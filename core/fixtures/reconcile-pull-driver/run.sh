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
#   BL-1202 / BL-1204 (world a gains a tracked settings.json the operator edited before the pull, the pipeline-state schema and a
#   tracked state ledger; the pull's settings merge runs between the first apply and the resolution round):
#   retry   the dirty snapshot (header 2) is kept verbatim over the same-theirs resolution round and holds the pre-merge blob.
#   dirty-d the file the operator edited and the pull's merge also wrote is committed as the pull's change only (equal to the
#           merge of the clean file); the operator's key stays an unstaged diff. It is the clean twin of dirty-overlap.
#   eol     a `text eol=crlf` file dirty at the snapshot that the pull also changed is committed as the repository-form (LF)
#           merge carrying the pull's line only.
#   pw-moved  (world a-ov) the pull's settings line rewritten after finish: deliver REFUSED deliver-pull-writes-moved, HEAD
#           unchanged, remedy `pull.sh record -- <path>`; its quiet twin is world a's deliver (no pull-writes NOTE).
#           record-paths  a second pulled file, clean at the snapshot, edited too: a bare `record` REFUSED record-path-unnamed
#           naming both, the record unchanged.   pw-record  `record -- <both>` exits 0 and records the edits.   dirty-overlap
#           after that: NOTE deliver-dirty-overlap overlap, REFUSED deliver-dirty-overlap rc 2, HEAD and the file unchanged;
#           staged-exit  the whole file staged: deliver still refuses, nothing mutated.   whole-ack  `deliver --whole <path>`
#           commits it whole with NOTE deliver-dirty-whole, and both NOTE pull-writes-rerecorded, in the commit message and
#           the PR body.   staged-clean-twin  (world a-st) dirty-d's file staged whole: deliver commits the merged blob,
#           byte-identical to world a's.   dirty-v1 / dirty-w0  no pre-pull blob
#           recorded: NOTE deliver-dirty-overlap unrecorded, REFUSED, HEAD unchanged.   re-deliver  a second deliver adds no
#           commit.
#   F1      (world s) an apply that hands back nothing never stamps: the stamp reads base, the marker stays, the last line is
#           `NEXT pull.sh finish ...` with the same base; finish with that base exits 0 and stamps theirs.   F1-cms  (world c3)
#           the same under --carried-machinery-slice: neither pair after apply, both pairs after finish.
#   F2      (world c3 copy) a written file reverted before finish: DECIDE finish-unapplied withheld, never
#           finish-base-unverified, the stamp kept.
#   adv     (world c3) the F1-cms finish with an agent-definition check that fires: DECIDE agent-definitions advisory,
#           exit 0, the stamp written and the marker removed.
#   pw-retry  (world k, after an ABANDON to the original branch) a pull-written file edited, the same theirs retried:
#           REFUSED apply-pull-writes-moved, nothing written; twin (no edit): the retry proceeds.
#   pw-unfinished  (world k) a new theirs while the pull's writes are uncommitted: REFUSED apply-pull-unfinished, the
#           snapshot kept; twin (the writes committed): the new theirs's snapshot is written.
#   pw-delivered  (world a-nx) after deliver, an operator edit kept uncommitted in a pull-written file: a new theirs's
#           apply proceeds (deliver wrote pull-writes.delivered); its twin is pw-unfinished (no deliver).
#   rw-stamped  (world a, delivered) finish on a stamped tree with no marker: the restamp-withheld row says so.
#   st      a tracked pipeline-state file a hook appended to after the snapshot stays out; st-ctl the exempt names are committed;
#           st-exempt the exempt names are still schema names; st-noschema (world s) no schema: the NOTE and the file committed.
#   pw-dirty-late  (world a-lt) a file dirty before the pull, named by a decisions row after finish, edited again: deliver refuses it
#           `unrecorded`; its snapshot-blob twin, a state file and a ledger in the same shape are not refused; record demands it by
#           name; `--whole` commits it; (world a-lr) named in the record, deliver merges it.   br-run  Buckets applied skips a run
#           before the snapshot's.   pw-absorb  (world a-ab) finish absorbs an edit to a recorded file; the PR body discloses it.
#   pw-dlv-order  (world a-do) a delivered retry whose snapshot write fails keeps the record, marker and snapshot.
#   nr-fold  thirty derivation-info scopes fold into one PR-body line; report-unverified and reapproval-narrowed survive.
#   ign-untracked  (world a) an untracked file ignored at the snapshot and un-ignored by the pull stays out, NOTE
#           deliver-ignored-untracked names it; twin: a never-ignored untracked file whose directory extends the name is committed.
#   register-unstaged  (world a) the layer-adjudication register, an unstaged edit before the pull, is committed whole.
#   restart-prbody  (world a) the first apply's report restart is one counted `report-restarted` row in the delivered PR body.
#   restart-prune  (world a-rp) a delivered pull retried at the same theirs, restarting at its dry run: the PR body carries only
#           the retry's row.   restart-cleared  (world a-rt) deliver marked the record delivered; a retry that restarts nothing
#           leaves no report-restarted row in the PR body.
#   already-applied  (world a-aa, delivered, stamp at AT) dry-run at AT with base $AB, apply at AT with the abbreviated stamp as
#           base: each REFUSED <cmd>-already-applied rc=2, nothing written.   already-applied-undelivered  (world a before its
#           deliver, no delivery marker) apply refuses naming `pull.sh deliver`, nothing written; world a's deliver opens the PR.
#           base-stale  (world a-nx) a new theirs with base $AB: REFUSED apply-base-stale rc=2, nothing written; its twin is
#           union-commit's round 1 (base the stamp's commit), which proceeds. re-deliver is the command-scope twin (deliver on the
#           stamped tree, base $AB, not refused). The delivered retries (a-rt, a-rp, a-do) run below the stamp: on the pre-pull
#           branch (below_stamp), the update PR unmerged.   restart-count  one report-restarted line per PR body.
#   union-commit  (world a-nx after base-stale) a VERSION-only theirs, base AT, two rounds (ASK blend, which also carries
#           pw-delivered; then a region re-rendered since approval, unseen=0): the union gate proceeds (NOTE blockers-resolved,
#           NEXT pull.sh finish).
#   BL-1249 (world hr, one chain: T1 apply exit 3 on three HARD rows, the remedies written, upstream moves, T2 apply, finish,
#   deliver):   hr-chain  each step's exit.   hr-a  an override clean at T1 and remedied is committed.   hr-b  an override
#           dirty at T1, then remedied: the commit holds the remedy only, the operator's edit stays unstaged.   hr-c  the
#           override `pull.sh register-drift` wrote is committed.   hr-d  a control file written in the window stays untracked
#           and out.   hr-e  the core file register-drift reverted and T2's apply rewrote is committed as theirs.   hr-f  a T1
#           pull-decisions.tsv row survives into the commit.
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
  ESC_SRC="$ROOT/core/skills/ai-dlc/escalations.md"; REC_REL=core/skills/ai-dlc-update/reconcile; HOOK_REL=core/hooks; SKILL_SRC="$ROOT/core/skills/ai-dlc-update/SKILL.md"
elif [ -f "$ROOT/.claude/skills/ai-dlc-update/reconcile/apply.sh" ]; then
  REC_SRC="$ROOT/.claude/skills/ai-dlc-update/reconcile"; HOOK_SRC="$ROOT/.claude/hooks/ai-dlc-answer-capture.sh"
  ESC_SRC="$ROOT/.claude/skills/ai-dlc/escalations.md"; REC_REL=.claude/skills/ai-dlc-update/reconcile; HOOK_REL=.claude/hooks; SKILL_SRC="$ROOT/.claude/skills/ai-dlc-update/SKILL.md"
else
  echo "FIXTURE BROKEN: reconcile/apply.sh not found under $ROOT in either layout (run from the repository root)" >&2
  exit 2
fi
echo "resolved: $REC_SRC"
# THE SUBJECT, AND ITS OLD-TEXT SIGNATURE (a consumer whose engine predates this driver): SKIP, never ok.
if [ ! -f "$REC_SRC/pull.sh" ] || [ ! -f "$REC_SRC/pull-key.sh" ] || [ ! -f "$REC_SRC/ask-families.tsv" ] \
   || ! grep -q '^pk_conflict_ledger() {' "$REC_SRC/pull-key.sh" || ! grep -q 'pk_conflict_ledger' "$REC_SRC/readopt-override.sh" \
   || ! grep -q '^pl_hook_pre_gate_repair() {' "$REC_SRC/pull.sh" || ! grep -q '^pl_deliver_merge() {' "$REC_SRC/pull.sh" \
   || ! grep -qF -- '--stamp-at-finish) STAMP_AT_FINISH=1' "$REC_SRC/apply.sh" || ! grep -q '^pl_writes_record() {' "$REC_SRC/pull.sh" \
   || ! grep -q '^pl_writes_absorbed() {' "$REC_SRC/pull.sh" || ! grep -q '^pl_run_set() {' "$REC_SRC/pull.sh"; then
  echo "SKIP reconcile-pull-driver: reconcile/pull.sh (with its conflict ledger, pre-gate repair, pl_deliver_merge(), the pull-writes record pl_writes_record(), its absorbed-file disclosure pl_writes_absorbed() and run-set lister pl_run_set()) and apply.sh --stamp-at-finish are not installed; they arrive with the pull that carries this fixture"
  fx_skip_exit "$HERE"
fi
[ -f "$HOOK_SRC" ] && [ -f "$ESC_SRC" ] && [ -f "$HERE/escalation-validator.seed" ] \
  || { echo "FIXTURE BROKEN: the answer-capture hook, escalations.md or escalation-validator.seed is missing" >&2; exit 2; }
SCHEMA_SRC=""
for _s in "$ROOT/core/schemas/pipeline-state-paths.json" "$ROOT/.claude/schemas/pipeline-state-paths.json"; do
  [ -f "$_s" ] && { SCHEMA_SRC="$_s"; break; }
done
[ -n "$SCHEMA_SRC" ] || { echo "FIXTURE BROKEN: pipeline-state-paths.json not found under $ROOT in either layout" >&2; exit 2; }
echo "resolved: $SCHEMA_SRC"
for _t in jq git awk; do command -v "$_t" >/dev/null 2>&1 || { echo "FIXTURE BROKEN: $_t is not on PATH" >&2; exit 2; }; done

WORK="$(mktemp -d "${TMPDIR:-/tmp}/reconcile-pull-driver.XXXXXX")" || { echo "FIXTURE BROKEN: mktemp" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd -P)"
# pw-dlv-order sets `chflags uchg` on one file (DO_SNAP); it is cleared before the tree is removed.
trap '[ -z "${DO_SNAP:-}" ] || ! command -v chflags >/dev/null 2>&1 || chflags nouchg "$DO_SNAP" 2>/dev/null; rm -rf "$WORK"' EXIT

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
# pull_state <consumer>: what a refused dry-run/apply must leave byte-identical -- the branch list, HEAD, the status, the
# <git-dir>/ai-dlc-pull listing and each file's checksum, the report and the delivery marker.
pull_state() {
  world_git -C "$1" for-each-ref --format='%(refname) %(objectname)' refs/heads
  world_git -C "$1" rev-parse HEAD
  world_git -C "$1" status --porcelain=v1 --untracked-files=all
  ( cd "$1/.git/ai-dlc-pull" && find . | LC_ALL=C sort && find . -type f -exec cksum {} + | LC_ALL=C sort )
  cksum < "$1/_bmad-output/ai-dlc-update/reconcile-report.md" 2>&1
  cat "$1/.git/ai-dlc-pull/pull-writes.delivered" 2>&1
}

# ================================ a, h, p: pull.sh apply on the pull world ================================
copy_world seed-main a
A="$WORK/a"; AB="$(cat "$A/.B")"; AT="$(cat "$A/.T")"
# report-restart / report-spelling: one real render at the seed pair, spelled with 8-hex refs. World a's pull (below) is to a
# later theirs, so this region describes another pull there; world c's pull is this same pair, spelled in full.
AT0="$AT"
bash "$REC/emit-report.sh" "$A/dist" "${AB:0:8}" "$A/c" "${AT0:0:8}" > "$WORK/region-short" 2> "$WORK/region-short.err" \
  && grep -qx "_base_ \`${AB:0:8}\` → _theirs_ \`${AT0:0:8}\`." "$WORK/region-short" \
  && grep -q 'BEGIN GENERATED: reconcile-mechanical' "$WORK/region-short" \
  || { echo "FIXTURE BROKEN: the 8-hex render of the seed pair failed or carries no 8-hex _base_ line" >&2; exit 2; }
# BL-1202/1204: theirs carries a settings template (the pull's settings merge has a drift row to answer).
mkdir -p "$A/dist/templates" && printf '{\n  "bashOutputMaxChars": 30000\n}\n' > "$A/dist/templates/settings.json.template" \
  && AT="$(prd_dist_commit "$A/dist" "theirs with a settings template")" && printf '%s\n' "$AT" > "$A/.T" \
  || { echo "FIXTURE BROKEN: cannot add the settings template to world a" >&2; exit 2; }
# The deliver arms' operator state, in place before the pull's first apply (arm dl reads it after finish):
# a modified tracked file, an untracked file, a staged edit, a staged rename, and a dirty file a hook appends
# to later; an earlier pull's report and gate record (untracked); and this pull's gate record (pull.sh gate).
mkdir -p "$A/c/notes" "$A/c/_bmad-output/ai-dlc-update" "$A/c/.claude/schemas"
for _f in op-mod op-staged op-ren-old op-append; do printf 'line of %s\n' "$_f" > "$A/c/notes/$_f.txt"; done
# BL-1202/1204: a tracked settings.json (the operator's edit to line 2 is dirty before the pull; the pull's merge appends past
# the last key), the pipeline-state schema, and a tracked pipeline-state ledger a hook appends to later.
cp "$SCHEMA_SRC" "$A/c/.claude/schemas/pipeline-state-paths.json" || { echo "FIXTURE BROKEN: cannot install the schema" >&2; exit 2; }
printf '{\n  "k1": 1,\n  "k2": 2,\n  "k3": 3,\n  "k4": 4,\n  "k5": 5,\n  "k6": 6,\n  "k7": 7,\n  "k8": 8,\n  "operatorCommitted": true\n}\n' \
  > "$A/c/.claude/settings.json"
printf '{"row":1}\n' > "$A/c/_bmad-output/spawn-ledger.jsonl"
printf '{"rec":1}\n' > "$A/c/_bmad-output/subagent-context.jsonl"
# pw-ledger: a tracked ledger inside an exempt tree (planning-artifacts), clean at the snapshot, that a hook appends to after finish.
mkdir -p "$A/c/_bmad-output/planning-artifacts" && printf '{"w":1}\n' > "$A/c/_bmad-output/planning-artifacts/.artifact-writes.jsonl"
# eol: a `text eol=crlf` file, committed from a CRLF worktree (the blob is LF, repository form); the operator edits line 2
# before the pull (dirty at the snapshot, whose raw blob is CRLF) and the pull's resolution round edits line 8.
mkdir -p "$A/c/docs" && printf 'docs/crlf.txt text eol=crlf\n' > "$A/c/.gitattributes" \
  && printf 'c1\r\nc2\r\nc3\r\nc4\r\nc5\r\nc6\r\nc7\r\nc8\r\n' > "$A/c/docs/crlf.txt" || { echo "FIXTURE BROKEN: cannot write the eol file" >&2; exit 2; }
# ign-untracked: a tracked .gitignore ignoring a scratch directory (not a schema state name) that the pull later stops
# ignoring.   register-unstaged: the tracked layer-adjudication register an LC-A1 verdict appends to before the snapshot.
printf '# operator ignores\n_bmad-output/.beats/\n' > "$A/c/.gitignore" \
  && printf '{"r":1}\n' > "$A/c/_bmad-output/ai-dlc-update/layer-adjudication-register.jsonl" || { echo "FIXTURE BROKEN: cannot write the ignore file or the register" >&2; exit 2; }
world_commit "$A/c" "operator notes" >/dev/null || { echo "FIXTURE BROKEN: cannot commit the operator notes" >&2; exit 2; }
[ "$(world_git -C "$A/c" rev-parse HEAD:docs/crlf.txt)" = "$(printf 'c1\nc2\nc3\nc4\nc5\nc6\nc7\nc8\n' | world_git -C "$A/c" hash-object --no-filters --stdin)" ] && [ -z "$(world_git -C "$A/c" status --porcelain=v1 -- docs/crlf.txt)" ] \
  || { echo "FIXTURE BROKEN: the eol file is not LF in HEAD or not clean after its commit" >&2; exit 2; }
printf 'c1\r\nc2 OPERATOR\r\nc3\r\nc4\r\nc5\r\nc6\r\nc7\r\nc8\r\n' > "$A/c/docs/crlf.txt"
printf 'operator edit\n' >> "$A/c/notes/op-mod.txt"
sed 's/"k1": 1,/"k1": "operatorDirtyKey",/' "$A/c/.claude/settings.json" > "$A/c/.claude/settings.json.new" \
  && mv -f "$A/c/.claude/settings.json.new" "$A/c/.claude/settings.json" || { echo "FIXTURE BROKEN: cannot dirty settings.json" >&2; exit 2; }
printf 'operator untracked\n' > "$A/c/notes/op-untracked.txt"
printf 'operator staged\n' >> "$A/c/notes/op-staged.txt"
world_git -C "$A/c" add notes/op-staged.txt && world_git -C "$A/c" mv notes/op-ren-old.txt notes/op-ren-new.txt \
  || { echo "FIXTURE BROKEN: cannot stage the operator entries" >&2; exit 2; }
printf 'operator before the pull\n' >> "$A/c/notes/op-append.txt"
mkdir -p "$A/c/_bmad-output/.beats" && printf 'scratch beat\n' > "$A/c/_bmad-output/.beats/b1.txt" \
  && printf '{"r":2}\n' >> "$A/c/_bmad-output/ai-dlc-update/layer-adjudication-register.jsonl" \
  && [ -z "$(world_git -C "$A/c" status --porcelain=v1 --untracked-files=all -- _bmad-output/.beats)" ] \
  && [ "$(world_git -C "$A/c" status --porcelain=v1 -- _bmad-output/ai-dlc-update/layer-adjudication-register.jsonl)" = " M _bmad-output/ai-dlc-update/layer-adjudication-register.jsonl" ] \
  || { echo "FIXTURE BROKEN: the scratch file is not ignored or the register is not an unstaged edit before the pull" >&2; exit 2; }
# An earlier pull's report: its prose, its region (the seed pair, not this pull's theirs) and a judgment classify block.
{ printf '# AI/DLC reconcile report — an earlier pull\n\n## Worklist resolutions\n\nan earlier pull left this\n\n'; cat "$WORK/region-short"
  printf '\n## Ledger\n\nFILE: core/stale/earlier-pull-only.md\n  - id: stale-judgment-1\n    confirmation_kind: judgment\n'; } \
  > "$A/c/_bmad-output/ai-dlc-update/reconcile-report.md" && cp "$A/c/_bmad-output/ai-dlc-update/reconcile-report.md" "$WORK/a-report.seed" \
  || { echo "FIXTURE BROKEN: cannot seed the earlier pull's report" >&2; exit 2; }
GATE_OLD=_bmad-output/ai-dlc-update/self-update-gate-20200101T000000Z.md
printf '# an earlier pull'"'"'s gate record\n' > "$A/c/$GATE_OLD"
# The pre-pull branch: a delivered retry is re-seated on it (below_stamp), the update PR unmerged.
A_ORIG="$(world_git -C "$A/c" symbolic-ref -q --short HEAD)" && [ -n "$A_ORIG" ] || { echo "FIXTURE BROKEN: world a is not on a branch before its pull" >&2; exit 2; }
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
AREP="$A/c/_bmad-output/ai-dlc-update/reconcile-report.md"
rr_note="NOTE report-restarted ${AB:0:12}..${AT0:0:12} -> ${AB:0:12}..${AT:0:12}: the report's prose described another pull; it was set aside at $A_RUN/report.previous.md"
if [ -n "$A_RUN" ] && [ "$AT0" != "$AT" ] && grep -qxF -- "$rr_note" "$WORK/a.out" && [ "$(grep -c '^NOTE report-restarted ' "$WORK/a.out")" = 1 ] \
   && [ "$(sed -n 1p "$AREP")" = "# reconcile report — ${AB:0:12}..${AT:0:12}" ] && grep -qx "_base_ \`$AB\` → _theirs_ \`$AT\`." "$AREP" \
   && ! grep -q 'stale-judgment-1\|an earlier pull left this' "$AREP" && ! grep -q '^DECIDE judgment ' "$WORK/a.out" \
   && ! grep -q 'stale-judgment-1' "$A/c/_bmad-output/ai-dlc-update/pull-decisions.tsv" && cmp -s "$WORK/a-report.seed" "$A_RUN/report.previous.md"; then
  ok "report-restart: a report whose region describes another pull is set aside in the run dir and restarted under this pull's header, NOTE report-restarted once, and its stale judgment block decides nothing"
