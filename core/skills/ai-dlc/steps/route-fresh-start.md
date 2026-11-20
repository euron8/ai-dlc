---
name: route-fresh-start
description: The fresh-start half of the router -- Steps 1 to 6 and the failure modes, loaded by route.md when Step 0 does not resume
nextStepFile: dynamically determined by routing logic
---

# AI/DLC Router: fresh start (Steps 1-6)

`shard: n/a (no dispatch)` — this file is a continuation of `route.md`, which routes to step files and joins prior deliverables. Its STATE VARIABLES are `route.md`'s.

### Step 1: Read Project State

Check for existing artifacts on disk:

1. Check `_bmad-output/planning-artifacts/product-brief.md` — exists and non-empty?
2. Check `_bmad-output/planning-artifacts/prd.md` — exists and non-empty?
3. Check `docs/architecture.md` or `_bmad-output/planning-artifacts/architecture.md` — exists?
4. Check `_bmad-output/planning-artifacts/s*/stories/` — any story files exist?
5. Check `_bmad-output/planning-artifacts/carry-over-backlog.md` — any OPEN items?
6. Read `_bmad-output/planning-artifacts/sprint-status.yaml` if it exists — current sprint state?
7. Read CLAUDE.md for project rules and conventions.

### Step 1a: Artifact-Size Budget Gate (Rule 25(d)) — HARD_BLOCK

Run `scripts/ai-dlc/validate-artifact-budget.sh`.

If it names a stamp later than the current UTC time, apply Step 0a check 1's stamp
remedy first, without asking; it is not a budget breach and no remedy below clears it.

**Exit 0** — every living artifact is within budget. Continue to Step 2.

**Exit 1** — one or more artifacts are over budget. **HARD_BLOCK. Do not start the
sprint.** Present the script's output to the operator, and apply the remedy the
script names per artifact — they are not interchangeable:

- `consolidate` → the operator runs `artifact-consolidation.md` (a
  fidelity-critical rewrite; it is supervised, never automatic).
- `rotate` → a rotation was **missed**. Move the epoch to
  `_bmad-output/implementation-artifacts/s<N>/<basename>-archive.md`, the one
  destination `artifact-path-grammar.md` gives every rotation archive
  (Rule 25(c)). Never rewrite a log.

  **`<N>` IS THE SPRINT THAT CLOSED, NOT THE ONE ABOUT TO START, AND THE REASON IS
  ORDERING RATHER THAN AVAILABILITY.** The next sprint's number is perfectly
  resolvable here — `scripts/ai-dlc/sprint-status.sh sprint-id` answers it, and
  core hooks call it continuously — so do not justify this to yourself as "the
  number is unknown" and do not act on `s<N+1>/` when you find that it is known.
  What Step 1a runs before is Step 6's **`roll`**, which is what CREATES a sprint
  directory (`sprint-status.sh` `roll()`, `path.parent.mkdir`). Making
  `s<N+1>/` here pre-empts that roll and the HARD_BLOCK it performs on an
  unclosed prior sprint.

  So the destination is the CLOSED sprint's slot — the only one on disk — whose
  `<basename>-archive.md` is already filled by that retro's own rotation.
  **Writing this epoch there destroys that archive**: a Rule 25(a) no-loss
  breach, irreversible outside git recovery. Append the ordinal instead, per the
  grammar's rule for a second rotation into one sprint slot:

      mv _bmad-output/pipeline-continuation-log.md \
         _bmad-output/implementation-artifacts/s<N>/pipeline-continuation-log-archive-2.md

  then **edit that file to put the epoch's span in its first line** — `mv`
  preserves bytes, so the moved file opens with the log's own re-seeded
  `# Pipeline Flow Log` header and states no span until you write one. Naming
  the span is not optional here: this archive holds an INTER-SPRINT window that
  belongs to neither sprint's retro, and the next paragraph is how that window
  still gets read.

  **RECORD THE WINDOW WHERE THE NEXT RETRO WILL LOOK.** Rotating at Step 1a moves
  events out of the live log *after* sprint `<N>`'s §4b audit has run and *before*
  sprint `<N+1>`'s exists, so neither audit opens them and the steerability
  findings in that window are lost silently — a retro reporting zero findings on
  a window nobody read, which §4b itself calls worse than an unrun check. Add an
  `Open Items` entry to `_bmad-output/pipeline-snapshot.md` naming the archive
  and its span, so the next retro reads it alongside the live log.

  Do **not** invent a status token in the basename (`-pending` and the like): the
  directory is the only sprint slot and no basename may carry a sprint token
  (Rule 25).
