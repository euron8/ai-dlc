#!/usr/bin/env bash
# whole-read-pool — assert the planning-artifact budget is derived from its reader,
# and that the reader's window is RESOLVED rather than inherited.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the check regressed, 2 = fixture broken.
#
# WHAT THIS REPLACED.
#
# Four per-file constants (prd 60000, product-brief 60000, carry-over-backlog
# 40000, architecture 60000) with no derivation: no ADR, no measurement, no named
# reader, and a per-artifact env override. A physical limit does not ship with an
# override flag. The gate they backed is a HARD_BLOCK at sprint start over
# artifacts holding LOCKED requirements (Rule 13) that no rule retires, so growth
# is monotonic and the gate was eventually unpassable -- with "relocate locked
# requirements" as its standing remedy. The reference consumer ran that relocation
# at S242, S247 and S274; it grew back every time.
#
# Exactly one agent whole-reads the four: the Rule-24 analyst at
# carry-over-evaluation.md section 1 (Rule 25(b)). So the binding quantity is the
# SUM against ONE window, and the pool is that window's 33%.
#
# THE PART THAT IS CORE'S AND NOT THE CONSUMER'S.
#
# The consumer that derived this wrote the window in as a literal 1,000,000, with
# a comment telling a human "if that model line changes, THIS NUMBER CHANGES.
# Re-derive; do not inherit." Core cannot execute an instruction to a human, and
# the number is not core's to inherit: the model a role runs is a per-project fact
# held in the consumer's `aiDlcRoles`/`aiDlcModels` config. A hardcoded 1,000,000
# would hand a 200K-window analyst a pool 1.65x its entire context -- a fail-open at
# a HARD_BLOCK, on the very gate that exists to stop the analyst blowing its window
# one step later.
#
# Assertions 1-6 are that resolution, and assertion 4 is the one that matters:
# unknown must fall to the SMALLER window, never the larger.
#
# THESE ASSERTIONS USED TO WRITE A ROLE FILE, AND THAT IS WHY THEY STAYED GREEN
# THROUGH A DEAD RESOLVER. `resolve_reader_window()` shipped at v0.124.0 reading
# `^- Personal:` out of team-roles/analyst.md. v0.174.0 deleted that line from every
# role file core ships. This fixture kept RECONSTRUCTING the deleted format with its
# own `printf`, so four assertions went on exercising a resolver against a role-file
# shape core had not shipped for fifty releases, and the reference consumer sat on a
# 5x-understated pool and a 417% breach the whole time. A fixture that builds its own
# input can outlive the world its input came from; the arms below drive the CONFIG
# BLOCK the consumer actually holds, and assertion 6 is the anti-regression that the
# role file is no longer consulted at all.

set -uo pipefail

# HERMETIC: the resolver honours AI_DLC_MODEL_<FAMILY>_WINDOW, AI_DLC_READER_WINDOW_TOKENS
# and AI_DLC_WINDOW_LIB, and a consumer exports its settings env block into the push that
# runs this. Scrub the whole prefix so an ambient declaration cannot answer an arm.
# AI_DLC_PROJECT_ROOT survives: hermetic-run.sh sets it, and its sandbox has no .git or .claude
# marker above core/scripts, so without it the validator cannot resolve a root and exits 2.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do
  [ "$_v" = AI_DLC_PROJECT_ROOT ] || unset "$_v"
done

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"

if [ -n "$ROOT" ] && [ -f "$ROOT/core/scripts/validate-artifact-budget.sh" ]; then
  VALIDATOR="$ROOT/core/scripts/validate-artifact-budget.sh"
elif [ -n "$ROOT" ] && [ -f "$ROOT/scripts/ai-dlc/validate-artifact-budget.sh" ]; then
  VALIDATOR="$ROOT/scripts/ai-dlc/validate-artifact-budget.sh"
else
  echo "FIXTURE ERROR: validate-artifact-budget.sh not found in either layout" >&2
  echo "  looked in: $ROOT/core/scripts/ (distribution), $ROOT/scripts/ (consumer)" >&2
  exit 2
fi

# THE WINDOW LIBRARY, RESOLVED FROM THIS FIXTURE'S ROOT IN BOTH LAYOUTS. The validator runs
# with --root "$WORK", which has no hooks directory, so on a consumer (validator at
# scripts/ai-dlc/, library at .claude/hooks/) its own search would find nothing and every
# arm would silently take the [1m]-or-200000 fallback. Exported, so every run below uses
# the library the consumer actually installed.
if [ -n "$ROOT" ] && [ -f "$ROOT/core/hooks/ai-dlc-window.sh" ]; then
  WINLIB="$ROOT/core/hooks/ai-dlc-window.sh"
elif [ -n "$ROOT" ] && [ -f "$ROOT/.claude/hooks/ai-dlc-window.sh" ]; then
  WINLIB="$ROOT/.claude/hooks/ai-dlc-window.sh"
