# graph pull → ai-dlc v0.213.0 — operator handoff, revision 3

**Point a fresh Claude Code session at this file in `/Users/n8/git/graph`.** It drives the pull to
done across multiple sessions.

**Revision 3, and it is a different KIND of document from revisions 1 and 2.** Those were
single-session copy/paste prompts with four report-back pauses. This one is a multi-session handoff
with a progress ledger, because the pull's judgement load grew from 3 required fixes to **45
discrete decisions** across three separate gates that wedge the push if skipped. A 45-judgement
single-session prompt is how you get the failure this file's own §3 warns about: under context
pressure the fast route through a per-item judgement is to batch-apply the permissive option, which
converts a real finding into a silent exemption and leaves the consumer where it started.

Revisions 1 and 2 live at `docs/reviews/graph-pull-0.183.0-operator-prompt.md`. **Do not reuse
them** — they pull to 0.183.0, which is already banked.

---

## 0. How to use this file, and WHICH REPO YOU ARE IN

1. Read §1–§5 in full. They are short and every line is load-bearing.
2. Read the **Progress Ledger** (§5) to find the next unticked row.
3. Read that row's section in §6, execute it, tick the ledger **with a sha or a count** as the last
   act. A fresh session's only way to know where it is.
4. When you reach a **`⏹ SESSION BOUNDARY`**, stop and tell the operator to start a fresh session
   pointed back here. Do not push past one.

**TWO REPOS, TWO SESSIONS, AND THE SPLIT IS DELIBERATE.** Every row in §5 names its repo. The short
version:

| | **graph session** (`/Users/n8/git/graph`) | **ai-dlc session** (`/Users/n8/git/ai-dlc`) |
|---|---|---|
| Runs | the classifiers, `apply.sh`, the 28 declarations, the 17 adjudications, graph's own push | nothing against graph |
| May edit | graph's tree | core only |
| Job at a boundary | report the tally it measured, verbatim | decide whether a deviation is a **core defect** or a consumer decision |

**Why the second session exists, and it is not ceremony.** When the graph session hits a tally that
does not match, it is the *worst-placed* agent to judge whether the check misfired: it has the
consumer's context loaded, it is mid-push, and the cheap resolution is always "widen the thing that
is complaining." §3 names that failure mode twice. An ai-dlc session with the distribution loaded is
what refuses it. **A core defect found during this pull is fixed in ai-dlc and re-delivered — never
patched in graph.**

**Everything in §6 is reference for the row you are on. §5 says what to do next; nothing else in
this file does.** Rejected options and corrected premises are recorded so they are not
re-litigated — they are not competing instructions.

**Fidelity tags.** **[V]** = verified with a control during the 2026-07-29 measurement pass, named
in §4. **[R]** = reported, not independently verified — **treat as a hypothesis.** Two [R] premises
were falsified during the program that produced this pull.

---

## 1. State at handoff

| | |
|---|---|
| **Distribution target** | `3490997`, VERSION **0.213.0**. **PIN THIS SHA.** |
| **Consumer** | `graph` at `170ff9d8c`, stamped **0.183.0 @ 46aa98a** |
| **Span** | `46aa98a → 3490997` — **25 releases**, 0.184.0 through 0.213.0 |
| **Base for every classifier** | `46aa98a` (the stamp), NOT `0.183.0`'s tag and NOT `170ff9d8c` |
| **Judgement load** | **17** adjudications + **28** fixture declarations = 45 per-item decisions, plus 4 mechanical edits |
| **Gates that WEDGE the push if skipped** | three: party-mode home, fixture drivability, the 17 adjudications |
| Program that produced this span | `docs/analysis/layer-contract-program-handoff.md` rows 1–11, all closed |

**graph has been frozen for this program** — no sprint has run in it, which is why `170ff9d8c` is
still the tip and why the tallies below are measurable in advance at all. **The freeze ends when
this pull merges.**

---

## 2. Locked decisions — do not re-litigate

| Decision | Consequence for you |
|---|---|
| **One branch, machinery + rulebook together** | Rev 1's run proved splitting them wedges: the skill's own self-update installs a validator that blocks its own push. Precedent: PR #829. |
| **Consumer checks/rules ≥900; core 1..899** | The 5 `W5` warnings are the consumer's squatters. **Renumbering is NOT part of this pull** — each rewrite touches an integer already in gate logs and wants a crosswalk row first. Verify the tally, leave them. |
| **`overrides/steps__gate-validation__check-25-universal-core.md` is RETIRED, as a required step** | Not optional. v0.197.0 exists to make it possible, and the override's own first line is false — it drops core's gate-type enum. |
| **17 adjudications are RECORDED, not waived** | `level: ADJUDICATED` blocks `apply` while unrecorded. There is no skip flag, deliberately. |
| **The 28 fixture declarations are a PER-DIRECTORY judgement** | Route 2 (`README.md`) over a fixture that HAS a driver is a false statement the script cannot detect and will accept. Do not batch-apply it. |
| **A core defect is fixed in ai-dlc, never in graph** | Report it at the boundary and stop. |

