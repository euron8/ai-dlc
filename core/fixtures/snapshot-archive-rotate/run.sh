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
# The absorb arms drive the real control hooks, which read AI_DLC_* tuning variables. A consumer
# that sets any of them in settings.json must not be able to turn this fixture red.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh" | tail -1)" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

# Locate the rotator by walking UP for a marker, so this resolves from the distribution
# (core/scripts) and from a consumer where install.sh relocates it (scripts/ai-dlc). Resolving
# it relative to the fixture would bind the fixture to one of the two layouts.
# The two control hooks the absorb arms drive are resolved at the SAME root, in the layout that
# matched: `core/hooks/` beside `core/scripts/` upstream, `.claude/hooks/` beside `scripts/ai-dlc/`
# in a consumer. Resolving them independently could pair one tree's rotator with another's hooks.
ROT=""
HOOKDIR=""
d="$HERE"
while [ "$d" != "/" ]; do
  if [ -f "$d/core/scripts/rotate-snapshot-archive.sh" ]; then
    ROT="$d/core/scripts/rotate-snapshot-archive.sh"; HOOKDIR="$d/core/hooks"; break
  fi
  if [ -f "$d/scripts/ai-dlc/rotate-snapshot-archive.sh" ]; then
    ROT="$d/scripts/ai-dlc/rotate-snapshot-archive.sh"; HOOKDIR="$d/.claude/hooks"; break
  fi
  d="$(dirname "$d")"
done
[ -n "$ROT" ] || { echo "FIXTURE ERROR: rotate-snapshot-archive.sh not found in either layout" >&2; exit 2; }
HOOK_C="$HOOKDIR/ai-dlc-continue.sh"
HOOK_P="$HOOKDIR/ai-dlc-pause.sh"
[ -f "$HOOK_C" ] && [ -f "$HOOK_P" ] \
  || { echo "FIXTURE ERROR: ai-dlc-continue.sh / ai-dlc-pause.sh not found beside the rotator (${HOOKDIR})" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "FIXTURE ERROR: jq is required to drive the hooks" >&2; exit 2; }

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
# The snapshot is TRUNCATED, never removed: every control hook keys "a pipeline is active" on the
# file's existence, so the absorbed file stays on disk at 0 bytes and stays tracked. The tracked
# *.md count therefore does not move — no dated archive was minted, and nothing was deleted.
before_md="$( cd "$PROJ" && git ls-files -- '*.md' | wc -l | tr -d ' ' )"
cp "$STALE" "$WORK/stale.before" || { echo "FIXTURE ERROR: cannot copy the stale snapshot" >&2; exit 2; }
bash "$ROT" "$HIST" --absorb "$STALE" --keep-entries 5 --apply >/dev/null 2>&1
after_md="$( cd "$PROJ" && git ls-files -- '*.md' | wc -l | tr -d ' ' )"
# The WHOLE snapshot, not its marker line: the archive's last N lines must be the pre-absorb copy
# byte for byte, where N is that copy's line count. A marker grep alone passes a lossy absorb.
sn="$(wc -l < "$WORK/stale.before" | tr -d ' ')"
tail -n "$sn" "$ARCHIVE" > "$WORK/stale.tail"
whole=no; [ "$sn" -gt 1 ] && cmp -s "$WORK/stale.before" "$WORK/stale.tail" && whole=yes
if grep -q 'STALESNAP' "$ARCHIVE" && [ "$whole" = yes ] && [ -f "$STALE" ] && [ ! -s "$STALE" ] \
   && [ "$before_md" -gt 0 ] && [ "$after_md" -eq "$before_md" ]; then
  ok "--absorb: the whole stale snapshot (${sn} lines, byte-identical) is the archive's tail, the snapshot is present at 0 bytes, no dated file created (tracked *.md ${before_md} -> ${after_md})"
else
  bad "--absorb: marker in archive=$(grep -c 'STALESNAP' "$ARCHIVE"), whole snapshot is the archive tail=${whole} (${sn} lines), snapshot present=$([ -f "$STALE" ] && echo yes || echo no), bytes=$(if [ -f "$STALE" ]; then wc -c < "$STALE" | tr -d ' '; fi), tracked *.md ${before_md} -> ${after_md}"
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

# =============================================================================================
# THE ABSORB SWAP. route.md's fresh start is two acts — the rotator absorbs the stale snapshot,
# then the lead writes the new one — and a turn can end between them. Every control hook keys
# "a pipeline is active" on the snapshot's EXISTENCE, so the absorb must leave the file present
# (emptied), and it must run on every path that is not a refusal, or the lead's next write
# destroys the stale snapshot unarchived.
#
# Every arm below drives a FRESH copy of one seed template, so no arm reads a tree an earlier arm
# or a mutant wrote. The arms are a function of the rotator and the two hooks they drive, which
# is what lets the mutants further down re-run the SAME arms against a mutated subject.
# =============================================================================================
STOP_JSON='{"session_id":"fx","hook_event_name":"Stop","stop_hook_active":false,"transcript_path":"/nonexistent"}'
PROMPT_JSON='{"session_id":"fx","hook_event_name":"UserPromptSubmit","prompt":"please look at the login flow again before the next story"}'
SNAP_REL="_bmad-output/pipeline-snapshot.md"
HIST_REL="_bmad-output/pipeline-snapshot-history.md"
ARCH_REL="_bmad-output/pipeline-history/pipeline-snapshot-archive.md"