else
  bad "report-restart: notes: $(grep '^NOTE report' "$WORK/a.out" | tr '\n' '|') header: '$(sed -n 1p "$AREP")' stale-in-report=$(grep -c 'stale-judgment-1' "$AREP") decide-judgment=$(grep -c '^DECIDE judgment ' "$WORK/a.out") previous=$([ -f "$A_RUN/report.previous.md" ] && echo present || echo absent)"
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
# The same resolution round runs the pull's settings merge (SKILL.md step 5) over the operator's edited settings.json.
SET_T="$WORK/settings.template"; SET_P="$WORK/settings.prior"; printf '{}\n' > "$SET_P"
world_git -C "$A/dist" show "${AT}:templates/settings.json.template" > "$SET_T" || { echo "FIXTURE BROKEN: cannot read the settings template" >&2; exit 2; }
SNAP_A="$A/c/.git/ai-dlc-pull/dirty-snapshot"; snap_a1="$(git hash-object "$SNAP_A")"
( cd "$A/c" && bash "$REC/settings-merge.sh" --consumer .claude/settings.json --template "$SET_T" --prior-template "$SET_P" ) > "$WORK/a-merge.out" 2>&1; sm_rc=$?
# ign-untracked: the resolution round's ignore re-render drops the scratch directory's pattern (its file becomes `??`), and the
# round writes a file under a sibling whose name only extends the dropped one (never ignored): the twin.
printf '# operator ignores\n' > "$A/c/.gitignore" && mkdir -p "$A/c/_bmad-output/.beatsx" && printf 'pull wrote this\n' > "$A/c/_bmad-output/.beatsx/n.txt" \
  && [ "$(world_git -C "$A/c" status --porcelain=v1 --untracked-files=all -- _bmad-output/.beats)" = "?? _bmad-output/.beats/b1.txt" ] \
  || { echo "FIXTURE BROKEN: the scratch file did not become untracked when its ignore pattern was dropped" >&2; exit 2; }
# eol: the resolution round's change to the crlf file, in its worktree (CRLF) form.
printf 'c1\r\nc2 OPERATOR\r\nc3\r\nc4\r\nc5\r\nc6\r\nc7\r\nc8 PULL\r\n' > "$A/c/docs/crlf.txt"
# report-keep: the model's prose and a judgment classify block for this pull, written between rounds, outlive the round.
printf '\n## Worklist resolutions\n\nthis pull'"'"'s model wrote this\n\nFILE: core/keep/this-pull-only.md\n  - id: keep-judgment-1\n    confirmation_kind: judgment\n' >> "$AREP"
outside_region() { awk '/BEGIN GENERATED: reconcile-mechanical/ { r = 1 } !r { print } /END GENERATED: reconcile-mechanical/ { r = 0 }' "$1"; }
rk0="$(outside_region "$AREP" | git hash-object --stdin)"
count_on a "$WORK/log-d"
bash "$REC/pull.sh" apply "$A/dist" "$AB" "$A/c" "$AT" > "$WORK/d.out" 2> "$WORK/d.err" < /dev/null; d_rc=$?
count_off
if [ "$(outside_region "$AREP" | git hash-object --stdin)" = "$rk0" ] && grep -q "this pull's model wrote this" "$AREP" \
   && grep -q 'BEGIN GENERATED: reconcile-mechanical' "$AREP" && ! grep -q '^NOTE report-restarted' "$WORK/d.out" \
   && grep -q '^PULL run=' "$WORK/d.out" && grep -q 'classify block keep-judgment-1 ' "$A/c/_bmad-output/ai-dlc-update/pull-decisions.tsv"; then
  ok "report-keep: a same-pull round keeps every byte outside the region, prints no NOTE report-restarted, and reads this pull's judgment block"
else
  bad "report-keep: outside-region moved=$([ "$(outside_region "$AREP" | git hash-object --stdin)" = "$rk0" ] && echo no || echo yes) notes: $(grep '^NOTE report' "$WORK/d.out" | tr '\n' '|') keep-row=$(grep -c 'keep-judgment-1' "$A/c/_bmad-output/ai-dlc-update/pull-decisions.tsv")"
fi
sw0="$(awk -F'\t' '$4 == ".claude/settings.json" {print $3}' "$SNAP_A")"
sw0_txt="$(world_git -C "$A/c" cat-file blob "$sw0" 2>/dev/null)"
if [ "$sm_rc" = 0 ] && grep -q bashOutputMaxChars "$A/c/.claude/settings.json" && [ "$snap_a1" = "$(git hash-object "$SNAP_A")" ] \
   && [ "$(sed -n 1p "$SNAP_A" | awk '{print $1 " " $2}')" = "ai-dlc-dirty-snapshot 2" ] && [ "${#sw0}" = 40 ] \
   && grep -q operatorDirtyKey <<<"$sw0_txt" && ! grep -q bashOutputMaxChars <<<"$sw0_txt"; then
  ok "retry: a same-theirs resolution round after the settings merge keeps the first dirty snapshot byte for byte (header 2), whose settings.json blob is the pre-merge file"
else
  bad "retry: merge rc=$sm_rc snapshot moved=$([ "$snap_a1" = "$(git hash-object "$SNAP_A")" ] && echo no || echo yes) header='$(sed -n 1p "$SNAP_A")' settings blob='$sw0' has-op-key=$(grep -c operatorDirtyKey <<<"$sw0_txt") has-merge-key=$(grep -c bashOutputMaxChars <<<"$sw0_txt")"
