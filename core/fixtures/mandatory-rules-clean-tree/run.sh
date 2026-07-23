#!/usr/bin/env bash
# mandatory-rules-clean-tree — prove the --check-clean-tree subset entrypoint asserts the
# delegated toolchain floor (validate-retro-evidence.sh + validate-cycle-commits.sh) and
# nothing more: it PASSes with those two present even though validate-retro-prereq.sh is
# absent (consumer-provided), and FAILs when a REQUIRED sibling is missing.
#
# THE DEFECT THIS EXISTS TO CATCH. A clean-tree check that required retro-prereq (a
# consumer-provided sibling core does not ship) would FAIL on every stock install — a gate
# that can never pass. And a floor that never fails (does not check the required siblings)
# would pass a broken install; the mutation control below pins it.
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

WORK="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

# Isolated SCRIPT_DIR: the real validator + sibling stubs (--check-clean-tree tests
# existence only, never executes them). retro-prereq is deliberately absent.
mkdir -p "$WORK/bin"
cp "$VMR" "$WORK/bin/validate-mandatory-rules.sh"
: > "$WORK/bin/validate-retro-evidence.sh"
: > "$WORK/bin/validate-cycle-commits.sh"

echo "mandatory-rules-clean-tree"

# --- 1. toolchain floor present (retro-prereq ABSENT) -> PASS -----------------
bash "$WORK/bin/validate-mandatory-rules.sh" --check-clean-tree >"$WORK/out.txt" 2>&1
rc=$?
if [ "$rc" = "0" ] && grep -q 'toolchain present' "$WORK/out.txt"; then
  ok "PASSes with retro-evidence + cycle-commits present, retro-prereq absent (not part of the floor)"
else
  bad "clean-tree did not PASS with the toolchain floor present (exit $rc)"; sed 's/^/        /' "$WORK/out.txt"
fi

# --- 2. MUTATION: a REQUIRED sibling missing -> FAIL --------------------------
rm -f "$WORK/bin/validate-retro-evidence.sh"
bash "$WORK/bin/validate-mandatory-rules.sh" --check-clean-tree >"$WORK/out.txt" 2>&1
rc=$?
if [ "$rc" = "1" ] && grep -q 'toolchain incomplete' "$WORK/out.txt"; then
  ok "MUTATION: a missing required sibling FAILs (the floor is real, not vacuous)"
else
  bad "a missing required sibling did not FAIL (exit $rc)"; sed 's/^/        /' "$WORK/out.txt"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "mandatory-rules-clean-tree: PASS"
  exit 0
fi
echo "mandatory-rules-clean-tree: FAIL ($fails assertion(s))"
exit 1
