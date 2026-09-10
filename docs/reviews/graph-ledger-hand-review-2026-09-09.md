# Hand-review worklist — 20 discharged-but-open push-candidate rows

**Produced by ai-dlc session `ai-dlc-17`, 2026-09-09, against consumer ledger md5
`47849b451bea46efa1e4cd03fe0695a1`.** Every verdict below was measured by driving the shipping
code at ai-dlc `HEAD` = `98acc996` = the consumer's own installed `version`/`commit`. Four
adjudicating hands, each finding re-derived by the lead with a control in the same invocation.

**This file is a DECISION LIST, not an instruction to re-derive.** The adjudication is done. What
remains is the write, and the write is the consumer's.

---

## What this is, and why these rows never closed

These 20 candidates are all **fixed and delivered**: each shipped in a release at or below
`0.542.0`, which this consumer has installed. Their ledger rows are open anyway, and the cause is
mechanical rather than anyone's oversight.

- **16 declare `verify: manual`.** `ledger-reverify.sh:1462` emits `HAND-REVIEW` for that verb by
  design — "no mechanical predicate by design; adjudicate the entry body against theirs". It can
  never emit `CLOSE-CANDIDATE`, so no number of closer runs will move them.
- **4 carry receipts anchored on text the fix KEEPS.** The closer says so itself in its
  `RECEIPTS-UNDECIDED` row: *"an anchor on text the fix KEEPS survives the fix, and the entry can
  then never close."*

Verified by running the closer from the consumer root at these refs: **26 HAND-REVIEW / 49
STILL-LIVE / 0 CLOSE-CANDIDATE.**

**The close is an ANNOTATION.** `entry_line_closes()` (`ledger-reverify.sh:1002`) stops emitting a
row once the ENTRY HEADING carries `ADOPTED UPSTREAM` or `WITHDRAWN`; `ledger-rotate.sh:212`
archives on the stricter form `**ADOPTED UPSTREAM (v<digit>`. No upstream code change is needed.

---

## Boundary — read before writing

**Only the 20 ids below.** The closer reports 26 HAND-REVIEW rows. The other ~10 are entries whose
fixes have **NOT** shipped: they are genuinely open work, and annotating one would retire a live
defect. That is the worst output this system has. The 20 here are the complete set that is both
`verify: manual`-or-stuck AND cited in an `origin/main` release commit.

**Line numbers are keyed on the entry SHAPE**, re-derived at the md5 above. If your ledger's md5
differs, re-locate by id — do not trust the line. One of these (`PC-S339`) has a CROSS-REFERENCE at
line 1821 inside a different entry; **its real heading is 2368.** An earlier cut of this worklist
had that wrong, and it would have annotated the wrong entry.

**Annotation form**, on the entry heading line, matching the archive's existing convention:

```
**ADOPTED UPSTREAM (v<version>, verified 2026-09-09).** <one sentence naming what shipped>
```

For a PARTIAL, the archive's own convention for a half-close applies — annotate the resolved half
and state the residue in the same breath:

```
**ADOPTED UPSTREAM (v<version>, verified 2026-09-09).** <what shipped>
**Owed follow-up, not closed by this:** <residue>, filed upstream as <BL-id>.
```

---

## RESOLVED — 12 rows, close clean

