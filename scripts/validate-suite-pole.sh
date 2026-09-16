#!/usr/bin/env bash
# validate-suite-pole.sh -- a RATCHET on the fixture suite's POLE: the loaded cost of the
# single longest fixture directory, read from the last full green run and compared against a
# tracked baseline. Distribution-only; a consumer has no docs/ and no baseline to read.
#
# WHAT IT IS. The pre-push suite is pole-bound -- its wall clock tracks the longest DIRECTORY,
# not the sum over the pool -- and until this existed nothing watched that number. It grew
# 493 -> 573 across two releases with no mechanism able to observe it, and three separate
# places (BL-005, docs/plans/pre-push-wall-clock.md, BL-257's own precursor) went on citing a
# pole that had been displaced four releases earlier. This reads the figure and says when it
# has grown past a stated band.
#
# WHY THE PROBE RUNS FIRST, BEFORE ANY REAL FILE IS OPENED. A ratchet that cannot fire reads
# exactly like a green one, and every wrong implementation of this guard that has been built
# was SILENT rather than loud: a hardcoded threshold, a zero-tolerance compare, a `cmp`, and
# floor instead of ceiling arithmetic all pass a same-vs-same receipt. So the first thing this
# program does is build seed pairs under `mktemp -d` and assert its own comparator answers
# them both ways -- a grown pole reported, a within-band pole silent -- and REFUSES (exit 2) on
# any miss. It runs even when the real baseline is corrupt, which is what makes the ordering
# observable: the probe's verdict precedes the corpus verdict in the output.
#
# WHY SKIP AND NOT FAIL ON NON-COMPARABLE INPUT. A LOADED cost is only meaningful against
# another loaded cost taken the same way. A partial dispatch (the read-set skip narrows the
# suite in place) leaves the pole scheduled beside thirty units instead of two hundred, which
# is a near-solo figure and a guaranteed false green -- or, compared the other direction, a
# false red. A different pool width is a different machine for this purpose. Every such state
# is a SKIP with its reason on exit 0, never a FAIL: a false red here trains the operator to
# `--no-verify`, which is strictly worse than no guard at all.
#
# WHY THERE IS NO DOWNWARD FAIL. A pole below the baseline is the outcome this guard exists to
# encourage, and failing on it would block the very push that improves the suite -- and would
# fire on any quiet box. A figure less than half the baseline gets a NOTE saying the row can
# come down; nothing more. The "check that cannot fire" property is owned by the self-probe
# above, which is where it can be asserted rather than inferred from a red run.
#
# THE BASELINE MOVES DOWN FREELY AND UP ONLY WITH A MEASUREMENT. That is the ratchet, and it is
# a review rule carried by the file's own comment header, not by this program.
#
# Usage: validate-suite-pole.sh [--durations <file>] [--baseline <file>] [--jobs <N>] [--root <dir>]
# Env:   AI_DLC_POLE_BASELINE=<file>   overrides the baseline path (same effect as --baseline)
# Exit:  0 = pass, or SKIP on non-comparable input (both are "do not block this push")
#        1 = the pole has GROWN beyond the band
#        2 = refusal: bad usage, unreadable/malformed baseline, or a self-probe miss
set -uo pipefail

ME="validate-suite-pole"

# ---------------------------------------------------------------------------------------
# Argument parsing. Explicit flag and env values are taken AS GIVEN -- never re-resolved
# against the root -- because the fixture and the filed receipt both hand this program files
# under mktemp that exist nowhere near a repo.
# ---------------------------------------------------------------------------------------
OPT_DUR=""; OPT_BASE=""; OPT_JOBS=""; OPT_ROOT=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --durations) [ "$#" -ge 2 ] || { printf '%s: REFUSE -- --durations needs a value\n' "$ME" >&2; exit 2; }; OPT_DUR="$2"; shift 2 ;;
    --baseline)  [ "$#" -ge 2 ] || { printf '%s: REFUSE -- --baseline needs a value\n'  "$ME" >&2; exit 2; }; OPT_BASE="$2"; shift 2 ;;
    --jobs)      [ "$#" -ge 2 ] || { printf '%s: REFUSE -- --jobs needs a value\n'      "$ME" >&2; exit 2; }; OPT_JOBS="$2"; shift 2 ;;
    --root)      [ "$#" -ge 2 ] || { printf '%s: REFUSE -- --root needs a value\n'      "$ME" >&2; exit 2; }; OPT_ROOT="$2"; shift 2 ;;
    -h|--help)   sed -n '2,45p' "$0"; exit 0 ;;
    *) printf '%s: REFUSE -- unknown argument %s\n' "$ME" "$1" >&2; exit 2 ;;
  esac
