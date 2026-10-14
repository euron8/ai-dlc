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

## BL-503 — validate-mutation-red graded an all-skipped pytest run as GREEN, so a test that never ran read UNPROVEN

**DEFECT.** Filed by the consumer as `PC-S318-VALIDATE-MUTATION-RED-PRINTS-BASELINE-GREEN-FOR-AN-ALL-SKIPPED-RUN-AND-SCORES-IT-UNPROVEN-NOT-UNEVALUABLE`.

**What happened.** The baseline gate in `core/scripts/validate-mutation-red.sh` keyed on the test command's exit code
alone. A pytest run in which every selected test is skipped exits 0, so the script printed `baseline: GREEN`, and the
equally skipped mutated run landed in the UNPROVEN arm (exit 1), "the named test stayed GREEN under a real mutation".
Nothing ran; the honest verdict is exit 2. The consumer's S318 hit it on a `db_required` test skipped for want of a
database.

**The fix (batch 228).** For a pytest runner the script reads pytest's terminal summary line, ANSI-stripped, the LAST
match, under `LC_ALL=C`. A run whose counts are only `skipped`, `deselected` and `warning(s)`, or `no tests ran`, is
`UNEVALUABLE (no test ran)`, exit 2: at baseline before the file is mutated, and on the mutated run after the verified
restore. Any other count word means a test ran. A missing summary line, or a parse that returns anything unexpected,
fails open and prints `skip-check: not applied (no pytest summary line)` on every verdict. The refusal's first line
says the baseline is not GREEN, so the part-shard handover already routes it. One verdict changes on purpose: a test
skipped at baseline and un-skipped by the mutation was PROVEN and is now 2, since no GREEN to RED transition of a test
was observed. `dev.md` and `code-reviewer.md` name the new cause. `core/fixtures/mutation-red-replay` carries real-pytest
seeds s1-s11 and mutants sk1-sk9.

The contract adversary measured pytest 9.0.2's summary forms and set the whitelist, colour, last-match and `-k` seeds.
The tip adversary found a byte the parser could not read: a non-UTF-8 byte in test output made `awk` abort under a
UTF-8 locale, and the skip-gated case read PROVEN with no note. The parse now runs under `LC_ALL=C`, both case sites
have a fail-open default arm, and seed s11 with mutant sk8 hold it.

The receipt below is scored under `set -uo pipefail`: 0 on the fixed tree; 1 on the base `b1b5affb` and with the summary
check stubbed to report a run.

verify: sh F=core/scripts/validate-mutation-red.sh; [ -f "$F" ] || exit 9; D="$(mktemp -d)" || exit 9; printf 'a\nb\n' > "$D/t.txt"; mkdir "$D/s" "$D/m" || exit 9; printf '#!/bin/sh\necho "1 skipped in 0.00s"\nexit 0\n' > "$D/s/pytest"; printf '#!/bin/sh\necho "1 passed, 1 skipped in 0.00s"\nexit 0\n' > "$D/m/pytest"; chmod +x "$D/s/pytest" "$D/m/pytest" || exit 9; bash "$F" "$D/t.txt" 1 'z' "$D/s/pytest" >/dev/null 2>"$D/e1"; r1=$?; bash "$F" "$D/t.txt" 1 'z' "$D/m/pytest" >/dev/null 2>"$D/e2"; r2=$?; [ "$r2" -eq 1 ] || exit 9; printf 'a\nb\n' | cmp -s - "$D/t.txt" || exit 9; [ "$r1" -eq 2 ] && grep -qF 'UNEVALUABLE (no test ran)' "$D/e1" && exit 0; exit 1

## BL-504 — a dev seat was escalated only by a story tag, while code review was escalated by a capital-path criterion the dev route never stated

**DEFECT.** Filed by the consumer as `PC-S318-DEV-ESCALATION-HAS-NO-CAPITAL-PATH-CRITERION-WHILE-CODE-REVIEWER-ESCALATION-DOES`.

**What happened.** `implementation.md` escalated a review "for a capital-path or high-blast-radius diff", judged by
the lead at dispatch, and escalated a dev only when the story already carried `escalate_model: true`, whose only stated
reason was architectural judgment, cross-layer analysis or an open-ended approach. Nothing told a story author or the
lead to escalate a dev for capital-path work, so in the consumer's S318 a story editing production capital-path code
went to a plain `dev` while its review went escalated.

