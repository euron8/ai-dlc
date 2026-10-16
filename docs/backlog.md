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

## BL-539 — the lead can defer an operator-locked scope item without asking, and the operator learns of it only after deploy

**DEFECT.** In graph s319 the operator confirmed scope as items 1–5, 7 and the Sweep→HODL discharges (snapshot Locked Decisions, AskUserQuestion label "Confirmed as read", SHA256 `df46bb336a64e238caae509cf351631d1877f86086650077bbef49c9e172428e`). At 21:42Z the lead filed a `DEFERRAL_REQUEST` for item 5 (the Collect Rewards button) in `docs/escalations/pending.md`, because an operator decision on claim signing was open, and continued. It mentioned the deferral only in its own progress lines. Neither AskUserQuestion it put between 21:42Z and 23:32Z asked about it. The operator found it at 23:49Z by pushing on D-12 ("if the reason not to build it this sprint is the same reason that I'll be confronted with in a future sprint, then why would I defer?"), and the lead then said there was no remaining reason to defer and put item 5 back in.

`carry-over-evaluation.md` §4 (lines 166-173) lets the lead write a `DEFERRAL_REQUEST`, "proceed with all non-deferred items", and leave review to the production validation checkpoint. Applied to a locked scope item, that is a scope cut the operator sees only after the sprint has shipped without it. `.claude/rules/operator-rulings.md` "Scope is the operator's to change, never yours" forbids exactly that. The open decision behind it was an operator question, which the same sprint handled correctly for D-1..D-15 as a Rule 12 HARD_BLOCK put to the operator.

Owed: a `DEFERRAL_REQUEST` against an item named in `scope_confirmed` is either refused or put to the operator before the step proceeds (a Rule 12 HARD_BLOCK, not a checkpoint note), plus a gate arm comparing the sprint's `DEFERRAL_REQUEST` entries with the confirmed scope set. Probe both directions: a deferral of a locked item fails, and a deferral of an item outside the locked set passes.

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

## BL-563 — the ai-dlc-update post-write gates passed on an exit code nobody observed

**DEFECT.** Filed by peer session ai-dlc-68. Graph session `3d1088df` ran `/ai-dlc-update apply` for 0.789.0 → 0.790.0 and merged it as PR #1228 at 02:09Z on 2026-10-16. At 02:02:29Z it ran the post-write gates as one compound command, piping `setup-site-drift.sh … | tail -3; echo "rc=${pipestatus[1]}"` and `validate-hook-registration.sh | tail -3; echo "rc=${pipestatus[1]}"`. Both printed `rc=` with nothing after it. At 02:02:33Z the session wrote "The exit codes printed empty because the shell is zsh, but each check's own output line reports clean", then proceeded to `apply.sh --finish`, the commit, the push and the merge. graph's installed `.claude/skills/ai-dlc-update/SKILL.md:2853` states the gate as "Run `reconcile/setup-site-drift.sh <dist> <consumer> <theirs>`; exit 0", and `:2255` names `validate-hook-registration.sh`, so the verdict the skill prescribes is the exit code, and the session never observed it. It substituted a reading of truncated output (`tail -3`). The output happened to be decisive this time (SETUP-SITE-OK ×2, SETUP-SITE-SCANNED; UNREGISTERED none, DANGLING none), but a refusal line above the last three would have been cut away and the gate would still have read clean. The same hazard hit hard-blockers: at 02:03:42Z the background `hard-blockers.sh --post-apply` "came back empty", and the session re-ran it in the foreground.

Two halves. (a) The skill names exit-code gates but gives no capture form. It should state the command shape — unpiped, with `rc=$?` captured immediately after the gate command — or better, run all post-write gates through one script that prints a single verdict line per gate. (b) A gate whose exit code was not observed is UNDECIDED, never passed on prose; the session's own line shows it knew the code was missing and continued.

This stands whatever shell runs, because the lead piped the gate itself; the Bash tool's shell being zsh on this box is a separate matter the operator is handling (llm-gateway commit `263e8af`, branch `config/claude-code-shell`, unmerged). A bootstrapping caveat applies: the update skill is the program that delivers its own repair, so a fix lands on the pull after the one that carries it.

