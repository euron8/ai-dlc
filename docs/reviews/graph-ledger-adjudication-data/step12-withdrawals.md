# Step 12 — the 17 entries adjudicated and NOT filed

Phase 2 step 12 took the 59 live push-candidate entries to the working tree. **42 were filed as
`BL-021`..`BL-062` in `docs/backlog.md`; these 17 were not.** A filing that cannot be substantiated
is worse than none, so a dead premise is a legitimate and expected outcome — the measured base rate
of expired premises in this corpus is roughly one in two, and this pass came in at 29%.

**This file exists because the filed half and the withdrawn half have different homes.** The 42 live
in the backlog and are re-derived by `scripts/backlog-reverify.sh` on demand. The 17 have no such
home, and their evidence was produced in a session scratchpad that a later session cannot reach.
Phase 4's consumer brief needs exactly this material: for each, graph is being asked to retire an
entry it filed, and the reason has to travel with the ask.

Each section below is one batch agent's own words, verbatim, minus the entries it filed. The verdict
vocabulary is the brief's: **PREMISE DEAD** (already fixed, or the premise is false against the tree)
and **REFUSE** (the subject is a settled decision rather than a defect).

The population is derived, never hand-listed: 59 rows in `filing-population.tsv`, 42 `## BL-`
headings emitted into `docs/backlog.md`, leaving 17.

---

## Batch `layer-1`

# out-layer-1 — subsystem `layer-extensions`, pins 226 / 252 / 255 / 259

Four drafted `BL-` entries. Ids are the literal token `BL-XXX`; the lead numbers them.
Pinned ledger md5 verified `2fd444dcf406cdff728fe3c0c4352267` at 4356 lines; the 4355-line
prefix control hashes `d4e39a96a33c5c92adfe4c8457020064`, so the offsets are into the pinned
file and not into a neighbouring revision.

---


---


---


---


---

## Receipt falsifiability — measured, both directions

Every receipt above was run against the working tree today and against a seeded `mktemp` copy of
the same files with the anchor appended. The two sides are asserted to differ in the same
invocation:

```
BEFORE r1 exit=1   AFTER r1 exit=0     (rare_event appended to gate-validation.md)
BEFORE r2 exit=1   AFTER r2 exit=0     (fix-forward appended to deploy-validate.md)
BEFORE r3 exit=1   AFTER r3 exit=0     (` origin/main` appended to retro.md)
BEFORE r4 exit=1   AFTER r4 exit=0     (spec path appended under ai-dlc-update/)
```

The `r2` loose-anchor probe is the separate false-close measurement:
`grep -rqF 'fix-forward' core/` exits **0** today.

---

## Batch `layer-2`

# Batch `layer-2` — subsystem `layer-extensions`

Drafted `BL-` entries for pins 262, 265, 267. Pin 3980 is a **withdrawal candidate**
(PREMISE DEAD) and is reported at the bottom without an entry.

Derived against `ai-dlc` at `95e421a` / `VERSION` 0.372.0 and the reference consumer at
`510e4d9f5`, read-only. Pinned ledger md5 `2fd444dcf406cdff728fe3c0c4352267` verified;
control `sed -n '1,4355p'` gave `d4e39a96a33c5c92adfe4c8457020064`, so the offsets are this
file's.

---


---


---


---


---

# Not filed

## PREMISE DEAD — pin 3980, `PC-S330-A-CONTRADICTS-CORE-VERDICT-EXPIRES-LIKE-A-READING-AND-STOPS-BEING-SURFACED`

**Withdrawal candidate.** The fix shipped in 0.369.0 and the entry's own shape-independent
recipe now closes it.

The entry declines a substring receipt and prescribes a behavioural one instead: *"Build a
register whose only `contradicts-core` row declares no `owed`, then run `audit-layer-debt.sh`
against it. If that row is reported … the defect is closed."* Run verbatim against
`core/scripts/audit-layer-debt.sh` at `95e421a`, with the control in the same invocation:

```
ARM      one contradicts-core row, no owed, neutral reason
         -> CONTRADICTS-CORE WITHOUT AN `owed` (1)  — the row is listed
CONTROL  byte-identical row, verdict still-additive
         -> CONTRADICTS-CORE WITHOUT AN `owed` (0)
```

The control is what makes this a finding rather than a scan that flags everything: the arm
discriminates on the verdict, it does not fire on any row. Satisfiability checked in the other
direction too — a register where a **later** row on the same entry declares an `owed` reports
**0**, so the standard is reachable and the arm is entry-scoped, not row-scoped.

**Both fix shapes the entry prescribed were bypassed, and it closed anyway — worth recording.**
Neither landed: `core/schemas/layer-adjudication-register.json` still lists `required` as exactly
`["clause","entry","subject_digest","verdict","recorded_utc","reason"]` with `owed` marked
`"OPTIONAL"`, and `core/skills/ai-dlc-update/reconcile/layer-drift.sh:548` still resolves a
verdict by `select(.subject_digest == $d)` alone, verdict-agnostic. A third shape shipped instead
— a report arm in `audit-layer-debt.sh` — and the entry's refusal to anchor on either prescribed
shape is precisely why it did not report a false STILL-LIVE. `CHANGELOG.md` under
`## [0.369.0] — 2026-08-14` records the arm, its per-entry scoping, and a false-positive set
measured at two revisions (1 of 7, then 0 of 7).

Nothing to file. Recommend withdrawal against the run above.

---

# Adjudicated and NOT filed, within the filed rows

These are blocks the ledger rows name that do **not** reproduce. Recorded so the corrections are
not lost when the rows are struck.

| Row | Block | Verdict | Evidence |
|---|---|---|---|
| 262 | `Rule 919` Rule 19 model-derivation scope | **ABSORBED** | The block itself concedes the derivation half (*"This section carries no model-derivation procedure"*). The residue — which surfaces carry `model` — is stated three times in core: Rule 19's opening clause scopes it to Agent-tool spawns (`SKILL.md:636`); `core/hooks/ai-dlc-dispatch-guard.sh:99-101` and `:341-342` carry the party-persona case verbatim (*"a missing model is a normal state, not an error"*); `templates/settings.json.template` ships `cis`/`sm`/`tea`/`ux` with an effort and no model. |
| 262 | `Rule 924` analyst four-clause file-write | **ABSORBED** | (a)+(b) at `core/team-roles/analyst.md:24-29` — write to the canonical path, return `{artifact_path, summary, gaps}`. (c)+(d) at `SKILL.md:818` (*"as non-delivery and re-dispatch. Build no detector for this"*), `:1023`, and `steps/_gate-procedures.md:107`. Residue is a housekeeping SSOT-location claim, not a defect. |
| 262 | `Rule 925` gate-log auto-rotation | **REFUSE — settled against** | Countermands core on both axes. Trigger: the block says rotate at retro close *"not on a size threshold"*; `steps/gate-validation.md:691` rotates on a 25k threshold or an epoch boundary. Destination: the block writes `gate-log-archive-s<N>.md`; core's grammar is `s<N>/gate-log-archive.md`, and `core/scripts/migrate-artifact-paths.sh:158` treats the block's spelling as the pre-migration form. The operator already ruled on the sibling entry — pinned ledger lines 237-242 record *"Core wins per operator directive"* for the same countermand in `gate-validation-push.md` item 12. |
| 262 | pending-approval author-side marking (S253); no-self-schedule re-entry ban | **GONE FROM THE SOURCE** | Absent from `SKILL-push.md` at `510e4d9f5`: `pending-approval` 0, `S253` 0, `self-schedule` 0, `re-entry` 0; controls in the same invocation `Effort level` 1, `four-clause` 2, `gate log` 7, `Rule 19` 4. |
| 265 | script-based snapshot reset | **SUPERSEDED AND PARTLY COUNTERMANDED** | `core/scripts/rotate-snapshot-archive.sh` ships; `steps/route.md:534-546` mandates running it by name and **retires** the dated `pipeline-snapshot.archive.{ISO-timestamp}.md` spelling the block prescribes. |