---

## 3. Non-negotiable discipline

**A zero is not a finding.** Every absence-shaped claim carries a control in the same invocation
that returns non-zero. **This rule earned its place five times in one afternoon during this pull's
own measurement pass** — see §4. Every one of those was a wrong invocation that answered "clean."

**Never read `$?` after a pipe.** It is the pipe's last stage. Redirect to a file, then check.

**`printf '%s' "$VAR" | grep -q` inverts under `pipefail`.** Once the value clears the pipe buffer
the pipeline reports the writer's status, so a MATCH answers non-zero. Read the value as a
here-string: `grep -q ... <<<"$VAR"`.

**Unbraced `$ref:path` in zsh.** `:c`/`:t` are history modifiers and eat the next character. Always
`"${r}:core/…"`. graph's operator has already hit this while authoring a receipt.

**A widened exemption is not a fix.** If a gate reports a finding, the remedy is the finding's
subject — never the gate's scope. A home added because it currently reports a finding is an
exemption wearing a performance argument. Both wedging gates in this pull have a permissive route
that silences them, and neither is correct.

**Structurally-impossible zeros are not evidence of work done.** Post-apply, `base` equals `theirs`,
so hook-drift and roughly 8 of 13 statuses **cannot fire at all**. A real run of an earlier revision
mistook that for evidence the re-reads had been disposed. Each row in §6 states which of its zeros
are impossible rather than clean.

**Report tallies verbatim at a boundary.** Not "as expected" — the number, and the stop condition it
was measured against.

---

## 4. Premises already falsified, and the five false probes

**All six tallies in §6 were re-derived on 2026-07-29 against `graph 170ff9d8c` with the shipping
code from a pinned worktree at `3490997` [V].** graph had not moved; the *distribution* had, by 8
releases, so every tally that joins the two trees was stale even though the consumer was not.

**Two of the previous revision's tallies were wrong, and five probes answered falsely before the
right invocation. Expect to hit these — they are properties of the tools, not mistakes you can
avoid by being careful:**

| # | Probe | What went wrong | The right invocation |
|---|---|---|---|
| 1 | `validate-gate-manifest.sh <root>` | Wants a **FILE**, not a repo root. Exited **2**; a grep for `UNLOADABLE` read **0** | `validate-gate-manifest.sh <consumer>/.claude/skills/ai-dlc/steps/gate-validation.md` |
| 2 | `validate-fixture-drivability.sh <root>` | Wants `--dir`. Exited **2**, read as no findings | `validate-fixture-drivability.sh --dir tests/fixtures`, run **from graph's root** |
| 3 | `validate-provenance-block.sh --strays <root>` | Takes **paths**, and derives the project root from **its own script location** — your cwd is ignored. Scanning with the script outside graph reported **397** findings against a true **5** | Run the copy that lives at `scripts/ai-dlc/` **inside graph** |
| 4 | `--strays` against graph's installed copy | graph's 0.183.0 copy contains the string `strays` **zero** times — **the mode arrives WITH the pull.** Nothing can measure it pre-apply except a staged copy | Stage the shipping script into a **copy** of graph, never graph itself |
| 5 | `grep 'W5'` on the linter's output | The token `W5` **never appears in the message text**. 5 warnings existed; the grep said 0 | Match `OUT OF BAND`, or count the `WARN` lines |

**And one tally moved:** the envelope-carrier count after the party-mode fix is **893**, not the
889 recorded. The finding count (**5**) and their subject (`scripts/tests/**`) are unchanged.

**The lesson to carry through every row: when a probe answers "clean," check that it ran.** Four of
the five above are indistinguishable from a passing check if you only read the tally.

---

## 5. Progress Ledger

**The next unticked row is the next thing to do. Do them in order.** Tick as the last act of each
row, with a sha or the count you measured. `—` = not started.

| # | Row | Repo | Status |
|---|---|---|---|
| 1 | Pre-flight: the pre-push shim, `_bmad/`, a clean tree, pin the engine | graph | — |
| 2 | Classify only. Report all six tallies. **Write nothing.** | graph | — |
| ⏹ | **SESSION BOUNDARY** — the ai-dlc session adjudicates every deviation before anything is written | | |
| 3 | The two mechanical pre-apply edits: party-mode home, retire `check-25-universal-core` | graph | — |
| 4 | The **28** fixture declarations — one per-directory judgement each | graph | — |
| ⏹ | **SESSION BOUNDARY** — 28 judgements is a session's worth on its own | | |
| 5 | The **17** adjudications — record a verdict per row | graph | — |
| ⏹ | **SESSION BOUNDARY** | | |
| 6 | `apply` on one branch, machinery + rulebook | graph | — |
| 7 | Post-apply verification, including the one probe that MUST fail | graph | — |
| ⏹ | **SESSION BOUNDARY** | | |
| 8 | The push-candidate ledger: close `PC-S296`, update the 3 renamed tokens | graph | — |
| 9 | Commit, push, PR, merge. Then unfreeze. | graph | — |

