# s305 triage — six root causes, each measured, each with a remedy

## RESUME HERE

**You were started with one sentence: `READ and FOLLOW docs/plans/graph-s305-triage.md`.
This section is the whole of your entry point and it is the ONLY CURRENT STATUS RECORD in
this file.** Everything from `## Context` down is EVIDENCE — measurements taken 2026-08-24/25
against trees that have since moved. Read it when a figure looks arbitrary or when you need
the derivation behind one. **Do not take an instruction from it.**

**Two repos, and the boundary is absolute.** `/Users/n8/git/ai-dlc` is WRITE.
`/Users/n8/git/graph` is the reference consumer: **read it, never write it.** Full boundary,
and the reason for it, in `## Start here` below.

**Ping the operator** on any question, on any decision, and on completion — including an
early stop. Silence and progress are indistinguishable from outside.

**Merges are preapproved.** Cut the branch, run the gate, merge it. Each phase is ONE
release on its own branch; `validate-release-version.sh` rejects a branch carrying two.

### Derive the state; do not trust the record below

Every figure in this file is a HYPOTHESIS about trees that have moved. The measured base
rate of expired premises in this program is roughly one in two. **Run this block first — it
is the phase state.** Each probe is keyed on an emission site, and the two controls at the
end must read `DONE` then `TODO` or the block is not discriminating and its zeros mean
nothing.

```sh
cd /Users/n8/git/ai-dlc
v() { [ "$1" -gt 0 ] && echo DONE || echo TODO; }
lb=$(awk '/ALLOWED_BY_LIVE_BEAT/{f=1} f&&/exit 0/{exit} f' core/hooks/ai-dlc-continue.sh \
     | grep -cF 'rm -f "$STATE_FILE"')
echo "P1a readset producer ships   $([ -e core/scripts/derive-fixture-readsets.sh ] && echo DONE || echo TODO)"
echo "P1b party-mode home in core  $(v "$(grep -rF -- '_bmad-output/party-mode/s<N>/' core/skills/ai-dlc/ | wc -l)")"
echo "P1c SKILL.md parenthetical   $([ "$(grep -cF 'planning-artifacts/party-mode' core/skills/ai-dlc/SKILL.md)" -eq 0 ] && echo DONE || echo TODO)"
echo "P1d push time budget        $(v "$(grep -ciF 'timeout' core/skills/ai-dlc/steps/_gate-procedures.md)")"
echo "P1d CONTROL (same file)      $(v "$(grep -cF 'git push' core/skills/ai-dlc/steps/_gate-procedures.md)")"
echo "P2  live-beat keeps LAST_TS  $([ "$lb" -eq 0 ] && echo DONE || echo TODO)"
echo "P3  escalation guards        $(v "$(grep -ciF 'escalation_undelivered' CHANGELOG.md)")"
echo "P4  answer-capture routes    $(v "$(grep -cF 'additionalContext' core/hooks/ai-dlc-answer-capture.sh)")"
echo "P5  full re-read mandate     $([ "$(grep -cF 'IN FULL' core/skills/ai-dlc/SKILL.md)" -eq 0 ] && echo DONE || echo TODO)"
p6a=$([ -e core/scripts/sync-transient-ignore.sh ] && echo 1 || echo 0)
p6b=$(grep -cF 'bash "$SYNC_IGNORE"' scripts/install.sh)
echo "P6  transient ignore rule    $(v "$((p6a * p6b))")"
echo "P7  consumer brief filed     $(v "$(ls docs/reviews/ 2>/dev/null | grep -c s305)")"
echo "CTL must be DONE             $([ -d core ] && echo DONE || echo TODO)"
echo "CTL must be TODO             $([ -e core/NO-SUCH-CONTROL.sh ] && echo DONE || echo TODO)"
```

**P1a through P6 read DONE; P7 reads TODO; `P1d CONTROL` reads DONE and the
two block controls read DONE then TODO.**

**P6's ORIGINAL PROBE WAS REPLACED BECAUSE IT WENT GREEN ON A COMMENT.** It grepped
`templates/` and `scripts/install.sh` for `wait-beats`, and the shipped fix put that token in
`core/schemas/pipeline-state-paths.json` — nowhere the probe looked. What made it read DONE was
a MEASUREMENT SENTENCE in install.sh's new header naming the path. A whole-file grep is
satisfied by a comment, which is this repo's own standing rule, and the probe had drifted onto
the wrong side of it. It now keys on two emission sites: the renderer existing at a path fixed
by convention, and install.sh's invocation LINE.
Every probe read TODO when this plan was written, and the three that flipped did so when
phase 1 landed — which is the polarity proof, not a formality. Each probe is polarity-correct
in the sense `BL-086` names: it keys on a byte that EXISTS today and the fix REMOVES, or on a
path fixed by convention (`core/scripts/`) rather than on a flag name a hypothesised fix would
introduce. **A probe anchored on a token the fix invents reports TODO forever, including after
the fix lands** — three of them have now been observed flipping, so that failure is ruled out
for those three and not for the rest.

Re-derive the consumer side too, each with its own control:

```sh
cd /Users/n8/git/graph && bash scripts/ai-dlc/validate-artifact-paths.sh | tail -1
git -C /Users/n8/git/graph ls-files _bmad-output/.wait-beats/ | wc -l
for e in BLOCKED BACKOFF ALLOWED_BY_LIVE_BEAT NO_SUCH_EVENT_CONTROL; do \
  printf '%-24s %s\n' "$e" "$(grep -c "^## .*-- ${e}" \
  /Users/n8/git/graph/_bmad-output/pipeline-continuation-log.md)"; done
md5 -q /Users/n8/git/graph/_bmad-output/ai-dlc-update/push-candidate-ledger.md
```

At this plan's writing those read `FAIL — 24 blocking, 3 ambiguous`; `134`;
`BLOCKED 15 / BACKOFF 0 / ALLOWED_BY_LIVE_BEAT 240 / NO_SUCH_EVENT_CONTROL 0`; and
`a8f61789e1c947a8251eef9b4cb7c098`.

### What is DONE — do not redo any of it

**Phase 1 (RC-1) is DONE, shipped as v0.404.0 (`fe64a47a`). Action 6b (RC-1b) is DONE,
shipped as v0.405.0 (`fea38ec7`), taken out of order at the operator's direction. Phase 2
(RC-4) is DONE, shipped as v0.406.0. Phase 3 (RC-3) is DONE, shipped as v0.407.0, with its
item 1 DROPPED on the operator's decision — see RC-3's remedy. Action 4 (RC-2) is DONE,
shipped as v0.408.0 (`faea82e7`, merged `dbdb18cb`). Action 5 (RC-5) is DONE, shipped as
v0.409.0 (`16cc6799`, merged `f7318db0`). Action 6 (RC-6) is DONE, shipped as v0.410.0.
All merged to `main` and pushed.
Action 7 is the only one open. Start at NEXT ACTION 7.**