---

## Batch `recon-1`

# batch recon-1 — `reconcile` subsystem, 4 rows

Pinned ledger md5 verified `2fd444dcf406cdff728fe3c0c4352267`, 4356 lines.

Dispositions: **2 FILE**, **1 PREMISE DEAD**, **1 REFUSE**.

---


Measured exit today: **1**. Reaches 0 when the `domain-local` bullet routes a block whose machinery
core depends on to a push decision; verified satisfiable by seeding that sentence into a `mktemp`
copy, asserting the sides differ, and re-running (exit 0).

---


Measured exit today: **1**. Probed on `mktemp` copies with the sides asserted to differ: a worklist
tally seeded beside `mech_fail=0` → 0; a second condition seeded on the guard line → 0; a comment
merely mentioning `worklist_n=` → stays 1. Exits 3, not 0, if either control token vanishes.

---

## NOT FILED — pin 1597, `PC-S299-LEDGER-REVERIFY-MISATTRIBUTES-ABSORBING-VERSION`

**PREMISE DEAD.** Fixed, and the fix is at the exact site the entry named.
`core/skills/ai-dlc-update/reconcile/ledger-reverify.sh:267-273` defines `absorbed_at()`, which
walks `git log -S"$sub" --reverse` over `BASE..THEIRS` and returns the VERSION of the first commit
where the substring appears. Both close rows now interpolate it: `:906` (`theirs_lacks` absorption)
and `:935` (`theirs_has` fix) both read `$av`, not `$TV`.

Control in the same invocation: the token `TV` occurs **14** times in the file, so the corpus is
live and greppable; the phrase `absorbed this at $TV` occurs **once**, at `:252`, inside the
comment recording the removal — the "fix quotes back its own anchor" shape, and the reason a
substring receipt on that phrase would have reported this entry still-live forever. Zero live
emitters use `$TV` for attribution.

The fix is also better than the entry asked for: the entry's own correction of itself was wrong.
It reports the tool said 0.147.0 and a hand correction said 0.146.0; `:257-259` records the
measured answer as v0.144.0 and notes both prior figures were wrong, "three releases apart, in a
record nothing re-derives". Phase-1's `ALREADY-FIXED-v0.152.0` verdict is confirmed.

---

## NOT FILED — pin 334, `layer-drift.sh EXTENSION-RESTATES-CORE matches on section number + title`

**REFUSE — settled design decision, and the entry itself already reclassified to a design dissent.**

The mechanism reproduces exactly. `core/skills/ai-dlc-update/reconcile/layer-drift.sh:1425` and
`:1456` are the two `emit EXTENSION-RESTATES-CORE` sites, both gated on `same_section "$t_ext"
"$t_up"` — a heading join. There is no body-overlap comparison, and no `adds-to:` grain: a
recursive grep for `adds-to` across `core/` returns rc=1, with a control on the same corpus
(`RESTATES-CORE` in 10 files) coming back non-zero.

But the cost is declared accepted upstream, in the current tree, in the entry's own terms.
`core/skills/ai-dlc/steps/gate-validation.md:142-153` is the Rule 26(c) block, and its
false-positive paragraph reads: "an additive extension that hooks a core check by reusing its
number and title is reported as a collision and must be refiled as an override reproducing the
section — friction on a legitimate entry, not data loss. Remove when core and consumer catalogs no
longer share a rendered namespace." That is this entry's complaint, priced, accepted, and given a
retirement condition.

Two further facts support the refusal rather than a re-file. `core/skills/ai-dlc/layer-contract.yaml`
LC-E5 sets this clause's level to `WARN`, not `ADJUDICATED` — it does not block `apply`, and it is
not eligible for the adjudication-register suppression that `adj_is_adjudicated()` applies to
ADJUDICATED codes. And the un-numbered sibling arm at `:1573` documents the asymmetry as
deliberate: it is "weaker than EXTENSION-RESTATES-CORE on purpose: a numbered anchor is an identity
claim, a prose heading is not, so this reports the match and does not prescribe the delete."

The entry has no `PC-` id and no `verify:` line, so no receipt exists to retire; the close channel
is a brief annotation, as the batch row states.

**Method note.** A grep for the literal phrase `friction on a legitimate entry` across `core/`
returned rc=1. That was a FALSE ZERO — the phrase wraps across a newline at `:151-152`. The control
(same corpus, token known present) came back non-zero and did not catch it, because the control
only establishes that the search ran. Reading the file caught it. A single-line grep cannot see a
wrapped phrase in prose, and nothing about the zero says so.

---

## Batch `recon-3`

# Batch `recon-3` — drafted `BL-` entries (subsystem: `reconcile`)

Three rows, three dispositions: **FILE / FILE / FILE**. All three receipts exit non-zero today
and were driven to 0 against a mutated copy in the same invocation.

---


---


---

---

## Batch `skill-1`

# batch-skill-1 — drafted entries

Subsystem `ai-dlc-skill`. Four rows adjudicated: **2 FILE, 1 PREMISE DEAD, 1 REFUSE.**
Pinned ledger md5 verified `2fd444dcf406cdff728fe3c0c4352267`, 4356 lines.

---


---


---

# Not filed

## PREMISE DEAD — pin 269, `extensions/steps-domain/stories-test-strategy-push.md`

Withdrawal candidate. Both named halves are upstream already.

- **out-of-scope AC** → `core/skills/ai-dlc/steps/stories-test-strategy.md:248-255`,
  "### Story-AC Out-of-Scope Declaration Rule": when a Day-0 survey enumerates more targets than
  the selected lane covers, the story MUST include an explicit out-of-scope-declaration AC naming
  uncovered targets verbatim, "verified at gate by confirming the named targets were not modified."
  Measured: `out-of-scope` = 3 in that file. Control in the same invocation: `acceptance` = 16 in
  the same file, and `copy-paste` = 0 — so the search discriminates.
- **Check-3a enforcement** → `core/skills/ai-dlc/steps/gate-validation.md:347-390`,
  "### 3a. Story validation origin check (story gates only)" with `<!-- CHECK_LOADED: 3a -->`,
  registered in the gate-type table at `:64` (`story → 3a, 3b, 5, 17, 24, 30, 31`). It carries the
  LR→AC discrimination verbatim: "**Gate FAILS** if any substantive element of the original
  requirement is not covered by a story acceptance criterion, REGARDLESS of whether the story's own
  ACs pass their validation," with a HARD_BLOCK remediation naming `requirement divergence`.

