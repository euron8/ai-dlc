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
# SPRINT is spliced into the span regex below, so a non-digit value is a regex, not a sprint:
# `--sprint '.*'` and `--sprint '5|'` each verified a sprint=5 line. Refused here, once.
case "$SPRINT" in
  *[!0-9]*) echo "FAIL: --sprint takes a sprint NUMBER (digits only), got: $SPRINT" >&2; exit 1 ;;
esac

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
# ONE GRAMMAR, THREE SITES. The two --verify arms below and the citation all build
# from ATTEST_LEAD and ATTEST_TAIL through one judge function, and the locating arm
# from ATTEST_LOCATE. Three hand-written anchors is three chances to widen one
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
# only in what precedes one byte-identical attestation: under that `^` anchor column 1
# exited 0, and a table cell, a backtick wrap, a `- ` bullet and a four-space indent all
# exited 1. (A four-space indent is an indented CODE BLOCK and is now refused by the block
# context in the reader, with fences and HTML comment blocks.)
# Under a token boundary all five exit 0 — but a token boundary does not read
# what PRECEDES the span, so failure words before it were granted. The closed lead at
# the end of this block is what closed that.
#
# WHY NOT A BARE SUBSTRING EITHER. Dropping the anchor makes `XH2_ATTESTED` and
# `NOT_H2_ATTESTED` count, so a line that DENIES an attestation grants one. The
# grammar is therefore a TOKEN boundary for GRANTING: the closed lead admits no letter
# before the span. The LOCATING boundary is `[^0-9A-Za-z]` rather than `\b`, because this
# expression is also what a reader copies into a `git grep -E`, where `\b` returns a clean
# zero; it omits `_` so `_SPAN_` and `NOT_H2_ATTESTED` are located, never first-gate.
#
# A BACKTICK MUST NOT BE INTERPOLATED INTO A DOUBLE-QUOTED STRING. When these grammars
# were `grep -qE "…"` arguments, an unescaped backtick opened command substitution and
# `bash -n` on the file exited 2, so they were spelled without one. They now reach the
# reader only through the environment of a single-quoted awk program, which is what lets
# the closed decoration sets name the backtick literally. Keep it that way.
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
# by --attest be followed by closing decoration only — backticks, periods, asterisks, spaces —
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
#
# OPTIONAL IS NOT OPEN, THOUGH: the `mechanical=` value is pinned to the one --attest emits,
# `check-17-bypass:PASS`. Under an open value class a column-1 line ending
# `mechanical=check-17-bypass:FAIL` verified — the line recording that the mechanical item
# FAILED granted the attestation. A pinned value leaves `:FAIL` for the tail to refuse, so
# the line is LOCATED, never granted. The consumer's spans carry `:PASS` on every one.
#
# WHY THE READER IS NOT WIDENED TO ADMIT A BULLET. A consumer transcribed the line into a
# markdown bullet, `- [core] H2 — … → \`SPAN\`; item 1 recursion guard fires …`, and
# --verify refused it. Every tail that admits that bullet also admits a FAIL sentence in
# the same shape, because the verdict lives in the prose after the span and no grammar
# adjudicates prose. Measured against six adversarial FAIL lines, each quoting a live span
# at the correct sprint and digest:
#
#   backtick, then anything            grants 5 of 6, including the sprint-311 sentence
#   backtick, then `;` or a dash       grants 4 of 6
#   backtick, then a `;` separator     grants 3 of 6
#   bare substring (no tail)           grants 5 of 6
#   the shipped cell-bounded tail      grants 0 of 6, and refuses the consumer's bullet
#
# One of the three granted by the `;` form reads "`SPAN`; item 3 manifest-bypass seed
# PASSED H1 — H2 FAILS, do not cite." SO THE READER REFUSES AND LOCATES INSTEAD. The third
# --verify arm below matches ATTEST_LOCATE and the ANY-digest span WITHOUT the tail,
# grants nothing, and names `<gate-log>:<line>` of the last quoted span, so the operator
# is told which line to replace rather than that the sprint never attested. It is keyed on
# ATTEST_ANY, never ATTEST_SPAN: keyed on the exact digest, a quoted span at a MOVED digest
# would fall through to "this is the sprint's first gate", the wrong message again.
#
# AND THE LEAD WAS STILL UNBOUNDED, SO A FAILED ROW VERIFIED. The tail above was
# cell-bounded; the lead was only a token boundary, so nothing BEFORE the span was read.
# Five shapes at the live sprint and digest exited 0: a FAIL verdict in an earlier cell,
# in a later cell, in the row label (`H2 (INVALID, do not cite)`), prose before the span
# in its own cell, and `H2 FAILED, re-drive owed: SPAN` as plain prose ending the line.
# The fix has two halves and both are CLOSED sets, never negated classes.
#
# PLACEMENT. The span must stand alone on its line, or alone in its table cell, with
# decoration from a closed set on each side: ATTEST_LEAD admits spaces, one `- ` bullet,
# `**` and one backtick; ATTEST_TAIL admits one backtick, `**`, one period and spaces.
# The earlier tail was the NEGATED class "not a word character, not a pipe", and a negated
# class mirrored onto the lead grants whatever glyph a transcriber uses to say NO: `❌`
# and `✗` before the span, `~~` strike-through around it, `<!-- -->` commenting it out,
# `> ` quoting it and `--` all passed it. A closed set refuses every one of them without
# having to name any.
#
# VERDICT. A span in a table row is accepted only when the table's header row — the row
# directly above its `|---|` separator — names a Result, Verdict, Status or Outcome
# column, and EVERY such cell in the row reads, whole, `PASS` or `PASSED` plus at most one
# parenthetical and a period, after `*`, `_`, backtick and space decoration (PASS, PASSED,
# `**PASS (…)**`), with no FAIL or revocation word in the parenthetical. A row in a table
# with no header, or a header naming no such column, or a verdict cell that is `—`, VOIDED,
# FAIL, `PASS/FAIL`, `PASS (FAILED on re-drive)`, or a second verdict column reading FAIL, is
# refused. Measured over every revision of every consumer file carrying a span: 4 table rows
# are ever granted, each verdict cell exactly `PASS`, so the whole-cell grammar refuses none.
# A span alone on its own line is not in a row and needs no verdict column.
#
# BLOCK CONTEXT AND REVOCATION. A span inside a fenced code block, an HTML comment block or an
# indented code block (four spaces or a tab before the line) is refused and located. A LATER
# line carrying the live span with VOID, REVOKE, RETRACT, SUPERSEDE or INVALID withdraws an
# earlier grant (REVOKED, naming both lines); a later accepted span re-grants. A revoking
# sentence that carries NO span is not read: that shape refused five correct consumer gate
# logs on commentary ("a changed fixture voids the attestation by design").
#
# Measured over 501 distinct consumer blobs carrying the token (every revision of 67 paths),
# 688 forced-digest runs: no verdict changes on any gate-log path. Twenty runs change, all on
# pipeline snapshots and one h2-drive note whose span sits inside a real ``` block.
#
# WHY AN ALLOWLIST AND NOT A FAILURE VOCABULARY. The first design refused a row whose
# other cells carried FAIL, INVALID, REFUSED, RE-DRIVE or "do not cite". Over the
# consumer's history that vocabulary REFUSED A REAL PASS: sprint 289's verdict cell reads
# `**PASS (attested, cite — do not re-drive)**`, and "do not re-drive" is the instruction
# NOT to re-drive, carried by a passing row. A vocabulary also misses VOIDED, SUPERSEDED
# and `❌` by construction — a verdict column is written by whoever writes the log, and a
# list of the words for failure is never finished. The PASS column is one word, and the
# header says which cell it is in.
#
# MEASURED over the same corpus, every revision of every gate-log file, now 31 (sprint,
# digest) pairs. Each pair's log is every distinct gate-log revision carrying it, whole,
# so each row keeps its table header, driven through the REAL script with the digest
# forced. A log of the matching LINES alone strips every header, and this reader then
# also refuses sprint 313, whose every record is a table row — correctly, since a row
# with no header has no verdict column to read:
#
#   token-bounded lead (the previous reader)       31 / 31
#   closed placement, no verdict column           29 / 31
#   closed placement + PASS verdict column        29 / 31   (this reader)
#   column 1 only                                 27 / 31
#
# The two lost are 309 `aab08e34184faa3d` — a PASSED row whose only record carries the span
# AFTER prose in its evidence cell, a pair its own sprint voided and re-attested as a
# span-alone cell — and 312 `0a1a18af49486682`, whose records likewise quote the span
# after prose in the evidence cell. Both are historical. --verify is consulted for the
# CURRENT sprint only, and the consumer's current sprint, 314, verifies under this reader.
# The closed sets cost no pair: the negated-class mirror also scores 29 / 31, and it
# grants all six glyph shapes above where this reader refuses all six.
#
# THE THIRD ARM LOCATES ON ATTEST_LOCATE, THE OLD TOKEN-BOUNDARY LEAD, and states which
# rule refused the span: inside other text, a table row with no header, no verdict
# column, or a verdict that does not begin PASS. It stays loose on purpose — a refused
# span must be named by its line, never reported as the sprint's first gate.
#
# These strings are no longer interpolated into a double-quoted `grep -E` argument; the
# single awk pass reads them from its environment, so the backtick in the closed sets is
# a literal character here and cannot open a command substitution.
# A TAB is decoration exactly where a space is (padding in a cell, after a bullet). A tab or
# four spaces BEFORE a line is not: that line is an indented code block, refused by the block
# context below before these sets are read.
ATTEST_LEAD='[ \t]*(- )?[ \t]*(\*\*)?`?'
ATTEST_TAIL='`?(\*\*)?\.?[ \t]*'
# `_` is NOT a boundary-breaking character here: `_SPAN_` is markdown emphasis, and with `_`
# counted as a word character it was never located and read as the sprint's first gate.
ATTEST_LOCATE='(^|[^0-9A-Za-z])'
# The emitted span, for the tail test and for CITATION. Its optional groups mirror the line
# --attest emits field for field, so a field added there is matched here without being required.
ATTEST_FIELDS='( at=[0-9A-Za-z:-]+)?( items=[0-9,]+)?( mechanical=check-17-bypass:PASS)?'
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
  # ONE PASS, THREE ARMS. The awk program below judges every line carrying a span and
  # prints ONE verdict: `PASS|<span>` (arm 1, this digest, accepted placement), `CHANGED`
  # (arm 2, another digest, accepted placement), `LOCATE|<line>|<reason>` (arm 3, a span
  # the first two refused), or `NONE`. Arms 1 and 2 call the SAME judge with the same
  # ATTEST_LEAD, ATTEST_TAIL and verdict-column test, differing only in the span they are
  # handed, so neither can be narrowed without the other. Arm 3 is keyed on ATTEST_LOCATE
  # and ATTEST_ANY, so ANY refused span is located rather than reported as first-gate.
  # A table row needs the header the judge reads, which is why this is one stateful pass
  # and no longer three greps. The program is single-quoted and may carry no apostrophe.
  #
  # A NUL BYTE ENDS A LINE FOR BSD awk, so `| H2 | FAIL\0 | SPAN |` was judged as `| H2 | FAIL`
  # and `SPAN\0 FAILED, do not cite` as a bare SPAN. Every NUL is rewritten to \032 (SUB) before
  # awk reads the log: a byte in no decoration set, so it can neither end a cell nor pad a span.
  # pipefail keeps an unreadable log on the could-not-read arm rather than reading it as empty.
  _res="$(set -o pipefail
          LC_ALL=C tr '\000' '\032' < "$GATE_LOG" |
          LC_ALL=C H2_LEAD="$ATTEST_LEAD" H2_TAIL="$ATTEST_TAIL" H2_LOCATE="$ATTEST_LOCATE" \
          H2_SPAN="$ATTEST_SPAN" H2_ANY="$ATTEST_ANY" awk '
    # cells(s, arr): split a table row into cells, by the reading GFM selects. A TABLE ROW
    # VERIFIES ONLY IF BOTH READINGS ACCEPT IT. A pipe written as \| is never a delimiter
    # in either. The two differ on a pipe inside a backtick code span:
    #   code-span reading (GFM == 0): the pipe is part of the cell. A code span opens on a
    #     run of N backticks and closes on the next run of exactly N; an opener with no
    #     closer is a literal backtick.
    #   GFM reading (GFM == 1, gfmcells): every unescaped pipe delimits, code span or not,
    #     which is how a GitHub table renders the row.
    # Either reading alone is steerable to a false grant, because one pipe shifts every
    # later cell one column. Splitting on every pipe judged `a| PASS` in a code span as a
    # PASS column where the rendered-as-code row read FAIL; splitting on code spans judged
    # `a| FAIL |b` in a code span, then a PASS cell, as PASS where GitHub renders FAIL in
    # that column. Requiring both refuses each. The cost is a false REFUSAL of a genuine
    # PASS row that carries a pipe inside a code span, which costs one H2 re-drive; a
    # false grant attests a check nobody drove, which is the worst output this reader has.
    function gfmcells(s, arr,    n, i, L, ch, cur) {
      split("", arr)
      sub(/^[ ]*[|]/, "", s); sub(/[|][ ]*$/, "", s)
      L = length(s); n = 0; cur = ""; i = 1
      while (i <= L) {
        ch = substr(s, i, 1)
        if (ch == "\\" && substr(s, i + 1, 1) == "|") { cur = cur "\\|"; i += 2; continue }
        if (ch == "|") { arr[++n] = cur; cur = ""; i++; continue }
        cur = cur ch; i++
      }
      arr[++n] = cur
      return n
    }
    function closer(s, p, run,    L, r) {
      L = length(s)
      while (p <= L) {
        if (substr(s, p, 1) != "`") { p++; continue }
        r = 1; while (substr(s, p + r, 1) == "`") r++
        if (r == run) return p
        p += r
      }
      return 0
    }
    function cells(s, arr,    n, i, j, L, ch, cur, run) {
      if (GFM) return gfmcells(s, arr)
      split("", arr)
      sub(/^[ ]*[|]/, "", s); sub(/[|][ ]*$/, "", s)
      L = length(s); n = 0; cur = ""; i = 1
      while (i <= L) {
        ch = substr(s, i, 1)
        if (ch == "\\" && substr(s, i + 1, 1) == "|") { cur = cur "\\|"; i += 2; continue }
        if (ch == "`") {
          run = 1; while (substr(s, i + run, 1) == "`") run++
          j = closer(s, i + run, run)
          if (j) { cur = cur substr(s, i, j + run - i); i = j + run }
          else   { cur = cur substr(s, i, run); i += run }
          continue
        }
        if (ch == "|") { arr[++n] = cur; cur = ""; i++; continue }
        cur = cur ch; i++
      }
      arr[++n] = cur
      return n
    }
    # judge(rx): OK when a span matching rx sits in an accepted placement on this line,
    # else the reason it was refused. Sets CITE to the accepted span. A table row is read
    # under BOTH cell readings (see cells) and is OK only when both are; otherwise the
    # first refusal names the reason.
    function judge(rx,    a, b, cite) {
      GFM = 0; a = judgeone(rx); cite = CITE
      if (!istab) return a
      GFM = 1; b = judgeone(rx); GFM = 0
      if (a != "OK") return a
      if (b != "OK") return b " (reading every pipe as a cell border, as GitHub renders it)"
      CITE = cite; return "OK"
    }
    function judgeone(rx,    alone_rx, n, c, i, at, hn, hc, vi, k, v, name) {
      alone_rx = "^" LEAD "(" rx ")" TAIL "$"
      if (!istab) {
        if ($0 !~ alone_rx) return "inside other text"
        match($0, rx); CITE = substr($0, RSTART, RLENGTH); return "OK"
      }
      n = cells($0, c); at = 0
      for (i = 1; i <= n; i++) if (c[i] ~ alone_rx) { at = i; break }
      if (!at) return "inside other text"
      if (hdr == "") return "in a table row with no header row above its separator"
      hn = cells(hdr, hc); vi = 0
      for (i = 1; i <= hn; i++) {
        k = hc[i]; gsub(/[ *_`]/, "", k)
        if (tolower(k) ~ /^(result|verdict|status|outcome)$/) { vi = i; name = k; break }
      }
      if (!vi) return "in a table whose header names no Result, Verdict, Status or Outcome column"
      # EVERY verdict column is read, and the WHOLE cell: PASS or PASSED, optionally one
      # parenthetical, optionally a period, and nothing else. `PASS (FAILED on re-drive)`,
      # `PASS/FAIL`, `PASS~~` and `| Result | Status |` holding `PASS | FAIL` are refused.
      for (i = vi; i <= hn; i++) {
        k = hc[i]; gsub(/[ *_`]/, "", k)
        if (tolower(k) !~ /^(result|verdict|status|outcome)$/) continue
        v = (i <= n) ? c[i] : ""
        if ((why = vcell(v)) != "") return "in a row whose " k " cell " why
      }
      match(c[at], rx); CITE = substr(c[at], RSTART, RLENGTH); return "OK"
    }
    # vcell(v): empty when a verdict cell reads PASS, else why not. The first test keeps the
    # original message, so a cell that never began PASS reads as it always did.
    function vcell(v) {
      gsub(/^[ \t*_`]+|[ \t*_`]+$/, "", v)
      if (v !~ /^PASS(ED)?([^0-9A-Za-z_]|$)/) return "does not begin PASS"
      if (v !~ /^PASS(ED)?( [(][^()]*[)])?[.]?$/) return "carries more than PASS and one parenthetical"
      if (toupper(v) ~ REVOKE_WORDS || toupper(v) ~ /FAIL/) return "carries a failure word after PASS"
      return ""
    }
    # revokes(): this line withdraws THE attestation already granted, which it can only do by
    # carrying the live span itself AND a revocation word. A sentence that merely mentions
    # voiding is NOT read: over the consumer history that shape refused five correct PASS
    # gate logs (sprints 289, 308, 309) on prose such as "a changed fixture voids the
    # attestation by design" and "not an invalid attestation". A line naming no span cannot
    # say WHICH attestation it withdraws, and no word list separates it from commentary.
    function revokes(    u) {
      u = toupper($0)
      if ($0 ~ SPAN) return (u ~ REVOKE_WORDS)
      # One sentence shape carries no span and still revokes: a statement that THE attestation
      # IS void, and names no digest (a digest names some OTHER attestation this line is about).
      if ($0 ~ /digest=/) return 0
      return (u ~ /ATTESTATION (ABOVE |LINE )?(IS|WAS) (NOW )?(VOID|REVOKED|RETRACTED|WITHDRAWN|INVALID)/)
    }
    BEGIN {
      LEAD = ENVIRON["H2_LEAD"]; TAIL = ENVIRON["H2_TAIL"]; LOC = ENVIRON["H2_LOCATE"]
      SPAN = ENVIRON["H2_SPAN"]; ANY = ENVIRON["H2_ANY"]
      REVOKE_WORDS = "VOID|REVOKE|RETRACT|SUPERSEDE|INVALID"
      prevtab = 0; rows = 0; hdr = ""; prev = ""; fence = ""; incom = 0
    }
    {
      # A CRLF log must judge like an LF one, so the carriage return goes first.
      sub(/\r$/, "")
      # BLOCK CONTEXT before anything else. A span inside a fenced code block, an HTML
      # comment block, or an indented code block (four spaces, or a tab, before the line) is
      # displayed text, not a record: it is located, never granted, and never arms a table.
      blk = ""
      if (fence != "") {
        blk = "inside a fenced code block"
        if ($0 ~ ("^(   |  | )?" fence)) fence = ""
      } else if (match($0, /^(   |  | )?(```|~~~)/)) {
        fence = substr($0, RSTART + RLENGTH - 3, 3); blk = "on a code fence line"
      } else if (incom) {
        blk = "inside an HTML comment block"
        if (index($0, "-->")) incom = 0
      } else if ($0 ~ /^[ \t]*<!--/ && index(substr($0, index($0, "<!--") + 4), "-->") == 0) {
        incom = 1; blk = "inside an HTML comment block"
      } else if ($0 ~ /^(    |\t| \t|  \t|   \t)/) {
        blk = "inside an indented code block"
      }
      if (blk != "") {
        prevtab = 0; rows = 0; hdr = ""; prev = ""   # a block ends any table around it
        if (index($0, "H2_ATTESTED") && $0 ~ (LOC "(" ANY ")")) { locn = NR; locwhy = blk }
        next
      }
      # Table state next, so the row being judged sees its own header. The header is the
      # row directly above the separator, and only when it is the first row of its block.
      istab = ($0 ~ /^[ ]*[|]/)
      if (!istab) { rows = 0; hdr = "" }
      else if ($0 ~ /^[ |:-]+$/ && $0 ~ /-/) {
        if (prevtab && rows == 1 && hdr == "") hdr = prev
        prevtab = 1; prev = $0; next
      } else {
        if (!prevtab) { rows = 0; hdr = "" }
        rows++
      }
      prevtab = istab; prev = $0
      # A LATER REVOCATION REVOKES. The log is read in order and the last word on this
      # sprint at this digest stands: a VOIDED row carrying the span, or a sentence voiding
      # the H2 attestation, withdraws an earlier grant, and a later accepted span re-grants.
      # A line that is itself an accepted placement is a grant, never a revocation.
      spanl = (index($0, "H2_ATTESTED") && $0 ~ (LOC "(" ANY ")"))
      if (spanl && $0 ~ SPAN && judge(SPAN) == "OK") { pass = 1; passn = NR; revoked = 0; cite = CITE; next }
      if (pass && revokes()) { pass = 0; revoked = NR; revn = passn; next }
      if (!spanl) next
      why = judge(ANY)
      if (why == "OK") { changed = 1; next }
      locn = NR; locwhy = why
    }
    END {
      if (pass) print "PASS|" cite
      else if (revoked) print "REVOKED|" revoked "|" revn
      else if (changed) print "CHANGED"
      else if (locn) print "LOCATE|" locn "|" locwhy
      else print "NONE"
    }')" || {
    echo "RE-DRIVE: could not read ${GATE_LOG} — H2 cannot be verified from it." >&2
    exit 1
  }
  IFS='|' read -r _v _a _b <<<"$_res"
  case "$_v" in
    PASS)
      echo "PASS  H2 attested for sprint ${SPRINT} at fixture digest ${DIGEST}."
      # PRINT THE SPAN, NOT THE LINE, AND FROM THE LINE THAT WAS ACCEPTED. Once the reader
      # admits a table cell, the matching LINE is the whole markdown row — measured at 891
      # bytes on the consumer's own log against 117 for the span — and this output is copy
      # text an operator cites. The span is cut from the accepted placement itself, never
      # from the last occurrence anywhere in the log, which can be a REFUSED row whose
      # optional fields differ.
      printf '%s\n' "$_a"
      echo "      Cite this line. The fixtures are byte-identical to when it was driven."
      exit 0 ;;
    # EVERY VERDICT GOES TO STDOUT, like PASS and first-gate: a caller capturing only stdout
    # once saw nothing for CHANGED or a located refusal. stderr carries only reader failures.
    CHANGED)
      echo "RE-DRIVE: sprint ${SPRINT} has an attestation, but the fixture set CHANGED."
      echo "          expected digest ${DIGEST}; the logged attestation carries another."
      echo "          A changed fixture voids the attestation by design — re-drive H2 in full."
      exit 1 ;;
    REVOKED)
      echo "RE-DRIVE: ${GATE_LOG}:${_a} REVOKES the H2 attestation for sprint ${SPRINT} accepted at line ${_b}."
      echo "          A later line voiding the attestation withdraws it. Re-drive --attest and append"
      echo "          its line on its OWN line at column 1, nothing before or after it."
      exit 1 ;;
    LOCATE)
      echo "RE-DRIVE: ${GATE_LOG}:${_a} QUOTES an H2_ATTESTED span for sprint ${SPRINT} ${_b},"
      echo "          so it cannot be verified (a span the placement rules refuse is not an attestation). Re-drive"
      echo "          --attest and append its line on its OWN line at column 1, nothing before or after it."
      echo "          In a table log the span may instead sit ALONE in a cell of a row whose"
      echo "          Result, Verdict, Status or Outcome column reads PASS."
      exit 1 ;;
    NONE)
      echo "RE-DRIVE: no H2 attestation for sprint ${SPRINT} — this is the sprint's first gate."
      exit 1 ;;
  esac
  echo "RE-DRIVE: the --verify reader returned no verdict for ${GATE_LOG}." >&2
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
echo "Append the line below to the gate log on its own line at column 1, with nothing"
echo "before or after it. Any prose AFTER the line makes it unverifiable, as does any"
echo "prose before it, and --verify will name the line. In a table log, the span ALONE"
echo "in a cell is also accepted, in a row whose Result, Verdict, Status or Outcome"
echo "column reads PASS; a table with no header row, or no such column, is refused."
echo "Nothing else about the line may change."
echo ""
echo "H2_ATTESTED v1 sprint=${SPRINT} digest=${DIGEST} at=${STAMP} items=1,2,3 mechanical=check-17-bypass:PASS"
exit 0
