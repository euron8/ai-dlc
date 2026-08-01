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
#     W9 a layer entry names a SCRIPT PATH that resolves nowhere in this project. The
#        third citation namespace: W3 resolves `Step <n>`, W7 resolves `Check <n>`,
#        and nothing asked the question of the executables an entry tells an agent
#        to RUN. Root-anchored (`./scripts/x.sh` is checked, `core/scripts/x.sh` is
#        a distribution path and is not this arm's subject) and fence-skipping, with
#        the cost of that skip recorded at the arm itself. Measured on the reference
#        consumer before shipping: TWO live subjects, both agent-facing instructions
#        naming a file that has never existed in that repo's history, and both
#        invisible to every other mechanism in the rulebook.
#     E15 extension ALLOCATES a check or rule number below the reserved consumer band —
#        core's range. Whether core has taken that number yet decides the message, not
#        the verdict. The case core has NOT taken is the one E6 and W4 are structurally
#        unable to see, and it is the one that decides whether they ever fire.
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
#          - A number core DOES define is NOT excluded, and REMOVING that exclusion
#            is what this arm now is. It shipped with one, on the reasoning that an
#            entry deliberately qualifying core's Rule 13 shares that integer
#            BECAUSE the integer is the reference. That reasoning conflates two
#            different things: the HEADING is an allocation from core's namespace,
#            the REFERENCE to core's rule is prose in the body. Renumbering the
#            heading to 913 moves the allocation and leaves the reference exactly
#            where it was. Core is the source of truth for the range below
#            BAND_FLOOR; a consumer heading there is out of band whoever wrote it
#            first, and an exclusion that says otherwise is the "numbering is a
#            LABEL, not a namespace" position the band exists to replace.
#
#            THE EXCLUSION ALSO HAD A MEASURED HOLE, and the note that used to sit
#            here ("the exclusion that keeps the check honest") overstated it.
#            The predicate was "core defines this number TODAY", so a subject
#            LEFT the set at the moment core allocated its number — which is
#            precisely the retroactive collision this clause exists to warn
#            about. Re-derived on the reference consumer: EIGHT entry rules share
#            a core integer across two files, not four, and one of them is not a
#            qualifier at all. Its Rule 30 ("Lead states no fact it did not
#            observe this session") was authored 2026-07-20 alongside its Rules
#            31 and 32, three siblings filed in one retro; core allocated its own
#            unrelated Rule 30 six days later. The warning came true, and the
#            number went quiet here on the day it did. W4 does not report it
#            either — the consumer's remedy was a catalog label, which W4 reads
#            as the resolved state. Before this release, NEITHER ARM FIRED on the
#            one number in the tree that had actually detonated.
#
#            Authorship order was measured as a candidate predicate for keeping a
#            narrower exclusion — from the consumer's own history, seven core-first,
#            one consumer-first, none undecidable over those eight; 24/1/2 over the
#            full 27-subject set this de-blinding exposes. It is recorded and NOT
#            shipped: it would have kept 24 of 27 consumer allocations silent on the
#            grounds that core happened to number first, which is the carve-out
#            above, wearing a git pickaxe. It also needed a zero guard, because a
#            shallow or squashed clone answers empty on both sides and an arm that
#            cannot fire reads exactly like one that passed.
#
#            SO THE SUBJECT SET IS EVERY BARE INTEGER BELOW THE FLOOR, and the two
#            message bodies differ only in what has already happened to it: core
#            has not allocated it yet (the collision is coming) or core has (the
#            collision is here, retroactively, and no label reaches back).
#          - Check numbers are scoped to `kind: check`, exactly as E6 is, and for
#            the same stated reason: a step number is a POSITION in an ordered
#            procedure, not an allocation from a namespace, so a step-domain entry
#            hooking `steps/retro.md` at `### 4a-bis.` is placing text, not claiming
#            an id. Renumbering it into the band would reorder the procedure.
#        Rule numbers are not scoped by kind: SKILL.md's rulebook is one global
#        namespace whatever kind of entry writes into it.
#
#        A catalog label does NOT silence this, and that is the one place E15 departs
#        from E6/W4's "a labelled heading is the resolved state". The label resolves
#        an EXISTING collision in the audit record; the band removes the need for a
#        label at all. A labelled squatter is the expected state on first contact —
#        labelling is what core previously told consumers to do — so reporting it is
#        the migration signal, and suppressing it would hide the whole subject set
#        behind the remedy for a different clause.
#
#        WARN, never ERROR. Measured on the reference consumer at the release the band
#        first shipped: FIVE live subjects (checks 33/34/35, rules 31/32), zero
#        conforming entries reported. Re-measured with the membership exclusion removed:
#        TWENTY-SEVEN — 17 checks and 8 rules that core has ALREADY allocated over, plus
#        the same 2 pending rules (31/32) the exclusion never hid. Zero conforming
#        entries reported in either run: the in-band, suffixed and alphabetic controls
#        stay silent, so the twenty-two the exclusion was suppressing are subjects it
#        was hiding, not false positives it was preventing.
#
#        The severity argument is the same one and it got stronger, not weaker. The
#        remedy is renumbering, which rewrites the consumer's own durable audit key and
#        needs a crosswalk row per number; blocking a pull on five of those would wedge
#        a consumer out of taking a fix over its own catalog, and blocking on
#        twenty-seven would wedge it flat. Core is AT 32 checks and 30 rules, so
#        `Rule 31` is literally the next integer core will allocate — the pending
#        warnings have a live detonation date and the other twenty-five have a past one.
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

# THE CODE IS AN ARGUMENT, and that is the whole point of this shape.
#
# WHAT IT ENDS, MEASURED ON THE RELEASE BEFORE THIS ONE. The contract's header claimed
# "THE BINDING IS ON A TOKEN THE ENFORCER ALREADY EMITS". It was not: of the 22 codes
# clauses bind to THIS script, EIGHTEEN appeared nowhere but its comments, and the other
# four appeared in a message only because a neighbouring clause's prose mentioned them.
# I36 forward greps the enforcer for the code with `grep -qF` over the WHOLE file, so
# eighteen clauses satisfied the contract's central join ON A COMMENT — a join that a
# comment can satisfy is a join a comment can also be the only thing holding up.
#
# Two things follow from passing it instead of printing it. A finding names the clause it
# came from, so an operator handed `ERROR  E11  …` can look the rule up; and the per-code
# tally below is produced BY THE RUN, so `measured{fires}` is a count nobody can transcribe
# without running the script. That is v0.123.0's rule — ask whether a cell can be written
# without the run — applied to the field the charter specified and never got.
LC_FIRED=''
_lc_fire() { LC_FIRED="${LC_FIRED}$1 "; }
err()  { local c="$1"; shift; _lc_fire "$c"; printf 'ERROR  %s  %s\n' "$c" "$*"; ERRORS=$((ERRORS+1)); }
warn() { local c="$1"; shift; _lc_fire "$c"; printf 'WARN   %s  %s\n' "$c" "$*"; WARNS=$((WARNS+1)); }

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
# DELIBERATELY NOT WIDENED alongside `CHECK_HEAD_RE`, and the reason is a measurement
# rather than a preference: the alphabetic branch applied to the BOLD form harvests
# `**QA — validate every AC …**` (steps/implementation.md, present in core and in the
# reference consumer's installed copy) as a check id `QA`. That is a false positive with
# no remedy — there is no check `QA` to anchor — so the bold pseudo-heading stays numeric.
# The `#` form's alphabetic branch was measured over the same two trees and harvests only
# real ids, which is why the two forms are allowed to differ here and nowhere else.
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
# same assignment byte-identically and I47 asserts it, because that script has to find a
# consumer check heading that never became a `CHECK_LOADED` anchor — the state in which a
# check is neither MISSING (no manifest row names it) nor ORPHAN (no anchor exists), so
# it falls through both directions of the two-way resolve and reports as nothing at all.
# A second spelling of this pattern is exactly how the five-spelling normalizer in I40's
# header came to exist.
#
# ALPHABETIC IDS AND THE `—` TERMINATOR. This was numeric-and-dot-only for four releases,
# while `reconcile/relabel-extension-checks.sh` and `reconcile/layer-drift.sh` had ALREADY
# widened their ANCHOR_RE to `[A-Z]{1,3}[0-9]*` and `[.—]`. The two pairs forked in
# silence: the rewriter could relabel `## Check AP — …` and the detector could not see it,
# so the reference consumer's `Check AP` and `Check VH` were live, unloadable, and absent
# from every report. I47 now binds this line to that ANCHOR_RE as well, so the fork cannot
# reopen. Measured before widening: across core and the reference consumer the alphabetic
# branch harvests exactly `H1 H2 AP VH` and nothing else, and the `—` terminator harvests
# no numeric id at all (control: the numeric branch is unchanged at 171 core matches).
CHECK_HEAD_RE='^#{2,4}[[:space:]]+(Check[[:space:]]+)?([0-9]+[a-z-]*|[A-Z]{1,3}[0-9]*)[[:space:]]*[.—]'
defined_anchors() {
  [ -f "$1" ] || return 0
  { grep -Eho "$CHECK_HEAD_RE" "$1" 2>/dev/null \
      | sed -E 's/^#+[[:space:]]+(Check[[:space:]]+)?//' | sed -E 's/[[:space:]]*[.—]$//'
    bold_anchors_of_file "$1"
  } | sort -u
}