- `trim` → **move** the superseded content verbatim to
  `pipeline-snapshot-history.md` (write-only, Rule 25(a)), **then** delete it from
  `pipeline-snapshot.md`, with `snapshot-update.sh --move-to-history <section> <match>`
  (one call per line; it appends to the history first). Never delete it outright. The live file keeps all seven
  sections: a section is trimmed by moving its superseded entries out, never by
  dropping the section. Then run:

      bash scripts/ai-dlc/rotate-snapshot-archive.sh \
           _bmad-output/pipeline-snapshot-history.md --apply

Then re-run `validate-artifact-budget.sh`. It must exit 0 before the sprint proceeds.
If `rotate-snapshot-archive.sh` exits non-zero, read its stderr and fix what it names before re-running it, and re-run it until it exits 0.

### Step 2: Analyze User Input

Classify the user's request:

- **Sprint-execute signal**: Input mentions "implement the sprint",
  "execute the sprint", "run the stories", "pick up implementation",
  "start building", or sprint-status.yaml shows stories in ready-for-dev
  or in-progress status AND user does not describe a new feature/bug.
- **Bug signal**: Input describes the system behaving contrary to intent —
  a failure, a misreport, wrong/stale/incorrect values, a regression,
  "stopped working", "started after a deploy", or any unexpected behavior.
  The literal tokens "fix", "bug", "broken", "wrong", "error", "doesn't work"
  are sufficient but NOT necessary: keyword absence is not signal absence. A
  production-defect description is a bug signal whatever words carry it —
  and that includes a defect described *inside* a carry-over/backlog item.
  Arriving as an operator-dispositioned backlog entry does not neutralize a
  defect; the content is classified on its substance, not its envelope.
- **Feature signal**: Input describes new capability, enhancement, addition,
  or references a feature spec / escalation doc.
- **Carry-over signal**: Input mentions "carry-over", "backlog", "next sprint",
  or no specific feature — just "run the next sprint".
- **Analysis signal**: Input mentions "analyze", "document", "understand",
  "inventory", "what does this codebase do" without mentioning building anything.
- **Greenfield signal**: No trusted artifacts exist AND input describes
  something to build.

### Step 3: Route to Pipeline Variant

Apply the following decision tree:

```
Is there a planned sprint with stories ready for implementation?
  (has_ready_sprint AND user signals "implement", "execute", "run sprint",
   "start building", or does not describe a new feature/bug)
  YES → pipeline_variant = "sprint-execute"
  NO  ↓

Is this a bug fix?
  YES → pipeline_variant = "bug"
  NO  ↓

Is this carry-over / next sprint work?
  YES → pipeline_variant = "carry-over"
  NO  ↓

Is this analysis-only (no implementation requested)?
  YES → pipeline_variant = "analysis-only"
  NO  ↓

Do trusted planning artifacts exist on disk?
  (has_product_brief AND has_prd AND has_architecture)
  YES → pipeline_variant = "feature"
  NO  ↓

Do ANY planning artifacts exist?
  YES → Are they trusted / current?
    NOT SURE → pipeline_variant = "brownfield-c"
    NO, STALE → Is code mid-implementation?
      YES → pipeline_variant = "brownfield-a"
      NO  → pipeline_variant = "brownfield-b"
  NO  → Is there an existing codebase with source files?
    YES → pipeline_variant = "brownfield-b"
    NO  → pipeline_variant = "greenfield"
```

### Step 4: Ambiguity Check (Rule 11)

If you cannot confidently determine the pipeline variant, ask the user ONE
clarifying question. Examples of genuine ambiguity:

- User said "improve the dashboard" but no PRD exists and the codebase has
  partial documentation — is this brownfield-b or brownfield-c?
- User said "run the sprint" but there are both carry-over items AND a new
  feature spec — which takes priority?
