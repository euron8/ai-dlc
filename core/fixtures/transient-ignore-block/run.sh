#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
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
  echo "  skip  jq is absent, so the expected pattern set cannot be derived from the declaration"
  echo "  0 failed, 1 skipped"
  exit 0
fi
# PRINT THE RESOLVED PATH. A mutant applied to the copy the run never loads leaves every arm
# green, which reads exactly like an arm that cannot fire.
echo "  subject: ${SUBJECT#"$ROOT"/}"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

BEGIN="$(jq -r '.block_begin' "$SCHEMA")"
END="$(jq -r '.block_end' "$SCHEMA")"
TRANSIENT="$(jq -r '.paths[] | select(.transient) | .ignore' "$SCHEMA")"
DURABLE_NAMES="$(jq -r '.paths[] | select(.transient | not) | .name' "$SCHEMA")"
ROOT_DIR="$(jq -r '.root' "$SCHEMA")"

# The seed must be able to express the defect. A declaration with nothing transient in it, or
# with no durable half, makes several arms below vacuously true.
if [ -z "$TRANSIENT" ] || [ -z "$DURABLE_NAMES" ] || [ -z "$BEGIN" ] || [ -z "$END" ]; then
  echo "  FIXTURE BROKEN: the declaration yields transient=$(printf '%s' "$TRANSIENT" | grep -c .) durable=$(printf '%s' "$DURABLE_NAMES" | grep -c .) markers='${BEGIN:0:12}'/'${END:0:12}' — the arms below cannot discriminate" >&2
  exit 2
fi

# fresh_project -> a seeded scratch project, echoed. Each arm gets its own so a mutation in one
# cannot be read through state another left behind.
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
  render "$subj" "$w" >/dev/null || return 1
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
  render "$subj" "$w" >/dev/null || return 1
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
  render "$subj" "$w" >/dev/null || return 1
  printf 'a-rule-the-consumer-added-later/\n' >> "$w/project/.gitignore"
  render "$subj" "$w" >/dev/null || return 1
  grep -qxF -- 'a-rule-the-consumer-added-later/' "$w/project/.gitignore" || return 1
  # And the rules that were there BEFORE the block are still there too.
  grep -qxF -- 'node_modules/' "$w/project/.gitignore" || return 1
  grep -qxF -- '.env' "$w/project/.gitignore" || return 1
  return 0
}

