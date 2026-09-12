#!/usr/bin/env bash
# Render `.claude/agents/<role>.md` agent definitions from `aiDlcRoles` in this project's
# .claude/settings.json.
#
# WHY THIS EXISTS. A role's configured `effort` had no channel that reached the subagent. The
# dispatch guard binds `model` through the Agent tool's `model` parameter and states the effort
# as a SENTENCE in the prompt, because that tool has no effort parameter -- and a prompt cannot
# set effort. Measured across the reference consumer's subagent transcripts, every child ran at
# the effort the SESSION resolved (from the launch flag, or from the user's
# `effortLevel`/`modelSettings`) and never at the role's, whatever the prompt directive said.
#
# A CHILD DOES NOT INHERIT ITS PARENT'S EFFORT, and the shape that reads that way is a
# coincidence of how the consumer launches. Measured over 1664 parent-child pairs: the
# resolution is the session's, so a session launched with one `--effort` value produces a
# uniform reading across every definition-less spawn under it. Writing this as inheritance
# predicts the wrong thing about a session launched any other way.
#
# The harness channel that DOES set it is `.claude/agents/<name>.md` frontmatter, and it
# OUTRANKS the session's resolution rather than merely filling a gap. Measured on CC 2.1.269
# under `claude --effort medium`: a definition-less child read `medium` (the flag in force), a
# definition with `effort: low` read `low`, and one with `effort: max` read `max`. So the
# definition is the binding and this renderer is what writes it.
#
# ONE DECLARATION, RENDERED. `aiDlcRoles.<role>` is the single source. This file restates none
# of it: the model key, the effort and the role set all come from settings.json at render time,
# because a second copy of any of them drifts silently and the symptom is a teammate running at
# a level nobody configured. The guard reads what this renders; `--check` at the gate is what
# stops the two separating.
#
# A ROLE WITH NO `model` KEY GETS NO FILE. The party personas (spawned inside /bmad-party-mode,
# which controls their model -- see core/hooks/ai-dlc-dispatch-guard.sh's PARTY PERSONAS
# paragraph for why their model is left alone) configure an effort and no model. Rendering a
# model-less definition for one would bind an effort onto a spawn the guard is told not to
# touch, so the absence of a model is read as "not ours to define", not as an error. The four
# names are NOT restated here; the condition is the model key's presence.
#
# THE MARKER NAMES THE CONSUMER PATH FROM EITHER COPY, DELIBERATELY. install.sh splits
# core/scripts/<x> to scripts/ai-dlc/<x>, and a marker that named whichever copy rendered it
# would make the two layouts produce different bytes for the same declaration -- which is
# exactly the drift `--check` exists to detect, manufactured by the checker itself. The
# rendered text is layout-independent; the command in it is the one a consumer types.
#
# EXIT STATUS:
#   0  every definition written (default), or every one current (--check)
#   1  --check only: a definition is missing, has drifted, is a stale projection of a role
#      that left `aiDlcRoles`, or names a model key that resolves in no `aiDlcModels`
#   2  REFUSAL: the root could not be resolved, jq is absent, or settings.json is present and
#      unparseable. Nothing was read, so nothing is known.
#   3  NOT APPLICABLE: no .claude/settings.json, or it declares no `aiDlcRoles`. This is a
#      project that pins no roles, which is a normal state and not a finding.
#
# 2 AND 3 ARE SEPARATE STATUSES AND THAT IS THE POINT. The distribution's own tree has no
# .claude/settings.json at all, so it is permanently in state 3; a consumer whose settings
# stopped parsing is in state 2 and its definitions are unknowable. Collapsing them would make
# the gate print the same line for "nothing to do here" and "this check could not run", which
# is this repository's named defect class. Both pre-push hooks and reconcile/apply.sh read the
# two codes differently, and none of them re-derives the applicability test.
#
# --check NEVER WRITES, so it is safe to call from a gate.
set -uo pipefail

