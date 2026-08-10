#!/bin/bash
# AI/DLC Installation Script
# Copies core files into a target project and generates config scaffolding

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="${1:-.}"
AI_DLC_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Read upstream version (semver source of truth)
if [ -f "$AI_DLC_ROOT/VERSION" ]; then
  AI_DLC_VERSION="$(tr -d '[:space:]' < "$AI_DLC_ROOT/VERSION")"
else
  AI_DLC_VERSION="unknown"
fi

# Capture upstream commit sha if installer is running from a git checkout
if git -C "$AI_DLC_ROOT" rev-parse --short HEAD >/dev/null 2>&1; then
  AI_DLC_COMMIT="$(git -C "$AI_DLC_ROOT" rev-parse --short HEAD)"
  if ! git -C "$AI_DLC_ROOT" diff-index --quiet HEAD -- 2>/dev/null; then
    AI_DLC_COMMIT="${AI_DLC_COMMIT}-dirty"
  fi
else
  AI_DLC_COMMIT="unknown"
fi

INSTALL_TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

echo "AI/DLC Installer"
echo "================"
echo "Version: $AI_DLC_VERSION ($AI_DLC_COMMIT)"
echo "Target project: $PROJECT_ROOT"
echo ""

# Verify target exists
if [ ! -d "$PROJECT_ROOT" ]; then
  echo "Error: Target directory $PROJECT_ROOT does not exist"
  exit 1
fi

# Verify BMAD is installed
if [ ! -d "$PROJECT_ROOT/_bmad" ]; then
  echo "Warning: BMAD Method not detected in target project."
  echo "AI/DLC requires BMAD Method v6 (npx bmad-method install)."
  echo "Install BMAD first, then re-run this script."
  exit 1
fi

# Verify jq (required for settings.json merge and hook scripts)
if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required but not found on PATH."
  echo "Install jq from your package manager (e.g. apt, dnf, pacman,"
  echo "apk, brew, choco) or https://jqlang.github.io/jq/download/"
  exit 1
fi

# Create directories
echo "Creating directories..."
mkdir -p "$PROJECT_ROOT/.claude/skills/ai-dlc/steps"
mkdir -p "$PROJECT_ROOT/.claude/skills/ai-dlc-setup"
mkdir -p "$PROJECT_ROOT/.claude/skills/ai-dlc-update/reconcile"
mkdir -p "$PROJECT_ROOT/.claude/team-roles"
mkdir -p "$PROJECT_ROOT/docs"
mkdir -p "$PROJECT_ROOT/docs/ai-dlc-patterns"
mkdir -p "$PROJECT_ROOT/docs/escalations"
mkdir -p "$PROJECT_ROOT/docs/reviews"
mkdir -p "$PROJECT_ROOT/docs/retro"
mkdir -p "$PROJECT_ROOT/_bmad-output/implementation-artifacts"
# NO stories/ DIRECTORY IS SCAFFOLDED, and its absence is the correct state rather than an
# omission. Under artifact-path-grammar.md the corpus lives at `planning-artifacts/s<N>/stories/`,
# so there is no sprint-independent directory to create — and creating one for a guessed sprint
# would scaffold a home the pipeline then has to be told to ignore. The step that writes the first
# story creates it. Check 6 reports an empty corpus as a SKIP, which is what a project before its
# first story is.
mkdir -p "$PROJECT_ROOT/_bmad-output/planning-artifacts"

# Archive existing files that AI/DLC will replace, BEFORE any overwrite.
# Each install gets a timestamped archive so previous backups aren't clobbered.
#
# Two archive layouts within docs/pre-ai-dlc/$ARCHIVE_TS/:
#   - Flat (archive root): files that /ai-dlc-setup Step 0 reads for
#     project-specific config absorption — CLAUDE.md, QUICKSTART.md,
#     coding-conventions.md, team role files.
#   - _divergence/ (mirrors project-relative paths): files that Step 0 does
#     NOT read but that the export tool needs to diff against installed
#     upstream — skill files, step files, setup skill, pattern files.
#     Preserving directory structure lets the export tool walk the tree
#     with `diff -r`.
ARCHIVED=false
ARCHIVE_TS="$(date +%Y%m%d-%H%M%S)"
ARCHIVE_DIR="$PROJECT_ROOT/docs/pre-ai-dlc/$ARCHIVE_TS"

_ensure_archive_root() {
  if [ "$ARCHIVED" = false ]; then
    mkdir -p "$ARCHIVE_DIR"
    echo "Archiving existing files to docs/pre-ai-dlc/$ARCHIVE_TS/..."
    ARCHIVED=true
  fi
}

# Flat archive — Step 0 absorption targets.
archive_if_exists() {
  local file="$1"
  local basename="$(basename "$file")"
  if [ -f "$file" ]; then
    _ensure_archive_root
    cp "$file" "$ARCHIVE_DIR/$basename"
    echo "  Archived $basename"
  fi
}

# Structured archive — preserves the project-relative path under _divergence/.
archive_tree_file() {
  local file="$1"
  local rel_path="${file#$PROJECT_ROOT/}"
  if [ -f "$file" ]; then
    _ensure_archive_root
    local dest_dir="$ARCHIVE_DIR/_divergence/$(dirname "$rel_path")"
    mkdir -p "$dest_dir"
    cp "$file" "$dest_dir/"
    echo "  Archived $rel_path"
  fi
}

