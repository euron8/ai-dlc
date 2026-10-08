#!/usr/bin/env bash
# Derive each fixture's READ-SET by tracing it, and write the map the pre-push suite uses to
# skip fixtures a change cannot affect.
#
# RUN AS, in this distribution:  sudo bash core/scripts/derive-fixture-readsets.sh [--all | --list "<fixtures>"]
#         in an installed tree:  sudo bash scripts/ai-dlc/derive-fixture-readsets.sh [--all | --list "<fixtures>"]
#
# `--tracer sandbox` replaces fs_usage with the kernel's own Sandbox reports (a scoped
# `sandbox-exec` profile read through `log stream`) and needs NO root -- run it WITHOUT sudo.
# The sandbox cannot see a read by a process outside the fixture's lineage (an XPC or launchd
# helper), and `log stream` DROPS reports under load; a window carrying a drop notice omits its
# fixture, and so does one where the atime leg saw a READ the stream never reported (the LOSS
# CANARY, beside the drop-notice guard: a loss canary only, never a completeness claim).
#
# `--tracer both` IS THE COMPARISON THAT DECIDES WHETHER THE SANDBOX MAY REPLACE fs_usage:
#     sudo bash core/scripts/derive-fixture-readsets.sh --all --tracer both     (or --list)
# fs_usage stays the default until this run reads SANDBOX-MISSES-NOTHING over every fixture.
#   * NEEDS ROOT, because fs_usage does. The fixture still runs unprivileged: it is started as
#     `sudo -n -u "$SUDO_USER" sandbox-exec -f <profile> bash <run.sh>`, ONCE, under both tracers
#     at the same time, so the two sets describe one execution rather than two.
#   * NEVER WRITES THE MAP. It is a measurement of the tracers, not a derivation; the map stays
#     whatever the last fs_usage run wrote. The union of the three tracers is still collected per
#     fixture, so the loop body is the one the other modes run, but the script exits at the
#     verdict and never reaches the write.
#   * ONE LINE PER FIXTURE with two counts: `sandbox-missed` (in fs_usage, not in the sandbox --
#     the count the verdict reads) and `fs_usage-missed` (the reverse, informational: negative
#     lookups fs_usage does not record were measured in that direction and are safe).
#   * A MISS IS fs_usage MINUS sandbox, NOT fs_usage MINUS (sandbox UNION atime). The stricter set
#     can only over-report, so a clean verdict under it is clean under the looser one too; on the
#     four fixtures measured so far the two agreed (sandbox UNION atime = sandbox).
#   * TWO EXCLUSIONS, applied to BOTH sets before they are compared, and nothing else:
#       `.git` and `.git/**`, by PREFIX. The pre-push runner strips exactly those from the map's
#       universe before matching, so a row there can never select or skip a fixture -- and
#       `git check-ignore` answers NOT-ignored for `.git/HEAD`, so the ignore filter would keep it.
#       Every path `git check-ignore` calls IGNORED, through drop_ignored -- the same filter every
#       map row already passes through, so an ignored path can never become a map row either way.
#       The FILE `.gitignore` is NOT excluded: it is tracked, the map carries it as a read of many
#       fixtures, and the runner does not strip it, so it is a live skip input like any other.
#   * EXIT 0 = `SANDBOX-MISSES-NOTHING`; 1 = `SANDBOX-MISSES <n> path(s) across <m> fixture(s)`;
#     2 = REFUSED, and every refusal in this mode is 2, including the ones that exit 1 in the
#     other modes (not root, SUDO_USER unset, a missing tool, a LINKED WORKTREE -- which dies
#     before the arguments are parsed, so the mode is read off the raw arguments first). It is
#     also 2 whenever fewer fixtures were COMPARED than were LISTED, naming each uncompared one
#     and why (fixture exit, settle, flush, a stream drop, a dirty tree, either set empty): a
#     verdict over part of the suite must never read as a verdict over all of it. An EMPTY
#     sandbox set is its own reason because it is how a root `log stream` that cannot see the
#     `sudo -u` child's reports would present -- not measurable without root, so refused.
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
# fixture defeats relatime by construction, proven each run by the unread control below
# (UNREAD_CTL: a planted file that must still read the 2001 epoch after every fixture).
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
#
# `--tracer both` IS READ OFF THE RAW ARGUMENTS HERE, BEFORE THE CHECK BELOW, because in that mode
# exit 1 is a VERDICT (the sandbox missed something) and a refusal at 1 would read as one. Read
# pairwise, so a fixture that happens to be NAMED `both` in a `--list` does not switch the mode.
# THE LAST `--tracer` WINS, because the parser below overwrites TRACER on each one: every
# occurrence sets the code from its own value, so `--tracer both --tracer fs_usage` refuses at 1.
DIE_RC=1
_prev=""
for _a in "$@"; do
  if [ "$_prev" = --tracer ]; then
    if [ "$_a" = both ]; then DIE_RC=2; else DIE_RC=1; fi
  else
    case "$_a" in
      --tracer=both) DIE_RC=2 ;;
      --tracer=*)    DIE_RC=1 ;;
    esac
  fi
  _prev="$_a"
done
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
[ -n "$REPO_ROOT" ] && [ -d "$REPO_ROOT/.git" ] || {
  echo "ERROR: not inside a git work tree, or inside a LINKED worktree (whose .git is a file). The map is a tracked artifact of one repository and the trace copies its .git; there is nothing to derive from here." >&2; exit "$DIE_RC"; }
MAP="$REPO_ROOT/.ai-dlc-fixture-readsets.tsv"

# System daemons that walk the filesystem on their own schedule and are never part of a
# fixture's work. Deliberately NOT a general noise list: a fixture's own helpers (bash, git,
# awk, sed, python3, cp) are absent from it, because a `cp` reading a source file IS a real
# dependency and fixtures copy trees constantly.
# READSET_DAEMONS_BEGIN
DAEMONS='fseventsd|mds|mds_stores|mdworker|mdworker_shared|mdsync|Spotlight|distnoted|cfprefsd|syspolicyd|opendirectoryd|securityd|notifyd|logd|UserEventAgent|revisiond|backupd|diskarbitrationd|coreauthd|trustd|nsurlsessiond|Finder|fmfd|photoanalysisd|cloudd|bird|CrashReporter'
# READSET_DAEMONS_END

# ONE ASSIGNMENT, ON ITS OWN LINE, so core/fixtures/readset-skip can point a COPY of this script at
# a stub stream: `/usr/bin/log` is called by absolute path (zsh shadows `log` with a builtin), so a
# PATH stub can never stand in for it. Not an environment knob.
LOG_BIN=/usr/bin/log

die() { echo "ERROR: $*" >&2; exit "$DIE_RC"; }
say() { echo "[$(date +%H:%M:%S)] $*"; }

USAGE="usage: bash $0 [--all | --list \"<fixtures>\" | --reconcile] [--tracer fs_usage|sandbox|both] [--local-map <file>]   (fs_usage and both need sudo)"
MODE=""; LIST_ARG=""; TRACER="fs_usage"; LOCAL_MAP=""; RECONCILE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --all)       MODE="--all"; shift ;;
    --reconcile) RECONCILE=1; shift ;;
    --list)      MODE="--list"; LIST_ARG="${2:-}"; shift; [ $# -gt 0 ] && shift ;;
    --tracer)    TRACER="${2:-}"; shift; [ $# -gt 0 ] && shift ;;
    --tracer=*)  TRACER="${1#--tracer=}"; shift ;;
    --local-map) LOCAL_MAP="${2:-}"; shift; [ $# -gt 0 ] && shift; [ -n "$LOCAL_MAP" ] || die "--local-map needs a file. $USAGE" ;;
    *)           die "$USAGE" ;;
  esac
done
# `--reconcile` TRACES WHAT THE MAP OWES, AND ONLY UNDER THE SANDBOX TRACER: it is the unprivileged
# answer to "which fixtures need a trace", so it never takes sudo. It derives its own list below, once
# the fixture root is known, and then runs exactly as `--list "<that list>" --tracer sandbox`.
if [ "$RECONCILE" = 1 ]; then
  [ -z "$MODE" ] && [ -z "$LOCAL_MAP" ] || die "--reconcile derives its own list; it takes no --all, --list or --local-map. $USAGE"
  TRACER=sandbox; DIE_RC=1
fi
: "${MODE:=--all}"
case "$TRACER" in fs_usage|sandbox|both) ;; *) die "unknown --tracer '$TRACER'. $USAGE" ;; esac

