# Carry-over backlog

Items this repo owes itself. An entry lives here when it is real, measured, and **not the
subject of any live plan** — the state that previously had no home, so it survived only by
being written into a plan about something else and vanished when that plan was discharged.

**This is the DISTRIBUTION's backlog, and it is not a push-candidate ledger.** A consumer's
`_bmad-output/ai-dlc-update/push-candidate-ledger.md` tracks what that consumer wants pushed
UPSTREAM to ai-dlc, and its receipts resolve against a pull's `theirs` ref with the verbs
`theirs_has` / `theirs_lacks`. This file tracks what ai-dlc owes ITSELF, its receipts resolve
against this working tree, and its verbs are `sh` / `has` / `lacks`. The two grammars are
mutually unreadable by each other's engine on purpose. Entry ids are `BL-`, never `PC-`.

**Read by** `scripts/backlog-reverify.sh`, which executes each entry's `verify:` receipt and
emits a status. **Rotated by** `scripts/backlog-rotate.sh`, which moves closed entries to
`docs/backlog.archive.md` — it moves, it never deletes. Neither ships; both are
distribution-only, as `core/fixtures/plan-shape/.dist-only` already is.

## Receipts

```
verify: sh <one-liner>              exit 0 = the fix is present -> CLOSE-CANDIDATE
                                    exit 9 = the receipt cannot measure its subject -> NEEDS-REVIEW
                                    any other non-zero = still reproduces -> STILL-LIVE
verify: has   <repo-rel-path> "<substr>"    close when the file CONTAINS the substring
verify: lacks <repo-rel-path> "<substr>"    close when the file LACKS it
verify: manual                      no mechanical predicate by design -> HAND-REVIEW
```

**Prefer `sh`.** The tree is right here and executable, which the consumer's ledger cannot
assume of the ref it greps. A receipt runs from the repo root with stdin closed, so it names
any input it reads as a file. A behavioural predicate asserts the defect itself and cannot be
anchored on prose the author invented to describe a wanted fix.

**THIS FILE'S `sh` POLARITY IS THE OPPOSITE OF THE CONSUMER LEDGER'S, AND THE TWO ARE WRITTEN
IN THE SAME SESSIONS.** Here, `scripts/backlog-reverify.sh:334-335` reads **exit 0 as "the fix
is present"** and non-zero as "still reproduces". In a consumer's push-candidate ledger,
`core/skills/ai-dlc-update/reconcile/ledger-reverify.sh:2929` reads it the other way — **exit 0
means the entry STILL REPRODUCES**, and non-zero proposes CLOSE-CANDIDATE. Carrying this file's
rule into a consumer receipt writes a predicate that proposes closing a LIVE defect, which is
the one direction that loses data permanently. Check which file your receipt lands in before
you fix its polarity, and read the emitter rather than either header.

**In a consumer receipt, guard the unresolvable subject too.** A RENAMED subject also exits
non-zero there, so a relocation reads as an absorption that never happened; `[ -n "$s" ] ||
exit 127` makes it NEEDS-REVIEW instead. This file's engine needs no such guard, because its
non-zero direction is the one that keeps the entry open.

**When you must use `has`/`lacks`, anchor on a token the fix CANNOT BE WRITTEN WITHOUT** — a
flag, a path, a function name — never a phrase describing the fix. The consumer's engine
detects that error by reading a third ref; this one has no third ref to read, so the rule is
enforced by the author and by review, not by the tool. `core/fixtures/ledger-reverify-unfalsifiable/README.md`
is the measurement: 13 entries on the reference consumer carried predicates that could never
have gone green, and would have reported "still open" forever.

**A closed entry is annotated in place and left for rotation**, in the form
`**LANDED (v<version>, verified <sha>).**` — the annotation FORM is what the rotator keys on,
never the word anywhere in prose, because an entry that merely discusses landing something is
not a closed entry.

## BL-474 — measure the first cross shard's serial tail before ruling on it

