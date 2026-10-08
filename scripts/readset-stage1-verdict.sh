#!/usr/bin/env bash
# readset-stage1-verdict.sh -- score the LAST THREE stage-1 runs recorded by readset-stage1-run.sh.
#
# Usage: bash scripts/readset-stage1-verdict.sh [--self-probe]
#   --self-probe  runs only the self-probe and prints how many probes answered as expected
#   exit 0  MET      -- one line
#   exit 1  NOT-MET  -- one line per failed arm per run/subject; every arm is evaluated
#   exit 2  REFUSED  -- one line naming why (the self-probe failing is a refusal too)
#
# DISTRIBUTION-ONLY. The ledger is read from
#   $(git rev-parse --git-common-dir)/ai-dlc-readset-stage1.ledger
# or from AI_DLC_READSET_STAGE1_LEDGER when set. The wrapper writes TWO lines per run:
#   RUN_DIR<TAB>started<TAB>start-epoch<TAB>HEAD-sha                  before the deriver launches
#   RUN_DIR<TAB>rc<TAB>start-epoch<TAB>end-epoch<TAB>HEAD-sha         when it ends (rc may be `killed`)
# and each RUN_DIR holds root/ (the deriver's trace root), deriver.log, rc and load.tsv.
#
# THE LAST SIX NON-EMPTY LINES MUST READ started/terminal three times over, each terminal directly
# preceded by its OWN started line (same RUN_DIR, start-epoch and HEAD). A `kill -9` of the wrapper
# writes the started line and no terminal; a ledger that dropped that run would let the three runs
# either side of it read as consecutive. So a started line with no terminal after it, a terminal
# with no started line before it, and a malformed line anywhere in those six are each a REFUSAL --
# never a skip. A killed run OLDER than the last three pairs does not block, exactly as an earlier
# `killed` terminal does not: the ledger is append-only, and a rule over the whole file would wedge
# the scorer forever on one `kill -9`.
#
# NO ROOTS ON THE COMMAND LINE. Consecutiveness is a property of the ledger; a scorer that took
# three roots by argument would let a reader pick three good runs out of many. For the same reason
# a last-three line that does not resolve is a REFUSAL, never a skip to an earlier line.
#
# THE SELF-PROBE RUNS FIRST, before the ledger is read, under `mktemp -d`. It seeds one world per
# arm firing alone plus a near-miss for each, from real-shape files, and drives the SAME functions
# the scoring below calls. Any probe answering wrong is exit 2: a scorer that cannot fire must not
# report MET.
#
# CITED DERIVER EMISSIONS (core/scripts/derive-fixture-readsets.sh): the sandbox banner
# `sandbox tracer: fixtures run as` (say, :611); `copying the tree to <TREE>` (:644); the
# `uncommitted path(s)` note (:707); the per-fixture verdict lines `  <fx> OMITTED (<why>)` (:1037)
# and `  <fx> <n> paths` (:1041); the reason `LOSS CANARY: unreadable` assembled at :1009 from
# readset_loss_canary's `unreadable` (:601); the `.git` exclusion predicate (:733). Under the
# sandbox tracer the deriver writes `.raw` (:836), `.win` (:951/:953), `.canary` (:985 via the
# redirect at :597, which creates the file even when comm writes nothing), and `.set` (:999) for
# every subject the loop reached -- so each must EXIST, and a clean canary is an EMPTY file.
set -uo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR 2>/dev/null

# THE SUBJECTS, in the deriver's loop order (the A4 window runs from the first to the last).
# scripts/readset-stage1-run.sh carries the same five; a run whose deriver.log names a subject
# outside this set is refused (R6), so a drift between the two copies refuses rather than scores.
SUBJECTS="enforcement-map-sites enforcement-map-sites-b enforcement-map-sites-c validator-arm-selection validator-arm-selection-b"
FIRST_SUBJECT="enforcement-map-sites"
LAST_SUBJECT="validator-arm-selection-b"
LOAD_FLOOR="4.5"

refuse() { echo "REFUSED: $*"; exit 2; }

# ------------------------------------------------------------------ helpers ----
# A `.raw` timestamp (`YYYY-MM-DD HH:MM:SS.mmm`, LOCAL time, no zone) to epoch seconds. The
# fraction is FLOORED for a window start and CEILED for a window end, so a load sample taken in the
# boundary second counts as inside.
ts_epoch() { # $1 timestamp  $2 floor|ceil
  local whole frac e
  whole="${1%.*}"; frac="${1#*.}"; [ "$frac" != "$1" ] || frac=0
  e="$(date -j -f '%Y-%m-%d %H:%M:%S' "$whole" +%s 2>/dev/null)" || return 1
  case "$e" in ''|*[!0-9]*) return 1 ;; esac
  case "$frac" in ''|*[!0-9]*) return 1 ;; esac
  if [ "$2" = ceil ] && [ "$((10#$frac))" -gt 0 ]; then e=$((e + 1)); fi
  printf '%s\n' "$e"
}

