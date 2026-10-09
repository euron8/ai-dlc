#!/usr/bin/env bash
# validate-suite-pole.sh -- a RATCHET on the fixture suite's POLE: the loaded cost of the
# single longest fixture directory, read from the last full green run and compared against
# the RECORDED HISTORY of poles at the pool width that ran, seeded where a width has no history
# yet by a tracked baseline row. Distribution-only; a consumer has no docs/ and no baseline.
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
# WHY NON-COMPARABLE HISTORY IS SET ASIDE AND NEVER FAILED ON. A LOADED cost is only meaningful
# against another loaded cost taken under a similar load. A keyed dispatch (the read-set skip
# narrows the suite in place) times the pole beside seventy units instead of two hundred, and
# compared against a full-suite figure that is a false green -- or, the other direction, a false
# red. So each history row is COMPARABLE to this run or it is not (see COMPARABILITY below); a row
# that is not is counted and named on the output, never refused, and a run with too few
# comparable rows CALIBRATES. A false red here trains the operator to `--no-verify`, which is
# strictly worse than no guard at all. The remaining SKIPs are states with no measurement at all.
#
# A DIFFERENT POOL WIDTH IS A DIFFERENT MACHINE, AND EVERY WIDTH IS GUARDED BY ITS OWN HISTORY.
# A loaded figure is only comparable to one taken at the same width, and the first cut compared
# only at widths someone had hand-calibrated a tracked row for -- every other width printed a
# SKIP, which reads exactly like a pass (BL-465). Now every gated green run RECORDS its pole in a
# history file keyed by width, and the comparison at width W reads W's own rows:
#   - W has K=3 or more usable history rows: compare against B(W), the MAX OF EVERY usable row at
#     W since its rows were last dropped, under the file-level `# history-band:` of the tracked
#     baseline. History is the source at EVERY width once it exists, 12 and 16 included.
#   - fewer than K rows and a tracked row at W: CALIBRATING against the tracked SEED -- print the
#     comparison, record, exit 0. A seed never FAILs: the hand-calibrated rows are what BL-465
#     replaces, and a seed that could block would stop the history that replaces it from forming.
#   - fewer than K rows and no tracked row: CALIBRATING (n/3) -- record, print the comparison
#     against the max so far, exit 0. Nothing is enforced until K rows exist.
#
# B IS A MAX OVER ALL ROWS, NOT OVER A RECENT WINDOW, and the window is a measured defect. With
# admission at or below B, a window of the K most recent rows ratchets ONE WAY: three quiet runs
# are admitted, push the loud ones out of the window, and B falls to the quiet figure for good.
# Measured: calibrated at 500/520/510, then three runs at 300, and every ordinary loaded figure
# from 410 to 500 failed the push. Over all rows, admitted rows cannot lower B either -- B moves
# only through the reviewed drop command, exactly as a tracked row only moves by a reviewed edit.
# The output names which source was used. History rows are `<jobs>\t<pole>\t<secs>\t<fixture-
# count>\t<epoch>\t<load>\t<dispatched>`, appended by ONE `printf ... >> "$HIST"` per row: no temp
# file, no rename, so two pushes recording at once interleave whole lines rather than one
# discarding the other. Rows written before the load and count columns existed carry the first
# five only and are LEGACY rows, never usable (see COMPARABILITY).
#
# ADMISSION: B NEVER MOVES WITHOUT REVIEW. Once K rows exist a passing run is appended only if its
# pole is at or below B; a run inside the band ABOVE B passes and is not recorded, so a slow creep
# inside the band cannot ratchet the statistic up a band at a time. Before K rows exist B is
# undefined and every calibrating run is recorded -- gating calibration on a B that does not exist
# would freeze a width at its first row. Re-baselining is a reviewed act: drop the width's rows
# (the FAIL text prints the exact command) and let it re-calibrate.
#
# ONE MEASUREMENT IS ONE ROW. A recorded run CONSUMES the width sidecar (empties it), so the same
# published durations file re-read by a second invocation records nothing.
#
# A HISTORY ROW WHOSE POLE DIRECTORY IS GONE IS IGNORED, NOT REFUSED. A renamed or sharded fixture
# leaves rows naming nothing; they do not count toward K and do not enter B, and a NOTE says how
# many were ignored. If ignoring them drops a width below K, it is back in CALIBRATING, which is
# deliberate: a statistic over a partition that no longer exists is not a measurement. "Gone" is
# membership in the same on-disk population the load is summed over -- a directory carrying a run.sh.
#
# THE RECORD POINT IS THE END OF THE PROGRAM, after the comparison, and ONLY on PASS or
# CALIBRATING -- never on a SKIP (no measurement, no record, no fixtures), a FAIL, a refusal,
# or the hook's `--durations /dev/null` branches, which reach verdict 3 and exit. A keyed run whose
# share of the record is low RECORDS: its count column is what makes it comparable later. Once a width
# holds K rows, a run with no comparable row records only at or below their max (ADMISSION, in the
# header's COMPARABILITY section). It also requires
# the hook's WIDTH SIDECAR (`<durations>.jobs`, written beside the durations file only when a
# green pool published it) to equal `--jobs`, so a stale durations file from a run at another
# width is never recorded under this one. NOTE: "green" here is the POOL. A push whose fixture
# suite was green and whose other gate failed still records, because the pole figure is a
# property of the pool and the pool was complete.
#
# THE HISTORY FILE IS RESOLVED ON ITS OWN: `--history <file>`, else
# `$(git rev-parse --path-format=absolute --git-common-dir)/ai-dlc-suite-pole.history` at the root.
# In a root that is not a repository there is no default and nothing is created -- no mkdir, no
# fallback under `$ROOT/.git` -- and the run says it did not record.
#
# THE HISTORY STATISTIC IS NOT IN THE SELF-PROBE, for the reason the width selector is not: a
# probe seed on it converts a broken statistic into a refusal on every input, every fixture arm
# dies at once and none owns it. The suite-pole-guard fixture's history arms own it instead.
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
# COMPARABILITY IS A PROPERTY OF EACH HISTORY ROW AGAINST THIS RUN, AND IT IS THE DISPATCHED COUNT
# (BL-465). What makes a loaded figure loaded is how many units ran beside it. Every row records its
# run's DISPATCHED COUNT -- the rows of its durations file naming a fixture directory on disk -- and a
# 7-column row at this width is usable when its pole directory exists, its pole was TIMED by this run
# (so the unit B names was measured, not assumed), and its count is within +-COUNT_BAND% of this
# run's. B is the max of the usable rows. The count, and not the timed cost, because a cost moves when
# the code gets slower: keyed on cost, a uniform slowdown moved the run out of band and every regression
# of that shape calibrated instead of failing. The row's LOAD (timed cost less its own pole) is still
# written and printed; it decides nothing. A LEGACY 5-column row carries neither figure and is never
# usable; a row of any other shape, or a 7-column row with a non-integer load or count, is MALFORMED
# and never usable. Both are counted and named, never refused.
#
# ADMISSION ON THE CALIBRATING PATH. A run with fewer than K usable rows calibrates, and before this it
# recorded unconditionally -- so a regression that made itself incomparable (a slowdown, a novel
# dispatch, a keyed run skipping B's pole) entered history and raised B for every later run in band
# of it, without review. Once a width holds K or more well-formed 7-column rows of ANY comparability,
# a calibrating run (or a seed run) records only if its pole is at or below the max over those rows;
# above it the run still passes, is not recorded, and says so. A pole above the width's max enters
# history only after a reviewed drop, exactly as a pole above B does on the history path.
#
# WHY NOT THE SHARE OF THE RECORD, AND WHY NOT THE DISPATCHED SET. The share test was the first
# predicate here and it SKIPPED every keyed push: read-set keys dispatch about seventy of two
# hundred and fifty units, so no keyed push reached 90% and none could record. Measured over the
# last 21 measuring commits, a run with three or more comparable earlier rows was found for 0 of 21
# by an exact dispatched set, 2-5 of 21 by a 90% cost-weighted overlap of sets, 10-17 of 21 by load
# within +-25%, and 10-15 of 21 by dispatched count within +-25%. A share of "the dispatched set's
# record cost" is x/x = 100% always, because the hook folds this run into the record before the guard
# runs. The share is still computed and PRINTED, so a near-solo comparison is visible; it decides nothing.
#
# Usage: validate-suite-pole.sh [--durations <file>] [--record <file>] [--baseline <file>] [--jobs <N>] [--root <dir>] [--history <file>]
#   --durations  this run's own costs (the hook's .last file); its width sidecar is <file>.jobs
#   --record     the cumulative merged record the printed share is read from
#   --history    the per-width pole history read and appended (default: in the git common dir)
# Env:   AI_DLC_POLE_BASELINE=<file>   overrides the baseline path (same effect as --baseline)
# Exit:  0 = pass, CALIBRATING, or SKIP with no measurement (all "do not block this push")
#        1 = the pole has GROWN beyond the band
#        2 = refusal: bad usage, unreadable/malformed baseline, or a self-probe miss
set -uo pipefail