# `--local-map <file>` IS THE PRE-PUSH HOOK'S MODE, and it never writes the committed map. Both hooks
# start it DETACHED after a green suite, for the fixtures that have no valid read set and the ones
# whose key record went stale, so neither keeps running on every push without anyone hand-running this.
# Each fixture whose trace is clean has its rows in <file> replaced, atomically (temp + mv), as
# `<fx>\t<path>\t<sha256 or ->` plus `<fx>\t#deriver\t<sha256 of this script>`; the hook honours a
# row set only while every recorded path still hashes the same and this script is unchanged. A
# discarded trace writes `<fx>\t#discards\t<n>\t<run.sh sha>:<deriver sha>` instead, and the hook
# stops re-tracing a fixture after three in a row on one key. A valid local row set REPLACES the
# committed rows of its fixture in the hook. Unprivileged by construction -- the
# sandbox tracer only -- and the fixture's normal-run log is read from `<file>.logs/<fx>`, where the
# hook stashed it, because a trace whose verdict lines differ from the normal run's is not a trace
# of the run that passed.
if [ -n "$LOCAL_MAP" ]; then
  [ "$TRACER" = sandbox ] || die "--local-map runs only under --tracer sandbox: it is started by the pre-push hook, which has no root"
  [ "$MODE" = --list ] || die "--local-map needs --list \"<fixtures>\": it traces the fixtures the hook names, never the whole suite"
  case "$LOCAL_MAP" in /*) ;; *) LOCAL_MAP="$PWD/$LOCAL_MAP" ;; esac
  command -v shasum >/dev/null || die "shasum not found; --local-map keys every row on a sha256"
fi
DERIVER_SHA="$(shasum -a 256 -- "$0" 2>/dev/null | cut -d' ' -f1)"

# EACH TRACER HAS ITS OWN TRACE ROOT. The fs_usage run creates its tree as root and then chowns
# only the tree, so a root-owned TRACE_ROOT is left behind; a later sandbox run -- unprivileged by
# construction -- cannot `rm -rf` it and would die, or worse, trace inside a half-cleared tree.
# A sandbox run also REFUSES any existing root it does not own, rather than attempting the delete.
if [ "$TRACER" = sandbox ]; then
  TRACE_ROOT="${AI_DLC_READSET_TRACE_ROOT:-/private/tmp/ai-dlc-readset-sandbox-$(id -u)}"
elif [ "$TRACER" = both ]; then
  TRACE_ROOT="${AI_DLC_READSET_TRACE_ROOT:-/private/tmp/ai-dlc-readset-both}"
else
  TRACE_ROOT="${AI_DLC_READSET_TRACE_ROOT:-/private/tmp/ai-dlc-readset}"
fi

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
# The root is read off the runner's one `FXROOT="<root>/"` line, the variable its glob iterates.
# EXACTLY ONE MATCH IS REQUIRED. Zero means the runner no longer declares a fixture root and
# this script's whole premise has moved; more than one means the suite has two roots and a map
# keyed on basenames alone cannot say which directory an entry belongs to.
RUNNER="$REPO_ROOT/.githooks/pre-push"
[ -r "$RUNNER" ] || die "cannot read $RUNNER. It is the program that consumes this map, and the fixture root is read off its own glob rather than assumed."
FIXTURE_ROOT="$(sed -n 's|^FXROOT="\([A-Za-z0-9_./-]*\)/"$|\1|p' "$RUNNER" | sort -u)"
N_ROOT="$(printf '%s\n' "$FIXTURE_ROOT" | grep -c .)"
[ "$N_ROOT" -eq 1 ] || die "read $N_ROOT fixture root(s) from $RUNNER, need exactly 1 (got: $(printf '%s' "$FIXTURE_ROOT" | tr '\n' ' ')). Zero means its fixture glob has changed shape and this producer is now guessing; more than one means a basename key cannot name a directory."
[ -d "$REPO_ROOT/$FIXTURE_ROOT" ] || die "$RUNNER drives '$FIXTURE_ROOT/' and no such directory exists under $REPO_ROOT."

# THE RUNNER'S OWN UNIVERSE, SOURCED, NEVER RESTATED. The `# digest <fx> <sha>` line this script writes
# for a traced fixture is recomputed by the runner over its own `.now` to decide whether a stale record
# clears, so both must be ONE function over ONE universe filter: readset_digests and the filter it is fed
# are read out of the runner's READSET_UNIVERSE span. A runner with no such span (an older hook) gets no
# digest lines -- its fixtures still select, they only cannot clear a stale record -- and `--reconcile`,
# which needs the runner's verdict on the tree, refuses.
MAP_REL=".ai-dlc-fixture-readsets.tsv"
UNIVERSE_SPAN="$(mktemp "${TMPDIR:-/tmp}/readset-universe.XXXXXX")" || die "mktemp failed"
sed -n '/^# READSET_UNIVERSE_BEGIN$/,/^# READSET_UNIVERSE_END$/p' "$RUNNER" > "$UNIVERSE_SPAN"
HAVE_UNIVERSE=0
if grep -q '^readset_digests() ' "$UNIVERSE_SPAN" && grep -q '^readset_committed_digests() ' "$UNIVERSE_SPAN"; then
  # shellcheck disable=SC1090
  . "$UNIVERSE_SPAN" && HAVE_UNIVERSE=1
fi
rm -f "$UNIVERSE_SPAN"
READSET_MAP="$MAP_REL"
GITCOMMON="$(cd "$REPO_ROOT" && git rev-parse --git-common-dir 2>/dev/null)"
case "$GITCOMMON" in ''|/*) ;; *) GITCOMMON="$REPO_ROOT/$GITCOMMON" ;; esac
READSET_LOCAL="${GITCOMMON:-$REPO_ROOT/.git}/ai-dlc-fixture-readsets.local"

# READSET_RECONCILE_BEGIN
# `--reconcile`'s list: one `<fx>\t<reason>` line per fixture that needs a trace, first reason wins.
#   unmapped  a fixture directory with a run.sh and no row in the committed map;
#   stale     a key record under <keys dir> reading `#state stale`;
#   changed   a committed `# digest` that no longer matches this tree, judged by the runner's own
#             readset_committed_digests over the runner's own manifest (a fixture whose rows carry no
#             digest cannot be judged this way and is not listed for it).
# Run from the repo root, with the runner's span sourced. <keys dir> absent means no record yet, so
# nothing is stale; a keys dir that exists and cannot be read REFUSES (exit 2), because the glob would
# stay literal and the parse, whose stderr is silenced, would read it as "no stale record".
#   $1 fixture root (repo-relative)   $2 keys dir   $3 scratch dir (must not exist)
readset_reconcile_list() {
  local fxr="$1" kd="$2" s="$3" d b nk
  mkdir "$s" || return 2
  if [ -e "$kd" ]; then
    [ -d "$kd" ] && [ -r "$kd" ] && [ -x "$kd" ] || { echo "--reconcile: cannot read the key records under $kd" >&2; return 2; }
    set -- "$kd"/*.key; [ -e "$1" ] || set --
    nk=$#
    readset_key_records "$kd" > "$s/krecs"
    [ "$nk" -eq 0 ] || [ -s "$s/krecs" ] || { echo "--reconcile: $nk key record(s) under $kd and none parsed" >&2; return 2; }
    awk -F'\t' '$2 == "#state" && $3 == "stale" { print $1 }' "$s/krecs" | LC_ALL=C sort -u > "$s/stale"
  else
    : > "$s/stale"
  fi
  { [ -s "$READSET_MAP" ] && grep -v '^#' "$READSET_MAP" | cut -f1; :; } | LC_ALL=C sort -u > "$s/mapped"
  readset_manifest "$s"
  [ -s "$s/.now" ] || { echo "--reconcile: could not hash the working tree, so a changed read set cannot be told from an unchanged one" >&2; return 2; }
  readset_committed_digests "$s"
  awk -F'\t' '$2 == "differs" { print $1 }' "$s/.cdig" > "$s/changed"
  for d in "$fxr"/*/; do
    [ -f "${d}run.sh" ] || continue
    d="${d%/}"; b="${d##*/}"
    if ! grep -qxF "$b" "$s/mapped"; then printf '%s\tunmapped\n' "$b"
    elif grep -qxF "$b" "$s/stale"; then printf '%s\tstale\n' "$b"
    elif grep -qxF "$b" "$s/changed"; then printf '%s\tchanged\n' "$b"
    fi
  done
  return 0
}
# READSET_RECONCILE_END

if [ "$RECONCILE" = 1 ]; then
  [ "$HAVE_UNIVERSE" = 1 ] || die "--reconcile needs the READSET_UNIVERSE span of $RUNNER to judge a changed read set, and it has none -- update the hook first"
  RC_S="$(mktemp -d "${TMPDIR:-/tmp}/readset-reconcile.XXXXXX")" || die "mktemp failed"
  ( cd "$REPO_ROOT" && readset_reconcile_list "$FIXTURE_ROOT" "${GITCOMMON:-.git}/ai-dlc-fixture-keys" "$RC_S/l" ) > "$RC_S/list" \
    || die "--reconcile could not derive its list (see above); nothing traced"
  if [ ! -s "$RC_S/list" ]; then
    echo "nothing to reconcile"
    exit 0
  fi
  echo "--reconcile: $(grep -c . "$RC_S/list") fixture(s) to trace:"
  sed 's/^/  /' "$RC_S/list"
  MODE="--list"; LIST_ARG="$(cut -f1 "$RC_S/list" | tr '\n' ' ' | sed 's/ $//')"
fi

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
  # A `# digest <fx> <sha>` LINE IS CARRIED WITH ITS FIXTURE'S ROWS: kept for a fixture this run did
  # not trace, dropped for one it did (the caller adds the new one, or none for an omitted fixture).
  # Every other `#` line is the header, which the writer regenerates.
  if [ -s "$old" ]; then
    awk -v traced=" $traced " '
      $1 == "#" && $2 == "digest" && NF == 4 { if (index(traced, " " $3 " ") == 0) print; next }
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

# READSET_CONTROL_BEGIN
# THE MAP MUST DISCRIMINATE: at least one fixture's read-set is a PROPER subset of the union of
# every path the map names.
#   $1 the map to judge -- the MERGED map, never one run's traced entries alone (see the call
#      site for why the distinction is the whole of this control's history)
# Prints one PASS or FAIL line and returns 0 or 1. Nothing else here reads it, so a caller in
# either layout gets the same verdict from the same bytes.
#
# BOTH SIDES OF THE COMPARISON ARE COUNTED FROM THE SAME FILE. A fixture's own path count taken
# from one map while the universe is taken from a larger one is not a subset test at all: the
# smaller count is below the larger union for every input, so the control passes on a map that
# discriminates nothing.
#
# Kept as a standalone function between sentinels for the same reason the merge above is: the
# rest of this script needs root and cannot run in the fixture suite, so the fixture extracts
# THIS block and drives it, and the logic under test is the shipped logic rather than a
# restatement of it.
readset_discrimination_control() {
  awk -F'\t' '
    /^#/ { next }
    NF >= 2 {
      if ((($1 SUBSEP $2) in seen) == 0) { seen[$1 SUBSEP $2] = 1; own[$1]++ }
      if (($2 in path) == 0) { path[$2] = 1; universe++ }
    }
    END {
      proper = 0; nfix = 0
      for (f in own) { nfix++; if (own[f] < universe) proper++ }
      if (proper > 0) {
        printf "  PASS  CONTROL: %d of %d read-set(s) are a PROPER subset of the %d-path universe -- the map discriminates\n", proper, nfix, universe
        exit 0
      }
      printf "  FAIL  CONTROL: every read-set covers the whole %d-path universe -- this map selects everything on every change and skips nothing\n", universe
      exit 1
    }
  ' "$1"
}
# READSET_CONTROL_END

# READSET_ALLLIST_BEGIN
# The `--all` subject list: every directory directly under $1 that holds a run.sh, by basename,
# printed SPACE-separated on one line.
#   $1 the fixtures directory (`$TREE/$FIXTURE_ROOT` at the call site)
#
# SPACE-SEPARATED IS THE CONTRACT, AND A NEWLINE-SEPARATED LIST BREAKS TWO GUARDS SILENTLY. Every
# membership test on `$LIST` below is `case " $LIST " in *" $f "*)`, which needs a space on both
# sides of each name. The list this replaced was a `for` loop's output -- one name per line -- so
# under `--all` neither the untraced-fixture guard nor the plan-shape controls ever matched a
# name: every fixture was classed untouched, so one OMITTED fixture made the merge check die and
# discard every good trace, and the plan-shape pair never ran on any `--all` derivation. `--list`
# was always space-separated and always correct, which is why nothing looked broken.
#
# Kept between sentinels so core/fixtures/readset-skip drives THIS function on a seeded directory
# and asserts on its output, rather than on a restatement of it.
readset_all_list() {
  local root="$1" d out=""
  for d in "$root"/*/; do
    [ -f "${d}run.sh" ] || continue
    d="${d%/}"
    out="${out}${out:+ }${d##*/}"
  done
  printf '%s' "$out"
}
# READSET_ALLLIST_END

