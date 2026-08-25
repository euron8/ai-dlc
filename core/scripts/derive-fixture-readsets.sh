#!/usr/bin/env bash
# Derive each fixture's READ-SET by tracing it, and write the map the pre-push suite uses to
# skip fixtures a change cannot affect.
#
# RUN AS, in this distribution:  sudo bash core/scripts/derive-fixture-readsets.sh [--all | --list "<fixtures>"]
#         in an installed tree:  sudo bash scripts/ai-dlc/derive-fixture-readsets.sh [--all | --list "<fixtures>"]
#
# ---------------------------------------------------------------------------------------
# WHY IT LIVES IN core/scripts/ AND SHIPS. It did not, for the whole life of the read-set
# skip: v0.294.0 shipped `core/git-hooks/pre-push`, which READS the map, and left the program
# that WRITES it in the distribution's own `scripts/`. A consumer therefore reached the
# `no read-set map -- running all N` line on every push it has ever made, and there was no
# command anywhere in its tree that could produce one. Measured on the reference consumer at
# 0.403.0: 155 fixtures on every push, 2m30s wall clock, against a 2m00s tool timeout that
# SIGKILLed the push twice in one sprint. The reader shipping without the producer is invisible
# by construction, because the fallback it takes is the correct and safe one.
#
# THE TWO LAYOUTS ARE NOT THE SAME TREE, AND NOTHING HERE MAY ASSUME EITHER. install.sh splits
# what shares a parent in the distribution, and the fixture suite each hook drives has a
# different root on each side -- `core/fixtures/` here, the consumer's own `tests/fixtures/`
# there. Both are RESOLVED below and neither is written into a default, because a producer
# that guessed the wrong root would write a map keyed on fixture names the runner never looks
# up, and the runner's fail-closed "unmapped means run it" would turn that into a suite that
# simply stopped skipping -- correct, silent, and indistinguishable from the map being absent.
#
# ---------------------------------------------------------------------------------------
# WHY A MAP AT ALL. `scripts/suite-content-key.sh` already skips the WHOLE suite when nothing
# moved. What it cannot do is skip PART of it, so any change to anything pays the full
# makespan. This map is the finer skip inside that outer one. The content key is NOT touched:
# it stays the safe outer gate, and when this map is in doubt the correct fallback is the full
# run.
#
# WHY TRACING RATHER THAN THE DECLARED BINDINGS. Measured on this tree: 118 drivable fixtures,
# 40 named in an enforcement-map `fixtures:` binding, 78 named nowhere. A skip built on
# declarations would skip those 78 BLIND. And the 40 that are bound declare 1-3 paths while
# reading 5-31 -- the binding names what a CLAUSE is proven by, not what the fixture READS.
# Total paths a declaration-based skip would have missed: ~8000.
#
# WHY "UNCHANGED FIXTURE" IS NOT "UNAFFECTED FIXTURE". v0.293.0 changed
# scripts/validate-plan-shape.sh and touched zero fixtures; `plan-shape` went red, correctly,
# because its SUBJECT moved. A filter keyed on "did this fixture's own files change" would
# have skipped exactly the fixture that caught the regression. This script's own control
# asserts that case still selects `plan-shape` -- in THIS distribution only, since neither the
# fixture nor the validator exists in an installed tree. The pair of controls that holds
# everywhere is derived instead, and both live in the controls block below.
#
# ---------------------------------------------------------------------------------------
# THE HAZARD, AND EVERY DESIGN CHOICE BELOW ANSWERS IT. Under-record one path and the result
# is not a slow suite -- it is a SILENTLY SKIPPED one. A fixture that never ran reports
# nothing and the summary says green. So:
#
#   * A fixture whose trace did not complete cleanly is OMITTED FROM THE MAP, and the runner
#     always runs a fixture it has no entry for. Absence means "run it", never "needs nothing".
#   * The read-set is the UNION of two tracers with disjoint blind spots. Over-recording costs
#     makespan; under-recording hides a regression. They are not symmetric.
#
# TWO TRACERS, AND NEITHER IS SUFFICIENT ALONE:
#   fs_usage  sees open() AND stat64() -- a dependency reached only by `[ -f x ]`, or a
#             NEGATIVE lookup on a path that does not exist, is invisible to any read-based
#             method. Needs root. DROPS EVENTS UNDER LOAD (measured: 11 on one heavy fixture).
#   atime     sees reads only, never stat(). Cannot drop. Independent of how the path was
#             SPELLED, because it is a property of the file rather than of the string used to
#             reach it -- which is why it catches what a path-prefix filter misses.
#
# WHY atime IS FORCED OLD FIRST. APFS is relatime-like: measured on this machine, a second
# read of a file does NOT advance its atime. A naive before/after watermark therefore misses
# every file read twice, which is the fatal under-record. Forcing atime to 2001 before each
# fixture defeats relatime by construction, proven each run by the unread control below.
#
# WHY dtruss IS NOT USED. SIP restricts /bin/bash, and ROOT DOES NOT LIFT THAT:
# `dtrace: failed to execute /bin/bash: Operation not permitted`. Disabling SIP would buy
# nothing -- dtruss reports the same opens and stats fs_usage already reports.
#
# WHY THE FIXTURES RUN UNPRIVILEGED. fs_usage needs root; the fixture must not have it.
# Measured: check-22-spawn-ledger PASSES 16/16 as a normal user and FAILS 9/16 as root,
# because one arm asserts a settings-readability REFUSAL and root reads regardless of
# permissions. The red verdict is the harmless half. The dangerous half is that an arm root
# SKIPS reads fewer files, so the read-set comes back short -- and a short read-set skips that
# fixture silently forever after. Running as root would corrupt the map, not just the verdict.
#
# WHY AN ISOLATED COPY. fs_usage is system-wide. Tracing the live tree folds every concurrent
# reader -- editor, agent, a statusline's `git status` -- into the read-set. A private tree
# gives attribution with no pid bookkeeping. Even so the trace is filtered by PROCESS as well:
# measured, fseventsd walked the fresh copy and put 203 spurious `.git/**` paths into one
# fixture's set.
set -uo pipefail

