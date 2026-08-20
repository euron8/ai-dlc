#!/usr/bin/env bash
# migrate-artifact-paths.sh — move a consumer's artifacts onto the declared path grammar.
#
#   migrate-artifact-paths.sh [--root <dir>] [--grammar <file>]            # DRY RUN. Writes nothing.
#   migrate-artifact-paths.sh [--root <dir>] [--grammar <file>] --apply    # git mv + verification.
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
# `git mv` ONLY, NEVER A DELETE, and never a rewrite of any file's CONTENT. Breaking historical
# traceability is accepted by operator directive -- the declared convention is the guide to where
# to look, and a link-rewriting pass over 2000+ files is a second, unverifiable migration riding
# on this one.
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
    -h|--help) sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "$PROG: unknown option '$1'" >&2
       echo "usage: $PROG [--root <dir>] [--grammar <file>] [--apply]" >&2
       exit 2 ;;
  esac
done

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
cfg() { # <mode> -> the resolver's answer, or die carrying its own message
  local out rc
  if [ -n "$GRAMMAR_ARG" ]; then out="$(bash "$CONFIG" "$1" --grammar "$GRAMMAR_ARG" 2>&1)"; rc=$?
  else                           out="$(bash "$CONFIG" "$1" 2>&1)"; rc=$?; fi
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
REMEDY_FILE="$(bash "$CONFIG" --consumer-file 2>/dev/null || true)"

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
strip_token() { # <component> -> the component with EVERY sprint token removed, separators tidied
  local cur="$1" prev=""
  while [ "$cur" != "$prev" ]; do
    prev="$cur"
    cur="$(printf '%s' "$cur" | sed -E 's/(^|-)(s|S|sprint-)[0-9]+(-|$|\.)/\1\3/')"
  done
  printf '%s' "$cur" | sed -E 's/--+/-/g; s/^-+//; s/-+(\.|$)/\1/'
}

sprints_in() { # <path> -> the DISTINCT sprint numbers its components name, one per line
  local c cur prev n
  printf '%s\n' "$1" | tr '/' '\n' | while IFS= read -r c; do
    cur="$c"; prev=""
    while [ "$cur" != "$prev" ]; do
      prev="$cur"
      n="$(printf '%s' "$cur" | grep -oE "$TOKEN_RE" | head -1 | grep -oE '[0-9]+')"
      [ -n "$n" ] || break
      printf '%s\n' "$n"
      cur="$(printf '%s' "$cur" | sed -E 's/(^|-)(s|S|sprint-)[0-9]+(-|$|\.)/\1\3/')"
    done
  done | sort -u
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
# Corroborated on the reference consumer before this shipped, because a licence is not a
# measurement: of the 786 basenames matching `story-<A>-<B>`, ALL 786 have `A` inside the sprint
# range the tree actually uses (7..302) and `B` distributed as a story index (212 ones, 176 twos).
# Control, the form where the sprint is NOT in doubt: all 73 `story-S<N>-<M>` files have exactly
# that structure in exactly those two positions.
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
story_normalize() { # <path> -> the path with a bare leading sprint number spelt `s<N>`
  local b="${1##*/}" nb
  case "$b" in story-[0-9]*) ;; *) printf '%s' "$1"; return ;; esac
  nb="$(printf '%s' "$b" | sed -E 's/^story-([0-9]+)-([0-9]+)/story-s\1-\2/')"
  if [ "$nb" = "$b" ]; then printf '%s' "$1"; else printf '%s/%s' "${1%/*}" "$nb"; fi
}

# --- build the plan -----------------------------------------------------------
TMP="$(mktemp -d "${TMPDIR:-/tmp}/apmig-XXXXXX")" || exit 2
trap 'rm -rf "$TMP"' EXIT
PLAN="$TMP/plan"; REFUSE="$TMP/refuse"; INFERRED="$TMP/inferred"
: > "$PLAN"; : > "$REFUSE"; : > "$INFERRED"

