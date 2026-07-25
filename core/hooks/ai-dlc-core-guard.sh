#!/usr/bin/env bash
#
# AI/DLC Core-Layer Write Guard  (PreToolUse: Edit | Write | MultiEdit)
#
# Makes it STRUCTURALLY IMPOSSIBLE for a layered consumer to edit an
# upstream-owned CORE file in place. A denied edit is routed to the layer it
# belongs in: an `overrides/` entry (shadowing a core rule/check) or an
# additive `extensions/` entry. This is the edit-time complement to
# `ai-dlc-update`'s reconcile engine: it PREVENTS the in-place core drift that
# `reconcile/apply.sh` otherwise has to clean up after. Once core is never
# writable in place, a pull's core files are always clean UPSTREAM-ONLY applies
# and the irreducibly-semantic BOTH-CHANGED-on-core prose merge becomes rare by
# design.
#
# CONTRACT
#   Active ONLY on a LAYERED CONSUMER — the project has a `.claude/.ai-dlc-version`
#   stamp AND `.claude/skills/ai-dlc/{overrides,extensions}/` dirs. This is the
#   SAME activation gate the retro-gate `core-layer-immutability` check uses. The
#   distribution source repo (no stamp; core lives under core/, not .claude/) and
#   a pre-Phase-2 consumer (no layer dirs) are no-ops.
#
#   DENY iff the target is a core-manifest file AND the write is not a declared
#   `/ai-dlc-setup` config-region fill. The core path set is DERIVED at runtime
#   from `core-manifest.md` (fallback: `reconcile/setup-sites.md`'s I5-synced
#   copy) — never hand-listed in this hook. The config regions come from
#   `reconcile/setup-sites.md`, the SAME data the retro gate and
#   `unregistered-drift.sh` read.
#
#   FAIL-OPEN on any ambiguity: unreadable manifest, path outside the project,
#   unparseable input, absent site data. A false-deny wedges a consumer's
#   pipeline, and an over-broad deny gets the hook turned off — the teeth are
#   precise, positive-match only.
#
#   EXEMPT BY CONSTRUCTION: `ai-dlc-update` / reconcile write core via SHELL
#   (`git show >`, cp, sed) — never the Edit/Write tool — so the entire pull and
#   untangle flow passes untouched. This hook matches only Edit|Write|MultiEdit.
#
# The retro-gate `core-layer-immutability` check remains as a defense-in-depth
# backstop (it catches drift a whole sprint late; this catches it at the keystroke).
#
# INSTALL: wired by templates/settings.json.template (PreToolUse matcher
#   "Edit|Write|MultiEdit"); upserted by reconcile/settings-merge.sh on pull.

set -u

INPUT="$(cat)"

TOOL_NAME="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)"

# Only the file-editing tools are in scope. Bash (the shell writes apply.sh and
# reconcile use) and everything else is not our concern — allow silently.
case "$TOOL_NAME" in
  Edit|Write|MultiEdit) ;;
  *) exit 0 ;;
esac

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

# ---------------------------------------------------------------------------
# Activation gate — layered consumer only. Anything else is a no-op (fail-open).
# ---------------------------------------------------------------------------
[ -f "$PROJECT_DIR/.claude/.ai-dlc-version" ]            || exit 0
[ -d "$PROJECT_DIR/.claude/skills/ai-dlc/overrides" ]   || exit 0
[ -d "$PROJECT_DIR/.claude/skills/ai-dlc/extensions" ]  || exit 0

MANIFEST="$PROJECT_DIR/.claude/skills/ai-dlc/core-manifest.md"
SITES="$PROJECT_DIR/.claude/skills/ai-dlc-update/reconcile/setup-sites.md"

# ---------------------------------------------------------------------------
# Target path -> project-relative.
# ---------------------------------------------------------------------------
TARGET="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
[ -n "$TARGET" ] || exit 0

