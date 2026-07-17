#!/usr/bin/env bash
# validate-layer-entries.sh — Rule 27 layer hygiene (authoring-time, consumer-side)
#
# Validates the consumer's `extensions/` and `overrides/` entries against the
# entry contracts and against the core files they hook/shadow. Runs entirely
# inside the consumer: it needs NO distribution checkout.
#
# Why this exists (v0.34.0 spec): a full sweep of a real consumer found Rule 27's
# drift safety was not working. Extensions carry no drift anchor; 5 of 12
# overrides had a `base_sha` pointing at a CONSUMER commit, so the pull's
# `git diff <base_sha>..theirs` against the distribution silently failed. Two
# shipped upstream changes were being discarded unseen.
#
# The enabling property (verified 9/9 on the real consumer): a CORRECT base_sha is
# a distribution sha — it resolves in the distribution repo and NOT in the
# consumer repo. A poisoned one resolves in the consumer repo. So poisoning is
# detectable here, with no distribution access.
#
# Usage: validate-layer-entries.sh [project-root]
# Exit:  0 = no errors (warnings may print), 1 = at least one ERROR, 2 = bad usage
#
# SEVERITY IS TIERED ON PURPOSE. ERROR is reserved for mechanized invariants with
# no false-positive path — a linter that errors dozens of times on first contact
# gets disabled, and then catches nothing. Smells that need human judgement are
# WARN.
#
#   ERROR (invariants)
#     E1 override: missing `shadows:`/`base_sha:`, or base_sha not 7-40 hex
#     E2 override: base_sha resolves in the CONSUMER repo -> wrong repo's sha,
#        drift detection silently dead for that entry
#     E3 override: `shadows:` target file does not exist
#     E4 extension: missing `kind:`/`hooks:`/`id:`
#     E5 extension: `hooks:` target file does not exist
#     E6 check extension defines a check NUMBER its hooked core file also defines,
#        with a DIFFERENT title -> a number collision. Both catalogs render into
#        one merged list under one integer, so the bare "Check N" the lead writes
#        into the gate log has no referent. The consumer-catalog namespace was a
#        DECLARATION (gate-validation.md, "Consumer-catalog crosswalk") with no
#        mechanism behind it; this is the mechanism. Scoped to `kind: check`
#        because a check number is committed to the durable audit record.
#
#   WARN (smells — judgement required)
#     W1 extension defines a section number its hooked core file also defines with
#        the SAME title -> a restatement, which Rule 27(c) forbids: the copy cannot
#        drift-check against the original, so it forks silently. WARN, not ERROR,
#        only because a real consumer already carries ten and a linter that errors
#        ten times on first contact gets switched off. They are a retirement
#        worklist. Same-number/different-title in a NON-check extension also lands
#        here (a step number never reaches the audit trail).
#     W2 extension contains restricting language -> an additive entry that
#        RESTRICTS core is an override wearing extension frontmatter
#     W3 a `Step <n>` reference whose anchor is defined NOWHERE in the rendered
#        rulebook (core + every extension + every override). Global on purpose:
#        a step reference legitimately crosses files (SKILL.md cites retro's
#        steps), so per-target resolution false-positives. Anchor collection
#        includes `**7a-post. ...**` bold anchors, not just `### 7a-post.`
#        headings — an override defines one that way.
#
# Rule 26(c) contract — catches: a layer entry silently duplicating, restricting,
# or shadowing a core rule upstream has since changed. False-positive cost: one
# re-confirmation per still-valid override whose core section moved; one WARN per
# deliberate restriction. Remove when: core ships as an immutable package with
# machine-checked layer bindings resolved at load time.

set -uo pipefail

PROJECT_ROOT="${1:-$(pwd)}"
SKILL_DIR="$PROJECT_ROOT/.claude/skills/ai-dlc"
EXT_DIR="$SKILL_DIR/extensions"
OVR_DIR="$SKILL_DIR/overrides"

ERRORS=0
WARNS=0
err()  { printf 'ERROR  %s\n' "$*"; ERRORS=$((ERRORS+1)); }
warn() { printf 'WARN   %s\n' "$*"; WARNS=$((WARNS+1)); }

