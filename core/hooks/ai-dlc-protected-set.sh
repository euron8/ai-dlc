#!/bin/bash
#
# AI/DLC protected-path set -- a SOURCED library, never a hook.
#
# The ONE list of paths AI/DLC requires to be loaded verbatim. `ai-dlc-protect.sh` sources it to
# deny context-mode consolidation of these paths; the read-intent guard sources it in
# `ai-dlc-recover-gate.sh` (to record a whole Read of one of them, with AI_DLC_PSET_LAZY=1) and in
# `ai-dlc-handoff-entry.sh` (to name the record). All read the same arrays and the same predicate,
# so they can never disagree about what is protected.
#
# Defines, and does nothing else (reads no stdin, never exits; only ps_load_ext_cached writes,
# into the directory its caller names):
#   PROTECTED_PATTERNS, EXCLUDED_PATTERNS  -- core lists, extended by the consumer layer below
#   EXT_JSON, EXT_BAD                       -- the layer file found, and that file when malformed
#   ROOT_SEGMENTS                           -- the literal root segments normalize() cuts on
#   normalize <path>, normalize_to <path> (sets _PS_N, no fork), is_excluded <path>,
#   is_protected <path>, is_protected_norm <normalized path>, ps_load_ext, ps_load_ext_cached <dir>
#
# A caller sources it as a sibling and decides what its absence means: the protect hook fails
# CLOSED (denies every call carrying a path), the read-intent guard fails SILENT.
#
# PROTECTED PATHS: rule files, schemas, pipeline snapshot, gate log, escalations, setup skill,
# audit anchors, sprint status, story files. Consolidation risks pipeline integrity drift.
#
# WHAT IS DELIBERATELY *NOT* PROTECTED. The planning corpus (prd.md, architecture.md,
# product-brief.md, carry-over-backlog.md) is the single largest read surface in the pipeline and
# Rule 24 exists to offload it. It is safe to consolidate because the byte-exactness claims made
# against it are enforced SCRIPT-side, not model-side: `validate-locked-anchor.sh` resolves every
# `full_text_source:` against the SoR file on disk, so a consolidated read cannot forge a passing
# anchor. Artifact ARCHIVES are excluded for the same reason -- see EXCLUDED_PATTERNS.

# -----------------------------------------------------------------------------
# Protected paths (core). A consumer EXTENDS this list through
# extensions/protected-paths.json — see the layer resolution below. Core stays
# project-agnostic on purpose: a consumer that keeps its architecture SoR at
# docs/architecture.md declares that itself rather than shipping one project's
# vocabulary to every other consumer.
# -----------------------------------------------------------------------------

PROTECTED_PATTERNS=(
  ".claude/skills/ai-dlc/*"
  ".claude/skills/ai-dlc-setup/SKILL.md"
  ".claude/team-roles/*.md"
  ".claude/schemas/*.json"
  "CLAUDE.md"
  "*/CLAUDE.md"
  "SKILL.md"
  "docs/coding-conventions.md"
  "docs/escalations/pending.md"
  "_bmad-output/pipeline-snapshot.md"
  "_bmad-output/audit-anchors.md"
  "_bmad-output/implementation-artifacts/gate-log.md"
  "_bmad-output/implementation-artifacts/sprint-status.yaml"
  "_bmad-output/planning-artifacts/sprint-status.yaml"
  # STORY FILES, WHEREVER THEY SIT. Keyed on the reserved `stories/` component
  # rather than a corpus location, so it is TOTAL over both layouts (flat and
  # `s<N>/`) and needs no schema read in a hook that runs on every tool call. It
  # is deliberately WIDER than the declared corpus: a `stories/` directory
  # anywhere is protected. Over-protecting costs native Reads; under-protecting
  # costs pipeline integrity, and only one of those is recoverable. `*` spans `/`
  # in a bash `case` pattern, so this also covers any nesting below.
  "*/stories/*.md"
)

# -----------------------------------------------------------------------------
# Excluded paths — matched FIRST, and a match means allow.
#
# Archives and history files are the retro's analysis corpus: they are read to
# be summarized, which is exactly what consolidation is for. Naming them makes
# it a decision, and keeps the archive allowed once the live file's pattern is
# widened.
# -----------------------------------------------------------------------------

EXCLUDED_PATTERNS=(
  "*.archive.*"
  "*-archive.md"
  "*-archive-*.md"
  "*-history.md"
  "*/pre-ai-dlc/*"
  "*/node_modules/*"
)

