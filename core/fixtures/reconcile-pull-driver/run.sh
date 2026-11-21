#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
# reconcile-pull-driver/run.sh -- reconcile/pull.sh, the engine-update pull driver (BL-1190): its detectors run
# once per `apply`, an F mismatch runs them fresh, only an ASK family asks, and an ASK decided without the
# operator never reaches the tree.
#
# Usage: bash core/fixtures/reconcile-pull-driver/run.sh   (from the repository root)
# Exit:  0 every assertion holds (or SKIP on a consumer whose engine predates the driver); 1 a regression;
#        2 fixture broken.
#
# THE ARMS. Each drives a WORLD COPY of reconcile/ in which the seven detectors are stub-wrapped
# (seed.sh prd_instrument): every detector START appends one row to a world-local log, marked `pre` while the
# consumer's session-driver file still reads `# driver v1` (the pull rewrites it to theirs) and `post` after.
#   a    pull.sh apply: one render (emit-report.sh is wrapped too: a start without --verify), every detector
#        starts pre-write, and no (detector, argv) starts twice pre-write.
#   d    one model resolution round (a's classify row resolved, apply re-run): exactly one more render.
#   b    theirs advanced after a dry run: F differs, apply.sh with that run's store runs the detectors fresh,
#        and ends UPSTREAM-MOVED, exit 1, nothing written.
#   c    a hand-edited region, apply.sh with AI_DLC_PULL_RUN unset: exit 1, nothing written.
#   c2   an ORPHANED-UNKNOWN ask settled by deleting the file, no answer: ASK-UNANSWERED, exit 3, nothing
#        written; with a hook-written answer quoting the digest, the same apply proceeds.
#   c2b  a direct readopt-override.sh --merge conflict resolved by hand: pull.sh finish and apply.sh --finish each ASK-UNANSWERED, exit 3;
#        with a hook-written answer quoting the digest, no ASK.
#   c3   a record a pre-driver --verify wrote (no driver sidecar) carrying an ASK row that no longer renders:
#        pull.sh apply replaces it and reaches exit 0.
#   c4   a stored detector call answers its exact argv and never another argv.
#   e    a staged-only change moves F.   f  a stamp edit moves F.   (control: F is stable over one state)
#   g    a render with a refused detector keeps no store: the verify re-runs every detector.
#   h    a clean override merge, an extension re-read and a pristine delete: a DECIDE row each, no ASK row;
#        its twin, a consumer-MODIFIED file theirs deletes: exactly one ASK delete-consumer-modified, no DECIDE.
#   i    a conflict hunk from pull.sh merge: exactly one ASK row.
#   p    pre-gate repair: one WORKLIST pre-gate-repair row; a validator without STATUSLESS-ENTRY: SKIP, no row;
#        p2: the validator's `FAIL: STATUSLESS` form gives the same one row.
#   j    a blend block merged with no answer: pull.sh finish ASK-UNANSWERED, exit 3; answered, with a judgment-only
#        block beside it (never a ledger row), finish exits 0.
#        c2b also: markers still present at --finish, and a plain apply.sh, each refuse the open row.
#   k    a delete apply.sh cannot prove pristine: one ASK delete-consumer-modified, one ledger row, exit 3;
#        answered, the apply proceeds.
#   l    theirs moved: the earlier theirs' answer does not silence the row.
#   q    the PR body renders this pull's decision rows (a model's six-column row included), each once, and never
#        a row an earlier pull left in the file.
#   pull.sh deliver on world a after finish, against a bare file:// origin, a stub gh and consumer hooks:
#   i    operator state from before apply (modified, untracked, staged, staged rename) stays out of the commit
#        and keeps its state.   i-b  a dirty file appended to after apply stays out.   i-c  the pre-commit hook
#        sees only the selected paths; nothing of the pull's is left staged after.   ii  the report, dirty at the
#        snapshot, is committed (always-stage).   ii-b  the gate record pull-artifacts names is committed, an
#        older one is not.   iii  a staged deletion and a staged rename commit whole.
#   v    (world v, no apply) no snapshot: NOTE deliver-no-snapshot and every changed path committed.
#   iv   (world v) an oversized region: the body gh receives is under 60000 bytes with a pointer line, and was on
#        disk at pre-push.
#   vi   an answer citing the 8-hex digest prefix: pull.sh finish and pull.sh apply print NOTE ask-short-cite
#        beside the re-asked ledger row; a USER_PAUSE-shaped record citing it: no NOTE.
#   vii  (world s, after c2) two off-branch ASK rounds keep round 1's dirty snapshot; deliver commits the answer
#        history the hook appended between rounds.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }
. "$HERE/../lib/world.sh" || { echo "FIXTURE BROKEN: cannot source lib/world.sh" >&2; exit 2; }
. "$HERE/../lib/layout.sh" || { echo "FIXTURE BROKEN: cannot source lib/layout.sh" >&2; exit 2; }
[ -f "$HERE/seed.sh" ] && . "$HERE/seed.sh" || { echo "FIXTURE BROKEN: cannot source seed.sh" >&2; exit 2; }

# THE ROOT IS THE WORKING DIRECTORY (fixture-contract C1); both layouts resolve from it.
ROOT="$(pwd -P)"
if [ -f "$ROOT/core/skills/ai-dlc-update/reconcile/apply.sh" ]; then
  REC_SRC="$ROOT/core/skills/ai-dlc-update/reconcile"; HOOK_SRC="$ROOT/core/hooks/ai-dlc-answer-capture.sh"
  ESC_SRC="$ROOT/core/skills/ai-dlc/escalations.md"; REC_REL=core/skills/ai-dlc-update/reconcile; HOOK_REL=core/hooks
elif [ -f "$ROOT/.claude/skills/ai-dlc-update/reconcile/apply.sh" ]; then
  REC_SRC="$ROOT/.claude/skills/ai-dlc-update/reconcile"; HOOK_SRC="$ROOT/.claude/hooks/ai-dlc-answer-capture.sh"
  ESC_SRC="$ROOT/.claude/skills/ai-dlc/escalations.md"; REC_REL=.claude/skills/ai-dlc-update/reconcile; HOOK_REL=.claude/hooks
else
  echo "FIXTURE BROKEN: reconcile/apply.sh not found under $ROOT in either layout (run from the repository root)" >&2
  exit 2
fi
echo "resolved: $REC_SRC"
# THE SUBJECT, AND ITS OLD-TEXT SIGNATURE (a consumer whose engine predates this driver): SKIP, never ok.
if [ ! -f "$REC_SRC/pull.sh" ] || [ ! -f "$REC_SRC/pull-key.sh" ] || [ ! -f "$REC_SRC/ask-families.tsv" ] \
   || ! grep -q '^pk_conflict_ledger() {' "$REC_SRC/pull-key.sh" || ! grep -q 'pk_conflict_ledger' "$REC_SRC/readopt-override.sh" \
   || ! grep -q '^pl_hook_pre_gate_repair() {' "$REC_SRC/pull.sh"; then
  echo "SKIP reconcile-pull-driver: reconcile/pull.sh (with its conflict ledger and pre-gate repair) is not installed beside apply.sh; it arrives with the pull that carries this fixture"
  fx_skip_exit "$HERE"
fi
[ -f "$HOOK_SRC" ] && [ -f "$ESC_SRC" ] && [ -f "$HERE/escalation-validator.seed" ] \
  || { echo "FIXTURE BROKEN: the answer-capture hook, escalations.md or escalation-validator.seed is missing" >&2; exit 2; }
for _t in jq git awk; do command -v "$_t" >/dev/null 2>&1 || { echo "FIXTURE BROKEN: $_t is not on PATH" >&2; exit 2; }; done

WORK="$(mktemp -d "${TMPDIR:-/tmp}/reconcile-pull-driver.XXXXXX")" || { echo "FIXTURE BROKEN: mktemp" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd -P)"
trap 'rm -rf "$WORK"' EXIT

# --- the world copy of reconcile/ and of the answer hook -------------------------------------------------
cp -R "$REC_SRC" "$WORK/rec" || { echo "FIXTURE BROKEN: cannot copy reconcile/" >&2; exit 2; }
REC="$WORK/rec"
for _s in pull.sh pull-key.sh apply.sh readopt-override.sh emit-report.sh; do echo "HERMETIC-CONSUMED $REC_REL/$_s"; done
prd_instrument "$REC" "$WORK/prd-on" || { echo "FIXTURE BROKEN: prd_instrument" >&2; exit 2; }
mkdir -p "$WORK/hooks" && cp "$HOOK_SRC" "$WORK/hooks/" || { echo "FIXTURE BROKEN: cannot copy the answer hook" >&2; exit 2; }
HOOK="$WORK/hooks/ai-dlc-answer-capture.sh"
echo "HERMETIC-CONSUMED $HOOK_REL/ai-dlc-answer-capture.sh"
VAL="$HERE/escalation-validator.seed"
grep -v 'STATUSLESS-ENTRY' "$VAL" > "$WORK/validator-old.sh" || true
[ "$(grep -c 'STATUSLESS-ENTRY' "$VAL")" -gt 0 ] && [ "$(grep -c 'STATUSLESS-ENTRY' "$WORK/validator-old.sh")" = 0 ] \
  || { echo "FIXTURE BROKEN: the validator seed carries no STATUSLESS-ENTRY signature to remove" >&2; exit 2; }
# The validator's newer offender form: `FAIL: STATUSLESS <path>:<line> <header>` on stderr.
awk '/^[[:space:]]*echo "STATUSLESS \$ESCALATIONS:\$a \$b"$/ { sub(/echo "STATUSLESS/, "echo \"FAIL: STATUSLESS"); $0 = $0 " >&2"; n++ } { print } END { exit n != 1 }' \
  "$VAL" > "$WORK/validator-new.sh" && grep -q 'FAIL: STATUSLESS .* >&2$' "$WORK/validator-new.sh" \
  || { echo "FIXTURE BROKEN: could not derive the FAIL: STATUSLESS validator form from the seed" >&2; exit 2; }