# READSET_UNTRACED_BEGIN
# THE MERGE MUST NOT LOSE A FIXTURE IT WAS NOT ASKED ABOUT. Prints, one per line, every fixture the
# existing map names that this run did NOT trace and that the merged map no longer carries.
#   $1 existing map (absent or empty: nothing to lose, prints nothing)
#   $2 the merged map this run would write
#   $3 the fixtures this run TRACED -- space- OR newline-separated; normalised here
# Returns non-zero only when a map could not be read, so the caller can tell "lost nothing" from
# "did not look".
#
# MEMBERSHIP IS BY EXACT NAME ON BOTH SIDES. A traced list holding `fx-b` must not count `fx` as
# traced, and a merged map row for `fx-b` must not count as a row for `fx`. A substring test passes
# both, and the second one is the silent direction: `fx` is reported kept while it is gone.
#
# NORMALISED HERE rather than at the call site because this block is what the fixture extracts and
# drives -- the same reasoning as readset_merge_map's normalisation, and the defect it closes is the
# same one: the `--all` list arrived newline-separated, no name matched, and every fixture read as
# untraced.
readset_untraced_lost() {
  local old="$1" merged="$2" traced="$3"
  [ -s "$old" ] || return 0
  [ -r "$merged" ] || return 2
  traced="$(printf '%s' "$traced" | tr '\n\t' '  ')"
  awk -F'\t' -v traced=" $traced " '
    FILENAME == ARGV[1] { if ($0 !~ /^#/) have[$1] = 1; next }
    /^#/ { next }
    $1 == "" { next }
    ($1 in seen) { next }
    {
      seen[$1] = 1
      if (index(traced, " " $1 " ") == 0 && ($1 in have) == 0) print $1
    }
  ' "$merged" "$old"
}
# READSET_UNTRACED_END

# READSET_COPY_BEGIN
# Build the trace tree: the whole `.git/`, plus exactly the paths git would call candidate inputs
# -- `git ls-files --cached --others --exclude-standard`, tracked plus untracked-not-ignored.
#   $1 source repo root   $2 destination (exists, empty)   $3 scratch dir for the path list
# Prints one `copied N path(s)` line, and a note naming any listed path absent on disk.
#
# WHY NOT `cp -a` OF THE WHOLE WORKING TREE. Everything gitignored was copied and then never
# recordable, because drop_ignored removes every ignored path from the read-set -- yet it was
# walked by reset_atimes and the `-newerat` scan once per fixture. Measured on the reference
# consumer: 117595 files in the trace copy against 11976 tracked. This population is the one
# drop_ignored already treats as a possible input, so the NAMES a read-set can hold are
# unchanged. What CAN change is behaviour: a fixture that reads an ignored file which exists
# only in the working tree now finds it absent. That is the correct tree to trace -- a fresh
# clone, which is what CI and every other checkout see, does not carry it either.
#
# WHAT LANDS, and each is asserted by core/fixtures/readset-skip, which drives this block:
#   * `-z` END TO END. A name with a space or a newline is one record, never two.
#   * modes, mtimes and symlinks are preserved -- a tracked symlink stays a symlink, a tracked
#     executable stays executable. `tar` rather than a `cp` loop, because `cp -R` of a symlink to
#     a directory follows it on BSD cp and the list is one fork, not one per file.
#   * A GITLINK LANDS AS AN EMPTY DIRECTORY. `--no-recursion` archives the listed directory entry
#     and nothing under it; the submodule's objects are in `.git/modules/`, copied with `.git/`.
#     A fixture that reads inside the submodule's work tree will not find its files, and the
#     submodule rows in the map vanish at the next derivation (drop_ignored collapses any that do
#     appear into the gitlink row). An untracked nested repository lands the same way.
#   * A LISTED PATH ABSENT ON DISK (deleted, not yet staged) is skipped and NAMED, never allowed
#     to abort the copy: the index still lists it, and the working tree is what a fixture sees.
#     A dangling tracked symlink is present (`-L`) and is copied as the symlink it is.
readset_copy_tree() {
  local src="$1" dst="$2" scratch="$3" p n=0 miss=0 misslist=""
  ( cd "$src" && git ls-files -z --cached --others --exclude-standard ) > "$scratch/copy.all" \
    || { echo "readset_copy_tree: git ls-files failed in $src" >&2; return 1; }
  while IFS= read -r -d '' p; do
    if [ -e "$src/$p" ] || [ -L "$src/$p" ]; then
      printf '%s\0' "$p"; n=$((n+1))
    else
      miss=$((miss+1)); [ "$miss" -le 5 ] && misslist="$misslist '$p'"
    fi
  done < "$scratch/copy.all" > "$scratch/copy.list"
  if [ "$n" -gt 0 ]; then
    ( cd "$src" && tar -cf - --null --no-recursion -T "$scratch/copy.list" ) \
      > "$scratch/copy.tar" || { echo "readset_copy_tree: tar -c failed" >&2; return 1; }
    ( cd "$dst" && tar -xpf "$scratch/copy.tar" ) \
      || { echo "readset_copy_tree: tar -x failed" >&2; return 1; }
    rm -f "$scratch/copy.tar"
  fi
  cp -a "$src/.git" "$dst/.git" || { echo "readset_copy_tree: copying .git failed" >&2; return 1; }
  echo "copied $n path(s) plus .git/"
  [ "$miss" -eq 0 ] || echo "note: $miss listed path(s) absent on disk, not copied:$misslist"
  return 0
}
# READSET_COPY_END

command -v python3  >/dev/null || die "python3 not found (path normalisation)"
# THE ROOT CHECK BELONGS TO fs_usage, NOT TO THE DERIVATION. The sandbox tracer is unprivileged
# end to end, and it REFUSES root instead: its fixtures run as whoever invoked it, and a fixture
# run as root reads past every permission-refusal arm and comes back with a short read-set.
#
# `--tracer both` takes the fs_usage half of this (root, and a non-root SUDO_USER to run fixtures
# as) AND the sandbox half's tools. Its fixture runs as `sudo -n -u "$RUN_AS" sandbox-exec`, so
# everything root writes that the child must READ -- the profile, the marker directory, the
# markers -- is created under umask 022.
if [ "$TRACER" = fs_usage ] || [ "$TRACER" = both ]; then
  [ "$(id -u)" = "0" ] || die "must run as root -- fs_usage needs it. Use: sudo bash $0 $MODE${LIST_ARG:+ \"$LIST_ARG\"} --tracer $TRACER"
  command -v fs_usage >/dev/null || die "fs_usage not found; this derivation is macOS-only"
  if [ "$TRACER" = both ]; then
    command -v sandbox-exec >/dev/null || die "sandbox-exec not found; --tracer both is macOS-only"
    [ -x "$LOG_BIN" ] || die "$LOG_BIN not found; --tracer both reads the kernel's Sandbox reports through 'log stream'"
    umask 022
  fi
  RUN_AS="${SUDO_USER:-}"
  [ -n "$RUN_AS" ] && [ "$RUN_AS" != "root" ] || die \
"cannot determine the invoking user (SUDO_USER unset). Fixtures MUST NOT run as root: a
   permission-refusal arm silently passes and its read-set comes back short, which is a
   permanent silent skip. Invoke through sudo from a normal account."
  id -u "$RUN_AS" >/dev/null 2>&1 || die "user '$RUN_AS' does not resolve"
else
  [ "$(id -u)" != "0" ] || die "--tracer sandbox must NOT run as root: its fixtures run as the invoking user, and a fixture run as root passes permission-refusal arms by reading anyway, which shortens its read-set permanently. Run it from a normal account, without sudo."
  command -v sandbox-exec >/dev/null || die "sandbox-exec not found; --tracer sandbox is macOS-only"
  [ -x "$LOG_BIN" ] || die "$LOG_BIN not found; --tracer sandbox reads the kernel's Sandbox reports through 'log stream'"
  RUN_AS="$(id -un)"
fi

# READSET_NORM_BEGIN
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
# READSET_NORM_END

# READSET_DROP_BEGIN
# Driven by core/fixtures/readset-skip on a seeded repo carrying a real submodule; it reads only
# $TREE and stdin, so the extracted span is the shipped logic.
#
# A GITIGNORED PATH IS NOT A SUITE INPUT, AND RECORDING ONE MAKES THE MAP A FUNCTION OF WHAT
# ELSE WAS ON THE DISK. `.claude/worktrees/` is the Claude Code harness's own agent checkouts:
# not this project's state, not any project's state, present in whatever number of concurrent
# sessions happened to be running. Traced, they entered the map as permanent per-fixture inputs
# -- 12435 rows across the map, and one fixture's entry moved 4815 -> 26854 between two
# derivations minutes apart for no reason but concurrent agents. A derived artifact whose
# content depends on ambient activity cannot be reviewed, diffed, or reproduced.
#
# THE BOUNDARY IS THE REPOSITORY'S OWN `.gitignore`, READ BY GIT -- never a second list
# maintained here, which would drift from it silently. `.claude/rules/**` is un-ignored by
# negation and so SURVIVES this filter: fixtures do read those rule files, and the distinction
# between "under .claude" and "ignored" is exactly what a hand-written prefix list gets wrong.
#
# WHY NOT FILTER ON `ls-files --cached` ALONE: a path may legitimately be untracked-and-not-ignored
# (a file a fixture creates and reads back), and that is a real dependency. Ignored is the
# narrower, correct predicate -- and it is the same one readset_copy_tree builds the trace tree
# from (`--cached --others --exclude-standard`), so the copy and this filter agree on what can be
# an input.
#
# FAILS OPEN BY DESIGN, and that is the safe direction here: if `git check-ignore` cannot run,
# every path is kept, the read-set is a superset, and the fixture runs more often than it must.
# The dangerous direction would be dropping a real input, which makes a fixture skip when its
# subject moved.
# STDIN IS BUFFERED BEFORE THE FILTER RUNS, because a pipeline consumes it exactly once and the
# fail-open branch has nothing left to fall back on otherwise -- it would emit an EMPTY read-set,
# which is the one direction this must never take.
#
# A PATH INSIDE A SUBMODULE MAKES `check-ignore` REFUSE THE WHOLE BATCH, SO THE FILTER NEVER RAN
# WHERE A GITLINK EXISTS. One `sub/x` row and git exits 128 with "is in submodule" and no verdict
# for any row; the fail-open branch then keeps all of them. Measured on the reference consumer
# (gitlink `hook/lib/v4-core`, mode 160000): 357 rows in, 357 out, ignored `.venv`, `.pytest_cache`
# and nonce paths among the survivors -- 139 -> 66 once the submodule rows were taken out of the
# batch. So those rows never reach `check-ignore`:
#   * a path at or under a gitlink COLLAPSES TO THE GITLINK PATH ITSELF, which the parent tracks
#     and a submodule bump changes. The parent's runner never sees a change to a file inside the
#     submodule (it is not in the parent's index), so the gitlink row is the one that can select
#     the fixture; the inner rows could match nothing.
#   * a `.git/modules/` row is kept as-is and bypasses the batch too. Measured: `check-ignore`
#     does NOT refuse one (rc 0, reported non-matching), so this is belt rather than repair; it is
#     git internals, and the runner strips `.git/` before matching.
# Gitlinks are read off the INDEX (`ls-files -s`), never off the disk, so an unpopulated or
# emptied submodule directory is still recognised.
drop_ignored() { # reads paths on stdin (repo-relative), writes the non-ignored ones
  local in ask sub gl keep circ
  in="$(mktemp)" || { cat; return 0; }
  ask="$in.ask"; sub="$in.sub"; gl="$in.gl"; keep="$in.keep"
  cat > "$in"
  # `-z`, then the TAB split: a submodule path may carry a space, which a whitespace awk split
  # would cut in half and then never match.
  ( cd "$TREE" && git ls-files -s -z 2>/dev/null ) | tr '\0' '\n' \
    | awk -F'\t' 'substr($1, 1, 7) == "160000 " { print $2 }' > "$gl"
  awk -v glf="$gl" -v subf="$sub" '
    BEGIN { while ((getline g < glf) > 0) if (g != "") gl[g] = 1 }
    {
      p = $0
      if (p == ".git/modules" || index(p, ".git/modules/") == 1) { print p > subf; next }
      for (g in gl) if (p == g || index(p, g "/") == 1) { print g > subf; next }
      print p
    }' "$in" > "$ask" || { cat "$in"; rm -f "$in" "$ask" "$sub" "$gl" "$keep"; return 0; }
  # CHECK-IGNORE'S OWN STATUS IS READ, NOT A PIPELINE'S. On a refused batch it prints verdicts for
  # the rows BEFORE the offending one and then exits 128; piped into sed and sort, only `pipefail`
  # stood between that partial list and the caller -- measured: sourced without it, the partial
  # list came back as the filtered set and every row after the refusal was silently dropped.
  # 0 (some ignored) and 1 (none ignored) are verdicts; anything else is not.
  {
    if [ -s "$ask" ]; then
      ( cd "$TREE" && git check-ignore --stdin --non-matching --verbose < "$ask" ) > "$keep.ci" 2>/dev/null
      circ=$?
      if [ "$circ" -le 1 ] && sed -n 's/^::[[:space:]]*//p' "$keep.ci" | LC_ALL=C sort -u > "$keep" && [ -s "$keep" ]; then
        cat "$keep"
      else
        # No usable verdict -- keep everything rather than silently emptying the read-set.
        cat "$ask"
      fi
    fi
    [ -s "$sub" ] && cat "$sub"
  } | LC_ALL=C sort -u
  rm -f "$in" "$ask" "$sub" "$gl" "$keep" "$keep.ci"
}
# READSET_DROP_END

# READSET_PSEUDO_BEGIN
# Driven by core/fixtures/readset-skip, under all three tracers through the one call site where
# their sets meet, and from its sentinels by the backlog receipt; it reads only $TREE and stdin.
#
# A PSEUDO-PATH IS AN ARGV STRING THE TRACER SAW AS A LOOKUP, NOT A FILE ANY FIXTURE DEPENDS ON.
# Fixtures pass placeholder strings such as `<string>` or `sub/<unknown>` to the programs they
# test; the kernel reports the failed lookup under the tree, and the map then carried rows naming
# no file. A row is dropped ONLY when BOTH hold: its LAST component is a whole `<...>` token (no
# `/` inside), and nothing by that name exists in the trace tree, followed or not (`-e` or `-L`).
# So `a<b>c` and `e<f>g.sh` stay (the brackets do not span the component), `d/<real>` stays when a
# file of that name was traced (a fixture may genuinely create one), and an absent ordinary path
# such as `src/missing.sh` stays (a negative lookup on a real name IS a dependency: creating it
# can change the fixture's outcome).
# A LAST COMPONENT LEADING WITH `-` IS DROPPED UNDER THE SAME TWO CONDITIONS, and it is exempt from
# that dependency rule because it is not a name the fixture looked up: it is an option string a
# tool took as an operand -- a `grep` option written after `--`, read as a file and looked up under
# the tree. No fixture depends on the absence of a file called `--exclude-dir=fixtures`. A file
# whose name does start with `-` and exists in the trace tree is kept, exactly as `d/<real>` is.
# On check-3b-locked-anchor's next trace this drops `core/fixtures/check-3b-locked-anchor/-`.
# COSMETIC, AND THE ENTRY THAT ADDED IT IS A NOTE. The runner keeps only manifest paths that pass
# `[ -f ]` (.githooks/pre-push, the manifest build), so such a row could never select a fixture;
# this only stops the map carrying rows that look like a tracer fault.
# THE COLON-SHAPED ROWS ARE DELIBERATELY NOT FILTERED (`file:/var/...`, `<hex>:core/...`,
# `HEAD:core/...`): they are negative lookups of argv strings the runner never hashes, and telling
# a `rev:path` argument from a real file whose name carries a colon needs its own design.
readset_drop_pseudo() { # reads repo-relative paths on stdin, writes all but the absent pseudo-paths
  # Two arms, both applied to the LAST component (`${p##*/}` holds no `/` by construction): the
  # glob `^<[^/]*>$` and the option shape `^-`. Both share one existence test, so either shape
  # survives when it names a file or link in the traced tree.
  local p
  while IFS= read -r p; do
    case "${p##*/}" in
      '<'*'>') if [ -e "$TREE/$p" ] || [ -L "$TREE/$p" ]; then printf '%s\n' "$p"; fi ;;
      -*) if [ -e "$TREE/$p" ] || [ -L "$TREE/$p" ]; then printf '%s\n' "$p"; fi ;;
      *) printf '%s\n' "$p" ;;
    esac
  done
  return 0
}
# READSET_PSEUDO_END

