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
