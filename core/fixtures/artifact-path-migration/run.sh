#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
# artifact-path-migration — migrate-artifact-paths.sh moves every path onto the declared
# grammar, REFUSES what it cannot derive, and its own output conforms to the rule it enforces.
#
# THE DEFECTS THIS EXISTS TO CATCH, every one of them measured on the reference consumer while
# the script was being written. None was found by reading it.
#
#  - MATCHING THE WHOLE PATH WITH A COMPONENT REGEX. The token boundary is `^` or `-`, and a
#    path separator is neither, so `docs/retro/sprint-299.md` matched NOTHING. 668 files were
#    detected instead of 2551 and `docs/retro` was absent from the plan entirely.
#  - ADJACENT TOKENS HIDING EACH OTHER. `grep -o` and `sed ...g` both consume the separator the
#    next token needs, so `gate-log-archive-s291-s292.md` reported ONE sprint. That is not a
#    cosmetic miss: a file naming two sprints was planned as if it named one, and would have
#    been filed under the wrong sprint permanently.
#  - THE SLOT NESTED INSIDE THE TOKEN IT REPLACES. A basename-only transform produced
#    `implementation-artifacts/sprint-287/smoke-evidence/s287/foo.md` on 53 directories --
#    output that breaks the grammar the script exists to impose.
#  - A HALF-MIGRATED STORY CORPUS. `story-S298-1-x.md` carries a matchable token and
#    `story-297-1-x.md` does not, so a run over `stories/` moves one sibling and leaves the
#    other. Split conventions inside one sprint are worse than one wrong convention.
#
# THE VERDICT IS NEVER TRUSTED. Every assertion below reads the TREE -- what exists, what does
# not, and whether the bytes survived -- rather than the script's own summary line. A migration
# that printed "2670 verified" while moving nothing would pass a report-reading fixture.
#
# Per push each mutant runs its deciding arm and one twin; the measured matrix replaces an
# exact-vector assertion. The matrix is re-measured as .claude/rules/fixture-mutants.md clause 2 ("One
# run per distinct state") requires. Arm names are the
# column names `--matrix` prints (T-* read the tree after --apply, R-* read the report).
# MUTANT-MATRIX ambiguity-allowed decides=T-ambig twins=T-conform
# MUTANT-MATRIX stories-half-migrated decides=T-storybeta twins=T-storyalpha
# MUTANT-MATRIX story-slot-blind decides=T-conform twins=T-storyalpha
# MUTANT-MATRIX hdr-over-name-off decides=T-hdr twins=T-storyalpha
# MUTANT-MATRIX consumer-areas decides=R-areas twins=T-conform
# MUTANT-MATRIX remedy-root-mig decides=R-remedy-mig twins=T-conform
# MUTANT-MATRIX remedy-root-val decides=R-remedy-val twins=T-conform
# MUTANT-MATRIX fork-sprints-in decides=R-forks twins=R-progress
# MUTANT-MATRIX fork-strip-token decides=R-forks twins=R-progress
# MUTANT-MATRIX fork-nhits decides=R-forks twins=R-progress
# MUTANT-MATRIX progress-stdout decides=R-progress twins=T-conform
# MUTANT-MATRIX progress-none decides=R-progress twins=T-conform
# MUTANT-MATRIX apply-per-file decides=R-applyscale twins=R-progress
# MUTANT-MATRIX verify-rollback-off decides=A-verify twins=A-crlf
# MUTANT-MATRIX stage-bound-short decides=A-verify twins=A-crlf
# MUTANT-MATRIX hash-path-guard-off decides=A-read twins=A-quote
# MUTANT-MATRIX stage-rollback-off decides=A-stage twins=A-crlf
# MUTANT-MATRIX stage-add-rehash decides=A-crlf twins=A-stage
# MUTANT-MATRIX quoted-read decides=A-quote twins=A-crlf
# MUTANT-MATRIX unsafe-early decides=A-quote twins=A-crlf
# MUTANT-MATRIX-DYNAMIC mutant_score-name why=mutant_score() passes its first argument "$n" to mutant_killed; each mutant_score call (ambiguity-allowed, stories-half-migrated, ...) names a literal mutant that carries its own row in this block
# MUTANT-MATRIX-REMEASURE bash core/fixtures/artifact-path-migration/run.sh --matrix
#
# Usage: run.sh [--matrix]
set -uo pipefail

# HERMETIC -- scrub the operator's tuning before invoking anything (I10). The migration calls
# artifact-path-config.sh --consumer-file without --root, and that helper takes
# AI_DLC_PROJECT_ROOT ahead of its own walk; an inherited override makes it read a tree other
# than the seeded one every arm below is judging.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }

# install.sh maps core/scripts/<x> -> scripts/ai-dlc/<x>; core/skills/ai-dlc/ -> .claude/skills/ai-dlc/.
MIG="$(pick "$HERE/../../scripts/migrate-artifact-paths.sh" \
            "$HERE/../../../scripts/ai-dlc/migrate-artifact-paths.sh" \
            "$HERE/../../core/scripts/migrate-artifact-paths.sh")"
GRAMMAR="$(pick "$HERE/../../skills/ai-dlc/artifact-path-grammar.md" \
                "$HERE/../../../.claude/skills/ai-dlc/artifact-path-grammar.md" \
                "$HERE/../../core/skills/ai-dlc/artifact-path-grammar.md")"
# The migration resolves the grammar, the areas and the sprint-token expression through this
# sibling rather than carrying its own copy, so every mutant tree below has to hold BOTH files.
# A lone copy exits 2 at its first line, emits nothing, and "no output" otherwise scores as a
# kill -- which is what the unmutated control exists to catch, and did.
CONFIG="$(pick "$HERE/../../scripts/artifact-path-config.sh" \
               "$HERE/../../../scripts/ai-dlc/artifact-path-config.sh" \
               "$HERE/../../core/scripts/artifact-path-config.sh")"
[ -n "$MIG" ] && [ -n "$GRAMMAR" ] && [ -n "$CONFIG" ] \
  || { echo "FIXTURE ERROR: cannot locate migrate-artifact-paths.sh, artifact-path-config.sh and/or artifact-path-grammar.md" >&2; exit 2; }
# Reached only once the subject resolved; printed as the resolved physical path, never one with `..`.
echo "HERMETIC-CONSUMED $(cd "$(dirname "$MIG")" && pwd -P)/$(basename "$MIG")"

# Lay down a runnable PAIR: the migration and the resolver it calls, side by side the way
# install.sh puts them. Mutants sed one of the two in place afterwards.
lay_pair() { mkdir -p "$1"; cp "$MIG" "$1/m.sh"; cp "$CONFIG" "$1/artifact-path-config.sh"; }

fails=0; asserts=0
ok()  { asserts=$((asserts+1)); printf '  ok    %s\n' "$1"; }
bad() { asserts=$((asserts+1)); fails=$((fails+1)); printf '  FAIL  %s\n' "$1"; }
has() { [ -f "$1/$2" ]; }

echo "artifact-path-migration:"
MATRIX=0; MROWS=0
if [ "${1:-}" = "--matrix" ]; then MATRIX=1; fi
. "$HERE/../lib/mutant.sh" || { echo "FIXTURE ERROR: lib/mutant.sh not found" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"
. "$HERE/matrix.sh" || { echo "FIXTURE ERROR: matrix.sh not found" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/fixtures/artifact-path-migration/matrix.sh"

# ONE seeded world, cloned per question. seed.sh is a pure function of the grammar (two git commits
# and ~45 files), and every arm below wants a PRISTINE copy of exactly that world, so it is built
# once and `cp -R`'d; seeding it nine times answered the same question nine times. The clone is a
# whole git work tree, so each arm still mutates its own.
TPL="$(bash "$HERE/seed.sh" "$GRAMMAR")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
clone_world() {
  local d; d="$(mktemp -d "${TMPDIR:-/tmp}/apmig-cl-XXXXXX")" || return 1
  cp -R "$TPL/." "$d" || return 1
  printf '%s\n' "$d"
}

# =============================================================================
# 1. DRY RUN WRITES NOTHING. The default must be safe, or the first run of a
#    2600-file mover on a real tree is an experiment.
# =============================================================================
W="$(clone_world)"
BEFORE="$(cd "$W" && git status --porcelain | wc -l | tr -d ' ')"
OUT="$(bash "$MIG" --root "$W" 2>&1)"; RC=$?
AFTER="$(cd "$W" && git status --porcelain | wc -l | tr -d ' ')"
[ "$RC" -eq 0 ] && ok "dry run exits 0 when there is work to do" \
                || bad "dry run exited $RC, expected 0"
[ "$BEFORE" = "0" ] && [ "$AFTER" = "0" ] \
  && ok "dry run left the work tree untouched (git reports no change)" \
  || bad "dry run MODIFIED the tree — porcelain went '$BEFORE' -> '$AFTER'"
has "$W" "docs/retro/sprint-301.md" \
  && ok "...and the source files are all still where they were" \
  || bad "a source file moved during a DRY RUN"
case "$OUT" in *"DRY RUN"*) ok "the dry run says so in its own output" ;;
               *) bad "the dry run does not announce itself; an operator cannot tell the two modes apart" ;; esac

# THE SELF-CHECK MUST BE PRESENT AND ZERO. It is the one arm that catches the script writing
# paths its own grammar rejects, and it reports on both roads.
case "$OUT" in
  *"outside the slot: 0"*) ok "self-check: no planned destination carries a token outside the slot" ;;
  *) bad "self-check missing or non-zero — the plan contains paths the grammar rejects" ;;
esac

# =============================================================================
# 2. APPLY — every transform property, asserted against the TREE.
# =============================================================================
OUT="$(bash "$MIG" --root "$W" --apply 2>&1)"; RC=$?
[ "$RC" -eq 0 ] && ok "apply exits 0" || { bad "apply exited $RC"; printf '%s\n' "$OUT" | tail -5 | sed 's/^/        /'; }

# $1 label  $2 destination that MUST exist  $3 source that MUST be gone  $4 why
moved() {
  asserts=$((asserts+1))
  if has "$W" "$2" && ! has "$W" "$3"; then printf '  ok    %-26s %s\n' "$1" "$4"
  else fails=$((fails+1)); printf '  FAIL  %-26s %s\n           dest %s: %s / src %s: %s\n' "$1" "$4" \
       "$2" "$(has "$W" "$2" && echo present || echo MISSING)" \
       "$3" "$(has "$W" "$3" && echo STILL-THERE || echo gone)"; fi
}

moved "basename-prefix"  "_bmad-output/planning-artifacts/s301/research-notes.md" \
                         "_bmad-output/planning-artifacts/s301-research-notes.md" \
                         "s<N>- prefix moves into the directory"
moved "basename-word"    "_bmad-output/party-mode-transcripts/s301/retro.md" \
                         "_bmad-output/party-mode-transcripts/sprint-301-retro.md" \
                         "the sprint-<N>- word form too"
moved "basename-suffix"  "_bmad-output/implementation-artifacts/s301/gate-log-archive.md" \
                         "_bmad-output/implementation-artifacts/gate-log-archive-s301.md" \
                         "and the SUFFIX position, which is why a prefix filter was never enough"
moved "strips-to-nothing" "docs/retro/s301/retro.md" \
                         "docs/retro/sprint-301.md" \
                         "a nameless basename takes the name of what contained it"
moved "strips-to-nothing-2" "_bmad-output/implementation-artifacts/s301/sprint-status.yaml" \
                         "_bmad-output/implementation-artifacts/sprint-status/sprint-301.yaml" \
                         "...and the promoted directory does not also remain a directory"
moved "directory-token"  "_bmad-output/implementation-artifacts/s301/smoke-evidence/shot.png" \
                         "_bmad-output/implementation-artifacts/sprint-301/smoke-evidence/shot.png" \
                         "a token in a DIRECTORY moves too, subdirectories intact"
moved "dir-and-basename" "_bmad-output/planning-artifacts/s301/archive/cycle-1/prd-adversarial-p2.md" \
                         "_bmad-output/planning-artifacts/archive/s301-cycle-1/prd-adversarial-s301-p2.md" \
                         "both at once collapse to ONE slot under the area"
moved "root-log-archive" "_bmad-output/implementation-artifacts/s301/pipeline-continuation-log-archive.md" \
                         "_bmad-output/pipeline-continuation-log-archive-s301.md" \
                         "a rotation archive at _bmad-output/ root lands in implementation-artifacts"