# Archive every file in a directory matching a glob, preserving relative path.
archive_tree_glob() {
  local dir="$1"
  local glob="$2"
  if [ -d "$dir" ]; then
    shopt -s nullglob
    for file in "$dir"/$glob; do
      archive_tree_file "$file"
    done
    shopt -u nullglob
  fi
}

# Flat archive — consumer-owned files that /ai-dlc-setup Step 0 absorbs.
archive_if_exists "$PROJECT_ROOT/CLAUDE.md"
archive_if_exists "$PROJECT_ROOT/QUICKSTART.md"
archive_if_exists "$PROJECT_ROOT/docs/coding-conventions.md"

# Structured archive — ai-dlc-owned files (reference/diff only, NOT absorbed
# by setup). Upstream is authoritative on reinstall; team roles, skills,
# steps, patterns, and hooks are reset to the installed versions and any
# consumer drift lives only under _divergence/ for historical reference.
archive_tree_file "$PROJECT_ROOT/.claude/skills/ai-dlc/SKILL.md"
archive_tree_glob "$PROJECT_ROOT/.claude/skills/ai-dlc/steps" "*.md"
archive_tree_file "$PROJECT_ROOT/.claude/skills/ai-dlc-setup/SKILL.md"
archive_tree_file "$PROJECT_ROOT/.claude/skills/ai-dlc-update/SKILL.md"
archive_tree_glob "$PROJECT_ROOT/.claude/skills/ai-dlc-update/reconcile" "*"
archive_tree_glob "$PROJECT_ROOT/docs/ai-dlc-patterns" "*.md"
archive_tree_glob "$PROJECT_ROOT/.claude/team-roles" "*.md"
archive_tree_glob "$PROJECT_ROOT/.claude/hooks" "ai-dlc-*.sh"
archive_tree_glob "$PROJECT_ROOT/.claude/rules" "ai-dlc-*.md"
archive_tree_file "$PROJECT_ROOT/.claude/settings.json"

if [ "$ARCHIVED" = true ]; then
  echo ""
  echo "  Originals saved to docs/pre-ai-dlc/$ARCHIVE_TS/"
  echo "  The /ai-dlc-setup wizard will absorb your project-specific"
  echo "  content from the most recent archive during configuration."
  echo ""
fi

# Copy core skill files (always overwrite with AI/DLC versions)
echo "Installing AI/DLC skill..."
cp "$SCRIPT_DIR/../core/skills/ai-dlc/SKILL.md" "$PROJECT_ROOT/.claude/skills/ai-dlc/"
cp "$SCRIPT_DIR/../core/skills/ai-dlc/steps/"*.md "$PROJECT_ROOT/.claude/skills/ai-dlc/steps/"
# core skill docs that live at the skill root (not under steps/).
# core-manifest.md is the authoritative core file set: the gate-validation
# Core-layer immutability check, the protected-path-editor role, and the
# ai-dlc-core-guard.sh edit-time hook all READ it from the consumer, so it must
# be present. It is upstream-owned and overwrite-on-pull like the rest.
# enforcement-map.yaml is in this list because validate-gate-adjudication.sh DERIVES
# the escalated check set from it and fails closed (exit 2, "will not guess") when it
# is absent. Without it here, Check 26's enforcer was inert on every fresh install --
# refusing rather than adjudicating, with nothing reporting that it never ran. It
# reached the reference consumer only through the ai-dlc-update pull path, which maps
# the whole skill dir, so the gap was invisible to anyone who had ever pulled.
# THE LIST IS HAND-WRITTEN AND I76 BINDS IT, which is the part that was missing rather
# than the list itself. Deriving it with a glob was tried and reverted: I23 decides which
# skill-root files ship by substring-searching THIS FILE's text, so a glob makes the
# shipped set unreadable to it — and a comment naming a file would then make I23 call
# that file shipped, which is the grep-satisfied-by-a-comment defect one file over.
#
# What I76 asserts instead: every flat file under core/skills/ai-dlc/ either lands in a
# probe install AND is claimed by core_manifest:, or carries a `<name>.not-shipped`
# marker and is claimed by neither. The ship side is measured by RUNNING this loop, so
# the list cannot drift from what it delivers.
for doc in escalations.md rule-authoring.md artifact-path-grammar.md core-manifest.md enforcement-map.yaml layer-contract.yaml; do
  [ -f "$SCRIPT_DIR/../core/skills/ai-dlc/$doc" ] && \
    cp "$SCRIPT_DIR/../core/skills/ai-dlc/$doc" "$PROJECT_ROOT/.claude/skills/ai-dlc/"
done
# Skill templates cited by step files with a skill-root-relative path
# (retro.md's finding-class table). These were previously kept at the dev repo's
# templates/pipeline/ and never copied, so retro.md pointed at a file no consumer
# had. A reader that cannot resolve the pointer applies no finding-class at all
# and nothing reports it -- the same shape as a check whose PASS is identical to
# its never having run.
#
# Upstream-owned and overwrite-on-pull like the rest of core, NOT an additive
# scaffold like extensions/ and overrides/. They sit under core/skills/ai-dlc/,
# so unregistered-drift.sh already scans them (I12 classifies at skill
# granularity): a consumer that adds its own domain finding-classes in place is
# reported and routed to an extensions/ entry, which is Rule 27 working. The
# reference consumer HAS such a copy today, drifted and unmanaged, precisely
# because nothing shipped or tracked this file.
if [ -d "$SCRIPT_DIR/../core/skills/ai-dlc/templates" ]; then
  mkdir -p "$PROJECT_ROOT/.claude/skills/ai-dlc/templates"
  cp "$SCRIPT_DIR/../core/skills/ai-dlc/templates/"*.md \
     "$PROJECT_ROOT/.claude/skills/ai-dlc/templates/" 2>/dev/null || true
