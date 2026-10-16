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

## BL-531 — a message typed in another session of the same project raises the lead's pause flag

**DEFECT. Operator ruling 2026-10-15: a message typed in another session in the same project must
not create the pause flag.** `core/hooks/ai-dlc-pause.sh:381-382` touches
`_bmad-output/pipeline-paused.flag` for a typed prompt in any session once the pipeline is active.
The typing session's id is logged (`:391`) and never compared with anything. No hook or snapshot
field records which session is the lead, so there is no value to compare it against.

Measured in graph s319: a message typed at 19:15:51Z in session `0efd887c-26f7-44e5-94aa-2147fa1496fd`
paused lead session `62eadbbe-59c3-436d-bf7c-931ebc09ecba`. Six remediator dispatches were denied by
Rule 29 (19:24:56-19:25:26); the lead then removed the flag at 19:25:43, read the message at 19:25:53,
and re-dispatched all six (19:26:04-19:26:30) before telling the operator at 19:27:01. The archived
entry about the same hook (`docs/backlog.archive.md:15400`, a missed opening prompt) is a different
subject.

Owed:
1. The lead records its own session id when it routes (route.md Step 6, fresh start) and again on
   every resume (Step 0, a new session). A compaction keeps the id.
2. `ai-dlc-pause.sh` raises the flag only when the typing session matches that id. A prompt from any
   other session is still captured to `operator-requests-history.md` (Check 33 and
   `user_request_cite` depend on full capture) and logged as a distinct event, not a pause.
3. With no recorded lead id (a pre-migration tree) the hook pauses as it does today, so a missing
   binding never lets the lead's own operator message through unpaused.
4. A probe in both directions: the bound session pauses; a different session captures and does not
   pause; no binding pauses.

verify: manual

## BL-537 — a spawn made by a teammate is recorded nowhere, so a second writer or reviewer has no provenance

**DEFECT.** In graph s319 the `pm-escalated` requirements authoring agent (`a1c69096c184098d6`, dispatched by the lead at 22:01Z) spawned a `general-purpose` subagent itself, "PRD rubric walker S319" (`afe532cc5f05cad9d`, 22:14:55–22:16:40Z), which wrote `_bmad-output/planning-artifacts/s319/prd-validate/review-rubric.md`. That spawn is required by the skill the step invokes: `requirements.md:178` runs `/bmad-prd` validate, and `.claude/skills/bmad-prd/SKILL.md:73-75` tells it to dispatch its rubric walker and reviewers as parallel subagents. `_bmad-output/spawn-ledger.jsonl` has 0 rows for it, against 1 row in `subagent-context.jsonl` (the post-completion probe), so the dispatch-time record misses it while the completion record sees it. `ai-dlc-dispatch-guard.sh` writes the ledger row at dispatch (append at line 1120). Why this call left no row was not traced: it is a teammate-issued call (`agent_id` set) for a role with no `core/team-roles/` file.

This is the same class as the consumer's `PC-S319-LEDGER-ATTRIBUTES-AN-EDIT-TO-AN-AGENT-ID-WITH-NO-TRANSCRIPT`: there, one `.artifact-writes.jsonl` row on `sections/2.md` carries agent id `ad67234a336bc2239`, which has no transcript, no spawn-ledger row and no tool call in its parent remediator's transcript, and the join refused the shard as two writers. Both cases leave a write by an agent the pipeline has no dispatch record for. Check 22 and every join that counts writers read the spawn ledger, so a nested spawn is invisible to them.

Owed: either a teammate's `Agent`/`Task` call is recorded in the spawn ledger with its parent `agent_id`, so a join can attribute a nested writer to its dispatcher, or teammate spawns are refused and any skill that a step invokes and that dispatches subagents (`bmad-prd` validate is one) is told to run its reviewers sequentially, which `SKILL.md:75` already allows ("If subagents are unavailable, run sequentially"). A probe drives one teammate-issued spawn and asserts the record.

verify: manual

## BL-538 — the lead takes a full turn for every agent notification while an armed join already covers it

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

## BL-545 — after a compaction the lead dispatched before its Rule 32 R advisor call

**DEFECT.** SKILL.md Rule 32 touchpoint R: "after the `postcompact-digest.md` Read … call the advisor in the same turn, before your first dispatch or write." In s319 the lead compacted at 23:01Z, read the snapshot, `requirements.md` and the digest (23:01:07–23:01:18), dispatched 12 party-repair remediators from 23:02:18Z, and called the advisor at 23:03:19Z. Its own message: "I haven't made the post-recovery advisor call (touchpoint R) yet, so I'm making it now." `ai-dlc-advisor-gate.sh` denies a release push or merge without an advisor attempt, but no hook holds a post-compact dispatch behind R. The recover-gate forces the three reads and then lets the next `Agent` call through. Owed: the recover-gate, or the advisor gate, denies `Agent`/`Task` and writes after a compaction until an advisor attempt follows the digest Read. A probe shows a dispatch denied before R and allowed after.

verify: manual

## BL-546 — a SPEC part remediator hand-edits `SPEC.md`, which core forbids and nothing refuses