# Normalized heading TEXT for one anchor. A shared NUMBER is not a shared check:
# core's 24 is "The adversarial cycle CONVERGED", a consumer's 24 is
# "Financial-display ground-truth live-verify". The number cannot tell those apart
# and the title can, which is exactly what the Consumer-catalog crosswalk rule has
# always said (align by title/intent, never by number).
# The two lookups below take an id `defined_anchors` already harvested; they add none of
# their own. They still have to accept everything `CHECK_HEAD_RE` accepts, or a widened
# harvester feeds them an id whose title comes back EMPTY — and an empty title routes the
# collision arm into its RESTATES branch, where `heading_labelled` can never clear it. That
# is the "remedy that does not remedy" this function's own header records, reached from the
# other direction. The terminator is spelled as an ALTERNATION rather than the bracket
# class `[.—]` used in the shell grammar: a byte-oriented awk treats a multibyte `—` inside
# brackets as three separate bytes, so `sub()` would strip one of them and leave the rest in
# the title. The BOLD arm keeps its `\.` for the reason `bold_anchors_of_file` states.
heading_title() { # heading_title <file> <anchor>
  awk -v a="$2" "$NRM_FN"'
    $0 ~ ("^#{2,4}[ \t]+(Check[ \t]+)?" a "[ \t]*(\\.|—)") || $0 ~ ("^\\*\\*(Check[ \t]+)?" a "\\.") {
      h=$0; sub(/^#+[ \t]+/,"",h); sub(/^\*\*/,"",h); sub(/^Check[ \t]+/,"",h)
      sub("^" a "[ \t]*(\\.|—)[ \t]*","",h)
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
    $0 ~ ("^#{2,4}[ \t]+(Check[ \t]+)?" a "[ \t]*(\\.|—)") || $0 ~ ("^\\*\\*(Check[ \t]+)?" a "\\.") {
      print ($0 ~ /\[ext:[A-Za-z0-9_.-]+\]|\[core\]/) ? "yes" : "no"; exit
    }' "$1" 2>/dev/null
}

# THE ID AS ITS OWN HEADING SPELLS IT, terminator included.
#
# `defined_anchors` strips the terminator so that ids compare as ids, and E15's remedy then
# re-attached a `.` to every one of them. Measured on the reference consumer: 37 of its 39
# section-id subjects carry `.` and TWO carry `—` (`## Check AP — …`, `## Check VH — …`), so
# for those two the remedy named a string that occurs nowhere in the file. An operator or a
# script transcribing "rename 'AP.' to 'XAP.'" matches nothing, the id stays out of band, and
# the edit count still reads right: a remedy that does not remedy, failing silently. Without a
# `cmp -s` guard on the edit, 47 of 49 renames reads as 49 of 49 — which is what happened on
# the first pass of the migration rehearsal.
#
# The reverse fix is wrong in the other direction, which is why this is a join rather than a
# constant: drop the dot everywhere and 37 of the 39 remedies stop matching instead of 2.
#
# NEVER INVENTS A TERMINATOR. An id whose heading matches neither grammar comes back bare,
# because appending a plausible `.` is precisely the defect above. Found by RUNNING the
# migration this partition prescribes; it is not visible from core's own tree, which has no
# consumer to rename ids in.
anchor_form() { # anchor_form <file> <id> -> the id carrying the terminator its heading uses
  local m
  m="$(grep -Ehom1 "^#{2,4}[[:space:]]+(Check[[:space:]]+)?$2[[:space:]]*[.—]" "$1" 2>/dev/null)"
  if [ -n "$m" ]; then
    printf '%s' "$m" | sed -E 's/^#+[[:space:]]+(Check[[:space:]]+)?//'
    return
  fi
  # The bold pseudo-heading form has no `—` variant; `bold_anchors_of_file` requires the dot.
  grep -Eq "^\*\*(Check[[:space:]]+)?$2\." "$1" 2>/dev/null && { printf '%s.' "$2"; return; }
  printf '%s' "$2"
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

# --- the reserved consumer numbering band (E15) ---------------------------------
#
# ONE definition of the floor, here, because it is a two-sided partition: this file
# holds the CONSUMER side (allocate at or above it) and I45 in
# validate-enforcement-map.sh holds the CORE side (allocate below it). A second
# spelling of the number would let the two halves drift apart, and a partition whose
# halves disagree is worse than no partition — it would declare a range safe that
# core is still allocating from.
BAND_FLOOR=900

# The ALPHABETIC half of the same partition. A band is an ordering and alphabetic ids
# (`AP`, `VH`, `H1`) have none, which is why they were excluded from it for four
# releases — and the exclusion was measured to hide a live collision: the reference
# consumer defines check `H1` and so does core. A prefix is an ordering-free partition
# and does the same job: core allocates alphabetic ids that do NOT start with this
# letter, a consumer allocates ones that do. I45 holds core's side.
BAND_ALPHA_PREFIX=X

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

# THE PARTITION IS TOTAL. Every id a consumer entry allocates is governed — bare
# integers, suffixed ids, alphabetic ids, in every namespace and every `kind:`. This
# function answers with the CONFORMING FORM of an out-of-band id, and returns 1 when
# the id is already in band, so a caller cannot report a violation without also
# holding the remedy.
#
# THE THREE EXCLUSIONS THIS REPLACES WERE EACH MEASURED TO HIDE A LIVE COLLISION, which
# is why none of them survives. Stated in full because each was argued for on its merits
# and each argument was locally reasonable:
#
#   - "a suffix marks a POSITION beside core's N, not an allocation." The reference
#     consumer carries fifteen suffixed ids and core defines `1a 2a 2d 2e 3a 3b` among
#     its own — SIX live collisions the band could not see. The suffix does mark a
#     position, and the position is expressed by the ORDER of the numeric prefix, which
#     survives the move: `4a-bis` becomes `904a-bis` and still sorts before `904b`.
#     What it stops doing is sorting beside CORE's `4a`, and that is the accepted cost
#     of the partition rather than an oversight — a consumer section that must render
#     inside a core section is what `kind: qualifier` and `extends:` are for.
#   - "an alphabetic id has no ordering, so a numeric band cannot express it." True, and
#     a band is not the only partition available. A reserved PREFIX is ordering-free.
#     Core defines `H1`/`H2`, the reference consumer defines `AP`, `VH` and its own
#     `H1` — the seventh live collision, and the one that had been invisible longest.
#   - "a step number is a position in an ordered PROCEDURE, so `kind: check` scoping."
#     Same answer as the suffix: the numeric prefix carries the order, the band moves
#     the whole consumer range without permuting it, and a step that must render inside
#     a core step is a qualifier.
#
# The remedy forms:
#   numeric-leading   `19b` -> `919b`, `0b` -> `900b`, `5c-table` -> `905c-table`
#                     The leading integer is zero-padded to two digits before the `9`,
#                     or `0b` would become `90b` — still below the floor, a remedy that
#                     does not remedy.
#   alphabetic-leading `AP` -> `XAP`, `H1` -> `XH1`
out_of_band() { # out_of_band <id> -> conforming form on stdout; rc 1 = already conforming
  local id="$1" num rest
  case "$id" in
    '') return 1 ;;
    [0-9]*)
      num="${id%%[!0-9]*}"; rest="${id#"$num"}"
      # `10#` or a consumer id like `08` is read as invalid octal and the arithmetic
      # fails silently under `set -u`, which would retire this arm for that one id.
      [ "$((10#$num))" -lt "$BAND_FLOOR" ] || return 1
      printf '9%02d%s' "$((10#$num))" "$rest" ;;
    "$BAND_ALPHA_PREFIX"*) return 1 ;;
    [A-Za-z]*) printf '%s%s' "$BAND_ALPHA_PREFIX" "$id" ;;
    *) return 1 ;;
  esac
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
# Pass 0 — the contract receipt (E17, W6)
# ---------------------------------------------------------------------------
# WHAT THIS ENDS. `contract_version` and per-clause `since:` were declared at contract
# version 1 and read by NOTHING through eight bumps. I41 held ids unique and I42 held
# every `since` at or below the version, so the declaration was internally perfect and
# behaviourally absent — the shape that reads exactly like a working mechanism. This
# pass is the entry side of the join, and it is what makes `since:` mean something.
#
# THE SPECIFIED SEMANTICS WAS A SKIP AND IT IS NOT BUILT. Both the contract's own header
# and the plan that scheduled this stated the rule as "an entry declaring `conforms_to: N`
# is held only to clauses with `since <= N`". Built that way, a consumer erases any clause
# core has allocated since by writing one frontmatter line: the reference consumer's 49
# band ERRORs sit at `since: 4` and `since: 8`, so `conforms_to: 3` in thirteen files
# retires the whole partition. Core is the source of truth. The receipt reports scope and
# silences nothing, and the header paragraph that said otherwise was replaced in the same
# release rather than left to be read as still true.
#
# The retro-application problem the skip aimed at is real — a new clause that fires on
# every entry on first contact is a linter the operator turns off — and it is solved one
# level up, in core's release decision: ship the clause at WARN, promote it to ERROR once
# the migration has landed. LC-N5's promotion from its retired warn-tier code to E15 at
# contract_version 8 is the worked example, and it was core's call taken in the open, in a
# release, not a per-file declaration. (The retired code is deliberately not written here:
# I36 reverse reads every code token in this file and would demand a clause for it.)
#
# FALSE-POSITIVE SET, MEASURED BEFORE SHIPPING, on the reference consumer at 5491d6c0e:
# 50 entry files under extensions/ + overrides/, of which 38 declare `kind:` and 12
# declare `base_sha:`. 38 + 12 = 50 exactly, so every file `layer_files()` yields is a
# real entry and there is no file for which requiring the key is wrong. Live subject set
# 50, false-positive set EMPTY. `conforms_to:` occurs 0 times there today, which is why
# this is required rather than optional: an optional field nobody declares is a reader
# with no subject, and `kind: qualifier` spent 20 releases proving how that ends.
echo "== contract receipt =="
LC_FILE="$SKILL_DIR/layer-contract.yaml"
LC_CV=''
LC_SINCE=''
LC_CODE_ROWS=''
# Subject populations for the census, counted by the passes themselves rather than taken
# from LC_ENTRIES: that counter only advances when the contract was readable, so on a broken
# install it would report a population of zero and make every clause look evaluated-and-clean.
LC_N_OVERRIDE=0
LC_N_EXTENSION=0
LC_ENTRIES=0
LC_CURRENT=0
LC_BEHIND=0
LC_UNDECLARED=0
LC_BEHIND_LIST=''

