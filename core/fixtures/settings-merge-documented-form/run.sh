#!/usr/bin/env bash
# settings-merge-documented-form — SKILL.md's settings-merge invocations must be RUNNABLE.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the check regressed, 2 = fixture broken.
#
# THE DEFECT THIS EXISTS TO CATCH.
#
# SKILL.md step 5 documented `reconcile/settings-merge.sh --check` and called it "(no writes)".
# The bare form exits 1 with usage: the script requires `--consumer` and `--template`. Step 7's
# form supplied `--template <theirs>/templates/settings.json.template`, but `theirs` is resolved
# as a GIT REF, so that path fails the script's `-r` readability guard.
#
# Both were unrunnable as written, in a step whose output is an operator question. A documented
# command nobody executes drifts from its script silently — the script grew required flags and
# the prose did not follow. This binds them: the flags the doc shows must be the flags the
# script demands, and the demonstrated form must actually produce output.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"

find_one() { # find_one <core-relative-path>
  local rel="$1"
  if [ -n "$ROOT" ] && [ -f "$ROOT/core/$rel" ]; then printf '%s' "$ROOT/core/$rel"
  elif [ -n "$ROOT" ] && [ -f "$ROOT/.claude/$rel" ]; then printf '%s' "$ROOT/.claude/$rel"
  fi
}

SKILL="$(find_one skills/ai-dlc-update/SKILL.md)"
MERGE="$(find_one skills/ai-dlc-update/reconcile/settings-merge.sh)"
[ -n "$SKILL" ] || { echo "FIXTURE ERROR: ai-dlc-update/SKILL.md not found" >&2; exit 2; }
[ -n "$MERGE" ] || { echo "FIXTURE ERROR: settings-merge.sh not found" >&2; exit 2; }
echo "HERMETIC-CONSUMED $SKILL"
echo "HERMETIC-CONSUMED $MERGE"

TMPL=""
for c in "$ROOT/templates/settings.json.template" "$ROOT/.claude/templates/settings.json.template"; do
  [ -f "$c" ] && TMPL="$c" && break
done