# THE ROOT IS RESOLVED, NEVER COUNTED IN `..` HOPS. This file sits at `core/scripts/` here and
# at `scripts/ai-dlc/` in an installed tree; a fixed number of hops is correct in exactly one of
# them and silently names a subdirectory in the other. `git rev-parse` is the marker both
# layouts share, and it is what both pre-push hooks already use.
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
[ -n "$REPO_ROOT" ] && [ -d "$REPO_ROOT/.git" ] || {
  echo "ERROR: not inside a git work tree. The map is a tracked artifact of one repository and the trace copies its .git; there is nothing to derive from here." >&2; exit 1; }
MAP="$REPO_ROOT/.ai-dlc-fixture-readsets.tsv"
TRACE_ROOT="${AI_DLC_READSET_TRACE_ROOT:-/private/tmp/ai-dlc-readset}"
TREE="$TRACE_ROOT/t"
WORK="$TRACE_ROOT/w"
SENTINEL="$TREE/.readset-sentinel"

# System daemons that walk the filesystem on their own schedule and are never part of a
# fixture's work. Deliberately NOT a general noise list: a fixture's own helpers (bash, git,
# awk, sed, python3, cp) are absent from it, because a `cp` reading a source file IS a real
# dependency and fixtures copy trees constantly.
DAEMONS='fseventsd|mds|mds_stores|mdworker|mdworker_shared|mdsync|Spotlight|distnoted|cfprefsd|syspolicyd|opendirectoryd|securityd|notifyd|logd|UserEventAgent|revisiond|backupd|diskarbitrationd|coreauthd|trustd|nsurlsessiond|Finder|fmfd|photoanalysisd|cloudd|bird|CrashReporter'

die() { echo "ERROR: $*" >&2; exit 1; }
say() { echo "[$(date +%H:%M:%S)] $*"; }