REL="${TARGET#./}"
case "$REL" in
  "$PROJECT_DIR"/*) REL="${REL#"$PROJECT_DIR"/}" ;;
  /*)
    abs="$(cd "$PROJECT_DIR" 2>/dev/null && pwd)"
    case "$REL" in
      "$abs"/*) REL="${REL#"$abs"/}" ;;
      *) exit 0 ;;                 # absolute path outside the project — not ours
    esac ;;
esac

# ---------------------------------------------------------------------------
# Derive the core path set (globs) from core-manifest.md; fall back to
# setup-sites.md's I5-synced copy. NEVER hand-listed here.
# ---------------------------------------------------------------------------
parse_manifest() {   # <file> -> raw core_manifest entries, one per line
  local f="$1"
  [ -r "$f" ] || return 1
  awk '
    /^core_manifest:[ \t]*$/ { inlist=1; next }
    inlist && /^[ \t]*-[ \t]+/ {
      line=$0
      sub(/^[ \t]*-[ \t]+/, "", line)
      sub(/[ \t]+$/, "", line)
      print line
      next
    }
    inlist && /^[^ \t]/ { inlist=0 }     # dedent (incl. a closing ``` fence) ends the list
  ' "$f"
}

to_consumer_glob() {  # <manifest entry> -> consumer-relative glob
  local e="${1#core/}"                    # setup-sites.md form carries a core/ prefix
  case "$e" in
    team-roles/*)     printf '.claude/%s\n' "$e" ;;
    hooks/*)          printf '.claude/%s\n' "$e" ;;   # hooks live at .claude/hooks/, outside the skill dir
    scripts/*)        printf '%s\n' "$e" ;;           # scripts/ai-dlc/* is at the project root, not under .claude/
    fixtures/*)       printf 'tests/%s\n' "$e" ;;     # install.sh copies core/fixtures/<n>/ to tests/fixtures/<n>/
    session-driver/*) printf '.claude/%s\n' "$e" ;;   # machinery, outside the skill dir
    schemas/*)        printf '.claude/%s\n' "$e" ;;   # machinery, outside the skill dir
    skills/*)         printf '.claude/%s\n' "$e" ;;   # ai-dlc/, ai-dlc-setup/ and ai-dlc-update/ all sit under .claude/skills/
    *)                printf '.claude/skills/ai-dlc/%s\n' "$e" ;;
  esac
}

RAW_ENTRIES="$(parse_manifest "$MANIFEST")"
[ -n "$RAW_ENTRIES" ] || RAW_ENTRIES="$(parse_manifest "$SITES")"
[ -n "$RAW_ENTRIES" ] || exit 0           # no manifest anywhere — fail-open

CORE_GLOBS=()
while IFS= read -r e; do
  [ -n "$e" ] || continue
  CORE_GLOBS+=("$(to_consumer_glob "$e")")
done <<< "$RAW_ENTRIES"

is_core() {
  local p="$1" g
  for g in "${CORE_GLOBS[@]}"; do
    # shellcheck disable=SC2254
    case "$p" in $g) return 0 ;; esac
  done
  return 1
}

# Not a core-manifest file (overrides/, extensions/, source, tests, docs, the
# ai-dlc-setup / ai-dlc-update skills, schemas) — allow. Core hooks ARE in the
# manifest now, so they take the deny path below (with hook-specific routing).
is_core "$REL" || exit 0

# ---------------------------------------------------------------------------
# It IS core. Route it — unless the write is a declared /ai-dlc-setup config
# fill. Without the site manifest we cannot tell a config fill from a rulebook
# edit, so we fail-open rather than risk wedging setup.
# ---------------------------------------------------------------------------
route_and_deny() {
  local reason ctx
  case "$REL" in
    .claude/hooks/*)
      # Hooks are machinery, not rulebook: no overrides/ or extensions/ grain applies.
      reason="${REL} is an upstream-owned CORE hook (Rule 27 core-manifest). Hooks are machinery, not rulebook — there is NO consumer layer for them: no overrides/ shadow and no extensions/ entry applies to a hook. Do NOT edit it in place; the next /ai-dlc-update overwrites core and clobbers the change. To change hook behavior, take the change upstream and pull it with /ai-dlc-update (which writes core through the reconcile engine, not the editor). SOME hooks read an AI_DLC_* settings/env tunable; most do not, so grep this file for AI_DLC_ before assuming one exists. If the behavior you need has no tunable, that is a gap to raise upstream, not a reason to edit the file."
      ctx="AI/DLC core-layer guard: .claude/hooks/*.sh are upstream-owned machinery with no consumer layer. Reconciled by /ai-dlc-update, never hand-edited. If a hook must behave differently, contribute the change upstream; a few hooks also expose an AI_DLC_* tunable, but there is no overrides/ or extensions/ entry for a hook."
      ;;
    scripts/ai-dlc/*)
      # Same grain as hooks: machinery, no overrides/ or extensions/ shadow applies.
      # This is the class that was unguarded until v0.126.0 -- the validators every
      # gate's teeth depend on were the one part of core a consumer could edit in
      # place, because they lived loose in a directory the consumer also owns.
      reason="${REL} is an upstream-owned CORE validator (Rule 27 core-manifest). Scripts are machinery, not rulebook — there is NO consumer layer for them: no overrides/ shadow and no extensions/ entry applies to a validator. Do NOT edit it in place; the next /ai-dlc-update overwrites core and clobbers the change. An edited validator is also a weakened gate: every check that cites it is only as good as the copy on disk. To change its behavior, take the change upstream and pull it with /ai-dlc-update. A MINORITY of validators expose an AI_DLC_* env tunable (grep the file for AI_DLC_ to see whether this one does); if the knob you need does not exist, say so upstream and it gets added — a promised tunable that is not there is how a consumer ends up forking the enforcer instead. If this is YOUR script rather than ours, it is in the wrong directory — scripts/ai-dlc/ is core-owned in its entirety (core-manifest.md claims scripts/ai-dlc/*), so this deny stands whether or not the distribution ships a file by that name; consumer-authored pipeline tooling goes in scripts/ai-dlc-local/, which core never reads, never writes and never overwrites."
      ctx="AI/DLC core-layer guard: scripts/ai-dlc/* are upstream-owned validators with no consumer layer. Reconciled by /ai-dlc-update, never hand-edited — an edited enforcer silently changes what every gate citing it actually checks. Contribute the change upstream; only some validators expose an AI_DLC_* tunable, so grep the file before assuming one. Consumer-authored ai-dlc tooling belongs in scripts/ai-dlc-local/."
      ;;
    tests/fixtures/*)
      # Fixtures are upstream TEST DATA -- neither rulebook nor machinery. You cannot
      # "override" a seed and no extensions/ entry shadows an assertion, so the generic
      # arm's layer routing is actively wrong advice here. And the failure is worse than
      # clobber-on-pull: the markers, counts and deliberately-malformed stanzas IN the
      # file are the payload the assertion beside it reads, so a tidying edit can leave
      # the fixture GREEN while it tests nothing, and nothing downstream can tell a
      # vacated fixture from a working one.
      reason="${REL} is an upstream-owned CORE fixture (Rule 27 core-manifest). A fixture is TEST DATA — not rulebook, not machinery — and NO consumer layer applies: there is no overrides/ shadow for a seed, no extensions/ entry for an assertion, and no AI_DLC_* tunable. Do NOT edit it in place. Two things go wrong if you do. First, the next /ai-dlc-update overwrites core and the change is gone. Second, and worse: a fixture's CONTENT is the input its own assertions read — the stub markers, the anchor counts, the malformed stanzas are the payload, not untidiness — so an edit that looks like a cleanup can VACATE the fixture, leaving it passing while it proves nothing. That is the exact failure fixtures exist to prevent, and nothing downstream can tell a vacated fixture from a working one. If the fixture is wrong, or its assertion is too strict, that is an UPSTREAM defect: take it upstream and pull it with /ai-dlc-update. If this is YOUR test rather than ours, it is in the wrong directory — this fixture directory is core-owned; a consumer's own fixtures go in tests/fixtures/<your-own-name>/, which core never reads, never writes and never overwrites, and which the pre-push suite drives exactly the same way."
      ctx="AI/DLC core-layer guard: tests/fixtures/<core-name>/ is upstream test data with no consumer layer — no overrides/, no extensions/, no AI_DLC_ tunable, so the generic layer-routing advice does not apply. Reconciled by /ai-dlc-update, never hand-edited: a fixture's markers and counts ARE its assertion's input, so editing one can leave it green while it tests nothing. A consumer's own fixtures live in tests/fixtures/<their-own-name>/ and the pre-push suite drives those too. If the core fixture itself is wrong, fix it upstream."
      ;;
    *)
      reason="${REL} is an upstream-owned CORE file (Rule 27 core-manifest); a layered consumer MUST NOT edit it in place — an in-place edit is exactly what makes the next /ai-dlc-update clobber your change or raise a false BOTH-CHANGED conflict. Route it to the layer instead: a change to an EXISTING core rule/check -> an overrides/ entry that shadows it (see .claude/skills/ai-dlc/rule-authoring.md); a NET-NEW consumer rule/check/step -> an additive extensions/ entry (see .claude/skills/ai-dlc/extensions/README.md). To pull an UPSTREAM core change, run /ai-dlc-update — it writes core through the reconcile engine (git show / cp / sed), not the editor, so core stays byte-reconcilable with upstream."
      ctx="AI/DLC core-layer guard: core files are upstream-owned and reconciled by /ai-dlc-update, never hand-edited. Put the change in overrides/ (shadow a core rule) or extensions/ (additive). The retro-gate core-layer-immutability check is the backstop; this hook is the primary. Editing a declared /ai-dlc-setup config region (a team-role model string, a dev/qa ## Ownership block, a deploy/smoke command) is allowed — this deny means the edit fell outside every such region."
      ;;
  esac
  jq -n --arg reason "$reason" --arg ctx "$ctx" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason,
      additionalContext: $ctx
    }
  }'
  exit 0
}

# No site manifest -> cannot assess the config exemption -> fail-open.
[ -r "$SITES" ] || exit 0

# A whole-file overwrite of a core file is never a setup token-fill.
[ "$TOOL_NAME" = "Write" ] && route_and_deny

# setup-sites.md keys sites by `core/<rel>`; map REL back to that key.
core_key() {
  local p="$1"
  case "$p" in
    .claude/team-roles/*)    printf 'core/team-roles/%s'    "${p#.claude/team-roles/}" ;;
    .claude/skills/ai-dlc/*) printf 'core/skills/ai-dlc/%s' "${p#.claude/skills/ai-dlc/}" ;;
    *) return 1 ;;
  esac
}

# Emit this file's declared sites: "SINGLE<TAB>regex" or "BLOCK<TAB>heading<TAB>next".
sites_for() {
  local key="$1"
  awk -v want="$key" -v SQ=\' -v DQ='"' '
    function strip(s,   q){
      sub(/^[ \t]*[a-z_]+:[ \t]*/, "", s)
      sub(/[ \t]+$/, "", s)
      q = substr(s, 1, 1)
      if ((q==SQ || q==DQ) && substr(s, length(s), 1)==q) s = substr(s, 2, length(s)-2)
      return s
    }
    /^[ \t]*-[ \t]+id:/    { infile=0; heading="" }
    /^    file:/           { infile = (strip($0)==want) }
    infile && /^    match:/        { print "SINGLE\t" strip($0) }
    infile && /^    heading:/      { heading = strip($0) }
    infile && /^    next_heading:/ { print "BLOCK\t" heading "\t" strip($0) }
  ' "$SITES"
}