# --- worlds, each built once --------------------------------------------------------------------------
prd_seed_main "$WORK/seed-main" "$ESC_SRC" "$VAL" || { echo "FIXTURE BROKEN: prd_seed_main" >&2; exit 2; }
prd_seed_stray "$WORK/seed-stray" "$ESC_SRC" "$WORK/validator-old.sh" || { echo "FIXTURE BROKEN: prd_seed_stray" >&2; exit 2; }
prd_seed_ovr "$WORK/seed-ovr" || { echo "FIXTURE BROKEN: prd_seed_ovr" >&2; exit 2; }
copy_world() { [ ! -e "$WORK/$2" ] && cp -R "$WORK/$1" "$WORK/$2" || { echo "FIXTURE BROKEN: cannot copy world $1" >&2; exit 2; }; }
SENT_REL=.claude/session-driver/ai-dlc-session-driver.sh
# count_on <world> <log> [<detector to refuse>] / count_off
count_on() { printf '%s\n%s\n%s\n%s\n' "$2" "$WORK/$1/c/$SENT_REL" "# driver v1" "${3:-}" > "$WORK/prd-on"; : > "$2"; }
count_off() { rm -f "$WORK/prd-on"; }
pre_rows() { awk -F'\t' -v d="$2" '$2 == "pre" && $1 != "emit-report.sh" && (d == "" || $1 == d)' "$1" | wc -l | tr -d ' '; }
# renders <log>: emit-report.sh starts without --verify (print mode, the render).
renders() { awk -F'\t' '$1 == "emit-report.sh" && $3 !~ /--verify/' "$1" | wc -l | tr -d ' '; }
# answer <consumer> <question> <answer>: one AskUserQuestion record through the real hook (a world copy).
answer() {
  jq -n --arg q "$2" --arg a "$3" \
    '{tool_name:"AskUserQuestion",session_id:"fx-prd",tool_use_id:"fx-prd-tu",tool_response:{answers:{($q):$a}}}' > "$1.payload.json" || return 1
  CLAUDE_PROJECT_DIR="$1" bash "$HOOK" < "$1.payload.json" >/dev/null 2>&1
  grep -q -- "$2" "$1/_bmad-output/operator-answers-history.md" 2>/dev/null
}
run_dir() { sed -n 's/^PULL run=\([^ ]*\) .*/\1/p' "$1" | tail -1; }

# ================================ a, h, p: pull.sh apply on the pull world ================================
copy_world seed-main a
A="$WORK/a"; AB="$(cat "$A/.B")"; AT="$(cat "$A/.T")"
# The deliver arms' operator state, in place before the pull's first apply (arm dl reads it after finish):
# a modified tracked file, an untracked file, a staged edit, a staged rename, and a dirty file a hook appends
# to later; an earlier pull's report and gate record (untracked); and this pull's gate record (pull.sh gate).
mkdir -p "$A/c/notes" "$A/c/_bmad-output/ai-dlc-update"
for _f in op-mod op-staged op-ren-old op-append; do printf 'line of %s\n' "$_f" > "$A/c/notes/$_f.txt"; done
world_commit "$A/c" "operator notes" >/dev/null || { echo "FIXTURE BROKEN: cannot commit the operator notes" >&2; exit 2; }
printf 'operator edit\n' >> "$A/c/notes/op-mod.txt"
printf 'operator untracked\n' > "$A/c/notes/op-untracked.txt"
printf 'operator staged\n' >> "$A/c/notes/op-staged.txt"
world_git -C "$A/c" add notes/op-staged.txt && world_git -C "$A/c" mv notes/op-ren-old.txt notes/op-ren-new.txt \
  || { echo "FIXTURE BROKEN: cannot stage the operator entries" >&2; exit 2; }
printf 'operator before the pull\n' >> "$A/c/notes/op-append.txt"
printf '# reconcile report\n\nan earlier pull left this\n' > "$A/c/_bmad-output/ai-dlc-update/reconcile-report.md"
GATE_OLD=_bmad-output/ai-dlc-update/self-update-gate-20200101T000000Z.md
printf '# an earlier pull'"'"'s gate record\n' > "$A/c/$GATE_OLD"
bash "$REC/pull.sh" gate "$A/dist" "$AB" "$A/c" "$AT" > "$WORK/gate.out" 2> "$WORK/gate.err" < /dev/null; gate_rc=$?
count_on a "$WORK/log-a"
bash "$REC/pull.sh" apply "$A/dist" "$AB" "$A/c" "$AT" > "$WORK/a.out" 2> "$WORK/a.err" < /dev/null; a_rc=$?
count_off
A_RUN="$(run_dir "$WORK/a.out")"
if [ "$a_rc" = 0 ] && [ "$(renders "$WORK/log-a")" = 1 ] && grep -q '^PULL run=.* renders=1$' "$WORK/a.out" \
   && grep -q '^WORK classify session-driver/ai-dlc-both-changed.sh$' "$WORK/a.out" && grep -qF '# driver v2 UPSTREAM' "$A/c/$SENT_REL"; then
  ok "a: pull.sh apply exits 0 after one in-world render, hands the classify row back, and wrote theirs"
else
  bad "a: pull.sh apply rc=$a_rc in-world renders=$(renders "$WORK/log-a"); out: $(tr '\n' '|' < "$WORK/a.out" | cut -c1-400) err: $(head -c 300 "$WORK/a.err")"
fi
a_miss=""
for _d in $PRD_DETECTORS; do [ "$(pre_rows "$WORK/log-a" "$_d")" -ge 1 ] || a_miss="$a_miss $_d"; done
a_dup="$(awk -F'\t' '$2 == "pre" {print $1 "\t" $3}' "$WORK/log-a" | sort | uniq -d | cut -f1 | tr '\n' ' ')"
a_post="$(awk -F'\t' '$2 == "post"' "$WORK/log-a" | wc -l | tr -d ' ')"
if [ -z "$a_miss" ] && [ -z "$a_dup" ] && [ "$a_post" -ge 1 ]; then
  ok "a: each of the 7 detectors started pre-write, no (detector, argv) started twice pre-write ($(pre_rows "$WORK/log-a" "") pre rows, $a_post post-write rows)"
else
  bad "a: detectors never started pre-write:[$a_miss] started twice pre-write:[$a_dup] post-write rows:$a_post"
fi
if grep -q '^DECIDE extension-reread .claude/skills/ai-dlc/extensions/steps-domain/alpha-domain.md ' "$WORK/a.out" \
   && grep -q '^DECIDE pristine-delete scripts/ai-dlc/validate-gone.sh deleted$' "$WORK/a.out" \
   && [ ! -e "$A/c/scripts/ai-dlc/validate-gone.sh" ] && ! grep -q '^ASK ' "$WORK/a.out"; then
  ok "h: an extension re-read and a pristine delete each take a DECIDE row, the delete is done, and nothing asks"
else
  bad "h: extension/pristine-delete rows wrong: $(grep '^DECIDE\|^ASK' "$WORK/a.out" | tr '\n' '|')"
fi
p_n="$(grep -c '^WORKLIST pre-gate-repair docs/escalations/pending.md:[0-9]* ## 2026-11-02 statusless entry$' "$WORK/a.out")" || p_n=0
p_all="$(grep -c '^WORKLIST pre-gate-repair ' "$WORK/a.out")" || p_all=0
if [ "$p_n" = 1 ] && [ "$p_all" = 1 ] && grep -q '^pre-gate-repair	docs/escalations/pending.md:' "$A/c/_bmad-output/ai-dlc-update/pull-decisions.tsv" 2>/dev/null; then
  ok "p: one statusless entry gives exactly one WORKLIST pre-gate-repair row and its decisions row"
else
  bad "p: pre-gate-repair rows $p_n/$p_all, decisions: $(grep -c '^pre-gate-repair' "$A/c/_bmad-output/ai-dlc-update/pull-decisions.tsv" 2>/dev/null)"
fi

# ================================ d: one model resolution round renders exactly once more ==================
# The model resolves arm a's WORK classify row (the file takes theirs) and re-runs the same apply.
world_git -C "$A/dist" show "${AT}:core/session-driver/ai-dlc-both-changed.sh" > "$A/c/.claude/session-driver/ai-dlc-both-changed.sh"
# The resolution round also meets the validator's newer `FAIL: STATUSLESS` form (arm p2 below).
cp "$WORK/validator-new.sh" "$A/c/scripts/ai-dlc/validate-escalation-status-vocabulary.sh" || { echo "FIXTURE BROKEN: cannot install the new-form validator" >&2; exit 2; }
count_on a "$WORK/log-d"
bash "$REC/pull.sh" apply "$A/dist" "$AB" "$A/c" "$AT" > "$WORK/d.out" 2> "$WORK/d.err" < /dev/null; d_rc=$?
count_off
if [ "$d_rc" = 0 ] && [ "$(renders "$WORK/log-d")" = 1 ] && grep -q '^PULL run=.* renders=1$' "$WORK/d.out" \
   && ! grep -q '^WORK classify' "$WORK/d.out" && ! grep -q '^ASK ' "$WORK/d.out"; then
  ok "d: one resolution round (the classify row resolved, apply re-run) renders exactly once more and exits 0"
else
  bad "d: resolution round rc=$d_rc in-world renders=$(renders "$WORK/log-d") out: $(tr '\n' '|' < "$WORK/d.out" | cut -c1-400)"
fi
p2_n="$(grep -c '^WORKLIST pre-gate-repair docs/escalations/pending.md:[0-9]* ## 2026-11-02 statusless entry$' "$WORK/d.out")" || p2_n=0
if [ "$p2_n" = 1 ]; then
  ok "p2: the validator's FAIL: STATUSLESS form gives exactly one WORKLIST pre-gate-repair row"
