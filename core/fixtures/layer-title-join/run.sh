#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# layer-title-join — assert the absorption question is asked of PROSE headings, and that
# the two exclusions that make it bearable are real rather than aspirational.
#
# THE DEFECT THIS EXISTS FOR. `layer-drift.sh`'s absorption pass is gated on
# `anchors_of_file` returning something, and both of that function's arms require a leading
# integer or a short uppercase id. An entry whose headings are ordinary prose yields nothing,
# so the ENTIRE catalog reconciliation is skipped for it — silently, and indistinguishably
# from a clean result. Measured with the shipping functions against the reference consumer:
# 11 of 38 entries yield an anchor, 27 yield none, and the blind 27 include every role entry
# and every SKILL entry. Two absorptions core had already landed were sitting unreported
# behind it.
#
# WHAT THE NEW STATUS MAY AND MAY NOT CLAIM. A numbered anchor is an identity claim
# (`### 921.` asserts "this IS check 921"), so agreeing on number and title is duplication
# and RESTATES-CORE's "retire it" follows. A prose heading asserts nothing of the kind:
# `## Block: Step 1 Read Project State` NAMES the core step the entry augments. So
# EXTENSION-TITLE-MATCHES-CORE reports the match and prescribes no delete, and Part 5 asserts
# it never degrades into the stronger status — a fixture that only checked "something fired"
# would score a data-loss suggestion as a pass.
#
# Usage: run.sh [path-to-layer-drift.sh]
# Exit:  0 = every assertion holds, 1 = an arm regressed, 2 = the fixture could not run.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
DRIFT="$(pick "${1:-}" "$HERE/../../skills/ai-dlc-update/reconcile/layer-drift.sh" \
                       "$HERE/../../../core/skills/ai-dlc-update/reconcile/layer-drift.sh" \
                       "$HERE/../../../.claude/skills/ai-dlc-update/reconcile/layer-drift.sh")"
# A MISSING SUBJECT IS NOT A PASS. Every assertion below is "did this row appear", so a run
# that cannot invoke the classifier at all produces no rows and would score green on the
# negative arms. Exit 2, loudly.
[ -n "$DRIFT" ] || { echo "FIXTURE ERROR: cannot locate layer-drift.sh" >&2; exit 2; }

ROOT="$(mktemp -d "${TMPDIR:-/tmp}/layer-title-join.XXXXXX")"
trap 'rm -rf "$ROOT"' EXIT
DIST="$ROOT/dist"; CONS="$ROOT/consumer"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

echo "layer-title-join:"

# ---------------------------------------------------------------------------------------
# The distribution at BASE.
#
# `## Shared Skeleton` is deliberately in BOTH role files and in nothing else's business:
# that is what makes it skeletal, and the exclusion is DERIVED from that recurrence rather
# than from a list, so the seed has to actually produce the recurrence for Part 3 to mean
# anything. `## Widget Handling` appears in exactly one file, so it stays a section.
# ---------------------------------------------------------------------------------------
mkdir -p "$DIST/core/skills/ai-dlc/steps" "$DIST/core/team-roles" "$CONS/.claude/skills/ai-dlc/extensions"
git -C "$DIST" init -q 2>/dev/null || { echo "FIXTURE ERROR: git init failed" >&2; exit 2; }

# THE ADJUDICATION VOCABULARY IS READ FROM THE SCHEMA AT THEIRS, so a synthetic dist that
# omits it yields an EMPTY verdict set — and an empty set makes every register lookup miss,
# which reads exactly like "no verdict was recorded". Part 6 below could not tell those apart.
# Copy the REAL schema in rather than restating an enum here; a second copy of the vocabulary
# is the thing the reader was written to avoid.
# BOTH LAYOUTS, VIA THE `pick` HELPER ALREADY DEFINED ABOVE FOR layer-drift.sh. The first
# cut of this seed was `$HERE/../../schemas/...`, which resolves to core/schemas only in the
# DISTRIBUTION; from a consumer's tests/fixtures/<name>/ the same walk lands on tests/schemas,
# which does not exist, and the fixture died in the seed. That is invariant I33's rule -- never
# locate one core file by walking up from another -- broken three lines under a helper written
# for exactly this, and it turned a green machinery pull into a red covering fixture on the
# reference consumer.
mkdir -p "$DIST/core/schemas"
ADJ_SRC="$(pick "$HERE/../../schemas/layer-adjudication-register.json" \
                "$HERE/../../../core/schemas/layer-adjudication-register.json" \
                "$HERE/../../../.claude/schemas/layer-adjudication-register.json")"
[ -n "$ADJ_SRC" ] || { echo "FIXTURE ERROR: layer-adjudication-register.json not found in either layout" >&2; exit 2; }
cp "$ADJ_SRC" "$DIST/core/schemas/" || { echo "FIXTURE ERROR: cannot seed the adjudication schema" >&2; exit 2; }

cat > "$DIST/core/skills/ai-dlc/core-manifest.md" <<'MD'
<!-- CORE_MANIFEST v1 -->
machinery:
  - core-manifest.md