**DEFECT, open by operator ruling, batch 204.** `0.744.0` shards code review and QA execution across their part agents,
but the first cross shard still runs the one canonical suite run and every replay a part HANDED OVER, all in the frozen
worktree (Rule 28, "Code review and QA shard their execution too"; `BL-464`'s Track B paragraph). A hand-over is an AC
whose replay cannot reach GREEN in a fresh detached worktree at the frozen sha, so a per-group fresh copy repeats the
failure. The operator ruled, choosing among build-it-now, accept-it-serial and measure-first: **measure first, then
decide.** Until then the residue is recorded as not serial by design, never as a ruling that it may stay serial.

Measure on the reference consumer's first sharded code review or QA after it pulls `0.744.0`, from the shard directory
`merge-review-shards.sh` joins, read-only:
- the part count K and the cross group count G;
- the hand-over count N, from the part shards' `handovers: <n>` lines, and the `handover-run:` lines in the first cross
  shard, which must equal N;
- the first cross shard's wall clock from its dispatch to its file's final write, split into the canonical suite run and
  the hand-over replays, against the slowest part shard's.

Then put the measured tail to the operator with three choices, each with a marked recommendation drawn from the numbers.
**Shard it:** each cross group replays its share in an APFS clone (`cp -c`) of the frozen worktree with its setup state,
never a fresh checkout. It is unproven against absolute paths, local services, ports and databases inside the
environment, and is built as its own release with its own adversary. **Rule it serial by design:** Rule 28 and `BL-464`
record the operator's ruling. **Keep it open:** take a second sprint's measurement.

**Measured at batch 223** (graph `fcb6afe96`, 140 refs, read-only): 14 sharded review directories under
`docs/reviews/s317/shards/`, every one K=4, G=6, N=0; 0 `handover-run:` lines, matching N. The cross shard's wall clock
is unrecoverable (a `round epoch` stamp at most, no dispatch time paired with a final write); with N=0 its tail is the
canonical suite run alone. **Operator ruling, batch 223: serial by design.** Rule 28 records it.

verify: manual -- close when the measurement above is recorded in this entry from a real consumer review and the operator has ruled on it.


## BL-497 — a declared fixture that tolerates a missing input passes its sandbox with fewer assertions, and nothing compares that count against a plain run

**DEFECT, filed at batch 221; re-adjudicated at batch 222 (below the original text, which is kept whole).**

**Original filing (batch 221).** **DEFECT, filed at batch 221** as BL-495's residue, by the 0.771.0 tip adversary, measured at `4a4022e9`. BL-495 says
no mechanical predicate can tell a narrowed declaration from an under-declared one without the trace; the trace
exists for most fixtures, and nothing joins the two. Joining each declared fixture's `inputs.decl` against its own
rows in `.ai-dlc-fixture-readsets.tsv` (tracked paths outside the fixture's own directory) found **110 of 182**
traced declared fixtures reading at least one tracked file their declaration does not cover, **1927** paths in all.
Much of it is root noise (`.gitignore`, `package.json`); `agent-definition-render` alone reads 59 `core/scripts/*`
files it does not declare. An under-declared fixture is skipped when a file it reads changes, and its verdict-store
pass is reused, which is the failure BL-495 warned narrowing could introduce. Control in the same join: removing
`core-paths.sh` from `upstream-routing`'s declaration makes exactly that path appear.

The fix is the join as a validator (standalone, not an arm of `validate-enforcement-map.sh`, which the suite pole
runs), with the root-noise class enumerated and its false-positive set measured before it ships, then each real
gap declared. The map is stale for fixtures changed since its last derivation, so a row naming a file that no
longer exists is the map's, not the declaration's.

**Re-adjudicated at batch 222, measured at `50b5ca40`.** The filing makes two claims; one survives.

**Claim 1, the census: REPRODUCES.** The same join (each declared fixture's `inputs.decl`, `!` stripped, a
trailing-`/` entry covering its subtree, against its committed rows for tracked paths outside its own directory)
reads 238 declared fixtures, 182 traced, **110 with a gap, 1927 paths**. The control holds in the same invocation:
dropping `core/scripts/core-paths.sh` from `upstream-routing`'s declaration reads 111 and 1928, and the diff is that
one line. 1695 of the paths are under `core/`, 102 are `.gitignore`; `shipped-rule-version-floor` carries 956 and
`layer-crosswalk-home` 569, and `agent-definition-render` 59.

**Claim 2, the harm — "an under-declared fixture is skipped when a file it reads changes, and its verdict-store pass
is reused": FALSE as stated.** The skip is real: the hook keys a declared fixture from `.dkeys` alone
(`.githooks/pre-push:1503-1505`, the decision awk at `.githooks/pre-push:1662-1665`), so a change to an undeclared
file does not rerun it. The harm is not, because the fixture never runs against that file. A declared fixture is
run only by `core/scripts/hermetic-run.sh` (`.githooks/pre-push:2003-2006`, dispatch at
`.githooks/pre-push:2011-2020`), in a fresh sandbox holding only its declared inputs
(`core/scripts/hermetic-run.sh:54-57`, invocation at `core/scripts/hermetic-run.sh:510`), so the stored verdict cannot
depend on a file the sandbox does not hold. The map rows that produce the "gap" were traced UNSANDBOXED and predate
the declarations: `agent-definition-render`'s rows were last written at `199721b6` (0.734.0) and `f7eec6f5` (0.674.0),
its `inputs.decl` was added at `cab72a8e` (0.755.0). Measured: the kept sandbox of `agent-definition-render` at this
tip holds **0 of its 59** gap files and holds its declared `core/scripts/render-agent-definitions.sh` (control 1);
sandboxed and plain runs gave identical rc and `ok` counts on six fixtures — `agent-definition-render` 28,
`suppression-lifetime` 97, `escalation-status-vocabulary` 57, `upstream-routing` 54, `shipped-rule-version-floor` 12,
`layer-crosswalk-home` 21 (the last two carry 1525 of the 1927 paths). All six were re-run at this tip, rc 0 on
both sides and no `skip` line on either. The original fix — declare every gap — would
widen keys by files the fixture provably runs without.

**The live residue, which the title now names.**

- **(a) Reduced coverage reads PASS.** A fixture with a skip branch for a missing input passes under the sandbox with
  fewer assertions. `core/scripts/hermetic-run.sh:27-35` records the measured case (48 assertions down to 32, verdict
  PASS, one hook dropped from a declaration) and why only a `!` REQUIRED input's `HERMETIC-CONSUMED` sentinel catches
  it. An input not marked `!` has no such guard, and nothing compares a sandboxed run's assertion count against a plain
  run's.
- **(b) The sandbox is a copy, not a jail.** `env -i` and `AI_DLC_PROJECT_ROOT` set to the sandbox root
  (`core/scripts/hermetic-run.sh:54-56`) redirect a fixture that resolves its root the documented way; one that reaches
  the real tree by absolute path reads outside the sandbox, and there the original harm sentence is true — its verdict
  depends on an unkeyed read. No such fixture was measured. One was available to measure (grep the declared fixtures
  for an absolute repo path, or run each sandboxed with the real tree moved aside) and was not taken this batch.

The fix is an instrument, standalone and not an arm of `validate-enforcement-map.sh`, that runs each declared fixture
sandboxed and plain and compares their assertion and skip counts; (b) shows up in it as a sandboxed run whose result
changes when the real tree is made unreadable for the duration of that run.

**Batch 223: the instrument for (a) is built; the census run has not happened, so this entry stays OPEN.**
`scripts/census-hermetic-coverage.sh` runs each declared fixture through `core/scripts/hermetic-run.sh` (kept
sandbox, a fresh verdict store per pair) and then plainly from the root with the sandbox's own `env -i` invocation
and its tool farm. It compares the fixture rc and the multiset of `ok`/`PASS` lines, normalised for paths only and
never for digits, and it reports each side's skip-line count beside the verdict, which that count does not decide.
Each row gets one verdict: **EQUAL**, **LOW-RES** (equal at 1 or 2 ok lines), **MISMATCH** (direction
PLAIN-MORE, HERMETIC-MORE, DIFFER or RC, confirmed by one re-pair), **FLAKY** (a mismatch the re-pair did not
reproduce), **UNCOUNTABLE** (the plain run printed no ok line, never scored `0 = 0` EQUAL) or **REFUSED** (hermetic-run
exit 2, or a plain run that changed the root's git status, stash list, worktree list or durations record, which also
stops the census). A MISMATCH fixture with no `git.decl` whose own scripts call git is tagged **NO-GIT-DECL**. For that
class, `git.decl: seed` is a valid remedy beside declaring the input or marking it `!`, because the sandbox is not a
repository without one. `core/fixtures/census-hermetic-coverage` (`.dist-only`) binds it. A seeded skip-branch
fixture reads MISMATCH PLAIN-MORE, and a fixture that agrees across a cwd-relative read, a farm-only tool, a stderr ok
line and root and scratch paths reads EQUAL. Eight wrong census implementations are each killed.

The `--jail` half was dropped before it was built, so **(b) remains, unmeasured**. The census measures (a) only:
a fixture that reaches the real tree by absolute path reads it in both runs, and the two runs agree.

verify: manual -- close when an instrument run over every declared fixture reports, per fixture, the sandboxed run's assertion and skip counts equal to the plain run's, with every mismatch either fixed or covered by a `!` required input; the instrument must be shown to fire on a seeded fixture whose sandboxed count drops (an input left undeclared behind a skip branch) and stay quiet on one whose counts match


## BL-498 — the derivation-capture hook evaluates a linked worktree's `derived` fences against the main tree

**DEFECT, filed at batch 223.** Filed by the consumer as PC-S317-3.2-DERIVATION-HOOK-CWD, from a dev seat's story
worktree, and reproduced independently by that sprint's gate-1 reviewer. `core/hooks/ai-dlc-derivation-capture.sh`
ran the validator with `AI_DLC_PROJECT_ROOT="$PROJECT_DIR"`, and `core/scripts/validate-artifact-derivations.sh`
runs every fence from that root (`cd "$AI_DLC_ROOT"`). A file edited in a linked worktree was therefore judged
against the MAIN tree's files: the consumer measured one `grep -c` at 6 from the main tree and 8 from the worktree,
and the hook refused a correct write. The author's natural workaround, `git -C <worktree> show`, is refused by the
validator's read-only allowlist, so the observed workaround was pinning every fence to a sha.

**The fix.** The hook takes the edited file's own checkout, and only when it is another checkout of the same
repository: the two toplevels differ and `git rev-parse --path-format=absolute --git-common-dir` of both is the
same non-empty path. It then passes that checkout's copy of the project dir as the validator's root,
`<worktree toplevel>` plus the project dir's path below its own toplevel, so a project dir that is a subdirectory of
its repository is judged from `<worktree>/<subdir>`. The first cut passed the bare worktree toplevel, which ran such
a project's fences one directory too high and refused correct writes; the adversary pass on 0.773.0 measured it
(base hook 0, release hook 2), and arm A7 with mutant M3 now holds it. The git calls run in a subshell with
`GIT_DIR`, `GIT_WORK_TREE`, `GIT_INDEX_FILE` and `GIT_COMMON_DIR` unset: under an exported `GIT_DIR` git takes the
current directory as the toplevel, so a main-tree edit in a subdirectory read as a different checkout and a correct
fence was refused. Arm A8 with mutant M4 holds that. Every other case keeps `PROJECT_DIR` as before: a main-tree
edit, a nested repository or submodule (a different common dir), a file outside any repository, a project dir that
is not a repository, and a git without `--path-format`. The
validator is unchanged and stays the installed copy beside `PROJECT_DIR`. `core/fixtures/derivation-capture-worktree-root`
(ships) seeds a fence that is right in the worktree and stale in the main tree, in both layouts (worktree outside the
project dir, and inside it at `.claude/worktrees/`). Its anti-stub arm requires exit 2 naming only a pair stale in
both trees, and its nested-repo arm requires the project root to be kept. It kills the revert-to-`PROJECT_DIR` mutant
and the no-common-dir-check mutant in its own run.

**The receipt** drives the hook three times in one throwaway repository with a linked worktree and a nested
repository: (a) a fence correct in the worktree and stale in the main tree must exit 0; (b) a fence stale in the
worktree must exit 2; (c) a fence in the nested repository that is correct for the project root and wrong for the
nested root must exit 0. It then requires the emission line `AI_DLC_PROJECT_ROOT="$DERIV_ROOT"` in the hook, the
literal `validate-backlog-receipts.sh` needs to score it at all (with no literal it is UNSCORABLE and the ledger's only
`sh` receipt leaves R2 with zero scored); a correct fix that renames that variable must update this receipt. Scored under `set -uo pipefail` against trees holding each hook: the fix 0 (`020`), the base
at `aa594904` 1 (`200`), an `exit 0` stub 1 (`000`), show-toplevel without the common-dir check 1 (`022`), and the
root resolved but `PROJECT_DIR` still passed to the validator 1 (`200`).

verify: sh unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR; d=$(mktemp -d) && d=$(cd "$d" && pwd -P) && m="$d/m" && w="$d/w" && mkdir -p "$m/.claude/hooks" "$m/scripts/ai-dlc" "$m/x" && cp core/hooks/ai-dlc-derivation-capture.sh "$m/.claude/hooks/h.sh" && cp core/scripts/validate-artifact-derivations.sh "$m/scripts/ai-dlc/" && printf 'a\n' > "$m/d.txt" && printf 'x\n' > "$m/x/k" || exit 9; g(){ git -C "$1" -c user.name=f -c user.email=f@x.invalid -c commit.gpgsign=false -c core.hooksPath=/dev/null "${@:2}" >/dev/null 2>&1; }; g "$m" init -q && g "$m" add -A && g "$m" commit -qm b && g "$m" worktree add -q -b s "$w" && printf 'a\na\na\n' > "$w/d.txt" && mkdir -p "$m/n" && printf 'a\na\n' > "$m/n/d.txt" && g "$m/n" init -q && [ -d "$m/n/.git" ] || exit 9; f(){ printf '# s\n\n```derived\n$ grep -c a d.txt\n%s\n```\n' "$2" > "$1"; }; h(){ jq -nc --arg f "$1" --arg c "$(cat "$1")" '{tool_name:"Write",tool_input:{file_path:$f,content:$c}}' | CLAUDE_PROJECT_DIR="$m" bash "$m/.claude/hooks/h.sh" >/dev/null 2>&1; printf '%s' "$?"; }; f "$w/x/ok.md" 3; f "$w/x/bad.md" 1; f "$m/n/ok.md" 1; r="$(h "$w/x/ok.md")$(h "$w/x/bad.md")$(h "$m/n/ok.md")"; [ "$r" = 020 ] && grep -qF 'AI_DLC_PROJECT_ROOT="$DERIV_ROOT"' core/hooks/ai-dlc-derivation-capture.sh

## BL-499 — Check 22 judged every spawn row against the model pin read at gate time, so a mid-sprint pin change failed every correct earlier dispatch

**DEFECT, filed at batch 223.** Filed by the consumer as PC-S317-SPAWN-LEDGER-PIN-CHANGE-RETROACTIVE.

`core/scripts/validate-spawn-ledger.sh` compared each row's `model_bound` against `aiDlcRoles.<role>.model` as
`--settings` read at the gate. A row records what was right at its own dispatch, so an operator editing a pin
mid-sprint turned every earlier correct dispatch into a Rule 19(a) FAIL. Measured on a copy of the consumer's
sprint-317 ledger (992 in-sprint rows, every one carrying `tier_pinned`) with `--probe`: the base validator at
`aa594904` reports 288 Rule 19 FAILs under the current settings and 67 under the pre-pin settings, on the same
ledger. Arm S3's 10 FAILs do not change between the two runs, which is the control.

The fix judges a row carrying `tier_pinned` (the key the dispatch guard resolved at dispatch) against the model its
teammate's own transcript recorded, joined from `--probe` by `tool_use_id`. An unjoined row is PENDING, and a pin
that has changed since is a `NOTE:`. A row without `tier_pinned` keeps the gate-time comparison unchanged. The
comparison is not `tier_pinned` against `model_bound`, because the guard writes both from one resolution and that
comparison cannot fail. On the same copy, the fixed validator reports 0 Rule 19 FAILs under both settings files,
with 866 rows verified, 126 PENDING, and 288 or 67 rows NOTED as dispatched under a pin since changed. Covered by
the T-series in `core/fixtures/check-22-spawn-ledger/run.sh`, including mutants for the current-settings comparison
and for no comparison.

**This is a coverage reduction for older rows, and it is recorded rather than hidden.** Rows from earlier sprints
carry `tier_pinned` but no `tool_use_id` (on the consumer's ledger: sprints 298-310, plus 17 rows in 311), so they
join no transcript model and now read PENDING where they were compared to the gate-time settings before. **A pin
key is not the model it names**, and the first cut compared the transcript model against the key alone, so a
consumer key such as `fast` naming `claude-sonnet-5-5` failed a correct run. A key miss is now retried against the
resolved string, the row's `model_pinned` or else `aiDlcModels[<key>]`, and a `<synthetic>` transcript model is
PENDING; arms K1-K4 and three mutants in the same fixture hold both.

verify: sh grep -q 'tier_at_dispatch' core/scripts/validate-spawn-ledger.sh && d="$(mktemp -d)" && printf '%s\n' '{"aiDlcModels":{"opus":"claude-opus-5","sonnet":"claude-sonnet-5"},"aiDlcRoles":{"dev":{"model":"opus"}}}' > "$d/s" && printf '%s\n' '{"v":1,"sprint":9,"name":"pre","role":"dev","tier_pinned":"sonnet","model_bound":"sonnet","model_requested":"sonnet","role_contract_cited":true,"role_file_readable":true,"tool_use_id":"t1"}' > "$d/a" && printf '%s\n' '{"v":1,"sprint":9,"name":"bad","role":"dev","tier_pinned":"sonnet","model_bound":"sonnet","model_requested":"sonnet","role_contract_cited":true,"role_file_readable":true,"tool_use_id":"t2"}' > "$d/b" && printf '%s\n' '{"tool_use_id":"t1","model":"claude-sonnet-5"}' '{"tool_use_id":"t2","model":"claude-opus-5"}' > "$d/p" && bash core/scripts/validate-spawn-ledger.sh --ledger "$d/a" --sprint 9 --settings "$d/s" --probe "$d/p" > "$d/oa" 2>&1 && grep -q 'NOTE: \[pre\] was dispatched under' "$d/oa" && { bash core/scripts/validate-spawn-ledger.sh --ledger "$d/b" --sprint 9 --settings "$d/s" --probe "$d/p" > "$d/ob" 2>&1; [ $? -eq 1 ]; } && grep -q 'FAIL: \[bad\]' "$d/ob"

## BL-500 — the deploy-gate smoke-failure loop routed a code fix to the dev seat without dispatching it, and a lead fixed the code inline

**DEFECT.** Filed by the consumer as `PC-S317-DEPLOY-VALIDATE-FIX-LOOP-ROUTES-TO-A-DEV-SEAT-NAMELESSLY-LEAVING-INLINE-LEAD-EXECUTION-UNGUARDED`.
The filing was uncommitted in the consumer's working-tree ledger when this batch was scoped, so its id may
change before the consumer commits it.

**What happened.** `core/skills/ai-dlc/steps/deploy-validate.md` §3, the smoke-failure loop, item 3 read
"If code issue: route back to the dev teammate to fix, re-deploy, and re-run smoke tests." It named a seat and no
delegation. In the consumer's S317 deploy gate the lead read it as its own route to execute and edited product code
and a test inline before the operator caught it. Rule 28's non-delegable set does not cover that edit: (a)
Orchestration lists dispatch, branches, merges and discharge predicates, and `rule-bodies/rule-28.md` names
"applying a fix" as an inline action outside the set. Item 4 already said "dispatch the `ops` teammate", and §7 of
the same file already said "dispatch `dev` for the fixes … the lead then redeploys". Item 3 was the one repair path
in the step that named no dispatch.

**The fix (batch 223).** Item 3 now opens "If code issue: dispatch `dev` to fix the code and its tests", says the
lead then re-deploys and re-runs smoke, limits the lead's own work in the loop to the dispatch, the commit, the
re-deploy and the smoke re-run under Rule 28 (a) Orchestration, and calls a lead's product-code edit there applying
a fix inline, a Rule 28 lead-conduct finding. `SKILL.md`'s Rule 28 text is unchanged. No model replay closes a
prompt fix, so the close is the text plus a pin: `core/fixtures/deploy-validate-smoke-classification` gains a
§3-scoped `DISPATCH` arm, line-anchored on item 3 because §7 already carries `dispatch `dev`` and a whole-file
grep was satisfied before the fix. Its mutants `revert-dispatch`, `comment-dispatch` (the dispatch phrase parked in
a comment beside an undelegated item 3) and `no-leadscope` are each killed by that arm alone.

The receipt below is scoped to §3 the same way and scored under `set -uo pipefail`: 0 on the fixed tree, 1 on the
base `aa594904`, 1 on item 3 reverted, 1 with `dispatch `dev`` added only to §7, 1 with it added only as a
comment inside §3, and 9 when §3 cannot be isolated.

verify: sh F=core/skills/ai-dlc/steps/deploy-validate.md; [ -f "$F" ] || exit 9; B="$(awk '/^### 3\. Smoke Tests/{on=1; next} on && /^### /{exit} on{print}' "$F")"; [ -n "$B" ] || exit 9; grep -qE '^3\. If code issue: dispatch `dev` to fix' <<<"$B" || exit 1; L="$(printf '%s' "$B" | tr '\n' ' ' | sed 's/[[:space:]][[:space:]]*/ /g')"; case "$L" in *'is applying a fix inline, which Rule 28 makes a lead-conduct finding'*) exit 0 ;; *) exit 1 ;; esac
