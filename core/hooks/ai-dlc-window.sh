# ai-dlc-window.sh -- the ONE resolver for the context window this session is running with.
#
# SOURCED, NEVER EXECUTED. No shebang, no `set`, no top-level work: a library that
# changes shell options changes them for whichever caller sourced it.
#
# WHY THIS EXISTS. Two readers ask the same question -- the Stop hook that ramps
# snapshot frequency, and the validator that reports the auto-compact configuration --
# and their answers must not drift. They previously carried byte-identical copies of
# this logic under a comment asserting the copies were "duplicated deliberately"
# because a hook "cannot source from scripts/". That is not so: a hook installs to
# .claude/hooks/ and can source a SIBLING there, which is how ai-dlc-continue.sh and
# ai-dlc-recover.sh already share ai-dlc-handoff-pending.sh. A library that lives
# beside the hooks resolves in both layouts, and a validator under scripts/ai-dlc/
# reaches it by naming both layouts rather than by walking up from its own package.
#
# THE ENV VAR IS NO LONGER THE TOP OF THE CHAIN. Its primacy mirrored Claude Code's
# own config merge, which is a STATIC merge: a shell launcher exports the variable once
# and it does not change when the model is switched mid-session with `/model`. A
# launcher configured for a 1M-context model leaves the pipeline ramping toward a
# number a 262144-context session never reaches, so the snapshot is stale exactly when
# compaction fires. The statusline writes the live answer to a file on every render;
# that file, when it can be trusted, outranks a value fixed at launch.
#
# THE RUNTIME FILE IS NOT SESSION-SCOPED. Its path is fixed, so concurrent Claude Code
# sessions write the same file and a reader can be handed another session's window.
# That is why the session id is compared and not merely read, and why a caller with no
# session id SKIPS this layer rather than trusting it.
#
# ABSENT IS NOT EMPTY. `current_usage`, `used_percentage` and `target` are null before
# the first API call of a session and again after a compaction until the next one. A
# null target means the producer does not know yet, so the layer is skipped and a lower
# one answers. Coercing it to 0 would report a zero-token window as a measurement.

# ai_dlc_parse_window <raw>
# Accepts Claude Code's own spellings ("auto", "400k", "1m", bare int where 100..1000
# means thousands). Echoes an integer, returns 1 when the value is unparseable.
ai_dlc_parse_window() {
  local raw
  raw="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
  case "$raw" in
    ""|auto) return 1 ;;
    *m) awk -v v="${raw%m}" 'BEGIN{printf "%d", v*1000000}' ;;
    *k) awk -v v="${raw%k}" 'BEGIN{printf "%d", v*1000}' ;;
    *[!0-9]*) return 1 ;;
    *)
      if [ "$raw" -ge 100 ] && [ "$raw" -le 1000 ]; then
        awk -v v="$raw" 'BEGIN{printf "%d", v*1000}'
      else
        printf '%d' "$raw"
      fi
      ;;
  esac
}

# ai_dlc_window_file
# The runtime file the statusline writes. Overridable so a fixture can point at a
# seeded copy -- without that, an arm on this machine reads the operator's live
# session and tests whatever it happens to be doing.
ai_dlc_window_file() {
  printf '%s' "${AI_DLC_WINDOW_FILE:-$HOME/.ai-dlc/window.json}"
}

