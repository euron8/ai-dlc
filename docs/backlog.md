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

## BL-528 — the snapshot future-stamp check does not run when a step writes the snapshot

**DEFECT.** Reopens the delivery half of BL-517 (landed v0.783.0). On 0.789.0 the s319 lead wrote
Recent Activity entries stamped `21:50Z`, `21:55Z` and `22:10Z` starting at about 21:28Z. Lead
snapshot Edits carrying those stamps were sent at 21:28:01, 21:30:14, 21:33:49 and 21:38:37, and
none was refused or warned. The stamps were found only when the lead ran
`validate-artifact-budget.sh` by hand at 21:39:57, and corrected by a `CLOCK CORRECTION` line
(graph `_bmad-output/pipeline-snapshot.md:30`).

BL-517's close text says the arm runs at every write. It runs where `check_future_stamps`
is called (`core/scripts/validate-artifact-budget.sh:1709`): gate Check 14 and route Step 0a. The
step-level procedure that writes the snapshot most often, `_gate-procedures.md` "Sub-step snapshot
update" (lines 16-45), never names the validator. None of graph's `Edit|Write|MultiEdit` hooks
(`derivation-capture`, `core-guard`, `gate-remediation-guard`, `artifact-path-guard`,
`advisor-gate`, `acknowledge`) runs it. The BL-517 probe drives the validator through `verdict.sh`
over a seeded root (`probes/bl-517-future-stamp.sh:77`), so it proves the check and not any trigger.

Owed: a write-time carrier for the future-stamp verdict on `pipeline-snapshot.md`, so a future stamp
is refused or flagged at the write that creates it, plus a receipt that drives that trigger.

**Second half (measured 2026-10-15T21:54Z, graph s319 planning gate).** The future-stamp arm also refuses a CORRECT future value. The lead recorded an operator-set monitor deadline, `2026-10-21T16:08:54Z` (Stories 2.6/2.7 staleness ceiling, 7 days from deploy), in a Recent Activity line. `verdict.sh validate-artifact-budget --only pipeline-snapshot.md` returned rc=1 with `FUTURE _bmad-output/pipeline-snapshot.md line 30: 2026-10-21T16:08:54Z is 8294 min ahead of now (Recent Activity)`, and its remedy text says to rewrite the stamp to `date -u` without asking. That would have overwritten an operator ruling with the current time. Instead the lead ran `sed -i '' 's/2026-10-21T16:08:54Z/21 Oct 16:08Z/'` on the snapshot, a form `check_future_stamps` does not parse, so the arm passed. The workaround is also a BL-530 instance: a Bash in-place write with no ledger row. The arm cannot tell an entry's own stamp (the leading `- <ISO>` that must not be in the future) from a future date the entry RECORDS. Owed besides the write-time carrier: the arm keys on the entry's leading stamp only, or the snapshot grammar gives a recorded deadline a form the arm exempts. A probe should show both that a future leading stamp still fails and that a recorded future deadline passes.

verify: manual

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

## BL-534 — the scope validator refused a routing-record cite copied with its `SHA256:` label

**DEFECT.** Discharges `PC-S319-ROUTING-RECORD-CITE-PREFIX-REJECTED-BY-SCOPE-VALIDATOR`.

Filed by graph on 2026-10-15 from Sprint 319, in its working-tree
`_bmad-output/ai-dlc-update/push-candidate-ledger.md`. The filing is uncommitted there.
`route.md` Step 6 named both routing-record cites as "the `SHA256:` value" of the capture hook's
`- SHA256: <hex>` line, and leads copied the label in with the hex. `validate-scope-confirmation.sh`
then refused `scope_confirmed_cite: SHA256:<hex>` at its hex arm, though the bare hex resolves.
`validate-request-coverage.sh --cite-sha SHA256:<hex>` exited 2 for the same reason.

**Census.** graph has 545 pipeline-snapshot commits. `scope_confirmed_cite` carried the prefix in 3
of them, all in s306. `user_request_cite` carried it in 22, across s302, s306, s316 and s317. The
commits hold 5 distinct prefixed values, and every one resolves to a capture entry once the label is
removed. FP set: 0, meaning no prefixed value that fails to resolve bare.

**The s306 rewrite.** In s306 the routing record, which graph's snapshot heads "written once,
never rewritten", was rewritten mid-gate. No program detects a rewritten routing record, and this
fix does not add one.