# READSET_CANARY_BEGIN
# The loss canary's comparison: paths in the atime set ($1) absent from the stream set ($2),
# written to $3. Prints their COUNT, or `unreadable` when the comparison could not run.
# Kept between sentinels so readset-skip can reach the unreadable branch, which no real trace
# produces on demand.
# READ OFF comm's OWN STATUS, NEVER A PIPELINE'S AND NEVER A DEFAULT OF 0. A comm that could not
# read either side leaves $3 empty, so a count taken anyway reads 0, and a 0 MAPS the fixture --
# the fail-open direction. `unreadable` is non-zero to the caller's guard, so it omits.
readset_loss_canary() {
  local n
  if LC_ALL=C comm -23 "$1" "$2" > "$3" 2>/dev/null; then
    n="$(grep -c . "$3")" || n=0
    printf '%s\n' "$n"
  else
    printf 'unreadable\n'
  fi
}
# READSET_CANARY_END

# READSET_LOCALMAP_BEGIN
# `--local-map` mode's three helpers. Kept between sentinels so core/fixtures/readset-skip drives
# the shipped logic on seeded files; none of them reads a global.
#
# readset_verdict_sig <log> <root>... -- the MULTISET of a fixture's verdict lines, normalised.
# A verdict line is one whose first word is `ok`, `FAIL` or `PASS`, or which carries `: PASS` or
# `: FAIL` (a fixture's own summary line). Every root given is replaced by `<ROOT>`, every path
# under a temp directory by `<TMP>`, every run of digits by `N`, and the lines are sorted. Two runs
# of one fixture on one tree give one signature; a trace whose sandbox changed an outcome does not.
readset_verdict_sig() {
  local log="$1"; shift
  [ -r "$log" ] || return 2
  RS_ROOTS="$(printf '%s\n' "$@")" awk '
    BEGIN { n = split(ENVIRON["RS_ROOTS"], r, "\n") }
    /^[ \t]*(ok|FAIL|PASS)([ \t]|$)/ || /: (PASS|FAIL)([ \t(]|$)/ {
      l = $0
      for (i = 1; i <= n; i++) if (r[i] != "") while ((p = index(l, r[i])) > 0) l = substr(l, 1, p - 1) "<ROOT>" substr(l, p + length(r[i]))
      gsub(/(\/private)?\/(var\/folders|tmp)\/[^ \t:'"'"'")]*/, "<TMP>", l)
      gsub(/[0-9]+/, "N", l)
      print l
    }' "$log" | LC_ALL=C sort
}
#
# readset_hash_rows <tree> <fx> <set file> -- prints `<fx>\t<path>\t<sha256>` for every path of the
# set, `-` for one that is not a regular file in <tree> (a directory, a negative lookup). The hash is
# the trace COPY's: the hook honours the row set only while every one of these still matches.
# THE LOOP ENDS 0 WHATEVER ITS LAST PATH IS. Spelled `[ -f "$p" ] && printf`, a set whose LAST path
# was a directory or an absent name ended the loop on the failed test, and under `pipefail` that
# failed the whole hash: a clean trace was then dropped as `could not hash <fx>'s set in the trace
# copy -- not recorded`. FAIL-CLOSED BY COUNT, not by the pipeline's status alone: the number of
# hashed lines must equal the number of regular files fed to shasum, so an unreadable file (shasum
# prints nothing for it) still refuses when the caller runs without `pipefail`.
readset_hash_rows() {
  local tree="$1" fx="$2" set="$3" p nsha
  ( cd "$tree" || exit 1
    n=0
    while IFS= read -r p; do if [ -f "$p" ]; then printf '%s\0' "$p"; n=$((n + 1)); fi; done < "$set" > "$set.reg" || exit 1
    printf '%s\n' "$n" > "$set.nreg" || exit 1
    xargs -0 -n 200 shasum -a 256 -- < "$set.reg" 2>/dev/null
  ) | awk '{ s = $1; p = $0; sub(/^[0-9a-f]+  /, "", p); print p "\t" s }' > "$set.sha" || return 1
  nsha="$(grep -c . "$set.sha")" || nsha=0
  [ "$(cat "$set.nreg" 2>/dev/null)" = "$nsha" ] || return 1
  awk -F'\t' -v fx="$fx" -v sha="$set.sha" '
    BEGIN { while ((getline l < sha) > 0) { i = index(l, "\t"); h[substr(l, 1, i - 1)] = substr(l, i + 1) } }
    $0 != "" { print fx "\t" $0 "\t" (($0 in h) ? h[$0] : "-") }' "$set"
}
#
# readset_local_write <local map> <committed map> <ok rows> <discards> <traced fixtures> <deriver sha>
#   <ok rows>   `<fx>\t<path>\t<sha>` for every fixture whose trace was clean
#   <discards>  `<fx>\t<key>\t<why>` for every fixture whose trace was discarded
# Rewrites <local map> ATOMICALLY (a temp file beside it, then mv): every traced fixture's rows are
# replaced -- a fixture the committed map names included, because the hook's valid local rows
# REPLACE that fixture's committed ones (that is how a stale record clears) -- a clean one gains its `#deriver` key row, and a discarded one carries
# `<fx>\t#discards\t<n>\t<key>\t<why>` -- n counts consecutive discards on one key, so a changed
# key starts again at 1.
#   <present>   one fixture basename per line: the fixtures with a run.sh in the checkout this trace
#               was started from. Every row of a fixture NOT in it is pruned -- a deleted or renamed
#               fixture's rows otherwise stay in the local map for good, and the hook would read
#               them. An absent or empty file prunes every untraced row, which leaves those fixtures
#               unmapped: they run and are re-traced, never skipped.
readset_local_write() {
  local lm="$1" cm="$2" okr="$3" disc="$4" traced="$5" dsha="$6" present="${7:-/dev/null}" tmp
  tmp="$lm.tmp.$$"
  traced="$(printf '%s' "$traced" | tr '\n\t' '  ')"
  {
    [ -s "$present" ] && sed 's/^/P\t/' "$present"
    [ -s "$disc" ] && sed 's/^/D\t/' "$disc"
    [ -s "$lm" ] && sed 's/^/L\t/' "$lm"
    [ -s "$okr" ] && sed 's/^/O\t/' "$okr"
    :
  } | awk -F'\t' -v traced=" $traced " -v dsha="$dsha" '
    $1 == "P" { here[$2] = 1; next }
    $1 == "D" { dk[$2] = $3; dw[$2] = $4; next }
    $1 == "L" {
      if (!($2 in here)) next
      if ($3 == "#discards") { pn[$2] = $4; pk[$2] = $5 }
      if (index(traced, " " $2 " ") == 0) { sub(/^L\t/, ""); print; next }
      next }
    $1 == "O" { ok[$2] = 1; sub(/^O\t/, ""); print; next }
    END {
      for (f in ok) print f "\t#deriver\t" dsha
      for (f in dk) { n =((f in pk) && pk[f] == dk[f]) ? pn[f] + 1 : 1; print f "\t#discards\t" n "\t" dk[f] "\t" dw[f] }
    }' | LC_ALL=C sort > "$tmp" || { rm -f "$tmp"; return 1; }
  mv "$tmp" "$lm" || { rm -f "$tmp"; return 1; }
}
# READSET_LOCALMAP_END

if [ "$TRACER" = fs_usage ]; then
  say "fs_usage runs as root; fixtures run as '$RUN_AS'"
elif [ "$TRACER" = both ]; then
  say "both tracers: fs_usage and log stream run as root; each fixture runs ONCE as '$RUN_AS' under sandbox-exec; the map is NOT written"
else
  say "sandbox tracer: fixtures run as '$RUN_AS' under sandbox-exec; no root anywhere"
  [ ! -e "$TRACE_ROOT" ] || [ -O "$TRACE_ROOT" ] || die "$TRACE_ROOT exists and is not owned by '$RUN_AS' (a root fs_usage run leaves one behind). Refusing to delete it; point AI_DLC_READSET_TRACE_ROOT elsewhere."
fi
rm -rf "$TRACE_ROOT" 2>/dev/null
[ ! -e "$TRACE_ROOT" ] || die "could not clear $TRACE_ROOT -- a tree left by another run, or one this user cannot delete"
mkdir -p "$TRACE_ROOT/t" "$TRACE_ROOT/w" || die "cannot create $TRACE_ROOT"
# CANONICAL SPELLING, because both tracers match on the path STRING. The kernel reports
# `/private/tmp/...`; a `/tmp/...` root would make the sandbox's `subpath` and the stream
# predicate match nothing, and every fixture would come back with an atime-only read-set.
TRACE_ROOT="$(cd "$TRACE_ROOT" && pwd -P)" || die "cannot resolve $TRACE_ROOT"
# `--local-map` removes the trace root it created on EVERY exit, a refusal included.
[ -z "$LOCAL_MAP" ] || trap 'rm -rf "$TRACE_ROOT"' EXIT
TREE="$TRACE_ROOT/t"
WORK="$TRACE_ROOT/w"
SENTINEL="$TREE/.readset-sentinel"
ENDMARK="$TREE/.readset-end"
# UNDER THE SANDBOX TRACER THE MARKERS LIVE BESIDE THE TREE, NOT IN IT. A fixture that walks its
# tree (`find .`, a python os.walk, an importer scanning every file) stats both markers, and each
# such touch is one more marker line in the stream. The window is cut at the LAST start marker and
# the FIRST end marker, so a walk moves its start INTO the fixture's run -- every report before the
# walk silently leaves the set -- or puts an end marker before it, which omits the fixture.
# Measured on the reference consumer: 8 start and 6 end marker lines in one fixture's stream,
# where one of each is expected. A sibling directory the fixture never walks is reported under
# the same profile and stream, and sandbox_paths keeps only paths under the tree.
#
# UNDER `--tracer both` THE MARKERS ARE IN $MARKDIR TOO, and fs_usage is told to keep that prefix
# as well as the tree's (`-e "$TREE/" -e "$MARKDIR/"` below). Widening its filter to the whole
# $TRACE_ROOT/ instead would feed it its own output: the raw capture is written under $WORK, which
# is under that root, so every line grep writes is an fs_usage event grep then matches again.
MARKDIR="$TRACE_ROOT/m"
if [ "$TRACER" = sandbox ] || [ "$TRACER" = both ]; then
  mkdir -p "$MARKDIR" || die "cannot create $MARKDIR"
  SENTINEL="$MARKDIR/.readset-sentinel"
  ENDMARK="$MARKDIR/.readset-end"
fi

