---
name: ai-dlc-update
description: "Reconcile upstream AI/DLC distribution changes into a diverged consumer project via a base-aware semantic three-way merge (the distribution→consumer pull path). Run bare for a dry-run report, or with `apply` to reconcile after review. Run with `untangle` (or `untangle apply`) for the one-time Phase-2 core/extensions/overrides migration on a still-tangled consumer. Use when the user says \"ai-dlc-update\", \"pull upstream\", \"update ai-dlc\", \"reconcile with distribution\", or \"untangle\"."
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

  **Stamp schema (`.claude/.ai-dlc-version`, v0.17.0+):** two independently
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
- **theirs** = distribution `core/` at the target ref (default upstream HEAD).
- **ours**  = the consumer's live tree (`.claude/…`, plus `scripts/` for
  `core/scripts/…`).

`base` and `theirs` are fetched from the distribution git repo. `ours` is the
working tree. See §6.1 of the design record — this is a vendored-dep updater
(`npm update` runs in your project and reaches the registry), not the reverse.

## Path mapping (core/ → consumer)

- `core/scripts/<x>`  →  `scripts/<x>`   (project root)
- `core/<x>`          →  `.claude/<x>`   (everything else: skills, team-roles,
  hooks, session-driver)

## Divergence taxonomy — the classifier's output buckets

Every consumer block that differs from upstream is one of:

| Bucket | Meaning | Pull action |
|--------|---------|-------------|
| **rewording** | same concept, different prose; already-upstream in substance | take theirs (drop the consumer rewording) |
| **domain-local** | consumer machinery upstream intentionally lacks | keep ours; layer theirs' non-conflicting additions around it |
| **un-pushed-innovation** | generalizable improvement not yet absorbed upstream | keep ours; **flag for push** (feeds the absorption arc) |
| **conflict** | both changed the same core rule incompatibly | operator adjudicates |

## Procedure

1. **Resolve inputs.** Read the stamp: `base` = the `commit` field (rulebook
   merge-base), per the schema above; fall back to legacy single-line parsing if
   there is no `commit:` field. Resolve `theirs` (arg or upstream HEAD). Confirm
   the distribution repo is reachable — read the `upstream` field if present;
   otherwise ask the operator for the distribution checkout path.
2. **Self-update — an AUTONOMOUS, self-contained commit→merge cycle (before any
   rulebook classify/apply).** You run FROM a copy of this skill inside the
   consumer; a pull can include a change to that copy, so the logic executing the
   reconcile may be stale relative to `theirs`. The skill's own files
   (`core/skills/ai-dlc-update/**` — SKILL.md + `reconcile/*`) are **upstream-owned
   tooling, overwrite-safe** — the consumer never edits them (like `core`), so
   refreshing them carries no consumer-divergence risk. Therefore the self-update
   lands on its OWN cycle, **autonomously — no operator approval**, distinct from
   the operator-gated rulebook reconcile (step 8).

   Diff `base→theirs` restricted to `core/skills/ai-dlc-update/**`. If EMPTY, say
   so in one line and continue to step 3. If NON-EMPTY:
   - **Run the self-update cycle autonomously:** cut a dedicated branch
     `ai-dlc-update/self-update-<theirs-version>-<ts>`, overwrite the consumer's
     `.claude/skills/ai-dlc-update/**` with `theirs`, **update the stamp's
     `skill_version`/`skill_commit` to `theirs`** (rewrite the stamp in schema,
     preserving `version`/`commit`/`installed_at`/`upstream`), commit
     (`chore(ai-dlc-update): self-update <base-skill-ver> → <theirs-ver>`), push,
     open a PR, and **auto-merge (squash, delete branch)** — no operator gate. If
     there is no remote / push fails, commit locally and note it; do not block the
     run. Advancing `skill_version` here is what keeps the stamp an honest record
     of the installed tool version — it is bookkeeping tied to the (already
     autonomous) self-update, and never touches `version`/`commit` (the rulebook
     base stays put until a gated apply).
   - **Then HARD STOP the run and hand the operator the choice below.** The
     self-update landed, but THIS invocation is still executing the PRE-update
     logic — its reconcile/classify/apply behavior is stale, and an in-flight
     agent cannot hot-reload its own instructions. So after the self-update
     merges you MUST STOP here; do NOT proceed to step 3 on stale logic. Report:
     the self-update landed (merged PR ref) + a one-line summary of what changed
     (touches `reconcile/` — the engine — vs prose/docs), and offer:
     - **(a) re-invoke `/ai-dlc-update`** (recommended) — a fresh
       invocation loads the updated logic and runs the reconcile on it;
     - **(b) continue this run on the prior logic** — only if the operator
       EXPLICITLY asks, and best reserved for a docs-only self-change;
     - **(c) hold here — return control to the operator.** Do nothing
       further: no re-invoke, no continue, no assumption the operator wants
       either right now. This is the safe default in the absence of a
       reply — the stop already returns control by itself; (a)/(b) are only
       acted on if and when the operator explicitly picks one in a later
       message. The operator may be about to go look at the merged
       self-update PR, do something unrelated, or come back to this
       tomorrow — do not read a stop-and-report as an implicit request to
       keep going down either path.
     Recommend (a); never auto-pick it. Do NOT auto-continue — silently
     proceeding on stale logic is the exact defect this stop prevents (a
     self-update to the reconcile/apply logic is worthless if the same run
     ignores it). This stop applies even when
     the following reconcile would be empty.
