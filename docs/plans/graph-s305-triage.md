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
echo "P2  live-beat keeps LAST_TS  $([ "$lb" -eq 0 ] && echo DONE || echo TODO)"
echo "P3  escalation guards        $(v "$(grep -ciF 'escalation_undelivered' CHANGELOG.md)")"
echo "P4  answer-capture routes    $(v "$(grep -cF 'additionalContext' core/hooks/ai-dlc-answer-capture.sh)")"
echo "P5  full re-read mandate     $([ "$(grep -cF 'IN FULL' core/skills/ai-dlc/SKILL.md)" -eq 0 ] && echo DONE || echo TODO)"
echo "P6  wait-beats ignore        $(v "$(grep -rlF 'wait-beats' templates/ scripts/install.sh 2>/dev/null | wc -l)")"
echo "P7  consumer brief filed     $(v "$(ls docs/reviews/ 2>/dev/null | grep -c s305)")"
echo "CTL must be DONE             $([ -d core ] && echo DONE || echo TODO)"
echo "CTL must be TODO             $([ -e core/NO-SUCH-CONTROL.sh ] && echo DONE || echo TODO)"
```

**P1a, P1b and P1c read DONE; P2 through P7 read TODO; the controls read DONE then TODO.**
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

**Phase 1 (RC-1) is DONE, shipped as v0.404.0 (`fe64a47a`), merged to `main` and pushed.
Phases 2 through 7 are open. Start at NEXT ACTION 2.** The gate ran green on it —
`AI_DLC_FIXTURE_NO_SKIP=1 bash .githooks/pre-push`, gate exit 0, 0 FAIL lines, 163 fixtures
ok, `readset-skip`, `artifact-path-conformance` and `validator-fork-budget` read by name
against an impossible-name control of 0.

**Tree state at handoff (`902197f2`):** on `main`, clean, level with `origin/main`, `VERSION`
`0.404.0`. Consumer ledger re-checked at the phase boundary and unchanged at
`a8f61789e1c947a8251eef9b4cb7c098`; nothing in `/Users/n8/git/graph` was written — its three
dirty paths (`.context-sensor-state`, `.driver/turns`, `pipeline-continuation-log.md`) belong
to its own paused session and were dirty before this work began. Phase 2's reconnaissance is
filed under RC-4's remedy, so that phase starts at the sites rather than the search.

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

**Run the probe block first and execute the LOWEST-NUMBERED phase reading `TODO`.** The
sprint cannot safely resume until the consumer can push, which is why RC-1 is phase 1.

1. **RC-1 — unblock the consumer's push.** **Declare `_bmad-output/party-mode` in core's
   own `areas:` block FIRST** (`core/skills/ai-dlc/artifact-path-grammar.md`) — see the
   ordering constraint in RC-1's remedy; then prescribe the findings home at
   `_bmad-output/party-mode/s<N>/`; fix `core/skills/ai-dlc/SKILL.md:721`; close the I82
   prescription blindness with a derived join; ship `derive-fixture-readsets.sh` into
   `core/scripts/`, `install.sh`, `uninstall.sh` and both manifest copies, and make
   `core/git-hooks/pre-push` generate the map rather than fall back to all-155.
2. **RC-4 — make the stall detector able to fire.** Stop `rm -f "$STATE_FILE"` on the
   live-beat path; reset the COUNTER and keep `LAST_TS`. Refuse to print an epoch as a
   delta. Add the fixture arm that proves `BACKOFF` is reachable.
3. **RC-3 — the two escalation guards.** A `PreToolUse` deny on an `AskUserQuestion`
   carrying a question with fewer than two options, and a `PostToolUse` on `SendMessage`
   that logs `ESCALATION_UNDELIVERED` on `success:false`.
4. **RC-2 — route a handoff arriving as an answer.** Extend `ai-dlc-answer-capture.sh` to
   emit the routing block, create the pause flag and log `USER_PAUSE` on a handoff-intent
   answer, single-sourcing the vocabulary and the branch text from `ai-dlc-pause.sh`.
   Extend `core/fixtures/handoff-resume-guard` to require Step 1's stopped-teammate record.
   Fix step 4's driver signal.
5. **RC-5 — cut the post-compact re-read loop.** Extend `ai-dlc-recover.sh` to RENDER the
   rules and step-position digest that live past Claude Code's re-attach cut, and rewrite
   the `POST-COMPACT RECOVERY PROTOCOL` to cite the injected block instead of mandating a
   full `SKILL.md` Read.
6. **RC-6 — ship the ignore rule** for `_bmad-output/.wait-beats/`.
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

   **The brief must also carry the TIMEOUT.** Measured on that clone with per-line
   timestamps: the pre-push is 148.9s, of which every phase before the fixture suite is
   18.0s and the suite is 130.9s. The suite is pole-bound — 155 fixtures, 1006
   fixture-seconds, longest single fixture `layer-reference-resolution` at 119s — so even a
   perfect read-set map cannot put a change that selects the pole under a 120s caller
   timeout. Tell that session to push with an explicit long timeout, and separately to
   build the map once with `sudo bash scripts/ai-dlc/derive-fixture-readsets.sh --all`.

### Done when

All nine probes read `DONE`, the consumer's `validate-artifact-paths.sh` reports 0 blocking,
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

### Remedy

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

### Remedy

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

### Remedy — operator-selected: extend `ai-dlc-recover.sh`

`core/hooks/ai-dlc-recover.sh` already injects 8,944 bytes on every compaction. **Extend it
to RENDER the rules and step-position digest that live past the re-attach cut**, so the
mandated full `SKILL.md` Read stops being necessary, and rewrite the protocol to cite the
injected block.

This is the repo's own "render safety-critical output; do not let a model retype it"
pattern: the digest is generated into a marked region and `--check` byte-compared at the
gate, so it cannot drift from `SKILL.md`. Sharding `SKILL.md` and `gate-validation.md` is
explicitly NOT in this scope.

Measure before and after on the same corpus. The figure is a **re-read count and byte
total**, never a token estimate.

---

## RC-6 — 134 transient scratch files are tracked in git

`git ls-files _bmad-output/.wait-beats/ | wc -l` = **134**; `git check-ignore -v` on that
path returns nothing. These are per-shell coordination files (`.shell-<pid>`, `<n>.since`,
`<n>.progress`) created and destroyed constantly — 5 of the 25 files in the handoff commit
`386a56d34` were wait-beat churn.

### Remedy

Ship the ignore rule in the distribution; untrack in graph via the brief (RC-1 item 4),
never by writing to the consumer from here.

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