fi
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
# The resolution round (arm d) merged line 8 into the eol file; its row is written in that round, before the finish records the
# pull's writes (a row written after the finish is pw-dirty-late's shape, refused unrecorded).
printf 'refile\tdocs/crlf.txt\t-\tmodel\tkept\tthe resolution round merged line 8 into the eol file\n' >> "$ADEC"
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
# deliver_run <world> <dist> <base> <consumer> <theirs> [<deliver option>...]
deliver_run() {
  PATH="$WORK/bin:$PATH" GH_LOG="$WORK/$1-gh" PRECOMMIT_LOG="$WORK/$1-precommit" PREPUSH_LOG="$WORK/$1-prepush" \
  GIT_AUTHOR_NAME=fixture GIT_AUTHOR_EMAIL=fixture@invalid GIT_COMMITTER_NAME=fixture GIT_COMMITTER_EMAIL=fixture@invalid \
    bash "$REC/pull.sh" deliver "${@:6}" "$2" "$3" "$4" "$5" > "$WORK/$1-deliver.out" 2> "$WORK/$1-deliver.err" < /dev/null
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
# After the snapshot, hooks write pipeline state: the tracked ledger (clean at the snapshot) gains a line, a story file and the
# push-candidate archive appear. Variants of this world are cut here, before deliver_env gives a its remote.
printf '{"row":2}\n' >> "$A/c/_bmad-output/spawn-ledger.jsonl"
# st-rec: a second tracked state file, clean at the snapshot and written after it, that a decisions row of this pull names (column 2).
printf '{"rec":2}\n' >> "$A/c/_bmad-output/subagent-context.jsonl"
printf 'refile\t_bmad-output/subagent-context.jsonl\t-\tmodel\tkept\ta hook-written state file this pull'"'"'s record names\n' >> "$ADEC"
mkdir -p "$A/c/_bmad-output/implementation-artifacts" || { echo "FIXTURE BROKEN: mkdir implementation-artifacts" >&2; exit 2; }
printf 'a hook wrote this story\n' > "$A/c/_bmad-output/implementation-artifacts/story-1.md"
printf '# archive\n' > "$A/c/_bmad-output/ai-dlc-update/push-candidate-ledger.archive.md"
for _v in ov v1 w0 st ns lt ab; do copy_world a "a-$_v"; done
# ov: the pull's change also lands on the line the operator edited (HEAD, the snapshot blob and the worktree all differ there).
sed 's/"k1": "operatorDirtyKey",/"k1": "pullRewroteThis",/' "$WORK/a-ov/c/.claude/settings.json" > "$WORK/a-ov/c/.claude/settings.json.new" \
  && mv -f "$WORK/a-ov/c/.claude/settings.json.new" "$WORK/a-ov/c/.claude/settings.json" || { echo "FIXTURE BROKEN: cannot build world a-ov" >&2; exit 2; }
# v1: a header-1 snapshot records no worktree blobs (column 3 is `-`).   w0: header 2, the settings.json blob absent from the store.
for _v in v1 w0; do
  _sn="$WORK/a-$_v/c/.git/ai-dlc-pull/dirty-snapshot"
  awk -F'\t' -v OFS='\t' -v v="$_v" 'NR == 1 && v == "v1" { sub(/^ai-dlc-dirty-snapshot 2 /, "ai-dlc-dirty-snapshot 1 ") }
    NR > 1 && v == "v1" { $3 = "-" } NR > 1 && v == "w0" && $4 == ".claude/settings.json" { $3 = "0000000000000000000000000000000000000000" } { print }' "$_sn" > "$_sn.new" \
    && mv -f "$_sn.new" "$_sn" || { echo "FIXTURE BROKEN: cannot rewrite the a-$_v snapshot" >&2; exit 2; }
done
[ "$(sed -n 1p "$WORK/a-v1/c/.git/ai-dlc-pull/dirty-snapshot" | awk '{print $2}')" = 1 ] \
  && [ "$(awk -F'\t' '$4 == ".claude/settings.json" {print $3}' "$WORK/a-w0/c/.git/ai-dlc-pull/dirty-snapshot")" = 0000000000000000000000000000000000000000 ] \
  || { echo "FIXTURE BROKEN: the a-v1 / a-w0 snapshot rewrite changed nothing" >&2; exit 2; }
# already-applied-undelivered (world a, finished and not yet delivered: the stamp's commit is AT, no delivery marker): apply at
# AT refuses apply-already-applied naming `pull.sh deliver` and writes nothing -- one property (the marker) from already-applied.
# World a's own deliver below is the remedy followed; its arm is after it.
ud_sc="$(sed -n 's/^commit:[[:space:]]*\([^[:space:]]*\).*/\1/p' "$A/c/.claude/.ai-dlc-version" | head -1)"
[ ! -e "$A/c/.git/ai-dlc-pull/pull-writes.delivered" ] && [ -n "$ud_sc" ] \
  && [ "$(world_git -C "$A/dist" rev-parse -q --verify "${ud_sc}^{commit}")" = "$(world_git -C "$A/dist" rev-parse "$AT")" ] \
  || { echo "FIXTURE BROKEN: world a is not finished-undelivered before its deliver (stamp '$ud_sc', marker $([ -e "$A/c/.git/ai-dlc-pull/pull-writes.delivered" ] && echo present || echo absent))" >&2; exit 2; }
pull_state "$A/c" > "$WORK/a-ud.s0" 2>&1
bash "$REC/pull.sh" apply "$A/dist" "$AB" "$A/c" "$AT" > "$WORK/a-ud-apply.out" 2> "$WORK/a-ud-apply.err" < /dev/null; ud_rc=$?
pull_state "$A/c" > "$WORK/a-ud.s1" 2>&1
deliver_env a || { echo "FIXTURE BROKEN: deliver_env a" >&2; exit 2; }
# Between finish and deliver: a hook appends to the already-dirty file (i-b), and the resolution stages a rename (iii).
printf 'appended after apply\n' >> "$A/c/notes/op-append.txt"
world_git -C "$A/c" mv tests/fixtures/synthetic-fx/run.sh tests/fixtures/synthetic-fx/run-renamed.sh || { echo "FIXTURE BROKEN: cannot stage the rename" >&2; exit 2; }
dl_br="$(world_git -C "$A/c" symbolic-ref -q --short HEAD)"
deliver_run a "$A/dist" "$AB" "$A/c" "$AT"; dl_rc=$?
if [ "$ud_rc" = 2 ] && [ "$(cat "$WORK/a-ud-apply.out")" = "REFUSED apply-already-applied rc=2" ] \
   && grep -qF 'so run `pull.sh deliver` with this pull'"'"'s arguments' "$WORK/a-ud-apply.err" && [ -s "$WORK/a-ud.s0" ] && cmp -s "$WORK/a-ud.s0" "$WORK/a-ud.s1" \
   && [ "$dl_rc" = 0 ] && grep -qx 'DECIDE pr https://example.invalid/pr/1 opened' "$WORK/a-deliver.out" \
   && [ "$(cat "$A/c/.git/ai-dlc-pull/pull-writes.delivered" 2>/dev/null)" = "$(world_git -C "$A/dist" rev-parse "$AT")" ]; then
  ok "already-applied-undelivered: finished, not delivered: apply refuses apply-already-applied naming pull.sh deliver, nothing written; that deliver opens the PR and marks AT delivered"
else
  bad "already-applied-undelivered: apply rc=$ud_rc out: $(tr '\n' '|' < "$WORK/a-ud-apply.out" | cut -c1-120) err: $(head -c 200 "$WORK/a-ud-apply.err") state: $(diff "$WORK/a-ud.s0" "$WORK/a-ud.s1" | head -3 | tr '\n' '|') deliver rc=$dl_rc marker '$(cat "$A/c/.git/ai-dlc-pull/pull-writes.delivered" 2>/dev/null)'"
fi
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
# dirty-d: settings.json, dirty at the snapshot with the operator's key and also written by the pull's merge, is committed as the
# merge of the CLEAN file (the twin: the same merge run in scratch over the pre-deliver HEAD blob); the key stays an unstaged diff.
twin="$WORK/twin-settings.json"; world_git -C "$A/c" show "HEAD^:.claude/settings.json" > "$twin"
( cd "$WORK" && bash "$REC/settings-merge.sh" --consumer "$twin" --template "$SET_T" --prior-template "$SET_P" ) > /dev/null 2>&1
world_git -C "$A/c" show "HEAD:.claude/settings.json" > "$WORK/a-head-settings.json"
dd_diff="$(world_git -C "$A/c" diff HEAD -- .claude/settings.json | grep '^[-+][^-+]')"
dd_want="$(printf '%s\n%s' '-  "k1": 1,' '+  "k1": "operatorDirtyKey",')"
if [ "$dl_rc" = 0 ] && grep -qx 'M	.claude/settings.json' <<<"$dl_ns" && grep -q bashOutputMaxChars "$twin" && cmp -s "$twin" "$WORK/a-head-settings.json" \
   && [ "$dd_diff" = "$dd_want" ] && [ -z "$(world_git -C "$A/c" diff --cached --name-only -- .claude/settings.json)" ] \
   && [ "$(dl_st .claude/settings.json)" = " M .claude/settings.json" ]; then
  ok "dirty-d: a file the operator edited and the pull's merge wrote is committed equal to the merge of the clean file; the operator's key is the whole unstaged diff and nothing is staged for it"
else
  bad "dirty-d: rc=$dl_rc committed==clean-twin: $(cmp -s "$twin" "$WORK/a-head-settings.json" && echo yes || echo no) diff vs HEAD: $(tr '\n' '|' <<<"$dd_diff" | cut -c1-200) status '$(dl_st .claude/settings.json)' commit: $(tr '\n\t' '| ' <<<"$dl_ns" | cut -c1-300)"
fi
# eol: the crlf file is committed as the LF merge carrying the pull's line 8 only; the operator's line 2 stays an unstaged diff.
eol_head="$(world_git -C "$A/c" rev-parse -q --verify HEAD:docs/crlf.txt)"
eol_want="$(printf 'c1\nc2\nc3\nc4\nc5\nc6\nc7\nc8 PULL\n' | world_git -C "$A/c" hash-object --no-filters --stdin)"
if [ "$dl_rc" = 0 ] && grep -qx 'M	docs/crlf.txt' <<<"$dl_ns" && [ -n "$eol_want" ] && [ "$eol_head" = "$eol_want" ] \
   && [ "$(dl_st docs/crlf.txt)" = " M docs/crlf.txt" ] && grep -q 'c2 OPERATOR' "$A/c/docs/crlf.txt"; then
  ok "eol: a text eol=crlf file dirty at the snapshot is committed as the repository-form (LF) merge carrying the pull's line only; the operator's line stays unstaged"
else
  bad "eol: rc=$dl_rc committed '$eol_head' want '$eol_want' status '$(dl_st docs/crlf.txt)' notes: $(grep '^NOTE' "$WORK/a-deliver.out" | tr '\n' '|' | cut -c1-300)"
fi
# st: a tracked state ledger clean at the snapshot and appended to by a hook stays out of the commit, in the worktree, unstaged.
if grep -qx 'M	.claude/settings.json' <<<"$dl_ns" && ! grep -q 'spawn-ledger.jsonl' <<<"$dl_ns" && grep -qx '{"row":2}' "$A/c/_bmad-output/spawn-ledger.jsonl" \
   && [ "$(world_git -C "$A/c" show HEAD:_bmad-output/spawn-ledger.jsonl)" = '{"row":1}' ] \
   && [ "$(dl_st _bmad-output/spawn-ledger.jsonl)" = " M _bmad-output/spawn-ledger.jsonl" ] && [ -z "$(world_git -C "$A/c" diff --cached --name-only -- _bmad-output/spawn-ledger.jsonl)" ]; then
  ok "st: a pipeline-state ledger a hook appended to after the snapshot is not in the commit, keeps its line in the worktree and has nothing staged"
else
  bad "st: ledger in commit: $(grep -c 'spawn-ledger' <<<"$dl_ns") worktree status '$(dl_st _bmad-output/spawn-ledger.jsonl)' HEAD ledger: $(world_git -C "$A/c" show HEAD:_bmad-output/spawn-ledger.jsonl | tr '\n' '|') out: $(grep '^NOTE' "$WORK/a-deliver.out" | tr '\n' '|' | cut -c1-200)"
fi
# st-ctl: the exempt names (and the always-stage archive) are committed, and the schema was read (no NOTE).
if grep -qx 'A	_bmad-output/implementation-artifacts/story-1.md' <<<"$dl_ns" && grep -qx 'A	_bmad-output/ai-dlc-update/push-candidate-ledger.archive.md' <<<"$dl_ns" \
   && ! grep -q '^NOTE deliver-state-unfiltered' "$WORK/a-deliver.out"; then
  ok "st-ctl: a file under implementation-artifacts and the push-candidate archive, both written after the snapshot, are committed, and the state filter was on"
else
  bad "st-ctl: not committed: $(tr '\n\t' '| ' <<<"$dl_ns" | cut -c1-400) notes: $(grep '^NOTE' "$WORK/a-deliver.out" | tr '\n' '|' | cut -c1-200)"
fi
# st-rec: the twin of st. A state file clean at the snapshot, written after it and named by this pull's decisions row IS committed.
if grep -qx 'M	_bmad-output/subagent-context.jsonl' <<<"$dl_ns" && [ "$(world_git -C "$A/c" show HEAD:_bmad-output/subagent-context.jsonl)" = "$(printf '{"rec":1}\n{"rec":2}')" ] \
   && [ "$(awk -F'\t' 'NF != 6' "$ADEC" | wc -l | tr -d ' ')" = 0 ] && ! grep -q 'spawn-ledger.jsonl' <<<"$dl_ns"; then
  ok "st-rec: a state file written after the snapshot and named by a decisions row of this pull is committed with the written line, while the unnamed ledger stays out"
else
  bad "st-rec: not committed: $(tr '\n\t' '| ' <<<"$dl_ns" | cut -c1-300) HEAD file: $(world_git -C "$A/c" show HEAD:_bmad-output/subagent-context.jsonl | tr '\n' '|')"
fi
# ign-untracked: the file ignored when the pull began and un-ignored by the pull stays out and untracked, one NOTE names it; its
# twin under `.beatsx/` (an untracked file the snapshot never saw ignored) is committed.
ign_note="NOTE deliver-ignored-untracked 1 untracked path(s) ignored when the pull began and no longer ignored are left out of this commit as yours: _bmad-output/.beats/b1.txt"
dl_ign_line="$(grep '^NOTE deliver-ignored-untracked ' "$WORK/a-deliver.out" | head -1)"
dl_ign_rest="${dl_ign_line#"$ign_note (full list: ai-dlc-pull/"}"
ign_tail_re='^run-[0-9TZ]+-[0-9]+/deliver[.]ignored under the git dir[)]$'
if [ "$dl_rc" = 0 ] && ! grep -q '\.beats/' <<<"$dl_ns" && [ "$(dl_st _bmad-output/.beats/b1.txt)" = "?? _bmad-output/.beats/b1.txt" ] \
   && [ "$(grep -c '^NOTE deliver-ignored-untracked ' "$WORK/a-deliver.out")" = 1 ] && [ "$dl_ign_rest" != "$dl_ign_line" ] && [[ "$dl_ign_rest" =~ $ign_tail_re ]] \
   && grep -qx 'A	_bmad-output/.beatsx/n.txt' <<<"$dl_ns" && grep -qx 'M	.gitignore' <<<"$dl_ns"; then
  ok "ign-untracked: an untracked file ignored at the snapshot and un-ignored by the pull is left out with one NOTE deliver-ignored-untracked naming it; a never-ignored untracked file beside it is committed"
else
  bad "ign-untracked: b1 status '$(dl_st _bmad-output/.beats/b1.txt)' notes: $(grep '^NOTE deliver-ignored' "$WORK/a-deliver.out" | tr '\n' '|' | cut -c1-300) commit: $(grep 'beats\|gitignore' <<<"$dl_ns" | tr '\n\t' '| ')"
fi
# register-unstaged: the register, an UNSTAGED edit dirty at the snapshot, is committed whole by the one deliver.
reg=_bmad-output/ai-dlc-update/layer-adjudication-register.jsonl
if [ "$dl_rc" = 0 ] && grep -qx "M	$reg" <<<"$dl_ns" && [ "$(world_git -C "$A/c" show "HEAD:$reg")" = "$(printf '{"r":1}\n{"r":2}')" ] && [ -z "$(dl_st "$reg")" ]; then
  ok "register-unstaged: the layer-adjudication register, edited unstaged before the pull, is committed whole and left clean"
else
  bad "register-unstaged: status '$(dl_st "$reg")' HEAD: $(world_git -C "$A/c" show "HEAD:$reg" 2>&1 | tr '\n' '|') commit: $(grep 'register' <<<"$dl_ns" | tr '\n\t' '| ')"
fi
# restart-prbody: the report restart at a's first apply reaches the body deliver handed gh, as one counted row naming the set-aside copy.
a_prs="$(ls "$A/c/.git/ai-dlc-pull"/run-*/pr-body.md 2>/dev/null)"
if [ -n "$a_prs" ] && [ "$(grep -c . <<<"$a_prs")" = 1 ] && grep -qxF -- "- \`report-restarted\`: 1 row(s); paths: ai-dlc-pull/${A_RUN##*/}/report.previous.md" "$a_prs"; then
  ok "restart-prbody: the delivered PR body carries the report-restarted row, counted, naming $A_RUN/report.previous.md"
else
  bad "restart-prbody: bodies: $(tr '\n' ' ' <<<"$a_prs") rows: $(grep 'report-restarted' $a_prs 2>/dev/null | tr '\n' '|' | cut -c1-300)"
fi
# re-deliver: a second deliver makes no new commit.
a_head1="$(world_git -C "$A/c" rev-parse HEAD)"
deliver_run a "$A/dist" "$AB" "$A/c" "$AT"; a_rd_rc=$?
world_git -C "$A/c" show "HEAD:.claude/settings.json" > "$WORK/a-head2-settings.json"
# It is also the stamp gate's command-scope ALLOW twin: the stamp's commit is AT and <base> the held $AB, which dry-run and apply refuse.
a_rd_sc="$(sed -n 's/^commit:[[:space:]]*\([^[:space:]]*\).*/\1/p' "$A/c/.claude/.ai-dlc-version" | head -1)"
if [ "$a_rd_rc" = 0 ] && [ -s "$WORK/a-deliver.out" ] && [ "$a_head1" = "$(world_git -C "$A/c" rev-parse HEAD)" ] && cmp -s "$WORK/a-head2-settings.json" "$WORK/a-head-settings.json" \
   && [ "$(world_git -C "$A/dist" rev-parse -q --verify "${a_rd_sc}^{commit}")" = "$(world_git -C "$A/dist" rev-parse "$AT")" ] && ! grep -q -- '-already-applied\|-base-stale' "$WORK/a-deliver.out"; then
  ok "re-deliver: a second deliver on the tree the stamp says carries AT, base \$AB, is not refused, exits 0 and adds no commit"
else
  bad "re-deliver: rc=$a_rd_rc head moved=$([ "$a_head1" = "$(world_git -C "$A/c" rev-parse HEAD)" ] && echo no || echo yes) out: $(tr '\n' '|' < "$WORK/a-deliver.out" | cut -c1-300) err: $(head -c 200 "$WORK/a-deliver.err")"
fi
# pw-moved, quiet twin: world a's deliver read this pull's record of its own writes (settings.json named in it) and refused nothing.
A_PW="$A/c/.git/ai-dlc-pull/pull-writes"
if [ "$dl_rc" = 0 ] && [ "$(sed -n 1p "$A_PW" 2>/dev/null)" = "ai-dlc-pull-writes 1 $AT" ] && grep -q '^\.claude/settings\.json	' "$A_PW" \
   && ! grep -q '^NOTE pull-writes-moved\|^REFUSED deliver-pull-writes' "$WORK/a-deliver.out"; then
  ok "pw-moved twin: with every file the pull wrote still at its recorded content, deliver reads the record (settings.json in it) and refuses nothing"
else
  bad "pw-moved twin: rc=$dl_rc record header '$(sed -n 1p "$A_PW" 2>/dev/null)' out: $(grep 'pull-writes' "$WORK/a-deliver.out" | tr '\n' '|' | cut -c1-300)"
fi
# pw-delivered: world a is delivered with the operator's settings.json edit still uncommitted, at the content the pull recorded.
# A copy (a-nx) on a plain branch at that commit (the PR merged) applies a new theirs (union-commit's round 1): deliver marked its
# pull delivered, so the kept edit is the operator's and the apply proceeds. Its twin, a pull with no deliver, is pw-unfinished (world ku).
copy_world a a-nx
NX="$WORK/a-nx"
world_git -C "$NX/c" checkout -q -b merged-main || { echo "FIXTURE BROKEN: cannot branch a-nx" >&2; exit 2; }
printf '2.0.1\n' > "$NX/dist/VERSION" && world_commit "$NX/dist" "theirs moves" >/dev/null || { echo "FIXTURE BROKEN: cannot move theirs in a-nx" >&2; exit 2; }
NX_T="$(world_git -C "$NX/dist" rev-parse HEAD)"
nx_sb="$(world_git -C "$NX/c" hash-object --no-filters -- .claude/settings.json)"
nx_pre="$( [ -n "$(world_git -C "$NX/c" status --porcelain=v1 -- .claude/settings.json)" ] && grep -qx ".claude/settings.json	$nx_sb" "$NX/c/.git/ai-dlc-pull/pull-writes" && echo y)"
# The marker is read before the apply: this new pull's own record, once written, clears it.
nx_dl="$(cat "$NX/c/.git/ai-dlc-pull/pull-writes.delivered" 2>/dev/null)"
# base-stale (world a-nx): the stamp's commit is AT, theirs is newer, <base> is the held pre-pull $AB: REFUSED apply-base-stale
# before any write. Its ALLOW twin, one property apart (<base> = the stamp's commit), is union-commit's round 1 on the same world.
pull_state "$NX/c" > "$WORK/a-nb.s0" 2>&1
bash "$REC/pull.sh" apply "$NX/dist" "$AB" "$NX/c" "$NX_T" > "$WORK/a-nb.out" 2> "$WORK/a-nb.err" < /dev/null; nb_rc=$?
pull_state "$NX/c" > "$WORK/a-nb.s1" 2>&1
if [ "$nb_rc" = 2 ] && [ "$(cat "$WORK/a-nb.out")" = "REFUSED apply-base-stale rc=2" ] && grep -q "re-run with $(world_git -C "$NX/dist" rev-parse "$AT") as <base>" "$WORK/a-nb.err" \
   && [ -s "$WORK/a-nb.s0" ] && cmp -s "$WORK/a-nb.s0" "$WORK/a-nb.s1"; then
  ok "base-stale: a new theirs with <base> not the stamp's commit: REFUSED apply-base-stale rc=2 naming the stamp's commit, nothing written"
else
  bad "base-stale: rc=$nb_rc out: $(tr '\n' '|' < "$WORK/a-nb.out" | cut -c1-200) err: $(head -c 300 "$WORK/a-nb.err") state: $(diff "$WORK/a-nb.s0" "$WORK/a-nb.s1" | head -5 | tr '\n' '|')"
fi
# union-commit (apply.sh's union gate), world a-nx: its VERSION-only theirs (core/ equal to the stamp's) applied at base AT in two
# rounds. Round 1, the answers history moved aside, snapshots this theirs and stops at ASK blend (rc 3) with the approved-region
# record written; round 2, the history restored and the alpha-domain extension moved aside, verifies a region re-rendered since
# approval (RE-RENDERED-SINCE-APPROVAL, unseen=0) and PROCEEDS: the stamp's commit is not theirs, so this is no post-apply re-run.
[ "$(world_git -C "$NX/dist" rev-parse "$NX_T:core")" = "$(world_git -C "$NX/dist" rev-parse "$AT:core")" ] \
  || { echo "FIXTURE BROKEN: a-nx's theirs must share AT's core/ tree" >&2; exit 2; }
uc_h=_bmad-output/operator-answers-history.md; uc_x=.claude/skills/ai-dlc/extensions/steps-domain/alpha-domain.md
mv "$NX/c/$uc_h" "$WORK/a-nx.history" || { echo "FIXTURE BROKEN: union-commit: cannot move the history aside" >&2; exit 2; }
bash "$REC/pull.sh" apply "$NX/dist" "$AT" "$NX/c" "$NX_T" > "$WORK/a-nx.out" 2> "$WORK/a-nx.err" < /dev/null; nx_rc=$?
nx_snap="$(sed -n 1p "$NX/c/.git/ai-dlc-pull/dirty-snapshot" | awk '{print $3}')"
[ -f "$NX/c/.git/ai-dlc-approved-region" ] && nx_rec=y || nx_rec=n
# pw-delivered: deliver marked its pull delivered, so the operator's kept edit does not hold this theirs's apply as unfinished.
if [ "$nx_pre" = y ] && [ "$nx_dl" = "$(world_git -C "$NX/dist" rev-parse "$AT")" ] \
   && grep -q '^PULL run=' "$WORK/a-nx.out" && ! grep -q 'pull-writes-unfinished\|apply-pull-unfinished\|^REFUSED' "$WORK/a-nx.out" \
   && [ "$nx_snap" = "$NX_T" ]; then
  ok "pw-delivered: after deliver, an operator edit kept uncommitted in a file the pull wrote does not hold the next theirs's apply as unfinished (rc=$nx_rc, its own snapshot written)"
else
  bad "pw-delivered: precondition='$nx_pre' delivered-before-apply='$nx_dl' rc=$nx_rc snapshot theirs '$nx_snap' out: $(tr '\n' '|' < "$WORK/a-nx.out" | cut -c1-300) err: $(head -c 200 "$WORK/a-nx.err")"
fi
mv "$WORK/a-nx.history" "$NX/c/$uc_h" && mv "$NX/c/$uc_x" "$WORK/a-nx.ext" || { echo "FIXTURE BROKEN: union-commit: cannot restore the history or move the extension" >&2; exit 2; }
bash "$REC/pull.sh" apply "$NX/dist" "$AT" "$NX/c" "$NX_T" > "$WORK/a-nx2.out" 2> "$WORK/a-nx2.err" < /dev/null; nx2_rc=$?
nx2_rd="$(run_dir "$WORK/a-nx2.out")"
if [ "$nx_rc" = 3 ] && grep -q '^ASK blend ' "$WORK/a-nx.out" && [ "$nx_rec" = y ] \
   && [ "$nx2_rc" = 0 ] && grep -q '^NEXT pull.sh finish ' "$WORK/a-nx2.out" && ! grep -q '^REFUSED' "$WORK/a-nx2.out" \
   && [ -n "$nx2_rd" ] && grep -q 'RE-RENDERED-SINCE-APPROVAL' "$nx2_rd/apply.err" && grep -q 'unseen=0' "$nx2_rd/apply.err" \
   && grep -q '^NOTE	blockers-resolved	' "$nx2_rd/apply.out"; then
  ok "union-commit: a VERSION-only theirs (core/ equal to the stamp's) re-rendered since approval proceeds past the union gate (NOTE blockers-resolved, NEXT pull.sh finish)"
else
  bad "union-commit: round 1 rc=$nx_rc record=$nx_rec round 2 rc=$nx2_rc out: $(grep -E '^(REFUSED|NEXT|ASK)' "$WORK/a-nx2.out" | cut -c1-80 | tr '\n' '|') apply.err: $(grep -o '^apply: .\{0,160\}' "$nx2_rd/apply.err" 2>/dev/null | tail -1)"
fi
# pw-delivered-retry, pw-delivered-cleared: world a delivered; the operator's checkout returns to a plain branch (the update branch
# abandoned) and edits a file the pull wrote; the SAME theirs is retried. The pull is finished, so the retry NOTEs, drops the old
# record and takes a FRESH snapshot (the edit reads as the operator's, dirty at the snapshot, never the pull's own). The retry is then
# abandoned undelivered with its writes in the worktree; the NEXT theirs refuses apply-pull-unfinished (the retry's record, not the
# old delivery, decides).
copy_world a a-rt
copy_world a a-do   # pw-dlv-order (below the deliver arms): the delivered world, before rw-stamped's finish moves it
copy_world a a-rp   # restart-prune
copy_world a a-aa   # already-applied
# below_stamp <world> <branch>: the operator back on the pre-pull branch (the update PR unmerged; `checkout -f`, since some git
# builds refuse a merge checkout over staged changes): the stamp's commit is $AB, below theirs, while <git-dir>/ai-dlc-pull still
# says AT was delivered. Each retry arm makes its own edit after it.
below_stamp() {
  world_git -C "$1/c" checkout -q -f -b "$2" "$A_ORIG" 2> "$1.co.err" || { echo "below_stamp $1: checkout -f $A_ORIG: $(head -c 400 "$1.co.err")" >&2; return 1; }
  [ -z "$(world_git -C "$1/c" ls-files -u)" ] \
    && [ "$(world_git -C "$1/dist" rev-parse -q --verify "$(sed -n 's/^commit:[[:space:]]*\([^[:space:]]*\).*/\1/p' "$1/c/.claude/.ai-dlc-version" | head -1)^{commit}")" = "$(world_git -C "$1/dist" rev-parse "$AB")" ] \
    && [ "$(cat "$1/c/.git/ai-dlc-pull/pull-writes.delivered" 2>/dev/null)" = "$(world_git -C "$1/dist" rev-parse "$AT")" ]
}
# already-applied (world a-aa, the delivered world on a plain branch at its commit: the stamp's commit is AT): dry-run at AT with
# the held $AB and apply at AT with the stamp's own abbreviated commit as <base>, each REFUSED <cmd>-already-applied before any write.
AA="$WORK/a-aa"
world_git -C "$AA/c" checkout -q -b merged-aa || { echo "FIXTURE BROKEN: cannot branch a-aa" >&2; exit 2; }
aa_sc="$(sed -n 's/^commit:[[:space:]]*\([^[:space:]]*\).*/\1/p' "$AA/c/.claude/.ai-dlc-version" | head -1)"
[ -n "$aa_sc" ] && [ "$aa_sc" != "$AT" ] && [ "$(world_git -C "$AA/dist" rev-parse -q --verify "${aa_sc}^{commit}")" = "$(world_git -C "$AA/dist" rev-parse "$AT")" ] \
  || { echo "FIXTURE BROKEN: a-aa's stamp ('$aa_sc') is not an abbreviation of AT" >&2; exit 2; }
pull_state "$AA/c" > "$WORK/a-aa.s0" 2>&1
aa_bad=""
for _ab in "dry-run $AB b" "apply $aa_sc s"; do
  read -r _c _b _t <<<"$_ab"
  bash "$REC/pull.sh" "$_c" "$AA/dist" "$_b" "$AA/c" "$AT" > "$WORK/a-aa-$_c-$_t.out" 2> "$WORK/a-aa-$_c-$_t.err" < /dev/null; _rc=$?
  pull_state "$AA/c" > "$WORK/a-aa.s1" 2>&1
  [ "$_rc" = 2 ] && [ "$(cat "$WORK/a-aa-$_c-$_t.out")" = "REFUSED $_c-already-applied rc=2" ] && grep -q 'there is nothing to do here' "$WORK/a-aa-$_c-$_t.err" \
    && cmp -s "$WORK/a-aa.s0" "$WORK/a-aa.s1" || aa_bad="$aa_bad [$_c base=$_t rc=$_rc out=$(tr '\n' '|' < "$WORK/a-aa-$_c-$_t.out" | cut -c1-120) state: $(diff "$WORK/a-aa.s0" "$WORK/a-aa.s1" | head -3 | tr '\n' '|')]"
done
if [ -z "$aa_bad" ] && [ -s "$WORK/a-aa.s0" ]; then
  ok "already-applied: dry-run (base \$AB) and apply (base the abbreviated stamp) at the theirs the stamp records: each REFUSED <cmd>-already-applied rc=2, nothing written"
else
  bad "already-applied:$aa_bad"
fi
RT="$WORK/a-rt"
below_stamp "$RT" merged-rt || { echo "FIXTURE BROKEN: cannot re-seat a-rt below the stamp" >&2; exit 2; }
rt_snap0="$(sed -n 1p "$RT/c/.git/ai-dlc-pull/dirty-snapshot")"
rt_rr0="$(sed -n 1p "$RT/c/.git/ai-dlc-pull/report-restarted" 2>/dev/null)"
rt_rrn="$(grep -c "	ai-dlc-pull/${A_RUN##*/}/report.previous.md	" "$RT/c/.git/ai-dlc-pull/report-restarted" 2>/dev/null)" || rt_rrn=0
printf '\n' >> "$RT/c/.claude/settings.json"
rt_sb="$(world_git -C "$RT/c" hash-object --no-filters -- .claude/settings.json)"
bash "$REC/pull.sh" apply "$RT/dist" "$AB" "$RT/c" "$AT" > "$WORK/a-rt.out" 2> "$WORK/a-rt.err" < /dev/null; rt_rc=$?
if [ "$rt_rc" = 3 ] && grep -q '^ASK blend ' "$WORK/a-rt.out" && grep -q '^NOTE pull-delivered-retry ' "$WORK/a-rt.out" && grep -q '^PULL run=' "$WORK/a-rt.out" \
   && ! grep -q 'apply-pull-writes-moved' "$WORK/a-rt.out" \
   && [ "$(sed -n 1p "$RT/c/.git/ai-dlc-pull/dirty-snapshot")" != "$rt_snap0" ] \
   && awk -F'\t' '$4 == ".claude/settings.json" {f = 1} END {exit !f}' "$RT/c/.git/ai-dlc-pull/dirty-snapshot" \
   && ! grep -q "^.claude/settings.json	$rt_sb\$" "$RT/c/.git/ai-dlc-pull/pull-writes"; then
  ok "pw-delivered-retry: a delivered pull retried at the same theirs after an edit: NOTE, a fresh snapshot holding the edit as dirty, the edit not recorded as the pull's own (rc=$rt_rc)"
else
  bad "pw-delivered-retry: rc=$rt_rc out: $(tr '\n' '|' < "$WORK/a-rt.out" | cut -c1-300) err: $(head -c 200 "$WORK/a-rt.err")"
fi
# restart-cleared (world a-rt): world a's deliver marked its report-restarted record delivered (A_RUN's row in it); the retry,
# which restarts nothing, takes the delivered-retry snapshot path, and no report-restarted row remains in the PR body.
bash "$REC/pull.sh" pr-body "$RT/c" > "$WORK/a-rt-pr.out" 2> "$WORK/a-rt-pr.err" < /dev/null; rtp_rc=$?
if [ "$rt_rr0" = "ai-dlc-report-restarted 1 $(world_git -C "$RT/dist" rev-parse "$AT") delivered" ] && [ "$rt_rrn" = 1 ] \
   && grep -q '^NOTE pull-delivered-retry ' "$WORK/a-rt.out" && ! grep -q '^NOTE report-restarted' "$WORK/a-rt.out" \
   && [ "$rtp_rc" = 0 ] && grep -q '^### Reconcile region' "$WORK/a-rt-pr.out" && ! grep -q 'report-restarted' "$WORK/a-rt-pr.out"; then
  ok "restart-cleared: deliver marks the report-restarted record delivered, and a same-theirs retry that restarts nothing leaves no report-restarted row in the PR body"
else
  bad "restart-cleared: header before retry '$rt_rr0' A_RUN rows=$rt_rrn pr-body rc=$rtp_rc rows: $(grep 'report-restarted' "$WORK/a-rt-pr.out" | tr '\n' '|' | cut -c1-300) record after: '$(sed -n 1p "$RT/c/.git/ai-dlc-pull/report-restarted" 2>/dev/null)'"
fi
# restart-prune (world a-rp, the delivered world): a retry at the same theirs whose dry run meets an earlier pull's report
# restarts it (the record, marked delivered, is replaced); the retry's apply takes the delivered-retry snapshot path, which keeps
# an unmarked record. The apply's own outcome past its snapshot is not this arm's.
RP="$WORK/a-rp"
below_stamp "$RP" merged-rp || { echo "FIXTURE BROKEN: cannot re-seat a-rp below the stamp" >&2; exit 2; }
cp "$WORK/a-report.seed" "$RP/c/_bmad-output/ai-dlc-update/reconcile-report.md" || { echo "FIXTURE BROKEN: a-rp: cannot seed the earlier report" >&2; exit 2; }
bash "$REC/pull.sh" dry-run "$RP/dist" "$AB" "$RP/c" "$AT" > "$WORK/a-rp0.out" 2> "$WORK/a-rp0.err" < /dev/null; rp0_rc=$?
RP0_RUN="$(run_dir "$WORK/a-rp0.out")"
bash "$REC/pull.sh" apply "$RP/dist" "$AB" "$RP/c" "$AT" > "$WORK/a-rp.out" 2> "$WORK/a-rp.err" < /dev/null
bash "$REC/pull.sh" pr-body "$RP/c" > "$WORK/a-rp-pr.out" 2> "$WORK/a-rp-pr.err" < /dev/null; rpp_rc=$?
if [ "$rp0_rc" = 0 ] && [ -n "$RP0_RUN" ] && grep -q '^NOTE report-restarted ' "$WORK/a-rp0.out" && grep -q '^NOTE pull-delivered-retry ' "$WORK/a-rp.out" \
   && [ "$rpp_rc" = 0 ] && grep -qxF -- "- \`report-restarted\`: 1 row(s); paths: ai-dlc-pull/${RP0_RUN##*/}/report.previous.md" "$WORK/a-rp-pr.out"; then
  ok "restart-prune: a delivered pull retried at the same theirs: the PR body carries only the retry's own report-restarted row, never the delivered pull's"
else
  bad "restart-prune: dry-run rc=$rp0_rc run='$RP0_RUN' pr-body rc=$rpp_rc rows: $(grep 'report-restarted' "$WORK/a-rp-pr.out" | tr '\n' '|' | cut -c1-400) apply: $(grep '^NOTE pull-delivered\|^REFUSED' "$WORK/a-rp.out" | tr '\n' '|')"
fi
# restart-count: restart-prbody's body and restart-prune's each carry exactly one report-restarted line.
rc_a="$(grep -c 'report-restarted' $a_prs 2>/dev/null)" || rc_a=0
rc_p="$(grep -c 'report-restarted' "$WORK/a-rp-pr.out" 2>/dev/null)" || rc_p=0
if [ "$rc_a" = 1 ] && [ "$rc_p" = 1 ]; then
  ok "restart-count: the first pull's PR body and the below-stamp retry's each carry exactly one report-restarted line"
else
  bad "restart-count: report-restarted lines: first pull $rc_a, retry $rc_p (each must be 1)"
fi
# The retry stopped at the blend ASK (apply.sh not started, so no record); answer it as rw-stamped does and run it on.
rt_dg="$(awk '$1 == "ASK" && $2 == "blend" {print $4; exit}' "$WORK/a-rt.out")"
if [ "${#rt_dg}" = 64 ] && answer "$RT/c" "Blend the session driver? digest $rt_dg" "blend it"; then
  bash "$REC/pull.sh" apply "$RT/dist" "$AB" "$RT/c" "$AT" > "$WORK/a-rt1.out" 2> "$WORK/a-rt1.err" < /dev/null; rt1_rc=$?
  if [ "$rt1_rc" = 0 ] && grep -q '^PULL run=' "$WORK/a-rt1.out" && ! grep -q '^REFUSED\|^ASK ' "$WORK/a-rt1.out"; then
    ok "pw-delivered-retry apply: the answered retry below the stamp applies (rc=0, PULL run=, no REFUSED or ASK row)"
  else
    bad "pw-delivered-retry apply: rc=$rt1_rc out: $(tr '\n' '|' < "$WORK/a-rt1.out" | cut -c1-300) err: $(head -c 200 "$WORK/a-rt1.err")"
  fi
else
  bad "pw-delivered-cleared: the retry raised no blend ASK to answer: $(tr '\n' '|' < "$WORK/a-rt.out" | cut -c1-200)"
fi
if [ ! -e "$RT/c/.git/ai-dlc-pull/pull-writes.delivered" ] && [ "$(sed -n 1p "$RT/c/.git/ai-dlc-pull/pull-writes" | awk '{print $3}')" = "$(world_git -C "$RT/dist" rev-parse "$AT")" ]; then
  world_git -C "$RT/c" checkout -q merged-rt 2>/dev/null || { echo "FIXTURE BROKEN: cannot abandon a-rt" >&2; exit 2; }
  printf '2.0.2\n' > "$RT/dist/VERSION" && world_commit "$RT/dist" "theirs moves again" >/dev/null || { echo "FIXTURE BROKEN: cannot move theirs in a-rt" >&2; exit 2; }
  RT_T="$(world_git -C "$RT/dist" rev-parse HEAD)"
  bash "$REC/pull.sh" apply "$RT/dist" "$AB" "$RT/c" "$RT_T" > "$WORK/a-rt2.out" 2> "$WORK/a-rt2.err" < /dev/null; rt2_rc=$?
  if [ "$rt2_rc" = 2 ] && grep -qx 'REFUSED apply-pull-unfinished rc=2' "$WORK/a-rt2.out" && grep -q '^NOTE pull-writes-unfinished ' "$WORK/a-rt2.out"; then
    ok "pw-delivered-cleared: the retry's record cleared the delivery marker, so its abandoned writes refuse the next theirs (apply-pull-unfinished)"
  else
    bad "pw-delivered-cleared: rc=$rt2_rc out: $(tr '\n' '|' < "$WORK/a-rt2.out" | cut -c1-300) err: $(head -c 200 "$WORK/a-rt2.err")"
  fi
else
  bad "pw-delivered-cleared: precondition: delivered marker '$(cat "$RT/c/.git/ai-dlc-pull/pull-writes.delivered" 2>/dev/null)' record '$(sed -n 1p "$RT/c/.git/ai-dlc-pull/pull-writes")' out: $(tr '\n' '|' < "$WORK/a-rt1.out" 2>/dev/null | cut -c1-300)"
fi
# rw-stamped: finish on the delivered world a (stamp at theirs, no in-flight marker) withholds on its unverified base; its
# restamp-withheld row says the stamp already reads theirs and the marker is absent, never that either was left in place.
a_sc="$(sed -n 's/^commit:[[:space:]]*//p' "$A/c/.claude/.ai-dlc-version" | head -1)"
# The delivered world re-raises its blend block (arm j's) with a new digest; it is answered as j answers it, then finish re-runs.
bash "$REC/pull.sh" finish "$A/dist" "$AB" "$A/c" "$AT" > "$WORK/a-rw0.out" 2> "$WORK/a-rw0.err" < /dev/null
a_rw_dg="$(awk '$1 == "ASK" && $2 == "blend" {print $4; exit}' "$WORK/a-rw0.out")"
[ "${#a_rw_dg}" = 64 ] && answer "$A/c" "Blend the session driver? digest $a_rw_dg" "blend it" \
  || bad "rw-stamped: the delivered world's finish raised no blend ASK to answer, or the hook wrote no record: $(tr '\n' '|' < "$WORK/a-rw0.out" | cut -c1-200)"
bash "$REC/pull.sh" finish "$A/dist" "$AB" "$A/c" "$AT" > "$WORK/a-rw.out" 2> "$WORK/a-rw.err" < /dev/null; a_rw_rc=$?
a_rw_row="$(cat "$(ls -td "$A/c/.git/ai-dlc-pull"/run-*/ | head -1)finish.out" 2>/dev/null | awk -F'\t' '$2 == "restamp-withheld"')"
if [ "$(world_git -C "$A/dist" rev-parse "$a_sc")" = "$(world_git -C "$A/dist" rev-parse "$AT")" ] && [ ! -e "$A/c/.claude/.ai-dlc-applying" ] \
   && [ "$(grep -c . <<<"$a_rw_row")" = 1 ] && grep -qF "The stamp already reads ${AT} (an earlier apply or finish wrote it) and \`.ai-dlc-applying\` is absent; this run changed neither." <<<"$a_rw_row" \
   && ! grep -q 'deliberately left in place' <<<"$a_rw_row"; then
  ok "rw-stamped: finish on a stamped tree with no marker: the restamp-withheld row says the stamp already reads theirs and the marker is absent"
else
  bad "rw-stamped: rc=$a_rw_rc stamp '$a_sc' row: $(cut -c1-400 <<<"$a_rw_row") out: $(tr '\n' '|' < "$WORK/a-rw.out" | cut -c1-200)"
fi
# ov_state <consumer>: HEAD, the settings.json bytes and the whole status, one line (nothing mutated compares equal).
ov_state() { printf '%s %s %s\n' "$(world_git -C "$1" rev-parse HEAD)" "$(world_git -C "$1" hash-object --no-filters -- .claude/settings.json)" \
  "$(world_git -C "$1" status --porcelain=v1 --untracked-files=all | world_git -C "$1" hash-object --stdin)"; }
# pw-moved: world a-ov rewrites the operator's settings line after finish (a step-7 merge the last driver step did not see):
# deliver refuses, naming the path, before any write.
OV="$WORK/a-ov"
deliver_env a-ov || { echo "FIXTURE BROKEN: deliver_env a-ov" >&2; exit 2; }
ov_s0="$(ov_state "$OV/c")"; ov_br="$(world_git -C "$OV/c" symbolic-ref -q --short HEAD)"
deliver_run a-ov "$OV/dist" "$AB" "$OV/c" "$AT"; ov_m_rc=$?
cp "$WORK/a-ov-deliver.out" "$WORK/a-ov-moved.out"
if [ "$ov_m_rc" = 2 ] && grep -qx 'REFUSED deliver-pull-writes-moved rc=2' "$WORK/a-ov-moved.out" \
   && [ "$(grep -c '^NOTE pull-writes-moved ' "$WORK/a-ov-moved.out")" = 1 ] \
   && grep -q '^NOTE pull-writes-moved \.claude/settings\.json recorded [0-9a-f]\{40\} now [0-9a-f]\{40\}$' "$WORK/a-ov-moved.out" \
   && [ "$(ov_state "$OV/c")" = "$ov_s0" ] && [ -z "$(world_git --git-dir="$WORK/a-ov-origin.git" rev-parse -q --verify "refs/heads/$ov_br" 2>/dev/null)" ] \
   && grep -qF "run ONE \`pull.sh record '$OV/dist' '$AB' '$OV/c' '$AT' -- <path>...\` naming every file above" "$WORK/a-ov-deliver.err"; then
  ok "pw-moved: a file the pull wrote, changed after finish: deliver REFUSED deliver-pull-writes-moved naming it, its remedy naming pull.sh record, HEAD, the file and the status unchanged, nothing pushed"
else
  bad "pw-moved: rc=$ov_m_rc out: $(tr '\n' '|' < "$WORK/a-ov-moved.out" | cut -c1-300) err: $(head -c 400 "$WORK/a-ov-deliver.err") state unchanged: $([ "$(ov_state "$OV/c")" = "$ov_s0" ] && echo yes || echo no)"
fi
# record-paths: a second file the pull wrote, clean at the snapshot (deliver stages it whole), is edited after the finish too.
# A bare `pull.sh record` refuses record-path-unnamed naming both moved files, and the record is unchanged.
OV_PW="$OV/c/.git/ai-dlc-pull/pull-writes"
ov_cp="$(awk -F'\t' -v fs="$OV/c/.git/ai-dlc-pull/dirty-snapshot" 'FILENAME == fs { if (FNR > 1) s[$4] = 1; next }
  FNR > 1 && !($1 in s) && $2 ~ /^[0-9a-f]+$/ && length($2) == 40 { print $1; exit }' "$OV/c/.git/ai-dlc-pull/dirty-snapshot" "$OV_PW")"
[ -n "$ov_cp" ] && [ -f "$OV/c/$ov_cp" ] || { echo "FIXTURE BROKEN: world a-ov records no pulled file clean at the snapshot" >&2; exit 2; }
printf 'operator edit after the finish\n' >> "$OV/c/$ov_cp"
cp "$OV_PW" "$WORK/a-ov-pw0"
# The resolution round's apply disclosed what it absorbed (pw-absorb), so the disclosure list may already exist: it must not move.
ov_rr0="$(cat "$OV_PW.rerecorded" 2>/dev/null)"
bash "$REC/pull.sh" record "$OV/dist" "$AB" "$OV/c" "$AT" > "$WORK/a-ov-rec0.out" 2> "$WORK/a-ov-rec0.err" < /dev/null; ov_r0_rc=$?
if [ "$ov_r0_rc" = 2 ] && grep -qx 'REFUSED record-path-unnamed rc=2' "$WORK/a-ov-rec0.out" \
   && [ "$(grep -c '^NOTE pull-writes-moved ' "$WORK/a-ov-rec0.out")" = 2 ] \
   && grep -q '^NOTE pull-writes-moved \.claude/settings\.json recorded ' "$WORK/a-ov-rec0.out" && grep -qF "NOTE pull-writes-moved $ov_cp recorded " "$WORK/a-ov-rec0.out" \
   && cmp -s "$OV_PW" "$WORK/a-ov-pw0" && [ "$(cat "$OV_PW.rerecorded" 2>/dev/null)" = "$ov_rr0" ] && grep -q 'record <dist> <base> <consumer> <theirs> -- <path>' "$WORK/a-ov-rec0.err"; then
  ok "record-paths: a bare pull.sh record with two moved files refuses record-path-unnamed naming both ($ov_cp), the record unchanged"
else
  bad "record-paths: rc=$ov_r0_rc out: $(tr '\n' '|' < "$WORK/a-ov-rec0.out" | cut -c1-300) err: $(head -c 200 "$WORK/a-ov-rec0.err") record unchanged: $(cmp -s "$OV_PW" "$WORK/a-ov-pw0" && echo yes || echo no)"
fi
# pw-record: on this finished pull `pull.sh record -- <path>...` (the deliver refusal's remedy) exits 0, prints its NOTE and takes
# both edits into the record, and lists both paths for deliver's disclosure.
bash "$REC/pull.sh" record "$OV/dist" "$AB" "$OV/c" "$AT" -- .claude/settings.json "$ov_cp" > "$WORK/a-ov-finish.out" 2> "$WORK/a-ov-finish.err" < /dev/null; ov_f_rc=$?
ov_sb="$(world_git -C "$OV/c" hash-object --no-filters -- .claude/settings.json)"
ov_cb="$(world_git -C "$OV/c" hash-object --no-filters -- "$ov_cp")"
if [ "$ov_f_rc" = 0 ] && grep -q "^NOTE pull-writes-recorded [1-9][0-9]* $AT\$" "$WORK/a-ov-finish.out" \
   && grep -qx ".claude/settings.json	$ov_sb" "$OV_PW" && grep -qxF "$ov_cp	$ov_cb" "$OV_PW" \
   && [ "$(sed -n 1p "$OV_PW.rerecorded")" = "ai-dlc-pull-rerecorded 1 $AT" ] && grep -qx '\.claude/settings\.json' "$OV_PW.rerecorded" && grep -qxF "$ov_cp" "$OV_PW.rerecorded"; then
  ok "pw-record: pull.sh record -- <both> on the finished pull exits 0 with its NOTE, records both at their work-tree content and lists both for disclosure"
else
  bad "pw-record: rc=$ov_f_rc out: $(tr '\n' '|' < "$WORK/a-ov-finish.out" | cut -c1-200) err: $(head -c 200 "$WORK/a-ov-finish.err") row: $(grep '^\.claude/settings\.json' "$OV_PW" 2>/dev/null) rerecorded: $(tr '\n' '|' < "$OV_PW.rerecorded" 2>/dev/null)"
fi
# pw-unrecorded: a tracked file the pull never wrote, clean at the snapshot, is edited after the finish. deliver would stage it
# whole, so it REFUSES deliver-pull-writes-moved naming it (recorded none), HEAD, the status and the remote untouched; then
# `pull.sh record <dist> <base> <consumer> <theirs> -- <path>` on the finished pull exits 0 and puts it in the record.
# The edit stays recorded: the whole-ack deliver below (rc 0) commits it.
OV_UF=.gitattributes
[ -n "$(world_git -C "$OV/c" ls-files -- "$OV_UF")" ] && ! awk -F'\t' -v p="$OV_UF" 'NR > 1 && $4 == p {f = 1} END {exit !f}' "$OV/c/.git/ai-dlc-pull/dirty-snapshot" \
  && ! grep -q "^$OV_UF	" "$OV_PW" || { echo "FIXTURE BROKEN: a-ov $OV_UF is not tracked, clean at the snapshot and unrecorded" >&2; exit 2; }
cp "$OV/c/$OV_UF" "$WORK/a-ov-uf0" && cp "$WORK/a-ov-uf0" "$OV/c/$OV_UF"
OV_LG=_bmad-output/planning-artifacts/.artifact-writes.jsonl
[ -n "$(world_git -C "$OV/c" ls-files -- "$OV_LG")" ] && ! awk -F'\t' -v p="$OV_LG" 'NR > 1 && $4 == p {f = 1} END {exit !f}' "$OV/c/.git/ai-dlc-pull/dirty-snapshot" \
  && [ -z "$(world_git -C "$OV/c" status --porcelain=v1 -- "$OV_LG")" ] || { echo "FIXTURE BROKEN: a-ov $OV_LG is not tracked and clean at the snapshot" >&2; exit 2; }
printf '{"w":2}\n' >> "$OV/c/$OV_LG"   # the hook's append after finish
ov_u0="$(ov_state "$OV/c")"
printf '# operator edit after the finish\n' >> "$OV/c/$OV_UF"
ov_u1="$(ov_state "$OV/c")"
deliver_run a-ov "$OV/dist" "$AB" "$OV/c" "$AT"; ov_u_rc=$?
cp "$WORK/a-ov-deliver.out" "$WORK/a-ov-unrec.out"
if [ "$ov_u_rc" = 2 ] && grep -qx 'REFUSED deliver-pull-writes-moved rc=2' "$WORK/a-ov-unrec.out" \
   && grep -q "^NOTE pull-writes-moved $OV_UF recorded none now [0-9a-f]\{40\}\$" "$WORK/a-ov-unrec.out" && [ "$(grep -c '^NOTE pull-writes-moved ' "$WORK/a-ov-unrec.out")" = 1 ] \
   && [ "$(ov_state "$OV/c")" = "$ov_u1" ] && [ "$ov_u0" != "$ov_u1" ]; then
  ok "pw-unrecorded: a tracked file the pull never wrote, edited after the finish: deliver REFUSED deliver-pull-writes-moved naming it (recorded none), nothing mutated"
else
  bad "pw-unrecorded: rc=$ov_u_rc out: $(tr '\n' '|' < "$WORK/a-ov-unrec.out" | cut -c1-300) err: $(head -c 200 "$WORK/a-ov-deliver.err")"
fi
# The remedy the refusal printed, taken from deliver's stderr and run exactly as printed (its `<path>` placeholder the one thing filled in).
ov_ul="$(grep -o 'pull\.sh record [^`]*' "$WORK/a-ov-deliver.err" | head -1)"
ov_ul="${ov_ul//<path>.../$OV_UF}"
[ "$ov_ul" = "pull.sh record '$OV/dist' '$AB' '$OV/c' '$AT' -- $OV_UF" ] || bad "pw-unrecorded remedy: deliver printed '$ov_ul', want the four positionals single-quoted and the path"
eval "bash \"\$REC/pull.sh\" ${ov_ul#pull.sh }" > "$WORK/a-ov-ur.out" 2> "$WORK/a-ov-ur.err" < /dev/null; ov_ur_rc=$?
if [ "$ov_ur_rc" = 0 ] && grep -q "^NOTE pull-writes-recorded [1-9][0-9]* $AT\$" "$WORK/a-ov-ur.out" \
   && grep -qxF "$OV_UF	$(world_git -C "$OV/c" hash-object --no-filters -- "$OV_UF")" "$OV_PW" && grep -qxF "$OV_UF" "$OV_PW.rerecorded"; then
  ok "pw-unrecorded: the pull.sh record line deliver's refusal printed (four positionals, real values), run as printed on the finished pull, exits 0 and records the unrecorded file"
else
  bad "pw-unrecorded record: rc=$ov_ur_rc out: $(tr '\n' '|' < "$WORK/a-ov-ur.out" | cut -c1-200) err: $(head -c 200 "$WORK/a-ov-ur.err")"
fi
# pw-ledger: the hook's append to the ledger above (tracked, clean at the snapshot, in an exempt tree) is pipeline state: the refusal and
# the record line name only the non-state twin ($OV_UF, refused above), and record neither demands nor takes the ledger.
if [ "$(world_git -C "$OV/c" status --porcelain=v1 -- "$OV_LG")" = " M $OV_LG" ] && grep -q "^NOTE pull-writes-moved $OV_UF recorded none" "$WORK/a-ov-unrec.out" \
   && ! grep -qF "$OV_LG" "$WORK/a-ov-unrec.out" "$WORK/a-ov-deliver.err" "$WORK/a-ov-ur.out" "$WORK/a-ov-ur.err" && [ "$ov_ur_rc" = 0 ] && ! grep -q "^$OV_LG	" "$OV_PW"; then
  ok "pw-ledger: a ledger inside an exempt tree appended to after finish is no recorded-none row and no record demand, while the non-state twin $OV_UF is refused"
else
  bad "pw-ledger: ur rc=$ov_ur_rc unrec: $(grep -c . "$WORK/a-ov-unrec.out") rows $(grep '^NOTE pull-writes-moved' "$WORK/a-ov-unrec.out" | tr '\n' '|' | cut -c1-300) record: $(tr '\n' '|' < "$WORK/a-ov-ur.out" | cut -c1-200)"
fi
# pw-keep: a path an apply.sh row names (so deliver's keep set holds it), tracked and clean at the snapshot, is edited after the finish.
# Keep membership is no exemption: deliver REFUSES deliver-pull-writes-moved naming it. (A state-tree path is filtered whether keep-selected
# or not: arms st, st-ctl, st-rec.) pw-row: the `pull.sh record ...` line an advisory row printed, taken from the finish's real output
# with the marker gone and run exactly as printed, exits 0 and records the path.
ov_kp=""; ov_rl=""; ov_rp=""
for _f in "$OV/c/.git/ai-dlc-pull"/run-*/finish.out "$OV/c/.git/ai-dlc-pull"/run-*/apply.out; do
  [ -f "$_f" ] || continue
  while IFS=$'\t' read -r _k _n _p _t; do
    [ "$_k" = WORKLIST ] || [ "$_k" = DECISION ] || continue
    [ -f "$OV/c/$_p" ] && [ -n "$(world_git -C "$OV/c" ls-files -- "$_p")" ] || continue
    case "$_t" in
      *'`pull.sh record '*) [ -n "$ov_rl" ] || { ov_rp="$_p"; ov_rl="$(printf '%s\n' "$_t" | grep -o 'pull\.sh record [^`]*' | head -1)"; } ;;
    esac
    [ -z "$ov_kp" ] || continue
    awk -F'\t' -v p="$_p" 'NR > 1 && $4 == p {f = 1} END {exit !f}' "$OV/c/.git/ai-dlc-pull/dirty-snapshot" && continue
    grep -q "^$_p	" "$OV_PW" && continue
    [ -z "$(world_git -C "$OV/c" status --porcelain=v1 -- "$_p")" ] || continue
    ov_kp="$_p"
  done < "$_f"
done
ov_rows="$(cat "$OV/c/.git/ai-dlc-pull"/run-*/finish.out "$OV/c/.git/ai-dlc-pull"/run-*/apply.out 2>/dev/null | awk -F'\t' '$1 == "WORKLIST" || $1 == "DECISION" {print $2 ":" $3}' | sort -u | tr '\n' ' ')"
[ -n "$ov_kp" ] || { echo "FIXTURE BROKEN: no row in world a-ov names a tracked, snapshot-clean, unrecorded file: rows: $ov_rows" >&2; exit 2; }
[ -n "$ov_rl" ] || { echo "FIXTURE BROKEN: no row in world a-ov prints a pull.sh record line: rows: $ov_rows" >&2; exit 2; }
cp "$OV/c/$ov_kp" "$WORK/a-ov-kp0"
printf '# operator edit after the finish\n' >> "$OV/c/$ov_kp"
deliver_run a-ov "$OV/dist" "$AB" "$OV/c" "$AT"; ov_k_rc=$?
cp "$WORK/a-ov-deliver.out" "$WORK/a-ov-keep.out"
if [ "$ov_k_rc" = 2 ] && grep -qx 'REFUSED deliver-pull-writes-moved rc=2' "$WORK/a-ov-keep.out" \
   && grep -q "^NOTE pull-writes-moved $ov_kp recorded none now [0-9a-f]\{40\}\$" "$WORK/a-ov-keep.out"; then
  ok "pw-keep: a keep-set path ($ov_kp) clean at the snapshot, edited after the finish: deliver REFUSED deliver-pull-writes-moved naming it (recorded none)"
else
  bad "pw-keep: path=$ov_kp rc=$ov_k_rc out: $(tr '\n' '|' < "$WORK/a-ov-keep.out" | cut -c1-300) err: $(head -c 200 "$WORK/a-ov-deliver.err")"
fi
cp "$WORK/a-ov-kp0" "$OV/c/$ov_kp"
# pw-row: the row's own line, its `<path>` placeholder the one thing filled in; the row's file edited after the finish first.
ov_rl="${ov_rl//<path>.../$ov_rp}"
ov_rl="${ov_rl//$A\//$OV/}"
cp "$OV/c/$ov_rp" "$WORK/a-ov-rp0"
printf '# operator edit after the finish\n' >> "$OV/c/$ov_rp"
eval "bash \"\$REC/pull.sh\" ${ov_rl#pull.sh }" > "$WORK/a-ov-kr.out" 2> "$WORK/a-ov-kr.err" < /dev/null; ov_kr_rc=$?
case "$ov_rl" in "pull.sh record "*" -- $ov_rp") ov_kform=ok ;; *) ov_kform="" ;; esac
if [ -n "$ov_kform" ] && [ "$ov_kr_rc" = 0 ] && grep -qxF "$ov_rp	$(world_git -C "$OV/c" hash-object --no-filters -- "$ov_rp")" "$OV_PW"; then
  ok "pw-row: the pull.sh record line an advisory row printed, run as printed after finish, exits 0 and records $ov_rp"
