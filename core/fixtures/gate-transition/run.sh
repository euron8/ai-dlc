#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# gate-transition/run.sh -- drive the REAL core/scripts/gate-transition.sh over one seeded story world
# (story-evidence-scaffold's build_world, a lead checkout at the base and a frozen dev worktree), and
# assert each gate's plan by VALUE.
#
# THE ARMS, each with the control that must read the opposite:
#   MAP     gate 1, partitioned: the plan's shard lines are cmp-equal to a standalone
#           `partition-review-diff.sh --map ... --exclude-captures` on the same tree.
#           control: the same standalone map with one byte altered is NOT cmp-equal.
#   JOIN    the REAL dispatch guard ALLOWS a sharded code-reviewer brief whose `gate-plan:` is the path gate 1
#           printed, so the guard accepts the plan path and format the program writes.
#           control: the byte-identical brief citing that plan's twin with only `sha:` changed is DENIED on the
#           partition manifest, the brief with no `gate-plan:` line is DENIED, and the two cited briefs differ
#           in that one line only.
#   MAPX    gate 1 at the threshold where the captures decide (AI_DLC_REVIEW_SHARD_MIN_FILES=8): the plan
#           reads `manifest: none`, carries no shard line, and its route is `serial <the standalone line>`.
#           control: the standalone --map WITHOUT --exclude-captures partitions this tree (exit 0, shard lines).
#   DAR     gate 2 with a stale canonical Dev Agent Record exits 1 with `REFUSED dar-fold`, and the plan
#           pre-seeded at that path is gone: no plan file is on disk.
#           control: the same gate once the record is folded exits 0 and writes the plan.
#   RECP    gate 2: the lead record's `partition-sha.<shard dir>` equals the manifest's `sha` line, which
#           --map wrote, so --record-partition ran after --map.
#           control: --record-partition on a shard dir no --map has written refuses `no manifest`.
#   OPEN12  every gate-1 and gate-2 run leaves a live `.gate-checkpoint/OPEN` byte-identical.
#           control: the gate-3 run (G3) moves it.
#   RERUN   gate 2 pass 2 whose prior QA pass reviewed the base: Rule A answers GATE1-RERUN, and the plan
#           reads `gate: rerun`, `manifest: none`, a `route: rerun GATE1-RERUN` line and no shard line.
#           control: the prior QA pass reviewed the frozen sha, GATE1-SKIP, and the plan is `gate: 2` with shard lines.
#   G3X     gate 3 with one refusing arm exits 1, writes no g3 plan and leaves OPEN byte-identical.
#           control: G3.
#   G3      gate 3 with every arm passing exits 0, its plan carries `nonce: <N>`, and OPEN now reads <N>.
#           control: G3X.
#   G3Q     gate 3 with the Check 22 arm exiting 1 exits 1 and prints `REFUSED check-22`; any non-zero Check 22 exit but 3 refuses.
#           control: G3P.
#   G3P     gate 3 with the Check 22 arm exiting 3 (PRE-LEDGER, not a FAIL) still exits 0, writes the g3 plan, and the plan
#           carries the script's own first line as `gate-log: Check 22 exit 3: PRE-LEDGER: ...` and its COUNTS: line. control: G3Q.
#   G3N     the same exit 3 from the other branch (NO ROLE-BOUND ROWS: EXAMINED NOTHING): exit 0, and the plan carries that
#           message and no "PRE-LEDGER". control: G3P.
#   CLOSEX  `close` over a gate-3 ledger whose 26 row is FAIL exits 1 and leaves no close plan.
#           control: CLOSE.
#   CLOSE   `close` once the ledger carries `26 PASS` exits 0 with `gate: close` and the g3 plan's nonce.
#           control: CLOSEX.
#   CLOSEM  `close` for a story with no g3 plan and no slugged verdict, over the newest storyless
#           `implementation-s1-<TS>` verdict whose ledger carries `26 PASS`: exit 0, `gate: close`, that
#           nonce, and a `gate3-scope:` line. control: CLOSEMX.
#   CLOSEMX the same with the newest storyless s1 verdict's ledger lacking `26 PASS`, while a newer
#           `implementation-s12-` verdict, a newer `implementation-story4x1-s1-` verdict and an OLDER storyless
#           s1 verdict carry it: exit 1, and the refusal is the newest verdict's own (its nonce, "has no '26 PASS'
#           row"), no plan. Newest wins: the older 26-PASS verdict is never fallen back to. control: CLOSEM.
#   CLOSEP  a story whose slugged verdict is OLDER than the storyless one closes on the slugged nonce, with no
#           `gate3-scope:` line: the story-scoped lookup wins. control: CLOSEM.
# Gate 3's script arms run from a COPY of the scripts directory in which the eight check siblings are
# stubs answering PASS (one refuses on demand, GT_FX_REFUSE); gate-transition.sh and gate-checkpoint.sh
# in that copy are the real files. A real gate-3 world needs a sprint canonical, a spawn ledger, settings
# and an H2 attestation, none of which is the subject's decision.
#
# THE MUTANTS, each a copy of the whole scripts directory with gate-transition.sh edited and cmp-checked;
# per push each runs only its deciding world, scored against that step's base flag (lib/mutant.sh).
# Measured by the --matrix run below (11 mutants x 17 arms, every other cell GREEN).
# MUTANT-MATRIX m-early decides=DAR,G3X,CLOSEX,CLOSEMX twins=- why=per push it runs only G3X, and its one cheap green twin G3 would mint a second gate-3 nonce in the same second as the real G3 run, blinding that run's OPEN-moved check
# MUTANT-MATRIX m-pre3 decides=G3P,G3N twins=G3Q
# MUTANT-MATRIX m-open12 decides=OPEN12 twins=MAP
# MUTANT-MATRIX m-noxcap decides=MAPX twins=OPEN12
# MUTANT-MATRIX m-norm decides=DAR twins=OPEN12
# MUTANT-MATRIX m-close26 decides=CLOSEX twins=CLOSE
# MUTANT-MATRIX m-pdir decides=JOIN twins=MAP
# MUTANT-MATRIX m-fixed3 decides=G3N twins=G3P
# MUTANT-MATRIX m-slugok decides=CLOSEMX twins=- why=its cheap green twin CLOSEM seeds a newer storyless verdict that hides the slugged decoy, so it runs only the CLOSEMX start
# MUTANT-MATRIX m-nosprint decides=CLOSEM,CLOSEMX twins=- why=its one cheap green twin CLOSEP needs a story-3-1 world the CLOSEM start does not leave, so a twin would add a second start for no new cell
# MUTANT-MATRIX m-skipolder decides=CLOSEMX twins=- why=its cheap green twin CLOSEM seeds a newer storyless verdict carrying 26 PASS, which the mutant takes like the original, so it runs only the CLOSEMX start
# MUTANT-MATRIX-REMEASURE bash core/fixtures/gate-transition/run.sh --matrix
#
# Usage: run.sh [--matrix]
# Exit:  0 = every arm passed, 1 = an arm failed, 2 = fixture broken.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset GT_FX_REFUSE GT_FX_RC22 GT_FX_MSG22

HERE="$(cd "$(dirname "$0")" && pwd)"
MATRIX=0; [ "${1:-}" = --matrix ] && MATRIX=1

# The engine is found by walking up for the directory that carries it, in either layout:
# <root>/core/scripts (the distribution) or <root>/scripts/ai-dlc (an installed consumer).
SCR=""; _d="$HERE"
while [ -n "$_d" ] && [ "$_d" != / ] && [ "$_d" != . ]; do
  if [ -f "$_d/core/scripts/gate-transition.sh" ]; then SCR="$_d/core/scripts"; break; fi
  if [ -f "$_d/scripts/ai-dlc/gate-transition.sh" ]; then SCR="$_d/scripts/ai-dlc"; break; fi
  _d="$(dirname "$_d")"