fi

# Layered rulebook (Rule 27 / spec §7): consumer-owned extensions/ + overrides/.
# ADDITIVE — create if absent and seed the README contract; NEVER overwrite a
# consumer's populated layer (that is the whole point of the split).
echo "Installing rulebook layer scaffolds (extensions/, overrides/)..."
for layer in extensions overrides; do
  mkdir -p "$PROJECT_ROOT/.claude/skills/ai-dlc/$layer"
  if [ ! -f "$PROJECT_ROOT/.claude/skills/ai-dlc/$layer/README.md" ]; then
    cp "$SCRIPT_DIR/../core/skills/ai-dlc/$layer/README.md" \
       "$PROJECT_ROOT/.claude/skills/ai-dlc/$layer/"
    echo "  $layer/ scaffolded"
  else
    echo "  $layer/ preserved (consumer-owned)"
  fi
done

# The catalog crosswalk table. SCAFFOLDED ONCE, NEVER OVERWRITTEN, and the path is not
# spelled here — it is read from the `consumer_crosswalk_file:` declaration the validator
# reads, so the installer and the reader cannot drift apart. I67 binds them.
#
# It is a separate file rather than a section of extensions/README.md because that README
# is CORE's: the distribution ships it and every pull compares a consumer's copy against
# base, so rows written there read as unregistered core drift. LC-N6 is an ERROR whose only
# compliant output used to be an unregistered edit to upstream's tree.
CROSSWALK_REL="$(sed -n 's/^consumer_crosswalk_file:[[:space:]]*//p' \
  "$SCRIPT_DIR/../core/skills/ai-dlc/layer-contract.yaml" | head -1 | sed 's/[[:space:]]*$//')"
if [ -z "$CROSSWALK_REL" ]; then
  echo "  ERROR: layer-contract.yaml declares no 'consumer_crosswalk_file:' — cannot scaffold the crosswalk table." >&2
  exit 1
fi
mkdir -p "$PROJECT_ROOT/$(dirname "$CROSSWALK_REL")"
if [ ! -f "$PROJECT_ROOT/$CROSSWALK_REL" ]; then
  cp "$SCRIPT_DIR/../core/skills/ai-dlc/templates/crosswalk.md" "$PROJECT_ROOT/$CROSSWALK_REL"
  echo "  $CROSSWALK_REL scaffolded"
else
  echo "  $CROSSWALK_REL preserved (consumer-owned)"
fi

# The ai-dlc machinery inventory. SCAFFOLDED ONCE, NEVER OVERWRITTEN, path read from the
# `consumer_machinery_file:` declaration rather than spelled here, for the reason the
# crosswalk above states and I67 enforces.
MACHINERY_REL="$(sed -n 's/^consumer_machinery_file:[[:space:]]*//p' \
  "$SCRIPT_DIR/../core/skills/ai-dlc/layer-contract.yaml" | head -1 | sed 's/[[:space:]]*$//')"
if [ -z "$MACHINERY_REL" ]; then
  echo "  ERROR: layer-contract.yaml declares no 'consumer_machinery_file:' — cannot scaffold the machinery inventory." >&2
  exit 1
fi
mkdir -p "$PROJECT_ROOT/$(dirname "$MACHINERY_REL")"
if [ ! -f "$PROJECT_ROOT/$MACHINERY_REL" ]; then
  cp "$SCRIPT_DIR/../core/skills/ai-dlc/templates/machinery.md" "$PROJECT_ROOT/$MACHINERY_REL"
  echo "  $MACHINERY_REL scaffolded"
else
  echo "  $MACHINERY_REL preserved (consumer-owned)"
fi

# The PR-class taxonomy the post-merge trunk audit reads. Same rule as the two above:
# scaffolded once, never overwritten, path read from `consumer_pr_class_file:` rather than
# spelled here.
PRCLASS_REL="$(sed -n 's/^consumer_pr_class_file:[[:space:]]*//p' \
  "$SCRIPT_DIR/../core/skills/ai-dlc/layer-contract.yaml" | head -1 | sed 's/[[:space:]]*$//')"
if [ -z "$PRCLASS_REL" ]; then
  echo "  ERROR: layer-contract.yaml declares no 'consumer_pr_class_file:' — cannot scaffold the PR-class taxonomy." >&2
  exit 1
fi
mkdir -p "$PROJECT_ROOT/$(dirname "$PRCLASS_REL")"
if [ ! -f "$PROJECT_ROOT/$PRCLASS_REL" ]; then
  cp "$SCRIPT_DIR/../core/skills/ai-dlc/templates/pr-classes.md" "$PROJECT_ROOT/$PRCLASS_REL"
  echo "  $PRCLASS_REL scaffolded"
