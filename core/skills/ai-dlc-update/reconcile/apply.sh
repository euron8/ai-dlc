#!/usr/bin/env bash
# apply.sh — the RESOLUTION half of ai-dlc-update. Executes every MECHANICAL resolution a pull
# needs, and emits a worklist of the only things left: the genuinely SEMANTIC merges (which the
# skill does inline) and the genuine OPERATOR decisions. The point of the whole skill is that the
# operator runs the update and it lands — not that a report tells them to go do the fixes by hand.
#
# WHAT IT RESOLVES MECHANICALLY (writes to the consumer; the caller wraps this in a branch+commit):
#   - pure applies        UPSTREAM-ONLY / UPSTREAM-ONLY-ADD core files overwritten from theirs
#   - token substitution  a new SETUP-TOKENS file's {*_model_*} filled from the nearest-equivalent
#                         existing role (gate-adjudicator <- adversary; same opus tier), no prompt
#   - drift refile        a known in-place core-list drift refiled to its consumer-extension point
#                         (provenance-block.json known_skills -> extensions/known-skills.json) and
#                         the core file reverted — the "migrate the drift" chore, automated
#   - catalog relabel     relabel-extension-checks.sh --apply (labels NEW-THIS-PULL collisions)
#   - re-stamp            .ai-dlc-version base -> theirs
#
# WHAT IT HANDS BACK (it does NOT guess these):
#   WORKLIST semantic-merge   <path>      a BOTH-CHANGED file needing a 3-way PROSE merge (LLM)
#   WORKLIST override-readopt <override>  a HARD-OVERRIDE-DRIFT-SECTION: merge the section, then
#                                         readopt-override.sh --stamp readopt (LLM + gated script)
#   DECISION <kind> <path> <why>          a genuine operator call (unknown drift refile-vs-revert,
#                                         a deletion, a value with no default)
#
# Usage:  apply.sh <dist> <base> <consumer> <theirs>
# Exit:   0 = mechanical resolution completed (a residual WORKLIST/DECISION is normal, not failure)
#         1 = an error while resolving; 2 = usage.
set -uo pipefail

DIST="${1:?usage: apply.sh <dist> <base> <consumer> <theirs>}"
BASE="${2:?}"
CONSUMER="${3:?}"
THEIRS="${4:?}"

SELF="$(cd "$(dirname "$0")" && pwd)"
say() { printf '%s\t%s\t%s\n' "$1" "$2" "${3:-}"; }
err() { echo "apply: $*" >&2; exit 1; }

# core/<rel> -> consumer path (mirrors install.sh / unregistered-drift.sh).
consumer_path() {
  case "$1" in
    skills/ai-dlc-setup/*) printf '%s/.claude/skills/ai-dlc-setup/%s' "$CONSUMER" "${1#skills/ai-dlc-setup/}" ;;
    skills/ai-dlc-update/*) printf '%s/.claude/skills/ai-dlc-update/%s' "$CONSUMER" "${1#skills/ai-dlc-update/}" ;;
    skills/ai-dlc/*)  printf '%s/.claude/skills/ai-dlc/%s'  "$CONSUMER" "${1#skills/ai-dlc/}" ;;
    team-roles/*)     printf '%s/.claude/team-roles/%s'     "$CONSUMER" "${1#team-roles/}" ;;
    hooks/*)          printf '%s/.claude/hooks/%s'          "$CONSUMER" "${1#hooks/}" ;;
    schemas/*)        printf '%s/.claude/schemas/%s'        "$CONSUMER" "${1#schemas/}" ;;
    scripts/*)        printf '%s/scripts/%s'                "$CONSUMER" "${1#scripts/}" ;;
    fixtures/*)       printf '%s/tests/fixtures/%s'         "$CONSUMER" "${1#fixtures/}" ;;
    *) return 1 ;;
  esac
}
overwrite_from_theirs() { # <core-rel>
  local cp="$1" cons; cons="$(consumer_path "$cp")" || return 1
  mkdir -p "$(dirname "$cons")"
  git -C "$DIST" show "${THEIRS}:core/${cp}" > "$cons" 2>/dev/null || return 1
}

# ---------------------------------------------------------------- 1. buckets (preclassify)
PC="$(bash "$SELF/preclassify.sh" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" 2>/dev/null || true)"

while IFS="$(printf '\t')" read -r kind path cons bucket; do
  [ -n "${bucket:-}" ] || continue
  rel="${path#core/}"
  case "$bucket" in
    UPSTREAM-ONLY|UPSTREAM-ONLY-ADD)
      overwrite_from_theirs "$rel" && say RESOLVED pure-apply "$rel" || say DECISION unmapped-path "$rel" "no consumer path mapping" ;;
    *SETUP-TOKENS*)
      if overwrite_from_theirs "$rel"; then
        cons="$(consumer_path "$rel")"
        # Fill {gate_adjudicator_model_*} from the consumer's adversary role (same opus tier).
        adv="$CONSUMER/.claude/team-roles/adversary.md"
        if [ -f "$adv" ]; then
          p="$(sed -nE 's/^- Personal: `\/model (.+)`$/\1/p' "$adv" | head -1)"
          b="$(sed -nE 's/^- Bedrock: `\/model (.+)`$/\1/p' "$adv" | head -1)"
          [ -n "$p" ] && sed -i.bak "s|{gate_adjudicator_model_personal}|$p|g" "$cons"
          [ -n "$b" ] && sed -i.bak "s|{gate_adjudicator_model_bedrock}|$b|g" "$cons"
          rm -f "$cons.bak"
        fi
        if grep -q '{[a-z_]*_model_[a-z]*}' "$cons" 2>/dev/null; then
          say DECISION setup-token "$rel" "a {*_model_*} token had no default source"
        else
          say RESOLVED token-substitute "$rel"
        fi
      else
        say DECISION unmapped-path "$rel" "no consumer path mapping"
      fi ;;
    *CLASSIFY*)
      say WORKLIST semantic-merge "$rel" ;;
    UPSTREAM-DELETED|ORPHANED-RELOCATED*)
      say DECISION deletion "$rel" "apply would remove a consumer file — gated" ;;
    ALREADY-AT-THEIRS|ALREADY-PRESENT|*NOOP|DIST-ONLY-SKIP) : ;;
    *) say DECISION unhandled-bucket "$rel" "$bucket" ;;
  esac
done <<EOF
$PC
EOF

# ---------------------------------------------------------------- 2. drift refile (known patterns)
# provenance-block.json known_skills: the consumer added skill names in place. Refile them to the
# sanctioned extension point (extensions/known-skills.json) and revert the schema to theirs.
UD="$(bash "$SELF/unregistered-drift.sh" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null | awk -F'\t' '$1=="HARD-UNREGISTERED-CORE-DRIFT"{print $2}')"
while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  cons="$(consumer_path "$rel")" || { say DECISION drift "$rel" "no consumer path mapping"; continue; }
  case "$rel" in
    schemas/provenance-block.json)
      added="$(diff <(git -C "$DIST" show "${THEIRS}:core/${rel}" 2>/dev/null) "$cons" 2>/dev/null \
               | sed -n 's/^> *//p' | grep -oE '"[^"]+"' | tr -d '"' | grep -v '^known_skills$' | sort -u)"
      if [ -n "$added" ]; then
        ext="$CONSUMER/.claude/skills/ai-dlc/extensions/known-skills.json"
        mkdir -p "$(dirname "$ext")"
        python3 - "$ext" $added <<'PY'
