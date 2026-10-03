#!/bin/bash
# AI/DLC Uninstall Script
# Removes all AI/DLC components from a target project.
# Does NOT remove BMAD Method or _bmad-output/ (planning artifacts are yours).

set -e

# The distribution checkout this script runs from. uninstall.sh is never shipped to a
# consumer, so core/ and templates/ are on disk beside it, and the removal sets for the
# unprefixed shared directories (.claude/schemas/, .claude/rules/) are derived from there
# by basename rather than hand-listed. Absolute, because the caller may pass `.` as root.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AI_DLC_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PROJECT_ROOT="${1:-.}"
FORCE=false

for arg in "$@"; do
  case "$arg" in
    --force) FORCE=true ;;
  esac
done

# Normalize PROJECT_ROOT (strip trailing slash, resolve path)
PROJECT_ROOT="${PROJECT_ROOT%/}"

echo "AI/DLC Uninstaller"
echo "=================="
echo "Target project: $PROJECT_ROOT"
echo ""

# Verify target exists
if [ ! -d "$PROJECT_ROOT" ]; then
  echo "Error: Target directory $PROJECT_ROOT does not exist"
  exit 1
fi

# Verify AI/DLC is installed
if [ ! -f "$PROJECT_ROOT/.claude/skills/ai-dlc/SKILL.md" ]; then
  echo "AI/DLC does not appear to be installed in this project."
  echo "(Expected: .claude/skills/ai-dlc/SKILL.md)"
  exit 1
fi

# Build removal list
echo "The following will be removed:"
echo ""

DIRS_TO_REMOVE=()
FILES_TO_REMOVE=()
KEPT_EDITED=""
KEPT_TUNED=""

# -- Skills --
if [ -d "$PROJECT_ROOT/.claude/skills/ai-dlc" ]; then
  DIRS_TO_REMOVE+=(".claude/skills/ai-dlc/")
fi
if [ -d "$PROJECT_ROOT/.claude/skills/ai-dlc-setup" ]; then
  DIRS_TO_REMOVE+=(".claude/skills/ai-dlc-setup/")
fi
if [ -d "$PROJECT_ROOT/.claude/skills/ai-dlc-update" ]; then
  DIRS_TO_REMOVE+=(".claude/skills/ai-dlc-update/")
fi

# -- Team roles (all AI/DLC role files; team-roles/ is ai-dlc-owned) --
if [ -d "$PROJECT_ROOT/.claude/team-roles" ]; then
  for role_file in "$PROJECT_ROOT/.claude/team-roles/"*.md; do
    [ -f "$role_file" ] || continue
    FILES_TO_REMOVE+=(".claude/team-roles/$(basename "$role_file")")
  done
fi

# -- Hooks (the `ai-dlc-` prefix is the boundary) --
# `.claude/hooks/` is shared: a consumer may keep its own hooks beside ours, and
# core-manifest.md claims only `hooks/ai-dlc-*.sh` for that reason. Remove by prefix and
# never the directory. The prefix, not the set core ships today, so a hook an older install
# copied and core has since retired goes too. A hook left behind stays REGISTERED unless the
# settings.json un-merge below also runs, and a registered hook whose file is gone errors on
# every event it is wired to.
if [ -d "$PROJECT_ROOT/.claude/hooks" ]; then
  for hook_file in "$PROJECT_ROOT/.claude/hooks/"ai-dlc-*.sh; do
    [ -f "$hook_file" ] || continue
    FILES_TO_REMOVE+=(".claude/hooks/$(basename "$hook_file")")
  done
fi

# -- Rule files (the `ai-dlc-` prefix is the boundary, as it is for the hooks above) --
# `.claude/rules/` is NOT ai-dlc-owned the way team-roles/ is: Claude Code reads every
# `.md` there, so a consumer's own authoring rules live alongside ours. Remove by prefix
# and never the directory. Leaving one behind is worse than never shipping it -- an
# unconditional rule keeps loading into EVERY session of a repo that no longer has AI/DLC
# installed, and nothing in that tree would explain where the text came from.
if [ -d "$PROJECT_ROOT/.claude/rules" ]; then
  for rule_file in "$PROJECT_ROOT/.claude/rules/"ai-dlc-*.md; do
    [ -f "$rule_file" ] || continue
    FILES_TO_REMOVE+=(".claude/rules/$(basename "$rule_file")")
  done
