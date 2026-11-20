#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
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
#   RERUN   gate 2 pass 2 whose prior QA pass reviewed the base: Rule A answers GATE1-RERUN, so gate 1 runs TOGETHER:
#           the gate-2 plan reads `gate: 2` and a `gate1-plan:` line naming a written `gate: 1` plan for pass 1, and
#           no plan anywhere reads `gate: rerun`.
#           control: the prior QA pass reviewed the frozen sha, GATE1-SKIP, and the plan is `gate: 2` with shard lines.
#   PRIORM  gate 1 pass 2 over a pass-1 prior written by the REAL merge-review-shards.sh, one column-0 reviewed-sha
#           line per shard (non-adjacent, all naming MID, the commit between B and WK): exit 0, `gate: 1`, its `prior:`
#           line names that file, the manifest's `base` is MID, and no gate-log line records a --map refusal fallback.
#           control: PRIORD.
#   PRIORD  the same prior with its third line naming B (A A B A A): exit 1, `REFUSED prior-review` naming 2 distinct
#           values, no plan. control: PRIORM.
#   FENCE   the PRIORM prior plus a fenced `reviewed-sha: B`: the fenced line is not read, so exit 0 with manifest base
#           MID. control: FENCEC, the prior whose only reviewed-sha line sits in a fence, exits 1 naming no line.
#   PRIORX  the same prior with every line reading `reviewed-sha: <MID> (base <B>)`, the shape 7 consumer files carry: one
#           distinct value once normalised, so only the hex check can refuse it: exit 1, `REFUSED prior-review` naming
#           `not a hex object name`, no plan. control: PRIORM.
#   QAM     gate 2 pass 2 over a merged QA prior (byte-shape copy of a consumer one: three shard sections, one line each,
#           all naming WK, the middle one backticked): `gate: 2` with shard lines. control: QAD.
#   QAD     a merged QA prior naming WK, B, WK: exit 1, `REFUSED prior-validation` naming 2 distinct values, no plan.
#           control: QAM.
#   receipt-bl926.sh reads the PRIORM, PRIORD, QAM and QAD outputs and prints `receipt-bl926: PASS` (BL-926).
#   RULE A's GATE-1 CANDIDATE (BL-931), each gate 2 pass 2 over a rework worktree off WK (G1 adds a code line, the
#   frozen sha after it adds only a docs .md), its gate-2 index dash form and its gate-1 files dot form:
#   RA1     p1 APPROVED at B, p2 APPROVED at G1, a p3 .md.draft beside them: exit 0, `gate: 2`, `rule-a-base: gate1 <G1>
#           <p2 file>`, a GATE1-SKIP gate-log line. control: RA0.
#   RA0     the RA1 world without p2: `gate: 2`, `rule-a-base: qa <WK> ...`, a `gate1-plan:` line naming the `5.1` gate-1 plan.
#   RAN     p9 APPROVED and p10 NEEDS_REWORK at G1: p10 decides by number, base qa, `gate: 2` with the `6.1` pass-11 gate-1 plan. control: RA1.
#   RAX     the re-review APPROVED at a side commit not ancestor-related to WK: exit 1, REFUSED gate1-review, no plan.
#   RAA     gate-1 files under both the dot and the dash form: exit 1, REFUSED gate1-review ambiguous, no plan.
#   RAM     the re-review a MERGED file (the real merge's output, every reviewed-sha naming G1): RA1's answer.
#   receipt-bl931.sh reads the six outputs and prints `receipt-bl931: PASS` (BL-931), after asserting RA1 and RA0
#   differ by exactly the p2 file, --gate1-rerun from WK answers RERUN and from G1 answers SKIP.
#   G3K     RULE A AT GATE 1: gate 1 pass 2 over the rework worktree (frozen RSHA) after a gate-3 rework, the pass-1
#           gate-1 review APPROVED at G1 and the g3 p1 plan naming G1, so the delta G1..RSHA is a docs .md only: exit 0,
#           `gate: skip`, `manifest: none`, `route: skip GATE1-SKIP`, no shard line, `rule-a-base: gate1 <G1> ...`, a
#           next: gate-2 line. control: G3C, the same world with the g3 plan naming RSHA (the remedy gate 3 asked for
#           at the sha it judged): `gate: 1` and the remedy gate-log line.
#   G2K     GATE 2 AFTER A GATE-3 REWORK (BL-1030): gate 2 pass 2 over the rework worktree whose QA prior PASSed at G1, the
#           g3 p1 plan naming RSHA (strictly between G1 and the frozen RSHA2) and the delta G1..RSHA2 a docs .md only: exit 0,
#           `gate: skip`, `manifest: none`, `route: skip GATE2-SKIP`, no shard line, a g3-base line, a next: gate-3 line
#           (never close). Each refusal control changes one input and must read `gate: 2` with a gate-log line naming
#           its own arm: G2R1 a comment-only code edit after the g3 sha (Rule A's line filter skips it, the strict code
#           class does not), G2R2 GO -> code C -> g3 -> records with an APPROVED gate-1 review at C (Rule A's base is C and
#           sees only the records; the delta from GO carries the code), G2R3 the frozen sha is the g3 sha, G2R4 the QA sha
#           is not an ancestor of the g3 sha, G2R5 the QA prior reads NEEDS_REWORK, G2R6 a story-file edit outside its
#           Dev Agent Record, G2R7 no g3 plan. G2D is the positive control for G2R6: an edit inside the Dev Agent Record
#           skips. G2W1 and G2W2 are the prior_file wedge: pass 3 after a GATE2-SKIP (gate 2) or GATE1-SKIP (gate 1) at
#           pass 2 finds the pass-1 file and writes a plan, with no refusal naming the missing pass-2 file. G2W3 is their control:
#           a pass 2 that was DISPATCHED (plan `gate: 2`) and left no file stops the walk, and pass 3 refuses prior-validation.
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
# Usage: run.sh
# Exit:  0 = every arm passed, 1 = an arm failed, 2 = fixture broken.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset GT_FX_REFUSE GT_FX_RC22 GT_FX_MSG22

HERE="$(cd "$(dirname "$0")" && pwd)"

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
. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }
# world.sh reads WORK, DIR, ok and bad; it defines build_world, gitw and STORY.
WORK="$T/work"; DIR="$HERE"; mkdir -p "$WORK"
# shellcheck source=/dev/null
. "$WSH" || { echo "FIXTURE BROKEN: sourcing $WSH failed" >&2; exit 2; }
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