The only residue is the word "copy-paste": core states the mandate but ships no boilerplate AC
block. That is not filed. `core/skills/ai-dlc/templates/` holds six templates and none is an AC
form, and a copy-paste block in `steps/*.md` is resident context paid on every compaction —
`.claude/rules/resident-context.md` makes that a cost to justify, not a gap to close. The row
carried no receipt and no PC id, and the ledger's own section preamble at pinned lines 210-224
says of this list "Treat every line here as a lead to verify, not as evidence."

## REFUSE — pin 177, "Rule 18 has no carve-out for terse traceability citations"

Settled decision, refused on the merits, and the filing's premise does not survive contact with
core.

**The quoted text is not in Rule 18.** Rule 18 (`core/skills/ai-dlc/SKILL.md:615-627`) says a rule
must be "writable as a standalone mandate without supporting narrative" and delegates to
`rule-authoring.md`. It contains no sprint-or-story clause: `grep -c "sprint or story reference"
core/skills/ai-dlc/SKILL.md` = **0**, control `standalone mandate` in the same file = **1**. The
prohibition is at `core/skills/ai-dlc/rule-authoring.md:20`, the only file in `core/` carrying it
(control: `rule-authoring` = 13 files).

**Upstream already wrote a traceability carve-out, four lines above the prohibition, and it is the
opposite of the one requested.** `rule-authoring.md:15-19`: "Give a rule a stable identifier a later
rule can cite, and carry it in the rule's own heading: `Rule <n>` ... Cite a mechanism by its
invariant identifier in backticks: `I23`. **An identifier is a name and MUST NOT encode a sprint,
story, version, or date.**" The entry asks for `(PI-Sxxx-x)` tags and `Source: docs/retro/sprint-N.md`
pointers — identifiers that encode exactly what that sentence forbids. The tension the entry says
every retro must re-adjudicate is adjudicated, in the owning file, adjacent to the prohibition.

**It is mechanized and blocking, not merely stated.** `core/scripts/audit-rule-files.sh:242-267`,
Class 1a, tier 1: `ORIGIN_TAG = \bv\d+\.\d+\.\d+|\bS\d{2,4}\b`, with the header at `:238-241`
naming this as "the prohibitions rule-authoring.md states but nothing mechanized ... a violation on
sight, with nothing for a lead to weigh." `(PI-S169)` matches `\bS\d{2,4}\b`.

**And the "pervasive dependence" does not exist upstream.** The audit over its real 76-file corpus
reports `ORIGIN_TAG: CLEAN n=[]`, `ORIGIN_PARENTHETICAL: CLEAN`, `EMBEDDED_DATE: CLEAN`. Probed in
both directions on a `mktemp` tree before that zero was read: a seeded
`A rule that must hold (PI-S169). Source: docs/retro/sprint-169.md S258-DV-1` was FLAGGED tier-1 at
`core/rules/probe-offender.md:3`; a seeded near-miss citing `I23` and `Rule 18` stayed silent. The
117 lines the filing measured are the consumer's rulebook, which is not this tree's to sweep.

The duplicate the entry names, `PC-S295-RETRO-RULE18-STABLE-IDENTIFIER-TAGS`, is the half upstream
ADOPTED — `rule-authoring.md:15-19` is a stable-identifier rule. Pin 177's specific ask is the half
upstream rejected. They should not be merged and pushed together; the lead should close 177 as
refused and adjudicate the duplicate as adopted-in-part.

---

## Batch `skill-2`

# Batch `skill-2` — drafted entries (subsystem `ai-dlc-skill`)

Four rows in. **Three FILE, one REFUSE.** Pinned ledger md5 `2fd444dcf406cdff728fe3c0c4352267`
verified; control `sed -n '1,4355p'` gave `d4e39a96a33c5c92adfe4c8457020064`, so the pin is the
file the offsets were taken against.

All three receipts were run through the shipping engine — `bash scripts/backlog-reverify.sh` on a
throwaway ledger — and all three reported `STILL-LIVE`. A fourth control entry in the same
invocation (`verify: sh test -f core/skills/ai-dlc/steps/gate-validation.md`) reported
`CLOSE-CANDIDATE`, which is what establishes that the engine could have closed them and did not.

---


---


---


---

# REFUSED — not filed

## `PC-S296-DEPLOY-VALIDATE-NA-RITUAL`, pinned ledger line 715

**REFUSE**, and the premise is separately dead. Not written as a `BL-` entry.

**The premise.** The entry claims Steps 1/2/2b/4/4b of `deploy-validate.md` "each produce a
'nothing to check' determination" when the step is entered with a known-empty service diff.
`N/A` occurs exactly **once** in `core/skills/ai-dlc/steps/deploy-validate.md`, at `:292`, and
that occurrence is `- Visual verification: PASSED / N/A` inside Step 5's Production Validation
Checkpoint report template — none of the five named steps. Control in the same invocation:
`MUST` = **19** occurrences in the same file, so the search ran. None of the five is scoped on
diff emptiness either: Step 1 (`:15-30`) verifies gate passage and PR pre-staging and says the
pre-staging rule "applies UNIVERSALLY to all sprint-overall PRs, not gated on anchor count or
story count"; Step 2 is the deploy itself; Step 2b is scoped to units "with changed paths in the
sprint diff" (`:98-99`) and carries an explicit anti-vacuity clause at `:119-122` — "this gate
does not vacuously pass"; Step 4 is gated on `is_ui_epic == true` (`:245`); Step 4b is
"Hard Gate — Non-Skippable" (`:256`) scoped to deferred ACs. The four-N/A ritual is a consumer
reporting habit, not behaviour any text here produces.

