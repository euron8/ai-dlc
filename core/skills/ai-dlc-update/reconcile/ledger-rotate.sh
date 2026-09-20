#!/usr/bin/env bash
# reconcile-region: exempt — an action that moves CLOSED entries to an archive. It reports what it rotated, not a pull finding.
# ledger-rotate.sh — move CLOSED push-candidate entries out of the live ledger and into an
# archive, so the file the pull reads stays proportional to the work that is still open.
#
# WHY THIS EXISTS. The ledger is append-only by design: step 8 appends, ledger-reverify never
# edits, and a close is an ANNOTATION ("ADOPTED UPSTREAM"), never a deletion — deliberately,
# because the entry is the provenance of an upstreamed change. Nothing, however, ever moved a
# closed entry OUT. Measured on the reference consumer at v0.147.1: 2830 lines / 220 KB / 50
# entries, grown 1038 -> 1820 -> 2325 -> 2830 across 40 commits, monotonic, never once
# smaller. Only 39 entries still classify. The rest are parsed on every pull, re-rendered into
# every report, and re-read by every agent that edits the file, for zero classifier value.
#
# The cost is not theoretical: a batch of receipt edits against a 220 KB ledger is the slowest
# step in the whole update, and it grows every sprint.
#
# ROTATION IS DELIBERATELY STRICTER THAN THE SKIP RULE, and the asymmetry is the point.
# `ledger-reverify.sh` treats an entry as closed on a LINE-LEADING marker with an OPTIONAL bold
# span. That is right for SKIPPING — the cost of skipping one extra entry is one unverified row —
# but wrong for MOVING, where the cost is live work filed into an archive nobody re-reads.
#
# The phrase occurs in open entries as instruction ("annotate `ADOPTED UPSTREAM (vX, verified
# <date>)` once the grep is non-zero") and as narrative ("the sentinel ADOPTED UPSTREAM in
# v0.135.0, but ..."). Measured on the reference consumer: 47 occurrences, 32 in the annotation
# form, so 15 are not annotations. A rotation on the loose rule archives those entries.
#
# SO ROTATION REQUIRES THE ANNOTATION FORM, AND THAT REQUIREMENT IS NOW ONE TRANSFORM OF THE SKIP
# RULE RATHER THAN A SECOND LIST. An annotation opens a BOLD SPAN; a prose mention does not. So
# `lib.sh`s `ledger_archive_awk()` takes reverify`s grammar and makes its optional bold span
# MANDATORY, changing nothing else. An entry wrongly kept costs one more pull to notice; an entry
# wrongly archived costs the work — and both of those are still true, because the transform is
# strictly narrowing. MEASURED over the reference consumer`s two ledger files in one invocation:
# skip 5 / archive 4 on the live file, 265 / 265 on the archive, an archive-not-a-subset-of-skip
# count of ZERO on both, impossible-token control 0.
#
# THIS FILE USED TO HAND-WRITE ITS OWN LITERAL, `**ADOPTED UPSTREAM (v<digit>`, AT THREE SITES,
# AND THAT LIST WAS ONE TOKEN SHORT OF THE SKIP RULE IT SAT BESIDE. Measured at our tip before
# this change: the token `WITHDRAWN` appeared in this file ZERO times (control, same invocation,
# same file: `ADOPTED UPSTREAM` 19 times; impossible token 0) while the lifted skip rule honoured
# it. An entry closed that way was skipped by EVERY re-verification and refused by EVERY rotation
# at once — invisible in the report and permanently resident in the live ledger, which is the
# class the stuck report below names "closed-and-unarchivable" and could never shrink. Measured on
# the reference consumer live ledger: SIX entries stranded, five of which the derived grammar
# takes. Nothing the old literal archived stops archiving — the lines it takes that this grammar
# does not number ZERO across both consumer files, on boundary lines and bodies alike.
#
# AND THE VERSION DIGIT IS GONE ON PURPOSE. It was added after this script archived a live entry,
# to stop the pattern matching its own quotation and to stop `\(v` matching `(verified`. The
# no-backtick run inside the bold span does the first job — an annotation never quotes itself —
# and the second job was never legitimate: a close that HAS no version (a withdrawal, an
# absorption predating the pull`s base, a rejection adjudicated by date) is a genuine close, and
# a rule demanding a digit left the operator two exits, leave the entry live forever or annotate
# a falsehood. Requiring the FORM and saying nothing about the parenthetical is what lets a
# versionless close archive on its own terms without inventing a version for it.
#
# Entry BOUNDARIES are lifted from ledger-reverify's parser unchanged: an entry is a
# top-level `- **…**` bullet or a `##`-`######` heading, and either one ENDS the entry above.
#
# THE INVARIANT THAT MAKES THIS SAFE, AND THE PROJECTION IT HOLDS OVER. Closed entries are
# exactly the ones ledger-reverify already skips, so rotating them must not change WHICH ROWS it
# emits: the row SET, by status and subject, is identical before and after. Run ledger-reverify.sh
# before and after and compare that projection — that is the acceptance test, and the fixture
# asserts it. The default (no --apply) writes nothing, so the comparison is free.
#
# THE ROW SET, NOT A ROW COUNT, AND NOT THE BYTES EITHER. A count lets a swept entry hide behind a
# duplicate. The bytes are a stricter test than the invariant needs, and until the counter below
# was corrected they false-failed on the very workflow this script is the second half of.
#
# THE COUNTER IS COUNTED OVER THE CORPUS, AND THAT IS WHAT MAKES THE ROW SET INVARIANT.
# `prefix_entry_count()` in ledger-reverify.sh counts a sprint prefix over every entry line in
# BOTH files, open or closed. Annotating an entry moves nothing between the files and rotating it
# moves it from one to the other, so the count cannot change at either step. It used to be OPEN
# entries unioned with ARCHIVED labels: an entry annotated in the same pass — which is exactly what
# the annotate-then-rotate step prescribes — was on NEITHER side while it sat in the live file and
# on the archive side once moved, so the count DIPPED at the annotate and RETURNED at the rotate.
# On a prefix with more than two members that surfaced as a changed count on an identical row; on a
# prefix with exactly two, one annotated, the dip reached ONE and the surviving sibling's row
# crossed between `NAMED-UPSTREAM <slug>` and `NAMED-UPSTREAM-AMBIGUOUS <prefix>` — a changed row
# SET, by status and subject, on a rotation that swept nothing. The reference consumer reported the
# second shape from its own ledger with 89 rows either side
# (PC-S337-ROTATE-ACCEPTANCE-TEST-FALSE-FAILS-WHEN-A-PREFIX-CROSSES-THE-ONE-VS-MANY-THRESHOLD).
#
# THE ARCHIVE ARM STAYS, AND DELETING IT WOULD BE A REGRESSION. Without it the count was
# ANTI-MONOTONIC, every rotation lowering it and converting a correct AMBIGUOUS into a confidently
# wrong single attribution. The corpus count is that fix carried one step further, in the same
# direction: strictly fewer attributions, never more.
#
# A WIDENING OF THIS COUNTER WAS ONCE MEASURED ON THE REFERENCE CONSUMER AT REST AND REJECTED FOR
# FLIPPING ZERO VERDICTS. The defect is a TRANSIENT — it exists only between the annotate and the
# rotate — and a ledger at rest has no annotated-but-unrotated entry to show it. The consumer's own
# diff, taken across a live rotation, is what a rest-state census could not see.
#
# Usage:
#   ledger-rotate.sh <ledger-path> [--archive <path>] [--apply]
#     default          report what WOULD move; write nothing
#     --apply          rewrite the ledger and append to the archive
#     --archive PATH   default: <ledger-dir>/push-candidate-ledger.archive.md
#
# Exit: 0 = reported or rotated (0 closed entries is a normal, affirmative result)
#       1 = refused: an integrity check failed and nothing was written
#       2 = usage
set -uo pipefail