else
  echo "  $PRCLASS_REL preserved (consumer-owned)"
fi

# The derivable story-field list `sprint-status.sh derive-stories` reads. Same rule as the
# three above: scaffolded once, never overwritten, path read from the declaration.
STORYF_REL="$(sed -n 's/^consumer_story_fields_file:[[:space:]]*//p' \
  "$SCRIPT_DIR/../core/skills/ai-dlc/layer-contract.yaml" | head -1 | sed 's/[[:space:]]*$//')"
if [ -z "$STORYF_REL" ]; then
  echo "  ERROR: layer-contract.yaml declares no 'consumer_story_fields_file:' — cannot scaffold the derivable story-field list." >&2
  exit 1
fi
mkdir -p "$PROJECT_ROOT/$(dirname "$STORYF_REL")"
if [ ! -f "$PROJECT_ROOT/$STORYF_REL" ]; then
  cp "$SCRIPT_DIR/../core/skills/ai-dlc/templates/story-fields.md" "$PROJECT_ROOT/$STORYF_REL"
  echo "  $STORYF_REL scaffolded"
else
  echo "  $STORYF_REL preserved (consumer-owned)"
fi

# The artifact kinds and areas rule 4 of artifact-path-grammar.md reads. Same rule as the four
# above: scaffolded once, never overwritten, path read from the declaration rather than spelled
# here so the installer and the reader cannot drift apart.
ARTPATH_REL="$(sed -n 's/^consumer_artifact_paths_file:[[:space:]]*//p' \
  "$SCRIPT_DIR/../core/skills/ai-dlc/layer-contract.yaml" | head -1 | sed 's/[[:space:]]*$//')"
if [ -z "$ARTPATH_REL" ]; then
  echo "  ERROR: layer-contract.yaml declares no 'consumer_artifact_paths_file:' — cannot scaffold the artifact kind set." >&2
  exit 1
fi
mkdir -p "$PROJECT_ROOT/$(dirname "$ARTPATH_REL")"
if [ ! -f "$PROJECT_ROOT/$ARTPATH_REL" ]; then
  cp "$SCRIPT_DIR/../core/skills/ai-dlc/templates/artifact-paths.md" "$PROJECT_ROOT/$ARTPATH_REL"
  echo "  $ARTPATH_REL scaffolded"
else
  echo "  $ARTPATH_REL preserved (consumer-owned)"
fi

# Copy setup skill (always overwrite with AI/DLC versions)
echo "Installing setup skill..."
cp "$SCRIPT_DIR/../core/skills/ai-dlc-setup/SKILL.md" "$PROJECT_ROOT/.claude/skills/ai-dlc-setup/"

# Copy update skill + reconcile engine (always overwrite — upstream-owned
# tooling, overwrite-safe: the consumer never edits it. This is the SAME skill
# scripts/bootstrap-update-skill.sh lands additively into an already-diverged
# consumer that predates it; shipping it here means fresh installs get the
# distribution->consumer pull path (ai-dlc-update) from day one.)
echo "Installing update skill..."
cp "$SCRIPT_DIR/../core/skills/ai-dlc-update/SKILL.md" "$PROJECT_ROOT/.claude/skills/ai-dlc-update/"
cp "$SCRIPT_DIR/../core/skills/ai-dlc-update/reconcile/"* "$PROJECT_ROOT/.claude/skills/ai-dlc-update/reconcile/"
# chmod the whole glob, not named scripts: `cp` happens to preserve the source
# mode, so a newly added reconcile script works by luck until it does not.
chmod +x "$PROJECT_ROOT/.claude/skills/ai-dlc-update/reconcile/"*.sh 2>/dev/null || true
echo "  ai-dlc-update installed (skill + reconcile engine)"

# Install team roles (always overwrite with AI/DLC versions)
echo "Installing team roles..."
# Glob over every core role file so new roles (analyst, tea, ux, sm, cis,
# protected-path-editor, and any future additions) install automatically —
# no enumerated list to drift from core/team-roles/.
for role_file in "$SCRIPT_DIR/../core/team-roles/"*.md; do
  cp "$role_file" "$PROJECT_ROOT/.claude/team-roles/"
  echo "  $(basename "$role_file") installed"
done

# Install templates (always overwrite with AI/DLC versions)
echo "Installing templates..."
for tmpl in CLAUDE.md QUICKSTART.md; do
  cp "$SCRIPT_DIR/../templates/$tmpl.template" "$PROJECT_ROOT/$tmpl"
  echo "  $tmpl installed"
done

cp "$SCRIPT_DIR/../templates/coding-conventions.md.template" "$PROJECT_ROOT/docs/coding-conventions.md"
echo "  coding-conventions.md installed"

# Copy pattern files for setup reference (always overwrite with AI/DLC versions)
echo "Installing patterns reference..."
cp "$SCRIPT_DIR/../patterns/"*.md "$PROJECT_ROOT/docs/ai-dlc-patterns/"
echo "  Patterns copied to docs/ai-dlc-patterns/ (reference for /ai-dlc-setup)"

# Install hooks (always overwrite with AI/DLC versions)
echo "Installing hooks..."
mkdir -p "$PROJECT_ROOT/.claude/hooks"
cp "$SCRIPT_DIR/../core/hooks/"*.sh "$PROJECT_ROOT/.claude/hooks/"
chmod +x "$PROJECT_ROOT/.claude/hooks/"*.sh
echo "  hooks installed"