else
  bad "pw-row: line '$ov_rl' form=$ov_kform rc=$ov_kr_rc out: $(tr '\n' '|' < "$WORK/a-ov-kr.out" | cut -c1-200) err: $(head -c 200 "$WORK/a-ov-kr.err")"
fi
cp "$WORK/a-ov-rp0" "$OV/c/$ov_rp"
bash "$REC/pull.sh" record "$OV/dist" "$AB" "$OV/c" "$AT" -- "$ov_rp" > /dev/null 2>&1 || { echo "FIXTURE BROKEN: cannot re-record $ov_rp after restoring it" >&2; exit 2; }
# dirty-overlap: with that edit in the record the pull's change now lies on the operator's line, so the merge cannot split them:
# REFUSED deliver-dirty-overlap, nothing mutated.
ov_s1="$(ov_state "$OV/c")"
deliver_run a-ov "$OV/dist" "$AB" "$OV/c" "$AT"; ov_rc=$?
cp "$WORK/a-ov-deliver.out" "$WORK/a-ov-overlap.out"
if [ "$ov_rc" = 2 ] && grep -qx 'REFUSED deliver-dirty-overlap rc=2' "$WORK/a-ov-overlap.out" \
   && [ "$(grep -c '^NOTE deliver-dirty-overlap ' "$WORK/a-ov-overlap.out")" = 1 ] && grep -qx 'NOTE deliver-dirty-overlap .claude/settings.json overlap' "$WORK/a-ov-overlap.out" \
   && ! grep -q 'pull-writes-moved' "$WORK/a-ov-overlap.out" && [ "$(ov_state "$OV/c")" = "$ov_s1" ] \
   && grep -q pullRewroteThis "$OV/c/.claude/settings.json" && [ -z "$(world_git --git-dir="$WORK/a-ov-origin.git" rev-parse -q --verify "refs/heads/$ov_br" 2>/dev/null)" ]; then
  ok "dirty-overlap: an operator edit on the line the pull changed: REFUSED deliver-dirty-overlap with one NOTE (overlap), HEAD, the file and the status unchanged, nothing pushed (twin: dirty-d)"