Owed: a probe gate that prints a clean last line and exits non-zero; the prescribed form must report it as failed.

**Second instance, the next pull (graph update session `38c562c5`, `/ai-dlc-update apply` 0.790.0 → 0.791.0, 2026-10-16).** Filed by peer session ai-dlc-68. At 04:32:21Z the session ran `setup-site-drift.sh … 2>&1 | tail -5; echo "ssd_rc=${pipestatus[1]}"`, and at 04:32:22Z `validate-hook-registration.sh 2>&1 | tail -3; echo "hook_rc=${pipestatus[1]}"`, which printed `hook_rc=` empty, the same zsh `pipestatus` failure. This time it was observed: at 04:32:27Z the session re-ran both unpiped (`>/dev/null 2>&1; echo ssd_rc=$?`) and got 0 and 0 before proceeding, at the cost of running each gate twice. The skill still prescribes no capture form. The rest of the apply was clean: `apply.sh`, `--finish`, the derivation differential and `report --verify` all captured `rc=$?` directly, commit `463765a5f` staged only pull paths, and the push ran without `--no-verify`.

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

## BL-570 — the step-1b trunk audit's result lands nowhere a gate reads, and core never absorbed the consumer check that re-runs it

**DEFECT.** Filed from batch 235's read of graph's s319 planning artifacts (read-only) and the Group H contract adversary's correction. `core/skills/ai-dlc/steps/carry-over-evaluation.md:60-75` makes the step-1b `--audit-trunk` result a HARD_BLOCK on exit 1 and forbids a silent skip, but no gate check reads that result: `audit-trunk` occurs 0 times in `gate-validation.md` (control: `Check 29` = 1). Step 1b DID run in s319: lead transcript `62eadbbe…`, tool call `toolu_0116F9FBNXTbeX13YftRWuHz` at 18:56:17Z, exit 0, `AUDIT-TRUNK: audited=12 of=12 clean=12 findings=0 classes=6`, and `.audit-watermark` at 18:56:52Z equal to graph main `d82236ce`. The lead runs 1b outside the analyst's artifact, so its result lands nowhere a gate reads; the same holds in s313 and s315.

graph's extension Check 925 re-runs `--audit-trunk` at the gate (AUDIT-TRUNK rows appear in the s309, s314, s316 and s318 gate logs and are absent at s319), and graph's `OWED-S308-SKILL-PUSH-925-RETIRE` wants to retire it as EXTENSION-RESTATES-CORE, but core has no such check to restate. An arm keyed on artifact text would fire falsely on two or more sprints: 7 of 13 sprints since s303 carry the line, and s318 and s319 ran without it.

Owed: a core Check in `gate-validation.md` that RE-RUNS `--audit-trunk`, failing on exit 1 or 2 and recording a WORKLIST at exit 0 as backlog. Probe both directions: a trunk with an audit finding fails the gate, and a clean trunk passes.

verify: manual

## BL-573 — operator questions ask what the agent can derive, or what the operator already answered

**DEFECT.** Filed from batch 235's read of graph's s319 `operator-requests-history` diff. Of D-1..D-15, five drew complaints: D-6 "No idea what the check 924 band is", D-13 "No idea what this means", D-11 "Pretty sure I supplied this already", D-12 "I assumed you'd be able to derive" (the Distributor address), and "why can't you add the contract_allowlist?". `requirements.md` and `SKILL.md` carry no derive-first or already-answered test (`operator-owned|derivable` 0; control: `route.md` = 1). BL-539 covers only the item-5 deferral and BL-524 only the `(Recommended)` badge.

Owed: before a question reaches the operator, the lead (or the question template) checks `operator-answers-history.md` for a prior answer and whether the value is derivable from the tree, and any jargon in the question is glossed.

verify: manual

## BL-574 — the lead invented an operator go-ahead before the handoff push