world() {  # <template> -> prints a fresh copy's path
  local w
  w="$(mktemp -d "$WORK/w.XXXXXX")" || return 1
  cp -R "$TMPL/$1/." "$w/" || return 1
  printf '%s\n' "$w"
}

# hooks_fire <world>: drive the REAL Stop and UserPromptSubmit hooks against the world.
# Sets HB (count of block decisions emitted) and HF (yes/no: the pause flag was created).
hooks_fire() {
  local w="$1" out
  rm -f "$w/_bmad-output/pipeline-paused.flag" "$w/_bmad-output/pipeline-block-state.txt"
  out="$(printf '%s' "$STOP_JSON" | CLAUDE_PROJECT_DIR="$w" bash "$HC_" 2>/dev/null)"
  HB="$(grep -c '"decision"[[:space:]]*:[[:space:]]*"block"' <<<"$out")" || HB=0
  printf '%s' "$PROMPT_JSON" | CLAUDE_PROJECT_DIR="$w" bash "$HP_" >/dev/null 2>&1
  if [ -f "$w/_bmad-output/pipeline-paused.flag" ]; then HF=yes; else HF=no; fi
}

tracked() { ( cd "$1" && git ls-files --error-unmatch -- "$2" >/dev/null 2>&1 ); }
fbytes()  { if [ -f "$1" ]; then wc -c < "$1" | tr -d ' '; fi; }

# snap_copy <world>: copy the snapshot OUTSIDE the world's repo (a sibling path), so the copy is
# the pre-absorb bytes and cannot dirty the world's `git status`. Prints the copy's path.
snap_copy() { cp "$1/$SNAP_REL" "$1.before" && printf '%s\n' "$1.before"; }

# absorbed_ok <world> <marker> <pre-absorb copy>: the marker is in the archive once, the archive's
# last N lines are the pre-absorb copy byte for byte (N = the copy's line count, and N > 1 so the
# copy cannot be the marker line alone), the snapshot is present at 0 bytes, and the archive is
# tracked. Each is a different way to lose the snapshot. The marker grep alone is satisfied by an
# absorb that copies ONLY the marker line (measured: `grep -E STALE` in place of `cat`).
absorbed_ok() {
  local n sn
  n="$(grep -c "$2" "$1/$ARCH_REL" 2>/dev/null)" || n=0
  [ -s "$3" ] || return 1
  sn="$(wc -l < "$3" | tr -d ' ')"
  tail -n "$sn" "$1/$ARCH_REL" > "$1.tail" 2>/dev/null || return 1
  [ "$n" -eq 1 ] && [ "$sn" -gt 1 ] && cmp -s "$3" "$1.tail" \
    && [ -f "$1/$SNAP_REL" ] && [ ! -s "$1/$SNAP_REL" ] && tracked "$1" "$ARCH_REL"
}

# --- the arms. Each returns 0 (holds) or 1 and sets MSG. ----------------------------------------

# SWAP: before the call the hooks fire (the precondition — proves the arm measures the rotator,
# not a world the hooks ignore); after --absorb --apply they STILL fire.
arm_swap() {
  local w; w="$(world above)" || { MSG="world copy failed"; return 1; }
  hooks_fire "$w"; local b0="$HB" f0="$HF"
  bash "$R_" "$w/$HIST_REL" --absorb "$w/$SNAP_REL" --apply >/dev/null 2>&1; local rc=$?
  hooks_fire "$w"
  MSG="before: block=${b0} flag=${f0}; rotator rc=${rc}; after: block=${HB} flag=${HF}, snapshot present=$([ -f "$w/$SNAP_REL" ] && echo yes || echo no)"
  [ "$b0" -eq 1 ] && [ "$f0" = yes ] && [ "$rc" -eq 0 ] && [ "$HB" -eq 1 ] && [ "$HF" = yes ]
}

# NEG: a tree with no snapshot at all — the rotator runs, and both hooks stay silent. The positive
# half of this pair is arm_swap's "before" reading, one property apart (the snapshot file).
arm_neg() {
  local w; w="$(world nosnap)" || { MSG="world copy failed"; return 1; }
  bash "$R_" "$w/$HIST_REL" --apply >/dev/null 2>&1; local rc=$?
  hooks_fire "$w"
  MSG="rotator rc=${rc}; block=${HB} flag=${HF}; snapshot exists=$([ -e "$w/$SNAP_REL" ] && echo yes || echo no)"
  [ "$rc" -eq 0 ] && [ ! -e "$w/$SNAP_REL" ] && [ "$HB" -eq 0 ] && [ "$HF" = no ]
}

# SHAPE: one per non-refusal path. The rotator's own verdict line is asserted too, so the three
# worlds are PROVEN to reach three different paths rather than assumed to.
arm_shape() {  # <world> <verdict regex>
  local w out rc pre; w="$(world "$1")" || { MSG="world copy failed"; return 1; }
  pre="$(snap_copy "$w")" || { MSG="snapshot copy failed"; return 1; }
  out="$(bash "$R_" "$w/$HIST_REL" --absorb "$w/$SNAP_REL" --apply 2>&1)"; rc=$?
  local whole=no; absorbed_ok "$w" "STALESNAP-$1" "$pre" && whole=yes
  MSG="rc=${rc}, path verdict matched=$(grep -cE "$2" <<<"$out"), marker in archive=$(grep -c "STALESNAP-$1" "$w/$ARCH_REL" 2>/dev/null), whole snapshot is the archive tail=$(cmp -s "$pre" "$w.tail" && echo yes || echo no) ($(wc -l < "$pre" | tr -d ' ') lines), snapshot present=$([ -f "$w/$SNAP_REL" ] && echo yes || echo no) bytes=$(fbytes "$w/$SNAP_REL"), archive tracked=$(tracked "$w" "$ARCH_REL" && echo yes || echo no)"
  [ "$rc" -eq 0 ] && grep -qE "$2" <<<"$out" && [ "$whole" = yes ]
}

