#!/usr/bin/env bash
# migrate-artifact-paths.sh — move a consumer's artifacts onto the declared path grammar.
#
#   migrate-artifact-paths.sh [--root <dir>] [--grammar <file>]            # DRY RUN. Writes nothing.
#   migrate-artifact-paths.sh [--root <dir>] [--grammar <file>] --apply    # staged renames + verification.
#
# WHAT IT DOES. `artifact-path-grammar.md` makes the DIRECTORY the only sprint slot, immediately
# under the area root:
#
#     <area>/s<N>/[<subdir>/...]<basename>
#
# so this rewrites every tracked path under the scan roots that carries a sprint token anywhere
# OUTSIDE that slot -- in the basename, or in any intermediate directory.
#
# IT OPERATES ON THE WHOLE PATH, NOT THE BASENAME, and the first draft did not. Against the
# reference consumer a basename-only transform produced destinations like
# `implementation-artifacts/sprint-287/smoke-evidence/s287/foo.md` and
# `planning-artifacts/archive/s300-cycle-1/s300/bar.md` -- the reserved slot nested inside the
# non-conforming directory it was meant to replace, on 53 destination directories. The sprint is
# ONE fact about a file: every component is stripped and the slot is inserted once, under the area.
#
# STAGED RENAMES ONLY, NEVER A DELETE, and never a rewrite of any file's CONTENT. Each file is
# moved with `mv`, and its batch is staged by one `git update-index --index-info` that carries
# each source's EXISTING index entry (mode and blob) to the destination -- nothing is re-hashed
# through a filter -- which is the index a `git mv` per file leaves. Breaking historical
# traceability is accepted by operator directive --
# the declared convention is the guide to where to look, and a link-rewriting pass over 2000+
# files is a second, unverifiable migration riding on this one.
#
# VERIFICATION IS PER FILE AND IS NOT A COUNT. Each move is confirmed as
#   source ABSENT  AND  destination READABLE  AND  sha256 IDENTICAL to the pre-move source
# and any file failing any leg aborts the run. A count of moved files cannot see whether the
# RIGHT bytes arrived, which is the whole failure mode a migration has.
#
# EVERY FILE IT WILL NOT MOVE IS REPORTED, WITH THE REASON. A migration that silently covers most
# of a tree is worse than none: the operator reads "done" and the remainder is found by whatever
# breaks next.
#
# Exit codes:
#   0  -- dry run completed, or --apply completed with every move verified
#   1  -- a move failed, or a post-move verification failed (aborts at the first one)
#   2  -- usage error, unreadable grammar file, or a tree this cannot safely operate on
#   3  -- nothing to migrate. Distinct from 0 so "no work" is never reported in the same
#         breath as "work done and verified".
#
# PROGRESS goes to STDERR, so stdout stays the report it always was. The plan phase prints
#   migrate-artifact-paths.sh: PROGRESS plan: <total> tracked file(s) to scan
#   migrate-artifact-paths.sh: PROGRESS plan: scanned <i> of <total>
# and --apply's move loop prints
#   migrate-artifact-paths.sh: PROGRESS apply: <N> move(s) to apply
#   migrate-artifact-paths.sh: PROGRESS apply: moved <i> of <N>
# every AI_DLC_MIGRATE_PROGRESS_EVERY files (default 1000; a positive integer, anything else is
# exit 2). A phase with fewer files than that prints nothing at all.
set -uo pipefail

PROG="migrate-artifact-paths.sh"
ROOT="."
APPLY=0
GRAMMAR_ARG=""

while [ $# -gt 0 ]; do
  case "$1" in
    --apply) APPLY=1; shift ;;
    --root)  ROOT="${2:-}"; [ -n "$ROOT" ] || { echo "$PROG: --root needs a directory" >&2; exit 2; }; shift 2 ;;
    # For REHEARSING the migration before the pull that installs the grammar, and for the
    # fixture. The normal path resolves the consumer's own installed copy.
    --grammar) GRAMMAR_ARG="${2:-}"; [ -n "$GRAMMAR_ARG" ] || { echo "$PROG: --grammar needs a file" >&2; exit 2; }; shift 2 ;;
    -h|--help) sed -n '2,/^set -uo pipefail$/p' "$0" | sed -e '$d' -e 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "$PROG: unknown option '$1'" >&2
       echo "usage: $PROG [--root <dir>] [--grammar <file>] [--apply]" >&2
       exit 2 ;;
  esac
done

# The PROGRESS cadence (see the header). Validated before any work, because a value that cannot
# be a count would otherwise surface as an arithmetic error in the middle of the plan loop. More
# than 18 digits is past what shell arithmetic holds, and means "never": no file count reaches it.
_PG_EVERY=1000
if [ -n "${AI_DLC_MIGRATE_PROGRESS_EVERY+set}" ]; then
  _PG_RE='^[1-9][0-9]*$'
  if ! [[ $AI_DLC_MIGRATE_PROGRESS_EVERY =~ $_PG_RE ]]; then
    echo "$PROG: AI_DLC_MIGRATE_PROGRESS_EVERY must be a positive integer, got '$AI_DLC_MIGRATE_PROGRESS_EVERY'" >&2
    exit 2
  fi
  if [ "${#AI_DLC_MIGRATE_PROGRESS_EVERY}" -le 18 ]; then _PG_EVERY="$AI_DLC_MIGRATE_PROGRESS_EVERY"
  else _PG_EVERY=999999999999999999; fi
fi