moved "inferred-area"    "_bmad-output/brainstorming/s301/brainstorm-ideas.md" \
                         "_bmad-output/brainstorming/brainstorm-s301-ideas.md" \
                         "an UNDECLARED area still migrates"
moved "inferred-area-token" "_bmad-output/party-verdicts-retro/s301/pm.md" \
                         "_bmad-output/party-verdicts-s301-retro/pm.md" \
                         "an inferred area's OWN token is stripped before it anchors the slot"
moved "uppercase-S"      "docs/reviews/s301/1-code-review.md" \
                         "docs/reviews/S301-1-code-review.md" \
                         "S<N> normalises to the one legal spelling"

# ALREADY CONFORMING FILES ARE NOT TOUCHED. A migration that rewrites correct paths churns the
# tree and breaks citations for nothing.
has "$W" "_bmad-output/planning-artifacts/s301/architecture-context.md" \
  && ok "a path already in the slot is left alone" \
  || bad "an ALREADY CONFORMING path was moved"
has "$W" "_bmad-output/planning-artifacts/prd.md" \
  && ok "a durable area-root file with no sprint is left alone" \
  || bad "a durable file with no sprint token was moved"

# =============================================================================
# 3. REFUSALS — each one stays put, and is NAMED.
# =============================================================================
# $1 label  $2 path that must still exist  $3 reason token in the report  $4 why
refused() {
  asserts=$((asserts+1))
  if has "$W" "$2" && grep -q "$3" <<<"$OUT"; then printf '  ok    %-26s %s\n' "$1" "$4"
  else fails=$((fails+1)); printf '  FAIL  %-26s %s\n           still present: %s / report names %s: %s\n' "$1" "$4" \
       "$(has "$W" "$2" && echo yes || echo NO-IT-MOVED)" "$3" \
       "$(grep -q "$3" <<<"$OUT" && echo yes || echo NO)"; fi
}

refused "adjacent-tokens" "_bmad-output/implementation-artifacts/gate-log-archive-s298-s299.md" \
        "AMBIGUOUS" "two ADJACENT tokens are seen as two sprints, not one"
refused "tokens-disagree" "_bmad-output/planning-artifacts/archive/s300-cycle-1/notes-s295.md" \
        "AMBIGUOUS" "a directory and a basename naming different sprints is refused"
refused "no-area"         "_bmad-output/s177/wave-1-dispatch-status.md" \
        "NO-AREA" "a sprint dir under a non-area scan root has nothing to anchor to"

# THE STORY CORPUS: BOTH SPELLINGS MOVE, OR NEITHER. Still the anti-half-migration arm; what
# changed is which side of it is correct. The explicit-token file and the bare-number file must
# reach the SAME shape under their own sprints, and the sprint must be gone from both basenames.
moved "story-token"      "_bmad-output/planning-artifacts/s301/stories/story-1-alpha.md" \
                         "_bmad-output/planning-artifacts/stories/story-S301-1-alpha.md" \
                         "an explicit-token story lands under its sprint, sprint out of the name"
moved "story-bare-number" "_bmad-output/planning-artifacts/s297/stories/story-1-beta.md" \
                         "_bmad-output/planning-artifacts/stories/story-297-1-beta.md" \
                         "a BARE-number story lands the same way — read from position, not name"

# A story already on the grammar is untouched, and its INDEX is not read as a sprint. Without the
# `s<N>/`-above-it test this file would be "migrated" to s12/, which is the reading the deferral
# was afraid of — correctly, just in the wrong place.
asserts=$((asserts+1))
if has "$W" "_bmad-output/planning-artifacts/s299/stories/story-299-3-gamma.md" \
   && ! has "$W" "_bmad-output/planning-artifacts/s299/stories/story-3-gamma.md"; then
  printf '  ok    %-26s %s\n' "story-index-not-sprint" "a conforming story is left alone; its index is not read as a sprint"
else
  fails=$((fails+1))
  printf '  FAIL  %-26s %s\n' "story-index-not-sprint" "a story ALREADY under s299/ was re-read: index 12 became a sprint slot"
fi

refused "story-no-sprint" "_bmad-output/planning-artifacts/stories/bug-mobile-layout.md" \
        "STORY-NO-SPRINT" "a story with no sprint in its name OR its body is refused, not guessed"

# =============================================================================
# 3b. SPRINT RECOVERY — read the FILE before refusing, header first.
# =============================================================================
# The refusal this replaces prescribed a rename as the only remedy, and the reference consumer's
# own migration commit places all 23 of the files it refused as PURE DIRECTORY MOVES -- 0
# insertions, 0 deletions -- so nobody ever renamed one. Each arm below asserts the DESTINATION,
# not the report: a recovery that reports the right sprint and files the file somewhere else is
# the failure that matters.

moved "recover-header"   "_bmad-output/planning-artifacts/s72/stories/bug-124-deployed-range.md" \
                         "_bmad-output/planning-artifacts/stories/bug-124-deployed-range.md" \
                         "a story with no sprint in its path is placed from its **Sprint:** header"
# THE PRECEDENCE ARM, AND IT IS THE ONE THAT SEPARATES THE TWO CHANNEL ORDERS. The file above
# opens with 124 and declares 72. Asking the basename first puts it under s124 -- a slot that is
# WRONG rather than merely absent, and silent. Asserting the destination is s72 is not enough on
# its own: this asserts the wrong slot was not created at all.
asserts=$((asserts+1))
if ! has "$W" "_bmad-output/planning-artifacts/s124/stories/bug-124-deployed-range.md"; then
  printf '  ok    %-26s %s\n' "recover-precedence" "the HEADER outranks the basename: no s124/ slot was created"
else
  fails=$((fails+1))
  printf '  FAIL  %-26s %s\n' "recover-precedence" "the basename won: 124 is a carry-over ITEM, the header said sprint 72"
fi

moved "recover-header-prose" "_bmad-output/planning-artifacts/s18/stories/bug-dashboard-portfolio.md" \
                         "_bmad-output/planning-artifacts/stories/bug-dashboard-portfolio.md" \
                         "a header carrying trailing prose still resolves"
moved "recover-subject"  "_bmad-output/planning-artifacts/s192/stories/192-ff-A-token-decimals.md" \
                         "_bmad-output/planning-artifacts/stories/192-ff-A-token-decimals.md" \
                         "with no header, the leading number in the basename places it"
# The header expression is anchored at line start, so `**Epic:** Sprint 131b` and
# `**QA agent:** Sprint 158-hotfix` are mentions rather than declarations. If either were read this
# file would land under s131.
moved "recover-not-a-mention" "_bmad-output/planning-artifacts/s158/stories/hotfix-158-1-token0-fixes.md" \
                         "_bmad-output/planning-artifacts/stories/hotfix-158-1-token0-fixes.md" \
                         "a mid-line 'Sprint 131b' mention is not read as the file's declaration"

# BL-214: A READABLE HEADER OUTRANKS THE LEADING NUMBER OF `story-<A>-<B>`, not only when the path
# is silent. `A` is the carry-over ITEM in the pre-s199 era; the consumer's own file declares 53 and
# was filed under s102. Each arm asserts the destination AND that the name's slot was not created.
moved "hdr-over-name"    "_bmad-output/planning-artifacts/s53/stories/story-1-effective-spread-500.md" \
                         "_bmad-output/planning-artifacts/stories/story-102-1-effective-spread-500.md" \
                         "**Sprint:** 53 on story-102-1 lands s53, not the item number's s102"
asserts=$((asserts+1))
if [ ! -d "$W/_bmad-output/planning-artifacts/s102" ]; then
  printf '  ok    %-26s %s\n' "hdr-over-name-no-s102" "no s102/ slot was created for the item number"
else
  fails=$((fails+1)); printf '  FAIL  %-26s %s\n' "hdr-over-name-no-s102" "s102/ exists: the item number was read as the sprint"
fi
moved "hdr-over-name-3dig" "_bmad-output/planning-artifacts/s185/stories/story-1-three-digit.md" \
                         "_bmad-output/planning-artifacts/stories/story-230-1-three-digit.md" \
                         "three digits each side: **Sprint:** 185 on story-230-1 lands s185"
asserts=$((asserts+1))
if [ ! -d "$W/_bmad-output/planning-artifacts/s230" ]; then
  printf '  ok    %-26s %s\n' "hdr-over-name-no-s230" "no s230/ slot was created for the item number"
else
  fails=$((fails+1)); printf '  FAIL  %-26s %s\n' "hdr-over-name-no-s230" "s230/ exists: the item number was read as the sprint"
fi
moved "hdr-agrees-name"  "_bmad-output/planning-artifacts/s296/stories/story-2-delta.md" \
                         "_bmad-output/planning-artifacts/stories/story-296-2-delta.md" \
                         "near-miss: a header AGREEING with the name moves exactly as before"
moved "hdr-unreadable-name" "_bmad-output/planning-artifacts/s95/stories/story-1-foundation.md" \
                         "_bmad-output/planning-artifacts/stories/story-95-1-foundation.md" \
                         "an unreadable header (50A) leaves the name's reading in place"
asserts=$((asserts+1))
if grep -qE '^  s53 +header>name +.*story-102-1-effective-spread-500\.md$' <<<"$OUT" \
   && grep -qE '^  s185 +header>name +.*story-230-1-three-digit\.md$' <<<"$OUT" \
   && ! grep -q 'story-296-2-delta' <<<"$(sed -n '/SPRINT RECOVERED/,/^$/p' <<<"$OUT")" \
   && ! grep -q 'story-95-1-foundation' <<<"$(sed -n '/SPRINT RECOVERED/,/^$/p' <<<"$OUT")"; then
  printf '  ok    %-26s %s\n' "hdr-over-name-reported" "each override is reported as header>name; the agreeing and unreadable files are not"
else
  fails=$((fails+1)); printf '  FAIL  %-26s %s\n' "hdr-over-name-reported" "an override was silent, or a non-override was reported as one"
fi

# A SUFFIXED SPRINT IS REFUSED, NOT ROUNDED. `131b` has no legal `^s[0-9]+$` slot spelling, and
# truncating it to s131 merges one sprint's artifacts into another's on a guess.
refused "recover-suffixed" "_bmad-output/planning-artifacts/stories/story-131b-1-hr12-retirement.md" \
        "STORY-NO-SPRINT" "a suffixed sprint (131b) has no legal slot, so it is refused not rounded"

# A HEADER THAT SPOKE AND COULD NOT BE READ IS A REFUSAL, NOT A FALL-THROUGH TO THE BASENAME.
# One arm per shape the consumer actually produces or its template ships. Each of these files has
# a basename whose leading number is a carry-over ITEM, so a fall-through lands the exact case the
# header channel exists to prevent -- worse than the pre-recovery state, which refused.
refused "hdr-unparseable-range" "_bmad-output/planning-artifacts/stories/bug-311-range-hdr.md" \
        "STORY-NO-SPRINT" "a **Sprint:** 53-54 header refuses; it does not fall through to the basename"
refused "hdr-unparseable-tbd"   "_bmad-output/planning-artifacts/stories/bug-312-tbd-hdr.md" \
        "STORY-NO-SPRINT" "a **Sprint:** TBD header refuses rather than guessing from the name"
refused "hdr-unparseable-tmpl"  "_bmad-output/planning-artifacts/stories/bug-313-placeholder-hdr.md" \
        "STORY-NO-SPRINT" "the shipped template's [sprint ID/name] placeholder refuses"
refused "hdr-zero"              "_bmad-output/planning-artifacts/stories/bug-315-zero-hdr.md" \
        "STORY-NO-SPRINT" "**Sprint:** 0 names no sprint, so it refuses rather than minting s0/"

# THE `S` PREFIX IS A SPELLING THE CONSUMER USES, not a stray: 46 such header lines at consumer
# HEAD and 30 at the pre-migration ref, against a control of 817 bare-digit headers. It must reach
# the SAME slot as the bare form, and it must beat the basename exactly as the bare form does.
moved "hdr-s-prefix"     "_bmad-output/planning-artifacts/s270/stories/bug-124-s-prefix-hdr.md" \
                         "_bmad-output/planning-artifacts/stories/bug-124-s-prefix-hdr.md" \
                         "**Sprint:** S270 resolves to s270, not to the basename's carry-over 124"