# --- trees of the subject ---------------------------------------------------------------------
# mk_tree <dir> : a whole copy of the scripts directory at <dir>/core/scripts (so every copy of the
# subject ends in core/scripts/gate-transition.sh) plus a gate-3 copy at <dir>/stub/core/scripts whose
# eight check siblings are stubs. Prints nothing; 1 when a copy failed. Both copies carry every entry of the
# scripts directory except hermetic-run.sh, which no script in either tree reads: copying it would make the
# fixture read an input its inputs.decl cannot declare.
STUBS="verdict.sh validate-escalation-resolution.sh sprint-status.sh validate-stub-audit.sh validate-spawn-ledger.sh validate-provenance-block.sh validate-steering-budget.sh validate-h2-attestation.sh"
mk_tree() {
  local d="$1" s
  mkdir -p "$d/core/scripts" "$d/stub/core/scripts" || return 1
  set --
  for s in "$SCR"/* "$SCR"/.[!.]*; do
    [ "${s##*/}" != hermetic-run.sh ] && [ -e "$s" ] && set -- "$@" "$s"
  done
  cp -R "$@" "$d/core/scripts/" && cp -R "$@" "$d/stub/core/scripts/" || return 1
  for s in $STUBS; do
    [ -f "$d/stub/core/scripts/$s" ] || return 1
    printf '#!/usr/bin/env bash\n# gate-transition fixture stub for %s: PASS unless GT_FX_REFUSE names it.\n[ %s != validate-spawn-ledger.sh ] || [ -z "${GT_FX_RC22:-}" ] || { [ "$GT_FX_RC22" != 3 ] || { if [ "${GT_FX_MSG22:-}" = norole ]; then echo "NO ROLE-BOUND ROWS: EXAMINED NOTHING -- 2 S1 row(s) exist and NONE of them was judged"; else echo "PRE-LEDGER: 4 row(s) in ledger.jsonl, NONE of them S1."; fi; echo "COUNTS: examined 0 S1 spawn row(s) of 4 in ledger.jsonl;"; }; exit "$GT_FX_RC22"; }\n[ "${GT_FX_REFUSE:-}" != %s ] || { echo "stub %s: REFUSED by the fixture" >&2; exit 1; }\n[ %s != validate-h2-attestation.sh ] || echo "H2_ATTESTED v1 sprint=1 stub"\n[ %s != validate-steering-budget.sh ] || echo "steering-count 0"\nexit 0\n' \
      "$s" "$s" "$s" "$s" "$s" "$s" > "$d/stub/core/scripts/$s" || return 1
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
# g1with <gate-2 plan> <gate-1 plan basename>: the plan's gate1-plan: line names that file, and the file is a written gate-1 plan.
g1with() { local f; f="$(sed -n 's/^gate1-plan: //p' "$1" | sed -n 1p)"; [ -n "$f" ] && [ "${f##*/}" = "$2" ] && [ -f "$f" ] && grep -qx 'gate: 1' "$f"; }
st_g2r() { # gate 2 pass 2, prior QA reviewed the base: RERUN, OPEN12
  mkdir -p "$L/docs/reviews/s1" && printf '# QA Validation: 1-1\n\nreviewed-sha: %s\n' "$B" > "$L/docs/reviews/s1/1-1-qa-validation.md"
  gtrun "$1" "$2" g2r 2 - 1-1 2 --pass 2
  V_RERUN=0
  [ "$RC" = 0 ] && grep -qx 'gate: 2' "$P/1-1-g2-p2.plan" && ! grep -qx 'gate: rerun' "$P/1-1-g2-p2.plan" \
    && g1with "$P/1-1-g2-p2.plan" 1-1-g1-p1.plan && V_RERUN=1
  V_OPEN=$OPEN_SAME
}
st_g2k() { # gate 2 pass 2, prior QA reviewed the frozen sha: RERUN's control, OPEN12
  printf '# QA Validation: 1-1\n\nreviewed-sha: %s\n' "$WK" > "$L/docs/reviews/s1/1-1-qa-validation.md"
  gtrun "$1" "$2" g2k 2 - 1-1 2 --pass 2
  V_RERUNC=0
  [ "$RC" = 0 ] && grep -qx 'gate: 2' "$P/1-1-g2-p2.plan" && [ "$(nshards "$P/1-1-g2-p2.plan")" -gt 0 ] && V_RERUNC=1
  V_OPEN=$OPEN_SAME
}
# --- the pass-2 priors (BL-926): every column-0 reviewed-sha line of a merged review names one sha --------------
# seed_priors : the pass-1 priors under $L/docs/reviews/s1/, built once per world. 1-1 is a REAL merge-review-shards.sh
# output over shards reviewing MID (the commit between B and WK, so a fallback to --base reads differently): one
# reviewed-sha line per shard, non-adjacent, separated by the shard sections the merge writes. 1-2 is that file with
# its third reviewed-sha line naming B (A A B A A: two distinct values, the odd one in the middle). 1-3 is that file
# plus a fenced `reviewed-sha: B` block; 1-4 carries its one reviewed-sha line only inside a fence. The QA priors are
# byte-shape copies of a consumer merged QA validation (three shard sections, one reviewed-sha line each): 4-1 names
# WK on all three, the middle one backticked; 4-2 names WK, B, WK.
seed_priors() {
  local sd o k r="$L/docs/reviews/s1"
  MID="$(gitw "$L" rev-parse "$WK^")" || return 1
  sd="$WT/docs/reviews/s1/shards/1-1-code-review-$(printf '%s' "$MID" | cut -c1-12)"
  mkdir -p "$r" || return 1
  bash "$SCR/validate-handoff-evidence.sh" -C "$WT" --list-captures "$STORY" "$MID" > "$WD/capm" 2> /dev/null || return 1
  AI_DLC_REVIEW_SHARD_MIN_FILES=2 bash "$SCR/partition-review-diff.sh" --map "$WT" "$B" "$MID" --exclude-captures "$WD/capm" --shard-dir "$sd" > "$WD/mapm" 2> /dev/null || return 1
  for k in $(cut -f1 "$WD/mapm") cross; do
    { printf '# Code Review shard %s\n\nreviewed-sha: %s\nshard-verdict: APPROVED\nadvisor: called\n' "$k" "$MID"
      [ "$k" = cross ] || printf 'handovers: 0\n'
      printf '\n## Summary\nRead.\n\n## Findings\n\n### Critical (must fix before merge)\n\nNone.\n\n### Important (should fix, can be follow-up)\n\nNone.\n\n### Suggestions (optional improvements)\n\nNone.\n'
    } > "$sd/$k.md" || return 1
  done
  o="$r/1-1-code-review.md"
  ( cd "$L" && AI_DLC_PROJECT_ROOT="$_d" bash "$SCR/merge-review-shards.sh" "$sd" --gate code-review --out "$o" ) > "$WD/merge.out" 2>&1 || return 1
  grep -q '^MERGED: ' "$WD/merge.out" || return 1
  awk -v b="$B" '/^reviewed-sha:/ && ++n == 3 { print "reviewed-sha: " b; next } { print }' "$o" > "$r/1-2-code-review.md"
  awk -v b="$B" '{ print } NR == 1 { print ""; print "```"; print "reviewed-sha: " b; print "```" }' "$o" > "$r/1-3-code-review.md"
  awk -v m="$MID" '/^reviewed-sha:/ { next } { print } NR == 1 { print ""; print "```"; print "reviewed-sha: " m; print "```" }' "$o" > "$r/1-4-code-review.md"
  awk -v m="$MID" -v b="$B" '/^reviewed-sha:/ { print $0 " (base " b ")"; next } { print }' "$o" > "$r/1-5-code-review.md"
  qa_prior "$r/4-1-qa-validation.md" "$WK" "\`$WK\`" "$WK"
  qa_prior "$r/4-2-qa-validation.md" "$WK" "$B" "$WK"
}
qa_prior() { # <file> <sha of part 1> <of part 2> <of cross>
  { printf '# QA Validation: %s (merged from 3 shards)\n\n## Summary\n\nThree shards validated.\n\n## Verdict\n\nPASS\n' "${1##*/}"
    printf '\n## Shard: part 1\n\nshard-verdict: PASS\nreviewed-sha: %s\n\n## Findings\n\nNone.\n' "$2"
    printf '\n## Shard: part 2\n\nshard-verdict: PASS\nreviewed-sha: %s\n\n## Findings\n\nNone.\n' "$3"
    printf '\n## Shard: cross\n\nshard-verdict: PASS\nreviewed-sha: %s\n\n## Findings\n\nNone.\n' "$4"
  } > "$1"
}
nrs() { # <file> -> the count of distinct normalised reviewed-sha values, fences not consulted (the seeds carry none here)
  awk '/^reviewed-sha:/ { v = $0; sub(/^reviewed-sha:[[:space:]]*/, "", v); gsub(/[`[:space:]]/, "", v); if (!(v in S)) { S[v] = 1; n++ } } END { print n + 0 }' "$1"
}
mbase() { # <plan> -> the base line of the manifest the plan names
  local m; m="$(sed -n 's#^manifest: ##p' "$1" 2> /dev/null)"
  [ -f "$m" ] && awk -F'\t' '$1 == "base" { print $2 }' "$m"
}
p2run() { # <cell> <gt> <tag> <idx> <gate> : one pass-2 start, its exit kept beside its output
  gtrun "$1" "$2" "$3" 2 - "$4" "$5" --pass 2; printf '%s\n' "$RC" > "$WD/$3.rc"
}
st_pm() { # gate 1 pass 2 over the real merged prior, five identical lines: PRIORM
  p2run "$1" "$2" pm 1-1 1
  V_PRIORM=0
  [ "$RC" = 0 ] && grep -qx 'gate: 1' "$P/1-1-g1-p2.plan" && grep -qxF "prior: $L/docs/reviews/s1/1-1-code-review.md" "$P/1-1-g1-p2.plan" \
    && [ "$(mbase "$P/1-1-g1-p2.plan")" = "$MID" ] && ! grep -q '^gate-log: partition-review-diff' "$P/1-1-g1-p2.plan" && V_PRIORM=1
}
st_pd() { # gate 1 pass 2 over the same prior with its middle line naming B: PRIORD
  p2run "$1" "$2" pd 1-2 1
  V_PRIORD=0
  [ "$RC" = 1 ] && grep -q 'REFUSED prior-review: .* carries 2 distinct column-0 reviewed-sha values' "$WD/pd.err" && [ ! -e "$P/1-2-g1-p2.plan" ] && V_PRIORD=1
}
st_fe() { # gate 1 pass 2, the prior's A lines plus a fenced reviewed-sha B: FENCE
  p2run "$1" "$2" fe 1-3 1
  V_FENCE=0
  [ "$RC" = 0 ] && grep -qx 'gate: 1' "$P/1-3-g1-p2.plan" && [ "$(mbase "$P/1-3-g1-p2.plan")" = "$MID" ] && V_FENCE=1
}
st_fc() { # gate 1 pass 2, the prior's only reviewed-sha line inside a fence: FENCEC
  p2run "$1" "$2" fc 1-4 1
  V_FENCEC=0
  [ "$RC" = 1 ] && grep -q 'REFUSED prior-review: .* carries no column-0 reviewed-sha line outside a fence' "$WD/fc.err" && [ ! -e "$P/1-4-g1-p2.plan" ] && V_FENCEC=1
}
st_px() { # gate 1 pass 2, every line `reviewed-sha: <MID> (base <B>)`: PRIORX
  p2run "$1" "$2" px 1-5 1
  V_PRIORX=0
  [ "$RC" = 1 ] && grep -q 'REFUSED prior-review: .* carries a column-0 reviewed-sha value that is not a hex object name' "$WD/px.err" && [ ! -e "$P/1-5-g1-p2.plan" ] && V_PRIORX=1
}
st_qm() { # gate 2 pass 2 over a merged QA prior, three lines naming WK, the middle one backticked: QAM
  p2run "$1" "$2" qm 4-1 2
  V_QAM=0
  [ "$RC" = 0 ] && grep -qx 'gate: 2' "$P/4-1-g2-p2.plan" && [ "$(nshards "$P/4-1-g2-p2.plan")" -gt 0 ] \
    && grep -qxF "prior: $L/docs/reviews/s1/4-1-qa-validation.md" "$P/4-1-g2-p2.plan" && V_QAM=1
}
st_qd() { # gate 2 pass 2 over a merged QA prior naming WK, B, WK: QAD
  p2run "$1" "$2" qd 4-2 2
  V_QAD=0
  [ "$RC" = 1 ] && grep -q 'REFUSED prior-validation: .* carries 2 distinct column-0 reviewed-sha values' "$WD/qd.err" && [ ! -e "$P/4-2-g2-p2.plan" ] && V_QAD=1
}
# --- Rule A's gate-1 candidate (BL-931) -------------------------------------------------------------------------
# seed_ra : the rework worktree WRA off WK (the go-signal sha QA validated): G1, a commit adding a code line, then
# RSHA, a commit adding only a docs .md (records, never code). So --gate1-rerun answers RERUN from WK and SKIP from
# G1. XS is a commit off B on no branch: neither ancestor nor descendant of WK. The gate-2 indexes are dash form and
# their gate-1 files dot form, as the consumer's are; each start owns one index, so no start reads another's files.
# The lead checkout gets the two files the merge lifts its verdict reader from (it resolves them under its root).
seed_ra() {
  local i c g="" r=""
  WRA="$WD/wra"; RV="$L/docs/reviews/s1"
  gitw "$L" worktree add -q --detach "$WRA" "$WK" || return 1
  printf 'def a():\n    return 2\n' > "$WRA/src/a.py" && gitw "$WRA" commit -qam rework || return 1
  G1="$(gitw "$WRA" rev-parse HEAD)" || return 1
  mkdir -p "$WRA/docs" && printf '# notes\n' > "$WRA/docs/notes.md" && gitw "$WRA" add docs/notes.md && gitw "$WRA" commit -qm notes || return 1
  RSHA="$(gitw "$WRA" rev-parse HEAD)" || return 1
  XS="$(gitw "$L" commit-tree "${B}^{tree}" -p "$B" -m side)" || return 1
  for i in 5-1 6-1 7-1 8-1 9-1; do printf '# QA Validation: %s\n\nreviewed-sha: %s\n' "$i" "$WK" > "$RV/$i-qa-validation.md" || return 1; done
  for c in "$_d/core/skills/ai-dlc/steps/gate-validation.md" "$_d/.claude/skills/ai-dlc/steps/gate-validation.md"; do [ -f "$c" ] && { g="$c"; break; }; done
  for c in "$_d/core/team-roles/code-reviewer.md" "$_d/.claude/team-roles/code-reviewer.md"; do [ -f "$c" ] && { r="$c"; break; }; done
  [ -n "$g" ] && [ -n "$r" ] && cp "$g" "$L/.claude/skills/ai-dlc/steps/gate-validation.md" && cp "$r" "$L/.claude/team-roles/code-reviewer.md" || return 1
  # The shape the receipt checks first: the two bases separate, RERUN from WK and SKIP from G1.
  bash "$SCR/partition-review-diff.sh" --gate1-rerun "$WRA" "$WK" "$RSHA" > "$WD/ra-go.out" 2>&1
  bash "$SCR/partition-review-diff.sh" --gate1-rerun "$WRA" "$G1" "$RSHA" > "$WD/ra-g1.out" 2>&1
  printf '%s\n' "$WK" > "$WD/.GO"; printf '%s\n' "$G1" > "$WD/.G1"; printf '%s\n' "$RSHA" > "$WD/.RSHA"
}
g1f() { # <file> <verdict> <reviewed sha> : a serial gate-1 review file
  printf '# Code Review: %s\n\nreviewed-sha: %s\n\n## Verdict\n%s\n\n## Findings\n\nNone.\n' "${1##*/}" "$3" "$2" > "$1"
}
rarun() { # <cell> <gt> <tag> <idx> : one gate-2 pass-2 start over the rework worktree; its exit, plan and review listing kept
  local wt0="$WT"
  WT="$WRA"; gtrun "$1" "$2" "$3" 2 - "$4" 2 --pass 2; WT="$wt0"
  printf '%s\n' "$RC" > "$WD/$3.rc"
  rm -f "$WD/$3.plan"; [ ! -f "$P/$4-g2-p2.plan" ] || cp "$P/$4-g2-p2.plan" "$WD/$3.plan"
  ( cd "$RV" && for f in "${4%%-*}"[.-]*; do [ -f "$f" ] && printf '%s\n' "$f"; done ) > "$WD/$3.ls"
}
st_ra1() { # p1 APPROVED at B, p2 APPROVED at G1, a p3 .md.draft NEEDS_REWORK beside them: RA1
  g1f "$RV/5.1-code-review.md" APPROVED "$B"; g1f "$RV/5.1-code-review-p2.md" APPROVED "$G1"; g1f "$RV/5.1-code-review-p3.md.draft" NEEDS_REWORK "$G1"
  rarun "$1" "$2" ra1 5-1
  V_RA1=0
  [ "$RC" = 0 ] && grep -qx 'gate: 2' "$WD/ra1.plan" && grep -qxF "rule-a-base: gate1 $G1 $RV/5.1-code-review-p2.md" "$WD/ra1.plan" \
    && grep -q '^gate-log: GATE1-SKIP' "$WD/ra1.plan" && V_RA1=1
  V_OPEN=$OPEN_SAME
}
st_ra0() { # the RA1 world without the p2 file: RA0
  rm -f "$RV/5.1-code-review-p2.md"
  rarun "$1" "$2" ra0 5-1
  V_RA0=0
  [ "$RC" = 0 ] && grep -qx 'gate: 2' "$WD/ra0.plan" && grep -qxF "rule-a-base: qa $WK $RV/5-1-qa-validation.md" "$WD/ra0.plan" \
    && g1with "$WD/ra0.plan" 5.1-g1-p2.plan && V_RA0=1
  V_OPEN=$OPEN_SAME
}
st_ran() { # p9 APPROVED and p10 NEEDS_REWORK, both at G1: the numerically latest decides, RAN
  g1f "$RV/6.1-code-review-p9.md" APPROVED "$G1"; g1f "$RV/6.1-code-review-p10.md" NEEDS_REWORK "$G1"
  rarun "$1" "$2" ran 6-1
  V_RAN=0
  [ "$RC" = 0 ] && grep -qx 'gate: 2' "$WD/ran.plan" && grep -qxF "rule-a-base: qa $WK $RV/6-1-qa-validation.md" "$WD/ran.plan" \
    && grep -qF "6.1-code-review-p10.md reads verdict=NEEDS_REWORK" "$WD/ran.plan" && g1with "$WD/ran.plan" 6.1-g1-p11.plan && V_RAN=1
  V_OPEN=$OPEN_SAME
}
st_rax() { # the re-review APPROVED at XS, on a side branch neither ancestor nor descendant of the QA sha: RAX
  g1f "$RV/7.1-code-review-p2.md" APPROVED "$XS"
  rarun "$1" "$2" rax 7-1
  V_RAX=0
  [ "$RC" = 1 ] && grep -q 'REFUSED gate1-review: .* not ancestor-related; refusing to guess' "$WD/rax.err" && grep -q '  remedy: repair the gate-1 review record of story 7\.1 (a full-range re-review pass' "$WD/rax.err" \
    && [ ! -e "$WD/rax.plan" ] && V_RAX=1
  V_OPEN=$OPEN_SAME
}
st_raa() { # gate-1 files under both the dot and the dash form: RAA
  g1f "$RV/8.1-code-review-p2.md" APPROVED "$G1"; g1f "$RV/8-1-code-review.md" APPROVED "$G1"
  rarun "$1" "$2" raa 8-1
  V_RAA=0
  [ "$RC" = 1 ] && grep -q 'REFUSED gate1-review: gate-1 review files sit under 2 index forms (8-1, 8\.1) .* ambiguous' "$WD/raa.err" && [ ! -e "$WD/raa.plan" ] && V_RAA=1
  V_OPEN=$OPEN_SAME
}
st_ram() { # the re-review a MERGED review (the real merge's output over the shards seed_priors built), every line naming G1: RAM
  awk -v g="$G1" '/^reviewed-sha:/ { print "reviewed-sha: " g; next } { print }' "$RV/1-1-code-review.md" > "$RV/9.1-code-review-p2.md"
  rarun "$1" "$2" ram 9-1
  V_RAM=0
  [ "$RC" = 0 ] && grep -qx 'gate: 2' "$WD/ram.plan" && grep -qxF "rule-a-base: gate1 $G1 $RV/9.1-code-review-p2.md" "$WD/ram.plan" \
    && grep -q '^gate-log: GATE1-SKIP' "$WD/ram.plan" && V_RAM=1
  V_OPEN=$OPEN_SAME
}
# g3run <cell> <gt> <tag> <idx> <g3 sha> : gate 1 pass 2 over the rework worktree (frozen RSHA), after a gate-3 rework:
# the pass-1 gate-1 review APPROVED at G1 (so G1..RSHA, docs .md only, is the delta) and a g3 p1 plan naming <g3 sha>.
g3run() {
  local wt0="$WT"
  g1f "$RV/$4-code-review.md" APPROVED "$G1"
  printf 'story: %s\ngate: 3\npass: 1\nsha: %s\n' "$4" "$5" > "$P/$4-g3-p1.plan"
  WT="$WRA"; gtrun "$1" "$2" "$3" 2 - "$4" 1 --pass 2; WT="$wt0"
  rm -f "$WD/$3.plan"; [ ! -f "$P/$4-g1-p2.plan" ] || cp "$P/$4-g1-p2.plan" "$WD/$3.plan"
}
st_g3k() { # gate 3 judged G1, the rework after it is records only: G3K
  g3run "$1" "$2" g3k 10-1 "$G1"
  V_G3K=0
  [ "$RC" = 0 ] && grep -qx 'gate: skip' "$WD/g3k.plan" && grep -qx 'manifest: none' "$WD/g3k.plan" \
    && grep -q '^route: skip GATE1-SKIP: ' "$WD/g3k.plan" && [ "$(nshards "$WD/g3k.plan")" = 0 ] \
    && grep -qxF "rule-a-base: gate1 $G1 $RV/10-1-code-review.md" "$WD/g3k.plan" && grep -q '^next: gate-transition.sh 10-1 2 ' "$WD/g3k.plan" && V_G3K=1
  V_OPEN=$OPEN_SAME
}
st_g3c() { # gate 3 judged RSHA itself, so gate 1 at RSHA is the remedy gate 3 asked for: G3K's control
  g3run "$1" "$2" g3c 11-1 "$RSHA"
  V_G3C=0
  [ "$RC" = 0 ] && grep -qx 'gate: 1' "$WD/g3c.plan" && ! grep -q '^route: skip' "$WD/g3c.plan" \
    && grep -q '^gate-log: Rule A at gate 1: .* a re-review gate 3 asked for, so it runs$' "$WD/g3c.plan" && V_G3C=1
  V_OPEN=$OPEN_SAME
}
# --- gate 2 after a gate-3 rework (BL-1030) -------------------------------------------------------------------
# seed_g2g3 : worktrees off RSHA (the records-only commit after G1's code line), one frozen sha each: WR2 adds a docs .md
# (RSHA2), WRC a comment-only line in src/b.py, WRS a story-file edit outside its Dev Agent Record, WRD one inside it.
# The QA role file the merge's --read-verdict --gate qa lifts its verdict set from joins the lead checkout.
seed_g2g3() {
  local c q=""
  for c in "$_d/core/team-roles/qa.md" "$_d/.claude/team-roles/qa.md"; do [ -f "$c" ] && { q="$c"; break; }; done
  [ -n "$q" ] && cp "$q" "$L/.claude/team-roles/qa.md" || return 1
  WR2="$WD/wr2"; WRC="$WD/wrc"; WRS="$WD/wrs"; WRD="$WD/wrd"
  for c in "$WR2" "$WRC" "$WRS" "$WRD"; do gitw "$L" worktree add -q --detach "$c" "$RSHA" || return 1; done
  printf '# n2\n' > "$WR2/docs/n2.md" && gitw "$WR2" add docs/n2.md && gitw "$WR2" commit -qm n2 || return 1
  RSHA2="$(gitw "$WR2" rev-parse HEAD)" || return 1
  printf '# note\ndef b():\n    return 1\n' > "$WRC/src/b.py" && gitw "$WRC" commit -qam comment || return 1
  RSC="$(gitw "$WRC" rev-parse HEAD)" || return 1
  awk '/^## Dev Agent Record$/ { print "## Acceptance Criteria\n\nAC1 reworded.\n" } { print }' "$WRS/$STORY" > "$WD/story.ac" && cp "$WD/story.ac" "$WRS/$STORY" && gitw "$WRS" commit -qam ac || return 1
  RSS="$(gitw "$WRS" rev-parse HEAD)" || return 1
  awk '/^## Dev Agent Record$/ { print; print ""; print "Rework note."; next } { print }' "$WRD/$STORY" > "$WD/story.dar" && cp "$WD/story.dar" "$WRD/$STORY" && gitw "$WRD" commit -qam dar || return 1
  RSD="$(gitw "$WRD" rev-parse HEAD)" || return 1
  # The shape the arms need: G1 < RSHA < each frozen sha; the strict code class separates WK..RSHA2 (G1's code) from G1..RSHA2.
  { gitw "$WRA" merge-base --is-ancestor "$G1" "$RSHA" && gitw "$WRA" merge-base --is-ancestor "$RSHA" "$RSHA2" \
    && ! gitw "$WRA" merge-base --is-ancestor "$G1" "$WK"; } || return 1
}
qa_one() { # <file> <reviewed sha> <verdict> : a serial QA validation file
  printf '# QA Validation: %s\n\nreviewed-sha: %s\n\n## Verdict\n\n%s\n\n## Findings\n\nNone.\n' "${1##*/}" "$2" "$3" > "$1"
}
# g2g3run <cell> <gt> <tag> <idx> <worktree> <QA prior sha> <g3 sha or -> [verdict] : gate 2 pass 2 over <worktree>.
g2g3run() {
  local wt0="$WT" i="$4"
  qa_one "$RV/$i-qa-validation.md" "$6" "${8:-PASS}"
  [ "$7" = - ] || printf 'story: %s\ngate: 3\npass: 1\nsha: %s\n' "$i" "$7" > "$P/$i-g3-p1.plan"
  WT="$5"; gtrun "$1" "$2" "$3" 2 - "$i" 2 --pass 2; WT="$wt0"
  rm -f "$WD/$3.plan"; [ ! -f "$P/$i-g2-p2.plan" ] || cp "$P/$i-g2-p2.plan" "$WD/$3.plan"
}
# g2full <tag> <gate-log regex> : the pass wrote a gate-2 plan, no skip, and the gate-log line names the arm's own reason.
g2full() {
  [ "$RC" = 0 ] && grep -qx 'gate: 2' "$WD/$1.plan" && ! grep -q '^route: skip' "$WD/$1.plan" && grep -qE "^gate-log: Rule A at gate 2: .*$2" "$WD/$1.plan"
}
st_sk() { # QA PASS at G1, g3 at RSHA, frozen RSHA2, records only: G2K
  g2g3run "$1" "$2" sk 12-1 "$WR2" "$G1" "$RSHA"
  V_G2K=0
  [ "$RC" = 0 ] && grep -qx 'gate: skip' "$WD/sk.plan" && grep -qx 'manifest: none' "$WD/sk.plan" \
    && grep -q '^route: skip GATE2-SKIP: ROUTE: ' "$WD/sk.plan" && [ "$(nshards "$WD/sk.plan")" = 0 ] \
    && grep -qxF "g3-base: gate2 go=$G1 g3=$RSHA p1" "$WD/sk.plan" && grep -q '^next: gate-transition.sh 12-1 3 ' "$WD/sk.plan" \
    && ! grep -q '^next:.* close' "$WD/sk.plan" && V_G2K=1
  V_OPEN=$OPEN_SAME
}
st_sr1() { # a comment-only code edit after the g3 sha: G2R1
  g2g3run "$1" "$2" sr1 12-2 "$WRC" "$G1" "$RSHA"
  V_G2R1=0; g2full sr1 'FULL: .*changes 1 code path\(s\), first src/b.py' && V_G2R1=1
  V_OPEN=$OPEN_SAME
}
st_sr2() { # GO -> code C -> g3 -> records -> frozen, an APPROVED gate-1 review at C: Rule A sees only the records: G2R2
  g1f "$RV/12-3-code-review.md" APPROVED "$G1"
  g2g3run "$1" "$2" sr2 12-3 "$WR2" "$WK" "$RSHA"
  V_G2R2=0
  g2full sr2 'FULL: .*changes 1 code path\(s\), first src/a.py' && grep -qxF "rule-a-base: gate1 $G1 $RV/12-3-code-review.md" "$WD/sr2.plan" && ! grep -qx 'gate: rerun' "$WD/sr2.plan" && V_G2R2=1
  V_OPEN=$OPEN_SAME
}
st_sr3() { # the frozen sha is the sha gate 3 judged: G2R3
  g2g3run "$1" "$2" sr3 12-4 "$WR2" "$G1" "$RSHA2"
  V_G2R3=0; g2full sr3 'FULL: the frozen sha is the sha gate 3 judged' && V_G2R3=1
  V_OPEN=$OPEN_SAME
}
st_sr4() { # the QA sha is not an ancestor of the g3 sha: G2R4
  g2g3run "$1" "$2" sr4 12-5 "$WR2" "$G1" "$WK"
  V_G2R4=0; g2full sr4 'FULL: the go-signal sha .* is not an ancestor of the gate-3 sha' && V_G2R4=1
  V_OPEN=$OPEN_SAME
}
st_sr5() { # the QA prior reads NEEDS_REWORK: G2R5
  g2g3run "$1" "$2" sr5 12-6 "$WR2" "$G1" "$RSHA" NEEDS_REWORK
  V_G2R5=0; g2full sr5 'QA file .* is not read as PASS' && V_G2R5=1
  V_OPEN=$OPEN_SAME
}
st_sr6() { # a story-file edit outside its Dev Agent Record: G2R6
  g2g3run "$1" "$2" sr6 12-7 "$WRS" "$G1" "$RSHA"
  V_G2R6=0; g2full sr6 'FULL: the story file .* changes outside its Dev Agent Record' && V_G2R6=1
  V_OPEN=$OPEN_SAME
}
st_sr7() { # no g3 plan: G2R7
  g2g3run "$1" "$2" sr7 12-8 "$WR2" "$G1" -
  V_G2R7=0
  [ "$RC" = 0 ] && grep -qx 'gate: 2' "$WD/sr7.plan" && ! grep -q '^route: skip' "$WD/sr7.plan" && ! grep -q 'Rule A at gate 2' "$WD/sr7.plan" && [ ! -e "$P/12-8-g3-p1.plan" ] && V_G2R7=1
  V_OPEN=$OPEN_SAME
}
st_sd() { # a story-file edit inside its Dev Agent Record, the canonical copy folded: G2D, G2R6's control
  local c0="$WD/story.canon"
  cp "$L/$STORY" "$c0" && cp "$WRD/$STORY" "$L/$STORY"
  g2g3run "$1" "$2" sd 12-9 "$WRD" "$G1" "$RSHA"
  cp "$c0" "$L/$STORY"
  V_G2D=0
  [ "$RC" = 0 ] && grep -qx 'gate: skip' "$WD/sd.plan" && grep -q '^route: skip GATE2-SKIP: ' "$WD/sd.plan" && V_G2D=1
  V_OPEN=$OPEN_SAME
}
st_sw1() { # pass 3 at gate 2 after the GATE2-SKIP at pass 2 (12-1): the prior is the pass-1 file: G2W1
  local wt0="$WT"
  WT="$WR2"; gtrun "$1" "$2" sw1 2 - 12-1 2 --pass 3; WT="$wt0"
  rm -f "$WD/sw1.plan"; [ ! -f "$P/12-1-g2-p3.plan" ] || cp "$P/12-1-g2-p3.plan" "$WD/sw1.plan"
  V_G2W1=0
  [ "$RC" = 0 ] && ! grep -q 'REFUSED prior-validation' "$WD/sw1.err" && grep -qxF "prior: $RV/12-1-qa-validation.md" "$WD/sw1.plan" && grep -qx 'gate: skip' "$WD/sw1.plan" && V_G2W1=1
  V_OPEN=$OPEN_SAME
}
st_sw2() { # pass 3 at gate 1 after the GATE1-SKIP at pass 2 (10-1, G3K): the prior is the pass-1 file: G2W2
  local wt0="$WT"
  WT="$WRA"; gtrun "$1" "$2" sw2 2 - 10-1 1 --pass 3; WT="$wt0"
  rm -f "$WD/sw2.plan"; [ ! -f "$P/10-1-g1-p3.plan" ] || cp "$P/10-1-g1-p3.plan" "$WD/sw2.plan"
  V_G2W2=0
  [ "$RC" = 0 ] && ! grep -q 'REFUSED prior-review' "$WD/sw2.err" && grep -qxF "prior: $RV/10-1-code-review.md" "$WD/sw2.plan" && grep -qx 'gate: skip' "$WD/sw2.plan" && V_G2W2=1
  V_OPEN=$OPEN_SAME
}
st_sw3() { # pass 3 at gate 2 after a DISPATCHED pass 2 (plan gate: 2) that left no QA file: the walk stops, prior-validation refuses: G2W3
  local wt0="$WT"
  qa_one "$RV/12-10-qa-validation.md" "$G1" PASS
  printf 'story: 12-10\ngate: 2\npass: 2\n' > "$P/12-10-g2-p2.plan"
  WT="$WR2"; gtrun "$1" "$2" sw3 2 - 12-10 2 --pass 3; WT="$wt0"
  V_G2W3=0
  [ "$RC" = 1 ] && grep -q 'REFUSED prior-validation' "$WD/sw3.err" && [ ! -e "$P/12-10-g2-p3.plan" ] && V_G2W3=1
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
O12=1

st_g1 g1 "$GTR"; [ "$V_OPEN" = 1 ] || O12=0
[ "$V_MAP" = 1 ] && ok "MAP gate-1 plan carries $(grep -c . "$WD/g1.shards") shard line(s), cmp-equal to a standalone --map with --exclude-captures" \
  || bad "MAP gate-1 rc=$RC: plan shard lines differ from the standalone --map, or are absent ($(head -3 "$WD/g1.err" | tr '\n' ' '))"
sed '1s/^./X/' "$WD/sa2" > "$WD/sa2.alt"
cmp -s "$WD/g1.shards" "$WD/sa2.alt" && bad "MAP control: a one-byte-altered map is still cmp-equal" || ok "MAP control: a one-byte-altered standalone map is NOT cmp-equal to the plan"
st_join join
[ "$J_OK" = 1 ] && ok "JOIN the real guard ALLOWS a sharded code-reviewer brief citing the plan gate-transition.sh printed ($(head -1 "$WD/g1.out" | sed "s#^$L/##"))" \
  || bad "JOIN the program's own plan read $J_ODEC from the guard (rc $J_OGRC): $(printf '%s' "$J_OWHY" | cut -c1-240)"
[ "$J_SHA" = 1 ] && ok "JOIN control: the byte-identical brief citing the plan's wrong-sha twin is DENIED (partition manifest)" \
  || bad "JOIN control: the wrong-sha twin was not denied on the partition manifest"
[ "$J_NO" = 1 ] && ok "JOIN control: the same brief with no gate-plan line is DENIED" || bad "JOIN control: the no-plan brief was not denied for its missing gate-plan line"
[ "$J_DIFF" = 1 ] && ok "JOIN control: the allow and wrong-sha briefs differ only in their gate-plan line" || bad "JOIN control: the allow and wrong-sha briefs differ outside the gate-plan line"

st_g1x g1x "$GTR"; [ "$V_OPEN" = 1 ] || O12=0
[ "$V_MAPX" = 1 ] && ok "MAPX at min-files 8 the plan reads manifest: none, no shard line, route: serial $(cut -c1-48 "$WD/sa8")..." \
  || bad "MAPX rc=$RC: plan is not the standalone SERIAL answer ($(grep -E '^(manifest|route):' "$P/1-8-g1-p1.plan" 2> /dev/null | tr '\n' ' '))"
[ "$(nshards "$WD/sa8n")" -gt 0 ] && ok "MAPX control: the same tree WITHOUT --exclude-captures partitions ($(nshards "$WD/sa8n") shard lines)" \
  || bad "MAPX control: without --exclude-captures the tree does not partition, so MAPX cannot discriminate"

st_g2s g2s "$GTR"; [ "$V_OPEN" = 1 ] || O12=0
[ "$V_DAR" = 1 ] && ok "DAR stale Dev Agent Record: exit 1, REFUSED dar-fold, and the pre-seeded plan is gone (no plan on disk)" \
  || bad "DAR rc=$RC: $(grep -c 'REFUSED dar-fold' "$WD/g2s.err") dar-fold line(s), plan on disk: $([ -e "$P/1-1-g2-p1.plan" ] && echo yes || echo no)"

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
[ "$V_RERUN" = 1 ] && ok "RERUN GATE1-RERUN at gate 2 pass 2: gate 1 runs together, a gate: 2 plan naming the written gate-1 plan" \
  || bad "RERUN rc=$RC: $(grep -E '^(gate|manifest|route):' "$P/1-1-g2-p2.plan" 2> /dev/null | tr '\n' ' ')"
st_g2k g2k "$GTR"; [ "$V_OPEN" = 1 ] || O12=0
[ "$V_RERUNC" = 1 ] && ok "RERUN control: GATE1-SKIP at gate 2 pass 2 writes gate: 2 with $(nshards "$P/1-1-g2-p2.plan") shard lines" \
  || bad "RERUN control rc=$RC: $(head -3 "$WD/g2k.err" | tr '\n' ' ')"
seed_priors || { echo "FIXTURE BROKEN: the pass-1 priors did not build (the real merge-review-shards.sh merge over MID's shards refused: $(head -2 "$WD/merge.out" | tr '\n' ' '))" >&2; exit 2; }
# The seeds separate what the arms need: the real merge wrote more than one line naming one sha, the A A B A A copy
# names two, and the backticked QA prior reads one distinct value only once normalised.
[ "$(grep -c '^reviewed-sha:' "$L/docs/reviews/s1/1-1-code-review.md")" -ge 2 ] && [ "$(nrs "$L/docs/reviews/s1/1-1-code-review.md")" = 1 ] \
  && [ "$(nrs "$L/docs/reviews/s1/1-2-code-review.md")" = 2 ] && [ "$(nrs "$L/docs/reviews/s1/1-5-code-review.md")" = 1 ] \
  && [ "$(grep -c '^reviewed-sha: .* (base ' "$L/docs/reviews/s1/1-5-code-review.md")" = "$(grep -c '^reviewed-sha:' "$L/docs/reviews/s1/1-5-code-review.md")" ] && [ "$MID" != "$B" ] && [ "$MID" != "$WK" ] \
  && [ "$(awk '/^reviewed-sha:/ { print $2 }' "$L/docs/reviews/s1/4-1-qa-validation.md" | sort -u | grep -c .)" = 2 ] \
  && [ "$(nrs "$L/docs/reviews/s1/4-1-qa-validation.md")" = 1 ] \
  || { echo "FIXTURE BROKEN: the seeded priors do not separate one distinct value from two, or raw from normalised" >&2; exit 2; }
st_pm pm "$GTR"; [ "$V_OPEN" = 1 ] || O12=0
[ "$V_PRIORM" = 1 ] && ok "PRIORM gate 1 pass 2 over a real merged prior ($(grep -c '^reviewed-sha:' "$L/docs/reviews/s1/1-1-code-review.md") reviewed-sha lines, one sha): plan written, its prior line names the file, the manifest base is the prior's sha" \
  || bad "PRIORM rc=$RC: $(head -2 "$WD/pm.err" | tr '\n' ' ') base=$(mbase "$P/1-1-g1-p2.plan")"
st_pd pd "$GTR"; [ "$V_OPEN" = 1 ] || O12=0
[ "$V_PRIORD" = 1 ] && ok "PRIORD control: the same prior with its middle line naming the base exits 1, REFUSED prior-review naming 2 distinct values, no plan" \
  || bad "PRIORD rc=$RC: $(head -2 "$WD/pd.err" | tr '\n' ' ')"
st_px px "$GTR"; [ "$V_OPEN" = 1 ] || O12=0
[ "$V_PRIORX" = 1 ] && ok "PRIORX gate 1 pass 2 over a prior whose lines read 'reviewed-sha: <sha> (base <sha>)': exit 1, REFUSED prior-review naming a value that is not a hex object name, no plan" \
  || bad "PRIORX rc=$RC: $(head -2 "$WD/px.err" | tr '\n' ' ')"
st_fe fe "$GTR"; [ "$V_OPEN" = 1 ] || O12=0
[ "$V_FENCE" = 1 ] && ok "FENCE a fenced reviewed-sha naming the base is not read: gate 1 pass 2 proceeds with manifest base $(printf '%s' "$MID" | cut -c1-12)" \
  || bad "FENCE rc=$RC: $(head -2 "$WD/fe.err" | tr '\n' ' ')"
st_fc fc "$GTR"; [ "$V_OPEN" = 1 ] || O12=0
[ "$V_FENCEC" = 1 ] && ok "FENCE control: a prior whose only reviewed-sha line is fenced exits 1, REFUSED prior-review naming no line outside a fence" \
  || bad "FENCE control rc=$RC: $(head -2 "$WD/fc.err" | tr '\n' ' ')"
st_qm qm "$GTR"; [ "$V_OPEN" = 1 ] || O12=0
[ "$V_QAM" = 1 ] && ok "QAM gate 2 pass 2 over a merged QA prior, three lines naming the frozen sha (one backticked): gate: 2 with $(nshards "$P/4-1-g2-p2.plan") shard lines" \
  || bad "QAM rc=$RC: $(head -2 "$WD/qm.err" | tr '\n' ' ')"
st_qd qd "$GTR"; [ "$V_OPEN" = 1 ] || O12=0
[ "$V_QAD" = 1 ] && ok "QAD control: a merged QA prior naming WK, B, WK exits 1, REFUSED prior-validation naming 2 distinct values, no plan" \
  || bad "QAD rc=$RC: $(head -2 "$WD/qd.err" | tr '\n' ' ')"
# BL-926's receipt reads the outputs the PRIORM, PRIORD, QAM and QAD starts above left on disk; it starts no subject.
bash "$HERE/receipt-bl926.sh" "$WD" "$L" "$P" > "$WD/r926.out" 2>&1; r926=$?
case "$r926" in
  0) sed -n '1p' "$WD/r926.out"; ok "BL-926 receipt: the multi-line identical priors proceed and the distinct-value priors refuse" ;;
  9) echo "FIXTURE BROKEN: receipt-bl926.sh refused to measure: $(head -1 "$WD/r926.out")" >&2; exit 2 ;;
  *) bad "BL-926 receipt exited $r926: $(tr '\n' ' ' < "$WD/r926.out" | cut -c1-300)" ;;