else
  echo "FIXTURE ERROR: ai-dlc-window.sh not found in either layout" >&2
  echo "  looked in: $ROOT/core/hooks/ (distribution), $ROOT/.claude/hooks/ (consumer)" >&2
  exit 2
fi
export AI_DLC_WINDOW_LIB="$WINLIB"

echo "HERMETIC-CONSUMED core/scripts/validate-artifact-budget.sh"

WORK="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/_bmad-output/planning-artifacts" "$WORK/docs" "$WORK/.claude/team-roles" || exit 2

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }

# The consumer's config block, in the layout install.sh writes. `aiDlcRoles.<role>.model`
# is a KEY into `aiDlcModels`, never a model string -- the same two-hop resolution
# ai-dlc-dispatch-guard.sh performs.
settings() { # settings <role-model-key> <model-string-that-key-maps-to>
  printf '{\n  "aiDlcRoles": { "analyst": { "model": "%s", "effort": "high" } },\n  "aiDlcModels": { "%s": "%s" }\n}\n' \
    "$1" "$1" "$2" > "$WORK/.claude/settings.json"
}

# The role file as core ACTUALLY ships it since v0.174.0: it names the config entry and
# carries no model string of its own. Written so the resolver has a role file present
# and still cannot get a window out of it.
role_file_as_shipped() {
  printf '# Role: Analyst\n\n**Model and effort: set at the start of your session from\n`aiDlcRoles.analyst` in `.claude/settings.json`.**\n' \
    > "$WORK/.claude/team-roles/analyst.md"
}

# Size the four planning artifacts. Arg is total KB, split evenly across them.
artifacts() { # artifacts <kb-each>
  for f in "$WORK/_bmad-output/planning-artifacts/prd.md" \
           "$WORK/_bmad-output/planning-artifacts/product-brief.md" \
           "$WORK/_bmad-output/planning-artifacts/carry-over-backlog.md" \
           "$WORK/docs/architecture.md"; do
    head -c "$(( $1 * 1024 ))" /dev/zero | tr '\0' 'x' > "$f"
  done
}

run() {
  bash "$VALIDATOR" --root "$WORK" >"$WORK/out.txt" 2>&1
  echo "$?"
}
pool_of() { sed -n 's/^whole-read pool     : \([0-9]*\) tok.*/\1/p' "$WORK/out.txt" | head -1; }

echo "whole-read-pool"

artifacts 1

# --- 1. A [1m] analyst resolves to the 1M window -------------------------------
# Reproduces the reference consumer exactly, and this is the arm that was RED before
# the fix: `aiDlcRoles.analyst.model = "sonnet"`, `aiDlcModels.sonnet =
# "claude-sonnet-5[1m]"`, a role file present and carrying no model of its own. Two
# hops, key then string -- a resolver that only reads the key gets `sonnet`, which
# has no `[1m]` in it, and lands on 66000.
role_file_as_shipped
settings 'sonnet' 'claude-sonnet-5[1m]'
run >/dev/null
if [ "$(pool_of)" = "330000" ]; then
  ok "a [1m] analyst resolves to a 330000-tok pool through aiDlcRoles -> aiDlcModels"
else
  bad "a [1m] analyst resolved to '$(pool_of)', expected 330000"
fi

# --- 2. A 200K analyst resolves to the 200K window -----------------------------
# A full id without `[1m]` is the 200K variant; only an EXACT bare alias gets the 1M
# default. Seeded with a haiku id so this arm does not overlap 2e, which owns the
# frontier full-id case.
settings 'haiku' 'claude-haiku-4-5'
run >/dev/null
if [ "$(pool_of)" = "66000" ]; then
  ok "a haiku analyst resolves to a 66000-tok pool"
else
  bad "a haiku analyst resolved to '$(pool_of)', expected 66000"
fi

# --- 2b. A BARE ALIAS IS ITS 1M VARIANT ----------------------------------------
# The template this release ships maps `sonnet` -> `sonnet`. A `[1m]`-substring resolver
# reads that 200000 and turns an in-budget Step 1a pool into a HARD_BLOCK.
settings 'sonnet' 'sonnet'
run >/dev/null
if [ "$(pool_of)" = "330000" ]; then
  ok "a bare 'sonnet' analyst resolves to a 330000-tok pool (bare-alias default)"
else
  bad "a bare 'sonnet' analyst resolved to '$(pool_of)', expected 330000"
fi
if grep -q 'bare alias sonnet default' "$WORK/out.txt"; then
  ok "  and the output names the bare-alias default as the source"
else
  bad "  the output does not name the layer that answered: $(grep '^whole-read pool' "$WORK/out.txt")"
fi
settings 'haiku' 'haiku'
run >/dev/null
if [ "$(pool_of)" = "66000" ]; then
  ok "a bare 'haiku' analyst resolves to 66000 (bare-alias default)"