Fix, on both sides. `route.md` now names each value as the 64 hex characters after `- SHA256: `,
copied without the `SHA256:` label. `validate-scope-confirmation.sh` strips exactly one literal
`SHA256:` right after the cite is assigned and before any arm reads it, so the resolve grep and the
deferred-items timestamp join both see the bare hex. `validate-request-coverage.sh` strips the
same single label from `cite_sha`. It also refuses an empty remainder with exit 2, because
`SHA256:` alone would otherwise read as "no pin" and fall through to the newest entry. Neither
validator strips any other label, folds case or strips twice.

Carrier: `core/fixtures/process-rule-pins/run.sh` rows `route-cite-user` and `route-cite-scope`
(contains mode, span `### Step 6:` to `## FAILURE MODES`). The labelled-cite cells and four mutants
are in `core/fixtures/scope-confirmation/run.sh`, and five `--cite-sha` cells beside assertion 9 are
in `core/fixtures/request-coverage/run.sh`.

**NOTE.** `gate-validation.md` lines 1037, 1046 and 3080 still use "the `SHA256:` of" phrasing.
Those lines describe the check and do not instruct the write, so they are harmless. They were not
aligned.

The receipt keys only on the two validators' exit codes, never on stderr or route.md text. It seeds
one answers entry and one request entry. Bare-hex controls must pass on both validators first, or
it exits 9. Then a labelled real cite must pass, and a labelled fabricated hash, a `foo:` label, a
doubled label and `SHA256:` alone must all still fail. A labelled pin against a brief that dropped
the asked id must still exit 1.

verify: sh V=core/scripts/validate-scope-confirmation.sh; C=core/scripts/validate-request-coverage.sh; [ -f "$V" ] && [ -f "$C" ] && command -v shasum >/dev/null && command -v python3 >/dev/null || exit 9; T="$(mktemp -d)" || exit 9; H="$(printf Confirmed | shasum -a 256 | cut -d' ' -f1)"; F=0000000000000000000000000000000000000000000000000000000000000000; Q="$(printf '\140\140\140')"; [ "${#H}" -eq 64 ] || exit 9; printf '# answers\n\n## 2026-10-15T00:00:00Z -- AskUserQuestion\n- SHA256: %s\n%stext\nConfirmed\n%s\n' "$H" "$Q" "$Q" > "$T/a.md"; : > "$T/b.md"; grep -q "^- SHA256: $F\$" "$T/a.md" && exit 9; s() { printf -- '- user_request_verbatim: x\n- scope_confirmed: confirmed\n- scope_confirmed_cite: %s\n- scope_deferred_items: none\n' "$1" > "$T/s.md"; AI_DLC_PROJECT_ROOT="$T" bash "$V" --snapshot "$T/s.md" --answers "$T/a.md" --backlog "$T/b.md" >/dev/null 2>&1; echo $?; }; [ "$(s "$H")" = 0 ] || exit 9; printf '# requests\n\n## 2026-10-15T00:00:00Z -- (typed)\n- Session: s1\n- SHA256: %s\n%stext\nplease do CO-S1-X\n%s\n' "$H" "$Q" "$Q" > "$T/r.md"; printf '# Product Brief\n\n<!-- LOCKED_REQUIREMENTS — DO NOT MODIFY DURING VALIDATION -->\n### LOCKED block: S42\n- **LR-S42-0 (%sCO-S1-X%s):** do it.\n<!-- END LOCKED_REQUIREMENTS -->\n' '`' '`' > "$T/k.md"; sed 's/CO-S1-X/CO-S9-Y/' "$T/k.md" > "$T/d.md"; c() { AI_DLC_PROJECT_ROOT="$T" bash "$C" --requests "$T/r.md" --brief "$T/$2" --sprint 42 --cite-sha "$1" >/dev/null 2>&1; echo $?; }; [ "$(c "$H" k.md)" = 0 ] && [ "$(c "$H" d.md)" = 1 ] || exit 9; [ "$(s "SHA256:$H")" = 0 ] && [ "$(s "SHA256:$F")" = 1 ] && [ "$(s "foo:$H")" = 1 ] && [ "$(s "SHA256:SHA256:$H")" = 1 ] && [ "$(s "SHA256:")" = 1 ] && [ "$(c "SHA256:$H" k.md)" = 0 ] && [ "$(c "SHA256:$F" k.md)" = 2 ] && [ "$(c "foo:$H" k.md)" = 2 ] && [ "$(c "SHA256:" k.md)" = 2 ] && [ "$(c "SHA256:$H" d.md)" = 1 ] || exit 1; exit 0
