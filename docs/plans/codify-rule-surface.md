# Codify the effective rule surface of ai-dlc — DISCHARGED

**DISCHARGED at `v0.366.0`. DO NOT EXECUTE.** Every numbered action is built, gate-green and
merged, and all four operator decisions are ruled. This file is now a RECORD of why each
decision went the way it did. Part 4 carries the closed action list and the rulings; Parts
1–3 are the inventory and reasoning that produced them.

## Context

Every rule that governs work in this repo lives in one of four places today, and only two of
them are in git. `CLAUDE.md` and `.claude/rules/` are tracked and validated. A third surface —
80 firing invariant arms, 11 pre-push steps, 147 fixtures — is tracked as executable code. The
fourth is **213 untracked markdown files in the operator's home directory**, indexed by a
71-line `MEMORY.md`, holding what deduplicates to **46 distinct standing rules**. That fourth
surface is invisible to every reviewer, survives no machine change, and is reachable by no gate.

This plan inventories all four, states where each rule sits versus where it belongs, and
proposes the codification. Three defects in the *already-codified* surface were found while
measuring it, and they are the argument for the work: a rule surface nobody joins to ground
truth drifts exactly like the memory corpus does, only with more authority.

## Start here

**Repos.** One tree is written: `/Users/n8/git/ai-dlc`.
`/Users/n8/.claude/projects/-Users-n8-git-ai-dlc/memory/` — **read it, never write it**, except
where a numbered action names the file. No consumer repo is touched at any point.

**Merges are preapproved.** No step in this plan stops for merge authorization.

**Everything is sourced.** Every figure below was re-derived against the working tree with a
same-invocation control. Where a subagent's number disagreed with the re-derivation, the
re-derivation is what appears here.

**Ping the operator** on any question, on any decision marked OPERATOR DECISION, and on
completion including an early stop.

**Start at Part 4.** It opens with the closed action list and the four rulings; the table under
them is the record of what merged, and "Working this repo" carries the mechanics the waves cost
to learn. Parts 1–3 are the inventory, gap analysis and recommendations that produced all of it
— read them for WHY a decision went the way it did, not for current state.

**Parts 1 and 2 are a point-in-time measurement, not a live reading.** Their figures were taken
before any of this shipped, and several have moved since — the fixture count and the invariant
totals in particular. Re-derive anything you intend to act on; the commands are in the text.

## Status

**DISCHARGED.** Six releases are built, gate-green and merged to `main`, which is at
`v0.366.0`. **Nothing remains**: the three actions that were open at handoff are closed in
Part 4, and the three decisions that were open are ruled there.

The last full verification before the final release was `AI_DLC_FIXTURE_NO_SKIP=1 bash
.githooks/pre-push`: **147 of 147 fixtures, all gate steps green, both skips disabled, 581s
wall from inside the repo.** That timing was the one done-when the program had missed.

Seven operator rulings are folded in — topical unscoped rule files (R1), no
`docs/coding-conventions.md` (R2), prose plus a structural proxy for the two standing
directives (R4), derive the `OK:` line rather than hand-maintain it (R6), hold the
durable-channel ceiling where it is, do not widen arm A1, and keep the three consumer-workflow
clusters in the memory corpus. The last three are recorded at the end of Part 4 with the
ground truth each turned on.

**Four corrections to this plan, every one forced by a mechanism rather than by review**, and a
resuming session should expect more of the same. Dating frozen measurements in `CLAUDE.md` is
not available, so the fix is removal (R5). The `.claude/rules/` files sit inside the rule-file
audit corpus, so they carry no version tags, sprint ids or dates (R1). Two of Wave B's candidate
arms and one of Wave C's were dropped on measurement rather than tuned, because their entire hit
set was correct code (R3, R4). **Writing a check is not measuring it — three of the nine arms
this plan proposed did not survive contact with the corpus.**

---

# Part 1 — The inventory

## A. Codified prose (git-tracked, binding this repo)

| Surface | Size | Loader semantics |
|---|---|---|
| `CLAUDE.md` | 224 lines, 13,645 B, ~45 rules in 9 sections | Unscoped, so re-injected on **every** compaction and resident every turn. Reaches subagents. |
| `.claude/rules/fixture-mutants.md` | `paths: core/fixtures/**` | Loads on the **first matching Read/Edit only**, once per session. `Write`/`Grep`/`Glob`/`Bash` do not fire it. **Not** re-injected after compaction. A subagent's read never reaches the parent. |
| `.claude/rules/fixture-ship-decl.md` | `paths:` fixtures + `install.sh` + `uninstall.sh` | same |
| `.claude/rules/plan-shape.md` | `paths: docs/plans/**` | same |
| `.claude/rules/plan-shape-measured.md` | `paths: docs/plans/**` | same |
| `README.md` §Working on the distribution, §Versioning | ~40 lines | Read only when someone opens it. Carries the gate-enable command, the deliberate no-GitHub-Actions policy, and the SemVer bump rules. |
| `.gitignore:41` comment block | 9 lines | Explains the `.claude/*` narrowing that makes rule files committable. |
| `core/rules/ai-dlc-resident-discipline.md:3-13` | 3 rules | Authoring constraints on that file itself. Its body is **consumer** content. |