**Rows 4 and 5 are separated on purpose.** Both are per-item judgement at scale and neither
survives sharing a context with the other. Row 5 also cannot be done before row 6's `apply` is
*attempted* — see its section for why that is not a contradiction.

### Out of scope for this pull — surface, do not fix

Each is a **consumer decision** the pull's duty is only to report. Filing one is fine; doing it
inside this pull is not.

- **Renumbering the 5 `W5` squatters** (checks 33/34/35, rules 31/32) — wants a crosswalk row first.
- **Disposing the 4 `UNLOADABLE` checks** (`19b`, `2s`, `33`, `35`) — `33` is a retired tombstone
  whose remedy is deletion; the other three want an anchor plus `gate_types:`.
- **`story-290-1`'s stale `status: review`** — one live Check 5 drift, dormant until that story is
  in a live sprint's mapping.
- **Retiring `scripts/check-mutation-red-anchor.sh`** — fully absorbed by core's
  `validate-mutation-red.sh`, but the swap touches Check 35's prose and a test's path.
- **Retiring `scan-stray-provenance.sh`'s stray arm** — absorbed; its `--fixture-provenance` mode is
  **not** and does not move.
- **graph's override-body finding** (`steps__retro__ci-gates-enforcement-surface.md`) — already
  deferred to a sprint in graph's reconcile log.

---

## 6. Rows

### Row 1 — pre-flight. In `graph`.

**Nothing here writes to graph.** Four things, and the first one is the reason this row exists at all.

**1a. The pre-push shim. If it is missing, every gate in this pull is silently disarmed.**

```bash
ls -l .git/hooks/pre-push          # expect: present, 314 bytes
git config core.hooksPath          # expect: NO output (unset)
```

**Measured 2026-07-29: present, 314 bytes, `core.hooksPath` unset [V].** graph is armed by this
untracked shim rather than by `core.hooksPath`, because setting that path would disable the gitleaks
pre-commit. **Nothing in core asserts the shim exists.** Absent, every push in this pull passes
without running a single validator, and that reads exactly like a clean push.

**STOP CONDITION:** shim absent, or `core.hooksPath` set to anything. Do not proceed and do not
"fix" it by setting `core.hooksPath` — that trades this problem for the gitleaks one.

**1b. `_bmad/` must exist** or `install.sh` aborts. Measured: present [V].

**1c. A clean tree.** `git status --porcelain` — commit or stash first. A dirty tree makes the
post-apply `cmp` comparisons in row 7 unreadable, and `_bmad-output/` churn is normal here so read
the list rather than the count.

**1d. Pin the engine, and run the classifiers from a worktree of the DISTRIBUTION at the target
sha — never from graph's installed copies.**

```bash
git -C /Users/n8/git/ai-dlc worktree add --detach /tmp/pull-engine 3490997
git -C /tmp/pull-engine rev-parse --short HEAD     # MUST print 3490997
```

**This is not a preference.** graph's installed engine is 0.183.0 and **cannot emit statuses this
pull adds** — `--strays` appears in its `validate-provenance-block.sh` **zero times** [V]. Revision 1
quoted a tally measured with the new engine while telling the agent to run the old one. Every command
in rows 2 and 7 is prefixed with `/tmp/pull-engine/core/…` for this reason.

**Tick row 1** with the shim's byte count and the worktree sha.

---

### Row 2 — classify only. Report all six tallies. Write nothing. In `graph`.

**The two classifiers take their arguments in DIFFERENT orders.** This has bitten a real run.

```bash
E=/tmp/pull-engine
# layer-drift.sh   <dist> <base> <theirs>   <consumer>
bash $E/core/skills/ai-dlc-update/reconcile/layer-drift.sh \
     /Users/n8/git/ai-dlc 46aa98a 3490997 /Users/n8/git/graph > /tmp/ld.txt
# ledger-reverify.sh <dist> <base> <consumer> <theirs>     <-- 3rd and 4th SWAPPED
bash $E/core/skills/ai-dlc-update/reconcile/ledger-reverify.sh \
     /Users/n8/git/ai-dlc 46aa98a /Users/n8/git/graph 3490997 > /tmp/lr.txt
cut -f1 /tmp/ld.txt | sort | uniq -c | sort -rn
```

**EXPECTED — `layer-drift.sh`, measured 2026-07-29 with the shipping code [V]. 69 rows:**

| Status | Count | Note |
|---|---|---|
| `HARD-LAYER-ADJUDICATION-MISSING` | **17** | **BLOCKS `apply`.** Row 5 is these. |
| `EXTENSION-HOOK-DRIFT` | **17** | one per adjudication row, by construction |
| `EXTENSION-OK` | 16 | |
| `OVERRIDE-OK` | 9 | |
| `HARD-OVERRIDE-DRIFT-SECTION` | **4** | **BLOCKS.** `readopt-override.sh --merge` in row 6 |
| `OVERRIDE-DOUBLE-SHADOW` | 2 | one deliberate collision, self-documented. Report-only |
| `OVERRIDE-DELEGATES-INTO-SHADOW` | 2 | report-only, already deferred to a sprint |
| `OVERRIDE-ASSERTS-SHADOW-SURVIVES` | 2 | report-only |