done

# WALK UP FOR `VERSION`, never count `..` hops. A validator that counts hops answers
# differently from the repo root, from a subdirectory, and from a fixture sandbox that copied
# it -- and the sandbox answer is the silent one. `--root` short-circuits the walk entirely so
# a probe tree can be named outright.
resolve_root() {
  local d
  d="$(pwd -P)"
  while [ "$d" != "/" ]; do
    [ -f "$d/VERSION" ] && { printf '%s\n' "$d"; return 0; }
    d="$(dirname "$d")"
  done
  return 1
}

if [ -n "$OPT_ROOT" ]; then
  ROOT="$OPT_ROOT"
  [ -d "$ROOT" ] || { printf '%s: REFUSE -- --root %s is not a directory\n' "$ME" "$ROOT" >&2; exit 2; }
else
  ROOT="$(resolve_root)" || { printf '%s: REFUSE -- no VERSION found walking up from %s; pass --root\n' "$ME" "$(pwd -P)" >&2; exit 2; }
fi

DUR="${OPT_DUR:-$ROOT/.git/ai-dlc-fixture-durations.last}"
BASE="${OPT_BASE:-${AI_DLC_POLE_BASELINE:-$ROOT/docs/suite-pole-baseline.tsv}}"
JOBS="${OPT_JOBS:-12}"
case "$JOBS" in ''|*[!0-9]*) printf '%s: REFUSE -- --jobs %s is not a number\n' "$ME" "$JOBS" >&2; exit 2 ;; esac

# ---------------------------------------------------------------------------------------
# THE COMPARATOR, factored out so the self-probe drives THE SAME CODE the corpus verdict does.
# A probe that re-implements the arithmetic is a second opinion whose bugs nobody finds.
#
# CEILING IS `B + ceil(B*band/100)` IN INTEGER ARITHMETIC. The `+ 99` is what makes it ceil
# rather than floor, and it is load-bearing on small baselines: B=4 band=15 gives 4*15=60,
# floor 0 -> ceiling 4 (so an honest 5 fails), ceil 1 -> ceiling 5. Rounding is wrong the same
# way one step out: B=7 band=15 is 105, round 1 -> ceiling 8, ceil 2 -> ceiling 9.
# ---------------------------------------------------------------------------------------
pole_ceiling() { # <baseline-seconds> <band-percent> -> ceiling
  printf '%s\n' "$(( $1 + ($1 * $2 + 99) / 100 ))"
}
# 0 = within band (pass), 1 = grown past the ceiling.
pole_verdict() { # <observed> <baseline> <band>
  local c; c="$(pole_ceiling "$2" "$3")"
  [ "$1" -gt "$c" ] && return 1
  return 0
}

