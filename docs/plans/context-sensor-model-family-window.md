# Replace the sensor's model-row guess with operator-declared, per-family window vars

## RESUME HERE

**You were started with one sentence: `READ and FOLLOW docs/plans/context-sensor-model-family-window.md`. This section is the ONLY CURRENT STATUS RECORD in this file.**

**State: BUILT as v0.490.0, gate pending at the time of this write.** Actions 1–6 are done
and action 8's triple is written; action 7 (the gate) and 9 (re-derive this block after the
merge) are what remain. The graph migration brief is the section "Graph migration brief"
at the bottom of this file. The design below is the record of what was built.

## Start here

- **`/Users/n8/git/ai-dlc`** — WRITE. The change lands entirely in `core/`.
- **`/Users/n8/git/graph`** — **READ ONLY.** `.claude/rules/consumer-boundary.md` is
  unconditional. This plan's deliverable to graph is a **brief the operator carries in**, not
  an edit — see action 6. Read it if needed to confirm current values; do not write or edit
  anything in that tree.
- **Ping the operator** on any question, on any decision, on completion, and on any early
  stop. Merges are preapproved — do not stop to ask for one.

## The problem this replaces

`core/hooks/ai-dlc-context-sensor.sh` needs `MODEL_MAX` — the model's true ceiling — to
clamp `EFFECTIVE = min(WINDOW, MODEL_MAX)` (`core/hooks/ai-dlc-context-sensor.sh:401-404`) and
to gate the `imminent` band on `ROW_KNOWN`
(`core/hooks/ai-dlc-context-sensor.sh:467`). Today it GUESSES: `AI_DLC_MODEL_ROW` is a closed
`200K|1M` vocabulary (`core/hooks/ai-dlc-context-sensor.sh:341-344`), and absent that, it tries
to PROVE `1M` by watching whether resident tokens cross
`PROOF_1M = 200000 - COMPACT_RESERVE` (`core/hooks/ai-dlc-context-sensor.sh:146,347-352`) — a
proof that, once made, is written to `.context-sensor-model` and is **sticky across every
future session** (`core/hooks/ai-dlc-context-sensor.sh:85,350-351`).

Two measured failures, both real, not hypothetical:

- **Claude Haiku 4.5 is natively 200K while every other current-generation Claude model is
  1M** (Fable 5/5.1, Opus 5/4.8/4.7/4.6, Sonnet 5/4.6). A single `AI_DLC_MODEL_ROW=1M` pin —
  which is exactly what graph has set — is silently wrong the moment a session runs Haiku.