## B. Mechanized (the only surface that blocks)

Entry point is `git push` → `.githooks/pre-push`, 11 steps. No pre-commit, no
`.github/workflows`, by policy.

| Mechanism | Binds |
|---|---|
| `scripts/validate-enforcement-map.sh` | The invariant registry. As measured then: **80 IDs can fire**; its final `OK:` line named **71**. That line no longer enumerates anything — see R6. |
| `scripts/validate-claude-rules.sh` | Arms A1–A4: `CLAUDE.md` ↔ `.claude/rules/` in both directions; every `paths:` glob non-empty; Cursor `.mdc` keys forbidden; every rule file pointed at or carrying a non-empty `no-stub` reason. |
| `scripts/validate-plan-shape.sh` | Arms P1–P7 over `docs/plans/*.md`: entry point, numbered actions, read/write boundary, operator ping, resolving citations, no contradictory identifier, one current status, no opt-out kit. |
| `scripts/validate-release-version.sh` | Commit subject == `VERSION` == CHANGELOG heading, per commit and across a range. |
| `scripts/validate-no-dead-doc-refs.sh` | No `core/**` file cites a `docs/` design doc `install.sh` does not ship. |
| `core/scripts/sync-taught-schema.sh --check` | The rendered-region + byte-compare pattern, already pre-push step 1. |
| `core/scripts/validate-reattach-budget.sh:99` | A resident-size budget — **`--skill`-scoped to `SKILL.md` only**. |
| 147 fixture directories | `plan-shape/` and `claude-rules-joins/` prove those two validators can FAIL. |

## C. The 46 memory clusters, and where each belongs

Legend — **MECH**: already enforced by a named mechanism. **HAVE**: already in tracked prose.
**→RULES**: belongs in a new topical unscoped file under `.claude/rules/` (R1). **→VAL**: needs
a new standalone validator + fixture. **KEEP**: episodic or consumer-workflow, stays in memory.
Target files: `verification-discipline.md` (VD), `tool-hazards.md` (TH), `consumer-boundary.md`
(CB), `mechanism-design.md` (MD), `resident-context.md` (RC), `operator-rulings.md` (OR).