CORE_KEY="$(core_key "$REL")" || route_and_deny
SITE_SPECS="$(sites_for "$CORE_KEY")"

# A core file with NO declared setup site is pure rulebook — always route it.
[ -n "$SITE_SPECS" ] || route_and_deny

# It has config sites. Allow the write iff every replaced (old_string) line lies
# within a declared site region of the CURRENT file. This mirrors the retro
# gate's line-level exemption exactly.
T="$PROJECT_DIR/$REL"
[ -r "$T" ] || exit 0             # can't read current file to locate regions — fail-open

editable_lines() {                # every declared-config line of the current file
  local kind a b
  while IFS="$(printf '\t')" read -r kind a b; do
    case "$kind" in
      SINGLE) awk -v re="$a" '$0 ~ re { print }' "$T" ;;
      BLOCK)  awk -v h="$a" -v nh="$b" '
                !started && index($0,h)==1  { started=1; print; next }
                started  && index($0,nh)==1 { started=0 }
                started                     { print }
              ' "$T" ;;
    esac
  done <<< "$SITE_SPECS"
}

old_strings() {                   # every old_string the write would replace
  case "$TOOL_NAME" in
    Edit)      printf '%s' "$INPUT" | jq -r '.tool_input.old_string // empty' 2>/dev/null ;;
    MultiEdit) printf '%s' "$INPUT" | jq -r '.tool_input.edits[]?.old_string // empty' 2>/dev/null ;;
  esac
}

EDITABLE="$(editable_lines)"
OLD="$(old_strings)"
[ -n "$OLD" ] || exit 0           # nothing concrete to compare — fail-open

while IFS= read -r line; do
  stripped="${line//[$' \t']/}"
  [ -z "$stripped" ] && continue  # blank / whitespace-only context line
  if ! printf '%s\n' "$EDITABLE" | grep -qxF -- "$line"; then
    route_and_deny                # a replaced line is core rulebook, outside every site
  fi
done <<< "$OLD"

# Every replaced line is declared /ai-dlc-setup config — allow the fill.
exit 0
