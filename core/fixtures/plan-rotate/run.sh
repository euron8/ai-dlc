#!/usr/bin/env bash
# plan-rotate — assert that scripts/plan-rotate.sh grades fences the way CommonMark does, keeps
# every section its own declaration block names LIVE, refuses rather than guessing on a cut it
# cannot make safely, and that each of those properties can go RED.
#
# THE TWO MUTANTS THIS FIXTURE EXISTS FOR ARE THE TWO THAT PASSED EVERYTHING ELSE.
#
# 1. THE NAIVE FENCE TOGGLE. A grader that flips fence state on every backtick run disagrees with
#    CommonMark on a run whose INFO STRING CARRIES A BACKTICK, which CommonMark reads as a
#    paragraph. Measured on this repo's own longest plan: the toggle scored 10 fenced headings
#    where the info-string rule scores 1, because two such paragraphs opened and closed a fence
#    across an 1100-line band. The seed pair below is HAND-TYPED and shares no byte with that
#    file: two lines identical except that one carries a delimiter inside its info string and the
#    other does not. Under the shipped grader the first ROTATES and the second is REFUSED as an
#    unterminated fence; under the toggle both are refused. That is the whole discrimination, and
#    a seed copied out of the corpus would have agreed with the grader for the wrong reason.
#
# 2. THE ARM-3 TAUTOLOGY. The subject's first cut read arm 3's WANT side off the SPLITTER's own
#    `livesec` classification, so WANT and GOT were two readings of one decision. A mutant that
#    archived `## Start here` and the plan's read/write boundary reported PASS at rc=0. Arm 3 now
#    RE-DERIVES its WANT side and cross-checks the two, so that mutant dies — but a fixture that
#    scored the outcome by reading the subject's own report would still be satisfied by the
#    tautology. EVERY LIVE/ARCHIVED EXPECTATION BELOW IS A HAND-TYPED SENTINEL LIST, asserted
#    against the FILES ON DISK and never against a line the subject printed. `m1t` puts the
#    tautology back, and it is that sentinel arm and nothing else that kills it.
#
# WHY THE SEEDS ARE TYPED AND NOT DERIVED. A seed taken off the tree the arm reads is a typed copy
# of the arm's own answer; it passes a wrong fix as readily as a right one. Every plan here was
# written for this file: its section titles, its sentinels, its retrospective paragraphs and its
# two fence lines exist nowhere else in the repository.
#
# BOTH DIRECTIONS, ON THE PROPERTY THAT DISCRIMINATES. Each refusal arm has a QUIET twin one
# property away — the info-string pair above; a plan that names no live sections REFUSED over the
# ceiling and ACCEPTED under it; a fence wholly inside one section against a fence that splits a
# live one. A refusal arm with no quiet twin passes identically against a subject that refuses
# everything.
#
# Usage: run.sh [path-to-plan-rotate.sh]
# Exit:  0 = every assertion holds, 1 = an arm regressed, 2 = the fixture could not run.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

# WALK UP FOR THE VERSION MARKER, NEVER COUNT `..` HOPS. A hop count answers differently from the
# repo root, from a subdirectory, and from a sandbox that copied this file — and the sandbox
# answer is the silent one.
REPO_ROOT=""
d="$HERE"
while [ "$d" != "/" ]; do
  if [ -f "$d/VERSION" ]; then REPO_ROOT="$d"; break; fi
  d="$(dirname "$d")"
done
[ -n "$REPO_ROOT" ] || { echo "FIXTURE ERROR: no VERSION marker above $HERE" >&2; exit 2; }

