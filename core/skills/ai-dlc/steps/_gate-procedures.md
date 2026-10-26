---
name: _gate-procedures
description: Procedures invoked by reference from pipeline step files (sub-step snapshot update, bounded-join beat, auto-handoff evaluation) — extracted from gate-validation.md so their bodies stay out of the resident gate path and load only at their invocation seam
---
<!-- STEP_LOADED_TOKEN: gate-procedures -->

# Gate Procedures (invoked by reference)

These procedures are invoked **by name** from pipeline step files — they are
NOT gate checks and are NOT part of the `gate-validation.md` Check 1–H2
sequence. A step file loads this file `READ AND FOLLOW`-style when it says
"run sub-step snapshot update" or "run auto-handoff evaluation at Seam <X>".
`gate-validation.md` carries a one-line forwarding pointer at each procedure's
former location.

## Sub-step snapshot update (referenced by step files)

Step files invoke this lightweight update after each validation
sub-skill and after each story transition during implementation.
Gate passages still run the full Check 14 in `gate-validation.md`;
sub-step updates are narrower in scope.

When a step file says "run sub-step snapshot update", execute:

1. Append a one-line entry to **Recent Activity** naming the
   sub-skill completed or transition observed, with timestamp and
   artifact touched (e.g., `2026-04-17T15:22Z — /bmad-party-mode
   completed on PRD — _bmad-output/planning-artifacts/prd.md`).
2. Refresh **Open Items** from current state of
   `docs/escalations/pending.md` and any open triage items. Keep any
   `fan-out round <subject> since <epoch>` line until that round's join has
   completed (Rule 28, "Split dispatch").
