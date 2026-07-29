# Layer Contract Program — execution handoff

**Point a fresh Claude Code session at this file in `/Users/n8/git/ai-dlc`.** It drives the
remaining program to done across multiple sessions.

Untracked on purpose: committing it would need a version bump per edit, and it is edited every
release. Do not delete it until the Progress Ledger is fully ticked.

---

## 0. How to use this file

1. Read §1–§5 in full. They are short and every line is load-bearing.
2. Read the **Progress Ledger** (§6) to find the next unticked release.
3. Read that release's section, execute it, ship it.
4. **Tick the ledger in this file** as the last act of each release, with the merge sha. A fresh
   session's only way to know where it is.
5. When you reach a **`⏹ SESSION BOUNDARY`** marker, stop and tell the operator to start a fresh
   session pointed back here. Do not push past one — the releases after a boundary are large and
   degrade badly on a long context.

**Fidelity rule for the executing session.** Facts below are tagged:

- **[V]** verified directly by the previous session, with a control. Trust it, but the tree may
  have moved — re-check any count you are about to depend on.
- **[R]** reported by a subagent, not independently verified. **Treat as a hypothesis.** Two
  premises tagged this way were already falsified during this program (see §4). Verify before
  implementing anything that rests on it.

**Everything below §6 is reference for the row you are on. §6 says what to do next; nothing else
in this file does.** Notes, caveats and rejected options are recorded so they are not re-litigated —
they are not competing instructions.

---

## 1. State at handoff

