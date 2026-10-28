#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
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
# exact-vector assertion and is re-measured whenever an arm or a mutant changes. Arm names are the
# column names `--matrix` prints (T-* read the tree after --apply, R-* read the report).
# MUTANT-MATRIX whole-path-scan decides=T-wholepath twins=T-conform
# MUTANT-MATRIX ambiguity-allowed decides=T-ambig twins=T-conform
# MUTANT-MATRIX stories-half-migrated decides=T-storybeta twins=T-storyalpha
# MUTANT-MATRIX story-slot-blind decides=T-conform twins=T-storyalpha
# MUTANT-MATRIX hdr-over-name-off decides=T-hdr twins=T-storyalpha
# MUTANT-MATRIX consumer-areas decides=R-areas twins=T-conform
# MUTANT-MATRIX remedy-root-mig decides=R-remedy-mig twins=T-conform
# MUTANT-MATRIX remedy-root-val decides=R-remedy-val twins=T-conform
# MUTANT-MATRIX-DYNAMIC mutant_score-name why=mutant_score() passes its first argument "$n" to mutant_killed; each mutant_score call (whole-path-scan, ambiguity-allowed, ...) names a literal mutant that carries its own row in this block
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
ARMS="T-wholepath T-ambig T-storyalpha T-storybeta T-conform T-hdr R-areas R-remedy-mig R-remedy-val"
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
    T-wholepath)  [ ! -f "$w/docs/retro/sprint-301.md" ] && [ -f "$w/docs/retro/s301/retro.md" ] ;;
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
  esac
}
SHIPD="$MUT/ship"; lay_dir "$SHIPD"
# mutant_score <name> <m|c|v: which file the sed edits> <sed flag> <sed program> <deciding arm> <twin arm> <claim>
mutant_score() {
  local n="$1" which="$2" flag="$3" prog="$4" dec="$5" tw="$6" claim="$7" d="$MUT/$1" src dst a base
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
  if arm_hold "$dec" "$SHIPD"; then base=1; else base=0; fi
  if arm_hold "$dec" "$d"; then bad "MUTANT $n SURVIVED on $dec -- $claim"
  else mutant_killed "$base" "$n" "MUTANT $n ($dec): $claim"; fi
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

mutant_score whole-path-scan m -E "s@[|] tr '/' '.n' [|]@|@" T-wholepath T-conform \
  'scanning the whole path leaves docs/retro/sprint-301.md unmigrated -- the 668-vs-2551 defect'
mutant_score ambiguity-allowed m -E 's@^  if \[ "\$nhits" -gt 1 \]; then@  hits="$(printf "%s" "$hits" | head -1)"; nhits=1\n  if [ "$nhits" -gt 1 ]; then@' T-ambig T-conform \
  'collapsing to the FIRST sprint instead of refusing files a two-sprint path under a guess'
mutant_score stories-half-migrated m -E 's@/story-s@/story-@' T-storybeta T-storyalpha \
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

# A plain run executes no matrix-only cell; --matrix executes one row per mutant per arm.
if [ "$MATRIX" = 0 ]; then
  if [ "$MROWS" -eq 0 ]; then ok "MX plain run executed no matrix-only cell (matrix rows=0)"
  else bad "MX plain run executed $MROWS matrix-only rows"; fi
else
  _nx=$(( 8 * $(printf '%s\n' $ARMS | grep -c .) ))
  if [ "$MROWS" -eq "$_nx" ]; then ok "MX matrix run measured $MROWS mutant x arm cells (8 mutants)"
  else bad "MX matrix run measured $MROWS cells, $_nx expected"; fi
fi
rm -rf "$ra" "$rb" "$RW" "$MUT"
rm -rf "$TPL"
echo
if [ "$fails" -eq 0 ]; then echo "artifact-path-migration: PASS ($asserts assertions)"; exit 0; fi
echo "artifact-path-migration: $fails of $asserts assertion(s) FAILED" >&2
exit 1