if [ ! -f "$LC_FILE" ]; then
  # NOT a skip. The contract ships with the skill (`install.sh` copies it beside SKILL.md),
  # so its absence is a broken install, and a pass that quietly evaluated nothing would
  # report the same clean footer as a consumer that holds every clause.
  err E17 "cannot read the layer contract at $(rel "$LC_FILE") — it ships with the skill, so this is a broken or partial install. Every entry's conforms_to went UNCHECKED in this run; that is not the same as clean. Re-run /ai-dlc-update, or restore the file."
else
  LC_CV="$(awk '/^contract_version:/{print $2; exit}' "$LC_FILE")"
  LC_SINCE="$(awk '/^  - id:/{id=$3} /^    since:/{ if (id != "") { print id, $2; id="" } }' "$LC_FILE")"
  # `<code> <clause> <subject> <enforcer-basename>`, one row per clause. The census at the
  # foot of this run reports on the rows whose enforcer is THIS script and no others: a code
  # belonging to reconcile/layer-drift.sh has no subject population here, and printing a 0
  # for it would say "evaluated, nothing found" about a clause this run never evaluated.
  LC_CODE_ROWS="$(awk '
    /^  - id:/       { id=$3; subj=""; enf=""; next }
    /^    subject:/  { subj=$2; next }
    /^    enforcer:/ { n=split($2,p,"/"); enf=p[n]; next }
    /^    code:/     { if (id != "" && subj != "" && enf != "") print $2, id, subj, enf; id=""; next }
  ' "$LC_FILE")"

  if ! grep -Eq '^[0-9]+$' <<<"${LC_CV:-x}" || [ "${LC_CV:-0}" -lt 1 ]; then
    err E17 "read no usable contract_version out of $(rel "$LC_FILE") (got '${LC_CV:-<none>}'). Every receipt below is compared against it, so an unreadable value retires this whole pass silently instead of failing it."
    LC_CV=''
  fi
  if [ -z "$LC_SINCE" ]; then
    err E17 "read ZERO clauses with a since: out of $(rel "$LC_FILE"). The migration worklist below is derived from that set, so an empty one makes every entry look fully migrated — the state this pass exists to make visible."
  fi
fi

if [ -n "$LC_CV" ]; then
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    LC_ENTRIES=$((LC_ENTRIES+1))
    ct="$(fm "$f" conforms_to)"
    if [ -z "$ct" ]; then
      LC_UNDECLARED=$((LC_UNDECLARED+1))
      err E17 "$(rel "$f"): missing 'conforms_to:' frontmatter. Every layer entry declares the contract version it has been migrated to; without it neither you nor core can say which of the contract's ${LC_CV} versions of clauses this entry has ever been read against. Add 'conforms_to: ${LC_CV}' once the entry holds every clause, or the lower version it was last migrated to."
    elif ! grep -Eq '^[0-9]+$' <<<"$ct" || [ "$ct" -lt 1 ]; then
      err E17 "$(rel "$f"): conforms_to '$ct' is not a positive integer. It names a contract version, so it is compared numerically against contract_version ${LC_CV}."
    elif [ "$ct" -gt "$LC_CV" ]; then
      err E17 "$(rel "$f"): conforms_to $ct claims a contract version this distribution has never reached — its contract_version is ${LC_CV}. A receipt for a contract that does not exist cannot be honoured by anything, and it reads as MORE conformant than a correct entry."
    elif [ "$ct" -lt "$LC_CV" ]; then
      LC_BEHIND=$((LC_BEHIND+1))
      LC_BEHIND_LIST="${LC_BEHIND_LIST}$(rel "$f")@${ct} "
    else
      LC_CURRENT=$((LC_CURRENT+1))
    fi
  done < <(layer_files "$EXT_DIR"; layer_files "$OVR_DIR")
fi

# W6 — ONE line per run, not one per entry, and the reason is the one the E16 degraded-mode
# line records: the release that bumps contract_version puts EVERY entry behind at once, and
# a wall of identical lines is a wall an operator scrolls past. The union of postdating
# clause ids is the migration worklist; the per-entry version is on each entry.
#
# IT DOES NOT SILENCE ANYTHING and that is the whole design. Being behind is reported, never
# subtracted: every clause above still fired on these entries in this same run.
if [ "$LC_BEHIND" -gt 0 ]; then
  lc_min="$(printf '%s\n' $LC_BEHIND_LIST | sed 's/.*@//' | sort -n | head -1)"
  lc_owed="$(awk -v n="$lc_min" '$2+0 > n { printf "%s ", $1 }' <<<"$LC_SINCE")"
  lc_owed="${lc_owed% }"
  warn W6 "${LC_BEHIND} of ${LC_ENTRIES} layer entr(y/ies) declare a conforms_to below contract_version ${LC_CV}: ${LC_BEHIND_LIST% }. Clauses introduced after the lowest of them (${lc_min}) are their migration worklist: ${lc_owed:-<none>}. This is scope, not an exemption — every one of those clauses was evaluated against these entries in this run."
fi

# ---------------------------------------------------------------------------
# Pass 1 — overrides (E1, E2, E3)
# ---------------------------------------------------------------------------
echo "== overrides =="
while IFS= read -r f; do
  [ -n "$f" ] || continue
  LC_N_OVERRIDE=$((LC_N_OVERRIDE+1))
  shadows="$(fm "$f" shadows)"; base_sha="$(fm "$f" base_sha)"

  fm_unterminated "$f" \
    && err E1 "$(rel "$f"): frontmatter opens with '---' but never closes. Every reader here scans to EOF for its keys, so the entry looks well-formed while its body is still inside the YAML block — where the '### …' heading that carries the override parses as a comment, not a section."

  [ -n "$shadows" ] || err E1 "$(rel "$f"): missing 'shadows:' frontmatter"

  if [ -z "$base_sha" ]; then
    err E1 "$(rel "$f"): missing 'base_sha:' — override-drift cannot be computed for this entry"
  elif ! grep -Eq '^[0-9a-f]{7,40}$' <<<"$base_sha"; then
    err E1 "$(rel "$f"): base_sha '$base_sha' is not a 7-40 char hex sha"
  elif git -C "$PROJECT_ROOT" rev-parse -q --verify "${base_sha}^{commit}" >/dev/null 2>&1; then
    subj="$(git -C "$PROJECT_ROOT" log -1 --format='%s' "$base_sha" 2>/dev/null | cut -c1-46)"
    err E2 "$(rel "$f"): base_sha '$base_sha' is a CONSUMER commit (\"${subj}\") — it MUST be the DISTRIBUTION sha of the core rule when this override was authored. Override-drift detection is silently dead for this entry."
  fi

  # E8 — `reason:` is required. The contract has always said so and nothing read the key:
  # `grep -c reason` over both this validator and layer-drift.sh returned 0. An override is a
  # deliberate divergence from upstream, and the reason is the only record of WHY that a future
  # re-adoption can adjudicate against. Every entry on the reference consumer carries one, so
  # this fires zero times there — which is exactly why the fixture mutant below exists.
  [ -n "$(fm "$f" reason)" ] \
    || err E8 "$(rel "$f"): missing 'reason:' frontmatter. An override records why this consumer
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
        err E3 "$(rel "$f"): shadows part '#$anc' names no target file, and no earlier comma-part supplies one to inherit. A bare '#anchor' inherits the file from the part before it; as the FIRST part there is nothing to inherit, so this part shadows nothing and every file and anchor check on it is skipped in silence."
        continue
      fi
      core_file="$(resolve_target "$tgt")"
      if [ ! -f "$core_file" ]; then
        err E3 "$(rel "$f"): shadows target '$tgt' does not exist at $core_file"
        continue
      fi
      [ -n "$anc" ] || continue
      case "$(anchor_arm "$anc" < "$core_file")" in
        FORWARD) : ;;
        REVERSE:*)
          real="$(anchor_arm "$anc" < "$core_file" | sed 's/^REVERSE://')"
          err E7 "$(rel "$f"): shadows anchor '$anc' is not a heading in $tgt — it CONTAINS the heading '$real'. It resolves only by the reverse arm of the containment match, which silently widens the shadow to that WHOLE section: you believe you shadowed a narrower span and you have shadowed everything under that heading. Write the anchor as '$real', or narrow the shadow to the sub-headings you actually rewrote."
          ;;
        *)
          err E7 "$(rel "$f"): shadows anchor '$anc' matches no heading in $tgt. The override shadows nothing, so its body never reaches the lead while every mechanical check reports green."
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
# --- E16: an id that LEFT an entry needs a crosswalk row -----------------------
#
# The renumber is the event, and it is the one thing about the migration core can
# actually evaluate. Core cannot see which numbers a consumer has written into its gate
# logs — `extensions/README.md` says so in its own prose, on correct I37 grounds, and
# that clause stays withdrawn. But core CAN see that an entry used to define `24.` and
# now defines `924.`, because the consumer's own history says so. Every such id is a
# bare citation somewhere in evidence that no longer resolves, and the crosswalk row is
# what resolves it.
#
# WHY THIS IS NOT IN reconcile/layer-drift.sh, where a reader would look for it. That
# script's span is `base_sha..theirs` in the DISTRIBUTION. A renumber is a CONSUMER-side
# event — the entry moves between two consumer commits — so no distribution span
# contains it and the classifier would be joining against the wrong history. Here the
# consumer's git is already in hand (E2 resolves base_sha against it), the arm is ERROR,
# and the consumer's pre-push refuses: earlier and stricter than blocking `apply`.
#
# THE HISTORICAL SET IS READ FROM THE DIFF, not from one `git show` per commit. On the
# reference consumer that is 33 git invocations rather than 230, and the union of every
# ADDED heading line across a file's history is exactly the set of ids it has ever
# defined. The added lines are written to a temp file and handed to `defined_anchors` /
# `defined_rules` UNCHANGED, so this arm cannot harvest an id shape the rest of the file
# would not — a second grammar here is how the five-copy fork in I40's header started.
#
# AND IT REFUSES RATHER THAN GUESSING. An empty history and a clean history produce the
# same empty retired-set, which is this arm's PASS — the named defect class exactly. So
# a shallow clone, a missing git, or a TRACKED file whose log comes back empty is
# reported, counted and named, never skipped.
# WHERE THE TABLE LIVES, AND WHY IT IS DECLARED RATHER THAN WRITTEN HERE.
#
# It used to be `$EXT_DIR/README.md`, hard-wired. That file is CORE's — the distribution
# ships it, `install.sh` scaffolds it, and `unregistered-drift.sh` compares a consumer's
# copy against the distribution at base. So LC-N6, an ERROR, had its only compliant output
# inside a file the consumer does not own: the reference consumer's migration wrote 19 rows
# into it and earned a permanent `HARD-UNREGISTERED-CORE-DRIFT`, whose two printed remedies
# (revert, or refile under overrides/) respectively delete the rows and put them where this
# reader does not look. A rule whose enforcement and whose ownership model disagree is not a
# bug in either one; it is a missing join, and this is the join.
#
# The path is DECLARED in layer-contract.yaml, beside the clauses that cite it, and twinned
# into reconcile/setup-sites.md for the reason `consumer_machinery_home:` is — ai-dlc-update
# may not read pipeline files, so the updater and this reader would otherwise be bound by
# nothing. I67 holds the two declarations to one string and refuses to let this script carry
# the literal. The contract rather than core-manifest.md because the manifest is a file 55 of
# the 63 fixture seeds touching a synthetic consumer never build, while every one of them
# already copies the contract for E17 — same declaration, false-positive set zero instead of
# fifty-five.
#
# IT REFUSES RATHER THAN GUESSING. An unreadable declaration and a consumer with no rows are
# the same empty crosswalk set otherwise, and that set is what E16 and W7 clear themselves
# against — so a missing key would silently turn two clauses into unconditional PASSes.
#
# SCOPED TO A CONTRACT THAT EXISTS. An absent `layer-contract.yaml` is already refused by
# LC-C1's own arm, which names it and says why; reporting it a second time here made ONE
# defect produce TWO findings and entangled a sibling fixture's mutant with this clause —
# `layer-conforms-to`'s m3 asserts that removing ITS refusal lets an uninstalled contract
# exit 0, and it stopped being able to say that. The subject here is a contract present and
# silent about the key, which is the only state this arm can speak to.
CROSSWALK_REL="$(sed -n 's/^consumer_crosswalk_file:[[:space:]]*//p' "$LC_FILE" 2>/dev/null | head -1 | sed 's/[[:space:]]*$//')"
if [ -z "$CROSSWALK_REL" ] && [ -f "$LC_FILE" ]; then
  err E16 "could not read 'consumer_crosswalk_file:' from $(rel "$LC_FILE"). The crosswalk table's location is declared there and nowhere else, so without it this run has no table to read — and an unread table is indistinguishable from an empty one, which is E16's and W7's PASS. Both clauses are therefore unevaluated in this run, not clean."
  CROSSWALK_MD=''
