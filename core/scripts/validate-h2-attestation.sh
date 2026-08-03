#!/bin/bash
#
# AI/DLC H2 Harness Self-Test Attestation (gate-validation.md H2)
#
# WHY THIS EXISTS
# H2 is the meta-meta-check: it proves the gate's own machinery cannot be bypassed
# (H1's recursion guard fires; a forged provenance block is caught; a sliced gate
# context that drops required checks is caught). It ran at EVERY gate -- 4 to 6 times
# per planning phase -- and it re-drove the SAME three checked-in fixtures each time.
#
# Those fixtures are static. Nothing about them changes between gate 1 and gate 5 of
# one sprint. H2 was re-proving an identical fact 4-6 times, and gate-validation.md
# explicitly demanded it ("a FRESH fixture seed").
#
# This script makes H2 attest ONCE PER SPRINT instead, pinned to a digest of the
# fixture set. Later gates in the same sprint verify the attestation and the digest
# and cite it. Change any fixture byte and the digest moves, the attestation is void,
# and H2 re-drives in full.
#
# THIS IS DEDUPLICATION, NOT PRUNING. The check keeps every tooth: it still runs, with
# a fresh seed, against the real validators, once per sprint. What is removed is the
# repetition -- not the coverage. (Do not confuse this with weakening H2. H2 was in
# fact weaker than anyone thought: its fixtures wrote no files and it adjudicated
# their English descriptions. That is fixed separately; see check-17-bypass/run.sh.)
#
# USAGE
#   validate-h2-attestation.sh --digest
#       print the fixture-set digest and exit
#
#   validate-h2-attestation.sh --attest --sprint N [--fixtures DIR] [--scripts DIR]
#       DRIVE the mechanical fixtures, and on success print the H2_ATTESTED v1 line
#       for the lead to append to the gate log. Exit 1 if any fixture fails.
#       --scripts is forwarded to the fixture runner ONLY when given; without it the
#       runner self-locates the validators, which is the correct default everywhere.
#
#   validate-h2-attestation.sh --verify --sprint N [--gate-log PATH]
#       exit 0  a valid attestation for this sprint AND this digest exists -> cite it
#       exit 1  no attestation, wrong sprint, or the fixtures changed -> re-drive H2
#
# EXIT
#   0  attested / verified
#   1  a fixture failed, no valid attestation, or input unreadable

set -u

# --- AI_DLC_ROOT ------------------------------------------------------------
# Resolve the project root by walking UP for a marker, never by a fixed number of
# `..` hops. This script runs from three layouts:
#   <root>/core/scripts/X      distribution
#   <root>/scripts/ai-dlc/X    consumer, v0.126.0+
#   <root>/scripts/X           consumer, pre-v0.126.0
# and no fixed hop count fits all three. v0.126.0 moved the validators one level
# deeper, which silently turned every `dirname $0/..` root into <root>/scripts:
# this script then found no docs/retro/, printed "Scanned 0 retros, 0 gates
# declared, 0 dormant" and exited 0 — a check that could no longer fire, reading
# exactly like one that passed.
# Inline on purpose, in every script that needs it: a shared lib cannot fix this,
# because locating the lib is the same unsolved problem. Duplication is correct
# here. core/fixtures/validator-path-resolution asserts both layouts agree.
ai_dlc_resolve_root() {
  local d="$1"
  while [ -n "$d" ] && [ "$d" != "/" ] && [ "$d" != "." ]; do
    if [ -e "$d/.git" ] || [ -d "$d/.claude" ] || [ -d "$d/core/skills/ai-dlc" ]; then
      printf '%s\n' "$d"; return 0
    fi
    d="$(dirname "$d")"
  done
  return 1
}
AI_DLC_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AI_DLC_ROOT="${AI_DLC_PROJECT_ROOT:-}"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="$(ai_dlc_resolve_root "$AI_DLC_SELF_DIR" || true)"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="${CLAUDE_PROJECT_DIR:-}"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="$(ai_dlc_resolve_root "$(pwd)" || true)"
[ -n "$AI_DLC_ROOT" ] || {
  echo "ERROR: cannot resolve the project root from ${AI_DLC_SELF_DIR} (no .git or" >&2
  echo "  .claude/ marker in any parent). Set AI_DLC_PROJECT_ROOT to the repo root." >&2
  exit 2
}
# --- end AI_DLC_ROOT --------------------------------------------------------

PROJECT_DIR="$AI_DLC_ROOT"
FIXTURES=""
GATE_LOG=""
SPRINT=""
MODE=""
SCRIPTS_DIR=""   # operator override only; empty means "let the fixture self-locate"

while [ $# -gt 0 ]; do
  case "$1" in
    --digest)   MODE="digest"; shift ;;
    --attest)   MODE="attest"; shift ;;
    --verify)   MODE="verify"; shift ;;
    --sprint)   SPRINT="${2:-}"; shift 2 ;;
    --fixtures) FIXTURES="${2:-}"; shift 2 ;;
    --scripts)  SCRIPTS_DIR="${2:-}"; shift 2 ;;
    --gate-log) GATE_LOG="${2:-}"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 1 ;;
  esac
done

[ -n "$MODE" ] || { echo "FAIL: pass --digest, --attest or --verify" >&2; exit 1; }

# Fixtures live at tests/fixtures/ in a consumer (install.sh copies core/fixtures/
# there) and at core/fixtures/ in the distribution. Try both.
if [ -z "$FIXTURES" ]; then
  for cand in "$PROJECT_DIR/tests/fixtures" "$PROJECT_DIR/core/fixtures"; do
    [ -d "$cand/check-17-bypass" ] && { FIXTURES="$cand"; break; }
  done
