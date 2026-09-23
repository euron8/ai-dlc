#!/usr/bin/env bash
# reconcile-region: exempt — a remediation action that pulls an unregistered edit INTO the layer system; unregistered-drift.sh is the classifier and it IS in the region.
# register-drift.sh — pull an unregistered in-place core edit INTO the layer system.
#
# `unregistered-drift.sh` finds a core file the consumer edited in place: no override
# entry, no base_sha, invisible to layer-drift.sh, and DELETED without a word by the
# next `apply` (core is upstream-owned and overwritten). Detecting that was half the
# job. Telling the operator "refile the delta as an override with a base_sha" and
# leaving them to hand-author the YAML, pick the anchor, and copy the right section out
# is the other half, undone — and a hand-authored anchor that resolves to no heading is
# how drift detection dies silently (this repo has repointed four such overrides).
#
# This authors the entry, extracts the consumer's own section verbatim, and reverts
# core. The operator confirms and writes the `reason:`; they do not do the surgery.
#
# The `base_sha` is stamped at BASE -- the sha the consumer's text actually forked
# from, not the sha being pulled. If upstream ALSO changed that section in this pull,
# the new entry is immediately reported as HARD-OVERRIDE-DRIFT-SECTION and goes through
# `readopt-override.sh --merge` like any other. Stamping `theirs` here would silently
# claim the consumer had already read upstream's change. It has not.
#
# Usage: register-drift.sh <dist-repo> <base-sha> <consumer-root> <core-rel-path> [--apply]
#          core-rel-path e.g. team-roles/tea.md  |  skills/ai-dlc/steps/retro.md
#        (default: dry-run -- print the override it WOULD write)
# Exit:  0 ok / 1 nothing to register / 2 usage OR refusal -- a section that cannot be
#        classified or accounted for; nothing is written and core is NOT reverted
set -uo pipefail

DIST="${1:?usage: register-drift.sh <dist-repo> <base-sha> <consumer-root> <core-rel-path> [--apply]}"
BASE="${2:?}"
CONSUMER="${3:?}"
REL="${4:?}"
APPLY="${5:-}"