else
  bad "a bare 'haiku' analyst resolved to '$(pool_of)', expected 66000"
fi

# --- 2e. A FULL ID WITHOUT [1m] IS THE 200K VARIANT ----------------------------
# THE DISCRIMINATING INPUT. The operator ruling covers BARE aliases only. A family-
# substring default read `claude-sonnet-4-5` and a Bedrock profile id as 1M and let a
# 330000 pool through a 200K analyst -- a fail-open at a HARD_BLOCK.
for full in 'claude-sonnet-4-5' 'global.anthropic.claude-sonnet-4-6' \
            'us.anthropic.claude-opus-4-1-v1:0' 'claude-fable-1'; do
  settings 'a' "$full"
  run >/dev/null
  if [ "$(pool_of)" = "66000" ]; then
    ok "a full id '$full' without [1m] resolves to 66000"
  else
    bad "a full id '$full' resolved to '$(pool_of)', expected 66000 -- substring defaulting is back"
  fi
done

# --- 2c. AN UNKNOWN MODEL ID TIGHTENS ------------------------------------------
settings 'local' 'local-qwen3-max'
run >/dev/null
if [ "$(pool_of)" = "66000" ]; then
  ok "an id naming no known family resolves to 66000 (OTHER) -- unknown tightens"
else
  bad "an unknown id resolved to '$(pool_of)' -- unknown opened the gate"
fi

# --- 2d. THE DECLARATION LAYERS ------------------------------------------------
# Process env AI_DLC_MODEL_<FAMILY>_WINDOW, then the settings files' env block. Both are
# seeded on a haiku analyst, whose default (66000) is what each would fall back to.
settings 'haiku' 'claude-haiku-4-5'
AI_DLC_MODEL_HAIKU_WINDOW=1m bash "$VALIDATOR" --root "$WORK" >"$WORK/out.txt" 2>&1
if [ "$(pool_of)" = "330000" ]; then
  ok "process env AI_DLC_MODEL_HAIKU_WINDOW=1m overrides the family default"
else
  bad "process env override gave pool '$(pool_of)', expected 330000"
fi
settings_env() { # settings_env <key> <model> <declared HAIKU window>
  printf '{\n  "env": { "AI_DLC_MODEL_HAIKU_WINDOW": "%s" },\n  "aiDlcRoles": { "analyst": { "model": "%s" } },\n  "aiDlcModels": { "%s": "%s" }\n}\n' \
    "$3" "$1" "$1" "$2" > "$WORK/.claude/settings.json"
}
settings_env 'haiku' 'claude-haiku-4-5' '1000000'
run >/dev/null
if [ "$(pool_of)" = "330000" ]; then
  ok "settings.json .env AI_DLC_MODEL_HAIKU_WINDOW overrides the default with no process env"
else
  bad "settings .env override gave pool '$(pool_of)', expected 330000"
fi
AI_DLC_MODEL_HAIKU_WINDOW=500000 bash "$VALIDATOR" --root "$WORK" >"$WORK/out.txt" 2>&1
if [ "$(pool_of)" = "165000" ]; then
  ok "  and process env outranks the settings .env (500000 -> 165000)"
else
  bad "  process env did not outrank settings .env: pool '$(pool_of)', expected 165000"
fi

# --- 2f. AN IMPLAUSIBLE DECLARATION IS REJECTED, NAMED, AND FALLS THROUGH --------
# `99` would size the pool at 32 tokens; a 20-digit value overflows awk. Either must be
# refused (50000..2000000), and the source must say so rather than read as a default.
settings 'haiku' 'claude-haiku-4-5'
for v in 99 99999999999999999999; do
  AI_DLC_MODEL_HAIKU_WINDOW="$v" bash "$VALIDATOR" --root "$WORK" >"$WORK/out.txt" 2>&1
  if [ "$(pool_of)" = "66000" ] && grep -q "rejected env AI_DLC_MODEL_HAIKU_WINDOW=$v" "$WORK/out.txt"; then
    ok "a declared window of $v is rejected, named in the source, and falls to 66000"
  else
    bad "a declared window of $v gave pool '$(pool_of)' and/or was not named as rejected"
  fi
done
settings_env 'haiku' 'claude-haiku-4-5' '1000000'
AI_DLC_MODEL_HAIKU_WINDOW=99 bash "$VALIDATOR" --root "$WORK" >"$WORK/out.txt" 2>&1
if [ "$(pool_of)" = "330000" ]; then
  ok "  a rejected process env falls through to the valid settings .env (330000)"
else
  bad "  a rejected process env did not fall through to settings .env: pool '$(pool_of)'"
fi

