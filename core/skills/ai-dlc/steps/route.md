---
name: route
description: Detect pipeline variant from project state and user input, compose step sequence
nextStepFile: dynamically determined by routing logic
---
<!-- STEP_LOADED_TOKEN: route -->

# AI/DLC Router

## STATE VARIABLES
- `user_input`: The user's original request text
- `pipeline_variant`: One of [greenfield, feature, bug, carry-over, sprint-execute, brownfield-a, brownfield-b, brownfield-c, analysis-only]
- `has_product_brief`: boolean
- `has_prd`: boolean
- `has_architecture`: boolean
- `has_stories`: boolean
- `has_carry_over_items`: boolean
- `has_ready_sprint`: boolean (stories exist with status ready-for-dev or in-progress)
- `is_ui_epic`: boolean (determined during planning, not routing)

## EXECUTION SEQUENCE

### Step 0: Entry-token and Resume Check

Before running the full routing sequence, read the entry token and check
for an existing pipeline snapshot that indicates a resume from a
previous session.

0. **If `user_input` is an ENTRY TOKEN, dispatch on it.** An entry token
   is the WHOLE of the user's input — optionally preceded by `/ai-dlc`
   and whitespace, and nothing else besides surrounding whitespace:

   - **`handoff`** — **READ AND FOLLOW** `steps/handoff.md` and skip the
     rest of this routing sequence.
   - **`resume`** — this is a resume signal for path 2 below. With the
     prefix it is `/ai-dlc resume`, which is the line `handoff.md` step 4
     emits verbatim, so it is the form a successor session actually
     arrives with. Accept that exact string.

   **`SKILL.md`'s handoff trigger (a) cannot cover the token form.** That
   trigger is a natural-language judgment a lead makes MID-SESSION, and a
   session whose FIRST input is the request has no lead in conversation to
   make it — so without this arm the request falls through to Step 1 and
   is routed as a new feature.

   **Match the WHOLE input, never a substring.** Measured over 67 recorded
   prompts from the reference consumer: a predicate matching any prompt
   CONTAINING `handoff` scores 9, and at least two of those are prompts
   ABOUT a handoff rather than requests for one — "the handoff that I
   issued should have pushed it", "you are not supposed to ask me if I
   want to handoff". Whole-input matching scores 6 with no false positive.
   A prompt that merely mentions the word is still covered mid-session by
   trigger (a), so the narrow predicate loses nothing.

1. Check if `_bmad-output/pipeline-snapshot.md` exists and is non-empty.
2. If YES and the user input carries a resume signal — the `resume` entry
   token above, OR input beginning with "Resuming an ai-dlc sprint", OR
   input explicitly referencing "pipeline snapshot" — this is a resume.
   **Before dispatching, run Step 0a snapshot integrity validation
   below.** If integrity validation passes:

   **The entry token is listed FIRST because it is the only one that has
   ever fired.** Across those same 67 prompts the other two forms match
   **0** and the bare entry line matches **3** — so a reader carrying only
   the prose forms has never once recognised a real resume, and the
   snapshot a handoff spent five steps preserving was archived as stale by
   Step 6 on the next invocation.
   - Take `current_step_file` from the snapshot Step 0a loaded. Do NOT
     re-read or re-grep the snapshot — that one load serves all of it.
   - Acknowledge the resume in the first output line:
     *"Resuming from snapshot at `{current_step_file}`."*
   - Reconcile every `In-Flight Teammates` row: a deliverable newer than
     its `dispatched-at` is DELIVERED — consume it, never re-dispatch.
     Older or absent means the beat resumes, not that the teammate died.
     (A resume that followed `handoff.md` Step 1 finds the table empty;
     one that followed a crash or context blow-out does not.)
   - Skip the rest of this routing sequence. Steps 1–6 are for fresh
     pipeline starts; on resume they would misclassify the input and
     overwrite the snapshot.
   - **READ AND FOLLOW** the step file named in `current_step_file`:
     `{project-root}/.claude/skills/ai-dlc/steps/{current_step_file}`
   - The snapshot is already current (kept fresh by
     `gate-validation.md` Check 14 on each gate passage throughout the
     previous session); do NOT re-initialize it.
3. If the snapshot exists but user input does NOT indicate a resume
   (e.g., the user is starting a new feature while an old snapshot
   remains on disk from a previous pipeline run), continue to Step 1.
   Step 6 will detect the stale snapshot and archive it before
   creating a new one.
4. If no snapshot exists, continue to Step 1 normally.

### Step 0a: Snapshot Integrity Validation (resume dispatch only)