esac
# --- Rule A's gate-1 candidate (BL-931): six starts of the real subject, then BL-931's receipt over their outputs ----
seed_ra || { echo "FIXTURE BROKEN: the Rule A rework world did not build (the worktree off WK, its two commits, or the lifted role files)" >&2; exit 2; }
for s in ra1:RA1 ra0:RA0 ran:RAN rax:RAX raa:RAA ram:RAM; do
  t="${s%%:*}"; a="${s#*:}"
  "st_$t" "$t" "$GTR"; [ "$V_OPEN" = 1 ] || O12=0
  eval "v=\$V_$a"
  if [ "$v" = 1 ]; then
    ok "$a gate 2 pass 2 over the Rule A world: $(grep -E '^(gate|rule-a-base):' "$WD/$t.plan" 2> /dev/null | tr '\n' ' ')$(grep -m1 'REFUSED' "$WD/$t.err" | cut -c1-120)"
  else bad "$a rc=$RC: $(grep -E '^(gate|rule-a-base|next):' "$WD/$t.plan" 2> /dev/null | tr '\n' ' ') $(head -3 "$WD/$t.err" | tr '\n' ' ' | cut -c1-400)"; fi
done
bash "$HERE/receipt-bl931.sh" "$WD" "$RV" > "$WD/r931.out" 2>&1; r931=$?
case "$r931" in
  0) sed -n '1p' "$WD/r931.out"; ok "BL-931 receipt: an APPROVED latest gate-1 re-review of the rework is Rule A's base, and the next: line names the gate-1 index form" ;;
  9) echo "FIXTURE BROKEN: receipt-bl931.sh refused to measure: $(head -1 "$WD/r931.out")" >&2; exit 2 ;;
  *) bad "BL-931 receipt exited $r931: $(tr '\n' ' ' < "$WD/r931.out" | cut -c1-300)" ;;