ME="validate-suite-pole"

# ---------------------------------------------------------------------------------------
# Argument parsing. Explicit flag and env values are taken AS GIVEN -- never re-resolved
# against the root -- because the fixture and the filed receipt both hand this program files
# under mktemp that exist nowhere near a repo.
# ---------------------------------------------------------------------------------------
OPT_DUR=""; OPT_REC=""; OPT_BASE=""; OPT_JOBS=""; OPT_ROOT=""; JOBS_GIVEN=0; OPT_HIST=""; HIST_GIVEN=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --durations) [ "$#" -ge 2 ] || { printf '%s: REFUSE -- --durations needs a value\n' "$ME" >&2; exit 2; }; OPT_DUR="$2"; shift 2 ;;
    --record)    [ "$#" -ge 2 ] || { printf '%s: REFUSE -- --record needs a value\n'    "$ME" >&2; exit 2; }; OPT_REC="$2"; shift 2 ;;
    --baseline)  [ "$#" -ge 2 ] || { printf '%s: REFUSE -- --baseline needs a value\n'  "$ME" >&2; exit 2; }; OPT_BASE="$2"; shift 2 ;;
    --jobs)      [ "$#" -ge 2 ] || { printf '%s: REFUSE -- --jobs needs a value\n'      "$ME" >&2; exit 2; }; OPT_JOBS="$2"; JOBS_GIVEN=1; shift 2 ;;
    --root)      [ "$#" -ge 2 ] || { printf '%s: REFUSE -- --root needs a value\n'      "$ME" >&2; exit 2; }; OPT_ROOT="$2"; shift 2 ;;
    --history)   [ "$#" -ge 2 ] || { printf '%s: REFUSE -- --history needs a value\n'   "$ME" >&2; exit 2; }; OPT_HIST="$2"; HIST_GIVEN=1; shift 2 ;;
    # The header ends at the `set -uo pipefail` line; the range is derived from it, so a header
    # that grows cannot silently truncate the exit codes off the end of --help.
    -h|--help)   awk 'NR > 1 && /^set -uo pipefail$/ { exit } NR > 1' "$0"; exit 0 ;;
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

# THE DEFAULT RECORDS LIVE IN THE COMMON GIT DIR, which is what the hook's `$GITDIR` is. In a
# linked worktree `$ROOT/.git` is a FILE, so a default built on it names nothing and every
# default run would SKIP as "no measurement". Resolved only when a default is actually needed,
# and falling back to `$ROOT/.git` where the root is not a repository (a probe tree).
if [ -z "$OPT_DUR" ] || [ -z "$OPT_REC" ]; then
  GITDIR="$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || GITDIR=""
  [ -n "$GITDIR" ] && [ -d "$GITDIR" ] || GITDIR="$ROOT/.git"
fi
DUR="${OPT_DUR:-$GITDIR/ai-dlc-fixture-durations.last}"
REC="${OPT_REC:-$GITDIR/ai-dlc-fixture-durations}"
BASE="${OPT_BASE:-${AI_DLC_POLE_BASELINE:-$ROOT/docs/suite-pole-baseline.tsv}}"
# AN EXPLICIT EMPTY `--jobs` IS REFUSED, NOT DEFAULTED. The hook passes "$FIXTURE_JOBS"; an
# unset variable there reaching this program as 12 would compare against the 12-width row
# while the pool ran at some other width.
if [ "$JOBS_GIVEN" -eq 1 ]; then JOBS="$OPT_JOBS"; else JOBS=12; fi
case "$JOBS" in ''|*[!0-9]*) printf '%s: REFUSE -- --jobs "%s" is not a number\n' "$ME" "$JOBS" >&2; exit 2 ;; esac
# Canonical decimal, so `--jobs 016` selects the row keyed 16 rather than reading as no row.
JOBS="$((10#$JOBS))"

# The percent either side of this run's dispatched count within which a 7-column history row is
# comparable. 25 is the band the comparability rates in the header were measured at.
COUNT_BAND=25

# K, the number of usable history rows at a width before history replaces the tracked seed and B
# is enforced. Three loaded readings is the same n the tracked rows were calibrated from; B is
# then the MAX over every usable row, the same statistic they took (see the header for why not a
# window of the most recent K).
HIST_K=3