# THE FIXTURE ROOT IS READ OFF THE RUNNER THAT WILL CONSUME THE MAP, not restated here. The
# map's key is a fixture BASENAME and the runner looks it up against the directories its own
# glob produced; a producer that enumerated a different root would emit keys nothing ever
# matches, every fixture would be "unmapped", and the runner would fail closed by running all
# of them. That is the correct behaviour and it is why the drift is undetectable from the
# outside -- the suite goes on passing and merely stops skipping.
#
# `.githooks/pre-push` is the runner in BOTH layouts: this repo's own gate, and, in an
# installed tree, the copy install.sh puts there from core/git-hooks/pre-push (a consumer's
# .git/hooks/pre-push is a shim that execs it). Invariant I66 binds those to be one program.
#
# EXACTLY ONE MATCH IS REQUIRED. Zero means the runner no longer iterates a fixture glob and
# this script's whole premise has moved; more than one means the suite has two roots and a map
# keyed on basenames alone cannot say which directory an entry belongs to.
RUNNER="$REPO_ROOT/.githooks/pre-push"
[ -r "$RUNNER" ] || die "cannot read $RUNNER. It is the program that consumes this map, and the fixture root is read off its own glob rather than assumed."
FIXTURE_ROOT="$(sed -n 's|^[[:space:]]*for d in \([A-Za-z0-9_./-]*\)/\*/;.*|\1|p' "$RUNNER" | sort -u)"
N_ROOT="$(printf '%s\n' "$FIXTURE_ROOT" | grep -c .)"
[ "$N_ROOT" -eq 1 ] || die "read $N_ROOT fixture root(s) from $RUNNER, need exactly 1 (got: $(printf '%s' "$FIXTURE_ROOT" | tr '\n' ' ')). Zero means its fixture glob has changed shape and this producer is now guessing; more than one means a basename key cannot name a directory."
[ -d "$REPO_ROOT/$FIXTURE_ROOT" ] || die "$RUNNER drives '$FIXTURE_ROOT/' and no such directory exists under $REPO_ROOT."

# READSET_MERGE_BEGIN
# Merge a run's newly-derived entries into the existing map and print the result.
#   $1 existing map (may be absent or empty)
#   $2 this run's entries, `<fixture>\t<path>`
#   $3 space-separated list of fixtures this run TRACED
#
# WHY A MERGE AND NOT A REWRITE. `--list` exists so refreshing one fixture costs its own
# runtime instead of a ~50-minute full derivation. The first version wrote the map from only
# the fixtures it had just traced, so `--list "plan-shape"` silently dropped the other 117.
# That is SAFE -- an unmapped fixture always runs -- and therefore invisible: the suite stays
# correct and merely stops skipping, which looks like the feature underperforming rather than
# like a bug.
#
# A TRACED FIXTURE'S OLD ENTRIES GO EVEN IF IT PRODUCED NONE. That is the case that matters:
# a fixture which was mapped and has now been OMITTED (its trace failed, it wrote into the
# tree, tracing never settled) must lose its stale read-set, or the map keeps asserting a
# dependency set nothing re-verified. Dropping it makes the fixture unmapped, which means it
# always runs -- the fail-closed direction.
#
# Kept as a standalone function between sentinels because the rest of this script needs root
# and cannot run in the fixture suite. The fixture extracts THIS block and drives it directly,
# so the logic under test is the shipped logic rather than a restatement of it.
readset_merge_map() {
  local old="$1" new="$2" traced="$3"
  # NEWLINES IN `traced` ABORT THE awk BELOW, AND IT FAILS SILENTLY IN THE WORST DIRECTION.
  # `awk -v` cannot carry a newline: the caller builds its list with a `for` loop, so it arrives
  # newline-separated and awk dies with `newline in string` on line 1. The `if` branch then
  # emits NOTHING, so every untraced fixture's old entries are dropped. Under `--all` that is
  # invisible because nothing needed preserving; under `--list` it silently unmaps the whole
  # rest of the suite. Fail-closed, so never wrong -- just useless, and quiet about it.
  #
  # Normalised here rather than at the call site because this block is what the fixture
  # extracts and drives: a fix at the caller would leave the tested function still broken.
  traced="$(printf '%s' "$traced" | tr '\n' ' ')"
  if [ -s "$old" ]; then
    awk -v traced=" $traced " '
      /^#/ { next }
      {
        fx = $0
        sub(/\t.*$/, "", fx)
        if (index(traced, " " fx " ") == 0) print
      }
    ' "$old"
  fi
  [ -s "$new" ] && cat "$new"
  return 0
}
# READSET_MERGE_END