esac
st_g3k g3k "$GTR"; [ "$V_OPEN" = 1 ] || O12=0
[ "$V_G3K" = 1 ] && ok "G3K gate 1 pass 2 after a gate-3 rework over a records-only delta: gate: skip, route: skip GATE1-SKIP, no shard line" \
  || bad "G3K rc=$RC: $(grep -E '^(gate|route|rule-a-base|next|gate-log):' "$WD/g3k.plan" 2> /dev/null | tr '\n' ' ' | cut -c1-400) $(head -3 "$WD/g3k.err" | tr '\n' ' ' | cut -c1-300)"
st_g3c g3c "$GTR"; [ "$V_OPEN" = 1 ] || O12=0
[ "$V_G3C" = 1 ] && ok "G3K control: the same pass at the sha gate 3 judged is the remedy gate 3 asked for: gate: 1, a seat" \
  || bad "G3K control rc=$RC: $(grep -E '^(gate|route|gate-log):' "$WD/g3c.plan" 2> /dev/null | tr '\n' ' ' | cut -c1-400) $(head -3 "$WD/g3c.err" | tr '\n' ' ' | cut -c1-300)"
seed_g2g3 || { echo "FIXTURE BROKEN: the gate-2-after-gate-3 world did not build (qa.md, the four worktrees off RSHA, or G1 < RSHA < RSHA2 and G1 not below WK)" >&2; exit 2; }
st_sk sk "$GTR"; [ "$V_OPEN" = 1 ] || O12=0
[ "$V_G2K" = 1 ] && ok "G2K gate 2 pass 2 after a gate-3 rework over a records-only delta from the QA sha: gate: skip, route: skip GATE2-SKIP, no shard line, next: names gate 3" \
  || bad "G2K rc=$RC: $(grep -E '^(gate|route|g3-base|next|gate-log):' "$WD/sk.plan" 2> /dev/null | tr '\n' ' ' | cut -c1-400) $(head -3 "$WD/sk.err" | tr '\n' ' ' | cut -c1-300)"
