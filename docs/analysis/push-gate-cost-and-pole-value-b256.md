# Push gate cost and pole value, from recorded logs (BL-583, batch 256)

Measured for batch 256, M6, read only, by two hands: m6-583a (the push population, wall clock and
dollars) and m6-583b (the pole value judgment). It answers BL-583's two owed figures, a per-gate wall
clock and a dollar figure from real pushes of this repo, and its value judgment of the non-mutant
poles. No timing run was made: every figure is read from a record an earlier run wrote. Pushes are
named by session id, UTC time and log path. Scratch paths are perishable; they live in the scratchpads
of the sessions named, and the hands' rows are `h583a.xSit/rows.txt` and `h583a.xSit/final.txt` in
session 66c124f2's scratchpad.

## Method

Population: every release `git push` in the ai-dlc session transcripts under
`~/.claude/projects/-Users-n8-git-ai-dlc`, main and subagent files (890 files and 425 Bash uses matching a push, per m6-583a's report; not on
disk). Each is paired to its `tool_result`, its task notification and the log its redirect wrote.
13 uses are excluded, each with its reason (listed in `h583a.xSit/main.out`): 4 prose-only (a push inside a script body), 3 heredoc or
script writers that returned in 2 s or less, 2 denied by a hook, 1 background launch that failed in
0.1 s, 3 scripts that do not push. The candidate filter kept a push segment that is not `--delete`,
`--dry-run` or `--no-verify` and not inside quoted prose, plus script-wrapped background pushes: 80
candidates, 67 kept (the 80 is from m6-583a's report; the 67 and 13 are in `main.out`). Branch-delete pushes are not release pushes and are reported
separately below.

Wall window: from the push's `tool_use` timestamp to the first of these that exists:
- the hook's last line or the push's rc file, by the mtime of the log or rc file (44 pushes);
- the background task's completion notification (20 pushes);
- the foreground `tool_result` timestamp (3 pushes).
These counts are the window-end sources column of `h583a.xSit/final.txt`, the rows file on disk
(perishable). Where a log or rc mtime and a notification both exist they agree within 0.0 to 0.8 s,
per m6-583a's report (not on disk).

Class source, from the `src` field of `h583a.xSit/final.json`: the hook's own log for 45 pushes, a
later read of the push log in the same transcript for 18 (greps of the hook source filtered out), hook
text in the `tool_result` for 2, and for 2 with no hook text, the `.git/ai-dlc-suite-key.log` line
inside the window (one MISS with a notification exit 0, one HIT).

In-session time only: the idle time between a handoff and the next resume is excluded, and no window
here spans one.

Dollars: the pushing transcript's usage records whose timestamp falls inside the window, deduped by
`message.id` (78391 usage lines over 40157 ids, `h583a.xSit/final.txt` line 1; m6-583a reports every
repeated line carrying an identical usage tuple, so first-wins dedup is exact), priced per model id and per token class. Rates in $ per
million tokens:

| Model id | Input | Output | Cache write 5 m | Cache write 1 h | Cache read |
|---|---|---|---|---|---|
| `claude-opus-5-5` | 4.00 | 20.00 | 5.00 | 8.00 | 0.20 |
| `claude-sonnet-5-5` | 2.00 | 10.00 | 2.50 | 4.00 | 0.10 |
| `claude-haiku-5-5` | 0.10 | 0.50 | 0.125 | 0.20 | 0.01 |
| `claude-fable-5-2` | 8.00 | 40.00 | 10.00 | 16.00 | 0.20 |

Source: the claude-api skill's model table as cached 2026-11-03, as the counter's own comment says
(`h583a.xSit/final.py`); the cache-write multipliers (1.25x input at the 5 m TTL, 2x at 1 h) are per
m6-583a's report. Records in the windows: Opus 5.5 240, Fable 5.2
56, Sonnet 5.5 24, all at standard speed (fast mode would be 2x), none unpriced.

## Population: 67 release pushes, 2026-11-09T02:08Z to 2026-11-12T17:37Z

| Class | Pushes | Wall min (s) | Wall median (s) | Wall max (s) | Fixtures run, min / median / max |
|---|---|---|---|---|---|
| green, fixture suite ran | 49 | 81 | 752 | 1998 | 1 / 36 / 81 (n=46) |
| green, whole suite SKIPPED on the suite key | 4 (up to 5) | 76 | 151 | 253 | - |
| green, suite entered, 0 fixtures ran | 6 | 189 | 211 | 349 | 0 |
| red | 8 | 602 | 1398 | 1950 | 23 / 50 / 271 (n=7) |
| all | 67 | 76 | 732 | 1998 | |

The 0-fixtures class: in `final.txt`, session 2b1ab404 (2026-11-12T16:51Z) reads verdict-store skip
54 with read-set 0 of 273, and session fda0ce30 (2026-11-10T13:00Z) reads read-set 0 of 264. Per
m6-583a's report (the banner text is not in the rows files), five of the six carry the banner
"read-set skip found no fixture whose inputs changed" and fda0ce30's carries the older "SKIPPED on an
unchanged content key".

All 8 reds failed inside the fixture suite; 0 pushes went red before it. Limits on that zero: 22
pushes have no hook log of their own (45 do, `final.json` `src`), the suite-key log cannot see a pre-suite red, and the classifier's pre-suite
branch cannot fire on a BLOCKED log. Re-read for this file: 44 of those 45 logs are still on disk, every one of the 44 carries `── `
phase headers, and none of those headers carries a duration, so no per-phase wall clock exists
in the record; the per-gate figure is the whole push.

"Up to 5": `.git/ai-dlc-suite-key.log` holds 75 lines in the population's span, 63 MISS and 12 HIT
(`final.txt`). Each push claims the lines inside its own window; all 63 MISS lines are claimed, and 6
HIT lines are claimed by no push: 2026-11-10T14:37:24Z, 2026-11-11T15:35:47Z, 15:43:29Z, 16:26:01Z,
18:29:33Z and 19:32:49Z. Five of the six are the HITs of branch-delete pushes in the table below, by
their HIT times. Two more delete HITs, 15:26:55Z and 18:57:16Z, fall inside release-push windows (the
pushes starting 2026-11-11T15:26:20Z and 18:51:37Z, whose key-log column reads HIT beside MISS), so a
window's HIT is not always its own. That leaves 15:43:29Z, the same content key as the 15:35:47Z
delete per m6-583a, unattributed; it is the ceiling on missed release pushes.

Controls, per m6-583a's report (not on disk): an impossible token is absent from all 425 commands and
results, and `pre-push:` is present in 33 `tool_result`s.

Unrecoverable range: 0.1028.0 and earlier. The oldest record in the ai-dlc transcripts is
2026-11-09T00:16:40Z, per m6-583a's scan (not on disk). The first main commit after it is 0.1029.0,
committed 2026-11-08T21:46:38-05:00, which is 2026-11-09T02:46Z (re-read with `git log`). The main
checkout's `.git/ai-dlc-suite-key.log` holds 2711 lines before 00:16:40Z, pushes with no transcript
left, out of 2790 when re-read on 2026-11-12.

## Dollars

The pushing transcript's spend inside its push window: median $0.167, max $2.37 (session 0b6a7bbd,
2026-11-12T11:14Z, a red push), sum $17.61 over the 67. The whole session, main plus subagents, in
the same windows: median $0.172, sum $21.73.

