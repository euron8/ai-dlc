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

[ -d "$ROOT" ] || { echo "$PROG: not a directory: $ROOT" >&2; exit 2; }
cd "$ROOT" || exit 2
ROOT_ABS="$(pwd)"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || { echo "$PROG: $ROOT_ABS is not a git work tree. This moves files with \`git mv\` so that a" >&2
       echo "  bad run is recoverable with \`git checkout\`; without git there is no undo." >&2; exit 2; }

# --- the scan roots and the areas come from the grammar, not from here -------
# The same two blocks I82 reads, so enforcement and migration can never disagree about which part
# of the tree the rule governs or where a sprint directory may live.
GRAMMAR=""
if [ -n "$GRAMMAR_ARG" ]; then
  [ -f "$GRAMMAR_ARG" ] || { echo "$PROG: --grammar names no readable file: $GRAMMAR_ARG" >&2; exit 2; }
  GRAMMAR="$GRAMMAR_ARG"
else
  for c in ".claude/skills/ai-dlc/artifact-path-grammar.md" \
           "core/skills/ai-dlc/artifact-path-grammar.md"; do
    [ -f "$c" ] && GRAMMAR="$c" && break
  done
fi
[ -n "$GRAMMAR" ] || { echo "$PROG: cannot find artifact-path-grammar.md under $ROOT_ABS." >&2
                       echo "  It declares the scan roots and areas this migration works from;" >&2
                       echo "  guessing them would move files the grammar does not govern." >&2; exit 2; }

SCAN_ROOTS="$(awk '/^```scan-roots$/{f=1;next} f&&/^```/{f=0} f' "$GRAMMAR" | grep -E '.')"

# ONE EXTRACTOR FOR BOTH FILES. Core's grammar and the consumer's declaration carry the same
# `areas:` block in the same shape, and two copies of this awk is how they start disagreeing
# about what an area is -- the fork this repo has already paid for in three other pairs.
areas_of() { awk '/^areas:$/{f=1;next} f&&/^[^ ]/{f=0} f&&/^  [^ ]/{gsub(/^  /,"");print}' "$1"; }

DECLARED_AREAS="$(areas_of "$GRAMMAR")"

# --- THE CONSUMER'S OWN AREAS ARE READ, NOT ONLY POINTED AT -------------------------------
#
# Core prescribes the grammar; the CONSUMER declares its own areas, in the file named by
# `consumer_artifact_paths_file:` in `layer-contract.yaml` (grammar, line 4). This script read
# only core's list, so every consumer-specific area was "undeclared" no matter what the consumer
# had written, and the report told the operator to fix **the grammar** — a core file, overwritten
# on the next pull, and the wrong home by core's own rule. `CLAUDE.md`'s opening warning is about
# exactly this pair of files.
#
# MEASURED, and it is the reason this is a code change and not a wording change: on the reference
# consumer the migration inferred NINE areas and reported them; that consumer's
# `.claude/skills/ai-dlc/artifact-paths.md` was byte-identical to the scaffolded template, so
# nothing had ever been declared there — and declaring it would have changed nothing, because
# nothing read it. A remedy pointing at a file no reader consults is the inert-mechanism class,
# and a corrected sentence in front of an inert mechanism is worse than the wrong sentence: it
# reads as done.
#
# So the consumer's areas JOIN core's. Declaring an area is now the act that stops it being
# inferred, which is what makes the report's instruction followable.
#
# PATH DERIVED FROM THE CONTRACT, never restated. The literal lives once, in
# `layer-contract.yaml`; a second copy here is the drift I67/I70/I73 exist to prevent.
CONTRACT=""
for c in ".claude/skills/ai-dlc/layer-contract.yaml" "core/skills/ai-dlc/layer-contract.yaml"; do
  [ -f "$c" ] && CONTRACT="$c" && break
done
CONSUMER_AREAS_FILE=""
if [ -n "$CONTRACT" ]; then
  CONSUMER_AREAS_REL="$(sed -n 's/^consumer_artifact_paths_file:[[:space:]]*//p' "$CONTRACT" \
                        | head -1 | sed 's/[[:space:]]*$//' | tr -d '"')"
  [ -n "$CONSUMER_AREAS_REL" ] && [ -f "$CONSUMER_AREAS_REL" ] && CONSUMER_AREAS_FILE="$CONSUMER_AREAS_REL"
