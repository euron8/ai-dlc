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


## BL-523 — the gate-adjudication rotator reports "nothing to move" while a sprint's verdicts carry a series id no `--sprint` can name

**DEFECT.** **Provenance: `PC-S318-ROTATE-GATE-ADJUDICATION-SPRINT-FLAG-NEVER-MATCHES-NONCE-STYLE-SERIES-IDS`**,
filed by the reference consumer at its s318 retro. `rotate-gate-adjudication.sh --sprint s<N>` selects by
the `-s<N>-` token in `gate_series_id`, and the schema leaves that field unpatterned. On the consumer's
live directory (239 verdicts), 52 carry an id with no such token, 42 of them exactly `<gate>-<nonce>`. An
empty selection exited 0 with "nothing to move", so retro step 5b passed while the sprint's verdicts
stayed live for the gate-remediation guard.

**Reader half, this branch.** An empty `--sprint` selection is now exit 1 when an unmatchable series
(a non-empty id no selector can name) has a NEWEST member recording a FAIL. The refusal is computed from
the live directory on every run, re-runs included, and keys on no record of an earlier run: running only
the first printed line fills this sprint's archive, and the re-run must still refuse while a newer FAIL
series stays live. The refusal names every file of every such series and prints one dry-run
`--sprint s<M> --series '<exact-id>'` command per id. Any other unmatchable series gets a WARN with the
same commands and does not refuse. `--series` moves exactly that id. On a non-empty selection the rotator
prints a WARN and exits 0, unless the survivor refusal fires. On the close (`--sprint` without `--series`)
the survivor refusal fires whenever the close leaves an unmovable FAIL as the live pass, promoted or not. On
a remedy step (`--series` or `--legacy-through`) it fires only when the move promotes a new live pass, so a
walk that moves an older series first is not refused, and the two remedies cannot refuse each other. A
moved verdict whose nonce TIES the survivor's counts as promotion, because the guard orders a tie by glob
and the moved verdict may have been the live pass.

**The scope was revised twice: from the id alone to FAIL-carrying series, then to each series' newest
member.** The guard reads only the live directory, and a stale verdict with no FAIL is its allow state, so
only a stale FAIL can deny. A series moves whole and its newest member sorts above its older ones, so an
older FAIL can never become the live pass while its PASSing retry stays live; a sidecar does not exempt a
series, because the guard reads one only for the live nonce. On the consumer's tree, `--sprint s318` keyed
on any member named 12 files in 8 series. Keyed on the newest member it names 4 files in 4 series
(`s311-stories-test-strategy-7`, `s311-sprint-review`, `sprint-review-20260919T193432Z`,
`implementation-20261005T022120Z`) and WARNs 48 files under 44 commands. Mutation 6 reverts the FAIL
narrowing and mutation 8 keys on any member; each flips a WARN world to exit 1.

A hint is printed only when exactly one sprint is possible. Otherwise the line prints `NO HINT (s<a>..s<b>)`,
`NO HINT (..s<N>)` when no sprint archive exists, or `NO HINT (backfill below s<L>)` when the sprint being
closed is not above the newest archive. Scored against the consumer's sprint-close commits, the 48 printed
commands give 39 correct hints, 0 wrong and 9 NO HINT. With every archive removed, the old rule hinted the
closing sprint and scored 18 right and 30 wrong; it now gives 8 right, 0 wrong and 40 NO HINT. In a simulated s319 close with a new FAILing
`<gate>-<nonce>` verdict, walking the printed commands in order finishes in one pass: 11 commands, 2
operator questions, 0 refused applies, and `--sprint s319 --apply` exits 0. The PASS seed takes 10
commands and 1 question.

**Writer half, a follow-on in this batch.** It stamps `<gate_type>-s<N>-<nonce>` at mint time, so new
verdicts carry the token. It is built after the two branches that edit the same files merge.

