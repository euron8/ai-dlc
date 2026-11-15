#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
# transient-ignore-block/run.sh — prove sync-transient-ignore.sh renders the declared transient
# paths into a consumer's .gitignore, edits ONLY the region between its markers, and refuses to
# write rather than guessing when the declaration is unusable.
#
# WHY THIS EXISTS. The distribution shipped no ignore rule at all, and the reference consumer
# had committed 138 files of per-run pipeline state across three paths before anyone looked.
# The fix is a rendered region driven by schemas/pipeline-state-paths.json. A rendered region
# has two failure modes and this fixture is aimed at both: it can render the WRONG SET, and --
# far worse, because a .gitignore is somebody else's file -- its edit can take rules the
# consumer wrote. The second one is silent. Nothing reports a .gitignore that got shorter.
#
# EVERY EXPECTED PATTERN IS DERIVED FROM THE DECLARATION, never listed here. A fixture that
# restated the thirteen patterns would pass while the declaration and the renderer drifted
# together away from it, and would need editing on every future classification -- which is the
# hand-written list this whole release replaces, reintroduced one layer down.
set -uo pipefail


# The gate inherits every AI_DLC_* tunable a consumer set in settings.json. A fixture that
# drives a script while inheriting them tests the CONFIG, not the code (I10). The renderer
# reads AI_DLC_STATE_PATHS_SCHEMA, so this scrub is load-bearing here rather than habitual --
# and the arms below set it explicitly for exactly that reason.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"

# WALK UP FROM THIS FILE FOR THE SUBJECT ITSELF, in either layout, and never for `VERSION`.
# Two separate reasons and both have bitten this repo. Counting `..` hops answers differently
# from core/fixtures/<name>/ upstream and tests/fixtures/<name>/ in a consumer, silently. And
# VERSION is a content-key EXCLUDED path: a fixture that READS one can change behaviour without
# the pre-push suite ever re-running, because the skip key does not hash it (I55).
#
# install.sh SPLITS what shares a parent here -- core/scripts/ lands at scripts/ai-dlc/ and
# core/schemas/ at .claude/schemas/ -- so each candidate names its own pair rather than deriving
# one from the other, which is the parent-sharing assumption I33 fails the build on.
#
# A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECT: it reaches a consumer on one pull and the code it
# guards may land on the next, so an absent subject reports SKIP rather than the green line that
# would read as "checked, and fine".
SUBJECT=""; SCHEMA=""; ROOT=""
d="$HERE"
while [ "$d" != "/" ]; do
  if [ -f "$d/core/scripts/sync-transient-ignore.sh" ]; then
    ROOT="$d"; SUBJECT="$d/core/scripts/sync-transient-ignore.sh"
    [ -f "$d/core/schemas/pipeline-state-paths.json" ] && SCHEMA="$d/core/schemas/pipeline-state-paths.json"
    break
  elif [ -f "$d/scripts/ai-dlc/sync-transient-ignore.sh" ]; then
    ROOT="$d"; SUBJECT="$d/scripts/ai-dlc/sync-transient-ignore.sh"
    [ -f "$d/.claude/schemas/pipeline-state-paths.json" ] && SCHEMA="$d/.claude/schemas/pipeline-state-paths.json"
    break
  fi
  d="$(dirname "$d")"
done

echo "transient-ignore-block"
if [ -z "$SUBJECT" ] || [ -z "$SCHEMA" ]; then
  echo "  skip  sync-transient-ignore.sh / pipeline-state-paths.json not present in this tree (subject='${SUBJECT:-none}' schema='${SCHEMA:-none}')"
  echo "  0 failed, 1 skipped"
  exit 0
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "  FIXTURE BROKEN: jq is absent, so the expected pattern set cannot be derived from the declaration"
  echo "  0 failed, 1 broken"
  exit 2
fi
# PRINT THE RESOLVED PATH. A different copy than the one the run loads would leave every arm
# green, which reads exactly like an arm that cannot fire.
echo "  subject: ${SUBJECT#"$ROOT"/}"
# The REQUIRED inputs of inputs.decl: the renderer and its declaration are resolved and about to be driven.
echo "HERMETIC-CONSUMED core/scripts/sync-transient-ignore.sh"
echo "HERMETIC-CONSUMED core/schemas/pipeline-state-paths.json"

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }

BEGIN="$(jq -r '.block_begin' "$SCHEMA")"
END="$(jq -r '.block_end' "$SCHEMA")"
TRANSIENT="$(jq -r '.paths[] | select(.transient) | .ignore' "$SCHEMA")"
DURABLE_NAMES="$(jq -r '.paths[] | select(.transient | not) | .name' "$SCHEMA")"
ROOT_DIR="$(jq -r '.root' "$SCHEMA")"
# BL-685: the declared OUT-OF-ROOT patterns, derived like TRANSIENT and kept SEPARATE from it so
# arm 1 and arm 10 own different halves of the block.
OUT_OF_ROOT="$(jq -r '.out_of_root[]? | .pattern' "$SCHEMA")"

# The seed must be able to express the defect. A declaration with nothing transient in it, or
# with no durable half, makes several arms below vacuously true.
if [ -z "$TRANSIENT" ] || [ -z "$DURABLE_NAMES" ] || [ -z "$OUT_OF_ROOT" ] || [ -z "$BEGIN" ] || [ -z "$END" ]; then
  echo "  FIXTURE BROKEN: the declaration yields transient=$(printf '%s' "$TRANSIENT" | grep -c .) out_of_root=$(printf '%s' "$OUT_OF_ROOT" | grep -c .) durable=$(printf '%s' "$DURABLE_NAMES" | grep -c .) markers='${BEGIN:0:12}'/'${END:0:12}' — the arms below cannot discriminate" >&2
  exit 2
fi

WORLDS="$(mktemp -d)"
trap 'rm -rf "$WORLDS"' EXIT
# fresh_project -> a seeded scratch project, echoed. Each arm gets its own so no arm reads
# state another left behind.
fresh_project() {
  local w
  w="$(bash "$HERE/seed.sh")" || return 1
  printf '%s\n' "$w"
}

# render <subject> <work> [extra args...] -> run the renderer against that project.
render() {
  local subj="$1" w="$2"; shift 2
  AI_DLC_STATE_PATHS_SCHEMA="$SCHEMA" bash "$subj" --root "$w/project" "$@" 2>&1
}

block_of() { # <gitignore> -> the marker-bounded block, or nothing
  awk -v b="$BEGIN" -v e="$END" '
    $0 == b { inb = 1 }
    inb == 1 { print }
    inb == 1 && $0 == e { inb = 0; exit }
  ' "$1"
}

# ---------------------------------------------------------------------------------------
# The arms, as functions returning 0 when the property HOLDS. Every one is PRESENCE-shaped --
# each demands a specific line APPEAR -- so a subject replaced by `exit 0` fails them by
# construction rather than passing as a clean run.
# ---------------------------------------------------------------------------------------

# Arm 1: every declared transient pattern is rendered, inside the markers.
arm_renders_declared_set() {
  local w="$1" subj="$2" blk pat
  blk="$(block_of "$w/project/.gitignore")"
  [ -n "$blk" ] || return 1
  # NEVER FEED `grep -q` FROM A PIPE. It leaves at its first match while the writer is still
  # pushing, so under pipefail the pipeline answers with the writer's EPIPE and reports
  # NOT-FOUND on input that contains the pattern -- a size threshold, not a race (I54/I54b).
  grep -qxF -- "$BEGIN" <<<"$blk" || return 1
  grep -qxF -- "$END" <<<"$blk" || return 1
  while IFS= read -r pat; do
    [ -n "$pat" ] || continue
    grep -qxF -- "$pat" <<<"$blk" || return 1
  done <<EOF
$TRANSIENT
EOF
  return 0
}

# Arm 2: no DURABLE path reaches the block. The partition's other half, and the direction that
# would silently ignore a consumer's committed pipeline artifacts.
arm_excludes_durable() {
  local w="$1" subj="$2" blk nm
  blk="$(block_of "$w/project/.gitignore")"
  [ -n "$blk" ] || return 1
  while IFS= read -r nm; do
    [ -n "$nm" ] || continue
    grep -qxF -- "$ROOT_DIR/$nm" <<<"$blk" && return 1
  done <<EOF
$DURABLE_NAMES
EOF
  return 0
}

# Arm 3: the cut is bounded at BOTH ends. A rule written after the block survives a re-render.
# This is the arm the whole marker pair exists for, and the failure it guards is silent.
arm_cut_is_bounded() {
  local w="$1" subj="$2"
  printf 'a-rule-the-consumer-added-later/\n' >> "$w/project/.gitignore"
  render "$subj" "$w" >/dev/null || return 1
  grep -qxF -- 'a-rule-the-consumer-added-later/' "$w/project/.gitignore" || return 1
  # And the rules that were there BEFORE the block are still there too.
  grep -qxF -- 'node_modules/' "$w/project/.gitignore" || return 1
  grep -qxF -- '.env' "$w/project/.gitignore" || return 1
  return 0
}