This is what the pushing SESSION spent while its push ran. It is not a gate cost: the hook spends no
tokens, and the gate's cost unit is wall seconds.

## The FAIL population

10 FAIL summary lines over 9 fixtures in the 8 red pushes (`final.txt`). Per m6-583a's report (not
on disk), the raw FAIL lines across the surviving logs are 9 `done N/M FAIL <fx>` progress lines, 9
`FAIL  <fx>` summary lines and 7 bare phase-verdict FAILs of the suite phase, with 0 FAILs outside
the fixture suite.

Each is classified by joining it mechanically to the CHANGELOG sections dated in the window that name
the fixture; the push logs themselves were not read for this.

| Fixture | Push (session, start UTC) | Class | Record |
|---|---|---|---|
| `process-rule-pins` | 94d65a60 2026-11-11T14:14Z; 949b78fd 2026-11-11T18:51Z | unknown | the in-window lines are pin additions, 0.1034.0 to 0.1037.0 |
| `mutation-red-replay` | d3170907 2026-11-09T02:08Z | fixture defect | BL-940, 0.1033.0: a host SKIP moved the J3 count. A floor: its log is gone |
| `handoff-completion-assertion` | 94d65a60 2026-11-11T14:14Z | load | 0.1064.0, the BL-868 clock shim |
| `handoff-resume-guard` | bf3ed410 2026-11-11T15:44Z | unknown | no in-window line; the older BL-830 red was fixture-side |
| `procsub-staged-refusal` | bf3ed410 2026-11-11T15:44Z | probably fixture defect | BL-941, 0.1033.0: an en_US.UTF-8 host dependency |
| `validator-fork-budget` | ac41cd6f 2026-11-12T00:32Z | unknown | the in-window lines are cost figures only |
| `prepush-pool-depth` | 83ed1313 2026-11-12T07:43Z | load | BL-985, 0.1077.0; a full 271-fixture run |
| `validator-arm-selection` | 0b6a7bbd 2026-11-12T11:14Z | real subject defect, exposed by timing | 0.1081.0: `i75_norm \| grep -qE` took SIGPIPE in `scripts/validate-enforcement-map.sh`; no other unit recorded |
| `handoff-record-carries-return` | 654184a1 2026-11-12T13:28Z | real, prose | 0.1083.0: new `remediator.md` text collided with an R3 phrase; no other unit recorded |