else
  bad "p2: FAIL: STATUSLESS form gave $p2_n rows: $(grep 'pre-gate-repair' "$WORK/d.out" | tr '\n' '|')"
fi

# ================================ q: the PR body renders the pull's rows, the model's included, each once ===
# The model appends a row exactly as SKILL.md prescribes (six tab-separated columns, decider model).
ADEC="$A/c/_bmad-output/ai-dlc-update/pull-decisions.tsv"
printf 'refile\tdocs/model-decided.md\t-\tmodel\tkept\tthe consumer extension stays in place\n' >> "$ADEC"
bash "$REC/pull.sh" pr-body "$A/c" > "$WORK/q.out" 2> "$WORK/q.err" < /dev/null; q_rc=$?
q_dup="$(grep '^| ' "$WORK/q.out" | sort | uniq -d | wc -l | tr -d ' ')"
q_fdup="$(sed 1d "$ADEC" | sort | uniq -d | wc -l | tr -d ' ')"
if [ "$q_rc" = 0 ] && grep -q '^| refile | `docs/model-decided.md` | model | kept | ' "$WORK/q.out" \
   && grep -q '^| pristine-delete | `scripts/ai-dlc/validate-gone.sh` ' "$WORK/q.out" && [ "$q_dup" = 0 ] && [ "$q_fdup" = 0 ] \
   && [ "$(awk -F'\t' 'NF != 6' "$ADEC" | wc -l | tr -d ' ')" = 0 ]; then
  ok "q: the PR body renders the driver's rows and a model row in SKILL.md's six-column form, no row twice"
else
  bad "q: pr-body rc=$q_rc dup-rendered=$q_dup dup-in-file=$q_fdup out: $(grep '^| ' "$WORK/q.out" | tr '\n' '~' | cut -c1-400)"
fi

# ================================ j: a blend block merged with no answer never reaches the stamp ============
# The classify agent tags the handed-back file `confirmation_kind: blend`; the model merges it (arm d) and runs
# finish without asking. The ledger row is open whatever the file now holds.
JREP="$A/c/_bmad-output/ai-dlc-update/reconcile-report.md"
printf '\nFILE: core/session-driver/ai-dlc-both-changed.sh\n  - id: 1\n    confirmation_kind: blend\n' >> "$JREP"
j_stamp0="$(git hash-object "$A/c/.claude/.ai-dlc-version")"
bash "$REC/pull.sh" finish "$A/dist" "$AB" "$A/c" "$AT" > "$WORK/j.out" 2> "$WORK/j.err" < /dev/null; j_rc=$?
j_dg="$(awk '$1 == "ASK" && $2 == "blend" {print $4; exit}' "$WORK/j.out")"
if [ "$j_rc" = 3 ] && [ "${#j_dg}" = 64 ] && grep -q "^ASK-UNANSWERED	blend	.claude/session-driver/ai-dlc-both-changed.sh	${j_dg}\$" "$WORK/j.err" \
   && grep -q "^blend	.claude/session-driver/ai-dlc-both-changed.sh	${j_dg}	" "$A/c/.git/ai-dlc-pull/asks.tsv" \
   && [ "$(git hash-object "$A/c/.claude/.ai-dlc-version")" = "$j_stamp0" ]; then
  ok "j: a blend block merged without an answer: pull.sh finish ASK-UNANSWERED (the ASK digest is the ledger's), exit 3, stamp not advanced"
else
  bad "j: finish rc=$j_rc digest '$j_dg' out: $(tr '\n' '|' < "$WORK/j.out" | cut -c1-300) err: $(grep -m2 'ASK-UNANSWERED\|REFUSED' "$WORK/j.err" | tr '\n' '|')"
fi
# Answered through the hook, and a judgment-only block beside it (a model decision, never a ledger row): finish proceeds.
answer "$A/c" "Blend the session driver? digest $j_dg" "blend it" || bad "j: the answer hook wrote no record"
printf '\nFILE: core/session-driver/ai-dlc-both-changed.sh\n  - id: 2\n    confirmation_kind: judgment\n' >> "$JREP"
bash "$REC/pull.sh" finish "$A/dist" "$AB" "$A/c" "$AT" > "$WORK/j2.out" 2> "$WORK/j2.err" < /dev/null; j2_rc=$?
if [ "$j2_rc" = 0 ] && ! grep -q '^ASK' "$WORK/j2.out" && ! grep -q '^ASK-UNANSWERED' "$WORK/j2.err" \
   && grep -q '^DECIDE judgment .claude/session-driver/ai-dlc-both-changed.sh model$' "$WORK/j2.out" \
   && [ "$(grep -c '^judgment	' "$A/c/.git/ai-dlc-pull/asks.tsv")" = 0 ]; then
  ok "j: the answered blend and a judgment-only block: finish exits 0, asks nothing, and the judgment row never enters the ledger"
else
  bad "j: answered finish rc=$j2_rc out: $(tr '\n' '|' < "$WORK/j2.out" | cut -c1-300) err: $(grep -m2 'ASK-UNANSWERED\|REFUSED\|apply:' "$WORK/j2.err" | tr '\n' '|')"
fi

# ================================ dl: pull.sh deliver against a bare file:// remote ==========================
# deliver_env <world>: a bare origin, a consumer pre-commit hook recording the index it is shown, a pre-push
# hook recording which run directories hold a pr-body.md at push time, and a stub gh recording --body-file's size.
mkdir -p "$WORK/bin" || { echo "FIXTURE BROKEN: mkdir bin" >&2; exit 2; }
printf '%s\n' '#!/usr/bin/env bash' \
  'while [ $# -gt 0 ]; do case "$1" in --body-file) wc -c < "$2" | tr -d " " > "$GH_LOG"; shift ;; esac; shift; done' \
  'echo https://example.invalid/pr/1' > "$WORK/bin/gh" && chmod +x "$WORK/bin/gh" || { echo "FIXTURE BROKEN: cannot write the gh stub" >&2; exit 2; }
deliver_env() {
  world_git init -q --bare "$WORK/$1-origin.git" && world_git -C "$WORK/$1/c" remote add origin "file://$WORK/$1-origin.git" || return 1
  printf '%s\n' '#!/usr/bin/env bash' 'git diff --cached --name-only > "$PRECOMMIT_LOG"' > "$WORK/$1/c/.git/hooks/pre-commit" || return 1
  printf '%s\n' '#!/usr/bin/env bash' 'ls "$(git rev-parse --absolute-git-dir)"/ai-dlc-pull/run-*/pr-body.md > "$PREPUSH_LOG" 2>/dev/null; exit 0' > "$WORK/$1/c/.git/hooks/pre-push" || return 1
  chmod +x "$WORK/$1/c/.git/hooks/pre-commit" "$WORK/$1/c/.git/hooks/pre-push"
}
# deliver_run <world> <dist> <base> <consumer> <theirs>
deliver_run() {
  PATH="$WORK/bin:$PATH" GH_LOG="$WORK/$1-gh" PRECOMMIT_LOG="$WORK/$1-precommit" PREPUSH_LOG="$WORK/$1-prepush" \
  GIT_AUTHOR_NAME=fixture GIT_AUTHOR_EMAIL=fixture@invalid GIT_COMMITTER_NAME=fixture GIT_COMMITTER_EMAIL=fixture@invalid \
    bash "$REC/pull.sh" deliver "$2" "$3" "$4" "$5" > "$WORK/$1-deliver.out" 2> "$WORK/$1-deliver.err" < /dev/null
}
GATE_NEW="$(sed -n '2p' "$A/c/.git/ai-dlc-pull/pull-artifacts" 2>/dev/null)"
if [ "$gate_rc" = 0 ] && [ "$(sed -n 1p "$A/c/.git/ai-dlc-pull/pull-artifacts" 2>/dev/null)" = "ai-dlc-pull-artifacts 1 $AT" ] \
   && [ -n "$GATE_NEW" ] && [ "$GATE_NEW" != "$GATE_OLD" ] && [ -f "$A/c/$GATE_NEW" ] && [ "${GATE_NEW#_bmad-output/ai-dlc-update/self-update-gate-}" != "$GATE_NEW" ] \
   && grep -q "	.*	.*	$GATE_NEW	" "$A/c/.git/ai-dlc-pull/dirty-snapshot" && grep -q "	.*	.*	$GATE_OLD	" "$A/c/.git/ai-dlc-pull/dirty-snapshot" \
   && grep -q "	.*	.*	_bmad-output/ai-dlc-update/reconcile-report.md	" "$A/c/.git/ai-dlc-pull/dirty-snapshot"; then
  ok "ii-b: pull.sh gate records only the gate record it wrote in pull-artifacts, and the snapshot holds it, the older record and the earlier report"
else
  bad "ii-b: gate rc=$gate_rc artifacts: $(tr '\n' '|' < "$A/c/.git/ai-dlc-pull/pull-artifacts" 2>/dev/null) snapshot: $(cut -f1,4 "$A/c/.git/ai-dlc-pull/dirty-snapshot" 2>/dev/null | tr '\n\t' '| ' | cut -c1-400)"