for s in sr1:G2R1:"a comment-only code edit after the g3 sha" sr2:G2R2:"GO -> code -> g3 -> records with an APPROVED gate-1 review at the code commit (the delta from GO carries the code)" \
         sr3:G2R3:"the frozen sha is the g3 sha" sr4:G2R4:"the QA sha is not an ancestor of the g3 sha" sr5:G2R5:"the QA prior reads NEEDS_REWORK" \
         sr6:G2R6:"a story-file edit outside its Dev Agent Record" sr7:G2R7:"no g3 plan" sd:G2D:"a story-file edit inside its Dev Agent Record (G2R6's control) skips"; do
  t="${s%%:*}"; r="${s#*:}"; a="${r%%:*}"; w="${r#*:}"
  "st_$t" "$t" "$GTR"; [ "$V_OPEN" = 1 ] || O12=0
  eval "v=\$V_$a"
  if [ "$v" = 1 ]; then ok "$a gate 2 pass 2 after a gate-3 rework, $w: $(grep -E '^(gate|route):' "$WD/$t.plan" 2> /dev/null | tr '\n' ' ' | cut -c1-120)"
  else bad "$a rc=$RC ($w): $(grep -E '^(gate|route|rule-a-base|gate-log: Rule A at gate 2)' "$WD/$t.plan" 2> /dev/null | tr '\n' ' ' | cut -c1-300) $(grep -o 'Rule A at gate 2.*' "$WD/$t.plan" 2> /dev/null | cut -c1-400) $(head -3 "$WD/$t.err" | tr '\n' ' ' | cut -c1-300)"; fi
