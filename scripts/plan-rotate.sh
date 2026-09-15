#!/usr/bin/env bash
# plan-rotate.sh -- move SPENT sections of a plan in docs/plans/ out to
# docs/plans/archive/<slug>.md, leaving a live remainder under a byte ceiling.
#
# WHY THIS EXISTS, MEASURED. A plan file is a HANDOFF that also accumulates a retrospective
# record, and the record grows every batch while the instruction does not.
# `docs/plans/graph-ledger-full-drain.md` measured 1158744 bytes / 14764 lines across 276
# commits of MONOTONE growth -- it has never once shrunk -- carrying 113 batch numbers. Its
# genuine instruction is under 4% of that. `scripts/backlog-rotate.sh:8` already records that
# NOTHING in this repo bounds this channel: the A6 byte ceiling in `validate-claude-rules.sh`
# covers only CLAUDE.md and .claude/rules/, and `docs/plans/retire-graph-consumer-layer.md`
# reached 384817 bytes with no push ever failing over it.
#
# IT MOVES, IT NEVER DELETES. `backlog-rotate.sh:13`'s asymmetry, inherited whole and for the
# same reason: a section wrongly KEPT costs one more read to notice; one wrongly ARCHIVED costs
# the work it recorded. Every judgement call below resolves that way, which is why this file
# REFUSES on an ambiguous cut rather than guessing at one.
#
# ------------------------------------------------------------------------------------------
# WHY `core/skills/ai-dlc-update/reconcile/lib.sh` IS NOT SOURCED HERE, AND DO NOT "FIX" THIS.
# `backlog-rotate.sh:66` sources it and REFUSES to run without it, because the LEDGER entry
# BOUNDARY is single-sourced across three readers of `docs/backlog.md`. Neither half of that
# argument reaches a plan:
#
#   1. A PLAN HAS NO `BL-` IDS. `backlog_entry_label()` -- the predicate that rotator shares --
#      returns EMPTY on every line of a plan file, so importing it would buy a boundary rule
#      with no subject. There is no second reader of a plan's section boundary to drift from.
#   2. lib.sh's FENCE GRADER DISAGREES WITH CommonMark ON THIS EXACT FILE, and
#      `backlog-rotate.sh:115` says so in as many words: `ledger_entry_shape()` strips the WHOLE
#      leading indent before its delimiter tests, where CommonMark stops honouring a delimiter
#      past column three. Measured on `graph-ledger-full-drain.md`: that rule finds 36
#      delimiters against this file's 17 real fence pairs. Importing it imports the
#      disagreement, and a rotator that cuts at a line CommonMark reads as fenced is exactly the
#      corruption `backlog-rotate.sh:71` refuses its own input over.
#
# So the grader below is STANDALONE and implements the CommonMark info-string rule directly.
# That is a deliberate second implementation of a fence reader, taken with its eyes open,
# because the two readers answer about DIFFERENT CORPORA and a shared answer would be wrong for
# one of them.
# ------------------------------------------------------------------------------------------
#
# THE NAIVE FENCE TOGGLE IS WRONG BY NINE ON THE SUBJECT FILE, AND THAT IS WHY THE INFO-STRING
# RULE IS SPELLED OUT BELOW RATHER THAN APPROXIMATED. Three graders over `^#{2,6}[ \t]` headings,
# same file, same run:
#
#     naive `^``` ` toggle            delimiters=26  fenced=10  unfenced=131
#     CommonMark info-string rule     delimiters=34  fenced= 1  unfenced=140
#
# Lines 6323 and 7423 are backtick runs whose INFO STRING CONTAINS A BACKTICK. CommonMark says a
# backtick fence's info string may hold no backtick, so both are PARAGRAPHS. The naive toggle
# opens a fence at 6323, closes it at 7423, and inverts fence state across an 1100-line band --
# misreading nine real `### BATCH 39..45` headings as fenced, which silently fuses nine spent
# sections into their neighbour and makes their boundaries invisible to the split. Only line 9819
# is genuinely fenced on that file, and it sits INSIDE the live derive block, so a splitter that
# cuts there eats live work.
#
# THE ACCEPTANCE TEST IS THREE ARMS BECAUSE THE FIRST TWO CANNOT SEE THE FAILURE THAT MATTERS.
# Measured on a real naive split of the subject file (`### BATCH` sections moved out):
#
#     LINE conservation PASSES     BYTE conservation PASSES     validator rc=1
#
# and on the SECTION-EATING variant (the heading regex widened one character so it took `## PC-`
# headings too, archiving a live section's fenced example):
#
#     LINE conservation PASSES     BYTE conservation PASSES     the live derive block LOST its
#                                                               fenced example
#
# Conservation is a statement about BYTES, not about WHICH HALF a byte landed in, so a rotation
# that archives a live section conserves perfectly. Arm 3 -- the live-section-set arm -- is the
# only one that can see it, and it DERIVES BOTH SIDES from the file so it cannot be satisfied by
# a hand-list that drifts.
#
# EVERY ARM WAS PROVEN ABLE TO GO RED BEFORE THIS SHIPPED, by building mutants of this file and
# scoring each. Each mutant is asserted to have APPLIED -- a literal one-line replacement that
# exits non-zero on an apply count other than one -- because a sed that silently no-ops reads
# exactly like a mutant the arm already kills. Base passes; all six die, each on its own arm:
#
#     M1  live-set join deleted, so every named section archives  -> arm 3's DERIVATION CROSS-CHECK
#     M2  one line dropped from both halves                       -> arm 1 conservation
#     M3  one line altered in place, byte count conserved         -> arm 2 multiset identity
#     M4  the info-string rule removed (the naive toggle)         -> unterminated-fence refusal
#     M5  the fence-state test removed from the heading scan      -> fence-cut refusal, line 9819
#     M6  one named-live section forced into the archive          -> arm 3's MISSING branch
#
# M1 IS THE REASON ARM 3 HAS A CROSS-CHECK AT ALL, and it is worth stating plainly because the
# first cut of this file SHIPPED THE DEFECT ARM 3 EXISTS TO CATCH. That version read arm 3's
# WANT side back off the splitter's own classification, so WANT and GOT were two readings of one
# decision. M1 shrank the live remainder from 138157 bytes to 2391 -- archiving `## Start here`,
# `### NEXT ACTIONS` and the plan's read/write boundary -- and arm 3 reported PASS, rc=0. A
# record a program writes from its own input is a record of INTENT, never of completion.
#
# AND FIRED IN BOTH DIRECTIONS, on plans typed BY HAND rather than derived from the subject --
# a seed that came off the tree the arm reads agrees with the arm for the wrong reason. The
# discriminating pair differs in ONE character position: a line inside a fence at column zero
# ends the batch run there and puts the cut inside the fence (REFUSED), and the same line
# indented does not (QUIET). Six more seeds -- a clean plan, a fenced heading mid-section, a
# fence wholly inside a live section, a backtick-in-info-string paragraph, a plan with no
# declared live set, and a plan under the ceiling -- land on the intended verdict.
#
# Usage:  plan-rotate.sh <plan> [--apply] [--archive <path>] [--check] [--ceiling <bytes>]
#         THE PLAN PATH IS REQUIRED AND THERE IS NO DEFAULT, unlike `backlog-rotate.sh`, which
#         defaults to the one ledger this repo has. A plan corpus has many members and picking
#         one silently is how a tool rewrites a file nobody asked it to touch.
#         default archive: <dir of plan>/archive/<basename of plan>
#         default ceiling: AI_DLC_PLAN_BYTES, else 150000.
#         Without --apply it REPORTS what would move and writes nothing.
# Exit:   0 report, apply, or nothing-to-do (already under the ceiling is NOT an error);
#         2 the plan or the repo root could not be resolved, a cut lands inside a fence, the
#           acceptance test found a difference, or the ceiling is unreachable.
set -uo pipefail