MODE="${1:---all}"
[ "$(id -u)" = "0" ] || die "must run as root -- fs_usage needs it. Use: sudo bash $0 $MODE"
command -v fs_usage >/dev/null || die "fs_usage not found; this derivation is macOS-only"
command -v python3  >/dev/null || die "python3 not found (path normalisation)"

RUN_AS="${SUDO_USER:-}"
[ -n "$RUN_AS" ] && [ "$RUN_AS" != "root" ] || die \
"cannot determine the invoking user (SUDO_USER unset). Fixtures MUST NOT run as root: a
   permission-refusal arm silently passes and its read-set comes back short, which is a
   permanent silent skip. Invoke through sudo from a normal account."
id -u "$RUN_AS" >/dev/null 2>&1 || die "user '$RUN_AS' does not resolve"

norm() {
  python3 -c '
import sys, os
seen = set()
for line in sys.stdin:
    p = os.path.normpath(line.strip())
    if p and p not in ("." , "..") and not p.startswith("..") and p not in seen:
        seen.add(p); print(p)
' | LC_ALL=C sort -u
}

say "fs_usage runs as root; fixtures run as '$RUN_AS'"
rm -rf "$TRACE_ROOT"; mkdir -p "$TREE" "$WORK" || die "cannot create $TRACE_ROOT"
say "copying the tree to $TREE"
cp -a "$REPO_ROOT/." "$TREE/" || die "copy failed"
[ -d "$TREE/.git" ] || die "copy carries no .git; git-backed fixtures would fail for the wrong reason"
chown -R "$RUN_AS" "$TREE" || die "chown failed"
# The sentinel lives inside the tree because the tracer filters on the tree prefix, which
# makes it an untracked file. Left visible it pegs `git status --porcelain` at 1 and the
# contamination guard below can never report anything.
echo ".readset-sentinel" >> "$TREE/.git/info/exclude"

# THE CONTAMINATION GUARD MEASURES A DELTA, NOT AN ABSOLUTE. The copy carries whatever the
# working tree carries, so deriving from a tree with uncommitted work starts non-zero -- and
# an absolute test then blames every fixture for the operator's own edits. Measured: a smoke
# run with three uncommitted paths omitted BOTH subject fixtures for "wrote 3 path(s)", which
# is a guard that cannot distinguish the thing it exists to detect from its own starting
# conditions. The baseline is taken once, here, after the copy and the exclude are in place.
DIRTY_BASE="$( ( cd "$TREE" && git status --porcelain 2>/dev/null | wc -l ) | tr -d ' ')"
case "$DIRTY_BASE" in ''|*[!0-9]*) DIRTY_BASE=0 ;; esac
[ "$DIRTY_BASE" -eq 0 ] || say "note: deriving from a tree with $DIRTY_BASE uncommitted path(s); the guard measures growth beyond that"

case "$MODE" in
  --all)  LIST="$(cd "$TREE" && for d in "$FIXTURE_ROOT"/*/; do [ -f "$d/run.sh" ] && basename "$d"; done)" ;;
  --list) LIST="${2:-}"; [ -n "$LIST" ] || die "--list needs a fixture list" ;;
  *)      die "usage: sudo bash $0 [--all | --list \"<fixtures>\"]" ;;
esac
N_SUBJECT="$(echo "$LIST" | wc -w | tr -d ' ')"
[ "$N_SUBJECT" -gt 0 ] || die "no drivable fixtures found -- an empty map would skip the entire suite"

reset_atimes() {
  find "$TREE" -type f -print0 2>/dev/null | xargs -0 -P 8 -n 500 touch -a -t 200101010000 2>/dev/null
  return 0
}

OMITTED=""; MAPPED=0; TOTAL_PATHS=0
: > "$WORK/map"