done
st_sw1 sw1 "$GTR"; [ "$V_OPEN" = 1 ] || O12=0
[ "$V_G2W1" = 1 ] && ok "G2W1 gate 2 pass 3 after a GATE2-SKIP at pass 2 reads the pass-1 QA file: no prior-validation refusal, a gate: skip plan naming that file" \
  || bad "G2W1 rc=$RC: $(grep -E '^(gate|prior):' "$WD/sw1.plan" 2> /dev/null | tr '\n' ' ') $(head -3 "$WD/sw1.err" | tr '\n' ' ' | cut -c1-300)"
st_sw2 sw2 "$GTR"; [ "$V_OPEN" = 1 ] || O12=0
[ "$V_G2W2" = 1 ] && ok "G2W2 gate 1 pass 3 after a GATE1-SKIP at pass 2 reads the pass-1 review file: no prior-review refusal, a gate: skip plan naming that file" \
  || bad "G2W2 rc=$RC: $(grep -E '^(gate|prior):' "$WD/sw2.plan" 2> /dev/null | tr '\n' ' ') $(head -3 "$WD/sw2.err" | tr '\n' ' ' | cut -c1-300)"
st_sw3 sw3 "$GTR"; [ "$V_OPEN" = 1 ] || O12=0
[ "$V_G2W3" = 1 ] && ok "G2W3 gate 2 pass 3 after a dispatched pass 2 with no QA file while the pass-1 file exists: exit 1, REFUSED prior-validation, no plan" \
  || bad "G2W3 rc=$RC: $(head -3 "$WD/sw3.err" | tr '\n' ' ' | cut -c1-300) plan $([ -e "$P/12-10-g2-p3.plan" ] && echo present || echo absent)"
