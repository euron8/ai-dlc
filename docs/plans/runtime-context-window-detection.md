# DISCHARGED — DO NOT EXECUTE — Detect the context window at runtime instead of a launcher env var

## STATUS

**DISCHARGED 2026-09-02, shipped as v0.485.0, merged to `main` at `9cada242` (ref confirmed
moved from `ecd75049`). Do not execute this file.** Everything below the next section is the
record of work that is finished; a session that follows it will redo a landed change.

`docs/plans/graph-ledger-full-drain.md` is UNPAUSED — its action 1 is restored to batch 45,
and that is the next thing to pick up.

This section replaces the status record that stood here, and is the only one in this file.

## What shipped, and what did NOT

`core/hooks/ai-dlc-window.sh` is the single resolver. The chain is the runtime file, then
`CLAUDE_CODE_AUTO_COMPACT_WINDOW`, then the three settings layers, then the model default.
`core/hooks/ai-dlc-context-sensor.sh` sources it as a sibling; `core/scripts/validate-compact-window.sh`
reaches it by naming both layouts. Places that resolve a window went from **2 to 1**, derived
with the same grep at `ecd75049` and at `HEAD`.

**Done-when 2 is only half established, and this is the one open item.** That switching models
mid-session changes the target with no pipeline restart was proven mechanically: one pipeline,
no state reset, only the file rewritten between two hook fires, giving `effective_window`
420000 then 262144. What was NOT driven is the PRODUCER half — that `/model` actually causes
`~/.claude/statusline.sh` to rewrite the file — because this task was instructed not to edit
that script, and no live model switch was observed during the work. The reader honours whatever
the file says; whether the file follows `/model` rests on the operator's own report of the
statusline's behaviour, not on a measurement taken here.

**Requirement 5 needed no change** and was verified in code rather than from the comment
claiming it: `ai-dlc-context-sensor.sh:302` already sums
`input_tokens + cache_creation_input_tokens + cache_read_input_tokens`, the same input-only
formula `used_percentage` uses.

**Requirement 2 is unsatisfiable in the validator**, reported rather than faked. It is a script
with no stdin and so no session id (zero `session_id` references against a control of 16
`WINDOW` references). It takes `AI_DLC_SESSION_ID` when a caller has one; with none it skips
the runtime layer and says `[window.json not consulted: no session id]`.

**Three false zeros were caught by controls while measuring the premise**, all the same class:
`\b` and `\s` are not POSIX ERE, so `git grep -E` returned a clean, plausible 0 for tokens
present 7 times and for hook files that do source a shared sibling. That last zero, had it been
believed, would have left the duplication in place — it was the evidence that the comment
justifying the duplication was false.

## Start here

- **`/Users/n8/git/ai-dlc`** — WRITE. The change lands in `core/`.
- **`/Users/n8/git/graph`** — **READ ONLY.** `.claude/rules/consumer-boundary.md` is
  unconditional: an ai-dlc session never writes to a consumer. A consumer runs its own installed
  engine, so nothing here reaches it until the operator runs a pull.
- **`~/.ai-dlc/window.json`** — OUTSIDE the repo, and this task consumes it: **read it, never
  write it.** A pipeline that writes its own window file would be reading back its own guess.
- **`~/.claude/statusline.sh`** — writes that file. **Do not edit it as part of this task**, and
  do not write to it to make a test pass. Operator instruction, stated when the task was given.
  Seed a temp file and point the reader at it instead.

**Ping the operator** on any question, on any decision, on completion, and on any early stop.
From outside, a session that is thinking and a session that is waiting on a human look
identical. Merges are preapproved — do not stop to ask for one.

## The problem

The pipeline reads `CLAUDE_CODE_AUTO_COMPACT_WINDOW` from the environment and ramps snapshot
frequency against it. That variable is set once by the shell launcher and **does not change when
the model is switched mid-session with `/model <alias>`**. A launcher configured for a 1M-context
model exports `420000` or `1000000`; switch the session to a 262144-context model and the
pipeline ramps toward a number the session never reaches, so the snapshot is stale when
compaction fires.