verify: sh R="$PWD/core/scripts/rotate-gate-adjudication.sh"; [ -f "$R" ] || exit 9; command -v jq >/dev/null || exit 9; d="$(mktemp -d)" || exit 9; g="$d/s/gate-adjudication"; a="$d/s/implementation-artifacts/s309/gate-adjudication"; h="$d/t/gate-adjudication"; mkdir -p "$g" "$h" || exit 9; printf '{"gate_nonce":"planning-20260909T120000Z","gate_series_id":"planning-20260909T120000Z","verdicts":[{"check_id":"1","verdict":"FAIL"}]}\n' > "$g/planning-20260909T120000Z.verdict.json"; printf '{"gate_nonce":"planning-20260910T120000Z","gate_series_id":"planning-20260909T120000Z-retry","verdicts":[{"check_id":"1","verdict":"PASS"}]}\n' > "$g/planning-20260910T120000Z.verdict.json"; printf '{"gate_nonce":"implementation-20260914T000000Z","gate_series_id":"implementation-20260914T000000Z","verdicts":[{"check_id":"4","verdict":"FAIL"}]}\n' > "$g/implementation-20260914T000000Z.verdict.json"; printf '{"gate_nonce":"story-20260913T044428Z","gate_series_id":"story-s311","verdicts":[{"check_id":"2","verdict":"FAIL"}]}\n' > "$h/story-20260913T044428Z.verdict.json"; o="$(bash "$R" --sprint s308 --state-dir "$d/s" 2>&1)"; r=$?; [ "$r" -eq 1 ] || exit 1; grep -q '/planning-20260909T120000Z\.verdict\.json$' <<<"$o" || exit 1; o="$(bash "$R" --sprint s308 --state-dir "$d/t" 2>&1)"; r=$?; [ "$r" -eq 1 ] || exit 1; grep -q '/story-20260913T044428Z\.verdict\.json$' <<<"$o" || exit 1; bash "$R" --sprint s309 --series planning-20260909T120000Z --apply --state-dir "$d/s" >/dev/null 2>&1 || exit 1; [ -f "$a/planning-20260909T120000Z.verdict.json" ] && [ -f "$g/planning-20260910T120000Z.verdict.json" ] || exit 1; o="$(bash "$R" --sprint s309 --state-dir "$d/s" 2>&1)"; r=$?; [ "$r" -eq 1 ] || exit 1; grep -q '/implementation-20260914T000000Z\.verdict\.json$' <<<"$o" || exit 1; bash "$R" --sprint s309 --series implementation-20260914T000000Z --apply --state-dir "$d/s" >/dev/null 2>&1 || exit 1; bash "$R" --sprint s309 --state-dir "$d/s" >/dev/null 2>&1 || exit 1; bash "$R" --sprint s308 --state-dir "$d/s" >/dev/null 2>&1 || exit 1; u="$d/u/gate-adjudication"; v="$d/v/gate-adjudication"; w="$d/w/gate-adjudication"; mkdir -p "$u" "$v" "$w" || exit 9; printf '{"gate_nonce":"planning-20260908T000000Z","gate_series_id":"planning-20260908T000000Z","verdicts":[{"check_id":"1","verdict":"PASS"}]}\n' > "$u/planning-20260908T000000Z.verdict.json"; printf '{"gate_nonce":"planning-20260909T120000Z","gate_series_id":"planning-20260909T120000Z","verdicts":[{"check_id":"1","verdict":"FAIL"}]}\n' > "$u/planning-20260909T120000Z.verdict.json"; bash "$R" --sprint s310 --series planning-20260908T000000Z --apply --state-dir "$d/u" >/dev/null 2>&1 || exit 1; o="$(bash "$R" --sprint s310 --state-dir "$d/u" 2>&1)"; r=$?; [ "$r" -eq 1 ] || exit 1; grep -q '/planning-20260909T120000Z\.verdict\.json$' <<<"$o" || exit 1; printf '{"gate_nonce":"planning-20260915T000000Z","gate_series_id":"planning-s310-20260915T000000Z","verdicts":[{"check_id":"1","verdict":"PASS"}]}\n' > "$v/planning-20260915T000000Z.verdict.json"; printf '{"gate_nonce":"implementation-20260916T000000Z","gate_series_id":"implementation-20260916T000000Z","verdicts":[{"check_id":"4","verdict":"FAIL"}]}\n' > "$v/implementation-20260916T000000Z.verdict.json"; o="$(bash "$R" --sprint s310 --state-dir "$d/v" 2>&1)"; r=$?; [ "$r" -eq 1 ] || exit 1; grep -q 'implementation-20260916T000000Z' <<<"$o" || exit 1; printf '{"gate_nonce":"legacy-20260701T000000Z","verdicts":[{"check_id":"7","verdict":"FAIL"}]}\n' > "$w/legacy-20260701T000000Z.verdict.json"; printf '{"gate_nonce":"planning-20260909T120000Z","gate_series_id":"planning-20260909T120000Z","verdicts":[{"check_id":"1","verdict":"FAIL"}]}\n' > "$w/planning-20260909T120000Z.verdict.json"; o="$(bash "$R" --sprint s310 --series planning-20260909T120000Z --state-dir "$d/w" 2>&1)"; r=$?; [ "$r" -eq 1 ] || exit 1; grep -q -- '--legacy-through 20260701T000000Z' <<<"$o" || exit 1; bash "$R" --legacy-through 20260701T000000Z --apply --state-dir "$d/w" >/dev/null 2>&1 || exit 1; bash "$R" --sprint s310 --series planning-20260909T120000Z --apply --state-dir "$d/w" >/dev/null 2>&1 || exit 1; bash "$R" --sprint s310 --state-dir "$d/w" >/dev/null 2>&1 || exit 1; x="$d/x/gate-adjudication"; y="$d/y/gate-adjudication"; mkdir -p "$x" "$y" || exit 9; printf '{"gate_nonce":"legacy-20260909T120000Z","verdicts":[{"check_id":"7","verdict":"FAIL"}]}\n' > "$x/legacy-20260909T120000Z.verdict.json"; printf '{"gate_nonce":"aplanning-20260909T120000Z","gate_series_id":"aplanning-20260909T120000Z","verdicts":[{"check_id":"1","verdict":"PASS"}]}\n' > "$x/aplanning-20260909T120000Z.verdict.json"; o="$(bash "$R" --sprint s310 --series aplanning-20260909T120000Z --state-dir "$d/x" 2>&1)"; r=$?; [ "$r" -eq 1 ] || exit 1; grep -q 'legacy-20260909T120000Z -- ' <<<"$o" || exit 1; printf '{"gate_nonce":"legacy-20260920T000000Z","verdicts":[{"check_id":"1","verdict":"PASS"}]}\n' > "$y/legacy-20260920T000000Z.verdict.json"; printf '{"gate_nonce":"planning-20260909T120000Z","gate_series_id":"planning-20260909T120000Z","verdicts":[{"check_id":"1","verdict":"FAIL"}]}\n' > "$y/planning-20260909T120000Z.verdict.json"; o="$(bash "$R" --legacy-through 20260920T000000Z --state-dir "$d/y" 2>&1)"; r=$?; [ "$r" -eq 1 ] || exit 1; grep -q 'planning-20260909T120000Z -- ' <<<"$o"