if [ ! -d "$SKILL_DIR" ]; then
  echo "Not an ai-dlc consumer: $SKILL_DIR not found" >&2
  exit 2
fi

# core/-relative layer target -> consumer path.
# `team-roles/<role>.md` lives OUTSIDE the skill dir; everything else inside.
resolve_target() {
  case "$1" in
    team-roles/*) printf '%s/.claude/%s' "$PROJECT_ROOT" "$1" ;;
    *)            printf '%s/%s' "$SKILL_DIR" "$1" ;;
  esac
}

fm() { # fm <file> <key> -- first frontmatter scalar, trimmed
  awk -v k="$2" '
    NR==1 && $0=="---" { inf=1; next }
    inf && $0=="---"   { exit }
    inf && index($0, k":")==1 { sub("^"k":[[:space:]]*", ""); print; exit }
  ' "$1"
}

# Section anchors a file DEFINES. Both `### 5c. Title` headings and
# `**7a-post. Title**` bold anchors (an override defines 7a-post that way; a
# heading-only scan would report every reference to it as dangling).
#
# The optional `Check ` prefix is NOT cosmetic tolerance. Core wrote one check as
# `### Check 24.` while every other is `### 24.`; a digit-anchored regex skipped
# it, so W1 -- the one check that would have caught the v0.48.0 number collision
# -- was blind to precisely the check that caused it. Match the prefix, strip it,
# and the anchor set is the catalog again.
defined_anchors() {
  [ -f "$1" ] || return 0
  { grep -Eho '^#{2,4}[[:space:]]+(Check[[:space:]]+)?[0-9]+[a-z-]*\.' "$1" 2>/dev/null \
      | sed -E 's/^#+[[:space:]]+(Check[[:space:]]+)?//'
    grep -Eho '^\*\*(Check[[:space:]]+)?[0-9]+[a-z-]*\.' "$1" 2>/dev/null \
      | sed -E 's/^\*\*(Check[[:space:]]+)?//'
  } | sed -E 's/\.$//' | sort -u
}

# Normalized heading TEXT for one anchor. A shared NUMBER is not a shared check:
# core's 24 is "The adversarial cycle CONVERGED", a consumer's 24 is
# "Financial-display ground-truth live-verify". The number cannot tell those apart
# and the title can, which is exactly what the Consumer-catalog crosswalk rule has
# always said (align by title/intent, never by number).
heading_title() { # heading_title <file> <anchor>
  awk -v a="$2" '
    function nrm(s){ s=tolower(s); gsub(/[`*]/,"",s); gsub(/[^a-z0-9]+/," ",s);
                     gsub(/^ +| +$/,"",s); return s }
    $0 ~ ("^#{2,4}[ \t]+(Check[ \t]+)?" a "\\.") || $0 ~ ("^\\*\\*(Check[ \t]+)?" a "\\.") {
      h=$0; sub(/^#+[ \t]+/,"",h); sub(/^\*\*/,"",h); sub(/^Check[ \t]+/,"",h)
      sub("^" a "\\.[ \t]*","",h)
      # Strip the catalog label before normalizing. Left in, "[ext:foo]" becomes part
      # of the title, so a correctly-labelled heading never matches the core title
      # and the RESTATES/collision split misreads.
      gsub(/\[ext:[A-Za-z0-9_.-]+\][ \t]*/, "", h); gsub(/\[core\][ \t]*/, "", h)
      print nrm(h); exit
    }' "$1" 2>/dev/null
}

# Does the heading at <anchor> carry an explicit catalog label?
#
# The label IS the sanctioned fix for a number collision (v0.49.0 crosswalk), so a
# labelled heading must CLEAR the error. It did not: the message told the operator to
# add `[ext:<id>]`, they added it, and the ERROR persisted — a remedy that does not
# remedy. Found by applying this linter's own advice and re-running it.
heading_labelled() { # heading_labelled <file> <anchor>
  awk -v a="$2" '
    $0 ~ ("^#{2,4}[ \t]+(Check[ \t]+)?" a "\\.") || $0 ~ ("^\\*\\*(Check[ \t]+)?" a "\\.") {
      print ($0 ~ /\[ext:[A-Za-z0-9_.-]+\]|\[core\]/) ? "yes" : "no"; exit
    }' "$1" 2>/dev/null
}