# The A4 window of one run: `<start> <end>` epochs, from the LAST readset-sentinel line of the
# first subject's .raw to the FIRST readset-end line of the last subject's .raw.
run_window() { # $1 RUN_DIR
  local w="$1/root/w" sl el s e
  sl="$(awk '/readset-sentinel/ { l = $1 " " $2 } END { print l }' "$w/$FIRST_SUBJECT.raw" 2>/dev/null)"
  el="$(awk '/readset-end/ { print $1 " " $2; exit }' "$w/$LAST_SUBJECT.raw" 2>/dev/null)"
  [ -n "$sl" ] && [ -n "$el" ] || return 1
  s="$(ts_epoch "$sl" floor)" || return 1
  e="$(ts_epoch "$el" ceil)" || return 1
  [ "$s" -le "$e" ] || return 1
  printf '%s %s\n' "$s" "$e"
}

# Load samples inside [start, end]: prints `<count> <peak>`; peak is `-` when count is 0.
window_load() { # $1 load.tsv  $2 start  $3 end
  awk -F'\t' -v s="$2" -v e="$3" '
    $1 ~ /^[0-9]+$/ && $2 ~ /^[0-9]+(\.[0-9]+)?$/ && $1 + 0 >= s + 0 && $1 + 0 <= e + 0 {
      n++; if (n == 1 || $2 + 0 > p + 0) p = $2 }
    END { if (n == 0) print "0 -"; else print n " " p }' "$1"
}

# ------------------------------------------------------------------ refusals ----
# Each prints a reason and returns 1 when the run must be refused.

# THE DERIVER'S DEFAULT PROFILE, rendered for a resolved trace root. This is the deriver's own
# default-profile `printf` with "$TREE" "$MARKDIR" "$TREE" spelled as root/t, root/m, root/t (it
# resolves the root with `pwd -P` first). It is a COPY of one format string, and the fixture binds the
# copy: it extracts the format from both files and refuses unless they are byte-identical, and it seeds
# every run's sandbox.sb from the DERIVER's format, so a drift fails the ALL-MET world. The trailing
# root-literal clause (BL-470) means R0 refuses every stage-1 run dir recorded before it landed: their
# sandbox.sb lacks that line.
render_profile() { # $1 resolved trace root
  printf '(version 3)\n(allow default)\n(allow file* process-exec* (subpath "%s") (subpath "%s") (with report))\n(allow file-read-metadata file-test-existence (literal "%s"))\n' "$1/t" "$1/m" "$1/t"
}

# R0 also refuses a SUBSTITUTED profile. AI_DLC_READSET_SANDBOX_PROFILE (:684) replaces the
# default, and a narrower one reports fewer operations -- fewer drops, a cleaner canary -- so it
# could score MET for a profile no stage-1 criterion was written about.
r0_sandbox() { # $1 RUN_DIR  $2 scratch dir
  local rr
  grep -qF 'sandbox tracer: fixtures run as' "$1/deriver.log" 2>/dev/null \
    || { echo "R0 $1: deriver.log carries no 'sandbox tracer: fixtures run as' line -- not a sandbox run"; return 1; }
  [ -f "$1/root/w/sandbox.sb" ] || { echo "R0 $1: root/w/sandbox.sb is absent -- not a sandbox run"; return 1; }
  [ -d "$1/root/m" ] || { echo "R0 $1: root/m/ is absent -- not a sandbox run"; return 1; }
  rr="$(cd "$1/root" 2>/dev/null && pwd -P)" || { echo "R0 $1: root/ does not resolve"; return 1; }
  render_profile "$rr" > "$2/r0.sb" || { echo "R0 $1: cannot render the default profile"; return 1; }
  cmp -s "$2/r0.sb" "$1/root/w/sandbox.sb" \
    || { echo "R0 $1: root/w/sandbox.sb is not the deriver's default profile for this root -- a substituted profile"; return 1; }
  return 0
}

# RL: the last six ledger lines are three started/terminal PAIRS. Walked from the END, so the reason
# names the defect at the position it occupies: a started line where a terminal belongs is a run
# that recorded no terminal (a `kill -9`); a terminal where a started line belongs, or a started
# line naming another run, is a terminal not preceded by its own started line.
rl_pairs() { # $1 a file holding the last six non-empty ledger lines
  local j k t s tr tc ts te th sr sc ss sh sx tx
  for k in 3 2 1; do
    t=$((2 * k)); s=$((t - 1))
    IFS="$(printf '\t')" read -r tr tc ts te th tx <<EOF
$(sed -n "${t}p" "$1")
EOF
    IFS="$(printf '\t')" read -r sr sc ss sh sx <<EOF
$(sed -n "${s}p" "$1")
EOF
    if [ "$tc" = started ]; then
      echo "RL ledger line $t of the last six: $tr started at $ts and recorded no terminal line -- a killed run is never skipped"; return 1
    fi
    [ -n "$tr" ] && [ -n "$tc" ] && [ -n "$th" ] && [ -z "$tx" ] \
      || { echo "RL ledger line $t of the last six is not RUN_DIR<TAB>rc<TAB>start<TAB>end<TAB>sha"; return 1; }
    case "$ts$te" in ''|*[!0-9]*) echo "RL ledger line $t of the last six carries a non-numeric window ($ts-$te)"; return 1 ;; esac
    [ "$sc" = started ] && [ -n "$sh" ] && [ -z "$sx" ] \
      || { echo "RL ledger line $t of the last six: the terminal line for $tr is not preceded by its own started line"; return 1; }
    [ "$sr" = "$tr" ] && [ "$ss" = "$ts" ] && [ "$sh" = "$th" ] \
      || { echo "RL ledger line $t of the last six: the terminal line for $tr is preceded by the started line of $sr ($ss) -- not its own"; return 1; }
  done
  return 0
}

