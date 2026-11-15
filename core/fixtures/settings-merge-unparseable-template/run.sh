#!/usr/bin/env bash
# settings-merge-unparseable-template -- `--check` must REFUSE a template it cannot parse,
# not answer `model_window_needed=no` and exit 0.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the check regressed, 2 = fixture broken.
#
# THE DEFECT THIS EXISTS TO CATCH.
#
# `SENSOR_WIRED` was `jq -r '<sensor predicate>' "$TEMPLATE" 2>/dev/null || echo false`. That
# fallback made a jq ERROR and a genuine verdict the SAME STRING, and every guard downstream of
# the conflation is blind by construction: the verdict gate is
# `[ "$SENSOR_WIRED" = "true" ] && [ -z "$DECLARED_FAMILIES" ]`, so anything that is not the
# literal `true` collapses to `model_window_needed=no` at exit 0. Step 5 of ai-dlc-update
# raises the declaration question ONLY on `yes`, so a consumer that genuinely needed a model
# window declared was never asked and the run stayed green. (Measured when the gate's second
# conjunct was a single `AI_DLC_MODEL_ROW` key; the shape is the same with the per-family
# `AI_DLC_MODEL_<FAMILY>_WINDOW` declarations that replaced it.)
#
# FOUR INPUT CLASSES REACHED THAT SILENT `no`, NOT THE ONE THE REPORT NAMED. Re-measured here
# against one consumer settings.json declaring no model window, same script, same
# invocation, pre-fix blob vs the tree:
#
#   template            pre-fix                              fixed
#   correct (producer)  sensor_wired=true   needed=yes rc=0   sensor_wired=true needed=yes rc=0
#   0-byte              sensor_wired=       needed=no  rc=0   refused, rc=1
#   readable non-JSON   sensor_wired=false  needed=no  rc=0   refused, rc=1
#   bare JSON scalar    sensor_wired=false  needed=no  rc=0   refused, rc=1
#   {"hooks":5}         sensor_wired=false  needed=no  rc=0   refused, rc=1
#
# The last two are VALID JSON, which is why validating the template as JSON is not sufficient --
# `.hooks // {} | to_entries[]` still errors on them. The unreadable case was never open: the
# `-r` guard already refuses it at exit 1.
#
# THE FIX IS LAYERED. Layer 1 reads jq's own exit
# status (the `|| echo false` is gone); layer 2 refuses unless SENSOR_WIRED is a literal
# true|false. Reverting only layer 1 still closes the 0-byte case, because jq exits 0 there and
# prints nothing, so the fallback never fires and the empty string trips layer 2. Reverting only
# layer 2 still closes the other three, because jq exits non-zero on them. #
# WHY THE POSITIVE CONTROL IS NOT OPTIONAL. Arms 2 and 3 are ABSENCE-shaped -- "no verdict is
# produced". A script that answers `no` to EVERYTHING, or refuses everything, satisfies them
# both. Arm 1 asserts the correct template still reaches `model_window_needed=yes` and the `ask:`
# lines step 5 prints, so a fix that closes the check by breaking it is rejected here.
#

set -u

NAME="settings-merge-unparseable-template"

# --- self-location, BEFORE any cd, and the repo root by MARKER not by hop count ---------------
# Counting `..` from here answers differently in the distribution, from a subdirectory, and in a
# consumer sandbox that copied the tree -- and the sandbox answer is the silent one. Walk up for
# the VERSION marker instead.
HERE="$(cd "$(dirname "$0")" && pwd)" || { printf 'FIXTURE BROKEN: cannot resolve own directory\n' >&2; exit 2; }
ROOT=""
_d="$HERE"
while [ "$_d" != "/" ] && [ -n "$_d" ]; do
  if [ -f "$_d/VERSION" ]; then ROOT="$_d"; break; fi
  _d="$(dirname "$_d")"
done
[ -n "$ROOT" ] || { printf 'FIXTURE BROKEN: no VERSION marker above %s\n' "$HERE" >&2; exit 2; }

# --- the subject, named in BOTH install layouts and RESOLVED into a variable -------------------
# I33/I33b/I33c: install.sh splits what shares a parent here -- core/skills/<x> lands at
# .claude/skills/<x> while core/fixtures/ lands at tests/fixtures/ -- so a chain that walks up
# from this file into a core sibling is green here and resolves nowhere on a consumer. Both
# candidates are named off the marker-resolved root, and the winner is printed.
SUBJECT=""
LOOKED=""
for _c in \
  "$ROOT/core/skills/ai-dlc-update/reconcile/settings-merge.sh" \
  "$ROOT/.claude/skills/ai-dlc-update/reconcile/settings-merge.sh"; do
  LOOKED="$LOOKED
    $_c"
  if [ -f "$_c" ]; then SUBJECT="$_c"; break; fi
