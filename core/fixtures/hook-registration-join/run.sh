#!/usr/bin/env bash
# hook-registration-join — prove `validate-hook-registration.sh` can FAIL.
#
# WHAT THE VALIDATOR ASSERTS. A hook arrives on a consumer in two halves: `apply.sh` writes
# `.claude/hooks/ai-dlc-<x>.sh` mechanically, and `settings-merge.sh` registers it in
# `.claude/settings.json`. Nothing CALLS `settings-merge.sh` — its only invocation sites in
# the distribution are prose, in `ai-dlc-update/SKILL.md`. A pull that skips the prose ships
# a hook that is on disk, looks installed, and never fires. The validator joins the two sides
# and names the difference.
#
# WHY THIS FIXTURE EXISTS. That validator passes on this repo and on every well-formed
# consumer — the state this repo names as its recurring defect. Its whole value is the tree
# it rejects, and a green with no mutant behind it is indistinguishable from a check whose
# extraction stopped matching. Every arm below asserts a POSITIVE outcome (a specific exit
# code, and for the finding arms a named hook), never the absence of the old message.
#
# THE MUTANTS ARE THE INPUT TREE, NOT THE VALIDATOR. The validator resolves both its sides
# from `--root`, so the whole subject is expressible as a seeded consumer tree. Each arm is a
# fresh COPY of an unmutated base, the mutation is guarded with `cmp -s` so a `sed` that
# matched nothing cannot pass as a mutation, and arm 1 is the unmutated control — a base tree
# that fails would make every kill below meaningless.
#
# THE PATTERN-SOURCE MUTANTS ARE THE POINT OF ARMS 6-8. The validator does not restate the
# ai-dlc ownership regex; it reads it out of `settings-merge.sh`, which is the program that
# DEFINES it. That binding is only worth something if a broken extraction is loud, so the base
# tree carries a real copy of `settings-merge.sh` and three arms damage it in the three ways
# that matter: unextractable, too broad, and absent. All three must fail CLOSED (exit 2), not
# fall back to a private literal — a fallback would read exactly like a clean consumer.
#
# BOTH LAYOUTS. The fixture is three directories below the project root in the distribution
# (`core/fixtures/<x>/`) and on a consumer (`tests/fixtures/<x>/`), so the root is one
# expression; the two files it reaches for are then named at BOTH of their install paths
# rather than found by walking sideways from one another (invariant I33).
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the check regressed, 2 = fixture broken.

set -uo pipefail

# The validator inherits every AI_DLC_* tunable a consumer set in settings.json, and one of
# them — AI_DLC_PROJECT_ROOT — overrides the `--root` resolution this fixture depends on. A
# leaked value would pin every arm to the same tree and turn twelve comparisons green against
# a check that never looked at the seeded state. CLAUDE_PROJECT_DIR is scrubbed for the same
# reason one step over: it is the next fallback in the same chain.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset CLAUDE_PROJECT_DIR

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
[ -n "$ROOT" ] || { echo "hook-registration-join: FIXTURE BROKEN — cannot resolve project root from $HERE" >&2; exit 2; }

pick() { for p in "$@"; do [ -f "$ROOT/$p" ] && { printf '%s\n' "$ROOT/$p"; return 0; }; done; return 1; }

VALIDATOR="$(pick core/scripts/validate-hook-registration.sh scripts/ai-dlc/validate-hook-registration.sh)" || {
  echo "hook-registration-join: FIXTURE BROKEN — validate-hook-registration.sh is at neither core/scripts/ nor scripts/ai-dlc/ under $ROOT" >&2; exit 2; }
MERGE="$(pick core/skills/ai-dlc-update/reconcile/settings-merge.sh .claude/skills/ai-dlc-update/reconcile/settings-merge.sh)" || {
  echo "hook-registration-join: FIXTURE BROKEN — settings-merge.sh is at neither core/skills/ nor .claude/skills/ under $ROOT" >&2; exit 2; }

command -v python3 >/dev/null 2>&1 || { echo "hook-registration-join: FIXTURE BROKEN — python3 absent; the validator needs it" >&2; exit 2; }

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

fails=0
ok()  { echo "  ok    $*"; }
bad() { echo "  FAIL  $*" >&2; fails=$((fails + 1)); }