asserts=$((asserts+1))
if ! has "$W" "_bmad-output/planning-artifacts/s124/stories/bug-124-s-prefix-hdr.md"; then
  printf '  ok    %-26s %s\n' "hdr-s-prefix-precedence" "an S-prefixed header is READ, not skipped into the basename channel"
else
  fails=$((fails+1))
  printf '  FAIL  %-26s %s\n' "hdr-s-prefix-precedence" "S270 fell through to the basename and landed s124 — the carry-over ITEM"
fi

# ONE CANONICAL SLOT PER SPRINT. `007` and `7` are one sprint; minting s007/ beside s7/ gives it
# two homes and the conformance validator accepts both, so nothing downstream would report it.
moved "hdr-leading-zeros" "_bmad-output/planning-artifacts/s7/stories/bug-314-leading-zeros-hdr.md" \
                         "_bmad-output/planning-artifacts/stories/bug-314-leading-zeros-hdr.md" \
                         "**Sprint:** 007 canonicalises to s7/, so one sprint keeps one slot"
asserts=$((asserts+1))
if ! has "$W" "_bmad-output/planning-artifacts/s007/stories/bug-314-leading-zeros-hdr.md"; then
  printf '  ok    %-26s %s\n' "hdr-no-s007-slot" "no s007/ slot was minted beside s7/"
else
  fails=$((fails+1))
  printf '  FAIL  %-26s %s\n' "hdr-no-s007-slot" "s007/ and s7/ now both exist as homes for one sprint"
fi

# THE `--follow` BOUND. The subject is a LEGACY story path -- no `s<N>/` above it, no sprint in the
# name, no header -- so it REACHES the recovery block and both channels decline. That is the whole
# repair: the first cut of this arm used a conforming `s121/` path, for which `legacy_story()`
# returns false, so the file skipped the recovery entirely and the arm passed against a shipping
# script carrying a real `git log --follow` third channel.
#
# Its history crosses a rename out of a sprint-71 path, so a history-reading recovery finds 71 and
# PLACES it. It must be REFUSED and stay where it is.
refused "follow-bound" "_bmad-output/planning-artifacts/stories/cooldown-sentinel-followbait.md" \
        "STORY-NO-SPRINT" "history is not a channel: a crossing rename does not become a sprint"

# CONTROL ONE: the hazard must be REAL in this tree. If `--follow` and plain `git log` agree here,
# the seeded crossing rename is missing and the arm above cannot discriminate.
asserts=$((asserts+1))
_p=_bmad-output/planning-artifacts/stories/cooldown-sentinel-followbait.md
_f="$(cd "$W" && git log --follow --format=%H -- "$_p" 2>/dev/null | tail -1)"
_n="$(cd "$W" && git log --format=%H -- "$_p" 2>/dev/null | tail -1)"
if [ -n "$_f" ] && [ -n "$_n" ] && [ "$_f" != "$_n" ]; then
  printf '  ok    %-26s %s\n' "follow-bound-control" "--follow and git log DISAGREE here, so a history channel would answer 71"
else
  fails=$((fails+1))
  printf '  FAIL  %-26s %s\n' "follow-bound-control" "--follow ($_f) and git log ($_n) agree; the seeded rename is missing and follow-bound is vacuous"
fi

# CONTROL TWO, AND IT IS THE ONE THE FIRST CUT LACKED: the subject must REACH the recovery block.
# `legacy_story()` is what decides that, and a conforming path answers false and skips the whole
# mechanism -- passing the arm above for a reason that has nothing to do with history. Driving the
# SHIPPING function is the only way to establish it; a path that merely looks legacy is not one.
asserts=$((asserts+1))
_lsfn="$(mktemp "${TMPDIR:-/tmp}/lsfn-XXXXXX")"
sed -n '/^legacy_story() {/,/^}/p' "$MIG" > "$_lsfn"
# shellcheck disable=SC1090
. "$_lsfn"
if legacy_story "_bmad-output/planning-artifacts/stories/cooldown-sentinel-followbait.md" \
   && ! legacy_story "_bmad-output/planning-artifacts/s299/stories/story-299-3-gamma.md"; then
  printf '  ok    %-26s %s\n' "follow-bound-reaches" "the follow-bait IS legacy, so it reaches the recovery the arm guards"
else
  fails=$((fails+1))
  printf '  FAIL  %-26s %s\n' "follow-bound-reaches" "the follow-bait is not legacy (or the control is): the arm never reaches the recovery"
fi
rm -f "$_lsfn"

# RECOVERY IS REPORTED, NEVER SILENT. A recovered sprint is the migration's own claim about a file
# whose path never stated one, so the operator has to be able to audit it. The report must name
# the file AND the channel that produced it.
asserts=$((asserts+1))
if grep -q 'SPRINT RECOVERED' <<<"$OUT" \
   && grep -qE '^  s72 +header +.*bug-124-deployed-range\.md$' <<<"$OUT" \
   && grep -qE '^  s192 +basename +.*192-ff-A-token-decimals\.md$' <<<"$OUT"; then
  printf '  ok    %-26s %s\n' "recovery-reported" "every recovered sprint is printed with the channel that produced it"
else
  fails=$((fails+1))
  printf '  FAIL  %-26s %s\n' "recovery-reported" "a sprint was recovered SILENTLY, or without naming its channel"
fi

# =============================================================================
# 4. NOTHING WAS LOST. git is the witness, not the script's own verdict.
# =============================================================================
STATUS="$(cd "$W" && git status --porcelain=1 | cut -c1-2 | sort -u | tr -d ' \n')"
[ "$STATUS" = "R" ] && ok "git sees ONLY renames — no deletions, no additions, no content edits" \
                    || bad "git status letters were '$STATUS', expected only 'R' (renames)"
N_BEFORE="$(cd "$W" && git ls-files | wc -l | tr -d ' ')"
[ "$N_BEFORE" -gt 0 ] && ok "tracked file count is non-zero ($N_BEFORE) — the control on the arm above" \
                      || bad "zero tracked files; every assertion above is vacuous"

# =============================================================================
# 5. IDEMPOTENT. A second run must find nothing, or the transform is not a function.
# =============================================================================
(cd "$W" && git add -A && git commit -q -m migrated)
bash "$MIG" --root "$W" >/dev/null 2>&1; RC=$?
[ "$RC" -eq 3 ] && ok "a second run exits 3 (nothing to migrate) — the transform is idempotent" \
                || bad "a second run exited $RC, expected 3; the first run left work behind"
rm -rf "$W"


# =============================================================================
# AREAS INFERRED — the remedy names the CONSUMER's file, and declaring an area
# there actually stops it being inferred.
#
# THE DEFECT. The report said "the grammar file is INCOMPLETE and should declare them", naming
# CORE's artifact-path-grammar.md — a file a pull overwrites, and the wrong home by core's own
# rule (the grammar's line 4 says the consumer declares its areas in the file named by
# `consumer_artifact_paths_file:`). A consumer session followed it literally and proposed adding
# nine consumer-specific areas to core.
#
# AND THE WORDING FIX ALONE WOULD HAVE BEEN WORSE THAN THE WRONG WORDING. Nothing read the
# consumer's file, so "declare them there" would have changed no verdict on any later run: the
# same areas would be inferred again, with a corrected sentence in front of an inert mechanism.
# The pair below is what proves the join is live.
# =============================================================================
wi="$(clone_world)"

# ARM A — nothing declared, which is the state the reference consumer was in.
a_out="$(bash "$MIG" --root "$wi" 2>&1)"
grep -q "_bmad-output/brainstorming" <<<"$(sed -n '/AREAS INFERRED/,/^$/p' <<<"$a_out")" \
  && ok "undeclared area is reported as inferred" \
  || bad "an undeclared area was NOT reported as inferred — the remaining arms cannot be attributed"
if grep -q "\.claude/skills/ai-dlc/artifact-paths.md" <<<"$a_out"; then
  ok "the remedy names the CONSUMER's own file, resolved from the contract"
else
  bad "the remedy did not name the consumer's declaration file"
fi
grep -q "INCOMPLETE and should declare them" <<<"$a_out" \
  && bad "the report still sends the operator to CORE's grammar, which a pull overwrites" \
  || ok "the report no longer sends the operator to core's grammar"

# ARM B — declare ONE of them in the consumer's own file. It must drop out of the inferred set,
# and the OTHER undeclared area must stay in it: a run that simply stopped reporting would
# satisfy a one-sided assertion.
mkdir -p "$wi/.claude/skills/ai-dlc"
cat > "$wi/.claude/skills/ai-dlc/artifact-paths.md" <<'EOF'
# consumer artifact paths

areas:
  _bmad-output/brainstorming
EOF
b_inf="$(sed -n '/AREAS INFERRED/,/^$/p' <<<"$(bash "$MIG" --root "$wi" 2>&1)")"
if grep -q "_bmad-output/brainstorming" <<<"$b_inf"; then
  bad "declaring the area in the consumer's file did NOT stop it being inferred — the remedy is inert"
elif ! grep -q "party-verdicts-retro" <<<"$b_inf"; then
  bad "the whole inferred set vanished, so the assertion above is satisfied by a report that stopped reporting"
else
  ok "declaring an area in the consumer's file removes it from the inferred set, and only it"
fi

# ARM B2 — THE UNREADABLE DECLARATION. The template shipped `area: <path>` one per line for
# seven releases while the resolver only ever read an `areas:` block, so a consumer following
# its own scaffolded documentation declared nothing and was told to declare it on every run.
# Correcting the template fixes nothing for a consumer that HAS one: install.sh preserves that
# file by design, so the correction cannot arrive by pull and the diagnosis has to.
cat > "$wi/.claude/skills/ai-dlc/artifact-paths.md" <<'EOF'
# consumer artifact paths

area: _bmad-output/brainstorming
area: _bmad-output/test-artifacts
EOF
b2_out="$(bash "$MIG" --root "$wi" 2>&1)"
if grep -q "UNREADABLE DECLARATION" <<<"$b2_out"; then
  ok "an 'area:'-per-line declaration is reported as UNREADABLE, not silently ignored"
else
  bad "the documented-but-unreadable 'area:' form extracted nothing and said nothing — the consumer is told to declare an area they have already declared, on every run, forever"
fi
# and it must still be INFERRED, because nothing was read: a diagnosis that replaced the
# inferred row would hide the consequence it is diagnosing.
grep -q "_bmad-output/brainstorming" <<<"$(sed -n '/AREAS INFERRED/,/^$/p' <<<"$b2_out")" \
  && ok "  and the area is STILL inferred — the diagnosis reports the state, it does not mask it" \
  || bad "  the diagnosis replaced the inferred row, so the report no longer shows what was lost"

# THE NEAR-MISS. A READABLE block that also mentions `area:` in its prose must stay silent, or
# the check fires on every correctly-declared file that happens to describe its own grammar.
cat > "$wi/.claude/skills/ai-dlc/artifact-paths.md" <<'EOF'
# consumer artifact paths

An `area:` is a durable root; declare each one under the block below.

areas:
  _bmad-output/brainstorming
EOF
if grep -q "UNREADABLE DECLARATION" <<<"$(bash "$MIG" --root "$wi" 2>&1)"; then
  bad "a READABLE areas: block was reported as unreadable because the prose mentions 'area:' — the predicate is not the conjunction and every compliant file is a false positive"
else
  ok "  and a readable block that mentions 'area:' in prose stays silent"
fi

# Restore ARM B's state so the mutation below measures what it was written to measure.
cat > "$wi/.claude/skills/ai-dlc/artifact-paths.md" <<'EOF'
# consumer artifact paths

areas:
  _bmad-output/brainstorming
EOF


# =============================================================================
# THE REMEDY NAMES THE --root TREE's FILE, NOT THE RESOLVER's OWN TREE's.
#
# THE DEFECT. Every `cfg()` call passed `--root "$ROOT_ABS"`; the one line resolving REMEDY_FILE
# did not, so artifact-path-config.sh fell back to AI_DLC_PROJECT_ROOT, then to a walk up from its
# OWN install path. Driven from the distribution at a consumer, or with the override naming another
# tree, the report told the operator to write a file the contract of a DIFFERENT tree declares.
#
# WHY THE ARMS ABOVE COULD NOT SEE IT: the seeded contract declares the same value core's does, so
# the wrong tree and the right one gave byte-identical answers. Each tree here declares a value no
# other tree carries, and the near-miss arm proves the values differ before anything is read off them.
# =============================================================================
VAL="$(pick "$HERE/../../scripts/validate-artifact-paths.sh" \
            "$HERE/../../../scripts/ai-dlc/validate-artifact-paths.sh" \
            "$HERE/../../core/scripts/validate-artifact-paths.sh")"