[ "$O12" = 1 ] && ok "OPEN12 the live OPEN is byte-identical across every gate-1 and gate-2 run" || bad "OPEN12 a gate-1 or gate-2 run moved the live OPEN"

st_g3x g3x "$GT3"
[ "$V_G3X" = 1 ] && ok "G3X gate 3 with the H2 arm refusing: exit 1, no g3 plan, OPEN byte-identical" \
  || bad "G3X rc=$RC: plan $([ -e "$P/1-1-g3-p1.plan" ] && echo present || echo absent), OPEN same=$OPEN_SAME"

st_g3q g3q "$GT3"
[ "$V_G3Q" = 1 ] && ok "G3Q gate 3 with the Check 22 arm exiting 1: exit 1, REFUSED check-22, OPEN byte-identical" \
  || bad "G3Q rc=$RC: $(head -3 "$WD/g3q.err" | tr '\n' ' ')"

st_g3 g3 "$GT3"
[ "$V_G3" = 1 ] && ok "G3 gate 3 passing: exit 0, the plan carries nonce: $X, and OPEN now reads it" \
  || bad "G3 rc=$RC nonce=[$X]: $(head -3 "$WD/g3.err" | tr '\n' ' ')"
[ "$V_OPENC" = 1 ] && ok "OPEN12 control: the gate-3 open moves OPEN" || bad "OPEN12 control: gate 3 left OPEN unchanged, so OPEN12 cannot discriminate"