else
  bad "dirty-overlap: finish rc=$ov_f_rc deliver rc=$ov_rc out: $(tr '\n' '|' < "$WORK/a-ov-overlap.out" | cut -c1-300) err: $(head -c 200 "$WORK/a-ov-deliver.err") finish: $(tr '\n' '|' < "$WORK/a-ov-finish.out" | cut -c1-200)"
fi
# staged-exit: the operator stages the whole file: staging is no acknowledgement, so deliver still refuses and mutates nothing.
world_git -C "$OV/c" add -- .claude/settings.json || { echo "FIXTURE BROKEN: cannot stage a-ov settings.json" >&2; exit 2; }
ov_s2="$(ov_state "$OV/c")"
deliver_run a-ov "$OV/dist" "$AB" "$OV/c" "$AT"; ov_x_rc=$?
if [ "$ov_x_rc" = 2 ] && grep -qx 'REFUSED deliver-dirty-overlap rc=2' "$WORK/a-ov-deliver.out" \
   && grep -qx 'NOTE deliver-dirty-overlap .claude/settings.json overlap' "$WORK/a-ov-deliver.out" && [ "$(ov_state "$OV/c")" = "$ov_s2" ] \
   && [ "$(world_git -C "$OV/c" status --porcelain=v1 -- .claude/settings.json)" = "M  .claude/settings.json" ] \
   && grep -q 're-run deliver with `--whole <path>`' "$WORK/a-ov-deliver.err" && [ -z "$(world_git --git-dir="$WORK/a-ov-origin.git" rev-parse -q --verify "refs/heads/$ov_br" 2>/dev/null)" ]; then
  ok "staged-exit: the whole file staged after the refusal: deliver still REFUSED deliver-dirty-overlap, its remedy naming --whole, HEAD, the file and the staged entry unchanged"
else
  bad "staged-exit: rc=$ov_x_rc out: $(tr '\n' '|' < "$WORK/a-ov-deliver.out" | cut -c1-300) err: $(head -c 300 "$WORK/a-ov-deliver.err")"
fi
# whole-ack: `deliver --whole .claude/settings.json` commits the file whole (equal to the worktree) and discloses it, with the two
# re-recorded paths, in the commit message and the PR body.
deliver_run a-ov "$OV/dist" "$AB" "$OV/c" "$AT" --whole .claude/settings.json; ov_w_rc=$?
world_git -C "$OV/c" show HEAD:.claude/settings.json > "$WORK/a-ov-head-settings.json" 2>/dev/null
ov_msg="$(world_git -C "$OV/c" log -1 --format=%B)"
ov_head_cp="$(world_git -C "$OV/c" show "HEAD:$ov_cp")"
ov_pr="$(ls -td "$OV/c/.git/ai-dlc-pull"/run-*/ | head -1)pr-body.md"
ov_wn="NOTE deliver-dirty-whole .claude/settings.json delivered whole at the operator's request; your uncommitted edits in it are in this commit"
ov_rn1="NOTE pull-writes-rerecorded .claude/settings.json re-recorded by pull.sh record at the operator's request; edits made in it after the pull's last step are in this commit"
ov_rn2="NOTE pull-writes-rerecorded $ov_cp re-recorded by pull.sh record at the operator's request; edits made in it after the pull's last step are in this commit"
if [ "$ov_w_rc" = 0 ] && grep -qx 'DECIDE pr https://example.invalid/pr/1 opened' "$WORK/a-ov-deliver.out" && ! grep -q '^NOTE deliver-dirty-overlap' "$WORK/a-ov-deliver.out" \
   && grep -qxF "$ov_wn" <<<"$ov_msg" && grep -qxF "$ov_rn1" <<<"$ov_msg" && grep -qxF "$ov_rn2" <<<"$ov_msg" \
   && grep -qxF -- "- $ov_wn" "$ov_pr" && grep -qxF -- "- $ov_rn2" "$ov_pr" \
   && grep -q pullRewroteThis "$WORK/a-ov-head-settings.json" && cmp -s "$WORK/a-ov-head-settings.json" "$OV/c/.claude/settings.json" \
   && grep -qx 'operator edit after the finish' <<<"$ov_head_cp" \
   && grep -qx '# operator edit after the finish' <<<"$(world_git -C "$OV/c" show "HEAD:$OV_UF")" \
   && [ -z "$(world_git -C "$OV/c" status --porcelain=v1 -- .claude/settings.json)" ]; then
  ok "whole-ack: deliver --whole commits the overlapping file whole (equal to the worktree) and the re-recorded clean file with its edit, each disclosed in the commit message and the PR body"
else
  bad "whole-ack: rc=$ov_w_rc out: $(tr '\n' '|' < "$WORK/a-ov-deliver.out" | cut -c1-300) err: $(head -c 200 "$WORK/a-ov-deliver.err") msg: $(tr '\n' '|' <<<"$ov_msg" | cut -c1-500)"
fi
# pw-ledger (deliver): the whole-ack deliver above commits the ledger too (clean at the snapshot, appended to after finish): the state-tree
# exemption is for the unrecorded-write check and record's demand only, never for deliver's selection.
if [ "$ov_w_rc" = 0 ] && grep -qxF "$OV_LG" <<<"$(world_git -C "$OV/c" show --name-only --format= HEAD)" \
   && [ "$(world_git -C "$OV/c" show "HEAD:$OV_LG")" = "$(cat "$OV/c/$OV_LG")" ] && [ -z "$(world_git -C "$OV/c" status --porcelain=v1 -- "$OV_LG")" ]; then
  ok "pw-ledger: deliver commits the exempt-tree ledger appended to after finish (named by the delivered commit, equal to the worktree) and leaves it clean in git status"
else
  bad "pw-ledger: deliver rc=$ov_w_rc commit files: $(world_git -C "$OV/c" show --name-only --format= HEAD | tr '\n' '|' | cut -c1-300) status: '$(world_git -C "$OV/c" status --porcelain=v1 -- "$OV_LG")'"
fi
# staged-clean-twin: world a-st is world a with dirty-d's settings.json staged whole (its index entry moved since the snapshot and
# equals the worktree); its merge is clean, so deliver commits the merged blob, byte-identical to world a's, and the operator's key
# comes back unstaged.
ST="$WORK/a-st"
deliver_env a-st || { echo "FIXTURE BROKEN: deliver_env a-st" >&2; exit 2; }
world_git -C "$ST/c" add -- .claude/settings.json || { echo "FIXTURE BROKEN: cannot stage a-st settings.json" >&2; exit 2; }
st_sx="$(awk -F'\t' '$4 == ".claude/settings.json" {print $2}' "$ST/c/.git/ai-dlc-pull/dirty-snapshot")"
st_ix="$(world_git -C "$ST/c" rev-parse -q --verify :.claude/settings.json)"
[ -n "$st_ix" ] && [ "$st_ix" != "$st_sx" ] && [ "$st_ix" = "$(world_git -C "$ST/c" hash-object -- .claude/settings.json)" ] \
  || { echo "FIXTURE BROKEN: a-st's staged settings.json does not differ from the snapshot's index blob or the worktree" >&2; exit 2; }
deliver_run a-st "$ST/dist" "$AB" "$ST/c" "$AT"; st_rc=$?
world_git -C "$ST/c" show HEAD:.claude/settings.json > "$WORK/a-st-head-settings.json" 2>/dev/null
if [ "$st_rc" = 0 ] && grep -qx 'DECIDE pr https://example.invalid/pr/1 opened' "$WORK/a-st-deliver.out" \
   && cmp -s "$WORK/a-st-head-settings.json" "$WORK/a-head-settings.json" && grep -q operatorDirtyKey "$ST/c/.claude/settings.json" \
   && [ "$(world_git -C "$ST/c" status --porcelain=v1 -- .claude/settings.json)" = " M .claude/settings.json" ] \
   && ! grep -q '^NOTE deliver-dirty' "$WORK/a-st-deliver.out"; then
  ok "staged-clean-twin: a staged candidate whose merge is clean is committed as the merge, byte-identical to the unstaged twin; the operator's key comes back unstaged"
else
  bad "staged-clean-twin: rc=$st_rc same-as-twin: $(cmp -s "$WORK/a-st-head-settings.json" "$WORK/a-head-settings.json" && echo yes || echo no) status '$(world_git -C "$ST/c" status --porcelain=v1 -- .claude/settings.json)' out: $(tr '\n' '|' < "$WORK/a-st-deliver.out" | cut -c1-300)"
fi
# dirty-v1 / dirty-w0: no pre-pull blob recorded for the path: the merge cannot be made, so deliver refuses (unrecorded).
for _v in v1 w0; do
  _w="$WORK/a-$_v"
  deliver_env "a-$_v" || { echo "FIXTURE BROKEN: deliver_env a-$_v" >&2; exit 2; }
  _s0="$(ov_state "$_w/c")"
  deliver_run "a-$_v" "$_w/dist" "$AB" "$_w/c" "$AT"; _rc=$?
  if [ "$_rc" = 2 ] && grep -qx 'REFUSED deliver-dirty-overlap rc=2' "$WORK/a-$_v-deliver.out" \
     && grep -qx 'NOTE deliver-dirty-overlap .claude/settings.json unrecorded' "$WORK/a-$_v-deliver.out" \
     && [ "$(ov_state "$_w/c")" = "$_s0" ] && grep -q operatorDirtyKey "$_w/c/.claude/settings.json" && grep -q bashOutputMaxChars "$_w/c/.claude/settings.json"; then
    ok "dirty-$_v: no recorded pre-pull blob ($([ "$_v" = v1 ] && echo 'header 1' || echo 'blob absent from the store')): NOTE deliver-dirty-overlap unrecorded, REFUSED, HEAD, the file and the status unchanged"
  else
    bad "dirty-$_v: rc=$_rc out: $(tr '\n' '|' < "$WORK/a-$_v-deliver.out" | cut -c1-300) err: $(head -c 200 "$WORK/a-$_v-deliver.err")"
  fi
done
# st-exempt: every name pull.sh exempts from the state filter is still a name in the schema (the filter's exemption is a list of schema names).
st_ex="$(sed -n 's/^PL_STATE_EXEMPT="\(.*\)"$/\1/p' "$REC/pull.sh")"
st_miss=""; st_n=0
for _n in $st_ex; do
  st_n=$((st_n + 1))
  jq -e --arg n "$_n" '[.paths[].name] | index($n) != null' "$SCHEMA_SRC" > /dev/null 2>&1 || st_miss="$st_miss $_n"
done
if [ "$st_n" -ge 1 ] && [ -z "$st_miss" ]; then
  ok "st-exempt: each of the $st_n names pull.sh exempts from the state filter ($st_ex) is a paths[].name in the schema"
else
  bad "st-exempt: exempt names [$st_ex] count=$st_n, not in the schema:[$st_miss]"
fi

# ================================ pw-dirty-late, br-run: a dirty file the pull keeps after its last step =====
# World a-lt (world a before deliver): notes/op-mod.txt, dirty when the pull began and never selected, is named by a decisions row
# after the finish and edited again; its twins in the same run, each one property apart: notes/op-append.txt (named too, its
# worktree still the snapshot's blob), a state file and a schema ledger (each dirty at the snapshot, named, written after it).
LT="$WORK/a-lt"; LT_GD="$LT/c/.git/ai-dlc-pull"; LT_DEC="$LT/c/_bmad-output/ai-dlc-update/pull-decisions.tsv"
LT_SP=_bmad-output/spawn-ledger.jsonl; LT_LG=_bmad-output/planning-artifacts/.artifact-writes.jsonl
for _p in "$LT_SP" "$LT_LG"; do
  _h="$(world_git -C "$LT/c" rev-parse -q --verify "HEAD:$_p")" && printf ' M\t%s\t%s\t%s\t-\n' "$_h" "$_h" "$_p" >> "$LT_GD/dirty-snapshot" \
    || { echo "FIXTURE BROKEN: a-lt: cannot add the snapshot row of $_p" >&2; exit 2; }
done
printf '{"w":2}\n' >> "$LT/c/$LT_LG"
for _p in notes/op-mod.txt notes/op-append.txt "$LT_SP" "$LT_LG"; do
  printf 'refile\t%s\t-\tmodel\tkept\tnamed after the finish\n' "$_p" >> "$LT_DEC"
done
lt_w0="$(awk -F'\t' 'NR > 1 && $4 == "notes/op-append.txt" {print $3}' "$LT_GD/dirty-snapshot")"
[ "${#lt_w0}" = 40 ] && [ "$(world_git -C "$LT/c" hash-object --no-filters -- notes/op-append.txt)" = "$lt_w0" ] \
  && [ -n "$(world_git -C "$LT/c" status --porcelain=v1 -- notes/op-mod.txt)" ] && ! grep -q '^notes/' "$LT_GD/pull-writes" \
  || { echo "FIXTURE BROKEN: a-lt: op-append is not at its snapshot blob, op-mod is clean, or the record names a notes/ file" >&2; exit 2; }
{ printf 'operator late line\n'; cat "$LT/c/notes/op-mod.txt"; } > "$LT/c/notes/op-mod.txt.new" && mv -f "$LT/c/notes/op-mod.txt.new" "$LT/c/notes/op-mod.txt" \
  || { echo "FIXTURE BROKEN: a-lt: cannot edit op-mod" >&2; exit 2; }
copy_world a-lt a-lr
deliver_env a-lt || { echo "FIXTURE BROKEN: deliver_env a-lt" >&2; exit 2; }
lt_h0="$(world_git -C "$LT/c" rev-parse HEAD)"
deliver_run a-lt "$LT/dist" "$AB" "$LT/c" "$AT"; lt_rc=$?
lt_n="$(grep -c '^NOTE deliver-dirty-overlap ' "$WORK/a-lt-deliver.out")" || lt_n=0
if [ "$lt_rc" = 2 ] && grep -qx 'REFUSED deliver-dirty-overlap rc=2' "$WORK/a-lt-deliver.out" && [ "$lt_n" = 1 ] \
   && grep -qx 'NOTE deliver-dirty-overlap notes/op-mod.txt unrecorded' "$WORK/a-lt-deliver.out" && [ "$(world_git -C "$LT/c" rev-parse HEAD)" = "$lt_h0" ]; then
  ok "pw-dirty-late: a file dirty before the pull, named by a decisions row after the finish and edited again: REFUSED deliver-dirty-overlap, its one NOTE unrecorded; the twin at its snapshot blob, the state file and the ledger are not refused"
else
  bad "pw-dirty-late: rc=$lt_rc overlap NOTEs=$lt_n out: $(tr '\n' '|' < "$WORK/a-lt-deliver.out" | cut -c1-400) err: $(head -c 200 "$WORK/a-lt-deliver.err")"
fi
# The record leg: `record -- <another path>` demands the late file by name.
bash "$REC/pull.sh" record "$LT/dist" "$AB" "$LT/c" "$AT" -- .claude/settings.json > "$WORK/a-lt-rec.out" 2> "$WORK/a-lt-rec.err" < /dev/null; lt_r_rc=$?
lt_rn="$(grep -c '^NOTE pull-writes-moved ' "$WORK/a-lt-rec.out")" || lt_rn=0
if [ "$lt_r_rc" = 2 ] && grep -qx 'REFUSED record-path-unnamed rc=2' "$WORK/a-lt-rec.out" && [ "$lt_rn" = 1 ] \
   && grep -q '^NOTE pull-writes-moved notes/op-mod\.txt recorded none now [0-9a-f]\{40\}$' "$WORK/a-lt-rec.out"; then
  ok "pw-dirty-late record: record naming another path refuses record-path-unnamed, its one NOTE naming the late file (not its snapshot-blob twin)"
else
  bad "pw-dirty-late record: rc=$lt_r_rc moved NOTEs=$lt_rn out: $(tr '\n' '|' < "$WORK/a-lt-rec.out" | cut -c1-400) err: $(head -c 200 "$WORK/a-lt-rec.err")"
fi
# br-run: an old run (5 RESOLVED rows) before the run the snapshot names, a new run after it (2): the commit counts the new run's 2
# beyond world a's own count (its delivered commit, the same runs).
mkdir -p "$LT_GD/run-20000101T000000Z-1" "$LT_GD/run-29990101T000000Z-1" || { echo "FIXTURE BROKEN: a-lt: cannot add the br runs" >&2; exit 2; }
awk 'BEGIN { for (i = 1; i <= 5; i++) printf "RESOLVED\tbucket\tdocs/br-old-%d.md\told run\n", i }' > "$LT_GD/run-20000101T000000Z-1/apply.out"
awk 'BEGIN { for (i = 1; i <= 2; i++) printf "RESOLVED\tbucket\tdocs/br-new-%d.md\tnew run\n", i }' > "$LT_GD/run-29990101T000000Z-1/apply.out"
br_base="$(world_git -C "$A/c" log -1 --format=%B "$a_head1" | sed -n 's/^Buckets applied: \([0-9][0-9]*\)\. .*/\1/p')"
# The late file delivered whole at the operator's request.
deliver_run a-lt "$LT/dist" "$AB" "$LT/c" "$AT" --whole notes/op-mod.txt; lt_w_rc=$?
lt_msg="$(world_git -C "$LT/c" log -1 --format=%B)"
if [ "$lt_w_rc" = 0 ] && grep -qx 'DECIDE pr https://example.invalid/pr/1 opened' "$WORK/a-lt-deliver.out" && ! grep -q '^NOTE deliver-dirty-overlap' "$WORK/a-lt-deliver.out" \
   && grep -qxF "NOTE deliver-dirty-whole notes/op-mod.txt delivered whole at the operator's request; your uncommitted edits in it are in this commit" <<<"$lt_msg" \
   && [ "$(world_git -C "$LT/c" show HEAD:notes/op-mod.txt)" = "$(cat "$LT/c/notes/op-mod.txt")" ]; then
  ok "pw-dirty-late whole: deliver --whole commits the late file equal to the worktree, with its deliver-dirty-whole NOTE"