r1_bound() { # $1 RUN_DIR
  local logged want
  logged="$(awk 'index($0, "copying the tree to ") { sub(/^.*copying the tree to /, ""); print; exit }' "$1/deriver.log" 2>/dev/null)"
  want="$(cd "$1/root" 2>/dev/null && pwd -P)" || { echo "R1 $1: root/ does not resolve"; return 1; }
  want="$want/t"
  [ -n "$logged" ] && [ "$logged" = "$want" ] \
    || { echo "R1 $1: deriver.log copied the tree to '${logged:-<no line>}', not to $want -- the log is not this root's"; return 1; }
  return 0
}

r3_inputs() { # $1 RUN_DIR
  local fx ext
  for fx in $SUBJECTS; do
    for ext in win set canary raw; do
      [ -f "$1/root/w/$fx.$ext" ] || { echo "R3 $1: root/w/$fx.$ext is absent -- the deriver never reached $fx"; return 1; }
    done
  done
  return 0
}

r6_subjects() { # $1 RUN_DIR -- every per-fixture verdict line names one of the five
  local foreign
  foreign="$(awk -v subj=" $SUBJECTS " '
    substr($0, 1, 2) == "  " && ($2 == "OMITTED" || $3 == "paths") && index(subj, " " $1 " ") == 0 { print $1; exit }' "$1/deriver.log")"
  [ -z "$foreign" ] || { echo "R6 $1: deriver.log traced '$foreign', which is not a stage-1 subject -- a superset is not a stage-1 run"; return 1; }
  return 0
}

# R2: three DISTINCT runs. $1..$3 RUN_DIRs, $4..$9 start/end epochs from the ledger.
r2_distinct() {
  local a b c fx
  a="$(cd "$1/root" 2>/dev/null && pwd -P)"; b="$(cd "$2/root" 2>/dev/null && pwd -P)"; c="$(cd "$3/root" 2>/dev/null && pwd -P)"
  [ -n "$a" ] && [ -n "$b" ] && [ -n "$c" ] || { echo "R2: a root does not resolve"; return 1; }
  if [ "$a" = "$b" ] || [ "$a" = "$c" ] || [ "$b" = "$c" ]; then
    echo "R2: two ledger lines resolve to one root ($a / $b / $c) -- not three runs"; return 1
  fi
  for fx in $SUBJECTS; do
    if cmp -s "$1/root/w/$fx.raw" "$2/root/w/$fx.raw" || cmp -s "$1/root/w/$fx.raw" "$3/root/w/$fx.raw" \
       || cmp -s "$2/root/w/$fx.raw" "$3/root/w/$fx.raw"; then
      echo "R2: $fx.raw is byte-identical in two runs -- a copied run, not a trace"; return 1
    fi
  done
  if [ "$4" -le "$5" ] && [ "$5" -lt "$6" ] && [ "$6" -le "$7" ] && [ "$7" -lt "$8" ] && [ "$8" -le "$9" ]; then
    return 0
  fi
  echo "R2: the ledger windows are not time-ordered and disjoint ($4-$5, $6-$7, $8-$9)"; return 1
}

r4_same_tree() { # $1..$3 RUN_DIRs
  local h1 h2 h3 rd
  h1="$(git -C "$1/root/t" rev-parse HEAD 2>/dev/null)"; h2="$(git -C "$2/root/t" rev-parse HEAD 2>/dev/null)"; h3="$(git -C "$3/root/t" rev-parse HEAD 2>/dev/null)"
  [ -n "$h1" ] && [ "$h1" = "$h2" ] && [ "$h2" = "$h3" ] \
    || { echo "R4: the three trees are not at one HEAD (${h1:-?} ${h2:-?} ${h3:-?}) -- A6 would compare different trees"; return 1; }
  cmp -s "$1/root/w/copy.list" "$2/root/w/copy.list" && cmp -s "$2/root/w/copy.list" "$3/root/w/copy.list" \
    || { echo "R4: root/w/copy.list differs across the three runs -- A6 would compare different trees"; return 1; }
  for rd in "$1" "$2" "$3"; do
    if grep -qF 'uncommitted path(s)' "$rd/deriver.log"; then
      echo "R4 $rd: deriver.log carries the 'uncommitted path(s)' note -- the tree carried uncommitted work"; return 1
    fi
  done
  return 0
}

# ------------------------------------------------------------------ arms ----
# Each prints one NOT-MET line per failure and returns 1 on failure. FIELD-EXACT names: `$1 == fx`.

a1_omitted() { # $1 deriver.log  $2 fx  $3 label
  local hit
  hit="$(awk -v f="$2" '$1 == f && $2 == "OMITTED" { print; exit }' "$1")"
  [ -z "$hit" ] || { echo "NOT-MET $3 $2 A1: OMITTED by the deriver:$hit"; return 1; }
  return 0
}

a2_dropped() { # $1 .win  $2 fx  $3 label
  local n
  n="$(grep -c 'dropped during' "$1" 2>/dev/null)"
  case "$n" in ''|*[!0-9]*) echo "NOT-MET $3 $2 A2: $1 could not be read"; return 1 ;; esac
  [ "$n" -eq 0 ] || { echo "NOT-MET $3 $2 A2: the stream dropped reports $n time(s) in the window"; return 1; }
  return 0
}