- User gave a description that could be a bug or a feature enhancement.
- A defect signal (per Step 2) co-occurs with a carry-over or sprint-execute
  signal — a backlog / "next sprint" request that ALSO describes a production
  defect — which takes priority, the planned work or triaging the defect?

**Mixed defect + carry-over/sprint is a MUST-ASK, not optional.** When a bug
signal (per Step 2) co-occurs with a carry-over or sprint-execute signal and
the operator has NOT already directed the priority, you MUST ask the one
clarifying question before routing. This case fires on signal co-occurrence,
not on operator phrasing — do not resolve it silently by subordinating the
defect into a carry-over/feature story. The "Do NOT ask" allowance below does
NOT cover it: co-occurring defect + carry-over is ambiguous by definition,
because the two route to different pipelines (`bug` → repro-first triage;
`carry-over` → full planning). Record the outcome in the snapshot's
`clarification_asked` field (Step 6) with
`snapshot-update.sh --set clarification_asked <value> 'Pipeline Position'`:
`yes` if you asked, `n-a` if the operator pre-directed the priority.

**The question MUST offer triage now, then fold the fix** among its options:
READ AND FOLLOW `bug-investigation.md` (native Read, in consecutive `offset`/`limit` chunks of at most 16 KB covering the whole file, never `ctx_*`) sections 0–2c for the defect — so any
operator-applicable relief reaches the operator first — then return to this
step and fold the fix story (sections 3–4) into the current sprint: through
`stories-test-strategy.md` §3a if the sprint has not yet passed that step;
otherwise run `bug-investigation.md` sections 3–4 directly into the sprint's
`stories/` directory, skipping sections 5–6. Section 4's fold architecture
dispatch applies to it, and Check 17's fold architecture gate owns the residue
it writes. Both halves of Check 17's bug-fix arm and its fold architecture gate
run at the end of section 4, right after the stamp and the architect dispatch
and before any dev dispatch; every later implementation gate runs Check 17's
implementation gate arm for the story. The other options are yours to frame within
Rule 3's 2-4 per question.

Do NOT ask if the variant is clear from the project state + input.

**This allowance is about the VARIANT, and it does not reach Step 6's
sprint-scope confirmation.** That one is unconditional and fires even when
the variant was never in doubt — the two questions have different subjects.
This step asks *which pipeline*, and a clear answer is a reason not to ask.
Step 6 asks *is the scope I resolved the scope you asked for*, and a clear
answer there is the lead's own reading of the request, which is exactly the
thing that has been wrong while looking certain. Rule 11's "do not ask about
matters resolvable by reading existing artifacts" does not reach it either,
for the same reason: the artifact the lead would read to resolve it is the
one the lead just wrote.

### Step 5: Branch Strategy

Before starting the pipeline, determine the correct branch strategy:

1. **Check the current branch:** Run `git branch --show-current`.

2. **If on `main` or `master`:** Create a new branch for this work.
   Generate a branch name from the pipeline variant and user input:
   - Format: `ai-dlc/<variant>/<short-description>`
   - Examples: `ai-dlc/feature/user-dashboard`, `ai-dlc/bug/stale-cache`,
     `ai-dlc/greenfield/notification-system`
   - Keep the description to 2-4 kebab-case words derived from the
     user's request.
   - Create the branch: `git checkout -b <branch-name>`
   - Announce: "Created branch `<branch-name>` for this work."

3. **If on an existing `ai-dlc/*` branch:** This is likely a resumed
   pipeline. Ask the user: "You're on branch `<name>`. Continue on
   this branch, or create a new one?" If continuing, proceed. If new,
   create as above.

4. **If on any other branch:** The user is on a custom branch. Ask:
   "You're on branch `<name>`. Use this branch for AI/DLC work, or
   create a new branch?" Respect their choice.

5. **If git is not initialized:** Skip branching entirely. Do not
   initialize a git repo — that is the user's decision.

### Step 6: Compose Pipeline and Begin

Based on `pipeline_variant`, load the first step file:

| Variant | Pipeline Sequence | First Step |
|---------|------------------|------------|
| sprint-execute | implementation → sprint-review → deploy-validate → retro | `implementation.md` |
| greenfield | discovery → research-requirements → architecture → stories-test-strategy → [ui-direction] → implementation → sprint-review → deploy-validate → retro | `discovery.md` |
| feature | requirements → architecture → stories-test-strategy → [ui-direction] → implementation → sprint-review → deploy-validate → retro | `requirements.md` |
| bug | bug-investigation → implementation → deploy-validate → retro | `bug-investigation.md` |
| carry-over | carry-over-evaluation → requirements → architecture → stories-test-strategy → [ui-direction] → implementation → sprint-review → deploy-validate → retro | `carry-over-evaluation.md` |
| brownfield-a | codebase-inventory → discovery → research-requirements → architecture → stories-test-strategy → implementation → sprint-review → deploy-validate → retro | `codebase-inventory.md` |
| brownfield-b | deep-codebase-analysis → discovery → research-requirements → architecture → stories-test-strategy → [ui-direction] → implementation → sprint-review → deploy-validate → retro | `deep-codebase-analysis.md` |
| brownfield-c | doc-reconciliation → doc-repair-backfill → discovery → research-requirements → architecture → stories-test-strategy → [ui-direction] → implementation → sprint-review → deploy-validate → retro | `doc-reconciliation.md` |
| analysis-only | deep-codebase-analysis → **STOP** (present analysis to user, do not proceed to implementation) | `deep-codebase-analysis.md` |

**Note:** `[ui-direction]` is conditional — included only when the sprint
introduces new visual surfaces (new UI components, pages, or layout changes).
This is determined during the stories-test-strategy step, not here.

**Note:** For multi-sprint features (Rule 14), each subsequent sprint
loops through: `sprint-review-next` → `implementation` → `sprint-review`
→ `deploy-validate`. The `sprint-review-next` step validates the next
sprint's stories before implementation begins. This loop is handled by
`deploy-validate.md`'s post-validation routing, not by the router.

**Note:** For `feature` variant, the requirements step is scoped — it updates
existing artifacts rather than creating from scratch.

**Determine validation intensity (Rule 8).** Before creating the
snapshot, classify `validation_intensity` based on the stories in
scope (or anticipated scope for carry-over/greenfield):

- `full` — ≥3 stories touching service code paths
- `standard` — 1-2 stories touching service code paths
- `carry-over-single` — carry-over variant with ≤2 stories touching
  service code paths; assignable only to carry-over variants
- `lightweight` — all stories touch only pipeline-infra paths
  (scripts, config, docs, CI workflows)

For carry-over and bug variants where story count is not yet known,
estimate from the user's input. The intensity MAY be revised upward
(never downward) at stories-test-strategy if the actual story scope
differs from the estimate. Record the intensity in the snapshot's
Sprint Context section with
`snapshot-update.sh --set validation_intensity <value> 'Sprint Context'`.

**Resolve `sprint_id` (MANDATORY — this is the pipeline's sprint
identity).** A fresh pipeline start is the only place the sprint number
is derived; every downstream consumer reads it from the snapshot, never
re-derives it. Resolve it here, before creating the snapshot:

    scripts/ai-dlc/sprint-status.sh sprint-id

It prints an integer on stdout. Use that value. Do NOT re-derive it by
reading `sprint-status.yaml` yourself — the rules are the script's, and a
second implementation is a second answer.

Exit codes: **0** — use the printed integer. **3** — HARD_BLOCK (Rule 11):
the two `sprint-status.yaml` copies disagree on `sprint:`. Surface both
values and wait; never guess which is authoritative. **1** — fail-closed;
report it and stop.

`sprint_id` MUST be an integer. `none` is a hard stop, never a fallback —
the analyst-draft write paths below are stamped with it (Rule 24), and an
unstamped fallback silently destroys the prior sprint's draft, which is
the exact defect the stamp exists to prevent.

The script also decides the case a hand-applied rule set has no branch for:
a canonical that exists but carries no `sprint:` key, the state a
rotate-at-close leaves behind. Read as "greenfield" it restamps a live
project from sprint 1, and the frozen archives are history, not the current
state, so the script REFUSES it with exit 1 and names the file. Restore
`sprint: <N>` and `status:` in that file; never resolve the number by hand.

**Rotate the sprint envelope (MANDATORY).** Immediately after resolving
`sprint_id`, run:

    scripts/ai-dlc/sprint-status.sh roll --sprint <sprint_id> \
      [--name "<sprint name>"] [--variant <variant>] [--intensity <intensity>]