# --- 3. A DANGLING KEY IS CLASSIFIED FROM THE KEY ------------------------------
# `aiDlcRoles.analyst.model` names a key that `aiDlcModels` does not define. The key is
# itself an alias: `opus` dangling is still an opus model and takes the OPUS default, and
# a key naming no family lands in OTHER and tightens. THIS REVERSES AN EARLIER ARM, which
# asserted every dangling key read 66000. That was correct under a `[1m]`-substring policy
# and is wrong under the family policy: Claude Code runs a bare `opus` as the 1M variant.
printf '{\n  "aiDlcRoles": { "analyst": { "model": "opus" } },\n  "aiDlcModels": { "sonnet": "claude-sonnet-5[1m]" }\n}\n' \
  > "$WORK/.claude/settings.json"
run >/dev/null
if [ "$(pool_of)" = "330000" ]; then
  ok "a dangling 'opus' key is classified from the key: OPUS default, 330000"
else
  bad "a dangling 'opus' key resolved to '$(pool_of)', expected 330000"
fi
printf '{\n  "aiDlcRoles": { "analyst": { "model": "mystery" } },\n  "aiDlcModels": { "sonnet": "claude-sonnet-5[1m]" }\n}\n' \
  > "$WORK/.claude/settings.json"
run >/dev/null
if [ "$(pool_of)" = "66000" ]; then
  ok "a dangling key naming no family falls to 66000, not to the 1m sibling in the block"
else
  bad "a dangling unknown key resolved to '$(pool_of)' -- an incoherent config opened the gate"
fi

# --- 4. NO CONFIG AT ALL FALLS TO THE SMALLER WINDOW ---------------------------
# The direction of the unknown case is the whole safety property. Unknown must
# tighten the gate; resolving unknown to 1M is a fail-open at a HARD_BLOCK.
rm -f "$WORK/.claude/settings.json"
run >/dev/null
if [ "$(pool_of)" = "66000" ]; then
  ok "a missing settings.json falls back to 66000 -- unknown tightens, never opens"
else
  bad "a missing settings.json resolved to '$(pool_of)' -- unknown opened the gate"
fi

# --- 4b. NO aiDlcRoles.analyst ENTRY FALLS TO THE SMALLER WINDOW ---------------
# A settings.json that exists and simply says nothing about the analyst. Distinct
# from assertion 4: the file is readable and parses, so a resolver that only guards
# on readability walks past this one.
printf '{\n  "aiDlcModels": { "sonnet": "claude-sonnet-5[1m]" }\n}\n' > "$WORK/.claude/settings.json"
run >/dev/null
if [ "$(pool_of)" = "66000" ]; then
  ok "a settings.json with no aiDlcRoles.analyst falls back to 66000"
else
  bad "a missing analyst entry resolved to '$(pool_of)' -- unknown opened the gate"
fi

# --- 6. THE ROLE FILE IS NOT CONSULTED — THE ANTI-REGRESSION -------------------
# This is the arm that would have caught the original defect from the other side, and
# the one that stops the old grep coming back. A role file carrying the pre-v0.174.0
# `- Personal:` line WITH a [1m] model, against a config saying plainly that the
# analyst runs a non-1m model. The config wins. If this ever reports 330000, something
# is reading a model out of a role file again -- which is the state that reported 66000
# on a 1M consumer for fifty releases, in the other direction.
printf '# Analyst\n\n## Model\n\n- Personal: `/model claude-sonnet-5[1m]`\n' \
  > "$WORK/.claude/team-roles/analyst.md"
settings 'haiku' 'claude-haiku-4-5'
run >/dev/null
if [ "$(pool_of)" = "66000" ]; then
  ok "a role file claiming [1m] does not override the config -- the role file is not a model source"
else
  bad "a role file's model line was honoured ('$(pool_of)') -- the deleted format is being read again"
fi
role_file_as_shipped

# --- 5. The pool actually BINDS ------------------------------------------------
# A budget that cannot fail is not a budget. Controls in both directions, so
# neither verdict is an accident of the fixture's file sizes.
settings 'sonnet' 'claude-sonnet-5[1m]'
artifacts 1
status="$(run)"
if [ "$status" = "0" ] && grep -q '  ok  WHOLE-READ POOL' "$WORK/out.txt"; then
  ok "four small artifacts pass the pool (exit 0)"
else
  bad "four small artifacts did not pass -- exit $status"
fi

artifacts 400   # 4 x 400 KB / 4 = 409,600 tok, past 330000 + 10%
status="$(run)"
if [ "$status" = "1" ] && grep -q '^OVER  WHOLE-READ POOL' "$WORK/out.txt"; then
  ok "four oversized artifacts breach the pool (exit 1)"
else
  bad "four oversized artifacts did not breach -- exit $status"
  grep -E 'POOL' "$WORK/out.txt" | sed 's/^/        /'
fi

# --- 6. NO PER-FILE PLANNING BUDGET SURVIVES -----------------------------------
# The subtraction is the point: four constants became one derived number. A
# leftover per-file row would re-impose an underived limit that the pool's own
# remedy text says is not a remedy, and the two would disagree.
if grep -qE '^(prd|product-brief|carry-over-backlog|architecture)\.md\|' "$VALIDATOR"; then
  bad "a per-file planning budget is still in the BUDGETS table -- the subtraction did not happen"