# ---------------------------------------------------------------------------------------
# THE COMPARATOR, factored out so the self-probe drives THE SAME CODE the corpus verdict does.
# A probe that re-implements the arithmetic is a second opinion whose bugs nobody finds.
#
# CEILING IS `B + ceil(B*band/100)` IN INTEGER ARITHMETIC. The `+ 99` is what makes it ceil
# rather than floor, and it is load-bearing on small baselines: B=4 band=15 gives 4*15=60,
# floor 0 -> ceiling 4 (so an honest 5 fails), ceil 1 -> ceiling 5. Rounding is wrong the same
# way one step out: B=7 band=15 is 105, round 1 -> ceiling 8, ceil 2 -> ceiling 9.
# ---------------------------------------------------------------------------------------
#
# THE ARITHMETIC LIVES ONCE, in `pole_ceiling_v`, which sets `_CEIL` rather than printing it, so
# the probe's ten-odd `pole_verdict` calls fork no subshell. `pole_ceiling` prints the same value
# for the one caller that reports it.
pole_ceiling_v() { # <baseline-seconds> <band-percent> -> sets _CEIL
  _CEIL="$(( $1 + ($1 * $2 + 99) / 100 ))"
}
pole_ceiling() { # <baseline-seconds> <band-percent> -> ceiling
  pole_ceiling_v "$1" "$2"
  printf '%s\n' "$_CEIL"
}
# 0 = within band (pass), 1 = grown past the ceiling.
pole_verdict() { # <observed> <baseline> <band>
  local c; pole_ceiling_v "$2" "$3"; c="$_CEIL"
  [ "$1" -gt "$c" ] && return 1
  return 0
}