| # | Rule | Disposition |
|---|---|---|
| D1 | Prove a check passes vacuously → FAILS on the real bug → passes after the fix | HAVE `CLAUDE.md §A check that cannot fire`; the **self-probe-before-corpus** form (`validate-claude-rules.sh:29`) is unstated → +VD |
| D2 | The distribution is not a consumer: install into a clean tree and run as one, in both layouts | HAVE partly `CLAUDE.md §Two layouts`; general form → CB |
| D3 | A hand-maintained list is the bug — derive both sides | HAVE `CLAUDE.md §Prohibitions need mechanisms` |
| D4 | A control that agrees with the verdict, or that proves only the run worked, is not a control | HAVE partly `CLAUDE.md §A zero is not a finding`; refinement → VD |
| D5 | Never `$?` after a pipe; `printf \| grep -q` under `pipefail` reports NOT-FOUND at ≥64 KiB | MECH I54/I54b (`validate-enforcement-map.sh:4265`, `:4375`) |
| D6 | The Bash tool's shell is zsh — no `PIPESTATUS`, no word-splitting, history modifiers eat unbraced `"$ref:path"`, force `bash -c` | HAVE half `CLAUDE.md §A zero is not a finding`; remainder → TH. **Corpus is 0 tracked files**, so no validator is possible |
| D7 | BSD grammars — no `\s` in BRE, `[ \t]` is not a tab, no `\1` in awk `sub()`, `awk -v` strips escapes, BSD sed no-ops GNU constructs | MECH for the `[ \t]` half (I71, `:4179`); remainder → VAL |
| D8 | Assignments and exit codes inside `$( )` or a pipeline's last stage are lost | MECH for the pipeline half (I54b); `$( )` half → VAL |
| D9 | Git lies by default — `-M` for renames, brace rev-paths, never test landing by ancestry in a squash-merge repo | → TH (ad-hoc tool calls leave no artifact) |
| D10 | Environment floor — bash 3.2, no `setsid`, SIP blocks `dtruss`, the interactive `grep` is a ugrep shim honoring `.gitignore` | `mapfile`/`declare -A`/`setsid` → VAL; the rest → TH |
| D11 | Run the SHIPPING code against the REAL corpus; a hand-written probe is a second implementation | → VD |
| D12 | Verify the premise — measured base rate of expired premises ~1 in 2 | → VD |
| D13 | Ask what SET a number was taken over, and whether it is the set the mechanism runs on | → VD |
| D14 | Measure the false-positive set before designing the check | HAVE `CLAUDE.md §Before adding a check`; the **FP-narrowing record** convention is unstated → +VD |
| D15 | Score mutants one at a time; `cmp -s` proves only that bytes changed | HAVE `.claude/rules/fixture-mutants.md` |
| D16 | A fixture must not agree with itself — never seed from the reader's accept-set | HAVE partly; the *different-author* clause → extend that rule file |
| D17 | A fixture whose tree cannot EXPRESS the defect proves nothing | HAVE partly; extend that rule file |
| D18 | Rehearse a pull or bulk migration on a `file://` clone; every figure comes from the run | → CB |
| D19 | An ai-dlc session never writes to the consumer; plan across both and close on a consumer measurement | → CB |
| D20 | A consumer runs its OWN installed engine, so a bootstrap fix cannot be delivered by the step it fixes | → CB |
| D21 | Packaging is enumerated in several places and every one rots | HAVE `.claude/rules/fixture-ship-decl.md` + I8/I13/I14/I74 |
| D22 | Verify a release with `AI_DLC_FIXTURE_NO_SKIP=1 bash .githooks/pre-push`; `core/git-hooks/pre-push` is the CONSUMER's and prints green having run almost nothing | HAVE half `CLAUDE.md §Run the fixture suite`; the two-hooks trap and the env var → +VD |
| D23 | No rationale, narrative, version tag or date in resident rule prose | **No home for this repo** → RC |
| D24 | Verbosity is deliberate scar tissue — delete only vestigial prose whose enforcer you can name | **No home** → RC |
| D25 | A rule survives compaction only if something other than memory CARRIES it | **No home** → RC |
| D26 | Anchor a receipt on a token the fix cannot be written without | KEEP (consumer ledger workflow) |
| D27 | A join that cannot FAIL is the mirror of a check that cannot fire; prefer a partition | HAVE partly `CLAUDE.md §A check that cannot fire` → +MD |
| D28 | A vacuous guard is a loaded gun; fix by subtraction | → MD |
| D29 | A whole-file `grep -qF` is satisfied by a comment — key a binding on the EMISSION SITE | → VD |
| D30 | A schema or list written N times is N−1 chances to drift | HAVE `CLAUDE.md §Prohibitions need mechanisms` + the enforcement map |
| D31 | Cite, do not restate; a restatement drifts tighter invisibly | → MD |
| D32 | Before writing a mechanism, GREP FOR IT — it usually already exists | → MD |
| D33 | Absorbing a consumer mechanism: ask what core's version IS, which half it owns, whether it fires at the same POINT | KEEP (consumer pull workflow) |
| D34 | Prohibitions need mechanisms | HAVE `CLAUDE.md §Prohibitions need mechanisms` |
| D35 | Enforce at PreToolUse; write down what makes the signal LET GO in the same change | KEEP (shipped-machinery design) |
| D36 | Render safety-critical output into a generated region with a `--verify` byte-compare | Pattern exists (`sync-taught-schema.sh`), rule unstated → MD |
| D37 | Site a duty where the DECLARATION decides; detect at USE time across N delivery paths | → MD |
| D38 | Never ship a check that wedges an in-flight consumer or errors on correct data at first contact | HAVE locally `validate-plan-shape.sh:21`; general form → MD |
| D39 | Ask what a change makes always-true downstream, and whether it turns a join into a tautology | → MD |
| D40 | Remove the AFFORDANCE rather than policing the violation | → MD |
| D41 | KISS applies to rules, checks, schemas and hooks, not just code | **No home** → MD |
| D42 | Optimize the operator's WALL CLOCK, not tokens — spawn agents liberally, background long work | **No home** → OR (must reach subagents) |
| D43 | A handoff must be executable by a stranger; banner a discharged runbook in its TITLE | HAVE `.claude/rules/plan-shape*.md` + P1–P7; the banner rule → VAL (new P10) |
| D44 | An instruction that ships its own opt-out is not an instruction | HAVE `CLAUDE.md §An instruction that ships its own opt-out` + P7 |
| D45 | Tier findings on CONSEQUENCE — BLOCKER / DEFECT / NOTE | **No home** → OR |
| D46 | Operator standing rulings — a flawed process's output is UNTRUSTED; never narrow a goal on your own authority | **No home** → OR. **This is where the two directives from "Start here" belong.** |

Counts: **9 already mechanized or fully held**, **7 partially held and needing an extension**,
**24 with no tracked home at all**, **3 needing a new validator**, **3 staying in memory**.

---

# Part 2 — Gap analysis

## G1 — `CLAUDE.md` cites an invariant that was deliberately never built

`CLAUDE.md §Some authoring rules live in .claude/rules/` and `CLAUDE.md §Some authoring rules live in .claude/rules/` name **`I88`** as the mechanism binding `CLAUDE.md` to
`.claude/rules/`. `git grep I88` returns five hits, **none in any script**; control `I87`
returns 16 hits in `validate-enforcement-map.sh`. The correction is already recorded twice in
the tree — `docs/plans/claude-rules-adoption.md:135` and `CHANGELOG.md:969` both state the
invariant is `scripts/validate-claude-rules.sh` arms A1–A4, "not `I88`". Nothing joins
`CLAUDE.md`'s citations to what exists, so the rulebook contradicts its own changelog.

## G2 — `CLAUDE.md`'s figures have gone stale, in the section that warns about exactly that

`CLAUDE.md §Run the fixture suite` states a "full 133-fixture suite"; measured **147**. `CLAUDE.md §Some authoring rules live in .claude/rules/` states the
home plans directory holds "60 files"; measured **58**. The same section already says of a
previous instance: *"THAT FIGURE WENT STALE AND NOBODY NOTICED, WHICH IS ITS OWN LESSON."*
Sixteen lines carry an integer ≥ 10 and only two carry a date or version anchor, so a reader
cannot tell a derivable count from a frozen historical measurement.

