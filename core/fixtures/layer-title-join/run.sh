#!/usr/bin/env bash
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

echo ""
if [ "$fails" -eq 0 ]; then echo "layer-title-join: PASS"; exit 0; fi
echo "layer-title-join: FAIL ($fails)"; exit 1
