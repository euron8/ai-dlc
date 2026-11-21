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
#                      other tools), then append the template's blocks. Event-key
#                      set is the union of consumer's and template's.
#   2. enabledPlugins— additive only, user wins on conflict, with ONE retirement:
#                      `context-mode@context-mode` set to exactly `true` is removed
#                      (context-mode is installed once at user scope; a project-level
#                      enable makes Claude Code record a per-project install). `false`
#                      and every other entry are untouched. The key is written only
#                      when non-empty, and dropped when the retirement empties it. The
#                      retirement runs only when the template wires hooks, so the
#                      uninstall call (an empty `{}` template) never retires anything.
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
#                      Roles merge whole-role, consumer wins, except that each
#                      template-owned key in SM_ROLE_FILL_KEYS is filled into a
#                      role both sides declare when the consumer entry lacks it;
#                      one `settings-merge: filled <keys> into aiDlcRoles.<role>`
#                      line per filled role goes to stdout (also under --check).
#                      With `--prior-template` (the template at the pull's base), a
#                      key the consumer holds at EXACTLY the prior template's value
#                      (never customized) is replaced by the new template's value,
#                      one `settings-merge: replaced <keys> in aiDlcRoles.<role>` line
#                      per role; any other consumer value is kept.
#   2c. bashOutputMaxChars
#                    — template supplies, consumer wins. The harness cap on
#                      inline Bash output: past it, a result becomes a path plus
#                      a 2,000-character preview. This is Rule 23(c)'s enforcer
#                      (large read-only output must not land in the resident
#                      prefix; measured 155 results over 8 KB summing 2.9 MB
#                      across 40 consumer sessions), and it must REACH an
#                      existing consumer, which "every other key preserved"
#                      cannot do. A consumer value survives every pull; a
#                      template with no value writes nothing.
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
#   settings-merge.sh --consumer <path> --template <path> [--prior-template <path>]
#   settings-merge.sh --consumer <path> --template <path> [--prior-template <path>] --check
#
#   --prior-template  The template as it stood at the pull's base. A template-owned role
#             key whose consumer value equals the prior's value (and differs from the
#             template's) is replaced; without the flag no value is ever replaced.
#             An unreadable or non-object prior exits 1.
#
#   --check   Report what would change and exit 0 WITHOUT writing. Prints one
#             `enabledPlugins:` line when the context-mode retirement will fire. Prints
#             `model_window_needed=yes` when the operator must be asked (no
#             family window declared and the template wires the sensor). Use
#             this to build the step-5 dry-run report.
#
# EXIT
#   0  merged (or, with --check, reported)
#   1  bad arguments, unreadable inputs, or the merge produced invalid JSON

sm_main() {
set -u

CONSUMER=""
TEMPLATE=""
PRIOR=""
CHECK=0

while [ $# -gt 0 ]; do
  case "$1" in
    --consumer)  CONSUMER="$2"; shift 2 ;;
    --template)  TEMPLATE="$2"; shift 2 ;;
    --prior-template) PRIOR="$2"; shift 2 ;;
    --check)     CHECK=1; shift ;;
    *) echo "unknown argument: $1" >&2; exit 1 ;;
  esac
done

[ -n "$CONSUMER" ] && [ -n "$TEMPLATE" ] || {
  echo "usage: settings-merge.sh --consumer <path> --template <path> [--prior-template <path>] [--check]" >&2
  exit 1
}
command -v jq >/dev/null 2>&1 || { echo "FAIL: jq is required" >&2; exit 1; }
[ -r "$TEMPLATE" ] || { echo "FAIL: cannot read template: $TEMPLATE" >&2; exit 1; }
# The prior template is validated like the template: an error is never read as "no prior".
if [ -n "$PRIOR" ]; then
  [ -r "$PRIOR" ] && jq -e 'type == "object"' "$PRIOR" >/dev/null 2>&1 || {
    echo "FAIL: the prior template is unreadable or not a JSON object: $PRIOR" >&2; exit 1; }
  PRIOR_ARGS=(--slurpfile pri "$PRIOR")
else
  PRIOR_ARGS=(--argjson pri '[{}]')
fi

# A consumer with no settings.json is a fresh target: the template IS the base,
# exactly as `install.sh` does with `cp`. Starting from `{}` instead would drop
# every non-hook template key (env.ENABLE_PROMPT_CACHING_1H, enabledPlugins, ...).
# The merge below is idempotent against the template, so this stays correct.
if [ ! -r "$CONSUMER" ]; then
  BASE_JSON="$(cat "$TEMPLATE")"
else
  BASE_JSON="$(cat "$CONSUMER")"
fi
# Validated through a PIPE, not a here-string. bash 3.2 stages every `<<<` to a temp file, and when
# that write fails -- `ulimit -f`, a full TMPDIR -- jq reads EMPTY stdin, `jq -e .` exits non-zero,
# and a valid settings.json was refused as "not valid JSON". The run already refused, so no file was
# written; the defect was the message, which sends the operator to repair a file that is fine. jq
# reads to EOF, so nothing exits early on the pipe, and `printf '%s\n'` restores the newline the
# here-string appended. Every other read of BASE_JSON below is already a pipe.
printf '%s\n' "$BASE_JSON" | jq -e . >/dev/null 2>&1 || { echo "FAIL: consumer settings.json is not valid JSON; left untouched" >&2; exit 1; }

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