**Tree state at handoff:** on `main`, clean, level with `origin/main`, `VERSION` `0.410.0`.
**NOTHING IS IN FLIGHT** — no branch open, no partial edit, no unrun gate. Action 7 has not
been started.

**RC-6 MEASURED WIDER THAN IT WAS FILED, and the operator chose the wider scope.** The entry
below records 134 tracked files under one path; the measurement was 138 across THREE —
`.wait-beats/` (134), `.driver/` (3), `.context-sensor-state` (1) — with ten more transient
paths latent and NO ignore-rule delivery path in the distribution at all (`install.sh` carried
zero references to `.gitignore`). What shipped is a full transient/durable PARTITION of the 33
names the machinery constructs, rendered by a shipped script and bound by **I95**. A blanket
`_bmad-output/.*` glob was measured and rejected: the reference consumer tracks
`_bmad-output/.audit-accepted-exceptions`, which `core/` has zero knowledge of.

**THE CONSUMER STILL HAS ALL 138 FILES TRACKED, AND NOTHING IN THIS RELEASE UNTRACKS THEM.**
An ignore rule does nothing to a file git already tracks. The renderer NAMES them and prints
the `git rm -r --cached` command; running it is action 7's business, on the consumer side.

**THE COMPACTION-DURABLE RULE CHANNEL IS EFFECTIVELY FULL: 44522 of 44544 bytes, 22 free.**
Arm A6 of `scripts/validate-claude-rules.sh` fails the push over the ceiling, so any rule you
add to `CLAUDE.md` or to a `.claude/rules/` file with no `paths:` breaks your gate unless you
delete as much as you add. Raising the ceiling has been an OPERATOR RULING both times it has
happened. Derive the live number before you plan a rule — `bash
scripts/validate-claude-rules.sh` prints it — because this figure moves with every release.

**EIGHT LOCAL BRANCHES ARE AHEAD OF `origin/main` AND NONE OF THEM IS THIS PLAN'S.** All six
plan release branches are fully contained in `origin/main`, verified by content rather than
ancestry. The eight predate this plan: `backup-batch7b`, `hook-selftest`, and six
`worktree-agent-*`. Two are substantial — 13 and 20 commits — and they carry FIXTURE-SHARDING
AND FORK-BUDGET PERF WORK, which is the subject of **BL-088**, the suite pole. Do not assume
they are dead, and do not delete one to tidy up; ask the operator before acting on them.
`git rev-list --count origin/main..<branch>` is the reading.

**`git branch` OUTPUT WAS SILENTLY TRUNCATED WHEN THIS WAS DERIVED** — a listing showed 8 of
20 branches, caught only because a `release/*` count of 8 contradicted the names beside it.
That is the Bash-output compressor described below, on a command whose answer is a LIST.
Count the thing two ways before you believe a branch inventory.

**The whole consumer block was re-derived at this handoff and every value is UNCHANGED**
from the record above: `FAIL — 24 blocking, 3 ambiguous`; `134` tracked wait-beats;
`BLOCKED 15 / BACKOFF 0 / ALLOWED_BY_LIVE_BEAT 240`; ledger
`a8f61789e1c947a8251eef9b4cb7c098`. The control `NO_SUCH_EVENT_CONTROL` read `0` while three
real event names read non-zero in the same invocation, so the grep discriminates and those
zeros are readings rather than a broken pattern. Nothing in `/Users/n8/git/graph` was
written — its three dirty paths (`.context-sensor-state`, `.driver/turns`,
`pipeline-continuation-log.md`) belong to its own paused session and were dirty before this
work began.

**THE BASH-OUTPUT HAZARD IS LIVE AND IT FIRED AGAIN IN THE v0.409.0 SESSION.** A compressor
edits text inside Bash results, code included, and raises no error. It struck twice while
RC-5 was being built: an `install.sh` read came back with its copy loop mangled, and a
`core-manifest.md` block read came back deduplicated so four list entries were invisible.
Both were caught only by re-deriving with `grep -c` instead of reading. Read source with
`Read` or `ctx_execute_file`; keep Bash for output whose SHAPE is the answer — counts, exit
codes — and for mutations. **Where a Bash result has to be exact, DERIVE it**: the pattern
that worked all session was `printf 'a=%s b=%s\n' "$(grep -c X f)" "$(grep -c Y f)"`, one
line, with a control in the same invocation.
`scripts/validate-claude-rules.sh`'s A6 header carries the ruling and why neither
mechanising nor scoping was available.

**A BUDGET WAS RAISED IN v0.409.0 AND THE MEASUREMENT THAT JUSTIFIED IT WAS INITIALLY WRONG.**
`FORK_BUDGET` went `7000 -> 7050` in `scripts/validate-enforcement-map.sh`. A first timing
comparison read **+1.9s (11%)** on the pole validator and would have justified an optimisation
pass; it was invalid, because it ran `origin/main` from a `mktemp` extraction against the
branch in the LIVE REPO — two different trees. Re-measured with both sides extracted alike and
the runs INTERLEAVED to cancel drift, five reps each: main **17.29s**, branch **17.10s**. No
regression. **Never compare a `mktemp` extraction against the working repo**, and interleave
timing reps rather than running one side then the other.

**RC-2's THREE REMEDY ITEMS ALL SHIPPED, and the single-source clause cost more than the
routing did.** Routing the answer channel made a second emitter of the pause branch text and
a second reader of the handoff-intent patterns, so both moved into a new declaration,
`core/schemas/pause-routing.json`, with three readers and invariant **I94** holding it to one
copy. Two things a later phase should not rediscover:

- **`I92` was the ID first chosen and it was already claimed**, by the transcript-corpus
  predicate arm. The rendered index caught it; its `i92_*` variables would also have
  collided inside the same file. Read `docs/invariant-index.md` before claiming a number.
- **An arm's FORK COUNT is a change to the suite's wall clock, and `validator-fork-budget`
  is what says so.** I94's first draft resolved each declared field with its own `python3`
  start, twice over, and measured 7020 against a 7000 ceiling. Dumping the whole declaration
  once and replacing a per-field `grep | grep -v | tr` with one `grep` plus shell filtering
  brought it to 6998. The budget was NOT raised.

**THREE PREMISES IN RC-4'S EVIDENCE WERE MEASURED FALSE while executing phase 2, and the
remedy that shipped is not the remedy that was filed. The operator chose it on the
measurement.** All three are corrected in RC-4's own section rather than here, because that is
where a later reader meets them. The short form: the filed remedy — keep `LAST_TS`, zero the
counter — is BEHAVIOURALLY INERT, and a mutant built from it is killed by the same two fixture
arms that kill the unfixed hook.