**STOP CONDITION:** any total other than 69, any status not in this table, or a count off by one.
Report it at the boundary — do not adjust the table.

**ZEROS THAT ARE STRUCTURALLY IMPOSSIBLE, not clean.** State these in your report explicitly,
because a real run has already mistaken one for evidence that work was disposed:

- **`EXTENSION-ANCHOR-DRIFT` and `EXTENSION-ANCHOR-MISSING` will be ZERO.** No graph entry declares
  `extends:`, so both are **unable to fire**. A row carrying either means an entry gained an
  `extends:` key — not that the classifier misfired.
- **`Check AP` and `Check VH` will NOT appear** in row 2's `UNLOADABLE` tally. The heading grammar is
  numeric; both are alphabetic and structurally outside what it can see. Both **are** live and
  unloadable. Their absence is not evidence they load.
- **`EXTENSION-RETIRE-CANDIDATE` will be ZERO** — measured, against a table that predicted it would
  rank third in the migration order.

**`EXTENSION-HOOK-DRIFT`'s message text changed in v0.196.0.** A prompt that greps the old wording
counts zero. **Match the STATUS token, never the sentence.**

**Then the four consumer-side tallies. Note each one's invocation trap from §4 — four of the five
false probes are in this block.**

```bash
# (i) W5 squatters — the token 'W5' is NOT in the output. Match the message.
bash $E/core/scripts/validate-layer-entries.sh /Users/n8/git/graph 2>&1 | tail -3
#     EXPECT: 0 error(s), 5 warning(s) -- checks 33/34/35, rules 31/32, all "OUT OF BAND"

# (ii) UNLOADABLE — takes a FILE, not a root
bash $E/core/scripts/validate-gate-manifest.sh \
     /Users/n8/git/graph/.claude/skills/ai-dlc/steps/gate-validation.md 2>&1 | grep -E 'UNLOADABLE|MISSING|ORPHAN|manifest source'
#     EXPECT exit 1: UNLOADABLE = 19b 2s 33 35 ; MISSING none ; ORPHAN none
#     EXPECT manifest source: overrides/steps__gate-validation__check-25-universal-core.md
#            extension gate_types: none          <-- both change in row 3

# (iii) fixture drivability — takes --dir, run from graph's root
cd /Users/n8/git/graph && bash $E/core/scripts/validate-fixture-drivability.sh --dir tests/fixtures 2>&1 | head -5
#     EXPECT exit 1: 103 directories / 73 driven / 2 declared undrivable / 28 undeclared

# (iv) Check 5's new enforcer. Run from graph's root.
#      NOTE: the shipping script needs the shipping SCHEMA. Run against graph's installed
#      copies and it dies with KeyError: 'story_key_re' -- that is a version skew, not a
#      finding. Stage both, or defer this one to row 7 where apply has landed both.
bash $E/core/scripts/sprint-status.sh check-stories 2>&1 | tail -3
#     EXPECT: PASS -- 2 comparison(s) over 2 entries, 0 finding(s)   (sprint 299)
```

**EXPECTED, all measured 2026-07-29 with the shipping code [V]:**

| Tally | Expected | Stop condition |
|---|---|---|
| `W5` warnings | **5**: checks 33, 34, 35; rules 31, 32 | a 6th, or a different subject |
| `UNLOADABLE` | **4**: `19b`, `2s`, `33`, `35`. `MISSING none`, `ORPHAN none` | a 5th, or any MISSING/ORPHAN row |
| Fixture dirs | **103 / 73 driven / 2 undrivable / 28 undeclared** | a 29th, or `declared undrivable` ≠ 2 |
| Check 5 `check-stories` | `PASS — 2 comparison(s) over 2 entries, 0 finding(s)`, sprint 299 | any finding; **exit 4 means it compared nothing and is never a pass** |

**The 2 `declared undrivable` are core's own `check-h1-recursion` and `check-manifest-bypass`.** If
either appears in the 28 findings instead, the exemption marker has diverged and **that is a CORE
defect** — stop and say so at the boundary.

**`--strays` CANNOT BE MEASURED HERE, and that is the finding.** graph's installed copy has the mode
zero times; it arrives with the pull. Do not run it against graph's tree in row 2 and do not read its
absence as a pass. Row 3 stages it in a **copy**. Expected there: **5 findings, all under
`scripts/tests/**`** [V].

**Tick row 2** with all six tallies, verbatim.

⏹ **SESSION BOUNDARY.** Report every tally to the ai-dlc session. Any deviation is adjudicated
there — core defect or consumer decision — **before** row 3 writes anything.

---

### Row 3 — the two mechanical pre-apply edits. In `graph`.

Both are **required**, both are mechanical, and both were verified end to end on a **copy** of graph
on 2026-07-29 [V]. Two edits, then two verifications.