else
  ok "no per-file planning budget remains in the BUDGETS table"
fi
# And the breach above must be reported as the POOL, not as four files.
if grep -qE '^OVER  _bmad-output/planning-artifacts/prd\.md' "$WORK/out.txt"; then
  bad "prd.md was also reported per-file -- the lead gets two verdicts and the wrong remedy"
else
  ok "  and the breach is reported once, as a sum"
fi

# --- 7. --only pipeline-snapshot.md does NOT drag the pool in ------------------
# Check 14 and the sub-step path only ever ask about the snapshot. Reporting a
# planning-artifact breach there would fail the wrong gate on the wrong artifact
# with a remedy (consolidate) that must never run mid-sprint.
artifacts 400
printf '## Pipeline Position\nx\n' > "$WORK/_bmad-output/pipeline-snapshot.md"
bash "$VALIDATOR" --root "$WORK" --only pipeline-snapshot.md >"$WORK/out.txt" 2>&1
only_status=$?
if [ "$only_status" = "0" ] && ! grep -q 'WHOLE-READ POOL' "$WORK/out.txt"; then
  ok "--only pipeline-snapshot.md ignores the pool entirely"
else
  bad "--only pipeline-snapshot.md exit $only_status and/or reported the pool -- gates would fail on the wrong artifact"
fi

artifacts 1

# --- 8b'. THE LIBRARY ABSENT: THE OLD PATH, NEVER AN EXIT -----------------------
# retired-contract-token copies this validator ALONE, so an unreadable library must not
# be a refusal. A lone copy in $WORK finds no library: a `[1m]` id still reads 1M, a bare
# alias reads 200000 (the pre-library behaviour), and the source says it fell back.
LONE="$WORK/lone"; mkdir -p "$LONE" || exit 2
cp "$VALIDATOR" "$LONE/validate-artifact-budget.sh" || exit 2
settings 'sonnet' 'claude-sonnet-5[1m]'
env -u AI_DLC_WINDOW_LIB bash "$LONE/validate-artifact-budget.sh" --root "$WORK" >"$WORK/out.txt" 2>&1
lone_rc=$?
if [ "$lone_rc" = "0" ] && [ "$(pool_of)" = "330000" ] && grep -q 'fallback: ai-dlc-window.sh not found' "$WORK/out.txt"; then
  ok "library absent: a [1m] analyst still reads 330000, exit 0, and the source says fallback"
else
  bad "library absent: exit $lone_rc, pool '$(pool_of)' -- expected 0 / 330000 / a fallback source"
fi
settings 'sonnet' 'sonnet'
env -u AI_DLC_WINDOW_LIB bash "$LONE/validate-artifact-budget.sh" --root "$WORK" >"$WORK/out.txt" 2>&1
if [ "$(pool_of)" = "66000" ]; then
  ok "  and a bare alias reads 66000 there -- the tightening direction"
else
  bad "  library absent, bare alias read '$(pool_of)', expected 66000"
fi

# --- 8c. THE SHARED LIBRARY THROUGH AI_DLC_WINDOW_LIB ----------------------------
settings 'sonnet' 'sonnet'
AI_DLC_WINDOW_LIB="$WINLIB" bash "$VALIDATOR" --root "$WORK" >"$WORK/out.txt" 2>&1
if [ "$(pool_of)" = "330000" ] && grep -q 'bare alias sonnet default' "$WORK/out.txt"; then
  ok "  the shared library through AI_DLC_WINDOW_LIB reads 330000 from the bare-alias default"
else
  bad "  the shared library through AI_DLC_WINDOW_LIB read '$(pool_of)'"
fi

# --- 8d. THE TWO READERS AGREE ---------------------------------------------------
# The context sensor and this validator resolve a model's window through the same
# library. Drive BOTH over one id set and require the same number. The sensor runs in a
# sandbox project with no autoCompactWindow, no runtime window file and no launcher env,
# so its effective_window IS the model window; the validator's is pool * 100 / 33.
if [ -f "$ROOT/core/hooks/ai-dlc-context-sensor.sh" ]; then
  SENSOR="$ROOT/core/hooks/ai-dlc-context-sensor.sh"
elif [ -f "$ROOT/.claude/hooks/ai-dlc-context-sensor.sh" ]; then
  SENSOR="$ROOT/.claude/hooks/ai-dlc-context-sensor.sh"
else
  echo "FIXTURE ERROR: ai-dlc-context-sensor.sh not found in either layout" >&2
  exit 2