# REPORT the notifier's resolved channel, because the no-channel case is otherwise INVISIBLE.
# ai-dlc-notify.sh is macOS (osascript) and Linux (notify-send); on anything else, or with the
# tool absent, it exits 0 having raised nothing. A hook that silently does nothing is the
# inert-mechanism class this repo keeps shipping, and its stderr at notification time is not
# somewhere an operator looks. This is the one moment they are watching, so it is said here.
# PROBED, never assumed: the answer comes from running the hook that will run later, so a
# platform branch that stops resolving cannot keep reporting that it does.
NOTIFY_HOOK="$PROJECT_ROOT/.claude/hooks/ai-dlc-notify.sh"
if [ -x "$NOTIFY_HOOK" ]; then
  NOTIFY_PROBE="$(bash "$NOTIFY_HOOK" --probe 2>/dev/null)"
  NOTIFY_CHANNEL="$(printf '%s\n' "$NOTIFY_PROBE" | sed -n 's/^channel=//p' | head -1)"
  NOTIFY_PLATFORM="$(printf '%s\n' "$NOTIFY_PROBE" | sed -n 's/^platform=//p' | head -1)"
  case "${NOTIFY_CHANNEL:-none}" in
    none)
      echo "  input-needed notifier: NO desktop channel on ${NOTIFY_PLATFORM:-this platform}."
      echo "    ai-dlc-notify.sh will exit 0 without raising anything. Supported: macOS"
      echo "    (osascript) and Linux with notify-send installed."
      ;;
    *)
      echo "  input-needed notifier: desktop channel = ${NOTIFY_CHANNEL} (${NOTIFY_PLATFORM:-unknown})"
      ;;
  esac
fi

# Install the auto session-chaining driver (operator-run tmux launcher)
mkdir -p "$PROJECT_ROOT/.claude/session-driver"
cp "$SCRIPT_DIR/../core/session-driver/"*.sh "$PROJECT_ROOT/.claude/session-driver/"
chmod +x "$PROJECT_ROOT/.claude/session-driver/"*.sh
echo "  session-driver installed (.claude/session-driver/)"

# Install settings.json
# Fresh project -> copy template. Existing settings.json -> merge in place:
#   * Preserve user-owned permissions, env, mcpServers, etc.
#   * Upsert ai-dlc hook blocks (stale ai-dlc entries from prior installs are
#     stripped before template entries are appended, so reinstalls propagate).
#   * Shallow-merge enabledPlugins; user values win on conflict.
# A block counts as ai-dlc-owned when any inner command references
# .claude/hooks/ai-dlc-*.sh OR the legacy "RULE 3 CONTINUATION MANDATE" echo
# (left over from pre-hook-script versions of this installer).
TEMPLATE_SETTINGS="$SCRIPT_DIR/../templates/settings.json.template"
USER_SETTINGS="$PROJECT_ROOT/.claude/settings.json"

# The merge itself lives in ai-dlc-update's reconcile engine, so install and
# `ai-dlc-update` provably apply the SAME contract. Two copies of this jq is how
# an installed consumer and a reconciled consumer silently diverge.
SETTINGS_MERGE="$SCRIPT_DIR/../core/skills/ai-dlc-update/reconcile/settings-merge.sh"
if [ ! -r "$SETTINGS_MERGE" ]; then
  echo "  Error: missing $SETTINGS_MERGE" >&2
  exit 1
fi

# -----------------------------------------------------------------------------
# AI_DLC_MODEL_ROW -- the context sensor's model row.
#
# The transcript records `claude-opus-4-8` for BOTH the 200K and the 1M variant,
# so ai-dlc-context-sensor.sh cannot read the window size off it. Unset, it
# assumes 200K and self-corrects once it observes a reading no 200K model could
# reach (>= 187,000). Pinning the row skips that one early-reminder session.
#
# We deliberately do NOT ship a default value in the template:
#   * Pinning "200K" would set row_known=1 and DISABLE the self-correction, so a
#     1M project would fire early reminders forever -- worse than unset.
#   * Pinning "1M" on a 200K model would put red (200,000) above that model's
#     compact threshold (187,000), so red would never fire before compaction --
#     the exact failure the ordering invariant exists to prevent.
# Silence is the safe state, so a non-interactive install leaves it unset.
#
# The settings `env` block propagates into hook subprocesses (verified against
# Claude Code 2.1.206), which is how the hook reads this.
# -----------------------------------------------------------------------------
# Ask only when it matters: --check reports model_row_needed=yes exactly when the
# key is absent AND the template wires the sensor.
NEEDED="$(bash "$SETTINGS_MERGE" --consumer "$USER_SETTINGS" --template "$TEMPLATE_SETTINGS" --check 2>/dev/null \
  | sed -n 's/^model_row_needed=//p' | head -1)"
EXISTING_ROW="$(jq -r '.env.AI_DLC_MODEL_ROW // empty' "$USER_SETTINGS" 2>/dev/null || true)"