# REPORT-ONLY: --absorb WITHOUT --apply, on each history shape, writes nothing at all — the world's
# `git status --porcelain` is empty, the snapshot is byte-identical to its pre-run copy, and no
# archive exists. The positive conjunct is the rotator's own "would be appended" line, so a subject
# that emits nothing (or exits before the absorb report) cannot pass this absence-shaped arm.
arm_ro() {
  local s w pre out rc st ok_all=1; MSG=""
  for s in nohist floor above; do
    w="$(world "$s")" || { MSG="world copy failed"; return 1; }
    pre="$(snap_copy "$w")" || { MSG="snapshot copy failed"; return 1; }
    out="$(bash "$R_" "$w/$HIST_REL" --absorb "$w/$SNAP_REL" 2>&1)"; rc=$?
    st="$( cd "$w" && git status --porcelain --untracked-files=all 2>&1 )"
    local same=no said=no; cmp -s "$pre" "$w/$SNAP_REL" && same=yes
    grep -q 'would be appended' <<<"$out" && said=yes
    MSG="${MSG}${s}: rc=${rc} status-lines=$(printf '%s' "$st" | grep -c .) snapshot-identical=${same} archive=$([ -e "$w/$ARCH_REL" ] && echo yes || echo no) reported=${said}; "
    { [ "$rc" -eq 0 ] && [ -z "$st" ] && [ "$same" = yes ] && [ ! -e "$w/$ARCH_REL" ] && [ "$said" = yes ]; } || ok_all=0
  done
  [ "$ok_all" -eq 1 ]
}

# IGN: ignored archive on the no-history path — refused, snapshot byte-identical, no archive.
arm_ign() {
  local w out rc; w="$(world ignored)" || { MSG="world copy failed"; return 1; }
  out="$(bash "$R_" "$w/$HIST_REL" --absorb "$w/$SNAP_REL" --apply 2>&1)"; rc=$?
  local same=no; cmp -s "$TMPL/ignored/$SNAP_REL" "$w/$SNAP_REL" && same=yes
  MSG="rc=${rc}, snapshot byte-identical=${same}, archive exists=$([ -e "$w/$ARCH_REL" ] && echo yes || echo no)"
  [ "$rc" -eq 1 ] && [ "$same" = yes ] && [ ! -e "$w/$ARCH_REL" ] && grep -q 'git-ignored' <<<"$out"
}

# UNWRITABLE: the archive path pre-created as a DIRECTORY, so no append to it can succeed whoever
# runs the fixture (a chmod-based world is writable by root). On the no-history path (absorb only)
# and on the above-floor path (rotation + absorb): rc 1, the snapshot byte-identical to its pre-run
# copy, and on the rotation path the history byte-identical too. The positive conjunct is the rc:
# a subject that emits nothing and exits 0 fails it.
arm_unw() {
  local s w pre hpre rc sid hid ok_all=1; MSG=""
  for s in nohist above; do
    w="$(world "$s")" || { MSG="world copy failed"; return 1; }
    mkdir -p "$w/$ARCH_REL" || { MSG="cannot pre-create the archive directory"; return 1; }
    pre="$(snap_copy "$w")" || { MSG="snapshot copy failed"; return 1; }
    hpre="$w.hist"; if [ -f "$w/$HIST_REL" ]; then cp "$w/$HIST_REL" "$hpre"; else : > "$hpre"; fi
    bash "$R_" "$w/$HIST_REL" --absorb "$w/$SNAP_REL" --apply >/dev/null 2>&1; rc=$?
    sid=no; cmp -s "$pre" "$w/$SNAP_REL" && sid=yes
    hid=n/a
    if [ "$s" = above ]; then hid=no; cmp -s "$hpre" "$w/$HIST_REL" && hid=yes; fi
    MSG="${MSG}${s}: rc=${rc} snapshot-identical=${sid} history-identical=${hid}; "
    { [ "$rc" -eq 1 ] && [ "$sid" = yes ] && [ "$hid" != no ]; } || ok_all=0
  done
  [ "$ok_all" -eq 1 ]
}