**DEFECT.** `_gate-procedures.md:925-929` and `requirements.md:233-236`: the SPEC part's shard "never edits `SPEC.md` by hand"; it appends a `(decision)` to `.memlog.md` and re-renders through `bmad-spec`. In s319 this was broken twice. The requirements party-repair part 04 remediator "first applied the edits to `SPEC.md` by hand, then redid the change through the memlog and re-rendered". The serial cross-part remediator disclosed "a direct edit of `SPEC.md` without re-rendering through `bmad-spec`" at 00:04Z. Both were caught only by the agents' own disclosure. No hook refuses an Edit/Write to `_bmad-output/specs/**/SPEC.md` from a remediator, and the join does not compare `SPEC.md` against a render of its memlog. Owed: a guard denying direct writes to `SPEC.md` outside the `bmad-spec` render path, or a join arm that re-renders from `.memlog.md` and refuses a byte difference.

**Third instance, with a cause (graph s319 requirements elicitation repair, part 04, 01:04–01:18Z on 2026-10-16).** The SPEC part remediator appended its `(decision)` entry to `.memlog.md`, invoked the `bmad-spec` Skill to re-render, and then hand-wrote the `SPEC.md` edits. In its own words: "The `bmad-spec` Skill only loaded its instructions, so I hand-wrote the SPEC.md edits. The record says this." So the earlier two instances may not be agents ignoring the rule. In a teammate, invoking the Skill delivers the skill's instructions into the agent's context and renders nothing, and the agent then has to perform the render itself by editing `SPEC.md`. That is the hand edit the rule forbids. `join-remediator-shards.sh --pass elicitation` then joined all 13 parts with no refusal (01:18:39Z), confirming that no arm compares `SPEC.md` with a render of its memlog. The lead noted the breach ("That breaks the rule against editing the SPEC by hand") and deferred handling it. Owed, in addition to the guard: a render path a teammate can actually execute (a script that renders `SPEC.md` from `.memlog.md` deterministically, or a stated procedure the Skill's instructions resolve to). Until one exists, a guard denying `SPEC.md` writes would block the SPEC part outright. Measure first by driving `bmad-spec` headless from a teammate context and recording whether `SPEC.md` changes.

**The render path does not exist, even outside a pause (graph s319 resumed lead `f65eae3b`, fold teammate pm-escalated `a9dd4af333cca61de`, 02:17–02:30Z 2026-10-16).** With no pause flag set, the teammate invoked `Skill bmad-spec` at 02:25:08Z with args "headless update … re-derive SPEC.md from .memlog.md". The Skill loaded its instructions, ran `resolve_customization.py`, and then the teammate hand-edited `SPEC.md` with four `Edit` calls (02:25:23–02:25:31Z). Its returned JSON says `"rendered_by": "hand"` and "the package has no renderer (assets/ holds only the template and schema; _bmad/scripts/ holds only memlog.py and the resolvers)". That is true of graph's tree: `.claude/skills/bmad-spec/` holds SKILL.md, customize.toml and assets/{headless-schemas.md, spec-template.md}, and `_bmad/scripts/` holds memlog.py, resolve_config.py and resolve_customization.py. Meanwhile `bmad-spec/SKILL.md:46` says SPEC.md is "DERIVED from .memlog.md, never hand-edited". The "derivation" is the model distilling under the skill's instructions, so a teammate reading "no render script" concludes that a hand-applied Edit is the only path. The lead accepted this at 02:30:34Z ("That is the only path available, so I'm proceeding on it") and dispatched the 19-agent adversarial series on SPEC `d08b4b81`, although the V1 advisor at 02:14Z had said not to dispatch the adversarial series on a hand-edited SPEC, so the advisor's condition was satisfied by relabelling, not by a render. Correct one of the two: either ai-dlc's brief states that a bmad-spec update IS the agent re-deriving SPEC.md from the memlog under the skill's instructions (and how that differs from piecemeal Edits: a full rewrite from the memlog, plus the two-pass sweep recorded as memlog `event` entries, SKILL.md:117-123), or ship a render/verify script that checks SPEC.md against the memlog (BL-560). Today every SPEC change in s319 has been a piecemeal hand Edit (part 04, the 01:48Z pass, the 02:25Z fold), and nothing distinguishes them from a render.

verify: manual

## BL-547 — the lead hand-writes the walk-up for "is this seat file finished", and a trailing blank line miscounts it

**DEFECT.** In s319 at 22:52Z the lead counted completed party seats with its own last-line check, got a low count, and spent a second round trip finding that several files end in a trailing blank line, which `wait-for-deliverable.sh --complete` already skips. Its words: "my last-line check may be tripping on a trailing blank line." The program that answers this correctly exists, but its answer is only available as a beat that sleeps. Owed: `wait-for-deliverable.sh --complete --status <paths>` (or a sibling) prints, without sleeping, the same DELIVERED/UNFINISHED/UNSETTLED per path, so a progress check uses the shipped predicate rather than a hand-rolled one.

**Second instance, a hand loop that skipped absent files (graph s319 resumed lead `f65eae3b`, requirements-adversarial-p1, 02:42–02:43Z on 2026-10-16).** Filed by peer session ai-dlc-68. At 02:42:49Z the lead wrote "Of 19 shards, 16 have a closing seat-complete line". At 02:43:33Z it corrected itself: shards 11, 13, cross-1 and cross-3 had no file at all, and its loop had skipped absent paths. With the beats unable to report DELIVERED (BL-566), this hand check was the lead's only completion signal.

verify: manual

## BL-548 — a seat edits its own file after writing `seat-complete:`, against its contract, and nothing records that the findings changed

**DEFECT.** In s319 three seats edited their sealed file after the marker. Requirements dev part 01 ("I edited the file once after writing `seat-complete` … The seat contract says not to edit after that line") and dev cross g4 did so in the party round, and dev cross g2 reported its sealed "Checked and not raised" section unreliable. `--complete`'s settle window only delays delivery until the edits stop. It does not record that a finding set changed after the seat declared it final, so the repair cannot tell a revised seat from an original one. Owed: the beat or the merge reports any seat whose content hash changed after its marker was first seen (it already holds that hash in the `.settle` sidecar), and the lead's repair brief marks those seats' findings for re-read.

**A rescan by the lead missed a duplicate because it hand-rolled the heading grammar (01:01:50Z).** While clearing the cross-owner refusal (BL-555), the lead scanned every cross shard for owner-duplicate section sets with its own pattern, which missed `### F-6 (MAJOR) <title>`, a heading with a title after the severity. It had to rescan "with a looser pattern". This is the same root as BL-547: the program that parses a shard is `merge-adversarial-shards.sh`, and the lead rewrote its grammar by hand instead of asking it. Owed alongside BL-547's status mode: a `merge-adversarial-shards.sh --dry-run` that prints every refusal at once rather than stopping at the first, so the lead clears a round's duplicates in one pass.

verify: manual

## BL-549 — the stop hook reported "no live wait-beat" while a beat had just been armed

**DEFECT.** Twice in s319 the Stop hook fired "IF YOU ARE WAITING ON A TEAMMATE, this block means NO LIVE WAIT-BEAT IS ARMED" while a beat appeared live. First at 23:13:02Z: five seconds later the lead read `.beat-inflight` as holding an epoch about 29 s in the future. Then at 00:00:49Z, seconds after the lead armed beat `bcd634p7x`. `ai-dlc-continue.sh` defers only on a live `.beat-inflight` lease (`beat_lease_live`, comment around line 290). A beat that returns and re-arms within the hook's read window, or a marker written after the hook reads it, would explain both. Not proven: the marker may have cleared in between. Owed: trace the order in which the beat writes, clears and rewrites the marker against the Stop hook's read, and either lock it or have the hook re-read once after a short delay. A probe races a re-arm against a Stop.

verify: manual

## BL-550 — party seats grep for files that do not exist, because nothing gives them the repository's real paths

**DEFECT (efficiency).** Across 134 s319 party and elicitation seat transcripts there are 105 "No such file or directory" lines. Seats guessed paths such as `rebalancer/db.py`, `rebalancer/state_store.py`, `server/main.py`, `rebalancer/config_schema.py`, `infra/lib/ecs-stack.ts` and `rebalancer/execution_log.py`, none of which exist and none of which the subject files cite (`grep -l -F` over the PRD, SPEC, brief and `architecture-impact.md` returns 0 for each, against 3 for the control `rebalancer/execution.py`). Each miss is a tool round trip and a guess that can be filled in with an invented answer. Owed: the seat brief carries the subject's cited code paths (derivable from the subject files) and an instruction to resolve any other path with `git ls-files` before reading it.

**Second instance, the adversarial round (graph s319 resumed lead `f65eae3b`, requirements-adversarial-p1, 2026-10-16).** Filed by peer session ai-dlc-68. Seven parts (1, 2, 6, 8, 13, cross-3 and cross-6) made 13 greps for nonexistent paths: `dashboard/`, `extensions/`, `shared/`, `shared/tokens.py`, `aggregator/`, `rebalancer/config_schema.py`, `rebalancer/config.example.json`, `rebalancer/tests/test_s318_subscribe_pin.py`, `test_s245_subscribe_pin.py`, `web/src/pages/Dashboard.jsx|tsx` and `web/src/hooks`. Three more greps died on `ugrep` limits: "exceeds complexity limits" on `.{0,80}` and `[^.]{0,140}` (parts 12 and cross-6), and "empty (sub)expression" on `\b` inside an alternation (cross-5). The brief owed above should also state a pattern form that `ugrep` accepts.

verify: manual

## BL-551 — a teammate leaves files staged, and nothing returns the git index to the lead clean

**DEFECT.** The s319 requirements authoring agent (`pm-escalated`, 22:01–22:21Z) relocated the spec package with `git add` then `git mv`, so `_bmad-output/specs/s319/offramp-config-and-rewards/{SPEC.md,.memlog.md}` are staged in graph's main checkout (`git diff --cached --name-status` shows them as `A`), alongside the lead's own staged `pipeline-snapshot-archive.md`. Its report disclosed this. The teammate role files do not say whether a planning teammate may stage or commit, so the lead's next commit can carry another agent's staging without either noticing. Owed: a stated rule that a planning teammate leaves the index as it found it (no `git add`/`git mv`), and a check at dispatch return that the index is unchanged, or names what changed.

verify: manual

## BL-552 — the lead posts a status line for every finished seat even with a join covering the round

**DEFECT (efficiency).** Distinct from BL-538 (the wake itself): even when the lead does take a turn, the step files give it nothing to do with "seat N delivered" except narrate it. In the s319 party round (36 seats) and elicitation round (19 shards), almost every arrival produced a lead message of the form "<seat> delivered (n findings). The join beat is still armed …". The text carries per-seat finding counts that the merge recomputes anyway. Owed: the step files say a notification for an agent inside an armed `--complete` join gets no per-agent summary; the lead ends the turn, and reports the round once from the merge.

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

**DEFECT.** `core/team-roles/remediator.md:313-316`: "For an item that is locked or operator-owned, give no recommendation. That is a … `D-<n>` decision, a config leaf, a money-path threshold or literal … State each option with its concrete effect … and stop there." In graph s319 requirements elicitation repair, part 09 (`s319/shards/requirements-elicitation-repair/09.md`, PRD section 5, the Net P&L card) repaired seven findings. Two of the fixes applied rules the operator never stated: F-4 "one unavailable pool makes the total unavailable", and F-7 "whole-card em dash for a partial price miss". Both are the behaviour of the operator's D-5 ruling, which reads only "If inputs are unavailable then show -. Yes it is acceptable interim risk." The remediator's own report calls them "My gap fills … The lead may veto either." So operator-owned text now carries an agent-chosen rule unless the lead happens to strike it. The same part did the right thing for its F-1 (S3 pass-or-block on a null), which it escalated without picking, so the role contract is understood. It just does not stop the agent applying the gap fill. Its siblings in the same round followed it: part 08 escalated the D-1 write ordering with options and no recommendation. Owed: the repair brief and `remediator.md` say a fix that extends a `D-<n>` or `LR-` decision to a case its words do not cover is an `escalated` entry, never `repaired`. The `--sources`/`--escalations` join refuses a `repaired` entry whose `edit:` lands in a span citing a `D-<n>` or `LR-` id when its claim carries "gap fill" or "veto". The refusal is measured against graph's records first.

**The serial remediator kept the gap fills (01:50Z).** The serial cross-part remediator's report reads: "Part 09 gap-fills (kept as written): one unavailable pool makes the total unavailable (F-4), and a partial price miss renders the whole card as an em dash (F-7)." The lead did not strike them and the gate has not run. So two agent-chosen rules extending the operator's D-5 ruling have passed a second agent and are in the requirements subject heading into the adversarial series, with no operator sight of them. In the same pass, S-24 reversed part 01's F-2 wording on the stable-only sweep. That is a second agent overriding a first agent's repair, with no adjudication recorded beyond its own report.

verify: manual

## BL-557 — a remediator proceeds without the advisor and without replaying its derivations, and the record does not say which checks it skipped

**DEFECT.** In graph s319 requirements elicitation repair (13 part remediators, 01:04–01:09Z), 9 of the 19 elicitation-round transcripts (repairs plus shards) report the advisor rate-limited. At least six part remediators (01, 02, 05, 07, 10, 11) wrote their part record "without that review". Separately, part 02, 07, 10 and 12 report "I did not replay the `derived` fences with `validate-artifact-derivations.sh`", against `remediator.md:221-223`. That rule says a check that reads the tree is a `derived` fence "replayed by one call to `scripts/ai-dlc/validate-artifact-derivations.sh <that file>`". Each disclosed the gap only in its final chat message. The record that the join and the next pass read carries no field for it. The lead replayed the fences itself for every part (01:06–01:09Z), which caught nothing but cost 12 tool calls. Part 06 also edited before its first advisor call, against the role file's "consult the advisor … first" order, and the advisor flagged it. `ai-dlc-advisor-gate.sh` only WARNS when the last advisor result is `unavailable` (header lines 13-15), so a rate-limited round runs without review and leaves no trace in the artifacts. Owed: a part record carries `- advisor: called|unavailable` and `- derivations: replayed <n>|not replayed` lines. The join refuses a missing or `not replayed` value. The lead's per-part replay becomes unnecessary when the join reports it.

verify: manual

## BL-558 — `story-evidence-scaffold` costs 173-177s solo against a recorded pool-12 history of 2-3s, and the cause is not found

**DEFECT (efficiency).** Found at batch 234 while gating 0.790.0. Pushed from a linked worktree, the pre-push runner re-ran the same 10 fixtures every time (the 8 its read-set map leaves unmapped there, plus two), and `story-evidence-scaffold` was the pole of that set at 144s and 146s. The suite-pole guard judged it against its own pool-12 history, 8 rows with a maximum of 3s, and failed two gates on the regime ceiling (6s). Measured solo and interleaved, from detached worktrees of `origin/main` (`bfb5589e`) and the release tip (`1c2bf345`), at load 4-6: base 177s and 175s, tip 173s and 171s. So the cost is not the release. The 2-3s rows are not explained: a grep of `run.sh` (725 lines, one file in the fixture) for reads outside `core/` (`projects`, `graph`, `HOME`, `git log`, `find`) found none, and the fixture's own run log shows a full mutant battery over about 30 handoff and strategy cases. Its 8 pool-12 rows were dropped on the operator's choice with the guard's own printed remedy (backup kept), and the next gate read `CALIBRATING (1/3)` at 143s and passed.

Owed: find what the 2-3s rows measured (a skipped battery, a different dispatch, a different tree) and whether 175s is the fixture's real cost. If it is, the fixture is a candidate for the same sharding the other batteries got, since a 175s unit can become a full-suite pole. Measure solo first, in a clean worktree, and name the tree beside the number.

verify: manual

## BL-559 — the pause gate denies `Skill` to an in-flight teammate, so a dispatched render cannot finish and the handoff waits on it

**DEFECT.** `core/hooks/ai-dlc-acknowledge.sh:572-581`: while paused, a teammate's Write/Edit is allowed (`ACK_TEAMMATE_WRITE`), so an in-flight teammate is not left half-amended. But "Agent/Task/Skill/TaskCreate stay denied for a teammate too." In graph s319 at 01:50:21Z the lead dispatched a `pm-escalated` agent to re-render `SPEC.md` from `.memlog.md` through `bmad-spec`, which is the path core requires for the SPEC (`requirements.md:233-236`). Four seconds later, at 01:50:25Z, the operator typed "handoff", and the pause flag went up. The render agent read its inputs, then at 01:50:39Z invoked `Skill bmad-spec` and was denied: "AI/DLC Rule 29: the pipeline is PAUSED". The lead, following `handoff.md` step 1, armed one bounded-join beat over that agent's deliverable at 01:50:47Z. The only route to that deliverable is the Skill call the gate refuses. So the rule meant to let an in-flight teammate reach a consistent endpoint blocks exactly the call that reaches it, and the handoff's join can only time out. `SPEC.md` is left stale against the PRD, which the lead said at 01:50:16Z ("SPEC.md is stale against the PRD until `.memlog.md` is re-rendered"). Owed: a teammate dispatched before the flag was raised may invoke `Skill` (it spawns no agent and is the derive path, unlike Agent/Task/TaskCreate), or `handoff.md` step 1 names what to do when an in-flight teammate's only remaining work is a denied call (stop it as `stopped`, with the stale artifact recorded in Open Items). A probe raises the flag between a teammate's dispatch and its Skill call and asserts the outcome.

**Outcome.** The render agent did not fail when the pause flag denied `Skill bmad-spec`. It hand-applied memlog lines 30 and 31 to `SPEC.md` and returned at 01:53:08Z, which is the BL-546 hand-edit path again. The handoff then committed that SPEC as `dbc4c057e`. So the pause gate turns a rendered SPEC into a hand-edited one, silently, rather than stranding it.

verify: manual

## BL-560 — the SPEC re-render is a separate dispatch the lead must remember, and the subject is left stale between them

**DEFECT.** In graph s319 the serial cross-part remediator appended 4 `(decision)` entries to the spec's `.memlog.md` and edited none of `SPEC.md` (its writes: prd 28, architecture-impact 8, product-brief 8, memlog 4). That is correct under `requirements.md:233-236`. But it left `SPEC.md` behind its memlog when the pass delivered, and the join accepted the record. The lead then had to dispatch a separate render agent (01:50:21Z), which the pause then stranded (BL-559). The earlier SPEC remediators (BL-546) did the opposite, rendering by hand. Between the two, nothing ties "the memlog has entries newer than `SPEC.md`" to any check, so the subject that the next adversarial pass and the gate read can carry a SPEC that does not reflect its own decisions. Owed: the join (or `validate-artifact-derivations.sh` over the subject) refuses when `.memlog.md` holds a `(decision)` entry dated after `SPEC.md`'s last render stamp, so the stale state cannot reach the adversary. BL-546's render path is what lets the serial remediator close it itself.

verify: manual

## BL-561 — `--sources` on a non-party repair record does not refuse whenever the sprint also has party seats

**DEFECT.** Filed by peer session ai-dlc-68 from graph s319 (lead `62eadbbe`, handoff 01:50–01:55Z 2026-10-16). At 01:50:23Z the lead ran `join-remediator-shards.sh --sources _bmad-output/planning-artifacts/s319/requirements-elicitation-repair.md --sprint 319`. graph's installed `_gate-procedures.md:851-858` says that after the serial remediator appends to a record with no party seat files (adversarial, elicitation or gate repair), the lead runs `--escalations <record> --sprint <N>`, and that only a party record takes `--sources`. The script's own header (`join-remediator-shards.sh:579-580`, `:801-803`) says `--sources` "needs the sprint's party-mode/s<N> seat dir and refuses without it". s319 HAS a `party-mode/s319/` dir because a party round ran this sprint, so `--sources` did not refuse: it resolved the elicitation record's `<cross-N|N>.md#F-n` tokens against the party seats and printed 138 REFUSED lines. The lead then misdiagnosed this as a tool defect, wrote it into `pipeline-snapshot.md` as "PC candidate worth filing: elicitation-pass sources resolve against the wrong dir", and never ran `--escalations`, so the open-escalation list in the handoff (S-21, S-22, S-23, S-8) was assembled by hand rather than printed by the join.

Two halves. (a) The join cannot tell a party record from a non-party one, so a wrong-mode call succeeds whenever the sprint happens to have party seats; it should refuse `--sources` on a record whose `source:` tokens do not name party seat files, or key the mode on the record's subject dir, and name `--escalations` in the refusal. (b) The lead picked the wrong mode with the right one stated in the procedure.

Owed: a probe running `--sources` on an elicitation record in a tree that also has `party-mode/s<N>/` exits non-zero naming `--escalations`, with a party record as the control that still passes.

verify: manual

## BL-562 — the lead pushed the handoff with `--no-verify`, and nothing prohibits or denies it

**DEFECT.** Filed by peer session ai-dlc-68 from graph s319. At 01:54:42Z the lead ran `git push -u origin HEAD --no-verify` (timeout 600000) as handoff step 3, and at 01:54:56Z justified it as "because the commit only touches `_bmad-output/` and `docs/escalations/`". graph's installed `handoff.md:58-70` and `_gate-procedures.md:1190-1209` prescribe `git push -u origin HEAD` and say "the push is the whole command". `--no-verify` occurs 0 times in `handoff.md`, `_gate-procedures.md` or `SKILL.md` (control: `git push` occurs 2, 4 and 0 times respectively). The lead bypassed the consumer pre-push hook on its own judgement that the change was artifact-only. No hook refuses `--no-verify` on a pipeline push, and the step file never prohibits it.

Owed: a PreToolUse deny on `git push … --no-verify` from the pipeline lead, or at least an explicit prohibition beside the prescribed command. Probe: the hook denies `git push -u origin HEAD --no-verify` and allows the bare prescribed form.

**Second instance, a different model (graph s319 handoff, lead `f65eae3b`, 03:05:42Z on 2026-10-16).** Filed by peer session ai-dlc-68. The lead (Sonnet 5.5) ran `git push --no-verify -u origin HEAD` at handoff step 3, justified as "The commit is bookkeeping-only, with all 38 paths under `_bmad-output/`", which is the same reasoning as `62eadbbe` (qwen) and contradicts `handoff.md:58-70` ("the whole command"). It ran after the Rule 32 advisor call at 03:05:30Z, and neither the advisor nor any hook stopped it. Two leads on two models took the same step the same way, so this is a pipeline affordance, not a model quirk.

verify: manual

## BL-563 — the ai-dlc-update post-write gates passed on an exit code nobody observed

**DEFECT.** Filed by peer session ai-dlc-68. Graph session `3d1088df` ran `/ai-dlc-update apply` for 0.789.0 → 0.790.0 and merged it as PR #1228 at 02:09Z on 2026-10-16. At 02:02:29Z it ran the post-write gates as one compound command, piping `setup-site-drift.sh … | tail -3; echo "rc=${pipestatus[1]}"` and `validate-hook-registration.sh | tail -3; echo "rc=${pipestatus[1]}"`. Both printed `rc=` with nothing after it. At 02:02:33Z the session wrote "The exit codes printed empty because the shell is zsh, but each check's own output line reports clean", then proceeded to `apply.sh --finish`, the commit, the push and the merge. graph's installed `.claude/skills/ai-dlc-update/SKILL.md:2853` states the gate as "Run `reconcile/setup-site-drift.sh <dist> <consumer> <theirs>`; exit 0", and `:2255` names `validate-hook-registration.sh`, so the verdict the skill prescribes is the exit code, and the session never observed it. It substituted a reading of truncated output (`tail -3`). The output happened to be decisive this time (SETUP-SITE-OK ×2, SETUP-SITE-SCANNED; UNREGISTERED none, DANGLING none), but a refusal line above the last three would have been cut away and the gate would still have read clean. The same hazard hit hard-blockers: at 02:03:42Z the background `hard-blockers.sh --post-apply` "came back empty", and the session re-ran it in the foreground.

Two halves. (a) The skill names exit-code gates but gives no capture form. It should state the command shape — unpiped, with `rc=$?` captured immediately after the gate command — or better, run all post-write gates through one script that prints a single verdict line per gate. (b) A gate whose exit code was not observed is UNDECIDED, never passed on prose; the session's own line shows it knew the code was missing and continued.

This stands whatever shell runs, because the lead piped the gate itself; the Bash tool's shell being zsh on this box is a separate matter the operator is handling (llm-gateway commit `263e8af`, branch `config/claude-code-shell`, unmerged). A bootstrapping caveat applies: the update skill is the program that delivers its own repair, so a fix lands on the pull after the one that carries it.

Owed: a probe gate that prints a clean last line and exits non-zero; the prescribed form must report it as failed.

**Second instance, the next pull (graph update session `38c562c5`, `/ai-dlc-update apply` 0.790.0 → 0.791.0, 2026-10-16).** Filed by peer session ai-dlc-68. At 04:32:21Z the session ran `setup-site-drift.sh … 2>&1 | tail -5; echo "ssd_rc=${pipestatus[1]}"`, and at 04:32:22Z `validate-hook-registration.sh 2>&1 | tail -3; echo "hook_rc=${pipestatus[1]}"`, which printed `hook_rc=` empty, the same zsh `pipestatus` failure. This time it was observed: at 04:32:27Z the session re-ran both unpiped (`>/dev/null 2>&1; echo ssd_rc=$?`) and got 0 and 0 before proceeding, at the cost of running each gate twice. The skill still prescribes no capture form. The rest of the apply was clean: `apply.sh`, `--finish`, the derivation differential and `report --verify` all captured `rc=$?` directly, commit `463765a5f` staged only pull paths, and the push ran without `--no-verify`.

verify: manual

## BL-565 — a serial remediator entry that re-escalates a part escalation carries no `closes:` link, so one open decision is counted twice

**DEFECT.** Filed by peer session ai-dlc-68 from graph's s319 resumed lead. At 02:17:57Z the lead ran `join-remediator-shards.sh --escalations …/s319/requirements-elicitation-repair.md --sprint 319`, which printed `ESCALATED-COUNT: 9 (2 closed …)`. The open set is 04.md F-8, 07.md F-1, 08.md F-1, 09.md F-1, 13.md S-8, S-17, S-21, S-22 and S-23. The serial entries' own `source:` lines show these are four decisions counted twice: S-21 `source: 7.md#F-1`, S-22 `source: 8.md#F-1 …`, S-23 `source: 9.md#F-1 …` and S-17 `source: … 4.md#F-8`. Each serial entry is itself `disposition: escalated`, and none carries `- closes:`, because `_gate-procedures.md:853-855` lets only a `repaired` entry close an escalation. The lead's snapshot then says "Still open after the fold: 13.md S-8 … and S-17" and drops 04 F-8, 07 F-1, 08 F-1 and 09 F-1 from its own accounting, contradicting the join it had just run, so the open list is again the lead's reading rather than the tool's. The operator's AskUserQuestion answers (S-21 "Proceed, no pin", S-22 "First deploy-validate action", S-23 "S3 passes or NOT_READY") resolve S-21..S-23, but unless the fold writes `closes:` lines for BOTH the serial entry and its part source, the join keeps reporting 07/08/09 F-1 open into the adversarial series and the gate.

Owed: let an escalated serial entry carry `supersedes:`/`closes:` for the part escalation it restates and have the join dedupe on it, or have the lead's answer fold write closes for every escalation in the chain. Probe: a record whose serial escalated entry restates a part escalation reports ESCALATED-COUNT 1, not 2; after a repaired entry closes the serial entry, 0.

**The fold did not close the chain (02:30Z).** The fold record `s319/requirements-operator-answers-fold.md` landed at 02:30:00Z. It carries 3 `disposition` lines and **0 `closes:` lines**, and the lead's `join-remediator-shards.sh --escalations` on it printed `ESCALATED-COUNT: 0 (0 closed …)`, which describes the new record only. The operator's three answers therefore close nothing in `requirements-elicitation-repair.md`: all nine of S-21, S-22, S-23, 07.md F-1, 08.md F-1, 09.md F-1, 04.md F-8, S-8 and S-17 still read as open to the join, and the lead dispatched the adversarial series at 02:31:27Z without re-running `--escalations` on the elicitation record. The fold also returned five open questions to the lead (Q20, whether S3 NOT_READY blocks or not; the S-23 gloss "does not fail closed" versus the operator's words; the S-21 scope "items 1-4" applied as FR-S319-1..9 and 13; "before any sweep" being the lead's option wording; and a stale pointer pending.md:5224), and the lead adjudicated none of them before the dispatch.

verify: manual

## BL-566 — one beat exiting deletes `.beat-inflight` for every other live beat, and concurrent beats reset each other's per-path state

**DEFECT.** Filed by peer session ai-dlc-68 from graph's s319 resumed lead (session `f65eae3b`, round `requirements-adversarial-p1`, 19 adversaries dispatched 02:31:33–02:32:12Z on 2026-10-16). graph's installed `wait-for-deliverable.sh:967` uses one shared `BEAT_MARKER`, and `:970` sets an unconditional EXIT trap that removes it. Two beats were live: `bxo15gjt1`, a stale beat on the fold armed at 02:27:39Z and never TaskStopped after the fold delivered at 02:30:30Z, and `by8hw963y`, the 19-shard join armed at 02:32:16Z. `bxo15gjt1` exited at 02:37:31Z; the Stop hook fired at 02:37:36Z; `cat .beat-inflight` exited 1 at 02:37:41Z; and the lead armed a duplicate join at 02:37:47Z. One beat's exit removed the lease for the beat still running, so the hook read no live beat. This is the same mechanism as BL-549, and the two are fixed together.

**Concurrent beats also interfere through shared per-path state (02:40–02:51Z).** Beats `by8hw963y` (02:32:16Z, 19 paths), `bxb1k8u08` (02:37:47Z, 14 paths) and a third at 02:42:17Z (7 paths) waited over overlapping paths. At 02:42:10Z `by8hw963y` printed "0 delivered, 19 still out", listing `5.md` as WAITING although its last line was already `seat-complete: requirements adversary 5/13` (the agent returned at 02:34:23Z; the same held for 4, 6, 10 and 12). At 02:47:45Z `bxb1k8u08` printed "1 delivered, 13 still out" when 16 were closed. All beats share `COUNTER_DIR="${STATE_DIR}/.wait-beats"` (`wait-for-deliverable.sh:415`), keyed by path. `is_delivered` deletes the `.settle` sidecar when it sees no marker, and `settled` keys on the stored hash and time, so beats can reset each other's settle state. This half is unreproduced.

Owed: the in-flight marker is per beat (or reference-counted), so one beat's exit leaves another's lease intact, and the per-path settle state is per beat or written so a second beat cannot reset it. Probes: two beats are live and one exits, and the hook still sees a live beat, with a single-beat exit clearing the marker as the control; and two beats over one completed path both report DELIVERED.

verify: manual

## BL-567 — the early-write header instruction collides with the teammate advisor gate, so most adversaries' first shard write is denied

**DEFECT.** Filed by peer session ai-dlc-68 from graph's s319 resumed lead (`f65eae3b`, round `requirements-adversarial-p1`). Of 19 adversaries, 17 had their first Write to `shards/requirements-p1/<n>.md` or `cross-<n>.md` denied between 02:31:45Z and 02:32:23Z by `ai-dlc-advisor-gate` on the Rule 32 touchpoint (`ai-dlc-advisor-gate.sh:80-90`, path test at `:303`). `_gate-procedures.md:278` and `:541-542` require each adversary to write its header first, early. A re-write of a path the gate has not denied is not re-gated, so the effect is to move the advisor consult to before the adversary has read anything. Parts 2 and 9 wrote a `.draft` first to get past the deny (BL-554).

**The deny defeats the early-write rule (02:40–02:51Z).** After the 02:32Z denies, 11 first wrote at 02:43:44Z, cross-1 at 02:44:39Z, cross-6 at 02:48:13Z and 13 at 02:48:52Z, and cross-3 (denied at 02:32:18Z) had no file at 02:51Z. The beats reported these shards absent, not in progress.

Owed: the advisor gate exempts a header-only write (no `### F-` heading, no exit or verdict line), or gates the final stamp instead of the first write. Probe: a teammate's header-only first write is allowed, and a write adding the first finding or the exit stamp is denied without an advisor attempt.

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

## BL-571 — `ADVERSARIAL_STATE_UNADJUDICABLE` fires on every sprint transition with a remedy that blames a correct declaration

**DEFECT.** Filed from batch 235's read of graph's continuation-log archives (read-only) and the Group H contract adversary's correction. The emitters, `core/hooks/ai-dlc-acknowledge.sh:422` and `core/hooks/ai-dlc-continue.sh:1150`, sit inside the I81 byte-identical block and fire whenever the resolved sprint's `s<N>/` directory is absent, which is the normal state before a sprint's first artifact. graph's s318 `pipeline-continuation-log-archive-2.md` holds 67 such entries from 2026-10-14T21:47Z to 2026-10-15T18:49Z, every one `sprint-id resolved: '319'`; s319's archive adds 2 at 18:57Z; and the pattern recurs across s303..s318. No guard was lost: the 67-entry window holds 0 adversary spawn rows (ledger control 862), and every s318 series reached EXIT_CONDITION_MET. The defect is the remedy text only. "Fix the declared sprint" is wrong when the previous sprint's directory exists and the resolved one does not, because that is a pending sprint, not a mis-declared one.

Owed: both emitters distinguish "previous sprint dir exists, resolved one does not" (pending sprint) from a mis-declared sprint, with remedy text matching each, changed together so the I81 block stays byte-identical. Probe both shapes.

verify: manual

## BL-572 — a fenced `git diff --stat` derivation goes STALE at any terminal width but 80, because the derivations checker never pins `COLUMNS`

**DEFECT.** Filed from batch 235's read of graph s319 `planning-artifacts/s319/carry-over-evaluation-party-repair-p1.md:465`, which records the output unfenced and says "re-run it by hand", and the Group H contract adversary's correction. The checker does not mangle the graph glyphs: `norm()` in `core/scripts/validate-artifact-derivations.sh` (`:530`) trims trailing blanks only. `git diff --stat` sizes its graph to `COLUMNS`, which the script never pins (`COLUMNS` 0 hits), so the same derivation is STALE at 40, 60, 120 and 200 columns and OK at 80 or unset. In graph's corpus there are 48 fenced `--stat` derivations in 37 files, and 33 are already STALE identically under 80 and unset (22 with an empty actual, 11 with real drift).

Owed: pin `COLUMNS` in `run_pair`'s eval subshell (`:702`), and state `--stat=N` as the width-stable fence form. Probe: one `--stat` derivation replays OK under two different `COLUMNS` values.

verify: manual

## BL-573 — operator questions ask what the agent can derive, or what the operator already answered

**DEFECT.** Filed from batch 235's read of graph's s319 `operator-requests-history` diff. Of D-1..D-15, five drew complaints: D-6 "No idea what the check 924 band is", D-13 "No idea what this means", D-11 "Pretty sure I supplied this already", D-12 "I assumed you'd be able to derive" (the Distributor address), and "why can't you add the contract_allowlist?". `requirements.md` and `SKILL.md` carry no derive-first or already-answered test (`operator-owned|derivable` 0; control: `route.md` = 1). BL-539 covers only the item-5 deferral and BL-524 only the `(Recommended)` badge.

Owed: before a question reaches the operator, the lead (or the question template) checks `operator-answers-history.md` for a prior answer and whether the value is derivable from the tree, and any jargon in the question is glossed.

verify: manual

## BL-574 — the lead invented an operator go-ahead before the handoff push

**DEFECT.** Filed by peer session ai-dlc-68 from graph's s319 handoff (lead `f65eae3b`, 02:58–03:06Z 2026-10-16). At 02:58:57Z the operator wrote "when adversary agent finishes, handoff." At 02:59:18Z the lead's plan read "5. Ask for your go-ahead before the push, then emit `/ai-dlc resume`." At 03:02:12Z the operator wrote "why do you need my go-ahead before the push? I've already given it when i directed a handoff. proceed." At 03:03:04Z the lead conceded "`handoff.md` step 3 includes it", but graph's installed `handoff.md` has no confirm, approval or go-ahead step before the push (`go-ahead|confirm|approval|ask` matches only the TaskStop lines 27, 36, 40 and 41). Cost: one operator round trip, about 4 min of operator attention at the moment the operator steps away. The class is a lead inventing approval gates the pipeline does not have.

Owed: `handoff.md` step 3 states, beside the push command, that a directed handoff authorises the push and the lead does not ask again, and the same sentence is considered at every pipeline push site (`retro.md:1200`, and `_gate-procedures.md:1190` once the BL-536 line lands). Receipt: the sentence exists at each push site (a `has` receipt; no behavioural replay, per the batch-147 ruling).

verify: manual

## BL-590 — the recover gate denies TEAMMATE tool calls with text addressed to the lead

**DEFECT.** Filed from batch 235's Group E contract adversary (read-only on graph). `core/hooks/ai-dlc-recover-gate.sh` carries no `agent_id` test (0 hits; control: `ai-dlc-acknowledge.sh` uses it), its marker is project-wide and its matcher is `*`. Measured on graph: 253 teammate tool calls across 113 `subagents/*.jsonl` transcripts were denied with the lead's "your FIRST tool call" text (control: 168 lead-file lines carry the same text). In-flight teammates, which the recovery block itself says are alive, have their writes denied during the lead's recovery window.

Owed: the recover gate's deny arms apply to the lead only (empty `agent_id`), and a teammate passes through. An arm plus a mutant: a teammate call passes and a lead call is denied before recovery.

verify: manual