## The new source of truth

`~/.ai-dlc/window.json`, written by the statusline command.

```json
{
  "model": "local-qwen3",
  "window": 262144,
  "target": 262144,
  "used_percentage": 20,
  "total_input_tokens": 52924,
  "current_usage": {
    "input_tokens": 52924,
    "output_tokens": 40,
    "cache_creation_input_tokens": 0,
    "cache_read_input_tokens": 0
  },
  "session_id": "3faf79e7-883b-41e9-ae51-ff629539b31c",
  "ts": 1788398758
}
```

| Field | Meaning |
|---|---|
| `model` | Current model id. Updates on in-session `/model` switch. |
| `window` | Resolved context window in tokens. Honors `CLAUDE_CODE_MAX_CONTEXT_TOKENS` for custom gateway model ids. |
| `target` | Precomputed ramp target: `window >= 1000000 ? 420000 : window` |
| `used_percentage` | Percent of window used, from input tokens only: `input_tokens + cache_creation_input_tokens + cache_read_input_tokens`. Excludes `output_tokens`. |
| `total_input_tokens` | Tokens currently in the context window, from the most recent API response. |
| `current_usage` | Token counts from the last API call. |
| `session_id` | Claude Code session id. |
| `ts` | Unix epoch seconds when the file was written. |

## Required changes

1. Use `target` from `~/.ai-dlc/window.json` as the ramp target.
2. Before trusting the file, compare `session_id` to the pipeline's own session id. On mismatch,
   fall back.
3. Treat the file as stale if `ts` is more than 60 seconds old. On stale, fall back.
4. Fallback order: `~/.ai-dlc/window.json` → `CLAUDE_CODE_AUTO_COMPACT_WINDOW` → existing
   default. Never crash on a missing or unreadable file.
5. If the pipeline computes context proximity itself, use the same input-only formula as
   `used_percentage` so the two agree.

## The shape to build — THIS IS A REFACTOR, and the existing structure is not a constraint

**Operator instruction, 2026-09-02, correcting the first draft of this file: build for the
OUTCOME and structure the code around achieving it. Do not treat what is there now as the frame
to fit into.** The first draft read as "add a branch above the env var in two places", which
preserves exactly the shape that made this fragile.

**The outcome: the pipeline knows the window the session is ACTUALLY running with, at the moment
it asks, and every reader gets that answer from ONE place.**

What follows from that, and each of these is licence rather than obligation:

- **One resolver owns the whole chain**, and every reader calls it. Two hand-written copies of
  one precedence order is the defect this task keeps tripping over, not a fact to work around.
  `.claude/rules/mechanism-design.md` — *"a schema, list or grammar written N times is N−1
  chances to drift. Single-source it as data the reader LOADS"* — and *"take the reshaped or
  reduced form over the additive one"*.
- **The env var stops being the top of the chain.** It becomes one fallback among others. Its
  current primacy is documented at `core/hooks/ai-dlc-context-sensor.sh:379` as mirroring Claude
  Code's own config merge; that rationale is about a STATIC config and does not survive a source
  that changes mid-session.
- **Nothing about the current layering is protected** — not the `settings.local` → project →
  user order, not the `EFFECTIVE = min(WINDOW, MODEL_MAX)` clamp at
  `core/hooks/ai-dlc-context-sensor.sh:402`, not the split between the hook and the validator.
  If the clamp is redundant once `target` is authoritative, delete it; if a settings layer has no
  remaining subject, say so and remove it. **A guard whose removal changes nothing is not
  load-bearing.**
- **Delete what the new source makes vestigial rather than leaving it beside the new path.**
  Fix by subtraction first. Two resolution paths where one would do is how the next reader gets
  the stale answer.

**What is NOT open**: the operator's five required changes and the constraints below, the
`~/.ai-dlc/window.json` schema, and the instruction not to edit `~/.claude/statusline.sh`. Those
are the specification. Everything about how this repo currently reaches a window number is yours
to reshape.

**The acceptance criteria are behavioural on purpose.** None of them names a file. If the right
structure means the answer comes from somewhere neither current reader lives, that is a better
outcome and not a deviation.

