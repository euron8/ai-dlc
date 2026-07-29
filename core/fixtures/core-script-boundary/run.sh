#!/usr/bin/env bash
# core-script-boundary — assert the core validators are protected at edit time, and
# that the consumer's own scripts are not.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the check regressed, 2 = fixture broken.
#
# THE DEFECT THIS EXISTS TO CATCH.
#
# ai-dlc-core-guard.sh derives its deny set from core-manifest.md and hand-lists
# nothing, which is right. But `scripts/*` was never IN the manifest, so the core
# validators -- the machinery every gate's teeth depend on -- were the one part of
# core a consumer could edit in place. Two of them had been, in the reference
# consumer, and neither edit was ever filed as a push candidate. An edited enforcer
# is a weakened gate: every check that cites it is only as good as the copy on disk.
#
# It could not simply be globbed in. `scripts/` is SHARED: the reference consumer's
# copy holds well over a hundred loose files, most of them theirs, and no prefix
# separates them -- ai-dlc ships `audit-rule-files.sh` while the consumer owns
# `audit-dormant-gates.sh`, `audit-main-since.sh` and `audit-rule-exercise.sh`. A
# `scripts/audit-*` glob denies the consumer's own files; that is the trap
# `hooks/*.sh` hit before v0.106.0 narrowed it to `hooks/ai-dlc-*.sh`.
#
# So v0.126.0 gave the core scripts a directory of their own and enumerated its
# contents, and v0.160.0 let the manifest claim the directory whole
# (`scripts/ai-dlc/*`) once the relocation had made that expressible.
#
# Assertions 2-4 are the half that matters: the boundary must be silent on
# everything that is not ours, including the names that collide. Assertion 8 pins
# the one behaviour the glob changed.

set -uo pipefail

# The pre-push gate inherits every AI_DLC_* tunable a consumer set in settings.json.
# A fixture that invokes a hook must scrub them, or a consumer who tunes one fails
# this fixture -- and blocks every push -- against a hook behaving correctly.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"

for cand in "$ROOT/core/hooks/ai-dlc-core-guard.sh" \
            "$ROOT/.claude/hooks/ai-dlc-core-guard.sh"; do
  [ -f "$cand" ] && GUARD="$cand" && break
done
[ -n "${GUARD:-}" ] || { echo "FIXTURE ERROR: ai-dlc-core-guard.sh not found" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "FIXTURE ERROR: jq not on PATH" >&2; exit 2; }

WORK="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd)"
trap 'rm -rf "$WORK"' EXIT

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

# A minimal layered consumer: the guard's activation gate needs all three.
mkdir -p "$WORK/.claude/skills/ai-dlc/overrides" \
         "$WORK/.claude/skills/ai-dlc/extensions" \
         "$WORK/scripts/ai-dlc" "$WORK/scripts/ai-dlc-local" || exit 2
: > "$WORK/.claude/.ai-dlc-version"

# The manifest the guard derives from. Deliberately a SMALL hand-written stand-in
# rather than a copy of the real one: this fixture tests the boundary mechanism, not
# the real file's contents. Two LITERAL script entries, which the shipped manifest no
# longer uses -- that is the point. Assertions 1-4 prove the guard consults the list;
# assertion 8 swaps in the shipped `scripts/ai-dlc/*` form and proves the two shapes
# reach opposite answers on the same path.
cat > "$WORK/.claude/skills/ai-dlc/core-manifest.md" <<'MANIFEST'
<!-- CORE_MANIFEST v1 -->
```yaml
core_manifest:
  - SKILL.md
  - steps/*.md
  - hooks/ai-dlc-*.sh
  - scripts/ai-dlc/verdict.sh
  - scripts/ai-dlc/audit-rule-files.sh
```
MANIFEST

