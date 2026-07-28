#!/usr/bin/env bash
# shadowed-local-validators — assert warn-shadowed-local-validators.sh flags a local
# validator fork ONLY when its ledger entry is CLOSED (ADOPTED UPSTREAM), the fork exists,
# AND it shadows a real core validator — and stays silent otherwise.
#
# THE DEFECT THIS EXISTS TO CATCH. The signal must fire on exactly one condition set. If it
# fired on OPEN entries it would nag about forks still doing real work; if it fired on a
# `.sh` token in prose with no fork it would be noise; if it fired on a fork that shadows no
# core validator it would be wrong. The mutation control proves the CLOSED gate is what
# suppresses open entries — without it, an open fork would be flagged too.
set -uo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT=""
for cand in \
  "$DIR/../../skills/ai-dlc-update/reconcile/warn-shadowed-local-validators.sh" \
  "$DIR/../../../core/skills/ai-dlc-update/reconcile/warn-shadowed-local-validators.sh" \
  "$DIR/../../../.claude/skills/ai-dlc-update/reconcile/warn-shadowed-local-validators.sh"; do
  [ -f "$cand" ] && SCRIPT="$cand" && break
done
[ -n "$SCRIPT" ] || { echo "FIXTURE ERROR: warn-shadowed-local-validators.sh not found" >&2; exit 2; }

WORK="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/local" "$WORK/core"

# The synthetic ledger: two closed entries, one open, in the heading shape the real ledger
# uses; one closed entry naming a tool with no core twin.
cat > "$WORK/ledger.md" <<'LED'
# Push-candidate ledger (fixture)

## PC-CLOSED-FOO — validate-foo.sh: divergence
Prose about core/scripts/validate-foo.sh.
verify: theirs_lacks core/scripts/validate-foo.sh "some-marker"
ADOPTED UPSTREAM (v0.130.0, verified 2026-07-22)

## PC-OPEN-BAR — validate-bar.sh: divergence
Prose about core/scripts/validate-bar.sh — still diverging.
verify: theirs_lacks core/scripts/validate-bar.sh "other-marker"

## PC-CLOSED-NOFORK — validate-nofork.sh: divergence
Prose about core/scripts/validate-nofork.sh.
ADOPTED UPSTREAM (v0.130.0)

## PC-CLOSED-NOCORE — some-tool.sh: consumer-only tool
Prose naming some-tool.sh.
ADOPTED UPSTREAM (v0.130.0)

## PC-CLOSED-SUB — validate-sub.sh: divergence
Prose about core/scripts/validate-sub.sh.
ADOPTED UPSTREAM (v0.130.0)
LED

# Forks the consumer carries.
for f in validate-foo.sh validate-bar.sh some-tool.sh validate-orphan.sh; do : > "$WORK/local/$f"; done
# A fork filed under a SUBDIRECTORY of the home. The home's internal layout is the
# consumer's — core declares the directory and claims nothing about its shape — so this is
# the ordinary way a consumer files a fork once the home holds more than a few scripts.
mkdir -p "$WORK/local/lib"
: > "$WORK/local/lib/validate-sub.sh"
# Core validators (what a fork must shadow to count).
for f in validate-foo.sh validate-bar.sh validate-nofork.sh validate-orphan.sh validate-sub.sh; do : > "$WORK/core/$f"; done

run_warn() { # run_warn <script>
  bash "$1" --root "$WORK" --ledger "$WORK/ledger.md" \
    --local-dir "$WORK/local" --core-dir "$WORK/core" 2>/dev/null
}

OUT="$(run_warn "$SCRIPT")"
fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1" >&2; fails=$((fails+1)); }
# The emitted path is the fork's REAL location, root-relative — here `local/…`, because
# that is where --local-dir points. Until v0.194.0 the script fabricated the string
# `scripts/ai-dlc-local/<basename>` no matter where --local-dir actually pointed or where
# under it the fork sat, so the row named a path that need not exist. Keying this fixture on
# the fabricated form is what let that ship: it asserted the constant, not the finding.
has() { printf '%s\n' "$OUT" | grep -q "	local/$1	"; }

echo "shadowed-local-validators:"

# CLOSED + fork + core shadow -> flagged.
has "validate-foo.sh" && ok "closed entry + fork + core shadow -> RETIRE-CANDIDATE (foo)" \
  || bad "validate-foo.sh not flagged — the one true positive is missing"
# OPEN entry -> not flagged.
has "validate-bar.sh" && bad "validate-bar.sh flagged despite an OPEN (not ADOPTED) entry" \
  || ok "open entry -> not flagged (bar)"