WORK="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }
[ -f "$HERE/../lib/mutant.sh" ] || { echo "FIXTURE BROKEN: lib/mutant.sh not found beside $HERE" >&2; exit 2; }
. "$HERE/../lib/mutant.sh" || { echo "FIXTURE BROKEN: sourcing lib/mutant.sh failed" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"

# The subject is driven IN PROCESS (BL-878): sourced once, `sm_main` called in a subshell per drive, each drive one
# fx_inproc pass. This fixture is .dist-only, so the subject is always this tree's wrapped one; a subject missing
# either half of the wrap is a broken fixture world, never a SKIP.
grep -q '^sm_main() {$' "$MERGE"; _gx=$?
[ "$_gx" -le 1 ] || { echo "FIXTURE ERROR: cannot read $MERGE (grep exit $_gx)" >&2; exit 2; }
[ "$_gx" -eq 0 ] || { echo "FIXTURE BROKEN: $MERGE carries no \`sm_main() {\` line, so it cannot be driven in process" >&2; exit 2; }
grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$MERGE"; _gx=$?
[ "$_gx" -le 1 ] || { echo "FIXTURE ERROR: cannot read $MERGE (grep exit $_gx)" >&2; exit 2; }
[ "$_gx" -eq 0 ] || { echo "FIXTURE BROKEN: $MERGE carries no column-0 source guard; sourcing it would run sm_main in this shell" >&2; exit 2; }
. "$MERGE" || { echo "FIXTURE BROKEN: sourcing $MERGE failed" >&2; exit 2; }
declare -F sm_main > /dev/null || { echo "FIXTURE BROKEN: sourcing $MERGE defined no sm_main" >&2; exit 2; }
sm_run() { ( set +o pipefail
  fx_inproc "$MERGE"
  sm_main "$@" ); }

echo "settings-merge-documented-form:"

# --- Assertion 1: the script's REQUIRED flags are what the doc shows ---------
# Derived from the script's own usage string, never hardcoded here — if it grows a third
# required flag, this fixture must notice rather than pin yesterday's contract.
USAGE="$(grep -m1 'usage: settings-merge.sh' "$MERGE" || true)"
[ -n "$USAGE" ] || { echo "FIXTURE STALE: settings-merge.sh has no usage line" >&2; exit 2; }
missing=""
for flag in --consumer --template; do
  grep -qF -- "$flag" <<<"$USAGE" || missing="$missing $flag"
done
[ -z "$missing" ] || { echo "FIXTURE STALE: usage line lost$missing" >&2; exit 2; }

# Every settings-merge invocation the doc shows must carry both required flags somewhere in
# its (possibly wrapped) command. Checked per-occurrence over a 4-line window.
bare=0
while read -r ln; do
  [ -n "$ln" ] || continue
  win="$(sed -n "${ln},$((ln + 4))p" "$SKILL")"
  grep -qF -- '--consumer' <<<"$win" && grep -qF -- '--template' <<<"$win" \
    || bare=$((bare + 1))
done <<EOF
$(grep -n 'settings-merge\.sh' "$SKILL" | grep -v 'settings-merge\.sh`' | cut -d: -f1)
EOF
if [ "$bare" -eq 0 ]; then
  ok "every documented settings-merge invocation carries --consumer and --template"
else
  bad "$bare documented settings-merge invocation(s) omit a REQUIRED flag — the bare form exits 1 with usage, in a step whose output is an operator question"
fi

# --- Assertion 2: no invocation passes a git ref where a PATH is required ----
# `theirs` is a ref. `--template <theirs>/templates/...` fails the script's -r guard.
#
# Windowed, not line-anchored: the doc wraps, and the real defect had `--template` at the end
# of one line and `<theirs>/templates/...` at the start of the next. A single-line regex missed
# it — which is how this assertion first passed against the very text it exists to reject.
refpath=0
while read -r ln; do
  [ -n "$ln" ] || continue
  win="$(sed -n "${ln},$((ln + 4))p" "$SKILL")"
  grep -qF -- '--template' <<<"$win" \
    && grep -qE '<theirs>/[A-Za-z_.-]*templates?/' <<<"$win" \
    && refpath=$((refpath + 1))
done <<EOF
$(grep -n 'settings-merge\.sh' "$SKILL" | grep -v 'settings-merge\.sh`' | cut -d: -f1)
EOF
if [ "$refpath" -eq 0 ]; then
  ok "no documented invocation passes a git ref as the --template path"
else
  bad "$refpath documented invocation(s) pass '<theirs>/templates/...' to --template — theirs is a git ref and the script reads --template with -r, so this always fails"
fi

# --- Assertion 3: the documented form actually RUNS -------------------------
# The point of the whole fixture: a form that parses is not a form that works.
if [ -n "$TMPL" ]; then
  printf '{"permissions":{"allow":[]}}\n' > "$WORK/settings.json"
  out="$(sm_run --consumer "$WORK/settings.json" --template "$TMPL" --check 2>&1)"
  rc=$?
  if [ "$rc" -eq 0 ] && grep -q 'model_window_needed=' <<<"$out"; then
    ok "the documented form runs and reports model_window_needed (--check writes nothing)"
  else
    bad "the documented --check form did not run cleanly (rc=$rc): $(printf '%s' "$out" | head -1)"
  fi
  if [ -s "$WORK/settings.json" ] && grep -q '"allow"' "$WORK/settings.json"; then
    ok "--check left the consumer settings.json unwritten"
  else
    bad "--check MODIFIED the consumer settings.json — SKILL.md documents it as no-writes"
  fi
else
  bad "FIXTURE STALE: templates/settings.json.template not found in either layout"
fi

# --- Assertion 4: the historical bare form must FAIL ---------------
# If the bare form still exited 0, assertion 1 would be guarding nothing.
sm_run --check >/dev/null 2>&1
if [ "$?" -ne 0 ]; then
  ok "the bare '--check' form exits nonzero (assertion 1 guards a real failure)"
else
  bad "bare '--check' now exits 0, so assertion 1 cannot distinguish a runnable doc from an unrunnable one"
fi

# --- Assertion 5: bashOutputMaxChars is DELIVERED, and the consumer's value wins -----
# The template's cap on inline Bash output is the one non-hook scalar the merge must carry
# to an EXISTING consumer; "every other key preserved" would leave every installed tree
# uncapped forever. Three worlds, each read as a VALUE rather than a presence. Both template shapes are synthesised here so the arm does not depend
# on what the live template happens to declare.
if [ -n "$TMPL" ]; then
  T_CAP="$WORK/tmpl-cap.json"; T_NOCAP="$WORK/tmpl-nocap.json"
  jq '.bashOutputMaxChars = 8000' "$TMPL" > "$T_CAP"
  jq 'del(.bashOutputMaxChars)' "$TMPL" > "$T_NOCAP"
  [ "$(jq -r '.bashOutputMaxChars' "$T_CAP")" = "8000" ] \
    && [ "$(jq -r 'has("bashOutputMaxChars")' "$T_NOCAP")" = "false" ] \
    || { echo "FIXTURE BROKEN: could not synthesise the two template shapes" >&2; exit 2; }

  # World 1: consumer declares 12000, template declares 8000 -> 12000 survives.
  printf '{"bashOutputMaxChars":12000,"permissions":{"allow":[]}}\n' > "$WORK/w1.json"
  sm_run --consumer "$WORK/w1.json" --template "$T_CAP" >/dev/null 2>&1
  v="$(jq -r '.bashOutputMaxChars' "$WORK/w1.json")"
  if [ "$v" = "12000" ]; then ok "bashOutputMaxChars: consumer's 12000 survives a template declaring 8000"
  else bad "bashOutputMaxChars: consumer's 12000 was replaced (read $v) — the merge must never overwrite a consumer scalar"; fi

  # World 2: consumer silent, template declares 8000 -> 8000 lands.
  printf '{"permissions":{"allow":[]}}\n' > "$WORK/w2.json"
  sm_run --consumer "$WORK/w2.json" --template "$T_CAP" >/dev/null 2>&1
  v="$(jq -r '.bashOutputMaxChars' "$WORK/w2.json")"
  if [ "$v" = "8000" ]; then ok "bashOutputMaxChars: template's 8000 lands on a consumer that declares none"
  else bad "bashOutputMaxChars: template value did not reach the consumer (read $v) — an installed tree stays uncapped"; fi

  # World 3: neither side declares it -> key absent, not null and not 0.
  printf '{"permissions":{"allow":[]}}\n' > "$WORK/w3.json"
  sm_run --consumer "$WORK/w3.json" --template "$T_NOCAP" >/dev/null 2>&1
  v="$(jq -r 'has("bashOutputMaxChars")' "$WORK/w3.json")"
  if [ "$v" = "false" ]; then ok "bashOutputMaxChars: absent on both sides stays absent"
  else bad "bashOutputMaxChars: a key neither side declared appeared (has=$v) — the guard is gone"; fi
fi

# --- Assertion 6: the SHIPPED template's seat tiers (BL-838, BL-971) ---------
# Every other fixture seeds its own aiDlcRoles values, so nothing read what the distribution
# ships. This arm reads the template itself and asserts the four values the operator ruled:
# dev sonnet/medium, dev-escalated opus/medium. It lives here, not in dispatch-model-guard,
# because that fixture ships to consumers and a consumer has no templates/ tree. An unreadable
# template is a FAIL, never a skip.
# tpl_tiers <file> -> "devmodel/deveffort devescmodel/devesceffort", or nothing if unreadable.
tpl_tiers() {
  jq -r '.aiDlcRoles | "\(.dev.model)/\(.dev.effort) \(.["dev-escalated"].model)/\(.["dev-escalated"].effort)"' "$1" 2>/dev/null
}
TPL_WANT="sonnet/medium opus/medium"
if [ -z "$TMPL" ] || [ ! -r "$TMPL" ]; then
  bad "6 FIXTURE BROKEN: the shipped template is not readable — the seat-tier arm asserts nothing"
else
  TPL_GOT="$(tpl_tiers "$TMPL")"
  if [ "$TPL_GOT" = "$TPL_WANT" ]; then
    ok "6 the shipped template pins dev sonnet/medium and dev-escalated opus/medium"
  else
    bad "6 the shipped template pins '$TPL_GOT', expected '$TPL_WANT' (dev, dev-escalated)"
  fi
  # A second correct spelling (key order, whitespace) reads the same, so the arm keys on values.
  TPL_RESPELL="$WORK/tpl-respelled.json"
  jq -c '.aiDlcRoles |= (to_entries | reverse | from_entries)' "$TMPL" > "$TPL_RESPELL" 2>/dev/null
  if cmp -s "$TMPL" "$TPL_RESPELL" || [ ! -s "$TPL_RESPELL" ]; then
    bad "6 re-spelling control DID NOT APPLY: the respelled copy is identical to, or empty against, the template"
  else
    [ "$(tpl_tiers "$TPL_RESPELL")" = "$TPL_WANT" ] \
      && ok "6 a re-ordered, re-spaced spelling of the same values reads identically (the arm keys on values)" \
      || bad "6 a correct re-spelling of the template read '$(tpl_tiers "$TPL_RESPELL")', expected '$TPL_WANT'"
  fi
fi

# --- Assertion 7: the context-mode enable is retired, nothing else (BL-1188) ---------------------------
# The shipped template carries no enable; a consumer's `true` is removed on a merge against a template
# that wires hooks, `false` and other plugins survive, a key nobody had stays absent (no `{}`), and the
# uninstall call (an empty `{}` template) never retires. Each world is one in-process run.
if [ -n "$TMPL" ]; then
  CM='context-mode@context-mode'
  [ "$(jq -r 'has("enabledPlugins")' "$TMPL")" = false ] \
    && ok "7 the shipped template carries no enabledPlugins block" \
    || bad "7 the shipped template still carries an enabledPlugins block"
  printf '{}\n' > "$WORK/empty-tmpl.json"
  sm7() { # <id> <seed-json> <template> [--check]; leaves $WORK/$id.json and $WORK/$id.out
    printf '%s\n' "$2" > "$WORK/$1.json"
    sm_run --consumer "$WORK/$1.json" --template "$3" ${4:+"$4"} > "$WORK/$1.out" 2>&1; }
  A='{"enabledPlugins":{"context-mode@context-mode":true,"other@x":true}}'
  B='{"enabledPlugins":{"context-mode@context-mode":false}}'
  sm7 chkA "$A" "$TMPL" --check; sm7 chkB "$B" "$TMPL" --check
  grep -q '^enabledPlugins: .*context-mode.*--scope user' "$WORK/chkA.out" \
    && ok "7 --check names the retirement and the user-scope install when a true enable will be retired" \
    || bad "7 --check printed no retirement line for a consumer holding the enable: $(head -c 200 "$WORK/chkA.out")"
  grep -q '^model_window_needed=' "$WORK/chkB.out" && ! grep -q '^enabledPlugins:' "$WORK/chkB.out" \
    && ok "7 --check prints no retirement line for a false enable (and still reports)" \
    || bad "7 --check printed a retirement line where none fires, or no report: $(head -c 200 "$WORK/chkB.out")"
  sm7 wA "$A" "$TMPL"; sm7 wB "$B" "$TMPL"; sm7 wC '{"permissions":{"allow":[]}}' "$TMPL"
  sm7 wD '{"enabledPlugins":{"context-mode@context-mode":true}}' "$TMPL"
  sm7 wE '{"enabledPlugins":{"context-mode@context-mode":true}}' "$WORK/empty-tmpl.json"
  [ "$(jq -c '.enabledPlugins' "$WORK/wA.json")" = '{"other@x":true}' ] \
    && ok "7 a true enable is removed and another plugin is kept" \
    || bad "7 true/other-plugin world read $(jq -c '.enabledPlugins' "$WORK/wA.json")"
  [ "$(jq -c '.enabledPlugins' "$WORK/wB.json")" = '{"context-mode@context-mode":false}' ] \
    && ok "7 an explicit false enable is kept" || bad "7 false world read $(jq -c '.enabledPlugins' "$WORK/wB.json")"
  [ "$(jq -r 'has("enabledPlugins")' "$WORK/wC.json")" = false ] \
    && ok "7 a consumer with no enabledPlugins gains none (no {})" || bad "7 an absent enabledPlugins key appeared"
  [ "$(jq -r 'has("enabledPlugins")' "$WORK/wD.json")" = false ] \
    && ok "7 retiring a sole true entry leaves no enabledPlugins key (no {})" || bad "7 sole-true world left $(jq -c '.enabledPlugins' "$WORK/wD.json")"
  [ "$(jq -c '.enabledPlugins' "$WORK/wE.json")" = '{"context-mode@context-mode":true}' ] \
    && ok "7 a pre-install true survives the uninstall call (empty template)" || bad "7 the empty-template merge retired the enable"
fi

# --- the cli cells (cells.decl): the subject run as a PROGRAM once per distinct CLI outcome this fixture drives -----
# The outcomes: exit 0 with the --check report on stdout, exit 1 with the usage line on stderr, and exit 0 with the
# merge written and its confirmation on stdout. One `FXCELL=<id> bash "$MERGE"` start per outcome, each compared with
# the in-process call on its own copy of the same world: stdout, stderr and exit separately, byte for byte, and for the
# merge the written file too. Each cell also asserts its own outcome, and the cells must differ.
EQ="$WORK/eq"; mkdir -p "$EQ" || { echo "FIXTURE BROKEN: cannot create $EQ" >&2; exit 2; }
eqv() { # <cell-id> <seed-json or -> <args...>; the literal CONS in args names the cell's own consumer copy
  local id="$1" seed="$2" a side; shift 2
  for side in ip cl; do
    [ "$seed" = - ] || printf '%s\n' "$seed" > "$EQ/$id.$side.json"
    set --; for a in "${EQARGS[@]}"; do [ "$a" = CONS ] && a="$EQ/$id.$side.json"; set -- "$@" "$a"; done
    if [ "$side" = ip ]; then sm_run "$@" > "$EQ/$id.ip.out" 2> "$EQ/$id.ip.err"; echo "$?" > "$EQ/$id.ip.rc"
    else FXCELL="$id" bash "$MERGE" "$@" > "$EQ/$id.cl.out" 2> "$EQ/$id.cl.err"; echo "$?" > "$EQ/$id.cl.rc"; fi
  done
  cmp -s "$EQ/$id.ip.out" "$EQ/$id.cl.out" && cmp -s "$EQ/$id.ip.err" "$EQ/$id.cl.err" && cmp -s "$EQ/$id.ip.rc" "$EQ/$id.cl.rc" \
    && { [ "$seed" = - ] || cmp -s "$EQ/$id.ip.json" "$EQ/$id.cl.json"; }
}
eq_twin() { printf 'in-process rc=%s out=[%s] err=[%s] / program rc=%s out=[%s] err=[%s]' "$(cat "$EQ/$1.ip.rc")" \
  "$(head -c 300 "$EQ/$1.ip.out")" "$(head -c 300 "$EQ/$1.ip.err")" "$(cat "$EQ/$1.cl.rc")" "$(head -c 300 "$EQ/$1.cl.out")" "$(head -c 300 "$EQ/$1.cl.err")"; }
if [ -n "$TMPL" ]; then
  EQARGS=(--consumer CONS --template "$TMPL" --check)
  if eqv cli-check '{"permissions":{"allow":[]}}' && [ "$(cat "$EQ/cli-check.cl.rc")" = 0 ] && grep -q '^model_window_needed=' "$EQ/cli-check.cl.out" \
     && [ ! -s "$EQ/cli-check.cl.err" ]; then
    ok "cli-check: the program's --check report is exactly the in-process call's (stdout, stderr, exit 0)"
  else bad "cli-check: the program and the in-process call differ, or the outcome is not exit 0 with the report ($(eq_twin cli-check))"; fi
  EQARGS=(--consumer CONS --template "$T_CAP")
  if eqv cli-merge '{"permissions":{"allow":[]}}' && [ "$(cat "$EQ/cli-merge.cl.rc")" = 0 ] && grep -q '^settings.json reconciled' "$EQ/cli-merge.cl.out" \
     && [ "$(jq -r '.bashOutputMaxChars' "$EQ/cli-merge.cl.json")" = 8000 ]; then
    ok "cli-merge: the program writes and confirms the merge exactly as the in-process call does (stdout, stderr, exit 0, merged file)"
  else bad "cli-merge: the program and the in-process call differ, or the outcome is not exit 0 with the merge written ($(eq_twin cli-merge))"; fi
else
  bad "FIXTURE STALE: templates/settings.json.template not found in either layout, so the cli-check and cli-merge cells cannot run"
fi
EQARGS=(--check)
if eqv cli-usage - && [ "$(cat "$EQ/cli-usage.cl.rc")" = 1 ] && [ ! -s "$EQ/cli-usage.cl.out" ] \
   && grep -q '^usage: settings-merge.sh --consumer' "$EQ/cli-usage.cl.err"; then
  ok "cli-usage: the program refuses the bare form exactly as the in-process call does (stdout, stderr, exit 1)"
else bad "cli-usage: the program and the in-process call differ, or the outcome is not the exit-1 usage refusal ($(eq_twin cli-usage))"; fi
if [ -s "$EQ/cli-check.cl.out" ] && [ -s "$EQ/cli-merge.cl.out" ] && ! cmp -s "$EQ/cli-check.cl.out" "$EQ/cli-merge.cl.out" \
   && ! cmp -s "$EQ/cli-check.cl.rc" "$EQ/cli-usage.cl.rc"; then
  ok "cli cells discriminate: the report, the merge confirmation and the usage refusal give different output"
else bad "cli cells do not discriminate: two outcomes read the same, so an equivalence over them proves nothing"; fi

echo
report_end settings-merge-documented-form