# setup-sites.md must exist or the guard FAILS OPEN on every core file, by design:
# without the site manifest it cannot tell a declared /ai-dlc-setup config fill (a
# team-role model string, a deploy command) from a rulebook edit, and wedging setup
# is worse than missing one edit. A tree without it is not a tree this fixture can
# measure -- the first draft omitted it and every deny assertion read as allow.
mkdir -p "$WORK/.claude/skills/ai-dlc-update/reconcile" || exit 2
cat > "$WORK/.claude/skills/ai-dlc-update/reconcile/setup-sites.md" <<'SITES'
# Setup sites
No config regions are declared for this fixture, so every core edit routes to a
deny. Validators have no config region in the real file either.
SITES

# An ALLOW is the guard exiting 0 with NO output at all -- not a JSON document
# saying "allow". Piping straight into jq makes that indistinguishable from a
# crash, because jq on empty input prints nothing and the `// "allow"` default
# never runs. The first draft of this fixture did exactly that and reported all
# eleven assertions failing against a guard that was working.
guard_out() { # guard_out <tool> <project-relative-path>
  printf '{"tool_name":"%s","tool_input":{"file_path":"%s/%s"}}' "$1" "$WORK" "$2" \
    | CLAUDE_PROJECT_DIR="$WORK" bash "$GUARD" 2>/dev/null
}

decision() { # decision <project-relative-path> [tool] -> deny | allow
  local out; out="$(guard_out "${2:-Edit}" "$1")"
  [ -n "$out" ] || { echo allow; return; }
  printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // "allow"'
}

expect() { # expect <want> <path> <label>
  local got; got="$(decision "$2")"
  [ "$got" = "$1" ] && ok "$3" || bad "$3 -- expected $1, got $got"
}

echo "core-script-boundary"

# --- 1. A core validator is refused --------------------------------------------
expect deny "scripts/ai-dlc/verdict.sh" "a core validator in scripts/ai-dlc/ is denied"

# --- 2. THE CONSUMER'S OWN SCRIPTS ARE NOT TOUCHED -----------------------------
# The half that decides whether this boundary is usable. A guard that also denies
# the consumer's tooling gets turned off, and takes the real protection with it.
expect allow "scripts/deploy.sh"            "a consumer script in scripts/ is allowed"
expect allow "scripts/ai-dlc-local/reset.sh" "a consumer script in scripts/ai-dlc-local/ is allowed"

# --- 3. A COLLIDING BASENAME IS STILL THE CONSUMER'S ---------------------------
# `audit-rule-files.sh` IS core. `audit-dormant-gates.sh` and `audit-rule-exercise.sh`
# are the reference consumer's, and share its prefix. Directory decides, never name.
expect deny  "scripts/ai-dlc/audit-rule-files.sh"  "core audit-rule-files.sh is denied"
expect allow "scripts/audit-rule-files.sh"         "the SAME basename outside scripts/ai-dlc/ is allowed"
expect allow "scripts/audit-dormant-gates.sh"      "a consumer script sharing the prefix is allowed"
expect allow "scripts/audit-rule-exercise.sh"      "  and another one"

# --- 4. THE MANIFEST IS THE AUTHORITY, NOT THE DIRECTORY NAME -------------------
# Under the LITERAL stub manifest above, a file in the core directory that the list
# does not name goes allow. This is the assertion that proves the guard is reading
# the manifest at all rather than pattern-matching the directory name -- without it,
# assertion 1's deny could come from anywhere. The shipped manifest reaches the
# opposite answer on this same path; assertion 8 asserts that.
expect allow "scripts/ai-dlc/not-in-manifest.sh" \
  "under a LITERAL manifest, a script in the core dir but absent from the list is NOT denied"

# --- 5. The deny message routes to the VALIDATOR arm ---------------------------
# The generic arm sends the reader to overrides/ or extensions/. Neither exists for
# machinery, so the generic text is actively wrong advice here -- it would send a
# consumer to build a shadow entry that nothing reads.
reason="$(guard_out Edit scripts/ai-dlc/verdict.sh | jq -r '.hookSpecificOutput.permissionDecisionReason')"
if grep -q 'CORE validator' <<<"$reason" \
   && grep -q 'ai-dlc-local' <<<"$reason"; then
  ok "the deny names it a validator and points consumer scripts at scripts/ai-dlc-local/"