# RESOLVE --grammar BEFORE the cd. It is the operator's path, relative to where they are
# standing, and this script then changes directory into the consumer -- so a relative value would
# be re-resolved against a tree it does not live in and report "no readable file" for a file that
# is plainly there.
if [ -n "$GRAMMAR_ARG" ]; then
  case "$GRAMMAR_ARG" in /*) : ;; *) GRAMMAR_ARG="$(pwd)/$GRAMMAR_ARG" ;; esac
fi

# AND RESOLVE THIS SCRIPT'S OWN DIRECTORY BEFORE THE cd, FOR THE SAME REASON ONE LINE UP.
# `${BASH_SOURCE[0]}` is `core/scripts/migrate-artifact-paths.sh` when it is invoked relatively,
# and re-resolving that after the cd looks for `core/scripts/` INSIDE the consumer -- which is
# not a place it has any reason to be. Measured: the absolute invocation the fixture uses worked
# and the relative one every operator types died at `cd: core/scripts: No such file or directory`.
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$SELF_DIR/artifact-path-config.sh"
[ -f "$CONFIG" ] || { echo "$PROG: no artifact-path-config.sh beside this script at '$CONFIG'." >&2
                      echo "  It is the single home of the scan roots, the areas and the sprint-token" >&2
                      echo "  expression. Guessing them would move files the grammar never governed." >&2
                      exit 2; }

[ -d "$ROOT" ] || { echo "$PROG: not a directory: $ROOT" >&2; exit 2; }
cd "$ROOT" || exit 2
ROOT_ABS="$(pwd)"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || { echo "$PROG: $ROOT_ABS is not a git work tree. This moves files with \`git mv\` so that a" >&2
       echo "  bad run is recoverable with \`git checkout\`; without git there is no undo." >&2; exit 2; }

# --- the scan roots and the areas come from the grammar, not from here -------
#
# RESOLVED BY artifact-path-config.sh, WHICH IS THE ONLY PLACE THAT READS THE GRAMMAR'S BLOCKS.
# This script used to carry its own copy of that extraction, byte-identical to the one in
# validate-enforcement-map.sh's I82 -- which is what a fork looks like the day before it stops
# being one. The conformance validator would have been the third copy. There is now one, and the
# consumer-area join, the contract lookup and the sprint-token expression live there with it.
#
# WHAT THE JOIN IS FOR, kept here because it is this script's report that acts on it: core
# prescribes the grammar and the CONSUMER declares its own areas, so declaring one is the act
# that stops it being inferred. That is only true because the declaration is READ. On the
# reference consumer the file was byte-identical to the scaffolded template and nothing consulted
# it, so the remedy this report prints would have changed no later verdict -- a corrected sentence
# in front of an inert mechanism reads as done, which is worse than the wrong sentence.
# `--root "$ROOT_ABS"` IS SAID, NOT INHERITED, for the reason validate-artifact-paths.sh states
# beside its own copy: the resolver no longer defaults to the cwd, so the tree this run is about
# has to be named by the program that knows it rather than left to whichever root the resolver
# would find from its own install path.
cfg() { # <mode> -> the resolver's answer, or die carrying its own message
  local out rc
  if [ -n "$GRAMMAR_ARG" ]; then out="$(bash "$CONFIG" "$1" --root "$ROOT_ABS" --grammar "$GRAMMAR_ARG" 2>&1)"; rc=$?
  else                           out="$(bash "$CONFIG" "$1" --root "$ROOT_ABS" 2>&1)"; rc=$?; fi
  if [ "$rc" -ne 0 ]; then
    echo "$PROG: artifact-path-config.sh $1 failed (rc=$rc):" >&2
    printf '%s\n' "$out" >&2
    exit 2
  fi
  printf '%s\n' "$out"
}

GRAMMAR="$(cfg --grammar-file)"
SCAN_ROOTS="$(cfg --scan-roots)"
DECLARED_AREAS="$(cfg --areas)"

# Where the report sends the operator. The contract's declared path even when the file does not
# exist yet, because "go write this file" is the correct remedy then; only a missing CONTRACT
# leaves it unnamed, and that is a broken install, not a paperwork gap.
REMEDY_FILE="$(bash "$CONFIG" --consumer-file --root "$ROOT_ABS" 2>/dev/null || true)"

if [ "$APPLY" -eq 1 ] && [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  echo "$PROG: the work tree is DIRTY. Commit or stash first." >&2
  echo "  --apply performs hundreds of \`git mv\`s and aborts at the first verification failure;" >&2
  echo "  a clean tree is what makes \`git checkout -- .\` a complete undo of a partial run." >&2
  exit 2
fi

# --- the transform ------------------------------------------------------------
# `_bmad-output/` ROOT IS NOT AN AREA, declared rather than discovered. It holds live singletons
# -- pipeline-snapshot.md, the flow log, the pause flag -- whose whole point is that there is
# exactly one, so it cannot grow an `s<N>/`. What it does hold with a sprint token is ROTATION
# ARCHIVES of those logs, and the grammar puts every rotation archive under
# implementation-artifacts/s<N>/.
ARCHIVE_HOME="_bmad-output/implementation-artifacts"

# The sprint-token expression, from the same resolver, for the same reason: the validator that
# blocks a push on it and the migration that clears the block must not be able to disagree about
# what a sprint token is.
TOKEN_RE="$(cfg --token-re)"

# ONE REGEX, APPLIED PER COMPONENT, ONE TOKEN AT A TIME, TO A FIXED POINT. Three properties,
# and the drafts that lacked each of them are the reason all three are spelled out here.
#
# PER COMPONENT: matching TOKEN_RE against a whole path silently misses every token a `/`
# precedes -- `docs/retro/sprint-299.md`, `docs/reviews/s283-foo.md` -- because the boundary
# alternation is `^` or `-`, and a path separator is neither. Measured: 668 files detected
# instead of 2551, with `docs/retro` absent from the plan ENTIRELY. Widening the regex to accept
# `/` would leave two definitions of a sprint token to keep in sync; splitting the path and
# reusing the component regex leaves one.
#
# ONE AT A TIME, TO A FIXED POINT: both `grep -o` and `sed ...g` CONSUME the separator that
# would begin the next token, so two ADJACENT tokens read as one.
#   `gate-log-archive-s291-s292.md`      -> the `-` before s292 is eaten by the `-s291-` match,
#                                           so only 291 is seen. The file names TWO sprints and
#                                           was planned as if it named one.
#   `sprint-239-S239-1-code-review.md`   -> `^sprint-239-` eats the `-`, `S239-` never matches,
#                                           and the destination KEEPS a sprint token.
# Measured: 21 destinations still carrying a token, and -- worse -- files whose sprint is
# genuinely ambiguous reported as unambiguous and queued for a move. Stripping one occurrence
# and re-scanning from the start makes the next token visible again.
#
# NO PROCESS PER PATH. Both helpers run once per tracked file under the scan roots -- tokenless and
# already-conforming files included -- so a fork per component was a fork count in the hundreds of
# thousands on the reference consumer, and minutes of silence. They are pure bash, and each hands
# its answer back in ONE global that nothing else reads or writes (`_STRIP_TOKEN_OUT`,
# `_SPRINTS_IN_OUT`), so the caller needs no `$( )` subshell either.
#
# THE MATCH POSITION IS CONSTRUCTED, NOT SEARCHED FOR. `BASH_REMATCH` gives the matched text and no
# offset, and the first LITERAL occurrence of that text can sit left of the leftmost regex match:
# in `x-s123x-s12` the regex matches the trailing `-s12` through `$`, while the text `-s12` first
# occurs at offset 1. A match whose terminator group is EMPTY ended at `$`, so it is a suffix and
# is cut from the right. Otherwise it ends in a literal `-` or `.`, and any earlier occurrence of
# that text would itself be an earlier match -- so the first occurrence is the match.
#
# DETECTION IS TOKEN_RE AND STRIPPING IS THE LITERAL BELOW, kept as two expressions exactly as the
# two `sed`/`grep` calls this replaced kept them: TOKEN_RE comes from the config, and merging the
# two would change behaviour wherever they could ever differ.
_STRIP_RE='(^|-)(s|S|sprint-)[0-9]+(-|$|\.)'
_DIGITS_RE='[0-9]+'
strip_token() { # <component> -> _STRIP_TOKEN_OUT: the component with EVERY sprint token removed, separators tidied
  local _st_cur="$1" _st_m="" _st_pre=""
  _STRIP_TOKEN_OUT=""
  while [[ $_st_cur =~ $_STRIP_RE ]]; do
    _st_m="${BASH_REMATCH[0]}"
    if [ -z "${BASH_REMATCH[3]}" ]; then _st_pre="${_st_cur%"$_st_m"}"
    else _st_pre="${_st_cur%%"$_st_m"*}"; fi
    _st_cur="${_st_pre}${BASH_REMATCH[1]}${BASH_REMATCH[3]}${_st_cur:$((${#_st_pre} + ${#_st_m}))}"
  done
  # The tidy, as `s/--+/-/g; s/^-+//; s/-+(\.|$)/\1/`. After the first two no run of dashes is
  # left, so the third removes ONE dash: before the first `.` that follows one, else a trailing one
  # (a `-.` always sits left of a trailing dash, so it is the leftmost match whenever it exists).
  while [[ $_st_cur == *--* ]]; do _st_cur="${_st_cur//--/-}"; done
  _st_cur="${_st_cur#-}"
  if [[ $_st_cur == *-.* ]]; then
    _st_pre="${_st_cur%%-.*}"
    _st_cur="${_st_pre}${_st_cur:$((${#_st_pre} + 1))}"
  else
    _st_cur="${_st_cur%-}"
  fi
  _STRIP_TOKEN_OUT="$_st_cur"
}

sprints_in() { # <path> -> _SPRINTS_IN_OUT: the DISTINCT sprint numbers its components name, one per line, in `sort -u` order
  local _si_p="$1" _si_more=1 _si_c="" _si_cur="" _si_m="" _si_d="" _si_n="" _si_got=0
  local _si_list="" _si_rest="" _si_new="" _si_x="" _si_placed=0 _si_nl=$'\n'
  _SPRINTS_IN_OUT=""
  while [ "$_si_more" -eq 1 ]; do
    case "$_si_p" in
      */*) _si_c="${_si_p%%/*}"; _si_p="${_si_p#*/}" ;;
      *)   _si_c="$_si_p"; _si_more=0 ;;
    esac
    _si_cur="$_si_c"
    while [[ $_si_cur =~ $TOKEN_RE ]]; do
      # Every digit run in the token match, as `grep -oE '[0-9]+'` printed them. The leftmost run
      # starts at the first digit, so its first literal occurrence is the run itself.
      _si_d="${BASH_REMATCH[0]}"; _si_got=0
      while [[ $_si_d =~ $_DIGITS_RE ]]; do
        _si_n="${BASH_REMATCH[0]}"; _si_d="${_si_d#*"$_si_n"}"; _si_got=1
        # Insert into the sorted, distinct list: `sort -u` order, which is lexical (`10` before `9`).
        _si_rest="$_si_list"; _si_new=""; _si_placed=0
        while [ -n "$_si_rest" ]; do
          _si_x="${_si_rest%%"$_si_nl"*}"; _si_rest="${_si_rest#*"$_si_nl"}"
          if [ "$_si_placed" -eq 0 ]; then
            if [ "$_si_x" = "$_si_n" ]; then _si_placed=1
            elif [[ $_si_n < $_si_x ]]; then _si_new="${_si_new}${_si_n}${_si_nl}"; _si_placed=1; fi
          fi
          _si_new="${_si_new}${_si_x}${_si_nl}"
        done
        [ "$_si_placed" -eq 1 ] || _si_new="${_si_new}${_si_n}${_si_nl}"
        _si_list="$_si_new"
      done
      [ "$_si_got" -eq 1 ] || break
      # Strip ONE token and re-scan, so an adjacent token becomes visible (see above).
      [[ $_si_cur =~ $_STRIP_RE ]] || break
      _si_m="${BASH_REMATCH[0]}"
      if [ -z "${BASH_REMATCH[3]}" ]; then _si_x="${_si_cur%"$_si_m"}"
      else _si_x="${_si_cur%%"$_si_m"*}"; fi
      _si_cur="${_si_x}${BASH_REMATCH[1]}${BASH_REMATCH[3]}${_si_cur:$((${#_si_x} + ${#_si_m}))}"
    done
  done
  _SPRINTS_IN_OUT="${_si_list%"$_si_nl"}"
}

