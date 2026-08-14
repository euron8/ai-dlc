# Push-candidate adjudication — the graph consumer's whole ledger

Every open entry in `/Users/n8/git/graph/_bmad-output/ai-dlc-update/push-candidate-ledger.md` was
re-derived against this distribution at `b1ee196` / VERSION `0.372.0`. **115 entries, 115 verdicts,
no exceptions** — a missing row is indistinguishable from an entry nobody looked at, so the
coverage join is asserted rather than assumed.

This document is the upstream half. The consumer owns its own ledger; **nothing here edits the
graph repo.** Consumer access throughout was `git cat-file`, `git log`, `git show`, `grep`, `ls`
and read-only detector runs.

## Why this pass had to be by hand

The instrument that normally answers "what is still open" cannot answer it, and says so. graph's
own reconcile report for the 0.370.0 → 0.372.0 pull carries:

> `RECEIPTS-UNDECIDED (theirs_has receipts)  28 of 28 'theirs_has' receipt(s) reported STILL-LIVE
> on a substring present at BASE as well as at theirs (0.372.0) … Do not treat a zero
> CLOSE-CANDIDATE count from this run as evidence that nothing was absorbed.`

So the zero-close reading was not a floor and the 59 `STILL-LIVE` rows were not findings.

**The measured result is worse than that warning implies: 41 of 115 entries — 36% — were already
fixed upstream, and the ledger's own machinery had closed none of them.**

## Method