3. Reconcile **In-Flight Teammates**: add a row for every teammate
   dispatched since the last update (`agent name | role | deliverable
   path | dispatched-at | status`, `status: in-flight`) — the deliverable
   path is COPIED FROM THE BRIEF, which Rule 20 requires to name it, never
   invented here to fill the cell, and `dispatched-at` is the output of
   `scripts/ai-dlc/wait-for-deliverable.sh --dispatch-ts <agentId>` (the
   timestamp of the dispatch's spawn-ledger row), never a clock reading.
   When a deliverable is consumed, set that row's `status` to `delivered-reachable` if the teammate is still alive and
   you may message it again, and **DELETE** the row outright once you will not.
   The one exception is a teammate STOPPED before it delivered: `steps/handoff.md`
   step 1 sets its `status` to `stopped` and KEEPS the row, because a successor
   session cannot tell a deleted row from a teammate that never existed. Do not
   delete a `stopped` row at the gate that WRITES it. **Its reader is the
   successor session, and that session discharges it**: `route.md`'s resume
   sequence deletes `stopped` rows at its first snapshot write after the resume,
   once what they record has been carried into Recent Activity or Open Items.
   A `stopped` row surviving past the resume that read it is not history, it is
   an unbounded section — this one has overrun its byte budget before, which is
   why the `inflight-row-shape` fixture exists.
   Rows only — no prose, no struck-through history; `status` is how a row
   says it has delivered. This section must be written **at
   dispatch**, not only at the transition that follows it — a teammate
   dispatched and compacted-over before its row is written is exactly the
   teammate the lead will re-dispatch blind.
4. Do NOT refresh other sections (Pipeline Position, Sprint Context,
   Locked Decisions remain gate-scope). Do NOT re-evaluate context
   reminder thresholds here — reminder evaluation stays at gate
   boundaries per `gate-validation.md` Check 14.
5. Run the snapshot budget check:

       scripts/ai-dlc/verdict.sh validate-artifact-budget --only pipeline-snapshot.md

   The script reports an overage inside the grace band (a `warn` line,
   exit 0) and breaches only past it.

   - **Exit 1 naming a stamp later than the current UTC time → apply the
     stamp remedy the verdict line prints FIRST, before any TRIM NOW or
     MOVE IT NOW below**, without asking: rewrite each `FUTURE` stamp to
     `date -u` in place, keep line order, add the one `CLOCK CORRECTION`
     line it spells, and re-run. Never clear this verdict by moving the
     future lines to `pipeline-snapshot-history.md`; that hides the stamp
     instead of correcting it.
   - `warn` (over budget, within grace) → note it and continue.
   - **Do NOT add `--warn-only` to this invocation.** It is `retro.md`'s
     sprint-end posture, where blocking helps nobody because the sprint is
     over. Here the sprint is running and the snapshot is still growing,
     which is the only reason this check sits between gates at all. The flag
     turns the one mechanism that catches growth *while it happens* into a
     log line.
   - **Exit 1 (past the grace band) → TRIM NOW, before the next
     sub-step.** Move superseded narrative verbatim to
     `pipeline-snapshot-history.md` (write-only), then run
     `bash scripts/ai-dlc/rotate-snapshot-archive.sh _bmad-output/pipeline-snapshot-history.md --apply`,
     re-run the budget check, then continue. On a non-zero exit from the
     rotator, read its stderr and fix what it names before re-running. The rotate is here and not at
     retro because this is the site that FEEDS the history: it fires
     between gates, all sprint, which is exactly the cadence nothing was
     bounding.
   - **Exit 1 naming a section outside the seven-section schema → MOVE IT
     NOW**, same destination, same "before the next sub-step." This is the
     verdict that matters here rather than at the gate: invented sections
     accumulate BETWEEN gates, which is the only place they can, and by the
     time bytes breach they are already load-bearing in the lead's head.

   Do NOT defer the trim to a later pause. The gate (Check 14) remains
   the blocking point.

   Call it through `verdict.sh`, which prints one line and **exits with
   the validator's own status**. Do NOT hand-roll
   `validate-… | grep -E 'OVER|PASS'`: a pipe hands the exit status to
   `grep`, so a validator that prints FAIL and exits 1 reads as a pass.

This keeps mid-step compaction survivable: the snapshot's Recent
Activity reflects the in-flight sub-step rather than only the last
gate, and In-Flight Teammates carries the deliverable paths that let
the lead re-join its teammates instead of re-dispatching them.

The budget is checked here, not only at gates. The full Check 14 still
runs at the next gate.

## Bounded-join beat (referenced by step files)

When a step file says "join the deliverable", execute this. It is Rule 29's bounded file-wait beat, and it is the ONLY sanctioned way to wait for a teammate.

**The handle.** An `Agent` spawn returns an `agent_id`. `TaskOutput` joins a `task_id`, which only `TaskCreate`
produces — **`TaskOutput` cannot join an `Agent`**, and a `Skill` spawn returns no handle at all. Every ai-dlc
teammate delivers by file (Rule 20): **the deliverable file IS the handle.**

**The call.** One `Bash` call, `run_in_background: true`, every path in the wave:

    scripts/ai-dlc/wait-for-deliverable.sh [--since <epoch|ISO8601>] [--dispatch <agentId> ...] <path> [<path> ...]

**`run_in_background: true` is part of the call, not a preference.** A foreground
beat is a dead beat: its exit trap clears the in-flight marker before your turn ends, so the join you believe is armed is not, and the turn-end hook reports no
live wait over a teammate that has not delivered.

**A teammate's markdown result file is closed by `--mark` and joined `--complete`.** Every brief naming one as its
deliverable ends with ONE line, rendered here and copied, never retyped:
`<lead engine>/wait-for-deliverable.sh --mark <file> <step> <role> <shard> findings=<n>`. `<lead engine>` is the
lead checkout's `scripts/ai-dlc` path the brief carries for a worktree-isolated teammate, else `scripts/ai-dlc`. That
brief also carries `<deliverable>`, the absolute path of the file inside the teammate's OWN worktree and never under
its `_bmad-output/planning-artifacts/`; `<file>` is that path, and the beat watches it. `<shard>` is `none` for a
non-shard dispatch. A non-review file passes `findings=0` with `<role>` its role (`dev`, `ops`, `qa`): only the shard
merges check `findings=` against parsed findings, and `join-remediator-shards.sh` and `content-seal.sh` read term 3
as a role. Out of scope: JSON and JSONL (the adjudicator's `.verdict.json`, `gate-adjudication/*.part-*.jsonl`),
analyst artifacts, and repair records — the remediator's, which keep `--complete-repair`, and the ops repair record.

**The join keys on the dispatch, not on the brief you meant to send.** Read the dispatch's spawn-ledger row by the
Agent result's `agentId`: `jq -r --arg t "$(jq -r .toolUseId ~/.claude/projects/*/"$CLAUDE_CODE_SESSION_ID"/subagents/agent-<agentId>.meta.json)" 'select(.tool_use_id == $t) | .mark // "bare"' "${AI_DLC_STATE_DIR:-_bmad-output}/spawn-ledger.jsonl"`
(a named `<name>@<team>` teammate: select on `.name == "<name>"`). Any output but `rendered`, empty too, is `bare`. The
guard writes `"mark":"rendered"` only when every `--mark` line in the brief is well-formed. `rendered`: one call,
`scripts/ai-dlc/wait-for-deliverable.sh --complete --dispatch <agentId> <path>`; `bare`: the plain call above. The row decides
only a non-shard teammate's result file: seat, shard, cross and repair-part files keep `--complete` (`--complete-repair` where that is their form), as do epic part files, regardless of the row.

- `exit 0` — beat complete. Read the output: consume the `DELIVERED <path>` lines, beat again over the `WAITING <path>`
  ones. Exit 0 alone does not mean all landed. **Delivered means non-empty AND written since the join armed**, not
  merely present: a path reused across sprints otherwise hands back the PREVIOUS sprint's file in under a second.
- `exit 1` — Rule 20 non-delivery. Re-dispatch, then HARD_BLOCK — for a path the beat reports `absent`, unless the beat
  prints `LIVE DISPATCH` or `STOPPED DISPATCH`, in which case read that agent's transcript first, as the block says.
  Under `--complete`, `UNFINISHED <path>` (present, last non-blank line is not `seat-complete:`, or its `sha=` no longer
  matches) and `UNSETTLED <path>` (marked with no `sha=`, still changing) are NOT absent, on a waiting beat or an
  exhausted one: read the file before deciding, never re-dispatch over it unread — that discards the teammate's findings.
- **A waiting beat exits 0 on purpose.** A nonzero exit from a backgrounded command reaches you as `status: failed`,
  a false failure on every healthy join that buries the one exit code needing a decision. Nonzero means non-delivery
  (1) or a refused call that armed nothing (64).

**A missing completion report is not non-delivery.** When a teammate's completion report is missing from your context, which happens when the opt-in wake hook suppressed its hand-back, read the deliverable and `_bmad-output/.subagent-final/<agent_id>.txt` before treating it as non-delivery or re-dispatching.

**`--since` is optional and only ever needed when the teammate may have delivered BEFORE you armed the join** —
normally when resuming a join after a compaction. Pass the row's `dispatched-at` value (defined above) with
`--dispatch <agentId>`, the `agentId` (or a named teammate's `agent_id`) the Agent result returned: the beat reads the
dispatch's time from the spawn ledger and refuses a `--since` later than it, which a hand-stamped row can be. It only
moves the threshold earlier; a stamp later than now is clamped, a stamp after the dispatch is not: pass `--dispatch`.
**Pass the whole wave to ONE call.** Never chain beats in a single `Bash` call. **Never hand-roll the wait.**
`until [ -s <path> ]; do sleep 15; done`, `while [ ! -s <path> ]; ...`, and any bare `sleep` on a deliverable are
**Rule 29 Check A violations**; gate Check 25 counts them. Do not poll a subagent's raw output file under
`/private/tmp/.../tasks/<agent-id>` — the deliverable path in the snapshot's In-Flight Teammates row is the handle.

## Gate-adjudication dispatch (referenced by the gate)

When `gate-validation.md` says "dispatch the gate-adjudicator", execute this. It escalates
the read-and-compare (`adjudication: llm`) checks of ONE gate to a fresh Opus subagent so the
lead can run on a cheaper model without weakening the gate. The lead still owns PASS/FAIL: it
adopts the verdict only through Check 26.

**Script arms before the adjudicator.** Nothing is dispatched until the script checks pass.
At gate entry the lead first runs every `adjudication: script` check and the script arm of
every `adjudication: llm` check whose enforcement-map entry carries an `enforcer:`. A FAIL
there is repaired through `gate-validation.md` **Gate Failure** before any nonce exists, so
no adjudicator is running while the repair happens. Only once those pass does the lead mint
the nonce and dispatch. A script FAIL discovered after a dispatch costs a second full
adjudication, because there is no partial re-adjudication to fall back on.

**At gate entry, generate the nonce** — `<gate_type>-$(date -u +%Y%m%dT%H%M%SZ)`, e.g.
`implementation-20260715T140322Z` — and derive the verdict path:

    ${AI_DLC_STATE_DIR:-_bmad-output}/gate-adjudication/<gate_nonce>.verdict.json

The nonce makes a stale verdict live at a different path: the bounded-join cannot find a prior
gate's verdict, and Check 26 refuses one whose `gate_nonce` field is not this path's stem. That
closes the "absent verdict reads as pass" hole.

**Dispatch** ONE `gate-adjudicator` (or N worklist shards, "Shard the worklist" below), `Agent` tool, `run_in_background: true` (Rule 29 — it must
not block the operator), bound to `.claude/team-roles/gate-adjudicator.md` per SKILL.md Rule 19
(both bindings: `model` and the standing role-contract Read line). Give it: the `gate_type`, the
`gate_nonce`, the `gate_series_id` decided by the same-series rule in `gate-validation.md` "At gate entry", the verdict output path, and the artifact roots it may read. When the gate is dispatched for exactly one story, the brief also carries a `story: <story-index>` line naming it, the only source of the series id's slug; a gate dispatched over several stories, or over none, carries no `story:` line. It derives its own
worklist with `scripts/ai-dlc/validate-gate-adjudication.sh --expected <gate_type>` (the SAME derivation
Check 26 uses), reads each escalated check's body in `gate-validation.md` as the spec, and writes
one `GATE_ADJUDICATION_VERDICT v1` JSON to the verdict path. No Skill, no provenance block — it is
the native path with its own schema. Before returning that path it runs
`scripts/ai-dlc/validate-gate-adjudication.sh --coverage <gate_type> <verdict_path>` on the file it
just wrote — its own role file governs what a non-zero exit obliges it to do, and that mode decides
nothing about the gate.

**Shard the worklist (Rule 28, "Split dispatch": worklist-items axis).** When `--expected
<gate_type>` prints more than one check, dispatch N `gate-adjudicator` shards in waves
(Rule 28, "Split dispatch") instead of one, with N no greater than that count (`--shard` refuses a larger N). All N share this
ONE `gate_nonce`. Each shard derives its own slice with
`scripts/ai-dlc/validate-gate-adjudication.sh --expected <gate_type> --shard <i>/<N>` and writes
`<gate_nonce>.part-<i>of<N>.jsonl` beside the verdict path, never a `.json` (`--series` walks
that directory and refuses any `.json` that is not a verdict). Its brief carries
`shard: <i>/<N> <gate_type>`, the gate's `story: <story-index>` line when it has one, and the one `gate_series_id` every shard of this dispatch stamps, since `--merge` refuses parts that disagree on it. Dispatch the shards right after minting the nonce: a merged verdict
is written by the validator, gets no verdict-write ledger row, and binds only through a
`gate-adjudicator` spawn-ledger row within 900s of the nonce. The join is the program: beat-join
every part path, then run
`scripts/ai-dlc/validate-gate-adjudication.sh --merge <gate_type> <verdict_path> <part>...`,
which refuses (exit 2, `REFUSED:`, nothing written) unless the parts are exactly this nonce's
1..N, no check_id appears twice, and their union equals `--expected`; it then writes the one v1
verdict and runs the coverage arms on it. Check 26 reads that file as it reads an unsharded one.

**A re-dispatch is a whole new dispatch.** The escalation preamble at the top of
`gate-validation.md` governs: a fresh `gate_nonce`, every escalated check re-derived from current
state, and no verdict carried forward, cited or merged from a superseded dispatch. The
`gate_series_id` is exempt: the same-series rule decides it at dispatch, never `close`. There is no
partial or targeted re-adjudication, and a verdict file assembled by hand is not a dispatch's
verdict. `scripts/ai-dlc/validate-gate-adjudication.sh` is what makes that binding rather than
advisory: it refuses any verdict whose covered set differs from the escalated set (the schema's
`coverage_exact` rule), so a verdict covering only the checks that failed cannot be adopted.
`--merge` joins the parts of ONE dispatch under ONE nonce, and it is not a carry-forward. Re-dispatching a
single shard that did not deliver, under the same nonce, same `<i>/<N>` and same slice, is
non-delivery handling and not re-adjudication; the shards dispatched at minting already carry
the binding.

**Join** with the bounded-join beat (above): `scripts/ai-dlc/wait-for-deliverable.sh <verdict_path>`
(sharded: every `<part>` path, then `--merge`).

**While it runs, the lead evaluates ONLY the remaining `project` / `lead` checks** — the
`script` checks ran before the dispatch and are already decided.
Inline-evaluating an `adjudication: llm` check is a Rule 20 solo violation — that judgment is the
adjudicator's, adopted at Check 26.

## Validation cycle (referenced by step files)

When a step file says "run the validation cycle", execute this — the Rule 8
convergence loop a planning step runs over its artifact. The step supplies the
PARAMETERS (party-mode seats + subject, adversarial focus, the `Seam D` label,
the artifact to changelog, and any source-fidelity check); everything here is the
same for every step, so it lives here and not restated in each step file.

**What the adversary and remediator DO is not restated in step files.** The
severity ladder, the verdict envelope, `EXIT_CONDITION_MET` /
`EXIT_CONDITION_NOT_MET` / `DIVERGENT_HARD_BLOCK`, the prior-scope discipline, and
the underived-claim bar all live in `team-roles/adversary.md` and
`team-roles/remediator.md`, and the gate enforces them mechanically
(`scripts/ai-dlc/validate-adversarial-convergence.sh`, invoked by Check 24). A copy in a
step file is a copy that drifts.

**Join every spawn on its DELIVERABLE** — one `scripts/ai-dlc/wait-for-deliverable.sh
<path> [<path> ...]` call per wave, `run_in_background: true` ("Bounded-join beat"
above). A hand-rolled `until`/`while`/`sleep` wait is a Rule 29 Check A violation that
gate Check 25 counts. SKILL.md Rule 32 touchpoint P applies on a pass's `beat 2/` WAITING
line, and touchpoint V2 wherever a pass verdict and a validator disagree.

**Intensity.** Run the minimum cycle SKILL.md Rule 8's intensity table names for
the declared `validation_intensity` — read that row; a copy here drifts. A
`lightweight` single pass is still a CONVERGENCE pass: it stamps a `verdict:` and
Check 24 reads it.

Execute the sub-skills back-to-back, with no pause for human input between them:

1. `/bmad-party-mode --mode subagent --non-interactive` — the step's seats (bound
   via the Rule 20 role-manifest preamble to their `.claude/team-roles/<role>.md`)
   walk the step's subject and record findings; run the step's source-fidelity check if it
   names one.

   **Minimum mechanism (Rule 26(c)).** Failure caught: a capital-path or address defect in
   first-authored text that no later round raises, such as a partial request rebalancing a whole
   position, a sweep re-minting a withheld remainder, or a lowercase address that crash-loops a
   live process at load. False-positive cost: one seat agent per (seat, part) and the party
   repair. Removal condition: measured sprints in which this round carries no unique MAJOR or
   CRITICAL catch that survives to the shipped artifact.

   **The seats edit nothing, in every case below.** Several seats walking one subject would
   each write it in place at once, and nothing attributes or orders those writes, so a lost
   update between two seats is invisible. Each seat writes one findings file per (seat, shard)
   — its deliverable, named below — and every finding in it opens a `##` heading whose first
   token is the finding's id (`## F-1 (major) sections: 2`), carrying one `sections:` line
   citing the map ordinals it rests on. Ids collide across seats, so a finding is named by its
   file and its id together. That `##` form is the SEAT grammar only: an adversary or
   elicitation shard writes each finding as a `### ` heading inside `## Findings` with an
   UPPERCASE severity word (FINDING GRAMMAR, `merge-adversarial-shards.sh`'s header), and the
   merge refuses a shard whose finding opens with `## `.

   **Every seat writes its file early and closes it with a completion line.** Its brief tells
   it to Write the file's header first, append each finding as soon as it is verified, and,
   when it has finished and only then, close it with ONE Bash call,
   `<lead engine>/wait-for-deliverable.sh --mark <file> <step> <seat> <shard> findings=<n>`,
   which appends `seat-complete: <step> <seat> <shard> key=<k> sha=<hex> findings=<n>` (`key=<k>` on a review shard only), where `<shard>`
   is the brief's `shard:` value (for a review shard, the shard's own key: the file basename
   without `.md`; for a repair part under `shards/<dir>-repair[-p<M>]/`, any words: `--mark` ignores `<step> <seat> <shard>` and writes `<dir>` without its `-repair[-p<M>]` suffix, `remediator` and the part's file name from the path), `<n>` the number of findings in the file, and `sha=` the digest
   of every line above the marker. A code-review or QA shard checks itself first with
   `scripts/ai-dlc/merge-review-shards.sh <shard dir> --gate <gate> --check-shard <shard file>`
   until SHARD-OK; `--mark` runs the same check and refuses a shard that fails it. After a
   refused merge the lead re-dispatches each seat that every REFUSED line's `[owner: <key>]` names with
   every line naming it verbatim, and never edits or re-marks a reviewer's shard. The marker is never written with the header, nor by hand. A seat dispatched worktree-isolated (a dev) carries `<lead engine>`, the absolute path of the LEAD checkout's `scripts/ai-dlc`, in its brief and runs `--mark` from it, never from its worktree, and its brief also carries `<deliverable>`, the seat file's absolute path inside its OWN worktree and never under its `_bmad-output/planning-artifacts/`, which is the `<file>` it marks and the path the beat watches; a seat that runs in the primary tree (the adversary never runs worktree-isolated) uses `scripts/ai-dlc` there, which is the lead's engine.
   Every adversary shard brief — part or cross, in item 2 and in "Adversarial
   review dispatch" — carries the same instruction with the adversary in place of the seat.
   Every beat that joins such a file passes `--complete` (`wait-for-deliverable.sh`, its
   header): the file counts as DELIVERED only when that line is last — outside any fence, with
   no carriage return — and its `sha=` matches the content above it, with no window; a file
   edited after its marker reads UNFINISHED until the seat runs `--mark` again. A marker with no
   `sha=` (a seat briefed before this release) is judged as before, by the settle window
   (`AI_DLC_WAIT_SETTLE_SECS`, default 180s, measured from a cross seat's real edit gaps). So a file written
   early is never taken as finished, a seat editing above its marker is not either, and a seat
   still appending shows as progress on its own file rather than as silence. The beat reads the marker only; `merge-adversarial-shards.sh` and
   `merge-review-shards.sh` check `findings=<n>` against the findings they parse and refuse a
   shard that disagrees. A code review or QA over `partition-review-diff.sh --map` dispatches
   its cross shards in the same wave as its parts, and its first cross shard arms its own
   `--complete --since <round epoch>` beat on the part files, under a state directory its brief
   names, before the hand-over replays (`implementation.md`, Gate-1 and Gate-2 dispatch). A party round's seat files are read by the lead and by
   `join-remediator-shards.sh`, which refuses a repair citing an unmarked seat file beside a
   marked one but does not check the count, so on that axis the marker's count has no
   mechanical reader. `--complete` and `--progress-path` never go on the same beat.

   **One repair writer applies them.** After the round's join the lead dispatches the seats'
   findings to remediators, never back to a seat, and every entry of the party repair record
   — a joined part, the serial remediator's appended entries, or a single writer's record —
   carries `source: <seat-file>#<finding-id>`, one token per seat finding the edit applies
   (`- source: architecture-dev-3.md#F-1 architecture-tea-3.md#F-1`). The join resolves each
   token against `_bmad-output/party-mode/s<N>/` on the (file, id) pair and refuses an entry
   with no `source:`, a token naming no seat file of the sprint, and a token whose file carries
   no finding of that id. Seats x parts is repaired as "Adversarial repair dispatch" "Shard by
   file" does, with `--artifact <artifact>-party --pass 1`, the shard dir
   `_bmad-output/planning-artifacts/s<N>/shards/<artifact>-party-repair-p1/` and the joined
   record `_bmad-output/planning-artifacts/s<N>/<artifact>-party-repair-p1.md`. Seats x
   sections is repaired as "Shard by section" does, split into that same shard dir with
   `--expect-sha` the sha256 the lead recorded for the document before wave 1, and joined with
   `join-remediator-shards.sh --document <doc> <that dir>`. The requirements subject case is
   below. A finding citing two or more parts goes to the serial remediator after the join, whose
   brief carries `shard: none (authoring-chain)`, and
   the lead then runs `scripts/ai-dlc/join-remediator-shards.sh --sources <the joined record> --sprint <N>`
   over the record with its appended entries, adding `--sources <its -serial-repair record>` after it
   when the serial work ran in lanes. The remediator brief also carries `revised-seats:`:
   after the round's join the lead runs `scripts/ai-dlc/wait-for-deliverable.sh --complete --status
   --since <the round epoch> --dispatch <agentId>… <the seat paths>` (one `--dispatch` per agent the
   round joined) and copies the path of every `REVISED-AFTER-MARKER <n> <path> --` line it prints
   into the brief as `revised-seats: <path>…`; the remediator re-reads those seats' findings from
   disk, never from an earlier summary. The cross seats reviewed the bytes from before
   the part repairs, so before it applies any cross finding the serial remediator runs
   `scripts/ai-dlc/validate-artifact-derivations.sh` on the cross files, from the project root
   against the assembled document, and re-derives every finding that reports STALE before
   applying it. Its limit: it re-runs only `derived`-fenced claims and proves each recorded
   output still reproduces; an unfenced `file:line` citation or quoted line is not checked, so
   the remediator re-reads every cross finding's cited text in the assembled document before
   editing on it.

   **An unsharded round has the same write model.** One agent per seat over the whole subject
   (a `SERIAL:` map, a one-part subject, or a subject that meets none of the cases below), the
   seats still edit nothing, and ONE remediator briefed `shard: none (serial-document)` (Rule 28
   exception 4) applies their findings and writes the party repair record itself, every entry
   carrying `source:`. No join runs, so the lead runs
   `scripts/ai-dlc/join-remediator-shards.sh --sources <that record> --sprint <N>`; a refusal
   re-dispatches that remediator.

   **When the subject is two or more files** (`stories/`), the round is sharded (Rule 28,
   "Split dispatch": seats x parts axis). The invocation brief asks for one persona agent per
   (seat, story ordinal) plus one cross-story agent per (seat, cross group) that reads every
   story and focuses on its group's pairs ("The cross groups" below). The
   ordinals are the ones `scripts/ai-dlc/merge-adversarial-shards.sh --map <shards-dir>` prints
   (`<shards-dir>` is the next review pass's `s<N>/shards/<artifact>-p<M>/`, which must exist),
   and each agent's brief carries its `shard:` line. A round spawns at most seats x (K + 6)
   agents, K being the story count.
   **When the subject is a single document** (one path), the round is sharded (Rule 28,
   "Split dispatch": seats x sections axis) over the parts
   `scripts/ai-dlc/partition-document.sh --map <doc>` prints: one persona agent per (seat,
   part ordinal) plus one cross-part agent per (seat, cross group) that reads the whole document and focuses on its group's pairs. A `SERIAL:` answer keeps one agent per seat
   (Rule 28 serial exception 4) and has no cross agent. `PART_CAP` in `partition-document.sh` bounds the parts and there are at most six cross groups, so a round
   spawns at most seats x (`PART_CAP` + 6) agents.
   **The cross groups, on every axis**, are the rows
   `scripts/ai-dlc/partition-document.sh --cross-groups <K>` prints, `<g>\t<ordinals>`, K being
   the ordinal count the axis's own `--map` printed. That program is their one speller; every
   unordered pair of parts lies inside at least one group, and G, the row count, is never above
   six. A cross agent's brief carries the line `shard: cross/<K> g<g>/<G> <ordinals>` and the
   whole group table (Rule 28, "Split dispatch"). It reads the WHOLE subject: its group's pairs
   are its FOCUS, and it may cite any ordinal. The groups cover every pair but not every triple,
   so a group-bounded read loses a finding resting on three or more parts that no group holds;
   wall clock tracks the tokens a cross agent writes, not the bytes it reads, so the whole read
   costs little and the focus is what shortens it. Each cross finding has one owner,
   `partition-document.sh --cross-owner`; the merge refuses a finding reported outside its owner
   only when the owner's shard carries the identical cited set, and accepts any other. The cross
   agent's brief therefore tells it to run `scripts/ai-dlc/partition-document.sh --cross-owner <K>
   <ordinal,ordinal,...>` (its cited ordinals, comma-joined) before it records a cross finding, and, when the printed group is not its
   own, to record the finding only if the owner's focus pairs would not surface it and otherwise
   to name it under `## Cross-references`, which is not a finding.
   **When the subject is the requirements subject** (`steps/requirements.md` section 5: the
   brief, `SPEC.md`, `prd.md` and `architecture-impact.md` under one base), the round is
   sharded (Rule 28, "Split dispatch": seats x subject-parts axis) over the parts
   `scripts/ai-dlc/partition-subject.sh --map <N> --base <base sha>` prints: one persona agent
   per (seat, part ordinal) plus one cross-part agent per (seat, cross group). This is the subject's first
   map: the lead resolves `<base sha>` as `steps/requirements.md` section 5 states, the map
   records it in the subject manifest, and every later sub-pass passes the manifest's sha. The
   seats edit nothing, as above, and the party repair below applies their findings. Before wave 1 the lead writes the sha256 of every subject file, one `<stem>=<sha>`
   line each, to `_bmad-output/planning-artifacts/s<N>/shards/requirements-party-repair/anchor`
   — the bytes the seats review, and the split anchor of the party repair. Write the separator as
   `@` only if `scripts/ai-dlc/merge-adversarial-shards.sh --pair-sep` prints exactly `@`,
   otherwise `=`; both are accepted.
   **Party repair (requirements subject case).** After the round's join, the lead dispatches
   the seats' findings to remediators exactly as "Adversarial repair dispatch" below shards the
   requirements subject, with `--pass party`, the shard dir
   `_bmad-output/planning-artifacts/s<N>/shards/requirements-party-repair/`, and the anchor's
   shas as the expected bytes. The joined record is
   `_bmad-output/planning-artifacts/s<N>/requirements-party-repair.md`, and the join resolves
   every entry's `source:` as above. A finding citing two or more parts goes to the serial
   remediator after assembly, whose brief carries `shard: none (authoring-chain)`, and `--sources` then checks the record with its appended entries.
   A subject that maps to one part is not sharded: no seats x parts round and no party shard dir.
   It is the unsharded round above: the party repair is ONE remediator that writes
   `_bmad-output/planning-artifacts/s<N>/requirements-party-repair.md` itself, and `--sources`
   checks it.
   A subject that meets none of these cases keeps one agent per seat, as an unsharded round.
   The round goes out in waves (Rule 28, "Split dispatch"): seats x parts routinely exceeds
   the harness's concurrent-subagent cap, and a spawn past the cap is rejected, not queued.
   Rule 28's Waves paragraph sizes them; a seat is never a wave.
   The cross agents go out in the same waves as the parts, not after them, and the
   cross members are dispatched first in wave 1, ahead of the per-ordinal members: they are
   the round's longest seats, and the harness usually admits a message's earlier calls first,
   though not always.
   The lead's join, before it proceeds, derives the EXPECTED set — `<step>-<seat>-<ordinal>.md`
   for every seat on the step's seat list (never from directory entries) and every ordinal the
   `--map` prints, plus `<step>-<seat>-cross-<g>.md` per seat for every group `<g>` that
   `--cross-groups <K>` prints — and takes as delivered only the paths
   a beat armed with `--complete --since <round epoch>` reports as `DELIVERED` (Rule 28 owns the epoch and
   where it is recorded), never a count of files in the directory. It names
   expected minus delivered as the MISSING (seat, ordinal) and (seat, cross group) members, which
   are re-dispatched after the join under the Rule 20 re-dispatch budget. A spawn the harness
   rejected is not MISSING: it is re-dispatched on the first agent exit since the rejection
   (Rule 28, "A rejected spawn"), never held for the join. `/bmad-party-mode` internals are not
   ai-dlc's, so this file-level join is the only check available.
   **Both flags are load-bearing and neither is optional — SKILL.md Rule 20 (i)
   owns why.**
   **Every per-seat deliverable this invocation produces is written under
   `_bmad-output/party-mode/s<N>/`**, one file per seat, named
   `<step>-<seat>.md`, or when sharded one per (seat, ordinal), named `<step>-<seat>-<ordinal>.md`
   and one per (seat, cross group), named `<step>-<seat>-cross-<g>.md` — `-cross-1.md` when
   there is one group. That directory is the declared area for it
   (`artifact-path-grammar.md`, "Areas"); anything written elsewhere blocks the
   consumer's push at `validate-artifact-paths.sh`, because a sprint token in
   any other position is outside the reserved slot. The retro TRANSCRIPT is a
   different artifact in a different area and `steps/retro.md` owns its path —
   do not fold the two together.
   **Run sub-step snapshot update** ("Sub-step snapshot update" above), then
   proceed.
2. `/bmad-advanced-elicitation` — probe until zero ambiguity and update the
   artifact. **Run sub-step snapshot update**, then proceed.

   **Minimum mechanism (Rule 26(c)).** Failure caught: a defect in text the party round never
   read (a fold, the party repair), or in first-authored text it missed, such as a swap quoted
   against another chain's hard-coded quoter, a checksum-invalid address passing validation, an
   empty allowlist failing open, or a fee floor orders of magnitude above the threshold it
   replaced. False-positive cost: one sharded elicitation round and its repair. Removal
   condition: measured sprints in which elicitation carries no unique MAJOR or CRITICAL catch
   that survives to the shipped artifact.

   **Elicitation takes the axis and the shape of the step's adversarial pass, for every subject.**
   The subject is sharded for elicitation exactly as "Adversarial review dispatch" shards it for
   the step's convergence passes; a lighter shape is not the lead's to choose. Two or more files
   (`stories/`, the files axis): one `adversary` per story ordinal plus one cross-story
   `adversary` per cross group, never one voice under `shard: none (serial-document)`, which Rule
   28 keeps for a single document. The story ordinals are the ones
   `scripts/ai-dlc/merge-adversarial-shards.sh --map <shards-dir>` prints, `<shards-dir>` being
   the next review pass's `s<N>/shards/<artifact>-p<M>/`, which the lead creates first, as item 1
   does for the party round; `--map` refuses the `<artifact>-elicitation/` directory, whose name is
   not `<artifact>-p<M>`. A `stories/` holding ONE file is ONE `adversary` briefed
   `shard: 1/1 <story-index>` (Rule 28, files axis) with no cross shard, never `shard: none (…)`.
   One document that `partition-document.sh --map` partitions
   (the sections axis): one `adversary` per part plus one cross-part `adversary` per cross group;
   a `SERIAL:` answer is ONE `adversary` under `shard: none (serial-document)` (Rule 28 exception
   4), which is how an architecture or carry-over evaluation that does not partition runs. The
   requirements subject: as below. On the files and sections axes each shard runs
   `/bmad-advanced-elicitation` in its own context scoped to its part, records findings and edits
   nothing, writes early and closes with its `seat-complete:` line as item 1 states, and writes
   `_bmad-output/planning-artifacts/s<N>/shards/<artifact>-elicitation/<ordinal>.md` (a cross
   shard: `cross-<g>.md`, or `cross.md` when there is one group) with
   `skill: bmad-advanced-elicitation`, the `artifact:` and `artifact_sha:` an adversarial shard on
   its axis notarizes, and no `verdict:` line. Each finding in it is a `### ` heading inside
   `## Findings` with an UPPERCASE severity word (FINDING GRAMMAR, `merge-adversarial-shards.sh`'s
   header), not item 1's `##` seat form. The brief carries the shard header as the generated
   `provenance-block/elicitation` region below: copy this region verbatim, never as a field
   list the lead retypes. The shard copies the region verbatim and then deletes each line's
   trailing ` #` comment (the space, the `#` and everything after it), because the merge reads
   every value literally. Beat-join every shard path with
   `--complete --shard-header elicitation`. No merge reads that directory (`merge-adversarial-shards.sh --elicitation` merges
   only the requirements subject), so the shard records ARE the elicitation record, and the
   elicitation repair reads them shard by shard, dispatched on the same axis by "Adversarial
   repair dispatch": files are repaired as "Shard by file" does, with
   `--artifact <artifact>-elicitation --pass 1`, the shard dir
   `_bmad-output/planning-artifacts/s<N>/shards/<artifact>-elicitation-repair-p1/` and the joined
   record `_bmad-output/planning-artifacts/s<N>/<artifact>-elicitation-repair-p1.md`; sections
   are repaired as "Shard by section" does, split into that same shard dir with `--expect-sha`
   the sha every elicitation shard notarized, and joined with
   `join-remediator-shards.sh --document <doc> <that dir>`.

   **The delta clause — a story split or added after a correctly sharded stories elicitation.**
   When `shards/stories-elicitation/` is complete for the K it was elicited at, and `stories/`
   has since gained a story no ORDINAL shard in it names (a split, or an addition), elicit ONLY
   the delta, never the whole round again. The owed stories are those whose file no ordinal
   shard's `artifact:` names; a cross shard's `<name>=` entry never covers a story. The owed
   cross groups are every group of today's `partition-document.sh --cross-groups <K>` that holds
   the ordinal of an owed story (by `merge-adversarial-shards.sh --map`), never the groups whose
   index list changed. Dispatch one `adversary` per owed story and one per owed group, each
   briefed at today's K (`shard: <i>/<K>`), writing
   `_bmad-output/planning-artifacts/s<N>/shards/stories-elicitation-delta-k<K>/<story-basename>.md`
   and `cross-<g>.md` there (`cross.md` at one group), in the same shard-file shape as above. Write
   no root `stories-elicitation-delta*.md` record. Check 24 arm L names the owed stories and groups
   in its remedy. A base that is not complete for its own K, or that is one voice at
   `shard: 1/1`, has nothing to top up: re-run the whole elicitation in the shape above.

<!-- BEGIN GENERATED: provenance-block/elicitation — source: .claude/schemas/provenance-block.json; do not edit by hand -->
```
<!-- SKILL_INVOCATION_PROVENANCE v1
skill: bmad-advanced-elicitation            # the evaluation that ACTUALLY RAN. Naming one you did not invoke is a forged block.
invoked_at: <ISO 8601 UTC, to the second>   # Check 24 orders the pass series on this. Ambiguity here reorders the cycle.
tool_use_id: <NOT_ACCESSIBLE as a shard; unsharded, the toolu_... id of the Skill call or Agent dispatch that spawned you> # a SHARD writes the literal NOT_ACCESSIBLE, never an id it was told or guessed: it cannot know its own dispatch id, and the merge derives each shard's id from the harness records and refuses a real-shaped id that differs. An UNSHARDED pass writes the id of the Skill/Agent call that ran this evaluation. CHECKED FOR SHAPE ONLY — nothing verifies it against a transcript, so it is not proof the evaluation ran.
mode: subagent                              # never solo.
lead_role: <the step file that invoked or dispatched the evaluation> # which step owns this pass.
artifact: <path of the artifact you reviewed> # what this pass reviewed.
artifact_sha: <sha256 of that file, as you read it> # `shasum -a 256 <artifact> | cut -d' ' -f1`. Makes the pass a notarization of the bytes it reviewed, which is what lets the gate later prove a claimed revert landed on a state some pass actually saw. What a shard notarizes depends on its axis: a per-story shard on the files axis carries its one story's sha; a cross-story shard carries one `<stem><sep><sha>` per story it read; the merged files-axis pass, which the merge writes, carries one `<stem><sep><sha>` per story; a subject-axis shard, cross included, carries one `<stem><sep><sha>` per subject stem; and a sections-axis shard, cross included, carries the whole document's sha. Write `<sep>` as `@` only if `scripts/ai-dlc/merge-adversarial-shards.sh --pair-sep` prints exactly `@`, otherwise `=`; both are accepted. The `artifact_sha` pattern accepts exactly those two shapes: one sha256, or two or more space-separated `<stem><sep><sha>` entries.
findings_critical: <int>                    # the residue the verdict is adjudicated against. Required of EVERY known evaluation, not only verdict-bearing ones — see rules.counts_always.
findings_critical_prior_scope: <int>        # of the CRITICALs above, those in text the PRIOR pass also reviewed. OPTIONAL BY DESIGN: absent means the validator assumes ALL of them (fail-closed). Requiring it would invert that default and reject the safe omission. This is what separates 'not converging' from 'the document is moving'.
findings_major: <int>                       # omit it and the stall rung goes silent for the ENTIRE series.
findings_major_underived: <int>             # of the MAJORs above, those whose ONLY defect is a MISSING DERIVATION -- a count, a universal, a call-site list or a negative asserted without one, which you have NOT shown to be false. These are RECORDED and do NOT block the exit condition; a MAJOR you have shown WRONG still does. OPTIONAL, and ABSENT MEANS ZERO -- the inverse of findings_critical_prior_scope's default, deliberately. There, absent means ALL, because assuming a cycle has not progressed is the safe assumption. Here, absent means NONE, because assuming a claim is merely unproven is not: an omission leaves every MAJOR blocking, exactly as before this field existed, so no pre-existing block changes verdict and a producer that never emits it can only be stricter, never laxer. It may never exceed findings_major -- that is arm B's business, not the reader's.
findings_minor: <int>                       # the nitpick bucket. Does not block the exit condition.
SKILL_INVOCATION_PROVENANCE_END -->
```
<!-- END GENERATED: provenance-block -->

   **When the subject is the requirements subject**, elicitation is sharded (Rule 28, "Split
   dispatch": subject axis): one `adversary` per part of the subject map, each invoking
   `/bmad-advanced-elicitation` in its own context scoped to its part, plus one cross-part
   `adversary` per cross group (item 1, "The cross groups") that reads the whole subject and
   focuses on its group's pairs, all in the same waves. They record findings and edit nothing, and each
   writes early and closes with its `seat-complete:` line as item 1 states. Each writes to
   `_bmad-output/planning-artifacts/s<N>/shards/requirements-elicitation/<ordinal>.md` (a
   cross shard: `cross-<g>.md`, or `cross.md` when there is one group) with `skill: bmad-advanced-elicitation` and no `verdict:` line,
   since elicitation is not a convergence pass; its brief carries the shard header exactly as
   the files and sections axes above state. Beat-join every shard path with
   `--complete --shard-header elicitation`, then run
   `scripts/ai-dlc/merge-adversarial-shards.sh --subject <N> --base <base sha from the manifest> --elicitation <that dir>`.
   It refuses unless every ordinal and every cross group delivered exactly once, every finding
   cites ordinals within the partition, and no cross finding outside its owner's shard repeats
   one the owner carries, and then writes
   `_bmad-output/planning-artifacts/s<N>/requirements-elicitation.md` with no verdict. The
   elicitation repair is dispatched as the party repair is, with `--pass elicitation`, the shard
   dir `s<N>/shards/requirements-elicitation-repair/`, and the merged record's per-stem
   `artifact_sha` values as the expected bytes; its brief carries `revised-seats:` as item 1's
   "One repair writer applies them" states, read from the same `--complete --status` call over the
   shard paths; its joined record is
   `_bmad-output/planning-artifacts/s<N>/requirements-elicitation-repair.md`.
   Every elicitation shard notarizes exactly what an adversarial subject shard does ("Shard the
   requirements subject" below): `artifact:` = the subject manifest
   `_bmad-output/planning-artifacts/s<N>/requirements-subject.md`, `artifact_sha:` as one
   `<stem>=<sha>` token for each of the four subject stems, each equal to that file's sha256 on
   disk, and one `sections:` line citing map ordinals on every finding (a part shard only its own,
   a cross shard two or more, any of them). The merge refuses a shard missing any of them.
   Write each token's separator as `@` only if
   `scripts/ai-dlc/merge-adversarial-shards.sh --pair-sep` prints exactly `@`, otherwise `=`;
   both are accepted.
   **A subject that maps to one part** (`partition-subject.sh --map` exits 3) is never merged:
   `merge-adversarial-shards.sh --subject` refuses it, and `--elicitation` has no single-adversary
   form. ONE adversary, briefed `shard: none (serial-document)` (Rule 28 exception 4), runs
   `/bmad-advanced-elicitation` over the whole subject and writes
   `_bmad-output/planning-artifacts/s<N>/requirements-elicitation.md` itself, with no `verdict:`
   line, `skill: bmad-advanced-elicitation`, `artifact:` = the subject manifest and `artifact_sha:`
   as above. No merge runs, and the elicitation repair is ONE remediator on the same footing.
3. **Adversarial convergence** — passes through the
   **Adversarial review dispatch** and **Adversarial repair dispatch**
   sub-routines (below), carrying the step's declared focus. **Run sub-step
   snapshot update after each pass**, then **run auto-handoff evaluation**
   ("Auto-handoff evaluation" below) at `Seam D` with the step's label — FIRE
   ends the session, otherwise continue until the terminal pass stamps
   `EXIT_CONDITION_MET`. A `DIVERGENT_HARD_BLOCK` or STALL does not end the loop:
   follow "Divergence resolution dispatch" below.

   **Minimum mechanism (Rule 26(c)).** Failure caught: a defect a repair or a fold wrote into
   the subject, such as a subscription broadcast from a burn hash, a destination rebind placed
   before the assignment that overwrites it, or a config key a repair left in place so the loader
   raises at start. This round's catches are all of that kind: no first-authored defect is unique
   to it. Most MAJORs at every adversarial pass sit in text the previous repair wrote, and
   the next pass is the only reader of that text; the terminal pass is also the counted exit
   Check 24 reads (Rule 8). False-positive cost: one pass and its repair per round until the
   exit. Removal condition: repairs that measurably stop writing defects, and a Rule 8 that no
   longer counts an exit.

   **Requirements pass 1 reviews the elicitation repair.** On the requirements subject the
   lead briefs every pass-1 shard, and the one adversary of a subject that maps to one part,
   under the pass-2+ contract (`team-roles/adversary.md`, "Later passes review the REPAIR"),
   handing it `_bmad-output/planning-artifacts/s<N>/requirements-elicitation.md` as the prior
   pass's findings and `_bmad-output/planning-artifacts/s<N>/requirements-elicitation-repair.md`
   as the repair record. It is still pass 1 of the series, and elicitation still carries no verdict.
4. Append the step's changelog ("Where a changelog is written" below), then proceed to
   the step's next action.

## Where a changelog is written (referenced by step files)

**A changelog entry is a record of one sprint's passes over an artifact, so it is written
to that sprint's slot and never appended to the durable artifact itself:**

```
_bmad-output/planning-artifacts/s<N>/changelog-<artifact>.md
```

`<N>` is `sprint_id` (`scripts/ai-dlc/sprint-status.sh sprint-id`); `<artifact>` is the
stem of the artifact the entry is about — `changelog-product-brief.md`, `changelog-prd.md`,
`changelog-architecture.md`. Append to the file if the sprint has already opened one. A
story file's changelog stays INLINE in the story: a story already lives in `s<N>/stories/`,
so it carries its own sprint and has no durable artifact to pollute.

**Why this is not a preference.** A durable artifact carries no sprint token by rule 3 of
the artifact path grammar, and that is what makes it durable. Appending per-sprint prose to
it puts sprint-scoped content at a sprint-independent path — the same defect
`artifact-consolidation.md` had for its four working files, which is why it now writes them
to `s<N>/` too. Measured on the reference consumer before this changed: the live product
brief was 1030 lines, of which **223 (21%) were four changelog entries carrying the same date
and all belonging to ONE sprint**, sitting inside an artifact the whole-read budget pools.

**AND NOTHING IN CORE READS ONE, WHICH IS THE REASON TO HOME IT RATHER THAN TO DROP IT.**
`change[ -]?log` over `scripts/ai-dlc/` and `.claude/hooks/` matches only the
*validation-cycle-log* model — one of those lines says per-artifact changelogs are "freeform
prose, not countable here" (`validate-mandatory-rules.sh`, its `[Check 2]` enablement comment). The entries are evidence a human reads when asking
what a sprint did to an artifact, and a coverage report can cite one; deleting them breaks a
record the pass produced. **Existing entries already inside a durable artifact are MOVED into
the slot of the sprint they describe, never removed** — the same disposition item 23b took for
the 33 byproduct files.

## Adversarial review dispatch (referenced by step files)

When a step file says "run an adversarial review pass", execute this. It is the REVIEW half of
the Rule 8 cycle; the repair half is below.

**No Skill runs.** The convergence review is ai-dlc-native: the method is `team-roles/adversary.md`,
in full. The bmad skill `/bmad-review-adversarial-general` is NOT invoked here — its contract
(*find at least ten issues; HALT if zero findings; emit no severity, priority, or ranking*) has
no fixed point in a loop whose exit criteria are a bounded severity residue, and it forbids the
severity fields Check 24 reads. It remains correct for a ONE-SHOT cynical sweep, and the step
files that run one still invoke it.

**Dispatch** ONE `adversary` per pass, or one shard per story plus one cross-story shard per cross
group when the artifact is two or more files ("Shard a multi-file artifact" below), or one shard
per section plus one cross-section shard per cross group when the artifact is one document that
`partition-document.sh --map` partitions ("Shard a single document" below), or one shard per
subject part plus one cross-part shard per cross group when the artifact is the requirements
subject ("Shard the requirements subject" below). The cross groups are the rows
`partition-document.sh --cross-groups <K>` prints for the map's K ("Validation cycle" item 1,
"The cross groups"), and the cross shards go out in the same waves as the parts.
Agent tool, bound to `.claude/team-roles/adversary.md` per
SKILL.md Rule 19 (both bindings: `model` and the standing role-contract Read line). Give it: the
artifact path under review, the canonical output path, the pass number, and — on pass 2+ — the
PRIOR pass's findings and the repair record, because pass 2+ reviews the REPAIR, not the document
again. On pass 1 of the requirements subject, sharded or one-part, that pair is the elicitation
record: `_bmad-output/planning-artifacts/s<N>/requirements-elicitation.md` as the prior pass's findings and `_bmad-output/planning-artifacts/s<N>/requirements-elicitation-repair.md` as the repair record ("Validation cycle" item 3). Every adversary brief, sharded or not, also carries the early-write instruction of
"Validation cycle" item 1: header first, each finding appended as verified, and ONE final
act once it has finished, never with the header: the ONE Bash call
`scripts/ai-dlc/wait-for-deliverable.sh --mark <shard path> <step> adversary <shard> findings=<n>`,
which appends `seat-complete: <step> adversary <shard> sha=<hex> findings=<n>`. That call is the
one sanctioned Bash write to a shard; every other write is Write or Edit, never Bash (the merge
refuses a shard written or amended through Bash after its last Write or Edit, by its content
seal; `content-seal.sh` owns the check, and `--mark` re-seals what it writes). `<shard>` is
the brief's `shard:` value (`none` when it carries none) and
`<n>` its `### ` findings, each a `### ` heading inside `## Findings` with an UPPERCASE severity word (FINDING GRAMMAR in `merge-adversarial-shards.sh`'s header; item 1's `##` seat example does not apply to a shard). On every axis, once ANY shard in the directory carries a
`seat-complete:` line anywhere, the merge refuses every shard in it that does not end in
exactly one, or whose `findings=<n>` differs from the findings it parses there. Its limit: a directory where no shard carries the marker merges
unchecked, exactly as before. That is a directory written before this instruction, and also a
round where no shard has finished — which the join's `--complete` beat, not the merge, keeps
from reaching the merge. The merged record's `tool_use_id` is the derived id of cross-1 (of `cross` when there is one cross shard).

It writes findings to `_bmad-output/planning-artifacts/s<N>/<artifact>-adversarial-p<M>.md`
carrying a `SKILL_INVOCATION_PROVENANCE v1` block. Every adversary brief, sharded or not, carries
that block as the generated `provenance-block/adversary-pass` region of `team-roles/adversary.md`
copied verbatim (`sync-taught-schema.sh` renders it from `.claude/schemas/provenance-block.json`),
never as a field list the lead retypes; an unsharded pass fills `tool_use_id` with THIS Agent
dispatch's id. A SHARD writes `tool_use_id: NOT_ACCESSIBLE`, because a
dispatched adversary cannot know its own dispatch id, and the merge derives each shard's dispatch id
from the harness records: the write ledger names the agent that wrote the shard, its meta file names
the dispatch, and the spawn ledger must record that dispatch as an `adversary`. Write your shard
with Write or Edit, never Bash; a Bash-written shard has no harness record and the merge refuses it.
Filename numbering is load-bearing: Check 24 orders the series by the `p<M>` token.

**Join** with the bounded-join beat (above): `scripts/ai-dlc/wait-for-deliverable.sh --complete <findings_path>`, which takes a file as delivered only once it ends in its `seat-complete:` line and that line's `sha=` matches.

**A re-dispatched shard is merged with `--rerun`.** Write-ledger rows never expire, so after a stalled adversary is re-dispatched the merge refuses its shard as written by two adversary dispatches. When it does, run the same merge with `--rerun <shard>.md@<the re-dispatch's dispatched-at>` (repeatable, one per re-dispatched shard). The re-dispatch is a NEW dispatch, and a refusal naming a writer of another shard is a finding, never a timestamp to move.

**The probe ledger is load-bearing until the consumer's hook writes `transcript_path`.** Do not rotate or truncate `subagent-context.jsonl` mid-round: a shard row without `transcript_path` takes its dispatch id from that ledger alone. A refusal naming a row that "predates transcript_path" is re-run after the next dispatch writes the new keys, never hand-filled.

**Shard a multi-file artifact (Rule 28, "Split dispatch": files axis).** When the artifact under
review is two or more files (`stories/`), dispatch one `adversary` shard per story plus one
cross-story shard per cross group, in waves (Rule 28, "Split dispatch"). The part set is derived: create
`_bmad-output/planning-artifacts/s<N>/shards/<artifact>-p<M>/`, then run
`scripts/ai-dlc/merge-adversarial-shards.sh --map <that dir>`, which prints
`<ordinal>\t<basename>` per story. Each per-story shard gets its ordinal and basename, the line
`shard: <ordinal>/<K> <basename>`, and the output path `<that dir>/<ordinal>.md`. Each cross-story
shard gets `shard: cross/<K> g<g>/<G> <ordinals>`, the whole map, the whole group table, every
story to read, its group's pairs as its focus ("Validation cycle" item 1, "The cross groups"),
and `<that dir>/cross-<g>.md` (`<that dir>/cross.md` when G is 1). Every finding carries one `stories:` line in the grammar
`merge-adversarial-shards.sh` defines. Beat-join every shard path with
`--complete --shard-header convergence`, then run the join
`scripts/ai-dlc/merge-adversarial-shards.sh <that dir>`. It refuses (exit 2, `REFUSED:`, nothing
written) unless every ordinal and every cross group delivered exactly once, every finding
respects the partition, no cross finding outside its owner's shard repeats the owner's identical
cited set, and every cross shard's `artifact:` equals `cross-1`'s. It then sums the counts, recomputes the verdict (a shard's own verdict is
advisory) and writes the one `<artifact>-adversarial-p<M>.md` above. Check 24 reads that file as
it reads an unsharded pass. A single-file artifact is sharded by section (below), and passes stay
serial (exception 2).

**Shard a single document (Rule 28, "Split dispatch": sections axis).** When the artifact under
review is one file, run `scripts/ai-dlc/partition-document.sh --map <artifact path>`. Exit 3 with a
`SERIAL:` line means the document does not partition: dispatch ONE adversary whose brief carries
`shard: none (serial-document)` (Rule 28 exception 4). Otherwise the map prints
`<ordinal>\t<first-line>\t<last-line>\t<heading>` per part; create
`_bmad-output/planning-artifacts/s<N>/shards/<artifact>-p<M>/` and dispatch, in waves (Rule 28,
"Split dispatch"), one `adversary` per part plus one cross-section shard per cross group. Each part shard gets its ordinal, its line
range and heading, the line `shard: <ordinal>/<K> <heading>`, and the output path
`<that dir>/<ordinal>.md`; it reads its line range of the REAL document, read-only, never a copy.
Each cross-section shard gets `shard: cross/<K> g<g>/<G> <ordinals>`, the whole map, the whole
group table, the whole document to read and its group's pairs as its focus,
and `<that dir>/cross-<g>.md` (`<that dir>/cross.md` when G is 1). Every finding carries one `sections:`
line citing map ordinals (a part shard only its own, a cross shard two or more, any of them), and every
shard notarizes the WHOLE document's `artifact_sha` with `artifact:` naming the document. Beat-join
every shard path with `--complete --shard-header convergence`, then run the join
`scripts/ai-dlc/merge-adversarial-shards.sh --document <artifact path> <that dir>`. It re-derives
the ordinal set from `--map` and the groups from `--cross-groups`, refuses (exit 2, `REFUSED:`, nothing written) unless every ordinal
and every cross group delivered exactly once, every finding cites `sections:` within the partition,
no cross finding outside its owner's shard repeats the owner's identical cited set, and every shard notarized the document's current sha, then writes the one
`<artifact>-adversarial-p<M>.md` above.

**Shard the requirements subject (Rule 28, "Split dispatch": subject axis).** When the artifact
under review is the requirements subject (`steps/requirements.md` section 5), the series is
`s<N>/requirements-adversarial-p<M>` and every pass of it is sharded. Create
`_bmad-output/planning-artifacts/s<N>/shards/requirements-p<M>/` and run
`scripts/ai-dlc/partition-subject.sh --map <N> --base <base sha>`, with the base read from the
subject manifest, never re-derived. The map prints
`<ordinal>\t<file>\t<first-line>\t<last-line>\t<heading>` per part. A subject that maps to one
part gets ONE adversary whose brief carries `shard: none (serial-document)` (Rule 28 exception
4); it writes `requirements-adversarial-p<M>.md` itself, with `artifact:` = the subject manifest
and `artifact_sha:` as one `<stem>=<sha>` entry per subject file (write the separator as `@`
only if `scripts/ai-dlc/merge-adversarial-shards.sh --pair-sep` prints exactly `@`, otherwise
`=`; both are accepted). Otherwise dispatch, in waves (Rule 28, "Split dispatch"), one `adversary` per part plus one
cross-part shard per cross group. Each part shard gets its ordinal, its file, its line range and heading, the
line `shard: <ordinal>/<K> <file-stem> <heading>`, and the output path `<that dir>/<ordinal>.md`;
it reads its line range of the REAL file, read-only. Each cross-part shard gets
`shard: cross/<K> g<g>/<G> <ordinals>`, the whole map, the whole group table, the whole subject
to read — across files as well as within one — with its group's pairs as its focus,
and `<that dir>/cross-<g>.md` (`<that dir>/cross.md` when G is 1). Every finding carries one
`sections:` line citing map ordinals (a part shard only its own, a cross shard two or more, any of them).
Every shard notarizes `artifact:` = the subject manifest and `artifact_sha:` as one
`<stem>=<sha>` entry per subject file, as the files are on disk. Write the separator as `@` only
if `scripts/ai-dlc/merge-adversarial-shards.sh --pair-sep` prints exactly `@`, otherwise `=`;
both are accepted. Beat-join every shard path with
`--complete --shard-header convergence`, then run `scripts/ai-dlc/merge-adversarial-shards.sh --subject <N> --base <base sha> <that dir>`.
It re-derives the ordinal set from `partition-subject.sh --map` and the groups from `--cross-groups`, refuses (exit 2, `REFUSED:`,
nothing written) unless every ordinal and every cross group delivered exactly once, every
finding cites ordinals within the partition, no cross finding outside its owner's shard repeats the owner's identical cited set, and every per-stem sha matches the disk, then
sums the counts, recomputes the verdict and writes
`_bmad-output/planning-artifacts/s<N>/requirements-adversarial-p<M>.md`. `--document` refuses a
shard dir named `requirements-p<M>`, so no sharded pass of this series is written in document
mode. Check 24 arm K3 (`gate-validation.md`) holds the series to the subject shape.

**Zero findings on a later pass is the EXPECTED outcome, not a suspicious one.** The cycle exists
to reach it. An adversary that manufactures a finding to justify its pass sends the remediator to
edit a correct artifact, and the edit is where new defects come from.

## Divergence resolution dispatch (referenced by step files)

When the cycle **STOPS** — a pass stamps `DIVERGENT_HARD_BLOCK`, or Check E fires a STALL — the
Rule 8 cycle does not end. It waits. Execute this, in this order. You cannot skip a step: the
PreToolUse hook denies every `Agent` / `Skill` / `Task` dispatch until step 3 has produced a file.

**STOP → ADJUDICATE → RESOLVE → VERIFY**

1. **STOP.** No further pass on the artifact as it stands. Do not dispatch a remediator: a repair
   on unchanged scope is what diverged, and running one now is the failure repeating.
2. **ADJUDICATE.** Escalate to the operator (Rule 11(a)). **The operator picks the kind.**

   **Present a DECISION, not the findings.** The operator is being asked for one thing — which
   resolution KIND — and everything that is not that question is material they must read past to
   answer it. Emit, in this order and nothing else:

   a. **One sentence naming the decision.** Not the finding, not its severity, not how the pass
      graded it: the choice in front of them. *"Do I fix two sentences in the spec, or delete
      them, before the discovery step closes?"*
   b. **An `AskUserQuestion` with 2–4 options** (the constraint and why the
      harness enforces it are in `SKILL.md`'s Rule 3 pause-point section)**.** Each option carries its resolution KIND, the
      concrete edit it authorizes, and what it costs. An option the lead has not worked out well
      enough to state that way is not an option yet — work it out or drop it.
   c. **When no option touches a `LOCKED_REQUIREMENTS` entry: exactly one option marked
      `(Recommended)`, with the one reason.** A menu with no recommendation hands the judgment
      back and is a defect of the presentation, not a display of neutrality; the lead has read
      the artifact and the operator has not.
      **When an option touches one** — the record's `locked_requirements_touched:` names an
      entry — **mark NO option `(Recommended)`.** State each option's effect on that entry
      instead, including the value it leaves in force (SKILL.md Rule 11(a)). The locked value is
      the operator's, and a badge on it is the lead deciding it in the operator's name.

   Where a repair weakened something LOAD-BEARING — an AC, a predicate, a guard, a
   `LOCKED_REQUIREMENTS` entry; test: *after the edit, can the check still FAIL?* — say so in (a),
   and state per option what it does to that thing rather than which option you would take.
   That is the one fact that changes which kind is correct, so it belongs in the decision
   sentence rather than in the evidence the operator has to go looking for.

   The findings, the repair that caused them, and the derivations behind them stay in the pass
   artifacts, where they already are. Reproducing them in the escalation is what turns a
   90-second decision into four round-trips.

   Record what you presented: the resolution record's `options_presented` and
   `recommended_option` are the machine-readable half of this step.
3. **RESOLVE.** *A repair edits the artifact to close findings on UNCHANGED scope. A resolution
   changes WHAT IS UNDER REVIEW.* The LEAD writes the record — not the adversary (it would only be
   echoing the lead's claim) and not the remediator (it authors repairs, which is the thing being
   stopped). Write it to `_bmad-output/planning-artifacts/s<N>/<artifact>-resolution-p<M>.md`
   (`<M>` = the pass being resolved). **This write is permitted while paused**; it is the one write
   the pause is waiting for.

   ```
   <!-- ADVERSARIAL_RESOLUTION v1
   resolves: <path of the DIVERGENT_HARD_BLOCK pass>
   resolution: REVERT_REPAIR | CHANGE_APPROACH | CUT_SCOPE | RESTART_CYCLE | REOPEN_AFTER_MET
   adjudicated_by: operator
   artifact: <path of the artifact under review>
   artifact_sha_before: <MUST equal the resolved pass's artifact_sha>
   artifact_sha_after:  <sha256 after the resolution>
   artifact_bytes_before / artifact_bytes_after: <int>
   scope_delta: <what changed, concretely>
   locked_requirements_touched: <none | entries + the operator's authorization>   # absent reads as none
   operator_authorization: <ISO-8601 UTC ts of the operator's message> | "<verbatim quote of it, >=12 chars after whitespace is collapsed; a short message is quoted whole, numbering included>"
   options_presented: <int, >=2>   # how many resolution options step 2(b) put to the operator
   recommended_option: <the one you marked (Recommended), named so the operator's reply identifies it | none when locked_requirements_touched names an entry>
   archive: <dir>            # RESTART_CYCLE only
   ADVERSARIAL_RESOLUTION_END -->
   ```

   | kind | what it means | what the gate checks |
   |---|---|---|
   | `REVERT_REPAIR` | put the artifact back to a state an earlier pass reviewed | `artifact_sha_after` must equal some earlier pass's `artifact_sha` |
   | `CUT_SCOPE` | remove the contested scope | `artifact_bytes_after` **<** `artifact_bytes_before` |
   | `CHANGE_APPROACH` | a different approach, on the operator's authority | sha changed; `scope_delta` present |
   | `RESTART_CYCLE` | abandon the series and start over | as above, **plus** the passes MOVED to an existing `archive:` dir |
   | `REOPEN_AFTER_MET` | the series had already stamped `EXIT_CONDITION_MET` and the artifact moved after it | sha changed; `scope_delta` names what moved |

   **For the requirements subject** the record's `artifact:` is the subject manifest, and
   `artifact_sha_before` and `artifact_sha_after` each carry one `<stem>=<sha>` entry per subject
   file, every stem on both sides. `artifact_bytes_before` / `artifact_bytes_after` are the sums
   over the subject files, so `CUT_SCOPE` compares summed bytes. `REVERT_REPAIR` matches per
   stem: every stem's after sha equals that stem's sha in one earlier pass's `artifact_sha`.
   Write the separator as `@` only if `scripts/ai-dlc/merge-adversarial-shards.sh --pair-sep`
   prints exactly `@`, otherwise `=`; both are accepted.

   **THE CYCLE GETS ONE SANCTIONED RESOLUTION; A SECOND MUST BE ANCHORED.** Arms C, D and E
   each STOP the cycle and all three take this same exit, so a cycle stopped and released
   repeatedly reads to every one of them as a cycle being legitimately resolved. Arm I counts
   the records. Past the first, the newest one must declare `CUT_SCOPE` or `REVERT_REPAIR` —
   the two kinds whose claim is checked against the bytes in the table above. A second
   `CHANGE_APPROACH` or `RESTART_CYCLE` is the cycle trying again at the same size, nothing
   can check the claim, and the hooks deny every dispatch until the kind changes.

   The block lifts on the same pass the moment it does — it never denies the verification pass
   a record was written to authorize — and it does not apply once the series stamps
   `EXIT_CONDITION_MET`. If the operator judges a document genuinely needs more:
   `AI_DLC_RESOLUTION_CEILING`.

   **`EXIT_CONDITION_MET` IS A FREEZE POINT, AND THE CYCLE IS ORDERED.** Rule 8's intensity
   arrow is a sequence — Party Mode → Advanced Elicitation → Adversarial Review — so
   elicitation runs BEFORE the convergence cycle, never after it. Once a series stamps
   `EXIT_CONDITION_MET` the artifact it notarised is frozen for that step.

   A pass that runs after MET and reports any CRITICAL or MAJOR is proof the artifact moved
   after it was signed off: the same bytes reviewed under the same contract yield the same
   residue. That is a RE-OPEN, arm J stops it, and it costs a fresh sub-cycle. A pass after
   MET that finds NOTHING is the intensity FLOOR being met and costs nothing — the arm
   requires a non-zero residue precisely so the floor is never punished as a defect.

   Rule 7 ("fix it directly in the artifact") governs findings raised INSIDE the cycle.
   After MET, an improvement is DEFERRED to the next step's artifact, or it re-opens the
   series on this record. It does not simply happen: the measured instance was an
   elicitation editing an artifact its own series had already notarised, buying a five-pass
   sub-cycle nobody scheduled.

   **THE AMENDMENT PROCEDURE — a notarized artifact that must move after MET.** Check 24 arm J2
   compares the file the terminal MET pass notarized against the bytes on disk. Amend it one of
   these ways, in the same dispatch as the edit:
   1. A residue or gate repair on unchanged scope: the remediator's structured repair record, in
      the pass directory, with `artifact:`, `artifact_sha_before:` and `artifact_sha_after:`.
      Each repair's before is the previous repair's after, from the notarized sha to the disk sha.
      For the requirements subject the repair is sharded as "Adversarial repair dispatch" shards
      that subject, and each side is the per-stem `<stem>=<sha>` list, chained per stem. Write
      the separator as `@` only if `scripts/ai-dlc/merge-adversarial-shards.sh --pair-sep`
      prints exactly `@`, otherwise `=`; both are accepted.
      A split or merge of story ids is NOT item 1. When `test-strategy.md` moves so that the set of
      story ids its mapping rows name (the story column, `| ST<N>-… | <id> |`) differs between the
      notarized bytes and the bytes on disk, it is a scope change for the test strategy: follow
      items 3 and 4 (one `REOPEN_AFTER_MET` record plus ONE verify pass). Check 24 arm J2 refuses
      a repair chain that changes that set.
   2. A scope change — a later step rewording a capability: append a `(decision)` entry to the
      spec's `.memlog.md` and re-render `SPEC.md` through `bmad-spec`; update the `prd.md`
      sprint-block FR in the same dispatch.
   3. For that scope change, write ONE `REOPEN_AFTER_MET` record above, `artifact_sha_before` =
      the notarized sha and `artifact_sha_after` = the disk sha, whose `scope_delta` names the
      `CAP-<n>` or `FR-S<N>-<n>` it moves. It is operator-authorized under F6; a Tier-2
      `DECIDED_AUTONOMOUSLY` is not authorization.
   4. Run ONE verify pass in the same series citing that record in `resolves_divergence:`. It is
      terminal and notarizes the bytes on disk.

   **This clause lives here rather than in Rule 8 because `SKILL.md` has no room.** The
   POST-COMPACT RECOVERY PROTOCOL must end inside Claude Code's ~5000-token re-attach
   window, and it ended with THREE tokens of slack; any prose added above it pushes the
   tail out of the window a re-attaching lead can see. Rule 8 already delegates kinds and
   procedure to this file, so this is where it belongs — but the constraint, not the
   taxonomy, is what decided it.

   **`operator_authorization` is a CITATION, required for EVERY kind, and verified.** A
   resolution CLEARS a HARD_BLOCK, and a hard block is operator-gated by design (only the
   operator may adjudicate). So the field is not free text — it is a *timestamp* plus a
   *verbatim substring* of the operator's own message, and Check 24 checks that substring
   against the harness-owned session transcript using the genuine-operator predicate (the same
   one Rule 29 uses). If no genuine operator message in the pause window contains those words,
   the gate FAILS: a lead-authored resolution is not an operator adjudication. Quote a real span
   of what the operator actually typed (≥12 chars after whitespace is collapsed; a short message
   is quoted whole) — not a paraphrase, and not a token. The
   machine notarizes that a human said it; you and the operator own what it means.

   **FREEZE is not on this list and is rejected by name.** A hard block means CRITICALs rose in
   text a previous pass had already reviewed — text that is *already frozen*. Freezing it again
   removes nothing: the verification pass reads the same bytes and finds the same CRITICALs. There
   is no wording of a freeze that passes Check 24. (Freezing IS the remedy for a *moving artifact*
   — a cycle that cannot converge because the sprint grows under it. Opposite failure, opposite
   remedy. Conflating the two parked a live pipeline for a day.)

   **`RESTART_CYCLE` must MOVE the abandoned passes**, not leave them. A restart writes p1, p2, p3
   over the dead cycle's files — and if the dead cycle ran to p17, then p4…p17 are still on disk,
   the glob chains them onto the new series, and the gate adjudicates the corpse. `git mv` them to
   `planning-artifacts/archive/<series>-cycle-<n>/`. Do not delete them; retro reads them.

4. **VERIFY.** Dispatch **ONE** adversary pass (procedure above, sharded exactly as a review pass is
   when the artifact is two or more files, a document `--map` partitions, or the requirements
   subject — whose verify pass is mapped by `partition-subject.sh` under the manifest's base and
   merged with `--subject` — and every shard carrying the declaration below) against the RESOLVED artifact, as the
   **next pass number in the SAME series**, declaring `resolves_divergence: <the record>`. Do not
   open a new series: `--series` spans both, the pass numbers collide, and the gate then fails on
   a cycle that did nothing wrong. That pass is the terminal clean pass Check 24 requires.

## Adversarial repair dispatch (referenced by step files and by the gate)

ONE procedure, TWO callers: a step file that says "repair the findings" after an adversarial
pass, and `gate-validation.md` "Gate Failure" after a check fails. **The lead does not repair the
artifact itself** — it is the most context-saturated agent in the pipeline and repairs from a
compacted summary, not the document. (Rationale + the measurement: notes R35.)

**Dispatch** ONE `remediator` per pass, or one shard per disjoint FILE set when the artifact is
two or more files ("Shard by file" below), or one shard per SECTION when the artifact is one
document that `partition-document.sh --map` partitions ("Shard by section" below), or one shard
per subject part when the artifact is the requirements subject ("Shard the requirements
subject's repair" below), and never one per finding. The gate-failure caller at the
requirements gate repairs a FAILED check on a subject file the same way, as a subject repair,
under the gate record name (`join-remediator-shards.sh --subject <N> --artifact gate-<type> --pass <M>`,
"Shard the requirements subject's repair" below).
Agent tool, bound to
`.claude/team-roles/remediator.md` per SKILL.md Rule 19 (both bindings: `model` and the
standing role-contract Read line). Together the remediators take that pass's WHOLE set: every
finding of the adversarial pass, or every FAILED check of the gate pass.

**Adversarial repair name.** The adversarial repair record carries no round word: its shard dir is `shards/<artifact>-repair-p<M>/` and its record `<artifact>-repair-p<M>.md`, never `<artifact>-adversarial-repair-p<M>` or `<artifact>-adversarial-p<k>-repair-p<M>`, and the join refuses an artifact ending in `-adversarial`, since arm H of `validate-adversarial-convergence.sh` reads only the first name.

**Shard by file (Rule 28, "Split dispatch": files axis).** Partition the findings by the files
their `edit:` targets name. A finding touching one file goes to that file's shard, and each
shard edits its files IN PLACE, never a copy. A finding citing more than one file goes to ONE
serial remediator dispatched after the join, which is dispatched as "Every escalated entry
reaches the serial remediator" says, not only for such a finding, and its brief carries
`shard: none (authoring-chain)` (Rule 28 exception 3). A single-file artifact is sharded by section
(below). Each shard's brief carries `shard: <i>/<N> <files>` and the parts path
`_bmad-output/planning-artifacts/s<N>/shards/<artifact>-repair-p<M>/<i>.md`. Every `edit:` line
cites the project-relative path in the ledger's spelling (`_bmad-output/planning-artifacts/s<N>/…`)
of each file it edits, and a citation must not wrap onto the next line. Beat-join
every part with
`scripts/ai-dlc/wait-for-deliverable.sh --complete --since <round epoch> --dispatch <agentId> <part path>...`
(one `--dispatch` per agent the round joined), which takes a part as delivered only once it ends
in the `seat-complete:` line its remediator's `--mark` wrote. An UNFINISHED part whose body is complete and carries no `seat-complete:` line was written before parts marked: read it, then `--mark` it or re-dispatch its part. Then run the join
`scripts/ai-dlc/join-remediator-shards.sh --sprint <N> --artifact <name> --pass <M> --artifact-path _bmad-output/planning-artifacts/s<N> --since <ISO> --until <ISO>`
over the repair window. `--artifact-path` is the sprint slot `s<N>`, not `s<N>/stories`: a
stories repair also edits `epics/epics.md` and other slot siblings, and every file a shard edits
under the slot must be cited on its `edit:` lines. Writes under `s<N>/shards/` are the parts
themselves and are not counted. It reads the harness write ledger and refuses (exit 2, `REFUSED:`,
nothing written) if any file was written by two agents, if a written file is cited by no part,
if a file is cited by two parts, or if any part is unstructured. Otherwise it writes the one
repair record below. The serial work then runs in LANES and a FAN-IN, as "Every escalated entry
reaches the serial remediator" below says: the lane remediators write PARTS that a second join
joins into their own record, and only the one fan-in remediator APPENDS to a joined record,
opening its entries with its own `- artifact:` / `- artifact_sha_before:` /
`- artifact_sha_after:` triple per file it edits, each before equal to the bytes the joins left. No two
agents ever append to one record. The join never overwrites a record, so it is run before the serial
remediators and never after them.

**Every escalated entry reaches the serial remediator.** A shard whose fix lies partly outside
its files writes two entries with one `source:` token, `repaired` and `escalated`. The join, in
every parts mode, prints one `ESCALATED: <part> <entry>` line per escalated entry, then
`ESCALATED-COUNT: <n>`, then `SERIAL-REQUIRED: <n>`, the count of `repaired` entries with a
real edit, each of which owes the cross-file sibling grep and moved-cite check below. In every
mode (files, sections, subject), dispatch the serial remediators after the join whenever
SERIAL-REQUIRED or ESCALATED-COUNT is above 0, whether or not any finding cited two files or
parts. The join partitions that work into LANES of FILES and prints them after SERIAL-REQUIRED:
`LANE-EDGES:`, one `LANE: <n> files: <file>... parts: <part>...` per lane with its
`LANE-ITEM: <n> <item>` lines, one `FANIN: <item>` line per item no single lane owns, then
`LANE-COUNT:` and `FANIN-COUNT:`. One part's files are one lane, and a `MOVED-CITE` the join's own
`serial-remediation-worklist.sh --keep` run finds (sections and subject mode; files mode has no
worklist) joins the two files it links. A `HIT` never joins lanes, and neither does an escalation:
one standing in, or naming files of, two or more lanes, or naming no lane's file, is a `FANIN`
item. `LANE-EDGES: UNASSESSED` means the worklist did not run clean and every file is one lane.
The join also prints `LANE-ARTIFACT: <lane artifact> --pass <M>`, the lane round's name derived
from round one's record name; copy LANE-ARTIFACT, never infer it from `--artifact` or `--subject`
(the subject party round's is `requirements-party-serial --pass 1`, not `requirements-serial`,
which names the subject pass-1 round's lane record).
Beside it the round-one join prints `LANE-ARTIFACT-PATH: <path>`, the lane join's `--artifact-path`
spelled as the write ledger spells it: the slot `<state basename>/planning-artifacts/s<N>` after a
files round, the assembled document after a sections round (project-relative when it lies outside the
state dir, `<state basename>/...` when inside it), the state basename after a subject round. Copy
LANE-ARTIFACT-PATH, never infer it from the slot, the state dir or the document's location. Below,
`<lane artifact>`, `<M>` and `<path>` are those lines' values.
Dispatch ONE serial remediator per lane, in parallel, each brief carrying its `LANE:` line, its
`LANE-ITEM:` lines and every `ESCALATED:` line verbatim, and the line `shard: none (authoring-chain)`
(Rule 28 exception 3: it reads the joined record the shards produced; commentary goes after the
closing parenthesis), as a second PARTS-MODE round: lane `<n>`
writes its part `s<N>/shards/<lane artifact>-repair-p<M>/lane-<n>.md` and edits only its lane's
files; the part opens with its own
`- artifact:` / `- artifact_sha_before:` / `- artifact_sha_after:` triple per file it edits, each
before equal to the bytes round one's join left, so Check 24 arm J2 chains the lanes between the
join and the fan-in. Beat-join the lanes with `--complete`
and run the same join over them, files mode, `--artifact <lane artifact> --pass <M>
--artifact-path <path>` (`<path>` copied from `LANE-ARTIFACT-PATH:`), so a file two lanes wrote, or one no lane cites, refuses exactly as in round
one; it writes `s<N>/<lane artifact>-repair-p<M>.md` and prints no `LANE:` line. Then dispatch
ONE fan-in serial remediator, briefed with the same `shard: none (authoring-chain)` line, every `FANIN:` line and every `ESCALATED:` line the
lane join printed, which appends to that record as above. A round whose join prints `LANE-COUNT: 1` and `FANIN-COUNT: 0`
is one lane with no fan-in. In `--sources` mode the
`ESCALATED:` lines are the lead's to adjudicate, never a re-dispatch of the serial remediator:
that record may be the serial remediator's own, so no SERIAL-REQUIRED line is printed there, and
no `LANE:` or `FANIN:` line. An
escalated entry is closed only by a later `repaired` entry carrying `- closes: <part> <entry>`
copied from its `ESCALATED:` line, never by a shared `source:` token; the join prints each closed
one as `ESCALATED-CLOSED: <part> <entry>`. After the serial remediators finish on a record that
has no party seat files (an adversarial, elicitation or gate repair), the lead runs
`scripts/ai-dlc/join-remediator-shards.sh --escalations <the joined record> [--escalations <its -serial-repair record>] --sprint <N>`,
round one's record FIRST, because a lane closes round one's escalations in its own record and
closure is read in order; the join refuses a round-one record whose lane record is on disk and
not passed after it. It reads the `closes:` lines with no `party-mode/s<N>/` directory and prints
every escalation still open; each open one is the lead's to adjudicate. A party record takes
`--sources` the same way, which does the same. The join also refuses a `repaired` MAJOR or CRITICAL whose claim sets part of the
fix aside as outside the shard or not required without naming a hand-off, and, in every parts
mode, a `repaired` entry with an edit whose `siblings:` field is absent or in none of its four
forms, and a siblings fence whose control text is not in the file it names.

After a join refusal naming a file `which no dispatched agent wrote`, or a file `written by more
than one agent in the window`, or a part whose entry `sets part of the fix aside` and names no
hand-off:

1. Re-dispatch that shard, writing through Edit, Write or MultiEdit, and re-run the join. The
   join lists every reason it refused; clear each one.

1b. **Re-run one part with `--rerun`.** When the refusal is confined to one part's files, re-run
   that part alone and run the join again.
   Keep the refused join's `--since <ISO>`, take a NEW `--until <ISO>` after the re-run part reports, and add `--rerun <part>.md@<S_P>`;
   S_P falls inside that window. This holds in files, `--document` and `--subject` modes alike.
   The re-run is a NEW dispatch with a new agent id, never a continuation of the refused part's agent: the join
   refuses a re-run writer that is one of the writers it supersedes, or that wrote any other part's
   file or record in the window. The re-run writer rewrites the part's own record
   `<repair-dir>/<part>.md` after S_P, and the join refuses that record written after S_P by anyone else, or not at all by the re-run writer.
   When the cure is a record change only (the set-aside refusal above is one), the brief tells the re-run to rewrite
   the record and nothing else, and never to make an edit no finding asked for. The join reads that re-run as
   RECORD-ONLY: no cited file written after S_P, so the earlier writes on them stand, and the record's one writer after
   S_P is the re-run writer. It refuses a record-only re-run whose record has more than one writer after S_P, or whose
   writer also wrote the part's files before S_P.
   Its brief requires the re-run remediator to account for the whole section diff against the split slice
   (in files mode, against the bytes the pass reviewed), not only its own edits, because the earlier
   writer's bytes stay in the file and the re-run part's account is all that covers them.
   The lead picks S_P by reading `date -u +%Y-%m-%dT%H:%M:%SZ` after the refused part's writer has stopped and immediately before sending the re-dispatch,
   so every earlier write on that part's files falls before S_P and the re-run's first write falls at
   or after it. A refusal naming a superseded writer that also wrote outside the part's files, or
   wrote at or after S_P, is a finding to adjudicate, never a timestamp to move.

2. Only if the operator approves in this session: hand-assemble the record, with a disclosure
   header naming every unledgered file and the refusal's lines.

**Shard by section (Rule 28, "Split dispatch": sections axis).** When the artifact is one
document, run `scripts/ai-dlc/partition-document.sh --map <artifact path>`. Exit 3 with a `SERIAL:`
line keeps ONE remediator with `shard: none (serial-document)` (Rule 28 exception 4), editing the
document in place. Otherwise, in this order:

1. **Split.** `scripts/ai-dlc/partition-document.sh --split <artifact path>
   _bmad-output/planning-artifacts/s<N>/shards/<artifact>-repair-p<M>/ --expect-sha <artifact_sha>`,
   where `<artifact_sha>` is the `artifact_sha` of the pass being repaired. It writes
   `<that dir>/sections/<ordinal>.md` and `<that dir>/sections/.manifest`, and it refuses when the
   document is not the bytes that pass reviewed or when `sections/` already exists.
2. **Parts.** Partition the findings by their `sections:` line. A finding citing one section goes
   to that section's shard; a finding citing two or more goes to ONE serial remediator after
   assembly (step 4), which is dispatched as "Every escalated entry reaches the serial
   remediator" says, not only for such a finding, and whose brief carries
   `shard: none (authoring-chain)`. Each shard's brief carries `shard: <ordinal>/<K> <heading>`, the full path of
   its section file, that part's first-line offset from the map (a finding's document line `L` is
   line `L - first + 1` of the section file), and the part path `<that dir>/<ordinal>.md`. A shard
   edits ONLY its section file, never the document, and every `edit:` line cites that section
   file by its full path. A `derivation:` fence in the part names the DOCUMENT by its
   project-relative path, never the section file, because assembly removes the section file
   before the derivations validator re-runs the fence.
3. **Join and assemble.** Beat-join every part with
   `scripts/ai-dlc/wait-for-deliverable.sh --complete --since <round epoch> --dispatch <agentId> <part path>...`
   (one `--dispatch` per agent the round joined), which takes a part as delivered only once it
   ends in the `seat-complete:` line its remediator's `--mark` wrote. An UNFINISHED part whose body is complete and carries no `seat-complete:` line was written before parts marked: read it, then `--mark` it or re-dispatch its part. Then run
   `scripts/ai-dlc/join-remediator-shards.sh --document <artifact path> <that dir> --since <ISO> --until <ISO>`.
   When one section's remediator was re-run, add `--rerun <part>.md@<S_P>` as "After a join
   refusal" item 1b says.
   `--artifact-path` is refused in document mode: the section files under `<that dir>/sections/`
   are the file set, so a section written by two agents, an
   uncited section or a section cited by two parts refuses exactly as a file does. The join then
   runs `partition-document.sh --assemble <that dir>`, which refuses when the document moved since
   the split, a section is missing or a foreign file is present; on any refusal the join exits 2
   and writes neither the document nor the record. Otherwise the document is written atomically
   from the sections, the manifest records the assembled sha, the section copies are removed, and
   the join writes the one repair record.
4. **Cross-section.** The serial cross-section remediator then edits the ASSEMBLED document in
   place and APPENDS its entries to the joined record, opening them with its own `- artifact:` /
   `- artifact_sha_before:` / `- artifact_sha_after:` triple, its before equal to the join's after.
   Before that dispatch the lead runs `scripts/ai-dlc/serial-remediation-worklist.sh <that dir>`
   once, as the subject-axis step 4 below describes, and briefs the remediator with its output.

**Shard the requirements subject's repair (Rule 28, "Split dispatch": subject axis).** When the
artifact is the requirements subject (`steps/requirements.md` section 5), the repair is sharded
by the subject map, with the base read from the subject manifest. A subject that maps to one
part keeps ONE remediator with `shard: none (serial-document)` (Rule 28 exception 4). Otherwise,
in this order:

1. **Split.** `scripts/ai-dlc/partition-subject.sh --split <N>
   _bmad-output/planning-artifacts/s<N>/shards/requirements-repair-p<M>/ --base <base sha>
   --expect-sha "<stem>=<sha> ..."`, naming every subject stem once with the sha the pass being
   repaired reviewed (or `--expect-sha @<file>` holding that list). Write the separator as `@`
   only if `scripts/ai-dlc/merge-adversarial-shards.sh --pair-sep` prints exactly `@`, otherwise
   `=`; both are accepted. It delegates per file and
   writes one section file per part of a file mapped into sections, under
   `<that dir>/<stem>/sections/`; it
   refuses when any subject file is not the bytes that pass reviewed. A WHOLE-FILE part — the
   SPEC always, and any file whose scoped map is SERIAL — is not split: it has no section copy,
   its one shard edits the file itself, and its expected bytes are that stem's sha.
2. **Parts.** Partition the findings by their `sections:` line. A finding citing one part goes
   to that part's shard; a finding citing two or more goes to ONE serial remediator after
   assembly, which is dispatched as "Every escalated entry reaches the serial remediator"
   says, not only for such a finding, and whose brief carries `shard: none (authoring-chain)`.
   A section part's shard edits ONLY its section file, as "Shard by section" step 2
   describes. A whole-file part's shard edits its file in place. The SPEC part's shard never
   edits `SPEC.md` by hand: it appends a `(decision)` entry to the spec's `.memlog.md` and
   re-renders `SPEC.md` through `bmad-spec` (the amendment procedure's item 2 path, "Divergence
   resolution dispatch"). It then appends one
   `- (event) Render <pass>: re-derived from memlog through <last decision>` line to `.memlog.md`;
   a change applied with Edit is recorded as `- (event) Hand-edit <pass>`, never as Render. A
   `(decision)` entry after the last such Render line is a stale SPEC, and the join refuses it. Its `edit:` lines cite
   both files by their project-relative paths under `_bmad-output/specs/s<N>/<slug>/`.
3. **Join and assemble.** Beat-join every part with
   `scripts/ai-dlc/wait-for-deliverable.sh --complete --since <round epoch> --dispatch <agentId> <part path>...`
   (one `--dispatch` per agent the round joined), which takes a part as delivered only once it
   ends in the `seat-complete:` line its remediator's `--mark` wrote. An UNFINISHED part whose body is complete and carries no `seat-complete:` line was written before parts marked: read it, then `--mark` it or re-dispatch its part. Then run
   `scripts/ai-dlc/join-remediator-shards.sh --subject <N> --base <base sha> --pass <M> <that dir> --since <ISO> --until <ISO>`.
   When one part's remediator was re-run, add `--rerun <part>.md@<S_P>` as "After a join
   refusal" item 1b says.
   The file set is the four subject files, the spec's `.memlog.md`, and the section copies; a
   file written by two agents, an uncited file or one cited by two parts refuses, and a write to
   subject text outside the in-scope parts refuses. It then reassembles each file that was split
   through `partition-subject.sh --assemble`, which refuses when such a file moved since the
   split (a whole-file part is not reassembled), and
   writes the one record `_bmad-output/planning-artifacts/s<N>/requirements-repair-p<M>.md`,
   whose `artifact:` is the subject manifest and whose sha lines are per-stem `<stem>=<sha>`
   lists. The join writes `@` only if `scripts/ai-dlc/merge-adversarial-shards.sh --pair-sep`
   prints exactly `@`, otherwise `=`; both are accepted.
4. **Cross-part and out-of-scope.** The serial remediator then edits the ASSEMBLED files in
   place and APPENDS its entries to the joined record, opening them with its own `- artifact:`
   (the subject manifest) and per-stem `- artifact_sha_before:` / `- artifact_sha_after:` lists,
   every stem on both sides, each before equal to the join's after. It owns every finding citing two or more
   parts AND every finding whose fix lies in PRD text outside the in-scope parts — a part shard
   never edits text outside its section file, so such a finding has no other owner.
   After the join and before that dispatch, the lead runs
   `scripts/ai-dlc/serial-remediation-worklist.sh <that dir> --record <the joined record>` ONCE
   and puts its output in the serial remediator's brief. The join's own worklist run (the lane
   edges) passes `--keep`, so this run is the lead's one consuming run, not a second one. It lists the text each shard replaced
   with every place that text still stands (`HIT`), and every cite into a repaired file whose
   line moved (`MOVED-CITE`); the remediator adjudicates those lines rather than deriving them.
   The run consumes the pre-repair copies it reads, so a later run exits 3 `UNASSESSABLE`
   unless the run before it passed `--keep`. A files-mode repair has no split directory, so
   the script exits 3 there and the remediator runs the grep itself.

The party and elicitation repairs run this same procedure, under the shard dirs and record
names "Validation cycle" items 1 and 2 give them. For the requirements subject they take
`--pass party` and `--pass elicitation`. On the files and sections axes they take
`--artifact <artifact>-party --pass 1` and `--artifact <artifact>-elicitation --pass 1`: outside
the subject the join reads `--pass` only as a pass number, and refuses `--pass elicitation`
there. The requirements gate's FAILURE repair runs it with `--artifact gate-<type> --pass <M>`
(`<type>` the gate type, `<M>` numeric), splitting into
`s<N>/shards/gate-<type>-repair-p<M>/` and joining into `s<N>/gate-<type>-repair-p<M>.md`, the
name the non-subject gate caller writes; `--pass party`, `--pass elicitation` and `--artifact`
are never combined. The subject's `requirements-party-repair.md` and
`requirements-elicitation-repair.md` sit outside `*-repair-p<M>.md`. The files- and
sections-axis records (`<artifact>-party-repair-p1.md`, `<artifact>-elicitation-repair-p1.md`)
and the gate record sit inside that glob; arm H of `validate-adversarial-convergence.sh` reads a
record whose name does not carry the series' stem as another repair's (a party or elicitation
round, or a gate repair), so none of them stands in for an adversarial pass's repair record.

It writes the repaired artifact in place plus a **repair record** (`<M>` = the pass repaired) at
`_bmad-output/planning-artifacts/s<N>/<artifact>-repair-p<M>.md` when the caller is an
adversarial pass, or at
`_bmad-output/planning-artifacts/s<N>/gate-<type>-repair-p<M>.md` when the caller is a gate
failure. Both open with `- artifact:`, `- artifact_sha_before:` and `- artifact_sha_after:` —
the repaired file and its whole-file sha256 on each side, as `team-roles/remediator.md` teaches.
A serial remediator appending to a joined record opens its entries with its own such triple,
its before equal to the join's after, so Check 24 arm J2 chains the join and the serial edit.
Per finding — or per failed check — the disposition, the edit site, and the command
that derives every factual claim the repair asserts, with its output. The next adversarial pass
verifies against that record; so does the gate's re-run of the failed checks.

**Repair record name, again.** The adversarial repair record is `<artifact>-repair-p<M>.md` with no round word, never `<artifact>-adversarial-repair-p<M>.md` or `<artifact>-adversarial-p<k>-repair-p<M>.md`, whether a join or a serial remediator writes it; the join refuses the first of those wrong shapes.

**Join** with the bounded-join beat (above): `scripts/ai-dlc/wait-for-deliverable.sh --complete-repair
--dispatch <agentId> <repair_record_path>`. The serial remediator and the
unsharded `shard: none (serial-document)` remediator both end their record with
`<lead engine>/wait-for-deliverable.sh --mark-repair <record> <pass>`, which appends `repair-complete: serial
<pass> sha=<hex>`, the line only `--complete-repair` waits for. A remediator dispatched worktree-isolated carries `<lead engine>`, the LEAD checkout's `scripts/ai-dlc` path, in its brief and runs `--mark-repair` from it, never from its worktree; otherwise `scripts/ai-dlc` is the lead's engine. A part remediator closes its part
with `--mark` instead, and each axis's join step above beat-joins those parts with `--complete`
before the shard join runs; the joined record the shard join writes is written by that join,
synchronously, and needs no beat until the serial remediator appends to it. A serial
remediator whose block appended a `(decision)` entry to a spec's `.memlog.md` re-renders
`SPEC.md` and appends its `- (event) Render <pass>: re-derived from memlog through <last decision>`
line before its `--mark-repair`, so the render lies inside the dispatch this beat joins; the lead
dispatches no separate render agent.

**A completed record is never reopened by `SendMessage`.** Once a remediator's record carries its
`repair-complete:` line, that remediator is finished, and it may not edit the record again
(`remediator.md`). When the join, a refusal or a later check needs more repair on that record,
`TaskStop` the resident remediator and send ONE fresh `Agent` dispatch, whose brief names the open
work and which appends a new block that opens with its own triple and ends in its own
`repair-complete: serial <pass> sha=<hex>` line, written by `--mark-repair`. Join that dispatch with its own `--dispatch <agentId>`.
Never resume the finished remediator with `SendMessage`, even to deliver a refusal: it can either
leave the work undone or finish it by editing past its own completion line.

SKILL.md Rule 32 touchpoint V1 applies once the repair record is joined, before the next pass.
Once the join is accepted, commit the repaired subject files (`git add` and `git commit`) before
the next pass dispatches, so a later stop cannot blur joined edits with in-flight ones.

**Then re-run the derivations, BEFORE dispatching the next pass:**

```
scripts/ai-dlc/validate-artifact-derivations.sh <the joined repair record>
scripts/ai-dlc/validate-artifact-derivations.sh <assembled document path>
scripts/ai-dlc/report-propagation-fanout.sh <base-ref>
```

Every re-run names a FILE and never the slot directory. Run
`validate-artifact-derivations.sh <the joined repair record>` on the joined record itself,
then on the assembled document (for the requirements subject, each of the manifest's four files:
`prd.md`, `product-brief.md`, `architecture-impact.md` and `SPEC.md`), and on the spec's
`.memlog.md`; a repair that edited another record names that record as a file target too. A
directory target skips the frozen shard and seat records no remediator may edit, so it cannot
reach the cites a repair moved.

The second line applies to a section-sharded repair and names the ASSEMBLED document: a fenced
command that reads its own file measured a section copy while the shard ran, so only the
assembled bytes answer, and a line-number self-reference is falsified by any edit above it.
Run it after the join and after the serial cross-section remediator.

**Moved cites are the serial remediator's, after the join.** A `<file>:<n>` cite into a region a
shard's edit shifted cannot be checked inside that shard: a section shard sees only its copy.
The serial remediator re-reads every cite into each edited file AFTER the join or assembly,
before these validators run, and repairs any that moved as its own entry. It also owns the
cross-file sibling grep: a shard's siblings fence greps only its own files (a concurrent shard
fixing a copy elsewhere would turn it stale), and a section or subject shard writes `siblings:
n/a (section shard; ...)`, so for every `repaired` shard entry with an edit, and every
escalated sibling line, the serial remediator runs `grep -rn -F '<the text that entry
replaced>'` over the ASSEMBLED files (`s<N>/stories` and `s<N>/epics`, or the document), never the
slot, `shards/` or a record, and records it as its own entry with a `siblings:` fence. That is
why SERIAL-REQUIRED dispatches it: a round whose every finding stayed inside one shard still
owes this grep. A lane remediator runs it for its lane's entries and edits only its lane's
files; a hit in another lane's file is the fan-in's `FANIN:` item, and the fan-in remediator, after
every lane has joined, runs the grep once more over the assembled files for the text each lane
replaced, because a lane's edit can leave a hit in another lane. After a sections or subject join the lead's `serial-remediation-worklist.sh`
output (the subject-axis step 4 above) is the starting list for both the grep and the cites.

Owed derivations are refused at gate-validation.md Check 37, not here.

Exit 1 from `validate-artifact-derivations.sh` on one of those file targets is a repair that falsified a
derivation — most often not its own, but one
elsewhere in the artifact set that was counting the thing this repair moved. Send it back to
the remediator now. Exit 2 is NOT a finding: an `UNRUN:` or `REFUSED:` line names a
derivation the checker could not run or compare, and nothing in the artifact is wrong. Re-run
the validator; never send an exit 2 to the remediator. Exit 1 costs an exit code here and a full review-and-repair round trip if it
reaches the adversary instead: measured across four sprints of this pipeline, **78% of the
MAJOR findings raised at pass 2 and later were introduced by a prior repair**, and the single
largest sub-shape is a derivation that was correct when written, was never re-run after a
later edit, and was rediscovered one pass downstream by an Opus agent running the same
command the artifact already carried.

Run the same command after the AUTHORING step too, before the cycle's first pass — the same
staleness reaches pass 1 from the step that wrote the artifact.

`report-propagation-fanout.sh` finds the dependents no derivation fence covers: it prints an
**advisory worklist** of every `` `path:N` `` citation in the mutable current-sprint corpus
whose target this repair line-shifted. `<base-ref>` is the sha this pass's repair started from;
pass it alone and the diff runs against the WORKING TREE, which is where an uncommitted repair
is. Hand the worklist to the remediator with the next pass's set. It is not a gate verdict and
no exit code of it adjudicates a gate.

Its exit codes say whether it could LOOK, never what it found. **0** means the scope resolved
and the worklist is meaningful even when empty. **3** means it never established one, so it
resolved to the wrong tree and the empty worklist beneath it states nothing about your
artifacts; **2** means usage, an unresolvable ref, or not a git repository, and judges nothing
either. On 3, fix the scope and re-run: do not send it to the remediator, and do not read it as
a clean corpus.

**The lead keeps** dispatch, the join, and the **Rule 11/13 scope calls** the remediator
escalates (cut-versus-fix, `LOCKED_REQUIREMENTS`, anything changing what the sprint delivers).
Those are decisions, not edits.

## Auto-handoff evaluation (referenced by step files)

Step files invoke this helper at each safe seam defined in SKILL.md
Handoff Protocol "Auto-handoff (configurable via `auto_handoff_mode`)".
When a step file says "run auto-handoff
evaluation at Seam <X>", execute this procedure. The outcome is
either CONTINUE (no-op — the step resumes normally) or FIRE (the
lead executes the Rule 2(a) handoff and the session ENDS). This
helper MUST NOT be invoked from inside the `gate-validation.md`
Check 1–15 sequence; it is only called from step files at the defined seams.

Every defined safe seam is a clean step/sub-step boundary. Auto-handoff
MUST fire only at such a boundary; it MUST NOT fire mid-sub-step.
Auto-handoff is NOT a fifth Rule 3 pause point — it is a
session-terminating action that executes the path (a) procedure
(`steps/handoff.md`) unchanged.

**Inputs:** the seam name (`Seam A` through `Seam E`; `Seam E` is the
retro-entry seam at `retro.md` Step 1 pre-flight, before party mode) and
a short human-readable
label for the distinguishing
output line (e.g., `deploy-validate Step 0 pre-flight`,
`implementation story transition`,
`architecture adversarial pass 2`).

**Evaluate preconditions in this order. The first failing
precondition returns CONTINUE immediately — no fire, no side
effects, the step resumes.**

1. **Mode gate.** Read `AI_DLC_AUTO_HANDOFF_MODE` from
   `.claude/settings.json` "env"; unset means `off`. If `off`, return
   CONTINUE. If `deploy-only` and the seam is not `Seam A`, return
   CONTINUE. If `safe-seam`, all defined seams (`Seam A` through
   `Seam E`) are permitted.

   **Then the exclusion gate.** Read `AI_DLC_AUTO_HANDOFF_SEAMS_EXCLUDED`
   — a comma-separated list of seam letters, unset meaning none. If this
   seam's letter is in it, return CONTINUE regardless of mode. A project
   that has ruled a particular seam unsafe declares it here rather than
   shadowing this procedure, because a shadow freezes the whole span and
   an exclusion is the only part it actually disagrees with.

   Proceed to precondition 2.

2. **Trigger basis (mode-dependent).** Exactly ONE of 2a / 2b applies:
   the one naming your `auto_handoff_mode`. Read that sub-item and stop.
   The other mode's rule does not apply to you. Applying the other
   mode's condition returns CONTINUE at every seam, which disables
   auto-handoff while the mode still reports itself on — indistinguishable
   from a mode whose seam was never reached.

   **2a. Under `safe-seam`** — the seam itself is the trigger. Only the
   token *magnitude* is advisory: how many tokens are in play does not
   gate the fire. The seam being reached IS the firing condition, so
   **skip the red check entirely** and proceed to precondition 3. There
   is no measured-red requirement in this mode; 2b does not apply.
   "Advisory magnitude" does NOT mean the handoff is optional — once a
   defined seam is reached and preconditions 3–7 pass, the fire is
   mandatory, not a judgment call about whether the context feels large
   enough.

   **2b. Under `deploy-only`** — require **measured red**: read
   `last_level` from `_bmad-output/.context-sensor-state` (authoritative
   and current every turn; fall back to `context_reminders_sent` in the
   snapshot Context Reminders block if the sidecar is absent). If it is
   not `red`, return CONTINUE. The sensor sets `red` only from a real
   measurement of resident context — Claude Code's own figure, read off
   the transcript — so this precondition is equivalent to "red threshold
   measured, not estimated". There is no estimate path: the sensor is
   silent when it cannot measure.

3. **Snapshot is current.** Read the most recent Recent Activity
   entry. If it does not reflect either (a) the gate passage that
   most recently ran Check 15, or (b) the sub-step snapshot update
   preceding this seam, run the sub-step snapshot update now and
   re-read. If the update fails or Recent Activity still does not
   reflect the preceding sub-step, return CONTINUE — firing
   auto-handoff on a stale snapshot would produce a broken resume
   contract.

4. **No gate validation currently executing.** This precondition is
   satisfied by-construction: step files MUST NOT invoke this
   helper from inside the Check 1–15 sequence. If the caller is
   inside Check 1–15, return CONTINUE — treat as a caller bug.

5. **No deployment currently executing.** This precondition is
   satisfied by-construction: Seam A runs at `deploy-validate.md`
   Step 0, before Step 1. No other seam runs during
   `deploy-validate.md` Steps 1–5. If the caller is between Step 1
   and Step 5, return CONTINUE.

6. **No teammate awaiting lead orchestration response.** Check the
   task list for in-progress tasks that are blocked on a lead
   mediation or response. Inspect recent teammate messages
   awaiting the lead. If any teammate is awaiting a response,
   return CONTINUE — firing handoff while a teammate is blocked
   would strand the teammate.

7. **Not at any Rule 3 pause point.** Verify the lead is not
   currently in ambiguity resolution, the Production Validation
   Checkpoint, the retro commentary prompt, sprint-scope
   confirmation, or the post-compact verification turn. If any
   pause point is active, return CONTINUE.

**These seven preconditions are EXHAUSTIVE — there is no eighth.**
User activity, user presence, the recency of a user message, or the
absence of an explicit stop request is NOT a precondition and MUST NOT
be treated as permission to return CONTINUE. Specifically, "the user
has been active this session but did not share `/context`, so I may
continue unless they intervene" is a PROHIBITED rationalization: it
invents a precondition that does not exist and inverts the contract
(the fire is the default at a passed seam, not something the user must
opt into). The token magnitude being advisory (precondition 2) governs
only *how large* the context is — it never converts the fire itself
into a discretionary call. If all seven preconditions pass, the outcome
is FIRE; the lead does not get to weigh whether a handoff "feels"
warranted. This applies identically under `safe-seam` and `deploy-only`
(under `deploy-only`, precondition 2's Mode-1 red requirement is itself
one of the seven — once it and the rest pass, the same
no-rationalization rule holds).

If all seven preconditions pass, FIRE auto-handoff. This is the
Rule 2(a) handoff procedure (canonical base in `steps/handoff.md`),
repeated here as the auto-handoff variant — the distinguishing output
line in step 4 identifies this handoff as automated, and steps 3/5
carry the no-human-present additions:

1. **Stop all in-flight teammates first.** Before calling `TaskStop`, run
   ONE bounded-join beat ("Bounded-join beat" above) over every
   **In-Flight Teammates** row whose `status` is `in-flight` and that names
   a deliverable path: one call per kind of deliverable, each
   `run_in_background: true` — `scripts/ai-dlc/wait-for-deliverable.sh <path>
   [<path> ...]` for a plain deliverable, `scripts/ai-dlc/wait-for-deliverable.sh
   --complete <path> [<path> ...]` for seat, shard, cross and repair-part files, epic part files and
   for a teammate's markdown result file whose dispatch's spawn-ledger row carries
   `"mark":"rendered"` (the scope "Bounded-join beat" states), and
   `scripts/ai-dlc/wait-for-deliverable.sh --complete-repair <record>` for a
   serial-remediator row. The flag is per call and a call mixing the two flags
   is refused (exit 64), so a mixed set is up to three calls and a set of one
   kind is one. End this turn on the armed beats and resume this step when
   every one has returned. A row
   whose deliverable is DELIVERED in that beat is joined normally — apply
   the sub-step snapshot update's handling (`status: delivered-reachable`,
   or delete the row outright), never `stopped`. Only rows still absent
   after the beat get `TaskStop`. `steps/handoff.md` step 1 owns why.

   Call `TaskStop` on every `in_progress` task still absent after the beat.
   Halt any Agent-spawned teammate not bound to a task. Wait until every
   teammate has returned before proceeding. Record stopped teammates and
   in-flight artifacts in the snapshot's Open Items in Step 3, and set each
   stopped teammate's **In-Flight Teammates** row `status` to `stopped` —
   rewrite the row, never delete it. Record the `TaskStop` task id in each
   stopped row's agent cell. For each stopped row, run
   `scripts/ai-dlc/join-remediator-shards.sh --agent-writes <task id>` and
   write its output into the snapshot's Open Items as that agent's
   unrecorded partial edits, never inferring them from `git status`.
   `steps/handoff.md` step 1 owns why. Where `ai-dlc-continue.sh` Check 0 is armed it blocks the stop
   while any row still reads `in-flight`, deferring only while a beat's
   `.beat-inflight` lease is live.
2. `git add` and `git commit` any in-flight work, including work
   teammates left in the working tree.
3. Finalize the pipeline snapshot — one last update capturing
   in-flight state, current sub-step, and the stopped-teammate
   record from Step 1. Commit the finalized snapshot if the project
   tracks `_bmad-output/`, then push the current branch to origin
   (`git push -u origin HEAD`) so the Step 2 commit and the finalized
   state reach the remote and are not stranded on this machine.
   SKILL.md Rule 32 touchpoint I applies before the push.
   A directed handoff authorises this push; the lead does not ask the operator for a go-ahead again.
   **Never `--no-verify`**: the pre-push hook runs on every pipeline push, whatever the change
   set, and `ai-dlc-advisor-gate.sh` denies the flag.
   For an auto-handoff no operator directed the push: the seven preconditions above authorise
   it, and there is no operator to ask.
   **`-u origin HEAD`, never a bare `git push`** — a bare push cannot
   succeed on a branch that has never been pushed, which is every
   sprint's FIRST auto-handoff wherever a branch is cut per sprint.
   `steps/handoff.md` step 3 owns the full reason and it is not
   restated here.

   **EVERY `git push` IN THIS PIPELINE RUNS WITH AN EXPLICIT 10-MINUTE
   TIMEOUT — `timeout: 600000` on the Bash call — AND IN THE FOREGROUND.**
   The pre-push gate runs the whole fixture suite, and the default tool
   timeout is 2 minutes. Measured on the reference consumer: 148.9s, of
   which 130.9s is the suite. A push that exceeds the default is SIGKILLed
   at `Exit code 143`, which looks like a failed push and is not one — the
   gate was still running, so nothing is known about whether it would have
   passed. **Do not background the push to dodge this.** A backgrounded
   push invites moving on before its result arrives; a push is a
   mutation, so the next step would be acting on a remote state that
   does not exist yet. **The push is the whole command — `git push -u
   origin HEAD` and nothing chained, piped or redirected after it.** Its
   exit code is in the tool result; a `; echo $?`, a `| tail` or a
   redirect-then-read is not needed, a pipe replaces the push's exit
   code with the last command's, and a chained push is denied by the
   steering-budget hook.
   If the push was moved to the background, do not issue another; end the
   turn and wait for its notification.

   If the push fails (no
   remote configured, offline, or a protected branch), note the reason
   in the auto-handoff line and continue; the local commits still stand
   and the handoff is not blocked. **Those three are ENVIRONMENTAL and
   are the whole of what this fallback covers. A branch that cannot be
   published is not one of them**, and routing it here reports success
   over a sprint's output left in git nowhere. "The local commits still
   stand" is also false whenever Step 2 was skipped, so verify Step 2
   landed before relying on it.
4. Output the distinguishing auto-handoff line (substitute mode,
   seam label, and trigger basis), then output the resume prompt
   (SKILL.md Handoff Protocol template) wrapped in `----` delimiter
   lines. The trigger basis depends on mode: under `safe-seam` it is
   `seam trigger (token threshold advisory)`; under `deploy-only` it is
   the confirmed token count from the most recent user-shared `/context`:

   > *"Auto-handoff triggered by auto_handoff_mode=safe-seam at Seam E
   > (seam trigger, token threshold advisory)."*

   > *"Auto-handoff triggered by auto_handoff_mode=deploy-only at
   > Seam A. Context at <tokens> tokens, red threshold confirmed via
   > user-shared /context."*

   The resume line is the bare `/ai-dlc resume` (the successor reads the
   snapshot for all state). Then
   `mkdir -p _bmad-output/.driver && touch _bmad-output/.driver/handoff` —
   the driver's zero-content handoff signal. **The `touch` is
   unconditional**; `steps/handoff.md` step 4 owns why.

5. Create the pause flag so the continuation hook allows this
   auto-handoff to end the session (an autonomous handoff has no user
   message to set it): `touch _bmad-output/pipeline-paused.flag`, and clear the
   entry marker from the preamble: `rm -f _bmad-output/.handoff-in-progress`.
   Then end the session — do not continue the pipeline in this conversation.
   Reply to any further messages with a pointer to the snapshot and the
   resume prompt. Resume itself is NOT automated: the user MUST open a
   new conversation and paste the resume prompt.

A FIRE outcome does not return control to the calling step. A
CONTINUE outcome returns silently — the step proceeds with its
next directive (typically the `gate-validation.md` call, the next
adversarial pass, or the next story transition orchestration).

## Context reminder threshold check (referenced by Check 14)

Invoked by `gate-validation.md` Check 14 at every gate. It reads and
updates the Context Reminders fields defined in Check 14's seven-section
snapshot schema (which stays resident); the evaluation mechanics below do
not.

**Context reminder threshold check (required at every gate):**

Read the Context Reminders block from the snapshot. If any required
field is absent (e.g., snapshot predates this rule), initialize
missing fields before proceeding: `context_reminders_sent: none`
and each `last_*_fire_tokens`/`last_*_fire_turns` to `null`.

The active thresholds are DERIVED by the sensor from the resolved
effective window — each band is a clamped percentage of the window, a
bounded lead below the ceiling (`effectiveWindow - 31,000`), not read
from a table. At a 200K window that lands at yellow 80K / red 120K; at
larger windows the bands scale with the ceiling, clamped. The sensor
records the level it fired in `_bmad-output/.context-sensor-state`.

The lead does not measure or estimate its own context window. The
`ai-dlc-context-sensor.sh` hook measures it every turn (Stop) and every tool batch (PostToolBatch) from the
session transcript, fires the Rule 2(b)/(c) reminder, and owns both
the dedupe and the recurrence arithmetic (50,000-token / 20-turn
delta). This gate check therefore **reads** the result; it does not
compute one.

Read `_bmad-output/.context-sensor-state`. It is a flat key=value
file:

```
last_level=none|yellow|red
last_fire_tokens=<int>
last_fire_turn=<int>
turn_counter=<int>
last_measured=<int>
model_family=FABLE|OPUS|SONNET|HAIKU|OTHER
window_declared=0|1
effective_window=<int>
window_source=<string>
```

Reconcile the snapshot's Context Reminders fields to it:

- `context_reminders_sent` := `last_level`
- `last_yellow_fire_tokens` / `last_yellow_fire_turns` := the
  sidecar's `last_fire_tokens` / `last_fire_turn` when `last_level`
  is `yellow`
- `last_red_fire_tokens` / `last_red_fire_turns` := likewise when
  `last_level` is `red`

If the sidecar is absent, the sensor has not fired this pipeline (a
fresh session, or context still below yellow). Leave the snapshot
fields at `none` / `null`. Do **not** substitute an estimate: a guess
beside an authoritative number is worse than silence.

If `window_declared=0`, no context window is declared for the lead
model's family and the sensor is assuming a 200,000-token ceiling,
because the model's context-window size is not recorded anywhere in
the transcript. yellow and red still fire on that assumption, so
reminders may fire early on a 1M model; `imminent` stays off until a
window is declared. `model_family` names the family the sensor
classified from the transcript's model id (`mythos` counts as
`FABLE`; an id naming no Claude family is `OTHER`). Declare each
family's window in the project's `.claude/settings.json` `env` block,
one integer token count per family (`1m`, `400k` and bare integers
are all accepted):

```
AI_DLC_MODEL_FABLE_WINDOW
AI_DLC_MODEL_OPUS_WINDOW
AI_DLC_MODEL_SONNET_WINDOW
AI_DLC_MODEL_HAIKU_WINDOW
AI_DLC_MODEL_OTHER_WINDOW
```

The sensor never infers or caches a window; a statusline-written
`window.json` for this session outranks the declaration when present.

Do **not** re-emit the reminder here. The hook already delivered it
to the lead as `additionalContext` on the turn it fired. A user reply
to a reminder is a Rule 11 directive handled on the next turn.

User-shared `/context` output remains valid as manual confirmation. If
the user shares it and it disagrees materially with `last_measured`,
trust the user, say so, and note the discrepancy in the retro — the
sensor reads Claude Code's own figure, so a real disagreement means
the sensor is broken.
