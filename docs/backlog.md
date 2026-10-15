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

## BL-532 — the remediator-shard join could not join a party repair after one section's remediator was re-run

**DEFECT.** Discharges `PC-S319-JOIN-REFUSES-A-SINGLE-SECTION-RERUN-IN-DOCUMENT-MODE`.

Filed by graph on 2026-10-15 from the Sprint 319 carry-over-evaluation party repair
(`carry-over-evaluation-party-repair-p1`, six section copies), in its working-tree
`_bmad-output/ai-dlc-update/push-candidate-ledger.md` section "S319 party repair: two push candidates".
Subject: `core/scripts/join-remediator-shards.sh`, which took ONE `--since/--until` window. When one
part's remediator is re-run after the others finished, no single window joins. A narrow window
starting at the re-run reads every other part UNWRITTEN. The contract adversary reproduced this on a
read-only copy of graph's corpus at bfb5589e, where the shipped join equals graph's installed copy by
`cmp`: exit 2, five UNWRITTEN (1, 3, 4, 5, 6). A wide window gives `sections/2.md` three writers:
the re-run, the original remediator `a51ac04becc00c152` and the orphan `ad67234a336bc2239`. The
operator-approved "re-run section 2 only" was therefore unjoinable, and graph hand-assembled the record
with a disclosure.

**One incident, two entries.** The orphan row of BL-533 caused the first refusal, and that refusal
forced the section-2 re-run that this entry's join could not take. The two are separable: the orphan's
row (19:27:46Z) falls before any re-run start after it, so the narrowing drops it, and this entry's
receipt does not depend on BL-533's fix.

Fix: `--rerun <part>.md@<S_P>`, repeatable, in files, `--document` and `--subject` modes, and refused
with `--sources`/`--escalations`. Only rows on the files that part cites, timestamped before S_P, are
dropped. Their writers are that part's superseded writers, and every existing arm runs unchanged on
the remaining rows. Three new refusals apply: a superseded writer that also wrote outside the part's
files, a superseded writer still writing at or after S_P, and a re-run writer that is one of the
writers it supersedes (the re-run is a NEW dispatch). The record keeps the outer window and adds one
`rerun:` line naming each superseded writer. Remedy (b), skipping a part whose sha matches an earlier
cleared window, was ruled unconstructible: a refused join writes nothing, the section copies are
removed at assembly, and the ledger carries no sha.

**Residual, stated.** Bytes a genuine earlier writer wrote to the re-run part's file before S_P stay
in the file. They are covered only by the re-run part's own prose account of the whole section diff
against the split slice, which `_gate-procedures.md` "After a join refusal" item 1b requires of the
re-run's brief. No program checks that account.

Carrier: `_gate-procedures.md` item 1b (the trigger now also names the two-writer refusal; a NEW
dispatch; the whole-diff account; how the lead picks S_P), plus a `--rerun` sentence in the document
and subject "Join and assemble" steps. `core/fixtures/process-rule-pins/run.sh` pins the seven new
sentences (rows `gp-rerun-*`), and deleting any one fails only its own row.

The receipt runs the REAL hook, splitter and join on a seeded three-section document. With section 2
written before and after S_P by two agents, it requires the following. The no-flag join refuses with
the two-writer line. `--rerun 2.md@S_P` joins and records the superseded writer. A superseded writer
that is section 3's sole writer is refused as writing outside the part's files. A re-run writer equal
to the original is refused under the NEW-ID rule.

