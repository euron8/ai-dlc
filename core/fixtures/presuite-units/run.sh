#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
# presuite-units -- the distribution hook's pre-suite steps are units of the fixture mechanism: queued by `step`, keyed by
# the fixture mechanism's own readset_* functions from scripts/presuite/<slug>/inputs.decl, decided in ONE key pass and run
# CONCURRENTLY by ps_flush (BL-1091).
#
# WHAT IT DRIVES, CUT FROM THE HOOK'S BYTES. The PRESUITE_UNITS span (ps_enqueue, ps_select, ps_flush, step) and the
# FIXTURE_POOL span (the readset_* functions) are extracted from .githooks/pre-push and SOURCED in a subshell inside a
# mktemp git repo with its own root commit and verdict store; three stub steps are queued and flushed. Nothing here is a
# copy of the logic.
#
# THE ARMS. Each builds its own world, flushes twice (the first records, the second is judged), and reads which steps ran
# off a log the stub steps append to, so a step that did not run prints nothing and a skip cannot read as a run.
#   skip     nothing changed: the two keyed steps skip, the undeclared one runs
#   unrel    a file added outside every declared directory: the two keyed steps still skip
#   moved    a declared file edited: the step declaring it runs, the other keyed step skips
#   absent   a file ADDED to a declared directory (the `cells.decl` appearing under core/fixtures/<x>/ shape, which no
#            file read could see): the step declaring that directory runs, the other skips
#   conc     two undeclared steps that each read the other's token off a fifo both pass: a fifo's bytes die with its last
#            open fd, so each token read proves the two steps were live at once (ordering, not timing)
#   content  two worktrees of one repo, one path set, core/a.txt differing: after the other tree records, a tree skips on
#            its own pass (the one <slug>.key holds the other's rows), and a third content no run passed runs (BL-1058)
#   order    the steps print in declaration order, each followed by its own verdict
#   trewrite a step rewrites a declared file and puts it back by cp -p while the steps run: its pass is not
#            recorded, and the next flush runs it (BL-919: the keys were taken before the change)
#   tcreate  the same for a file created and removed in a declared directory
#   tunrel   the near-miss: a path outside the step's inputs changed the same way leaves its pass recorded
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/fixtures/lib/report.sh"
HOOK=".githooks/pre-push"
[ -f "$HOOK" ] || { echo "FIXTURE BROKEN: $HOOK not found (run from the repo root)" >&2; exit 2; }
echo "HERMETIC-CONSUMED .githooks/pre-push"
broken() { printf '  FAIL  %s\n' "$1" >&2; echo "presuite-units: FIXTURE BROKEN" >&2; exit 2; }
WORK="$(mktemp -d)" || broken "mktemp failed"
trap 'rm -rf "$WORK"' EXIT
sed -n '/^# FIXTURE_POOL_BEGIN$/,/^# FIXTURE_POOL_END$/p' "$HOOK" > "$WORK/pool.sh"
sed -n '/^# PRESUITE_UNITS_BEGIN$/,/^# PRESUITE_UNITS_END$/p' "$HOOK" > "$WORK/psu.sh"
for _s in pool psu; do [ "$(grep -c . "$WORK/$_s.sh")" -gt 20 ] || broken "the $_s span did not extract from $HOOK"; done
grep -q '^ps_flush() {$' "$WORK/psu.sh" && grep -q '^readset_keys() {' "$WORK/pool.sh" || broken "the spans do not hold ps_flush and readset_keys"