fi

# -- Unprefixed core files in shared directories: DERIVED from core/, by basename --
# core/rules/ ships at least one rule WITHOUT the prefix, and core/schemas/ and
# core/session-driver/ carry no naming boundary at all, so no prefix loop can name them.
# install.sh copies each directory's whole glob; the same glob, read from the checkout this
# script runs in, names exactly what install wrote. Only a file core ships by that basename
# is removed, so a consumer's own schema or rule beside ours is never touched. An uninstall
# run from a NEWER checkout than the one installed leaves behind a file the old version
# shipped and the new one dropped -- residue, the safe direction.
#
# A NAME IS NOT PROOF OF AUTHORSHIP. A file whose BYTES differ from core's copy was edited
# after install, or is the consumer's own under a name core also ships, so it is kept and
# listed rather than removed. A byte-identical file is core's, so it goes.
if [ ! -d "$AI_DLC_ROOT/core" ]; then
  echo "  WARNING: $AI_DLC_ROOT/core is absent, so .claude/schemas/, .claude/session-driver/"
  echo "    and unprefixed .claude/rules/ files cannot be derived and are left in place."
fi
for pair in "rules:md" "schemas:json" "session-driver:sh"; do
  sub="${pair%%:*}"; ext="${pair##*:}"
  for core_file in "$AI_DLC_ROOT/core/$sub/"*."$ext"; do
    [ -f "$core_file" ] || continue
    name="$(basename "$core_file")"
    case "$sub:$name" in rules:ai-dlc-*) continue ;; esac   # the prefix loop above has it
    [ -f "$PROJECT_ROOT/.claude/$sub/$name" ] || continue
    if cmp -s "$core_file" "$PROJECT_ROOT/.claude/$sub/$name"; then
      FILES_TO_REMOVE+=(".claude/$sub/$name")
    else
      KEPT_EDITED="$KEPT_EDITED .claude/$sub/$name"
    fi
  done
done

# -- Version stamp --
if [ -f "$PROJECT_ROOT/.claude/.ai-dlc-version" ]; then
  FILES_TO_REMOVE+=(".claude/.ai-dlc-version")
fi

# -- Generated agent definitions --
# install.sh runs render-agent-definitions.sh, which writes one `.claude/agents/<role>.md`
# per pinned role and stamps each with its GENERATED marker. Only a file carrying that
# marker is ours; a consumer's own agent definition is left alone. The marker is READ from
# the renderer rather than restated here, so the two cannot drift; if it cannot be read, no
# agent file is removed and the uninstall says so rather than guessing.
AGENT_GEN_PREFIX="$(sed -n "s/^GEN_PREFIX='\(.*\)'\$/\1/p" \
  "$AI_DLC_ROOT/core/scripts/render-agent-definitions.sh" 2>/dev/null | head -1)"
if [ -d "$PROJECT_ROOT/.claude/agents" ]; then
  if [ -z "$AGENT_GEN_PREFIX" ]; then
    echo "  WARNING: the GENERATED marker could not be read from core/scripts/render-agent-definitions.sh,"
    echo "    so no .claude/agents/ file is removed. Delete generated role definitions by hand."
  else
    for agent_file in "$PROJECT_ROOT/.claude/agents/"*.md; do
      [ -f "$agent_file" ] || continue
      grep -qF -- "$AGENT_GEN_PREFIX" "$agent_file" || continue
      FILES_TO_REMOVE+=(".claude/agents/$(basename "$agent_file")")
    done
  fi
fi

# -- Templates installed to root --
for file in CLAUDE.md QUICKSTART.md; do
  if [ -f "$PROJECT_ROOT/$file" ]; then
    FILES_TO_REMOVE+=("$file")
  fi
done

# -- Docs installed by AI/DLC --
if [ -f "$PROJECT_ROOT/docs/coding-conventions.md" ]; then
  FILES_TO_REMOVE+=("docs/coding-conventions.md")
fi
if [ -f "$PROJECT_ROOT/docs/ai-dlc-feedback.md" ]; then
  FILES_TO_REMOVE+=("docs/ai-dlc-feedback.md")