case "$REL" in
  skills/ai-dlc/*) CONS_FILE="$CONSUMER/.claude/skills/ai-dlc/${REL#skills/ai-dlc/}"; SHADOW_TGT="${REL#skills/ai-dlc/}" ;;
  team-roles/*)    CONS_FILE="$CONSUMER/.claude/team-roles/${REL#team-roles/}";       SHADOW_TGT="$REL" ;;
  hooks/*)
    echo "register-drift: $REL is a HOOK. The layer system has no override grain for hooks —" >&2
    echo "  overrides shadow rulebook headings. Keep the consumer hook (accept per-entry) or" >&2
    echo "  upstream the change." >&2
    echo "  If upstream has ALREADY absorbed it, unregistered-drift.sh reports" >&2
    echo "  HARD-CORE-DRIFT-ABSORBED and the remedy is a REVERT, not an override." >&2
    exit 2 ;;
  # THE SECOND NO-GRAIN CASE, and it needs its own name for the same reason hooks does.
  # Overrides live at `.claude/skills/ai-dlc/overrides/` and every one of them shadows a heading
  # in a file inside THAT skill. `ai-dlc-setup` is a second skill and `schemas/` is data with no
  # headings, so neither has anything to shadow. Both are `scan`-marked in I12, so
  # unregistered-drift.sh DOES report them and the report hands the operator the register-drift
  # command below — which used to answer `unrecognized core path`, a message that reads like a
  # typo in the path rather than a structural refusal, on a path the report itself supplied.
  #
  # This list is not free: validate-enforcement-map.sh I31 requires every I12 `scan` subtree to
  # be either registerable above or named here, so a new scan-marked subtree fails the build
  # until someone decides which it is.
  schemas/*|skills/ai-dlc-setup/*)
    echo "register-drift: $REL has NO OVERRIDE GRAIN. The layer system's overrides live at" >&2
    echo "  .claude/skills/ai-dlc/overrides/ and each one shadows a HEADING inside the ai-dlc" >&2
    echo "  skill. A second core skill (ai-dlc-setup) and schema data have no heading to shadow," >&2
    echo "  so there is nothing to refile into. This is structural, not a missing case." >&2
    echo "  Two dispositions, and both are real: keep the consumer's version (accept per-entry —" >&2
    echo "  it re-reports HARD- on every pull, which is the honest cost), or take the change" >&2
    echo "  upstream so the divergence disappears. Reverting destroys the divergence; say so" >&2
    echo "  before anyone chooses it." >&2
    echo "  If upstream has ALREADY absorbed it, unregistered-drift.sh reports" >&2
    echo "  HARD-CORE-DRIFT-ABSORBED and the remedy is a REVERT, not an override." >&2
    exit 2 ;;
  *) echo "register-drift: unrecognized core path: $REL" >&2; exit 2 ;;
esac

CORE="core/${REL}"
[ -f "$CONS_FILE" ] || { echo "register-drift: consumer file absent: $CONS_FILE" >&2; exit 2; }
git -C "$DIST" cat-file -e "${BASE}:${CORE}" 2>/dev/null || { echo "register-drift: $CORE absent at $BASE" >&2; exit 2; }

OVR_DIR="$CONSUMER/.claude/skills/ai-dlc/overrides"
mkdir -p "$OVR_DIR"

# Top-level heading names in the consumer's file.
headings_of() { grep -nE '^#{2,3} ' "$1" | sed 's/:.*#\{2,3\} /:/'; }

# section_of() — the ONE resolver, from lib.sh.
#
# A stricter matcher here does not merely miss a section; it MISFILES it. The resolver
# matches bidirectionally on substrings, so the consumer's `## Escalation Protocol`
# resolves against core's `## Escalation` — a RENAMED section, which is an override. An
# exact matcher finds nothing, concludes core has no such heading, and routes it to
# `extensions/` as an ADDITION. Extensions are additive: core's `Escalation` and the
# consumer's `Escalation Protocol` would then BOTH render, as duplicate and conflicting
# guidance in one document. That shipped, in v0.54.2.
#
# Two resolvers that disagree means the tool and the gate disagree, and the tool wins.
# This used to say "byte for byte" over a hand-copied body; now there is one body.
SELF="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
. "$SELF/lib.sh" || { echo "register-drift: cannot source $SELF/lib.sh" >&2; exit 1; }

# Which sections did the consumer actually change? Only those go in the override —
# an override that restates unchanged core is a fork waiting to happen (Rule 27(c)).
#
# A section whose ONLY difference is a `{token}` template site is NOT a consumer change:
# that is install.sh doing its job. Pulling it into the override would shadow core text
# the consumer never touched, and every future upstream edit to it would be discarded
# unseen. Same asymmetric test unregistered-drift.sh uses — the DIST side must carry the
# token, so a consumer cannot manufacture an exemption by typing "{foo}" into its copy.
#
# THREE ANSWERS, NOT TWO: `yes`, `no`, and `unknown` when the diff did not run -- the discipline
# unregistered-drift.sh's is_unregistered() took for the same shape. The caller reaches this only
# AFTER `[ "$a" = "$b" ]` has shown the sections differ, so the only legitimate `diff` exit is 1
# with at least one hunk. Anything else is a diff that FAILED (a fork refused under load, EAGAIN
# on the process substitution), and the awk below used to print `yes` for an empty stream. `yes`
# means "leave this section out of the override", and the section is then destroyed by the
# revert at the end. Measured with a `diff` shim that exits 2 only for one section: two edited
# sections, Alpha and Beta, the diff failing only for Beta -- rc 0, `skipped: Beta`, the override
# carried Alpha alone, core was reverted, and Beta's edit was gone with no line on stderr.
# The exit status is checked AND the awk refuses an empty stream, because either failure alone
# reaches `yes`. The captured variable loses only diff's trailing newline, which the here-string
# restores.
substitution_only() { # <consumer-section-text> <dist-section-text>
  local d drc
  d="$(diff <(printf '%s\n' "$2") <(printf '%s\n' "$1") 2>/dev/null)"; drc=$?
  if [ "$drc" -ne 1 ] || [ -z "$d" ]; then printf 'unknown'; return 0; fi
  awk '
    /^[0-9]/ { if (hunk && !tok) bad=1; hunk=1; tok=0; next }
    /^</     { if ($0 ~ /\{[a-z_][a-z0-9_]*\}/) tok=1 }
    END      { if (!hunk) { print "unknown"; exit } if (hunk && !tok) bad=1; print (bad ? "no" : "yes") }
  ' <<<"$d"
}

# A refusal names the section and exits 2 BEFORE anything is written or reverted. It is the
# only safe answer here: every path below that proceeds on a guess ends in `git show > core`,
# which deletes whatever the guess left out.
refuse() { echo "register-drift: $1" >&2; echo "  Nothing written; $REL NOT reverted. Re-run; if it repeats, register by hand." >&2; exit 2; }

changed=""
skipped=""
added=""
while IFS= read -r line; do
  h="${line#*:}"
  [ -n "$h" ] || continue
  a="$(section_of "$h" < "$CONS_FILE")"
  b="$(git -C "$DIST" show "${BASE}:${CORE}" | section_of "$h")"

  # A section the CONSUMER has but CORE does not is an ADDITION, not an override.
  #
  # An override shadows an existing core heading; the resolver locates it by heading.
  # Anchor `shadows:` at a heading core never had and the anchor resolves to NOTHING —
  # layer-drift reports OVERRIDE-ANCHOR-UNRESOLVED and drift detection is DEAD for that
  # section, forever, silently. This project has had to repoint four overrides for
  # exactly that, and an earlier cut of THIS script wrote two more (tea.md's
  # `Context Loading` and `Communication`, which core does not define). Additive content
  # belongs in `extensions/`, which is file-hooked and needs no anchor.
  if [ -z "$b" ]; then
    added="${added}${added:+$'\n'}${h}"
    continue
  fi

  [ "$a" = "$b" ] && continue
  # Refused HERE, inside the loop, so a dry run refuses too: a dry run that prints an override
  # missing a section is the preview the operator approves before --apply.
  so="$(substitution_only "$a" "$b")"
  case "$so" in
    yes) skipped="${skipped}${skipped:+, }${h}"; continue ;;
    no)  ;;
    *)   refuse "cannot classify section '${h}': diff did not run" ;;
  esac
  changed="${changed}${changed:+$'\n'}${h}"
done < <(headings_of "$CONS_FILE")

[ -n "$skipped" ] && echo "── skipped (template substitution only, not a consumer change): ${skipped}"
[ -n "$added" ] && echo "── consumer-ONLY sections (core has no such heading) -> extensions/, not overrides/: $(printf '%s' "$added" | tr '\n' ';')"

if [ -z "$changed" ]; then
  echo "register-drift: $REL differs from ${BASE}, but no ## / ### section differs."
  echo "  The delta is outside any heading (frontmatter, preamble, or a token site)."
  echo "  An override anchors to a heading, so this cannot be registered as one. Revert it,"
  echo "  or take it upstream."
  exit 1
fi

n_changed="$(printf '%s\n' "$changed" | grep -c .)"
slug="$(printf '%s' "$REL" | sed 's|/|__|g; s|\.md$||')"
first="$(printf '%s\n' "$changed" | head -1)"
OUT="$OVR_DIR/$(printf '%s' "$slug" | sed 's|skills__ai-dlc__||')__consumer-drift.md"

shadow_line="$SHADOW_TGT#$(printf '%s\n' "$changed" | paste -sd '@' - | sed "s|@|, ${SHADOW_TGT}#|g")"

body="$(printf '%s\n' "$changed" | while IFS= read -r h; do
          [ -n "$h" ] || continue
          section_of "$h" < "$CONS_FILE"; echo
        done)"

render() {
  cat <<EOF
---
shadows: ${shadow_line}
base_sha: ${BASE}
reason: TODO — one line: why this consumer changes the core rule. Registered by register-drift.sh; this text was carried as an UNREGISTERED in-place edit of core/${REL} (no override entry, no base_sha, invisible to layer-drift.sh, and destroyed by the next apply). Content is unchanged from what the consumer was already running; only its registration is new.
---

${body}
EOF
}

if [ "$APPLY" != "--apply" ]; then
  echo "── would write: ${OUT#$CONSUMER/}"
  echo "── would revert: .claude/${REL#skills/ai-dlc/} to ${BASE}"
  echo "── ${n_changed} changed section(s): $(printf '%s' "$changed" | tr '\n' ';')"
  echo ""
  render
  echo ""
  echo "register-drift: DRY RUN. Re-run with --apply to write it."
  exit 0
fi

render > "$OUT"

# Consumer-only sections go to extensions/ — additive, file-hooked, no anchor to break.
# Dropping them would DELETE consumer content when core is overwritten; putting them in
# `shadows:` would create an anchor that resolves to nothing.
if [ -n "$added" ]; then
  case "$REL" in
    team-roles/*) EXT_SUB="roles"; EXT_KIND="role" ;;
    *)            EXT_SUB="steps-domain"; EXT_KIND="step" ;;
  esac
  EXT_DIR="$CONSUMER/.claude/skills/ai-dlc/extensions/$EXT_SUB"
  mkdir -p "$EXT_DIR"
  ext_id="$(printf '%s' "$REL" | sed 's|.*/||; s|\.md$||')-consumer"
  EXT_OUT="$EXT_DIR/${ext_id}.md"
  {
    printf -- '---\nkind: %s\nhooks: %s\nid: %s\n' "$EXT_KIND" "$SHADOW_TGT" "$ext_id"
    printf 'reason: TODO — one line: why this consumer ADDS these sections. Written by register-drift.sh; core defines no heading for them, so they are additive and cannot be an override (an override anchors to a core heading; one that resolves to nothing is drift detection that is silently dead).\n---\n\n'
    printf '%s\n' "$added" | while IFS= read -r h; do
      [ -n "$h" ] || continue
      section_of "$h" < "$CONS_FILE"; echo
    done
  } > "$EXT_OUT"
  echo "EXTENSION   ${EXT_OUT#$CONSUMER/}  ($(printf '%s' "$added" | tr '\n' ';'))"
fi

git -C "$DIST" show "${BASE}:${CORE}" > "$CONS_FILE"

echo "REGISTERED  ${OUT#$CONSUMER/}"
echo "  shadows      : ${shadow_line}"
echo "  base_sha     : ${BASE}  (where the delta forked from, NOT the sha being pulled)"
echo "  core reverted: .claude/${REL#skills/ai-dlc/} restored to ${BASE}"
echo ""
echo "  WRITE THE reason: LINE. It says TODO. An override whose reason nobody stated is"
echo "  one nobody can ever retire — the next pull cannot ask 'does upstream supersede this?'"
echo "  about a reason that was never given."