**The corpus was pinned before anything was read.** A live graph session was filing into the
ledger during this pass (it added `PC-S303-BUDGET-CHECK-EVIDENCE-FIND-PICKS-A-STALE-GATE-LOG`
uncommitted, and the consumer's dirty count moved 35 → 36 unaided). Every derivation ran against a
pinned copy, so the line numbers below are stable.

**The census was lifted from the shipping code, not re-implemented.** `ledger-reverify.sh`'s own
extraction program (lines 621–738) was taken verbatim with one change: `flush()`'s `has_verify &&`
conjunct dropped, so an entry carrying no receipt is emitted too. **The control is that the
receipt-carrying subset must equal the tool's own label set** — 79 labels each way, symmetric
difference empty, and the comparison demonstrably fires on a one-line mutant.

That discipline was learned the hard way in this same session: a hand-rolled `awk` census produced
a false finding (two section headings said to have absorbed a receipt) within the hour. The
shipping parser emits no row for either heading; the tokens the probe matched are
`verify: theirs_has` written inside ordinary prose. **A hand-written probe is a second
implementation whose bugs nobody finds.**

**131 open entry starts, 16 section banners, 115 adjudicable entries.** Receipt mix: 25
`theirs_has`, 24 `manual`, 19 `sh`, 11 `theirs_lacks`, and **36 carrying no receipt at all** —
entries nothing mechanical has ever tested.

Adjudication ran as 29 parallel subagents, four entries each, one subsystem per batch. Each was
given the verdict vocabulary, the consumer-boundary prohibition verbatim, and this repo's control
discipline: any claim whose answer is an absence carries a control in the same invocation that
comes back non-zero, and both numbers are reported.

## Result

| verdict | count | disposition |
|---|---|---|
| `ALREADY-FIXED` | **41** | close by CHANGELOG citation |
| `HOLDS-MECHANISM-WRONG` | 22 | remediate the real defect; record the correction |
| `NOT-UPSTREAM` | 16 | brief only — consumer-local by nature |
| `HOLDS` | 15 | remediate as filed |
| `HOLDS-WIDER` | 14 | remediate at the true scope |
| `FALSIFIED` | 4 | close by CHANGELOG refutation |
| `DUPLICATE-OF` | 3 | close by citation of the dropped id |

**51 entries are live.** By subsystem: validators 14, the `ai-dlc` skill 12, reconcile machinery
10, layer extensions 7, the `ai-dlc-update` skill 4, fixtures 2, roles 1, hooks 1.

**48 close now** — 41 already fixed, 4 falsified, 3 duplicates. Sixteen more are consumer-local and
close by disposition rather than by upstream work.

## The findings that change what gets built

**Of the 51 live entries, 36 are materially wrong about their own mechanism.** That is
`HOLDS-MECHANISM-WRONG` plus `HOLDS-WIDER` — every one of them reproduces as a defect while its
filing misstates the cause, the consequence, or the scope. The last cycle measured three of four;
this pass measures 36 of 51 and the base rate is now established, not anecdotal. **Adjudicate the
mechanism, never the claim, and never trust the filing's prescribed fix.**

**A `NAMED-UPSTREAM` silence is not evidence of non-absorption.** The commit that fixed two entries
at v0.117.0 (`b356c92`) cites no `PC-` id at all and is discoverable only by subject text or
`git log -S` on the shipped prose. Several other absorptions were independent upstream
rediscoveries that never credited the filing. So the id-keyed attributor structurally
under-reports, and that is a second reason the zero-close reading meant nothing.

**A `NAMED-UPSTREAM` row is not evidence of absorption either.** Every naming was read.
`80586e6`'s `PC-S295` citation names one full id and absorbed exactly that entry — for the other
four it is a bare prefix collision. `a705e55`'s `PC-S304` attributes to a different, archived entry
of the same short id. `9cdfce7`'s `PC-S298` names a set that predates the filing. `fc193e0`'s
`PC-S331` is an unrelated later filing reusing the short id. `665a3cd` is a plan doc, and the
release that actually moved the subject names no id. **Five of the thirteen NAMED-UPSTREAM signals
are collisions, not dispositions.**

**A receipt anchored on text the fix quotes back is the dominant failure mode.** Repeatedly, the
fix documents what it removed, so the receipt's anchor survives inside the comment recording the
change — `PC-S316`, `PC-S302-ADJUDICATION-RERUN`, `PC-S303-EFFORT-BINDING`, `PC-S299-SIGPIPE`,
`PC-S299-MISATTRIBUTES`, `PC-S308`, and more. Quoting what you removed is good authoring practice
here, so **this will keep happening**, and it is a distinct failure from the two shapes
`ledger-reverify.sh` already detects. One receipt was green for a third reason: it anchored on
`solo-evaluat`, a hyphenation the filing invented, while upstream spells the same concept
"inline-evaluating". It reported STILL-LIVE against a rule that had shipped six days before the
entry was filed.

**One entry is not an entry.** The body at pin line 2028 is the severed tail of archived
`PC-S306-OVERRIDE-DELEGATES-INTO-THE-SECTION-IT-SHADOWS`. `ledger-rotate.sh` cut it mid-fenced
block: the archive half runs to an odd fence count so the following entry's heading now sits inside
an open code fence, and the live half begins with a quoted `retro.md` heading promoted to a real
one. The entry documenting heading-span fragility was itself destroyed by a heading-span bug. The
claim it carried is `ALREADY-FIXED` at v0.180.0; the parser damage is live and corroborates
`PC-S313`, which was independently reproduced by running the shipped rotator.

**Three entries were already dead when they were written.**
`PC-S298-WAIT-FOR-DELIVERABLE` was filed during a pull to 0.168.1 whose range contains its own fix
at 0.168.0. `PC-S297-RETRO-MD-CLAIMS-NONEXISTENT-GHA-WORKFLOW` was filed four days after
`93e05d3` fixed it. `PC-S295-RETRO-LEAD-SOLO-EVAL-LLM-CHECK`'s rule landed six days before the
filing, at `b7112d7` — and the refutation pass established it was present **in the very blob the
entry cites as its own re-verification base**, `f4845a9`, at two sites, with 43 `CHECK_LOADED`
markers in the same blob as the control. The entry's "STILL LIVE — re-verified" is false against
its own named ref.

**One entry's own re-verification produced a false zero.** `PC-S297-RETRO-UPSTREAM-PM-AC-PRECISION`
re-asserted STILL-LIVE in 2026-07-28 having grepped for wording the fix does not use — its control
was correct and its arm was blind. Re-derived at the entry's own cited sha, the clause is present,
and the control returns the exact value the entry itself reports.

**Sixteen entries target code this distribution has never shipped.** Nine `PC-S312-*` probes plus
seven others cite the consumer's forked `scripts/` tree; per-path `git log --all` returns zero for
every one against non-zero controls in the same invocation. They are `NOT-UPSTREAM` by
construction and cannot close by any upstream act.

**Three live upstream defects were found that no ledger entry names**, surfaced while adjudicating
something else: divergent flow-log legends across the three seeding hooks; two dispatched modes in
`validate-stub-audit.sh` with no executable driver; and a word-split list at
`validate-draft-stamps.sh:138`/`:193` whose failure mode is a check that silently reports itself
skipped.

**The distribution's own gate is exposed to a filed consumer defect.**
`PC-S330-PREPUSH-LEAKS-GIT_DIR` is anchored on the shipped consumer hook, but `.githooks/pre-push`
— this repo's gate — has the identical gap at its own dispatch site, and `git worktree list`
currently shows seven linked worktrees here. Reproduced behaviourally in throwaway repos: with
`GIT_DIR` inherited, a sandbox `git init` creates no `.git` and the commit lands on the real
repository, staging a deletion. No fixture depends on the leak.

## Notes on the instrument itself

**The tool's `ENTRY` column is not a unique key**, though its header calls it "a join key back into
the ledger". Four `## Open — filed <date>` banners all label as `Open`; two bullets collide on
`scripts/validate-provenance-block.sh`. Measured: no collision today involves a receipt-carrying
entry, so it emits no wrong report row yet. Tiered low, recorded so it is not rediscovered.

**Two entries closed themselves in a form neither tool can read.**
`PC-S300-CYCLE-STATE-RESOLVED-UNREACHABLE` wrote `**CLOSED — FIXED UPSTREAM at v0.247.0**`; the
reverify skip predicate fires zero times on it and `ledger-rotate.sh` will never archive it. It is
closed in prose and invisible to both tools — the state `ledger-reverify.sh:787` warns about,
reached from the other side.

## Reproducing this

```
cd /Users/n8/git/graph && bash .claude/skills/ai-dlc-update/reconcile/ledger-reverify.sh \
  /Users/n8/git/ai-dlc adec9ae /Users/n8/git/graph b1ee196
```

**Never run it with the process cwd at the ai-dlc root** — `ledger-reverify.sh:927-948` records
that a distribution-root run turned a live `STILL-LIVE` into a `CLOSE-CANDIDATE`, and a false close
is the worst output this system has.

## The verdict table — all 115 open entries

Keyed by line number in the pinned ledger (`md5 2fd444dcf406cdff728fe3c0c4352267`, 4356 lines).
Sorted by ledger order.

| pin | entry | verdict | subsystem |
|---|---|---|---|
| 78 | `validate-ci-gates-surface-remainder` | **NOT-UPSTREAM** | validators |
| 118 | `validate-retro-evidence-delegate-provenance` | **HOLDS-MECHANISM-WRONG** | validators |
| 139 | `validate-mandatory-rules-subset-flags` | **DUPLICATE-OF-pin1011** | validators |
| 157 | `SKILL.md-provenance-schema-pointer` | **ALREADY-FIXED-v0.143.6** | ai-dlc-skill |
| 177 | `rule18-terse-traceability-carve-out` | **HOLDS-MECHANISM-WRONG** | ai-dlc-skill |
| 226 | `extensions/checks/gate-validation-push.md` | **HOLDS-MECHANISM-WRONG** | layer-extensions |
| 252 | `extensions/steps-domain/deploy-validate-push.md` | **HOLDS-MECHANISM-WRONG** | layer-extensions |
| 255 | `extensions/steps-domain/retro-push.md` | **HOLDS-MECHANISM-WRONG** | layer-extensions |
| 259 | `extensions/steps-domain/implementation-push.md` | **HOLDS-MECHANISM-WRONG** | layer-extensions |
| 262 | `extensions/steps-domain/SKILL-push.md` | **HOLDS-MECHANISM-WRONG** | layer-extensions |
| 265 | `extensions/steps-domain/route-push.md` | **HOLDS** | layer-extensions |
| 267 | `extensions/steps-domain/sprint-review-push.md` | **HOLDS** | layer-extensions |
| 269 | `extensions/steps-domain/stories-test-strategy-push.md` | **HOLDS** | ai-dlc-skill |
| 271 | `extensions/steps-domain/artifact-consolidation-push.md` | **ALREADY-FIXED-v0.33.2** | ai-dlc-skill |
| 273 | `extensions/roles/code-reviewer-push.md` | **ALREADY-FIXED-v0.277.0** | roles |
| 275 | `extensions/roles/qa-push.md` | **ALREADY-FIXED-v0.277.0** | roles |
| 276 | `extensions/roles/dev-push.md` | **HOLDS-MECHANISM-WRONG** | roles |
| 281 | `.claude/team-roles/tea.md` | **ALREADY-FIXED-v0.21.0** | roles |
| 297 | `validate-provenance-block-placeholder-literal` | **ALREADY-FIXED-v0.128.0** | validators |
| 302 | `validate-provenance-block-inline-transcript` | **ALREADY-FIXED-v0.60.0** | validators |
| 305 | `scan-stray-provenance-generated-carveout` | **ALREADY-FIXED-v0.198.0** | validators |
| 316 | `sprint-review-decision-branch-coverage` | **HOLDS-WIDER** | ai-dlc-skill |
| 334 | `layer-drift-EXTENSION-RESTATES-CORE-title-join` | **HOLDS-MECHANISM-WRONG** | reconcile |
| 349 | `S295-retro-batch-closures` | **NOT-UPSTREAM-scaffolding** | consumer-local |
| 351 | `PC-S295-RETRO-STEERING-AUDIT-SESSION-SCOPED` | **ALREADY-FIXED-v0.117.0** | ai-dlc-skill |
| 387 | `PC-S295-FLOWLOG-HEADER-LEGEND-IS-GREPPABLE-AS-DATA` | **ALREADY-FIXED-v0.117.0** | hooks |
| 436 | `PC-S295-RETRO-STEP5C-DEADLOCK-ON-DEFERRED-RED` | **HOLDS-WIDER** | ai-dlc-skill |
| 510 | `PC-S295-RETRO-CHECK5-SELF-REFERENTIAL` | **HOLDS** | ai-dlc-skill |
| 553 | `PC-S295-RETRO-LEAD-SOLO-EVAL-LLM-CHECK` | **FALSIFIED** | ai-dlc-skill |
| 577 | `PC-S295-RETRO-RED-SMOKE-CROSSING-SPRINT-BOUNDARY` | **HOLDS-WIDER** | ai-dlc-skill |
| 610 | `PC-S295-RETRO-RULE18-STABLE-IDENTIFIER-TAGS` | **DUPLICATE-OF-pin177** | ai-dlc-skill |
| 638 | `gate-validation-Check25-arm-B-no-remediation` | **ALREADY-FIXED-v0.111.0** | ai-dlc-skill |
| 654 | `PC-S296-ESCALATION-STATUS-APPENDS-INSTEAD-OF-REPLACING` | **HOLDS-MECHANISM-WRONG** | validators |
| 673 | `PC-S296-H2-ATTESTED-ANCHOR-DEFEATED-BY-BACKTICKS` | **HOLDS-WIDER** | validators |
| 687 | `PC-S296-SNAPSHOT-BUDGET-UNENFORCED-AT-GATES` | **FALSIFIED** | validators |
| 701 | `PC-S296-PIPELINE-POSITION-MUST-BE-EDITED-IN-PLACE` | **HOLDS-MECHANISM-WRONG** | hooks |
| 715 | `PC-S296-DEPLOY-VALIDATE-NA-RITUAL` | **FALSIFIED** | ai-dlc-skill |
| 728 | `PC-S296-PAUSE-SKIP-ARM-MISSES-TASK-NOTIFICATIONS` | **ALREADY-FIXED-v0.265.0** | hooks |
| 776 | `PC-S295-RETRO-PARALLEL-OPEN-COUNT-METHOD` | **NOT-UPSTREAM** | ai-dlc-skill |
| 798 | `PC-S295-RETRO-COLLAPSE-PAUSE-FLAG-AND-BOUNDED-JOIN` | **HOLDS-MECHANISM-WRONG** | validators |
| 821 | `PC-S296-H1-FIXTURE-CITATION-GAP` | **ALREADY-FIXED-v0.146.0** | ai-dlc-skill |
| 860 | `PC-S296-REJECTION-CARRIES-UNRELATED-GAPS` | **HOLDS** | reconcile |
| 931 | `PC-S297-POOL-LOOP-SUBSHELL-TRAP-UNDOCUMENTED` | **HOLDS-MECHANISM-WRONG** | validators |
| 1030 | `validate-retro-prereq-RETIRED-record` | **NOT-UPSTREAM** | consumer-local |
| 1045 | `PC-S297-FFCLUSTER-SHA-STALE` | **NOT-UPSTREAM** | layer-extensions |
| 1069 | `PC-S297-LOCKED-ANCHOR-VALIDATOR-VACUOUS` | **ALREADY-FIXED-v0.280.0** | validators |
| 1093 | `PC-S297-CHECK16-ELEMENT2-REGEX-DEAD` | **HOLDS-MECHANISM-WRONG** | validators |
| 1125 | `PC-S297-RETRO-MD-CLAIMS-NONEXISTENT-GHA-WORKFLOW` | **ALREADY-FIXED-93e05d3** | ai-dlc-skill |
| 1136 | `PC-S297-PROVENANCE-FLAGLESS-FAIL-OPEN-BY-DEFAULT` | **HOLDS-WIDER** | validators |
| 1149 | `PC-S297-GUARDED-MERGE-PROVENANCE-INDIRECT-INVOCATION` | **NOT-UPSTREAM** | consumer-local |
| 1165 | `PC-S297-CHECK17-PRD-ARM-CONTRADICTS-RULE-20` | **HOLDS-WIDER** | ai-dlc-skill |
| 1215 | `PC-S297-LOCKED-FENCE-LAUNDERS-AGENT-PROSE` | **HOLDS** | validators |
| 1226 | `PC-S297-VALIDATOR-PASS-VS-NOTHING-TO-CHECK-CONVENTION` | **HOLDS-WIDER** | validators |
| 1240 | `PC-S297-LOCKED-ANCHOR-EXEMPTED-BY-SILENCE` | **ALREADY-FIXED-v0.280.0** | validators |
| 1254 | `PC-S297-VALIDATE-MANDATORY-RULES-CHECK3-CHECK4-DEAD` | **ALREADY-FIXED-v0.88.0** | validators |
| 1269 | `PC-S297-CHECK16-SCOPE-AMBIGUITY` | **HOLDS** | ai-dlc-skill |
| 1305 | `PC-S297-RETRO-UPSTREAM-PM-AC-PRECISION` | **ALREADY-FIXED-v0.169.0** | roles |
| 1346 | `PC-S297-RETRO-OVERRIDES-F1F2F3F6` | **HOLDS-WIDER** | ai-dlc-skill |
| 1361 | `PC-S297-GATE-PROCEDURES-DISPATCH-NOT-MANDATED-BACKGROUND` | **HOLDS-MECHANISM-WRONG** | ai-dlc-skill |
| 1381 | `PC-S297-VALIDATE-STEERING-BUDGET-TRANSCRIPT-PROVENANCE` | **HOLDS-WIDER** | validators |
| 1406 | `PC-S299-UNREGISTERED-DRIFT-SCAN-SKIPS-CORE-FIXTURES` | **DUPLICATE-OF-PC-S303-UNREG** | reconcile |
| 1449 | `PC-S299-LEDGER-REVERIFY-SIGPIPE-FALSE-ABSENT` | **ALREADY-FIXED-v0.147.1** | reconcile |
| 1543 | `PC-S299-READOPT-DOSSIER-RENDERS-REASON-EMPTY` | **ALREADY-FIXED-v0.150.1** | reconcile |
| 1571 | `PC-S299-UPSTREAM-SHIPS-TWO-REVIEW-VERDICT-VOCABULARIES` | **HOLDS-MECHANISM-WRONG** | ai-dlc-skill |
| 1597 | `PC-S299-LEDGER-REVERIFY-MISATTRIBUTES-ABSORBING-VERSION` | **ALREADY-FIXED-v0.152.0** | reconcile |
| 1622 | `PC-S299-PREPUSH-NONREPRODUCING-FAIL` | **HOLDS-MECHANISM-WRONG** | fixtures |
| 1757 | `PC-S303-UNREGISTERED-DRIFT-SCANS-FIVE-OF-TEN-CORE-SUBTREES` | **FALSIFIED** | reconcile |
| 1862 | `PC-S298-WAIT-FOR-DELIVERABLE-NO-PROGRESS-EVIDENCE` | **ALREADY-FIXED-v0.168.0** | ai-dlc-skill |
| 1977 | `PC-S304-APPLY-SH-RESTAMPS-BEFORE-THE-WORKLIST-IS-DONE` | **HOLDS-MECHANISM-WRONG** | reconcile |
| 2028 | `ORPHAN-tail-of-archived-PC-S306` | **ALREADY-FIXED-v0.180.0** | reconcile |
| 2101 | `PC-S307-MACHINE-AUDITS-IS-A-CHILD-OF-4A` | **HOLDS** | ai-dlc-skill |
| 2170 | `PC-S308-SELF-UPDATE-INSTALLS-THE-VALIDATOR-THAT-BLOCKS-ITS-OWN-PUSH` | **ALREADY-FIXED-v0.185.0** | update-skill |
| 2231 | `PC-S311-ENTRY-SWALLOWED-LITERAL-BACKSLASH-U` | **HOLDS** | reconcile |
| 2306 | `PC-S312-RETRO-REPLAY-HARNESS-NOT-ABSORBED` | **NOT-UPSTREAM** | consumer-local |
| 2341 | `PC-S312-SPRINT-STATUS-CHECK-STORIES-ONE-FIELD-OF-FIVE` | **HOLDS-MECHANISM-WRONG** | validators |
| 2372 | `PC-S312-TRUNK-PUSH-DECLINES-TO-POLICE-THE-TRUNK` | **NOT-UPSTREAM** | consumer-local |
| 2411 | `PC-S312-PROTECTED-CORE-PATHS-STAYS-RETIRED` | **NOT-UPSTREAM** | consumer-local |
| 2436 | `PC-S312-MUTATION-RED-ANCHOR-STAYS-RETIRED` | **NOT-UPSTREAM** | consumer-local |
| 2465 | `PC-S312-STRAY-SCAN-ARM-STAYS-RETIRED` | **NOT-UPSTREAM** | consumer-local |
| 2492 | `PC-S312-STRAYS-DOES-NOT-NORMALIZE-AN-ABSOLUTE-PATH` | **HOLDS** | validators |
| 2546 | `PC-S312-S239-1-HARDENING-CALLS-PRE-RELOCATION-PATHS` | **NOT-UPSTREAM** | consumer-local |
| 2576 | `PC-S312-FIXTURE-PROVENANCE-ARM-HAS-NO-LIVE-DRIVER` | **NOT-UPSTREAM** | consumer-local |
| 2598 | `PC-S312-EXPECTED-VALIDATORS-WORD-SPLIT-EXCLUDES-FLAGS` | **NOT-UPSTREAM** | consumer-local |
| 2630 | `PC-S312-PR-CLASS-TEST-A6-A7-ARE-UNREACHABLE` | **NOT-UPSTREAM** | consumer-local |
| 2655 | `PC-S312-FIX-FORWARD-CLASS-GATES-ON-NO-VALIDATOR` | **NOT-UPSTREAM** | consumer-local |
| 2680 | `PC-S300-CYCLE-STATE-RESOLVED-UNREACHABLE` | **ALREADY-FIXED-v0.247.0** | validators |
| 2785 | `PC-S300-RESOLUTION-RECORD-CITATION-CANNOT-OUTLIVE-ITS-SESSION` | **HOLDS** | validators |
| 2957 | `PC-S313-LEDGER-ROTATE-SPLITS-AN-ENTRY-AT-A-BOLD-ANNOTATION` | **HOLDS** | reconcile |
| 3018 | `PC-S314-PRECLASSIFY-BUCKETS-A-MODE-ONLY-CHANGE-AS-UPSTREAM-ONLY` | **HOLDS** | reconcile |
| 3088 | `PC-S315-EMIT-REPORT-REGION-OMITS-THREE-MANDATED-DETECTORS` | **HOLDS-WIDER** | reconcile |
| 3145 | `PC-S316-LEDGER-REVERIFY-DOES-NOT-NORMALIZE-CONSUMER-ABSOLUTE` | **ALREADY-FIXED-v0.301.0** | reconcile |
| 3190 | `PC-S316-ABSORPTION-DETECTOR-JOINS-ONLY-ON-NUMBERED-ANCHORS` | **ALREADY-FIXED-v0.275.0** | reconcile |
| 3244 | `PC-S316-LEDGER-REVERIFY-EXITS-0-SILENTLY` | **ALREADY-FIXED-v0.301.0** | reconcile |
| 3287 | `PC-S302-ADJUDICATION-RERUN-BASE-DISARMS-LC-A1` | **ALREADY-FIXED-v0.303.0** | update-skill |
| 3336 | `PC-S314-APPLY-SH-OVERWRITES-ITSELF-MID-RUN` | **ALREADY-FIXED-v0.316.0** | reconcile |
| 3375 | `PC-S314-NO-DETECTOR-LAYER-FILE-CITING-RETIRED-PATH` | **ALREADY-FIXED-v0.333.0** | layer-extensions |
| 3413 | `PC-S318-SELF-UPDATE-SLICE-CANNOT-CARRY-THE-FIXTURE-FIX` | **HOLDS** | update-skill |
| 3464 | `PC-S319-SUBJECT-DIGEST-IS-UNREADABLE-ONCE-ITS-ROW-STOPS-BLOCKING` | **ALREADY-FIXED-v0.331.0** | reconcile |
| 3507 | `PC-S328-NAMED-UPSTREAM-JOINS-ON-THE-FULL-SLUG` | **ALREADY-FIXED-v0.329.0** | reconcile |
| 3595 | `PC-S329-NAMED-UPSTREAM-DETAIL-INSTRUCTS-THE-CLOSE-ITS-STATUS-FORBIDS` | **HOLDS-MECHANISM-WRONG** | update-skill |
| 3647 | `PC-S330-LEDGER-ROTATE-STUCK-SET-CONTRADICTS-SKIP-RULE` | **HOLDS-MECHANISM-WRONG** | reconcile |
| 3719 | `PC-S302-FIXTURE-SUITE-POOL-UNREPRODUCIBLE-FAIL` | **ALREADY-FIXED-v0.367.0** | fixtures |
| 3749 | `PC-S302-RETIRED-LAYER-CONTRACT-READS-CLEAN` | **ALREADY-FIXED-v0.359.0** | reconcile |
| 3787 | `PC-S302-HARD-BLOCKERS-HAS-NO-POST-APPLY-GUARD` | **ALREADY-FIXED-v0.367.0** | reconcile |
| 3828 | `PC-S303-EFFORT-BINDING-COMMANDS-A-SLASH-COMMAND` | **ALREADY-FIXED-v0.367.0** | hooks |
| 3881 | `PC-S330-PREPUSH-LEAKS-GIT_DIR-INTO-EVERY-FIXTURE-SANDBOX` | **HOLDS-WIDER** | fixtures |
| 3918 | `PC-S330-STEP-2-NO-DISPOSITION-CONSUMER-MODIFIED-MACHINERY` | **HOLDS-MECHANISM-WRONG** | update-skill |
| 3980 | `PC-S330-A-CONTRADICTS-CORE-VERDICT-EXPIRES` | **ALREADY-FIXED-v0.369.0** | layer-extensions |
| 4052 | `PC-S333-SETTINGS-MERGE-CHECK-READS-AN-EMPTY-TEMPLATE-AS-A-VERDICT` | **HOLDS-WIDER** | reconcile |
| 4096 | `PC-S333-SKILL-RENDERS-THE-THEIRS-REF-UNQUOTED-AND-ZSH-EATS-IT` | **HOLDS-WIDER** | update-skill |
| 4153 | `PC-S303-BUDGET-SCRIPT-PASS-LINE-UNCONDITIONAL` | **ALREADY-FIXED-v0.372.0** | validators |
| 4184 | `PC-S303-RETRO-NO-CLOSE-RECORD-FOR-RESET-OR-ABANDONED-SPRINTS` | **ALREADY-FIXED-v0.372.0** | validators |
| 4216 | `PC-S303-POSTCOMPACT-RECOVERY-MANDATE-NO-STATED-EXCEPTION` | **ALREADY-FIXED-v0.372.0** | hooks |
| 4258 | `PC-S331-APPLY-SH-CO-EMITS-READOPT-AND-RETIRE` | **HOLDS** | reconcile |
| 4313 | `PC-S303-BUDGET-CHECK-EVIDENCE-FIND-PICKS-STALE-GATE-LOG` | **HOLDS-WIDER** | validators |