rulebook:
  - steps/*.md
  - team-roles/*.md
MD

cat > "$DIST/core/skills/ai-dlc/steps/widget.md" <<'MD'
# Widget

## Widget Handling

Core text for widget handling.

### 3. Numbered Widget Section.

Core numbered text.
MD

for r in alpha beta; do
  cat > "$DIST/core/team-roles/${r}.md" <<'MD'
# Role

## Shared Skeleton

Every role file carries this heading.
MD
done
# Part 3's control lives HERE, in the file the SKELETON entry hooks. An extension is
# compared against its OWN hooked file and nothing else, so a heading borrowed from
# widget.md would go unmatched for a reason that has nothing to do with the exclusion under
# test — the first cut of this fixture did exactly that and reported a defect that was not
# one. It appears in one rulebook file, so it is a section, not a skeleton.
cat >> "$DIST/core/team-roles/alpha.md" <<'MD'

## Role Specific Section

Only alpha defines this.
MD

cat > "$DIST/core/skills/ai-dlc/layer-contract.yaml" <<'YML'
contract_version: 15
YML

git -C "$DIST" add -A >/dev/null 2>&1
git -C "$DIST" -c user.email=f@x -c user.name=f commit -qm base >/dev/null 2>&1
BASE="$(git -C "$DIST" rev-parse --short HEAD)"

# THEIRS adds a section that did NOT exist at base, so Part 6 can tell the two tags apart.
cat >> "$DIST/core/skills/ai-dlc/steps/widget.md" <<'MD'

## Freshly Absorbed Widget Rule

Core adopted this on this pull.
MD
git -C "$DIST" add -A >/dev/null 2>&1
git -C "$DIST" -c user.email=f@x -c user.name=f commit -qm theirs >/dev/null 2>&1
THEIRS="$(git -C "$DIST" rev-parse --short HEAD)"

# ---------------------------------------------------------------------------------------
# The consumer layer.
# ---------------------------------------------------------------------------------------
mkext() { # mkext <name> <hooks> <body-file-content-on-stdin>
  cat > "$CONS/.claude/skills/ai-dlc/extensions/$1.md" <<EOF
---
kind: step-domain
hooks: $2
id: $1
push_candidate: false
conforms_to: 15
---

$(cat)
EOF
}

mkext MATCH steps/widget.md <<'MD'
## Widget Handling

Consumer text under a heading that names core's section.
MD

mkext CONTROL steps/widget.md <<'MD'
## Entirely Unrelated Consumer Concern

Nothing in core names this.
MD

mkext SKELETON team-roles/alpha.md <<'MD'
## Shared Skeleton

Consumer additions to its own role file.

## Role Specific Section

A second heading in the same entry, which the hooked core file DOES define as a section.
MD

mkext CONTAINER steps/widget.md <<'MD'
## 3 (numbered widget section)

### 3. [ext:CONTAINER] Numbered Widget Section.

The inner heading is the anchor; the outer one merely wraps it.
MD

mkext FRESH steps/widget.md <<'MD'
## Freshly Absorbed Widget Rule

Consumer text core adopted between base and theirs.
MD

# --- LC-E20's three seeds. See Part 8 for what separates them. -------------------------
#
# THE NAIVE GUARD AND THE SHIPPED ONE AGREE ON `NOHEAD` AND DISAGREE ON `NUMONLY`, and that
# is the only pair that can tell them apart. `ext_titles` is this file's headings MINUS the
# ones the numbered arm owns, so an entry built entirely out of NUMBERED headings harvests
# empty there while being fully checked by the numbered arm forty lines up. A row keyed on
# the empty `ext_titles` accuses it of being unreachable while the join is reading it. Seed
# them together or Part 8's positive arm passes against the false-positive guard too.
mkext NOHEAD steps/widget.md <<'MD'
This entry is frontmatter plus prose and carries no markdown heading of any kind, so
neither absorption join can harvest anything from it and neither can ever report it as
absorbed — whatever core has since adopted.
MD

mkext NUMONLY steps/widget.md <<'MD'
### 3. [ext:NUMONLY] Numbered Widget Section.

Every heading in this entry is NUMBERED, so `unnumbered_titles_of_file` harvests EMPTY —
exactly like NOHEAD — while the numbered arm reads it fully. This is the naive guard's
false-positive set, and it must stay silent.
MD

# THE PREDICATE IS `#{2,6}`, WIDER THAN EITHER JOIN'S `#{2,4}`, AND THIS IS THE SEED THAT
# HOLDS IT THERE. An h5 heading is invisible to both joins (their grammar stops at `####`)
# AND invisible to `heading_titles_of_stream`, so `ext_titles` is empty here too. The row's
# claim is "no heading of any kind is present", which is FALSE of this entry — an h5 body is
# a different gap and is not this row's to state. Narrow the predicate to `#{2,4}` and this
# entry starts being accused; the mutant below does exactly that.
mkext H5ONLY steps/widget.md <<'MD'
##### Deep Consumer Heading

This entry's only heading is an h5, which is below both joins' `#{2,4}` grammar. It has a
heading, so LC-E20's claim does not hold of it.
MD

OUT="$(bash "$DRIFT" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>"$ROOT/err")"
st() { printf '%s\n' "$OUT" | awk -F'\t' -v e="$1" '$2 ~ e {print $1}'; }
detail() { printf '%s\n' "$OUT" | awk -F'\t' -v e="$1" -v s="$2" '$1==s && $2 ~ e {print $4}'; }

# --- Part 1: a prose heading naming a core section is reported -------------------------
if grep -qx EXTENSION-TITLE-MATCHES-CORE <<<"$(st 'MATCH\.md$')"; then
  ok "an unnumbered heading that names a core section is reported"
else
  bad "an unnumbered heading matching core was NOT reported — 27 of 38 real entries are this shape, and the absorption pass never looked at any of them"
fi

# --- Part 2: the control, and its non-vacuity ------------------------------------------
if grep -qx EXTENSION-TITLE-MATCHES-CORE <<<"$(st 'CONTROL\.md$')"; then
  bad "CONTROL: an entry whose heading names NOTHING in core was reported — the arm matches any unnumbered heading, not a matching one"
else
  ok "  an entry naming nothing in core stays silent"
fi
# Its silence is only evidence if the entry reached the classifier at all.
if [ "$(printf '%s\n' "$OUT" | grep -c 'CONTROL\.md')" -ge 1 ]; then
  ok "  CONTROL appears under some other status, so its silence above is a real zero"
else
  bad "the control entry produced NO row at all — its silence proves nothing about the arm"
fi

# --- Part 3: skeleton headings are excluded, and the exclusion is not a blanket mute ----
# `## Shared Skeleton` recurs across two rulebook files, so it is the SHAPE of a role file
# and not a section a consumer could be duplicating. `identity` vs `identity` scores a
# perfect match and means nothing; on the reference consumer this class was 6 of the 20
# rows first contact produced.
sk_details="$(detail 'SKELETON\.md$' EXTENSION-TITLE-MATCHES-CORE)"
if grep -q 'shared skeleton' <<<"$sk_details"; then
  bad "a heading shared by two core rulebook files was reported — that is a document skeleton, and retiring the entry would delete the consumer's only copy of its own text"
else
  ok "  a heading recurring across rulebook files is excluded as skeletal"
fi
# THE LOAD-BEARING CONTROL. The same entry also carries `## Widget Handling`, which core
# defines once. If the exclusion were implemented as "skip this entry" — or if the rulebook
# derivation silently returned everything — this assertion goes red while the one above
# stays green, which is the only way to tell an exclusion from an outage.
if grep -q 'role specific section' <<<"$sk_details"; then
  ok "  and the SAME entry's non-skeletal heading is still reported (the exclusion is per heading, not per entry)"
else
  bad "the skeleton exclusion silenced a non-skeletal heading in the same entry — it is muting entries, not headings"
fi

# --- Part 4: a container for a numbered heading belongs to the numbered arm -------------
# `## 3 (numbered widget section)` wrapping `### 3. [ext:CONTAINER] …` is one section
# written at two levels. Reporting the outer one puts a row on an entry that has ALREADY
# done the one thing core asks for — labelling its catalog at the point of use — and a
# detector that cannot be silenced by following its own advice stops being read.
if grep -qx EXTENSION-TITLE-MATCHES-CORE <<<"$(st 'CONTAINER\.md$')"; then
  bad "the unnumbered CONTAINER of an already-labelled numbered heading was reported — the resolved state is being flagged as a defect"
else
  ok "  a heading opening with an anchor the entry declares is left to the numbered arm"
fi
# POSITIVE CONTROL for Part 4: the numbered arm must still see that entry. Without this,
# deleting the numbered pass outright would make Part 4 pass.
if [ "$(printf '%s\n' "$OUT" | grep -c 'CONTAINER\.md')" -ge 1 ]; then
  ok "  and the CONTAINER entry is still classified by the numbered arm"
else
  bad "the CONTAINER entry produced no row at all — Part 4's silence would pass against a detector that had stopped looking"
fi

# --- Part 5: the prose arm must not degrade into the status that prescribes deletion ----
#
# ASSERTED AS AN EXACT SET, not as three named absences. A named-absence list only forbids
# the statuses whoever wrote it thought of, and it goes stale the moment a status is added;
# an exact set forbids everything that is not expected, including codes that do not exist
# yet. It also means this file names no contract code it cannot make FIRE — naming one it
# only ever asserts the absence of would bind the clause to a fixture that never proves it.
want="EXTENSION-HOOK-DRIFT
EXTENSION-TITLE-MATCHES-CORE"
got="$(st 'MATCH\.md$' | sort -u)"
if [ "$got" = "$want" ]; then
  ok "  a prose title match yields EXACTLY the title status (plus the file-grain drift row)"
else
  bad "a prose title match yielded an unexpected status set — a stronger status here tells the operator to retire an entry that may be naming the section it AUGMENTS. want=[$(tr '\n' ' ' <<<"$want")] got=[$(tr '\n' ' ' <<<"$got")]"
fi

# THE POSITIVE HALF, and the reason Part 5 can be trusted. If the numbered arm were simply
# dead, the exact-set assertion above would pass for the wrong reason — nothing else could
# ever appear. CONTAINER's `### 3.` matches core's `### 3.` at the same number AND title, so
# the numbered arm must still say so.
if grep -qx EXTENSION-RESTATES-CORE <<<"$(st 'CONTAINER\.md$')"; then
  ok "  and the numbered arm still emits EXTENSION-RESTATES-CORE on a same-number same-title duplicate"
else
  bad "the numbered arm emitted no EXTENSION-RESTATES-CORE — Part 5's exact-set assertion would then pass against a classifier that had stopped classifying"
fi

# --- Part 6: NEW-THIS-PULL and PRE-EXISTING are told apart ------------------------------
# The tag is what dates the duplication. Collapsing them would report every long-carried
# duplicate as landing on this pull, hiding how long it has been rotting.
case "$(detail 'FRESH\.md$' EXTENSION-TITLE-MATCHES-CORE)" in
  NEW-THIS-PULL*) ok "  a section core added base..theirs is tagged NEW-THIS-PULL" ;;
  *)              bad "a section absorbed on THIS pull was not tagged NEW-THIS-PULL: $(detail 'FRESH\.md$' EXTENSION-TITLE-MATCHES-CORE | cut -c1-40)" ;;
esac
case "$(detail 'MATCH\.md$' EXTENSION-TITLE-MATCHES-CORE)" in
  PRE-EXISTING*) ok "  a section core carried at base is tagged PRE-EXISTING" ;;
  *)             bad "a long-standing duplicate was not tagged PRE-EXISTING: $(detail 'MATCH\.md$' EXTENSION-TITLE-MATCHES-CORE | cut -c1-40)" ;;
esac

# --- Part 7: a rulebook glob that resolves to nothing is LOUD --------------------------
# A partial rulebook set and a complete one are both non-empty, so "did we get any files"
# cannot tell them apart. The first cut of the derivation listed a single subtree and lost
# every `team-roles/*.md` file — 24 files came back and the skeleton exclusion was quietly
# running on two thirds of the rulebook. This asserts the per-glob zero is reported.
cat > "$DIST/core/skills/ai-dlc/core-manifest.md" <<'MD'
<!-- CORE_MANIFEST v1 -->
machinery:
  - core-manifest.md
rulebook:
  - steps/*.md
  - team-roles/*.md
  - nowhere/*.md
MD
git -C "$DIST" add -A >/dev/null 2>&1
git -C "$DIST" -c user.email=f@x -c user.name=f commit -qm "a glob that matches nothing" >/dev/null 2>&1
THEIRS3="$(git -C "$DIST" rev-parse --short HEAD)"
bash "$DRIFT" "$DIST" "$BASE" "$THEIRS3" "$CONS" >/dev/null 2>"$ROOT/err3"
if grep -q "nowhere/\*\.md" "$ROOT/err3"; then
  ok "  a rulebook glob matching no file is reported per glob, not swallowed by a non-empty total"
else
  bad "a rulebook glob matching nothing produced no warning — the skeleton exclusion can run on a partial set that reads exactly like a complete one"
fi
# CONTROL: the healthy manifest must NOT produce that warning, or the assertion above is
# satisfied by a script that warns unconditionally.
if grep -q "matches NO file" "$ROOT/err"; then
  bad "CONTROL: the healthy manifest also warned — the guard fires unconditionally and proves nothing"
else
  ok "  and a manifest whose globs all resolve stays quiet"
fi

# =======================================================================================
# Part 8: LC-E20 — AN ENTRY NO ABSORPTION JOIN CAN SEE SAYS SO, AND THE GUARD IS
#         "NO HEADING AT ALL" RATHER THAN "ext_titles IS EMPTY".
#
# THE DEFECT. Both absorption arms key on a markdown HEADING — the numbered one on
# `anchors_of_file`, the unnumbered one on `unnumbered_titles_of_file`. An entry whose body
# carries no heading anywhere harvests EMPTY from both, `cand` is never populated, the
# absorption block never runs and there is no `else`. The only row such an entry can produce
# is the drift arm's `EXTENSION-OK`, which `emit-report.sh` filters out of the
# operator-facing section — so an entry that no duplication join has ever been able to read
# arrives as silence indistinguishable from a clean check.
#
# THE ARM THAT MATTERS IS THE NEGATIVE ONE, and it is why `NUMONLY` is seeded. A guard keyed
# on the empty `ext_titles` reports BOTH entries and looks correct against a fixture that
# only asserts the positive: `ext_titles` is the file's headings MINUS the ones the numbered
# arm owns, so an entry built entirely out of numbered headings harvests empty there while
# being read in full by the numbered arm. On the reference consumer that naive guard scores
# 14 of 40 registered entries where the shipped one scores 4 — a ten-entry false-positive
# set, and every one of them a true accusation of unreachability against a join that was
# reading it.
#
# THIS SECTION NAMES `EXTENSION-NO-HEADINGS` IN ITS ASSERTIONS, NOT ONLY IN THIS COMMENT.
# I65 joins a clause to the fixture that proves its code fires, and it refuses a fixture
# whose only mention of the code is prose: a header sentence listing what a fixture covers
# is a statement ABOUT the proof, never the proof. LC-E20's `fixture:` is updated from
# `none` to this directory in the same change, and I65's reverse arm would fail the push if
# it were not.
# =======================================================================================
echo ""

# 8a. THE POSITIVE. An entry with no heading at all is reported.
if grep -qx EXTENSION-NO-HEADINGS <<<"$(st 'NOHEAD\.md$')"; then
  ok "an entry carrying NO markdown heading is reported as EXTENSION-NO-HEADINGS"
else
  bad "an entry with no heading of any kind produced no EXTENSION-NO-HEADINGS row — both absorption joins harvest empty from it, so its only other row is the filtered EXTENSION-OK and its unreachability reads to the operator as a clean check"
fi

# 8b. THE DISCRIMINATING NEGATIVE, and the whole reason 8a is not satisfied by the naive
#     guard. NUMONLY has an EMPTY `ext_titles` — identical to NOHEAD at that grain — and IS
#     fully checked, by the numbered arm.
if grep -qx EXTENSION-NO-HEADINGS <<<"$(st 'NUMONLY\.md$')"; then
  bad "an entry built entirely out of NUMBERED headings was reported as having no heading — the guard is keyed on the empty ext_titles rather than on the absence of a heading, which accuses 10 of the reference consumer's 40 entries of being unreachable while the numbered join is reading them"
else
  ok "  an entry whose every heading is NUMBERED is NOT reported (its ext_titles is empty too, and the numbered arm reads it)"
fi
# THE NON-VACUITY CONJUNCT for 8b. Its silence on this status is evidence only if the entry
# reached the classifier at all; an entry that produced no row whatsoever would satisfy 8b
# against a pass that had simply stopped looking at it.
if [ "$(printf '%s\n' "$OUT" | grep -c 'NUMONLY\.md')" -ge 1 ]; then
  ok "  and NUMONLY does appear under some other status, so its silence above is a real zero"
else
  bad "the NUMONLY entry produced NO row at all — 8b's silence proves nothing, because an entry the classifier never reached is silent on every status"
fi

# 8c. THE PREDICATE'S WIDTH, asserted as its own case. `#{2,6}` is wider than either join's
#     `#{2,4}` on purpose: an h5-only entry is invisible to both joins AND has an empty
#     `ext_titles`, but it HAS a heading, so this row's claim is false of it.
if grep -qx EXTENSION-NO-HEADINGS <<<"$(st 'H5ONLY\.md$')"; then
  bad "an entry whose only heading is an h5 was reported as having NO heading — the predicate has narrowed to the joins' own #{2,4} and the row now makes a claim that is false of its subject"
else
  ok "  an entry whose only heading is an h5 is NOT reported (it has a heading; its invisibility to the joins is a different gap)"
fi

# 8d. THE ROW IS ADDITIVE, NOT A REPLACEMENT. A heading-less entry still gets its drift row;
#     if this status displaced EXTENSION-OK the operator would lose the drift signal for
#     exactly the entries nothing else can see. Asserted as an exact set so a code that does
#     not exist yet cannot creep in unnoticed.
e20_want="EXTENSION-HOOK-DRIFT
EXTENSION-NO-HEADINGS"
e20_got="$(st 'NOHEAD\.md$' | sort -u)"
if [ "$e20_got" = "$e20_want" ]; then
  ok "  a heading-less entry yields EXACTLY the new status plus its file-grain drift row"
else
  bad "a heading-less entry yielded an unexpected status set — want=[$(tr '\n' ' ' <<<"$e20_want")] got=[$(tr '\n' ' ' <<<"$e20_got")]. A stronger status here would prescribe a remedy for an entry about which nothing has been read"
fi

# 8e. THE LEVEL. LC-E20 is WARN and deliberately NOT ADJUDICATED: the ADJUDICATED level
#     demands a recorded verdict keyed on a subject digest before apply proceeds, and this
#     row's entire content is that no mechanism looked at the entry — there is no reading for
#     a verdict to be a record of. Read from the reader's OWN `--adjudicated-codes` mode
#     rather than from a restatement here. The seeded contract is a stub with no clauses, so
#     the control asserted in Part 7 (nothing at ADJUDICATED in this tree) is what makes this
#     a real zero; re-derived here against the DISTRIBUTION's contract, which does have some.
e20_adj="$(bash "$DRIFT" --adjudicated-codes "$HERE/../../.." HEAD 2>/dev/null)"
if [ -z "$e20_adj" ]; then
  ok "  (LC-E20 level: the distribution contract is unreadable from here, so this arm stands down rather than asserting against an empty set)"
elif grep -qxF 'EXTENSION-NO-HEADINGS' <<<"$e20_adj"; then
  bad "EXTENSION-NO-HEADINGS is at level ADJUDICATED. That level creates a register duty — a verdict keyed on a subject digest, recorded before apply proceeds — and this row states only that nothing looked at the entry. There is no reading for a verdict to be a record of, and promoting it also moves the ADJUDICATED set that I58 binds against layer-contract.yaml"
else
  ok "  EXTENSION-NO-HEADINGS is NOT in the reader's own ADJUDICATED set (control: that set is non-empty, $(printf '%s\n' "$e20_adj" | grep -c .) code(s))"
fi

# =======================================================================================
# Part 6: THE ROW IS KEYABLE, AND A RECORDED READING SILENCES IT UNTIL EITHER SIDE MOVES.
#
# v0.290.0 corrected this row's remedy to say a register verdict clears it and left the
# mechanism inert: the code is not in ADJ_CODES, so no digest was published and no conforming
# record could be written. A corrected sentence in front of an inert mechanism reads as
# actionable, which is worse than the wrong sentence was.
#
# The suppression asserted here is NOT the one this arm deleted years ago. That one keyed on a
# declared `extends:`, which says nothing about whether core carries the body, and it removed
# true findings. This one keys on (entry blob + core target blob at theirs), which is a human
# having read the body, and it expires when either side moves. Arm 6c is that expiry, and
# without it 6b would be an exemption for the path rather than a record of a reading.
# =======================================================================================
REG="$CONS/_bmad-output/ai-dlc-update/layer-adjudication-register.jsonl"
mkdir -p "$(dirname "$REG")"
rerun() { bash "$DRIFT" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>/dev/null; }
tm_rows() { printf '%s\n' "$1" | awk -F'\t' '$1=="EXTENSION-TITLE-MATCHES-CORE"' | grep -c . ; }

BASE_ROWS="$(tm_rows "$OUT")"
DIG="$(detail 'MATCH\.md$' EXTENSION-TITLE-MATCHES-CORE | grep -oE 'subject_digest [0-9a-f]{40}' | awk '{print $2}' | head -1)"

# 6a. the row publishes a digest the operator can copy verbatim
if [ -n "$DIG" ]; then
  ok "the row publishes a subject_digest, so a conforming register record can be written at all"
else
  bad "the row publishes NO subject_digest — the remedy it prescribes is unwritable (the v0.290.0 defect)"
fi

if [ -z "$DIG" ] || [ "$BASE_ROWS" -lt 1 ]; then
  bad "FIXTURE BROKEN: no keyed title-match row to record against (rows=$BASE_ROWS)"
else
  # 6b. a recorded verdict silences THAT row and no other
  printf '{"clause":"LC-E19","entry":"x","subject_digest":"%s","verdict":"still-additive","recorded_utc":"2026-08-07T00:00:00Z","reason":"read the body; augments"}\n' "$DIG" > "$REG"
  AFTER="$(rerun)"; A_ROWS="$(tm_rows "$AFTER")"
  if [ "$A_ROWS" -eq $((BASE_ROWS - 1)) ]; then
    ok "a recorded still-additive verdict silences exactly that row ($BASE_ROWS -> $A_ROWS), leaving the others"
  else
    bad "recording one verdict took the count $BASE_ROWS -> $A_ROWS; expected $((BASE_ROWS - 1))"
  fi

  # 6c. THE EXPIRY, and without it 6b is an exemption rather than a record. Move the entry;
  #     the digest changes and the row must come back with the SAME register in place.
  printf '\n<!-- entry edited after the verdict was recorded -->\n' >> "$CONS/.claude/skills/ai-dlc/extensions/MATCH.md"
  MOVED="$(rerun)"; M_ROWS="$(tm_rows "$MOVED")"
  if [ "$M_ROWS" -eq "$BASE_ROWS" ]; then
    ok "editing the entry re-arms the row with the verdict still on file — the digest is spent, not an exemption for the path"
  else
    bad "after editing the entry the count is $M_ROWS, expected $BASE_ROWS — a stale verdict is silencing a changed body"
  fi

  # 6d. CONTROL: a register holding a verdict for a DIFFERENT digest silences nothing.
  printf '{"clause":"LC-E19","entry":"x","subject_digest":"%s","verdict":"still-additive","recorded_utc":"2026-08-07T00:00:00Z","reason":"unrelated"}\n' \
    "0000000000000000000000000000000000000000" > "$REG"
  CTL="$(rerun)"; C_ROWS="$(tm_rows "$CTL")"
  if [ "$C_ROWS" -eq "$BASE_ROWS" ]; then
    ok "CONTROL: a verdict for an unrelated digest silences nothing — the match is on the digest, not on the register being non-empty"
  else
    bad "CONTROL: an unrelated verdict changed the count to $C_ROWS; the lookup is not keying on the digest"
  fi
fi


# =======================================================================================
# Part 7: `--list-adjudications` COVERS THIS ROW, WHICH IS NOT AT LEVEL ADJUDICATED.
#
# THE MEASUREMENT THIS ARM EXISTS FOR. On the reference consumer, 12 keyed subjects and only
# ONE of them is an `adj_check` row; the other eleven are this clause. LC-E19 keys on a digest
# while sitting at WARN, so a listing derived from the ADJUDICATED code set would have reported
# 1 of 12 and read like a complete answer. That is why the listing is sited on `adj_digest` —
# the one function every keyed row asks for its key — and this arm is what fails if anyone
# re-sites it on ADJ_CODES.
#
# AND THIS SITE HIDES ITS KEY HARDER THAN adj_check DOES. A recorded verdict there leaves the
# candidate row printing and only drops the blocking message; here the whole row is suppressed
# by the `continue` above, so the digest goes with it. Both register states are asserted.
# =======================================================================================
echo ""

# CONTROL FIRST, and this seed gives the sharpest form of it: the seeded contract is a stub
# carrying no clauses, so NOTHING is at level ADJUDICATED and the whole tier is inactive in this
# tree. A listing derived from the adjudicated code set could not name a single subject here.
# The reader's empty answer is corroborated against the contract's own text, because an empty
# answer from a broken reader would otherwise read the same.
adj_n="$(bash "$DRIFT" --adjudicated-codes "$DIST" "$THEIRS" 2>/dev/null | grep -c .)"
lvl_adj="$(git -C "$DIST" show "$THEIRS:core/skills/ai-dlc/layer-contract.yaml" 2>/dev/null | grep -c 'level: ADJUDICATED')"
if [ "$lvl_adj" -ne 0 ]; then
  bad "CONTROL: the seeded contract now puts $lvl_adj clause(s) at ADJUDICATED. Part 7 was written against a stub contract with none, and the sharpest version of its assertion depends on that. Re-derive this arm against the new seed"
elif [ "$adj_n" -ne 0 ]; then
  bad "CONTROL: the seeded contract declares no ADJUDICATED clause and --adjudicated-codes answered with $adj_n code(s). The two disagree, so neither can be used as the control for what follows"
else
  ok "CONTROL: the seeded contract puts nothing at ADJUDICATED and --adjudicated-codes agrees — the adjudication tier is inactive in this tree, so a listing derived from it could name no subject at all"
fi

: > "$REG"
FRESH="$(rerun)"
DIG2="$(printf '%s\n' "$FRESH" | awk -F'\t' '$1=="EXTENSION-TITLE-MATCHES-CORE" && $2 ~ /MATCH\.md$/' \
        | grep -oE 'subject_digest [0-9a-f]{40}' | awk '{print $2}' | head -1)"
listing() { bash "$DRIFT" --list-adjudications "$DIST" "$BASE" "$THEIRS" "$CONS" 2>/dev/null \
            | awk -F'\t' '$1=="ADJUDICABLE"{print $4}'; }

if [ -z "$DIG2" ]; then
  bad "FIXTURE BROKEN: no keyed title-match row to read a digest from, so Part 7 would assert against an empty key"
else
  # Every match below is a here-string against a variable, never a pipe into `grep -q`: under
  # pipefail the reader leaves at its first match and the pipeline answers with the writer's
  # EPIPE, so a MATCH reports as not-found once the upstream's remaining output clears the pipe
  # buffer. I54b holds the whole tree to that shape.
  LIST_OPEN="$(listing)"
  if grep -qxF -- "$DIG2" <<<"$LIST_OPEN"; then
    ok "the listing names this WARN-level row's subject — a listing derived from the ADJUDICATED code set would miss it, and on the reference consumer that is 11 of 12 subjects"
  else
    bad "the listing does not name this row's digest, so it is derived from the adjudicated code set rather than from adj_digest. Every clause that keys on a digest without sitting at ADJUDICATED is then invisible to the one reader built to show keys"
  fi

  printf '{"clause":"LC-E19","entry":"x","subject_digest":"%s","verdict":"still-additive","recorded_utc":"2026-08-07T00:00:00Z","reason":"read the body; augments"}\n' "$DIG2" > "$REG"
  TM_AFTER="$(printf '%s\n' "$(rerun)" | awk -F'\t' '$1=="EXTENSION-TITLE-MATCHES-CORE" && $2 ~ /MATCH\.md$/' | grep -c .)"
  if [ "$TM_AFTER" -ne 0 ]; then
    bad "PRECONDITION FAILED: the recorded verdict left $TM_AFTER such row(s), so the next assertion is not measuring the state in which this site's key disappears. Read arm 6b first"
  else
    ok "PRECONDITION: the recorded verdict suppresses the whole row here, taking the published digest with it"
  fi
  LIST_CLOSED="$(listing)"
  if grep -qxF -- "$DIG2" <<<"$LIST_CLOSED"; then
    ok "the listing still names that subject with the verdict recorded — the key survives the suppression that used to delete it"
  else
    bad "recording a verdict removed this subject from the listing. The key is again reachable only while the row prints, which for this clause means only while it is unadjudicated"
  fi
fi

# =======================================================================================
# MUTANTS FOR PART 8
#
# Part 8's arms 8b and 8c are ABSENCE-shaped, and an absence-shaped arm is the one that
# REQUIRES a mutant: both-directions seeding establishes that the arm discriminates between
# two inputs, and only a mutant establishes that it discriminates AT ALL.
#
# EACH MUTANT IS A COPY OF THE WHOLE reconcile DIRECTORY. `layer-drift.sh` sources
# `lib.sh` as a SIBLING and refuses with exit 1 when it cannot; a lone mutated copy finds no
# library, emits nothing, and "no rows" would then score every absence arm as a kill.
#
# KEYED ON THE GUARD'S LOCATION AND OBSERVABLE, NEVER ON A SPELLING THE FIX INTRODUCED.
# Each `sed` rewrites the CONDITION at the emission site; a mutation anchored on the status
# token or on the remedy prose would match nothing the day either is reworded, and the
# fixture would go FIXTURE STALE on a commit that changed no behaviour.
# =======================================================================================
echo ""
echo "  --- Part 8 mutants ---"

E20_SRC_DIR="$(cd "$(dirname "$DRIFT")" && pwd)"
E20N=0
# `e20mut` SETS A GLOBAL AND PRINTS NOTHING, and that is not a style choice. `bad` writes to
# STDOUT, so a builder called inside `$( )` folds its own refusal text into the captured
# value: every failure path then returns a NON-EMPTY string, the caller reads it as a
# successfully built mutant, and `bash "<the refusal sentence>"` produces no rows — which
# the arms below score as MUTANT SURVIVED. Measured while probing this section: a subject
# already carrying the naive guard reported `MUTANT SURVIVED [me1]` where the true state is
# FIXTURE STALE, and the two readings prescribe opposite repairs.
E20_MUT=""
e20mut() { # e20mut <name> <sed-arg>... -> sets E20_MUT to the mutant's path, or to ""
  local name="$1"; shift
  local d="$ROOT/e20-$name"
  E20_MUT=""
  rm -rf "$d"; mkdir -p "$d"
  cp -R "$E20_SRC_DIR"/. "$d"/ 2>/dev/null || { bad "MUTANT HARNESS BROKEN [$name]: could not copy the reconcile directory"; return 1; }
  sed "$@" "$DRIFT" > "$d/mutant-drift.sh" || { bad "MUTANT DID NOT APPLY [$name]: sed exited non-zero, so no mutant exists and its arms would report nothing"; return 1; }
  # `cmp -s` — a mutation that matched NOTHING is byte-identical to the original and reads
  # exactly like a mutant that survived. This repo has shipped that reading twice.
  if cmp -s "$DRIFT" "$d/mutant-drift.sh"; then
    bad "FIXTURE STALE [$name]: the mutation matched nothing in layer-drift.sh, so the arm it is meant to probe is unproven. The subject was reworded — re-anchor the mutation on the same observable, never relax the assertion"
    return 1
  fi
  if ! bash -n "$d/mutant-drift.sh" 2>/dev/null; then
    bad "FIXTURE STALE [$name]: the mutant does not parse, so a kill would be a syntax error rather than a disarmed guard"
    return 1
  fi
  E20_MUT="$d/mutant-drift.sh"
  return 0
}
# Every mutant's own control: the copy must still classify NOHEAD's SIBLING — the unrelated
# CONTROL entry, which no mutation below touches — or the copy is what failed. PRESENCE-
# shaped, because a copy that died sourcing lib.sh emits nothing and that is what an
# absence-shaped control would score as healthy.
e20run() { printf '%s\n' "$(bash "$1" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>/dev/null)"; }
e20st() { printf '%s\n' "$1" | awk -F'\t' -v e="$2" '$2 ~ e {print $1}'; }
e20ctl() { # e20ctl <name> <output>
  if [ "$(printf '%s\n' "$2" | grep -c 'CONTROL\.md')" -ge 1 ]; then
    ok "  control [$1]: the copy still classifies the untouched CONTROL entry — it loaded lib.sh and ran"
  else
    bad "MUTANT HARNESS BROKEN [$1]: the copy produced no row for the untouched CONTROL entry; it is not running, and every verdict beside it is a property of the copy rather than of the mutation"
  fi
}

# NOTE — CONJUNCT 1 OF THE GUARD IS VACUOUS TODAY, AND NO MUTANT BELOW DROPS IT.
#
# The guard is `[ -z "$ext_titles" ] && ! grep -qE '^#{2,6}[[:space:]]+' "$f"`. A mutant
# removing the FIRST conjunct would SURVIVE, and its survival must not be read as a coverage
# gap: `heading_titles_of_stream` matches `^#{2,4}`, a strict SUBSET of the guard's `^#{2,6}`,
# so any file with a heading conjunct 2 can see also populates `ext_titles` — no input can
# separate them. Measured independently here over 9 seeds (no heading, h1-only, h2, h3, h4,
# h5, h6, mixed h5+h6, numbered-only): conjunct-2-ALONE and the shipped guard emit the
# identical set, while conjunct-1-ALONE differs on four of them, which is the harness control
# proving the instrument can see a difference at all.
#
# THE DECISIVE COMPARISON IS conjunct2-ALONE vs SHIPPED. Comparing conjunct1-alone against
# shipped establishes that conjunct 2 is load-bearing and says nothing about the vacuity.
#
# THE GUARD STAYS BY OPERATOR DECISION. It is recorded here rather than deleted because the
# two predicates are only equivalent while the two grammars stay in their current relation,
# and a `#{2,4}` widening would separate them silently. ME2 below is what fails if the
# relation moves.
#
# ME1 — THE GUARD IS KEYED ON THE EMPTY `ext_titles` ALONE, which is the naive form the fix
#       header measures a 10-entry false-positive set for. Killed by 8b: NUMONLY's
#       `ext_titles` is empty too, so it starts being accused of unreachability while the
#       numbered arm is reading it. This is the CONVERSE of the vacuity above — dropping
#       conjunct 2 is observable, dropping conjunct 1 is not.
#       ANCHORED ON THE `&&` CONJUNCTION rather than on the status token: the conjunction IS
#       the property under test, and it survives any rewording of the row's text.
if e20mut me1-naive-ext-titles-guard -e 's@^  if \[ -z "\$ext_titles" \] && ! grep -qE .\^#{2,6}\[\[:space:\]\]+. "\$f"; then$@  if [ -z "$ext_titles" ]; then@'; then
  ME1_OUT="$(e20run "$E20_MUT")"
  if grep -qx EXTENSION-NO-HEADINGS <<<"$(e20st "$ME1_OUT" 'NUMONLY\.md$')"; then
    ok "  mutant [me1] KILLED by 8b: keyed on the empty ext_titles alone, the guard accuses a fully-checked numbered-only entry"
  else
    bad "MUTANT SURVIVED [me1]: the naive ext_titles-only guard did NOT report NUMONLY, so 8b does not depend on the heading half of the conjunction and the false-positive set it exists to bound is untested"
  fi
  # THE SAME MUTANT MUST STILL REPORT NOHEAD. Without this conjunct a mutant that disabled
  # the whole block would fail 8b's check for the wrong reason and read as a kill.
  if grep -qx EXTENSION-NO-HEADINGS <<<"$(e20st "$ME1_OUT" 'NOHEAD\.md$')"; then
    ok "    and it still reports NOHEAD, so the kill above is the widening and not a dead block"
  else
    bad "MUTANT HARNESS BROKEN [me1]: the mutant reports NEITHER entry — the block is disabled rather than widened, and the kill above would be an outage"
  fi
  e20ctl me1 "$ME1_OUT"
  E20N=$((E20N+1))
fi

# ME2 — THE HEADING PREDICATE NARROWS TO THE JOINS' OWN `#{2,4}`. Killed by 8c: an h5-only
#       entry then reads as having no heading at all, and the row makes a claim that is
#       false of its subject. This is the arm that holds the predicate WIDER than the joins.
if e20mut me2-narrow-to-joins-grammar -e 's@! grep -qE .\^#{2,6}\[\[:space:\]\]+. "\$f"@! grep -qE '"'"'^#{2,4}[[:space:]]+'"'"' "$f"@'; then
  ME2_OUT="$(e20run "$E20_MUT")"
  if grep -qx EXTENSION-NO-HEADINGS <<<"$(e20st "$ME2_OUT" 'H5ONLY\.md$')"; then
    ok "  mutant [me2] KILLED by 8c: narrowed to #{2,4}, the guard reports an entry that HAS a heading"
  else
    bad "MUTANT SURVIVED [me2]: narrowing the predicate to the joins' own #{2,4} changed nothing about H5ONLY, so 8c is not load-bearing and the row's width is unasserted"
  fi
  if grep -qx EXTENSION-NO-HEADINGS <<<"$(e20st "$ME2_OUT" 'NOHEAD\.md$')"; then
    ok "    and it still reports NOHEAD, so the kill is the narrowing and not a dead block"
  else
    bad "MUTANT HARNESS BROKEN [me2]: the mutant reports neither entry — the block is disabled rather than narrowed"
  fi
  e20ctl me2 "$ME2_OUT"
  E20N=$((E20N+1))
fi

# A MUTANT THAT KILLED NOTHING READS EXACTLY LIKE AN ARM THAT CANNOT FIRE, and `cmp -s`
# cannot see it — it proves the edit applied, never that the run loaded the edited file.
# Assert the count.
if [ "$E20N" -eq 2 ]; then
  ok "  both Part 8 mutants were built, applied (cmp -s) and scored"
else
  bad "only $E20N of 2 Part 8 mutants were scored — a mutation that never became a mutant leaves its arm unproven, and this fixture would report PASS over it"
fi

echo ""
if [ "$fails" -eq 0 ]; then echo "layer-title-join: PASS"; exit 0; fi
echo "layer-title-join: FAIL ($fails)"; exit 1