a3_canary() { # $1 .canary  $2 deriver.log  $3 fx  $4 label
  local rc=0
  if [ -s "$1" ]; then
    echo "NOT-MET $4 $3 A3: the loss canary holds $(grep -c . "$1") path(s) read by the fixture and absent from the stream"; rc=1
  fi
  if awk -v f="$3" '$1 == f && $2 == "OMITTED" && index($0, "LOSS CANARY: unreadable") { found = 1 } END { exit !found }' "$2"; then
    echo "NOT-MET $4 $3 A3: the loss canary was unreadable"; rc=1
  fi
  return "$rc"
}

a5_paths() { # $1 deriver.log  $2 .set  $3 fx  $4 label
  local logged n
  logged="$(awk -v f="$3" '$1 == f && $3 == "paths" { print $2; exit }' "$1")"
  [ -n "$logged" ] || { echo "NOT-MET $4 $3 A5: deriver.log carries no '$3 <n> paths' line -- it was not mapped"; return 1; }
  n="$(grep -c . "$2" 2>/dev/null)"
  case "$n" in ''|*[!0-9]*) echo "NOT-MET $4 $3 A5: $2 could not be read"; return 1 ;; esac
  [ "$logged" = "$n" ] || { echo "NOT-MET $4 $3 A5: deriver.log says $logged paths, $2 holds $n"; return 1; }
  return 0
}

a4_load() { # $1 load.tsv  $2 start  $3 end  $4 label
  local cp peak
  cp="$(window_load "$1" "$2" "$3")"; peak="${cp#* }"
  [ "${cp%% *}" -gt 0 ] || { echo "NOT-MET $4 A4: no load sample inside the window $2-$3"; return 1; }
  if awk -v p="$peak" -v f="$LOAD_FLOOR" 'BEGIN { exit !(p + 0 >= f + 0) }'; then return 0; fi
  echo "NOT-MET $4 A4: peak 1-min load $peak inside the window $2-$3 is below $LOAD_FLOOR"; return 1
}

# A6: the three runs' path sets for fx, `.git` rows dropped by the deriver's own predicate, each
# kept only if the path exists in ANY run's tree. $1..$3 RUN_DIRs  $4 fx  $5 scratch dir.
# EXISTENCE IS `-e` OR `-L`, ANY FILE TYPE: a quarter of real `.set` rows are DIRECTORIES (`core`,
# `.githooks`, every `core/fixtures/<fx>`), so a `-f` filter drops them all from the comparison.
a6_present() { [ -e "$1" ] || [ -L "$1" ]; }
a6_compare() {
  local fx="$4" s="$5" i rd p
  for i in 1 2 3; do
    eval "rd=\"\$$i\""
    awk '$0 != "" && $0 != ".git" && index($0, ".git/") != 1' "$rd/root/w/$fx.set" | LC_ALL=C sort -u > "$s/a6.$i" \
      || { echo "NOT-MET $fx A6: run $i's set could not be read"; return 1; }
  done
  LC_ALL=C sort -u "$s/a6.1" "$s/a6.2" "$s/a6.3" > "$s/a6.union"
  : > "$s/a6.keep"
  while IFS= read -r p; do
    if a6_present "$1/root/t/$p" || a6_present "$2/root/t/$p" || a6_present "$3/root/t/$p"; then
      printf '%s\n' "$p" >> "$s/a6.keep"
    fi
  done < "$s/a6.union"
  for i in 1 2 3; do
    LC_ALL=C comm -12 "$s/a6.$i" "$s/a6.keep" > "$s/a6.f$i"
  done
  if cmp -s "$s/a6.f1" "$s/a6.f2" && cmp -s "$s/a6.f2" "$s/a6.f3"; then return 0; fi
  p="$(LC_ALL=C comm -3 "$s/a6.f1" "$s/a6.f2" | head -1)"
  [ -n "$p" ] || p="$(LC_ALL=C comm -3 "$s/a6.f2" "$s/a6.f3" | head -1)"
  echo "NOT-MET $fx A6: the three runs' present-path sets differ (first difference: $(printf '%s' "$p" | tr -d '\t'))"
  return 1
}

# ------------------------------------------------------------------ self-probe ----
PROBE_FAIL=0; PROBE_N=0
probe() { # $1 name  $2 expected status (0|1)  $3.. command
  local name="$1" want="$2" got
  shift 2
  PROBE_N=$((PROBE_N + 1))
  "$@" > /dev/null 2>&1; got=$?
  [ "$got" = "$want" ] || { echo "REFUSED: self-probe '$name' answered $got, expected $want"; PROBE_FAIL=1; }
}

