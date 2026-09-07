#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# snapshot-archive-rotate/run.sh — prove the snapshot-history rotator moves old narrative into
# ONE archive, loses nothing, refuses rather than half-writes, and never puts the bytes
# somewhere Check 35 cannot see them.
#
# THE ACCEPTANCE TEST IS THE LAST ONE: the conservation corpus must still contain every
# substantive line the history held before the rotation. Check 35's corpus is
# `git ls-files -- '*.md' | xargs cat`, so "wrote the bytes" and "conserved the bytes" are
# different claims and only the second one matters. Measured on the reference consumer: if the
# history file's content leaves the corpus, destroyed lines go 17 -> 79 against a floor of 40.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the check regressed, 2 = fixture broken.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh" | tail -1)" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

# Locate the rotator by walking UP for a marker, so this resolves from the distribution
# (core/scripts) and from a consumer where install.sh relocates it (scripts/ai-dlc). Resolving
# it relative to the fixture would bind the fixture to one of the two layouts.
ROT=""
d="$HERE"
while [ "$d" != "/" ]; do
  for base in "$d/core/scripts" "$d/scripts/ai-dlc"; do
    if [ -f "$base/rotate-snapshot-archive.sh" ]; then ROT="$base/rotate-snapshot-archive.sh"; break 2; fi
  done
  d="$(dirname "$d")"
done
[ -n "$ROT" ] || { echo "FIXTURE ERROR: rotate-snapshot-archive.sh not found in either layout" >&2; exit 2; }

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

# The conservation corpus, built exactly the way validate-snapshot-conservation.sh builds it.
corpus() { ( cd "$PROJ" && git ls-files -z -- '*.md' | xargs -0 cat 2>/dev/null ) \
             | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | sort -u; }
subst()  { sed 's/^[[:space:]]*//; s/[[:space:]]*$//' "$@" | awk 'length($0) >= 20' | sort -u; }

echo "snapshot-archive-rotate:"

BEFORE_LINES="$(wc -l < "$HIST" | tr -d ' ')"
BEFORE_BOUND="$(grep -c '^## ' "$HIST")"
subst "$HIST" > "$WORK/before.substantive"
BEFORE_SUBST="$(wc -l < "$WORK/before.substantive" | tr -d ' ')"

# --- Assertion 0: SANITY — the seed holds the shape the rotator has to survive -----------
# Without this every assertion below could pass over a seed that never had a nested snapshot
# in it, which is the one shape that distinguishes a cut-point rotator from an entry parser.
if [ "$BEFORE_BOUND" -eq 28 ] && [ "$BEFORE_SUBST" -gt 20 ] \
   && grep -q '^## Pipeline Position$' "$HIST" && grep -q 'NESTEDLEAD' "$HIST"; then
  ok "before: ${BEFORE_LINES} lines, ${BEFORE_BOUND} '## ' lines — but only 21 are cut candidates, because 7 belong to a nested verbatim snapshot"
else
  bad "FIXTURE BROKEN — seed shape wrong (${BEFORE_BOUND} '## ' lines, ${BEFORE_SUBST} substantive)"
  echo; echo "snapshot-archive-rotate: FIXTURE BROKEN" >&2; exit 2
fi

# --- Assertion 1: the default writes nothing ---------------------------------------------
H0="$(shasum "$HIST" | cut -d' ' -f1)"
out="$(bash "$ROT" "$HIST" 2>&1)"; rc=$?
H1="$(shasum "$HIST" | cut -d' ' -f1)"
if [ "$rc" -eq 0 ] && [ "$H0" = "$H1" ] && [ ! -e "$ARCHIVE" ]; then
  ok "report-only default: exits 0, history byte-identical, archive not even created"
else
  bad "report-only default wrote something (rc=$rc, archive exists: $([ -e "$ARCHIVE" ] && echo yes || echo no))"
fi

