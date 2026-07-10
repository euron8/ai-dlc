#!/usr/bin/env bash
# settings-merge.sh — the settings.json reconcile, as a script rather than prose.
#
# WHY THIS IS A SCRIPT
# `.claude/settings.json` is the one reconcile target with an exact, mechanical
# contract (strip ai-dlc hook blocks, re-append the template's, preserve every
# user key). Prose that an agent retypes as jq drifts; this does not. It is the
# same contract `scripts/install.sh` applies on install, so a consumer that
# reconciles and a consumer that reinstalls converge on the same file.
#
# WHAT IT DOES
#   1. hooks         — strip every block whose inner command matches
#                      /\.claude/hooks/ai-dlc-[^/]+\.sh (per-block, NEVER
#                      per-event: SessionStart is shared with context-mode and
#                      caveman), then append the template's blocks. Event-key
#                      set is the union of consumer's and template's.
#   2. enabledPlugins— additive only, user wins on conflict. Never removed.
#   3. env.AI_DLC_MODEL_ROW
#                    — PROVISION ONLY. Written when the key is absent AND the
#                      template wires ai-dlc-context-sensor.sh AND a row was
#                      supplied. Never overwrites an existing value. `auto`
#                      writes nothing (an absent key is the inference path).
#   4. every other key (permissions, env.*, mcpServers, statusLine, …)
#                    — preserved untouched.
#
# WHY NO DEFAULT MODEL ROW
# The sensor cannot read the context-window size off the transcript (Claude Code
# records `claude-opus-4-8` for both the 200K and 1M variant). Pinning `200K`
# sets row_known=1 and disables the sensor's self-correction, so a 1M project
# fires early reminders forever. Pinning `1M` on a 200K model puts red (200,000)
# above that model's compact threshold (187,000), so red never fires before
# compaction — the failure the ordering invariant exists to prevent. An absent
# key is the only safe default, which is why the operator is asked and `auto`
# writes nothing.
#
# USAGE
#   settings-merge.sh --consumer <path> --template <path> [--model-row 1M|200K|auto]
#   settings-merge.sh --consumer <path> --template <path> --check
#
#   --check   Report what would change and exit 0 WITHOUT writing. Prints
#             `model_row_needed=yes` when the operator must be asked (key absent
#             and the template wires the sensor). Use this to build the step-5
#             dry-run report.
#
# EXIT
#   0  merged (or, with --check, reported)
#   1  bad arguments, unreadable inputs, or the merge produced invalid JSON

set -u

CONSUMER=""
TEMPLATE=""
MODEL_ROW=""
CHECK=0

while [ $# -gt 0 ]; do
  case "$1" in
    --consumer)  CONSUMER="$2"; shift 2 ;;
    --template)  TEMPLATE="$2"; shift 2 ;;
    --model-row) MODEL_ROW="$2"; shift 2 ;;
    --check)     CHECK=1; shift ;;
    *) echo "unknown argument: $1" >&2; exit 1 ;;
  esac
done

[ -n "$CONSUMER" ] && [ -n "$TEMPLATE" ] || {
  echo "usage: settings-merge.sh --consumer <path> --template <path> [--model-row 1M|200K|auto] [--check]" >&2
  exit 1
}
command -v jq >/dev/null 2>&1 || { echo "FAIL: jq is required" >&2; exit 1; }
[ -r "$TEMPLATE" ] || { echo "FAIL: cannot read template: $TEMPLATE" >&2; exit 1; }

case "$MODEL_ROW" in
  ""|auto|200K|1M) ;;
  *) echo "FAIL: --model-row must be 200K, 1M, or auto (got '$MODEL_ROW')" >&2; exit 1 ;;
esac

# A consumer with no settings.json is a fresh target: the template IS the base,
# exactly as `install.sh` does with `cp`. Starting from `{}` instead would drop
# every non-hook template key (env.ENABLE_PROMPT_CACHING_1H, enabledPlugins, ...).
# The merge below is idempotent against the template, so this stays correct.
if [ ! -r "$CONSUMER" ]; then
  BASE_JSON="$(cat "$TEMPLATE")"
else
  BASE_JSON="$(cat "$CONSUMER")"
fi
jq -e . >/dev/null 2>&1 <<<"$BASE_JSON" || { echo "FAIL: consumer settings.json is not valid JSON; left untouched" >&2; exit 1; }