# One real-shape run directory: every subject's files, a sandbox log, a tree with `p`.
seed_run() { # $1 RUN_DIR  $2 a distinguishing token for the raw files  $3 day-second offset
  local rd="$1" fx
  mkdir -p "$rd/root/t" "$rd/root/w" "$rd/root/m" || return 1
  render_profile "$(cd "$rd/root" && pwd -P)" > "$rd/root/w/sandbox.sb"
  {
    echo "[00:10:00] sandbox tracer: fixtures run as 'n8' under sandbox-exec; no root anywhere"
    echo "[00:10:01] copying the tree to $(cd "$rd/root" && pwd -P)/t"
  } > "$rd/deriver.log"
  for fx in $SUBJECTS; do
    {
      echo "Filtering the log data using \"sender == \"Sandbox\" AND composedMessage CONTAINS \"/x/\"\""
      echo "Timestamp               Ty Process[PID:TID]"
      echo "2026-10-05 00:10:1$3.313 Df kernel[0:1] (Sandbox) Sandbox: cat(1) allow file-read-data /x/m/.readset-sentinel"
      echo "2026-10-05 00:10:2$3.100 Df kernel[0:1] (Sandbox) Sandbox: bash(2) allow file-read-data /x/t/$2"
      echo "2026-10-05 00:10:3$3.832 Df kernel[0:1] (Sandbox) Sandbox: cat(3) allow file-test-existence /x/m/.readset-end"
    } > "$rd/root/w/$fx.raw"
    : > "$rd/root/w/$fx.win"; : > "$rd/root/w/$fx.canary"
    printf 'core/fixtures/%s/run.sh\n' "$fx" > "$rd/root/w/$fx.set"
    printf '  %-32s %5s paths\n' "$fx" 1 >> "$rd/deriver.log"
  done
  printf 'a\0b\0' > "$rd/root/w/copy.list"
}