# A MISSING SUBJECT IS NOT A PASS. Every arm below reads the subject's output or its writes, so a
# run that cannot invoke it produces nothing — and "nothing" satisfies every assertion phrased as
# an absence. An explicit argument that names no file is an ERROR and never a fallback: a
# mutation run drives this fixture with an alternately-named copy, and silently falling back to
# the tree's own script would score the ORIGINAL on every arm.
if [ $# -ge 1 ]; then
  SUBJ="$1"
  [ -f "$SUBJ" ] || { echo "FIXTURE ERROR: cannot locate plan-rotate.sh at $SUBJ" >&2; exit 2; }
else
  SUBJ="$REPO_ROOT/scripts/plan-rotate.sh"
  [ -f "$SUBJ" ] || { echo "FIXTURE ERROR: cannot locate plan-rotate.sh at $SUBJ" >&2; exit 2; }
fi

WORK="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
[ -n "$WORK" ] && [ -d "$WORK" ] || { echo "FIXTURE ERROR: mktemp -d produced no directory" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/seeds" "$WORK/roots"

FAIL=0
KILLS=0
echo "plan-rotate fixture"
echo "  subject: $SUBJ"
echo

ok()  { printf '  ok    %-26s %s\n' "$1" "$2"; }
bad() { printf '  FAIL  %-26s %s\n' "$1" "$2"; FAIL=1; }
broken() { printf 'FIXTURE BROKEN: %s\n' "$1" >&2; exit 2; }

# HERE-STRING, NEVER A PIPE. `grep -q` leaves at its first match while the writer is still
# pushing, and under pipefail the pipeline answers with the writer's EPIPE — a false NOT-FOUND on
# input that contains the pattern, correct until the output after the match fills the buffer.
has() { grep -qF -- "$1" <<<"$2"; }

# =============================================================================================
# THE SEEDS. Hand-typed plans. `base_head` and `base_tail` bracket the one site every fence seed
# varies, so the fence seeds differ from the conforming plan at exactly one place and a firing
# arm is attributable to that place.
#
# The heredocs stay QUOTED: their bodies carry backticks and `$0`-shaped text, and an unquoted
# heredoc would command-substitute both.
#
# They are also never wrapped in `$( )`. bash is 3.2 and its command-substitution parser counts
# parentheses across heredoc bodies it should not be reading; the subject's own header and the
# backlog-rotate fixture beside this one both record the same trap.
# =============================================================================================
base_head() {
  cat <<'MD'
# Probe plan for the plan-rotate fixture

Resume with: READ and FOLLOW docs/plans/probe.md

## Start here

LIVE-STARTHERE-SENTINEL. This is the first level-2 section, so it is this plan's declaration
block, and the titles it names in backticks inside the numbered list below are its LIVE set.
Every other section is finished history and may be rotated out to the archive.

1. `## Start here` -- you are reading it now, and it is live by construction.
2. `## Hazards` -- read this before touching anything at all in either tree.
3. `### NEXT ACTIONS` -- the ordered list this plan exists in order to hand over.

## Hazards

LIVE-HAZARD-SENTINEL. The hazards section is deliberately the LARGEST live section in this
seed. A mutant that lets a named-live section into an archivable span takes the largest span
first, so this is the one it eats, and the sentinel above is how that is observed.
MD
}

base_tail() {
  cat <<'MD'

HAZ-FILLER-A. Padding that exists to give the live core a size the ceiling can be set against.
HAZ-FILLER-B. Padding that exists to give the live core a size the ceiling can be set against.
HAZ-FILLER-C. Padding that exists to give the live core a size the ceiling can be set against.
HAZ-FILLER-D. Padding that exists to give the live core a size the ceiling can be set against.
HAZ-FILLER-E. Padding that exists to give the live core a size the ceiling can be set against.
HAZ-FILLER-F. Padding that exists to give the live core a size the ceiling can be set against.

### NEXT ACTIONS

1. LIVE-NEXTACTION-SENTINEL. Do the first thing. This instruction is the plan's whole point
   and it must survive every rotation.

   **BATCH 7** -- RETRO-SEVEN-SENTINEL. A retrospective paragraph appended under action 1,
   indented, and delimited by the second boundary grammar rather than by a heading. A rotation
   that moves only whole SECTIONS cannot reach this text, and this text is where the bytes are.
   RETRO-SEVEN-FILLER-A. Padding inside the retrospective run.
   RETRO-SEVEN-FILLER-B. Padding inside the retrospective run.
   RETRO-SEVEN-FILLER-C. Padding inside the retrospective run.

   **BATCH 8** -- RETRO-EIGHT-SENTINEL. A second retrospective paragraph in the same run, so
   the run's end is decided by the column-zero line below it and not by the next batch.
   RETRO-EIGHT-FILLER-A. Padding inside the retrospective run.
   RETRO-EIGHT-FILLER-B. Padding inside the retrospective run.
   RETRO-EIGHT-FILLER-C. Padding inside the retrospective run.

2. LIVE-NEXTACTION-TWO-SENTINEL. Do the second thing. This line sits at column zero, which is
   what ends the retrospective run above it, so it must stay live.

## SPENT ONE

SPENT-ONE-SENTINEL. A spent section. Nothing in the declaration block names it, so a rotation
may move it, and the whole of it must land in the archive rather than half of it.
SPENT-ONE-FILLER-A. Padding that makes this span worth taking.
SPENT-ONE-FILLER-B. Padding that makes this span worth taking.
SPENT-ONE-FILLER-C. Padding that makes this span worth taking.
SPENT-ONE-FILLER-D. Padding that makes this span worth taking.

## SPENT TWO

SPENT-TWO-SENTINEL. A second spent section, adjacent to the first, so the two form one
maximal run of consecutive non-live sections and a rotation takes them together.
SPENT-TWO-FILLER-A. Padding that makes this span worth taking.
SPENT-TWO-FILLER-B. Padding that makes this span worth taking.
SPENT-TWO-FILLER-C. Padding that makes this span worth taking.
SPENT-TWO-FILLER-D. Padding that makes this span worth taking.
MD
}

# THE DISCRIMINATING PAIR, TYPED HERE AND NOWHERE ELSE. Both are a three-backtick run at column
# zero. The first's info string CARRIES a backtick, which CommonMark forbids in a backtick
# fence's info string, so the line is a PARAGRAPH and the plan holds no fence at all. The
# second's does not, so it is a real opener that never closes.
PARA_INFO_LINE='```text holding a `delimiter` inside its info string, which is a paragraph'
REAL_OPENER_LINE='```text holding no stray delimiter inside its info string, so it opens a fence'

# A fence that SPLITS a live section, quoting a heading. Under the shipped grader the quoted
# heading is fenced and is not a boundary; blind the heading scan to fence state and it becomes
# one, and the cut then lands on a fenced line.
fence_block() {
  cat <<'MD'

```markdown
## QUOTED-HEADING-INSIDE-A-FENCE
```
MD
}

# The declaration block with its backticked titles removed from the numbered list. Everything
# else is byte-identical to `base_head`, so the NONAMED refusal is attributable to the join's
# missing side and to nothing else about the plan.
nonamed_head() {
  cat <<'MD'
# Probe plan for the plan-rotate fixture

Resume with: READ and FOLLOW docs/plans/probe.md

## Start here

LIVE-STARTHERE-SENTINEL. This is the first level-2 section, so it is this plan's declaration
block, and the titles it names in backticks inside the numbered list below are its LIVE set.
Every other section is finished history and may be rotated out to the archive.

1. Start here -- you are reading it now, and it is live by construction.
2. Hazards -- read this before touching anything at all in either tree.
3. NEXT ACTIONS -- the ordered list this plan exists in order to hand over.

## Hazards

LIVE-HAZARD-SENTINEL. The hazards section is deliberately the LARGEST live section in this
seed. A mutant that lets a named-live section into an archivable span takes the largest span
first, so this is the one it eats, and the sentinel above is how that is observed.
MD
}

{ base_head; base_tail; }                      > "$WORK/seeds/base.md"
{ base_head; printf '\n%s\n' "$PARA_INFO_LINE";   base_tail; } > "$WORK/seeds/para-info.md"
{ base_head; printf '\n%s\n' "$REAL_OPENER_LINE"; base_tail; } > "$WORK/seeds/real-opener.md"
{ base_head; fence_block; base_tail; }         > "$WORK/seeds/fenced-heading.md"
{ nonamed_head; base_tail; }                   > "$WORK/seeds/nonamed.md"

cat > "$WORK/seeds/nodecl.md" <<'MD'
# Probe plan with no level-2 heading anywhere in it

Resume with: READ and FOLLOW docs/plans/probe.md

### A third-level heading, which is not a declaration block

NODECL-SENTINEL. This plan carries a level-1 title and a level-3 heading and nothing at level
two, so there is no first level-2 section to read a live set out of.
NODECL-FILLER-A. Padding to carry this seed over the ceiling the arm drives it with.
NODECL-FILLER-B. Padding to carry this seed over the ceiling the arm drives it with.
NODECL-FILLER-C. Padding to carry this seed over the ceiling the arm drives it with.
NODECL-FILLER-D. Padding to carry this seed over the ceiling the arm drives it with.
NODECL-FILLER-E. Padding to carry this seed over the ceiling the arm drives it with.
NODECL-FILLER-F. Padding to carry this seed over the ceiling the arm drives it with.
NODECL-FILLER-G. Padding to carry this seed over the ceiling the arm drives it with.
NODECL-FILLER-H. Padding to carry this seed over the ceiling the arm drives it with.
MD

cat > "$WORK/seeds/noheadings.md" <<'MD'
NOHEADINGS-SENTINEL. This file carries no ATX heading at any level, so it has no sections to
partition and no boundary a rotation could cut on.
NOHEAD-FILLER-A. Padding to carry this seed over the ceiling the arm drives it with.
NOHEAD-FILLER-B. Padding to carry this seed over the ceiling the arm drives it with.
NOHEAD-FILLER-C. Padding to carry this seed over the ceiling the arm drives it with.
NOHEAD-FILLER-D. Padding to carry this seed over the ceiling the arm drives it with.
NOHEAD-FILLER-E. Padding to carry this seed over the ceiling the arm drives it with.
NOHEAD-FILLER-F. Padding to carry this seed over the ceiling the arm drives it with.
NOHEAD-FILLER-G. Padding to carry this seed over the ceiling the arm drives it with.
NOHEAD-FILLER-H. Padding to carry this seed over the ceiling the arm drives it with.
MD

# EVERY SECTION LIVE, NO RECORD, NO INDENTED RETROSPECTIVE PARAGRAPH: over any ceiling below its
# size there is no span of any class to take. This is the shape the subject used to answer with
# the UNDER-ceiling sentence at exit 0, because its nothing-moved branch ran before its
# unreachable test and pre-empted it.
cat > "$WORK/seeds/nocand.md" <<'MD'
# Probe plan whose every section is live

Resume with: READ and FOLLOW docs/plans/probe.md

## Start here

NOCAND-STARTHERE-SENTINEL. Both sections of this plan are named live below, and neither holds a
column-zero batch record or an indented retrospective paragraph, so nothing in it is archivable.

1. `## Start here` -- you are reading it now, and it is live by construction.
2. `## Hazards` -- live, and the larger of the two sections.

## Hazards

NOCAND-HAZARD-SENTINEL. A live section with no record in it and no retrospective run under it.
NOCAND-FILLER-A. Padding to carry this seed over the ceiling the arm drives it with.
NOCAND-FILLER-B. Padding to carry this seed over the ceiling the arm drives it with.
NOCAND-FILLER-C. Padding to carry this seed over the ceiling the arm drives it with.
NOCAND-FILLER-D. Padding to carry this seed over the ceiling the arm drives it with.
MD

# THE BATCH-RECORD SEED. A resume block holding forty COLUMN-ZERO records numbered newest-first,
# 140 down to 101, under a header paragraph that is not a record, each record three column-zero
# paragraphs whose size rises strictly with the record's number -- so an oldest-first selection
# and a smallest-first one pick the same records and a NEWEST-first one picks different ones.
# Three planted shapes, each the subject of one mutant below:
#
#   - record 140, the max and the first, carries a fence quoting a column-zero `**BATCH 999`. It
#     must stay live, fence and all.
#   - record 130, an ELIGIBLE record, carries a fence quoting a column-zero `**BATCH 55`. The 999
#     line alone cannot kill a fence-blind opener scan: sitting in the first record, it opens a
#     record that is the new max and is protected either way, so nothing moves differently. The
#     55 line sits where a fence-blind scan opens a CANDIDATE on a fenced line, and the fence-cut
#     refusal fires.
#   - record 105, a record the rotation archives, carries an INDENTED `**BATCH 77` paragraph --
#     class-2-shaped text inside a class-3 record, the overlap the partition assertion exists for.
#
# A spent section sits between the resume block and `### NEXT ACTIONS`, adjacent to the oldest
# record, so a rotation that takes it and a run of old records writes ONE coalesced range. It is
# also what gives the near-miss a subject: at a ceiling it alone reaches, class 3 must not move.
#
# The records are generated by a loop rather than typed out forty times; every byte of them is
# still this file's, and none is read off the tree the subject rotates.
batch_head() {
  cat <<'MD'
# Probe plan carrying column-zero batch records

Resume with: READ and FOLLOW docs/plans/probe.md

## Start here

BSTART-SENTINEL. The declaration block of the batch-record seed. It names three live sections,
and the resume block it names holds forty column-zero batch records under a header paragraph.

1. `## Start here` -- you are reading it now, and it is live by construction.
2. `## RESUME HERE` -- the resume block, whose oldest records are history.
3. `### NEXT ACTIONS` -- the ordered list this plan exists in order to hand over.

## RESUME HERE

RESUME-HEADER-SENTINEL. A header paragraph that is not a record. It opens the section, so it
precedes the first record and belongs to none of them.

MD
}
batch_records() {
  LC_ALL=C awk 'BEGIN {
    for (r = 140; r >= 101; r--) {
      pad = sprintf("%" (1000 + 150 * (r - 101)) "s", ""); gsub(/ /, ".", pad)
      printf "**BATCH %d** -- REC-%d-OPEN. The column-zero opener of record %d.\n\n", r, r, r
      printf "REC-%d-BODY. %s\n\n", r, pad
      if (r == 140) printf "```text\n**BATCH 999** -- FENCED-999-SENTINEL. A quoted opener inside a fence, which opens nothing.\n```\n\n"
      if (r == 130) printf "```text\n**BATCH 55** -- FENCED-55-SENTINEL. A quoted opener inside an eligible record.\n```\n\n"
      if (r == 105) printf "   **BATCH 77** -- INDENTED-77-SENTINEL. An indented batch paragraph inside a record.\n\n"
      printf "REC-%d-TAIL. The third column-zero paragraph of record %d.\n\n", r, r
    }
  }'
}
batch_tail() {
  cat <<'MD'
## SPENT BATCH-SEED

SPENT-BATCH-SENTINEL. A spent section. The declaration block does not name it, so it is class 1
and is taken before any batch record is.
SPENT-BATCH-FILLER-A. Padding that makes this span larger than the pointer line it costs.
SPENT-BATCH-FILLER-B. Padding that makes this span larger than the pointer line it costs.
SPENT-BATCH-FILLER-C. Padding that makes this span larger than the pointer line it costs.
SPENT-BATCH-FILLER-D. Padding that makes this span larger than the pointer line it costs.
SPENT-BATCH-FILLER-E. Padding that makes this span larger than the pointer line it costs.

### NEXT ACTIONS

1. BNEXT-SENTINEL. Do the next thing. This instruction must survive every rotation.
MD
}
{ batch_head; batch_records; batch_tail; } > "$WORK/seeds/batch.md"

# THE HAND-TYPED EXPECTATION. Not one of these tokens is read back off the subject's report; each
# is asserted against the bytes of the file the subject wrote. This is the list that kills the
# arm-3 tautology, and it is the reason it is typed rather than derived.
LIVE_SENTINELS="LIVE-STARTHERE-SENTINEL
LIVE-HAZARD-SENTINEL
LIVE-NEXTACTION-SENTINEL
LIVE-NEXTACTION-TWO-SENTINEL"
MOVED_SENTINELS="SPENT-ONE-SENTINEL
SPENT-TWO-SENTINEL
RETRO-SEVEN-SENTINEL
RETRO-EIGHT-SENTINEL"

# THE CEILINGS ARE DERIVED FROM THE SEED, NOT TYPED, AND THE TYPED ONES ARE WHY. This file
# shipped `CEIL=2000` and `CEIL_ONE_SPAN=2800`, each measured at the time and each correct at the
# time. Then the subject started BUDGETING ITS OWN POINTER LINE inside the selection loop, and
# both went wrong at once without a byte of the seed changing: the live core is 1774 and the
# pointer 238, so 2000 became UNREACHABLE and the conforming plan was REFUSED at base-apply, and
# 2800 fell inside the band where BOTH spans move, leaving the pointer-refresh arm nothing to take
# on its second step. A typed ceiling is a measurement of the subject frozen at one commit, and
# it goes stale in exactly the direction that reads as a regression in the change under test.
#
# So every ceiling below is computed from two things this fixture measures itself: the byte size
# of each span, read off the SEED by its own markers, and the cost of the pointer line, read off
# the DISK after one calibrating apply. The calibration moves only the section run (it is the
# larger span, and the greedy takes the largest first), so the file it writes is
#
#     F_ONE = live_core + retro_run + pointer
#
# and the pointer cost falls out as F_ONE - (seed - section_run). The bands, derived:
#
#     both spans move     live_core + pointer  <=  C  <  F_ONE
#     only the section    F_ONE  <=  C  <  seed
#
# `CEIL` sits half a retrospective run below F_ONE, so it clears the lower bound by the same
# half-run -- far more than the few bytes a second range adds to the pointer. `CEIL_ONE_SPAN`
# sits midway through the upper band. `CEIL_STEP2` is derived at the pointer-refresh arm from the
# size the FIRST step actually wrote, since that file is the second step's input.
#
# The `base-both-grammars` arm asserts the classes actually moved and says FIXTURE BROKEN rather
# than FAIL if they did not: a mis-set constant is a dead harness, not a regression in the
# subject, and the two must not read alike.
BASE_BYTES="$(wc -c < "$WORK/seeds/base.md" | tr -d ' ')"
SPANS="$(LC_ALL=C awk '
  /^## SPENT ONE$/ { in1 = 1 }
  /^   \*\*BATCH 7\*\*/ { in2 = 1 }
  /^2\. LIVE-NEXTACTION-TWO-SENTINEL/ { in2 = 0 }
  { b = length($0) + 1; if (in1) s1 += b; if (in2) s2 += b }
  END { printf "%d %d\n", s1, s2 }' "$WORK/seeds/base.md")"
SPAN1_B="${SPANS% *}"; SPAN2_B="${SPANS#* }"
[ "${SPAN1_B:-0}" -gt 0 ] && [ "${SPAN2_B:-0}" -gt 0 ] && [ "$SPAN1_B" -gt "$SPAN2_B" ] \
  || { echo "FIXTURE BROKEN: the seed's span markers measured section=$SPAN1_B retro=$SPAN2_B; the calibration needs both, the section run the larger" >&2; exit 2; }

# =============================================================================================
# Driving.
# =============================================================================================
mkroot() { # mkroot <name> [<subject>] -> echoes the root path
  local r="$WORK/roots/$1"
  mkdir -p "$r/scripts" "$r/docs/plans" || return 1
  # A SYNTHETIC MARKER, NOT A COPY OF THE REAL `VERSION`. The subject only tests that the file
  # EXISTS in order to find its root, and `VERSION` is excluded from the suite content key — so
  # reading it would make this fixture's input changeable without the suite re-running, which
  # `I55` in validate-enforcement-map.sh fails the push on.
  printf '0.0.0-fixture-sandbox\n' > "$r/VERSION"
  cp "${2:-$SUBJ}" "$r/scripts/plan-rotate.sh" || return 1
  printf '%s' "$r"
}

LAST_OUT=""; LAST_RC=0; LAST_PLAN=""; LAST_ARCH=""; LAST_WROTE=""; LAST_UNTOUCHED=""
drive() { # drive <root> <seedfile> <slug> [args...]
  local r="$1" sf="$2" sl="$3"; shift 3
  case "$r" in "$WORK"/*) ;; *) broken "drive was handed a root outside the scratch tree: $r" ;; esac
  LAST_PLAN="$r/docs/plans/$sl.md"
  LAST_ARCH="$r/docs/plans/archive/$sl.md"
  cp "$sf" "$LAST_PLAN" || broken "could not seed $LAST_PLAN"
  rm -f "$LAST_ARCH"
  LAST_OUT="$(bash "$r/scripts/plan-rotate.sh" "$LAST_PLAN" "$@" 2>&1)"
  LAST_RC=$?
  # THE WROTE-NOTHING VERDICT IS SNAPSHOTTED HERE, NOT TESTED LATER, AND THIS IS A MEASURED
  # DEFECT IN THIS FILE'S FIRST CUT. A root is driven twice — the mutant seed and its control —
  # and both write to the SAME archive path, so a `[ ! -f "$LAST_ARCH" ]` read after the second
  # drive sees the second run's archive and reports that the first run wrote. `mutant:m5` failed
  # exactly that way with the mutant firing correctly, which reads as an arm that cannot fire.
  LAST_WROTE=yes;     [ -f "$LAST_ARCH" ] || LAST_WROTE=no
  LAST_UNTOUCHED=yes; cmp -s "$LAST_PLAN" "$sf" || LAST_UNTOUCHED=no
}

# =============================================================================================
# THE DISCRIMINATORS, CHECKED BEFORE ANY ARM READS ONE. A sentence that stopped being emitted
# makes every `! has` below vacuously true and every kill unearned — the failure this fixture
# exists to catch, one level down. A sentence that CONTAINS another stops discriminating the
# moment both can fire.
# =============================================================================================
S_UNTERM="a fence opened at line"
S_FENCECUT="a section boundary lands inside a fenced block"
S_NONAMED="THIS IS THE SIDE OF THE JOIN THAT SAYS WHAT IS LIVE"
S_NODECL="it has no declaration block naming its live sections"
S_NOHEAD="it has no sections to partition"
S_UNREACH="every archivable span was taken"
S_ARM1="arm 1 (conservation) FAILED"
S_ARM2="arm 2 (multiset identity) FAILED"
S_ARM3="arm 3 (live-section set) FAILED"
S_ARM3X="two independent derivations of the LIVE-SECTION"
S_ARM1OK="arm 1 conservation PASS"
S_ARM2OK="arm 2 multiset identity PASS"
S_ARM3OK="arm 3 live-section set PASS"
S_NOTHING="nothing to move"
S_NOCAND="no archivable span of any class was found"
S_ARM4="arm 4 (protected-record) FAILED"
S_ARM4OK="arm 4 protected-record PASS"
S_ARM4LOST="a protected batch record is not in the live remainder"
S_ARM4INV="was archived while the OLDER record"
S_PARTITION="the candidate spans are not a partition"
S_BUDGET="The budget and the write disagree"

# THE POINTER IS KEYED ON THE ARCHIVE PATH, NOT ON THE SENTENCE AROUND IT, AND THAT IS A
# REPAIR. The first cut of this file hardcoded `Spent sections are archived at` at six sites;
# the rotator then had to change that opening — it spelled a discharge token, see the
# `rotated-plan-stays-live` arm below — and three assertions here went red on a CORRECT fix,
# reading exactly like a regression in the change under test.
#
# The archive path is what the pointer is FOR: an archived record nothing points at is
# evidence no reader can find. The prose around it is presentation and has now moved once.
# Measured on the real rotated plan, both figures in one invocation: `docs/plans/archive/`
# appears exactly 1 time, and so does the pointer sentence — so keying on the path is not a
# widening, it selects the same single line. The uniqueness is re-derived per run at the
# `pointer` arm rather than assumed, because a plan that happened to cite the archive
# directory in its prose would make the key ambiguous, and an ambiguous key must fail loudly
# rather than silently match the wrong line.
PTR_KEY='docs/plans/archive/probe.md'

SENTS="$S_UNTERM
$S_FENCECUT
$S_NONAMED
$S_NODECL
$S_NOHEAD
$S_UNREACH
$S_ARM1
$S_ARM2
$S_ARM3
$S_ARM3X
$S_ARM1OK
$S_ARM2OK
$S_ARM3OK
$S_NOTHING
$S_NOCAND
$S_ARM4
$S_ARM4OK
$S_ARM4LOST
$S_ARM4INV
$S_PARTITION
$S_BUDGET"
N_SENTS="$(LC_ALL=C grep -c . <<<"$SENTS")" || N_SENTS=0

sent_ok=1
while IFS= read -r _s; do
  [ -n "$_s" ] || continue
  _n="$(grep -cF -- "$_s" "$SUBJ")" || _n=0
  if [ "$_n" -lt 1 ]; then
    bad "discriminators" "the subject emits no copy of: $_s"
    sent_ok=0
  fi
done <<<"$SENTS"
while IFS= read -r _a; do
  [ -n "$_a" ] || continue
  while IFS= read -r _b; do
    [ -n "$_b" ] || continue
    if [ "$_a" != "$_b" ] && case "$_a" in *"$_b"*) true ;; *) false ;; esac; then
      bad "discriminators" "one arm's sentence contains another's, so it cannot discriminate: [$_a] vs [$_b]"
      sent_ok=0
    fi
  done <<<"$SENTS"
done <<<"$SENTS"
[ "$sent_ok" -eq 1 ] && ok "discriminators" "$N_SENTS verdict sentences, each emitted by the subject, none a substring of another"

# THE SEED PAIR MUST DIFFER ON THE PROPERTY THAT DISCRIMINATES, AND IT IS ASSERTED BEFORE IT IS
# USED. Two seeds that differ somewhere else read as a working receipt and are not one: the whole
# claim below is that a backtick INSIDE THE INFO STRING is what separates a paragraph from a
# fence, so the pair has to differ there and nowhere structurally else.
pi_info="${PARA_INFO_LINE#\`\`\`}"
ro_info="${REAL_OPENER_LINE#\`\`\`}"
case "$pi_info" in
  *'`'*) case "$ro_info" in
           *'`'*) bad "seed-pair" "both fence seeds carry a delimiter in the info string — the pair discriminates nothing" ;;
           *)     ok  "seed-pair" "the pair differs exactly on the info string: one carries a delimiter, the other does not" ;;
         esac ;;
  *) bad "seed-pair" "the paragraph seed carries NO delimiter in its info string, so it is a real opener and the pair is inverted" ;;
esac
cmp -s "$WORK/seeds/para-info.md" "$WORK/seeds/real-opener.md" \
  && bad "seed-pair" "the two fence seeds are byte-identical" \
  || ok "seed-pair" "and the two seeds differ on disk"

# =============================================================================================
# THE CALIBRATION, AND THE CEILINGS IT DERIVES. See the ceiling block above for why they are not
# typed. One apply one byte under the seed's size: the greedy takes the LARGER span, the section
# run, and must stop there because that span alone outweighs the pointer it costs. The file that
# lands is F_ONE, and it is read off the DISK -- never off the subject's report.
# =============================================================================================
CAL="$(mkroot calibrate)" || broken "could not build the calibration sandbox root"
drive "$CAL" "$WORK/seeds/base.md" probe --ceiling "$((BASE_BYTES - 1))" --apply
[ "$LAST_RC" -eq 0 ] || broken "the calibrating apply one byte under the seed was refused (exit $LAST_RC): $LAST_OUT"
CAL_ARCH="$(cat "$LAST_ARCH" 2>/dev/null)"
if ! has "SPENT-ONE-SENTINEL" "$CAL_ARCH" || has "RETRO-SEVEN-SENTINEL" "$CAL_ARCH"; then
  broken "the calibrating apply did not move exactly the section run, so F_ONE is not the quantity the ceilings are derived from"
fi
F_ONE="$(wc -c < "$LAST_PLAN" | tr -d ' ')"
PTR_B=$((F_ONE - (BASE_BYTES - SPAN1_B)))
LIVE_CORE_B=$((BASE_BYTES - SPAN1_B - SPAN2_B))
CEIL=$((F_ONE - SPAN2_B / 2))
CEIL_ONE_SPAN=$((F_ONE + (BASE_BYTES - F_ONE) / 2))
if [ "$PTR_B" -le 0 ] || [ "$CEIL" -le $((LIVE_CORE_B + PTR_B)) ] || [ "$CEIL_ONE_SPAN" -ge "$BASE_BYTES" ] || [ "$CEIL_ONE_SPAN" -le "$F_ONE" ]; then
  broken "the derived bands are empty: seed=$BASE_BYTES section=$SPAN1_B retro=$SPAN2_B pointer=$PTR_B F_ONE=$F_ONE CEIL=$CEIL CEIL_ONE_SPAN=$CEIL_ONE_SPAN"
fi
ok "calibration" "seed $BASE_BYTES = core $LIVE_CORE_B + section $SPAN1_B + retro $SPAN2_B; pointer $PTR_B; CEIL=$CEIL (both spans), CEIL_ONE_SPAN=$CEIL_ONE_SPAN (section only)"

# =============================================================================================
# THE CONFORMING BASE. Every seeded defect is this plan with one thing changed.
# =============================================================================================
R="$(mkroot base)" || broken "could not build the base sandbox root"
drive "$R" "$WORK/seeds/base.md" probe --ceiling "$CEIL" --apply
BASE_OUT="$LAST_OUT"; BASE_RC="$LAST_RC"

if [ -z "$BASE_OUT" ]; then
  broken "plan-rotate.sh emitted nothing at all on the conforming seed. Every assertion below reads that output or the files it wrote, so this is a dead harness and not a regression."
fi
if [ "$BASE_RC" -ne 0 ]; then
  # A REFUSAL OF THE CONFORMING PLAN IS TWO DIFFERENT EVENTS AND THEY MUST NOT READ ALIKE.
  # Refused BY AN ACCEPTANCE ARM is a regression in the subject — the split it computed does not
  # survive its own test — and belongs in the FAIL tally the gate reads as a defect. Refused for
  # any other reason means the seed no longer reaches the behaviour under test, which is a dead
  # harness. Measured while proving this file can go red: a subject that archives a named-live
  # section refuses HERE, at arm 3, and the undifferentiated form reported it as BROKEN — a
  # subject regression wearing a harness failure's label, which is the inverse of the confusion
  # `CLAUDE.md` records about hand-rolled suite loops.
  if has "$S_ARM1" "$BASE_OUT" || has "$S_ARM2" "$BASE_OUT" || has "$S_ARM3" "$BASE_OUT" || has "$S_ARM3X" "$BASE_OUT"; then
    bad "base-applies" "the conforming plan was refused by one of its own acceptance arms (exit $BASE_RC): $(head -3 <<<"$BASE_OUT" | tr '\n' '|')"
    echo
    echo "plan-rotate: FAIL — the subject cannot rotate a conforming plan, so no arm below is readable." >&2
    exit 1
  fi
  broken "the conforming seed was refused for a reason no acceptance arm names (exit $BASE_RC) — the seed no longer reaches the behaviour under test: $BASE_OUT"
fi
ok "base-applies" "the conforming plan rotates and exits 0"

[ -f "$LAST_ARCH" ] || broken "the conforming --apply wrote no archive at $LAST_ARCH"
BASE_LIVE="$(cat "$LAST_PLAN")"
BASE_ARCH="$(cat "$LAST_ARCH")"

# --- THE SENTINEL ARM. HAND-TYPED EXPECTATION, ASSERTED AGAINST THE FILES. ------------------
# This is the arm that kills the tautology. It never reads a line the subject printed about what
# it did; it reads what is on disk. A subject that reports perfectly and writes the wrong halves
# fails here and passes everywhere else.
sent_fail=0
while IFS= read -r _t; do
  [ -n "$_t" ] || continue
  has "$_t" "$BASE_LIVE" || { bad "live-set" "a section the declaration block names LIVE is not in the live remainder: $_t"; sent_fail=1; }
  has "$_t" "$BASE_ARCH" && { bad "live-set" "a LIVE sentinel was written into the archive: $_t"; sent_fail=1; }
done <<<"$LIVE_SENTINELS"
while IFS= read -r _t; do
  [ -n "$_t" ] || continue
  has "$_t" "$BASE_ARCH" || { bad "moved-set" "a spent sentinel did not reach the archive: $_t"; sent_fail=1; }
  has "$_t" "$BASE_LIVE" && { bad "moved-set" "a spent sentinel is still in the live remainder: $_t"; sent_fail=1; }
done <<<"$MOVED_SENTINELS"
if [ "$sent_fail" -eq 0 ]; then
  ok "live-set" "all 4 hand-typed live sentinels are in the live half and none is in the archive"
  ok "moved-set" "all 4 hand-typed spent sentinels are in the archive and none is in the live half"
fi

# --- BOTH BOUNDARY GRAMMARS FIRED -----------------------------------------------------------
# A section-run rotation alone leaves the retrospective tail behind, which is where the bytes
# are. If only one class moved the ceiling constant is wrong and every arm keyed on the other
# class is inert — that is a dead harness, so it is reported as BROKEN and not as a FAIL.
if ! has "SPENT-ONE-SENTINEL" "$BASE_ARCH"; then
  broken "the ceiling constant $CEIL left the spent-section run in place; class 1 is untested"
fi
if ! has "RETRO-SEVEN-SENTINEL" "$BASE_ARCH"; then
  broken "the ceiling constant $CEIL left the retrospective run in place; class 2 is untested"
fi
ok "base-both-grammars" "both boundary grammars moved a span: a section run and a retrospective BATCH run"

# --- THE THREE ACCEPTANCE ARMS RAN AND PASSED ------------------------------------------------
if has "$S_ARM1OK" "$BASE_OUT" && has "$S_ARM2OK" "$BASE_OUT" && has "$S_ARM3OK" "$BASE_OUT"; then
  ok "base-arms-ran" "all three acceptance arms reported PASS on the conforming rotation"
else
  bad "base-arms-ran" "an acceptance arm did not report on a successful rotation: $BASE_OUT"
fi

# --- CONSERVATION, MEASURED BY THIS FIXTURE AND NOT READ OFF THE SUBJECT ---------------------
# The subject asserts conservation itself. So does this, independently, on the bytes: a receipt
# that reads the subject's own verdict establishes that the subject has an opinion.
ORIG_B="$(wc -c < "$WORK/seeds/base.md" | tr -d ' ')"
LIVE_B="$(wc -c < "$LAST_PLAN" | tr -d ' ')"
# The archive carries a declared header, and the live half carries a pointer line, so the two
# halves do NOT sum to the original. What must hold is that every ORIGINAL line is present
# exactly once across the two files: a multiset, which no pair of cancelling edits survives.
LC_ALL=C sort "$WORK/seeds/base.md" > "$WORK/exp.sorted"
{ cat "$LAST_PLAN"; cat "$LAST_ARCH"; } | LC_ALL=C grep -vF "$PTR_KEY" \
  | LC_ALL=C grep -vF 'archived sections' \
  | LC_ALL=C grep -vF 'rotated out of' \
  | LC_ALL=C grep -vF 'Nothing here is deleted' \
  | LC_ALL=C grep -vF 'read it when a rule in the live plan' \
  | LC_ALL=C grep -vF 'behind a figure. **Do not take an instruction from it.**' \
  | LC_ALL=C sort > "$WORK/got.raw"
# The header and the pointer each introduce a blank line too; compare the NON-BLANK multisets and
# assert separately that no non-blank line was lost or invented.
LC_ALL=C grep -v '^[[:space:]]*$' "$WORK/exp.sorted" > "$WORK/exp.nb"
LC_ALL=C grep -v '^[[:space:]]*$' "$WORK/got.raw"    > "$WORK/got.nb"
if cmp -s "$WORK/exp.nb" "$WORK/got.nb"; then
  ok "conservation" "every non-blank line of the original is present exactly once across the two halves"
else
  bad "conservation" "$(diff "$WORK/exp.nb" "$WORK/got.nb" | head -6 | tr '\n' '|')"
fi

# --- THE POINTER ------------------------------------------------------------------------------
# An archived record nothing points at is evidence that still exists and no reader can find,
# which reads exactly like the evidence being gone. And it must be a PLAIN PATH: a `path:line`
# citation into an archive that a later rotation re-numbers fails `validate-plan-shape.sh`'s
# citation arm on a CORRECT rotation.
PTR_N="$(LC_ALL=C grep -cF "$PTR_KEY" "$LAST_PLAN")" || PTR_N=0
PTR_LINE="$(LC_ALL=C grep -F "$PTR_KEY" "$LAST_PLAN")"
if [ "$PTR_N" -ne 1 ]; then
  bad "pointer" "expected exactly one pointer line in the live plan, found $PTR_N"
elif has "$WORK" "$PTR_LINE"; then
  bad "pointer" "the pointer carries an absolute sandbox path, which resolves on one machine only: $PTR_LINE"
elif grep -qE 'docs/plans/archive/probe\.md:[0-9]' <<<"$PTR_LINE"; then
  bad "pointer" "the pointer is a path:line citation into the archive; a later rotation re-numbers it and the citation arm then fails a correct rotation"
else
  ok "pointer" "one pointer line, repo-relative, and not a path:line citation"
fi

# THE POINTER IS REFRESHED, NOT APPENDED, AND THE RANGE IT NAMES MOVES. A second rotation must
# leave ONE pointer carrying the CURRENT range and must not stack a second archive header. Its
# own root, and a TWO-STEP ceiling: at `CEIL_ONE_SPAN` only the section run goes, so the plan is
# still over `CEIL` afterwards and a second rotation has the retrospective run left to take.
# Driving both steps at the same ceiling would leave nothing to move and the arm would pass on a
# no-op, which is the shape that cannot fail.
#
# `CEIL_STEP2` IS DERIVED FROM THE FILE THE FIRST STEP WROTE, half a retrospective run under it.
# The second step REPLACES a pointer rather than inserting one, so its pointer cost is the
# difference of two range texts -- a few bytes -- and half a run clears it. And the first step is
# asserted to have left the retrospective run LIVE: the typed `CEIL_ONE_SPAN=2800` stopped doing
# that once the pointer was budgeted, and the arm below then read a two-step rotation whose
# second step had nothing to do.
PR="$(mkroot pointer)" || broken "could not build the pointer sandbox root"
drive "$PR" "$WORK/seeds/base.md" probe --ceiling "$CEIL_ONE_SPAN" --apply
FIRST_RC="$LAST_RC"
PTR_1="$(LC_ALL=C grep -F "$PTR_KEY" "$LAST_PLAN")"
if has "RETRO-SEVEN-SENTINEL" "$(cat "$LAST_ARCH" 2>/dev/null)"; then
  broken "the first step at CEIL_ONE_SPAN=$CEIL_ONE_SPAN already moved the retrospective run, so the pointer-refresh arm's second step has nothing to take"
fi
FIRST_B="$(wc -c < "$LAST_PLAN" | tr -d ' ')"
CEIL_STEP2=$((FIRST_B - SPAN2_B / 2))
SECOND_OUT="$(bash "$PR/scripts/plan-rotate.sh" "$LAST_PLAN" --ceiling "$CEIL_STEP2" --apply 2>&1)"
SECOND_RC=$?
PTR_N2="$(LC_ALL=C grep -cF "$PTR_KEY" "$LAST_PLAN")" || PTR_N2=0
PTR_2="$(LC_ALL=C grep -F "$PTR_KEY" "$LAST_PLAN")"
HDR_N2="$(LC_ALL=C grep -cF 'archived sections' "$LAST_ARCH")" || HDR_N2=0
if [ "$FIRST_RC" -ne 0 ] || [ "$SECOND_RC" -ne 0 ]; then
  bad "pointer-refresh" "a two-step rotation was refused (first $FIRST_RC, second $SECOND_RC): $SECOND_OUT"
elif ! has "RETRO-SEVEN-SENTINEL" "$(cat "$LAST_ARCH")"; then
  bad "pointer-refresh" "the second rotation moved nothing — the arm would pass on a no-op"
elif [ "$PTR_N2" -ne 1 ]; then
  bad "pointer-refresh" "a second rotation left $PTR_N2 pointer lines; a stale range beside a fresh one is worse than none"
elif [ "$PTR_1" = "$PTR_2" ]; then
  bad "pointer-refresh" "the pointer names the same range after a second rotation moved a further span — it was not refreshed"
elif [ "$HDR_N2" -ne 1 ]; then
  bad "pointer-refresh" "a second rotation wrote $HDR_N2 archive headers into one archive file"
else
  ok "pointer-refresh" "a second rotation appends to the one archive, refreshes the single pointer, and its range moves"
fi

# =============================================================================================
# THE ROTATED PLAN MUST STILL READ AS **LIVE** TO `validate-plan-shape.sh`.
#
# THE DEFECT THIS ARM EXISTS FOR, AND THE FIRST CUT OF THIS FIXTURE COULD NOT HAVE CAUGHT IT.
# The rotator's pointer opened `**Spent sections are archived at`, and
# `validate-plan-shape.sh:165` is `DISCHARGE_BANNER='DISCHARGED|SPENT|DO NOT EXECUTE|SUPERSEDED'`,
# read case-INSENSITIVELY over `head -12` by six sites. The pointer lands at line 3. So every
# rotation wrote a discharge token into its own output, and the rotated plan read as SPENT --
# silencing P9, P10, P11, P12 and P13 on the very file the rotation was performed to keep
# healthy. THE GATE WENT GREEN BECAUSE FIVE ARMS STOPPED RUNNING, which is the exact shape of
# `plan-shape.md`'s eleven-byte opt-out except that the TOOL wrote it automatically.
#
# Measured on the real plan with one discriminating mutant, P10's resume one-liner repointed at
# an ancestor, the two pointers five bytes apart:
#
#     pointer "Spent ..."     P10 hits 0, rc=0   <- arm SILENCED
#     pointer "Archived ..."  P10 hits 1, rc=1   <- arm FIRES
#
# Control, same invocation: the pre-rotation head window carries 0 banner hits while the same
# grammar over the whole file returns 39 -- so that zero is a real absence and not a broken
# search.
#
# WHY THIS ARM DRIVES THE VALIDATOR RATHER THAN GREPPING THE HEAD WINDOW. "Line 3 holds no
# discharge token" tests a STRING; what was actually lost is a CONSEQUENCE -- five arms that
# stopped running. A head-window grep also goes vacuous the moment the banner vocabulary gains a
# word, and it would pass against a validator whose window moved. So the assertion is that a
# liveness-scoped arm, driven for real against the rotated output, CAN STILL FIRE.
#
# BOTH DIRECTIONS, ONE PROPERTY APART. The seeded offender is a rotated plan whose resume line
# names an ancestor: P10 must fire. The near-miss is the same rotated plan with its own resume
# line intact: P10 must stay silent. Without the near-miss an arm that flagged every plan would
# pass the offender direction identically.
# =============================================================================================
VPS="$REPO_ROOT/scripts/validate-plan-shape.sh"
if [ ! -f "$VPS" ]; then
  broken "cannot locate validate-plan-shape.sh at $VPS -- this arm's whole claim is about what that validator does with the rotated output, and a run that cannot invoke it would score green on every absence below"
fi

# Build a root, rotate for real, then drive the validator over the RESULT.
LV="$(mkroot liveness)" || broken "could not build the liveness sandbox root"
mkdir -p "$LV/scripts" || broken "could not create $LV/scripts"
cp "$VPS" "$LV/scripts/validate-plan-shape.sh" || broken "could not copy the validator into the sandbox"
drive "$LV" "$WORK/seeds/base.md" probe --ceiling "$CEIL" --apply
[ "$LAST_RC" -eq 0 ] || broken "the liveness root's rotation was refused (exit $LAST_RC); there is no rotated output to check: $LAST_OUT"
[ -f "$LAST_ARCH" ] || broken "the liveness root's rotation wrote no archive, so the pointer this arm is about was never written"
ROTATED="$LAST_PLAN"

# P10's OWN sentence, not `rc`. The rotated probe seed trips other arms of the validator for
# reasons that have nothing to do with this claim -- it is a minimal plan, not a conforming one --
# so an rc-keyed assertion would read those as evidence about P10. Anchored on the emitted text.
P10_SAYS='does not carry its own resume one-liner'
p10_hits() { # p10_hits <root> -> prints the number of P10 findings over the default corpus
  local n out
  out="$( cd "$1" && bash scripts/validate-plan-shape.sh 2>&1 )"
  n="$(LC_ALL=C grep -cF -- "$P10_SAYS" <<<"$out")" || n=0
  printf '%s' "$n"
}

# THE CORPUS IS DEPTH-1, SO THE ARCHIVE IS STRUCTURALLY OUTSIDE IT, AND THAT IS ASSERTED RATHER
# THAN ASSUMED. `validate-plan-shape.sh:52` is `find docs/plans -maxdepth 1`. The archive file
# DELIBERATELY keeps `Spent sections rotated out of ...` in its own header -- it genuinely is a
# spent record -- so an arm written carelessly would flag it, and a validator whose corpus ever
# went recursive would start reading a discharge banner off a file that is allowed to carry one.
EXAMINED="$( cd "$LV" && bash scripts/validate-plan-shape.sh 2>&1 | LC_ALL=C sed -n 's/^validate-plan-shape: \([0-9][0-9]*\) plan(s) checked.*/\1/p' )"
ARCH_SPENT="$(LC_ALL=C grep -ciE 'DISCHARGED|SPENT|DO NOT EXECUTE|SUPERSEDED' "$LAST_ARCH")" || ARCH_SPENT=0
if [ "$EXAMINED" = "1" ] && [ "$ARCH_SPENT" -gt 0 ]; then
  ok "archive-outside-corpus" "the validator examined 1 plan, not 2, while the archive carries $ARCH_SPENT discharge token(s) of its own — a spent record is allowed to say so, and the depth-1 corpus is why"
else
  bad "archive-outside-corpus" "expected 1 examined plan beside an archive carrying a discharge token; got examined='$EXAMINED' archive-tokens=$ARCH_SPENT"
fi

# THE SEED ITSELF MUST NOT CARRY A BANNER TOKEN, AND THIS IS A MEASURED DEFECT IN THIS ARM'S
# FIRST CUT RATHER THAN A PRECAUTION. The declaration block read "Everything else in the file is
# SPENT and may be rotated out" -- ordinary prose, and it landed at line 11, INSIDE the validator's
# `head -12` window. So the seed pre-silenced P9..P13 before any rotation happened: P10 read 0
# hits in BOTH directions, the offender arm failed, and the kill arm below scored a `0 -> 0`
# transition as a kill. The arm was dead and reported a result anyway.
#
# So the precondition is asserted on the SEED, in this run, with a control in the same
# invocation: the head window must hold zero banner tokens while the same grammar over the whole
# seed returns non-zero, which is what says the grammar can see this file at all.
SEED_HEAD_TOK="$(head -12 "$WORK/seeds/base.md" | LC_ALL=C grep -ciE 'DISCHARGED|SPENT|DO NOT EXECUTE|SUPERSEDED')" || SEED_HEAD_TOK=0
SEED_ALL_TOK="$(LC_ALL=C grep -ciE 'DISCHARGED|SPENT|DO NOT EXECUTE|SUPERSEDED' "$WORK/seeds/base.md")" || SEED_ALL_TOK=0
if [ "$SEED_HEAD_TOK" -eq 0 ] && [ "$SEED_ALL_TOK" -gt 0 ]; then
  ok "seed-is-live" "the seed's head -12 window carries no discharge token, against a control of $SEED_ALL_TOK over the whole seed — so the zero is a real absence and the liveness arms below have a subject"
else
  broken "the conforming seed carries $SEED_HEAD_TOK discharge token(s) in its own head -12 window (whole seed: $SEED_ALL_TOK). The seed is ALREADY discharged, so P9..P13 never run on it and every liveness verdict below would be an absence with no subject. Reword the seed; the banner vocabulary is DISCHARGED|SPENT|DO NOT EXECUTE|SUPERSEDED, read case-insensitively."
fi

# THE NEAR-MISS DIRECTION: the rotated plan keeps its own resume line, so P10 has nothing to say.
NM_HITS="$(p10_hits "$LV")"

# THE OFFENDER DIRECTION: repoint the resume line at an ancestor. This is the discriminating
# mutant, and it is seeded on the property P10 actually keys on — the BASENAME the sentence
# names — rather than on the sentence's presence, which a bare deletion would test instead.
LC_ALL=C sed 's|docs/plans/probe\.md|docs/plans/SOME-ANCESTOR.md|' "$ROTATED" > "$WORK/rotated-offender.md"
if cmp -s "$WORK/rotated-offender.md" "$ROTATED"; then
  broken "the resume-line mutation matched nothing in the rotated plan, so the offender direction has no subject"
fi
cp "$WORK/rotated-offender.md" "$ROTATED"
OFF_HITS="$(p10_hits "$LV")"

if [ "$OFF_HITS" -ge 1 ] && [ "$NM_HITS" -eq 0 ]; then
  ok "rotated-plan-stays-live" "P10 FIRES on the rotated plan when its resume line names an ancestor ($OFF_HITS hit) and stays silent when it names itself — the rotation did not silence the liveness arms"
elif [ "$OFF_HITS" -eq 0 ]; then
  bad "rotated-plan-stays-live" "P10 is SILENT on a rotated plan whose resume line names an ancestor. The rotation wrote a DISCHARGE token into the validator's head -12 window, so P9/P10/P11/P12/P13 all stopped running on the file the rotation exists to keep healthy — a gate that goes green because five arms died. Check the pointer string for the discharge vocabulary."
else
  bad "rotated-plan-stays-live" "P10 fired on a rotated plan that names ITSELF ($NM_HITS hit(s)) — the arm flags everything and its offender verdict says nothing"
fi

# THE KILL, SEEDED IN THIS FIXTURE RATHER THAN LEFT TO THE SUBJECT. Re-seed the discharge-token
# pointer the rotator used to write, into the offender plan that has just been shown to FIRE. The
# only difference is the pointer's opening word. If P10 goes silent the arm above has been proven
# to discriminate on exactly this property; if it still fires, the arm's green verdict is not
# evidence about the pointer and this fixture would pass a regression.
#
# AND IT IS GATED ON THE OFFENDER HAVING FIRED, BECAUSE `0 -> 0` IS NOT A KILL. Measured on this
# arm's first cut: with the seed pre-silenced P10 read 0 before and 0 after, and the kill arm
# reported a kill on a transition that never happened. A kill is a CHANGE in the verdict, so the
# before-state has to be non-zero for the after-state to mean anything.
if [ "$OFF_HITS" -lt 1 ]; then
  bad "spent-pointer-kill" "not scored: P10 read $OFF_HITS on the offender, so there is no verdict for the re-seeded pointer to silence and a '0 -> 0' reading would be a kill that never happened"
elif LC_ALL=C sed 's|^\*\*Archived sections live at|**Spent sections are archived at|' "$ROTATED" > "$WORK/rotated-spent.md"; cmp -s "$WORK/rotated-spent.md" "$ROTATED"; then
  bad "spent-pointer-kill" "the re-seed matched nothing — the pointer no longer opens with the string this arm knows how to attack, so the kill was not scored and the arm above is unproven"
else
  SPENT_LINE="$(LC_ALL=C grep -n 'Spent sections are archived at' "$WORK/rotated-spent.md" | cut -d: -f1)"
  cp "$WORK/rotated-spent.md" "$ROTATED"
  SPENT_HITS="$(p10_hits "$LV")"
  # The head window is the DIAGNOSIS, printed beside the verdict; the verdict itself is the
  # consequence. Control in the same invocation: the whole file against the same grammar.
  HEAD_TOK="$(head -12 "$ROTATED" | LC_ALL=C grep -ciE 'DISCHARGED|SPENT|DO NOT EXECUTE|SUPERSEDED')" || HEAD_TOK=0
  ALL_TOK="$(LC_ALL=C grep -ciE 'DISCHARGED|SPENT|DO NOT EXECUTE|SUPERSEDED' "$ROTATED")" || ALL_TOK=0
  if [ "$SPENT_HITS" -eq 0 ] && [ "$HEAD_TOK" -gt 0 ]; then
    KILLS=$((KILLS + 1))
    ok "spent-pointer-kill" "rotated-plan-stays-live would FAIL: a pointer opening 'Spent' at line ${SPENT_LINE:-?} puts a discharge token in the head -12 window ($HEAD_TOK there, $ALL_TOK in the whole file) and P10 drops $OFF_HITS -> 0 on the identical plan"
  elif [ "$SPENT_HITS" -ne 0 ]; then
    bad "spent-pointer-kill" "the 'Spent' pointer did NOT silence P10 ($SPENT_HITS hit(s)); the live arm's verdict is therefore not evidence about the pointer's vocabulary, and this fixture would pass the regression it was written for"
  else
    bad "spent-pointer-kill" "P10 went silent with NO discharge token in the head window (head=$HEAD_TOK, whole file=$ALL_TOK) — it was silenced by something other than the banner, so the attribution is wrong"
  fi
fi
# The plan is left mutated on disk deliberately: this root is not driven again, and restoring it
# would invite a later arm to read a file whose provenance is two mutations deep.

# --- REPORT MODE WRITES NOTHING ---------------------------------------------------------------
# A report that says what would move and then moves it is the call nobody asked for.
RR="$(mkroot report)" || broken "could not build the report sandbox root"
drive "$RR" "$WORK/seeds/base.md" probe --ceiling "$CEIL"
if [ "$LAST_RC" -ne 0 ]; then
  bad "report-mode" "the bare report run was refused (exit $LAST_RC): $LAST_OUT"
elif [ "$LAST_UNTOUCHED" != yes ]; then
  bad "report-mode" "the bare report run rewrote the plan"
elif [ "$LAST_WROTE" = yes ]; then
  bad "report-mode" "the bare report run created an archive"
elif ! has "would move" "$LAST_OUT"; then
  bad "report-mode" "the bare report run wrote nothing and also said nothing: $LAST_OUT"
else
  ok "report-mode" "a bare run reports what would move and leaves both files untouched"
fi

# --- THE CEILING BOUNDARY DISCRIMINATES -------------------------------------------------------
# `at the ceiling` and `one byte over it` must land on DIFFERENT verdicts, asserted in the same
# arm. A threshold test that only ever drives one side of its own boundary reads as a working
# comparison under an off-by-one and under a counter that is simply wrong.
BASE_BYTES="$(wc -c < "$WORK/seeds/base.md" | tr -d ' ')"
drive "$RR" "$WORK/seeds/base.md" probe --ceiling "$BASE_BYTES"
AT_RC="$LAST_RC"; AT_OUT="$LAST_OUT"
drive "$RR" "$WORK/seeds/base.md" probe --ceiling "$((BASE_BYTES - 1))"
OVER_RC="$LAST_RC"; OVER_OUT="$LAST_OUT"
if has "$S_NOTHING" "$AT_OUT" && [ "$AT_RC" -eq 0 ] \
   && ! has "$S_NOTHING" "$OVER_OUT" && has "would move" "$OVER_OUT"; then
  ok "ceiling-boundary" "a plan AT the ceiling ($BASE_BYTES bytes) has nothing to move; one byte over it rotates"
else
  bad "ceiling-boundary" "the ceiling does not discriminate at its own boundary (at: rc=$AT_RC, over: rc=$OVER_RC)"
fi

# =============================================================================================
# THE FENCE GRADER, IN BOTH DIRECTIONS, ON THE PROPERTY THAT DISCRIMINATES.
# =============================================================================================
drive "$RR" "$WORK/seeds/para-info.md" probe --ceiling "$CEIL" --apply
PI_RC="$LAST_RC"; PI_OUT="$LAST_OUT"; PI_LIVE=""
[ -f "$LAST_PLAN" ] && PI_LIVE="$(cat "$LAST_PLAN")"
if [ "$PI_RC" -ne 0 ] || has "$S_UNTERM" "$PI_OUT"; then
  bad "info-string-paragraph" "a backtick run whose info string carries a delimiter was read as a FENCE (exit $PI_RC): $(head -3 <<<"$PI_OUT" | tr '\n' '|')"
elif ! has "LIVE-HAZARD-SENTINEL" "$PI_LIVE"; then
  bad "info-string-paragraph" "the plan rotated but the live section holding the paragraph did not survive"
else
  ok "info-string-paragraph" "a backtick run with a delimiter in its info string is a PARAGRAPH: the plan rotates"
fi

drive "$RR" "$WORK/seeds/real-opener.md" probe --ceiling "$CEIL" --apply
RO_RC="$LAST_RC"; RO_OUT="$LAST_OUT"
if [ "$RO_RC" -eq 0 ]; then
  bad "unterminated-fence" "a real opener that never closes was rotated at exit 0 — every boundary below it is a fenced line"
elif ! has "$S_UNTERM" "$RO_OUT"; then
  bad "unterminated-fence" "it refused, but not by the unterminated-fence finding: $RO_OUT"
elif [ "$LAST_WROTE" = yes ] || [ "$LAST_UNTOUCHED" != yes ]; then
  bad "unterminated-fence" "the refusal wrote to disk"
else
  ok "unterminated-fence" "the same line WITHOUT a delimiter in its info string is a real opener, and an unterminated one is refused"
fi

# A FENCE WHOLLY INSIDE ONE SECTION IS NOT A CUT. The quiet twin of the fence-cut refusal: the
# shipped grader sees the quoted heading as fenced, so it is not a boundary and nothing is cut.
drive "$RR" "$WORK/seeds/fenced-heading.md" probe --ceiling "$CEIL" --apply
FH_RC="$LAST_RC"; FH_OUT="$LAST_OUT"; FH_LIVE=""
[ -f "$LAST_PLAN" ] && FH_LIVE="$(cat "$LAST_PLAN")"
if [ "$FH_RC" -ne 0 ]; then
  bad "fenced-heading-quiet" "a fence quoting a heading inside a live section was refused (exit $FH_RC): $(head -3 <<<"$FH_OUT" | tr '\n' '|')"
elif ! has "QUOTED-HEADING-INSIDE-A-FENCE" "$FH_LIVE"; then
  bad "fenced-heading-quiet" "the quoted heading was treated as a section boundary and its text left the live half"
else
  ok "fenced-heading-quiet" "a heading quoted inside a fence is not a boundary, and the live section keeps it"
fi

# =============================================================================================
# THE REFUSALS, EACH WITH ITS OWN SENTENCE AND EACH WRITING NOTHING.
# =============================================================================================
expect_refusal() { # expect_refusal <arm> <seed> <sentence> [args...]
  local arm="$1" sf="$2" sent="$3"; shift 3
  drive "$RR" "$sf" probe "$@"
  if [ "$LAST_RC" -eq 0 ]; then
    bad "$arm" "exited 0 on a plan it cannot partition safely: $(head -2 <<<"$LAST_OUT" | tr '\n' '|')"
  elif ! has "$sent" "$LAST_OUT"; then
    bad "$arm" "refused (exit $LAST_RC) but not by its own finding — the operator is handed the wrong remedy: $(head -4 <<<"$LAST_OUT" | tr '\n' '|')"
  elif [ "$LAST_WROTE" = yes ] || [ "$LAST_UNTOUCHED" != yes ]; then
    bad "$arm" "the refusal wrote to disk"
  else
    ok "$arm" "refused by its own finding at exit $LAST_RC, and wrote nothing"
  fi
}
expect_refusal "refuse-nonamed"    "$WORK/seeds/nonamed.md"    "$S_NONAMED" --ceiling "$CEIL" --apply
expect_refusal "refuse-nodecl"     "$WORK/seeds/nodecl.md"     "$S_NODECL"  --ceiling 200 --apply
expect_refusal "refuse-noheadings" "$WORK/seeds/noheadings.md" "$S_NOHEAD"  --ceiling 200 --apply
expect_refusal "refuse-unreachable" "$WORK/seeds/base.md"      "$S_UNREACH" --ceiling 1 --apply

# --- OVER THE CEILING WITH NO CANDIDATE OF ANY CLASS IS A REFUSAL, NOT THE UNDER-CEILING LINE ---
# The subject used to print "at or under the ceiling -- nothing to move" at exit 0 about a plan
# OVER the ceiling it was given, because its nothing-moved branch ran first. The arm demands the
# no-candidate sentence, exit 2, NEITHER under-ceiling phrase, the plan byte-identical and no
# archive. Its quiet twin is the same seed at its own exact size, which must still exit 0 with
# "nothing to move" -- a subject that refused every no-candidate plan would pass the first half.
NC_BYTES="$(wc -c < "$WORK/seeds/nocand.md" | tr -d ' ')"
drive "$RR" "$WORK/seeds/nocand.md" probe --ceiling "$((NC_BYTES / 2))" --apply
if [ "$LAST_RC" -ne 2 ]; then
  bad "no-candidates-refuses" "an over-ceiling plan with no archivable span exited $LAST_RC, not 2: $(head -2 <<<"$LAST_OUT" | tr '\n' '|')"
elif ! has "$S_NOCAND" "$LAST_OUT"; then
  bad "no-candidates-refuses" "refused, but not by the no-candidate finding: $(head -3 <<<"$LAST_OUT" | tr '\n' '|')"
elif has "$S_NOTHING" "$LAST_OUT" || has "at or under" "$LAST_OUT"; then
  bad "no-candidates-refuses" "the refusal also carries the UNDER-ceiling phrasing, so a caller keyed on it reads success"
elif [ "$LAST_WROTE" = yes ] || [ "$LAST_UNTOUCHED" != yes ]; then
  bad "no-candidates-refuses" "the refusal wrote to disk (archive=$LAST_WROTE, plan untouched=$LAST_UNTOUCHED)"
else
  ok "no-candidates-refuses" "over the ceiling with no span of any class: exit 2, its own sentence, plan byte-identical, no archive"
fi
drive "$RR" "$WORK/seeds/nocand.md" probe --ceiling "$NC_BYTES" --apply
if [ "$LAST_RC" -eq 0 ] && has "$S_NOTHING" "$LAST_OUT" && ! has "$S_NOCAND" "$LAST_OUT" && [ "$LAST_UNTOUCHED" = yes ]; then
  ok "no-candidates-quiet" "the same seed at its exact size ($NC_BYTES) exits 0 with nothing to move and is not refused"
else
  bad "no-candidates-quiet" "the same seed AT its own size did not exit 0 with nothing to move (exit $LAST_RC): $(head -2 <<<"$LAST_OUT" | tr '\n' '|')"
fi

# =============================================================================================
# THE BATCH-RECORD CLASS. Every figure the arms below compare against is derived HERE, from the
# seed's own bytes, by a reader that shares no code with the subject: record sizes by column-zero
# opener (the fixture knows where it planted its fences, so a plain toggle is exact for this
# seed), the spent section's size, and the lines each would carry into the archive.
#
# `batch_derive <NMAX> <out>` prints `total section size101 .. size140` and writes to <out> the
# lines of the spent section plus every record numbered NMAX or below -- the multiset the archive
# must grow by when those are what moved.
# =============================================================================================
batch_derive() {
  LC_ALL=C awk -v NMAX="$1" -v OUT="$2" '
    /^```/ { fence = !fence }
    { b = length($0) + 1; total += b }
    /^## SPENT BATCH-SEED$/ { cur = "C1" }
    /^### NEXT ACTIONS$/ { cur = "" }
    !fence && /^\*\*BATCH [0-9]+/ { s = $0; sub(/^\*\*BATCH /, "", s); cur = s + 0 }
    cur != "" {
      size[cur] += b
      if (cur == "C1" || cur + 0 <= NMAX + 0) print > OUT
    }
    END { printf "%d %d", total, size["C1"]; for (r = 101; r <= 140; r++) printf " %d", size[r]; printf "\n" }
  ' "$WORK/seeds/batch.md"
}
read -r B_TOTAL B_S1 B_SIZES <<<"$(batch_derive 0 /dev/null)"
B_K=5
B_R="$((B_TOTAL - B_S1))"; B_RK=""; B_R39=""; B_PREV=0; B_J=0; B_MIN=""
for _s in $B_SIZES; do
  B_J=$((B_J + 1))
  [ "$_s" -gt "$B_PREV" ] || broken "the batch seed's record sizes do not rise strictly with the record number (record $((100 + B_J)) is $_s after $B_PREV) -- an oldest-first and a newest-first selection would not pick different records"
  B_PREV="$_s"; [ -n "$B_MIN" ] || B_MIN="$_s"
  B_R=$((B_R - _s))
  [ "$B_J" -eq "$B_K" ] && B_RK="$B_R"
  [ "$B_J" -eq 39 ] && B_R39="$B_R"
done
[ "$B_J" -eq 40 ] || broken "the batch seed derived $B_J records, not 40"
S140="$_s"

# THE NEAR-MISS, WHICH IS ALSO THE POINTER CALIBRATION. One byte under the seed the spent section
# alone reaches the ceiling, so phase 1 takes it and phase 2 -- class 3 -- must never run: no record
# may move. The file it writes, less the seed without that section, is the pointer cost P.
BNR="$(mkroot batch-nearmiss)" || broken "could not build the batch near-miss sandbox root"
drive "$BNR" "$WORK/seeds/batch.md" probe --ceiling "$((B_TOTAL - 1))" --apply
BN_ARCH="$(cat "$LAST_ARCH" 2>/dev/null)"
if [ "$LAST_RC" -ne 0 ]; then
  bad "batch-nearmiss" "the batch seed one byte over the ceiling was refused (exit $LAST_RC): $(head -3 <<<"$LAST_OUT" | tr '\n' '|')"
elif has "REC-" "$BN_ARCH" || ! has "SPENT-BATCH-SENTINEL" "$BN_ARCH"; then
  bad "batch-nearmiss" "at a ceiling the spent section alone reaches, class 3 moved anyway, or the spent section did not: $(LC_ALL=C grep -o 'REC-[0-9]*-OPEN' <<<"$BN_ARCH" | tr '\n' ' ')"
else
  ok "batch-nearmiss" "at a ceiling the spent section alone reaches, only it moves and no batch record does"
fi
B_P=$(( $(wc -c < "$LAST_PLAN" | tr -d ' ') - (B_TOTAL - B_S1) ))
[ "$B_P" -gt 0 ] && [ "$B_MIN" -gt $((4 * B_P)) ] \
  || broken "the batch seed's smallest record ($B_MIN) is not much larger than the pointer ($B_P), so C = R_k + P/2 does not pin how many records move"

# C = R_k + floor(P/2). After k records the file would be R_k + P, over C, so a rotation that
# budgets its pointer takes one more; one that does not stops at k and writes over C. The count
# that must move is derived by the same walk rather than typed as k+1.
B_CEIL=$((B_RK + B_P / 2))
B_R="$((B_TOTAL - B_S1))"; B_NMOVE=0
for _s in $B_SIZES; do
  [ $((B_R + B_P)) -le "$B_CEIL" ] && break
  B_R=$((B_R - _s)); B_NMOVE=$((B_NMOVE + 1))
done
B_NMAX=$((100 + B_NMOVE))
batch_derive "$B_NMAX" "$WORK/batch-expected.raw" > /dev/null
LC_ALL=C sort "$WORK/batch-expected.raw" > "$WORK/batch-expected.sorted"
# The floor: every eligible record gone and the pointer written still leaves the file over it,
# by half of record 140 -- so only a rotation that takes the protected record can reach it.
B_FLOOR=$((B_R39 + B_P - S140 / 2))

ARCH_PREFIX="PRE-EXISTING-ARCHIVE-SENTINEL. A record already in the archive before this rotation."
ARCH_PREFIX_B=$(( ${#ARCH_PREFIX} + 1 ))

# `batch_run <root-name> <script> <ceiling>` rotates the batch seed in a FRESH root over an archive
# that already holds one line, so what the rotation appended is exactly the bytes after it.
batch_run() {
  local r
  r="$(mkroot "$1" "$2")" || broken "could not build the $1 sandbox root"
  B_PLAN="$r/docs/plans/probe.md"; B_ARCH="$r/docs/plans/archive/probe.md"
  mkdir -p "$r/docs/plans/archive" || broken "could not create $r/docs/plans/archive"
  cp "$WORK/seeds/batch.md" "$B_PLAN" || broken "could not seed $B_PLAN"
  printf '%s\n' "$ARCH_PREFIX" > "$B_ARCH"
  B_OUT="$(bash "$r/scripts/plan-rotate.sh" "$B_PLAN" --ceiling "$3" --apply 2>&1)"
  B_RC=$?
  B_LIVE="$(cat "$B_PLAN")"
  tail -c +"$((ARCH_PREFIX_B + 1))" "$B_ARCH" > "$r/growth.md"
  B_GROWTH="$(cat "$r/growth.md")"
  B_GROWTH_F="$r/growth.md"
  B_UNTOUCHED=yes; cmp -s "$B_PLAN" "$WORK/seeds/batch.md" || B_UNTOUCHED=no
  B_ARCH_SAME=yes; [ "$(cat "$B_ARCH")" = "$ARCH_PREFIX" ] || B_ARCH_SAME=no
}

# `batch_verdict` names the FIRST property of a correct class-3 rotation that the last
# `batch_run` broke, or prints `ok`. Every property is read off the files on disk.
batch_verdict() {
  local sz nr maxm mink ptrn ranges
  if [ "$B_RC" -ne 0 ]; then echo "refused: $(head -2 <<<"$B_OUT" | tr '\n' '|')"; return; fi
  sz="$(wc -c < "$B_PLAN" | tr -d ' ')"
  [ "$sz" -le "$B_CEIL" ] || { echo "final size $sz is over the ceiling $B_CEIL"; return; }
  has "REC-140-OPEN" "$B_LIVE" && has "FENCED-999-SENTINEL" "$B_LIVE" \
    || { echo "record 140 or its fenced 999 line left the live half"; return; }
  has "REC-101-OPEN" "$B_GROWTH" && ! has "REC-101-OPEN" "$B_LIVE" \
    || { echo "record 101, the oldest, was not archived"; return; }
  maxm="$(LC_ALL=C grep -o 'REC-[0-9]*-OPEN' "$B_GROWTH_F" | LC_ALL=C awk -F- '$2 > m { m = $2 } END { print m + 0 }')"
  mink="$(LC_ALL=C grep -o 'REC-[0-9]*-OPEN' "$B_PLAN" | LC_ALL=C awk -F- 'm == "" || $2 < m { m = $2 } END { print m + 0 }')"
  [ "$maxm" -lt "$mink" ] || { echo "moved record $maxm is not older than kept record $mink"; return; }
  ptrn="$(LC_ALL=C grep -cF "$PTR_KEY" "$B_PLAN")" || ptrn=0
  [ "$ptrn" -eq 1 ] || { echo "$ptrn pointer lines, not 1"; return; }
  ranges="$(LC_ALL=C grep -F "$PTR_KEY" "$B_PLAN" | LC_ALL=C sed -n 's/.*original lines \(.*\)\. It is a RECORD.*/\1/p')"
  nr="$(LC_ALL=C awk '{ print gsub(/\.\./, "") }' <<<"$ranges")"
  [ "${nr:-0}" -eq 1 ] || { echo "the pointer names ${nr:-0} ranges ($ranges), not one coalesced range"; return; }
  for _t in BSTART-SENTINEL BNEXT-SENTINEL RESUME-HEADER-SENTINEL '### NEXT ACTIONS' '## Start here'; do
    has "$_t" "$B_LIVE" || { echo "live text lost: $_t"; return; }
  done
  LC_ALL=C sort "$B_GROWTH_F" > "$B_GROWTH_F.sorted"
  cmp -s "$B_GROWTH_F.sorted" "$WORK/batch-expected.sorted" \
    || { echo "the archive grew by something other than the spent section plus records 101..$B_NMAX"; return; }
  echo ok
}

# --- BATCH-RECORDS: THE CLASS-3 ROTATION, AT C = R_k + floor(P/2) ------------------------------
batch_run batch-records "$SUBJ" "$B_CEIL"
BV="$(batch_verdict)"
if [ "$BV" = ok ] && has "$S_ARM4OK" "$B_OUT"; then
  ok "batch-records" "at $B_CEIL (R_$B_K=$B_RK + P/2, P=$B_P) records 101..$B_NMAX move oldest-first as one range beside the spent section; 140 and its fenced 999 stay live; the archive grew by exactly those lines"
else
  bad "batch-records" "$BV$(has "$S_ARM4OK" "$B_OUT" || echo " (and no arm 4 PASS)")"
fi

# --- BATCH-PROTECTED-FLOOR: THE PROTECTED RECORD IS WHAT STANDS BETWEEN THE PLAN AND THE CEILING --
# Every eligible record taken still leaves the file over this ceiling by half of record 140, so
# the only way under is to archive the current record. The shipped subject refuses as UNREACHABLE
# and writes nothing; a subject that lost its protection takes 140 and arm 4 catches it. Without
# this arm the protection is never exercised, because an oldest-first selection reaches 140 last.
batch_run batch-floor "$SUBJ" "$B_FLOOR"
if [ "$B_RC" -eq 2 ] && has "$S_UNREACH" "$B_OUT" && ! has "$S_ARM4" "$B_OUT" \
   && [ "$B_UNTOUCHED" = yes ] && [ "$B_ARCH_SAME" = yes ]; then
  ok "batch-protected-floor" "at $B_FLOOR only archiving record 140 would reach the ceiling; the rotation refuses as unreachable and writes nothing"
else
  bad "batch-protected-floor" "expected an UNREACHABLE refusal writing nothing (exit $B_RC, plan untouched=$B_UNTOUCHED, archive unchanged=$B_ARCH_SAME): $(head -2 <<<"$B_OUT" | tr '\n' '|')"
fi

# THE QUIET TWIN OF EVERY SHAPE REFUSAL, AND IT IS THE ARM THAT KEEPS THEM USABLE. A plan under
# the ceiling has no rotation to perform, so nothing about its shape needs to be decidable —
# asking is the defect. Measured by the subject's author over the real corpus: the first cut
# parsed every input and refused 37 of 39 correct plans. A lint that errors on 95% of its corpus
# is one the operator switches off, which is worse than none.
quiet_under_ceiling() { # quiet_under_ceiling <arm> <seed>
  local arm="$1" sf="$2" b
  b="$(wc -c < "$sf" | tr -d ' ')"
  drive "$RR" "$sf" probe --ceiling "$((b + 1))" --apply
  if [ "$LAST_RC" -ne 0 ]; then
    bad "$arm" "a plan UNDER the ceiling was refused for its shape (exit $LAST_RC): $(head -2 <<<"$LAST_OUT" | tr '\n' '|')"
  elif ! has "$S_NOTHING" "$LAST_OUT"; then
    bad "$arm" "a plan under the ceiling exited 0 without saying it had nothing to move: $LAST_OUT"
  elif [ "$LAST_UNTOUCHED" != yes ]; then
    bad "$arm" "a plan under the ceiling was rewritten"
  else
    ok "$arm" "under the ceiling it is not asked about its shape, and nothing is written"
  fi
}
quiet_under_ceiling "quiet-nonamed"    "$WORK/seeds/nonamed.md"
quiet_under_ceiling "quiet-nodecl"     "$WORK/seeds/nodecl.md"
quiet_under_ceiling "quiet-noheadings" "$WORK/seeds/noheadings.md"
quiet_under_ceiling "quiet-real-opener" "$WORK/seeds/real-opener.md"

# =============================================================================================
# CWD-INVARIANCE, ASSERTED IN THIS FIXTURE'S OWN ARMS.
# A fixture that is green only from the repo root may be asserting nothing, because that is a cwd
# where its sandbox does not exist. The subject resolves its root by walking up from its own
# path, so its answer must not move with the caller's directory — and that is a claim to CHECK,
# not one to inherit from how the suite happens to dispatch this file.
# =============================================================================================
CW="$(mkroot cwd)" || broken "could not build the cwd sandbox root"
cp "$WORK/seeds/base.md" "$CW/docs/plans/probe.md"
CWD_A="$( cd "$REPO_ROOT" && bash "$CW/scripts/plan-rotate.sh" "$CW/docs/plans/probe.md" --ceiling "$CEIL" 2>&1 )"
CWD_A_RC=$?
CWD_B="$( cd / && bash "$CW/scripts/plan-rotate.sh" "$CW/docs/plans/probe.md" --ceiling "$CEIL" 2>&1 )"
CWD_B_RC=$?
CWD_C="$( cd "$CW/docs/plans" && bash "$CW/scripts/plan-rotate.sh" "$CW/docs/plans/probe.md" --ceiling "$CEIL" 2>&1 )"
CWD_C_RC=$?
if [ "$CWD_A_RC" -ne 0 ]; then
  bad "cwd-invariance" "the subject failed from the repo root (exit $CWD_A_RC): $CWD_A"
elif [ "$CWD_A" = "$CWD_B" ] && [ "$CWD_A" = "$CWD_C" ] && [ "$CWD_B_RC" -eq 0 ] && [ "$CWD_C_RC" -eq 0 ]; then
  ok "cwd-invariance" "identical report and exit 0 from the repo root, from /, and from the plan's own directory"
else
  bad "cwd-invariance" "the answer moved with the caller's directory (rc $CWD_A_RC/$CWD_B_RC/$CWD_C_RC)"
fi

# A MISSING SUBJECT IS NOT A PASS, ASSERTED BY RE-INVOKING THIS FILE. The control is that the
# process running right now located its own subject and is executing these arms; the probe is
# that a named path with no file behind it exits 2 rather than falling back to the tree's copy
# and scoring the ORIGINAL on every mutant arm.
( bash "$HERE/run.sh" "$WORK/no-such-plan-rotate.sh" >/dev/null 2>&1 )
MISS_RC=$?
if [ "$MISS_RC" -eq 2 ]; then
  ok "missing-subject" "an argument naming no file exits 2, and does not silently fall back to the tree's own copy"
else
  bad "missing-subject" "a named-but-absent subject exited $MISS_RC; a mutation run would score the unmutated script"
fi

# =============================================================================================
# MUTANTS. Every arm above is shaped as "the subject refused" or "the subject stayed quiet", and
# BOTH shapes pass against a subject that emits nothing. Each mutant below is a COPY, never an
# in-place edit, guarded by `cmp -s` so a sed that matched nothing cannot score a kill.
#
# The mutants live in sandbox ROOTS with their own synthetic VERSION marker, because the subject
# walks up from its own path to find one — a bare copy in a temp directory exits 2 having parsed
# nothing, which reads exactly like a guard firing. The unmutated `control` root below is what
# separates those two outcomes.
# =============================================================================================
mutant_root() { # mutant_root <name> <sed-args...> -> echoes the root path, empty on failure
  local n="$1"; shift
  local r="$WORK/roots/$n"
  # EVERY ATTEMPT IS RECORDED IN A FILE, BECAUSE THIS RUNS INSIDE `$( )` and a counter would die
  # with the subshell. The tally below compares attempts against built roots and against kills.
  printf '%s\n' "$n" >> "$WORK/mutants.tried"
  mkdir -p "$r/scripts" "$r/docs/plans" || return 1
  printf '0.0.0-fixture-sandbox\n' > "$r/VERSION"
  LC_ALL=C sed "$@" "$SUBJ" > "$r/scripts/plan-rotate.sh" || {
    echo "mutant $n: sed DID NOT APPLY (it exited non-zero, so no mutant exists to score)" >&2
    return 1
  }
  if cmp -s "$r/scripts/plan-rotate.sh" "$SUBJ"; then
    echo "mutant $n: the sed matched nothing, so this copy IS the original" >&2
    return 1
  fi
  : > "$r/.mutant-built"
  printf '%s' "$r"
}
killed() { KILLS=$((KILLS + 1)); ok "$1" "$2"; }

# THE BATCH-RECORD MUTANTS USE A FIXED-STRING REPLACEMENT WITH AN ASSERTED APPLY COUNT. `sed`
# needs every `[`, `*`, `&` and `|` in the subject's awk escaped, and a mis-escaped pattern either
# matches nothing -- which `cmp -s` catches -- or matches a SECOND line, which it does not. So the
# anchor is a literal substring passed by ENVIRON (no escaping layer at all), the replacement is
# spliced in by `index`, and the copy is refused unless EXACTLY ONE line carried the anchor.
mutant_fixed() { # mutant_fixed <name> <literal-anchor> <literal-replacement> -> root path, empty on failure
  local n="$1" r="$WORK/roots/$1" hits
  printf '%s\n' "$n" >> "$WORK/mutants.tried"
  mkdir -p "$r/scripts" "$r/docs/plans" || return 1
  printf '0.0.0-fixture-sandbox\n' > "$r/VERSION"
  hits="$(M_OLD="$2" M_NEW="$3" LC_ALL=C awk -v OUT="$r/scripts/plan-rotate.sh" '
    BEGIN { o = ENVIRON["M_OLD"]; w = ENVIRON["M_NEW"] }
    { i = index($0, o)
      if (i > 0) { h++; $0 = substr($0, 1, i - 1) w substr($0, i + length(o)) }
      print > OUT }
    END { print h + 0 }' "$SUBJ")" || { echo "mutant $n: awk DID NOT APPLY" >&2; return 1; }
  if [ "$hits" -ne 1 ]; then
    echo "mutant $n: the anchor matched $hits lines, not exactly 1" >&2
    return 1
  fi
  if cmp -s "$r/scripts/plan-rotate.sh" "$SUBJ"; then
    echo "mutant $n: the replacement changed nothing, so this copy IS the original" >&2
    return 1
  fi
  : > "$r/.mutant-built"
  printf '%s' "$r"
}

# CONTROL, UNMUTATED, FIRST — AND WITH A POSITIVE CONJUNCT. A control asserting only rc=0 and no
# complaint passes against a subject replaced by `exit 0`, because rc=0 with nothing reported is
# exactly what a clean copy looks like. So it also demands a baseline row be THERE.
CTRL="$(mkroot control)" || broken "could not build the control sandbox root"
drive "$CTRL" "$WORK/seeds/base.md" probe --ceiling "$CEIL" --apply
if [ "$LAST_RC" -eq 0 ] && has "$S_ARM3OK" "$LAST_OUT" && has "SPENT-ONE-SENTINEL" "$(cat "$LAST_ARCH" 2>/dev/null)"; then
  ok "mutant-control" "the unmutated copy in a sandbox root rotates, reports arm 3 PASS, and writes the archive"
else
  broken "the UNMUTATED copy in a sandbox root did not behave like the real script (exit $LAST_RC). Every kill below would be scored against a broken harness: $LAST_OUT"
fi

# --- M1 — THE LIVE-SET JOIN DELETED ----------------------------------------------------------
# Every section below the declaration block becomes spent, so one maximal run swallows the whole
# plan's live work. Targets arm 3's DERIVATION CROSS-CHECK: the splitter's `livesec` rows shrink
# while the acceptance test's independent re-derivation does not, and the two disagree.
M1="$(mutant_root m1-live-join-deleted -e 's/islive\[i\] = (i <= di) || (t in named)/islive[i] = (i <= di)/')"
if [ -z "$M1" ]; then
  bad "mutant:m1" "the mutation did not apply — the live-set join has moved, so this mutant tests nothing"
else
  drive "$M1" "$WORK/seeds/base.md" probe --ceiling "$CEIL" --apply
  if [ "$LAST_RC" -ne 0 ] && has "$S_ARM3X" "$LAST_OUT" && [ "$LAST_WROTE" = no ]; then
    killed "mutant:m1" "the cross-check would FAIL: the two derivations of the live set disagree, and nothing was written"
  else
    bad "mutant:m1" "the live-set join was deleted and arm 3's cross-check stayed silent (exit $LAST_RC): $(head -3 <<<"$LAST_OUT" | tr '\n' '|')"
  fi
fi

# --- M1T — THE ARM-3 TAUTOLOGY, PUT BACK, ON TOP OF M1 ---------------------------------------
# THE SHAPE THAT PASSED EVERYTHING BEFORE IT WAS CAUGHT. WANT is taken from the splitter's own
# `livesec` rows, so WANT and GOT become two readings of ONE decision and arm 3 cannot fail. The
# subject then APPLIES at rc=0 having archived the plan's read/write boundary and its next
# actions, and reports three green arms while doing it.
#
# NOTHING THE SUBJECT PRINTS CAN CATCH THIS, which is the point: the kill is scored by the
# hand-typed sentinel list against the files on disk.
M1T="$(mutant_root m1t-arm3-tautology \
  -e 's/islive\[i\] = (i <= di) || (t in named)/islive[i] = (i <= di)/' \
  -e 's/^if \[ "\$WANT" != "\$SPLITTER_WANT" \]; then$/WANT="$SPLITTER_WANT"; if false; then/')"
if [ -z "$M1T" ]; then
  bad "mutant:m1t" "the tautology mutation did not apply — arm 3's cross-check has moved"
else
  T_APPLIED=0
  grep -qF 'WANT="$SPLITTER_WANT"; if false; then' "$M1T/scripts/plan-rotate.sh" && T_APPLIED=1
  if [ "$T_APPLIED" -ne 1 ]; then
    bad "mutant:m1t" "the second layer did not land; a one-layer revert proves the layer left in place"
  else
    drive "$M1T" "$WORK/seeds/base.md" probe --ceiling "$CEIL" --apply
    T_RC="$LAST_RC"; T_OUT="$LAST_OUT"
    T_LIVE=""; [ -f "$LAST_PLAN" ] && T_LIVE="$(cat "$LAST_PLAN")"
    # THE KILL IS THE SENTINEL, AND THE REPORT IS THE EVIDENCE THAT THE REPORT IS WORTHLESS: the
    # mutant must exit 0 AND claim arm 3 PASS while the live half has lost its named sections.
    if [ "$T_RC" -eq 0 ] && has "$S_ARM3OK" "$T_OUT" \
       && ! has "LIVE-HAZARD-SENTINEL" "$T_LIVE" && ! has "LIVE-NEXTACTION-SENTINEL" "$T_LIVE"; then
      killed "mutant:m1t" "live-set would FAIL: exit 0 and 'arm 3 ... PASS' while the archive ate the named-live sections — only the on-disk sentinel arm sees it"
    else
      bad "mutant:m1t" "the tautology did not reproduce: exit $T_RC, arm3-pass=$(has "$S_ARM3OK" "$T_OUT" && echo yes || echo no), hazard-live=$(has "LIVE-HAZARD-SENTINEL" "$T_LIVE" && echo yes || echo no)"
    fi
  fi
fi

# --- M1T-TWIN — THE TAUTOLOGY ALONE, WITH THE JOIN INTACT ------------------------------------
# The other half of the proof, and the reason the defect shipped unnoticed: with the join intact
# the tautology changes NO verdict today. A twin that fired here would mean m1t's kill was
# attributable to the join deletion alone and said nothing about the tautology.
M1W="$(mutant_root m1w-tautology-only \
  -e 's/^if \[ "\$WANT" != "\$SPLITTER_WANT" \]; then$/WANT="$SPLITTER_WANT"; if false; then/')"
if [ -z "$M1W" ]; then
  bad "mutant-twin:m1w" "the tautology-only mutation did not apply"
else
  : > "$M1W/.mutant-twin"
  drive "$M1W" "$WORK/seeds/base.md" probe --ceiling "$CEIL" --apply
  W_LIVE=""; [ -f "$LAST_PLAN" ] && W_LIVE="$(cat "$LAST_PLAN")"
  if [ "$LAST_RC" -eq 0 ] && has "LIVE-HAZARD-SENTINEL" "$W_LIVE" && has "LIVE-NEXTACTION-SENTINEL" "$W_LIVE"; then
    ok "mutant-twin:m1w" "the tautology ALONE rotates correctly — it flips no verdict today, which is why it shipped; m1t's kill needs both layers"
  else
    bad "mutant-twin:m1w" "the tautology alone changed the rotation (exit $LAST_RC) — m1t's kill is then attributable to it rather than to the blinded arm"
  fi
fi

# --- M2 — A LINE DROPPED FROM BOTH HALVES ----------------------------------------------------
# Targets arm 1. The emit loop starts at line 2, so line 1 reaches neither file.
M2="$(mutant_root m2-line-dropped -e 's/for (n = 1; n <= NL; n++) {/for (n = 2; n <= NL; n++) {/')"
if [ -z "$M2" ]; then
  bad "mutant:m2" "the mutation did not apply — the emit loop has moved"
else
  drive "$M2" "$WORK/seeds/base.md" probe --ceiling "$CEIL" --apply
  if [ "$LAST_RC" -ne 0 ] && has "$S_ARM1" "$LAST_OUT" && [ "$LAST_WROTE" = no ]; then
    killed "mutant:m2" "arm 1 would FAIL: a line that reached neither half is reported as lost, and nothing was written"
  else
    bad "mutant:m2" "a dropped line did not trip conservation (exit $LAST_RC): $(head -3 <<<"$LAST_OUT" | tr '\n' '|')"
  fi
fi

# --- M3 — A LINE ALTERED IN PLACE, BYTE COUNT CONSERVED --------------------------------------
# Targets arm 2, and it must NOT trip arm 1: `toupper` preserves the byte length of every ASCII
# line, so the two totals arm 1 reads are unchanged and only the CONTENT moved. Two errors that
# cancel are exactly the class a pair of totals cannot see, so the assertion demands arm 1 report
# PASS in the same output that carries arm 2's failure — a mutant failing two arms means one of
# them is vacuous.
M3="$(mutant_root m3-line-altered -e 's/if (n in move) print line\[n\] > MOVED/if (n in move) print toupper(line[n]) > MOVED/')"
if [ -z "$M3" ]; then
  bad "mutant:m3" "the mutation did not apply — the emit branch has moved"
else
  drive "$M3" "$WORK/seeds/base.md" probe --ceiling "$CEIL" --apply
  if [ "$LAST_RC" -ne 0 ] && has "$S_ARM2" "$LAST_OUT" && has "$S_ARM1OK" "$LAST_OUT" && [ "$LAST_WROTE" = no ]; then
    killed "mutant:m3" "arm 2 would FAIL: the multiset differs while arm 1 reports PASS on the same run, so the two arms are not entangled"
  else
    bad "mutant:m3" "a byte-conserving alteration did not trip the multiset arm alone (exit $LAST_RC, arm1-pass=$(has "$S_ARM1OK" "$LAST_OUT" && echo yes || echo no))"
  fi
fi

# --- M4 — THE INFO-STRING RULE REMOVED, WHICH IS THE NAIVE TOGGLE ----------------------------
# THE GRADER THAT SCORED NINE SPENT SECTIONS AS FENCED ON THIS REPO'S OWN PLAN. With this one
# line gone the grader toggles on every backtick run, so the paragraph seed opens a fence that
# never closes and the whole file reads as fenced. Killed by the info-string seed; its control is
# the conforming plan, which carries no backtick run at all and must still rotate — otherwise the
# mutation broke the grader outright rather than changing this one rule.
M4="$(mutant_root m4-naive-fence-toggle -e '/if (isdelim \&\& ch == "`" \&\& index(info, "`") > 0) { print FNR "\\t-"; next }/d')"
if [ -z "$M4" ]; then
  bad "mutant:m4" "the mutation did not apply — the info-string rule has moved"
else
  drive "$M4" "$WORK/seeds/para-info.md" probe --ceiling "$CEIL" --apply
  M4_P_RC="$LAST_RC"; M4_P_OUT="$LAST_OUT"
  drive "$M4" "$WORK/seeds/base.md" probe --ceiling "$CEIL" --apply
  M4_B_RC="$LAST_RC"
  if [ "$M4_P_RC" -ne 0 ] && has "$S_UNTERM" "$M4_P_OUT" && [ "$M4_B_RC" -eq 0 ]; then
    killed "mutant:m4" "info-string-paragraph would FAIL: the toggle opens an unterminated fence on the paragraph seed while the fence-free conforming plan still rotates"
  else
    bad "mutant:m4" "removing the info-string rule did not make the paragraph read as a fence while leaving the fence-free plan alone (paragraph rc=$M4_P_RC, conforming rc=$M4_B_RC)"
  fi
fi

# --- M5 — THE FENCE-STATE TEST REMOVED FROM THE HEADING SCAN ---------------------------------
# The grader still grades; the SPLITTER stops consulting it. A heading quoted inside a fence then
# becomes a section boundary, and the cut lands on a fenced line. Killed by the fence-cut
# refusal; control is the conforming plan, which holds no fence and must still rotate.
M5="$(mutant_root m5-heading-scan-fence-blind -e 's/^  st\[FNR\] == "F" { next }$/  st[FNR] == "NEVER" { next }/')"
if [ -z "$M5" ]; then
  bad "mutant:m5" "the mutation did not apply — the heading scan's fence test has moved"
else
  # SNAPSHOT THE WROTE-NOTHING VERDICT BEFORE THE CONTROL DRIVE. Both drives use the same root
  # and therefore the same archive path, so a test deferred past the control reads the CONTROL's
  # archive and reports that the refusal wrote. Measured on this file's first cut: m5 fired
  # correctly and scored as survived for exactly that reason.
  drive "$M5" "$WORK/seeds/fenced-heading.md" probe --ceiling "$CEIL" --apply
  M5_F_RC="$LAST_RC"; M5_F_OUT="$LAST_OUT"; M5_F_WROTE="$LAST_WROTE"
  drive "$M5" "$WORK/seeds/base.md" probe --ceiling "$CEIL" --apply
  M5_B_RC="$LAST_RC"
  if [ "$M5_F_RC" -ne 0 ] && has "$S_FENCECUT" "$M5_F_OUT" && [ "$M5_F_WROTE" = no ] && [ "$M5_B_RC" -eq 0 ]; then
    killed "mutant:m5" "fenced-heading-quiet would FAIL: a heading inside a fence becomes a boundary and the cut is refused, while the fence-free plan still rotates"
  else
    bad "mutant:m5" "blinding the heading scan to fence state did not produce a fence-cut refusal on the fenced seed alone (fenced rc=$M5_F_RC, conforming rc=$M5_B_RC)"
  fi
fi

# --- M6 — A NAMED-LIVE SECTION FORCED INTO AN ARCHIVABLE RUN ---------------------------------
# THE SECTION-EATER. `livesec` is untouched, so arm 3's cross-check AGREES and cannot see it;
# arms 1 and 2 conserve perfectly, because conservation is a statement about bytes and not about
# which half they landed in. Only arm 3's MISSING branch can, and the assertion demands it name
# `Hazards` by title — a refusal that named something else would be a different defect wearing
# this one's exit code.
#
# `\&\&` IS DELIBERATE AND IS CHECKED. An unescaped `&` in a BSD sed replacement is the WHOLE
# MATCH, so the mutation would re-insert the matched line inside itself and produce a mutant
# whose text is plausible and whose meaning is not. The grep below reads the mutant's own bytes.
M6="$(mutant_root m6-named-live-section-eaten -e 's/if (islive\[i\]) { i++; continue }/if (islive[i] \&\& ht[i] !~ \/Hazards\/) { i++; continue }/')"
if [ -z "$M6" ]; then
  bad "mutant:m6" "the mutation did not apply — the candidate-run loop has moved"
elif ! grep -qF 'if (islive[i] && ht[i] !~ /Hazards/) { i++; continue }' "$M6/scripts/plan-rotate.sh"; then
  bad "mutant:m6" "the sed replacement was mangled — an unescaped & would have re-inserted the match, and the mutant's text is not what was intended"
else
  drive "$M6" "$WORK/seeds/base.md" probe --ceiling "$CEIL" --apply
  if [ "$LAST_RC" -ne 0 ] && has "$S_ARM3" "$LAST_OUT" && has "Hazards" "$LAST_OUT" \
     && ! has "$S_ARM3X" "$LAST_OUT" && [ "$LAST_WROTE" = no ]; then
    killed "mutant:m6" "arm 3's MISSING branch would FAIL: 'Hazards' is named live and absent from the remainder, while the cross-check agrees and arms 1 and 2 conserve"
  else
    bad "mutant:m6" "a named-live section forced into an archivable run was not caught by arm 3's MISSING branch (exit $LAST_RC): $(head -4 <<<"$LAST_OUT" | tr '\n' '|')"
  fi
fi

# =============================================================================================
# THE BATCH-RECORD MUTANTS. Each is scored against the batch seed, whose unmutated run in a sandbox
# root is the `batch-records` arm above -- that is this group's control, and it must have passed
# for any verdict below to mean anything. Each kill demands the NAMED refusal or the named broken
# property, never merely a non-zero exit.
# =============================================================================================
BATCH_CTRL_OK=no
batch_run batch-control "$SUBJ" "$B_CEIL"
[ "$(batch_verdict)" = ok ] && has "$S_ARM4OK" "$B_OUT" && BATCH_CTRL_OK=yes
[ "$BATCH_CTRL_OK" = yes ] || broken "the UNMUTATED subject in a sandbox root did not rotate the batch seed correctly; every batch mutant verdict below would be scored against a broken harness: $B_OUT"

# --- M7 — THE PROTECTION TEST REPLACED BY `if (0)` --------------------------------------------
# Record 140 becomes eligible. Oldest-first reaches it LAST, so at the batch-records ceiling
# nothing changes -- which is exactly why the floor arm exists. At the floor the mutant takes 140,
# lands under the ceiling, and arm 4's LOST branch refuses the write.
M7="$(mutant_fixed m7-protection-removed 'if (rn[r] == mx || r == 1) {' 'if (0) {')"
if [ -z "$M7" ]; then
  bad "mutant:m7" "the mutation did not apply — the protection test has moved"
else
  batch_run m7-drive "$M7/scripts/plan-rotate.sh" "$B_FLOOR"
  if [ "$B_RC" -eq 2 ] && has "$S_ARM4LOST" "$B_OUT" && has "REC-140-OPEN" "$B_OUT" \
     && [ "$B_UNTOUCHED" = yes ] && [ "$B_ARCH_SAME" = yes ]; then
    killed "mutant:m7" "batch-protected-floor would FAIL: record 140 is archived to reach the floor, and arm 4 names it LOST and writes nothing"
  else
    bad "mutant:m7" "removing the protection did not trip arm 4's LOST branch at the floor (exit $B_RC): $(head -3 <<<"$B_OUT" | tr '\n' '|')"
  fi
fi

# --- M8 — OLDEST-FIRST FLIPPED TO NEWEST-FIRST ------------------------------------------------
M8="$(mutant_fixed m8-newest-first 'cnum[k] < cnum[best]' 'cnum[k] > cnum[best]')"
if [ -z "$M8" ]; then
  bad "mutant:m8" "the mutation did not apply — the class-3 order test has moved"
else
  batch_run m8-drive "$M8/scripts/plan-rotate.sh" "$B_CEIL"
  if [ "$B_RC" -eq 2 ] && has "$S_ARM4INV" "$B_OUT" && [ "$B_UNTOUCHED" = yes ]; then
    killed "mutant:m8" "batch-records would FAIL: newer records move while 101 stays, and arm 4 refuses the inversion"
  else
    bad "mutant:m8" "newest-first selection did not trip arm 4's inversion branch (exit $B_RC): $(head -3 <<<"$B_OUT" | tr '\n' '|')"
  fi
fi

# --- M9 — THE POINTER COST ZEROED IN THE SELECTION LOOP ---------------------------------------
# The loop stops at R_k, which is under C with no pointer and over it with one. This is the
# ceiling C = R_k + P/2 was chosen to discriminate: the subject must then refuse rather than write.
M9="$(mutant_fixed m9-pointer-cost-zero 'rem + ptr_cost() <= CEIL' 'rem + 0 <= CEIL')"
if [ -z "$M9" ]; then
  bad "mutant:m9" "the mutation did not apply — the budgeted stop test has moved"
else
  batch_run m9-drive "$M9/scripts/plan-rotate.sh" "$B_CEIL"
  if [ "$B_RC" -eq 2 ] && { has "$S_UNREACH" "$B_OUT" || has "$S_BUDGET" "$B_OUT"; } \
     && [ "$B_UNTOUCHED" = yes ] && [ "$B_ARCH_SAME" = yes ]; then
    killed "mutant:m9" "batch-records would FAIL: the selection stops one record short with the pointer unbudgeted, and the write is refused"
  else
    bad "mutant:m9" "an unbudgeted pointer was not refused at C = R_k + P/2 (exit $B_RC): $(head -3 <<<"$B_OUT" | tr '\n' '|')"
  fi
fi

# --- M10 — CLASS 2 NO LONGER SKIPS LINES INSIDE A CLASS-3 RECORD ------------------------------
# The indented `**BATCH 77` inside record 105 becomes a class-2 span over lines record 105 owns.
M10="$(mutant_fixed m10-class2-overlaps 'st[n] != "F" && !(n in in3) && ' 'st[n] != "F" && ')"
if [ -z "$M10" ]; then
  bad "mutant:m10" "the mutation did not apply — class 2's class-3 exclusion has moved"
else
  batch_run m10-drive "$M10/scripts/plan-rotate.sh" "$B_CEIL"
  if [ "$B_RC" -eq 2 ] && has "$S_PARTITION" "$B_OUT" && has "(batch record 105) and (retrospective batch paragraphs)" "$B_OUT" \
     && [ "$B_UNTOUCHED" = yes ]; then
    killed "mutant:m10" "batch-records would FAIL: the indented 77 paragraph is a second candidate over record 105's lines, and the partition refusal fires"
  else
    bad "mutant:m10" "an overlapping class-2 span was not refused as a non-partition (exit $B_RC): $(head -3 <<<"$B_OUT" | tr '\n' '|')"
  fi
fi

# --- M11 — CLASS 3 BLIND TO FENCES ------------------------------------------------------------
# The fenced `**BATCH 55` inside eligible record 130 opens a candidate on a fenced line.
M11="$(mutant_fixed m11-class3-fence-blind 'if (st[n] == "-" && line[n] ~ /^\*\*BATCH' 'if (line[n] ~ /^\*\*BATCH')"
if [ -z "$M11" ]; then
  bad "mutant:m11" "the mutation did not apply — the class-3 opener scan has moved"
else
  batch_run m11-drive "$M11/scripts/plan-rotate.sh" "$B_CEIL"
  if [ "$B_RC" -eq 2 ] && has "$S_FENCECUT" "$B_OUT" && [ "$B_UNTOUCHED" = yes ]; then
    killed "mutant:m11" "batch-records would FAIL: a fenced opener becomes a record boundary and the fence-cut refusal fires"
  else
    bad "mutant:m11" "a fence-blind opener scan was not refused as a fence cut (exit $B_RC): $(head -3 <<<"$B_OUT" | tr '\n' '|')"
  fi
fi

# --- M12 — ADJACENT RANGES NO LONGER COALESCED ------------------------------------------------
# The rotation is still correct in every byte; only the pointer lists each record separately.
M12="$(mutant_fixed m12-no-coalesce 'if (a && cs[sp[q]] == b + 1)' 'if (0 && cs[sp[q]] == b + 1)')"
if [ -z "$M12" ]; then
  bad "mutant:m12" "the mutation did not apply — the range coalescing test has moved"
else
  batch_run m12-drive "$M12/scripts/plan-rotate.sh" "$B_CEIL"
  M12_V="$(batch_verdict)"
  case "$M12_V" in
    "the pointer names "*) killed "mutant:m12" "batch-records would FAIL: $M12_V" ;;
    *) bad "mutant:m12" "uncoalesced ranges were not caught by the one-range check: $M12_V" ;;
  esac
fi

# --- M13 — THE NMOVED=0 EARLY EXIT 0 REINSTATED -----------------------------------------------
# The shipped defect: an over-ceiling plan with nothing to take reported "at or under the ceiling"
# at exit 0. Reinstated ahead of the no-candidate refusal, which it pre-empts again.
M13="$(mutant_fixed m13-nmoved-early-exit \
  "if LC_ALL=C grep -q '^NOCANDIDATES' \"\$WORK/meta.tsv\"; then" \
  "if [ \"\$NMOVED\" = \"0\" ]; then echo \"plan-rotate: \$PLAN is \$TOTAL bytes, at or under the \$CEILING-byte ceiling — nothing to move.\"; exit 0; fi; if LC_ALL=C grep -q '^NOCANDIDATES' \"\$WORK/meta.tsv\"; then")"
if [ -z "$M13" ]; then
  bad "mutant:m13" "the mutation did not apply — the no-candidate refusal has moved"
else
  drive "$M13" "$WORK/seeds/nocand.md" probe --ceiling "$((NC_BYTES / 2))" --apply
  if [ "$LAST_RC" -eq 0 ] && has "$S_NOTHING" "$LAST_OUT" && ! has "$S_NOCAND" "$LAST_OUT"; then
    killed "mutant:m13" "no-candidates-refuses would FAIL: the over-ceiling plan reads 'nothing to move' at exit 0 again"
  else
    bad "mutant:m13" "the reinstated early exit did not reproduce the under-ceiling sentence over the ceiling (exit $LAST_RC): $(head -2 <<<"$LAST_OUT" | tr '\n' '|')"
  fi
fi

# --- THE KILL COUNT ---------------------------------------------------------------------------
# A mutant that killed nothing reads exactly like an arm that cannot fire, and a battery whose
# seds all silently missed reads as a page of clean passes. `m1w` is a single-layer TWIN and not
# a target: it exists to show the tautology flips no verdict on its own, which is what makes
# m1t's verdict a measurement rather than an absence. Counting a twin as a kill counts the
# control as a result.
# `spent-pointer-kill` is a kill and it is NOT a `.mutant-built` root: it mutates the rotator's
# OUTPUT rather than the rotator, because the property it attacks is a string the tool writes
# into a tracked file and reads by nobody but another program. So kills exceed targets by one
# BY CONSTRUCTION, and the accounting says which is which rather than hiding it.
#
# NO TOTAL IS TYPED. The count was a literal 8 and every mutant added meant editing it; a typed
# total that fell behind would fail loudly, but one edited to match a battery that had quietly
# lost a member would not. Attempts are appended to a file by the two builders, built roots and
# twins are marked on disk, and the expected kill count is derived from them.
MUT_TRIED="$(LC_ALL=C grep -c . "$WORK/mutants.tried" 2>/dev/null)" || MUT_TRIED=0
MUT_BUILT="$(/usr/bin/find "$WORK/roots" -name '.mutant-built' -type f 2>/dev/null | wc -l | tr -d ' ')"
MUT_TWINS="$(/usr/bin/find "$WORK/roots" -name '.mutant-twin' -type f 2>/dev/null | wc -l | tr -d ' ')"
MUT_WANT=$((MUT_BUILT - MUT_TWINS + 1))
if [ "$MUT_TRIED" -gt 0 ] && [ "$MUT_BUILT" -eq "$MUT_TRIED" ] && [ "$KILLS" -eq "$MUT_WANT" ]; then
  ok "mutants" "$MUT_BUILT of $MUT_TRIED mutant roots built ($MUT_TWINS twin) and $KILLS kills — $((MUT_BUILT - MUT_TWINS)) script mutants plus the re-seeded discharge pointer, which mutates the OUTPUT and so builds no root"
else
  bad "mutants" "$MUT_BUILT of $MUT_TRIED mutant roots built ($MUT_TWINS twin), $KILLS of $MUT_WANT kills — an unkilled mutant means an arm cannot fire"
fi

echo
if [ "$FAIL" -eq 0 ]; then
  echo "plan-rotate: PASS — every assertion holds."
  exit 0
fi
echo "plan-rotate: FAIL — an assertion regressed." >&2
exit 1