# THE SANDBOX PROFILE IS SCOPED TO THE TREE, AND THE SCOPE IS LOAD-BEARING. `(with report)` on
# `(allow default)` reports every operation the fixture makes anywhere on the machine; measured,
# that dropped 64,673 messages on one heavy fixture and lost paths. Reporting only file and exec
# operations under the tree keeps the stream small enough to deliver.
# EVERY EMITTER ENDS WITH A ROOT-LITERAL ALLOW CLAUSE CARRYING NO `(with report)`: it removes the
# reports of `file-read-metadata` and `file-test-existence` on the tree ROOT ALONE -- every `bash`
# `cd` and `[ -d ]` a fixture makes there, 4155 of 4399 report lines on one fixture, which drove its
# stream into drops (BL-470). Those lines never entered the map (sandbox_paths keeps only paths under
# `$TREE/`). `file-read-data` on the root (a directory listing, which IS a read) and every operation
# below the root are still reported; core/fixtures/readset-sandbox-root-clause renders all three emitters and measures both.
# AI_DLC_READSET_SANDBOX_PROFILE names a replacement profile file, `@TREE@` substituted -- it
# exists so core/fixtures/readset-skip can force event loss with an unscoped profile and prove
# the refusal below fires. It is not a tuning knob.
#
# sandboxed() RUNS ONE COMMAND THE WAY THIS TRACER RUNS A FIXTURE. Under `both` the caller is root,
# and a fixture must never be: it drops to the invoking user BEFORE entering the profile, so the
# probe, both marker reads and the fixture itself all execute as the user the map is derived for.
#
# UNDER `--local-map` EVERY LAUNCH CARRIES `-D FXTAG=<fixture>`, and the profile appends
# `FXTAG=<fixture>;` to each report it makes, so the stream for one fixture is selected by its own
# tag. A TRIP clause after the tree's reports the exec of anything in the REFUSED set -- the
# setuid/setgid binaries on this machine, `/usr/bin/log` and `sandbox-exec` -- tagged `;TRIP`, and a
# window carrying one is discarded: a fixture that escalates or re-enters the tracer is not a
# fixture whose reads one unprivileged sandbox saw. The set is DERIVED at trace time by
# readset_trip_set, never hand-listed.
CUR_FX="__probe__"
# PREPUSH_POOL_DEPTH HANDED TO A TRACED FIXTURE IS THE CALLER'S DEPTH + 1, never a pinned 1. A deriver
# started by a fixture that a pool dispatched already carries a depth, and pinning 1 under it would hand
# the traced fixture a SHALLOWER depth than its real nesting -- the recursion bound counts levels, so a
# reset re-opens a level. The marker is read the way the hooks read it: absent is depth 0, and SET but
# not a number or longer than five digits is depth 2 (fail closed), so this deriver can never hand a
# traced fixture a shallower depth than the hook would have refused at. `10#` reads 08 and 09 as base
# ten, so `value too great for base` cannot occur. Computed HERE, at top level before any sandboxed()
# call, so the value is bound wherever a launch reads it (`set -u` makes an unbound read fatal).
RS_POOL_DEPTH="${PREPUSH_POOL_DEPTH:-0}"
case "$RS_POOL_DEPTH" in *[!0-9]*|??????*) RS_POOL_DEPTH=2 ;; esac
RS_POOL_DEPTH=$((10#$RS_POOL_DEPTH + 1))
sandboxed() {
  if [ "$TRACER" = both ]; then
    sudo -n -u "$RUN_AS" sandbox-exec -f "$PROFILE" "$@"
  elif [ -n "$LOCAL_MAP" ]; then
    sandbox-exec -D FXTAG="$CUR_FX" -f "$PROFILE" "$@"
  else
    sandbox-exec -f "$PROFILE" "$@"
  fi
}
readset_trip_set() {
  find /usr/bin /bin /usr/sbin /sbin /usr/libexec -maxdepth 1 -type f \( -perm -4000 -o -perm -2000 \) 2>/dev/null
  printf '%s\n' /usr/bin/log "$(command -v sandbox-exec)"
}
if [ "$TRACER" = sandbox ] || [ "$TRACER" = both ]; then
  PROFILE="$WORK/sandbox.sb"
  if [ -n "${AI_DLC_READSET_SANDBOX_PROFILE:-}" ]; then
    [ -r "$AI_DLC_READSET_SANDBOX_PROFILE" ] || die "AI_DLC_READSET_SANDBOX_PROFILE names an unreadable file"
    awk -v t="$TREE" -v m="$MARKDIR" '{
        while ((i = index($0, "@TREE@")) > 0) $0 = substr($0, 1, i - 1) t substr($0, i + 6)
        while ((i = index($0, "@MARK@")) > 0) $0 = substr($0, 1, i - 1) m substr($0, i + 6)
        print }' \
      "$AI_DLC_READSET_SANDBOX_PROFILE" > "$PROFILE" || die "cannot write $PROFILE"
    printf '(allow file-read-metadata file-test-existence (literal "%s"))\n' "$TREE" >> "$PROFILE" || die "cannot write $PROFILE"
  elif [ -n "$LOCAL_MAP" ]; then
    { printf '(version 3)\n(allow default)\n(allow file* process-exec* (subpath "%s") (subpath "%s") (with report) (with message (string-append "FXTAG=" (param "FXTAG") ";")))\n' "$TREE" "$MARKDIR"
      printf '(allow process-exec*'
      readset_trip_set | LC_ALL=C sort -u | awk 'NF { printf " (literal \"%s\")", $0 }'
      printf ' (with report) (with message (string-append "FXTAG=" (param "FXTAG") ";TRIP")))\n'
      printf '(allow file-read-metadata file-test-existence (literal "%s"))\n' "$TREE"
    } > "$PROFILE" || die "cannot write $PROFILE"
  else
    printf '(version 3)\n(allow default)\n(allow file* process-exec* (subpath "%s") (subpath "%s") (with report))\n(allow file-read-metadata file-test-existence (literal "%s"))\n' "$TREE" "$MARKDIR" "$TREE" > "$PROFILE" \
      || die "cannot write $PROFILE"
  fi
  sandboxed true 2>"$WORK/sandbox-probe.err" </dev/null \
    || die "sandbox-exec refused the profile: $(head -1 "$WORK/sandbox-probe.err")"
fi

# `--local-map` PRECONDITIONS THAT NEED THE PROFILE, and the cleanup it owes. A one-second `log
# stream` probe must see its own tagged sentinel read: a push made from INSIDE a sandbox (an agent
# harness, a nested sandbox-exec) gets a stream that delivers nothing, and every fixture would then
# be discarded one at a time for a reason that is not the fixture's. Refused here instead, once,
# with nothing written. The trace root is removed on every exit -- this mode runs unattended after
# every green push, and a tree copy left per run is a disk leak nobody is watching.
if [ -n "$LOCAL_MAP" ]; then
  CUR_FX="__liveness__"
  echo "liveness" > "$SENTINEL"
  "$LOG_BIN" stream --level debug --style compact \
    --predicate "eventMessage CONTAINS \"FXTAG=$CUR_FX;\"" > "$WORK/liveness.raw" 2>&1 &
  lv_pid=$!
  lv_ok=0; i=0
  while [ "$i" -lt 5 ]; do
    sandboxed cat "$SENTINEL" >/dev/null 2>&1 </dev/null
    if grep -q 'readset-sentinel' "$WORK/liveness.raw" 2>/dev/null; then lv_ok=1; break; fi
    sleep 0.2; i=$(( i + 1 ))
  done
  kill "$lv_pid" 2>/dev/null; wait "$lv_pid" 2>/dev/null
  [ "$lv_ok" -eq 1 ] || die "LIVENESS: a 1s log stream never saw this run's own tagged sentinel read -- a push from inside a sandbox, or a stream that delivers nothing. Nothing traced, nothing written; the fixtures stay unmapped."
fi

# THE COPY COMES AFTER THE LIVENESS PROBE. A `--local-map` run whose stream delivers nothing refuses
# above, and a consumer pushing from inside a sandbox refuses on every green push -- so the tree copy,
# the one step here that scales with the repository, is paid only by a run that can use it. Nothing
# above reads the copy: the profile names $TREE as a string, and the probe reads a marker beside it.
say "copying the tree to $TREE"
readset_copy_tree "$REPO_ROOT" "$TREE" "$WORK" || die "copy failed"
[ -d "$TREE/.git" ] || die "copy carries no .git; git-backed fixtures would fail for the wrong reason"
# THE UNREAD CONTROL. A file nothing reads, reset with every other file before each fixture and
# required to be STILL at the 2001 epoch after it. If its atime moved, either the reset did not
# take (so every "read" in that window is really the copy's own timestamp) or something walked the
# tree, and either way the atime set is not a set of the fixture's reads: the fixture is omitted.
# It sits in `.git/` because git never reads an unknown file there and `git status` never lists
# one. Measured before placing it: 0 of 33 census fixtures read `.git/description`, the nearest
# file git also ignores, against 2 reading `.git/HEAD`, so no fixture in that set walks `.git/`.
UNREAD_CTL=".git/readset-unread-control"
printf 'never read\n' > "$TREE/$UNREAD_CTL" || die "cannot plant the unread control $TREE/$UNREAD_CTL"
if [ "$TRACER" = fs_usage ] || [ "$TRACER" = both ]; then
  chown -R "$RUN_AS" "$TREE" || die "chown failed"
fi
# The sentinels live inside the tree because the tracer filters on the tree prefix, which
# makes them untracked files. Left visible they peg `git status --porcelain` and the
# contamination guard below can never report anything.
printf '.readset-sentinel\n.readset-end\n' >> "$TREE/.git/info/exclude"

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
  --all)  LIST="$(readset_all_list "$TREE/$FIXTURE_ROOT")" ;;
  --list) LIST="$LIST_ARG"; [ -n "$LIST" ] || die "--list needs a fixture list" ;;
  *)      die "$USAGE" ;;
esac
N_SUBJECT="$(echo "$LIST" | wc -w | tr -d ' ')"
[ "$N_SUBJECT" -gt 0 ] || die "no drivable fixtures found -- an empty map would skip the entire suite"

reset_atimes() {
  find "$TREE" -type f -print0 2>/dev/null | xargs -0 -P 8 -n 500 touch -a -t 200101010000 2>/dev/null
  return 0
}

# READSET_BOTH_BEGIN
# `--tracer both`: the comparison of one fixture's two sets, and the closing verdict over all of
# them. Kept between sentinels because the rest of this mode needs root: core/fixtures/readset-skip
# extracts THIS block and drives it, so the miss definition and the verdict under test are the
# shipped ones. readset_both_compare calls drop_ignored, which the fixture sources from its own span.
#
# THE TWO EXCLUSIONS, AND NOTHING ELSE (see the header for why each): `.git` and `.git/**` by
# prefix, then every path `git check-ignore` calls ignored. drop_ignored FAILS OPEN -- if
# check-ignore cannot run every path is kept -- so a broken filter can only ADD misses, which
# refuses the replacement rather than approving it.
readset_both_comparable() {
  awk '$0 != "" && $0 != ".git" && index($0, ".git/") != 1' | drop_ignored
}
#   $1 the fs_usage set   $2 the sandbox set   $3 output prefix
# Writes $3.sbmiss (in fs_usage, not in the sandbox -- the verdict's subject) and $3.fsmiss (the
# reverse), and prints `<sandbox-missed> <fs_usage-missed>`. Returns 2 if either set is unreadable.
readset_both_compare() {
  local fs="$1" sb="$2" out="$3"
  [ -r "$fs" ] && [ -r "$sb" ] || return 2
  readset_both_comparable < "$fs" > "$out.fs.cmp" || return 2
  readset_both_comparable < "$sb" > "$out.sb.cmp" || return 2
  LC_ALL=C comm -23 "$out.fs.cmp" "$out.sb.cmp" > "$out.sbmiss" || return 2
  LC_ALL=C comm -13 "$out.fs.cmp" "$out.sb.cmp" > "$out.fsmiss" || return 2
  printf '%s %s\n' "$(wc -l < "$out.sbmiss" | tr -d ' ')" "$(wc -l < "$out.fsmiss" | tr -d ' ')"
}
#   $1 the LISTED fixtures (whitespace-separated)   $2 the results file, one row per fixture the
#   loop finished: `<fx>\tcompared\t<sandbox-missed>\t<fs_usage-missed>\t` or
#   `<fx>\tuncompared\t-\t-\t<why>`   $3 the missed-paths file it names   $4 scratch dir
# Prints ONE verdict line and returns 0, 1 or 2.
#
# COMPARED IS COUNTED AGAINST LISTED, NEVER AGAINST THE ROWS PRESENT. A loop that died part-way
# leaves no row for the fixtures after it, and a verdict read off the rows alone would be clean over
# whatever subset happened to finish -- a comparison passing having compared almost nothing.
readset_both_verdict() {
  local list="$1" results="$2" missed="$3" scratch="$4" f
  [ -r "$results" ] || { echo "REFUSED: EXAMINED NOTHING -- the results file $results is unreadable"; return 2; }
  : > "$scratch/both.listed" || { echo "REFUSED: cannot write $scratch/both.listed"; return 2; }
  for f in $list; do printf '%s\n' "$f" >> "$scratch/both.listed"; done
  awk -F'\t' -v missed="$missed" '
    FILENAME == ARGV[1] { if ($0 != "") listed[++n] = $0; next }
    { st[$1] = $2; sb[$1] = $3; why[$1] = $5 }
    END {
      if (n == 0) { print "REFUSED: EXAMINED NOTHING -- no fixture was listed, and a comparison over none is not a verdict"; exit 2 }
      c = 0; u = ""; N = 0; M = 0
      for (i = 1; i <= n; i++) {
        f = listed[i]
        if ((f in st) == 0)         { u = u (u == "" ? "" : "; ") f " (no result row -- the loop never finished it)" }
        else if (st[f] != "compared") { u = u (u == "" ? "" : "; ") f " (" why[f] ")" }
        else if (sb[f] !~ /^[0-9]+$/) { u = u (u == "" ? "" : "; ") f " (unreadable miss count)" }
        else { c++; if (sb[f] > 0) { N += sb[f]; M++ } }
      }
      if (c < n) {
        printf "REFUSED: compared %d of %d listed fixture(s) -- a verdict over part of the suite is not one over all of it. Uncompared: %s\n", c, n, u
        exit 2
      }
      if (N > 0) { printf "SANDBOX-MISSES %d path(s) across %d fixture(s) -- each listed as <fixture>TAB<path> in %s\n", N, M, missed; exit 1 }
      printf "SANDBOX-MISSES-NOTHING -- %d of %d listed fixture(s) compared; no path outside .git/** and the ignored set was seen by fs_usage and not by the sandbox\n", c, n
      exit 0
    }' "$scratch/both.listed" "$results"
}
# READSET_BOTH_END