# ---------------------------------------------------------------------------------------
# BASELINE PARSER, used by the probe and the corpus arm alike.
#   `#` comments; the directives `# band: <N>`, `# jobs: <N>`, `# fixtures: <N>` are parsed
#   OUT of those comments; data rows `<fixture> <loaded-seconds>`.
# Prints one `<fixture> <seconds> <band> <jobs> <fixtures>` line per data row on success; on
# failure prints a diagnosis to stderr and returns 2.
#
# ONE ROW PER POOL WIDTH, AS BLOCKS. A loaded figure is a property of the width it was taken
# at, so the file may carry one row for each width the hook runs under. Each data row takes the
# three directives written since the PREVIOUS row, and they are consumed by it: a block is
# `# band:`, `# jobs:`, `# fixtures:`, then its row. Blocks rather than a `jobs` column because
# a single-width file written before widths existed is already exactly one block and parses
# unchanged, and because each width's band is its own calibration and belongs beside its row.
# A row with no directives of its own is REFUSED rather than inheriting the block above, and
# directives with no row after them are REFUSED -- either would bind a figure to terms nobody
# wrote for it. Two rows for one width are REFUSED: the guard would have to pick one, and the
# figure it compared against would then be whichever was typed first.
#
# STILL NOT A ROW PER FIXTURE. A baseline holding a row per fixture is a file nobody reads and
# everybody's push edits. The suite is pole-bound; one row per width is the whole of it.
# ---------------------------------------------------------------------------------------
parse_baseline() { # <file>
  # THE TAB IS A CONSTANT, NEVER A printf COMMAND SUBSTITUTION INSIDE THE LOOPS BELOW. Spelled
  # that way it forked on every pattern test of every directive line, which made the parser
  # the larger half of this program's cost; the suite-pole-guard fixture drives this program over
  # a thousand times per run, so that fork was most of the fixture's wall clock (BL-426).
  local tab=$'\t'
  local f="$1" band="" jobs="" fixtures="" n=0 line key val prev secs out="" seen=" "
  if [ ! -f "$f" ]; then
    printf '%s: REFUSE -- baseline not readable: %s\n' "$ME" "$f" >&2; return 2
  fi
  while IFS= read -r line || [ -n "$line" ]; do
    # A CRLF-saved baseline carries a CR on every line, which would otherwise read as a
    # non-integer value on every directive and every row. Stripped, not refused: the bytes
    # the reader sees are then the bytes the writer meant.
    line="${line%$'\r'}"
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
            "$tab"*) key="${key#"$tab"}" ;;
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
            "$tab"*) val="${val#"$tab"}" ;;
            *) break ;;
          esac
        done
        while :; do
          case "$val" in
            *' ')  val="${val% }" ;;
            *"$tab") val="${val%"$tab"}" ;;
            *) break ;;
          esac
        done
        case "$val" in
          ''|*[!0-9]*)
            printf '%s: REFUSE -- baseline directive "# %s:" has a non-integer value "%s" (%s)\n' "$ME" "$key" "$val" "$f" >&2
            return 2 ;;
        esac
        # A DIRECTIVE SEEN TWICE BEFORE A ROW CONSUMES ITS BLOCK IS REFUSED. Without this, a later
        # directive silently overwrites an earlier one, and a block left without a row has its
        # surviving terms inherited by the next row -- a figure compared under a band or width
        # nobody wrote beside it. The EOF check below only ever saw the LAST orphaned block.
        case "$key" in
          band)     prev="$band" ;;
          jobs)     prev="$jobs" ;;
          fixtures) prev="$fixtures" ;;
        esac
        if [ -n "$prev" ]; then
          printf '%s: REFUSE -- baseline directive "# %s:" appears twice before a data row consumes its block (%s then %s) (%s). Each block is one "# band:", one "# jobs:", one "# fixtures:" and then its row; a repeat means a block was left without a row, and its terms would otherwise bind to the next one.\n' "$ME" "$key" "$prev" "$val" "$f" >&2
          return 2
        fi
        case "$key" in
          band)     band="$val" ;;
          jobs)     jobs="$val" ;;
          fixtures) fixtures="$val" ;;
        esac
        ;;
      '') : ;;
      *)
        n=$((n + 1))
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
        # A ZERO-SECOND ROW is a ceiling of zero: every run reads as growth. Refused, not compared.
        # Canonical decimal too: `0628` would otherwise reach the ceiling arithmetic as octal.
        secs="$((10#$val))"
        if [ "$secs" -le 0 ]; then
          printf '%s: REFUSE -- baseline row "%s" carries zero seconds; its ceiling would be zero and every run would read as growth (%s).\n' "$ME" "$line" "$f" >&2
          return 2
        fi
        for key in band jobs fixtures; do
          case "$key" in
            band)     val="$band" ;;
            jobs)     val="$jobs" ;;
            fixtures) val="$fixtures" ;;
          esac
          if [ -z "$val" ]; then
            printf '%s: REFUSE -- baseline row "%s" is missing the "# %s: <N>" directive in its own block (%s). Each row takes the directives written since the row before it; without them the comparison has no stated terms and a later reader cannot tell what the figure was taken under.\n' "$ME" "$line" "$key" "$f" >&2
            return 2
          fi
        done
        if [ "$band" -le 0 ]; then
          printf '%s: REFUSE -- baseline band is %s; a band of zero or less is a zero-tolerance check on a LOADED figure, which fires on load rather than on growth (%s).\n' "$ME" "$band" "$f" >&2
          return 2
        fi
        # A BAND OVER 1000% is a ceiling an elevenfold slowdown cannot reach -- a ratchet that
        # cannot fire -- and a long enough digit string overflows the shell's arithmetic into a
        # negative ceiling that fails every run. Either way the figure is not a calibration.
        if [ "${#band}" -gt 4 ] || [ "$((10#$band))" -gt 1000 ]; then
          printf '%s: REFUSE -- baseline band is %s%%; above 1000%% the ceiling cannot be reached by any real regression (%s).\n' "$ME" "$band" "$f" >&2
          return 2
        fi
        jobs="$((10#$jobs))"
        case "$seen" in
          *" $jobs "*)
            printf '%s: REFUSE -- baseline carries a second row for pool width %s ("%s") (%s). One row per width: with two, the figure compared against would be whichever was typed first.\n' "$ME" "$jobs" "$line" "$f" >&2
            return 2 ;;
        esac
        seen="$seen$jobs "
        # FIVE FIELDS PER ROW, ONE ROW PER LINE. Written with four specifiers, `printf` RECYCLES
        # the format and splits one row across two lines; the probe's exact-string assertion on
        # a well-formed baseline is what caught that, which a "did it parse" assertion would not.
        out="$out$(printf '%s %s %s %s %s' "${line%% *}" "$secs" "$((10#$band))" "$jobs" "$fixtures")
"
        band=""; jobs=""; fixtures=""
        ;;
    esac
  done < "$f"
  if [ "$n" -eq 0 ]; then
    printf '%s: REFUSE -- baseline holds no data row (%s).\n' "$ME" "$f" >&2
    return 2
  fi
  if [ -n "$band$jobs$fixtures" ]; then
    printf '%s: REFUSE -- baseline ends with directives that no row follows (%s). A block is its directives THEN its row; directives after the last row bind to nothing.\n' "$ME" "$f" >&2
    return 2
  fi
  printf '%s' "$out"
  return 0
}

# The baseline row for one pool width, or nothing. Exact match on the jobs field, which the
# parser has already made canonical.
select_width() { # <parsed-rows> <jobs>
  printf '%s' "$1" | awk -v j="$2" '$4 == j'
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

# Every seed counts itself as it runs, so the report line states how many seeds were ANSWERED
# rather than a figure typed beside them that goes stale the release a seed is added.
PROBE_N=0
seeded() { PROBE_N=$((PROBE_N + 1)); }

probe_expect() { # <name> <observed> <baseline> <band> <expect: pass|fail>
  local want="$5" got
  seeded
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
seeded
# A second row with NO BLOCK OF ITS OWN must refuse. A parser that lets it inherit the block
# above binds a figure to a band and width nobody wrote for it -- and one that takes the first
# row and stops reads a corrupted baseline as a valid one.
printf '# band: 15\n# jobs: 12\n# fixtures: 200\nledger-reverify 100\nfixture-git-env-seam 350\n' > "$PROBE_DIR/two.tsv"
parse_baseline "$PROBE_DIR/two.tsv" >/dev/null 2>&1 && probe_fail 'the parser ACCEPTED a second data row with no directive block of its own'
seeded
# TWO BLOCKS FOR TWO WIDTHS parse to two rows, IN ORDER and each with its OWN terms. This is
# the positive partner of the refusal above: without it a parser refusing every second row
# passes that seed.
printf '# band: 15\n# jobs: 12\n# fixtures: 200\nledger-reverify 100\n# band: 25\n# jobs: 16\n# fixtures: 227\ngate-adjudication-mutants 600\n' > "$PROBE_DIR/widths.tsv"
probe_w="$(parse_baseline "$PROBE_DIR/widths.tsv" 2>/dev/null)" || probe_fail 'the parser refused a baseline carrying one block per pool width'
[ "$probe_w" = "ledger-reverify 100 15 12 200
gate-adjudication-mutants 600 25 16 227" ] || probe_fail "the parser read a two-width baseline as '$probe_w'"
seeded
# THE WIDTH SELECTOR IS NOT PROBED HERE, deliberately. A probe seed on it converts a broken
# selector into a refusal on EVERY input, which moves every fixture arm at once and leaves no
# arm owning the selection; the suite-pole-guard fixture's width arm owns it instead.
# TWO BLOCKS FOR ONE WIDTH must refuse -- by name, not by taking the first.
printf '# band: 15\n# jobs: 12\n# fixtures: 200\nledger-reverify 100\n# band: 15\n# jobs: 12\n# fixtures: 200\nledger-reverify 300\n' > "$PROBE_DIR/dupw.tsv"
parse_baseline "$PROBE_DIR/dupw.tsv" >/dev/null 2>&1 && probe_fail 'the parser ACCEPTED two rows for one pool width'
seeded
# A missing directive must refuse -- one probe per directive, because a loop over three names
# that checks only the first is a guard two thirds unable to fire.
printf '# jobs: 12\n# fixtures: 200\nledger-reverify 100\n' > "$PROBE_DIR/noband.tsv"
parse_baseline "$PROBE_DIR/noband.tsv" >/dev/null 2>&1 && probe_fail 'the parser ACCEPTED a baseline with no "# band:" directive'
seeded
printf '# band: 15\n# fixtures: 200\nledger-reverify 100\n' > "$PROBE_DIR/nojobs.tsv"
parse_baseline "$PROBE_DIR/nojobs.tsv" >/dev/null 2>&1 && probe_fail 'the parser ACCEPTED a baseline with no "# jobs:" directive'
seeded
printf '# band: 15\n# jobs: 12\nledger-reverify 100\n' > "$PROBE_DIR/nofix.tsv"
parse_baseline "$PROBE_DIR/nofix.tsv" >/dev/null 2>&1 && probe_fail 'the parser ACCEPTED a baseline with no "# fixtures:" directive'
seeded
# ALL THREE DIRECTIVES READ AT ONCE, from a file whose prose comments surround them and whose
# spacing is not the canonical one. This seed is here because the first cut of this parser used
# a BRE alternation, which BSD `sed` does not implement: it matched NOTHING, raised nothing, and
# every directive read as absent -- so the "missing directive" refusals above all passed while
# the parser could not read a conforming file at all. Three absent directives and three
# unreadable ones are the same output; only a POSITIVE seed separates them.
# The fixtures directive is TAB-spaced before the key, before the value and after it, so each of
# the three tab-stripping sites in the parser has a seed it must strip or the row loses a directive.
printf '# a prose line the parser must ignore\n#band:9\n#   jobs:   4\n#\tfixtures:\t7\t\n# another prose line\nsome-fixture 42\n' > "$PROBE_DIR/spacing.tsv"
probe_sp="$(parse_baseline "$PROBE_DIR/spacing.tsv" 2>/dev/null)" || probe_fail 'the parser refused a conforming baseline whose directives carry non-canonical spacing'
[ "$probe_sp" = "some-fixture 42 9 4 7" ] || probe_fail "the parser read non-canonically spaced directives as '$probe_sp', not 'some-fixture 42 9 4 7'"
seeded
# A zero or negative band is a zero-tolerance check on a LOADED figure and must be refused: it
# fires on load rather than on growth, which is the guard the operator switches off.
printf '# band: 0\n# jobs: 12\n# fixtures: 200\nledger-reverify 100\n' > "$PROBE_DIR/zeroband.tsv"
parse_baseline "$PROBE_DIR/zeroband.tsv" >/dev/null 2>&1 && probe_fail 'the parser ACCEPTED a band of 0, which is a zero-tolerance ratchet on a loaded figure'
seeded
# Directives after the last row bind to nothing and must refuse: a half-written second block
# otherwise parses as the one-width file it was before the edit began.
printf '# band: 15\n# jobs: 12\n# fixtures: 200\nledger-reverify 100\n# band: 20\n# jobs: 16\n' > "$PROBE_DIR/trailing.tsv"
parse_baseline "$PROBE_DIR/trailing.tsv" >/dev/null 2>&1 && probe_fail 'the parser ACCEPTED directives that no row follows'
seeded

# -- the durations reader, both directions ----------------------------------------------
# The pole is the MAX row, not the first and not the last. A reader that takes either reads a
# correct file and answers about the wrong fixture.
printf 'alpha 10\nledger-reverify 500\nomega 20\n' > "$PROBE_DIR/dur.tsv"
probe_max="$(max_row "$PROBE_DIR/dur.tsv")"
[ "$probe_max" = "ledger-reverify 500" ] || probe_fail "the durations reader answered '$probe_max' where the max row is 'ledger-reverify 500'"
seeded
# An empty durations file yields NOTHING, which is what verdict 3 turns into a SKIP. A reader
# that invents a zero here makes every baseline look like growth-free improvement forever.
: > "$PROBE_DIR/empty.tsv"
probe_empty="$(max_row "$PROBE_DIR/empty.tsv")"
[ -z "$probe_empty" ] || probe_fail "the durations reader returned '$probe_empty' from an EMPTY file"
seeded
# A file whose rows are all unparseable is the same case, and it is NOT the same input: an
# empty file and a garbage file reach the reader differently and only one of them was probed
# before this line existed.
printf 'garbage\nalso garbage here too\n' > "$PROBE_DIR/junk.tsv"
probe_junk="$(max_row "$PROBE_DIR/junk.tsv")"
[ -z "$probe_junk" ] || probe_fail "the durations reader returned '$probe_junk' from a file with no well-formed row"
seeded

rm -rf "$PROBE_DIR"
printf '   probe  comparator, parser and durations reader answered %s seeds in both directions\n' "$PROBE_N"

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
BL_ALL="$(parse_baseline "$BASE")" || exit 2

# THE FILE-LEVEL `# history-band: <N>` DIRECTIVE. Invisible to parse_baseline -- its stripped key
# is `history-band:...`, which no `band:*` prefix matches -- so it is read here in one pass and
# held to the same 0 < band <= 1000 terms as a block's band. Given twice it is REFUSED. Absent is
# legal until a comparison against history is actually reached, which refuses then by name.
HBAND="$(awk '
  { sub(/\r$/, "") }
  /^#[ \t]*history-band:/ { v = $0; sub(/^#[ \t]*history-band:[ \t]*/, "", v); sub(/[ \t]+$/, "", v); n++; last = v }
  END { if (n > 1) print "DUP"; else if (n == 1) print last }' "$BASE" 2>/dev/null)"
case "$HBAND" in
  '') : ;;
  DUP) printf '%s: REFUSE -- "# history-band:" appears more than once in %s; it is one file-level figure.\n' "$ME" "$BASE" >&2; exit 2 ;;
  *[!0-9]*) printf '%s: REFUSE -- baseline directive "# history-band:" has a non-integer value "%s" (%s)\n' "$ME" "$HBAND" "$BASE" >&2; exit 2 ;;
  *)
    if [ "${#HBAND}" -gt 4 ] || [ "$((10#$HBAND))" -le 0 ] || [ "$((10#$HBAND))" -gt 1000 ]; then
      printf '%s: REFUSE -- "# history-band:" is %s%%; it must be above 0 and at most 1000 (%s).\n' "$ME" "$HBAND" "$BASE" >&2
      exit 2
    fi
    HBAND="$((10#$HBAND))" ;;