## G3 — The enumeration `CLAUDE.md` points readers at is incomplete

`CLAUDE.md §Prohibitions need mechanisms` sends the reader to `validate-enforcement-map.sh`'s "final `OK:` line" as the
list of live invariants. Measured at `:6181`: it names **71** IDs, while **80** appear inside an
`err` message and can therefore fire. Nine can fire and are named nowhere on that line — I15,
I16, I17, I18, I33c, I77, I78, I79, I80. The reverse direction is clean. The exact totals shift
with the extractor grammar, since some arms fire from a Python sub-program written to a temp
file, and **that instability is itself the finding**: a hand-built count answers differently
every time it is taken.

## G4 — The compaction-durable channel has no budget

`.githooks/pre-push`'s re-attach budget step runs the resident-size budget, and
`core/scripts/validate-reattach-budget.sh:99` shows it is `--skill`-scoped to `SKILL.md`.
Sixteen scripts reference `CLAUDE.md`; none measures it. Part 3 adds 24 rules to that channel,
and nothing would notice if it doubled — a cost paid on every compaction of every session.

## G5 — 24 standing rules exist only in an untracked home directory

Including all of the operator's own standing rulings (D46), the wall-clock cost model (D42), the
KISS-applies-to-everything principle (D41), the finding-severity vocabulary (D45), and this
repo's resident-context discipline (D23–D25). `core/rules/ai-dlc-resident-discipline.md:7`
declares itself a duplicate of the **consumer's** SKILL.md Rule 23; this repo's own version has
no home.

## G6 — The two standing directives have no carrier

`grep -rniE "preapprov|ground.truth" scripts/validate-plan-shape.sh .claude/rules/` returns
nothing (control: `operator` appears 8 times in that script). The operator restates them per
prompt.

## G7 — Controlled vocabularies are single-sourced in data but have no reader-facing index

At least six invariants exist purely to keep one controlled vocabulary from being restated —
I39 (ledger statuses), I46 (extension kinds), I58 (`ADJUDICATED`), I70 (PR classes), I72 (PR-class
key set), I80 (the intensity set) — plus the closed `adjudication` enum in
`core/skills/ai-dlc/enforcement-map.yaml` and the verdict enum in
`core/schemas/layer-adjudication-register.json`. Each vocabulary is correctly owned by one file.
There is no place a reader can see all of them, and the invariants exist precisely because
people keep restating them from memory.

---

# Part 3 — Recommendations

## R1 — Topical unscoped rule files; `CLAUDE.md` becomes the index — RULED

The 24 homeless rules go into new files under `.claude/rules/` carrying **no `paths:` key**.
Measured loader semantics make that channel identical to `CLAUDE.md` — a rule file with no
`paths:` is re-injected on compaction (`load_reason:"compact"`) — while giving each topic its own
diff, its own review boundary and its own history. `CLAUDE.md` keeps the rules that govern
`CLAUDE.md` itself, the rules whose trigger cannot fire on its own, and a pointer per file
(arm A4 already forces the pointer).

New files: `verification-discipline.md`, `tool-hazards.md`, `consumer-boundary.md`,
`mechanism-design.md`, `resident-context.md`, `operator-rulings.md`.

**This makes "no `paths:`" ambiguous, and that must be closed in the same change.** Today an
absent `paths:` key can only be an accident, so nothing checks for it; after R1 it is also a
deliberate declaration. Require every rule file to carry exactly one of a `paths:` list or an
explicit `<!-- unconditional: <reason> -->` marker with a non-empty reason — the same discipline
`.dist-only` markers and `no-stub` reasons are already held to — and extend arm A3 to fail when
a file carries neither, or both. Without that arm, a rule file that lost its `paths:` line reads
exactly like one deliberately made resident, and the cost lands on every compaction.

**The budget covers the whole channel, not one file.** A ceiling on `CLAUDE.md` alone would be
evaded by the split. The new arm measures the sum of `CLAUDE.md` plus every unconditional rule
file.

**THE NEW FILES LAND INSIDE AN EXISTING BLOCKING AUDIT, AND THE SOURCE MATERIAL VIOLATES IT.**
`core/scripts/audit-rule-files.sh` — pre-push step 9 — scans `.claude/rules/` alongside the skill
tree. An embedded date is **tier-1 and blocks the push**; origin tags, version stamps and
`used to`-style narrative score as findings too. The 24 rules come from a memory corpus written
in exactly that register — nearly every cluster carries a release number, a date, or a sentence
about what something used to do. **Write each rule imperative-first with its evidence stripped,
and put the evidence in the CHANGELOG entry that lands it.** Measured on this plan's own first
attempt at `CLAUDE.md`: four dates took a 0-finding file to 4 tier-1 findings and blocked the
push. Budget the rewriting, not just the moving.

## R2 — A `docs/` artifact is right when it is DERIVED, and wrong when it is hand-written prose — RULED

The question is whether a project-level reference document is the correct home for any rule
content here. On the merits, for hand-written prose, it is not — for one reason, and the reason
is structural rather than incidental.

