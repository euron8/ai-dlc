#!/usr/bin/env bash
# reconcile-region: exempt — an action that rewrites settings, driven by step 5s own numbered steps, not a classifier.
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
#   2b. aiDlcModels / aiDlcRoles
#                    — additive only, user wins on conflict. Same shape as
#                      enabledPlugins, and load-bearing for the same reason in
#                      reverse: the VALUES are consumer config (which model
#                      string this project can reach) and must survive every
#                      pull, while a KEY added upstream — a new capability class
#                      a new role names — must arrive. Additive-with-user-wins
#                      is exactly that contract, and it is why `core/team-roles`
#                      needs no setup-substitution sites at all: there is no
#                      consumer-specific string left in a core file to mask.
#   3. env.AI_DLC_MODEL_<FAMILY>_WINDOW
#                    — NEVER WRITTEN. The context sensor's ceiling is declared
#                      per model family (FABLE, OPUS, SONNET, HAIKU, OTHER) in
#                      the consumer's own `env`; --check reports whether any
#                      family is declared so step 5 can raise the question.
#   4. every other key (permissions, env.*, mcpServers, statusLine, …)
#                    — preserved untouched.
#
# WHY NOTHING IS PROVISIONED
# The sensor cannot read the context-window size off the transcript (Claude Code
# records `claude-opus-4-8` for both the 200K and 1M variant), and it no longer
# infers or caches one: the operator declares a window per model family, and an
# undeclared family is assumed at 200,000 tokens — the direction that fires early
# rather than the one that puts red past compaction. The values are the consumer's
# own facts about the models they run, no single default is right for every
# family, and `env` is consumer-owned, so this script reports and never writes.
#
# USAGE
#   settings-merge.sh --consumer <path> --template <path>
#   settings-merge.sh --consumer <path> --template <path> --check
#
#   --check   Report what would change and exit 0 WITHOUT writing. Prints
#             `model_window_needed=yes` when the operator must be asked (no
#             family window declared and the template wires the sensor). Use
#             this to build the step-5 dry-run report.
#
# EXIT
#   0  merged (or, with --check, reported)
#   1  bad arguments, unreadable inputs, or the merge produced invalid JSON

set -u

CONSUMER=""
TEMPLATE=""
CHECK=0

while [ $# -gt 0 ]; do
  case "$1" in
    --consumer)  CONSUMER="$2"; shift 2 ;;
    --template)  TEMPLATE="$2"; shift 2 ;;
    --check)     CHECK=1; shift ;;
    *) echo "unknown argument: $1" >&2; exit 1 ;;
  esac
done

[ -n "$CONSUMER" ] && [ -n "$TEMPLATE" ] || {
  echo "usage: settings-merge.sh --consumer <path> --template <path> [--check]" >&2
  exit 1
}
command -v jq >/dev/null 2>&1 || { echo "FAIL: jq is required" >&2; exit 1; }
[ -r "$TEMPLATE" ] || { echo "FAIL: cannot read template: $TEMPLATE" >&2; exit 1; }

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

# Does the template wire the context sensor? Only then is a window declaration meaningful.
#
# THE `|| echo false` FALLBACK THIS USED TO CARRY MADE AN ERROR AND A VERDICT THE SAME STRING,
# and every guard written downstream of that conflation is blind by construction. `--check`
# answered `model_window_needed=no` and exited 0 on a template it could not parse; step 5
# raises the declaration question only on `yes`, so a consumer that genuinely needed a
# family window declared was never asked and the run stayed green.
#
# FOUR INPUT CLASSES REACHED THAT SILENT `no`, NOT THE ONE THE REPORT NAMED. Measured against
# one consumer settings.json declaring no family window, same script, same invocation:
# a 0-byte template (jq exits 0 and prints NOTHING, so the fallback never fires and
# SENSOR_WIRED is the empty string), a readable non-JSON template, a bare JSON scalar, and a
# valid JSON object whose `.hooks` is not an object. The last two are valid JSON and are why
# validating the template as JSON is not enough — `.hooks // {} | to_entries[]` still errors.
#
# NARROWING THE INPUT SET IS THE WEAKER CLAIM AND IT WAS MEASURED FAILING. A guard that
# refuses unless SENSOR_WIRED is a literal true|false, placed with the fallback still in
# place, closes ONLY the 0-byte case: the other three take the fallback and arrive spelled
# `false`, which is indistinguishable from a template that genuinely does not wire the sensor.
# So the fallback goes, jq's own exit status is read, and the verdict can only be produced
# from a literal true|false. An unparseable template cannot reach a verdict at all.
#
# The unreadable case is already refused at the `-r` guard above, exit 1; the report's headline
# said "0-byte or unreadable" and that half was never open.
if ! SENSOR_WIRED="$(jq -r '
  [ .hooks // {} | to_entries[] | .value[]? | .hooks[]? | .command // "" ]
  | any(test("ai-dlc-context-sensor\\.sh"))
' "$TEMPLATE" 2>/dev/null)"; then
  echo "FAIL: the sensor predicate could not be evaluated against the template: $TEMPLATE" >&2
  exit 1
fi
case "$SENSOR_WIRED" in
  true|false) ;;
  *) echo "FAIL: the sensor predicate produced no verdict against the template: $TEMPLATE" >&2
     exit 1 ;;