done
[ -n "$SUBJECT" ] || { printf 'FIXTURE BROKEN: settings-merge.sh in neither layout. Looked in:%s\n' "$LOOKED" >&2; exit 2; }

# --- the good template comes from the real PRODUCER, never hand-written to match the reader ----
# A seed derived from what the predicate accepts proves the predicate accepts its own grammar and
# nothing else. This is the file install.sh:408 merges into a consumer's settings.json.
TMPL=""
for _c in \
  "$ROOT/templates/settings.json.template" \
  "$ROOT/.claude/templates/settings.json.template"; do
  if [ -f "$_c" ]; then TMPL="$_c"; break; fi
done
[ -n "$TMPL" ] || { printf 'FIXTURE BROKEN: templates/settings.json.template in neither layout (see .dist-only: this fixture cannot run on a consumer)\n' >&2; exit 2; }

command -v jq >/dev/null 2>&1 || { printf 'FIXTURE BROKEN: jq absent. Without it the subject exits 1 on EVERY template, which would satisfy the two absence-shaped arms vacuously\n' >&2; exit 2; }

printf '%s:\n' "$NAME"
printf '  ..    subject resolved: %s\n' "${SUBJECT#$ROOT/}"
printf '  ..    producer template: %s\n' "${TMPL#$ROOT/}"

echo "HERMETIC-CONSUMED core/skills/ai-dlc-update/reconcile/settings-merge.sh"