self_probe() {
  local P r1 r2 r3 s fx
  P="$(mktemp -d "${TMPDIR:-/tmp}/readset-stage1-probe.XXXXXX")" || refuse "self-probe: mktemp failed"
  P="$(cd "$P" && pwd -P)"
  s="$P/scratch"; mkdir -p "$s"
  r1="$P/r1"; r2="$P/r2"; r3="$P/r3"
  seed_run "$r1" one 1; seed_run "$r2" two 2; seed_run "$r3" three 3
  fx="$FIRST_SUBJECT"

  # A6. Every world starts from three equal sets over files present in every tree.
  mkdir -p "$r1/root/t/d" "$r2/root/t/d" "$r3/root/t/d"
  for r in "$r1" "$r2" "$r3"; do
    : > "$r/root/t/present"; : > "$r/root/t/.gitignore"
    printf 'present\n' > "$r/root/w/$fx.set"
  done
  probe "A6 near-miss: equal sets compare EQUAL" 0 a6_compare "$r1" "$r2" "$r3" "$fx" "$s"
  printf 'absent/nowhere\npresent\n' > "$r2/root/w/$fx.set"
  probe "A6 near-miss: an absent-only difference compares EQUAL" 0 a6_compare "$r1" "$r2" "$r3" "$fx" "$s"
  mkdir -p "$r2/root/t/.git"; : > "$r2/root/t/.git/HEAD"
  printf '.git/HEAD\npresent\n' > "$r2/root/w/$fx.set"
  probe "A6 near-miss: a .git/ row difference compares EQUAL" 0 a6_compare "$r1" "$r2" "$r3" "$fx" "$s"
  printf '' > "$r2/root/w/$fx.set"
  probe "A6: a lost present path compares UNEQUAL" 1 a6_compare "$r1" "$r2" "$r3" "$fx" "$s"
  # P2 world: run 1's tree lacks d/p, runs 2-3 have it, run 2 lost it.
  : > "$r2/root/t/d/p"; : > "$r3/root/t/d/p"
  printf 'present\n' > "$r1/root/w/$fx.set"; printf 'present\n' > "$r2/root/w/$fx.set"; printf 'd/p\npresent\n' > "$r3/root/w/$fx.set"
  probe "A6: P2 world (run 1 tree lacks d/p, run 2 lost it) compares UNEQUAL" 1 a6_compare "$r1" "$r2" "$r3" "$fx" "$s"
  printf '.gitignore\npresent\n' > "$r1/root/w/$fx.set"; printf 'present\n' > "$r2/root/w/$fx.set"; printf '.gitignore\npresent\n' > "$r3/root/w/$fx.set"
  probe "A6: .gitignore lost in one run compares UNEQUAL" 1 a6_compare "$r1" "$r2" "$r3" "$fx" "$s"
  # OWN-TREE world: run 1's tree lacks d/p and run 1 REPORTS it; runs 2-3 have d/p and did not.
  # The P2 world above reads UNEQUAL under a per-run own-tree filter too, so it cannot tell the two
  # filters apart; this one can -- the own-tree filter drops d/p from run 1 alone and reads EQUAL.
  printf 'd/p\npresent\n' > "$r1/root/w/$fx.set"; printf 'present\n' > "$r2/root/w/$fx.set"; printf 'present\n' > "$r3/root/w/$fx.set"
  probe "A6: a path reported only by the run whose tree lacks it compares UNEQUAL (union, not own-tree)" 1 a6_compare "$r1" "$r2" "$r3" "$fx" "$s"
  # DIRECTORY world: `d` is a directory in every tree, reported by runs 1 and 3, lost from run 2. A
  # regular-file-only existence filter drops `d` from the comparison and reads EQUAL.
  printf 'd\npresent\n' > "$r1/root/w/$fx.set"; printf 'present\n' > "$r2/root/w/$fx.set"; printf 'd\npresent\n' > "$r3/root/w/$fx.set"
  probe "A6: a DIRECTORY row lost from one run compares UNEQUAL" 1 a6_compare "$r1" "$r2" "$r3" "$fx" "$s"
  printf 'present\n' > "$r1/root/w/$fx.set"; printf 'present\n' > "$r3/root/w/$fx.set"

  # A1 / A5, field-exact against the prefix-sharing names.
  printf '  %-32s OMITTED (the stream dropped reports 3 time(s) in this window) -- will always run\n' "enforcement-map-sites" > "$s/log.a1"
  probe "A1 fires on 'enforcement-map-sites OMITTED'" 1 a1_omitted "$s/log.a1" enforcement-map-sites x
  {
    printf '  %-32s OMITTED (fixture exited 1) -- will always run\n' "enforcement-map-sites-b"
    printf '  %-32s OMITTED (fixture exited 1) -- will always run\n' "enforcement-map-sites-c"
  } > "$s/log.bc"
  probe "A1 near-miss: -b/-c OMITTED does not fire for enforcement-map-sites" 0 a1_omitted "$s/log.bc" enforcement-map-sites x
  printf 'one\n' > "$s/set.1"
  probe "A5 fires for enforcement-map-sites on a log carrying only -b/-c lines" 1 a5_paths "$s/log.bc" "$s/set.1" enforcement-map-sites x
  printf '  %-32s %5s paths\n' "enforcement-map-sites" 1 > "$s/log.a5"
  probe "A5 near-miss: a matching paths line passes" 0 a5_paths "$s/log.a5" "$s/set.1" enforcement-map-sites x
  printf '  %-32s %5s paths\n' "enforcement-map-sites" 2 > "$s/log.a5n"
  probe "A5 fires on a paths count unequal to the .set" 1 a5_paths "$s/log.a5n" "$s/set.1" enforcement-map-sites x

  # A2 reads the .win, never the log. The notice is `log stream`'s own line, byte for byte as a real
  # .win carries it -- a seed of the reader's accept-set would pass a reader that keys on an ending
  # the producer never writes.
  printf '%s\n' '=== Messages dropped during live streaming (use `log show` to see what they were)' > "$s/win.drop"
  : > "$s/win.clean"
  probe "A2 fires on a .win carrying the drop notice (log silent)" 1 a2_dropped "$s/win.drop" enforcement-map-sites x
  probe "A2 near-miss: an empty .win passes" 0 a2_dropped "$s/win.clean" enforcement-map-sites x

  # A3.
  printf 'core/x.sh\n' > "$s/canary.1"; : > "$s/canary.0"; : > "$s/log.empty"
  probe "A3 fires on a 1-line .canary" 1 a3_canary "$s/canary.1" "$s/log.empty" enforcement-map-sites x
  probe "A3 near-miss: an empty .canary passes" 0 a3_canary "$s/canary.0" "$s/log.empty" enforcement-map-sites x
  printf '  %-32s OMITTED (LOSS CANARY: unreadable path(s) the fixture read) -- will always run\n' "enforcement-map-sites" > "$s/log.unr"
  probe "A3 fires on a 'LOSS CANARY: unreadable' OMITTED reason" 1 a3_canary "$s/canary.0" "$s/log.unr" enforcement-map-sites x

  # A4: the window is read off real-shape .raw lines; 5.0 before it, 4.4 / 4.5 inside it.
  local w ws we
  w="$(run_window "$r1")" || { echo "REFUSED: self-probe 'A4 window parse' could not read the seeded .raw window"; PROBE_FAIL=1; w="0 0"; }
  ws="${w% *}"; we="${w#* }"
  [ "$ws" -eq "$(date -j -f '%Y-%m-%d %H:%M:%S' '2026-10-05 00:10:11' +%s)" ] && [ "$we" -eq "$(date -j -f '%Y-%m-%d %H:%M:%S' '2026-10-05 00:10:32' +%s)" ] \
    || { echo "REFUSED: self-probe 'A4 window' read $ws-$we, not the seeded local-time 00:10:11-00:10:32"; PROBE_FAIL=1; }
  printf '%s\t5.00\n%s\t4.40\n' "$((ws - 30))" "$((ws + 5))" > "$s/load.low"
  printf '%s\t5.00\n%s\t4.50\n' "$((ws - 30))" "$((ws + 5))" > "$s/load.edge"
  probe "A4 fires on 5.0 before the window and 4.4 inside it" 1 a4_load "$s/load.low" "$ws" "$we" x
  probe "A4 passes at exactly 4.5 inside the window" 0 a4_load "$s/load.edge" "$ws" "$we" x
  # The window has an END: 6.00 sampled five seconds AFTER it must not count.
  printf '%s\t4.40\n%s\t6.00\n' "$((ws + 5))" "$((we + 5))" > "$s/load.after"
  probe "A4 fires on 4.4 inside the window and 6.0 after it" 1 a4_load "$s/load.after" "$ws" "$we" x

  # R0.
  probe "R0 near-miss: a sandbox run is accepted" 0 r0_sandbox "$r1" "$s"
  cp "$r2/deriver.log" "$s/log.keep"
  printf "[00:10:00] fs_usage runs as root; fixtures run as 'n8'\n" > "$r2/deriver.log"
  probe "R0 refuses an fs_usage-shaped log" 1 r0_sandbox "$r2" "$s"
  cp "$s/log.keep" "$r2/deriver.log"
  cp "$r2/root/w/sandbox.sb" "$s/sb.keep"
  printf '(version 3)\n(allow default)\n(allow file-read* (subpath "%s/t") (with report))\n' "$(cd "$r2/root" && pwd -P)" > "$r2/root/w/sandbox.sb"
  probe "R0 refuses a narrowed (substituted) profile" 1 r0_sandbox "$r2" "$s"
  cp "$s/sb.keep" "$r2/root/w/sandbox.sb"

  # RL: three started/terminal pairs, and a started line with no terminal among them.
  {
    printf '%s\tstarted\t10\th\n%s\t0\t10\t20\th\n' "$r1" "$r1"
    printf '%s\tstarted\t30\th\n%s\t0\t30\t40\th\n' "$r2" "$r2"
    printf '%s\tstarted\t50\th\n%s\t0\t50\t60\th\n' "$r3" "$r3"
  } > "$s/l.good"
  probe "RL near-miss: three started/terminal pairs are accepted" 0 rl_pairs "$s/l.good"
  {
    printf '%s\t0\t10\t20\th\n' "$r1"
    printf '%s\tstarted\t25\th\n' "$P/killed"
    printf '%s\tstarted\t30\th\n%s\t0\t30\t40\th\n' "$r2" "$r2"
    printf '%s\tstarted\t50\th\n%s\t0\t50\t60\th\n' "$r3" "$r3"
  } > "$s/l.killed"
  probe "RL refuses a started line with no terminal among the last runs" 1 rl_pairs "$s/l.killed"
  # A terminal preceded by ANOTHER run's started line: the killed run started between run 1's own
  # started line (now outside the six) and run 1's terminal. Every line is well-formed, so only the
  # RUN_DIR/epoch/HEAD equality refuses it.
  {
    printf '%s\tstarted\t15\th\n' "$P/killed"
    printf '%s\t0\t10\t20\th\n' "$r1"
    printf '%s\tstarted\t30\th\n%s\t0\t30\t40\th\n' "$r2" "$r2"
    printf '%s\tstarted\t50\th\n%s\t0\t50\t60\th\n' "$r3" "$r3"
  } > "$s/l.foreign"
  probe "RL refuses a terminal preceded by another run's started line" 1 rl_pairs "$s/l.foreign"

  # R2.
  probe "R2 near-miss: three distinct runs are accepted" 0 r2_distinct "$r1" "$r2" "$r3" 1 2 3 4 5 6
  ln -s "$r1" "$P/r1link"
  probe "R2 refuses one root under a symlinked spelling" 1 r2_distinct "$r1" "$P/r1link" "$r3" 1 2 3 4 5 6
  mkdir -p "$P/c2/root/w" "$P/c3/root/w"
  for fx in $SUBJECTS; do
    cp "$r1/root/w/$fx.raw" "$P/c2/root/w/$fx.raw"; cp "$r1/root/w/$fx.raw" "$P/c3/root/w/$fx.raw"
  done
  probe "R2 refuses three byte-identical copies" 1 r2_distinct "$r1" "$P/c2" "$P/c3" 1 2 3 4 5 6
  probe "R2 refuses overlapping ledger windows" 1 r2_distinct "$r1" "$r2" "$r3" 1 3 2 4 5 6
  # ONE subject copied, the other four distinct: still a copied run, and R2 refuses it.
  cp "$r2/root/w/enforcement-map-sites-b.raw" "$s/raw.keep"
  cp "$r1/root/w/enforcement-map-sites-b.raw" "$r2/root/w/enforcement-map-sites-b.raw"
  probe "R2 refuses ONE subject's .raw byte-identical across two runs" 1 r2_distinct "$r1" "$r2" "$r3" 1 2 3 4 5 6
  cp "$s/raw.keep" "$r2/root/w/enforcement-map-sites-b.raw"

  # R6, both verdict-line shapes.
  probe "R6 near-miss: the five subjects are accepted" 0 r6_subjects "$r1"
  cp "$r3/deriver.log" "$s/log.keep"
  printf '  %-32s %5s paths\n' "plan-shape" 3 >> "$r3/deriver.log"
  probe "R6 refuses a run that traced a sixth fixture" 1 r6_subjects "$r3"
  cp "$s/log.keep" "$r3/deriver.log"
  printf '  %-32s OMITTED (fixture exited 1) -- will always run\n' "plan-shape" >> "$r3/deriver.log"
  probe "R6 refuses a run that OMITTED a sixth fixture" 1 r6_subjects "$r3"

  [ "$PROBE_FAIL" -eq 0 ] || { echo "REFUSED: the self-probe failed (worlds kept under $P); the scorer is not trusted"; exit 2; }
  # Cleared only under the literal mktemp template, so no other path can reach the delete.
  case "$P" in */readset-stage1-probe.??????) rm -rf "$P" ;; esac
}