## Constraints the operator stated

- **`current_usage` is `null` before the first API call in a session, and again after `/compact`
  until the next API call repopulates it.** `used_percentage` and `remaining_percentage` may also
  be null early in a session. **Do not coerce null to 0; absent is not empty.**
- The file is rewritten on every statusline render: event-driven with a 300ms debounce, plus a
  10 second `refreshInterval`. Event triggers go quiet while the main session waits on background
  subagents, which is why the interval exists.
- **The path is fixed and not session-scoped. Concurrent Claude Code sessions write the same
  file.** That is what the `session_id` check in change 2 guards against.
- Writes are atomic (temp file plus rename), so partial reads do not occur.

## What the premise check found — this is a MAP OF WHAT EXISTS, not a description of what to keep

Measured 2026-09-02 against `origin/main`, with a control in the same invocation:

- **There are TWO live readers of the env var, not one**, and they carry hand-written copies of
  the same resolution order:
  - `core/hooks/ai-dlc-context-sensor.sh:386` — `resolve_window()`
  - `core/scripts/validate-compact-window.sh:157` and `:182` — the second also sets
    `WINDOW_SOURCE` to the string `env CLAUDE_CODE_AUTO_COMPACT_WINDOW`
  **That duplication is the thing to remove, not to update twice.** Grep for further readers
  before starting; that count is a floor, not a census.
- **The existing precedence is env → `settings.local` → project → user**, documented at
  `core/hooks/ai-dlc-context-sensor.sh:379`, and the resolved value is then clamped:
  `EFFECTIVE = min(WINDOW, MODEL_MAX)` at `core/hooks/ai-dlc-context-sensor.sh:402`. **Recorded
  so you know what you are replacing.** Whether any of it survives is a design call, not a
  given — including the clamp, which may be a no-op once `target` is authoritative, since
  `target` is already model-derived. Answer that with a measurement rather than a reading.
- **Hook stdin DOES carry `session_id`**, so requirement 2 is feasible.
  `core/hooks/ai-dlc-context-sensor.sh:41` names the shared schema: `session_id`,
  `transcript_path`, `cwd`, `prompt_id`, `permission_mode`, `agent_id`, `agent_type`, `effort`.
  Confirm `validate-compact-window.sh` can reach a session id too — it is a script, not a hook,
  and may have no stdin. **If it cannot, requirement 2 is unsatisfiable there and that is a
  finding to report, not a thing to fake.**
- **Requirement 5 may already be satisfied, so CHECK before changing anything.**
  `core/hooks/ai-dlc-context-sensor.sh:44-49` states the hook already computes
  `input_tokens + cache_creation_input_tokens + cache_read_input_tokens` from the last
  main-thread assistant message after the most recent compaction boundary, and claims that
  equals `compactMetadata.preTokens`. That is the same input-only formula `used_percentage`
  uses. **Verify it, then say so; do not "fix" a formula that already agrees.**
- Both `~/.ai-dlc/window.json` and `~/.claude/statusline.sh` exist on this machine today.

## The design chosen — action 3, written before any edit to the subject

**One library, sourced by both readers.** New file `core/hooks/ai-dlc-window.sh`, exposing
`ai_dlc_parse_window` and `ai_dlc_resolve_window`. It is not executable and is sourced, never
run.

**The NOTE that justified the duplication is false, and that is what unblocks this.**
`core/hooks/ai-dlc-context-sensor.sh:357-360` says hooks "cannot source from scripts/, so they
are duplicated deliberately". Two shipped hooks already source a shared sibling:
`core/hooks/ai-dlc-continue.sh:280-282` and `core/hooks/ai-dlc-recover.sh:138` both load
`core/hooks/ai-dlc-handoff-pending.sh` through `dirname "${BASH_SOURCE[0]}"`, and that helper's
own header states the same motive this task has — the two callers "ask the same question and
the two answers must not drift". A library in `core/hooks/` ships to `.claude/hooks/` beside
its callers, so the sibling resolves in both layouts. `scripts/install.sh:365` copies
`core/hooks/*.sh` as a glob, so the new file needs no packaging edit.