MODE="write"
PROJECT_ROOT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --check) MODE="check" ;;
    --root)  shift; PROJECT_ROOT="${1:-}" ;;
    -h|--help)
      echo "usage: render-agent-definitions.sh [--check] [--root <dir>]"
      echo "  (default) write .claude/agents/<role>.md for every aiDlcRoles entry with a model"
      echo "  --check   report whether every definition is current; write nothing"
      exit 0 ;;
    *) echo "render-agent-definitions.sh: unknown argument '$1'" >&2; exit 2 ;;
  esac
  shift
done

# RESOLVE THE ROOT BY WALKING UP FOR A MARKER, never by counting `..` hops. This script sits at
# core/scripts/ in the distribution and scripts/ai-dlc/ in a consumer, and a hop count that is
# right in one is wrong in the other -- silently, because it still resolves to a directory.
#
# `-e` ON `.git`, NOT `-d`, AND THAT IS A MEASUREMENT. In a linked worktree `.git` is a FILE
# holding a gitdir pointer, not a directory, so a `-d` test walks straight past the root it was
# looking for. sync-transient-ignore.sh carries the `-d` spelling and is saved by VERSION being
# beside it in this repository; a consumer worktree has no VERSION and would resolve to
# whatever lies further up, or to nothing.
if [ -z "$PROJECT_ROOT" ]; then
  _d="$(cd "$(dirname "$0")" && pwd)"
  while [ "$_d" != "/" ]; do
    if [ -e "$_d/.git" ] || [ -f "$_d/VERSION" ]; then PROJECT_ROOT="$_d"; break; fi
    _d="$(dirname "$_d")"
  done
fi
if [ -z "$PROJECT_ROOT" ] || [ ! -d "$PROJECT_ROOT" ]; then
  echo "render-agent-definitions.sh: could not resolve a project root (no .git or VERSION above $(dirname "$0"))" >&2
  exit 2
fi

SETTINGS="$PROJECT_ROOT/.claude/settings.json"
AGENTS_DIR="$PROJECT_ROOT/.claude/agents"

# NOT APPLICABLE, ASKED BEFORE jq. A project with no settings file pins no roles, and that is
# the distribution's own permanent state -- reporting a missing tool for it would be a refusal
# where there is nothing to refuse.
if [ ! -f "$SETTINGS" ]; then
  echo "NOT APPLICABLE: $SETTINGS does not exist, so no roles are pinned here."
  exit 3
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "render-agent-definitions.sh: jq is required to read $SETTINGS" >&2
  exit 2
fi
if ! jq -e . "$SETTINGS" >/dev/null 2>&1; then
  echo "render-agent-definitions.sh: $SETTINGS is not parseable JSON; refusing to render from it" >&2
  exit 2
fi
if [ "$(jq -r 'has("aiDlcRoles")' "$SETTINGS" 2>/dev/null)" != "true" ]; then
  echo "NOT APPLICABLE: $SETTINGS declares no aiDlcRoles, so no roles are pinned here."
  exit 3
fi

# THE GENERATED MARKER, AND WHY THE PREFIX IS SEPARATE FROM THE LINE. The per-role line carries
# the role name so a reader of one file knows which settings entry produced it. The stale scan
# below has to recognise a generated file whose role is no longer declared -- it cannot know
# that name in advance -- so it keys on the role-independent PREFIX. One string, two uses, and
# the full line is built from the prefix rather than written twice.
GEN_PREFIX='<!-- AI/DLC GENERATED: rendered by scripts/ai-dlc/render-agent-definitions.sh'

# The effort vocabulary. SAME FIVE LEVELS AS core/hooks/ai-dlc-dispatch-guard.sh's `PIN_EFFORT`
# case and core/scripts/validate-spawn-ledger.sh; an invariant in the distribution binds the
# three to one list. An unrecognised level is DROPPED, never rendered -- a definition carrying
# a level the harness does not accept is worse than one carrying none, because the harness's
# own fallback is silent and the file reads as though it bound something.
effort_valid() {
  case "$1" in
    low|medium|high|xhigh|max) return 0 ;;
    *) return 1 ;;
  esac
}