| line | id | version | what shipped |
|---|---|---|---|
| 2269 | `PC-S306-WORKTREE-DELIVERABLE-PATH-AMBIGUOUS-PRIMARY-VS-WORKTREE` | 0.429.0 | `implementation.md:130-160` item 7: a worktree teammate's deliverable path is always relative to its own worktree root. All 5 claims satisfied. |
| 2299 | `PC-S306-WAIT-BEAT-CANNOT-DISTINGUISH-SLOW-FROM-NEVER` | 0.429.0 | Three-way liveness vocabulary at `wait-for-deliverable.sh:521-540`, driven live; fixture PASS with 7 mutant kills. |
| 2321 | `PC-S306-GATE-REVIEW-ARTIFACTS-WRITTEN-OUTSIDE-SPRINT-SLOT` | 0.430.0 | `code-reviewer.md:71` + `qa.md:270-277` prescribe the `s<N>/` slot; invariant I99 proved able to fire by seeding an offender. |
| 2345 | `PC-S306-RETRO-AUTOCOMPACT-TRANSCRIPT-FILE-ASSUMPTION-UNVERIFIED` | 0.430.0 | The unconditional sentence is gone; `retro.md:704-717` narrows the rule and corrects the `find -newermt` form the entry proposed. |
| 1012 | `PC-S307-MACHINE-AUDITS-IS-A-CHILD-OF-4A-SO-EVERY-4A-SHADOW-SWALLOWS-IT` | 0.431.0 | Heading promoted to `###`; shipping `span_of` gives `4a 452-663` / `Machine Audits 664-687`. |
| 1647 | `PC-S318-SELF-UPDATE-SLICE-CANNOT-CARRY-THE-FIXTURE-FIX-THAT-UNBLOCKS-ITS-OWN-PUSH` | 0.437.0 | `self-update-fixtures.sh:713-760` refuses an omitting slice; driven on the exact historic range the filing measured. |
| 1745 | `PC-S331-APPLY-SH-CO-EMITS-READOPT-AND-RETIRE-FOR-ONE-SUBJECT-AS-IF-BOTH-WERE-OWED` | 0.439.0 | `apply.sh:812` emits `NOTE override-readopt-subsumed`; fixture PASS, 51 arms, 2 discriminating mutants. |
| 1873 | `PC-S303-SCOPE-CONFIRMATION-FIELD-OF-MISSES-BOLD-MARKDOWN-GRAMMAR` | **0.375.0** | `field_of()` strips `**`/`__`/backticks. **See the correction note below — this is NOT refuted.** |
| 2110 | `PC-S305-DISPATCH-GUARD-SED-PATTERN-BOLD-MISMATCH` | 0.481.0 | `ai-dlc-dispatch-guard.sh:320` takes both spellings; I104 binds three hooks byte-identically. |
| 2790 | `PC-S340-DERIVATION-CAPTURE-HOOK-ROLLS-BACK-THE-WHOLE-FILE-ON-A-REJECTED-BLOCK` | 0.474.0 | Parse half fixed. **Rollback half REFUTED**: the hook is `PostToolUse`, has no write path against the target, and a live rejected write leaves the file md5-unchanged. Nothing remains. |
| 2868 | `PC-S308-DISPATCH-GUARD-SPRINT-FIELD-INTERMITTENTLY-NULL` | 0.481.0 | Fix is in the hook, not the validator. Measured on THIS consumer: 118 rows since the 2026-09-06 install, **0 null**, against controls of 20-of-85 and 411-of-1252 in the pre-fix windows. |
| 2840 | `PC-S340-AUDIT-RULE-FILES-DRIFT-FINDINGS-IN-CORE-PROSE-ARE-NOT-CONSUMER-FIXABLE` | 0.520.0 | **Core half only.** Measured read-only on this consumer: `--fail-on=local` -> rc 0, 36 findings, `[core 36 / local 0]`; control `--fail-on=any` -> rc 1 on the same 36. Retro is no longer red over findings it may not fix. The entry's own split has expired in your favour — both files it named as the consumer's half now score 0. |

### Correction to carry: `PC-S303` is RESOLVED, not REFUTED

Upstream's own plan recorded this as REFUTED for seven batches, and that was **wrong in the
direction that discards a real filing**. `REFUTED` reads as *the premise was never true*. The
premise was true when filed and was FIXED.

Re-derived by lifting both implementations and driving them on byte-identical bold input: pre-fix
(`9b18af4d^`) returns `[**]` — the entry's own reproduction — and HEAD returns `[confirmed]`, with
a `cmp -s` control asserting the two function bodies differ. `git log -L` over the function returns
exactly two commits ever: `69a22e6b` (0.258.0, created it) and `9b18af4d` (**0.375.0**, fixed it).
`v0.482.0` touches that file **zero** times against a control of 5 files it does touch — it only
observed the state. **Annotate against 0.375.0.** Upstream's plan is corrected.

---

## PARTIAL — 8 rows, close the resolved half and cite the residue

Each of these shipped a real fix that satisfies some of the entry's claims. The rest is filed
upstream and is now tracked there. **Annotate the close AND the owed follow-up.**