fi
if [ -d "$PROJECT_ROOT/docs/ai-dlc-patterns" ]; then
  DIRS_TO_REMOVE+=("docs/ai-dlc-patterns/")
fi

# -- Template backup files (created when install.sh finds existing files) --
for file in docs/ai-dlc-CLAUDE.md.template docs/ai-dlc-QUICKSTART.md.template docs/ai-dlc-coding-conventions.md.template; do
  if [ -f "$PROJECT_ROOT/$file" ]; then
    FILES_TO_REMOVE+=("$file")
  fi
done

# -- Escalations file (only if it's the default empty one) --
if [ -f "$PROJECT_ROOT/docs/escalations/pending.md" ]; then
  FILES_TO_REMOVE+=("docs/escalations/pending.md")
fi

# -- Validation scripts installed by AI/DLC --
# The whole directory, because the whole directory is ours -- that is the point of
# scripts/ai-dlc/, and what core-manifest.md's `scripts/ai-dlc/*` entry claims.
#
# This used to be a hand-list of FOUR names against the full set install.sh ships, so
# an uninstall left almost every core validator behind and reported success. The list
# was the bug, exactly as it was for map_consumer() in v0.55.2, and exactly as the
# manifest's own enumeration of the same directory was until v0.160.0. A directory
# needs no list, and a de-numbered comment cannot go stale the way the last one did.
if [ -d "$PROJECT_ROOT/scripts/ai-dlc" ]; then
  DIRS_TO_REMOVE+=("scripts/ai-dlc")
fi

# -- CI workflows installed by AI/DLC --
for wf in validate-retro-compliance.yml validate-ci-gates.yml; do
  if [ -f "$PROJECT_ROOT/.github/workflows/$wf" ]; then
    FILES_TO_REMOVE+=(".github/workflows/$wf")
  fi
done

# -- Local pre-push gate installed by AI/DLC --
# Paired with install.sh's copy. Note we remove the FILE but never touch
# `core.hooksPath`: the operator set that, not us, and they may point it at hooks of
# their own.
if [ -f "$PROJECT_ROOT/.githooks/pre-push" ]; then
  FILES_TO_REMOVE+=(".githooks/pre-push")
fi