fi
deliver_env a || { echo "FIXTURE BROKEN: deliver_env a" >&2; exit 2; }
# Between finish and deliver: a hook appends to the already-dirty file (i-b), and the resolution stages a rename (iii).
printf 'appended after apply\n' >> "$A/c/notes/op-append.txt"
world_git -C "$A/c" mv tests/fixtures/synthetic-fx/run.sh tests/fixtures/synthetic-fx/run-renamed.sh || { echo "FIXTURE BROKEN: cannot stage the rename" >&2; exit 2; }
dl_br="$(world_git -C "$A/c" symbolic-ref -q --short HEAD)"
deliver_run a "$A/dist" "$AB" "$A/c" "$AT"; dl_rc=$?
dl_ns="$(world_git -C "$A/c" show --name-status -M --format= HEAD)"
dl_cached="$(world_git -C "$A/c" diff --cached --name-only)"
dl_st() { world_git -C "$A/c" status --porcelain=v1 -- "$1"; }
if [ "$dl_rc" = 0 ] && grep -qx 'DECIDE pr https://example.invalid/pr/1 opened' "$WORK/a-deliver.out" \
   && [ "$(world_git --git-dir="$WORK/a-origin.git" rev-parse -q --verify "refs/heads/$dl_br")" = "$(world_git -C "$A/c" rev-parse HEAD)" ] \
   && grep -q "	$SENT_REL\$" <<<"$dl_ns" && ! grep -q 'notes/' <<<"$dl_ns"; then
  ok "i: deliver pushes a commit carrying the pull's writes and none of the operator's modified, untracked, staged or renamed paths"
else
  bad "i: deliver rc=$dl_rc out: $(tr '\n' '|' < "$WORK/a-deliver.out" | cut -c1-300) err: $(head -c 300 "$WORK/a-deliver.err") commit: $(tr '\n\t' '| ' <<<"$dl_ns" | cut -c1-400)"
fi
if [ "$(dl_st notes/op-mod.txt)" = " M notes/op-mod.txt" ] && [ "$(dl_st notes/op-untracked.txt)" = "?? notes/op-untracked.txt" ] \
   && [ "$(dl_st notes/op-staged.txt)" = "M  notes/op-staged.txt" ] && [ "$(dl_st notes/op-ren-new.txt)" = "A  notes/op-ren-new.txt" ] \
   && [ "$(world_git -C "$A/c" status --porcelain=v1 | grep -c '^R  notes/op-ren-old.txt -> notes/op-ren-new.txt$')" = 1 ]; then
  ok "i: after deliver the operator's edit stays unstaged, the untracked file untracked, the staged edit and staged rename staged"
else
  bad "i: operator state after deliver: $(world_git -C "$A/c" status --porcelain=v1 -- notes | tr '\n' '|')"
fi
if [ "$(dl_st notes/op-append.txt)" = " M notes/op-append.txt" ] && ! grep -q 'op-append' <<<"$dl_ns" \
   && grep -q 'appended after apply' "$A/c/notes/op-append.txt"; then
  ok "i-b: a file dirty before apply and appended to before deliver stays out of the commit and stays dirty"
else
  bad "i-b: op-append status '$(dl_st notes/op-append.txt)' commit: $(tr '\n\t' '| ' <<<"$dl_ns" | cut -c1-300)"
fi
if grep -qx "$SENT_REL" "$WORK/a-precommit" 2>/dev/null && ! grep -q 'notes/' "$WORK/a-precommit" \
   && [ -n "$dl_cached" ] && [ -z "$(grep -v '^notes/' <<<"$dl_cached")" ]; then
  ok "i-c: the consumer's pre-commit hook was shown only the selected paths, and after deliver only the operator's entries are staged ($(wc -l < "$WORK/a-precommit" | tr -d ' ') paths at the hook)"
else
  bad "i-c: pre-commit saw: $(tr '\n' '|' < "$WORK/a-precommit" 2>/dev/null | cut -c1-300) staged after: $(tr '\n' '|' <<<"$dl_cached")"
fi
if grep -q "	_bmad-output/ai-dlc-update/reconcile-report.md\$" <<<"$dl_ns" && [ "$(dl_st _bmad-output/ai-dlc-update/reconcile-report.md)" = "" ]; then
  ok "ii: the report, dirty at the snapshot and in the always-stage set, is in the commit"
else
  bad "ii: report not committed: $(tr '\n\t' '| ' <<<"$dl_ns" | cut -c1-300)"
fi
if [ -n "$GATE_NEW" ] && grep -q "	$GATE_NEW\$" <<<"$dl_ns" && ! grep -q 'self-update-gate-20200101T000000Z' <<<"$dl_ns" \
   && [ "$(dl_st "$GATE_OLD")" = "?? $GATE_OLD" ]; then
  ok "ii-b: the gate record pull-artifacts names is in the commit; the older gate record is not, and stays untracked"
else
  bad "ii-b: gate records in the commit: $(grep 'self-update-gate' <<<"$dl_ns" | tr '\n\t' '| ') old: '$(dl_st "$GATE_OLD")'"
fi
if grep -qx 'D	scripts/ai-dlc/validate-gone.sh' <<<"$dl_ns" \
   && grep -qx 'R100	tests/fixtures/synthetic-fx/run.sh	tests/fixtures/synthetic-fx/run-renamed.sh' <<<"$dl_ns"; then
  ok "iii: a staged deletion and a staged rename are committed whole"
else
  bad "iii: deletion/rename not in the commit: $(tr '\n\t' '| ' <<<"$dl_ns" | cut -c1-400) err: $(head -c 300 "$WORK/a-deliver.err")"
fi

# ================================ iv, v: no snapshot, an oversized region ===================================
copy_world seed-main v
V="$WORK/v"; VB="$(cat "$V/.B")"; VT="$(cat "$V/.T")"
world_git -C "$V/c" checkout -q -b ai-dlc-update/2.0.0-reconcile-20260101T000000Z || { echo "FIXTURE BROKEN: cannot cut the v branch" >&2; exit 2; }
mkdir -p "$V/c/_bmad-output/ai-dlc-update" "$V/c/notes" || { echo "FIXTURE BROKEN: mkdir v" >&2; exit 2; }
{ printf '# reconcile report\n\n<!-- BEGIN GENERATED: reconcile-mechanical -->\n'
  awk 'BEGIN { for (i = 0; i < 1500; i++) printf "UPSTREAM-ADD  core/some/long/path/number-%05d.md  a row of the region long enough to count\n", i }'
  printf '<!-- END GENERATED: reconcile-mechanical -->\n'; } > "$V/c/_bmad-output/ai-dlc-update/reconcile-report.md"
v_reg="$(wc -c < "$V/c/_bmad-output/ai-dlc-update/reconcile-report.md" | tr -d ' ')"
printf 'operator untracked, no snapshot\n' > "$V/c/notes/v-untracked.txt"
printf '# edited, no snapshot\n' >> "$V/c/scripts/ai-dlc/validate-synthetic.sh"
deliver_env v || { echo "FIXTURE BROKEN: deliver_env v" >&2; exit 2; }
deliver_run v "$V/dist" "$VB" "$V/c" "$VT"; v_rc=$?
v_ns="$(world_git -C "$V/c" show --name-status -M --format= HEAD)"
if [ "$v_rc" = 0 ] && grep -q '^NOTE deliver-no-snapshot ' "$WORK/v-deliver.out" \
   && grep -qx 'A	notes/v-untracked.txt' <<<"$v_ns" && grep -qx 'M	scripts/ai-dlc/validate-synthetic.sh' <<<"$v_ns" \
   && grep -qx 'A	_bmad-output/ai-dlc-update/reconcile-report.md' <<<"$v_ns" && [ -z "$(world_git -C "$V/c" status --porcelain=v1)" ]; then
  ok "v: no dirty snapshot for this theirs: one NOTE deliver-no-snapshot line, and every changed path is committed"
else
  bad "v: deliver rc=$v_rc out: $(tr '\n' '|' < "$WORK/v-deliver.out" | cut -c1-300) err: $(head -c 300 "$WORK/v-deliver.err") commit: $(tr '\n\t' '| ' <<<"$v_ns")"
fi
v_body="$(cat "$WORK/v-prepush" 2>/dev/null)"
v_gh="$(cat "$WORK/v-gh" 2>/dev/null)"
if [ "$v_reg" -gt 60000 ] && [ -n "$v_gh" ] && [ "$v_gh" -gt 0 ] && [ "$v_gh" -lt 60000 ] && [ -n "$v_body" ] && [ -f "$v_body" ] \
   && grep -q '^omitted ([0-9]* bytes): see `_bmad-output/ai-dlc-update/reconcile-report.md` in this PR' "$v_body" \
   && [ "$(wc -c < "$v_body" | tr -d ' ')" = "$v_gh" ]; then
  ok "iv: a $v_reg-byte region: the PR body gh receives is $v_gh bytes with the pointer line, and it was on disk when the pre-push hook ran"
else
  bad "iv: region=$v_reg gh body=${v_gh:-none} pre-push saw: '${v_body:-nothing}'"
fi

# ================================ h twin: a consumer-MODIFIED delete asks =================================
copy_world seed-main t
Tw="$WORK/t"; TB="$(cat "$Tw/.B")"; TT="$(cat "$Tw/.T")"
printf '#!/usr/bin/env bash\necho gone, CONSUMER EDIT\n' > "$Tw/c/scripts/ai-dlc/validate-gone.sh"
world_commit "$Tw/c" "consumer edit" || { echo "FIXTURE BROKEN: cannot commit the twin's edit" >&2; exit 2; }
bash "$REC/pull.sh" apply "$Tw/dist" "$TB" "$Tw/c" "$TT" > "$WORK/t.out" 2> "$WORK/t.err" < /dev/null; t_rc=$?
t_ask="$(grep -c '^ASK ' "$WORK/t.out")" || t_ask=0
if [ "$t_rc" = 3 ] && [ "$t_ask" = 1 ] && grep -q '^ASK delete-consumer-modified core/scripts/validate-gone.sh [0-9a-f]\{64\} ' "$WORK/t.out" \
   && ! grep -q '^DECIDE .*validate-gone' "$WORK/t.out" && grep -q 'CONSUMER EDIT' "$Tw/c/scripts/ai-dlc/validate-gone.sh"; then
  ok "h twin: a consumer-modified file theirs deletes asks exactly once (delete-consumer-modified), takes no DECIDE row, and stays"