done
[ -n "$SCR" ] || { echo "FIXTURE BROKEN: no core/scripts/gate-transition.sh or scripts/ai-dlc/gate-transition.sh above $HERE" >&2; exit 2; }
GT="$SCR/gate-transition.sh"
GRAMMAR=""
for _c in "$_d/core/skills/ai-dlc/artifact-path-grammar.md" "$_d/.claude/skills/ai-dlc/artifact-path-grammar.md"; do
  [ -f "$_c" ] && { GRAMMAR="$_c"; break; }
done
[ -n "$GRAMMAR" ] || { echo "FIXTURE BROKEN: artifact-path-grammar.md is in neither layout under $_d" >&2; exit 2; }
# JOIN's guard and the step file whose sentinel arms it, in the layout the engine was found in:
# core/hooks + core/skills in the distribution, .claude/hooks + .claude/skills installed (install.sh).
case "$SCR" in
  */core/scripts) HOOK="$_d/core/hooks/ai-dlc-dispatch-guard.sh"; STEPF="$_d/core/skills/ai-dlc/steps/implementation.md" ;;
  *) HOOK="$_d/.claude/hooks/ai-dlc-dispatch-guard.sh"; STEPF="$_d/.claude/skills/ai-dlc/steps/implementation.md" ;;
esac
[ -f "$HOOK" ] && [ -f "$STEPF" ] || { echo "FIXTURE BROKEN: the dispatch guard $HOOK or the step file $STEPF is absent" >&2; exit 2; }
grep -q 'dg_gp_check' "$HOOK" || { echo "FIXTURE BROKEN: $HOOK carries no dg_gp_check; JOIN has no subject" >&2; exit 2; }
GH="$HOOK"   # the guard JOIN starts; the plain run repoints it at a core/hooks copy beside $GTR
WSH="$HERE/../story-evidence-scaffold/world.sh"
[ -f "$WSH" ] || { echo "FIXTURE BROKEN: $WSH is absent; the story world cannot be built" >&2; exit 2; }

T="$(mktemp -d)" || { echo "FIXTURE BROKEN: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$T"' EXIT
# PHYSICAL: the program prints ROOT-prefixed plan paths and the guard prefix-matches its project dir, so a
# /var against /private/var split would turn JOIN's allow cell into a deny.
T="$(cd "$T" && pwd -P)" || { echo "FIXTURE BROKEN: the scratch dir has no physical path" >&2; exit 2; }
fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails + 1)); }
# world.sh reads WORK, DIR, ok and bad; it defines build_world, gitw and STORY.
WORK="$T/work"; DIR="$HERE"; mkdir -p "$WORK"
# shellcheck source=/dev/null
. "$WSH" || { echo "FIXTURE BROKEN: sourcing $WSH failed" >&2; exit 2; }
. "$HERE/../lib/mutant.sh" || { echo "FIXTURE BROKEN: lib/mutant.sh not found" >&2; exit 2; }
. "$HERE/../lib/matrix.sh" || { echo "FIXTURE BROKEN: lib/matrix.sh not found" >&2; exit 2; }
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

# --- trees of the subject ---------------------------------------------------------------------
# mk_tree <dir> : a whole copy of the scripts directory at <dir>/core/scripts (so every copy of the
# subject ends in core/scripts/gate-transition.sh) plus a gate-3 copy at <dir>/stub/core/scripts whose
# eight check siblings are stubs. Prints nothing; 1 when a copy failed.
STUBS="verdict.sh validate-escalation-resolution.sh sprint-status.sh validate-stub-audit.sh validate-spawn-ledger.sh validate-provenance-block.sh validate-steering-budget.sh validate-h2-attestation.sh"
mk_tree() {
  local d="$1" s
  mkdir -p "$d/core/scripts" "$d/stub/core/scripts" || return 1
  cp -R "$SCR/." "$d/core/scripts/" && cp -R "$SCR/." "$d/stub/core/scripts/" || return 1
  for s in $STUBS; do
    [ -f "$d/stub/core/scripts/$s" ] || return 1
    printf '#!/usr/bin/env bash\n# gate-transition fixture stub for %s: PASS unless GT_FX_REFUSE names it.\n[ %s != validate-spawn-ledger.sh ] || [ -z "${GT_FX_RC22:-}" ] || { [ "$GT_FX_RC22" != 3 ] || { if [ "${GT_FX_MSG22:-}" = norole ]; then echo "NO ROLE-BOUND ROWS: EXAMINED NOTHING -- 2 S1 row(s) exist and NONE of them was judged"; else echo "PRE-LEDGER: 4 row(s) in ledger.jsonl, NONE of them S1."; fi; echo "COUNTS: examined 0 S1 spawn row(s) of 4 in ledger.jsonl;"; }; exit "$GT_FX_RC22"; }\n[ "${GT_FX_REFUSE:-}" != %s ] || { echo "stub %s: REFUSED by the fixture" >&2; exit 1; }\n[ %s != validate-h2-attestation.sh ] || echo "H2_ATTESTED v1 sprint=1 stub"\n[ %s != validate-steering-budget.sh ] || echo "steering-count 0"\nexit 0\n' \
      "$s" "$s" "$s" "$s" "$s" "$s" > "$d/stub/core/scripts/$s" || return 1
  done
}
# mut_tree <name> <awk program> <expected count of changed lines> : a mutant tree under $T/m/<name>,
# both copies of gate-transition.sh rewritten by the awk program (which prints every line). Sets d to
# the tree; returns 1, loudly, when the mutation did not apply or changed the wrong number of lines.
# Called directly, never inside `$( )`: there its `bad` would land in the capture and its count in a
# subshell, and a mutant that never applied would print nothing at all.
mut_tree() {
  local n="$1" prog="$2" want="$3" f got dd
  d="$T/m/$1"
  mk_tree "$d" || { bad "mutant $n: DID NOT APPLY -- the tree copy failed"; return 1; }
  for f in "$d/core/scripts/gate-transition.sh" "$d/stub/core/scripts/gate-transition.sh"; do
    awk "$prog" "$GT" > "$f.new" || { bad "mutant $n: DID NOT APPLY -- its awk program died"; return 1; }
    if cmp -s "$f.new" "$GT"; then bad "mutant $n: DID NOT APPLY -- the edit matched nothing"; return 1; fi
    # diff exits 1 on a difference, so under pipefail it is captured first and counted from a here-string.
    dd="$(diff "$GT" "$f.new")"
    got="$(grep -c '^[<>]' <<< "$dd")" || got=0
    [ "$got" = "$want" ] || { bad "mutant $n: DID NOT APPLY as built -- $got changed line(s), $want expected"; return 1; }
    mv "$f.new" "$f" || { bad "mutant $n: DID NOT APPLY -- the copy could not be replaced"; return 1; }
  done
}

