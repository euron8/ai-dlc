#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# layer-readopt-gate — assert the v0.52.0 landing machinery can actually LAND.
#
# Three properties, each of which fails RED against a real defect that shipped:
#
#   A. `readopt-override.sh --check` catches an override whose body still carries
#      core text upstream has SUPERSEDED. Un-caught, the core fix lands on disk and
#      the lead goes on obeying the old rule out of the override.
#   B. A bare re-stamp is REFUSED while the body is stale. Drift is computed
#      base_sha..theirs, so re-stamping ALONE makes the HARD status evaporate with
#      nothing migrated -- "proceed by doing nothing" wearing a stamp. This is the
#      single most important assertion in the file.
#   C. `unregistered-drift.sh` tells an in-place core rewrite apart from install.sh's
#      template substitution. Getting that wrong in EITHER direction is fatal: miss
#      the rewrite and `apply` silently deletes it; flag the substitution and the
#      check fires on 13 of 13 files on first contact and gets turned off. (It did,
#      in development -- a `$(...)` capture ate the trailing newline and every file
#      read as drift.)
#
# Usage: run.sh [readopt-override.sh] [unregistered-drift.sh]
# Exit:  0 = every assertion holds, 1 = a gate regressed.
set -uo pipefail

# HERMETIC — scrub the operator's tuning before invoking any hook.
#
# A fixture that INHERITS ambient config tests the config, not the code. The hooks honour
# thirteen AI_DLC_* tunables; a consumer that sets any of them in settings.json exports it
# into every session, `git push` inherits it, and the pre-push gate then runs this fixture
# against a hook configured differently from what the assertions assume.
#
# Observed live: a consumer pinned AI_DLC_MODEL_ROW=1M (the documented, sanctioned way to
# declare the model row). Its effective window became 300000 instead of 200000, every
# threshold shifted, and SEVEN assertions failed against a sensor that was behaving exactly
# as specified. The gate blocked every push on the repo. The distribution never caught it
# because the distribution sets none of these -- the check could not fire where it was
# authored.
#
# Unset ALL of them, by pattern, so a NEW tunable cannot reintroduce this. Per-command
# assignments (`AI_DLC_MODEL_ROW=1M "$HOOK"`) still work: those are the deliberate tests.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done


HERE="$(cd "$(dirname "$0")" && pwd)"

pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
READOPT="$(pick "${1:-}" \
  "$HERE/../../skills/ai-dlc-update/reconcile/readopt-override.sh" \
  "$HERE/../../../core/skills/ai-dlc-update/reconcile/readopt-override.sh" \
  "$HERE/../../../.claude/skills/ai-dlc-update/reconcile/readopt-override.sh")"
UNREG="$(pick "${2:-}" \
  "$HERE/../../skills/ai-dlc-update/reconcile/unregistered-drift.sh" \
  "$HERE/../../../core/skills/ai-dlc-update/reconcile/unregistered-drift.sh" \
  "$HERE/../../../.claude/skills/ai-dlc-update/reconcile/unregistered-drift.sh")"

[ -n "$READOPT" ] || { echo "FIXTURE ERROR: cannot locate readopt-override.sh" >&2; exit 2; }
[ -n "$UNREG" ]   || { echo "FIXTURE ERROR: cannot locate unregistered-drift.sh" >&2; exit 2; }

ROOT="$(bash "$HERE/seed.sh")"
DIST="$ROOT/dist"; CONS="$ROOT/consumer"
OVR="$CONS/.claude/skills/ai-dlc/overrides/SKILL__Rule-8.md"
BASE="$(git -C "$DIST" rev-parse --short HEAD~1)"
THEIRS="$(git -C "$DIST" rev-parse --short HEAD)"