This is the pipeline's ONLY rotation point, and it is idempotent — on a
re-plan (`sprint_id` unchanged) it is a no-op, so it is always safe to run.
When the prior sprint is closed it freezes that sprint to
`s<N>/sprint-status.yaml` — the path grammar's slot, not the
pre-migration `sprint-status/sprint-<N>.yaml` a validator blocks on — and
writes the new envelope in ONE step. A freeze already present under the
old spelling is honoured where it lies and never duplicated, so a tree
that has not run the migration keeps its archive.
A BMAD-format `sprint-status.yaml` (no `sprint:`, a `development_status:` key) found in the slot is moved to `s<N>/bmad-sprint-status.yaml` before the freeze is written, or removed if an identical copy is already there; a differing copy there refuses (exit 3).
On a greenfield project it creates the file.

Rotation lives HERE, at pipeline start, and not at sprint close, for one
reason: `sprint-id` above must be able to read the closed sprint's
`status: done`. Rotating at close prunes that block, and the successor
does not exist yet — so the number has nowhere to come from and the roll
falls to whoever remembers to do it by hand.

Exit **3** is a HARD_BLOCK: the prior sprint is not closed (`status:` is
not `done`); a frozen archive already exists and differs from the
canonical it would freeze; a BMAD copy whose relocation target differs; a
view ahead of the target; the two views disagreeing on `sprint:`; or a slot, its `s<N>` directory, or a relocation target that is not of the expected kind. Exit **1** is a
preamble-only view beside a view still to roll. Exit **1** is also a phase-2 I/O failure, which can leave earlier writes in place; fix the cause and re-run roll, which completes a half-rolled tree. Every phase-1 refusal writes
nothing and prints its own `Remedy:` line. Surface it and wait — never
freeze live state.

**Confirm the resolved sprint scope (Rule 3 pause point (d) — MANDATORY).**
Before initializing the snapshot, and before any planning step loads, ask the
operator ONE `AskUserQuestion` that puts the scope you resolved in front of
them to confirm or correct.
The 2-4 option constraint on every `AskUserQuestion` is stated in `SKILL.md`'s
Rule 3 pause-point section and is not restated here.

WHY THIS PAUSE POINT EXISTS, AND WHY HERE. Every other Rule 3 pause point is
downstream of implementation, so a sprint that never reaches implementation
has structurally nowhere to ask. One ran seven days, produced zero lines of
product code, planned three stories sharing not one identifier with what the
operator asked for, passed four consecutive gates green, and then filed all
three of its blocking questions on day 7. Nothing it did was a rule
violation. It had simply resolved the scope wrongly at hour one and had no
seam at which anyone would look at that reading before it hardened into a
locked block. This is that seam, and it is the only one upstream of planning.

**Ask about the scope you RESOLVED, never about what to build.** "What
should this sprint do?" is a question the operator already answered — it is
in `_bmad-output/operator-requests-history.md`, in their own bytes. Re-asking
it discards the answer and invites a second, different one. State your
reading and ask whether it is right.

Compose the question from what you resolved, not from memory:

- The **identifiers** the captured ask names — `CO-S\d+-[A-Z0-9-]+`,
  `LR-S\d+-\d+`, `CAP-\d+`, `Epic-[A-Z]{2,}` and range forms like
  `LR-S299-0..11`. These are the same identifiers Check 33 will join against
  the LOCKED block at the first planning gate. Surfacing them here is the
  difference between the operator correcting a misreading in one turn and
  Check 33 hard-blocking on it after the planning work is already done.
- The resolved `pipeline_variant` and `sprint_id`.
- Anything in the ask you are deliberately NOT taking this sprint, named.

