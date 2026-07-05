# Consumer-sync mechanism — the missing distribution→consumer pull path (design record)

Status: **PROPOSED**. Provenance: the v0.13.0/v0.14.0 consumer-absorption arc
surfaced the asymmetry — ai-dlc has a working *push* path (consumer→distribution)
but no repeatable *pull* path (distribution→consumer). This record specs the pull
path and the architecture that keeps it cheap.

## 1. The catch-22

ai-dlc is designed to **self-improve inside a consumer project**: a consumer
accumulates operational innovations sprint-over-sprint (graph: 280+ sprints). Two
directions of value flow result, and only one has a mechanism:

- **Push (consumer→distribution) — HAS a mechanism.** Mine the consumer's
  generalizable innovations, de-graph them, backport to distribution. This is the
  absorption arc (v0.4.1, v0.4.2, v0.11.0, v0.13.0, v0.14.0). Manual but repeatable.
- **Pull (distribution→consumer) — LACKS a mechanism.** When distribution gains a
  feature (its own, or a generalized innovation round-tripped from *another*
  consumer), there is no repeatable way to bring it into a consumer that has
  diverged. Today this is done two bad ways:
  1. **`install.sh` — a two-way overwrite.** `install.sh:159` unconditionally
     overwrites `SKILL.md`, `steps/*.md`, `team-roles/*.md`, etc. It archives the
     consumer's current rulebook to `docs/pre-ai-dlc/<ts>/_divergence/` first
     (recoverable) but replaces the live tree wholesale — destroying the
     consumer's divergence, domain machinery and un-pushed innovation alike.
  2. **Ad-hoc custom prompts.** How graph was actually brought to ~v0.10:
     hand-written, per-release "apply these changes to your ai-dlc" prompts driving
     an agent. Not base-aware, not repeatable, not conflict-surfacing; drifts a
     little every time. This is the practice the tool formalizes.