esac

# Which model families already declare a window. `env` is consumer-owned and never written
# here; this decides only whether step 5 must raise the declaration question. A non-object
# `env` declares nothing, which asks the question -- the safe direction -- rather than
# erroring into a verdict.
DECLARED_FAMILIES="$(printf '%s' "$BASE_JSON" | jq -r '
  (.env // {}) | if type == "object" then keys else [] end
  | map(select(test("^AI_DLC_MODEL_(FABLE|OPUS|SONNET|HAIKU|OTHER)_WINDOW$")))
  | join(" ")' 2>/dev/null || true)"

MODEL_WINDOW_NEEDED=no
if [ "$SENSOR_WIRED" = "true" ] && [ -z "$DECLARED_FAMILIES" ]; then
  MODEL_WINDOW_NEEDED=yes
fi

if [ "$CHECK" -eq 1 ]; then
  echo "sensor_wired=${SENSOR_WIRED}"
  echo "declared_model_windows=${DECLARED_FAMILIES:-<none>}"
  echo "model_window_needed=${MODEL_WINDOW_NEEDED}"
  if [ "$MODEL_WINDOW_NEEDED" = yes ]; then
    echo "ask: This project's context sensor has no model window declared."
    echo "ask:   It assumes a 200,000-token ceiling for an undeclared model family:"
    echo "ask:   yellow/red fire early on a larger model and imminent stays off."
    echo "ask:   Declare one window per family you run, in .claude/settings.json env,"
    echo "ask:   e.g. \"AI_DLC_MODEL_OPUS_WINDOW\": \"1m\" -- also FABLE, SONNET, HAIKU"
    echo "ask:   and OTHER (any id naming no Claude family). The reconcile never"
    echo "ask:   writes env; add them yourself. Leaving them unset is safe but noisy."
  fi
  exit 0
fi

OUT="$(mktemp)"
trap 'rm -f "$OUT"' EXIT

if ! printf '%s' "$BASE_JSON" | jq \
      --slurpfile tmpl "$TEMPLATE" '
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
    # Guarded so a tree where NEITHER side declares a block is left alone, rather
    # than gaining an empty `{}` that reads like config.
    #
    # aiDlcRoles merges at the ROLE level, not per field: a consumer entry replaces
    # the shipped one whole. Merging per field would let an upstream default for
    # `effort` reappear inside an entry the consumer had deliberately rewritten, and
    # the model and effort of a role are one decision.
    | ((($t.aiDlcModels // {}) + ($u.aiDlcModels // {}))) as $models
    | ((($t.aiDlcRoles  // {}) + ($u.aiDlcRoles  // {}))) as $roles
    | if ($models | length) > 0 then .aiDlcModels = $models else . end
    | if ($roles  | length) > 0 then .aiDlcRoles  = $roles  else . end
    | .hooks = (
        $events
        | map(. as $e | (($uh[$e] // []) | strip_ai_dlc) + ($th[$e] // []) | {($e): .})
        | add
      )
  ' > "$OUT" 2>/dev/null; then
  echo "FAIL: merge produced no output; consumer left untouched" >&2
  exit 1
fi

jq -e . "$OUT" >/dev/null 2>&1 || { echo "FAIL: merge produced invalid JSON; consumer left untouched" >&2; exit 1; }

mkdir -p "$(dirname "$CONSUMER")" 2>/dev/null || true
mv "$OUT" "$CONSUMER"
trap - EXIT

echo "settings.json reconciled (ai-dlc hooks upserted; user config preserved)"
if [ -n "$DECLARED_FAMILIES" ]; then
  echo "  env model windows declared for: ${DECLARED_FAMILIES} (consumer-owned, untouched)"
elif [ "$MODEL_WINDOW_NEEDED" = yes ]; then
  echo "  no env.AI_DLC_MODEL_<FAMILY>_WINDOW declared; the sensor assumes a 200,000-token ceiling until one is (see --check)"
fi
