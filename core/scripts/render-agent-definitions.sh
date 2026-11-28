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
# `omitClaudeMd` IS RENDERED INTO THE FRONTMATTER WHEN THE ENTRY DECLARES `true`, and never
# otherwise. A non-fork subagent receives every CLAUDE.md level plus the unscoped rules unless
# its definition says not to. The template flags every role whose contract does not need the
# consumer rulebook resident on every dispatch -- all but `dev`, `dev-escalated` and
# `protected-path-editor`, whose contracts edit or cite it throughout; a flagged role that needs
# one section of it is told to Read the project's `CLAUDE.md` by the step passage that needs it.
# The harness default is already "do not omit", so a declared `false` and an absent key render
# the same bytes.
#
# `disallowedTools` IS RENDERED VERBATIM AS A FRONTMATTER LINE WHEN THE ENTRY DECLARES A
# NON-EMPTY STRING of tool names separated by `, ` (for example "Skill, Agent"). It is a
# denylist: tools the role's contract never uses are removed from its first request, and every
# tool not named stays, deferred and MCP tools included. An absent key or an empty string
# renders no line. Any other value -- a non-string, or a string outside the grammar -- is
# OMITTED and reported, like an invalid effort.
#
# THE VALUE IS LOADED WITH A NULL-SAFE jq EXPRESSION, NOT `// empty`, AND THAT IS A TRAP. `//`
# treats jq's `false` as an absent left side: `.omitClaudeMd // empty` prints EMPTY for a
# declared `false` and cannot tell "the consumer said no" from "the consumer said nothing". The
# two render identically for THIS field, so the spelling is fixed for the field that follows --
# a boolean read through `//` silently loses its falsy value, and the loss reads as absence.
#
# A ROLE WITH NO `model` KEY GETS NO FILE. A party persona's model is optional (see
# core/hooks/ai-dlc-dispatch-guard.sh's PARTY PERSONAS paragraph): one that sets a model gets a
# definition like any role, and one without leaves its model to /bmad-party-mode. Rendering a
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
#
# --role <r> LIMITS THE RUN TO ONE ROLE, in both modes. `--check --role <r>` exits 0 when that one
# definition is current and 1 when it is missing, has drifted, or <r> has no rendered definition
# (absent from `aiDlcRoles`, model-less, or its model key unresolved). Other roles are neither
# compared nor reported, and the stale-projection pass does not run. Write mode with --role
# writes only that definition and deletes nothing. A <r> outside the role-name grammar exits 2.
rad_main() {
set -uo pipefail

MODE="write"
PROJECT_ROOT=""
ONLY_ROLE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --check) MODE="check" ;;
    --root)  shift; PROJECT_ROOT="${1:-}" ;;
    --role)  shift; ONLY_ROLE="${1:-}"
             case "$ONLY_ROLE" in
               ''|*[!a-z0-9-]*|[!a-z]*) echo "render-agent-definitions.sh: --role needs a role name matching [a-z][a-z0-9-]*" >&2; exit 2 ;;
             esac ;;
    -h|--help)
      echo "usage: render-agent-definitions.sh [--check] [--role <r>] [--root <dir>]"
      echo "  (default) write .claude/agents/<role>.md for every aiDlcRoles entry with a model"
      echo "  --check   report whether every definition is current; write nothing"
      echo "  --role r  limit the run to role r (exit 1 under --check when r has no current definition)"
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
  _d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  while [ "$_d" != "/" ]; do
    if [ -e "$_d/.git" ] || [ -f "$_d/VERSION" ]; then PROJECT_ROOT="$_d"; break; fi
    _d="$(dirname "$_d")"
  done
fi
if [ -z "$PROJECT_ROOT" ] || [ ! -d "$PROJECT_ROOT" ]; then
  echo "render-agent-definitions.sh: could not resolve a project root (no .git or VERSION above $(dirname "${BASH_SOURCE[0]}"))" >&2
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

