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
LED

# Forks the consumer carries.
for f in validate-foo.sh validate-bar.sh some-tool.sh validate-orphan.sh; do : > "$WORK/local/$f"; done
# Core validators (what a fork must shadow to count).
for f in validate-foo.sh validate-bar.sh validate-nofork.sh validate-orphan.sh; do : > "$WORK/core/$f"; done

run_warn() { # run_warn <script>
  bash "$1" --root "$WORK" --ledger "$WORK/ledger.md" \
    --local-dir "$WORK/local" --core-dir "$WORK/core" 2>/dev/null
}

OUT="$(run_warn "$SCRIPT")"
fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1" >&2; fails=$((fails+1)); }
has() { printf '%s\n' "$OUT" | grep -q "scripts/ai-dlc-local/$1"; }

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
  if printf '%s\n' "$MOUT" | grep -q "scripts/ai-dlc-local/validate-bar.sh"; then
    ok "MUTATION — dropping the CLOSED gate flags the OPEN bar fork too (the gate is load-bearing)"
  else
    bad "MUTATION — bar still not flagged without the CLOSED gate; the closed-only assertions prove nothing"
  fi
fi

echo
[ "$fails" -eq 0 ] && { echo "shadowed-local-validators: PASS"; exit 0; }
echo "shadowed-local-validators: $fails assertion(s) violated." >&2
exit 1