**TWO PREMISES BELOW WERE MEASURED FALSE while executing phase 1, and both are corrected
here rather than in the evidence they contradict.**

- **RC-1's ORDERING CONSTRAINT is wrong.** I82 does NOT fail on
  `_bmad-output/party-mode/s<N>/` when the area is undeclared. Differential, both runs on
  the live tree: byte-identical output, rc=0 either way. Its predicate reads path
  COMPONENTS and is area-independent. Positive control in the same session: a seeded
  `_bmad-output/party-mode/s305-findings.md` in that same file makes I82 fire, rc=1.
- **The area was already declared, by the CONSUMER.** graph's
  `.claude/skills/ai-dlc/artifact-paths.md` lists `_bmad-output/party-mode`. On the
  rehearsal clone, `validate-artifact-paths.sh` reports PASS with core's declaration,
  without it, and with NEITHER — so adding it to core's `areas:` block moved no verdict
  and would have been a decoration. It is load-bearing now only because I82b's second
  direction was built to give it a subject.

**A third premise held but was INCOMPLETE.** "Have `core/git-hooks/pre-push` generate the
map rather than fall back to all-155" cannot be done: the deriver needs root, because
`fs_usage` is the only tracer that sees a stat()-only dependency and an atime-only map
under-records exactly those — the direction that skips a fixture silently. A pre-push
cannot prompt for a password. Both hooks now print the resolved `sudo bash <path> --all`
instead of only the fallback line, and the producer ships so the command resolves.

**Do not re-run the investigation.** Every measurement behind the six findings is recorded
below with the command that produced it and the control that ran beside it. Re-deriving the
byte accounting means re-parsing 10.4 MB of transcript for a number this file already
carries, and the transcripts are outside every gate — nothing will tell you it was wasted.

**As each phase lands, the `### Remedy — COMPLETE, SHIPPED AS v0.404.0` heading of its RC section below is amended to
`### Remedy — COMPLETE, SHIPPED AS vX.Y.Z` and this paragraph is replaced.** Those headings
are the only place a phase's completion is written by hand, and they are corroboration only:
**the probe block above is the authority.** Where the two disagree the probe is right, because
a heading is a claim about the tree and the probe is a reading of it.

### NEXT ACTIONS — numbered, in order

**Run the probe block first and execute the LOWEST-NUMBERED ACTION whose probe reads `TODO`.**
The sprint cannot safely resume until the consumer can push, which is why RC-1 is action 1.

**The probes are NOT in action order and one of them is out of family, so the map is written
out rather than inferred.** `P1a`/`P1b`/`P1c` → action 1 (DONE). `P1d` → action 6b (DONE).
`P2` → action 2 (DONE). `P3` → action 3 (DONE). `P4` → action 4 (DONE).
`P5` → action 5 (DONE). `P6` → action 6 (DONE). `P7` → action 7. Read the ACTION number, not the
probe's; a session going top-down through the probe list reaches `P1d` first and would start
in the wrong place.

**`P2` grew a second way to read DONE and the fix had to work around it.** It greps the
live-beat window for the literal `rm -f "$STATE_FILE"`, so PROSE in that window naming the
command it is looking for holds the probe at TODO after the command is gone. Measured: the
first draft of the fix explained itself by quoting the deleted line, and `P2` read TODO
against a correctly fixed hook. The comment now describes the removal without spelling it,
and says why in the comment itself.

1. **RC-1 — unblock the consumer's push.** **Declare `_bmad-output/party-mode` in core's
   own `areas:` block FIRST** (`core/skills/ai-dlc/artifact-path-grammar.md`) — see the
   ordering constraint in RC-1's remedy; then prescribe the findings home at
   `_bmad-output/party-mode/s<N>/`; fix `core/skills/ai-dlc/SKILL.md:721`; close the I82
   prescription blindness with a derived join; ship `derive-fixture-readsets.sh` into
   `core/scripts/`, `install.sh`, `uninstall.sh` and both manifest copies, and make
   `core/git-hooks/pre-push` generate the map rather than fall back to all-155.
2. **RC-4 — COMPLETE, SHIPPED AS v0.406.0.** The stall detector can now fire. What shipped is
   a DELETION of the live-beat state wipe, not the counter-reset that was filed here — see
   RC-4's remedy for the differential that changed it, and note that the plan's own fixture
   prescription would have produced a vacuous arm.
3. **RC-3 — COMPLETE, SHIPPED AS v0.407.0.** The `PostToolUse` on `SendMessage` ships and the
   constraint is stated once. The `PreToolUse` deny was DROPPED because it could not be shown
   able to fire — see RC-3's remedy for the evidence and the operator's decision.
4. **RC-2 — COMPLETE, SHIPPED AS v0.408.0.** `ai-dlc-answer-capture.sh` routes a
   handoff-intent answer: pause flag, `USER_PAUSE` with a `Channel:` line, and the branch as
   `PostToolUse` `additionalContext`. The branch text and both intent patterns are declared
   once in `core/schemas/pause-routing.json` and read by three components; **I94** forbids a
   second copy. Check 0 gained a teammate-sweep arm — no `In-Flight Teammates` row may still
   read `in-flight` at a handoff, and `steps/handoff.md` step 1 requires the row be rewritten
   to `stopped` rather than deleted. Step 4's driver `touch` is unconditional in both the
   handoff and the auto-handoff copy. New shipping fixture `answer-handoff-routing`;
   `handoff-resume-guard` gained six arms and a mutant; `pause-hook-origin` now compares five
   legend seeders.
5. **RC-5 — COMPLETE, SHIPPED AS v0.409.0.** `core/skills/ai-dlc/postcompact-digest.md`
   ships, rendered by `scripts/render-postcompact-digest.sh` and byte-compared at pre-push.
   The mandated post-compact Read goes **102,881 → 21,850 bytes, −78%**. It is a SELECTION of
   SKILL.md's own bytes, not a summary. See RC-5's remedy for the faithfulness arm and for
   the one part of the done-when this release CANNOT close.
6. **RC-6 — COMPLETE, SHIPPED AS v0.410.0.** `core/schemas/pipeline-state-paths.json`
   classifies all 33 paths the machinery writes under the pipeline root (13 transient, 20
   durable); `core/scripts/sync-transient-ignore.sh` renders the transient half into the
   consumer's `.gitignore` as a marker-bounded block with a `--check` mode; **I95** binds the
   declaration to the machinery in both directions; new shipping fixture
   `transient-ignore-block` carries 7 arms and 3 mutants. See RC-6's remedy for why the
   renderer is a shipped script rather than installer code, and for the glob that was rejected.