# Closed but no fork -> nothing to retire.
has "validate-nofork.sh" && bad "validate-nofork.sh flagged with no fork present" \
  || ok "closed entry but no fork -> not flagged (nofork)"
# Fork exists but shadows no core validator -> filtered (prose .sh token).
has "some-tool.sh" && bad "some-tool.sh flagged though it shadows no core validator" \
  || ok "fork with no core shadow -> not flagged (some-tool)"
# Orphan fork, no ledger entry -> not flagged.
has "validate-orphan.sh" && bad "validate-orphan.sh flagged with no ledger entry" \
  || ok "fork with no ledger entry -> not flagged (orphan)"

# A fork under a SUBDIRECTORY of the home -> flagged, at its real path.
has "lib/validate-sub.sh" && ok "a fork in a subdirectory of the home -> RETIRE-CANDIDATE at its real path (sub)" \
  || bad "validate-sub.sh not flagged — a fork filed below the home's top level is invisible, which reads exactly like a home with no forks in it"

# Never blocks.
run_warn "$SCRIPT" >/dev/null 2>&1
[ "$?" -eq 0 ] && ok "exit 0 (signal never blocks)" || bad "exit was not 0 — a signal must not block"

# MUTATION control: drop the CLOSED gate in flush() so EVERY entry emits its basenames.
# The OPEN bar fork must then be flagged — proving the ADOPTED-UPSTREAM gate is what
# suppresses open entries. A grep-based anti-vacuity: require the mutation to change the file.
MUT="$WORK/mutant.sh"
CHG="$(python3 - "$SCRIPT" "$MUT" <<'PY'
import sys
src, dst = sys.argv[1], sys.argv[2]
s = open(src, encoding="utf-8").read()
s2 = s.replace('if (closed && names != "")', 'if (names != "")')
open(dst, "w", encoding="utf-8").write(s2)
print("CHANGED" if s2 != s else "UNCHANGED")
PY
)"
if [ "$CHG" != "CHANGED" ]; then
  bad "MUTATION matched nothing — the closed-gate in flush() was renamed"
else
  MOUT="$(run_warn "$MUT")"
  if printf '%s\n' "$MOUT" | grep -q "	local/validate-bar.sh	"; then
    ok "MUTATION — dropping the CLOSED gate flags the OPEN bar fork too (the gate is load-bearing)"
  else
    bad "MUTATION — bar still not flagged without the CLOSED gate; the closed-only assertions prove nothing"
  fi
fi

# MUTATION control 2: bound the home walk to its top level, the pre-v0.194.0 shape. The
# subdirectory fork must then go unreported — proving the recursive walk is what finds it,
# and that the assertion above is not passing on some other arm. Single-arm: `foo` at the
# home's root stays flagged, so this cannot be confused with the fork-existence gate.
MUT2="$WORK/mutant-depth.sh"
CHG2="$(python3 - "$SCRIPT" "$MUT2" <<'PY'
import sys
src, dst = sys.argv[1], sys.argv[2]
s = open(src, encoding="utf-8").read()
s2 = s.replace('find "$LOCAL_DIR" -type f', 'find "$LOCAL_DIR" -maxdepth 1 -type f')
open(dst, "w", encoding="utf-8").write(s2)
print("CHANGED" if s2 != s else "UNCHANGED")
PY
)"
if [ "$CHG2" != "CHANGED" ]; then
  bad "MUTATION 2 matched nothing — the home walk is no longer a bare find over LOCAL_DIR"
else
  MOUT2="$(run_warn "$MUT2")"
  if printf '%s\n' "$MOUT2" | grep -q "	local/lib/validate-sub.sh	"; then
    bad "MUTATION 2 — the subdirectory fork is STILL reported with the walk bounded to depth 1; the assertion above proves nothing about recursion"
  elif printf '%s\n' "$MOUT2" | grep -q "	local/validate-foo.sh	"; then
    ok "MUTATION 2 — bounding the walk to the home's top level hides the subdirectory fork while the root-level one stays flagged (the recursion is load-bearing, and only it changed)"
  else
    bad "MUTATION 2 — bounding the walk silenced the ROOT-LEVEL fork too; the mutant broke more than recursion and its verdict is entangled"
  fi
fi

echo
[ "$fails" -eq 0 ] && { echo "shadowed-local-validators: PASS"; exit 0; }
echo "shadowed-local-validators: $fails assertion(s) violated." >&2
exit 1