ra="$(clone_world)"
rb="$(clone_world)"
sed 's@^consumer_artifact_paths_file:.*@consumer_artifact_paths_file: TREE-A-FILE.md@' \
  "$ra/.claude/skills/ai-dlc/layer-contract.yaml" > "$ra/lc.tmp" && mv "$ra/lc.tmp" "$ra/.claude/skills/ai-dlc/layer-contract.yaml"
sed 's@^consumer_artifact_paths_file:.*@consumer_artifact_paths_file: TREE-B-FILE.md@' \
  "$rb/.claude/skills/ai-dlc/layer-contract.yaml" > "$rb/lc.tmp" && mv "$rb/lc.tmp" "$rb/.claude/skills/ai-dlc/layer-contract.yaml"
asserts=$((asserts+1))
if grep -qx 'consumer_artifact_paths_file: TREE-A-FILE.md' "$ra/.claude/skills/ai-dlc/layer-contract.yaml" \
   && grep -qx 'consumer_artifact_paths_file: TREE-B-FILE.md' "$rb/.claude/skills/ai-dlc/layer-contract.yaml"; then
  printf '  ok    %-26s %s\n' "remedy-root-seeded" "tree A declares TREE-A-FILE.md and tree B TREE-B-FILE.md, so a wrong-tree read is visible"
else
  fails=$((fails+1)); printf '  FAIL  %-26s %s\n' "remedy-root-seeded" "the contract edit did not land; the remedy-root arms below cannot discriminate"
fi
# $1 label  $2 output  $3 why
remedy_names_a() {
  asserts=$((asserts+1))
  if grep -q 'TREE-A-FILE\.md' <<<"$2" && ! grep -q 'TREE-B-FILE\.md' <<<"$2" \
     && ! grep -q '\.claude/skills/ai-dlc/artifact-paths\.md' <<<"$2"; then
    printf '  ok    %-26s %s\n' "$1" "$3"
  else
    fails=$((fails+1)); printf '  FAIL  %-26s %s\n           A: %s / B: %s / default: %s\n' "$1" "$3" \
      "$(grep -q 'TREE-A-FILE\.md' <<<"$2" && echo named || echo ABSENT)" \
      "$(grep -q 'TREE-B-FILE\.md' <<<"$2" && echo NAMED || echo absent)" \
      "$(grep -q '\.claude/skills/ai-dlc/artifact-paths\.md' <<<"$2" && echo NAMED || echo absent)"
  fi
}
remedy_names_a "migrate-remedy-override" \
  "$(cd "$ra" && AI_DLC_PROJECT_ROOT="$rb" bash "$MIG" --root "$ra" 2>&1)" \
  "AI_DLC_PROJECT_ROOT at tree B: the migration's remedy still names tree A's declared file"
remedy_names_a "migrate-remedy-unset" \
  "$(cd "$ra" && env -u AI_DLC_PROJECT_ROOT bash "$MIG" --root "$ra" 2>&1)" \
  "override unset: the same tree-A file, not the resolver's own install tree's"
if [ -n "$VAL" ]; then
  remedy_names_a "validate-noarea-override" \
    "$(sed -n '/NO-AREA/,/move it under one/p' <<<"$(cd "$ra" && AI_DLC_PROJECT_ROOT="$rb" bash "$VAL" --root "$ra" 2>&1)")" \
    "the conformance validator's NO-AREA remedy names tree A's file under the override too"
  remedy_names_a "validate-noarea-unset" \
    "$(sed -n '/NO-AREA/,/move it under one/p' <<<"$(cd "$ra" && env -u AI_DLC_PROJECT_ROOT bash "$VAL" --root "$ra" 2>&1)")" \
    "...and with it unset"
else
  bad "FIXTURE ERROR: cannot locate validate-artifact-paths.sh, so its NO-AREA remedy is unchecked"
fi

# =============================================================================
# 5b. NO PROCESS PER FILE, AND PROGRESS ON STDERR ONLY.
#
# THE DEFECT. The plan loop forked per file and per path component -- `sprints_in` ran tr, grep,
# head, sed and sort for EVERY tracked file under the scan roots, token or not, `strip_token` ran
# sed per component of every file with one sprint (the already-conforming `area/s<N>/...` majority
# included), and the hit count was one more grep. On the reference consumer that was ~400k forks
# over 16554 files and eleven minutes with no output at all, so the operator could not tell a slow
# run from a hung one.
#
# THE COST ARM COUNTS PROCESSES, NEVER TIME (zero load-dependent tests). sed/grep/tr/sort/head are
# counting shims on PATH, and the same tree is scanned at two sizes: K tokenless, K tokened-but-
# nonconforming and K already-conforming files, at K=1 and K=2. A fork-free scan starts the same
# number of those tools at both sizes, because everything it starts runs once per RUN (the resolver
# calls, the report); one fork per file anywhere in the plan loop makes the two counts differ by 3
# per fork. K is small on purpose: each shim is a counted bash start, and two sizes that differ are
# all equality needs -- a larger K only multiplies the starts the forking mutants pay. The
# moves-planned line is the control that each run read its tree.
# =============================================================================
PA=_bmad-output/planning-artifacts
# small_world <path>... -> a clone of the seeded world holding ONLY these artifacts under the scan
# roots (one line each), committed. Everything else the seed carries under them is removed, so a
# count or a report read off this world is about the named files alone.
small_world() {
  local d f; d="$(clone_world)" || return 1
  ( cd "$d" && git rm -rq _bmad-output docs && for f in "$@"; do mkdir -p "${f%/*}" && printf 'x\n' > "$f" || exit 1; done \
      && git add -A && git commit -qm small ) >/dev/null 2>&1 || return 1
  printf '%s\n' "$d"
}
fork_world() { # <K>
  local k="$1" i=0 fs=()
  while [ "$i" -lt "$k" ]; do
    i=$((i + 1))
    fs+=("$PA/plain-$i.md" "$PA/s$i-notes.md" "$PA/s$((i + 500))/x.md")
  done
  small_world "${fs[@]}"
}
FW1="$(fork_world 1)"; FW2="$(fork_world 2)"
[ -n "$FW1" ] && [ -n "$FW2" ] || { echo "FIXTURE BROKEN: the fork-scaling worlds could not be built" >&2; exit 2; }
SHIMS="$(mktemp -d "${TMPDIR:-/tmp}/apmig-shim-XXXXXX")" || exit 2
for _t in sed grep tr sort head; do
  _real="$(type -P "$_t")" || { echo "FIXTURE BROKEN: $_t is not on PATH, so it cannot be shimmed" >&2; exit 2; }
  printf '#!%s\nprintf "%%s\\n" %s >> "$APMIG_SHIM_LOG"\nexec %s "$@"\n' "$BASH" "$_t" "$_real" > "$SHIMS/$_t"
  chmod +x "$SHIMS/$_t"
done
# fork_count <script> <world> -> "<shimmed starts> <moves planned>" for one dry run
fork_count() {
  local log n m
  log="$(mktemp "${TMPDIR:-/tmp}/apmig-shlog-XXXXXX")" || return 2
  APMIG_SHIM_LOG="$log" PATH="$SHIMS:$PATH" bash "$1" --root "$2" > "$log.out" 2>&1
  n="$(wc -l < "$log")"; m="$(sed -n 's/^  moves planned: *//p' "$log.out")"
  rm -f "$log" "$log.out"
  printf '%s %s\n' "$((n + 0))" "${m:-none}"
}
# forks_hold <script> -> 0 when both sizes start the same non-zero number of shimmed tools and each
# run planned its K moves (only the tokened-nonconforming files move). FORKS_SEEN carries the readings for the report.
forks_hold() {
  local a b
  a="$(fork_count "$1" "$FW1")"; b="$(fork_count "$1" "$FW2")"
  FORKS_SEEN="K=1: $a / K=2: $b (shimmed starts, moves planned)"
  [ "${a#* }" = 1 ] && [ "${b#* }" = 2 ] && [ "${a%% *}" -gt 0 ] && [ "${a%% *}" = "${b%% *}" ]
}
forks_hold "$MIG"; FORKS_RC_MIG=$?; FORKS_SEEN_MIG="$FORKS_SEEN"
if [ "$FORKS_RC_MIG" -eq 0 ]; then ok "fork-scaling: the plan scan starts no tool per file -- $FORKS_SEEN"
else bad "fork-scaling: the shimmed tool count GROWS with the tree, or a run did not plan its moves -- $FORKS_SEEN"; fi

# THE MOVE LOOP, THE SAME WAY. --apply used to run two `shasum` and one `git mv` per move, ~77ms a
# move and ~280s on the reference consumer's 3637. It now hashes and stages per BATCH, so `shasum`
# and `git` starts must not grow with the number of moves: the same worlds, applied on copies, at
# K=1 and K=2 planned moves, under counting shims for exactly those two tools. `mv` and `mkdir`
# stay per move by design and are not shimmed. The VERDICT line is the control that every move ran.
SHIMA="$(mktemp -d "${TMPDIR:-/tmp}/apmig-shima-XXXXXX")" || exit 2
for _t in shasum git; do
  _real="$(type -P "$_t")" || { echo "FIXTURE BROKEN: $_t is not on PATH, so it cannot be shimmed" >&2; exit 2; }
  printf '#!%s\nprintf "%%s\\n" %s >> "$APMIG_SHIM_LOG"\nexec %s "$@"\n' "$BASH" "$_t" "$_real" > "$SHIMA/$_t"
  chmod +x "$SHIMA/$_t"
done
# apply_count <script> <world> -> "<git starts> <shasum starts> <moved>" for one --apply on a copy
apply_count() {
  local t g s m
  t="$(mktemp -d "${TMPDIR:-/tmp}/apmig-apc-XXXXXX")" || return 2
  mkdir -p "$t/w" && cp -R "$2/." "$t/w" || return 2
  APMIG_SHIM_LOG="$t/log" PATH="$SHIMA:$PATH" bash "$1" --root "$t/w" --apply > "$t/out" 2>&1
  g="$(grep -c '^git$' "$t/log")" || g=0
  s="$(grep -c '^shasum$' "$t/log")" || s=0
  m="$(sed -n 's/^VERDICT: \([0-9]*\) of \([0-9]*\) planned move(s) applied.*/\1\/\2/p' "$t/out")"
  rm -rf "$t"
  printf '%s %s %s\n' "$g" "$s" "${m:-none}"
}
# applyscale_hold <script> -> 0 when git and shasum starts are equal, and non-zero, at both sizes
# and each run applied all of its K moves. APPLYSCALE_SEEN carries the readings.
applyscale_hold() {
  local a b
  a="$(apply_count "$1" "$FW1")"; b="$(apply_count "$1" "$FW2")"
  APPLYSCALE_SEEN="K=1: $a / K=2: $b (git starts, shasum starts, moved)"
  set -- $a $b
  [ "$3" = 1/1 ] && [ "$6" = 2/2 ] && [ "$1" -gt 0 ] && [ "$2" -gt 0 ] && [ "$1" = "$4" ] && [ "$2" = "$5" ]
}
applyscale_hold "$MIG"; APPLYSCALE_RC_MIG=$?; APPLYSCALE_SEEN_MIG="$APPLYSCALE_SEEN"
if [ "$APPLYSCALE_RC_MIG" -eq 0 ]; then ok "apply-scaling: --apply starts no git or shasum per move -- $APPLYSCALE_SEEN"
else bad "apply-scaling: git or shasum starts GROW with the moves, or a run did not apply them all -- $APPLYSCALE_SEEN"; fi

