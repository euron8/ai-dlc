---
name: ai-dlc-update
description: "Reconcile upstream AI/DLC distribution changes into a diverged consumer project via a base-aware semantic three-way merge (the distribution→consumer pull path). Run bare for a dry-run report, or with `apply` to reconcile after review. Prefix either with a distribution ref (`<ref>`, `<ref> apply`) to stop short of upstream HEAD — needed when the self-update gate reports SELF-UPDATE-DEFER and names a SELF-UPDATE-SAFE-STOP ref, because a deferred machinery slice lands after the classify that would have used it. Run with `untangle` (or `untangle apply`) for the one-time Phase-2 core/extensions/overrides migration on a still-tangled consumer. Use when the user says \"ai-dlc-update\", \"pull upstream\", \"update ai-dlc\", \"reconcile with distribution\", or \"untangle\"."
effort: high
---

# AI/DLC Update — the distribution→consumer pull path

You are the AI/DLC **update** orchestrator. Your job is to bring upstream
distribution changes into THIS consumer project **without destroying the
consumer's divergence** — a base-aware semantic three-way merge, not the
blunt overwrite `install.sh` performs.

This is the third skill of the lifecycle triad: **setup** (onboard) ·
**ai-dlc** (operate) · **update** (reconcile). It runs on the consumer side
because it writes the consumer.

## HARD CONSTRAINT — self-contained

This skill and its reconcile engine MUST be self-contained. They read ONLY:
- their own files under `.claude/skills/ai-dlc-update/`,
- `git` (shelled out),
- the consumer's `.ai-dlc-version` stamp.

They MUST NOT read or depend on the consumer's PIPELINE rulebook
(`.claude/skills/ai-dlc/SKILL.md`, `steps/*.md`, `team-roles/*.md`). This is
what makes the bootstrap drop-in (§6.2 of the design spec) safe at ANY
divergence: a net-new directory that collides with nothing and needs nothing.
If you ever feel the urge to read a pipeline step to "understand the rules",
STOP — you don't; you diff text and classify it.

## The three inputs (three-way merge)

- **base**  = distribution `core/` at the `commit` recorded in the consumer's
  stamp. The last upstream rulebook content this consumer received.

  **Stamp schema (`.claude/.ai-dlc-version`, `v0.17.0+`):** two independently
  advancing versions —
  ```
  version: <rulebook ver>      # core/rulebook merge-base = the PULL BASE (this)
  commit:  <sha>               # advanced only by a rulebook apply (step 7)
  skill_version: <tool ver>    # the ai-dlc-update tool itself
  skill_commit:  <sha>         # advanced by the autonomous self-update (step 2)
  installed_at: <ts>
  upstream: <git ref>          # distribution URL (preserve on every re-stamp)
  ```
  `base` = the `commit` field (rulebook merge-base). Legacy stamps are single-line
  `X.Y.Z @ <sha>`: read `<sha>` as `commit`, `X.Y.Z` as `version`, treat
  `skill_version` as unknown; the next re-stamp/self-update rewrites the stamp in
  the schema above. Never drop `upstream`/`installed_at` when re-stamping.
- **theirs** = distribution `core/` at the **target ref**, which the operator may
  name (see *Invocation* below). Default upstream HEAD.
- **ours**  = the consumer's live tree (`.claude/…`, plus `scripts/` for
  `core/scripts/…`).

## Invocation

```
ai-dlc-update                     dry-run report to upstream HEAD
ai-dlc-update apply               reconcile to upstream HEAD
ai-dlc-update <ref>               dry-run report to <ref>
ai-dlc-update <ref> apply         reconcile to <ref>
ai-dlc-update untangle [apply]    one-time Phase-2 migration (unaffected by <ref>)
```

`<ref>` is anything the DISTRIBUTION repo resolves — a sha, a tag, a branch. It
sets `theirs` and nothing else; `base` still comes from the stamp.

**WHY A CONSUMER WOULD EVER STOP SHORT OF HEAD.** Step 2's self-update lands the
engine and re-invokes, so an improvement to the classifier normally classifies
its own pull. But `self-update-gate.sh` returns `SELF-UPDATE-DEFER` when the
machinery slice cannot stand alone, and a deferred slice lands in the **gated
apply at step 7 — after step 3's classify**. On such a pull the report is written
by the engine the pull was going to replace, and any new signal in the range
reports nothing at all. Measured on the reference consumer at 0.274.0 → 0.277.0:
three overrides upstream had just ABSORBED came back as ordinary
`HARD-OVERRIDE-DRIFT-SECTION`, which reads as *re-adopt the new wording* — the
exact misreading `override_supersessions` exists to end.

The remedy is to stop at a release whose slice IS machinery-only, let the engine
land, then pull the rest. **Do not hunt for that ref by hand:** every `DEFER`
now carries a `SELF-UPDATE-SAFE-STOP` row naming it, derived by running the gate
against each release in the range. Take the ref from that row.

**VALIDATE `<ref>` BEFORE USING IT — all four, and report which failed:**

1. It resolves in the **distribution** repo. A ref that resolves only in the
   consumer is the `base_sha` poisoning trap one layer up.
2. `base` is an ancestor of it (`git merge-base --is-ancestor <base> <ref>`).
   Otherwise the pull is a DOWNGRADE, and the stamp would record a version the
   consumer has already moved past.
3. It is reachable from the distribution's default branch. Pinning to an
   unmerged branch stamps the consumer to content that may never land.
4. It is not equal to `base`. That is a no-op pull, and it must say so rather
   than produce an empty report that reads like a clean one.

A `<ref>` that fails any of these STOPS the run. Do not silently fall back to
HEAD — the operator asked for a specific target, and substituting a different
one is the class of failure this whole skill is written against.

`base` and `theirs` are fetched from the distribution git repo. `ours` is the
working tree. See §6.1 of the design record — this is a vendored-dep updater
(`npm update` runs in your project and reaches the registry), not the reverse.

## Path mapping (core/ → consumer)

<!-- BEGIN GENERATED: path-mapping — source: reconcile/preclassify.sh map_consumer() -->
DERIVED from `map_consumer()`. Do not hand-edit: run `render-path-mapping.sh --write`.

| core path | consumer destination |
|-----------|----------------------|
| `core/scripts/<x>` | `scripts/ai-dlc/<x>` |
| `core/fixtures/<x>` | `tests/fixtures/<x>` |
| `core/ci-templates/<x>` | `.github/workflows/<x>` |
| `core/git-hooks/<x>` | `.githooks/<x>` |
| `core/<x>` | `.claude/<x>` |
| `<anything else>` | `<unchanged>` |

First match wins, so the rows are in the order `map_consumer()` tests them: the
specific subtrees are decided before the `core/` catch-all reaches them.
<!-- END GENERATED: path-mapping -->

## Divergence taxonomy — the classifier's output buckets

Every consumer block that differs from upstream is one of:

| Bucket | Meaning | Pull action |
|--------|---------|-------------|
| **rewording** | same concept, different prose; already-upstream in substance | take theirs (drop the consumer rewording) |
| **domain-local** | consumer machinery upstream intentionally lacks | keep ours; layer theirs' non-conflicting additions around it |
| **un-pushed-innovation** | generalizable improvement not yet absorbed upstream | keep ours; **flag for push** (feeds the absorption arc) |
| **conflict** | both changed the same core rule incompatibly | operator adjudicates |

**Every ours/theirs claim is DERIVED, never recalled.** A bucket above is a claim about
which side holds what, and the resolution prose you write is the only place that claim
appears — no detector re-reads it. So take it from the report's **Semantic worklist
orientation** block, which `emit-report.sh` renders per CLASSIFY file with the two sides
labelled and their exclusive lines shown; where a side is truncated, run the `full:` diff
command it prints. Do not describe a side from having read the file earlier in the run.

Failure caught: the sides get swapped, and because the recommended ACTION is written from
the comparison, the swap propagates into it. Observed on the 0.106.1 → 0.113.1 pull — a
BOTH-ADDED template's table assigned each side the other's rows, and the resolution would
have filed the consumer's override carrying *upstream's* content (an override restating
core, which `layer-drift.sh` flags on the next pull) while dropping the two domain classes
that were the consumer's whole reason for the file. False-positive cost: none — it
constrains where a claim comes from, not what it may say. Removed when the resolution
prose is itself generated rather than composed.

## Procedure

1. **Resolve inputs.** Read the stamp: `base` = the `commit` field (rulebook
   merge-base), per the schema above; fall back to legacy single-line parsing if
   there is no `commit:` field. Resolve `theirs` (arg or upstream HEAD). Confirm
   the distribution repo is reachable — read the `upstream` field if present;
   otherwise ask the operator for the distribution checkout path.

   **Git preflight — the consumer branch must be in a reconcilable state.**
   Shell to git in the consumer tree and check the current branch BEFORE the
   self-update (step 2) or any apply. This runs on EVERY invocation: step 2's
   autonomous push→auto-merge writes to `origin` even on a bare dry-run, and
   steps 6–7 cut the reconcile branch off the current branch. If the current
   branch does not match `origin`, cutting a reconcile/self-update branch off it
   and merging that to `origin` diverges local from `origin` the instant it
   merges, and the NEXT update then reconciles against a base that no longer
   matches `origin` — the repeated-reconciliation this check exists to prevent.
   - **Not a git repo** → STOP; no safe isolation (same as step 6).
   - **No remote configured** (`git remote` empty) → non-blocking note; the
     origin-sync guarantees below do not apply. Proceed — step 2 falls back to
     its commit-locally path.
   - **Detached HEAD** → STOP; there is no branch to track or return to.
   - **Remote exists but the current branch has no upstream** (never pushed) →
     **AUTO-PUSH**: run `git push -u origin <branch>` to publish it, then proceed.
     Its commits are absent from `origin`, so a branch cut off it and merged to
     `origin` would strand them; publishing first removes the hazard. If the push
     fails (auth, network, protected branch, remote rejected) → STOP and report
     the exact `git push` error and remedy; do not proceed on an un-synced branch.
   - **Branch AHEAD of its upstream** (unpushed commits) → **AUTO-PUSH**: run
     `git push` to bring `origin` in sync, then proceed. Ahead-only means the
     remote has not moved, so this is a clean fast-forward on `origin` and the
     exact remedy the operator would run by hand. If the push is rejected
     (e.g. the remote advanced between check and push, making the branch actually
     diverged) or otherwise fails → STOP and report the `git push` error; the
     branch is then no longer ahead-only and needs a pull/rebase first.
   - **Branch BEHIND its upstream** → STOP; fast-forward/pull first, so the
     reconcile runs against current `origin`, not a stale local base. (Not
     auto-resolved: a pull can conflict and is not a push.)
   - **Diverged** (both ahead and behind) → STOP; operator pulls/rebases first.
     (Not auto-resolved: a rebase/merge can conflict; a bare push would be
     rejected.)

   Detect with: `git remote` (empty → no remote); `git symbolic-ref -q HEAD`
   (fails → detached); `git rev-parse --abbrev-ref --symbolic-full-name @{u}`
   (non-zero exit → no upstream on this branch); and
   `git rev-list --left-right --count @{u}...HEAD` (prints `<behind>\t<ahead>`).
   For the two push-resolvable states (no-upstream, ahead-only) auto-push and
   report what was pushed in one line; for BEHIND/DIVERGED put the exact
   ahead/behind counts and the `git pull`/rebase remedy in the STOP so the
   operator knows what to run, then re-invoke. A clean tree on a branch in sync
   with its upstream — reached directly or via the auto-push — is the only state
   that proceeds.
