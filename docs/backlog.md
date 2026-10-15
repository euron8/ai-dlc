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



## BL-528 — the remediator-shard join could not join a party repair after one section's remediator was re-run

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

**One incident, two entries.** The orphan row of BL-529 caused the first refusal, and that refusal
forced the section-2 re-run that this entry's join could not take. The two are separable: the orphan's
row (19:27:46Z) falls before any re-run start after it, so the narrowing drops it, and this entry's
receipt does not depend on BL-529's fix.

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

## BL-529 — the write ledger recorded no evidence that could tell an alias row from a second writer

**DEFECT.** Discharges `PC-S319-LEDGER-ATTRIBUTES-AN-EDIT-TO-AN-AGENT-ID-WITH-NO-TRANSCRIPT`.

Filed by graph on 2026-10-15 from the same Sprint 319 carry-over-evaluation party repair as BL-528.
Ledger row `{ts 19:27:46Z, agent_id ad67234a336bc2239, tool Edit}` on `sections/2.md` sits between
remediator `a51ac04becc00c152`'s Edits at 19:27:42Z and 19:27:48Z. That id has no transcript and no
spawn-ledger row, and the remediator has 10 Edit tool_uses for 11 rows. The join counted it as a
second writer and refused. Its identity is UNPROVEN.

**One incident, two entries.** This orphan row caused the first refusal of section 2, and that
refusal forced the re-run that BL-528's join could not take.

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
