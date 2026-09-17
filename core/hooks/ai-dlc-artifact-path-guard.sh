#!/usr/bin/env bash
#
# AI/DLC Artifact-Path Write Guard  (PreToolUse: Write)
#
# Holds a NEW artifact file to `artifact-path-grammar.md` rule 2 at the keystroke:
# the reserved `s<N>/` directory is the only sprint slot, and a basename carrying
# the sprint is a violation. `validate-artifact-paths.sh` already enforces this,
# but its only call site is the consumer pre-push — opt-in via `core.hooksPath`,
# batched over everything already committed, and reached AFTER the file has been
# written, merged, and cited by name in other artifacts as established fact.
#
# THE MEASURED EPISODE, and it is the reason the timing matters rather than the
# rule. A code-reviewer teammate wrote `docs/reviews/s312-story-2-1-gate1-review.md`;
# nothing stopped the Write; the file was committed, merged, then quoted verbatim as
# its own evidence trail by `pipeline-snapshot.md`, `pipeline-continuation-log.md`
# and a later gate-2 QA review. Detection came at `git push`, by which point the
# remedy is a rename plus an edit to every artifact that cited it.
#
# WHAT IT COSTS TO BE LATE, measured on the reference consumer: of the paths written
# under the scan roots after the grammar migration, 62 were later RENAMED onto the
# grammar BY HAND. That is the price this guard exists to stop paying, and it is a
# delivery fact rather than a projection.
#
# ---------------------------------------------------------------------------
# CONTRACT
#
#   DENY iff the tool is `Write`, the target sits under a declared scan root, and
#   the classifier blames THE BASENAME BEING WRITTEN. Everything else fails open.
#
#   `Write` ONLY, and never Edit/MultiEdit. An edit does not choose the name: the
#   file already exists under it, so denying the edit refuses a change to content
#   while the offending path stays exactly as it was. The affordance this removes
#   is CREATING a misplaced artifact, which is a property of Write alone.
#
#   THE BASENAME NARROWING IS THE WHOLE DESIGN, and it is measured rather than
#   chosen for caution. Of 73 blocking paths in that population, only 31 are blamed
#   on the basename. The other 42 are blamed on an ANCESTOR DIRECTORY the author did
#   not name in this call — 26 of them a correctly-spelled `s<N>` slot flagged only
#   for sitting at the wrong DEPTH. Denying a Write because of a directory that
#   already exists refuses a blameless basename and gives the author no action, so
#   this guard does not.
#
#   AND THE ANCESTOR CLASS IS NOT EVEN STABLE. Declaring ONE depth-3 area in the
#   consumer's `artifact-paths.md` moves all 26 of those rows NONCONFORMING ->
#   CONFORMING (measured: 73 -> 47, area sets asserted to differ at 17 vs 18 first).
#   Two legal remedies exist — move the slot up, or declare the deeper area — and
#   picking one on the author's behalf at write time is a judgment this cannot make.
#   `validate-enforcement-map.sh` I82b already owns that under-specification.
#
#   FAIL-OPEN ON EVERYTHING ELSE, AND THIS LIST IS THE CLAIM RATHER THAN A SUMMARY: not a
#   consumer, no `jq`, no `git`, unreadable grammar or areas, a path outside the project, a
#   path under no scan root, a GITIGNORED path (see the arm below — the batched validator
#   cannot judge one, so a deny here would be unappealable), AMBIGUOUS across the whole path
#   (two distinct sprints need the same human judgment they need today), a basename carrying a
#   character outside `[0-9a-zA-Z._-]`, a basename that IS a well-formed slot, and any
#   classifier refusal. A false deny wedges a pipeline and an over-broad one gets the hook
#   turned off — then nothing is enforced at all.
#
#   AN ENUMERATION LIKE THIS ONE IS A CLAIM THAT CAN BE FALSE, AND IT WAS. A tip adversary
#   found three spellings absent from an earlier version of this list: `./`, `//` and `/../`
#   forms that RESOLVE into a scan root were allowed, because the scan-root test compared an
#   unnormalised string. `REL` is normalised before that test now. If you add an exit above,
#   add it here.
#
#   FALSE-POSITIVE SET MEASURED BEFORE SHIPPING, as CLAUDE.md requires: ZERO over
#   the reference consumer's 6510 tracked files under the scan roots, and ZERO over
#   this distribution's 69. THAT TREE PASSES TODAY, so the live set holds no
#   offender and could not discriminate — the population had to be CONSTRUCTED from
#   history (every path ADDED under the scan roots after the migration, materialized
#   in a scratch tree carrying the consumer's real grammar) before the guard had a
#   corpus that could disagree with it.
#
# WHY A DENY RATHER THAN A WARNING. The plan-channel hook was held to a warning
# because plan mode's harness REQUIRES its path to exist, so a deny breaks the mode
# outright. No equivalent requirement exists here: every pipeline step prescribes a
# conforming destination, and `validate-enforcement-map.sh` I82 fails the build if
# core ever prescribes otherwise — so a deny here cannot contradict an instruction
# core gives. Where the mechanism is constructible without wedging live work, the
# blocking form is the one that removes the affordance.
#
# THE GRAMMAR IS RESOLVED, NEVER RESTATED. Both the scan roots and the sprint-token
# expression come from `artifact-path-config.sh`, the declared single home for them.
# A second copy of a four-line extraction is what a fork looks like the day before it
# stops being one: widen `areas:` and whichever copy nobody edited goes on governing
# a smaller tree while reporting the same clean line.
#
# INSTALL: wired by templates/settings.json.template (PreToolUse matcher "Write").
#   Upserted by reconcile/settings-merge.sh on pull. Hooks ship by glob
#   (install.sh copies core/hooks/*.sh), so this file needs no packaging edit.