2. **Self-update — an AUTONOMOUS, self-contained commit→merge cycle (before any
   rulebook classify/apply).** You run FROM a copy of this skill inside the
   consumer; a pull can include a change to that copy, so the logic executing the
   reconcile may be stale relative to `theirs`. The skill's own files
   (`core/skills/ai-dlc-update/**` — SKILL.md + `reconcile/*`) are **upstream-owned
   tooling, overwrite-safe** — that is a DECLARATION scoped to those paths, and
   refreshing them carries no consumer-divergence risk. Therefore the self-update
   lands on its OWN cycle, **autonomously — no operator approval**, distinct from
   the operator-gated rulebook reconcile (step 8).

   **That declaration does NOT extend to the rest of the machinery set, and reading it as
   if it did is how this step overwrites a consumer edit.** Machinery is upstream-OWNED —
   a statement about who decides its content, not a claim that no consumer has ever edited
   its copy. The reference consumer edited its `.githooks/pre-push`, a `machinery:` entry,
   and this cycle would otherwise have written `theirs` over it autonomously and
   auto-merged the result. The second subtraction below is what disposes of that state,
   and `reconcile/self-update-gate.sh` names every such path in its output. Where the
   two sentences here and at "only the paths that diff names" below appear to conflict,
   the subtraction is the resolution: a consumer-modified machinery path is never written
   by this cycle.

   Diff `base→theirs` restricted to **the MACHINERY set** — read
   `reconcile/setup-sites.md`'s `machinery:` list (the manifest, `git-hooks/pre-push`,
   hooks, `scripts/ai-dlc/*`, schemas, session-driver, templates, and the `ai-dlc-setup` /
   `ai-dlc-update` subtrees) — **plus the fixtures that cover THE CHANGED PATHS**: every
   `core/fixtures/<dir>/` whose `*.sh` names one of the machinery paths **this diff actually
   touched**, EXCLUDING any dir carrying a `.dist-only` marker (never shipped, so it cannot
   run on a consumer). Derive both sets rather than enumerating either here, and grep
   `seed.sh` as well as `run.sh` (a fixture commonly resolves the tooling path in its seed,
   so a run.sh-only derivation misses it).

   **Against the CHANGED paths, not the whole machinery list — the difference is two orders
   of magnitude.** `machinery:` carries `core/scripts/ai-dlc/*`, which the substitution below
   turns into *every distribution script*; and a fixture's whole job is to invoke a validator,
   so naming a `core/scripts/…` path is the norm. Measured at 0.168.1: **45 of 66** shippable
   fixtures name one, so a whole-list reading demands 45 fixture runs to gate a one-script
   change and is indistinguishable from "run the entire suite." The changed-paths reading
   yields the one covering fixture, which is what the step means and what makes the write
   instruction below — "the covering fixtures, never the derived set per directory" — a
   distinction the reader can act on rather than a contradiction.

   **One entry is CONSUMER-shaped; translate it and match dist-to-dist.** `machinery:`
   entries carry a `core/` prefix and are otherwise consumer-shaped, which matters for
   exactly one of them: `core/scripts/ai-dlc/*` is where a validator LANDS, while upstream
   it is `core/scripts/<name>`. Testing a `git diff` path against that entry directly
   matches `scripts/` not at all and silently yields an EMPTY slice. Every other machinery
   entry is already a valid distribution glob (verified: only that one resolves to zero
   files under `git ls-files`). So substitute `core/scripts/ai-dlc/` → `core/scripts/`
   and match the diff paths against the result.

   Do NOT reach for `to_consumer_glob()` here. It lives in `core/scripts/core-paths.sh`
   and `core/hooks/ai-dlc-core-guard.sh` — outside `reconcile/`, so this skill's HARD
   CONSTRAINT forbids reading it, and an earlier draft of this step sent the reader there
   anyway. The one substitution above needs no helper.

   **The whole machinery set moves together, not just this skill.** Machinery is exactly
   the core with no layer grain — no `overrides/` shadow, no `extensions/` entry, nothing
   for an operator to adjudicate — which is the same property that makes this cycle
   autonomous in the first place. `validate-enforcement-map.sh` I28 asserts the
   `machinery:`/`rulebook:` lists partition the manifest, so the set cannot silently
   narrow. The rulebook stays operator-gated at step 8.

   **The tooling and the fixtures that guard it move together or the suite goes red on a
   pull that broke nothing.** Pulling `reconcile/*` alone leaves the consumer running new
   tooling against fixtures written for the old, and the suite fails on a fixture correctly
   reporting that its subject changed underneath it — not a regression, not consumer-caused,
   and it blocks the run before the reconcile that would have shipped the matching fixture.
   A self-update that carries a validator without the fixture asserting its behaviour
   strands the fixture against code it no longer describes.

   **Restricting the slice to this skill was itself that bug.** A fixture covering
   `ai-dlc-update` can depend on machinery elsewhere, and two of them do: `check-15-bypass`
   resolves `scripts/ai-dlc/core-paths.sh` and `core-manifest.md`, `core-write-guard`
   resolves the core guard hook. Pulling only `skills/ai-dlc-update/**` left both asserting
   against machinery this cycle did not carry, and a red derived fixture HARD-STOPS the
   cycle — so the self-update wedged on a pull that broke nothing. The machinery set is the
   smallest slice that closes that ~~, because a fixture's subject is always machinery~~.

   **CORRECTED — "a fixture's subject is always machinery" is FALSE, and widening the slice
   cannot fix it, because the only thing left to widen into is the rulebook this step
   deliberately excludes.** Measured on the reference consumer pulling 0.249.0 → 0.261.0:
   **7 of that tree's 109 fixtures are red in the state this step constructs**, and the
   operator had to cut a branch, write the 17-path slice and run 43 derived fixtures to
   find out. Two distinct couplings, both real:

   - **`enforcement-map.yaml` is machinery; its `CHECK_LOADED` anchors are rulebook.** A
     release that adds a check makes the incoming map reference an anchor that does not
     exist in the consumer's `steps/gate-validation.md` yet, so `validate-enforcement-map.sh`
     fails on the consumer's own tree and every fixture driving it goes red. Measured:
     checks 33, 34 and 35.
   - **Some fixtures assert on rulebook directly.** `postcompact-rulebook-recovery` runs
     `validate-reattach-budget.sh` against the SHIPPED `SKILL.md` and mutates its mandate.
     Its subject is rulebook, so it cannot be green while machinery is at theirs and
     rulebook at ours — whatever the slice contains.

   **So the deferral is structural, not exceptional**, and for any pull spanning a
   check-adding release it is the expected outcome. `reconcile/self-update-gate.sh` now
   detects both couplings BEFORE the branch is cut and returns `SELF-UPDATE-DEFER`, so the
   slice folds into the gated apply without the branch/write/run/revert cycle. Its arms fire
   only when the rulebook is ALSO about to change: a machinery-only pull still proceeds
   autonomously (verified against 0.256.0 → 0.257.0, which touches no rulebook file).

   **EMPTY is a CONTENT question, not a diff question — or this step never terminates.**
   The slice is `git diff base→theirs`, and `base` is the stamp's `commit`, which advances
   only under a gated `apply` at step 7. So once a self-update has written every machinery
   path, the diff STILL lists them on the next bare invocation: the cycle re-runs, re-invokes,
   and re-runs again. Measured on the reference consumer after both its self-update PRs
   merged — the diff still yielded every machinery path while a per-path content check
   reported all of them already at `theirs`.
   
   So drop from the slice every path whose consumer copy already matches `theirs`. Do not
   hand-roll that comparison: `reconcile/preclassify.sh` already buckets exactly this as
   `ALREADY-AT-THEIRS`. The slice is the sliced paths MINUS those.

   **Then subtract a SECOND set from the SAME call: every path whose bucket records a
   consumer divergence.** That call already returns them; this step used to read one bucket
   and drop the rest on the floor, which is the whole defect — a machinery path the consumer
   has edited comes back `BOTH-CHANGED->CLASSIFY` and was written from `theirs` anyway.
   **Key the subtraction on the CLASSIFY marker, not on that one bucket name.** Every bucket
   `preclassify.sh` sends `->CLASSIFY` is a path whose two sides diverged and which therefore
   needs an adjudication this autonomous cycle does not perform, and `BOTH-CHANGED` is only
   the modified-both-sides member of that set — the added-both-sides, upstream-deleted and
   consumer-deleted members carry consumer state too. `RELOCATE-MOVE+consumer-edited` records
   a divergence without carrying the marker, so match it as well.

   **Do NOT write those paths, and do NOT treat the subtraction as a silent drop.** Report
   each by name in one line, and carry it to the step-7 gated apply, which already emits a
   `WORKLIST semantic-merge <path>` row for it — so the path reaches the operator instead of
   being overwritten. `reconcile/self-update-gate.sh` emits one `SELF-UPDATE-CARRY` row per
   such path; if its set and yours disagree, stop and report that, because one of the two
   derivations is wrong.

   A carried path stays in the `base→theirs` diff on every later invocation, since `base`
   advances only at step 7. That is correct and is NOT the non-termination case above: it is
   a standing worklist item, reported each run and never re-attempted.

   If the slice is EMPTY after that subtraction, say so in one line and continue to step 3.

   If NON-EMPTY, **first run `reconcile/self-update-gate.sh <dist> <base> <theirs> <consumer>`.**
   The machinery slice includes `core/scripts/*`, and the consumer's own `.githooks/pre-push`
   INVOKES several of those scripts — so this cycle can install a check that then fails the very
   push it is making, on layer state that predates the pull and whose remedy is rulebook-side work
   this step deliberately does not do. It does not deadlock (a failed push commits locally and does
   not block the run), which is worse in one respect: it strands an orphaned local branch whose
   push is permanently blocked and a `skill_version` advanced on a commit that will never merge.
   Filed by the reference consumer as `PC-S308` after its operator hit it and derived the remedy by
   hand.

   - On `SELF-UPDATE-DEFER` or `SELF-UPDATE-UNDECIDED`: **do NOT cut the branch and do NOT push.**
     Report the rows, and carry the machinery slice into the step-7 gated apply so machinery and
     rulebook land on ONE branch — the operator fixes the layer state there, and that is the only
     ordering in which the pre-push gate can go green. Say in one line that step 2 deferred and
     why, and **advance `skill_version`/`skill_commit` with that apply rather than here — by
     running `reconcile/apply.sh --carried-machinery-slice <dist> <base> <consumer> <theirs>` at
     step 7.** That flag is the whole mechanism; do NOT set the two fields by hand, and do not
     read step 7's "preserve them" as overriding this. The two instructions describe different
     runs and the flag is what tells them apart — see step 7's re-stamp bullet.
   - On `SELF-UPDATE-OK`: proceed autonomously as below.
   - `SELF-UPDATE-CARRY` rows are ADVISORY and accompany any verdict, OK included. Each names
     one machinery path the consumer has diverged on. They do not stop the cycle; they remove
     paths from it. Report every one, write none of them, and carry each to the step-7 gated
     apply. A carry row and an OK verdict together mean "self-update the rest, hand this path
     to the operator" — the case this step had no disposition for.

   The gate's verdict is a DIFFERENTIAL — the incoming script and the consumer's current one, run
   under identical conditions — so a script that merely fails to resolve from a temp path cannot
   masquerade as a new finding and strand the slice for no reason.

   If NON-EMPTY and the gate says OK:
   - **Run the self-update cycle autonomously:** cut a dedicated branch
     `ai-dlc-update/self-update-<theirs-version>-<ts>`, write from `theirs` **only the paths
     that diff names AND that survived both subtractions above** — never a path carried by a
     `SELF-UPDATE-CARRY` row — each at the consumer destination `map_consumer()` gives it, and
     `tests/fixtures/<dir>/` for the covering fixtures — never the derived set per
     directory, **update the stamp's
     `skill_version`/`skill_commit` to `theirs`** (rewrite the stamp in schema,
     preserving `version`/`commit`/`installed_at`/`upstream`), commit
     (`chore(ai-dlc-update): self-update <base-skill-ver> → <theirs-ver>`), **run the
     derived fixtures through
     `reconcile/self-update-fixtures.sh <dist> <base> <theirs> <consumer> <fixture>...`
     and require green BEFORE the push**, push,
     open a PR, and **auto-merge (squash, delete branch)** — no operator gate (the
     step-1 git preflight confirmed the branch is in sync with `origin`, so this
     merge cannot strand local commits). If there is no remote / push fails,
     commit locally and note it; do not block the run. Advancing `skill_version` here is what keeps the stamp an honest record
     of the installed tool version — it is bookkeeping tied to the (already
     autonomous) self-update, and never touches `version`/`commit` (the rulebook
     base stays put until a gated apply).

     **A derived fixture whose consumer copy differs from `base` is a consumer edit — never
     overwrite it.** Report the path, leave the file, and continue the cycle. Only
     `.claude/skills/ai-dlc-update/**` is overwrite-safe by declaration; a fixture is not,
     and the derived set is grepped from the fixtures rather than from the diff, so it names
     fixtures this pull does not change.

     **A red derived fixture STOPS the self-update; it does not get pushed and sorted out
     later.** The machinery slice closes the common dependency case by construction — a
     fixture's subject is machinery, and the whole machinery set now moves together — but a
     fixture can still depend on RULEBOOK content, which this cycle deliberately does not
     pull. Running them here is what tells the two cases apart: green means the pulled set
     is self-consistent, red means it is not, and the second is a finding to report — with
     the fixture name and its output — not a gate to bypass. Pushing a known-red suite so
     the reconcile can proceed leaves the next operator unable to tell this breakage from a
     real one.

     **RUN THEM THROUGH `reconcile/self-update-fixtures.sh`, AND CITE THE LOG PATH IT
     PRINTS IN THE STOP MESSAGE.** On red this cycle discards the branch and restores the
     tree, so the state the fixtures ran against ceases to exist: `reconcile-log-<ts>.md`
     is step-7 only, and `reconcile-report.md` is not written until step 5. Run them any
     other way and the only record of WHY the self-update stopped is this agent's own
     context, which the next invocation does not have. The helper writes
     `_bmad-output/ai-dlc-update/self-update-fixtures-<ts>.md` as it goes — before the
     branch can be discarded — and exits 2 rather than 0 if it could not run at all, so an
     empty set cannot report as a green suite. Measured twice on the reference consumer,
     where the evidence had to be recovered by re-staging the discarded slice the first
     time and captured by hand the second.
   - **Then STOP this invocation and re-invoke `/ai-dlc-update` automatically —
     do NOT ask whether to.** The self-update landed, but THIS invocation is
     still executing the PRE-update logic — its reconcile/classify/apply behavior
     is stale, and an in-flight agent cannot hot-reload its own instructions. So
     do NOT proceed to step 3 on stale logic. Instead: report in one line that
     the self-update landed (merged PR ref) + what changed (`reconcile/` — the
     engine — vs prose/docs), then **immediately re-invoke the `ai-dlc-update`
     skill (Skill tool), carrying the operator's original arguments IN FULL** — a
     bare run re-invokes bare (fresh dry-run), an `apply` run re-invokes `apply`,
     and **a run that named a `<ref>` re-invokes with that same `<ref>`**. The
     fresh invocation loads the updated logic and runs the reconcile on it.

     Dropping the `<ref>` on re-invoke silently retargets the pull at HEAD, which
     is the one thing the operator ruled out by naming a ref — and it would do it
     at the exact moment the split-pull remedy is being executed, turning a
     deliberate two-step back into the single bundled pull it was working around.

     Re-invoking is the default and needs no confirmation: an operator who just
     updated the tool wants to run its latest iteration, and the re-invocation is
     the only way to execute the fresh logic — there is no reason to update the
     tool but not re-run it. Do NOT continue this run on the stale logic (silently
     proceeding on stale logic is the exact defect this stop prevents). The one
     case that returns control to the operator: if the re-invocation cannot be
     issued automatically in this harness, say so in one line and tell the
     operator to run `/ai-dlc-update` themselves — never fall through to stale
     logic. This applies even when the following reconcile would be empty.
3. **Mechanical pre-classification** (cheap, deterministic — no agents):
   run `reconcile/preclassify.sh <dist-repo> <base-sha> <theirs-ref> <consumer-root>`.
   It hashes base/theirs/ours per changed file and buckets each into:
   - `UPSTREAM-ONLY-ADD` (net-new upstream, consumer lacks it) → **apply (pure)**
   - `UPSTREAM-ONLY` (upstream changed, consumer untouched vs base) → **apply**
   - `ALREADY-AT-THEIRS` / `ALREADY-PRESENT` → **noop**
   - `UPSTREAM-DELETED` (upstream removed it, consumer untouched vs base) →
     **delete the consumer file (gated — destructive, see step 7)**
   - `UPSTREAM-DELETED-NOOP` (upstream removed it, consumer already lacks it) → **noop**
   - `CONSUMER-MISSING-NOOP` (the consumer opted out of this destination — today only
     `.github/workflows/`, which `install.sh` has always written *only* if the directory
     already exists) → **noop**. Updating a workflow a consumer HAS is a fix; creating
     CI on a consumer that has none is a change nobody asked the pull to make.
   - `ORPHANED-RELOCATED` (status `O`) — a file at a consumer path this distribution
     **used to** write and no longer targets, whose content still hash-matches the blob
     we shipped, so it is provably our copy → **delete the consumer file (gated —
     destructive, see step 7)**. When a core subtree's destination changes, the copies
     already written to the old path do not move and do not vanish; every later pull
     refreshes only the new path, so the orphan silently diverges from the file it is a
     copy of. Retiring it is the pull's job — a migration note in a CHANGELOG is how it
     never gets done. Emitted **level-triggered**: an orphan is a *state* of the consumer
     tree, not an event in the upstream diff, so a pull that touches no file in the moved
     subtree must still report it.
   - `ORPHANED-UNKNOWN` / `ORPHANED-RELOCATED+consumer-modified` → **needs semantic
     classify, never auto-deleted.** The orphan is either something upstream never
     shipped or something the consumer edited. The pull only ever proposes destroying a
     file whose bytes it can prove it wrote.
   - `BOTH-CHANGED` / `BOTH-ADDED` / `UPSTREAM-MOD+consumer-deleted` /
     `UPSTREAM-DELETED+consumer-modified` → **needs semantic classify**
3a-ii. **Retired contract tokens** (cheap, deterministic — no agents):
   run `reconcile/retired-tokens.sh <dist-repo> <base-sha> <theirs-ref> <consumer-root>`.
   Every `CLASSIFY` file's semantic merge MUST clear this before it counts as done.
   It names the one merge defect no other detector here can see: upstream retired a
   shared contract (a channel, a scratch path, a state file) and the consumer's own
   code — inside the same upstream-maintained file — still speaks the old one. That
   merges cleanly, parses cleanly, and yields a gate that cannot fire. It happened:
   on the 0.114.0 → 0.118.2 pull a consumer's pool block kept writing to a retired
   temp path and its budget gate reported PASS at **1212% of budget, exit 0**. Nothing
   flagged it; a person found it by hand-building a functional test.
   **A non-empty result means the merge is NOT complete.** Re-point the consumer's
   reference at whatever THEIRS replaced it with, then re-run until the output is
   empty — or record in the report why a survivor is safe. `apply.sh` carries the
   token list on the worklist item itself, so the obligation arrives with the work.
   Note what it does NOT catch: a consumer path upstream never had (there is no
   retirement to detect). A clean result is not proof the merge is semantically whole.
3a-iii. **Retired contract shapes in consumer layer files** (cheap, deterministic
   — no agents): run `reconcile/retired-layer-contract.sh <dist-repo> <base-sha>
   <theirs-ref> <consumer-root>`. `retired-tokens.sh` above scans only `CLASSIFY`
   core files, so `overrides/` and `extensions/` are outside every bucket and no
   detector opens them. A layer file that shadows, quotes, or restates a core
   construct upstream retired therefore survives the pull unreported, and the layer
   is what the teammate reads.
   Output is `RETIRED-LAYER-CONTRACT<TAB><layer-path><TAB><shape>`. Each row is a
   layer file to re-read against `theirs`: either re-point it at the replacement
   construct, or record in the report why the stale reference is harmless.
   **Read its stderr, not only its rows.** When the release retired no shape it opens
   no layer file at all, and says so; that NOTE is the difference between a scan that
   found nothing and a scan that never ran.
3a-iv. **Retired core PASSAGES still carried by a layer file** (cheap, deterministic
   — no agents): run `reconcile/retired-layer-passage.sh <dist-repo> <base-sha>
   <theirs-ref> <consumer-root>`. 3a-iii matches retired contract SHAPES — labelled
   directives and `{token}` placeholders — and cannot see a layer file that reproduces
   a retired core directive as ordinary prose. This one asks the complementary question:
   does a layer file still contain a LINE core carried at base and deleted by theirs?
   Output is `RETIRED-LAYER-PASSAGE<TAB><layer-path>:<line><TAB><deleted core line>`.
   Each row is a passage the layer reproduces and core no longer has — re-point it at
   the replacement wording, or record why reproducing the retired text is still correct.
   Its limit, and read its stderr for the same reason: it matches reproductions, not
   paraphrases. Reword any clause and the line stops matching.
   **This does NOT block the apply** — a layer file is consumer-owned and the pull
   does not rewrite it. It is a worklist item, and it is owed before the pull counts
   as done.
   Note what it does NOT catch: a shape the consumer invented that core never had,
   and a layer file that paraphrases a retired construct without using its literal
   shape. A clean result is not proof every layer file survived the release.
