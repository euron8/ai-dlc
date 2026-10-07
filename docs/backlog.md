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

## BL-467 — readset-skip's M5 arm keys gamma under `core/fixtures/` while a consumer hook looks under `tests/fixtures/`

**BLOCKER.** Filed by the reference consumer as `PC-S317-READSET-SKIP-M5-SEEDS-CORE-FIXTURES-UNDER-A-TESTS-FIXTURES-HOOK`.
`lt_held()` in `core/fixtures/readset-skip/run.sh` seeded gamma and built its recorded discard key from
`$t/core/fixtures/gamma/run.sh`. The consumer's hook sets `FXROOT="tests/fixtures/"`, so the key never matched and M5
failed on every consumer push, including the self-update push that installs 0.741.0. The fix reads the resolved pool
block's `FXROOT` once and seeds and keys gamma under it.

verify: sh ! grep -qF '"$t/core/fixtures/gamma/run.sh"):$(sha_of' core/fixtures/readset-skip/run.sh && grep -qF '"$t/$FXROOT/gamma/run.sh"' core/fixtures/readset-skip/run.sh

## BL-469 — readset-skip ends FIXTURE BROKEN under the read-set deriver's sandbox, so it is never mapped

**DEFECT.** Measured batch 203 by the operator's read-set trace. `/bin/ps` is setuid, and `sandbox-exec` refuses to exec
it (`execvp() of '/bin/ps' failed: Operation not permitted`, rc 71). The BL-463 start-time worlds in
`core/fixtures/readset-skip/run.sh` run `ps -o lstart=`, so under `--tracer sandbox` arm (k) failed and
`readset_pid_start printed nothing for the live lock pid` ended the fixture `FIXTURE BROKEN`. The deriver OMITTED it on
every trace and it ran on every push. The fix detects the sandbox POSITIVELY, from the `log stream` probe the loss arm
already took ("Cannot run while sandboxed"), and SKIPs the three ps-dependent groups by name only there; a sandbox claim
where `ps` still works is `broken`, and outside a sandbox a failing `ps` stays `broken`. The receipt runs the fixture's
own detector block under a real `sandbox-exec` and requires the SKIP, and requires the unskipped `broken` to remain.

verify: sh f=core/fixtures/readset-skip/run.sh; b="$(awk '/^IN_SANDBOX=0; LS_PROBE_RC=127$/,/^}$/' "$f")"; [ -n "$b" ] || exit 1; o="$(B="$b" sandbox-exec -p '(version 1)(allow default)' /bin/bash -c 'WORK="$(mktemp -d)"; broken() { echo BROKEN; exit 2; }; eval "$B"; ps_sandbox_skip probe' 2>&1)"; case "$o" in *"SKIP  probe: inside a sandbox"*) ;; *) exit 1 ;; esac; [ "$(grep -F '[ -n "$PJ_LIVE" ] || broken' "$f" | grep -cv '^[[:space:]]*#')" = 1 ]