This sub-step runs only when Step 0 path 2 is taken (a resume). Do
NOT silently dispatch to `current_step_file` if any check below
fails. Surface the specific failure to the user with a proposed
remediation and wait for direction.

**On any failure, create the pause flag before surfacing:**
`touch _bmad-output/pipeline-paused.flag`. Waiting for direction is
an intentional pause, and the Stop hook only recognizes one by that
flag. The `/ai-dlc` invocation deleted it (see SKILL.md, "Clear the
pipeline pause flag before any other action"), so without this the
Stop hook treats the failure message as a Rule 3 stall and returns a
forced-continuation reason that argues for pairing the text with a
tool call -- pressuring the lead toward the very dispatch this
sub-step exists to prevent. The flag also lets
`ai-dlc-driver-signal.sh` emit `.driver/idle`, which parks an
auto-chained session for the operator instead of leaving it blocked.
The lead clears the flag when the user directs the resume.

Run these integrity checks in order:

1. **Snapshot budget.** Before reading the snapshot, run
   `scripts/ai-dlc/verdict.sh validate-artifact-budget --only pipeline-snapshot.md`.
   This check protects the read that follows it: resume skips Steps 1–6,
   so Step 1a never runs, and the next budget check is
   `gate-validation.md` Check 14 — after the read. On non-zero exit,
   HARD_BLOCK with the `trim` remedy the script names (Rule 25(a),
   seven-section schema):
   > *"Snapshot at `_bmad-output/pipeline-snapshot.md` is over budget:
   > [verdict line, verbatim]. Reply `trim` to have me trim it to its
   > seven-section schema, `archive` to start fresh, or `abort`."*

2. **Load the snapshot.** Read `_bmad-output/pipeline-snapshot.md` **in
   full**. This is the single load that serves every check below, the
   Step 0 dispatch, and the rest of the session. No check below re-reads
   or greps it.

3. **Required sections present.** Confirm the snapshot contains all
   six load-bearing sections by heading:
   - `Pipeline Position`
   - `Sprint Context`
   - `Recent Activity`
   - `Open Items`
   - `Locked Decisions`
   - `Context Reminders`

   If any section is missing, FAIL with:
   > *"Snapshot at `_bmad-output/pipeline-snapshot.md` is missing
   > section(s): [list]. Resume is unsafe. Reply `archive` to move
   > this snapshot aside and start fresh, `edit` to have me fill in
   > the missing sections from git history, or `abort` to stop."*

   **`In-Flight Teammates` is the seventh section and AUTO-HEALS — it
   does NOT fail this check.** If absent, create it empty, say so in one
   line, and continue. Its absence is unambiguous (a snapshot predating
   the section recorded no teammates, and empty is the correct default),
   so failing on it would strand every snapshot written by a prior
   version. The other six carry state no default can reconstruct, which
   is why they still FAIL.

4. **`current_step_file` exists on disk.** From the loaded Pipeline
   Position section, resolve `current_step_file` to
   `{project-root}/.claude/skills/ai-dlc/steps/{current_step_file}`.
   If the file does not exist, FAIL with:
   > *"Snapshot references `current_step_file: {value}` but that
   > step file does not exist. Resume cannot dispatch. Reply
   > `archive`, `override <correct-step-file>`, or `abort`."*

5. **Git branch match.** Run `git branch --show-current`. Compare it to
   the branch recorded in the snapshot (in Pipeline Position or Recent
   Activity). If the current branch does not match, do NOT silently
   resume on the wrong branch:
   > *"Snapshot was finalized on branch `{snapshot_branch}` but
   > current branch is `{current_branch}`. Reply `switch` to
   > `git checkout {snapshot_branch}` and resume, `continue-here`
   > to resume on the current branch (I will update the snapshot's
   > branch field), or `abort`."*

6. **`last_gate_passed` recency.** Parse the timestamp from the loaded
   `last_gate_passed` field. If more than 7 days old relative to
   today's date, surface a warning (not a hard fail):
   > *"Warning: snapshot's last gate was {days} days ago. Pipeline
   > state may be stale relative to the code and external systems.
   > Reply `proceed` to resume as-is, `archive` to start fresh, or
   > provide additional context."*

   Wait for the user's reply before dispatching.

If all six checks pass (budget within threshold, snapshot loaded,
integrity verified, branch matches or user confirmed, recency
acceptable), continue with the Step 0 path 2 dispatch. Otherwise the
user's reply directs the next action.

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
  `pipeline-snapshot.md`. Never delete it outright. The live file keeps all seven
  sections: a section is trimmed by moving its superseded entries out, never by
  dropping the section. Then run:

      bash scripts/ai-dlc/rotate-snapshot-archive.sh \
           _bmad-output/pipeline-snapshot-history.md --apply

Then re-run the script. It must exit 0 before the sprint proceeds.

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
`clarification_asked` field (Step 6): `yes` if you asked, `n-a` if the
operator pre-directed the priority.

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
| feature | discovery → research-requirements → architecture → stories-test-strategy → [ui-direction] → implementation → sprint-review → deploy-validate → retro | `discovery.md` |
| bug | bug-investigation → implementation → deploy-validate → retro | `bug-investigation.md` |
| carry-over | carry-over-evaluation → discovery → research-requirements → architecture → stories-test-strategy → [ui-direction] → implementation → sprint-review → deploy-validate → retro | `carry-over-evaluation.md` |
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

**Note:** For `feature` variant, the discovery step is scoped — it updates
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
Sprint Context section.

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
project from sprint 1, so the script derives that case from the frozen
archives instead.

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
On a greenfield project it creates the file.

Rotation lives HERE, at pipeline start, and not at sprint close, for one
reason: `sprint-id` above must be able to read the closed sprint's
`status: done`. Rotating at close prunes that block, and the successor
does not exist yet — so the number has nowhere to come from and the roll
falls to whoever remembers to do it by hand.

Exit **3** is a HARD_BLOCK: the prior sprint is not closed (`status:` is
not `done`), or a frozen archive already exists and differs from the
canonical it would freeze. Surface it and wait — never freeze live state.

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

**Option labels carry no recommendation.** Do not append `(Recommended)`, or
any equivalent, to an option. That token appears nowhere in this skill — it
was invented by a lead, and on the corpus where it was measured the operator
took the option carrying it in 3 of 5 turns. A lead that has already
misresolved the scope will label the misreading `(Recommended)`, and the
badge does its most damage in exactly the case this pause point exists to
catch. Present the options flat and let the operator choose.

**No pause flag here.** Rule 3 tells you to `touch
_bmad-output/pipeline-paused.flag` at a pause point; pause point (d) is the
exception, and this is deliberate rather than an omission. The flag exists so
the Stop hook can tell an intentional pause from a stall, and a solicited
`AskUserQuestion` is neither — you have not ended the turn, the answer
arrives as a tool result rather than a UserPromptSubmit, and no
acknowledgement is owed because you already stopped and asked. Setting the
flag here leaves a pause nobody clears. The same asymmetry is why
`validate-steering-budget.sh` scores an AskUserQuestion answer as citable
operator text but never as a steamroll.

**Record the outcome in the routing record** (fields below): `scope_confirmed`
and `scope_confirmed_cite`. Then proceed — a correction is not a re-route.
Fold what the operator corrected into the scope you carry forward; only
re-run Step 3 if the correction changes the pipeline VARIANT, which is rare
and which you must say out loud if you conclude it.

**Initialize the pipeline snapshot.** Before the READ AND FOLLOW, handle
the pipeline snapshot at `_bmad-output/pipeline-snapshot.md`:

- **If the file does NOT exist:** create it with initial state:
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
    - `user_request_cite` — the `SHA256:` value of that same entry, copied.
      This is what makes the field above checkable: the hash resolves to a
      hook-written record, and that record's body is independently citable
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
    - `scope_confirmed_cite` — the `SHA256:` value of the matching entry in
      `_bmad-output/operator-answers-history.md`, copied. That file is written
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
      lead chose is the self-declaration hole this field exists to close)
  - Sprint Context (`sprint_id` as resolved above — an integer, never
    `none`; remaining fields from `sprint-status.yaml` if it exists)
  - Recent Activity (empty — will be populated by `gate-validation.md`
    Check 14 on each gate passage)
  - Open Items (empty)
  - Locked Decisions (empty)
  - In-Flight Teammates (empty table, header row only:
    `agent | role | deliverable | dispatched-at | status`; rows are added
    at dispatch as `in-flight`, become `delivered-reachable` at join if the
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

- **If the file ALREADY exists** (a stale snapshot from a previous
  pipeline run — Step 0 did not dispatch to a resume, so the user is
  starting fresh with an old snapshot still on disk): do NOT silently
  overwrite. Absorb the old file into the one snapshot archive:

      bash scripts/ai-dlc/rotate-snapshot-archive.sh \
           _bmad-output/pipeline-snapshot-history.md \
           --absorb _bmad-output/pipeline-snapshot.md --apply

  then create a new snapshot with initial state as above. Announce
  the archival in the output so the user knows the previous state
  was preserved.

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