else
  bad "the deny fell through to the generic overrides/extensions text -- wrong advice for machinery"
fi

# --- 6. Non-edit tools are still out of scope ----------------------------------
# apply.sh writes core through the shell on every pull. If the guard denied Bash it
# would wedge the update itself.
got="$(decision scripts/ai-dlc/verdict.sh Bash)"
[ "$got" = "allow" ] && ok "Bash is out of scope (the pull writes core through the shell)" \
                     || bad "Bash was denied ($got) -- /ai-dlc-update cannot write core"

# --- 7. THE MUTATION TEST — prove assertion 1's deny is the manifest entry's ----
# Drop the scripts/ arm from to_consumer_glob() on a COPY. The entry then resolves
# to .claude/skills/ai-dlc/scripts/ai-dlc/verdict.sh, matches nothing, and the real
# path goes allow. If it still denied, something else was producing the deny.
MUTANT="$WORK/mutant.sh"
sed "s@^    scripts/\*)        printf '%s\\\\n' \"\$e\" ;;@    scripts/DISABLED*) : ;;@" "$GUARD" > "$MUTANT" || exit 2
if cmp -s "$GUARD" "$MUTANT"; then
  echo "FIXTURE ERROR: mutation matched nothing -- to_consumer_glob's scripts/ arm was rewritten" >&2
  exit 2
fi
mout="$(printf '{"tool_name":"Edit","tool_input":{"file_path":"%s/scripts/ai-dlc/verdict.sh"}}' "$WORK" \
  | CLAUDE_PROJECT_DIR="$WORK" bash "$MUTANT" 2>/dev/null)"
if [ -z "$mout" ]; then got=allow; else got="$(printf '%s' "$mout" | jq -r '.hookSpecificOutput.permissionDecision // "allow"')"; fi
[ "$got" = "allow" ] && ok "MUTATION: removing the scripts/ path arm makes assertion 1 go allow" \
                     || bad "MUTATION: still $got without the scripts/ arm -- assertion 1 proves nothing"

# --- 8. THE SHIPPED GLOB FORM CLAIMS THE WHOLE DIRECTORY ------------------------
# v0.160.0 replaced the manifest's 27 filenames with `scripts/ai-dlc/*`. Under that
# entry the DIRECTORY is the answer and a file the distribution never shipped is
# denied too -- the same path assertion 4 sees allowed. That is the deliberate trade
# the enumeration was retired for: the list used to detect a consumer file squatting
# in our directory (measured across the reference consumer's installed validators:
# zero, ever), and the glob instead denies the edit AND the Write that would create
# it, routing the author to scripts/ai-dlc-local/ -- which is where the file belonged.
# Asserted here so the trade is a tested property rather than a changelog claim.
#
# Last, because it overwrites the manifest every assertion above depends on.
cat > "$WORK/.claude/skills/ai-dlc/core-manifest.md" <<'GLOBMANIFEST'
<!-- CORE_MANIFEST v1 -->
```yaml
core_manifest:
  - SKILL.md
  - hooks/ai-dlc-*.sh
  - scripts/ai-dlc/*
```
GLOBMANIFEST
expect deny  "scripts/ai-dlc/not-in-manifest.sh" \
  "under the shipped glob entry, ANY file in scripts/ai-dlc/ is denied"
expect allow "scripts/audit-rule-files.sh" \
  "  and the glob still stops at the directory boundary"
got="$(decision scripts/ai-dlc/brand-new.sh Write)"
[ "$got" = "deny" ] && ok "  and a Write that would CREATE a squatter is denied too" \
                    || bad "  a Write creating scripts/ai-dlc/brand-new.sh was $got -- a squatter can still be planted through the editor"

echo ""
if [ "$fails" -eq 0 ]; then
  echo "core-script-boundary: PASS"
  exit 0
fi
echo "core-script-boundary: FAIL ($fails assertion(s))"
exit 1
