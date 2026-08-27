#!/usr/bin/env bash
# Exercise the `.claude/rules/` version floor -- the DETECTOR, not a copy-time gate.
#
# `.claude/rules/` did not exist before Claude Code 2.0.64. Below that floor an installed
# rule file is INERT while everything in the tree reports success: the audit scans it and
# passes, `.ai-dlc-version` says the tree is current, and Rule 23's Carrier names it. A
# check that cannot fire reading exactly like one that passed.
#
# THE FLOOR IS NOT ENFORCED AT COPY TIME, AND THE FIRST VERSION OF THIS FIXTURE TESTED THE
# WRONG THING. It asserted that `install.sh` SKIPS the copy below the floor. That gate was
# real and passed its own arms -- and it protected nothing, because `install.sh` is only
# the path a NEW consumer takes. Measured on a copy of the reference consumer: the real
# pull (`apply.sh`, 0.347.0 -> 0.349.0, shimmed 1.9.0) reported
# `RESOLVED pure-apply rules/ai-dlc-resident-discipline.md`, wrote the file and re-stamped
# the tree as current. A third path -- install current, then DOWNGRADE -- no copy-time gate
# can see at all.
#
# So both copy paths ship the file unconditionally and ONE hook detects the floor every
# session, whatever path the file arrived by. These arms test that hook, plus the property
# that makes it the only thing standing between a consumer and a silent inert carrier.
#
#   A  no rule file present            -> silent (nothing to be inert)
#   B  file + version below floor      -> LOUD, names the file and the floor
#   C  file + version at floor (2.0.64)-> silent  (boundary, inclusive)
#   D  file + one below (2.0.63)       -> LOUD    (boundary, exclusive)
#   E  version unresolvable            -> reports UNRESOLVED, never silence
#   F  install.sh ships the file with NO version gate, on any version
#   G  uninstall.sh removes ai-dlc-*.md by prefix and KEEPS a consumer's own rule
#
# WHY E IS NOT PARANOIA. An unresolvable version is the same epistemic state as one below
# the floor. A detector that treats "I could not tell" as "fine" is the defect it exists
# to report, one level up.
#
# WHY F ASSERTS AN ABSENCE OF A GATE. The gate was removed deliberately; without this arm
# a future edit could reintroduce it, and the tree would again be protected on one path
# and not the other -- which reads as protection and is not.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
# Resolve the distribution root by walking UP for a marker from this fixture's OWN
# location, never by counting `..` hops -- a fixed hop count is what I33/I33b forbid.
ROOT="$DIR"
while [ "$ROOT" != "/" ] && [ ! -f "$ROOT/scripts/install.sh" ]; do ROOT="$(dirname "$ROOT")"; done
INSTALL="$ROOT/scripts/install.sh"
UNINSTALL="$ROOT/scripts/uninstall.sh"
HOOK="$ROOT/core/hooks/ai-dlc-rules-floor.sh"
[ -f "$HOOK" ] || HOOK="$ROOT/.claude/hooks/ai-dlc-rules-floor.sh"
RULE="ai-dlc-resident-discipline.md"

for f in "$INSTALL" "$UNINSTALL" "$HOOK"; do
  [ -f "$f" ] || { echo "run.sh: missing $f" >&2; exit 2; }
done
command -v jq >/dev/null 2>&1 || { echo "run.sh: jq required by install.sh" >&2; exit 2; }

# Scrub ambient AI_DLC_* before invoking any hook. A consumer that tunes one of these in
# settings.json would otherwise fail this fixture against a hook behaving correctly, and
# its pre-push gate would then block every push. The fixture must test the CODE, not the
# environment it happens to run in.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
rc=0
note() { printf '%s\n' "$*"; }

# Run the hook against a throwaway project dir at a pinned version.
hook_out() { # hook_out <project-dir> <AI_AGENT value or empty>
  local d="$1" agent="${2:-}" empty; empty="$(mktemp -d "$TMP/nobin.XXXXXX")"
  # PATH is stripped to a dir with no `claude` so the AI_AGENT branch is what is under
  # test; otherwise the fallback would silently answer with THIS machine's real version
  # and every arm below would pass for the wrong reason.
  CLAUDE_PROJECT_DIR="$d" AI_AGENT="$agent" PATH="$empty:/usr/bin:/bin" \
    bash "$HOOK" </dev/null 2>&1
}

proj() { local d; d="$(mktemp -d "$TMP/p.XXXXXX")"; mkdir -p "$d/.claude/rules"; printf '%s' "$d"; }

# --- A: nothing shipped -> silent ------------------------------------------
d="$(proj)"
if [ -z "$(hook_out "$d" claude-code_1-9-0_agent)" ]; then
  note "ok    A no rule file -- silent"
else note "FAIL  A the hook spoke with no rule file present"; rc=1; fi

# --- B: below floor -> loud -------------------------------------------------
d="$(proj)"; printf 'x\n' > "$d/.claude/rules/$RULE"
out="$(hook_out "$d" claude-code_1-9-0_agent)"
if grep -q 'FLOOR NOT MET' <<<"$out" && grep -q "$RULE" <<<"$out"; then
  note "ok    B below floor -- loud, and names the file"