3. **Mechanical pre-classification** (cheap, deterministic — no agents):
   run `reconcile/preclassify.sh <dist-repo> <base-sha> <theirs-ref> <consumer-root>`.
   It hashes base/theirs/ours per changed file and buckets each into:
   - `UPSTREAM-ONLY-ADD` (net-new upstream, consumer lacks it) → **apply (pure)**
   - `UPSTREAM-ONLY` (upstream changed, consumer untouched vs base) → **apply**
   - `ALREADY-AT-THEIRS` / `ALREADY-PRESENT` → **noop**
   - `UPSTREAM-DELETED` (upstream removed it, consumer untouched vs base) →
     **delete the consumer file (gated — destructive, see step 7)**
   - `UPSTREAM-DELETED-NOOP` (upstream removed it, consumer already lacks it) → **noop**
   - `BOTH-CHANGED` / `BOTH-ADDED` / `UPSTREAM-MOD+consumer-deleted` /
     `UPSTREAM-DELETED+consumer-modified` → **needs semantic classify**
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
   This MECHANIZES what "Layered consumers" below used to state as prose. Do NOT
   hand-verify overrides with ad-hoc `git diff` calls: nothing implemented that
   check for its entire existence, and a real consumer accumulated five overrides
   whose `base_sha` pointed at its OWN repo — every diff would have died on
   `fatal: bad revision`, and two shipped upstream changes were discarded unseen.
   Statuses:
   - `HARD-OVERRIDE-BASE-CONSUMER-SHA` / `HARD-OVERRIDE-BASE-UNRESOLVABLE` →
     **blocks `apply`** (see step 7). The `base_sha` is unusable, so drift for
     that override is undecidable. Never skip it; never "assume unchanged."
     Resolution: operator re-stamps `base_sha` to the correct distribution sha.
   - `OVERRIDE-DRIFT-SECTION` → the shadowed section changed; surface for
     re-confirmation (has upstream's change superseded the override's reason?).
   - `OVERRIDE-DRIFT-FILE` → the anchor is not a locatable heading AND the file
     changed, so the section cannot be *proven* safe. Surface for re-confirmation.
     Conservative on purpose — an unprovable section is never reported as OK.
   - `OVERRIDE-ANCHOR-UNRESOLVED` → upstream restructured the anchor away.
   - `EXTENSION-RETIRE-CANDIDATE` → upstream now defines a section this extension
     defines, and did not at `base` (titles agree, not merely the number — consumer
     gate-check numbers are a sanctioned separate namespace). Upstream **absorbed**
     it. Per Rule 27(b) the consumer MUST retire the entry; list it in the report's
     retirement list. This is the only signal that closes the absorption loop —
     without it every successful absorption leaves a duplicate behind.
   - `EXTENSION-HOOK-DRIFT` → the hooked core file changed. Extensions have no
     section anchor (`hooks:` is file-grain), so this is the strongest statement
     available: re-read the entry against the new core text.
   - `EXTENSION-HOOK-MISSING`, `OVERRIDE-OK`, `EXTENSION-OK` → as named.

4. **Semantic per-block classify** — for every file the pre-pass marked
   `…CLASSIFY`, dispatch ONE generic agent per file (batch trivial single-block
   diffs) using `reconcile/classify-block.md` as the prompt. Block granularity
   = per-file + per-numbered-item (rule / `###` section / check). Each agent
   computes the file's own base/theirs/ours three-way with git and returns
   structured per-block buckets. Agents return DATA (bucket tallies + only the
   conflict/flag details), never echoed file content — keeps the orchestrator
   context clean.