# world <dir>: a git repo with a root commit, three declared/undeclared step dirs and a few inputs.
world() {
  local w="$1"
  mkdir -p "$w/core/fixtures" "$w/core/scripts" "$w/docs" "$w/scripts/presuite/stepa" "$w/scripts/presuite/stepb" "$w/zz" || return 1
  printf 'a1\n' > "$w/core/a.txt"; : > "$w/core/scripts/x.sh"; printf 'b1\n' > "$w/docs/b.txt"
  printf 'core/\n' > "$w/scripts/presuite/stepa/inputs.decl"
  printf 'docs/\n' > "$w/scripts/presuite/stepb/inputs.decl"
  ( cd "$w" && unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY \
    && git init -q . && git -c user.email=f@x -c user.name=f add -A && git -c user.email=f@x -c user.name=f commit -qm root ) >/dev/null 2>&1
}
# flush <world> <psu span> <out> [conc]: queue the stub steps in the world and flush; the stubs log which ran to <world>.ran.
flush() {
  local w="$1" psu="$2" o="$3" mode="${4:-keyed}"
  (
    cd "$w" || exit 125
    unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY PREPUSH_POOL_DEPTH
    export AI_DLC_VERDICT_STORE="${VS:-$w.vs}" AI_DLC_FIXTURE_JOBS=4 RAN="$w.ran" W="$w" GIT_AUTHOR_NAME=f
    . "$WORK/pool.sh" > /dev/null 2>&1
    . "$psu" || exit 126
    fail=0; RED_STEPS=""; PRESUITE_DONE=0
    ps_probe() { printf '%s\n' "$1" >> "$RAN"; }
    # ps_meet <me> <other> <bound>: send my token on my fifo, then read the other's off its fifo. A fifo's bytes die with
    # its last open fd, so reading the other's token proves both steps held their fifos open AT ONCE.
    ps_meet() { local t=""; exec 3<>"$W.f.$1" 4<>"$W.f.$2" || return 1; printf '%s\n' "$1" >&3; read -r -t "$3" -u 4 t; exec 3>&- 4>&-; [ "$t" = "$2" ]; } # bl868-allow: psu-meet-bound
    # ps_flip <kind>: stepb as a step that changes a path and puts it back while the steps run; it passes only on the
    # state it made, and the tree after it is the keyed tree again (content and listing).
    ps_flip() {
      printf 'b\n' >> "$RAN"
      case "$1" in
        rewrite) cp -p docs/b.txt "$W.orig" && printf 'GOOD\n' > docs/b.txt && [ "$(cat docs/b.txt)" = GOOD ] && cp -p "$W.orig" docs/b.txt ;;
        create) printf 'GOOD\n' > docs/t.txt && [ "$(cat docs/t.txt)" = GOOD ] && rm -f docs/t.txt ;;
        unrel) printf 'GOOD\n' > zz/t.txt && [ "$(cat zz/t.txt)" = GOOD ] && rm -f zz/t.txt ;;
        *) return 1 ;;
      esac
    }
    if [ "$mode" = conc ]; then step "meet p" ps_meet p q "$MEET_BOUND"; step "meet q" ps_meet q p "$MEET_BOUND"
    elif [ "$mode" = flip ]; then step stepa ps_probe a; step stepb ps_flip "$FLIP"; step stepc ps_probe c
    else step stepa ps_probe a; step stepb ps_probe b; step stepc ps_probe c; fi
    ps_flush
    exit "$fail"
  ) > "$o" 2>&1
  echo "$?"
}
ran_of() { sort "$1.ran" 2>/dev/null | tr '\n' ' '; }  # the steps the LAST flush ran
# arm <name> <psu span> <mutate: none|unrel|moved|absent>: build a world, flush twice, print the second flush's ran set and out.
two() {
  local tag="$1" psu="$2" kind="$3" w="$WORK/$1-$3" rc1 rc2
  world "$w" || broken "could not build the $kind world"
  rc1="$(flush "$w" "$psu" "$w.out1")"
  [ "$rc1" = 0 ] && [ "$(ran_of "$w")" = "a b c " ] || { echo "first:rc=$rc1:ran=$(ran_of "$w")"; return 0; }
  : > "$w.ran"
  case "$kind" in
    none) : ;;
    unrel) printf 'x\n' > "$w/zz/new.txt" ;;
    moved) printf 'a2\n' > "$w/core/a.txt" ;;
    absent) mkdir -p "$w/core/fixtures/x" && : > "$w/core/fixtures/x/cells.decl" ;;
  esac
  rc2="$(flush "$w" "$psu" "$w.out2")"
  echo "rc=$rc2:ran=$(ran_of "$w")"
}
# conc_arm <psu> <tag>: the meet's bound only ends a pool that cannot meet; the meet returns the moment the other token
# arrives.
conc_arm() {
  local psu="$1" w="$WORK/conc-$2" rc b=120
  world "$w" || broken "could not build the conc world"
  mkfifo "$w.f.p" "$w.f.q" || broken "mkfifo failed"
  rc="$(MEET_BOUND="$b" flush "$w" "$psu" "$w.out" conc)"
  echo "rc=$rc:$(grep -c '   PASS' "$w.out")"
}
# content_arm <psu> <tag>: two worktrees of one repo share one root commit, so one keys dir; their path sets are equal and
# core/a.txt differs. A records, B records, A again must skip stepa on its own pass; then B moves to content no run
# passed, and stepa must run there.
content_arm() {
  local psu="$1" w="$WORK/content-$2" b ra rb
  world "$w" || broken "could not build the content world"
  b="$w.B"
  ( cd "$w" && unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY && git worktree add -q --detach "$b" ) >/dev/null 2>&1 \
    || broken "could not add the content world's second worktree"
  printf 'a2\n' > "$b/core/a.txt"
  [ "$(cd "$w" && git ls-files)" = "$(cd "$b" && git ls-files)" ] && ! cmp -s "$w/core/a.txt" "$b/core/a.txt" \
    || broken "the content world's two trees must share a path set and differ in core/a.txt"
  VS="$w.vs" flush "$w" "$psu" "$w.out1" > /dev/null
  VS="$w.vs" flush "$b" "$psu" "$b.out1" > /dev/null
  : > "$w.ran"; VS="$w.vs" flush "$w" "$psu" "$w.out2" > /dev/null; ra="$(ran_of "$w")"
  printf 'a3\n' > "$b/core/a.txt"
  : > "$b.ran"; VS="$w.vs" flush "$b" "$psu" "$b.out2" > /dev/null; rb="$(ran_of "$b")"
  echo "A=$ra;B=$rb"
}
# flip_arm <psu> <tag> <rewrite|create|unrel>: the first flush runs ps_flip as stepb; the world must read the same after it
# as before. The second flush runs the plain stubs. Prints the second flush's ran set and the first's not-recorded count.
flip_arm() {
  local psu="$1" w="$WORK/flip-$2-$3" rc1 rc2
  world "$w" || broken "could not build the $3 flip world"
  ( cd "$w" && find . -path ./.git -prune -o -print | sort && cat docs/b.txt ) > "$w.pre" 2>&1
  rc1="$(FLIP="$3" flush "$w" "$psu" "$w.out1" flip)"
  [ "$rc1" = 0 ] && [ "$(ran_of "$w")" = "a b c " ] || { echo "first:rc=$rc1:ran=$(ran_of "$w")"; return 0; }
  ( cd "$w" && find . -path ./.git -prune -o -print | sort && cat docs/b.txt ) > "$w.post" 2>&1
  cmp -s "$w.pre" "$w.post" || broken "the $3 flip world did not read the same after the step put its path back"
  : > "$w.ran"
  rc2="$(flush "$w" "$psu" "$w.out2")"
  echo "rc=$rc2:ran=$(ran_of "$w"):$(grep -c '   ..    not recorded: ' "$w.out1")"
}
chk() { # chk <tag> <arm> <pass 0|1> <ok message> <fail message>
  if [ "$3" = 0 ]; then ok "$4"; else bad "$5"; fi
}
run_arm() { # run_arm <tag> <psu> <arm>
  local tag="$1" psu="$2" arm="$3" r p=1
  case "$arm" in
    skip) r="$(two "$tag" "$psu" none)"; [ "$r" = "rc=0:ran=c " ] && p=0
      chk "$tag" skip "$p" "an unchanged tree: the two keyed steps skip on their recorded pass and only the undeclared step runs" "an unchanged tree ran '$r', want only c (a keyed step must skip on a recorded pass)" ;;
    unrel) r="$(two "$tag" "$psu" unrel)"; [ "$r" = "rc=0:ran=c " ] && p=0
      chk "$tag" unrel "$p" "a file added outside every declared directory leaves both keyed steps skipping" "an unrelated file add ran '$r', want only c (a path no step declares must not void a record)" ;;
    moved) r="$(two "$tag" "$psu" moved)"; [ "$r" = "rc=0:ran=a c " ] && p=0
      chk "$tag" moved "$p" "an edit of a declared file runs the step that declares it and still skips the other keyed step" "a moved input ran '$r', want a and c (the declaring step must run, the other must skip)" ;;
    absent) r="$(two "$tag" "$psu" absent)"; [ "$r" = "rc=0:ran=a c " ] && p=0
      chk "$tag" absent "$p" "a file ADDED to a declared directory (cells.decl under core/fixtures/x/) runs the step declaring it: the directory listing moved" "an added file in a declared directory ran '$r', want a and c (the absent-path case: no file read could see it)" ;;
    conc) r="$(conc_arm "$psu" "$tag")"; [ "$r" = "rc=0:2" ] && p=0
      chk "$tag" conc "$p" "two steps that each read the other's token off a fifo both pass: the steps were live at once (a serial pool drops the first step's token with its fd)" "the meeting steps gave '$r', want rc=0 and 2 PASS (a serial pool cannot pass both)" ;;
    content) r="$(content_arm "$psu" "$tag")"; [ "$r" = "A=c ;B=a c " ] && p=0
      chk "$tag" content "$p" "a tree whose declared input differs from another tree's at the same path set skips on its own pass after the other recorded, and content no run passed still runs" "two trees at one path set gave '$r', want A=c ;B=a c  (a tree's pass must survive another tree's record, and must not cover content it never passed)" ;;
    trewrite) r="$(flip_arm "$psu" "$tag" rewrite)"; [ "$r" = "rc=0:ran=b c :1" ] && p=0
      chk "$tag" trewrite "$p" "a declared file rewritten and put back by cp -p while the steps ran leaves that step unrecorded, so the next flush runs it" "a declared file put back during the run gave '$r', want rc=0:ran=b c :1 (a pass keyed on the restored tree must not be recorded)" ;;
    tcreate) r="$(flip_arm "$psu" "$tag" create)"; [ "$r" = "rc=0:ran=b c :1" ] && p=0
      chk "$tag" tcreate "$p" "a file created and removed in a declared directory while the steps ran leaves that step unrecorded, so the next flush runs it" "a file created and removed in a declared directory gave '$r', want rc=0:ran=b c :1 (the listing is back, the directory's inode moved)" ;;
    tunrel) r="$(flip_arm "$psu" "$tag" unrel)"; [ "$r" = "rc=0:ran=c :0" ] && p=0
      chk "$tag" tunrel "$p" "a file created and removed outside the step's declared inputs leaves its pass recorded, so the next flush skips it" "a path outside stepb's inputs, changed during the run, gave '$r', want rc=0:ran=c :0 (only the step's own key rows may void its record)" ;;
  esac
}
for _a in skip unrel moved absent conc content trewrite tcreate tunrel; do run_arm base "$WORK/psu.sh" "$_a"; done
# the order arm reads the base `none` world's second flush output
cp "$WORK/base-none.out2" "$WORK/o.txt" 2>/dev/null || broken "the skip world left no second-flush output"
r="$(sed -n '/^── /p;/^   PASS$/p;/^   skipped on/p' "$WORK/o.txt" | tr '\n' '|')"
chk base order "$([ "$r" = "── stepa|   skipped on a recorded pass: none of its declared inputs changed|   PASS|── stepb|   skipped on a recorded pass: none of its declared inputs changed|   PASS|── stepc|   PASS|" ] && echo 0 || echo 1)" \
  "the steps print in declaration order, each title followed by its own verdict" "the print order was '$r', want stepa stepb stepc in order, each with its own verdict"
report_end presuite-units 10