# -- Test fixture templates installed by AI/DLC --
# MUST stay identical to install.sh's fixture loop, or uninstall silently orphans the
# fixtures it does not name. It had already drifted: install shipped nine, this listed
# five. `scripts/validate-enforcement-map.sh` (I8) now asserts the two lists and
# core/fixtures/ agree, so the next fixture cannot be added to one loop only.
for fixture_dir in lib deploy-validate-smoke-classification story-evidence-scaffold review-carry-over-clauses check-1c-bypass check-15-bypass check-17-bypass check-17-counts check-3b-locked-anchor check-23-draft-stamps check-24-adversarial-convergence adversarial-citation escalation-citation extension-check-adoption check-25-steering-conduct check-h1-recursion check-manifest-bypass context-sensor layer-anchor-declaration layer-catalog-collision layer-readopt-gate layer-debt-ledger layer-debt-due-and-discharge handoff-resume-guard divergence-hard-block taught-schema gate-adjudication gate-adjudication-rotate self-update-gate setup-config-drift relabel-theirs-collision known-skills-extension reconcile-blocking-list reconcile-emit-report emit-report-refusal apply-drift-refile apply-drift-after-write apply-restamp-theirs apply-restamp-worklist apply-relabel-noop-row absorbed-specifics-survive escalation-status-vocabulary askuserquestion-citation answer-handoff-routing command-args-citation operator-request-capture request-coverage pause-hook-origin core-write-guard audit-anchors-schema dispatch-model-guard subagent-probe pause-question-in-prose sprint-status-lifecycle route-defect-classification story-provenance implementation-join-yield wait-stale-deliverable validate-mandatory-rules-revive mandatory-rules-clean-tree mandatory-rules-skip-accounting mandatory-rules-snapshot-position check5-anchor-base check-22-spawn-ledger cycle-commits-enforce ledger-reverify ledger-reverify-unfalsifiable ledger-reverify-dist-only-reach ledger-rotate snapshot-archive-rotate snapshot-section-schema resume-whole-read retired-contract-token retired-layer-contract retired-layer-passage retired-layer-token retired-fixture-orphan consumer-machinery-inventory retro-audit-scans retro-branch-behind-main context-mode-protect verdict-pass-content provenance-not-accessible provenance-flagless-default snapshot-evidence-cell inflight-row-shape whole-read-pool core-script-boundary apply-legacy-script-path validator-path-resolution relocation-preclassify preclassify-rename-row ci-gates-resolution shadowed-local-validators h2-attest-scripts-dir gate-remediation-deny gate-repair-record adversarial-shard-merge review-shard-merge remediator-shard-join document-partition gate-series-rung gate-verdict-grep-shape blocker-adjudication-record bmad-invocation-resolve check-31-ac-falsifiability spec-adoption-floor spec-join-integrity layer-qualifier-grain layer-extends-grain layer-retired-id-crosswalk layer-crosswalk-home layer-reference-resolution layer-artifact-path-prescriptions layer-conforms-to layer-entry-unreadable layer-adjudication-tier layer-title-join stray-party-mode-provenance core-paths-audit-diff mutation-red-replay trunk-push-bound trunk-audit-classes story-fields-derive fixture-drivability consumer-suite-pool postcompact-rulebook-recovery gate-resume scope-confirmation snapshot-conservation suppression-lifetime self-update-fixture-log snapshot-supersession-marker readset-skip artifact-path-migration artifact-path-conformance setup-site-drift story-corpus-sprint-slot apply-worklist-rows apply-self-overwrite layer-absorption-retire consolidation-residue apply-machinery-stamp changelog-sprint-slot updater-session-signals artifact-derivations derivation-capture hook-registration-join budget-summary-verdict architecture-index-cell-escaping prepush-worktree-env-scrub retro-compliance-workflow escalation-delivery transient-ignore-block preclassify-mode-bucket fanout-payload-channel fanout-untracked-corpus context-provenance wait-beat-liveness artifact-section-heading-level span-of-containment predicate-reclassification derivation-differential handoff-completion-assertion upstream-routing route-read-required requirements-step architecture-fast-track agent-definition-render write-format-steering-multiformat extract-push-flag-decision fold-architect-ledger-join update-preflight-push foreground-budget-deny ledger-reverify-b ledger-reverify-c ledger-reverify-d push-drain-refusals; do
  if [ -d "$PROJECT_ROOT/tests/fixtures/$fixture_dir" ]; then
    DIRS_TO_REMOVE+=("tests/fixtures/$fixture_dir/")
  fi
done

# -- RETIRED fixture templates: core deleted them or marked them `.dist-only`, and a consumer
# installed before that still has them --
# A separate list, not names in the loop above: I8 binds that loop to core/fixtures/ in both
# directions, so a name core no longer ships fails the push there. These are fixtures an older
# install.sh copied and nothing will copy again; uninstall still owns removing them.
for retired_fixture_dir in notify-hook-channel consumer-machinery-home layer-contract-conformance layer-contract-conformance-b ledger-status-vocabulary release-version-triple self-update-join-gate; do
  if [ -d "$PROJECT_ROOT/tests/fixtures/$retired_fixture_dir" ]; then
    DIRS_TO_REMOVE+=("tests/fixtures/$retired_fixture_dir/")
  fi
done

# Print what we found
for dir in "${DIRS_TO_REMOVE[@]}"; do
  echo "  [dir]  $dir"
done
for file in "${FILES_TO_REMOVE[@]}"; do
  echo "  [file] $file"
done

echo ""
echo "The following will NOT be removed:"
echo "  _bmad/                    (BMAD Method — uninstall separately)"
echo "  _bmad-output/             (your planning/implementation artifacts)"
echo "  docs/reviews/             (your code review output)"
echo "  docs/retro/               (your retrospectives)"
echo "  docs/escalations/         (directory preserved, pending.md removed)"
echo ""

# Confirm
if [ "$FORCE" != true ]; then
  read -p "Proceed with uninstall? [y/N] " confirm
  if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "Aborted."
    exit 0
  fi
fi

echo ""
echo "Removing AI/DLC components..."