SCANNED=0
STORIES_SEEN=0
while IFS= read -r src; do
  [ -n "$src" ] || continue
  SCANNED=$((SCANNED + 1))

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
    scan="$(story_normalize "$src")"
  fi

  hits="$(sprints_in "$scan")"
  nhits="$(printf '%s\n' "$hits" | grep -c .)"
  if [ "$nhits" -eq 0 ]; then
    # A legacy story path is NON-CONFORMING by position whatever its name, so a sprint this cannot
    # derive is a refusal that must be named -- not the silent skip every other tokenless path
    # gets, which is correct for them because they are already conforming.
    if legacy_story "$src"; then
      printf 'STORY-NO-SPRINT\t%s\tsits in a stories/ directory with no `s<N>/` above it, so it is not on the grammar -- but its name gives no sprint to move it to. Rename it `story-<sprint>-<index>-<slug>.md` (or `s<N>-...`) and the next run moves it.\n' \
        "$src" >> "$REFUSE"
    fi
    continue
  fi
  if [ "$nhits" -gt 1 ]; then
    printf 'AMBIGUOUS\t%s\tpath names %s different sprints (%s); which one owns it is not derivable\n' \
      "$src" "$nhits" "$(printf '%s' "$hits" | tr '\n' ' ')" >> "$REFUSE"
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
              *)   _ac="$(strip_token "${rest%%/*}")"
                   if [ -z "$_ac" ]; then
                     printf 'NO-AREA\t%s\t`%s/%s` is a sprint directory directly under a scan root that is not an area, so there is no area to anchor `s<N>/` to. Declare the area it belongs in, or move it under one.\n' \
                       "$src" "$r" "${rest%%/*}" >> "$REFUSE"
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
    [ "$area" = "_bmad-output" ] || printf '%s\n' "$area" >> "$INFERRED"
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
    s="$(strip_token "$c")"
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
  printf '%s\t%s\n' "$src" "$dest" >> "$PLAN"
done < <(git ls-files -- $(printf '%s ' $SCAN_ROOTS) 2>/dev/null)

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
  echo "  name; where the name does not give one they are REFUSED above by path, never guessed."
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
MOVED=0
while IFS=$'\t' read -r src dest; do
  [ -n "$src" ] && [ -n "$dest" ] || continue
  before="$(shasum -a 256 "$src" 2>/dev/null | cut -d' ' -f1)"
  if [ -z "$before" ]; then
    echo "$PROG: FAIL — cannot read $src before moving it. Aborting after $MOVED move(s)." >&2
    exit 1
  fi
  if [ -e "$dest" ]; then
    echo "$PROG: FAIL — destination already exists: $dest. Aborting after $MOVED move(s)." >&2
    echo "  Not in the collision set, so it is a pre-existing file. Never overwritten." >&2
    exit 1
  fi
  mkdir -p "${dest%/*}" || { echo "$PROG: FAIL — cannot create ${dest%/*}" >&2; exit 1; }
  if ! git mv -- "$src" "$dest" 2>/dev/null; then
    echo "$PROG: FAIL — git mv refused: $src -> $dest. Aborting after $MOVED move(s)." >&2
    exit 1
  fi
  # PER-FILE, THREE LEGS, AND A COUNT WOULD SEE NONE OF THEM.
  after="$(shasum -a 256 "$dest" 2>/dev/null | cut -d' ' -f1)"
  if [ -e "$src" ] || [ ! -r "$dest" ] || [ "$before" != "$after" ]; then
    echo "$PROG: FAIL — verification failed for $src -> $dest" >&2
    echo "    source still present: $([ -e "$src" ] && echo yes || echo no)" >&2
    echo "    destination readable: $([ -r "$dest" ] && echo yes || echo no)" >&2
    echo "    sha256 before/after:  $before / ${after:-<unreadable>}" >&2
    echo "  Aborting after $MOVED verified move(s). \`git checkout -- .\` restores the tree." >&2
    exit 1
  fi
  MOVED=$((MOVED + 1))
done < "$PLAN"

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