# --- Assertion 2: the seven nested section headings are NOT cut candidates ------------------
# 28 lines match '^## ', but seven of them are the schema section names inside one pasted
# snapshot, so there are 21 candidates and keeping 10 moves 11. A rotator that counted all 28
# would say "18 of 28" here — the number is what distinguishes the two implementations, and
# assertion 5 then proves the consequence.
if grep -q '11 of 21 entr' <<<"$out"; then
  ok "dry run: 11 of 21 cut candidates move — the 7 nested schema headings were excluded from candidacy"
else
  bad "dry run reported an unexpected split (expected '11 of 21'): $(head -1 <<<"$out")"
fi

# --- Assertion 3: apply moves, and the accounting balances --------------------------------
out="$(bash "$ROT" "$HIST" --apply 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ -s "$ARCHIVE" ]; then
  ok "apply: exits 0 and the archive exists"
else
  bad "apply failed (rc=$rc): $out"
  echo; echo "snapshot-archive-rotate: FAIL" >&2; exit 1
fi

AFTER_LINES="$(wc -l < "$HIST" | tr -d ' ')"
# I54b: no `writer | grep -q`. The reader leaves at its first match while the writer is still
# pushing, and under pipefail the pipeline answers with the writer's EPIPE — so the arm reports
# "not found" on input that contains the pattern. Command substitution, then a here-string.
FIRST_LINE="$(head -1 "$HIST")"
if [ "$AFTER_LINES" -lt "$BEFORE_LINES" ] && grep -q '^# Pipeline Snapshot' <<<"$FIRST_LINE"; then
  ok "history shrank ${BEFORE_LINES} -> ${AFTER_LINES} and kept its preamble H1"
else
  bad "history is ${AFTER_LINES} lines and its first line is '$(head -1 "$HIST")'"
fi

# --- Assertion 4: THE ACCEPTANCE TEST — nothing left the conservation corpus ---------------
corpus > "$WORK/corpus.after"
missing="$(comm -23 "$WORK/before.substantive" "$WORK/corpus.after" | wc -l | tr -d ' ')"
control="$(comm -23 "$WORK/before.substantive" /dev/null | wc -l | tr -d ' ')"
if [ "$missing" -eq 0 ] && [ "$control" -eq "$BEFORE_SUBST" ] && [ "$BEFORE_SUBST" -gt 0 ]; then
  ok "conservation: 0 of ${BEFORE_SUBST} substantive lines absent from the corpus (control against /dev/null: ${control})"
else
  bad "conservation: ${missing} line(s) left the corpus (control ${control} of ${BEFORE_SUBST})"
fi

# --- Assertion 5: the nested verbatim snapshot was not split across the two files ----------
n_hist="$(grep -c 'NESTED-' "$HIST" || true)"
n_arch="$(grep -c 'NESTED-' "$ARCHIVE" || true)"
if { [ "$n_hist" -eq 0 ] && [ "$n_arch" -eq 7 ]; } || { [ "$n_hist" -eq 7 ] && [ "$n_arch" -eq 0 ]; }; then
  ok "the nested verbatim snapshot's 7 sections stayed together (history ${n_hist} / archive ${n_arch})"
else
  bad "the nested snapshot was SPLIT: ${n_hist} sections in the history, ${n_arch} in the archive"
fi

# --- Assertion 6: the archive is staged, so Check 35 can actually see it -------------------
if ( cd "$PROJ" && git ls-files --error-unmatch "$ARCHIVE" >/dev/null 2>&1 ); then
  ok "the archive is staged — its bytes are inside 'git ls-files', which is what the corpus is"
else
  bad "the archive is NOT tracked; Check 35's corpus cannot see the lines just moved into it"
fi