# Do two normalized titles name the SAME check? Jaccard over significant tokens,
# OR near-total containment of the shorter title in the longer.
#
# Jaccard alone is set at 0.6, with a stop-list that drops scope suffixes ("gate",
# "only"), because the obvious cheap rule -- share 2 of the first 4 words -- is not
# safe here: consumer "Smoke test evidence (deploy-validate gate only)" and core
# "Smoke test coverage for user-facing changes?" share {smoke, test} and would be
# judged the same check. Acting on that would propose a live deploy-validate check
# for deletion. A loose title match is worse than no title match.
#
# Containment covers the other direction, which jaccard gets wrong: a layer that
# restates a core section and appends a provenance tag ("Local tree freshness
# precondition" vs "... [PI-S259-1 addendum]") is ONE section, but the extra tokens
# drag jaccard under the bar and it reads as a collision. Score the shorter title's
# coverage instead, and the suffix stops mattering. The bar stays at 0.75 so the
# smoke-test pair above (0.4 contained) is still correctly two different checks.
#
# Containment additionally requires the shorter title to carry >=2 significant tokens,
# or it degenerates to 1/1 = 1.00 against any title sharing that one word. This rule is
# byte-identical to `layer-drift.sh` same_section() and MUST stay that way -- the
# `layer-catalog-collision` fixture drives both through the same vectors for that
# reason. Change one, change the other. Full rationale lives beside same_section().
same_title() { # same_title <normA> <normB>
  [ -n "$1" ] && [ -n "$2" ] || return 1
  awk -v A="$1" -v B="$2" '
    BEGIN {
      split("the a an of and for to in on this its only gate gates", s, " ")
      for (i in s) stop[s[i]] = 1
      n = split(A, x, " "); for (i = 1; i <= n; i++) if (!(x[i] in stop)) a[x[i]] = 1
      n = split(B, y, " "); for (i = 1; i <= n; i++) if (!(y[i] in stop)) b[y[i]] = 1
      for (k in a) { na++; u++; if (k in b) inter++ }
      for (k in b) { nb++; if (!(k in a)) u++ }
      if (u == 0 || na == 0 || nb == 0) exit 1
      smaller = (na < nb) ? na : nb
      exit (inter / u >= 0.6 || (smaller >= 2 && inter / smaller >= 0.75)) ? 0 : 1
    }'
}

# What may satisfy a "Step N" reference. The rulebook spells step sections TWO ways:
#
#   route.md            `### Step 0a: Snapshot Integrity Validation`   (word + colon)
#   every other step    `### 2a. Variant-lock evidence`                (number + dot)
#
# `defined_anchors` above only ever harvested the second form, so route.md contributed
# ZERO definitions while its own headings were still scanned as REFERENCES. That made
# "Step 0a" warn as dangling although route.md:53 defines it.
#
# The dangerous half was the other direction. Those references were resolved against a
# global pool that also contained gate-validation.md's CHECK numbers (`### 9.`,
# `### 12.`) -- a different namespace entirely. So a reference to a step that does not
# exist was silently satisfied by a same-numbered gate check. Verified by injecting
# "Step 9" and "Step 12" into route.md: neither step exists, and the check accepted
# both. It could not detect the one thing it exists to detect.
#
# gate-validation.md's numbered sections are CHECKS, and the corpus cites them as
# "Check N" -- never "Step N" (183 "Check" vs 190 "Step", zero cross-uses). So they
# contribute NOTHING to the step namespace, which closes the false negative without
# breaking the legitimate `### 2a.` step-section references.
defined_step_anchors() {
  [ -f "$1" ] || return 0
  # Checks are not steps -- and this must cover the LAYERS too, not just core.
  # gate-validation's extensions/overrides restate its numbered checks (e.g.
  # extensions/checks/gate-validation-push.md defines `### 12.`), so matching only
  # the core filename left the layer copies feeding the step namespace and still
  # masking a dangling "Step 12".
  case "$1" in
    *gate-validation*) return 0 ;;
  esac
  { grep -Eho '^#{2,4}[[:space:]]+Step[ -][0-9]+[a-z-]*' "$1" 2>/dev/null \
      | sed -E 's/^#+[[:space:]]+Step[ -]//'
    defined_anchors "$1"
  } | sort -u
}