for fx in $LIST; do
  raw="$WORK/$fx.raw"
  echo "sentinel-$fx" > "$SENTINEL"
  reset_atimes

  fs_usage -w -f filesys 2>/dev/null | grep --line-buffered -F "$TREE/" > "$raw" &
  fs_pid=$!

  # ADAPTIVE SETTLE, AND IT IS A CONTROL RATHER THAN A GUESS. A fixed sleep cannot tell
  # "settled" from "not attached yet": measured, a 2s sleep still lost every fixture's own
  # run.sh to the capture boundary. Here the sentinel is read in a loop and the fixture does
  # not start until that read APPEARS IN THE TRACE, i.e. until tracing is provably live.
  settled=0; i=0
  while [ "$i" -lt 60 ]; do
    cat "$SENTINEL" >/dev/null 2>&1
    if grep -q 'readset-sentinel' "$raw" 2>/dev/null; then settled=1; break; fi
    sleep 0.2; i=$(( i + 1 ))
  done

  # Run it the way the pre-push runner runs it: `bash <path>/run.sh` FROM THE REPO ROOT.
  # cd-ing into the fixture directory breaks the sanity arm of five fixtures and FABRICATES
  # failures. `-n` and </dev/null are not decoration: backgrounded, sudo reaches for the
  # controlling terminal, the process group takes SIGTTIN and the whole derivation stops dead
  # in state T with no error and no exit code.
  ( cd "$TREE" && sudo -n -u "$RUN_AS" bash "$FIXTURE_ROOT/$fx/run.sh" ) >"$WORK/$fx.log" 2>&1 </dev/null
  rc=$?

  sleep 1
  # `$!` names the LAST element of the pipeline -- grep, not fs_usage. Killing only that
  # orphans the tracer, and orphans accumulate across a hundred fixtures until every later
  # trace drops events. That failure looks like a small read-set, not like a fault.
  kill "$fs_pid" 2>/dev/null; wait "$fs_pid" 2>/dev/null
  pkill -x fs_usage 2>/dev/null; sleep 0.5

  dirty="$( ( cd "$TREE" && git status --porcelain 2>/dev/null | wc -l ) | tr -d ' ')"

  # atime moved off the forced epoch == the file was READ.
  find "$TREE" -type f -newerat "2001-01-02" -print 2>/dev/null \
    | sed "s|^$TREE/||" | norm > "$WORK/$fx.at"

  # fs_usage, filtered by process and to events after the fixture actually started.
  # RdData/WrData are excluded: they are reads against an already-open fd, they carry no path
  # the open line did not already carry, and they are the ONLY lines fs_usage truncates --
  # and a truncated path maps to the wrong file or to none, which reads exactly like a clean
  # trace.
  last="$(grep -n 'readset-sentinel' "$raw" 2>/dev/null | tail -1 | cut -d: -f1)"; : "${last:=0}"
  tail -n "+$(( last + 1 ))" "$raw" 2>/dev/null \
    | grep -v 'RdData\|WrData' \
    | awk -v d="^($DAEMONS)(\\\\.[0-9]+)?$" '{ p=$NF; sub(/\.[0-9]+$/,"",p); if (p !~ d) print }' \
    | grep -oE "$TREE/[^ ]*" | sed "s|^$TREE/*||" | grep -v '^-\?$' | norm > "$WORK/$fx.fs"

  cat "$WORK/$fx.at" "$WORK/$fx.fs" | LC_ALL=C sort -u \
    | grep -v '^\.readset-sentinel$' > "$WORK/$fx.set"
  n="$(grep -c . "$WORK/$fx.set" 2>/dev/null)"; case "$n" in ''|*[!0-9]*) n=0 ;; esac

  # FAIL CLOSED. Anything that makes this trace untrustworthy omits the fixture from the map,
  # and the runner always runs a fixture it has no entry for.
  why=""
  [ "$rc" -eq 0 ]     || why="fixture exited $rc"
  [ "$settled" -eq 1 ] || why="${why:+$why; }tracing never settled"
  [ "$n" -gt 0 ]      || why="${why:+$why; }empty read-set"
  [ "$dirty" -le "$DIRTY_BASE" ] || why="${why:+$why; }fixture wrote $(( dirty - DIRTY_BASE )) path(s) into the tree"

  if [ -n "$why" ]; then
    OMITTED="${OMITTED}${OMITTED:+ }$fx"
    printf '  %-32s OMITTED (%s) -- will always run\n' "$fx" "$why"
  else
    awk -v f="$fx" '{ print f "\t" $0 }' "$WORK/$fx.set" >> "$WORK/map"
    MAPPED=$(( MAPPED + 1 )); TOTAL_PATHS=$(( TOTAL_PATHS + n ))
    printf '  %-32s %5s paths\n' "$fx" "$n"
  fi