# Arm 4: idempotent. Four renders leave exactly one block and one copy of each pattern.
arm_idempotent() {
  local w="$1" subj="$2" n pat
  for _ in 1 2 3 4; do render "$subj" "$w" >/dev/null || return 1; done
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
  render "$subj" "$w" >/dev/null || return 1
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
  render "$subj" "$w" >/dev/null || return 1
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
  local w="$1" subj="$2" pat rc_check tracked out_check out_write before
  render "$subj" "$w" >/dev/null || return 1
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
  # block is current, and it never names the tracked path. Its mutant is what established this.
  # `cmp -s` AGAINST A SAVED COPY, NOT `md5 -q`. The first cut used md5, which is absent under the
  # scrubbed `PATH` a shipped script must hold for -- `command -v md5` is MISSING under
  # `env -i PATH=/usr/bin:/bin` -- so `before` came back EMPTY and the arm failed on the
  # unmutated subject. `cmp` is what the rest of this suite uses for the same question.
  before="$w/gitignore.before"
  cp "$w/project/.gitignore" "$before" || return 1
  out_check="$(render "$subj" "$w" --check)"; rc_check=$?
  [ "$rc_check" -eq 0 ] || return 1
  grep -q 'transient-state block current' <<<"$out_check" || return 1
  grep -q 'still TRACKED' <<<"$out_check" && return 1
  # "IT WROTE NOTHING" IS `check_discriminates`'s PROPERTY, NOT THIS ARM'S, AND ASSERTING IT HERE
  # ENTANGLED THE TWO. A `cmp` of .gitignore across the --check made both arms fail the same
  # mutant, which the harness reports as entanglement and is right to: two arms failing together
  # cannot tell you which one is load-bearing. This arm owns exactly one property -- what --check
  # REPORTS about a tracked path -- and stands down on the write question. The saved copy is kept
  # only to make the seeded world reproducible for a reader.
  :
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

run_arms() { # <subject> -> prints "<name>:<0|1>" per arm, each on its own project
  local subj="$1" name w rc
  for name in renders_declared_set excludes_durable cut_is_bounded idempotent \
              check_discriminates fails_closed_on_empty_marker names_tracked_paths \
              check_is_blind_to_tracked; do
    w="$(fresh_project)" || { printf '%s:1\n' "$name"; continue; }
    "arm_$name" "$w" "$subj" >/dev/null 2>&1 && rc=0 || rc=1
    rm -rf "$w"
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
    idempotent)            msg="four renders leave exactly one block and one copy of each pattern" ;;
    check_discriminates)   msg="--check passes on a current block and fails on a present-but-stale one" ;;
    fails_closed_on_empty_marker) msg="an empty block marker is refused and .gitignore is left byte-identical" ;;
    names_tracked_paths)   msg="an already-tracked transient path is named, not silently ignored" ;;
    check_is_blind_to_tracked) msg="--check reports the BLOCK only: it exits 0 over a tracked transient path, which the write path names" ;;
    *)                     msg="$name" ;;
  esac
  [ "$rc" -eq 0 ] && ok "$msg" || bad "$msg"
done <<EOF
$LIVE
EOF

# ---------------------------------------------------------------------------------------
# MUTANTS. Each is a COPY -- never an in-place edit of the shipped file -- guarded with `cmp -s`
# so a sed that matched nothing cannot pass as a mutation. Each names the ONE arm it must move;
# a mutant that moves a second arm means those two arms are entangled and one is vacuous.
# ---------------------------------------------------------------------------------------
MUTDIR="$(mktemp -d)"
trap 'rm -rf "$MUTDIR"' EXIT
kills=0

mutate() { # <label> <sed-expr> <arm-that-must-fail>
  local label="$1" expr="$2" want="$3"
  # `copy` is declared on its own line, NOT in the `local` above: bash 3.2 under `set -u`
  # rejects a reference to a variable being declared in the same `local` statement.
  local copy="$MUTDIR/$label.sh"
  local out rc others
  cp "$SUBJECT" "$copy"
  sed -e "$expr" "$SUBJECT" > "$copy.new" && mv "$copy.new" "$copy"
  if cmp -s "$SUBJECT" "$copy"; then
    bad "MUTANT $label: the sed matched NOTHING, so the subject was never mutated and this kill would have been fictional"
    return
  fi
  chmod +x "$copy"
  out="$(run_arms "$copy")"
  rc="$(printf '%s\n' "$out" | sed -n "s/^${want}://p")"
  if [ "$rc" = "1" ]; then
    kills=$((kills+1))
    # A mutant must fail ONLY its own assertion.
    others="$(printf '%s\n' "$out" | grep ':1$' | grep -v "^${want}:" | cut -d: -f1 | tr '\n' ' ')"
    if [ -n "${others// /}" ]; then
      bad "MUTANT $label killed by $want AND by: $others — those arms are entangled and at least one is not independently load-bearing"
    else
      ok "MUTANT $label killed by $want, and by that arm alone"
    fi
  else
    bad "MUTANT $label SURVIVED: $want still passes against a subject that no longer does the thing that arm asserts"
  fi
}

# M1: the cut never resets, so it runs from the begin marker to EOF and eats everything after
# the block. Anchored on the END-marker clause, which is the line that SEPARATES this arm of
# the awk from the one above it -- keying on the shared `skip` text would edit both.
mutate cut-runs-to-eof 's/skip == 1 && \$0 == e { skip = 0; next }//' cut_is_bounded

