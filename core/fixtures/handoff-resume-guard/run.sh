#!/usr/bin/env bash
# handoff-resume-guard — assert Check 0 blocks a missed resume prompt, and does NOT
# block one that follows the rulebook.
#
# THE DEFECT THIS FIXTURE EXISTS FOR. The reference consumer carried this guard for
# months matching EXACTLY six hyphens (`^------$`) while `steps/handoff.md` step 4 has
# ALWAYS mandated four (`----`). Six-hyphen appears nowhere in core, at any sha. So the
# guard fired on handoffs that were CORRECT per the rulebook: the lead emitted `----` as
# instructed, was blocked, read a block message telling it to use `------`, and complied
# with the HOOK instead of the RULE.
#
# Assertion 2 is therefore the load-bearing one: it FAILS against the version of this
# guard that was actually running in production.
#
# Usage: run.sh [path-to-ai-dlc-continue.sh]
set -uo pipefail

# HERMETIC — scrub the operator's tuning before invoking any hook.
#
# A fixture that INHERITS ambient config tests the config, not the code. The hooks honour
# thirteen AI_DLC_* tunables; a consumer that sets any of them in settings.json exports it
# into every session, `git push` inherits it, and the pre-push gate then runs this fixture
# against a hook configured differently from what the assertions assume.
#
# Observed live: a consumer pinned AI_DLC_MODEL_ROW=1M (the documented, sanctioned way to
# declare the model row). Its effective window became 300000 instead of 200000, every
# threshold shifted, and SEVEN assertions failed against a sensor that was behaving exactly
# as specified. The gate blocked every push on the repo. The distribution never caught it
# because the distribution sets none of these -- the check could not fire where it was
# authored.
#
# Unset ALL of them, by pattern, so a NEW tunable cannot reintroduce this. Per-command
# assignments (`AI_DLC_MODEL_ROW=1M "$HOOK"`) still work: those are the deliberate tests.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done


HERE="$(cd "$(dirname "$0")" && pwd)"
pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
HOOK="$(pick "${1:-}" "$HERE/../../hooks/ai-dlc-continue.sh" \
                      "$HERE/../../../core/hooks/ai-dlc-continue.sh" \
                      "$HERE/../../../.claude/hooks/ai-dlc-continue.sh")"
[ -n "$HOOK" ] || { echo "FIXTURE ERROR: cannot locate ai-dlc-continue.sh" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "FIXTURE ERROR: jq required" >&2; exit 2; }

ROOT="$(bash "$HERE/seed.sh")"
fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

# Drive the hook exactly as the harness does: JSON on stdin, decision on stdout.
# A fresh state dir per case, so the rapid-fire backoff cannot leak between them.
drive() { # drive <transcript> -> prints "block" or "allow"
  local t="$1" out
  local proj; proj="$(mktemp -d)"; mkdir -p "$proj/_bmad-output"
  out="$(jq -nc --arg t "$t" --arg s "fx" '{transcript_path:$t,session_id:$s}' \
        | CLAUDE_PROJECT_DIR="$proj" bash "$HOOK" 2>/dev/null)"
  rm -rf "$proj"
  if printf '%s' "$out" | jq -e '.decision=="block"' >/dev/null 2>&1; then
    printf 'block'
  else
    printf 'allow'
  fi
}

r="$(drive "$(cat "$ROOT/.p_miss")")"
[ "$r" = block ] && ok "handoff requested, NO resume block -> BLOCK" \
                 || bad "handoff requested with no resume block was ALLOWED ($r) — the guard cannot fire"

r="$(drive "$(cat "$ROOT/.p_core4")")"
[ "$r" = allow ] && ok "resume block in CORE's mandated '----' form -> ALLOW" \
                 || bad "BLOCKED a handoff that follows steps/handoff.md step 4 verbatim ($r) — the check fires on COMPLIANCE"

r="$(drive "$(cat "$ROOT/.p_six")")"
[ "$r" = allow ] && ok "resume block with six hyphens -> ALLOW (delimiter is -{4,}, not a count)" \
                 || bad "six-hyphen delimiter rejected ($r) — this is what the consumer emits today"

r="$(drive "$(cat "$ROOT/.p_undelim")")"
[ "$r" = block ] && ok "'/ai-dlc resume' present but UNDELIMITED -> BLOCK (format, not substring)" \
                 || bad "an undelimited, non-copy-pasteable mention passed ($r) — presence is not format"

r="$(drive "$(cat "$ROOT/.p_noun")")"
[ "$r" = allow ] && ok "incidental NOUN mention of 'handoff guard' -> no fire" \
                 || bad "fired on a question ABOUT the guard ($r) — spurious block, this spammed a real operator"

rm -rf "$ROOT"
echo ""
[ "$fails" -eq 0 ] && { echo "handoff-resume-guard: PASS"; exit 0; }
echo "handoff-resume-guard: FAIL ($fails)"; exit 1