OMITTED=""; MAPPED=0; TOTAL_PATHS=0; DONE=""
: > "$WORK/map"
: > "$WORK/digest.rows"
: > "$WORK/both.results"
: > "$WORK/both.missed"

# THE SANDBOX TRACER'S EXTRACTION. One kernel report per line:
#   ... Sandbox: <proc>(<pid>) allow <op> <TREE>/<path>
# The PATH RUNS TO END OF LINE and may carry spaces, so it is everything after the op token, never
# a `\S*` match. Only file* and process-exec* ops are kept, then the same DAEMONS filter the
# fs_usage extraction applies. Reads the window on stdin, writes tree-relative paths.
# Between sentinels, with DAEMONS and norm, so a fixture can source the three and drive them.
# READSET_SBPATHS_BEGIN
sandbox_paths() {
  awk -v tree="$TREE/" -v d="^($DAEMONS)$" '
    {
      i = index($0, "Sandbox: "); if (i == 0) next
      rest = substr($0, i + 9)
      j = index(rest, ") allow "); if (j == 0) next
      head = substr(rest, 1, j - 1); k = 0
      for (m = length(head); m > 0; m--) if (substr(head, m, 1) == "(") { k = m; break }
      proc = (k ? substr(head, 1, k - 1) : head)
      rest = substr(rest, j + 8)
      sp = index(rest, " "); if (sp == 0) next
      op = substr(rest, 1, sp - 1); path = substr(rest, sp + 1)
      if (op !~ /^(file|process-exec)/) next
      if (proc ~ d) next
      if (index(path, tree) != 1) next
      print substr(path, length(tree) + 1)
    }'
}
# READSET_SBPATHS_END

# THE MAP IS WRITTEN AFTER EVERY ACCEPTED FIXTURE, NOT ONLY AT THE END. Each trace is independent,
# and a run interrupted after N clean fixtures used to lose all N: measured, a 5-fixture run killed
# after 2 clean traces wrote neither. readset_write_map is the whole merge-guard-control-write
# sequence, called in a SUBSHELL with LIST set to the fixtures traced so far after each accepted
# fixture (so a `die` there skips that write and leaves the previous map in place), and once more
# at the end over the whole LIST, which writes the OMITTED line and is the map an uninterrupted run
# always wrote. Its merge reads the map the previous call wrote; that map differs from the original
# only in fixtures this run already traced, and the final merge replaces all of those, so the final
# map is byte-identical to the end-only one. core/fixtures/readset-skip kills a 3-fixture run in its
# third fixture and asserts the first two landed, and cmp-s an uninterrupted map against end-only.
# THE WRITE IS A TEMP FILE BESIDE THE MAP, then mv, so an interrupt mid-write never leaves a
# truncated map. `cp -p` first carries the existing map's mode and, under sudo, its owner.
readset_write_map() {
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
#
# THE PAIR READS THIS RUN'S TRACED ROWS, SO IT RUNS ONLY WHEN plan-shape HAS ROWS IN THEM. A listed
# plan-shape that was OMITTED has none by construction; judged anyway, the positive control fails
# and the run dies "controls failed" -- one omitted fixture discarding every good trace, which is
# the defect the merge guard below was fixed for. The omission is printed instead, and the fixture
# runs on every push because it is unmapped. Same shape as the `--list` carve-out after this block.
case " $LIST " in *" plan-shape "*) ;; *) FIXTURE_HAS_PLAN_SHAPE=no ;; esac
if [ "${FIXTURE_HAS_PLAN_SHAPE:-yes}" = yes ] && ! grep -q '^plan-shape	' "$WORK/map"; then
  echo "  SKIP  plan-shape controls: plan-shape OMITTED this run"
  FIXTURE_HAS_PLAN_SHAPE=no
fi
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
# UNDER `--list` THIS CONTROL READS THE MERGED MAP, BELOW, NOT THIS RUN'S TRACED COUNT. A one-fixture
# refresh whose fixture is OMITTED maps zero fixtures in this run by construction, and dying here
# left that fixture's STALE rows in the map -- the map went on asserting a read-set the run had
# just refused. Written instead, the omission drops those rows and the fixture runs every push.
# Under `--all` the traced count IS the whole map, so it is read here.
if [ "$MODE" != --list ]; then
  [ "$MAPPED" -gt 0 ] || { echo "  FAIL  zero fixtures mapped -- an empty map would skip the whole suite"; FAIL=1; }
fi

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
# STAGED, WITH ITS STATUS READ: a `< <(cut … | sort -u)` feed discarded it, so a failed read of
# the map checked no fixture and this POSITIVE control passed having looked at nothing.
if cut -f1 "$WORK/map" | sort -u > "$WORK/map-fixtures"; then
  while IFS= read -r cfx; do
    [ -n "$cfx" ] || continue
    if ! grep -qxF "$cfx	$FIXTURE_ROOT/$cfx/run.sh" "$WORK/map"; then
      echo "  FAIL  $cfx's read-set does not name its own driver $FIXTURE_ROOT/$cfx/run.sh"; FAIL=1
    fi
  done < "$WORK/map-fixtures"
else
  echo "  FAIL  the fixture list could not be read out of $WORK/map, so this positive control did not run"; FAIL=1
fi

# THE MERGE HAPPENS HERE, ABOVE THE NEGATIVE CONTROL, BECAUSE THAT CONTROL JUDGES THE MAP THIS
# RUN WILL WRITE -- which is the merged one, never the handful of fixtures this run traced.
# Judged on the traced map alone, a `--list "<one fixture>"` run compares that fixture's set
# against a universe built from that same set: the two are equal by construction, N_PROPER is 0
# for every possible input, and the control fails every single-fixture refresh while looking
# exactly like a map that discriminates nothing. Measured: three owed `--list` refreshes failed
# identically, and the only workaround was to list more fixtures.
#
# THE ORDERING HAS A CONSEQUENCE AND IT IS DELIBERATE. The merge's "dropped '$f'" die now runs
# BEFORE the control verdicts are read, so a run whose merge lost an untraced fixture reports
# that die rather than a control line -- the earlier failure names the earlier fault, and the
# map is unwritten either way.
#
# THE `--all` READING CHANGES ONLY WHERE THE COMMITTED MAP NAMES A FIXTURE THAT IS NO LONGER ON
# DISK. Under `--all` every fixture on disk is traced, so the merged map adds nothing except
# such a stale fixture's paths, which would widen the universe. That case is live, not
# hypothetical: the committed map has carried rows for a fixture with no directory under the
# fixture root (notify-hook-channel). Such a fixture is untraced and kept by the merge, so the
# guard below does not die on it -- its rows survive every `--all` run until removed by hand.
MERGED="$WORK/merged"
readset_merge_map "$MAP" "$WORK/map" "$LIST" | LC_ALL=C sort -u > "$MERGED"
# THE DIGEST LINES CARRIED OVER ARE SPLIT OFF HERE, before anything counts fixtures: a `# digest` line
# has no tab, so `cut -f1` would count it as a fixture of its own.
# grep exits 1 on no match, which leaves the redirect's empty file -- correct; 2 is a failed read, which dies.
SPLIT_RC=0; grep '^# digest ' "$MERGED" > "$WORK/digest.carried" || SPLIT_RC=$?
[ "$SPLIT_RC" -le 1 ] || die "could not read the digest lines out of $MERGED"
SPLIT_RC=0; grep -v '^#' "$MERGED" > "$MERGED.rows" || SPLIT_RC=$?
[ "$SPLIT_RC" -le 1 ] || die "could not read the rows out of $MERGED"
mv "$MERGED.rows" "$MERGED" || die "could not split the digest lines out of $MERGED"
if [ "$MODE" = --list ]; then
  N_MERGED_FIX="$(cut -f1 "$MERGED" | LC_ALL=C sort -u | grep -c .)" || N_MERGED_FIX=0
  [ "$N_MERGED_FIX" -gt 0 ] || { echo "  FAIL  zero fixtures in the merged map -- an empty map would skip the whole suite"; FAIL=1; }
fi

# THE MERGE MUST NOT LOSE A FIXTURE IT WAS NOT ASKED ABOUT. Dropping one is SAFE (an unmapped
# fixture always runs) but it silently costs the skip, which is the entire point of the file --
# and the first version of `--list` did exactly that, rewriting the whole map from the handful
# of fixtures it had just traced. Asserted rather than trusted.
# The comparison is readset_untraced_lost, between sentinels above, so readset-skip drives it. Its
# output is staged to a file and its status read: a failed read must refuse, never pass as "lost
# nothing".
if [ -s "$MAP" ]; then
  readset_untraced_lost "$MAP" "$MERGED" "$LIST" > "$WORK/untraced.lost" \
    || die "could not compare $MAP against the merged map $MERGED -- refusing to write a map whose losses were never checked"
  if [ -s "$WORK/untraced.lost" ]; then
    f="$(head -1 "$WORK/untraced.lost")"
    die "merge dropped '$f', which this run never traced -- refusing to write a map that silently stops skipping"
  fi
fi

readset_discrimination_control "$MERGED" || FAIL=1

[ "$FAIL" -eq 0 ] || die "controls failed; the map was NOT written"

M_FIX="$(cut -f1 "$MERGED" | sort -u | wc -l | tr -d ' ')"
M_ENT="$(wc -l < "$MERGED" | tr -d ' ')"
M_PATH="$(cut -f2 "$MERGED" | sort -u | wc -l | tr -d ' ')"
[ "$M_ENT" -gt 0 ] || die "the merged map is empty -- refusing to write it"

# THE DIGESTS ARE ATTACHED ONLY AT THE FINAL WRITE (RS_FINAL=1), over this run's accepted fixtures, from
# the shas their paths had IN THE TRACE COPY -- the tree they were traced on, never the tree as it stands
# when the map is written, so an edit made during the run can only make a digest fail to match. The keep
# list is the runner's own manifest universe over the MERGED rows, which is the universe the runner will
# hash once this map is committed. A per-fixture write carries old digests for untraced fixtures and
# drops a traced fixture's old one, so an interrupted run leaves fixtures that select but cannot clear.
: > "$WORK/digest.new"
if [ "${RS_FINAL:-0}" = 1 ] && [ -s "$WORK/digest.rows" ]; then
  if [ "$HAVE_UNIVERSE" = 1 ]; then
    mkdir -p "$WORK/dgm" || die "cannot create $WORK/dgm"
    ( cd "$REPO_ROOT" && READSET_MAP="$MERGED" READSET_LOCAL=/dev/null readset_manifest "$WORK/dgm" )
    # A DIRECTORY'S LISTING IS TAKEN FROM THE TRACE COPY, the tree the row shas were taken on, so an edit made
    # to the checkout during the run can only make a digest fail to match.
    mkdir -p "$WORK/dgt" || die "cannot create $WORK/dgt"
    ( cd "$TREE" && READSET_MAP="$MERGED" READSET_LOCAL=/dev/null readset_manifest "$WORK/dgt" )
    if [ -s "$WORK/dgm/.paths" ] && [ -s "$WORK/dgt/.now" ] \
       && ( cd "$REPO_ROOT" && readset_dir_values "$WORK/digest.rows" "$WORK/dgt/.now" "$WORK/dgm/.paths" "$WORK/dgm/rows2" \
            && readset_digests "$WORK/dgm/rows2" "$WORK/dgm/rows2.keep" "$MAP_REL" "$WORK/dg" ) > "$WORK/digest.out"; then
      awk -F'\t' 'NF == 2 { print "# digest " $1 " " $2 }' "$WORK/digest.out" > "$WORK/digest.new"
    else
      say "note: could not compute the runner's universe or the digests -- no # digest line written; the traced fixtures select but cannot clear a stale key record"
    fi
  else
    say "note: $RUNNER carries no READSET_UNIVERSE span -- no # digest line written; the traced fixtures select but cannot clear a stale key record"
  fi
fi