import json, os, sys
path = sys.argv[1]; new = sys.argv[2:]
cur = []
if os.path.isfile(path):
    try:
        d = json.load(open(path)); cur = d.get("known_skills", d) if isinstance(d, dict) else d
    except Exception: cur = []
merged = list(dict.fromkeys([str(x) for x in cur] + new))
open(path, "w").write(json.dumps({"known_skills": merged}, indent=2) + "\n")
PY
        git -C "$DIST" show "${THEIRS}:core/${rel}" > "$cons" 2>/dev/null
        say RESOLVED drift-refile "$rel" "-> extensions/known-skills.json ($(echo $added | tr '\n' ' '))"
      else
        say DECISION drift "$rel" "in-place schema edit is not an additive known_skills entry — refile-vs-revert"
      fi ;;
    *)
      say DECISION drift "$rel" "in-place core edit with no known refile pattern — refile-as-override or revert" ;;
  esac
done <<EOF
$UD
EOF

# ---------------------------------------------------------------- 3. override readopt (hand to LLM)
LD_HARD="$(bash "$SELF/layer-drift.sh" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" 2>/dev/null | awk -F'\t' '$1=="HARD-OVERRIDE-DRIFT-SECTION"{print $2}')"
while IFS= read -r ovr; do
  [ -n "$ovr" ] || continue
  say WORKLIST override-readopt "$ovr" "merge the moved core section into the override body, then readopt-override.sh --stamp readopt"
done <<EOF
$LD_HARD
EOF

# ---------------------------------------------------------------- 4. catalog relabel (mechanical)
if bash "$SELF/relabel-extension-checks.sh" "$CONSUMER" --apply --dist "$DIST" --theirs "$THEIRS" >/dev/null 2>&1; then
  say RESOLVED relabel "ext-check collisions labelled"
fi

# ---------------------------------------------------------------- 5. re-stamp
STAMP="$CONSUMER/.claude/.ai-dlc-version"
if [ -f "$STAMP" ]; then
  theirs_sha="$(git -C "$DIST" rev-parse --short "$THEIRS" 2>/dev/null || echo "$THEIRS")"
  ver="$(cat "$DIST/VERSION" 2>/dev/null || true)"
  sed -i.bak -E "s/^(commit:).*/\1 ${theirs_sha}/" "$STAMP" 2>/dev/null || true
  [ -n "$ver" ] && sed -i.bak -E "s/^(version:).*/\1 ${ver}/" "$STAMP" 2>/dev/null || true
  rm -f "$STAMP.bak"
  say RESOLVED restamp "$BASE -> $theirs_sha"
fi

exit 0