5. **Emit the dry-run report, then HARD STOP (unconditional).** Write
   `_bmad-output/ai-dlc-update/reconcile-report.md`: a header stating
   `Generated: <UTC timestamp> by ai-dlc-update skill_version <X> @ <sha>`
   (read `skill_version`/`skill_commit` from the stamp), then per-file +
   per-block bucket, proposed action, the push-candidate list, the conflict
   list, a **needs-confirmation list** — every block any classify agent
   returned with `needs_operator_confirmation: true` (per
   `reconcile/classify-block.md`), each with its specific question, listed
   separately from and in addition to the conflict list (a block can be in
   neither, either, or both) — a **deletions list**: every
   `UPSTREAM-DELETED` path (upstream removed the file, consumer untouched),
   each with its reason line, since applying one `git rm`s a consumer file
   and is gated per-path at apply (step 7) — and a **template-changes
   list**: every `TEMPLATE-PROSE-MERGE` / `TEMPLATE-JSON-MERGE` file from step
   3b with a one-line summary of the upstream boilerplate delta being synced
   (e.g. "CLAUDE.md: remove Context-Mode Usage section") and, for any file
   that hit anchor-drift, its flag for adjudication — and, from step 3c, a
   **layer-drift list** (every `OVERRIDE-DRIFT-*` / `OVERRIDE-ANCHOR-UNRESOLVED` /
   `EXTENSION-HOOK-DRIFT` entry with its target and reason), a **retirement list**
   (every `EXTENSION-RETIRE-CANDIDATE`: the entry, the section upstream absorbed,
   and the note that retirement is an operator-gated delete per Rule 27(b)), and a
   **blocking-layer list** (every `HARD-*` status — these block `apply` outright).
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
   bullet") is giving an ANSWER — record it into the report/log for the
   `apply` run to act on. It is NOT an instruction to edit any file right now.
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
   any `HARD-OVERRIDE-BASE-CONSUMER-SHA` or `HARD-OVERRIDE-BASE-UNRESOLVABLE`,
   STOP before any write. Those overrides have an unusable `base_sha`, so whether
   upstream changed the rule they shadow is **undecidable** — applying the core
   overwrite would let a stale override silently keep shadowing a rule that moved.
   Present each to the operator with the correct distribution sha to re-stamp
   (Rule 27(a)); apply only after they are fixed or the operator explicitly
   accepts the risk per entry. `apply` authorizes writes; it does not authorize
   proceeding on an undecidable override — the same distinction the deletion gate
   below draws. Never infer that an unresolvable base means "unchanged."

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
   - `TEMPLATE-JSON-MERGE` (`.claude/settings.json` — from step 3b) → run the
     jq strip/merge in `reconcile/template-sites.md` "settings.json reconcile":
     strip stale `ai-dlc-*.sh` hook blocks + append the template's, preserve
     user permissions/env/mcpServers. `enabledPlugins` is additive-only and
     NEVER removed: a plugin the template dropped since base (e.g. ai-dlc's own
     `context-mode@context-mode` decommission) removes ai-dlc's *use* of it,
     not the consumer's right to keep it enabled — the consumer's
     `enabledPlugins` is preserved in full. Disabling a plugin is the
     consumer's decision, not the reconcile's.
   - (The skill's OWN files are NOT touched here — they were already refreshed by
     the autonomous self-update cycle in step 2.)
   - Re-stamp the rulebook base: set `version`/`commit` = `<theirs-version>` /
     `<theirs-sha>`, **preserving `skill_version`/`skill_commit`/`installed_at`/
     `upstream`** (rewrite the whole stamp in schema — never collapse it to the
     legacy single line, which would drop the skill version and upstream URL).
     Write `_bmad-output/ai-dlc-update/reconcile-log-<ts>.md`. **The re-stamp
     fires whenever the consumer core now equals `theirs` — INCLUDING an empty
     reconcile (zero rulebook blocks applied, e.g. a self-update-only pull). In
     that already-current case this step is a stamp-only bump: the point of the
     `apply` run is to advance the stamp; the log records "already current, stamp
     advanced <base> → <theirs>." Without this, a skill-only pull would leave the
     stamp stuck forever and every later pull would re-diff from a stale base.**

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
4. Confirm zero remaining `{...}` template tokens in any team-role file, and
   that every `/model` line holds a real (non-placeholder) string and every
   `/effort` line holds one of `low`/`medium`/`high`/`xhigh`/`max` — this is
   the concrete proof teammate dispatch will not break, the exact failure the
   reverted attempt caused.
5. Diff every overwritten core file against `theirs` **over the WHOLE file,
   line by line**, and confirm every differing line falls INSIDE a span
   declared for that file in `reconcile/setup-sites.md` (a single-line site's
   matched line, or a heading-block site's span). A difference at ANY line
   outside a declared span — a dropped `<!-- {token} -->` config comment, a
   removed blank line, reordered prose — is a FAIL, even if the setup values
   themselves reinjected correctly: it means the overwrite kept `ours`'s
   structure instead of `theirs`'s and core is no longer byte-reconcilable.
   Do NOT check only the value lines and declare pass (a real run did exactly
   that: `dev.md` lost three of theirs' model-option HTML comment lines and
   this criterion still reported PASS — the check must diff the whole file,
   not just confirm the values look right).

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
  After it merges the run HARD STOPS and hands the operator three choices:
  re-invoke to run the reconcile on the updated logic (recommended), continue
  on the prior logic (only if explicitly asked), or hold here with no further
  action — the in-flight agent can't hot-reload its own instructions, so
  continuing on stale logic without being asked is forbidden.
