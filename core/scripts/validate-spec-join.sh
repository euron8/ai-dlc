#!/usr/bin/env bash
# validate-spec-join.sh — the spec traceability joins
#
# Usage: ./scripts/ai-dlc/validate-spec-join.sh --spec DIR --prd FILE [--story FILE]...
#                                              [--spine-lint JSON] [--trace-verdict FILE]
#
# Gate-validation Check 30 enforcer (story gates).
#
# WHAT IT GUARDS. The chain from operator intent to a test is
#
#   LOCKED_REQUIREMENTS -> CAP-N -> FR-<n> -> story AC -> test
#
# and until now its middle joins were hand-typed prose. A PRD carries
# `FR-S290-1 (<- LR-S290-1)`; the arrow is a character, not a join, and nothing
# reads it. Two failures follow, both silent:
#
#   - A requirement reaches no capability. Observed: a locked requirement dropped
#     during an ADR pivot with no SUPERSEDED disposition — it simply stopped being
#     mentioned, and every artifact downstream stayed internally consistent.
#   - A definition is re-transcribed instead of cited. Observed: a roster of
#     always-on safety pollers restated per-story, at 5, 6 and 4 members in three
#     places, because no story pointed at one canonical definition.
#
# BMAD supplies the stable IDs this needs and does not join them: `bmad-spec`
# guarantees `CAP-N` is never reused or renumbered, `bmad-architecture` gives
# `AD-n`, and `bmad-create-epics-and-stories` emits an `FR Coverage Map`. What
# none of them does is FAIL. This is the caller that decides.
#
# THE JOINS, all ID-mechanical:
#   (1) every LOCKED_REQUIREMENTS bullet in the spec's memlog maps to >=1 CAP-N
#   (2) every CAP-N in SPEC.md appears in the PRD's FR Coverage Map
#   (3) every `capabilities:` entry in a story frontmatter resolves to a CAP-N
#       that SPEC.md defines
#
# ANCHOR ON THE MEMLOG, NOT SPEC.md. `bmad-spec` is the single writer of SPEC.md
# and re-derives it from `.memlog.md` on every run: "a hand-edit to SPEC.md from
# outside is unsupported and is overwritten on the next derive." A byte anchor into
# a re-rendered file holds until the next derive and then reports a drift that never
# happened. `.memlog.md` is append-only and never reordered, so requirement text is
# anchored there.
#
# TWO BORROWED VERDICTS. `--spine-lint` takes `lint_spine.py`'s JSON, which by
# design always exits 0 and lets the caller decide; a non-empty `ad_fields` or
# `placeholder` finding set fails here. `--trace-verdict` takes a
# `bmad-testarch-trace` gate decision; FAIL fails, CONCERNS and WAIVED are recorded
# with the matrix cited rather than dropped. Both are OPT-IN FLAGS: whether they ran
# is the gate's evidence question, not something this script can infer from a
# missing file.
#
# EXIT CODES
#   0  -- every join closes
#   1  -- an orphan or a dangling reference
#   2  -- DISARMED or usage error: a required input is unreadable, or SPEC.md
#         defines ZERO capabilities. A zero-capability spec closes every join
#         vacuously and prints the same line as a spec that closes them for real.

set -u

PROG="validate-spec-join.sh"
SPEC=""; PRD=""; SPINE=""; TRACE=""
STORIES=()

while [ $# -gt 0 ]; do
  case "$1" in
    --spec)          SPEC="${2:-}"; shift 2 || exit 2 ;;
    --prd)           PRD="${2:-}";  shift 2 || exit 2 ;;
    --story)         STORIES+=("${2:-}"); shift 2 || exit 2 ;;
    --spine-lint)    SPINE="${2:-}"; shift 2 || exit 2 ;;
    --trace-verdict) TRACE="${2:-}"; shift 2 || exit 2 ;;
    -h|--help) echo "usage: $PROG --spec DIR --prd FILE [--story FILE]... [--spine-lint JSON] [--trace-verdict FILE]" >&2; exit 2 ;;
    *) echo "$PROG: unexpected argument '$1'" >&2; exit 2 ;;
  esac
done

[ -n "$SPEC" ] && [ -d "$SPEC" ] || { echo "$PROG: DISARMED — --spec must name the spec folder (holding SPEC.md and .memlog.md); got '${SPEC:-<none>}'." >&2; exit 2; }
KERNEL="$SPEC/SPEC.md"
MEMLOG="$SPEC/.memlog.md"
[ -f "$KERNEL" ] || { echo "$PROG: DISARMED — no SPEC.md in $SPEC. Run bmad-spec before this gate; a missing kernel is not an empty one." >&2; exit 2; }
[ -f "$MEMLOG" ] || { echo "$PROG: DISARMED — no .memlog.md in $SPEC. The memlog is the append-only decision-of-record and the anchor surface for requirement text; without it join (1) cannot be checked at all." >&2; exit 2; }
[ -n "$PRD" ] && [ -f "$PRD" ] || { echo "$PROG: DISARMED — --prd must name a readable PRD; got '${PRD:-<none>}'." >&2; exit 2; }

# Capabilities the kernel defines.
CAPS="$(grep -ohE '\bCAP-[0-9]+\b' "$KERNEL" | sort -u -V)"
NCAPS="$(printf '%s\n' "$CAPS" | grep -c . )"
if [ "$NCAPS" -eq 0 ]; then
  echo "$PROG: DISARMED — $KERNEL defines ZERO capabilities (no CAP-<n> found). Every join below would close against an empty set and print the same PASS line as a spec that closes them for real." >&2
  exit 2
