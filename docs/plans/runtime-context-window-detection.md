# Detect the context window at runtime instead of trusting a launcher env var

## RESUME HERE

**Resume with exactly: `READ and FOLLOW docs/plans/runtime-context-window-detection.md`.**

**STATUS: NOT STARTED. Recorded 2026-09-02 as the operator's highest-priority item, ahead of
the graph-ledger drain program.** `docs/plans/graph-ledger-full-drain.md` is PAUSED at batch 45
for this; its own action 1 says so. Nothing in this file has been built, and the premise checks
below are the only work done.

This section is the only current status record in this file.

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

## What the premise check already established — do not re-derive, but do re-verify it still holds

Measured 2026-09-02 against `origin/main`, with a control in the same invocation:

- **There are TWO live readers of the env var, not one**, and they carry hand-written copies of
  the same resolution order:
  - `core/hooks/ai-dlc-context-sensor.sh:386` — `resolve_window()`
  - `core/scripts/validate-compact-window.sh:157` and `:182` — the second also sets
    `WINDOW_SOURCE` to the string `env CLAUDE_CODE_AUTO_COMPACT_WINDOW`
  **Change both or the validator and the sensor will disagree about the window.** Grep for
  further readers before starting; that count is a floor, not a census.
- **The existing precedence is env → `settings.local` → project → user**, documented at
  `core/hooks/ai-dlc-context-sensor.sh:379`, and the resolved value is then clamped:
  `EFFECTIVE = min(WINDOW, MODEL_MAX)` at `core/hooks/ai-dlc-context-sensor.sh:402`. **The new
  source slots ABOVE the env var.** Decide deliberately whether `target` is subject to the
  `MODEL_MAX` clamp — `target` is already model-derived, so clamping it twice may be a no-op or
  may be wrong, and that is a question to answer with a measurement rather than a reading.
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

## NEXT ACTIONS — numbered, in order

1. **Re-verify the premise before building.** Every bullet above is a hypothesis about a tree
   that has moved; the measured base rate of expired premises in this repo is roughly one in
   two. Re-run the reader grep with a control, and re-read the two resolution sites.
2. **Derive the full reader set**, do not trust the two named above. Ask separately which readers
   IGNORE the window rather than only which ones read it — a status-blind reader has no token for
   a grep to find, and that exact question is what a sibling batch missed one release ago.
3. **Decide where the read is SITED, once.** Two hand-written copies of one resolution order is
   the drift `.claude/rules/mechanism-design.md` warns about, and no invariant currently binds
   them. Prefer one function both readers call over editing the order twice; if that is not
   possible, bind the copies and say why.
4. **Build it**, honouring the fallback chain and the null constraints. `bash` is 3.2 — no
   `mapfile`, `readarray`, `declare -A`; an empty array under `set -u` is an error. `jq` is
   already a dependency of the sensor.
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
6. Both readers found in action 2 agree on the window for one input. Assert it, in the same
   invocation, against a control input where they should differ.

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