**The refusal.** The entry argues for removal on the ground that "Per Rule 26(c) there is no
removal condition to state because it is not a safety mechanism." Two of the five steps it names
are labelled `Hard Gate` and carry explicit Rule 26(c) removal conditions —
`deploy-validate.md:137` (Step 2b, "retire only if deploy tooling is made to fail closed on a
non-fresh rollout") and `:272` (Step 4b, "retire once deferred-AC predicates are collected and run
automatically at deploy time"). Measured: `Removal condition:` = **2**, `Hard Gate` = **5**;
control `Removal conditional:` = **0**. The entry's own stated ground for removal is false for the
steps it would remove.

And the exemption class it proposes has already been ruled against in the same file. `:142-145`:
"The smoke test full profile MUST run at every deploy-validate regardless of which paths changed.
'No service deploy' does NOT exempt the sprint from smoke verification." That is a settled
decision about empty-diff exemptions, not an omission.

**No receipt.** The entry carries no `verify:` line — `verify:` occurrences in its pin span
(715-727) = **0**, control over the pin-577 entry's span = **2**. There is nothing to re-anchor,
which is consistent with the batch file's `no-receipt` channel reason.

---

## Batch `skill-3`

# out-skill-3 — batch `ai-dlc-skill` (pins 1269, 1346, 1361, 1571)

Two FILE, two PREMISE DEAD. Only the entries under **FILINGS** are for `docs/backlog.md`.
Both receipts were run against this working tree and both exit **1** today; both were then run
against a mutated copy carrying the fix and both exit **0**.

---

# FILINGS



---

# WITHDRAWAL CANDIDATES — do not file

## pin 1269 — `PC-S297-CHECK16-SCOPE-AMBIGUITY` — PREMISE DEAD

The entry's subject is a sentence that no longer exists, and the decision whose ambiguity it named is
no longer made by anyone.

Measured in one invocation on `core/skills/ai-dlc/steps/gate-validation.md`: the filed phrasing
`Grep changed hot-path files` = **0**; control `hot-path` in the same file = **4**. The entry's own
0.246.0→0.248.0 re-anchor note had already measured this and recorded it as absent at both refs.

Check 16 today (`:977-1038`) is a pure delegation: "Run `scripts/ai-dlc/validate-stub-audit.sh` over
the gate's `changed_files` set… **Do NOT re-derive the elements by hand: read its exit code and its
counts**", followed by five exit-code dispositions and the sentence "**The regexes are the script's,
not this paragraph's**". The ambiguity mattered when an agent performed the grep and chose the scope;
that agent no longer chooses anything.

The residual is true and I am not filing it: neither the check body nor
`core/scripts/validate-stub-audit.sh` states whether the audit is added-lines-only or whole-file.
Measured — `added line`, `whole-file`, `whole file` in those two files: the only two hits are
`gate-validation.md:75` and `:686`, both about how much of a file to READ, neither about audit scope.
The behaviour is whole-file by construction: `--changed-from` resolves through
`git diff --name-only` (`validate-stub-audit.sh:100`), a FILE-level diff, and the scan at `:178-181`
slurps the whole file and walks every line of it. Two reasons not to file it. It has **no mechanical predicate** — the
ask is that core STATE something, and every anchor for a statement is a phrasing the filing invented,
which is the receipt convention's own named failure and why the consumer entry sits at
`verify: manual`. And whole-file is defensible rather than accidental: the four elements require a
stub to carry a resolvable `Item N`, so a whole-file audit says "your hot-path files carry disciplined
stubs", which is a coherent contract and not a bug.

Withdrawal recommended. If the operator wants the scope stated anyway, that is a documentation task
with a `manual` receipt, not a backlog defect.

## pin 1346 — `PC-S297-RETRO-OVERRIDES-F1F2F3F6` — PREMISE DEAD

The entry is self-discharging and was discharged by its own act. Its predicate, in its own words, is
"were these ever filed" — "Filing this consolidated entry closes the 'were these ever filed' question"
— and its evidence is a grep of the CONSUMER's ledger, not a claim about any ai-dlc file. It carries
no rule bodies at all, deliberately (Rule 25(a)). It has stayed LIVE only because `verify: manual` has
no mechanical resolver.

Its cited path is stale and I repointed rather than closed on it: `docs/retro/sprint-292.md` does not
exist in the consumer; the file is `docs/retro/s292/retro.md` (control: `docs/retro/` holds 296
entries). Read there, the cluster is audit finding A#1 plus A#2, both under operator disposition
2026-07-18: six rule layers whose targets are core files are to travel upstream rather than be
shadowed locally.

**The one member of that cluster ai-dlc can check by itself is FIXED.** A#2 claimed
`protected-path-editor.md`'s Ownership section asserts it edits `SKILL.md` / `steps/*.md` /
`team-roles/*.md` in place, contradicting `core-manifest.md`. Today
`core/team-roles/protected-path-editor.md:25-29` reads "The protected-path catalog ONLY, and ONLY the
specific paths named in your dispatch story's `protected_paths` frontmatter", and `:39-43` routes the
per-path answer to `core-paths.sh --is-core`, "the same derivation the edit-time guard uses". Control:
the file still names `core-manifest.md` twice, so the section was rewritten, not deleted.

**Reported, not filed** — the six rule bodies. They live only in the consumer's retro table
(`docs/retro/s292/retro.md:420-431`) and each is a separate design question this batch cannot
adjudicate: F1 gate-2 discharge write-back + snapshot grep-provenance; F2 derive `hard_block_count`,
stop storing; F3 pre-mutation consumer-trace + `REDIRECTED` tier; F4-core fallback-fixture rule +
capital-path fixture severity + review swap-in + magnitude gate; F6 teammate-wait never uses the pause
flag; F10-gate trace-the-trigger's-input + revert-control completeness. Spot-measured against `core/`
with a control (`run_in_background` = 12 files): `REDIRECTED` = **0** files, `revert-control` = **0**,
`trace the trigger` = **0**, so F3 and F10-gate have certainly not arrived; F6's substance appears to
have landed independently via Rule 29 (`ai-dlc-continue.sh:568` routes a teammate wait to the beat and
the pause flag to "no next action"). The retro itself records dissent on F1 and F4 (SM-vs-QA,
Architect-vs-TEA), so these are contested proposals from a consumer's retro, not defects in this
distribution.

Filing them as one `BL-` entry would produce exactly the artifact
`core/fixtures/ledger-reverify-unfalsifiable/README.md` measures 13 of: an entry ai-dlc cannot close
without re-reading a consumer tree. **This needs an ai-dlc operator scope decision, one layer at a
time, not a filing.**

---

## Batch `small-1`

# batch-small-1 — drafted BL- entries

Pinned ledger md5 verified `2fd444dcf406cdff728fe3c0c4352267` (4356 lines); the off-by-one
control `sed -n '1,4355p'` gave `d4e39a96a33c5c92adfe4c8457020064`, so the pin is exact.

Three entries to FILE, one PREMISE DEAD. Dispositions and hesitations are at the bottom.

---


---


---


---

# NOT FILED

## PREMISE DEAD — `PC-S299-PREPUSH-NONREPRODUCING-FAIL`, pinned ledger line 1622

Withdrawal candidate. The entry is a self-declared **LOW CONFIDENCE, not diagnosed** record of
two non-reproducing failures in July 2026, carrying `verify: manual`. Its subject survives but
its mechanism does not.

**The named fixture passes today.** `bash core/fixtures/apply-drift-refile/run.sh` from the repo
root: `apply-drift-refile: PASS`, rc=0, and the specific assertion the entry quotes is still
present and still green — `core/fixtures/apply-drift-refile/run.sh:119-122`, "apply.sh with no
map_consumer did NOT fail closed". So the subject is live and the check can still fire; what
failed is the diagnosis.

**The stated mechanism is false against this tree.** The entry concludes "a scratch-state race
between consecutive fixtures is the shape to look at first" and points at "the fixtures' own
scratch/seed handling". `core/fixtures/apply-drift-refile/seed.sh:18` allocates a unique
`mktemp -d "${TMPDIR:-/tmp}/apply-drift.XXXXXX"` per run, and every path the fixture touches —
`$WORK`, `$W2`, `$MUTDIR`, `$STAMP`, `$LONE` — resolves under it, with `trap 'rm -rf "$WORK"'
EXIT` at `:8`. Grepped for writes outside that root, the only three hits are a command
substitution, a comment, and `printf ... > "$STAMP"` where `$STAMP` is itself inside `$WORK`.
There is no shared scratch path for consecutive fixtures to race over.

**The flake class already has a filed entry, and it is a different fixture with a diagnosed
cause.** `docs/backlog.md:173` is `BL-008` — `suite-dispatch-order` flaking under the pool
because it sorts on wall-clock durations — observed `ok` / `FAIL` / green-solo on one unchanged
tree. Filing PC-S299 as well would add a second permanently-`manual` row for the same class with
strictly less mechanism behind it.

**A better-supported mechanism for the same class is the first entry in this batch.** A leaked
`GIT_DIR` redirects a fixture's sandbox git operations onto the real repository, fires only when
the push comes from a linked worktree, and would present exactly as a non-reproducing failure.
`apply-drift-refile/run.sh:27` uses `git -C "$DIST" show "$THEIRS:..."`, which an exported
`GIT_DIR` overrides. **I did not measure that this caused the 2026-07 observations and it is
stated as a hypothesis, not a finding** — the failing runs are a year gone and were never
captured. It is recorded so a third occurrence has somewhere to look.

Recommendation: withdraw. If the lead prefers to keep a placeholder for a third occurrence, it
belongs as a note on `BL-008` rather than as its own entry.

---

# Dispositions

| pin | label | disposition |
|-----|-------|-------------|
| 3881 | `PC-S330-PREPUSH-LEAKS-GIT_DIR-INTO-EVERY-FIXTURE-SANDBOX` | **FILE** — correction WIDER |
| 701 | `PC-S296-PIPELINE-POSITION-MUST-BE-EDITED-IN-PLACE` | **FILE** — different cause, direction inverted, consequence wider |
| 276 | `extensions/roles/dev-push.md` | **FILE** — correction NARROWER, 3 items → 2 |
| 1622 | `PC-S299-PREPUSH-NONREPRODUCING-FAIL` | **PREMISE DEAD** — withdraw |

---

## Batch `val-1`

# batch val-1 (subsystem `validators`) — drafted entries

Pinned ledger md5 verified `2fd444dcf406cdff728fe3c0c4352267`, 4356 lines.

Four rows in. **Two FILE, two PREMISE DEAD.** Drafted entries first; the two withdrawals and
one out-of-batch note follow.

---


---


---

# NOT FILED — withdrawal candidates

## pin 118 — `validate-retro-evidence.sh` → delegate the provenance-shape assertion — **PREMISE DEAD**

The entry's own string-level claim re-derives TRUE and is misleading. `core/scripts/validate-retro-evidence.sh`
contains **0** occurrences of `validate-provenance-block` (control, same invocation, same file:
`retro` = **53**). But the coverage the delegation was meant to add is already present, at two
composition sites, on the same artifact:

- `core/skills/ai-dlc/steps/gate-validation.md:1067-1071` — *"Retro gate: run
  `scripts/ai-dlc/validate-provenance-block.sh docs/retro/s<N>/retro.md` AND
  `scripts/ai-dlc/validate-retro-evidence.sh <N>`. Both must exit 0."* Both validators, one gate,
  same retro doc.
- `core/ci-templates/validate-retro-compliance.yml:72` and `:78-83` — the same workflow runs
  `validate-retro-evidence.sh` and then `validate-provenance-block.sh` on the retro doc.
- `core/skills/ai-dlc/steps/retro.md:826-827` names the ownership deliberately: the provenance
  validator *"owns the block's shape and is also its own CI step."*

So the residual is co-location, not coverage. What the entry asks for is a THIRD invocation of a
validator already run twice against the same file at the same gate, and its own stated rationale —
"defense-in-depth without a second copy of the predicate" — is already satisfied on the half that
matters: there is exactly one copy of the predicate, and `validate-retro-evidence.sh` duplicates
none of its regexes (its `transcript_path` occurrences at `:180-444` are a filesystem path variable,
not the provenance field). `mechanism-design.md` says to retire redundant enforcement rather than
port it forward.

Direction of the correction: **narrower than filed, to zero.** The 2026-07-23 annotation's own words
— "core runs provenance separately" — are accurate and read as a gap when they describe the design.
Half (a), the `origin/<branch>` resolution, is present at `:140-146` as the annotation says.

Recommend withdrawal. If the lead disagrees and wants it filed, it should be filed as a REFUSE
(settled design), not as a defect — I did not write a receipt, because a receipt asserting the
absence of a redundant call would close the moment someone added a call that changes no outcome.

## pin 139 — `validate-mandatory-rules.sh` subset flags + `gate_log_rotation_ok` — **PREMISE DEAD**

Duplicate of pin 1011 as the batch says, and independently dead on its own remaining half.

The generalizable claim the entry leads with — the additive subset-mode flag pattern — **LANDED**:
`--check-clean-tree` occurs **4** times in `core/scripts/validate-mandatory-rules.sh` (`:49`, `:57`,
`:64`, `:67`). Same file, same invocation: `--check-gate-log-rotation` = **0**, `gate_log_rotation_ok`
= **0**, and `rotation|rotate` = **0**.

That third zero is the one that decides it. There is no gate-log-rotation predicate anywhere in that
script to share, so `gate_log_rotation_ok` cannot be "a single predicate shared by the inline
pre-flight and the flag" upstream — there is no inline pre-flight. Core owns gate-log rotation
elsewhere: `core/scripts/validate-artifact-budget.sh:412-416` carries the `rotate` action table
(`gate-log.md|25000|rotate`) and `gate-validation.md:138-139` states the rotation contract. Control:
`gate-log` appears in **33** files under `core/`, so the concept is present and it is simply not in
this validator.

Pin 1011 already adjudicated the same subject and recorded that the fork's
`--check-gate-log-rotation` "did NOT adopt (its sole consumer, `test-gate-log-rotation-preflight.sh`,
was retired; no live gate used it)". Filing a BL- to add a subset entrypoint for a check core does
not have, whose only caller was retired, is a feature request against a settled boundary.