Every rule in this repo falls into one of two classes. **If it has an enforcer**, this repo has
already chosen the home for its explanation, and chosen it deliberately: the header of the guard
that enforces it. `CLAUDE.md §A check that cannot fire` states this — roughly a dozen files carry the rule locally, "in
the header of whichever guard learned it. Those statements stay where they are — each explains
its own guard." That choice is load-bearing, because a rule and its mechanism cannot drift apart
while they are the same file. A reference document holding the same content is copy #2 with no
join, which is D30 exactly. **If it has no enforcer**, then it is read only when something loads
it, and a file under `docs/` is loaded by nothing — not `paths:`-triggered, not re-injected at
compaction, not consulted before a Bash call. It is `CLAUDE.md` with the durability removed, and
arm A4 exists to forbid precisely that shape inside `.claude/rules/`.

There is no third class, so a hand-written `docs/` rulebook has nothing left to hold. Applied to
the specific candidate: `docs/coding-conventions.md`'s content splits with no residue — the
mechanizable half becomes `scripts/validate-shell-portability.sh` and lives in that script's
header (R3), the non-mechanizable half is a set of Bash-tool behaviours with **zero corpus** that
must be resident to be read at all (R1, `tool-hazards.md`). The basename collision with the
consumer artifact that `scripts/install.sh:354` writes is real, but it is not the argument; it
is a second reason arriving after the first has already settled it.

**A generated `docs/` artifact is right, and the repo already runs that pattern** —
`core/scripts/sync-taught-schema.sh --check` is pre-push step 1. Two belong there, both derived
and byte-compared, neither hand-edited:

- **`docs/invariant-index.md`** (R6) — closes G3.
- **`docs/vocabulary-index.md`** — closes G7. Rendered from the files that already own each
  controlled vocabulary (`core/schemas/*.json`, `core/skills/ai-dlc/enforcement-map.yaml`,
  `core/skills/ai-dlc/layer-contract.yaml`), never restating any of them. This is the artifact a
  glossary would have been, built so it cannot drift.

The same test disposes of the other absent conventional artifacts. `CONTRIBUTING.md`: its content
is already in `README.md:270-307` and it would be hand prose with no join. `AGENTS.md`: a second
copy of `CLAUDE.md` for other tools — right only as a generated copy with `--check`, and only
once a second tool is actually in use. `docs/architecture.md`: the enforcement map and
`layer-contract.yaml` are the machine-readable architecture; a prose one would drift.
An ADR directory: settled decisions are already recorded inline where they will be reopened —
`.claude/rules/fixture-ship-decl.md:39` is the pattern — and a third home would compete with the
CHANGELOG and the discharged plans. `.editorconfig` is the one artifact of a different kind
entirely, being machine-read config rather than prose; there is no measured formatting problem
here, so it is noted and not proposed.

## R3 — A new standalone `scripts/validate-shell-portability.sh`, not a rules file and not a map arm

**Not a path-scoped rules file:** over the last 200 commits, 323 distinct `.sh` files were ADDED
and 202 modified. Creation is a `Write`, which is measured not to fire the loader; modification
fires it once and it is gone after the first compaction; subagent loads never reach the parent.

**Not an arm inside `validate-enforcement-map.sh`:** that script is invoked by five of the six
slowest fixtures, and the repo's own measurement is 13.0s → 18.1s in the validator taking the
pole 442s → 595s — roughly **30s of gate wall clock per 1s of script**. A standalone pre-push
step costs ~1s serial.

Scope: D7's remainder, D8's `$( )` half, D10's bash-3.2 floor. Today's finding set over the
tracked shell corpus is **empty**, which makes each arm a pure regression guard and makes the
fixture the only evidence the arm works — so each arm ships with a self-probe that runs before
the corpus, in the shape at `scripts/validate-claude-rules.sh:29`.

## R4 — The two directives go to `operator-rulings.md`; only the checkable half becomes an arm — RULED

**"Merges are preapproved" gets no arm.** A strict grammar over the real corpus errors on **17
of 19** plans; the loose grammar matches all 19 and catches nothing. `CLAUDE.md §Before adding a check-209` forbids
shipping that. It is also a *grant by the operator*, not a required act by the executor, so there
is nothing in a plan file to check. It is stated once in the unconditional channel, where it
reaches every session and every subagent.

**"Everything sourced with ground truth" gets a structural proxy.** The phrase is unverifiable by
the file asserting it — a strict grammar errors on 18 of 19. The evidence is checkable: **9 of 19
plans carry zero resolving `path:line` citations and 7 carry no citation token at all**, and
every one is a clean P4 pass, because P4 checks only that citations resolve. That is this repo's
own zero-is-not-a-finding defect sitting inside its own plan validator. Ship:

- **P9** — a live plan must carry at least one resolving `path:line` citation.
- ~~**P10** — every plan is either live or banner-marked discharged.~~ **DROPPED on
  measurement, and the reason is worth keeping.** As written it is a tautology and cannot fire:
  a plan with no banner is simply classified live. Reshaped into a predicate that CAN fire — a
  discharge marker exists but is BURIED below the head window — its only hit on the corpus is a
  live plan whose inventory table describes other plans as spent, which is precisely the shape
  that recurs. And the genuinely dangerous case, a spent plan carrying no marker anywhere, is
  undetectable by construction. The arm would buy a false positive in exchange for the easy half
  of the problem. Live-detection is folded into P9's scoping instead, where it needs no arm of
  its own.