# ULIM: a REGULAR-FILE archive that fills up part-way through the append. The directory in arm_unw
# is refused by the `[ -f ]` guard alone, so it cannot tell a rotator carrying the write-status and
# growth checks from one carrying only `[ -f ]`; a `chmod 444` archive would, but root writes
# through it. `ulimit -f` binds root too. The archive is pre-filled to a few bytes under the limit
# (bash counts `ulimit -f` in 1024-byte units), so every append starts and none can finish. SIGXFSZ
# is ignored in the subshell so the writer gets EFBIG instead of dying, and the rotator inherits
# the ignored disposition across exec. On the no-history path and the rotation path: rc 1, and the
# snapshot and the history byte-identical to their pre-run copies. The archive was measured to
# have been appended to part-way (it grew and is at the limit), so the refusal is proven to be the
# append failing, not the run stopping before it.
ULIM_KIB=8
ULIM_FILL=$(( ULIM_KIB * 1024 - 40 ))
prefill_archive() {  # <world>: a regular-file archive ULIM_FILL bytes long, header first
  mkdir -p "$(dirname "$1/$ARCH_REL")" || return 1
  { printf '# Pipeline snapshot — archive\n\n'
    head -c "$ULIM_FILL" /dev/zero | tr '\0' 'x'; } | head -c "$ULIM_FILL" > "$1/$ARCH_REL"
  [ "$(fbytes "$1/$ARCH_REL")" -eq "$ULIM_FILL" ]
}
arm_ulim() {
  local s w pre hpre rc sid hid grew ok_all=1; MSG=""
  for s in nohist above; do
    w="$(world "$s")" || { MSG="world copy failed"; return 1; }
    prefill_archive "$w" || { MSG="cannot pre-fill the archive"; return 1; }
    pre="$(snap_copy "$w")" || { MSG="snapshot copy failed"; return 1; }
    hpre="$w.hist"; if [ -f "$w/$HIST_REL" ]; then cp "$w/$HIST_REL" "$hpre"; else : > "$hpre"; fi
    ( trap '' XFSZ; ulimit -f "$ULIM_KIB"; bash "$R_" "$w/$HIST_REL" --absorb "$w/$SNAP_REL" --apply ) >/dev/null 2>&1; rc=$?
    sid=no; cmp -s "$pre" "$w/$SNAP_REL" && sid=yes
    hid=n/a
    if [ "$s" = above ]; then hid=no; cmp -s "$hpre" "$w/$HIST_REL" && hid=yes; fi
    grew=no; [ "$(fbytes "$w/$ARCH_REL")" -gt "$ULIM_FILL" ] && grew=yes
    MSG="${MSG}${s}: rc=${rc} snapshot-identical=${sid} history-identical=${hid} archive-appended-part-way=${grew} ($(fbytes "$w/$ARCH_REL") bytes); "
    { [ "$rc" -eq 1 ] && [ "$sid" = yes ] && [ "$hid" != no ] && [ "$grew" = yes ]; } || ok_all=0
  done
  [ "$ok_all" -eq 1 ]
}

# WLATE / WSHORT: the write-status check and the growth check COVER EACH OTHER on every regular-file
# input `ulimit -f` can build. Measured over 3 body sizes x 3 limits x up to 10 prefill offsets (88
# appends, 68 of them failing): every failed append both exited non-zero AND grew short, so deleting
# either check alone leaves arm_ulim green. (A failed builtin `printf` also leaks its unwritten
# bytes into the next `$( )`, so the growth check sees a non-numeric size; it refuses that too.) Each check therefore gets a subject the other cannot
# see, forced by a `cat` shim ahead of the real one on PATH (the append's body is the rotator's
# only `cat` on the no-history path):
#   WLATE  — every byte lands, then the writer reports failure (a delayed write error on close).
#            Only the write-status check sees it: the growth is exact.
#   WSHORT — the last byte is dropped and the writer reports success. Only the growth check sees
#            it: the status is 0. This is the shape the growth check was written for (a group
#            answering with its last command), forced here because no real file produces it.
# Both: rc 1 and the snapshot byte-identical. The positive conjunct that the shim RAN is the
# archive's growth itself, asserted exact for WLATE and short-by-one for WSHORT.
REAL_CAT="$(command -v cat)"
SHIM="$WORK/shim"
mkdir -p "$SHIM/late" "$SHIM/short" || { echo "FIXTURE ERROR: cannot build the cat shims" >&2; exit 2; }
printf '#!/bin/sh\n"%s" "$@"\nexit 1\n' "$REAL_CAT" > "$SHIM/late/cat"
printf '#!/bin/sh\nn=$(wc -c < "$1")\nhead -c $((n - 1)) "$1"\nexit 0\n' > "$SHIM/short/cat"
chmod +x "$SHIM/late/cat" "$SHIM/short/cat" || { echo "FIXTURE ERROR: cannot chmod the cat shims" >&2; exit 2; }
arm_wshim() {  # <late|short>
  local w pre rc a0 a1 sid want; w="$(world nohist)" || { MSG="world copy failed"; return 1; }
  pre="$(snap_copy "$w")" || { MSG="snapshot copy failed"; return 1; }
  mkdir -p "$(dirname "$w/$ARCH_REL")" && printf '# Pipeline snapshot — archive\n\n' > "$w/$ARCH_REL" \
    || { MSG="cannot seed the archive"; return 1; }
  a0="$(fbytes "$w/$ARCH_REL")"
  PATH="$SHIM/$1:$PATH" bash "$R_" "$w/$HIST_REL" --absorb "$w/$SNAP_REL" --apply >/dev/null 2>&1; rc=$?
  a1="$(fbytes "$w/$ARCH_REL")"
  sid=no; cmp -s "$pre" "$w/$SNAP_REL" && sid=yes
  # header = "\n<!-- absorbed ... N lines -->\n\n"; body = the snapshot. The shim either lands all of
  # it (late) or all but one byte (short); anything else means the shim did not run as the arm says.
  want="$(( $(printf '\n<!-- absorbed whole snapshot from %s at fresh start: %s lines -->\n\n' "$(basename "$SNAP_REL")" "$(wc -l < "$pre" | tr -d ' ')" | wc -c) + $(wc -c < "$pre") ))"
  [ "$1" = short ] && want=$(( want - 1 ))
  MSG="shim=$1 rc=${rc} snapshot-identical=${sid} archive grew $(( a1 - a0 )) bytes (the shim writes ${want})"
  [ "$rc" -eq 1 ] && [ "$sid" = yes ] && [ "$(( a1 - a0 ))" -eq "$want" ]
}