fi
CONSUMER_AREAS=""
[ -n "$CONSUMER_AREAS_FILE" ] && CONSUMER_AREAS="$(areas_of "$CONSUMER_AREAS_FILE")"
if [ -n "$CONSUMER_AREAS" ]; then
  DECLARED_AREAS="$(printf '%s\n%s\n' "$DECLARED_AREAS" "$CONSUMER_AREAS" | grep -E '.' | sort -u)"
fi
# Where the report sends the operator. Falls back to the contract's declared path even when the
# file does not exist yet, because "go write this file" is the correct remedy then; only a
# missing CONTRACT leaves it unnamed, and that is a broken install, not a paperwork gap.
REMEDY_FILE="${CONSUMER_AREAS_FILE:-${CONSUMER_AREAS_REL:-}}"
[ -n "$SCAN_ROOTS" ] || { echo "$PROG: extracted ZERO scan roots from $GRAMMAR. An empty root set" >&2
                          echo "  would report a fully-conforming tree without reading one file." >&2; exit 2; }
[ -n "$DECLARED_AREAS" ] || { echo "$PROG: extracted ZERO areas from $GRAMMAR. Without them every" >&2
                              echo "  area would be inferred and the report would say nothing." >&2; exit 2; }

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

TOKEN_RE='(^|-)(s|S|sprint-)[0-9]+($|[-.])'

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

# --- build the plan -----------------------------------------------------------
TMP="$(mktemp -d "${TMPDIR:-/tmp}/apmig-XXXXXX")" || exit 2
trap 'rm -rf "$TMP"' EXIT
PLAN="$TMP/plan"; REFUSE="$TMP/refuse"; INFERRED="$TMP/inferred"
: > "$PLAN"; : > "$REFUSE"; : > "$INFERRED"

SCANNED=0
DEFERRED_STORIES=0
while IFS= read -r src; do
  [ -n "$src" ] || continue
  SCANNED=$((SCANNED + 1))

  # THE SPRINT IS ONE FACT ABOUT THE FILE. Read it from every component at once, so a path whose
  # directory and basename disagree is refused rather than silently resolved by whichever the
  # code happened to look at first.
  # THE STORY CORPUS IS DEFERRED, EXPLICITLY, and leaving it in would half-migrate it. The
  # sprint appears in two spellings there: `story-S298-1-slug.md` carries a token this
  # transform matches, while `story-297-1-slug.md` uses a BARE number, which rule 1 forbids
  # but which is indistinguishable from `story-<index>-<slug>` -- the very form the grammar
  # prescribes. So a run that took this directory would move the capital-S files and leave
  # their lowercase siblings, splitting one sprint's stories across two conventions. Moving
  # the directory needs `stories_dir` (a SCHEMA declaration three shipped readers restate)
  # and a re-derived story-id join; that is its own release, and this reports rather than
  # half-does it.
  case "$src" in
    */stories/*) DEFERRED_STORIES=$((DEFERRED_STORIES + 1)); continue ;;
  esac

  hits="$(sprints_in "$src")"
  nhits="$(printf '%s\n' "$hits" | grep -c .)"
  [ "$nhits" -eq 0 ] && continue
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
  # longer prefixes the source path.
  rel="${src#"$src_area_prefix"/}"
  # `_bmad-output/` root: not an area. Its sprint-tokened files are log rotation archives.
  if [ "$area" = "_bmad-output" ]; then
    area="$ARCHIVE_HOME"
    rel="${src##*/}"
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

if [ "$DEFERRED_STORIES" -gt 0 ]; then
  echo "DEFERRED — $DEFERRED_STORIES file(s) under a stories/ directory were NOT considered."
  echo "  The sprint is spelled two ways there and one of them is a bare number this transform"
  echo "  cannot tell from a story index, so migrating would split one sprint's stories across"
  echo "  two conventions. The stories move is a separate release; they stay non-conforming"
  echo "  until it lands, and that is a KNOWN gap rather than a silent one."
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
