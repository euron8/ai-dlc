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
#     W4 extension defines a RULE number its hooked core file also defines with a
#        different title. Exactly W1/E6's defect one namespace over: extensions are
#        additive, so `## Rule 29 -- <consumer thing>` and core's `### Rule 29 --
#        Steering budget` render into one merged rulebook, and "Rule 29" in a gate
#        log, retro finding or dispatch brief has two referents. E6 could never see
#        it: rule headings carry no `[.—]` terminator and the anchor grammar above
#        deliberately matches only check/step ids, so a rule number never reached
#        the collision arm at all. Measured on the reference consumer before
#        shipping: EIGHT live collisions, zero false positives — and six of the
#        eight are BELOW core's highest rule number, so this is not a
#        grew-past-the-ceiling problem, it starts the moment an extension numbers
#        anything. WARN for the same reason W1 is: eight ERRORs on first contact is
#        a linter that gets switched off, and a consumer must never be unable to
#        take a security fix because its own rule catalog needs relabelling.
#     W5 extension ALLOCATES a check or rule number core has NOT allocated, below the
#        reserved consumer band. This is the case E6 and W4 are structurally unable
#        to see, and it is the one that decides whether they ever fire.
#
#        E6/W4 are collision detectors: they join the entry's number against the
#        numbers core defines TODAY. A consumer numbering its own check 33 while
#        core stops at 32 therefore matches nothing and reports clean — until the
#        release where core allocates 33, at which point the collision appears
#        retroactively across every gate log already written. The defect is created
#        at authoring time and detected, if ever, by an unrelated party years later.
#        A detector whose subject set is "numbers core has already taken" can never
#        warn about the number an author is about to take.
#
#        So the fix is a PARTITION, not a better detector: core allocates below
#        BAND_FLOOR, a consumer allocates at or above it, and the collision becomes
#        unrepresentable rather than merely reported. The reserved floor is asserted
#        against core's own catalogs by invariant I45 in validate-enforcement-map.sh,
#        derived from `steps/gate-validation.md` and `SKILL.md` — without that arm
#        this band is a promise core is free to break, which is a declaration with
#        no mechanism.
#
#        SCOPE, and every exclusion below is load-bearing. The predicate fires only
#        on a BARE INTEGER that core does not define:
#          - Suffixed ids (`19b`, `2s`, `4a-bis`, `5c-table`) are excluded. A suffix
#            is an explicit "insert beside core's N" marker; it has no expression in
#            a numeric band and renumbering one to 919 would move it away from the
#            section it exists to sit next to.
#          - Alphabetic ids (`AP`, `VH`, `H1`) are excluded — a band is a numeric
#            partition and cannot order them.
#          - A number core DOES define is excluded, and this is the exclusion that
#            keeps the check honest. An entry deliberately qualifying core's Rule 13
#            shares that integer BECAUSE the integer is the reference; the reference
#            consumer carries four such rules, each declaring itself a tightening of
#            the core rule it names. Those are E6/W4's subject, resolved by the
#            catalog label, and they must never be told to renumber.
#          - Check numbers are scoped to `kind: check`, exactly as E6 is, and for
#            the same stated reason: a step number is a POSITION in an ordered
#            procedure, not an allocation from a namespace, so a step-domain entry
#            hooking `steps/retro.md` at `### 4a-bis.` is placing text, not claiming
#            an id. Renumbering it into the band would reorder the procedure.
#        Rule numbers are not scoped by kind: SKILL.md's rulebook is one global
#        namespace whatever kind of entry writes into it.
#
#        A catalog label does NOT silence this, and that is the one place W5 departs
#        from E6/W4's "a labelled heading is the resolved state". The label resolves
#        an EXISTING collision in the audit record; the band removes the need for a
#        label at all. A labelled squatter is the expected state on first contact —
#        labelling is what core previously told consumers to do — so reporting it is
#        the migration signal, and suppressing it would hide the whole subject set
#        behind the remedy for a different clause.
#
#        WARN, never ERROR. Measured on the reference consumer before shipping: FIVE
#        live subjects (checks 33/34/35, rules 31/32), zero conforming entries
#        reported. The remedy is renumbering, which rewrites the consumer's own
#        durable audit key and needs a crosswalk row per number; blocking a pull on
#        five of them would wedge a consumer out of taking a fix over its own
#        catalog. Core is AT 32 checks and 30 rules, so `Rule 31` is literally the
#        next integer core will allocate — the warning has a live detonation date.
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

