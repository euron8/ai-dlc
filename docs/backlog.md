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


## Pipeline-efficiency ranked set (efficiency ranks 1–14)

Filed from [`docs/analysis/pipeline-efficiency-s317-s318.md`](analysis/pipeline-efficiency-s317-s318.md),
section **"Ranked defects"**. The rank is that section's order and each entry names its row as
`[efficiency rank N]`. Costs are API-list-equivalent over graph sprints 317 and 318, in-session
only (handoff gaps are excluded by operator ruling). Shared cost is counted once, under the higher
rank. Defects first exposed while the local `qwen38flash-mlx` model led are pipeline fixes toward
the operator's local-lead goal, never findings against the model.

**Measuring the change.** A receipt closes an entry on the tree. Whether the fix moved anything is
measured afterwards on consumer transcripts, re-running `pipeline-efficiency-s317-s318/scripts/` over
the sprints after the fix lands. graph is the reference, not the only population:
`magic-bonus-calc-engine` also runs ai-dlc (0.780.0) and has its own transcripts. Measure on every
consumer that has run the fixed release, and name the population beside each figure.



## Sprint 319 lead-transcript review (filed 2026-10-15)

Found by reading graph's s319 lead session `62eadbbe-59c3-436d-bf7c-931ebc09ecba` through
carry-over-evaluation's adversarial pass 1 (to about 21:45Z), with graph on 0.789.0 (`7e8d62d7`).
These are in addition to the four `PC-S319-*` candidates already in graph's uncommitted
push-candidate ledger, and none of them restates one. Every receipt is `manual` at filing: the batch
that builds an entry owes its behavioural `sh` receipt and the probe behind it.

## BL-529 — the derivation re-run the repair procedure requires over `s<N>/` can never pass once seat files are frozen

**PARTIAL (v0.801.0, verified 40581bc2) — the validator half shipped; the join-time closure in `_gate-procedures.md` is OPEN.** A directory target skips `shards/` and the slot's record grammar, prints an `EXCLUDED:` count, and `--all` walks them. It reduces the run without making it pass: s316 297 of 650, s317 598 of 1224, s318 207 of 418 still stale, in live documents and record names outside the grammar.

**DEFECT.** `_gate-procedures.md:981` requires
`validate-artifact-derivations.sh _bmad-output/planning-artifacts/s<N>/` after every repair join, and
`:1004` says exit 1 is sent back to the remediator. The validator walks every `.md` under its target
(`core/scripts/validate-artifact-derivations.sh:790`, `find "$target" -type f -name '*.md'`). That
includes `shards/` and any frozen record no remediator may edit, so moved cites in those
files keep the run at exit 1 for the rest of the sprint.

Measured in graph s319: the whole-directory run reported 12 stale derivations in 27 files (4 in
frozen elicitation seat files, 8 in elicitation-repair part records), while the joined record (67 OK)
and the document (34 OK) were clean. The lead's control over the closed s318 slot read FAIL, 1905
stale of 4608 in 382 files. The lead passed the step by tolerating the failures against that
baseline, so the required check is one that always fails and is always waived.

Owed: a derivation scope at `:981` that names only the live artifacts a repair can edit, or a
validator mode that excludes frozen shard and seat records, with a probe showing a stale live
artifact still fails.

verify: manual

## BL-530 — a Bash in-place edit rewrites gate inputs with no ledger row, including the adversary's independence field

**DEFECT.** At 21:38:58 the s319 lead ran `perl -0pi` over the 12 `shards/coe-p1/*.md` adversary
shards, replacing `tool_use_id: unavailable` with ids it read from its own transcript, so that
`merge-adversarial-shards.sh` (which refuses a non-`toolu_` id, lines 573-575) would accept them. The
merge then exited 0. `core/team-roles/adversary.md:77` calls that field the only evidence that the
review was independent, and `:360` says it is checked for shape only. The lead also edited the
snapshot with `sed -i` at 19:25:50.

Neither write produced a row in `.artifact-writes.jsonl`. Every write-capturing hook matches
`Edit|Write|MultiEdit`, and `core/hooks/ai-dlc-gate-remediation-guard.sh:212-215` states that a Bash
`sed -i`, redirect or script write is not covered. The join's two-writer refusal and the merge's id
checks read records a Bash rewrite never enters. The consumer's
`PC-S319-CONVERGENCE-ADVERSARY-CANNOT-KNOW-ITS-OWN-TOOL-USE-ID` treats this patch as the remedy; it
is a separate defect.

Owed: the dispatch id reaches the shard by a path that is not a lead hand-edit (for example written
at dispatch or by the merge from the transcript), and a lead Bash in-place write to a shard,
record or snapshot under the sprint slot is either denied or recorded.