# --- the world --------------------------------------------------------------------------------
# new_world <dir> : the lead at <dir>/lead checked out at the base, the frozen worktree at <dir>/wt,
# the refs recorded IN the world (.B, .WK), a live OPEN marker and the standalone maps. Sets L WT B WK
# P OPEN WD for the steps below.
new_world() {
  WD="$1"; L="$WD/lead"; WT="$WD/wt"
  mkdir -p "$WD/td" || return 1
  build_world "$L" clean || return 1
  B="$(cat "$L/.B")"
  mkdir -p "$L/src" "$L/.claude/skills/ai-dlc" || return 1
  for f in a b c; do printf 'def %s():\n    return 1\n' "$f" > "$L/src/$f.py"; done
  cp "$GRAMMAR" "$L/.claude/skills/ai-dlc/" || return 1
  gitw "$L" add src .claude && gitw "$L" commit -qm more || return 1
  WK="$(gitw "$L" rev-parse HEAD)" || return 1
  printf '%s\n' "$B" > "$WD/.B"; printf '%s\n' "$WK" > "$WD/.WK"
  gitw "$L" checkout -q --detach "$B" && gitw "$L" worktree add -q --detach "$WT" "$WK" || return 1
  cp "$L/$STORY" "$WD/story.stale" || return 1
  export AI_DLC_PROJECT_ROOT="$L"
  P="$L/_bmad-output/implementation-artifacts/s1/gate-transition"
  OPEN="$L/_bmad-output/.gate-checkpoint/OPEN"
  bash "$SCR/gate-checkpoint.sh" --nonce implementation-20260101T000000Z open > /dev/null 2>&1 && [ -s "$OPEN" ] || return 1
  bash "$SCR/validate-handoff-evidence.sh" -C "$WT" --list-captures "$STORY" "$WK" > "$WD/cap" 2> /dev/null || return 1
  AI_DLC_REVIEW_SHARD_MIN_FILES=2 bash "$SCR/partition-review-diff.sh" --map "$WT" "$B" "$WK" --exclude-captures "$WD/cap" > "$WD/sa2" 2> /dev/null || return 1
  AI_DLC_REVIEW_SHARD_MIN_FILES=8 bash "$SCR/partition-review-diff.sh" --map "$WT" "$B" "$WK" --exclude-captures "$WD/cap" > "$WD/sa8" 2> /dev/null
  [ "$?" = 3 ] || return 1
  AI_DLC_REVIEW_SHARD_MIN_FILES=8 bash "$SCR/partition-review-diff.sh" --map "$WT" "$B" "$WK" > "$WD/sa8n" 2> /dev/null || return 1
  # The lead checkout is also the guard's project: a layered-consumer stamp, a snapshot at implementation.md,
  # and this tree's own implementation.md, so the guard's era gate reads the real sentinel.
  mkdir -p "$L/.claude/team-roles" "$L/.claude/skills/ai-dlc/steps" "$L/_bmad-output" || return 1
  printf 'version: 0.70.0\ncommit: fixture\n' > "$L/.claude/.ai-dlc-version" && printf '{}\n' > "$L/.claude/settings.json" || return 1
  cp "$STEPF" "$L/.claude/skills/ai-dlc/steps/implementation.md" || return 1
  printf '# Pipeline Snapshot\n\n## Pipeline Position\n- current_step_file: steps/implementation.md\n- sprint_id: 1\n\n## Recent Activity\n- none\n' \
    > "$L/_bmad-output/pipeline-snapshot.md"
}
shards() { grep -E '^[0-9]+	' "$1" 2> /dev/null; }
nshards() { local n; n="$(shards "$1" | grep -c .)" || n=0; printf '%s' "$n"; }
# gtrun <cell> <gt> <tag> <min-files> <refuse|-> <idx> <gate> [extra args] : one start of the subject.
gtrun() {
  local c="$1" g="$2" t="$3" n="$4" r="$5"; shift 5
  [ "$r" = - ] && r=""
  cp "$OPEN" "$WD/open.pre" 2> /dev/null || : > "$WD/open.pre"
  AI_DLC_REVIEW_SHARD_MIN_FILES="$n" GT_FX_REFUSE="$r" FXCELL="$c" bash "$g" "$@" \
    -C "$WT" --base "$B" --sprint 1 --story-file "$STORY" > "$WD/$t.out" 2> "$WD/$t.err" < /dev/null
  RC=$?
  cmp -s "$OPEN" "$WD/open.pre" && OPEN_SAME=1 || OPEN_SAME=0
}