Direction of the correction: the entry is **two claims, one landed and one without an upstream
subject**. Recommend withdrawal, with pin 1011 as the surviving record.

---

# Out of batch — reported, not acted on

**NOTE.** `core/scripts/validate-escalation-resolution.sh:103` —
`--any-authorized) ANY_AUTHORIZED=1; ESCALATIONS="${2:-}"; shift 2 ;;` — makes `--any-authorized`
take the pending.md path as its OPERAND. The live caller passes it that way
(`core/scripts/core-paths.sh:345`: `--any-authorized "$ESC"`), so nothing in-tree is broken. But
invoked with the flag in trailing position (e.g. `--escalations <path> --any-authorized`, which the
flag's name and the header's prose both invite) `$#` is 1, bash's `shift 2` is a no-op, and the
`while [ $# -gt 0 ]` loop at `:96` **never terminates**. Measured: two separate invocations left
running, one for 5m41s by `ps -o etime`, and `bash -x` shows the same three trace lines repeating
with `$#` never decreasing. It spins forever where it should have exited 2 on a bad argument. Found
while probing pin 654; outside my batch, not filed.

---

## Batch `val-2`

# batch val-2 (subsystem `validators`) — 4 entries, 0 filings

Pinned ledger md5 verified `2fd444dcf406cdff728fe3c0c4352267`, 4356 lines.

**All four are withdrawal candidates.** No `BL-XXX` entry is drafted below, because none of the
four defects reproduces against this working tree. Two of them (pins 931, 798) carry a phase-1
verdict of `HOLDS-MECHANISM-WRONG`; my re-derivation puts both at PREMISE DEAD, and the
divergence is stated per entry with the measurement that produced it.

---

## Pin 687 — `PC-S296-SNAPSHOT-BUDGET-UNENFORCED-AT-GATES`

**Disposition: PREMISE DEAD.** Phase 1 said `FALSIFIED`; concur, and the falsification is
older than the filing.

The entry's headline is "Check 14 refreshes the snapshot and Check 15 verifies it, and neither
reads its size". Both halves are false today:

- `core/skills/ai-dlc/steps/gate-validation.md:873` — Check 14 runs
  `scripts/ai-dlc/verdict.sh validate-artifact-budget --only pipeline-snapshot.md` under the
  heading at `:870`, "**Snapshot budget (Rule 25(d)) — this check FAILS if the snapshot is over
  it.**", and `:887` states `Exit 1 → **Check 14 FAILS**`.