**3a. Register `scripts/tests/**` as a party-mode home. WEDGES THE PUSH if skipped.**

One line into `.claude/skills/ai-dlc/extensions/known-skills.json`, which already exists carrying
`known_skills`:

```json
"party_mode_homes": ["scripts/tests/**"]
```

**Verified on a copy [V]:** before, **5 findings**, every one under `scripts/tests/**` — a consumer
test-harness tree carrying sample blocks inline. After, `--strays: PASS`, **893 file(s) carried the
envelope**.

**STOP CONDITION:** a 6th finding, or one **outside** `scripts/tests/**`. **Do NOT widen the homes to
make it pass.** A home added because it currently reports a finding is an exemption wearing a
performance argument, and the tree it would hide is graph's product source.

*(The recorded figure was 889 carriers; **893** is current. The finding count and subject are
unchanged, so the drift is in files added since, not in the gate.)*

**3b. Retire `overrides/steps__gate-validation__check-25-universal-core.md`. REQUIRED, not optional.**

```bash
git rm .claude/skills/ai-dlc/overrides/steps__gate-validation__check-25-universal-core.md
# then add to the frontmatter of extensions/checks/gate-validation-domain.md:
#   gate_types: implementation
```

**Why it is required and not a suggestion.** That override is **132 lines** carrying an entire
section's `base_sha` drift in order to add one integer to one table cell — and its own first line,
*"Identical to core, with one change"*, is **FALSE**: it drops core's canonical gate-type enum
(`planning · story · implementation · sprint-review · retro`) and the deployment/schema paragraph.
**graph has been running gates against a rendered document with no gate-type enum in it.** Retiring
restores both. v0.197.0's `gate_types:` on check extensions exists precisely to make this possible.

**Verified on a copy with the shipping code [V]. Expected after:**

```
manifest source: core                        (was: the override)
extension gate_types: 34->implementation     (was: none)
MISSING none ; ORPHAN none
exit 1 for the four UNLOADABLE rows ONLY
```

**STOP CONDITION:** any `MISSING` or `ORPHAN` row. That means the tree moved and this instruction is
stale — **do NOT re-author the override to make it pass.**

**Tick row 3** with `--strays: PASS (N carriers)` and the `manifest source:` line.

---

### Row 4 — the 28 fixture declarations. In `graph`. **Its own session.**

**WEDGES THE PUSH if skipped**, and this is the row most likely to be done wrong rather than left
undone.

v0.202.0 added a `fixture drivability` step to the consumer pre-push. Each of the 28 undeclared
directories wants **one** of two one-line declarations, and **which one is a per-directory judgement
you must make**:

1. **a `run.sh`** — two lines delegating to the harness that already drives it. This also puts that
   harness into the push suite instead of a hand-maintained `ci-local.sh` trigger, which is a real
   gain, not a formality.
2. **a `README.md`** carrying ``No `run.sh`, deliberately`` and the reason — for a fixture no script
   can drive. It is evidence an LLM reads at a gate.

**THE HAZARD, and it is the whole reason this row has its own session.** Route 2 over a fixture that
**has** a driver is a false statement **the script cannot detect and will accept**. Under push
pressure it is also the faster route for all 28 — which would convert one real finding into 28 silent
exemptions and leave the consumer exactly where it started. **Do not batch-apply route 2.**

**A starting classification — and it is [R], a CITATION, not a proof.** Derived by
`git grep -lF "fixtures/<name>"` over graph restricted to executables. **A script that names a
fixture is not necessarily a script that drives it.** Confirm each one before acting on it.

- **14 cite an executable driver** (route 1 likely): `check-cycle-types-bypass`,
  `check-ff-escalation`, `check-il-oracle-presence`, `check-substrate-audit`, `cycle-commits`,
  `detectors`, `exclusion-importer`, `live-contract-probe`, `live-shape`, `phase-sequencing`,
  `pipe-exit-mask`, `provenance-in-non-retro`, `retro-replay`, `rule-ref-reconcile`.
- **14 cite none** (route 2 likely; most are evidence for LLM-read `check-*` gate checks):
  `boundary`, `check-7-arch-content`, `check-18-runtime-constraints`, `check-19-disposition`,
  `check-20-doc-check`, `check-21-section0`, `check-26-deployed-ranges`, `check-27-config-integrity`,
  `check-30-orphaned-fn`, `check-31-cited-sha`, `check-35-mutation-red-reachability`,
  `check-a52-sprint-pr-merge`, `compute`, `retro-audit`.

**`boundary` is the one most worth re-reading.** It cites `scripts/regen-boundary-fixtures.sh`, which
**REGENERATES** it rather than driving it — which is why it sits on the route-2 side. That distinction
is exactly the one the citation cannot make for you.

**On `retro-replay`:** graph's `scripts/retro-replay-harness.sh` and its `scripts/tests/test-*.sh`
siblings are **NOT absorbed** by core — that arm's "registrable entry point" premise was refuted.
They stay where they are; a `run.sh` delegating to them is now the sanctioned way into the push suite.