# --- Assertion 7: idempotence, and the header is seeded exactly once ------------------------
A0="$(shasum "$ARCHIVE" | cut -d' ' -f1)"; H0="$(shasum "$HIST" | cut -d' ' -f1)"
bash "$ROT" "$HIST" --apply >/dev/null 2>&1; rc=$?
A1="$(shasum "$ARCHIVE" | cut -d' ' -f1)"; H1="$(shasum "$HIST" | cut -d' ' -f1)"
hdr="$(grep -c '^# Pipeline snapshot — archive' "$ARCHIVE")"
if [ "$rc" -eq 0 ] && [ "$A0" = "$A1" ] && [ "$H0" = "$H1" ] && [ "$hdr" -eq 1 ]; then
  ok "idempotent: a second --apply changes neither file, and the archive header appears once"
else
  bad "second --apply was not a no-op (rc=$rc, archive changed: $([ "$A0" = "$A1" ] && echo no || echo yes), headers=${hdr})"
fi

# --- Assertion 8: --absorb folds a stale snapshot into the SAME file, creating no new one ----
before_md="$( cd "$PROJ" && git ls-files -- '*.md' | wc -l | tr -d ' ' )"
bash "$ROT" "$HIST" --absorb "$STALE" --keep-entries 5 --apply >/dev/null 2>&1
after_md="$( cd "$PROJ" && git ls-files -- '*.md' | wc -l | tr -d ' ' )"
if grep -q 'STALESNAP' "$ARCHIVE" && [ ! -f "$STALE" ] && [ "$after_md" -lt "$before_md" ]; then
  ok "--absorb: the stale snapshot is inside the one archive, the dated file was never created (tracked *.md ${before_md} -> ${after_md})"
else
  bad "--absorb left the stale snapshot behind or created a new file (${before_md} -> ${after_md} tracked *.md)"
fi

# --- Assertion 9: REFUSAL — a non-empty body with no boundary at all -------------------------
H0="$(shasum "$NOBOUND" | cut -d' ' -f1)"
out="$(bash "$ROT" "$NOBOUND" --apply 2>&1)"; rc=$?
H1="$(shasum "$NOBOUND" | cut -d' ' -f1)"
if [ "$rc" -eq 1 ] && [ "$H0" = "$H1" ] && grep -q 'no cut point' <<<"$out"; then
  ok "REFUSAL: a history with no '## ' heading is refused (exit 1), not silently reported as nothing-to-rotate"
else
  bad "boundary-free history was not refused (rc=$rc, changed: $([ "$H0" = "$H1" ] && echo no || echo yes))"
fi

# --- Assertion 10: REFUSAL — a git-ignored destination -------------------------------------
# This is the refusal that the measurement bought. Writing bytes into an ignored path is not a
# move: `git ls-files` never lists it, so the conservation corpus never contains it.
IG="$WORK/ignored"; rm -rf "$IG"; mkdir -p "$IG/_bmad-output"
cp "$HIST" "$IG/_bmad-output/pipeline-snapshot-history.md"
printf '_bmad-output/pipeline-history/\n' > "$IG/.gitignore"
( cd "$IG" && git init -q . && git add -A \
  && git -c user.email=f@f -c user.name=f commit -qm i ) >/dev/null 2>&1
H0="$(shasum "$IG/_bmad-output/pipeline-snapshot-history.md" | cut -d' ' -f1)"
out="$(bash "$ROT" "$IG/_bmad-output/pipeline-snapshot-history.md" --keep-entries 1 --apply 2>&1)"; rc=$?
H1="$(shasum "$IG/_bmad-output/pipeline-snapshot-history.md" | cut -d' ' -f1)"
if [ "$rc" -eq 1 ] && [ "$H0" = "$H1" ] && grep -q 'git-ignored' <<<"$out"; then
  ok "REFUSAL: an ignored archive path is refused before anything is written"
else
  bad "an ignored archive path was NOT refused (rc=$rc, history changed: $([ "$H0" = "$H1" ] && echo no || echo yes))"
fi