fi
SP="$WORK/sensor-proj"
mkdir -p "$SP/_bmad-output" "$SP/.claude" "$WORK/sensor-home" || exit 2
: > "$SP/_bmad-output/pipeline-snapshot.md"
sensor_window() { # sensor_window <model id> -> the sensor's effective_window
  rm -f "$SP/_bmad-output/.context-sensor-state"
  printf '{"type":"assistant","isSidechain":false,"message":{"model":"%s","usage":{"input_tokens":2,"cache_creation_input_tokens":0,"cache_read_input_tokens":1000}}}\n' \
    "$1" > "$WORK/sensor-t.jsonl"
  printf '{"transcript_path":"%s","session_id":"t"}' "$WORK/sensor-t.jsonl" \
    | env -u CLAUDE_CODE_AUTO_COMPACT_WINDOW CLAUDE_PROJECT_DIR="$SP" CLAUDE_CONFIG_DIR="$WORK/sensor-home" \
        AI_DLC_WINDOW_FILE="$WORK/no-window.json" bash "$SENSOR" >/dev/null 2>&1
  sed -n 's/^effective_window=//p' "$SP/_bmad-output/.context-sensor-state" 2>/dev/null | head -1
}
validator_window() { # validator_window <validator> <model id>
  settings 'm' "$2"
  bash "$1" --root "$WORK" >"$WORK/out.txt" 2>&1
  p="$(pool_of)"
  [ -n "$p" ] && printf '%s' "$(( p * 100 / 33 ))"
}
AGREE_IDS="sonnet opus fable haiku claude-sonnet-5[1m] local-qwen3-max claude-opus-4-8 claude-sonnet-4-5 global.anthropic.claude-sonnet-4-6"
agree() { # agree <validator> -> number of ids on which the two readers differ
  n=0
  for id in $AGREE_IDS; do
    s="$(sensor_window "$id")"; v="$(validator_window "$1" "$id")"
    if [ -z "$s" ] || [ "$s" != "$v" ]; then n=$((n+1)); printf '        %s: sensor %s, validator %s\n' "$id" "${s:-<none>}" "${v:-<none>}" >&2; fi
  done
  printf '%s' "$n"
}
# Positive conjunct: the sensor actually ran and produced a number.
if [ "$(sensor_window sonnet)" = "1000000" ] && [ "$(sensor_window haiku)" = "200000" ]; then
  ok "  control: the sensor ran in the sandbox (sonnet 1000000, haiku 200000)"
else
  bad "  control: the sensor produced no window in the sandbox -- 8d would compare nothing"
fi
diffs="$(agree "$VALIDATOR" 2>"$WORK/agree.err")"
if [ "$diffs" = "0" ]; then
  ok "the context sensor and this validator return the same window for every id in the set"
else
  bad "the two readers disagree on $diffs id(s)"; sed 's/^/  /' "$WORK/agree.err"
fi

# --- 8b. THE ROLE-FILE GREP IS GONE, ASSERTED ON THE SOURCE --------------------
# Assertion 6 catches the behaviour; this catches the code, and the two fail for
# different reasons. `^- Personal:` has not existed in a shipped role file since
# v0.174.0, so a resolver that greps for it cannot fire -- and a check that cannot
# fire reads exactly like one that passed.
if grep -q "'\^- Personal:'" "$VALIDATOR"; then
  bad "the validator still greps '^- Personal:' -- a line format deleted at v0.174.0"
else
  ok "no '^- Personal:' grep remains in the validator"
fi
# Control on that absence: the string the resolver DOES read must be present, or the
# grep above proves only that greps run.
if grep -q 'aiDlcRoles.analyst.model' "$VALIDATOR"; then
  ok "  control: the validator reads aiDlcRoles.analyst.model, so the absence above is real"
else
  bad "  control failed: the validator reads neither the old line nor the config block"
fi

# --- 9. The env override still works, and says so ------------------------------
# The escape hatch survives, but it must be visible: a pool the operator raised is
# a different claim from a pool the reader derived, and the output must not
# conflate them.
settings 'sonnet' 'claude-sonnet-5'
artifacts 1
AI_DLC_READER_WINDOW_TOKENS=600000 bash "$VALIDATOR" --root "$WORK" >"$WORK/out.txt" 2>&1
if [ "$(pool_of)" = "198000" ] && grep -q 'AI_DLC_READER_WINDOW_TOKENS' "$WORK/out.txt"; then
  ok "the env override applies and names itself as the source"
else
  bad "override gave pool '$(pool_of)' and/or did not name its source"
fi