# render_one <role> <model-key> <effort-or-empty> -> the definition text on stdout.
#
# THE LAST TWO BODY LINES RESTORE WHAT A CUSTOM BODY REPLACES. A subagent spawned with no
# definition gets the harness's general-purpose prompt, which carries a no-proactive-`.md` rule
# and a no-re-delegation rule; a definition's body substitutes for that prompt and takes both
# with it. The report-as-text and absolute-path rules are appended by the harness to every
# subagent regardless of type and are not restated.
render_one() {
  printf -- '---\n'
  printf 'name: %s\n' "$1"
  printf 'description: AI/DLC role %s — rendered from aiDlcRoles.%s; do not edit by hand\n' "$1" "$1"
  printf 'model: %s\n' "$2"
  [ -n "$3" ] && printf 'effort: %s\n' "$3"
  printf -- '---\n'
  printf '%s from .claude/settings.json aiDlcRoles.%s. Edit the settings entry, then re-render. -->\n' \
    "$GEN_PREFIX" "$1"
  printf 'Your operating contract is `.claude/team-roles/%s.md`. Read it and follow it as your\n' "$1"
  printf 'FIRST action before any other work.\n'
  printf 'Never create documentation or report files unless your brief names the path; return findings\n'
  printf 'as text. Do not re-delegate your assignment to another agent.\n'
}

ROLES="$(jq -r '.aiDlcRoles | keys[]' "$SETTINGS" 2>/dev/null)"

rc=0
rendered=0
skipped_nomodel=0
unresolved=""
bad_effort=""
bad_name=""
# RENDERED NAMES ARE RECORDED AS A NEWLINE-DELIMITED STRING, not an array: bash 3.2 under
# `set -u` errors on expanding an EMPTY array, and the empty case is reachable (every role a
# party persona).
RENDERED_NAMES=""
drift=""
missing=""

while IFS= read -r role; do
  [ -n "$role" ] || continue

  # A ROLE NAME IS A PATH COMPONENT AND settings.json IS CONSUMER-OWNED INPUT. Anything outside
  # the role-file grammar the dispatch guard already derives (`[a-z][a-z-]*`) is refused rather
  # than turned into a filename -- `../../x` under `.claude/agents/` writes outside the tree.
  case "$role" in
    *[!a-z0-9-]*|'' ) bad_name="$bad_name $role"; continue ;;
    [!a-z]*)          bad_name="$bad_name $role"; continue ;;
  esac

  mkey="$(jq -r --arg r "$role" '.aiDlcRoles[$r].model // empty' "$SETTINGS" 2>/dev/null)"
  if [ -z "$mkey" ]; then
    # NORMAL, NOT AN ERROR. See the header: a role configuring an effort and no model is one
    # this renderer has nothing to say about.
    skipped_nomodel=$((skipped_nomodel+1))
    continue
  fi
  mstr="$(jq -r --arg k "$mkey" '.aiDlcModels[$k] // empty' "$SETTINGS" 2>/dev/null)"
  if [ -z "$mstr" ]; then
    # A DELIVERY GAP, NOT A PREFERENCE. The role was configured to run on a model and the key
    # resolves to nothing, so it gets no definition and its spawns fall back to the parent's
    # effort -- which is the exact state this renderer exists to end. Reported, and fatal to
    # --check.
    unresolved="$unresolved ${role}(${mkey})"
    rc=1
    continue
  fi

  eff="$(jq -r --arg r "$role" '.aiDlcRoles[$r].effort // empty' "$SETTINGS" 2>/dev/null)"
  if [ -n "$eff" ] && ! effort_valid "$eff"; then
    bad_effort="$bad_effort ${role}(${eff})"
    eff=""
  fi

  RENDERED_NAMES="$RENDERED_NAMES$role