| | |
|---|---|
| `ai-dlc` main | `92aa72f`, VERSION **0.205.0** |
| `graph` consumer | stamped **0.183.0 @ 46aa98a**; PR #829 merged, so 0.180.0→0.183.0 is banked |
| Shipped this program | 0.181.0 (#264), 0.182.0 (#265), 0.183.0 (#266), 0.184.0 (#267), 0.185.0 (#268), **0.186.0 (#269) … 0.201.0 (#284), 0.202.0 (#285), 0.203.0 (#286)** |
| Fixture suite | **72s**, **16**-way (`AI_DLC_FIXTURE_JOBS`, raised from 8 in v0.206.0 on a re-measured knee), 83 fixtures. **208s before v0.205.0, 124s before v0.206.0.** A push is that plus ~4s of validators. Re-derive before quoting: this row has carried a stale figure into two releases already |
| Original plan | `~/.claude/plans/i-m-done-with-consumer-indexed-fox.md` — context and rationale; **this file supersedes its release sequence** |
| graph freeze | **No sprint runs in graph until this program completes.** One final pull at the end. |

Because graph is frozen, two things are cheaper than they would normally be: renumbering (no gate
logs being written) and relocation (17 entries at once). Both large releases exploit that.

---

## 2. Locked decisions — do not re-litigate

| Decision | Consequence |
|---|---|
| **Reserved numbering band ≥900, renumber existing** | Consumer checks/rules allocate ≥900; core 1..899. graph renumbers 16 checks and 3 rules. The crosswalk table survives **only** as a resolver for pre-band history — core forbids resolving those by date, because Check 12 rotates gate logs cut-and-paste |
| **Revive `scripts/ai-dlc-local/`, mirroring core's subdirs** | One declared machinery home. Already named in `core-manifest.md` prose as consumer-owned and never read/written by core **[V]** |
| **ERROR immediately** on a layer entry citing machinery outside the home | 17 of 45 entries non-conformant on contact, so `layer-relocate.sh --apply` **must ship in the same release** |
| **Absorb the 8 duplicate consumer scripts** alongside the contract | ~3,000 lines retired as core grows one arm each. The 9 real core gaps are registered and queued, not absorbed |
| **Rename `NAMED-ABSORBED` → `NAMED-UPSTREAM`** | The token contradicts its own header and misled its author in the release that shipped it. Freeze makes it cheap; the final pull updates graph's 3 annotations |

---

## 3. Non-negotiable discipline

Repo `CLAUDE.md` is binding and short — **read it.** These are the clauses this program has already
tripped over, plus traps measured during it.

**A zero is not a finding.** Every absence-shaped claim carries a control in the same invocation
that returns non-zero. No exceptions.

**Never read `$?` after a pipe.** It is the pipe's last stage. This bit the previous session
**three times**: `grep … | head` nearly caused a "fix" to an already-fixed bug, and
`git push … | tail` made a hook-killed push read as successful. Redirect to a file, then check.

**A check that cannot fire reads exactly like one that passed.** Every new check ships with a
mutant proving it fires, and a measured false-positive set — empty or enumerated.

**Mutants:** build as a **copy**, guard with `cmp -s`, add an **unmutated control copy from the same
directory**, assert a **positive outcome**, and each mutant must fail **only its own assertion**.
Two failures mean entanglement and one assertion is vacuous.

Three mutant traps hit during this program, all worth expecting again:

- **Partial revert.** A two-layer guard with one layer stripped came out green, proving the layer
  left in place.
- **A byte-different no-op that `cmp -s` passed.** A `sed` inserted on an already-comma-split value
  changed bytes and behaved identically. `cmp -s` proves a mutation happened; only the assertion
  proves it mutated the thing under test.
- **A control that earned its place immediately** — an unmutated-first control caught a new fixture
  directory failing I8 before any mutant was believed.

**`ledger-reverify.sh`'s awk program is a single-quoted shell string. No apostrophes in it.** The
file warns about this three lines above where the last change landed, and the change still wrote
`PC-S296's` and failed to parse.

**Unbraced `$ref:path` in zsh.** `:c`/`:t` are history modifiers and eat the next character. Always
`"${r}:core/…"`. graph's operator hit this too while authoring a receipt.

**Two layouts.** Any path-resolution change is verified on a tree built by running
`scripts/install.sh` into an empty directory (needs a `_bmad/` dir present, or install aborts
**[V]**), then exercising the *installed* paths. `core/`-only runs resolve things by accident.

**Four enumerations plus a twin for every new fixture** (I8 + I5): `core/fixtures/<name>/`,
`core-manifest.md`, `scripts/install.sh`'s hand-list, `scripts/uninstall.sh`'s hand-list, and
`reconcile/setup-sites.md`'s `core_manifest:` copy. `reconcile/*` and `core/scripts/*` ship by glob,
so new *scripts* there need no manifest edit **[V]**.

**Every clause added to `layer-contract.yaml` must name a code its enforcer actually emits**, and
**every code an enforcer emits must be claimed by a clause** — I36 runs both directions and will
fail the build. I37 rejects a clause with no mechanism. I38 requires the clause id to appear in its
declared `prose_home`. This is the join working; do not weaken it to land a release.

**Release triple.** Commit subject + `VERSION` + `CHANGELOG` heading are one claim, joined at
pre-push. Single-version branches only.

---

## 4. Premises already falsified — the base rate here is high

Two of three items in the original plan's Part G were **already fixed upstream** when checked: the
SIGPIPE fault and the prose-mention arm of last-match-wins. The plan asserted them from graph's
ledger, whose own header warns "an entry is a hypothesis until re-verified."

And one **wrong claim shipped in core prose**: v0.181.0 recorded `PC-S296` as "absorbed v0.153.0" in
the CHANGELOG *and* in a comment inside `ledger-reverify.sh`. It was a citation read as a fix — the
anchoring closed one arm, the entry's actual subject stayed live until v0.184.0. Fixed.

And **release 1's own two guard premises were both false**, found by checking before building — see
release 1's section for what replaced them. Note the shape: both were about a *mechanism this file
named by path*, and naming a real file is what made them read as verified. **[V] means someone ran
something. It does not mean they ran it against the question you are about to ask.**

**Therefore: verify every [R] fact and every ledger-sourced premise against the tree before building
on it.** A grep hit is not a finding — read the sentence.

---

## 5. Ship mechanics

```bash
# Branch, work, then:
bash scripts/validate-enforcement-map.sh          # must exit 0
bash scripts/validate-no-dead-doc-refs.sh         # must exit 0
for f in core/fixtures/*/run.sh; do bash "$f" >/dev/null 2>&1 || echo "FAIL $(dirname $f)"; done
printf '0.18X.0\n' > VERSION                      # then add the CHANGELOG heading
bash scripts/validate-release-version.sh          # subject/VERSION/CHANGELOG must agree

# PUSH: the keychain account is READ-ONLY on this repo. Use the euron8 token.
gh auth switch --user euron8
git push "https://x-access-token:$(gh auth token)@github.com/euron8/ai-dlc.git" <branch>:<branch>
```

**Push in the background.** `.githooks/pre-push` runs the whole fixture suite (~3–5 min) and a
foreground push will hit the tool timeout. Redirect to a log, poll for a `PUSH_RC` sentinel, and
**verify with `git ls-remote --heads origin <branch>`** rather than trusting a piped exit code.

`.githooks/pre-push` is the **distribution's own** gate over `core/fixtures/`.
`core/git-hooks/pre-push` is the **consumer's** gate over `tests/fixtures/`. Two files by design,
not a fork **[V]**.

Then `gh pr create … && gh pr merge --squash --delete-branch`, `git checkout main`,
`git pull --ff-only origin main`, delete the local branch, tick the ledger.

---

## 6. Progress Ledger

**The next unticked row is the next thing to do. Do them in order.** Tick as the last act of each
release, with the merge sha. `—` = not started.

| # | Release | Status |
|---|---|---|
| 1 | rename `NAMED-ABSORBED` → `NAMED-UPSTREAM` + I39 | ✅ `aa6bbe6` (#269) v0.186.0 |
| 2 | PC-S309: override asserts its shadowed span survives | ✅ `f18bd51` (#270) v0.187.0 |
| 3 | PC-S310: a bold-bullet annotation swallows its own entry | ✅ `d598fec` (#272) v0.189.0 |
| 4 | fix E7: it skips 3 of 20 anchors — §7.4 | ✅ `5a6c1fe` (#274) v0.191.0 |
| 5 | pull-time statuses: `OVERRIDE-LOOSE-ANCHOR`, `OVERRIDE-DOUBLE-SHADOW` — §7.5 | ✅ `ee2cf37` (#275) v0.192.0 |
| ⏹ | **SESSION BOUNDARY — STOP HERE.** Tell the operator to start a fresh session pointed at this file. | |
| 5a | contract clause ids collided; `since` outran `contract_version` — §7.5a | ✅ `c6c0df0` (#276) v0.193.0 |
| 6 | the machinery home — **declaration + join only**; all four ERROR clauses REFUTED, §7.6 | ✅ `07f507e` (#277) v0.194.0 — **PARTIAL, and the remainder is closed, not owed** |
| ⏹ | **SESSION BOUNDARY** | |
| 7 | the ≥900 numbering band — **band + both joins only**; the ERROR clause and `RENUMBER-BAND --apply` are REFUTED, §7.7 | ✅ `07f8ab8` (#278) v0.195.0 — **PARTIAL, and the remainder is closed, not owed** |
| ⏹ | **SESSION BOUNDARY** | |
| 8 | `kind: qualifier` / `extends:` / `position:` grain | ✅ `4f254cb` (#279) v0.196.0 — **shipped in full**; the LC-N5 tightening it unblocks is a separate measurement, §9 |
| 9 | `gate_types:` on check extensions | ✅ `356b417` (#280) v0.197.0 — **shipped, and larger than scoped**: the stated value claim was REFUTED and the real subject set was 4 live checks, §7.9 |
| ⏹ | **SESSION BOUNDARY** | |
| 10 | the 8 absorptions, one arm per release | **IN PROGRESS.** arm 1 REFUTED, arm 2 ✅ `eb26178` (#281) v0.198.0, arm 5 ✅ `901202e` (#282) v0.199.0, arm 7 ✅ `853eab6` (#283) v0.200.0, arm 6 ✅ `0cc4028` (#284) v0.201.0, arm 8 ✅ `c695228` (#285) v0.202.0, arm 3 ✅ `590289b` (#286) v0.203.0, arm 4 **REFUTED** — v0.204.0 shipped the one core-owned slice inside it, §7.10. **ROW 10 IS CLOSED. All 8 arms are dispositioned: 6 shipped, 2 refuted** |
| ⏹ | **SESSION BOUNDARY** | |
| 10a | **wall-clock reduction across the whole distribution — by any route, not only parallelism** — operator-requested 2026-07-29, §7.10a | ✅ **ROW CLOSED.** `92aa72f` (#288) v0.205.0: **208s → 124s**. `bd0bf65` (#289) v0.206.0: **124.9s → 72.0s (−43%)** — and it **REFUTED this row's own next-two-poles ordering**: serial duration is the wrong statistic for a pooled suite. `8eaf896` (#290) v0.207.0: `wait-stale-deliverable` **52s → 9s, suite 72s → 50s**, plus the **300-site early-exit-reader class** the release leads on (**I54**). ✅ `8344631` (#291) v0.208.0: the content-keyed suite skip — **~50s → 0.3s on a push that changed only CHANGELOG/VERSION/docs** — and **§9 IS NOW CAUSALLY EXPLAINED AND FIXED**: a fixture was writing into the repository it tests. See §7.10a |
| ⏹ | **SESSION BOUNDARY** | |
| 10b | **mechanize what does not need inference** — operator-requested 2026-07-29, its own session because of scope, §7.10b | **IN PROGRESS.** Check 16 ✅ `564c5d2` (#292) v0.209.0 — the program **already existed inside the check's own fixture** as a restatement. Checks 18 and 22 remain, then the join that closes the class. §7.10b carries the ordering, which is now a MEASURED constraint rather than a preference |
| ⏹ | **SESSION BOUNDARY** | |
| 11 | ADJUDICATED tier + disposition register | — |
| 12 | Regenerate the final pull prompt (§8) | — |

Rows 4 and 5 were one row until 2026-07-28; E7's defect was found while scoping it and is split out
because an ERROR-tier check silently skipping its own subject set outranks adding report-only
statuses. Ship 4 before 5 — 5's wording depends on it.

**Version numbers are not pinned to rows.** `0.186.0`–`0.203.0` are spent — two on out-of-band
performance work, one (`0.193.0`, row 5a) on a defect found while scoping row 6. Each remaining row
takes the NEXT free version at ship time.

**Rows 8–11 all rest on [R] premises from the same subagent classification that produced row 6's
refuted clauses.** Row 6's four ERROR clauses came out of it and all four failed on contact with a
measurement. Re-derive row 7's counts and rows 8–11's tables against the tree before building —
the base rate here is now demonstrated, not merely warned about.

### Out of band, not part of this program

Real work, but do NOT let it displace the next unticked row:

- ~~Split `core/fixtures/enforcement-map-sites/` into nine per-invariant fixtures.~~ **MOVED
  INTO ROW 10a**, which is the same work under a wider scope. It deletes six hand-maintained
  path rebindings plus an existing entanglement where its assertions 1 and 5 are the same
  mutation firing two different messages. Seam and evidence: CHANGELOG v0.190.0. **RE-TIMED
  2026-07-29: it was 194.3s, not ~81s, and v0.205.0 brought it to 107s by making the
  validator it drives 42 times 2x faster rather than by splitting it.** The split is STILL
  AVAILABLE and still worth doing — at 107s it remains the suite's floor against a 124s
  suite — but it is now a second-order win, not the largest one. v0.205.0 also shipped the
  first slice of it as a separate `.dist-only` fixture, which is proof the split costs no
  enumeration: a dist-only fixture appears in NONE of the four hand-lists.
  **CLOSED BY v0.206.0, and by the other route.** The fixture now runs its 29 assertions
  through a pool inside one directory — 107s → 25s — which buys what the nine-way split was
  wanted for without creating nine directories, nine headers and nine copies of the
  distribution-only guard. What the split ALSO promised is still open and is now cosmetic
  rather than structural: the trailing `restore` at the end of each assertion re-seeds a tree
  that the process discards a line later (**measured: a seed is 0.117s, so ~3.4s serial and
  ~0.2s across the pool**), and the path rebindings that follow those restores are vestigial.
  Not worth a release on its own; fold it into the next edit of that file.

---

## 7. Releases

### 1. rename `NAMED-ABSORBED` → `NAMED-UPSTREAM` — SHIPPED v0.186.0

**Why.** The token says "absorbed" while its own header insists *"IT SAYS 'NAMES', NOT
'ABSORBED'"* — and it misled its author in the release that shipped it: all four instances were
recorded as absorbed when adjudication found **one absorption, one split, one passing mention, one
explicit refutation** **[V]**. A token that fools its own author fools every operator after.

**Do.** Rename the status in `reconcile/ledger-reverify.sh` (emission + header docs), the clause in
`layer-contract.yaml` if one claims it, `SKILL.md` step 3f, `emit-report.sh`'s section heading, and
`core/fixtures/ledger-reverify/{run,seed}.sh`. Add the old token to whatever
`reconcile/retired-tokens.sh` reads, so a layer file still speaking it is reported.

**SHIPPED — `aa6bbe6` (#269). Both stated guards were false; read this before trusting a [V] here.**

- *"I36's reverse direction will fail the build until the clause claims the new token."* **False.**
  I36 reverse extracts codes only from the two enforcers `layer-contract.yaml` declares
  (`validate-layer-entries.sh`, `layer-drift.sh`). `ledger-reverify.sh` is not one, no clause claims
  any ledger status, and the build stays green through a half-done rename.
- *"Add the old token to whatever `retired-tokens.sh` reads."* **There is no list.** It *derives*
  `$VAR/path`-shaped tokens from the CLASSIFY bucket — wrong shape, wrong bucket. Its sibling
  `retired-layer-contract.sh` derives from `setup-sites.md`'s `rulebook:` globs, which do not include
  `ai-dlc-update/SKILL.md`, so it cannot see the status vocabulary either.

**What shipped instead: I39**, a both-way join between the statuses `ledger-reverify.sh` emits and
those SKILL.md step 3f documents, plus the subset arm on `emit-report.sh`'s heading, with a zero
guard on each extraction. FP set empty; reverse direction bounded to step 3f's span because the same
grammar over the whole file matches 20 tokens, 15 of them other detectors'. Fixture
`core/fixtures/ledger-status-vocabulary/` — 6 mutants, each single-arm one asserting exactly one
failure line, plus the half-done-rename case and an unmutated control copy.

**Left open, deliberately** (now §9): reporting a *consumer* layer file still speaking the old token
has no mechanism. Covering it means widening `retired-layer-contract.sh`'s subject set, whose FP set
across every shape it already extracts is unmeasured.

**Note for §8.** graph's ledger carries 3 annotations using the old token; the final pull prompt
must instruct the operator to update them. Core prose no longer carries the old string outside
`CHANGELOG.md` and `docs/reviews/` (both historical, deliberately unchanged), so a consumer-side
grep for it is unambiguous.

### 2. PC-S309: an override whose body asserts its shadowed span survives — SHIPPED v0.187.0

**Why.** A third failure mode with **no detector**, found by graph's operator. `OVERRIDE-DELEGATES-
INTO-SHADOW` catches a body that delegates *into* its shadowed span; this is a body that **asserts
the span survives**. Live instance **[V, operator-verified]**:
`overrides/steps__retro__ci-gates-enforcement-surface.md` shadows all of
`steps/retro.md#Empirical gate validation` (three paragraphs) while its body replaces paragraph 2
and states *"The surrounding section … is unchanged and still governs."* False at load time — two
core paragraphs are dropped, including the exercise-window rule the override's own `reason:` cites.

**Do.** New report-only status in `reconcile/layer-drift.sh`. Predicate: an override whose body
contains a survival claim about the section it shadows. **Measure the false-positive set against
graph's 12 overrides before choosing the predicate** — do not ship a keyword scan unmeasured. The
recorded prior art is the short-title degeneracy in `same_section()`'s containment arm (5 false
positives); a survival-claim scan has the same shape of risk.

**Grain warning.** The detector must not fire on an override that shadows a *narrower* anchor and
correctly says the rest of the file is unchanged — that is true and normal. The defect is
specifically a claim about text **inside the shadowed span**.

### 3. PC-S310: a bold-bullet label silently deletes its own entry — SHIPPED v0.189.0

**Why.** `ledger_entry_shape()` treats a line-leading `- **Bold**` as a new entry, so an annotation
formatted that way **splits its own entry** and the entry stops emitting any row under its own id —
a silent disappearance. graph's operator hit this while annotating `PC-S296`: two intermediate runs
read clean and were not **[V, operator-reported with the mechanism]**.

**Do.** Not a re-keying of the entry-shape rule — that remedy was considered and rejected upstream
(see the `case 3` discussion in `ledger-reverify.sh`). Ship the **missing diagnostic**: when an
entry's span ends without ever emitting a row while its heading exists, say so. Cite v0.171.1's own
"a swallowed entry produces no row at all" as the same shape one heuristic over.

**Fixture.** Seed an entry whose body contains a `- **Case 3 (…)**` line. Assert the entry still
reports under its real id, or that a diagnostic names it. Mutant: remove the diagnostic → silence.

### 4. fix E7 — it skips 3 of 20 anchors — SHIPPED v0.191.0

**Verified directly 2026-07-28 by replaying the parse [V].** `core/scripts/validate-layer-entries.sh:420-425`
splits `shadows:` on comma and computes `tgt="${part%%#*}"` **per part**. Both multi-anchor spellings
are in live use, and only one survives that:

```
team-roles/tea.md#Identity, team-roles/tea.md#Ownership, …   <- file repeated: every part checked
steps/retro.md#3. Write Retro Document, #4a. Close-Out Sweep, #5. …, #7. …
                                        ^^^ no file prefix -> tgt EMPTY
```

For an inheriting part, line 425's `[ -n "$tgt" ] || continue` skips it **before any anchor check
runs**. Measured on `steps__retro__domain-sections.md`: **1 of 4 anchors checked, 3 skipped**
(`#4a. Close-Out Sweep`, `#5. Human Commentary`, `#7. Merge and Next-Sprint Handoff`).

**E7's own header claims this class is fixed** — *"This read only the FIRST part and only its file …
Nineteen anchor instances across twelve overrides were entirely unvalidated."* The fix handled
multiple PARTS but not the file-INHERITING form, so an ERROR-tier check is silently skipping part of
its own subject set. That is this repo's named defect class living inside the check written to end it.

**Do.** Carry the last non-empty target forward across parts, so a bare `#anchor` inherits the file
from the part before it — that is what the resolver and `layer-drift.sh` already do
(`layer-drift.sh:360` takes one target for the whole entry, `:384` harvests every part).

**Fixture.** An override whose `shadows:` uses the inheriting form with a BAD anchor in part two must
ERROR. Mutant: revert the carry-forward → that entry passes silently. The existing
`layer-anchor-declaration` fixture is the likely home; check before adding a new one.

**Expected effect on graph: still 0 errors.** All 20 of its anchors forward-match, so this widens
coverage without changing the verdict — which is exactly why nobody noticed. Do not read that zero as
the fix not working; the fixture is what proves it fires.

**SHIPPED — `5a6c1fe` (#274).** The predicted zero held, byte-identical before and after. The
evidence that the fix fires is a differential on a `cmp -s`-guarded COPY of graph's tree with one
previously-skipped anchor corrupted: `d9605f5` reports 0, the fix reports the anchor, unmutated
control reports 0. A second arm shipped alongside: a FIRST part with no file has nothing to inherit
and now ERRORs instead of silently skipping every check on the entry (FP set empty across all 14
live `shadows:` values). Two mutants, each single-arm.

**One trap worth carrying into row 5.** The first draft of the inheriting entry's assertion wanted
the anchor TEXT, and the target-less arm's message quotes the whole part — so the assertion passed
against a reverted fix. Mutation 3 caught it. When two arms of one check can both name the same
string, assert on the arm's WORDING, not on the subject both arms quote.

### 5. pull-time statuses: LOOSE-ANCHOR and DOUBLE-SHADOW — SHIPPED v0.192.0

**SHIPPED — `ee2cf37` (#275).** Every measurement below re-verified against `170ff9d8c` with the
shipping code and held: 13 overrides, 20 anchors, LOOSE **0 of 20** (control: an anchor corrupted
to the reverse form on a `cmp -s`-guarded copy reports LOOSE from the same run), DOUBLE **one
duplicate key** → 2 rows, FP set empty. Every pre-existing row byte-identical before and after.

**What row 6 inherits.**

- **`reconcile/lib.sh` now owns `nrm_awk`, `anchor_arm` and `shadow_parts`**, byte-identical to
  `core/scripts/validate-layer-entries.sh`'s copies and bound by **I40** (both arms mutated in
  `enforcement-map-sites`). The normalizer had **five** spellings across the two trees. Anything in
  row 6 or 7 that needs to read an anchor must CALL these, never restate — I26.
- **I21 now covers them automatically**: the reconcile helper set is derived from `lib.sh`, so a
  reconcile script redefining any of the three fails the build without a new check.
- **The latent cross-file parse bug is fixed**, not just noted: `layer-drift.sh` resolves each
  anchor against its OWN file now.
- **`hard-blockers.sh` needed no change, confirmed against the code**: `collect()` filters
  `$1 ~ /^HARD-/`, so report-only statuses cannot reach the blocking set. (The earlier note said
  "field 2"; it is field 1 that carries the status. Same conclusion.)
- **An `EXIT` trap in a reconcile script is a stderr hazard.** Installing one made bash report
  `printf: write error: Broken pipe` from every `printf | grep -q` in `layer-drift.sh` — 90 lines,
  from pipelines the change never touched. If row 6 or 7 wants a temp file, prefer an accumulating
  variable, and diff stderr against the shipped script either way.
- **`ai-dlc-update/SKILL.md`'s status list is prose nothing binds.** It was missing
  `OVERRIDE-ASSERTS-SHADOW-SURVIVES` from v0.187.0 entirely; this release documented that plus the
  two new ones. I36 binds statuses to the CONTRACT, not to this list. An I39-shaped join for
  layer-drift is the obvious fix and its FP set is unmeasured — see §9.

**Do row 4 first.** This section's wording depends on it.

**Why.** The loose-anchor and double-shadow checks are authoring-time only, and the authoring
validator is consumer-run and skippable. The pull is not.

**Do.** In `reconcile/layer-drift.sh`, two report-only statuses: `OVERRIDE-LOOSE-ANCHOR` and
`OVERRIDE-DOUBLE-SHADOW` (two overrides declaring the same `(target-file, normalised-anchor)`).

**Found while shipping row 4, and it lands in this row's code [V — read at `layer-drift.sh:360`
and `:384`, cross-checked against all 14 live `shadows:` values].** `layer-drift.sh` takes ONE
target for the whole entry — `${shadows%%#*}` then `sed 's/,.*//'`, i.e. part one's file — and then
checks EVERY harvested anchor against it. For both live spellings that is accidentally right,
because no live entry names two different files. An entry spelling `a.md#One, b.md#Two` would have
`Two` checked against `a.md`. Latent, zero live instances; fix it while you are in that parse
rather than opening a row for it.

**Call it a pull-time COUNTERPART, never a "mirror of E7".** Even after row 4, `layer-drift.sh`
parses `shadows:` differently — one target for the whole entry at `:360`, every part harvested at
`:384` — so the two arrive at the same coverage by different routes. Before row 4 it is strictly
wider than E7. "Mirror" claims a byte-for-byte equivalence that is not there.

**MEASURED 2026-07-28 against graph's main `170ff9d8c`, with controls [V]:**

- **13 overrides, 20 anchors.** Both multi-anchor spellings are live — see row 4.
- **LOOSE ANCHORS: ZERO of 20.** The prior "2 of 19" is CONFIRMED FIXED. Control: a bogus anchor
  reports LOOSE from the same probe, so the zero is real and not a broken matcher. **The fixture
  instance must be synthetic** — there is no live one left.
- **DOUBLE SHADOW: exactly ONE duplicate key** — `steps/retro.md#4a. Close-Out Sweep`, declared by
  both `steps__retro__domain-sections.md` and `steps__retro__pipeline-snapshot-ceiling.md`.
  **19 unique keys** (the earlier "17" was low). FP set empty.
- That anchor's span is **214 lines** (`steps/retro.md:359-572`), **21 commits touching the span**
  (`git log -L 359,572:`), 58 touching the file. It is the largest shadowed span in the consumer and
  two override files claim it at once, so each of those commits invalidates two stamps.

**TIER: report-only, and the reason is on the record.** The collision is DELIBERATE and
self-documented — `steps__retro__pipeline-snapshot-ceiling.md:18-21` states it does not restate the
Close-Out Sweep body and names `domain-sections` as the file that does. An ERROR would fire on a case
the consumer already reasoned about in writing.

**THE HARD PART, scoped and not started.** The loose-anchor predicate is `anchor_arm()` at
`core/scripts/validate-layer-entries.sh:139` (returns `FORWARD | REVERSE:<heading> | NONE`), which
depends on the `NRM_FN` normalizer at `:103`. `layer-drift.sh` **cannot call it** — I29 confines
ai-dlc-update to `reconcile/`, and core/scripts must not depend on the update skill. So it follows the
I15/I18/I34 pattern: put `anchor_arm()` AND `NRM_FN` in `reconcile/lib.sh` byte-identically and add an
invariant binding the two copies. `reconcile/lib.sh:51` already carries a semantically identical
`nrm()` inline inside `span_of`, and `span_of` already implements both containment arms — write the
shared form once rather than leaving a third spelling. **This is a cross-file grammar binding; it is
the highest-regression edit in the row. Do not half-land it.**

`reconcile/hard-blockers.sh` needs **no change** — its `collect()` derives `HARD-*` from field 2, so
new statuses reach the blocking set automatically **[V]**. Do not hand-list them.

⏹ **SESSION BOUNDARY** — the next release is the largest in the program.

### 5a. contract clause ids collided — SHIPPED v0.193.0

**Not planned. Found while re-deriving row 6's premises, in the file row 6 adds four clauses to.**

**SHIPPED — `c6c0df0` (#276).** `layer-contract.yaml` carried **two clauses with `id: LC-O12`** —
v0.187.0's `OVERRIDE-ASSERTS-SHADOW-SURVIVES` and v0.192.0's `OVERRIDE-LOOSE-ANCHOR`, five
releases apart, `validate-enforcement-map.sh` exiting **0** throughout, and `overrides/README.md`
carrying both under one bold label. Separately, `contract_version` was **2** while three clauses
declared `since: 3`, which by the file's own retro-application rule binds no conforming entry.

**Why nothing caught it, and the lesson for every later row.** Every invariant on that file keys
on something else: I36 joins on `code:` (unique), I37 on field presence, I38 greps the declared
`prose_home` for the id as a **SUBSTRING** — so two clauses sharing an id both pass on the
surviving one's line. The invariant nearest the defect was the one structurally unable to see it.
It hid because the file is **not in numeric order**: LC-O12 sat above LC-O10 and LC-O11, so an
author appending after LC-O11 counted forward onto a taken number without the two ever appearing
near each other. **Rows 6–11 all add clauses. Take the next free id by reading the whole id set,
never by reading the clause above your insertion point.**

`OVERRIDE-ASSERTS-SHADOW-SURVIVES` is now **LC-O14**; `contract_version` is **3**. **I41** asserts
ids are unique, **I42** that no clause declares a `since` above `contract_version` (a missing
`since:` and an unparseable version are errors, not skips). Both were run against the contract as
it shipped at `ee2cf37`, recovered with `git show`, and both fired — not a mutant, the defect.
Four assertions added to `core/fixtures/layer-contract-conformance/`, each verified to fire
**exactly one** invariant with the unmutated control clean.

**Carry into row 6.** The version mutant raises a clause's `since` rather than lowering
`contract_version`, because lowering it only fires while some clause sits exactly at the current
version — a later bump without a clause at it turns the mutant into a byte-different no-op, the
shape `cmp -s` passes because the bytes did change. And I42's three arms assert on their own
WORDING, never on the shared token `I42`, which is row 4's recorded trap.

**Left open** (now §9): `contract_version` and `conforms_to` have **no reader anywhere in the
tree**. I41/I42 keep the declaration coherent; they do not build the reader.

### 6. the machinery home — SHIPPED v0.194.0 as declaration + join; the clauses are CLOSED

**SHIPPED — `07f507e` (#277).** `core-manifest.md` declares `consumer_machinery_home:`, with the
`setup-sites.md` duplicate the other lists carry (the update skill cannot read pipeline files at
runtime). **I43** binds every spelling both ways — forward, no core file names a `scripts/ai-dlc*`
path other than core's own home and the declared one; reverse, the guard's deny text still routes
to the declared home, because a home no affordance points at is one no author finds. Token-grammar
FP set measured **empty** first: exactly two spellings exist in the distribution. **I44** asserts
the never-writes promise both `core-manifest.md` and the guard state in prose, derived from
install/uninstall targets plus the manifest globs, with a positive control. Fixture
`core/fixtures/consumer-machinery-home/` — five single-arm mutants plus an unmutated control.
`warn-shadowed-local-validators.sh` now walks the whole home and emits the fork's REAL path.

**THE FOUR ERROR CLAUSES ARE REFUTED, NOT DEFERRED. Do not re-attempt them without a new
predicate.** Every candidate for "consumer ai-dlc machinery" was measured against graph
`170ff9d8c` with controls, and all of them fail:

| Candidate predicate | Result |
|---|---|
| Path scan under `scripts/` | `check-orphaned-fn.sh` (domain) and `check-protected-core-paths.sh` (ai-dlc) are siblings, same name shape, opposite class |
| Name shape (`check-*`, `validate-*`, `audit-*`) | Straddles both classes — the same two files |
| **Cited by a layer entry** — §7.6's own rescue route | 86 spellings; **39 resolve to no path at all**; the resolving 47 include `rebalancer/api.py`, `server/aggregator.py`, `web/src/utils/configSchema.js` |
| **Invoked by a gate check** — the other rescue surface | Sweeps in graph's entire domain-check toolchain, which is the FP set the row was warned about |
| Consumer fixture dir not in core's derived set | 30 dirs, **mixed** product and ai-dlc (`boundary`/`compute`/`detectors` vs `check-*`); relocation breaks `tests/fixtures/MANIFEST`, `fixture-hashes.lock`, 4 `ci-local.sh` triggers, `core/git-hooks/pre-push`'s glob |
| Layer entry declares `fixtures:` | **Zero** live subjects — check-cannot-fire |
| Basename collides with a core script | **Zero of 1003** consumer executables — vacuous |
| `settings.json` hook command | Decidable, **1** subject; `.claude/hooks/` is core-claimed by prefix glob only, so a consumer hook beside it is already unambiguous. Measured value: none |

**`reconcile/layer-relocate.sh --apply` is closed with them.** A relocation tool needs a clause to
trigger it, and the thing it would relocate has no predicate. So is
`core-paths.sh --is-consumer-machinery` — it was the implementation of the refuted clause.

**The lesson to carry into rows 7–11.** This row's rescue route was itself written in this file as
the thing that "does work", and it does not: an entry citing a script does not make the script
ai-dlc, because entries cite product source. **A derivation is not sound merely because its inputs
are readable by core.** Ask what the derived set CONTAINS, not just where it comes from.

**Two things found while shipping, worth expecting again.** (i) A new check whose scan covers
`core/fixtures/` will fire on its own fixture's mutation strings — assemble alien tokens at
runtime and describe the shape in comments rather than reproducing it; this cost two red runs.
(ii) `core/fixtures/layer-readopt-gate/` failed once under the 8-way pre-push suite and passed
10/10 serially and in three subsequent full-suite runs. Intermittent, unrelated to this row — see
§9.

**The ORIGINAL scoping block follows, kept because its non-clause measurements still hold.
RE-MEASURED 2026-07-28 against graph `170ff9d8c`, with controls.**

- **The home is ALREADY ADVERTISED, with nothing behind it.** `core/hooks/ai-dlc-core-guard.sh`
  names `scripts/ai-dlc-local/` **twice in shipped deny text** the consumer reads at :163 and
  :164 — *"consumer-authored pipeline tooling goes in `scripts/ai-dlc-local/`, which core never
  reads, never writes and never overwrites."* This is the affordance-is-the-defect shape: the
  guard promises a home no mechanism enforces. Row 6 gives it teeth; it does not invent it.
- **And the same guard CONTRADICTS the proposed fixture clause.** Its fixture arm at :174 tells
  the consumer *"a consumer's own fixtures go in `tests/fixtures/<your-own-name>/`"*. That is the
  surface this row proposes to move under `<home>/fixtures/`. Both strings must change together
  or a consumer following the deny message lands outside the new home.
- **`enforcement-map-sites` collision: CONFIRMED, exactly one.** Core has 2 `.dist-only` fixtures;
  only that one also exists in graph. Control: `settings-merge-documented-form` does not.
- **28 data-only fixture dirs: CONFIRMED.** graph owns 33 fixture directories, 28 with no `run.sh`.
- **46 layer entries, not 45** (`layer_files()` = `*.md` minus `README.md`; 2 READMEs excluded).
- **The `settings.json` clause is decidable and nearly satisfied already**: all **14** hook
  commands already point into `.claude/hooks/`, 13 of them `ai-dlc-*` prefixed plus
  `guarded-merge.sh`. This clause is close to a no-op on the reference consumer — measure its
  value before spending a release on it.
- **7 checks in `gate-validation-domain.md` cite a consumer script**, including **Check 26 and
  Check 34** as claimed. The handoff's "10" spans all three extension check files; derive the
  full set rather than quoting either number.

**REFUTED: the clause "no consumer ai-dlc executable outside the home" has no available
predicate.** graph's entries cite **81 distinct executables**. `scripts/lib/meta-gate.sh` (ai-dlc
machinery) and `scripts/ecs-deploy.sh` (graph's deploy tooling) are siblings in one directory, and
entries also cite product source — `rebalancer/api.py`, `server/aggregator.py`,
`web/src/utils/configSchema.js`. Core cannot tell them apart by path. A naive path classifier
returns **21 of 46**, not 17, and its false-positive set is graph's entire domain toolchain.

`core-manifest.md:37-40` already makes this exact argument for core's own files: *"A glob names
our set only where that holds. `scripts/` does not hold it — a consumer's own audit scripts sit
beside ours under no distinguishing prefix."* Core solved it for itself by carving out a directory.
The consumer side has no such carve-out **yet** — which is what this row creates, so the clause
cannot be founded on the thing it is trying to establish.

**The route that does work: derive the subject set instead of scanning for it.** A consumer
executable is ai-dlc *because something ai-dlc-shaped points at it* — a layer entry cites it, a
`settings.json` hook command runs it, or a gate check invokes it. Those three surfaces are all
readable by core. Then "no ai-dlc executable outside the home" stops being a keyword scan and
becomes the union of the other three clauses, which is the derive-both-sides-of-a-join pattern
`CLAUDE.md` prescribes. **Anything the derivation cannot see stays invisible, and the release
should say so in the CHANGELOG rather than implying whole-tree coverage.**

**Why.** graph respects the `machinery:` prohibition *literally* — 31/31 files under
`scripts/ai-dlc/` byte-identical to core, zero machinery overrides — and evades it **structurally**:
**6,118 lines of ai-dlc pipeline machinery** live in `scripts/`, `scripts/lib/`, `scripts/tests/`,
`.claude/hooks/` and `tests/fixtures/`, mixed with the project's own tooling. Of **8 wiring
surfaces, core can see 2** — both the sanctioned `AI_DLC_*` tunable pattern **[R — STILL
UNVERIFIED; the line count and the surface list were not re-derived, and the classification
problem above means "6,118 lines of ai-dlc machinery" presupposes the predicate that does not
exist. Do not quote either number without deriving it.]**

**The home** (decision locked):

```
scripts/ai-dlc-local/
  <validator>.sh   lib/   hooks/   fixtures/   config/   tests/
```

**Clauses, all ERROR:** a layer entry's cited executable resolves under the home; no consumer ai-dlc
executable outside it; every consumer `settings.json` hook command points into `hooks/`; every
consumer fixture a layer entry references resolves under `fixtures/`.

**Why `fixtures/` moving matters beyond tidiness [R]:** graph's
`tests/fixtures/enforcement-map-sites/` **name-collides** with a core `.dist-only` fixture whose
`run.sh` differs — if core ever unsets `.dist-only`, `install.sh` clobbers it. Relocation dissolves
that class, and gives the **28 data-only fixture dirs** (no `run.sh`, per I20) a legal address,
which turns the largest warning set into zero rows rather than 28 suppressions.

**Ship the remedy in the same release.** `reconcile/layer-relocate.sh --apply` must `git mv` into
the home and rewrite every citing layer entry. **17 of 45 entries cite consumer machinery; 10
executable gate checks depend on those scripts** — including graph's non-skippable Check 26 and
Check 34, its own guard against editing core **[R — re-derive both counts]**. ERROR without the
relocation tool wedges the consumer's pre-push with no remedy.

**Reuse, do not invent:** `core-paths.sh --is-core` already returns `2` for "cannot determine, never
degrades to 0 or 1"; add `--is-consumer-machinery` beside it. **Highest-regression edit in the
program:** that helper is byte-identical-bound to `core/hooks/ai-dlc-core-guard.sh` by **I25**, and
the guard denies keystrokes. The guard currently routes on grain via hard-coded `case` arms while
`core-manifest.md:11-20` *declares* the grain — a restated list, I26's defect one layer in. Add the
derivation to **both** copies and extend I25's loop. **If it does not come out clean, drop this
clause from the release rather than shipping a fork.**

Extend `reconcile/warn-shadowed-local-validators.sh` from scripts-only to the six subdirs.

### ⏹ SESSION BOUNDARY

### 7. the ≥900 numbering band — SHIPPED v0.195.0 as the band + both joins; the ERROR and the tool are CLOSED

**SHIPPED — `07f8ab8` (#278).** `W5` (clause **LC-N5**, `contract_version` 4) reports a
consumer entry allocating a bare integer core has not defined, below the floor. **I45** holds
core to the complement, derived by RUNNING `validate-layer-entries.sh`'s own `defined_anchors`
and `defined_rules` against `steps/gate-validation.md` and `SKILL.md` rather than copying their
grammars, with the floor read from that file's `BAND_FLOOR` so the two halves of the partition
cannot land on separate copies of one number. Measured on graph `170ff9d8c`: **five subjects**
(checks 33/34/35, rules 31/32) against a baseline of **0 errors, 0 warnings** — graph's every
collision is already labelled, so W5 adds exactly the findings nothing could see and disturbs no
existing one. Fixture `core/fixtures/layer-catalog-collision/` Parts 5 and 6 (four mutants, one
exclusion each, plus an unmutated control copy); `enforcement-map-sites` Assertion 21 (three I45
arms).

**BOTH [R] COUNTS IN THE ORIGINAL SCOPING WERE WRONG, and the locked ERROR clause does not
survive the correction.** Re-derived with the shipping grammars:

- *"16 checks in `gate-validation-domain.md` (15, 17, 20, 22–32, 34, 35)"* — the file defines
  **19** anchors. The list omits **33** and **19b** and does not mention `H1`.
- *"3 rules in `SKILL-domain.md` (30/31/32)"* — **six** (13, 16, 20, 30, 31, 32), and
  `SKILL-push.md` carries **four more** (19, 24, 25, 29) that the row never mentions.
- The real subject set is **51 numbered headings across 13 files**, not 19 across 2.

**THE ERROR CLAUSE IS REFUTED — do not re-attempt "ERROR on a consumer number <900".** Of those
51 headings, **28 name a number core already defines** and **16 are step positions**:

| Class | Count | Why the band must not touch it |
|---|---|---|
| Deliberate qualifier on a core number | 4 rules | `Rule 13 [ext:skill-domain]` states in its own body *"a deliberate tightening of Rule 13 autonomy"*. The integer IS the reference; renumbering severs it. This is row 8's `kind: qualifier` grain, not row 7's |
| Push candidate staged against the core section it amends | 8 | `push_candidate: true`; every number matches a core number by design |
| Other collisions with a core number | 16 | E6/W4's subject, resolved by the catalog label |
| Step position in an ordered procedure | 16 | `### 4a-bis.`, `### 5c-table.`, `### 0.` — a band renders them at the END of the procedure they belong inside |
| Alphabetic id (`AP`, `VH`) | 2 | A numeric band cannot order them |
| **Genuine squat: a bare integer core has not taken** | **5** | The whole live subject set |

**`RENUMBER-BAND --apply` is closed with it,** and its stated route is independently false. The
row says it *"rides `reconcile/relabel-extension-checks.sh --apply`, which already rewrites
consumer headings"* **[V]** — that tool's rewrite loop iterates the numbers **core** defines and
looks each one up in the entry (`:132-139`). A number core does not define never enters the loop.
It is blind to W5's entire subject set **by construction**, not by coverage. Same shape as §4
warns about: naming a real file by path is what made the claim read as verified.

**Carry into rows 8–11.** The correction that mattered was not "the counts are off" — it was that
the counts were of the WRONG SET. The row counted one file's headings and generalised; the
predicate had to be re-derived per hooked file, per kind, and per frontmatter flag before any of
it meant anything. **Rows 8 and 10 both rest on tables from the same subagent classification.**

**The ORIGINAL scoping block follows.**

**Why.** `[ext:<id>] 24` is a *label*, not a namespace: collisions are detected after the fact
(`EXTENSION-CHECK-NUMBER-COLLISION` in 8 of 76 pulls **[R]**), and graph's `SKILL-domain.md`
invented Rules 30/31/32 out of the same sequence core allocates from **[V — CONFIRMED, and
understated: graph's Rule 30 is a LIVE collision with core's Rule 30 under a different title;
31 and 32 are pending ones, and core is AT 30, so Rule 31 is the next integer core allocates]**.

**Do.** Consumer checks and rules ≥900; core 1..899. Enforce **both directions**: an ERROR on a
consumer entry defining a number <900 (this replaces collision *detection* with a *partition*, so
the collision becomes unrepresentable), and a new invariant asserting core never allocates ≥900 —
**derived** from `steps/gate-validation.md`'s `CHECK_LOADED` anchors and `SKILL.md`'s rule headings,
never hand-listed.

**graph's renumbering:** 16 checks in `extensions/checks/gate-validation-domain.md`
(15, 17, 20, 22–32, 34, 35) and 3 rules in `extensions/steps-domain/SKILL-domain.md` (30/31/32)
**[R — re-derive from the file]**. Ship `RENUMBER-BAND --apply`; it rides
`reconcile/relabel-extension-checks.sh --apply`, which already rewrites consumer headings **[V]**.

The crosswalk table in `extensions/README.md` stays, frozen, as the resolver for pre-band history,
and gains a clause requiring an entry for every number the consumer has ever used.

**Reuse:** `RULE_RE` and the anchor grammar are already byte-identical across `layer-drift.sh`,
`relabel-extension-checks.sh` and `validate-layer-entries.sh` under I15/I18/I34. The band predicate
must **call** them, never restate (I26). `validate-layer-entries.sh` now has one `NRM_FN` heading
normalizer — use it, do not add a fourth copy **[V]**.

### ⏹ SESSION BOUNDARY

### 8. the `qualifier` grain — SHIPPED v0.196.0, in full

**SHIPPED.** `extends: <file>#<anchor>` (optional, every kind), `kind: qualifier` with
`position: append|prepend`, and a closed `kind:` vocabulary. `layer-drift.sh` compares the
declared anchor's SPAN instead of the file and emits `EXTENSION-ANCHOR-DRIFT`;
`EXTENSION-ANCHOR-MISSING` is its own LOUD status because a span that stops resolving compares
empty against empty and the natural failure of a narrowing is silence on a real change. Clauses
`LC-E10`–`LC-E15`, `contract_version` **5**. Fixture `core/fixtures/layer-qualifier-grain/`.

**Every [R] premise in the original scoping was re-derived, and every number moved:**

| Premise | Handoff said | Measured, with controls |
|---|---|---|
| Override lines byte-identical to core | ~300 of ~920 | **376 of 1126 (33%)** — both terms low, ratio right |
| Drift events, file grain | ~956 | **1421**, exact, full history |
| Drift events, anchor grain | ~180 | **133** expected → **91% reduction** |
| `position:` vs `disposition:` | [R] | **confirmed**, 8 of 9 unanchored hits in `core/`; `fm()` already anchors at index 1 |
| The concession, and the 132-line file | [V] | **both confirmed verbatim** |

The anchor-grain figure is an EXPECTATION under a uniform anchor, not a count: no entry declared
one, so there was nothing to count. It is derived from what commits actually touch — sampled over
417 commits, at most 40 per file — and the file-grain 1421 is exact. Do not quote 133 as measured.

**Zero effect on graph, checked rather than assumed.** No entry declares `extends:`, so all 52
classifier rows keep the same status, entry and target. Behaviour was demonstrated by differential
on a `cmp -s`-guarded COPY: the same entry reports `EXTENSION-HOOK-DRIFT` unanchored, `EXTENSION-OK`
anchored to a section the range left alone, `EXTENSION-ANCHOR-DRIFT` anchored to the one that moved,
`EXTENSION-ANCHOR-MISSING` on an anchor core no longer defines, with a sibling left unanchored in
the same run as the control.

**Two defects found by doing the work, both fixed here.** (i) **I36's reverse join was capped at one
digit** — `\b(E[1-9]|W[1-9])\b` cannot match `E10`, and E1..E9 were all allocated, so the next error
code would have been bound FORWARD only, green build, reverse direction silently not covering it.
(ii) **`extends:` must be quoted to be valid YAML** (a bare `#` opens a comment), and `fm()` returns
quotes literally, so `'#X'` parsed as a file named `'`. `unquote()` is now shared and in **I40**'s
byte-identity loop. Both arms of that extension proven to fire.

**Two harness traps this fixture hit on itself, recorded in its own comments.** A lone copy of
`layer-drift.sh` dies sourcing `lib.sh` and emits nothing — which scores as a kill for every mutant
at once, and the unmutated control is what caught it. And two `grep -q` pipelines against one
producer reported a false ENTANGLEMENT: that is the standing "never read `$?` after a pipe" rule,
inside a fixture, costing a real assertion that reported a defect which did not exist.

**What this does NOT do.** `LC-N5` is still WARN. Row 8 was the stated prerequisite for tightening
it (§9), and the declaration now exists — but the subject set has not been re-derived against it,
and row 7's recorded lesson is that the counts were of the WRONG SET. Deriving "which entries would
declare `kind: qualifier`" is a fresh measurement, not a consequence of this release.

**The ORIGINAL scoping block follows.**

**Why.** `extensions/README.md:152-157` concedes there is **no grain for rendering a rule inside a
core section**, so a consumer that only wants to *qualify* a section must shadow all of it verbatim
"and then you carry `base_sha` drift on prose you never meant to change." Consequence measured on
graph: **~300 of ~920 significant override lines are byte-identical core**, and
`check-25-universal-core.md` spends 132 lines to add the integer `34` to one table cell **[V for the
concession and the 132-line file; R for the ~300]**.

**Do.** `kind: qualifier` + `extends: <file>#<anchor>` + `position: append|prepend` — renders inside
a core section, carries **no `base_sha` obligation on prose it does not restate**. Two positions
only; a literal-prose anchor would be a third resolver, and `reconcile/lib.sh:17-31` records two
shipped defects from duplicate resolvers **[V]**.

Also allow `extends:` on ordinary entries (no `position:`) to narrow drift from file grain to anchor
grain. **This is the largest single friction win available: graph's 33 extensions carry ~956
(entry, commit) drift events at file grain, ~180 at anchor grain [R — re-derive]**, and
`EXTENSION-HOOK-DRIFT` is the top code at 31 of 76 pulls.

**Anchor `position:` matches.** Unanchored, `position:` also matches `disposition:` which appears in
`team-roles/code-reviewer.md` and elsewhere **[R]**.

**Fixture's load-bearing assertion:** a commit changing the hooked file **outside** the declared
anchor produces **no** `EXTENSION-ANCHOR-DRIFT`. That proves the narrowing is real and not a
relabelling.

### 9. `gate_types:` on check extensions — SHIPPED v0.197.0, and the scoping below was wrong twice

**SHIPPED — `356b417` (#280).** `gate_types:` on a `kind: check` entry; clauses **LC-E16** (`E14`),
**LC-E17** (`GM1`), **LC-E18** (`GM2`); `contract_version` **6**; **I47** binds `CHECK_HEAD_RE`
across the linter and the resolver; I36 gains a `GM[1-9][0-9]?` arm. Suite 77/77 with a
completeness control.

**The [R] premise was CONFIRMED and it was the only thing here that was.** The resolver does read
both layer dirs, parse frontmatter, and union anchors.

**"Closes the failure that script's own header records" is REFUTED as written.** The header records
two: the pre-v0.176.0 core-only resolve (closed in v0.176.0) and the MINIMUM-MECHANISM union hole
(an override shadowing a CHECK section and dropping its anchor). `gate_types:` touches neither.
It closes the header's OPENING claim instead — *"the gate runs, reports PASS, and the missing check
never fires"* — by a route the two-way resolve could not represent.

**"Subject set of 1" was wrong, and the correction is the release.** A check DEFINED only as a
heading has no anchor (so no ORPHAN) and no row (so no MISSING), and falls between both arms.
Measured with controls: **FOUR** — `19b`, `2s`, `35`, tombstone `33` — against a baseline of
`MISSING none / ORPHAN none / PASS`. FP set empty.

**The invariant already existed and could not reach it.** `validate-enforcement-map.sh` I6 asserts
"check heading(s) with no CHECK_LOADED anchor" — core's file only, in a distribution-only script.
**Third instance in this program of a guard whose subject set excludes the failure it describes**
(row 6's advertised home, v0.177.0's guard). When a row looks low-value, check whether the
mechanism that would catch its defect exists and is scoped away from the consumer.

**Two traps worth carrying.** (i) A hand-written probe counted THREE unloadable checks; the shipping
grammar found FOUR — the probe matched `## Check <id>` and missed `### <id>.`. The memory rule cuts
both ways: a probe can UNDER-count as easily as over-count. (ii) Hoisting `CHECK_HEAD_RE` out of
`defined_anchors()` broke **I45**, which lifts that function into a fresh shell — the unset variable
made it grep the empty string and harvest nothing, which is I45's PASS. Its zero guard caught it.
**Any hoist of a pattern out of a function must check who LIFTS that function.**

**The ORIGINAL scoping block follows.**

**Zero new detectors.** `core/scripts/validate-gate-manifest.sh` already reads `extensions/` and
`overrides/`, already parses entry frontmatter, and already renders
`anchors = core ∪ extensions ∪ overrides` **[R — confirm]**. Letting a `kind: check` entry declare
its own `GATE_MANIFEST` rows retires graph's 132-line `check-25-universal-core` override whose entire
delta is one table cell, and closes the failure that script's own header records.

### ⏹ SESSION BOUNDARY

### 10. the 8 absorptions, one arm per release

**STATE: arm 1 REFUTED, arm 2 SHIPPED v0.198.0 (`eb26178`, #281), arm 5 SHIPPED v0.199.0
(`901202e`, #282), arm 7 SHIPPED v0.200.0 (`853eab6`, #283), arm 6 SHIPPED v0.201.0
(`0cc4028`, #284), arm 8 SHIPPED v0.202.0 (`c695228`, #285), arm 3 SHIPPED v0.203.0
(`590289b`, #286). ONE arm remains — 4 — the weakest row in the table below. The row
order is NOT a sequence; take the arm that survives measurement.**

**Arm 3 SHIPPED v0.203.0 as `sprint-status.sh check-stories`. The absorber named in the
table was RIGHT; the arm was not, and the real subject was a numbered core check with
`enforcer: []`.** The table said "the producer half — core self-describes as PRODUCER +
READER". That was already scoped-and-doubted here on 2026-07-29 and the doubt was correct:
core genuinely produces. But the 1069-line consumer tool is not a producer either — its own
docstring opens *"story frontmatter is the single source of truth"* and it is a **drift
reconciler**, one of THREE consumer implementations of one core check.

- **The delta was found by asking what core's version IS** — arm 5's test, now the fourth
  instance and the only reliable one in this row. `gate-validation.md` Check 5 has always
  said *"Run: Read both files, compare status values programmatically"*, and
  `enforcement-map.yaml` carried `enforcer: []` for it. Five core files restate the duty
  (`dev.md`, `qa.md`, `code-reviewer.md`, `implementation.md`, `retro.md`) and **zero core
  scripts read a story file's status** — control: three read story files, for the Dev Agent
  Record and the locked anchor. Prose with five restatements and no program is the same
  shape arms 5 and 7 shipped against.
- **A [V]-shaped premise in this file's own "9 real core gaps" list was wrong.**
  `validate-story-status-consistency.sh` is listed there as NOT-absorbed. It is not a gap:
  core defines the check, numbers it, and states its predicate. What core lacked was the
  enforcer. **That list came out of the same subagent classification as the refuted rows;
  re-derive any entry of it before treating it as settled** — arm 4 is the last one, and
  the table's note on it already doubts its absorber.
- **The vacuity floor is the release, not the comparison.** All three consumer
  implementations went vacuously green at least once, on their own pipeline record: a
  story-id glob that matched none of the corpus (*"checked 0 story files"* printed beside a
  success line), a field set compared zero times for a whole sprint, a `**Status:**` grammar
  the story files no longer carried. So `check-stories` prints its COUNTS, Check 5's evidence
  clause now requires them in the gate log, and **"compared nothing" is exit 4** — never
  folded into 0.
- **The replay over real history found the release's own best evidence, and the fixture could
  not have.** 1019 states materialized with `git archive` and driven through the shipping
  code. Clean at HEAD; 6 true positives across the 40 states since graph's canonicals adopted
  this grammar. One of the six is the tree left by a commit titled *"fix(s290): story-290-1
  status left at review despite Phase 1 deploy+PVC confirmation"* — it rewrote `status:` in
  **four** yaml files and never touched the story file, which still reads `review` today.
  **The fix for a status drift shipped the drift, on the side nothing was reading.**
- **The replay also caught a check that would have fired on core's own output.** A `stories:`
  block containing only the placeholder comment is exactly what `sprint-status.sh roll`
  writes, and the first draft reported it as a finding. `empty` and `content-but-no-keys` are
  now different states: the second is the `- id:` LIST form the consumer ran a whole sprint
  on, the first is a freshly rolled sprint. **Run the replay before the fixture, not after —
  the fixture was written from the states the replay found.**
- **The unmutated control earned its place for the third time in this program, and loudest.**
  One assertion's setup was wrong, so it failed on the SHIPPING tool; eight of nine mutants
  then reported "entangled" for reasons unrelated to their mutations, and the ninth — the one
  whose assertion was already failing — came back **green**. A mutant harness with a broken
  assertion manufactures both false alarms and a false kill in the same run.
- **Two assertions reading one string is how one of them proves nothing.** The unresolvable-
  entry assertion and the id-collision assertion both keyed on `names no readable story file`,
  so the unresolvable-entry mutant failed both. The collision assertion now asserts on the
  IDENTITY of the file the tool read. This is row 4's recorded trap, one fixture over.
- **`adjudication` stays `llm`** — Check 2 is the precedent for an enforcer under an llm
  check, and `adjudication == "llm"` is the gate-adjudicator escalation predicate, so
  flipping it would change routing for a reason this release does not have.
- **The pre-push suite went red once on `apply-drift-refile`**, a fixture this release cannot
  reach (it drives `apply.sh` and the drift mapper; grep for every file this release touches
  returns nothing, with a control). Standalone PASS, the shipping `.githooks/pre-push` exits
  **0** on the same branch, and unmodified main gave 8/8 concurrent copies green plus a green
  full 8-way suite. **Second fixture in this program to show the intermittent-under-
  concurrency behaviour §9 records for `layer-readopt-gate` — that entry is now about a
  class, not a file.**

**Arm 4 is REFUTED as an absorption of `audit-main-since.sh`, and v0.204.0 shipped the one
core-owned slice inside it. ROW 10 IS CLOSED.**

**The absorber was misidentified, as this section already suspected — read both scripts, it
takes ten minutes.** `validate-cycle-commits.sh` counts ≥3 cycle commits per planning artifact
in `validation-cycle-log.md` over `<trunk>..<branch>`. `audit-main-since.sh` enumerates merges
over `<genesis>..main`, classifies each by changed paths, re-runs the class's validators in a
detached worktree at that merge's tree, and advances a watermark. No shared subject, input or
output. There is no mode of the one that is the other.

**And the arm has no core subject set, measured with controls against `core/` + `templates/`.**
Its predicate is `pr-class` (**0** hits), "PR class" (0), expected-validator sets (0),
`validator-runs` (0), watermark (0), `audit-results` (0), post-merge trunk audit (0 — "post-
merge" has 2 hits, both unrelated). Control: `provenance` matches 79 files, `audit` 68, so the
corpus was searched. The one `meta-gate` hit is `validate-provenance-block.sh` sourcing the
consumer's lib if present. **Core states no post-merge trunk-audit duty at all**, which is the
arm-5 test — an arm is absorbable when its predicate is spelled in core's language — returning
the opposite answer to the six arms before it.

**What WAS absorbable is one predicate, and it is the seventh time the arm name was wrong while
an absorption was real.** `audit-main-since.sh:233-258` verifies the operator citation that
lets a failing SHA past its watermark: it must name a bracketed escalation tag, resolve to a
real entry, and that entry must be RESOLVED/OVERRIDDEN **and** carry an
`Operator authorization:` line — *"otherwise any string after a `#` would launder a failing SHA
past the watermark."* Core's equivalent escape hatch, `core-paths.sh --audit-diff`, had the
identical laundering hole and no verifier: `grep -q 'Operator authorization:'` over the whole
of `pending.md`. That is written entirely in core's vocabulary — `escalations.md` defines the
terminal statuses and the citation shape, and `validate-escalation-resolution.sh` enforces
them — so the slice absorbed, and the rest did not. See the v0.204.0 CHANGELOG for the
measurement; the short version is that four of the eight lines satisfying core's grep on the
reference consumer are not citations, one of them a sentence stating that no citation exists.

**Two things worth carrying out of this arm.**

- **The check that finds the defect is often the one that shipped four releases ago.** The
  hole was in `--audit-diff`, which arm 5 shipped in v0.199.0, and its `PASS (with citation)`
  arm cleared **4 of 60** first-parent ranges on the reference consumer — v0.199.0 measured
  and recorded that number without asking what the citations were.
- **A probe's own vacuity nearly shipped a false differential.** The "old code" arm of the
  before/after comparison was a `git show` that failed, so the file was EMPTY — and an empty
  script exits 0, which is exactly the answer the arm was looking for. Caught by reading the
  output rather than the exit code. A differential needs a size check on both sides.

**Arm 8 SHIPPED v0.202.0 as `validate-fixture-drivability.sh` + I52. The arm NAME was
REFUTED and the absorption was real anyway — arm 2's lesson, third instance.**

The table called it "a consumer-registrable harness entry point", premised on the consumer's
647 lines of harness living outside the `tests/fixtures/<n>/run.sh` convention because there
was no seam to register them through. **There is one, and it is `run.sh` itself: a two-line
`run.sh` that delegates to an existing harness registers it, needs no new core grammar, and
was available the whole time.** Do not re-open "add a registration key". What was missing was
never the seam.

What WAS missing is the accounting. `core/git-hooks/pre-push`'s `[ -f "$d/run.sh" ] || continue`
prints nothing for a skip, so a driverless directory reads exactly like one that passed —
and that is **I20's hole, on the side I20's own header says it does not cover**: *"this
validator is a dev-repo gate … so I20 binds fixtures where they are AUTHORED."*

- **Fourth instance in this program of a guard whose subject set excludes the failure it
  describes** (row 6's advertised home, v0.177.0's guard, §7.9's I6). And this one had a
  SECOND mechanism that also could not reach it: **H1** states the same criterion for the
  consumer but only over fixtures a `kind: check` entry binds with `fixtures:`, and graph
  declares **zero** — §7.6 had already measured that zero and filed it under a different
  question. **When a row looks low-value, check BOTH: whether the mechanism exists and is
  scoped away, and whether a second one exists and is vacuous.**
- **Measured with the shipping code on graph `170ff9d8c`: 103 directories, 73 driven, 2
  declared undrivable, 28 undeclared.** FP set **empty**. The 2 that pass are core's own
  `check-h1-recursion` and `check-manifest-bypass` — the positive control that the exemption
  survives `install.sh`. Second control: the distribution's own `core/fixtures/` passes the
  same script unchanged. §7.6's "28 data-only fixture dirs" is CONFIRMED at 28; its "33"
  counted four loose FILES at the top of `tests/fixtures/` as directories.
- **The marker binding is the load-bearing half, not the trim.** The shipped script judges
  `tests/fixtures/`, where `install.sh` puts core's fixtures, so a diverged marker fails
  every consumer's next push on core files they did not write. That is I48's shape and it
  is why **I52** exists rather than a comment. Two arms, both fired.
- **Two layouts caught this one on the first try.** The fixture resolved its validator as
  `../../scripts/` and installed green in `core/` and RED under `scripts/install.sh` —
  exactly what `CLAUDE.md` warns and what I33 fails the build on. Fixed with the candidate-
  list idiom (`check-31-ac-falsifiability/run.sh:32`) and the seed now takes the resolved
  path as an ARGUMENT rather than resolving a second time. **Run the install-into-empty-tree
  check before believing any fixture that names a sibling core directory.**
- **The consumer pays 28 findings on its first push after this release**, and §8 carries the
  enumeration plus the hazard: half of them have a real external driver and want the
  delegating `run.sh`; declaring the exemption over those would be a false statement the
  script cannot detect and will accept.

**Arm 6 SHIPPED v0.201.0 as `validate-audit-anchors.sh --trunk-push` + pre-push arm 0.
The absorber named in the table was right; what the arm ABSORBS was not what the table
said.** The table calls it "the bounded Rule-(b) exception". Rule (b) is graph's own rule
about merging then running `scripts/ecs-deploy.sh` — pure domain, and core states **no**
branch policy anywhere (measured: one hit for `land via PR|push to main|refs/heads/main`
across `core/` + `templates/`, and it is a CI trigger; control, 33 files match `pre-push`).
Absorbing the prohibition would have imposed a workflow core never declared.

What IS core's is the **licence**: `retro.md` Step 5b tells the lead to update the anchor
SHA "in a follow-on commit on `main` after merge", because the retro-PR merge SHA is not
knowable until that PR has merged. Core wrote a standing exemption from its own PR route
and defined nothing about it. **106 instances on graph, every one unexamined.**

- **The arm-5 test decided this one.** "An arm is absorbable when its predicate is spelled
  in core's language." The *prohibition* is not; the *licence* is — core mandates the
  commit, names the file, and its schema already carries the backfill convention. Shipping
  the half core owns and refusing the half it does not is the whole release.
- **Neither pre-push hook was ref-aware at all** (control: both ~165 lines of other
  checks). The consumer hook's own header said "only TREE-LEVEL checks — ones decidable
  from the files on disk", which is the right boundary described by the wrong measure; it
  now says locally decidable. **Not** wired into the distribution's hook: this repo has no
  `_bmad-output/`, so the arm could not fire there — a check that cannot fire.
- **The FP set is empty and was measured on real history, not in a fixture.** Replayed
  with the shipping code over all **237** commits touching `audit-anchors.md` on graph's
  main: 236 PASS, 1 FAIL, and the FAIL is the true-positive shape. The predicate that made
  it empty is the narrow one — bound the *claimed* backfill, do not police the trunk.
  A blocking guard over all trunk pushes would have passed all three rejection arms and
  been wrong; the fixture's assertion 4 is that half, and it is what a "tighten it up"
  edit deletes.
- **The absorbed script's own defect is again the release's subject** (arm 7's shape, third
  instance). On ref creation it takes `range="$local_sha"` — every ancestor — so the first
  push of a trunk lists the whole history and cannot land.
- **`sys.stdin` inside a `python3 - <<PY` heredoc reads the heredoc's leftovers.** The mode
  read NOTHING in all nine cases it was first tested against, and every one of them looked
  like a pass. Only the explicit "no ref lines" branch surfaced it. Any mode that reads
  stdin must be drained in bash before the heredoc runs.
- **A join keyed on a shared prefix picks by file order.** I51 first extracted retro.md's
  subject template by its `chore(s<N>)` opening; retro.md carries a SECOND template under
  that prefix (gate-log rotation, Step 6f), so the vacuity mutant silently became a
  duplicate of the drift mutant. Caught by the fixture's vacuity arm — the arm that exists
  for exactly this — not by review.
- **An apostrophe inside a `$( ... <<PY ... PY )` block is the `ledger-reverify.sh` awk trap
  one file over.** `bash's` in a comment inside the heredoc opened a quote and produced a
  syntax error 200 lines away, in unrelated code.

**Consumer note for §8.** graph's own `no-direct-main-push` guard appears **disarmed on
that clone**: it is a pre-commit hook staged `pre-push`, but `.git/hooks/pre-push` is the
ai-dlc shim, which `exec`s `.githooks/pre-push`, which names neither pre-commit nor the
guard. Measured by reading all three files. So core's arm 0 is likely the first thing that
actually enforces this on the reference consumer — verify before asserting it in the prompt.

**Arm 7 SHIPPED as a new script, `core/scripts/validate-mutation-red.sh` — and the table's
absorber was the wrong file, exactly as this section warned.** `validate-audit-anchors.sh`
reads the audit-anchors housekeeping schema; the consumer's detector replays a claimed
mutation-red anchor. Two different things both called "anchor". The absorber did not exist,
and what core had instead was PROSE — arm 5's lesson, second instance in two releases:

- **Ask what core's version IS.** Four rule files (`dev.md`, `qa.md`, `code-reviewer.md`,
  `gate-validation.md`) demand a committed RED run against the REAL source under test.
  Measured: **zero of core's 31 shipped validators mention mutation at all**; the 16 core
  files that do are prose. Control: 42 core files mention provenance.
- **The absorbed script's own defect was the release's subject.** Its `sed`-based rewrite left
  the file UNCHANGED for a line past EOF, for a replacement identical to its line, and for a
  replacement containing `@` — and printed "claimed anchor is unproven" for all three. Core
  splits the verdict four ways (0 proven / 1 survived a real mutation / 2 nothing was mutated
  / 3 restore unverified). Reproduced with a positive control before any code was written.
- **Verdict-compatibility is measurable on the consumer's own fixture.** graph's three-case
  Check 35 non-vacuity test passes unchanged when driven against core's script; an
  always-exit-0 stub in the same position turns it red on its first case. That comparison cost
  ten minutes and is worth repeating for every remaining arm — the consumer usually has the
  discriminating fixture already.
- **A new core script needs no manifest edit; a new FIXTURE needs four.** `core/scripts/*`
  ships by glob **[V, re-confirmed]**. The fixture's four enumerations were forgotten and
  `validate-enforcement-map.sh` named both missing halves on the next run — the mechanism
  works, so do not spend measurement on it, just run the validator early.
- **A companion invariant was cheap because the citation surface already existed.** I50 joins
  every `scripts/ai-dlc/<validator>` path a shipped file names to the scripts core ships: 31
  citations, zero ghosts, one direction only (`validate-cycle-commits.sh` ships and nothing
  cites it by path, so the reverse arm would fail on an unrelated fact). Note for row 11 and
  for whoever revisits arm 4: **that script is core's only shipped validator no shipped file
  names**, which is worth a look on its own.

**Arm 1 (`audit-rule-exercise.sh` → `audit-rule-files.sh --exercise`) is REFUTED. Do not
re-attempt it without a new predicate.** It has no core subject set:

- Core defines **no anchored per-rule emission grammar**. The 6 rule-id-shaped strings in
  `core/` + `templates/` are all prose citations inside comments (control: 66 `Rule 26` hits
  from the same corpus, so the grep ran).
- Core has **no gate-log corpus enumerator** — `gate_log_corpus` and `gate-log-corpus.sh` are
  both zero in `core/` (control: 5 core scripts read gate-log files, each with its own glob).
- The consumer script keys on `PI-S269-1  displays_subgraph_aggregate`, graph's own AC2
  instrumentation sites, and an S288 sprint floor. Every one is domain.
- **And the row's own evidence says so.** The header sentence quoted as proof — *"Split out of
  scripts/ai-dlc/audit-rule-files.sh"* — continues: *"Upstream shipped its own
  audit-rule-files.sh (a python3 implementation with no bash-callable seam), so … this
  project-specific audit lives here instead."* The split reason was domain specificity, not a
  missing flag. **"Split out of X" was read as "belongs in X".**

**Arm 2 SHIPPED as `validate-provenance-block.sh --strays`.** Not `--scope`: core's validator
was never scope-bounded, it is single-artifact, and the arm is a corpus-wide floor. Homes,
subject vocabulary, excluded dirs and the generated-region markers all come from
`schemas/provenance-block.json`; consumers extend the homes through the existing additive
`extensions/known-skills.json` under `party_mode_homes`. **I48** binds the new top-level
`region_slug` across its renderer and the scan's carve-out. Wired into BOTH pre-push hooks.
Measured on graph `170ff9d8c` with the shipping code in a worktree at that sha: 889
envelope-bearing files, 5 findings, all under `scripts/tests/**`, all closed by one line of
extension. Not absorbed: the script's `--fixture-provenance` mode, which is pure domain.

**Three lessons from arm 2, for the six that remain.**

1. **Read the whole header sentence.** Arm 1 died on the clause after the one that was quoted.
   Every remaining arm's justification is a sentence someone summarised.
2. **The arm name in the table is a guess.** Arm 2's was `--scope`, premised on core being
   "current-scope-only". Core's validator takes one artifact path and always has. The name was
   wrong AND the premise behind it was wrong, and the absorption was still real.
3. **Check whether the mechanism exists and is scoped away** before calling an arm low-value —
   §7.9's lesson held again here. `sync-taught-schema.sh` already looks for provenance blocks
   outside a generated region; its corpus is `skills/` + `team-roles/` and its grammar is fenced
   examples only, so it could not reach a block in `server/`. Bounded overlap, stated in the
   schema comment rather than discovered later.

**Arm 5, SHIPPED v0.199.0 — what the five remaining arms should take from it.**

- **The stated rationale was false and the absorption was real anyway.** That is arm 2's
  lesson repeating: the table's *reason* is a summary someone wrote, and refuting it does not
  refute the arm. The real delta was one the table never mentioned — core stated the whole
  procedure in PROSE for an agent to run by hand, and the consumer had written the executable.
  **Ask what core's version IS, not whether core has one.**
- **Its two carve-outs were core's own vocabulary, not domain.** The `chore(ai-dlc-update):`
  subject is written by `ai-dlc-update/SKILL.md`; `docs/escalations/pending.md` is named in 23
  core files. An arm is absorbable when its predicate is spelled in core's language — that is a
  cheaper test than reading the whole script, and it is what killed arm 1.
- **Measure the arm on the consumer's real history, not only in a fixture.** 60 first-parent
  ranges gave 47 clean / 6 reconcile-exempt / 4 citation-exempt / 3 DORMANT / 0 FAIL, and the
  4 citation-exempt rows are where the FAIL arm was proven: strip the citation on a `cmp -s`
  worktree copy and a real `fix(s299-1)` commit reports four in-place core edits.
- **A new invariant's citation corpus will scan `core/fixtures/`.** I49 went red on its own
  fixture's ghost token and then on its own grep flags. §7.6 recorded this once; it recurred
  immediately. Budget for two red runs and assemble alien tokens at runtime.
- **A new fixture directory must be `git add`ed before the suite means anything.** The
  untracked dir failed `ledger-status-vocabulary`'s I8 arm and nothing else — exactly the
  control-earns-its-place trap in §3.

**Arm 7 still carries its warning, and arm 5's original one is kept because it was correct:**

- **Arm 5's stated rationale was false.** *"the guard is PreToolUse-only"* — core's
  core-layer-immutability gate check computes `git diff --name-only <sprint-base>..HEAD`, asks
  `core-paths.sh --is-core` per path, and describes ITSELF as *"the BACKSTOP for whatever reached
  disk anyway — a shell write, a `git push --no-verify`, or a consumer without the hook wired."*
  A real delta may still exist (that check is agent-run prose; the consumer's is an executable
  with a reconcile-commit exemption and an operator-authorization escape hatch, applied
  per-commit rather than to the net diff) — but it is NOT the one the table states, and it must
  be re-derived before a release is spent on it.
- **§7.6's "highest-regression edit" warning does NOT apply to arm 5.** I25 binds only
  `parse_manifest()` and `to_consumer_glob()` byte-identically across `core-paths.sh` and
  `ai-dlc-core-guard.sh`. Adding a MODE that calls the existing `--is-core` derivation touches
  neither function and needs no guard change. That warning was about
  `--is-consumer-machinery`, a NEW derivation — which is itself refuted (§7.6).
- **Arm 7's absorber looks misidentified.** `check-mutation-red-anchor.sh` reproduces a claimed
  MUTATION-red anchor (`docs/coding-conventions.md` "RED-Anchor Test Contract");
  `validate-audit-anchors.sh` reads the audit-anchors housekeeping schema (sprint + retro-merge
  sha). Two different things both called "anchor". Verify the absorber before the arm.

The ORIGINAL table follows. Every unshipped row is still **[R — a subagent's classification]**:

| Consumer script (lines) | Core absorber | The arm |
|---|---|---|
| ~~`audit-rule-exercise.sh` (106)~~ | ~~`audit-rule-files.sh`~~ | **REFUTED — see above. No core subject set.** |
| ~~`scan-stray-provenance.sh` (156)~~ | ~~`validate-provenance-block.sh`~~ | **SHIPPED v0.198.0 as `--strays`.** The stated arm name and premise were both wrong; the absorption was real |
| ~~`generate-sprint-status.py` (1069)~~ | ~~`sprint-status.sh`~~ | **SHIPPED v0.203.0 as `check-stories`.** The absorber was right and the arm was not: the consumer tool is a drift reconciler, not a producer, and the real subject was `gate-validation.md` **Check 5** — a numbered core check whose own text says "compare status values programmatically" and whose `enforcer:` was `[]`. Only the status arm is absorbed; neither consumer tool's WRITE side is |
| ~~`audit-main-since.sh` (349)~~ | ~~`validate-cycle-commits.sh`~~ | **REFUTED v0.204.0 — the absorber was misidentified AND the arm has no core subject set (measured, with controls). The one core-owned predicate inside it — verifying that an operator-authorization citation IS one — was absorbed into `core-paths.sh --audit-diff`.** The original scoping note follows: **[Scoped 2026-07-29, NOT shipped: the absorber looks MISIDENTIFIED, arm 7's shape a third time. `validate-cycle-commits.sh` counts >=3 cycle commits per planning artifact against `validation-cycle-log.md`; the consumer script is a post-merge fail-closed audit that re-derives PR class and re-runs validators in a detached worktree. It also sources `pr-class.sh` AND `meta-gate.sh`, both on the "9 real core gaps, not absorbed" list — so this arm depends on two absorptions the program deliberately deferred. Verify the absorber before the arm]** |
| ~~`check-protected-core-paths.sh` (163)~~ | ~~`core-paths.sh`~~ | **SHIPPED v0.199.0 as `--audit-diff`.** The arm NAME was right and the stated rationale was wrong; the real delta was prose-vs-executable |
| ~~`validate-no-direct-main-push.sh` (47)~~ | ~~`core/git-hooks/pre-push`~~ | **SHIPPED v0.201.0 as `--trunk-push` + pre-push arm 0.** The absorber was right; the ARM was not. "Rule (b)" is graph's domain rule and core states no branch policy — what core owns is the LICENCE Step 5b grants, not the prohibition around it |
| ~~`check-mutation-red-anchor.sh` (73)~~ | ~~`validate-audit-anchors.sh`~~ | **SHIPPED v0.200.0 as `validate-mutation-red.sh`.** The absorber was the wrong file and core's version was PROSE; the absorbed script's own three unmutated-file misgradings are what the release fixes |
| ~~`retro-replay-harness.sh` + 6 `tests/test-*.sh` (647)~~ | ~~the `tests/fixtures/<n>/run.sh` convention~~ | **SHIPPED v0.202.0 as `validate-fixture-drivability.sh` + I52.** The arm NAME was refuted — `run.sh` already IS a registrable entry point and may delegate. The real gap was that nothing told the consumer 28 of its 29 fixture directories were being skipped |

**Not absorbed:** the 9 real core gaps (~~`validate-story-status-consistency.sh`~~ — **NOT a gap;
core defined the check and lacked the enforcer, absorbed by v0.203.0 — `pr-class.sh`,
`meta-gate.sh`, `guarded-merge.sh` — core has **no PreToolUse `Bash` arm** — `install-hooks.sh` plus
the arming shim, `ai-dlc-reset-snapshot.sh`, `ci-local.sh`'s ai-dlc part) and 3 purely-domain items.
They relocate into the home and the report emits their carrier every pull.

**This list is [R] and one of its entries has now been falsified by measurement.** It came out of
the same subagent classification as the refuted arm rows. Arm 4 depends on two of its entries;
re-derive them rather than inheriting the label.

**Evidence this converges without a ban [R]:** graph **retired its own `validate-ci-gates.sh` fork**
the moment core shipped `AI_DLC_CI_SURFACE` / `AI_DLC_CI_ALIAS_TABLE`.

### ⏹ SESSION BOUNDARY

### 10a. wall-clock reduction across the whole distribution

**Operator-requested 2026-07-29, and the scope is stated in their words: not "can these
scripts be multithreaded" but "can we reduce wall-clock time, if so, how?"** Parallelism is
one route and probably not the biggest one. Redundant work, work done at the wrong time, and
work done twice over the same subject are all wall clock, and all of them are cheaper to
remove than to parallelise. **Refactoring is explicitly authorised. Marginal percentage
savings justify the change** — that is the operator's stated bar, so do not reject a
candidate for being small; reject it only for being unmeasured.

**"BY ANY ROUTE" EXCLUDES LOSS OF FIDELITY — the operator stated this explicitly, and it is
the constraint that decides the row.** Every unit must detect afterwards exactly what it
detected before: same subject set, same predicate, same findings on the same input. A
narrowing, a sampling, a cache, a skip-if-unchanged, an early exit — each of these buys time
by not looking, and this repo's named defect class is a check that cannot fire reading
exactly like one that passed. **Speed taken out of coverage is not a saving, it is the defect
with a stopwatch attached.** If a candidate cannot be shown to preserve fidelity, it is out
of scope for this row no matter how large the number beside it.

**Do the measurement before the design.** Every number below is either stale, a floor, or
[R]. Nothing here has been re-derived for this row.

**What is already known, and its shape.**

- The distribution's fixture suite went **7m06s → 2m34s → ~1m34s** by making it 8-way
  (`AI_DLC_FIXTURE_JOBS`) and by fixing ONE fixture. The recorded lesson from that work is the
  one to carry: **one fixture set the floor**, so an average is the wrong statistic — profile
  per unit and attack the tail, not the mean.
- **`core/fixtures/enforcement-map-sites/` is that tail today** — roughly 81s of a ~94s
  suite when last measured, and it grew again in v0.202.0 (Assertion 25). The out-of-band
  note below §6 already scopes splitting it into nine per-invariant fixtures; that split is
  the single largest known win and it also deletes six hand-maintained path rebindings and
  an existing entanglement between its assertions 1 and 5. **Fold that item into this row
  rather than leaving it out of band** — it is the same work under a bigger scope.
- The suite is not the only clock. **A push is ~2min** and `.githooks/pre-push` runs the
  whole suite; the consumer's `core/git-hooks/pre-push` runs theirs. Both are in the
  operator's inner loop, several times per release.

**Routes to enumerate and measure, in the order they are likely to pay.** This list is a
starting hypothesis, not a plan — the profile decides.

1. **Redundant re-derivation.** How many scripts re-run the same extraction? `validate-
   enforcement-map.sh` alone lifts several functions into fresh shells (I45 does it to
   `defined_anchors`), and the fixture harnesses re-seed whole trees per assertion —
   `enforcement-map-sites`' `restore()` copies ~1.4 MB and its own comments say so.
2. **Process-per-item shells.** Fixtures that fork a bash per assertion, greps run once per
   file where one pass would do, `git` invoked in a loop over paths it accepts as a list.
3. **The same subject read more than once.** Several validators walk the same corpus and
   extract different things from it; a single pass that feeds both is faster and detects
   identically. This is a legitimate route because nothing is skipped. **Its illegitimate
   twin — narrowing a scan to a changed-path set, sampling, or caching a result across runs —
   is OUT OF SCOPE under the fidelity constraint above.** The tell is simple: if the change
   can make a finding disappear on any input, it is the twin.
4. **Parallelism where it is still serial.** The distribution suite is 8-way; individual
   validators, the two pre-push hooks' step sequences, and the fixture harnesses' internal
   assertion loops are not. 18 cores sit idle.
5. **Work at the wrong time.** Moving a check EARLIER — `pre-push` to `pre-commit` — costs
   no fidelity and shortens the loop the operator actually waits in. Moving it later, or
   making it conditional on what changed, is the twin in route 3 and is out of scope.
6. **The runtime itself, and it is not restricted to runtimes already installed.** Most of
   this machinery is bash driving `grep`/`sed`/`awk` in loops that fork a process per file,
   per path, per assertion — `core-paths.sh` runs a nested `case` over every glob for every
   changed path, and the fixture harnesses fork a shell per assertion. `validate-cycle-
   commits.sh` already does its analysis in a single `python3` heredoc for exactly this
   reason and `gen-architecture-index.js` is node, so the precedent for leaving bash is
   inside the distribution already — but **that precedent is evidence, not the boundary.**
   Measure whether a hot unit is faster as one process in another language, and whether the
   harnesses themselves (the fixture runner, the two pre-push hooks) should dispatch from a
   different runtime entirely. **A language or runtime the tree does not currently depend on
   is in scope**, including a compiled one; an added dependency is a cost to weigh against
   the measured saving and to state in the release, not a reason to stop measuring. `bash
   3.2` compatibility is a constraint on the bash that remains, not an argument for keeping
   bash. The fidelity rule above is the only hard gate and it applies unchanged: a
   reimplementation must produce byte-identical output on a real tree AND still fail every
   mutant that proved the original fires.

**This list is not exhaustive and is not a menu.** It is where the previous session
expected the time to be, written down so it does not have to be re-derived. Any route that
reduces wall clock without reducing fidelity is in scope, including ones nobody here
thought of — the profile decides, and a candidate is rejected for being unmeasured, never
for being unlisted.

**Two hard constraints, both learned here.**

- **Parallelism needs a completeness control.** An 8-way run that silently drops a unit
  reads exactly like a fast green run. Every parallel harness must report the count it
  ran and fail if that count is not the count it enumerated. v0.197.0's suite shipped
  "77/77 with a completeness control" for this reason.
- **`core/fixtures/layer-readopt-gate/` is intermittently red under the 8-way suite and it
  is COLD-START correlated** — see §9 for the full reproduction. Any change to concurrency
  in this row will be blamed for it. Read that entry BEFORE touching the runner, and note
  its instruction: force the cold condition, do not repeat-run a warm tree.

**Deliverable.** A measured table — unit, current wall clock, proposed route, expected
saving, and the fidelity proof — then releases against it, largest first. **A timing
improvement whose only evidence is a stopwatch is not shippable here.** The fidelity proof
is concrete and it is the same shape every release in this program has used: the mutants
that proved the unit fires before the change must still fire after it, unchanged, and the
unit's output on a real tree must be byte-identical across the change. Both, not either.

---

#### THE MEASUREMENT — taken 2026-07-29 on an idle 18-core machine, every fixture timed individually and serially

**Both figures in the "what is already known" block above were stale by more than 2x, and
in the same direction.** Re-derive before quoting anything below, too.

| | Handoff said | Measured |
|---|---|---|
| 8-way suite | ~1m34s | **208s** |
| `enforcement-map-sites` | ~81s | **194.3s** |
| Fixtures driven | 75 | **82** (83 after v0.205.0) |
| Serial cost of the whole suite | — | **464.8s** |

**`enforcement-map-sites` was 42% of the serial suite by itself, so it WAS the 8-way
floor** — 194s against a 208s suite. The pool had nothing to do with the wall clock.

Serial per-unit, top of the tail (the full profile is
`scratchpad/fixture-serial-profile.tsv` from that session and is worth re-taking, not
re-reading):

| Unit | Serial | Disposition |
|---|---|---|
| `enforcement-map-sites` | **194.3s** | **v0.205.0 -> 107s.** Not the fixture: it invokes `validate-enforcement-map.sh` 42x and that validator was 5.05s |
| `wait-stale-deliverable` | **51.9s** | **UNDIAGNOSED.** Next pole. Suspected sleep-bound, which is a different problem from fork-bound and the fidelity rule bites differently — a shortened wait can change what is detected |
| `layer-contract-conformance` | **45.6s** | **UNDIAGNOSED.** Next pole after that |
| `consumer-machinery-home` | 32.4s | untouched |
| `ledger-status-vocabulary` | 31.1s | untouched |
| `layer-readopt-gate` | 14.8s | untouched — and see §9 before touching concurrency near it |
| everything else | < 8s each | 77 units, ~64s combined |

The non-fixture pre-push steps are **~6.2s in total** and `validate-enforcement-map.sh`
was 4.9s of it. After v0.205.0 the whole non-fixture half is ~3.7s. **There is nothing
left to win there** — the remaining six steps are 0.02s to 0.84s each. Do not spend a
release on them.

**The shape of the win, and it generalises.** The validator's profile was 1.7s user
against 2.7s system at 86% CPU — that is process creation, not work. Six invariants
evaluated their predicate by forking `grep`/`awk`/`sed`/`jq`/`basename` **once per item**
over a corpus they could read once. Reading the corpus once is a legitimate route (nothing
is skipped, no finding can disappear); it is route 3 in the list above, and it paid 51% of
the unit. **Expect the same shape in `layer-drift.sh`, `ledger-reverify.sh` and
`validate-layer-entries.sh`, none of which were profiled here.**

**What v0.205.0 shipped:** validator 5.05s -> 2.47s, fixture 194.3s -> 107s, **suite 208s
-> 124s (-40%)**, 83/83 verdicts.

**The proof shape that worked, and reuse it verbatim.** Byte-identical output on a passing
tree proves only that a green run stayed green — it says nothing about whether a check
still FIRES, which is the whole question when you rewrite a predicate. Three parts:

1. A **differential wrapper** substituted for the validator inside a scratch copy of
   `enforcement-map-sites`, running the edited copy and the pre-change baseline over the
   same mutated tree at all 26 assertions. The baseline runs in a `cp -R` COPY of the
   tree, never in it — the tree's own contents are inside several invariants' subject
   sets, so swapping the script in place turns assertion 0 red for reasons unrelated to
   the edit. Normalise the two tmp roots, including the doubled slash `${TMPDIR}/` leaves
   in one and `cd`+`pwd` removes from the other, or paths survive into the diff and read
   as a behavioural difference.
2. A **mutation battery**, one case per rewritten unit: baseline must fire, edited must
   fire, outputs byte-identical, plus an unmutated control tree clean under both.
3. A **knock-out control**: disable each rewritten `err` in turn and require **exactly
   one** assertion to go red.

**Prove the harness can report a mismatch before trusting a clean one** — a deliberate
one-line change to a rewritten invariant must make it speak. It did.

**Three traps this row paid for, all of them harness bugs rather than code bugs.**

- **`RC=$?` assigned inside `$( )` never reaches the caller.** The battery's exit-status
  assertion read a variable the subshell could not write back and passed on every case
  before comparing anything. Write the status to a FILE.
- **`awk`'s `sub()` has no `\1` backreference.** Two mutations "landed" (`cmp -s` saw
  changed bytes) and inserted a literal `\1`. `cmp -s` proves a mutation happened; only
  the assertion proves it mutated the thing under test — the recorded trap, hit again.
- **`bash $s` does not word-split in zsh.** Timing a list of `"script --flag"` strings
  gave `rc=127` on every multi-word entry and 0.02s beside it, which reads exactly like a
  script that is missing. Use `bash -c "$s"`.

---

#### v0.206.0 — THE ORDERING ABOVE WAS WRONG, AND THE REASON GENERALISES

**`bd0bf65` (#289). Suite 124.9s → 72.0s (−43%).** Read this before trusting any per-unit
duration in this file.

**Serial duration is the wrong statistic for a pooled suite.** The row queued
`wait-stale-deliverable` (51.9s) then `layer-contract-conformance` (45.6s) by how long each
takes ALONE. What decides the suite is which unit is on the CRITICAL PATH, and that needs a
start timestamp as well as a duration. Instrumented at the shipping `-P8`:

| Unit | Duration | Starts | Ends | In a 124.9s suite |
|---|---|---|---|---|
| `enforcement-map-sites` | 120.0s | 5.0s | **124.9s** | **the whole critical path** |
| `wait-stale-deliverable` | 49.5s | 35.4s | 84.9s | 40s of slack |
| `layer-contract-conformance` | 33.7s | 9.0s | 42.7s | 82s of slack; **24.8s alone** — v0.205.0 had already halved it and 45.6s was stale |

Both queued units finished with the suite still running. **Either release would have moved
the number by zero.** Profile per unit AND per schedule; a duration without a start time
cannot tell a pole from a passenger.

**The fixture was not slow, it was serial.** 29 assertions, 42 validator runs, and every one
already re-seeded a pristine tree before it ran — they were independent and merely written in
a row. Each is now a function in its own process against its own seed, run through a pool:
**107s → 25s**. Four things that had to change, and each is the shape to expect next time:
four assertions inherited a path bound by the assertion above them (fine in one process, an
unset variable under `set -u` in separate ones); the assertion list is DERIVED from the file's
own function definitions with a zero guard; a missing verdict is a FAILURE, not a gap; the
control stays serial and first.

**`AI_DLC_FIXTURE_JOBS` 8 → 16.** The hook had said EIGHT, NOT MORE for four releases on a
measurement that was correct when taken and was of a floor-bound suite. Re-measured with the
floor gone: `-P8` 95.5s, `-P12` 80.4s, `-P16` 72.0s, `-P24` 64.2s, 83/83 at each. Sixteen
because `-P24` nearly doubled individual units through contention (a 25s fixture took 47.6s).

**§9's intermittent class fired during this work.** Two of five `-P8` rounds went red, on
`apply-drift-refile` and `layer-readopt-gate` — that class exactly, no other fixture. Cleared
by §9's own route (unmodified `main` 83/83 over five rounds; zero hits for every path the
release touches inside both fixture dirs, control 22 and 6; both pass standalone; shipping
`-P16` 83/83 over five rounds). **New data point for §9: `layer-readopt-gate` also failed a
STANDALONE run taken while ten concurrent suite rounds were in flight, and passed 3/3 once the
machine was idle. The correlation is with LOAD, not only with a cold cache, and "passes
standalone" is not the control §9 took it to be.**

**Next on this row, and neither is declined:**

1. **`wait-stale-deliverable`, ~52s, now the critical path.** Sleep-bound, not fork-bound: its
   14 cases each wait out a beat quantum in turn and they are independent, so the fix is the
   same shape as v0.206.0's. **It is NOT provable the same way.** Its assertions carry
   wall-clock bounds (`ELAPSED -le 1` for "returned without sleeping", `-ge 6` for a quantum
   honoured), so a contention-inflated beat trips a real assertion for a reason unrelated to
   what it tests. A byte-identical differential is necessary and not sufficient; this one needs
   repeated-run evidence at the shipping pool size.
2. **A content-keyed suite skip — operator-proposed 2026-07-29, and NOT the narrowing this row
   rules out.** The suite re-runs in full on a push that changed only `CHANGELOG.md`, `VERSION`
   or `docs/` — files no fixture reads. The four trees the seeds copy (`core/`, `scripts/`,
   `.githooks/`, `templates/`) are **declared in the seeds**, so a suite-level key over them is
   derived, not hand-listed. **The operator's own gotcha is the decisive design constraint: a
   script calls another script, so a per-unit key would have to close over the whole call
   graph.** A suite-level key sidesteps it — the union of those four trees is a superset of any
   call chain inside the distribution. What escapes it is what lives OUTSIDE them, and that is
   the list to key on as well: `bash`, `grep`/`sed`/`awk`, `python3`, `git`, `jq`. Three more
   conditions, each learned from a defect this repo already has: the key must cover **listings,
   not only contents** (several invariants fire on a directory that has NO row, so a new empty
   directory is an input); a hit must **announce itself and name its key**, because a silent
   cached green is the check-that-cannot-fire class with a stopwatch; and a hit must be refused
   when the fixture SET changed. **The hit rate is the one number not measured** — `main` is
   squash-merged, so its history records releases and not the pushes inside them, which is
   exactly where the repeat runs happen. Measure it from the push record, not from `git log`.

**The general lesson, and the operator stated it during this release: one optimisation does not
retire another.** A unit with slack today is the critical path tomorrow, and here tomorrow
arrived inside the same release — `wait-stale-deliverable` had 40s of slack when the work
started and was the pole before it finished. Measurement decides the ORDER, never the
membership.

---

#### v0.207.0 — SHIPPED `8eaf896` (#290). The held release went out with the finding leading.

**All four ordered steps of the block below were executed. Read this before re-opening any of them.**

1. **The idiom is swept, repo-wide: 300 sites, 55 files, all converted to here-strings.**
   The discovery expression matters and the block below understated it — matching the literal
   `grep -q` cannot see `grep -Eq` or `grep -Fxq`, and it MISSED
   `core/scripts/validate-layer-entries.sh`, the ERROR-tier authoring linter. Use
   `| *grep -[A-Za-z]*q`. Exposure split, with a control: **250 sites in 38 files that set
   `pipefail`** (live) and **44 in 17 that do not** (latent — `set -u` alone leaves the
   pipeline reporting grep's status, which is correct). All 300 converted anyway; a file gains
   `pipefail` in one line.
2. **Fidelity was decided by measurement, not by the end-anchoring question the block asked.**
   The real question is whether a pattern can match an EMPTY line, because that is the only
   thing a here-string's extra newline adds. `printf '%s\n'` and `echo` sites (163) are
   byte-identical by construction. Of the 137 `printf '%s'` sites, **0 of 115 resolvable
   patterns match an empty line** (control: an empty-matching pattern IS caught by that
   harness); the 22 built from a variable were adjudicated one by one — each has a literal
   prefix, a length floor, or a variable non-empty at its assignment.
3. **The differential caught two real breakages**, which is the answer to "would a clean
   differential have proven anything". `check-31-ac-falsifiability` and
   `layer-catalog-collision` each drive a `sed` mutation that QUOTES the shipped line it
   targets; the sweep rewrote those lines and both `cmp -s` guards fired. **Expect this from
   any mechanical sweep: a mutation program that quotes its subject is a hidden edge of the
   subject set.**
4. **I54 ships, with its own two probes** — one of the banned shape it must match, one of the
   permitted shape it must not. 280 lines reported on the pre-sweep tree, zero after. Its
   subject set is **walked from `REPO_ROOT`, never `git ls-files`**: this validator runs inside
   seeded fixture trees that are not repositories, where git answers empty and would trip the
   zero guard on every assertion in `enforcement-map-sites`.
5. **`core/fixtures/early-exit-reader/`** (`.dist-only`, 0.09s) is the negative-direction proof
   the block demanded, made permanent: two generated checkers of opposite form and identical
   negative polarity, the converted one reporting a 200 KB violation and the banned one scoring
   the same input clean, with a large-clean control and a small-violating control so the cause
   is pinned to size rather than to a broken generator.

**§9 IS NOT CLOSED, AND THE EVIDENCE POINTS AWAY FROM THIS BEING ITS CAUSE.** The block below
called it "almost certainly" the intermittent-red class and said to test it first. Tested:

- The intermittency needs a threshold that moves with load. **It does not move** — 32K correct,
  64K wrong, idle and at 24-way load alike. This is a size trap, not a race.
- **Every converted site was instrumented on a tree copy** to log the byte length it actually
  reads, over a full 16-way suite run: 287 of 300 sites, 8,399 observations. **Exactly one
  observation reached the 64 KiB buffer** — `reconcile/ledger-reverify.sh:290` at 226,919 bytes
  — and that site was **already a here-string**, untouched by the sweep. The largest converted
  site observed is `enforcement-map-sites:481` at **23,061 bytes**.
- A/B in two fixed trees, 6 alternating rounds of 10 concurrent `layer-readopt-gate` copies:
  **before 2/60, after 0/60.** Suggestive only — 2 events is not a rate, and no failing copy
  carried `write error: Broken pipe`.

So the class was real and measured but, under the suite's current workloads, **latent rather
than firing**. Whoever picks §9 up inherits a narrowed field, not a closed one.

**ONE ITEM REMAINS ON ROW 10a: the content-keyed suite skip** (scoped in the v0.206.0 block
above). The profile is now FLAT — six units run 34.5s–45.9s and all start within 6s of t=0 —
so no further scheduling change can pay. The next lever is doing less work, not spreading it
wider.

---

#### v0.208.0 — SHIPPED `8344631` (#291). ROW 10a IS CLOSED, and §9 has a cause.

**The content-keyed suite skip shipped: ~50s → 0.3s on a push that changed only
`CHANGELOG.md`, `VERSION` or `docs/`.** But read the finding first — it is what the release
leads on and it retires the oldest open item in this file.

**§9's INTERMITTENT-RED CLASS IS DIAGNOSED AND FIXED. It was a fixture writing into the
repository under test.** `core/fixtures/taught-schema/run.sh` proved three of its checks fire
by mutating the package — stripping the forbidden list out of the real
`provenance-block.json`, dropping a probe into `core/team-roles/`, editing the schema again —
and every one of those writes landed in the **live tree**. Under the 16-way suite that is one
writer racing fifteen readers, and the error is unambiguous once visible:
`cp: core/team-roles/zz-taught-schema-fixture-probe.md: No such file or directory` —
`enforcement-map-sites`' seed finding the probe gone mid-copy, killed by `set -e`, reporting
`FIXTURE BROKEN` on **whichever assertion was seeding at that instant**. Seen on three
different assertions in three rounds, which is exactly why it looked like three defects and
why "passes standalone" was true every time.

**Measured: unmodified `main` 5/5 clean, the branch before the fix 3/5 red, after the fix 5/5
clean at 85/85.** The first control attempt was INVALID and is worth carrying: a `git archive`
copy has no `.git`, so `ledger-status-vocabulary` fails there *deterministically* and that tree
can answer nothing about intermittency. The schema window is the worse half and emits no error
at all — for two assertions the real schema is missing its forbidden list.

**§9's own entry should now be read as closed on cause, not merely narrowed.** v0.207.0
correctly measured that the early-exit-reader class was NOT it; this is. Both fixtures §9
records — `layer-readopt-gate` and `apply-drift-refile` — copy real trees, which is the
property that made them the two that showed it.

**No enforcer for the class, and the release says so.** A grep cannot tell a sandbox `$ROOT`
from the real one — measured, the FP set is most of the seed corpus — and a before/after tree
comparison cannot see a transient write that is cleaned up, which is precisely this one. What
IS guarded is the surviving half: after a green run the pre-push recomputes the content key and
**refuses to record it** if the suite changed the tree, naming both keys. Proven by a probe
fixture, and the first version of that probe was a **no-op that `cmp -s` passed** — appended
below a `run.sh` that exits first — so it is asserted behaviourally now.

**THE ROW'S OWN PREMISE FOR THE SKIP WAS WRONG, in the way this file keeps being wrong.** It
said to key on four trees "declared in the seeds". Those four are **one fixture's seed list**
(`enforcement-map-sites/seed.sh`), generalised to all 85. And `ledger-status-vocabulary` builds
its subject tree from `git ls-files`, so it copies **every tracked file** — `docs/` and
`CHANGELOG.md` are inside a fixture's own input tree. The shipped key is therefore
**everything EXCEPT a declared exclusion set**, which is the opposite polarity and the only
safe one: an include-list loses coverage by omission, silently.

**Carry this shape forward.** The row named a real file and a real seed, and that is what made
"declared in the seeds" read as verified — §4's recorded lesson, hit again, for the fourth time
in this program.

**Left open, deliberately:** the hit rate. `main` is squash-merged so its history records
releases, not the pushes inside them; the release-granularity proxy is **2 of the last 80
commits** (control: 0 of 80 with an empty exclusion set). The instrument ships with the change —
`.git/ai-dlc-suite-key.log`, one line per decision. **Measure it after a few weeks of real
pushes before anyone widens the exclusion set to chase a bigger number.**

---

#### The held-release block that produced the above, kept for its scoping and its traps

**⛔ v0.207.0 WAS BUILT AND HELD, AND THE REASON IS A LIVE CORRECTNESS DEFECT**

**Branch `perf-wait-stale-parallel`, commit `e659858`, COMMITTED BUT NOT PUSHED. `main` is
`bd0bf65` / v0.206.0.** The branch is green on everything it set out to do. It is held because
its final gate found something bigger, and shipping a perf release on top of it would bury the
finding.

**WHAT IS ALREADY DONE ON THAT BRANCH, and needs no re-doing:**

- `wait-stale-deliverable` parallelised the same way v0.206.0 did `enforcement-map-sites`:
  21 cases, one function and one process each, derived name list with a zero guard, missing
  verdict is a failure. **52s → 9s. Suite 72s → 50s.**
- Its six mutation programs collapsed into one `mutant_expr` table (case 21 re-runs all six,
  so a second copy would be a fork).
- **The exit-code contract restored in BOTH fixtures.** Routing a case through a worker
  collapsed `exit 2` (FIXTURE BROKEN) into `exit 1` (an assertion regressed). `enforcement-map-sites`
  shipped with that regression in v0.206.0; the branch fixes it there too.
- Evidence taken and green: differential identical (elapsed-second values masked — four
  messages embed them and they vary in the serial version too), five-case driver battery PASS,
  both validators exit 0, and **16 pool rounds at P16/20/24/32 measured FLAT at ~50s**, which
  is why `AI_DLC_FIXTURE_JOBS` stays 16.
- The CHANGELOG entry on the branch is written for the perf release ONLY. **It does not yet
  mention the finding below and must be rewritten before anything ships.**

**THE FINDING, and it outranks the rest of this row.**

`printf '%s' "$out" | grep -q "PATTERN"` under `set -o pipefail` **returns non-zero when the
pattern IS found.** `grep -q` exits at the first match; `printf` is still writing; it takes
EPIPE and exits non-zero; `pipefail` gives the pipeline printf's status. The `if` then takes
the wrong branch.

**Measured, not argued.** With the match near the start of a 2 MB captured output, under load:
**300 of 300 runs reported NOT-FOUND. The identical test with `grep -q PATTERN <<<"$out"`
reported found 300 of 300.** Reproduced in the real tree too: ten concurrent copies of
`enforcement-map-sites` gave **3 failures on three unrelated assertions** (I15, I33, I49, I51)
with `printf: write error: Broken pipe` on stderr.

**Scope: 34 fixtures, 250+ call sites.** In a POSITIVE assertion (`if grep -q X; then ok`) it
produces a false FAIL, which is noise. **In a NEGATIVE assertion (`if grep -q X; then bad`) it
produces a false PASS**, which is this repo's named defect class — a check that cannot fire.
**17 fixtures contain the negative form:** `apply-drift-after-write`, `apply-drift-refile`,
`apply-legacy-script-path`, `context-mode-protect`, `enforcement-map-sites`,
`layer-catalog-collision`, `layer-qualifier-grain`, `layer-readopt-gate`, `ledger-rotate`,
`mutation-red-replay`, `reconcile-emit-report`, `relabel-theirs-collision`,
`relocation-preclassify`, `retired-contract-token`, `retired-layer-contract`,
`retro-audit-scans`, `shadowed-local-validators`.

**THIS IS ALMOST CERTAINLY §9's INTERMITTENT-RED CLASS.** The two fixtures §9 records —
`layer-readopt-gate` and `apply-drift-refile` — carry **29 and 6** occurrences and sit at the
top of the count. It explains every property §9 could not: load- and concurrency-correlated
(the race widens under load), serial runs pass, the two fixtures "have nothing else in common"
except the RUNNER (they share the idiom), and the trigger varies with WHERE in the output the
match lands, which varies with what else fired. **Do not close §9 on this without proving it —
but test it first, before any other hypothesis.**

**THE NEXT SESSION'S RELEASE, and the order:**

1. **Sweep the idiom, repo-wide.** `grep -q PATTERN <<<"$var"` has no pipe and no EPIPE. Zero
   patterns in `enforcement-map-sites` are end-anchored, so the newline a here-string appends
   changes no verdict — **re-check that for every other fixture before converting it.**
   Enumerate the distinct shapes first: `grep -o "printf '[^']*' \"\$VAR\" | grep -[a-z]*"`
   returned nothing under one quoting attempt and 41 under another, so **the count depends on
   the extraction and must be taken with a control.**
2. **The proof is a whole-suite differential**: all 83 fixtures' stdout before and after must be
   identical on a passing tree, PLUS the load probe above showing the piped form fails and the
   converted form does not, PLUS a mutant in the NEGATIVE direction — a fixture whose check
   really does fire must go red after the conversion where it went green before. That last one
   is the whole point and the first two do not establish it.
3. **Then an invariant so it cannot come back.** The idiom is greppable and its subject set is
   `core/fixtures/*/run.sh` plus every shipped script that sets `pipefail`. Measure the
   false-positive set first — a pipe into `grep -q` is only unsafe when the left side can
   outlive the right, so `cmd | grep -q` where cmd is short is fine and a blanket ban would be
   the unmeasured lint `CLAUDE.md` warns about.
4. **Only then ship v0.207.0**, with the CHANGELOG rewritten so the finding leads and the perf
   work is what surfaced it.

**Operator directives from this session, both standing:**

- *One optimisation does not negate the work of doing a second — that is laziness.* Order by
  measured impact; never drop the second item.
- *An optimisation cannot be dismissed because you do not know how to solve it thoroughly,
  until iterative testing has proven you are overreaching.* Every dismissal in this session that
  was reasoned rather than measured turned out to be wrong: `wait-stale`'s timing assertions
  survived parallelisation cleanly, the pool knee was flat rather than contention-limited, and
  the cache's call-graph problem is answered by a suite-level key. **Prototype, then conclude.**

---

**The ORIGINAL next-release note follows, kept because its diagnosis instruction still holds
and its ordering is the thing v0.206.0 refuted.**

**Next release on this row, largest first:** `wait-stale-deliverable` (51.9s), then
`layer-contract-conformance` (45.6s). **Diagnose before designing** — neither has been
opened, and the fold-in of the nine-way `enforcement-map-sites` split is still available
under it at 107s.

### ⏹ SESSION BOUNDARY

### 10b. mechanize what does not need inference

**Operator-requested 2026-07-29, and the operator asked for it as its own session because of
the scope: "examine ai-dlc for opportunities to add mechanics where LLM inference isn't
needed."** Do not fold it into 10a. They share a motive — work the operator waits through —
but 10a's constraint is fidelity under a stopwatch and this row's is fidelity under a
different judge, and a row that tries to be both will trade one for the other without saying so.

**This row is not "replace the LLM."** Most of the catalog is genuinely adjudicated: a check
that reads an artifact and decides whether the reasoning in it holds cannot be a script. The
subject is narrower and it is already demonstrated — **a check whose own text states a
mechanical predicate, and which is nonetheless performed by an agent reading a paragraph at
every gate.** Three releases have now found one each, and each was found the same way: by
asking what the check's own words say it does.

- **v0.199.0** — `core-layer-immutability` said "diff the sprint range, ask the resolver per
  path" and had no program. Now `core-paths.sh --audit-diff`.
- **v0.203.0** — Check 5 said "compare status values programmatically" and carried
  `enforcer: []`. Now `sprint-status.sh check-stories`.
- **v0.204.0** — the same check as v0.199.0 decided the operator's escape hatch with a
  whole-file `grep`, next door to the script that owns the definition. Now a delegation.

**A starting measurement, already run, and every number in it is [V] as of 2026-07-29 — but
re-derive before building, because the discriminator is the hard part and it is not measured.**
Joining each check's body in `steps/gate-validation.md` to its `enforcement-map.yaml` row:

- **27 of 52 rows carry `enforcer: []`.** That is the outer bound, not the subject set — most
  of those checks are correctly adjudicated and want no script.
- **10 checks name a `scripts/ai-dlc/<validator>` in their body that their own row does not
  list as an enforcer.** Control: 12 name one that it does.
- Of those 10, **six are false positives on inspection** and they show what the discriminator
  has to separate: `verdict.sh` in Checks 2/14/15/26 is the helper that WRITES the gate
  verdict, and `wait-for-deliverable.sh` in Check 25 is the REMEDY the check offers on FAIL,
  not its predicate. **Naming a validator is not being enforced by it.**
- The remaining four are **Check 16, Check 18, Check 22 and `core-layer-immutability`** — each
  telling the lead to run a core validator while its row says nothing enforces it.
  `core-layer-immutability` is bound as of v0.204.0. **The other three are the live subject set
  and have not been examined.**

**The route, and it is the one this program keeps rediscovering.** Ask what the check's own
text says its predicate IS, then ask whether core ships a program that decides it. Do not start
from "which checks could be automated" — that is a survey, and the four rows this program spent
on subagent surveys all had to be re-derived. Start from the join above, widen the corpus to
`SKILL.md`'s rules and the step files, and measure the discriminator's false-positive set
before writing a single check.

**SHIPPED: Check 16 — `564c5d2` (#292) v0.209.0.** The join above was re-derived before building
and reproduced: **27** rows with `enforcer: []`, **10** named-but-not-enforcer pairs, control
non-empty. Two pairs the starting measurement did not list turned up (Check 17's
`stamp-story-provenance.sh` and `sync-taught-schema.sh`, both producers rather than predicates —
the same false-positive shape as `verdict.sh`).

**Check 16 was the strongest subject in the catalog and the reason is worth carrying.** Its body
published its predicate as literal machinery — a marker regex, an item regex, a backlog-status
regex, a digit-only `file:line` regex, and a density rule given as an exact shell pipeline — and
its row said nothing enforced it, at `gate_types: [universal]`. **And the program already existed**:
`check-15-bypass/run.sh` implemented all four elements inline because there was nothing to call,
and its own header said what that was worth ("It proves the FIXTURE's claim, not the ADJUDICATOR's
behaviour"). So the release was not "write a program" — it was **move a program that was already
written into the place it can ship from**, and point the fixture at it. Expect that shape again:
where a check's predicate is fully mechanical, someone has usually already coded it somewhere that
cannot run at a gate.

Mutating the relocated program immediately found **two arms of Check 16 that could not fire** —
element 4's length floor had no variant separating it from the density floor, and the density body
was being taken from the length regex's match. Neither was visible while the elements lived in a
fixture that asserted only what it already believed.

**THE ORDERING IS NOW MEASURED, not preferred.** The obvious closer for this row is an invariant
binding "a check whose body tells the lead to RUN a `scripts/ai-dlc/` validator" to "its row lists
that validator as an enforcer" — CLAUDE.md's prohibitions-need-mechanisms, and it would end the
class rather than one instance. The discriminator that separates the real subjects from the six
false positives is the imperative/exit-code form (`**Check.** Run/Invoke`, `- Run:`, a numbered
condition asserting `exits 0`) as against a mention of a producer or a remedy. **But that invariant
FAILS THE BUILD the moment it ships, because Checks 18 and 22 are still unbound.** It cannot land
before them. Do 18, then 22, then the join — and derive the discriminator's false-positive set
again at that point rather than trusting this paragraph.

**The two remaining subjects, unexamined, with what the join says about each:**

- **Check 18** — `**Check.** First run \`validate-audit-anchors.sh --entries\`… A non-zero exit
  FAILS this check CLOSED.` An imperative with an exit-code posture and no enforcer. Note its
  second mention (`--render`) is producer-mandate prose, NOT a predicate — one check contributes
  both a subject and a false positive, which is why the discriminator has to be per-mention.
  Its per-category verdicts come from consumer-supplied audit scripts, so the mechanizable part
  is the `--entries` gate and the prior-sprint SHA resolution, not the whole check.
- **Check 22** — numbered clearing condition 3 is `validate-escalation-resolution.sh … exits 0`,
  the same invocation Check 2a makes, and **Check 2a's row binds that validator while Check 22's
  does not**. The comparison against `aiDlcRoles` and the `role_file_readable` arm are mechanical;
  clearing condition 4 (the entry states a remediation and names its artifact) is genuinely
  adjudicated. Expect a partial bind, not a whole-check one.

**Two constraints.**

- **`adjudication: llm` is not the thing to flip.** Check 2 and Check 5 are the precedent: a
  numbered check can carry a mechanical enforcer AND stay `llm`, because the script decides the
  comparison and the adjudicator applies the carve-outs on top. `adjudication == "llm"` is also
  the gate-adjudicator escalation predicate, so flipping it changes ROUTING for a reason a
  mechanization release does not have. Bind the enforcer; leave the tier alone unless the
  release's own subject is the tier.
- **A mechanized check must report its COUNTS, and "compared nothing" must not be a pass.**
  v0.203.0's whole vacuity floor came from three consumer implementations that each went
  green having compared zero things. A script that replaces an agent inherits the agent's
  duty to say what it looked at.

### ⏹ SESSION BOUNDARY

### 11. ADJUDICATED tier + disposition register

**Why.** ERROR and WARN are the only severities, so a clause needing judgement can only be a WARN,
and a WARN reprints every pull forever. That is the friction: `EXTENSION-HOOK-DRIFT` on 31 of 76
pulls, adjudication prose 3.8 kB → 8.3 kB, **6 of 9 blocker adjudications re-litigating a file
another already covered** — `ai-dlc-setup/SKILL.md` three times in five hours, the third retracting
the first two **[R]**.

**Do.** Third severity: candidate set mechanized, verdict human, recorded once per
`(entry, clause, body-digest)`; **blocks while unrecorded**, silent once recorded, **re-fires when
the body changes** because the digest moves. Ritual name, used verbatim in every such clause row:
*the layer conformance adjudication*.

Single-homed register keyed per **subject**, never per run — the 3×-in-5-hours failure is three
files each opening a new heading for one subject. Reuse the ledger's entry shape so
`ledger-reverify.sh` and `ledger-rotate.sh` work on it unchanged, and add a
`REGISTER-CONTRADICTION` arm to `hard-blockers.sh`: two dispositions under one key where the later
lacks `supersedes:` and a `reason:`. Retraction stays available; it just has to be declared.

**The mutant's assertion is a triple** — seeded entry with no record → non-zero; record added → 0;
body mutated one byte → non-zero again. A path-keyed register passes (i) and (ii) and fails (iii),
which is a permanent exemption wearing an adjudication's clothes.

**Clauses to move here** (measured, in descending row count): the restriction clause — a keyword
predicate is unshippable (**FP 16/33 with 0 TPs** in one measurement, **9 files/14 lines with 5
irreducible FPs** in another; **the two disagree, so re-measure before writing it**) — then
`EXTENSION-HOOK-DRIFT`, retirement duty, and `OVERRIDE-DELEGATES-INTO-SHADOW`.

---

## 8. Final step — regenerate the pull prompt

Revision 2 lives at `docs/reviews/graph-pull-0.183.0-operator-prompt.md`. **Do not reuse it.**
Write a revision 3 for `0.183.0 → <final main sha>`, and carry these forward — each was a defect in
an earlier revision, found by a real run:

- **Pin the target sha, and create a read-only worktree of the distribution at it.** Run the
  classifiers from *that* engine, not the consumer's — the consumer's is the OLD version and cannot
  emit statuses added by the pull. Revision 1 quoted a tally measured with the new engine while
  telling the agent to run the old one.
- **Note the two scripts' differing arg orders:** `layer-drift.sh <dist> <base> <theirs> <consumer>`
  but `ledger-reverify.sh <dist> <base> <consumer> <theirs>`.
- **Read the label, not the exit status,** on the `cmp` validator comparison — the two branches
  assert opposite things before and after apply. Revision 1's success-branch label was
  self-contradictory.
- **Pre-flight the untracked 314-byte `.git/hooks/pre-push` shim.** graph is armed by it because
  `core.hooksPath` would disable the gitleaks pre-commit; **nothing in core asserts it**, so if it
  is missing every gate in the pull is silently disarmed **[V]**.
- **Recompute every expected tally against the final sha** and state them as falsifiable numbers
  with stop conditions. Also state which zeros are *structurally impossible* rather than deviations
  — post-apply, base equals theirs, so hook-drift and ~8 of 13 statuses cannot fire at all, and a
  real run mistook that for evidence the re-reads had been disposed.
- **Instruct the operator to update graph's 3 `NAMED-ABSORBED` annotations** to the renamed token.
- **Expect exactly FIVE new `W5` warnings** from `validate-layer-entries.sh` after apply — checks
  33/34/35 in `extensions/checks/gate-validation-domain.md` and rules 31/32 in
  `extensions/steps-domain/SKILL-domain.md`. Measured at `170ff9d8c` against a baseline of
  `0 error(s), 0 warning(s)`, so a SIXTH warning or a different subject means the tree moved and
  the prompt's tally is stale, not that the check misfired. State it as a falsifiable number with
  that stop condition. **Renumbering them is a consumer decision and NOT part of the pull** — each
  one rewrites an integer already written into gate logs and wants a crosswalk row first.
- **Expect ZERO `EXTENSION-ANCHOR-DRIFT` / `EXTENSION-ANCHOR-MISSING` rows**, and say why in the
  prompt: no graph entry declares `extends:`, so both statuses are **structurally unable to fire**
  rather than merely absent. This is the §8 trap already recorded one release down — a real run
  mistook a structurally-impossible zero for evidence that work had been disposed. State it with
  the stop condition: any row carrying either status means an entry gained an `extends:` key, not
  that the classifier misfired.
- **`EXTENSION-HOOK-DRIFT`'s message text changed** in v0.196.0 (it no longer claims extensions
  have no section anchor). A prompt that greps for the old wording to count re-read rows will
  find zero. Match the STATUS token, never the sentence.
- **`PC-S296` should now close** as `ADOPTED UPSTREAM (v0.184.0)`: the operator's SPLIT
  determination drove that fix, and it closes the case that kept the entry open.
- **`install.sh` needs a `_bmad/` directory present** in the target or it aborts — relevant to any
  install-into-empty-tree verification the prompt asks for **[V]**.
- **RETIRE `overrides/steps__gate-validation__check-25-universal-core.md`, as a REQUIRED step of the
  pull, not a suggestion.** This is the one consumer edit in the program that a release depends on
  to deliver anything, and v0.197.0 exists to make it possible. Two edits:
  1. `git rm` the override.
  2. Add `gate_types: implementation` to the frontmatter of
     `extensions/checks/gate-validation-domain.md`.

  **Expected after, measured on a `cmp -s`-guarded copy at `170ff9d8c` with the shipping code:**
  `manifest source: core`, `extension gate_types: 34->implementation`,
  `MISSING none`, `ORPHAN none`, exit 1 **only** for the UNLOADABLE rows below. **Stop condition:**
  any MISSING or ORPHAN row means the tree moved and this instruction is stale — do NOT re-author
  the override to make it pass.

  **Why it is required and not optional.** That override is 133 lines carrying the whole section's
  `base_sha` drift to add one integer to one row, and its own first line — *"Identical to core, with
  one change"* — is FALSE: it drops core's gate-type enum (`planning · story · implementation ·
  sprint-review · retro`) and the deployment/schema paragraph. The consumer has been running gates
  against a rendered document with no gate-type enum in it. Retiring restores both.
- **Expect exactly FOUR `UNLOADABLE` rows** from `validate-gate-manifest.sh`: `19b`, `2s`, `33`,
  `35`. Measured at `170ff9d8c` against a baseline of `MISSING none / ORPHAN none / PASS`, FP set
  empty (controls `34` and `2a` both come back anchored and claimed). Each is a consumer check
  defined as a heading that has never run at any gate. **Stop condition:** a fifth row, or a
  different id, means the tree moved and the tally is stale — not that the check misfired.
  `33` is a retired tombstone and its remedy is deletion, not declaration; the other three want an
  anchor plus a `gate_types:` on their entry. **Disposing them is a consumer decision per check and
  is NOT part of the pull** — the pull's duty is to surface them.
- **REQUIRED, and it WEDGES THE PUSH if skipped: register `scripts/tests/**` as a party-mode
  home before the pull's first push.** v0.198.0 adds a `--strays` step to the consumer pre-push,
  and on graph at `170ff9d8c` the core homes alone leave **5 findings**, all under
  `scripts/tests/**` — a consumer test-harness tree carrying sample blocks inline. Measured with
  the shipping code in a worktree at that sha. One edit closes all five: add
  `"party_mode_homes": ["scripts/tests/**"]` to
  `.claude/skills/ai-dlc/extensions/known-skills.json` (which already exists there, carrying
  `known_skills`). **Expected after: `--strays: PASS`, 889 file(s) carried the envelope. Stop
  condition:** a SIXTH finding, or one outside `scripts/tests/**`, means the tree moved and this
  tally is stale — do NOT widen the homes to make it pass; a home added because it currently
  reports a finding is an exemption wearing a performance argument.
- **graph's `scripts/check-mutation-red-anchor.sh` is fully absorbed by v0.200.0's
  `scripts/ai-dlc/validate-mutation-red.sh`, and retiring it is a consumer decision that is
  NOT part of the pull** — the pull's duty is to deliver the core script and say the two
  overlap. Note for whoever does retire it: Check 35 in
  `extensions/checks/gate-validation-domain.md` names the old path in its **Check** clause and
  its **Discriminating fixture** clause, and `scripts/tests/test-s291-3-check35-mutation-red.sh`
  resolves it as `$HERE/../check-mutation-red-anchor.sh`. That three-case test **passes
  unchanged against the core script** (measured, with an always-exit-0 stub as the control that
  it still discriminates), so the retirement is a path swap, not a re-authoring. The core
  script splits the old exit 1 into 1 (the test survived a real mutation) and 2 (nothing was
  mutated), so a wrapper or a caller that treats any non-zero as the finding would newly report
  unevaluable claims as failures — Check 35's prose grades the claim, so read the code.
- **graph's `scripts/scan-stray-provenance.sh` loses its stray arm to core, and its
  `--fixture-provenance` mode does NOT move.** Retiring the stray arm is a consumer decision and
  is NOT part of the pull — the pull's duty is to deliver `--strays` and say the two now overlap.
  Note for whoever does retire it: graph wires the old scanner nowhere in `.pre-commit-config.yaml`,
  `ci-local.sh` or `.githooks/`, so nothing depends on the old entry point.
- **REQUIRED, and it WEDGES THE PUSH if skipped: declare every fixture directory before the
  pull's first push.** v0.202.0 adds a `fixture drivability` step to the consumer pre-push,
  and on graph at `170ff9d8c` it reports **28 findings** — measured with the shipping code.
  **Expected: `fixture directories : 103`, `driven (run.sh) : 73`, `declared undrivable : 2`,
  `undeclared : 28`. Stop condition:** a 29th finding, a different name, or a `declared
  undrivable` other than 2 means the tree moved and this tally is stale. **The 2 are core's
  own `check-h1-recursion` and `check-manifest-bypass`** — if either appears in the findings,
  the exemption marker diverged and that is a CORE defect, not a consumer one; stop and say so.

  Each of the 28 wants one of two one-line declarations, and **which one is a per-directory
  judgement the consumer must make**:

  1. a `run.sh` — two lines delegating to the harness that already drives it, which also puts
     that harness into the push suite instead of a hand-maintained `ci-local.sh` trigger; or
  2. a `README.md` carrying ``No `run.sh`, deliberately`` and the reason, for a fixture no
     script can drive — evidence an LLM reads at a gate.

  **THE HAZARD, and it is the whole reason this is spelled out.** Route 2 over a fixture that
  HAS a driver is a false statement the script cannot detect and will accept. Under push
  pressure it is also the faster route for all 28, which would convert a real finding into 28
  silent exemptions and leave the consumer exactly where it started. Do not batch-apply it.

  **A starting classification, and it is [R] — a CITATION, not a proof.** Derived by
  `git grep -lF "fixtures/<name>"` over graph restricted to executables; a script naming a
  fixture is not necessarily a script that drives it, and §7.6's lesson is that a derivation
  is not sound merely because its inputs are readable. **Confirm each one before acting on it.**

  - **14 cite an executable driver** (route 1 likely): `check-cycle-types-bypass`,
    `check-ff-escalation`, `check-il-oracle-presence`, `check-substrate-audit`,
    `cycle-commits`, `detectors`, `exclusion-importer`, `live-contract-probe`, `live-shape`,
    `phase-sequencing`, `pipe-exit-mask`, `provenance-in-non-retro`, `retro-replay`,
    `rule-ref-reconcile`.
  - **14 cite none** (route 2 likely; most are evidence for LLM-read `check-*` gate checks):
    `boundary`, `check-7-arch-content`, `check-18-runtime-constraints`, `check-19-disposition`,
    `check-20-doc-check`, `check-21-section0`, `check-26-deployed-ranges`,
    `check-27-config-integrity`, `check-30-orphaned-fn`, `check-31-cited-sha`,
    `check-35-mutation-red-reachability`, `check-a52-sprint-pr-merge`, `compute`, `retro-audit`.
    Note `boundary` cites `scripts/regen-boundary-fixtures.sh`, which REGENERATES it rather
    than driving it — that is why it is on this side and it is the one most worth re-reading.
- **Check 5 gains an enforcer, and on graph it is GREEN today — say so with its stop condition.**
  v0.203.0 binds `scripts/ai-dlc/sprint-status.sh check-stories` to Check 5. Measured at
  `170ff9d8c` with the shipping code: **`PASS — 2 comparison(s) over 2 entries, 0 finding(s)`**,
  sprint 299, both canonical copies. **Stop condition:** any finding, or a comparison count other
  than 2, means the tree moved — do not read a finding as the check misfiring. Exit **4** means it
  compared nothing and is never a pass; at an implementation gate that IS Check 5's non-vacuity
  failure. graph carries **one live drift the check will report the moment story-290-1 is in a
  live sprint's mapping**: that story file's frontmatter still reads `status: review` while the
  sprint-290 envelope closed it done (the `fix(s290)` commit `0ed93f50e` rewrote four yaml files
  and not the story file). Fixing it is a **consumer decision and NOT part of the pull**.
  Note for whoever retires the consumer's own versions: `validate-story-status-consistency.sh`
  needs `yq` and does a three-way join core does not do (it also reads the planning copy's entries
  against the impl copy's); core's version covers the status join across both copies and reports
  its counts. `generate-sprint-status.py` keeps everything else — its `--write` sync arm is **not**
  absorbed and core does not propose to absorb it.
- **graph's `scripts/retro-replay-harness.sh` and its sibling `scripts/tests/test-*.sh` are
  NOT absorbed, and arm 8 did not propose to absorb them** — the arm's "registrable entry
  point" premise was refuted (§7.10). They stay where they are; what changes is that a
  `run.sh` delegating to them is now the sanctioned way to get them into the push suite.
- **`Check AP` and `Check VH` are ALSO unloadable and will NOT appear** in that tally — the heading
  grammar is numeric. State it in the prompt with the stop condition, because this is the §8 trap
  already recorded twice: a structurally-impossible zero read as evidence that work had been
  disposed. Their absence from the UNLOADABLE line is not evidence they load.

---

## 9. Known-open, deliberately out of scope

- **`enforcement-map.yaml` is copied by `install.sh` but appears nowhere in `core-manifest.md`** — an
  unmanifested core file, so consumer edits to it are not drift-scanned **[V]**. Pre-existing; file
  it rather than folding it into a release.
- **graph's `ci-local.sh` has two pre-existing failures on main** — shellcheck on four `scripts/*.sh`
  and `server-fixture-manifest` — unrelated to this program **[R, operator-reported]**.
- **A retired STATUS token in a consumer layer file has no detector** — opened by v0.186.0's rename.
  `retired-tokens.sh` matches only `$VAR/path` in the CLASSIFY bucket; `retired-layer-contract.sh`
  matches labelled directives and `{token}` placeholders, derived from `setup-sites.md`'s `rulebook:`
  globs, which exclude `ai-dlc-update/SKILL.md`. Covering it means widening that subject set, whose
  false-positive set across every shape it already extracts is **unmeasured** — measure first. I39
  covers the core side of any status rename; this is the consumer side only.
- **`contract_version` and `conforms_to` have no reader anywhere in the tree** — opened by
  v0.193.0. The retro-application rule the contract's header states (an entry declaring
  `conforms_to: N` is held only to clauses with `since <= N`) is enforced by nothing, and no
  consumer entry declares `conforms_to:` today. I41/I42 keep the declaration internally coherent
  so it cannot drift further; building the reader is a separate change and probably belongs with
  row 11, whose register is the first thing that would need it.
- **`layer-drift.sh`'s status list in `ai-dlc-update/SKILL.md` is prose nothing binds** — it silently
  lagged one status behind from v0.187.0 until v0.192.0 documented it. I36 joins statuses to the
  layer CONTRACT, not to this reader-facing list. The fix is I39's shape one detector over: derive
  the emitted set from `layer-drift.sh` and join it to the step-3c span. **The FP set is unmeasured**
  — the same grammar over the whole file matched 20 tokens when I39 tried it, 15 of them other
  detectors', so the span must be bounded first. Measure before writing it.
- **`core/fixtures/layer-readopt-gate/` is intermittently red under the 8-way pre-push suite** —
  opened by v0.194.0's push, where it was the only FAIL in an otherwise green run. It then passed
  **10/10 serially** and green in three subsequent full-suite runs, including a direct invocation
  of `.githooks/pre-push` (the shipping code) which exited **0**. It drives `layer-drift.sh`,
  `readopt-override.sh`, `register-drift.sh` and `unregistered-drift.sh`, none of which v0.194.0
  touched. A suite that is red once in N runs trains the operator to re-push rather than read, so
  this wants finding — but it is a fixture-hermeticity bug, not a core defect, and it should not
  displace a program row. Reproduce under `xargs -P8` before changing anything.
  **REPRODUCED 2026-07-28, and it is NOT caused by any release in this program.** It failed
  v0.196.0's pre-push too, which mattered because unlike v0.194.0 that release DID modify
  `layer-drift.sh` — so the v0.194.0 attribution could not simply be reused. Settled three ways:
  (i) eight concurrent copies of the fixture run against **unmodified `main` at `07f8ab8`** gave
  **3 of 8 failing**, on a commit predating the branch; (ii) the fixture seeds **zero** `extends:`
  keys and asserts on **zero** `EXTENSION-` statuses (its one such mention is a comment), so
  v0.196.0's additions are structurally unreachable inside it; (iii) on the branch, **0 of 12**
  serially, **0 of 10** further serial runs, and **0 of 10** full 8-way suite rounds. The failure
  is **cold-start correlated**: it hit on the first concurrent round after a fresh touch of the
  worktree and then did not recur across **24** further concurrent copies or those 10 suite
  rounds, which is why "passed 10/10 serially" was never going to find it. Whoever picks this up should force
  the cold condition (fresh checkout or dropped FS cache) rather than repeat-running a warm tree.
  Note for any future release that trips it: a re-push is the correct response ONLY after showing
  the release cannot reach the fixture; `--no-verify` is not.
  **v0.203.0 makes this a CLASS, not a file.** Its push went red once on
  `core/fixtures/apply-drift-refile/` — a second fixture, same shape. Cleared the same way and the
  route is worth reusing verbatim: the fixture passed standalone, the shipping `.githooks/pre-push`
  exited **0** on the same branch, a grep for every file the release touched found nothing in the
  fixture (with a control proving the grep matched), and unmodified `main` gave 8/8 concurrent
  copies green plus a green full 8-way suite. Whoever picks this up should stop treating it as
  `layer-readopt-gate`'s bug: the shared factor is the RUNNER, and the two fixtures have nothing
  else in common.
- **The consumer machinery home has no INHABITANTS on the reference consumer** — `scripts/ai-dlc-local/`
  does not exist in graph, so `warn-shadowed-local-validators.sh`'s `[ -d "$LOCAL_DIR" ] || exit 0`
  makes it a no-op there today. That is correct behaviour for an empty home, not a defect, and
  v0.194.0 deliberately did not create the directory: core never writes it (I44), and a home core
  materialised would be core claiming a path it promises never to touch. It gains inhabitants when
  a consumer files something there, which is now a consumer decision with nothing blocking it.
- **The crosswalk table's completeness has no clause, deliberately** — opened by v0.195.0. Row 7
  specified one requiring "an entry for every number the consumer has ever used". Core cannot see
  which numbers a consumer has written into evidence (gate logs, retros, escalations, most of them
  rotated into archives), so the clause has no evaluable predicate and I37 would reject it.
  `extensions/README.md` states the duty and states plainly that core does not check it. Do not
  re-open this as a clause; if it is ever mechanized it will be from the CONSUMER side.
- **Tightening `LC-N5` to ERROR: the prerequisite is now SHIPPED, the tightening is not.** Opened
  by v0.195.0, half-closed by v0.196.0. W5 tells a deliberate qualifier from a squatter only by the
  fact that core already defines the number, which works today and stops working the moment a
  consumer wants to qualify a section core has not written yet. `kind: qualifier` + `extends:` is
  the declared grain that distinguishes "I mean core's 13" from "I took 13", and it exists now.
  **What is still owed is a measurement, not code:** which of the reference consumer's entries
  would actually declare `kind: qualifier`, derived per hooked file and per frontmatter flag. Row
  7's recorded lesson is that its counts were of the WRONG SET, and the same trap is live here —
  "the four rules that qualify core numbers" is a subagent-era figure that v0.196.0 did not
  re-derive. Do not tighten LC-N5 on the strength of the grain existing.
- **`EXTENSION-HOOK-DRIFT` at "31 of 76 pulls" is still [R]** — quoted in rows 8 and 11, and
  v0.196.0 did NOT verify it. It needs graph's pull history, which core cannot see. The
  file-vs-anchor grain numbers v0.196.0 measured (1421 exact, 133 expected) are independent of it
  and do not confirm it. Row 11 leans on the same figure for `EXTENSION-HOOK-DRIFT`'s place in the
  clause-migration order — re-derive before using it to rank anything.
- **`scan-stray-provenance.sh --fixture-provenance` is NOT absorbed, deliberately** — opened by
  v0.198.0. That mode lints live-evidence artifacts for a generating-run citation
  (`captured_utc`, `raw_transcript:`, `Source:`). Its subject is the consumer's own captured
  EXPLAIN/SSM evidence and its marker vocabulary is a consumer on-disk convention core does not
  define. The consumer retires only the stray arm; the script stays for this one.
- **The stray scan does NOT exempt installed core files** — opened by v0.198.0.
  `.claude/skills/**` is scanned like anything else, and the one legitimate party-mode block
  there (`steps/retro.md`'s rendered example) is exempt through the generated-region carve-out
  rather than a path exclusion. That is deliberate: a blanket skills exclusion would hide a real
  stray in an installed core file, which would be a core defect and the one nobody could see.
  **The consequence is that I48 is load-bearing at consumer scale** — if the region slug ever
  forks, every consumer's next push goes red on a core file they did not write.
- **`--audit-diff`'s citation arm is still not bound to the touch it clears** — opened by
  v0.204.0, and deliberately, because v0.199.0 stated the deferral in its own output ("whether
  the citation covers these touches is the adjudicator's call"). v0.204.0 closed the half that
  was not deferred — a citation that is not a citation — and left this one. **The measurement
  that makes it a real question:** `pending.md` accumulates, so on the reference consumer three
  legacy citations from S298/S299 clear every future in-place core edit, and v0.199.0's own
  measurement records **4 of 60 ranges cleared by the citation arm** — a `fix(s299-1)` commit
  touching `.claude/hooks/ai-dlc-dispatch-guard.sh`, `ai-dlc-setup/SKILL.md`,
  `ai-dlc-update/SKILL.md` and `reconcile/apply.sh`, with **zero** entries in `pending.md`
  naming any of the four paths (control: 29 hits for "escalation" from the same corpus).
  Binding it needs a predicate core can derive — the entry naming the path, or the commit
  naming the tag — and the FP set for either is unmeasured because the reference consumer has
  no *authorized* in-place core edit to measure against. **Measure the predicate before writing
  it; do not re-open the presence-only deferral itself, which was a decision.**
- **Three more checks name a validator their `enforcement-map.yaml` row does not bind** —
  Checks **16**, **18** and **22**, found by the join v0.204.0 ran while binding
  `core-layer-immutability`. Not folded into that release: each is its own question about its
  own check. **This is now row 10b's live subject set**, and its section carries the full join
  and its six measured false positives.
- **graph's override-body finding** (§7 release 2's live instance) is a *consumer* decision: narrow
  the `shadows:` or extend the body. Recorded in graph's reconcile log, deferred to a sprint. Core
  ships the detector; core does not fix graph's override.
- **An alphabetic check id is outside GM1's subject set** — opened by v0.197.0. `CHECK_HEAD_RE` is
  numeric (`[0-9]+[a-z-]*\.`), so `Check AP` (attribution provenance, "every gate") and `Check VH`
  (vacuous-validator honesty, "story-validation gate") are invisible to it. **Both are live, both
  carry a real Scope line, and both are unloadable today** — measured with the same probe that
  found the four GM1 reports. Widening the grammar is bound to
  `reconcile/relabel-extension-checks.sh` by **I34**, and a detector that finds a heading the
  rewriter cannot rewrite reports a defect with no remedy — so widening means changing the
  relabeller in the same release, and its false-positive set across every heading it already
  rewrites is unmeasured. Measure before writing it. **Do not read GM1's silence on AP/VH as
  evidence they are fine; they are structurally outside what it can see.**
- **An override asserting IDENTITY rather than survival has no detector** — opened by v0.197.0.
  v0.187.0's `OVERRIDE-ASSERTS-SHADOW-SURVIVES` requires a scope phrase whose noun is the shadowed
  grain (`rest of the section`, `surrounding check`). graph's
  `steps__gate-validation__check-25-universal-core.md` opens with *"Identical to core, with **one
  change**: `34` joins the `implementation` row"* — no scope phrase, and the claim is **false**: it
  drops twelve lines of core prose including the canonical gate-type enum, and did so at authoring
  (both paragraphs were already in core at its own `base_sha: a705e55`, verified with `git show`).
  A predicate for the identity shape is a fresh measurement across the 13 overrides, and the
  survival-claim predicate's own header records that a bare vocabulary scan matched 5 with only 2
  real. v0.197.0 removes the REASON that override exists rather than detecting its claim; retiring
  it is the fix, and that is now a pinned step in §8, not a consumer option.