# --- 10. AN ARCHIVED PER-SPRINT COPY IS NOT A POOL MEMBER ----------------------
# The pool finds its members by BASENAME across two whole trees. That was safe
# until the artifact-path migration renamed every historical `architecture-s251.md`
# to `s251/architecture.md` -- the live basename -- at which point the search began
# summing the archive. Measured on the reference consumer: 30 files summed under a
# label reading "(4 planning artifacts)", 275,812 tok against 117,379 live, and the
# consumer was told to consolidate while sitting at 36% of its pool.
#
# THE DECOY IS THE POINT OF THIS ARM. `s301-close-out/` begins with `s` and three
# digits and is NOT a sprint slot; excluding it would silently drop a live artifact
# from a budget, which fails OPEN on a HARD_BLOCK. The slot is a whole path
# COMPONENT, and the arm asserts both directions in one run.
settings 'sonnet' 'claude-sonnet-5[1m]'
artifacts 1
mkdir -p "$WORK/_bmad-output/planning-artifacts/s251" \
         "$WORK/_bmad-output/planning-artifacts/s271/party-mode-transcripts" \
         "$WORK/_bmad-output/planning-artifacts/s301-close-out" || exit 2
head -c 200000 /dev/zero | tr '\0' 'x' > "$WORK/_bmad-output/planning-artifacts/s251/architecture.md"
head -c 200000 /dev/zero | tr '\0' 'x' > "$WORK/_bmad-output/planning-artifacts/s271/party-mode-transcripts/prd.md"
head -c 200000 /dev/zero | tr '\0' 'x' > "$WORK/_bmad-output/planning-artifacts/s301-close-out/prd.md"
run >/dev/null
pool_rows() { awk '/^whole-read pool/{i=1;next} i&&/^$/{exit} i' "$WORK/out.txt"; }

if ! grep -qE 's251/architecture\.md|s271/party-mode-transcripts/prd\.md' <<<"$(pool_rows)"; then
  ok "an archived s<N>/ copy is excluded from the pool"
else
  bad "an archived s<N>/ copy was summed into the pool -- the migration's basenames are being counted"
  sed 's/^/        /' <<<"$(pool_rows)"
fi
# The decoy control. Without it the arm above passes for a checker that excludes
# anything starting with `s` and a digit.
if grep -q 's301-close-out/prd\.md' <<<"$(pool_rows)"; then
  ok '  and s301-close-out/ is NOT read as a slot -- a live artifact is still summed'
else
  bad "  a non-slot directory beginning s<digits> was excluded -- the budget fails OPEN"
fi
# The label is derived from the same rows it sums. 5 = the four + the decoy.
if grep -qE 'WHOLE-READ POOL \(5 planning artifacts\)' "$WORK/out.txt"; then
  ok "  and the label counts the rows it summed, not a literal"
else
  bad "  the label disagrees with the row set: $(grep -oE 'WHOLE-READ POOL \([^)]*\)' "$WORK/out.txt" | head -1)"
fi

# --- 10b. THE LIVE SPRINT'S SLOT IS POOLED; EVERY OTHER SPRINT'S IS NOT --------
# Assertion 10 exists because a slot copy of a DURABLE basename is that sprint's
# archive. The LOCKED_REQUIREMENTS block is the opposite case: discovery.md §4a
# writes it to `s<N>/locked-requirements.md` and the analyst reads the CURRENT
# sprint's block whole, every sprint. Without this arm the move that put it there
# would have graded itself -- 54% of the reference consumer's brief leaving the
# pooled sum with the same bytes still read.
#
# BOTH DIRECTIONS IN ONE RUN, because either alone is satisfied by a wrong rule: a
# glob over `s*/` pools every sprint that ever ran, and no arm at all pools none.
# BOTH canonical copies, because sprint-id reads both and HARD_BLOCKs when they
# disagree -- seeding one leaves the other absent, which resolves to greenfield and
# would make 10b pass or fail for a reason unrelated to the arm.
sprint_status() { # sprint_status <n>
  mkdir -p "$WORK/_bmad-output/implementation-artifacts" \
           "$WORK/_bmad-output/planning-artifacts" || exit 2
  for v in implementation-artifacts planning-artifacts; do
    printf 'sprint: %s\nstatus: in_progress\nstories:\n' "$1" \
      > "$WORK/_bmad-output/$v/sprint-status.yaml"
  done
}
sprint_status_clear() {
  rm -f "$WORK/_bmad-output/implementation-artifacts/sprint-status.yaml" \
        "$WORK/_bmad-output/planning-artifacts/sprint-status.yaml"
}
settings 'sonnet' 'claude-sonnet-5[1m]'
artifacts 1
sprint_status 302
mkdir -p "$WORK/_bmad-output/planning-artifacts/s302" \
         "$WORK/_bmad-output/planning-artifacts/s288" || exit 2
head -c 120000 /dev/zero | tr '\0' 'x' > "$WORK/_bmad-output/planning-artifacts/s302/locked-requirements.md"
head -c 120000 /dev/zero | tr '\0' 'x' > "$WORK/_bmad-output/planning-artifacts/s288/locked-requirements.md"
run >/dev/null
if grep -q 's302/locked-requirements\.md' <<<"$(pool_rows)"; then
  ok "the LIVE sprint's locked-requirements.md is pooled"
else
  bad "the live sprint's locked-requirements.md was NOT pooled -- the move would grade itself"
  sed 's/^/        /' <<<"$(pool_rows)"