# The context-mode enable is retired only on a merge against a real template (one that wires
# hooks). uninstall.sh merges against an empty `{}` template to strip ai-dlc blocks, and a
# `true` the consumer held before install must survive that.
RETIRE_CM=false
if printf '%s' "$BASE_JSON" | jq -e --slurpfile tmpl "$TEMPLATE" '
     (($tmpl[0].hooks // {}) | type == "object" and length > 0)
     and (.enabledPlugins | type == "object") and (.enabledPlugins["context-mode@context-mode"] == true)
   ' >/dev/null 2>&1; then
  RETIRE_CM=true
fi
# Template-owned role keys: filled into a consumer role entry that exists on BOTH sides and LACKS
# the key. A consumer that declares the key keeps its value, unless it equals the prior template's
# value (--prior-template): that value was never customized and is replaced by the template's. A role absent from the consumer is not created here (the role-level merge below adds it).
SM_ROLE_FILL_KEYS='["omitClaudeMd","disallowedTools"]'
# One jq answers both the hook-retirement flag and the role fills, so the fill adds no exec.
# Line 1 is `<retire flag><TAB><fills JSON>`; every further line is one report row.
SM_NL='
'
SM_TAB=$'\t'
SM_FR="$(printf '%s' "$BASE_JSON" | jq -r --argjson keys "$SM_ROLE_FILL_KEYS" "${PRIOR_ARGS[@]}" --slurpfile tmpl "$TEMPLATE" '
    (try (($tmpl[0].hooks // {}) | type == "object" and length > 0) catch false) as $flag
    | ($tmpl[0].aiDlcRoles // {}) as $tr | (.aiDlcRoles // {}) as $ur
    | (if ($tr | type) == "object" and ($ur | type) == "object" then
        [ $ur | keys[] as $r
          | select(($tr[$r] | type) == "object" and ($ur[$r] | type) == "object")
          | { role: $r,
              keys: [ $keys[] as $k | select(($tr[$r] | has($k)) and (($ur[$r] | has($k)) | not)) | $k ] }
          | select(.keys | length > 0) ]
      else [] end) as $fills
    | ($pri[0].aiDlcRoles // {}) as $pr
    | (if ($tr | type) == "object" and ($ur | type) == "object" and ($pr | type) == "object" then
        [ $ur | keys[] as $r
          | select(($tr[$r] | type) == "object" and ($ur[$r] | type) == "object" and ($pr[$r] | type) == "object")
          | { role: $r,
              keys: [ $keys[] as $k
                      | select(($pr[$r] | has($k)) and ($tr[$r] | has($k)) and ($ur[$r] | has($k))
                               and $ur[$r][$k] == $pr[$r][$k] and $tr[$r][$k] != $pr[$r][$k]) | $k ] }
          | select(.keys | length > 0) ]
      else [] end) as $reps
    | "\($flag)\t\($fills + $reps | tojson)",
      ($fills[] | "settings-merge: filled \(.keys | join(",")) into aiDlcRoles.\(.role)"),
      ($reps[] | "settings-merge: replaced \(.keys | join(",")) in aiDlcRoles.\(.role) (the file held the prior template value)")
  ' 2>/dev/null)" || {
  echo "FAIL: the role-key fill could not be evaluated; consumer left untouched" >&2; exit 1; }
SM_FR_HEAD="${SM_FR%%"$SM_NL"*}"
case "$SM_FR" in *"$SM_NL"*) ROLE_FILL_ROWS="${SM_FR#*"$SM_NL"}" ;; *) ROLE_FILL_ROWS="" ;; esac
RETIRE_FLAG="${SM_FR_HEAD%%"$SM_TAB"*}"
ROLE_FILLS="${SM_FR_HEAD#*"$SM_TAB"}"
case "$RETIRE_FLAG" in
  true|false) ;;
  *) echo "FAIL: the role-key fill produced no verdict; consumer left untouched" >&2; exit 1 ;;
esac
sm_report_fills() {
  [ -n "$ROLE_FILL_ROWS" ] && printf '%s\n' "$ROLE_FILL_ROWS"
  return 0
}

if [ "$CHECK" -eq 1 ]; then
  sm_report_fills
  if [ "$RETIRE_CM" = true ]; then
    echo "enabledPlugins: this project's context-mode enable is retired (context-mode is installed once at user scope); every user of this project needs it: claude plugin install context-mode@context-mode --scope user"
  fi
  echo "sensor_wired=${SENSOR_WIRED}"
  echo "declared_model_windows=${DECLARED_FAMILIES:-<none>}"
  echo "model_window_needed=${MODEL_WINDOW_NEEDED}"
  if printf '%s' "$BASE_JSON" | jq -e '(.env // {}) | type == "object" and has("AI_DLC_SUITE_ADMISSION_PROBE")' >/dev/null 2>&1; then
    echo "suite_admission_probe=declared"
  else
    echo "suite_admission_probe=none"
    echo "optional: AI_DLC_SUITE_ADMISSION_PROBE in .claude/settings.json env names a shell command that exits 0 to admit a suite run and 3 to refuse it;"
    echo "optional:   with it, suite runs wait their turn instead of starving a loaded box. Leaving it unset changes nothing. The reconcile never writes env."
  fi
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

# THE MERGE IS STAGED BESIDE THE TARGET, NEVER IN TMPDIR. A `mktemp` in TMPDIR on another volume
# turns the final `mv` into copy-then-unlink: measured on a full consumer volume, the copy failed
# after the old file was gone, and the run printed "consumer left untouched" over a settings.json
# that no longer existed. Staged in the target's own directory the `mv` is a rename, which either
# happens whole or leaves the old file in place, so every refusal below is true as printed. The
# staging file starts as a `cp -p` of the existing file so the merge keeps its mode (`mktemp`
# creates 0600); a fresh target gets the umask default, as `cp` from install.sh would give it.
OUT=""
trap '[ -n "$OUT" ] && rm -f "$OUT"' EXIT
mkdir -p "$(dirname "$CONSUMER")" 2>/dev/null || true
OUT="$(mktemp "${CONSUMER}.merge.XXXXXX" 2>/dev/null)" || {
  OUT=""; echo "FAIL: could not create a staging file beside $CONSUMER; consumer left untouched" >&2; exit 1; }
if [ -e "$CONSUMER" ]; then
  cp -p "$CONSUMER" "$OUT" 2>/dev/null || {
    echo "FAIL: could not stage a copy of $CONSUMER beside it; consumer left untouched" >&2; exit 1; }
else
  chmod "$(printf '%o' $(( 0666 & ~0$(umask) )))" "$OUT" 2>/dev/null || {
    echo "FAIL: could not set the staging file's mode beside $CONSUMER; nothing was written" >&2; exit 1; }
fi

if ! printf '%s' "$BASE_JSON" | jq \
      --argjson retire "$RETIRE_FLAG" --argjson fills "$ROLE_FILLS" --slurpfile tmpl "$TEMPLATE" '
    . as $u |
    ($tmpl[0]) as $t |

    # Per-block, never per-event. Stripping a whole event key would delete the
    # consumer own SessionStart hooks (context-mode, for one) alongside ours.
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
    | (($t.enabledPlugins // {}) + ($u.enabledPlugins // {})) as $merged
    | ($retire and $merged["context-mode@context-mode"] == true) as $fires
    | ($merged | if $fires then del(.["context-mode@context-mode"]) else . end) as $plugins
    | if ($plugins | length) > 0 then .enabledPlugins = $plugins
      elif $fires then del(.enabledPlugins)
      else . end
    # Guarded so a tree where NEITHER side declares a block is left alone, rather
    # than gaining an empty `{}` that reads like config.
    #
    # aiDlcRoles merges at the ROLE level, not per field: a consumer entry replaces
    # the shipped one whole. Merging per field would let an upstream default for
    # `effort` reappear inside an entry the consumer had deliberately rewritten, and
    # the model and effort of a role are one decision. The one exception is $fills:
    # the template-owned keys (SM_ROLE_FILL_KEYS) a consumer entry lacks, or holds at the prior
    # template value (both arrive in $fills).
    | ((($t.aiDlcModels // {}) + ($u.aiDlcModels // {}))) as $models
    | ((($t.aiDlcRoles  // {}) + ($u.aiDlcRoles  // {}))
       | reduce $fills[] as $f (.; reduce $f.keys[] as $k (.; .[$f.role][$k] = $t.aiDlcRoles[$f.role][$k]))) as $roles
    | if ($models | length) > 0 then .aiDlcModels = $models else . end
    | if ($roles  | length) > 0 then .aiDlcRoles  = $roles  else . end
    # bashOutputMaxChars is a scalar, so "additive, user wins" is `//`. Guarded the
    # same way: neither side declaring it leaves the key absent.
    | ($u.bashOutputMaxChars // $t.bashOutputMaxChars) as $bash_cap
    | if $bash_cap != null then .bashOutputMaxChars = $bash_cap else . end
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

# The move's status is read: an unchecked `mv` that failed printed "settings.json reconciled" below
# over a consumer file nothing had written. It is a same-directory rename (see the staging above).
mv "$OUT" "$CONSUMER" || { echo "FAIL: could not move the merged settings into place at $CONSUMER; consumer left untouched" >&2; exit 1; }
trap - EXIT

echo "settings.json reconciled (ai-dlc hooks upserted; user config preserved)"
sm_report_fills
if [ -n "$DECLARED_FAMILIES" ]; then
  echo "  env model windows declared for: ${DECLARED_FAMILIES} (consumer-owned, untouched)"
elif [ "$MODEL_WINDOW_NEEDED" = yes ]; then
  echo "  no env.AI_DLC_MODEL_<FAMILY>_WINDOW declared; the sensor assumes a 200,000-token ceiling until one is (see --check)"
fi
}
[ "${BASH_SOURCE[0]}" = "$0" ] || return 0
sm_main "$@"