# ---------------------------------------------------------------------------------------
# BASELINE PARSER, used by the probe and the corpus arm alike.
#   `#` comments; the directives `# band: <N>`, `# jobs: <N>`, `# fixtures: <N>` are parsed
#   OUT of those comments; exactly ONE data row `<fixture> <loaded-seconds>`.
# Prints `<fixture> <seconds> <band> <jobs> <fixtures>` on success; on failure prints a
# diagnosis to stderr and returns 2.
#
# EXACTLY ONE DATA ROW BY DESIGN. A baseline holding a row per fixture is a file nobody reads
# and everybody's push edits, and the rows for units nobody watches rot in place. The suite is
# pole-bound; one row is the whole of what determines the wall clock.
# ---------------------------------------------------------------------------------------
parse_baseline() { # <file>
  local f="$1" band="" jobs="" fixtures="" rows="" n=0 line key val
  if [ ! -f "$f" ]; then
    printf '%s: REFUSE -- baseline not readable: %s\n' "$ME" "$f" >&2; return 2
  fi
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      '#'*)
        # Directive or free comment, parsed WITHOUT a regex alternation. BSD `sed` BRE has no
        # `\|` -- it matches nothing, raises nothing, and prints an empty line, so every
        # directive reads as absent and the "missing directive" refusal fires on a file that
        # carries all three. Measured here: the BRE form returned empty against an ERE control
        # that returned `band 15`, and this program's own self-probe is what surfaced it. Shell
        # prefix-stripping has no dialect.
        key="${line#\#}"
        # Strip leading blanks one at a time; `${x## }` cannot express "any run of blanks"
        # portably and a bracket class here is the multibyte trap S10 refuses elsewhere.
        while :; do
          case "$key" in
            ' '*)  key="${key# }" ;;
            "$(printf '\t')"*) key="${key#"$(printf '\t')"}" ;;
            *) break ;;
          esac
        done
        val=""
        case "$key" in
          band:*)     val="${key#band:}";     key=band ;;
          jobs:*)     val="${key#jobs:}";     key=jobs ;;
          fixtures:*) val="${key#fixtures:}"; key=fixtures ;;
          *) continue ;;
        esac
        # Trim blanks around the value, then demand a bare integer. A directive whose value is
        # not one is REFUSED by name rather than ignored: silently skipping it leaves the
        # "missing directive" refusal below firing with the wrong diagnosis.
        while :; do
          case "$val" in
            ' '*)  val="${val# }" ;;
            "$(printf '\t')"*) val="${val#"$(printf '\t')"}" ;;
            *) break ;;
          esac
        done
        while :; do
          case "$val" in
            *' ')  val="${val% }" ;;
            *"$(printf '\t')") val="${val%"$(printf '\t')"}" ;;
            *) break ;;
          esac
        done
        case "$val" in
          ''|*[!0-9]*)
            printf '%s: REFUSE -- baseline directive "# %s:" has a non-integer value "%s" (%s)\n' "$ME" "$key" "$val" "$f" >&2
            return 2 ;;
        esac
        case "$key" in
          band)     band="$val" ;;
          jobs)     jobs="$val" ;;
          fixtures) fixtures="$val" ;;
        esac
        ;;
      '') : ;;
      *)
        n=$((n + 1)); rows="$line"
        # A data row is two fields and the second is an integer. Anything else is refused by
        # NAME rather than skipped: a row this parser cannot read, silently dropped, leaves a
        # one-row file reading as zero rows and the refusal below fires for the wrong reason.
        case "$line" in
          *' '*) : ;;
          *) printf '%s: REFUSE -- baseline data line is not "<fixture> <seconds>": %s (%s)\n' "$ME" "$line" "$f" >&2; return 2 ;;
        esac
        val="${line#* }"
        case "$val" in
          ''|*[!0-9]*) printf '%s: REFUSE -- baseline seconds field is not an integer: %s (%s)\n' "$ME" "$line" "$f" >&2; return 2 ;;
        esac
        ;;
    esac
  done < "$f"
  if [ "$n" -ne 1 ]; then
    printf '%s: REFUSE -- baseline must hold exactly ONE data row, found %s (%s). The suite is pole-bound; a second row is a figure nobody reads and everybody edits.\n' "$ME" "$n" "$f" >&2
    return 2
  fi
  for key in band jobs fixtures; do
    case "$key" in
      band)     val="$band" ;;
      jobs)     val="$jobs" ;;
      fixtures) val="$fixtures" ;;
    esac
    if [ -z "$val" ]; then
      printf '%s: REFUSE -- baseline is missing the "# %s: <N>" directive (%s). Without it the comparison has no stated terms and a later reader cannot tell what the figure was taken under.\n' "$ME" "$key" "$f" >&2
      return 2
    fi
  done
  if [ "$band" -le 0 ]; then
    printf '%s: REFUSE -- baseline band is %s; a band of zero or less is a zero-tolerance check on a LOADED figure, which fires on load rather than on growth (%s).\n' "$ME" "$band" "$f" >&2
    return 2
  fi
  # FIVE SPECIFIERS FOR FIVE ARGUMENTS. Written with four, `printf` RECYCLES the format and
  # emits a second line -- the caller's `cut -f4` then reads `12\n200` and every downstream
  # comparison is against a value that is not a number. Nothing raised; the string simply had a
  # newline in it. The probe's exact-string assertion on a well-formed baseline is what caught
  # it, which a "did it parse" assertion would not have.
  printf '%s %s %s %s %s\n' "${rows%% *}" "${rows#* }" "$band" "$jobs" "$fixtures"
  return 0
}