- `gate-validation.md:951` — Check 15 verifies the Check 14 evidence cell mechanically via
  `verdict.sh validate-artifact-budget --check-evidence`; `:953` states
  `Exit 1 → **Check 15 FAILS.**`
- The blocking-and-verifying arm is implemented at
  `core/scripts/validate-artifact-budget.sh:733-831`; `:826` is the emitter that fails a
  Check 14 row claiming PASS while citing tokens past the ceiling.

Counted with a control in the same invocation, over `gate-validation.md`:
Check-14 blocking invocation = **1**, Check-15 `--check-evidence` invocation = **1**,
control (the entry's own phrasing `neither reads its size`) = **0**.

**Direction of the correction: the entry was already wrong when it was filed, not overtaken
by a later fix.** At `v0.122.0` — the release the consumer was reconciling *from* when this was
filed on 2026-07-22 — `2560ef8:core/skills/ai-dlc/steps/gate-validation.md` already carried
both `**Snapshot budget (Rule 25(d)) — this check FAILS if the snapshot is over it.**` (:721)
and `Exit 1 → **Check 14 FAILS**` (:738), with an impossible-string control at the same rev
returning 0. The Check-15 half (`--check-evidence`) is absent at `v0.122.0` (0 hits) and
present at `v0.125.0` (1 hit), shipped by `f491d64 feat(v0.123.0): a gate cited a passing
budget check that had failed at every commit around it`.

So the entry's Check-15 observation was a real gap for one release; its Check-14 observation was
false on the day it was written. Its own proposal — "the size read belongs there, at Check 14,
at zero marginal cost" — is what the tree already did.

`gate-validation.md:929` now carries the entry's own retro §4a reading verbatim: "A snapshot
over budget means the schema stopped being enforced at gate passages. **The gates that let it
grow are the finding — not the file.**"

Reproduce:

```sh
cd /Users/n8/git/ai-dlc && \
printf 'check14=%s check15=%s control=%s\n' \
  "$(grep -c 'verdict.sh validate-artifact-budget --only pipeline-snapshot.md' core/skills/ai-dlc/steps/gate-validation.md)" \
  "$(grep -c 'verdict.sh validate-artifact-budget --check-evidence' core/skills/ai-dlc/steps/gate-validation.md)" \
  "$(grep -c 'neither reads its size' core/skills/ai-dlc/steps/gate-validation.md)"
```

---

## Pin 798 — `PC-S295-RETRO-COLLAPSE-PAUSE-FLAG-AND-BOUNDED-JOIN`

**Disposition: PREMISE DEAD**, with a REFUSE ground behind it. Phase 1 said
`HOLDS-MECHANISM-WRONG`; I diverge — the entry's central premise is mechanically false, not
merely mis-described.

The entry asks to collapse Rule 3's pause flag and Rule 29's bounded join as "two separate
mechanisms addressing one underlying failure: the lead advancing while something it does not
control is still outstanding". Both mechanisms are live and both are arms of
`core/scripts/validate-steering-budget.sh` — Check B at `:527-562` (pause flag) and Check C at
`:564-585` (bounded join) — so that much of the entry re-verifies.

**They fire on opposite conduct, and the act that discharges one is the act the other
forbids.** Both arms read the same predicate, `isAdvancing` at `:364`. Check B fires *when it
is true* (`:555-559`, an advancing call found while the flag is uncleared). Check C is *reset*
by it (`:581`, `else if (isAdvancing(b)) run = 0`). Measured behaviourally by driving the
shipping validator with `--transcript` on three synthetic transcripts, controls in the same
invocation:

| transcript | content | A | B | C | D | `--count` |
|---|---|---|---|---|---|---|
| t1 | operator steer, then 7 wait beats, no advancing call | PASS | **PASS** | **FAIL** | PASS | 1 |
| t2 | operator steer, then one `Agent` call | PASS | **FAIL** | **PASS** | PASS | 1 |
| t3 | t1 with one `Agent` call inserted mid-run | PASS | **FAIL** | **PASS** | PASS | 1 |
| control | empty transcript | — | — | — | — | **0** |

t3 is the decisive row: inserting a single re-dispatch discharged Check C entirely and it is
the same call Check B reports as a steamroll. A collapsed single mechanism would have to hold
both polarities at once, which leaves a lead with an outstanding steer and an exhausted wait
sequence no compliant action at all. The two are complementary halves of one predicate, not
duplicate detectors of one failure.

Secondary ground for REFUSE, recorded separately because it is a different kind of objection:
the entry's whole evidentiary base — "both arms fired in S295 and each ran FAIL → HARD_BLOCK →
OVERRIDDEN in the same session" — is consumer sprint conduct. **I did not measure it and it was
not available to me**; the reference consumer is read-only for this pass and the ledger is
pinned. That is a limit on the dissent's support, not on the refutation above, which is derived
entirely from the distribution's own code.

Reproduce (rebuilds the three transcripts and runs the shipping validator):

```sh
cd /Users/n8/git/ai-dlc && D=$(mktemp -d) && \
beat(){ printf '{"type":"assistant","timestamp":"2026-08-17T00:00:%02dZ","message":{"content":[{"type":"tool_use","id":"b%s","name":"Bash","input":{"command":"sleep 5; [ -f _bmad-output/x.md ] && echo y"}}]}}\n' "$1" "$1"; }; \
op(){ printf '{"type":"user","timestamp":"2026-08-17T00:00:00Z","message":{"content":"stop and look at this"}}\n'; }; \
adv(){ printf '{"type":"assistant","timestamp":"2026-08-17T00:00:%02dZ","message":{"content":[{"type":"tool_use","id":"a%s","name":"Agent","input":{"description":"go"}}]}}\n' "$1" "$1"; }; \
{ op; for i in 1 2 3; do beat $i; done; adv 4; for i in 5 6 7 8; do beat $i; done; } > "$D/t3.jsonl"; \
bash core/scripts/validate-steering-budget.sh --transcript "$D/t3.jsonl"; rm -rf "$D"
```

Run it under `bash -c`; the function definitions do not survive zsh here.

---

## Pin 931 — `PC-S297-POOL-LOOP-SUBSHELL-TRAP-UNDOCUMENTED`

**Disposition: PREMISE DEAD.** Phase 1 said `HOLDS-MECHANISM-WRONG`; I diverge. The entry's
*literal* observation re-verifies, and its *justification* — the reason the comment was asked
for — is false in both of its clauses.

Literal observation, confirmed: `core/scripts/validate-artifact-budget.sh:926-934` accumulates
`POOL_TOTAL` in a `while IFS='|' read` loop closed by `done < "$POOL_TMP"`, with no comment at
that site.

**Clause 1 — "The failure is silent and passes the gate" — false. A shipping fixture kills the
mutant.** I built the exact regression the entry names (`cat "$POOL_TMP" | while … done`) in a
sandboxed copy of `core/scripts` + `core/schemas` and ran
`core/fixtures/whole-read-pool/run.sh` against both copies, asserting the two differed before
reading the comparison:

```
baseline exit=0  FAILs=0
mutant   exit=1  FAILs=2
  FAIL  four oversized artifacts did not breach -- exit 0
  FAIL    the label disagrees with the row set: WHOLE-READ POOL (0 planning artifacts)
```

`run.sh:185-204` is the arm — headed "The pool actually BINDS ... Controls in both directions,
so neither verdict is an accident of the fixture's file sizes" — and `:341` is the label arm.
The regression is loud, at the pre-push gate, in two independent assertions. `whole-read-pool`
is a SHIPPING fixture (present in `scripts/uninstall.sh`, `core/skills/ai-dlc/core-manifest.md`
and `core/skills/ai-dlc/enforcement-map.yaml`, no `.dist-only`), so the consumer that filed
this entry already runs the guard.

**Clause 2 — "Upstream has the redirect and no explanation of why it must stay" — true only of
that one site; the file explains the trap twice.** `:838-840` ("The subshell channels. These
exist because the scan loops run on the right of a `|` and cannot export a variable back") and
`:1004-1007` ("The `while` above runs in a subshell (pipe), so BREACH cannot escape it. The
temp file is the channel. Deliberate: …"). The entry's own text concedes this — "Same trap the
breach file below documents." The correction is NARROWER than the filing: what is missing is
adjacency at one of three sites, not an explanation.

What remains is a request for a comment where a two-assertion shipping fixture already blocks
the regression and the same file states the reason 70 lines below. **No receipt is possible
either** — the entry itself was re-classified to `manual` in 2026-07-27 after its
`theirs_lacks "not a pipe"` anchor produced a FALSE `CLOSE-CANDIDATE`, and any replacement
anchors on predicted comment prose, which is the same defect one release later.

**My hesitation, stated plainly:** the entry's literal sentence is true, and a reasonable
author could still file a one-line `verify: manual` doc item asking that the site cite
`core/fixtures/whole-read-pool` by name. I did not, because the backlog's bar is "real and
measured", the receipt would be unrunnable, and the entry's stated reason for existing is
measurably false. If the lead wants it filed anyway, the correct entry is "cite the existing
guard at the site", not "document the trap" — and it should say so.

Reproduce: see the mutant harness in the report back to the lead; it needs `core/scripts` and
`core/schemas` copied into a temp root, because the fixture resolves its validator from
`$HERE/../../..`.

---

## Pin 1069 — `PC-S297-LOCKED-ANCHOR-VALIDATOR-VACUOUS`

**Disposition: PREMISE DEAD.** Phase 1 said `ALREADY-FIXED-v0.280.0`; concur, and the entry's
own text anticipated this outcome ("**ADJUDICATE BEFORE PUSHING — the premise may be dead.**
… if that exemption is correct by design, this entry should be retired rather than pushed").

The residual the entry names is "a block citing only `requires_context:` … is never
byte-matched against the anchor's source". Two separate things are true of that today, and
together they close it:

**The vacuity is fixed.** `core/scripts/validate-locked-anchor.sh:451-486` resolves every load
pointer: the artifact must exist on disk (`:470`) and the cited anchor must be present in
it (`:481`), with `pointers_checked` reported at `:620`. `CHANGELOG.md:5648-5650`,
`## [0.280.0] — 2026-08-06`, "Check 3b verified nothing, on every story, for its entire life —
the load pointer is now resolved and the byte-match is scoped to the anchor it cites". So a
`requires_context`-only block is no longer a block that "scores identically to one that cited
correctly" — the header at `:21-28` records the measurement that motivated it (34 of 47
pointers in a 998-story corpus named an absent anchor).

**The remaining byte-match exemption is a stated, reasoned design decision**, in three places
in the shipping file: `:17-19` (the contract), `:451-452` (why matching abridged bullets would
"red every honest cite-by-reference block"), and `:496-509` (why the guard fires on
`bullets and no requires_context`, not on `not sources`). That is the deliberate upstream
ruling the entry asked for. Under the brief's third outcome this is also a REFUSE: the subject
is a settled decision, and the settlement is documented at the emitter.

Measured with controls in the same invocation over `validate-locked-anchor.sh`:
`is never byte-matched` = **1** (the entry's current receipt substring, so its own
`theirs_has` predicate already resolves CLOSE-CANDIDATE); `requires_context anchor byte-match`
= **0** (the prior unfalsifiable receipt, still absent); pointer-resolution failure emitters =
**2**; control emitter that must not exist (`requires_context bullets did not byte-match`) =
**0**.

Reproduce:

```sh
cd /Users/n8/git/ai-dlc && \
printf 'exemption=%s prior-anchor=%s emitters=%s control=%s\n' \
  "$(grep -c 'is never byte-matched' core/scripts/validate-locked-anchor.sh)" \
  "$(grep -c 'requires_context anchor byte-match' core/scripts/validate-locked-anchor.sh)" \
  "$(grep -c 'requires_context artifact' core/scripts/validate-locked-anchor.sh)" \
  "$(grep -c 'requires_context bullets did not byte-match' core/scripts/validate-locked-anchor.sh)"
```

---

## Batch `val-3`

# Batch val-3 (subsystem `validators`) — drafted entries

Four rows, four FILE dispositions. Every receipt was executed against the working tree and
exits **1** today; each was then proven able to reach 0 against a patched copy.

---


---


---


---

---

## Batch `val-4`

# batch val-4 (`validators`) — drafted entries and withdrawals

Pinned ledger md5 verified `2fd444dcf406cdff728fe3c0c4352267`, 4356 lines; off-by-one control
(`sed -n '1,4355p'`) → `d4e39a96a33c5c92adfe4c8457020064`, so the two differ and the pin offsets
are real.

4 rows in: **2 FILE**, **2 PREMISE DEAD**. The two filings are below in backlog grammar; the two
withdrawals follow them and are deliberately NOT written as entries.

---


---


---

# Withdrawal candidates — DO NOT FILE

## PREMISE DEAD — pin 1240, `PC-S297-LOCKED-ANCHOR-EXEMPTED-BY-SILENCE`

The entry's headline is that a zero-bullet LOCKED block "legitimately PASSes with
`claims_checked=0`, indistinguishable from a real check **at the PASS-string level**", and its ask
is that the "is zero-claims-PASS ever a defect" question get an explicit upstream ruling rather than
staying an implicit local reading. Both halves are answered.

Measured behaviourally, two stories, one invocation, `core/scripts/validate-locked-anchor.sh`:

```
zero-bullet, zero-citation block   rc=0  VALIDATE-LOCKED-ANCHOR: PASS — NOTHING VERIFIED
                                         (zero.md, 1 block(s) carried no resolvable citation)…
CONTROL, a block that verified      rc=0  VALIDATE-LOCKED-ANCHOR: PASS (ptr.md, 1 block(s),
                                         0 full_text_source claim(s) verified against 'sor.md',
                                         1 requires_context pointer(s) resolved)
```

Same exit code, different report lines — which is precisely the claim. The control is the second
story: it proves the validator reaches its PASS emitter by the OTHER road in the same run, so the
first line is a discrimination and not the only string the program can print.

The ruling is stated too, twice and in prose the entry could have been closed against:
`:60-63` ("Exit code 0 has TWO roads and they now print DIFFERENT lines… It is not failed: a block
that claims nothing has nothing to substantiate") and `:599-605`, which gives the reason — failing
it "would red every legacy block in a consumer's history for a defect it does not have".

**Why it survived: the receipt could never have closed.** `verify: theirs_has
core/scripts/validate-locked-anchor.sh "claims_checked = 0"` reports STILL-LIVE while the substring
is PRESENT. The substring is present at `:409` — as the Python **initializer** `claims_checked = 0`,
three lines after `extract_blocks`. No fix can remove it; the variable has to be initialized. The
entry has therefore reported STILL-LIVE on a defect fixed in v0.280.0 for as long as the
initializer has existed, which is the unfalsifiable class in its purest form: an anchor on a token
that is a property of the language, not of the defect.

Withdraw. Nothing to file.

## PREMISE DEAD — pin 2341, `PC-S312-SPRINT-STATUS-CHECK-STORIES-COVERS-ONE-FIELD-OF-FIVE`

The literal grep the entry rests on still reproduces: in `core/scripts/sprint-status.sh`,
`gate_1_model` occurs **0** times and `priority` occurs **0** times, against a control of **118**
for `status` in the same file with the same command shape. The file is now **1198** lines, not the
724 the entry re-measured at `dae9f16`.

**The grep is no longer the mechanism.** Core absorbed the multi-field entry-to-story-file join, in
a different subcommand and behind a consumer declaration, so a token search of the script cannot see
it. Measured on a sandbox root, three cases, one invocation:

```
CASE 1  `priority` drifts (envelope P9, story file P1), `status` agrees
          check-stories        rc=0
          derive-stories --check rc=1
          sprint-status: DRIFT [implementation] story-9-1.priority: envelope `P9` -> story file `P1`
          sprint-status derive-stories: sprint 9, fields status, priority (--check: nothing written)
CASE 2  CONTROL, `status` drifts
          check-stories        rc=1
CASE 3  CONTROL, everything agrees
          check-stories        rc=0        derive-stories --check rc=0
```

Case 1 is the entry's own gap and the wider mode catches it by name. Case 2 proves `check-stories`
can fire; case 3 proves neither mode flags a clean tree. `sprint-status.sh:904-924`
(`story_file_field`) reads any declared field generically out of the story file's frontmatter, so
`gate_1_model` is comparable the moment a project declares it.

It is wired into the check the entry is about. `core/skills/ai-dlc/steps/gate-validation.md:485-486`
runs `derive-stories --check` as the second half of Check 5 and states the split verbatim:
"`check-stories` compares `status`, this compares every field the project declares as derived."

**The receipt could not have seen any of this, and cannot.** `verify: theirs_lacks
core/scripts/sprint-status.sh "gate_1_model"` reports STILL-LIVE while the token is ABSENT and
closes only if core's script literally names it. `sprint-status.sh:27-34` records the decision that
core will never hand-list those fields — "Hand-listing the other eight in core would be a second
home for a schema — I28 and I48 both bite — so the CONSUMER declares them". The receipt waits on a
token the architecture has decided never to carry, which is the same unfalsifiable class as pin
1240 one level up: not an invented phrasing, but a token whose absence is a settled design choice.

**The honest limitation, stated rather than buried.** The absorption is consumer-declaration-gated:
a project with no `consumer_story_fields_file:` gets `status` only, and `derive-stories --check`
prints a WORKLIST and exits 0. That is deliberate and self-documented (`sprint-status.sh:849-893`,
and the worklist text itself says "declare the fields to widen it"), so it is a settled decision
rather than a residual defect — a REFUSE, not a filing, if anyone re-raises it. Note also that the
declaration grammar requires the `field:` lines to sit inside a fenced block; an unfenced list reads
as `no-declaration` and the run goes green on the floor alone. I hit that on the first probe. It is
in scope for nothing in this batch, and it is reported below rather than acted on.

Withdraw. Nothing to file.

---

# Out of batch, not acted on

- `declared_story_fields()` at `core/scripts/sprint-status.sh:849-893` returns `no-declaration` for
  a fields file whose `field:` lines are not inside a ``` fence, and the caller then prints a
  WORKLIST and exits **0**. A consumer that writes a correct field list without the fence gets a
  clean run over the `status` floor alone and no indication that its declaration was not read.
  `malformed` is reserved for fenced content that yields no field, so the unfenced case falls into
  the branch whose own docstring says the collapse it must not make is "reported, never treated as
  empty". Measured: my first probe wrote `field: priority` unfenced and `derive-stories --check`
  reported `PASS — 0 drifted key(s)` on a tree where `priority` was drifting; the same file fenced
  reported `FAIL — 2 drifted key(s)`. Not filed — outside this batch.
- `--strays` with an explicit path drops the fixture-home exclusion by design (`:184-186`), so
  `core/fixtures/**` — a declared home — is reported as a stray when named directly. Measured:
  `--strays core/fixtures/check-17-bypass/seed.sh` exits 1 both relatively and absolutely. That is
  the documented intent of the explicit-path branch, so it is noted, not filed.

---

## Batch `val-5`

# batch val-5 (subsystem `validators`) — 2 filings, 1 withdrawal candidate

Pinned ledger md5 verified `2fd444dcf406cdff728fe3c0c4352267`, 4356 lines.

---


---


---

# NOT A FILING — withdrawal candidate

## `PC-S303-RETRO-NO-CLOSE-RECORD-FOR-RESET-OR-ABANDONED-SPRINTS` (pin 4184) — PREMISE DEAD

Phase 1's `ALREADY-FIXED-v0.372.0` verdict is confirmed, and the fix is complete across all three
parts the entry asked for, not just the schema:

- **The record is defined.** `core/schemas/audit-anchors.json:39-40` carries
  `"close_reason": { "required": false, "enum": ["reset", "abandoned"] }`, described as "present
  ONLY on a sprint closed without a retro-PR merge; `sha` is then the commit the sprint actually
  stopped at, not a merge SHA".
- **It has a writer.** `core/scripts/validate-audit-anchors.sh --close-record <reason>` at `:143`,
  `:384-424`, which validates the reason against the schema's enum rather than a hand-listed set.
- **Check 18's chain reader accepts it.** `validate-audit-anchors.sh:488-491` reads `close_reason`
  off the prior sprint's entry and opens the audit window at the recorded commit;
  `core/skills/ai-dlc/steps/gate-validation.md:1153` documents `close_reason: reset|abandoned`.
- **Both directions are fixture-guarded.** `core/fixtures/audit-anchors-schema/run.sh:127,143,161,171`
  asserts a written close record, that an entry with NO `close_reason` still validates, and that a
  non-member (`paused`) FAILs naming the closed set; `core/fixtures/check5-anchor-base/run.sh:170`
  states the closed defect verbatim — "used to leave a HOLE and the next sprint's Check 18 failed
  closed on it".

Provenance: `1537e4c feat(v0.372.0): a PASS keyed on the exit code, an absence with no word for
itself, …`. Control in the same invocation: `git log -S"close_reason_ZZZ"` over the same file
returns 0 commits, and a tree-wide `grep -rl "close_reason_ZZZ" core/` returns 0 while
`grep -rl "close_reason" core/` returns 25 files.

Note for the lead: the schema's own `$close_reason_comment` at `:45-46` restates the entry's
diagnosis in the PAST tense ("The only writer of an entry was retro.md Step 5b …"). That is the
"anchor on text the fix quotes back" hazard in its pure form — any receipt keyed on the entry's
own wording would report STILL-LIVE forever against a fix that shipped. No receipt was written,
consistent with the batch's `no-receipt` channel reason.