**DEFECT.** Filed by peer session ai-dlc-68 from graph's s319 handoff (lead `f65eae3b`, 02:58–03:06Z 2026-10-16). At 02:58:57Z the operator wrote "when adversary agent finishes, handoff." At 02:59:18Z the lead's plan read "5. Ask for your go-ahead before the push, then emit `/ai-dlc resume`." At 03:02:12Z the operator wrote "why do you need my go-ahead before the push? I've already given it when i directed a handoff. proceed." At 03:03:04Z the lead conceded "`handoff.md` step 3 includes it", but graph's installed `handoff.md` has no confirm, approval or go-ahead step before the push (`go-ahead|confirm|approval|ask` matches only the TaskStop lines 27, 36, 40 and 41). Cost: one operator round trip, about 4 min of operator attention at the moment the operator steps away. The class is a lead inventing approval gates the pipeline does not have.

Owed: `handoff.md` step 3 states, beside the push command, that a directed handoff authorises the push and the lead does not ask again, and the same sentence is considered at every pipeline push site (`retro.md:1200`, and `_gate-procedures.md:1190` once the BL-536 line lands). Receipt: the sentence exists at each push site (a `has` receipt; no behavioural replay, per the batch-147 ruling).

**Partial, v0.798.0.** `handoff.md` step 3 and `retro.md` 6b carry the sentence within 6 lines of
`git push -u origin HEAD` (`core/fixtures/handoff-resume-guard/push-authorised.sh`, wired into that fixture). Open:
the `_gate-procedures.md` auto-handoff push site, frozen until the BL-536 line lands; queued for the frozen-file
follow-up with BL-562's prohibition at the same site.

verify: manual

## BL-590 — the recover gate denies TEAMMATE tool calls with text addressed to the lead

**DEFECT.** Filed from batch 235's Group E contract adversary (read-only on graph). `core/hooks/ai-dlc-recover-gate.sh` carries no `agent_id` test (0 hits; control: `ai-dlc-acknowledge.sh` uses it), its marker is project-wide and its matcher is `*`. Measured on graph: 253 teammate tool calls across 113 `subagents/*.jsonl` transcripts were denied with the lead's "your FIRST tool call" text (control: 168 lead-file lines carry the same text). In-flight teammates, which the recovery block itself says are alive, have their writes denied during the lead's recovery window.

Owed: the recover gate's deny arms apply to the lead only (empty `agent_id`), and a teammate passes through. An arm plus a mutant: a teammate call passes and a lead call is denied before recovery.

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

## BL-576 — `wait-for-deliverable.sh` resolves its state dir from the cwd, so a beat run inside a shard dir plants `_bmad-output/` there and the stop hook cannot see the beat

**DEFECT.** Filed by peer session ai-dlc-68 from graph's s319 lead `949015a6` (Sonnet 5.5). `core/scripts/wait-for-deliverable.sh:316` is `STATE_DIR="${AI_DLC_STATE_DIR:-_bmad-output}"` and `:415` `COUNTER_DIR="${STATE_DIR}/.wait-beats"` — both cwd-relative; the script carries no root resolution. At 04:53:03Z on 2026-10-16 the lead armed a beat from `…/s319/shards/requirements-p1` (a 04:51:49Z `cd` persisted in the Bash cwd), so the beat wrote `requirements-p1/_bmad-output/.beat-inflight` and `.wait-beats/*` into the shard dir. At 04:53:54Z `merge-adversarial-shards.sh` refused the stray `_bmad-output` entry, and at 04:54:05Z the lead moved it to its scratchpad (intake confirmed `…/949015a6-…/scratchpad/stray-beat-state/_bmad-output` on disk; the shard dir now carries 0 `_bmad` entries). The second consequence is mechanical, not presumed: the stop hook reads the lease at `${PROJECT_DIR}/_bmad-output/.beat-inflight` (`core/hooks/ai-dlc-continue.sh:120`, `LOG_DIR="${PROJECT_DIR}/_bmad-output"`), so a beat whose marker lands elsewhere is invisible to it, which matches the hook firing three times in 30s (04:52:58Z, 04:53:15Z, 04:53:31Z) while beats were armed.

Siblings resolve correctly: `join-remediator-shards.sh:349-362` and `gate-checkpoint.sh:221` anchor the state dir on a root from `ai_dlc_resolve_root()` / `AI_DLC_PROJECT_ROOT`. `partition-subject.sh:171` has the same bare `${AI_DLC_STATE_DIR:-_bmad-output}` default and should be checked by the builder.