# A component that strips to nothing, or to a bare extension, has no name left. That is NOT a
# refusal: the component WAS the sprint, and the sprint has moved into the slot. A directory like
# `sprint-287/` is dropped; a nameless BASENAME takes the name of whatever contained it, which is
# what lands `docs/retro/sprint-299.md` on `docs/retro/s299/retro.md` -- the grammar's own declared
# destination -- and `planning-artifacts/sprint-status/sprint-187.yaml` on
# `planning-artifacts/s187/sprint-status.yaml`, with no lookup table here.
is_nameless() { # <stripped-component> -> 0 when nothing but an extension survives
  case "$1" in
    '') return 0 ;;
    .*) case "${1#.}" in *[!A-Za-z0-9]*) return 1 ;; *) return 0 ;; esac ;;
    *)  return 1 ;;
  esac
}

# --- the story corpus, and the licence for reading a bare number as a sprint ---
#
# THE AMBIGUITY THAT DEFERRED THIS DIRECTORY FOR A RELEASE IS A NAME AMBIGUITY, AND THE NAME WAS
# NEVER WHERE THE ANSWER WAS. `story-297-1-slug.md` reads equally as sprint 297 story 1 and as
# story INDEX 297 with slug `1-slug` -- the form the grammar itself prescribes -- and no
# expression over that string can separate the two. POSITION separates them: the grammar places
# `stories/` only under `s<N>/`, so a `stories/` directory with no `s<N>/` component above it
# cannot hold a conforming file whatever the file is called. Everything in such a directory
# predates the grammar, by construction.
#
# POSITION SAYS THE FILE IS LEGACY; IT DOES NOT SAY `A` IS THE SPRINT. The licence first shipped on
# the observation that all 786 `story-<A>-<B>` basenames on the reference consumer have `A` inside
# the sprint range the tree uses (7..302). A carry-over ITEM number falls in that same range, so the
# observation could not separate the two readings it was offered for. The discriminating measurement
# is each file's own `**Sprint:**` header, over the same 786 at the pre-migration ref: 319 agree
# with `A`, 146 name a DIFFERENT sprint (every one lower than `A`, none with `A` >= 199), 6 carry an
# unreadable value (`50A`) and 315 carry none. So the name is read only where the header is silent
# or unreadable, and the loop below lets a readable header overrule it.
legacy_story() { # <path> -> 0 when it sits in a stories/ dir carrying no `s<N>/` slot above it
  case "$1" in */stories/*) ;; *) return 1 ;; esac
  local head="${1%/stories/*}" c oldIFS parts
  oldIFS="$IFS"; IFS='/'; set -f; parts=($head); set +f; IFS="$oldIFS"
  for c in "${parts[@]}"; do
    case "$c" in
      s[0-9]*) case "${c#s}" in *[!0-9]*) ;; *) return 1 ;; esac ;;
    esac
  done
  return 0
}

# NORMALISE, THEN REUSE. A legacy story basename spelling the sprint as a bare leading number is
# rewritten to the explicit `s<N>` spelling BEFORE the general transform sees it, so the sprint
# scan, the token strip, the collision check and the destination composition are all the SAME code
# that handles every other artifact. A second transform for this one directory is a second place
# for the destination rule to drift, and the drift would be invisible: both would still produce a
# path under `s<N>/`.
#
# BOTH numbers must be numeric. `story-131b-1-…` and `story-168-process-A.md` are refused rather
# than resolved, and a basename that is ALREADY `story-<M>-<slug>` (one number, then a word) is
# left alone rather than having its index read as a sprint.
#
# FORK-FREE, like the scan helpers above: the answer comes back in `_STORY_NORMALIZE_OUT`, never
# through `$( )`. The substitution this replaced (`^story-<A>-<B>` -> `story-s<A>-<B>`) only ever
# inserts an `s` after the `story-` its own anchor matched, so a match is that insertion exactly.
_STORY_NUM_NUM_RE='^story-[0-9]+-[0-9]+'
story_normalize() { # <path> -> _STORY_NORMALIZE_OUT: the path with a bare leading sprint number spelt `s<N>`
  local _sn_b="${1##*/}" nb=""
  _STORY_NORMALIZE_OUT="$1"
  [[ $_sn_b =~ $_STORY_NUM_NUM_RE ]] || return 0
  nb="story-s${_sn_b#story-}"
  [ "$nb" = "$_sn_b" ] || _STORY_NORMALIZE_OUT="${1%/*}/$nb"
}

# --- RECOVERING A SPRINT BEFORE REFUSING --------------------------------------
#
# THE REFUSAL USED TO PRESCRIBE A RENAME AS THE ONLY REMEDY, AND GROUND TRUTH SAYS THAT IS FALSE.
# On the reference consumer all 23 files this class refused were subsequently placed into slots by
# the operator, and `git show --numstat -M` on that commit scores every one of the 23 as a PURE
# DIRECTORY MOVE -- 0 insertions, 0 deletions, basename unchanged. Nobody renamed anything. The
# sprint was recoverable from the file the whole time and this script was the only thing that
# could not read it. Control on that measurement, in the same commit: 36 rows carry non-zero
# insertions and 72 rows DO rename a basename, so the parser that scored 23/23 can see both of
# the states it reported absent.
#
# TWO CHANNELS, HEADER FIRST, AND THE ORDER IS THE WHOLE MECHANISM. Scored against that commit as
# the oracle: the header alone is 6 correct / 0 wrong / 17 silent, the basename alone is 15 / 3 / 5,
# header-then-basename is 18 / 0 / 5, and basename-then-header is 17 / 3 / 3. The basename is the
# wider channel AND the wrong one to ask first: `bug-124-...` and `bug-125-...` open with a
# CARRY-OVER ITEM number, and their own headers say sprint 72 and 73. Asking the name first files
# both under a sprint that does not own them, silently. The file's own declaration outranks its
# name wherever both speak.
#
# NO GIT-HISTORY CHANNEL, AND THAT IS THE BOUND ON `--follow`. A history channel is the obvious
# third reading and it is refused here on measurement: at the pre-migration ref -- the state this
# script actually runs against -- `git log --follow` and `git log` return the SAME oldest commit
# for all 23, so following buys nothing where it would be used. Run against a tree where a
# migration has ALREADY moved the file, `--follow` crosses that rename and answers about the
# file's previous home: on the reference consumer it returns a "Sprint 71" commit for a story
# sitting in `s121/`, because an earlier migration moved it there. A recovery reading history
# inherits every prior migration's placement as though it were evidence. Both channels below read
# only the file's own bytes and its own name, neither of which a `git mv` alters.
#
# WHAT THIS BOUND CANNOT CATCH: a header that is itself wrong. If a story was authored by copying
# another sprint's file and its `**Sprint:**` line was never updated, the recovery believes it and
# places the file under the stale number. Nothing in the tree can separate that from a correct
# header -- the header IS the operator's declaration of ownership -- which is why every recovery
# is REPORTED with the channel that produced it rather than applied silently.
#
# A SUFFIXED SPRINT IS REFUSED, NOT ROUNDED. `story-131b-1-hr12-retirement.md` yields `131b`, and
# the reserved slot is `^s[0-9]+$` -- there is no legal slot spelling for it. Truncating to `s131`
# merges a distinct sprint's artifacts into another sprint's slot on a guess, so both channels
# require the sprint to be purely numeric and this file is refused and named. `story_normalize`
# above already refuses the same basename for the same reason; a recovery that accepted it would
# contradict its own sibling three functions up. That trades the one WRONG placement for a
# refusal: 18 correct / 0 wrong / 5 refused, against 18 / 1 / 4 for a recovery that takes it.
# A HEADER THAT SPOKE AND COULD NOT BE READ IS A REFUSAL, NEVER A FALL-THROUGH. This is the
# structural half and it matters more than the grammar half below. Without a distinct
# "spoke but unparseable" state, `**Sprint:** TBD` is indistinguishable from a file with no header
# at all, so the basename channel answers -- and for the carry-over shapes the basename is the ITEM
# number, which is the exact mis-filing the header channel exists to prevent. Measured on the
# shipping migrator, one file, two runs differing only in the header line:
#
#     **Sprint:** S270   ->  s124/stories/bug-124-deployed-range.md   (basename, WRONG)
#     **Sprint:** 270    ->  s270/stories/bug-124-deployed-range.md   (header, control)
#
# `s124` is the carry-over item. That is worse than the pre-recovery state, which refused outright,
# and `53-54`, `TBD` and the template's `[sprint ID/name]` all reach it the same way.
#
# So the header is read in TWO steps: does a `**Sprint:**` line exist at all, and does its value
# parse. `sprint_header_present` owns the first question, and the caller refuses when it says yes
# and the value comes back empty.
#
# BOTH QUESTIONS READ THE SAME FORTY LINES, FORK-FREE. `_sprint_header_scan` reads them with a
# bounded `read` loop where a `head -40` used to run: a final line with no newline still counts,
# CR bytes stay in the line, and an unopenable file reads as an empty one (the `head` form's
# `|| body=""`). The value is the capture of the FIRST line matching the value grammar, which is
# what `${first%%$'\n'*}` took from the `sed -n ... p` output this replaced -- with one difference:
# under a UTF-8 locale that `sed` died on a line holding invalid UTF-8 (`illegal byte sequence`)
# and gave no value, so the file was refused; this reader reads the declaration on such a line.
_HDR_DECL_RE='^\*\*Sprint:?\*\*'
_HDR_VALUE_RE='^\*\*Sprint:?\*\*[[:blank:]]*[Ss]?([0-9]+)([[:blank:]].*)?$'
#
# NUL BYTES ARE WHY THIS READS NUL-DELIMITED CHUNKS AND SPLITS THE LINES ITSELF. `$(head -40 ...)`
# DROPPED every NUL and kept the bytes either side, so `**Sprint:** 4<NUL>9` read as 49; a plain
# `read -r` line loop on bash 3.2 instead ENDS the line at the NUL and reads 4. `read -d ''` makes
# the NUL the delimiter, so concatenating the chunks is the NUL-dropped stream, exactly as before.
_sprint_header_scan() { # <path> -> _SPRINT_HDR_SEEN (1 when a declaration line is in the first 40 lines, else 0), _SPRINT_HDR_RAW (the first value's digits, or empty)
  local _sh_line="" _sh_n=0 _sh_eof=0 _sh_buf="" _sh_chunk="" _sh_nl=$'\n' _sh_np=0
  local -a _sh_parts=()
  local IFS=''                               # so "${_sh_parts[*]}" joins the chunks with nothing between
  _SPRINT_HDR_SEEN=0; _SPRINT_HDR_RAW=""
  {
    while [ "$_sh_n" -lt 40 ]; do
      # Only the NEW chunk is searched for the newline, since the buffer held none before it, and
      # the chunks are joined ONCE: searching and re-copying the growing buffer per chunk made a
      # long line quadratic (17s on a 4MB line, against the head form's 0.1s).
      if [[ $_sh_buf != *"$_sh_nl"* ]]; then
        _sh_parts=("$_sh_buf"); _sh_np=1
        while [ "$_sh_eof" = 0 ]; do
          IFS= read -r -d '' -n 4096 _sh_chunk || _sh_eof=1
          _sh_parts[$_sh_np]="$_sh_chunk"; _sh_np=$((_sh_np + 1))
          [[ $_sh_chunk != *"$_sh_nl"* ]] || break
        done
        _sh_buf="${_sh_parts[*]}"
      fi
      if [[ $_sh_buf == *"$_sh_nl"* ]]; then _sh_line="${_sh_buf%%"$_sh_nl"*}"; _sh_buf="${_sh_buf#*"$_sh_nl"}"
      elif [ -n "$_sh_buf" ]; then _sh_line="$_sh_buf"; _sh_buf=""
      else break; fi
      _sh_n=$((_sh_n + 1))
      [[ $_sh_line =~ $_HDR_DECL_RE ]] || continue
      _SPRINT_HDR_SEEN=1
      if [[ $_sh_line =~ $_HDR_VALUE_RE ]]; then _SPRINT_HDR_RAW="${BASH_REMATCH[1]}"; break; fi
    done
  } 2>/dev/null < "$1"
  return 0
}