# Largest row of a durations file, as `<fixture> <seconds>`. Empty output means no usable row.
# `NF == 2` is the same predicate the hook's own writer and reader use, so this cannot disagree
# with the pool about what a row is.
max_row() { # <file>
  awk 'NF == 2 && $2 ~ /^[0-9]+$/ { if ($2 + 0 > m) { m = $2 + 0; k = $1 } } END { if (k != "") print k, m }' "$1" 2>/dev/null
}

# ---------------------------------------------------------------------------------------
# VERDICT 1 -- THE SELF-PROBE, BOTH DIRECTIONS, UNDER mktemp, BEFORE ANY REAL FILE IS OPENED.
#
# Each seed names the wrong implementation it kills. A probe whose seeds all sit in the
# comfortable middle of the band is a probe four different wrong programs pass, which is the
# measurement that produced this list rather than a shorter one.
# ---------------------------------------------------------------------------------------
probe_fail() { printf '%s: REFUSE -- SELF-PROBE MISS: %s. The comparator cannot answer its own seeds, so nothing it says about the real baseline can be trusted. No corpus was read.\n' "$ME" "$1" >&2; exit 2; }

probe_expect() { # <name> <observed> <baseline> <band> <expect: pass|fail>
  local want="$5" got
  if pole_verdict "$2" "$3" "$4"; then got=pass; else got=fail; fi
  [ "$got" = "$want" ] || probe_fail "$1 (observed=$2 baseline=$3 band=$4% -> $got, expected $want)"
}

PROBE_DIR="$(mktemp -d)" || { printf '%s: REFUSE -- mktemp -d failed; the self-probe cannot run and this program does not read a corpus it has not proved it can judge.\n' "$ME" >&2; exit 2; }

# -- comparator, both directions --------------------------------------------------------
# AT the ceiling passes; ONE past it fails. This pair is what a `>=` mutant dies on.
probe_expect 'at-ceiling'     115 100 15 pass
probe_expect 'ceiling-plus-1' 116 100 15 fail
# Equal passes -- the trivial direction, and the only one a `cmp`-style implementation gets right.
probe_expect 'equal'          100 100 15 pass
# WITHIN the band passes. THIS is the seed a zero-tolerance implementation dies on, and it is
# the one the filed receipt structurally cannot carry: a receipt comparing 100 against 100 and
# 100 against 1000 is satisfied by an implementation that fails on any difference at all.
probe_expect 'within-band'    105 100 15 pass
# CEIL, NOT FLOOR. B=4 band=15 -> 60/100, floor 0, ceil 1. Under floor the ceiling is 4 and an
# honest 5 reads as growth; under ceil it is 5.
probe_expect 'ceil-not-floor-pass' 5 4 15 pass
probe_expect 'ceil-not-floor-fail' 6 4 15 fail
# CEIL, NOT ROUND. B=7 band=15 -> 105/100, round 1, ceil 2. Under round the ceiling is 8 and 9
# reads as growth; under ceil it is 9.
probe_expect 'ceil-not-round'      9 7 15 pass
# Far growth, the direction the guard exists for.
probe_expect 'gross-growth'     1000 100 15 fail

# -- parser, both directions ------------------------------------------------------------
printf '# band: 15\n# jobs: 12\n# fixtures: 200\nledger-reverify 100\n' > "$PROBE_DIR/good.tsv"
if ! probe_good="$(parse_baseline "$PROBE_DIR/good.tsv" 2>/dev/null)"; then
  probe_fail 'the parser refused a WELL-FORMED baseline -- every refusal it reports below would then be about its own grammar, not about the file'