# THE BATCHED LOOP ABORTS WHERE THE ONE-AT-A-TIME LOOP ABORTED, AND LEAVES WHAT IT LEFT. Batching
# moves a whole batch on disk before anything is verified or staged, so every abort is now a
# rollback, and a rollback can leave a tree no operator would get from the old loop. 300 planned
# moves (x1001-s1001.md .. x1300-s1300.md, each its own content) put the trouble at move 280, in the
# SECOND batch of 256, so batch one is moved, verified and staged before it:
#   read    the source is a dangling symlink, so it has no hash
#   exists  an IGNORED file already sits at the destination
#   verify  a relative symlink that resolves at the source and dangles once moved
#   stage   a stale .git/index.lock. It refuses the FIRST index update, so this one aborts in batch
#           one: a lock present at start cannot first appear at batch two without racing the run.
# Each is asserted on rc, `git status --porcelain=v1 -z`, `git ls-files -s` (both over _bmad-output),
# the directory tree, and the first stderr FAIL line. Every expected value was produced by RUNNING
# the 0.1101.0 one-at-a-time migrator on the same world and is pinned (status, index and tree as
# the first 16 hex of their sha256); the stage line alone is the batched loop's documented new text.
#
# B1, THE STAGING ITSELF. A file committed with CRLF before `* text=auto` is moved and must stage as a
# pure rename: `git update-index --add` would re-hash it through the eol filter and stage a content
# change, which `git mv` never did. Its blob is compared with the source's own pre-move entry.
ABW="$(mktemp -d "${TMPDIR:-/tmp}/apmig-abw-XXXXXX")" || exit 2
h16() { local h; h="$(shasum -a 256 < "$1")" || return 1; printf '%s' "${h:0:16}"; }
ab_base() { # -> the 300-move world, committed
  local d i=1000; d="$ABW/base"
  mkdir "$d" && cp -R "$TPL/." "$d" || return 1
  # No automatic gc or maintenance: a detached one packing objects while the world is copied
  # removes directories from under `cp -R`.
  ( cd "$d" && git config gc.auto 0 && git config maintenance.auto false \
      && git rm -rq _bmad-output docs && mkdir -p "$PA" \
      && while [ "$i" -lt 1300 ]; do i=$((i + 1)); printf 'f%s\n' "$i" > "$PA/x$i-s$i.md" || exit 1; done \
      && git add -A && git commit -qm abort-base ) >/dev/null 2>&1
}
ab_world() { mkdir "$ABW/$1" && cp -R "$ABW/base/." "$ABW/$1"; }
ab_commit() { ( cd "$ABW/$1" && git add -A && git commit -qm "$1" ) >/dev/null 2>&1; }
{ ab_base \
  && ab_world read && rm "$ABW/read/$PA/x1280-s1280.md" && ln -s nowhere "$ABW/read/$PA/x1280-s1280.md" && ab_commit read \
  && ab_world exists && printf '%s\n' "$PA/s1280/x1280.md" > "$ABW/exists/.gitignore" \
     && mkdir -p "$ABW/exists/$PA/s1280" && printf 'ignored\n' > "$ABW/exists/$PA/s1280/x1280.md" && ab_commit exists \
  && ab_world verify && printf 't\n' > "$ABW/verify/$PA/x1280-target.md" && rm "$ABW/verify/$PA/x1280-s1280.md" \
     && ln -s x1280-target.md "$ABW/verify/$PA/x1280-s1280.md" && ab_commit verify \
  && ab_world stage && : > "$ABW/stage/.git/index.lock"; } \
  || { echo "FIXTURE BROKEN: the abort-path worlds could not be built" >&2; exit 2; }
mkdir "$ABW/crlf" && cp -R "$TPL/." "$ABW/crlf" \
  && ( cd "$ABW/crlf" && git config core.autocrlf false && git config gc.auto 0 && git config maintenance.auto false && git rm -rq _bmad-output docs && mkdir -p "$PA" \
       && printf 'a\r\nb\r\n' > "$PA/crlf-s1500.md" && git add -A && git commit -qm crlf \
       && printf '* text=auto\n' > .gitattributes && git add .gitattributes && git commit -qm attr ) >/dev/null 2>&1 \
  || { echo "FIXTURE BROKEN: the CRLF world could not be built" >&2; exit 2; }
CRLF_BLOB="$(git -C "$ABW/crlf" ls-files -s -- "$PA/crlf-s1500.md")"; CRLF_BLOB="${CRLF_BLOB#* }"; CRLF_BLOB="${CRLF_BLOB%% *}"
# The pins: "<rc> <status> <index> <tree>" and the first stderr FAIL line, from the 0.1101.0 run.
AB_EXP_read="1 e3bb5b21144ee81c d7026bbfd3b8c1fd 1f8341d1b11c2ec7"
AB_EXP_exists="1 e3bb5b21144ee81c bacfbaca8d98b913 4a966e3bcdd22b9f"
AB_EXP_verify="1 1106200149097029 3ab6d5be7e4d42eb 0ca6ea2696f51417"
AB_EXP_stage="1 e3b0c44298fc1c14 c1d1e71cf1a5cc66 5a8bf898bd38acd5"
AB_LINE_read='migrate-artifact-paths.sh: FAIL — cannot read _bmad-output/planning-artifacts/x1280-s1280.md before moving it. Aborting after 279 move(s).'
AB_LINE_exists='migrate-artifact-paths.sh: FAIL — destination already exists: _bmad-output/planning-artifacts/s1280/x1280.md. Aborting after 279 move(s).'
AB_LINE_verify='migrate-artifact-paths.sh: FAIL — verification failed for _bmad-output/planning-artifacts/x1280-s1280.md -> _bmad-output/planning-artifacts/s1280/x1280.md'
AB_LINE_stage='migrate-artifact-paths.sh: FAIL — git update-index refused to stage this batch'"'"'s renames, from _bmad-output/planning-artifacts/x1001-s1001.md -> _bmad-output/planning-artifacts/s1001/x1001.md; the batch was moved back. Aborting after 0 move(s).'
# abort_run <script> <world> -> AB_OBS "<rc> <status> <index> <tree>" and AB_LINE, for one --apply on a copy
abort_run() {
  local t; t="$(mktemp -d "$ABW/r-XXXXXX")" || return 2
  mkdir "$t/w" && cp -R "$ABW/$2/." "$t/w" || return 2
  bash "$1" --root "$t/w" --apply > "$t/out" 2> "$t/err"; AB_RC=$?
  git -C "$t/w" status --porcelain=v1 -z -- _bmad-output > "$t/st" 2>/dev/null
  git -C "$t/w" ls-files -s -- _bmad-output > "$t/ls" 2>/dev/null
  ( cd "$t/w" && find _bmad-output -print ) > "$t/tr0"; LC_ALL=C sort "$t/tr0" > "$t/tr"
  AB_OBS="$AB_RC $(h16 "$t/st") $(h16 "$t/ls") $(h16 "$t/tr")"
  AB_LINE="$(grep -m1 'FAIL' "$t/err")"
  AB_STAT=""; AB_DEST=""
  if [ "$2" = crlf ]; then
    AB_STAT="$(git -C "$t/w" diff --cached -M --stat 2>/dev/null)"
    AB_DEST="$(git -C "$t/w" ls-files -s -- "$PA/s1500/crlf.md")"; AB_DEST="${AB_DEST#* }"; AB_DEST="${AB_DEST%% *}"
  fi
  rm -rf "$t"
}
crlf_blob_ok() { [ "$AB_RC" -eq 0 ] && [ -n "$CRLF_BLOB" ] && [ "$AB_DEST" = "$CRLF_BLOB" ]; }
crlf_stat_ok() { case "$AB_STAT" in *"crlf-s1500.md => s1500/crlf.md} | 0"*"0 insertions(+), 0 deletions(-)"*) return 0 ;; esac; return 1; }
# abort_hold <script> <world> -> 0 when the run matches every pin for that world
abort_hold() {
  abort_run "$1" "$2" || return 2
  if [ "$2" = crlf ]; then crlf_blob_ok && crlf_stat_ok; return; fi
  local e l; eval "e=\"\$AB_EXP_$2\"; l=\"\$AB_LINE_$2\""
  [ "$AB_OBS" = "$e" ] && [ "$AB_LINE" = "$l" ]
}
for _w in read exists verify stage; do
  abort_run "$MIG" "$_w"; eval "_e=\"\$AB_EXP_$_w\"; _l=\"\$AB_LINE_$_w\""
  set -- $AB_OBS; _x="$_e"; _er="${_x%% *}"; _x="${_x#* }"; _est="${_x%% *}"; _x="${_x#* }"; _els="${_x%% *}"; _etr="${_x#* }"
  [ "$1" = "$_er" ] && ok "abort-$_w: --apply exits $1, as the one-at-a-time loop did" || bad "abort-$_w: --apply exited $1, the one-at-a-time loop exited $_er"
  [ "$2" = "$_est" ] && ok "abort-$_w: git status is the one-at-a-time loop's" || bad "abort-$_w: git status differs from the one-at-a-time loop's ($2, want $_est)"
  [ "$3" = "$_els" ] && ok "abort-$_w: the index (ls-files -s) is the one-at-a-time loop's" || bad "abort-$_w: the index differs from the one-at-a-time loop's ($3, want $_els)"
  [ "$4" = "$_etr" ] && ok "abort-$_w: the directory tree is the one-at-a-time loop's" || bad "abort-$_w: the directory tree differs from the one-at-a-time loop's ($4, want $_etr)"
  [ "$AB_LINE" = "$_l" ] && ok "abort-$_w: stderr's FAIL line is the expected text" || bad "abort-$_w: stderr's FAIL line was: $AB_LINE"
  [ "$AB_OBS" = "$_e" ] && [ "$AB_LINE" = "$_l" ]; echo "$?" > "$ABW/prim-A-$_w.rc"
done
abort_run "$MIG" crlf
crlf_blob_ok && ok "crlf-rename: a CRLF file committed before text=auto stages under its own blob ($CRLF_BLOB)" \
  || bad "crlf-rename: rc=$AB_RC, staged blob '$AB_DEST' against the source's '$CRLF_BLOB'"
crlf_stat_ok && ok "crlf-rename: git diff --cached -M --stat shows a pure rename, 0 insertions and 0 deletions" \
  || bad "crlf-rename: the staged move is not a pure rename: $(printf '%s' "$AB_STAT" | tr '\n' '|')"
crlf_blob_ok && crlf_stat_ok; echo "$?" > "$ABW/prim-A-crlf.rc"

# NAMES GIT QUOTES. A line-delimited `git ls-files` C-quotes any path holding a non-ASCII byte, a
# backslash or a double quote under `core.quotePath true` (`"…caf\303\251.md"`), and that string
# names no file: the one-at-a-time loop neither planned nor refused such a path, it dropped it.
# The world pins `core.quotePath true` in its own config and tracks five tokened names: café,
# a backslash and a double quote must each stage as an R100 rename under the source's own blob;
# a tab and a newline cannot ride the tab-separated plan rows and must each be an UNSAFE-NAME
# refusal, left in place. The control asserts the hazard is live HERE: a plain `ls-files` in this
# world prints the quoted spelling, so the quoted-read mutant drops what the fixed read moves.
QN_CAFE="$PA/sprint-320-café.md"; QN_BSL="$PA/sprint-321-a\\b.md"; QN_DQ="$PA/sprint-322-a\"b.md"
QN_TAB="$PA/sprint-323-a"$'\t'"b.md"; QN_NL="$PA/sprint-324-a"$'\n'"b.md"
# AND TWO TAB/NEWLINE NAMES THAT WOULD PRODUCE NO ROW AT ALL: a CONFORMING one already in its slot,
# and a TOKENLESS one. The one-at-a-time loop skipped both silently, and an UNSAFE-NAME raised for
# them would refuse a file the migration never had a reason to touch. Neither may appear in any
# UNSAFE-NAME row or in REFUSED, while the two movable names above still must.
QN_CTAB="docs/retro/s3/notes"$'\t'"x.md"; QN_TNL="docs/retro/readme"$'\n'".md"
# Built in place per run rather than copied: a `cp -R` of this world inside the hermetic sandbox
# lost its `.git/objects/*` directories mid-copy (cp: No such file or directory, once per object
# directory), which no other world here did; the cause was not isolated.
quote_build() { # <dir> -> the quoted-name world, committed, at <dir>
  mkdir "$1" && cp -R "$TPL/." "$1" \
    && ( cd "$1" && git config core.quotePath true && git config core.autocrlf false \
         && git config gc.auto 0 && git config maintenance.auto false \
         && git rm -rq _bmad-output docs && mkdir -p "$PA" \
         && printf 'cafe\n' > "$QN_CAFE" && printf 'bsl\n' > "$QN_BSL" && printf 'dq\n' > "$QN_DQ" \
         && printf 'tab\n' > "$QN_TAB" && printf 'nl\n' > "$QN_NL" \
         && mkdir -p docs/retro/s3 && printf 'ctab\n' > "$QN_CTAB" && printf 'tnl\n' > "$QN_TNL" \
         && git add -A && git commit -qm quote ) >/dev/null 2>&1
}
quote_build "$ABW/quote" || { echo "FIXTURE BROKEN: the quoted-name world could not be built" >&2; exit 2; }
git -C "$ABW/quote" ls-files -s -z -- _bmad-output > "$ABW/quote.pre" 2>/dev/null
git -C "$ABW/quote" ls-files -- _bmad-output > "$ABW/quote.plain" 2>/dev/null
git -C "$ABW/quote" ls-files -z -- docs/retro > "$ABW/quote.docs" 2>/dev/null
_qn=0; while IFS= read -r -d '' _r; do _qn=$((_qn + 1)); done < "$ABW/quote.pre"
_qd=0; while IFS= read -r -d '' _r; do case "$_r" in "$QN_CTAB"|"$QN_TNL") _qd=$((_qd + 1)) ;; esac; done < "$ABW/quote.docs"
asserts=$((asserts+1))
if [ "$_qn" -eq 5 ] && [ "$_qd" -eq 2 ] && [ "$(git -C "$ABW/quote" config core.quotePath)" = true ] \
   && grep -qF '"_bmad-output/planning-artifacts/sprint-320-caf\303\251.md"' "$ABW/quote.plain"; then
  printf '  ok    %-26s %s\n' "quoted-names-control" "git tracks all seven names here and, with quotePath true, a line-delimited ls-files quotes cafe"