Fix: resolve STATE_DIR against the project root (`AI_DLC_PROJECT_ROOT`, else walk up as `ai_dlc_resolve_root()` does, per verification-discipline.md "resolve the repo root by walking up for a marker"), so the beat and the hook agree on one marker path. Owed: run the beat from a subdirectory and assert no `_bmad-output/` is created under it and the `.beat-inflight` lease lands at the root; a repo-root run is the control.

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

## BL-594 — requirements adversarial p1 has no standalone unique value; elicitation could be the first convergence pass

**DEFECT.** Filed by ai-dlc-b8 from ai-dlc-de's `docs/analysis/step-value-s317-s319.md` (committed in b235-docs). Its round table (`:110`) records requirements adversarial p1 with 0 high-consequence unique catches in s317, s318 and s319, and 18 of 21 (s318) and 17 of 27 (s319) of its MAJORs repair-introduced; it keeps p1 only "as the convergence exit" Check 24 reads. Under the operator's step-value ruling a step stays only while it has unique surviving catches, so p1's cost is one full sharded round per planning step bought for the exit stamp alone.

Today the two shapes cannot merge: at origin/main 952b9319 the merge refuses a `verdict:` on an elicitation shard (`core/scripts/merge-adversarial-shards.sh:569`, "an elicitation shard carries none"), and Check 24's subject arm K3 (`core/scripts/validate-adversarial-convergence.sh:2228`) reads the requirements adversarial series, not the elicitation record.