else
  bad "h twin: rc=$t_rc asks=$t_ask out: $(tr '\n' '|' < "$WORK/t.out" | cut -c1-400)"
fi
# ================================ k: a delete apply.sh cannot prove pristine asks ==========================
# Content at base, mode changed and uncommitted: the region reads it pristine, the pre-rm re-read does not, and
# apply.sh hands the delete back gated. It asks in the delete-consumer-modified family, ledger row and all.
copy_world seed-main k
Kw="$WORK/k"; KB="$(cat "$Kw/.B")"; KT="$(cat "$Kw/.T")"
chmod +x "$Kw/c/scripts/ai-dlc/validate-gone.sh"
bash "$REC/pull.sh" apply "$Kw/dist" "$KB" "$Kw/c" "$KT" > "$WORK/k.out" 2> "$WORK/k.err" < /dev/null; k_rc=$?
k_dg="$(awk '$1 == "ASK" && $2 == "delete-consumer-modified" && $3 == "scripts/validate-gone.sh" {print $4; exit}' "$WORK/k.out")"
k_l="$(grep -c "^delete-consumer-modified	scripts/validate-gone.sh	${k_dg:-none}	" "$Kw/c/.git/ai-dlc-pull/asks.tsv" 2>/dev/null)" || k_l=0
if [ "$k_rc" = 3 ] && [ "${#k_dg}" = 64 ] && [ "$k_l" = 1 ] && [ "$(grep -c '^ASK ' "$WORK/k.out")" = 1 ] && [ -e "$Kw/c/scripts/ai-dlc/validate-gone.sh" ]; then
  ok "k: a gated deletion asks once (delete-consumer-modified, the ASK digest is the ledger's), and the apply exits 3"
else
  bad "k: rc=$k_rc digest='$k_dg' ledger=$k_l out: $(tr '\n' '|' < "$WORK/k.out" | cut -c1-400)"
fi
answer "$Kw/c" "Delete validate-gone.sh? digest $k_dg" "keep it" || bad "k: the answer hook wrote no record"
bash "$REC/pull.sh" apply "$Kw/dist" "$KB" "$Kw/c" "$KT" > "$WORK/k2.out" 2> "$WORK/k2.err" < /dev/null; k2_rc=$?
if [ "$k2_rc" = 0 ] && ! grep -q '^ASK' "$WORK/k2.out"; then
  ok "k: answered through the hook, the same apply proceeds and asks nothing"
else
  bad "k: answered apply rc=$k2_rc out: $(tr '\n' '|' < "$WORK/k2.out" | cut -c1-300)"
fi

# ================================ e, f: F moves on the index and on the stamp ==============================
copy_world seed-main e
E="$WORK/e"; EB="$(cat "$E/.B")"; ET="$(cat "$E/.T")"
fk() { bash "$REC/pull-key.sh" "$E/dist" "$EB" "$E/c" "$ET" 2>/dev/null; }
f0="$(fk)"; f0b="$(fk)"
printf 'staged only\n' > "$E/c/scripts/ai-dlc/validate-synthetic.sh"
world_git -C "$E/c" add scripts/ai-dlc/validate-synthetic.sh
world_git -C "$E/c" show HEAD:scripts/ai-dlc/validate-synthetic.sh > "$E/c/scripts/ai-dlc/validate-synthetic.sh"
f1="$(fk)"
world_git -C "$E/c" reset -q
f0c="$(fk)"
printf '# edited\n' >> "$E/c/.claude/.ai-dlc-version"
f2="$(fk)"
case "$f0" in "pull-key 1 "*) f_ok=1 ;; *) f_ok=0 ;; esac
if [ "$f_ok" = 1 ] && [ "$f0" = "$f0b" ] && [ "$f0" = "$f0c" ]; then
  ok "e/f control: F is computed and stable over one state, and returns when the staged change is unstaged"
else
  bad "e/f control: F0=$f0 F0'=$f0b F0''=$f0c"
fi
if [ "$f_ok" = 1 ] && [ "$f1" != "$f0" ] && [ "${f1#pull-key 1 }" != "$f1" ]; then
  ok "e: a staged-only change (working tree unchanged) moves F"
else
  bad "e: a staged-only change left F at $f1 (before: $f0)"
fi
if [ "$f_ok" = 1 ] && [ "$f2" != "$f0" ] && [ "${f2#pull-key 1 }" != "$f2" ]; then
  ok "f: a stamp edit moves F"
else
  bad "f: a stamp edit left F at $f2 (before: $f0)"
fi

# ================================ b: theirs advanced after the dry run =====================================
copy_world seed-main b
Bw="$WORK/b"; BB="$(cat "$Bw/.B")"; BT="$(cat "$Bw/.T")"
bash "$REC/pull.sh" dry-run "$Bw/dist" "$BB" "$Bw/c" "$BT" > "$WORK/b-dry.out" 2> "$WORK/b-dry.err" < /dev/null; b_drc=$?
B_RUN="$(run_dir "$WORK/b-dry.out")"
# c4, on this dry run's store, before theirs moves. F does not name the consumer's PATH, so a byte-identical copy
# of the consumer at another path has the same F and different detector argv: the same --verify --reuse answers
# from the store at the store's own path and runs the detectors at the copy's.
REP_REL=_bmad-output/ai-dlc-update/reconcile-report.md
cp -R "$Bw/c" "$WORK/b-twin" || { echo "FIXTURE BROKEN: cannot copy the b consumer" >&2; exit 2; }
c4_f="$(bash "$REC/pull-key.sh" "$Bw/dist" "$BB" "$WORK/b-twin" "$BT" 2>/dev/null)"
count_on b "$WORK/log-c4-same"
bash "$REC/emit-report.sh" --verify --reuse "$B_RUN/raw" "$Bw/c/$REP_REL" "$Bw/dist" "$BB" "$Bw/c" "$BT" > /dev/null 2> "$WORK/c4-same.err" < /dev/null
count_on b "$WORK/log-c4-twin"
bash "$REC/emit-report.sh" --verify --reuse "$B_RUN/raw" "$WORK/b-twin/$REP_REL" "$Bw/dist" "$BB" "$WORK/b-twin" "$BT" > /dev/null 2> "$WORK/c4-twin.err" < /dev/null
count_off
c4_same="$(awk -F"\t" '$1 != "emit-report.sh"' "$WORK/log-c4-same" | wc -l | tr -d " ")"
if [ -n "$B_RUN" ] && [ "${c4_f#pull-key 1 }" != "$c4_f" ] && [ "$c4_f" = "$(cat "$B_RUN/raw/F" 2>/dev/null)" ] \
   && [ "$c4_same" = 0 ] && [ "$(pre_rows "$WORK/log-c4-twin" preclassify.sh)" -ge 1 ]; then
  ok "c4: under one F, --verify --reuse answers the exact argv from the store (0 detector starts) and runs the detectors for a different argv ($(pre_rows "$WORK/log-c4-twin" "") starts)"
else
  bad "c4: F twin=$c4_f stored=$(cat "$B_RUN/raw/F" 2>/dev/null); starts at the store's argv: $c4_same; at the twin's: $(cut -f1 "$WORK/log-c4-twin" | tr '\n' ' ')"
fi
printf '#!/usr/bin/env bash\n# driver v3 MOVED\n' > "$Bw/dist/core/session-driver/ai-dlc-session-driver.sh"
BT2="$(prd_dist_commit "$Bw/dist" moved)"
b_f="$(bash "$REC/pull-key.sh" "$Bw/dist" "$BB" "$Bw/c" "$BT2" 2>/dev/null)"
b_st0="$(world_git -C "$Bw/c" status --porcelain=v1 --untracked-files=all | git hash-object --stdin)"
count_on b "$WORK/log-b"
AI_DLC_PULL_RUN="$B_RUN" bash "$REC/apply.sh" "$Bw/dist" "$BB" "$Bw/c" "$BT2" > "$WORK/b.out" 2> "$WORK/b.err" < /dev/null; b_rc=$?
count_off
b_st1="$(world_git -C "$Bw/c" status --porcelain=v1 --untracked-files=all | git hash-object --stdin)"
if [ "$b_drc" = 0 ] && [ -n "$B_RUN" ] && [ -f "$B_RUN/raw/F" ] && [ "${b_f#pull-key 1 }" != "$b_f" ] && [ "$b_f" != "$(cat "$B_RUN/raw/F")" ]; then
  ok "b: the dry run kept a store, and theirs advancing moves F away from it"
else
  bad "b: dry run rc=$b_drc run=${B_RUN:-none} F now=$b_f stored=$(cat "$B_RUN/raw/F" 2>/dev/null)"
fi
if [ "$(pre_rows "$WORK/log-b" preclassify.sh)" -ge 1 ] && [ "$(pre_rows "$WORK/log-b" unregistered-drift.sh)" -ge 1 ]; then
  ok "b: on the F mismatch apply.sh ran the detectors fresh ($(pre_rows "$WORK/log-b" "") detector starts)"
else
  bad "b: on the F mismatch the detectors did not run: $(cut -f1,2 "$WORK/log-b" | tr '\n' ' ')"
fi
if [ "$b_rc" = 1 ] && grep -q 'cause: UPSTREAM-MOVED' "$WORK/b.err" && grep -q 'NOTHING HAS BEEN WRITTEN' "$WORK/b.err" \
   && [ "$b_st0" = "$b_st1" ] && grep -qF '# driver v1' "$Bw/c/$SENT_REL" && [ ! -e "$Bw/c/.claude/.ai-dlc-applying" ]; then
  ok "b: apply.sh ends UPSTREAM-MOVED, exit 1, and wrote nothing"