verify: sh J=core/scripts/join-remediator-shards.sh; H=core/hooks/ai-dlc-gate-remediation-guard.sh; P=core/scripts/partition-document.sh; [ -f "$J" ] && [ -f "$H" ] && [ -f "$P" ] && command -v jq >/dev/null || exit 9; D=_bmad-output/planning-artifacts/prd.md; X=_bmad-output/planning-artifacts/s9/shards/prd-repair-p1; L=_bmad-output/planning-artifacts/.artifact-writes.jsonl; Q=2026-01-01T00:00; w() { r="$(mktemp -d)" && r="$(cd "$r" && pwd -P)" || exit 9; n=0; mkdir -p "$r/_bmad-output/planning-artifacts/s9/shards" "$r/_bmad-output/gate-adjudication" || exit 9; : > "$r/_bmad-output/pipeline-snapshot.md"; printf '# PRD\n\n## Goals\nGoal one.\nGoal two.\n\n## Scope\nScope one.\nScope two.\n\n## Risks\nRisk one.\nRisk two.\n' > "$r/$D"; bash "$P" --split "$r/$D" "$r/$X" >/dev/null 2>&1 && [ -f "$r/$X/sections/3.md" ] || exit 9; for i in 1 2 3; do printf -- '- **disposition:** repaired\n- **edit:** `%s/sections/%s.md:2`\n- **siblings:** n/a (section shard; re-checked by the serial remediator after assembly)\n- **derivation:** the section %s finding, edited in its copy\n' "$X" "$i" "$i" > "$r/$X/$i.md"; done; }; e() { printf 'edit by %s\n' "$2" >> "$r/$X/sections/$1.md"; jq -nc --arg f "$r/$X/sections/$1.md" --arg a "$2" '{session_id:"s",tool_name:"Edit",transcript_path:"",tool_input:{file_path:$f},agent_id:$a}' | CLAUDE_PROJECT_DIR="$r" bash "$H" >/dev/null 2>&1; n=$((n + 1)); }; t() { [ "$(grep -c . "$r/$L")" = "$n" ] || exit 9; jq -c -n --argjson ts "$1" '[inputs] | to_entries[] | .value.ts = $ts[.key] | .value' "$r/$L" > "$r/l.tmp" && mv "$r/l.tmp" "$r/$L" || exit 9; }; j() { AI_DLC_PROJECT_ROOT="$r" bash "$J" --document "$D" "$r/$X" --since "$Q:00Z" --until "$Q:20Z" "$@" 2>&1; }; TS="[\"$Q:01Z\",\"$Q:02Z\",\"$Q:03Z\",\"$Q:10Z\"]"; w; e 1 a16fddf14ea289491; e 2 acd81ddfb7c535037; e 3 a078671394c90dc56; e 2 a5e0c4b21d9f3a870; t "$TS"; o="$(j)"; c=$?; [ "$c" -eq 2 ] && grep -qF "sections/2.md was written by more than one agent in the window" <<<"$o" || exit 1; o="$(j --rerun "2.md@$Q:05Z")"; c=$?; [ "$c" -eq 0 ] || exit 1; grep -qF "rerun: 2.md since $Q:05Z; superseded on $X/sections/2.md: acd81ddfb7c535037 (1 rows, $Q:02Z..$Q:02Z)" "$r/_bmad-output/planning-artifacts/s9/prd-repair-p1.md" || exit 1; w; e 1 a16fddf14ea289491; e 2 a078671394c90dc56; e 3 a078671394c90dc56; e 2 a5e0c4b21d9f3a870; t "$TS"; o="$(j --rerun "2.md@$Q:05Z")"; c=$?; [ "$c" -eq 2 ] && grep -qF "outside the files 2.md cites" <<<"$o" || exit 1; w; e 1 a16fddf14ea289491; e 2 acd81ddfb7c535037; e 3 a078671394c90dc56; e 2 acd81ddfb7c535037; t "$TS"; o="$(j --rerun "2.md@$Q:05Z")"; c=$?; [ "$c" -eq 2 ] && grep -qF "must not be one of the writers it supersedes" <<<"$o" || exit 1; exit 0

## BL-533 — the write ledger recorded no evidence that could tell an alias row from a second writer

**DEFECT.** Discharges `PC-S319-LEDGER-ATTRIBUTES-AN-EDIT-TO-AN-AGENT-ID-WITH-NO-TRANSCRIPT`.

Filed by graph on 2026-10-15 from the same Sprint 319 carry-over-evaluation party repair as BL-532.
Ledger row `{ts 19:27:46Z, agent_id ad67234a336bc2239, tool Edit}` on `sections/2.md` sits between
remediator `a51ac04becc00c152`'s Edits at 19:27:42Z and 19:27:48Z. That id has no transcript and no
spawn-ledger row, and the remediator has 10 Edit tool_uses for 11 rows. The join counted it as a
second writer and refused. Its identity is UNPROVEN.

**One incident, two entries.** This orphan row caused the first refusal of section 2, and that
refusal forced the re-run that BL-532's join could not take.

