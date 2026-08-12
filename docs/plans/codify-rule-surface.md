# Codify the effective rule surface of ai-dlc

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

**This file is the handoff**, and it is promoted: it lives at
`docs/plans/codify-rule-surface.md` and is inside `scripts/validate-plan-shape.sh`'s corpus.

## Status

Action 1 complete — this file is promoted and committed. Nothing else implemented. Inventory and
gap analysis complete and measured. Three operator rulings are already taken and are folded into
Part 3: topical unscoped rule files (R1), no `docs/coding-conventions.md` (R2), prose plus a
structural proxy for the two standing directives (R4). Wave A is next.

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
| `scripts/validate-enforcement-map.sh:6181` | The invariant registry. **80 IDs can fire**; its final `OK:` line names **71**. |
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

`.githooks/pre-push:88` runs the resident-size budget, and
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
- **P10** — every plan is either live or banner-marked discharged. This scopes P9 by construction
  rather than by exemption, and it mechanizes D43's banner rule. All 19 plans satisfy P10 today,
  so both its FP set and its backlog are empty. The banner may sit below line 1
  (`docs/plans/v0357-gate-remediation-delegation.md` carries it at line 6), so the arm windows
  the head rather than testing line 1.

**The authoring-time half cannot be closed and is not faked.** A new plan is written to
`~/.claude/plans/<slug>.md`, where no validator can see it; `CLAUDE.md §Some authoring rules live in .claude/rules/-164` records why. A
`docs/plans/` arm fires only at promotion. The carrier that does reach authoring time is the
unconditional channel, which is why R4 puts both directives there first and treats P9/P10 as the
audit rather than the delivery.

## R5 — Repair G1 and G2 by edit; bind only what has a non-empty corpus

Edit `CLAUDE.md §Some authoring rules live in .claude/rules/` and `:159` to name `scripts/validate-claude-rules.sh` arms A1–A4, matching
the correction already at `CHANGELOG.md:969`. Edit `:65` to 147 and `:148` to 58.

Add **arm A5**: every `I<n>` token cited in `CLAUDE.md` or any rule file must name an ID that can
fire. Measured today it fires on exactly `I88`, with control `I74` resolving — one true positive,
false-positive set empty.

Do **not** add a P4-style `path:line` arm over `CLAUDE.md`. It carries exactly two such citations
and both resolve, so the arm ships green forever and neither real defect is of that shape — the
check-that-cannot-fire class the file names at `CLAUDE.md §A check that cannot fire`.

For the figures, no arm can separate the three genres present: derivable counts, frozen
historical measurements that must never be re-derived, and invariant facts. The form with an
empty FP set is **generation plus explicit dating** — a generated region for the derivable
counts, and a one-time pass dating the ~8 historical measurements.

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

# Part 4 — Actions

Waves A, B and C are independent of each other. Wave D depends on A. Merges are preapproved
throughout.

1. Promote this file to `docs/plans/codify-rule-surface.md` and commit it, so
   `scripts/validate-plan-shape.sh` has it in corpus. Run the validator and report its output.

**Wave A — bind the rule surface to ground truth**

2. Build the invariant ID → emit-site extractor with its self-probe first. Prove it fires on a
   seeded `err "I…"`, on `|| err`, on `&& err`, on a multi-line message, and on the heredoc'd
   Python sub-program inside `scripts/validate-enforcement-map.sh`; prove it does not fire on a
   comment-only decoy. Ping the operator with the probe output and the firing-ID set before
   proceeding.
3. Add arm A5 to `scripts/validate-claude-rules.sh` consuming that extractor, with a self-probe
   that injects a nonexistent ID into a temp copy. Extend `core/fixtures/claude-rules-joins/` to
   prove A5 can fail, capturing red → green against the live `I88` defect.
4. Extend arm A3 to require exactly one of `paths:` or a non-empty
   `<!-- unconditional: <reason> -->` marker per rule file, with probes in both directions.
5. Add the durable-channel byte-ceiling arm (R1), measuring `CLAUDE.md` plus every unconditional
   rule file, with its fixture. Report the current total and propose a ceiling; the value is an
   OPERATOR DECISION.
6. Edit `CLAUDE.md §Some authoring rules live in .claude/rules/`, `:159`, `:65`, `:148` per R5, and date the ~8 frozen historical
   measurements in place.