done

# ---------------------------------------------------------------------- controls ----
# A map is only worth shipping if it still selects the fixture that caught a real regression,
# and only meaningful if it does NOT select everything. Both are asserted here, on the same
# read, before anything is written to the tree.
FAIL=0
# Membership by `case` glob rather than `echo | tr | grep -qx`: that idiom is a pipeline
# feeding a reader which leaves at its first match, and under `pipefail` the pipeline answers
# with the WRITER's EPIPE once the upstream's post-match output passes the pipe buffer -- a
# SIZE threshold, so it is correct until it is permanently wrong with no symptom. I54b caught
# exactly this line in this file. The glob also forks nothing.
case " $LIST " in *" plan-shape "*) ;; *) FIXTURE_HAS_PLAN_SHAPE=no ;; esac
if [ "${FIXTURE_HAS_PLAN_SHAPE:-yes}" = yes ]; then
  if grep -qxF "plan-shape	scripts/validate-plan-shape.sh" "$WORK/map"; then
    echo "  PASS  plan-shape's read-set names its own subject (the v0.293.0 regression case)"
  else
    echo "  FAIL  plan-shape's read-set does NOT name scripts/validate-plan-shape.sh"; FAIL=1
  fi
  if grep -qxF "plan-shape	scripts/validate-release-version.sh" "$WORK/map"; then
    echo "  FAIL  CONTROL: plan-shape also 'reads' an unrelated validator -- the set is not selective"; FAIL=1
  else
    echo "  PASS  CONTROL: an unrelated validator is absent from plan-shape's read-set"
  fi
fi
[ "$MAPPED" -gt 0 ] || { echo "  FAIL  zero fixtures mapped -- an empty map would skip the whole suite"; FAIL=1; }

# THE TWO CONTROLS ABOVE NAME A FIXTURE AND A VALIDATOR THAT EXIST ONLY IN THIS DISTRIBUTION,
# so in an installed tree the whole `if` is skipped and only "mapped > 0" is left -- which is
# satisfied by a map that records one path for one fixture. A shipped program whose controls
# cannot fire on the tree it ships to is this repo's named defect class, so the pair below is
# DERIVED and holds in any tree.
#
# POSITIVE: a fixture reads its own driver. `bash <root>/<fx>/run.sh` is how the runner starts
# it, so that path is in every honest read-set. A trace that lost it lost the fixture's first
# open, which means the capture boundary moved and every other path in that set is suspect.
#
# NEGATIVE: the map DISCRIMINATES. A read-set equal to the whole universe selects its fixture
# on every change and is a full run wearing a map's clothes -- and it is the shape an
# over-broad filter produces, so a map built entirely of them would report success while
# skipping nothing. One fixture whose set is a proper subset of the union is enough to
# establish that the instrument separates; zero of them is not.
while IFS= read -r cfx; do
  [ -n "$cfx" ] || continue
  if ! grep -qxF "$cfx	$FIXTURE_ROOT/$cfx/run.sh" "$WORK/map"; then
    echo "  FAIL  $cfx's read-set does not name its own driver $FIXTURE_ROOT/$cfx/run.sh"; FAIL=1
  fi
