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
#   V12 reason-short     — a reason over the density floor, under the length     (element 4)
#   V5  honest           — the positive control. Satisfies all four.
#
# V5 is what makes this fixture able to fail. Without it, an element check mutated to
# reject everything would still look correct: all four adversaries would be rejected and
# the fixture would report success.
#
# `scripts/ai-dlc/validate-stub-audit.sh` is the elements' one home and run.sh drives it,
# so this seed is exercised by the code that ships. See run.sh's header for the limit
# that remains.
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

# ---- V12: a reason that clears the DENSITY floor but not the LENGTH floor -----
# Element 4 has two independent floors: `^deferral-reason:\s+\S.{19,}` (a body of at
# least 20 characters) AND >=10 non-whitespace characters in that body. V2 is under both
# and V4 is under density only, so until this variant existed NO seeded case separated
# them: deleting the length floor left every variant landing on density, the fixture
# stayed green, and one of the two published floors was untestable. This body is 16
# characters, 14 of them non-whitespace — density passes, length rejects.
cat > "$TREE/src/v12_reason_short.py" <<'EOF'
def trim_ack_window():
    # Carry-over Item 12 — see src/ack.py:31
    # deferral-reason: needs a resample
    raise NotImplementedError  # stub
EOF

# ---- V13 / V14 / V15 / V16: the `Phase N` marker, and what it must NOT match --
# `Phase [0-9]` is the one marker in the set that is also ORDINARY ENGLISH. As a bare
# alternative it produced the check's dominant false positive: on the reference consumer
# it was the sole matcher on 129 tracked hot-path lines, and every one of the 23 findings
# in the largest recorded Check 16 failure came from it, all suppressed by the operator.
# Its only remediation for a consumer-owned file is rewording true prose — there is no
# escape hatch but upstream ownership — and a consumer did exactly that, deleting a
# factual phase reference from a module docstring to clear a gate.
#
# So it is a marker only inside a statement of ABSENCE. These four are the two directions
# of that, and neither is meaningful alone: V13/V16 are prose that must be ignored, V14 is
# a real deferral written only as a phase reference that must still be caught, and V15 is
# the guard against fixing it in the wrong place. Fold the absence requirement onto ALL
# the markers instead of onto the phase one and V15 goes silent, which is a check that
# stopped examining `raise NotImplementedError()` while every other arm here stays green.

# V13: the verbatim docstring a consumer rewrote to clear its gate. Prose. NO finding.
cat > "$TREE/src/v13_phase_prose_docstring.py" <<'EOF'
"""Alert Evaluator — Harmonization Phase 4 (Stories 103-1 and 103-2)."""


def evaluate(window):
    return sum(window) / len(window)
EOF

# V14: a genuine deferred implementation whose ONLY marker is the phase reference —
# verbatim from the reference consumer. Satisfies zero elements, so element 1 rejects it.
# Drop `Phase [0-9]` from the marker set outright and this file goes silent.
cat > "$TREE/src/v14_phase_deferral.py" <<'EOF'
def build_position():
    return Position(
        burn_snapshots=[],  # Phase 1: no live snapshots yet (subgraph not deployed)
    )
EOF

# V15: an unambiguous marker with no prose beside it. The absence requirement is scoped
# to the phase alternative alone, so this must still be examined and rejected.
cat > "$TREE/src/v15_notimplemented_bare.py" <<'EOF'
def collect_fees():
    raise NotImplementedError()
EOF

# V16: a phase reference used as a SECTION LABEL — the shape that accounts for most of
# the consumer's 129. Prose. NO finding.
#
# V13 and V16 are not redundant and the difference is which FUTURE fix clears them. V13
# sits in a docstring, which carries no comment prefix; a marker gate that required
# comment TEXT — the remedy filed for the sibling defect, where an identifier named
# `stub` matches in code — would clear V13 on its own and leave V16 exactly as it was,
# because V16 IS a comment. Only the absence requirement clears V16, so it is the arm
# that stays load-bearing after that fix lands.
cat > "$TREE/src/v16_phase_section_label.py" <<'EOF'
def drain(cursor):
    # Phase 2: drain remaining records in cursor_block above cursor_logindex
    return cursor.advance()
EOF

# ---- V17-V20: WHERE a prose marker is credible -------------------------------
#
# The four prose markers (`stub`, `TODO`, `FIXME`, `wired later`) are ordinary English
# words. Matched on the raw line they fire on identifiers, on filenames and on test
# vocabulary, and every one of those opens the four elements against a line that can
# never satisfy them — the consumer paid a full HARD_BLOCK gate cycle and an operator
# SUPPRESSED disposition for this class in two consecutive sprints. They are examined
# only inside a comment, and only as whole words.
#
# THE TWO HALVES HAVE SEPARATE SUBJECTS ON PURPOSE. The boundary and the comment gate
# cover each other on most real lines, and two guards that cover each other read exactly
# like two guards that do not work — the symptom is zero failures, not two. So V17 is
# reachable ONLY by the comment gate (a bare word, in code) and V18 ONLY by the boundary
# (a substring, in a comment). Disabling either is visible in exactly one cell.

# V17: the verbatim reproduction from the consumer's sprint-303 gate — a local variable
# named `stub`. A whole word, so the boundary cannot save it; the comment gate is the
# sole reason it is not examined. NO finding.
cat > "$TREE/src/v17_code_bare_stub.py" <<'EOF'
def make_driver():
    stub = AsyncMock(return_value=None)
    return stub
EOF