6b. **RC-1b — COMPLETE, SHIPPED AS v0.405.0.** Core prescribed `git push` with no time budget.
   Measured on a `file://` clone of the reference consumer at `386a56d34`, per-line
   timestamps: the pre-push is **148.9s**, of which every phase before the fixture suite is
   **18.0s** and the suite is **130.9s**. The default caller timeout is **120s**. The suite
   is POLE-BOUND — 155 fixtures, 1006 fixture-seconds, longest single fixture
   `layer-reference-resolution` at **119s** — so phase 1's read-set map removes the routine
   cost and CANNOT put a change that selects the pole under the default. The transcript
   records the SIGKILL twice, `2026-08-24T13:19Z` and `2026-08-25T01:41:47Z`
   (`Exit code 143 | Command timed out after 2m 0s`).

   Core prescribes `git push` as bare text in three places — `steps/_gate-procedures.md:617`,
   `steps/handoff.md:31`, `steps/retro.md:891` — with no timeout and no backgrounding.
   Prescribe an **explicit long timeout on a FOREGROUND call**, once, cited from the other
   two. Do not prescribe `run_in_background`: it is the same fix with an extra way to go
   wrong, and the way it goes wrong is this repo's own standing rule — *"Read the gate's
   exit, never a backgrounded wrapper's"* (`.claude/rules/verification-discipline.md`),
   learned from a gate that exited 1 under a 159 ok / 0 FAIL tally. The exit code IS
   delivered by a background call in this harness; what backgrounding adds is a session that
   proceeds past a push it has not yet made, and `git push` is a mutation.

   **This is PROSE WITH NO ENFORCER and it ships that way deliberately.** A `PreToolUse` hook
   can deny a call; it cannot raise the timeout of one. Nothing on disk can make the lead
   pass a budget it was not told to pass. Say so beside the instruction rather than leaving a
   later session to discover the rule is unbacked and assume it was an oversight.

   **The durable fix is the POLE, not the budget**, and it is explicitly NOT in this plan's
   scope: 119s in one fixture is what makes a 120s default unsurvivable at all. FILED as
   **BL-088** — that did not happen when 6b shipped, and was caught only when a later phase
   went looking. It is distinct from BL-005, which is a different pole in a different tree.
7. **Deliver the consumer brief.** Rehearse on a `file://` clone, then hand the paused
   graph session an exact command list: migrate the 24 paths, untrack the 134 wait-beats,
   re-run `validate-artifact-paths.sh` and the pre-push, resume gate-3 only after both are
   green.

   **The path half of that is already REHEARSED, on a `file://` clone at `386a56d34`.**
   22 tracked files `git mv` from `_bmad-output/planning-artifacts/party-mode/s305/` to
   `_bmad-output/party-mode/s305/`, preserving the `architecture-rounds/` subdirectory,
   then `migrate-artifact-paths.sh --apply` for the 2 residual
   `_bmad-output/brainstorming/brainstorm-s305-*` paths, which are a different and
   pre-existing class. The verdict went `FAIL — 24 blocking, 3 ambiguous` to `PASS — 0
   blocking, 3 ambiguous` over 5793 tracked files. The 3 ambiguous are non-blocking and
   pre-date s305. Do NOT run `migrate-artifact-paths.sh` on the 22: it derives
   `_bmad-output/planning-artifacts/s305/party-mode/`, which is legal but is neither the
   prescribed home nor where sprints 297/298/303 put theirs.

   **The brief must also carry the TIME BUDGET**, whose measurement and whose reason for
   being a foreground timeout rather than a background call are in action 6b and are not
   restated here. Two commands for that session: push with an explicit long timeout, and
   build the map once with `sudo bash scripts/ai-dlc/derive-fixture-readsets.sh --all`.

### Done when

All ten phase probes read `DONE` with `P1d CONTROL` still `DONE`, the consumer's `validate-artifact-paths.sh` reports 0 blocking,
its pre-push completes inside the two-minute bound, and the graph session has been handed the
brief. Report completion to the operator; an early stop is reported the same way.

---

## Start here

**The read/write boundary, in full.** `/Users/n8/git/ai-dlc` is WRITE. `/Users/n8/git/graph`
is the reference consumer: **read it, never write it.** An ai-dlc session never writes to a
consumer — it writes `core/`, and it writes the brief. Assert the boundary by ledger CONTENT,
not by dirty count and not by `HEAD`:
`md5 -q /Users/n8/git/graph/_bmad-output/ai-dlc-update/push-candidate-ledger.md`. Record it
before your first action and re-check after every phase; a change is a stop-and-ping condition.

**Never run `git checkout --`, `git restore`, `git clean`, `git stash`, or
`git reset --hard` in either repo, and tell every delegate the same.** Delegates work in
`mktemp` copies made with `git archive HEAD | tar -x`.

### Delegate, and name the model

**The phases are independent below phase 1. Spawn named agents in parallel and background
anything long** — the operator's cost is wall clock, not tokens, and this box has 18 cores.
Give every agent a `name` so it stays addressable by `SendMessage` while it runs.

**Send work to a subagent when any of these is true**, and do the work inline otherwise:

- it is a SEARCH or a census whose answer is a short conclusion drawn from many files — the
  agent keeps the file dumps and hands back the number;
- it is a REHEARSAL on a `file://` clone or a `mktemp` copy, which is slow, self-contained,
  and produces one verdict;
- it belongs to a different phase than the one in front of you and shares no file with it;
- it is a two-direction self-probe or a mutation battery whose only output is a kill count.

**Do NOT delegate the thing the phase is FOR.** Writing the arm, choosing the predicate,
deciding what a measurement means, and reconciling a finding against this plan's evidence
stay with the session that owns the phase. A subagent's read of a `paths:`-scoped rule file
loads inside that subagent only and never reaches you, so an agent authoring core files is
authoring them without the rules you are holding.

**Choose the model by the reasoning the task needs, not by how long it will take.** The
parameter is `model` on the `Agent` call and its values are `opus` and `sonnet`; it
overrides the agent definition's own frontmatter, and it is IGNORED for
`subagent_type: "fork"`, which always runs on the parent's model.

- **`model: "sonnet"`** — the task has a stated procedure and a checkable answer. Running a
  named script and reporting its verdict and exit code. Enumerating call sites, counting a
  corpus, extracting a list. Building a scratch install and reporting whether a file landed.
  Driving a fixture and reporting its tally. Re-deriving a figure this plan already carries,
  with its control.
- **`model: "opus"`** — the task requires deciding what the answer MEANS. Designing a
  predicate and measuring its false-positive set. Adjudicating whether a zero is a finding or
  a broken instrument. Reading a hook's state machine to work out why an arm cannot fire.
  Writing rule prose that will sit in the resident channel. Anything whose output this plan
  will be amended from.

**When you cannot tell which, it is `opus`.** The failure mode this ordering exists to
prevent is a cheap agent returning a confident zero from a scan that could not have fired,
which reads exactly like a clean result and costs a whole phase to catch.