else
  fails=$((fails+1)); printf '  FAIL  %-26s %s\n' "quoted-names-control" "tracked $_qn of 5 movable and $_qd of 2 rowless names, or quotePath is not true, or ls-files did not quote the cafe name: the arm below cannot discriminate"
fi
# qn_blob <ls-files -s -z file> <path> -> the blob staged at <path>, '' when none
qn_blob() {
  local r; QN_B=""
  while IFS= read -r -d '' r; do [ "${r#*$'\t'}" = "$2" ] && { r="${r#* }"; QN_B="${r%% *}"; return 0; }; done < "$1"
  return 1
}
# quote_run <script> -> QN_RC, QN_ROWS (renames found R100 under their source's blob), QN_UNSAFE (refusal rows), QN_STAY (refused files still in place)
quote_run() {
  local t a b c s d
  QN_RC=99; QN_ROWS=0; QN_UNSAFE=0; QN_STAY=0; QN_NAMED=0; QN_QUIET=0
  t="$(mktemp -d "$ABW/q-XXXXXX")" || return 2
  quote_build "$t/w" || return 2
  bash "$1" --root "$t/w" --apply > "$t/out" 2> "$t/err"; QN_RC=$?
  git -C "$t/w" diff --cached -M --name-status -z > "$t/ns" 2>/dev/null
  git -C "$t/w" ls-files -s -z -- _bmad-output > "$t/post" 2>/dev/null
  : > "$t/rows"
  while IFS= read -r -d '' a; do
    case "$a" in R*) IFS= read -r -d '' b; IFS= read -r -d '' c; printf '%s|%s|%s\n' "$a" "$b" "$c" >> "$t/rows" ;; esac
  done < "$t/ns"
  QN_ROWS=0
  for s in "$QN_CAFE" "$QN_BSL" "$QN_DQ"; do
    case "$s" in
      "$QN_CAFE") d="$PA/s320/café.md" ;; "$QN_BSL") d="$PA/s321/a\\b.md" ;; *) d="$PA/s322/a\"b.md" ;;
    esac
    qn_blob "$ABW/quote.pre" "$s"; a="$QN_B"; qn_blob "$t/post" "$d"; b="$QN_B"
    grep -qxF "R100|$s|$d" "$t/rows" && [ -n "$a" ] && [ "$a" = "$b" ] && QN_ROWS=$((QN_ROWS + 1))
  done
  QN_UNSAFE="$(grep -c '^  UNSAFE-NAME ' "$t/out")" || QN_UNSAFE=0
  # NAMED: both movable tab/newline names are in UNSAFE-NAME rows. QUIET: neither rowless name is
  # anywhere in the report -- not in an UNSAFE-NAME row, not elsewhere in REFUSED.
  QN_NAMED=0; QN_QUIET=0
  grep '^  UNSAFE-NAME ' "$t/out" > "$t/unsafe"
  grep -q 'sprint-323-a' "$t/unsafe" && grep -q 'sprint-324-a' "$t/unsafe" && QN_NAMED=1
  grep -q 's3/notes' "$t/out" || grep -q 'retro/readme' "$t/out" || QN_QUIET=1
  QN_STAY=0; [ -e "$t/w/$QN_TAB" ] && QN_STAY=$((QN_STAY + 1)); [ -e "$t/w/$QN_NL" ] && QN_STAY=$((QN_STAY + 1))
  rm -rf "$t"
}
quote_hold() {
  quote_run "$1" || return 2
  [ "$QN_RC" -eq 0 ] && [ "$QN_ROWS" -eq 3 ] && [ "$QN_UNSAFE" -eq 2 ] && [ "$QN_STAY" -eq 2 ] \
    && [ "$QN_NAMED" -eq 1 ] && [ "$QN_QUIET" -eq 1 ]
}
quote_hold "$MIG"; echo "$?" > "$ABW/prim-A-quote.rc"
[ "$QN_RC" -eq 0 ] && [ "$QN_ROWS" -eq 3 ] \
  && ok "quoted-names: cafe, a backslash and a double quote each stage as R100 under their own blob (rc 0)" \
  || bad "quoted-names: rc=$QN_RC, $QN_ROWS of 3 quoted names staged as R100 under their own blob"
[ "$QN_UNSAFE" -eq 2 ] && [ "$QN_NAMED" -eq 1 ] && [ "$QN_STAY" -eq 2 ] \
  && ok "quoted-names: the movable tab and newline names are each an UNSAFE-NAME refusal and stay where they are" \
  || bad "quoted-names: $QN_UNSAFE UNSAFE-NAME row(s) (want 2, naming sprint-323 and sprint-324: $QN_NAMED) and $QN_STAY of 2 tab/newline files left in place"
[ "$QN_QUIET" -eq 1 ] \
  && ok "quoted-names: a conforming tab name and a tokenless newline name are skipped silently, in no UNSAFE-NAME row and not in REFUSED" \
  || bad "quoted-names: docs/retro/s3/notes<TAB>x.md or docs/retro/readme<NL>.md was reported, though neither would produce a plan or refusal row"

# PROGRESS. One world carries a tokenless file, a conforming one, a refused one and two moves -- so
# a tick keyed anywhere but straight after the scan counter moves (a `continue` path skipping it)
# lands on a different line. Every 2 files: the start line, then scanned 2 and 4 of 5.
#
# AND THE SAME WORLD CARRIES THE MATCH-POSITION TRAPS, END TO END. `x-s123x-s12` and `a-s12x-s12`
# end in a token matched through `$`, and the text of that token occurs EARLIER as a literal -- a
# strip that finds the match by searching for its text cuts the wrong place. `x/s9/s10-y.md` names
# two sprints whose `sort -u` order is lexical: the refusal prints `(10 9)`, not `(9 10)`. Every
# expected line below was produced by RUNNING the pre-fix forking script (0.1101.0) on this world
# and is pinned byte-exact.
PW="$(small_world "$PA/plain.md" "$PA/s7/x.md" "$PA/x/s9/s10-y.md" "$PA/x-s123x-s12/f.md" "$PA/a-s12x-s12/f.md")"
[ -n "$PW" ] || { echo "FIXTURE BROKEN: the progress world could not be built" >&2; exit 2; }
PGD="$(mktemp -d "${TMPDIR:-/tmp}/apmig-pg-XXXXXX")" || exit 2
printf '%s\n' "migrate-artifact-paths.sh: PROGRESS plan: 5 tracked file(s) to scan" \
  "migrate-artifact-paths.sh: PROGRESS plan: scanned 2 of 5" \
  "migrate-artifact-paths.sh: PROGRESS plan: scanned 4 of 5" > "$PGD/exp.plan"
cp "$PGD/exp.plan" "$PGD/exp.apply"
printf '%s\n' "migrate-artifact-paths.sh: PROGRESS apply: 2 move(s) to apply" \
  "migrate-artifact-paths.sh: PROGRESS apply: moved 2 of 2" >> "$PGD/exp.apply"
bash "$MIG" --root "$PW" > "$PGD/out0" 2> "$PGD/err0"; rc0=$?
AI_DLC_MIGRATE_PROGRESS_EVERY=2 bash "$MIG" --root "$PW" > "$PGD/out1" 2> "$PGD/err1"; rc1=$?
# progress_hold <script> -> 0 when a dry run every 2 files prints exactly the plan lines on stderr
# and the stdout of the unset run, byte for byte.
progress_hold() {
  local t; t="$(mktemp -d "$PGD/h-XXXXXX")" || return 2
  AI_DLC_MIGRATE_PROGRESS_EVERY=2 bash "$1" --root "$PW" > "$t/o" 2> "$t/e"
  cmp -s "$t/e" "$PGD/exp.plan" && cmp -s "$t/o" "$PGD/out0"
}
[ "$rc0" -eq 0 ] && [ "$rc1" -eq 0 ] && [ ! -s "$PGD/err0" ] \
  && ok "progress: below the cadence (1000) a run prints nothing on stderr" \
  || bad "progress: unset run rc=$rc0, cadence-2 run rc=$rc1, or the unset run wrote stderr: $(head -2 "$PGD/err0")"
cmp -s "$PGD/err1" "$PGD/exp.plan" \
  && ok "progress: every 2 files the plan prints its start line and scanned 2 and 4 of 5, on stderr" \
  || bad "progress: plan stderr was not the three expected lines: $(tr '\n' '|' < "$PGD/err1")"
cmp -s "$PGD/out1" "$PGD/out0" && grep -q 'tracked files scanned: 5' "$PGD/out0" \
  && ok "progress: stdout is byte-identical to the run without the variable" \
  || bad "progress: stdout CHANGED when progress was turned on (or the unset run scanned nothing)"
asserts=$((asserts+1))
if grep -qxF '    _bmad-output/planning-artifacts/x-s123x-s12/f.md' "$PGD/out0" \
   && grep -qxF '      -> _bmad-output/planning-artifacts/s12/x-s123x/f.md' "$PGD/out0" \
   && grep -qxF '    _bmad-output/planning-artifacts/a-s12x-s12/f.md' "$PGD/out0" \
   && grep -qxF '      -> _bmad-output/planning-artifacts/s12/a-s12x/f.md' "$PGD/out0"; then
  printf '  ok    %-26s %s\n' "match-position-traps" "x-s123x-s12/ and a-s12x-s12/ plan s12/x-s123x/ and s12/a-s12x/, as the forking script did"
else
  fails=$((fails+1)); printf '  FAIL  %-26s %s\n' "match-position-traps" "a trap directory planned a destination the forking script did not"
fi
asserts=$((asserts+1))
if grep -qxF '  AMBIGUOUS  _bmad-output/planning-artifacts/x/s9/s10-y.md' "$PGD/out0" \
   && grep -qxF '             path names 2 different sprints (10 9); which one owns it is not derivable' "$PGD/out0"; then
  printf '  ok    %-26s %s\n' "ambiguous-sort-order" "x/s9/s10-y.md is refused naming (10 9), the forking script's sort -u order"
else
  fails=$((fails+1)); printf '  FAIL  %-26s %s\n' "ambiguous-sort-order" "the AMBIGUOUS refusal for x/s9/s10-y.md is not the forking script's text"