3a-v. **Core fixtures the consumer still carries after core stopped shipping them**
   (cheap, deterministic — no agents): run
   `reconcile/retired-fixtures.sh <dist-repo> <theirs-ref> <consumer-root>`.
   `install.sh` and `apply.sh` copy a core fixture into the consumer; when core later
   marks it `.dist-only` or deletes it, both stop copying it — correctly — and the copy
   already installed becomes unreachable by every mechanism core has. It is not drift
   (nobody edited it) and not a missing file (the consumer has one), so no bucket claims
   it, and it freezes at whatever core last shipped.
   Output is `RETIRED-FIXTURE-ORPHAN<TAB><consumer-path><TAB><remedy>`.
   **This does NOT block the apply**, and core does not remove the directory — the file
   is the consumer's. Each row is a `rm -rf` the operator confirms, or a rename if the
   consumer has adopted the fixture as its own.
   Two rows are NOT orphans and mean the scan was incomplete: `HARD-RETIRED-FIXTURE-
   SCAN-UNAVAILABLE` (the path mapper could not be loaded — nothing was scanned) and
   `RETIRED-FIXTURE-HISTORY-UNAVAILABLE` (a shallow clone, so a fixture core DELETED
   cannot be told from one the consumer wrote; the `.dist-only` half is unaffected).
   Note what it does NOT catch: a core fixture the consumer RENAMED, which by design
   reads as the consumer's own.

3b. **Template pre-classification** (the generated files outside `core/`):
   run `reconcile/preclassify.sh <dist-repo> <base-sha> <theirs-ref>
   <consumer-root> --templates`. The `core/` reconcile above never sees
   `CLAUDE.md`, `docs/coding-conventions.md`, `QUICKSTART.md`, or
   `.claude/settings.json` — they are generated from `templates/*.template`
   and filled with consumer config, so an upstream edit to the template
   boilerplate (a removed section, a reworded rule) would otherwise never
   reach a consumer. This pass buckets each per `reconcile/template-sites.md`:
   - `TEMPLATE-UNCHANGED-NOOP` (upstream template boilerplate identical vs base) → **noop**
   - `CONSUMER-MISSING-NOOP` (consumer lacks the generated file) → **skip**
   - `TEMPLATE-PROSE-MERGE` (token-prose file, boilerplate changed) → **marker-anchored mask/reinject (step 7)**
   - `TEMPLATE-JSON-MERGE` (`settings.json`, changed) → **jq strip/merge (step 7)**
   Reconciling these is per `template-sites.md`'s transforms; the consumer's
   filled config is preserved, only upstream boilerplate is synced.