# --- Assertion 11: CONTROL for 10 — un-ignore the same tree and it must succeed --------------
rm -f "$IG/.gitignore"
out="$(bash "$ROT" "$IG/_bmad-output/pipeline-snapshot-history.md" --keep-entries 1 --apply 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && [ -s "$IG/_bmad-output/pipeline-history/pipeline-snapshot-archive.md" ]; then
  ok "CONTROL: the same tree with the ignore removed rotates normally — assertion 10 measured the ignore, not the tree"
else
  bad "CONTROL FAILED: un-ignoring did not make the same rotation succeed (rc=$rc)"
fi

# --- Assertion 12: REFUSAL — at the cut floor WITH unheaded move markers ---------------------
# The knife-edge beside assertion 9. That one needs ZERO boundaries; ONE surviving `## ` lands
# here instead, where the file used to print an affirmative "nothing to rotate" and exit 0 while
# growing without bound. Measured on the reference consumer: it rotates ONCE, lands on exactly
# `--keep-entries` headings, then grows every round forever, and the old verdict line was
# identical to a genuinely short file's.
FLOOR="$WORK/floor"; rm -rf "$FLOOR"; mkdir -p "$FLOOR"
{ printf '# H\n\n'
  printf '## [MOVED 2026-09-06T10:00:00Z from pipeline-snapshot.md — trim]\n'
  i=0; while [ "$i" -lt 30 ]; do i=$((i + 1))
    printf '[MOVED 2026-09-06T11:00:%02dZ from pipeline-snapshot.md — trim]\nbody %s\n' "$i" "$i"
  done; } > "$FLOOR/h.md"
H0="$(shasum "$FLOOR/h.md" | cut -d' ' -f1)"
out="$(bash "$ROT" "$FLOOR/h.md" --keep-entries 10 --apply 2>&1)"; rc=$?
H1="$(shasum "$FLOOR/h.md" | cut -d' ' -f1)"
if [ "$rc" -eq 1 ] && [ "$H0" = "$H1" ] && grep -q 'cut floor' <<<"$out"; then
  ok "REFUSAL: at the cut floor with unheaded move markers, the file is refused (exit 1), not reported as nothing-to-rotate"
else
  bad "a file at the cut floor carrying unheaded markers was NOT refused (rc=$rc, changed: $([ "$H0" = "$H1" ] && echo no || echo yes))"
fi

# --- Assertion 13: CONTROL for 12 — same bytes, markers HEADED, must rotate -------------------
# One property apart. If this refused too, assertion 12 would be measuring the cut floor rather
# than the unheaded markers, and a rotator that refused everything would pass both.
sed -E 's/^\[MOVED/## [MOVED/' "$FLOOR/h.md" > "$FLOOR/headed.md"
if cmp -s "$FLOOR/h.md" "$FLOOR/headed.md"; then
  bad "CONTROL BROKEN: the sed changed nothing, so assertion 13 is not one property from 12"
else
  out="$(bash "$ROT" "$FLOOR/headed.md" --keep-entries 10 --apply 2>&1)"; rc=$?
  if [ "$rc" -eq 0 ] && grep -q 'entr(ies)' <<<"$out"; then
    ok "CONTROL: the same content with every marker headed rotates normally — assertion 12 measured the heading, not the floor"
  else
    bad "CONTROL FAILED: headed markers did not rotate (rc=$rc)"
  fi
fi

# --- Assertion 14: CONTROL for 12 — genuinely short file still exits 0 -----------------------
# The other side: a file at the floor with NO unheaded markers must keep the old affirmative
# behaviour. Without this, a refusal keyed on the floor alone would pass assertion 12.
printf '# H\n\n## [MOVED 2026-09-06T10:00:00Z from pipeline-snapshot.md — trim]\nbody\n' > "$FLOOR/short.md"
out="$(bash "$ROT" "$FLOOR/short.md" --keep-entries 10 --apply 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && grep -q 'nothing to rotate' <<<"$out"; then
  ok "CONTROL: a genuinely short history at the floor still reports nothing-to-rotate and exits 0"