fi
if ! grep -q 's288/locked-requirements\.md' <<<"$(pool_rows)"; then
  ok "  and an EARLIER sprint's copy is not -- the arm resolves sprint_id, it does not glob s*/"
else
  bad "  a closed sprint's locked-requirements.md was summed -- this is a glob, not a resolution"
fi

# --- 10c. AN UNRESOLVED LIVE SPRINT SAYS SO RATHER THAN CONTRIBUTING ZERO ------
# The whole reason 10b exists is that a pool row can go quiet for a reason unrelated
# to size. A resolver that fails and prints nothing recreates that defect one level
# down, so the absence has to announce itself.
sprint_status_clear
mv "$WORK/_bmad-output/planning-artifacts/s302" "$WORK/_bmad-output/planning-artifacts/s1" || exit 2
run >/dev/null
if grep -q 's1/locked-requirements\.md' <<<"$(pool_rows)"; then
  ok "  greenfield resolves to sprint 1 and pools its slot rather than falling silent"
else
  bad "  a greenfield tree pooled nothing from the sprint arm and said nothing about it"
  sed 's/^/        /' <<<"$(pool_rows)"
fi
mv "$WORK/_bmad-output/planning-artifacts/s1" "$WORK/_bmad-output/planning-artifacts/s302" || exit 2
sprint_status 302
rm -f "$WORK/_bmad-output/planning-artifacts/s288/locked-requirements.md"

# --- 10d. A staged copy of the validator pools the live sprint slot ------------
#
# THE COPY NEEDS A SIBLING. The arm resolves the live sprint through
# `$AI_DLC_SELF_DIR/sprint-status.sh`, so a lone copy in a scratch directory would
# find no resolver and contribute nothing.
# The control is therefore staged in a scratch BIN directory
# holding a copy of sprint-status.sh -- outside the repo tree, so a crashed run
# cannot leave a stray script where the core-script-boundary checks would read it.
# AND THE SIBLING HAS A SIBLING OF ITS OWN. sprint-status.sh loads
# sprint-status.json and refuses to guess without it, so a BIN holding only the two
# scripts makes the resolver exit 1 and the control pools nothing.
#
# THE SCHEMA IS RESOLVED FROM $ROOT, IN BOTH LAYOUTS, AND NEVER BY WALKING UP FROM
# $VALIDATOR. This arm shipped at v0.322.0 resolving the schema as the validator's
# dirname plus a parent hop into a schemas sibling -- written out here in words rather
# than as the expression, because I33 scans this file and would flag the example.
# That parent-sharing is true only in the distribution: install.sh SPLITS it, sending
# core/scripts/<x> to scripts/ai-dlc/<x> and core/schemas/ to .claude/schemas/. So the
# arm was green here and exited 2 on every consumer -- the item-20 class, and a
# permanent stop on the consumer's own pre-push, which is how the reference consumer
# found it (PC-S326). The chain is rooted at the FIXTURE's own self-location and names
# both layouts explicitly, which is what lines 53-56 above already do for the validator
# and what sprint-status.sh:129-153 does for this same schema.
BIN="$WORK/bin"
mkdir -p "$BIN" "$WORK/schemas" || exit 2
SCRIPTS_DIR="$(dirname "$VALIDATOR")"
SPRINT_STATUS="$SCRIPTS_DIR/sprint-status.sh"
if [ -f "$ROOT/core/schemas/sprint-status.json" ]; then
  SPRINT_SCHEMA="$ROOT/core/schemas/sprint-status.json"
elif [ -f "$ROOT/.claude/schemas/sprint-status.json" ]; then
  SPRINT_SCHEMA="$ROOT/.claude/schemas/sprint-status.json"
else
  echo "FIXTURE ERROR: sprint-status.json not found in either layout" >&2
  echo "  looked in: $ROOT/core/schemas/ (distribution), $ROOT/.claude/schemas/ (consumer)" >&2
  exit 2
fi
[ -f "$SPRINT_STATUS" ] || { echo "FIXTURE ERROR: sprint-status.sh not beside $VALIDATOR" >&2; exit 2; }

cp "$SPRINT_STATUS" "$BIN/sprint-status.sh" || exit 2
cp "$SPRINT_SCHEMA" "$WORK/schemas/sprint-status.json" || exit 2
# A copy staged the same way in the same directory still pools the live slot.
CONTROL3="$BIN/control-budget.sh"
cp "$VALIDATOR" "$CONTROL3" || exit 2
bash "$CONTROL3" --root "$WORK" >"$WORK/out.txt" 2>&1
if grep -q 's302/locked-requirements\.md' <<<"$(pool_rows)"; then
  ok "  control: an unmutated copy staged the same way still pools the live slot"
else
  bad "  the unmutated copy did not pool it"
fi
run >/dev/null

echo ""
report_end whole-read-pool