MAP_TMP="$MAP.tmp.$$"
if [ -e "$MAP" ]; then cp -p "$MAP" "$MAP_TMP" || die "could not stage $MAP_TMP -- $MAP is unchanged"; fi
{
  echo "# GENERATED by derive-fixture-readsets.sh -- DO NOT EDIT BY HAND."
  echo "# LOG -- unbounded by design; rotation does not apply. It grows with the fixture suite and is regenerated whole, never trimmed."
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
  echo "# Each '# digest <fixture> <sha256>' line, after the rows, is the sha256 of that fixture's sorted"
  echo "# path<TAB>sha lines in the runner's universe as traced; the runner clears a stale key record when"
  echo "# it recomputes the same value over the tree it is pushing."
  echo "#"
  echo "# fixtures mapped: $M_FIX    entries: $M_ENT"
  [ -n "$OMITTED" ] && echo "# OMITTED by the last run (always run): $OMITTED"
  cat "$MERGED"
  LC_ALL=C sort -u "$WORK/digest.carried" "$WORK/digest.new"
} > "$MAP_TMP" || { rm -f "$MAP_TMP"; die "could not write $MAP_TMP -- $MAP is unchanged"; }
mv -f "$MAP_TMP" "$MAP" || { rm -f "$MAP_TMP"; die "could not move $MAP_TMP over $MAP -- $MAP is unchanged"; }
}

# The PRESENT set for `--local-map`, read off the checkout the hook pushed from, not the trace copy:
# a fixture deleted there since the copy was taken is gone for the next push too.
readset_local_present() {
  local _pd
  for _pd in "$REPO_ROOT/$FIXTURE_ROOT"/*/; do
    [ -f "${_pd}run.sh" ] || continue
    _pd="${_pd%/}"; printf '%s\n' "${_pd##*/}"
  done
}

for fx in $LIST; do
  DONE="${DONE}${DONE:+ }$fx"
  [ -z "$LOCAL_MAP" ] || { : > "$WORK/local.ok"; : > "$WORK/local.discards"; }
  raw="$WORK/$fx.raw"
  CUR_FX="$fx"
  # Under `--local-map` the stream selects this fixture's own tag, never the trace root: one
  # predicate per fixture window, as the other modes run one stream per window.
  STREAM_PRED="sender == \"Sandbox\" AND eventMessage CONTAINS \"$TRACE_ROOT/\""
  [ -z "$LOCAL_MAP" ] || STREAM_PRED="eventMessage CONTAINS \"FXTAG=$fx;\""
  echo "sentinel-$fx" > "$SENTINEL"
  echo "end-$fx" > "$ENDMARK"
  reset_atimes

  fsu_pid=""
  if [ "$TRACER" = both ]; then
    # TWO CAPTURES OF ONE EXECUTION. fs_usage keeps the marker prefix as well as the tree's, so
    # the sentinel both tracers settle on is the SAME read, in the same window.
    fs_usage -w -f filesys 2>/dev/null | grep --line-buffered -F -e "$TREE/" -e "$MARKDIR/" > "$raw.fsu" &
    fsu_pid=$!
    "$LOG_BIN" stream --level debug --style compact \
      --predicate "sender == \"Sandbox\" AND eventMessage CONTAINS \"$TRACE_ROOT/\"" > "$raw" 2>&1 &
    fs_pid=$!
  elif [ "$TRACER" = fs_usage ]; then
    fs_usage -w -f filesys 2>/dev/null | grep --line-buffered -F "$TREE/" > "$raw" &
    fs_pid=$!
  else
    # STARTED BEFORE THE FIXTURE, per window. `log show` afterwards returns nothing for these
    # reports, so a stream that was not live when an event fired has lost it for good -- which is
    # why the settle loop below and the end sentinel after the fixture are both required.
    "$LOG_BIN" stream --level debug --style compact \
      --predicate "$STREAM_PRED" > "$raw" 2>&1 &
    fs_pid=$!
  fi

  # ADAPTIVE SETTLE, AND IT IS A CONTROL RATHER THAN A GUESS. A fixed sleep cannot tell
  # "settled" from "not attached yet": measured, a 2s sleep still lost every fixture's own
  # run.sh to the capture boundary. Here the sentinel is read in a loop and the fixture does
  # not start until that read APPEARS IN THE TRACE, i.e. until tracing is provably live. Under
  # the sandbox tracer the read has to happen INSIDE the profile, or nothing reports it.
  settled=0; i=0
  while [ "$i" -lt 100 ]; do
    if [ "$TRACER" = fs_usage ]; then
      cat "$SENTINEL" >/dev/null 2>&1
    else
      sandboxed cat "$SENTINEL" >/dev/null 2>&1 </dev/null
    fi
    # Under `both`, settled means BOTH captures carry the sentinel: a fixture started when only
    # one tracer was live would be compared against a set that missed its opening reads.
    if grep -q 'readset-sentinel' "$raw" 2>/dev/null \
       && { [ "$TRACER" != both ] || grep -q 'readset-sentinel' "$raw.fsu" 2>/dev/null; }; then
      settled=1; break
    fi
    sleep 0.2; i=$(( i + 1 ))
  done

  # Run it the way the pre-push runner runs it: `bash <path>/run.sh` FROM THE REPO ROOT.
  # cd-ing into the fixture directory breaks the sanity arm of five fixtures and FABRICATES
  # failures. `-n` and </dev/null are not decoration: backgrounded, sudo reaches for the
  # controlling terminal, the process group takes SIGTTIN and the whole derivation stops dead
  # in state T with no error and no exit code.
  #
  # VAS_INNER_POOL_WIDTH=1 NARROWS validator-arm-selection's inner `xargs -P` pool on a traced run
  # (BL-375). At its pre-push width of 6 the concurrent `grep -r` sweeps push `log stream` past
  # 14k reports/s and the sandbox tracer drops reports, so the fixture is OMITTED; at width 1 it
  # traced clean. The width changes the SCHEDULE, not the work -- every id is still run and every
  # file still read -- so the read-set derived at width 1 is the read-set at width 6.
  # IT IS PASSED AS `env KNOB=1 bash`, INSIDE sudo and sandbox-exec, ON PURPOSE. An export, or a
  # `KNOB=1 sudo ...` / `KNOB=1 sandboxed ...` prefix, is stripped by sudo's env_reset under
  # `fs_usage` and `--tracer both`, and the fixture would silently run at 6. Placed after the
  # privilege drop, `env` sets it in the very process that runs the fixture, under every tracer.
  # The name carries no AI_DLC_ prefix as future-proofing: several fixtures scrub that prefix from
  # the environment they hand their subjects. No scrub sits on this path today.
  # EMS_POOL_WIDTH=1 rides the same `env`, for the same reason and with the same guarantee:
  # enforcement-map-sites reads it as its own pool width, so a traced run of it is narrowed too.
  # core/fixtures/readset-skip binds this line by running a copy of this deriver, for both knobs.
  # PREPUSH_POOL_DEPTH is RS_POOL_DEPTH, the caller's depth + 1; it is set at top level above sandboxed().
  if [ "$TRACER" = fs_usage ]; then
    ( cd "$TREE" && sudo -n -u "$RUN_AS" env PREPUSH_POOL_DEPTH="$RS_POOL_DEPTH" VAS_INNER_POOL_WIDTH=1 EMS_POOL_WIDTH=1 bash "$FIXTURE_ROOT/$fx/run.sh" ) >"$WORK/$fx.log" 2>&1 </dev/null
    rc=$?
  else
    ( cd "$TREE" && sandboxed env PREPUSH_POOL_DEPTH="$RS_POOL_DEPTH" VAS_INNER_POOL_WIDTH=1 EMS_POOL_WIDTH=1 bash "$FIXTURE_ROOT/$fx/run.sh" ) >"$WORK/$fx.log" 2>&1 </dev/null
    rc=$?
  fi

  flushed=1
  if [ "$TRACER" = fs_usage ]; then
    sleep 1
    # `$!` names the LAST element of the pipeline -- grep, not fs_usage. Killing only that
    # orphans the tracer, and orphans accumulate across a hundred fixtures until every later
    # trace drops events. That failure looks like a small read-set, not like a fault.
    # `-P $$` NAMES ONLY THIS RUN'S TRACER: the pipeline's left element is forked straight from this
    # top-level shell. Matching on the name alone killed every other run's tracer on the box, and a
    # killed tracer reads as a small read-set (BL-466). A pipeline moved inside `( ... ) &` would
    # parent its tracer to that subshell and escape `-P $$`.
    kill "$fs_pid" 2>/dev/null; wait "$fs_pid" 2>/dev/null
    pkill -P $$ -x fs_usage 2>/dev/null; sleep 0.5
  else
    # THE END SENTINEL IS THE FLUSH CONTROL. The stream delivers asynchronously, so the fixture
    # exiting says nothing about whether its last reports have arrived. Its own tail is read
    # through the profile until that read APPEARS, and everything before it in the stream is
    # the fixture's. No end sentinel, no trustworthy window: the fixture is omitted below.
    flushed=0; i=0
    while [ "$i" -lt 100 ]; do
      sandboxed cat "$ENDMARK" >/dev/null 2>&1 </dev/null
      if grep -q 'readset-end' "$raw" 2>/dev/null; then flushed=1; break; fi
      sleep 0.2; i=$(( i + 1 ))
    done
    kill "$fs_pid" 2>/dev/null; wait "$fs_pid" 2>/dev/null
    if [ -n "$fsu_pid" ]; then
      # Same reaping as the fs_usage mode: `$!` is grep, so the tracer itself is named too.
      sleep 1
      kill "$fsu_pid" 2>/dev/null; wait "$fsu_pid" 2>/dev/null
      pkill -P $$ -x fs_usage 2>/dev/null; sleep 0.5
    fi
  fi

  # atime moved off the forced epoch == the file was READ.
  #
  # THE SCAN RUNS BEFORE THE DIRTY CHECK BELOW, NEVER AFTER IT. `git status` reads `.git/index`,
  # `.gitignore`, `.git/info/exclude` and the refs -- in every fixture's window, because it is the
  # DERIVER running it. Taken after, the atime scan recorded that footprint as the fixture's own:
  # the `.git/**` and `.gitignore` rows present in all 218 mapped fixtures, including ones whose
  # run.sh never runs git. Nothing between the fixture's exit and this line reads the tree.
  find "$TREE" -type f -newerat "2001-01-02" -print 2>/dev/null \
    | sed "s|^$TREE/||" | norm > "$WORK/$fx.at"
  # The unread control's verdict, read off the same scan; its row never enters the read-set.
  unread_moved=0
  if grep -qxF "$UNREAD_CTL" "$WORK/$fx.at"; then
    unread_moved=1
    grep -vxF "$UNREAD_CTL" "$WORK/$fx.at" > "$WORK/$fx.at.tmp"; mv "$WORK/$fx.at.tmp" "$WORK/$fx.at"
  fi

  dirty="$( ( cd "$TREE" && git status --porcelain 2>/dev/null | wc -l ) | tr -d ' ')"

  # fs_usage, filtered by process and to events after the fixture actually started.
  # RdData/WrData are excluded: they are reads against an already-open fd, they carry no path
  # the open line did not already carry, and they are the ONLY lines fs_usage truncates --
  # and a truncated path maps to the wrong file or to none, which reads exactly like a clean
  # trace.
  last="$(grep -n 'readset-sentinel' "$raw" 2>/dev/null | tail -1 | cut -d: -f1)"; : "${last:=0}"
  lost=0
  if [ "$TRACER" = fs_usage ]; then
    tail -n "+$(( last + 1 ))" "$raw" 2>/dev/null \
      | grep -v 'RdData\|WrData' \
      | awk -v d="^($DAEMONS)(\\\\.[0-9]+)?$" '{ p=$NF; sub(/\.[0-9]+$/,"",p); if (p !~ d) print }' \
      | grep -oE "$TREE/[^ ]*" | sed "s|^$TREE/*||" | grep -v '^-\?$' | norm > "$WORK/$fx.fs"
  else
    # The window is strictly between the LAST start sentinel and the FIRST end sentinel.
    endl="$(grep -n 'readset-end' "$raw" 2>/dev/null | head -1 | cut -d: -f1)"; : "${endl:=0}"
    if [ "$endl" -gt "$last" ]; then
      sed -n "$(( last + 1 )),$(( endl - 1 ))p" "$raw" > "$WORK/$fx.win"
    else
      : > "$WORK/$fx.win"; flushed=0
    fi
    # EVENT LOSS OMITS THE FIXTURE; A SMALLER SET IS NEVER EMITTED. `log stream` prints
    # `=== Messages dropped during live streaming` when it cannot keep up, and the reports it
    # dropped are gone -- the set that remains is short by an unknown amount, which is the
    # silent-skip direction. Measured on this machine at load ~38: even the scoped profile drops
    # under a burst of a few hundred opens, and every burst that lost paths printed the notice.
    lost="$(grep -c 'dropped during' "$WORK/$fx.win" 2>/dev/null)" || lost=0
    sandbox_paths < "$WORK/$fx.win" | grep -v '^-\?$' | norm > "$WORK/$fx.fs"
  fi
  # THE LOSS CANARY: a file the fixture READ (its atime moved off the forced epoch) that the stream
  # never reported. Under every tracer whose $fx.fs IS the stream set -- `sandbox` and `both`. Under
  # `both` the fs_usage comparison cannot see a read BOTH tracers lost, so a canary there makes the
  # fixture UNCOMPARED rather than letting it count toward SANDBOX-MISSES-NOTHING. Under fs_usage
  # $fx.fs is not a stream set at all, so the canary does not run.
  # IT IS A CANARY, NOT A COMPLETENESS CONTROL, AND CLAIMS NO COMPLETENESS. atime sees only reads of
  # files that exist at the scan: a lost stat, a lost negative lookup, a lost exec of a file outside
  # the tree, and a lost report on a file deleted before the scan are all invisible to it. A zero
  # here says the stream lost no READ the atime leg could see -- never that the set is whole.
  # WHY IT EXISTS: the stream can lose reports WITHOUT printing a drop notice -- measured, a `cp -R`
  # recorded 946 of the 956 paths it read with zero notices -- so the drop-notice guard below cannot
  # be the only loss guard. Proven by core/fixtures/readset-skip: a deterministic stub-world arm (no
  # `log stream` needed) and a real unscoped burst of 8 concurrent readers over 1500 files.
  # FALSE-POSITIVE SET, MEASURED BEFORE SHIPPING, AND NO NARROWING WAS NEEDED: a 33-fixture --list
  # spread across the map, load 7.7-42, fired the canary on 1 fixture, which also carried 1863
  # drop notices, and on 0 of the 16 fixtures whose windows had 0 notices. The one firing seen
  # WITHOUT a notice was a synthetic single-reader burst over 1500 files: 3 of its 4 canary paths
  # appear nowhere in the raw stream and the 4th matches only as a prefix of other names, so that
  # was a real silent loss and not a false positive. No path class is exempted.
  # The comparison is readset_loss_canary, between sentinels above, so readset-skip drives it.
  canary=0
  if [ "$TRACER" != fs_usage ]; then
    canary="$(readset_loss_canary "$WORK/$fx.at" "$WORK/$fx.fs" "$WORK/$fx.canary")"
  fi
  # Under `both`, the fs_usage capture is extracted exactly as the fs_usage mode extracts it, from
  # its OWN last sentinel line, into $fx.fsu. $fx.fs above is then the sandbox set.
  : > "$WORK/$fx.fsu"
  if [ "$TRACER" = both ]; then
    flast="$(grep -n 'readset-sentinel' "$raw.fsu" 2>/dev/null | tail -1 | cut -d: -f1)"; : "${flast:=0}"
    tail -n "+$(( flast + 1 ))" "$raw.fsu" 2>/dev/null \
      | grep -v 'RdData\|WrData' \
      | awk -v d="^($DAEMONS)(\\\\.[0-9]+)?$" '{ p=$NF; sub(/\.[0-9]+$/,"",p); if (p !~ d) print }' \
      | grep -oE "$TREE/[^ ]*" | sed "s|^$TREE/*||" | grep -v '^-\?$' | norm > "$WORK/$fx.fsu"
  fi

  cat "$WORK/$fx.at" "$WORK/$fx.fs" "$WORK/$fx.fsu" | LC_ALL=C sort -u \
    | grep -v '^\.readset-sentinel$' | grep -v '^\.readset-end$' | readset_drop_pseudo | drop_ignored > "$WORK/$fx.set"
  n="$(grep -c . "$WORK/$fx.set" 2>/dev/null)"; case "$n" in ''|*[!0-9]*) n=0 ;; esac

  # FAIL CLOSED. Anything that makes this trace untrustworthy omits the fixture from the map,
  # and the runner always runs a fixture it has no entry for.
  why=""
  [ "$rc" -eq 0 ]     || why="fixture exited $rc"
  [ "$settled" -eq 1 ] || why="${why:+$why; }tracing never settled"
  [ "$flushed" -eq 1 ] || why="${why:+$why; }no end sentinel in the stream -- the tail of the window is unknown"
  [ "$lost" -eq 0 ]    || why="${why:+$why; }the stream dropped reports $lost time(s) in this window"
  [ "$canary" = 0 ]    || why="${why:+$why; }LOSS CANARY: $canary path(s) the fixture read (atime) are absent from the stream -- see $WORK/$fx.canary"
  [ "$unread_moved" -eq 0 ] || why="${why:+$why; }UNREAD CONTROL: $UNREAD_CTL left the 2001 atime epoch -- the reset did not hold or something walked the tree"
  [ "$n" -gt 0 ]      || why="${why:+$why; }empty read-set"
  [ "$dirty" -le "$DIRTY_BASE" ] || why="${why:+$why; }fixture wrote $(( dirty - DIRTY_BASE )) path(s) into the tree"
  # `--local-map` ADDS THREE CONDITIONS, because nobody reads this run's output: the hook starts it
  # detached and only the rows it writes are ever consumed.
  #   TRIP     the window reports an exec from the refused set (the profile's `;TRIP` tag);
  #   DRIVER   the set does not name the fixture's own run.sh, so the window lost its first open;
  #   VERDICT  the multiset of the trace's verdict lines differs from the normal run's, read from
  #            `<local map>.logs/<fx>` where the hook stashed it -- a missing log is a discard too.
  if [ -n "$LOCAL_MAP" ]; then
    trip="$(grep -c "FXTAG=$fx;TRIP" "$WORK/$fx.win" 2>/dev/null)" || trip=0
    [ "$trip" -eq 0 ] || why="${why:+$why; }TRIP: $trip exec(s) of a refused binary (setuid/setgid, log, sandbox-exec)"
    grep -qxF "$FIXTURE_ROOT/$fx/run.sh" "$WORK/$fx.set" || why="${why:+$why; }the set does not name its own $FIXTURE_ROOT/$fx/run.sh"
    if [ ! -r "$LOCAL_MAP.logs/$fx" ]; then
      why="${why:+$why; }VERDICT: no normal-run log at $LOCAL_MAP.logs/$fx to compare against"
    elif [ "$(readset_verdict_sig "$WORK/$fx.log" "$TREE" "$REPO_ROOT")" != "$(readset_verdict_sig "$LOCAL_MAP.logs/$fx" "$TREE" "$REPO_ROOT")" ]; then
      why="${why:+$why; }VERDICT: the sandboxed run's verdict lines differ from the normal run's"
    fi
  fi

  if [ "$TRACER" = both ]; then
    # EITHER SET EMPTY IS ITS OWN REASON. An empty sandbox set is what a root `log stream` that
    # cannot see the `sudo -u` child's reports would produce, and compared against it fs_usage
    # would show every path as a sandbox miss -- or, the other way round, nothing to compare.
    [ -s "$WORK/$fx.fsu" ] || why="${why:+$why; }fs_usage set empty"
    [ -s "$WORK/$fx.fs" ]  || why="${why:+$why; }sandbox set empty"
    if [ -z "$why" ]; then
      counts="$(readset_both_compare "$WORK/$fx.fsu" "$WORK/$fx.fs" "$WORK/$fx.cmp")" \
        || { counts=""; why="the comparison could not read its two sets"; }
    fi
    if [ -n "$why" ]; then
      printf '%s\tuncompared\t-\t-\t%s\n' "$fx" "$why" >> "$WORK/both.results"
      printf '  %-32s UNCOMPARED (%s)\n' "$fx" "$why"
    else
      sbm="${counts%% *}"; fsm="${counts##* }"
      printf '%s\tcompared\t%s\t%s\t\n' "$fx" "$sbm" "$fsm" >> "$WORK/both.results"
      awk -v f="$fx" '{ print f "\t" $0 }' "$WORK/$fx.cmp.sbmiss" >> "$WORK/both.missed"
      printf '  %-32s sandbox-missed %5s   fs_usage-missed %5s\n' "$fx" "$sbm" "$fsm"
    fi
  fi

  if [ -n "$why" ]; then
    OMITTED="${OMITTED}${OMITTED:+ }$fx"
    [ "$TRACER" = both ] || printf '  %-32s OMITTED (%s) -- will always run\n' "$fx" "$why"
    if [ -n "$LOCAL_MAP" ]; then
      dk="$( (shasum -a 256 -- "$TREE/$FIXTURE_ROOT/$fx/run.sh" 2>/dev/null || echo -) | cut -d' ' -f1):$DERIVER_SHA"
      printf '%s\t%s\t%s\n' "$fx" "$dk" "$(printf '%s' "$why" | tr '\t\n' '  ')" >> "$WORK/local.discards"
    fi
  else
    awk -v f="$fx" '{ print f "\t" $0 }' "$WORK/$fx.set" >> "$WORK/map"
    MAPPED=$(( MAPPED + 1 )); TOTAL_PATHS=$(( TOTAL_PATHS + n ))
    [ "$TRACER" = both ] || printf '  %-32s %5s paths\n' "$fx" "$n"
    if [ -n "$LOCAL_MAP" ]; then
      readset_hash_rows "$TREE" "$fx" "$WORK/$fx.set" >> "$WORK/local.ok" \
        || { echo "  could not hash $fx's set in the trace copy -- not recorded" >&2; }
    elif [ "$TRACER" != both ]; then
      # The digest's input, hashed in the trace copy now; the final write turns it into a `# digest` line.
      if readset_hash_rows "$TREE" "$fx" "$WORK/$fx.set" > "$WORK/$fx.dig"; then
        cat "$WORK/$fx.dig" >> "$WORK/digest.rows"
      else
        echo "  could not hash $fx's set in the trace copy -- no # digest line for it" >&2
      fi
    fi
    if [ -z "$LOCAL_MAP" ] && [ "$TRACER" != both ]; then
      ( LIST="$DONE"; readset_write_map ) > "$WORK/$fx.write" 2>&1 \
        || say "  per-fixture map write refused after $fx (the previous map stands): $(tail -1 "$WORK/$fx.write")"
    fi
  fi
  # `--local-map` writes its file after EVERY fixture, kept or discarded, for the same reason.
  if [ -n "$LOCAL_MAP" ]; then
    readset_local_present > "$WORK/local.present"
    readset_local_write "$LOCAL_MAP" "$MAP" "$WORK/local.ok" "$WORK/local.discards" "$fx" "$DERIVER_SHA" "$WORK/local.present" \
      || die "could not write $LOCAL_MAP after tracing $fx -- that fixture's rows are unchanged"
  fi