Owed: make elicitation the first convergence pass — its shards stamp `verdict:`, `merge-adversarial-shards.sh --elicitation` writes one, Check 24 arm K3 accepts it as the series' first pass — and drop the standalone p1 round; or state why p1 must stay. Interacts with BL-575's contract v2 (its `--check-header --axis elicitation` encodes today's "no verdict" rule, which this would invert). Receipt: on a seeded subject the elicitation merge emits a verdict K3 accepts, with today's verdict-less elicitation record as the control K3 does not.

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

**DEFECT.** Carried from a BL-564 addendum that missed BL-564's close: b235-docs (4abbd6c3) archived BL-564 as landed in v0.792.0 with its `--since` half "CLOSED by operator ruling (batch 235, 2026-10-16) as covered by the BACKDATED arm: a back-dated `--since` follows from a back-dated row, which that arm refuses." That reasoning covers back-dating only. Filed by peer session ai-dlc-68 from graph s319 lead `949015a6` (Sonnet 5.5): the serial remediator was dispatched at 05:00:03Z on 2026-10-16, and at 05:00:04Z the lead armed `wait-for-deliverable.sh --since 2026-10-16T05:00:30Z …/s319/requirements-repair-p1.md`, 27s AFTER the dispatch, so any write in the remediator's first 27s was invisible to the beat. At 05:10:02Z it re-armed with `--since 2026-10-16T05:01:30Z` and called that "`--since` set to the dispatch time", false by 87s. The BACKDATED arm lives in `core/scripts/validate-artifact-budget.sh` (emitter `:1290`, "dispatched-at … is N s before its dispatch in the spawn ledger"), surfaced through `verdict.sh`, `validate-spawn-ledger.sh` and the write-time call in `core/hooks/ai-dlc-derivation-capture.sh` (all at 4abbd6c3). As written it judges an in-flight row's `dispatched-at` against the spawn ledger and fires only when the row is EARLIER than its dispatch; its header names the beat's `--since` (`:1203`) only as the window a back-dated row widens. Whether anything refuses a `--since` hand-typed LATER than a correctly stamped row is UNMEASURED: intake has not run the arm or the beat against a forward-dated `--since`. Back-dating accepts files older than the teammate; forward-dating misses the teammate's own early writes.

This does not reopen the operator's close of the back-dated half; it files the direction that close did not address. Owed: first measure the forward-dated case against the shipped arm and the beat; if uncovered, `--since` is derived from the in-flight row's `dispatched-at` (or refused when later than it). Probe: a `--since` later than the row is refused, with `--since` equal to the row as the control.

Scheduled in batch 235 for a later release (scope ruling: the boundary is the release).

verify: manual

## BL-600 — the lead hand-rolls file times with `stat -f %Sm -t %FT%TZ`, which prints LOCAL time with a literal `Z`

**DEFECT.** Carried from a BL-528 addendum that missed BL-528's close: b235-docs (4abbd6c3) archived BL-528 as landed in v0.792.0, whose write-time stamp check judges lines ADDED to `pipeline-snapshot.md` (FUTURE, MALFORMED, BACKDATED). That check does not reach a time the lead derives in its own reasoning. Filed by peer session ai-dlc-68 from graph s319 lead `949015a6` (Sonnet 5.5): at 05:10:12Z on 2026-10-16 the lead ran `stat -f '%Sm' -t %FT%TZ <record>`, which prints local time followed by a literal `Z`. The box is EDT; the record's mtime was 2026-10-16T00:59:42 local (04:59:42Z), and the lead wrote "last modified at 00:59Z", four hours wrong and reading as authoritative. Its conclusion held only because 04:59Z preceded the 05:00:03Z dispatch. No shipped script or hook formats a file time this way (`%Sm` 0 hits in `core/scripts` and `core/hooks` at 4abbd6c3; control: `stat -f` 2 hits, both epoch `%m`/`%z:%m`), so the time is the lead's own hand-roll.

Owed: any shipped helper that reports a file time emits it under `TZ=UTC` (or `date -u -r <epoch>`), and the step text that asks the lead whether a record changed since a dispatch names that helper instead of leaving the format to the lead. Probe: the helper's output for a file with a known epoch equals `date -u -r <epoch> +%FT%TZ` under a non-UTC `TZ`, with `TZ=UTC` as the control.

Scheduled in batch 235 for a later release (scope ruling: the boundary is the release).

verify: manual

## BL-580 — the ai-dlc-update skill prescribes long runs but never says to background them, so every pull's first long call is denied and re-issued

**DEFECT.** Filed by peer session ai-dlc-68 (listed as ai-dlc-4e [e15800]) from graph's ai-dlc-update sessions. The steering-budget deny ("this FOREGROUND Bash call declares timeout 600000 ms, over the 120s steering budget") appears exactly once in each of graph's last three update sessions (intake counted read-only: `3d1088df` 1, `38c562c5` 1, `1d7b4691` 1): the 0.790.0 pull at the self-update gate, the 0.791.0 pull, and the 0.792.0 self-update at 06:37:40Z on 2026-10-16 on `self-update-fixtures.sh` over 19 fixtures, re-issued in the background at 06:37:43Z. Three of three pulls lost a round trip, each after the session reached for `timeout: 600000` itself.

The skill prescribes the long runs (the self-update gate, `self-update-fixtures.sh`, `apply.sh`, and the push with its pre-push suite) but never how to run them: `core/skills/ai-dlc-update/SKILL.md` at c16609ba mentions `run_in_background` 0 times (control: `self-update-fixtures` 6 times; graph's installed copy reads the same, 0 and 6).

The filer's alternative fix is already shipped and is NOT the gap: the deny text the session received names the remedy ("Re-issue the same call with run_in_background: true and collect its result when it completes, or declare a timeout of at most 120000 ms"), and `core/hooks/ai-dlc-foreground-budget.sh:3` says the hook does so. The recovery works; the round trip is the cost of a skill that never states the form up front.

Owed: SKILL.md states once, at the first long-running step, that every reconcile script and the push run with `run_in_background: true` and the session waits for the completion notice. Receipt: SKILL.md names `run_in_background` at the `self-update-fixtures` step (no behavioural replay for a prompt fix, batch 147 ruling).

Not filed, noted: the same session wrote its fixture list to a bare `/tmp/x` (2 writes in `1d7b4691`) outside its scratchpad — a shared path concurrent sessions can collide on.

Scheduled in batch 235 for a later release (scope ruling: the boundary is the release).

verify: manual

## BL-581 — the reconcile log records a false-zero as "Verified": a consumer-repo `git show <dist-sha>:` failed silently and every base count read 0

**DEFECT.** Filed by peer session ai-dlc-68 (listed as ai-dlc-4e [e15800]) from graph's 0.791.0 → 0.793.0 apply, session `1d7b4691` (Sonnet), 2026-10-16 03:18-03:22 EDT. `derivation-differential.sh` reported 8 NEWLY-FAILING, all recorded `$ grep -n … scripts/ai-dlc/validate-artifact-budget.sh` derivations in s319 artifacts (carry-over-evaluation-architect-5.md:13 and :23, carry-over-evaluation-pm-5.md:13, prd.md:1289, carry-over-evaluation-party-repair-p1.md:632, requirements-party-repair.md:859, shards/carry-over-evaluation-party-repair-p1/5.md:15, shards/requirements-party-repair/08.md:102). To find why, the session ran `git show 952b9319:scripts/ai-dlc/validate-artifact-budget.sh 2>/dev/null | grep -c -F -e "$p"` in graph's tree (2 such commands in the transcript). 952b9319 is a distribution sha: intake confirmed `git -C graph cat-file -e 952b9319` fails (control: graph's own HEAD resolves), so the `git show` failed, `2>/dev/null` hid the error, and every base count read 0. Graph's `_bmad-output/ai-dlc-update/reconcile-log-20261016T0725Z.md:33` then records: "Verified: `330000 to 66000`, `66000 and an in-budget pool became a HARD_BLOCK`, `  ok  %-44s` and `--quiet)` each count 0 at base and 1 now", and demotes the real cause to "Inference, not verified: the recorded line numbers moved with the 0.792.0 …".

Ground truth, intake re-derived on `core/scripts/validate-artifact-budget.sh`: each of the four needles counts 1 at 952b9319, 1 at 27467671 (0.792.0) and 1 at c16609ba, with a made-up needle at 0 at all three. The text was never added; 0.792.0 moved the line numbers the recorded `grep -n` derivations cite. The log has the cause backwards and labels the wrong half verified — the false-zero shape CLAUDE.md's "a zero is not a finding" names: an absence produced by a failed read, with no control in the invocation.

Consequence: the disposition ("leave untouched, record as owed") was the operator's and holds either way, but the s319 session inheriting the 8 re-points is told the needles were added in 0.792.0, when each is a line-number re-point.

Owed: (a) `derivation-differential.sh` prints, per NEWLY-FAILING row, the derivation's base and theirs output (or their diff), so the cause is measured by the shipped tool; (b) wherever ai-dlc-update's SKILL.md asks for a distribution path at base, it names `git -C <dist> show "${BASE}:core/…"` — a consumer-repo `git show <dist-sha>:` always fails. Receipt: a probe `grep -n` derivation whose needle stays but whose line shifts between base and theirs is reported NEWLY-FAILING with both outputs shown; an unchanged derivation is the control.

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

## BL-585 — release gates go red on the release's own shell defects, and each red costs a full re-push

**DEFECT (efficiency).** Filed by peer session ai-dlc-68 (listed as ai-dlc-4e [e15800]) from lead ai-dlc-9c's batch 235 reports and the failure records in the main checkout.
- 0.795.0 (vssnap): the first gate went red on a pipe into `grep -q`, caught by I54. Re-pushed, about +10 min.
- 0.796.0 (W): the first gate went red on six silent-failure redirects, caught by `procsub-staged-refusal` (`.git/ai-dlc-fixture-failures.20261016T085900Z.80433`, 1 of 73 units red). Re-pushed, about +15-20 min.
- The 08:29Z run (`.git/ai-dlc-fixture-failures.20261016T082952Z.45977`) had 11 of 43 units red, mostly enforcement-map fixtures reporting FIXTURE BROKEN.
- 0.797.0 (H-a), per lead ai-dlc-9c's report and NOT verified by intake (the main checkout was in a quiet window): the third release in a row whose first gate went red on its own code — 3 red units, at least two from H-a's own code; the fix plus a fresh gate cost about 35-50 min. Which check caught them is not yet established.
- The `procsub-staged-refusal` family's recorded loaded costs, per the filer: 138, 183, 101 and 256 s.
Intake confirmed both cited failure records exist (21 `ai-dlc-fixture-failures.*` files in `.git/`).

The cheapest checks that catch these classes run only inside the full gate, so a red there throws away the whole run, including mutant batteries that had already passed.

Owed:
1. For each red gate in batch 235, establish which check caught it and how long that check takes alone on the changed files only (H-a's red is a discriminating input to add once its cause is known).
2. A single pre-gate command that runs those checks on a builder's own diff in seconds, within the rule that a hand verifies only its own change.
3. Fail fast: when a cheap phase goes red, stop before dispatching the mutant batteries, or dispatch the cheap catchers first.
4. State the gate minutes saved per avoided red, with the dollar figure beside them.
Related: BL-583, BL-584.

Assigned to ai-dlc-4e [9b62de] by lead ai-dlc-9c, to build after H-b, with the two confirmed red commits (vssnap, caught by I54; W, caught by `procsub-staged-refusal`) as its discriminating inputs.

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

## BL-604 — a refused wait-for-deliverable.sh call (exit 64) reads as NON-DELIVERY by the lead's own instructions, so a live teammate is re-dispatched

**DEFECT.** Filed by peer session ai-dlc-ad; closes with its BL-599 release (branch `b235-since-dispatch`). `core/scripts/wait-for-deliverable.sh` exits 64 at 12 usage-refusal sites at origin/main 3d5f1e70, all executable (`--since` with no or a bad value, an unknown arg, no paths, `--complete` with `--progress-path`, …). `core/skills/ai-dlc/rule-bodies/rule-29.md` (the beat's exit list, ~:96-108) names only `exit 0` (BEAT COMPLETE) and `exit 1` (NON-DELIVERY: re-dispatch ONCE, then HARD_BLOCK) — intake counted 64 mentioned 0 times there — and `core/skills/ai-dlc/steps/_gate-procedures.md:141` says "Nonzero means non-delivery, nothing else." So a backgrounded beat refused for a malformed call arrives as rc 64, reads as non-delivery, and the lead spends the Rule 20 re-dispatch on a live agent with no beat armed.

Owed (in ad's BL-599 release): rule-29's list gains `exit 64 -- REFUSED` (no beat ran and the join is not armed: correct the call and arm again), and wait-stale-deliverable case C46 derives the script's exit codes and fails when rule-29's list does not name each one; the control (rule-29 without the 64 line, and origin/main's rule-29) reports 64 missing. ai-dlc-c9's release (a) carries the `_gate-procedures.md:141` wording as its A10.

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

verify: manual

## BL-608 — the validator fork budget's headroom eroded from +6 to 0 across five releases, and nothing warned

**DEFECT.** Filed by peer session ai-dlc-a6. `scripts/validate-enforcement-map.sh` FORK_BUDGET was set to 3363 in 0.786.0 as "HIGH reading 3357 plus the usual 6" (paragraph ~:825-831 then). Measured by the filer on 2026-10-16 with `fork-profile.sh --section by-arm --stable`, interleaved base/tip/base/tip in one detached worktree at one path, caller environment inherited: origin/main e3073787 (0.796.0) read 3362 and 3363 (STABLE 2, spread 3360-3362), equal to the budget — 0.792.0 through 0.796.0 spent the full +6 and no arm said so. `validator-fork-budget` fails only when the reading EXCEEDS the budget (its arm A3, "measured <= FORK_BUDGET"), so the window between "headroom gone" and "red" is invisible; at zero headroom the instrument's ±1-2 jitter makes any release adding one fork a ~1-in-4 red that reads as a flake. On 0.797.0 (+1 fork, I126 0 -> 1) the re-verify read 3362 with one rep at 3364 against 3363; 0.797.0 raised the budget to 3370 (+1 for its arm, +5 to restore headroom), which intake confirmed as `FORK_BUDGET=3370` at origin/main 3d5f1e70 (`:841`).

Owed: a headroom arm in `validator-fork-budget` that FAILS when the STABLE reading + 2 > FORK_BUDGET, naming the remedy (re-measure and raise by the HIGH reading plus 6, per the file's own rule), so erosion reports while margin remains. It needs its own mutant (the arm with the +2 dropped must miss a seeded reading at budget - 1) and its FP set measured over the budget history in that file's paragraphs. Scope: a small later release.

verify: manual

## BL-609 — a pre-gate listing of the fixtures a builder's diff selects, so a red caught only by executing a fixture is foreseen before the slot request

**DEFECT (efficiency).** Filed by peer session ai-dlc-4e [9b62de] on lead ai-dlc-9c's instruction; assigned to ai-dlc-4e [9b62de], to build after BL-585 (which gates first, by 9c's ruling).

Premise, measured from H-a (0.797.0): the red capture `.git/ai-dlc-fixture-failures.20261016T094322Z.82523` (intake confirmed it exists) records `gate-resume: 1 of 63 assertion(s) FAILED`, the line being `BL-457 mutant (e) … expected [… WC=1 …], got [… WC=0 …]`. Per the filer that red was H-a's own code: `core/fixtures/gate-resume/seed.sh:26` reads `core/hooks/ai-dlc-recover.sh`, H-a's new sentence in that hook's injected block consumed the WC case's margin under its 10000-char ceiling, and H-a removed the sentence before merging. WC measures the hook's real emitted output on a seeded worst case, so no static check over the diff catches it (no grep, no validator, not BL-585's pre-gate self-check); only running the fixture does. The edge is already recorded: intake counted 17 fixtures whose row in `.ai-dlc-fixture-readsets.tsv` names `core/hooks/ai-dlc-recover.sh` (the filer said 18), `gate-resume` among them. A reading of the fixture's own files misses it, because the dependency runs through what the seed reads.

Owed:
1. A report-only arm `e:readset-impact` in `scripts/pregate-self-check.sh` (that script is BL-585's, on local branch `b235-pregate`; not on origin/main at a0451c70). From the diff it lists each fixture whose read-set contains a changed path, with its recorded loaded cost from `.git/ai-dlc-fixture-durations`. The read-set reader is sourced from the hook (`readset_manifest` / the map reader, 3 mentions in `.githooks/pre-push`), never restated. It runs nothing and cannot turn red.
2. Before it ships, measure its value under the step-value ruling: does the listing change a builder's slot request, or what the builder runs before asking? If it changes nothing, it does not ship.

Related: BL-585.

verify: manual

## BL-610 — the read-set sandbox tracer omits any fixture that probes process liveness

**NOTE.** Filed by peer session ai-dlc-a6 on lead ai-dlc-9c's instruction. `core/scripts/derive-fixture-readsets.sh --tracer sandbox` runs each fixture under `sandbox-exec` with a profile that grants file and process-exec rights but no process-info rights (intake: `process-info` 0 times in the script, against 16 `sandbox-exec`). Inside it `ps -p` sees no other process, not even its own shell, so a fixture whose premise is process liveness fails its own controls and the deriver omits it ("OMITTED (fixture exited 1) -- will always run", 1 occurrence in the script).

Measured by the filer on 2026-10-16 in a trace of 14 fixtures at a0451c70 (rc 0, 173 s, 13 mapped): `derivation-differential` was omitted (its `run.sh` uses `ps -p` 7 times). Its sandboxed log `/private/tmp/ai-dlc-readset-sandbox-501/w/derivation-differential.log:47-48` carries the two A12 control failures (intake confirmed both lines verbatim; the log holds 13 lines containing `FAIL` in all, which the filer's "exactly two FAILs" does not account for):
  `FAIL  A12 control: ps -p does not separate the seeded dead PID (52683) from the live one (46059) -- A12b and A12l are unreadable`
  `FAIL  A12 control: PID 1 does not separate ps -p from kill -0 here (running as root?) -- A12e is unreadable`
Outside the sandbox the fixture is green: per the filer, `ok derivation-differential` appears in all three 2026-10-16 gate logs (an impossible token reads 0), with 7 loaded runs that day at 15-31 s each.

Cost: it stays unmapped and runs on every push, about 20 s, not the gate pole. It ran on every push before too (its rows were stale), so this is a permanent read-set gap, not a regression. Two candidate fixes, neither chosen: grant process-info in the profile (broadens what a trace records, to be weighed), or skip the liveness arms under the sandbox (weakens the fixture exactly where the trace looks; not recommended). Not to be fixed now.

verify: manual