sprint_header_present() { # <path> -> 0 when a **Sprint:** declaration line exists, whatever it says
  _sprint_header_scan "$1"
  [ "$_SPRINT_HDR_SEEN" = 1 ]
}

sprint_from_header() { # <path> -> the CANONICAL sprint the file's own header declares, or empty
  # The spelling is markdown-bold PROSE and not the schema's `^sprint:` key. Measured on the
  # refused population: the schema form matches 0 of 23, against a control of 318 files elsewhere
  # in the same tree that do match it -- so that zero discriminates rather than reporting a broken
  # search. Anchored at line start so `**Epic:** Sprint 131b` and `**QA agent:** Sprint 158-hotfix`
  # -- both present in this population -- cannot be read as declarations, and trailing prose is
  # allowed because `**Sprint:** 18 (carry-over eligible)` is one of the six that resolve.
  #
  # `S` IS OPTIONAL AND THE CONSUMER USES BOTH. `**Sprint:** S303` and `**Sprint:** S270 (carry-over
  # ...)` are spelt with the prefix: 46 such lines at consumer HEAD, 30 at the pre-migration ref
  # this script runs against, both against a control of 817 bare-digit headers in the same scan --
  # so the prefix is a real and separately-populated spelling, not a stray. The value is CASE-
  # FOLDED to the one legal slot spelling by `canon_sprint` below, exactly as the path-side
  # transform already normalises an uppercase `S301` component.
  #
  # The answer comes back in `_SPRINT_FROM_HEADER_OUT`, never through `$( )`.
  _sprint_header_scan "$1"
  canon_sprint "$_SPRINT_HDR_RAW"
  _SPRINT_FROM_HEADER_OUT="$_CANON_SPRINT_OUT"
}

# ONE CANONICAL FORM, ENFORCED AT THE ONLY WRITER THAT MINTS A SLOT FROM FILE CONTENT.
# `007` and `7` are the same sprint and would otherwise mint `s007/` and `s7/` as two homes for it,
# which `validate-artifact-paths.sh` accepts on both sides because `^s[0-9]+$` is satisfied by
# either -- so nothing downstream would ever report the split. Zero instances in the consumer today
# (control: 817 numeric headers in the same scan), so this is latent rather than live, and latent
# is the whole reason to fix it here: every OTHER sprint value in this script is read off a PATH
# that some earlier mechanism already normalised, while a header is free text nobody normalises.
# Leading zeros are STRIPPED rather than refused, because `007` states its sprint unambiguously and
# refusing it would strand a file over a spelling. `0` has no `s0` sprint to belong to and is
# refused, as is a value long enough to be an identifier rather than a sprint.
canon_sprint() { # <raw digits> -> _CANON_SPRINT_OUT: the canonical spelling, or empty when it is not a sprint
  local v="$1"
  _CANON_SPRINT_OUT=""
  [ -n "$v" ] || return 0
  case "$v" in *[!0-9]*) return 0 ;; esac
  [ "${#v}" -le 6 ] || return 0     # not a sprint number; a date or an id
  # `0` and `000` strip to the empty string and are refused BY that, with no separate guard. A
  # guard here would be vacuous -- both branches return empty -- and a mutant deleting it survived
  # every arm, which is exactly what a vacuous guard looks like from the outside. The strip is
  # `s/^0+//` without the fork: `${v%%[!0]*}` is the run of leading zeros, removed from the front.
  _CANON_SPRINT_OUT="${v#"${v%%[!0]*}"}"
}

# THE BASENAME CHANNEL AND `story_normalize` READ THE SAME DIGITS AND DO NOT AGREE, DELIBERATELY.
# Re-derived by driving both against one basename set: on `story-<A>-<B>` they agree (`story-297-1`
# -> 297 both ways). They part on `story-<M>-<slug>`, which `story_normalize` leaves ALONE -- its
# comment says a basename that is already `story-<M>-<slug>` must not have its index read as a
# sprint -- while this function returns that same `M`.
#
# THAT DIVERGENCE IS CORRECT AND IT IS THE WHOLE REASON THIS FUNCTION IS SEPARATE. The two are
# asked DIFFERENT QUESTIONS at different points. `story_normalize` runs on every legacy story and
# rewrites the path the general transform then scans, so reading an index as a sprint there would
# mis-file a file whose sprint is about to be read correctly from somewhere else. This function
# runs ONLY after `sprints_in` has returned zero over the whole path -- the file has no sprint
# anywhere, in any component -- and only after the header has been asked and declined. At that
# point the alternative to reading the leading number is refusing the file outright, which is why
# 15 of the consumer's 23 resolve here.
#
# Two guards keep that licence narrow. A `story-<M>-<slug>` basename reaching this point has
# already been left alone by `story_normalize` AND scored zero by `sprints_in`, so nothing else in
# the tree claims it; and the value goes through `canon_sprint`, so this channel cannot mint a slot
# spelling the path-side transform would not.
_SUBJECT_TYPED_RE='^(story|bug|hotfix|spike|chore|task)-([0-9]+)-.*$'
_SUBJECT_BARE_RE='^([0-9]+)-.*$'
# The plan loop reads the normalised name's own number with this, where a `sed -n` ran per story.
_STORY_S_NUM_RE='^story-s([0-9]+)-.*$'
sprint_from_subject() { # <path> -> _SPRINT_FROM_SUBJECT_OUT: a sprint opening the basename, or empty
  local _sf_b="${1##*/}" v=""
  if [[ $_sf_b =~ $_SUBJECT_TYPED_RE ]]; then v="${BASH_REMATCH[2]}"
  elif [[ $_sf_b =~ $_SUBJECT_BARE_RE ]]; then v="${BASH_REMATCH[1]}"; fi
  canon_sprint "$v"
  _SPRINT_FROM_SUBJECT_OUT="$_CANON_SPRINT_OUT"
}

# --- build the plan -----------------------------------------------------------
TMP="$(mktemp -d "${TMPDIR:-/tmp}/apmig-XXXXXX")" || exit 2
trap 'rm -rf "$TMP"' EXIT
PLAN="$TMP/plan"; REFUSE="$TMP/refuse"; INFERRED="$TMP/inferred"; RECOVERED="$TMP/recovered"
: > "$PLAN"; : > "$REFUSE"; : > "$INFERRED"; : > "$RECOVERED"

SCANNED=0
STORIES_SEEN=0