# ONE heading normalizer. nrm() was defined identically in two awk programs in this file
# (heading_title and rule_title) and a third copy was about to be added for the anchor-arm check
# below. Two copies of a grammar in one file is the restatement smell I26 names; three is a fork
# waiting to happen, and this normalizer decides whether two headings are THE SAME heading — the
# join every anchor check in this file rests on. It is CONCATENATED onto the front of each awk
# program by adjacent-string quoting, so the remainder of each program stays single-quoted and
# needs no escaping.
#
# ONE copy IN THIS FILE was not enough: reconcile/lib.sh's resolver carried a fourth spelling and
# the pull-time classifier a fifth, so "the same heading" had two answers depending on which tool
# the operator ran. `nrm_awk`, `anchor_arm` and `shadow_parts` below are byte-identical to
# reconcile/lib.sh's and BOUND to them by I40. They are COPIES rather than a source for the
# reason I25 records: core/scripts must not depend on the update skill, and I29 confines
# ai-dlc-update to reconcile/ — so neither may source the other's file, and the binding is an
# assertion instead. Change one, change both; the build fails otherwise.
nrm_awk() {
  cat <<'AWK'
function nrm(s){ s=tolower(s); gsub(/[`*]/,"",s); gsub(/[^a-z0-9]+/," ",s); gsub(/^ +| +$/,"",s); return s }
AWK
}
NRM_FN="$(nrm_awk)"

# core/-relative layer target -> consumer path.
# `team-roles/<role>.md` lives OUTSIDE the skill dir; everything else inside.
resolve_target() {
  case "$1" in
    team-roles/*) printf '%s/.claude/%s' "$PROJECT_ROOT" "$1" ;;
    *)            printf '%s/%s' "$SKILL_DIR" "$1" ;;
  esac
}

# The two anchor helpers below are byte-identical to reconcile/lib.sh's, bound by I40. Their
# rationale lives THERE, at the single home, so that reading one copy does not teach a reader
# something the other copy no longer does. Do not paraphrase it back into this file.
anchor_arm() { # anchor_arm <anchor>  < stream  -> FORWARD | REVERSE:<heading> | NONE
  awk -v want="$1" "$(nrm_awk)"'
    BEGIN { w = nrm(want); res = "NONE" }
    /^#{2,6}[ \t]/ {
      h = $0; sub(/^#+[ \t]+/, "", h); hn = nrm(h)
      if (hn == "") next
      if (w != "" && index(hn, w) > 0) { print "FORWARD"; found = 1; exit }
      # length > 3 mirrors span_of: a heading of three characters or fewer
      # contains-matches almost anything, which is noise rather than a finding.
      if (length(hn) > 3 && w != "" && index(w, hn) > 0 && res == "NONE") res = "REVERSE:" h
    }
    END { if (!found) print res }
  '
}

unquote() { # unquote <value>
  case "$1" in
    "'"*"'") printf '%s' "${1#\'}" | sed "s/'\$//" ;;
    '"'*'"') printf '%s' "${1#\"}" | sed 's/"$//' ;;
    *)       printf '%s' "$1" ;;
  esac
}

shadow_parts() { # shadow_parts <shadows-value>  -> one `<file>\t<anchor>` line per comma-part
  awk -v s="$1" '
    BEGIN {
      n = split(s, p, ",")
      for (i = 1; i <= n; i++) {
        part = p[i]; gsub(/^[ \t]+|[ \t]+$/, "", part)
        if (part == "") continue
        h = index(part, "#")
        if (h > 0) { f = substr(part, 1, h - 1); a = substr(part, h + 1) }
        else       { f = part; a = "" }
        gsub(/[ \t]+$/, "", f); gsub(/^[ \t]+|[ \t]+$/, "", a)
        if (f != "") last = f; else f = last
        print f "\t" a
      }
    }
  ' < /dev/null
}

fm() { # fm <file> <key> -- first frontmatter scalar, trimmed
  awk -v k="$2" '
    NR==1 && $0=="---" { inf=1; next }
    inf && $0=="---"   { exit }
    inf && index($0, k":")==1 { sub("^"k":[[:space:]]*", ""); print; exit }
  ' "$1"
}

# Does the frontmatter block CLOSE? Nothing asked before, and the omission hid a real
# entry: fm() is deliberately tolerant -- finding no closing `---`, it scans to EOF for
# `key:` and returns it -- so an entry whose block never closes still yields its
# shadows/base_sha and passes every other check here. It reports zero errors while its
# BODY is not a body at all: the text sits inside the YAML block, where the `### …`
# heading that carries the override is read as a comment.
#
# Only the opened-but-never-closed shape is an error here. A file with no frontmatter
# at all is already caught, loudly, by the missing-key checks below.
# NB: `exit` inside a rule still runs END, and an `exit` there overrides the status --
# so the state must be carried in a flag and decided once, in END. Writing the rc
# directly in the rules made this always-true, and it read as the trap passing.
fm_unterminated() { # fm_unterminated <file> -- rc 0 when `---` opens and never closes
  awk '
    NR==1 && $0!="---" { nofm=1; exit }
    NR>1  && $0=="---" { closed=1; exit }
    END { exit (nofm || closed) ? 1 : 0 }
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
#
# A bold ANCHOR is not a bold PROSE LIST item, and the opening cannot tell them
# apart -- `**7a-post. Log Rotation …**` and `**1. Narrative drift.** Rule text
# continues…` open identically. What follows the CLOSING `**` decides: an anchor's
# bold span IS the heading (it ends the line, or the heading wraps and never closes
# on it); a list item closes its label and continues in plain prose. Matching the
# opening alone read a consumer's three-item rule-weakness triage list as sections
# 1/2/3 and collided them with core's retro steps 1/2/3 -- a defect reported on
# every run, forever, in text that defines no section, and whose prescribed remedy
# ("label the heading `### 1. [ext:<id>] …`") cannot be applied to a sentence. It
# also fed those sentences to the STEP namespace below, where a prose item could
# silently satisfy a dangling "Step N".
#
# This predicate also lives in `reconcile/layer-drift.sh`, under the same name and
# with the same body. The two are a KNOWN drifting pair -- the same split has already
# cost this project three defects (readopt-override's resolver vs layer-drift's;
# register-drift's vs layer-drift's; the heading-label rule) -- so the
# layer-catalog-collision fixture extracts BOTH copies and asserts they return the
# same anchors for the same input. Change one, change the other, or the fixture says so.
bold_anchors_of_file() {
  awk '
    /^\*\*(Check[ \t]+)?[0-9]+[a-z-]*\./ {
      if ($0 ~ /^\*\*[^*]*\*\*[ \t]*[^ \t]/) next   # label closes, prose follows -> list item
      id = $0
      sub(/^\*\*(Check[ \t]+)?/, "", id)
      sub(/\..*$/, "", id)
      print id
    }' "$1" 2>/dev/null
}
# The check-HEADING grammar, ONE definition. `validate-gate-manifest.sh` carries this
# same assignment byte-identically and I46 asserts it, because that script has to find a
# consumer check heading that never became a `CHECK_LOADED` anchor — the state in which a
# check is neither MISSING (no manifest row names it) nor ORPHAN (no anchor exists), so
# it falls through both directions of the two-way resolve and reports as nothing at all.
# A second spelling of this pattern is exactly how the five-spelling normalizer in I40's
# header came to exist, and the terminating `.` here is as load-bearing as it is below.
CHECK_HEAD_RE='^#{2,4}[[:space:]]+(Check[[:space:]]+)?[0-9]+[a-z-]*\.'
defined_anchors() {
  [ -f "$1" ] || return 0
  { grep -Eho "$CHECK_HEAD_RE" "$1" 2>/dev/null \
      | sed -E 's/^#+[[:space:]]+(Check[[:space:]]+)?//' | sed -E 's/\.$//'
    bold_anchors_of_file "$1"
  } | sort -u
}

# Normalized heading TEXT for one anchor. A shared NUMBER is not a shared check:
# core's 24 is "The adversarial cycle CONVERGED", a consumer's 24 is
# "Financial-display ground-truth live-verify". The number cannot tell those apart
# and the title can, which is exactly what the Consumer-catalog crosswalk rule has
# always said (align by title/intent, never by number).
heading_title() { # heading_title <file> <anchor>
  awk -v a="$2" "$NRM_FN"'
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

# --- RULE numbers: a SECOND namespace, deliberately not folded into the above ---
#
# `defined_anchors` matches `### 24.` and `### Check 24.` and nothing else -- the
# id shape is narrow on purpose, and the terminating `.` is load-bearing there. A
# rule heading is `### Rule 29 -- Steering budget`: no terminator, and `Rule` is a
# word the anchor grammar must never learn, or `Rule 29` and check `29` become one
# id and the collision arm starts joining two unrelated catalogs. So rules get
# their own extractor, and the two namespaces stay apart.
#
# The optional `[...]` before the separator is the catalog LABEL. It has to be part
# of the pattern rather than stripped afterwards: a labelled heading is the resolved
# state, and a matcher that cannot see the label cannot recognise the fix it asked
# for -- the same defect `heading_labelled` above exists to record.
#
# This regex is a KNOWN drifting pair with `reconcile/relabel-extension-checks.sh`,
# which rewrites exactly the headings this reports. Invariant I34 in
# validate-enforcement-map.sh asserts the two `RULE_RE=` lines byte-identical: a
# detector that finds a heading the rewriter cannot rewrite would report a defect
# with no remedy, forever.
RULE_RE='^#{2,4}[[:space:]]+Rule[[:space:]]+([0-9]+[a-z]*)[[:space:]]*(\[[^]]*\][[:space:]]*)?(--|—|:)'

defined_rules() { # defined_rules <file> -> rule numbers, one per line
  [ -f "$1" ] || return 0
  grep -Eho "$RULE_RE" "$1" 2>/dev/null \
    | sed -E 's/^#+[[:space:]]+Rule[[:space:]]+//; s/[^0-9a-z].*$//' \
    | grep -E '.' | sort -u
}

rule_title() { # rule_title <file> <n>
  awk -v a="$2" "$NRM_FN"'
    $0 ~ ("^#{2,4}[ \t]+Rule[ \t]+" a "[ \t]*(\\[[^]]*\\][ \t]*)?(--|—|:)") {
      h=$0; sub(/^#+[ \t]+Rule[ \t]+/,"",h)
      sub("^" a "[ \t]*","",h)
      gsub(/\[ext:[A-Za-z0-9_.-]+\][ \t]*/, "", h); gsub(/\[core\][ \t]*/, "", h)
      sub(/^(--|—|:)[ \t]*/,"",h)
      print nrm(h); exit
    }' "$1" 2>/dev/null
}

rule_labelled() { # rule_labelled <file> <n>
  awk -v a="$2" '
    $0 ~ ("^#{2,4}[ \t]+Rule[ \t]+" a "[ \t]*(\\[[^]]*\\][ \t]*)?(--|—|:)") {
      print ($0 ~ /\[ext:[A-Za-z0-9_.-]+\]|\[core\]/) ? "yes" : "no"; exit
    }' "$1" 2>/dev/null
}

# --- the reserved consumer numbering band (W5) ---------------------------------
#
# ONE definition of the floor, here, because it is a two-sided partition: this file
# holds the CONSUMER side (allocate at or above it) and I45 in
# validate-enforcement-map.sh holds the CORE side (allocate below it). A second
# spelling of the number would let the two halves drift apart, and a partition whose
# halves disagree is worse than no partition — it would declare a range safe that
# core is still allocating from.
BAND_FLOOR=900

# --- the extension kind vocabulary (E10) ---------------------------------------
#
# ONE definition, here, for the same reason BAND_FLOOR is one definition: the set is
# restated in `extensions/README.md`'s entry contract, which is the prose an author
# actually reads, and I46 in validate-enforcement-map.sh joins the two so the copy
# cannot rot into a different set. Before this list existed `kind:` only had to be
# PRESENT, so `kind: qualifer` — or any other typo — was accepted in silence and then
# routed nowhere by the Rule 27 loader: an entry that reads as active and governs
# nothing, which is the check-cannot-fire defect wearing an author's typo.
#
# Measured before shipping: the reference consumer's thirty-three entries use exactly
# `step-domain` (21), `role` (8) and `check` (4), so the enum's false-positive set on
# the tree it was written against is EMPTY. `qualifier` is added by this release.
LAYER_KINDS='check step-domain role qualifier'

# Is <n> an allocation this band governs? Bare integers only, and the exclusions are
# in the header note above: a suffix marks a position beside core's N, and an alpha id
# has no ordering in a numeric band. Returns 0 (true) for a governed, out-of-band
# allocation.
below_band() { # below_band <n>
  case "$1" in
    ''|*[!0-9]*) return 1 ;;                 # suffixed or alphabetic -> not governed
  esac
  [ "$1" -lt "$BAND_FLOOR" ]
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

  fm_unterminated "$f" \
    && err "$(rel "$f"): frontmatter opens with '---' but never closes. Every reader here scans to EOF for its keys, so the entry looks well-formed while its body is still inside the YAML block — where the '### …' heading that carries the override parses as a comment, not a section."

  [ -n "$shadows" ] || err "$(rel "$f"): missing 'shadows:' frontmatter"

  if [ -z "$base_sha" ]; then
    err "$(rel "$f"): missing 'base_sha:' — override-drift cannot be computed for this entry"
  elif ! grep -Eq '^[0-9a-f]{7,40}$' <<<"$base_sha"; then
    err "$(rel "$f"): base_sha '$base_sha' is not a 7-40 char hex sha"
  elif git -C "$PROJECT_ROOT" rev-parse -q --verify "${base_sha}^{commit}" >/dev/null 2>&1; then
    subj="$(git -C "$PROJECT_ROOT" log -1 --format='%s' "$base_sha" 2>/dev/null | cut -c1-46)"
    err "$(rel "$f"): base_sha '$base_sha' is a CONSUMER commit (\"${subj}\") — it MUST be the DISTRIBUTION sha of the core rule when this override was authored. Override-drift detection is silently dead for this entry."
  fi

  # E8 — `reason:` is required. The contract has always said so and nothing read the key:
  # `grep -c reason` over both this validator and layer-drift.sh returned 0. An override is a
  # deliberate divergence from upstream, and the reason is the only record of WHY that a future
  # re-adoption can adjudicate against. Every entry on the reference consumer carries one, so
  # this fires zero times there — which is exactly why the fixture mutant below exists.
  [ -n "$(fm "$f" reason)" ] \
    || err "$(rel "$f"): missing 'reason:' frontmatter. An override records why this consumer
diverges from upstream; without it a later re-adoption has nothing to adjudicate the divergence against."

  # E3 / E7 — EVERY comma-part of `shadows:`, file AND anchor.
  #
  # This read only the FIRST part and only its file: `${shadows%%#*}` discards the anchor and
  # `sed 's/,.*//'` discards parts two onward. Measured on the reference consumer, one override
  # declares five anchors and got one file check and ZERO anchor checks; another declares four.
  # Nineteen anchor instances across twelve overrides were entirely unvalidated.
  #
  # THAT FIX HANDLED MULTIPLE PARTS AND NOT THE FILE-INHERITING SPELLING, so this ERROR-tier check
  # went on silently skipping part of its own subject set. Both spellings are in live use:
  #
  #   a.md#One, a.md#Two    <- file repeated per part: every part was checked
  #   a.md#One, #Two        <- file stated once: `${part%%#*}` is EMPTY for part two, and the
  #                            `[ -n "$tgt" ]` skip below fired BEFORE any anchor check ran
  #
  # Measured on the reference consumer: one override declaring four anchors got ONE checked and
  # THREE skipped. A part that names no file inherits the last one that did. The reading itself
  # now lives in shadow_parts() above — one grammar, bound to the pull classifier's by I40, so
  # the two tools cannot disagree about what an entry shadows.
  #
  # SPLIT BY PARAMETER EXPANSION, NOT BY `IFS=<tab> read`. A tab is IFS WHITESPACE, so a leading
  # one is absorbed rather than producing an empty first field — the target-less part `#Anchor`
  # came back as target `Anchor` with no anchor, and the arm below reported a missing FILE named
  # after the anchor. The empty field is the whole signal; it has to survive the read.
  if [ -n "$shadows" ]; then
    _tab="$(printf '\t')"
    while IFS= read -r _pair; do
      [ -n "$_pair" ] || continue
      tgt="${_pair%%"$_tab"*}"; anc="${_pair#*"$_tab"}"
      if [ -z "$tgt" ]; then
        err "$(rel "$f"): shadows part '#$anc' names no target file, and no earlier comma-part supplies one to inherit. A bare '#anchor' inherits the file from the part before it; as the FIRST part there is nothing to inherit, so this part shadows nothing and every file and anchor check on it is skipped in silence."
        continue
      fi
      core_file="$(resolve_target "$tgt")"
      if [ ! -f "$core_file" ]; then
        err "$(rel "$f"): shadows target '$tgt' does not exist at $core_file"
        continue
      fi
      [ -n "$anc" ] || continue
      case "$(anchor_arm "$anc" < "$core_file")" in
        FORWARD) : ;;
        REVERSE:*)
          real="$(anchor_arm "$anc" < "$core_file" | sed 's/^REVERSE://')"
          err "$(rel "$f"): shadows anchor '$anc' is not a heading in $tgt — it CONTAINS the heading '$real'. It resolves only by the reverse arm of the containment match, which silently widens the shadow to that WHOLE section: you believe you shadowed a narrower span and you have shadowed everything under that heading. Write the anchor as '$real', or narrow the shadow to the sub-headings you actually rewrote."
          ;;
        *)
          err "$(rel "$f"): shadows anchor '$anc' matches no heading in $tgt. The override shadows nothing, so its body never reaches the lead while every mechanical check reports green."
          ;;
      esac
    # HERE-DOC, NOT A PIPE. `printf | tr | while` puts the loop body in a SUBSHELL, so every
    # err() call incremented a counter in a child process and threw it away: the ERROR lines
    # printed and the footer counted one of three, which is a validator that reports a violation
    # and then exits zero. Loud and non-blocking is the worst of both.
    done <<EOF
$(shadow_parts "$shadows")
EOF
  fi
done < <(layer_files "$OVR_DIR")

# ---------------------------------------------------------------------------
# Pass 2 — extensions (E4, E5, W1, W2)
# ---------------------------------------------------------------------------
echo "== extensions =="
while IFS= read -r f; do
  [ -n "$f" ] || continue
  kind="$(fm "$f" kind)"; hooks="$(fm "$f" hooks | awk '{print $1}')"; id="$(fm "$f" id)"

  fm_unterminated "$f" \
    && err "$(rel "$f"): frontmatter opens with '---' but never closes. Every reader here scans to EOF for its keys, so the entry looks well-formed while its body is still inside the YAML block — where the '### …' heading that carries the extension parses as a comment, not a section."

  [ -n "$kind" ] || err "$(rel "$f"): missing 'kind:' frontmatter"
  [ -n "$id" ]   || err "$(rel "$f"): missing 'id:' frontmatter"
  # E9 — `push_candidate:` is required, and must be a boolean. The contract declared this key
  # and NOTHING read it: `grep -rl push_candidate` over the consumer's scripts, core/scripts and
  # core/hooks matched zero files. It is the flag the push queue is drained from, so an entry
  # without it is invisible to the absorption arc — the entry never becomes a push candidate and
  # never gets retired either. Measured on the reference consumer: one entry of thirty-three.
  pc="$(fm "$f" push_candidate)"
  case "$pc" in
    true|false) : ;;
    "")  err "$(rel "$f"): missing 'push_candidate:' frontmatter. It is the flag the push queue is drained from, so an entry without it can never be offered upstream and never retired on absorption." ;;
    *)   err "$(rel "$f"): push_candidate '$pc' is not true or false." ;;
  esac
  if [ -z "$hooks" ]; then
    err "$(rel "$f"): missing 'hooks:' frontmatter"; continue
  fi

  core_path="$(resolve_target "$hooks")"
  if [ ! -f "$core_path" ]; then
    err "$(rel "$f"): hooks target '$hooks' does not exist at $core_path"; continue
  fi

  # --- E10 — `kind:` names a grain the loader routes. ----------------------------
  # See LAYER_KINDS for why the set is defined once and what its false-positive set
  # measured. Checked AFTER the hooks arm so a single entry missing both keys reports
  # the missing hook first; an unknown kind on an entry that hooks nothing is noise.
  if [ -n "$kind" ] && ! printf '%s\n' $LAYER_KINDS | grep -Fxq -- "$kind"; then
    err "$(rel "$f"): kind '$kind' is not one of: $LAYER_KINDS. Rule 27's loader routes an entry by its kind, so an unrecognised one is read by nothing — the entry sits in the layer directory looking active and governs no run. If this is a new grain, it needs a loader that reads it before it needs a file that declares it."
  fi

  # --- E11/E12/E13 — the qualifier grain: `extends:` and `position:`. ------------
  #
  # WHAT THIS IS FOR. An extension hooks a FILE, so `EXTENSION-HOOK-DRIFT` fires on
  # any change anywhere in it. Measured across the reference consumer's 33 entries
  # and the full history of the 17 core files they hook: 1421 (entry, commit) drift
  # events at file grain against an expected 133 at anchor grain — 91% of what the
  # operator re-reads every pull is a change to a part of the file the entry never
  # referred to. `extends:` is the declaration that lets the classifier narrow it.
  #
  # `fm()` matches at index 1, which is what keeps `position:` from reading a body's
  # `disposition:` — that token is live in core (`team-roles/code-reviewer.md`,
  # `team-roles/remediator.md`, `steps/gate-validation.md`) and an unanchored grammar
  # for this key matches 8 of its 9 occurrences in core. Any future reader of this key
  # anchors the same way or inherits that false-positive set.
  extends="$(unquote "$(fm "$f" extends)")"
  position="$(unquote "$(fm "$f" position)")"

  if [ -n "$extends" ]; then
    # Parsed by shadow_parts — the SAME reading `shadows:` gets, bound byte-identical
    # across this file and reconcile/lib.sh by I40. A second parser for a second
    # anchor-bearing key is how the three readings I40's header records came to exist.
    ext_pairs="$(shadow_parts "$extends")"
    ext_n="$(printf '%s\n' "$ext_pairs" | grep -c .)"
    if [ "$ext_n" -ne 1 ]; then
      err "$(rel "$f"): extends: declares $ext_n anchors ('$extends'); exactly one is allowed. The whole point of the key is to give this entry ONE drift subject — two anchors mean two spans, and a drift row could no longer say which one moved without re-introducing the file-grain report it replaces."
    else
      ext_file="$(printf '%s' "$ext_pairs" | cut -f1)"
      ext_anc="$(printf '%s' "$ext_pairs" | cut -f2)"
      # A bare `#Anchor` inherits the hooked file: shadow_parts emits an empty file
      # field for a first part that names none, and that is the intended spelling.
      [ -n "$ext_file" ] || ext_file="$hooks"
      if [ "$ext_file" != "$hooks" ]; then
        err "$(rel "$f"): extends: names '$ext_file' but hooks: names '$hooks'. The anchor must live in the file this entry hooks, or the narrowed drift check would watch one file while the entry augments another — a green row for a section nothing here refers to."
      elif [ -z "$ext_anc" ]; then
        err "$(rel "$f"): extends: '$extends' carries no '#anchor'. Without one it declares the same file grain hooks: already declares, so it narrows nothing while reading as though it did."
      else
        case "$(anchor_arm "$ext_anc" < "$core_path")" in
          FORWARD) : ;;
          REVERSE:*)
            ext_real="$(anchor_arm "$ext_anc" < "$core_path" | sed 's/^REVERSE://')"
            err "$(rel "$f"): extends: anchor '$ext_anc' is not a heading in $hooks — it CONTAINS the heading '$ext_real'. It resolves only by the reverse arm of the containment match, which silently WIDENS the span to that whole section: you would believe drift was narrowed to a paragraph while the classifier watched everything under that heading. Write the anchor as '$ext_real'."
            ;;
          *)
            err "$(rel "$f"): extends: anchor '$ext_anc' matches no heading in $hooks. The narrowed drift check has no span to watch, so this entry would report clean through every upstream change to the section it augments."
            ;;
        esac
      fi
    fi
  fi

  # `position:` is meaningful only where something renders INSIDE a core section.
  # On any other kind it is a key the loader never reads, which is the same silent
  # no-op E10 exists to stop one field over.
  if [ "$kind" = qualifier ]; then
    [ -n "$extends" ]  || err "$(rel "$f"): kind 'qualifier' requires 'extends:'. A qualifier renders inside a core section, so without the anchor naming that section there is nothing for the loader to render into and nothing for the pull to drift-check."
    [ -n "$position" ] || err "$(rel "$f"): kind 'qualifier' requires 'position:'. The loader has to place this body relative to the core prose it qualifies; undeclared, two readers of the merged section can order it differently and the rendered rulebook stops being one document."
  elif [ -n "$position" ]; then
    err "$(rel "$f"): position '$position' is declared on kind '$kind', which does not render inside a core section. Nothing reads the key here, so it states a placement that never happens. Use kind 'qualifier' if that is what this entry does."
  fi

  # --- E14 — `gate_types:` is a CHECK's key. --------------------------------------
  # Same silent-no-op class as the `position:` arm above, one field over: only a check
  # is loaded from a GATE_MANIFEST row, so on a role or a step-domain entry nothing
  # reads the key and it declares a loading rule that never happens.
  #
  # The name is deliberately the one `enforcement-map.yaml` already uses per check
  # (`gate_types: [universal]`, read by validate-gate-adjudication.sh as
  # `gate_type in check.gate_types`). Same question, same answer, so a second spelling
  # would be a synonym for a live key — the `position:`/`disposition:` collision one
  # release back is what that costs. `fm()` anchors at index 1 and the map's copies are
  # indented four spaces, so the two never read each other.
  #
  # WHAT THIS ARM DOES NOT DECIDE. Whether the declared types exist, whether the entry
  # anchors anything, and whether it hooks the file carrying the manifest are all
  # questions about the RENDERED manifest, which only validate-gate-manifest.sh holds.
  # Answering them here would need a second GATE_MANIFEST grammar (I26).
  gate_types="$(unquote "$(fm "$f" gate_types)")"
  if [ -n "$gate_types" ] && [ "$kind" != check ]; then
    err "$(rel "$f"): gate_types '$gate_types' is declared on kind '$kind'. Only a check is loaded from a GATE_MANIFEST row, so on this kind nothing reads the key and it states a loading rule that never happens. Use kind 'check' if this entry defines gate checks."
  fi

  if [ -n "$position" ]; then
    case "$position" in
      append|prepend) : ;;
      *) err "$(rel "$f"): position '$position' is not 'append' or 'prepend'. Two positions is the whole vocabulary on purpose: a literal-prose anchor would be a THIRD anchor resolver in this repo, and reconcile/lib.sh's header records two shipped defects caused by duplicate resolvers." ;;
    esac
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
    grep -Fxq -- "$a" <<<"$core_anchors" || continue

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

  # W4 — the same collision in the RULE namespace. See the header note.
  #
  # Never ERROR. A rule number does not reach the durable audit record the way a
  # check number does (E6's stated reason for erroring), and the remedy is a
  # relabelling of the consumer's own catalog — blocking a pull on it would mean a
  # consumer cannot take a fix until it has renamed its own rules.
  core_rules="$(defined_rules "$core_path")"
  while IFS= read -r n; do
    [ -n "$n" ] || continue
    grep -Fxq -- "$n" <<<"$core_rules" || continue

    r_ext="$(rule_title "$f" "$n")"
    r_core="$(rule_title "$core_path" "$n")"
    # No title on either side means nothing to split collision from restatement on.
    # Reporting anyway would be a bare number with no evidence in the message.
    if [ -z "$r_ext" ] || [ -z "$r_core" ]; then continue; fi

    if same_title "$r_ext" "$r_core"; then
      warn "$(rel "$f"): RESTATES core 'Rule $n' (\"$r_core\") from '$hooks'. Rule 27(c): an extension MUST NOT restate a core rule — the copy cannot drift-check against the original, so it forks silently and then contradicts it."
      continue
    fi
    # A labelled heading is the RESOLVED state — same contract as heading_labelled.
    if [ "$(rule_labelled "$f" "$n")" = yes ]; then continue; fi

    warn "$(rel "$f"): RULE NUMBER COLLISION on 'Rule $n' — this defines \"$r_ext\" while core '$hooks' defines \"$r_core\" at the same number. Extensions are ADDITIVE, so both render into one merged rulebook under one integer and a bare \"Rule $n\" in a gate log, retro finding or dispatch brief has two referents. Give this rule a catalog-labelled heading (\"## Rule $n [ext:$id] -- …\") per the Consumer-catalog crosswalk; the integer never moves. \`reconcile/relabel-extension-checks.sh --apply\` writes it."
  done < <(defined_rules "$f")

  # W5 — an allocation from core's range. See the header note for why this is a
  # partition rather than a detector, and for every exclusion the predicate carries.
  #
  # THE TWO FILTERS BELOW ARE THE WHOLE CHECK, and each one has to be read in the
  # right order. `below_band` rejects suffixed and alphabetic ids; the `grep -Fxq`
  # against the core set rejects the deliberate qualifier, which shares core's
  # integer precisely because that integer is its reference. What survives both is a
  # number core has not taken, in the range core allocates from — an allocation that
  # is not yet a collision and will become one without anybody editing the entry.
  #
  # `relabel-extension-checks.sh` CANNOT be offered as the remedy here, and the
  # reason is structural rather than a matter of coverage: its rewrite loop iterates
  # the numbers CORE defines and looks each one up in the entry. A number core does
  # not define never enters that loop, so the relabeller is blind to W5's entire
  # subject set by construction. Prescribing it would hand the operator a tool that
  # exits "no unlabelled core-number collisions" on a tree full of findings.
  while IFS= read -r n; do
    [ -n "$n" ] || continue
    below_band "$n" || continue
    grep -Fxq -- "$n" <<<"$core_rules" && continue
    warn "$(rel "$f"): RULE OUT OF BAND — 'Rule $n' allocates from core's range. Core '$hooks' does not define rule $n TODAY, so no collision is reported and none can be: the collision appears in the release where core allocates $n, retroactively, across every gate log, retro and escalation already written against it. Consumer rules are reserved at ${BAND_FLOOR} and above — renumber to '9$n' or the next free number in your band, and add a crosswalk row in extensions/README.md resolving the bare \"Rule $n\" your existing history already carries. A catalog label does not settle this; it resolves a collision that exists, and the band prevents one that does not yet."
  done < <(defined_rules "$f")

  # The check namespace, scoped to `kind: check` exactly as E6 is — a step number is
  # a position in a procedure, not an allocation, and a band cannot reorder a
  # procedure without breaking it.
  if [ "$kind" = check ]; then
    while IFS= read -r a; do
      [ -n "$a" ] || continue
      below_band "$a" || continue
      grep -Fxq -- "$a" <<<"$core_anchors" && continue
      warn "$(rel "$f"): CHECK OUT OF BAND — check '$a.' allocates from core's range. Core '$hooks' does not define check $a TODAY, so E6 has nothing to join against and reports clean: the collision appears in the release where core allocates $a, retroactively, across every gate log already written — and a gate log is the durable audit record, so it cannot be corrected after the fact. Consumer checks are reserved at ${BAND_FLOOR} and above — renumber to '9$a' or the next free number in your band, and add a crosswalk row in extensions/README.md resolving the bare \"Check $a\" your existing history already carries."
    done < <(defined_anchors "$f")
  fi

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
    grep -Fxq -- "$ref" <<<"$GLOBAL_STEP_ANCHORS" && continue
    warn "$(rel "$f"): references \"Step $ref\" but no core file, extension, or override defines Step $ref anywhere in the rendered rulebook — dangling step pointer"
  done < <(grep -Eoh 'Step[ -][0-9]+[a-z-]*' "$f" 2>/dev/null | sed -E 's/^Step[ -]//' | sort -u)
done <<< "$all_files"

echo
printf 'validate-layer-entries: %d error(s), %d warning(s)\n' "$ERRORS" "$WARNS"
[ "$ERRORS" -eq 0 ]