**Every delegated result is a HYPOTHESIS until re-derived.** Give the agent its control in
the prompt — name the token that must be present in the same invocation — and require it to
report both halves. An agent that reports an absence without a control has established that
its search ran, not that the thing is missing.

---

## Context

The graph consumer's sprint 305 is paused mid-gate-3 on story 2.1. The operator's report:
it started well and degraded; stalls during adversarial review cycles, a handoff the lead
did not execute, a pre-push artifact-path violation, and unacceptable time and token churn.

Every finding below was derived against the working trees with a control in the same
invocation. **Corpus:** 5 transcripts, `2026-08-22T03:20Z` → `2026-08-25T01:45Z`, ~70 h,
10.4 MB of conversation content, 27 compactions. Graph runs ai-dlc `0.403.0` (`895db006`).

### The regression question: NO, and it is measured

`git diff --stat 539062dc~1..HEAD -- core/` — the whole 0.396.0 → 0.403.0 band graph pulled
— touches `ledger-reverify.sh`, `layer-drift.sh`, `extensions/README.md`,
`layer-contract.yaml` (prose inside one clause; **no `contract_version` bump**) and three
fixtures. It touches no `SKILL.md`, no `steps/`, no `hooks/`, no `git-hooks/`, no
`scripts/`. Control: the same range whole-repo is 18 files / 1076 insertions, so the range
is non-empty.

Every root cause below predates the pull: **v0.81.0** (`8f4ea5e5`), **v0.118.0**
(`1941c9ed`), **v0.294.0** (`b9e81c3f`), or is design-level. What changed is not ai-dlc — it
is that s305 ran long enough and parallel enough for latent gaps to compound.

### The plan question: `graph-ledger-full-drain.md` covers none of it

Occurrences in that file: `wait-beat|wait-for-deliverable` **0**, `post-compact|re-read`
**0**, `rapid-fire|BACKOFF` **0**, `handoff` **0**, `party-mode` **0**, `readset` 2. Control
`ZZZNOSUCH` 0. The live backlog (63 entries) is the same. `BL-086` is the single partial
overlap and is discussed under RC-1.

---

## RC-1 — the consumer cannot push, for two independent reasons

**Reason A — a standing artifact-path RED that grew all sprint.**
`bash scripts/ai-dlc/validate-artifact-paths.sh --report` in graph:
`VERDICT: FAIL — 24 blocking, 3 ambiguous`. All 24 are
`_bmad-output/planning-artifacts/party-mode/s305/**`.

`BL-086` measured this same red at **6 blocking** during the 0.396→0.403 pull. It reached
**24** during s305 and no mechanism in the sprint noticed.

Root cause: **core prescribes no home for party-mode findings.** Declared areas
(`artifact-path-config.sh --areas`) include `_bmad-output/party-mode` and
`_bmad-output/planning-artifacts` — but not their concatenation, so an `s305/` component
there is a sprint token outside the reserved slot. Sprints 297, 298 and 303 used the legal
`_bmad-output/party-mode/s<N>/`. s305 is the first to use the illegal path
(`git log --diff-filter=A`, first add `af862b61d`). The only string in all of `core/`
resembling a party-mode findings directory is the parenthetical at
`core/skills/ai-dlc/SKILL.md:721` — 1 occurrence, against a control of 7 for
`party-mode-transcripts/s<N>`.

**I82 is blind to it by construction.** `--token-re-prescribed` is applied per path
component: `party-mode` → no token, `planning-artifacts` → no token, control `s<N>` →
TOKEN. The prose omits the sprint slot, so the violation exists only at expansion, where no
prose scanner looks.