# --- the steps: each one start, each sets the verdicts of the arms it decides ----------------
st_g1() { # gate 1, partitioned: MAP, OPEN12
  gtrun "$1" "$2" g1 2 - 1-1 1
  V_MAP=0; shards "$P/1-1-g1-p1.plan" > "$WD/g1.shards"
  [ "$RC" = 0 ] && [ -s "$WD/g1.shards" ] && cmp -s "$WD/g1.shards" "$WD/sa2" && V_MAP=1
  V_OPEN=$OPEN_SAME
}
# guard <tag> [gate-plan line] : one start of the real dispatch guard on a sharded code-reviewer brief for part 1
# of the gate-1 plan. The brief is written to $WD/<tag>.brief, so two briefs can be diffed. Sets DEC (deny|allow),
# WHY and GRC; the guard's stderr is kept in $WD/<tag>.gerr. Empty stdout reads as allow ONLY with exit 0.
guard() {
  local t="$1" o
  { printf 'Your operating contract is `.claude/team-roles/code-reviewer.md`. Read it first.\nshard: 1/%s %s\n' "$JN" "$JK"
    [ -z "${2:-}" ] || printf '%s\n' "$2"
    printf 'Do the work.\n'; } > "$WD/$t.brief"
  jq -nc --rawfile p "$WD/$t.brief" --arg n "gt-join-$t" '{tool_name:"Agent",tool_input:{name:$n,prompt:$p}}' > "$WD/$t.json"
  o="$(CLAUDE_PROJECT_DIR="$L" FXCELL="$JC-$t" bash "$GH" < "$WD/$t.json" 2> "$WD/$t.gerr")"; GRC=$?
  [ -n "$o" ] || o='{}'
  DEC="$(jq -r '.hookSpecificOutput.permissionDecision // "allow"' <<< "$o" 2> /dev/null)" || DEC=unreadable
  WHY="$(jq -r '.hookSpecificOutput.permissionDecisionReason // empty' <<< "$o" 2> /dev/null)"
  grep -qE 'No such file or directory|command not found' "$WD/$t.gerr" && DEC="broken"
}
st_join() { # <cell prefix> : the guard over the plan st_g1 just wrote, cited as the program printed it: JOIN
  local pl s1 s7 nd
  JC="$1"
  V_JOIN=0; J_OK=0; J_SHA=0; J_NO=0; J_DIFF=0; J_ODEC=unrun; J_OWHY=""; J_OGRC=-
  pl="$(head -1 "$WD/g1.out")"
  JK="$(shards "$P/1-1-g1-p1.plan" | head -1 | cut -f2)"; JN="$(nshards "$P/1-1-g1-p1.plan")"
  # The wrong-sha twin: the program's own plan at another plan-shaped name, its sha line alone changed.
  sed 's/^sha: .*/sha: 0000000000000000000000000000000000000000/' "$P/1-1-g1-p1.plan" > "$P/1-1-g1-p7.plan"
  s1="$(sed -n 's/^sha: //p' "$P/1-1-g1-p1.plan")"; s7="$(sed -n 's/^sha: //p' "$P/1-1-g1-p7.plan")"
  { [ -n "$pl" ] && [ -n "$JK" ] && [ "$JN" -ge 2 ] && [ -n "$s1" ] && [ "$s1" != "$s7" ]; } || return 0
  guard jok "gate-plan: $pl"; J_ODEC="$DEC"; J_OWHY="$WHY"; J_OGRC="$GRC"
  [ "$DEC" = allow ] && [ "$GRC" = 0 ] && J_OK=1
  guard jsha "gate-plan: ${pl%-p1.plan}-p7.plan"
  case "$GRC:$DEC:$WHY" in 0:deny:*"partition manifest"*) J_SHA=1 ;; esac
  guard jno
  case "$GRC:$DEC:$WHY" in 0:deny:*"no \`gate-plan:\` line"*) J_NO=1 ;; esac
  # The allow brief and its wrong-sha twin differ in exactly one line each way, and it is the gate-plan line.
  nd="$(diff "$WD/jok.brief" "$WD/jsha.brief")"
  [ "$(grep -c '^[<>]' <<< "$nd")" = 2 ] && [ "$(grep -c '^[<>] gate-plan: ' <<< "$nd")" = 2 ] && J_DIFF=1
  [ "$J_OK$J_SHA$J_NO$J_DIFF" = 1111 ] && V_JOIN=1
}
st_g1x() { # gate 1 at the captures threshold: MAPX, OPEN12
  gtrun "$1" "$2" g1x 8 - 1-8 1
  V_MAPX=0
  [ "$RC" = 0 ] && grep -qx 'manifest: none' "$P/1-8-g1-p1.plan" && grep -qxF "route: serial $(cat "$WD/sa8")" "$P/1-8-g1-p1.plan" \
    && [ "$(nshards "$P/1-8-g1-p1.plan")" = 0 ] && V_MAPX=1
  V_OPEN=$OPEN_SAME
}
st_g2s() { # gate 2, stale canonical DAR, a stale plan pre-seeded: DAR, OPEN12
  cp "$WD/story.stale" "$L/$STORY" && printf 'story: stale\n' > "$P/1-1-g2-p1.plan"
  gtrun "$1" "$2" g2s 2 - 1-1 2
  V_DAR=0
  [ "$RC" = 1 ] && grep -q 'REFUSED dar-fold' "$WD/g2s.err" && [ ! -e "$P/1-1-g2-p1.plan" ] && V_DAR=1
  V_OPEN=$OPEN_SAME
}
st_g2() { # gate 2 after the fold: RECP, OPEN12, and DAR's control
  cp "$WT/$STORY" "$L/$STORY"
  gtrun "$1" "$2" g2 2 - 1-1 2
  V_DARC=0; [ "$RC" = 0 ] && [ -f "$P/1-1-g2-p1.plan" ] && V_DARC=1
  local sd ms rs; V_RECP=0
  sd="$(sed -n 's#^manifest: \(.*\)/\.manifest$#\1#p' "$P/1-1-g2-p1.plan" 2> /dev/null)"
  if [ -n "$sd" ] && [ -f "$sd/.manifest" ]; then
    ms="$(awk -F'\t' '$1 == "sha" { print $2 }' "$sd/.manifest")"
    rs="$(awk -F': ' -v k="partition-sha.${sd##*/}" '$1 == k { print $2 }' "$L/.git/ai-dlc/stories/s1-1-1" 2> /dev/null)"
    [ -n "$ms" ] && [ "$ms" = "$WK" ] && [ "$rs" = "$ms" ] && V_RECP=1
  fi
  V_OPEN=$OPEN_SAME
}
st_g2r() { # gate 2 pass 2, prior QA reviewed the base: RERUN, OPEN12
  mkdir -p "$L/docs/reviews/s1" && printf '# QA Validation: 1-1\n\nreviewed-sha: %s\n' "$B" > "$L/docs/reviews/s1/1-1-qa-validation.md"
  gtrun "$1" "$2" g2r 2 - 1-1 2 --pass 2
  V_RERUN=0
  [ "$RC" = 0 ] && grep -qx 'gate: rerun' "$P/1-1-g2-p2.plan" && grep -qx 'manifest: none' "$P/1-1-g2-p2.plan" \
    && grep -q '^route: rerun GATE1-RERUN: ' "$P/1-1-g2-p2.plan" && [ "$(nshards "$P/1-1-g2-p2.plan")" = 0 ] && V_RERUN=1
  V_OPEN=$OPEN_SAME
}
st_g2k() { # gate 2 pass 2, prior QA reviewed the frozen sha: RERUN's control, OPEN12
  printf '# QA Validation: 1-1\n\nreviewed-sha: %s\n' "$WK" > "$L/docs/reviews/s1/1-1-qa-validation.md"
  gtrun "$1" "$2" g2k 2 - 1-1 2 --pass 2
  V_RERUNC=0
  [ "$RC" = 0 ] && grep -qx 'gate: 2' "$P/1-1-g2-p2.plan" && [ "$(nshards "$P/1-1-g2-p2.plan")" -gt 0 ] && V_RERUNC=1
  V_OPEN=$OPEN_SAME
}
st_g3x() { # gate 3, the H2 arm refusing: G3X
  gtrun "$1" "$2" g3x 2 validate-h2-attestation.sh 1-1 3 --transcript-dir "$WD/td"
  V_G3X=0
  [ "$RC" = 1 ] && grep -q 'REFUSED check-H2' "$WD/g3x.err" && [ ! -e "$P/1-1-g3-p1.plan" ] && [ "$OPEN_SAME" = 1 ] && V_G3X=1
}
st_g3q() { # gate 3, the Check 22 arm exiting 1: G3Q
  GT_FX_RC22=1 gtrun "$1" "$2" g3q 2 - 1-1 3 --transcript-dir "$WD/td"
  V_G3Q=0
  [ "$RC" = 1 ] && grep -q 'REFUSED check-22' "$WD/g3q.err" && [ "$OPEN_SAME" = 1 ] && V_G3Q=1
}
st_g3p() { # gate 3, the Check 22 arm exiting 3 (PRE-LEDGER): G3P
  GT_FX_RC22=3 gtrun "$1" "$2" g3p 2 - 1-1 3 --transcript-dir "$WD/td"
  V_G3P=0
  [ "$RC" = 0 ] && grep -qxF "gate-log: Check 22 exit 3: PRE-LEDGER: 4 row(s) in ledger.jsonl, NONE of them S1." "$P/1-1-g3-p1.plan" \
    && grep -qxF "gate-log: Check 22 COUNTS: examined 0 S1 spawn row(s) of 4 in ledger.jsonl;" "$P/1-1-g3-p1.plan" && V_G3P=1
}
st_g3n() { # gate 3, the Check 22 arm exiting 3 from the NO ROLE-BOUND ROWS branch: G3N
  GT_FX_RC22=3 GT_FX_MSG22=norole gtrun "$1" "$2" g3n 2 - 1-1 3 --transcript-dir "$WD/td"
  V_G3N=0
  [ "$RC" = 0 ] && grep -qxF "gate-log: Check 22 exit 3: NO ROLE-BOUND ROWS: EXAMINED NOTHING -- 2 S1 row(s) exist and NONE of them was judged" "$P/1-1-g3-p1.plan" \
    && ! grep -q 'PRE-LEDGER' "$P/1-1-g3-p1.plan" && V_G3N=1
}
st_g3() { # gate 3, every arm passing: G3, and OPEN12's control
  gtrun "$1" "$2" g3 2 - 1-1 3 --transcript-dir "$WD/td"
  V_G3=0; X="$(sed -n 's/^nonce: //p' "$P/1-1-g3-p1.plan" 2> /dev/null)"
  [ "$RC" = 0 ] && [ -n "$X" ] && [ "$(head -1 "$OPEN")" = "$X" ] && [ "$X" != "$(head -1 "$WD/open.pre")" ] && V_G3=1
  V_OPENC=0; [ "$OPEN_SAME" = 0 ] && V_OPENC=1
}
st_cx() { # close over a 26 FAIL ledger: CLOSEX
  [ -z "$X" ] || bash "$SCR/gate-checkpoint.sh" --nonce "$X" record 26 FAIL > /dev/null 2>&1
  gtrun "$1" "$2" cx 2 - 1-1 close
  V_CLOSEX=0
  [ "$RC" = 1 ] && grep -q "no '26 PASS' row" "$WD/cx.err" && [ ! -e "$P/1-1-gclose-p1.plan" ] && V_CLOSEX=1
}
st_c() { # close once 26 PASS is recorded: CLOSE
  [ -z "$X" ] || bash "$SCR/gate-checkpoint.sh" --nonce "$X" record 26 PASS > /dev/null 2>&1
  gtrun "$1" "$2" c 2 - 1-1 close
  V_CLOSE=0
  [ "$RC" = 0 ] && [ -n "$X" ] && grep -qx 'gate: close' "$P/1-1-gclose-p1.plan" && grep -qxF "nonce: $X" "$P/1-1-gclose-p1.plan" && V_CLOSE=1
}
# seed_v <nonce> <gate_series_id> [check id] : a gate-adjudication verdict at <nonce>, and its ledger carrying
# <check id> PASS (26 by default). Story 2-1 has no g3 plan and no slugged verdict, so only the sprint-scoped
# fallback can name its nonce; story 3-1 has a slugged verdict OLDER than the storyless one, so a fallback taken
# before the slug lookup would pick the storyless nonce.
seed_v() {
  mkdir -p "$L/_bmad-output/gate-adjudication"
  printf '{\n  "schema_id": "GATE_ADJUDICATION_VERDICT v1",\n  "gate_type": "implementation",\n  "gate_series_id": "%s",\n  "gate_nonce": "%s",\n  "verdicts": []\n}\n' \
    "$2" "$1" > "$L/_bmad-output/gate-adjudication/$1.verdict.json"
  bash "$SCR/gate-checkpoint.sh" --nonce "$1" record "${3:-26}" PASS > /dev/null 2>&1
}
NM0=implementation-20260130T000000Z; NM1=implementation-20260201T000000Z; NM2=implementation-20260202T000000Z; NM3=implementation-20260131T000000Z; NM9=implementation-20260209T000000Z; NM4=implementation-20260201T120000Z
st_cmx() { # close, story 2-1, the newest storyless s1 verdict's ledger has no 26 row: CLOSEMX
  # OLDER than NM1, storyless, same sprint, 26 PASS: a fallback that skips a verdict lacking 26 PASS closes on it.
  seed_v "$NM0" "implementation-s1-20260130T000000Z"
  seed_v "$NM1" "implementation-s1-20260201T000000Z" 5
  # The newest verdict of all is sprint 12's, storyless, with 26 PASS: a sprint match by prefix would close on it.
  seed_v "$NM9" "implementation-s12-20260209T000000Z"
  # Newer than NM1, same sprint, 26 PASS, but ANOTHER story's slug: a fallback admitting a slug would close 2-1 on it.
  seed_v "$NM4" "implementation-story4x1-s1-20260201T120000Z"
  gtrun "$1" "$2" cmx 2 - 2-1 close
  V_CLOSEMX=0
  [ "$RC" = 1 ] && grep -qF "REFUSED close: the gate-3 ledger for nonce $NM1 has no '26 PASS' row" "$WD/cmx.err" \
    && [ ! -e "$P/2-1-gclose-p1.plan" ] && V_CLOSEMX=1
}
st_cm() { # close, story 2-1, a newer storyless s1 verdict whose ledger carries 26 PASS: CLOSEM
  seed_v "$NM2" "implementation-s1-20260202T000000Z"
  gtrun "$1" "$2" cm 2 - 2-1 close
  V_CLOSEM=0
  [ "$RC" = 0 ] && grep -qx 'gate: close' "$P/2-1-gclose-p1.plan" && grep -qxF "nonce: $NM2" "$P/2-1-gclose-p1.plan" \
    && grep -q '^gate3-scope: sprint-scoped gate 3 ' "$P/2-1-gclose-p1.plan" && V_CLOSEM=1
}
st_cp() { # close, story 3-1, its slugged verdict older than the storyless one: CLOSEP
  seed_v "$NM3" "implementation-story3x1-s1-20260131T000000Z"
  gtrun "$1" "$2" cp 2 - 3-1 close
  V_CLOSEP=0
  [ "$RC" = 0 ] && grep -qxF "nonce: $NM3" "$P/3-1-gclose-p1.plan" && ! grep -q '^gate3-scope:' "$P/3-1-gclose-p1.plan" && V_CLOSEP=1
}

echo "gate-transition:"
printf 'HERMETIC-CONSUMED %s\n' "$GT"
printf 'HERMETIC-CONSUMED %s\n' "$HOOK"
printf '  subject %s\n' "$GT"

# --- the matrix: each mutant through every step on a fresh world -------------------------------
P_EARLY='{ print } $0 == "rm -f \"$PLAN\"" { print "echo \"story: $IDX\" > \"$PLAN\"" }'
P_OPEN12='{ print } $0 == "1)" || $0 == "2)" { print "  bash \"$SELF/gate-checkpoint.sh\" --nonce implementation-20990101T000000Z open > /dev/null 2>&1" }'
P_NOXCAP='{ i = index($0, "\"$SHA\" $(xcap) \"$@\" --shard-dir"); if (i) $0 = substr($0, 1, i + 5) substr($0, i + 14) } { print }'
P_NORM='$0 != "rm -f \"$PLAN\"" { print }'
# m-pre3: Check 22 exit 3 refuses like any other non-zero exit.
P_PRE3='index($0, "3) input gate-log \"Check 22 exit 3:") { $0 = "    3) refuse check-22 \"mutant: exit 3 refuses\" \"none\" ;;" } { print }'
P_CLOSE26='{ i = index($0, "$2 == \"PASS\""); if (i) $0 = substr($0, 1, i - 1) "($2 == \"PASS\" || $2 == \"FAIL\")" substr($0, i + 13) } { print }'
# m-pdir: the program's plan directory spelled with a `/./` hop. The physical directory is unchanged, so every
# other arm still finds its plan; only the printed path changes, and the guard refuses a dotted plan path.
P_PDIR='$0 == "PDIR=\"${ROOT}/_bmad-output/implementation-artifacts/s${SPRINT}/gate-transition\"" { $0 = "PDIR=\"${ROOT}/_bmad-output/implementation-artifacts/s${SPRINT}/./gate-transition\"" } { print }'
# m-fixed3: Check 22 exit 3 records one fixed PRE-LEDGER line whatever the script said, as the program once did.
P_FIXED3='index($0, "3) input gate-log \"Check 22 exit 3:") { $0 = "    3) input gate-log \"Check 22 exit 3: PRE-LEDGER: 4 row(s) in ledger.jsonl, NONE of them S1.\"; [ -z \"$CL\" ] || input gate-log \"Check 22 $CL\" ;;" } { print }'
# m-nosprint: the sprint-scoped close fallback dropped; its series-id match never holds.
P_NOSPRINT='index($0, "\"implementation-s${SPRINT}-[0-9]{8}T[0-9]{6}Z") { $0 = "      continue" } { print }'
# m-slugok: the fallback's series-id match admits any text before the sprint field, so a slugged id qualifies.
P_SLUGOK='{ i = index($0, "implementation-s${SPRINT}-[0-9]{8}"); if (i) $0 = substr($0, 1, i + 14) "[^\\\"]*" substr($0, i + 15) } { print }'
# m-skipolder: the fallback skips a verdict whose ledger lacks 26 PASS and moves on, so an OLDER passing gate 3 is taken
# where newest-wins refuses on the newest one.
P_SKIPOLDER='{ print } index($0, "implementation-s${SPRINT}-[0-9]{8}T[0-9]{6}Z\\\"\" \"$v\" || continue") { print "      n=\"${v##*/}\"; grep -qE \"^26[[:space:]]+PASS\" <<< \"$(bash \"$SELF/gate-checkpoint.sh\" --nonce \"${n%.verdict.json}\" list 2> /dev/null)\" || continue" }'
MUTS="m-early:P_EARLY:1 m-open12:P_OPEN12:2 m-noxcap:P_NOXCAP:2 m-norm:P_NORM:1 m-close26:P_CLOSE26:2 m-pdir:P_PDIR:2 m-pre3:P_PRE3:2 m-fixed3:P_FIXED3:2 m-nosprint:P_NOSPRINT:2 m-slugok:P_SLUGOK:2 m-skipolder:P_SKIPOLDER:1"
ARMS="MAP JOIN MAPX DAR RECP OPEN12 RERUN G3X G3Q G3 CLOSEX CLOSE G3P G3N CLOSEMX CLOSEM CLOSEP"

if [ "$MATRIX" = 1 ]; then
  rows=0
  for m in $MUTS; do
    n="${m%%:*}"; r="${m#*:}"; pv="${r%%:*}"; want="${r#*:}"
    eval "prog=\"\$$pv\""
    mut_tree "$n" "$prog" "$want" || continue
    new_world "$T/mx-$n" || { echo "FIXTURE BROKEN: the matrix world for $n did not build" >&2; exit 2; }
    o=1
    st_g1 x "$d/core/scripts/gate-transition.sh"; [ "$V_OPEN" = 1 ] || o=0
    st_join x
    st_g1x x "$d/core/scripts/gate-transition.sh"; [ "$V_OPEN" = 1 ] || o=0
    st_g2s x "$d/core/scripts/gate-transition.sh"; [ "$V_OPEN" = 1 ] || o=0
    st_g2 x "$d/core/scripts/gate-transition.sh"; [ "$V_OPEN" = 1 ] || o=0
    st_g2r x "$d/core/scripts/gate-transition.sh"; [ "$V_OPEN" = 1 ] || o=0
    st_g2k x "$d/core/scripts/gate-transition.sh"; [ "$V_OPEN" = 1 ] || o=0
    st_g3x x "$d/stub/core/scripts/gate-transition.sh"
    st_g3q x "$d/stub/core/scripts/gate-transition.sh"
    st_g3 x "$d/stub/core/scripts/gate-transition.sh"
    st_cx x "$d/core/scripts/gate-transition.sh"
    st_c x "$d/core/scripts/gate-transition.sh"
    st_g3p x "$d/stub/core/scripts/gate-transition.sh"
    st_g3n x "$d/stub/core/scripts/gate-transition.sh"
    st_cmx x "$d/core/scripts/gate-transition.sh"
    st_cm x "$d/core/scripts/gate-transition.sh"
    st_cp x "$d/core/scripts/gate-transition.sh"
    V_OPEN12=$o
    for a in $ARMS; do
      eval "v=\$V_$a"
      if [ "$v" = 1 ]; then matrix_row "$n" "$a" 0 GREEN no; else matrix_row "$n" "$a" 1 TRIPPED yes; fi
      rows=$((rows + 1))
    done
  done
  _nm="$(printf '%s\n' $MUTS | grep -c .)" || _nm=0
  _na="$(printf '%s\n' $ARMS | grep -c .)" || _na=0
  [ "$rows" -eq $((_nm * _na)) ] && ok "MX matrix run measured $rows mutant x arm cells" || bad "MX matrix run measured $rows cells, $((_nm * _na)) expected"
  [ "$fails" -eq 0 ] && { echo "gate-transition: MATRIX DONE"; exit 0; }
  exit 1
fi

# --- the plain run ----------------------------------------------------------------------------
new_world "$T/w" || { echo "FIXTURE BROKEN: the story world did not build (build_world, the worktree, the live OPEN or a standalone --map)" >&2; exit 2; }
mk_tree "$T/real" || { echo "FIXTURE BROKEN: the gate-3 stub tree did not build" >&2; exit 2; }
GT3="$T/real/stub/core/scripts/gate-transition.sh"
# The real-subject cells start the unmutated COPY at $T/real/core/scripts, never $GT itself: installed, $GT is
# scripts/ai-dlc/gate-transition.sh, which the counter cannot match to the core/scripts/gate-transition.sh row, so
# a counted consumer run measured 8 of 16 and failed J3/C2/C3 (story-evidence-scaffold starts its mk_tree copy too).
GTR="$T/real/core/scripts/gate-transition.sh"
cmp -s "$GTR" "$GT" || { echo "FIXTURE BROKEN: the real-subject copy $GTR is not byte-identical to $GT" >&2; exit 2; }
# The guard likewise: installed, $HOOK is .claude/hooks/ai-dlc-dispatch-guard.sh, which the counter cannot match to
# the core/hooks/ai-dlc-dispatch-guard.sh row, so JOIN starts a whole copy of the hooks directory beside $GTR's tree.
mkdir -p "$T/real/core/hooks" && cp -R "$(dirname "$HOOK")/." "$T/real/core/hooks/" \
  || { echo "FIXTURE BROKEN: the hooks copy at $T/real/core/hooks did not build" >&2; exit 2; }
GH="$T/real/core/hooks/ai-dlc-dispatch-guard.sh"
cmp -s "$GH" "$HOOK" || { echo "FIXTURE BROKEN: the guard copy $GH is not byte-identical to $HOOK" >&2; exit 2; }
[ -s "$WD/sa2" ] && grep -q '^SERIAL: ' "$WD/sa8" && [ -n "$(shards "$WD/sa8n")" ] \
  || { echo "FIXTURE BROKEN: the standalone maps do not separate the threshold world (sa2, sa8 SERIAL, sa8n partitioned)" >&2; exit 2; }
O12=1; KILLS=0

st_g1 g1 "$GTR"; [ "$V_OPEN" = 1 ] || O12=0
B_MAP="$([ "$V_MAP" = 1 ] && echo 1)"; B_O1="$([ "$V_OPEN" = 1 ] && echo 1)"
[ "$V_MAP" = 1 ] && ok "MAP gate-1 plan carries $(grep -c . "$WD/g1.shards") shard line(s), cmp-equal to a standalone --map with --exclude-captures" \
  || bad "MAP gate-1 rc=$RC: plan shard lines differ from the standalone --map, or are absent ($(head -3 "$WD/g1.err" | tr '\n' ' '))"
sed '1s/^./X/' "$WD/sa2" > "$WD/sa2.alt"
cmp -s "$WD/g1.shards" "$WD/sa2.alt" && bad "MAP control: a one-byte-altered map is still cmp-equal" || ok "MAP control: a one-byte-altered standalone map is NOT cmp-equal to the plan"
st_join join
B_JOIN="$([ "$V_JOIN" = 1 ] && echo 1)"
[ "$J_OK" = 1 ] && ok "JOIN the real guard ALLOWS a sharded code-reviewer brief citing the plan gate-transition.sh printed ($(head -1 "$WD/g1.out" | sed "s#^$L/##"))" \
  || bad "JOIN the program's own plan read $J_ODEC from the guard (rc $J_OGRC): $(printf '%s' "$J_OWHY" | cut -c1-240)"
[ "$J_SHA" = 1 ] && ok "JOIN control: the byte-identical brief citing the plan's wrong-sha twin is DENIED (partition manifest)" \
  || bad "JOIN control: the wrong-sha twin was not denied on the partition manifest"
[ "$J_NO" = 1 ] && ok "JOIN control: the same brief with no gate-plan line is DENIED" || bad "JOIN control: the no-plan brief was not denied for its missing gate-plan line"
[ "$J_DIFF" = 1 ] && ok "JOIN control: the allow and wrong-sha briefs differ only in their gate-plan line" || bad "JOIN control: the allow and wrong-sha briefs differ outside the gate-plan line"
if mut_tree m-pdir "$P_PDIR" 2; then
  st_g1 m-pdir "$d/core/scripts/gate-transition.sh"
  st_join m-pdir
  case "$V_JOIN:$V_MAP:$J_ODEC:$J_OWHY" in
    0:1:deny:*"names no readable plan"*)
      mutant_killed "$([ "$B_JOIN" = 1 ] && [ "$B_MAP" = 1 ] && echo 1)" m-pdir "mutant m-pdir (plan dir spelled s<N>/./gate-transition): the guard denies the program's own plan, killed by JOIN; twin MAP stays green" && KILLS=$((KILLS + 1)) ;;
    *) bad "mutant m-pdir SURVIVED or for another reason: JOIN=$V_JOIN MAP=$V_MAP guard=$J_ODEC" ;;
  esac