else
  CROSSWALK_MD="$PROJECT_ROOT/$CROSSWALK_REL"
fi
# The retired location, kept readable for exactly one reason: an unmigrated consumer's rows
# must still RESOLVE, or this release would re-wedge every consumer it is meant to unblock.
# LC-N7 is what keeps that from being a silent dual-read.
CROSSWALK_LEGACY="$EXT_DIR/README.md"
CROSSWALK_STATE=''
CROSSWALK_UNREADABLE=''
CROSSWALK_UNREADABLE_N=0

crosswalk_probe() {
  [ -z "$CROSSWALK_STATE" ] || return 0
  if ! git -C "$PROJECT_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    CROSSWALK_STATE=no-git
  elif [ "$(git -C "$PROJECT_ROOT" rev-parse --is-shallow-repository 2>/dev/null)" = true ]; then
    CROSSWALK_STATE=shallow
  else
    CROSSWALK_STATE=ok
  fi
}

# Column 1 of every data row of every pipe table in the crosswalk file. Deliberately
# not scoped to one heading: the table is being widened from checks to both namespaces
# and a heading-scoped reader would have to be edited in lockstep with a prose heading,
# which is the restatement smell. A separator row and the header cell are dropped by
# shape, not by position.
#
# FENCED BLOCKS ARE SKIPPED, and that arm is not tidiness. Measured on the shipped
# `extensions/README.md` before this release: the reader harvested THREE ids from core's own
# file — two from a gate-log render example inside a ``` fence, and one live example row in
# the table itself. Every consumer inherited all three, so `24` arrived pre-resolved and
# E16 could never fire on it. A prose example that satisfies the clause it illustrates is
# this repo's named class, and it had been shipping since the table existed. Core's own
# files now yield ZERO ids under this reader, which is what makes an id found in the retired
# location provably consumer-authored — LC-N7 needs no subtraction because there is nothing
# to subtract. I68 is the arm that keeps it that way.
crosswalk_rows() { # crosswalk_rows <file>
  [ -n "${1:-}" ] && [ -f "$1" ] || return 0
  awk -F'|' '
    /^[[:space:]]*```/ { fence = !fence; next }
    fence { next }
    /^[[:space:]]*\|/ {
      v=$2; gsub(/^[ \t`*]+|[ \t`*]+$/,"",v)
      if (v == "" || v ~ /^-+$/) next
      if (tolower(v) ~ /^your (number|id)$/) next
      print v
    }' "$1" | sort -u
}

# Every id <extractor> would harvest from any version of <file> in this repo's history.
historical_ids() { # historical_ids <file> <defined_anchors|defined_rules>
  local tmp added
  tmp="$(mktemp "${TMPDIR:-/tmp}/vle-hist.XXXXXX")" || return 0
  git -C "$PROJECT_ROOT" log -p --format='' -- "$1" 2>/dev/null | sed -n 's/^+//p' > "$tmp"
  added=$?
  "$2" "$tmp"
  rm -f "$tmp"
  return $added
}

crosswalk_unreadable() { # crosswalk_unreadable <subject>
  CROSSWALK_UNREADABLE="${CROSSWALK_UNREADABLE}${CROSSWALK_UNREADABLE:+, }$1"
  CROSSWALK_UNREADABLE_N=$((CROSSWALK_UNREADABLE_N+1))
}

echo "== extensions =="

# Primed HERE, in the parent shell. Called from inside a `$( )` it would assign into a
# subshell, read as unset on every entry, and re-run its two `git rev-parse` calls once
# per file — and the degraded-mode message would name the generic reason on a tree that
# is plainly not a git repo at all.
crosswalk_probe
CROSSWALK_IDS="$(crosswalk_rows "$CROSSWALK_MD")"

# LC-N7 / W8 — the retired location, and the reason this is a WARN with teeth rather than a
# silent dual-read. The spec this release was cut against is explicit: an unmigrated consumer
# and a migrated one MUST NOT produce identical output. They do not — the ids still resolve,
# so nothing wedges, and the run names every row that has not moved yet. A consumer that has
# migrated says nothing here, which is the only state in which this arm is quiet.
CROSSWALK_LEGACY_IDS="$(crosswalk_rows "$CROSSWALK_LEGACY")"
if [ -n "$CROSSWALK_LEGACY_IDS" ]; then
  CROSSWALK_IDS="$(printf '%s\n%s\n' "$CROSSWALK_IDS" "$CROSSWALK_LEGACY_IDS" | grep -E '.' | sort -u)"
  warn W8 "$(rel "$CROSSWALK_LEGACY"): carries $(printf '%s\n' "$CROSSWALK_LEGACY_IDS" | grep -c .) crosswalk row(s) in the RETIRED location — $(printf '%s' "$CROSSWALK_LEGACY_IDS" | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g'). That file is core's: the distribution ships it and every pull compares your copy against it, so rows written there read as unregistered core drift and the two remedies the updater prints for that status will either delete them or move them somewhere nothing reads. They still resolve today and nothing is wedged. Move them to ${CROSSWALK_REL:-the declared crosswalk file} and delete them from here; the declaration is 'consumer_crosswalk_file:' in $(rel "$LC_FILE")."
fi

# ================= LC-M1 / E18 and LC-M2 / W10 — the machinery inventory ==================
#
# THE GOAL THIS SERVES, and the distinction that took the whole program to get right. Eight
# predicates asking core to INFER which consumer executables are ai-dlc were measured and all
# eight refuted; that refutation is sound and nothing below re-attempts it. But inference and
# declaration are different questions. Core cannot decide whether `scripts/foo.sh` serves the
# ai-dlc process or the consumer's own domain. A consumer CAN, and once it has said so,
# "is this declared path inside the declared home" is a string comparison.
#
# THE HOME AND THE INVENTORY FILE ARE BOTH READ FROM DECLARATIONS, never spelled here. The
# home literal lives in ai-dlc-update's setup-sites.md copy (I43 binds it across every
# surface); the inventory path is declared in the contract beside the crosswalk's, and I67's
# rule applies to it — a reader that restates the literal is the drift this contract removes.
MACHINERY_REL="$(sed -n 's/^consumer_machinery_file:[[:space:]]*//p' "$LC_FILE" 2>/dev/null | head -1 | sed 's/[[:space:]]*$//')"
# NOT from reconcile/setup-sites.md: I25 and I29 forbid core/scripts depending on the update
# skill, and that is why nrm_awk() above is a bound COPY rather than a source. `core-manifest.md`
# ships inside THIS skill, carries the same literal, and I43 holds every surface to one string --
# so reading it here is a join, not a fifth spelling.
MACHINERY_HOME="$(sed -n 's/^consumer_machinery_home:[[:space:]]*//p' "$SKILL_DIR/core-manifest.md" 2>/dev/null | head -1 | sed 's/[[:space:]]*$//')"

# Both arms are SILENT on a tree with no contract, exactly as E16 is. A distribution that
# predates the declaration is not a consumer failing to migrate, and v0.228.0 recorded what
# happens when an arm cannot tell those apart: two apply fixtures went red because their
# synthetic distributions predate the contract entirely.
if [ -n "$MACHINERY_REL" ] && [ -n "$MACHINERY_HOME" ]; then
  MACHINERY_MD="$PROJECT_ROOT/$MACHINERY_REL"
  if [ ! -f "$MACHINERY_MD" ]; then
    # Scaffolded by install.sh and by the pull driver. Absent means neither has run since the
    # declaration shipped -- v0.228.0's finding, where a create-once file reached no existing
    # consumer because a consumer never runs install.sh twice.
    warn W10 "$MACHINERY_REL: the ai-dlc machinery inventory has not been scaffolded, so this project has not declared which of its scripts are ai-dlc machinery. The next pull creates it from core's template; until then nothing states the inventory and nothing can check it. An empty inventory is legitimate and is declared with the literal 'none' -- what is not legitimate is silence, because a project with no machinery and a project that has never looked are indistinguishable without it."
  else
    # The inventory: every non-blank line inside the fenced block that is not prose. The
    # grammar is deliberately dumb -- a path per line -- because the consumer writes this by
    # hand and a clever parser would make a hand-written file a source of parse errors.
    MACHINERY_LINES="$(awk '/^```/{f=!f; next} f && NF' "$MACHINERY_MD" 2>/dev/null | sed 's/[[:space:]]*$//' | grep -E '.' || true)"
    if [ -z "$MACHINERY_LINES" ]; then
      warn W10 "$MACHINERY_REL: carries no inventory block at all -- not even the literal 'none'. An empty inventory and an undeclared one must not look alike: state 'none' if this project has no ai-dlc machinery of its own, or list one path per line inside the fenced block."
    elif [ "$(printf '%s\n' "$MACHINERY_LINES" | grep -c .)" = "1" ] && [ "$MACHINERY_LINES" = "none" ]; then
      : # explicitly empty, and that is a complete answer
    else
      while IFS= read -r mpath; do
        [ -n "$mpath" ] || continue
        case "$mpath" in "#"*) continue ;; esac
        # ERROR 1 of 2 -- declared but outside the home. THIS IS THE SEGREGATION.
        case "$mpath" in
          "$MACHINERY_HOME"*) ;;
          *) err E18 "$mpath: declared as ai-dlc machinery in $MACHINERY_REL but it does not live under the declared machinery home '$MACHINERY_HOME'. That is the state the home exists to end -- ai-dlc machinery and this project's own domain code mixed in one directory with nothing able to tell them apart. Move it and update every reference: git mv '$mpath' '${MACHINERY_HOME}$(basename "$mpath")'. If this file is NOT ai-dlc machinery -- if it would still have a job with ai-dlc removed from this repository -- then it should not be in the inventory at all; remove the line instead of moving the file."
             continue ;;
        esac
        # ERROR 2 of 2 -- declared but absent. An inventory nothing checks is forgeable.
        [ -e "$PROJECT_ROOT/$mpath" ] || err E18 "$mpath: declared as ai-dlc machinery in $MACHINERY_REL but no such file exists in this project. A declared inventory that names paths which are not there is a list nothing checks, which is exactly the forgeability this contract removes. Either the path is stale and should be removed from the inventory, or the file was moved and the inventory did not follow."
      done <<MACHINERY_EOF