- **The proof-by-token-growth direction is the wrong one.** A session on a genuinely smaller
  window (256K, measured on this operator's local `qwen3` models) never crosses `PROOF_1M`
  (a lower bound below the real one is never proven), so `ROW` defaults to the fallback and
  `MODEL_MAX` is whichever constant the fallback carries — and if that fallback is ever
  large, every band computes against a ceiling the session cannot reach and the sensor is
  **silent through the compaction it exists to warn about**. Measured by driving the
  shipping hook directly: same tokens, same settings, differing only in which layer
  answered — `window.json` present → correct IMMINENT fire; absent → **silent**, because the
  fallback `MODEL_MAX` overstated the ceiling.

Statusline (`window.json`, layer 1 of `ai_dlc_resolve_window`, `core/hooks/ai-dlc-window.sh`)
already solves this **when present**, but it requires a `statusLine` command configured —
absent from `templates/settings.json.template` and a single global slot a consumer may
already be using for their own script (graph is: `~/.claude/statusline.sh`, user-scoped).
AI/DLC will not claim that slot. This plan replaces the FALLBACK, not layer 1.

## The design — settled, re-verify before building

**Delete the guess. Let the operator declare the ceiling per model family, and classify by
family substring so a version bump never needs a code or settings change.**

1. **Five new settings, one per family**, read from the environment exactly as
   `AI_DLC_MODEL_ROW` is today:
   ```
   AI_DLC_MODEL_FABLE_WINDOW
   AI_DLC_MODEL_OPUS_WINDOW
   AI_DLC_MODEL_SONNET_WINDOW
   AI_DLC_MODEL_HAIKU_WINDOW
   AI_DLC_MODEL_OTHER_WINDOW
   ```
   Each an integer token count (`ai_dlc_parse_window`'s existing `1m`/`400k`/bare-int forms
   apply — reuse it, don't reparse).

2. **Classify by SUBSTRING of `message.model`, not by exact id.** The sensor already
   extracts `LEAD_MODEL` from the transcript for the arm record
   (`core/hooks/ai-dlc-context-sensor.sh:286`) — reuse that read,
   do not add a second one. Every current id carries its family name literally
   (`claude-opus-5`, `claude-opus-4-8`, `claude-sonnet-5`, `claude-haiku-4-5`,
   `claude-fable-5-1`, `claude-mythos-5-1`):
   ```
   case "$LEAD_MODEL" in
     *fable*|*mythos*) FAMILY=FABLE  ;;
     *opus*)           FAMILY=OPUS   ;;
     *sonnet*)         FAMILY=SONNET ;;
     *haiku*)          FAMILY=HAIKU  ;;
     *)                FAMILY=OTHER  ;;
   esac
   ```
   `opus-4-8 → opus-4-9 → opus-5 → opus-5-1` all match `*opus*` with zero code changes. A
   genuinely new top-level family (no case arm) falls to `OTHER`, which is the conservative
   bucket below — fails toward "fires early," never toward "silent."

3. **The matched family's env var, if set, IS `MODEL_MAX`.** No proof, no cache, no
   cross-session state. If unset, `MODEL_MAX` = **200000** — the smallest real current tier,
   Haiku's own true max, and consistent with Claude Code's own fallback: its changelog
   records *"Changed auto-compact to keep sessions on unrecognized model IDs within the
   assumed context window instead of letting them grow past it"* (`~/.claude/cache/changelog.md:904`
   on this machine; outside this repo, so re-derive with
   `grep -n "unrecognized model IDs" ~/.claude/cache/changelog.md` rather than trust this
   line, and if it doesn't resolve, 200000 stands on the first two reasons alone). The state
   file records that the
   window was **not declared**, mirroring today's `row_known` gate: yellow/red still fire on
   the conservative floor; `imminent` stays gated off until a real value is known, same as
   `ROW_KNOWN=0` does today (`core/hooks/ai-dlc-context-sensor.sh:467`).

4. **Delete the proof mechanism entirely**: `PROOF_1M`
   (`core/hooks/ai-dlc-context-sensor.sh:146`), the `ROW`/`ROW_KNOWN` inference block
   (`core/hooks/ai-dlc-context-sensor.sh:329-352`), and `.context-sensor-model` /
   `$MODEL_FILE` (`core/hooks/ai-dlc-context-sensor.sh:85,350-351`) — including the
   sticky-cache write. Nothing is learned or cached anymore; the answer is deterministic
   from settings + the transcript on every fire.

5. **`window.json` (layer 1) is untouched and still wins.** `_RT_MODEL_MAX` from
   `ai_dlc_resolve_window` — assigned into the sensor at
   `core/hooks/ai-dlc-context-sensor.sh:374-398`, the FUNCTION itself lives in
   `core/hooks/ai-dlc-window.sh`, do not confuse the two — overrides the family lookup
   exactly as it overrides `ROW`/`MODEL_MAX` today. This plan only replaces what happens
   when layer 1 doesn't answer.

6. **State-file schema changes**, documented at
   `core/skills/ai-dlc/steps/_gate-procedures.md:724-734`: `model_row=200K|1M` is replaced by
   `model_family=FABLE|OPUS|SONNET|HAIKU|OTHER` and `row_known=0|1` is renamed
   `window_declared=0|1` (same semantics: 1 iff the matched family's env var was set, or
   layer 1 answered). Rewrite `core/skills/ai-dlc/steps/_gate-procedures.md:750-756`'s
   operator-facing prose to name the five vars instead of `AI_DLC_MODEL_ROW`.

## Reader set — floor, not a census; derive before touching anything

`grep -rl AI_DLC_MODEL_ROW core/ scripts/` returns 12 files today. Some are semantic readers,
some are incidental (a fixture's `AI_DLC_*` wildcard scrub, which already covers any new
`AI_DLC_MODEL_*_WINDOW` name with no change needed — confirmed at
`core/fixtures/context-sensor/run.sh:29`, and I10 in `scripts/validate-enforcement-map.sh:825-840`
requires exactly that scrub and needs no update). Classify each of the 12 before editing;
this list is a floor:

```
core/hooks/ai-dlc-context-sensor.sh                                  semantic — action 2
core/fixtures/context-sensor/run.sh                                  semantic — action 3
core/skills/ai-dlc/steps/_gate-procedures.md:730,750-756              semantic — action 4
core/fixtures/layer-readopt-gate/run.sh                              classify
core/fixtures/handoff-resume-guard/run.sh                            classify
core/fixtures/settings-merge-unparseable-template/run.sh             classify
core/fixtures/handoff-completion-assertion/run.sh                    classify
core/skills/ai-dlc-update/SKILL.md                                   classify
core/skills/ai-dlc-update/reconcile/template-sites.md                classify
core/skills/ai-dlc-update/reconcile/settings-merge.sh                classify
scripts/validate-enforcement-map.sh:825                              confirmed non-applicable
scripts/install.sh                                                   classify (likely a glob copy, not semantic)
```

`core/scripts/validate-compact-window.sh` is confirmed OUT of scope — `--row` is accepted
and ignored (`core/scripts/validate-compact-window.sh:114`), the validator has been
row-independent since the clamp redesign
(`core/scripts/validate-compact-window.sh:17-19`), and it never touches
`MODEL_MAX`/`ROW_KNOWN`. No change there.

### NEXT ACTIONS — numbered, in order

1. **Re-verify the premise.** Re-run the reader grep above; re-read
   `ai-dlc-context-sensor.sh:325-430` and confirm line numbers still match — they will have
   moved if anything landed on this file since. The base rate of an expired premise in this
   repo is roughly one in two.
2. **Rewrite the sensor.** Delete `PROOF_1M`, the `ROW`/`ROW_KNOWN` block, `$MODEL_FILE` and
   its write. Add the family `case` (reusing the already-extracted `LEAD_MODEL`, not a new
   transcript read), the five env-var reads, the 200000 conservative default, and the
   renamed state-file fields (`model_family`, `window_declared`).
3. **Rewrite the fixture.** `core/fixtures/context-sensor/run.sh` carries roughly 15
   `AI_DLC_MODEL_ROW=1M` / `row=1M` cases
   (`core/fixtures/context-sensor/run.sh:20,28,92-93,182-364` per the floor grep) built
   for the deleted mechanism — these do not get patched in place, they get replaced. Required
   arms, each a positive AND the control that proves it discriminates:
   - Each of the five families reads its own var when set — five positive cases.
   - **The one that actually proves separation, not just that some lookup fires**: set
     `AI_DLC_MODEL_OPUS_WINDOW` only, run a Haiku-family `LEAD_MODEL`, assert it does **not**
     inherit Opus's value — a near-miss beside the positive, in the same run.
   - Unset var on a recognized family → 200000 floor, `window_declared=0`, imminent gated
     off, yellow/red still fire — mutant control: seed the OLD constant in place of 200000
     and confirm the arm fails.
   - `window.json` present still overrides the family lookup regardless of which family
     matched — regression guard on layer-1 precedence.
   - A model id with no case-arm match (new/unknown family) lands in `OTHER`.
   - Per `fixture-mutants.md`: build every mutant as a copy with `cmp -s`, never in place.
4. **Rewrite the doc.** `_gate-procedures.md:724-756` — new state-file field list, new
   operator-facing prose naming the five vars, drop the `AI_DLC_MODEL_ROW` instruction.
5. **Resolve the classify-list**, updating or confirming non-applicable each of the eight
   remaining files, and re-run the floor grep as the close-out control: zero semantic hits
   for `AI_DLC_MODEL_ROW` outside historical CHANGELOG prose.
6. **Write the graph migration brief — do not apply it.** `consumer-boundary.md` governs:
   the deliverable is the exact `settings.json` `env` block snippet, all five vars, handed to
   the operator to carry into a graph session or apply themselves:
   ```
   AI_DLC_MODEL_FABLE_WINDOW:  1000000
   AI_DLC_MODEL_OPUS_WINDOW:   1000000
   AI_DLC_MODEL_SONNET_WINDOW: 1000000
   AI_DLC_MODEL_HAIKU_WINDOW:  200000
   AI_DLC_MODEL_OTHER_WINDOW:  256000
   ```
   plus an instruction to remove `AI_DLC_MODEL_ROW`. The Claude-family values are graph's own
   current `AI_DLC_MODEL_ROW=1M` pin, split per family (Haiku genuinely differs — see "The
   problem this replaces"), derivable from this repo alone. **`OTHER: 256000` is NOT
   derivable from this repo — it is the operator's own stated fact about the `local-qwen3` /
   `local-qwen3-max` models graph runs, given directly, not measured from any file here.**
   State that provenance in the brief itself rather than presenting it as measured; if it has
   changed since, ask the operator rather than assume. Removing `AI_DLC_MODEL_ROW` support
   ships safe without this brief ever being applied — the fallback becomes the 200000 floor,
   not a silent overstatement — so this is not a blocking dependency for the release.
7. **Gate it the way the hook runs it.** `AI_DLC_FIXTURE_NO_SKIP=1 bash .githooks/pre-push`,
   read the gate's own exit — not a backgrounded wrapper, not the fixture tally.
8. **Release.** `CHANGELOG.md` heading, `VERSION` bump, release commit message — standard
   triple, validated by `scripts/validate-release-version.sh`.
9. **After the merge, before you stop: re-derive this file's RESUME block.** Run the reader
   grep again and diff against what action 5 closed out. Mark this plan `DISCHARGED — DO NOT
   EXECUTE` if the work is complete and nothing is owed.

### Ping the operator

On any question, on any decision, on completion, and on any early stop. Scope is the
operator's — never narrow it on your own authority.

### Done when

1. `grep -rl 'AI_DLC_MODEL_ROW\|PROOF_1M\|MODEL_FILE=' core/hooks/ai-dlc-context-sensor.sh`
   returns zero, against a control that `SENSOR_RESERVE` (a constant that stays) still
   greps non-zero in the same file.
2. The fixture's five family-positive cases, the Haiku-does-not-inherit-Opus near-miss, the
   unset-conservative-floor case with its mutant control, and the layer-1-still-wins case
   all pass, driving the real shipping hook — not a hand-rolled probe.
3. `_gate-procedures.md`'s schema block and operator prose name the five vars and
   `model_family`/`window_declared`; zero remaining mentions of `AI_DLC_MODEL_ROW` or
   `row_known` in that file.
4. Every file in the reader floor is either updated or the classify-list records why not,
   and the close-out grep in action 5 is clean.
5. `AI_DLC_FIXTURE_NO_SKIP=1 bash .githooks/pre-push` is green, read by its own exit.
6. The graph migration brief exists as a deliverable (text or a committed scratch file this
   plan points to) — its APPLICATION is explicitly out of scope, per action 6.

## Hazards

- **The Bash tool's shell is zsh.** No `PIPESTATUS`; force `bash -c` for any loop or heredoc
  touching this fixture.
- **`bash` is 3.2** in the fixture's execution context — no `declare -A`, no `mapfile`.
- **A zero is not a finding.** Every "no more mentions of X" claim in this plan carries a
  control that must return non-zero in the same invocation.
- **Do not re-add a cache.** The entire point of this design is that the answer is
  deterministic from settings + the transcript on every fire — a cache reintroduces the
  stale-latch failure this plan exists to remove.

## Graph migration brief — deliverable of action 6, NOT applied

`/Users/n8/git/graph` is READ ONLY to an ai-dlc session (`.claude/rules/consumer-boundary.md`).
This section is the brief the operator carries into a graph session or applies themselves.
It ships safe unapplied: from v0.490.0 the sensor ignores `AI_DLC_MODEL_ROW` and assumes a
200,000-token ceiling for any undeclared family, which fires yellow/red early on a 1M model and
keeps `imminent` off — noisy, never silent.

**What graph carries today** (read from `/Users/n8/git/graph/.claude/settings.json` at
installed version 0.489.0): `env.AI_DLC_MODEL_ROW` is `1M`, and no `AI_DLC_MODEL_*_WINDOW` key
exists. Its `arm-log.jsonl` records the lead ids `claude-opus-4-8`, `claude-opus-5`,
`claude-sonnet-5`, `qwen3.5:35b-a3b-coding-mxfp8`, `qwen3.6:35b-a3b-mxfp8` and `<synthetic>`.
The three Claude ids classify as OPUS / OPUS / SONNET; the qwen ids and `<synthetic>` name no
Claude family and classify as OTHER. graph's statusline is the operator's own
`~/.claude/statusline.sh` (user-scoped), so `window.json` will usually answer first and this
declaration is the fallback for when it does not.

**Change to `.claude/settings.json` `env`** — add five keys, remove one:

```json
"env": {
  "AI_DLC_MODEL_FABLE_WINDOW":  "1000000",
  "AI_DLC_MODEL_OPUS_WINDOW":   "1000000",
  "AI_DLC_MODEL_SONNET_WINDOW": "1000000",
  "AI_DLC_MODEL_HAIKU_WINDOW":  "200000",
  "AI_DLC_MODEL_OTHER_WINDOW":  "256000"
}
```

and delete `"AI_DLC_MODEL_ROW": "1M"`. Every other `env` key stays.

**Provenance of each value.** The four Claude-family values are graph's own current `1M` pin
split per family, with Haiku corrected to its native 200K (Claude Haiku 4.5 is the one current
family that is not 1M) — derivable from this repo and the plan above. **`OTHER: 256000` is NOT
derivable from this repo.** It is the operator's own stated fact about the local qwen3 models
graph runs, given directly in the conversation that produced this plan, not measured from any
file here. If those models or their windows have changed since, ask the operator rather than
assume; a wrong OTHER value in the LARGE direction is the silent failure this release removes.

**How to verify on graph after applying**, from a graph session: fire one turn with an active
pipeline and read `_bmad-output/.context-sensor-state`. It must carry `model_family=` naming the
running family and `window_declared=1`. A `window_declared=0` there means the matched family's
key is absent or unparseable. `scripts/ai-dlc/validate-compact-window.sh` is unaffected by this
change and needs no re-run for it.