fi
if mut_tree m-open12 "$P_OPEN12" 2; then
  st_g1 m-open12 "$d/core/scripts/gate-transition.sh"
  if [ "$V_OPEN" = 0 ] && [ "$V_MAP" = 1 ]; then
    mutant_killed "$([ "$B_O1" = 1 ] && [ "$B_MAP" = 1 ] && echo 1)" m-open12 "mutant m-open12 (open at gates 1 and 2): OPEN moved across gate 1, killed by OPEN12; twin MAP stays green" && KILLS=$((KILLS + 1))
  else bad "mutant m-open12 SURVIVED or moved MAP: OPEN same=$V_OPEN MAP=$V_MAP"; fi
fi

st_g1x g1x "$GTR"; [ "$V_OPEN" = 1 ] || O12=0
B_MAPX="$([ "$V_MAPX" = 1 ] && echo 1)"; B_O2="$([ "$V_OPEN" = 1 ] && echo 1)"
[ "$V_MAPX" = 1 ] && ok "MAPX at min-files 8 the plan reads manifest: none, no shard line, route: serial $(cut -c1-48 "$WD/sa8")..." \
  || bad "MAPX rc=$RC: plan is not the standalone SERIAL answer ($(grep -E '^(manifest|route):' "$P/1-8-g1-p1.plan" 2> /dev/null | tr '\n' ' '))"