# Remove the managed transient-state block from the consumer's .gitignore.
#
# RUNS BEFORE ANY FILE IS REMOVED: its markers come from .claude/schemas/, which the file
# loop below now deletes. Placed after that loop, it would find the schema gone and fall to
# the NOTE branch on every uninstall, leaving the block behind while reporting success.
#
# CUT BY MARKER PAIR, never by matching the rules themselves. A consumer may legitimately have
# written its own rule for one of these paths before installing -- the reference consumer had
# four of them, hand-added -- and a removal keyed on the patterns would delete those too. The
# markers bound exactly what install.sh wrote.
#
# THE MARKERS ARE READ FROM THE INSTALLED SCHEMA, NOT RESTATED HERE. A second copy of the two
# strings is a second thing to drift, and the failure is silent: a stale marker in this file
# leaves the block behind while the uninstall reports success. If the schema is already gone,
# say so rather than guessing.
UNINSTALL_STATE_SCHEMA="$PROJECT_ROOT/.claude/schemas/pipeline-state-paths.json"
CONSUMER_GITIGNORE="$PROJECT_ROOT/.gitignore"
if [ -f "$CONSUMER_GITIGNORE" ]; then
  if [ -f "$UNINSTALL_STATE_SCHEMA" ] && command -v jq >/dev/null 2>&1; then
    UIG_BEGIN="$(jq -r '.block_begin' "$UNINSTALL_STATE_SCHEMA")"
    UIG_END="$(jq -r '.block_end' "$UNINSTALL_STATE_SCHEMA")"
    if grep -qxF -- "$UIG_BEGIN" "$CONSUMER_GITIGNORE"; then
      awk -v b="$UIG_BEGIN" -v e="$UIG_END" '
        $0 == b { skip = 1; next }
        skip == 1 && $0 == e { skip = 0; next }
        skip == 0 { print }
      ' "$CONSUMER_GITIGNORE" > "$CONSUMER_GITIGNORE.ai-dlc-new"
      mv "$CONSUMER_GITIGNORE.ai-dlc-new" "$CONSUMER_GITIGNORE"
      echo "  Removed AI/DLC transient-state block from .gitignore"
    fi
  else
    echo "  NOTE: .claude/schemas/pipeline-state-paths.json is absent, so the managed"
    echo "    .gitignore block (if present) was left in place. Delete the lines between"
    echo "    the AI/DLC transient pipeline state markers by hand."
  fi
fi