# REW: the HISTORY REWRITE fails, after the archive append succeeded. The `bigtail` world is sized
# so every write before the rewrite fits under `ulimit -f` and the rewritten history does not. That
# sizing is PROVEN, not assumed: an unlimited control run on a second copy must rotate (rc 0) to a
# history whose preamble and kept tail are each under the limit and whose whole is over it, with the
# archive under it. Then, under the limit: rc 1, the refusal names the rewrite, the history is
# byte-identical to its pre-run copy, the snapshot byte-identical, every pre-run history line is
# still in the history or the archive, and the partial new history is kept at the path printed.
arm_rew() {
  local lim w c pre hpre out rc hid sid lost kept c_rc hb pb tb ab
  lim=$(( ULIM_KIB * 1024 ))
  c="$(world bigtail)" || { MSG="world copy failed"; return 1; }
  bash "$R_" "$c/$HIST_REL" --absorb "$c/$SNAP_REL" --apply >/dev/null 2>&1; c_rc=$?
  hb="$(fbytes "$c/$HIST_REL")"; ab="$(fbytes "$c/$ARCH_REL")"
  pb="$(awk '/^## /{exit} {print}' "$c/$HIST_REL" | wc -c | tr -d ' ')"
  tb=$(( ${hb:-0} - pb ))
  if ! { [ "$c_rc" -eq 0 ] && [ "${hb:-0}" -gt "$lim" ] && [ "$pb" -lt "$lim" ] && [ "$tb" -lt "$lim" ] \
         && [ -n "$ab" ] && [ "$ab" -lt "$lim" ]; }; then
    MSG="SEED CANNOT REACH THE REWRITE: unlimited control rc=${c_rc}, new history ${hb:-none} (preamble ${pb} + tail ${tb}), archive ${ab:-none}, limit ${lim}"
    return 1
  fi
  w="$(world bigtail)" || { MSG="world copy failed"; return 1; }
  pre="$(snap_copy "$w")" || { MSG="snapshot copy failed"; return 1; }
  hpre="$w.hist"; cp "$w/$HIST_REL" "$hpre" || { MSG="history copy failed"; return 1; }
  out="$( ( trap '' XFSZ; ulimit -f "$ULIM_KIB"; bash "$R_" "$w/$HIST_REL" --absorb "$w/$SNAP_REL" --apply ) 2>&1 >/dev/null )"; rc=$?
  hid=no; cmp -s "$hpre" "$w/$HIST_REL" && hid=yes
  sid=no; cmp -s "$pre" "$w/$SNAP_REL" && sid=yes
  sort -u "$hpre" > "$w.want"
  cat "$w/$HIST_REL" "$w/$ARCH_REL" 2>/dev/null | sort -u > "$w.have"
  lost="$(comm -23 "$w.want" "$w.have" | wc -l | tr -d ' ')"
  kept="$(sed -n 's/.*kept, not deleted, at: //p' <<<"$out" | head -1)"
  MSG="control: history ${hb} (preamble ${pb} + tail ${tb}) archive ${ab}, limit ${lim}; under the limit: rc=${rc} names-rewrite=$(grep -c 'writing the new history failed' <<<"$out") history-identical=${hid} ($(fbytes "$w/$HIST_REL") of $(fbytes "$hpre") bytes) snapshot-identical=${sid} pre-run lines in neither file=${lost} of $(wc -l < "$w.want" | tr -d ' ') kept-copy=${kept:-none}"
  [ "$rc" -eq 1 ] && grep -q 'writing the new history failed' <<<"$out" && [ "$hid" = yes ] && [ "$sid" = yes ] \
    && [ "$lost" -eq 0 ] && [ -s "$w.want" ] && [ -n "$kept" ] && [ -f "$kept" ]
}

# ARGS: on the no-history path an unknown option and an --absorb naming no file are both usage
# errors (rc 2), and neither touches the snapshot.
arm_args() {
  local w rc1 rc2; w="$(world nohist)" || { MSG="world copy failed"; return 1; }
  bash "$R_" "$w/$HIST_REL" --absorb "$w/$SNAP_REL" --no-such-option --apply >/dev/null 2>&1; rc1=$?
  bash "$R_" "$w/$HIST_REL" --absorb "$w/_bmad-output/no-such-snapshot.md" --apply >/dev/null 2>&1; rc2=$?
  local same=no; cmp -s "$TMPL/nohist/$SNAP_REL" "$w/$SNAP_REL" && same=yes
  MSG="unknown option rc=${rc1}, missing --absorb path rc=${rc2}, snapshot untouched=${same}"
  [ "$rc1" -eq 2 ] && [ "$rc2" -eq 2 ] && [ "$same" = yes ]
}