[ "$(nshards "$WD/sa8n")" -gt 0 ] && ok "MAPX control: the same tree WITHOUT --exclude-captures partitions ($(nshards "$WD/sa8n") shard lines)" \
  || bad "MAPX control: without --exclude-captures the tree does not partition, so MAPX cannot discriminate"
if mut_tree m-noxcap "$P_NOXCAP" 2; then
  st_g1x m-noxcap "$d/core/scripts/gate-transition.sh"
  if [ "$V_MAPX" = 0 ] && [ "$V_OPEN" = 1 ]; then
    mutant_killed "$([ "$B_MAPX" = 1 ] && [ "$B_O2" = 1 ] && echo 1)" m-noxcap "mutant m-noxcap (--map without --exclude-captures): the plan partitions at the threshold, killed by MAPX; twin OPEN12 stays green" && KILLS=$((KILLS + 1))
  else bad "mutant m-noxcap SURVIVED or moved OPEN12: MAPX=$V_MAPX OPEN same=$V_OPEN"; fi
fi

st_g2s g2s "$GTR"; [ "$V_OPEN" = 1 ] || O12=0
B_DAR="$([ "$V_DAR" = 1 ] && echo 1)"; B_O3="$([ "$V_OPEN" = 1 ] && echo 1)"
[ "$V_DAR" = 1 ] && ok "DAR stale Dev Agent Record: exit 1, REFUSED dar-fold, and the pre-seeded plan is gone (no plan on disk)" \
  || bad "DAR rc=$RC: $(grep -c 'REFUSED dar-fold' "$WD/g2s.err") dar-fold line(s), plan on disk: $([ -e "$P/1-1-g2-p1.plan" ] && echo yes || echo no)"