layer_files() { [ -d "$1" ] || return 0; find "$1" -type f -name '*.md' ! -name 'README.md' 2>/dev/null | sort; }
rel() { printf '%s' "${1#"$PROJECT_ROOT"/}"; }

# ---------------------------------------------------------------------------
# Pass 1 — overrides (E1, E2, E3)
# ---------------------------------------------------------------------------
echo "== overrides =="
while IFS= read -r f; do
  [ -n "$f" ] || continue
  shadows="$(fm "$f" shadows)"; base_sha="$(fm "$f" base_sha)"

  [ -n "$shadows" ] || err "$(rel "$f"): missing 'shadows:' frontmatter"

  if [ -z "$base_sha" ]; then
    err "$(rel "$f"): missing 'base_sha:' — override-drift cannot be computed for this entry"
  elif ! printf '%s' "$base_sha" | grep -Eq '^[0-9a-f]{7,40}$'; then
    err "$(rel "$f"): base_sha '$base_sha' is not a 7-40 char hex sha"
  elif git -C "$PROJECT_ROOT" rev-parse -q --verify "${base_sha}^{commit}" >/dev/null 2>&1; then
    subj="$(git -C "$PROJECT_ROOT" log -1 --format='%s' "$base_sha" 2>/dev/null | cut -c1-46)"
    err "$(rel "$f"): base_sha '$base_sha' is a CONSUMER commit (\"${subj}\") — it MUST be the DISTRIBUTION sha of the core rule when this override was authored. Override-drift detection is silently dead for this entry."
  fi

  if [ -n "$shadows" ]; then
    tgt="$(printf '%s' "${shadows%%#*}" | tr -d ' ' | sed 's/,.*//')"
    [ -z "$tgt" ] || [ -f "$(resolve_target "$tgt")" ] \
      || err "$(rel "$f"): shadows target '$tgt' does not exist at $(resolve_target "$tgt")"
  fi
done < <(layer_files "$OVR_DIR")

# ---------------------------------------------------------------------------
# Pass 2 — extensions (E4, E5, W1, W2)
# ---------------------------------------------------------------------------
echo "== extensions =="
while IFS= read -r f; do
  [ -n "$f" ] || continue
  kind="$(fm "$f" kind)"; hooks="$(fm "$f" hooks | awk '{print $1}')"; id="$(fm "$f" id)"

  [ -n "$kind" ] || err "$(rel "$f"): missing 'kind:' frontmatter"
  [ -n "$id" ]   || err "$(rel "$f"): missing 'id:' frontmatter"
  if [ -z "$hooks" ]; then
    err "$(rel "$f"): missing 'hooks:' frontmatter"; continue
  fi

  core_path="$(resolve_target "$hooks")"
  if [ ! -f "$core_path" ]; then
    err "$(rel "$f"): hooks target '$hooks' does not exist at $core_path"; continue
  fi

  # E6 / W1 — extension defines a section number its hooked core file also defines.
  #
  # The number alone cannot say WHICH defect this is, and the two need opposite
  # remedies. Split on the title:
  #
  #   different title -> COLLISION. Two unrelated checks now carry one integer in
  #     the merged document, and the lead writes that integer into the gate log.
  #     `Check 24: PASSED` stops having a referent. ERROR for a check extension:
  #     it is a mechanized invariant with no false-positive path, and the number
  #     lands in the durable audit record, which is what makes it dangerous.
  #   same title      -> RESTATEMENT. Rule 27(c) forbids it outright ("An extension
  #     MUST NOT restate ... a core section"): the copy cannot drift-check against
  #     the original, so it silently forks. Still WARN -- a real consumer carries
  #     ten of these, and a linter that errors ten times on first contact is a
  #     linter that gets switched off (see SEVERITY note at the top of this file).
  #     They are the retirement worklist, not a build break.
  #
  # ERROR is scoped to `kind: check`. The same collision exists in steps-domain
  # extensions, but a step number is never committed to evidence -- it is a
  # legibility problem in the rendered pipeline, not a corrupted audit trail.
  core_anchors="$(defined_anchors "$core_path")"
  while IFS= read -r a; do
    [ -n "$a" ] || continue
    printf '%s\n' "$core_anchors" | grep -Fxq -- "$a" || continue

    t_ext="$(heading_title "$f" "$a")"
    t_core="$(heading_title "$core_path" "$a")"

    if [ -n "$t_ext" ] && [ -n "$t_core" ] && ! same_title "$t_ext" "$t_core"; then
      # A labelled heading is the RESOLVED state, not a violation. The integer is
      # still shared, but it is no longer a bare number: `### 25. [ext:foo] …` and
      # `### 25.` in core name their catalogs at the point of use, which is exactly
      # what the crosswalk asks for. Erroring here anyway would mean the linter's own
      # prescribed remedy could never clear the linter.
      if [ "$(heading_labelled "$f" "$a")" = yes ]; then
        continue
      fi
      msg="$(rel "$f"): NUMBER COLLISION on '$a.' — this defines \"$t_ext\" while core '$hooks' defines \"$t_core\" at the same number. Extensions are ADDITIVE, so both render into one merged list under one integer: a bare \"Check $a\" in a gate log, retro, or escalation has no referent. Give this check a catalog-labelled heading (\"### $a. [ext:$id] …\") per the Consumer-catalog crosswalk."
      case "$kind" in
        check) err "$msg" ;;
        *)     warn "$msg" ;;
      esac
    else
      warn "$(rel "$f"): RESTATES core section '$a.' (\"${t_core:-$a}\") from '$hooks'. Rule 27(c): an extension MUST NOT restate a core section — the copy cannot drift-check against the original, so it forks silently and then contradicts it. If this entry only ADDS to the core check, hook it without redefining the number; if it RESTRICTS core, it is an override wearing extension frontmatter and belongs in overrides/ with a base_sha."
    fi
  done < <(defined_anchors "$f")

  # W2 — a restriction in an additive layer is a mis-filed override.
  if grep -Eqi 'only[^.]{0,60}(are|is) valid|is NOT subject to|are the only valid' "$f"; then
    warn "$(rel "$f"): contains restricting language (\"only … are valid\" / \"is NOT subject to\"). An extension ADDS behavior; a restriction on a core rule belongs in overrides/ with a base_sha so drift is tracked."
  fi