self_probe
if [ "${1:-}" = --self-probe ]; then
  echo "self-probe: $PROBE_N probes answered as expected"
  exit 0
fi
[ $# -eq 0 ] || refuse "usage: bash $0 [--self-probe] -- the scorer takes no roots; it reads the last three ledger lines"

# ------------------------------------------------------------------ the ledger ----
resolve_root() {
  local d="$1"
  while [ -n "$d" ] && [ "$d" != "/" ] && [ "$d" != "." ]; do
    if [ -e "$d/.git" ]; then printf '%s\n' "$d"; return 0; fi
    d="$(dirname "$d")"
  done
  return 1
}
if [ -n "${AI_DLC_READSET_STAGE1_LEDGER:-}" ]; then
  LEDGER="$AI_DLC_READSET_STAGE1_LEDGER"
else
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)" || refuse "cannot resolve the script directory"
  ROOT="$(resolve_root "$SCRIPT_DIR")" || refuse "no .git above $SCRIPT_DIR"
  CDIR="$(git -C "$ROOT" rev-parse --git-common-dir 2>/dev/null)" || refuse "cannot resolve the git common dir of $ROOT"
  case "$CDIR" in /*) ;; *) CDIR="$ROOT/$CDIR" ;; esac
  LEDGER="$CDIR/ai-dlc-readset-stage1.ledger"
fi
[ -r "$LEDGER" ] || refuse "the ledger $LEDGER is unreadable or absent -- no stage-1 run has been recorded"

SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/readset-stage1-verdict.XXXXXX")" || refuse "mktemp failed"
# Cleared on every exit, refusals included, and only under the literal mktemp template.
trap 'case "$SCRATCH" in */readset-stage1-verdict.??????) rm -rf "$SCRATCH" ;; esac' EXIT
awk 'NF > 0' "$LEDGER" | tail -n 6 > "$SCRATCH/last6" || refuse "cannot read the ledger $LEDGER"
NL="$(grep -c . "$SCRATCH/last6")" || NL=0
[ "$NL" -eq 6 ] || refuse "the ledger $LEDGER holds $NL line(s); stage 1 is scored over three runs, two lines each"
why="$(rl_pairs "$SCRATCH/last6")" || refuse "$why"
awk 'NR % 2 == 0' "$SCRATCH/last6" > "$SCRATCH/last3" || refuse "cannot read the ledger $LEDGER"