Of 10, 2 are real catches, 2 load, 1 a fixture defect, 1 probably a fixture defect and 4 unknown.

## The loaded durations top

LOADED costs, from `.git/ai-dlc-fixture-durations` in the main checkout (271 rows against 273
fixture directories; written 2026-11-12T18:46Z, read 19:11Z, sum 23529 s). Each row is the unit's
cost under the pool on its last run and must not be compared with a solo run.

| Rank | Fixture | Loaded s |
|---|---|---|
| 1 | `backlog-receipt-binding` | 1103 |
| 2 | `adversarial-shard-merge` | 978 |
| 3 | `apply-restamp-worklist-b` | 731 |
| 4 | `story-evidence-scaffold` | 699 |
| 5 | `review-shard-merge` | 639 |
| 6 | `ledger-reverify` | 575 |
| 7 | `review-shard-merge-b` | 549 |
| 8 | `apply-drift-refile` | 447 |
| 9 | `remediator-shard-join` | 400 |
| 10 | `apply-restamp-worklist` | 395 |
| 11 | `check-24-adversarial-convergence-d` | 394 |
| 12 | `owed-derivations` | 392 |
| 13 | `readset-skip-d` | 384 |
| 14 | `procsub-staged-refusal-boot-b` | 377 |
| 15 | `wait-beat-liveness` | 354 |

`document-partition`, the pole BL-583 named at 0.842.0, now reads 39 s.

## Pole value