set -u

INPUT="$(cat)"

command -v jq >/dev/null 2>&1 || exit 0

TOOL_NAME="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)"

# Write ONLY. See the contract above: an Edit does not choose the basename.
[ "$TOOL_NAME" = "Write" ] || exit 0

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

# ---------------------------------------------------------------------------
# Activation gate — a layered consumer only, the same stamp the core-layer guard
# uses. The distribution source repo governs its own paths through pre-push and
# has no `.claude/.ai-dlc-version`.
# ---------------------------------------------------------------------------
[ -f "$PROJECT_DIR/.claude/.ai-dlc-version" ] || exit 0

# ---------------------------------------------------------------------------
# Target path -> project-relative. Same normalisation as ai-dlc-core-guard.sh:
# an absolute path outside the project is not ours to judge.
# ---------------------------------------------------------------------------
TARGET="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
[ -n "$TARGET" ] || exit 0

# COLLAPSE `//` BEFORE THE PREFIX TEST, not only after it. A doubled slash at the project
# BOUNDARY (`$PROJECT_DIR//docs/...`) defeats the `"$PROJECT_DIR"/*` match itself, so the
# path is never recognised as being inside the tree and the later normaliser never sees it.
# Measured: that one spelling ALLOWED while the other three walk-forms denied correctly.
REL="$(printf '%s' "${TARGET#./}" | sed 's|//*|/|g')"
case "$REL" in
  "$PROJECT_DIR"/*) REL="${REL#"$PROJECT_DIR"/}" ;;
  /*)
    abs="$(cd "$PROJECT_DIR" 2>/dev/null && pwd)"
    case "$REL" in
      "$abs"/*) REL="${REL#"$abs"/}" ;;
      *) exit 0 ;;
    esac ;;
esac

# NORMALISE `//`, `/./` AND `/../` BEFORE THE SCAN-ROOT TEST, or the test answers about a
# string rather than about a location. Measured: `docs/plans/../reviews/s312-x.md` resolves
# INTO `docs/reviews` and was ALLOWED, because the `case "$REL" in "$r"/*` prefix match fails
# on the unresolved spelling. A step composing a path by concatenation produces exactly the
# `./` and `//` forms. This normalises rather than refusing: a path that walks ABOVE the
# project is left with leading `../` segments, matches no scan root, and takes the fail-open
# exit below, which is the correct answer for a path outside the tree.
while :; do
  case "$REL" in
    *//*)   REL="$(printf '%s' "$REL" | sed 's|//*|/|g')" ;;
    ./*)    REL="${REL#./}" ;;
    */./*)  REL="$(printf '%s' "$REL" | sed 's|/\./|/|g')" ;;
    */../*) REL="$(printf '%s' "$REL" | sed -E 's|(^\|/)[^/]+/\.\./|\1|')" ;;
    *) break ;;
  esac
done

# ---------------------------------------------------------------------------
# The resolver is the single home of the scan roots and the token expression.
# It is a SIBLING of the shipped scripts directory in the consumer layout.
# Any refusal from it is a fail-open: a guard that cannot resolve the grammar
# must not invent one.
# ---------------------------------------------------------------------------
CONFIG="$PROJECT_DIR/scripts/ai-dlc/artifact-path-config.sh"
[ -r "$CONFIG" ] || exit 0

# THE SCAN-ROOT TEST COMES FIRST, AND THE ORDER IS THE POINT. This hook is in front of EVERY
# `Write` in every consumer, and the vast majority of them are source files under no scan root
# at all. Resolving the token and slot expressions before establishing that the path is even
# our subject charges every one of those writes for an answer that is then discarded.
# Measured, 20 reps: 64ms for a path outside every root against a 9ms non-`Write` control.
# Only `--scan-roots` is needed to bail, so only it is resolved up front.
SCAN_ROOTS="$(bash "$CONFIG" --scan-roots --root "$PROJECT_DIR" 2>/dev/null)" || exit 0
[ -n "$SCAN_ROOTS" ] || exit 0

# Under a declared scan root? A path the enforcement never reads is not ours.
UNDER=0
while IFS= read -r r; do
  [ -n "$r" ] || continue
  case "$REL" in "$r"/*) UNDER=1; break ;; esac
done <<EOF
$SCAN_ROOTS
EOF
[ "$UNDER" -eq 1 ] || exit 0

TOKEN_RE="$(bash "$CONFIG" --token-re 2>/dev/null)" || exit 0
[ -n "$TOKEN_RE" ] || exit 0
SLOT_RE="$(bash "$CONFIG" --slot-re 2>/dev/null)" || exit 0
[ -n "$SLOT_RE" ] || exit 0

# ---------------------------------------------------------------------------
# A GITIGNORED PATH IS NOT THIS GUARD'S SUBJECT, AND DENYING ONE IS UNAPPEALABLE.
#
# `validate-artifact-paths.sh:136-140` builds its corpus with `git ls-files` — the TRACKED
# set. This hook's corpus is whatever an agent hands to `Write`. Those differ by exactly the
# ignored set, and the difference runs in the dangerous direction: for an ignored path the
# batched arm can never render a verdict, so a deny here is the ONLY verdict and there is no
# later gate to appeal to or to confirm it.
#
# MEASURED on the reference consumer, driving the shipped hook over its ignored paths under
# the scan roots: FIVE denials, all of them generated evidence the pipeline has been writing
# for hundreds of sprints -- `s241-1-evidence-manifest.txt`, `sprint-148-smoke-test-*.log`,
# `cdk-diff-s310-services-stack.txt` and two more, ignored by `*.txt` and `*.log`. Every
# future `sprint-NNN-*.log` would hit it. The guard's own header claims it governs the
# classifier's population; without this test it governs a strictly WIDER one, which is the
# consumer wedge this design was scoped to avoid.
#
# FAIL-OPEN, AS EVERYWHERE ELSE HERE: `git` absent, not a work tree, or any non-0/1 status
# leaves the path judged. `check-ignore` exits 0 when the path IS ignored, 1 when it is not.
# ---------------------------------------------------------------------------
if command -v git >/dev/null 2>&1; then
  git -C "$PROJECT_DIR" check-ignore -q -- "$REL" 2>/dev/null && exit 0
fi

BASE="${REL##*/}"