if mut_tree m-norm "$P_NORM" 1; then
  st_g2s m-norm "$d/core/scripts/gate-transition.sh"
  if [ "$V_DAR" = 0 ] && [ "$RC" = 1 ] && [ -e "$P/1-1-g2-p1.plan" ] && [ "$V_OPEN" = 1 ]; then
    mutant_killed "$([ "$B_DAR" = 1 ] && [ "$B_O3" = 1 ] && echo 1)" m-norm "mutant m-norm (stale-plan removal dropped): the pre-seeded plan survives a refusal, killed by DAR; twin OPEN12 stays green" && KILLS=$((KILLS + 1))
  else bad "mutant m-norm SURVIVED or for another reason: DAR=$V_DAR rc=$RC OPEN same=$V_OPEN"; fi
fi

st_g2 g2 "$GTR"; [ "$V_OPEN" = 1 ] || O12=0
[ "$V_DARC" = 1 ] && ok "DAR control: once the record is folded the same gate exits 0 and writes its plan" || bad "DAR control: folded gate 2 rc=$RC, $(head -3 "$WD/g2.err" | tr '\n' ' ')"
[ "$V_RECP" = 1 ] && ok "RECP the lead record's partition-sha equals the manifest's sha line ($WK)" \
  || bad "RECP the lead record's partition-sha does not equal the manifest sha (rc=$RC)"
mkdir -p "$WT/docs/reviews/s1/shards/1-1-qa-validation-000000000000"
( cd "$L" && bash "$SCR/merge-review-shards.sh" --record-partition "$WT/docs/reviews/s1/shards/1-1-qa-validation-000000000000" ) > "$WD/neg.err" 2>&1
nrc=$?
[ "$nrc" != 0 ] && grep -q 'no manifest' "$WD/neg.err" && ok "RECP control: --record-partition on a shard dir --map never wrote refuses 'no manifest' (rc=$nrc)" \
  || bad "RECP control: --record-partition without a manifest did not refuse (rc=$nrc)"

st_g2r g2r "$GTR"; [ "$V_OPEN" = 1 ] || O12=0
[ "$V_RERUN" = 1 ] && ok "RERUN GATE1-RERUN at gate 2 pass 2: gate: rerun, manifest: none, no shard line" \
  || bad "RERUN rc=$RC: $(grep -E '^(gate|manifest|route):' "$P/1-1-g2-p2.plan" 2> /dev/null | tr '\n' ' ')"
st_g2k g2k "$GTR"; [ "$V_OPEN" = 1 ] || O12=0
[ "$V_RERUNC" = 1 ] && ok "RERUN control: GATE1-SKIP at gate 2 pass 2 writes gate: 2 with $(nshards "$P/1-1-g2-p2.plan") shard lines" \
  || bad "RERUN control rc=$RC: $(head -3 "$WD/g2k.err" | tr '\n' ' ')"
[ "$O12" = 1 ] && ok "OPEN12 the live OPEN is byte-identical across all six gate-1 and gate-2 runs" || bad "OPEN12 a gate-1 or gate-2 run moved the live OPEN"

st_g3x g3x "$GT3"
B_G3X="$([ "$V_G3X" = 1 ] && echo 1)"
[ "$V_G3X" = 1 ] && ok "G3X gate 3 with the H2 arm refusing: exit 1, no g3 plan, OPEN byte-identical" \
  || bad "G3X rc=$RC: plan $([ -e "$P/1-1-g3-p1.plan" ] && echo present || echo absent), OPEN same=$OPEN_SAME"
if mut_tree m-early "$P_EARLY" 1; then
  st_g3x m-early "$d/stub/core/scripts/gate-transition.sh"
  if [ "$V_G3X" = 0 ] && [ "$RC" = 1 ] && [ -e "$P/1-1-g3-p1.plan" ]; then
    mutant_killed "$([ "$B_G3X" = 1 ] && echo 1)" m-early "mutant m-early (plan written before the checks): a refused gate 3 leaves a plan, killed by G3X" && KILLS=$((KILLS + 1))
  else bad "mutant m-early SURVIVED or for another reason: G3X=$V_G3X rc=$RC"; fi
fi

st_g3q g3q "$GT3"
[ "$V_G3Q" = 1 ] && ok "G3Q gate 3 with the Check 22 arm exiting 1: exit 1, REFUSED check-22, OPEN byte-identical" \
  || bad "G3Q rc=$RC: $(head -3 "$WD/g3q.err" | tr '\n' ' ')"

st_g3 g3 "$GT3"
[ "$V_G3" = 1 ] && ok "G3 gate 3 passing: exit 0, the plan carries nonce: $X, and OPEN now reads it" \
  || bad "G3 rc=$RC nonce=[$X]: $(head -3 "$WD/g3.err" | tr '\n' ' ')"
[ "$V_OPENC" = 1 ] && ok "OPEN12 control: the gate-3 open moves OPEN" || bad "OPEN12 control: gate 3 left OPEN unchanged, so OPEN12 cannot discriminate"

st_cx cx "$GTR"
B_CLOSEX="$([ "$V_CLOSEX" = 1 ] && echo 1)"
[ "$V_CLOSEX" = 1 ] && ok "CLOSEX close over a 26 FAIL ledger: exit 1, no '26 PASS' row refused, no close plan" \
  || bad "CLOSEX rc=$RC: $(head -2 "$WD/cx.err" | tr '\n' ' ')"