# Non-interactive callers (CI, `curl | bash`) preset the answer:
#   AI_DLC_MODEL_ROW=1M scripts/install.sh /path/to/project
PRESET_ROW="${AI_DLC_MODEL_ROW:-}"
case "$PRESET_ROW" in
  200K|1M|auto|"") ;;
  *) echo "  Warning: ignoring AI_DLC_MODEL_ROW='$PRESET_ROW' (expected 200K, 1M, or auto)"
     PRESET_ROW="" ;;
esac

CHOSEN_ROW="auto"

if [ -n "$EXISTING_ROW" ]; then
  : # consumer-owned; settings-merge.sh will not touch it
elif [ "$NEEDED" != "yes" ]; then
  : # template does not wire the sensor
elif [ -n "$PRESET_ROW" ]; then
  CHOSEN_ROW="$PRESET_ROW"
elif [ ! -t 0 ]; then
  echo "  AI_DLC_MODEL_ROW unset (non-interactive install)."
  echo "    The context sensor will assume the 200K thresholds and self-correct"
  echo "    once it observes a reading only a larger window could produce."
  echo "    To pin it: re-run with AI_DLC_MODEL_ROW=1M, or set"
  echo "    .env.AI_DLC_MODEL_ROW in .claude/settings.json"
else
  echo ""
  echo "  Context sensor: which context window does this project's model run?"
  echo "    1) 1M    -- e.g. Opus/Sonnet with the 1M context beta enabled"
  echo "    2) 200K  -- the standard context window"
  echo "    3) auto  -- let the sensor infer it (safe; costs one session of"
  echo "                early reminders on a 1M model)"
  printf "  Choose [1/2/3] (default 3): "
  read -r MODEL_ROW_CHOICE </dev/tty || MODEL_ROW_CHOICE=""
  case "$MODEL_ROW_CHOICE" in
    1) CHOSEN_ROW="1M" ;;
    2) CHOSEN_ROW="200K" ;;
    *) CHOSEN_ROW="auto" ;;
  esac
fi

# One call, one contract: merge hooks + (maybe) provision the row, atomically.
# Capture rather than pipe: `cmd | sed` reports sed's exit status, so a failed
# merge would read as a success.
if MERGE_OUT="$(bash "$SETTINGS_MERGE" \
       --consumer "$USER_SETTINGS" \
       --template "$TEMPLATE_SETTINGS" \
       --model-row "$CHOSEN_ROW" 2>&1)"; then
  printf '%s\n' "$MERGE_OUT" | sed 's/^/  /'
else
  printf '%s\n' "$MERGE_OUT" | sed 's/^/  /'
  echo "  Error: failed to merge settings.json. Existing file left untouched."
  echo "  Archived copy at docs/pre-ai-dlc/$ARCHIVE_TS/_divergence/.claude/settings.json"
  exit 1
fi