fails=0
ok()   { printf '  ok    %s\n' "$1"; }
bad()  { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

echo "== A. the stale-core-text gate fires on the real shape =="

out="$(bash "$READOPT" "$DIST" "$THEIRS" "$CONS" "$OVR" --check 2>&1)"; rc=$?
if [ "$rc" -eq 1 ] && grep -q 'STALE-CORE-TEXT' <<<"$out"; then
  ok "--check RED: override body carries core text theirs no longer has"
else
  bad "--check did NOT fire on an override copying a superseded core clause (rc=$rc)"
  printf '%s\n' "$out" | sed 's/^/        /'
fi

# The gate must name the actual superseded sentence, not merely exit 1.
if grep -q 'more CRITICALs than pass N' <<<"$out"; then
  ok "--check names the superseded clause verbatim"
else
  bad "--check fired but did not identify the stale line"
fi

echo "== B. a bare re-stamp is REFUSED while the body is stale =="

before_sha="$(sed -n 's/^base_sha:[[:space:]]*//p' "$OVR" | head -1)"
out="$(bash "$READOPT" "$DIST" "$THEIRS" "$CONS" "$OVR" --stamp readopt 2>&1)"; rc=$?
after_sha="$(sed -n 's/^base_sha:[[:space:]]*//p' "$OVR" | head -1)"

if [ "$rc" -ne 0 ] && grep -q 'REFUSED' <<<"$out"; then
  ok "--stamp readopt REFUSED while superseded text remains"
else
  bad "--stamp readopt SUCCEEDED on a stale body -- the block can be cleared by doing nothing (rc=$rc)"
fi
if [ "$before_sha" = "$after_sha" ]; then
  ok "base_sha untouched by the refused stamp ($before_sha)"
else
  bad "REFUSED stamp still rewrote base_sha ($before_sha -> $after_sha)"
fi

echo "== B2. reaffirm without a note is REFUSED =="
out="$(bash "$READOPT" "$DIST" "$THEIRS" "$CONS" "$OVR" --stamp reaffirm 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && grep -q 'REQUIRES --note' <<<"$out"; then
  ok "--stamp reaffirm demands a recorded reason"
else
  bad "--stamp reaffirm accepted with no note -- an unrecorded decision (rc=$rc)"
fi

echo "== C. the gate GOES GREEN once the body is genuinely re-adopted =="

# Re-adopt: carry theirs' clause into the override, keep the consumer's delta.
cat > "$OVR" <<EOF
---
shadows: SKILL.md#Rule 8
base_sha: ${BASE}
reason: consumer-specific validation-intensity table keyed to this repo's service paths.
---

## Rule 8 -- Validation Depth

Validation intensity by path: service/ and infra/ are FULL; scripts/ and docs/ are LIGHT.

**Divergence is a HARD_BLOCK, not a reason for another pass.** If pass N+1
reports more CRITICALs IN THE SCOPE THE PRIOR PASS ALSO REVIEWED
(\`findings_critical_prior_scope\`) than pass N reported in total, the repair step
is injecting defects. CRITICALs in scope the sprint ADDED are NOT divergence.
EOF

out="$(bash "$READOPT" "$DIST" "$THEIRS" "$CONS" "$OVR" --check 2>&1)"; rc=$?
if [ "$rc" -eq 0 ]; then ok "--check green after a real re-adoption"
else bad "--check still red after the body was re-adopted (rc=$rc)"; printf '%s\n' "$out" | sed 's/^/        /'; fi

out="$(bash "$READOPT" "$DIST" "$THEIRS" "$CONS" "$OVR" --stamp readopt 2>&1)"; rc=$?
new_sha="$(sed -n 's/^base_sha:[[:space:]]*//p' "$OVR" | head -1)"
if [ "$rc" -eq 0 ] && [ "$new_sha" = "$THEIRS" ]; then
  ok "--stamp readopt re-stamped base_sha $BASE -> $THEIRS"
else
  bad "--stamp readopt did not re-stamp (rc=$rc, base_sha=$new_sha, want $THEIRS)"
fi

# And the consumer's own delta must have SURVIVED the re-adoption.
if grep -q 'validation-intensity\|Validation intensity' "$OVR"; then
  ok "the consumer's delta survived re-adoption"
else
  bad "re-adoption destroyed the consumer's delta"
fi

echo "== B3. reaffirm must not CORRUPT a multi-line reason: block =="

# A `reason:` is routinely a multi-line YAML block — six of the reference consumer's
# overrides have one, the longest running 99 lines. Appending the note to the `reason:`
# LINE splices it into the middle of a sentence. That shipped, and it corrupted a live
# override. The reason is what the NEXT pull reads to decide "does upstream supersede
# this?"; corrupting it corrupts the record the whole workflow turns on.
ML="$CONS/.claude/skills/ai-dlc/overrides/SKILL__Multiline.md"
cat > "$ML" <<EOF
---
shadows: SKILL.md#Rule 7
base_sha: ${BASE}
reason: The core paragraph claims a thing that is
  not true in this consumer, and the second line
  finishes the sentence.
---
Body.
EOF
bash "$READOPT" "$DIST" "$THEIRS" "$CONS" "$ML" --stamp reaffirm --note "still stands" >/dev/null 2>&1

if grep -q 'reason: The core paragraph claims a thing that is$' "$ML"; then
  ok "the reason's first line is INTACT (note not spliced mid-sentence)"
else
  bad "reaffirm mangled the multi-line reason — spliced the note into line 1"
  grep -n '^reason:' "$ML" | sed 's/^/        /'
fi
if grep -q 'finishes the sentence.$' "$ML"; then
  ok "the reason's continuation lines survived"
else
  bad "reaffirm destroyed the reason's continuation lines"
fi
if [ "$(grep -c 'RE-AFFIRMED against' "$ML")" = "1" ] && \
   tail -n +2 "$ML" | awk '/^---$/{exit} {last=$0} END{exit !(last ~ /RE-AFFIRMED/)}'; then
  ok "the note is appended at the END of the reason block"
else
  bad "the note is not at the end of the reason block"
fi
rm -f "$ML"

echo "== B4. the dossier must RENDER a block-scalar reason, not its indicator =="

# The twin of B3, in the other direction. B3 proved the WRITER tracks a block scalar; the
# READER did not. `fm()` is `… | head -1`, so on `reason: |` it captured the indicator and
# nothing else and the dossier's rationale panel printed a bare `|`. Eight of the reference
# consumer's sixteen overrides declare `reason:` as a block; every one rendered empty.
#
# SKILL.md step 7's retire / readopt / reaffirm decision turns on that field, so the operator
# adjudicated a re-adoption against a blank rationale — and a blank rationale reads as an
# override with no stated purpose, which is an argument for retiring it.
BL="$CONS/.claude/skills/ai-dlc/overrides/SKILL__BlockReason.md"
cat > "$BL" <<EOF
---
shadows: SKILL.md#Rule 7
base_sha: ${BASE}
reason: |
  UNIQUE-BLOCK-SENTINEL the first line of the block.
  And a continuation line that must also survive.
---
Body.
EOF
out="$(bash "$READOPT" "$DIST" "$THEIRS" "$CONS" "$BL" 2>&1)"
if grep -q 'UNIQUE-BLOCK-SENTINEL' <<<"$out"; then
  ok "the dossier renders a block-scalar reason's text"
else
  bad "the dossier did NOT render the block-scalar reason — step 7's readopt decision turns on a field the operator cannot see"
  printf '%s\n' "$out" | sed -n '/WHY THIS OVERRIDE EXISTS/,+3p' | sed 's/^/        /'
fi
if grep -q 'continuation line that must also survive' <<<"$out"; then
  ok "the block's continuation lines render too (not just line 1)"
else
  bad "the dossier rendered only the block's first line — a 99-line reason still reads as a one-liner"
fi
# Non-vacuity in the other direction: the INLINE form must not regress.
cat > "$BL" <<EOF
---
shadows: SKILL.md#Rule 7
base_sha: ${BASE}
reason: UNIQUE-INLINE-SENTINEL a single-line reason.
---
Body.
EOF
out="$(bash "$READOPT" "$DIST" "$THEIRS" "$CONS" "$BL" 2>&1)"
if grep -q 'UNIQUE-INLINE-SENTINEL' <<<"$out"; then
  ok "an INLINE reason still renders (the block reader did not break the common path)"
else
  bad "the inline reason stopped rendering — fixing the block form broke the single-line form"
  printf '%s\n' "$out" | head -12 | sed 's/^/        /'
fi
rm -f "$BL"

echo "== B4b. a MULTI-LINE PLAIN reason renders whole, and it fails WORSE than the block form =="

# THE SAME DEFECT ONE YAML SHAPE OVER, AND IN THE MORE DANGEROUS DIRECTION. B4 above cured
# `reason: |`; `reason: <text>` continued over the lines beneath it took `fm_block()`'s
# `print v; exit` arm and rendered its FIRST LINE ONLY. A bare `|` rendered EMPTY, which the
# operator reads as a missing field and goes to the file for. One surviving line that ends in a
# complete sentence reads as the WHOLE reason, so step 7's retire / readopt / reaffirm decision
# is taken against a fragment that looks whole and nothing in the output says otherwise.
#
# THREE SENTINELS, NOT TWO. A two-line seed cannot tell "reads the continuation" from "reads one
# more line"; the third is what makes the arm about the continuation STATE rather than about a
# lookahead. Each is unique in the file, so a hit is that line and not a substring of another.
PM="$CONS/.claude/skills/ai-dlc/overrides/SKILL__PlainMulti.md"
cat > "$PM" <<EOF
---
shadows: SKILL.md#Rule 7
base_sha: ${BASE}
reason: PLAIN-FIRST-SENTINEL the first line of a plain scalar,
  PLAIN-CONT-SENTINEL and the continuation that finishes it,
  PLAIN-TAIL-SENTINEL and a third line beneath that one.
---
Body.
EOF
pm_out="$(bash "$READOPT" "$DIST" "$THEIRS" "$CONS" "$PM" 2>&1)"
if grep -q 'PLAIN-FIRST-SENTINEL' <<<"$pm_out"; then
  ok "a PLAIN multi-line reason renders its first line"
else
  bad "the dossier rendered nothing for a plain scalar reason at all — the common path is broken, and every verdict below is about an empty panel"
fi
if grep -q 'PLAIN-CONT-SENTINEL' <<<"$pm_out" && grep -q 'PLAIN-TAIL-SENTINEL' <<<"$pm_out"; then
  ok "  ...and BOTH continuation lines beneath it — a reason that runs past line 1 is not silently truncated to a fragment that reads whole"
else
  bad "the dossier rendered only line 1 of a PLAIN multi-line reason (cont=$(grep -c 'PLAIN-CONT-SENTINEL' <<<"$pm_out") tail=$(grep -c 'PLAIN-TAIL-SENTINEL' <<<"$pm_out"), want 1 and 1) — step 7's decision is taken against a fragment ending in a complete sentence, which is worse than the blank field B4 fixed"
fi

# THE CONTINUATION MUST STOP AT THE NEXT KEY, and that is the half a widened reader breaks.
# `inb` carries the block-END rule — an unindented `key:` closes it, which is the `--note`
# WRITER's own rule — and the plain arm reuses it precisely so reader and writer cannot disagree
# about where a reason stops. A reader that simply consumed to the fence would pass every
# assertion above and swallow `base_sha` into the rationale panel.
PK="$CONS/.claude/skills/ai-dlc/overrides/SKILL__PlainKeyStop.md"
cat > "$PK" <<EOF
---
shadows: SKILL.md#Rule 7
reason: PLAIN-STOP-SENTINEL line one of the reason,
  PLAIN-STOP-CONT-SENTINEL line two of the reason.
base_sha: ${BASE}
---
Body.
EOF
pk_panel="$(bash "$READOPT" "$DIST" "$THEIRS" "$CONS" "$PK" 2>&1 \
            | awk '/WHY THIS OVERRIDE EXISTS/{p=1;next} /^--- WHAT UPSTREAM/{p=0} p')"
if grep -q 'PLAIN-STOP-CONT-SENTINEL' <<<"$pk_panel"; then
  ok "CONTROL: with a key BELOW it the reason's continuation line still renders (so the absence below is a real zero)"
else
  bad "CONTROL: the continuation did not render when a key follows the reason, so the stop assertion below is a statement about an empty panel"
fi
if grep -q 'base_sha' <<<"$pk_panel"; then
  bad "the rationale panel swallowed the `base_sha:` key that follows the reason — the plain arm is consuming to the fence instead of reusing the block-END rule, and the operator reads frontmatter as the override's stated purpose"
else
  ok "  ...and the reason STOPS at the next unindented key: base_sha does not leak into the panel"
fi
rm -f "$PK"

echo "== B4c. the reason panel's CLIP ANNOUNCES ITSELF =="

# IT WAS `head -20`: a reason longer than twenty folded lines lost its tail with nothing in the
# output saying so, and the operator adjudicated against a fragment indistinguishable from a
# complete field. The same dangerous direction as B4b — a plausible value is worse than an
# obviously missing one.
#
# RAISING THE LIMIT IS NOT THE FIX AND THE ARM IS BUILT SO THAT IT COULD NOT BE. The notice is a
# function of the INPUT (the awk END rule fires whenever the authored line count exceeds what was
# printed), so what is asserted is the RELATION — head shown, tail withheld, count stated — and
# no value of the bound satisfies it while clipping silently.
CLIP="$CONS/.claude/skills/ai-dlc/overrides/SKILL__Clip.md"
{
  echo '---'
  echo 'shadows: SKILL.md#Rule 7'
  echo "base_sha: ${BASE}"
  echo 'reason: CLIP-HEAD-SENTINEL line 1 of a long plain scalar.'
  i=2
  while [ "$i" -le 30 ]; do echo "  continuation line ${i} of the long plain scalar."; i=$((i+1)); done
  echo '  CLIP-TAIL-SENTINEL the very last line, which must not be shown.'
  echo '---'
  echo 'Body.'
} > "$CLIP"
clip_out="$(bash "$READOPT" "$DIST" "$THEIRS" "$CONS" "$CLIP" 2>&1)"
if grep -q 'CLIP-HEAD-SENTINEL' <<<"$clip_out" && ! grep -q 'CLIP-TAIL-SENTINEL' <<<"$clip_out"; then
  ok "a long reason is still clipped (head shown, tail withheld) — the panel is bounded, which is what makes the notice necessary"
else
  bad "the clip itself has moved (head=$(grep -c 'CLIP-HEAD-SENTINEL' <<<"$clip_out") tail=$(grep -c 'CLIP-TAIL-SENTINEL' <<<"$clip_out"), want 1 and 0) — if nothing is withheld the notice arm below asserts nothing, and if nothing is shown the panel is empty"
fi
clip_n="$(grep -oE '\[\.\.\. [0-9]+ further line' <<<"$clip_out" | grep -oE '[0-9]+' | head -1)"
if [ -n "$clip_n" ] && [ "$clip_n" -gt 0 ]; then
  ok "  ...and the clip ANNOUNCES itself with a COUNT ($clip_n further line(s)) — the operator is told the field is partial instead of reading a fragment as whole"
else
  bad "the reason panel clipped with NO notice and no count — this is the shipped defect: a truncated rationale is indistinguishable from a complete one, and the retire/readopt/reaffirm decision is taken on it"
fi
# THE NEAR-MISS, AND IT CARRIES THE PROPERTY THE FEARED REGRESSION KEYS ON. A notice printed
# unconditionally would satisfy both assertions above. This reason is long enough to be a real
# multi-line scalar and short enough to fit, so a notice here is a false one.
SHORT="$CONS/.claude/skills/ai-dlc/overrides/SKILL__ClipCtl.md"
cat > "$SHORT" <<EOF
---
shadows: SKILL.md#Rule 7
base_sha: ${BASE}
reason: SHORT-HEAD-SENTINEL line one of a short plain scalar,
  and line two, which fits inside the bound with room to spare.
---
Body.
EOF
short_out="$(bash "$READOPT" "$DIST" "$THEIRS" "$CONS" "$SHORT" 2>&1)"
if grep -q 'SHORT-HEAD-SENTINEL' <<<"$short_out"; then
  ok "CONTROL: the short reason renders (so the notice's absence below is a real zero, not a dead run)"
else
  bad "CONTROL: the short reason did not render at all, so the absence below says nothing"
fi
if grep -q 'NOT SHOWN' <<<"$short_out"; then
  bad "a reason that FITS carried the clip notice anyway — the notice fires unconditionally, so it tells the operator nothing about whether this field is partial"
else
  ok "  ...and carries NO clip notice: the announcement is a function of the input, not a line printed on every dossier"
fi
rm -f "$SHORT"

# --- MUTANTS: the plain-continuation arm and the clip notice ------------------------------
# B4b's stop-assertion and B4c's near-miss are both ABSENCE-shaped, and an absence passes
# against a copy that emits nothing. Both mutants are copies of the WHOLE reconcile directory
# (a lone script dies sourcing its siblings and prints nothing, which would score as a kill for
# every arm here), `cmp -s`-guarded, keyed on the LINE THAT DECIDES rather than on any wording.
# A FRESH `mktemp -d` RATHER THAN A REUSED-AND-CLEARED NAME. The sibling batteries in this file
# open with `rm -rf "$VAR"` on a path they just assigned; a fresh directory reaches the same state
# without a recursive delete on a computed path, and it cannot inherit a previous battery's
# leftovers — which is the failure that makes a mutant read a file nobody in this block wrote.
PMUT="$(mktemp -d "${TMPDIR:-/tmp}/lrg-plainmut.XXXXXX")" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
cp "$(dirname "$READOPT")"/*.sh "$PMUT/" 2>/dev/null || true
cp "$(dirname "$READOPT")"/*.md "$PMUT/" 2>/dev/null || true

cp "$READOPT" "$PMUT/readopt-override.sh"
pctl="$(bash "$PMUT/readopt-override.sh" "$DIST" "$THEIRS" "$CONS" "$PM" 2>&1)"
if grep -q 'PLAIN-CONT-SENTINEL' <<<"$pctl" && grep -q 'PLAIN-FIRST-SENTINEL' <<<"$pctl"; then
  ok "  mutation control: an unmutated copy in a fresh directory still renders both lines of the plain reason"
else
  bad "  mutation control: the unmutated copy rendered first=$(grep -c 'PLAIN-FIRST-SENTINEL' <<<"$pctl") cont=$(grep -c 'PLAIN-CONT-SENTINEL' <<<"$pctl") — a copy that cannot run scores every kill below unearned"
fi

# MUTANT 1 — the plain arm back to `print v; exit`, which is the shipped-before behaviour
# exactly. The multi-line entry must lose its continuation and the SINGLE-line form must not
# move: one reads the same either way, so a mutant that took both would be testing whether the
# reader runs at all rather than whether it continues.
sed 's@^      print v; inb = 1; next$@      print v; exit@' "$READOPT" > "$PMUT/readopt-override.sh"
if cmp -s "$READOPT" "$PMUT/readopt-override.sh"; then
  bad "  mutation plain-continue: the mutation matched nothing (cmp -s guard) — the continuation arm has been respelled and B4b proves nothing"
else
  m_multi="$(bash "$PMUT/readopt-override.sh" "$DIST" "$THEIRS" "$CONS" "$PM" 2>&1)"
  cat > "$CONS/.claude/skills/ai-dlc/overrides/SKILL__PlainOne.md" <<EOF
---
shadows: SKILL.md#Rule 7
base_sha: ${BASE}
reason: ONELINE-SENTINEL a single-line plain reason.
---
Body.
EOF
  m_one="$(bash "$PMUT/readopt-override.sh" "$DIST" "$THEIRS" "$CONS" "$CONS/.claude/skills/ai-dlc/overrides/SKILL__PlainOne.md" 2>&1)"
  if grep -q 'PLAIN-FIRST-SENTINEL' <<<"$m_multi" && ! grep -q 'PLAIN-CONT-SENTINEL' <<<"$m_multi" \
     && grep -q 'ONELINE-SENTINEL' <<<"$m_one"; then
    ok "  mutation plain-continue: with the arm back to \`print v; exit\` the continuation VANISHES while line 1 and the single-line form both still render — B4b is reading the continuation and not the run"
  else
    bad "  mutation plain-continue: multi first=$(grep -c 'PLAIN-FIRST-SENTINEL' <<<"$m_multi") (want 1) cont=$(grep -c 'PLAIN-CONT-SENTINEL' <<<"$m_multi") (want 0) single=$(grep -c 'ONELINE-SENTINEL' <<<"$m_one") (want 1) — the arm is vacuous, or the mutant broke the reader and silence scored as a kill"
  fi
  rm -f "$CONS/.claude/skills/ai-dlc/overrides/SKILL__PlainOne.md"
fi

# MUTANT 2 — the announcement deleted, the BOUND left in place: `head -20`'s exact behaviour.
# This is the one that could not be caught by any arm reading the panel's CONTENT, because the
# shown lines are byte-identical either way — the notice is the whole observable. The short
# control is the positive conjunct, so a mutant that killed the panel cannot score this.
sed 's@ | awk .NR<=20{print} END{if (NR>20) printf "  \[\.\.\. %d further line(s) NOT SHOWN\. Read the override file named above for the whole reason\.\]\\n", NR-20}.@ | head -20@' "$READOPT" > "$PMUT/readopt-override.sh"
if cmp -s "$READOPT" "$PMUT/readopt-override.sh"; then
  bad "  mutation clip-notice: the mutation matched nothing (cmp -s guard) — the announcing awk has been respelled and B4c proves nothing"
else
  mc_long="$(bash "$PMUT/readopt-override.sh" "$DIST" "$THEIRS" "$CONS" "$CLIP" 2>&1)"
  if ! grep -q 'NOT SHOWN' <<<"$mc_long" && grep -q 'CLIP-HEAD-SENTINEL' <<<"$mc_long" \
     && ! grep -q 'CLIP-TAIL-SENTINEL' <<<"$mc_long"; then
    ok "  mutation clip-notice: with the announcement removed the SAME twenty lines are shown and the tail is SILENTLY dropped — the notice is the only observable, which is why no content arm could have caught this"
  else
    bad "  mutation clip-notice: notice=$(grep -c 'NOT SHOWN' <<<"$mc_long") (want 0) head=$(grep -c 'CLIP-HEAD-SENTINEL' <<<"$mc_long") (want 1) tail=$(grep -c 'CLIP-TAIL-SENTINEL' <<<"$mc_long") (want 0) — either the notice is not load-bearing, or the mutant changed the bound too and the two properties are entangled"
  fi
fi
rm -f "$PM" "$CLIP"

echo "== B5. the dossier's upstream-change panel must SAY when nothing drifted =="

# The panel titled "WHAT UPSTREAM CHANGED IN THE SHADOWED SECTION" echoed its heading for
# EVERY anchor before computing that anchor's diff, so an entry whose sections are
# byte-identical rendered as a list of bare headings underneath a title asserting they
# CHANGED. Measured on the reference consumer, `overrides/steps__retro__domain-sections.md`,
# four anchors: four headings, ZERO diff hunks. The reader's inference is "four sections
# drifted", which points at --merge / --stamp readopt -- surgery on an entry needing none.
# It reached an operator's report before it was caught.
#
# SELF-MASKING, which is why it needs an arm rather than a doc note: the same rendering is
# CORRECT whenever at least one anchor did change, so nothing downstream disagrees and the
# panel is internally consistent in both cases.
#
# THE ARM IS PRESENCE-SHAPED IN BOTH DIRECTIONS, and that is deliberate. Asserting only
# "no bare heading appears" would pass against a subject that emits nothing at all --
# `fixture-mutants.md`'s rule that an absence-shaped arm scores silence as a kill. So the
# quiet direction DEMANDS the explicit sentence, and the loud direction DEMANDS a real
# diff hunk. Rule 7 is byte-identical BASE..THEIRS in this seed and Rule 8 is not, so the
# two directions are driven by two different anchors of the same seeded core file — a
# single anchor could not produce both.
PANEL="$CONS/.claude/skills/ai-dlc/overrides/SKILL__PanelQuiet.md"
panel_of() { # $1 override path -> just the upstream-change panel
  bash "$READOPT" "$DIST" "$THEIRS" "$CONS" "$1" 2>&1 \
    | awk '/WHAT UPSTREAM CHANGED/{p=1} /SUPERSEDED CORE TEXT/{p=0} p'
}

# -- QUIET DIRECTION: an anchor that did NOT drift.
cat > "$PANEL" <<EOF
---
shadows: SKILL.md#Rule 7
base_sha: ${BASE}
reason: shadows a section upstream did not touch in this range.
---
Body that restates nothing.
EOF
qp="$(panel_of "$PANEL")"
if grep -qE '\(none -- all [0-9]+ compared anchor' <<<"$qp"; then
  ok "an unchanged anchor renders an explicit 'nothing drifted' sentence"
else
  bad "the panel did NOT state that nothing drifted — a reader cannot tell 'unchanged' from 'not compared'"
  printf '%s\n' "$qp" | sed 's/^/        /'
fi
if grep -qE '^[[:space:]]*## ' <<<"$qp"; then
  bad "an unchanged anchor still rendered a bare '## <id>' heading under a title asserting it CHANGED"
  printf '%s\n' "$qp" | sed 's/^/        /'
else
  ok "no bare anchor heading is printed for a section that did not drift"
fi

# -- LOUD DIRECTION, the non-vacuity control. Same panel, an anchor that DID drift.
cat > "$PANEL" <<EOF
---
shadows: SKILL.md#Rule 8
base_sha: ${BASE}
reason: shadows a section upstream DID rewrite in this range.
---
Body that restates nothing.
EOF
lp="$(panel_of "$PANEL")"
if grep -qE '^[[:space:]]*@@' <<<"$lp"; then
  ok "CONTROL: a genuinely drifted anchor still renders its diff hunk"
else
  bad "CONTROL: the drifted anchor rendered NO diff — the quiet arm above is passing because the panel went silent for everything"
  printf '%s\n' "$lp" | sed 's/^/        /'
fi
if grep -qE '^[[:space:]]*## Rule 8' <<<"$lp"; then
  ok "CONTROL: the drifted anchor's heading IS printed, above its diff"
else
  bad "CONTROL: a drifted anchor lost its heading — the fix suppressed headings unconditionally"
fi
rm -f "$PANEL"

# --- MUTANT: restore the defect (heading emitted before the diff is known) --------------
# The second quiet assertion above is ABSENCE-shaped -- "no bare `## ` heading appears" --
# and `fixture-mutants.md` is explicit that such an arm scores SILENCE as a kill. A copy of
# this script that cannot source lib.sh prints nothing and would satisfy it. So the arm gets
# a mutant that makes the panel LOUD in exactly the old way, plus an unmutated control in the
# same directory so a broken copy is reported as broken rather than as a pass.
#
# The mutation deletes the emptiness guard, which is the whole of the fix on the quiet path:
# every anchor's heading is then emitted whether or not its section moved.
MUTP="$ROOT/mutpanel"; rm -rf "$MUTP"; mkdir -p "$MUTP"
cp "$(dirname "$READOPT")"/*.sh "$MUTP/" 2>/dev/null || true
cat > "$PANEL" <<EOF
---
shadows: SKILL.md#Rule 7
base_sha: ${BASE}
reason: shadows a section upstream did not touch in this range.
---
Body that restates nothing.
EOF

cp "$READOPT" "$MUTP/readopt-override.sh"
cpanel="$(bash "$MUTP/readopt-override.sh" "$DIST" "$THEIRS" "$CONS" "$PANEL" 2>&1 \
          | awk '/WHAT UPSTREAM CHANGED/{p=1} /SUPERSEDED CORE TEXT/{p=0} p')"
if grep -qE '\(none -- all [0-9]+ compared anchor' <<<"$cpanel"; then
  ok "  mutation control: an unmutated copy still prints the 'nothing drifted' sentence"
else
  bad "  mutation control: unmutated copy printed no sentence — a copy that cannot run scores as a kill"
fi

sed 's@^  \[ -n "\$_d" \] || continue$@@' "$READOPT" > "$MUTP/readopt-override.sh"
if cmp -s "$READOPT" "$MUTP/readopt-override.sh"; then
  bad "  mutation panel-guard: the mutation matched nothing, so the bare-heading assertion is unproven"
else
  mpanel="$(bash "$MUTP/readopt-override.sh" "$DIST" "$THEIRS" "$CONS" "$PANEL" 2>&1 \
            | awk '/WHAT UPSTREAM CHANGED/{p=1} /SUPERSEDED CORE TEXT/{p=0} p')"
  if grep -qE '^[[:space:]]*## Rule 7' <<<"$mpanel"; then
    ok "  mutation panel-guard: without it an UNCHANGED anchor prints a bare heading again (the arm can fire)"
  else
    bad "  mutation panel-guard: the mutant did NOT reproduce the bare heading, so the arm above proves nothing"
    printf '%s\n' "$mpanel" | sed 's/^/        /'
  fi
fi
rm -rf "$MUTP"
rm -f "$PANEL"

echo "== C0. --merge re-adopts MECHANICALLY (no hand edit) =="

# The operator must never be told to "merge the new core text in, preserving your
# delta" by hand: that is asking them to run a three-way merge in their head, on prose,
# and a hand-merge is where half an upstream clause gets silently dropped. Re-seed the
# stale override and let --merge do it.
cat > "$OVR" <<EOF
---
shadows: SKILL.md#Rule 8
base_sha: ${BASE}
reason: consumer-specific validation-intensity table keyed to this repo's service paths.
---

## Rule 8 -- Validation Depth

Validation intensity by path: service/ and infra/ are FULL; scripts/ and docs/ are LIGHT.

**Divergence is a HARD_BLOCK, not a reason for another pass.** If pass N+1
reports more CRITICALs than pass N, the repair step is injecting defects faster
than review removes them; another pass only finds the next wave. STOP.
EOF

out="$(bash "$READOPT" "$DIST" "$THEIRS" "$CONS" "$OVR" --merge 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && grep -q 'MERGED' <<<"$out"; then
  ok "--merge applied upstream's change with no hand edit"
else
  bad "--merge failed (rc=$rc): $out"
fi
if grep -q 'IN THE SCOPE THE PRIOR PASS ALSO REVIEWED' "$OVR"; then
  ok "upstream's new clause is IN the override body"
else
  bad "--merge did not bring upstream's clause into the body"
fi
if grep -q 'Validation intensity by path' "$OVR"; then
  ok "the consumer's delta survived the merge"
else
  bad "--merge destroyed the consumer's delta -- the whole reason the override exists"
fi
if grep -q 'more CRITICALs than pass N' "$OVR"; then
  bad "the superseded clause is STILL in the body after --merge"
else
  ok "the superseded clause is gone"
fi
# And the merged body must now pass the gate it previously failed.
bash "$READOPT" "$DIST" "$THEIRS" "$CONS" "$OVR" --check >/dev/null 2>&1 \
  && ok "--check green after --merge (stamp is now permitted)" \
  || bad "--check still red after --merge -- the merge did not actually clear the block"

echo "== C0b. a MULTI-ANCHOR override merges per anchor, not by hand =="

# This used to be `REFUSED ... merge them one at a time by hand`, which routed the
# operator into the exact procedure C0 exists to abolish. It is also disproportionate:
# Rule 7 and Rule 9 are BYTE-IDENTICAL base..theirs, so three of the four anchors need
# no work at all -- only Rule 8 drifted. The differential is that the two unchanged
# sections must come out byte-for-byte, INCLUDING their consumer deltas: a merge that
# re-flows a section core never touched is indistinguishable, in a diff, from one that
# quietly rewrote it.
cat > "$OVR" <<EOF
---
shadows: SKILL.md#Rule 7, SKILL.md#Rule 8, SKILL.md#Rule 9
base_sha: ${BASE}
reason: consumer rewrites of three rule sections; only one of them drifted upstream.
---

Preamble prose no anchor covers. Must survive verbatim.

## Rule 7 -- Something Else

CONSUMER-DELTA-SEVEN kept exactly as written.

## Rule 8 -- Validation Depth

Validation intensity by path: service/ and infra/ are FULL; scripts/ and docs/ are LIGHT.

**Divergence is a HARD_BLOCK, not a reason for another pass.** If pass N+1
reports more CRITICALs than pass N, the repair step is injecting defects faster
than review removes them; another pass only finds the next wave. STOP.

## Rule 9 -- Trailing

CONSUMER-DELTA-NINE kept exactly as written.
EOF

out="$(bash "$READOPT" "$DIST" "$THEIRS" "$CONS" "$OVR" --merge 2>&1)"; rc=$?
if [ "$rc" -eq 0 ]; then
  ok "--merge accepted a multi-anchor override (was: REFUSED, exit 2)"
else
  bad "--merge still refuses a multi-anchor override (rc=$rc): $out"
fi
if grep -q '1 merged, 2 unchanged, 0 conflicted' <<<"$out"; then
  ok "only the anchor that drifted was merged (1 merged, 2 unchanged)"
else
  bad "expected '1 merged, 2 unchanged, 0 conflicted', got: $out"
fi
if grep -Fqx 'CONSUMER-DELTA-SEVEN kept exactly as written.' "$OVR" \
   && grep -Fqx 'CONSUMER-DELTA-NINE kept exactly as written.' "$OVR"; then
  ok "the two unchanged sections came out byte-for-byte"
else
  bad "an unchanged section was rewritten -- --merge must not touch what core did not change"
fi
if grep -Fqx 'Preamble prose no anchor covers. Must survive verbatim.' "$OVR"; then
  ok "prose outside every anchor span survived verbatim"
else
  bad "--merge dropped body prose no anchor covers"
fi
if grep -q 'IN THE SCOPE THE PRIOR PASS ALSO REVIEWED' "$OVR" \
   && grep -q 'Validation intensity by path' "$OVR" \
   && ! grep -q 'more CRITICALs than pass N' "$OVR"; then
  ok "the drifted anchor took upstream's clause, kept the delta, dropped the superseded line"
else
  bad "the drifted anchor did not merge correctly"
fi
bash "$READOPT" "$DIST" "$THEIRS" "$CONS" "$OVR" --check >/dev/null 2>&1 \
  && ok "--check green after the multi-anchor merge" \
  || bad "--check still red after the multi-anchor merge"

echo "== C0c. --merge invents no whitespace the file did not have =="

# Found on the reference consumer, NOT here: its override has no blank line after the
# `---` fence, and --merge emitted one because the writer appended a separator
# unconditionally. A whitespace-only edit is still an edit to a file whose promise is that
# untouched sections come out byte-for-byte, and it lands in every reviewer's diff. The
# fixture's other overrides all happen to have that blank, so none of them could see it.
cat > "$OVR" <<EOF
---
shadows: SKILL.md#Rule 7, SKILL.md#Rule 8
base_sha: ${BASE}
reason: no blank line after the fence, and none may be added.
---
FLUSH-PREAMBLE immediately after the fence.

## Rule 7 -- Something Else

CONSUMER-DELTA-SEVEN kept exactly as written.

## Rule 8 -- Validation Depth

**Divergence is a HARD_BLOCK, not a reason for another pass.** If pass N+1
reports more CRITICALs than pass N, the repair step is injecting defects faster
than review removes them; another pass only finds the next wave. STOP.
EOF
before_line10="$(sed -n '6p' "$OVR")"
bash "$READOPT" "$DIST" "$THEIRS" "$CONS" "$OVR" --merge >/dev/null 2>&1
if [ "$(sed -n '5p' "$OVR")" = '---' ] && [ "$(sed -n '6p' "$OVR")" = "$before_line10" ]; then
  ok "no blank line invented after the frontmatter fence"
else
  bad "--merge inserted whitespace after the fence: line 6 was '$before_line10', now '$(sed -n '6p' "$OVR")'"
fi
if [ -n "$(tail -c 1 "$OVR")" ] || [ "$(tail -n 1 "$OVR")" != "" ]; then
  ok "no trailing blank line appended at EOF"
else
  bad "--merge appended a trailing blank line at EOF"
fi

echo "== C1. a stamp cannot outrun an unresolved CONFLICT =="

printf '\n<<<<<<< override (yours)\nfoo\n=======\nbar\n>>>>>>> core\n' >> "$OVR"
out="$(bash "$READOPT" "$DIST" "$THEIRS" "$CONS" "$OVR" --stamp readopt 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && grep -q 'conflict markers' <<<"$out"; then
  ok "--stamp readopt REFUSED while conflict markers remain"
else
  bad "--stamp readopt shipped <<<<<<< into the rulebook the lead reads (rc=$rc)"
fi

echo "== C2. an UNRESOLVABLE anchor fails CLOSED (the vacuous-check hole) =="

# If `shadows:` names an anchor that resolves to no heading, the stale-text test
# compares two EMPTY sections, finds nothing, and reports the body clean. That is a
# check that cannot fail -- gating the very re-stamp it exists to withhold. It must
# refuse, not pass. (Found live: the anchor "Empirical gate validation (the
# `Enforcement:` paragraph)" resolves under layer-drift's matcher but not under a
# naive one, so the gate blocked and its remedy silently cleared the block.)
GHOST="$CONS/.claude/skills/ai-dlc/overrides/SKILL__Ghost.md"
cat > "$GHOST" <<EOF
---
shadows: SKILL.md#Rule 404 -- Does Not Exist
base_sha: ${BASE}
reason: anchor names no heading in core.
---
Body that copies nothing and can be proven safe by nobody.
EOF

out="$(bash "$READOPT" "$DIST" "$THEIRS" "$CONS" "$GHOST" --check 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && grep -q 'UNDECIDABLE' <<<"$out"; then
  ok "--check on an unresolvable anchor: UNDECIDABLE, not 'clean'"
else
  bad "--check reported an unresolvable anchor as clean (rc=$rc) -- a check that cannot fail"
fi

out="$(bash "$READOPT" "$DIST" "$THEIRS" "$CONS" "$GHOST" --stamp readopt 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && grep -q 'REFUSED' <<<"$out"; then
  ok "--stamp readopt REFUSED on an unresolvable anchor"
else
  bad "--stamp readopt cleared a HARD block via a vacuous test (rc=$rc)"
fi

# reaffirm --note is the sanctioned way past it: a human puts their name on it.
out="$(bash "$READOPT" "$DIST" "$THEIRS" "$CONS" "$GHOST" --stamp reaffirm --note "anchor is legacy; override still stands" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ]; then ok "--stamp reaffirm --note is the recorded way past an undecidable anchor"
else bad "reaffirm --note could not clear an undecidable anchor (rc=$rc) -- no path out means the gate gets routed around"; fi

rm -f "$GHOST"

echo "== D. unregistered drift vs sanctioned template substitution =="

tsv="$(bash "$UNREG" "$DIST" "$BASE" "$CONS" 2>&1)"

st() { printf '%s\n' "$tsv" | awk -F'\t' -v f="$1" '$2==f {print $1}'; }

if [ "$(st team-roles/tea.md)" = "HARD-UNREGISTERED-CORE-DRIFT" ]; then
  ok "in-place core rewrite (tea.md) -> HARD-UNREGISTERED-CORE-DRIFT"
else
  bad "in-place core rewrite NOT flagged (got '$(st team-roles/tea.md)') -- apply would silently delete it"
fi

if [ "$(st team-roles/dev.md)" = "CORE-TEMPLATE-SUBSTITUTED" ]; then
  ok "install.sh token substitution (dev.md) -> CORE-TEMPLATE-SUBSTITUTED, not drift"
else
  bad "template substitution misread as '$(st team-roles/dev.md)' -- this is the false positive that gets the check turned off"
fi

if [ "$(st skills/ai-dlc/SKILL.md)" = "CORE-OK" ]; then
  ok "untouched core file -> CORE-OK"
else
  bad "untouched core file reported '$(st skills/ai-dlc/SKILL.md)' -- trailing-newline regression is back"
fi

echo "== E. register-drift pulls an in-place edit INTO the layer system =="

# Detecting unregistered drift is half the job. Telling the operator to "refile the
# delta as an override with a base_sha" and leaving them to hand-author the YAML, pick
# the anchor, and copy the right section out is the other half, undone -- and a
# hand-picked anchor that resolves to no heading is how drift detection dies silently.
REG="$(pick "$HERE/../../skills/ai-dlc-update/reconcile/register-drift.sh" \
            "$HERE/../../../core/skills/ai-dlc-update/reconcile/register-drift.sh" \
            "$HERE/../../../.claude/skills/ai-dlc-update/reconcile/register-drift.sh")"
if [ -z "$REG" ]; then
  bad "cannot locate register-drift.sh"
else
  out="$(bash "$REG" "$DIST" "$BASE" "$CONS" team-roles/tea.md --apply 2>&1)"; rc=$?
  NEW="$CONS/.claude/skills/ai-dlc/overrides/team-roles__tea__consumer-drift.md"

  if [ "$rc" -eq 0 ] && [ -f "$NEW" ]; then ok "authored the overrides/ entry"
  else bad "register-drift did not author an override (rc=$rc)"; fi

  # The anchor MUST resolve to a real heading in core, or drift detection is dead
  # for this entry from the day it is written.
  anchor="$(sed -n 's/^shadows:[[:space:]]*//p' "$NEW" 2>/dev/null | sed 's/.*#//; s/,.*//')"
  if [ -n "$anchor" ] && grep -qiF "$anchor" <<<"$(git -C "$DIST" show "${BASE}:core/team-roles/tea.md")"; then
    ok "shadows: anchors to a heading that EXISTS in core (#$anchor)"
  else
    bad "shadows: anchor '#$anchor' resolves to no heading -- drift detection is dead for this entry"
  fi

  # base_sha at BASE, not THEIRS. Stamping theirs would claim the consumer had already
  # read an upstream change it has not.
  b="$(sed -n 's/^base_sha:[[:space:]]*//p' "$NEW" 2>/dev/null)"
  if [ "$b" = "$BASE" ]; then ok "base_sha stamped at BASE (where the delta forked), not THEIRS"
  else bad "base_sha is '$b', want '$BASE' -- stamping theirs claims a read that never happened"; fi

  if grep -q 'Test Architect' "$NEW" 2>/dev/null; then ok "the consumer's text was carried into the override"
  else bad "the consumer's text was not carried into the override -- it is now LOST"; fi

  # core reverted, so the drift is gone
  if [ "$(bash "$UNREG" "$DIST" "$BASE" "$CONS" | awk -F'\t' '$2=="team-roles/tea.md"{print $1}')" = "CORE-OK" ]; then
    ok "core reverted; tea.md is no longer unregistered drift"
  else
    bad "tea.md still reports drift after register-drift --apply"
  fi

  # A hook has no override grain. It must REFUSE, not invent one.
  bash "$REG" "$DIST" "$BASE" "$CONS" hooks/ai-dlc-continue.sh --apply >/dev/null 2>&1
  if [ $? -eq 2 ]; then ok "refuses a HOOK (no override grain exists for hooks)"
  else bad "register-drift invented an override for a hook -- overrides shadow headings, hooks have none"; fi
fi

echo "== E2. register-drift REFUSES rather than revert an edit it did not carry =="

# register-drift ends in a revert: core overwrites the consumer's file. Every step before it
# that fails QUIETLY therefore destroys an edit, and each world below is one such step, forced:
#   (a) a MIXED diff failure -- two edited sections, `diff` failing for Beta alone. Before the
#       fix the classifier read the empty stream as `yes` (template substitution only), Beta was
#       skipped, the override carried Alpha alone, and core was reverted: rc 0, Beta gone.
#   (b) the same world as a DRY RUN, which is the preview an operator approves.
#   (c) the override path already a DIRECTORY, so the override cannot be written as a file.
#   (d) the BODY extraction failing for Alpha (a `mktemp` shim, keyed on the call index derived
#       from a counting run, not hardcoded) -- only the pre-revert conservation check reads the
#       RESULT, so only it can see an override whose body lost a section. Its CONSUMER side does:
#       Alpha's edited line sits in a section whose text nothing written carries.
#   (e) the positive control: the same two-edit seed, nothing shimmed, registers BOTH sections.
# The shapes the name-keyed resolver misfiles, each measured before ff1ed69e as rc 0, REGISTERED,
# core reverted and the edit gone. Each is refused by the POSITIONAL conservation check:
#   (s) SHADOWED heading: an edited `## Review` below an unedited `## Review Process` -- both names
#       resolve to the latter, so the override carries the wrong section.
#   (u) DUPLICATE same-level heading, edited at its second occurrence.
#   (p) a PREAMBLE edit, above every `##`, beside an edited section.
#   (x) a core section the consumer DELETED: nothing shadows it, so it would render back. Only
#       the CORE side of the check sees this; the consumer side has no added line to test.
#   (y) a consumer-only `## Review` beside core's `## Review Process`: the name resolves to core's
#       section, so it is filed as an unchanged override section, not an extension. Only the
#       CONSUMER side sees this; the core side has no removed line.
#   (g) an EDITED `## 概要`, a heading whose name normalizes to nothing, so no override can anchor it.
#   (k) the ALLOW twin of (g), one property apart: `## 概要` UNCHANGED beside an edited Alpha
#       registers (rc 0) -- the unaddressable heading needs no carrying when byte-equal to core.
#   (j) the same world as (k) as a DRY RUN, which must preview rather than refuse.
# Every arm is PRESENCE-shaped: a named refusal on stderr (the exact conservation line, by line
# number and text), a shim `.fired` marker where there is a shim, and the consumer file
# cmp-identical. A subject that emits nothing fails all of them.
# Worlds are fresh `mktemp -d` directories under $ROOT, one per drive: every --apply mutates its
# world, and a mutant must never read a file a previous drive left.
E2_REALDIFF="$(command -v diff)"; E2_REALMK="$(command -v mktemp)"
if [ -z "$REG" ] || [ -z "$E2_REALDIFF" ] || [ -z "$E2_REALMK" ]; then
  bad "E2: cannot locate register-drift.sh ($REG), diff ($E2_REALDIFF) or mktemp ($E2_REALMK)"
else
  e2_world() { # <beta-edit-marker> -> prints a fresh world dir
    local w
    w="$(mktemp -d "$ROOT/e2w.XXXXXX")" || return 1
    mkdir -p "$w/dist/core/team-roles" "$w/cons/.claude/team-roles" || return 1
    git -C "$w/dist" init -q && git -C "$w/dist" config user.email f@x \
      && git -C "$w/dist" config user.name f || return 1
    printf '# Role: X\n\n## Alpha\n\nalpha core text.\n\n## Beta\n\nbeta core text.\n\n## Gamma\n\ngamma core text.\n' \
      > "$w/dist/core/team-roles/x.md" || return 1
    git -C "$w/dist" add -A && git -C "$w/dist" commit -qm base || return 1
    sed "s/alpha core text\./alpha E2-ALPHA-EDIT./; s/beta core text\./beta $1./" \
      "$w/dist/core/team-roles/x.md" > "$w/cons/.claude/team-roles/x.md" || return 1
    cp "$w/cons/.claude/team-roles/x.md" "$w/orig.md" || return 1
    git -C "$w/dist" rev-parse HEAD > "$w/base" || return 1
    printf '%s' "$w"
  }
  # The resolver-shape worlds (s u p x y g k j): core and consumer written whole, printf-%b text.
  e2_seed() { # <arm> -> sets E2_CORE / E2_CONS
    case "$1" in
      s) E2_CORE='# X\n\n## Alpha\n\nalpha.\n\n## Review Process\n\nproc.\n\n## Review\n\nreview.\n'
         E2_CONS='# X\n\n## Alpha\n\nalpha E2S-ALPHA.\n\n## Review Process\n\nproc.\n\n## Review\n\nreview E2S-REVIEW.\n' ;;
      u) E2_CORE='# X\n\n## Alpha\n\nalpha.\n\n## Notes\n\nn1.\n\n## Beta\n\nbeta.\n\n## Notes\n\nn2.\n'
         E2_CONS='# X\n\n## Alpha\n\nalpha E2S-ALPHA.\n\n## Notes\n\nn1.\n\n## Beta\n\nbeta.\n\n## Notes\n\nn2 E2S-NOTES.\n' ;;
      p) E2_CORE='# X\n\nintro.\n\n## Alpha\n\nalpha.\n'
         E2_CONS='# X\n\nintro E2S-INTRO.\n\n## Alpha\n\nalpha E2S-ALPHA.\n' ;;
      x) E2_CORE='# X\n\n## Alpha\n\nalpha.\n\n## Beta\n\nbeta E2S-COREBETA.\n\n## Gamma\n\ngamma.\n'
         E2_CONS='# X\n\n## Alpha\n\nalpha E2S-ALPHA.\n\n## Gamma\n\ngamma.\n' ;;
      y) E2_CORE='# X\n\n## Alpha\n\nalpha.\n\n## Review Process\n\nproc.\n'
         E2_CONS='# X\n\n## Alpha\n\nalpha E2S-ALPHA.\n\n## Review Process\n\nproc.\n\n## Review\n\nreview E2S-ADDREVIEW.\n' ;;
      g) E2_CORE='# X\n\n## Alpha\n\nalpha.\n\n## 概要\n\ngaiyou.\n'
         E2_CONS='# X\n\n## Alpha\n\nalpha E2S-ALPHA.\n\n## 概要\n\ngaiyou E2S-GAIYOU.\n' ;;
      k|j) E2_CORE='# X\n\n## Alpha\n\nalpha.\n\n## 概要\n\ngaiyou.\n'
         E2_CONS='# X\n\n## Alpha\n\nalpha E2S-ALPHA.\n\n## 概要\n\ngaiyou.\n' ;;
      *) return 1 ;;
    esac
  }
  e2_world2() { # <arm> -> prints a fresh world dir
    local w
    e2_seed "$1" || return 1
    w="$(mktemp -d "$ROOT/e2w.XXXXXX")" || return 1
    mkdir -p "$w/dist/core/team-roles" "$w/cons/.claude/team-roles" || return 1
    git -C "$w/dist" init -q && git -C "$w/dist" config user.email f@x \
      && git -C "$w/dist" config user.name f || return 1
    printf '%b' "$E2_CORE" > "$w/dist/core/team-roles/x.md" || return 1
    git -C "$w/dist" add -A && git -C "$w/dist" commit -qm base || return 1
    printf '%b' "$E2_CONS" > "$w/cons/.claude/team-roles/x.md" || return 1
    cp "$w/cons/.claude/team-roles/x.md" "$w/orig.md" || return 1
    git -C "$w/dist" rev-parse HEAD > "$w/base" || return 1
    printf '%s' "$w"
  }
  # The exact refusal each resolver-shape arm must print: which SIDE of the check fired, at which
  # line, quoting that line. Derived by driving ff1ed69e over the seeds above.
  # One line per acceptable refusal (grep -F reads a newline-separated pattern list). Where BOTH
  # sides of the check see the shape (s u p g), either side's line for that position is accepted,
  # so disabling one side leaves the arm holding on the other -- the side-specific proof is owned
  # by (x), which only the core side sees, and by (y) and (d), which only the consumer side sees.
  e2_want() { case "$1" in
    s) printf '%s\n' "conservation: core line 13 (review.) was changed or removed by the consumer" \
                     "conservation: consumer line 13 (review E2S-REVIEW.) is carried by nothing that was written" ;;
    u) printf '%s\n' "conservation: core line 17 (n2.) was changed or removed by the consumer" \
                     "conservation: consumer line 17 (n2 E2S-NOTES.) is carried by nothing that was written" ;;
    p) printf '%s\n' "conservation: core line 3 (intro.) was changed or removed by the consumer" \
                     "conservation: consumer line 3 (intro E2S-INTRO.) is carried by nothing that was written" ;;
    g) printf '%s\n' "conservation: core line 9 (gaiyou.) was changed or removed by the consumer" \
                     "conservation: consumer line 9 (gaiyou E2S-GAIYOU.) is carried by nothing that was written" ;;
    x) echo "conservation: core line 7 (## Beta) was changed or removed by the consumer" ;;
    y) echo "conservation: consumer line 10 () is carried by nothing that was written" ;;
    d) echo "conservation: consumer line 5 (alpha E2-ALPHA-EDIT.) is carried by nothing that was written" ;;
  esac; }
  # A `diff` that exits 2 only when an input carries KEEPME (Beta's marker in the keyed seed) AND
  # it was handed process substitutions -- substitution_only's per-section diff, never the
  # whole-file conservation diff, which takes two real paths. So Alpha is classified, Beta alone
  # is not, and the conservation check still runs for real: a mutant of layer 1 is then answered
  # by layer 2's positional check, not by a shim that happened to fail both.
  e2_diffshim() {
    local d
    d="$(mktemp -d "$ROOT/e2dshim.XXXXXX")" || return 1
    cat > "$d/diff" <<EOF
#!/bin/sh
t1=\$(mktemp) || exit 3; t2=\$(mktemp) || exit 3
cat "\$1" > "\$t1"; cat "\$2" > "\$t2"
case "\$1" in /dev/fd/*) psub=y ;; *) psub=n ;; esac
if [ "\$psub" = y ] && grep -q KEEPME "\$t1" "\$t2"; then rm -f "\$t1" "\$t2"; : > "$d/.fired"; exit 2; fi
"$E2_REALDIFF" "\$t1" "\$t2"; rc=\$?; rm -f "\$t1" "\$t2"; exit \$rc
EOF
    chmod +x "$d/diff" && printf '%s' "$d"
  }
  # A `mktemp` that logs every call (`noarg` = section_of's own temp file, `arg` = a templated
  # temp beside a target) and fails the Nth no-argument call; N=0 never fails.
  e2_mkshim() { # <N>
    local d
    d="$(mktemp -d "$ROOT/e2mshim.XXXXXX")" || return 1
    echo 0 > "$d/n"; : > "$d/log"
    cat > "$d/mktemp" <<EOF
#!/bin/sh
if [ \$# -eq 0 ]; then
  n=\$(( \$(cat "$d/n") + 1 )); echo \$n > "$d/n"; echo noarg >> "$d/log"
  if [ "\$n" = "$1" ]; then : > "$d/.fired"; exit 1; fi
else
  echo arg >> "$d/log"
fi
exec "$E2_REALMK" "\$@"
EOF
    chmod +x "$d/mktemp" && printf '%s' "$d"
  }
  e2_run() { # <script> <world> <shim-dir or -> [--apply]
    local s="$1" w="$2" p="$3" P="$PATH"; shift 3
    [ "$p" = - ] || P="$p:$PATH"
    PATH="$P" bash "$s" "$w/dist" "$(cat "$w/base")" "$w/cons" team-roles/x.md "$@" > "$w/out" 2> "$w/err"
    echo $? > "$w/rc"
  }
  e2_novr() { ls -A "$1/cons/.claude/skills/ai-dlc/overrides" 2>/dev/null | wc -l | tr -d ' '; }

  # The call index of Alpha's BODY extraction, derived: the body is extracted after the classify
  # loop and immediately before the first templated temp file (the override's), one no-argument
  # call per changed section, Alpha first. A counting run that registers cleanly supplies it.
  E2_N=""
  e2w="$(e2_world E2-BETA-EDIT-KEEPME)"; e2m="$(e2_mkshim 0)"
  if [ -n "$e2w" ] && [ -n "$e2m" ]; then
    e2_run "$REG" "$e2w" "$e2m" --apply
    e2c="$(awk '/^arg$/ { print c + 0; f = 1; exit } /^noarg$/ { c++ }' "$e2m/log")"
    if [ "$(cat "$e2w/rc")" = 0 ] && grep -q '^REGISTERED' "$e2w/out" && [ -n "$e2c" ] && [ "$e2c" -ge 3 ]; then
      E2_N=$((e2c - 1))
    fi
  fi
  if [ -n "$E2_N" ]; then
    ok "E2 harness: a counting run registers cleanly and puts Alpha's body extraction at no-argument mktemp call $E2_N"
  else
    bad "E2 harness: the counting run did not register or logged no templated mktemp before the body (rc=$(cat "$e2w/rc" 2>/dev/null)) -- arm (d) cannot be keyed"
  fi

  E2_WHY=""; E2_W=""
  e2_arm() { # <a|b|c|d|e|n|s|u|p|x|y|g|k|j> <script> -> 0 holds / 1 fails / 2 harness; E2_WHY and E2_W describe the run
    local arm="$1" s="$2" w sh="" o rc f=n same=n novr beta=E2-BETA-EDIT-KEEPME want
    E2_WHY=""; E2_W=""
    case "$arm" in
      s|u|p|x|y|g|k|j)
        w="$(e2_world2 "$arm")"; [ -n "$w" ] || { E2_WHY="world build failed"; return 2; }
        E2_W="$w"; o="$w/cons/.claude/skills/ai-dlc/overrides/team-roles__x__consumer-drift.md"
        if [ "$arm" = j ]; then e2_run "$s" "$w" -; else e2_run "$s" "$w" - --apply; fi
        rc="$(cat "$w/rc")"
        cmp -s "$w/orig.md" "$w/cons/.claude/team-roles/x.md" && same=y
        novr="$(e2_novr "$w")"
        case "$arm" in
          k)
            E2_WHY="rc=$rc registered=$(grep -c '^REGISTERED' "$w/out") unaddressable-line=$(grep -c 'headings no override can anchor.*概要' "$w/out") alpha=$(grep -c E2S-ALPHA "$o" 2>/dev/null) reverted=$(cmp -s "$w/dist/core/team-roles/x.md" "$w/cons/.claude/team-roles/x.md" && echo y || echo n) err=$(head -1 "$w/err" | cut -c1-120)"
            [ "$rc" = 0 ] && grep -q '^REGISTERED' "$w/out" && grep -q 'headings no override can anchor.*概要' "$w/out" \
              && grep -q E2S-ALPHA "$o" && cmp -s "$w/dist/core/team-roles/x.md" "$w/cons/.claude/team-roles/x.md" ;;
          j)
            E2_WHY="rc=$rc dry-run-line=$(grep -c 'DRY RUN' "$w/out") unaddressable-line=$(grep -c 'headings no override can anchor.*概要' "$w/out") preview-alpha=$(grep -c E2S-ALPHA "$w/out") overrides-dir-entries=$novr consumer-identical=$same err=$(head -1 "$w/err" | cut -c1-120)"
            [ "$rc" = 0 ] && grep -q 'DRY RUN' "$w/out" && grep -q 'headings no override can anchor.*概要' "$w/out" \
              && grep -q E2S-ALPHA "$w/out" && [ "$novr" = 0 ] && [ "$same" = y ] ;;
          *)
            want="$(e2_want "$arm")"
            E2_WHY="rc=$rc names-the-line=$(grep -cF "$want" "$w/err") registered=$(grep -c '^REGISTERED' "$w/out") overrides-dir-entries=$novr consumer-identical=$same err=$(head -1 "$w/err" | cut -c1-140)"
            [ "$rc" = 2 ] && grep -qF "$want" "$w/err" && [ "$novr" = 0 ] && [ "$same" = y ] \
              && ! grep -q '^REGISTERED' "$w/out" ;;
        esac
        return $? ;;
    esac
    [ "$arm" = n ] && beta=E2-BETA-EDIT-PLAIN
    w="$(e2_world "$beta")"; [ -n "$w" ] || { E2_WHY="world build failed"; return 2; }
    E2_W="$w"; o="$w/cons/.claude/skills/ai-dlc/overrides/team-roles__x__consumer-drift.md"
    case "$arm" in
      a|b|n) sh="$(e2_diffshim)" ;;
      d)     [ -n "$E2_N" ] || { E2_WHY="no derived call index"; return 2; }; sh="$(e2_mkshim "$E2_N")" ;;
      c)     mkdir -p "$o" ;;
    esac
    case "$arm" in a|b|n|d) [ -n "$sh" ] || { E2_WHY="shim build failed"; return 2; } ;; esac
    if [ "$arm" = b ]; then e2_run "$s" "$w" "${sh:--}"; else e2_run "$s" "$w" "${sh:--}" --apply; fi
    rc="$(cat "$w/rc")"
    [ -n "$sh" ] && [ -e "$sh/.fired" ] && f=y
    cmp -s "$w/orig.md" "$w/cons/.claude/team-roles/x.md" && same=y
    novr="$(e2_novr "$w")"
    case "$arm" in
      a|b)
        E2_WHY="rc=$rc fired=$f names-Beta=$(grep -cF "cannot classify section 'Beta'" "$w/err") overrides-dir-entries=$novr consumer-identical=$same dry-run-line=$(grep -c 'DRY RUN' "$w/out")"
        [ "$rc" = 2 ] && [ "$f" = y ] && grep -qF "cannot classify section 'Beta'" "$w/err" \
          && [ "$novr" = 0 ] && [ "$same" = y ] && ! grep -q 'DRY RUN' "$w/out" && ! grep -q '^REGISTERED' "$w/out" ;;
      c)
        E2_WHY="rc=$rc names-path=$(grep -cF 'exists and is not a regular file' "$w/err") inside-the-dir=$(ls -A "$o" 2>/dev/null | wc -l | tr -d ' ') consumer-identical=$same"
        [ "$rc" = 2 ] && grep -qF 'exists and is not a regular file' "$w/err" && [ -d "$o" ] \
          && [ "$(ls -A "$o" | wc -l | tr -d ' ')" = 0 ] && [ "$novr" = 1 ] && [ "$same" = y ] ;;
      d)
        want="$(e2_want d)"
        E2_WHY="rc=$rc fired=$f names-Alpha-line=$(grep -cF "$want" "$w/err") overrides-dir-entries=$novr consumer-identical=$same err=$(head -1 "$w/err" | cut -c1-140)"
        [ "$rc" = 2 ] && [ "$f" = y ] && grep -qF "$want" "$w/err" \
          && [ "$novr" = 0 ] && [ "$same" = y ] ;;
      e|n)
        E2_WHY="rc=$rc fired=$f registered=$(grep -c '^REGISTERED' "$w/out") alpha=$(grep -c E2-ALPHA-EDIT "$o" 2>/dev/null) beta=$(grep -c "$beta" "$o" 2>/dev/null) reverted=$(cmp -s "$w/dist/core/team-roles/x.md" "$w/cons/.claude/team-roles/x.md" && echo y || echo n)"
        [ "$rc" = 0 ] && [ "$f" = n ] && grep -q '^REGISTERED' "$w/out" && grep -q E2-ALPHA-EDIT "$o" \
          && grep -q "$beta" "$o" && cmp -s "$w/dist/core/team-roles/x.md" "$w/cons/.claude/team-roles/x.md" ;;
    esac
  }
  # The DAMAGE a killed arm must show, read off the world e2_arm just drove. A mutant scores a
  # kill only by reproducing the loss the arm exists to prevent -- never by merely not refusing,
  # which a copy that died would also do.
  e2_damage() { # <arm>
    local w="$E2_W" o="$E2_W/cons/.claude/skills/ai-dlc/overrides/team-roles__x__consumer-drift.md"
    case "$1" in
      a) [ "$(cat "$w/rc")" = 0 ] && grep -q '^REGISTERED' "$w/out" && ! grep -rq KEEPME "$w/cons" ;;
      b) [ "$(cat "$w/rc")" = 0 ] && grep -q 'DRY RUN' "$w/out" && grep -q '^── skipped.*Beta' "$w/out" ;;
      c) [ "$(cat "$w/rc")" = 0 ] && grep -q '^REGISTERED' "$w/out" && [ -d "$o" ] && [ "$(ls -A "$o" | wc -l | tr -d ' ')" = 1 ] ;;
      d) [ "$(cat "$w/rc")" = 0 ] && grep -q '^REGISTERED' "$w/out" && ! grep -rq E2-ALPHA-EDIT "$w/cons" ;;
      s|u|p|y|g) [ "$(cat "$w/rc")" = 0 ] && grep -q '^REGISTERED' "$w/out" && ! grep -rq "$(e2_marker "$1")" "$w/cons" ;;
      # A deleted core section is lost the other way round: the revert writes it BACK, and no
      # override shadows it, so the consumer's deletion is undone.
      x) [ "$(cat "$w/rc")" = 0 ] && grep -q '^REGISTERED' "$w/out" && grep -q E2S-COREBETA "$w/cons/.claude/team-roles/x.md" \
           && ! grep -q 'x.md#Beta' "$o" ;;
      *) return 1 ;;
    esac
  }

  e2_label() { case "$1" in
    a) echo "(a) MIXED diff failure, --apply" ;;   b) echo "(b) MIXED diff failure, dry run" ;;
    c) echo "(c) override path is a directory" ;;  d) echo "(d) Alpha's body extraction fails" ;;
    e) echo "(e) positive control, unshimmed" ;;   n) echo "(a') keyed shim over an UNKEYED seed" ;;
    s) echo "(s) edited ## Review SHADOWED by ## Review Process" ;;
    u) echo "(u) duplicate same-level ## Notes, second one edited" ;;
    p) echo "(p) preamble edit beside an edited section" ;;
    x) echo "(x) a core section the consumer DELETED" ;;
    y) echo "(y) consumer-only ## Review resolving to core's ## Review Process" ;;
    g) echo "(g) an EDITED unaddressable ## 概要" ;;
    k) echo "(k) an UNCHANGED unaddressable ## 概要, --apply" ;;
    j) echo "(j) an UNCHANGED unaddressable ## 概要, dry run" ;;
  esac; }
  e2_marker() { case "$1" in
    s) echo E2S-REVIEW ;; u) echo E2S-NOTES ;; p) echo E2S-INTRO ;; y) echo E2S-ADDREVIEW ;; g) echo E2S-GAIYOU ;;
  esac; }
  e2_ok() { case "$1" in
    a) echo "refused naming Beta (rc 2), the diff shim fired, no override written, the consumer file cmp-identical" ;;
    b) echo "the dry run refuses too, naming Beta, and prints no DRY RUN preview missing a section" ;;
    c) echo "refused (rc 2) naming the path, nothing moved inside the directory, the consumer file cmp-identical" ;;
    d) echo "the conservation check's CONSUMER side refuses naming Alpha's edited line 5 (rc 2), the mktemp shim fired, no override, the consumer file cmp-identical" ;;
    s|u|p|g) echo "refused (rc 2) by the positional conservation check naming the edited line by number and text, no override, the consumer file cmp-identical" ;;
    x) echo "refused (rc 2) by the CORE side naming the deleted '## Beta' at core line 7, no override, the consumer file cmp-identical" ;;
    y) echo "refused (rc 2) by the CONSUMER side naming line 10 of the misfiled section, no override, the consumer file cmp-identical" ;;
    k) echo "the allow twin of (g): rc 0, REGISTERED, the heading reported as unaddressable, Alpha carried, core reverted" ;;
    j) echo "the dry run previews (rc 0, DRY RUN, Alpha in the preview) rather than refusing, and writes nothing" ;;
    e) echo "rc 0, REGISTERED, the override carries BOTH edits, and core is reverted" ;;
    n) echo "the allow twin of (a): the same shim on a seed without its key does not fire, and both edits register" ;;
  esac; }

  E2_ARMS="a b c d e n s u p x y g k j"
  for e2a in $E2_ARMS; do
    e2_arm "$e2a" "$REG"; e2r=$?
    if [ "$e2r" = 0 ]; then ok "$(e2_label "$e2a"): $(e2_ok "$e2a")"
    else bad "$(e2_label "$e2a"): $E2_WHY (verdict $e2r)"; fi
  done

  # --- MUTANTS. A copy of the WHOLE reconcile directory (the script sources lib.sh; a lone copy
  # dies, prints nothing, and would score every arm as a kill). Each mutation is a fixed-string
  # line replacement whose key must occur EXACTLY once before and zero times after, plus a
  # `cmp -s` that the copy differs -- a respelled line reports DID NOT APPLY, never a kill.
  #   M1  layer 1 reverted ALONE: substitution_only two-valued again (no `unknown`, an empty
  #       stream reads `yes`) and the caller refusal gone. Since the conservation check became
  #       positional it no longer re-asks the classifier, so it CATCHES the skipped Beta by
  #       position: core's Beta line is removed and nothing shadows it. M1 therefore moves (a) and
  #       (b) -- the Beta-naming refusal is gone -- and must NOT reproduce the loss: it is scored
  #       as COVERED, and the refusal it gets instead must be layer 2's, naming core line 9.
  #   M1+ every layer reverted: M1 plus M2. Reproduces the loss in (a) and (b). It necessarily
  #       also moves every arm M2 owns, and exactly those, so it is scored against that set.
  #   M2  the conservation check's verdict replaced by a no-op. Owns (d) and every resolver-shape
  #       arm: nothing else reads the written files back against the consumer's.
  #   M3  the not-a-regular-file guard removed. Owns (c): `mv` onto a directory SUCCEEDS by
  #       moving the file inside it, so the run registers and reverts.
  #   M4  the CORE side of the check off (removed core lines never tested against `shadows:`).
  #       Owns (x) alone: every other shape the core side sees, the consumer side sees too.
  #   M5  the CONSUMER side of the check off (added consumer lines never tested for a carrier).
  #       Owns (y) and (d): a pure addition and a lost body have no unshadowed removed line.
  # NOT a mutant here, measured and recorded: leaving the whole-file diff's exit status unchecked
  # SURVIVES every world, because the awk refuses a hunkless stream on its own (`hunks 0`) --
  # the two guards cover each other, and no world separates them without faking a diff that
  # exits non-zero while printing hunks.
  EMUT="$(mktemp -d "$ROOT/e2mut.XXXXXX")" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
  cp "$(dirname "$REG")"/*.sh "$EMUT/" 2>/dev/null || true
  cp "$(dirname "$REG")"/*.md "$EMUT/" 2>/dev/null || true
  cp "$REG" "$EMUT/register-drift.sh"
  e2_ctl=0
  if [ -f "$EMUT/lib.sh" ] && cmp -s "$REG" "$EMUT/register-drift.sh"; then
    for e2a in $E2_ARMS; do
      e2_arm "$e2a" "$EMUT/register-drift.sh" || { e2_ctl=1; bad "  mutation control: the unmutated copy fails $(e2_label "$e2a"): $E2_WHY"; }
    done
  else
    e2_ctl=1; bad "  mutation control: lib.sh is not beside the copied register-drift.sh -- every verdict below would be a dead copy"
  fi
  [ "$e2_ctl" = 0 ] && ok "  mutation control: an unmutated copy in a fresh directory holds every E2 arm ($E2_ARMS), including REGISTERED through the keyed shim on the unkeyed seed and the unaddressable-heading allow twins"

  e2_mutate() { # <key> <replacement> [<key> <replacement>]... -> builds $EMUT/register-drift.sh
    local dst="$EMUT/register-drift.sh"
    cp "$REG" "$dst" || return 1
    while [ $# -ge 2 ]; do
      [ "$(grep -cF -- "$1" "$dst")" = 1 ] || return 1
      K="$1" R="$2" awk 'index($0, ENVIRON["K"]) { print ENVIRON["R"]; next } { print }' "$dst" > "$dst.next" || return 1
      mv "$dst.next" "$dst" || return 1
      [ "$(grep -cF -- "$1" "$dst")" = 0 ] || return 1
      shift 2
    done
    ! cmp -s "$REG" "$dst"
  }
  # Arms are space-delimited in <owned> / <also>, so a one-letter arm matches only itself.
  e2_in() { case " $2 " in *" $1 "*) return 0 ;; esac; return 1; }
  e2_score() { # <name> <owned-arms> [<also-moved-arms>]
    local a r others="" moved=""
    for a in $E2_ARMS; do
      e2_arm "$a" "$EMUT/register-drift.sh"; r=$?
      if e2_in "$a" "$2"; then
        if [ "$r" = 1 ] && e2_damage "$a"; then
          ok "  mutation $1 KILLS $(e2_label "$a"): the edit is lost exactly as before the fix -- $E2_WHY"
        else
          bad "  mutation $1 did NOT kill $(e2_label "$a") with the loss reproduced (verdict $r): $E2_WHY"
        fi
      elif e2_in "$a" "${3:-}"; then
        { [ "$r" = 1 ] && e2_damage "$a"; } || others="$others $a(expected to move with the loss, verdict $r: $E2_WHY)"
        moved="$moved $a"
      else
        [ "$r" = 0 ] || others="$others $a($E2_WHY)"
      fi
    done
    if [ -z "$others" ]; then
      if [ -n "$moved" ]; then ok "  mutation $1: beyond its own it moves exactly{$moved } (M2's set, with the loss) and every other arm holds"
      else ok "  mutation $1: every arm it does not own still holds -- it fails only its own"; fi
    else bad "  mutation $1 ALSO moved:$others -- the arms are entangled"; fi
  }
  # M1 alone: the owned arms must FAIL (the Beta-naming refusal is layer 1's) while the edit is
  # KEPT -- refused by layer 2 at Beta's core line, consumer cmp-identical, nothing written.
  e2_score_covered() { # <name> <owned-arms>
    local a r others="" want="conservation: core line 9 (beta core text.) was changed or removed by the consumer"
    for a in $E2_ARMS; do
      e2_arm "$a" "$EMUT/register-drift.sh"; r=$?
      if e2_in "$a" "$2"; then
        if [ "$r" = 1 ] && [ "$(cat "$E2_W/rc")" = 2 ] && grep -qF "$want" "$E2_W/err" \
             && cmp -s "$E2_W/orig.md" "$E2_W/cons/.claude/team-roles/x.md" && [ "$(e2_novr "$E2_W")" = 0 ]; then
          ok "  mutation $1 moves $(e2_label "$a") and is COVERED: layer 2 refuses at Beta's core line 9, the consumer file cmp-identical"
        else
          bad "  mutation $1 on $(e2_label "$a"): want the arm to fail AND layer 2 to refuse naming core line 9 with the edit kept (verdict $r): $E2_WHY err=$(head -1 "$E2_W/err" | cut -c1-140)"
        fi
      else
        [ "$r" = 0 ] || others="$others $a($E2_WHY)"
      fi
    done
    if [ -z "$others" ]; then ok "  mutation $1: every arm it does not own still holds -- it fails only its own"
    else bad "  mutation $1 ALSO moved:$others -- the arms are entangled"; fi
  }
  E2_M1="then printf 'unknown'; return 0; fi"
  E2_M1R="  :"
  E2_M1B='if (!hunk) { print "unknown"; exit } '
  E2_M1BR='    END      { if (hunk && !tok) bad=1; print (bad ? "no" : "yes") }'
  E2_M1C='refuse "cannot classify section'
  E2_M1CR="    # M1: the unknown arm removed; a non-yes answer falls through to changed"
  E2_M2='|| refuse "conservation: ${cons_check:-'
  E2_M2R='  || true'
  if [ "$e2_ctl" = 0 ]; then
    if e2_mutate "$E2_M1" "$E2_M1R" "$E2_M1B" "$E2_M1BR" "$E2_M1C" "$E2_M1CR"; then
      e2_score_covered M1 "a b"
    else bad "  mutation M1 DID NOT APPLY: a layer-1 anchor in substitution_only or its caller was respelled -- (a) and (b) are unproven"; fi
    if e2_mutate "$E2_M1" "$E2_M1R" "$E2_M1B" "$E2_M1BR" "$E2_M1C" "$E2_M1CR" "$E2_M2" "$E2_M2R"; then
      e2_score M1+ "a b" "d s u p x y g"
    else bad "  mutation M1+ DID NOT APPLY: a layer-1 anchor or the conservation verdict line was respelled -- (a) and (b) are unproven"; fi
    if e2_mutate "$E2_M2" "$E2_M2R"; then
      e2_score M2 "d s u p x y g"
    else bad "  mutation M2 DID NOT APPLY: the conservation verdict line was respelled -- (d) and the resolver-shape arms are unproven"; fi
    if e2_mutate '[ ! -e "$1" ] || [ -f "$1" ] || refuse' "    :"; then
      e2_score M3 c
    else bad "  mutation M3 DID NOT APPLY: the not-a-regular-file guard was respelled -- (c) is unproven"; fi
    if e2_mutate 'for (k = 1; k <= nlost; k++) if (!shadowed(LOST[k])) {' '    for (k = 1; k <= nlost; k++) if (0) {'; then
      e2_score M4 x
    else bad "  mutation M4 DID NOT APPLY: the core-side loop of the conservation check was respelled -- (x) is unproven"; fi
    if e2_mutate 'for (L = rs; L <= re; L++) if (!covered(L)) {' '    for (L = rs; L <= re; L++) if (0) {'; then
      e2_score M5 "y d"
    else bad "  mutation M5 DID NOT APPLY: the consumer-side loop of the conservation check was respelled -- (y) and (d) are unproven"; fi
  fi
fi

echo "== F. upstream ABSORBED the consumer's in-place delta =="

# Extensions have had this signal since v0.34.0 (EXTENSION-RETIRE-CANDIDATE). Core drift
# had NO equivalent, so a consumer whose hardening was upstreamed went on being told to
# "refile it as an override, or revert" — with nothing saying the revert was now the
# RIGHT answer. It would have blocked forever on a delta core already carried.
# (Live case: the reference consumer's handoff resume-prompt guard, v0.55.0.)
st_theirs="$(bash "$UNREG" "$DIST" "$BASE" "$CONS" "$THEIRS" | awk -F'\t' '$2=="hooks/guard.sh"{print $1}')"
st_base="$(bash "$UNREG" "$DIST" "$BASE" "$CONS" "$BASE"   | awk -F'\t' '$2=="hooks/guard.sh"{print $1}')"
st_none="$(bash "$UNREG" "$DIST" "$BASE" "$CONS"           | awk -F'\t' '$2=="hooks/guard.sh"{print $1}')"

if [ "$st_theirs" = "HARD-CORE-DRIFT-ABSORBED" ]; then
  ok "upstream absorbed the delta -> HARD-CORE-DRIFT-ABSORBED (remedy: revert, not override)"
else
  bad "absorption NOT detected (got '$st_theirs') — the consumer would be told to refile a delta core already carries, forever"
fi

# The control: at BASE, upstream does NOT have the lines, so it must NOT claim absorption.
# A detector that says 'absorbed' when nothing was absorbed invites the operator to
# DELETE consumer text upstream never took.
if [ "$st_base" = "HARD-UNREGISTERED-CORE-DRIFT" ]; then
  ok "not-yet-absorbed -> plain HARD-UNREGISTERED-CORE-DRIFT (no false 'absorbed')"
else
  bad "claimed absorption against a core that does NOT carry the delta (got '$st_base') — this would delete consumer text"
fi

if [ "$st_none" = "HARD-UNREGISTERED-CORE-DRIFT" ]; then
  ok "no theirs-ref -> old behaviour preserved"
else
  bad "behaviour changed when no theirs-ref is passed (got '$st_none')"
fi

# It must still BLOCK. Absorption changes the recommendation, not who decides: a revert
# deletes consumer content, and only the operator can confirm nothing was lost.
case "$st_theirs" in
  HARD-*) ok "absorption still BLOCKS apply (a revert deletes text; the operator confirms)" ;;
  *)      bad "absorption downgraded out of HARD- — apply would silently delete the consumer's hook" ;;
esac

echo "== C3. an override that delegates INTO the section it shadows =="

# Precedence is overrides > extensions > core, so a whole-section shadow deletes every
# construct defined inside that section -- including one the override's own body points
# the lead at. It reads as a correct single-source delegation and behaves as a dropped
# one. Both real instances on the reference consumer were reported OVERRIDE-OK while
# doing exactly this, which is why the two questions must be asked separately.
DRIFT="$(pick "$HERE/../../skills/ai-dlc-update/reconcile/layer-drift.sh" \
              "$HERE/../../../core/skills/ai-dlc-update/reconcile/layer-drift.sh" \
              "$HERE/../../../.claude/skills/ai-dlc-update/reconcile/layer-drift.sh")"
if [ -z "$DRIFT" ]; then
  bad "FIXTURE BROKEN — cannot locate layer-drift.sh; C3 would pass by not running"
else
  ld_out="$(bash "$DRIFT" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>&1)"
  st_of() { printf '%s\n' "$ld_out" | awk -F'\t' -v e="$1" '$2 ~ e {print $1}'; }

  if grep -qx OVERRIDE-DELEGATES-INTO-SHADOW <<<"$(st_of 'SKILL__Rule-10\.md$')"; then
    ok "an override naming a construct defined inside its own shadow is REPORTED"
  else
    bad "the delegation went undetected — every future change to that construct fails to arrive while every check reports green"
  fi

  # THE CONTROL, and it must be able to fail. Same shape, same file, delegating to a
  # construct defined OUTSIDE the shadowed span. Without it the assertion above passes
  # for a detector that flags every override carrying a backticked term.
  if grep -qx OVERRIDE-DELEGATES-INTO-SHADOW <<<"$(st_of 'SKILL__Rule-10-control\.md$')"; then
    bad "an override delegating OUTSIDE its shadow was reported — the detector fires on every legitimate cross-section pointer"
  else
    ok "  and delegating to a construct outside the shadow stays silent"
  fi

  # It answers a DIFFERENT question than the drift arm. Both rows must appear for the
  # same entry: folding this into `worst` would hide it behind an OVERRIDE-OK, which is
  # precisely how both live instances stayed invisible.
  if grep -qx OVERRIDE-OK <<<"$(st_of 'SKILL__Rule-10\.md$')"; then
    ok "  and the entry is STILL OVERRIDE-OK on drift (the two questions are independent)"
  else
    bad "  but the delegation status displaced the drift status — one entry, two questions, two rows"
  fi

  # THE MEASURED FALSE POSITIVE, and the only assertion that can catch its return.
  # When the backticked term is in the ANCHOR heading itself, naming it is
  # self-description, not delegation. Dropping the anchor-heading exclusion re-fires
  # this (1 of 13 on the reference consumer) and every other assertion here stays green.
  if grep -qx OVERRIDE-DELEGATES-INTO-SHADOW <<<"$(st_of 'SKILL__Rule-12-anchor\.md$')"; then
    bad "an override naming a term from the heading it OVERRIDES was reported — the anchor heading is not being excluded, and every self-describing override now fires"
  else
    ok "  and naming a term from the overridden heading itself stays silent"
  fi

  # Report-only. It must not block `apply`, or a consumer cannot take a security fix
  # until it has restructured its own overrides.
  if grep -q DELEGATES <<<"$(printf '%s\n' "$ld_out" | awk -F'\t' '$1 ~ /^HARD-/{print $1}')"; then
    bad "OVERRIDE-DELEGATES-INTO-SHADOW carries a HARD- prefix — it would block apply"
  else
    ok "  and it is report-only, never a blocker"
  fi

  # --- OVERRIDE-ASSERTS-SHADOW-SURVIVES, the sibling status ---------------------------
  # Same mechanism as the delegation arm, opposite failure: that one points the lead at
  # text precedence has removed, this one TELLS the lead the text is still there. Measured
  # on the reference consumer: a bare survival-vocabulary scan matches 5 of 13 overrides
  # with only 2 real; restricting the claim's noun to the shadowed grain takes the
  # false-positive set to zero. The three controls below are those three false positives.
  if grep -qx OVERRIDE-ASSERTS-SHADOW-SURVIVES <<<"$(st_of 'SKILL__Rule-13-survives\.md$')"; then
    ok "an override asserting its own shadowed span survives is REPORTED"
  else
    bad "the survival claim went undetected — the body states something false about its own effect and every check reports green"
  fi

  # THE WRAP, isolated in its own entry so exactly ONE assertion is sensitive to it. The
  # claim splits across a newline between 'Every other part of' and 'Rule 16', where the
  # real instance splits. A line-based predicate returns zero here, which reads identically
  # to compliance. Nothing else in this file would notice the flattening being removed.
  if grep -qx OVERRIDE-ASSERTS-SHADOW-SURVIVES <<<"$(st_of 'SKILL__Rule-16-wrapped\.md$')"; then
    ok "  and a claim WRAPPING across a newline is still found (the body is flattened)"
  else
    bad "  the wrapped claim was missed — a line-based scan reports a false zero on the real shape"
  fi

  # --- OVERRIDE-BODY-UNCLAIMED (LC-O16) ------------------------------------------------
  # The third body-side question, and the one that asks something the other two cannot:
  # LC-O9 and LC-O14 ask whether the body is TRUTHFUL, this asks whether it is REACHED.
  # The state is what an LC-O15 narrowing LEAVES BEHIND when it removes an anchor and keeps
  # the text, so the two clauses have to be read together.
  if grep -qx OVERRIDE-BODY-UNCLAIMED <<<"$(st_of 'SKILL__Rule-18-unclaimed\.md$')"; then
    ok "a body section no shadows: anchor claims is REPORTED"
  else
    bad "the unclaimed body section went undetected — it is applied by nothing while every mechanical check reports green"
  fi

  # THE NEAR-MISS, and it is the assertion that stops this arm being a heading counter. A
  # sub-heading nested INSIDE a claimed section is inside that anchor's span; a heading-set
  # difference would report every '###' child of every shadowed section on every consumer.
  if grep -qx OVERRIDE-BODY-UNCLAIMED <<<"$(st_of 'SKILL__Rule-19-nested\.md$')"; then
    bad "a sub-heading NESTED inside the claimed section was reported — the claim is being read as a heading set, not a span, and every override with a child heading is a false positive"
  else
    ok "  and a sub-heading nested inside a claimed section stays silent"
  fi

  # The single-anchor shape: a body restating NO shadowed heading is the WHOLE span of its
  # one anchor, so nothing in it can be unclaimed. readopt-override.sh names this shape at
  # its own refusal site; an arm that fired here would report every such entry forever.
  if grep -qx OVERRIDE-BODY-UNCLAIMED <<<"$(st_of 'SKILL__Rule-13-survives\.md$')"; then
    bad "the single-anchor shape (a body restating no shadowed heading) was reported — the whole body is that anchor's span and nothing in it can be unclaimed"
  else
    ok "  and the single-anchor shape stays silent"
  fi

  if grep -q '^HARD-' <<<"$(st_of 'SKILL__Rule-18-unclaimed\.md$')"; then
    bad "OVERRIDE-BODY-UNCLAIMED carries a HARD- prefix — it would block apply"
  else
    ok "  and it is report-only (no HARD- prefix), so it cannot block an apply"
  fi

  # It answers a DIFFERENT question than the drift arm, same as its sibling. Both real
  # instances were OVERRIDE-OK while making the claim.
  if grep -qx OVERRIDE-OK <<<"$(st_of 'SKILL__Rule-13-survives\.md$')"; then
    ok "  and the entry is STILL OVERRIDE-OK on drift (two questions, two rows)"
  else
    bad "  but the survival status displaced the drift status — it would hide behind an OVERRIDE-OK"
  fi

  # CONTROL 1 — the shape the grain warning names as legitimate, and the reason the noun
  # set excludes `file`. An override shadowing ONE section that says the rest of the FILE
  # is unchanged is telling the truth, in the same vocabulary. Widening the predicate to
  # any survival claim re-fires this and every other assertion here stays green.
  if grep -qx OVERRIDE-ASSERTS-SHADOW-SURVIVES <<<"$(st_of 'SKILL__Rule-14-file-claim\.md$')"; then
    bad "an override correctly saying the rest of the FILE is unchanged was reported — the noun restriction is gone and every honest scoping sentence now fires"
  else
    ok "  and a true claim about the rest of the FILE stays silent"
  fi

  # CONTROL 2 — the measured false-positive class: survival vocabulary whose subject is a
  # DIFFERENT named unit, plus a self-reference to the override's own body. Both shapes
  # occur on the reference consumer and both must stay silent.
  if grep -qx OVERRIDE-ASSERTS-SHADOW-SURVIVES <<<"$(st_of 'SKILL__Rule-15-other-unit\.md$')"; then
    bad "an override whose survival claim names a DIFFERENT unit was reported — this is the 3-of-5 false-positive set returning"
  else
    ok "  and survival vocabulary about another unit stays silent"
  fi

  # Report-only, for the same reason as its sibling.
  if grep -q ASSERTS <<<"$(printf '%s\n' "$ld_out" | awk -F'\t' '$1 ~ /^HARD-/{print $1}')"; then
    bad "OVERRIDE-ASSERTS-SHADOW-SURVIVES carries a HARD- prefix — it would block apply"
  else
    ok "  and it is report-only, never a blocker"
  fi

  # --- OVERRIDE-LOOSE-ANCHOR: the pull-time counterpart of E7 --------------------------
  # E7 rejects an anchor that resolves only by the REVERSE arm at AUTHORING time. That
  # validator is consumer-run and skippable; the pull is not, and an anchor finer than a
  # heading silently widens the shadow to the whole section either way.
  #
  # NOT a "mirror of E7". Even now that both read `shadows:` through the same shadow_parts,
  # E7 resolves against the consumer's on-disk core and this resolves against THEIRS — the
  # incoming distribution — so they answer the same question about two different trees.
  if grep -qx OVERRIDE-LOOSE-ANCHOR <<<"$(st_of 'SKILL__Rule-11-loose\.md$')"; then
    ok "an anchor that CONTAINS its heading is REPORTED at pull time"
  else
    bad "the loose anchor went undetected — the entry shadows the whole section while the operator believes it shadowed a paragraph"
  fi

  # CONTROL — the legitimate id-prefix grain, in the same vocabulary. `#Rule 8` naming
  # `## Rule 8 -- Validation Depth` is a consumer naming a rule by its id, and it is what
  # nearly every entry here does. If this fires, the arm has been inverted and every
  # well-formed override in the consumer reports.
  if grep -qx OVERRIDE-LOOSE-ANCHOR <<<"$(st_of 'SKILL__Rule-8\.md$')"; then
    bad "a FORWARD-matching id-prefix anchor was reported loose — the containment direction is inverted and every honest entry now fires"
  else
    ok "  and a FORWARD-matching id-prefix anchor stays silent"
  fi

  if grep -qx OVERRIDE-OK <<<"$(st_of 'SKILL__Rule-11-loose\.md$')"; then
    ok "  and the entry is STILL OVERRIDE-OK on drift (two questions, two rows)"
  else
    bad "  but the loose status displaced the drift status — it would hide behind an OVERRIDE-OK"
  fi

  # --- OVERRIDE-DOUBLE-SHADOW: a finding that exists only ACROSS entries ---------------
  # Each entry is individually well-formed. Precedence resolves the overlap silently, so
  # which body governs is an ordering accident no entry declares, and every commit touching
  # the span invalidates BOTH stamps while reconciling one looks complete.
  ds_a="$(printf '%s\n' "$(st_of 'SKILL__Rule-7-dup-a\.md$')" | grep -cx OVERRIDE-DOUBLE-SHADOW || true)"
  ds_b="$(printf '%s\n' "$(st_of 'SKILL__Rule-7-dup-b\.md$')" | grep -cx OVERRIDE-DOUBLE-SHADOW || true)"
  if [ "$ds_a" -eq 1 ] && [ "$ds_b" -eq 1 ]; then
    ok "two entries claiming one (file, anchor) are BOTH reported"
  else
    bad "double shadow filed under a=$ds_a b=$ds_b (want 1 and 1) — a row under only one of them leaves the other reading clean on the finding it is half of"
  fi

  # CONTROL — a single-claimant anchor. Without this the check could be counting every
  # anchor as its own duplicate and both assertions above would still be green.
  if grep -qx OVERRIDE-DOUBLE-SHADOW <<<"$(st_of 'SKILL__Rule-13-survives\.md$')"; then
    bad "a single-claimant anchor was reported as a double shadow — the key is collapsing entries that do not collide"
  else
    ok "  and an anchor only one entry claims stays silent"
  fi

  # Report-only, and the reason is on the record: the one live instance is DELIBERATE and
  # says so in prose. An ERROR would fire on a case the consumer already reasoned about.
  if grep -qE 'LOOSE-ANCHOR|DOUBLE-SHADOW' <<<"$(printf '%s\n' "$ld_out" | awk -F'\t' '$1 ~ /^HARD-/{print $1}')"; then
    bad "a new pull-time status carries a HARD- prefix — it would block apply on a report-only finding"
  else
    ok "  and both new statuses are report-only, never blockers"
  fi

  # --- MUTANTS: the two discriminators this predicate was MEASURED into ----------------
  # Both are the difference between a shippable check and the 5-of-13 keyword scan that was
  # rejected. Each is a COPY guarded by `cmp -s`, asserts a POSITIVE outcome, and is aimed
  # so that exactly one seeded entry changes verdict -- the others are the proof of that.
  MUTD="$ROOT/mut"; rm -rf "$MUTD"; mkdir -p "$MUTD"
  cp "$(dirname "$DRIFT")"/*.sh "$MUTD/" 2>/dev/null || true

  # THE UNMUTATED CONTROL. Both mutants are copies into a fresh directory; a copy that
  # cannot source lib.sh emits nothing, and "no rows" would otherwise score as a kill for
  # both mutations below.
  cp "$DRIFT" "$MUTD/layer-drift.sh"
  ctl_n="$(bash "$MUTD/layer-drift.sh" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>/dev/null \
           | awk -F'\t' '$1=="OVERRIDE-ASSERTS-SHADOW-SURVIVES"{c++} END{print c+0}')"
  if [ "$ctl_n" -eq 2 ]; then
    ok "  mutation control: an unmutated copy still reports both seeded claims"
  else
    bad "  mutation control: unmutated copy reported $ctl_n of 2 — a copy that cannot run scores as a kill"
  fi

  # The same control for the two new statuses. The mutants below assert an ABSENCE, and a
  # copy that cannot run produces the same absence.
  ctl_l="$(bash "$MUTD/layer-drift.sh" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>/dev/null \
           | awk -F'\t' '$1=="OVERRIDE-LOOSE-ANCHOR"{c++} END{print c+0}')"
  ctl_d="$(bash "$MUTD/layer-drift.sh" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>/dev/null \
           | awk -F'\t' '$1=="OVERRIDE-DOUBLE-SHADOW"{c++} END{print c+0}')"
  if [ "$ctl_l" -eq 1 ] && [ "$ctl_d" -eq 2 ]; then
    ok "  mutation control: and the same copy reports 1 loose anchor and 2 double-shadow rows"
  else
    bad "  mutation control: unmutated copy reported loose=$ctl_l (want 1) double=$ctl_d (want 2)"
  fi

  # MUTANT 1 — drop the flattening. The wrapped entry must go silent and the single-line
  # entry must NOT, or the two are entangled and the wrap assertion proves nothing.
  sed "s@| tr '\\\\n' ' ' | tr -s ' ' \\\\@| tr -s ' ' \\\\@" "$DRIFT" > "$MUTD/layer-drift.sh"
  if cmp -s "$DRIFT" "$MUTD/layer-drift.sh"; then
    bad "  mutation flatten: the mutation matched nothing, so the flattening assertion is unproven"
  else
    m1="$(bash "$MUTD/layer-drift.sh" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>/dev/null)"
    m1w="$(printf '%s\n' "$m1" | awk -F'\t' '$1=="OVERRIDE-ASSERTS-SHADOW-SURVIVES" && $2 ~ /Rule-16-wrapped/{c++} END{print c+0}')"
    m1s="$(printf '%s\n' "$m1" | awk -F'\t' '$1=="OVERRIDE-ASSERTS-SHADOW-SURVIVES" && $2 ~ /Rule-13-survives/{c++} END{print c+0}')"
    if [ "$m1w" -eq 0 ] && [ "$m1s" -eq 1 ]; then
      ok "  mutation flatten: without it the WRAPPED claim vanishes and the single-line one does not"
    else
      bad "  mutation flatten: wrapped=$m1w (want 0) single-line=$m1s (want 1) — the flattening assertion is vacuous or the two entries are entangled"
    fi
  fi

  # MUTANT 2 — widen the noun set to include `file`. The legitimate rest-of-the-FILE claim
  # must start firing, and the two real claims must keep firing. This is the 3-of-5
  # false-positive set returning, and it is the only assertion that can catch it.
  sed 's@(section|check|rule|clause)@(section|check|rule|clause|file)@' "$DRIFT" > "$MUTD/layer-drift.sh"
  if cmp -s "$DRIFT" "$MUTD/layer-drift.sh"; then
    bad "  mutation noun-set: the mutation matched nothing, so the noun restriction is unproven"
  else
    m2="$(bash "$MUTD/layer-drift.sh" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>/dev/null \
          | awk -F'\t' '$1=="OVERRIDE-ASSERTS-SHADOW-SURVIVES"{print $2}')"
    if grep -q 'Rule-14-file-claim' <<<"$m2"; then
      ok "  mutation noun-set: widening it to \`file\` re-fires the true claim — the restriction is load-bearing"
    else
      bad "  mutation noun-set: the honest rest-of-the-FILE claim stayed silent even with \`file\` in the noun set, so the control above is vacuous"
    fi
  fi

  # MUTANT 3 — delete the REVERSE arm, which is the whole loose-anchor predicate. The loose
  # row must vanish and the double-shadow rows must NOT: they are computed from a different
  # accumulator and a mutant that took both would prove neither.
  awk '!/^      REVERSE:\*\) loose=/' "$DRIFT" > "$MUTD/layer-drift.sh"
  if cmp -s "$DRIFT" "$MUTD/layer-drift.sh"; then
    bad "  mutation loose-arm: the mutation matched nothing, so the loose-anchor assertion is unproven"
  else
    m3="$(bash "$MUTD/layer-drift.sh" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>/dev/null)"
    m3l="$(printf '%s\n' "$m3" | awk -F'\t' '$1=="OVERRIDE-LOOSE-ANCHOR"{c++} END{print c+0}')"
    m3d="$(printf '%s\n' "$m3" | awk -F'\t' '$1=="OVERRIDE-DOUBLE-SHADOW"{c++} END{print c+0}')"
    if [ "$m3l" -eq 0 ] && [ "$m3d" -eq 2 ]; then
      ok "  mutation loose-arm: without the REVERSE arm the loose anchor goes silent, and only that"
    else
      bad "  mutation loose-arm: loose=$m3l (want 0) double=$m3d (want 2) — the assertion is vacuous or the two statuses are entangled"
    fi
  fi

  # MUTANT 4 — require THREE claimants instead of two, which is the off-by-one a duplicate
  # check is most likely to ship with. The double-shadow rows must vanish and the loose row
  # must not.
  sed 's/if (n\[key\] > 1)/if (n[key] > 2)/' "$DRIFT" > "$MUTD/layer-drift.sh"
  if cmp -s "$DRIFT" "$MUTD/layer-drift.sh"; then
    bad "  mutation dup-threshold: the mutation matched nothing, so the double-shadow assertion is unproven"
  else
    m4="$(bash "$MUTD/layer-drift.sh" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>/dev/null)"
    m4d="$(printf '%s\n' "$m4" | awk -F'\t' '$1=="OVERRIDE-DOUBLE-SHADOW"{c++} END{print c+0}')"
    m4l="$(printf '%s\n' "$m4" | awk -F'\t' '$1=="OVERRIDE-LOOSE-ANCHOR"{c++} END{print c+0}')"
    if [ "$m4d" -eq 0 ] && [ "$m4l" -eq 1 ]; then
      ok "  mutation dup-threshold: raising the duplicate threshold silences the pair, and only that"
    else
      bad "  mutation dup-threshold: double=$m4d (want 0) loose=$m4l (want 1) — the assertion is vacuous or the two statuses are entangled"
    fi
  fi

  # MUTANT 5 — silence the unclaimed arm by resolving NO span. Two of the three LC-O16
  # assertions are ABSENCE-shaped and would pass against a subject that emits nothing, which
  # is the exact shape a near-miss cannot distinguish. The PRESENCE arm must die here and
  # only it; the positive conjunct is a baseline row that must survive, so a mutant that
  # broke the whole script cannot score this as a kill.
  sed 's|_sp="$(span_of "$_id" < "$_b")"|_sp=""|' "$DRIFT" > "$MUTD/layer-drift.sh"
  if cmp -s "$DRIFT" "$MUTD/layer-drift.sh"; then
    bad "  mutation unclaimed-silence: the mutation matched nothing, so the unclaimed presence assertion is unproven"
  else
    m5="$(bash "$MUTD/layer-drift.sh" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>/dev/null)"
    m5u="$(printf '%s\n' "$m5" | awk -F'\t' '$1=="OVERRIDE-BODY-UNCLAIMED"{c++} END{print c+0}')"
    m5d="$(printf '%s\n' "$m5" | awk -F'\t' '$1=="OVERRIDE-DOUBLE-SHADOW"{c++} END{print c+0}')"
    if [ "$m5u" -eq 0 ] && [ "$m5d" -eq 2 ]; then
      ok "  mutation unclaimed-silence: with no span resolved the unclaimed row vanishes, and only that"
    else
      bad "  mutation unclaimed-silence: unclaimed=$m5u (want 0) double=$m5d (want 2) — the presence assertion is vacuous, or the script died and silence scored as a kill"
    fi
  fi

  # MUTANT 6 — WIDEN instead of silence, because the two narrowings are what make this arm
  # something other than a heading counter, and only a widening mutant can prove them. BOTH
  # layers come out together: dropping either one alone changes nothing on this seed, which
  # is a partial revert proving the layer left in place. The NESTED entry must now be
  # reported, and the single-anchor entry must still not be -- it resolves no span either way.
  sed -e '/if (covered) next/d' \
      -e 's/if (olvl\[i\] in claimed) print otxt\[i\]/print otxt[i]/' "$DRIFT" > "$MUTD/layer-drift.sh"
  if cmp -s "$DRIFT" "$MUTD/layer-drift.sh"; then
    bad "  mutation unclaimed-widen: the mutation matched nothing, so the two narrowings are unproven"
  else
    m6="$(bash "$MUTD/layer-drift.sh" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>/dev/null)"
    m6n="$(printf '%s\n' "$m6" | awk -F'\t' '$1=="OVERRIDE-BODY-UNCLAIMED" && $2 ~ /Rule-19-nested/{c++} END{print c+0}')"
    m6s="$(printf '%s\n' "$m6" | awk -F'\t' '$1=="OVERRIDE-BODY-UNCLAIMED" && $2 ~ /Rule-13-survives/{c++} END{print c+0}')"
    if [ "$m6n" -eq 1 ] && [ "$m6s" -eq 0 ]; then
      ok "  mutation unclaimed-widen: without the span and level narrowings the NESTED child is reported — both are load-bearing"
    else
      bad "  mutation unclaimed-widen: nested=$m6n (want 1) single-anchor=$m6s (want 0) — the near-miss assertion is vacuous, or the widening reached an entry it should not"
    fi
  fi
fi

# --- OVERRIDE-SUPERSEDED: core declaring an entry is no longer NEEDED ------------------
#
# Every other status asks whether the override is still CORRECT. This one asks whether it
# is still needed, and it is the only status whose answer is "delete this entry". Without
# it a superseded override presents as ordinary section drift -- which reads as "re-adopt
# the new wording", not "you can retire this" -- so the entry survives and goes on freezing
# every unrelated line in its shadowed span at base_sha. That is how a real core fix failed
# to reach the reference consumer.
if [ -z "$DRIFT" ]; then
  bad "FIXTURE BROKEN — no layer-drift.sh; the supersession arm would pass by not running"
else
  mkdir -p "$DIST/core/skills/ai-dlc"

  # A CORE FILE THE SURPLUS ARMS CAN BE MEASURED AGAINST, committed BEFORE the declaration so an
  # entry can carry it as its own `base_sha`. Every other SUP__ entry below shadows a file that
  # does not exist in this seed at all — which is the UNMEASURABLE case, asserted in its own right
  # further down. Without this commit the surplus arms would only ever exercise that branch, and a
  # measurement that never runs reports the same silence as one that found nothing.
  #
  # `### 3. Widget schema.` is FIVE non-blank lines including its heading. The two entries seeded
  # against it differ by exactly three lines, so the expected numbers below are seeded rather than
  # recomputed — a fixture that re-derives the answer with the same expression it is testing
  # agrees with itself.
  mkdir -p "$DIST/core/skills/ai-dlc/steps"
  cat > "$DIST/core/skills/ai-dlc/steps/widget.md" <<'WIDGET'
# Widget

### 3. Widget schema.

Core line one.
Core line two.
Core line three.

### 4. Other section.

Untouched.
WIDGET
  git -C "$DIST" add -A >/dev/null 2>&1
  git -C "$DIST" -c user.email=f@x -c user.name=f commit -qm "core carries the widget schema" >/dev/null 2>&1
  WBASE="$(git -C "$DIST" rev-parse --short HEAD)"

  cat > "$DIST/core/skills/ai-dlc/layer-contract.yaml" <<'YML'
contract_version: 13
override_supersessions:
  - shadows: steps/widget.md#3. Widget schema.
    since_core_version: "9.9.9"
    replaces_with:
      settings_env_key: AI_DLC_WIDGET_EXTRA
  - shadows: steps/widget.md#5. Adopted section.
    since_core_version: "9.9.9"
    reason: core took this entry's paragraph verbatim; there is nothing to configure.
  - shadows: steps/widget.md#6. Two-key section.
    since_core_version: "9.9.9"
    replaces_with:
      settings_env_keys:
        - AI_DLC_WIDGET_ALPHA
        - AI_DLC_WIDGET_BETA
absorbed_from:
  - path: core/skills/ai-dlc/extensions/README.md
YML
  git -C "$DIST" add -A >/dev/null 2>&1
  git -C "$DIST" -c user.email=f@x -c user.name=f commit -qm "declare a supersession" >/dev/null 2>&1
  THEIRS2="$(git -C "$DIST" rev-parse --short HEAD)"

  # The MATCH and its CONTROL differ in one field: the anchor. Same file, same shape, same
  # base_sha -- so an arm that fires on both is matching "is an override", not "is superseded".
  #
  # SUP__multi and SUP__multictl are the MULTI-ANCHOR pair, and they are the case the join was
  # blind to. The declared anchor is deliberately FIRST in SUP__multi's list -- see the mutant
  # below, which keeps only the LAST part and must therefore silence THIS entry while leaving
  # single-anchor SUP__match firing. Their own difference is one anchor: SUP__multictl bundles
  # two anchors core declares nothing about, so an arm that fires on it is matching "shadows more
  # than one thing", not "shadows something core superseded".
  for pair in "SUP__match:steps/widget.md#3. Widget schema." "SUP__control:steps/widget.md#4. Other section." "SUP__adopted:steps/widget.md#5. Adopted section." "SUP__twokey:steps/widget.md#6. Two-key section." "SUP__multi:steps/widget.md#3. Widget schema., #4. Other section." "SUP__multictl:steps/widget.md#4. Other section., #7. Also undeclared."; do
    nm="${pair%%:*}"; sh_v="${pair#*:}"
    cat > "$CONS/.claude/skills/ai-dlc/overrides/${nm}.md" <<EOF
---
shadows: ${sh_v}
base_sha: ${BASE}
reason: fixture entry
conforms_to: 13
---

# body
EOF
  done

  # THE TWO SURPLUS ENTRIES. Same anchor, same base_sha, same declaration — they differ ONLY in
  # whether the shadowed span carries lines core does not have. That is what makes the pair a
  # test of the measurement rather than of the entry's size.
  cat > "$CONS/.claude/skills/ai-dlc/overrides/SUP__surplus.md" <<EOF
---
shadows: steps/widget.md#3. Widget schema.
base_sha: ${WBASE}
reason: fixture entry carrying three lines core does not have
conforms_to: 13
---

### 3. Widget schema.

Core line one.
Core line two.
Core line three.
Consumer surplus A.
Consumer surplus B.
Consumer surplus C.
EOF
  cat > "$CONS/.claude/skills/ai-dlc/overrides/SUP__nosurplus.md" <<EOF
---
shadows: steps/widget.md#3. Widget schema.
base_sha: ${WBASE}
reason: fixture entry whose span is byte-identical to core's
conforms_to: 13
---

### 3. Widget schema.

Core line one.
Core line two.
Core line three.
EOF

  sup_out="$(bash "$DRIFT" "$DIST" "$BASE" "$THEIRS2" "$CONS" 2>&1)"
  sup_st() { printf '%s\n' "$sup_out" | awk -F'\t' -v e="$1" '$2 ~ e {print $1}'; }

  if grep -qx OVERRIDE-SUPERSEDED <<<"$(sup_st 'SUP__match\.md$')"; then
    ok "an override core declares SUPERSEDED is reported as retirable"
  else
    bad "a superseded override was not reported — it survives the pull and keeps freezing its shadowed span"
  fi

  if grep -qx OVERRIDE-SUPERSEDED <<<"$(sup_st 'SUP__control\.md$')"; then
    bad "CONTROL: an override on a DIFFERENT anchor was reported superseded — the arm matches any override"
  else
    ok "  and an override on an undeclared anchor stays silent"
  fi

  # THE TOKEN CONTRACT WITH apply.sh, which is where this can rot silently. apply.sh reads
  # `replaces_with=<KEY> ::` off the front of the detail to expand ONE superseded row into an
  # ORDERED, ATOMIC two-step worklist. If this prefix ever changes, apply falls back to a
  # single unordered row -- still green, still emitted, and the ordering constraint that keeps
  # a retire from re-imposing the core rule before its replacement is written is simply gone.
  # A degradation that keeps passing is the shape this repo names; assert the join, not the row.
  sup_detail="$(printf '%s\n' "$sup_out" | awk -F'\t' '$1=="OVERRIDE-SUPERSEDED" && $2 ~ /SUP__match\.md$/ {print $4}')"
  case "$sup_detail" in
    "replaces_with=AI_DLC_WIDGET_EXTRA ::"*)
      ok "  the detail leads with the replaces_with= token apply.sh parses, carrying the declared key" ;;
    *)
      bad "the replaces_with= token is missing or malformed -- apply.sh silently drops to a single unordered row: ${sup_detail:0:60}" ;;
  esac

  # NON-VACUITY. The two assertions above are both satisfied by a run that emitted nothing
  # at all for the control and something for the match; assert the run itself is alive.
  if [ "$(printf '%s\n' "$sup_out" | grep -c 'SUP__control')" -ge 1 ]; then
    ok "  CONTROL is present in the output under some other status (so its silence above is a real zero)"
  else
    bad "the control entry produced NO row at all — its silence proves nothing"
  fi

  # A SUPERSESSION NEEDS NO CONFIGURATION TO BE ONE.
  #
  # Core stops needing an override two ways: it turns a hardcoded set into an AI_DLC_* key
  # the consumer declares its value in (the row above), or it simply ADOPTS the entry's
  # prose, where there is no key because there is nothing to configure. The emission used to
  # be gated on `settings_env_key`, so the second kind could be authored in the contract and
  # would silently never fire — a declaration with no reader, which is the cannot-fire class
  # arriving through the data side where I36 does not look. Measured on the reference
  # consumer: three of eleven overrides retire by adoption, none by configuration.
  if grep -qx OVERRIDE-SUPERSEDED <<<"$(sup_st 'SUP__adopted\.md$')"; then
    ok "  a supersession declaring NO settings_env_key still fires (core adopted the prose)"
  else
    bad "an env-keyless supersession was not reported — the cheapest retirement class is undeclarable, and the contract row that declares it has no reader"
  fi

  # THE OTHER HALF OF THE apply.sh TOKEN CONTRACT. apply.sh strips a leading
  # `replaces_with=<KEY> ::` and, finding none, emits the SINGLE worklist row. If the
  # env-less detail carried the token with an empty key, apply would instead emit
  # "1/2 ATOMIC — write  into .claude/settings.json" and hand the operator an instruction
  # naming nothing. Assert the absence, because that failure is green on every other check.
  sup_adopted="$(printf '%s\n' "$sup_out" | awk -F'\t' '$1=="OVERRIDE-SUPERSEDED" && $2 ~ /SUP__adopted\.md$/ {print $4}')"
  case "$sup_adopted" in
    replaces_with=*) bad "the env-keyless detail leads with replaces_with= anyway — apply.sh will emit a 1/2 ATOMIC row telling the operator to write an empty key: ${sup_adopted:0:70}" ;;
    "")              bad "the env-keyless supersession produced an empty detail" ;;
    *)               ok "  and its detail omits the replaces_with= token, so apply.sh renders the single retire row" ;;
  esac

  # A SUPERSESSION MAY NEED MORE THAN ONE KEY, AND ONE PER ROW WAS NEVER A DECISION.
  # It was the only shape anyone had needed, so a retirement requiring two keys could not
  # be expressed at all and the entry stayed shadowed over a mechanism gap rather than over
  # a disagreement. The list form joins on a comma into the same field the single form
  # fills, and apply.sh splits it into N+1 ATOMIC rows.
  sup_twokey="$(printf '%s\n' "$sup_out" | awk -F'\t' '$1=="OVERRIDE-SUPERSEDED" && $2 ~ /SUP__twokey\.md$/ {print $4}')"
  case "$sup_twokey" in
    "replaces_with=AI_DLC_WIDGET_ALPHA,AI_DLC_WIDGET_BETA ::"*)
      ok "  a settings_env_keys: LIST carries BOTH keys, comma-joined, in the token apply.sh parses" ;;
    "") bad "the two-key supersession produced no detail at all" ;;
    *)  bad "the settings_env_keys: list did not render both keys in order: ${sup_twokey:0:80}" ;;
  esac

  # THE LIST MUST NOT BLEED. Its items begin with a dash, exactly like the rows of the
  # block itself, so a loose item pattern would swallow the next `- shadows:` and attribute
  # one entry's keys to another. The single-key row that follows it in the contract is the
  # control: if it still carries exactly its own key, the list terminated where it should.
  sup_still="$(printf '%s\n' "$sup_out" | awk -F'\t' '$1=="OVERRIDE-SUPERSEDED" && $2 ~ /SUP__match\.md$/ {print $4}')"
  case "$sup_still" in
    "replaces_with=AI_DLC_WIDGET_EXTRA ::"*)
      ok "  and the neighbouring single-key row still carries exactly its own key (the list did not bleed)" ;;
    *)  bad "the single-key row was contaminated by the list above it: ${sup_still:0:80}" ;;
  esac

  # --- THE SURPLUS THE REMEDY DROPS IS STATED AS A NUMBER --------------------------------
  #
  # THE REPORT BEHIND THIS. The consumer was told to narrow `shadows:` because core superseded
  # ONE ARM of an anchor, while their span under it carried 119 lines core does not have. The row
  # already warned, in prose, that narrowing "releases every unrelated line that anchor's span
  # froze at base_sha" — and an unquantified warning beside a concrete instruction reads as
  # boilerplate. The obvious remedy is to declare the ARM, and an arm is NOT ADDRESSABLE:
  # `override_supersessions` keys on `<file>#<anchor>` with no span vocabulary, the real case's
  # 231-line span carries exactly one sub-heading with the superseded machinery on BOTH sides of
  # it, and the other superseded arm is not in the shadowed file at all. So the row states the
  # size of what the operator is about to drop, which needs no new declaration.
  sup_surp="$(printf '%s\n' "$sup_out" | awk -F'\t' '$1=="OVERRIDE-SUPERSEDED" && $2 ~ /SUP__surplus\.md$/ {print $4}')"
  case "$sup_surp" in
    *"against core's 4 at ${WBASE}, and 3 of yours appear nowhere in core's"*)
      ok "the row MEASURES the surplus: 3 consumer-only line(s) against core's span at ${WBASE} — the operator is told the size of what narrowing drops" ;;
    "") bad "the surplus entry produced no OVERRIDE-SUPERSEDED detail at all, so this arm asserts nothing" ;;
    *"could NOT be measured"*)
      bad "the surplus went UNMEASURABLE on an entry whose span and core span both exist. Either the anchor is not resolving in one of the two, or base_sha is not being read — and the fallback sentence then hides it behind honest-sounding prose: ${sup_surp:0:200}" ;;
    *)  bad "the surplus was measured wrongly (want 3 consumer-only against core's 4): $(printf %s "$sup_surp" | grep -oE 'MEASURED:.*' | head -1 || echo "<no MEASURED clause in the detail at all>")" ;;
  esac

  # THE CONTROL, and it is what stops the arm being "print the entry's size". Same anchor, same
  # base_sha, same declaration; the only difference is that this span carries nothing core lacks.
  sup_nosurp="$(printf '%s\n' "$sup_out" | awk -F'\t' '$1=="OVERRIDE-SUPERSEDED" && $2 ~ /SUP__nosurplus\.md$/ {print $4}')"
  case "$sup_nosurp" in
    *"and 0 of yours appear nowhere in core's"*)
      ok "  CONTROL: an identical span reports 0 consumer-only lines — the number is a comparison, not the entry's length" ;;
    "") bad "the no-surplus control produced no detail at all, so the assertion above is unpaired" ;;
    *)  bad "CONTROL: a span byte-identical to core's did not report 0 consumer-only lines: ${sup_nosurp:0:220}" ;;
  esac

  # UNMEASURABLE IS SAID OUT LOUD. SUP__match shadows a section its own body does not contain, so
  # neither span resolves. The clause must SAY that rather than fall back to the qualitative
  # sentence alone — a warning that quietly loses its number reads exactly like one that never had
  # a subject, which is the defect class this whole arm belongs to.
  case "$sup_still" in
    *"could NOT be measured"*)
      ok "  an entry whose span does not resolve says so in the row, instead of dropping silently to prose" ;;
    *"appear nowhere in core's"*)
      bad "an entry with no resolvable span reported a MEASUREMENT anyway, so the numbers in the two assertions above cannot be trusted: ${sup_still:0:200}" ;;
    *)  bad "an entry whose span does not resolve carries neither a measurement nor the unmeasurable notice: ${sup_still:0:200}" ;;
  esac

  # MUTATION — drop the comparison and count the whole span. The surplus entry still looks right
  # (8 lines, and 8 would be reported), so ONLY the control can see this; that is why it is paired.
  MUTS="$ROOT/drift-mutant-surplus"; rm -rf "$MUTS"; mkdir -p "$MUTS"
  cp "$(dirname "$DRIFT")"/* "$MUTS"/ 2>/dev/null
  sed 's/| grep -Fxv -f <(printf .%s\\n. "\$cs") | grep -c \./| grep -c ./' "$DRIFT" > "$MUTS/layer-drift.sh"
  if cmp -s "$DRIFT" "$MUTS/layer-drift.sh"; then
    bad "  mutation surplus-comparison: the mutation matched nothing, so the control above proves nothing"
  else
    ms="$(bash "$MUTS/layer-drift.sh" "$DIST" "$BASE" "$THEIRS2" "$CONS" 2>/dev/null \
          | awk -F'\t' '$1=="OVERRIDE-SUPERSEDED" && $2 ~ /SUP__nosurplus\.md$/ {print $4}')"
    if [ -z "$ms" ]; then
      bad "  mutation surplus-comparison: the mutant emitted no row for the control, so it broke the arm rather than the comparison"
    elif grep -qF "and 0 of yours appear nowhere" <<<"$ms"; then
      bad "  mutation surplus-comparison: counting the WHOLE span still reported 0 consumer-only lines — the control is not reading the number it claims to"
    else
      ok "  MUTATION: without the comparison the identical span reports a non-zero surplus, so the control is load-bearing"
    fi
  fi

  # --- A MULTI-ANCHOR OVERRIDE IS THE CASE THIS ARM WAS BLIND TO ------------------------------
  #
  # The join compared `norm` of the WHOLE `shadows:` value against `norm` of the declaration's,
  # so an entry bundling several anchors could never match a declaration naming ONE of them --
  # and the more anchors an entry bundles the more unrelated core text it freezes, which is
  # exactly the entry a retirement signal exists for. Measured on the reference consumer at
  # 0.310.0 and it was a LIVE miss: `overrides/steps__retro__domain-sections.md` shadows four
  # retro anchors, one of which core declared superseded at 0.281.0. Whole-string join on the
  # real tree over the real pull range: 0 rows. Same tree, that anchor alone in `shadows:`: 1.
  if grep -qx OVERRIDE-SUPERSEDED <<<"$(sup_st 'SUP__multi\.md$')"; then
    ok "a MULTI-anchor override is reported when core supersedes ONE of its anchors"
  else
    bad "a multi-anchor override naming a declared supersession went unreported — the join reads the whole shadows: string, so the entries that freeze the most core text are the ones it cannot see"
  fi

  if grep -qx OVERRIDE-SUPERSEDED <<<"$(sup_st 'SUP__multictl\.md$')"; then
    bad "CONTROL: a multi-anchor override with NO declared anchor was reported — the arm is matching 'shadows more than one thing', not 'shadows something superseded'"
  else
    ok "  and a multi-anchor override with no declared anchor stays silent"
  fi

  # NON-VACUITY for that control, same reasoning as SUP__control's above.
  if [ "$(printf '%s\n' "$sup_out" | grep -c 'SUP__multictl')" -ge 1 ]; then
    ok "  CONTROL is present under some other status (so its silence is a real zero)"
  else
    bad "the multi-anchor control produced NO row at all — its silence proves nothing"
  fi

  # THE REMEDY IS NOT THE SAME REMEDY, AND SAYING SO IS THE POINT OF THE TOKEN.
  # `readopt-override.sh --stamp retire` DELETES THE FILE; there is no per-anchor retire. On a
  # multi-anchor entry that discards the anchors core has NOT superseded, and every section they
  # shadowed silently reverts to core. apply.sh renders the last worklist row off `retire_anchor=`
  # (asserted end to end in apply-worklist-rows), so a lost token is a row telling the operator
  # to delete an entry core asked them to narrow.
  sup_multi="$(printf '%s\n' "$sup_out" | awk -F'\t' '$1=="OVERRIDE-SUPERSEDED" && $2 ~ /SUP__multi\.md$/ {print $4}')"
  case "$sup_multi" in
    "replaces_with=AI_DLC_WIDGET_EXTRA :: retire_anchor=steps/widget.md#3. Widget schema. ::"*)
      ok "  its detail carries retire_anchor= after replaces_with=, naming the entry's OWN spelling of the superseded anchor" ;;
    *retire_anchor=*)
      bad "the retire_anchor= token is present but not in the ordered prefix apply.sh parses: ${sup_multi:0:100}" ;;
    *)
      bad "the multi-anchor detail carries NO retire_anchor= token, so apply.sh renders '--stamp retire' and tells the operator to delete an entry core asked them to narrow: ${sup_multi:0:100}" ;;
  esac

  # AND THE SINGLE-ANCHOR DETAIL MUST NOT GAIN THE TOKEN. For a one-anchor entry deleting the
  # file really IS the remedy, and a token there would turn the correct instruction into
  # "remove the only anchor", leaving an override that shadows nothing.
  case "$sup_still" in
    *retire_anchor=*) bad "the SINGLE-anchor detail gained a retire_anchor= token — apply.sh would tell the operator to strip the entry's only anchor instead of retiring it" ;;
    *)                ok "  and the single-anchor detail is unchanged: no token, so its remedy is still the retire stamp" ;;
  esac

  # --- MUTANT: the entry side back to ONE part ------------------------------------------------
  # A COPY of the whole reconcile directory (layer-drift sources lib.sh from beside it, and a
  # lone script copy dies before printing anything), `cmp -s`-guarded so a sed that matched
  # nothing cannot pass as a mutation. Dropping the accumulator keeps only the LAST harvested
  # part, and SUP__multi lists its declared anchor FIRST — so this mutant must silence SUP__multi
  # while leaving single-anchor SUP__match firing. Two verdicts from one mutant, and they are the
  # disentanglement: a mutation that killed both would be testing "the arm runs", not the join.
  SMUT="$ROOT/supmut"; rm -rf "$SMUT"; mkdir -p "$SMUT"
  cp "$(dirname "$DRIFT")"/*.sh "$SMUT/" 2>/dev/null || true
  cp "$DRIFT" "$SMUT/layer-drift.sh"
  sctl="$(bash "$SMUT/layer-drift.sh" "$DIST" "$BASE" "$THEIRS2" "$CONS" 2>/dev/null | awk -F'\t' '$1=="OVERRIDE-SUPERSEDED"' | wc -l | tr -d ' ')"
  if [ "$sctl" -ge 2 ]; then
    ok "CONTROL: an unmutated copy in a fresh directory still reports both the single- and multi-anchor entries ($sctl rows)"
  else
    bad "CONTROL: the unmutated copy reported $sctl supersession row(s) — the mutant verdict below would be unreadable"
  fi

  sed 's@^    ent_keys="\${ent_keys}\$(norm @    ent_keys="$(norm @' "$DRIFT" > "$SMUT/layer-drift.sh"
  if cmp -s "$DRIFT" "$SMUT/layer-drift.sh"; then
    bad "the multi-anchor MUTANT did not apply — the ent_keys accumulator has been respelled, so it proves nothing"
  else
    smut_out="$(bash "$SMUT/layer-drift.sh" "$DIST" "$BASE" "$THEIRS2" "$CONS" 2>/dev/null)"
    smut_st() { printf '%s\n' "$smut_out" | awk -F'\t' -v e="$1" '$2 ~ e {print $1}'; }
    if grep -qx OVERRIDE-SUPERSEDED <<<"$(smut_st 'SUP__multi\.md$')"; then
      bad "MUTANT SURVIVED: SUP__multi is still reported with only its last anchor harvested, so the multi-anchor assertion is not testing the per-part join"
    else
      ok "MUTANT (entry side keeps one part): the multi-anchor entry goes silent — the accumulation is what makes every anchor joinable"
    fi
    if grep -qx OVERRIDE-SUPERSEDED <<<"$(smut_st 'SUP__match\.md$')"; then
      ok "  and the single-anchor entry still fires under it — the two arms are not entangled"
    else
      bad "  the mutant also silenced the single-anchor entry: it is testing whether the arm RUNS, not how it joins"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# G / H. THE OTHER DIRECTION OF THE SET DIFFERENCE, AND THE WRAP.
# ---------------------------------------------------------------------------
# Arms A-C test SUPERSEDED text: a line core DROPPED that the body still carries.
# That is one half of a two-sided question and shipping only it made the COMMONEST
# upstream change invisible — a purely ADDITIVE edit removes nothing, so the stale
# set is empty by construction, `--check` printed OK, and `--stamp readopt` then
# advanced base_sha, after which the next pull computes no drift on that section and
# never offers the new text again. Measured on the reference consumer's own
# `steps__retro__domain-sections.md` across `a5cbdf0b -> 95670e58`: the shipping gate
# exited 0 while five lines of core's rewritten `#4a. Close-Out Sweep` were absent
# from the body.
#
# THE TWO NEW GUARDS GET SUBJECTS THE OTHER CANNOT SEE. G's core change is a pure
# ADDITION (nothing deleted, so the stale arm has no input at all); H's is a pure
# DELETION (nothing added, so the unadopted arm has none). An arm that fired on both
# subjects would be reporting "this section moved", which every override in this
# fixture would trip.
G3="$ROOT/g3"; rm -rf "$G3"; mkdir -p "$G3"
GPRE="$(git -C "$DIST" rev-parse --short HEAD)"
python3 - "$DIST/core/skills/ai-dlc/SKILL.md" <<'GPY'
import sys
p = sys.argv[1]; s = open(p).read()
# PURE ADDITION to Rule 7 -- nothing removed.
s = s.replace("""## Rule 7 -- Something Else

Untouched across the range. Present so the fixture proves the gate is
section-scoped and not merely file-scoped.
""", """## Rule 7 -- Something Else

Untouched across the range. Present so the fixture proves the gate is
section-scoped and not merely file-scoped.

**Every rule-7 adjudication now records the deciding session id**, and a record
that carries no session id is rejected at the gate rather than queued.
""")
# PURE DELETION from Rule 13 -- nothing added.
s = s.replace("""The adjudication order, the freeze semantics, and the record format live here, in the
paragraphs an override of this rule silently drops.
""", "")
open(p, "w").write(s)
GPY
git -C "$DIST" add -A >/dev/null 2>&1
git -C "$DIST" -c user.email=f@x -c user.name=f commit -qm "additive rule 7, deleted rule 13 paragraph" >/dev/null 2>&1
GTH="$(git -C "$DIST" rev-parse --short HEAD)"

GOVR="$CONS/.claude/skills/ai-dlc/overrides/G__additive.md"
cat > "$GOVR" <<EOF
---
shadows: SKILL.md#Rule 7
base_sha: ${GPRE}
reason: consumer keeps core's rule 7 and adds one project-specific sentence.
---

## Rule 7 -- Something Else

This consumer also records the adjudicating team, which core does not ask for.

Untouched across the range. Present so the fixture proves the gate is
section-scoped and not merely file-scoped.
EOF
cp "$GOVR" "$G3/additive.orig"
# THE CONSUMER DELTA SITS AT THE TOP OF THE BODY ON PURPOSE. Upstream's addition lands
# at the END of the section, and a three-way merge of two edits to adjacent lines is a
# CONFLICT -- which the stamp then refuses on its markers, so the satisfiability arm
# below would be asserting the conflict path rather than the clean one and would pass
# for the wrong reason.

# THE NEAR-MISS, IN THE SAME RUN. Same anchor, same base_sha, same upstream change --
# and this body DID adopt it, re-wrapped at a different column. A whole-line test calls
# that absent, so this entry is what separates "the body lacks upstream's text" from
# "the body does not match upstream's line breaks".
GOK="$CONS/.claude/skills/ai-dlc/overrides/G__adopted.md"
cat > "$GOK" <<EOF
---
shadows: SKILL.md#Rule 7
base_sha: ${GPRE}
reason: consumer adopted the new clause and re-wrapped it.
---

## Rule 7 -- Something Else

Untouched across the range. Present so the fixture proves the gate is
section-scoped and not merely file-scoped.

**Every rule-7 adjudication now records the deciding session id**, and a record that
carries no session id is rejected at the gate rather than queued.
EOF

HOVR="$CONS/.claude/skills/ai-dlc/overrides/H__rewrap.md"
cat > "$HOVR" <<EOF
---
shadows: SKILL.md#Rule 13
base_sha: ${GPRE}
reason: consumer escalation rules; still carries core's deleted sentence, re-wrapped.
---

## Rule 13 -- Escalation (CONSUMER OVERRIDE)

Escalate at three failures rather than two.

The adjudication order, the freeze semantics, and the record format live
here, in the paragraphs an override of this rule silently
drops.
EOF
# EVERY core line is BROKEN by this wrapping, and that is what makes the mutant below
# readable. Core's paragraph is two lines; if the body re-wrapped only the first, the
# second would survive whole inside one body line and a substring test would find it
# with the flattening removed -- the mutant would then survive an arm that is correct.

HOK="$CONS/.claude/skills/ai-dlc/overrides/H__clean.md"
cat > "$HOK" <<EOF
---
shadows: SKILL.md#Rule 13
base_sha: ${GPRE}
reason: consumer escalation rules, carrying none of core's superseded prose.
---

## Rule 13 -- Escalation (CONSUMER OVERRIDE)

Escalate at three failures rather than two. Nothing else from core's rule 13 is
reproduced here.
EOF

echo "== G. an ADDITIVE upstream change to a shadowed section is REPORTED =="
# THE TIER IS THE ASSERTION, and v0.476.0 got it wrong in the direction that loses data.
# This arm shipped as a REFUSAL and was demoted one release later: replayed over the 27
# re-adoptions in the reference consumer's own history, a refusing form refuses 7 of them,
# at least one demonstrably falsely -- a body that had ALREADY adopted upstream's addition,
# reworded. And the escape is worse than the wedge: `--stamp reaffirm --note` advances
# base_sha, so a falsely-refused re-adoption is re-stamped and the clause is never offered
# again, under a note asserting the consumer declined text it had in fact taken. So the arm
# must REPORT and must NOT refuse, and both halves are asserted here.
out="$(bash "$READOPT" "$DIST" "$GTH" "$CONS" "$GOVR" --check 2>&1)"; rc=$?
if grep -q 'UNADOPTED-CORE-TEXT' <<<"$out"; then
  ok "--check REPORTS: core ADDED text to the shadowed section and the body does not carry it"
else
  bad "--check did NOT report a purely additive upstream change (rc=$rc) -- the stale set is empty by construction, so this is the direction that reads as clean"
  printf '%s\n' "$out" | sed 's/^/    /'
fi
if [ "$rc" -eq 0 ]; then
  ok "  and it does NOT fail: a REWORDED adoption scores here too, and refusing on that routes a correct re-adoption to reaffirm"
else
  bad "  --check exited $rc on an unadopted-only finding: that is the tier v0.477.0 removed, and it converts a false positive into a permanent re-stamp"
fi
if grep -q 'records the deciding session id' <<<"$out"; then
  ok "  and it names the un-adopted sentence verbatim"
else
  bad "  it reported but did not identify the un-adopted line, so the operator cannot act on it"
fi

before_sha="$(sed -n 's/^base_sha:[[:space:]]*//p' "$GOVR" | head -1)"
out="$(bash "$READOPT" "$DIST" "$GTH" "$CONS" "$GOVR" --stamp readopt 2>&1)"; rc=$?
after_sha="$(sed -n 's/^base_sha:[[:space:]]*//p' "$GOVR" | head -1)"
if [ "$rc" -eq 0 ] && grep -q 'UNADOPTED-CORE-TEXT' <<<"$out"; then
  ok "--stamp readopt LANDS and says what was not adopted -- the operator decides, having been told"
else
  bad "--stamp readopt exited $rc or said nothing about the unadopted lines: either it refuses (v0.476.0's defect) or it is silent (the defect that release fixed)"
  printf '%s\n' "$out" | sed 's/^/    /'
fi
# THE VALUE, NOT THE EXIT CODE. An arm reading only the exit code passes against an
# implementation that reports and does NOT stamp, and against one that stamps silently.
if [ "$after_sha" = "$GTH" ] && [ "$before_sha" != "$after_sha" ]; then
  ok "  and base_sha advanced $before_sha -> $after_sha, so the stamp is a real one"
else
  bad "  base_sha is $after_sha (was $before_sha, theirs is $GTH): the stamp did not land"
fi

gok_out="$(bash "$READOPT" "$DIST" "$GTH" "$CONS" "$GOK" --check 2>&1)"
if ! grep -q 'UNADOPTED-CORE-TEXT' <<<"$gok_out"; then
  ok "NEAR-MISS: a body that adopted the same addition RE-WRAPPED is not reported at all"
else
  bad "NEAR-MISS FAILED: a body carrying upstream's new text at a different column is reported as un-adopted -- the arm is testing line breaks, not content"
  printf '%s\n' "$gok_out" | sed 's/^/    /'
fi

# SATISFIABILITY. A gate that cannot be cleared by the remedy it prints is a wedge, and
# `--merge` is that remedy. Assert the whole round trip, ending in the stamp actually
# landing -- asserting only the refusal would pass against a guard that refuses always.
cp "$G3/additive.orig" "$GOVR"
bash "$READOPT" "$DIST" "$GTH" "$CONS" "$GOVR" --merge >/dev/null 2>&1
if bash "$READOPT" "$DIST" "$GTH" "$CONS" "$GOVR" --check >/dev/null 2>&1; then
  ok "  --merge clears it: the body carries the addition and --check goes green"
else
  bad "  --merge did NOT clear the new gate -- the remedy the message prints cannot satisfy it"
  bash "$READOPT" "$DIST" "$GTH" "$CONS" "$GOVR" --check 2>&1 | sed 's/^/    /'
fi
if bash "$READOPT" "$DIST" "$GTH" "$CONS" "$GOVR" --stamp readopt >/dev/null 2>&1 \
   && [ "$(sed -n 's/^base_sha:[[:space:]]*//p' "$GOVR" | head -1)" = "$GTH" ]; then
  ok "  and the stamp then LANDS, advancing base_sha to $GTH"
else
  bad "  the stamp still refused after a clean merge, or base_sha did not advance to $GTH"
fi

# THE FRONTMATTER IS NOT THE BODY. `reason:` is prose ABOUT the override, and the natural
# way to decline an upstream clause is to quote it there — so a containment test that reads
# the whole file scores the clause as ADOPTED on the entry that says, in as many words, that
# it did not adopt it. That is a false clean produced by the remedy text itself. Its ALLOW
# twin is the same clause in the body, in the same run: without that half this arm passes for
# an implementation that reads neither.
GFM="$CONS/.claude/skills/ai-dlc/overrides/G__reason-only.md"
cat > "$GFM" <<EOF
---
shadows: SKILL.md#Rule 7
base_sha: ${GPRE}
reason: consumer rule 7. Upstream now says **Every rule-7 adjudication now records the deciding session id**, and a record that carries no session id is rejected at the gate rather than queued. This consumer declines it.
---

## Rule 7 -- Something Else

This consumer also records the adjudicating team, which core does not ask for.

Untouched across the range. Present so the fixture proves the gate is
section-scoped and not merely file-scoped.
EOF
if grep -q 'UNADOPTED-CORE-TEXT' <<<"$(bash "$READOPT" "$DIST" "$GTH" "$CONS" "$GFM" --check 2>&1)"; then
  ok "  and core text quoted in \`reason:\` does NOT count as adoption: only the body the lead reads can carry it"
else
  bad "an entry carrying core's new clause only in its \`reason:\` — to say it DECLINES it — was scored as having adopted it, so the report is silenced by the sentence that says it was not"
fi

# THE SECOND PASTE TARGET, and the frontmatter fix left it open for a release. Upstream text
# dropped into an HTML comment INSIDE the body reaches no lead either, so it is not adoption.
# Its ALLOW twin is the same clause as real body prose, asserted in the near-miss above.
GHC="$CONS/.claude/skills/ai-dlc/overrides/G__comment-only.md"
{ cat "$G3/additive.orig"; printf '\n<!--\n**Every rule-7 adjudication now records the deciding session id**, and a record\nthat carries no session id is rejected at the gate rather than queued.\n-->\n'; } > "$GHC"
if grep -q 'UNADOPTED-CORE-TEXT' <<<"$(bash "$READOPT" "$DIST" "$GTH" "$CONS" "$GHC" --check 2>&1)"; then
  ok "  and core text pasted into an HTML COMMENT in the body does not count either"
else
  bad "core text inside <!-- --> scored as adoption -- the report prints the offending lines verbatim, so the tool emits the exact text that silences it"
fi
rm -f "$GFM" "$GHC"

echo "== H. the body test is WRAP-INSENSITIVE in the superseded direction too =="
out="$(bash "$READOPT" "$DIST" "$GTH" "$CONS" "$HOVR" --check 2>&1)"; rc=$?
if [ "$rc" -eq 1 ] && grep -q 'STALE-CORE-TEXT' <<<"$out"; then
  ok "--check RED: a superseded core sentence carried at a DIFFERENT wrap is still found"
else
  bad "--check missed a superseded sentence the body demonstrably carries, re-wrapped (rc=$rc) -- and an override of a consumer-rewritten section is a re-wrap by definition"
  printf '%s\n' "$out" | sed 's/^/    /'
fi
if bash "$READOPT" "$DIST" "$GTH" "$CONS" "$HOK" --check >/dev/null 2>&1; then
  ok "CONTROL: a body carrying none of the superseded prose stays green"
else
  bad "CONTROL FAILED: an override reproducing no core text was reported -- the containment test matches anything"
fi

# --- MUTANT: put the containment test back on whole LINES -------------------------------
# A copy of the whole reconcile directory (a lone script dies sourcing lib.sh, and no
# output otherwise scores as a kill), `cmp -s`-guarded. The mutation flattens nothing,
# which is exactly the shipped-before behaviour, and it must kill H while leaving G
# firing: G's subject is absent from the body at ANY wrap, so it does not depend on the
# flattening at all. Two verdicts from one mutant, and their disagreement is the proof
# the two guards are separable.
#
# THE ANCHOR IS THE SHIPPED SPELLING, and a re-spelling of the flattening MUST re-anchor
# it here rather than relax this arm. Scored while building it: an implementation that
# flattens with `awk` instead is behaviourally identical and satisfies the entry's
# receipt, and this mutation then matches nothing — which the `cmp -s` guard reports as
# an un-applied mutant rather than passing it off as a kill.
RMUT="$ROOT/readoptmut"; rm -rf "$RMUT"; mkdir -p "$RMUT"
cp "$(dirname "$READOPT")"/*.sh "$RMUT/" 2>/dev/null || true
cp "$READOPT" "$RMUT/readopt-override.sh"
if bash "$RMUT/readopt-override.sh" "$DIST" "$GTH" "$CONS" "$GOK" --check >/dev/null 2>&1 \
   && ! bash "$RMUT/readopt-override.sh" "$DIST" "$GTH" "$CONS" "$HOVR" --check >/dev/null 2>&1; then
  ok "CONTROL: the unmutated copy in a fresh directory still passes the near-miss and still reports the re-wrap"
else
  bad "CONTROL: the unmutated copy does not reproduce the two baseline verdicts -- the mutant below would be unreadable"
fi
sed "s@| tr '\\\\n' ' ' | tr -s ' ')\"@)\"@" "$READOPT" > "$RMUT/readopt-override.sh"
if cmp -s "$READOPT" "$RMUT/readopt-override.sh"; then
  bad "the wrap MUTANT did not apply -- the body-flattening line has been respelled, so the H arm proves nothing"
else
  if bash "$RMUT/readopt-override.sh" "$DIST" "$GTH" "$CONS" "$HOVR" --check >/dev/null 2>&1; then
    ok "MUTANT (body compared un-flattened): the re-wrapped superseded sentence goes UNFOUND -- flattening is what finds it"
  else
    bad "MUTANT SURVIVED: the H arm still fires with the flattening removed, so it is not testing wrap-insensitivity"
  fi
  if bash "$RMUT/readopt-override.sh" "$DIST" "$GTH" "$CONS" "$GOVR.absent" --check >/dev/null 2>&1; then
    bad "  the mutant accepted a non-existent override path, so its verdicts say nothing about the subject"
  else
    ok "  and it still refuses a path naming no file, so the mutant runs rather than dying early"
  fi
fi
rm -f "$GOK" "$HOVR" "$HOK"

# ---------------------------------------------------------------------------
# J. UPSTREAM RE-FLOWED A PARAGRAPH, AND A FAITHFUL ADOPTION MUST NOT BE REFUSED.
# ---------------------------------------------------------------------------
# Arms A-H all change WORDS. This one changes only LINE BREAKS on the core side: the
# same sentences, re-wrapped so that a base line survives at theirs as the SUFFIX of
# a longer line. A whole-line set difference scores that base line as DELETED, and a
# body that adopted theirs faithfully still CONTAINS it (it contains the whole longer
# line), so the superseded gate refuses exactly the state it exists to certify.
# Measured on the reference consumer's `steps__gate-validation__check-20.md` across
# `eb49b783 -> a798e215`: --merge 1 merged / 0 conflicted, all 38 substantive theirs
# lines carried, --stamp readopt REFUSED on one suffix line, and the only stamp left
# was `reaffirm`, which recorded a re-adoption under the wrong outcome name.
#
# THREE SUBJECTS, AND THE NEAR-MISS CARRIES THE PROPERTY THE FEARED REGRESSION KEYS ON.
# JOK adopted theirs verbatim (must pass). JBAD adopted theirs' re-flow AND still carries
# a sentence theirs genuinely DROPPED (must refuse, naming that sentence and NOT the
# re-flowed one). A fix that simply stopped looking at the base side would pass JOK and
# miss JBAD's dropped sentence; a fix keyed on "line count unchanged" would pass JOK and
# call JBAD clean too. JBAD's dropped sentence sits in a DIFFERENT paragraph from the
# re-flow so neither guard covers the other's subject.
J3="$ROOT/j3"; rm -rf "$J3"; mkdir -p "$J3"
JPRE="$(git -C "$DIST" rev-parse --short HEAD)"
python3 - "$DIST/core/skills/ai-dlc/SKILL.md" <<'JPY'
import sys
p = sys.argv[1]; s = open(p).read()
old = """## Rule 14 -- Budget

Shadowed by an override whose survival claim is about the rest of the FILE, which is
TRUE for a single-section shadow. The control for the noun restriction.
"""
assert old in s, "rule 14 seed text moved; re-anchor arm J"
# RE-FLOW ONLY: the second base line becomes the SUFFIX of a longer theirs line, and
# the first base line is split. Every word survives; no whole base line does.
# Then a SEPARATE paragraph is DROPPED (the genuinely superseded sentence JBAD keeps).
new = """## Rule 14 -- Budget

Shadowed by an override whose survival claim is about the rest of the FILE, which is TRUE
for a single-section shadow. The control for the noun restriction.
"""
s = s.replace(old, new)
old2 = """The ordering guarantee and the retention window live here, in the paragraphs that entry
silently drops.
"""
assert old2 in s, "rule 16 seed text moved; re-anchor arm J"
s = s.replace(old2, "")
# NEGATED IN PLACE: the base rule-15 line survives at theirs as the SUFFIX of one longer
# line whose meaning is the opposite. Bare containment acquits a body carrying only the
# old line; that is the false pass an adversarial hand measured on the first cut.
old3 = """Shadowed by an override whose survival vocabulary names a DIFFERENT unit (Rule 9) and
its own body. The control for the measured false-positive class.
"""
assert old3 in s, "rule 15 seed text moved; re-anchor arm J"
s = s.replace(old3, """Never Shadowed by an override whose survival vocabulary names a DIFFERENT unit (Rule 9) and
its own body. The control for the measured false-positive class.
""")
open(p, "w").write(s)
JPY
git -C "$DIST" add -A >/dev/null 2>&1
git -C "$DIST" -c user.email=f@x -c user.name=f commit -qm "re-flow rule 14, drop a rule 16 paragraph" >/dev/null 2>&1
JTH="$(git -C "$DIST" rev-parse --short HEAD)"
# The seed must actually be a re-flow: no base Rule 14 line survives whole at theirs, and
# every base line's words are contained in theirs' flattened section. Without this the arm
# would be asserting an ordinary rewrite, which arm A already covers.
j_base_lines="$(git -C "$DIST" show "${JPRE}:core/skills/ai-dlc/SKILL.md" | awk '/^## Rule 14/{f=1;next} /^## /{f=0} f && length($0)>24')"
j_theirs_lines="$(git -C "$DIST" show "${JTH}:core/skills/ai-dlc/SKILL.md" | awk '/^## Rule 14/{f=1;next} /^## /{f=0} f && length($0)>24')"
j_theirs_flat="$(printf '%s\n' "$j_theirs_lines" | tr '\n' ' ' | tr -s ' ')"
j_whole=0; j_contained=0; j_n=0
while IFS= read -r l; do
  [ -n "$l" ] || continue; j_n=$((j_n+1))
  grep -qxF -- "$l" <<<"$j_theirs_lines" && j_whole=$((j_whole+1))
  case "$j_theirs_flat" in *"$l"*) j_contained=$((j_contained+1));; esac
done <<<"$j_base_lines"
if [ "$j_n" -ge 2 ] && [ "$j_whole" -eq 0 ] && [ "$j_contained" -eq "$j_n" ]; then
  ok "SEED: rule 14 is a pure RE-FLOW -- $j_n base lines, 0 survive whole at theirs, $j_n contained in theirs' flattened section"
else
  bad "SEED: rule 14 is not a re-flow (lines=$j_n whole=$j_whole contained=$j_contained) -- arm J would be asserting an ordinary rewrite"
fi

JOK="$CONS/.claude/skills/ai-dlc/overrides/J__reflow-adopted.md"
cat > "$JOK" <<EOF
---
shadows: SKILL.md#Rule 14
base_sha: ${JPRE}
reason: consumer budget ceiling; body carries core's rule 14 at theirs verbatim.
---

## Rule 14 -- Budget

This consumer raises the budget ceiling.

Shadowed by an override whose survival claim is about the rest of the FILE, which is TRUE
for a single-section shadow. The control for the noun restriction.
EOF

JBAD="$CONS/.claude/skills/ai-dlc/overrides/J__reflow-plus-dropped.md"
cat > "$JBAD" <<EOF
---
shadows: SKILL.md#Rule 14, SKILL.md#Rule 16
base_sha: ${JPRE}
reason: consumer budget and record format; adopted the re-flow, still carries a sentence core dropped.
---

## Rule 14 -- Budget

This consumer raises the budget ceiling.

Shadowed by an override whose survival claim is about the rest of the FILE, which is TRUE
for a single-section shadow. The control for the noun restriction.

## Rule 16 -- Recording

Multi-paragraph, shadowed by an override whose survival claim WRAPS across a newline --
the shape that returns a false zero to any line-based predicate.

The ordering guarantee and the retention window live here, in the paragraphs that entry
silently drops.
EOF

# NEGATED IN PLACE. Base rule 15 permits; theirs prepends `Never`, so the old line is a
# strict SUFFIX of the new one. JNEG carries only the OLD line and must be refused naming
# it; JNEGOK carries theirs' line and must pass. Bare containment acquits JNEG, because
# the old line's words are in theirs; what separates the two is that JNEGOK's body carries
# the theirs text holding those words and JNEG's does not.
JNEG="$CONS/.claude/skills/ai-dlc/overrides/J__negated-kept.md"
cat > "$JNEG" <<EOF
---
shadows: SKILL.md#Rule 15
base_sha: ${JPRE}
reason: consumer gating; still teaches the rule core inverted.
---

## Rule 15 -- Gating

This consumer gates at two failures.

Shadowed by an override whose survival vocabulary names a DIFFERENT unit (Rule 9) and
its own body. The control for the measured false-positive class.
EOF
JNEGOK="$CONS/.claude/skills/ai-dlc/overrides/J__negated-adopted.md"
cat > "$JNEGOK" <<EOF
---
shadows: SKILL.md#Rule 15
base_sha: ${JPRE}
reason: consumer gating; adopted core's inverted rule.
---

## Rule 15 -- Gating

This consumer gates at two failures.

Never Shadowed by an override whose survival vocabulary names a DIFFERENT unit (Rule 9) and
its own body. The control for the measured false-positive class.
EOF
# The seed must be a NEGATION IN PLACE: the base line's words survive INSIDE one theirs
# line and not as a whole line. The first cut lowercased a letter after `Never`, so the
# base line was not contained at all and every implementation refused JNEG -- the M2
# mutant then survived, and only this assertion separates that from a real kill.
jn_base="Shadowed by an override whose survival vocabulary names a DIFFERENT unit (Rule 9) and"
jn_theirs="$(git -C "$DIST" show "${JTH}:core/skills/ai-dlc/SKILL.md" | awk '/^## Rule 15/{f=1;next} /^## /{f=0} f' | tr -s ' ')"
if ! grep -qxF -- "$jn_base" <<<"$jn_theirs" && grep -qF -- "$jn_base" <<<"$jn_theirs"; then
  ok "SEED: the rule 15 base line survives at theirs INSIDE a longer line and not as a whole line"
else
  bad "SEED: the rule 15 base line is not a negation-in-place at theirs -- the JNEG arm below cannot discriminate"
fi

echo "== J. a RE-FLOWED core paragraph, faithfully adopted, is not superseded text =="
out="$(bash "$READOPT" "$DIST" "$JTH" "$CONS" "$JOK" --check 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && ! grep -q 'STALE-CORE-TEXT' <<<"$out"; then
  ok "--check OK: a body carrying theirs' re-flowed paragraph verbatim is not refused"
else
  bad "--check refused a faithful adoption of a RE-FLOWED paragraph (rc=$rc) -- the suffix false positive: the only stamp left is reaffirm, which records a readopt under the wrong name"
  printf '%s\n' "$out" | sed 's/^/    /'
fi
before_sha="$(sed -n 's/^base_sha:[[:space:]]*//p' "$JOK" | head -1)"
out="$(bash "$READOPT" "$DIST" "$JTH" "$CONS" "$JOK" --stamp readopt 2>&1)"; rc=$?
after_sha="$(sed -n 's/^base_sha:[[:space:]]*//p' "$JOK" | head -1)"
if [ "$rc" -eq 0 ] && [ "$after_sha" = "$JTH" ]; then
  ok "--stamp readopt LANDS on it ($before_sha -> $after_sha)"
else
  bad "--stamp readopt REFUSED a faithful re-flow adoption (rc=$rc, base_sha $before_sha -> $after_sha)"
  printf '%s\n' "$out" | sed 's/^/    /'
fi
out="$(bash "$READOPT" "$DIST" "$JTH" "$CONS" "$JBAD" --check 2>&1)"; rc=$?
if [ "$rc" -eq 1 ] && grep -q 'STALE-CORE-TEXT' <<<"$out" && grep -q 'retention window live here' <<<"$out"; then
  ok "NEAR-MISS: the same re-flow adopted PLUS a sentence core genuinely dropped is still refused, naming the dropped sentence"
else
  bad "NEAR-MISS: a body still carrying a sentence core DROPPED was not refused, or the refusal did not name it (rc=$rc) -- containment has swallowed the superseded direction"
  printf '%s\n' "$out" | sed 's/^/    /'
fi
if ! grep -q 'noun restriction' <<<"$out"; then
  ok "  and the re-flowed rule 14 line is NOT among the lines it names"
else
  bad "  the refusal names the RE-FLOWED line as superseded -- the false positive is back, hiding behind a true one"
fi
out="$(bash "$READOPT" "$DIST" "$JTH" "$CONS" "$JNEG" --check 2>&1)"; rc=$?
if [ "$rc" -eq 1 ] && grep -q 'STALE-CORE-TEXT' <<<"$out" && grep -q 'survival vocabulary names a DIFFERENT unit' <<<"$out"; then
  ok "NEGATED IN PLACE: a body carrying only the line core prefixed with Never is REFUSED, naming it"
else
  bad "NEGATED IN PLACE: a body teaching the rule core INVERTED was not refused (rc=$rc) -- bare containment acquitted it because the old words survive inside the new line"
  printf '%s\n' "$out" | sed 's/^/    /'
fi
out="$(bash "$READOPT" "$DIST" "$JTH" "$CONS" "$JNEGOK" --check 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && ! grep -q 'STALE-CORE-TEXT' <<<"$out"; then
  ok "  and a body carrying core's Never line passes -- the same words, in the context theirs gives them"
else
  bad "  a body that adopted the inverted line was refused (rc=$rc) -- the narrowing overshot and refuses a faithful adoption"
  printf '%s\n' "$out" | sed 's/^/    /'
fi

# --- MUTANT: put the base-side test back on WHOLE LINES ----------------------------------
# The shipped-before shape: a set difference over whole trimmed lines. Restoring it must
# make JOK REFUSE (the suffix line scores as deleted) while JBAD still refuses -- one cell
# moves. Built as a whole-directory copy, cmp -s guarded, with the unmutated control first.
#
# THE STAMP ABOVE ADVANCED JOK'S base_sha TO THEIRS, and against a degenerate range every
# implementation reports OK -- the first cut of this mutant "survived" for exactly that
# reason, with its control passing beside it. Put the range back and assert it is back.
sed -i.bak "s/^base_sha:.*/base_sha: ${JPRE}/" "$JOK" && rm -f "$JOK.bak"
if [ "$(sed -n 's/^base_sha:[[:space:]]*//p' "$JOK" | head -1)" = "$JPRE" ] && [ "$JPRE" != "$JTH" ]; then
  ok "  JOK's base_sha reset to $JPRE for the mutant (theirs is $JTH, so the range is not degenerate)"
else
  bad "  could not reset JOK's base_sha -- the mutant below would compare theirs against itself"
fi
JMUT="$ROOT/reflowmut"; rm -rf "$JMUT"; mkdir -p "$JMUT"
cp "$(dirname "$READOPT")"/*.sh "$JMUT/" 2>/dev/null || true
cp "$(dirname "$READOPT")"/*.md "$JMUT/" 2>/dev/null || true
if bash "$JMUT/readopt-override.sh" "$DIST" "$JTH" "$CONS" "$JOK" --check >/dev/null 2>&1 \
   && ! bash "$JMUT/readopt-override.sh" "$DIST" "$JTH" "$CONS" "$JBAD" --check >/dev/null 2>&1; then
  ok "CONTROL: the unmutated copy in a fresh directory passes JOK and refuses JBAD"
else
  bad "CONTROL: the unmutated copy does not reproduce the two baseline verdicts -- the mutant below would be unreadable"
fi
# TWO MUTANTS, one per half of the predicate. M1 drops the containment acquittal, so
# `changed_lines` is the whole-line set difference again: JOK must be REFUSED, JBAD still
# refused. M2 drops the context test, so bare containment acquits: JNEG must PASS (the
# false pass the first cut shipped), JOK still passes. Each is anchored on the clause it
# removes, which no other line in the file carries.
sed 's@    carries "\$to_flat" "\$line" \&\& carried_in_context "\$2" "\$3" "\$line" \&\& continue@    :@' "$READOPT" > "$JMUT/readopt-override.sh"
if cmp -s "$READOPT" "$JMUT/readopt-override.sh"; then
  bad "the re-flow MUTANT (M1) did not apply -- the containment line in changed_lines has been respelled, so arm J proves nothing"
else
  if bash "$JMUT/readopt-override.sh" "$DIST" "$JTH" "$CONS" "$JOK" --check >/dev/null 2>&1; then
    bad "MUTANT M1 SURVIVED: with the containment acquittal removed, the faithful re-flow adoption still passes -- arm J is not testing containment"
  else
    ok "MUTANT M1 (whole-line set difference restored): the faithful re-flow adoption is REFUSED -- containment is what clears it"
  fi
  if bash "$JMUT/readopt-override.sh" "$DIST" "$JTH" "$CONS" "$JBAD" --check >/dev/null 2>&1; then
    bad "  M1 passed JBAD, so it is not the whole-line form -- its JOK verdict says nothing"
  else
    ok "  and M1 still refuses JBAD, so exactly one cell moved"
  fi
fi
sed 's@    carries "\$to_flat" "\$line" \&\& carried_in_context "\$2" "\$3" "\$line" \&\& continue@    carries "$to_flat" "$line" \&\& continue@' "$READOPT" > "$JMUT/readopt-override.sh"
if cmp -s "$READOPT" "$JMUT/readopt-override.sh"; then
  bad "the bare-containment MUTANT (M2) did not apply -- the context clause in changed_lines has been respelled, so the negation arm proves nothing"
else
  if bash "$JMUT/readopt-override.sh" "$DIST" "$JTH" "$CONS" "$JNEG" --check >/dev/null 2>&1; then
    ok "MUTANT M2 (bare containment, no context test): the body teaching the INVERTED rule PASSES -- the context test is what refuses it"
  else
    bad "MUTANT M2 SURVIVED: bare containment still refuses the negated-in-place body, so the context test is not what is doing the work"
  fi
  if bash "$JMUT/readopt-override.sh" "$DIST" "$JTH" "$CONS" "$JOK" --check >/dev/null 2>&1; then
    ok "  and M2 still passes the faithful re-flow, so exactly one cell moved"
  else
    bad "  M2 refused JOK, so it is not bare containment -- its JNEG verdict says nothing"
  fi
fi
rm -f "$JOK" "$JBAD" "$JNEG" "$JNEGOK"

rm -rf "$ROOT"
echo ""
if [ "$fails" -eq 0 ]; then echo "layer-readopt-gate: PASS"; exit 0; fi
echo "layer-readopt-gate: FAIL ($fails)"; exit 1
