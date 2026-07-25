#!/usr/bin/env bash
# Seed the check-15-bypass fixture (Check 16 — stub audit, hot-path content verification).
#
# THIS FIXTURE WRITES REAL HOT-PATH FILES AND A REAL BACKLOG. It used to be two `echo`
# statements naming "four bypass variants" that were never created. Nothing was
# established, so nothing could fail — the fixture read exactly like a passing test for
# as long as it existed. Same shape the check-manifest-bypass and check-h1-recursion
# seeds were rewritten out of.
#
# Check 16 greps changed hot-path files for stub markers and requires FOUR elements in
# the comment block (preceding 5 lines + the matched line):
#   1. `Item [0-9]+` reference
#   2. that item is OPEN or IN SPRINT in carry-over-backlog.md
#   3. a `file:line` reference (path token, colon, 1+ DIGITS)
#   4. `^deferral-reason:\s+\S.{19,}` AND >=10 non-whitespace chars in the reason body
#
# Five stub sites are seeded. Each of V1..V4 satisfies every element EXCEPT one, so a
# driver can assert not merely that the variant fails but that it fails ON THE INTENDED
# ELEMENT — a variant rejected on the wrong element is indistinguishable from a healthy
# reject by exit code alone, and would let the element under test rot untested.
#
#   V1  item-absent      — cites `Item 999`, which is not in the backlog   (element 2)
#   V2  reason-tbd       — `deferral-reason: TBD`, under the length floor  (element 4)
#   V3  no-file-line     — carries no path:digits reference at all         (element 3)
#   V4  reason-padding   — `deferral-reason: X` + padding: clears the 19+  (element 4,
#                          length rule but not the >=10 non-whitespace density rule)
#   V5  honest           — the positive control. Satisfies all four.
#
# V5 is what makes this fixture able to fail. Without it, an element check mutated to
# reject everything would still look correct: all four adversaries would be rejected and
# the fixture would report success.
#
# Check 16 is `adjudication: llm` in enforcement-map.yaml with `enforcer: []` — there is
# no validator script to drive, so run.sh evaluates the check's OWN PUBLISHED REGEXES
# against this seed. See run.sh's header for the limits of what that proves.
#
# Usage: seed.sh [OUT_DIR]   (prints the seeded tree path on stdout)

set -euo pipefail

OUT="${1:-${OUT:-$(mktemp -d)}}"
TREE="$OUT/tree"
rm -rf "$TREE"                     # idempotent re-seed
mkdir -p "$TREE/src" "$TREE/_bmad-output/planning-artifacts"

cat > "$TREE/_bmad-output/planning-artifacts/carry-over-backlog.md" <<'EOF'
# Carry-over backlog

- Item 12 — connection pooling for the read path (OPEN)
- Item 34 — queue driver pin (IN SPRINT 43)
- Item 7 — retired ack shim (CLOSED)
EOF

# ---- V1: cites an item that is not in the backlog at all ---------------------
cat > "$TREE/src/v1_item_absent.py" <<'EOF'
def widen_read_path():
    # Carry-over Item 999 — see src/pool.py:41
    # deferral-reason: the pool sizing heuristic needs the production
    #   request-rate sample that lands next sprint.
    raise NotImplementedError  # stub
EOF

# ---- V2: deferral-reason under the length floor ------------------------------
cat > "$TREE/src/v2_reason_tbd.py" <<'EOF'
def pin_queue_driver():
    # Carry-over Item 34 — see src/queue.py:88
    # deferral-reason: TBD
    raise NotImplementedError  # stub
EOF

# ---- V3: no file:line reference anywhere in the block ------------------------
# Deliberately carries no path-token-colon-digits sequence. It also carries exactly
# ONE stub marker (`TODO`, on the last line) so the whole comment block falls inside
# that match's 5-line window — a second marker higher up would drag a truncated
# window into scope and fail elements 1 and 4 as well, which would make it impossible
# to assert that V3 fails on element 3 SPECIFICALLY.
cat > "$TREE/src/v3_no_file_line.sh" <<'EOF'
widen_read_path() {
  # Carry-over Item 12, deferred
  # deferral-reason: the pool sizing heuristic needs the production
  #   request-rate sample that lands next sprint.
  : # TODO
}
EOF

# ---- V4: padding-only reason — clears the 19+ length rule, fails density -----
# `X` then a run of spaces: `^deferral-reason:\s+\S.{19,}` matches (19+ chars of
# ANY kind, spaces included) while the reason body holds one non-whitespace char.
printf '%s\n' \
  'def sample_request_rate():' \
  '    # Carry-over Item 12 — see src/pool.py:41' \
  '    # deferral-reason: X                                   ' \
  '    raise NotImplementedError  # stub' \
  > "$TREE/src/v4_reason_padding.py"