fi
[ "$probe_good" = "ledger-reverify 100 15 12 200" ] || probe_fail "the parser misread a well-formed baseline as '$probe_good'"
# Two data rows must refuse. A parser that takes the first row and stops reads a corrupted
# baseline as a valid one, and the figure it compares against is then whichever row was typed
# first.
printf '# band: 15\n# jobs: 12\n# fixtures: 200\nledger-reverify 100\nfixture-git-env-seam 350\n' > "$PROBE_DIR/two.tsv"
parse_baseline "$PROBE_DIR/two.tsv" >/dev/null 2>&1 && probe_fail 'the parser ACCEPTED a baseline with two data rows'
# A missing directive must refuse -- one probe per directive, because a loop over three names
# that checks only the first is a guard two thirds unable to fire.
printf '# jobs: 12\n# fixtures: 200\nledger-reverify 100\n' > "$PROBE_DIR/noband.tsv"
parse_baseline "$PROBE_DIR/noband.tsv" >/dev/null 2>&1 && probe_fail 'the parser ACCEPTED a baseline with no "# band:" directive'
printf '# band: 15\n# fixtures: 200\nledger-reverify 100\n' > "$PROBE_DIR/nojobs.tsv"
parse_baseline "$PROBE_DIR/nojobs.tsv" >/dev/null 2>&1 && probe_fail 'the parser ACCEPTED a baseline with no "# jobs:" directive'
printf '# band: 15\n# jobs: 12\nledger-reverify 100\n' > "$PROBE_DIR/nofix.tsv"
parse_baseline "$PROBE_DIR/nofix.tsv" >/dev/null 2>&1 && probe_fail 'the parser ACCEPTED a baseline with no "# fixtures:" directive'
# ALL THREE DIRECTIVES READ AT ONCE, from a file whose prose comments surround them and whose
# spacing is not the canonical one. This seed is here because the first cut of this parser used
# a BRE alternation, which BSD `sed` does not implement: it matched NOTHING, raised nothing, and
# every directive read as absent -- so the "missing directive" refusals above all passed while
# the parser could not read a conforming file at all. Three absent directives and three
# unreadable ones are the same output; only a POSITIVE seed separates them.
printf '# a prose line the parser must ignore\n#band:9\n#   jobs:   4\n# fixtures: 7\n# another prose line\nsome-fixture 42\n' > "$PROBE_DIR/spacing.tsv"
probe_sp="$(parse_baseline "$PROBE_DIR/spacing.tsv" 2>/dev/null)" || probe_fail 'the parser refused a conforming baseline whose directives carry non-canonical spacing'
[ "$probe_sp" = "some-fixture 42 9 4 7" ] || probe_fail "the parser read non-canonically spaced directives as '$probe_sp', not 'some-fixture 42 9 4 7'"
# A zero or negative band is a zero-tolerance check on a LOADED figure and must be refused: it
# fires on load rather than on growth, which is the guard the operator switches off.
printf '# band: 0\n# jobs: 12\n# fixtures: 200\nledger-reverify 100\n' > "$PROBE_DIR/zeroband.tsv"
parse_baseline "$PROBE_DIR/zeroband.tsv" >/dev/null 2>&1 && probe_fail 'the parser ACCEPTED a band of 0, which is a zero-tolerance ratchet on a loaded figure'