# Arm 4: idempotent. The shared first render plus two more leave exactly one block and one copy of each pattern.
arm_idempotent() {
  local w="$1" subj="$2" n pat
  for _ in 1 2; do render "$subj" "$w" >/dev/null || return 1; done
  n="$(grep -cxF -- "$BEGIN" "$w/project/.gitignore")"; [ "$n" -eq 1 ] || return 1
  n="$(grep -cxF -- "$END" "$w/project/.gitignore")";   [ "$n" -eq 1 ] || return 1
  while IFS= read -r pat; do
    [ -n "$pat" ] || continue
    n="$(grep -cxF -- "$pat" "$w/project/.gitignore")"
    [ "$n" -eq 1 ] || return 1
  done <<EOF
$TRANSIENT
EOF
  return 0
}

# Arm 5: --check discriminates. It passes on a freshly rendered block and FAILS on a stale one,
# and both directions are asserted -- a --check that always passed would satisfy one of them.
arm_check_discriminates() {
  local w="$1" subj="$2" rc_fresh rc_stale first
  render "$subj" "$w" --check >/dev/null; rc_fresh=$?
  first="$(printf '%s\n' "$TRANSIENT" | sed -n 1p)"
  # Edit the rendered region, leaving the markers in place: the stale case is a block that is
  # PRESENT and WRONG, which a presence-only check would call current.
  sed -i.bak "s#^$(printf '%s' "$first" | sed 's/[.[\*^$/]/\\&/g')\$#${first}-STALE#" "$w/project/.gitignore"
  rm -f "$w/project/.gitignore.bak"
  render "$subj" "$w" --check >/dev/null 2>&1; rc_stale=$?
  [ "$rc_fresh" -eq 0 ] && [ "$rc_stale" -ne 0 ]
}

# Arm 6: fail closed on an unusable declaration, and leave the file BYTE-IDENTICAL. An empty
# begin marker makes the cut match blank lines, so "refuses to write" and "wrote a truncated
# .gitignore" are the two outcomes here and only a byte compare tells them apart.
arm_fails_closed_on_empty_marker() {
  local w="$1" subj="$2" before after rc
  jq '.block_begin = ""' "$SCHEMA" > "$w/broken.json" || return 1
  before="$(md5 -q "$w/project/.gitignore" 2>/dev/null || md5sum "$w/project/.gitignore" | cut -d' ' -f1)"
  AI_DLC_STATE_PATHS_SCHEMA="$w/broken.json" bash "$subj" --root "$w/project" >/dev/null 2>&1
  rc=$?
  after="$(md5 -q "$w/project/.gitignore" 2>/dev/null || md5sum "$w/project/.gitignore" | cut -d' ' -f1)"
  [ "$rc" -ne 0 ] && [ "$before" = "$after" ]
}

# Arm 7: a transient path that is ALREADY TRACKED is NAMED. An ignore rule does nothing to a
# tracked file, so a renderer that only wrote the rule would report success over the exact
# state that motivated this release.
arm_names_tracked_paths() {
  local w="$1" subj="$2" pat dir out
  pat="$(printf '%s\n' "$TRANSIENT" | grep '/$' | sed -n 1p)"
  [ -n "$pat" ] || return 1
  dir="$w/project/${pat%/}"
  mkdir -p "$dir" && printf '6\n' > "$dir/seeded-beat"
  git -C "$w/project" add -f "${pat%/}/seeded-beat" >/dev/null 2>&1 || return 1
  git -C "$w/project" commit -qm tracked >/dev/null 2>&1 || return 1
  out="$(render "$subj" "$w")"
  grep -q 'still TRACKED' <<<"$out" || return 1
  grep -qF -- "$pat" <<<"$out" || return 1
  return 0
}