$MACHINERY_LINES
MACHINERY_EOF
    fi
  fi
fi

# THE RESOLVABILITY SET — measured, and it is what makes E16's subject the right one.
#
# The first form of this arm asked "did an id leave THIS entry", and on the reference
# consumer that reported 32 subjects of which 25 were wrong. The wrong ones were all the
# same shape: an entry that used to RESTATE a core section — `retro-domain.md` carried
# twenty of core's own retro step ids — and later stopped. Nothing was retired there. A
# gate log citing `Step 7a` still resolves, to core's `7a`, which is exactly where it
# always pointed. The same for an id that moved to a SIBLING entry hooking the same core
# file: the catalog still defines it, so the citation still lands.
#
# So the question is not "did it leave this file" but "did it leave the RENDERED
# RULEBOOK" — core plus every entry hooking it. That is a narrowing of the subject set
# and NOT an exclusion from the partition: an id core defines is resolvable BECAUSE core
# is the source of truth for it. The band arms above are what make sure the consumer is
# not squatting on it in the first place.
#
# Two sets, never one. `Rule 24` and check `24` are different catalogs that share an
# integer on purpose, and a merged set would let a live rule resolve a retired check.
LIVE_ANCHORS=''
LIVE_RULES=''
LIVE_ENTRY_N=0
while IFS= read -r _lf; do
  [ -n "$_lf" ] || continue
  LIVE_ENTRY_N=$((LIVE_ENTRY_N+1))
  LIVE_ANCHORS="$LIVE_ANCHORS
$(defined_anchors "$_lf")"
  LIVE_RULES="$LIVE_RULES
$(defined_rules "$_lf")"
  _lh="$(fm "$_lf" hooks)"
  [ -n "$_lh" ] || continue
  _lc="$(resolve_target "$_lh")"
  [ -f "$_lc" ] || continue
  LIVE_ANCHORS="$LIVE_ANCHORS
$(defined_anchors "$_lc")"
  LIVE_RULES="$LIVE_RULES
$(defined_rules "$_lc")"
done < <(layer_files "$EXT_DIR")
LIVE_ANCHORS="$(printf '%s\n' "$LIVE_ANCHORS" | grep -E '.' | sort -u)"
LIVE_RULES="$(printf '%s\n' "$LIVE_RULES" | grep -E '.' | sort -u)"
# A zero here is E16's PASS, so it cannot be allowed to pass silently: an empty live set
# makes every historical id look retired, which would bury the real subjects in noise and
# is the mirror of the unreadable-history case below.
#
# BUT AN EMPTY SET IS ONLY MEANINGLESS WHEN THERE WERE ENTRIES TO BUILD IT FROM. A consumer
# that has just run the installer has ZERO layer entries, and this arm fired on every one of
# them: the set is empty because there is no subject, not because the subject could not be
# read. Measured on a tree built by running scripts/install.sh into an empty directory before
# this guard: `1 error(s)`, exit 1, from `E16=LC-N6:1/0` in the census — a clause firing once
# against a subject population of zero. The two states are opposite and the old arm could not
# tell them apart, which is this repo's named class arriving as a FALSE POSITIVE rather than a
# false zero: a fresh install's pre-push refused, and a bare `1 error(s)` reads like any other.
#
# The guard is the entry COUNT, not the emptiness of the set, because those are the two facts
# that differ. Zero entries and an empty set is a new consumer. Entries present and an empty
# set is the unreadable case this arm exists for, and it still errs.
if [ -z "$LIVE_ANCHORS" ] && [ -z "$LIVE_RULES" ] && [ "$LIVE_ENTRY_N" -gt 0 ]; then
  err E16 "built an EMPTY resolvability set from the $LIVE_ENTRY_N layer entr(y/ies) present and the core files they hook. Every id any entry has ever defined would read as retired, so this arm's output is meaningless in both directions — it cannot be trusted to fire and it cannot be trusted to stay quiet."