# IDEM: absorbing the now-empty snapshot again appends nothing.
arm_idem() {
  local w rc a0 a1 pre; w="$(world nohist)" || { MSG="world copy failed"; return 1; }
  pre="$(snap_copy "$w")" || { MSG="snapshot copy failed"; return 1; }
  bash "$R_" "$w/$HIST_REL" --absorb "$w/$SNAP_REL" --apply >/dev/null 2>&1
  a0="$(fbytes "$w/$ARCH_REL")"; [ -f "$w/$ARCH_REL" ] && cp "$w/$ARCH_REL" "$w/arch.first"
  bash "$R_" "$w/$HIST_REL" --absorb "$w/$SNAP_REL" --apply >/dev/null 2>&1; rc=$?
  a1="$(fbytes "$w/$ARCH_REL")"
  MSG="second absorb rc=${rc}, archive bytes ${a0:-none} -> ${a1:-none}, snapshot present=$([ -f "$w/$SNAP_REL" ] && echo yes || echo no)"
  [ "$rc" -eq 0 ] && [ -n "$a0" ] && [ "$a0" -gt 0 ] && cmp -s "$w/arch.first" "$w/$ARCH_REL" \
    && absorbed_ok "$w" "STALESNAP-nohist" "$pre"
}

ARMS="swap neg nohist floor above ign unw ulim wlate wshort rew args idem ro"
arm_run() {
  case "$1" in
    ulim)   arm_ulim ;;
    wlate)  arm_wshim late ;;
    wshort) arm_wshim short ;;
    rew)    arm_rew ;;
    swap)   arm_swap ;;
    neg)    arm_neg ;;
    nohist) arm_shape nohist 'no history at' ;;
    floor)  arm_shape floor '10 entr\(ies\) present, keeping 10' ;;
    above)  arm_shape above 'moved 4 entr\(ies\)' ;;
    ign)    arm_ign ;;
    unw)    arm_unw ;;
    args)   arm_args ;;
    idem)   arm_idem ;;
    ro)     arm_ro ;;
  esac
}
# run_arms <rotator> <continue hook> <pause hook>: sets FAILED to the space-separated failing arms.
run_arms() {
  R_="$1"; HC_="$2"; HP_="$3"; FAILED=""
  local a
  for a in $ARMS; do arm_run "$a" || FAILED="${FAILED} ${a}"; done
}

# --- The arms against the shipped subject ---------------------------------------------------
# The seed must hold every template, or each arm below reads a world nobody seeded.
for t in nohist floor above nosnap ignored bigtail; do
  [ -d "$TMPL/$t/.git" ] || { echo "FIXTURE BROKEN: seed template '$t' is not a repository" >&2; exit 2; }
done
[ -f "$TMPL/floor/$HIST_REL" ] && [ ! -e "$TMPL/nohist/$HIST_REL" ] && [ ! -e "$TMPL/nosnap/$SNAP_REL" ] \
  || { echo "FIXTURE BROKEN: seed templates do not carry the shapes the arms key on" >&2; exit 2; }

R_="$ROT"; HC_="$HOOK_C"; HP_="$HOOK_P"
for a in $ARMS; do
  case "$a" in
    swap)   what="ACROSS THE SWAP — after --absorb --apply the Stop hook still blocks and the pause hook still raises its flag" ;;
    neg)    what="NEGATIVE — a tree with no snapshot keeps both hooks silent" ;;
    nohist) what="absorb, NO history: whole snapshot is the archive's tail byte for byte, snapshot present at 0 bytes, archive tracked" ;;
    floor)  what="absorb, history at exactly --keep-entries cut points (no rotation): whole snapshot is the archive's tail byte for byte, snapshot present at 0 bytes, archive tracked" ;;
    above)  what="absorb, history above the floor (rotation, the control): whole snapshot is the archive's tail byte for byte, snapshot present at 0 bytes, archive tracked" ;;
    ign)    what="REFUSAL — ignored archive on the no-history path: rc 1, snapshot byte-identical" ;;
    unw)    what="REFUSAL — archive path is a directory (unwritable), on no history and on the rotation path: rc 1, snapshot byte-identical, history byte-identical" ;;
    ulim)   what="REFUSAL — a regular-file archive that fills up mid-append (ulimit -f, binds root too), on no history and on the rotation path: rc 1, the archive appended part-way, snapshot and history byte-identical" ;;
    wlate)  what="REFUSAL — every byte appended but the writer reports failure: rc 1, snapshot byte-identical (only the write-status check sees this)" ;;
    wshort) what="REFUSAL — one byte short and the writer reports success: rc 1, snapshot byte-identical (only the growth check sees this)" ;;
    rew)    what="REFUSAL — the history REWRITE fails after the archive append succeeded (ulimit -f, sizing proven by an unlimited control): rc 1, history and snapshot byte-identical, no pre-run history line in neither file, the partial copy kept at the printed path" ;;
    args)   what="USAGE on the no-history path — unknown option rc 2, --absorb naming no file rc 2" ;;
    idem)   what="idempotent — absorbing the already-empty snapshot appends nothing" ;;
    ro)     what="REPORT-ONLY — --absorb without --apply on no history, the floor and above it writes nothing (git status empty, snapshot byte-identical, no archive) and says what it would do" ;;
  esac
  if arm_run "$a"; then ok "$what"; else bad "$what ($MSG)"; fi
done