i=0
while IFS="$(printf '\t')" read -r rd rc st en sha extra; do
  i=$((i + 1))
  [ -n "$rd" ] && [ -n "$sha" ] && [ -z "$extra" ] || refuse "RL ledger line $i is not RUN_DIR<TAB>rc<TAB>start<TAB>end<TAB>sha"
  case "$st$en" in ''|*[!0-9]*) refuse "RL ledger line $i carries a non-numeric window ($st-$en)" ;; esac
  eval "RD$i=\"\$rd\"; ST$i=\"\$st\"; EN$i=\"\$en\"; LRC$i=\"\$rc\""
done < "$SCRATCH/last3"
[ "$i" -eq 3 ] || refuse "read $i ledger line(s), not 3"

# ------------------------------------------------------------------ refusals, per run ----
for i in 1 2 3; do
  eval "rd=\"\$RD$i\"; lrc=\"\$LRC$i\""
  [ -d "$rd" ] || refuse "RL run $i: $rd does not exist -- a missing run is never skipped"
  [ "$lrc" = 0 ] || refuse "RL run $i: $rd is recorded with rc '$lrc' -- a failed run is never skipped"
  frc="$(cat "$rd/rc" 2>/dev/null)"
  [ "$frc" = 0 ] || refuse "RL run $i: $rd/rc reads '${frc:-<absent>}', not 0"
  [ -f "$rd/deriver.log" ] || refuse "RL run $i: $rd/deriver.log is absent"
  [ -f "$rd/load.tsv" ] || refuse "RL run $i: $rd/load.tsv is absent"
  why="$(r0_sandbox "$rd" "$SCRATCH")" || refuse "$why"
  why="$(r1_bound "$rd")" || refuse "$why"
  why="$(r3_inputs "$rd")" || refuse "$why"
  why="$(r6_subjects "$rd")" || refuse "$why"
done
why="$(r2_distinct "$RD1" "$RD2" "$RD3" "$ST1" "$EN1" "$ST2" "$EN2" "$ST3" "$EN3")" || refuse "$why"
why="$(r4_same_tree "$RD1" "$RD2" "$RD3")" || refuse "$why"
for i in 1 2 3; do
  eval "rd=\"\$RD$i\""
  w="$(run_window "$rd")" || refuse "R5 run $i: no A4 window -- $FIRST_SUBJECT.raw has no readset-sentinel line or $LAST_SUBJECT.raw no readset-end line after it"
  cp="$(window_load "$rd/load.tsv" "${w% *}" "${w#* }")"
  [ "${cp%% *}" -gt 0 ] || refuse "R5 run $i: no load sample in $rd/load.tsv falls inside the window ${w% *}-${w#* }"
  eval "WS$i=\"\${w% *}\"; WE$i=\"\${w#* }\""
done

# ------------------------------------------------------------------ arms ----
FAILED=0
for i in 1 2 3; do
  eval "rd=\"\$RD$i\"; ws=\"\$WS$i\"; we=\"\$WE$i\""
  label="run$i($rd)"
  for fx in $SUBJECTS; do
    a1_omitted "$rd/deriver.log" "$fx" "$label" || FAILED=1
    a2_dropped "$rd/root/w/$fx.win" "$fx" "$label" || FAILED=1
    a3_canary "$rd/root/w/$fx.canary" "$rd/deriver.log" "$fx" "$label" || FAILED=1
    a5_paths "$rd/deriver.log" "$rd/root/w/$fx.set" "$fx" "$label" || FAILED=1
  done
  a4_load "$rd/load.tsv" "$ws" "$we" "$label" || FAILED=1
done
for fx in $SUBJECTS; do
  a6_compare "$RD1" "$RD2" "$RD3" "$fx" "$SCRATCH" || FAILED=1
done

if [ "$FAILED" -ne 0 ]; then exit 1; fi
echo "MET: stage 1 -- three consecutive sandbox runs ($RD1, $RD2, $RD3), every subject mapped with no drop notice and a clean canary, peak load >= $LOAD_FLOOR inside every window, identical present-path sets"
exit 0