# Arm 8: `--check` ANSWERS ONLY THE BLOCK, AND A CALLER MUST NOT READ IT AS THE WHOLE SUBJECT.
#
# The arm above proves the WRITE path names an already-tracked transient path. This one pins the
# other half of that same property: `--check` does NOT, and cannot, because it returns at the
# block comparison while the tracked scan sits below on the write path. The state that
# discriminates is a block that is CURRENT and a declared transient path that is TRACKED -- there
# `--check` exits 0 saying "current" while the ignore rule is doing nothing whatever about the
# file git already holds.
#
# THIS IS A CONTRACT ARM, NOT A DEFECT ARM. It is not asking the renderer to change: `--check`
# is documented to report on the block and to never write, and widening it to mutate or to scan
# the index would break the property that makes it safe to call from a gate. The arm exists so
# that a caller which reads `--check` as "the transient state is clean" is refuted HERE, by a
# seeded world, rather than on a consumer whose committed marker keeps re-arming a guard.
# `apply.sh`'s transient_ignore_row() asks the consumer's index directly for exactly this reason.
#
# SEEDED WITH A NON-FIRST MEMBER on purpose. A seed that tracked the first declared pattern could
# not tell "scanned the declared set" from "looked at its first entry".
arm_check_is_blind_to_tracked() {
  local w="$1" subj="$2" pat rc_check tracked out_check out_write
  # A FILE pattern, and deliberately not the first one in the declared set.
  pat="$(printf '%s\n' "$TRANSIENT" | grep -v '/$' | sed -n 2p)"
  [ -n "$pat" ] || return 1
  mkdir -p "$(dirname "$w/project/$pat")" || return 1
  : > "$w/project/$pat"
  git -C "$w/project" add -f "$pat" >/dev/null 2>&1 || return 1
  git -C "$w/project" commit -qm tracked-transient >/dev/null 2>&1 || return 1
  # PRESENCE-SHAPED, AND THAT IS WHAT MAKES THIS ARM NON-VACUOUS. An earlier cut asserted only
  # that `--check` exits 0 over the tracked path -- which a subject whose check branch has been
  # deleted ALSO does, because it then re-renders an already-current block and exits 0 too. The
  # discriminating observables are what `--check` must PRINT and must NOT print: it reports the
  # block is current, and it never names the tracked path.
  out_check="$(render "$subj" "$w" --check)"; rc_check=$?
  [ "$rc_check" -eq 0 ] || return 1
  grep -q 'transient-state block current' <<<"$out_check" || return 1
  grep -q 'still TRACKED' <<<"$out_check" && return 1
  # That --check wrote nothing is check_discriminates's property; this arm owns only what --check
  # REPORTS about a tracked path.
  # The path must genuinely still be tracked in the same invocation, which is the control that
  # makes the clean report above a BLINDNESS rather than a correct all-clear.
  tracked="$(git -C "$w/project" ls-files -- "$pat" | wc -l | tr -d ' ')"
  [ "${tracked:-0}" -ge 1 ] || return 1
  # And the WRITE path DOES see it -- the two halves of the contract, one property apart.
  #
  # VIA A COMMAND SUBSTITUTION AND A HERE-STRING, NEVER A PIPE. `render | grep -q` is I54: grep
  # leaves at its first match while the renderer is still writing, the renderer takes EPIPE, and
  # under this file's `pipefail` the pipeline answers NOT-FOUND on output that DOES contain the
  # string. It cost this arm a false FAIL on the correct subject, four lines below the comment in
  # arm 1 that says so.
  out_write="$(render "$subj" "$w")"
  grep -q 'still TRACKED' <<<"$out_write" || return 1
  return 0
}

# Arm 9 (BL-329): IN THE CONSUMER LAYOUT, a `--root` naming a directory with no declaration of
# its own falls back to the INSTALL's. The subject is copied to scripts/ai-dlc/ of a
# consumer-shaped tree whose declaration sits only at .claude/schemas/ -- so the script-relative
# candidate, scripts/schemas/, does not exist -- and driven with NO env pin, from a subdirectory,
# against a foreign root holding only a .gitignore. Presence-shaped: the run must get past the
# schema and REPORT the block missing (exit 1 naming it), never exit 2 "not found". The NEAR-MISS
# is the same tree with `--root` naming the consumer itself, whose own .claude/schemas/ wins: it
# must pass --check once written, which a fallback that outranked the root could not tell apart.
arm_install_fallback() {
  local w="$1" subj="$2" c="$1/consumer" f="$1/foreign" out rc
  # A REAL repository, not a bare `.git` directory: any git call the subject makes against the
  # consumer (M4 adds one to --check) must not die on "not a git repository" and entangle this arm.
  mkdir -p "$c/.claude/schemas" "$c/scripts/ai-dlc" "$c/docs" "$f" || return 1
  git init -q "$c" || return 1
  cp "$SCHEMA" "$c/.claude/schemas/pipeline-state-paths.json" || return 1
  cp "$subj" "$c/scripts/ai-dlc/sync-transient-ignore.sh" || return 1
  [ ! -e "$c/scripts/schemas" ] || return 1
  printf 'node_modules/\n' > "$f/.gitignore"
  out="$( cd "$c/docs" && bash "$c/scripts/ai-dlc/sync-transient-ignore.sh" --check --root "$f" 2>&1 )"; rc=$?
  [ "$rc" -eq 1 ] || return 1
  grep -q 'not found' <<<"$out" && return 1
  grep -qF -- "$f" <<<"$out" || return 1
  # Near-miss: the consumer's own declaration, written then checked.
  printf 'node_modules/\n' > "$c/.gitignore"
  ( cd "$c/docs" && bash "$c/scripts/ai-dlc/sync-transient-ignore.sh" --root "$c" ) >/dev/null 2>&1 || return 1
  out="$( cd "$c/docs" && bash "$c/scripts/ai-dlc/sync-transient-ignore.sh" --check --root "$c" 2>&1 )" || return 1
  grep -q 'transient-state block current' <<<"$out" || return 1
  return 0
}