WORK="$(mktemp -d 2>/dev/null)" || { printf 'FIXTURE BROKEN: mktemp failed\n' >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

# shellcheck source=/dev/null
. "$HERE/../lib/report.sh" || { echo "FIXTURE ERROR: lib/report.sh not found" >&2; exit 2; }

# --- seeds ------------------------------------------------------------------------------------
CONSUMER="$WORK/settings.json"
printf '{"env":{"ENABLE_PROMPT_CACHING_1H":"1"},"permissions":{"allow":[]},"hooks":{}}\n' > "$CONSUMER"
S_GOOD="$WORK/good.json";     cp "$TMPL" "$S_GOOD"
S_EMPTY="$WORK/empty.json";   : > "$S_EMPTY"
S_JUNK="$WORK/junk.json";     printf 'not json at all\n' > "$S_JUNK"
S_SCALAR="$WORK/scalar.json"; printf '5\n' > "$S_SCALAR"
S_HOOKS="$WORK/hooksnum.json"; printf '{"hooks":5}\n' > "$S_HOOKS"

# --- CAN THE SEEDS REACH THE BRANCH UNDER TEST? -----------------------------------------------
# A fixture whose tree cannot EXPRESS the defect proves nothing. Arm 1 asserts `yes`, which is
# reachable only if the producer template wires the sensor AND the consumer seed declares no
# model window. Both are derived here rather than assumed, because either one drifting turns
# arm 1 into a constant.
grep -qF 'ai-dlc-context-sensor.sh' "$S_GOOD" \
  || { printf 'FIXTURE BROKEN: the producer template no longer wires ai-dlc-context-sensor.sh, so model_window_needed=yes is unreachable and arm 1 asserts nothing\n' >&2; exit 2; }
[ "$(jq -r '(.env // {}) | keys[]' "$CONSUMER" | grep -c '^AI_DLC_MODEL_.*_WINDOW$')" -eq 0 ] \
  || { printf 'FIXTURE BROKEN: the consumer seed declares an AI_DLC_MODEL_<FAMILY>_WINDOW, which suppresses model_window_needed=yes independently of the sensor\n' >&2; exit 2; }
[ ! -s "$S_EMPTY" ] \
  || { printf 'FIXTURE BROKEN: the 0-byte seed is not 0 bytes\n' >&2; exit 2; }
jq -e . "$S_SCALAR" >/dev/null 2>&1 && jq -e . "$S_HOOKS" >/dev/null 2>&1 \
  || { printf 'FIXTURE BROKEN: the scalar and hooks-not-an-object seeds must be VALID JSON -- that is the whole reason validating the template as JSON is insufficient\n' >&2; exit 2; }

# --- the arms, as functions, so the subject is scored by ONE instrument ------
RC=0
OUT=""
run_check() { # run_check <script> <template>
  OUT="$(bash "$1" --consumer "$CONSUMER" --template "$2" --check 2>&1)"
  RC=$?
}

# ARM 1 -- POSITIVE CONTROL, and the decisive third case. The correct template must still reach
# a verdict of `yes` AND print the operator question step 5 raises. Absence-shaped arms alone
# pass against a script that answers `no` to everything or refuses everything; this one does not.
arm1() { # arm1 <script>
  run_check "$1" "$S_GOOD"
  [ "$RC" -eq 0 ] || return 1
  grep -qF 'sensor_wired=true'      <<<"$OUT" || return 1
  grep -qF 'model_window_needed=yes'   <<<"$OUT" || return 1
  grep -q  '^ask: '                 <<<"$OUT" || return 1
  return 0
}

# ARM 2 -- the 0-byte template. jq exits 0 and prints NOTHING here, so the removed fallback never
# fired on this input: this is the case layer 2 owns. The assertion is a POSITIVE outcome -- a
# non-zero exit carrying the script's own `FAIL:` refusal naming the template -- and only then
# the absence of a verdict line. Asserting the absence alone would score a kill against a
# harness that died before running.
arm2() { # arm2 <script>
  run_check "$1" "$S_EMPTY"
  [ "$RC" -ne 0 ] || return 1
  grep -q '^FAIL: ' <<<"$OUT" || return 1
  grep -qF "$S_EMPTY" <<<"$OUT" || return 1
  grep -qF 'model_window_needed=' <<<"$OUT" && return 1
  return 0
}

# ARM 3 -- the three templates jq itself ERRORS on: readable non-JSON, a bare JSON scalar, and a
# valid object whose `.hooks` is not an object. This is the case layer 1 owns. Same positive
# shape as arm 2.
arm3() { # arm3 <script>
  for _t in "$S_JUNK" "$S_SCALAR" "$S_HOOKS"; do
    run_check "$1" "$_t"
    [ "$RC" -ne 0 ] || return 1
    grep -q '^FAIL: ' <<<"$OUT" || return 1
    grep -qF "$_t" <<<"$OUT" || return 1
    grep -qF 'model_window_needed=' <<<"$OUT" && return 1
  done
  return 0
}

score() { # score <script> -> prints the failing arm names, space-separated, or empty
  local s="$1" f=""
  arm1 "$s" || f="$f arm1"
  arm2 "$s" || f="$f arm2"
  arm3 "$s" || f="$f arm3"
  printf '%s' "${f# }"
}

# --- 1..3: the arms against the RESOLVED subject -----------------------------------------------
SHIPPED_FAIL=""
if arm1 "$SUBJECT"; then
  ok "arm1 POSITIVE CONTROL: the producer template reaches sensor_wired=true, model_window_needed=yes and the ask: block"
else
  SHIPPED_FAIL="$SHIPPED_FAIL arm1"
  bad "arm1 POSITIVE CONTROL FAILED (rc=$RC): the correct template no longer reaches model_window_needed=yes, so step 5 never raises the provisioning question. A guard that closes the check by refusing everything lands here. Output: $(head -1 <<<"$OUT")"
fi

if arm2 "$SUBJECT"; then
  ok "arm2: a 0-byte template is REFUSED with a FAIL: diagnostic and produces no model_window_needed verdict"
else
  SHIPPED_FAIL="$SHIPPED_FAIL arm2"
  bad "arm2 FAILED (rc=$RC): a 0-byte template still reaches a verdict. jq exits 0 and prints nothing on it, so SENSOR_WIRED is the empty string and the gate collapses it to model_window_needed=no at exit 0. Output: $(head -1 <<<"$OUT")"
fi

if arm3 "$SUBJECT"; then
  ok "arm3: non-JSON, a bare JSON scalar and {\"hooks\":5} are each REFUSED with a FAIL: diagnostic and no verdict"
else
  SHIPPED_FAIL="$SHIPPED_FAIL arm3"
  bad "arm3 FAILED (rc=$RC): a template jq cannot evaluate still reaches a verdict. Two of these three are VALID JSON, so validating the template as JSON does not close this. Output: $(head -1 <<<"$OUT")"
fi

# --- 10: CWD INVARIANCE -------------------------------------------------------------------------
# The suite drives run.sh from the repo root. Every path above is absolute, resolved off the
# VERSION marker before any cd, so the verdicts must not move with the process working directory.
# A fixture green only from the repo root may be asserting nothing from anywhere else.
# The process-cwd side is the failing set arms 1-3 ALREADY computed against the resolved subject at this same cwd,
# so it is taken from them and not re-run; only the $WORK side needs a fresh score, because its cwd differs.
elsewhere="$( cd "$WORK" && score "$SUBJECT" )"
here_now="${SHIPPED_FAIL# }"
if [ "$elsewhere" = "$here_now" ]; then
  ok "cwd-invariant: the arm set scores identically from \$WORK and from the process cwd ('${here_now:-all pass}')"
else
  bad "cwd-DEPENDENT: from \$WORK the failing set is [${elsewhere:-none}], from the process cwd it is [${here_now:-none}]. A verdict that moves with the caller's directory is not a verdict."
fi


printf '\n'
report_end "$NAME"