# V18: a comment whose only marker is a SUBSTRING inside an identifier. The comment gate
# admits the line, so the word boundary is the sole reason it is not examined. NO finding.
cat > "$TREE/src/v18_comment_substring.py" <<'EOF'
def call_remote():
    # the client_stub helper is fine and needs no follow-up
    return 0
EOF

# V19: the positive control for the pair — a bare prose marker inside a real comment,
# satisfying no element. This is what the gate is FOR, and it is what goes silent if the
# marker set is disarmed (`\b` is not in Darwin's ERE: `STUB_MARKER='\b(...)\b'` examines
# nothing at all and reports a clean tree). Element 1 rejects it.
cat > "$TREE/src/v19_comment_bare_stub.py" <<'EOF'
def settle():
    # stub, wire later
    return None
EOF

# V20: a prose marker in CODE that is not `stub`, so it also holds when only the `stub`
# alternative is comment-gated — the narrower of the two filed remedies. NO finding.
cat > "$TREE/src/v20_code_todo_data.py" <<'EOF'
def rejected_reasons():
    return ["TODO", "TBD", "n/a"]
EOF

# V21: the marker sits in a TRAILING `//` comment. The comment portion is not the whole
# line and the opener is not `#`, so this is the arm that goes silent if either the
# opener set narrows or the portion is taken as the leading prefix only. A finding.
cat > "$TREE/src/v21_slashslash_comment.js" <<'EOF'
function settle(order) {
  return order.total;  // stub, wire later
}
EOF

# V22: a comment opener INSIDE A STRING LITERAL. This is ordinary code — the consumer's
# own fixtures print marker text — and it is what the quote guard is for. NO finding.
cat > "$TREE/src/v22_quoted_opener.sh" <<'EOF'
emit_marker() {
  printf '# stub, wire later\n' > "$1"
}
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

# THE OWNERSHIP PAIRS CARRY A `TODO`, NOT A PHASE REFERENCE, AND THAT IS DELIBERATE.
# They were seeded on a bare `Phase 3`, which coupled a question about OWNERSHIP to a
# question about the marker VOCABULARY: narrowing the phase alternative moved V9 and V11
# as well as its own arms, so one mutation failed three assertions and two of the three
# were reporting someone else's defect. An ownership arm must survive every legitimate
# change to the marker set, so its payload is the least ambiguous marker in the set.
#
# V8: upstream-owned (`skills/ai-dlc-update/**`). Zero elements satisfied. EXEMPT.
# The verbatim text that failed the real gate stays in the block and is no longer a
# marker at all — a bare `Phase 3` in prose stopped being one. Keeping it here is the
# record of what this pair was seeded on and a second reading of V13/V16's rule in the
# one file where a false positive was historically unclearable.
cat > "$TREE/.claude/skills/ai-dlc-update/reconcile/apply.sh" <<'EOF'
#!/usr/bin/env bash
# So both captures happen here, together, in the only state in which ours-vs-base
# means what the status name claims. Phases 1 and 2 consume what this phase measured.
#
# Phase 3's layer-drift.sh does NOT belong here and is not exposed to the same fault: its
# consumer-side reads are layer_files(), which walks consumer-authored *.md.
#
# TODO: the drift ledger is not wired here yet.
PC="$(bash "$SELF/preclassify.sh" || true)"
EOF

# V9: a CONSUMER-owned hook. The core glob is `hooks/ai-dlc-*.sh`, so this is NOT
# core, sits one directory from files that are, and MUST still be audited.
cat > "$TREE/.claude/hooks/my-own-hook.sh" <<'EOF'
#!/usr/bin/env bash
# TODO: the dispatch table is not wired here yet.
exit 0
EOF

# ---- V10 / V11: the same discrimination, on FIXTURE ownership -----------------
# The manifest claims each shipped fixture dir as `fixtures/<name>/**`, and a consumer's
# OWN fixtures share the tests/fixtures/ directory under no distinguishing prefix — core
# and consumer dirs there both use the `check-` prefix, so no glob separates them and the
# entries have to be name-exact. That exactness is what V11 tests.
#
# V10 and V11 are a PAIR, same construction as V8/V9: both under tests/fixtures/, both
# carrying one `TODO` marker, both satisfying ZERO elements, differing ONLY in ownership.
# V11's directory name is deliberately a core fixture's name plus a suffix — a malformed
# entry (`fixtures/check-15-bypass**`, one dropped slash) over-captures it and flips V11,
# where a neutrally-named control would not notice.
#
# These markers are the payload. Scrubbing either one makes its file marker-free, the
# audit returns `ok`, and the assertion mismatches — loudly, not vacuously. The reason it
# is a `TODO` and not a phase reference is the one given at V8/V9: an ownership arm that
# borrows the marker vocabulary reports on the vocabulary too.
mkdir -p "$TREE/tests/fixtures/check-15-bypass" \
         "$TREE/tests/fixtures/check-15-bypass-local"

# V10: a CORE fixture — `fixtures/check-15-bypass/**` in the manifest. EXEMPT.
cat > "$TREE/tests/fixtures/check-15-bypass/seed.sh" <<'EOF'
#!/usr/bin/env bash
# Phase 3's layer-drift.sh is not exercised by this seed.
# TODO: the drift ledger is not wired here yet.
: # seeded
EOF

# V11: a CONSUMER-authored fixture, one suffix from a core name. NOT core. Audited.
cat > "$TREE/tests/fixtures/check-15-bypass-local/seed.sh" <<'EOF'
#!/usr/bin/env bash
# TODO: the dispatch table is not wired here yet.
: # seeded
EOF

echo "$TREE"