# THE TRACKED-FILE LIST IS STAGED AND ITS STATUS READ. The plan loop below used to read
# `done < <(git ls-files …)`, which discards the status: an `ls-files` that failed read as a tree
# with no artifact under any scan root, so the run exited 3, "nothing to migrate" -- a false
# clear on a tree full of work. A listing that did not run is exit 2, a tree this cannot safely
# operate on. SCAN_ROOTS is word-split into pathspecs exactly as before.
#
# NUL-DELIMITED, RAW PATHS. A plain `ls-files` prints any path holding a non-ASCII byte, a quote, a
# backslash or a control character C-QUOTED (`"docs/retro/sprint-320-caf\303\251.md"`), and that
# string names no file: such a path was neither planned nor refused -- silently skipped. `-z`
# prints every path as its bytes whatever `core.quotePath` says (git: "do not quote filenames").
LS_RC=0
# shellcheck disable=SC2046,SC2086
git ls-files -z -- $(printf '%s ' $SCAN_ROOTS) 2>/dev/null > "$TMP/tracked" || LS_RC=$?
if [ "$LS_RC" -ne 0 ]; then
  echo "$PROG: git ls-files over the scan roots did not run (exit $LS_RC), so no artifact was listed; refusing rather than reporting nothing to migrate" >&2
  exit 2