**The validator reaches it by naming both layouts**, which is the form `I33c` prescribes and
`core/scripts/sprint-status.sh:129-137` demonstrates: `$AI_DLC_ROOT/core/hooks/` in this repo,
`$AI_DLC_ROOT/.claude/hooks/` in a consumer, with an env override for tests. Unreadable means
fall back to today's behaviour, never crash.

**The resolver returns `window|source|model_max` in one call**, and the four layers are:

1. `$AI_DLC_WINDOW_FILE` (default `$HOME/.ai-dlc/window.json`) — taken only when the file is
   readable, `jq` parses it, `.session_id` equals the caller's non-empty session id, `ts` is
   within `$AI_DLC_WINDOW_MAX_AGE` (default 60) seconds of now, and `.target` is a positive
   integer. Emits `model_max` from `.window` as well.
2. `CLAUDE_CODE_AUTO_COMPACT_WINDOW`.
3. `settings.local.json`, then project `settings.json`, then user settings.
4. Nothing — empty window, the model default.

**The `model_max` return is why the clamp survives rather than being deleted.** The plan
invited removing `EFFECTIVE = min(WINDOW, MODEL_MAX)`. Measured against the chain above,
deleting it is wrong in one direction and keeping it unchanged is wrong in the other: on a
262144-token model whose row has not been proven, `MODEL_MAX` is 200000, so an unchanged clamp
would drag a correct runtime `target` of 262144 down to 200000. Layer 1 therefore supplies
`MODEL_MAX` from `.window` and marks the row known, after which the existing clamp arithmetic
is already correct and untouched. That is the reshaped form rather than a second branch beside
the clamp, and it makes the `imminent` band — gated on `ROW_KNOWN` — reachable in the one case
where the row is a fact rather than a guess.

**What is deleted**, not left beside the new path:

- `parse_window()` and `resolve_window()` from `core/hooks/ai-dlc-context-sensor.sh` and from
  `core/scripts/validate-compact-window.sh`, plus the NOTE asserting their byte-identity.
  Confirmed byte-identical today by `cmp` with a control, and confirmed bound by nothing:
  no arm in `scripts/validate-enforcement-map.sh` joins the two files (control: 49 arms mention
  `core/hooks` at all).
- The validator's SECOND walk of the settings layers at
  `core/scripts/validate-compact-window.sh:185-192`, which re-derives `WINDOW_SOURCE` by
  restating the precedence `resolve_window()` had just applied. One call now returns both.

**Requirement 2 is unsatisfiable in the validator, and that is reported rather than faked.**
`validate-compact-window.sh` is a script, not a hook: it reads no stdin and carries zero
`session_id` references (control: 16 `WINDOW` references in the same file). It accepts a
session id from `AI_DLC_SESSION_ID` when a caller has one; with none, layer 1 is SKIPPED rather
than trusted, and the reported source says so instead of implying the layer was consulted and
lost.

## NEXT ACTIONS — numbered, in order

1. **Re-verify the premise before building.** Every bullet above is a hypothesis about a tree
   that has moved; the measured base rate of expired premises in this repo is roughly one in
   two. Re-run the reader grep with a control, and re-read the two resolution sites.
2. **Derive the full reader set**, do not trust the two named above. Ask separately which readers
   IGNORE the window rather than only which ones read it — a status-blind reader has no token for
   a grep to find, and that exact question is what a sibling batch missed one release ago.
3. **Design the resolver before editing anything, and write down the shape you chose and what
   you are deleting.** One place owns the chain; every reader calls it. This is the step where
   the refactor is decided, and skipping it produces the additive version by default — a new
   branch bolted above an unchanged env-var path, in two files, which is the structure that
   caused the defect. If you conclude the duplication must stay, that is a finding to report
   with its reason, not a default to fall into.
4. **Build it**, honouring the fallback chain and the null constraints, and **remove what the
   new source makes vestigial in the same change**. A second resolution path left beside the new
   one is how a later reader gets the stale answer. `bash` is 3.2 — no `mapfile`, `readarray`,
   `declare -A`; an empty array under `set -u` is an error. `jq` is already a dependency of the
   sensor.