# --- MUTANTS of the absorb swap ---------------------------------------------------------------
# Each is a copy with ONE edit, keyed on a line the subject carries exactly once, and asserted to
# have applied (the anchor count goes 1 -> 0 and the copy differs) before its verdict is read. The
# copies are driven by the SAME arms, and an unmutated copy from the same directory is driven
# first: it must pass every arm, so a mutant verdict is a verdict about the edit, not the harness.
# The hooks' copies carry their schema siblings, because both hooks resolve `../schemas/`.
MD="$WORK/mut"
mkdir -p "$MD/hooks" "$MD/schemas" || { echo "FIXTURE ERROR: cannot build mutant tree" >&2; exit 2; }
cp "$HOOKDIR"/*.sh "$MD/hooks/" && cp "$HOOKDIR/../schemas/"*.json "$MD/schemas/" \
  || { echo "FIXTURE ERROR: cannot copy the hooks and schemas" >&2; exit 2; }
cp "$ROT" "$MD/rot-control.sh"

# mut_line <src> <dst> <old line> <new line>: exact whole-line replacement. 0 = applied.
mut_line() {
  local pre post
  pre="$(grep -cxF -- "$3" "$1")" || pre=0
  [ "$pre" -eq 1 ] || return 1
  awk -v a="$3" -v b="$4" '$0 == a { print b; next } { print }' "$1" > "$2" || return 1
  post="$(grep -cxF -- "$3" "$2")" || post=0
  [ "$post" -eq 0 ] && ! cmp -s "$1" "$2"
}
# mut_before <src> <dst> <anchor line> <inserted line>: insert a line before the anchor.
mut_before() {
  local pre
  pre="$(grep -cxF -- "$3" "$1")" || pre=0
  [ "$pre" -eq 1 ] || return 1
  awk -v a="$3" -v b="$4" '$0 == a { print b } { print }' "$1" > "$2" || return 1
  grep -qxF -- "$4" "$2" && ! cmp -s "$1" "$2"
}

run_arms "$MD/rot-control.sh" "$MD/hooks/ai-dlc-continue.sh" "$MD/hooks/ai-dlc-pause.sh"
if [ -z "$FAILED" ]; then
  ok "MUTANT CONTROL: the unmutated copies in the mutant tree pass every arm — the harness runs"
else
  bad "MUTANT CONTROL: the unmutated copies FAILED:${FAILED} — no mutant verdict below is evidence"
fi

# score <label> <must-fail arm> <rotator> <continue> <pause> <what>
score() {
  run_arms "$3" "$4" "$5"
  case " ${FAILED} " in
    *" $2 "*) ok "$1 KILLED by '$2' (failing arms:${FAILED}) — $6" ;;
    *)        bad "$1 SURVIVED: arm '$2' did not fail (failing arms:${FAILED:- none}) — $6" ;;
  esac
}
CH="$MD/hooks/ai-dlc-continue.sh"; PH="$MD/hooks/ai-dlc-pause.sh"

if mut_line "$ROT" "$MD/m1.sh" '  [ "$ABSORB_DID" -eq 1 ] && : > "$ABSORB"' '  [ "$ABSORB_DID" -eq 1 ] && rm -f "$ABSORB"'; then
  score m1 swap "$MD/m1.sh" "$CH" "$PH" "the absorb REMOVES the snapshot instead of truncating it"
else bad "m1 DID NOT APPLY — the truncate line is not in the rotator exactly once"; fi

if mut_line "$ROT" "$MD/m2.sh" 'absorb_only() {' 'absorb_only() { return 0'; then
  score m2 floor "$MD/m2.sh" "$CH" "$PH" "the absorb is re-gated behind the rotation path"
else bad "m2 DID NOT APPLY — 'absorb_only() {' is not in the rotator exactly once"; fi

if mut_before "$ROT" "$MD/m3.sh" 'APPLY=0' 'if [ ! -f "$HISTORY" ]; then echo "no history at $HISTORY"; exit 0; fi'; then
  score m3 args "$MD/m3.sh" "$CH" "$PH" "the history-absent exit sits above the argument loop again"
else bad "m3 DID NOT APPLY — 'APPLY=0' is not in the rotator exactly once"; fi

if mut_line "$ROT" "$MD/m4.sh" '  refuse_if_archive_ignored' '  :'; then
  score m4 ign "$MD/m4.sh" "$CH" "$PH" "REFUSAL 3 is dropped from the absorb path"
else bad "m4 DID NOT APPLY — the absorb path's refusal call is not in the rotator exactly once"; fi

# m5 / m6: the negative arm is ABSENCE-shaped (it demands silence), so only a mutant establishes
# it discriminates. Delete each hook's snapshot-existence predicate and it must go red.
if mut_line "$CH" "$MD/hooks/m5-continue.sh" 'if [ ! -f "$SNAPSHOT_FILE" ]; then' 'if false; then'; then
  score m5 neg "$MD/rot-control.sh" "$MD/hooks/m5-continue.sh" "$PH" "ai-dlc-continue.sh's snapshot-existence predicate deleted"
else bad "m5 DID NOT APPLY — the Stop hook's snapshot predicate is not in it exactly once"; fi

if mut_line "$PH" "$MD/hooks/m6-pause.sh" 'if [ ! -f "$SNAPSHOT_FILE" ]; then' 'if false; then'; then
  score m6 neg "$MD/rot-control.sh" "$CH" "$MD/hooks/m6-pause.sh" "ai-dlc-pause.sh's snapshot-existence predicate deleted"
else bad "m6 DID NOT APPLY — the pause hook's snapshot predicate is not in it exactly once"; fi

# m7: a LOSSY absorb that keeps only the marker line. The marker-grep arms passed it; the
# whole-content comparison in absorbed_ok is what kills it. The lossy body is handed to the
# rotator's own verified append as a FILE, so the append's growth check (header + body bytes)
# is satisfied and cannot be what kills it — the mutant exits 0 and only the content differs.
M7_OLD='  archive_append "${NL}<!-- absorbed whole snapshot from $(basename "$ABSORB") at fresh start: ${A_LINES} lines -->${NL}${NL}" "$ABSORB"'
M7_NEW='  M7="${ABSORB}.m7"; grep -E STALE "$ABSORB" > "$M7"; archive_append "${NL}<!-- absorbed whole snapshot from $(basename "$ABSORB") at fresh start: ${A_LINES} lines -->${NL}${NL}" "$M7"'
if mut_line "$ROT" "$MD/m7.sh" "$M7_OLD" "$M7_NEW"; then
  score m7 nohist "$MD/m7.sh" "$CH" "$PH" "the absorb copies only the marker line instead of the whole snapshot"
else bad "m7 DID NOT APPLY — the absorb's archive_append call is not in the rotator exactly once"; fi

# m8: every append guard reports through archive_fail, so making it RETURN instead of exit removes
# each layer at once (not-a-regular-file, failed write, short growth). The unwritable arm dies.
if mut_line "$ROT" "$MD/m8.sh" 'archive_fail() {' 'archive_fail() { return 0'; then
  score m8 unw "$MD/m8.sh" "$CH" "$PH" "a failed archive append no longer stops the run before the truncate"
else bad "m8 DID NOT APPLY — 'archive_fail() {' is not in the rotator exactly once"; fi

# m9: the report-only arm is ABSENCE-shaped (it demands that nothing is written), so a mutant
# must prove it can fail: make the absorb-only path ignore report-only mode.
if mut_line "$ROT" "$MD/m9.sh" '  if [ "$APPLY" -eq 0 ]; then' '  if false; then'; then
  score m9 ro "$MD/m9.sh" "$CH" "$PH" "the absorb-only path writes even without --apply"
else bad "m9 DID NOT APPLY — absorb_only's report-only branch is not in the rotator exactly once"; fi

# m10 / m11 / m13: the three layers of the archive-append guard. `[ -f ]` refuses a non-file, the
# write-status check refuses a writer that failed, the growth check refuses a short append. On
# every `ulimit -f` input measured the last two cover each other (see arm_wshim), so each is killed
# by the shim arm the other cannot see, and the ulimit arm kills the variant keeping ONLY `[ -f ]`
# — the one that exits 0 and empties the snapshot behind a read-only or full archive.
M10_OLD='  { printf '"'"'%s'"'"' "$hdr"; cat "$body"; } >> "$ARCHIVE" || archive_fail "the write failed"'
M10_NEW='  { printf '"'"'%s'"'"' "$hdr"; cat "$body"; } >> "$ARCHIVE"'
# The growth check is TWO lines, and both go: its numeric-operand guard and its comparison. Deleting
# only the comparison leaves the guard refusing the non-numeric size a failed builtin `printf` leaks
# into the next substitution, which is a partial revert that proves the layer left in place.
M11_OLD='  if ! [ "$after" -eq "$(( before + b_hdr + b_body ))" ]; then'
M11G_OLD='  case "${before}${after}${b_hdr}${b_body}" in '"''"'|*[!0-9]*) archive_fail "a size read back as non-numeric" ;; esac'
mut_growth() {  # <src> <dst>: delete both lines of the growth check
  mut_line "$1" "$2.g" "$M11G_OLD" '  :' && mut_line "$2.g" "$2" "$M11_OLD" '  if false; then'
}
if mut_line "$ROT" "$MD/m10.sh" "$M10_OLD" "$M10_NEW"; then
  score m10 wlate "$MD/m10.sh" "$CH" "$PH" "the append's write-status check deleted"
else bad "m10 DID NOT APPLY — the append's write-status line is not in the rotator exactly once"; fi

if mut_growth "$ROT" "$MD/m11.sh"; then
  score m11 wshort "$MD/m11.sh" "$CH" "$PH" "the append's byte-growth check deleted (its numeric guard and its comparison)"
else bad "m11 DID NOT APPLY — a line of the growth check is not in the rotator exactly once"; fi

if mut_line "$ROT" "$MD/m13a.sh" "$M10_OLD" "$M10_NEW" && mut_growth "$MD/m13a.sh" "$MD/m13.sh"; then
  score m13 ulim "$MD/m13.sh" "$CH" "$PH" "only the [ -f ] guard left: both the write-status and the growth checks deleted"
else bad "m13 DID NOT APPLY — the write-status line or the growth check is not in the rotator exactly once"; fi

# m12: the history is rewritten IN PLACE again. The truncating open cuts the history the moment the
# write fails, so the rewrite arm dies; the copy to the temp name keeps every other path unchanged.
M12_OLD='( set -C; cat "$TMPD/preamble" "$TMPD/tail" > "$HIST_NEW" ) || rewrite_fail "the write failed"'
M12_NEW='cat "$TMPD/preamble" "$TMPD/tail" > "$HISTORY" || rewrite_fail "the write failed"; cp "$HISTORY" "$HIST_NEW"'
if mut_line "$ROT" "$MD/m12.sh" "$M12_OLD" "$M12_NEW"; then
  score m12 rew "$MD/m12.sh" "$CH" "$PH" "the history is rewritten in place (cat preamble tail > history)"
else bad "m12 DID NOT APPLY — the history write line is not in the rotator exactly once"; fi

echo
if [ "$fails" -eq 0 ]; then
  echo "snapshot-archive-rotate: PASS"
else
  echo "snapshot-archive-rotate: FAIL ($fails)" >&2; exit 1
fi