| line | id | version | resolved | residue — filed upstream as |
|---|---|---|---|---|
| 1403 | `PC-S300-RESOLUTION-RECORD-CITATION-CANNOT-OUTLIVE-ITS-SESSION` | 0.248.0 | `--transcript-dir` fixes cross-session unverifiability, and the second consumption site is wired too. | A corpus PRESENT but lacking the citation fails CLOSED while an ABSENT one fails OPEN — supplying partial ground truth is worse than supplying none. **`BL-219`** |
| 690 | `PC-S297-PROVENANCE-FLAGLESS-FAIL-OPEN-BY-DEFAULT` | 0.379.0 | The `RETRO_PATH_RE` path-classifier half, with three same-run self-probes. | The flagless default: an ordinary file with no marker and no flag exits 0, and no `--allow-missing` opt-out exists. **`BL-220`** |
| 789 | `PC-S297-VALIDATOR-PASS-VS-NOTHING-TO-CHECK-CONVENTION` | 0.378.0 | The convention now exists: `EXAMINED NOTHING` declared once, rendered, bound by I93 (proved able to fire). | I93 refuses only the three RETIRED spellings, so a FOURTH seeds clean — the map's own comment predicted this. **`BL-221`** |
| 2368 | `PC-S339-WITHDRAWAL-COMMIT-BECOMES-THE-NEW-ATTRIBUTION` | 0.440.0 | The withdrawal commit is no longer ELECTED; all naming commits are emitted whole, real fix first, no version read off it. | It remains in every affected id's match set. **Deliberate** — the filed `Withdraws-attribution:` trailer was refused on measurement (it cannot reach an already-written commit and would have subtracted 0 of 16 rows). No upstream `BL-`; recorded here as a stated limit. |
| 2676 | `PC-S340-UNDECLARED-CUE-CANNOT-TELL-A-REFERENCE-FROM-A-DECLARATION` | 0.478.0 | The NEGATION class is fixed. | The CITATION class still fires: a row citing an `OWED-` id another row DECLARES lands in the same bucket as a genuine offender. The entry's own proposed fix targets an unconstructible state. **`BL-218`** |
| 2765 | `PC-S340-VALIDATE-ESCALATION-RESOLUTION-NONDETERMINISTIC-ON-BYTE-IDENTICAL-INPUT` | 0.480.0 | The greedy-capture defect is gone and **the nondeterminism is refuted AT RATE** — the filing predicts >20 second-verdict occurrences over 25 runs; 25 runs give one hash. The entry's stated mechanism (unordered iteration) does not exist. | `pending.md` is not the only input. The transcript CORPUS moves the verdict on byte-identical bytes, and the corpus identity is rendered on the FAIL path only — the fail-OPEN branch stays silent. **`BL-222`** |
| 2893 | `PC-S308-WRITE-FORMAT-STEERING-APPLIED-AD-HOC-NOT-UNIVERSALLY` | 0.517.0 | The enforcer exists and runs at both pre-push hooks, population JOINED not hand-listed; `pipeline-snapshot-history.md`'s header format is stated. | **This ledger is outside the enforcer's population** (0 hits vs control 1), and `upstream-routing.md` is byte-unchanged by the release with 0 steering directives vs a control of 9. The entry grammar remains unstated convention. **`BL-223`** |
| 3096 | `PC-S342-ADJUDICATION-ROW-PRESCRIBES-AN-ENTRY-EDIT-THAT-SPENDS-ITS-OWN-VERDICT` | 0.528.0 | `adj_spent_note()` distinguishes a spent verdict from a never-recorded one on the `HARD-LAYER-ADJUDICATION-MISSING` row. | One call site. The row the filing named (`EXTENSION-TITLE-MATCHES-CORE`, LC-E19) is WARN-level and unreached, and **the fixture is green because its oracle is pinned to the one covered code**. The ordering clause also lives inside the conditional note, so it arrives after a verdict is already spent. **`BL-224`** |

---

## Also filed upstream this session, not from these 20

Two defects surfaced while adjudicating, neither residue of any entry above. No action here; listed
so they are not re-filed from this side.

- **`BL-217`** — `code-reviewer.md:453-456` tells a worktree-isolated reviewer to write to the
  canonical checkout, which `implementation.md:130-133` forbids the lead to ask for, while `:118`
  names the code reviewer as a worktree target. `git blame` dates it to `e7ccffa9` (2026-07-05),
  predating the v0.429.0 fix. A precedence defect, not a contradiction — the compatible fallback
  already exists in the parenthetical, stated second.
- Item 7 of that protocol **has no enforcer**: nothing under `core/fixtures/`, `scripts/` or
  `core/scripts/` references it, against a control that resolves a fixture for an unrelated token.

---

## After the write

Re-run the closer from the consumer root, absolute paths, and confirm the HAND-REVIEW count fell by
20:

```
cd /Users/n8/git/graph && bash .claude/skills/ai-dlc-update/reconcile/ledger-reverify.sh \
  /Users/n8/git/ai-dlc 98acc996 /Users/n8/git/graph 98acc996
```

**Never run it with the process cwd at the ai-dlc root** — a distribution-root run has turned a
live `STILL-LIVE` into a `CLOSE-CANDIDATE`, and a false close retires a live entry.

Then `ledger-rotate.sh --check` before `--apply`, and **confirm the archive count MOVED**. A
rotation has been silently skipped and reported complete before.

Report which ids closed and which did not. A row that does not close after annotation is a finding
about the annotation form, not about the entry.
