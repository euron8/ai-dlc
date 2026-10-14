
## S317 dev and code-reviewer tier-pin change [lead] - 2026-10-10T21:15:00Z
**Status:** OVERRIDDEN
**Blocker type:** process gap
**Context:** `.claude/settings.json` was committed at 015245610 with `aiDlcRoles.dev.model` pinned to `haiku` and `aiDlcRoles.code-reviewer.model` pinned to `opus`. Check 22 `validate-spawn-ledger.sh --ledger _bmad-output/spawn-ledger.jsonl --sprint 317 --settings .claude/settings.json` then exits 1 on arm (a), a Rule 19(a) tier mismatch, for every earlier S317 spawn bound to `sonnet`.
**Evidence observed:** derived from `_bmad-output/spawn-ledger.jsonl` with `jq -r 'select(.sprint==317 and (.role=="dev" or .role=="code-reviewer") and .model_bound=="sonnet") | .role' | sort | uniq -c`, which prints 82 dev and 42 code-reviewer rows, timestamped 2026-10-05T15:57:32Z through 2026-10-10T19:01:13Z, all before the pin commit. The validator output lists 82 `[dev]` and 42 `[code-reviewer]` tier-mismatch FAIL lines among 135 FAIL lines in total; the other 11 are the arm S3 rows already cleared by the OVERRIDDEN entry above plus the summary lines. The control is that the same validator, run before 015245610, had no tier-mismatch rows.
**Assertion (beyond evidence):** none - assertion equals evidence.
**Decision/Question:** whether the 124 earlier spawns, correct against the pins in force when each was made, are waived or the pins reverted.
**Options:** (a) OVERRIDDEN, waiving the 124 spawns [chosen]; (b) revert the dev and code-reviewer pins; (c) hold story 3.1 at gate 2.
**Impact if skipped:** Gate 3 cannot close for story 3.1 or any later S317 story.
**Remediation:** No spawn is re-dispatched. Every spawn's output was verified by gates 1-3 and the converged review series: each of the 124 spawns belongs to a story that passed gate 1, gate 2 and gate 3 and merged, or to a review series stamped `EXIT_CONDITION_MET`. Spawns from here on bind the committed pins.
**Operator authorization:** 2026-10-10T21:07:09Z | "Authorize an override" - the operator's AskUserQuestion answer, recorded in `_bmad-output/operator-answers-history.md` with SHA256 53bb7e57020f3fa540de1be68526331e6edfb89576f80aef3f59382efb216de4.