else
  bad "pw-dirty-late whole: rc=$lt_w_rc out: $(tr '\n' '|' < "$WORK/a-lt-deliver.out" | cut -c1-300) err: $(head -c 200 "$WORK/a-lt-deliver.err") msg: $(tr '\n' '|' <<<"$lt_msg" | cut -c1-300)"
fi
if [ -n "$br_base" ] && grep -qx "Buckets applied: $((br_base + 2))\. .*" <<<"$lt_msg"; then
  ok "br-run: Buckets applied counts the new run's 2 RESOLVED rows over world a's $br_base, never the 5 of a run before the snapshot's"
else
  bad "br-run: world a counted '$br_base'; this commit: $(grep '^Buckets applied' <<<"$lt_msg")"
fi
# pw-dirty-late named (world a-lr, the same state): `record -- notes/op-mod.txt` names the late file, so deliver merges it: the operator's
# pre-pull line stays out of the commit, the named line is in it, nothing refused.
LR="$WORK/a-lr"
bash "$REC/pull.sh" record "$LR/dist" "$AB" "$LR/c" "$AT" -- notes/op-mod.txt > "$WORK/a-lr-rec.out" 2> "$WORK/a-lr-rec.err" < /dev/null; lr_r_rc=$?
deliver_env a-lr || { echo "FIXTURE BROKEN: deliver_env a-lr" >&2; exit 2; }
deliver_run a-lr "$LR/dist" "$AB" "$LR/c" "$AT"; lr_rc=$?
lr_head="$(world_git -C "$LR/c" show HEAD:notes/op-mod.txt 2>/dev/null)"
if [ "$lr_r_rc" = 0 ] && [ "$lr_rc" = 0 ] && ! grep -q '^NOTE deliver-dirty-overlap' "$WORK/a-lr-deliver.out" \
   && [ "$lr_head" = "$(printf 'operator late line\nline of op-mod')" ] && grep -qx 'operator edit' "$LR/c/notes/op-mod.txt"; then
  ok "pw-dirty-late named: the record naming the late file, deliver merges it (the named line in, the pre-pull edit out) and refuses nothing"
else
  bad "pw-dirty-late named: record rc=$lr_r_rc deliver rc=$lr_rc HEAD file: $(tr '\n' '|' <<<"$lr_head") out: $(tr '\n' '|' < "$WORK/a-lr-deliver.out" | cut -c1-300) err: $(head -c 200 "$WORK/a-lr-deliver.err")"
fi

# ================================ pw-absorb: finish absorbs an edit to a recorded file, and deliver discloses it ======
# World a-ab (world a before deliver, on the update branch): finish re-run unchanged, then again after an edit to a file the record names.
ABW="$WORK/a-ab"
grep -q "^$SENT_REL	" "$ABW/c/.git/ai-dlc-pull/pull-writes" || { echo "FIXTURE BROKEN: a-ab: the record does not name $SENT_REL" >&2; exit 2; }
bash "$REC/pull.sh" finish "$ABW/dist" "$AB" "$ABW/c" "$AT" > "$WORK/a-ab0.out" 2> "$WORK/a-ab0.err" < /dev/null; ab0_rc=$?
printf '# operator edit after the finish\n' >> "$ABW/c/$SENT_REL"
bash "$REC/pull.sh" finish "$ABW/dist" "$AB" "$ABW/c" "$AT" > "$WORK/a-ab1.out" 2> "$WORK/a-ab1.err" < /dev/null; ab1_rc=$?
deliver_env a-ab || { echo "FIXTURE BROKEN: deliver_env a-ab" >&2; exit 2; }
deliver_run a-ab "$ABW/dist" "$AB" "$ABW/c" "$AT"; ab_rc=$?
ab_pr="$(ls -td "$ABW/c/.git/ai-dlc-pull"/run-*/ | head -1)pr-body.md"
ab_n="NOTE pull-writes-rerecorded $SENT_REL absorbed by pull.sh finish, which re-recorded it as the pull's own; changed between driver steps (a WORKLIST or step-7 edit, or yours); now in this commit"
if [ "$ab1_rc" = "$ab0_rc" ] && ! grep -q '^NOTE pull-writes-absorbed' "$WORK/a-ab0.out" \
   && grep -q "^NOTE pull-writes-absorbed $SENT_REL recorded [0-9a-f]\{40\} now [0-9a-f]\{40\} by finish\$" "$WORK/a-ab1.out" \
   && [ "$ab_rc" = 0 ] && grep -qxF -- "- $ab_n" "$ab_pr" && grep -qx '# operator edit after the finish' <<<"$(world_git -C "$ABW/c" show "HEAD:$SENT_REL")"; then
  ok "pw-absorb: finish re-run after an edit to a recorded file exits as it does without it ($ab1_rc), NOTEs the absorbed file, and deliver's PR body names it absorbed by pull.sh finish"
else
  bad "pw-absorb: finish rc $ab0_rc/$ab1_rc deliver rc=$ab_rc ab1: $(grep 'pull-writes' "$WORK/a-ab1.out" | tr '\n' '|' | cut -c1-300) pr: $(grep 'pull-writes' "$ab_pr" 2>/dev/null | tr '\n' '|' | cut -c1-300) err: $(head -c 200 "$WORK/a-ab-deliver.err")"
fi

# ================================ pw-dlv-order: a delivered retry whose snapshot write fails keeps its record ======
# World a-do (world a delivered, then on a plain branch) retries the same theirs while the snapshot cannot be replaced (a `chflags uchg`
# file: its rename fails, deletes beside it work; where chflags is absent, an `mv` on PATH that fails for that one target).
DO="$WORK/a-do"; DO_PW="$DO/c/.git/ai-dlc-pull/pull-writes"
below_stamp "$DO" merged-do || { echo "FIXTURE BROKEN: cannot re-seat a-do below the stamp" >&2; exit 2; }
[ -f "$DO_PW" ] && [ -f "$DO_PW.delivered" ] || { echo "FIXTURE BROKEN: a-do holds no record or no delivery marker" >&2; exit 2; }
cp "$DO_PW" "$WORK/a-do-pw0" && cp "$DO_PW.delivered" "$WORK/a-do-dl0" && cp "$DO/c/.git/ai-dlc-pull/dirty-snapshot" "$WORK/a-do-snap0" \
  || { echo "FIXTURE BROKEN: a-do: cannot save the records" >&2; exit 2; }
do_path="$PATH"
if command -v chflags >/dev/null 2>&1; then
  DO_SNAP="$DO/c/.git/ai-dlc-pull/dirty-snapshot"; chflags uchg "$DO_SNAP" || { echo "FIXTURE BROKEN: chflags uchg" >&2; exit 2; }
else
  mkdir -p "$WORK/do-bin" && printf '%s\n' '#!/usr/bin/env bash' 'for _a in "$@"; do _l="$_a"; done' \
    'case "$_l" in */ai-dlc-pull/dirty-snapshot) echo "mv: injected failure" >&2; exit 1 ;; esac' "exec $(command -v mv) \"\$@\"" > "$WORK/do-bin/mv" \
    && chmod +x "$WORK/do-bin/mv" || { echo "FIXTURE BROKEN: cannot write the mv shim" >&2; exit 2; }
  do_path="$WORK/do-bin:$PATH"
fi
PATH="$do_path" bash "$REC/pull.sh" apply "$DO/dist" "$AB" "$DO/c" "$AT" > "$WORK/a-do.out" 2> "$WORK/a-do.err" < /dev/null; do_rc=$?
if [ -n "${DO_SNAP:-}" ]; then chflags nouchg "$DO_SNAP" || { echo "FIXTURE BROKEN: chflags nouchg" >&2; exit 2; }; DO_SNAP=""; fi
if [ "$do_rc" = 2 ] && grep -qx 'REFUSED dirty-snapshot rc=2' "$WORK/a-do.out" && grep -q '^NOTE pull-delivered-retry ' "$WORK/a-do.out" && cmp -s "$DO_PW" "$WORK/a-do-pw0" \
   && cmp -s "$DO_PW.delivered" "$WORK/a-do-dl0" && cmp -s "$DO/c/.git/ai-dlc-pull/dirty-snapshot" "$WORK/a-do-snap0"; then
  ok "pw-dlv-order: a delivered retry whose fresh snapshot cannot be written (rc=$do_rc) keeps the record, the delivery marker and the old snapshot byte for byte (twin: pw-delivered-retry)"
else
  bad "pw-dlv-order: rc=$do_rc record kept: $(cmp -s "$DO_PW" "$WORK/a-do-pw0" && echo y || echo n) marker kept: $(cmp -s "$DO_PW.delivered" "$WORK/a-do-dl0" && echo y || echo n) snapshot kept: $(cmp -s "$DO/c/.git/ai-dlc-pull/dirty-snapshot" "$WORK/a-do-snap0" && echo y || echo n) out: $(tr '\n' '|' < "$WORK/a-do.out" | cut -c1-300) err: $(head -c 200 "$WORK/a-do.err")"
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

# ns: world a-ns: the snapshot on disk names an EARLIER theirs while this theirs's record is current (its apply ran on an ai-dlc-update/*
# branch and wrote no snapshot): deliver and `record` take the deliver-no-snapshot path and refuse nothing.
NS="$WORK/a-ns"
ns_snap="$NS/c/.git/ai-dlc-pull/dirty-snapshot"
awk 'NR == 1 { $3 = "0000000000000000000000000000000000000000" } { print }' "$ns_snap" > "$ns_snap.new" && mv -f "$ns_snap.new" "$ns_snap" || { echo "FIXTURE BROKEN: cannot rewrite the a-ns snapshot header" >&2; exit 2; }
[ "$(sed -n 1p "$ns_snap" | awk '{print $3}')" != "$(sed -n 1p "$NS/c/.git/ai-dlc-pull/pull-writes" | awk '{print $3}')" ] || { echo "FIXTURE BROKEN: a-ns snapshot and record name the same theirs" >&2; exit 2; }
deliver_env a-ns || { echo "FIXTURE BROKEN: deliver_env a-ns" >&2; exit 2; }
bash "$REC/pull.sh" record "$NS/dist" "$AB" "$NS/c" "$AT" > "$WORK/a-ns-rec.out" 2> "$WORK/a-ns-rec.err" < /dev/null; ns_rec_rc=$?
deliver_run a-ns "$NS/dist" "$AB" "$NS/c" "$AT"; ns_rc=$?
if [ "$ns_rec_rc" = 0 ] && [ "$ns_rc" = 0 ] && grep -q '^NOTE deliver-no-snapshot ' "$WORK/a-ns-deliver.out" \
   && ! grep -q 'pull-writes-read\|record-read' "$WORK/a-ns-rec.out" "$WORK/a-ns-rec.err" "$WORK/a-ns-deliver.out" "$WORK/a-ns-deliver.err"; then
  ok "ns: a snapshot naming an earlier theirs with this theirs's record current: record rc 0, deliver rc 0 with NOTE deliver-no-snapshot, no pull-writes-read refusal"
else
  bad "ns: record rc=$ns_rec_rc ($(tr '\n' '|' < "$WORK/a-ns-rec.out" | cut -c1-200) $(head -c 200 "$WORK/a-ns-rec.err")) deliver rc=$ns_rc out: $(tr '\n' '|' < "$WORK/a-ns-deliver.out" | cut -c1-300) err: $(head -c 200 "$WORK/a-ns-deliver.err")"
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
K_ORIG="$(world_git -C "$Kw/c" symbolic-ref -q --short HEAD)"
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

# ================================ pw-retry, pw-unfinished: the pull's own writes after an ABANDON ==============
# The k pull applied on its update branch; ABANDON returns the checkout to the original branch, the writes still in the
# worktree. Copies: kr (a pull-written file edited, then the same theirs retried), ku / ku0 (a new theirs, the writes
# left uncommitted / committed); k itself is kr's twin (the retry with no edit).
K_SD=.claude/session-driver/ai-dlc-session-driver.sh
K_BR="$(world_git -C "$Kw/c" symbolic-ref -q --short HEAD)"
world_git -C "$Kw/c" checkout -q "$K_ORIG" 2>/dev/null || { echo "FIXTURE BROKEN: cannot ABANDON world k to $K_ORIG" >&2; exit 2; }
grep -qF '# driver v2 UPSTREAM' "$Kw/c/$K_SD" && [ "$K_BR" != "$K_ORIG" ] && [ -f "$Kw/c/.git/ai-dlc-pull/pull-writes" ] \
  || { echo "FIXTURE BROKEN: world k did not apply on its own branch, or left no pull-writes record" >&2; exit 2; }
for _v in kr ku ku0; do copy_world k "$_v"; done
printf '# operator edit after the abandon\n' >> "$WORK/kr/c/$K_SD"
kr_sd0="$(git hash-object "$WORK/kr/c/$K_SD")"
bash "$REC/pull.sh" apply "$WORK/kr/dist" "$KB" "$WORK/kr/c" "$KT" > "$WORK/kr.out" 2> "$WORK/kr.err" < /dev/null; kr_rc=$?
if [ "$kr_rc" = 2 ] && grep -qx 'REFUSED apply-pull-writes-moved rc=2' "$WORK/kr.out" \
   && grep -q "^NOTE pull-writes-moved $K_SD recorded [0-9a-f]\{40\} now [0-9a-f]\{40\}\$" "$WORK/kr.out" \
   && [ "$(git hash-object "$WORK/kr/c/$K_SD")" = "$kr_sd0" ] && [ "$(world_git -C "$WORK/kr/c" symbolic-ref -q --short HEAD)" = "$K_ORIG" ]; then
  ok "pw-retry: a pull-written file edited after ABANDON, the same theirs retried: REFUSED apply-pull-writes-moved naming it, the edit kept, no branch cut"
else
  bad "pw-retry: rc=$kr_rc out: $(tr '\n' '|' < "$WORK/kr.out" | cut -c1-300) err: $(head -c 300 "$WORK/kr.err")"
fi
bash "$REC/pull.sh" apply "$Kw/dist" "$KB" "$Kw/c" "$KT" > "$WORK/kr0.out" 2> "$WORK/kr0.err" < /dev/null; kr0_rc=$?
if [ "$kr0_rc" = 0 ] && grep -q '^PULL run=' "$WORK/kr0.out" && ! grep -q 'pull-writes' "$WORK/kr0.out" \
   && [ "$(world_git -C "$Kw/c" symbolic-ref -q --short HEAD)" != "$K_ORIG" ]; then
  ok "pw-retry twin: the same retry with no edit proceeds (exit 0, a branch cut, no pull-writes row)"
else
  bad "pw-retry twin: rc=$kr0_rc out: $(tr '\n' '|' < "$WORK/kr0.out" | cut -c1-300) err: $(head -c 300 "$WORK/kr0.err")"
fi
# A new theirs (VERSION moves) in ku and ku0; ku0 commits the pull's writes first.
world_git -C "$WORK/ku0/c" add -A && world_git -C "$WORK/ku0/c" commit -q -m "the k pull's writes, committed" || { echo "FIXTURE BROKEN: cannot commit ku0" >&2; exit 2; }
for _v in ku ku0; do
  printf '2.0.1\n' > "$WORK/$_v/dist/VERSION" && world_commit "$WORK/$_v/dist" "theirs moves" >/dev/null || { echo "FIXTURE BROKEN: cannot move theirs in $_v" >&2; exit 2; }
done
KU_T="$(world_git -C "$WORK/ku/dist" rev-parse HEAD)"; KU0_T="$(world_git -C "$WORK/ku0/dist" rev-parse HEAD)"
k_th="$(world_git -C "$Kw/dist" rev-parse "$KT")"
ku_snap() { sed -n 1p "$WORK/$1/c/.git/ai-dlc-pull/dirty-snapshot" 2>/dev/null | awk '{print $3}'; }
bash "$REC/pull.sh" apply "$WORK/ku/dist" "$KB" "$WORK/ku/c" "$KU_T" > "$WORK/ku.out" 2> "$WORK/ku.err" < /dev/null; ku_rc=$?
if [ "$ku_rc" = 2 ] && grep -qx 'REFUSED apply-pull-unfinished rc=2' "$WORK/ku.out" \
   && grep -q "^NOTE pull-writes-unfinished $K_SD theirs $k_th\$" "$WORK/ku.out" && [ "$(ku_snap ku)" = "$k_th" ] \
   && grep -qF '# driver v2 UPSTREAM' "$WORK/ku/c/$K_SD"; then
  ok "pw-unfinished: a new theirs while the earlier pull's writes are uncommitted: REFUSED apply-pull-unfinished naming them, the earlier snapshot kept"
else
  bad "pw-unfinished: rc=$ku_rc out: $(tr '\n' '|' < "$WORK/ku.out" | cut -c1-300) snapshot theirs '$(ku_snap ku)' err: $(head -c 300 "$WORK/ku.err")"
fi
bash "$REC/pull.sh" apply "$WORK/ku0/dist" "$KB" "$WORK/ku0/c" "$KU0_T" > "$WORK/ku0.out" 2> "$WORK/ku0.err" < /dev/null; ku0_rc=$?
if [ "$(ku_snap ku0)" = "$KU0_T" ] && [ "$KU0_T" != "$k_th" ] && ! grep -q 'pull-writes-unfinished\|apply-pull-unfinished' "$WORK/ku0.out" \
   && grep -q '^PULL run=' "$WORK/ku0.out"; then
  ok "pw-unfinished twin: the same new theirs with the earlier writes committed proceeds and writes its own snapshot (rc=$ku0_rc)"
else
  bad "pw-unfinished twin: rc=$ku0_rc snapshot theirs '$(ku_snap ku0)' want $KU0_T out: $(tr '\n' '|' < "$WORK/ku0.out" | cut -c1-300)"
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
CREP="$Cw/c/_bmad-output/ai-dlc-update/reconcile-report.md"
# report-spelling: this pull's own report, its region rendered with 8-hex spellings of the full refs the dry run is given.
[ "$CB" = "$AB" ] && [ "$CT" = "$AT0" ] && [ "${#CB}" = 40 ] && [ "${#CT}" = 40 ] && mkdir -p "${CREP%/*}" \
  && { printf '# reconcile report\n\nprose this pull wrote under its 8-hex spelling\n\n'; cat "$WORK/region-short"; printf '\ntrailing prose of this pull\n'; } > "$CREP" \
  || { echo "FIXTURE BROKEN: cannot seed world c's 8-hex report (or world c is not the seed pair)" >&2; exit 2; }
bash "$REC/pull.sh" dry-run "$Cw/dist" "$CB" "$Cw/c" "$CT" > "$WORK/c-dry.out" 2> "$WORK/c-dry.err" < /dev/null; c_drc=$?
if [ "$c_drc" = 0 ] && grep -qx 'prose this pull wrote under its 8-hex spelling' "$CREP" && grep -qx 'trailing prose of this pull' "$CREP" \
   && grep -qx "_base_ \`$CB\` → _theirs_ \`$CT\`." "$CREP" && ! grep -q '^NOTE report-restarted' "$WORK/c-dry.out" && grep -q '^PULL run=' "$WORK/c-dry.out"; then
  ok "report-spelling: a region rendered with 8-hex spellings of this pull's refs is the same pull: the dry run keeps the prose and prints no NOTE"
else
  bad "report-spelling: dry run rc=$c_drc notes: $(grep '^NOTE report' "$WORK/c-dry.out" | tr '\n' '|') prose kept=$(grep -c 'prose this pull wrote' "$CREP")"
fi
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
# F1: round 3 handed back nothing, and the driver's apply never stamps: the stamp still reads base, the in-flight marker
# stays, and the last line names the finish with the same base. That finish exits 0 and stamps theirs.
s_commit() { sed -n 's/^commit:[[:space:]]*//p' "$Sw/c/.claude/.ai-dlc-version"; }
if [ "$s3_rc" = 0 ] && [ "$(tail -1 "$WORK/s3.out")" = "NEXT pull.sh finish $Sw/dist $SB $Sw/c $ST" ] && [ "$(s_commit)" = "$SB" ] \
   && [ -e "$Sw/c/.claude/.ai-dlc-applying" ] && [ "$(git hash-object "$Sw/c/.claude/.ai-dlc-version")" = "$s_stamp0" ] \
   && ! grep -qi 'restamp\|stamp-deferred' "$WORK/s3.out"; then
  ok "F1: an apply that hands back nothing leaves the stamp at base and the marker in place, and its last line is NEXT pull.sh finish with the same base"
else
  bad "F1: apply rc=$s3_rc stamp commit '$(s_commit)' (base $SB) stamp unchanged=$([ "$(git hash-object "$Sw/c/.claude/.ai-dlc-version")" = "$s_stamp0" ] && echo yes || echo no) marker=$([ -e "$Sw/c/.claude/.ai-dlc-applying" ] && echo kept || echo gone) stamp rows: $(grep -i 'restamp\|stamp-deferred' "$WORK/s3.out" | tr '\n' '|' | cut -c1-200) last line '$(tail -1 "$WORK/s3.out")'"