**Reason B — the push is SIGKILLed before the hook finishes.** Timed in graph:
`bash .git/hooks/pre-push` = **2 m 30.52 s at 652 % CPU**. The Bash tool default timeout is
2 m 00 s. The transcript shows the consequence twice — `2026-08-24T13:19Z` ("timing out
resolving") and `2026-08-25T01:41:47Z` (`Exit code 143 | Command timed out after 2m 0s`).

The hook's own log names the cause: `no read-set map at .ai-dlc-fixture-readsets.tsv --
running all 155`. `core/git-hooks/pre-push:255` **reads** `READSET_MAP`;
`derive-fixture-readsets.sh` **is not in `core/scripts/`** and never has been
(`git log --all --diff-filter=A -- core/scripts/derive-fixture-readsets.sh` is empty;
control: `validate-artifact-paths.sh` is present there). v0.294.0 shipped the reader and
never the producer, so **every consumer runs all 155 fixtures on every push, permanently.**

### Remedy

1. **Give party-mode findings a prescribed home in core** (operator-selected),
   `_bmad-output/party-mode/s<N>/` — the path three prior sprints already used. Fix
   `SKILL.md:721` to name it. Single declaration, cited not restated. Graph's 24 s305 files
   migrate to it. **Closed sprints stay put**: s297/s298/s303 already conform.

   **ORDERING CONSTRAINT, and without it this phase fails its own gate.** The area is
   declared by the CONSUMER, not by core. `core/scripts/artifact-path-config.sh --areas`
   run in THIS repo returns 8 areas and `_bmad-output/party-mode` is not among them — the
   control `party-mode-transcripts` is, so the absence is real and not a broken read. The
   dev repo has no `.claude/skills/ai-dlc/artifact-paths.md` to join, so **I82 — "core's own
   artifact-path prescriptions obey core's own grammar" (`docs/invariant-index.md:101`) —
   would fail the push on the very prescription this item adds.** Add
   `_bmad-output/party-mode` to the `areas:` block of
   `core/skills/ai-dlc/artifact-path-grammar.md` in the same change, BEFORE the
   prescription, and re-run `--areas` with its control to confirm the set moved to 9.
2. **Close the I82 blindness with a derived join**, not a hand-list: a core prescription
   naming a directory under a scan root, which will receive a sprint slot at expansion, must
   be written with the slot (`.../s<N>/`) so the prose form carries a token I82 can read.
   Ship it only with its false-positive set measured and enumerated.
3. **Ship `derive-fixture-readsets.sh`** — `core/scripts/`, `install.sh` copy loop,
   `uninstall.sh`, both manifest copies — and have `core/git-hooks/pre-push` generate the
   map when absent rather than silently falling back to all-155.
4. **Graph-side remediation is a BRIEF, not a write.** Rehearse
   `migrate-artifact-paths.sh --apply` on a `file://` clone here, then hand the paused graph
   session the exact command list and the expected before/after verdict.

---

## RC-2 — the handoff request arrived on a channel no mechanism watches

At `2026-08-25T01:25:47Z` the lead asked an `AskUserQuestion` about a gate-3 Check 16
disposition. At `01:35:25Z` the operator answered **`"handoff"`**. The lead read the intent
correctly and then improvised — one `TaskStop`, a snapshot edit, `touch
pipeline-paused.flag` — without ever loading `steps/handoff.md` in that session. At
`01:38:21Z` the operator said so, and the lead confirmed at `01:42:08Z`: *"no full teammate
sweep, no commit, no push attempt, no bare resume line."*

Root cause: **`core/hooks/ai-dlc-pause.sh` is the only thing that routes a handoff request,
and it cannot see an AskUserQuestion answer.** Its `additionalContext` carries the three-way
branch including *"(c) Handoff request — follow Rule 2 handoff protocol"*. It fires on
`UserPromptSubmit`. An AskUserQuestion answer never raises that event — stated in
`core/hooks/ai-dlc-answer-capture.sh`'s own header. The continuation log confirms it: no
`USER_PAUSE` between `01:24:59Z` and `01:38:21Z`; the `01:36:15Z` `ALLOWED_BY_PAUSE` reads a
flag the lead created itself.

`ai-dlc-answer-capture.sh` does see the answer, and by design *"NEVER BLOCKS … stdout:
nothing"* — it records, it does not route.

Residual, still true after the corrected run: `_bmad-output/.driver/handoff` is dated
`Aug 21 18:13`, so step 4's driver signal was not touched.

### Remedy

1. **Route at the answer channel.** `ai-dlc-answer-capture.sh` is `PostToolUse` and may emit
   `additionalContext` without blocking. On an answer matching the handoff/pause intent
   vocabulary, emit the routing block, create the pause flag, and log `USER_PAUSE`.
   **Single-source the branch text and the vocabulary** — `ai-dlc-pause.sh`'s header
   explicitly forbids re-homing its list in a second copy, and the same discipline binds this.
2. **Make the handoff auditable.** A handoff commit must carry Step 1's stopped-teammate
   record in the snapshot. Extend `core/fixtures/handoff-resume-guard` with a mutant that
   dies only when the record is present.
3. **Fix step 4's driver signal** so the `touch` is not conditional prose the lead skips.

---

## RC-3 — the escalation path had two consecutive silent failure modes

The operator's standing instruction (`2026-08-22T14:45:51Z`): *"send all messages that need
operator attention/decisions to that session."*

- **`SendMessage → graph-6b` returned `No agent named 'graph-6b' reachable` 3×** —
  `08-24T19:25`, `08-24T22:38`, `08-25T01:25`, i.e. in each of the last three sessions. The
  channel the operator designated was dead and nothing recorded that.
- **The `AskUserQuestion` fallback was rejected 3×** with `Too small: expected array to have
  >=2 items`. Core states the two-option minimum **nowhere**: 53 `AskUserQuestion` mentions
  across 9 files in `core/`, 0 mentioning it.
- **A rejected ask leaves no artifact.** `operator-answers-history.md` records answers only.
  Two of the three rejections were followed by a compaction within ~3 minutes (`22:38:23` →
  compacted `22:41:02`; `00:01:51` at the boundary), so the undelivered decision went into a
  summary and the operator never saw it.
- Asks that did land had operator latencies of **1.9 h, 7.5 h and 11 h**.

### Remedy — COMPLETE, SHIPPED AS v0.407.0

**RC-3 shipped. This phase is closed and there is nothing here to execute.** Items 2 and 3
shipped; item 1 was dropped. The three filed items are kept at the end of this section under
their own heading. Nothing between here and that heading is superseded.

**What shipped.** `core/hooks/ai-dlc-escalation-delivery.sh`, `PostToolUse` on `SendMessage`,
logging `ESCALATION_UNDELIVERED` on a boolean `success:false`, with the recipient and the
harness message on the entry. The 2-4 option constraint is stated once in `SKILL.md`'s Rule 3
pause-point section and cited from the two step files.

**ITEM 1 WAS DROPPED, ON THE OPERATOR'S DECISION, AND THE REASON IS REUSABLE.** A `<2`-option
`AskUserQuestion` is rejected at INPUT VALIDATION — `InputValidationError`, `"code":"too_small"`,
`"minimum":2` — and the hooks documentation does not state whether hook dispatch runs before or
after that. `PostToolUseFailure` is documented as firing when a tool "started executing and
fails", which a schema-invalid call never did. **The hook could not be shown able to fire, and
this repo does not ship checks in that state.** It would also have duplicated a rejection the
lead already sees in-band; what s305 actually lost was the DECISION, to a compaction three
minutes later.

**Two premises in the evidence above were measured wrong.** "Core states the two-option minimum
NOWHERE" is false — `steps/_gate-procedures.md:302` stated it, gate-scoped, which is why it did
not reach the fallback ask. And the `success:false` population is not all escalations: of 18
real failures, 9 are a subagent failing to reach `parent` and 1 is a capability refusal.

**A trap worth carrying forward.** The sensor cannot be a tool-error flag. `is_error` is absent
on ALL EIGHTEEN measured failures — the harness treats an undelivered message as a successful
call returning a failure body. An arm keyed on the error flag reads clean over a corpus made
entirely of failures.

---

#### The filed remedy — items 2 and 3 shipped, item 1 dropped

Everything above this heading describes what actually shipped.

1. **Remove the affordance.** A `PreToolUse` deny on `AskUserQuestion` with any question
   carrying fewer than two options, returning the reason in-band so the lead repairs it
   instead of losing the decision. Log the event so a retro can count it.
2. **State the constraint once**, where the lead is told to use the tool, and cite it from
   the other sites rather than restating.
3. **Surface an undelivered escalation.** `PostToolUse` on `SendMessage` detecting
   `success:false`, appending an `ESCALATION_UNDELIVERED` event to the continuation log — a
   countable signal instead of a silent fall-through.

---

## RC-4 — the stall detector cannot fire, so no stall was ever confirmed

`core/hooks/ai-dlc-continue.sh`'s `ALLOWED_BY_LIVE_BEAT` path runs `rm -f "$STATE_FILE"`.
The next block therefore reads `LAST_TS=0`, so `DELTA = NOW - 0 ≈ 1.79e9`, always ≥
`RAPID_WINDOW_SECONDS`, so `COUNTER=1` — every time.

Measured in graph's `pipeline-continuation-log.md`, controls in the same invocation:
`BACKOFF` **0**, `HANDOFF_GUARD_BLOCK` **0**, impossible-event control **0**, against
`BLOCKED` **15** and `ALLOWED_BY_LIVE_BEAT` **240**. All 15 blocks read `rapid-fire 1/3`;
none ever reached 2. All 15 `Seconds since previous block` values are epoch-scale (min
`1787395192`) — an epoch printed as a delta, the visible symptom of the same bug.

Consequence, and it is the operator's reported symptom: **170 wait-beat arms and 16.7 h
inside join-wait loops**, while the one mechanism built to say *"this is a stall, investigate
the transcript"* fired zero times. Introduced v0.81.0.

### Remedy — COMPLETE, SHIPPED AS v0.406.0

**RC-4 SHIPPED. This phase is closed and there is nothing here to execute.** Two things
changed in `core/hooks/ai-dlc-continue.sh` and they are stated in the next paragraph.

**The three-numbered remedy that this section used to open with is NOT what shipped.** It was
built as a mutant, driven, and measured inert. It now sits at the END of this section under
its own heading, marked superseded, kept only so a reader can see which of its premises were
wrong. Nothing between here and that heading is superseded.

**What shipped.** The live-beat state wipe is DELETED — that path now
touches the block state not at all. **The clock is the progress signal**, so the counter needs
no separate reset: a beat that genuinely consumed time pushes `DELTA` past
`RAPID_WINDOW_SECONDS` and the pre-existing `else` branch resets the counter itself, while a
beat that returned instantly consumes no time and lets the counter climb. Item 2 shipped as
filed. The fixture is `core/fixtures/implementation-join-yield`, **9 → 14 assertions**.

**Premise 1, FALSE: "so `COUNTER=1` — every time."** True only where a state wipe precedes
every block. Four consecutive blocks with no intervening beat DO reach `BACKOFF` on the
unfixed hook, measured. The unreachable case is specifically the ALTERNATING one, which is
graph's.

**Premise 2, FALSE: the filed remedy item 1 is BEHAVIOURALLY INERT.** Zeroing the counter
makes the next block `0 + 1 = 1`, the identical value the epoch delta forced. Built as a
mutant and driven against the committed hook over four event sequences: the decision sequence
came back BYTE-IDENTICAL, only the printed delta moved. The shipped fixture kills that mutant
with the same two arms that kill the unfixed hook.

**Premise 3, FALSE: remedy item 3's arm as prescribed is VACUOUS.** "Interleaving live beats
with rapid blocks and asserting `BACKOFF` is reached" PASSES ON THE UNFIXED HOOK — one beat
followed by four blocks reaches `BACKOFF` today. The arm that discriminates holds the event
shape fixed and varies ONE thing, whether the beat CONSUMED TIME: alternating instant beats
must reach `BACKOFF`, the same sequence with beats that consumed time must stay silent.

**A fourth trap, met while writing the fixture and worth the line.** A bare token grep over
the flow log also matches the log's own legend, which names every event type — it put three
phantom `BACKOFF`s in front of every sequence and made the offender arm pass without the
detector firing. `core/hooks/ai-dlc-continue.sh` documents the correct grammar in the header
it writes: one event is one `## <timestamp> -- <EVENT>` line.

---

#### The filed remedy — SUPERSEDED, do not execute

Everything above this heading describes what actually shipped. The three items below are the
original prescription, kept verbatim as the record of what was measured wrong: item 1 is
inert, item 3's arm is vacuous, and only item 2 shipped as written.

1. **Stop deleting the timestamp.** Reset the COUNTER on a live beat; keep `LAST_TS`. A live
   beat is forward progress for the counter, not amnesia for the clock.
2. **Refuse to print an epoch as a delta** — report `first block` when `LAST_TS=0`.
3. **Prove it can fire.** A fixture arm interleaving live beats with rapid blocks and
   asserting `BACKOFF` is reached, plus a seeded near-miss that stays quiet. One direction
   alone leaves a scan that flags everything looking identical to one that discriminates.

**Reconnaissance already done against `core/hooks/ai-dlc-continue.sh` at `902197f2`, so the
next session starts from the sites rather than the search.** Re-derive before editing; the
file moves.

`MAX_RAPID_BLOCKS=3` at line 89, `RAPID_WINDOW_SECONDS=30` at line 88. There are FOUR
`rm -f "$STATE_FILE"` sites and only ONE of them is the defect:

- **line 507 — the subject.** Inside the `ALLOWED_BY_LIVE_BEAT` branch, under a comment that
  says it is resetting the rapid-fire COUNTER. It deletes the file, so it resets `LAST_TS`
  too, and the read block twenty lines below then starts from `LAST_TS=0`.
- line 458 — the pause-resume path, deliberate (`pause-resume cycle counts as progress`).
- line 467 — no snapshot, so no pipeline and no state to track.
- line 547 — inside the `BACKOFF` emitter itself, after the stall has been declared.

The read block is lines 515-526 (`LAST_TS=0`, `COUNTER=0`, then `sed -n '1p'`/`'2p'` off the
state file, then `DELTA=$((NOW - LAST_TS))`); the window test and counter are 528-534; the
`BACKOFF` branch is 539-548; the state write is 586-587; the epoch-as-a-delta print is line
598. The two fixtures already driving this hook's neighbourhood are
`core/fixtures/implementation-join-yield` and `core/fixtures/handoff-resume-guard` — check
whether the new arm belongs in one of those before creating a directory, because a NEW
fixture directory reads nothing and so cannot fire `.claude/rules/fixture-ship-decl.md`.

**The write at 586-587 is the shape the fix has to match**: line 1 is the timestamp, line 2
is the counter. Preserving `LAST_TS` while zeroing the counter means writing both, not
deleting the file — and at line 507 `LAST_TS` has not been read yet, so the fix either moves
the read above the live-beat branch or rewrites line 2 in place.

---

## RC-5 — the compaction / re-read loop is the token churn

Byte accounting over all 5 transcripts (10.4 MB total):

| category | MB | share |
|---|---|---|
| `Read` tool results (n=401, avg 13.4 KB) | 5.36 | 51.5 % |
| `SKILL.md` — 17 Reads + 22 skill-load injections | 1.59 | 15.3 % |
| `steps/*` — 86 reads | 1.26 | 12.1 % |
| `pipeline-snapshot.md` — 37 reads | 0.60 | 5.8 % |

**About a third of the entire sprint's context was ai-dlc re-reading its own instruction
surface.**

The loop: `SKILL.md` is 101,720 bytes; Claude Code re-attaches ~5,000 tokens after a
compaction; the `POST-COMPACT RECOVERY PROTOCOL` therefore mandates
`Read .claude/skills/ai-dlc/SKILL.md` **in full**, and Rule 22 mandates re-reading the
current step file — `gate-validation.md` is 150,835 bytes. Each compaction costs ~120 KB of
re-read, which brings the next compaction closer.

It shows in the cadence: **27 compactions**, 5 on Aug 22, 15 on Aug 24, and one every ~30
minutes in the final stretch (`21:23`, `21:52`, `22:04`, `22:41`, `00:01`, `00:30`). That is
the measured shape of "started well, degraded".

Corroborating waste: the party-mode invocation shape was re-derived from scratch four
separate times (`08-22T10:26`, `08-22T11:49`, `08-24T09:55`, `08-24T14:06`).

### Remedy — COMPLETE, SHIPPED AS v0.409.0

**RC-5 shipped. This phase is closed and there is nothing here to execute**, except that its
done-when is only PARTLY discharged — see the last paragraph, which is the one thing a later
session still owes.

**What shipped.** `core/skills/ai-dlc/postcompact-digest.md`, rendered by
`scripts/render-postcompact-digest.sh` and byte-compared at pre-push. The
`POST-COMPACT RECOVERY PROTOCOL` and `ai-dlc-recover.sh` both mandate the digest instead of
`SKILL.md` IN FULL; `validate-reattach-budget.sh`'s mandate arm re-anchors onto the digest
path AND the SKILL.md path, requiring both.

**THE DIGEST COULD NOT BE INJECTED, AND THAT DECIDED THE DESIGN.** The hook's block is bounded
by Claude Code's 10,000-character cliff and was already at 8,670 bytes, so a 20 KB digest was
never going into `additionalContext`. It is a FILE the block names. Anyone revisiting this
should start from that constraint rather than rediscovering it.

**It is a SELECTION of SKILL.md's own bytes, never a summary**, so it cannot say anything
SKILL.md does not and `--check` fails the push the moment SKILL.md moves. The selector takes
every heading past the measured 20,121-byte cut with its first paragraph and, where that
paragraph ends on a COLON, the block it announces.

**That colon clause is the whole faithfulness argument and it is not decorative.** Measured:
first-paragraph-only left THREE entries dangling, one of them Rule 23, rendered as *"Three
controls keep the resident set lean:"* with the three controls dropped — the one rule whose
absence causes the compaction that removed it. `--check` asserts zero dangling and reports 3
against the naive selector in the same invocation, so the arm discriminates.

**The digest is disclosed as an INDEX, and a fixture arm asserts the disclosure.** It
establishes that a rule EXISTS and what it governs, and is not enough to APPLY one; both the
hook and the protocol tell the lead to Read SKILL.md for the full text of any rule it acts on.
A lead that reads an entry and proceeds as though it read the rule has no signal it is missing
anything, which is a worse failure than the one this replaced — so it is not left to prose.

**A SECOND DEFECT WAS FOUND AND FIXED WHILE MEASURING THE FIRST.** The Pipeline Position
excerpt was included whole or dropped whole against a 9,000-byte ceiling, and measured, a
snapshot whose Position ran to its 1,200-byte cap lost it entirely — so `build yes` was
reachable only for a Position under ~230 bytes. It now fits the excerpt to the space left,
drawing on the range between the ceiling and the cliff and leaving a 500-byte reserve.
Verified across Position sections of 2, 10, 40 and 400 rows: the excerpt survives every one.

**THE DONE-WHEN IS NOT FULLY DISCHARGED AND CANNOT BE FROM THIS REPO.** It asks for a
re-measured Read-byte share **over a real post-compact sequence, not a projection**. That
sequence requires a CONSUMER running the new code through an actual compaction, which no run
here can produce. The −78% is a derived per-event figure taken from the two files on disk.
**Whoever delivers action 7 should carry this**: the brief is the first point at which the
consumer-side measurement becomes takeable, and RC-5 closes there or not at all.

---

## RC-6 — 134 transient scratch files are tracked in git

`git ls-files _bmad-output/.wait-beats/ | wc -l` = **134**; `git check-ignore -v` on that
path returns nothing. These are per-shell coordination files (`.shell-<pid>`, `<n>.since`,
`<n>.progress`) created and destroyed constantly — 5 of the 25 files in the handoff commit
`386a56d34` were wait-beat churn.

### Remedy — COMPLETE, SHIPPED AS v0.410.0

**The finding above is the filed one and it is NARROWER than what was measured.** 138 files
across three paths were tracked, not 134 across one, and ten further transient paths were
latent. The root cause is one level up from any of them: the distribution had NO ignore-rule
delivery path — `install.sh` carried zero references to `.gitignore` — so every transient path
the reference consumer ignored had been hand-added by that consumer, four of them across
roughly four hundred releases.

What shipped:

- `core/schemas/pipeline-state-paths.json` — a PARTITION, not a list. All 33 top-level names
  the shipped machinery constructs under the pipeline root, each classified transient or
  durable with its producer and a reason. Binding only the transient half would leave a new
  state path invisible until somebody spotted it in a diff, which is the same failure the
  hand-written list had.
- `core/scripts/sync-transient-ignore.sh` — renders the transient half into `.gitignore` as a
  marker-bounded block, idempotent by cut-then-append, with a `--check` mode that fails on a
  block that is present and stale. **It is a shipped script and not installer code for a
  DELIVERY reason**: an existing consumer arrives through `ai-dlc-update`, whose `apply.sh`
  copies core files by a derived mapping, so an inline renderer would have delivered the
  declaration to every consumer and the code that renders it to none — leaving the consumers
  that already have committed transient state as the only ones it could never reach.
- **I95** in `scripts/validate-enforcement-map.sh`, four arms, both join directions.
- `core/fixtures/transient-ignore-block/` — shipping, 7 arms and 3 mutants.

**A blanket `_bmad-output/.*` glob was measured and REJECTED.** One line, covers every future
dot-prefixed path for free, and wrong: the reference consumer tracks
`_bmad-output/.audit-accepted-exceptions`, a deliberate committed file with zero references in
`core/` (control: 31 for `audit-anchors`). A glob shipped from the distribution silently
untracks consumer-owned dot-entries no declaration here can enumerate.

**Untracking is NOT done and cannot be done from here.** An ignore rule has no effect on a
tracked file. The renderer names the still-tracked paths and prints the `git rm -r --cached`
command; running it belongs to the brief in action 7, never to a write into the consumer.

---

## Verification

- Every arm ships with a two-direction self-probe under `mktemp` that runs BEFORE the
  corpus — a seeded offender reported, a seeded near-miss silent.
- Gate the way the hook runs it: `AI_DLC_FIXTURE_NO_SKIP=1 bash .githooks/pre-push`, read
  the **gate's** own exit, tabulate every `── phase` header against PASS/FAIL, and read each
  changed fixture BY NAME against an impossible-name control in the same invocation. This
  shell has no `PIPESTATUS`, so never read a push's exit through a pipe.
- RC-1 closes when a scratch install built by `scripts/install.sh` into an empty directory
  produces a readset map and a pre-push under the two-minute bound, measured, in both layouts.
- RC-4 closes when `BACKOFF` is observed firing in a fixture that interleaves live beats with
  rapid blocks.
- RC-5 closes on a re-measured Read-byte share taken over a real post-compact sequence, not a
  projection.
- The consumer ledger md5 is re-checked at every phase boundary and must still read
  `a8f61789e1c947a8251eef9b4cb7c098`.