# Install validation + pipeline scripts (always overwrite with AI/DLC versions)
echo "Installing validation scripts..."
# CORE SCRIPTS LIVE IN THEIR OWN DIRECTORY, AND ONLY CORE SCRIPTS LIVE THERE.
#
# They used to land loose in scripts/, mixed in with the consumer's own, and no
# prefix separates them -- ai-dlc ships `audit-rule-files.sh` while the consumer
# owns `audit-dormant-gates.sh`, `audit-main-since.sh`, `audit-rule-exercise.sh`.
#
# That mattered because the edit-time core guard derives its deny set from
# core-manifest.md, and no glob over a SHARED directory can name our set without
# also naming theirs. So the enforcers -- the scripts every gate's teeth depend
# on -- were the one part of core a consumer could edit in place, and two of them
# had been. The directory boundary is what makes the set expressible in one line:
# `scripts/ai-dlc/*` means exactly ours, which is why the manifest claims the whole
# directory rather than listing its contents (v0.160.0 -- before that it named every
# filename, in two files, with an invariant to keep them honest).
mkdir -p "$PROJECT_ROOT/scripts/ai-dlc"
# DERIVED from core/scripts/, never enumerated. A hand-listed loop ships a new
# validator absent-and-inert on every fresh install while all content
# verification stays green — the list becomes the bug. Unlike the fixture loop
# below (which uninstall.sh must mirror, and which validate-enforcement-map.sh
# I8 binds), nothing pairs with this one, so deriving it is strictly simpler
# than adding a check to guard it.
STALE_CORE_SCRIPTS=()
core_scripts=("$SCRIPT_DIR"/../core/scripts/*)
if [ ! -e "${core_scripts[0]}" ]; then
  echo "  Error: core/scripts/ is empty or missing — refusing to install zero validators."
  echo "  A silent no-op here yields a project whose every check is absent and inert."
  exit 1
fi
for script_path in "${core_scripts[@]}"; do
  [ -f "$script_path" ] || continue
  script="$(basename "$script_path")"
  cp "$script_path" "$PROJECT_ROOT/scripts/ai-dlc/"
  chmod +x "$PROJECT_ROOT/scripts/ai-dlc/$script"
  echo "  ai-dlc/$script installed"
  # MIGRATION, NOT CLEANUP. A pre-0.126.0 consumer has this script loose in
  # scripts/, possibly with local edits (the reference consumer had one). Deleting
  # it here would discard those silently, so the old copy is REPORTED and left in
  # place. Removing it is the operator's call, after they have looked at it.
  if [ -f "$PROJECT_ROOT/scripts/$script" ]; then
    STALE_CORE_SCRIPTS+=("scripts/$script")
  fi
done

# bash 3.2 (macOS default) errors on "${arr[@]}" for an EMPTY array under set -u,
# so the count is tested before the array is ever expanded.
if [ "${#STALE_CORE_SCRIPTS[@]}" -gt 0 ]; then
  echo ""
  echo "  NOTE: ${#STALE_CORE_SCRIPTS[@]} core script(s) remain at the pre-0.126.0 location."
  echo "  They are superseded by scripts/ai-dlc/ and nothing invokes them any more."
  echo "  They were NOT deleted: a consumer that edited one in place (which the old"
  echo "  layout permitted) would lose that change without ever seeing it."
  echo ""
  for s in "${STALE_CORE_SCRIPTS[@]}"; do
    echo "    $s"
  done
  echo ""
  echo "  Diff each against scripts/ai-dlc/ before removing. A difference is a local"
  echo "  edit that belongs upstream as a push candidate, not in the bin."
fi

# Install CI workflow templates (copy only if .github/workflows/ exists)
if [ -d "$PROJECT_ROOT/.github/workflows" ]; then
  echo "Installing CI workflow templates..."
  for wf in validate-retro-compliance.yml validate-ci-gates.yml; do
    if [ -f "$SCRIPT_DIR/../core/ci-templates/$wf" ]; then
      cp "$SCRIPT_DIR/../core/ci-templates/$wf" "$PROJECT_ROOT/.github/workflows/"
      echo "  $wf installed"
    fi
  done
else
  echo "Skipping CI workflows (.github/workflows/ not found)"
  echo "  Copy from ai-dlc/core/ci-templates/ when ready"
fi

# Install the local pre-push gate (always overwrite — upstream-owned).
#
# The FILE is installed automatically; the hook is NOT ENABLED here. Enabling is
# `git config core.hooksPath .githooks`, and it is deliberately left to the operator:
# if the project's layer entries are currently dirty, enabling a blocking hook would
# fail the very next push. A linter that errors on first contact is a linter that gets
# turned off. Install now, enable when clean.
echo "Installing local pre-push gate..."
mkdir -p "$PROJECT_ROOT/.githooks"
cp "$SCRIPT_DIR/../core/git-hooks/pre-push" "$PROJECT_ROOT/.githooks/pre-push"
chmod +x "$PROJECT_ROOT/.githooks/pre-push"
if [ "$(git -C "$PROJECT_ROOT" config core.hooksPath 2>/dev/null)" = ".githooks" ]; then
  echo "  .githooks/pre-push installed (ENABLED)"
else
  echo "  .githooks/pre-push installed (not enabled)"
  echo "  Enable with: git config core.hooksPath .githooks"
  echo "  Check first: bash scripts/ai-dlc/validate-layer-entries.sh"
fi

# Install schemas (always overwrite with AI/DLC versions)
# SKILL_INVOCATION_PROVENANCE v1 lives here and NOWHERE ELSE: validate-provenance-block.sh
# LOADS this file at runtime, and every provenance example an agent is taught is RENDERED
# from it by sync-taught-schema.sh. The reader has no built-in copy and fails closed without
# it -- deliberately, because a reader that falls back to a stale built-in schema is exactly
# the drift this design removed.
echo "Installing schemas..."
mkdir -p "$PROJECT_ROOT/.claude/schemas"
for schema_file in "$SCRIPT_DIR/../core/schemas/"*.json; do
  [ -f "$schema_file" ] || continue
  cp "$schema_file" "$PROJECT_ROOT/.claude/schemas/"
  echo "  $(basename "$schema_file") installed"
done

# Install the unconditional rule files that Claude Code's own loader reads.
#
# THE VERSION FLOOR IS CHECKED, NOT ASSUMED, AND A MISS IS LOUD. `.claude/rules/` did not
# exist before Claude Code 2.0.64. On an older build the directory is written and NOTHING
# READS IT -- the consumer's own audit would score the file CLEAN while it did nothing at
# all, which is this project's named recurring defect. So the floor is resolved here and
# the copy is SKIPPED with a visible warning rather than shipped into a tree that ignores
# it. The rule DUPLICATES SKILL.md Rule 23, so skipping costs nothing a consumer had.
RULES_FLOOR="2.0.64"
CC_VERSION="$(claude --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)"
version_ge() {  # version_ge A B -> 0 iff A >= B
  [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -1)" = "$2" ]
}
echo "Installing rule files..."
if [ -z "$CC_VERSION" ]; then
  echo "  SKIPPED -- could not resolve a Claude Code version from \`claude --version\`."
  echo "  .claude/rules/ requires >= $RULES_FLOOR. Nothing was written: a rules directory on a"
  echo "  build without the loader is read by nothing and reports as installed."
elif ! version_ge "$CC_VERSION" "$RULES_FLOOR"; then
  echo "  SKIPPED -- Claude Code $CC_VERSION is below the $RULES_FLOOR floor for .claude/rules/."
  echo "  Nothing was written. Rule 23 is still carried by SKILL.md, exactly as before."
else
  mkdir -p "$PROJECT_ROOT/.claude/rules"
  for rule_file in "$SCRIPT_DIR/../core/rules/"*.md; do
    [ -f "$rule_file" ] || continue
    cp "$rule_file" "$PROJECT_ROOT/.claude/rules/"
    echo "  $(basename "$rule_file") installed (Claude Code $CC_VERSION)"
  done
fi
# Recorded whether or not the copy happened, so the detector can tell "below floor" from
# "loader present but silent" -- two states that look identical from the tree alone.
printf '%s\n' "${CC_VERSION:-unknown}" > "$PROJECT_ROOT/.claude/.ai-dlc-cc-version"

# Install test fixture templates (always overwrite with AI/DLC versions)
echo "Installing test fixture templates..."
mkdir -p "$PROJECT_ROOT/tests/fixtures"
# THE SHIP LIST IS DERIVED, NOT WRITTEN. Every directory under core/fixtures/ ships
# EXCEPT one carrying a `.dist-only` marker, which is the fixture's own colocated
# declaration that its subject is distribution machinery a consumer does not have.
# The criterion for writing that marker is in CLAUDE.md; the marker's own body states
# why THIS fixture has one, and `validate-enforcement-map.sh` (I74) requires it to be
# non-empty, because a marker with no reason is a decision nobody can audit.
#
# THIS LOOP WAS A HAND-WRITTEN LIST OF 120 NAMES. Adding one fixture cost four edits
# across four files, and the two that were missed at v0.316.0 were found by a failed
# push rather than at authoring time. The list here and uninstall.sh's are the pair that
# disagreed; deriving this one means the disagreement has one fewer side that can drift.
for fixture_dir in $(
  for _fd in "$SCRIPT_DIR/../core/fixtures/"*/; do
    [ -d "$_fd" ] || continue
    [ -f "$_fd.dist-only" ] && continue
    _fn="${_fd%/}"; printf '%s\n' "${_fn##*/}"
  done | sort
); do
  if [ -d "$SCRIPT_DIR/../core/fixtures/$fixture_dir" ]; then
    mkdir -p "$PROJECT_ROOT/tests/fixtures/$fixture_dir"
    cp "$SCRIPT_DIR/../core/fixtures/$fixture_dir/"* "$PROJECT_ROOT/tests/fixtures/$fixture_dir/"
    # chmod the whole glob, not two named scripts -- the same reasoning the reconcile
    # loop above states. `cp` preserves the source mode on a NEW file, so a fixture
    # shipping a third executable works by luck; on an OVERWRITE it keeps the
    # destination's existing mode, which is 0644 forever and silent. That is how a
    # guard once installed inert while every content diff stayed green.
    chmod +x "$PROJECT_ROOT/tests/fixtures/$fixture_dir/"*.sh 2>/dev/null || true
    echo "  $fixture_dir/ installed"
  fi