# The omitClaudeMd vocabulary: a JSON boolean, which the jq load above prints as `true` or
# `false`. Any other value is the invalid-effort class -- a frontmatter line the harness does
# not accept is worse than none, because the harness's own fallback is silent and the file reads
# as though it bound something. Omitted from the file, reported on stderr.
omit_valid() {
  case "$1" in
    true|false) return 0 ;;
    *) return 1 ;;
  esac
}

# The disallowedTools grammar: one or more tool names, each `[A-Za-z][A-Za-z0-9_*-]*`, joined by
# exactly `, `. The value reaches this test as the loader printed it; a non-string arrives
# type-tagged (`(boolean)true`) and so can never match.
DT_NAME='[A-Za-z][A-Za-z0-9_*-]*'
DT_RE="^${DT_NAME}(, ${DT_NAME})*\$"
dt_valid() {
  [[ "$1" =~ $DT_RE ]]
}

# role_file <role> -> the role file a definition embeds: the INSTALLED copy, which carries the
# consumer's layering as the lead loads it, else core/team-roles/ (the distribution layout), else
# nothing (the body then tells the teammate to Read the file, as before embedding).
role_file() {
  if [ -f "$PROJECT_ROOT/.claude/team-roles/$1.md" ]; then printf '%s' "$PROJECT_ROOT/.claude/team-roles/$1.md"
  elif [ -f "$PROJECT_ROOT/core/team-roles/$1.md" ]; then printf '%s' "$PROJECT_ROOT/core/team-roles/$1.md"
  fi
}

# contract_region < <definition> -> the lines between the ROLE-CONTRACT markers, builtins only.
contract_region() {
  local _l _f=0
  while IFS= read -r _l || [ -n "$_l" ]; do
    case "$_l" in
      '<!-- ROLE-CONTRACT BEGIN '*) _f=1; continue ;;
      '<!-- ROLE-CONTRACT END -->') _f=0; continue ;;
    esac
    [ "$_f" = 1 ] && printf '%s\n' "$_l"
  done
  return 0
}

# render_one <role> <model-key> <effort-or-empty> <omit-true-or-empty> <disallowedTools-or-empty>
#   -> the definition text.
#
# THE LAST TWO BODY LINES RESTORE WHAT A CUSTOM BODY REPLACES. A subagent spawned with no
# definition gets the harness's general-purpose prompt, which carries a no-proactive-`.md` rule
# and a no-re-delegation rule; a definition's body substitutes for that prompt and takes both
# with it. The report-as-text and absolute-path rules are appended by the harness to every
# subagent regardless of type and are not restated.
#
# THE ROLE CONTRACT IS EMBEDDED, VERBATIM, BETWEEN ROLE-CONTRACT MARKERS. Sibling spawns diverge at
# their first tool call, so a role file reached by a Read is written to the prompt cache by every
# spawn; text in the definition body sits in the shared prefix and later spawns of the role read it
# from cache. The FIRST body line stays the role-specific Rule 19(b) line the dispatch guard keys
# on. The harness loads definitions once per process, so a re-render reaches only later sessions;
# the guard credits the embedded copy only from the session's SessionStart snapshot and otherwise
# cites the role file in the prompt. A role-file edit is therefore drift, and --check names it.
render_one() {
  printf -- '---\n'
  printf 'name: %s\n' "$1"
  printf 'description: AI/DLC role %s — rendered from aiDlcRoles.%s; do not edit by hand\n' "$1" "$1"
  printf 'model: %s\n' "$2"
  [ -n "$3" ] && printf 'effort: %s\n' "$3"
  [ "${4:-}" = "true" ] && printf 'omitClaudeMd: true\n'
  [ -n "${5:-}" ] && printf 'disallowedTools: %s\n' "$5"
  printf -- '---\n'
  printf '%s from .claude/settings.json aiDlcRoles.%s. Edit the settings entry, then re-render. -->\n' \
    "$GEN_PREFIX" "$1"
  printf 'Your operating contract is `.claude/team-roles/%s.md`. Read it and follow it as your\n' "$1"
  _rf="$(role_file "$1")"
  if [ -n "$_rf" ]; then
    printf 'contract: its text follows below, between the ROLE-CONTRACT BEGIN and END markers, so you hold it without a Read. If your brief tells you to Read that file, Read that file in consecutive `offset`/`limit` chunks of at most 16 KB through its last line (when a chunk is refused for size, halve its limit): the file is then newer than the copy below. Read an appendix only when a pointer in the contract tells you to.\n'
    printf '<!-- ROLE-CONTRACT BEGIN .claude/team-roles/%s.md -->\n' "$1"
    # Builtins only: each line as read, a final newline added only where the file lacks one.
    while IFS= read -r _l || [ -n "$_l" ]; do printf '%s\n' "$_l"; done < "$_rf"
    printf '<!-- ROLE-CONTRACT END -->\n'
  else
    printf 'FIRST action before any other work, reading it with native Read in consecutive `offset`/`limit` chunks of at most 16 KB covering the whole file, never `ctx_*`.\n'
  fi
  printf 'Never create documentation or report files unless your brief names the path; return findings\n'
  printf 'as text. Do not re-delegate your assignment to another agent.\n'
  printf 'A path `.claude/hooks/ai-dlc-protect.sh` protects (its PROTECTED_PATTERNS) is read with the native Read tool, never with a context-mode tool (ctx_*): the hook denies those calls.\n'
}