# ai_dlc_resolve_window <session_id> <settings_local> <settings_project> <settings_user>
#
# Echoes exactly one line: "<window>|<source>|<model_max>".
#   window     the resolved window in tokens, or empty for "unset (model default)"
#   source     the layer that answered, for an operator-facing report
#   model_max  the model's true maximum, ONLY when the runtime layer answered; empty
#              otherwise, meaning the caller keeps whatever row it had inferred
#
# The layers, highest precedence first. The highest layer that DEFINES a value wins; a
# layer that does not set the key does not shadow a lower one; a defining layer whose
# value is unparseable ("auto") resolves to the model default and lower layers are not
# consulted.
ai_dlc_resolve_window() {
  local sid s_local s_project s_user file now maxage rt rt_target rt_window raw val f pair

  sid="${1:-}"
  s_local="${2:-}"
  s_project="${3:-}"
  s_user="${4:-}"

  # --- layer 1: the runtime file the statusline writes ------------------------
  # Taken only when every one of these holds: a session id was supplied, the file is
  # readable, jq parses it, the file's session id is THIS session's, its timestamp is
  # within the freshness bound, and its target is a positive number. Any failure is a
  # skip to the next layer, never an error and never a crash.
  file="$(ai_dlc_window_file)"
  maxage="${AI_DLC_WINDOW_MAX_AGE:-60}"
  case "$maxage" in ''|*[!0-9]*) maxage=60 ;; esac

  if [ -n "$sid" ] && [ -r "$file" ] && command -v jq >/dev/null 2>&1; then
    now="$(date +%s 2>/dev/null || true)"
    case "${now:-}" in ''|*[!0-9]*) now="" ;; esac
    if [ -n "$now" ]; then
      # One jq pass returns "target|window" or nothing at all. `// empty` on a null
      # target yields no output rather than a zero, which is the whole point.
      rt="$(jq -r --arg sid "$sid" --argjson now "$now" --argjson maxage "$maxage" '
        if ((.session_id // "") | tostring) != $sid then empty
        elif ((.ts // null) | type) != "number" then empty
        elif (($now - .ts) > $maxage) or (($now - .ts) < (0 - $maxage)) then empty
        else
          (.target // null) as $t
          | (.window // null) as $w
          | if ($t | type) == "number" and $t > 0
            then "\($t | floor)|\(if ($w | type) == "number" and $w > 0 then ($w | floor) else "" end)"
            else empty
            end
        end' "$file" 2>/dev/null || true)"
      rt="$(printf '%s' "${rt:-}" | head -1)"
      rt_target="${rt%%|*}"
      rt_window="${rt#*|}"
      case "${rt_target:-}" in ''|*[!0-9]*) rt_target="" ;; esac
      case "${rt_window:-}" in ''|*[!0-9]*) rt_window="" ;; esac
      if [ -n "$rt_target" ]; then
        printf '%s|%s|%s' "$rt_target" "window.json (runtime)" "$rt_window"
        return 0
      fi
    fi
  fi

  # --- layer 2: the launcher's environment variable ---------------------------
  if [ -n "${CLAUDE_CODE_AUTO_COMPACT_WINDOW:-}" ]; then
    val=""
    if val="$(ai_dlc_parse_window "$CLAUDE_CODE_AUTO_COMPACT_WINDOW")"; then :; else val=""; fi
    printf '%s|%s|' "$val" "env CLAUDE_CODE_AUTO_COMPACT_WINDOW"
    return 0
  fi

  # --- layer 3: the settings files, in Claude Code's precedence order ----------
  for pair in "settings.local.json:$s_local" "settings.json:$s_project" "user settings:$s_user"; do
    f="${pair#*:}"
    [ -n "$f" ] || continue
    [ -r "$f" ] || continue
    raw="$(jq -r '.autoCompactWindow // empty' "$f" 2>/dev/null || true)"
    [ -n "$raw" ] || continue
    val=""
    if val="$(ai_dlc_parse_window "$raw")"; then :; else val=""; fi
    printf '%s|%s|' "$val" "${pair%%:*}"
    return 0
  done

  # --- layer 4: nothing defined it -------------------------------------------
  printf '|%s|' "unset (model default)"
}

# =============================================================================
# THE MODEL'S OWN WINDOW -- one family policy for every reader.
#
# A second question, distinct from the auto-compact window above: how large is the
# context of the MODEL a role runs? Two readers ask it. The context sensor asks it of the
# lead's transcript model id, to place its bands; validate-artifact-budget.sh asks it of
# the analyst's configured `aiDlcModels` value, to size the Step 1a whole-read pool, which
# is a HARD_BLOCK. They used to answer by two different routes -- the sensor by family
# declaration with a 200000 floor, the validator by a `[1m]` substring with a 200000
# fallback -- and a bare alias (`sonnet`) read 200000 in both, although Claude Code maps
# every bare alias to its 1M-context variant (operator ruling). A shared policy is the
# only way the two cannot drift, so it lives here and both source it.
#
# Precedence, highest first; a layer whose value is unparseable or outside
# AI_DLC_WINDOW_MIN..AI_DLC_WINDOW_MAX does not define it, and the rejection is named in
# the source tag of whichever lower layer answers:
#   1. process env AI_DLC_MODEL_<FAMILY>_WINDOW
#   2. `.env.AI_DLC_MODEL_<FAMILY>_WINDOW` in the settings files passed, in order
#      (settings.local.json before settings.json). The USER settings file is not read
#      here: a user-level declaration reaches a reader only through Claude Code's export
#      of the merged env block into the process, i.e. layer 1.
#   3. a `[1m]` suffix on the id -> 1000000
#   4. an EXACT bare alias (lowercased, `[1m]` stripped): fable, opus, sonnet -> 1000000;
#      haiku -> 200000
#   5. anything else -> 200000
#
# THE ALIAS DEFAULT IS KEYED ON THE WHOLE ID, NEVER ON THE FAMILY SUBSTRING. The operator
# ruling is that Claude Code maps a BARE alias to its 1M variant. A full id without `[1m]`
# -- `claude-sonnet-4-5`, `us.anthropic.claude-opus-4-1-v1:0` -- is the 200K variant, and
# a substring default read it as 1M: the sensor then stayed silent at 190K on a real 200K
# session and the validator let a 330000 pool through a 200K analyst. Family
# classification still uses the substring, because the declaration in layers 1-2 is per
# family; only the DEFAULT is restricted.
#
# Layers 4 and 5 are ASSUMPTIONS (declared=0): the sensor keeps its imminent band gated
# off on them, because an assumption in the large direction is silent.
# =============================================================================

AI_DLC_WINDOW_MIN=50000
AI_DLC_WINDOW_MAX=2000000

# ai_dlc_window_in_range <parsed value> -> 0 when it is a plausible model window.
# A 20-digit declaration parses to a saturated or negative number (awk's %d), so the
# digits-only test plus this range is what refuses it -- measured on four overflow
# spellings; no separate length guard changes any outcome.
ai_dlc_window_in_range() {
  case "${1:-}" in ''|*[!0-9]*) return 1 ;; esac
  [ "$1" -ge "$AI_DLC_WINDOW_MIN" ] 2>/dev/null && [ "$1" -le "$AI_DLC_WINDOW_MAX" ] 2>/dev/null
}

# ai_dlc_model_family <model id or alias>
# FABLE before OPUS: a fable/mythos id must never fall into a later arm.
ai_dlc_model_family() {
  case "$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')" in
    *fable*|*mythos*) printf 'FABLE'  ;;
    *opus*)           printf 'OPUS'   ;;
    *sonnet*)         printf 'SONNET' ;;
    *haiku*)          printf 'HAIKU'  ;;
    *)                printf 'OTHER'  ;;
  esac
}