fi
# PROGRESS (see the header), on stderr. The total is counted once -- NUL-terminated records, read
# by the shell, no process -- and both lines are keyed on SCANNED straight after it moves, so no
# `continue` below can skip a tick.
_PG_TOTAL=0; _NL=$'\n'; _TAB=$'\t'
{ while IFS= read -r -d '' _pg_rec; do _PG_TOTAL=$((_PG_TOTAL + 1)); done < "${TMP}/tracked"; } 2>/dev/null
[ "$_PG_TOTAL" -lt "$_PG_EVERY" ] || echo "$PROG: PROGRESS plan: $_PG_TOTAL tracked file(s) to scan" >&2
_unsafe=0
_unsafe_row() { # the UNSAFE-NAME refusal for the current `src`, which holds a tab or a newline
  printf 'UNSAFE-NAME\t%q\tthe path holds a tab or a newline, and the plan and move lists this script carries are tab-separated lines, so it cannot be moved intact. Rename it without the tab or newline and the next run moves it.\n' \
    "$src" >> "$REFUSE"
}
_refuse() { # <printf format> <args>... -> that refusal row, or UNSAFE-NAME in its place for an unsafe `src`
  if [ "$_unsafe" = 1 ]; then _unsafe_row; else printf "$@" >> "$REFUSE"; fi
}
while IFS= read -r -d '' src; do
  [ -n "$src" ] || continue
  SCANNED=$((SCANNED + 1))
  [ $((SCANNED % _PG_EVERY)) -ne 0 ] || echo "$PROG: PROGRESS plan: scanned $SCANNED of $_PG_TOTAL" >&2
  # A TAB OR A NEWLINE IN THE PATH. The plan, the refusal list, the recovery and inferred-area
  # lists and the move list are tab-separated lines, so such a path cannot be carried through any
  # of them intact. It is only FLAGGED here: a conforming or tokenless path is skipped below exactly
  # as every other one is, and only a path that would produce a plan or refusal row is refused, by
  # name and shell-quoted (`_unsafe_row`), in place of that row. It never reaches a list.
  _unsafe=0
  case "$src" in *"$_NL"*|*"$_TAB"*) _unsafe=1 ;; esac

  # THE SPRINT IS ONE FACT ABOUT THE FILE. Read it from every component at once, so a path whose
  # directory and basename disagree is refused rather than silently resolved by whichever the
  # code happened to look at first.
  #
  # `scan` is the path the DERIVATION reads; `src` stays the real path `git mv` moves. They differ
  # only for a legacy story basename, whose bare leading sprint number is spelt `s<N>` first so
  # that everything below is the one transform rather than two.
  scan="$src"
  if legacy_story "$src"; then
    STORIES_SEEN=$((STORIES_SEEN + 1))
    story_normalize "$src"; scan="$_STORY_NORMALIZE_OUT"
    # THE HEADER OUTRANKS THE LEADING NUMBER HERE TOO, NOT ONLY WHEN THE PATH IS SILENT. In the
    # pre-s199 era `story-<A>-<B>` opens with the carry-over ITEM or epic number, so `A` is not
    # the sprint: `story-102-1-effective-spread-500.md` declares `**Sprint:** 53`, and reading `A`
    # filed it under s102, a different sprint entirely. A READABLE header that names a different
    # sprint wins and is reported under SPRINT RECOVERED as `header>name`. An unreadable one
    # (`50A`) keeps the name's reading: refusing here would block a source path the conformance
    # validator, which reads paths and never headers, still counts as one this script moves.
    if [ "$scan" != "$src" ]; then
      sb="${scan##*/}"
      _NM_RAW=""; [[ $sb =~ $_STORY_S_NUM_RE ]] && _NM_RAW="${BASH_REMATCH[1]}"
      canon_sprint "$_NM_RAW"; nm_n="$_CANON_SPRINT_OUT"
      sprint_from_header "$src"; hd_n="$_SPRINT_FROM_HEADER_OUT"
      if [ -n "$hd_n" ] && [ -n "$nm_n" ] && [ "$hd_n" != "$nm_n" ]; then
        # Composed through printf so this line stays clear of `story_normalize`'s `nb=` line, which
        # the artifact-path-migration fixture's `stories-half-migrated` mutant anchors on.
        scan="${scan%/*}/$(printf 'story-s%s-%s' "$hd_n" "${sb#story-s*-}")"
        [ "$_unsafe" = 1 ] || printf '%s\t%s\t%s\n' "$src" "$hd_n" "header>name" >> "$RECOVERED"
      fi
    fi
  fi

  sprints_in "$scan"; hits="$_SPRINTS_IN_OUT"
  # The line count of `hits` (every line non-empty): its newlines, plus one, unless it is empty.
  nhits=0; [ -z "$hits" ] || { _NHITS_NL="${hits//[!$'\n']/}"; nhits=$(( ${#_NHITS_NL} + 1 )); }
  if [ "$nhits" -eq 0 ]; then
    # A legacy story path is NON-CONFORMING by position whatever its name, so a sprint this cannot
    # derive is a refusal that must be named -- not the silent skip every other tokenless path
    # gets, which is correct for them because they are already conforming.
    if legacy_story "$src"; then
      # RECOVER BEFORE REFUSING. The header is the file's own declaration and outranks its name;
      # see the two functions above for the ordering measurement and for why history is not a
      # channel. A recovery is never silent -- it is recorded here and printed under RECOVERED, so
      # the operator can audit every sprint this script decided rather than read.
      rec=""; rec_ch=""
      sprint_from_header "$src"; rec="$_SPRINT_FROM_HEADER_OUT"
      [ -n "$rec" ] && rec_ch="header"
      # THE HEADER SPOKE AND COULD NOT BE READ -> REFUSE, never fall through to the basename.
      # For every carry-over shape the basename is the ITEM number, so falling through files the
      # file under a sprint that does not own it, silently -- strictly worse than the refusal this
      # recovery replaced. A file whose own declaration is unreadable is one the operator must fix.
      if [ -z "$rec" ] && sprint_header_present "$src"; then
        _refuse 'STORY-NO-SPRINT\t%s\tsits in a stories/ directory with no `s<N>/` above it, and it DOES carry a `**Sprint:**` line whose value could not be read as a sprint number. Its basename was NOT used as a fallback, deliberately: for a carry-over story the leading number is the ITEM, so guessing from it files the story under a sprint that does not own it. Fix the header to `**Sprint:** <N>` (an `S` prefix is fine) and the next run moves it.\n' \
          "$src"
        continue
      fi
      if [ -z "$rec" ]; then
        sprint_from_subject "$src"; rec="$_SPRINT_FROM_SUBJECT_OUT"
        [ -n "$rec" ] && rec_ch="basename"
      fi
      if [ -n "$rec" ]; then
        [ "$_unsafe" = 1 ] || printf '%s\t%s\t%s\n' "$src" "$rec" "$rec_ch" >> "$RECOVERED"
        hits="$rec"; nhits=1
      else
        _refuse 'STORY-NO-SPRINT\t%s\tsits in a stories/ directory with no `s<N>/` above it, so it is not on the grammar. Its name gives no sprint, its own `**Sprint:** <N>` header gives none either, and a suffixed sprint (`131b`) has no legal `s<N>/` slot to move to -- so both readings were tried and both came back empty. Add a `**Sprint:** <N>` header line, or rename it `story-<sprint>-<index>-<slug>.md` (or `s<N>-...`), and the next run moves it.\n' \
          "$src"
        continue
      fi
    else
      continue
    fi
  fi
  if [ "$nhits" -gt 1 ]; then
    _refuse 'AMBIGUOUS\t%s\tpath names %s different sprints (%s); which one owns it is not derivable\n' \
      "$src" "$nhits" "$(printf '%s' "$hits" | tr '\n' ' ')"
    continue
  fi
  n="$hits"

  # THE AREA IS THE ANCHOR: the slot goes directly under it and everything else nests inside.
  # Longest declared area that prefixes the path wins.
  area=""; src_area_prefix=""
  while IFS= read -r a; do
    [ -n "$a" ] || continue
    case "$src/" in "$a"/*) [ "${#a}" -gt "${#area}" ] && { area="$a"; src_area_prefix="$a"; } ;; esac
  done <<EOF
$DECLARED_AREAS
EOF

  if [ -z "$area" ]; then
    # Not under any DECLARED area. Infer one -- the scan root, plus one component when the scan
    # root is a container of areas rather than an area itself -- and REPORT it. On the reference
    # consumer this fires on NINE directories no area declares. Inferring silently would migrate
    # them and leave the declaration wrong; refusing outright would strand a chunk of the tree
    # for a paperwork reason.
    #
    # NINE, NOT EIGHT: the pre-run estimate said eight and the real run found `_bmad-output/research`
    # as well, on a single file. A count derived from a sample of a tree is not a count of the tree,
    # and the one it missed is the one with the fewest files -- which is the direction that kind of
    # miss always runs in.
    for r in $SCAN_ROOTS; do
      case "$src/" in
        "$r"/*)
          rest="${src#"$r"/}"
          if [ "$rest" = "${rest%%/*}" ]; then
            area="$r"                       # the file sits directly in the scan root
          else
            case "$r" in
              */*) area="$r" ;;             # `docs/retro` IS an area
              # `_bmad-output` CONTAINS areas. The component is STRIPPED before being used as
              # one: `party-verdicts-s274-retro/` is a per-sprint directory sitting where an
              # area should be, and taking it verbatim yields `party-verdicts-s274-retro/s274/`
              # -- the reserved slot nested inside the token it replaces, on 30 paths.
              # A first component that is PURELY a sprint token (`_bmad-output/s177/foo.md`)
              # strips to nothing, and using it would compose `_bmad-output//s177/...`. It is
              # a sprint directory sitting directly under a scan root that is declared NOT to
              # be an area, so there is no area to anchor the slot to and nothing here can
              # derive one. Refused and named, not guessed.
              *)   strip_token "${rest%%/*}"; _ac="$_STRIP_TOKEN_OUT"
                   if [ -z "$_ac" ]; then
                     _refuse 'NO-AREA\t%s\t`%s/%s` is a sprint directory directly under a scan root that is not an area, so there is no area to anchor `s<N>/` to. Declare the area it belongs in, or move it under one.\n' \
                       "$src" "$r" "${rest%%/*}"
                     continue
                   fi
                   area="$r/$_ac" ;;
            esac
          fi
          src_area_prefix="$r"
          [ "$area" = "$r" ] || src_area_prefix="$r/${rest%%/*}"
          break ;;
      esac
    done
    [ -n "$area" ] || continue
    [ "$area" = "_bmad-output" ] || [ "$_unsafe" = 1 ] || printf '%s\n' "$area" >> "$INFERRED"
  fi

  # `rel` comes off the ORIGINAL prefix, since an inferred area may have been stripped and no
  # longer prefixes the source path. It is taken from `scan`, not `src`, so a normalised story
  # basename reaches the component rebuild below and its bare number is stripped like any token.
  rel="${scan#"$src_area_prefix"/}"
  # `_bmad-output/` root: not an area. Its sprint-tokened files are log rotation archives.
  if [ "$area" = "_bmad-output" ]; then
    area="$ARCHIVE_HOME"
    rel="${scan##*/}"
  fi

  # Rebuild every component with its token removed. A component that strips to nothing is
  # dropped; a nameless basename takes the name of what contained it.
  out=""; last=""; prev_named="${area##*/}"
  oldIFS="$IFS"; IFS='/'; set -f; parts=($rel); set +f; IFS="$oldIFS"
  ncomp="${#parts[@]}"
  i=0
  for c in "${parts[@]}"; do
    i=$((i + 1))
    strip_token "$c"; s="$_STRIP_TOKEN_OUT"
    if [ "$i" -lt "$ncomp" ]; then
      is_nameless "$s" && continue           # the directory WAS the sprint
      out="${out}${s}/"; prev_named="$s"
    else
      if is_nameless "$s"; then
        ext=""; case "$c" in *.*) ext=".${c##*.}" ;; esac
        s="${prev_named}${ext}"
        # The containing directory has been promoted into the filename, so it must not also
        # remain a directory: `sprint-status/sprint-187.yaml` becomes `s187/sprint-status.yaml`,
        # never `s187/sprint-status/sprint-status.yaml`.
        out="${out%"${prev_named}/"}"
      fi
      last="$s"
    fi
  done

  dest="$area/s$n/${out}${last}"
  [ "$dest" = "$src" ] && continue           # already conforming
  if [ "$_unsafe" = 1 ]; then _unsafe_row; continue; fi
  printf '%s\t%s\n' "$src" "$dest" >> "$PLAN"
done < "$TMP/tracked"

# COLLISIONS ARE REFUSED, NOT RESOLVED. Two spellings of one sprint's artifact
# (`sprint-171-adversarial-pass2.md` and `s171-adversarial-pass2.md`) collapse to one
# destination, and `git mv` would silently overwrite. Picking one is a guess about which is the
# real artifact, and this script does not make that guess for the operator.
COLLIDE="$TMP/collide"
cut -f2 "$PLAN" | sort | uniq -d > "$COLLIDE"
if [ -s "$COLLIDE" ]; then
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    srcs="$(awk -F'\t' -v D="$d" '$2==D{printf "%s ", $1}' "$PLAN")"
    printf 'COLLISION\t%s\t%s source(s) map here: %s\n' "$d" "$(printf '%s' "$srcs" | wc -w | tr -d ' ')" "$srcs" >> "$REFUSE"
  done < "$COLLIDE"
  # Drop every colliding row. A partial migration of a collision set is worse than none: it
  # leaves the survivors unfindable under either convention.
  awk -F'\t' 'NR==FNR{bad[$0]=1;next} !($2 in bad)' "$COLLIDE" "$PLAN" > "$PLAN.keep" && mv "$PLAN.keep" "$PLAN"
fi

N_PLAN="$(grep -c . "$PLAN" || true)"
N_REFUSE="$(grep -c . "$REFUSE" || true)"

echo "$PROG: root $ROOT_ABS"
echo "  grammar:               $GRAMMAR"
echo "  scan roots:            $(printf '%s ' $SCAN_ROOTS)"
echo "  tracked files scanned: $SCANNED"
echo "  moves planned:         $N_PLAN"
echo "  REFUSED:               $N_REFUSE"
echo ""

# THE STORY CORPUS IS NO LONGER DEFERRED, and the count is printed rather than dropped because a
# corpus this size moving in silence is indistinguishable from one that did not move. The previous
# release reported 1001 files here as a KNOWN gap; this one reports how many it saw and, in
# REFUSED above, every one it could not place.
if [ "$STORIES_SEEN" -gt 0 ]; then
  echo "STORIES — $STORIES_SEEN file(s) sit in a stories/ directory carrying no \`s<N>/\` slot,"
  echo "  which is what makes them legacy whatever they are called. The sprint is taken from the"
  echo "  name unless the file's own readable \`**Sprint:**\` header names another; where neither"
  echo "  gives one they are REFUSED above by path, never guessed."
  echo ""
fi

# RECOVERY IS NEVER SILENT. A sprint this script READ off the path is derivable by anyone; a
# sprint it RECOVERED is a claim it made about a file whose name does not carry one, and the
# operator has to be able to audit it. Each row names the channel that produced it, because the
# two channels are not equally trustworthy -- a header is the file's own declaration, a basename
# is an inference from a spelling convention -- and a wrong recovery is a file filed under the
# wrong sprint, which is invisible afterwards.
N_RECOVERED="$(grep -c . "$RECOVERED")" || N_RECOVERED=0
if [ "$N_RECOVERED" -gt 0 ]; then
  echo "SPRINT RECOVERED — $N_RECOVERED story file(s) whose path names no sprint, or whose name's"
  echo "  leading number their own header contradicts, so the sprint was read from the file itself."
  echo "  These MOVE. Audit them: a recovered sprint is this script's claim, not something the path"
  echo "  stated. \`header\` is the file's own \`**Sprint:** <N>\` line and wins where both speak;"
  echo "  \`header>name\` is that header overruling a \`story-<A>-<B>\` name whose A is an item number;"
  echo "  \`basename\` is the leading number in the name:"
  sort "$RECOVERED" | awk -F'\t' '{printf "  s%-6s %-8s %s\n", $2, $3, $1}'
  echo ""
fi

if [ -s "$INFERRED" ]; then
  echo "AREAS INFERRED — no area is declared for these, so one was derived from the scan root."
  echo "They migrate correctly, but nothing has declared them:"
  sort "$INFERRED" | uniq -c | sort -rn | sed 's/^/  /'
  if [ -n "$REMEDY_FILE" ]; then
    echo ""
    echo "  DECLARE THEM IN YOUR OWN FILE, NOT IN CORE'S GRAMMAR:"
    echo "    $REMEDY_FILE"
    echo "  Add each under its 'areas:' block. That file is consumer-owned and survives a pull;"
    echo "  core's artifact-path-grammar.md is overwritten by one, so an area added there is"
    echo "  gone at the next update. This run READ your file and joined its areas to core's, so"
    echo "  declaring them is what stops them being inferred here again."
    # AND IF THE DECLARATION IS ALREADY THERE AND UNREADABLE, SAY SO HERE. Without this line the
    # remedy above is what a consumer who has ALREADY followed it reads, on every run, forever --
    # which is the state the shipped template put them in for seven releases. The syntax check is
    # resolved from the config rather than restated, so there is one spelling of what readable means.
    _syn="$(cfg --consumer-syntax 2>/dev/null || true)"
    [ -n "$_syn" ] && { echo ""; echo "  $_syn" | fold -s -w 96 | sed '2,$s/^/  /'; }
  fi
  echo ""
fi

if [ "$N_REFUSE" -gt 0 ]; then
  echo "REFUSED — NOT migrated and NOT conforming. Printed in full, because a migration that"
  echo "silently covers most of a tree reads as 'done':"
  sort "$REFUSE" | awk -F'\t' '{printf "  %-10s %s\n             %s\n", $1, $2, $3}'
  echo ""
fi

if [ "$N_PLAN" -eq 0 ]; then
  if [ "$N_REFUSE" -gt 0 ]; then
    echo "VERDICT: nothing migratable, $N_REFUSE refusal(s) above. Resolve them and re-run."
    exit 3
  fi
  echo "VERDICT: already conforming — no path under the scan roots carries a sprint token outside"
  echo "  the reserved slot. Control: $SCANNED tracked file(s) were read to establish that. A zero"
  echo "  here with a zero scanned would mean the scan roots resolved to nothing."
  exit 3
fi

# THE SELF-CHECK, on both roads. A migration whose own output breaks the rule it enforces is the
# worst possible outcome: it looks done, the validator that lands next fails on 2000 files, and
# the tree is worse than before. Computed by stripping the ONE legal slot and asking whether any
# token survives.
LEFTOVER="$(cut -f2 "$PLAN" | sed -E 's#/s[0-9]+/#/#' | grep -cE "(/|-)(s|S|sprint-)[0-9]+(-|/|\.|$)" || true)"

if [ "$APPLY" -eq 0 ]; then
  echo "DRY RUN — nothing was written. Planned moves, by area:"
  cut -f2 "$PLAN" | sed -E 's#/s[0-9]+/.*$##' | sort | uniq -c | sort -rn | sed 's/^/  /'
  echo ""
  echo "  Sample (first 8):"
  head -8 "$PLAN" | awk -F'\t' '{printf "    %s\n      -> %s\n", $1, $2}'
  echo ""
  echo "  SELF-CHECK: destinations still carrying a sprint token outside the slot: $LEFTOVER"
  echo "  (must be 0 — non-zero means this script writes paths its own grammar rejects)"
  echo ""
  echo "VERDICT: $N_PLAN move(s) planned, $N_REFUSE refused. Re-run with --apply to perform them."
  [ "$LEFTOVER" -eq 0 ] || exit 1
  exit 0
fi

if [ "$LEFTOVER" -ne 0 ]; then
  echo "$PROG: REFUSING TO APPLY — $LEFTOVER planned destination(s) still carry a sprint token" >&2
  echo "  outside the reserved slot. Applying would move files onto paths this grammar rejects." >&2
  exit 1
fi

# --- apply --------------------------------------------------------------------
#
# BATCHED, AND STILL VERIFIED PER FILE. One `shasum` and one `git mv` per move cost ~77ms a move,
# ~280s for the reference consumer's 3637 moves, and the two `shasum` runs were most of it. So the
# moves run in batches of _AP_CHUNK: one `shasum` over the batch's sources, then per move the same
# checks in the same order (source readable, destination ABSENT -- never overwritten --, directory,
# move), then one `shasum` over the batch's destinations and the three legs per file, in order, then
# ONE index update staging the batch's moves as renames from the sources' existing index entries
# (`git ls-files -s` -> `git update-index --index-info`), the same mode and blob `git mv` carries.
#
# A FAILED MOVE, READ OR VERIFICATION LEAVES THE TREE AND THE INDEX THE ONE-MOVE-AT-A-TIME LOOP
# LEFT. A failing move at position k is reported only after the moves before it are verified; a
# failed verification at k moves the batch's later, unverified files back to their sources first;
# and the moves through k are staged before the exit, as `git mv` had already staged them.
# A FAILED INDEX UPDATE (a stale `index.lock`, say) moves the WHOLE batch back, last first, so the
# tree and index are what the one-at-a-time loop leaves when its first `git mv` in that batch is
# refused; only the message differs, naming the index update rather than `git mv`. A file that
# cannot be moved back is reported by name, never dropped. Every directory THIS run created is
# recorded with the move that created it, and a rollback removes the ones the one-at-a-time loop
# would never have reached, deepest first, with `rmdir` only -- so a directory that is not empty
# stays.
_AP_CHUNK=256
_AP_S=(); _AP_D=(); _AP_N=0; _AP_H=(); _AP_B=(); _AP_LO=0
_AP_MKD=(); _AP_MKW=(); _AP_MKN=0; _AP_VK=""; _AP_VMSG=""; _AP_RBSKIP=""
while IFS=$'\t' read -r src dest; do
  [ -n "$src" ] && [ -n "$dest" ] || continue
  _AP_S[$_AP_N]="$src"; _AP_D[$_AP_N]="$dest"; _AP_N=$((_AP_N + 1))
done < "$PLAN"

_ap_hash() { # <path>... -> _AP_H[k]: what `shasum -a 256 <path> | cut -d' ' -f1` gives the k-th path, '' when unreadable
  local _ah_p="" _ah_k=0 _ah_j=0 _ah_n=0 _ah_l=""
  local -a _ah_lines=()
  _AP_H=()
  shasum -a 256 "$@" > "$TMP/apply-hash" 2>/dev/null
  while IFS= read -r _ah_l; do _ah_lines[$_ah_n]="$_ah_l"; _ah_n=$((_ah_n + 1)); done < "$TMP/apply-hash"
  for _ah_p in "$@"; do
    # An unreadable path has NO line, and a name `shasum` escapes does not compare equal. Either
    # way the path gets the one-file command, and the next line is consumed only if that path was
    # readable -- so a line is never credited to the wrong path.
    _ah_l=""; [ "$_ah_j" -ge "$_ah_n" ] || _ah_l="${_ah_lines[$_ah_j]}"
    if [ -n "$_ah_l" ] && [ "${_ah_l:0:1}" != '\' ] && [ "${_ah_l#*  }" = "$_ah_p" ]; then
      _AP_H[$_ah_k]="${_ah_l%%  *}"; _ah_j=$((_ah_j + 1))
    else
      _AP_H[$_ah_k]="$(shasum -a 256 "$_ah_p" 2>/dev/null | cut -d' ' -f1)"
      [ -z "${_AP_H[$_ah_k]}" ] || _ah_j=$((_ah_j + 1))
    fi
    _ah_k=$((_ah_k + 1))
  done
}

_ap_mkdir() { # <move> <dir> -> `mkdir -p <dir>`, recording each level it creates against <move>
  local _md_d="$2" _md_i=0
  local -a _md_l=()
  [ -d "$_md_d" ] && return 0
  while [ -n "$_md_d" ] && [ ! -e "$_md_d" ]; do
    _md_l[$_md_i]="$_md_d"; _md_i=$((_md_i + 1))
    case "$_md_d" in */*) _md_d="${_md_d%/*}" ;; *) _md_d="" ;; esac
  done
  mkdir -p "$2" || return 1
  while [ "$_md_i" -gt 0 ]; do               # recorded shallowest first, so a reverse walk is deepest first
    _md_i=$((_md_i - 1))
    _AP_MKD[$_AP_MKN]="${_md_l[$_md_i]}"; _AP_MKW[$_AP_MKN]="$1"; _AP_MKN=$((_AP_MKN + 1))
  done
}

_ap_rollback() { # <from> <to, exclusive> <first move whose directories go> -> moves back, last first, then rmdir
  local _rb_k=$(($2 - 1)) _rb_j=$((_AP_MKN - 1))
  while [ "$_rb_k" -ge "$1" ]; do
    # Never onto a source path that exists again: the file there is not this run's to replace.
    if [ -e "${_AP_S[$_rb_k]}" ] || [ -L "${_AP_S[$_rb_k]}" ]; then
      echo "$PROG: FAIL — could not move ${_AP_D[$_rb_k]} back to ${_AP_S[$_rb_k]}: that path exists again and is never overwritten; the file is still at the destination, unstaged." >&2
      _AP_RBSKIP=1
    else
      mv -- "${_AP_D[$_rb_k]}" "${_AP_S[$_rb_k]}" 2>/dev/null \
        || { echo "$PROG: FAIL — could not move ${_AP_D[$_rb_k]} back to ${_AP_S[$_rb_k]}; it is still at the destination, unstaged." >&2; _AP_RBSKIP=1; }
    fi
    _rb_k=$((_rb_k - 1))
  done
  while [ "$_rb_j" -ge 0 ] && [ "${_AP_MKW[$_rb_j]}" -ge "$3" ]; do
    rmdir -- "${_AP_MKD[$_rb_j]}" 2>/dev/null
    _rb_j=$((_rb_j - 1))
  done
}

# STAGED FROM THE SOURCE'S OWN INDEX ENTRY. `git update-index --add` would re-hash the moved file
# through the clean and eol filters, and a file committed before a `text=auto` attribute then stages
# as a content change; `git mv` carries the entry over. So the entry is read and carried: one removal
# line for the source, one line for the destination with the source's mode and blob.
#
# BOTH SIDES ARE NUL-DELIMITED RAW PATHS, for the reason the plan's own listing is: a C-quoted
# `ls-files -s` path matches no source, and the batch would roll back and abort over a name it
# could have moved. The entries come back in index order, which is the plan's order, so each source
# is matched at its own position first and searched for only if that fails; a source with no
# stage-0 entry fails the batch rather than being staged from a guess.
_ap_stage() { # <from> <to, exclusive> -> 0 when those moves are staged as renames in ONE index update
  local _sg_k="$1" _sg_n=0 _sg_j=0 _sg_r="" _sg_p="" _sg_ms="" _sg_z=""
  local -a _sg_ep=() _sg_em=()
  [ "$1" -lt "$2" ] || return 0
  git --literal-pathspecs ls-files -s -z -- "${_AP_S[@]:$1:$(($2 - $1))}" > "$TMP/apply-entries" 2>/dev/null || return 1
  while IFS= read -r -d '' _sg_r; do        # `<mode> <blob> <stage>TAB<path>`
    _sg_p="${_sg_r#*$'\t'}"; _sg_ms="${_sg_r%%$'\t'*}"
    [ "${_sg_ms##* }" = 0 ] || continue
    _sg_ep[$_sg_n]="$_sg_p"; _sg_em[$_sg_n]="${_sg_ms% *}"; _sg_n=$((_sg_n + 1))
  done < "$TMP/apply-entries"
  : > "$TMP/apply-info" || return 1
  while [ "$_sg_k" -lt "$2" ]; do
    _sg_j=$((_sg_k - $1))
    if [ "$_sg_j" -ge "$_sg_n" ] || [ "${_sg_ep[$_sg_j]}" != "${_AP_S[$_sg_k]}" ]; then
      _sg_j=0
      while [ "$_sg_j" -lt "$_sg_n" ] && [ "${_sg_ep[$_sg_j]}" != "${_AP_S[$_sg_k]}" ]; do _sg_j=$((_sg_j + 1)); done
      [ "$_sg_j" -lt "$_sg_n" ] || return 1
    fi
    _sg_z="${_sg_em[$_sg_j]#* }"; _sg_z="${_sg_z//?/0}"
    printf '0 %s\t%s\0%s 0\t%s\0' "$_sg_z" "${_AP_S[$_sg_k]}" "${_sg_em[$_sg_j]}" "${_AP_D[$_sg_k]}" >> "$TMP/apply-info"
    _sg_k=$((_sg_k + 1))
  done
  git update-index -z --index-info < "$TMP/apply-info" 2>/dev/null
}

_ap_fail_msg() { # <kind> -> the failure message the one-at-a-time loop printed for it
  case "$1" in
    read)   echo "$PROG: FAIL — cannot read $src before moving it. Aborting after $MOVED move(s)." >&2 ;;
    exists) echo "$PROG: FAIL — destination already exists: $dest. Aborting after $MOVED move(s)." >&2
            echo "  Not in the collision set, so it is a pre-existing file. Never overwritten." >&2 ;;
    mkdir)  echo "$PROG: FAIL — cannot create ${dest%/*}" >&2 ;;
    mv)     echo "$PROG: FAIL — git mv refused: $src -> $dest. Aborting after $MOVED move(s)." >&2 ;;
    verify) printf '%s\n' "$_AP_VMSG" >&2
            echo "  Aborting after $MOVED verified move(s). \`git checkout -- .\` restores the tree." >&2 ;;
  esac
}

_ap_verify() { # <from> <to, exclusive> -> PER-FILE, THREE LEGS, AND A COUNT WOULD SEE NONE OF THEM
  # -> _AP_VK: the first move failing a leg ('' when none), and _AP_VMSG: its report, legs read now
  local _vf_k="$1" _vf_m=0 _vf_src="" _vf_dest="" _vf_before="" _vf_after="" _vf_sp=no _vf_dr=no
  _AP_VK=""; _AP_VMSG=""
  [ "$1" -lt "$2" ] || return 0
  _ap_hash "${_AP_D[@]:$1:$(($2 - $1))}"
  while [ "$_vf_k" -lt "$2" ]; do
    _vf_src="${_AP_S[$_vf_k]}"; _vf_dest="${_AP_D[$_vf_k]}"
    _vf_before="${_AP_B[$((_vf_k - _AP_LO))]}"; _vf_after="${_AP_H[$_vf_m]}"
    if [ -e "$_vf_src" ] || [ ! -r "$_vf_dest" ] || [ "$_vf_before" != "$_vf_after" ]; then
      _vf_sp=no; [ ! -e "$_vf_src" ] || _vf_sp=yes
      _vf_dr=no; [ ! -r "$_vf_dest" ] || _vf_dr=yes
      _AP_VK="$_vf_k"
      _AP_VMSG="$PROG: FAIL — verification failed for $_vf_src -> $_vf_dest
    source still present: $_vf_sp
    destination readable: $_vf_dr
    sha256 before/after:  $_vf_before / ${_vf_after:-<unreadable>}"
      return 0
    fi
    _vf_k=$((_vf_k + 1)); _vf_m=$((_vf_m + 1))
  done
}

MOVED=0
[ "$N_PLAN" -lt "$_PG_EVERY" ] || echo "$PROG: PROGRESS apply: $N_PLAN move(s) to apply" >&2
while [ "$_AP_LO" -lt "$_AP_N" ]; do
  _ap_hi=$((_AP_LO + _AP_CHUNK)); [ "$_ap_hi" -le "$_AP_N" ] || _ap_hi="$_AP_N"
  _ap_hash "${_AP_S[@]:$_AP_LO:$((_ap_hi - _AP_LO))}"
  _AP_B=(${_AP_H[@]+"${_AP_H[@]}"})
  _ap_done="$_AP_LO"; _ap_fail=""; _ap_k="$_AP_LO"
  while [ "$_ap_k" -lt "$_ap_hi" ]; do
    src="${_AP_S[$_ap_k]}"; dest="${_AP_D[$_ap_k]}"; before="${_AP_B[$((_ap_k - _AP_LO))]}"
    if [ -z "$before" ]; then _ap_fail=read; break; fi
    if [ -e "$dest" ]; then _ap_fail=exists; break; fi
    _ap_mkdir "$_ap_k" "${dest%/*}" || { _ap_fail=mkdir; break; }
    mv -- "$src" "$dest" 2>/dev/null || { _ap_fail=mv; break; }
    _ap_k=$((_ap_k + 1)); _ap_done="$_ap_k"
  done
  # A failed leg at k: the later moves never happened in the one-at-a-time loop, so undo them.
  _ap_verify "$_AP_LO" "$_ap_done"
  _ap_end="$_ap_done"; _ap_ok="$_ap_done"
  if [ -n "$_AP_VK" ]; then
    _ap_rollback $((_AP_VK + 1)) "$_ap_done" $((_AP_VK + 1))
    _ap_end=$((_AP_VK + 1)); _ap_ok="$_AP_VK"; _ap_fail=verify
  fi
  # The index update failed: the one-at-a-time loop's first `git mv` of this batch is refused, so
  # every move of the batch is undone; the directory that loop created for that first move stays.
  if ! _ap_stage "$_AP_LO" "$_ap_end"; then
    _ap_rollback "$_AP_LO" "$_ap_end" $((_AP_LO + 1))
    echo "$PROG: FAIL — git update-index refused to stage this batch's renames, from ${_AP_S[$_AP_LO]} -> ${_AP_D[$_AP_LO]}; the batch was moved back${_AP_RBSKIP:+, except the file(s) named above}. Aborting after $MOVED move(s)." >&2
    _ap_fail_msg "$_ap_fail"
    exit 1
  fi
  _ap_k="$_AP_LO"
  while [ "$_ap_k" -lt "$_ap_ok" ]; do
    MOVED=$((MOVED + 1))
    [ $((MOVED % _PG_EVERY)) -ne 0 ] || echo "$PROG: PROGRESS apply: moved $MOVED of $N_PLAN" >&2
    _ap_k=$((_ap_k + 1))
  done
  [ -z "$_ap_fail" ] || { _ap_fail_msg "$_ap_fail"; exit 1; }
  _AP_LO="$_ap_hi"
done

echo "VERDICT: $MOVED of $N_PLAN planned move(s) applied and VERIFIED per file"
echo "  (source absent AND destination readable AND sha256 identical, checked for each one)."
if [ "$N_REFUSE" -gt 0 ]; then
  echo "  $N_REFUSE file(s) were REFUSED and remain non-conforming — see the list above."
fi
echo "  Nothing was deleted and no file's content changed. Review with \`git status\`, then commit."
echo "  Citations into the old paths no longer resolve; that is accepted, and the declared"
echo "  convention is the guide to where to look."
[ "$MOVED" -eq "$N_PLAN" ] || exit 1
exit 0