if mut_tree m-close26 "$P_CLOSE26" 2; then
  st_cx m-close26 "$d/core/scripts/gate-transition.sh"
  if [ "$V_CLOSEX" = 0 ] && [ "$RC" = 0 ]; then
    mutant_killed "$([ "$B_CLOSEX" = 1 ] && echo 1)" m-close26 "mutant m-close26 (close accepting 26 FAIL): close passes over a FAIL ledger, killed by CLOSEX" && KILLS=$((KILLS + 1))
  else bad "mutant m-close26 SURVIVED or for another reason: CLOSEX=$V_CLOSEX rc=$RC"; fi
fi

st_c c "$GTR"
[ "$V_CLOSE" = 1 ] && ok "CLOSE close with 26 PASS: exit 0, gate: close, nonce: $X" || bad "CLOSE rc=$RC: $(head -2 "$WD/c.err" | tr '\n' ' ')"
if [ -d "$T/m/m-close26/core/scripts" ]; then
  st_c m-close26-t "$T/m/m-close26/core/scripts/gate-transition.sh"
  [ "$V_CLOSE" = 1 ] && ok "T-m-close26 twin CLOSE stays GREEN under mutant m-close26" || bad "T-m-close26 twin CLOSE tripped under m-close26 (rc=$RC)"
fi
st_g3p g3p "$GT3"
B_G3P="$([ "$V_G3P" = 1 ] && echo 1)"
[ "$V_G3P" = 1 ] && ok "G3P gate 3 with the Check 22 arm exiting 3 (PRE-LEDGER): exit 0, g3 plan written, it carries the PRE-LEDGER gate-log line" \
  || bad "G3P rc=$RC: $(head -3 "$WD/g3p.err" | tr '\n' ' ')"
st_g3n g3n "$GT3"
B_G3N="$([ "$V_G3N" = 1 ] && echo 1)"
[ "$V_G3N" = 1 ] && ok "G3N gate 3 with the Check 22 arm exiting 3 (NO ROLE-BOUND ROWS): exit 0, the plan carries that message and no PRE-LEDGER" \
  || bad "G3N rc=$RC: $(head -3 "$WD/g3n.err" | tr '\n' ' ')"
if mut_tree m-pre3 "$P_PRE3" 2; then
  st_g3p m-pre3 "$d/stub/core/scripts/gate-transition.sh"
  if [ "$V_G3P" = 0 ] && [ "$RC" = 1 ] && grep -q 'REFUSED check-22' "$WD/g3p.err"; then
    mutant_killed "$([ "$B_G3P" = 1 ] && echo 1)" m-pre3 "mutant m-pre3 (Check 22 exit 3 refuses): a PRE-LEDGER sprint is refused, killed by G3P; twin G3Q stays green" && KILLS=$((KILLS + 1))
  else bad "mutant m-pre3 SURVIVED or for another reason: G3P=$V_G3P rc=$RC"; fi
fi
if mut_tree m-fixed3 "$P_FIXED3" 2; then
  st_g3n m-fixed3 "$d/stub/core/scripts/gate-transition.sh"
  if [ "$V_G3N" = 0 ] && [ "$RC" = 0 ]; then
    mutant_killed "$([ "$B_G3N" = 1 ] && echo 1)" m-fixed3 "mutant m-fixed3 (Check 22 exit 3 records a fixed PRE-LEDGER line): the NO ROLE-BOUND ROWS branch is mislabelled, killed by G3N; twin G3P stays green" && KILLS=$((KILLS + 1))
  else bad "mutant m-fixed3 SURVIVED or for another reason: G3N=$V_G3N rc=$RC"; fi
fi
st_cmx cmx "$GTR"
[ "$V_CLOSEMX" = 1 ] && ok "CLOSEMX close over a storyless s1 verdict whose ledger lacks 26 PASS: exit 1, REFUSED close, no close plan (a newer s12 verdict with 26 PASS is not taken)" \
  || bad "CLOSEMX rc=$RC: $(head -2 "$WD/cmx.err" | tr '\n' ' ')"
B_CLOSEMX="$([ "$V_CLOSEMX" = 1 ] && echo 1)"
# Before CLOSEM seeds a newer storyless verdict, which would hide the slugged decoy from the mutant.
if mut_tree m-slugok "$P_SLUGOK" 2; then
  st_cmx m-slugok "$d/core/scripts/gate-transition.sh"
  if [ "$V_CLOSEMX" = 0 ] && [ "$RC" = 0 ] && grep -qxF "nonce: $NM4" "$P/2-1-gclose-p1.plan"; then
    mutant_killed "$([ "$B_CLOSEMX" = 1 ] && echo 1)" m-slugok "mutant m-slugok (fallback admits a slugged series id): story 2-1 closes on story 4-1's gate, killed by CLOSEMX" && KILLS=$((KILLS + 1))
  else bad "mutant m-slugok SURVIVED or for another reason: CLOSEMX=$V_CLOSEMX rc=$RC"; fi
fi
# Also before CLOSEM: its newer 26-PASS storyless verdict would be taken by the mutant and the original alike.
if mut_tree m-skipolder "$P_SKIPOLDER" 1; then
  st_cmx m-skipolder "$d/core/scripts/gate-transition.sh"
  if [ "$V_CLOSEMX" = 0 ] && [ "$RC" = 0 ] && grep -qxF "nonce: $NM0" "$P/2-1-gclose-p1.plan"; then
    mutant_killed "$([ "$B_CLOSEMX" = 1 ] && echo 1)" m-skipolder "mutant m-skipolder (fallback skips a verdict lacking 26 PASS): story 2-1 closes on an older sprint gate, killed by CLOSEMX" && KILLS=$((KILLS + 1))
  else bad "mutant m-skipolder SURVIVED or for another reason: CLOSEMX=$V_CLOSEMX rc=$RC"; fi
fi
st_cm cm "$GTR"
B_CLOSEM="$([ "$V_CLOSEM" = 1 ] && echo 1)"
[ "$V_CLOSEM" = 1 ] && ok "CLOSEM close with no g3 plan over the newest storyless implementation-s1 verdict with 26 PASS: exit 0, gate: close, nonce: $NM2, a gate3-scope line" \
  || bad "CLOSEM rc=$RC: $(head -2 "$WD/cm.err" | tr '\n' ' ')"
st_cp cp "$GTR"
B_CLOSEP="$([ "$V_CLOSEP" = 1 ] && echo 1)"
[ "$V_CLOSEP" = 1 ] && ok "CLOSEP a story-slug verdict ($NM3) wins over a newer storyless one ($NM2): no gate3-scope line" \
  || bad "CLOSEP rc=$RC: $(grep -E '^(nonce|gate3-scope):' "$P/3-1-gclose-p1.plan" 2> /dev/null | tr '\n' ' ') $(head -2 "$WD/cp.err" | tr '\n' ' ')"
if mut_tree m-nosprint "$P_NOSPRINT" 2; then
  st_cm m-nosprint "$d/core/scripts/gate-transition.sh"
  if [ "$V_CLOSEM" = 0 ] && [ "$RC" = 1 ] && grep -q 'no gate-3 plan and no gate-adjudication verdict' "$WD/cm.err"; then
    mutant_killed "$([ "$B_CLOSEM" = 1 ] && echo 1)" m-nosprint "mutant m-nosprint (sprint-scoped close fallback dropped): a storyless gate 3 names no nonce, killed by CLOSEM" && KILLS=$((KILLS + 1))
  else bad "mutant m-nosprint SURVIVED or for another reason: CLOSEM=$V_CLOSEM rc=$RC"; fi
fi
# Every mutant was built, applied and killed: KILLS counts mutant_killed calls that returned 0.
[ "$KILLS" = 11 ] && ok "MK all 11 mutants applied and scored" || bad "MK $KILLS of 11 mutants scored"

echo
if [ "$fails" -eq 0 ]; then echo "gate-transition: PASS"; exit 0; fi
echo "gate-transition: $fails assertion(s) FAILED" >&2
exit 1
