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
# The attestation line is TRANSCRIBED, not written by this script: --attest prints
# it and a human or a model pastes it into a markdown gate log. So the reader's
# grammar has to admit the shapes that transcription produces, and refuse the ones
# that only LOOK like it.
#
# ONE GRAMMAR, THREE SITES. The two --verify arms below and the citation grep all
# build from ATTEST_LEAD. Three hand-written anchors is three chances to widen one
# and not the others, and the half-widened form is the dangerous one: with only the
# digest arm widened, a table-embedded attestation at a MOVED digest reaches neither
# branch and reports "this is the sprint's first gate" — the wrong one of the two
# messages, telling an operator the sprint never attested when it has and that the
# fixtures are unchanged when they moved.
#
# WHY NOT `^`. A gate log in a consumer is markdown, and its check rows are TABLE
# rows: the line the consumer pasted read `| H2 | core | PASS | \`H2_ATTESTED v1
# sprint=311 …\`. |`, which `^H2_ATTESTED` cannot reach. Measured at the release tree
# against the shipping script and the real fixture digest, five gate logs differing
# only in what precedes one byte-identical attestation: column 1 exits 0; a table
# cell, a backtick wrap, a `- ` bullet and a four-space indent all exit 1.
#
# WHY NOT A BARE SUBSTRING EITHER. Dropping the anchor makes `XH2_ATTESTED` and
# `NOT_H2_ATTESTED` count, so a line that DENIES an attestation grants one. The
# grammar is therefore a TOKEN boundary: start of line, or any character that is not
# a word character. `[^0-9A-Za-z_]` rather than `\b`, because this expression is also
# what a reader copies into a `git grep -E`, where `\b` returns a clean zero.
#
# A BACKTICK MUST NOT APPEAR IN THESE STRINGS. They are interpolated into double-quoted
# `grep -qE` arguments, where an unescaped backtick opens command substitution and
# `bash -n` on the file exits 2. The classes here are spelled without one deliberately;
# the wrapping backticks a transcriber adds are matched by the negated classes, not by
# naming the character.
#
# AND A BOUNDARY ALONE MANUFACTURES ATTESTATIONS OUT OF FAILURE PROSE. This is the half
# that makes a widened reader WORSE than the anchored one, so it ships with the widening
# and not after it. A gate log's own narrative QUOTES the line it is complaining about:
# the consumer's committed log carries a numbered finding reading *"the `H2_ATTESTED v1
# sprint=311 digest=<D> … mechanical=check-17-bypass:PASS` line from the requirements gate
# was embedded in a table cell … THIS GATE FAILED -- re-drive required."* Under a bare
# boundary that sentence exits 0 — a sentence saying the gate FAILED grants an attestation
# nobody drove, against a control with the token removed reading 1.
#
# SO THE MATCH IS BOUNDED AT BOTH ENDS. ATTEST_TAIL requires that the emitted span at
# `:209` be followed by closing decoration only — backticks, periods, asterisks, spaces —
# up to a cell delimiter or end of line. A line whose span is followed by WORDS is prose
# about an attestation, not one.
#
# WHY THE CELL DELIMITER IS IN THE CLASS, measured rather than assumed. Over every
# `H2_ATTESTED` line in the consumer's whole gate-log history — all revisions of all 108
# gate-log files, 155 distinct lines, 28 distinct (sprint, digest) pairs — grammars scored
# per PAIR, which is the unit that decides whether a sprint can cite rather than re-drive:
#
#   shipped `^`                        26 / 28 pairs verifiable
#   boundary only                      28 / 28, and ACCEPTS the failure sentence
#   boundary + end-of-line decoration  27 / 28, REFUSES a real row ending `. | 1033 |`
#   boundary + cell-bounded tail       28 / 28, and refuses the failure sentence
#
# The third loses sprint 309's `aab08e34184faa3d` outright: its only record is a table row
# carrying a trailing numeric column, so anchoring on end of line reintroduces the defect
# one column further right. The shipped form is the fourth, and it gains two pairs the
# `^` anchor cannot reach (294, 309) while losing none.
#
# THE TRAILING FIELDS ARE OPTIONAL, AND THAT IS ALSO MEASURED. Requiring the whole emitted
# span REGRESSES sprint 308's `5ddce3ec7bb9805c`, whose only record stops after `items=`:
# the emitter has not always printed the same fields, and a reader keyed on today's tail
# refuses yesterday's attestation. `sprint=` and `digest=` are the identity and are
# required; everything after them is matched if present and not demanded.
ATTEST_LEAD='(^|[^0-9A-Za-z_])'
ATTEST_TAIL='[^0-9A-Za-z|]*(\||$)'
# The emitted span, for the tail test and for CITATION. Its optional groups mirror `:209`
# field for field, so a field added there is matched here without being required.
ATTEST_FIELDS='( at=[0-9A-Za-z:-]+)?( items=[0-9,]+)?( mechanical=[0-9A-Za-z:_.-]+)?'
ATTEST_SPAN="H2_ATTESTED v1 sprint=${SPRINT} digest=${DIGEST}${ATTEST_FIELDS}"
# The same span at ANY digest, for the "fixture set CHANGED" arm. It carries the identical
# lead and tail, because BOTH arms must refuse prose: guarding only the accepting arm moves
# the failure sentence from a false PASS to a false CHANGED, which still tells an operator
# the sprint attested and the fixtures moved when neither happened.
ATTEST_ANY="H2_ATTESTED v1 sprint=${SPRINT} digest=[0-9a-f]+${ATTEST_FIELDS}"

# ---------------------------------------------------------------------------
# verify: is there a live attestation for THIS sprint and THIS fixture set?
# ---------------------------------------------------------------------------
if [ "$MODE" = "verify" ]; then
  if [ -z "$GATE_LOG" ] || [ ! -f "$GATE_LOG" ]; then
    echo "RE-DRIVE: no gate log found — H2 has not attested this sprint."
    exit 1
  fi
  if grep -qE "${ATTEST_LEAD}${ATTEST_SPAN}${ATTEST_TAIL}" "$GATE_LOG"; then
    echo "PASS  H2 attested for sprint ${SPRINT} at fixture digest ${DIGEST}."
    # PRINT THE SPAN, NOT THE LINE. Once the reader admits a table cell, the matching
    # LINE is the whole markdown row — measured at 891 bytes on the consumer's own log
    # against 117 for the span — and this output is copy text an operator cites. `-o`
    # emits the token span alone, so the citation is byte-identical whichever placement
    # the attestation was transcribed into.
    grep -oE "${ATTEST_SPAN}" "$GATE_LOG" | tail -1
    echo "      Cite this line. The fixtures are byte-identical to when it was driven."
    exit 0
  fi
  if grep -qE "${ATTEST_LEAD}${ATTEST_ANY}${ATTEST_TAIL}" "$GATE_LOG"; then
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
echo "Append to the gate log, as its own line at column 1 — or inside the H2 row's"
echo "evidence cell. Both verify; nothing else about the line may change."
echo ""
echo "H2_ATTESTED v1 sprint=${SPRINT} digest=${DIGEST} at=${STAMP} items=1,2,3 mechanical=check-17-bypass:PASS"
exit 0