# RESOLVE THE ROOT BY WALKING UP FOR `VERSION`, NEVER BY COUNTING `..` HOPS. A validator that
# counts hops answers differently from the repo root, from a subdirectory, and from a fixture
# sandbox that copied it -- and the sandbox answer is the silent one.
REPO_ROOT=""
d="$(cd "$(dirname "$0")" && pwd)"
while [ "$d" != "/" ]; do
  if [ -f "$d/VERSION" ]; then REPO_ROOT="$d"; break; fi
  d="$(dirname "$d")"
done
[ -n "$REPO_ROOT" ] || { echo "plan-rotate: no VERSION marker above this script; repo root unknown" >&2; exit 2; }

PLAN=""
ARCHIVE=""
APPLY=false
CHECK=false
CEILING="${AI_DLC_PLAN_BYTES:-150000}"
while [ $# -gt 0 ]; do
  case "$1" in
    --apply)   APPLY=true; shift ;;
    --check)   CHECK=true; shift ;;
    --archive) ARCHIVE="${2:?--archive needs a path}"; shift 2 ;;
    --ceiling) CEILING="${2:?--ceiling needs a byte count}"; shift 2 ;;
    -*)        echo "plan-rotate: unknown option $1" >&2; exit 2 ;;
    *)         PLAN="$1"; shift ;;
  esac
done
if [ -z "$PLAN" ]; then
  echo "plan-rotate: no plan given. Usage: plan-rotate.sh <docs/plans/<slug>.md> [--apply|--check]" >&2
  exit 2
fi
[ -f "$PLAN" ] || { echo "plan-rotate: $PLAN is not a file" >&2; exit 2; }
case "$CEILING" in
  ''|*[!0-9]*) echo "plan-rotate: ceiling '$CEILING' is not a byte count" >&2; exit 2 ;;
esac
if [ -z "$ARCHIVE" ]; then
  ARCHIVE="$(dirname "$PLAN")/archive/$(basename "$PLAN")"
fi

# ---------------------------------------------------------------------------------------------
# THE CEILING TEST COMES FIRST, BEFORE ANY PARSING, AND THE FALSE-POSITIVE MEASUREMENT IS WHY.
# The first cut parsed the declaration block on every input and refused anything whose block did
# not name its live sections. Driven over the real corpus on a scratch copy tree -- 39 plans --
# that refused 37 of them, against a control in the same run of 2 plans actually over the
# ceiling. Every one of the 37 was a correct plan with nothing to do, and a lint that errors on
# 95% of its corpus on first contact is one the operator switches off, which is worse than none.
#
# The repair is SITING, not a narrowing of the grammar. A plan under the ceiling has no rotation
# to perform, so nothing about its shape needs to be decidable -- asking is the defect. After
# this gate the refusal's population is exactly the plans a rotation would run on, where
# "I cannot tell which of your sections are live" is the only safe answer available.
#
# FALSE-POSITIVE SET AFTER THE NARROWING, re-measured the same way: 1 of 39 --
# `retire-graph-consumer-layer.md` at 384817 bytes, which is over the ceiling and whose
# declaration block genuinely does not name its live sections. It is a REAL finding, not a
# false one: that plan cannot be rotated safely until someone says what in it is live, and the
# refusal says so and writes nothing.
# ---------------------------------------------------------------------------------------------
PLAN_BYTES="$(wc -c < "$PLAN" | tr -d ' ')"
if [ "$PLAN_BYTES" -le "$CEILING" ]; then
  echo "plan-rotate: $PLAN is $PLAN_BYTES bytes, at or under the $CEILING-byte ceiling — nothing to move."
  echo "  (this is a normal state, not an error; a plan under the ceiling rotates to itself)"
  exit 0