else
  bad "b: apply.sh rc=$b_rc status-unchanged=$([ "$b_st0" = "$b_st1" ] && echo yes || echo no) err: $(grep -m3 'cause:\|apply:' "$WORK/b.err" | tr '\n' '|' | cut -c1-400)"
fi

# ================================ c: a hand-edited region, AI_DLC_PULL_RUN unset ===========================
copy_world seed-main c
Cw="$WORK/c"; CB="$(cat "$Cw/.B")"; CT="$(cat "$Cw/.T")"
bash "$REC/pull.sh" dry-run "$Cw/dist" "$CB" "$Cw/c" "$CT" > "$WORK/c-dry.out" 2> "$WORK/c-dry.err" < /dev/null; c_drc=$?
CREP="$Cw/c/_bmad-output/ai-dlc-update/reconcile-report.md"
awk '{print} /BEGIN GENERATED: reconcile-mechanical/ && !d {print "HAND-EDITED  a line the detectors never rendered"; d = 1}' "$CREP" > "$CREP.e" && mv -f "$CREP.e" "$CREP"
c_st0="$(world_git -C "$Cw/c" status --porcelain=v1 --untracked-files=all | git hash-object --stdin)"
env -u AI_DLC_PULL_RUN bash "$REC/apply.sh" "$Cw/dist" "$CB" "$Cw/c" "$CT" > "$WORK/c.out" 2> "$WORK/c.err" < /dev/null; c_rc=$?
c_st1="$(world_git -C "$Cw/c" status --porcelain=v1 --untracked-files=all | git hash-object --stdin)"
if [ "$c_drc" = 0 ] && grep -q '^HAND-EDITED' "$CREP" && [ "$c_rc" = 1 ] && grep -q 'hand-edited' "$WORK/c.err" \
   && [ "$c_st0" = "$c_st1" ] && grep -qF '# driver v1' "$Cw/c/$SENT_REL"; then
  ok "c: a hand-edited region refuses apply.sh (no pull run): exit 1, cause hand-edited, nothing written"
else
  bad "c: dry run rc=$c_drc apply rc=$c_rc err: $(grep -m3 'cause:\|apply:' "$WORK/c.err" | tr '\n' '|' | cut -c1-400)"
fi

# ================================ g: a refused render is never reused ======================================
copy_world seed-main g
G="$WORK/g"; GB="$(cat "$G/.B")"; GT="$(cat "$G/.T")"
count_on g "$WORK/log-g" ledger-reverify.sh
bash "$REC/pull.sh" dry-run "$G/dist" "$GB" "$G/c" "$GT" > "$WORK/g.out" 2> "$WORK/g.err" < /dev/null; g_rc=$?
count_off
G_RUN="$(run_dir "$WORK/g.out")"
g_pc="$(awk -F'\t' '$1 == "preclassify.sh" && $2 == "pre" {print $3}' "$WORK/log-g" | sort | uniq -c | awk '{print $1}' | sort -n | tail -1)"
if grep -q '^PULL run=[^ ]* key= renders=1$' "$WORK/g.out" && grep -q '^REFUSED ledger-reverify' "$WORK/g.out" \
   && [ -n "$G_RUN" ] && [ ! -e "$G_RUN/raw/F" ] && [ "${g_pc:-0}" -ge 2 ]; then
  ok "g: a render with a refused detector keeps no store (empty key), and the verify ran preclassify again ($g_pc starts of one argv)"
else
  bad "g: rc=$g_rc out: $(tr '\n' '|' < "$WORK/g.out" | cut -c1-400) store-F=$([ -e "${G_RUN:-/nonexistent}/raw/F" ] && echo kept || echo none) preclassify-max=$g_pc"
fi

# ================================ c2: an ASK decided without the operator ===================================
copy_world seed-stray s
Sw="$WORK/s"; SB="$(cat "$Sw/.B")"; ST="$(cat "$Sw/.T")"
bash "$REC/pull.sh" apply "$Sw/dist" "$SB" "$Sw/c" "$ST" > "$WORK/s1.out" 2> "$WORK/s1.err" < /dev/null; s1_rc=$?
s_dg="$(awk '$1 == "ASK" && $2 == "orphaned-unknown" {print $4; exit}' "$WORK/s1.out")"
s1_n="$(grep -c '^ASK ' "$WORK/s1.out")" || s1_n=0
S1_HDR="$(sed -n 1p "$Sw/c/.git/ai-dlc-pull/dirty-snapshot" 2>/dev/null)"
if [ "$s1_rc" = 3 ] && [ "$s1_n" = 1 ] && [ "${#s_dg}" = 64 ] && grep -qF '# driver v1' "$Sw/c/$SENT_REL"; then
  ok "c2: round 1 asks once (orphaned-unknown) and exits 3 with nothing written"
else
  bad "c2: round 1 rc=$s1_rc asks=$s1_n out: $(tr '\n' '|' < "$WORK/s1.out" | cut -c1-400)"
fi
rm -f "$Sw/c/.claude/fixtures/stray/run.sh"
s_stamp0="$(git hash-object "$Sw/c/.claude/.ai-dlc-version")"
bash "$REC/pull.sh" apply "$Sw/dist" "$SB" "$Sw/c" "$ST" > "$WORK/s2.out" 2> "$WORK/s2.err" < /dev/null; s2_rc=$?
S2_RUN="$(run_dir "$WORK/s2.out")"
if [ "$s2_rc" = 3 ] && [ -n "$s_dg" ] && grep -q "^ASK-UNANSWERED	orphaned-unknown	core/fixtures/stray/run.sh	${s_dg}\$" "$S2_RUN/apply.err" 2>/dev/null \
   && grep -q "^ASK orphaned-unknown core/fixtures/stray/run.sh ${s_dg} " "$WORK/s2.out" \
   && grep -qF '# driver v1' "$Sw/c/$SENT_REL" && [ "$(git hash-object "$Sw/c/.claude/.ai-dlc-version")" = "$s_stamp0" ]; then
  ok "c2: the ask settled by deleting the file, no answer: ASK-UNANSWERED, exit 3, nothing written"
else
  bad "c2: round 2 rc=$s2_rc out: $(tr '\n' '|' < "$WORK/s2.out" | cut -c1-300) apply.err: $(grep -m2 'ASK-UNANSWERED' "${S2_RUN:-/nonexistent}/apply.err" 2>/dev/null | tr '\n' '|')"
fi
answer "$Sw/c" "Keep or delete the stray? digest $s_dg" "delete it" || bad "c2: the answer hook wrote no record"
bash "$REC/pull.sh" apply "$Sw/dist" "$SB" "$Sw/c" "$ST" > "$WORK/s3.out" 2> "$WORK/s3.err" < /dev/null; s3_rc=$?
if [ "$s3_rc" = 0 ] && grep -qF '# driver v2 UPSTREAM' "$Sw/c/$SENT_REL" \
   && grep -q "^orphaned-unknown	core/fixtures/stray/run.sh	${s_dg}	operator	answered	" "$Sw/c/_bmad-output/ai-dlc-update/pull-decisions.tsv" 2>/dev/null; then
  ok "c2: with a hook-written answer quoting the digest the same apply proceeds and records the operator's decision"
else
  bad "c2: round 3 rc=$s3_rc out: $(tr '\n' '|' < "$WORK/s3.out" | cut -c1-300)"
fi
if grep -q '^SKIP pre-gate-repair .*STATUSLESS-ENTRY' "$WORK/s3.out" && ! grep -q '^WORKLIST pre-gate-repair' "$WORK/s3.out"; then
  ok "p: a validator without the STATUSLESS-ENTRY signature prints SKIP pre-gate-repair and no row"
else
  bad "p: the old validator: $(grep 'pre-gate-repair' "$WORK/s3.out" | tr '\n' '|')"
fi
# vii: two resolution rounds off the update branch (s1 and s2 exit 3 on the ASK before any branch is cut), the
# answer hook appends the history file, round 3 applies: the snapshot round 1 took survives, so the history
# file (absent then) is the pull's write and deliver commits it.
s_snap_hdr() { sed -n 1p "$Sw/c/.git/ai-dlc-pull/dirty-snapshot" 2>/dev/null; }
s_hdr3="$(s_snap_hdr)"
deliver_env s || { echo "FIXTURE BROKEN: deliver_env s" >&2; exit 2; }
deliver_run s "$Sw/dist" "$SB" "$Sw/c" "$ST"; s_drc=$?
s_ns="$(world_git -C "$Sw/c" show --name-status -M --format= HEAD)"
if [ -n "$S1_HDR" ] && [ "$S1_HDR" = "$s_hdr3" ] && [ "$S1_HDR" = "$(s_snap_hdr)" ] && [ "$s_drc" = 0 ] \
   && grep -qx 'DECIDE pr https://example.invalid/pr/1 opened' "$WORK/s-deliver.out" \
   && grep -qx 'A	_bmad-output/operator-answers-history.md' <<<"$s_ns" && grep -q "	$SENT_REL\$" <<<"$s_ns"; then
  ok "vii: two off-branch ask rounds keep round 1's snapshot ($(printf '%s' "$S1_HDR" | awk '{print $4}')), and deliver commits the answer history appended between them"
else
  bad "vii: snapshot header round 1 '$S1_HDR' after round 3 '$s_hdr3' now '$(s_snap_hdr)'; deliver rc=$s_drc out: $(tr '\n' '|' < "$WORK/s-deliver.out" | cut -c1-200) commit: $(tr '\n\t' '| ' <<<"$s_ns" | cut -c1-300)"