else
  bad "CONTROL FAILED: a short history was refused or misreported (rc=$rc)"
fi

# --- MUTATION: break the split so the line accounting cannot balance -------------------------
# The line-accounting refusal cannot be reached from any input — it guards the splitter against
# itself — so the only way to prove it fires is to break the splitter.
MUT="$WORK/mutant.sh"
sed 's|^sed -n "\${CUT},\\\$p"  *"\$HISTORY" > "\$TMPD/tail"|sed -n "$((CUT + 1)),\\$p" "$HISTORY" > "$TMPD/tail"|' "$ROT" > "$MUT"
if cmp -s "$ROT" "$MUT"; then
  bad "MUTATION: the sed matched nothing, so the line-accounting refusal is UNPROVEN"
else
  MW="$WORK/mutwork"; rm -rf "$MW"; mkdir -p "$MW/_bmad-output"
  cp "$HIST" "$MW/_bmad-output/pipeline-snapshot-history.md"
  ( cd "$MW" && git init -q . && git add -A \
    && git -c user.email=f@f -c user.name=f commit -qm i ) >/dev/null 2>&1
  H0="$(shasum "$MW/_bmad-output/pipeline-snapshot-history.md" | cut -d' ' -f1)"
  m_out="$(bash "$MUT" "$MW/_bmad-output/pipeline-snapshot-history.md" --keep-entries 1 --apply 2>&1)"; m_rc=$?
  H1="$(shasum "$MW/_bmad-output/pipeline-snapshot-history.md" | cut -d' ' -f1)"
  if [ "$m_rc" -eq 1 ] && grep -q 'accounting does not balance' <<<"$m_out" && [ "$H0" = "$H1" ]; then
    ok "MUTATION: a splitter that drops one line REFUSES and writes nothing — the accounting invariant is live"
  else
    bad "MUTATION: a splitter that drops a line was NOT caught (rc=$m_rc); the accounting invariant is inert"
  fi
fi

# --- MUTATION 2: strip REFUSAL 2's guard and assertion 12 must go red ------------------------
# Assertion 12 is ABSENCE-shaped — it demands a refusal — so a subject that never checks the
# marker looks identical to one that checks and finds none. Only a mutant establishes that the
# arm discriminates at all. The mutation is keyed on the guard's own predicate, not on a line
# list, and the post-mutation count is asserted 0 against a non-zero unmutated count.
MUT2="$WORK/mutant2.sh"
sed 's|^  if \[ "\$N_UNHEADED" -gt 0 \]; then|  if false; then|' "$ROT" > "$MUT2"
pre="$(grep -c 'N_UNHEADED" -gt 0' "$ROT")" || pre=0
post="$(grep -c 'N_UNHEADED" -gt 0' "$MUT2")" || post=0
if cmp -s "$ROT" "$MUT2" || [ "$pre" -eq 0 ] || [ "$post" -ne 0 ]; then
  bad "MUTATION 2 DID NOT APPLY (unmutated=$pre mutated=$post); REFUSAL 2 is UNPROVEN"
else
  m_out="$(bash "$MUT2" "$FLOOR/h.md" --keep-entries 10 --apply 2>&1)"; m_rc=$?
  # The mutant must do what the OLD code did: affirm, exit 0, never refuse.
  if [ "$m_rc" -eq 0 ] && grep -q 'nothing to rotate' <<<"$m_out"; then
    ok "MUTATION 2: with the unheaded-marker guard stripped the file reports nothing-to-rotate and exits 0 — assertion 12 is live, not vacuous"
  else
    bad "MUTATION 2: stripping the guard did not restore the silent exit 0 (rc=$m_rc); assertion 12 may be passing for another reason"
  fi
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "snapshot-archive-rotate: PASS"
else
  echo "snapshot-archive-rotate: FAIL ($fails)" >&2; exit 1
fi