fi

WORK="$(mktemp -d)" || { echo "plan-rotate: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
GRADE="$WORK/grade.tsv"
LIVEF="$WORK/live.md"
MOVEDF="$WORK/moved.md"

# ---------------------------------------------------------------------------------------------
# THE FENCE GRADER. Emits one `<line>\t<state>` row per input line, where state is:
#   D  a fence DELIMITER (opener or closer) -- not content of a fence
#   F  inside a fence
#   -  ordinary content
# plus a trailing `UNTERMINATED\t<line>` row when a fence never closes.
#
# CommonMark, stated precisely because the approximations are what go wrong:
#   - a delimiter is a run of >= 3 backticks or >= 3 tildes at an indent of AT MOST 3 COLUMNS,
#     where a TAB counts as four columns and not as one character;
#   - a BACKTICK opener's info string may contain NO BACKTICK. A line like
#     ```` ```derived ```` ... is a PARAGRAPH, not a fence, and reading it as one inverts the
#     fence state for everything below it until the next such line;
#   - a TILDE opener's info string may contain anything, including backticks;
#   - a closer must use the SAME character as its opener, be AT LEAST AS LONG, and carry nothing
#     but blanks after the run. A `run + info string` line inside a fence is content.
# ---------------------------------------------------------------------------------------------
LC_ALL=C awk '
  function indent_cols(l,   i, c, ch) {
    c = 0
    for (i = 1; i <= length(l); i++) {
      ch = substr(l, i, 1)
      if (ch == " ") c += 1
      else if (ch == "\t") c += 4
      else break
    }
    return c
  }
  function run_len(s, ch,   i, n) {
    n = 0
    for (i = 1; i <= length(s); i++) { if (substr(s, i, 1) != ch) break; n++ }
    return n
  }
  {
    body = $0
    sub(/\r$/, "", body)
    stripped = body
    sub(/^[ \t]+/, "", stripped)
    ch = substr(stripped, 1, 1)
    isdelim = 0; n = 0; info = ""
    if ((ch == "`" || ch == "~") && indent_cols(body) <= 3) {
      n = run_len(stripped, ch)
      if (n >= 3) { isdelim = 1; info = substr(stripped, n + 1) }
    }
    if (!IN) {
      # A BACKTICK RUN WHOSE INFO STRING CARRIES A BACKTICK IS A PARAGRAPH. This one line is the
      # whole difference between fenced=1 and fenced=10 on the subject file.
      if (isdelim && ch == "`" && index(info, "`") > 0) { print FNR "\t-"; next }
      if (isdelim) { IN = 1; FCH = ch; FLEN = n; FAT = FNR; print FNR "\tD"; next }
      print FNR "\t-"; next
    }
    if (isdelim && ch == FCH && n >= FLEN) {
      rest = info; gsub(/[ \t]/, "", rest)
      if (rest == "") { IN = 0; print FNR "\tD"; next }
    }
    print FNR "\tF"
  }
  END { if (IN) print "UNTERMINATED\t" FAT }
' "$PLAN" > "$GRADE"

UNTERM="$(LC_ALL=C awk -F'\t' '$1=="UNTERMINATED"{print $2}' "$GRADE")"
if [ -n "$UNTERM" ]; then
  echo "plan-rotate: REFUSING to rotate $PLAN -- a fence opened at line $UNTERM and never closes." >&2
  echo "  Everything below that line is inside it, so every section boundary under it is a" >&2
  echo "  fenced line and no split of this file can be trusted. Close the fence, then re-run." >&2
  echo "  Nothing was moved and nothing was written." >&2
  exit 2
fi

# ---------------------------------------------------------------------------------------------
# THE SPLIT, AND THE LIVE SET IS DERIVED FROM THE PLAN'S OWN DECLARATION BLOCK.
#
# THE HISTORY BOUNDARY IS BY HEADING, NEVER BY POSITION, and the subject file says so about
# itself at its line 27: `## Start here`, `## Hazards` and `### Done when` all sit BELOW
# `## Context`, so a rule reading "everything from `## Context` down is HISTORY" archives this
# plan's own READ/WRITE BOUNDARY. That is the single most expensive line in the file.
#
# So: the plan's FIRST level-2 section is its DECLARATION BLOCK, and the section titles it names
# in backticks inside its numbered list are the LIVE SET. Both sides of that join come off the
# file. A hand-list here would be a second population that drifts from the plan silently, and a
# heading-position rule is refuted above.
#
# TWO BOUNDARY GRAMMARS, NOT ONE. Section runs alone leave the subject file at 370201 bytes --
# over any ceiling worth setting -- because ONE live section, `### NEXT ACTIONS`, is 151936 bytes
# of which 100648 is a retrospective tail appended under action 1. That tail is delimited by
# `^[[:space:]]+\*\*BATCH [0-9]+` paragraphs with ZERO competing headings in its span, which is a
# machine-readable boundary, so it is a second candidate class rather than an impossibility.
# ---------------------------------------------------------------------------------------------
LC_ALL=C awk -v G="$GRADE" -v CEIL="$CEILING" -v LIVE="$LIVEF" -v MOVED="$MOVEDF" '
  BEGIN {
    while ((getline l < G) > 0) { split(l, a, "\t"); if (a[1] == "UNTERMINATED") continue; st[a[1]+0] = a[2] }
  }
  { line[FNR] = $0; blen[FNR] = length($0) + 1; total += blen[FNR] }
  # A HEADING INSIDE A FENCE IS NOT A HEADING. On the subject file exactly one line qualifies --
  # 9819, `## PC-S314-...`, quoted as an EXAMPLE inside the live derive block -- and a splitter
  # that treats it as a boundary cuts a live section in half.
  st[FNR] == "F" { next }
  /^#{1,6}[ \t]/ { nh++; hl[nh] = FNR; ht[nh] = $0 }
  END {
    NL = NR
    if (nh == 0) { print "NOHEADINGS" > "/dev/stderr"; exit 3 }
    for (i = 1; i <= nh; i++) he[i] = (i < nh ? hl[i+1] - 1 : NL)

    # --- the declaration block: the first level-2 section ------------------------------------
    di = 0
    for (i = 1; i <= nh; i++) if (ht[i] ~ /^##[ \t]/) { di = i; break }
    if (di == 0) { print "NODECL" > "/dev/stderr"; exit 3 }
    printf "decl\t%d\t%d\t%s\n", hl[di], he[di], ht[di] > "/dev/stderr"

    # --- the named-live set: backticked `#...` titles inside the declaration block s NUMBERED
    # --- list items. The list is where the plan enumerates the sections a reader must read;
    # --- prose elsewhere in the block names sections it is describing as HISTORY.
    for (n = hl[di]; n <= he[di]; n++) {
      s = line[n]
      if (s ~ /^[0-9]+\.[ \t]/) innum = 1
      else if (s ~ /^[^ \t]/) innum = 0
      if (!innum) continue
      while (match(s, /`#+[^`]+`/)) {
        t = substr(s, RSTART + 1, RLENGTH - 2)
        sub(/^#+[ \t]*/, "", t); sub(/[ \t]+$/, "", t)
        if (!(t in named)) { named[t] = 1; order[++nn] = t; print "named\t" t > "/dev/stderr" }
        s = substr(s, RSTART + RLENGTH)
      }
    }
    if (nn == 0) { print "NONAMED" > "/dev/stderr"; exit 3 }

    # --- mark live sections: the title block, the declaration block, and every named one.
    # --- A TITLE MAY REPEAT. `## Done when` and `### Done when` both exist on the subject file
    # --- and BOTH are named; matching by title keeps both, which is the it-moves-never-deletes
    # --- direction.
    for (i = 1; i <= nh; i++) {
      t = ht[i]; sub(/^#+[ \t]*/, "", t); sub(/[ \t]+$/, "", t)
      islive[i] = (i <= di) || (t in named)
      if (islive[i]) printf "livesec\t%d\t%d\t%s\n", hl[i], he[i], t > "/dev/stderr"
    }

    # --- candidate class 1: maximal runs of consecutive NON-live sections --------------------
    i = 1
    while (i <= nh) {
      if (islive[i]) { i++; continue }
      j = i; while (j + 1 <= nh && !islive[j+1]) j++
      nc++; cs[nc] = hl[i]; ce[nc] = he[j]; ck[nc] = "spent sections"
      i = j + 1
    }
    # --- candidate class 2: retrospective BATCH paragraph runs INSIDE a live section ---------
    for (i = 1; i <= nh; i++) {
      if (!islive[i]) continue
      n = hl[i]
      while (n <= he[i]) {
        if (st[n] != "F" && line[n] ~ /^[[:space:]]+\*\*BATCH [0-9]+/) {
          rs = n; re = n
          for (m = n + 1; m <= he[i]; m++) {
            # the run ends at the first line that starts a NEW top-level block: a non-blank
            # line at column 0. Indented continuation and blank lines belong to the run.
            if (line[m] ~ /^[^ \t]/ && line[m] !~ /^[[:space:]]*$/) break
            re = m
          }
          nc++; cs[nc] = rs; ce[nc] = re; ck[nc] = "retrospective batch paragraphs"
          n = re + 1
        } else n++
      }
    }

    # --- REFUSE A CUT THAT LANDS INSIDE A FENCE ----------------------------------------------
    # Every span boundary is a cut. A cut at a fenced line splits the fence, leaving an
    # unterminated one in the archive and an orphan closer in the live file -- corruption at
    # exit 0. Refuse rather than guess, in `backlog-rotate.sh:88` s spirit.
    for (k = 1; k <= nc; k++) {
      if (st[cs[k]] == "F") printf "fencecut\t%d\tspan start\n", cs[k] > "/dev/stderr"
      if (ce[k] < NL && st[ce[k] + 1] == "F") printf "fencecut\t%d\tspan end\n", ce[k] + 1 > "/dev/stderr"
    }

    # --- greedy, LARGEST SPAN FIRST, until the remainder is under the ceiling ----------------
    # Largest-first is the it-moves-never-deletes direction: it reaches the ceiling while
    # touching the FEWEST spans, so the smallest number of judgement calls are made.
    rem = total
    for (k = 1; k <= nc; k++) { by = 0; for (n = cs[k]; n <= ce[k]; n++) by += blen[n]; cb[k] = by }
    while (rem > CEIL) {
      best = 0; bb = -1
      for (k = 1; k <= nc; k++) if (!got[k] && cb[k] > bb) { bb = cb[k]; best = k }
      if (best == 0) break
      got[best] = 1; rem -= cb[best]
    }
    printf "total\t%d\tremainder\t%d\tceiling\t%d\n", total, rem, CEIL > "/dev/stderr"
    if (rem > CEIL) print "UNREACHABLE" > "/dev/stderr"

    # --- emit the split ----------------------------------------------------------------------
    for (k = 1; k <= nc; k++) if (got[k]) {
      for (n = cs[k]; n <= ce[k]; n++) move[n] = k
      printf "moving\t%d\t%d\t%d\t%s\n", cs[k], ce[k], cb[k], ck[k] > "/dev/stderr"
      nmoved++
    }
    printf "nmoved\t%d\n", nmoved+0 > "/dev/stderr"
    for (n = 1; n <= NL; n++) {
      if (n in move) print line[n] > MOVED
      else           print line[n] > LIVE
    }
  }
' "$PLAN" 2> "$WORK/meta.tsv"
AWK_RC=$?
if [ "$AWK_RC" -ne 0 ]; then
  echo "plan-rotate: REFUSING to rotate $PLAN -- its shape cannot be read." >&2
  case "$(LC_ALL=C awk -F'\t' '$1=="NOHEADINGS"||$1=="NODECL"||$1=="NONAMED"{print $1}' "$WORK/meta.tsv" | head -1)" in
    NOHEADINGS) echo "  It carries no unfenced ATX heading, so it has no sections to partition." >&2 ;;
    NODECL)     echo "  It carries no level-2 heading, so it has no declaration block naming its live sections." >&2 ;;
    NONAMED)    echo "  Its first level-2 section names no section titles in backticks inside a numbered list." >&2
                echo "  THIS IS THE SIDE OF THE JOIN THAT SAYS WHAT IS LIVE. Without it every section below" >&2
                echo "  the declaration block reads as spent, and a rotation would archive the plan's own" >&2
                echo "  read/write boundary and its next actions. Name the live sections in the declaration" >&2
                echo "  block -- '1. \`## Start here\` -- ...' -- and re-run." >&2 ;;
  esac
  echo "  Nothing was moved and nothing was written." >&2
  exit 2
fi

FENCECUTS="$(LC_ALL=C awk -F'\t' '$1=="fencecut"{printf "  line %s: a %s lands inside a fenced block\n", $2, $3}' "$WORK/meta.tsv")"
if [ -n "$FENCECUTS" ]; then
  echo "plan-rotate: REFUSING to rotate $PLAN -- a section boundary lands inside a fenced block." >&2
  printf '%s\n' "$FENCECUTS" >&2
  echo "  Splitting there leaves an unterminated fence in the archive and an orphan delimiter in" >&2
  echo "  the live file, at exit 0, with no symptom until someone reads it. Fix the plan, not this" >&2
  echo "  guard: indent the fenced heading, or drop its leading '#' so it is not heading-shaped." >&2
  echo "  Nothing was moved and nothing was written." >&2
  exit 2
fi

TOTAL="$(LC_ALL=C awk -F'\t' '$1=="total"{print $2}' "$WORK/meta.tsv")"
REMAIN="$(LC_ALL=C awk -F'\t' '$1=="total"{print $4}' "$WORK/meta.tsv")"
NMOVED="$(LC_ALL=C awk -F'\t' '$1=="nmoved"{print $2}' "$WORK/meta.tsv")"
NMOVED="${NMOVED:-0}"

if [ "$NMOVED" = "0" ]; then
  echo "plan-rotate: $PLAN is $TOTAL bytes, at or under the $CEILING-byte ceiling — nothing to move."
  echo "  (this is a normal state, not an error; a plan under the ceiling rotates to itself)"
  exit 0
fi

if LC_ALL=C grep -q '^UNREACHABLE' "$WORK/meta.tsv"; then
  echo "plan-rotate: REFUSING to rotate $PLAN -- every archivable span was taken and the live" >&2
  echo "  remainder is still $REMAIN bytes against a $CEILING-byte ceiling." >&2
  echo "  The live sections THEMSELVES exceed the ceiling, so no rotation reaches it and the" >&2
  echo "  remedy is editorial, not mechanical: shorten a live section, or move a retrospective" >&2
  echo "  tail out of one under a '**BATCH <n>' paragraph so this tool can see it." >&2
  echo "  Nothing was moved and nothing was written." >&2
  exit 2
fi

echo "plan-rotate: $PLAN is $TOTAL bytes against a $CEILING-byte ceiling."
echo "  $NMOVED span(s) would move to $ARCHIVE, leaving $REMAIN bytes live:"
LC_ALL=C awk -F'\t' '$1=="moving"{printf "    lines %s..%s  %s bytes  (%s)\n", $2, $3, $4, $5}' "$WORK/meta.tsv"

# ---------------------------------------------------------------------------------------------
# THE ACCEPTANCE TEST -- THREE ARMS, EACH INDEPENDENTLY ABLE TO GO RED.
#
# It runs on EVERY invocation, not only under `--check`, and not inside either branch. A guard
# reachable only by `--check` is bypassed by omitting the flag, and one inside `--apply` is
# bypassed by running `--check`; `backlog-rotate.sh:339` records that exact siting mistake.
# ---------------------------------------------------------------------------------------------
ORIG_B="$(wc -c < "$PLAN" | tr -d ' ')"
ORIG_L="$(wc -l < "$PLAN" | tr -d ' ')"
LIVE_B="$(wc -c < "$LIVEF" | tr -d ' ')"; LIVE_L="$(wc -l < "$LIVEF" | tr -d ' ')"
MOVE_B="$(wc -c < "$MOVEDF" | tr -d ' ')"; MOVE_L="$(wc -l < "$MOVEDF" | tr -d ' ')"

# --- ARM 1: BYTE conservation ----------------------------------------------------------------
# LINE conservation is NOT sufficient and this is measured, not cautious: on a naive split of the
# subject file that archived nine live headings, line conservation PASSED and byte conservation
# PASSED. Bytes are strictly stronger than lines -- a truncated line conserves the line count and
# not the byte count -- so bytes are what is asserted, and lines are reported beside them because
# a line delta is the more legible diagnosis when one fires.
if [ "$((LIVE_B + MOVE_B))" -ne "$ORIG_B" ] || [ "$((LIVE_L + MOVE_L))" -ne "$ORIG_L" ]; then
  echo "plan-rotate: REFUSING TO APPLY — arm 1 (conservation) FAILED." >&2
  echo "  in:  $ORIG_L lines / $ORIG_B bytes" >&2
  echo "  out: $LIVE_L + $MOVE_L = $((LIVE_L + MOVE_L)) lines / $LIVE_B + $MOVE_B = $((LIVE_B + MOVE_B)) bytes" >&2
  echo "  A rotation that loses a byte is the failure this tool exists to not have." >&2
  exit 2
fi
echo "  arm 1 conservation PASS: $LIVE_L + $MOVE_L = $ORIG_L lines, $LIVE_B + $MOVE_B = $ORIG_B bytes."

# --- ARM 2: MULTISET identity ----------------------------------------------------------------
# Arm 1 reads two TOTALS, so two errors that cancel pass it: a line moved to the wrong half and
# ALTERED by the same number of bytes conserves both counts perfectly. Sorting both sides and
# hashing compares the CONTENT as a multiset, which no pair of cancelling byte edits survives.
# `sort` and not `sort -u`: a duplicate line dropped from one half and gained by the other is
# exactly the class this is here for, and `-u` would erase it.
ORIG_MD5="$(LC_ALL=C sort "$PLAN" | md5)"
SPLIT_MD5="$(cat "$LIVEF" "$MOVEDF" | LC_ALL=C sort | md5)"
if [ "$ORIG_MD5" != "$SPLIT_MD5" ]; then
  echo "plan-rotate: REFUSING TO APPLY — arm 2 (multiset identity) FAILED." >&2
  echo "  sorted original md5: $ORIG_MD5" >&2
  echo "  sorted split    md5: $SPLIT_MD5" >&2
  echo "  The two halves do not hold the same LINES as the original, so a line was altered or" >&2
  echo "  duplicated on its way across. Arm 1 passed, which means the byte counts cancelled." >&2
  diff <(LC_ALL=C sort "$PLAN") <(cat "$LIVEF" "$MOVEDF" | LC_ALL=C sort) | head -20 >&2
  exit 2
fi
echo "  arm 2 multiset identity PASS: sorted halves hash to the original ($ORIG_MD5)."

# --- ARM 3: THE LIVE-SECTION SET --------------------------------------------------------------
# THE ONLY ARM THAT CAN SEE "A LIVE SECTION GOT ARCHIVED". Arms 1 and 2 are statements about
# bytes and lines, not about WHICH HALF one landed in, so both pass perfectly on a split that
# archives the plan's read/write boundary -- measured, on the section-eating variant.
#
# BOTH SIDES ARE DERIVED FROM THE FILE, AND THE WANT SIDE IS RE-DERIVED RATHER THAN READ BACK
# OFF THE SPLITTER. THE FIRST CUT OF THIS ARM GOT THAT WRONG AND IT IS THE DEFECT THIS WHOLE ARM
# EXISTS TO CATCH, ONE LEVEL UP. That version took WANT from the splitter's own `livesec` rows --
# which the splitter emits from its own `islive` classification -- so WANT and GOT were two
# readings of ONE decision. Measured, with a mutant that deleted the `|| (t in named)` clause so
# every named-live section was archived: the mutant shrank the live remainder from 138157 bytes
# to 2391, archiving `## Start here`, `### NEXT ACTIONS` and the plan's read/write boundary, and
# the arm reported `all 2 section(s) ... are in the live remainder` and PASSED, rc=0. A record a
# program writes from its own input is a record of INTENT, never of completion.
#
# So the WANT side below re-reads the PLAN, re-grades its fences, re-finds its declaration block
# and re-extracts the named titles, in a pass that shares no state with the splitter. The GOT
# side is the unfenced heading set of the live remainder, graded from scratch on the remainder
# itself. Two independent derivations of the same set, which is the only shape that can
# disagree.
WANT="$(LC_ALL=C awk '
  function indent_cols(l,   i, c, ch) {
    c = 0
    for (i = 1; i <= length(l); i++) { ch = substr(l, i, 1); if (ch == " ") c += 1; else if (ch == "\t") c += 4; else break }
    return c
  }
  function run_len(s, ch,   i, n) { n = 0; for (i = 1; i <= length(s); i++) { if (substr(s, i, 1) != ch) break; n++ } return n }
  {
    line[FNR] = $0
    body = $0; sub(/\r$/, "", body); stripped = body; sub(/^[ \t]+/, "", stripped)
    ch = substr(stripped, 1, 1); isdelim = 0; n = 0; info = ""
    if ((ch == "`" || ch == "~") && indent_cols(body) <= 3) { n = run_len(stripped, ch); if (n >= 3) { isdelim = 1; info = substr(stripped, n + 1) } }
    if (!IN) {
      if (isdelim && ch == "`" && index(info, "`") > 0) { fenced[FNR] = 0 }
      else if (isdelim) { IN = 1; FCH = ch; FLEN = n; fenced[FNR] = 0; next }
    } else {
      if (isdelim && ch == FCH && n >= FLEN) { rest = info; gsub(/[ \t]/, "", rest); if (rest == "") IN = 0 }
      fenced[FNR] = 1; next
    }
  }
  END {
    # the declaration block is the FIRST level-2 section; its numbered list names the live set.
    for (n = 1; n <= NR; n++) {
      if (fenced[n]) continue
      if (line[n] ~ /^##[ \t]/) { if (!ds) ds = n; else if (!de) { de = n - 1; break } }
      else if (ds && line[n] ~ /^#{1,6}[ \t]/) { de = n - 1; break }
    }
    if (!ds) exit 0
    if (!de) de = NR
    # the declaration block titles ITSELF, and it is live by construction -- the resume block
    # cannot name itself in its own numbered list and does not have to.
    t = line[ds]; sub(/^#+[ \t]*/, "", t); sub(/[ \t]+$/, "", t); print t
    for (n = 1; n < ds; n++) {
      if (fenced[n]) continue
      if (line[n] ~ /^#{1,6}[ \t]/) { t = line[n]; sub(/^#+[ \t]*/, "", t); sub(/[ \t]+$/, "", t); print t }
    }
    for (n = ds; n <= de; n++) {
      s = line[n]
      if (s ~ /^[0-9]+\.[ \t]/) innum = 1
      else if (s ~ /^[^ \t]/) innum = 0
      if (!innum) continue
      while (match(s, /`#+[^`]+`/)) {
        t = substr(s, RSTART + 1, RLENGTH - 2)
        sub(/^#+[ \t]*/, "", t); sub(/[ \t]+$/, "", t)
        print t
        s = substr(s, RSTART + RLENGTH)
      }
    }
  }
' "$PLAN" | LC_ALL=C sort -u)"
# THE RE-DERIVATION MUST AGREE WITH THE SPLITTER ABOUT THE SET, OR ONE OF THEM IS BROKEN AND
# THE ARM'S VERDICT IS UNREADABLE EITHER WAY. This is an ASSERTION on the two passes, never a
# control: a disagreement means the arm cannot be trusted in EITHER direction, so it refuses
# rather than reporting whichever answer it happened to compute. A differential whose two sides
# share a defect reads as agreement, and this is what stops these two from silently becoming
# one reader again.
SPLITTER_WANT="$(LC_ALL=C awk -F'\t' '$1=="livesec"{print $4}' "$WORK/meta.tsv" | LC_ALL=C sort -u)"
if [ "$WANT" != "$SPLITTER_WANT" ]; then
  echo "plan-rotate: REFUSING TO APPLY — arm 3's two independent derivations of the LIVE-SECTION" >&2
  echo "  set disagree. The splitter and the acceptance test read the same file and got different" >&2
  echo "  answers, so neither verdict can be read." >&2
  diff <(printf '%s\n' "$SPLITTER_WANT") <(printf '%s\n' "$WANT") >&2
  exit 2
fi
LC_ALL=C awk '
  function indent_cols(l,   i, c, ch) {
    c = 0
    for (i = 1; i <= length(l); i++) { ch = substr(l, i, 1); if (ch == " ") c += 1; else if (ch == "\t") c += 4; else break }
    return c
  }
  function run_len(s, ch,   i, n) { n = 0; for (i = 1; i <= length(s); i++) { if (substr(s, i, 1) != ch) break; n++ } return n }
  {
    body = $0; sub(/\r$/, "", body); stripped = body; sub(/^[ \t]+/, "", stripped)
    ch = substr(stripped, 1, 1); isdelim = 0; n = 0; info = ""
    if ((ch == "`" || ch == "~") && indent_cols(body) <= 3) { n = run_len(stripped, ch); if (n >= 3) { isdelim = 1; info = substr(stripped, n + 1) } }
    if (!IN) {
      if (isdelim && ch == "`" && index(info, "`") > 0) { }
      else if (isdelim) { IN = 1; FCH = ch; FLEN = n; next }
    } else {
      if (isdelim && ch == FCH && n >= FLEN) { rest = info; gsub(/[ \t]/, "", rest); if (rest == "") { IN = 0 } }
      next
    }
    if (/^#{1,6}[ \t]/) { t = $0; sub(/^#+[ \t]*/, "", t); sub(/[ \t]+$/, "", t); print t }
  }
' "$LIVEF" | LC_ALL=C sort -u > "$WORK/got.txt"
MISSING="$(comm -23 <(printf '%s\n' "$WANT") "$WORK/got.txt")"
if [ -n "$MISSING" ]; then
  echo "plan-rotate: REFUSING TO APPLY — arm 3 (live-section set) FAILED." >&2
  echo "  These sections are named LIVE by $PLAN's own declaration block and are NOT in the live" >&2
  echo "  remainder the split produced:" >&2
  printf '%s\n' "$MISSING" | sed 's/^/    /' >&2
  echo "  Arms 1 and 2 pass on this, because conservation is a statement about bytes and not" >&2
  echo "  about which half they landed in. A rotation that archives a plan's read/write boundary" >&2
  echo "  or its next actions is the one failure that costs the work the plan records." >&2
  echo "  Nothing was moved and nothing was written." >&2
  exit 2
fi
NWANT="$(printf '%s\n' "$WANT" | LC_ALL=C grep -c .)" || NWANT=0
echo "  arm 3 live-section set PASS: all $NWANT section(s) the declaration block names are in the live remainder."

if [ "$CHECK" = true ] && [ "$APPLY" != true ]; then
  echo "  --check PASS: all three acceptance arms green."
fi

if [ "$APPLY" != true ]; then
  echo "  (report only; pass --apply to move them)"
  exit 0
fi

# ---------------------------------------------------------------------------------------------
# APPLY. The archive is written with a header of KNOWN, DECLARED size -- arm 1 above compares
# the SPLIT, before any header is added, so the header cannot mask a lost byte.
# ---------------------------------------------------------------------------------------------
mkdir -p "$(dirname "$ARCHIVE")" || { echo "plan-rotate: cannot create $(dirname "$ARCHIVE")" >&2; exit 2; }
# REPO-RELATIVE, for the reason the pointer block below states at length: these strings land in
# TRACKED files, and the path the caller happened to type is not a fact about the repository.
PLAN_REL="${PLAN#$REPO_ROOT/}"
if [ ! -f "$ARCHIVE" ]; then
  {
    echo "# $(basename "$PLAN" .md) — archived sections"
    echo
    echo "Spent sections rotated out of \`$PLAN_REL\` by \`scripts/plan-rotate.sh\`."
    echo "Nothing here is deleted; this file is the destination, not a wastebasket. It is a RECORD:"
    echo "read it when a rule in the live plan looks arbitrary, or when you need the evidence"
    echo "behind a figure. **Do not take an instruction from it.**"
    echo
  } > "$ARCHIVE"
fi
cat "$MOVEDF" >> "$ARCHIVE"
cp "$LIVEF" "$PLAN"

# ---------------------------------------------------------------------------------------------
# THE POINTER. AN ARCHIVED RECORD THAT NOTHING POINTS AT IS THE BLINDNESS `BL-255` NAMES: the
# evidence still exists and no reader can find it, which reads exactly like the evidence being
# gone. Refreshed on every apply so a second rotation does not leave a stale range behind.
#
# A PLAIN PATH STRING, NEVER A `path:line` CITATION. `validate-plan-shape.sh:138` harvests
# `path:line` tokens and errors when one does not resolve; a citation into an archive that a
# later rotation re-numbers would fail P4 on a correct rotation. The path alone carries the
# reader there and is stable under re-rotation.
#
# AND IT IS WRITTEN REPO-RELATIVE, NOT AS THE CALLER SPELLED IT. The archive path is derived
# from the plan path as given on the command line, so an absolute invocation writes an absolute
# path into a TRACKED file -- one carrying whatever scratch or worktree directory the rotation
# happened to run in, which resolves on exactly one machine. Stripping the root makes the
# pointer the same string whichever way the tool was invoked.
# ---------------------------------------------------------------------------------------------
ARCHIVE_REL="${ARCHIVE#$REPO_ROOT/}"
RANGES="$(LC_ALL=C awk -F'\t' '$1=="moving"{printf "%s%s..%s", (c++ ? ", " : ""), $2, $3}' "$WORK/meta.tsv")"
POINTER="**Spent sections are archived at \`$ARCHIVE_REL\`** — rotated by \`scripts/plan-rotate.sh\`, original lines $RANGES. It is a RECORD, not an instruction: read it for the evidence behind a figure, never for something to do."
LC_ALL=C awk -v P="$POINTER" '
  BEGIN { done = 0 }
  /^\*\*Spent sections are archived at/ { if (!done) { print P; done = 1 }; next }
  { print }
  END {
    if (!done) {
      # No pointer existed. It goes immediately after the title line, above everything a
      # resuming session reads, because a pointer below the fold is a pointer nobody follows.
      exit 1
    }
  }
' "$PLAN" > "$WORK/pointed.md"
if [ $? -ne 0 ]; then
  LC_ALL=C awk -v P="$POINTER" 'NR==1 { print; print ""; print P; next } { print }' "$PLAN" > "$WORK/pointed.md"
fi
cp "$WORK/pointed.md" "$PLAN"

FINAL_B="$(wc -c < "$PLAN" | tr -d ' ')"
echo "  applied: $NMOVED span(s) appended to $ARCHIVE; $PLAN is now $FINAL_B bytes (was $ORIG_B)."
exit 0