fi
# APPLY, on its own copy so the dry-run world stays pristine for the mutants. Run with the cadence,
# reset, run without it: the move loop's lines are on stderr and stdout is unchanged.
PWA="$(mktemp -d "${TMPDIR:-/tmp}/apmig-pwa-XXXXXX")" && cp -R "$PW/." "$PWA"
AI_DLC_MIGRATE_PROGRESS_EVERY=2 bash "$MIG" --root "$PWA" --apply > "$PGD/aout1" 2> "$PGD/aerr1"; arc1=$?
git -C "$PWA" reset -q --hard
bash "$MIG" --root "$PWA" --apply > "$PGD/aout0" 2> "$PGD/aerr0"; arc0=$?
[ "$arc1" -eq 0 ] && [ "$arc0" -eq 0 ] && cmp -s "$PGD/aerr1" "$PGD/exp.apply" && [ ! -s "$PGD/aerr0" ] \
  && ok "progress: --apply prints the plan lines, then 2 move(s) to apply and moved 2 of 2, on stderr" \
  || bad "progress: --apply rc=$arc1/$arc0, or its stderr was not the expected five lines: $(tr '\n' '|' < "$PGD/aerr1")"
cmp -s "$PGD/aout1" "$PGD/aout0" && grep -q 'VERDICT: 2 of 2 planned move(s) applied' "$PGD/aout0" \
  && ok "progress: --apply stdout is byte-identical to the run without the variable" \
  || bad "progress: --apply stdout CHANGED when progress was on, or the moves were not applied"
for _v in 0 01 abc; do
  AI_DLC_MIGRATE_PROGRESS_EVERY="$_v" bash "$MIG" --root "$PW" > "$PGD/vo" 2> "$PGD/ve"; _rc=$?
  [ "$_rc" -eq 2 ] && [ ! -s "$PGD/vo" ] && grep -q 'AI_DLC_MIGRATE_PROGRESS_EVERY must be a positive integer' "$PGD/ve" \
    && ok "progress: AI_DLC_MIGRATE_PROGRESS_EVERY=$_v is a usage error, exit 2" \
    || bad "progress: AI_DLC_MIGRATE_PROGRESS_EVERY=$_v exited $_rc (want 2, empty stdout and the usage message)"
done
rm -rf "$PWA"

# =============================================================================
# 6. MUTANTS. Each removes ONE mechanism. An ARM is a named predicate over what a copy of the program
#    produced: T-* read the TREE after --apply, R-* read the report. Every mutant is a guarded COPY
#    (a sed that matches nothing is a failure) laid down beside its resolver sibling, so a copy that
#    cannot run is not scored as a kill; the unmutated control below runs the same layout.
#    Per push: the deciding arm must stop holding and the twin must keep holding. `--matrix` runs
#    every arm against every mutant and prints one row per cell.
# =============================================================================
MUT="$(mktemp -d "${TMPDIR:-/tmp}/apmig-mut-XXXXXX")"
RW="$(clone_world)"
mkdir -p "$RW/.claude/skills/ai-dlc"
printf '# consumer artifact paths\n\nareas:\n  _bmad-output/brainstorming\n' > "$RW/.claude/skills/ai-dlc/artifact-paths.md"
ARMS="T-ambig T-storyalpha T-storybeta T-conform T-hdr R-areas R-remedy-mig R-remedy-val R-forks R-progress R-applyscale A-read A-exists A-verify A-stage A-crlf A-quote"
lay_dir() { lay_pair "$1"; [ -z "$VAL" ] || cp "$VAL" "$1/v.sh"; }
names_a() { grep -q 'TREE-A-FILE\.md' <<<"$1" && ! grep -q 'TREE-B-FILE\.md' <<<"$1" \
              && ! grep -q '\.claude/skills/ai-dlc/artifact-paths\.md' <<<"$1"; }
# arm_hold <arm> <dir> -> returns 0 when the arm's expectation holds for the copy laid down in <dir>
arm_hold() {
  local a="$1" d="$2" w o
  case "$a" in
    T-*)
      if [ ! -f "$d/treepath" ]; then
        w="$(clone_world)" || return 2
        bash "$d/m.sh" --root "$w" --apply >/dev/null 2>&1
        printf '%s' "$w" > "$d/treepath"
      fi
      w="$(cat "$d/treepath")" ;;
  esac
  case "$a" in
    T-ambig)      [ -f "$w/_bmad-output/implementation-artifacts/gate-log-archive-s298-s299.md" ] ;;
    T-storyalpha) [ -f "$w/_bmad-output/planning-artifacts/s301/stories/story-1-alpha.md" ] ;;
    T-storybeta)  [ -f "$w/_bmad-output/planning-artifacts/s297/stories/story-1-beta.md" ] ;;
    T-conform)    [ -f "$w/_bmad-output/planning-artifacts/s299/stories/story-299-3-gamma.md" ] \
                    && [ ! -f "$w/_bmad-output/planning-artifacts/s299/stories/story-3-gamma.md" ] ;;
    T-hdr)        [ -f "$w/_bmad-output/planning-artifacts/s53/stories/story-1-effective-spread-500.md" ] \
                    && [ -f "$w/_bmad-output/planning-artifacts/s185/stories/story-1-three-digit.md" ] \
                    && [ -f "$w/_bmad-output/planning-artifacts/s72/stories/bug-124-deployed-range.md" ] ;;
    R-areas)      o="$(sed -n '/AREAS INFERRED/,/^$/p' <<<"$(bash "$d/m.sh" --root "$RW" 2>&1)")"
                  ! grep -q "_bmad-output/brainstorming" <<<"$o" && grep -q "party-verdicts-retro" <<<"$o" ;;
    R-remedy-mig) names_a "$(cd "$ra" && AI_DLC_PROJECT_ROOT="$rb" bash "$d/m.sh" --root "$ra" 2>&1)" ;;
    R-remedy-val) [ -f "$d/v.sh" ] && names_a "$(sed -n '/NO-AREA/,/move it under one/p' <<<"$(cd "$ra" && AI_DLC_PROJECT_ROOT="$rb" bash "$d/v.sh" --root "$ra" 2>&1)")" ;;
    # The two cost/progress arms are dry runs over read-only worlds, so each copy's answer is kept
    # beside it: the shipped copy is consulted once per mutant and is measured once.
    R-forks)      [ -f "$d/forks.rc" ] || { forks_hold "$d/m.sh"; echo "$?" > "$d/forks.rc"; printf '%s\n' "$FORKS_SEEN" > "$d/forks.seen"; }
                  read -r o < "$d/forks.rc"; return "$o" ;;
    R-applyscale) [ -f "$d/applyscale.rc" ] || { applyscale_hold "$d/m.sh"; echo "$?" > "$d/applyscale.rc"; printf '%s\n' "$APPLYSCALE_SEEN" > "$d/applyscale.seen"; }
                  read -r o < "$d/applyscale.rc"; return "$o" ;;
    R-progress)   [ -f "$d/progress.rc" ] || { progress_hold "$d/m.sh"; echo "$?" > "$d/progress.rc"; }
                  read -r o < "$d/progress.rc"; return "$o" ;;
    A-quote)      [ -f "$d/$a.rc" ] || { quote_hold "$d/m.sh"; echo "$?" > "$d/$a.rc"; }
                  read -r o < "$d/$a.rc"; return "$o" ;;
    A-read|A-exists|A-verify|A-stage|A-crlf)
                  [ -f "$d/$a.rc" ] || { abort_hold "$d/m.sh" "${a#A-}"; echo "$?" > "$d/$a.rc"; }
                  read -r o < "$d/$a.rc"; return "$o" ;;
  esac
}
SHIPD="$MUT/ship"; lay_dir "$SHIPD"
# The shipped pair was already measured on R-forks and R-progress in 5b; a byte-identical copy is
# not re-run per mutant (clause 3), its answers are carried over.
if cmp -s "$MIG" "$SHIPD/m.sh" && cmp -s "$CONFIG" "$SHIPD/artifact-path-config.sh"; then
  echo "$FORKS_RC_MIG" > "$SHIPD/forks.rc"; printf '%s\n' "$FORKS_SEEN_MIG" > "$SHIPD/forks.seen"
  echo "$APPLYSCALE_RC_MIG" > "$SHIPD/applyscale.rc"; printf '%s\n' "$APPLYSCALE_SEEN_MIG" > "$SHIPD/applyscale.seen"
  for _a in A-read A-exists A-verify A-stage A-crlf A-quote; do cp "$ABW/prim-$_a.rc" "$SHIPD/$_a.rc"; done
  if cmp -s "$PGD/err1" "$PGD/exp.plan" && cmp -s "$PGD/out1" "$PGD/out0"; then echo 0 > "$SHIPD/progress.rc"
  else echo 1 > "$SHIPD/progress.rc"; fi
fi
# mutant_score <name> <m|c|v: which file the sed edits> <sed flag> <sed program> <deciding arm> <twin arm> <claim>
mutant_score() {
  local n="$1" which="$2" flag="$3" prog="$4" dec="$5" tw="$6" claim="$7" d="$MUT/$1" src dst a base_rc
  lay_dir "$d"
  case "$which" in m) src="$MIG"; dst="$d/m.sh" ;; c) src="$CONFIG"; dst="$d/artifact-path-config.sh" ;; v) src="$VAL"; dst="$d/v.sh" ;; esac
  sed $flag "$prog" "$src" > "$dst.new" && mv "$dst.new" "$dst"
  if cmp -s "$src" "$dst"; then bad "MUTANT $n sed matched NOTHING -- the mutant IS the original"; return; fi
  if [ "$MATRIX" = 1 ]; then
    for a in $ARMS; do
      if arm_hold "$a" "$d"; then w=GREEN; else w=TRIPPED; fi
      if arm_hold "$a" "$SHIPD"; then sw=GREEN; else sw=TRIPPED; fi
      if [ "$w" = "$sw" ]; then kd=no; else kd=yes; fi
      matrix_row "$n" "$a" 0 "$w" "$kd"; MROWS=$((MROWS + 1))
    done
    ok "MATRIX $n measured against $(printf '%s\n' $ARMS | grep -c .) arms"
    return 0
  fi
  arm_hold "$dec" "$SHIPD"; base_rc=$?
  if arm_hold "$dec" "$d"; then bad "MUTANT $n SURVIVED on $dec -- $claim"
  else mutant_killed "$([ "$base_rc" -eq 0 ] && echo 1 || echo 0)" "$n" "MUTANT $n ($dec): $claim"; fi
  if arm_hold "$tw" "$d"; then ok "T-$n twin $tw stays GREEN under mutant $n (the change is confined to its deciding arm)"
  else bad "T-$n twin $tw TRIPPED under mutant $n -- the matrix row for this mutant moved"; fi
}

# UNMUTATED CONTROL, from the same directory layout: every arm must hold on a copy the way it does on
# the shipped file, so a harness that cannot run a copy reports itself broken instead of scoring kills.
# HERE-STRING, NOT A PIPE: `... | grep -q` under pipefail answers with the writer's SIGPIPE on a match.
lay_dir "$MUT/control"
ctl_held=0; ctl_n=0
for a in $ARMS; do ctl_n=$((ctl_n + 1)); arm_hold "$a" "$MUT/control" && ctl_held=$((ctl_held + 1)); done
ctl_out="$(bash "$MUT/control/m.sh" --root "$(clone_world)" 2>&1)"
if [ "$ctl_held" -eq "$ctl_n" ] && grep -q "outside the slot: 0" <<<"$ctl_out"; then
  ok "CONTROL: an unmutated copy in the mutant directory holds all $ctl_n arms and passes its own self-check"
else
  bad "CONTROL: an unmutated copy held $ctl_held of $ctl_n arms (or failed its self-check) -- the mutant harness is what is broken, not the mutants"
fi

mutant_score ambiguity-allowed m -E 's@^  if \[ "\$nhits" -gt 1 \]; then@  hits="$(printf "%s" "$hits" | head -1)"; nhits=1\n  if [ "$nhits" -gt 1 ]; then@' T-ambig T-conform \
  'collapsing to the FIRST sprint instead of refusing files a two-sprint path under a guess'
mutant_score stories-half-migrated m -E 's@^  nb="story-s@  nb="story-@' T-storybeta T-storyalpha \
  'without the bare-number normalisation one sprint stories split across two conventions (beta keeps its number)'
mutant_score story-slot-blind m -E 's@^  local head=@  return 0\n  local head=@' T-conform T-storyalpha \
  'a conforming story is re-migrated once the s<N>/-above-it test stops firing'
mutant_score hdr-over-name-off m -E 's@^      if \[ -n "\$hd_n" \] && \[ -n "\$nm_n" \] && \[ "\$hd_n" != "\$nm_n" \]; then@      if false; then@' T-hdr T-storyalpha \
  'without the override the item number is read as the sprint (s102, s230)'
