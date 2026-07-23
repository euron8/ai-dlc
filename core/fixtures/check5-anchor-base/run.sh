#!/usr/bin/env bash
# check5-anchor-base — prove mandatory-rules Check 5 FIRES at retro time by diffing from the
# prior-sprint audit-anchor SHA, not main..HEAD (which is empty on a retro branch cut from
# main after the sprint merged — the CANNOT-FIRE bug), and that removing the anchor base
# reintroduces the SKIP.
#
# THE DEFECT THIS EXISTS TO CATCH. Check 5 diffed main..HEAD. At retro time the sprint's
# web/** changes are ancestors of main, so main..HEAD is empty and Check 5 SKIPped every
# sprint — a check that cannot fire reads exactly like one that passed. The fix resolves the
# base from audit-anchors.md's prior-sprint SHA so [anchor..HEAD] is the sprint's real change
# set. The scenario below has the web change ALREADY merged to main (main..HEAD empty), so
# only the anchor base can see it.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"

if   [ -n "$ROOT" ] && [ -f "$ROOT/core/scripts/validate-mandatory-rules.sh" ]; then
  VMR="$ROOT/core/scripts/validate-mandatory-rules.sh"
elif [ -n "$ROOT" ] && [ -f "$ROOT/scripts/ai-dlc/validate-mandatory-rules.sh" ]; then
  VMR="$ROOT/scripts/ai-dlc/validate-mandatory-rules.sh"
else
  echo "FIXTURE ERROR: validate-mandatory-rules.sh not found in either layout" >&2
  exit 2
fi
command -v git >/dev/null 2>&1 || { echo "FIXTURE ERROR: git not on PATH" >&2; exit 2; }
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

WORK="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd)"
trap 'rm -rf "$WORK"' EXIT

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

# Isolated toolchain dir: the real validator + no-op sibling stubs so Checks 1/2 do not
# interfere with the Check 5 line we read. Check 5 reads audit-anchors/gate-log/git from CWD.
mkdir -p "$WORK/bin"
cp "$VMR" "$WORK/bin/validate-mandatory-rules.sh"
printf '#!/bin/sh\nexit 0\n' > "$WORK/bin/validate-retro-evidence.sh"
printf '#!/bin/sh\nexit 0\n' > "$WORK/bin/validate-cycle-commits.sh"
chmod +x "$WORK/bin/validate-retro-evidence.sh" "$WORK/bin/validate-cycle-commits.sh"

cd "$WORK" || exit 2
git -c init.defaultBranch=main init -q . 2>/dev/null || { echo "FIXTURE ERROR: git init failed" >&2; exit 2; }
git config user.email f@example.com; git config user.name Fixture; git config commit.gpgsign false
mkdir -p _bmad-output/implementation-artifacts

echo "seed" > seed.txt; git add -A && git commit -q -m "prior sprint boundary"; git branch -M main
PRIOR_SHA="$(git rev-parse HEAD)"

# The sprint's web change, merged to main (so main..HEAD will be empty on the retro branch).
mkdir -p web/src; echo "console.log('ui')" > web/src/app.js
git add -A && git commit -q -m "Sprint 900 web change"

# audit-anchors.md: prior sprint 899 -> the boundary SHA (mandatory-rules reads PRIOR_SPRINT = 899).
printf -- '- sprint: 899\n  sha: %s\n' "$PRIOR_SHA" > _bmad-output/audit-anchors.md

# Retro branch == main tip: main..HEAD is empty; PRIOR_SHA..HEAD carries the web change.
git checkout -q -b ai-dlc/retro/sprint-900

GATE_LOG="_bmad-output/implementation-artifacts/gate-log.md"
write_gatelog() {  # <notes-cell>
  printf '## Gate Log: Sprint 900\n\n| Gate | Result | Notes |\n|------|--------|-------|\n| Deploy Status Report | PASS | %s |\n' "$1" > "$GATE_LOG"
}
check5_line() { ( cd "$WORK" && bash "$1" 900 2>/dev/null ) | grep -i 'CHECK 5:' | head -1; }

echo "check5-anchor-base"

# --- 1. web changed (anchor base) + NO visual evidence -> Check 5 FIRES and FAILs ---
write_gatelog "deploy completed"
L="$(check5_line "$WORK/bin/validate-mandatory-rules.sh")"
if echo "$L" | grep -qi 'CHECK 5: FAIL'; then
  ok "fires and FAILs on a web/** change with no visual evidence (main..HEAD would have SKIPped)"
else
  bad "Check 5 did not fire+FAIL — got: ${L:-<no CHECK 5 line>}"
fi

# --- 2. web changed + USER-CONFIRMED -> Check 5 PASS --------------------------
write_gatelog "USER-CONFIRMED visual verification captured"
L="$(check5_line "$WORK/bin/validate-mandatory-rules.sh")"
if echo "$L" | grep -qi 'CHECK 5: PASS'; then
  ok "PASSes with USER-CONFIRMED evidence in the sprint gate-log section"
else
  bad "Check 5 did not PASS with evidence — got: ${L:-<no CHECK 5 line>}"
fi

# --- 3. MUTATION: revert the base to main..HEAD -> Check 5 SKIPs (cannot fire) ---
MUTANT="$WORK/mbin/validate-mandatory-rules.sh"
mkdir -p "$WORK/mbin"
cp "$WORK/bin/validate-retro-evidence.sh" "$WORK/bin/validate-cycle-commits.sh" "$WORK/mbin/"
sed 's/${CHECK5_BASE}/main/g' "$WORK/bin/validate-mandatory-rules.sh" > "$MUTANT" || exit 2
if cmp -s "$WORK/bin/validate-mandatory-rules.sh" "$MUTANT"; then
  echo "FIXTURE ERROR: mutation matched nothing — the CHECK5_BASE reference was renamed" >&2
  exit 2
fi
write_gatelog "deploy completed"   # no evidence: under the anchor base this FAILs
L="$(check5_line "$MUTANT")"
if echo "$L" | grep -qi 'CHECK 5: SKIP'; then
  ok "MUTATION: reverting the base to main..HEAD makes Check 5 SKIP (the anchor base is what fires it)"
else
  bad "MUTATION: Check 5 did not SKIP on main..HEAD — got: ${L:-<no CHECK 5 line>}"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "check5-anchor-base: PASS"
  exit 0
fi
echo "check5-anchor-base: FAIL ($fails assertion(s))"
exit 1