fi
bash "$REC/pull.sh" finish "$Sw/dist" "$SB" "$Sw/c" "$ST" > "$WORK/s-fin.out" 2> "$WORK/s-fin.err" < /dev/null; s_frc=$?
if [ "$s_frc" = 0 ] && [ "$(world_git -C "$Sw/dist" rev-parse -q --verify "$(s_commit)^{commit}")" = "$ST" ] && grep -q '^version:[[:space:]]*2\.0\.0$' "$Sw/c/.claude/.ai-dlc-version" \
   && [ ! -e "$Sw/c/.claude/.ai-dlc-applying" ] && ! grep -q 'finish-base-unverified' "$WORK/s-fin.out"; then
  ok "F1: pull.sh finish with the ORIGINAL base exits 0, stamps theirs and clears the marker"
else
  bad "F1: finish rc=$s_frc stamp commit '$(s_commit)' (theirs $ST) out: $(tr '\n' '|' < "$WORK/s-fin.out" | cut -c1-300) err: $(head -c 300 "$WORK/s-fin.err")"
fi
printf '{"row":1}\n' > "$Sw/c/_bmad-output/spawn-ledger.jsonl"
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
# st-noschema: this world installs no schema, so the state filter is off: one NOTE, and a state file written after the snapshot is committed as before.
if [ "$s_drc" = 0 ] && [ "$(grep -c '^NOTE deliver-state-unfiltered ' "$WORK/s-deliver.out")" = 1 ] && grep -qx 'A	_bmad-output/spawn-ledger.jsonl' <<<"$s_ns"; then
  ok "st-noschema: no schema in the consumer: NOTE deliver-state-unfiltered once, and the pipeline-state file is committed"
else
  bad "st-noschema: deliver rc=$s_drc out: $(tr '\n' '|' < "$WORK/s-deliver.out" | cut -c1-300) commit: $(tr '\n\t' '| ' <<<"$s_ns" | cut -c1-300)"
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
# nr: the PR body relays a derivation-unassessable NOTE row whole (over 400 bytes, a pipe inside) past a truncated decisions table, lists a high-volume non-whole kind once, and reads only this pull's runs.
NRGD="$S4/c/.git/ai-dlc-pull"; NRRUN=run-29990101T000000Z-1; NRSTALE=run-20000101T000000Z-1
mkdir -p "$NRGD/$NRRUN" "$NRGD/$NRSTALE"
nr_snap_had=0; if [ -f "$NRGD/dirty-snapshot" ]; then nr_snap_had=1; cp "$NRGD/dirty-snapshot" "$WORK/nr-snapshot.bak"; fi
nr_long="$(awk 'BEGIN { for (i = 0; i < 60; i++) printf "derive%02d ", i }')"
nr_row="$(printf 'NOTE\tderivation-unassessable\tdocs/nr.md\t%s | tail-after-pipe' "$nr_long")"
{ printf '%s\n' "$nr_row"; awk 'BEGIN { pad = sprintf("%0380d", 0); for (i = 0; i < 3000; i++) printf "NOTE\tderivation-info-out-of-scope\tdocs/nr-info-%04d.md\t%s\n", i, pad
  for (i = 0; i < 400; i++) printf "NOTE\tzz-nr-kind-%04d\tdocs/nr-kind.md\tinfo\n", i }'; } > "$NRGD/$NRRUN/apply.out"
printf 'NOTE\tstale-kind-zz\tdocs/stale.md\tfrom an earlier pull\n' > "$NRGD/$NRSTALE/apply.out"
nr_fin="$(printf 'NOTE\tfinish-unverified\tdocs/nr-fin.md\tconfirm by hand | %s' "$nr_long")"
printf '%s\n' "$nr_fin" > "$NRGD/$NRRUN/finish.out"
nr_ev="$(awk 'BEGIN { for (i = 0; i < 30; i++) printf "evidence-text "; }')"
awk -v ev="$nr_ev" 'BEGIN { for (i = 0; i < 120; i++) printf "refile\tdocs/nr-%03d.md\t-\tmodel\tkept\t%s\n", i, ev }' >> "$S4/c/_bmad-output/ai-dlc-update/pull-decisions.tsv"
rm -f "$NRGD/dirty-snapshot"
bash "$REC/pull.sh" pr-body "$S4/c" > "$WORK/nr0.out" 2> "$WORK/nr0.err" < /dev/null; nr0_rc=$?
printf 'ai-dlc-dirty-snapshot 2 %s %s\n' "$(printf '%064d' 0)" "$NRRUN" > "$NRGD/dirty-snapshot"
bash "$REC/pull.sh" pr-body "$S4/c" > "$WORK/nr.out" 2> "$WORK/nr.err" < /dev/null; nr_rc=$?
nr_want="- $(printf '%s' "$nr_row" | tr '\t' ' ')"
nr_fwant="- $(printf '%s' "$nr_fin" | tr '\t' ' ')"
if [ "$nr_rc" = 0 ] && [ "${#nr_long}" -gt 400 ] && grep -qxF -- "$nr_want" "$WORK/nr.out" && grep -qx '### NOTE rows relayed whole' "$WORK/nr.out" \
   && grep -qxF -- "$nr_fwant" "$WORK/nr.out" && grep -q 'more decision rows omitted' "$WORK/nr.out"; then
  ok "nr: a derivation-unassessable NOTE row over 400 bytes with a pipe, and a finish-unverified row from the run's finish.out, reach the PR body whole while the over-budget decisions table omits rows"
else
  bad "nr: pr-body rc=$nr_rc row-whole=$(grep -cxF -- "$nr_want" "$WORK/nr.out") section=$(grep -c '^### NOTE rows relayed whole' "$WORK/nr.out") omitted=$(grep -c 'more decision rows omitted' "$WORK/nr.out") err: $(head -c 200 "$WORK/nr.err")"
fi
if [ "$nr_rc" = 0 ] && [ "$(grep -c '^- `derivation-info-\*`: 3000 row(s) in 1 scopes: derivation-info-out-of-scope (3000)$' "$WORK/nr.out")" = 1 ] \
   && [ "$(grep -c 'derivation-info-out-of-scope' "$WORK/nr.out")" = 1 ] && [ "$(wc -c < "$WORK/nr.out" | tr -d ' ')" -lt 60000 ] \
   && grep -qE '^… [0-9]+ more NOTE kinds \([0-9]+ rows\)' "$WORK/nr.out"; then
  ok "nr-vol: 3000 rows (over 1 MB) of a non-whole NOTE kind are one per-kind line, 400 more distinct kinds end in a more-kinds line, pr-body exits 0 and the body stays under 60000 bytes"
else
  bad "nr-vol: rc=$nr_rc kind lines=$(grep -c 'derivation-info-out-of-scope' "$WORK/nr.out") body bytes=$(wc -c < "$WORK/nr.out" | tr -d ' ') err: $(head -c 200 "$WORK/nr.err")"
fi
if [ "$nr0_rc" = 0 ] && grep -q 'stale-kind-zz' "$WORK/nr0.out" && ! grep -q 'stale-kind-zz' "$WORK/nr.out"; then
  ok "nr-run: with no snapshot an earlier run's NOTE kind is listed; with the snapshot naming this pull's first run it is absent"
else
  bad "nr-run: no-snapshot rc=$nr0_rc stale listed=$(grep -c 'stale-kind-zz' "$WORK/nr0.out") with snapshot stale listed=$(grep -c 'stale-kind-zz' "$WORK/nr.out")"
fi
# nr-fold: 30 derivation-info-<scope> kinds of 8 rows each, long paths, then report-unverified and reapproval-narrowed (sorted after them):
# the scopes are one line, so both later kinds keep their own lines inside the byte budget.
awk 'BEGIN { for (s = 1; s <= 30; s++) for (r = 0; r < 8; r++) printf "NOTE\tderivation-info-s%d\tdocs/nr-fold/a-long-directory-name-for-scope-%02d/row-%02d-of-the-fold-arm.md\tinfo\n", s, s, r
  printf "NOTE\treport-unverified\tdocs/nr-fold-report.md\tconfirm by hand\n"; printf "NOTE\treapproval-narrowed\tdocs/nr-fold-reapproval.md\tnarrowed\n" }' > "$NRGD/$NRRUN/apply.out"
rm -f "$NRGD/$NRRUN/finish.out"
bash "$REC/pull.sh" pr-body "$S4/c" > "$WORK/nr-fold.out" 2> "$WORK/nr-fold.err" < /dev/null; nrf_rc=$?
if [ "$nrf_rc" = 0 ] && grep -qx '^- `report-unverified`: 1 row(s); paths: docs/nr-fold-report.md' "$WORK/nr-fold.out" \
   && grep -qx '^- `reapproval-narrowed`: 1 row(s); paths: docs/nr-fold-reapproval.md' "$WORK/nr-fold.out" \
   && grep -q '^- `derivation-info-\*`: 240 row(s) in 30 scopes: derivation-info-s1 (8), ' "$WORK/nr-fold.out" && ! grep -q 'more NOTE kinds' "$WORK/nr-fold.out"; then
  ok "nr-fold: 30 derivation-info scopes of 8 rows are one line (derivation-info-s1 first), and report-unverified and reapproval-narrowed both reach the PR body"
else
  bad "nr-fold: rc=$nrf_rc kinds: $(grep '^- `\|more NOTE kinds' "$WORK/nr-fold.out" | cut -c1-120 | tr '\n' '|' | cut -c1-600) err: $(head -c 200 "$WORK/nr-fold.err")"
fi
rm -f "$NRGD/$NRRUN/apply.out" "$NRGD/$NRRUN/finish.out" "$NRGD/$NRSTALE/apply.out" "$NRGD/dirty-snapshot"
[ "$nr_snap_had" = 0 ] || cp "$WORK/nr-snapshot.bak" "$NRGD/dirty-snapshot"
# nr-bind: the kinds pull.sh relays whole (PL_NOTE_FULL) and the kinds it counts (PL_NOTE_COUNTED) partition every static `say NOTE <kind>` emit in apply.sh and every pl_dnote kind in pull.sh (derivation-info- is a prefix entry); each FULL kind has an emit site; the kinds step 7 names are named in SKILL.md; a seeded unclassified emit is reported.
nr_full="$(sed -n 's/^PL_NOTE_FULL="\(.*\)"$/\1/p' "$REC/pull.sh")"
nr_cnt="$(sed -n 's/^PL_NOTE_COUNTED="\(.*\)"$/\1/p' "$REC/pull.sh")"
nr_miss() { local k m=""; for k in $1; do grep -qE -- "say NOTE $k( |\")" "$REC/apply.sh" || m="$m $k"; done; printf '%s' "$m"; }
nr_emits() { { grep -v '^[[:space:]]*#' "$1" | sed -n 's/.*say NOTE "\{0,1\}\([a-z][a-z0-9-]*\).*/\1/p'; grep -v '^[[:space:]]*#' "$2" | sed -n 's/.*pl_dnote "NOTE \([a-z][a-z0-9-]*\).*/\1/p'; } | sort -u; }
nr_unclass() { local k c inf inc out=""; for k in $(nr_emits "$1" "$2"); do inf=0; inc=0
  for c in $nr_full; do [ "$c" = "$k" ] && inf=1; done
  for c in $nr_cnt; do case "$c" in *-) case "$k" in "$c"*) inc=1 ;; esac ;; *) [ "$c" = "$k" ] && inc=1 ;; esac; done
  [ $((inf + inc)) = 1 ] || out="$out $k"; done; printf '%s' "$out"; }
cp "$REC/apply.sh" "$WORK/nr-apply-seed.sh"; printf '  say NOTE zz-unclassified-kind-zz "x" "y"\n' >> "$WORK/nr-apply-seed.sh"
nr_n="$(printf '%s\n' $nr_full | grep -c .)" || nr_n=0
nr_ne="$(nr_emits "$REC/apply.sh" "$REC/pull.sh" | grep -c .)" || nr_ne=0
nr_real="$(nr_miss "$nr_full")"; nr_seed="$(nr_miss "$nr_full zz-unknown-kind-zz")"
nr_un="$(nr_unclass "$REC/apply.sh" "$REC/pull.sh")"; nr_unseed="$(nr_unclass "$WORK/nr-apply-seed.sh" "$REC/pull.sh")"
nr_sk=""; for k in derivation-unassessable reconcile-log-name override-readopt-subsumed extension-retire extension-contradicts-core; do case " $nr_full " in *" $k "*) grep -qF -- "$k" "$SKILL_SRC" || nr_sk="$nr_sk $k" ;; *) nr_sk="$nr_sk $k(not-full)" ;; esac; done
if [ "$nr_n" -ge 11 ] && [ "$nr_ne" -ge 20 ] && [ -z "$nr_real" ] && [ "$nr_seed" = " zz-unknown-kind-zz" ] && [ -z "$nr_un" ] && [ "$nr_unseed" = " zz-unclassified-kind-zz" ] && [ -z "$nr_sk" ]; then
  ok "nr-bind: $nr_ne emitted NOTE kinds each fall in exactly one of PL_NOTE_FULL ($nr_n) and PL_NOTE_COUNTED, every FULL kind has an emit site, the step-7 kinds are named in SKILL.md, and a seeded unclassified emit is reported"
else
  bad "nr-bind: full=$nr_n emits=$nr_ne no-emit-site:[$nr_real] seeded-unknown:[$nr_seed] unclassified:[$nr_un] seeded-unclassified:[$nr_unseed] step7-not-in-SKILL:[$nr_sk]"
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
  s3_st0="$(git hash-object "$S3/c/.claude/.ai-dlc-version")"
  bash "$REC/pull.sh" apply --carried-machinery-slice "$S3/dist" "$SB" "$S3/c" "$ST" > "$WORK/s3a.out" 2> "$WORK/s3a.err" < /dev/null; s3a_rc=$?
  if [ "$s3a_rc" = 0 ] && grep -qF '# driver v2 UPSTREAM' "$S3/c/$SENT_REL" && [ -e "$S3GD/ai-dlc-approved-region.pull" ]; then
    ok "c3: a pre-driver record (no driver sidecar) carrying a since-settled ASK row is replaced, and pull.sh apply exits 0"
  else
    bad "c3: pull.sh apply over a pre-driver record rc=$s3a_rc out: $(tr '\n' '|' < "$WORK/s3a.out" | cut -c1-400)"
  fi
else
  bad "c3: could not seed a pre-driver record (verify rc=$s3v_rc, header '$(sed -n 1p "$S3GD/ai-dlc-approved-region" 2>/dev/null)')"
fi
# F1-cms: the same deferral under --carried-machinery-slice: after apply neither pair moved (the stamp is byte-identical, no
# skill pair) and the NEXT line carries the flag; finish with the flag and the original base writes both pairs.
s3_stamp() { sed -n "s/^$1:[[:space:]]*//p" "$S3/c/.claude/.ai-dlc-version"; }
if [ "$s3a_rc" = 0 ] && [ "$(tail -1 "$WORK/s3a.out")" = "NEXT pull.sh finish --carried-machinery-slice $S3/dist $SB $S3/c $ST" ] \
   && [ "$(git hash-object "$S3/c/.claude/.ai-dlc-version")" = "${s3_st0:-none}" ] && [ -z "$(s3_stamp skill_commit)" ] && [ -e "$S3/c/.claude/.ai-dlc-applying" ]; then
  ok "F1-cms: under --carried-machinery-slice the apply writes neither pair, keeps the marker, and its NEXT line carries the flag"
else
  bad "F1-cms: apply rc=$s3a_rc last line '$(tail -1 "$WORK/s3a.out")' stamp: $(tr '\n' '|' < "$S3/c/.claude/.ai-dlc-version")"
fi
# F2: a copy of that state with the pull-written driver file reverted to its base content before finish.
copy_world s3 s3f2
printf '#!/usr/bin/env bash\n# driver v1\n' > "$WORK/s3f2/c/$SENT_REL"
s3f2_st0="$(git hash-object "$WORK/s3f2/c/.claude/.ai-dlc-version")"
# adv: the F1-cms consumer's agent-definition check reports drift (a renderer whose --check exits 1), so the finish
# prints WORKLIST agent-definitions; it runs after the stamp and is reported advisory, never withheld.
printf '#!/usr/bin/env bash\necho "role dev: .claude/agents/dev.md is stale"\nexit 1\n' > "$S3/c/scripts/ai-dlc/render-agent-definitions.sh"
bash "$REC/pull.sh" finish --carried-machinery-slice "$S3/dist" "$SB" "$S3/c" "$ST" > "$WORK/s3f.out" 2> "$WORK/s3f.err" < /dev/null; s3f_rc=$?
s3_full() { world_git -C "$S3/dist" rev-parse -q --verify "$(s3_stamp "$1")^{commit}"; }
if [ "$s3f_rc" = 0 ] && [ "$(s3_full commit)" = "$ST" ] && [ "$(s3_full skill_commit)" = "$ST" ] \
   && [ "$(s3_stamp version)" = 2.0.0 ] && [ "$(s3_stamp skill_version)" = 2.0.0 ] && [ ! -e "$S3/c/.claude/.ai-dlc-applying" ]; then
  ok "F1-cms: pull.sh finish --carried-machinery-slice with the original base exits 0 and writes both pairs to theirs"
else
  bad "F1-cms: finish rc=$s3f_rc stamp: $(tr '\n' '|' < "$S3/c/.claude/.ai-dlc-version") out: $(tr '\n' '|' < "$WORK/s3f.out" | cut -c1-300)"
fi
if [ "$s3f_rc" = 0 ] && grep -qx 'DECIDE agent-definitions .claude/agents/ advisory' "$WORK/s3f.out" && ! grep -q ' withheld$' "$WORK/s3f.out" \
   && [ "$(s3_full commit)" = "$ST" ] && [ ! -e "$S3/c/.claude/.ai-dlc-applying" ]; then
  ok "adv: a finish whose agent-definition check fires prints DECIDE agent-definitions advisory, exits 0, stamps theirs and removes the marker"
else
  bad "adv: finish rc=$s3f_rc stamp commit '$(s3_stamp commit)' marker=$([ -e "$S3/c/.claude/.ai-dlc-applying" ] && echo kept || echo gone) out: $(tr '\n' '|' < "$WORK/s3f.out" | cut -c1-300)"
fi
bash "$REC/pull.sh" finish "$WORK/s3f2/dist" "$SB" "$WORK/s3f2/c" "$ST" > "$WORK/s3f2.out" 2> "$WORK/s3f2.err" < /dev/null; s3f2_rc=$?
if [ "$s3f2_rc" = 3 ] && grep -q "^DECIDE finish-unapplied $SENT_REL withheld\$" "$WORK/s3f2.out" && ! grep -q 'finish-base-unverified' "$WORK/s3f2.out" \
   && [ "$(git hash-object "$WORK/s3f2/c/.claude/.ai-dlc-version")" = "$s3f2_st0" ] && [ -e "$WORK/s3f2/c/.claude/.ai-dlc-applying" ]; then
  ok "F2: a pull-written file reverted before finish: DECIDE finish-unapplied withheld (never finish-base-unverified), exit 3, the stamp and marker kept"
else
  bad "F2: finish rc=$s3f2_rc out: $(tr '\n' '|' < "$WORK/s3f2.out" | cut -c1-400) err: $(head -c 300 "$WORK/s3f2.err")"
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

# ===== BL-1173: the deliver-time BMAD manifest probe (pl_bmad_probe) =====
# bm_world <world> <record: old|none|same> <rc>: a delivery world (copy of seed-main, no apply, so no snapshot) on an
# update branch whose consumer carries _bmad/_config/manifest.yaml (v1), a stub validator that appends to a sentinel
# and exits with the rc in a file, and the record per <record>; the manifest is then edited to v2 (or kept at v1
# for `same`). The stub, manifest and record are committed first, so only the v2 edit and a notes file are the pull's.
BM_REC=_bmad-output/ai-dlc-update/bmad-manifest-digest
bm_world() {
  copy_world seed-main "$1" || return 1
  local c="$WORK/$1/c"
  world_git -C "$c" checkout -q -b ai-dlc-update/2.0.0-reconcile-20260102T000000Z || return 1
  mkdir -p "$c/_bmad/_config" "$c/_bmad-output/ai-dlc-update" "$c/notes" || return 1
  printf 'manifest: v1\n' > "$c/_bmad/_config/manifest.yaml"
  BM_V1="$(world_git -C "$c" hash-object --no-filters -- _bmad/_config/manifest.yaml)"
  case "$2" in
    old|same) printf 'ai-dlc-bmad-manifest 1 %s\n' "$BM_V1" > "$c/$BM_REC" ;;
    none) : ;;
  esac
  printf '%s\n' '#!/usr/bin/env bash' "echo run >> '$WORK/$1.sent'" 'echo "FAIL: stub invocation"' "exit \$(cat '$WORK/$1.rc')" \
    > "$c/scripts/ai-dlc/validate-bmad-invocations.sh" || return 1
  printf '%s\n' "$3" > "$WORK/$1.rc"
  world_commit "$c" "bmad probe world" || return 1
  [ "$2" = same ] || printf 'manifest: v2\n' > "$c/_bmad/_config/manifest.yaml"
  printf 'operator untracked\n' > "$c/notes/bm-untracked.txt"
  BM_V2="$(world_git -C "$c" hash-object --no-filters -- _bmad/_config/manifest.yaml)"
  deliver_env "$1"
}
bm_sent() { if [ -f "$WORK/$1.sent" ]; then wc -l < "$WORK/$1.sent" | tr -d ' '; else echo 0; fi; }
bm_head_rec() { world_git -C "$WORK/$1/c" show "HEAD:$BM_REC" 2>/dev/null; }
bm_remote() { world_git --git-dir="$WORK/$1-origin.git" rev-parse -q --verify "refs/heads/$2" 2>/dev/null; }
# M: manifest changed vs the record, validator exit 1 refuses; the same world with exit 0 delivers.
bm_world bm old 1 || { echo "FIXTURE BROKEN: bm_world bm" >&2; exit 2; }
BMB="$(cat "$WORK/bm/.B")"; BMT="$(cat "$WORK/bm/.T")"; BM_BR="$(world_git -C "$WORK/bm/c" symbolic-ref -q --short HEAD)"
BM_H0="$(world_git -C "$WORK/bm/c" rev-parse HEAD)"; BM_BLOB="$BM_V2"; BM_OLD="$BM_V1"
deliver_run bm "$WORK/bm/dist" "$BMB" "$WORK/bm/c" "$BMT"; bm1_rc=$?
if [ "$bm1_rc" = 2 ] && grep -qx 'REFUSED deliver-bmad-invocations rc=2' "$WORK/bm-deliver.out" \
   && grep -q 'stub invocation' "$WORK/bm-deliver.err" && grep -q 'npx bmad-method install' "$WORK/bm-deliver.err" \
   && [ "$(bm_sent bm)" = 1 ] && [ "$(world_git -C "$WORK/bm/c" rev-parse HEAD)" = "$BM_H0" ] \
   && [ -z "$(bm_remote bm "$BM_BR")" ] && ! grep -q '^DECIDE' "$WORK/bm-deliver.out" \
   && [ "$(bm_head_rec bm)" = "ai-dlc-bmad-manifest 1 $BM_OLD" ] && [ "$BM_BLOB" != "$BM_OLD" ]; then
  ok "bmad probe: a changed manifest and a failing validator refuse (REFUSED deliver-bmad-invocations), HEAD unchanged, the branch absent on origin, no DECIDE row, the record kept at the old blob"