else note "FAIL  B below floor did not report: ${out:0:120}"; rc=1; fi
# The message is injected as JSON; malformed JSON is dropped by the harness and the
# warning never reaches anyone, which is indistinguishable from silence.
if ! python3 -c 'import json,sys; json.load(sys.stdin)' <<<"$out" 2>/dev/null; then
  note "FAIL  B emitted invalid JSON; the harness would discard it and the warning would vanish"; rc=1
fi

# --- C/D: the boundary, both sides -----------------------------------------
d="$(proj)"; printf 'x\n' > "$d/.claude/rules/$RULE"
# KEYED ON THE FLOOR FINDING, NOT ON SILENCE. This hook stopped being silent when the floor is
# met: it also carries the fleet's provenance contract, which has to reach the lead on EVERY
# session and not only on the sessions where an unrelated check happens to fire. The property
# arm C owns is that a met floor produces NO FLOOR COMPLAINT, and that is what it now asserts.
# Asserting emptiness would make this arm fail on any future payload the hook legitimately
# carries, which is a check that errors on correct data.
out_c="$(hook_out "$d" claude-code_2-0-64_agent)"
if grep -q 'FLOOR NOT MET' <<<"$out_c" || grep -q 'FLOOR -- UNRESOLVED' <<<"$out_c"; then
  note "FAIL  C 2.0.64 IS the floor and must be accepted"; rc=1
else
  note "ok    C floor exactly (2.0.64) -- no floor complaint"
fi
# The control the emptiness test used to give for free: the hook must still be SAYING something,
# or "no complaint" would be satisfied by a hook that died. And it must still be valid JSON.
if [ -z "$out_c" ]; then
  note "FAIL  C the hook emitted NOTHING at the floor -- the provenance contract has no carrier, and a silent hook satisfies the no-complaint test above for the wrong reason"; rc=1
elif ! python3 -c 'import json,sys; json.load(sys.stdin)' <<<"$out_c" 2>/dev/null; then
  note "FAIL  C emitted invalid JSON at the floor; the harness would discard the whole block"; rc=1
elif ! grep -q 'AI-DLC-HOOK-PROVENANCE' <<<"$out_c"; then
  note "FAIL  C the floor-met emission carries no provenance marker, so this hook is not carrying the contract it is sited to carry"; rc=1
fi
grep -q 'FLOOR NOT MET' <<<"$(hook_out "$d" claude-code_2-0-63_agent)" \
  && note "ok    D one below floor (2.0.63) -- loud" \
  || { note "FAIL  D 2.0.63 is below the floor and must be reported"; rc=1; }

# --- E: unresolvable version -> reports, never silent -----------------------
d="$(proj)"; printf 'x\n' > "$d/.claude/rules/$RULE"
grep -q 'UNRESOLVED' <<<"$(hook_out "$d" "")" \
  && note "ok    E version unresolvable -- reported, not assumed fine" \
  || { note "FAIL  E an unresolvable version was treated as meeting the floor"; rc=1; }

# --- F: install.sh ships the file, with no version gate ---------------------
t="$(mktemp -d "$TMP/tgt.XXXXXX")"; mkdir -p "$t/_bmad"; ( cd "$t" && git init -q . )
oldbin="$(mktemp -d "$TMP/old.XXXXXX")"
printf '#!/bin/sh\necho "1.9.0 (Claude Code)"\n' > "$oldbin/claude"; chmod +x "$oldbin/claude"
PATH="$oldbin:$PATH" bash "$INSTALL" "$t" > "$TMP/install.log" 2>&1
if [ -f "$t/.claude/rules/$RULE" ]; then
  note "ok    F install ships the rule with no copy-time version gate"
else
  note "FAIL  F install SKIPPED the rule on an old version. A copy-time gate is back, and it"
  note "      protects install.sh only -- apply.sh has no such gate, so the tree is guarded"
  note "      on one path and not the other. The floor belongs in the hook."
  rc=1
fi

# --- G: uninstall by prefix, keeping the consumer's own ---------------------
printf '# a rule this consumer wrote\n' > "$t/.claude/rules/consumer-own.md"
printf 'y\n' | bash "$UNINSTALL" "$t" > "$TMP/uninstall.log" 2>&1
if [ -f "$t/.claude/rules/$RULE" ]; then
  note "FAIL  G the shipped rule survived uninstall; it would keep loading into every session"
  note "      of a repo that no longer has AI/DLC installed"; rc=1
elif [ ! -f "$t/.claude/rules/consumer-own.md" ]; then
  note "FAIL  G uninstall deleted the consumer's OWN rule file; the ai-dlc- prefix is the boundary"; rc=1
else
  note "ok    G uninstall removed ai-dlc-* and kept the consumer's own rule"
fi

[ "$rc" -eq 0 ] && note "PASS  shipped-rule-version-floor -- detector correct on both sides of the boundary, no copy-time gate, uninstall scoped by prefix"
exit "$rc"