esac

# EVERY ROW, NOT ONLY THE ONE THIS RUN SELECTS. A row for a width the hook is not running at
# today is never compared, so a stale pole in it would otherwise rot until the width changed.
STALE_SCAN="$BL_ALL"
while IFS=' ' read -r _pole _rest; do
  [ -n "$_pole" ] || continue
  if [ ! -d "$ROOT/core/fixtures/$_pole" ]; then
    printf '%s: REFUSE -- the baseline names pole "%s" and %s/core/fixtures/%s is not a directory (%s). A deleted or renamed fixture produces no durations row, so this can never surface as a comparison: the arm below would SKIP on every run and the tracked baseline would rot green. Re-point the row at the fixture that is the pole now, with its measurement.\n' \
      "$ME" "$_pole" "$ROOT" "$_pole" "$BASE" >&2
    exit 2
  fi
done <<EOF
$STALE_SCAN
EOF

# ---------------------------------------------------------------------------------------
# THE RECORD POINT, defined here and called ONLY at the two verdicts that may record: a PASS and
# a CALIBRATING run. Every SKIP, the FAIL and every refusal exit before reaching it.
#
# THE WIDTH SIDECAR MUST EQUAL --jobs. The hook writes `<durations>.jobs` beside the durations
# file only when a green pool published it, and empties it where the durations file is emptied,
# so a durations file left over from a run at another width -- or written by nothing this push --
# cannot be recorded as this width's pole. A missing or mismatched sidecar records nothing and
# says so, naming the path, so a hook that stopped writing it is visible on the first push.
#
# ONE `printf >>` PER ROW, never a temp file and a rename: two pushes recording at once then
# interleave whole lines, where a rename would let one discard the other's row.
# ---------------------------------------------------------------------------------------
RECORDED=0
record_pole() { # <admit: yes|no> <why-not>  -> sets RECORDED=1 when a row was appended
  local side="$DUR.jobs" sj=""
  if [ "$1" != yes ]; then
    printf '   not recorded: %s\n' "$2"
    return 0
  fi
  if [ -z "$HIST" ]; then
    printf '   not recorded: %s is not a git repository and no --history was given, so there is no history file to append to\n' "$ROOT"
    return 0
  fi
  [ -f "$side" ] && sj="$(sed -n 1p "$side" 2>/dev/null)"
  case "$sj" in ''|*[!0-9]*) sj="" ;; *) sj="$((10#$sj))" ;; esac
  if [ "$sj" != "$JOBS" ]; then
    printf '   not recorded: the width sidecar %s reads "%s", not --jobs %s -- these durations were not published by a green pool at this width\n' "$side" "$sj" "$JOBS"
    return 0
  fi
  # SEVEN COLUMNS: the five a legacy row carries, then this run's LOAD and its on-disk dispatched
  # count -- the figures a later run's comparability test reads (see COMPARABILITY in the header).
  if printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$JOBS" "$OBS_POLE" "$OBS_SECS" "$fx_count" "$(date +%s)" "$LOAD" "$DISP" >> "$HIST" 2>/dev/null; then
    RECORDED=1
    # CONSUME THE SIDECAR: one published measurement is one row, however often it is re-read.
    : > "$side" 2>/dev/null
    printf '   recorded: pool %s pole %s %ss in %s\n' "$JOBS" "$OBS_POLE" "$OBS_SECS" "$HIST"
    # Said only when a row was really appended: a run whose sidecar did not match leaves the width
    # at zero rows, and announcing a first pole there would name a record that does not exist. And
    # only when the width held NO row at all, of any shape -- zero USABLE rows is not a first pole.
    if [ "$W_ROWS" -eq 0 ]; then
      printf '   RECORDED -- first pole at pool width %s: %ss (%s)\n' "$JOBS" "$OBS_SECS" "$OBS_POLE"
    fi
  else
    printf '   not recorded: could not append to %s\n' "$HIST"
  fi
  return 0
}

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
# THE HISTORY FILE, resolved only now: every branch above exits without reading or writing it,
# including the hook's `--durations /dev/null` branches, so a push that measured nothing costs
# no `git` call here. In a root that is not a repository there is NO default -- nothing is
# created, no `.git` is invented under a probe root -- and the record point says so.
# ---------------------------------------------------------------------------------------
if [ "$HIST_GIVEN" -eq 1 ]; then
  HIST="$OPT_HIST"
  [ -n "$HIST" ] || { printf '%s: REFUSE -- --history needs a non-empty value\n' "$ME" >&2; exit 2; }