fi
while IFS= read -r f; do
  [ -n "$f" ] || continue
  LC_N_EXTENSION=$((LC_N_EXTENSION+1))
  kind="$(fm "$f" kind)"; hooks="$(fm "$f" hooks | awk '{print $1}')"; id="$(fm "$f" id)"

  fm_unterminated "$f" \
    && err E4 "$(rel "$f"): frontmatter opens with '---' but never closes. Every reader here scans to EOF for its keys, so the entry looks well-formed while its body is still inside the YAML block — where the '### …' heading that carries the extension parses as a comment, not a section."

  [ -n "$kind" ] || err E4 "$(rel "$f"): missing 'kind:' frontmatter"
  [ -n "$id" ]   || err E4 "$(rel "$f"): missing 'id:' frontmatter"
  # E9 — `push_candidate:` is required, and must be a boolean. The contract declared this key
  # and NOTHING read it: `grep -rl push_candidate` over the consumer's scripts, core/scripts and
  # core/hooks matched zero files. It is the flag the push queue is drained from, so an entry
  # without it is invisible to the absorption arc — the entry never becomes a push candidate and
  # never gets retired either. Measured on the reference consumer: one entry of thirty-three.
  pc="$(fm "$f" push_candidate)"
  case "$pc" in
    true|false) : ;;
    "")  err E9 "$(rel "$f"): missing 'push_candidate:' frontmatter. It is the flag the push queue is drained from, so an entry without it can never be offered upstream and never retired on absorption." ;;
    *)   err E9 "$(rel "$f"): push_candidate '$pc' is not true or false." ;;
  esac
  if [ -z "$hooks" ]; then
    err E4 "$(rel "$f"): missing 'hooks:' frontmatter"; continue
  fi

  core_path="$(resolve_target "$hooks")"
  if [ ! -f "$core_path" ]; then
    err E5 "$(rel "$f"): hooks target '$hooks' does not exist at $core_path"; continue
  fi

  # --- E10 — `kind:` names a grain the loader routes. ----------------------------
  # See LAYER_KINDS for why the set is defined once and what its false-positive set
  # measured. Checked AFTER the hooks arm so a single entry missing both keys reports
  # the missing hook first; an unknown kind on an entry that hooks nothing is noise.
  if [ -n "$kind" ] && ! grep -Fxq -- "$kind" <<<"$(printf '%s\n' $LAYER_KINDS)"; then
    err E10 "$(rel "$f"): kind '$kind' is not one of: $LAYER_KINDS. Rule 27's loader routes an entry by its kind, so an unrecognised one is read by nothing — the entry sits in the layer directory looking active and governs no run. If this is a new grain, it needs a loader that reads it before it needs a file that declares it."
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
      err E11 "$(rel "$f"): extends: declares $ext_n anchors ('$extends'); exactly one is allowed. The whole point of the key is to give this entry ONE drift subject — two anchors mean two spans, and a drift row could no longer say which one moved without re-introducing the file-grain report it replaces."
    else
      ext_file="$(printf '%s' "$ext_pairs" | cut -f1)"
      ext_anc="$(printf '%s' "$ext_pairs" | cut -f2)"
      # A bare `#Anchor` inherits the hooked file: shadow_parts emits an empty file
      # field for a first part that names none, and that is the intended spelling.
      [ -n "$ext_file" ] || ext_file="$hooks"
      if [ "$ext_file" != "$hooks" ]; then
        err E11 "$(rel "$f"): extends: names '$ext_file' but hooks: names '$hooks'. The anchor must live in the file this entry hooks, or the narrowed drift check would watch one file while the entry augments another — a green row for a section nothing here refers to."
      elif [ -z "$ext_anc" ]; then
        err E11 "$(rel "$f"): extends: '$extends' carries no '#anchor'. Without one it declares the same file grain hooks: already declares, so it narrows nothing while reading as though it did."
      else
        case "$(anchor_arm "$ext_anc" < "$core_path")" in
          FORWARD) : ;;
          REVERSE:*)
            ext_real="$(anchor_arm "$ext_anc" < "$core_path" | sed 's/^REVERSE://')"
            err E11 "$(rel "$f"): extends: anchor '$ext_anc' is not a heading in $hooks — it CONTAINS the heading '$ext_real'. It resolves only by the reverse arm of the containment match, which silently WIDENS the span to that whole section: you would believe drift was narrowed to a paragraph while the classifier watched everything under that heading. Write the anchor as '$ext_real'."
            ;;
          *)
            err E11 "$(rel "$f"): extends: anchor '$ext_anc' matches no heading in $hooks. The narrowed drift check has no span to watch, so this entry would report clean through every upstream change to the section it augments."
            ;;
        esac
      fi
    fi
  fi

  # `position:` is meaningful only where something renders INSIDE a core section.
  # On any other kind it is a key the loader never reads, which is the same silent
  # no-op E10 exists to stop one field over.
  if [ "$kind" = qualifier ]; then
    [ -n "$extends" ]  || err E12 "$(rel "$f"): kind 'qualifier' requires 'extends:'. A qualifier renders inside a core section, so without the anchor naming that section there is nothing for the loader to render into and nothing for the pull to drift-check."
    [ -n "$position" ] || err E12 "$(rel "$f"): kind 'qualifier' requires 'position:'. The loader has to place this body relative to the core prose it qualifies; undeclared, two readers of the merged section can order it differently and the rendered rulebook stops being one document."
  elif [ -n "$position" ]; then
    err E12 "$(rel "$f"): position '$position' is declared on kind '$kind', which does not render inside a core section. Nothing reads the key here, so it states a placement that never happens. Use kind 'qualifier' if that is what this entry does."
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
    err E14 "$(rel "$f"): gate_types '$gate_types' is declared on kind '$kind'. Only a check is loaded from a GATE_MANIFEST row, so on this kind nothing reads the key and it states a loading rule that never happens. Use kind 'check' if this entry defines gate checks."
  fi

  if [ -n "$position" ]; then
    case "$position" in
      append|prepend) : ;;
      *) err E13 "$(rel "$f"): position '$position' is not 'append' or 'prepend'. Two positions is the whole vocabulary on purpose: a literal-prose anchor would be a THIRD anchor resolver in this repo, and reconcile/lib.sh's header records two shipped defects caused by duplicate resolvers." ;;
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
        check) err E6 "$msg" ;;
        *)     warn W1 "$msg" ;;
      esac
    else
      warn W1 "$(rel "$f"): RESTATES core section '$a.' (\"${t_core:-$a}\") from '$hooks'. Rule 27(c): an extension MUST NOT restate a core section — the copy cannot drift-check against the original, so it forks silently and then contradicts it. If this entry only ADDS to the core check, hook it without redefining the number; if it RESTRICTS core, it is an override wearing extension frontmatter and belongs in overrides/ with a base_sha."
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
      warn W4 "$(rel "$f"): RESTATES core 'Rule $n' (\"$r_core\") from '$hooks'. Rule 27(c): an extension MUST NOT restate a core rule — the copy cannot drift-check against the original, so it forks silently and then contradicts it."
      continue
    fi
    # A labelled heading is the RESOLVED state — same contract as heading_labelled.
    if [ "$(rule_labelled "$f" "$n")" = yes ]; then continue; fi

    warn W4 "$(rel "$f"): RULE NUMBER COLLISION on 'Rule $n' — this defines \"$r_ext\" while core '$hooks' defines \"$r_core\" at the same number. Extensions are ADDITIVE, so both render into one merged rulebook under one integer and a bare \"Rule $n\" in a gate log, retro finding or dispatch brief has two referents. Give this rule a catalog-labelled heading (\"## Rule $n [ext:$id] -- …\") per the Consumer-catalog crosswalk; the integer never moves. \`reconcile/relabel-extension-checks.sh --apply\` writes it."
  done < <(defined_rules "$f")

  # E15 — an allocation from core's range. See the header note for why this is a
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
  # not define never enters that loop, so the relabeller is blind to E15's entire
  # subject set by construction. Prescribing it would hand the operator a tool that
  # exits "no unlabelled core-number collisions" on a tree full of findings.
  while IFS= read -r n; do
    [ -n "$n" ] || continue
    want="$(out_of_band "$n")" || continue
    if grep -Fxq -- "$n" <<<"$core_rules"; then
      err E15 "$(rel "$f"): RULE OUT OF BAND, ALREADY COLLIDED — 'Rule $n' allocates from core's range and core '$hooks' ALREADY defines rule $n. This is not a pending risk; every gate log, retro, escalation and dispatch brief written against a bare \"Rule $n\" has two referents right now, and it acquired the second one retroactively on the day core allocated. A catalog label does not settle it: the label resolves the reference at the point of use from here on and cannot reach back into evidence already written, which is why numbering is a label and not a namespace until the band makes it one. Consumer rules are reserved at ${BAND_FLOOR} and above — renumber to 'Rule $want' or the next free id in your band, and add a crosswalk row in extensions/README.md resolving the bare \"Rule $n\" your existing history already carries."
    else
      err E15 "$(rel "$f"): RULE OUT OF BAND — 'Rule $n' allocates from core's range. Core '$hooks' does not define rule $n TODAY, so no collision is reported and none can be: the collision appears in the release where core allocates $n, retroactively, across every gate log, retro and escalation already written against it. Consumer rules are reserved at ${BAND_FLOOR} and above — renumber to 'Rule $want' or the next free id in your band, and add a crosswalk row in extensions/README.md resolving the bare \"Rule $n\" your existing history already carries. A catalog label does not settle this; it resolves a collision that exists, and the band prevents one that does not yet."
    fi
  done < <(defined_rules "$f")

  # THE SECTION-ID NAMESPACE, AND IT IS NO LONGER SCOPED TO `kind: check`. It was, on
  # the reasoning E6 uses — a step number is a position in an ordered procedure, not an
  # allocation from a namespace. The partition is total instead: the numeric prefix
  # carries the order, so moving the whole consumer range preserves every relative
  # position within it, and what is lost is only the ability to sort a consumer section
  # beside a CORE section of the same number. A consumer section that must render inside
  # a core section is `kind: qualifier` with `extends:`, which is the grain built for it
  # and does not need to borrow core's integer to do it.
  while IFS= read -r a; do
    [ -n "$a" ] || continue
    want="$(out_of_band "$a")" || continue
    # The remedy is quoted in the form the heading actually carries, and the conforming form
    # inherits that terminator by substitution rather than by a second spelling of it. See
    # anchor_form: a hardcoded `.` here named a string absent from two of the reference
    # consumer's headings, and the failure was silent at the point of transcription.
    a_form="$(anchor_form "$f" "$a")"
    want_form="$want${a_form#"$a"}"
    if grep -Fxq -- "$a" <<<"$core_anchors"; then
      err E15 "$(rel "$f"): SECTION ID OUT OF BAND, ALREADY COLLIDED — '$a_form' allocates from core's range and core '$hooks' ALREADY defines '$a.'. Every gate log, retro and escalation written against a bare \"$a\" has two referents right now, and a gate log is the durable audit record, so it cannot be corrected after the fact. A catalog label does not settle it: the label resolves the reference at the point of use from here on and cannot reach back into evidence already written. E6 may be silent on this entry — a labelled heading is E6's resolved state — and that silence is the label doing its job on the reference, not the allocation ceasing to be one. Consumer section ids are reserved at ${BAND_FLOOR} and above, or at the '${BAND_ALPHA_PREFIX}' prefix for alphabetic ids — rename to '$want_form' or the next free id in your band, and add a crosswalk row in extensions/README.md resolving the bare \"$a\" your existing history already carries."
    else
      err E15 "$(rel "$f"): SECTION ID OUT OF BAND — '$a_form' allocates from core's range. Core '$hooks' does not define '$a_form' TODAY, so E6 has nothing to join against and reports clean: the collision appears in the release where core allocates $a, retroactively, across every gate log already written — and a gate log is the durable audit record, so it cannot be corrected after the fact. Consumer section ids are reserved at ${BAND_FLOOR} and above, or at the '${BAND_ALPHA_PREFIX}' prefix for alphabetic ids — rename to '$want_form' or the next free id in your band, and add a crosswalk row in extensions/README.md resolving the bare \"$a\" your existing history already carries."
    fi
  done < <(defined_anchors "$f")

  # E16 — every id this entry has RETIRED needs a crosswalk row resolving it.
  #
  # Both namespaces, and the row may name the id bare (`24`) or namespaced
  # (`Check 24` / `Rule 30`). Bare is accepted because the reference consumer's one
  # existing row is bare and predates the widening; namespaced is what the widened table
  # documents, because a bare `30` cannot say whether it resolves a check or a rule once
  # the table carries both.
  if [ "$CROSSWALK_STATE" = ok ]; then
    if git -C "$PROJECT_ROOT" ls-files --error-unmatch -- "$f" >/dev/null 2>&1; then
      for _ns in anchors rules; do
        case "$_ns" in
          anchors) _mine="$(defined_anchors "$f")"; _now="$LIVE_ANCHORS"; _was="$(historical_ids "$f" defined_anchors)"; _lbl='' ;;
          rules)   _mine="$(defined_rules "$f")";   _now="$LIVE_RULES";   _was="$(historical_ids "$f" defined_rules)";   _lbl='Rule ' ;;
        esac
        # A TRACKED file whose history yields no id IT currently defines is the
        # unreadable case, not a clean one: the diff sweep found nothing where the
        # working tree plainly has something.
        #
        # THE GUARD COMPARES AGAINST THIS FILE'S OWN IDS, not the resolvability set,
        # and the first version got that wrong in a way worth recording. `$_now` is the
        # rendered rulebook's whole live set and is never empty, so `[ -n "$_now" ]` was
        # true for every entry — including the great majority that define no RULE at
        # all — and the guard fired 51 times on a tree with nothing wrong with it. A zero
        # guard that cannot tell "this file has no rules" from "I could not read this
        # file's rules" is noise, and noise is how a real refusal gets scrolled past.
        if [ -n "$_mine" ] && [ -z "$_was" ]; then
          crosswalk_unreadable "$(rel "$f") (${_ns})"
          continue
        fi
        while IFS= read -r _rid; do
          [ -n "$_rid" ] || continue
          grep -Fxq -- "$_rid" <<<"$CROSSWALK_IDS" && continue
          grep -Fxq -- "${_lbl}${_rid}" <<<"$CROSSWALK_IDS" && continue
          grep -Fxq -- "Check ${_rid}" <<<"$CROSSWALK_IDS" && continue
          err E16 "$(rel "$f"): RETIRED ID WITH NO CROSSWALK ROW — this entry used to define '${_lbl}${_rid}' and no longer does, and the crosswalk file (${CROSSWALK_REL:-undeclared}) carries no row resolving it. Every gate log, retro and escalation written while it was live cites a bare \"${_lbl}${_rid}\", those citations are permanent, and no renumber can reach back into them — the row is the only thing that keeps them resolvable. Add one naming '${_lbl}${_rid}', the id it became, and the title, then this clears. Core does NOT claim to check the table's completeness against your evidence and cannot; it checks the one thing it can see, which is an id leaving this entry."
        done < <(comm -23 <(printf '%s\n' "$_was" | sort -u) <(printf '%s\n' "$_now" | sort -u))
      done
    fi
  else
    crosswalk_unreadable "$(rel "$f")"
  fi

  # W2 — a restriction in an additive layer is a mis-filed override.
  if grep -Eqi 'only[^.]{0,60}(are|is) valid|is NOT subject to|are the only valid' "$f"; then
    warn W2 "$(rel "$f"): contains restricting language (\"only … are valid\" / \"is NOT subject to\"). An extension ADDS behavior; a restriction on a core rule belongs in overrides/ with a base_sha so drift is tracked."
  fi