# Arm 10 (BL-685): every declared OUT-OF-ROOT pattern is rendered inside the markers. Presence-
# shaped, and over a set disjoint from arm 1's, so a renderer that drops the out_of_root half
# fails this arm alone. The pattern must sit BETWEEN the markers, never merely in the file.
arm_renders_out_of_root() {
  local w="$1" subj="$2" blk pat
  blk="$(block_of "$w/project/.gitignore")"
  [ -n "$blk" ] || return 1
  while IFS= read -r pat; do
    [ -n "$pat" ] || continue
    grep -qxF -- "$pat" <<<"$blk" || return 1
  done <<EOF
$OUT_OF_ROOT
EOF
  return 0
}

run_arms() { # <subject> -> prints "<name>:<0|1>" per arm, each on its own project
  local subj="$1" name w w0 rc base_rc arms
  shift
  arms="${*:-renders_declared_set excludes_durable cut_is_bounded idempotent check_discriminates fails_closed_on_empty_marker names_tracked_paths check_is_blind_to_tracked install_fallback renders_out_of_root}"
  # ONE seed and ONE render per subject; every arm gets a cp -R copy of that rendered world, so no
  # arm reads state another left behind. An arm that formerly rendered first could only fail on a
  # failed first render, which base_rc now reports for all of them.
  # exit inside $( ) would end only the subshell, so a failed seed is reported as every arm failing.
  if w0="$(fresh_project)"; then render "$subj" "$w0" >/dev/null 2>&1; base_rc=$?; else base_rc=99; w0="$WORLDS"; fi
  for name in $arms; do
    # Arms 1, 2 and 10 only READ the rendered block, so they share the one render with no copy;
    # every other arm writes into its world and gets its own cp -R.
    case "$name" in
      renders_declared_set|excludes_durable|renders_out_of_root) w="$w0" ;;
      *) w="$(mktemp -d "$WORLDS/w.XXXXXX")" && cp -R "$w0/." "$w" || { printf '%s:1\n' "$name"; continue; } ;;
    esac
    if [ "$base_rc" -ne 0 ]; then rc=1
    else "arm_$name" "$w" "$subj" >/dev/null 2>&1 && rc=0 || rc=1; fi
    printf '%s:%s\n' "$name" "$rc"
  done
}

# ---------------------------------------------------------------------------------------
# Live subject
# ---------------------------------------------------------------------------------------
LIVE="$(run_arms "$SUBJECT")"
while IFS=: read -r name rc; do
  [ -n "$name" ] || continue
  case "$name" in
    renders_declared_set)  msg="every declared transient pattern is rendered inside the markers ($(printf '%s\n' "$TRANSIENT" | grep -c .) path(s))" ;;
    excludes_durable)      msg="no durable path reaches the block ($(printf '%s\n' "$DURABLE_NAMES" | grep -c .) checked)" ;;
    cut_is_bounded)        msg="the cut is bounded at both ends — rules before and after the block survive" ;;
    idempotent)            msg="repeated renders leave exactly one block and one copy of each pattern" ;;
    check_discriminates)   msg="--check passes on a current block and fails on a present-but-stale one" ;;
    fails_closed_on_empty_marker) msg="an empty block marker is refused and .gitignore is left byte-identical" ;;
    names_tracked_paths)   msg="an already-tracked transient path is named, not silently ignored" ;;
    check_is_blind_to_tracked) msg="--check reports the BLOCK only: it exits 0 over a tracked transient path, which the write path names" ;;
    install_fallback)      msg="consumer layout: --root naming a tree with no declaration falls back to the install's (exit 1 on the block, not 2), and a root with its own still wins" ;;
    renders_out_of_root)   msg="every declared out-of-root pattern is rendered inside the markers ($(printf '%s\n' "$OUT_OF_ROOT" | grep -c .) path(s))" ;;
    *)                     msg="$name" ;;
  esac
  if [ "$rc" -eq 0 ]; then ok "$msg"; else bad "$msg"; fi
done <<EOF
$LIVE
EOF


echo "  $fails failed"
report_end transient-ignore-block