else
  _hgd="$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || _hgd=""
  if [ -n "$_hgd" ] && [ -d "$_hgd" ]; then HIST="$_hgd/ai-dlc-suite-pole.history"; else HIST=""; fi
fi

# ---------------------------------------------------------------------------------------
# VERDICT 4 -- THE RUN'S OWN FIGURES, THEN THE COMPARISON SOURCE.
#
# (a) THE CUMULATIVE RECORD the printed share is read from. Absent or
#     empty is a SKIP by name: without it there is no statement of what the whole suite costs.
# ---------------------------------------------------------------------------------------
if [ ! -s "$REC" ]; then
  printf '   SKIP -- no cumulative durations record to measure coverage against (%s)\n' "$REC"
  exit 0
fi

# (b) THE ON-DISK POPULATION. Every sum below is joined to the fixture directories on disk: the
#     record keeps a key for a deleted fixture forever (the hook's merge never prunes it), and a
#     ghost key's cost would read as work this run failed to do, or as load it ran beside. The
#     population is a directory under core/fixtures/ carrying a run.sh, the same one the hook's
#     dispatch loop builds; only membership is read, never order, so the `find` shim and
#     /usr/bin/find agree.
ONDISK="$(find "$ROOT/core/fixtures" -mindepth 2 -maxdepth 2 -name run.sh -type f 2>/dev/null | awk -F/ '{ print $(NF - 1) }')"
fx_count="$(printf '%s' "$ONDISK" | awk 'NF { n++ } END { print n + 0 }')"
if [ "$fx_count" -eq 0 ]; then
  printf '   SKIP -- no fixtures found under %s/core/fixtures, so how much of the suite ran cannot be established\n' "$ROOT"
  exit 0
fi

OBS="$(max_row "$DUR")"
if [ -z "$OBS" ]; then
  printf '   SKIP -- no well-formed row in %s\n' "$DUR"
  exit 0
fi
OBS_POLE="${OBS%% *}"
OBS_SECS="${OBS#* }"

# (c) THE ONE JOIN SITE: a durations file's cost over the on-disk names (stdin), its on-disk row
#     count, and that cost LESS the named pole. Over this run's file the third figure is the LOAD L;
#     the pole is excluded BY NAME, never by subtracting its seconds, so a max row naming a fixture
#     that is not on disk cannot under-count the load. One call per file; no second join to drift.
cov_sum() { # <durations-file> <pole-name>  (stdin: on-disk fixture names) -> "<sum> <rows> <sum-less-pole>"
  awk -v p="$2" 'NR == FNR { d[$1] = 1; next } NF == 2 && $2 ~ /^[0-9]+$/ && ($1 in d) { s += $2; n++; if ($1 != p) l += $2 } END { print s + 0, n + 0, l + 0 }' - "$1" 2>/dev/null
}
read -r NUM DISP LOAD <<EOF
$(printf '%s\n' "$ONDISK" | cov_sum "$DUR" "$OBS_POLE")
EOF
read -r DEN _rn _rl <<EOF
$(printf '%s\n' "$ONDISK" | cov_sum "$REC" "$OBS_POLE")
EOF
case "$NUM" in ''|*[!0-9]*) NUM=0 ;; esac
case "$DEN" in ''|*[!0-9]*) DEN=0 ;; esac
case "$DISP" in ''|*[!0-9]*) DISP=0 ;; esac
case "$LOAD" in ''|*[!0-9]*) LOAD=0 ;; esac
if [ "$DEN" -eq 0 ]; then
  printf '   SKIP -- the record %s carries no cost for any of the %s fixture directories on disk\n' "$REC" "$fx_count"
  exit 0
fi

# (d) THE SHARE OF THE RECORD, PRINTED AND NEVER AN EXIT. It is how a reader sees that a comparison
#     was made on a keyed or near-solo dispatch. It decides nothing.
COV_BP=$((NUM * 10000 / DEN))
COV_TXT="$(printf '%d.%02d%%' "$((COV_BP / 100))" "$((COV_BP % 100))")"
printf '   coverage %s (this run timed %ss of the record'"'"'s %ss over %s fixture directories; printed, not a gate)\n' \
  "$COV_TXT" "$NUM" "$DEN" "$fx_count"