else
  bad "bmad probe rc1: rc=$bm1_rc sent=$(bm_sent bm) out: $(tr '\n' '|' < "$WORK/bm-deliver.out" | cut -c1-300) err: $(head -c 200 "$WORK/bm-deliver.err")"
fi
printf '0\n' > "$WORK/bm.rc"
deliver_run bm "$WORK/bm/dist" "$BMB" "$WORK/bm/c" "$BMT"; bm2_rc=$?
if [ "$bm2_rc" = 0 ] && grep -qx 'NOTE bmad-probe pass' "$WORK/bm-deliver.out" && grep -qx 'DECIDE pr https://example.invalid/pr/1 opened' "$WORK/bm-deliver.out" \
   && [ "$(bm_head_rec bm)" = "ai-dlc-bmad-manifest 1 $BM_BLOB" ] && [ "$(bm_sent bm)" = 2 ] \
   && [ "$(bm_remote bm "$BM_BR")" = "$(world_git -C "$WORK/bm/c" rev-parse HEAD)" ]; then
  ok "bmad probe: the same world with validator exit 0 passes, delivers, and the COMMITTED record holds the current manifest blob"
else
  bad "bmad probe rc0 rerun: rc=$bm2_rc record='$(bm_head_rec bm)' want $BM_BLOB out: $(tr '\n' '|' < "$WORK/bm-deliver.out" | cut -c1-300)"
fi
# U: the record equals the manifest: the validator never runs (bm's sentinel, written by its exit-1 run, is the control).
bm_world bmu same 1 || { echo "FIXTURE BROKEN: bm_world bmu" >&2; exit 2; }
deliver_run bmu "$WORK/bmu/dist" "$(cat "$WORK/bmu/.B")" "$WORK/bmu/c" "$(cat "$WORK/bmu/.T")"; bmu_rc=$?
if [ "$bmu_rc" = 0 ] && grep -qx 'NOTE bmad-probe unchanged' "$WORK/bmu-deliver.out" && [ "$(bm_sent bmu)" = 0 ] && [ "$(bm_sent bm)" -ge 1 ] \
   && [ "$(bm_head_rec bmu)" = "ai-dlc-bmad-manifest 1 $BM_V1" ]; then
  ok "bmad probe: record equal to the manifest: NOTE bmad-probe unchanged, the validator never ran (the changed-manifest world's did), delivered"
else
  bad "bmad probe unchanged: rc=$bmu_rc sent=$(bm_sent bmu) control sent=$(bm_sent bm) out: $(tr '\n' '|' < "$WORK/bmu-deliver.out" | cut -c1-300)"
fi
# N: no record, validator exit 1: a first pull never blocks; the record is written and committed.
bm_world bmn none 1 || { echo "FIXTURE BROKEN: bm_world bmn" >&2; exit 2; }
deliver_run bmn "$WORK/bmn/dist" "$(cat "$WORK/bmn/.B")" "$WORK/bmn/c" "$(cat "$WORK/bmn/.T")"; bmn_rc=$?
if [ "$bmn_rc" = 0 ] && grep -qx 'NOTE bmad-probe no-baseline rc=1' "$WORK/bmn-deliver.out" && [ "$(bm_sent bmn)" = 1 ] \
   && [ "$(bm_head_rec bmn)" = "ai-dlc-bmad-manifest 1 $BM_V2" ] \
   && grep -q 'FAIL: stub invocation' "$WORK/bmn-deliver.err" && grep -q 'npx bmad-method install' "$WORK/bmn-deliver.err"; then
  ok "bmad probe: no record and validator exit 1: NOTE bmad-probe no-baseline rc=1, delivers, the committed record holds the manifest blob"
else
  bad "bmad probe no-baseline: rc=$bmn_rc record='$(bm_head_rec bmn)' out: $(tr '\n' '|' < "$WORK/bmn-deliver.out" | cut -c1-300) err: $(head -c 200 "$WORK/bmn-deliver.err")"
fi
# S: changed manifest, validator exit 2: reported SKIP, delivers, the record stays at the old blob.
bm_world bms old 2 || { echo "FIXTURE BROKEN: bm_world bms" >&2; exit 2; }
deliver_run bms "$WORK/bms/dist" "$(cat "$WORK/bms/.B")" "$WORK/bms/c" "$(cat "$WORK/bms/.T")"; bms_rc=$?
if [ "$bms_rc" = 0 ] && grep -q '^NOTE bmad-probe SKIP rc=2' "$WORK/bms-deliver.out" && [ "$(bm_sent bms)" = 1 ] \
   && [ "$(bm_head_rec bms)" = "ai-dlc-bmad-manifest 1 $BM_V1" ] && [ "$BM_V2" != "$BM_V1" ]; then
  ok "bmad probe: validator exit 2: NOTE bmad-probe SKIP, delivers, no record written (the committed record is still the old blob)"
else
  bad "bmad probe rc2: rc=$bms_rc record='$(bm_head_rec bms)' out: $(tr '\n' '|' < "$WORK/bms-deliver.out" | cut -c1-300)"
fi
# bmd: the record is in the always-stage set. A world WITH a snapshot that lists the record as dirty (index blob equal to HEAD's) still
# commits the record the probe rewrote; without the always-stage row the snapshot's unchanged-index rule leaves it out of the commit.
bm_world bmd old 0 || { echo "FIXTURE BROKEN: bm_world bmd" >&2; exit 2; }
bmd_c="$WORK/bmd/c"; bmd_gd="$bmd_c/.git"; bmd_th="$(world_git -C "$WORK/bmd/dist" rev-parse -q --verify "$(cat "$WORK/bmd/.T")^{commit}")"
bmd_ix="$(world_git -C "$bmd_c" rev-parse "HEAD:$BM_REC")"
bmd_wt="$(printf 'operator edit\n' | world_git -C "$bmd_c" hash-object -w --stdin)"
mkdir -p "$bmd_gd/ai-dlc-pull" && printf 'ai-dlc-dirty-snapshot 2 %s run-20260102T000000Z-1\nM \t%s\t%s\t%s\t-\n' "$bmd_th" "$bmd_ix" "$bmd_wt" "$BM_REC" > "$bmd_gd/ai-dlc-pull/dirty-snapshot" \
  || { echo "FIXTURE BROKEN: cannot write the bmd snapshot" >&2; exit 2; }
deliver_run bmd "$WORK/bmd/dist" "$(cat "$WORK/bmd/.B")" "$bmd_c" "$(cat "$WORK/bmd/.T")"; bmd_rc=$?
if [ "$bmd_rc" = 0 ] && grep -qx 'NOTE bmad-probe pass' "$WORK/bmd-deliver.out" && [ -n "$bmd_th" ] && [ "$BM_V2" != "$BM_V1" ] \
   && [ "$(bm_head_rec bmd)" = "ai-dlc-bmad-manifest 1 $BM_V2" ]; then
  ok "bmad probe: a record dirty at the snapshot is still committed with the digest the probe wrote (it is an always-stage path)"
else
  bad "bmad probe always-stage: rc=$bmd_rc record='$(bm_head_rec bmd)' want $BM_V2 out: $(tr '\n' '|' < "$WORK/bmd-deliver.out" | cut -c1-300) err: $(head -c 200 "$WORK/bmd-deliver.err")"
fi
# ===== end BL-1173 arms =====

# ================================ hr: a HARD remedy written before a theirs change is delivered (BL-1249) ===========
# World hr, one T1 -> T2 chain. Three HARD rows at T1: two SKILL.md overrides with no base_sha
# (HARD-OVERRIDE-BASE-UNRESOLVABLE; Rule 9's carries an operator edit made before the pull) and a committed in-place
# edit of steps/alpha.md (HARD-UNREGISTERED-CORE-DRIFT). In the window after T1's exit 3: base_sha written into both
# overrides by hand, `pull.sh register-drift` for alpha.md, the model's T1 disposition row naming Rule 9's override, and
# an untracked control file. Upstream then moves (T2 changes alpha.md's Alpha section, which apply.sh writes), and the
# T2 apply, finish and deliver run.
HR="$WORK/hr"; HRD="$HR/dist"; HRC="$HR/c"; HR_OVR=.claude/skills/ai-dlc/overrides; HR_ALPHA=.claude/skills/ai-dlc/steps/alpha.md
hr_skill='# Rules\n\nSTATUS-OK is a status.\n\n## Rule 8 -- Depth\n\nLine A base.\n\n## Rule 9 -- Tail\n\nTail X base.\n'
mkdir -p "$HRD/core/skills/ai-dlc/steps" "$HRD/core/session-driver" && world_git init -q "$HRD" \
  && printf '1.0.0\n' > "$HRD/VERSION" && printf "$hr_skill" > "$HRD/core/skills/ai-dlc/SKILL.md" \
  && printf '# alpha step\n\n## Alpha\n\nDo alpha.\n\n## Beta\n\nDo beta.\n' > "$HRD/core/skills/ai-dlc/steps/alpha.md" \
  && printf '#!/usr/bin/env bash\n# driver v1\n' > "$HRD/core/session-driver/ai-dlc-session-driver.sh" \
  && HRB="$(prd_dist_commit "$HRD" base)" && printf '2.0.0\n' > "$HRD/VERSION" \
  && printf '#!/usr/bin/env bash\n# driver v2 UPSTREAM\n' > "$HRD/core/session-driver/ai-dlc-session-driver.sh" \
  && HRT1="$(prd_dist_commit "$HRD" t1)" \
  && mkdir -p "$HRC/.claude/skills/ai-dlc/steps" "$HRC/$HR_OVR" "$HRC/.claude/session-driver" "$HRC/.claude/schemas" \
  && cp "$SCHEMA_SRC" "$HRC/.claude/schemas/" && printf "$hr_skill" > "$HRC/.claude/skills/ai-dlc/SKILL.md" \
  && printf '# alpha step\n\n## Alpha\n\nDo alpha.\n\n## Beta\n\nDo beta, CONSUMER WAY.\n' > "$HRC/$HR_ALPHA" \
  && printf '#!/usr/bin/env bash\n# driver v1\n' > "$HRC/.claude/session-driver/ai-dlc-session-driver.sh" \
  && printf 'version: 1.0.0\ncommit: %s\n' "$HRB" > "$HRC/.claude/.ai-dlc-version" \
  && printf -- '---\nshadows: SKILL.md#Rule 8\nreason: fixture\n---\n\n## Rule 8 -- Depth\n\nLine A OURS.\n' > "$HRC/$HR_OVR/SKILL__Rule-8.md" \
  && printf -- '---\nshadows: SKILL.md#Rule 9\nreason: fixture\n---\n\n## Rule 9 -- Tail\n\nTail X OURS.\n' > "$HRC/$HR_OVR/SKILL__Rule-9.md" \
  && prd_consumer_commit "$HRC" >/dev/null && deliver_env hr \
  && printf '\nOPERATOR NOTE before the pull.\n' >> "$HRC/$HR_OVR/SKILL__Rule-9.md" \
  || { echo "FIXTURE BROKEN: cannot build world hr" >&2; exit 2; }
# hr_base_sha <file>: the remedy, base_sha written as the frontmatter's second line.
hr_base_sha() { awk -v b="$HRB" 'NR == 2 { print "base_sha: " b } { print }' "$1" > "$1.new" && mv -f "$1.new" "$1"; }
bash "$REC/pull.sh" apply "$HRD" "$HRB" "$HRC" "$HRT1" > "$WORK/hr-t1.out" 2> "$WORK/hr-t1.err" < /dev/null; hr1_rc=$?
hr_r9_head="$(world_git -C "$HRC" show "HEAD:$HR_OVR/SKILL__Rule-9.md" | awk -v b="$HRB" 'NR == 2 { print "base_sha: " b } { print }')"
hr_base_sha "$HRC/$HR_OVR/SKILL__Rule-8.md" && hr_base_sha "$HRC/$HR_OVR/SKILL__Rule-9.md" \
  || { echo "FIXTURE BROKEN: cannot write the base_sha remedies" >&2; exit 2; }
bash "$REC/pull.sh" register-drift "$HRD" "$HRB" "$HRC" "$HRT1" skills/ai-dlc/steps/alpha.md > "$WORK/hr-rd.out" 2> "$WORK/hr-rd.err" < /dev/null; hrr_rc=$?
HR_RD="$(sed -n 's/^REGISTERED  *//p' "$WORK/hr-rd.out")"
HR_DEC="$HRC/_bmad-output/ai-dlc-update/pull-decisions.tsv"
mkdir -p "${HR_DEC%/*}" && { [ -f "$HR_DEC" ] || printf 'kind\tpath\tdigest\tdecider\tverdict\tevidence\n' > "$HR_DEC"; } \
  && printf 'override-base\t%s\t-\tmodel\tremedied\thr T1 disposition row\n' "$HR_OVR/SKILL__Rule-9.md" >> "$HR_DEC" \
  && printf 'operator scratch\n' > "$HRC/control.txt" \
  && printf '# alpha step\n\n## Alpha\n\nDo alpha, T2 UPSTREAM.\n\n## Beta\n\nDo beta.\n' > "$HRD/core/skills/ai-dlc/steps/alpha.md" \
  && printf '3.0.0\n' > "$HRD/VERSION" && HRT2="$(prd_dist_commit "$HRD" t2)" \
  || { echo "FIXTURE BROKEN: cannot write the hr window or move upstream" >&2; exit 2; }
bash "$REC/pull.sh" apply "$HRD" "$HRB" "$HRC" "$HRT2" > "$WORK/hr-t2.out" 2> "$WORK/hr-t2.err" < /dev/null; hr2_rc=$?
bash "$REC/pull.sh" finish "$HRD" "$HRB" "$HRC" "$HRT2" > "$WORK/hr-fin.out" 2> "$WORK/hr-fin.err" < /dev/null; hrf_rc=$?
deliver_run hr "$HRD" "$HRB" "$HRC" "$HRT2"; hrd_rc=$?
hr_in_commit() { world_git -C "$HRC" show --name-only --format= HEAD | grep -cxF -- "$1"; }
hr_st() { world_git -C "$HRC" status --porcelain=v1 -- "$1"; }
if [ "$hr1_rc" = 3 ] && grep -qxF "HARD HARD-OVERRIDE-BASE-UNRESOLVABLE $HR_OVR/SKILL__Rule-8.md" "$WORK/hr-t1.out" \
   && grep -qxF "HARD HARD-OVERRIDE-BASE-UNRESOLVABLE $HR_OVR/SKILL__Rule-9.md" "$WORK/hr-t1.out" \
   && grep -qxF 'HARD HARD-UNREGISTERED-CORE-DRIFT skills/ai-dlc/steps/alpha.md' "$WORK/hr-t1.out" \
   && [ "$hrr_rc" = 0 ] && [ -n "$HR_RD" ] && [ "$hr2_rc" = 0 ] && [ "$hrf_rc" = 0 ] && [ "$hrd_rc" = 0 ] \
   && grep -qx 'DECIDE pr https://example.invalid/pr/1 opened' "$WORK/hr-deliver.out" && [ "$HRT2" != "$HRT1" ]; then
  ok "hr-chain: T1 apply exit 3 on three HARD rows, register-drift exit 0, upstream moved, T2 apply, finish and deliver exit 0"
else
  bad "hr-chain: t1=$hr1_rc rd=$hrr_rc t2=$hr2_rc fin=$hrf_rc dl=$hrd_rc t1: $(grep '^HARD\|^REFUSED' "$WORK/hr-t1.out" | tr '\n' '|' | cut -c1-300) t2: $(grep '^HARD\|^REFUSED\|^ASK' "$WORK/hr-t2.out" | tr '\n' '|' | cut -c1-300) dl: $(tr '\n' '|' < "$WORK/hr-deliver.out" | cut -c1-300)"
fi
hr_r8_blob="$(world_git -C "$HRC" show "HEAD:$HR_OVR/SKILL__Rule-8.md")"
if [ "$(hr_in_commit "$HR_OVR/SKILL__Rule-8.md")" = 1 ] && [ -z "$(hr_st "$HR_OVR/SKILL__Rule-8.md")" ] \
   && grep -qx "base_sha: $HRB" <<< "$hr_r8_blob"; then
  ok "hr-a: an override clean at T1 and remedied before the theirs change is in the deliver commit, with its base_sha, nothing left dirty"
else
  bad "hr-a: in commit $(hr_in_commit "$HR_OVR/SKILL__Rule-8.md"), status '$(hr_st "$HR_OVR/SKILL__Rule-8.md")'"
fi
hr_r9_diff="$(world_git -C "$HRC" diff -- "$HR_OVR/SKILL__Rule-9.md")"
if [ "$(hr_in_commit "$HR_OVR/SKILL__Rule-9.md")" = 1 ] && [ "$(world_git -C "$HRC" show "HEAD:$HR_OVR/SKILL__Rule-9.md")" = "$hr_r9_head" ] \
   && [ "$(hr_st "$HR_OVR/SKILL__Rule-9.md")" = " M $HR_OVR/SKILL__Rule-9.md" ] \
   && grep -qx '+OPERATOR NOTE before the pull.' <<< "$hr_r9_diff" \
   && [ "$(grep -c '^[-+][^-+]' <<< "$hr_r9_diff")" = 1 ]; then
  ok "hr-b: an override dirty at T1, remedied in the window: the commit holds the remedy only, the operator's edit is left unstaged"
else
  bad "hr-b: in commit $(hr_in_commit "$HR_OVR/SKILL__Rule-9.md"), status '$(hr_st "$HR_OVR/SKILL__Rule-9.md")', HEAD blob: $(world_git -C "$HRC" show "HEAD:$HR_OVR/SKILL__Rule-9.md" | tr '\n' '|' | cut -c1-200)"
fi
if [ -n "$HR_RD" ] && [ "$(hr_in_commit "$HR_RD")" = 1 ] && [ -z "$(hr_st "$HR_RD")" ]; then
  ok "hr-c: the consumer-drift override pull.sh register-drift wrote is in the deliver commit"
else
  bad "hr-c: '$HR_RD' in commit $(hr_in_commit "$HR_RD"), status '$(hr_st "$HR_RD")'"
fi
if [ -f "$HRC/control.txt" ] && [ "$(hr_st control.txt)" = '?? control.txt' ] && [ "$(hr_in_commit control.txt)" = 0 ]; then
  ok "hr-d: the control file written in the same window is present, untracked and out of the commit"
else
  bad "hr-d: control status '$(hr_st control.txt)', in commit $(hr_in_commit control.txt)"
fi
if [ "$(world_git -C "$HRC" show "HEAD:$HR_ALPHA")" = "$(world_git -C "$HRD" show "$HRT2:core/skills/ai-dlc/steps/alpha.md")" ] \
   && [ -z "$(hr_st "$HR_ALPHA")" ] && grep -q 'T2 UPSTREAM' "$HRC/$HR_ALPHA"; then
  ok "hr-e: the core file register-drift reverted and the T2 apply rewrote is committed as theirs, no conflict, nothing left dirty"
else
  bad "hr-e: status '$(hr_st "$HR_ALPHA")' HEAD: $(world_git -C "$HRC" show "HEAD:$HR_ALPHA" | tr '\n' '|' | cut -c1-200)"
fi
hr_dec_blob="$(world_git -C "$HRC" show HEAD:_bmad-output/ai-dlc-update/pull-decisions.tsv 2>/dev/null)"
if grep -q '	hr T1 disposition row$' <<< "$hr_dec_blob"; then
  ok "hr-f: the T1 disposition row in pull-decisions.tsv survives the theirs change into the deliver commit"
else
  bad "hr-f: committed decisions: $(world_git -C "$HRC" show HEAD:_bmad-output/ai-dlc-update/pull-decisions.tsv 2>&1 | tr '\n' '|' | cut -c1-300)"
fi

report_end reconcile-pull-driver 130