**The authoring-time half cannot be closed and is not faked.** A new plan is written to
`~/.claude/plans/<slug>.md`, where no validator can see it; `CLAUDE.md §Some authoring rules live in .claude/rules/-164` records why. A
`docs/plans/` arm fires only at promotion. The carrier that does reach authoring time is the
unconditional channel, which is why R4 puts both directives there first and treats P9/P10 as the
audit rather than the delivery.

## R5 — Repair G1 and G2 by edit; bind only what has a non-empty corpus

**DONE.** Both `I88` citations now name `scripts/validate-claude-rules.sh` arms A1–A4, matching
the correction already at `CHANGELOG.md:969`; the stale fixture count and home-plan count are
gone; `CLAUDE.md §Prohibitions need mechanisms` points at `docs/invariant-index.md`.

**Arm A5 still to build**: every `I<n>` cited in **bold** in `CLAUDE.md` or any rule file must
name an ID the index lists. The bold form is the file's own pre-existing convention for "this is
the live mechanism" — backticks mark a literal token under discussion — and it predates this
work (`git show 5f57940:CLAUDE.md`). Measured over that pre-fix file the arm fires on exactly
`I88`, with `I33` and `I66` resolving as live controls: **one true positive, false-positive set
empty**. A5 consumes `docs/invariant-index.md` rather than re-deriving, so there is one
extractor; the index is byte-compared at an earlier pre-push step, and A5 fails closed if it is
missing.

Do **not** add a P4-style `path:line` arm over `CLAUDE.md`. It carries exactly two such citations
and both resolve, so the arm ships green forever and neither real defect is of that shape — the
check-that-cannot-fire class the file names at `CLAUDE.md §A check that cannot fire`.

**CORRECTION — dating the frozen measurements is not available, and this plan was wrong to
propose it.** `core/scripts/audit-rule-files.sh` scans `CLAUDE.md` and treats an embedded date as
a **tier-1, push-blocking** finding. Adding dates took that file from a 0 tier-1 baseline to 4 and
blocked the push. The remaining form with an empty FP set is therefore **removal, not dating**:
delete the decaying number, write the derivation command in its place, and leave the measurement
in the CHANGELOG, which is outside the audit corpus. A number that is not there cannot go stale.
A generated region in `CLAUDE.md` is still open as a later option, but it is not needed for any
figure currently in the file.

## R6 — Two generated indices, derived from markers or not at all

`scripts/render-invariant-index.sh` → tracked `docs/invariant-index.md`, and
`scripts/render-vocabulary-index.sh` → tracked `docs/vocabulary-index.md`, each with a
byte-comparing `--check` wired into `.githooks/pre-push` beside the existing
`sync-taught-schema.sh --check`. Then repoint `CLAUDE.md §Prohibitions need mechanisms` at the invariant index.

Two constraints decide whether the invariant index ships at all. It must derive from **a marker
the arms themselves carry**, never from the `OK:` line's prose — rendering the summary sentence
would freeze the nine-ID gap and stamp it authoritative, which is worse than today's visible
ambiguity. And the extractor must be probe-armed before it renders, proving it finds a seeded
emit site in each `err` call shape and in a Python sub-program, and that it does not find a
decoy. If the derivation cannot be made total, ship nothing.

## R7 — The memory corpus: standing rules move, dated episodes stay

The 46 clusters are the worklist and Part 1C is the placement. Dated episodes stay where they
are; do not bulk-import 213 files into `docs/`, which already holds 78 tracked files of which
none is a live rulebook. Add a one-line pointer in `CLAUDE.md` naming the corpus path, so a
stranger can find the evidence behind a rule.

The corpus sits outside the tree the gate hashes, so **no pre-push hook can ever reach it**. The
only seam is a PostToolUse hook in the operator's home — the same unversioned, warning-strength
mechanism as the existing home-plans warning, and it is labeled as such.

## R8 — Five conventions the inventory surfaced that nothing above covers

Each has a live corpus and no general statement anywhere. All go to `verification-discipline.md`.

1. **Every arm carries a self-probe that runs before the corpus** —
   `scripts/validate-claude-rules.sh:29`: an arm reporting zero findings without first proving it
   can produce one has established that it ran, not that the corpus is clean. This is the repo's
   most-repeated rule and it has no general home.
2. **How a false-positive set was taken to zero is part of the arm.** A new arm with no narrowing
   story is unfinished.
3. **Resolve the repo root by walking up for a marker, never by counting `..` hops** — so a
   validator answers identically from the repo root and from a fixture sandbox.
4. **A glob that matches nothing must not report success** — `scripts/validate-plan-shape.sh:47`.
5. **A calibration is a property of its text, not of its divisor** — a bytes-per-token figure
   measured on one population under-counts on another, and was carried backwards for four
   releases.

---

# Part 4 — The closed action list

**All three CLOSED at `v0.366.0`.** They are kept in their numbered form, marked done, because
a plan that deletes its actions on completion leaves a reader unable to tell a finished item
from one that was never written. "Working this repo" below carries what the waves cost to learn.