# ---------------------------------------------------------------------------
# THE PREDICATE, and it is deliberately the BASENAME half of the shipped
# classifier rather than a reimplementation of the whole thing.
#
# The classifier's area resolution decides WHICH COMPONENT is the legal slot, and
# that resolution is what the 26-row differential above showed to be unstable under
# a single area declaration. The basename, however, is NEVER the slot: a slot is a
# directory, and `validate-artifact-paths.sh` exempts only the component AT the slot
# index. So "the basename carries a sprint token" needs no area resolution at all,
# and it is the one verdict that cannot move when `areas:` changes.
#
# THE SLOT TEST IS STILL APPLIED, to a basename that IS a bare slot spelling. A
# directory named `s7` reaching here as a written file is not a rule-2 violation of
# the kind this denies, and refusing it would be refusing the grammar's own form.
# ---------------------------------------------------------------------------
case "$BASE" in
  *[!0-9a-zA-Z._-]*) exit 0 ;;   # anything exotic: not ours to judge
esac

# HERE-STRINGS, NEVER `printf | grep -q`. `grep -q` leaves at its first match while the
# writer is still pushing, so under pipefail the pipeline answers with the WRITER's EPIPE
# and reports NOT-FOUND on input that contains the pattern. I54 fails the build on the pipe
# form; the redirect goes at the end of the grep and the pipe disappears.
grep -qE "$SLOT_RE" <<<"$BASE" && exit 0
grep -qE "$TOKEN_RE" <<<"$BASE" || exit 0