# ledger_entry_shape() — THE entry-boundary rule, from lib.sh. This block used to carry its own
# copy, "lifted from ledger-reverify's parser unchanged"; within one release the label rule in
# it had already drifted. There is one boundary now.
SELF="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
. "$SELF/lib.sh" || { echo "ledger-rotate: cannot source $SELF/lib.sh" >&2; exit 1; }

# COMPUTED ONCE AND GUARDED, BECAUSE A REFUSAL MUST NOT BE SURVIVABLE. `ledger_close_awk` refuses
# when the close grammar is missing from ledger-reverify.sh, or no longer single-homed there.
# Interpolated straight into an awk program that refusal became an EMPTY string, awk then died on
# an undefined function, and this script exited 0 having emitted no rows -- a silent clean run,
# byte-indistinguishable from a corpus with nothing in it. MEASURED before this guard existed:
# rc=0 with 0 rows on the refusal path, against rc=0 with 1 row when the lift resolves.
CLOSE_AWK="$(ledger_close_awk)" || exit 2
CLOSE_AWK="${CLOSE_AWK}
$(ledger_entry_line_close_awk)" || exit 2
# AND THE ARCHIVE GRAMMAR, DERIVED FROM THE SAME SINGLE HOME. This file used to hand-write the
# rule that decides a MOVE — the literal `**ADOPTED UPSTREAM (v[0-9]`, at three sites — beside a
# skip rule it lifted. So the two lists could differ, and they did: this file contained the token
# `WITHDRAWN` ZERO times while the lifted skip rule honoured it, and an entry closed that way was
# skipped by every re-verification AND refused by every rotation. `ledger_archive_awk` makes the
# skip grammar`s optional bold span mandatory and changes nothing else, so this file no longer
# has a membership opinion of its own and a fourth close token cannot reach one tool alone.
CLOSE_AWK="${CLOSE_AWK}
$(ledger_archive_awk)" || exit 2