# M2: render the whole declaration rather than its transient half, so the block carries ignore
# rules for artifacts the consumer commits.
#
# THE OBVIOUS MUTATION HERE IS INERT AND THIS FIXTURE CAUGHT IT. Deleting only
# `select(.transient)` leaves `.ignore // empty`, and a durable entry HAS no ignore field, so
# the filter that remains drops exactly the entries the mutation was meant to admit: `cmp`
# reports a changed file and the output is byte-identical. The mutation therefore has to
# SYNTHESISE a pattern for the durable half, which it does under the declared root rather than
# a literal one -- a hard-coded root here would stop matching the arm the day the declaration
# moved, and the mutant would survive for a reason that has nothing to do with the subject.
mutate renders-durable-too 's#\.paths\[\] | select(\.transient) | \.ignore // empty#. as $d | $d.paths[] | (.ignore // ($d.root + "/" + .name))#' excludes_durable

# M3: drop the empty-marker guard, so an unusable declaration is used anyway.
mutate no-empty-marker-guard 's/if \[ -z "\$IG_BEGIN" \] || \[ -z "\$IG_END" \]; then/if false; then/' fails_closed_on_empty_marker

# M4: make `--check` REPORT a tracked transient path while still exiting 0 and still writing
# nothing. That is the widening arm 8's contract forbids, and it is the shape a later hand
# reaches for on being told "--check cannot see a tracked path": add the scan to the check branch
# because it looks like free information.
#
# THE FIRST SPELLING OF THIS MUTANT WAS `if false; then` ON THE MODE BRANCH, AND IT BELONGED TO A
# DIFFERENT ARM. Disabling the branch makes --check fall through and RE-RENDER, which turns a
# stale block current -- exactly `check_discriminates`'s subject -- so both arms failed it and the
# harness reported entanglement, correctly. A mutant that two arms kill cannot say which one is
# load-bearing. This spelling leaves the mode branch intact and moves only the one observable arm
# 8 owns: what --check PRINTS about the index.
mutate check-reports-tracked \
  's#^  echo "OK: transient-state block current#  git -C "$PROJECT_ROOT" ls-files -- $PATTERNS 2>/dev/null | sed "s/^/  NOTE: still TRACKED: /"\n  echo "OK: transient-state block current#' \
  check_is_blind_to_tracked

# UNMUTATED CONTROL, with a POSITIVE conjunct. A control asserting only "nothing went wrong"
# passes against a subject replaced by `exit 0`, because rc=0 with nothing reported is exactly
# what a clean copy looks like. This one requires a named arm to be THERE and passing.
cp "$SUBJECT" "$MUTDIR/control.sh"; chmod +x "$MUTDIR/control.sh"
CTL="$(run_arms "$MUTDIR/control.sh")"
CTL_FAILS="$(printf '%s\n' "$CTL" | grep -c ':1$')"
CTL_RENDERS="$(printf '%s\n' "$CTL" | sed -n 's/^renders_declared_set://p')"
if [ "$CTL_FAILS" -eq 0 ] && [ "$CTL_RENDERS" = "0" ]; then
  ok "CONTROL: an unmutated copy passes every arm, and renders_declared_set is affirmatively green"
else
  bad "CONTROL: an unmutated copy failed $CTL_FAILS arm(s) (renders_declared_set=$CTL_RENDERS) — the harness is what is broken, not the subject, and every kill above is suspect"
fi

# ASSERT THE KILL COUNT IS NON-ZERO. A battery whose mutants all applied to a file the run
# never loaded reports the same silence as one whose arms cannot fire.
[ "$kills" -eq 0 ] && bad "NO MUTANT WAS KILLED. Either the mutations landed in a copy nothing executes, or none of these arms is load-bearing."

echo "  $fails failed, $kills mutant(s) killed"
[ "$fails" -eq 0 ] || exit 1
exit 0