**Verify after, from graph's root:**

```bash
bash /tmp/pull-engine/core/scripts/validate-fixture-drivability.sh --dir tests/fixtures
#   EXPECT exit 0: 103 directories / 101 driven-or-declared / 2 declared undrivable / 0 undeclared
```

**Tick row 4** with the count that went each route — `N run.sh, M README.md, N+M = 28`.

⏹ **SESSION BOUNDARY.** 28 judgements is a full session. Do not continue into row 5.

---

### Row 5 — the 17 adjudications. In `graph`. **Its own session.**

**BLOCKS `apply`. There is no skip flag, deliberately.** This is *the layer conformance
adjudication*, shipped in v0.213.0 as `level: ADJUDICATED` — the newest and largest obligation in
this pull, and the one no earlier revision mentions.

**What it is.** `EXTENSION-HOOK-DRIFT` means the core file an extension hooks changed, and an
extension has no section anchor, so nothing can locate what to re-merge. The verdict is **yours**:
the candidate set is mechanized, the judgement is not. Before v0.213.0 this was a `WARN` that
reprinted every pull with no way to say "this one was read" — so the worklist got cleared rather than
read. Now skipping it is a blocked pull instead of a silent one.

**Read the entry against the new core text and record one verdict per row:** `still-additive`,
`contradicts-core`, or `retire`.

**How to record.** One JSON object per line in
`_bmad-output/ai-dlc-update/layer-adjudication-register.jsonl` (shape:
`.claude/schemas/layer-adjudication-register.json`), copying `subject_digest` **verbatim from the
blocking row**:

```json
{"clause":"LC-E4","entry":".claude/skills/ai-dlc/extensions/checks/gate-validation-domain.md","subject_digest":"<copied from the row>","verdict":"still-additive","recorded_utc":"2026-07-30T09:00:00Z","reason":"core's change was to the gate-type enum; this entry adds a check row and does not restate it"}
```

**Four things that will bite:**

1. **Do not re-derive the digest.** It covers the entry **and** the hooked core file at `theirs`.
   Copy it from the row. A digest computed two ways is a digest computed wrong.
2. **A verdict is spent when either side moves.** It is a record of a reading, **not an exemption for
   the path** — which is the entire reason the register is keyed per subject and not per run.
3. **The verdict must be one of the three.** Anything else does not discharge the duty; the schema's
   enum is what the enforcer reads.
4. **Changing your mind is allowed and must be declared.** A second record under one key with a
   different verdict needs `supersedes` **and** `reason`, or it is `HARD-REGISTER-CONTRADICTION`.

**`jq` must be on PATH.** Without it the register cannot be read, and the enforcer treats that as
blocking rather than as an empty register — a register that cannot be read is not a register with
nothing in it.

**Why this row can precede `apply` even though it reports on incoming core.** The classifier reads
`theirs` from the pinned distribution, not from graph's working tree. Every one of the 17 rows is
computable — and recordable — before a single core byte is written. That is the point of doing it
here rather than mid-apply.

**Verify: re-run row 2's `layer-drift.sh` command.**

```
EXPECT: 0 HARD-LAYER-ADJUDICATION-MISSING
        17 EXTENSION-HOOK-DRIFT   <-- UNCHANGED. This row must NOT go quiet.
```

**The second line is the load-bearing half.** The candidate row still prints once adjudicated; only
the blocking row disappears. If `EXTENSION-HOOK-DRIFT` dropped to zero, the clause's declared code is
being emitted by nothing and the clause has become unfalsifiable — **report that as a core defect.**

**Tick row 5** with the verdict split — `N still-additive, M contradicts-core, K retire, sum = 17`.

⏹ **SESSION BOUNDARY.**

---

### Row 6 — `apply` on one branch. In `graph`.

**One branch, machinery and rulebook together.** Locked in §2; the reason is that the update skill's
own self-update cycle installs a validator that blocks its own push, so a split lands a tree that
cannot be pushed. Precedent: PR #829.

```bash
git checkout -b chore/ai-dlc-update-0.213.0
```

**Before `apply`, run the blocking list and read it.** `apply` must not be approved against a report
that dropped a line:

```bash
E=/tmp/pull-engine
bash $E/core/skills/ai-dlc-update/reconcile/hard-blockers.sh \
     /Users/n8/git/ai-dlc 46aa98a /Users/n8/git/graph 3490997
```

**EXPECTED after rows 3–5: the 4 `HARD-OVERRIDE-DRIFT-SECTION` rows and NOTHING ELSE.** The 17
adjudication blockers are discharged by row 5's register; if any still appears, row 5 is incomplete —
go back, do not proceed. `hard-blockers.sh` derives its list from the detectors by design, so a
blocker missing from a hand-written report is a blocker you would approve without seeing.

**The 4 drift-section blockers go through `readopt-override.sh --merge`,** one at a time. Each is an
override whose shadowed core section changed in this span — upstream's new text and the consumer's
override both need to survive, and that is a merge, not a pick.