# Un-merge .claude/settings.json: remove exactly what install.sh merged in, nothing else.
#
# RUNS BEFORE the archive restore below, which deletes docs/pre-ai-dlc/ -- the only record of
# what the consumer's settings.json held before AI/DLC touched it.
#
# WHAT install.sh MERGES is settings-merge.sh's contract, and each part is undone its own way:
#   hooks          -- every block the merge's own predicate calls ai-dlc-owned is stripped BY
#                     THAT SCRIPT, driven with an empty template. The predicate is not restated
#                     here: two copies of it is how install and uninstall would disagree about
#                     which blocks are ours. A consumer's own blocks, in any event, survive.
#                     Event keys and the `hooks` object left EMPTY by the strip are dropped.
#   aiDlcModels, aiDlcRoles
#                  -- per ENTRY, the grain the merge writes at (a consumer role entry replaces
#                     the shipped one whole). An entry is removed only when it still equals the
#                     template's entry AND the pre-install settings.json lacked it. A tuned
#                     entry -- a role pinned to another model, say -- is consumer data: it is
#                     KEPT and named in the closing listing. Uninstall never destroys consumer
#                     configuration by default.
#   every other template key (enabledPlugins entries, env entries, bashOutputMaxChars)
#                  -- SHARED, and the merge is "user wins", so the installed file cannot say
#                     who set one. A key is removed only when it still equals the template
#                     value AND the consumer's pre-install settings.json lacked it. The
#                     pre-install file is the one install.sh archived under the OLDEST
#                     docs/pre-ai-dlc/<ts>/_divergence/; no archived copy means install.sh
#                     created the file. A consumer that set one of these values itself before
#                     installing keeps it. (A reinstall over a first install that found no
#                     settings archives the POST-install file, so its template values survive:
#                     residue, the safe direction.)
# If nothing the consumer wrote remains and install.sh created the file, the file goes.
SETTINGS_FILE="$PROJECT_ROOT/.claude/settings.json"
SETTINGS_MERGE="$AI_DLC_ROOT/core/skills/ai-dlc-update/reconcile/settings-merge.sh"
SETTINGS_TEMPLATE="$AI_DLC_ROOT/templates/settings.json.template"
if [ -f "$SETTINGS_FILE" ]; then
  if ! command -v jq >/dev/null 2>&1 || [ ! -r "$SETTINGS_MERGE" ] || [ ! -r "$SETTINGS_TEMPLATE" ]; then
    echo "  WARNING: jq, $SETTINGS_MERGE or $SETTINGS_TEMPLATE is unavailable, so"
    echo "    .claude/settings.json was NOT un-merged. Its AI/DLC hook registrations now point at"
    echo "    removed files; delete every block naming .claude/hooks/ai-dlc-*.sh by hand."
  else
    UM_DIR="$(mktemp -d)"
    printf '{}\n' > "$UM_DIR/empty-template.json"
    cp "$SETTINGS_FILE" "$UM_DIR/settings.json"
    PRE_SETTINGS=""
    if [ -d "$PROJECT_ROOT/docs/pre-ai-dlc" ]; then
      OLDEST_ARCHIVE="$(ls -d "$PROJECT_ROOT/docs/pre-ai-dlc"/*/ 2>/dev/null | sort | head -1)"
      if [ -n "$OLDEST_ARCHIVE" ] && [ -f "${OLDEST_ARCHIVE}_divergence/.claude/settings.json" ]; then
        PRE_SETTINGS="${OLDEST_ARCHIVE}_divergence/.claude/settings.json"
      fi
    fi
    if [ -n "$PRE_SETTINGS" ]; then cp "$PRE_SETTINGS" "$UM_DIR/pre.json"; else printf 'null\n' > "$UM_DIR/pre.json"; fi
    if bash "$SETTINGS_MERGE" --consumer "$UM_DIR/settings.json" --template "$UM_DIR/empty-template.json" >/dev/null 2>&1 \
       && jq --slurpfile tmpl "$SETTINGS_TEMPLATE" --slurpfile pre "$UM_DIR/pre.json" '
            ($tmpl[0]) as $t | ($pre[0]) as $p |
            def pre_lacks($k): ($p == null) or (($p | try getpath($k) catch null) == null);
            reduce ("aiDlcModels", "aiDlcRoles") as $ns (.;
                reduce (($t[$ns] // {}) | keys[]) as $e (.;
                  if (.[$ns] | type) == "object" and (.[$ns] | has($e))
                     and .[$ns][$e] == $t[$ns][$e] and pre_lacks([$ns, $e])
                  then del(.[$ns][$e]) else . end)
                | if (.[$ns] | type) == "object" and (.[$ns] | length) == 0 and pre_lacks([$ns])
                  then del(.[$ns]) else . end)
            | reduce ( $t | del(.hooks, .aiDlcModels, .aiDlcRoles)
                       | paths(type != "object") ) as $k (.;
                if ((try getpath($k) catch null) == ($t | getpath($k))) and pre_lacks($k)
                then delpaths([$k]) else . end )
            | if (.hooks | type) == "object"
              then .hooks |= with_entries(select((.value | type) != "array" or (.value | length) > 0))
              else . end
            | with_entries(select(
                ( (.key == "hooks" or .key == "enabledPlugins" or .key == "env")
                  and (.value | type) == "object" and (.value | length) == 0
                  and pre_lacks([.key]) ) | not))
          ' "$UM_DIR/settings.json" > "$UM_DIR/out.json" 2>/dev/null \
       && jq -e . "$UM_DIR/out.json" >/dev/null 2>&1; then
      if [ -z "$PRE_SETTINGS" ] && [ "$(jq -c . "$UM_DIR/out.json")" = "{}" ]; then
        FILES_TO_REMOVE+=(".claude/settings.json")
        echo "  settings.json held only what install.sh wrote; removing it"
      else
        KEPT_TUNED="$(jq -r '["aiDlcModels","aiDlcRoles"][] as $ns
            | (.[$ns] // {}) | if type == "object" then keys[] | "\($ns).\(.)" else $ns end' \
            "$UM_DIR/out.json" 2>/dev/null | tr '\n' ' ')"
        mv "$UM_DIR/out.json" "$SETTINGS_FILE"
        echo "  Un-merged AI/DLC hooks and config from .claude/settings.json (your own entries kept)"
      fi
    else
      echo "  WARNING: the settings.json un-merge failed, so the file was left untouched. Its"
      echo "    AI/DLC hook registrations now point at removed files; delete them by hand."
    fi
    rm -f "$UM_DIR/empty-template.json" "$UM_DIR/settings.json" "$UM_DIR/pre.json" "$UM_DIR/out.json"
    rmdir "$UM_DIR" 2>/dev/null || true
  fi
fi

# Remove directories
for dir in "${DIRS_TO_REMOVE[@]}"; do
  rm -rf "$PROJECT_ROOT/$dir"
  echo "  Removed $dir"
done

# Remove files
for file in "${FILES_TO_REMOVE[@]}"; do
  rm -f "$PROJECT_ROOT/$file"
  echo "  Removed $file"
done

# Restore archived originals from the most recent archive
RESTORED=false
ARCHIVE_BASE="$PROJECT_ROOT/docs/pre-ai-dlc"
if [ -d "$ARCHIVE_BASE" ]; then
  # Find the most recent timestamped subdirectory
  LATEST_ARCHIVE="$(ls -d "$ARCHIVE_BASE"/*/ 2>/dev/null | sort | tail -1)"

  # Fall back to the base dir if no subdirectories (legacy format)
  if [ -z "$LATEST_ARCHIVE" ]; then
    LATEST_ARCHIVE="$ARCHIVE_BASE"
  fi

  echo ""
  echo "Restoring archived originals from $(basename "$LATEST_ARCHIVE")..."
  for file in "$LATEST_ARCHIVE"/*; do
    [ -f "$file" ] || continue
    basename="$(basename "$file")"
    case "$basename" in
      CLAUDE.md|QUICKSTART.md)
        cp "$file" "$PROJECT_ROOT/$basename"
        echo "  Restored $basename"
        RESTORED=true
        ;;
      coding-conventions.md)
        mkdir -p "$PROJECT_ROOT/docs"
        cp "$file" "$PROJECT_ROOT/docs/$basename"
        echo "  Restored docs/$basename"
        RESTORED=true
        ;;
      architect.md|code-reviewer.md|dev.md|pm.md|qa.md)
        mkdir -p "$PROJECT_ROOT/.claude/team-roles"
        cp "$file" "$PROJECT_ROOT/.claude/team-roles/$basename"
        echo "  Restored .claude/team-roles/$basename"
        RESTORED=true
        ;;
    esac
  done
  rm -rf "$ARCHIVE_BASE"
  echo "  Removed docs/pre-ai-dlc/ archive directory"
fi

# Clean up empty directories (don't remove if they still have content)
# Children before parents: `.claude` can only go once every subdirectory above it has.
for dir in .claude/skills .claude/team-roles .claude/hooks .claude/rules .claude/schemas .claude/session-driver .claude/agents .claude docs/escalations docs; do
  if [ -d "$PROJECT_ROOT/$dir" ] && [ -z "$(ls -A "$PROJECT_ROOT/$dir")" ]; then
    rmdir "$PROJECT_ROOT/$dir"
    echo "  Removed empty directory $dir/"
  fi
done

echo ""
echo "Uninstall complete."
echo ""
if [ "$RESTORED" = true ]; then
  echo "Restored original files from pre-ai-dlc archive."
fi
echo "Preserved:"
echo "  - _bmad-output/ (your planning artifacts)"
echo "  - docs/reviews/ (your code review output)"
echo "  - docs/retro/ (your retrospectives)"
echo "  - Any non-AI/DLC files in .claude/"
if [ -n "${KEPT_TUNED// /}" ]; then
  echo "  - Consumer-tuned AI/DLC configuration left in place in .claude/settings.json"
  echo "    (it differs from what install.sh wrote, or predates the install):"
  for k in $KEPT_TUNED; do echo "      $k"; done
fi
if [ -n "${KEPT_EDITED// /}" ]; then
  echo "  - Files that share a name with an AI/DLC file but differ from it (edited after"
  echo "    install, or your own), left in place:"
  for k in $KEPT_EDITED; do echo "      $k"; done
fi
echo ""
echo "To also remove BMAD Method: rm -rf _bmad/"
echo "To remove planning artifacts: rm -rf _bmad-output/"