fi
# l: an answer given for one theirs never answers the same row once theirs moves.
copy_world seed-stray s4
S4="$WORK/s4"
answer "$S4/c" "Keep or delete the stray? digest $s_dg" "delete it" || bad "l: the answer hook wrote no record"
printf '2.0.1\n' > "$S4/dist/VERSION" && world_commit "$S4/dist" "theirs moves" >/dev/null || { echo "FIXTURE BROKEN: cannot move theirs" >&2; exit 2; }
S4T="$(world_git -C "$S4/dist" rev-parse HEAD)"
# The earlier pull (theirs = ST) left one decision row behind; this pull's first apply render starts the file over.
mkdir -p "$S4/c/_bmad-output/ai-dlc-update" "$S4/c/.git/ai-dlc-pull"
printf 'kind\tpath\tdigest\tdecider\tverdict\tevidence\nrefile\tdocs/earlier-pull.md\t-\tmodel\tkept\tdecided in the earlier pull\n' \
  > "$S4/c/_bmad-output/ai-dlc-update/pull-decisions.tsv"
world_git -C "$S4/dist" rev-parse "$ST" > "$S4/c/.git/ai-dlc-pull/decisions-theirs"
bash "$REC/pull.sh" apply "$S4/dist" "$SB" "$S4/c" "$S4T" > "$WORK/l.out" 2> "$WORK/l.err" < /dev/null; l_rc=$?
bash "$REC/pull.sh" pr-body "$S4/c" > "$WORK/l-pr.out" 2> /dev/null < /dev/null
if ! grep -q 'earlier-pull.md' "$WORK/l-pr.out" && grep -q '^### Decisions' "$WORK/l-pr.out" \
   && [ "$(sed -n 1p "$S4/c/_bmad-output/ai-dlc-update/pull-decisions.tsv")" = "$(printf 'kind\tpath\tdigest\tdecider\tverdict\tevidence')" ]; then
  ok "q: a row the earlier pull decided does not reach this pull's PR body, and the file keeps its six-column header"
else
  bad "q: earlier-pull row still rendered or header lost: $(grep '^| \|^none' "$WORK/l-pr.out" | tr '\n' '~' | cut -c1-300)"
fi
l_dg="$(awk '$1 == "ASK" && $2 == "orphaned-unknown" {print $4; exit}' "$WORK/l.out")"
if [ "$l_rc" = 3 ] && [ "${#l_dg}" = 64 ] && [ "$l_dg" != "$s_dg" ] && [ -n "$s_dg" ]; then
  ok "l: theirs moved, the answer for the earlier theirs does not silence the row: it asks again under a new digest"
else
  bad "l: rc=$l_rc digest now '$l_dg' answered '$s_dg' out: $(tr '\n' '|' < "$WORK/l.out" | cut -c1-300)"
fi

# ================================ c3: a pre-driver record never wedges =====================================
copy_world seed-stray s3
S3="$WORK/s3"
mkdir -p "$S3/c/_bmad-output/ai-dlc-update"
S3REP="$S3/c/_bmad-output/ai-dlc-update/reconcile-report.md"
{ printf '# reconcile report\n\n'; bash "$REC/emit-report.sh" "$S3/dist" "$SB" "$S3/c" "$ST" 2>/dev/null; } > "$S3REP"
bash "$REC/emit-report.sh" --verify "$S3REP" "$S3/dist" "$SB" "$S3/c" "$ST" > /dev/null 2>&1; s3v_rc=$?
S3GD="$S3/c/.git"
rm -f "$S3/c/.claude/fixtures/stray/run.sh"
if [ "$s3v_rc" = 0 ] && [ "$(sed -n 1p "$S3GD/ai-dlc-approved-region" 2>/dev/null)" = "ai-dlc-approved-region 1" ] \
   && [ ! -e "$S3GD/ai-dlc-approved-region.pull" ] && grep -q 'ORPHANED-UNKNOWN' "$S3GD/ai-dlc-approved-region"; then
  bash "$REC/pull.sh" apply "$S3/dist" "$SB" "$S3/c" "$ST" > "$WORK/s3a.out" 2> "$WORK/s3a.err" < /dev/null; s3a_rc=$?
  if [ "$s3a_rc" = 0 ] && grep -qF '# driver v2 UPSTREAM' "$S3/c/$SENT_REL" && [ -e "$S3GD/ai-dlc-approved-region.pull" ]; then
    ok "c3: a pre-driver record (no driver sidecar) carrying a since-settled ASK row is replaced, and pull.sh apply exits 0"
  else
    bad "c3: pull.sh apply over a pre-driver record rc=$s3a_rc out: $(tr '\n' '|' < "$WORK/s3a.out" | cut -c1-400)"
  fi
else
  bad "c3: could not seed a pre-driver record (verify rc=$s3v_rc, header '$(sed -n 1p "$S3GD/ai-dlc-approved-region" 2>/dev/null)')"
fi

# ================================ h, i: pull.sh merge on the override world ================================
copy_world seed-ovr o
Ow="$WORK/o"; OB="$(cat "$Ow/.B")"; OT="$(cat "$Ow/.T")"
OV=.claude/skills/ai-dlc/overrides
bash "$REC/pull.sh" merge "$Ow/dist" "$OB" "$Ow/c" "$OT" "$OV/SKILL__Rule-9.md" > "$WORK/oh.out" 2> "$WORK/oh.err" < /dev/null; oh_rc=$?
if [ "$oh_rc" = 0 ] && grep -qx "DECIDE override-drift $OV/SKILL__Rule-9.md merged" "$WORK/oh.out" && ! grep -q '^ASK ' "$WORK/oh.out" \
   && grep -q 'Tail X THEIRS' "$Ow/c/$OV/SKILL__Rule-9.md" && grep -q 'Tail Y OURS' "$Ow/c/$OV/SKILL__Rule-9.md"; then
  ok "h: a clean override-drift merge takes a DECIDE row and no ASK row"
else
  bad "h: clean merge rc=$oh_rc out: $(tr '\n' '|' < "$WORK/oh.out") err: $(head -c 300 "$WORK/oh.err")"
fi
bash "$REC/pull.sh" merge "$Ow/dist" "$OB" "$Ow/c" "$OT" "$OV/SKILL__Rule-8.md" > "$WORK/oi.out" 2> "$WORK/oi.err" < /dev/null; oi_rc=$?
oi_n="$(grep -c '^ASK ' "$WORK/oi.out")" || oi_n=0
oi_l="$(grep -c "^conflict-hunk	$OV/SKILL__Rule-8.md	" "$Ow/c/.git/ai-dlc-pull/asks.tsv" 2>/dev/null)" || oi_l=0
if [ "$oi_rc" = 3 ] && [ "$oi_n" = 1 ] && grep -q "^ASK conflict-hunk $OV/SKILL__Rule-8.md [0-9a-f]\{64\} " "$WORK/oi.out" && [ "$oi_l" = 1 ]; then
  ok "i: a conflict hunk produces exactly one ASK row and one ledger row"
else
  bad "i: conflict merge rc=$oi_rc asks=$oi_n ledger=$oi_l out: $(tr '\n' '|' < "$WORK/oi.out" | cut -c1-300)"
fi

# ================================ c2b: a direct readopt conflict resolved by hand ==========================
copy_world seed-ovr ob
Ob="$WORK/ob"
bash "$REC/readopt-override.sh" "$Ob/dist" "$OT" "$Ob/c" "$Ob/c/$OV/SKILL__Rule-8.md" --merge > "$WORK/ob-m.out" 2> "$WORK/ob-m.err" < /dev/null; ob_mrc=$?
ob_dg="$(awk -F'\t' '$1 == "conflict-hunk" {print $3; exit}' "$Ob/c/.git/ai-dlc-pull/asks.tsv" 2>/dev/null)"
# The hunk still carries its markers and nothing was asked: no row is pending at finish.
bash "$REC/apply.sh" --finish "$Ob/dist" "$OB" "$Ob/c" "$OT" > "$WORK/ob-mk.out" 2> "$WORK/ob-mk.err" < /dev/null; ob_mkrc=$?
if [ "$ob_mkrc" = 3 ] && grep -q "^ASK-UNANSWERED	conflict-hunk	$OV/SKILL__Rule-8.md	${ob_dg:-none}\$" "$WORK/ob-mk.err"; then
  ok "c2b: markers still in the file, unanswered: apply.sh --finish ASK-UNANSWERED, exit 3"
else
  bad "c2b: markers present, finish rc=$ob_mkrc err: $(grep -m2 'ASK-UNANSWERED\|apply:' "$WORK/ob-mk.err" | tr '\n' '|' | cut -c1-300)"
fi
printf -- '---\nshadows: SKILL.md#Rule 8\nbase_sha: %s\nreason: fixture\n---\n\n## Rule 8 -- Depth\n\nLine A THEIRS, hand-resolved.\n' "$OB" > "$Ob/c/$OV/SKILL__Rule-8.md"
# vi control: a USER_PAUSE-shaped record (the answer record's shape, another header) citing the 8-hex prefix.
mkdir -p "$Ob/c/_bmad-output"
printf '## 2026-11-20T00:00:00Z -- USER_PAUSE\n- Question (lead-authored, NOT covered by the hash): How should the Rule 8 hunk be resolved? digest %s\n\n```text\ntake theirs\n```\n\n' \
  "$(printf '%s' "$ob_dg" | cut -c1-8)" >> "$Ob/c/_bmad-output/operator-answers-history.md"
bash "$REC/pull.sh" finish "$Ob/dist" "$OB" "$Ob/c" "$OT" > "$WORK/ob-f.out" 2> "$WORK/ob-f.err" < /dev/null; ob_frc=$?
if [ "$ob_frc" = 3 ] && grep -q "^ASK conflict-hunk $OV/SKILL__Rule-8.md ${ob_dg:-none} " "$WORK/ob-f.out" && ! grep -q '^NOTE ask-short-cite' "$WORK/ob-f.out"; then
  ok "vi: a USER_PAUSE-shaped record citing the 8-hex prefix: finish re-asks the row with no NOTE ask-short-cite"