Because neither pull path preserves divergence *and* reconciles upstream, consumer
self-improvement can only accumulate, never reconcile. An un-reconcilable consumer
degrades into what looks like a hard fork (graph's rulebook is 2–3.7× distribution)
even though it was never meant to be one.

**This is the general consumer problem, and graph is its worst case — not a
special case.** Every ai-dlc consumer that self-improves diverges; the value of a
pull path scales with divergence. A fresh install (no divergence) is served fine by
`install.sh` today. A lightly-diverged consumer needs a cheap reconcile. Graph
(stamped v0.10.0, then 280+ sprints of un-pulled self-improvement, 2–3.7× bulk) is
the maximum-divergence stress test. The design below is written consumer-general and validated against graph as
the hard end; a cleanly-stamped consumer travels the same path with less friction
at every phase (Phase 0 free, Phase 1 near-fast-forward, Phase 2 a small override
set). Two properties make it genuinely multi-consumer rather than a graph patch —
the layer-aware authoring guard (§7) and the fan-in push story (§8) — both called
out where they land.

## 2. Diagnosis: base-less overwrite where a three-way merge is needed

A consumer rulebook is `upstream_base + local_divergence`. When upstream moves
`base → base'`, the correct result is `base' + local_divergence`, with conflicts
surfaced only where both edited the same region. That is a **three-way merge** —
git's exact job, given the merge-base.

`install.sh` performs a **two-way** operation (theirs-wins overwrite; the recorded
base is never consulted at update time), so clobber is the only outcome. The
custom-prompt path is also base-less — it applies a delta the prompt author
remembered, not a computed diff from a recorded base.

Plain `git merge-file` cannot substitute directly: the rulebook is **prose**, and
consumer divergence is frequently *reworded* forms of the same concept (v0.13.0
spec §1). A line-based merge would false-conflict on nearly every block. The thing
that makes prose three-way tractable is **semantic classification** — which ai-dlc
already has as agents (the arc's 6-agent per-block classifier). This is why the
pull path is an ai-dlc-shaped problem, not a git-config one.

## 3. Assets already in place (build on, don't reinvent)

- **Merge-base stamping** — `install.sh` writes `.claude/.ai-dlc-version` (version
  + upstream sha + timestamp); `check-version.sh` reads it. The stamp *is* the
  merge-base pointer; it is simply never used at update time. (Graph *has* a valid
  one — `0.10.0 @ 2271942` — it is just never consulted on update; see Phase 0.)
- **The reconcile engine** — the arc's per-block semantic classifier
  (ALREADY-UPSTREAM / BACKPORT-WORTHY / GRAPH-LOCAL). A three-way reconcile is the
  same engine run pull-direction.
- **An override precedent** — `install.sh:250` already three-way-merges
  `settings.json` ("ai-dlc hooks upserted; user config preserved") instead of
  overwriting. The pattern to generalize from settings to the rulebook exists.
- **The `_divergence/` archive + referenced "export tool"** — install already
  preserves consumer drift under a path-mirrored layout expressly so a tool can
  diff it against installed upstream. The diff-against-upstream scaffold is started.
- **Prior art for semantic apply** — the graph→v0.10 custom prompts. Proof that
  agent-driven application of an upstream delta into a diverged consumer works; the
  tool makes it base-aware and repeatable.

## 4. Divergence taxonomy (what the reconcile must distinguish)

Every consumer block that differs from upstream falls into one of four buckets. The
correct pull action differs per bucket — this is the classifier's output space:

| Bucket | Meaning | Pull action |
|--------|---------|-------------|
| **Rewording** | same concept, different prose; already-upstream in substance | take upstream (drop the consumer rewording — it round-trips via push if better) |
| **Domain-local** | consumer-specific machinery upstream intentionally lacks (graph §5: financial/ECS/subgraph checks, execution-health floors) | keep consumer's; layer upstream's non-conflicting additions around it |
| **Un-pushed innovation** | generalizable improvement not yet absorbed upstream | keep consumer's; **flag for push** (feeds the absorption arc) |
| **Genuine conflict** | consumer and upstream both changed the same core rule incompatibly | operator adjudicates |

The arc's finding — most of graph's divergence is *rewording* of already-upstream
content — predicts the common case is cheap (take-upstream), and the expensive
cases (domain-local, conflict) are the minority. That is what makes an automated
pull viable rather than a per-release prompt.

## 5. Phase 0 — establish the merge-base

Prerequisite for any three-way merge: the consumer's `.ai-dlc-version` stamp. For a
cleanly-installed consumer this is present by construction.

**Graph already has a valid stamp** — `0.10.0 @ 2271942` — and `2271942` is a real
distribution commit (`feat(v0.10.0): KISS minimum-mechanism principle + consumer
absorption`, #19, 2026-06-12). So Phase 0 for graph is **validate, not
reconstruct**: the merge-base exists and is honest.

- **Pull merge-base = the stamp = `2271942` (v0.10.0).** This is the last upstream
  content graph *received*. The custom-prompt v0.10 apply also stamped it, so the
  stamp is truthful about the baseline.
- **Do not confuse it with the push diff-base.** The absorption arc diffed
  graph@S281 against distribution@v0.11.0 (`e7ccffa`) to *mine innovations up* —
  that is a different reference point for a different direction. Pull uses the
  stamp (`2271942`); push used `e7ccffa`.
- **Upstream delta to reconcile = `2271942..HEAD` = 12 commits = v0.10.0→v0.14.0**
  (v0.11.0, v0.12.0, v0.13.0, v0.14.0). Much of that — v0.13.0/v0.14.0 — was itself
  mined *from* graph, so it classifies heavily into the cheap rewording /
  already-present bucket (§4), not conflicts. v0.11.0 folded graph's S281 delta;
  v0.12.0 is structural resident-slimming. The gap is more tractable than
  12-commits suggests.
- **The divergence the pull is actually for:** graph's stamp records v0.10.0, but
  graph self-improved 280+ sprints since **with no upstream pull** — the entire
  v0.11→v0.14 window never reached it. `ours` (graph live) = the v0.10.0 base +
  that un-pulled self-improvement. That accumulation is precisely what the
  three-way reconcile is designed to preserve while applying the upstream delta.
- **Action:** none required to establish the base — the stamp is valid and
  validated. Phase 1 runs directly with `base = 2271942`, `theirs = HEAD`,
  `ours = /Users/n8/git/graph`.

## 6. Phase 1 — `ai-dlc update`: the semantic three-way bridge tool

Formalizes the custom-prompt practice into a repeatable, base-aware reconcile.
Works on the tangled tree **today**, no refactor required.

**Inputs (three-way):**
- `base` = distribution `core/` at the consumer's stamped sha
- `theirs` = distribution `core/` at HEAD (target version)
- `ours` = the consumer's live `.claude/` rulebook

**Procedure:**
1. Enumerate blocks changed `base→theirs` (upstream delta) and blocks changed
   `base→ours` (consumer delta).
2. **Upstream-only** (changed upstream, untouched by consumer) → apply.
3. **Consumer-only** (changed by consumer, untouched upstream) → keep.
4. **Both changed** → semantic classify (§4) and act: rewording→take theirs;
   domain-local→keep ours + layer theirs' additions; un-pushed innovation→keep ours
   + emit a push-candidate note; genuine conflict→present both to the operator.
5. Emit a **dry-run report first** (per-block bucket + proposed action + conflict
   list) for operator review; apply only on confirm.
6. On apply, re-stamp `.ai-dlc-version` = HEAD sha; write a reconcile log.

**Engine:** the arc's per-block classifier, run pull-direction. Same agents, same
buckets. **Adjudication:** only genuine conflicts reach the operator — the common
rewording case is automatic. **Safety:** dry-run + the existing `_divergence/`
archive give a full recover path; nothing is destroyed.

### 6.1 Packaging — a consumer-side skill, sibling to `ai-dlc-setup`

`ai-dlc update` is **its own skill**, not a script and not folded into the pipeline
`ai-dlc` skill. Rationale:

- **It is semantic orchestration, not a copy.** The reconcile is per-block agent
  classification + operator conflict-adjudication + apply — skill territory
  (multi-step, model-driven, agent dispatch). `install.sh` stays the dumb-copy path;
  update is the smart path. A bash `ai-dlc-update.sh` could only shell out to the
  classifier, which *is* the skill.
- **It is a lifecycle/meta operation, like setup.** The project already separates
  meta-operations on the rulebook (`ai-dlc-setup` = onboard a project *into*
  ai-dlc) from the operating pipeline (`ai-dlc` = run sprints). Update = reconcile
  upstream *into* the project — the same class. Clean lifecycle triad: **setup
  (onboard) · ai-dlc (operate) · update (reconcile).**
- **It stays out of resident context.** The pipeline `SKILL.md` is under first-5K
  re-attach pressure (v0.12.0 slimming). Update runs rarely → a separate
  JIT-loaded skill, never resident bloat.

**Sidedness — the skill runs on the side it writes to.** This is the principle that
places it:

- **Pull / update** writes the *consumer* → **consumer-side skill**, installed into
  the consumer's `.claude/skills/ai-dlc-update/` exactly like `ai-dlc-setup`, and
  invoked from the consumer (`/ai-dlc-update`).
- **Push / absorption** writes *distribution* (it produces a distribution PR — this
  is how the v0.13/v0.14 arc ran, from the distribution checkout) → a
  distribution-side operation.

They legitimately run from opposite sides because their output lands on opposite
sides. **Nothing is ever "installed into distribution"** — distribution stays pure
source. (An earlier draft's "distribution-side update skill" was wrong: it blurred
source vs. operated-project. Corrected here.)

**How the consumer-side skill gets its three inputs** (the one new mechanic vs
setup, which is consumer-only):

- `ours` = the local tree (cwd). Trivial.
- `base` + `theirs` = fetch upstream. The consumer's `.ai-dlc-version` stamp already
  records the base sha (`2271942` for graph); the skill fetches distribution (git
  remote or configured upstream), then reads `base = git show <stamp-sha>:core/…`
  and `theirs = git show <HEAD>:core/…`. Identical in spirit to any vendored-dep
  updater — `npm update` / `brew upgrade` run *in your project* and reach the
  registry; you do not go to the registry and point it back at your machine.

**Shared engine, thin orchestrator.** The per-block classifier is NOT owned by
`ai-dlc-update` — per §8 it serves four jobs. It lives as a shared reconcile
component; `ai-dlc-update` is the pull *entry point* that calls it. Keeps push,
Phase-2 untangle, and fan-in able to reuse the same engine.

**Two gaps to close in implementation:**

- **Upstream ref is not recorded.** The stamp holds version + sha but not the
  distribution *URL*. Update needs to know where upstream lives — extend
  `.ai-dlc-version` (or a sibling config) to carry the upstream git ref.
- **Self-update bootstrapping.** The update skill lives in the consumer and can
  update itself. Standard handling: it treats its own skill files as `core/`
  (overwrite-safe) and applies its own new version last (or re-execs). Not a
  blocker, but call it out so the apply order is deliberate.

### 6.2 Bootstrap — landing `ai-dlc-update` without a full install

Chicken-and-egg: the tool that lands upstream changes *safely* must itself first
be landed by some *other* means, because it is not present yet — and the only
existing landing mechanism, `install.sh`, is the blunt full-rulebook overwrite this
whole design exists to avoid. So the first install of `ai-dlc-update` cannot go
through `install.sh`.

**Mechanism: a file-scoped additive copy.** `ai-dlc-update` is a **net-new
directory** in the consumer (`.claude/skills/ai-dlc-update/`) — a diverged consumer
does not have it. Copying *only that directory* (plus the shared reconcile-engine
directory, if the classifier lives separately — also net-new) collides with nothing
in the consumer's divergence: it is safe **because** it is purely additive, a new
path with zero overwrite of the existing rulebook. This is the same file-scoped
down-port pattern already used for the one other genuine distribution→graph
cherry-pick (`ai-dlc-driver-signal.sh`), never a blanket install.

```bash
# bootstrap (one-time, additive — touches nothing else in the consumer):
cp -r core/skills/ai-dlc-update  <consumer>/.claude/skills/
# + the shared engine dir, if separate. Then run /ai-dlc-update from the consumer.
```

**Design constraint that makes the drop-in always safe:** `ai-dlc-update` and its
engine **MUST be self-contained** — no dependency on the consumer's *pipeline*
rulebook (`SKILL.md`, `steps/*.md`). It may read only its own logic, shell to git,
and dispatch generic agents. If it reached into the consumer's pipeline files, the
bootstrap copy would be version-fragile (it could land against a rulebook shape it
does not expect). Self-contained → the additive copy is safe regardless of how far
the consumer has diverged. This is a hard constraint on Phase 1's implementation,
not an option.

**Repeatable form (optional, for N consumers):** add an `install.sh --only
<component>` flag — a single-named-component install that copies just that
directory additively and skips the archive/overwrite of everything else. Turns the
manual `cp` into a supported operation without reintroducing the full overwrite.
After bootstrap, the skill self-updates (§6.1) — the `cp` is needed exactly once
per consumer.

## 7. Phase 2 — layered core/extension architecture (the destination)

Makes the pull near-mechanical forever by fencing divergence so it cannot re-tangle.
Same shape as the BMAD `_bmad/` LAZY/JIT pattern v0.12.0 already borrowed, and as
the settings.json upsert.

```
consumer .claude/skills/ai-dlc/
  core/          <- upstream-owned; overwrite on update; consumer NEVER edits
    SKILL.md, steps/*.md, team-roles/*.md
  extensions/    <- consumer-owned; upstream never writes
    checks/         (e.g. graph gate-checks 20,23,24,26,27,28)
    steps-domain/   (execution-health floors, deployed-ranges gate)
    roles/          (tea.md, domain OPUS_REVIEW patterns)
  overrides/     <- shadow/patch a specific core rule (settings.json-style upsert)
```

- **Update becomes:** overwrite `core/`, leave `extensions/` + `overrides/`. The
  three-way merge shrinks to just the `overrides/` set (the few core rules a
  consumer deliberately changed) — a tiny surface vs. today's whole-rulebook tangle.
- **Runtime:** the skill loads `core/` then applies `extensions/` (additive) and
  `overrides/` (shadowing), analogous to how hooks are already upserted into
  settings.
- **One-time cost:** refactor SKILL/steps to expose extension points, and untangle
  graph's divergence once into `extensions/` vs `overrides/`. Phase 1's classifier
  does the untangle triage (its domain-local vs conflict buckets map to
  extensions vs overrides).

### 7.1 Layer-aware authoring guard (load-bearing — without it, every consumer re-tangles)

Storage layering is necessary but **not sufficient**. ai-dlc's defining premise is
that the agent edits the rulebook *in place* during retros (self-improvement). If
that authoring loop keeps writing new rules into `core/`, `core/` re-tangles and the
catch-22 returns — slower, but inevitably. The layers only stay clean if the
**self-improvement loop is made layer-aware**:

- **Authoring routing.** The retro / rule-authoring step (`rule-authoring.md`,
  `retro.md`) MUST route output by kind: a *new consumer-specific rule* →
  `extensions/`; a *change to an existing core rule* → an `overrides/` entry that
  shadows it (never an in-place `core/` edit); a *generalizable improvement* →
  `extensions/` **and** flagged as a push-candidate (§8). Raw edits to `core/` are
  forbidden.
- **Gate enforcement.** A gate-validation check fails any sprint whose diff touches
  `core/` without a declared override — the same shape as the existing
  protected-path lead-only enforcement (`implementation.md`). This makes the
  discipline mechanical, not aspirational: `core/` stays byte-reconcilable with
  upstream by construction, so a pull is always a clean overwrite of `core/` plus a
  small `overrides/` merge.
- **Why this is the real generalization.** It is what reconciles ai-dlc's two
  premises — "self-improve in the consumer" and "receive upstream updates" — that
  are otherwise in direct tension. Graph proves the failure mode (no guard → total
  tangle); the guard is what stops the next consumer from repeating it.

**Minimum mechanism (Rule 26(c)).** Failure caught: a consumer's in-place rule
authoring silently mutating `core/`, so the next upstream pull either clobbers the
new rule or false-conflicts against it — the catch-22, regrown. False-positive
cost: one override declaration when a consumer genuinely must change a core rule.
Removal condition: retire once `core/` is physically read-only to the consumer
(e.g. shipped as an immutable package the skill loads, never a writable tree).

## 8. One engine, both directions — and many consumers

The per-block semantic classifier is the shared kernel of the whole system:
- **Push** (absorption arc): classify consumer divergence → BACKPORT-WORTHY items
  flow up.
- **Pull** (`ai-dlc update`): classify upstream delta vs consumer → apply/keep/
  reconcile.
- **Untangle** (Phase 2 migration): classify divergence → extensions vs overrides.

Building Phase 1 well yields the reusable engine that also powers Phase 2's
migration and future push cycles.

### 8.1 Multi-consumer fan-in (N consumers → one distribution)

The absorption arc was single-source (graph). With N consumers each self-improving,
the push path becomes a **fan-in**, and two things follow:

- **`extensions/` is the push queue.** Under §7.1, every consumer's generalizable
  innovations already live fenced in `extensions/`, each flagged push-candidate at
  authoring time. So absorption stops being a bespoke per-consumer archaeology dig
  (what the graph arc was) and becomes: drain each consumer's flagged
  `extensions/` queue through the same classifier. The pull tool *produces* the
  push backlog as a side effect.
- **N→1 dedupe at distribution.** When consumer A and consumer B both upstream a
  generalized form of the same concept, distribution must reconcile them before
  absorbing — pick the stronger generalization, or merge both into one rule. This
  is the classifier run in a *third* mode (candidate-vs-candidate, not
  candidate-vs-upstream): ALREADY-QUEUED / STRONGER-VARIANT / DISTINCT. The
  §7-mapping recording discipline (graph→dist check-number mapping in the v0.13.0
  arc) generalizes to a per-consumer provenance ledger so a concept absorbed from A
  is not re-flagged as new when B's near-duplicate arrives.

Net: the same per-block classifier serves four jobs — pull-reconcile, push-mine,
Phase-2 untangle, and N→1 fan-in dedupe. One engine, four directions.

## 9. Rollout

- **Phase 0** (done for graph): graph's stamp already records a valid merge-base —
  `0.10.0 @ 2271942`, confirmed present in distribution history. No reconstruction
  needed; validate the stamp and proceed.
- **Phase 1** (bridge): build `ai-dlc update` (dry-run reconcile + apply + re-stamp)
  reusing the arc classifier, self-contained per §6.2. **Bootstrap first** —
  file-scoped additive copy of the skill into graph (§6.2), one-time, before it can
  run. First real deliverable: graph's first clean pull to v0.14.0 core, on the
  tangled tree, with domain machinery preserved and un-pushed innovations flagged.
- **Phase 2** (structural): refactor to `core/` + `extensions/` + `overrides/`;
  untangle graph once using Phase 1's classifier; updates thereafter = overwrite
  core + merge the small overrides set.

## 10. Open questions / risks

- **Block granularity.** What is a "block" for the classifier — a rule, a `###`
  section, a check? Too coarse → false conflicts; too fine → context loss. The arc
  used per-file + per-numbered-item; start there.
- **Base fidelity for stamp-less consumers.** Graph's base is a real stamp
  (`2271942`), not an approximation — no fidelity risk there. The open case is a
  consumer with *no* stamp (installed pre-versioning, or hand-copied): its base
  must be reconstructed by finding the nearest-matching upstream commit, and early
  pulls may over-surface conflicts until the first clean reconcile corrects it.
  Acceptable — it converges. Graph is not this case.
- **Override drift.** A core rule a consumer overrides can itself change upstream;
  `overrides/` entries need their own three-way (their base = the core rule they
  shadow). This is the residual three-way surface Phase 2 keeps — small, but not
  zero.
- **Push/pull ordering.** A consumer should push (absorb its innovations upstream)
  before a pull, so pull doesn't re-surface an innovation as consumer-only that is
  about to be upstreamed. Sequence: push arc → release → pull.
- **Version semantics for a consumer.** After Phase 2, "consumer is on v0.14" means
  "core/ is v0.14"; extensions are versioned independently. The stamp tracks core
  only.
- **Authoring-guard activation ordering.** The §7.1 gate can only fire once `core/`
  physically exists (Phase 2). In Phase 1 (pre-layer, tangled tree) there is no
  clean `core/` to protect, so the guard is dormant and pulls still rely on the
  three-way reconcile. Risk: a consumer keeps tangling between Phase 1 and Phase 2.
  Mitigation: treat the Phase-2 untangle as the guard's activation event, and don't
  let a consumer sit long in Phase 1.
- **Fan-in provenance ledger.** The per-consumer absorbed-concept ledger (§8.1) is
  itself a growing artifact — it must live under the Rule 25 no-loss archival family
  (bounded live view + archive) or it becomes the next unbounded gate-read. Where it
  lives (distribution-side, one ledger) and its schema are unspecified.
- **Endgame: read-only core.** The §7.1 removal condition — ship `core/` as an
  immutable package the skill loads rather than a writable tree — would make the
  authoring guard unnecessary and pulls a package-version bump. Worth evaluating as
  the true destination beyond Phase 2, against the cost of losing in-tree
  editability that some consumers may rely on for fast local experiments.