done < <(layer_files "$EXT_DIR")

# E16's degraded mode, emitted ONCE per run rather than once per entry: on a clone with
# no usable history every entry lands here, and a wall of identical lines is a wall an
# operator scrolls past. One line, counted and naming its subjects. It is an ERROR and
# not a note, because "no retired ids" and "I could not look" are the same output
# otherwise — which is precisely the state this arm was built to end.
if [ "$CROSSWALK_UNREADABLE_N" -gt 0 ]; then
  case "$CROSSWALK_STATE" in
    no-git)  cw_why="this project root is not inside a git work tree" ;;
    shallow) cw_why="this is a SHALLOW clone, so the id history is truncated at the graft boundary and an id retired before it is invisible" ;;
    *)       cw_why="the file is tracked but its diff history yielded none of the ids it currently defines" ;;
  esac
  err E16 "RETIRED-ID HISTORY UNREADABLE — E16 could not be evaluated for ${CROSSWALK_UNREADABLE_N} entr(y/ies) because ${cw_why}. These were NOT judged clean, they were not judged at all: ${CROSSWALK_UNREADABLE}. Re-run in a full clone (\`git fetch --unshallow\`) before reading the crosswalk as complete."
fi

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
    warn W3 "$(rel "$f"): references \"Step $ref\" but no core file, extension, or override defines Step $ref anywhere in the rendered rulebook — dangling step pointer"
  done < <(grep -Eoh 'Step[ -][0-9]+[a-z-]*' "$f" 2>/dev/null | sed -E 's/^Step[ -]//' | sort -u)
done <<< "$all_files"