# ai_dlc_alias_default <model id or alias>
# Echoes "<window>|<source>". Only an EXACT bare alias gets the 1M default; see the
# header for why a family substring must not.
ai_dlc_alias_default() {
  local a
  a="$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')"
  a="${a%\[1m\]}"
  case "$a" in
    fable|opus|sonnet) printf '1000000|bare alias %s default' "$a" ;;
    haiku)             printf '200000|bare alias %s default' "$a" ;;
    *)                 printf '200000|not a bare alias: 200000 default' ;;
  esac
}

# ai_dlc_family_window <FAMILY> [settings files...]
# On success echoes "<window>|<source>" for the highest layer that DECLARES the family's
# window (process env, then each settings file's env block) and returns 0. Otherwise
# echoes "|<rejections>" -- empty when nothing was declared, else a note naming each
# declaration refused as unparseable or out of range -- and returns 1.
ai_dlc_family_window() {
  local fam var val parsed f rej
  fam="${1:-OTHER}"
  case "$fam" in FABLE|OPUS|SONNET|HAIKU) ;; *) fam=OTHER ;; esac
  var="AI_DLC_MODEL_${fam}_WINDOW"
  rej=""
  [ $# -gt 0 ] && shift
  case "$fam" in
    FABLE)  val="${AI_DLC_MODEL_FABLE_WINDOW:-}"  ;;
    OPUS)   val="${AI_DLC_MODEL_OPUS_WINDOW:-}"   ;;
    SONNET) val="${AI_DLC_MODEL_SONNET_WINDOW:-}" ;;
    HAIKU)  val="${AI_DLC_MODEL_HAIKU_WINDOW:-}"  ;;
    *)      val="${AI_DLC_MODEL_OTHER_WINDOW:-}"  ;;
  esac
  if [ -n "$val" ]; then
    parsed="$(ai_dlc_parse_window "$val" 2>/dev/null)" || parsed=""
    if ai_dlc_window_in_range "$parsed"; then
      printf '%s|env %s' "$parsed" "$var"
      return 0
    fi
    rej="${rej}; rejected env ${var}=${val} (not in ${AI_DLC_WINDOW_MIN}..${AI_DLC_WINDOW_MAX})"
  fi
  if command -v jq >/dev/null 2>&1; then
    for f in "$@"; do
      [ -n "$f" ] && [ -r "$f" ] || continue
      val="$(jq -r --arg k "$var" '(.env // {})[$k] // empty | tostring' "$f" 2>/dev/null || true)"
      [ -n "$val" ] || continue
      parsed="$(ai_dlc_parse_window "$val" 2>/dev/null)" || parsed=""
      if ai_dlc_window_in_range "$parsed"; then
        printf '%s|%s env %s%s' "$parsed" "$(basename "$f")" "$var" "$rej"
        return 0
      fi
      rej="${rej}; rejected $(basename "$f") env ${var}=${val} (not in ${AI_DLC_WINDOW_MIN}..${AI_DLC_WINDOW_MAX})"
    done
  fi
  printf '|%s' "$rej"
  return 1
}

# ai_dlc_model_window <model id or alias> [settings files...]
# Echoes exactly one line: "<window>|<declared>|<source>". declared is 1 when a
# declaration or a `[1m]` suffix answered, 0 when a default did.
ai_dlc_model_window() {
  local id fam fw rej ad
  id="${1:-}"
  [ $# -gt 0 ] && shift
  fam="$(ai_dlc_model_family "$id")"
  if fw="$(ai_dlc_family_window "$fam" "$@")"; then
    printf '%s|1|%s' "${fw%%|*}" "${fw#*|}"
    return 0
  fi
  rej="${fw#*|}"
  case "$id" in
    *'[1m]'|*'[1M]') printf '1000000|1|[1m] suffix%s' "$rej"; return 0 ;;
  esac
  ad="$(ai_dlc_alias_default "$id")"
  printf '%s|0|%s%s' "${ad%%|*}" "${ad#*|}" "$rej"
}