# ---------------------------------------------------------------------------
# AMBIGUOUS fails open, and the count is taken over THE WHOLE PATH, not the basename.
# A path naming TWO distinct sprints cannot be placed by this guard any more than the
# migration can place it, and `validate-artifact-paths.sh` reports that class rather
# than blocking on it. Denying here would refuse a write whose only remedy is the human
# judgment the batched arm already defers.
#
# MEASURED, AND THE BASENAME-ONLY FORM WAS WRONG. Driving this guard over the reference
# consumer's 6510 tracked paths returned THREE denials on a tree the validator passes:
# `.../sprint-302/smoke-evidence/s253-execution-health-evidence.md` and two siblings, all
# three classed AMBIGUOUS ("names 302 253") because the ANCESTOR names one sprint and the
# basename another. Counting distinct sprints across the basename alone cannot see the
# second one, so the guard denied what the batched arm defers. The distinct-count is a
# property of the PATH; only the BLAME is a property of the basename.
# ---------------------------------------------------------------------------
NDISTINCT="$(sed 's/sprint-/s/g' <<<"$REL" \
  | tr '/.-' '\n\n\n' \
  | grep -E '^[sS][0-9]+$' \
  | sed 's/^[sS]//' \
  | sed 's/^0*\([0-9]\)/\1/' \
  | sort -u | grep -c .)" || NDISTINCT=0
[ "$NDISTINCT" -gt 1 ] && exit 0

# The conforming form, composed from the sprint the basename already names, so the
# remedy is a path rather than a rule. A grammar citation with no destination is
# what sends an author to the same failure one directory over.
SPRINT="$(printf '%s' "$BASE" \
  | sed 's/sprint-/s/g' \
  | tr '.-' '\n\n' \
  | grep -E '^[sS][0-9]+$' \
  | head -1 | sed 's/^[sS]//')"
DIR="${REL%/*}"

# THE STRIP RUNS OVER THE STEM ONLY, AND EVERY OCCURRENCE, AND BOTH ARE MEASURED FAULTS OF THE
# FORM THAT DID NOT.
#
# (a) SPLIT THE EXTENSION OFF FIRST. A token in the SUFFIX position ends at the `.`, so a
#     strip expression whose trailing class includes `.` consumes the extension separator:
#     `review-s288.md` became `review-md`. That position is the COMMON one --
#     `artifact-path-config.sh:106-108` records it as 173 files on the reference consumer and
#     is the reason `TOKEN_RE` is not anchored to a whole component -- so this was the usual
#     case, not an edge. The stem/ext split makes the `$` branch reachable for a trailing
#     token and keeps `.md` out of the subject entirely.
#
# (b) STRIP EVERY OCCURRENCE, NOT THE FIRST. `sed` replaces once per expression, so
#     `s12-s12-x.md` kept its second token and the suggested remedy was DENIED by this very
#     hook on the next keystroke -- a mechanism defending its own defect, and an instruction
#     the author cannot follow. The loop runs to a fixed point.
STEM="$BASE"; EXT=""
case "$BASE" in
  ?*.*) EXT=".${BASE##*.}"; STEM="${BASE%.*}" ;;