LEDGER="${1:-}"
[ -n "$LEDGER" ] || { echo "usage: ledger-rotate.sh <ledger-path> [--archive <path>] [--apply]" >&2; exit 2; }
[ -f "$LEDGER" ] || { echo "ledger-rotate: no ledger at '$LEDGER' — nothing to rotate." >&2; exit 0; }
shift

APPLY=0
ARCHIVE="$(dirname "$LEDGER")/push-candidate-ledger.archive.md"
while [ $# -gt 0 ]; do
  case "$1" in
    --apply)   APPLY=1; shift ;;
    --archive) ARCHIVE="${2:?--archive needs a path}"; shift 2 ;;
    *) echo "ledger-rotate: unknown argument '$1'" >&2; exit 2 ;;
  esac
done

TMPD="$(mktemp -d)" || { echo "ledger-rotate: mktemp failed" >&2; exit 1; }
trap 'rm -rf "$TMPD"' EXIT

# --- REFUSE TO ROTATE A LEDGER THE BOUNDARY RULE WOULD SPLIT ------------------------------
# THE DEFECT. `ledger_entry_shape()` opens an entry on ANY line-leading `- **`, so an
# ANNOTATION written in that shape inside a CLOSED entry ends it. The head is archived and the
# tail -- including the entry`s verify: receipt -- is stranded in the live ledger under no
# heading. Observed on `PC-S296-WHOLE-READ-POOL`: the archived copy ended mid-sentence and the
# receipt sat 170 lines below an unrelated entry. Driven behaviourally against this script,
# two ledgers byte-identical but for one bullet`s indentation: the column-0 bullet puts HEAD in
# the archive and TAIL in the live file, the indented one rotates the entry whole.
#
# THE EXISTING INTEGRITY CHECK CANNOT SEE THIS AND THAT IS STRUCTURAL, NOT AN OVERSIGHT. The
# `kept + moved != total` arm below is LINE accounting, and a split conserves every line -- the
# two halves simply land on opposite sides. Every conservation predicate over the SAME parse is
# blind the same way, because the parse is the thing that is wrong.
#
# WHY A DETECTOR AND NOT A PARSER FIX, WHICH IS THE SAME ANSWER `scripts/backlog-rotate.sh`
# REACHED FOR THE FENCE CASE. An annotation lead-in and an entry title are
# byte-indistinguishable, so no boundary rule can separate them. The two cheap discriminators
# were measured and both fail: requiring a `PC-` id makes the rotator stop seeing every legacy
# id-less entry, which is silent non-archival rather than a visible refusal, and requiring a
# `verify:` receipt fails for the same corpus. `ledger-entry-boundary-measurement.md`, the
# distribution`s own analysis note, asks whether an explicit terminator could carry it instead:
# measured on the reference consumer, the live ledger holds 96 boundary-shaped lines against 50
# `---` separators and the archive 142 against 70, so `---` does not separate all entries and
# that route is closed on this corpus.
#
# REFUSING IS THE CORRECT FAILURE HERE, AND THIS REPO NORMALLY PREFERS PENDING TO FAIL. Not on
# this one: the alternative to stopping is irreversible loss of the tail of a real entry, and
# the remedy is a one-line edit to the offending ledger -- indent the annotation so it does not
# start a line, or drop its bold. Cheap to satisfy, unrecoverable to skip.
#
# KEYED ON THE HARM, NOT ON THE SHAPE, AND THE FIRST CUT GOT THIS WRONG IN THE WAY THE
# ANALYSIS FILE PREDICTS. Keying on shape alone -- any non-id boundary inside a closed id-keyed
# entry -- reads a REAL prose-titled entry that merely FOLLOWS a closed one as an annotation,
# and wedges a rotation that would have been correct. `core/fixtures/ledger-rotate/seed.sh`
# carries exactly that adjacency: `- **Entry STUCK is closed for re-verification and`
# `unarchivable.**` sits right after the closed `PC-CLOSED-BULLET`, and the shape-keyed form
# refused it. That fixture found the false positive the reference-consumer corpus did not
# contain.
#
# So the predicate is the DAMAGE. A split only loses something when the closed entry`s receipt
# ends up on the far side of the offending line, so all three of these must hold: the boundary
# is non-id and sits inside a CLOSED id-keyed entry; it carries NO close annotation of its own,
# which a real entry closed in its own right does; and a `verify:` receipt follows it before
# the next id-keyed boundary. When those hold, the receipt is either the closed entry`s --
# about to be stranded -- or the new entry`s, and NOTHING can tell which. That is exactly the
# state in which refusing is the right answer rather than a guess.
#
# `ledger_entry_id()` is the shared, single-homed id rule from lib.sh -- the same one
# `ledger-reverify.sh`s ENTRY-SWALLOWED arm reads, so the two tools cannot drift about what an
# id is. The close test is `ledger_body_archives()` -- rotation`s ARCHIVE grammar, the one that
# decides the move -- and not reverify`s looser skip rule, because the loose form matches an
# entry that merely QUOTES the phrase. IT MUST BE THE ARCHIVE RULE AND NOT A THIRD FORM: this
# guard only has a subject where rotation can actually move the entry, so a close test narrower
# than the move goes blind on exactly the entries the move newly reaches. Hand-written as the
# old `(v[0-9]` literal it could not see a withdrawal at all, and an entry closed that way would
# have been split with no refusal.
#
# FALSE-POSITIVE SET, MEASURED BEFORE SHIPPING AND ENUMERATED RATHER THAN ASSERTED. Over this
# guard`s ACTUAL POPULATION -- the files a rotation reads, which are LIVE ledgers -- it reports
# ZERO: nothing on the reference consumer`s live ledger, and nothing on the distribution`s own
# backlog or its archive. It fires on the reproduction above and stays silent on the
# indented near-miss, with the two inputs asserted byte-different first.
#
# THE CONSUMER`S OWN ARCHIVE REPORTS 22, AND THAT IS STATED RATHER THAN ROUNDED AWAY. An
# archive is a rotation OUTPUT and never an input, so those 22 gate nothing and no run reaches
# them. They are NOT adjudicated here: each is a boundary-shaped line inside a closed entry, and
# whether a given one is an annotation or a real legacy id-less entry is the same question this
# whole guard exists BECAUSE nothing can answer. Reporting the number without the adjudication
# is the honest form; calling it zero because it does not gate anything would not be.
SPLIT_FINDINGS="$(LC_ALL=C awk "$(ledger_entry_awk)$(ledger_entry_id_awk)${CLOSE_AWK}"'
  function label_of(l,   line, shape) {
    shape = ledger_entry_shape(l)
    if (shape == "") return "\001"
    line = l
    if (shape == "heading") { sub(/^#{2,6}[ \t]+/, "", line) }
    else                    { sub(/^- \*\*/, "", line); sub(/\*\*.*$/, "", line) }
    return line
  }
  function report() {
    if (susp_at && !susp_closed && !entry_hasv && (susp_colon || susp_hasv))
      printf "  line %d: `%s` sits inside the CLOSED entry `%s` opened at line %d, carries no close annotation of its own, and a verify: receipt follows it at line %d -- rotation would archive that entry head and strand the receipt in the live ledger under no heading\n", susp_at, substr(susp_lab, 1, 55), substr(entry_lab, 1, 55), entry_at, susp_v_at
    susp_at = 0; susp_closed = 0; susp_hasv = 0
  }
  {
    lab = label_of($0)
    if (lab != "\001") {
      if (ledger_entry_id(lab) != "") { report(); entry_at = NR; entry_lab = lab; closed = 0; entry_hasv = 0; next }
      report()
      if (entry_at && closed) {
        susp_at = NR; susp_lab = lab; susp_colon = (lab ~ /:$/)
        # THE CLOSE MAY SIT IN THE BOUNDARY LINE`S OWN BOLD SPAN. The legacy id-less form
        # writes it there -- `- **`validate-ci-gates.sh` -> ADOPTED UPSTREAM (v0.135.0).**` --
        # so a close test that only reads the lines BELOW never sees it and the guard refuses a
        # real entry. Read the line itself as well.
        # THE SUPPRESSORS STAY LOOSE AND BECOME TOKEN-COMPLETE. `ledger_entry_line_closes()` is
        # reverify`s own UNANCHORED entry-line rule, which is the loose form this site has always
        # wanted -- what it did not have was the whole token set, so a suspect line closed as
        # WITHDRAWN suppressed nothing and the guard refused a real entry. Lifting the rule keeps
        # the looseness the measurement below prescribes and removes the membership opinion.
        if (ledger_entry_line_closes($0)) susp_closed = 1
      }
      next
    }
    # THE GUARD MUST SEE EVERY ENTRY ROTATION CAN MOVE, OR IT GOES BLIND ON EXACTLY THE ENTRIES
    # THIS CHANGE NEWLY MOVES. This test decides whether an entry is CLOSED, which is what makes a
    # non-id boundary inside it a refusal candidate at all. Hand-written as the strict `(v[0-9]`
    # literal it could not see a withdrawal, so an entry that is now archivable would have been
    # split with no refusal -- the one outcome this guard exists to prevent. It is the same
    # grammar the move below uses, from the same single home.
    if (ledger_body_archives($0) && !susp_at) closed = 1
    # DELIBERATELY NOT THE LIFTED PREDICATE, AND THE MEASUREMENT IS WHY. This one and the stuck
    # rule below ask a similar question and FAIL IN OPPOSITE DIRECTIONS, so one rule cannot serve
    # both. The stuck rule makes a CLAIM -- these are the entries reverify skips -- so a loose
    # form states something false about an open entry. This one SUPPRESSES a refusal, so a loose
    # form only lets a split through, while a TIGHT form refuses a real entry and writes nothing.
    #
    # ROUTING THIS THROUGH ledger_body_closes() WAS BUILT AND MEASURED, AND IT WEDGES ROTATION.
    # Driven on the false-positive case the fixture already carries: a real entry whose body says
    # "Annotate it `ADOPTED UPSTREAM (vX.Y.Z...)` once the grep is non-zero", sitting under a
    # genuinely closed entry. Unanchored, rc=0 and no refusal; anchored, rc=1 and REFUSING TO
    # ROTATE -- a false positive on a real entry, and refusal writes nothing at all. The stuck
    # report is fixed either way: 5 rows on the reference consumer under both.
    #
    # THE MISSED-REFUSAL DIRECTION IS STILL REAL AND IS FILED RATHER THAN GUESSED AT. A mention
    # can still silence this guard. Closing that without re-opening the false positive needs a
    # predicate that is neither of these two, and it needs its own false-positive measurement
    # against the consumer archive, where 22 boundary-shaped lines inside closed entries all
    # escape refusal on a single clause today.
    if (ledger_entry_line_closes($0) && susp_at) susp_closed = 1
    if ($0 ~ /^[ \t]*(<br[ \t]*\/?[ \t]*>)?[ \t]*[-*]?[ \t]*`?verify:/) {
      # A receipt ABOVE the suspect line is already on the archive side, so nothing of this
      # entry`s receipt can be stranded by the split and there is nothing to refuse.
      if (susp_at) { if (!susp_hasv) { susp_hasv = 1; susp_v_at = NR } }
      else if (entry_at)             { entry_hasv = 1 }
    }
  }
  END { report() }
' "$LEDGER")"
if [ -n "$SPLIT_FINDINGS" ]; then
  echo "ledger-rotate: REFUSING to rotate $LEDGER — the entry-boundary rule would split a closed entry." >&2
  printf '%s\n' "$SPLIT_FINDINGS" >&2
  echo "  If the reported line is an ANNOTATION, re-indent it so it does not start a line, or drop" >&2
  echo "  its bold. If it is a real ENTRY, that advice would destroy it — give it its own close" >&2
  echo "  annotation, or an entry id, so the two stop being indistinguishable. This refuses" >&2
  echo "  precisely because nothing here can tell which one it is." >&2
  echo "  Nothing written." >&2
  exit 1
fi

# Split the ledger into KEEP and MOVE by the same boundary + closed rules ledger-reverify
# uses. Everything before the first entry boundary is the file's preamble and always stays
# (`started` stays 0 until the first boundary, and only `started && closed` moves).
# Append (`>>`) into pre-created files: awk's `>` truncates on first write per target, which
# would drop every entry but the last.
rm -f "$TMPD/keep" "$TMPD/move" "$TMPD/moved-names" "$TMPD/stuck-names"
: > "$TMPD/keep"; : > "$TMPD/move"; : > "$TMPD/moved-names"; : > "$TMPD/stuck-names"
awk -v keep="$TMPD/keep" -v move="$TMPD/move" -v names="$TMPD/moved-names" -v stuck="$TMPD/stuck-names" "$(ledger_entry_awk)${CLOSE_AWK}"'
  function flush(  i) {
    if (n == 0) return
    out = (started && closed) ? move : keep
    for (i = 1; i <= n; i++) print buf[i] >> out
    if (started && closed) print label >> names
    # THE ENTRIES NEITHER RULE TAKES. `ledger-reverify.sh` skips on a line-leading marker with an
    # OPTIONAL bold span; this file archives on the same grammar with that span MANDATORY. The
    # asymmetry is deliberate and its stated cost is that "an entry wrongly kept costs one more
    # pull to notice" -- but NOTHING NOTICED, because nothing reported the gap. An entry in it is
    # skipped by every re-verification AND refused by every rotation: invisible in the report
    # and never filed, for as long as the ledger lives.
    #
    # THIS SET IS NOW BOUNDED BY THE TRANSFORM AND CANNOT GROW BY DISAGREEMENT. It used to hold
    # everything the two files SPELLED differently -- the whole `WITHDRAWN` class, permanently.
    # What can land here now is only what the two forms of ONE grammar separate: a close written
    # without a bold span. That is a repairable annotation, which is what the remedy below asks
    # for, rather than a token this file never heard of.
    if (started && !closed && loose) print label >> stuck
    n = 0; closed = 0; loose = 0; label = ""
  }
  # NOT TRUNCATED. This label is what the run prints as `moved-names` — the record of which
  # entries left the live ledger. Clipping it to 70 characters, as this did, produced a name the
  # operator cannot grep back into either file. Same clip, same reason, as the one removed from
  # ledger-reverify.sh. The em-dash split stays reverify-only: unifying the two label rules
  # changes this output, which lib.sh records as a separate call.
  function open_entry(l) {
    flush(); started = 1
    sub(/^[-#][ \t]*/, "", l); gsub(/\*\*/, "", l); gsub(/`/, "", l)
    sub(/[[:space:]]+$/, "", l); label = l
  }
  # THE OPENING LINE MUST BE TESTED TOO, AND THIS `next` IS WHY IT WAS NOT.
  #
  # A close annotation sitting on the entry`s OWN boundary line was invisible to every rule
  # below: `next` skips the archive test, the lifted loose test, and the retained-copy test
  # alike. `flush()` then evaluated `started && !closed && loose` as false, and the entry went
  # to `keep` -- ARCHIVED BY NOTHING AND REPORTED BY NOTHING. That is the state the stuck list
  # was added to eliminate, surviving in the one shape the stuck list could not see.
  #
  # THE SPLIT GUARD ABOVE ALREADY READS THE BOUNDARY LINE, and its comment names the legacy
  # id-less form that writes a close there. So the shape was understood and the fix landed on
  # one of the two predicates; this is the other one.
  #
  # MEASURED, one variable changed, strict form, bullet shape preserved on both sides:
  #   close ON the boundary line     before: 0 would move   after: 1 would move
  #   same close one line INTO body  before: 1 would move   after: 1 would move
  # The body path is unchanged, which is what says this widened the subject rather than the rule.
  #
  # BOTH FLAGS, NOT JUST `closed`. Setting only the archive flag would leave a boundary-line
  # close carrying NO version invisible in both directions instead of becoming a correctly
  # reported stuck row -- fixing the loud half and leaving the quiet half exactly as it was.
  #
  # ORDER MATTERS: `open_entry()` calls `flush()` first, which zeroes both flags for the
  # entry that just ended. Setting them AFTER that call is what attaches them to the entry
  # this line OPENS rather than to the one it closes.
  #
  # THE COUNT OF AFFECTED ENTRIES CANNOT BE READ OFF STUCK COUNTS. An entry in this shape
  # appears in the stuck list only when some UNRELATED body line happens to match the loose
  # rule, so every such count is a lower bound biased downward by a coincidence that has
  # nothing to do with the property being counted. Measured on the reference consumer: its one
  # instance was visible only because a neighbouring sub-bullet`s own annotation sat five lines
  # inside its span.
  { if (ledger_entry_shape($0) != "") { open_entry($0); buf[++n] = $0
      # THE ENTRY-LINE ARCHIVE RULE, NOT THE BODY ONE. A close on a boundary line sits MID-LINE
      # after the title (`## PC-FOO -- **WITHDRAWN ...**`), so the body rule`s line-leading anchor
      # can never match here and would answer "not closed" for every entry line ever passed to it
      # -- inert rather than merely wrong. `ledger_archive_awk` emits both for that reason.
      if (ledger_entry_line_archives($0)) closed = 1
      if (ledger_entry_line_closes($0)) loose = 1
      next } }
  # THE BOLD SPAN IS WHAT SEPARATES AN ANNOTATION FROM A MENTION, AND IT CARRIES BOTH OF THE
  # FIXES THE RETIRED `(v<digit>` LITERAL USED TO CARRY.
  #
  # NO APOSTROPHES IN THIS COMMENT, AND THAT IS NOT STYLE. This awk program sits inside a shell
  # single-quoted string, so one apostrophe here closes the quote and the whole block becomes
  # shell words -- which is exactly how the first draft of this comment failed.
  #
  # DEFECT 1 (PC-S331): THE OLD PATTERN ARCHIVED A LIVE ENTRY BECAUSE THE ENTRY QUOTED IT.
  # The test is per-ENTRY, over every buffered line, so any line anywhere in a body decides the
  # verdict -- and a push candidate ABOUT this script naturally writes the form it describes.
  # Reproduced on the reference consumer: --apply archived PC-S330, a live entry, on a line
  # reading  `**ADOPTED UPSTREAM (v` annotation is a real close.  The entry was matched against
  # its own quotation of the rule, and the operator caught it only because the acceptance test
  # this script prescribes made the disappearance visible. A swept entry drops a ROW, so the
  # row-set form above catches it for the same reason the byte form did, without the false alarm.
  # THE DERIVED GRAMMAR REFUSES THAT LINE TOO, AND BY A DIFFERENT PROPERTY: it is anchored
  # line-leading, and the no-backtick run `[^`]*` between the bold opener and the token means a
  # code span before the words is a mention even when the bold happens to lead. An annotation
  # never quotes itself. Both halves of that come from reverify`s own grammar, where they were
  # derived from every occurrence on this same corpus.
  #
  # SKIPPING FENCES IS THE OBVIOUS FIX AND IT IS THE WRONG ONE -- measured, because the report
  # said the quotation was fenced and it is not. Four quotation forms were tried against a
  # seeded ledger: fenced-with-the-awk-regex does NOT match (the escaped form is not the
  # literal), while INLINE BACKTICKS and BARE PROSE both do. The live case is inline. A
  # fence-skipping fix would have shipped green and left the real defect untouched.
  # (That is about the CLOSE predicate. The BOUNDARY rule in lib.sh IS fence-aware now, for
  # PC-S308-LEDGER-REVERIFY-ENTRY-BOUNDARY-IGNORES-FENCED-HEADINGS: a fenced `## <ts>` line no
  # longer opens an entry, so a closed entry carrying one rotates whole instead of in pieces.)
  #
  # DEFECT 2 WAS NEVER A DEFECT, AND CORRECTING IT COST MORE THAN IT SAVED. The old literal`s
  # `\(v` also matched `(verified`, so an entry annotated  **ADOPTED UPSTREAM (verified
  # 2026-07-21).**  satisfied a rule whose banner promised a version. The digit anchor turned
  # that into a stuck row -- and a close carrying no version is a GENUINE close, not a
  # malformed one. Demanding a digit left the operator two exits on every withdrawal and every
  # pre-base absorption: leave the entry live forever, or write a version that is not true.
  # This grammar asks for the FORM and says nothing about the parenthetical, so that entry
  # archives on its own terms. The stuck report below is correspondingly narrower: what reaches
  # it now is a close written with no bold span at all, which is a repairable annotation.
  #
  # FALSE-NEGATIVE SET MEASURED BEFORE SHIPPING, against the reference consumer`s archive of
  # genuine closes AND its live ledger, in one invocation: the lines the OLD literal takes that
  # this grammar does NOT number ZERO in both files, on boundary lines and bodies alike, so
  # nothing that archived before stops archiving. Going the other way it takes one more line on
  # the live file -- a real withdrawal this repo`s vocabulary already honoured -- and the same
  # 14 boundary closes on the archive. Impossible-token control 0 on both.
  ledger_body_archives($0) { closed = 1 }
  # THE SKIP SIDE OF THE SAME QUESTION, LIFTED FROM reverify RATHER THAN RESTATED.
  #
  # NO APOSTROPHES IN THIS COMMENT EITHER, for the reason stated above it.
  #
  # This used to read an UNANCHORED phrase test matching anywhere on any body line, and the
  # comment above it attributed that to entry_line_closes(). Two things were wrong.
  # entry_line_closes() is applied to the ENTRY LINE and not to the body, so the citation named a
  # mechanism that decides a different question; and the body rule it should have named is
  # ANCHORED, because the ledger is prose that DISCUSSES closes as well as carrying them.
  # MEASURED on the reference consumer: this report named 12 entries and 7 of them were OPEN,
  # one of them being the entry that filed this defect. ledger_body_closes() is the reverify line
  # itself, read out of that file at load time, so the two cannot drift apart again.
  ledger_body_closes($0) { loose = 1 }
  # The retained-copy parenthetical stays LOCAL and stays unanchored. It is not part of the
  # reverify BODY rule at all -- reverify closes that shape on the ENTRY LINE, through
  # entry_line_closes() -- and it is a parenthetical that legitimately sits mid-line in a heading.
  /\(original text, retained for the record\)/ { loose = 1 }
                     { buf[++n] = $0 }
  END { flush() }
' "$LEDGER"

# NO `|| echo 0` FALLBACK, and none is needed: `moved-names` is pre-created above, so the only
# question is whether it is empty. `grep -c` PRINTS `0` on no match and ALSO exits 1, so a
# fallback fires on exactly the case it was meant to cover and makes this the two-line string
# `0\n0`. `[ "$n_move" -eq 0 ]` below then errors with `integer expression expected` and
# evaluates FALSE, so the nothing-to-rotate early exit never fires on the nothing-to-rotate
# case — the report contradicts itself and `--apply` creates a header-only archive the run had
# no reason to write.
n_move="$(grep -c . "$TMPD/moved-names")"
n_stuck="$(grep -c . "$TMPD/stuck-names")"

# REPORTED WHETHER OR NOT ANYTHING MOVES, and before the nothing-to-rotate exit below, because
# the nothing-to-rotate case is exactly where this hides. Measured on the reference consumer at
# 0.329.0: rotate printed "0 closed entries -- nothing to rotate" while ELEVEN entries sat
# closed-and-unarchivable, one of them annotated `**ADOPTED UPSTREAM (absorbed before base
# <sha>, verified <date>)` -- a real, deliberate, bolded close that the then-strict `(v` refused
# because the parenthetical does not start with a version.
#
# THAT ENTRY NOW ARCHIVES, AND THIS REPORT IS CORRESPONDINGLY NARROWER. The archive grammar is
# derived from the skip grammar and asks for the annotation FORM rather than for a version, so a
# genuine close carrying none is no longer stuck. Archiving live work is still the expensive
# error and the rule is still the stricter of the two -- what left the set is the class that
# could never leave it by any annotation, not the caution.
#
# THIS REPORT DOES NOT RETIRE WITH ITS LARGEST CLASS, and it must not. The two grammars still
# differ by one property, so a close written with no bold span at all still lands here, and the
# remedy below is now something the operator can actually satisfy.
if [ "$n_stuck" -gt 0 ]; then
  echo "ledger-rotate: ${n_stuck} entry(ies) are CLOSED for re-verification but NOT archivable."
  # THIS BANNER USED TO DESCRIBE THE STATE IT FIXES, IN THE PRESENT TENSE, INSIDE ITS OWN
  # OUTPUT. It read "they never appear in a report again ... they are never filed" -- printed
  # by the report that files them, two lines above the sentence saying the row IS the record.
  # A reader who stopped at the first sentence concluded the state was unhandled and the
  # prescribed remedy was the only exit. Measured: that is exactly what a consumer session did,
  # and it produced an upstream request to add annotation spellings for a case already named
  # two lines below. The rows below are the filing; say so where the reader is.
  echo "  ledger-reverify.sh skips them and this script refuses them, so THIS ROW is the only"
  echo "  place they appear. They stay in the live ledger and are re-reported every run."
  echo "  To archive one, write the close as a BOLD ANNOTATION on its own line, or in the bold"
  echo "  span of the entry title:  **ADOPTED UPSTREAM (v<version>, verified <date>)**"
  echo "  NO VERSION IS REQUIRED. A close that genuinely has none archives on its own terms —"
  echo "  **WITHDRAWN (<date>) — <why>**,  **ADOPTED UPSTREAM (absorbed before base <sha>)**,"
  echo "  **CLOSED AS REJECTED — BY DESIGN, adjudicated <date>**  are all accepted forms."
  echo "  Do not invent a version to satisfy this script; the bold span is what it reads."
  sed 's|^|    |' "$TMPD/stuck-names"
fi
l_all="$(wc -l < "$LEDGER" | tr -d ' ')"
l_keep="$(wc -l < "$TMPD/keep" | tr -d ' ')"
l_move="$(wc -l < "$TMPD/move" | tr -d ' ')"

# INTEGRITY: every line is in exactly one output. A rotation that drops a line is worse than
# no rotation at all, so this refuses rather than reports.
if [ "$(( l_keep + l_move ))" -ne "$l_all" ]; then
  echo "ledger-rotate: REFUSED — line accounting does not balance (${l_keep} kept + ${l_move} moved != ${l_all} total). Nothing written." >&2
  exit 1
fi

if [ "$n_move" -eq 0 ]; then
  echo "ledger-rotate: 0 closed entries — nothing to rotate (${l_all} lines stay)."
  exit 0
fi

if [ "$APPLY" -eq 0 ]; then
  echo "ledger-rotate: ${n_move} closed entries would move (${l_move} of ${l_all} lines, leaving ${l_keep})."
  sed 's/^/  /' "$TMPD/moved-names"
  echo "  archive: ${ARCHIVE}"
  echo "  re-run with --apply to write. Verify after: ledger-reverify.sh must emit the SAME ROW SET,"
  echo "  by status and subject (cut -f1,2 | sort). Prefix counts inside NAMED-UPSTREAM-AMBIGUOUS details"
  echo "  are taken over both files and do not move. A row that appears, disappears, or changes status"
  echo "  — NAMED-UPSTREAM <slug> becoming NAMED-UPSTREAM-AMBIGUOUS <prefix> included — means a sweep: STOP."
  exit 0
fi

if [ ! -f "$ARCHIVE" ]; then
  {
    echo "# Push-candidate ledger — archive"
    echo
    echo "Entries closed against upstream, rotated out of the live ledger by"
    echo "\`reconcile/ledger-rotate.sh\`. Nothing here is re-verified: an entry is archived"
    echo "only once \`ledger-reverify.sh\` already skips it. This file is provenance, not a"
    echo "worklist. Never hand-edit an entry back into the live ledger — re-file it."
    echo
  } > "$ARCHIVE"
fi
cat "$TMPD/move" >> "$ARCHIVE"
cat "$TMPD/keep" > "$LEDGER"

echo "ledger-rotate: moved ${n_move} closed entries (${l_move} lines) to ${ARCHIVE}; ledger is now ${l_keep} lines."
sed 's/^/  /' "$TMPD/moved-names"
