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

## BL-558 — `story-evidence-scaffold` costs 173-177s solo against a recorded pool-12 history of 2-3s, and the cause is not found

**DEFECT (efficiency).** Found at batch 234 while gating 0.790.0. Pushed from a linked worktree, the pre-push runner re-ran the same 10 fixtures every time (the 8 its read-set map leaves unmapped there, plus two), and `story-evidence-scaffold` was the pole of that set at 144s and 146s. The suite-pole guard judged it against its own pool-12 history, 8 rows with a maximum of 3s, and failed two gates on the regime ceiling (6s). Measured solo and interleaved, from detached worktrees of `origin/main` (`bfb5589e`) and the release tip (`1c2bf345`), at load 4-6: base 177s and 175s, tip 173s and 171s. So the cost is not the release. The 2-3s rows are not explained: a grep of `run.sh` (725 lines, one file in the fixture) for reads outside `core/` (`projects`, `graph`, `HOME`, `git log`, `find`) found none, and the fixture's own run log shows a full mutant battery over about 30 handoff and strategy cases. Its 8 pool-12 rows were dropped on the operator's choice with the guard's own printed remedy (backup kept), and the next gate read `CALIBRATING (1/3)` at 143s and passed.

Owed: find what the 2-3s rows measured (a skipped battery, a different dispatch, a different tree) and whether 175s is the fixture's real cost. If it is, the fixture is a candidate for the same sharding the other batteries got, since a 175s unit can become a full-suite pole. Measure solo first, in a clean worktree, and name the tree beside the number.

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

## BL-595 — the Check 22 arm refusing `none (serial-document)` on a `stories/` subject is still unbuilt

**NOTE.** BL-509's close (archived, `docs/backlog.archive.md:32870ff`) built the sharded stories-elicitation rule (`_gate-procedures.md:413-420`, "never `shard: none (…)`", pinned by 8 `elic-shape-*`/`sts-elic-*` rows in `process-rule-pins`) but left Check 22 untightened: "an S3 arm refusing `none (serial-document)` on a `stories/` subject was not built because its false-positive set on graph's ledgers was not measured". `core/scripts/validate-spawn-ledger.sh:920-923` S3 still fails only an exception outside the four, and `:973` reads only the first parenthesised token, so a single serial-document voice over `stories/` passes. The yield evidence that the sharded shape is worth enforcing now exists: `docs/analysis/step-value-s317-s319.md:137` (s317 22 shards about 15 unique; s318 one voice at most 1). Owed: measure the arm's false-positive set on graph's ledgers (it fires on graph's closed s318 stories row, a true finding), then build it or record why not.

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

## BL-600 — the lead hand-rolls file times with `stat -f %Sm -t %FT%TZ`, which prints LOCAL time with a literal `Z`

**DEFECT.** Carried from a BL-528 addendum that missed BL-528's close: b235-docs (4abbd6c3) archived BL-528 as landed in v0.792.0, whose write-time stamp check judges lines ADDED to `pipeline-snapshot.md` (FUTURE, MALFORMED, BACKDATED). That check does not reach a time the lead derives in its own reasoning. Filed by peer session ai-dlc-68 from graph s319 lead `949015a6` (Sonnet 5.5): at 05:10:12Z on 2026-10-16 the lead ran `stat -f '%Sm' -t %FT%TZ <record>`, which prints local time followed by a literal `Z`. The box is EDT; the record's mtime was 2026-10-16T00:59:42 local (04:59:42Z), and the lead wrote "last modified at 00:59Z", four hours wrong and reading as authoritative. Its conclusion held only because 04:59Z preceded the 05:00:03Z dispatch. No shipped script or hook formats a file time this way (`%Sm` 0 hits in `core/scripts` and `core/hooks` at 4abbd6c3; control: `stat -f` 2 hits, both epoch `%m`/`%z:%m`), so the time is the lead's own hand-roll.

Owed: any shipped helper that reports a file time emits it under `TZ=UTC` (or `date -u -r <epoch>`), and the step text that asks the lead whether a record changed since a dispatch names that helper instead of leaving the format to the lead. Probe: the helper's output for a file with a known epoch equals `date -u -r <epoch> +%FT%TZ` under a non-UTC `TZ`, with `TZ=UTC` as the control.

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

## BL-602 — derivation-differential-mutants claims each mutant is killed by EXACTLY its declared arms, but checks only that the declared arms are a SUBSET of the failed ones