1. **DONE — `scripts/render-vocabulary-index.sh` → tracked `docs/vocabulary-index.md`**, with
   `core/fixtures/vocabulary-index/` (`.dist-only`, 2 controls and 11 mutants) and a pre-push
   step beside the invariant index. Seven cross-file vocabularies and four schema enums.
   **THIS ACTION'S OWN SOURCE LIST WAS WRONG, and the measurement is what changed the design.**
   It said to derive each vocabulary from `core/schemas/*.json`, `enforcement-map.yaml` and
   `layer-contract.yaml`. Measured against the arms, only I58's owner is one of those three
   (`core/skills/ai-dlc/layer-contract.yaml:593`): I39's is the `emit` literals at
   `core/skills/ai-dlc-update/reconcile/ledger-reverify.sh:235`, I46's is the `LAYER_KINDS`
   assignment at `core/scripts/validate-layer-entries.sh:548`, I72's is the `case` at
   `core/scripts/validate-cycle-commits.sh:217`, I80's is Rule 8's table at
   `core/skills/ai-dlc/SKILL.md:207`, I30's is the sentinel block at `.githooks/pre-push:640` — and
   **I70's owner is not in this tree at all**, being the consumer's own taxonomy read through
   `git show`. So the population is declared by a `# vocabulary:` marker on each arm rather than
   by a fixed list of source files, and the consumer-owned one carries a reason instead of
   members. The totality bar the action set was met on the declared population, in three
   directions, and the arm that keeps that population from going stale is a prose check on arm
   headers whose false-positive set was measured empty before it shipped.
2. **DONE — full-suite wall clock recorded.** `AI_DLC_FIXTURE_NO_SKIP=1 bash .githooks/pre-push`
   from inside the repo: **581s, exit 0, 147 fixtures**, both skips disabled. In the CHANGELOG,
   not in `CLAUDE.md`. The suite is pole-bound, so the ~0.4s step this release adds moves the
   total by its own cost and nothing else.
3. **DONE — Wave E, the home-directory carriers**, in the form operator decision 3 settled.
   `~/.claude/hooks/plan-outside-repo-warn.sh` now restates both standing directives verbatim at
   plan-authoring time, where `.claude/rules/operator-rulings.md` cannot reach; and a sibling,
   `~/.claude/hooks/memory-write-placement-warn.sh`, fires on any write under a per-project
   memory corpus carrying R1's three-clause placement test and the prose-only-rules-are-never-
   scoped clause. Both are registered in the home `settings.json`, both probed in both
   directions, both WARNINGS and neither a gate. **Neither is versioned anywhere and neither
   reaches a consumer** — that is the ruling, not an omission.

## Completed and merged

| Release | What landed |
|---|---|
| `acd1771` | This plan promoted into `validate-plan-shape.sh`'s corpus. |
| `v0.361.0` | `render-invariant-index.sh` + `docs/invariant-index.md` + its fixture + pre-push step; the `OK:` line's 12,243-char hand-list replaced; I1/I2 and I17 declared; `I76`/`I91` split; `CLAUDE.md`'s `I88` citations and stale counts repaired; `validate-no-dead-doc-refs.sh` rescoped off `.dist-only`. |
| `v0.362.0` | Arms A5 (bold invariant citations resolve), A3b (scope declared exactly once), A6 (durable-channel byte ceiling); `claude-rules-joins` extended to 11 mutants. |
| `v0.363.0` | The six unconditional rulebooks under `.claude/rules/` carrying the 24 homeless rules; `CLAUDE.md`'s placement test gained its third clause; `fixture-mutants.md` gained three clauses; memory-corpus pointer added. |
| `v0.364.0` | `validate-shell-portability.sh` (7 arms, 325 files, ~0.5s) + its fixture + pre-push step; `tool-hazards.md` reduced to citing it. |
| `v0.365.0` | Arm P9 — a live plan carries at least one resolving citation; `plan-shape` fixture extended both directions. |
| `v0.366.0` | `render-vocabulary-index.sh` + `docs/vocabulary-index.md` + `vocabulary-index` fixture + pre-push step; `# vocabulary:` markers on seven arms; the full-suite wall clock; Wave E's two home-directory carriers. |

**Three proposed arms were DROPPED on measurement, and they are not pending work.** A bare
`sed -i` scan (4 hits, all 4 correct), an `awk -v` backslash scan (1 hit, correct, and the
correct and incorrect forms are the same shape to a regex), and **P10** (a tautology as written;
reshaped, its only hit is a live plan whose table describes others as spent, while the dangerous
case is undetectable by construction). Do not rebuild them.

## Working this repo — what the finished waves cost to learn

- **One release per branch, cut from `origin/main`, merged in order.**
  `validate-release-version.sh` refuses a branch adding two CHANGELOG headings, because a squash
  takes the first version in the subject and the rest become unattributable.
- **`git push` is the gate**, and the full suite is roughly nine minutes. Background it. The
  content key skips an unchanged tree and the read-set map narrows to affected fixtures; both are
  correct, and neither is evidence your change was exercised. Verify a release with
  `AI_DLC_FIXTURE_NO_SKIP=1`.
- **`core/git-hooks/pre-push` is the CONSUMER's hook.** Run here it prints a green banner having
  executed almost nothing. The distribution's gate is `.githooks/pre-push`.