**The fix (batch 228).** One criterion, stated in the routing map's `escalate_model` row and cited by the review route:
capital-path or high-blast-radius owned paths. Core names no path list; a consumer's own conventions say which paths
qualify. The story author sets the tag. Before a story's FIRST dev dispatch, if the tag is absent or `false` and the
owned paths meet the criterion, the lead sets it in the canonical story file and commits it so it is reachable on the
dev's branch base BEFORE the dev worktree is cut, then dispatches `dev-escalated`. A story already dispatched keeps its
route, rework included, and the lead never removes the tag. A refused write is recorded in `docs/escalations/pending.md`,
which the refusing hook permits. Rule 28(b) names story-to-role routing. Check 22 needs no edit: it re-derives the route
from the persisted tag, which now lands before the first dispatch. No step or role file names a model for an escalated
route any more; each says "a stronger model than `dev` (resp. `code-reviewer`), as configured in `aiDlcRoles`".
`core/fixtures/process-rule-pins` pins seven phrases with four named rewording mutants.

The contract adversary walked the consumer's S318, S302, S258/S259 and S310 and found two BLOCKERs (a tag written after
the cut is overwritten by the consumer's artifact fold and FAILs Check 22; a tag written at rework FAILs it too) and
the explicit `escalate_model: false` the consumer writes as a template field. The tip adversary found the refusal
fallback pointed at a gate log the same hook denies.

**Recorded for the consumer (a finding, not an instruction).** In the consumer's S318, 0 of 13 stories carry its own
`capital_path` field, which its earlier sprints carry; and its role extension's "set `model: opus` on the spawn" is
rebound to the role's pin by core's dispatch guard, so the working spelling is `escalate_model: true`.

The receipt below is scored under `set -uo pipefail`: 0 on the fixed tree; 1 on the base `b1b5affb` and with "BEFORE the
dev worktree is cut" rewritten to "after".

verify: sh F=core/skills/ai-dlc/steps/implementation.md; S=core/skills/ai-dlc/steps/stories-test-strategy.md; [ -f "$F" ] && [ -f "$S" ] || exit 9; A="$(awk '/^\*\*Pre-dispatch routing/{on=1} on&&/^\*\*Pre-dispatch auth check/{exit} on{print}' "$F" | tr '\n' ' ' | tr -s ' ')"; R="$(awk '/^\*\*Routing map/{on=1} on&&/^Absent any routing tag/{exit} on{print}' "$S" | tr '\n' ' ' | tr -s ' ')"; [ -n "$A" ] && [ -n "$R" ] || exit 9; grep -qF "Before a story's FIRST dev dispatch, if its \`escalate_model\` is absent or \`false\`" <<<"$A" || exit 1; grep -qF 'BEFORE the dev worktree is cut' <<<"$A" || exit 1; grep -qF 'A story already dispatched keeps its route, rework included' <<<"$A" || exit 1; grep -qF 'capital-path or high-blast-radius' <<<"$R" || exit 1; grep -qF 'opus-tier' "$F" "$S" && exit 1; exit 0

## BL-505 — the Step 1a budget validator read a bare model alias as a 200K window, and the context sensor carried no family default

**DEFECT, found at batch 228 by the measurement of the operator's settings-template change.**

**What happened.** The operator's template maps `aiDlcModels` to the bare aliases `fable`, `opus`, `sonnet` and `haiku`,
as the reference consumer runs them. In Claude Code a bare `opus` or `sonnet` is the 1M variant (operator ruling,
batch 228). `core/scripts/validate-artifact-budget.sh` granted 1M only when the analyst's model id contained `[1m]`, so
under the new template, and on the consumer today, it read 200K, and the whole-read pool fell from 330000 to 66000 tokens;
an over-budget pool at Step 1a is a HARD_BLOCK. The context sensor gave every undeclared family 200K; its 1M figure for
opus and sonnet lived in a comment. Neither reader looked at the `env` block of `settings.json`, where the consumer
declares its windows.