Then run the pull itself (`/ai-dlc-update`, or `reconcile/apply.sh` per the skill's step 6). **The
new core files must be in the write set** — a new core file silently not written is indistinguishable
from one written correctly. At minimum, confirm afterwards:

```bash
test -f .claude/schemas/layer-adjudication-register.json && echo present || echo MISSING
test -f .claude/skills/ai-dlc/layer-contract.yaml        && echo present || echo MISSING
```

**Flagged-block checkpoint applies.** Any block carrying `needs_operator_confirmation: true` stops
here and asks — being inside an authorized `apply` does not waive a judgement the classifier flagged.

**Tick row 6** with the branch name and the blocker count you cleared.

---

### Row 7 — post-apply verification. In `graph`.

**Read the LABEL, not the exit status,** on every `cmp` below. The two branches assert *opposite*
things before and after apply, and revision 1 shipped a success-branch label that was
self-contradictory.

```bash
E=/tmp/pull-engine
cat .claude/.ai-dlc-version        # BOTH pairs must read 0.213.0 @ 3490997

# the flip: graph's installed validators must now be IDENTICAL to the distribution's
for s in validate-layer-entries.sh validate-gate-manifest.sh validate-provenance-block.sh \
         validate-fixture-drivability.sh sprint-status.sh; do
  if cmp -s "scripts/ai-dlc/$s" "$E/core/scripts/$s"; then
    echo "IDENTICAL  $s   <-- required AFTER apply"
  else
    echo "FORKED     $s   <-- stop and report"
  fi
done

# --strays is now REAL here for the first time (row 3 measured it on a copy)
bash scripts/ai-dlc/validate-provenance-block.sh --strays
#   EXPECT: PASS, ~893 carriers

bash $E/core/skills/ai-dlc-update/reconcile/unregistered-drift.sh \
     /Users/n8/git/ai-dlc 46aa98a . > /tmp/unreg.tsv 2>/dev/null
grep -c '^HARD-' /tmp/unreg.tsv    # EXPECT 0
```

**EXPECTED — and this is where revision 2's numbers do NOT carry forward.** Measured on a copy at
`170ff9d8c` with the shipping code after rows 3–5 [V]:

```
validate-layer-entries: 0 error(s), 5 warning(s)      exit 0
```

**Revision 2 expected `exit 1` with 3 `ERROR` lines and called that "the expected, correct
outcome."** That was true for 0.183.0, whose ERROR tier was brand new and had three live subjects.
**Those three were fixed in that pull.** At 0.213.0 the correct outcome is **exit 0** with the 5 `W5`
warnings and no errors. **A non-zero exit here is a real finding now, not a success.** This is the
single most important difference between the two revisions.

**ZEROS THAT ARE STRUCTURALLY IMPOSSIBLE POST-APPLY — state them, do not count them as clean.**
After `apply`, **`base` equals `theirs`**, so:

- **`EXTENSION-HOOK-DRIFT` and roughly 8 of 13 statuses cannot fire at all.** There is no range left
  to diff. A real run mistook this for evidence the re-reads had been disposed. **It is not.** Row 5's
  register is the evidence they were disposed; this zero is arithmetic.
- The same applies to every `OVERRIDE-DRIFT-*` status.

**Then verify against the RENDERED pipeline, never against core alone.** A core fix is effective only
if it survives `overrides > extensions > core` resolution. For every override re-adopted in row 6,
grep the **override** for the new clause — that is the text the lead actually obeys. Core containing
a fix proves nothing about a section the consumer shadows.

**Run the fixture suite.** It now includes graph's own directories plus whatever row 4 wired in:

```bash
bash scripts/ai-dlc/validate-fixture-drivability.sh --dir tests/fixtures   # EXPECT exit 0
```

**Tick row 7** with the version line, the five `IDENTICAL` labels, and the linter's footer verbatim.

⏹ **SESSION BOUNDARY.**

---

### Row 8 — the push-candidate ledger. In `graph`.

Three edits, all mechanical, all in
`_bmad-output/ai-dlc-update/push-candidate-ledger.md`.

**8a. Close `PC-S296` as `ADOPTED UPSTREAM (v0.184.0)`.** The operator's SPLIT determination drove
that fix and it closes the case that kept the entry open. **Note the recorded trap:** v0.181.0 wrote
`PC-S296` as "absorbed v0.153.0" in core's CHANGELOG *and* in a comment inside `ledger-reverify.sh` —
a **citation read as a fix**. The anchoring closed one arm while the entry's actual subject stayed
live until v0.184.0. Close it against the fix, not against the citation.

**8b. Update the 3 `NAMED-ABSORBED` annotations to `NAMED-UPSTREAM`.** v0.186.0 renamed the status
because the old token contradicts its own header and misled its author. Core no longer carries the old
string outside `CHANGELOG.md` and `docs/reviews/` — both historical and deliberately unchanged — so a
consumer-side grep for it is unambiguous:

```bash
grep -rn 'NAMED-ABSORBED' _bmad-output/     # EXPECT exactly 3, all in the ledger
```

**There is no detector for this**, deliberately: `retired-tokens.sh` matches only `$VAR/path` shapes
in the CLASSIFY bucket, and `retired-layer-contract.sh`'s subject set excludes
`ai-dlc-update/SKILL.md` where the status vocabulary lives. **If you skip 8b, nothing will tell you.**

**8c. When writing any `verify:` receipt — no apostrophes.** `ledger-reverify.sh`'s awk program is a
single-quoted shell string. The file warns about this three lines above where the last change landed,
and that change still wrote `PC-S296's` and failed to parse.

**Tick row 8** with the grep count for the old token — it must be **0** after.

---

### Row 9 — commit, push, PR, merge. Then unfreeze. In `graph`.

**Push in the background.** graph's pre-push runs its whole fixture suite; a foreground push hits the
tool timeout. Redirect to a log, poll for a sentinel, and **verify with
`git ls-remote --heads origin <branch>`** — never by trusting a piped exit code.

```bash
( git push -u origin chore/ai-dlc-update-0.213.0 > /tmp/push.log 2>&1; echo "PUSH_RC=$?" >> /tmp/push.log ) &
# poll for PUSH_RC, then:
git ls-remote --heads origin chore/ai-dlc-update-0.213.0
```

**If the pre-push refuses, read which gate.** All three wedging gates were closed in rows 3–5; a
refusal means one of them regressed, and the remedy is the finding — **never `--no-verify`**.

**One known-flaky class, and the correct response to it.** Two core fixtures
(`layer-readopt-gate`, `apply-drift-refile`) have gone red **once** each under a parallel suite and
green on every rerun. The failure is **cold-start correlated** and the shared factor is the runner, not
either fixture. A re-push is correct **only after showing the release cannot reach the fixture** —
grep every file the pull touched against the fixture, with a control proving the grep matches
something. `--no-verify` is never the answer.

**graph's `ci-local.sh` has two pre-existing failures on main** — shellcheck on four `scripts/*.sh`,
and `server-fixture-manifest` — **unrelated to this pull [R, operator-reported]**. Do not attempt to
fix them here; confirm they predate the branch and say so in the PR.

**The PR body should carry:** the six row-2 tallies, the verdict split from row 5, the route split
from row 4, and the four items from §5's out-of-scope list as explicit follow-ups so they are filed
rather than forgotten.

**After merge: the freeze ends.** Say so to the operator — no sprint has run in graph for the duration
of this program, and rows 1–11 of the distribution-side program are all closed.

**Tick row 9** with the merge sha. **That closes the pull, and with it the layer contract program.**

---

## 7. Known-open, deliberately out of scope

These are recorded so a later session does not re-open them as defects. Each is a real gap with a
stated reason for not closing it here.

- **`contract_version` and `conforms_to` have no reader anywhere in the tree.** The retro-application
  rule the contract states — an entry declaring `conforms_to: N` is held only to clauses with
  `since <= N` — is enforced by nothing, and no consumer entry declares `conforms_to:` today. I41/I42
  keep the declaration coherent; they do not build the reader.
- **`layer-drift.sh`'s status list in `ai-dlc-update/SKILL.md` is prose nothing binds.** It silently
  lagged one status behind from v0.187.0 to v0.192.0. The fix is I39's shape one detector over, and its
  false-positive set is **unmeasured** — the same grammar over the whole file matched 20 tokens when
  I39 tried it, 15 of them other detectors'. Measure before writing it.
- **A retired STATUS token in a consumer layer file has no detector** — this is why row 8b is a manual
  step. Covering it means widening `retired-layer-contract.sh`'s subject set, whose FP set across every
  shape it already extracts is unmeasured.
- **`Check AP` and `Check VH` are outside GM1's subject set.** The heading grammar is numeric. Both are
  live, both carry a real Scope line, and both are unloadable today. Widening is bound to
  `relabel-extension-checks.sh` by I34 — a detector that finds a heading the rewriter cannot rewrite
  reports a defect with no remedy.
- **An override asserting IDENTITY rather than survival has no detector.** v0.187.0's predicate needs a
  scope phrase whose noun is the shadowed grain; `check-25-universal-core`'s *"Identical to core, with
  one change"* has none. Row 3b removes the reason that override exists rather than detecting its
  claim — which is why retiring it is required rather than optional.
- **`--audit-diff`'s citation arm is not bound to the touch it clears.** `pending.md` accumulates, so
  three legacy citations from S298/S299 clear every future in-place core edit. Binding it needs a
  predicate core can derive, and the FP set is unmeasured because the reference consumer has no
  *authorized* in-place core edit to measure against.
- **The crosswalk table's completeness has no clause, deliberately.** Core cannot see which numbers a
  consumer has written into evidence — gate logs, retros, escalations, most of them rotated into
  archives. If it is ever mechanized it will be from the **consumer** side.
- **`enforcement-map.yaml` is copied by `install.sh` but appears nowhere in `core-manifest.md`** — an
  unmanifested core file, so consumer edits to it are not drift-scanned.