# ---- V6: a file reference with no DIGITS after the colon ---------------------
# Element 3 is explicitly digit-only ("rejects `file:FIXME`"). Without this variant a
# loosened `\S+:\S+` element 3 passes the whole fixture — a mutation run proved it.
# The marker (`FIXME`) is deliberately the LAST line so the 5-line window still covers
# the item reference and the deferral-reason, leaving element 3 the only failure.
cat > "$TREE/src/v6_file_no_digits.py" <<'EOF'
def sample_request_rate():
    # Carry-over Item 12
    # deferral-reason: the pool sizing heuristic needs the production
    #   request-rate sample that lands next sprint.
    # see src/pool.py:FIXME
EOF

# ---- V7: cites a CLOSED backlog item -----------------------------------------
# Element 2 accepts OPEN or IN SPRINT only. Without this variant an element 2 widened
# to accept CLOSED passes the whole fixture — the same mutation run proved it. V1
# covers an ABSENT item, which is a different hole in the same element.
cat > "$TREE/src/v7_item_closed.py" <<'EOF'
def retire_ack_shim():
    # Carry-over Item 7 — see src/ack.py:12
    # deferral-reason: the ack shim cannot be removed until the queue
    #   driver pin lands and the consumers redeploy.
    raise NotImplementedError  # stub
EOF

# ---- V5: the positive control — satisfies all four elements ------------------
cat > "$TREE/src/v5_honest.py" <<'EOF'
def widen_read_path():
    # Carry-over Item 12 — see src/pool.py:41
    # deferral-reason: the pool sizing heuristic needs the production
    #   request-rate sample that lands next sprint.
    raise NotImplementedError  # stub
EOF

# ---- V8 / V9: the upstream-owned exemption, and its discrimination control ----
# Check 16 drops upstream-owned paths from scope, because the four elements are
# unsatisfiable there: element 1 wants an `Item N` from the CONSUMER's backlog and
# the core guard denies the edit that would add one. Until this pair existed the
# whole fixture seeded only `src/` — consumer-authored product code — so "a core
# file trips Check 16 and the consumer cannot clear it" had NO coverage, and it
# shipped. It then failed a real consumer's §6 gate four times on the exact
# comment reproduced in V8.
#
# V8 and V9 are a PAIR and neither is meaningful alone. Both live under `.claude/`,
# both carry the same bare `Phase 3` marker, and both satisfy ZERO elements. Only
# their OWNERSHIP differs. If the exemption were a blanket `.claude/` carve-out
# rather than a core-manifest resolve, V8 would pass and V9 would pass too — and
# V9 passing is a consumer hook smuggling an unaudited stub through the gate.
mkdir -p "$TREE/.claude/skills/ai-dlc/steps" \
         "$TREE/.claude/skills/ai-dlc-update/reconcile" \
         "$TREE/.claude/hooks"

# The resolver reads the REAL core-manifest.md, not a fixture-local invention: a
# hand-written stand-in here would keep passing after the real manifest changed
# shape, which is the failure mode this whole check is about. Walk UP for whichever
# layout we are in (distribution `core/`, or a consumer's installed `.claude/`)
# rather than counting `..` — the fixture runs from both.
MANIFEST_SRC=""
d="$(cd "$(dirname "$0")" && pwd)"
while [ "$d" != "/" ]; do
  if [ -f "$d/core/skills/ai-dlc/core-manifest.md" ]; then
    MANIFEST_SRC="$d/core/skills/ai-dlc/core-manifest.md"; break
  elif [ -f "$d/.claude/skills/ai-dlc/core-manifest.md" ]; then
    MANIFEST_SRC="$d/.claude/skills/ai-dlc/core-manifest.md"; break
  fi
  d="$(dirname "$d")"
done
[ -n "$MANIFEST_SRC" ] || { echo "seed: FAIL — no core-manifest.md found walking up from $0. V8/V9 would compare against nothing." >&2; exit 2; }
cp "$MANIFEST_SRC" "$TREE/.claude/skills/ai-dlc/core-manifest.md"

# V8: upstream-owned (`skills/ai-dlc-update/**`). Zero elements satisfied. EXEMPT.
# The comment block is the verbatim text that failed the real gate.
cat > "$TREE/.claude/skills/ai-dlc-update/reconcile/apply.sh" <<'EOF'
#!/usr/bin/env bash
# So both captures happen here, together, in the only state in which ours-vs-base
# means what the status name claims. Phases 1 and 2 consume what this phase measured.
#
# Phase 3's layer-drift.sh does NOT belong here and is not exposed to the same fault: its
# consumer-side reads are layer_files(), which walks consumer-authored *.md.
PC="$(bash "$SELF/preclassify.sh" || true)"
EOF

# V9: a CONSUMER-owned hook. The core glob is `hooks/ai-dlc-*.sh`, so this is NOT
# core, sits one directory from files that are, and MUST still be audited.
cat > "$TREE/.claude/hooks/my-own-hook.sh" <<'EOF'
#!/usr/bin/env bash
# Phase 3's dispatch table is not wired here yet.
exit 0
EOF

echo "$TREE"