done < <(layer_files "$EXT_DIR")

# ---------------------------------------------------------------------------
# Pass 3 — W3: step references resolving nowhere in the rendered rulebook
# ---------------------------------------------------------------------------
echo "== step references =="
all_files="$(
  { find "$SKILL_DIR" -maxdepth 1 -name 'SKILL.md';
    find "$SKILL_DIR/steps" -name '*.md' 2>/dev/null;
    find "$PROJECT_ROOT/.claude/team-roles" -name '*.md' 2>/dev/null;
    layer_files "$EXT_DIR"; layer_files "$OVR_DIR"; } 2>/dev/null | sort -u
)"
# A "Step N" reference resolves against STEP definitions only -- never against the
# numbered gate-check anchors. See defined_step_anchors() for what conflating them did.
GLOBAL_STEP_ANCHORS="$(while IFS= read -r f; do [ -n "$f" ] && defined_step_anchors "$f"; done <<< "$all_files" | sort -u)"

while IFS= read -r f; do
  [ -n "$f" ] || continue
  while IFS= read -r ref; do
    [ -n "$ref" ] || continue
    printf '%s\n' "$GLOBAL_STEP_ANCHORS" | grep -Fxq -- "$ref" && continue
    warn "$(rel "$f"): references \"Step $ref\" but no core file, extension, or override defines Step $ref anywhere in the rendered rulebook — dangling step pointer"
  done < <(grep -Eoh 'Step[ -][0-9]+[a-z-]*' "$f" 2>/dev/null | sed -E 's/^Step[ -]//' | sort -u)
done <<< "$all_files"

echo
printf 'validate-layer-entries: %d error(s), %d warning(s)\n' "$ERRORS" "$WARNS"
[ "$ERRORS" -eq 0 ]