# Does the template wire the context sensor? Only then is the row meaningful.
SENSOR_WIRED="$(jq -r '
  [ .hooks // {} | to_entries[] | .value[]? | .hooks[]? | .command // "" ]
  | any(test("ai-dlc-context-sensor\\.sh"))
' "$TEMPLATE" 2>/dev/null || echo false)"

EXISTING_ROW="$(printf '%s' "$BASE_JSON" | jq -r '.env.AI_DLC_MODEL_ROW // empty' 2>/dev/null || true)"

MODEL_ROW_NEEDED=no
if [ "$SENSOR_WIRED" = "true" ] && [ -z "$EXISTING_ROW" ]; then
  MODEL_ROW_NEEDED=yes
fi

if [ "$CHECK" -eq 1 ]; then
  echo "sensor_wired=${SENSOR_WIRED}"
  echo "existing_model_row=${EXISTING_ROW:-<unset>}"
  echo "model_row_needed=${MODEL_ROW_NEEDED}"
  if [ "$MODEL_ROW_NEEDED" = yes ]; then
    echo "ask: This project's context sensor needs the model's context window."
    echo "ask:   1M   -> reminders at yellow 120K / red 200K"
    echo "ask:   200K -> reminders at yellow 80K / red 120K"
    echo "ask:   auto -> leave unset; sensor assumes 200K and self-corrects"
    echo "ask: default is auto (writes nothing)"
  fi
  exit 0
fi

# The row is written only when it is genuinely absent. An operator answering a
# question the reconcile already answered must never clobber a pinned value.
WRITE_ROW=""
if [ "$MODEL_ROW_NEEDED" = yes ] && [ -n "$MODEL_ROW" ] && [ "$MODEL_ROW" != auto ]; then
  WRITE_ROW="$MODEL_ROW"
fi

OUT="$(mktemp)"
trap 'rm -f "$OUT"' EXIT

if ! printf '%s' "$BASE_JSON" | jq \
      --slurpfile tmpl "$TEMPLATE" \
      --arg row "$WRITE_ROW" '
    . as $u |
    ($tmpl[0]) as $t |

    # Per-block, never per-event. Stripping a whole event key would delete the
    # consumer own SessionStart hooks (context-mode, caveman) alongside ours.
    def is_ai_dlc_block:
      (.hooks // [])
      | any(
          (.command // "") as $c |
          ($c | test("/\\.claude/hooks/ai-dlc-[^/]+\\.sh")) or
          ($c | test("RULE 3 CONTINUATION MANDATE"))
        );

    def strip_ai_dlc: map(select(is_ai_dlc_block | not));

    ($u.hooks // {}) as $uh |
    ($t.hooks // {}) as $th |
    (($uh | keys) + ($th | keys) | unique) as $events |

    $u
    | .enabledPlugins = (($t.enabledPlugins // {}) + ($u.enabledPlugins // {}))
    | .hooks = (
        $events
        | map(. as $e | (($uh[$e] // []) | strip_ai_dlc) + ($th[$e] // []) | {($e): .})
        | add
      )
    | if $row != "" then .env = ((.env // {}) + {AI_DLC_MODEL_ROW: $row}) else . end
  ' > "$OUT" 2>/dev/null; then
  echo "FAIL: merge produced no output; consumer left untouched" >&2
  exit 1
fi

jq -e . "$OUT" >/dev/null 2>&1 || { echo "FAIL: merge produced invalid JSON; consumer left untouched" >&2; exit 1; }

mkdir -p "$(dirname "$CONSUMER")" 2>/dev/null || true
mv "$OUT" "$CONSUMER"
trap - EXIT

echo "settings.json reconciled (ai-dlc hooks upserted; user config preserved)"
if [ -n "$WRITE_ROW" ]; then
  echo "  env.AI_DLC_MODEL_ROW provisioned as '${WRITE_ROW}'"
elif [ -n "$EXISTING_ROW" ]; then
  echo "  env.AI_DLC_MODEL_ROW left as '${EXISTING_ROW}' (consumer-owned)"
elif [ "$MODEL_ROW_NEEDED" = yes ]; then
  echo "  env.AI_DLC_MODEL_ROW left unset (auto); the sensor will infer the row"
fi