esac
while :; do
  _n="$(printf '%s' "$STEM" | sed -E "s/(^|-)(s|S|sprint-)0*${SPRINT}(\$|-)/\1/")"
  [ "$_n" = "$STEM" ] && break
  STEM="$_n"
done
STEM="$(printf '%s' "$STEM" | sed -E 's/^-+//; s/-+$//; s/-{2,}/-/g')"
STRIPPED="${STEM}${EXT}"
# A BASENAME THAT WAS ONLY THE TOKEN HAS NO NAME LEFT, AND FALLING BACK TO IT IS A DENIED
# REMEDY. `s304.md` strips to an empty stem; suggesting `$BASE` put the token back and the
# composed path `s304/s304.md` was refused by this same hook -- the defect (b) above, arriving
# through the fallback rather than through the strip. The grammar's own answer for a file that
# names only its sprint is the slot plus a generic stem, which `artifact-path-grammar.md`
# spells as `docs/retro/s<N>/retro.md` for exactly this shape.
[ -n "$STEM" ] || STRIPPED="artifact${EXT}"
case "$DIR" in
  *"/s${SPRINT}") SUGGEST="${DIR}/${STRIPPED}" ;;
  *)              SUGGEST="${DIR}/s${SPRINT}/${STRIPPED}" ;;
esac

reason="${REL} puts the sprint in the BASENAME, and \`artifact-path-grammar.md\` rule 2 reserves the \`s<N>/\` DIRECTORY as the only sprint slot. Write it to \`${SUGGEST}\` instead. This is refused at the keystroke deliberately: the batched arm (\`validate-artifact-paths.sh\`, consumer pre-push) would not see it until \`git push\`, which on the measured episode was after the file had been committed, merged, and cited by name as established evidence in three other artifacts -- so the remedy there is a rename PLUS an edit to everything that quoted it. A basename carrying the sprint also makes every later reader search for the file, and search means sorting by mtime. If this path is genuinely not a sprint artifact, it does not belong under a declared scan root; if it names TWO sprints, this guard does not fire at all and the pre-push arm reports it for a human."

ctx="AI/DLC artifact-path guard: rule 2 of artifact-path-grammar.md -- the reserved s<N>/ directory is the only sprint slot, and a basename carrying the sprint is a violation. This hook denies ONLY a Write whose own BASENAME carries the token; a path blamed on an ancestor DIRECTORY fails open, because that directory was not named in this call and has two legal remedies (move the slot, or declare the deeper area). The suggested destination is composed from the sprint the basename already names, not from a search. The grammar, the scan roots and the token expression are resolved from scripts/ai-dlc/artifact-path-config.sh, never restated here."

# PROVENANCE MARKER -- the library is a SIBLING in both layouts (core/hooks/,
# .claude/hooks/), so this is a same-directory read and never a walk up from a
# resolved path. Fail-open: a hook that cannot mark its output still emits it.
_AI_DLC_PROV="$(dirname "${BASH_SOURCE[0]}")/ai-dlc-context-provenance.sh"
if [ -r "$_AI_DLC_PROV" ]; then . "$_AI_DLC_PROV"
else ai_dlc_provenance_wrap() { printf %s "${3:-}"; }; fi
ctx="$(ai_dlc_provenance_wrap ai-dlc-artifact-path-guard PreToolUse "$ctx")"

jq -n --arg reason "$reason" --arg ctx "$ctx" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason,
    additionalContext: $ctx
  }
}'
exit 0