**DEFECT.** Filed by peer session ai-dlc-60 while building release U-a; the fix is assigned to ai-dlc-c3. `core/fixtures/derivation-differential-mutants/run.sh` states an equality contract at :6 ("killed by exactly its declared arms"), :7 (exit 1 includes a mutant that "moved an arm it does not own"), :14-15 ("the set of arms that FAIL must EQUAL the set the mutant declares … one that fails an arm it does not own means two arms are entangled") and :231. The check at :127 is `missed="$(comm -13 "$WORK/$label.moved" "$WORK/$label.declared" …)"`, which prints only declared arms that did not fail: declared ⊆ failed. Intake confirmed all five lines at origin/main 3d5f1e70. A mutant that also fails an arm it does not own prints `KILLED`; the extra arms appear only in the "full failed set" text, which nothing asserts. That is the entanglement the header promises to catch and `.claude/rules/fixture-mutants.md` ("A mutant must fail **only** its own assertion") requires. Per the filer, of the 23 fixture `run.sh` files that use `comm -`, only this one carries the `comm -13 "$WORK/$label.moved"` form; other batteries need their own read before generalising.

Measured by ai-dlc-60 on U-a head d524616d (based on e3073787), battery exit 0 in 150 s: 5 of 12 mutants fail a strict SUPERSET of their declared arms, 7 match exactly. R1 adds A16n A18b A18c A1c A1d A2c A3b A3d A9a A9b; R2 adds 35 arms; R3 adds 23; R4 adds A9c; R8 adds A15n. The equality form would therefore turn 5 current kills red. The A18 arms and R11/R12 come from U-a; on origin/main the battery has R1-R10 only.

Owed: decide which side is right. If the header is right and the check too weak (which the rule file argues for), add `comm -23` and fail any mutant whose failed set exceeds its declared set, widening the 5 superset mutants' declared sets each with a reason. If the check is right, rewrite :6-7, :14-15 and :231 to say "at least". Receipt: a seeded mutant whose failed set is {declared} plus one extra arm is refused under the equality form; a mutant whose failed set equals its declared set is still KILLED, as the control.

verify: manual

## BL-603 — derivation-differential.sh's `_good` cache is never written, so its early-break arm can never fire

**DEFECT.** Filed by peer session ai-dlc-c3, measured read-only. In `core/skills/ai-dlc-update/reconcile/derivation-differential.sh` at origin/main 3d5f1e70, :240 initialises `_good=" "` and :243 reads it (`case "$_good" in *" $_b "*) BASE_COMMIT="$_c"; break ;; esac`); intake found `_good` on those two lines only, while `_bad` has 1 append in the same file. Per the filer the same holds at U-a head d524616d (:245, :248). A matching blob is handled by the `resolves_to_base && skill_commit_ok` branch, which sets BASE_COMMIT and breaks, so the `_good` arm is a guard whose removal changes nothing (`mechanism-design.md`, "A vacuous guard is a loaded gun").

Owed: delete the `_good` arm and its init (fix by subtraction), or append `_b` to `_good` in the success branch if a later blob can repeat. Receipt: a mutant removing the arm changes no verdict before the delete. It is in the subject, not in c3's battery release, so it ships in a later release.

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

verify: manual

## BL-612 — "takes effect on the pull AFTER the one that delivers it" is wrong for any change the update skill runs after its step-2 re-invoke

**DEFECT.** Filed by peer session ai-dlc-60, found by the BL-587 contract adversary; intake re-derived it read-only. `core/skills/ai-dlc-update/SKILL.md` step 2 (origin/main, ~:248-256) self-updates the machinery slice (`core/skills/ai-dlc-update/**`, `core/scripts/*`, hooks, schemas) on its own commit-and-merge cycle, then (~:731-740) says "STOP this invocation and re-invoke `/ai-dlc-update` automatically … THIS invocation is still executing the PRE-update logic … do NOT proceed to step 3 on stale logic". So steps 3 onward run the NEW engine and the NEW skill text on the delivering pull, unless the self-update gate returns `SELF-UPDATE-DEFER` (9 mentions in SKILL.md). Only behaviour that executes in steps 1-2 of that invocation really runs the pre-update version.

Measured on graph's 0.791.0 → 0.793.0 pull: `scripts/ai-dlc/validate-artifact-derivations.sh` is blob `deacd13c` at `3dd8a9fd4` (pre-pull), and `e3cdd564` at `41d2dbf91` (#1230, the self-update) and at `897dfdb32` (#1231, the reconcile). In this repo the same file is `deacd13c` at 952b9319 and `e3cdd564` at c16609ba, so the two blobs differ and the new validator was in place at the delivering pull's reconcile.

So these release notes are wrong: 0.793.0's "the reconcile engine runs this validator, so a consumer gets the pin on the pull AFTER", and 0.799.0's "both files are read by the update session, so a consumer gets this on the pull AFTER the one that delivers it". The CHANGELOG has 35 lines matching "pull after" (control: 887 `## [` headings), and the live backlog carries the same claim in BL-563 and BL-582. Each needs classifying:
- step-1/2 behaviour: really takes effect on the next pull.
- anything read or run from step 3 on: live on the delivering pull, after the re-invoke.
BL-582, for example, splits: its step-2 touchpoint is next-pull, and its step-8 touchpoint is live on delivery.