# -----------------------------------------------------------------------------
# Consumer layer: extensions/protected-paths.json
#
# A DATA EXTENSION in the sense extensions/README.md defines: consumer-owned
# JSON that the reader owning a core list unions in, with no core edit. Shape:
#
#   { "protected_paths": ["docs/architecture.md"],
#     "excluded_paths":  ["docs/architecture-drafts/*"] }
#
# Both keys optional. A present-but-malformed file sets EXT_BAD, and every
# caller treats every path as protected -- a broken layer file must never
# silently degrade to the core-only list.
# -----------------------------------------------------------------------------

EXT_JSON=""
for _cand in \
  "${CLAUDE_PROJECT_DIR:-.}/.claude/skills/ai-dlc/extensions/protected-paths.json" \
  "${CLAUDE_PROJECT_DIR:-.}/skills/ai-dlc/extensions/protected-paths.json"; do
  if [ -f "$_cand" ]; then EXT_JSON="$_cand"; break; fi
done

EXT_BAD=""
# ps_load_ext: the union, by jq. Run at source time unless the sourcing hook set AI_DLC_PSET_LAZY=1
# first (ai-dlc-recover-gate.sh's read-intent arm, which runs on every tool call and must fork
# nothing for a path it can decide without the layer file); ps_load_ext_cached is that caller's
# entry. Idempotent.
_PS_EXT_LOADED=0
ps_load_ext() {
  local _pl _p _x
  [ "$_PS_EXT_LOADED" = 1 ] && return 0
  _PS_EXT_LOADED=1
  [ -n "$EXT_JSON" ] || return 0
  if jq -e '
        type == "object"
        and ((.protected_paths // []) | type == "array")
        and ((.excluded_paths  // []) | type == "array")
        and ((((.protected_paths // []) + (.excluded_paths // [])) | map(type == "string") | all))
      ' "$EXT_JSON" >/dev/null 2>&1; then
    _pl="$(jq -r '(.protected_paths // [])[]' "$EXT_JSON" 2>/dev/null)" || _pl=""
    while IFS= read -r _p; do
      [ -n "$_p" ] && PROTECTED_PATTERNS+=("$_p")
    done <<< "$_pl"
    _pl="$(jq -r '(.excluded_paths // [])[]' "$EXT_JSON" 2>/dev/null)" || _pl=""
    while IFS= read -r _x; do
      [ -n "$_x" ] && EXCLUDED_PATTERNS+=("$_x")
    done <<< "$_pl"
  else
    EXT_BAD="$EXT_JSON"
  fi
  ps_roots
}
# ps_load_ext_cached <dir>: the same union with no fork while the layer file is unchanged. The
# file is read by the `read` builtin and compared with the copy `<dir>/.pset-ext.raw` holds; on a
# match the patterns come from `<dir>/.pset-ext.lists` (`P <pattern>`, `X <pattern>`, `BAD`). On a
# miss ps_load_ext runs (jq) and both files are rewritten. A cache that cannot be written only
# costs the next call the same jq.
ps_load_ext_cached() {
  local _d="$1" _raw="" _craw="" _l _np _nx _i
  [ "$_PS_EXT_LOADED" = 1 ] && return 0
  [ -n "$EXT_JSON" ] || { _PS_EXT_LOADED=1; return 0; }
  IFS= read -r -d '' _raw < "$EXT_JSON" 2>/dev/null
  if [ -f "$_d/.pset-ext.raw" ] && [ -f "$_d/.pset-ext.lists" ]; then
    IFS= read -r -d '' _craw < "$_d/.pset-ext.raw" 2>/dev/null
    if [ "$_raw" = "$_craw" ]; then
      _PS_EXT_LOADED=1
      while IFS= read -r _l; do
        case "$_l" in
          "P "*) PROTECTED_PATTERNS+=("${_l#P }") ;;
          "X "*) EXCLUDED_PATTERNS+=("${_l#X }") ;;
          BAD) EXT_BAD="$EXT_JSON" ;;
        esac
      done < "$_d/.pset-ext.lists"
      ps_roots
      return 0
    fi
  fi
  _np=${#PROTECTED_PATTERNS[@]}; _nx=${#EXCLUDED_PATTERNS[@]}
  ps_load_ext
  [ -d "$_d" ] || return 0
  {
    [ -n "$EXT_BAD" ] && printf 'BAD\n'
    _i=$_np; while [ "$_i" -lt ${#PROTECTED_PATTERNS[@]} ]; do printf 'P %s\n' "${PROTECTED_PATTERNS[$_i]}"; _i=$((_i + 1)); done
    _i=$_nx; while [ "$_i" -lt ${#EXCLUDED_PATTERNS[@]} ]; do printf 'X %s\n' "${EXCLUDED_PATTERNS[$_i]}"; _i=$((_i + 1)); done
  } > "$_d/.pset-ext.lists" 2>/dev/null && printf '%s' "$_raw" > "$_d/.pset-ext.raw" 2>/dev/null
  return 0
}

# -----------------------------------------------------------------------------
# Normalization
#
# Cut everything before the last known root segment instead of stripping a
# literal $CLAUDE_PROJECT_DIR prefix. The prefix strip failed open on every
# absolute path that did not share the project root's exact spelling (story
# worktrees). Suffix anchoring also absorbs symlinked roots (/tmp vs
# /private/tmp) with no realpath call on a path that may not exist yet.
# -----------------------------------------------------------------------------

# Space-delimited, not an array: bash 3.2 errors on "${arr[@]}" for an EMPTY
# array under `set -u`, and a protect-hook failure is a silent fail-open. Root
# segments never contain spaces, so a string is the shape that cannot fail.
ROOT_SEGMENTS=""
ps_roots() {
  local _p _s
  ROOT_SEGMENTS=""
  for _p in "${PROTECTED_PATTERNS[@]}"; do
    case "$_p" in
      */*) _s="${_p%%/*}" ;;
      *)   continue ;;
    esac
    case "$_s" in *[*?]*) continue ;; esac
    case " $ROOT_SEGMENTS " in *" $_s "*) ;; *) ROOT_SEGMENTS="$ROOT_SEGMENTS $_s" ;; esac
  done
}
ps_roots
[ "${AI_DLC_PSET_LAZY:-}" = 1 ] || ps_load_ext

# normalize_to sets _PS_N with no fork; normalize prints it.
normalize_to() {
  local p="$1" root
  p="${p#./}"
  # shellcheck disable=SC2086
  for root in $ROOT_SEGMENTS; do
    case "$p" in
      */"$root"/*) p="$root/${p##*/"$root"/}"; break ;;
    esac
  done
  # Still absolute and inside the project? Fall back to the literal prefix strip.
  if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
    p="${p#"${CLAUDE_PROJECT_DIR}"/}"
  fi
  _PS_N="$p"
}
normalize() {
  normalize_to "$1"
  printf '%s' "$_PS_N"
}

# -----------------------------------------------------------------------------
# Match against protected patterns
# -----------------------------------------------------------------------------

is_excluded() {
  local path="$1" x
  for x in "${EXCLUDED_PATTERNS[@]}"; do
    # shellcheck disable=SC2254
    case "$path" in
      $x) return 0 ;;
    esac
  done
  return 1
}

is_protected() {
  local path
  path="$(normalize "$1")"
  is_protected_norm "$path"
}

# is_protected_norm <normalized path>: the decision, on a path normalize_to already produced.
is_protected_norm() {
  local path="$1" pattern has_glob=1

  is_excluded "$path" && return 1

  case "$path" in *[*?]*) has_glob=0 ;; esac

  for pattern in "${PROTECTED_PATTERNS[@]}"; do
    # (a) the ordinary case: the path names a protected file.
    # shellcheck disable=SC2254
    case "$path" in
      $pattern) return 0 ;;
    esac

    # (b) a DIRECTORY reference that contains a protected rulebook file.
    # `wc -l .claude/skills/ai-dlc` and ctx_index on `.claude/team-roles` read
    # the whole rulebook while naming no file. Scoped to .claude/ patterns
    # deliberately: a rulebook directory is never legitimately consolidated
    # wholesale, whereas an artifact directory sweep (planning-artifacts/,
    # stories/) is precisely the Rule 24 offload.
    case "$pattern" in
      .claude/*)
        case "$pattern" in
          "$path"/*) return 0 ;;
        esac
        ;;
    esac

    # (c) the path is itself a GLOB that spans a protected file.
    # `cat _bmad-output/implementation-artifacts/gate-log*.md` expands inside
    # the sandbox to include the live gate-log; the literal token does not
    # equal any pattern, so (a) waves it through. Match the other direction.
    if [ "$has_glob" -eq 0 ]; then
      # shellcheck disable=SC2254
      case "$pattern" in
        $path) return 0 ;;
      esac
    fi
  done

  return 1
}