mutant_score consumer-areas c "" 's@^  CONSUMER_AREAS="\$(areas_of "\$CONSUMER_AREAS_REL")"@  CONSUMER_AREAS=""@' R-areas T-conform \
  'without the consumer read, a declared area is inferred again: the join is load-bearing'
mutant_score remedy-root-mig m "" 's@--consumer-file --root "\$ROOT_ABS"@--consumer-file@' R-remedy-mig T-conform \
  'without --root the migration remedy names tree B file'
mutant_score remedy-root-val v "" 's@--consumer-file --root "\$ROOT_ABS"@--consumer-file@' R-remedy-val T-conform \
  'without --root the validator remedy names tree B file'

# THE FORK MUTANTS each put back ONE helper's pre-fix forking form, verbatim from 0.1101.0, behind
# the global the caller now reads -- so every planned path and every refusal is unchanged and only
# the process count moves. Each is inserted after the fixed definition (a later definition wins),
# by a sed script file, because the restored code carries both quote characters.
cat > "$MUT/base-sprints-in.txt" <<'EOF'
sprints_in() { # MUTANT fork-sprints-in: the pre-fix forking form, answering through the same global
  _SPRINTS_IN_OUT="$(_apmig_base_sprints_in "$1")"
}
_apmig_base_sprints_in() {
  local c cur prev n
  printf '%s\n' "$1" | tr '/' '\n' | while IFS= read -r c; do
    cur="$c"; prev=""
    while [ "$cur" != "$prev" ]; do
      prev="$cur"
      n="$(printf '%s' "$cur" | grep -oE "$TOKEN_RE" | head -1 | grep -oE '[0-9]+')"
      [ -n "$n" ] || break
      printf '%s\n' "$n"
      cur="$(printf '%s' "$cur" | sed -E 's/(^|-)(s|S|sprint-)[0-9]+(-|$|\.)/\1\3/')"
    done
  done | sort -u
}
EOF
cat > "$MUT/base-strip-token.txt" <<'EOF'
strip_token() { # MUTANT fork-strip-token: the pre-fix forking form, answering through the same global
  _STRIP_TOKEN_OUT="$(_apmig_base_strip_token "$1")"
}
_apmig_base_strip_token() {
  local cur="$1" prev=""
  while [ "$cur" != "$prev" ]; do
    prev="$cur"
    cur="$(printf '%s' "$cur" | sed -E 's/(^|-)(s|S|sprint-)[0-9]+(-|$|\.)/\1\3/')"
  done
  printf '%s' "$cur" | sed -E 's/--+/-/g; s/^-+//; s/-+(\.|$)/\1/'
}
EOF
printf '/^# A component that strips to nothing, or to a bare extension, has no name left/r %s\n' "$MUT/base-sprints-in.txt" > "$MUT/sed-fork-sprints-in"
printf '/^# A component that strips to nothing, or to a bare extension, has no name left/r %s\n' "$MUT/base-strip-token.txt" > "$MUT/sed-fork-strip-token"
cat > "$MUT/sed-fork-nhits" <<'EOF'
s@^  nhits=0; \[ -z "\$hits" \] .*$@  nhits="$(printf '%s\\n' "$hits" | grep -c .)"@
EOF
mutant_score fork-sprints-in m -f "$MUT/sed-fork-sprints-in" R-forks R-progress \
  'a sprint scan forking per component makes the plan cost grow with the tree'
mutant_score fork-strip-token m -f "$MUT/sed-fork-strip-token" R-forks R-progress \
  'a token strip forking per component of every one-sprint file (conforming ones included) grows with the tree'
mutant_score fork-nhits m -f "$MUT/sed-fork-nhits" R-forks R-progress \
  'counting the hits through a grep forks once per scanned file'
for _m in fork-sprints-in fork-strip-token fork-nhits; do
  [ -f "$MUT/$_m/forks.seen" ] && printf '        %s: %s\n' "$_m" "$(cat "$MUT/$_m/forks.seen")"
done

# THE APPLY MUTANT puts back the 0.1101.0 move loop verbatim -- two `shasum` and one `git mv` per
# move -- right after the apply start line, and empties the batched loop's work list so the batched
# loop below it never runs. Every move, check and VERDICT is the same; only the starts move.
cat > "$MUT/base-apply-loop.txt" <<'EOF'
MOVED=0
while IFS=$'\t' read -r src dest; do
  [ -n "$src" ] && [ -n "$dest" ] || continue
  before="$(shasum -a 256 "$src" 2>/dev/null | cut -d' ' -f1)"
  if [ -z "$before" ]; then
    echo "$PROG: FAIL — cannot read $src before moving it. Aborting after $MOVED move(s)." >&2
    exit 1
  fi
  if [ -e "$dest" ]; then
    echo "$PROG: FAIL — destination already exists: $dest. Aborting after $MOVED move(s)." >&2
    echo "  Not in the collision set, so it is a pre-existing file. Never overwritten." >&2
    exit 1
  fi
  mkdir -p "${dest%/*}" || { echo "$PROG: FAIL — cannot create ${dest%/*}" >&2; exit 1; }
  if ! git mv -- "$src" "$dest" 2>/dev/null; then
    echo "$PROG: FAIL — git mv refused: $src -> $dest. Aborting after $MOVED move(s)." >&2
    exit 1
  fi
  # PER-FILE, THREE LEGS, AND A COUNT WOULD SEE NONE OF THEM.
  after="$(shasum -a 256 "$dest" 2>/dev/null | cut -d' ' -f1)"
  if [ -e "$src" ] || [ ! -r "$dest" ] || [ "$before" != "$after" ]; then
    echo "$PROG: FAIL — verification failed for $src -> $dest" >&2
    echo "    source still present: $([ -e "$src" ] && echo yes || echo no)" >&2
    echo "    destination readable: $([ -r "$dest" ] && echo yes || echo no)" >&2
    echo "    sha256 before/after:  $before / ${after:-<unreadable>}" >&2
    echo "  Aborting after $MOVED verified move(s). \`git checkout -- .\` restores the tree." >&2
    exit 1
  fi
  MOVED=$((MOVED + 1))
done < "$PLAN"
_AP_N=0
EOF
printf '/PROGRESS apply: \$N_PLAN move(s) to apply" >&2$/r %s\n' "$MUT/base-apply-loop.txt" > "$MUT/sed-apply-per-file"
mutant_score apply-per-file m -f "$MUT/sed-apply-per-file" R-applyscale R-progress \
  'two shasum and one git mv per move make --apply cost grow with the plan (~280s on the reference consumer)'
[ -f "$MUT/apply-per-file/applyscale.seen" ] && printf '        apply-per-file: %s\n' "$(cat "$MUT/apply-per-file/applyscale.seen")"

# THE ABORT-PATH MUTANTS, one per rollback mechanism, plus the staging form B1 replaced. Sed scripts
# in files, because the anchors carry both quote characters.
cat > "$MUT/sed-verify-rollback-off" <<'EOF'
/^    _ap_rollback \$((_AP_VK + 1)) "\$_ap_done" \$((_AP_VK + 1))$/d
EOF
cat > "$MUT/sed-stage-bound-short" <<'EOF'
s@^    _ap_end=\$((_AP_VK + 1)); _ap_ok=@    _ap_end="$_AP_VK"; _ap_ok=@
EOF
cat > "$MUT/sed-hash-path-guard-off" <<'EOF'
s@ && \[ "\${_ah_l#\*  }" = "\$_ah_p" \]@@
EOF
cat > "$MUT/sed-stage-rollback-off" <<'EOF'
/^    _ap_rollback "\$_AP_LO" "\$_ap_end" \$((_AP_LO + 1))$/d
EOF
cat > "$MUT/sed-stage-add-rehash" <<'EOF'
s@^  git update-index -z --index-info < "\$TMP/apply-info" 2>/dev/null$@  _sg_k="$1"; while [ "$_sg_k" -lt "$2" ]; do printf '%s\\0%s\\0' "${_AP_S[$_sg_k]}" "${_AP_D[$_sg_k]}"; _sg_k=$((_sg_k + 1)); done | git update-index --add --remove -z --stdin 2>/dev/null@
EOF
mutant_score verify-rollback-off m -f "$MUT/sed-verify-rollback-off" A-verify A-crlf \
  'a failed verification leaves the later moves of its batch moved on disk and unstaged'
mutant_score stage-bound-short m -f "$MUT/sed-stage-bound-short" A-verify A-crlf \
  'staging stops one short of the failed move, which git mv had already staged'
# THE GUARD IS REACHED BY AN UNREADABLE PATH, NOT AN ESCAPED NAME: a name `shasum` escapes (a
# backslash in it) prints a line opening with `\`, which the check one conjunct earlier already
# refuses, so dropping this conjunct changes nothing for it. A path with NO line (the dangling
# source) is what shifts every later line onto the wrong path, which is what the guard stops. Its
# twin is the quoted-name world, which now plans a backslash name: it holding under this mutant is
# the measurement that the escaped name does not reach the guard.
mutant_score hash-path-guard-off m -f "$MUT/sed-hash-path-guard-off" A-read A-quote \
  'without the line-to-path check an unreadable source takes the next file s hash and the abort moves'
mutant_score stage-rollback-off m -f "$MUT/sed-stage-rollback-off" A-stage A-crlf \
  'a refused index update leaves the whole batch moved on disk and unstaged'
mutant_score stage-add-rehash m -f "$MUT/sed-stage-add-rehash" A-crlf A-stage \
  'git update-index --add re-hashes a CRLF file through text=auto and stages a content change'
# THE QUOTED READ: the line-delimited `ls-files` and the newline reads of its output, as before the
# NUL fix. Under the world's `core.quotePath true` every quoted name becomes a string naming no file.
cat > "$MUT/sed-quoted-read" <<'EOF'
s@^git ls-files -z -- \$(printf@git ls-files -- $(printf@
s@^{ while IFS= read -r -d '' _pg_rec; do@{ while IFS= read -r _pg_rec; do@
s@^while IFS= read -r -d '' src; do$@while IFS= read -r src; do@
EOF
mutant_score quoted-read m -f "$MUT/sed-quoted-read" A-quote A-crlf \
  'a C-quoted path names no file, so cafe, a backslash and a quote are never moved, and tab/newline never refused by name'
# THE EARLY, UNCONDITIONAL UNSAFE-NAME: every tab/newline path refused at the top of the loop, so a
# conforming or tokenless one that would make no row is refused too.
cat > "$MUT/sed-unsafe-early" <<'EOF'
s@^  case "\$src" in \*"\$_NL"\*|\*"\$_TAB"\*) _unsafe=1 ;; esac$@  case "$src" in *"$_NL"*|*"$_TAB"*) _unsafe_row; continue ;; esac@
EOF
mutant_score unsafe-early m -f "$MUT/sed-unsafe-early" A-quote A-crlf \
  'refusing every tab/newline name up front refuses a conforming and a tokenless file the migration would never touch'
mutant_score progress-stdout m -E '/PROGRESS (plan|apply):/s@" >&2$@"@' R-progress T-conform \
  'progress written to stdout changes the report operators and fixtures parse'
mutant_score progress-none m -E '/echo "\$PROG: PROGRESS/s@echo "[^"]*" >&2$@:@' R-progress T-conform \
  'with no progress line a long plan phase is silent, indistinguishable from a hang'

# A plain run executes no matrix-only cell; --matrix executes one row per mutant per arm.
if [ "$MATRIX" = 0 ]; then
  if [ "$MROWS" -eq 0 ]; then ok "MX plain run executed no matrix-only cell (matrix rows=0)"
  else bad "MX plain run executed $MROWS matrix-only rows"; fi
else
  _nx=$(( 20 * $(printf '%s\n' $ARMS | grep -c .) ))
  if [ "$MROWS" -eq "$_nx" ]; then ok "MX matrix run measured $MROWS mutant x arm cells (20 mutants)"
  else bad "MX matrix run measured $MROWS cells, $_nx expected"; fi
fi
rm -rf "$ra" "$rb" "$RW" "$MUT" "$FW1" "$FW2" "$PW" "$PGD" "$SHIMS" "$SHIMA" "$ABW"
rm -rf "$TPL"
echo
if [ "$fails" -eq 0 ]; then echo "artifact-path-migration: PASS ($asserts assertions)"; exit 0; fi
echo "artifact-path-migration: $fails of $asserts assertion(s) FAILED" >&2
exit 1