st_cx cx "$GTR"
[ "$V_CLOSEX" = 1 ] && ok "CLOSEX close over a 26 FAIL ledger: exit 1, no '26 PASS' row refused, no close plan" \
  || bad "CLOSEX rc=$RC: $(head -2 "$WD/cx.err" | tr '\n' ' ')"

st_c c "$GTR"
[ "$V_CLOSE" = 1 ] && ok "CLOSE close with 26 PASS: exit 0, gate: close, nonce: $X" || bad "CLOSE rc=$RC: $(head -2 "$WD/c.err" | tr '\n' ' ')"
st_g3p g3p "$GT3"
[ "$V_G3P" = 1 ] && ok "G3P gate 3 with the Check 22 arm exiting 3 (PRE-LEDGER): exit 0, g3 plan written, it carries the PRE-LEDGER gate-log line" \
  || bad "G3P rc=$RC: $(head -3 "$WD/g3p.err" | tr '\n' ' ')"
st_g3n g3n "$GT3"
[ "$V_G3N" = 1 ] && ok "G3N gate 3 with the Check 22 arm exiting 3 (NO ROLE-BOUND ROWS): exit 0, the plan carries that message and no PRE-LEDGER" \
  || bad "G3N rc=$RC: $(head -3 "$WD/g3n.err" | tr '\n' ' ')"
st_cmx cmx "$GTR"
[ "$V_CLOSEMX" = 1 ] && ok "CLOSEMX close over a storyless s1 verdict whose ledger lacks 26 PASS: exit 1, REFUSED close, no close plan (a newer s12 verdict with 26 PASS is not taken)" \
  || bad "CLOSEMX rc=$RC: $(head -2 "$WD/cmx.err" | tr '\n' ' ')"
st_cm cm "$GTR"
[ "$V_CLOSEM" = 1 ] && ok "CLOSEM close with no g3 plan over the newest storyless implementation-s1 verdict with 26 PASS: exit 0, gate: close, nonce: $NM2, a gate3-scope line" \
  || bad "CLOSEM rc=$RC: $(head -2 "$WD/cm.err" | tr '\n' ' ')"
st_cp cp "$GTR"
[ "$V_CLOSEP" = 1 ] && ok "CLOSEP a story-slug verdict ($NM3) wins over a newer storyless one ($NM2): no gate3-scope line" \
  || bad "CLOSEP rc=$RC: $(grep -E '^(nonce|gate3-scope):' "$P/3-1-gclose-p1.plan" 2> /dev/null | tr '\n' ' ') $(head -2 "$WD/cp.err" | tr '\n' ' ')"

echo
report_end gate-transition