5. **Add fixture arms, and seed from what the PRODUCER emits, never from what the reader
   accepts.** `core/fixtures/context-sensor/run.sh` and `core/fixtures/context-provenance/run.sh`
   already `unset CLAUDE_CODE_AUTO_COMPACT_WINDOW` at the top because an ambient value silently
   rewrites the arm that tests the default into a second copy of the arm that tests the override.
   **A new source read from `$HOME` has the same hazard and worse** — the real
   `~/.ai-dlc/window.json` will be present on the machine running the suite, so every arm needs
   its home directory or the path pinned, or the fixture tests the operator's live session.
   Score every new arm against the pre-fix code and confirm exactly the intended arms fail.
6. **Gate it the way the hook runs it.** `git push` is the cheapest way to run the suite; read
   the GATE's own exit, not a tally and not a banner. Confirm the ref moved.
7. **After the merge, re-derive this file's RESUME HERE block and prove it is resumable.** Run
   `bash scripts/validate-plan-shape.sh`; that is the floor, not the answer. If action 1 still
   names work you have finished, replace it. Fix the COMMAND, never only the prose.
8. **Retitle this file `DISCHARGED — DO NOT EXECUTE` when it is spent**, and unpause
   `docs/plans/graph-ledger-full-drain.md` by restoring its action 1 to batch 45.

## Done when

Each is a command, and each was checked to be answerable at the point it is read.

1. A 1M-context model reports ramp target **420000**; a 262144-context model reports **262144**.
   Derive both from the shipping code against a seeded `window.json`, not by reading it.
2. Switching models mid-session with `/model` changes the target **without restarting the
   pipeline**. This one needs a live session; if it cannot be driven mechanically, state that and
   record the manual observation rather than asserting it.
3. Missing, unreadable, stale (`ts` older than 60s) and foreign-`session_id` files each fall back
   cleanly, and each is asserted **separately** — one arm covering all four cannot say which
   fallback fired.
4. A null `current_usage` produces neither a 0% reading nor a divide-by-zero. Assert the VALUE is
   absent, not that a count is unchanged.
5. `AI_DLC_FIXTURE_NO_SKIP=1 bash .githooks/pre-push` is green on the release branch, with each
   changed fixture read BY NAME against an impossible-name control in the same invocation.
6. **Every reader found in action 2 agrees on the window for one input** — trivially, if they
   now share a resolver, in which case assert the SHARED CALL rather than the agreement, because
   two callers of one function cannot disagree and a null there proves nothing. If any reader
   still resolves independently, assert agreement in the same invocation against a control input
   where they should differ.
7. **The count of places that resolve a window is lower than it was.** Derive it before and
   after with the same grep, and report both numbers. A refactor that leaves the old path in
   place beside the new one has not landed, however green the arms are.

## Hazards

- **The env var is live in this operator's own environment.** `CHANGELOG.md` records that it
  "was live in the environment and outranks" the settings layers, and that the hermetic setup
  block had to `unset` it. Any measurement taken without unsetting it is measuring the launcher.
- **A validator that resolves its own root ignores the probe tree you built for it.** Set
  `AI_DLC_PROJECT_ROOT` and read the output for a path that could only have come from the wrong
  tree.
- **The Bash tool's shell is zsh**: no `PIPESTATUS`, and an apostrophe inside a single-quoted
  `awk` program closes the string and breaks the whole file. Force `bash -c` for loops and
  heredocs.
- **A hook's prose is PAYLOAD.** `core/fixtures/postcompact-rulebook-recovery/run.sh` holds the
  directive `ai-dlc-recover.sh` emits under a 9500-character bound; adding explanatory lines to a
  hook has already breached it once.
- **`core/` paths must not appear in runtime-pipeline prose.** `install.sh` maps `core/<x>` to
  `.claude/<x>`, so such a citation is a dead link for every consumer reader, and the
  enforcement-map invariant fails the push on it.