# -- the durations reader, both directions ----------------------------------------------
# The pole is the MAX row, not the first and not the last. A reader that takes either reads a
# correct file and answers about the wrong fixture.
printf 'alpha 10\nledger-reverify 500\nomega 20\n' > "$PROBE_DIR/dur.tsv"
probe_max="$(max_row "$PROBE_DIR/dur.tsv")"
[ "$probe_max" = "ledger-reverify 500" ] || probe_fail "the durations reader answered '$probe_max' where the max row is 'ledger-reverify 500'"
# An empty durations file yields NOTHING, which is what verdict 3 turns into a SKIP. A reader
# that invents a zero here makes every baseline look like growth-free improvement forever.
: > "$PROBE_DIR/empty.tsv"
probe_empty="$(max_row "$PROBE_DIR/empty.tsv")"
[ -z "$probe_empty" ] || probe_fail "the durations reader returned '$probe_empty' from an EMPTY file"
# A file whose rows are all unparseable is the same case, and it is NOT the same input: an
# empty file and a garbage file reach the reader differently and only one of them was probed
# before this line existed.
printf 'garbage\nalso garbage here too\n' > "$PROBE_DIR/junk.tsv"
probe_junk="$(max_row "$PROBE_DIR/junk.tsv")"
[ -z "$probe_junk" ] || probe_fail "the durations reader returned '$probe_junk' from a file with no well-formed row"

rm -rf "$PROBE_DIR"
printf '   probe  comparator, parser and durations reader answered %s seeds in both directions\n' 18

# ---------------------------------------------------------------------------------------
# VERDICT 2 -- THE BASELINE ITSELF. Refusals, not failures: a malformed baseline is a broken
# instrument and reporting growth from one would be a number invented by a parser.
#
# THE STALE-POLE CHECK IS HOISTED HERE, and the hoist is the point. A baseline naming a fixture
# directory that no longer exists can never be caught downstream: a deleted fixture produces no
# durations row, so the comparison arm below would SKIP forever and the tracked file would rot
# green. Reachability is the reason this sits above the durations read rather than beside the
# comparison it belongs to.
# ---------------------------------------------------------------------------------------
BL="$(parse_baseline "$BASE")" || exit 2
BL_POLE="$(printf '%s' "$BL" | cut -d' ' -f1)"
BL_SECS="$(printf '%s' "$BL" | cut -d' ' -f2)"
BL_BAND="$(printf '%s' "$BL" | cut -d' ' -f3)"
BL_JOBS="$(printf '%s' "$BL" | cut -d' ' -f4)"
BL_FIXT="$(printf '%s' "$BL" | cut -d' ' -f5)"

if [ ! -d "$ROOT/core/fixtures/$BL_POLE" ]; then
  printf '%s: REFUSE -- the baseline names pole "%s" and %s/core/fixtures/%s is not a directory (%s). A deleted or renamed fixture produces no durations row, so this can never surface as a comparison: the arm below would SKIP on every run and the tracked baseline would rot green. Re-point the row at the fixture that is the pole now, with its measurement.\n' \
    "$ME" "$BL_POLE" "$ROOT" "$BL_POLE" "$BASE" >&2
  exit 2
fi

# ---------------------------------------------------------------------------------------
# VERDICT 3 -- NO FRESH MEASUREMENT. Exit 0. The hook writes the durations file only after a
# fully green pool and truncates it at pool entry, so "absent or empty" is the normal state on
# every push that did not run a complete suite. Failing here would fail those pushes.
# ---------------------------------------------------------------------------------------
if [ ! -s "$DUR" ]; then
  printf '   SKIP -- no fresh full-suite measurement (%s)\n' "$DUR"
  exit 0
fi

# ---------------------------------------------------------------------------------------
# VERDICT 4 -- COMPARABILITY PRECONDITIONS. Each is a SKIP with its reason, never a FAIL.
#
# (a) PARTIAL DISPATCH. The read-set skip narrows the dispatch list in place, so a run can
#     time the pole beside thirty units instead of two hundred. That is a near-solo figure and
#     the two must never be compared -- one shard has measured 442s loaded against 112s solo.
#     This is the false red the guard would otherwise produce on most pushes.
# ---------------------------------------------------------------------------------------
dur_rows="$(awk 'NF == 2 && $2 ~ /^[0-9]+$/ { n++ } END { print n + 0 }' "$DUR" 2>/dev/null)"
case "$dur_rows" in ''|*[!0-9]*) dur_rows=0 ;; esac