fi

rc=0
note=0

# --- (1) every locked requirement reaches a capability -------------------------
# The memlog records one line per capability with its CAP-N; a locked requirement
# that no capability line cites is a requirement that reached nothing.
LRS="$(grep -ohE '\bLR-[A-Za-z0-9]+-[0-9]+[a-z]?\b' "$MEMLOG" | sort -u)"
NLRS="$(printf '%s\n' "$LRS" | grep -c . )"
if [ "$NLRS" -eq 0 ]; then
  echo "$PROG: DISARMED — no LR-<...> identifiers found in $MEMLOG. Join (1) has nothing to check, which is not the same as closing." >&2
  exit 2
fi
for lr in $LRS; do
  # The capability entries citing this LR. A memlog line typed `capability` that
  # names both the LR and a CAP-N is the join.
  if ! grep -E "(^|[^A-Za-z0-9-])$lr([^A-Za-z0-9-]|\$)" "$MEMLOG" | grep -qE '\bCAP-[0-9]+\b'; then
    echo "FAIL: $lr appears in the memlog but no capability entry cites it alongside a CAP-<n>. A locked requirement that reaches no capability is dropped, and every artifact downstream stays internally consistent while it is missing. Either map it to a capability or record an explicit SUPERSEDED/AMENDED disposition for it." >&2
    rc=1
  fi
done

# --- (2) every capability reaches an FR in the coverage map --------------------
MAP_START="$(grep -nE '^#{1,6}[[:space:]]*FR Coverage Map' "$PRD" | head -1 | cut -d: -f1)"
if [ -z "$MAP_START" ]; then
  echo "$PROG: DISARMED — $PRD has no 'FR Coverage Map' heading. bmad-create-epics-and-stories emits it; without it join (2) cannot be checked, and skipping the join silently is the defect this check exists to remove." >&2
  exit 2
fi
MAP="$(sed -n "${MAP_START},\$p" "$PRD" | awk 'NR>1 && /^#{1,6}[[:space:]]/{exit} {print}')"
for cap in $CAPS; do
  if ! printf '%s\n' "$MAP" | grep -qE "(^|[^A-Za-z0-9-])$cap([^A-Za-z0-9-]|\$)"; then
    echo "FAIL: $cap is defined in SPEC.md but appears nowhere in the PRD's FR Coverage Map. A capability with no functional requirement behind it is specified and unplanned — it reaches no epic, no story and no test." >&2
    rc=1
  fi
done

# --- (3) every story capability reference resolves -----------------------------
if [ "${#STORIES[@]}" -gt 0 ]; then
  for s in "${STORIES[@]}"; do
    [ -f "$s" ] || { echo "$PROG: DISARMED — --story names an unreadable file: $s" >&2; exit 2; }
    refs="$(sed -n '/^capabilities:/{s/^capabilities:[[:space:]]*//; s/[][]//g; s/,/ /g; p; }' "$s" | head -1)"
    if [ -z "$refs" ]; then
      echo "FAIL: $s carries no 'capabilities:' frontmatter field. That field is the only mechanical link from a story to the spec; without it the story's place in the chain is prose." >&2
      rc=1
      continue
    fi
    for r in $refs; do
      case "$r" in CAP-*) ;; *) continue ;; esac
      if ! printf '%s\n' "$CAPS" | grep -qx -- "$r"; then
        echo "FAIL: $s cites '$r' and $KERNEL defines no such capability. A story pointing at an ID that does not exist is a story nobody can trace, and CAP-<n> is never renumbered — so this is a typo or a stale reference, not a renumbering." >&2
        rc=1
      fi
    done
  done
fi

# --- borrowed verdict: lint_spine.py ------------------------------------------
if [ -n "$SPINE" ]; then
  [ -f "$SPINE" ] || { echo "$PROG: DISARMED — --spine-lint names an unreadable file: $SPINE" >&2; exit 2; }
  # lint_spine.py emits JSON findings and always exits 0 by design. Two of its
  # classes are gate-fatal here: a placeholder left in a ratified spine, and an
  # AD-n missing its Binds/Prevents/Rule fields.
  for cls in ad_fields placeholder; do
    if grep -q "\"$cls\"" "$SPINE"; then
      echo "FAIL: lint_spine.py reported '$cls' findings in the architecture spine ($SPINE). It exits 0 by design and leaves the decision to its caller; this is that decision. An AD with missing Binds/Prevents/Rule fields, or an unfilled placeholder, is a design decision that binds nothing." >&2
      rc=1
    fi
  done
fi

# --- borrowed verdict: bmad-testarch-trace ------------------------------------
if [ -n "$TRACE" ]; then
  [ -f "$TRACE" ] || { echo "$PROG: DISARMED — --trace-verdict names an unreadable file: $TRACE" >&2; exit 2; }
  if grep -qE '\bFAIL\b' "$TRACE"; then
    echo "FAIL: the traceability gate decision in $TRACE is FAIL. Requirements are not covered by tests; the matrix names which." >&2
    rc=1
  elif grep -qE '\b(CONCERNS|WAIVED)\b' "$TRACE"; then
    echo "  note  traceability gate decision is CONCERNS/WAIVED — recorded, not dropped. Matrix: $TRACE"
    note=$((note+1))
  fi
fi

if [ "$rc" -eq 0 ]; then
  echo "$PROG: PASS ($NLRS locked requirement(s), $NCAPS capability(ies), ${#STORIES[@]} story(ies), $note recorded note(s))"
fi
exit $rc