fi
[ -n "$FIXTURES" ] && [ -d "$FIXTURES" ] || {
  echo "FAIL: cannot locate the fixture set (pass --fixtures DIR)" >&2; exit 1; }

# The three fixtures H2 drives. H1 enumerates more; H2 drives exactly these.
H2_FIXTURES="check-h1-recursion check-17-bypass check-manifest-bypass"

# ---------------------------------------------------------------------------
# Digest: sha256 over the sorted contents of every file in the three fixture
# dirs. Any byte change anywhere in them moves the digest and voids attestations.
# ---------------------------------------------------------------------------
digest() {
  local f
  for d in $H2_FIXTURES; do
    [ -d "$FIXTURES/$d" ] || { echo "FAIL: missing fixture dir: $FIXTURES/$d" >&2; exit 1; }
    find "$FIXTURES/$d" -type f | LC_ALL=C sort | while read -r f; do
      printf '%s\n' "${f#"$FIXTURES"/}"
      cat "$f"
    done
  done | { shasum -a 256 2>/dev/null || sha256sum; } | cut -d' ' -f1 | cut -c1-16
}

DIGEST="$(digest)"
[ -n "$DIGEST" ] || { echo "FAIL: could not compute fixture digest" >&2; exit 1; }

if [ "$MODE" = "digest" ]; then
  echo "$DIGEST"
  exit 0
fi

[ -n "$SPRINT" ] || { echo "FAIL: --sprint N is required for --attest/--verify" >&2; exit 1; }

if [ -z "$GATE_LOG" ]; then
  for cand in "$PROJECT_DIR/_bmad-output/implementation-artifacts/gate-log.md" \
              "$PROJECT_DIR/_bmad-output/planning-artifacts/gate-log.md" \
              "$PROJECT_DIR/_bmad-output/gate-log.md"; do
    [ -f "$cand" ] && { GATE_LOG="$cand"; break; }
  done
fi

# ---------------------------------------------------------------------------
# verify: is there a live attestation for THIS sprint and THIS fixture set?
# ---------------------------------------------------------------------------
if [ "$MODE" = "verify" ]; then
  if [ -z "$GATE_LOG" ] || [ ! -f "$GATE_LOG" ]; then
    echo "RE-DRIVE: no gate log found — H2 has not attested this sprint."
    exit 1
  fi
  if grep -qE "^H2_ATTESTED v1 sprint=${SPRINT} digest=${DIGEST}\b" "$GATE_LOG"; then
    echo "PASS  H2 attested for sprint ${SPRINT} at fixture digest ${DIGEST}."
    grep -E "^H2_ATTESTED v1 sprint=${SPRINT} digest=${DIGEST}\b" "$GATE_LOG" | tail -1
    echo "      Cite this line. The fixtures are byte-identical to when it was driven."
    exit 0
  fi
  if grep -qE "^H2_ATTESTED v1 sprint=${SPRINT} " "$GATE_LOG"; then
    echo "RE-DRIVE: sprint ${SPRINT} has an attestation, but the fixture set CHANGED." >&2
    echo "          expected digest ${DIGEST}; the logged attestation carries another." >&2
    echo "          A changed fixture voids the attestation by design — re-drive H2 in full." >&2
    exit 1
  fi
  echo "RE-DRIVE: no H2 attestation for sprint ${SPRINT} — this is the sprint's first gate."
  exit 1
fi

# ---------------------------------------------------------------------------
# attest: actually drive the mechanical fixtures, then emit the line.
# ---------------------------------------------------------------------------
RUN="$FIXTURES/check-17-bypass/run.sh"
if [ ! -x "$RUN" ] && [ ! -f "$RUN" ]; then
  echo "FAIL: check-17-bypass/run.sh is missing. H2 item (2) cannot be driven." >&2
  echo "      A fixture with no runner is the failure this attestation exists to prevent." >&2
  exit 1
fi

echo "H2 attestation — driving the mechanical fixture (item 2)…"
# check-17-bypass/run.sh SELF-LOCATES the validators, and it must: in a consumer they
# live at scripts/ai-dlc/ (since v0.126.0), in the distribution at core/scripts/. Do NOT
# re-derive that here. A second candidate list is a second thing to go stale, and an
# explicit --scripts DEFEATS the fixture's correct answer with this script's wrong one.
# That is exactly what v0.138.0 shipped: this line read `--scripts "$SCRIPTS_DIR"` where
# SCRIPTS_DIR was guessed from a pre-relocation pair (scripts/, then core/scripts/ with
# NO existence test), so every consumer's --attest died on "cannot locate
# validate-provenance-block.sh" while the same fixture passed when run by hand. The
# distribution has a scripts/ that holds no validators, so the fallback fired there and
# the bug could not be seen where it was authored.
# --scripts is forwarded ONLY when the operator supplied one.
if ! bash "$RUN" ${SCRIPTS_DIR:+--scripts "$SCRIPTS_DIR"}; then
  echo "" >&2
  echo "FAIL: check-17-bypass did not hold. H2 does NOT attest. The gate FAILS." >&2
  exit 1
fi

STAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""
echo "Items (1) H1 recursion guard and (3) manifest-bypass are LLM-adjudicated:"
echo "drive their seeds now and record the verdicts alongside this line."
echo ""
echo "Append to the gate log:"
echo ""
echo "H2_ATTESTED v1 sprint=${SPRINT} digest=${DIGEST} at=${STAMP} items=1,2,3 mechanical=check-17-bypass:PASS"
exit 0