# (e) THE HISTORY, READ IN ONE awk PASS -- no fork per row; the fixture drives this program many
#     times. Inputs: the on-disk names (stdin), this run's durations (the set S it TIMED), then the
#     history. A row at this width is, in this order:
#       gone       its pole directory is not on disk -- ignored, with its own NOTE;
#       legacy     a 5-column row -- recorded before the count existed, never usable;
#       malformed  any other shape short of 7 columns, or a non-integer load or count;
#       untimed    its pole is not in S -- the unit B would name was not measured by this run;
#       outband    its dispatched count is outside +-COUNT_BAND% of this run's count C;
#     and otherwise USABLE, printed as `<pole> <secs> <fixtures> <count>`. The last line is
#     `# <gone> <untimed> <outband> <legacy> <malformed> <width-rows> <admit-rows> <admit-max>`:
#     width-rows counts every non-gone row at this width (the first-pole announcement reads it);
#     admit-rows and admit-max are the well-formed 7-column rows of ANY comparability and the max pole
#     over them, which the calibrating path's admission reads. The band test is exact integer
#     arithmetic on both edges, so a row at exactly 75% or 125% of C is comparable.
hist_read() { # stdin: on-disk fixture names
  awk -F'\t' -v j="$JOBS" -v C="$DISP" -v band="$COUNT_BAND" '
    FNR == 1 { f++ }
    f == 1 { d[$0] = 1; next }
    f == 2 { if (split($0, x, " ") == 2 && x[2] ~ /^[0-9]+$/) s[x[1]] = 1; next }
    NF >= 5 && $1 == j && $3 ~ /^[0-9]+$/ && $3 > 0 {
      if (!($2 in d)) { gone++; next }
      wrows++
      if (NF == 5) { legacy++; next }
      if (NF < 7 || $6 !~ /^[0-9]+$/ || $7 !~ /^[0-9]+$/) { malformed++; next }
      arows++; if ($3 + 0 > amax) amax = $3 + 0
      if (!($2 in s)) { untimed++; next }
      if ($7 * 100 < C * (100 - band)) { outband++; next }
      if ($7 * 100 > C * (100 + band)) { outband++; next }
      print $2, $3 + 0, $4, $7 + 0
    }
    END { print "#", gone + 0, untimed + 0, outband + 0, legacy + 0, malformed + 0, wrows + 0, arows + 0, amax + 0 }' - "$DUR" "$HIST" 2>/dev/null
}
H_RAW=""
if [ -n "$HIST" ] && [ -f "$HIST" ] && [ -s "$HIST" ]; then
  H_RAW="$(printf '%s\n' "$ONDISK" | hist_read)"
fi
H_N=0; H_STALE=0; H_UNTIMED=0; H_OUTBAND=0; H_LEGACY=0; H_MALFORMED=0; W_ROWS=0; A_ROWS=0; A_MAX=0; H_LIST=""
while IFS=' ' read -r _hp _hs _hf _hl _hx _hm _hw _ha _hz; do
  [ -n "$_hp" ] || continue
  if [ "$_hp" = "#" ]; then
    H_STALE="$_hs"; H_UNTIMED="$_hf"; H_OUTBAND="$_hl"; H_LEGACY="$_hx"; H_MALFORMED="$_hm"
    W_ROWS="$_hw"; A_ROWS="$_ha"; A_MAX="$_hz"; continue
  fi
  H_N=$((H_N + 1))
  H_LIST="$H_LIST$_hp $_hs $_hf $_hl
"
done <<EOF
$H_RAW
EOF
H_NC=$((H_UNTIMED + H_OUTBAND + H_LEGACY + H_MALFORMED))
H_B=0; H_BPOLE=""; H_BFIXT=""; H_BCOUNT=""
while IFS=' ' read -r _hp _hs _hf _hl; do
  [ -n "$_hp" ] || continue
  if [ "$_hs" -gt "$H_B" ]; then H_B="$_hs"; H_BPOLE="$_hp"; H_BFIXT="$_hf"; H_BCOUNT="$_hl"; fi
done <<EOF
$H_LIST
EOF

printf '   dispatched %s fixture directories (load %ss, this run'"'"'s on-disk cost less its pole %s, printed only); pool %s history: %s usable, %s not comparable (%s pole not timed, %s count outside +-%s%%, %s legacy, %s malformed)\n' \
  "$DISP" "$LOAD" "$OBS_POLE" "$JOBS" "$H_N" "$H_NC" "$H_UNTIMED" "$H_OUTBAND" "$COUNT_BAND" "$H_LEGACY" "$H_MALFORMED"

# ADMISSION WITHOUT A USABLE B. A calibrating or seed run records unconditionally only while the width
# holds fewer than K well-formed rows; once it holds K, a pole above the max over them is not recorded.
# Otherwise a regression that made itself incomparable -- slower everywhere, a novel dispatch, a keyed
# run skipping B's pole -- would enter history and raise B for every later run in band of it.
admit_calibrating() {
  if [ "$A_ROWS" -ge "$HIST_K" ] && [ "$OBS_SECS" -gt "$A_MAX" ]; then
    record_pole no "${OBS_SECS}s is above the width's max ${A_MAX}s over its ${A_ROWS} recorded row(s), and with no comparable row to judge it a pole above that max enters history only after a reviewed drop"
  else
    record_pole yes ""
  fi
}

# (f) POOL WIDTH AND SOURCE. A different width is a different machine for a loaded figure, so the
#     figure compared against is one taken at THIS width: its usable history once that holds K
#     rows, else the tracked row as a seed, else nothing -- CALIBRATING, which records and passes.
#     There is no SKIP for "no row at this width" and none for a low share (BL-465). B is the MAX
#     of every usable row; with fewer than K rows it is only ever printed.
BL="$(select_width "$BL_ALL" "$JOBS")"
if [ "$H_N" -ge "$HIST_K" ]; then
  SRC=history
  if [ -z "$HBAND" ]; then
    printf '%s: REFUSE -- pool width %s has %s usable history rows in %s, so history is the comparison source, and %s carries no "# history-band: <N>" directive to compare it under.\n' "$ME" "$JOBS" "$H_N" "$HIST" "$BASE" >&2
    exit 2
  fi
  BL_POLE="$H_BPOLE"; BL_SECS="$H_B"; BL_BAND="$HBAND"; BL_FIXT="${H_BFIXT:-?}"
elif [ -n "$BL" ]; then
  SRC=seed
  BL_POLE="$(printf '%s' "$BL" | cut -d' ' -f1)"
  BL_SECS="$(printf '%s' "$BL" | cut -d' ' -f2)"
  BL_BAND="$(printf '%s' "$BL" | cut -d' ' -f3)"
  BL_FIXT="$(printf '%s' "$BL" | cut -d' ' -f5)"
else
  SRC=calibrating
fi

# ---------------------------------------------------------------------------------------
# CALIBRATING -- this width has fewer than K usable history rows and no tracked seed. Nothing is
# enforced -- print the comparison against the max so far, pass -- and the run records under
# admit_calibrating: freely while the width is young, at or below its max once it holds K rows.
# ---------------------------------------------------------------------------------------
if [ "$SRC" = calibrating ]; then
  printf '   CALIBRATING (%s/%s) -- pool width %s has %s usable history row(s) and no tracked row; pole %s %ss' \
    "$((H_N + 1))" "$HIST_K" "$JOBS" "$H_N" "$OBS_POLE" "$OBS_SECS"
  if [ "$H_N" -gt 0 ]; then printf ' against the max so far %s %ss' "$H_BPOLE" "$H_B"; fi
  printf '\n'
  [ "$H_STALE" -gt 0 ] && printf '   NOTE  %s history row(s) at pool %s name a pole directory that no longer exists and were ignored\n' "$H_STALE" "$JOBS"
  admit_calibrating # calibrating path
  exit 0
fi