done

# `--local-map` ENDS HERE. It never reaches the controls or the committed map's write: those judge
# a full map, and a one-fixture local trace would fail the plan-shape pair and the discrimination
# control by construction. Its own conditions were applied, and its file written, per fixture above.
if [ -n "$LOCAL_MAP" ]; then
  say "wrote $LOCAL_MAP -- $MAPPED of $N_SUBJECT traced fixture(s) recorded${OMITTED:+; discarded: $OMITTED}"
  exit 0
fi

# `--tracer both` ENDS HERE, AT ITS VERDICT, AND NEVER REACHES THE WRITE BELOW. The loop above still
# built $WORK/map exactly as the other modes do, so this exit is the ONLY thing between a
# comparison run and a rewritten map -- core/fixtures/readset-skip deletes it in a copy and asserts
# the map's md5 then moves, which is how this guard is known to be the one that holds.
if [ "$TRACER" = both ]; then
  BOTH_LINE="$(readset_both_verdict "$LIST" "$WORK/both.results" "$WORK/both.missed" "$WORK")"
  BOTH_RC=$?
  echo "$BOTH_LINE"
  say "the map was NOT written (--tracer both compares tracers; it never derives)"
  exit "$BOTH_RC"
fi

# THE FINAL WRITE: the same function every accepted fixture called above, over the whole LIST and
# NOT in a subshell, so its `die` ends the run exactly as the end-only write did. RS_FINAL attaches the
# `# digest` lines, which only this write computes.
RS_FINAL=1
readset_write_map

say "wrote $MAP -- $M_FIX fixtures, $M_ENT entries, $M_PATH distinct paths (this run traced $MAPPED)"
[ -n "$OMITTED" ] && say "OMITTED and therefore always run: $OMITTED"
exit 0