## BL-526 — nothing prescribes `gate_series_id`, so the adjudicator invents one and the stall rung cannot group a gate

**DEFECT.** Discharges `PC-S318-ROTATE-GATE-ADJUDICATION-SPRINT-FLAG-NEVER-MATCHES-NONCE-STYLE-SERIES-IDS`
as its writer half. BL-523 is the reader half: the rotator's sprint flag.
`_gate-procedures.md` named `gate_series_id` 0 times against 6 for `gate_nonce`, and the adjudicator
brief passed no series id. The adjudicator invented one. In graph's committed corpus (239 verdicts),
94 carry none, 42 carry the nonce-style `<gate>-<TS>` that the rotator's sprint flag cannot match, and
34 more carry ad-hoc shapes.

**The fix.** `gate-validation.md` "At gate entry" now prescribes exactly `<gate_type>-s<N>-<TS>` for an
unscoped gate and `<gate_type>-s<N>-<slug>-<TS>` for a gate scoped to one story. `<N>` is the snapshot's
`sprint_id`. The slug is `story` plus the story's `<story-index>` with each `.` or `-` written as `x`:
one lowercase `[a-z0-9]` segment ending in a digit. A same-series rule decides the id at dispatch,
never from `close`. The only reuse candidate is the newest stem whose id has that exact form for this
gate_type, sprint and slug, with every part agreeing. A Gate Reset id wins. Otherwise a candidate that
did not pass is reused, where not passing is read from the `26` row of its `.gate-checkpoint/<nonce>.tsv`
ledger and never from the verdict's per-check rows, which still record a suppressed check as FAIL.
Otherwise a new id is minted, so a malformed id is never reused and two stories' gates never share a
series. Replayed on graph's interleaved s304 story gates, that yields 4 series, and `--series` reports
both real check-22 STALLs (story1, story4). A Gate Reset is performed before gate entry. It mints the new
id and records the retired one, or `legacy`. The adjudicator brief and shard briefs carry the series id,
and it is exempt from "nothing carried forward". The validator's per-pass envelope arm requires the
gate_type prefix, the `-s<digits>-` field, an optional slug, and a trailing timestamp no later than the
nonce. It judges only a pass whose nonce is at or after `SERIES_FORM_FROM` (20261015T000000Z). That makes
its FP set 0 of graph's 239; unscoped it fires on 61. The arm's header records the derivation. The C5(a)
rotator's `--sprint s<N>` selector (`*-s<N>-*`) moves a slugged id.

The receipt runs the `gate-adjudication` fixture and needs its ten series-form cases, including the
slugged near-miss and the three malformed-slug offenders. It also needs the 27 series-id rows of
`process-rule-pins --report`. It exits 1 at `4aa734c4`, on a rule 2 that reuses a malformed id, counts
a suppressed FAIL or ignores the gate's story, on the arm without its slug, trailing-timestamp or
series-time check, and on the prose with no arm. It exits 0 at this tip.

verify: sh F=core/fixtures/gate-adjudication/run.sh; P=core/fixtures/process-rule-pins/run.sh; [ -f "$F" ] && [ -f "$P" ] || exit 9; o="$(bash "$F" 2>&1)" || exit 1; n="$(grep -cE '^  ok    SF(0|0b|1|2|3|4|5|6|7|8): ' <<<"$o")" || n=0; [ "$n" -eq 10 ] || exit 1; r="$(bash "$P" --report 2>&1)" || exit 1; m="$(grep -cE '^  ok    (gv-series-[a-z]+|gv-fail-series|gv-reset-[a-z]+|gp-[a-z]+-series|gadj-[a-z]+-series): pinned inside ' <<<"$r")" || m=0; [ "$m" -eq 27 ]