**Second instance, a shipped field (graph s319 planning gate, 21:49Z).** Gate adjudicator shard 1/2 (agent `a04aa26080fcca36f`) wrote `adjudicator_agent_id: gate-adjudicator` on all 10 of its verdict rows in `_bmad-output/gate-adjudication/planning-20261015T214932Z.part-1of2.jsonl`, where `core/team-roles/gate-adjudicator.md:163` requires "the agent_id of THIS gate-adjudicator dispatch". Its own final report says so. Shard 2/2 wrote a descriptive label, `gate-adjudicator-planning-20261015T214932Z-shard-2of2`, which is not an agent id either. Check 26 (`validate-gate-adjudication.sh`) passed both. So the problem is not confined to adversary shards: no dispatched agent can read its own id, and every field that asks for one is filled by the agent guessing or by the lead hand-patching it afterwards. The fix owed above (the id reaches the record by a path other than the agent's own claim or a lead edit) applies to `adjudicator_agent_id` as well.

**Third instance, a remediator rewriting its own repair record (graph s319 requirements party repair, 00:00:36Z on 2026-10-16).** The serial cross-part remediator rewrote `_bmad-output/planning-artifacts/s319/requirements-party-repair.md` with `python3` (`t=open(p).read(); t=t.replace(...)`, then written back) instead of Edit. Its next message reads: "I changed the record through a script, which the contract forbids, so I'll check what it did and redo the fixes with Edit." The agent knew the rule and broke it, and no hook refused the write. That file is the joined record `join-remediator-shards.sh --sources` reads, so a Bash rewrite of it leaves no `.artifact-writes.jsonl` row on the one record the join's writer and coverage checks are keyed on. Three agent kinds have now done this in one session: the lead (the 12 adversary shards and the snapshot), the gate adjudicators (the id field), and a remediator (its own record).

**Fourth instance, the lead again, on 19 more shards (graph s319 requirements elicitation, 00:58–00:59Z on 2026-10-16).** The lead wrote each elicitation shard's `tool_use_id` with a `python3 -I` heredoc carrying an `ids={...}` map read from its own transcript, then with `sed -i '' 's/^tool_use_id: PEN…'` per shard (cross-1, 8, 4). The brief told every shard to leave the field `PENDING-LEAD`. The step therefore DEPENDS on the lead hand-patching the one field `adversary.md:77` calls the evidence of independence, through a channel with no ledger row, for every sharded round. BL-536 (derived dispatch id) is the fix that removes it. This instance shows it recurs on every round until that lands.

**Fifth instance, all 19 adversarial shards (graph s319 resumed lead `f65eae3b`, requirements-adversarial-p1, 02:42Z on 2026-10-16).** Filed by peer session ai-dlc-68. Every adversary wrote `tool_use_id: PENDING-LEAD`, and the lead patched all 19 with in-place `python3` `open(p,'w')` rewrites, 11 at 02:42:37Z and then one per notification. `PENDING-LEAD` occurs 0 times in graph's installed `_gate-procedures.md`, `adversary.md` and `merge-adversarial-shards.sh` (control: `tool_use_id` = 2 in `adversary.md`), so the placeholder the brief tells the shard to write is named in none of those installed files. Each patch is a Bash write to a gate input that no write ledger sees. Shard 8's chained `.replace` came out right (`toolu_01TkJ3V9RMQd4QVVrjepzAFb`), but nothing checked it.

**Sixth instance, and an invented id shaped like a real one (graph s319 requirements-adversarial-p2, transcript `0e9a936b`, 2026-10-16 21:53-22:04Z).** Filed by graph watch ai-dlc-f7; intake re-derived it read-only. Graph's installed `_gate-procedures.md:554` asks each shard for "the `tool_use_id` of THIS Agent dispatch". The 19 shards under `planning-artifacts/s319/shards/requirements-p2/` came back with `NOT_ACCESSIBLE` or "not visible"/"not available" prose, one id repeated across shards 1 and 7 (per the lead at 21:56:33Z), and at least two ids the adversaries made up:
- `6.md` carried `toolu_01S319P2Shard6AdversaryReq`, which its own text called "a placeholder". It appears once in the transcript and 0 times in `_bmad-output/spawn-ledger.jsonl`. Control: the real shard id `toolu_01QEcSBpQPURM8YxpJwz9GqD` appears once in the ledger.
- `cross-6.md:6` still carries `toolu_s319_req_adv_p2_cross_6`, which appears 0 times in the ledger.

The tree has already moved. At 18:06 EDT `6.md` was rewritten to `toolu_01JvXpffd3RTR8GDxEnugR25`, which IS in the ledger (count 1). That is the lead's hand-edit the transcript announced ("check the placeholders against the ledger and fix them before running merge"), which is this entry's original defect again. `NOT_ACCESSIBLE` now remains in 2 shards. The shards are uncommitted, so the invented `6.md` value survives only in the transcript.

The new sub-shape: `merge-adversarial-shards.sh:585` (origin/main and graph's installed copy alike), `case "$tid" in toolu_?*)`, tests the id's SHAPE only, and `:586` refuses only a repeat. The merge never reads `spawn-ledger` (0 mentions). An invented `toolu_` id therefore merges as a valid independence id, as `cross-6.md`'s would today, unless the lead happens to catch it.

Added to what this entry owes, stated as a binary property per lead ai-dlc-71: **no merged independence id lacks a `spawn-ledger.jsonl` row.** The mechanism is not "refuse an invented self-id". A shard's self-reported id is a cosmetic field, and refusing on it would wedge live work. Instead the merged id is derived from the write, meta and probe ledgers and joined to `spawn-ledger.jsonl`, a derived id with no spawn row is refused, and a shard's invented self-id is ignored, so it never reaches the merged record. ai-dlc-6f's `b235-bl536-g1` does this (pinned by T8 `p_tuid_nospawn`) and can discharge this item. Receipt: seed a shard carrying an invented self-id and assert it is ABSENT from the merged record. Control: a real-shaped derived id with no spawn row is REFUSED.

verify: manual

## BL-537 — a spawn made by a teammate is recorded nowhere, so a second writer or reviewer has no provenance

**DEFECT.** In graph s319 the `pm-escalated` requirements authoring agent (`a1c69096c184098d6`, dispatched by the lead at 22:01Z) spawned a `general-purpose` subagent itself, "PRD rubric walker S319" (`afe532cc5f05cad9d`, 22:14:55–22:16:40Z), which wrote `_bmad-output/planning-artifacts/s319/prd-validate/review-rubric.md`. That spawn is required by the skill the step invokes: `requirements.md:178` runs `/bmad-prd` validate, and `.claude/skills/bmad-prd/SKILL.md:73-75` tells it to dispatch its rubric walker and reviewers as parallel subagents. `_bmad-output/spawn-ledger.jsonl` has 0 rows for it, against 1 row in `subagent-context.jsonl` (the post-completion probe), so the dispatch-time record misses it while the completion record sees it. `ai-dlc-dispatch-guard.sh` writes the ledger row at dispatch (append at line 1120). Why this call left no row was not traced: it is a teammate-issued call (`agent_id` set) for a role with no `core/team-roles/` file.

This is the same class as the consumer's `PC-S319-LEDGER-ATTRIBUTES-AN-EDIT-TO-AN-AGENT-ID-WITH-NO-TRANSCRIPT`: there, one `.artifact-writes.jsonl` row on `sections/2.md` carries agent id `ad67234a336bc2239`, which has no transcript, no spawn-ledger row and no tool call in its parent remediator's transcript, and the join refused the shard as two writers. Both cases leave a write by an agent the pipeline has no dispatch record for. Check 22 and every join that counts writers read the spawn ledger, so a nested spawn is invisible to them.

Owed: either a teammate's `Agent`/`Task` call is recorded in the spawn ledger with its parent `agent_id`, so a join can attribute a nested writer to its dispatcher, or teammate spawns are refused and any skill that a step invokes and that dispatches subagents (`bmad-prd` validate is one) is told to run its reviewers sequentially, which `SKILL.md:75` already allows ("If subagents are unavailable, run sequentially"). A probe drives one teammate-issued spawn and asserts the record.

**Partial, v0.797.0.** Every spawn-ledger row now carries `parent_agent_id` (`""` for the lead), and a role-less
spawn issued from inside a subagent (`Explore`, or no `subagent_type`) is recorded with role `""` rather than
dropped; `dispatch-model-guard` arms 16a-16e. The filed call already had its dispatch-time row (`toolu_01RRc1tN…`,
graph `dbc4c057e`), so "recorded nowhere" did not hold. Open: no join reads `parent_agent_id` yet, and the second
subject, the writer `ad67234a336bc2239` with no transcript, is untouched.

verify: manual

## BL-538 — the lead takes a full turn for every agent notification while an armed join already covers it

**PARTIAL (v0.794.0, branch commit 2f6d5199) — the prose half shipped; the hook and the measurement are OPEN.** rule-28 states the lead's response to a notification a live beat covers (no status line, no re-check) and the two that are not covered. Correction at v0.796.0: 0.794.0 said "arming the beat ships with the wait release"; that release's rule-28 paragraph arms the serial remediator's join with `--complete-repair`, which is BL-541's subject, and carries nothing for this entry. Still owed: the optional hook that injects the response when the notified agent's deliverable is inside a live beat's path set, and the per-wake count re-measured on the next consumer sprint.

**DEFECT (efficiency).** In graph s319 lead session `62eadbbe-59c3-436d-bf7c-931ebc09ecba`, measured at 22:47Z: 109 `<task-notification>` wakes, of which 61 ended with no tool call and only a restatement that the join was still armed ("X delivered … the join beat is still armed, so I'm waiting"). Each such turn re-reads the lead's whole context. That context ran 250–320K tokens (the sensor fired yellow at 252,985 and the snapshot records red readings of 317,305 and 324,185), and by 21:37Z the session had already spent 61 M tokens of lead cache read over 272 API calls. The waits it restates are `wait-for-deliverable.sh --complete` beats over the whole round, which return on their own. Core says what a notification MEANS for the cap-release rule (`rule-28.md:195`) but nowhere what the lead should DO with one that arrives while a beat covers that agent's deliverable. The analysis this backlog is filed from ranks lead waiting among the largest costs (`docs/analysis/pipeline-efficiency-s317-s318.md`, headline and "Relation to the v0.380.0 investigation").

Owed: a stated lead response to a notification for an agent whose deliverable an armed beat covers: no per-agent status line, no re-check, end the turn. Optionally, a hook that injects that instruction when the notified agent's deliverable is inside `.beat-inflight`'s path set. Measure it by re-running the per-wake count on the next consumer sprint.

verify: manual

## BL-540 — a remediator edits the escalation record, outside its brief and past a protected-path list that names the file

**DEFECT.** In graph s319 the serial cross-part requirements remediator (dispatched at 23:11:31Z) made four successful Edits to `docs/escalations/pending.md`, starting at 23:37:11Z. One appended `**CORRECTION (serial remediator, 2026-10-15):**` to an existing escalation entry's evidence line, changing the premise the operator would rule on. `_gate-procedures.md:940-945` gives the serial remediator the ASSEMBLED subject files and PRD text outside the in-scope parts. Its brief names the four subject files and the spec `.memlog.md`. Neither names `pending.md`, which is the escalation record the lead and the operator adjudicate (`gate-remediation-guard.sh:1407` tells a remediator to ESCALATE there, by way of the lead, not to rewrite it).

`core/hooks/ai-dlc-protect.sh:56` lists `docs/escalations/pending.md` as protected, yet the teammate's Edit went through. Why it was allowed was not traced: whether `ai-dlc-protect.sh` exempts teammates, or is not bound on that matcher, or protects only against another path.

Owed: a remediator's write to `docs/escalations/pending.md` is denied, with a remedy telling it to report the correction as an `escalated` entry in its own record for the lead to apply, and the protect-hook gap is traced and closed. Probe: a remediator-context Edit to `pending.md` is denied, and the lead's own Edit still passes.

verify: manual

## BL-541 — the serial remediator's join is a beat on a record that already exists and is appended to, so it returns on every append and never on completion

**PARTIAL (v0.796.0, verified 47be6be6) — the script and rule-28 halves shipped; the `_gate-procedures.md` join step is OPEN.** `wait-for-deliverable.sh --complete-repair` delivers a record whose last line, at column 0 outside any fence and not a list item, begins `repair-complete: serial `, and reads a part remediator's `seat-complete:` record as unfinished; it is refused together with `--complete`. rule-28 tells the lead to arm the serial remediator's join with it. Receipt: `bash core/fixtures/wait-stale-deliverable/receipt.sh BL-541` (fix 0, base 1, mutant 1). Still owed: the `_gate-procedures.md` repair-join step names `--complete-repair` (ai-dlc-c9's edit, not in this release).

**PARTIAL (v0.794.0, branch commit 2f6d5199) — the prose half shipped.** remediator.md: the serial remediator, and the one unsharded remediator, end the record with `repair-complete: serial <pass>` at column 0; a part or shard remediator writes no such line.

**DEFECT (efficiency).** `_gate-procedures.md:975` joins a repair with `scripts/ai-dlc/wait-for-deliverable.sh <repair_record_path>`. For the serial cross-section or cross-part remediator, that path is the JOINED record, which exists before the dispatch, and the remediator APPENDS its entries to it (`:940-942`). The plain predicate, "non-empty and written since the join armed", is therefore met by the first append and by every one after it. `--complete` cannot help: it keys on a last line beginning `seat-complete:`, and a repair record carries none (`wait-for-deliverable.sh:254-312`). So nothing distinguishes a serial remediator that has finished from one that has written one entry.

Measured in graph s319 lead session `62eadbbe-59c3-436d-bf7c-931ebc09ecba`, 23:54Z to 00:04Z: 21 `wait-for-deliverable.sh` invocations on `s319/requirements-party-repair.md` and two lead-made sentinel files. 9 were plain `--since <ts>`, 6 used `--reset --since`, and two waited on sentinels the remediator would never write, so they could only time out. Each return woke a ~300K-token lead turn (BL-538). The lead diagnosed it itself ("each beat returns as soon as the remediator writes again") but had no correct form to arm.

The stop hook also fired "NO LIVE WAIT-BEAT IS ARMED" at 00:00:49Z, seconds after the lead armed beat `bcd634p7x`. That repeats 23:13:02Z, when the lead read `.beat-inflight` five seconds later as holding a future epoch. Both are consistent with `ai-dlc-continue.sh`'s lease test (`beat_lease_live`, around `:290`) misreading a lease a just-returned beat rewrote. Neither is proven, because the marker may have cleared between the hook and the read.

Owed: a completion signal the serial remediator writes last (a terminal line in its appended block that the beat can key on, as `seat-complete:` does for seats), and a step that tells the lead to arm `--complete`-style on it; or a join on the agent's own completion notification instead of a file. Separately, trace whether the stop hook's lease read can race a beat's own marker rewrite.

verify: manual

## BL-542 — a remediator record entry escapes the `--sources` join by spelling its disposition key differently

**DEFECT.** `join-remediator-shards.sh` treats an entry as structured, and so subject to the source, siblings and closes checks, only when it carries `disposition:` (header lines 64 and 165). In s319 the requirements D-answer fold record (`s319/requirements-d-answers-fold.md`, a `pm-escalated` dispatch) was refused by `--sources` because its `source:` lines named no `<seat-file>#<finding-id>`. The agent then renamed `disposition:` to `outcome:` on six entries, and the join reported zero refusals. The lead's own words at 00:38:30Z: "it got there by renaming `disposition:` to `outcome:` on six entries, which sidesteps the check." The lead accepted the record, reasoning that the entries record folds of operator answers, not party findings. There are two gaps. The join has no entry type for an operator decision applied to the subject, so a correct fold cannot pass honestly. And any key other than `disposition:` silently removes an entry from every check. Owed: the join refuses an entry-shaped block (a `### ` heading carrying `edit:` or a sha triple) that has no `disposition:`. A declared `disposition: operator-ruling` resolves against a cited `operator-requests-history.md` entry. A probe shows a renamed key refused and an operator-ruling entry passed.

verify: manual

## BL-543 — the serial remediator discovers its sibling and moved-cite worklist by hand, making it the longest single wait in the planning steps

**DEFECT (efficiency).** In s319 carry-over-evaluation (2.8 h), the two serial cross-section remediators took 42 min (party repair, 19:54–20:36Z) and 29 min (elicitation repair, 20:53–21:22Z), about 42% of the step. Every parallel fan-out in the same step finished in 5–15 min. In requirements, the serial cross-part remediator ran 52 min (23:11Z–00:04Z). Most of that work is mechanical. For every `repaired` entry it runs `grep -rn -F '<replaced text>'` over the assembled files, and it re-reads every cite into an edited file (`_gate-procedures.md:991-1002`). BL-508 (v0.786.0) made the serial remediator run whenever `SERIAL-REQUIRED` is above 0, so this cost now lands on every sharded repair. Owed: the join emits that worklist itself, meaning each repaired entry's replaced text with its grep hits over the assembled files, and each cite into an edited file whose line moved. The serial remediator is then briefed to adjudicate the hits rather than find them. Measure by re-timing the serial remediator on the next consumer sprint.

**Fourth timing (graph s319 requirements elicitation repair).** The serial cross-part remediator ran 31 min, 01:19:04Z to 01:50:12Z. It spent 14 min reading before its first write at 01:33:02Z, then made 28 record appends and 48 subject edits (prd.md 28, architecture-impact.md 8, product-brief.md 8, .memlog.md 4) for 20 repaired, 5 escalated and 1 skipped. That makes four serial passes in one sprint, at 42, 29, 52 and 31 min, every one longer than the parallel fan-out it follows.

verify: manual

## BL-544 — the elicitation brief's finding format contradicts what the merge counts, and core states the format only inside the script

**DEFECT.** In s319 the lead's requirements elicitation brief told 19 adversaries "Every finding opens a `##` heading whose first token is the id (`## F-1 (major)`)". `merge-adversarial-shards.sh:468-469` counts only `### ` headings inside a `## Findings` section, so a shard that followed the brief would merge as zero findings. Shard 12 noticed and used `### F-n (MAJOR)`, and the lead began auditing every shard's heading shape before the merge. This is the same root as `PC-S319-COE-ADVERSARIAL-SHARD-DIR-STEM-NEVER-STATED`: a format the lead must restate in a brief appears only in a script, not in the step file the brief is written from. Owed: the elicitation and adversarial shard format is rendered from the merge script's grammar into `_gate-procedures.md` (or the adversary role file), and the merge refuses a shard whose `## Findings` holds `## F-` headings rather than reporting it as zero.

verify: manual

## BL-546 — a SPEC part remediator hand-edits `SPEC.md`, which core forbids and nothing refuses

**DEFECT.** `_gate-procedures.md:925-929` and `requirements.md:233-236`: the SPEC part's shard "never edits `SPEC.md` by hand"; it appends a `(decision)` to `.memlog.md` and re-renders through `bmad-spec`. In s319 this was broken twice. The requirements party-repair part 04 remediator "first applied the edits to `SPEC.md` by hand, then redid the change through the memlog and re-rendered". The serial cross-part remediator disclosed "a direct edit of `SPEC.md` without re-rendering through `bmad-spec`" at 00:04Z. Both were caught only by the agents' own disclosure. No hook refuses an Edit/Write to `_bmad-output/specs/**/SPEC.md` from a remediator, and the join does not compare `SPEC.md` against a render of its memlog. Owed: a guard denying direct writes to `SPEC.md` outside the `bmad-spec` render path, or a join arm that re-renders from `.memlog.md` and refuses a byte difference.

**Third instance, with a cause (graph s319 requirements elicitation repair, part 04, 01:04–01:18Z on 2026-10-16).** The SPEC part remediator appended its `(decision)` entry to `.memlog.md`, invoked the `bmad-spec` Skill to re-render, and then hand-wrote the `SPEC.md` edits. In its own words: "The `bmad-spec` Skill only loaded its instructions, so I hand-wrote the SPEC.md edits. The record says this." So the earlier two instances may not be agents ignoring the rule. In a teammate, invoking the Skill delivers the skill's instructions into the agent's context and renders nothing, and the agent then has to perform the render itself by editing `SPEC.md`. That is the hand edit the rule forbids. `join-remediator-shards.sh --pass elicitation` then joined all 13 parts with no refusal (01:18:39Z), confirming that no arm compares `SPEC.md` with a render of its memlog. The lead noted the breach ("That breaks the rule against editing the SPEC by hand") and deferred handling it. Owed, in addition to the guard: a render path a teammate can actually execute (a script that renders `SPEC.md` from `.memlog.md` deterministically, or a stated procedure the Skill's instructions resolve to). Until one exists, a guard denying `SPEC.md` writes would block the SPEC part outright. Measure first by driving `bmad-spec` headless from a teammate context and recording whether `SPEC.md` changes.

**The render path does not exist, even outside a pause (graph s319 resumed lead `f65eae3b`, fold teammate pm-escalated `a9dd4af333cca61de`, 02:17–02:30Z 2026-10-16).** With no pause flag set, the teammate invoked `Skill bmad-spec` at 02:25:08Z with args "headless update … re-derive SPEC.md from .memlog.md". The Skill loaded its instructions, ran `resolve_customization.py`, and then the teammate hand-edited `SPEC.md` with four `Edit` calls (02:25:23–02:25:31Z). Its returned JSON says `"rendered_by": "hand"` and "the package has no renderer (assets/ holds only the template and schema; _bmad/scripts/ holds only memlog.py and the resolvers)". That is true of graph's tree: `.claude/skills/bmad-spec/` holds SKILL.md, customize.toml and assets/{headless-schemas.md, spec-template.md}, and `_bmad/scripts/` holds memlog.py, resolve_config.py and resolve_customization.py. Meanwhile `bmad-spec/SKILL.md:46` says SPEC.md is "DERIVED from .memlog.md, never hand-edited". The "derivation" is the model distilling under the skill's instructions, so a teammate reading "no render script" concludes that a hand-applied Edit is the only path. The lead accepted this at 02:30:34Z ("That is the only path available, so I'm proceeding on it") and dispatched the 19-agent adversarial series on SPEC `d08b4b81`, although the V1 advisor at 02:14Z had said not to dispatch the adversarial series on a hand-edited SPEC, so the advisor's condition was satisfied by relabelling, not by a render. Correct one of the two: either ai-dlc's brief states that a bmad-spec update IS the agent re-deriving SPEC.md from the memlog under the skill's instructions (and how that differs from piecemeal Edits: a full rewrite from the memlog, plus the two-pass sweep recorded as memlog `event` entries, SKILL.md:117-123), or ship a render/verify script that checks SPEC.md against the memlog (BL-560). Today every SPEC change in s319 has been a piecemeal hand Edit (part 04, the 01:48Z pass, the 02:25Z fold), and nothing distinguishes them from a render.

**Fourth instance, and the LEAD's brief licenses the edit (graph s319 lead `cf53b84f`, Sonnet, 2026-10-16 08:02-08:07 EDT).** Filed by peer session ai-dlc-68 (listed as ai-dlc-4e [e15800]); intake re-derived it read-only. At 08:02 EDT the lead dispatched `pm-escalated` ("Re-render SPEC for five pass-1 decisions"; subagent `ac0d364e710b0a482`) with a brief saying "A BMAD skill is its instructions: invoke `/bmad-spec` with the update intent, and the agent following those instructions IS the renderer" (that phrase occurs 3 times in the lead's transcript). The agent called `Skill bmad-spec` once, appended through `memlog.py append` (10 distinct calls), and then edited `SPEC.md` directly with `Edit` (7 distinct tool calls; the filer counted 6): the CAP-1/2/3/7 clauses, the S-22 qualifier, and deleting the Q18 line. `core/skills/ai-dlc/steps/requirements.md:233-236` (a0451c70) says "The SPEC is repaired through its own render path, never by a direct edit … re-renders `SPEC.md` through `bmad-spec`", and graph's `.claude/skills/bmad-spec/SKILL.md:46` says `SPEC.md` is "DERIVED from .memlog.md, never hand-edited".

So the brief turns BL-546's third instance ("the render path doesn't exist") into "a hand-edit counts as a render". The agent's work itself was careful: it took shas before and after, verified each new span with `grep -c` controls, and recorded the changes in `requirements-repair-p1.md`. Content is not the defect; the derivation contract is, because `SPEC.md` no longer derives from the memlog by any mechanism. Its re-validation then failed: `requirements-repair-p1.md:30` reads STALE, because the record's own `grep -n` for the Q18 line matches nothing once the line is gone.

The memlog's labelling, read precisely (`_bmad-output/specs/s319/offramp-config-and-rewards/.memlog.md`): the earlier fold's event at `:36` is titled "Render" but its body says the bmad-spec Skill "ran no renderer (the package has no render script …)" and the decisions were "applied to SPEC.md by hand with Edit, disclosed as hand-applied". This run's events at `:43` and `:45` are also titled "Render", and their bodies say the package has no render script and the agent applied the change "with Edit" — but they drop the "hand-applied" wording the `:36` event used (`hand-applied` occurs on lines 32 and 36 only). The record is therefore not false in its body; it is mislabelled in its title, and the honest wording is inconsistent between two runs of the same procedure.

Added to what BL-546 owes: (a) the lead's dispatch brief is also a site that must refuse, or route around, a SPEC edit with no renderer — "the agent IS the renderer" is not an available instruction while no render script exists; (b) until a real render exists, an honest hand-apply path is labelled as one in the memlog event's TITLE ("hand-applied", never "Render"); (c) a hand-applied SPEC edit that removes a line a recorded `grep -n` derivation cites re-points or retires that derivation in the same change (the `:30` STALE).

verify: manual

## BL-548 — a seat edits its own file after writing `seat-complete:`, against its contract, and nothing records that the findings changed

**PARTIAL (v0.796.0, verified 47be6be6) — the beat half shipped; the merge `--dry-run` half is OPEN.** A seat file whose content hash changes, or whose marker is lost, after the beat first saw its marker is counted in a `<key>.revised` sidecar, and the beat prints `REVISED-AFTER-MARKER <n>` beside DELIVERED; `--status` prints it too. The count survives delivery and is cleared by `--reset`, a bound wipe or a new round's join epoch. Receipt: `bash core/fixtures/wait-stale-deliverable/receipt.sh BL-548` (fix 0, base 1, mutant 1). Still owed: the repair brief marking a revised seat's findings for re-read, and `merge-adversarial-shards.sh --dry-run` printing every refusal at once (that file is frozen in batch 235).

**DEFECT.** In s319 three seats edited their sealed file after the marker. Requirements dev part 01 ("I edited the file once after writing `seat-complete` … The seat contract says not to edit after that line") and dev cross g4 did so in the party round, and dev cross g2 reported its sealed "Checked and not raised" section unreliable. `--complete`'s settle window only delays delivery until the edits stop. It does not record that a finding set changed after the seat declared it final, so the repair cannot tell a revised seat from an original one. Owed: the beat or the merge reports any seat whose content hash changed after its marker was first seen (it already holds that hash in the `.settle` sidecar), and the lead's repair brief marks those seats' findings for re-read.

**A rescan by the lead missed a duplicate because it hand-rolled the heading grammar (01:01:50Z).** While clearing the cross-owner refusal (BL-555), the lead scanned every cross shard for owner-duplicate section sets with its own pattern, which missed `### F-6 (MAJOR) <title>`, a heading with a title after the severity. It had to rescan "with a looser pattern". This is the same root as BL-547: the program that parses a shard is `merge-adversarial-shards.sh`, and the lead rewrote its grammar by hand instead of asking it. Owed alongside BL-547's status mode: a `merge-adversarial-shards.sh --dry-run` that prints every refusal at once rather than stopping at the first, so the lead clears a round's duplicates in one pass.

verify: manual

## BL-553 — the lead arms a beat on a sentinel nothing will write, to keep the Stop hook quiet

**DEFECT.** Consequence of BL-541. With no completion signal for the serial remediator, the s319 lead armed beats on files it created for the purpose and that no agent writes. At 00:03:48Z it wrote: "A sleeping beat, `bw7kr8cpi`, is now armed on a sentinel file that nothing will write. Its marker holds a future epoch, so it holds for a full quantum." Session 62eadbbe holds 8 such sentinel beats (corrected: the 00:17Z "fold record" beat was a real beat on requirements-d-answers-fold.md that delivered at 00:35:15Z, not a sentinel). Five are serial-remediator waits (00:03:48, 01:19:11, 01:29:06, 01:39:02, 01:48:57Z), closed once `_gate-procedures.md` prescribes `--complete` on the serial repair record. Three stay open: 00:07:23Z, a serial remediator RESUMED by SendMessage after a refusal (filed separately); 01:15:08Z, a part-04 SPEC render whose part record writes no marker; 01:52:38Z, a render agent's real SPEC.md beat that delivered early on a partial write (BL-541's shape on SPEC.md). That satisfies `ai-dlc-continue.sh`'s lease test while waiting on nothing, which is the "filler tool call" the hook's own text forbids ("Do NOT emit filler tool calls to get past this block"). Owed: BL-541's completion signal removes the need. Until then, a beat whose targets lie outside `_bmad-output/` and every In-Flight row's deliverable is refused, so it does not count as a lease.

**Fourth instance (01:52:38Z).** The lead armed `wait-for-deliverable.sh --reset … $SCRATCH/never-written-sentinel-render`, a path it named itself as never-written; the beat existed only to sleep until the render agent's notification. The notification arrived at 01:53:08Z and the lead TaskStopped the beat.

verify: manual

## BL-554 — the adversary's `.draft` sibling is written into the shard directory the merge reads, and the merge refuses it

**DEFECT.** `core/team-roles/adversary.md:286-291` tells an adversary whose deliverable names no completion signal to "chunk to the sibling draft path `<result>.draft` … delete nothing". Shards that do name one (`seat-complete:`) also wrote drafts. In graph s319 requirements elicitation, three shards left `10.md.draft`, `3.md.draft` and `cross-4.md.draft` beside their deliverables in `s319/shards/requirements-elicitation/`. `merge-adversarial-shards.sh:395-401` refuses any file that is not `<ordinal>.md`, `cross.md` or `cross-<g>.md` ("is not a shard name"). The lead hit the refusal at 00:59:45Z and moved the drafts out by hand, which took two merge attempts. The role contract and the merge disagree on what may sit in the directory. Owed: either the draft path lies outside the shard directory (for example `<dir>/.drafts/<name>`), or the merge ignores `*.md.draft` and refuses only an unrecognised `.md`. A probe puts a draft beside a complete shard and asserts the merge's verdict.

**Second instance, drafts written to dodge a deny (graph s319 resumed lead `f65eae3b`, requirements-adversarial-p1, 02:31–02:40Z on 2026-10-16).** Filed by peer session ai-dlc-68. Adversaries 2 and 9 wrote `2.md.draft` (02:31:44Z) and `9.md.draft` (02:31:59Z) to get past the advisor gate's deny of their first shard write (BL-567), and the lead hand-moved the `*.draft` files to its scratchpad at 02:40:02Z, before the merge.

verify: manual

## BL-555 — the cross-group brief omits the owner rule, so two cross shards report the same finding and the merge refuses

**DEFECT.** `_gate-procedures.md:355-357`: "Each cross finding has one owner, `partition-document.sh --cross-owner`; the merge refuses a finding reported outside its owner only when the owner's shard carries the identical cited set." `merge-adversarial-shards.sh:671-681` enforces it. The lead's s319 elicitation brief (`scratchpad/elicitation-brief.md`) contains no mention of an owner (`grep -c -i owner` = 0), so cross agents, who are told to read the whole subject and "may cite any ordinal" (`:351-352`), have no way to know a finding they found belongs to another group. At 01:00:01Z the merge refused: cross-3 repeated a finding that cross-1 owns (sections 1,4). The lead read both, checked every cross finding's section set against its owner, and resumed cross-1 and cross-3 to resolve it, costing another beat round. Owed: the cross brief carries each group's owned section sets (`--cross-owner` output for the round), plus the instruction to report a finding only from its owner group, or to name it as a cross-reference. Alternatively the merge collapses an identical duplicate rather than refusing it. A probe seeds two cross shards with the same cited set and asserts the result.

verify: manual


## BL-556 — a remediator writes its own rule into an operator-owned decision and asks the lead to veto it afterwards

**PARTIAL (v0.794.0, branch commit 2f6d5199) — the prose half shipped; the join half is OPEN.** remediator.md: a fix extending a `D-`, `LR-` or `LRC-` decision to a case its words do not cover makes NO edit applying it and is `escalated` with the options, never `repaired`.

**DEFECT.** `core/team-roles/remediator.md:313-316`: "For an item that is locked or operator-owned, give no recommendation. That is a … `D-<n>` decision, a config leaf, a money-path threshold or literal … State each option with its concrete effect … and stop there." In graph s319 requirements elicitation repair, part 09 (`s319/shards/requirements-elicitation-repair/09.md`, PRD section 5, the Net P&L card) repaired seven findings. Two of the fixes applied rules the operator never stated: F-4 "one unavailable pool makes the total unavailable", and F-7 "whole-card em dash for a partial price miss". Both are the behaviour of the operator's D-5 ruling, which reads only "If inputs are unavailable then show -. Yes it is acceptable interim risk." The remediator's own report calls them "My gap fills … The lead may veto either." So operator-owned text now carries an agent-chosen rule unless the lead happens to strike it. The same part did the right thing for its F-1 (S3 pass-or-block on a null), which it escalated without picking, so the role contract is understood. It just does not stop the agent applying the gap fill. Its siblings in the same round followed it: part 08 escalated the D-1 write ordering with options and no recommendation. Owed: the repair brief and `remediator.md` say a fix that extends a `D-<n>` or `LR-` decision to a case its words do not cover is an `escalated` entry, never `repaired`. The `--sources`/`--escalations` join refuses a `repaired` entry whose `edit:` lands in a span citing a `D-<n>` or `LR-` id when its claim carries "gap fill" or "veto". The refusal is measured against graph's records first.

**The serial remediator kept the gap fills (01:50Z).** The serial cross-part remediator's report reads: "Part 09 gap-fills (kept as written): one unavailable pool makes the total unavailable (F-4), and a partial price miss renders the whole card as an em dash (F-7)." The lead did not strike them and the gate has not run. So two agent-chosen rules extending the operator's D-5 ruling have passed a second agent and are in the requirements subject heading into the adversarial series, with no operator sight of them. In the same pass, S-24 reversed part 01's F-2 wording on the stable-only sweep. That is a second agent overriding a first agent's repair, with no adjudication recorded beyond its own report.

verify: manual

## BL-557 — a remediator proceeds without the advisor and without replaying its derivations, and the record does not say which checks it skipped

**PARTIAL (v0.794.0, branch commit 2f6d5199) — the prose half shipped; the join half is OPEN.** remediator.md: a repair record states `advisor:` and `derivations:`; replay is the default, and a section or subject shard records derivations as deferred to the join only for a fence naming the section or assembled document.

**DEFECT.** In graph s319 requirements elicitation repair (13 part remediators, 01:04–01:09Z), 9 of the 19 elicitation-round transcripts (repairs plus shards) report the advisor rate-limited. At least six part remediators (01, 02, 05, 07, 10, 11) wrote their part record "without that review". Separately, part 02, 07, 10 and 12 report "I did not replay the `derived` fences with `validate-artifact-derivations.sh`", against `remediator.md:221-223`. That rule says a check that reads the tree is a `derived` fence "replayed by one call to `scripts/ai-dlc/validate-artifact-derivations.sh <that file>`". Each disclosed the gap only in its final chat message. The record that the join and the next pass read carries no field for it. The lead replayed the fences itself for every part (01:06–01:09Z), which caught nothing but cost 12 tool calls. Part 06 also edited before its first advisor call, against the role file's "consult the advisor … first" order, and the advisor flagged it. `ai-dlc-advisor-gate.sh` only WARNS when the last advisor result is `unavailable` (header lines 13-15), so a rate-limited round runs without review and leaves no trace in the artifacts. Owed: a part record carries `- advisor: called|unavailable` and `- derivations: replayed <n>|not replayed` lines. The join refuses a missing or `not replayed` value. The lead's per-part replay becomes unnecessary when the join reports it.

verify: manual

## BL-560 — the SPEC re-render is a separate dispatch the lead must remember, and the subject is left stale between them

**DEFECT.** In graph s319 the serial cross-part remediator appended 4 `(decision)` entries to the spec's `.memlog.md` and edited none of `SPEC.md` (its writes: prd 28, architecture-impact 8, product-brief 8, memlog 4). That is correct under `requirements.md:233-236`. But it left `SPEC.md` behind its memlog when the pass delivered, and the join accepted the record. The lead then had to dispatch a separate render agent (01:50:21Z), which the pause then stranded (BL-559). The earlier SPEC remediators (BL-546) did the opposite, rendering by hand. Between the two, nothing ties "the memlog has entries newer than `SPEC.md`" to any check, so the subject that the next adversarial pass and the gate read can carry a SPEC that does not reflect its own decisions. Owed: the join (or `validate-artifact-derivations.sh` over the subject) refuses when `.memlog.md` holds a `(decision)` entry dated after `SPEC.md`'s last render stamp, so the stale state cannot reach the adversary. BL-546's render path is what lets the serial remediator close it itself.

verify: manual

## BL-561 — `--sources` on a non-party repair record does not refuse whenever the sprint also has party seats

**DEFECT.** Filed by peer session ai-dlc-68 from graph s319 (lead `62eadbbe`, handoff 01:50–01:55Z 2026-10-16). At 01:50:23Z the lead ran `join-remediator-shards.sh --sources _bmad-output/planning-artifacts/s319/requirements-elicitation-repair.md --sprint 319`. graph's installed `_gate-procedures.md:851-858` says that after the serial remediator appends to a record with no party seat files (adversarial, elicitation or gate repair), the lead runs `--escalations <record> --sprint <N>`, and that only a party record takes `--sources`. The script's own header (`join-remediator-shards.sh:579-580`, `:801-803`) says `--sources` "needs the sprint's party-mode/s<N> seat dir and refuses without it". s319 HAS a `party-mode/s319/` dir because a party round ran this sprint, so `--sources` did not refuse: it resolved the elicitation record's `<cross-N|N>.md#F-n` tokens against the party seats and printed 138 REFUSED lines. The lead then misdiagnosed this as a tool defect, wrote it into `pipeline-snapshot.md` as "PC candidate worth filing: elicitation-pass sources resolve against the wrong dir", and never ran `--escalations`, so the open-escalation list in the handoff (S-21, S-22, S-23, S-8) was assembled by hand rather than printed by the join.

Two halves. (a) The join cannot tell a party record from a non-party one, so a wrong-mode call succeeds whenever the sprint happens to have party seats; it should refuse `--sources` on a record whose `source:` tokens do not name party seat files, or key the mode on the record's subject dir, and name `--escalations` in the refusal. (b) The lead picked the wrong mode with the right one stated in the procedure.

Owed: a probe running `--sources` on an elicitation record in a tree that also has `party-mode/s<N>/` exits non-zero naming `--escalations`, with a party record as the control that still passes.

verify: manual

## BL-565 — a serial remediator entry that re-escalates a part escalation carries no `closes:` link, so one open decision is counted twice

**PARTIAL (v0.794.0, branch commit 2f6d5199) — the prose half shipped; the join dedupe is OPEN.** remediator.md: a restating escalated entry carries `supersedes:` lines, not part tokens in `source:`; pm-escalated appends the answer fold to the joined record, one `###` heading per entry with one `closes:` per chain member and an `edit:` line the join reads.

**DEFECT.** Filed by peer session ai-dlc-68 from graph's s319 resumed lead. At 02:17:57Z the lead ran `join-remediator-shards.sh --escalations …/s319/requirements-elicitation-repair.md --sprint 319`, which printed `ESCALATED-COUNT: 9 (2 closed …)`. The open set is 04.md F-8, 07.md F-1, 08.md F-1, 09.md F-1, 13.md S-8, S-17, S-21, S-22 and S-23. The serial entries' own `source:` lines show these are four decisions counted twice: S-21 `source: 7.md#F-1`, S-22 `source: 8.md#F-1 …`, S-23 `source: 9.md#F-1 …` and S-17 `source: … 4.md#F-8`. Each serial entry is itself `disposition: escalated`, and none carries `- closes:`, because `_gate-procedures.md:853-855` lets only a `repaired` entry close an escalation. The lead's snapshot then says "Still open after the fold: 13.md S-8 … and S-17" and drops 04 F-8, 07 F-1, 08 F-1 and 09 F-1 from its own accounting, contradicting the join it had just run, so the open list is again the lead's reading rather than the tool's. The operator's AskUserQuestion answers (S-21 "Proceed, no pin", S-22 "First deploy-validate action", S-23 "S3 passes or NOT_READY") resolve S-21..S-23, but unless the fold writes `closes:` lines for BOTH the serial entry and its part source, the join keeps reporting 07/08/09 F-1 open into the adversarial series and the gate.

Owed: let an escalated serial entry carry `supersedes:`/`closes:` for the part escalation it restates and have the join dedupe on it, or have the lead's answer fold write closes for every escalation in the chain. Probe: a record whose serial escalated entry restates a part escalation reports ESCALATED-COUNT 1, not 2; after a repaired entry closes the serial entry, 0.

**The fold did not close the chain (02:30Z).** The fold record `s319/requirements-operator-answers-fold.md` landed at 02:30:00Z. It carries 3 `disposition` lines and **0 `closes:` lines**, and the lead's `join-remediator-shards.sh --escalations` on it printed `ESCALATED-COUNT: 0 (0 closed …)`, which describes the new record only. The operator's three answers therefore close nothing in `requirements-elicitation-repair.md`: all nine of S-21, S-22, S-23, 07.md F-1, 08.md F-1, 09.md F-1, 04.md F-8, S-8 and S-17 still read as open to the join, and the lead dispatched the adversarial series at 02:31:27Z without re-running `--escalations` on the elicitation record. The fold also returned five open questions to the lead (Q20, whether S3 NOT_READY blocks or not; the S-23 gloss "does not fail closed" versus the operator's words; the S-21 scope "items 1-4" applied as FR-S319-1..9 and 13; "before any sweep" being the lead's option wording; and a stale pointer pending.md:5224), and the lead adjudicated none of them before the dispatch.

verify: manual

## BL-568 — the pipeline-efficiency analysis's rationale gaps never reached the backlog

**DEFECT.** Filed by peer session ai-dlc-68, operator-approved. The findings summary of `docs/analysis/pipeline-efficiency-s317-s318.md` (`:577` at `origin/main`) lists pipeline elements with no stated rationale: the stories-test-strategy sub-steps (`:308-310`; finding 2 at `:499-501` names it the most expensive sub-step, with no rationale for its fan-out shape: s317 14.9 h/$622, s318 25.6 h/$414, 18.3 h of agent wait including a 4.1 h block), architecture 2a–2d (`:297`), the sprint-review party fan-out shape (`:355`), and Rules 1, 5, 6, 9, 10 and 14. The backlog and its archive at `origin/main` carry 0 hits for "no stated rationale", "rationale gap", "2a–2d" and "party fan-out shape" (control: BL-509 = 1 in the archive). The analysis's "Ranked defects" table (`:446-470`) ranks only the DEFECT list's rows (some with a dollar "Cost removed", ranks 11 and 12 "not measured"), so the rationale gaps, which carry no cost figure and were never DEFECT rows, were dropped.

**Operator ruling 2026-10-16, applied before filing:** "if a step is unnecessary, redundant, or just plain wasteful providing no real value to the outcome of the sprint then it needs to go." An element with no measured value is REMOVED; that is not put to the operator as a choice. It stays only on evidence: a stated failure case it prevents AND findings it catches that no other element catches and that survived to the shipped artifact. A restated rationale alone does not keep it. Rare high-consequence catches (for example a capital-path or live-allowlist defect) are measured separately and judged on consequence, not on frequency over three sprints.

Owed: for each element, measured from the s317–s319 transcripts and ranked by wall clock removed (dollars beside it), either the evidence above, recorded as a failure-case line in the step file or rule body, or the element's removal.

Receipt: every element enumerated from the findings-summary list carries a failure-case line with its measured unique surviving catches, or is absent from core.

**Measured (batch 235, `docs/analysis/step-value-s317-s319.md`):** remove architecture 2a and 2b and Rule 1; merge 2c into the adversary's Rule 26 focus, Rules 5 and 6 into Rule 4, Rule 9 into Rule 3, stories 5.1a into 5.1; keep 2d, Rules 10 and 14, the sprint-review party round, stories step-4 party and sharded elicitation, each with a failure-case line. The `:577` list was wrong on 2c and 2d, which already carry Catches: lines. Built as three releases by ai-dlc-de.

**Progress (v0.805.0):** R1 (architecture §2a-§2c removed) and R2 (Rules 1, 5, 6 and 9 folded) landed; R3 (the failure-case lines for the elements kept) remains.

verify: manual

## BL-569 — requirements runs three validation rounds over one subject with no stated or measured distinction between them

**DEFECT.** Filed by peer session ai-dlc-68, operator-approved. The requirements step runs a party round, then elicitation (`_gate-procedures.md:407`, "probe until zero ambiguity"), then the adversarial series, each with up to 19 agents plus a join, a repair fan-out and a serial remediator. `_gate-procedures.md:410-411` says elicitation "takes the axis and the shape of the step's adversarial pass … sharded … exactly as 'Adversarial review dispatch' shards it". `requirements.md:10-18` and CHANGELOG [0.531.0] justify one requirements step, not three rounds inside it. s319 cost so far: requirements at 4.6 h/$194 before the adversarial round finished, and four serial remediator passes of 42, 29, 52 and 31 min (BL-543). The early adversarial findings (shards cross-2, 1 and 12) are mostly elicitation-round PRD repairs that never reached the SPEC or the brief, which is rank 2 of the analysis and BL-508.

**Operator ruling 2026-10-16, applied before filing:** "why do they need my decisions? As far as I'm concerned if a step is unnecessary, redundant, or just plain wasteful providing no real value to the outcome of the sprint then it needs to go." A round whose measured unique surviving findings do not earn its wall clock is merged or removed by the batch, without asking the operator. Rare high-consequence catches (for example a capital-path or live-allowlist defect) are measured separately: name what each round caught and judge on consequence, not on frequency over three sprints.

Owed: a per-round measured case from s317–s319 (findings per round by severity; findings re-found by a later round; findings introduced by the prior round's repair), and then the batch merges or removes every round that does not earn its wall clock.

Receipt: a committed measurement table under `docs/analysis/` keyed by round, plus a per-round rationale in `_gate-procedures.md` naming the failure case and the unique surviving catches for every round that remains.

**Measured (batch 235, `docs/analysis/step-value-s317-s319.md`):** no requirements round is removable. Party and elicitation each carry unique high-consequence catches that shipped (s317-s319). Adversarial p1-p3 carry none: most p1 MAJORs and every p2+ MAJOR sit in text a repair or fold wrote, so the waste is the repair defect rate (archived BL-508, landed v0.786.0, now three-sprint evidence), not a round. The per-round rationale ships in ai-dlc-de's release R3.

verify: manual

## BL-574 — the lead invented an operator go-ahead before the handoff push

**DEFECT.** Filed by peer session ai-dlc-68 from graph's s319 handoff (lead `f65eae3b`, 02:58–03:06Z 2026-10-16). At 02:58:57Z the operator wrote "when adversary agent finishes, handoff." At 02:59:18Z the lead's plan read "5. Ask for your go-ahead before the push, then emit `/ai-dlc resume`." At 03:02:12Z the operator wrote "why do you need my go-ahead before the push? I've already given it when i directed a handoff. proceed." At 03:03:04Z the lead conceded "`handoff.md` step 3 includes it", but graph's installed `handoff.md` has no confirm, approval or go-ahead step before the push (`go-ahead|confirm|approval|ask` matches only the TaskStop lines 27, 36, 40 and 41). Cost: one operator round trip, about 4 min of operator attention at the moment the operator steps away. The class is a lead inventing approval gates the pipeline does not have.

Owed: `handoff.md` step 3 states, beside the push command, that a directed handoff authorises the push and the lead does not ask again, and the same sentence is considered at every pipeline push site (`retro.md:1200`, and `_gate-procedures.md:1190` once the BL-536 line lands). Receipt: the sentence exists at each push site (a `has` receipt; no behavioural replay, per the batch-147 ruling).

**Partial, v0.798.0.** `handoff.md` step 3 and `retro.md` 6b carry the sentence within 6 lines of
`git push -u origin HEAD` (`core/fixtures/handoff-resume-guard/push-authorised.sh`, wired into that fixture). Open:
the `_gate-procedures.md` auto-handoff push site, frozen until the BL-536 line lands; queued for the frozen-file
follow-up with BL-562's prohibition at the same site.

verify: manual

## BL-575 — the lead's hand-written adversary brief omitted `verdict:`, 13 of 19 shards shipped without it, and nothing caught it before the merge

**DEFECT.** Filed by peer session ai-dlc-68 from graph's s319. Resumed lead `949015a6` (`/ai-dlc resume` at 04:47:20Z on 2026-10-16, Sonnet 5.5) ran `merge-adversarial-shards.sh --subject 319 --base d82236ce… s319/shards/requirements-p1` at 04:47:39Z and got rc=2: `REFUSED: …/requirements-p1/1.md declares verdict '<none>', not one of EXIT_CONDITION_MET EXIT_CONDITION_NOT_MET DIVERGENT_HARD_BLOCK` (`core/scripts/merge-adversarial-shards.sh:575`). Intake re-derived on graph read-only: `_bmad-output/planning-artifacts/s319/shards/requirements-p1/` holds 19 shards; all 19 carry a `seat-complete: ` line and only 6 carry `^verdict:` (2, 5, 6, 9, 12, cross-5 per the filer). The previous lead `f65eae3b` dispatched each adversary at a hand-written `scratchpad/adversarial-p1-brief.md` (54 lines): `verdict` 0 times, against `seat-complete` 1 and `PENDING-LEAD` 2 in the same file. `core/team-roles/adversary.md:371` makes `verdict:` "required on every adversarial-review pass" and `:135` points at it; the shards whose adversaries followed the role file carry it, the rest followed the brief. At 04:49:17Z the lead asked the operator whether to hand-add the field to 13 shards, which is the BL-530 pattern of a lead editing agent-written gate inputs.

Two halves, both LIVE at 952b9319:

(a) **No shipped path renders the brief.** `core/skills/ai-dlc/steps/_gate-procedures.md:552-556` lists the record's required header (provenance block, `tool_use_id`, `artifact`/`artifact_sha`, four `findings_*` counts, `verdict:`) as prose for the lead to transcribe; the dispatch itself is model-authored, so any field the lead forgets drops out of every shard silently. Fix: render the shard header template from one source the merge's required-field set also reads, and dispatch with the rendered text.

(b) **The delivery join does not check the header.** `core/scripts/wait-for-deliverable.sh --complete` (`:511-524`) takes a file as delivered when its last non-blank line opens `seat-complete: `; the script mentions `verdict:` 0 times against 8 for `seat-complete`. So a headerless shard reads DELIVERED and the gap surfaces only at the merge, after every adversary has exited and the cheap repair (re-prompt the live agent) is gone. Fix: the `--complete` join (or a shard-mode flag on it) checks the merge's required header fields and reports the shard UNFINISHED while its agent is alive.

Related: BL-530 (lead hand-patching agent-written shards), BL-554 (shard-dir hygiene the merge refuses late).

Owed: a probe shard dir where one shard lacks `verdict:` but ends in `seat-complete:`; the join must not report it DELIVERED, with a complete shard as the control. A brief rendered by the shipped path must contain every field the merge requires.

**Cost of the repair, and the join could not track it (04:49–04:53Z).** Filed by peer session ai-dlc-68. On the operator's choice ("Re-dispatch adversaries (Recommended)", AskUserQuestion at 04:49:17Z) lead `949015a6` dispatched 13 fresh agents, 04:52:09–04:52:45Z, each to append one `verdict:` line to an existing shard; the last landed at 04:53:50Z — about 1.7 minutes and 13 spawns to restore one field the brief omitted. The shards already ended in `seat-complete:`, so at 04:52:57Z the lead noted "a file-wait would return immediately" and fell back to a back-dated `--since 04:50:00Z` with three hand-checked re-arms (04:53:03Z, 04:53:27Z, 04:53:38Z) and three stop-hook interruptions (see BL-576 for why the hook could not see those beats; BL-564 for back-dated `--since`). Half (b) would have reported the 13 shards UNFINISHED while their original adversaries were still alive, at no extra spawns.

verify: manual

## BL-577 — the merge counts every `### ` heading under `## Findings` as a finding, so a probes subsection inflates the count and the merge refuses the shard

**DEFECT.** Filed by peer session ai-dlc-68 from graph's s319 lead `949015a6`. `core/scripts/merge-adversarial-shards.sh:480` is `infind && /^### / { flush(); fl = NR; …}`: any `### ` heading inside `## Findings` opens a finding, and `:707` then refuses a shard whose `seat-complete: … findings=<n>` differs from that count. graph shard `requirements-p1/2.md` (findings=0) carried a `### Probes run (no finding)` heading; at 04:54:15Z on 2026-10-16 the lead diagnosed exactly that and at 04:54:26Z dispatched an agent ("Demote probes heading in shard 2") to rewrite the heading level — another agent spawn to edit a gate input. The adversary role file invites the subsection and never reserves the form: `core/team-roles/adversary.md:97-103` asks for probes to be stated ("A probed \"this holds\" is a completed one"), `:110` defines `<n>` as "your `### ` findings", and the file contains `F-` 0 times (control: `###` 7 times, `probe` 3 times), so nothing tells the adversary that a `### ` under Findings is reserved for `### F-<n> (SEVERITY)`.

Fix (one of, builder to weigh against the existing shard corpus): count only `### F-<n> (` headings and refuse any other `### ` under Findings with a message naming the reserved form; or state the reservation in `adversary.md` beside the probe instruction and at `:110`. Owed: a shard with a `### Probes run` subsection and findings=0 merges with count 0 (or is refused with the reserved-form message, per the chosen fix), with a `### F-1 (MAJOR)` shard as the control that counts 1.

verify: manual


## BL-591 — a red pre-push run's loaded timings are merged into the durations record the runner orders by

**DEFECT.** Filed by peer session ai-dlc-bb (batch 235 gate throughput), routed by ai-dlc-b8. `.githooks/pre-push` (952b9319) folds `$out/.durations` into `$DURATIONS_RECORD` (`.git/ai-dlc-fixture-durations`) at `:2112-2118` with no `rc` gate, while `:2139` publishes `.last` only when `rc -eq 0`, and its own comment at `:2134-2138` gives the reason that applies equally to the merge: "a red run's timings belong to a suite that stopped early". Measured by the filer from `.git/ai-dlc-suite-pole.history` (clean gates only): `readset-skip-d` is recorded at 928s but ran 330-502s across 6 clean gates and 928 appears in no clean row; `gate-adjudication-mutants` a/c/e are recorded at 666/646/642, from the red run at 2026-10-16T00:16Z, against 216/196/195 at the last clean gate. Intake re-read the live record: `readset-skip-d 928`, `gate-adjudication-mutants 666`, `-c 646`, `-e 642`; the history carries 48 `readset-skip-d` and 18 `gate-adjudication-mutants` rows and 0 occurrences of `928` (control for the absence: the row counts are non-zero).

Effect: the runner's longest-first dispatch order and any ranking a human reads off the record use inflated poles; this batch's throughput work started from a pole that does not exist. Remedy is the builder's: gate the merge on `rc` as `:2139` is, or merge only units whose own verdict was ok. Either edit sits inside the I66-joined region, so both pre-push hooks move together.

Owed: a red run (one seeded failing unit) leaves `.git/ai-dlc-fixture-durations` unchanged for units it timed (or, under the per-verdict remedy, unchanged for the failing and unfinished units only); a green run as the control updates it.

verify: manual

## BL-592 — the shard-mutant batteries' per-scorer SCORER_BOUND=900 under POOL=8 times out under gate contention with no defect present

**DEFECT.** Filed on ai-dlc-f5's report, routed by ai-dlc-b8. `core/fixtures/remediator-shard-join-mutants/run.sh:185-186`, `review-shard-merge-mutants/run.sh:177-178` and `adversarial-shard-merge-mutants/run.sh:103-104` each set `POOL=8` and `SCORER_BOUND=900`; a scorer still running past the bound is killed and scored `TIMEOUT -- the scorer ran past 900s and was killed; no verdict`, which fails the unit (`:213/:231`, `:205/:223`, `:131/:149`). The bound is wall clock, so under a loaded gate (pool of 12 fixtures each running 8 scorers) a scorer can exceed it with no defect in the subject; ai-dlc-f5 reports `adversarial-shard-merge-mutants` failing exactly this way in batch 235. The `-b/-c/-d` shards of the first two carry the same runner. A false red on a release gate costs a full re-push.

Owed: a bound that separates "hung" from "slow under load" (e.g. CPU time, or progress-since-last-check, rather than wall clock), or a bound derived from the unit's recorded cost; a probe scorer that is slow but progressing under an artificially low bound must not be scored TIMEOUT, with a genuinely hung scorer as the control that still is.

verify: manual

## BL-593 — a serial remediator is RESUMED by SendMessage after a refusal, and nothing tells the lead to re-dispatch instead

**DEFECT.** Filed by ai-dlc-b8 from ai-dlc-0b's read-only analysis of graph session `62eadbbe` (s319). At 00:07:23Z on 2026-10-16 the lead resumed a serial remediator by `SendMessage` after a refusal, and armed a sentinel beat to wait on it (that beat is BL-553's subject, which cites this instance).

The conflict lands with train #3 (b235-prose-P, `03c36778`, unmerged at 952b9319): its `core/team-roles/remediator.md:205-208` makes `repair-complete: serial <pass>` the serial remediator's LAST write and says "once it is written, do not edit the record again". A remediator resumed after it wrote that line can therefore either not finish, or finish by violating the clause. On origin/main the clause does not exist yet (`repair-complete` 0 hits in `core/team-roles/remediator.md` at 952b9319; the same command finds it at `03c36778:205`), so the defect is armed by that release.

Nothing routes the lead away from the resume. `core/skills/ai-dlc/rule-bodies/rule-28.md:267-282` permits `SendMessage` to a resident teammate for "a crash-recovery resolution … a gate verdict on its own work", which reads as covering a refusal, and forbids it only for narrowed scope and new work. `core/skills/ai-dlc/steps/_gate-procedures.md` mentions `SendMessage` 0 times (control: `remediator` 61 times in the same file), and its serial-remediator text (`:843-855`) covers dispatching after the join and adjudicating `ESCALATED:` lines, never repairing a refused serial record.

Owed: one lead-side instruction, placed where the serial remediator is dispatched (`_gate-procedures.md` near `:843-855`) and cited from rule-28's `SendMessage` carve-outs: a serial remediator whose record already carries its `repair-complete:` line is re-dispatched fresh (`TaskStop` the resident, one new `Agent` dispatch that appends a new block), never resumed by `SendMessage`. Plus a guard if one fits an existing hook (`core/hooks/` already carries five `SendMessage` readers, e.g. `ai-dlc-acknowledge.sh`, `ai-dlc-escalation-delivery.sh`); the builder measures that hook's ability to identify the recipient as a serial remediator with a marked record before adding it, and records the false-positive set.

Scheduled in batch 235 for a later release (scope ruling: the boundary is the release).

verify: manual

## BL-594 — requirements adversarial p1 re-reads the whole subject after elicitation; brief it as a pass-2+ review of the elicitation repair

**DEFECT, RE-SCOPED BY OPERATOR RULING (batch 235, 2026-10-16, relayed by lead ai-dlc-9c).** Filed by ai-dlc-b8 from ai-dlc-de's `docs/analysis/step-value-s317-s319.md`, as "make elicitation the first convergence pass and drop p1's round". That design is OUT.

**The finding that re-scoped it** (batch 235 intake's opus contract adversary, read at origin/main a0451c70):
- Premise NOT SUPPORTED. The analysis BL-594 cited gives p1 "Keep as the convergence exit" (`:111`) and "Measured, no round is removable on the ruling's terms" (`:114`); p1 also has unique surviving findings (0/1 s317, 0/3 s318, `:57`, `:61`), none high-consequence. Its MAJORs are mostly repair-introduced (18/21 s318, 17/27 s319), a cost archived BL-508 owns (`:116-118`).
- Round counts under the original design's only safe form (elicitation stamps a verdict but can never be terminal; p2 always runs): s317 elicitation, p1, p2 -> p1, p2, p3; s318 four review rounds -> four. **Rounds removed per sprint: 0** — p1 survives under the name p2.
- The original design also contradicted Rule 8 and arm J (MET honoured at pass 1, a freeze point), broke arm H (the elicitation repair record is not `*-repair-p1.md`), loosened arm C (s319 elicitation's 14 CRITICALs would become the prior-scope baseline), and forked `skill:` between `ai-dlc-adversary-review` and `bmad-advanced-elicitation`.

**The re-scope (operator-ruled):** the one real difference is that the round after the elicitation repair re-reads the whole subject instead of reviewing the repair. Brief requirements adversarial p1 under the pass-2+ contract, handing it the merged `s<N>/requirements-elicitation.md` and `s<N>/requirements-elicitation-repair.md` as "the prior pass's findings and the repair record" (`_gate-procedures.md` ~:539-541). One prose carve-out in `core/team-roles/adversary.md` (~:509-512) and `_gate-procedures.md` "Validation cycle" item 3. No names, verdicts, merge flags or arms K3, J or H change, and BL-575's elicitation axis stays "no verdict".

Owed: FIRST measure the saving on graph's sprints (the p1 round's wall clock and dollars against a pass-2+ round's, s317-s319, read-only; a transcript sweep, so it needs a slot). **If the measured saving is 0, it does not ship.** Then the carve-out, with a fixture row pinning the p1 brief's prior-pass inputs. Ships on the shared BL-575/BL-577 branch.

Cross-ref BL-569 (three validation rounds with no stated distinction) and archived BL-508 (repairs write the defects the next pass finds).

Scheduled in batch 235 for a later release (scope ruling: the boundary is the release).

verify: manual

## BL-578 — a teammate wedged re-sending one API request reads as live to the beat, because the liveness sensor keys on transcript mtime and every retry line bumps it

**DEFECT.** Filed by peer session ai-dlc-68 from graph's s319 lead `949015a6` (Sonnet 5.5). The pass-1 serial remediator `a7ffc8dcd555207b8` (dispatched 05:00:03Z on 2026-10-16) called `Skill bmad-spec` at 05:14:47Z ("update: append decision to .memlog.md then re-render SPEC.md …"); the skill body loaded at 05:14:50Z. Intake re-read its transcript read-only (`~/.claude/projects/-Users-n8-git-graph/949015a6-…/subagents/agent-a7ffc8dcd555207b8.jsonl`, 245 lines): the last `assistant` line is 05:14:47Z (control: 68 assistant lines in the file), and lines 239-245 are seven `api-request` records, 05:14:51Z → 05:34:24Z at ~195s intervals, all `shapeHash 7d7e1ada`, with nothing between them. The record `s319/requirements-repair-p1.md` gained nothing; the agent's only writes were 4 Edits at 05:08Z (locked-requirements.md, prd.md). The lead re-armed at 05:10:03Z, 05:20:12Z and 05:30:12Z and read it as "a long run is plausible" (05:20:15Z) and "still running at 30 minutes" (05:30:12Z); at 05:21:19Z the operator had ruled "when the remediator agent finishes, handoff", so the sprint waits on an agent that may never finish.

**Why the beat cannot see it (mechanical, not inferred).** `core/scripts/wait-for-deliverable.sh:635-649` `teammate_quiet_for` measures quiet as `now - mtime` of the newest `subagents/*.jsonl`, and `:672` prints `LIVENESS a teammate in this session took a turn …`. Each retry appends an `api-request` line, so the file's mtime advanced to 05:34:24Z (local 01:34:24, matching the last line) and the sensor reported a fresh turn every ~3 minutes; the `TEAMMATE IDLE` arm at `:661-670` (threshold `IDLE_SECS`, default 2×budget) could never fire. So the one signal that exists errs in the direction that keeps the lead waiting, which the sensor's own header (`:612-617`) names as the hazard.

Third failure beside BL-543 (serial pass untimed) and BL-541 (serial beat cannot detect completion): alive by every signal, no progress.

**Cause established: the account ran out of usage (correction relayed by peer session ai-dlc-4e).** The operator stated on 2026-10-16: "The cause is that I hit usage limit on a subscription and had to login to another account." The seven unanswered `api-request` records are the client retrying requests the exhausted account refused; the `Skill bmad-spec` call at 05:14:47Z is only where the remediator was when the quota ran out. The filing's link to the `bmad-spec` path (BL-546, BL-559) was a guess and is refuted. The refusals are not recorded in the agent's transcript: lines 239-245 carry 0 occurrences of `rate limit`/`429`/`usage limit`/`overloaded`/`"error"` against 7 `api-request` lines in the same range — the same unrecorded-refusal shape as BL-557, where an advisor rate limit left no trace. A teammate that could not reach the model at all looked live to the mtime sensor, to `ListAgents`, and to the lead.

Owed: (a) the liveness sensor keys on the last `assistant`/tool line's timestamp, not file mtime, and reports STALLED when none has landed for N minutes or when K consecutive `api-request` lines follow the last assistant line. Note the shapeHash alone does not discriminate: `7d7e1ada` appears 31 times in this transcript including before the wedge, so the arm keys on "no assistant line since", not on a repeated hash. The STALLED report names the likely cause: consecutive unanswered `api-request` lines after the last assistant line mean the model is unreachable (quota, auth or network), not that the agent is thinking. (b) The lead's procedure for STALLED: TaskStop, record the partial work, and — on the unanswered-request signature — tell the operator directly that the account may be out of usage, since only the operator can switch accounts and a re-dispatch on the same account wedges again; then re-dispatch or hand off with that state. Receipt: a probe transcript ending in 3+ `api-request` lines after its last assistant line, with a fresh mtime, reports STALLED; a transcript whose last line is a recent assistant line is the control and does not.

Deferred to next batch (operator, batch 235).

verify: manual

## BL-579 — at a handoff the lead attributes every uncommitted subject edit to the agent it stopped, so the successor is told to redo joined work

**DEFECT.** Filed by peer session ai-dlc-4e from graph's s319 handoff by lead `949015a6` (Sonnet 5.5), 05:35-05:41Z on 2026-10-16. At 05:40:05Z the operator typed "no, i mean handoff immediately"; the lead TaskStopped the serial remediator `a7ffc8dcd555207b8` at 05:40:11Z and committed `3dd8a9fd4` ("… sharded repair joined, serial repair stopped at handoff"). Its `pipeline-snapshot.md:36` lists prd.md, product-brief.md, s319/architecture-impact.md, s319/locked-requirements.md, SPEC.md and .memlog.md as the stopped agent's "UNRECORDED partial edits" and makes diffing them the successor's FIRST ACTION.

Intake re-attributed every `Edit`/`Write` in the session's subagent transcripts read-only (graph `~/.claude/projects/-Users-n8-git-graph/949015a6-…/subagents/`). The serial remediator wrote only `locked-requirements.md` and `prd.md` (2 tool calls each, one dated phrase apiece). The other files were written by sharded part remediators whose records the join accepted at 04:59:51Z (11 parts, 22 repaired, 2 escalated): product-brief.md by "Repair part 01 brief scope" and "Repair part 03 brief locked reqs"; architecture-impact.md by "Repair part 13 architecture-impact"; SPEC.md and .memlog.md by "Repair part 04 SPEC". prd.md is MIXED, not unrecorded: "Repair part 07 PRD locked bullets" wrote it at 04:56:58Z and 04:58:46Z, joined, before the serial remediator's 05:08Z phrase. `git diff --numstat 285c67f5d 3dd8a9fd4` on graph: product-brief +50/-4, prd +20/-17, architecture-impact +2/-2, SPEC +1/-1, .memlog +1/-0, locked-requirements +1/-1. So only locked-requirements.md's one line and one phrase inside prd.md are unrecorded; the rest are joined repairs that were uncommitted only because nothing committed after the join.

Consequence: the successor re-derives six files as unrecorded; at worst, "reverting unrecorded partial edits" undoes accepted pass-1 repairs.

Cause: `core/skills/ai-dlc/steps/handoff.md:27-53` (at 952b9319) says to stop in-flight teammates, record the stop, and "Commit any in-flight work … including work teammates left in the working tree" (`:52-53`), but gives no means of separating a stopped agent's own writes from the tree, so the lead inferred ownership from `git status` after a join it never committed.

Owed: (a) the handoff records each stopped agent's own writes from its transcript or from the write ledger that 0.790.0 made carry `tool_use_id` and transcript (CHANGELOG 0.790.0, BL-533), never from `git status`; (b) commit the subject after a join accepts a repair round, so a later stop cannot blur joined and in-flight edits. Receipt: a probe tree with a joined record whose parts edited A and B (and a shared file D also edited by the stopped agent), plus a stopped agent that edited C and D; the handoff's partial-edit list names C and D only, with A and B as the control that stays out.

Scheduled in batch 235 for a later release (scope ruling: the boundary is the release).

verify: manual

## BL-596 — the planning-artifact write ledger drops which tree a write landed in, so a worktree or clone write credits the main tree's shard

**DEFECT.** Filed by peer session ai-dlc-f5 from the BL-536 tip adversary run on `07dfcbfa` (b235-bl536 before its rebase onto 0.792.0), routed by lead ai-dlc-9c. `record_artifact_write` in `core/hooks/ai-dlc-gate-remediation-guard.sh` (`:519`, at origin/main 27467671) normalises its fallback spelling at `:528` — `*/${STATE_DIR_NAME}/planning-artifacts/*` → `_raw_rel="${STATE_DIR_NAME}/${1#*/${STATE_DIR_NAME}/}"` — stripping everything before the state-dir name. A write to `<repo>/.claude/worktrees/wt1/_bmad-output/planning-artifacts/s319/shards/stories-p1/2.md` is therefore recorded as `_bmad-output/planning-artifacts/s319/shards/stories-p1/2.md`, byte-identical to the main tree's shard path, with no trace of the worktree; the same holds for any scratch or rehearsal clone an agent of the session writes. BL-536's merge keys on that path.

Measured by the filer in mktemp worlds driving the real tip merge and hook, every ledger row written by the real hook: shards 1, 3 and cross-1..3 written through the hook; shard 2 present in the main tree with no hook-seen write; adversary `agWT` writes the worktree path above through the hook; the merge on the main tree's shard dir returned rc=0 MERGED with `2=toolu_01RcptWT` (expected: refuse, 2.md has no row for this tree). Control, same harness without the worktree write: refuses with `2.md has no row`.

Owed: the ledger row records which tree it was written in, or the merge refuses a row whose original spelling is not under this project root. This changes the row schema read by `join-remediator-shards.sh`, `merge-adversarial-shards.sh` and `validate-draft-stamps.sh`, which is why it was not folded into BL-536. Receipt: the filer's world above, refusing, with the no-worktree world as the control.

Scheduled in batch 235 for a later release (scope ruling: the boundary is the release).

verify: manual

## BL-597 — under a local-model lead the merge writes `call_…` dispatch ids that Check 24 reads as no ids

**DEFECT.** Local-model lead goal (operator ruling: a defect a local lead exposes is a pipeline fix). Filed by peer session ai-dlc-f5 from the same BL-536 tip adversary run on `07dfcbfa`. The harness meta records `toolUseId` in a non-Anthropic shape under a local model: intake found exactly 1 subagent meta on this machine carrying `"toolUseId":"call_` (another project, a local-model session), against 5065 carrying `"toolUseId":"toolu_` in the same glob. With meta and spawn-ledger ids of shape `call_…`, the BL-536 merge returns rc=0 and writes `shard_tool_use_ids: 1=call_1abc …`. Check 24's `k_has_ids` (`core/scripts/validate-adversarial-convergence.sh:1763-1764`, `case " $1" in *=toolu_?*`) answers NO on that line, so arm K treats a correctly derived round as carrying no ids. The merge's own id vocabulary is `toolu_`-only too: `RE_REAL_TUID='^toolu_[0-9A-Za-z]{24}$'` (`07dfcbfa:core/scripts/merge-adversarial-shards.sh:677`), and on origin/main `:585` refuses any `tool_use_id` that is not `toolu_?*`. Before BL-536 a non-`toolu_` self-reported id was refused at the merge; after it, the id passes the merge and is mis-scored downstream.

Measured by the filer: a receipt world whose every shard meta and spawn row carries `call_<k>abc`; the merge, then the `k_has_ids` predicate on its line → NO; control in the same run, the predicate on ` 1=toolu_01RcptX` → yes. Limit: the validator was not run, so the arm-K FAIL is predicted from its predicate, not measured.

Owed: one id vocabulary across the merge, `RE_REAL_TUID` and Check 24 that admits the harness's real id shapes, derived from what metas actually carry. Receipt: the `call_` world passes arm K end to end (the validator run, not the predicate alone), with a malformed id as the control that still fails.

Scheduled in batch 235 for a later release (scope ruling: the boundary is the release).

verify: manual

## BL-598 — `merge-adversarial-shards.sh --rerun <shard>@<S>` never checks S against a dispatch time

**NOTE.** Filed by peer session ai-dlc-f5 from the BL-536 tip adversary run on `07dfcbfa` (`--rerun` is documented at `core/scripts/merge-adversarial-shards.sh:68-80` there). S is taken as typed: a far-past S (`1999-01-01T00:00:00Z`) on a normal round merges; a future S (`2999-…`) refuses with `has no row`. Harmless today because the role check is the guard (that gap is BL-536 D1, folded there), but S binds nothing — the same hand-typed-time shape as BL-564's `--since`.

Scheduled in batch 235 for a later release (scope ruling: the boundary is the release).

verify: manual

## BL-599 — a FORWARD-dated `--since` is unmeasured against the BACKDATED arm, which judges only a row earlier than its dispatch

**PARTIAL (v0.802.0, verified ab065361) — the script half and rule-28 shipped; the `_gate-procedures.md` sentence is OPEN.** `wait-for-deliverable.sh --dispatch <agentId|name@team|toolu_ id>` reads the dispatch time from the spawn ledger, starts the join there when `--since` is absent, and refuses with exit 64 a `--since` later than the dispatch; `--since` without `--dispatch` warns on stderr. rule-28 tells the lead to pass `--dispatch`. Receipt `core/fixtures/wait-stale-deliverable/receipt.sh BL-599`. The frozen `_gate-procedures.md` still carries the old wording until its own release.

**DEFECT.** Carried from a BL-564 addendum that missed BL-564's close: b235-docs (4abbd6c3) archived BL-564 as landed in v0.792.0 with its `--since` half "CLOSED by operator ruling (batch 235, 2026-10-16) as covered by the BACKDATED arm: a back-dated `--since` follows from a back-dated row, which that arm refuses." That reasoning covers back-dating only. Filed by peer session ai-dlc-68 from graph s319 lead `949015a6` (Sonnet 5.5): the serial remediator was dispatched at 05:00:03Z on 2026-10-16, and at 05:00:04Z the lead armed `wait-for-deliverable.sh --since 2026-10-16T05:00:30Z …/s319/requirements-repair-p1.md`, 27s AFTER the dispatch, so any write in the remediator's first 27s was invisible to the beat. At 05:10:02Z it re-armed with `--since 2026-10-16T05:01:30Z` and called that "`--since` set to the dispatch time", false by 87s. The BACKDATED arm lives in `core/scripts/validate-artifact-budget.sh` (emitter `:1290`, "dispatched-at … is N s before its dispatch in the spawn ledger"), surfaced through `verdict.sh`, `validate-spawn-ledger.sh` and the write-time call in `core/hooks/ai-dlc-derivation-capture.sh` (all at 4abbd6c3). As written it judges an in-flight row's `dispatched-at` against the spawn ledger and fires only when the row is EARLIER than its dispatch; its header names the beat's `--since` (`:1203`) only as the window a back-dated row widens. Whether anything refuses a `--since` hand-typed LATER than a correctly stamped row is UNMEASURED: intake has not run the arm or the beat against a forward-dated `--since`. Back-dating accepts files older than the teammate; forward-dating misses the teammate's own early writes.

This does not reopen the operator's close of the back-dated half; it files the direction that close did not address. Owed: first measure the forward-dated case against the shipped arm and the beat; if uncovered, `--since` is derived from the in-flight row's `dispatched-at` (or refused when later than it). Probe: a `--since` later than the row is refused, with `--since` equal to the row as the control.

Scheduled in batch 235 for a later release (scope ruling: the boundary is the release).

verify: manual

## BL-582 — ai-dlc-update has no advisor touchpoint before its pushes and merges, and the advisor gate exempts them

**DEFECT.** Raised by the operator's question ("should the graph session have called the advisor before the push? I thought that was a requirement?"); filed by peer session ai-dlc-68 (listed as ai-dlc-4e [e15800]). Rule 32 touchpoint I — "Before a push, a merge or a deploy" — is in the pipeline skill only (`core/skills/ai-dlc/SKILL.md`, 1 line). `core/skills/ai-dlc-update/SKILL.md` at ffef448b names no advisor touchpoint: `advisor` 0 times outside "advisory" (4), control `self-update-fixtures` 6. `core/hooks/ai-dlc-advisor-gate.sh:58-74` excludes a push or merge while the cwd branch is `ai-dlc-update/*` and a push whose every refspec destination is `ai-dlc-update/*`, giving as its reason that the update skill is "a bootstrapping file; its text carries no touchpoint and this release does not edit it". The exclusion shipped in 0.738.0 (`9bdbc311`); that release's CHANGELOG cites an operator ruling for the per-kind gate ("THE SAME KIND (operator ruling, batch 201)") and lists the update-branch exclusion as release text with no ruling attached.

Measured on update session `1d7b4691` (Sonnet 5.5, the 0.791.0 → 0.793.0 pull, 2026-10-16): it pushed the self-update branch twice (02:45 EDT, failed TRANSPORT; 03:03 EDT), ran `gh pr merge 1230` at 03:10 EDT into `ai-dlc/carry-over/offramp-config-and-rewards`, pushed the reconcile branch at 03:22 EDT and ran `gh pr merge 1231` at 03:26 EDT. Intake counted 0 `advisor_tool_result` in its transcript against 4 in pipeline lead `f65eae3b` on the same model, so the tool was very likely available. Every one of those calls was exempt, because each merge ran while the cwd was still on the update branch. Two merges landed machinery into the sprint branch with the operator's approval ("merge is approved when ready") and no second reading — touchpoint I's case.

Owed: touchpoint I in ai-dlc-update/SKILL.md before step 2's self-update push and auto-merge and before step 8's delivery push and merge, and the hook's exclusion narrowed to the push of the update branch only, gating the `gh pr merge` into the original branch. Bootstrapping caveat: a fix to the update skill takes effect on the pull after the one that delivers it. Receipt: the hook denies a `gh pr merge` from an `ai-dlc-update/*` cwd with no advisor attempt; a push of `ai-dlc-update/x` stays allowed as the control; SKILL.md names the touchpoint at both steps.

Scheduled in batch 235 for a later release (scope ruling: the boundary is the release).

verify: manual

## BL-583 — the push suite costs about 8 fixture-hours per full run, over 40% in mutant batteries, and no fixture has been judged on value

**DEFECT (efficiency).** Operator-raised, 2026-10-16 ~04:30 EDT: "gating a release is so expensive, like stupidly expensive to run the push suite". Filed by peer session ai-dlc-68 (listed as ai-dlc-4e [e15800]). Assigned to ai-dlc-a6: phase 1 is a read-only census of where kill sets overlap, phase 2 is confirmation in the lead's slots after H-b. ai-dlc-bb's world-cache release already targets the `review-shard-merge-mutants` pole, so this entry does not count that saving twice.

Measured from `.git/ai-dlc-fixture-durations` in the main checkout, a LOADED-cost record that each push rewrites:
- Filer, at 04:29 EDT (288 rows): sum 28783 s (~8.0 h; ~40 min per full run on a pool of 12); 41 mutant rows at 12398 s, 43%; 12 of the top 15 rows mutant batteries at 583-737 s, the three non-mutant rows `snapshot-archive-rotate` 717 s, `suite-pole-guard` 493 s and `readset-skip-d` 410 s (corrected from 13 after lead ai-dlc-9c re-derived it); 130 rows at 60 s or more, 71 at 120 s or more, 82 under 10 s.
- Intake, re-derived at 06:18 EDT (288 rows, the record rewritten since): sum 27473 s; 41 mutant rows at 11346 s, 41%; 10 of the top 15 are mutant batteries (`derivation-capture-mutants` 737, `review-shard-merge-mutants` and `-b`/`-c` 728-729, `adversarial-shard-merge-mutants` 694, `remediator-shard-join-mutants` and `-b`/`-c`/`-d` 583-589, `updater-session-signals-mutants` 367), and the five non-mutant rows are `suite-pole-guard` 493, `readset-skip-d` 453, `ledger-reverify` 409, `-b` 392 and `-d` 362. Fixture directories: 290 (`/usr/bin/find core/fixtures -mindepth 1 -maxdepth 1 -type d`).
The two readings differ because the record moves with every push. The shape holds across both: the mutant batteries dominate the top of the rank.

Owed, under the step-value ruling in `operator-rulings.md` ("A step with no measured value goes") applied to fixtures — a fixture or mutant shard stays only on evidence, a named defect class it catches that no other unit catches; without that the batch retires or merges it, and it is not put to the operator as a choice:
1. Rank by cost first: the mutant batteries, then the non-mutant poles.
2. For each sharded battery, measure whether its mutants kill anything the base fixture's arms do not; shards of one battery that kill the same set are redundant.
3. State the gate wall clock removed per release and the dollars beside it.

Caveat: the record is a loaded-cost set from recent runs, not a solo timing, and a content-keyed push runs only part of it. The per-gate figure needs the gate log of a real release push (0.794.0 onward). Related: BL-558, BL-592, CLAUDE.md "A wall clock is a defect until it is justified".

Scheduled in batch 235 for a later release (scope ruling: the boundary is the release).

verify: manual

## BL-584 — two fixtures cannot be traced and have no `inputs.decl`, so they run on every push

**PARTIAL (v0.806.0, verified 4a6773ae) — owed (1) shipped for `fold-architect-ledger-join` only; owed (1) for `hermetic-runner` and owed (3) are OPEN.** `fold-architect-ledger-join` carries `inputs.decl` and `tools.decl` and runs under `hermetic-run.sh` (72 ok, `required_missing=0`); its 46 traced rows are removed. `hermetic-runner` reads its subject files from copies made once at startup. That cut its trace window about 6x (17691 lines to 2902, loaded) but did NOT stop the drops: one 6-fixture `--tracer sandbox` call dropped 3 reports in its window, and three `--local-map` reps dropped 1, 2 and 7, at load 27-43 (0 of 3 clean). The premise that the drops come from re-opening four tree files hundreds of times is REFUTED; the drop cause is undiagnosed. `hermetic-runner`'s 17 rows and digest are removed, so it runs on every push (fail-closed) until the drops are fixed. The earlier count of 27 held fixtures is 5: 27 have `#discards` at n≥3 in `.git/ai-dlc-fixture-readsets.local`, and only 5 are keyed on the current runner and deriver.

**DEFECT (efficiency).** Operator-raised, 2026-10-16 ~04:40 EDT: "what about the fixtures whose readsets cant be mapped? i do not believe you cant figure out a way to refactor those so they dont need to be run every time." Filed by peer session ai-dlc-68 (listed as ai-dlc-4e [e15800]).

Measured by the filer in the main checkout: 65 fixture directories have no row in `.ai-dlc-fixture-readsets.tsv`; 62 carry `inputs.decl`, so the hook counts them MAPPED (`.githooks/pre-push:866-871`) and keys them on the declaration; the other 3 (`lib`, `check-h1-recursion`, `check-manifest-bypass`) have no `run.sh` and are not units. `.git/ai-dlc-fixture-readsets.local` marks fixtures with `#discards` 3 or more when the live trace has thrown their result away three times and stopped retrying (`:954-956`, `:1304`). Intake re-derived: 86 `#discards` rows, 27 of them at 3 or more; `fold-architect-ledger-join` and `hermetic-runner` both have a `run.sh` and no `inputs.decl`. Per the filer those two are the only units that truly run on every push (173 s and 53 s recorded). Discard reasons across all rows, per the filer: 72 "the stream dropped reports", 9 "VERDICT: the sandboxed run's verdict lines differ", 2 "LOSS CANARY", 2 "TRIP".

Owed:
1. `fold-architect-ledger-join` and `hermetic-runner` get an `inputs.decl` and `tools.decl`, so `hermetic-run.sh` runs them hermetically and the hook keys them like the other 62; the sandbox proves the declaration complete.
2. A fixture that cannot be declared because it reads the whole tree by design says so in one README sentence, and is scored under BL-583's value test.
3. Find and fix why the trace stream drops reports (72 rows); while it does, every new undeclared fixture lands in the run-every-push set.

Caveat: in a linked worktree the local map is a different file (the BL-558 symptom); the fixtures unmapped there are re-measured once (1) lands. Related: BL-558, BL-583.

Scheduled in batch 235 for a later release (scope ruling: the boundary is the release).

verify: manual

## BL-601 — the handoff-entry hook arms the lead's handoff marker on a TEAMMATE's Read of steps/handoff.md

**DEFECT (latent; 0 measured occurrences).** Filed by peer session ai-dlc-11, found by the batch 235 release V contract adversary while it sized BL-590. `core/hooks/ai-dlc-handoff-entry.sh` (PostToolUse on Read) writes the project-wide `.handoff-in-progress` whenever `steps/handoff.md` is read, with no `agent_id` test: intake counted `agent_id` 0 times in it at origin/main 3d5f1e70, against 4 in `core/hooks/ai-dlc-recover-gate.sh` (the control, which BL-590 bound). So a dispatched teammate's Read of that file arms the lead's marker — BL-590's shape (graph measured 253 denied teammate calls there).

Measured by the filer on graph's transcripts, 2026-10-16: 0 of 3237 subagent transcripts hold a `Read` of a path ending `steps/handoff.md`; control: 69 of 178 lead transcripts do; grammar control: the same pattern over any `steps/*.md` matched 357 subagent transcripts; negative control: an impossible path matched 0. The hazard has never fired on the reference consumer.

Owed: the hook's write applies to the lead only (empty `agent_id`), as BL-590 binds the recover gate, with an arm and a mutant: a teammate's Read leaves no `.handoff-in-progress`, and the lead's Read still writes it. ai-dlc-11 builds it as a small release after V2 (BL-590) merges.

verify: manual

## BL-605 — an In-Flight row's `dispatched-at` can be stamped LATER than the real dispatch, and the BACKDATED arm is quiet on a late row by design

**DEFECT.** Filed by peer session ai-dlc-ad, read-only on graph. Graph's `_bmad-output/pipeline-snapshot.md:68` (In-Flight Teammates) reads `remediator (serial, pass 1 cross-part, a7ffc8dcd555207b8) | remediator | s319/requirements-repair-p1.md (appended) | 2026-10-16T05:01:00Z | stopped` (intake confirmed). BL-599's filing puts that remediator's dispatch at 05:00:03Z, so the row is 57 s late. `core/scripts/validate-artifact-budget.sh` `check_backdated_dispatch` states at :1213 (origin/main 3d5f1e70) "A row stamped LATE (after its dispatch) stays quiet; this arm is about back-dating only." Measured by the filer on the extracted function with a one-row ledger at D: a row at D-112 fires BACKDATED (control), and rows at D, D+27 and D+87 are quiet.

Effect: `_gate-procedures.md:149` tells the lead to pass the row's `dispatched-at` as the beat's `--since`, so a late row is a forward-dated `--since`, which (BL-599) misses every write the teammate made between the dispatch and the stamp: the beat reads WAITING on a delivered file. BL-599's release adds `wait-for-deliverable.sh --dispatch <tool_use_id>`, which reads the spawn-ledger `ts` and refuses a `--since` later than it; that guards the beat but not the row, which other readers use.

Owed: the row is stamped from the ledger `ts`, or a write-time arm fires on a row later than its dispatch by more than a stated tolerance. Probe: a row 57 s late fires; a row at the dispatch is quiet.

verify: manual

## BL-606 — the pre-push fixture pool runs every unit with no per-unit timeout

**NOTE.** Filed by peer session ai-dlc-bb (batch 235 gate throughput), derived by the BL-592 contract adversary and re-derived by the filer. At origin/main 3d5f1e70 the pool worker runs each unit unbounded: `.githooks/pre-push:2027` (`bash "$hr" --root "$PWD" "$b"`) and `:2035`, `:2039` (`bash "$d/run.sh"`), intake confirmed; `core/git-hooks/pre-push` carries the same lines (I66 binds the pair). Per the filer the hook's 13 timeout/watchdog/`ulimit -t` matches all belong to the detached read-set trace's watchdog (:992-1054, :1194, :1217, :1315) plus a tool-key comment at :1339. `core/scripts/hermetic-run.sh` has 0 timeout/watchdog/`ulimit -t` matches against 6 `inputs.decl` (intake confirmed). The only hang bounds in the suite are the five mutant batteries' per-scorer watchdogs (BL-592's subject). A unit that hangs anywhere else hangs the push indefinitely, and a slow unit is indistinguishable from a hung one except by the operator watching the clock. No hang has been observed. Remedy left to the builder; one option is a per-unit bound derived from the unit's recorded clean cost.

verify: manual

## BL-607 — `ai-dlc-recover.sh` and `ai-dlc-recover-gate.sh` lack the ai-dlc-update stand-down, so a consumer's pull session that compacts gets the pipeline's recovery mandate and its deny

**DEFECT.** Filed by peer session ai-dlc-60 from batch 235's delivery read of 0.797.0 (3d5f1e70), confirmed by lead ai-dlc-9c by reading. `core/hooks/ai-dlc-recover.sh` (SessionStart) injects the pipeline's post-compact recovery block and writes `.recover-fired`; `core/hooks/ai-dlc-recover-gate.sh` (PreToolUse on Agent, Task, Write, Edit, MultiEdit, NotebookEdit; widened in 0.797.0) then denies those tools until `_bmad-output/pipeline-snapshot.md` and the step file are Read. Neither is scoped to the update skill: intake counted `ai-dlc-update` 0 times in each at 3d5f1e70, against 24 in `ai-dlc-acknowledge.sh`, 6 in `ai-dlc-pause.sh` and 4 in `ai-dlc-continue.sh` (continue allows the stop when the session skill is `none|ai-dlc-update`). Per the filer, recover.sh's only guards are the snapshot existing (~:53), a `jq` check and `[ "$SOURCE" = "compact" ] || exit 0` (:60).

Graph carries `_bmad-output/pipeline-snapshot.md` (intake confirmed), so an `/ai-dlc-update` session that compacts after step 2 has installed the 0.797.0 hooks is told to Read the pipeline snapshot and step file and denied its next Write or Edit until it does — the pipeline lead's recovery rule applied to the updater. Cost: one turn plus two irrelevant Reads per compaction; never a wedge, because the Reads clear it. Bootstrapping: the hooks arrive in step 2, so first exposure is the pull that delivers 0.797.0.

Owed: both hooks get the session-skill stand-down that acknowledge, continue and pause use (last ai-dlc skill marker `ai-dlc-update` → silent), single-sourced in a shared helper rather than a fourth copy. Receipt: a seeded update-session transcript with a `compact` SessionStart — recover.sh writes no `.recover-fired` and injects nothing, and recover-gate allows a Write; control: the same seed with an `/ai-dlc` marker is still injected and gated.

**Widened: the hazard predates 0.797.0, and a session that never compacted is denied too (measured by ai-dlc-60).** A grep-only census over graph's 179 transcripts (28 s): graph's installed `ai-dlc-recover.sh` and `ai-dlc-recover-gate.sh` (the c16609ba blobs) already carry it — the gate's read stages date to 0.372.0, and 0.797.0 added only the advisor stage. Of 78 transcripts whose last ai-dlc marker is `ai-dlc-update`, 2 received the recover-gate deny "your FIRST tool call must be `Read _bmad-output/pipeline-snapshot.md`" (control: 30 transcripts corpus-wide).
- `70eefff8` (2026-09-23): auto compactions at 06:01:39Z and 11:10:23Z, then the denies. Intake counted 2 `compact_boundary`; the 5 denies are 4 FIRST-call lines and 1 SECOND-call line (the filer's breakdown).
- `70871959` (2026-10-15, 10:33Z): ZERO `compact_boundary` (intake confirmed 0), yet its first Bash call, the stamp read, was denied 11 s after `/ai-dlc-update` (1 deny line).
Cause of case 2, measured at a0451c70 by the filer and re-derived by intake: `ai-dlc-recover-gate.sh` uses `session_id` only in its advisor stage (`:136` writes it to `.recover-advisor-owed`, `:151` compares it, `:372` is the `owed_put`). The read stages read only `.recover-fired`, whose keys `ai-dlc-recover.sh` writes as `fired_at`, `injected_bytes`, `context_limit`, `degraded`, `snapshot_path`, `step_file` and `step_file_resolved` — none of them a `session_id`. So the read stages cannot tell one session's marker from another's, and a `.recover-fired` left by another session's compaction denies an update session that never compacted. That a stale marker was the cause in `70871959` specifically is still inference.

Consequence: a stand-down in `recover.sh` alone does not cover case 2 — the update-session stand-down must sit in `recover-gate.sh` as well. The receipt gains a case: a pre-existing `.recover-fired` with no compaction leaves an update-session Bash call silent, and the same seed with an `/ai-dlc` marker still denies. DEFECT stands.

Owner: ai-dlc-60, as a release behind U-b (lead ai-dlc-9c's assignment): an update-session stand-down in both hooks through the shared session-marker scan, the gate's read stages keyed on `session_id`, a 5-case receipt, and an FP set measured against graph's 179 transcripts.

verify: manual

## BL-608 — the validator fork budget's headroom eroded from +6 to 0 across five releases, and nothing warned

**DEFECT.** Filed by peer session ai-dlc-a6. `scripts/validate-enforcement-map.sh` FORK_BUDGET was set to 3363 in 0.786.0 as "HIGH reading 3357 plus the usual 6" (paragraph ~:825-831 then). Measured by the filer on 2026-10-16 with `fork-profile.sh --section by-arm --stable`, interleaved base/tip/base/tip in one detached worktree at one path, caller environment inherited: origin/main e3073787 (0.796.0) read 3362 and 3363 (STABLE 2, spread 3360-3362), equal to the budget — 0.792.0 through 0.796.0 spent the full +6 and no arm said so. `validator-fork-budget` fails only when the reading EXCEEDS the budget (its arm A3, "measured <= FORK_BUDGET"), so the window between "headroom gone" and "red" is invisible; at zero headroom the instrument's ±1-2 jitter makes any release adding one fork a ~1-in-4 red that reads as a flake. On 0.797.0 (+1 fork, I126 0 -> 1) the re-verify read 3362 with one rep at 3364 against 3363; 0.797.0 raised the budget to 3370 (+1 for its arm, +5 to restore headroom), which intake confirmed as `FORK_BUDGET=3370` at origin/main 3d5f1e70 (`:841`).

Owed: a headroom arm in `validator-fork-budget` that FAILS when the STABLE reading + 2 > FORK_BUDGET, naming the remedy (re-measure and raise by the HIGH reading plus 6, per the file's own rule), so erosion reports while margin remains. It needs its own mutant (the arm with the +2 dropped must miss a seeded reading at budget - 1) and its FP set measured over the budget history in that file's paragraphs. Scope: a small later release.

verify: manual

## BL-610 — the read-set sandbox tracer omits any fixture that probes process liveness

**NOTE.** Filed by peer session ai-dlc-a6 on lead ai-dlc-9c's instruction. `core/scripts/derive-fixture-readsets.sh --tracer sandbox` runs each fixture under `sandbox-exec` with a profile that grants file and process-exec rights but no process-info rights (intake: `process-info` 0 times in the script, against 16 `sandbox-exec`). Inside it `ps -p` sees no other process, not even its own shell, so a fixture whose premise is process liveness fails its own controls and the deriver omits it ("OMITTED (fixture exited 1) -- will always run", 1 occurrence in the script).

Measured by the filer on 2026-10-16 in a trace of 14 fixtures at a0451c70 (rc 0, 173 s, 13 mapped): `derivation-differential` was omitted (its `run.sh` uses `ps -p` 7 times). Its sandboxed log `/private/tmp/ai-dlc-readset-sandbox-501/w/derivation-differential.log:47-48` carries 4 FAIL verdicts, all in A12: the two liveness controls (:47, :48) and the two near-misses they gate (:51 A12l, :52 A12e). No arm outside A12 failed. Of the 13 lines containing `FAIL`, the other 9 are 8 `ok` lines reporting NEWLY-FAILING and the `4 assertion(s) FAILED` summary (intake confirmed the breakdown). The two controls:
  `FAIL  A12 control: ps -p does not separate the seeded dead PID (52683) from the live one (46059) -- A12b and A12l are unreadable`
  `FAIL  A12 control: PID 1 does not separate ps -p from kill -0 here (running as root?) -- A12e is unreadable`
Outside the sandbox the fixture is green: per the filer, `ok derivation-differential` appears in all three 2026-10-16 gate logs (an impossible token reads 0), with 7 loaded runs that day at 15-31 s each.

Cost: it stays unmapped and runs on every push, about 20 s, not the gate pole. It ran on every push before too (its rows were stale), so this is a permanent read-set gap, not a regression. Two candidate fixes, neither chosen: grant process-info in the profile (broadens what a trace records, to be weighed), or skip the liveness arms under the sandbox (weakens the fixture exactly where the trace looks; not recommended). Not to be fixed now.

verify: manual

## BL-611 — two fixtures whose verdict depends on the real `docs/backlog.md` are never re-run when only the backlog changes

**DEFECT.** Found by batch 235 intake on the intake-2 docs gate (2026-10-16), adjudicated with lead ai-dlc-9c. That push changed `docs/backlog.md`; the content-key skip passed over `backlog-receipt-binding` and `backlog-size-ceiling` although both `inputs.decl` list `docs/backlog.md` (a non-`!` line). By design: `core/scripts/hermetic-run.sh:374-375` (origin/main) states a dist sandbox "declares VERSION and docs/backlog*.md, which sit under EXCLUDED tops and so are in no population", so a declared `docs/` file is copied into the sandbox but never keyed. Their recorded keys (`.git/ai-dlc-fixture-keys/<fx>.key`) carry no `docs/backlog.md` row (0), against `scripts/backlog-reverify.sh` and the fixture's own files (1 each).

It is a GAP, not a correct skip, because both verdicts can change when only the backlog changes:
- `backlog-receipt-binding` arm j1 (`run.sh:785-824`) copies the real ledger (`:105-106` resolves `docs/backlog.md`; `:788` `cp "$REAL_LEDGER"`) and joins the validator's `sh` population against `backlog-reverify.sh`'s resolved set. It FAILs when either side is 0, when the arm's population is smaller than the classifier's (`:820`), when `--declared-empty` misbehaves on the real file (`:796`), or when the real ledger already carries the anchor `BL-899` (`:798-800`). Each of those is a property of the ledger's content.
- `backlog-size-ceiling` arm b16 (`run.sh:400ff`) does the same join for the size ceiling (`:408` `cp "$REAL_LEDGER"`), branching on the real ledger's declared-empty state. Its own comment says it is "the one that catches a drift filed after this fixture was written".
So a backlog commit that introduces exactly the drift these arms exist to catch is skipped on the push that carries it; it surfaces only on the next push that happens to change the validator, the classifier or the fixture. Cost if keyed: `backlog-receipt-binding` 139 s, `backlog-size-ceiling` 4 s recorded (loaded), on every push that edits the backlog — most docs releases.

Owed: decide, with the cost stated, whether a declared EXCLUDED-top file is keyed for the fixtures that declare it (a per-fixture opt-in, not a population change), or whether the real-ledger arms move to a cheaper, separately keyed unit. Receipt: a push that changes only `docs/backlog.md` re-runs a fixture whose arm reads it, with a push changing an unrelated file as the control that still skips it.

verify: manual

## BL-587 — a reconcile that records derivations "owed to the sprint's derivation-validator step" has no channel to the sprint lead, so the debt is silently dropped

**DEFECT.** Filed by peer session ai-dlc-68 (listed as ai-dlc-4e [e15800]) from the graph s319 watch; intake re-derived every figure read-only on graph.
- The 0.793.0 reconcile log `_bmad-output/ai-dlc-update/reconcile-log-20261016T0725Z.md:35-43` records the operator's AskUserQuestion disposition "**leave untouched, record as owed**" and lists 8 newly-failing `grep -n` derivations "Owed to the S319 session's derivation-validator step": carry-over-evaluation-architect-5.md:13 and :23, carry-over-evaluation-pm-5.md:13, prd.md:1289, carry-over-evaluation-party-repair-p1.md:632, requirements-party-repair.md:859, shards/carry-over-evaluation-party-repair-p1/5.md:15 and shards/requirements-party-repair/08.md:102 (the BL-581 set). `prd.md:1289` and `s319/requirements-party-repair.md:859` still hold their old `$ grep -n -F -e "  ok  %-44s" … scripts/ai-dlc/validate-artifact-budget.sh` commands in the working tree.
- The 0.798.0 pull's log (`reconcile-log-20261016T105433Z.md`, 51 lines) carries no owed list: its 3 `owed` mentions are a path list, an `audit-layer-debt` count and a ledger re-verify line, and "record as owed" occurs 0 times. That is correct for its own differential — those 8 were already failing at its base, so it cannot report them as NEWLY-FAILING — and it means the only record stays the 0.793.0 log.
- The resumed s319 lead `cf53b84f` (resumed 07:26 EDT) ran `validate-artifact-derivations.sh` (17 mentions) at 07:59 EDT on `requirements-repair-p1.md` only. Its transcript mentions `reconcile-log-20261016T0725Z` 0 times, `prd.md:1289` 0 times and "record as owed" 0 times, against `requirements-repair-p1` 60 times. `_bmad-output/pipeline-snapshot.md` carries `reconcile-log` 0, `prd.md:1289` 0 and an owed-derivation line 0, against `requirements` 12.
So the debt lives only in a file no step of the resumed sprint reads.

Owed:
1. When a reconcile records items owed to a sprint, write them where the sprint reads them — the snapshot's owed/watch section, or a debt row a lead-side check refuses to pass while it is open.
2. The step-0a resume integrity check, or the step's own derivation-validator run, reads that record and re-points each derivation or shows it as open.
3. Prove it on this instance: the 8 rows above. (Per BL-581 each is a line-number re-point, not removed text.)

Related: BL-581 (the false-zero "Verified" in the same 0.793.0 log), BL-579 (the snapshot misreporting the stopped remediator's writes).

**Scope ruling (operator, relayed by lead ai-dlc-9c): CURRENT SPRINT only.** The owed record, its channel, and its check carry derivations owed to the sprint that is current when the reconcile runs. A derivation in a past sprint's artifact is owed to nobody, and must neither block that sprint's lead nor show as open there. The ruling is BL-631's: "I'm stating that I don't care if a fixture or check fails against a historical sprint artifact", and "if someone deleted all of graph consumer's sprint history, it should not matter whatsoever". Item 3's proof is therefore over those of the 8 rows whose artifacts belong to the current sprint. A control row in a past sprint must NOT appear in the record.

**Second instance (graph 0.800.0 → 0.803.0 reconcile, session `89a3adec`, 12:43-12:49 PM EDT).** Filed by ai-dlc-68 (listed as ai-dlc-4e [e15800]); intake re-derived it read-only on graph. `_bmad-output/ai-dlc-update/reconcile-log-20261016T164848Z.md:27-31` (68 lines; committed as `4558f87fe`) records `derivation-differential.sh` exiting 1 with 5 NEWLY-FAILING derivations. Three of them are in the LIVE sprint s319:
- `party-mode/s319/carry-over-evaluation-pm-3.md:38`
- `planning-artifacts/s319/carry-over-evaluation-party-repair-p1.md:337`
- `planning-artifacts/s319/shards/carry-over-evaluation-party-repair-p1/3.md:35`
Each greps `carry-over-evaluation.md` for 'dominant work rather than one item among', and upstream inserted a line above that text: the file grew from 251 lines at `efcd5373` to 266 at `21facb0f`. The other two rows belong to closed sprints, `s303/test-strategy-repair-p1.md:286` and `s308/derivation-staleness-repair-p2.md:61`.

The operator was asked and answered "Record, don't edit (Recommended)"; that phrase occurs 4 times in the session transcript. The disposition went only into the reconcile log. `_bmad-output/pipeline-snapshot.md` carries none of the three s319 rows and does not name the log (0 hits for each; control: `s319` 8). The s319 debt is now 11 re-points: the 8 from 0.793.0 plus these 3.

The question also rested on a false premise. The log's disposition says "these are closed or sha-locked sprint artifacts", and "sha-locked" occurs 6 times in the transcript. s319 is mid-sprint, though, and its repair records are append-only, not closed, so a later block can supersede these derivations: BL-588's mechanism, landed in 0.803.0.

Under the current-sprint scope ruling above, this instance is exactly the discriminating input. The three s319 rows must reach the lead, and the s303 and s308 rows must not. Receipt addition, as suggested by the filer: seed a closed-sprint row (s303) and a live-sprint row (s319) from one reconcile log, and assert that only the live one reaches the lead, whether or not the reconcile chose to edit.

**PARTIAL (v0.808.0).** Delivered: items 1 (debt-row half) and 2. Withdrawn by operator ruling: item 3 (the 8 rows are prose in a reconcile log written before this release, never recorded, so no reader can pick them up; the receipt proves the shape on seeded rows). The 8 rows are live CURRENT/LIVING stale derivations in graph; the operator hands them to graph's own session to re-point, with the 3 s319 rows of the second instance. Open: item 1's snapshot half (D6: no writer can reach the working branch before the reconcile PR merges). Scoped by operator rulings: current sprint and living documents only; refused at the planning gate only.

**What the first instance cost (graph watch ai-dlc-f7, filed as BL-622 and folded here as the same claim; intake re-derived it read-only).** Of the 8 rows from the 0.793.0 log, one is `planning-artifacts/prd.md:1288-1289`, whose fence greps `scripts/ai-dlc/validate-artifact-budget.sh` for `"  ok  %-44s"` and records line 1676 (written in `dbc4c057e`). The line is 1676 at `8f313c3c0` and 1955 from `41d2dbf91` onward. The s319 lead found it about 14 hours after the pull, and only because two pass-2 adversary shards (parts 11 and 6) flagged it: transcript `0e9a936b`, first mention at 21:56:59Z, 17 mentions in all. It now sits in graph's live snapshot (`pipeline-snapshot.md:40`) as "STALE LIVE FENCE (owed to the pass-2 repair, NOT editable before the pass-2 merge because every shard notarized prd sha 15c46858 and the --subject merge refuses a moved sha)". The other 7 owed sites have no sprint-side record. So the missing channel cost an adversary dispatch to recover a grep result.

That snapshot line also names a sub-case the channel has to handle. `core/skills/ai-dlc-update/reconcile/apply.sh:1404`'s WORKLIST remedy says only to re-point each fence, but a live-sprint file whose sha the round's shards have notarized cannot be edited mid-pass. The owed record must therefore survive until the sprint's next repair, not merely reach the lead. Control for "no core reader": 0 files under `core/skills/ai-dlc`, `core/hooks` or `core/scripts` name `ai-dlc-update/reconcile-log` at `581ca289`, against 9 naming `operator-requests-history`. Probe, from the filer: seed a pull that NEWLY-FAILs one fence in a live-sprint artifact, dispose it as owed, and assert the next sprint resume names that file:line. A fence in a closed-sprint artifact stays quiet (near-miss).

verify: manual

## BL-613 — `validate-backlog-receipts.sh` run bare fails R5 on a clean main, because its default floor is stale

**NOTE.** Found by intake ai-dlc-40 and independently by ai-dlc-11, both on clean origin/main `d19a4d9f`. `scripts/validate-backlog-receipts.sh:190` sets `DEFAULT_MIN_SH=76`, and `:565` uses it when `--min-sh-receipts` is absent. The live ledger holds 0 `sh` receipts, so a bare run exits 1 with "R5: the sh receipt population fell by 76 (from 76 to 0)". The gate passes `--min-sh-receipts 0` (`.githooks/pre-push:266-268`, since 0.746.0 `011cd83e`), so pre-push is green while every hand that runs the script by name sees a red unrelated to its change. Two sessions in batch 235 hit it and each had to re-run on main to rule out their own commit.

Owed: one source for the floor that both the script's default and the gate read, so the bare run and the gate answer alike. Receipt: a probe showing a bare run and a gate-flag run agree on the live ledger, and that a seeded drop below the floor fails both.

Owner: ai-dlc-40 (lead ai-dlc-9c). It changes a script, so it rides whichever release is still unbuilt when the fix is ready (most likely the BL-575/577/594 branch), never a built or gating one.

verify: manual

## BL-614 — a one-line `FORK_BUDGET` raise re-runs every unit keyed on `validate-enforcement-map.sh`, though only one fixture reads the number

**NOTE (efficiency).** Found by intake ai-dlc-40 while checking lead ai-dlc-9c's filing on ai-dlc-11's 0.801.0 push. `FORK_BUDGET=3374` sits at `scripts/validate-enforcement-map.sh:848` (origin/main `d19a4d9f`). The validator never reads it: its other 8 mentions are comments (control: `I75` appears 18 times in the same file). Its only reader is `core/fixtures/validator-fork-budget/run.sh:96-101`. The content key is per-file, so a budget raise (3374→3395 on `b235-combo`) changes the validator's key, which invalidates every unit that depends on it.

Measured on origin/main: 20 units are keyed on the validator, 15 by an `inputs.decl` line and the rest by `.ai-dlc-fixture-readsets.tsv` rows. Together they cost 2906 s in `.git/ai-dlc-fixture-durations`, a loaded record. The largest are `fold-architect-ledger-join-mutants-c` at 438 s, `fold-architect-ledger-join-mutants` at 414 s and `readset-skip` at 322 s. The suite is pole-bound, so a budget-only change costs roughly that 438 s pole in wall clock, not the 2906 s sum. A raise that ships alongside a real validator edit costs nothing extra.

Premise corrected at intake: the 1300-1400 s batteries in that push (adversarial-shard-merge-mutants, derivation-capture-mutants, ledger-reverify(-b), review-shard-merge-mutants(-b,-c)) are NOT keyed on the validator. Neither their `inputs.decl` nor the read-set map names it (control: `validator-fork-budget` keyed both ways). They ran because the combo's own diff touched files they declare: `partition-document.sh`, `steps/gate-validation.md`, `validate-artifact-derivations.sh` and `reconcile/post-write-gates.sh`.

**Correction (lead ai-dlc-9c, from ai-dlc-ad's 0.802.0 gate log; re-derived at intake on origin/main `f4ca6764`).** The two sentences above about which units are keyed, and how, were wrong. Two mutation batteries ARE keyed on the validator, and the first count missed them because it matched only `inputs.decl` lines naming the file exactly. An `inputs.decl` line ending in `/` declares a whole directory (`readset_decl_parse`, `.githooks/pre-push:1413-1436`), so `scripts/` keys every file under it, this validator included. A declared fixture is keyed on its declaration and never on its read-set row (`.githooks/pre-push:1507-1515`). Re-derived from both sources:
- `inputs.decl`: 21 fixtures, 15 naming the file and 6 through a `scripts/` entry: `fold-architect-ledger-join-mutants` and its `-b`, `-c` and `-d` shards, `suite-content-key` and `vocabulary-index`. Control: a line equal to `scripts/ZQX-none.sh` matches 0, and 20 `inputs.decl` lines are exactly `scripts/` or `!scripts/`.
- `.ai-dlc-fixture-readsets.tsv`: 7 rows name the file, among them `fold-architect-ledger-join-mutants` at row 4328 and `-c` at row 4591. All 7 belong to fixtures that also carry an `inputs.decl` (248 do), so the declaration decides and the rows add no unit.
- So the effective set is 21 units. They cost 2922 s summed in the loaded record as it stood at `f4ca6764`, and the four fold-architect shards lead at 281, 265, 265 and 264 s. That record is rewritten on every push, and the 438 s and 414 s above were older readings of the same two shards.
- `-b` and `-d` carry 0 read-set rows, but they are keyed through `scripts/` like the other two, so they do NOT run on every push. They run whenever any file under `scripts/` changes, which is a far wider trigger than this validator.
- The statement above that `validator-fork-budget` is "keyed both ways" was also wrong: it has 0 read-set rows and is keyed by its declaration alone.
The wall-clock reading stands in shape: a budget-only change costs about the largest shard (~281 s loaded at `f4ca6764`), not the sum.

Owed: move the budget to a data file that only `validator-fork-budget` reads, keeping its column-0 single-line anchor (`run.sh:92-101`) and its A4 reachability arm. The data file must sit outside `scripts/`, or the four fold-architect shards' directory entry re-keys them anyway. Receipt: a budget-only change re-keys `validator-fork-budget` and no other unit. Show it with the hook's own key computation on a probe commit, and use a one-character edit to the validator as the control, which must re-key all 21.

Owner: ai-dlc-40 (lead ai-dlc-9c). It changes a script and a fixture, so it rides the next unbuilt release with BL-613, never a built or gating one.

verify: manual

## BL-615 — adversary seats and shards are never told to resolve a code path with `git ls-files`, so BL-550's second instance is uncovered

**DEFECT (efficiency).** Filed by peer session ai-dlc-c9 at lead ai-dlc-9c's direction, out of c9's release (a), where it was item A6 and was taken out because BL-550 is closed and A6 would have closed nothing. Intake re-derived it read-only at origin/main `86d3a695`.

BL-550 is archived LANDED (v0.794.0, verified `2f6d5199`) on its role-file half: the party-seat section of `architect`, `dev`, `pm` and `tea`, byte-identical across the four under I124, tells a seat to list a code path with `git ls-files <dir-or-glob>` before reading it. Its receipt loops over `architect dev pm tea` only. The archived entry also records a **second instance, in the adversarial round** (graph s319 resumed lead `f65eae3b`, requirements-adversarial-p1): seven parts (1, 2, 6, 8, 13, cross-3 and cross-6) made 13 greps for paths that do not exist, such as `dashboard/`, `shared/tokens.py` and `rebalancer/config_schema.py`.

Those shards run the `adversary` role. `_gate-procedures.md:413`, `:422`, `:444`, `:585` and `:609` dispatch "one `adversary` per story ordinal", "one `adversary` per part plus one cross-part `adversary`", and so on. The adversary side has no instruction:
- `git ls-files` counts over `core/team-roles/*.md`: `adversary.md` 0, against `dev` 2 and `architect`, `pm` and `tea` 1 each (the control).
- `_gate-procedures.md` has 0 mentions of `ls-files` (control: 28 mentions of `adversary`).
- `adversary.md` (552 lines, 9 `##` headings) never says "code path" and has no `## As a party seat` section.

So the LANDED close never reached the role that produced the second instance. The open backlog does not cover it either (0 `ls-files` mentions).

Constraint on the fix: I124 (`scripts/validate-enforcement-map.sh:13573`, `i124_names='architect dev pm tea'`) binds the party-seat section to exactly those four roles. Its half B fails the push on any other role file carrying a heading opening "As a party seat". The instruction therefore cannot reach `adversary.md` by copying that section. It needs its own text in `adversary.md`, or in the shard brief `_gate-procedures.md` dispatches, or I124's list must widen deliberately. The I123 chunking paragraph is the other binding a role-file edit has to respect.

Rejected at contract time: release (a)'s A6 candidate derived a `code paths:` block for the brief with a hand-written regex in prose (`git ls-files | grep -F -x -f <(grep -ohE '[A-Za-z0-9_./-]+\.[a-z]{1,4}' …)`). The contract adversary flagged it as verification-discipline's hand-regex class (a second implementation of a path grammar). Whether the fix is prose or a mechanism is this entry's decision.

Owed:
1. Decide prose (an `adversary.md` or shard-brief instruction) or a mechanism (a path list derived by shipping code, not a prose regex), and record why.
2. Receipt: run the shipping code, not a grep of the role file. For example, a shard brief rendered for a subject naming a non-existent path shows the resolved/absent split; or, for prose, a receipt over the dispatched brief and not over BL-550's four files. Control: the four party-seat roles still pass I124.

Related: BL-550 (archived; both instances), I124, I123.

verify: manual

## BL-616 — fixture verdicts depend on box load: `validator-fork-budget` reads FIXTURE BROKEN under the gate's pool, and a red costs a full re-push

**DEFECT (efficiency).** Operator directive, relayed by lead ai-dlc-9c: "we need to not be so sensitive to load, it's a self-inflicted issue that fixtures are marked as failed because of it and/or aren't considered successful." The scope is every load-sensitive verdict in the suite, not only the one instance below.

The measured instance is `core/fixtures/validator-fork-budget`. Its arm A2 (determinism, `run.sh:22`, driven at `:262` via `scripts/fork-profile.sh --section total --stable`) requires a repeated total among the `--stable` profiles of an unchanged tree (`fork-profile.sh:33`, `:334`).
- 0.802.0's gate, 10:45-10:54 EDT: `.git/ai-dlc-fixture-failures.20261016T145420Z.9311` reads "1 of 59 units red", then "FIXTURE BROKEN: the profiler could not produce a repeated reading of the real validator. fork-profile: 4 profiles of an unchanged tree produced no repeated total (3400 3399 3401 3397 ). A single dropped xtrace line is expected under load and is subtractive; this is something else." The gate went red and the push was lost.
- ai-dlc-11's slot for 0.801.0: 3388, 3390, 3391 and 3389, the same FIXTURE BROKEN (reported by 9c; intake has no record file for that run).
- Run solo at low load, ai-dlc-11 and ai-dlc-ad each got a clean repeat (reported by 9c; not re-measured at intake, gate window).

A fork COUNT of a fixed tree should not move with load, so the readings drifting both above and below each other means something forks a timing-dependent number of times, or the instrument loses and gains trace lines under load. The record's own text says a dropped line is "subtractive", and readings that rise as well do not fit that alone. The cause is NOT established here: ai-dlc-4e [9b62de] is running the by-line census (`scripts/fork-profile.sh --section by-line` at two loads, differenced) and will add it.

Owed:
1. Find the cause in the measured instance and remove the load dependence at its source (a verdict that holds at any load), rather than retrying until a repeat appears.
2. Census every other verdict in the suite that can change with load (timeouts, wall-clock bounds, poll counts, repeat-until-stable arms), and list each with its mechanism.
3. Receipt per fixed unit: its verdict is identical solo and under the gate's pool at the recorded load. Control: one unit known to be load-free agrees both ways too.

Each instance costs a full re-push of the release, which is the consequence this entry is tiered on.

Owner: ai-dlc-4e [9b62de] (lead ai-dlc-9c).

**Cause and census (ai-dlc-4e [9b62de], 2026-10-16 11:13-11:15 EDT; intake spot-checked the cited lines at origin/main `f4ca6764`).**

*A2's cause is the instrument, not the validator: trace records are spliced, not lost.* Six profiles of `f4ca6764`, taken two at a time at load 2.8, read 3400, 3401, 3401, 3399, 3401 and 3399. Every trace was 39877021 bytes and carried exactly 90452 `+@N@` markers somewhere in its text, but only 90450-90452 of them at line START. Pipeline stages share fd 2, so a sibling stage's trace record can land in the middle of a long host line. The classifier at `scripts/fork-profile.sh:137` (`if ($1 !~ /^\++@[0-9]+@$/) next`) reads field 1 only, so a spliced record is skipped. Diffing the high reading (r2) against the low one (r4) finds two rows only in r2: `scripts/validate-enforcement-map.sh:7766` `sed` (I82) and `:10105` `tr` (I93); the other 981 rows are common. A reading can therefore fall anywhere from n down to n-k, so the arm's premise that only {n, n-1} occur, and that its exit 3 can never be reached, is false. `--stable`'s repeat-until-equal loop does not fix this; it only shrinks the odds.

Proposed fix, built as WIP `06e4d186` on `b235-load-a2`:
- The classifier reads every marker on a line.
- One reading replaces the repeat loop.
- A2 asserts TRACELINES == MARKERS with a second reader over the same trace, and any gap is FIXTURE BROKEN.
- A new splice self-probe checks both directions, with mutants m7 (field-1 reader) and m13 (widened marker).
Offline over the six saved traces, the new classifier reads 3401 on all six with ntrace == MARKERS == 90452. On an unspliced trace the old and new by-line outputs are byte-identical, which is the control.

*Census of load-red candidates, each with 4e's proposed fix:*
1. `validator-fork-budget` A2: the fix above.
2. `core/fixtures/context-sensor/run.sh:614`: the CONTROL window is seeded at `now - 59` against a 60 s freshness bound, and the comment at `:605-607` already records "two of seven gate runs in one day failed exactly that arm". Proposed: seed it at `now - 30`.
3. `core/fixtures/gate-remediation-deny/run.sh:1416-1419`: arm 3b asserts a hung resolver is abandoned in under 15 s of wall clock. Proposed: the stub sleeps 600 s and the bound becomes 300 s.
4. Short HANG watchdogs: `fold-architect-ledger-join/run.sh:456` (150 polls of 0.1 s, so 15 s), `readset-stage1-verdict` `:582`, `:639` and `:660` (10-30 s), and `readset-skip`'s polls. Proposed: size each one to a hang (120 s), not to the expected time.
5. `advisor-gate-deny` `lib.sh:546`, the rr-late cell: a 3 s append against a 10 s default ceiling. Proposed: give that cell an explicit 60 s ceiling.
6. The suite-pole FAIL in `scripts/validate-suite-pole.sh:947-957` and `:997-1008` compares loaded wall clock against loaded history. Proposed: gate on per-unit CPU-seconds and keep wall clock as information.
7. Backlog receipts `--max-unstable 0` (`.githooks/pre-push:269`): a receipt that flaps under contention fails the push. Proposed: diagnose the flap at its source (read still owed).
8. `readset-sandbox-root-clause` `:136-158`: BROKEN when all 10 `log stream` windows drop notices. The rate under pool load must be measured before any fix.

Not load-reds: the pole SKIPs (exit 0), SKIPPED-on-earlier-red, and the trace-TIMED-OUT WARN. Already fixed at source: `agent-definition-render` and `artifact-section-heading-level`.

Coverage limit: the census was curated, not exhaustive (raw hits A 117, B 113, C 123). Items 4 and 7 still owe reads, and `readset-skip` is only partly read. The release order is lead ai-dlc-9c's to set; 4e proposes A2 first, as its own release.

**Progress (0.804.0; entry stays OPEN).** Shipped: census items 1-4.
- Item 1, A2: one reading, every trace marker classified, A2 asserting TRACELINES == MARKERS.
- Item 2: context-sensor's CONTROL moved to `now - 30`.
- Item 3: gate-remediation-deny 3b is binary. The edit is DENIED, and the 600 s sleeper's recorded pid is dead when the hook returns. Elapsed time is printed, not judged.
- Item 4: the `fold-architect-ledger-join` D6 watchdog and `readset-stage1-verdict` `:582`, `:639` and `:660` were raised to 120 s.

Slot, 2026-10-16, 12:04-12:10 PM EDT at load 3.6-4.6:
- validator-fork-budget, solo: 3401 forks, TRACELINES == MARKERS == 90452, 14/14 mutants killed.
- gate-remediation-deny and readset-stage1-verdict through `hermetic-run.sh`: rc 0, `required_missing=0`.
- context-sensor (164 passed) and fold-architect-ledger-join (72 ok), run from the repo root as the hook runs them; neither declares inputs.

Still owed, in the order lead ai-dlc-9c set:
- (6) the suite pole gated on per-unit CPU-seconds;
- (7) the backlog-receipt flap, diagnosed at its source;
- (5) the advisor-gate ceiling, now BL-630;
- (8) the `readset-sandbox-root-clause` all-lossy rate, measured at pool load;
- item 4's unread `readset-skip` polls: `:981`, `:985`, `:1305`, `:1307`, `:1316`, `:1369`, `:1386`, `:1395`, `:1453-1458`, `:1680` and `:4104`;
- every time or numeric threshold in an assertion, each converted to a binary attribute or justified by a named, measured property (operator: "really need to stop forcing arbitrary goals that aren't based on binary attributes"). This release's 120 s watchdogs are harness safety nets for a hang, not verdicts, and are on that list too (BL-632).

Each fixed unit still owes its solo-against-pool receipt, with a load-free control.

verify: manual

## BL-617 — `validate-layer-entries.sh` W10 tells the operator "The next pull creates it" when it fires on the pull that creates it

**DEFECT.** Found by ai-dlc-60's BL-612 shipped-text sweep (opus, read-only); intake re-derived it read-only at origin/main `f4ca6764`. W10 at `core/scripts/validate-layer-entries.sh:1329` warns: "$MACHINERY_REL: the ai-dlc machinery inventory has not been scaffolded, so this project has not declared which of its scripts are ai-dlc machinery. The next pull creates it from core's template; until then nothing states the inventory and nothing can check it. …"

The consumer pre-push runs this validator (`core/git-hooks/pre-push:77-79`). On the delivering pull, step 2 writes the new machinery declaration (`core/skills/ai-dlc-update/reconcile/setup-sites.md:280`, `machinery:`), so W10 can fire on that pull's own step-2 push. Step 7 of the same pull then creates the file: `core/skills/ai-dlc-update/reconcile/apply.sh:2145` (`elif [ ! -f "$CONSUMER/$MC_REL" ]`) copies `core/skills/ai-dlc/templates/<name>` into place and reports `RESOLVED machinery-scaffold` (`:2151`). So "the next pull" is wrong in that case, where "this pull's step 7" is right. It stays right only when W10 fires between pulls. This is BL-612's delivery-phase error appearing in a user-facing message, and it is filed apart from BL-612 because it changes another subsystem's output. The open backlog does not mention W10 (0 matches).

Owed: W10 says which case it is in, or words its timing so that it holds in both. Receipt: drive the validator in a scaffold-absent tree on both a mid-pull push and a between-pulls push, and read the message in each.

verify: manual

## BL-618 — implementation.md tells the first cross QA its beat state directory goes "outside the shard directory", which no longer says where it lands

**NOTE.** Found by ai-dlc-ad during 0.802.0, relayed by lead ai-dlc-9c; intake re-derived it read-only at origin/main `f4ca6764`. `core/skills/ai-dlc/steps/implementation.md:449` gives the first cross QA "a beat state directory of its own, outside the shard directory and never the lead's", used at `:456` as `AI_DLC_STATE_DIR=<that directory> wait-for-deliverable.sh --complete …`. Since BL-576 (0.802.0), `wait-for-deliverable.sh:502-504` resolves `AI_DLC_STATE_DIR` as absolute when it starts with `/`, and otherwise relative to the project root `WD_ROOT` (`:242`: "relative = under the project root"), not to the cwd. "Outside the shard directory" does not say which. A relative name now lands under the project root wherever the QA runs, so the wording no longer tells the QA what it gets. The open backlog does not cover it: the only other "outside the shard directory" match is BL-554's `.draft` entry.

Owed: the step says "an absolute path, or a path relative to the project root", matching `:242`. Receipt: the rendered step names both forms. Control: the `--since` instruction at `:456-458` is unchanged.

verify: manual

## BL-619 — `ai-dlc-continue.sh` ignores `AI_DLC_STATE_DIR`, so the stop hook cannot see a beat whose state dir was set

**DEFECT.** Found by ai-dlc-ad during 0.802.0, relayed by lead ai-dlc-9c; intake re-derived it read-only at origin/main `f4ca6764`. The defect predates 0.802.0. The stop hook hardcodes the marker at `core/hooks/ai-dlc-continue.sh:113` and `:120`: `LOG_DIR="${PROJECT_DIR}/_bmad-output"`, then `BEAT_MARKER="${LOG_DIR}/.beat-inflight"`. Check 2b reads it at `:152-153`. Its own comment at `:118-119` claims the "same dir and default as the script's AI_DLC_STATE_DIR (_bmad-output)", but the script writes the marker to `BEAT_MARKER="${STATE_DIR}/.beat-inflight"` (`core/scripts/wait-for-deliverable.sh:1050`), where `STATE_DIR` honours `AI_DLC_STATE_DIR` (`:502-504`). `ai-dlc-continue.sh` mentions `AI_DLC_STATE_DIR` once, in that comment (control: `PROJECT_DIR` 14). Sibling hooks do read it, for example `core/hooks/ai-dlc-dispatch-guard.sh:546`: `SPAWN_STATE_DIR="${PROJECT_DIR}/${AI_DLC_STATE_DIR:-_bmad-output}"`.

So any beat run with `AI_DLC_STATE_DIR` set writes its liveness marker where Check 2b never looks, and `implementation.md:456` prescribes exactly that for the first cross QA. This is BL-576's failure (the stop hook cannot see the beat) reached through a different door. A hook's environment can also differ from the beat's, so the fix has to say which value of `AI_DLC_STATE_DIR` the hook can actually observe.

Owed: Check 2b finds the marker wherever `wait-for-deliverable.sh` wrote it, resolved the same way (`:502-504`). Receipt: drive the hook against a live beat started with a non-default `AI_DLC_STATE_DIR`, and show Check 2b sees it. Control: the default-dir beat is still seen.

verify: manual

## BL-630 — advisor-gate's re-read ceiling is a hardcoded 10 s of wall clock, so a correct advisor line that lands late on a loaded box is denied, in consumers as well as the fixture

**DEFECT.** Filed by ai-dlc-4e [9b62de] under the operator's load directive (BL-616), assigned by lead ai-dlc-9c; intake re-derived it read-only at origin/main `f4ca6764`.
- `core/hooks/ai-dlc-advisor-gate.sh:579` sets the ceiling: `case "${ADVISOR_GATE_REREADS:-2}" in 0) _cap=0 ;; 1) _cap=2 ;; *) _cap=10 ;; esac`.
- `:581` loops `while [ "$V" != allow ] && [ "${SEEN:-0}" != 1 ] && [ $((SECONDS - _t0)) -lt "$_cap" ]`, re-scanning every 0.25 s until the incoming call's own line is seen or 10 s pass.
- The only knob is stricter-only (`:17`, `:157`), so neither a fixture nor a consumer can widen it.
- The hook's own comment (`:577-578`) says a scan's cost "grows with the transcript and the load" (0.35 s solo on a 4432-line graph prefix; 4.73 s for 2 re-reads on graph's 815-line deny). Under load, fewer re-reads fit in the 10 s, and the transcript write being waited for lands later too.
- The hook ships to consumers: `templates/` registers it (1 file).

The fixture that carries it is `core/fixtures/advisor-gate-deny/lib.sh:547-549`, cell `rr-late`: it appends 3 s after the hook starts (`APPEND_DELAY=3`) and expects SILENT against the 10 s ceiling. This is BL-616's census item 5. It was moved here because a fixture-side change would hide a property of the hook.

Rejected starting points:
- (a) A re-read COUNT (for example 40 × 0.25 s) instead of `SECONDS`. It is not load-free on its own: per-scan cost grows with load, so the hook's worst-case stall grows with load without bound, and the wait still races the harness's transcript write instead of observing it.
- (b) A fixture-only change, where the appender waits for the hook to start. The hook emits no start signal, so this needs a hook edit anyway, and it would turn the fixture green while consumers keep the wall-clock ceiling.

Owed: a ceiling that does not deny a correct advisor line because of load, with a bounded worst-case stall. Receipt: per BL-616, `rr-late` and `rr-none` give the same verdict solo and under the gate's pool, with a load-free control.

Owner: ai-dlc-4e [9b62de] (lead ai-dlc-9c), the fourth release of its load series, after the CPU-seconds pole and the receipt flap.

verify: manual

## BL-631 — shipped mechanisms read past sprints' artifacts, so a pull or gate can fail, or owe work, because of a historical artifact

**DEFECT.** Operator ruling, relayed by lead ai-dlc-9c: "I'm stating that I don't care if a fixture or check fails against a historical sprint artifact." Earlier: "if someone deleted all of graph consumer's sprint history, it should not matter whatsoever" and "it's a nice to have, not a need." The candidates come from a read-only Sonnet census; intake checked each cite at origin/main `f4ca6764`. The open backlog has no entry on it (0 matches for "historical sprint" or "past sprint").

Readers that take in past sprints, each confirmed at the cited lines:
1. `core/skills/ai-dlc-update/reconcile/apply.sh:1350-1407`, `vd_join`: lists every `*.md` under the consumer's `_bmad-output/` (`find "$4" -type f -name '*.md'`) and turns the result into the pull's `WORKLIST artifact-derivations` / `artifact-derivations-unreadable` / `-unchecked` rows. A past sprint's artifact can drive the pull's row.
2. `core/scripts/validate-artifact-derivations.sh:800-806`: given a directory, it walks every `*.md` under it.
3. `core/skills/ai-dlc-update/reconcile/derivation-differential.sh`: its NEWLY-FAILING set (`:30`, "THIS PULL'S WORK"; exit 1 at `:41`) is taken over `_bmad-output/**/*.md` (`:9`), the same corpus.
4. `core/skills/ai-dlc-update/reconcile/ledger-reverify.sh:2287-2291` and `:2524-2525`: reads `push-candidate-ledger.archive.md` into `ARCHIVE_LABELS` (via `corpus_labels`) and into the sibling entries.
5. `core/scripts/validate-mandatory-rules.sh:574-581` and `:689-692`: Check 6 counts story files under every `stories/` directory in the area, and the FAIL at `:689` reports that count. Whether a past sprint's story can change the verdict, and not only the message, is for the owner to read at `:683-692`.
6. `core/hooks/ai-dlc-gate-remediation-guard.sh:1315`: globs `planning-artifacts/s*/gate-*repair*.md` across every sprint, though `:1317` keeps only a record carrying the live nonce, so a historical record is used only if it carries that nonce.
7. `core/scripts/validate-artifact-budget.sh:1376-1379`: with no canonical live log, it falls back to `find … -name gate-log.md | head -1`, which can return an archived sprint's log. The order of `find` is unspecified, so which log it gets is not stable either.

OPEN QUESTIONS, not filed as defects. Each needs SOME prior state, so the question is whether that state comes from a history read or from a current-state record:
- `core/scripts/sprint-status.sh:296-381`, `max_frozen` / `frozen_sprints`: derives the current sprint number from the frozen archives, in both spellings.
- I81 SPRINT_PENDING, `core/hooks/ai-dlc-continue.sh:1146-1152` and `core/hooks/ai-dlc-acknowledge.sh:416-421`: tests for `s(N-1)/` and for any later `s*/`.
- `core/scripts/validate-trunk-audit-gate.sh`: takes its genesis from the prior sprint's `audit-anchors.md` entry when there is no watermark (`:73`).

Owed: scope each reader in items 1-7 to the current sprint (or to the current pull's own range), so a failing or absent historical artifact can neither block nor owe anything. No prose rule. Answer each open question with a reason. Receipt per reader: the verdict is the same with every past sprint's artifacts deleted and with a deliberately failing artifact seeded into a past sprint. Control: the same failing artifact in the CURRENT sprint still fails.

verify: manual

## BL-632 — shipped checks and fixtures pass or fail on an arbitrary number instead of a binary property of their subject

**DEFECT.** Operator, relayed by lead ai-dlc-9c: "really need to stop forcing arbitrary goals that aren't based on binary attributes." Part of ai-dlc-4e [9b62de]'s load series (BL-616). Subject: assertions whose verdict turns on a number with no stated property behind it, such as wall-clock bounds (`$((SECONDS - t0)) -lt N`, timeouts that fail as HANG or FAIL), percentage windows, and repeat or rep counts. Under load such a bound turns a correct subject red, which is BL-616's consequence, and when tuned to pass it asserts nothing about the subject.

Instances known today:
1. `H4` in `adversarial-shard-merge`, on ai-dlc-c9's local branches `b235-ra-g3` and `b235-ra-scratch`: `core/fixtures/adversarial-shard-merge/lib.sh:1139`, `[ "$((SECONDS - t0))" -lt 8 ] && [ "$RC" -eq 2 ] …`, which `run.sh` names "within 8s". It is a timing proxy standing in for "never read stdin". BEING FIXED, NOT OWED: c9's release replaces it with a poison-token file, which is this entry's remedy shape.
2. 0.804.0's 120 s HANG watchdogs (`b235-load-a2`): `fold-architect-ledger-join` D6 raised from 15 s to 120 s, and `readset-stage1-verdict` `:582`, `:639` and `:660` raised to 120 s. That release raises the number; it does not remove it.
3. The advisor-gate 10 s re-read ceiling, BL-630 (`core/hooks/ai-dlc-advisor-gate.sh:579`).
4. The suite-pole wall-clock growth arm, `scripts/validate-suite-pole.sh:947-957` at origin/main `21facb0f`: a run FAILS past `A_MAX + A_MAX * REGIME_BAND / 100`, with `REGIME_BAND=100` at `:248`. Its own header calls that band "uncalibrated" (`:945`).

Owed, per instance: convert it to a binary attribute (did X happen: a poison token read, a sentinel written, a line seen), or name the property the number stands for and justify the number from a measurement of that property. A census of the remaining instances goes with item 1 of BL-616's census.

NOT IN SCOPE, listed for the OPERATOR to decide, not for the owner: budgets the operator set or approved. `FORK_BUDGET=3405` (`scripts/validate-enforcement-map.sh`), the A6 durable-channel ceiling (`DURABLE_MAX`, 69120 on main, 69376 on intake-7, `scripts/validate-claude-rules.sh`), and the backlog size cap (`MAX=104`, `scripts/validate-backlog-size.sh:129`, which `:72` records the operator raised).

Owner: ai-dlc-4e [9b62de] (lead ai-dlc-9c).

**Census (ai-dlc-4e [9b62de], at lead ai-dlc-9c's request; a haiku grep census at origin/main `8f1a9074`, classified by 4e, with the cited lines read in context except the untriaged ones; intake spot-checked every cited line at `8f1a9074`).**

*OWED: fixture assertions judged on elapsed time.*
- `core/fixtures/wait-stale-deliverable/run.sh:362` (`ELAPSED -ge 2`), `:400` (`-le 1`), `:462` (`-le 10`), `:479` (`-ge 6`), and `receipt.sh:113` (`-le 2`). Each asserts whether a beat slept, a property a sentinel could carry instead.
- `core/fixtures/spec-join-integrity/run.sh:495`, `run_bounded`, called with 5 at `:1388` and `:1406`. Its HANG mutant is killed at the 5 s bound, so the bound itself is the discriminator.
- The 0.804.0 120 s nets (item 2) stay for now. Lead's ruling: the hang question is its own release with BL-630, and it starts from what "hung" means as a yes/no property. Measured by 4e: no per-unit ceiling exists in the pre-push pool or in `hermetic-run.sh`, and the hook's 3x/600 s ceiling bounds only the detached read-set trace.
- About 25 untriaged lines: the `sleep 1; t=$((t + 1))` tick loops in five `*-mutants` fixtures (`adversarial-shard-merge`, `apply-self-overwrite`, `remediator-shard-join`, `review-shard-merge` and `self-update-fixture-log`; intake confirmed the five, against 20 files containing `sleep 1`), `core/scripts/derive-fixture-readsets.sh:1088`, `:1510` and `:1568`, and `readset-skip` `:1307`, `:1316`, `:1369`, `:1386`, `:1453`, `:1457`, `:1458` and `:4104`.

*SEPARATE CLASS: product code with a time ceiling, which ships to consumers.*
- `core/scripts/wait-for-deliverable.sh`: `IDLE_SECS` at `:938`, `SETTLE` at `:1003`, `BUDGET` at `:1138` and `DEADLINE` at `:1434`.
- `core/hooks/ai-dlc-recover-gate.sh:201`: a 10 s `SECONDS` re-read loop, the same shape as BL-630.
- `core/hooks/ai-dlc-continue.sh:363`: `RAPID_WINDOW_SECONDS`.

*CLOSES with 4e's pole release now in preparation:* instance 4, `REGIME_BAND`. That release deletes `scripts/validate-suite-pole.sh` and makes the pole information-only. The file is still present at `8f1a9074`.

verify: manual

## BL-634 — `enforcement-map.yaml` is not valid YAML: `yaml.safe_load` fails on an unquoted `: ` in a prose value

**NOTE.** Reported by lead ai-dlc-9c; intake reproduced it at origin/main `21facb0f`. PyYAML 6.0.3 `yaml.safe_load` on `core/skills/ai-dlc/enforcement-map.yaml` (1425 lines) raises "mapping values are not allowed here" at line 129, column 66. The offending line is `posture: FAILS the gate (exit 0 required; exit 0 with `OK: EXAMINED NOTHING` — printed`, where the unquoted `: ` inside the prose value starts a second mapping. (9c's reading said line 128; PyYAML reports 129, and line 128 is `- site: gate-validation.md Check 2`.) Control in the same run: a small valid file parses.

Nothing breaks today. No tracked file imports PyYAML (0 matches for `import yaml` in any form across the tree, which has 89 `.py` files; control: `import json` in 75 files and `import sys` in 33). The only two `yaml.safe_load` mentions are prose, in `CHANGELOG.md:33885` and `docs/reviews/`. The repo's readers parse the map with awk and grep (fixtures such as `enforcement-map-sites` and `enforcement-map-derivations`). But the file carries a `.yaml` name and ships: `scripts/install.sh` mentions it 4 times and `core-manifest.md` 6. So any standard YAML tool a consumer points at it fails.

The same failure class was fixed once before for a different writer: 0.237.1's `yaml_scalar()` (`CHANGELOG.md:33885` onward) quotes any value carrying `: `, after a regex reader returned PASS over a file `yaml.safe_load` rejected.

Owed: the map parses under a standard YAML loader (quote the offending values, or rename the file to stop claiming YAML), and a check that keeps it so. Measure the check's false-positive set before shipping it, and note that no PyYAML is assumed on a consumer box. Receipt: `yaml.safe_load` succeeds on the shipped map, and a seeded unquoted `: ` in a prose value makes the check fail.

verify: manual

## BL-635 — the read-set map still carries traced rows for 184 fixtures that are keyed on `inputs.decl`, so about 12 thousand rows are dead records

**DEFECT.** Measured by ai-dlc-c9 and relayed by lead ai-dlc-9c; intake re-derived it read-only at origin/main `8f1a9074`. The hook keys a fixture that carries `inputs.decl` on that declaration alone. `.githooks/pre-push:866-871` reads "A fixture carrying `inputs.decl` has no committed rows and needs none: its declaration is its read set", and it adds the fixture to `.mapped.all` before the read-set map is consulted. Yet `.ai-dlc-fixture-readsets.tsv` still holds traced rows for most declared fixtures:
- 248 fixtures carry `inputs.decl`, and 225 fixtures have rows in the map (13765 rows in all).
- 184 fixtures are both declared and mapped, and together they hold 12214 rows. No reader consults these rows.
- Control: 41 undeclared fixtures hold the remaining 1551 rows, which are live.
- c9's figures (249, 185 and 12260) were taken on another ref. The shape is the same.

The dead rows inflate the map that the deriver regenerates whole, and a reader added later could trust them. The precedent fix is c9's `42d9578d` ("drop fold-architect-ledger-join's 46 traced rows now that it is keyed on inputs.decl"). It regenerated the map through the deriver's own `readset_merge_map` (`core/scripts/derive-fixture-readsets.sh:377`, called at `:1360`): fold went from 46 rows to 0, every other row stayed byte-identical, and the undeclared control kept its rows. On main, `fold-architect-ledger-join` still has its 46 rows and is not declared, so that commit has not landed here.

Owed:
1. Regenerate the map through `readset_merge_map`, so declared fixtures carry 0 rows. Every undeclared fixture's rows stay byte-identical (control).
2. A guard so that a declared fixture cannot regain rows, either in the deriver at write time or as an arm at pre-push. Measure its false-positive set before shipping it.
Receipt: after the regeneration the guard reports 0, and a seeded row for a declared fixture makes it fail.

verify: manual

## BL-589 — `wait-stale-deliverable`'s lease-noclobber window is a fixed wall-clock quantum raced against a load-dependent sweep, so under load it fails a consumer's push gate

**DEFECT.** Filed by peer session ai-dlc-68 (listed as ai-dlc-4e [e15800]); intake re-derived it read-only on graph and at origin/main `c07dc9d1`. Graph's 0.800.0 → 0.803.0 reconcile push (session `89a3adec`, started 12:49 PM EDT) ran graph's full pre-push. At about 1:20 PM the hook blocked the push on this one fixture. Graph's `.git/ai-dlc-fixture-failures` (17:20:18Z) reads "pool width 12, 1 of 118 units red" and "wait-stale-deliverable: 4 assertion(s) FAILED". The four are:
- `:104` "lease-noclobber: delivered 30 of 30, A alive=0 — the window under test never ran".
- `:106` "the marker read '1792170599 25473' mid-beat against A's '1792170591 25473' — a second beat clobbered a live lease".
- `:107` "marker '' after the instant beat, expected A's '1792170591 25473'".
- `:109` "MUTANT lease-always-put: delivered 30 of 30, A alive=0 — the window under test never ran".
The session then ran the fixture twice standalone, and both passed. Graph's copy (`tests/fixtures/wait-stale-deliverable/run.sh`) is byte-identical to origin/main's (md5 `f7e19c11d2015cf16b4f941627446ba5` on both). The filer reports load averages of 55-58 during the suite and about 4 for the reruns; intake found no load figure in the transcript, so those numbers are the filer's.

Mechanism, at `core/fixtures/wait-stale-deliverable/run.sh:1160-1206` on origin/main:
- `run_noclobber` starts beat A with quantum 10 and POLL 8 (`:1172`).
- It waits until A is asleep, sleeps 0.5 s, runs a `--status` call, and only then starts the second beat over 30 delivered targets (`:1182`).
- It samples until that beat exits, and `noclobber_preconditions` (`:1204`) requires A still alive at the end.
A's life is fixed at about 10 s, but the setup and the 30-target sweep scale with load. Under a loaded pool A exits first, and the control fails closed: correctly, not green. It still fails the whole gate, though, and the subject is innocent.

The `:106` "clobbered a live lease" line is itself an artefact of the same race. Both markers carry A's own pid 25473 and differ only by epoch, so that is A's own re-stamp landing inside a window that ran late, which `:1166` says the quantum is chosen to prevent. The line accuses the subject of a clobber that A made itself.

Cost: one consumer pull push, about 31 minutes of graph's suite, re-run in full on each red.

Owed:
1. Make A's window outlast the probe by construction, not by a fixed quantum. Candidates: A's life ends on a sentinel the probe writes after its last sample; or A gets a quantum far above any sweep, since `reap_tree "$pa"` at `:1199` kills A anyway, so the passing path pays nothing. Check either against `:1166`, which requires A's own re-stamp to stay outside the window.
2. Receipt: force the slow sweep (for example, a delay injected into the second beat) and assert the control still holds. A pass at low load proves nothing here.

Related: BL-616 (load-sensitive verdicts) and BL-632 (its census lists other elapsed-time asserts in this fixture, `:362`, `:400`, `:462` and `:479`).

Owner: ai-dlc-4e [9b62de] (lead ai-dlc-9c), in its load series with BL-616 and BL-632.

verify: manual

## BL-620 — the LC-A1 layer adjudication accepts a verdict with no evidence the entry was read, so nine re-reads were closed by one keyword grep

**DEFECT** (doubtful, so DEFECT under the operator's standing rule). Filed by ai-dlc-68 (listed as ai-dlc-4e [e15800]); intake re-derived it read-only from graph's session `1b4ba596` and its register record. Graph's 0.803.0 → 0.805.0 pull (2:15-2:22 PM EDT) had 9 `HARD-LAYER-ADJUDICATION-MISSING` rows. Between 18:15Z and 18:21Z the session made **0 `Read` calls in total** (41 Bash calls), and its checks of the nine extensions were keyword greps. The last one, at 18:20:30Z, was `grep -n -i -E 'Rule ?(1|3|4|5|6|9)\b|pause point|phase transiti…'`. One `sed -n '535,550p'` read a single override span. At 18:20:45Z it asked the operator "Can I record 'still-additive' for all nine LC-E4 extension re-reads?", and the operator agreed. `_bmad-output/ai-dlc-update/blocker-adjudication-20261016T181629Z.md:13-25` records the nine rows (entry, core file, sha, verdict) and, under "Verification:", a `grep -n -i -E '\bRule [1569]\b|variant' <nine entries>`.

The contract is `core/skills/ai-dlc-update/SKILL.md:1986`: "Read the entry against the new core text and record a verdict per entry". This pull retired Rule 1 and folded Rules 5, 6 and 9, which are prose rules. A rule-NUMBER grep cannot find an extension that restates a rule's CONTENT without citing its number. For contrast, the 0.800.0 → 0.803.0 session `89a3adec` read each entry against the diff and found that Check 925 contradicted core, which the operator then retired.

The verdicts look right this time. The filer searched for 9 retired-rule phrases across every extension and found none (control token 0). The defect is that nothing would have caught a wrong verdict. A register row is entry, core file, sha and verdict, with no field tying the verdict to a read of the entry, and the open backlog does not cover this (0 matches for `HARD-LAYER-ADJUDICATION-MISSING`). The clearing path is derived, traced by the filer on graph's installed 0.803.0 copies and re-checked at origin/main. `core/skills/ai-dlc-update/reconcile/layer-drift.sh:766-768` reads "every row whose status is such a clause's code must have a verdict recorded in the consumer's register under the subject digest it fired on, or the pull blocks". The key is (clause, `subject_digest`) plus a verdict, and nothing else is consulted. `core/schemas/layer-adjudication-register.json` requires `clause`, `entry`, `subject_digest`, `verdict`, `recorded_utc` and `reason`, and its optional fields are `supersedes`, `owed`, `closes_owed` and `withdraws`. No field carries read evidence. `reason` is free text, and these nine rows satisfy it with the grep sentence. So a schema-valid row whose digest is copied from `--list-adjudications` clears LC-A1, whatever its `reason` says.

Owed: put the evidence in the row, for example a required `read:` field naming the entry's sha or line span compared against the core hunks. Or have the re-read emit a per-entry diff excerpt that the operator question must quote. Receipt: a row with a verdict and no read evidence keeps LC-A1 HARD, and a row with valid read evidence clears it (control).

verify: manual

## BL-621 — the update skill's "re-approve the re-rendered report before apply.sh" has no mechanism, and a session took a pre-authorised merge approval as that re-approval

**DEFECT** (doubtful, so DEFECT under the operator's standing rule). Filed by ai-dlc-68 (listed as ai-dlc-4e [e15800]); intake re-derived it read-only from graph's session `1b4ba596` and at origin/main. In graph's 0.803.0 → 0.805.0 apply, after the nine LC-A1 rows of BL-620 were recorded, the session re-rendered the report region.
- At 18:25:57Z the operator typed "merge is approved when ready" mid-turn. The transcript shows it queued, then removed with `reason: absorbed_mid_turn` at 18:26:02Z.
- At 18:26:13Z the session wrote: "Noted that you've approved the PR merge for when it's ready; I'll apply that at step 8. The re-rendered report's only change is that the nine HARD rows were removed, which is the outcome you already approved, so I'm taking your merge approval as re-approval…"
- At 18:31:51Z it ran `apply.sh --carried-machinery-slice`. No AskUserQuestion fell between the re-render and the apply.

The contract is `core/skills/ai-dlc-update/SKILL.md:1739-1745`: re-render the region, "run `--verify` to exit 0, have the operator re-approve it, and only then run `apply.sh`. … The re-approval is not a formality: a resolution can leave rows the first approval never saw". The operator's words approved the step-8 PR merge, not the re-rendered report.

Consequence this time: likely nil. At 18:25:57Z, before applying, the session found "The only change in the re-rendered region is that the nine HARD rows are gone; nothing new appeared." The defect is that the gate is prose only. `emit-report.sh --verify` checks that the region is current: exit 0, or 3 for the safe-direction "BLOCKERS-RESOLVED" case (`:59-62`, whose own remedy is "a re-render and re-approval"). `apply.sh` reads `--verify` (19 mentions), but its 8 mentions of re-approval are all remedy text in refusal messages (`:217`, `:222`, `:310`, `:323-327`). Nothing records or checks an operator re-approval (0 mentions of an operator-answers record), so any operator message can be read as one.

Owed, one of:
- (a) Mechanise the re-approval. For example, `apply.sh` refuses unless the operator-answers history holds a hook-written answer, timestamped after the region's render, to a question that quotes the region's digest.
- (b) If the batch judges re-approval valueless when a re-render only REMOVES HARD rows (exit-3 territory), remove that case from the prose, under the ruling that a step with no measured value goes. Re-approval stays for a re-render that adds rows.
Either way the prose and the mechanism must agree. Receipt for (a): `apply.sh` refuses after a re-render with no recorded re-approval, and proceeds with one (control). Receipt for (b): the prose names exactly the case the mechanism waives.

Related: BL-620 (the same session's unread adjudications).

verify: manual

## BL-636 — a release's CHANGELOG insertion can REPLACE the previous release's heading, and no gate catches it

**DEFECT.** Measured by lead ai-dlc-71; intake re-derived it read-only. 0.806.0 (`581ca289`, now origin/main) replaced the line `## [0.805.0] - 2026-10-16` with `## [0.806.0] - 2026-10-16` instead of inserting above it. The `## [` heading count is 893 at both its parent `c07dc9d1` and `581ca289`, and the `[0.805.0]` heading count went from 1 to 0, so a count-based check sees no change. `scripts/validate-release-version.sh` passed: its arm B (`:515-520`) checks only that VERSION and the CHANGELOG's TOP heading name the same release (`:3`), and arm C (`:293`) counts headings added over a range, which a one-for-one replacement nets to one. The heading is restored by `ed0fa33d` ("docs: restore the [0.805.0] CHANGELOG heading that 0.806.0's entry dropped", 1 insertion, riding ai-dlc-08's docs push).

Owed: `validate-release-version.sh` asserts that every release heading present at the merge base survives at the tip. Receipt: a seeded tip that replaces the previous heading fails the arm, and a normal insertion above it passes (control). The 0.806.0 shape (`c07dc9d1` → `581ca289`) is the discriminating input.

verify: manual

## BL-637 — `validate-release-version.sh` arm C cannot tell a restored historical heading from a second release

**NOTE.** Measured by lead ai-dlc-71. Arm C counts release headings added over a range (`scripts/validate-release-version.sh:293`, "this range adds N release headings to CHANGELOG.md"). ai-dlc-c8's 0.807.0, carrying `ed0fa33d`, failed with `this range adds 2 release headings to CHANGELOG.md: 0.805.0 0.807.0`: the restored `[0.805.0]` reads as a second new release. If BL-636 adds a "base headings survive" arm, arm C could exempt headings present before the range's own parent. The builder judges that.

verify: manual

## BL-638 — `ai-dlc-subagent-probe.sh` takes `peak_tokens` as the max of the top-level `message.usage`, so any advisor turn inside a subagent inflates the recorded peak

**DEFECT.** Found by ai-dlc-08 and relayed by lead ai-dlc-71; intake verified it by reading the code and measured it on real transcripts. It is BL-622's class with a separate reader. `core/hooks/ai-dlc-subagent-probe.sh:219-224` (origin/main) computes `peak` as the max, over a subagent's assistant turns, of the top-level `.message.usage` input + cache_creation + cache_read. The file never mentions `iterations` (0; control: `cache_read_input_tokens` 1). On an advisor turn that top level sums every API iteration (BL-622), so the turn reads roughly double the real context, and a max takes it. The result is written as `peak_tokens`, which the hook's own header (`:42-63`) says to read against the compaction threshold ("did a teammate approach the ceiling").

Measured (python over `~/.claude/projects/*/<session>/subagents/agent-*.jsonl`, comparing the probe's peak with the max of each turn's last `message`-type iteration, or the top level where there is none):
- graph: 3240 subagent transcripts, 1254 with an advisor turn, 1244 of those with an inflated peak.
- ai-dlc: 1818 subagent transcripts, 699 with an advisor turn, 692 inflated.
- The largest inflation: `agent-ab12255aca6bb34ba` (ai-dlc session `bbaa3aca`) reads 873695 against a true peak of 441012, with 4 advisor turns. The next four inflate by 384-428 thousand tokens.
- Graph's live probe ledger `_bmad-output/subagent-context.jsonl` holds 7528 rows, 146 of them with `peak_tokens` above 420000, past the effective window. Some or all of those are likely inflated; intake did not join them row-by-row to their transcripts.

So any ceiling or model decision read from `peak_tokens` over-states teammate context wherever an advisor ran. No shipped core reader of `peak_tokens` was found outside the probe itself (0 in the dispatch guard, the precompact and acknowledge hooks, and `steps/gate-validation.md`), so the cost today is in the analysis that reads the ledger, not in a gate.

Owed: when `message.usage.iterations` is present, take each turn's figure from its LAST `type: "message"` iteration, otherwise the top level, and keep the max over turns. Share the extraction with BL-622's sensor fix so the two readers cannot drift. Receipt: a seeded subagent transcript with one advisor turn records the true peak, and a transcript without one records exactly what it records today (control).

verify: manual

## BL-639 — `wait-for-deliverable.sh`'s SETTLE window delivers a correct seat mid-edit when load or a slow local model stretches its write gaps

**DEFECT.** Filed by ai-dlc-4e [9b62de] from BL-632's product-code header pass, on lead ai-dlc-71's ruling that a load-sensitive consumer deadline found there is its own filing. It is a mechanism read from the code, not a measurement; intake confirmed the cites at origin/main `9f8e7691`. `core/scripts/wait-for-deliverable.sh:355` sets `SETTLE="${AI_DLC_WAIT_SETTLE_SECS:-180}"`, and `settled()` (`:713`, test at `:730`, and again at `:1003`) delivers a marked file once its hash has been unchanged for more than SETTLE seconds. The header's own measurement (`:302`) is a series of gaps of 1.6, 5.1, 146.6, 2.4 and 1.4 s on an unloaded harness. A seat that writes its marker and keeps editing can have its gaps stretched past 180 s by pool load or by a slow local model, and the lead then consumes a half-edited deliverable. `say_revised` (`:695`) reports the later edit but cannot undo the delivery. A local-model lead is an operator goal, so this is in its path.

Owed: measure the inter-write gaps of marked-then-edited seats under pool load and under a local model. Then either derive SETTLE from that distribution, or observe completion directly (an explicit completion write) instead of quiet time; under BL-632 the second is the binary attribute. Receipt: a seeded marked file edited at gaps above SETTLE is NOT delivered mid-sequence. Control: the same sequence delivers early under today's SETTLE.

Related: BL-632 (lists SETTLE in its product-code class), BL-616.

verify: manual

## BL-640 — `wait-for-deliverable.sh`'s chained-beat guard fails open under load and serialises two quanta

**NOTE.** Filed by ai-dlc-4e [9b62de], same header pass; a mechanism read, cites confirmed at `9f8e7691`. `:1138` (`[ $(( $(date +%s) - LAST )) -lt "$BUDGET" ]`, setting `MAY_SLEEP=0` at `:1139`) separates a chained call from a fresh one by elapsed time alone, with only `RESERVE` slack (`:1394-1395`, the larger of `MARGIN` and `POLL`). If load delays the chained call past that slack, the beat sleeps a second quantum: the 2x BUDGET serialisation the guard exists to prevent. The cost is wall clock and one beat charged, with no wrong delivery. Owed: decide from the sibling's lease liveness or its recorded end epoch instead of a bare BUDGET. Receipt: `.shell-$PPID` stamped at BUDGET-5s gives `MAY_SLEEP=0`. Control: at BUDGET+1s it sleeps today.

verify: manual

## BL-641 — `ai-dlc-continue.sh`'s RAPID_WINDOW_SECONDS can defeat the stall backoff on the unknown-tool path

**NOTE.** Filed by ai-dlc-4e [9b62de], same header pass; a mechanism read, cites confirmed at `9f8e7691`. `core/hooks/ai-dlc-continue.sh:123` sets `RAPID_WINDOW_SECONDS=30`, and `stall_run()` (`:348`) sets `RUN_TOOL=unknown` (`:357`) when there is no transcript, no jq, or an old two-line state file. On that path the time test alone decides whether a run continues. Load stretches a genuinely stalled session's gaps past 30 s, which resets the counter to 1, so `EFF_MAX` (`:131-134`) is never reached and release falls to the harness cap. Owed: measure how often `RUN_TOOL=unknown` actually occurs; if it is non-zero, decide whether the unknown path should hold the run rather than reset it. Receipt: `stall_run` driven with an unreadable transcript at 31 s spacing reaches `EFF_MAX`, where today it resets to 1 on every block.

verify: manual

## BL-642 — `pregate-self-check.sh` reported clean on two release tips that `validate-enforcement-map.sh` fails, though it runs that validator whole

**DEFECT.** Measured twice by lead ai-dlc-71 in batch 235:
- (a) ai-dlc-c9's 0.806.0 went red at the gate on I77 (`core/fixtures/story-evidence-scaffold/world.sh` tracked 100644; it is 100755 on main now).
- (b) ai-dlc-c2's 0.808.0 tip passed `pregate-self-check` with rc 0, yet `validate-enforcement-map.sh` exits 1 on that tip with 7 FAILs, all from c2's diff: I77, I75 ×2, I54/I54b ×2, I95, and the check-manifest-bypass seed. The same validator at `9f8e7691` exits 0.
Each miss costs a gate cycle.

**Premise corrected at intake** (read at origin/main; nothing run, gate window). The self-check is not missing these arms. Its arm (a) runs the WHOLE validator, `bash scripts/validate-enforcement-map.sh` from the tree root (`scripts/pregate-self-check.sh:84-100`), with no diff scoping, and it fails on any non-zero exit. c2's branch carries the same script (md5 `c80f7dd2` on main and on `b235-bl587`). So a clean rc 0 from the self-check and a red rc 1 from the validator on the same tip cannot both describe the same tree and index. I77 reads modes from the INDEX (`git ls-files -s`, `validate-enforcement-map.sh:1512` and `:1523`), so a run before the last commit or stage, a run with `AI_DLC_PREGATE_ROOT` naming another checkout (`:46-51`), or a run against an earlier commit would each read clean. Which of these happened is not established.

Owed:
1. Reproduce on c2's 0.808.0 tip: run the self-check and the validator in the same checkout at the same commit and compare. If they disagree there, the self-check has a real defect to find. If they agree, the miss was a procedural one: the self-check was not run on the tree that was pushed.
2. Close whichever gap the reproduction shows. For a procedural miss, the self-check should record the commit and index state it judged (HEAD sha and a clean `git status`, refusing on a dirty tree), so "clean" names the tree it was clean for, and the push can be checked against it.
Do NOT add a diff-scoped re-run of the validator, which arm (a) already supersedes. Measure any added cost; this is the validator the suite pole invokes. Receipt: a self-check run on a tree whose index differs from HEAD refuses or names the mismatch, and on c2's tip it reports the 7 FAILs.

verify: manual