**The fix (batch 228).** One family-window policy in `core/hooks/ai-dlc-window.sh`, sourced by both readers:
`ai_dlc_model_family`, `ai_dlc_family_window` and `ai_dlc_model_window`. Order: process env
`AI_DLC_MODEL_<F>_WINDOW`, then the same key in `.claude/settings.local.json` and `.claude/settings.json` `.env`, then a
`[1m]` suffix (1M), then a default that applies to an exact bare alias only: `opus`, `sonnet` and `fable` 1M,
`haiku` 200K; every other id without `[1m]` (a full id such as `claude-sonnet-4-5` or a Bedrock id) is 200K. A declared
window outside 50000..2000000 is rejected and named, and the next layer answers.
`AI_DLC_READER_WINDOW_TOKENS` still wins outright in the budget validator, which finds the library in
`validate-compact-window.sh`'s search order and falls back to its old `[1m]`-or-200K path when it cannot. The sensor's
sees full transcript ids, so an undeclared frontier lead keeps the 200K floor it had, the safe direction; a bare
alias or a declared window answers above it. `core/fixtures/whole-read-pool` and `core/fixtures/context-sensor` carry the arms, a two-reader
agreement probe and the library mutants.

The tip adversary found the first cut applying the 1M default by substring, so a full 200K id such as
`global.anthropic.claude-sonnet-4-6` read 1M in both readers; and a declared `99` made a 32-token pool. Both are fixed,
each with an arm and a mutant.

The receipt below is scored under `set -uo pipefail`: 0 on the fixed tree; 1 on the base `b1b5affb` (no library function),
with the family default returning 1M for every family, and with the default applied by substring.

verify: sh L=core/hooks/ai-dlc-window.sh; [ -f "$L" ] || exit 9; o="$(env -i PATH=/usr/bin:/bin bash -c '. "$1"; type ai_dlc_model_window >/dev/null 2>&1 || exit 7; for m in sonnet opus haiku claude-sonnet-5[1m] claude-sonnet-4-5 mystery; do w="$(ai_dlc_model_window "$m")"; printf "%s=%s " "$m" "${w%%|*}"; done' _ "$L")"; rc=$?; [ "$rc" -eq 7 ] && exit 1; [ "$rc" -eq 0 ] || exit 9; [ "$o" = "sonnet=1000000 opus=1000000 haiku=200000 claude-sonnet-5[1m]=1000000 claude-sonnet-4-5=200000 mystery=200000 " ] && exit 0; exit 1

## BL-506 — the spawn-ledger validator defined a party seat as a role with no model, so a persona given a model left the shardable set

**DEFECT, found at batch 228 by the contract adversary for the operator's settings-template change.**

**What happened.** `core/scripts/validate-spawn-ledger.sh` derived the party seats (cis, sm, tea, ux) as the `aiDlcRoles`
entries carrying no model. The operator's template gives each persona a model, as the reference consumer already does,
so no persona was a party seat: S1 stopped warning on a persona row with `shard: null` and S3 stopped failing an
invented exception, and nothing reported it. On the consumer's S317 ledger the old validator read 0 persona S1 warnings
and 10 S3 failures; the fixed one reads 57 and 11, the new S3 a real undeclared exception. Seven carriers said a persona
carries "an effort and no model".

**The fix (batch 228).** A party seat is a role file under the team-roles directory beside the settings file passed with
`--settings` whose line starts `The lead spawns you as a party-mode persona`; exactly cis, sm, tea and ux carry it. The
self-probe runs that derivation over seeded role files rather than a literal, and a run that derives no seat WARNs. The
dispatch guard, the renderer, `setup-sites.md`, the four persona role files and the I22 comment say a persona's model is
optional: set, the renderer writes a definition and the guard binds it like any role; absent, `/bmad-party-mode` sets it.
The setup SKILL and `QUICKSTART.md.template` point at the shipped blocks in `.claude/settings.json` instead of copying
them. `check-22-spawn-ledger`, `dispatch-model-guard` and `agent-definition-render` carry the new arms and mutants.

The receipt below is scored under `set -uo pipefail`: 0 on the fixed tree; 1 on the base `b1b5affb` and with the
derivation's line-start anchor removed.

verify: sh V=core/scripts/validate-spawn-ledger.sh; T=core/team-roles; [ -f "$V" ] && [ -d "$T" ] || exit 9; n="$(grep -l '^The lead spawns you as a party-mode persona' "$T"/*.md 2>/dev/null | sed 's|.*/||' | tr '\n' ' ')"; [ "$n" = "cis.md sm.md tea.md ux.md " ] || exit 9; awk '/^party_seats\(\)/{on=1} on&&/^}/{exit} on' "$V" | grep -qF "^The lead spawns you as a party-mode persona" || exit 1; exit 0