done

# Create feedback log
if [ ! -f "$PROJECT_ROOT/docs/ai-dlc-feedback.md" ]; then
  cat > "$PROJECT_ROOT/docs/ai-dlc-feedback.md" << 'FEEDBACK'
# AI/DLC Feedback Log

Lessons learned from this project that may be generalizable to the
AI/DLC core framework. Reviewed during retros and periodically
contributed back to the upstream AI/DLC project.

## Format

```
## [Date] [Sprint/Context]
**Pattern:** [Name of the generalizable pattern]
**What happened:** [The incident or discovery]
**Current mitigation:** [What this project added]
**Generalizable?:** YES / NO / MAYBE
**If YES:** [How to generalize — what config would other projects need?]
```
FEEDBACK
  echo "  ai-dlc-feedback.md created (feedback loop log)"
fi

# Write version stamp so consumers can detect drift from upstream
VERSION_STAMP="$PROJECT_ROOT/.claude/.ai-dlc-version"
# Unified stamp schema (v0.17.0+): two independently-advancing versions.
#   version/commit       -> the rulebook (core) merge-base; advanced by an
#                           ai-dlc-update rulebook apply. This is the pull base.
#   skill_version/commit -> the ai-dlc-update tool itself; advanced by its own
#                           autonomous self-update cycle. Read this to know the
#                           installed skill version.
# At install time both pairs equal the installed distribution version.
cat > "$VERSION_STAMP" <<EOF
version: $AI_DLC_VERSION
commit: $AI_DLC_COMMIT
skill_version: $AI_DLC_VERSION
skill_commit: $AI_DLC_COMMIT
installed_at: $INSTALL_TIMESTAMP
upstream: https://github.com/euron8/ai-dlc
EOF
echo "  .claude/.ai-dlc-version stamped (rulebook $AI_DLC_VERSION @ $AI_DLC_COMMIT; skill $AI_DLC_VERSION)"

echo ""
echo "Installation complete!"
echo ""
echo "IMPORTANT: AI/DLC requires these for autonomous execution:"
echo "  export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1"
echo "  claude --dangerously-skip-permissions"
echo ""
echo "Without these, the pipeline will stall at every action waiting"
echo "for manual approval. See QUICKSTART.md for launch function examples."
echo ""
echo "Next steps:"
echo "1. Open Claude Code in your project directory (with the flags above)"
echo "2. Run /ai-dlc-setup for guided configuration (recommended)"
if [ "$ARCHIVED" = true ]; then
echo "   The wizard will absorb content from your archived files"
fi
echo "   Or manually: search for {template_variable} placeholders"
echo "3. Review patterns in docs/ai-dlc-patterns/ for optional enforcement"
echo "4. Run /ai-dlc to start your first pipeline"