# Counted with `find`, whose ordering is not read -- only the count is, so the interactive
# `bfs` shim and /usr/bin/find agree here. `-maxdepth 2 -name run.sh` is the same population
# the hook's own dispatch loop builds: a directory under core/fixtures/ carrying a run.sh.
fx_count="$(find "$ROOT/core/fixtures" -mindepth 2 -maxdepth 2 -name run.sh -type f 2>/dev/null | wc -l | tr -d ' ')"
case "$fx_count" in ''|*[!0-9]*) fx_count=0 ;; esac

if [ "$fx_count" -eq 0 ]; then
  printf '   SKIP -- no fixtures found under %s/core/fixtures, so "the whole suite ran" cannot be established (a zero here would make every partial run comparable)\n' "$ROOT"
  exit 0
fi
if [ "$dur_rows" -ne "$fx_count" ]; then
  printf '   SKIP -- partial dispatch (%s of %s) is not comparable to a full-suite baseline\n' "$dur_rows" "$fx_count"
  exit 0
fi
if [ "$JOBS" -ne "$BL_JOBS" ]; then
  printf '   SKIP -- pool width %s differs from the baseline'"'"'s %s\n' "$JOBS" "$BL_JOBS"
  exit 0
fi

# (c) BELT. Unreachable once (a) has passed -- a full-length durations file holds a row for
# every fixture, the baseline pole among them -- and kept because "unreachable" is a property
# of today's two populations agreeing, which is exactly the kind of claim that expires quietly.
OBS="$(max_row "$DUR")"
if [ -z "$OBS" ]; then
  printf '   SKIP -- no well-formed row in %s\n' "$DUR"
  exit 0
fi
OBS_POLE="${OBS%% *}"
OBS_SECS="${OBS#* }"

# ---------------------------------------------------------------------------------------
# VERDICT 5 -- THE COMPARISON.
# ---------------------------------------------------------------------------------------
CEIL="$(pole_ceiling "$BL_SECS" "$BL_BAND")"

if ! pole_verdict "$OBS_SECS" "$BL_SECS" "$BL_BAND"; then
  printf '   FAIL  the suite pole has GROWN: %s at %ss against baseline %s at %ss (band %s%%, ceiling %ss, pool %s, baseline taken over %s fixtures)\n' \
    "$OBS_POLE" "$OBS_SECS" "$BL_POLE" "$BL_SECS" "$BL_BAND" "$CEIL" "$JOBS" "$BL_FIXT"
  printf '         The suite is POLE-BOUND -- its wall clock is this one number, not the sum over the pool.\n'
  printf '         A LOADED BOX IS NOT A REASON TO RAISE THE ROW. Re-run the gate first; the band already\n'
  printf '         covers the run-to-run spread this figure was calibrated against.\n'
  printf '         A real change to %s or to what it exercises raises the row in %s IN THE SAME CHANGE,\n' "$OBS_POLE" "$BASE"
  printf '         with the measurement and the load average beside it. The row moves DOWN freely.\n'
  exit 1
fi

printf '   pole %s %ss against baseline %s %ss (band %s%%, ceiling %ss, pool %s)\n' \
  "$OBS_POLE" "$OBS_SECS" "$BL_POLE" "$BL_SECS" "$BL_BAND" "$CEIL" "$JOBS"

# NOTES, both non-failing.
#
# The pole MOVING is not growth and must not be reported as it: the suite is as fast as its
# longest unit whatever that unit is called. It is worth saying out loud because a baseline
# pinned to a fixture that is no longer the pole is watching the wrong number while passing.
if [ "$OBS_POLE" != "$BL_POLE" ]; then
  printf '   NOTE  the pole has moved to %s; the baseline still names %s. Consider re-baselining -- a row pinned to a unit that is no longer longest passes while watching the wrong number.\n' "$OBS_POLE" "$BL_POLE"
fi
# A baseline more than twice the observed figure is a ratchet that has stopped ratcheting: it
# would take a 100%% regression to fire. NO DOWNWARD FAIL, deliberately -- see the header.
if [ "$((OBS_SECS * 2))" -lt "$BL_SECS" ]; then
  printf '   NOTE  the baseline is more than twice this run'"'"'s figure -- lower the row. A ceiling this far above the real cost would take a doubling to fire.\n'
fi
exit 0