Fix, in two halves. First, `core/hooks/ai-dlc-gate-remediation-guard.sh` adds three record-only keys
to both `.artifact-writes.jsonl` and `.verdict-writes.jsonl` rows, written even when empty, with
`v: 1` kept: `tool_use_id`, `transcript_path` (the PARENT session's, never an identity on its own)
and `agent_transcript`. Second, `join-remediator-shards.sh` reads a row as another writer's alias only
when all of the following hold. The row has a tool_use_id and the other writer's session. Its agent
has no transcript, both at write time and at join time. The other writer's transcript holds exactly
one jq-parsed assistant `tool_use` with that id, as an Edit, Write or MultiEdit on the same file. Its
agent has no other row in the file set. A shared transcript_path is never evidence. An unresolved
row still refuses, naming its tool_use_id, whether its agent's transcript exists, and which
transcript holds the id. Rows without the keys are judged as before.

**Orphan class and efficacy.** Since 2026-10-01, graph's ledger holds 18 ids (26 rows) with no
transcript, out of 1095 ids. Of these, 5 sit within 6s of another agent's Edit on the same file, and
13 have no such neighbour, so no alias rule can clear those 13. This fix's efficacy on the real
19:27:46Z row is UNPROVEN, because that row was written before the hook recorded a tool_use_id. The
receipt is synthetic. It does not show that the S319 join would have succeeded under this fix, and
no such claim is made.

The receipt drives the REAL hook with payloads carrying `tool_use_id` and `transcript_path`, then
runs the REAL join. The ledger must record the payload's tool_use_id. A row whose id sits in the
other writer's transcript as an assistant Edit on the same file joins as one alias. The row refuses
naming its tool_use_id when any one of these holds: the id appears only inside a `tool_result`; the
row's agent has its own transcript at join time; that transcript existed at write time and was
moved away; no transcript holds the id; or the holding tool_use edits a different file.

verify: sh J=core/scripts/join-remediator-shards.sh; H=core/hooks/ai-dlc-gate-remediation-guard.sh; [ -f "$J" ] && [ -f "$H" ] && command -v jq >/dev/null || exit 9; S=_bmad-output/planning-artifacts/s9; L=_bmad-output/planning-artifacts/.artifact-writes.jsonl; B=a16fddf14ea289491; A=ad67234a336bc2239; C=acd81ddfb7c535037; w() { r="$(mktemp -d)" && r="$(cd "$r" && pwd -P)" || exit 9; T="$r/p/s1/subagents"; mkdir -p "$r/$S/stories" "$r/$S/shards/stories-repair-p1" "$T" || exit 9; : > "$r/_bmad-output/pipeline-snapshot.md"; echo x > "$r/$S/stories/a.md"; echo y > "$r/$S/stories/b.md"; for i in 1:a 2:b; do printf -- '- **disposition:** repaired\n- **edit:** `%s/stories/%s.md:1`\n- **siblings:** n/a (insertion)\n- **derivation:** n/a\n' "$S" "${i#*:}" > "$r/$S/shards/stories-repair-p1/${i%:*}.md"; done; }; d() { jq -nc --arg f "$r/$S/stories/$1.md" --arg a "$2" --arg u "$3" --arg t "$r/p/s1.jsonl" '{session_id:"s1",tool_name:"Edit",transcript_path:$t,tool_use_id:$u,tool_input:{file_path:$f},agent_id:$a}' | CLAUDE_PROJECT_DIR="$r" bash "$H" >/dev/null 2>&1; }; u() { jq -nc --arg u "$3" --arg f "$r/$S/stories/$2.md" '{type:"assistant",message:{content:[{type:"tool_use",id:$u,name:"Edit",input:{file_path:$f}}]}}' >> "$T/agent-$1.jsonl"; }; v() { jq -nc --arg u "$2" '{type:"user",message:{content:[{type:"tool_result",tool_use_id:$u,content:("edited; " + $u)}]}}' >> "$T/agent-$1.jsonl"; }; x() { d a "$B" toolu_B1; d a "$A" toolu_X; d b "$C" toolu_C1; [ "$(grep -c . "$r/$L")" = 3 ] || exit 9; }; j() { AI_DLC_PROJECT_ROOT="$r" bash "$J" --sprint 9 --artifact stories --pass 1 --artifact-path "$S" --since 2000-01-01T00:00:00Z --until 2999-01-01T00:00:00Z 2>&1; }; w; u "$B" a toolu_B1; u "$B" a toolu_X; u "$C" b toolu_C1; x; [ "$(jq -r --arg a "$A" 'select(.agent_id == $a) | .tool_use_id' "$r/$L")" = toolu_X ] || exit 1; o="$(j)"; c=$?; [ "$c" -eq 0 ] && grep -qF "1 alias rows" <<<"$o" && grep -qF "alias: $A's row on $S/stories/a.md" "$r/$S/stories-repair-p1.md" || exit 1; w; u "$B" a toolu_B1; v "$B" toolu_X; u "$C" b toolu_C1; x; o="$(j)"; c=$?; [ "$c" -eq 2 ] && grep -qF "is not an alias of another writer (tool_use_id toolu_X;" <<<"$o" || exit 1; w; u "$B" a toolu_B1; u "$B" a toolu_X; u "$C" b toolu_C1; x; : > "$T/agent-$A.jsonl"; o="$(j)"; c=$?; [ "$c" -eq 2 ] && grep -qF "is not an alias of another writer (tool_use_id toolu_X;" <<<"$o" || exit 1; w; u "$B" a toolu_B1; u "$B" a toolu_X; u "$C" b toolu_C1; : > "$T/agent-$A.jsonl"; x; mv "$T/agent-$A.jsonl" "$r/p/moved.jsonl" || exit 9; o="$(j)"; c=$?; [ "$c" -eq 2 ] && grep -qF "is not an alias of another writer (tool_use_id toolu_X;" <<<"$o" || exit 1; w; u "$B" a toolu_B1; u "$C" b toolu_C1; x; o="$(j)"; c=$?; [ "$c" -eq 2 ] && grep -qF "is not an alias of another writer (tool_use_id toolu_X;" <<<"$o" || exit 1; w; u "$B" a toolu_B1; u "$B" b toolu_X; u "$C" b toolu_C1; x; o="$(j)"; c=$?; [ "$c" -eq 2 ] && grep -qF "is not an alias of another writer (tool_use_id toolu_X;" <<<"$o" || exit 1; exit 0

## BL-537 — a spawn made by a teammate is recorded nowhere, so a second writer or reviewer has no provenance

**DEFECT.** In graph s319 the `pm-escalated` requirements authoring agent (`a1c69096c184098d6`, dispatched by the lead at 22:01Z) spawned a `general-purpose` subagent itself, "PRD rubric walker S319" (`afe532cc5f05cad9d`, 22:14:55–22:16:40Z), which wrote `_bmad-output/planning-artifacts/s319/prd-validate/review-rubric.md`. That spawn is required by the skill the step invokes: `requirements.md:178` runs `/bmad-prd` validate, and `.claude/skills/bmad-prd/SKILL.md:73-75` tells it to dispatch its rubric walker and reviewers as parallel subagents. `_bmad-output/spawn-ledger.jsonl` has 0 rows for it, against 1 row in `subagent-context.jsonl` (the post-completion probe), so the dispatch-time record misses it while the completion record sees it. `ai-dlc-dispatch-guard.sh` writes the ledger row at dispatch (append at line 1120). Why this call left no row was not traced: it is a teammate-issued call (`agent_id` set) for a role with no `core/team-roles/` file.

This is the same class as the consumer's `PC-S319-LEDGER-ATTRIBUTES-AN-EDIT-TO-AN-AGENT-ID-WITH-NO-TRANSCRIPT`: there, one `.artifact-writes.jsonl` row on `sections/2.md` carries agent id `ad67234a336bc2239`, which has no transcript, no spawn-ledger row and no tool call in its parent remediator's transcript, and the join refused the shard as two writers. Both cases leave a write by an agent the pipeline has no dispatch record for. Check 22 and every join that counts writers read the spawn ledger, so a nested spawn is invisible to them.

Owed: either a teammate's `Agent`/`Task` call is recorded in the spawn ledger with its parent `agent_id`, so a join can attribute a nested writer to its dispatcher, or teammate spawns are refused and any skill that a step invokes and that dispatches subagents (`bmad-prd` validate is one) is told to run its reviewers sequentially, which `SKILL.md:75` already allows ("If subagents are unavailable, run sequentially"). A probe drives one teammate-issued spawn and asserts the record.

verify: manual

## BL-538 — the lead takes a full turn for every agent notification while an armed join already covers it

**DEFECT (efficiency).** In graph s319 lead session `62eadbbe-59c3-436d-bf7c-931ebc09ecba`, measured at 22:47Z: 109 `<task-notification>` wakes, of which 61 ended with no tool call and only a restatement that the join was still armed ("X delivered … the join beat is still armed, so I'm waiting"). Each such turn re-reads the lead's whole context. That context ran 250–320K tokens (the sensor fired yellow at 252,985 and the snapshot records red readings of 317,305 and 324,185), and by 21:37Z the session had already spent 61 M tokens of lead cache read over 272 API calls. The waits it restates are `wait-for-deliverable.sh --complete` beats over the whole round, which return on their own. Core says what a notification MEANS for the cap-release rule (`rule-28.md:195`) but nowhere what the lead should DO with one that arrives while a beat covers that agent's deliverable. The analysis this backlog is filed from ranks lead waiting among the largest costs (`docs/analysis/pipeline-efficiency-s317-s318.md`, headline and "Relation to the v0.380.0 investigation").

Owed: a stated lead response to a notification for an agent whose deliverable an armed beat covers: no per-agent status line, no re-check, end the turn. Optionally, a hook that injects that instruction when the notified agent's deliverable is inside `.beat-inflight`'s path set. Measure it by re-running the per-wake count on the next consumer sprint.

verify: manual