- **Rule prose under `.claude/rules/` and `CLAUDE.md` is inside `audit-rule-files.sh`.** Version
  tags, `S`-prefixed sprint ids and ISO dates are tier-1 and BLOCK the push. Backticked spans,
  quoted spans, fenced code, HTML comments and frontmatter are exempt. Provenance goes in the
  CHANGELOG.
- **`docs/invariant-index.md` is generated.** Change the arm header and re-run the renderer.
- **A `git ls-files` corpus cannot see an uncommitted file**, so a local run before the commit
  and the gate's run after it are over different corpora. That is how the shell-portability
  validator came to flag its own mutation battery only at push.
- **`I54b` will catch a piped first-match reader**, and it caught three in this program written by
  an author who had the rule in front of them. Use here-strings.
- **The durable-channel ceiling was raised once already.** Raising it again to admit new prose is
  how the guard becomes decorative; mechanize or scope a rule out of the channel first.

## Verification

Corrected against what was actually built. **Every criterion is now MET**; the two that were
outstanding at handoff were closed by actions 1 and 2 above.

- `bash scripts/validate-claude-rules.sh` passes with A3b, A5 and A6 live; `I88` appears nowhere
  in `CLAUDE.md` as a live mechanism; `core/fixtures/claude-rules-joins/run.sh` proves all eleven
  mutants die by their own arm. **MET.**
- `bash scripts/validate-plan-shape.sh` passes over the whole corpus with P9 live, and
  `core/fixtures/plan-shape/run.sh` proves P9 fires on a live plan with no citation and stays
  silent on a banner-marked one. **MET.** (P10 is not part of this criterion; it was dropped.)
- `bash scripts/validate-shell-portability.sh` runs clean and its fixture proves every arm fails
  when mutated, plus two negatives. **MET.**
- `scripts/render-invariant-index.sh --check` passes and the index names every ID the extractor
  proves can fire. **MET.**
- `scripts/render-vocabulary-index.sh --check` passes, its population is bound in three
  directions, and `core/fixtures/vocabulary-index/run.sh` proves eleven mutants each die by
  their own arm. **MET.**
- No stale derivable count survives in `CLAUDE.md`. **MET BY REMOVAL, NOT BY GENERATION** — the
  audit blocks dates in rule prose, so the count was deleted and the derivation command written
  in its place. A generated region in `CLAUDE.md` remains available and is not currently needed.
- Every rule file loads: A2/A3/A3b/A4 pass and A6 counts all seven durable files. **MET.**
- `git push` green end to end, from the repo root, suite through its pool, no hand-rolled loop.
  **MET** — five releases, and a final `AI_DLC_FIXTURE_NO_SKIP=1` run of 147 of 147 fixtures.
- Timing before and after for `validate-enforcement-map.sh` (14.27s → 14.68s). **MET.**
- Full-suite wall clock recorded: **581s, exit 0, 147 fixtures**, both skips disabled, timed
  from inside the repo. **MET.**

## Operator decisions

1. **RULED.** The invariants named on the `OK:` line versus those that can fire — the operator
   ruled that the line is DERIVED rather than hand-maintained, which moots the per-ID judgment.
   Discharged by R6.
2. **RULED — hold the durable-channel ceiling at 40,960 and change nothing.** Measured at the
   time of the ruling: the channel was **38,950 bytes across 7 files**, 2,010 of headroom. The
   ruling follows the arm's own stated order at `scripts/validate-claude-rules.sh:275` — when A6
   fires, the first question is what can be MECHANIZED or SCOPED out, and raising is the last
   resort. It has not fired. A pre-emptive prose cut is separately forbidden by
   `.claude/rules/resident-context.md`, which says rule text here is not trimmed for byte cost;
   and lowering the number now would have fired the arm on the next ordinary pointer rather than
   on a rule anyone examined. **Derive the current figure from the A6 line, never from this
   sentence.**
3. **RULED — do NOT widen arm A1, and Wave E's carriers stay in the home directory,
   unversioned.** The decisive measurement is that **A1's own probe seeds `.claude/settings.json`
   as its offender** (`scripts/validate-claude-rules.sh:95`), and a repo-local hook needs its
   registration in exactly that file — so admitting it breaks the probe and reopens the
   containment the `.gitignore` narrowing exists to hold. Admitting `.claude/hooks/**` alone
   yields a tracked copy nothing executes, with the executing copy still in the home directory:
   two files, no join, which is D30. So the affordance was not created. Action 3 shipped in the
   only form that runs.
4. **RULED — all three KEEP clusters stay in the memory corpus.** D26 is not homeless: its
   authoring error is already mechanized by `core/skills/ai-dlc-update/reconcile/ledger-reverify.sh:1`
   and `core/fixtures/ledger-reverify-unfalsifiable/run.sh:1`, whose README names the canonical
   form, so "cite, do not restate" applies. D33 and D35 are prose-only, and `CLAUDE.md` forbids
   scoping a prose-only rule because scoping deletes it from every session that has compacted
   once — even though their globs would be non-empty (`core/skills/ai-dlc-update/**` is 26
   tracked files, `core/hooks/**` is 7) and pull-runbook delegation measured near zero, at 2 of
   12 files with one hit each. That left only the durable channel, against 2,010 bytes of
   headroom, for rules that bind the consumer-pull workflow rather than authoring in this repo.