3c. **Layer-drift detection** (cheap, deterministic — no agents):
   run `reconcile/layer-drift.sh <dist-repo> <base-sha> <theirs-ref> <consumer-root>`.
   This MECHANIZES the "Layered consumers" rule below. Do NOT
   hand-verify overrides with ad-hoc `git diff` calls: a hand check is what lets a
   consumer accumulate overrides
   whose `base_sha` pointed at its OWN repo — every diff would have died on
   `fatal: bad revision`, and two shipped upstream changes were discarded unseen.
   Statuses:
   - `HARD-OVERRIDE-BASE-CONSUMER-SHA` / `HARD-OVERRIDE-BASE-UNRESOLVABLE` →
     **blocks `apply`** (see step 7). The `base_sha` is unusable, so drift for
     that override is undecidable. Never skip it; never "assume unchanged."
     Resolution: operator re-stamps `base_sha` to the correct distribution sha.
   - `HARD-OVERRIDE-DRIFT-SECTION` → the shadowed section changed upstream, so the
     override is now shadowing **a rule that no longer exists**. **Blocks `apply`**
     (see step 7). Resolution is not freehand — run the re-adoption workflow:

         reconcile/readopt-override.sh <dist> <theirs> <consumer> <override>

     It prints the dossier (the core section's `base_sha..theirs` diff, the override's
     body, its stated `reason:`, and the superseded core lines still sitting in that
     body) and asks the one question that decides the outcome: **does upstream's change
     supersede the reason this override exists?** Three outcomes, all ending in a
     re-stamped `base_sha`: `--stamp retire` (upstream absorbed it), `--stamp readopt`
     (merge the new core text into the override, preserving the consumer's delta),
     `--stamp reaffirm --note "<why>"` (the override still stands).

     **`--merge` performs the re-adoption; you do not hand-edit the body.** It is a
     three-way merge (base = core@`base_sha`, ours = the override body, theirs =
     core@`theirs`), so upstream's change lands and the consumer's delta survives. A
     conflict leaves markers and is the only case needing a human.

     **`--stamp readopt` is REFUSED while the body still carries core text `theirs`
     superseded, or while conflict markers remain.** Drift is computed
     `base_sha..theirs`, so a bare re-stamp makes the HARD status evaporate with nothing
     migrated — the lead reads the OVERRIDE, not core, and would go on obeying the rule
     the fix replaced. Doing nothing is not an available outcome.

     The full procedure — **you do the surgery, the operator approves it** — is the
     adjudication loop in step 7. Do not hand the operator a blocker list.
     **Why this blocks, when a check-number collision does not.** A collision is
     cosmetic and consumer-fixable. This changes **the rules the lead obeys**: the
     lead reads the override, not core, so an un-adjudicated drift means the core fix
     landed on disk and the pipeline went on running the rule it replaced. That is
     not hypothetical: a core fix routinely targets a section some consumer shadows
     verbatim, and under an advisory status the fix is inert on exactly the pipelines
     it was written for.
   - `OVERRIDE-DRIFT-FILE` → the anchor is not a locatable heading AND the file
     changed, so the section cannot be *proven* safe. Surface for re-confirmation.
     Conservative on purpose — an unprovable section is never reported as OK.
   - `OVERRIDE-ANCHOR-UNRESOLVED` → upstream restructured the anchor away.
   - `OVERRIDE-DELEGATES-INTO-SHADOW` → the override's body names a construct
     defined INSIDE a section it shadows, so precedence deletes the delegation
     target along with the section. **Report-only, never blocking** — pointing the
     lead at core is sometimes deliberate. Every other status here asks whether
     UPSTREAM moved; this one is true or false today, independent of any pull, so a
     clean drift result says nothing about it. Record it and offer the three
     remedies: restate the construct in the override, narrow `shadows:` to the
     sub-headings actually rewritten, or delegate to something outside the span.
     Left alone, every future change to that construct silently fails to arrive.
   - `OVERRIDE-ASSERTS-SHADOW-SURVIVES` → the body states that the span it shadows
     is unchanged and still governs. The sibling of the above and the same mechanism:
     precedence replaces the WHOLE span, so that sentence is false about the entry's
     own effect. **Report-only.** Remedy: narrow `shadows:`, or restate the surviving
     text in the body.
   - `OVERRIDE-BODY-UNCLAIMED` → a section of the body that NO `shadows:` anchor
     claims. Both rows above ask whether the body describes its own effect truthfully;
     this asks whether the body is REACHED. The body is sliced per anchor, so a section
     no anchor names is applied by nothing — it renders nowhere while still reading as
     live consumer machinery. **Report-only.** It is reached by REMOVING an anchor and
     leaving the body, so it is the companion row to an `OVERRIDE-SUPERSEDED` narrowing:
     read them together before executing one. Remedy: restore the anchor, move the text
     under a section an anchor does claim, or delete it.
   - `OVERRIDE-LOOSE-ANCHOR` → a `shadows:` anchor resolves only by the REVERSE arm
     of the containment match, so it names something finer than a heading and quietly
     widens the shadow to the whole section. **Report-only.** The row names the exact
     heading to substitute. E7 errors on this at authoring time; that validator is
     consumer-run and skippable, and this pull is not.
   - `OVERRIDE-DOUBLE-SHADOW` → two entries declare the same (file, anchor). Each is
     well-formed alone; precedence picks one body silently, and every commit touching
     the span invalidates BOTH stamps, so reconciling one looks complete.
     **Report-only** — a deliberate split is allowed, but it has to be stated in the
     bodies. Filed under EVERY participating entry, not just the first.
   - `EXTENSION-RETIRE-CANDIDATE` → upstream **absorbed** a section this extension
     defines: the titles agree (never merely the number — consumer gate-check numbers
     are a sanctioned separate namespace) and core did not carry it at `base`. The
     match is number-agnostic, so it fires even when upstream absorbed the check under
     a *different* number. Per Rule 27(b) the consumer MUST retire the entry; list it
     in the report's retirement list. Without this signal every successful absorption
     leaves a duplicate behind.
   - `EXTENSION-RESTATES-CORE` → the same title agreement, but core already carried
     the section **at `base`**. The consumer has been duplicating a core section for
     some number of releases without being told. The retirement signal is
     level-triggered: it fires on every pull while the duplication stands, not only on
     the pull that landed the absorption. Rule 27(c) forbids restating core (the copy
     cannot drift-check against the original, so it forks silently and then contradicts
     it). List it in the retirement list too, but the remedy is a judgement: retire it
     if it merely duplicates core; refile it in `overrides/` with a `base_sha` if it
     hardens or restricts core.
   - `EXTENSION-CHECK-NUMBER-COLLISION` → core defines this extension's check *number*
     with a **different title**. Extensions are additive, so the two catalogs render
     into one merged list under one integer and the bare `Check N` the lead commits to
     the gate log stops having a referent. The exact complement of the absorption
     signal. Tagged `NEW-THIS-PULL` (this pull created it — route to the
     needs-confirmation list so the operator acknowledges it) or `PRE-EXISTING` (the
     migration worklist). **Report-only: it never blocks `apply`.** A collision is
     decidable and consumer-fixable, and a consumer must never be unable to take a
     security fix because its own catalog needs relabelling.
   - `EXTENSION-HOOK-DRIFT` → the hooked core file changed. Extensions have no
     section anchor (`hooks:` is file-grain), so this is the strongest statement
     available: re-read the entry against the new core text. Its clause is at
     `level: ADJUDICATED`, so the re-read must be RECORDED — see the two statuses below
     and step 7.
   - `HARD-LAYER-ADJUDICATION-MISSING` [LC-A1] → a row of a clause at `level: ADJUDICATED` has no
     recorded verdict in `_bmad-output/ai-dlc-update/layer-adjudication-register.jsonl`
     under the `subject_digest` the row carries. **Blocks `apply`.** The remedy is to make
     the judgement and write it down, not to widen anything. Step 7 has the record shape.
   - `HARD-REGISTER-CONTRADICTION` [LC-A2] → that register states two different verdicts under one
     key and the later record declares no `supersedes` plus `reason`. **Blocks `apply`**,
     because a lookup would otherwise answer with whichever record was read last.
   - `EXTENSION-HOOK-MISSING`, `OVERRIDE-OK`, `EXTENSION-OK` → as named.

3d. **Unregistered core drift — the layer system's blind spot.** `layer-drift.sh`
   walks `overrides/` and `extensions/`. A core file edited **in place** appears in
   neither, so no entry describes it, no `base_sha` tracks it, and `apply` — which
   overwrites upstream-owned core — **deletes it without a word.** Run:

       reconcile/unregistered-drift.sh <dist-repo> <base-sha> <consumer-root> <theirs-ref>

   **Pass `<theirs-ref>`.** Without it the absorption check cannot run, and a consumer
   whose hardening upstream just adopted keeps being told to refile a delta core already
   carries — forever.

   - `HARD-CORE-DRIFT-ABSORBED` → **upstream took this change.** Lines the consumer added
     (absent from core at `base`) are present in core at `theirs`. The remedy is a
     **revert**, not an override, and telling the operator to refile it would be actively
     wrong advice. It still **blocks**: a revert DELETES consumer text, so the operator
     confirms the upstream version covers their delta first. Show them the diff, then run
     the `git show "<theirs>:<core-path>" > <consumer-path>` command the status carries.
     This is the core-drift twin of `EXTENSION-RETIRE-CANDIDATE`.

   - `HARD-CORE-BEHIND` → **this copy is STALE, not forked.** It best-matches a historical
     blob of that path which is a strict ancestor of `base` and older than it, so the file
     predates the consumer's own stamp and most of what reads as consumer drift is
     upstream's change since then. The remedy is **take theirs**. It still **blocks**,
     because the residual against that ancestor IS the consumer's: show them that diff —
     the status carries the command — and confirm nothing in it is still wanted before
     overwriting. **Do not adjudicate this row from the base-relative line count**; that
     number grows with staleness on its own. A file excluded from `apply` by a standing
     per-entry acceptance is the usual way one gets here, and the acceptance is then
     self-perpetuating: each pull it skips makes the next pull's diff larger and the
     "fork" reading more convincing.

   - `HARD-UNREGISTERED-CORE-DRIFT` → **blocks `apply`** (step 7). Undecidable by the
     tool (deliberate hardening → refile as an `overrides/` entry with a `base_sha`;
     accident → revert) and lossy if ignored. Same bar as the other `HARD-` statuses.
     Reached only after `HARD-CORE-BEHIND` has been ruled out, so the consumer's copy is
     anchored at `base` and the delta really is its own.
     **`reconcile/register-drift.sh <dist> <base> <consumer> <core-rel-path> --apply`
     does the refiling**: it authors the override from the consumer's own changed
     sections, anchors it to real headings, stamps `base_sha` at **base**, and reverts
     core. It leaves `reason:` as `TODO` — propose one, have the operator confirm it.
     Hooks are refused by design (no override grain exists for them); say so plainly.
   - `CORE-TEMPLATE-SUBSTITUTED` → differs only where the distribution carries a
     `{token}` site. That is what `install.sh` does; it is not drift, and it must
     never be reported as such.
   - `CORE-OK` → byte-identical to the distribution at base.
   - `CORE-AT-THEIRS` → byte-identical to the distribution at `theirs`: already applied,
     never drift. A row here is the tell that the base passed in was stale.
   - `CORE-AT-SELF-UPDATE` → byte-identical to the distribution at `skill_commit`, the OTHER
     sha in this consumer's own stamp. **Not drift, and no action.** Step 2's autonomous
     self-update rewrites the whole MACHINERY set, so on a multi-hop pull those files sit at
     an INTERMEDIATE ref while `commit` — the base every predicate here measures against —
     stays where it was. **28 files are in both the machinery set and this scan** (control:
     72 machinery files are outside it), and without this row each one reads as a consumer
     edit and draws a HARD status whose printed remedy is to revert upstream's own text.
     Reproduced at ground truth on the distribution's own history: the same file at the
     intermediate ref gives `HARD-CORE-DRIFT-ABSORBED`, and at base gives `CORE-OK`.
     The script reads `skill_commit` from the stamp ITSELF rather than taking it as an
     argument — a fifth argument is a fifth thing a caller can omit, and step 7 below records
     what that cost the last time one instruction had to be remembered for two scripts.
   - `HARD-DRIFT-SCAN-UNAVAILABLE` → **blocks `apply`**. The scan could not load its path
     mapper, so it scanned NOTHING and its empty output is not a clean tree. Restore
     `reconcile/preclassify.sh` beside `unregistered-drift.sh` and re-run.

3e. **Consumer-catalog collisions.** Run `reconcile/relabel-extension-checks.sh
   <consumer-root> --dist <dist-repo> --theirs <theirs-ref>` (dry-run). Every extension
   check whose number core also defines needs the labelled form `### <n>. [ext:<id>]
   <title>`. **Pass `--dist`/`--theirs`** so the number set is the UNION of the installed
   core and the INCOMING core: a collision the pull *creates* (upstream adds `### 26.`
   while an extension already carries it) is invisible to a plain dry-run — the installed
   core does not carry the new number yet — so without theirs the tool reports "none"
   while the needs-confirmation list flags it, and the operator gets no relabel preview at
   the one moment they can decide it. **Report-only here; it never blocks `apply`** — a
   collision is decidable and consumer-fixable, and a consumer must never be unable to take
   a fix because its own catalog needs relabelling. The updater OFFERS the rewrite at step
   7. The integer never moves; only the label is added, so existing gate history maps by
   identity.

3ea. **Extension checks the incoming core makes newly-unloadable.** Run
   `reconcile/adopt-extension-checks.sh <consumer-root>` (dry-run). It lists, per
   `kind: check` extension entry, the check ids defined only as a HEADING — no
   `<!-- CHECK_LOADED: <id> -->` anchor, named by no manifest row — which is
   `validate-gate-manifest.sh`'s GM1 finding: neither MISSING nor an ORPHAN, so every
   gate passes without ever running them. **Report-only; it never blocks `apply`** — a
   consumer must never be unable to take a fix because the fix newly-fails its own
   content. The updater OFFERS the write at step 7.
   **The two writes are atomic and that is the reason a tool exists.** An anchor with no
   `gate_types:` is an ORPHAN (exit 1); a `gate_types:` with no anchor trips GM2 (exit 2).
   A hand edit doing one half trades one FAIL for another, so an operator working down a
   23-item list is red the whole way and cannot tell progress from regression.
   **`--apply` requires `--gate-types` and there is no default.** The anchor is derivable
   from the heading id; the gate slice is not. The only inferable default, `universal`,
   would promote every adopted check to run at every gate — unauthorised, and invisible
   afterwards because an over-broad slice passes vacuously. The dry-run prints the
   question once per ENTRY (`gate_types:` is entry frontmatter), which is why the
   reference consumer's 23 checks are 4 questions and not 23.

3f. **Push-candidate ledger re-verify — the CLOSE path.** Run
   `reconcile/ledger-reverify.sh <dist-repo> <base-sha> <consumer-root> <theirs-ref>`.
   Step 8 APPENDS to the ledger; nothing ever closed it, so an entry upstream adopted stayed
   open forever and could be re-pushed. For each OPEN entry carrying a `verify:` line, this
   re-runs the entry's own receipt against `theirs`:
   - `CLOSE-CANDIDATE` → the innovation is now present upstream / the defect no longer
     reproduces. **Report-only; never blocks `apply`** (a close touches no core and cannot
     lose data). The operator confirms and annotates at step 8 — the tool never edits the
     ledger, exactly as `HARD-CORE-DRIFT-ABSORBED` never reverts a file itself.
   - `STILL-LIVE` → stays open, filtered from the report.
   - `NAMED-UPSTREAM` → upstream's own commit history NAMES this entry's id. Emitted **in
     addition to** the receipt's verdict, never instead of it: a receipt can be structurally
     incapable of ever closing (anchored on a token present at both refs, an inverted verb, or
     `verify: manual`), and then re-running it forever produces a confident wrong answer. The
     id is the one signal a rewording cannot defeat, because it is the join key the ledger, the
     report and the §8.1 fan-in already use. `STILL-LIVE` + `NAMED-UPSTREAM` on one entry is
     the highest-value pair this tool prints: the entry is absorbed AND its receipt is wrong.
     **Not auto-closable** — step 8 closes `CLOSE-CANDIDATE` rows only, so this needs no
     exception. It is not *unclosable*: the row instructs an annotation, and **any** occurrence
     of `ADOPTED UPSTREAM` in an entry makes `ledger-reverify.sh` skip it from the next run on.
     Write the form `ledger-rotate.sh` accepts — bolded, version immediately after the
     parenthesis — or the entry becomes skipped-but-unarchivable: invisible in every future
     report and never filed. `ledger-rotate.sh` now reports that set; it counted **8** on the
     reference consumer while printing "0 closed entries — nothing to rotate" in the same run.
     Read it as "upstream named it", not "upstream took it": a commit can name an id to record
     a rejection or a split. Confirm which, then re-anchor or drop the stale receipt.
   - `NAMED-UPSTREAM-AMBIGUOUS` → upstream's history cites this entry's SPRINT prefix
     (`PC-S<n>`), but two or more ledger entries share that prefix and the commit does not say
     which it absorbed. **Deliberately NOT attributed.** Upstream writes the short id, not the
     full slug — measured against it at 0.328.0, the slug search found 20 of 128 entries while
     20 of 29 prefixes appeared, and of those 20 prefixes only 9 named a single entry. Matching
     the prefix regardless would tell you to close entries upstream never touched, which is
     worse than the silence it replaces. Read the named commit and decide per entry. Like
     `NAMED-UPSTREAM`, **not closable** — it is a pointer to a reading, not a verdict.
   - `HAND-REVIEW` → the entry declares `verify: manual`. No mechanical predicate exists for
     it BY DESIGN; adjudicate the body against theirs. This is NOT an entry with no `verify:`
     line — that emits no row at all.
   - `NEEDS-REVIEW` → THREE causes. The DETAIL field names which; report them separately.
     - *unresolved* — the `verify:` line is malformed, or its path resolves neither as given
       nor by unique basename at theirs. Correct the path, then re-run.
     - *vacuous predicate* — the STILL-LIVE side was never reachable: a `theirs_has`
       substring absent at BOTH base and theirs, or a `theirs_lacks` substring present at
       both. Read the body and check whether the verb is inverted. **Never drain on this
       verdict.**
     - *unfalsifiable predicate* — a `theirs_lacks` substring absent at base, at theirs, AND
       from the consumer's own tracked tree, so no adoption can satisfy it and the entry
       reports STILL-LIVE on every pull. Re-anchor it per the rule below, or declare
       `verify: manual` if the entry is a proposal nobody has built yet. **Never drain on
       this verdict.** A DETAIL reporting reachability NOT checked means unchecked, not
       clean.
   - `ENTRY-SWALLOWED` → a line-leading `- **…**` **annotation** inside an entry body. The
     entry-boundary rule opens a new entry on any such line, so the annotation truncates the
     entry it was annotating: everything below it — **including the `verify:` receipt** — is
     attributed to the annotation, and the real entry stops emitting any row under its own id.
     A silent disappearance, and it reads exactly like an entry with nothing to report. The
     signal is the colon: an annotation is a lead-in (`- **The share:** …`) and its bold span
     ends in one, while an entry title does not. The DETAIL names the nearest id-shaped entry
     above it and says whether a receipt was captured. **Fix the ledger, not the entry** —
     re-indent the annotation so it does not start a line, or drop the bold, then re-run and
     confirm the id reappears. Report-only; it never blocks.
   - `RECEIPTS-UNDECIDED` → one row per run, emitted only when the count is non-zero: how many
     `theirs_has` receipts reported `STILL-LIVE` on a substring present at **base as well as
     theirs**. This pull moved neither side of those predicates, so their verdicts are
     restatements of the previous run rather than new measurements — the entry may be live or
     long fixed, and this run did not distinguish them. **A `STILL-LIVE` in that set is not
     evidence the defect survives.** An anchor on text the fix KEEPS survives the fix, and the
     entry can then never close. Measured on the reference consumer at 0.301.0: of five
     `STILL-LIVE` verdicts re-checked against the code by hand, **three were false**, every one
     anchored on text its own fix keeps, and only one of the three was visible to
     `NAMED-UPSTREAM`. It is a COUNT, not an accusation against any row — "present at both refs"
     is also the normal state of a genuinely live entry, so it cannot decide one. Re-anchor the
     receipts per the rule below, or read the code. **Do not read a zero `CLOSE-CANDIDATE` count
     from such a run as evidence that nothing was absorbed.**
   - `INPUT-UNRESOLVED` → an ARGUMENT does not resolve, so **nothing was re-verified**. Run-
     scoped rather than entry-scoped: the entry column carries the offending path. Two causes,
     named in the DETAIL — the consumer root is not a directory, or an explicitly-supplied
     arg-5 ledger path is not a readable file. This row exists because that state used to be
     spelled as **zero rows and exit 0**, which is exactly how a clean corpus is spelled, and
     the argument order is the trap: this tool takes consumer THIRD and theirs FOURTH while
     every sibling in `reconcile/` takes `<dist> <base> <theirs> <consumer>`. Fix the
     invocation and re-run before reading any other verdict from that run. **Never drain on a
     run that emitted this** — a zero close count from it means nothing was examined.
   **Anchor a `theirs_lacks` receipt on a token upstream MUST use, never on predicted
   prose.** The substring for a fix that does not exist yet is a guess at wording upstream
   has not written, so it closes only if upstream happens to pick the same words. Anchor on a
   status name, a flag, a filename, a manifest row — something the fix cannot be written
   without. A receipt that only matches one phrasing of a fix is a receipt for that phrasing,
   not for the fix.

   **Anchor a `theirs_has` receipt on a token the FIX MUST REMOVE.** The rule above protects
   the verb the unfalsifiability guard already covers; this one has no guard at all, and it is
   the verb most receipts use. A token that merely CO-OCCURS with the defect survives the fix,
   so the entry reports STILL-LIVE forever against a defect that no longer exists — and it
   passes every lint, because it is well-formed, its path resolves, and it is reachable at both
   refs. Real case: an entry about `emit-report.sh --verify` being bound to one dist checkout
   anchored on the rendered `full: diff <(git -C $DIST show` line. The fix landed in the
   COMPARISON (`--verify` now normalises the path on both sides), and the rendering was kept
   deliberately, so the anchor is still there and the receipt still says STILL-LIVE. Ask of the
   substring: *could the fix be written without removing this?* If yes, it is the wrong anchor —
   anchor `theirs_lacks` on the token the fix cannot be written without.

   **Never reproduce a receipt's substring in the core file that receipt tests.** A
   `theirs_lacks` receipt is satisfied by ANY occurrence in that file, including one written
   to discuss the receipt, so quoting it closes the entry with nothing behind the close.
   Name the entry; describe what it asks for.

   An entry with NO `verify:` line emits no row and is left to hand-review as today; the
   convention is opt-in and the ledger stays prose. The line is one of
   `theirs_lacks <core-path> "<substr>"` (innovation upstream lacks),
   `theirs_has <core-path> "<substr>"` (defect present upstream), `sh <one-liner>`
   (exit 0 = still reproduces), or `manual`. A `theirs_*` line MAY carry more than one quoted
   substring; all must match. Rendered into the step-5 report by
   `emit-report.sh`, so a CLOSE-CANDIDATE cannot be silently dropped.

4. **Semantic per-block classify** — for every file the pre-pass marked
   `…CLASSIFY`, dispatch ONE generic agent per file (batch trivial single-block
   diffs) using `reconcile/classify-block.md` as the prompt. Block granularity
   = per-file + per-numbered-item (rule / `###` section / check). Each agent
   computes the file's own base/theirs/ours three-way with git and returns
   structured per-block buckets. Agents return DATA (bucket tallies + only the
   conflict/flag details), never echoed file content — keeps the orchestrator
   context clean.
5. **Emit the dry-run report, then HARD STOP (unconditional).**

   **The mechanical sections are RENDERED by a driver, not narrated by you.** Run
   `reconcile/emit-report.sh <dist> <base> <consumer> <theirs>` and paste its
   `BEGIN/END GENERATED: reconcile-mechanical` region into the report **VERBATIM**. That region
   is the per-file buckets, the semantic worklist, deletions, the **blocking-layer list**,
   unregistered drift, layer drift, catalog relabel, and the push-candidate ledger re-verify —
   every mechanical finding, complete, from every detector. You write ONLY the genuinely semantic sections AROUND it: for each file in
   the region's "Semantic worklist", its 3-way merge result (`classify-block`), the conflict list,
   and the needs-confirmation questions. **Do NOT restate, summarise, or edit anything inside the
   region** — a mechanical finding narrated by you is a finding you can drop, and one already was
   (a HARD core-schema drift, twice). After writing the report, run
   `reconcile/emit-report.sh --verify <report> <dist> <base> <consumer> <theirs>`; **it MUST exit 0
   before the HARD STOP.** A nonzero exit means the region is missing, stale, or was hand-edited —
   the report is unsound; regenerate and re-emit. This check is not optional, and the operator can
   run the same `--verify` to trust any report without re-running the detectors by hand.

   Write
   `_bmad-output/ai-dlc-update/reconcile-report.md`: a header stating
   `Generated: <UTC timestamp> by ai-dlc-update skill_version <X> @ <sha>`
   (read `skill_version`/`skill_commit` from the stamp), then per-file +
   per-block bucket, proposed action, the push-candidate list, the conflict
   list, a **needs-confirmation list** — every block any classify agent
   returned with `needs_operator_confirmation: true` (per
   `reconcile/classify-block.md`), each with its specific question, listed
   separately from and in addition to the conflict list (a block can be in
   neither, either, or both), **plus every step-3c
   `EXTENSION-CHECK-NUMBER-COLLISION` tagged `NEW-THIS-PULL`** — that collision did
   not exist before this pull and this pull is what created it, so the operator
   learns of it here, at the moment it is introduced, rather than from a confused
   gate log months later. The question is: which catalog does a bare `Check <n>` in
   your gate log now mean, and when will this entry be relabelled `[ext:<id>]`? —
   a **settings-provisioning question**, obtained by
   running (no writes; `--template` needs a FILESYSTEM path, and `theirs` is a ref,
   so materialize it first — the bare `--check` form exits 1 with usage):
   `t=$(mktemp); git -C <dist> show "<theirs>:templates/settings.json.template" > "$t";`
   `reconcile/settings-merge.sh --consumer .claude/settings.json --template "$t" --check`
   — when it reports
   `model_row_needed=yes`, reproduce its `ask:` lines verbatim as an operator
   question (the model row: `1M` / `200K` / `auto`; default `auto`, which writes
   nothing). The answer is passed to `--model-row` at apply (step 7) — a
   **deletions list**: every
   `UPSTREAM-DELETED` **and `ORPHANED-RELOCATED`** path (upstream removed the file, or
   moved where it ships it and the stale copy at the old path is provably ours — for an
   orphan, name the path it now lives at, so the operator can see the file is being
   retired, not lost), consumer untouched,
   each with its reason line, since applying one `git rm`s a consumer file
   and is gated per-path at apply (step 7) — and a **template-changes
   list**: every `TEMPLATE-PROSE-MERGE` / `TEMPLATE-JSON-MERGE` file from step
   3b with a one-line summary of the upstream boilerplate delta being synced
   (e.g. "CLAUDE.md: remove Context-Mode Usage section") and, for any file
   that hit anchor-drift, its flag for adjudication — and, from step 3c, a
   **layer-drift list** (every `OVERRIDE-DRIFT-*` / `OVERRIDE-ANCHOR-UNRESOLVED` /
   `OVERRIDE-DELEGATES-INTO-SHADOW` /
   `EXTENSION-HOOK-DRIFT` / `EXTENSION-CHECK-NUMBER-COLLISION` entry with its target
   and reason — a collision tagged `NEW-THIS-PULL` ALSO goes in the
   needs-confirmation list below, because this pull is what created it), a
   **retirement list**
   (every `EXTENSION-RETIRE-CANDIDATE` and `EXTENSION-RESTATES-CORE`: the entry, the
   core section it duplicates, and the note that retirement is an operator-gated
   delete per Rule 27(b) — upstream never writes the layer, so it cannot remove the
   entry for you), and a
   **blocking-layer list** — this is part of the driver-rendered `reconcile-mechanical` region
   (step 5's `emit-report.sh`), which lists every `HARD-*` the detectors emit and blocks `apply`.
   Beneath the region, write each blocker's resolution command (a block with no path out is a block
   someone routes around), **with every placeholder resolved** — a command carrying a literal
   `<dist>` is a path the operator cannot walk without guessing, which is the same block one step
   later. Do NOT re-author the list from memory of the tool output — a `HARD-*`
   line was silently dropped from two real reports that way, hiding a data-loss-grade core-schema
   drift; `emit-report.sh --verify` now fails if the rendered list drifts from the tools.

   **A blocker DISPOSITION carries the command that verified it, exactly as a step-8 defect
   filing does.** Name the disposition (retire / readopt / reaffirm / refile / revert), then the
   literal command run and its decisive output line, then what you could NOT verify. A claim
   about WHY a detector emitted the row is an INFERENCE — label it or verify it. The asymmetry
   this closes ran the wrong way: filing a complaint against upstream already required a receipt,
   while deciding to RETIRE — which DELETES a consumer-owned override — required none, and it is
   the more destructive act. Treat every recommendation here as a hypothesis and run the command
   that would falsify it; in one real pull a defect was filed against a checker that was
   correctly obeying an over-wide declaration, and a version correction was itself three releases
   wrong because it sampled the refs already loaded instead of walking history.

   **Record the operator's answers in `_bmad-output/ai-dlc-update/blocker-adjudication-<ts>.md`.**
   A named, timestamped file, because the two destinations previously named for an answer cannot
   hold one: this report is a fixed filename overwritten by the next dry run (below), and
   `reconcile-log-<ts>.md` is not written until step 7 under `apply`. An answer recorded in
   either is an answer lost — three dry runs in one day is normal. The file records, per blocker:
   the disposition, its verification, the fully-resolved resolution command, and any answer the
   operator gave. It ends with one readiness line: all blockers decided and `apply` may proceed,
   or which remain open and what closes them. `apply` reads it; it is never a substitute for the
   `apply` argument, and writing it is not authorization to resolve anything. And a
   **catalog-relabel list** (step 3e: every extension check heading that needs the
   `[ext:<id>]` label, report-only).
   This is a fixed filename
   overwritten on every
   run (a snapshot, not a log) — the header stamp is what lets anyone tell a
   fresh report from a stale leftover of a prior invocation, since the
   filename alone can't.

   **Producing this report is the TERMINAL action of the run unless the
   invocation carried an explicit `apply` argument.** After writing it, STOP and
   return it to the operator. Do NOT branch-for-apply, write, re-stamp, commit,
   push, open a PR, or merge.

   **The stop is unconditional — the following DO NOT authorize proceeding, and
   inferring authorization from any of them is a defect:**
   - zero conflicts, an "obviously clean" pull, or an all-`apply`-bucket report;
   - the pull looking safe, small, or already-verified;
   - inferred operator intent, urgency, or "they clearly want the update";
   - the fact that applying would be convenient or save a round-trip;
   - the operator answering a question about the report, adjudicating a
     conflict, or asking for a specific fix ("restore X", "just fix the Y
     bullet") in the conversation while reviewing it.

   The ONLY authorization to move past this stop is an explicit `apply` argument
   on THIS invocation (e.g. `/ai-dlc-update apply`). A bare `/ai-dlc-update` is a
   dry-run: report and stop, every time, no exceptions. If the invocation did not
   contain `apply`, you MUST NOT apply — full stop. When unsure whether `apply`
   was given, treat it as ABSENT and stop. Never write "operator directed" into
   the report unless the operator's invocation literally contained `apply`.

   **Adjudication is not authorization to write (incident-confirmed failure
   mode — do not repeat it).** An operator resolving a conflict, or asking for a
   specific fix, while reviewing a dry-run report ("restore the dropped KISS
   bullet") is giving an ANSWER — record it in
   `_bmad-output/ai-dlc-update/blocker-adjudication-<ts>.md` for the `apply` run to act on.
   NOT in this report, which the next dry run overwrites, and not in
   `reconcile-log-<ts>.md`, which does not exist until step 7.
   It is NOT an instruction to edit any file right now.
   A real run misread exactly this: the operator adjudicated a conflict in
   conversation and the agent edited the live working tree immediately,
   uncommitted, off-branch, before `apply` was ever invoked. Every write,
   without exception, happens only inside step 6's isolated branch, reached
   only via an explicit `apply` argument on a fresh invocation — a one-line,
   obviously-correct fix is not a carve-out from that. If the operator gives
   you a fix mid-review, say so explicitly: "recorded — will apply on
   `untangle apply`/`apply`," and touch nothing.

   **Already-current case (empty reconcile).** If the report shows NO
   consumer-rulebook changes to apply — every bucket is noop/already-present, e.g.
   a self-update-only pull whose sole delta was the skill's own files — then the
   consumer core already equals `theirs` and only the `.ai-dlc-version` stamp
   lags. State this in the report: `consumer core already at <theirs>; stamp
   behind at <base> — re-invoke with 'apply' to advance the stamp (bookkeeping,
   no rulebook change)`. Do NOT advance the stamp on this bare run — re-stamping
   is a write, forbidden here like any other. The stamp advances under `apply`
   (step 7), which for an empty reconcile is a stamp-only bump.
6. **Isolate — branch before ANY write (apply only, MANDATORY).** The reconcile
   MUST NOT mutate the consumer's live branch in place. Before the first write
   in step 7:
   - Shell to git in the consumer tree. If it is not a git repo, STOP and tell
     the operator (no safe isolation possible).
   - If the working tree has uncommitted changes that would tangle the reconcile
     diff, STOP and report — let the operator stash/commit first. (A dirty tree
     unrelated to the rulebook may be fine; when in doubt, stop.)
   - Re-confirm the step-1 git preflight still holds: the branch is in sync with
     its upstream. Time may have passed since the dry-run, so if the branch has
     since drifted AHEAD of `origin` (or gained an upstream-less state),
     **auto-push** to re-sync exactly as in step 1 and continue; if it drifted
     BEHIND or diverged, STOP with the `git pull`/rebase remedy — the reconcile
     branch cut here must sit on a base that matches `origin`.
   - `git checkout -b ai-dlc-update/<theirs-version>-reconcile-<ts>` off the
     current branch. ALL step-7 writes land here, so the operator reviews a
     clean diff / opens a PR — never a silently-mutated working branch.
   This is a hard requirement, symmetric with the pipeline's own branch-per-unit
   discipline; the `_divergence/` archive (step 9) is a backstop, not a
   substitute for the branch.
7. **Apply — reached ONLY when the invocation carried `apply` (step 5), on the
   step-6 branch.** If there are conflicts, apply only operator-adjudicated
   resolutions; zero conflicts does not remove the `apply`-arg requirement — it
   only removes the adjudication sub-step.

   **Blocking-layer gate (step 3c `HARD-*` statuses).** If layer-drift reported
   **any status whose name begins `HARD-`** — match on the PREFIX, not on a list of
   names you remember; today that is `HARD-OVERRIDE-BASE-CONSUMER-SHA` and
   `HARD-OVERRIDE-BASE-UNRESOLVABLE`, and the set is meant to grow —
   STOP before any write. `layer-drift.sh` documents the prefix as the contract
   ("statuses prefixed HARD- must block `apply`") and the report above builds its
   blocking list from `HARD-*`, so enumerating the two names here instead would mean
   the next `HARD-` status anyone adds is silently non-blocking: it would appear in
   the report under "blocks apply" and then not block it.
   Those overrides have an unusable `base_sha`, so whether
   upstream changed the rule they shadow is **undecidable** — applying the core
   overwrite would let a stale override silently keep shadowing a rule that moved.
   `HARD-` is reserved for exactly that: a condition the tool cannot DECIDE. A
   decidable, consumer-fixable finding (e.g. `EXTENSION-CHECK-NUMBER-COLLISION`)
   must never be `HARD-`, or a consumer becomes unable to take a security fix until
   it has relabelled its own catalog — and someone will comment out the gate.
   Present each to the operator with the correct distribution sha to re-stamp
   (Rule 27(a)); apply only after they are fixed or the operator explicitly
   accepts the risk per entry. `apply` authorizes writes; it does not authorize
   proceeding on an undecidable override — the same distinction the deletion gate
   below draws. Never infer that an unresolvable base means "unchanged."

   **Mechanical union gate — the driver, not memory.** `apply` may write only after BOTH hold:
   (1) `reconcile/emit-report.sh --verify <report> <dist> <base> <consumer> <theirs>` exits 0 — the
   report the operator approved carries a current, complete mechanical region; a nonzero exit means
   the approval was given without sight of a finding, so STOP and re-emit rather than write; and
   (2) re-running the blocking list, every `HARD-*` is resolved —
   `reconcile/hard-blockers.sh <dist> <base> <consumer> <theirs>` prints `0 HARD blockers.`, or the
   operator has explicitly accepted each remaining one per-path. This is the gap that shipped a
   data-loss drift past two reports: the detector caught it, the narrated report did not.

   **THE ADJUDICATION LOOP — YOU do the work; the operator APPROVES it.**

   **First, run the resolution driver — it does the mechanical bulk.**
   `reconcile/apply.sh <dist> <base> <consumer> <theirs>` executes every MECHANICAL resolution and
   prints a tab-separated manifest. **Add `--carried-machinery-slice` — first, before the four
   paths — if and only if step 2 deferred its self-update and handed this run the machinery
   slice**; that is what advances the stamp's `skill_version`/`skill_commit` beside
   `version`/`commit` (see the re-stamp bullet at the end of this step).
   - `RESOLVED …` — already done, no operator step: pure applies (core overwritten from theirs),
     setup-token defaults (e.g. `gate-adjudicator` ← `adversary`'s model), **known-drift refiles**
     (`provenance-block.json` `known_skills` → `extensions/known-skills.json`, core reverted — the
     "migrate the drift" chore, automated), catalog relabels, and the version re-stamp.
   - `WORKLIST …` — the only things left for YOU: each `semantic-merge` (a BOTH-CHANGED 3-way PROSE
     merge, per `classify-block.md`) and each `override-readopt` (work it with the loop below).
   - **A row whose detail begins `<i>/<n> ATOMIC` is one step of an ORDERED SEQUENCE.** Do every
     step of that subject in the printed order and commit them together. Do not reorder them, do
     not land one without the others, and do not treat the last step as the whole item. The order
     is a safety property, not a preference: an `override-retire` sequence writes the replacement
     configuration BEFORE deleting the entry, because deleting first re-imposes the core
     constraint the entry was widening onto a consumer whose artifacts already violate it, and
     the next gate then fails on a tree you just repaired. Each step states its own consequence.
   - `DECISION …` — a genuine operator call: an unknown drift's refile-vs-revert, a deletion, a
     token with no default. Ask ONE closed question per row.

   Do NOT re-do a `RESOLVED` row by hand. Work only the `WORKLIST` and `DECISION` rows. **This is
   what makes the update end-to-end**: the operator runs it and it lands; you handle the semantic
   remainder, not the mechanical bulk.

   **IF THE MANIFEST CARRIES ANY `WORKLIST` OR `DECISION` ROW, THE RE-STAMP WAS WITHHELD AND THE
   PULL IS NOT OVER WHEN THE ROWS ARE.** You will see `DECISION restamp-withheld` in place of
   `RESOLVED restamp`, and `.claude/.ai-dlc-applying` is still on the consumer, blocking its
   fixture suite on purpose. Dispose of every row, then run the finisher — the re-stamp bullet at
   the end of this step has the command and the reason. A pull left un-finished leaves the
   consumer at `<base>` with its own gate refusing to run.

   Do NOT hand the operator a list of blockers and ask them how to respond. A blocker
   list is a to-do list with extra steps: it makes them hand-merge prose, hand-author
   YAML frontmatter, and hand-pick a `shadows:` anchor — the three things this repo has
   most often gotten wrong (four overrides have had to be anchor-repointed after
   naming a heading that did not exist, and drift detection was dead for each of them
   until it was). You have the tools. Use them, then ask ONE closed question per
   blocker.

   **First, read the newest `_bmad-output/ai-dlc-update/blocker-adjudication-<ts>.md`, if one
   exists.** It carries the dispositions the dry run verified and any answer the operator
   already gave, so a decided blocker is executed rather than re-litigated. Two rules on it:
   a row whose verification does not resolve against THIS run's refs is stale — re-verify it
   here rather than trusting it; and the file NEVER authorizes a write on its own. It records
   an answer; the `apply` argument on this invocation is what authorizes acting on it. A
   blocker absent from the file, or present with no disposition, is worked from scratch below.

   Work the `HARD-*` rows **one at a time**. For each:

   **(1) Build the evidence.** Run `reconcile/readopt-override.sh <dist> <theirs>
   <consumer> <override>` with no flag. It prints the dossier: the core section's
   `base_sha..theirs` diff, the override's body, its stated `reason:`, and the
   superseded core lines still sitting in that body.

   **(2) Decide, against the dossier, and say which and why in ONE sentence:**
   - upstream's change makes the override redundant → **retire**
   - the override's `reason:` still holds AND upstream changed the shadowed text →
     **readopt**
   - the override's `reason:` still holds AND upstream changed only text this override
     does not depend on (e.g. a prose/rationale edit elsewhere in the section) →
     **reaffirm**

   **(3) DO IT.**
   - **readopt** → `readopt-override.sh … --merge`. This is a three-way merge (base =
     core@`base_sha`, ours = the override body, theirs = core@`theirs`): it applies
     upstream's change and keeps the consumer's delta. **Never hand-edit the body when
     `--merge` can do it** — a hand-merge is where half an upstream clause gets
     silently dropped. On CONFLICT, markers are left in the body and that is the one
     place a human is genuinely required; present the conflict hunk, nothing else.
   - **`HARD-UNREGISTERED-CORE-DRIFT`** → `reconcile/register-drift.sh <dist> <base>
     <consumer> <core-rel-path> --apply`. It authors the `overrides/` entry from the
     consumer's own sections, anchors it to real headings, stamps `base_sha` at **base**
     (where the delta forked from — NOT the sha being pulled; stamping `theirs` would
     claim the consumer had already read a change it has not), and reverts core.
     **Then write the `reason:` line, which it leaves as `TODO`** — propose one from the
     diff and have the operator confirm it. An override whose reason nobody stated is
     one nobody can ever retire.
     If the delta merely **duplicates an existing override**, do not register a second
     one: revert core and say which override already carries it.
     `register-drift.sh` refuses by design on **two** classes, and both refusals are
     structural rather than a missing case. If it is a **hook**, the layer system has no
     override grain for hooks. If it is **`skills/ai-dlc-setup/*` or `schemas/*`**, the
     same is true for a different reason: overrides shadow a HEADING inside the ai-dlc
     skill, and a second core skill and schema data have no heading to shadow. Both are
     `scan`-marked, so the pull DOES report them and hands you this command — which then
     refuses. `validate-enforcement-map.sh` I31 binds the two lists so a newly scan-marked
     subtree cannot reach an unnamed refusal. In both cases the dispositions are: keep the
     consumer's version (accept per-entry, and it re-reports every pull), or upstream it.
     Reverting destroys the divergence; say so before anyone chooses it.
     Check the row's status before you conclude anything:
     if it is `HARD-CORE-DRIFT-ABSORBED`, the disposition below applies. Otherwise say
     so, and let the operator keep it (it will report every pull) or upstream it. Do not
     paper over it.
   - **`HARD-CORE-BEHIND`** → **the copy is stale; the remedy is TAKE THEIRS.** Do not reach
     for `register-drift.sh`: there is little here to refile, and an override authored from a
     three-month-old blob anchors to headings upstream may have rewritten. Read the residual
     the detail names — `git -C <dist> show "<ancestor>:<core-path>" | diff - <consumer-path>` —
     and dispose of THAT, not of the base-relative diff. Typically the residual is small and
     already absorbed upstream by another route, in which case take theirs and say which
     upstream mechanism now carries each piece. If part of it is genuinely still consumer-only,
     that part — not the whole file — is the override candidate.
     **A recurring per-entry acceptance on a `HARD-` row is the signal to check for this.**
     An acceptance excludes the file from `apply`, which is what freezes it, which is what
     makes the next pull's diff larger. Three consecutive pulls on the reference consumer
     accepted a "genuine fork" that was a stale file whose two additions upstream had already
     absorbed elsewhere.
   - **`HARD-CORE-DRIFT-ABSORBED`** → **upstream took this change; the remedy is a REVERT,
     not an override.** `unregistered-drift.sh` proves the consumer's added lines are
     already present in core at `theirs` (it reports the hit count and percentage). So the
     delta is not consumer-specific behavior to preserve — it is a duplicate of core, and
     keeping it means carrying a fork of a file upstream now maintains. Revert with the
     command the detail string hands you:
     `git -C <dist> show "<theirs>:<core-path>" > <consumer-path>`.
     **Before you propose it, prove nothing is destroyed**: diff ours against theirs and
     confirm no consumer-only guard, path, flag, or exit code exists in ours that theirs
     lacks. If something does, it is a genuine consumer delta wearing an absorbed file's
     clothes — escalate it as such and do not revert. This is the one `HARD-*` row whose
     resolution DELETES consumer text, so it is gated on an explicit operator yes like any
     other, with the diff shown.

   **(4) Ask the operator to approve THAT ONE disposition** — a closed question with
   your recommendation and its one-line reason, and the evidence you used. Not "how do
   you want to handle five blockers." Their answer is *yes* / *no, do X instead*.

   **(5) Stamp**: `--stamp readopt` / `--stamp reaffirm --note "<their words>"` /
   `--stamp retire`. `--stamp readopt` is refused while superseded core text or
   conflict markers remain, so a stamp cannot outrun the merge.

   Then **re-run `layer-drift.sh` and `unregistered-drift.sh` and require ZERO `HARD-*`
   rows.** Do not carry forward your memory of having discussed them: the re-run is the
   evidence, and re-stamping is what makes it pass. A `HARD-` status that clears because
   you decided it was fine is the check-that-cannot-fail defect, in the tool built to
   prevent it.

   **THE TWO SCRIPTS TAKE DIFFERENT BASES ON THIS RE-RUN, and one instruction for both
   disarmed one of them.** This paragraph used to read *"pass `theirs` as the base on this
   re-run, not the pull's base"* without qualification. That is right for one script and
   wrong for the other, and the wrong half is silent.

   - **`unregistered-drift.sh` — pass `theirs`.** It measures the consumer against
     `<base-sha>` and presumes core still sits there. Core is now at `theirs`, so the pull's
     original base reports every line upstream ADDED as a consumer addition upstream
     absorbed — `HARD-CORE-DRIFT-ABSORBED` on a file `apply` just wrote, whose remedy is a
     revert to what it already is. The post-apply base IS `theirs`; that is the only base
     against which "consumer edits vs base" means what these status names claim.
     `CORE-AT-THEIRS` rows are the tell that the base was stale.
   - **`layer-drift.sh` — pass the PULL's base.** Its subject is what moved between base and
     theirs, not what the consumer edited. Most `ADJUDICATED` clauses are computed over
     that range, and `HARD-LAYER-ADJUDICATION-MISSING` (**LC-A1**) is demanded only on rows
     a clause at that level produces. With `base == theirs` those arms find no drift, so no
     adjudication is demanded, so the check cannot fail, and `hard-blockers.sh` prints a clean
     sheet on a tree where the verdicts are still owed. **Do not read a clause list here — a
     list of that set has already gone stale once, on the release that changed it.** Not every
     clause at this level is range-keyed: **LC-O15** (`OVERRIDE-SUPERSEDED`) compares a
     declaration at theirs against the entry on disk, so a degenerate range leaves its duty
     live and its rows above are real. Ask the reader which codes the version you are pulling
     holds you to: `layer-drift.sh --adjudicated-codes <dist> <theirs>`.
     Reported by the reference consumer — `0 HARD blockers.`
     with eighteen adjudications unrecorded — and reproduced on a scratch consumer: same
     tree, the pull's base gives `EXTENSION-HOOK-DRIFT` + `HARD-LAYER-ADJUDICATION-MISSING`,
     `theirs` gives `EXTENSION-OK` and nothing else. The register's own digest is
     spend-on-move, so re-running on the pull base cannot re-demand a verdict recorded this
     run.

   **You do not have to remember this.** `layer-drift.sh` emits `DRIFT-RANGE-DEGENERATE` when
   its two refs resolve to the same commit, naming the arms that cannot fire. If you see that
   row, the run said nothing about the layer — re-run it with the pull's base.

   **Re-running the WRAPPER post-apply takes a flag, and without it the wrapper is wrong
   whichever base you give it.** `reconcile/hard-blockers.sh` drives both detectors, so a single
   base has to be wrong for one of them: the pull's base makes `unregistered-drift.sh` report
   `HARD-UNREGISTERED-CORE-DRIFT` against text `apply` itself just wrote, and `theirs` disarms
   the arm above. Post-apply, call it as
   `reconcile/hard-blockers.sh --post-apply <dist> <pull-base> <consumer> <theirs>` — it passes
   `theirs` to `unregistered-drift.sh` and keeps the pull's base for `layer-drift.sh`. It also
   renders the `DRIFT-RANGE-DEGENERATE` row now, which its `HARD-`-only filter used to discard;
   a `0 HARD blockers.` line with that row beneath it is not a clean sheet.

   **Dispose of every `WORKLIST extension-reread` row — this is *the layer conformance
   adjudication*.** `apply.sh` emits one per `EXTENSION-HOOK-DRIFT`: the core file the extension
   hooks changed, and an extension has no section anchor, so nothing can locate what to
   re-merge. Read the entry against the new core text and record a verdict per entry —
   **still-additive**, **contradicts-core**, or **retire**.

   **Recording is now the mechanism, not a note to self.** `layer-contract.yaml` carries these
   clauses at `level: ADJUDICATED`: the candidate set is mechanized and the verdict is yours.
   `layer-drift.sh` emits `HARD-LAYER-ADJUDICATION-MISSING` (**LC-A1**) for every such row with
   no recorded verdict, and a `HARD-` status blocks `apply`. Write one JSON object per line into
   `_bmad-output/ai-dlc-update/layer-adjudication-register.jsonl`, shape in
   `.claude/schemas/layer-adjudication-register.json`, copying `subject_digest` **verbatim from
   the blocking row**:

   ```json
   {"clause":"LC-E4","entry":".claude/skills/ai-dlc/extensions/checks/gate-validation-domain.md","subject_digest":"<copied from the row>","verdict":"still-additive","recorded_utc":"2026-07-29T10:00:00Z","reason":"core's change was to the gate-type enum; this entry adds a check row and does not restate it"}
   ```

   **If the verdict leaves work OWED, declare it — do not write it into `reason`.** A
   `still-additive` that is only true because somebody intends to fix something has recorded a
   decision and lost the obligation. Add an `owed` object (`id`, `what`, optional `closes_when`)
   and a later row discharges it by naming the id in `closes_owed`; the register is append-only,
   so a debt is never closed by editing the row that opened it. Measured on the reference
   consumer before this existed: 46 rows, verdict distribution 45 `still-additive` / 1
   `contradicts-core` / 0 `retire`, with four rows carrying obligations reachable only by
   grepping prose — one of which said, in as many words, *"Nothing but this reason field is
   tracking that debt."*

   ```json
   {"clause":"LC-E4","entry":"…","subject_digest":"…","verdict":"still-additive","recorded_utc":"…","reason":"…","owed":{"id":"OWED-921-SPLIT","what":"split Check 921 into an overrides/ entry shadowing core Check 20","closes_when":"after this pull's apply"}}
   ```

   **Run `scripts/ai-dlc/audit-layer-debt.sh` and put its OPEN, UNDECLARED and
   CONTRADICTS-CORE-WITHOUT-AN-`owed` lists in the report, every pull.** OPEN is what this
   consumer owes; UNDECLARED is the migration backlog — rows whose prose reads like an
   obligation while declaring none. A debt nothing enumerates is a debt nobody acts on, which is
   the whole reason the field exists.

   The third list is the one that cannot be re-derived. A `contradicts-core` verdict is a
   judgement no detector can reach — that is stated where the verdict is defined below — and it
   is keyed on a `subject_digest` that expires the next time the entry or its hooked core file
   moves. After that the ruling is not overwritten; it is unaddressable, and every later row on
   the entry carries a different digest and so disagrees with nothing. `owed` is the only handle
   in this register that survives a digest change, because the debt join reads `owed.id` and
   never a digest. **Scoped per ENTRY, not per row**: the register is append-only, so a
   historical row can never acquire an `owed`, and the debt is declared by a later row — which
   is how both real ones on the reference consumer were in fact recorded.

   **TO RE-READ A KEY YOU HAVE ALREADY RECORDED A VERDICT UNDER, run
   `layer-drift.sh --list-adjudications <dist> <base> <theirs> <consumer>`.** It prints every
   keyed subject this pass can see — entry, target, `subject_digest`, and the recorded verdict
   if there is one — and nothing else: no classification rows, no blockers, and no dependence on
   whether the row is still blocking. Pass the SAME base the pull uses, for the reason step 7
   states per script: base decides which rows the pass produces, so a degenerate range gives a
   short listing rather than a visibly missing one. **Do not withhold the register to re-fire the
   block.** That was the only way to read a key before this mode existed, and it means
   deliberately breaking your own gate state to read a value the tool already computed. You need
   the key AFTER the first write more often than before it: updating an `owed` object, and
   re-verifying a subject, both name it.

   The digest covers the entry AND the core file it hooks at `theirs`, so a verdict is spent the
   next time either one moves. It is a record of a reading, not an exemption for a path — which
   is why the register is keyed per SUBJECT and never per run. Changing your mind is allowed and
   has to be declared: a second record under one key stating a different verdict needs
   `supersedes` and a `reason`, or it is `HARD-REGISTER-CONTRADICTION` (**LC-A2**), because
   otherwise a lookup answers with whichever record happened to be read last.

   `contradicts-core` is the verdict `layer-drift.sh` cannot reach on its own. It emits
   `EXTENSION-RESTATES-CORE` when an extension COPIES a core section, but an extension that
   asserts the opposite of core in its own words restates nothing and matches nothing —
   `extensions/README.md`'s "Additive only" has no detector, and an extension carries no
   `base_sha` to compute one against. This re-read is that check. Do not add a textual
   contradiction detector instead: agreement between two prose rules is not a substring
   property, and a scanner that guesses would fire on every extension that legitimately
   narrows a core default.

   **Post-apply, verify against the RENDERED pipeline, never against core alone.** A
   core fix is effective only if it survives `overrides > extensions > core`
   resolution. After the core overwrite, for every override you re-adopted, grep the
   OVERRIDE for the new clause — that is the text the lead actually obeys. Core
   containing the fix proves nothing about a section the consumer shadows.

   **Offer the catalog relabel (step 3e).** Run `reconcile/relabel-extension-checks.sh
   <consumer-root> --apply` once core is in place, since the collision set is defined
   against the NEW core. Then run `scripts/ai-dlc/validate-layer-entries.sh` and report its
   errors/warnings in the apply summary. This never blocks the apply.

   **Offer the extension-check adoption (step 3ea).** Run
   `reconcile/adopt-extension-checks.sh <consumer-root>` once core is in place — the
   anchor set it subtracts against is the NEW core's, so a check the incoming release
   started anchoring drops out on its own. Put its per-entry `gate_types:` question to
   the operator and apply only their explicit answer, one entry at a time:
   `--apply --gate-types <list>`. Never guess the slice; refusing is what the tool does
   on its own if you pass `--apply` without it. Re-run
   `scripts/ai-dlc/validate-gate-manifest.sh` afterwards and report its verdict in the
   apply summary. This never blocks the apply.

   **Flagged-block checkpoint (mid-apply, every block, not just conflicts).**
   Before executing a block's mechanical bucket action, check whether it (or
   its file, if flagged at file grain) carries `needs_operator_confirmation:
   true` from `classify-block.md` — this is orthogonal to bucket; a
   `domain-local` or `innovation` block can still need one. Being inside an
   authorized `apply` run on the step-6 branch does NOT waive this: writing is
   authorized here, but a specific judgment call the classifier flagged is
   not resolved by that authorization. When you reach such a block: STOP
   before acting on it, present its specific question to the operator (same
   footing as a conflict), and apply only their explicit answer for that
   block — never your own best guess, and never silently fall through to the
   bucket's default action because the rest of the run is "obviously fine" to
   continue. A real run hit this: two blocks a dry-run report explicitly
   flagged for operator review (a naming/kind decision, a genuine 3-way
   prose blend) reached `apply` with no formal gate forcing the question to
   actually be asked — nothing stopped the bucket's default action from
   silently deciding them. This checkpoint is that gate. Applies identically
   in untangle's 7u below.
   - apply-bucket blocks → write theirs into ours (path-mapped). If the file
     is listed in `reconcile/setup-sites.md`, run the **mask/reinject
     transform** (below) instead of a blind overwrite — extract the
     consumer's live values at each declared site before writing theirs, then
     reinject them at the same sites afterward. A blind overwrite of a
     manifest-listed file blanks the consumer's real model strings/ownership
     paths/deploy commands back to `{placeholder}` tokens — this happened
     once (the reverted Phase-2B spike) and must not happen again.
   - `UPSTREAM-ONLY-ADD+SETUP-TOKENS->SUBSTITUTE` → **a NEW core file carrying
     setup-substitution sites. mask/reinject CANNOT do this one**: that transform
     reinjects the CONSUMER's live values, and a file the consumer does not have yet
     has none to extract. A blind copy leaves `{token}` on a live line, and the
     leftover-token gate below then blocks delivery after every other write has
     landed. Substitute BEFORE the write: for each site `setup-sites.md` declares on
     that path, **ask the operator one closed question**, proposing the value the
     consumer already uses for its nearest-equivalent role as the default (for a new
     team-role's `/model`, that is the role with the same effort tier — `adversary`
     for a high-effort reviewer). Then write theirs with the answers substituted in.
     Every role file predates the consumer's install, so `ai-dlc-setup` filled these
     tokens once and the pull never had to. This bucket exists for the case that
     breaks: a template-bearing core file that postdates the consumer's install, of
     which `team-roles/remediator.md` is one.
   - keep/domain-local/innovation blocks → leave ours; for domain-local, layer
     theirs' non-conflicting additions; for innovation, append to the
     push-candidate ledger.
   - conflicts → apply only operator-adjudicated resolutions.
   - `UPSTREAM-DELETED` files (upstream removed the file, consumer untouched
     vs base) → **`git rm` the consumer file, but ONLY after an explicit
     operator confirmation for that path.** Deletion is destructive and
     irreversible in a way an overwrite is not, so every `UPSTREAM-DELETED`
     path is gated exactly like a flagged block: at the dry-run report (step
     5) it appears in a dedicated **deletions list** with the reason
     (`upstream removed <path> at <theirs>; consumer copy unmodified since
     base`), and mid-apply you STOP at each such path and apply the removal
     only on the operator's explicit yes for that path. Never batch-approve
     deletions, and never infer approval from the `apply` argument — `apply`
     authorizes writes, not this specific destroy. A `UPSTREAM-DELETED-NOOP`
     path (consumer already lacks it) is a silent noop — nothing to remove,
     no gate. A `UPSTREAM-DELETED+consumer-modified` path went through
     semantic classify (the consumer changed a file upstream then deleted):
     treat the classifier's finding as a **conflict** — the consumer's
     modifications may be an un-pushed innovation worth preserving as an
     extension rather than deleting; operator adjudicates, default keep-ours.
   - `ORPHANED-RELOCATED` files (this distribution moved where it ships a subtree;
     the copy left at the old consumer path still hash-matches the blob we wrote
     there) → **`git rm` the stale copy, under the exact same per-path operator
     gate as `UPSTREAM-DELETED`.** Same destructiveness, same rule: never
     batch-approve, never infer approval from the `apply` argument. State the new
     path in the prompt — the file is being *retired*, not lost, and an operator who
     cannot see that will refuse a safe deletion. `ORPHANED-UNKNOWN` and
     `ORPHANED-RELOCATED+consumer-modified` are **never deleted**: the first is a
     file upstream never shipped, the second the consumer edited, and the pull only
     ever proposes destroying bytes it can prove it wrote. Both go to the operator
     as conflicts, default keep-ours.
   - `TEMPLATE-PROSE-MERGE` files (`CLAUDE.md`, `coding-conventions.md`,
     `QUICKSTART.md` — from step 3b) → run the **marker-anchored mask/reinject
     transform** in `reconcile/template-sites.md`: capture the consumer's
     filled config at each `{token}` fill region, apply the upstream
     base→theirs boilerplate delta, reinject the captured config. The
     boilerplate-only shortcut applies when the delta touches no fill region
     (the Context-Mode Usage removal is this case). On anchor-drift (a
     base-template token/marker not locatable in the consumer file), STOP and
     flag that file for operator adjudication — never best-effort-place a
     preserved value.
   - `TEMPLATE-JSON-MERGE` (`.claude/settings.json` — from step 3b) → run
     `t=$(mktemp); git -C <dist> show "<theirs>:templates/settings.json.template" > "$t"`
     then `reconcile/settings-merge.sh --consumer .claude/settings.json --template
     "$t" --model-row <operator's answer>`. `--template` is read with `-r` and
     `theirs` is a git ref, so a ref-qualified template path fails the read guard.
     **Do not hand-write the jq** — the script is the contract. It strips stale
     `ai-dlc-*.sh` hook blocks + appends the template's, and preserves user
     permissions/env/mcpServers/statusLine. It also provisions
     `.env.AI_DLC_MODEL_ROW` when (and only when) that key is absent and the
     template wires `ai-dlc-context-sensor.sh` — the question was raised in the
     step-5 report; pass the answer here. Omit `--model-row` (or pass `auto`) to
     write nothing. An existing value is never overwritten.
     `enabledPlugins` is additive-only and
     NEVER removed: a plugin the template dropped since base (e.g. ai-dlc's own
     `context-mode@context-mode` decommission) removes ai-dlc's *use* of it,
     not the consumer's right to keep it enabled — the consumer's
     `enabledPlugins` is preserved in full. Disabling a plugin is the
     consumer's decision, not the reconcile's.
   - (The skill's OWN files are NOT touched here — they were already refreshed by
     the autonomous self-update cycle in step 2.)

   **Leftover-token gate — hard, runs after the last write, blocks delivery.**
   After every overwrite above and BEFORE the re-stamp, grep the consumer's core
   for a template token that survived on a LIVE line:

   ```
   grep -rn '{[a-z_]*}' <consumer>/.claude/team-roles/ | grep -v '<!--'
   ```

   A hit is a FAIL. STOP before the re-stamp and name the file and the token — then
   tell the two causes APART, because they have opposite remedies:

   - **The site is NOT declared in `setup-sites.md`.** The overwrite blanked a live
     consumer value back to its `{placeholder}`. Add the missing site to
     `setup-sites.md` and redo that file's overwrite through **mask/reinject**.
   - **The site IS declared, and the file is NEW to this consumer** (bucket
     `UPSTREAM-ONLY-ADD+SETUP-TOKENS->SUBSTITUTE`). Nothing was blanked — the file has
     simply never been through `ai-dlc-setup`, so there was no consumer value to
     reinject and mask/reinject is the WRONG tool. Substitute the declared sites from
     the operator's answer (step 7), then rewrite the file.

   Do not deliver a tree that dispatches a teammate against an unfilled `{token}`.

   Exclude `<!-- ... -->` doc comments — those legitimately carry the token text
   and MUST survive from `theirs` (per the mask/reinject transform, the doc
   comment is not part of the captured span). The token only matters on a live
   line. Match the same idea for non-role manifest files (`steps/*.md`), whose
   sites are commands and paths rather than `/model` strings.

   **Setup-site drift gate — the OTHER direction, and it is a script.** The gate
   above catches theirs' `{token}` surviving where the consumer's value belonged.
   This catches the reverse: OURS surviving where THEIRS's content belonged.

   ```
   reconcile/setup-site-drift.sh <dist> <consumer> <theirs>
   ```

   Exit 0 required, same place in the sequence — after the last write, before the
   re-stamp. It asserts that every file declaring a setup site equals `theirs`
   byte-for-byte outside that file's declared spans, and names the file and line
   where it does not.

   **Its failure direction is upstream content NOT ARRIVING**, which is why it is
   worth a program: the pull reports success and the consumer is quietly behind,
   with nothing downstream disagreeing. Measured on the reference consumer during
   the 0.297.0 → 0.300.0 hop, `deploy-validate.md` kept OURS at line 26 — outside
   both of that file's declared spans — and the line it kept prescribed the OLD
   artifact-path grammar that release had just replaced. It surfaced only because
   `HARD-CORE-BEHIND` flagged it independently: the safety net working, not the
   mechanism working.

   **This existed as prose and the prose was not enough.** §7v criterion 5 states
   exactly this rule, was untangle-only, and has already reported PASS on an
   instance of it (`dev.md`, three of theirs' model-option comment lines) — because
   the agent asked to check the transform is the agent that just performed it.

   *Why this exists.* `untangle`'s §7v criterion 4 already asserts "zero remaining
   `{...}` tokens in any team-role file" — but 7v is untangle-only, and the
   ORDINARY pull had no equivalent, so a manifest miss landed silently on the one
   path consumers actually run. It did: a role file carrying model tokens shipped
   while `setup-sites.md` went untouched for nine minor versions, so the manifest
   did not declare that role's model sites at all. The first
   consumer pull to touch that file would have overwritten a live
   a live opus model string with that role's unfilled placeholder and broken
   every adversary dispatch — with nothing in the run to catch it. A manifest is a
   hand-maintained list and WILL go stale again; this gate is what makes the next
   staleness loud instead of silent.

   Role files carry no model string, so no model site can be omitted from the
   manifest. This gate covers the sites that remain — ownership paths and
   deploy/smoke commands.

   **Hook-registration gate — hard, runs after the last write, blocks delivery.**

   ```
   scripts/ai-dlc/validate-hook-registration.sh
   ```

   Exit 0 required, same place in the sequence as the two gates above — after the
   last write, before delivery. It asserts that every `.claude/hooks/ai-dlc-*.sh`
   on disk is registered in `.claude/settings.json`, and that every registration
   names a hook that is there. Both sides are derived; nothing is hand-listed.

   A nonzero exit is a FAIL. STOP and run the settings reconcile — the
   `TEMPLATE-JSON-MERGE` bullet above is the same command — then re-run this gate
   until it exits 0. Exit 2 means the check could not run at all, which is a FAIL
   for the same reason: an unknown reads exactly like a clean.

   *Why this exists.* The two halves of a hook delivery are enforced differently.
   `apply.sh` writes the hook FILE mechanically, with a manifest row. The
   REGISTRATION is `settings-merge.sh`, and its only invocation sites in the whole
   distribution are prose — the two in this file. A pull that skips them ships a
   hook that is on disk, looks installed, and never fires, with no error and no
   absence anywhere to notice. `apply.sh` now emits a `WORKLIST settings-merge` row
   naming each such hook at the moment it creates the state; this is the gate that
   makes the row impossible to walk past.

   *Why it does not key on the `TEMPLATE-JSON-MERGE` bucket.* That bucket is a
   DELTA — preclassify emits it only when the template itself moved between `base`
   and `theirs`, and `TEMPLATE-UNCHANGED-NOOP` otherwise. A consumer whose
   settings.json went stale on an EARLIER pull produces no delta at all, so the
   bucket is silent on exactly the tree that is already broken. This gate reads
   disk state, so it fires on that tree too. Measured on the reference consumer
   while it was written: `ai-dlc-rules-floor.sh` — which `install.sh` calls "the
   SINGLE detector, running every session" — present and unregistered for six
   releases, across pulls that reported success.

   - Re-stamp the rulebook base: set `version`/`commit` = `<theirs-version>` /
     `<theirs-sha>`, **preserving `skill_version`/`skill_commit`/`installed_at`/
     `upstream`** (rewrite the whole stamp in schema — never collapse it to the
     legacy single line, which would drop the skill version and upstream URL).
     **`apply.sh` does this; you do not edit the stamp.**

     **THE ONE EXCEPTION, AND IT IS A FLAG RATHER THAN A JUDGEMENT CALL.** If step 2
     reported `SELF-UPDATE-DEFER`/`SELF-UPDATE-UNDECIDED` and handed its machinery
     slice to this apply, then this run DID install machinery, and the skill pair
     must advance with the rulebook pair — run
     `reconcile/apply.sh --carried-machinery-slice <dist> <base> <consumer> <theirs>`
     and it writes all four. Preserve is the default because a rulebook-only apply
     must not claim a machinery version it did not install; advance is correct only
     when it did. Withholding still applies to BOTH pairs or neither: a mechanical
     failure holds the machinery pair back exactly as it holds the rulebook pair.

     *Why this is a flag.* A stale `skill_commit` is not cosmetic.
     `unregistered-drift.sh` suppresses a machinery file as `CORE-AT-SELF-UPDATE`
     when it is byte-identical to the distribution at `skill_commit`, which it reads
     from this stamp. Leave the field behind and every machinery file this apply
     wrote from theirs reads as consumer drift on the next pull, with a printed
     remedy that reverts upstream's own text. That is the same false-drift failure
     the intermediate-ref suppression exists to prevent, reaching the operator
     through the stamp instead of through the scan.
     **The re-stamp
     fires whenever the consumer core now equals `theirs` — INCLUDING an empty
     reconcile (zero rulebook blocks applied, e.g. a self-update-only pull). In
     that already-current case this step is a stamp-only bump: the point of the
     `apply` run is to advance the stamp; the log records "already current, stamp
     advanced <base> → <theirs>." Without this, a skill-only pull would leave the
     stamp stuck forever and every later pull would re-diff from a stale base.**

     **THE STAMP IS WITHHELD WHILE ANY ROW IS OUTSTANDING, AND `--finish` IS HOW YOU
     ADVANCE IT. THIS IS A REQUIRED STEP, NOT A RECOVERY PATH.** The first `apply.sh`
     run of a pull that hands back ANY `WORKLIST` or `DECISION` row now emits
     `DECISION restamp-withheld` instead of `RESOLVED restamp`, leaves the stamp at
     `<base>`, and leaves `.claude/.ai-dlc-applying` in place — so the consumer's
     `pre-push` keeps refusing the fixture suite. That is correct: the tree really is
     a mixture until you have done the rows. **When every `WORKLIST` and `DECISION`
     row above is disposed, run
     `reconcile/apply.sh --finish [--carried-machinery-slice] <dist> <base> <consumer> <theirs>`.**
     It does the stamp and the marker clear and NOTHING else — it runs no resolution
     phase, so it cannot undo or redo your merges. Carry `--carried-machinery-slice`
     through to it if the first run had it; the withheld row prints the exact command,
     flag included.

     *Why a second invocation rather than a smarter first one.* The rows are work YOU
     complete after this program has exited, so there is no moment during the first run
     at which the stamp is true. And the finisher cannot simply re-run the phases: a file
     you semantically merged keeps a consumer delta by definition, so it re-buckets
     `BOTH-CHANGED->CLASSIFY` on every subsequent run and the hand-back would never
     clear. Filed by the reference consumer as
     `PC-S304-APPLY-SH-RESTAMPS-BEFORE-THE-WORKLIST-IS-DONE`, reproduced across two pulls
     a month apart — one run printed `RESOLVED restamp` beside 37 outstanding rows. The
     stamp is the next pull's merge base, so an abandoned apply left a tree claiming to
     be at theirs, and the un-merged files then read as `ALREADY-AT-THEIRS` to every
     detector that compares against it.

     *What `--finish` still checks.* It runs the hook-registration validator FIRST and
     withholds again on a `WORKLIST settings-merge` row, because by then the settings
     merge has happened and the answer is verifiable rather than attested. It does not
     gate on a `DECISION` row: those you have already adjudicated, or they are the tool
     saying it could not look, and gating on one that cannot clear would wedge the
     consumer with no exit.

   - **YOU write `_bmad-output/ai-dlc-update/reconcile-log-<ts>.md`, and `apply.sh` does NOT.**
     Write it LAST, after the post-apply re-runs, because it records them. It carries the gates
     before the first write, the apply manifest, the stamp transition, the post-apply re-runs on
     their own bases, the validator outcomes, the ledger decisions, and what was deliberately not
     done.

     *Why this is its own bullet.* It used to sit inside the re-stamp paragraph above, one
     sentence after "**`apply.sh` does this; you do not edit the stamp**" — so a reader
     reasonably attributed both to the tool, and the reference consumer filed exactly that
     (`PC-S329-APPLY-SH-NEVER-WRITES-THE-RECONCILE-LOG`). Measured when they did: **zero
     occurrences of the token in `apply.sh` against nine files here that name the artifact** —
     the contract stated everywhere except in the program a reader took to be honouring it.
     The run succeeded, the stamp advanced, and the only durable record of what the apply
     decided was absent.

     *Why the tool does not write it instead.* Every section above except the manifest and the
     stamp is outside what `apply.sh` can observe. A skeleton it could fill would ship a file
     whose empty sections read as written ones. **It says so on every successful run** — naming
     this path and stating that it does not write it — because prose alone is what failed here
     the first time.

### Mask/reinject transform (setup-substitution sites)

Some core-manifest files carry consumer config `ai-dlc-setup` filled in at
install time — model strings, ownership paths, deploy/smoke commands — living
inside otherwise upstream-owned files (team-role files, `deploy-validate.md`,
`implementation.md`). These are consumer config, not rulebook divergence, and
a plain overwrite would destroy them. `reconcile/setup-sites.md` is the
declared list of every such site (file, anchor, capture pattern). This
transform is used by BOTH step 7 above (every ordinary pull, once any manifest
site exists) and by `untangle` mode's core-overwrite below — it is not
untangle-specific.

For each file listed in `setup-sites.md`, before overwriting with `theirs`:
1. Locate each declared site in `ours` (its regex `match`, or its
   `heading`/`next_heading` span) and extract the captured value(s).
2. Overwrite the file with `theirs` — **the complete `theirs` content,
   verbatim**. This is a genuine whole-file replacement: theirs' surrounding
   structure (HTML `<!-- ... -->` config comments, blank lines, adjacent
   prose) is what the file now IS. Do NOT carry over `ours`'s structure around
   the sites — the whole point is that core becomes byte-reconcilable with
   theirs everywhere except the declared value spans.
3. Re-locate each site by the SAME locator in the freshly-written `theirs`
   content and reinject ONLY the extracted value into the captured span
   (single-line sites) or the heading-block body (heading-block sites).
   Touch nothing outside the captured span — a single-line site's
   `<!-- {token} -->` doc comment two lines up is NOT part of the span and
   MUST survive from `theirs` untouched. After reinject, the file must equal
   `theirs` byte-for-byte EXCEPT inside the declared site spans; if it differs
   anywhere else, the transform over-reached — redo it from a clean `theirs`
   copy.
4. **Anchor-drift:** if a site's locator cannot be found in the freshly-written
   `theirs` content (upstream restructured or reworded that section), STOP and
   flag the site for operator adjudication in the report/log — do not drop the
   value, and do not guess a new location for it.

**Setup site inside an overridden section.** A setup site can sit inside a
section that ALSO has a consumer `overrides/` entry shadowing it (e.g. a
`#Identity` override on a team-role file whose model `/model` lines are
declared sites within that same section). These are two independent layers and
must not be conflated: **core** is still restored to `theirs` verbatim and the
setup value reinjected into its span (per above) — core stays byte-reconcilable;
the **override** shadows the section at load time per Rule 27 (`overrides >
core`) using its own body, which describes only its deliberate change (e.g.
"remove the Local (Ollama) bullet") and explicitly does NOT restate the setup
`/model` lines (those live concrete in core and are reinjected there, not in
the override). Do NOT let the override's presence cause core to keep `ours`'s
structure at the site — that is the exact over-reach step 3 forbids, and it
leaves a non-site core deviation from theirs that the §7v gate (criterion 5)
must catch.

This is why "Layered consumers" below is a fast-forward everywhere EXCEPT at
declared sites, not everywhere unconditionally.

8. **Deliver — branch → commit → push → PR → merge.** The reconcile is landed
   through the consumer's normal review flow, never force-written to the working
   branch:
   - **Commit** all step-7 writes on the step-6 reconcile branch, with a subject
     like `chore(ai-dlc-update): reconcile distribution <base-ver> → <theirs-ver>`
     and a body summarizing buckets applied + conflicts adjudicated + the log path.
   - **Push** the reconcile branch to the consumer's remote (`origin`). If there
     is no remote or push fails (a local-only consumer), STOP here and hand the
     operator the local branch + diff to merge manually — do not silently drop
     the work.
   - **Open a PR** into the working branch (`gh pr create`), body = the reconcile
     report summary (buckets, conflicts, push-candidates).
   - **Merge ONLY on explicit operator approval of the PR.** This is a second,
     independent gate — separate from the `apply` arg that authorized the write.
     The skill does NOT auto-merge. None of the following authorize a merge: zero
     conflicts, a clean diff, the `apply` arg already given, or inferred intent.
     Present the PR and wait for the operator to approve it; only then merge
     (squash, delete branch). On merge, the re-stamp + log + changes reach the
     working branch.
   - Drain any `push_candidate`-flagged extensions into the push-candidate ledger
     for a later upstream push-mine (spec §8.1).
   - **Drain the defects this run found in UPSTREAM's own tooling** into the same ledger,
     one entry each, with a `verify:` line. Every other drain here moves a CONSUMER
     artifact; this is the other source, and it had no path. A pull is the best detector
     of these defects — it is the only context that runs `reconcile/*` end-to-end against
     real divergence — and what it finds otherwise lands in `reconcile-report.md` under a
     follow-ups heading that nothing re-reads and the next run overwrites (step 5: "a
     fixed filename overwritten on every run, a snapshot, not a log"). A refusal, a status
     with no actor, a remedy that cannot be executed, a check that passed vacuously: file
     it. Filing it is not the same as fixing it, and this step never fixes upstream.
   - **Every filed defect CITES the command that found it.** One literal command and its
     decisive output line — the discipline `steps/discovery.md` already imposes on the
     prior-decision search, where a zero-hit pass is valid ONLY if the command is shown. A
     claim about WHY a detector emitted a row is an INFERENCE, not a finding: label it as one,
     or verify it and cite that. The mechanical region is rendered and `--verify`'d precisely
     so detector output cannot be narrated; the prose AROUND it had no such rule, and that is
     where the wrong headline finding of each of the last two pulls came from — one filed
     against a checker that was correctly obeying an over-wide declaration, one calling a
     token inside a historical anecdote a second live vocabulary. Both were grep hits rendered
     as conclusions without reading the surrounding line. A third was a CORRECTION derived
     from the three refs already loaded rather than from the history, and it was wrong too.
   - **Re-run the re-verifier over what you just wrote, before the drain is done.**
     `reconcile/ledger-reverify.sh <dist> <base> <consumer> <theirs>` again, and read the rows
     for the entries this step added. Any of them landing `NEEDS-REVIEW` — unresolved, vacuous,
     or unfalsifiable — is a receipt to FIX NOW, not to file. Step 3f lints receipts on READ,
     so an entry authored here is first checked one pull later, after a pull has already acted
     on it. Last cycle this step wrote malformed receipts into the same document that correctly
     explained that defect class. The whole ledger re-verifies in ~1.5s; this costs nothing.
   - **Close any `CLOSE-CANDIDATE` entries from step 3f.** For each, confirm the upstream
     version at `theirs` covers your entry (the row's detail names the sha and the version),
     then annotate the ledger entry `ADOPTED UPSTREAM (v<theirs>, verified <date>)`, matching
     the existing hand-written closure format. **Do NOT delete the entry** — retro and the
     §8.1 fan-in read it. The annotation is an `Edit` under `_bmad-output/ai-dlc-update/**`
     (the updater's own directory, carved out of the Rule 29 acknowledge hook), never a
     Bash write, and never automatic. Close ONLY `CLOSE-CANDIDATE` rows; a `NEEDS-REVIEW`
     row is never a close, whatever its detail says.
   - **Every other status in the push-candidate heading has a disposition here, and none of
     them is a close.** `reconcile/emit-report.sh` renders the set the operator acts on and
     this is the step that acts, so a status named there and not here is a duty with no actor.
     Step 3f says what each status MEANS; these say what to DO with it.
     - `NAMED-UPSTREAM` — upstream's history names the id. Read the named commit and decide
       whether it ABSORBED the entry or recorded a rejection or a split. On absorption,
       annotate by hand in the form `ledger-rotate.sh` accepts — bolded, version immediately
       after the parenthesis — the same edit the bullet above describes; otherwise re-anchor or
       drop the stale receipt. Naming is not absorption and the row is never an auto-close.
       **The row supplies no version and you must establish one**: find the release that
       CONTAINS the absorbing commit, which is not the same as the `VERSION` file at that commit
       — a fix that lands before its bump reads one release early there. The row deliberately
       stopped guessing it, because a version read off a commit that merely NAMES the id is a
       claim about the wrong event and the annotation it lands in is permanent.
     - `NAMED-UPSTREAM-AMBIGUOUS` — the commit cites the sprint prefix and two or more entries
       share it. Deliberately NOT attributed: read the named commit and decide per entry.
       Annotate nothing on the strength of the row alone.
     - `HAND-REVIEW` — the entry declares `verify: manual` and no mechanical predicate exists
       for it by design. Adjudicate the body against `theirs`; annotate only what that
       adjudication establishes.
     - `NEEDS-REVIEW`, `INPUT-UNRESOLVED`, `RECEIPTS-UNDECIDED`, `ENTRY-SWALLOWED` — the
       RECEIPT or the entry's own shape is the defect, not the entry. Repair it here, the way
       the re-run bullet above requires, and close nothing on one.
   - **Rotate the closed entries out.** `reconcile/ledger-rotate.sh <ledger>` reports what
     would move; `--apply` moves it to `push-candidate-ledger.archive.md`. The ledger is
     append-only otherwise, so it grows every sprint and never shrinks — measured at 2830
     lines / 220 KB / 50 entries on the reference consumer, of which only 39 still
     classified. Every pull parses the closed ones, every report renders them, and every
     receipt edit pays for their bytes. Rotation moves, never deletes, and requires the
     annotation form (`**ADOPTED UPSTREAM (v`) rather than the phrase anywhere — an entry
     wrongly kept costs one pull to notice, one wrongly archived costs the work.
     **Acceptance test:** `ledger-reverify.sh` must emit the same ROW SET before and after —
     by status and subject. Rotation moves exactly the entries it already skips, so a changed
     row set means a live entry was swept. **It is NOT a byte comparison, and running one here
     false-fails on this very step.** An entry you annotated in this same pass is skipped by
     the open-entry extractor and not yet in the archive, so the sprint-prefix count inside
     `NAMED-UPSTREAM-AMBIGUOUS` details rises as it reaches the archive. Measured by annotating
     every open entry on a copy of the reference consumer's ledger and rotating: identical row
     set, every differing line carrying a prefix count, and that count rising — nothing swept.
     Treating it as a sweep unwinds correct work at exactly the moment a large batch of closes
     has landed. **Derive the row set; do not carry a row COUNT across corpora** — the totals are
     a property of the ledger's size on the day, and two runs of this experiment on ledgers of
     different sizes gave different ones.
9. **Safety.** Three independent recover layers: the step-6 reconcile **branch**
   (the working branch is never touched), the consumer's
   `docs/pre-ai-dlc/<ts>/_divergence/` archive (written by install), and the
   dry-run report. Nothing is destroyed without an operator confirm.

## Layered consumers (Rule 27 / spec §7) — the reconcile shrinks

When the consumer has the Phase 2 layer split (a populated
`{skill}/extensions/` and/or `{skill}/overrides/`), the reconcile surface
collapses:

- **core** (the protected-manifest files) → overwrite from theirs wholesale,
  running the **mask/reinject transform** (above) first for any file listed in
  `reconcile/setup-sites.md`. No per-block classify needed for rulebook prose
  — the consumer never edited core in place there (the gate-validation
  Core-layer immutability check guarantees it) — but base→ours is NOT empty
  at declared setup-substitution sites (model strings, ownership paths,
  deploy/smoke commands); those always differ from base by design, forever.
  The three-way degenerates to a fast-forward everywhere EXCEPT those sites,
  which mask/reinject handles without needing a classify pass.
- **extensions/** → never **written** by the pull (consumer-owned), but no longer
  invisible to it. Step 3c's `layer-drift.sh` reports `EXTENSION-HOOK-DRIFT` when
  the hooked core file changed, and `EXTENSION-RETIRE-CANDIDATE` when upstream has
  absorbed a section the extension defines (Rule 27(b) — the consumer retires it;
  the pull never deletes a layer entry). Drain entries flagged
  `push_candidate: true` into the push-candidate ledger (spec §8.1).
- **overrides/** → the ONLY genuine three-way surface. For each override, its
  base is the core rule it shadows (`base_sha` in the entry). If theirs changed
  that core rule between `base_sha` and HEAD, surface the override for operator
  re-confirmation (override-drift, spec §10). **This is computed by step 3c's
  `layer-drift.sh`, not by hand** — it was prose here for its whole existence and
  consequently never ran. An override whose `base_sha` does not resolve in the
  distribution is a HARD finding that blocks `apply` (Rule 27(a)); it is never
  treated as "unchanged."

On a pre-Phase-2 (tangled) consumer like graph's first pull, none of the above
applies yet — run the full per-block classify. The Phase-2 untangle is what
moves a consumer from the full reconcile to this cheap one.

## Untangle mode — one-time Phase-2 migration (`untangle` = dry-run, `untangle apply` = execute)

For a still-tangled consumer (core files mix upstream prose with in-place
consumer divergence — domain-local machinery, rewordings, un-pushed
innovations — because the Phase 2 layer split was never done), `untangle`
performs that split as a one-time migration, invoked from the consumer exactly
like the ordinary pull. It reuses the same self-contained, consumer-side
posture and the same shared classifier — it is one of the four jobs
`reconcile/classify-block.md` already serves (see "Shared engine" below).

**Precondition check.** If `{skill}/extensions/` or `{skill}/overrides/`
already hold more than their scaffold `README.md`, this consumer has already
untangled — refuse and report that, rather than re-running blindly.

**Steps 1–4: identical to the pull procedure above**, with one change: step 3
runs `reconcile/preclassify.sh <dist-repo> <base-sha> <theirs-ref> <consumer-root> --untangle`.
This exists because untangle is typically invoked when the consumer's stamp
already equals upstream HEAD (`base == theirs` — no upstream delta to pull,
only accumulated in-place divergence to split out). A plain `base`→`theirs`
diff is empty in that case, so `--untangle` mode enumerates the core-manifest
file list from `reconcile/setup-sites.md` instead and buckets purely by
`ours` vs `base`. `classify-block.md` itself needs no changes: a manifest file
that lands in `BOTH-CHANGED->CLASSIFY` still gets diffed and classified
exactly as it is for an ordinary pull, and any block the consumer touched
while upstream (at `base`, standing in for `theirs`) did not is already
handled by the classifier's existing `consumer-only-in-block` bucket.

Before any block in a manifest-listed file reaches the classifier, mask
declared `setup-sites.md` sites (per the mask/reinject transform above) so
setup config is never misclassified as rulebook divergence and never routed
into an `extensions/`/`overrides/` file.

**5u. Migration-plan dry-run.** Write
`_bmad-output/ai-dlc-update/untangle-plan.md` (own filename; coexists with the
ordinary pull's `reconcile-report.md` in the same directory) with a header
stating `Generated: <UTC timestamp> by ai-dlc-update skill_version <X> @
<sha>` — same reason as step 5's report: a fixed filename overwritten on
every run, so the stamp is the only way to tell a fresh plan from a stale one
left over from before a skill update. Then: per-file bucket
tally, proposed `extensions/`/`overrides/` file list (`hooks:`/`shadows:`+`id`
per the entry contracts in `extensions/README.md`/`overrides/README.md`),
push-candidate list, conflict list, a **needs-confirmation list** (every
`needs_operator_confirmation: true` block per `classify-block.md`, each with
its specific question — separate from the conflict list, same as step 5),
the masked-site list (so the operator can
catch a manifest miss before it's acted on), **and an explicit list of any
consumer-only files with no upstream equivalent at all** (e.g. an extra
team-role file, an extra subdirectory under the skill root) — name them, state
they will be left untouched and queued to the push-candidate ledger. Silence
on these reads as "not found," not "found and intentionally skipped" — say so
explicitly. **Unconditional stop unless invoked with `apply`** — identical
discipline to step 5: zero conflicts, an obviously-clean plan, inferred
intent, or convenience do NOT authorize proceeding. A bare `untangle` is a
dry-run, every time, no exceptions. **This includes conflict adjudication
given in conversation** — if the operator resolves the one conflict, or asks
for a specific fix, while reviewing this report, record their answer in the
plan for the `apply` run to act on; do NOT edit any file now (see step 5's
"Adjudication is not authorization to write" — the same rule, no exception for
untangle).

**6. Isolate branch.** Reused as-is (`git checkout -b
ai-dlc-update/untangle-<ts>` off the current branch).

**7u. Extract + mask-aware overwrite — reached ONLY when the invocation
carried `apply`.** The **flagged-block checkpoint** from step 7 applies here
unchanged: before executing any block's bucket action below, check
`needs_operator_confirmation` — if true, stop and get the operator's explicit
answer for that specific block before authoring anything for it, regardless
of bucket. This is not optional for untangle just because most blocks here
are mechanical — the two most consequential open items in graph's first
apply (a layer-`kind` naming decision, a genuine 3-way prose blend) were
exactly this shape. Per classify bucket, act:
- **rewording** → discard the consumer's version; core is restored to
  `theirs` at that block (rewording is by definition already-upstream in
  substance).
- **domain-local** → extract the block to `extensions/`, then restore core to
  `theirs` at that block.
- **un-pushed-innovation** → extract to `extensions/` with `push_candidate:
  true`, then restore core to `theirs`.
- **conflict** → extract to `overrides/` with `shadows: <file>#<id>` and
  `base_sha: <current stamp sha>`, then restore core to `theirs` (the override
  now shadows the core rule for this consumer; core itself stays
  byte-reconcilable with upstream).

Then apply the **mask/reinject transform** to every manifest-listed file as
part of its final overwrite. Files upstream has no equivalent for at all —
e.g. a consumer-only team-role file, or a whole consumer-only subdirectory
under the skill root — are left untouched entirely and queued to the
push-candidate ledger; core-overwrite by construction only ever touches paths
`theirs` actually has.

**7v. Runtime-verification gate — hard, unconditional, blocks delivery on any
failure.** Byte-equality is not sufficient evidence the migration worked (this
is exactly what the reverted attempt got wrong). Before delivery:
1. For every `overrides/*` entry, resolve its `shadows: <file>#<id>` against
   the just-overwritten core file — FAIL on a dangling shadow (id not found).
2. For every `extensions/*` entry, confirm its `hooks:` target file exists in
   core. **Resolve the `hooks:` path via the core→consumer path mapping (the
   same one `preclassify.sh` uses), NOT skill-relative:** a `steps/<x>.md` or
   bare `SKILL.md` hook lives under the skill dir
   (`.claude/skills/ai-dlc/…`), but a `team-roles/<role>.md` hook (used by
   `roles/*` extensions) lives at `.claude/team-roles/<role>.md` — OUTSIDE
   the skill dir. A naive skill-relative join (`.claude/skills/ai-dlc/team-roles/…`)
   would falsely report every role extension's target MISSING. `hooks:` values
   mirror the `core/`-relative path convention (`team-roles/x`, `steps/x`,
   `SKILL.md`); map each the same way core files map to consumer files.
3. Render 2–3 sample overrides and extensions to show what Rule 27's
   precedence (`overrides > extensions > core`) would actually produce at
   load time — proof the shadow/addition takes effect, not just that the id
   string matches somewhere.
4. Confirm zero remaining `{...}` template tokens in any team-role file; that
   every role file has an `aiDlcRoles` entry in `.claude/settings.json`, that
   each entry's `model` resolves in `aiDlcModels`, and that each `effort` is one
   of `low`/`medium`/`high`/`xhigh`/`max`. The dispatch guard fails open on any
   of those, so a role would dispatch with nothing bound — silently. This is the
   concrete proof teammate dispatch will not break, the exact failure the
   reverted attempt caused.
5. **Run `reconcile/setup-site-drift.sh <dist> <consumer> <theirs>`; exit 0
   required.** It diffs every file declaring a setup site against `theirs` over
   the WHOLE file and confirms every differing line falls INSIDE a span declared
   for that file in `reconcile/setup-sites.md` (a single-line site's matched
   line, or a heading-block site's span). A difference at ANY line outside a
   declared span — a dropped `<!-- {token} -->` config comment, a removed blank
   line, reordered prose — is a FAIL, even if the setup values themselves
   reinjected correctly: it means the overwrite kept `ours`'s structure instead
   of `theirs`'s and core is no longer byte-reconcilable.

   **This criterion was prose, and the prose was not enough.** A
   real run checked only the value lines and declared pass: `dev.md` lost three
   of theirs' model-option HTML comment lines and this criterion still reported
   PASS. Asking the agent that just performed the transform whether the transform
   was correct is not a check. The script is now the criterion, it also runs on
   the ORDINARY pull (step 7's post-write gate, where nothing equivalent existed
   at all), and a site it cannot locate FAILS rather than being skipped.

Any failure here STOPS the run before delivery — the branch holds the
in-progress state for inspection/fix, nothing is delivered. This gate is not
optional and not skippable by any of the same rationalizations forbidden at
step 5 (clean-looking result, zero conflicts, etc.).

**8, 9. Deliver, safety.** Reused as-is: branch → commit → push → PR →
operator-approved merge (PR body = the migration plan summary + the 7v gate
results); the same three recover layers (branch, `_divergence/` archive,
dry-run report — here, `untangle-plan.md`).

## Shared engine, thin orchestrator

The per-block classifier (`reconcile/classify-block.md`) is a SHARED engine
that serves four jobs (design §8): pull-reconcile (this skill), push-mine,
Phase-2 untangle, and N→1 fan-in dedupe. `ai-dlc-update` is only the **pull
entry point** that calls it — it does not own it. Keep the classifier prompt
free of pull-only assumptions so the other three jobs can reuse it.

## Not yet wired (design §6.1 gaps — call out, don't silently skip)

- **Generated files outside `core/`** (`CLAUDE.md`, `coding-conventions.md`,
  `QUICKSTART.md`, `settings.json`) ARE now reconciled — step 3b's `--templates`
  pass + `reconcile/template-sites.md` sync the upstream template boilerplate
  while preserving consumer config. This closed the gap where a template-only
  upstream change (e.g. a removed CLAUDE.md section) never reached a consumer
  through the `core/`-only reconcile. (Consumer `enabledPlugins` is the
  exception — additive-only, never removed, per `template-sites.md`.)
- **Upstream URL** is carried in the stamp's `upstream` field (written by
  install, preserved on every re-stamp). Read it in step 1; only fall back to
  asking the operator when the field is absent (a legacy stamp).
- **Self-update** is handled in step 2 as its own autonomous branch→commit→push
  →PR→auto-merge cycle (the skill's files are overwrite-safe upstream tooling, no
  operator gate), separate from the operator-gated rulebook reconcile (step 8).
  After it merges the run stops and **automatically re-invokes `/ai-dlc-update`**
  (carrying the operator's original argument) to run the reconcile on the updated
  logic — no operator prompt. The in-flight agent can't hot-reload its own
  instructions, so the re-invocation is the only way to run the fresh logic;
  continuing on stale logic is forbidden.