Classification rule. Almost every pole carries self-probe mutants, and BL-583 itself calls
`enforcement-map-sites` and `apply-restamp-worklist-c` non-mutant poles. So a MUTANT battery is a
unit whose verdict IS the kill score. Three say so in their first header line
(`story-evidence-receipts-mutants`, `smoke-surface-ignored-mutants`, `story-evidence-smoke-mutants`).
`backlog-receipt-binding` also qualifies, by its `run.sh` header ("AN UNMUTATED CONTROL PLUS EIGHT
MUTANTS ... Exit 0 iff the control is green AND every mutant is killed"). It is borderline, because
its control and arm j1 can fail alone on the real ledger. Every shard was confirmed by its own
"shard 'x' of" header line. The order is the row walk of the loaded record, longest single directory
first, not family sums. Row 1, `backlog-receipt-binding` at 1103 s, is a mutant battery and is not
judged here.

A catch is a red on record (backlog, archive, CHANGELOG, or an origin/main commit body) where the
fixture failed on a real defect in its subject. A red caused by the fixture itself, by load, or by
the host is listed and not counted.

| # | Family (loaded s) | Guards | Catches on record | Other unit caught it | Verdict |
|---|---|---|---|---|---|
| 1 | `adversarial-shard-merge` (978) | `merge-adversarial-shards.sh`: the merged verdict recomputed from the summed residue | none | - | NO CATCH ON RECORD |
| 2 | `apply-restamp-worklist` (1316: a 395, b 731, c 190) | `apply.sh` must not stamp THEIRS or clear the in-flight marker when it hands work back | 0.545.0: C4 caught the release's own hand-back row firing on every consumer that predates the mechanism; real, pre-ship. Fixture-side: 0.755.0 | none recorded | 1 real catch |
| 3 | `story-evidence-scaffold` (699) | the evidence scaffold, the Strategy Test IDs table and Check 21's reading of it | none on the subject. Fixture-side: BL-558, 0.806.0 (caught by I77, BL-642), BL-942 / 0.1033.0 | - | NO CATCH ON RECORD |
| 4 | `review-shard-merge` (1188: a 639, b 549) | partition and merge of a sharded gate-1 review and gate-2 QA | none on the subject. Fixture-side: BL-882. Load: BL-980, 0.1064.0 | - | NO CATCH ON RECORD |
| 5 | `ledger-reverify` (575) | `reconcile/ledger-reverify.sh` probes theirs, not base | none on the subject. Fixture-side: 0.301.0, BL-827, 0.329.0. Concurrency: BL-283 / 0.616.0 | - | NO CATCH ON RECORD |
| 6 | `apply-drift-refile` (447) | `apply.sh` automates the known_skills drift refile and revert | 0.228.0: the new layer-contract refusal fired on a THEIRS with no declaration; real, pre-ship. Load: 0.206.0, 0.283.0, 0.367.0. Fixture-side: 0.68.1 | `apply-restamp-theirs` red on the same defect | 1 real catch, also caught elsewhere |
| 7 | `remediator-shard-join` (400) | `join-remediator-shards.sh` proves disjoint write sets | 0.668.0: a doubled slash in TMPDIR made the join refuse absolute citations; A1, A3, A4 red at the gate; real, pre-ship. Fixture-side: BL-967 | none recorded | 1 real catch |
| 8 | `check-24-adversarial-convergence` (1104: a 230, b 282, c 198, d 394) | `validate-adversarial-convergence.sh` verdicts, asserted on the message | 0.413.0, case reopen-moved-clean: `--cycle-state` tested CONVERGED before REOPENED; real, pre-ship, during authoring | none recorded | 1 real catch |
| 9 | `owed-derivations` (392) | an owed derivation stays owed until re-pointed (`derivation-differential --record-owed` writes, `check-owed-derivations.sh` reads) | none; BL-652 and BL-668 were found on the consumer, not by this fixture | - | NO CATCH ON RECORD |
| 10 | `readset-skip` (1134: a 316, b 246, c 188, d 384) | the per-fixture read-set skip selects the exact set | none on the subject (0.294.0 is the defect it was written for). Fixture-side: 0.750.0, 0.767.0, 0.770.0, 0.984.0, BL-469. Load: 0.763.0, BL-616, BL-900 / 0.990.0, 0.963.0 | - | NO CATCH ON RECORD |
| 11 | `procsub-staged-refusal-boot` (727: a 116, b 377, c 234) | the four bootstrapping reconcile scripts refuse on a failed producer | none attributed: in 0.939.0 / BL-685 the dress found a `done <<<` here-string in `emit-report.sh` and which unit went red is not recorded. Fixture-side: 0.682.0, 0.777.0 | - | NO CATCH ON RECORD, one unattributed red |
| 12 | `wait-beat-liveness` (354) | the bounded join tells a slow teammate from an idle one | none on the subject. Fixture-side: BL-717 / 0.887.0. Load: 0.862.0, BL-616 | - | NO CATCH ON RECORD |
| 13 | `dispatch-model-guard` (304) | `ai-dlc-dispatch-guard.sh` injects the pinned model tier | no field red; 0.482.0 scored it against the pre-fix readers and it fails 6 lines, the sole behavioural cover. The 0.179.0 red was a gate defect | - | NO CATCH ON RECORD, one measured would-catch |

4 of 13 families have a real catch on record and 9 have none. Nothing beyond that is recommended
here: retiring a pole is a separate release with its own contract.

Outside the window, `procsub-staged-refusal`'s spelling arm has real catches at 0.657.0, 0.744.0,
0.767.0, 0.796.0 (BL-585) and 0.797.0. BL-585 records a sibling red caught by I54 instead, so the
I54/I54b lint partly overlaps that arm.

Method and controls of the pole judgment: every search is `/usr/bin/grep` or `awk` with the
exact-token regex `(^|[^-a-z0-9_])NAME(-[b-d])?([^-a-z0-9_.]|$)` over the backlog, the archive, the
CHANGELOG and the origin/main commit bodies (`git log origin/main -E --grep`, bodies as `%s%n%b`),
keeping catch-shaped lines in a window of 6 lines back and 2 forward. Positive control,
`gate-remediation-deny`: BL-181 and BL-178 found (29 backlog lines, 29 CHANGELOG lines, 3 windows).
Commit-body control: `gate-remediation-deny` reads 0 in bodies, so `procsub-staged-refusal` was used,
5 windows, all known catches. Must-miss token: 0 in every channel, verified absent first.

Limits: "no catch on record" is a floor of the record, not a proof that the fixture never caught
anything; a red that nobody wrote down, or wrote down without the fixture's name, is invisible to this
join. The push-FAIL classes are joined on CHANGELOG text, and the push logs were not read for them.
The loaded record is mixed-age: each row is the unit's last run.

## Branch-delete pushes run the whole hook

Filed as BL-1010. 7 branch-delete pushes ran the pre-push hook without `--no-verify`, and each wrote a
HIT line to `.git/ai-dlc-suite-key.log` inside its window. The wall is from the command's start to that
HIT stamp, a lower bound on the hook's wall (its last line was not read). Every HIT time is a
HIT line of `.git/ai-dlc-suite-key.log` on disk, re-read for this file (an impossible time reads 0).
The starts and log paths are from m6-583a's report (not on disk), except the bf3ed410 row; `T/` is `/private/tmp/claude-501/-Users-n8-git-ai-dlc/`, and every
log path is a perishable scratch path.

| Session | Start (UTC) | HIT (UTC) | Start to HIT (s) | Log |
|---|---|---|---|---|
| e1d32849 | 2026-11-10T14:35:00Z | 14:37:24Z | 144 | none, foreground to the tool result |
| 94d65a60 | 2026-11-11T15:24:18Z | 15:26:55Z | 157 | `../del.log` relative to the session's worktree, not resolved |
| b655f7b8 | 2026-11-11T15:33:12Z | 15:35:47Z | 155 | `T/b655f7b8-a59b-4a21-bf36-c52616e021d2/scratchpad/push.1mQo/del.log` |
| a9cff818 | 2026-11-11T16:23:33Z | 16:26:01Z | 148 | `T/a9cff818-6327-4006-8b24-26e56f7cf794/scratchpad/push.kSA218/del.log` |
| bf3ed410 | not found | 18:29:33Z | not measured | `T/bf3ed410-b6cc-468b-8903-e73efa263dbd/scratchpad/rdel.lVnW/push.out` |
| 490b0ab0 | 2026-11-11T18:53:56Z | 18:57:16Z | 200 | `T/490b0ab0-659f-4060-b933-bcfa410c3283/scratchpad/del.JdQ4/del.out` |
| 949b78fd | 2026-11-11T19:28:31Z | 19:32:49Z | 258 | `$D/../del.out`, D not resolved |

The bf3ed410 row is from m6-914v's table and the log itself: the log ends `- [deleted] b254-F975`
after `FIXTURE SUITE SKIPPED` and `17 of 23 step(s) skipped`, its mtime is 2026-11-11T18:29:36Z, and
the suite-key HIT is 3 s earlier. Its start is not in session bf3ed410's transcript: a search of its
15 transcript files for a Bash use naming `push.out` between 18:10Z and 18:30Z found none, while the
same files yield its cleanup command naming `rdel.lVnW` at 18:29:43Z, so the transcript is readable
and the push was launched some other way. Its time to HIT is therefore not measured.

About 2.5 minutes of hook on every branch delete. A delete pushes no tree, so nothing the hook checks
can be delivered by it.