# Whether the baseline's own pole was timed by this run. Under history it always was -- a row is
# usable only when its pole is in this run's durations -- so this decides anything only for a
# tracked SEED, and it is read only AFTER the ceiling below: growth past it fails or is reported
# whichever unit grew, and absence alone is never a pass.
BL_PRESENT="$(awk -v p="$BL_POLE" 'NF == 2 && $1 == p { print "y"; exit }' "$DUR" 2>/dev/null)"

# ---------------------------------------------------------------------------------------
# VERDICT 5 -- THE COMPARISON, ASYMMETRIC.
#
# Over the ceiling FAILS regardless of which unit is the max: a unit that is not the baseline
# pole growing past the pole's ceiling is the suite getting slower, exactly as much as the pole
# growing would be. A tracked SEED whose pole this run did not time is reported as such and still
# RECORDS: the row it writes is this width's history forming, and a seed never blocks.
# ---------------------------------------------------------------------------------------
CEIL="$(pole_ceiling "$BL_SECS" "$BL_BAND")"

if [ "$SRC" = history ]; then
  printf '   source: history -- max of %s usable row(s) at pool %s in %s (band %s%% from # history-band:); B'"'"'s row dispatched %s\n' \
    "$H_N" "$JOBS" "$HIST" "$BL_BAND" "$H_BCOUNT"
else
  printf '   CALIBRATING (%s/%s) -- source: the tracked SEED row for pool %s in %s, compared and reported, never enforced; history at this width holds %s of the %s usable rows that replace it\n' \
    "$((H_N + 1))" "$HIST_K" "$JOBS" "$BASE" "$H_N" "$HIST_K"
fi
[ "$H_STALE" -gt 0 ] && printf '   NOTE  %s history row(s) at pool %s name a pole directory that no longer exists and were ignored\n' "$H_STALE" "$JOBS"

if ! pole_verdict "$OBS_SECS" "$BL_SECS" "$BL_BAND"; then
  # A SEED NEVER BLOCKS. Above its ceiling the run is reported and passed: the operator ruled the
  # hand-calibrated rows the defect, and a seed that could FAIL a push would also stop the history
  # that replaces it from ever forming. It records under the same admission as a calibrating run.
  if [ "$SRC" = seed ]; then
    printf '   ABOVE SEED  %s at %ss is above the tracked seed %s at %ss (band %s%%, ceiling %ss, pool %s) -- not enforced while pool %s calibrates\n' \
      "$OBS_POLE" "$OBS_SECS" "$BL_POLE" "$BL_SECS" "$BL_BAND" "$CEIL" "$JOBS" "$JOBS"
    admit_calibrating
    exit 0
  fi
  printf '   FAIL  the suite pole has GROWN: %s at %ss against baseline %s at %ss (band %s%%, ceiling %ss, pool %s, baseline taken over %s fixtures)\n' \
    "$OBS_POLE" "$OBS_SECS" "$BL_POLE" "$BL_SECS" "$BL_BAND" "$CEIL" "$JOBS" "$BL_FIXT"
  printf '         The suite is POLE-BOUND -- its wall clock is this one number, not the sum over the pool.\n'
  printf '         A LOADED BOX IS NOT A REASON TO RAISE THE BASELINE. Re-run the gate first; the band already\n'
  printf '         covers the run-to-run spread this figure was calibrated against.\n'
  printf '         The baseline is the recorded history at pool %s in %s.\n' "$JOBS" "$HIST"
  printf '         A real change to %s or to what it exercises re-calibrates this width by dropping its rows:\n' "$OBS_POLE"
  # %q, never hand-written single quotes: a history path holding a quote would otherwise print a
  # command that splits at it, in the one message an operator is told to paste.
  printf "           awk -F'\\\\t' -v w=%s '\$1 != w' %q > %q && mv %q %q\n" "$JOBS" "$HIST" "$HIST.new" "$HIST.new" "$HIST"
  printf '         after which the next %s green pushes at pool %s are CALIBRATING. Nothing is recorded by a failing run.\n' "$HIST_K" "$JOBS"
  exit 1
fi

if [ -z "$BL_PRESENT" ]; then
  printf '   SEED POLE NOT TIMED -- %s has no row in this run, and the max it did time (%s %ss) is within %s'"'"'s ceiling of %ss; reported, and recorded toward this width'"'"'s history\n' \
    "$BL_POLE" "$OBS_POLE" "$OBS_SECS" "$BL_POLE" "$CEIL"
  admit_calibrating # D1: an untimed seed pole still records
  exit 0
fi

printf '   pole %s %ss against baseline %s %ss (band %s%%, ceiling %ss, pool %s)\n' \
  "$OBS_POLE" "$OBS_SECS" "$BL_POLE" "$BL_SECS" "$BL_BAND" "$CEIL" "$JOBS"

# NOTES, both non-failing.
#
# The pole MOVING is not growth and must not be reported as it: the suite is as fast as its
# longest unit whatever that unit is called. It is worth saying out loud because a baseline
# pinned to a fixture that is no longer the pole is watching the wrong number while passing.
#
# UNDER A HISTORY SOURCE THE REMEDY IS THE DROP COMMAND, never "edit the row": the tracked row is not
# read at a width with history, so an operator told to lower it edits a file that changes nothing.
# The same %q-quoted command the FAIL text prints, so it is pasteable whatever the path holds.
drop_hint() {
  printf "         Re-baseline pool %s by dropping its rows: awk -F'\\\\t' -v w=%s '\$1 != w' %q > %q && mv %q %q\n" \
    "$JOBS" "$JOBS" "$HIST" "$HIST.new" "$HIST.new" "$HIST"
}
if [ "$OBS_POLE" != "$BL_POLE" ]; then
  printf '   NOTE  the pole has moved to %s; the baseline still names %s. Consider re-baselining -- a baseline pinned to a unit that is no longer longest passes while watching the wrong number.\n' "$OBS_POLE" "$BL_POLE"
  [ "$SRC" = history ] && drop_hint
fi
# A baseline more than twice the observed figure is a ratchet that has stopped ratcheting: it
# would take a 100%% regression to fire. NO DOWNWARD FAIL, deliberately -- see the header.
if [ "$((OBS_SECS * 2))" -lt "$BL_SECS" ]; then
  printf '   NOTE  the baseline is more than twice this run'"'"'s figure -- lower the baseline. A ceiling this far above the real cost would take a doubling to fire.\n'
  [ "$SRC" = history ] && drop_hint
fi
# ADMISSION. Under a tracked seed (fewer than K usable rows) a pass records under admit_calibrating.
# Under history a pass records only at or below B, so B never moves except by a reviewed drop.
if [ "$SRC" = history ] && [ "$OBS_SECS" -gt "$BL_SECS" ]; then
  record_pole no "${OBS_SECS}s is inside the band but above B=${BL_SECS}s; only a pole at or below B is admitted, so B moves only by a reviewed re-calibration"
elif [ "$SRC" = history ]; then
  record_pole yes ""
else
  admit_calibrating
fi
exit 0
