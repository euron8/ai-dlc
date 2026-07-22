#!/usr/bin/env bash
# validator-path-resolution — assert every core validator behaves IDENTICALLY when it
# lives in scripts/ai-dlc/ and when it lives in scripts/.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the check regressed, 2 = fixture broken.
#
# THE DEFECT THIS EXISTS TO CATCH.
#
# v0.126.0 moved the ~25 core validators from scripts/ to scripts/ai-dlc/ so the core
# boundary could enumerate them. Four of them derived the project root as
# `dirname($0)/..` — correct at scripts/X, and one level short at scripts/ai-dlc/X,
# where it resolves to <root>/scripts. Same tree, same script, same commit:
#
#   from scripts/         DORMANT: gate 'build' ...  Scanned 1 retros   rc=1
#   from scripts/ai-dlc/  Scanned 0 retros, 0 gates declared, 0 dormant  rc=0
#
# That is the check-that-cannot-fire class in its purest form: the relocated copy
# scanned an empty tree, found nothing wrong, and exited 0. Nothing on screen
# distinguished it from a clean repo.
#
# Not one of the 51 fixtures caught it, and the reason is structural: they all invoke
# validators from the DISTRIBUTION layout (core/scripts/X) with an explicit --root.
# Passing --root is exactly what makes self-location irrelevant, so the entire suite
# was blind to where a validator thinks it is. This fixture is the only one that runs
# them the way a consumer does — from their installed path, with no --root.
#
# WHY THE MUTANT IS AN ENV VAR AND NOT A SED.
#
# Asserting "the two locations agree" proves nothing about a script that never
# consults its own location — it would agree trivially, and pass forever. So every
# script is also run with AI_DLC_PROJECT_ROOT pointed at <root>/scripts, which is the
# precise wrong answer the old two-hop code computed. If that run is indistinguishable
# from the correct one, the script is not path-sensitive under this invocation and the
# agreement above is vacuous — the fixture says so, by name, and requires the four
# known-affected scripts to be sensitive.

set -uo pipefail

# The validators inherit every AI_DLC_* tunable a consumer set in settings.json, and
# this fixture's whole subject is which root they resolve. A leaked AI_DLC_PROJECT_ROOT
# or AI_DLC_CI_SURFACE would pin every run to the same answer and turn the comparison
# green against a script that is broken.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset CLAUDE_PROJECT_DIR

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"

for cand in "$ROOT/core/scripts" "$ROOT/.claude/scripts"; do
  [ -d "$cand" ] && SRC="$cand" && break
done
[ -n "${SRC:-}" ] || { echo "FIXTURE ERROR: core scripts directory not found" >&2; exit 2; }
for cand in "$ROOT/core/schemas" "$ROOT/.claude/schemas"; do
  [ -d "$cand" ] && SCHEMAS="$cand" && break
done
[ -n "${SCHEMAS:-}" ] || { echo "FIXTURE ERROR: schemas directory not found" >&2; exit 2; }

WORK="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd)"
trap 'rm -rf "$WORK"' EXIT

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

# --- a minimal installed consumer ----------------------------------------------
# .git is the walk-up marker. .claude/ carries the schemas and agent-read docs a
# consumer install lays down; docs/retro and .github/workflows give the gate
# validators something real to disagree about.
mkdir -p "$WORK/.git" \
         "$WORK/.claude/schemas" "$WORK/.claude/skills/ai-dlc" "$WORK/.claude/team-roles" \
         "$WORK/docs/retro" "$WORK/.github/workflows" \
         "$WORK/scripts/ai-dlc" || exit 2