else
  bad "vi: USER_PAUSE control finish rc=$ob_frc out: $(tr '\n' '|' < "$WORK/ob-f.out" | cut -c1-300)"
fi
if [ "$ob_mrc" = 1 ] && [ "${#ob_dg}" = 64 ] && [ "$ob_frc" = 3 ] \
   && grep -q "^ASK-UNANSWERED	conflict-hunk	$OV/SKILL__Rule-8.md	${ob_dg}\$" "$WORK/ob-f.err" \
   && grep -q "^ASK conflict-hunk $OV/SKILL__Rule-8.md ${ob_dg} " "$WORK/ob-f.out"; then
  ok "c2b: a direct readopt --merge conflict resolved by hand: pull.sh finish ASK-UNANSWERED, exit 3"
else
  bad "c2b: readopt rc=$ob_mrc digest='$ob_dg' finish rc=$ob_frc err: $(head -c 300 "$WORK/ob-f.err")"
fi
# The same open row refuses apply.sh --finish driven directly (no pull.sh), with the ledger still holding exactly it.
bash "$REC/apply.sh" --finish "$Ob/dist" "$OB" "$Ob/c" "$OT" > "$WORK/ob-af.out" 2> "$WORK/ob-af.err" < /dev/null; ob_afrc=$?
ob_rows="$(grep -c '^conflict-hunk	' "$Ob/c/.git/ai-dlc-pull/asks.tsv" 2>/dev/null)" || ob_rows=0
if [ "$ob_afrc" = 3 ] && [ "$ob_rows" = 1 ] && [ -n "$ob_dg" ] \
   && grep -q "^ASK-UNANSWERED	conflict-hunk	$OV/SKILL__Rule-8.md	${ob_dg}\$" "$WORK/ob-af.err" \
   && ! grep -q "^version: *2\.0\.0" "$Ob/c/.claude/.ai-dlc-version"; then
  ok "c2b: apply.sh --finish run directly refuses the same open ledger row: ASK-UNANSWERED, exit 3, stamp not advanced"
else
  bad "c2b: direct apply.sh --finish rc=$ob_afrc ledger rows=$ob_rows err: $(grep -m2 'ASK-UNANSWERED\|apply:' "$WORK/ob-af.err" | tr '\n' '|' | cut -c1-300)"
fi
# A plain apply.sh (no --finish, no pull run) refuses the same open row before it writes anything.
ob_st0="$(git hash-object "$Ob/c/.claude/.ai-dlc-version")"
bash "$REC/apply.sh" "$Ob/dist" "$OB" "$Ob/c" "$OT" > "$WORK/ob-pl.out" 2> "$WORK/ob-pl.err" < /dev/null; ob_plrc=$?
if [ "$ob_plrc" = 3 ] && grep -q "^ASK-UNANSWERED	conflict-hunk	$OV/SKILL__Rule-8.md	${ob_dg:-none}\$" "$WORK/ob-pl.err" \
   && [ "$(git hash-object "$Ob/c/.claude/.ai-dlc-version")" = "$ob_st0" ]; then
  ok "c2b: a plain apply.sh with the open ledger row refuses: ASK-UNANSWERED, exit 3, nothing written"
else
  bad "c2b: plain apply.sh rc=$ob_plrc err: $(grep -m2 'ASK-UNANSWERED\|apply:' "$WORK/ob-pl.err" | tr '\n' '|' | cut -c1-300)"
fi
# vi: an answer through the hook whose question cites the 8-hex prefix does not count; finish and an apply
# re-run each re-ask the ledger row and say why.
ob_short="$(printf '%s' "$ob_dg" | cut -c1-8)"
answer "$Ob/c" "Resolve the Rule 8 hunk? digest $ob_short" "take theirs" || bad "vi: the answer hook wrote no record"
bash "$REC/pull.sh" finish "$Ob/dist" "$OB" "$Ob/c" "$OT" > "$WORK/vi-f.out" 2> "$WORK/vi-f.err" < /dev/null; vi_frc=$?
bash "$REC/pull.sh" apply "$Ob/dist" "$OB" "$Ob/c" "$OT" > "$WORK/vi-a.out" 2> "$WORK/vi-a.err" < /dev/null; vi_arc=$?
for _vi in f a; do
  _rc="$([ "$_vi" = f ] && echo "$vi_frc" || echo "$vi_arc")"
  if [ "${#ob_short}" = 8 ] && [ "$_rc" = 3 ] && grep -q "^ASK conflict-hunk $OV/SKILL__Rule-8.md ${ob_dg} " "$WORK/vi-$_vi.out" \
     && grep -q "^NOTE ask-short-cite $OV/SKILL__Rule-8.md .* ${ob_dg}\$" "$WORK/vi-$_vi.out"; then
    ok "vi: an answer citing the 8-hex prefix: pull.sh $([ "$_vi" = f ] && echo finish || echo apply) re-asks the ledger row and prints NOTE ask-short-cite"
  else
    bad "vi: short cite, pull.sh $_vi rc=$_rc out: $(tr '\n' '|' < "$WORK/vi-$_vi.out" | cut -c1-300) err: $(head -c 200 "$WORK/vi-$_vi.err")"
  fi
done
# vi (BL-1206): an UPPERCASE 8-hex cite is the same short cite. The history is cleared first so the lowercase record
# above cannot supply the NOTE; the only record is the uppercase one.
rm -f "$Ob/c/_bmad-output/operator-answers-history.md"
# The cite is the shortest digest prefix of 8 or more characters that carries a letter, so upper and lower case differ
# whatever digest this world derived (an all-digit 8-prefix would make the two spellings identical).
ob_shortU=""
for _n in 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32; do
  _c="$(printf '%s' "$ob_dg" | cut -c1-"$_n")"
  case "$_c" in *[a-f]*) ob_shortU="$(printf '%s' "$_c" | tr 'a-f' 'A-F')"; break ;; esac
done
answer "$Ob/c" "Resolve the Rule 8 hunk? digest $ob_shortU" "take theirs" || bad "vi: the answer hook wrote no uppercase record"
bash "$REC/pull.sh" finish "$Ob/dist" "$OB" "$Ob/c" "$OT" > "$WORK/vi-u.out" 2> "$WORK/vi-u.err" < /dev/null; vi_urc=$?
if [ "$ob_shortU" != "$ob_short" ] && [ "$vi_urc" = 3 ] && grep -q "^ASK conflict-hunk $OV/SKILL__Rule-8.md ${ob_dg} " "$WORK/vi-u.out" \
   && grep -q "^NOTE ask-short-cite $OV/SKILL__Rule-8.md .* ${ob_dg}\$" "$WORK/vi-u.out"; then
  ok "vi: an answer citing the UPPERCASE 8-hex prefix: pull.sh finish re-asks the ledger row and prints NOTE ask-short-cite"
else
  bad "vi: uppercase short cite (cite=$ob_shortU) rc=$vi_urc out: $(tr '\n' '|' < "$WORK/vi-u.out" | cut -c1-300)"
fi
answer "$Ob/c" "How should the Rule 8 hunk be resolved? digest $ob_dg" "take theirs" || bad "c2b: the answer hook wrote no record"
bash "$REC/pull.sh" finish "$Ob/dist" "$OB" "$Ob/c" "$OT" > "$WORK/ob-f2.out" 2> "$WORK/ob-f2.err" < /dev/null; ob_f2rc=$?
if [ "$ob_f2rc" != 3 ] && ! grep -q '^ASK-UNANSWERED' "$WORK/ob-f2.err" && ! grep -q '^ASK ' "$WORK/ob-f2.out"; then
  ok "c2b: with a hook-written answer quoting the digest, finish asks nothing (rc=$ob_f2rc)"
else
  bad "c2b: answered, finish rc=$ob_f2rc still asks: $(grep '^ASK' "$WORK/ob-f2.out" | tr '\n' '|')"
fi

# ===== BL-1190 note: pull.sh gate prints the SELF-UPDATE-DEFER row (batch 262 A) =====
copy_world seed-main gt
GT="$WORK/gt"; GTB="$(cat "$GT/.B")"; GTT="$(cat "$GT/.T")"
cp -R "$REC" "$WORK/recgt" || { echo "FIXTURE BROKEN: cannot copy reconcile/ for the gate arm" >&2; exit 2; }
printf '%s\n' '#!/usr/bin/env bash' \
  'printf "SELF-UPDATE-DEFER\tcarry-arm\tgate-stub-defer-reason\n"' \
  'printf "SELF-UPDATE-OK\tgate-stub-control-row\n"' \
  'printf "SELF-UPDATE-SAFE-STOP\tgate-stub-safe-stop\n"' > "$WORK/recgt/self-update-gate.sh"
bash "$WORK/recgt/pull.sh" gate "$GT/dist" "$GTB" "$GT/c" "$GTT" > "$WORK/gt.out" 2> "$WORK/gt.err" < /dev/null; gt_rc=$?
if [ "$gt_rc" = 0 ] && [ "$(sed -n 1p "$WORK/gt.out")" = "GATE DEFER" ] \
   && grep -qxF "$(printf 'SELF-UPDATE-DEFER\tcarry-arm\tgate-stub-defer-reason')" "$WORK/gt.out" \
   && grep -q '^SELF-UPDATE-SAFE-STOP	' "$WORK/gt.out" && ! grep -q 'SELF-UPDATE-OK' "$WORK/gt.out"; then
  ok "gate: pull.sh gate prints the SELF-UPDATE-DEFER row verbatim beside SAFE-STOP and filters the OK control row"
else
  bad "gate: rc=$gt_rc out: $(tr '\n\t' '|/' < "$WORK/gt.out" | cut -c1-300) err: $(head -c 200 "$WORK/gt.err")"
fi
# ===== end BL-1190 note arm =====

report_end reconcile-pull-driver 51