# ONE jq FOR EVERY ROLE. A line is `F` US `<role>` US `<model key>` US `<model string>` US `<effort>` US `<omitClaudeMd>`
# US `<disallowedTools>` (US = \037, a separator that is not IFS whitespace, so an empty field survives the split), the
# five values the per-role calls below load. A role whose fields hold a newline or US, a non-scalar, a non-string
# disallowedTools, or a lookup jq errors on, and a role name outside the role-file grammar, is printed as `S` US
# `<name>`; the loop then loads that role's fields with the five per-field calls, so the value is exactly what they
# return. The path is read from the tag alone, never inferred from a US inside the name.
US="$(printf '\037')"
ROLES="$(jq -r '. as $d | .aiDlcRoles | keys[] as $r
  | if ($r | test("^[a-z][a-z0-9-]*$") | not) then "S\u001f" + $r else
      (try (
        def sc: if type == "string" then . elif type == "number" or type == "boolean" then tojson else error("slow") end;
        (($d.aiDlcRoles[$r].model // "") | sc) as $m
        | (if $m == "" then "" else (($d.aiDlcModels[$m] // "") | sc) end) as $ms
        | (($d.aiDlcRoles[$r].effort // "") | sc) as $e
        | ($d.aiDlcRoles[$r].omitClaudeMd | if . == null then "" else tostring end) as $o
        | ($d.aiDlcRoles[$r].disallowedTools | if . == null then "" elif type == "string" then . else error("slow") end) as $t
        | [$m, $ms, $e, $o, $t] | if any(.[]; test("[\n\u001f]")) then error("slow") else . end
        | (["F", $r] + .) | join("\u001f")
      ) catch ("S\u001f" + $r)) end' "$SETTINGS" 2>/dev/null)"

rc=0
rendered=0
skipped_nomodel=0
unresolved=""
bad_effort=""
bad_omit=""
bad_dt=""
bad_name=""
# RENDERED NAMES ARE RECORDED AS A NEWLINE-DELIMITED STRING, not an array: bash 3.2 under
# `set -u` errors on expanding an EMPTY array, and the empty case is reachable (every role a
# party persona).
RENDERED_NAMES=""
drift=""
drift_rf=""
missing=""

while IFS= read -r role; do
  [ -n "$role" ] || continue
  fast=""
  case "$role" in
    "F$US"*) fast=1; role="${role#F"$US"}"; IFS="$US" read -r role mkey mstr eff om dt <<EOR
$role
EOR
    ;;
    "S$US"*) role="${role#S"$US"}" ;;
  esac
  [ -n "$role" ] || continue
  [ -z "$ONLY_ROLE" ] || [ "$role" = "$ONLY_ROLE" ] || continue

  # A ROLE NAME IS A PATH COMPONENT AND settings.json IS CONSUMER-OWNED INPUT. Anything outside
  # the role-file grammar the dispatch guard already derives (`[a-z][a-z-]*`) is refused rather
  # than turned into a filename -- `../../x` under `.claude/agents/` writes outside the tree.
  case "$role" in
    *[!a-z0-9-]*|'' ) bad_name="$bad_name $role"; continue ;;
    [!a-z]*)          bad_name="$bad_name $role"; continue ;;
  esac

  [ -n "$fast" ] || mkey="$(jq -r --arg r "$role" '.aiDlcRoles[$r].model // empty' "$SETTINGS" 2>/dev/null)"
  if [ -z "$mkey" ]; then
    # NORMAL, NOT AN ERROR. See the header: a role configuring no model (a party persona whose
    # model /bmad-party-mode chooses) is one this renderer has nothing to say about.
    skipped_nomodel=$((skipped_nomodel+1))
    continue
  fi
  [ -n "$fast" ] || mstr="$(jq -r --arg k "$mkey" '.aiDlcModels[$k] // empty' "$SETTINGS" 2>/dev/null)"
  if [ -z "$mstr" ]; then
    # A DELIVERY GAP, NOT A PREFERENCE. The role was configured to run on a model and the key
    # resolves to nothing, so it gets no definition and its spawns fall back to the parent's
    # effort -- which is the exact state this renderer exists to end. Reported, and fatal to
    # --check.
    unresolved="$unresolved ${role}(${mkey})"
    rc=1
    continue
  fi

  [ -n "$fast" ] || eff="$(jq -r --arg r "$role" '.aiDlcRoles[$r].effort // empty' "$SETTINGS" 2>/dev/null)"
  if [ -n "$eff" ] && ! effort_valid "$eff"; then
    bad_effort="$bad_effort ${role}(${eff})"
    eff=""
  fi

  # NOT `// empty`: see the header. A declared `false` must reach `omit_valid` AS `false`, not
  # as absence, so the loader distinguishes the three states the declaration can be in.
  [ -n "$fast" ] || om="$(jq -r --arg r "$role" '.aiDlcRoles[$r].omitClaudeMd | if . == null then "" else tostring end' "$SETTINGS" 2>/dev/null)"
  if [ -n "$om" ] && ! omit_valid "$om"; then
    bad_omit="$bad_omit ${role}(${om})"
    om=""
  fi

  # A non-string is TYPE-TAGGED, not stringified: `tojson` alone prints a boolean `true` as
  # `true`, which the tool-name grammar accepts. The trailing `.` keeps a value's own trailing
  # newline from being stripped by the command substitution, so it fails the grammar too.
  if [ -z "$fast" ]; then
    dt="$(jq -r --arg r "$role" '.aiDlcRoles[$r].disallowedTools | (if . == null then "" elif type == "string" then . else "(" + type + ")" + tojson end) + "."' "$SETTINGS" 2>/dev/null)"
    dt="${dt%.}"
  fi
  if [ -n "$dt" ] && ! dt_valid "$dt"; then
    bad_dt="$bad_dt ${role}(${dt})"
    dt=""
  fi

  RENDERED_NAMES="$RENDERED_NAMES$role
"
  want="$(render_one "$role" "$mkey" "$eff" "$om" "$dt")"
  target="$AGENTS_DIR/$role.md"

  if [ "$MODE" = "check" ]; then
    if [ ! -f "$target" ]; then
      missing="$missing $role"
      rc=1
    elif ! printf '%s\n' "$want" | cmp -s - "$target"; then
      _rf="$(role_file "$role")"
      # The region is compared against the region THIS render would write, never against the file
      # bytes, so a role file without a final newline is not reported forever.
      if [ -n "$_rf" ] && [ "$(printf '%s\n' "$want" | contract_region)" != "$(contract_region < "$target")" ]; then
        drift_rf="$drift_rf ${role}(${_rf#"$PROJECT_ROOT"/})"
      else
        drift="$drift $role"
      fi
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
if [ -z "$ONLY_ROLE" ] && [ -d "$AGENTS_DIR" ]; then
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

# --role <r> naming no rendered definition is a finding, never a vacuous pass.
if [ -n "$ONLY_ROLE" ]; then
  case "
$RENDERED_NAMES" in
    *"
$ONLY_ROLE
"*) : ;;
    *) echo "FAIL: --role $ONLY_ROLE has no rendered definition (not in aiDlcRoles, model-less, or unresolved model key)" >&2; rc=1 ;;
  esac
fi

# --- report ------------------------------------------------------------------------------
[ -n "${bad_name// /}" ] && \
  echo "render-agent-definitions.sh: aiDlcRoles key(s) outside the role-name grammar, skipped:${bad_name}" >&2
[ -n "${bad_effort// /}" ] && \
  echo "render-agent-definitions.sh: invalid effort level(s), OMITTED from the rendered definition (valid: low medium high xhigh max):${bad_effort}" >&2
[ -n "${bad_omit// /}" ] && \
  echo "render-agent-definitions.sh: invalid omitClaudeMd value(s), OMITTED from the rendered definition (valid: true false):${bad_omit}" >&2
[ -n "${bad_dt// /}" ] && \
  echo "render-agent-definitions.sh: invalid disallowedTools value(s), OMITTED from the rendered definition (valid: a JSON string of tool names joined by ', '):${bad_dt}" >&2
[ -n "${unresolved// /}" ] && \
  echo "render-agent-definitions.sh: role(s) whose model key resolves in no aiDlcModels entry, so NO definition was rendered and their spawns keep the parent's effort:${unresolved}" >&2

if [ "$MODE" = "check" ]; then
  if [ "$rc" -eq 0 ]; then
    echo "OK: agent definitions current ($(printf '%s' "$RENDERED_NAMES" | grep -c .) role(s), $skipped_nomodel model-less role(s) correctly undefined)"
    exit 0
  fi
  [ -n "${missing// /}" ] && echo "FAIL: no .claude/agents/<role>.md for pinned role(s):${missing}"
  [ -n "${drift// /}" ]   && echo "FAIL: .claude/agents/<role>.md has DRIFTED from aiDlcRoles for:${drift}"
  [ -n "${drift_rf// /}" ] && echo "FAIL: .claude/agents/<role>.md embeds a stale copy of its role file, which changed since the last render, for:${drift_rf}"
  [ -n "${stale// /}" ]   && echo "FAIL: generated .claude/agents/<role>.md for role(s) no longer in aiDlcRoles:${stale}"
  [ -n "${unresolved// /}" ] && echo "FAIL: unresolvable model key(s):${unresolved}"
  [ -n "${drift_rf// /}" ] && echo "  The role file is the source of the embedded contract: keep the role-file edit and re-render."
  echo "  These are a rendered region: change .claude/settings.json aiDlcRoles, then run:"
  echo "  bash scripts/ai-dlc/render-agent-definitions.sh"
  exit 1
fi

echo "  .claude/agents/: $rendered definition(s) written, $skipped_nomodel model-less role(s) left undefined"
[ -n "${stale// /}" ] && echo "  removed stale generated definition(s) for role(s) no longer in aiDlcRoles:${stale}"
# rc is 1 here only when a model key resolved to nothing, which the stderr line above named.
exit "$rc"
}
[ "${BASH_SOURCE[0]}" = "$0" ] || return 0
rad_main "$@"