7. Build `scripts/render-invariant-index.sh` per R6, its fixture and its pre-push wiring, then
   repoint `CLAUDE.md §Prohibitions need mechanisms`. If action 2's extractor cannot be made total, stop here and ping the
   operator rather than shipping a partial index.
8. Build `scripts/render-vocabulary-index.sh` and `docs/vocabulary-index.md` per R2/G7, deriving
   each vocabulary from the file that owns it. Add its fixture and pre-push wiring.

**Wave B — the shell-portability validator**

9. Write `scripts/validate-shell-portability.sh` covering D7's remainder, D8's `$( )` half and
   D10's bash-3.2 floor. Each arm self-probes before its corpus. Report the finding set and the
   false-positive set over the tracked shell corpus before wiring anything.
10. Add its fixture proving each arm can fail, and wire it as a new `.githooks/pre-push` step.
11. Time the step from inside the repo, before and after, and report both numbers. Confirm
    nothing was added to `scripts/validate-enforcement-map.sh`.

**Wave C — plan-shape arms**

12. Add P10 (live-or-banner-marked), deriving the banner grammar from all 19 plans and windowing
    the head rather than testing line 1.
13. Add P9 (a live plan carries at least one resolving citation), scoped by P10.
14. Extend `core/fixtures/plan-shape/` to prove P9 and P10 can each fail. Report both
    false-positive sets over `docs/plans/*.md` before wiring; if either is non-empty, stop and
    ping the operator.

**Wave D — the prose**

15. Create the six unconditional rule files per R1, each with an `<!-- unconditional: reason -->`
    marker and a `CLAUDE.md` pointer, and write the 24 homeless rules into them per Part 1C.
16. Add R8's five conventions to `verification-discipline.md`.
17. Add the third clause to the placement test at `CLAUDE.md §Some authoring rules live in .claude/rules/-108` — *and no subagent needs
    it* — and rewrite that section to describe three channels rather than two.
18. Extend `.claude/rules/fixture-mutants.md` with D16's different-author clause and D17's
    tree-must-express-the-defect clause.
19. Add the one-line memory-corpus pointer (R7).
20. Report the resulting durable-channel total against the ceiling from action 5. Triage of what
    to compress or drop is an OPERATOR DECISION.

**Wave E — the seams that cannot be versioned**

21. Extend the existing home-directory PostToolUse warning to carry both standing directives
    verbatim, and add a sibling for writes under the memory directory carrying R1's placement
    test. Label both as warnings, not gates.

## Verification

- `bash scripts/validate-claude-rules.sh` passes with A3-extended, A5 and the ceiling arm live;
  `I88` no longer appears in `CLAUDE.md`; `core/fixtures/claude-rules-joins/run.sh` proves each
  new arm fails when mutated.
- `bash scripts/validate-plan-shape.sh` passes over all 19 plans plus this one with P9 and P10
  live; `core/fixtures/plan-shape/run.sh` proves both fail when mutated.
- `bash scripts/validate-shell-portability.sh` runs clean, and its fixture proves each arm fails
  when mutated.
- Both renderers pass `--check`, and `docs/invariant-index.md` names every ID the extractor
  proves can fire.
- `CLAUDE.md §Run the fixture suite`'s fixture count comes from the generated region and equals
  `find core/fixtures -mindepth 1 -maxdepth 1 -type d | wc -l`.
- Every new rule file loads: confirmed by A2/A3/A4 passing and by the ceiling arm counting it.
- `git push` is green end to end. Run it from the repo root so the hook drives the suite through
  its pool; do not hand-roll a fixture loop.
- Timing reported before and after for `validate-enforcement-map.sh` and for the full suite,
  measured from inside the repo, loaded figures never compared against solo ones.

## Operator decisions

1. **The nine firing-but-unnamed invariant IDs** — I15, I16, I17, I18, I33c, I77, I78, I79, I80.
   Whether each is a missing entry, a retired arm, or a mis-scoped ID is a judgment about the
   invariants themselves, not about rendering. Action 2 reports; the ruling is yours.
2. **The durable-channel ceiling value**, and what gets compressed or dropped once Wave D lands.
3. **Whether to widen arm A1** to admit a tracked `.claude/hooks/` subtree, so the Wave E carriers
   can be versioned. This reopens the containment A1 exists to hold.
4. **The three KEEP clusters** — D26 receipt anchoring, D33 consumer-mechanism absorption, D35
   PreToolUse enforcement design. Each is consumer-workflow rather than repo-authoring; they can
   stay in memory or become a path-scoped rule file over the consumer-pull runbook paths.
