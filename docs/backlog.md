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

## BL-465 — the suite-pole guard compares only at pool widths someone hand-calibrated

**DEFECT.** Operator ruling, batch 202. `docs/suite-pole-baseline.tsv` holds rows only for pool widths 12 and 16, and
`scripts/validate-suite-pole.sh` SKIPs at any other width: a push at `AI_DLC_FIXTURE_JOBS=8` printed
`SKIP -- pool width 8 has no baseline row (widths with a row: 12 16)`. The operator's spec: every gated push records its
pole result keyed by the width it ran at, and the guard compares against that width's own recorded history, so any width
the operator uses is covered without hand calibration. A guard that skips at every width nobody calibrated reads exactly
like one that passed.

verify: manual -- close when a gated push at a width with no prior row records one, and the next push at that width compares against it instead of printing SKIP.

## BL-466 — `derive-fixture-readsets.sh --tracer fs_usage` kills every fs_usage on the box after each fixture

**DEFECT.** Measured batch 202. Four `--tracer fs_usage` runs started in parallel, each in its own clone with its own
`AI_DLC_READSET_TRACE_ROOT`, captured 0 bytes in every `.raw` file while their fixtures ran, and `pgrep -x fs_usage` read 0:
after each fixture the deriver runs `pkill -x fs_usage` (`core/scripts/derive-fixture-readsets.sh:1236`, and `:1253` under
`--tracer both`), which kills the other runs' tracers too. The deriver's own comment warns that a killed tracer "looks like
a small read-set, not like a fault", so the rows those runs write are untrustworthy and nothing says so. Kill this run's
own tracer by pid, or refuse to start while another `fs_usage` is live.

verify: sh ! grep -n 'pkill -x fs_usage' core/scripts/derive-fixture-readsets.sh

## BL-470 — the sandbox tracer logs every `bash` check on the tree root, and the stream drops a large fixture's trace

**DEFECT.** Measured batch 203 on `readset-skip`'s sandboxed trace, after `BL-469` let it finish (`PASS (238 assertions)`).
The deriver still OMITTED it: `the stream dropped reports 1384 time(s) in this window`. Of the 4399 Sandbox report lines in
that window's raw capture, **4155 name the trace tree's root directory and nothing below it**, all
`file-test-existence` and `file-read-metadata`; the next most-reported path has 71. The profile reports everything under
`(subpath TREE)`, which includes the root itself, so every `bash` path-existence and `cd` check a fixture makes on the tree
root costs a report line and carries no read-set information. The operator's own trace of the same fixture showed about
500 drop notices before it aborted. **It is not one fixture.** `self-update-fixture-log-mutants`, traced alone in a clean
clone of `6f73066d`, was OMITTED on 115 drops; 34685 of its 58568 report lines name the tree root alone, against 2600 for
the next path (`.git`). The 0.742.0 re-trace on the release tree added two more, OMITTED on drops: `self-update-gate`
(1007) and `procsub-staged-refusal-boot` (1657). All four stay unmapped, so all four run on every push, until this
lands. Remedy: stop reporting operations whose path is the tree root alone (exclude
`(literal TREE)` from the reporting clause, or drop those lines before the drop count is judged), keeping any
`file-read-data` on the root, which is a directory listing and IS a read. Re-trace all four after; all four must read
MAPPED.

verify: manual -- close when `bash core/scripts/derive-fixture-readsets.sh --list "readset-skip self-update-fixture-log-mutants self-update-gate procsub-staged-refusal-boot" --tracer sandbox` in a scratch clone reports all four MAPPED with zero drop notices.

## BL-471 — a fresh committed trace cannot clear a stale key record, so a stale fixture runs on every push

**DEFECT.** Operator ruling, batch 203. Once the pre-push hook reruns a fixture because a file in its key record
changed, it records that fixture `#state stale` under `$GITDIR/ai-dlc-fixture-keys/` (`.githooks/pre-push:1017`), and a
stale record runs the fixture on every later push. The ONLY thing that clears it is a valid row in the LOCAL map,
`$GITDIR/ai-dlc-fixture-readsets.local` (`:1016`), which only the hook's own detached post-green trace writes
(`:1115-1120`). A committed `.ai-dlc-fixture-readsets.tsv` row that postdates the stale stamp does not clear it, and the
post-green trace is skipped on any push from a linked worktree. Measured batch 203: the 0.741.1 push (from a worktree)
staled 45 records at 06:50; the operator's complete sandbox trace then committed fresh rows for all 45; the 0.742.0 push
still read `read-set keys: 99 of 246 fixture(s) run (54 changed, 0 unrecorded, 45 stale)`. Only 5 of the 45 had a local
row, and none was valid. Remedy: a committed row set for a fixture that was derived from the current tree (its paths hash
as `.now` does) clears that fixture's stale state, as a valid local row does today; and say in the hook output, per
stale fixture, what would clear it.

verify: manual -- close when a push run after a committed trace of a stale fixture, with no local row for it, reports that fixture as skipped (or as run for a reason other than `stale`), and a fixture whose committed rows predate the change still reads `stale`.

## BL-472 — `derive-fixture-readsets.sh --reconcile`: derive the stale and missing set and trace only that