**A tagged carve-out is the prior close-out's proposal, not the operator's ask.**
A captured-ask line that opens with `[S<N> close-out proposes]` was written
by sprint `<N>`'s close-out, not by the operator. The unit to keep or strike
is that tagged line only; the rest of its parent item stands as asked. Treat
an untagged line the same way, and name it as possibly inherited from the
prior close-out, when the captured entry's header reads `-- /ai-dlc`, its
body has the close-out's shape (it leads with a theme, names the epic, then
numbers the in-scope items), and the line or clause defers or excludes work
or leaves an item with the operator; an item marked "stretch" is not a
carve-out. The capture hook moves the command token into the
header, so never key on the body opening with `/ai-dlc`. Put each carve-out
in the same `AskUserQuestion` as the scope, as its own keep/strike question
that quotes the line and names the sprint whose close-out wrote it, or says
"possibly inherited"; when they outnumber the questions the call holds
beside the scope question, ask one question listing them all with keep-all
and strike-all options, and Other names the ones to strike. Never ask in a
second call: `scope_confirmed_cite` cites one answer. Never present a
carve-out as part of what the operator asked for. A tagged or
possibly-inherited line is never a prior answer for Rule 11(a)'s search;
the keep/strike answer is the citation.

- Struck: the item is in scope. Record `scope_confirmed: corrected` and fold
  the item into the scope carried forward; the tagged bytes stay in
  `user_request_verbatim`.
- Kept, and it defers work: file it under "File every deferred part of the
  ask BEFORE leaving Step 6" below. When it names a filed `CO-` id that is
  not CLOSED, list that id in `scope_deferred_items` and do not file it
  again.
- Kept, and it leaves an item with the operator: name the item
  operator-owned in the confirmed scope. Do not file it or list it in
  `scope_deferred_items`.

**Option labels carry no recommendation.** Do not append `(Recommended)`, or
any equivalent, to an option. The skill asks for that token in three other
places — a Rule 11(a) question whose options leave no operator-owned value in
force, a checkpoint's `### Decisions for You` item (`deploy-validate.md` §5),
and the adversarial STOP's adjudication when no locked requirement is
touched (`_gate-procedures.md` step 2(c)) — and this pause point is none of
them. Say in the question that its options carry no recommendation, and why.
On the corpus where it was measured here, the operator took the option
carrying it in 3 of 5 turns. A lead that has already
misresolved the scope will label the misreading `(Recommended)`, and the
badge does its most damage in exactly the case this pause point exists to
catch. Present the options flat and let the operator choose.

**Search, derive and gloss before asking.** This question takes the three
steps `SKILL.md` Rule 11(a) puts on every operator question: a value already
answered in `operator-answers-history.md`, the requests history or the
LOCKED block is applied with its citation; a value the tree or config can
give is derived and offered for veto, UNBADGED when it is a config leaf, a
money threshold or literal, an address, or an `LR-` or `D-<n>` value (a value no operator words fix); every check number, band or `LR-`,
`D-<n>` id in the question carries a plain-language gloss.

**No pause flag here.** Rule 3 tells you to `touch
_bmad-output/pipeline-paused.flag` at a pause point; pause point (d) is one
of the two exceptions Rule 3 names, and this is deliberate rather than an
omission. The flag exists so
the Stop hook can tell an intentional pause from a stall, and a solicited
`AskUserQuestion` is neither — you have not ended the turn, the answer
arrives as a tool result rather than a UserPromptSubmit, and no
acknowledgement is owed because you already stopped and asked. Setting the
flag here leaves a pause nobody clears. The same asymmetry is why
`validate-steering-budget.sh` scores an AskUserQuestion answer as citable
operator text but never as a steamroll.

**File every deferred part of the ask BEFORE leaving Step 6.** When the scope
the operator confirmed or corrected defers any named part of the ask — a phase
split included — append each deferred part to
`_bmad-output/planning-artifacts/carry-over-backlog.md` as its own
`### CO-S<N>-<DESCRIPTOR>` item, `<N>` being the `sprint_id` resolved above, in
the format `carry-over-evaluation.md` requires of every newly filed item (its
`Every new item filed` rule — status and id grammar are owned there, not here).
The question you put to the operator is text you authored and no hash covers
it, so a deferral recorded only there is lost with the context that holds it.
One item per deferred part; never fold two into one heading.

**Record the outcome in the routing record** (fields below): `scope_confirmed`,
`scope_confirmed_cite` and `scope_deferred_items`. Then proceed — a correction is not a re-route.
Fold what the operator corrected into the scope you carry forward; only
re-run Step 3 if the correction changes the pipeline VARIANT, which is rare
and which you must say out loud if you conclude it.

**Initialize the pipeline snapshot.** Before the READ AND FOLLOW, handle
the pipeline snapshot at `_bmad-output/pipeline-snapshot.md`:

- **If the file does NOT exist, or exists and is EMPTY (0 bytes):**
  create it with `snapshot-update.sh --init <step-file> <sprint-id>`, then
  record the rest of the initial state below with `--set <key> <value>
  '<section>'`, `--set-block`, `--row-add` and `--line-add` (never Write):
  - Pipeline Position (detected variant, first step file, no
    last-completed step yet, no gates passed yet, current git
    branch from `git branch --show-current`; plus the **routing record**,
    which Check 27 re-adjudicates at the first planning gate:
    - `user_request_verbatim` — the operator's request text, verbatim.
      **Copy it out of the newest matching entry in
      `_bmad-output/operator-requests-history.md`** — the fenced `text` block,
      byte for byte. That file is written by the UserPromptSubmit hook before
      any agent reads the request, so it is the operator's own bytes and not
      an agent's account of them. Do not compose this field from memory, do
      not summarize, and **do not write a pointer to another artifact in its
      place**. Persist it because a fresh gate-adjudicator has no access to
      this routing conversation and cannot re-classify what was never written
      to disk. `user_input` (Step 2) otherwise lives only in context.
    - `user_request_cite` — the 64 hex characters after `- SHA256: ` on that
      same entry, copied without the `SHA256:` label. This is what makes the
      field above checkable: the hash resolves to a hook-written record, and
      that record's body is independently citable
      against the session transcript with
      `validate-steering-budget.sh --cite`. Until this existed,
      `user_request_verbatim` was prose the lead wrote about the request
      rather than the request, and nothing could contradict it — a lead once
      recorded it as a pointer to the PREVIOUS sprint's locked block, planned
      a sprint sharing not one identifier with the ask, and passed four gates
      green. **If no entry exists** — the hook is not installed, or the
      request predates it — write `user_request_cite: none` and say which.
      `none` is a gap a later check can count; a fabricated hash is not.
    - `bug_signal_present` — `yes`/`no`, as resolved in Step 2.
    - `carryover_or_sprint_signal_present` — `yes`/`no`, as resolved in Step 2.
    - `clarification_asked` — `yes`/`no`/`n-a`, as resolved in Step 4.
    - `scope_confirmed` — `confirmed` if the operator accepted the scope you
      put to them at the pause point above, `corrected` if they changed it.
      There is no third value: this pause point is unconditional, so `n-a`
      would be a claim that it did not happen.
    - `scope_confirmed_cite` — the 64 hex characters after `- SHA256: ` on the
      matching entry in `_bmad-output/operator-answers-history.md`, copied
      without the `SHA256:` label. That file is written
      by the PostToolUse hook from the hook's own payload, before you write
      anything, and its hash covers the ANSWER alone — never the question you
      authored. This is what makes `scope_confirmed` checkable rather than a
      second field the lead grades itself on: the hash resolves to a
      hook-written record whose body is independently citable against the
      session transcript with `validate-steering-budget.sh --cite`.
      **If no entry exists** — the hook is not installed, or the operator
      dismissed the prompt — write `scope_confirmed_cite: none` and say which.
      `none` is a gap a later check can count; a fabricated hash is not. Do
      not compute this hash yourself: a hash the lead computed over text the
      lead chose is the self-declaration hole this field exists to close.
    - `scope_deferred_items` — `none` when the confirmed scope takes the whole
      ask; otherwise ONE line holding a bracketed list of the carry-over ids you
      filed at the pause point above, and any filed, not-CLOSED `CO-` id a kept
      carve-out names, e.g.
      `scope_deferred_items: [CO-S315-PHASE-2-BACKFILL, CO-S315-PHASE-3-CUTOVER]`.
      Never a multi-line list and never an id that is not filed: Check 34
      resolves every id to a `### <id>` heading in the live carry-over backlog
      or `carry-over-backlog-archive.md`, and fails one that is missing, malformed
      or CLOSED)
  - Sprint Context (`sprint_id` as resolved above — an integer, never
    `none`; remaining fields from `sprint-status.yaml` if it exists)
  - Recent Activity (empty — will be populated by `gate-validation.md`
    Check 14 on each gate passage)
  - Open Items (empty)
  - Locked Decisions (empty)
  - In-Flight Teammates (empty table, header row only:
    `agent | role | deliverable | dispatched-at | status`; rows are added
    at dispatch as `in-flight`, `dispatched-at` filled from
    `scripts/ai-dlc/wait-for-deliverable.sh --dispatch-ts <agentId>`, never a clock, become `delivered-reachable` at join if the
    teammate may still be messaged, and are deleted — never struck — once
    it will not be. The one exception is a HANDOFF: `steps/handoff.md`
    step 1 rewrites each stopped teammate's row to `stopped` and keeps it,
    because the successor session has no other way to learn what was
    running. What a message to a reachable teammate may carry is
    bounded by Rule 28)
  - Context Reminders (initialized here; the `ai-dlc-context-sensor.sh`
    hook owns runtime firing and dedupe in its own sidecar, and Check 14
    reconciles these fields from it at each gate):
    - `context_reminders_sent: none`
    - `last_yellow_fire_tokens: null`
    - `last_yellow_fire_turns: null`
    - `last_red_fire_tokens: null`
    - `last_red_fire_turns: null`