# --- the unmutated base: two ai-dlc hooks, both registered, plus a third-party block ---------
#
# `context-mode-decoy.sh` is present and deliberately unregistered. It is not ours, so the
# validator must not see it at all — an arm that counted every file under .claude/hooks/ would
# fail every consumer that has a second tool installed, and the ownership pattern is exactly
# what prevents that.
seed() { # seed <dir>
  local d="$1"
  mkdir -p "$d/.claude/hooks" "$d/.claude/skills/ai-dlc-update/reconcile"
  for h in ai-dlc-alpha.sh ai-dlc-beta.sh context-mode-decoy.sh; do
    printf '#!/bin/bash\nexit 0\n' > "$d/.claude/hooks/$h"; chmod +x "$d/.claude/hooks/$h"
  done
  cp "$MERGE" "$d/.claude/skills/ai-dlc-update/reconcile/settings-merge.sh"
  cat > "$d/.claude/settings.json" <<'JSON'
{
  "permissions": { "allow": ["Bash(ls:*)"] },
  "hooks": {
    "SessionStart": [
      { "hooks": [ { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/ai-dlc-alpha.sh" } ] },
      { "hooks": [ { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/context-mode-decoy.sh" } ] }
    ],
    "PreToolUse": [
      { "matcher": "Edit|Write", "hooks": [ { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/ai-dlc-beta.sh" } ] }
    ]
  }
}
JSON
}

# mutate <dir> <relative-file> <python-transform-name> — copy-then-edit, guarded by cmp -s.
# The guard is the rule: a transform that matched nothing produces a mutant identical to the
# base, which passes the validator and scores as a kill it never earned.
apply_mut() { # apply_mut <file> <old> <new>
  local f="$1" old="$2" new="$3" tmp
  tmp="$(mktemp)"
  python3 - "$f" "$old" "$new" > "$tmp" <<'PY'
import sys
f, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(f, encoding="utf-8").read()
sys.stdout.write(s.replace(old, new))
PY
  if cmp -s "$tmp" "$f"; then rm -f "$tmp"; return 1; fi
  mv "$tmp" "$f"; return 0
}

run() { # run <dir> -> prints output, sets RC
  OUT="$(bash "$VALIDATOR" --root "$1" 2>&1)"; RC=$?
}

# --- arm 1: the unmutated control ------------------------------------------------------------
seed "$T/base"
run "$T/base"
if [ "$RC" = "0" ]; then ok "CONTROL: the unmutated base tree passes (every kill below is attributable)"
else bad "CONTROL: the unmutated base tree FAILED (rc=$RC) — every arm below is meaningless: $(printf '%s' "$OUT" | tr '\n' ' ')"; echo "hook-registration-join: FIXTURE BROKEN" >&2; exit 2; fi

# The control must also prove the third-party file was SEEN and correctly excluded, or "not
# reported" is indistinguishable from "not looked at".
case "$OUT" in
  *"present under .claude/hooks/: 2"*) ok "OWNERSHIP: the third-party hook is excluded from our side (2 counted, not 3)" ;;
  *) bad "OWNERSHIP: expected the population line to count exactly our 2 hooks; got: $(printf '%s' "$OUT" | tr '\n' ' ')" ;;
esac

# --- arm 2: a shipped hook is not registered — THE DEFECT ------------------------------------
cp -R "$T/base" "$T/m2"
apply_mut "$T/m2/.claude/settings.json" '$CLAUDE_PROJECT_DIR/.claude/hooks/ai-dlc-beta.sh' '$CLAUDE_PROJECT_DIR/.claude/hooks/ai-dlc-UNWIRED.sh' \
  || { echo "hook-registration-join: FIXTURE BROKEN — arm 2 mutation matched nothing" >&2; exit 2; }
run "$T/m2"
if [ "$RC" = "1" ] && grep -q 'ai-dlc-beta\.sh' <<<"$OUT"; then
  ok "DEFECT: a present-but-unregistered hook is named and fails (rc=1)"
else bad "DEFECT: a hook on disk with no registration did not fail by name (rc=$RC): $(printf '%s' "$OUT" | tr '\n' ' ')"; fi

# The SAME mutation must also raise the other direction: the settings now name a file that is
# not there. One tree, two findings, and the validator must state both rather than stopping.
if grep -q 'ai-dlc-UNWIRED\.sh' <<<"$OUT"; then
  ok "DANGLING: a registration naming an absent file is reported alongside, not instead"
else bad "DANGLING: the registration for a nonexistent hook was not reported: $(printf '%s' "$OUT" | tr '\n' ' ')"; fi

# --- arm 3: re-registering the same hook clears it — the finding is the registration ---------
cp -R "$T/m2" "$T/m3"
apply_mut "$T/m3/.claude/settings.json" 'ai-dlc-UNWIRED.sh' 'ai-dlc-beta.sh' \
  || { echo "hook-registration-join: FIXTURE BROKEN — arm 3 mutation matched nothing" >&2; exit 2; }
run "$T/m3"
if [ "$RC" = "0" ]; then ok "REVERSIBLE: restoring the registration clears the finding (rc=0) — it is the join, not the tree"
else bad "REVERSIBLE: restoring the registration left rc=$RC: $(printf '%s' "$OUT" | tr '\n' ' ')"; fi

# --- arm 4: the third-party hook may be unregistered without penalty ------------------------
cp -R "$T/base" "$T/m4"
apply_mut "$T/m4/.claude/settings.json" '$CLAUDE_PROJECT_DIR/.claude/hooks/context-mode-decoy.sh' '$CLAUDE_PROJECT_DIR/.claude/hooks/context-mode-gone.sh' \
  || { echo "hook-registration-join: FIXTURE BROKEN — arm 4 mutation matched nothing" >&2; exit 2; }
run "$T/m4"
if [ "$RC" = "0" ]; then ok "DECOY: another tool's hook, present and unregistered, is not our finding"
else bad "DECOY: a non-ai-dlc hook produced a finding (rc=$RC) — this fails every consumer with a second tool installed: $(printf '%s' "$OUT" | tr '\n' ' ')"; fi

# --- arm 5: settings.local.json is a registration Claude Code honours ------------------------
cp -R "$T/m2" "$T/m5"
cat > "$T/m5/.claude/settings.local.json" <<'JSON'
{ "hooks": { "PreToolUse": [ { "hooks": [ { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/ai-dlc-beta.sh" } ] } ] } }
JSON
run "$T/m5"
if grep -q 'settings\.local\.json' <<<"$OUT"; then
  ok "LOCAL: a registration in settings.local.json counts, and is named as per-machine"
else bad "LOCAL: settings.local.json was not consulted: $(printf '%s' "$OUT" | tr '\n' ' ')"; fi

# --- arms 6-8: the ownership pattern is BOUND to settings-merge.sh, and fails closed ---------
#
# A validator that carried its own copy of this regex would pass all three of these while
# measuring a set that no longer matches what the merge actually strips and re-appends.
SM=".claude/skills/ai-dlc-update/reconcile/settings-merge.sh"

cp -R "$T/base" "$T/m6"
apply_mut "$T/m6/$SM" 'ai-dlc-[^/]+' 'THE-PATTERN-IS-GONE' \
  || { echo "hook-registration-join: FIXTURE BROKEN — arm 6 mutation matched nothing" >&2; exit 2; }
run "$T/m6"
if [ "$RC" = "2" ]; then ok "BOUND: an unextractable ownership pattern fails CLOSED (rc=2), never falls back to a literal"
else bad "BOUND: settings-merge.sh lost its pattern and the check still returned rc=$RC — it is reading a private copy: $(printf '%s' "$OUT" | tr '\n' ' ')"; fi

cp -R "$T/base" "$T/m7"
apply_mut "$T/m7/$SM" 'ai-dlc-[^/]+\\.sh' '(ai-dlc-[^/]+|[^/]+)\\.sh' \
  || { echo "hook-registration-join: FIXTURE BROKEN — arm 7 mutation matched nothing" >&2; exit 2; }
run "$T/m7"
if [ "$RC" = "2" ]; then ok "BOUND: a pattern broadened to match a NON-ai-dlc command fails CLOSED (the negative probe fires)"
else bad "BOUND: a pattern that also owns third-party hooks was accepted (rc=$RC) — the negative probe is not running: $(printf '%s' "$OUT" | tr '\n' ' ')"; fi

cp -R "$T/base" "$T/m8"
rm -f "$T/m8/$SM"
run "$T/m8"
if [ "$RC" = "2" ]; then ok "BOUND: an absent settings-merge.sh fails CLOSED rather than guessing the pattern"
else bad "BOUND: the pattern source was deleted and the check returned rc=$RC: $(printf '%s' "$OUT" | tr '\n' ' ')"; fi

# --- arm 9: an unreadable settings.json is not a pass ----------------------------------------
cp -R "$T/base" "$T/m9"
printf '{ "hooks": ' > "$T/m9/.claude/settings.json"
run "$T/m9"
if [ "$RC" = "2" ]; then ok "UNREADABLE: malformed settings.json fails CLOSED — an unknown must not read as a clean"
else bad "UNREADABLE: malformed settings.json returned rc=$RC: $(printf '%s' "$OUT" | tr '\n' ' ')"; fi

# --- arm 10: a tree with no settings.json is SKIPPED IN WORDS, and the skip is not hiding a red
#
# The paired control is the whole assertion: a silent 0 on a tree that WOULD fail is the
# check-that-cannot-fire class, so the same hook set is run both ways.
cp -R "$T/m2" "$T/m10"
mv "$T/m10/.claude/settings.json" "$T/m10/.claude/settings.json.moved"
run "$T/m10"
if [ "$RC" = "0" ] && grep -q 'SKIP' <<<"$OUT"; then
  mv "$T/m10/.claude/settings.json.moved" "$T/m10/.claude/settings.json"
  run "$T/m10"
  if [ "$RC" = "1" ]; then ok "SKIP: a tree with no settings.json says SKIP in words, and the SAME tree with it goes red"
  else bad "SKIP: the control tree did not go red once settings.json was restored (rc=$RC) — the skip arm proves nothing"; fi
else bad "SKIP: a tree with no settings.json did not report SKIP (rc=$RC): $(printf '%s' "$OUT" | tr '\n' ' ')"; fi

# --- arm 11: the AUTHORING side — every hook core ships is registered in the template ---------
#
# Arms 1-10 are about a consumer's tree. This one is about the distribution's: a new
# `core/hooks/ai-dlc-<x>.sh` added without a matching block in
# `templates/settings.json.template` is born inert and ships that way to every fresh install.
#
# `templates/` is NOT installed onto a consumer, so this arm has no subject there. It says so
# by name rather than passing silently — an arm that is not applicable and an arm that found
# nothing print the same thing otherwise, which is the defect this whole fixture is about.
if [ -f "$ROOT/templates/settings.json.template" ] && [ -d "$ROOT/core/hooks" ]; then
  # The heredoc is redirected to a file rather than wrapped in `$(...)`: bash 3.2 — the
  # macOS default, and the floor this repo targets — mis-scans quotes inside a heredoc that
  # sits in a command substitution, and this script is `#!/usr/bin/env bash`. The failure is
  # a parse error at EOF, which is loud; the reason it is worth a comment is that the obvious
  # fix (rewrite the regex to avoid the quote) would work here and break again on the next
  # edit that reintroduces one.
  python3 - "$ROOT" > "$T/a11.out" 2>&1 <<'PY'
import glob, json, os, re, sys
root = sys.argv[1]
shipped = {os.path.basename(p) for p in glob.glob(os.path.join(root, "core/hooks/ai-dlc-*.sh"))}
# A SOURCED LIBRARY IS NOT A HOOK, AND THE EXEMPTION IS DERIVED FROM THE OTHER SIDE OF THE JOIN
# RATHER THAN NAMED. core/hooks/ holds one file no event invokes: the emitting hooks `.`-source
# it as a sibling. Registering it would wire every consumer's settings to a command that reads
# no stdin and decides nothing. A hand-written skip list would exempt it by NAME, so deleting
# the last `source` of a library would leave the exemption behind and this arm would then permit
# a genuinely unregistered hook. Keying on "some sibling sources it" means a library nothing
# sources is scored as an unregistered hook again, automatically, on the commit that orphans it.
# I13 in scripts/validate-enforcement-map.sh derives the same set the same way.
sourced = set()
for p in glob.glob(os.path.join(root, "core/hooks/*.sh")):
    for line in open(p, encoding="utf-8"):
        if "BASH_SOURCE" not in line:
            continue
        sourced.update(re.findall(r"/([a-z0-9.-]+\.sh)", line))
shipped -= sourced
doc = json.load(open(os.path.join(root, "templates/settings.json.template"), encoding="utf-8"))
cmds = []
def walk(n):
    if isinstance(n, dict):
        for k, v in n.items():
            cmds.append(v) if k == "command" and isinstance(v, str) else walk(v)
    elif isinstance(n, list):
        for v in n: walk(v)
walk(doc.get("hooks", {}))
reg = {m.rsplit("/", 1)[-1] for c in cmds for m in re.findall(r'/\.claude/hooks/ai-dlc-[^/\s"\']+\.sh', c)}
if not shipped or not reg:
    # Fails closed for this repo's stated reason: every member of a set compared against
    # an empty one agrees with it, so an empty side is a pass nobody earned.
    print("ZERO shipped=%d registered=%d — one side is empty, so agreement would be vacuous"
          % (len(shipped), len(reg)))
elif shipped == reg:
    print("CLEAN %d hook(s), both sides identical" % len(shipped))
else:
    print("DISAGREE shipped-but-unregistered=[%s] registered-but-not-shipped=[%s]"
          % (",".join(sorted(shipped - reg)) or "none", ",".join(sorted(reg - shipped)) or "none"))
PY
  a11="$(cat "$T/a11.out")"
  a11_verdict="${a11%% *}"
  if [ "$a11_verdict" = "CLEAN" ]; then
    ok "AUTHORING: core/hooks/ and settings.json.template name the same set — ${a11#CLEAN }"
  elif [ "$a11_verdict" = "DISAGREE" ]; then
    bad "AUTHORING: ${a11#DISAGREE } — a hook the template does not name is born inert and ships that way to every fresh install; a template block naming a hook core no longer ships is a registration Claude Code cannot run."
  else
    bad "AUTHORING: the join could not be computed — $a11"
  fi
else
  echo "  n/a   AUTHORING: templates/settings.json.template is not in this layout (it is not installed onto a consumer) — arm not run, and not counted as passed"
fi

echo
if [ "$fails" -eq 0 ]; then echo "hook-registration-join: PASS"; exit 0; fi
echo "hook-registration-join: $fails assertion(s) FAILED" >&2
exit 1