done < <(cut -f1 "$WORK/map" | sort -u)
cut -f2 "$WORK/map" | sort -u > "$WORK/.universe"
N_UNIVERSE="$(grep -c . "$WORK/.universe" 2>/dev/null)"; case "$N_UNIVERSE" in ''|*[!0-9]*) N_UNIVERSE=0 ;; esac
N_PROPER=0
while IFS= read -r cfx; do
  [ -n "$cfx" ] || continue
  n_own="$(awk -F'\t' -v f="$cfx" '$1 == f' "$WORK/map" | wc -l | tr -d ' ')"
  [ "$n_own" -lt "$N_UNIVERSE" ] && N_PROPER=$(( N_PROPER + 1 ))
done < <(cut -f1 "$WORK/map" | sort -u)
if [ "$N_PROPER" -gt 0 ]; then
  echo "  PASS  CONTROL: $N_PROPER of $MAPPED read-set(s) are a PROPER subset of the $N_UNIVERSE-path universe -- the map discriminates"
else
  echo "  FAIL  CONTROL: every read-set covers the whole $N_UNIVERSE-path universe -- this map selects everything on every change and skips nothing"; FAIL=1
fi

[ "$FAIL" -eq 0 ] || die "controls failed; the map was NOT written"

MERGED="$WORK/merged"
readset_merge_map "$MAP" "$WORK/map" "$LIST" | LC_ALL=C sort -u > "$MERGED"

# THE MERGE MUST NOT LOSE A FIXTURE IT WAS NOT ASKED ABOUT. Dropping one is SAFE (an unmapped
# fixture always runs) but it silently costs the skip, which is the entire point of the file --
# and the first version of `--list` did exactly that, rewriting the whole map from the handful
# of fixtures it had just traced. Asserted rather than trusted.
if [ -s "$MAP" ]; then
  # THE `case` STAYS OUT OF THE COMMAND SUBSTITUTION. bash 3.2 -- which is what /bin/bash is on
  # macOS -- parses the `)` closing a case pattern as the `)` closing `$( )`, and dies with
  # "syntax error near unexpected token `newline'". Writing the intermediate to a file instead
  # of capturing it is the fix; this is the same bash-3.2 constraint the suite already works
  # under elsewhere.
  grep -v '^#' "$MAP" | cut -f1 | sort -u > "$WORK/old.fixtures"
  : > "$WORK/untouched"
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    case " $LIST " in
      *" $f "*) ;;
      *) printf '%s\n' "$f" >> "$WORK/untouched" ;;
    esac
  done < "$WORK/old.fixtures"
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    grep -q "^$f	" "$MERGED" \
      || die "merge dropped '$f', which this run never traced -- refusing to write a map that silently stops skipping"
  done < "$WORK/untouched"
fi

M_FIX="$(cut -f1 "$MERGED" | sort -u | wc -l | tr -d ' ')"
M_ENT="$(wc -l < "$MERGED" | tr -d ' ')"
M_PATH="$(cut -f2 "$MERGED" | sort -u | wc -l | tr -d ' ')"
[ "$M_ENT" -gt 0 ] || die "the merged map is empty -- refusing to write it"

{
  echo "# GENERATED by derive-fixture-readsets.sh -- DO NOT EDIT BY HAND."
  echo "#"
  echo "# <fixture>\t<path it reads>. The pre-push suite runs a fixture when any changed path"
  echo "# is in its set, and ALWAYS runs a fixture that has no entry here -- absence means"
  echo "# 'run it', never 'depends on nothing'. Re-derive after changing a fixture or anything"
  echo "# it reads: a stale entry is safe only in the direction of running too much."
  echo "#"
  echo "# A --list run MERGES: it replaces the entries of the fixtures it traced and leaves"
  echo "# every other fixture's entries alone, so refreshing one fixture costs its own runtime"
  echo "# rather than a full re-derivation."
  echo "#"
  echo "# fixtures mapped: $M_FIX    entries: $M_ENT"
  [ -n "$OMITTED" ] && echo "# OMITTED by the last run (always run): $OMITTED"
  cat "$MERGED"
} > "$MAP"

say "wrote $MAP -- $M_FIX fixtures, $M_ENT entries, $M_PATH distinct paths (this run traced $MAPPED)"
[ -n "$OMITTED" ] && say "OMITTED and therefore always run: $OMITTED"
exit 0