Hooks may be live even earlier, per ai-dlc-60. This is REASONED from the step-2 text and NOT yet measured; ai-dlc-60 is measuring it in U-b's slot. Step 2 writes the new machinery into the working tree before its own commit, push and merge, and Claude Code runs the on-disk hook on every call. A changed hook would therefore already govern the delivering pull's own step-2 merge, while the session still follows the old SKILL.md. That makes a third class beside the two above.

Owed:
1. The delivery-phase rule written once where release authors read it.
2. Correct the reconcile-phase claims, in the CHANGELOG's "Bootstrapping" lines and in BL-563 and BL-582, as a Corrections paragraph in BL-612's own release entry naming each misclassified "pull after" line plus the BL-563 and BL-582 items. That paragraph closes item 2 only. It is prose, so it cannot stand as the receipt for the mechanism; item 3 is that receipt.
3. Receipt: a fixture or derivation that takes a reconcile-engine change, simulates step 2 and then a re-invoke, and shows the new engine running at step 3. A step-1 behaviour change is the control, which must NOT be live. Lead ai-dlc-9c ruled the fixture is the receipt; the CHANGELOG paragraph closes only the documentation item. Whoever builds the fixture checks that its simulated re-invoke matches step 2's real re-invoke mechanism, read from the skill text itself (SKILL.md ~:731-740), not from a summary of it.

Items 2 and 3 ship together as BL-612's own release, after BL-587, and that one release closes the whole entry. Release U-b is built, so per the scope-boundary ruling nothing from this entry joins it; U-b adds only its own (a)/(b)/(c) outcome lines as part of its own verification. The hook-phase class above stays unmeasured until U-b's slot.

Owner: ai-dlc-60 (lead ai-dlc-9c).

verify: manual

## BL-588 — an append-only repair record whose later blocks change a subject leaves the earlier blocks' derivations permanently STALE, and nothing lets a later block supersede them

**DEFECT.** Filed by peer session ai-dlc-68 (listed as ai-dlc-4e [e15800]) from the graph s319 watch; intake re-derived it read-only (the validator itself was not re-run here; the filer re-ran it). At graph's handoff commit `e18724963` (08:21 EDT, lead `cf53b84f`), `_bmad-output/planning-artifacts/s319/requirements-repair-p1.md` (1697 lines) carries three blocks, closed by `repair-complete: serial 1` (:1261), `repair-complete: spec-render 1` (:1477) and `repair-complete: serial 2` (:1696). `scripts/ai-dlc/validate-artifact-derivations.sh` on it reports "FAIL: 9 stale or unrunnable derivation(s) of 105 checked", at lines 30, 536, 581, 646, 780, 793, 1409, 1426 and 1444.

Each later block changed SPEC/PRD/brief text that an earlier block's fence quotes. Line 30's fence greps `SPEC.md` for "What does the Story 1.5 read score for a two-hop row" and records `85:`; at `e18724963` that phrase occurs 0 times in `_bmad-output/specs/s319/offramp-config-and-rewards/SPEC.md` (control `CAP-1`: 4), because the spec-render deleted the Q18 line on the operator's "Retire Q18" (BL-546's fourth instance). Serial 2 was dispatched at 08:13 EDT to fix 5 such fences, and the count went from 5 to 9 after it delivered. The record is append-only, so no block can re-point an earlier fence. `_bmad-output/pipeline-snapshot.md:38` hands this to the successor as pass-2 entry item (1): "decide the 9 stale old fences … never edit or delete an old fence".

The validator has no way out: `core/scripts/validate-artifact-derivations.sh` on origin/main has 0 mentions of `supersede` and 0 of `artifact_sha_after` (control: 22 of `stale`, case-insensitive). The record already writes `supersedes:` lines (3, at :511, :1577 and :1578), but these are finding supersessions, which the validator does not read. The `supersedes:` convention for escalations lives in BL-565's PARTIAL note (`docs/backlog.md:319-325`, shipped in 0.794.0); BL-550 itself is archived.

Owed (either 1 or 2, then 3):
1. Let a later block of an append-only record supersede an earlier block's derivation with a `supersedes: <line>` field the validator honours, re-running the new fence in place of the old one.
2. Or have the validator score a fence against the subject sha its block recorded in `artifact_sha_after:`, not against the current tree.
3. Receipt: on this record at `e18724963`, the 9 lines above go to 0 without editing any old fence, and a fence whose subject drifted with no superseding block still reads STALE (control).

Related: BL-587 (owed re-points with no channel), BL-546 (the Q18 deletion), BL-565 / BL-550 (`supersedes:` for escalations).

Owner: ai-dlc-11 (lead ai-dlc-9c), as its own release after ai-dlc-11's combo release. It touches BL-587's reader.

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

Owed: move the budget to a data file that only `validator-fork-budget` reads, keeping its column-0 single-line anchor (`run.sh:92-101`) and its A4 reachability arm. Receipt: a budget-only change re-keys `validator-fork-budget` and no other unit. Show it with the hook's own key computation on a probe commit, and use a one-character edit to the validator as the control, which must re-key all 20.

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