"
  want="$(render_one "$role" "$mkey" "$eff")"
  target="$AGENTS_DIR/$role.md"

  if [ "$MODE" = "check" ]; then
    if [ ! -f "$target" ]; then
      missing="$missing $role"
      rc=1
    elif ! printf '%s\n' "$want" | cmp -s - "$target"; then
      drift="$drift $role"
      rc=1
    fi
  else
    mkdir -p "$AGENTS_DIR" || { echo "render-agent-definitions.sh: cannot create $AGENTS_DIR" >&2; exit 2; }
    printf '%s\n' "$want" > "$target" || { echo "render-agent-definitions.sh: cannot write $target" >&2; exit 2; }
    rendered=$((rendered+1))
  fi
done <<EOF
$ROLES
EOF

# STALE PROJECTIONS. A role that leaves `aiDlcRoles` leaves its definition behind, and that
# file keeps binding a model and an effort for a role the configuration no longer describes --
# the harness reads the directory, not the settings. Only files carrying the GENERATED marker
# are ever considered: a consumer's own hand-written agent definition is none of this
# renderer's business and is neither reported nor touched.
#
# WRITE MODE DELETES THEM. If it did not, `--check` would go red on a stale projection with no
# command able to clear it, and a standard nothing can satisfy is one an operator switches off.
stale=""
if [ -d "$AGENTS_DIR" ]; then
  for f in "$AGENTS_DIR"/*.md; do
    [ -f "$f" ] || continue
    grep -qF -- "$GEN_PREFIX" "$f" || continue
    base="${f##*/}"; base="${base%.md}"
    case "
$RENDERED_NAMES" in
      *"
$base
"*) continue ;;
    esac
    stale="$stale $base"
    if [ "$MODE" = "check" ]; then
      rc=1
    else
      rm -f "$f"
    fi
  done
fi

# --- report ------------------------------------------------------------------------------
[ -n "${bad_name// /}" ] && \
  echo "render-agent-definitions.sh: aiDlcRoles key(s) outside the role-name grammar, skipped:${bad_name}" >&2
[ -n "${bad_effort// /}" ] && \
  echo "render-agent-definitions.sh: invalid effort level(s), OMITTED from the rendered definition (valid: low medium high xhigh max):${bad_effort}" >&2
[ -n "${unresolved// /}" ] && \
  echo "render-agent-definitions.sh: role(s) whose model key resolves in no aiDlcModels entry, so NO definition was rendered and their spawns keep the parent's effort:${unresolved}" >&2

if [ "$MODE" = "check" ]; then
  if [ "$rc" -eq 0 ]; then
    echo "OK: agent definitions current ($(printf '%s' "$RENDERED_NAMES" | grep -c .) role(s), $skipped_nomodel model-less role(s) correctly undefined)"
    exit 0
  fi
  [ -n "${missing// /}" ] && echo "FAIL: no .claude/agents/<role>.md for pinned role(s):${missing}"
  [ -n "${drift// /}" ]   && echo "FAIL: .claude/agents/<role>.md has DRIFTED from aiDlcRoles for:${drift}"
  [ -n "${stale// /}" ]   && echo "FAIL: generated .claude/agents/<role>.md for role(s) no longer in aiDlcRoles:${stale}"
  [ -n "${unresolved// /}" ] && echo "FAIL: unresolvable model key(s):${unresolved}"
  echo "  These are a rendered region: change .claude/settings.json aiDlcRoles, then run:"
  echo "  bash scripts/ai-dlc/render-agent-definitions.sh"
  exit 1
fi

echo "  .claude/agents/: $rendered definition(s) written, $skipped_nomodel model-less role(s) left undefined"
[ -n "${stale// /}" ] && echo "  removed stale generated definition(s) for role(s) no longer in aiDlcRoles:${stale}"
# rc is 1 here only when a model key resolved to nothing, which the stderr line above named.
exit "$rc"