- **If the file exists and is NON-EMPTY** (a stale snapshot from a
  previous pipeline run — Step 0 did not dispatch to a resume, so the user
  is starting fresh with an old snapshot still on disk): do NOT silently
  overwrite. Absorb the old file into the one snapshot archive:

      bash scripts/ai-dlc/rotate-snapshot-archive.sh \
           _bmad-output/pipeline-snapshot-history.md \
           --absorb _bmad-output/pipeline-snapshot.md --apply

  1. **If the rotator exits NON-ZERO, STOP.** Do not write the snapshot.
     Report the rotator's stderr to the user verbatim. On exit 1 the history
     is byte-identical to before, EXCEPT in exactly one case: the history
     rename succeeded and the snapshot truncate then failed (read-only
     snapshot). There the history is the new, complete history and the
     archive holds the moved block and the snapshot; re-running after making
     the snapshot writable appends the snapshot again. The snapshot is never
     emptied without having been archived. The archive may carry a duplicate
     block after any exit 1.
     Writing over the snapshot destroys the only copy the pipeline reads.
  2. **On exit 0** the rotator has appended the stale snapshot to the
     archive and TRUNCATED the file to 0 bytes. Read the now-empty
     `_bmad-output/pipeline-snapshot.md`, then write the initial state
     as above into it with `snapshot-update.sh --init <step-file> <sprint-id>`, setting the
     multi-line Pipeline Position value with `--set-block`. Announce the archival in the output so the user
     knows the previous state was preserved.

  **The file is emptied, never removed:** every control hook keys "a
  pipeline is active" on the snapshot's existence, so a removed snapshot
  turns off stall detection, the pause flag, Rule 29's deny and
  compaction recovery until the new one is written, and a turn can end
  between the rotator call and that `--init`. An empty snapshot is not a
  resume: Step 0 item 1 requires the file to exist AND be non-empty.

  **One destination, one writing program, no dated files.** A per-occasion
  dated spelling (`pipeline-snapshot.archive.{ISO-timestamp}.md`) is
  retired: the reference consumer accumulated **158 of them in five
  different timestamp spellings**, three outside `_bmad-output/` root, and
  none matched `is_archive()` in the budget sweep — so nothing measured
  them and nothing rotated them.

  **Run the rotator; do not move the file by hand.** That is what keeps
  this write legal while the pipeline is paused — Rule 29's allowlist
  covers `Write|Edit`, never `Bash` — and the rotator refuses a
  destination Check 35's corpus cannot see.

The full per-section snapshot structure is defined in
`gate-validation.md` Check 14; see the SKILL.md Handoff Protocol and
Pipeline Snapshot section for its role and rationale. The snapshot is
maintained throughout the pipeline and is the source of truth for state
on handoff, post-`/compact` recovery, and lead self-orientation.

Announce the detected variant and pipeline to the user, then **READ AND
FOLLOW** the first step file at:
`{project-root}/.claude/skills/ai-dlc/steps/<first-step-filename>`

## FAILURE MODES

- If project state cannot be read (permission error, missing directories):
  ask user to confirm project root and directory structure.
- If user input is empty: ask user what they want to build.
- If ambiguity cannot be resolved with one question: default to the most
  conservative variant (brownfield-b for analysis, greenfield for building).