# ---------------------------------------------------------------------------
# W9 — a SCRIPT path a layer entry names that resolves nowhere in this project
# ---------------------------------------------------------------------------
# THE THIRD NAMESPACE. W3 resolves `Step <n>`, W7 resolves `Check <n>`; both ask whether a
# citation still points at something. An entry also cites EXECUTABLES, and nothing asked the
# question of those. Found by measurement on the reference consumer, not by reading the code:
# two entries name a script that has NEVER existed in that repo's history, and both are
# agent-facing instructions rather than prose about a mechanism —
#
#   a step's own command list:   - ./scripts/smoke-test.sh
#   a role file's Required: clause naming a wrapper "which handles backgrounding internally"
#
# A dispatched agent reads either one and runs a file that is not there. Nothing in the
# rendered rulebook, in either pre-push hook, or in this validator noticed, across the whole
# life of both citations.
#
# ROOT-ANCHORED, and the anchoring is what keeps the distribution's own paths out. The token
# is captured WITH any leading path segments and then required to start at the project root:
# `./scripts/x.sh` normalises to `scripts/x.sh` and is checked, while `core/scripts/x.sh` —
# a distribution path an entry may legitimately name in prose — is not a consumer-root path
# and is dropped. That is a derivation, not a carve-out: the arm resolves paths against
# PROJECT_ROOT, so a token that is not relative to PROJECT_ROOT is not its subject.
#
# FENCED BLOCKS ARE SKIPPED, and the cost of that is stated rather than hidden. I68's finding
# was a reader that did not skip fences importing core's own worked examples into every
# consumer; the same trap is live here, because an entry's fenced block is where illustrative
# invocations sit. The cost is real: on the reference consumer the skip drops one GENUINE
# command citation (`python3 scripts/check_deployed_ranges_consistency.py`, inside a fenced
# block, resolving). So a dangling path that appears ONLY inside a fence is outside this
# arm's subject set by construction, and this comment is where that is recorded.
#
# WARN, NOT ERROR, and the false-positive set is enumerated rather than claimed empty.
# Measured over the reference consumer's 52 entries: 82 unfenced root-anchored occurrences,
# 34 distinct paths, 32 resolving, 2 not — and both of the 2 are real. The one FP category
# with a live SHAPE is retirement narration: an entry correctly reporting that a script WAS
# retired names a path that no longer resolves. There is no live instance today (the one
# candidate, `scripts/scan-stray-provenance.sh`, still exists), but the shape is real and it
# is why an ERROR here would eventually wedge a consumer for writing true prose.
echo "== script citations =="
while IFS= read -r f; do
  [ -n "$f" ] || continue
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    [ -e "$PROJECT_ROOT/$p" ] && continue
    warn W9 "$(rel "$f"): names \`$p\`, and no such file exists in this project. A layer entry that cites an executable is telling a dispatched agent to run it; a citation that resolves nowhere is an instruction that fails at the moment it is followed. Either the path is stale and should be repointed or removed, or the file was never added. If this line is PROSE recording that the script was retired, name it without a runnable path."
  done < <(awk '
    /^[[:space:]]*```/ { fence = 1 - fence; next }
    fence { next }
    {
      s = $0
      while (match(s, /[A-Za-z0-9_.\/-]*scripts\/[A-Za-z0-9_.\/-]+\.(sh|py)/)) {
        t = substr(s, RSTART, RLENGTH)
        s = substr(s, RSTART + RLENGTH)
        sub(/^\.\//, "", t)
        if (t ~ /^scripts\//) print t
      }
    }
  ' "$f" 2>/dev/null | sort -u)
done < <({ layer_files "$EXT_DIR"; layer_files "$OVR_DIR"; })

# W7 — the same question in the CHECK namespace, and it is a different subject from W3's.
#
# WHY IT IS OWED, measured rather than argued. The band migration renames consumer ids into
# the reserved range, and nothing joined "an id was renamed" to "the prose that cites it".
# Run against the reference consumer's migration, the renames orphaned three `Check 19b`
# citations across three files — one of them a group HEADING inside the very file that
# renamed the id, `## Check 19b` sitting directly above `### 919b.`. W3 caught none of them:
# its grammar is `Step`, and a check id is not a step id. The four dangling pointers W3 DID
# catch during that migration were luck of overlap, not coverage.
#
# THE RESOLVER IS THE CROSSWALK, and that is the mechanism working rather than an exclusion.
# A citation resolves if the rendered rulebook still defines the anchor, OR if the crosswalk
# table carries a row for it — which is the row's entire stated purpose: a gate log citing a
# retired id is permanent and the row is the only thing that keeps it resolvable. So a
# complete migration clears this arm, and the arm is one more statement that the standard is
# satisfiable.
#
# NOT SUBSUMED BY E16, and the reference consumer carries the proof. E16 is keyed on the
# entry's OWN history — an id this file used to define. W7 is keyed on the CITATION SITE, so
# it sees an id no surviving entry ever defined: `Check 11b`, cited in a step-domain entry,
# defined nowhere, absent from the crosswalk, and invisible to every other arm in this file
# both before and after the migration.
#
# NUMERIC-LEADING, exactly as W3 is, and the restriction is what keeps the false-positive set
# empty rather than a hand-list. Core prose uses `Check A`…`Check E` and `Check N` as
# placeholders in worked examples; an alphabetic grammar harvests all of them and has no
# remedy to offer for any. Measured on the reference consumer, numeric-leading: FIVE subjects
# before the migration (`33`, `34` x3, `11b`), every one of them a genuine citation of an id
# the rulebook does not define, and ZERO false positives.
#
# WARN, not ERROR, and the reason is the subject set rather than the severity of the defect:
# four of those five predate the layer contract entirely, and erroring would wedge a
# consumer's pre-push on prose it wrote before the rule existed. §4b's ERROR ruling is about
# the naming partition, whose remedy the validator itself prints for every subject; here the
# remedy is a judgement about what the author meant.
GLOBAL_CHECK_ANCHORS="$(while IFS= read -r f; do [ -n "$f" ] && defined_anchors "$f"; done <<< "$all_files" | sort -u)"

while IFS= read -r f; do
  [ -n "$f" ] || continue
  while IFS= read -r ref; do
    [ -n "$ref" ] || continue
    grep -Fxq -- "$ref" <<<"$GLOBAL_CHECK_ANCHORS" && continue
    grep -Fxq -- "$ref" <<<"$CROSSWALK_IDS" && continue
    grep -Fxq -- "Check $ref" <<<"$CROSSWALK_IDS" && continue
    warn W7 "$(rel "$f"): references \"Check $ref\" but no core file, extension, or override defines check $ref anywhere in the rendered rulebook, and the crosswalk file (${CROSSWALK_REL:-undeclared}) carries no crosswalk row resolving it — dangling check pointer. Either repoint the citation at the id the check carries today, or add a crosswalk row naming '$ref', the id it became, and the title. A renumber into the reserved band does not reach back into prose that cites the old id, which is how these are made."
  done < <(grep -Eoh 'Check[ -][0-9]+[a-z-]*' "$f" 2>/dev/null | sed -E 's/^Check[ -]//' | sort -u)
done <<< "$all_files"

echo
printf 'validate-layer-entries: %d error(s), %d warning(s)\n' "$ERRORS" "$WARNS"

# THE MACHINE FOOTER. Specified with the contract at v0.181.0 and never built — 0 occurrences
# repo-wide, against 7 for `LAYER_CONTRACT` in the same sweep. It is one printf, and what it
# buys is unforgeability: a lead reporting conformance in a gate log can transcribe "0 errors"
# from memory, but not `entries=50 at_current=38 behind=12` — those are run-specific counts that
# do not exist until this script has walked the tree. That is the same argument that put
# run-specific counts in H1's fixture criterion and in the ledger report headings.
#
# `contract_version=-` is the honest reading when the contract could not be read at all: the
# fields below are then counts over zero entries, and printing a plausible 0 there would make an
# unevaluated consumer and a conforming one produce the same line.
printf 'LAYER_CONFORMANCE v1 contract_version=%s entries=%d at_current=%d behind=%d undeclared=%d errors=%d warnings=%d\n' \
  "${LC_CV:--}" "$LC_ENTRIES" "$LC_CURRENT" "$LC_BEHIND" "$LC_UNDECLARED" "$ERRORS" "$WARNS"

# THE MEASURED CENSUS — `measured{fires,of}`, the charter's last unbuilt contract field.
#
# WHY IT IS EMITTED AND NOT STORED. The charter asked for `measured{fires,of,fp}` as a row
# in layer-contract.yaml. A stored count is writable without the run, which is the exact
# forgeability test v0.123.0 put on evidence cells, and a hand-maintained fourth field is
# the drift shape `level:` sat in for six versions. So the count is produced here, per code,
# by the emitters themselves: `fires` is what this run actually reported and `of` is the
# subject population it reported against.
#
# WHAT THE READER IS FOR. `silent_with_subjects` is the charter's own sentence as a number —
# a clause whose `fires` is 0 against a non-empty `of` is a check that did not fire on
# anything it was given. On a CONFORMING consumer that number is high and correct, which is
# why this line is data and not a verdict: the reading that means something is the one taken
# across the fixture suite, where a mutant seeds each clause's violation and the clause that
# still reads 0 is the one that cannot fire. `fixture:` is the stored half of the same
# question and I64 binds it.
#
# `contract_version=-` and `measured=-` are the honest readings when the contract could not
# be read: the populations below are still real, but nothing maps a code to a subject, and
# printing an empty census would make an unevaluated run and a clean one produce one line.
lc_m_n=0; lc_m_fired=0; lc_m_silent=0; lc_m_list=''
if [ -n "$LC_CODE_ROWS" ]; then
  while read -r lc_m_code lc_m_clause lc_m_subj lc_m_enf; do
    [ "${lc_m_enf:-}" = validate-layer-entries.sh ] || continue
    case "$lc_m_subj" in
      override)  lc_m_of=$LC_N_OVERRIDE ;;
      extension) lc_m_of=$LC_N_EXTENSION ;;
      *)         lc_m_of=$((LC_N_OVERRIDE+LC_N_EXTENSION)) ;;
    esac
    # `grep -c` exits 1 on zero matches and prints the 0 anyway; the `|| true` keeps the
    # count and not the exit code. It reads the whole stream, so there is no early-close
    # EPIPE here — the trap I54 exists for is `grep -q`, which this deliberately is not.
    lc_m_f="$(printf '%s\n' $LC_FIRED | grep -Fxc -- "$lc_m_code" || true)"
    lc_m_n=$((lc_m_n+1))
    if [ "$lc_m_f" -gt 0 ]; then
      lc_m_fired=$((lc_m_fired+1))
    elif [ "$lc_m_of" -gt 0 ]; then
      lc_m_silent=$((lc_m_silent+1))
    fi
    lc_m_list="${lc_m_list}${lc_m_list:+,}${lc_m_code}=${lc_m_clause}:${lc_m_f}/${lc_m_of}"
  done <<EOF
$LC_CODE_ROWS
EOF
fi
# UNCLAIMED — a code this run REPORTED that the installed contract claims from no clause.
#
# This is I36's reverse direction asked at run time, in the consumer, and it is not a
# theoretical arm: the first run of this census against the reference consumer reported 103
# errors with `fired=0`, because that consumer's INSTALLED contract is at version 7 while its
# validator emits E15/E16/E17. Every one of those findings reached an operator with no clause
# behind it in the contract they actually hold — which is the state I36 forbids in the
# distribution and nothing was watching for in the consumer. It is the sharpest single
# signal that a pull landed one half of a release.
#
# Reported, never blocking: the remedy is a pull, and a validator that refuses until the
# consumer has pulled is one that cannot be run to find out what to pull.
lc_m_unclaimed=''
if [ -n "$LC_CODE_ROWS" ]; then
  while read -r lc_m_c; do
    [ -n "$lc_m_c" ] || continue
    awk -v c="$lc_m_c" '$1 == c { found=1 } END { exit !found }' <<<"$LC_CODE_ROWS" && continue
    lc_m_unclaimed="${lc_m_unclaimed}${lc_m_unclaimed:+,}${lc_m_c}"
  done < <(printf '%s\n' $LC_FIRED | grep -E '.' | sort -u)
fi

# A `-` in every derived cell, never a plausible 0. The populations stay numeric because the
# passes counted them without the contract's help, and saying so is the point of the split.
if [ "$lc_m_n" -eq 0 ]; then lc_m_n='-'; lc_m_fired='-'; lc_m_silent='-'; fi
printf 'LAYER_MEASURED v1 enforcer=validate-layer-entries.sh contract_version=%s codes=%s fired=%s silent_with_subjects=%s unclaimed=%s subjects=override:%d,extension:%d measured=%s\n' \
  "${LC_CV:--}" "$lc_m_n" "$lc_m_fired" "$lc_m_silent" "${lc_m_unclaimed:-none}" \
  "$LC_N_OVERRIDE" "$LC_N_EXTENSION" "${lc_m_list:--}"
[ "$ERRORS" -eq 0 ]