cp "$SCHEMAS"/*.json "$WORK/.claude/schemas/" 2>/dev/null || {
  echo "FIXTURE ERROR: no schemas to copy from $SCHEMAS" >&2; exit 2; }

# A declared-but-dormant gate: docs/retro names it, no workflow references it. A
# validator that reads the right tree MUST report it; one reading <root>/scripts
# sees an empty world and says "0 dormant".
printf 'CI gate `build-and-test`\n' > "$WORK/docs/retro/sprint-1.md"
printf 'name: unrelated\non: push\n' > "$WORK/.github/workflows/unrelated.yml"

# Install every core validator into BOTH layouts: the pre-v0.126.0 consumer path and
# the current one. Derived from the directory, never hand-listed — a validator added
# later is covered the day it ships, which is the property a hand-list cannot have.
n_installed=0
for f in "$SRC"/*.sh; do
  [ -f "$f" ] || continue
  cp "$f" "$WORK/scripts/" && cp "$f" "$WORK/scripts/ai-dlc/" || exit 2
  n_installed=$((n_installed + 1))
done
[ "$n_installed" -ge 10 ] || {
  echo "FIXTURE ERROR: only $n_installed core scripts found in $SRC" >&2; exit 2; }

# --- invocation table ----------------------------------------------------------
# Default is a bare run. Overrides exist for two reasons only:
#   - sync-taught-schema.sh defaults to WRITE mode, and a writer's second run
#     legitimately differs from its first, so it is pinned to --check;
#   - several validators parse arguments BEFORE they resolve a schema, so a bare run
#     exits at the usage line and never reaches the code under test. That is not a
#     pass, it is a question never asked — the mutant check below names it as such.
mkdir -p "$WORK/docs/stories" || exit 2
printf '# artifact\n' > "$WORK/docs/artifact.md"
printf '# terminal pass\n' > "$WORK/docs/pass-p1.md"
printf '# story\n' > "$WORK/docs/stories/story-1.md"

argv_for() {
  case "$1" in
    sync-taught-schema.sh)          printf '%s' "--check" ;;
    validate-audit-anchors.sh)      printf '%s' "--render" ;;
    validate-gate-adjudication.sh)  printf '%s' "--expected implementation" ;;
    validate-provenance-block.sh)   printf '%s' "$WORK/docs/artifact.md" ;;
    stamp-story-provenance.sh)      printf '%s' "--terminal $WORK/docs/pass-p1.md --check $WORK/docs/stories/story-1.md" ;;
    *)                              printf '%s' "" ;;
  esac
}

# The seven the relocation actually broke. Each must prove path-sensitive below; if one
# stops being sensitive, its agreement assertion has gone vacuous and this fixture
# would otherwise keep reporting a pass it no longer earns.
#
# The first draft of this list held four — the four a hand investigation had found.
# Running the comparison over the whole directory produced validate-audit-anchors.sh
# on the first execution, and widening the argv table to reach past the usage lines
# produced validate-gate-adjudication.sh and validate-provenance-block.sh. Three of the
# seven were invisible to reading; that is the argument for deriving the subject list
# from the directory rather than from what an investigation happened to notice.
SENSITIVE_REQUIRED="validate-ci-gates.sh sprint-status.sh stamp-story-provenance.sh sync-taught-schema.sh validate-audit-anchors.sh validate-gate-adjudication.sh validate-provenance-block.sh"

# Normalize the one difference that is legitimate: the script's own path, which several
# validators echo in their usage text. Longest prefix first.
norm() {
  sed -e "s@$WORK/scripts/ai-dlc@SCRIPTDIR@g" \
      -e "s@$WORK/scripts@SCRIPTDIR@g" \
      -e "s@$WORK@PROJECT@g"
}

run_one() { # run_one <layout-dir> <script-name> <wrong-root|""> -> "rc=<n>\n<output>"
  local dir="$1" name="$2" out rc
  out="$(cd "$WORK" && AI_DLC_PROJECT_ROOT="${3:-}" bash "$WORK/$dir/$name" $(argv_for "$name") 2>&1)"
  rc=$?
  printf '%s\n' "rc=$rc"
  printf '%s\n' "$out" | norm
}

echo "validator-path-resolution"
echo "  installed $n_installed core script(s) into scripts/ and scripts/ai-dlc/"
echo ""

sensitive_list=""
inert_list=""

for f in "$SRC"/*.sh; do
  name="$(basename "$f")"

  legacy="$(run_one "scripts"        "$name")"
  current="$(run_one "scripts/ai-dlc" "$name")"

  # THE ASSERTION. Same tree, same argv, same cwd — only the install path differs.
  if [ "$legacy" = "$current" ]; then
    ok "$name agrees from scripts/ and scripts/ai-dlc/"
  else
    bad "$name DIVERGES between layouts"
    printf '        scripts/       : %s\n' "$(printf '%s' "$legacy"  | tr '\n' '|' | cut -c1-160)"
    printf '        scripts/ai-dlc/: %s\n' "$(printf '%s' "$current" | tr '\n' '|' | cut -c1-160)"
  fi

  # THE MUTANT. <root>/scripts is exactly what `dirname($0)/..` computed from the new
  # location. A script that answers the same either way did not consult the root.
  mutant="$(run_one "scripts/ai-dlc" "$name" "$WORK/scripts")"
  if [ "$mutant" != "$current" ]; then
    sensitive_list="$sensitive_list $name"
  else
    inert_list="$inert_list $name"
  fi
done

echo ""
# --- non-vacuity ---------------------------------------------------------------
for want in $SENSITIVE_REQUIRED; do
  case " $sensitive_list " in
    *" $want "*) ok "MUTANT: $want changes behaviour when the root is wrong (its agreement is real)" ;;
    *) bad "MUTANT: $want ignored a wrong project root — its agreement assertion proves nothing" ;;
  esac
done

n_sensitive=$(printf '%s' "$sensitive_list" | wc -w | tr -d ' ')
n_inert=$(printf '%s' "$inert_list" | wc -w | tr -d ' ')
echo ""
echo "  path-sensitive under this invocation: $n_sensitive"
echo "  not path-sensitive (agreement is trivially true for these): $n_inert"
echo "   ${inert_list# }"

echo ""
if [ "$fails" -eq 0 ]; then
  echo "validator-path-resolution: PASS"
  exit 0
fi
echo "validator-path-resolution: FAIL ($fails assertion(s))"
exit 1