**DEFECT.** Operator request, batch 203. Today the operator must work out by hand which fixtures need a trace and pass
them to `--list`, or run `--all`. Add `--reconcile`: the deriver builds its own list from (a) every fixture directory with
a `run.sh` and no row in the committed map, (b) every fixture whose key record under `$GITDIR/ai-dlc-fixture-keys/` reads
`#state stale`, and (c) every mapped fixture with a recorded path whose content changed since that row set was taken. It
prints the list with one reason per fixture before tracing, traces exactly that list as `--list` would, and exits 0 with
"nothing to reconcile" on an empty list. Pairs with `BL-471`, which lets the committed trace this produces clear a stale
key record; build them together.

verify: manual -- close when `--reconcile` on a tree with one unmapped, one stale and one changed-input fixture names exactly those three with their reasons and traces only them, and on a fully-mapped clean tree prints "nothing to reconcile" and traces nothing.

## BL-473 — handoff step 1 ends the turn on a wait-beat while Check 0 blocks that Stop

**DEFECT.** Carries the reference consumer's `PC-S317-HANDOFF-STEP-1-ENDS-THE-TURN-ON-A-BEAT-WHILE-CHECK-0-BLOCKS-THE-STOP-ON-IN-FLIGHT-ROWS`.
`core/skills/ai-dlc/steps/handoff.md` step 1 runs ONE backgrounded `wait-for-deliverable.sh` beat over the in-flight rows
and ends the turn on it, in the same step that said Check 0 blocks the stop while any row reads `in-flight`. Check 0 in
`core/hooks/ai-dlc-continue.sh` ran before Check 2b's live-beat allow, and at that Stop every arm is unsatisfied by
construction: no resume block, commit, push or driver signal yet, and the entry marker still present. The block text tells
the lead to stop every teammate, which is the TaskStop the beat exists to avoid; the rapid-fire backoff releases only the
fourth Stop. Observed on the reference consumer's sprint 317: nine TEA seats stopped with no file, all nine re-dispatched
by the successor.

**FIX.** Inside Check 0's unsatisfied branch, after the reason is assembled and before the block, a live `.beat-inflight`
lease (an integer epoch later than now, read by `beat_lease_live`, the one helper Check 2b now also uses) logs
`HANDOFF_GUARD_DEFERRED_BY_LIVE_BEAT` and falls through to Check 1 and Check 2b. It writes no stall counter and keeps
`.handoff-guard-armed`, so the beat's return re-arms the guard. A satisfied handoff with a live lease is still stamped
complete. Limit: a SIGKILLed or unrelated beat's lease defers a Stop with nothing to re-invoke the lead, bounded by the
lease length (3*POLL, about 30s), the same hazard Check 2b carries. Fixtures: `handoff-resume-guard` A1-A6 with mutants
m1, m2, m4, m5 and placement; `implementation-join-yield` arm 8i with mutant m3.

The receipt drives the shipped hook in four worlds, each with a handoff request: three with an `in-flight` row -- a live
lease (must ALLOW and log the deferral), an expired lease and a non-integer lease (each must block with the `HANDOFF GUARD`
reason) -- and one with every arm satisfied under a live lease, which must still be stamped complete, so a deferral placed
before the arm test or at the top of Check 0 fails it. It exits 9 when the hook, its sibling, the schema, jq or mktemp is
missing, or when a world cannot be built.

verify: sh { [ -f core/hooks/ai-dlc-continue.sh ] && [ -f core/hooks/ai-dlc-handoff-pending.sh ] && [ -f core/schemas/pause-routing.json ] && command -v jq >/dev/null; } || exit 9; H="$PWD/core/hooks/ai-dlc-continue.sh"; S="$PWD/core/schemas/pause-routing.json"; T="$(mktemp -d)" && [ -d "$T" ] || exit 9; w() { p="$T/$1"; mkdir -p "$p/_bmad-output/.driver" && printf '# Pipeline Snapshot\n\n## In-Flight Teammates\n| agent | role | deliverable | dispatched-at | status |\n|---|---|---|---|---|\n| tester-a | qa | docs/q.md | 2026-08-25T01:10:00Z | %s |\n' "$3" > "$p/_bmad-output/pipeline-snapshot.md" && touch "$p/_bmad-output/pipeline-paused.flag" && : > "$p/_bmad-output/.driver/handoff" && printf '%s' "$2" > "$p/_bmad-output/.beat-inflight" && jq -nc '{message:{role:"user",content:"hand off the sprint"}}' > "$p/t.jsonl" && jq -nc '{message:{role:"assistant",content:"Snapshot finalized.\n\n----\n/ai-dlc resume\n----\n"}}' >> "$p/t.jsonl" || return 9; jq -nc --arg t "$p/t.jsonl" '{transcript_path:$t,session_id:"rcpt"}' | CLAUDE_PROJECT_DIR="$p" AI_DLC_PAUSE_ROUTING_SCHEMA="$S" bash "$H" > "$p/out" 2>/dev/null; return 0; }; n="$(date +%s)"; w a1 "$((n + 60))" in-flight || exit 9; w a2 "$((n - 1))" in-flight || exit 9; w a3 not-an-epoch in-flight || exit 9; w a6 "$((n + 60))" stopped || exit 9; grep -q '"block"' "$T/a1/out" && exit 1; grep -q 'HANDOFF_GUARD_DEFERRED_BY_LIVE_BEAT' "$T/a1/_bmad-output/pipeline-continuation-log.md" || exit 1; grep -q 'HANDOFF GUARD' "$T/a2/out" || exit 1; grep -q 'HANDOFF GUARD' "$T/a3/out" || exit 1; test -f "$T/a6/_bmad-output/.handoff-complete" || exit 1
