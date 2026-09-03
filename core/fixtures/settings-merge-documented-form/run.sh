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

TMPL=""
for c in "$ROOT/templates/settings.json.template" "$ROOT/.claude/templates/settings.json.template"; do
  [ -f "$c" ] && TMPL="$c" && break
done

WORK="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

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
  out="$(bash "$MERGE" --consumer "$WORK/settings.json" --template "$TMPL" --check 2>&1)"
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

# --- Assertion 4: MUTANT — the historical bare form must FAIL ---------------
# If the bare form still exited 0, assertion 1 would be guarding nothing.
bash "$MERGE" --check >/dev/null 2>&1
if [ "$?" -ne 0 ]; then
  ok "the bare '--check' form exits nonzero (assertion 1 guards a real failure)"
else
  bad "MUTANT NOT DETECTED: bare '--check' now exits 0, so assertion 1 cannot distinguish a runnable doc from an unrunnable one"
fi

echo
if [ "$fails" -eq 0 ]; then echo "settings-merge-documented-form: PASS"; exit 0; fi
echo "settings-merge-documented-form: $fails assertion(s) FAILED" >&2
exit 1
