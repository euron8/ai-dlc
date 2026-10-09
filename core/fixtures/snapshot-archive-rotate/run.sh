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
# A `chflags uchg` file cannot be unlinked, and MCF leaves killed worlds carrying one under $WORK, so
# the flag is cleared HERE, before the remove, where an interrupted run (TERM during the MCF sweep)
# still reaches it. `chflags` is BSD-only; where it is absent no such flag can have been set.
#
# AN INTERRUPT MUST REAP THE SWEEP BEFORE IT REMOVES ANYTHING. The kill-point sweep runs KPAR
# background workers, each a tree (worker -> subshell -> rotator -> its children), and only `wait`
# reaped them: a TERM to this shell ran the EXIT handler while every worker kept copying worlds into
# $WORK, so the `rm -rf` raced live writers and the tree came back (5k to 42k entries left in 7 of 10
# interrupted runs). So TERM and INT exit through the EXIT handler, and the handler, before its first
# removal, ignores TERM and INT itself (a second TERM landing during `chflags -R` otherwise killed
# bash before `rm` and left the whole sandbox) and reaps every worker's TREE: each process is stopped
# before its children are listed, so none can fork past the walk, then killed.
KPIDS=""
reap_tree() {  # <pid>: stop it, reap its descendants depth-first, then kill it
  local c
  kill -STOP "$1" 2>/dev/null
  for c in $(pgrep -P "$1" 2>/dev/null); do reap_tree "$c"; done
  kill -KILL "$1" 2>/dev/null
}
fixture_cleanup() {
  trap '' TERM INT
  local p
  for p in $KPIDS; do reap_tree "$p"; done
  for p in $KPIDS; do wait "$p" 2>/dev/null; done
  if command -v chflags >/dev/null 2>&1; then chflags -R nouchg "$WORK" 2>/dev/null; fi
  rm -rf "$WORK"
}
# TERM and INT exit explicitly so the EXIT handler runs on every bash, not only where an untrapped
# fatal signal happens to run it. Measured with a forced TERM mid-sweep in a scratch copy on bash 3.2:
# 0 entries left under the caller's TMPDIR; with the reap loop deleted, 9 rotator temp dirs; the
# unfixed fixture, 28.
trap fixture_cleanup EXIT
trap 'exit 143' TERM
trap 'exit 130' INT
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
echo "HERMETIC-CONSUMED core/scripts/rotate-snapshot-archive.sh"
echo "HERMETIC-CONSUMED core/hooks/ai-dlc-continue.sh"
echo "HERMETIC-CONSUMED core/hooks/ai-dlc-pause.sh"
# The hooks load these siblings only when present and fail open on absence, so the sentinel is guarded.
[ -f "$HOOKDIR/ai-dlc-handoff-pending.sh" ] && echo "HERMETIC-CONSUMED core/hooks/ai-dlc-handoff-pending.sh"
[ -f "$HOOKDIR/ai-dlc-context-provenance.sh" ] && echo "HERMETIC-CONSUMED core/hooks/ai-dlc-context-provenance.sh"
_PRS=""; for _c in "$HERE/../../schemas/pause-routing.json" "$HERE/../../../.claude/schemas/pause-routing.json"; do [ -f "$_c" ] && { _PRS="$_c"; break; }; done
[ -n "$_PRS" ] && echo "HERMETIC-CONSUMED core/schemas/pause-routing.json"
_HOS=""; for _c in "$HERE/../../schemas/harness-origin.json" "$HERE/../../../.claude/schemas/harness-origin.json"; do [ -f "$_c" ] && { _HOS="$_c"; break; }; done
[ -n "$_HOS" ] && echo "HERMETIC-CONSUMED core/schemas/harness-origin.json"
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

# REW: the HISTORY REWRITE fails under a real resource limit. The `bigtail` world is sized so that
# every file the rotator writes into its own temp directory fits under `ulimit -f` and the new
# history does not. That sizing is PROVEN, not assumed: an unlimited control run on a second copy
# must rotate (rc 0) to a history whose preamble and kept tail are each under the limit and whose
# whole is over it, with the archive under it. Then, under the limit: rc 1, the refusal names the
# rewrite, the history and the snapshot byte-identical, no archive created (the new history is
# built BEFORE the archive append), and every pre-run history line still in the history. The temp
# files left count is reported; the arm that owns "no temp left" is atomic. Under the rename design the first write to fail is the `cp -p` of the old
# history onto the temp file, which is larger than the new one; no input `ulimit -f` can build
# reaches the content write alone, so the content write's guards are owned by tlate/tshort.
arm_rew() {
  local lim w c pre hpre out rc hid sid lost c_rc hb pb tb ab nt
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
  nt="$(tmpcount "$w")"
  MSG="control: history ${hb} (preamble ${pb} + tail ${tb}) archive ${ab}, limit ${lim}; under the limit: rc=${rc} names-rewrite=$(grep -c 'writing the new history failed' <<<"$out") history-identical=${hid} snapshot-identical=${sid} archive=$([ -e "$w/$ARCH_REL" ] && echo yes || echo no) pre-run lines in neither file=${lost} of $(wc -l < "$w.want" | tr -d ' ') temp files left=${nt}"
  [ "$rc" -eq 1 ] && grep -q 'writing the new history failed' <<<"$out" && [ "$hid" = yes ] && [ "$sid" = yes ] \
    && [ ! -e "$w/$ARCH_REL" ] && [ "$lost" -eq 0 ] && [ -s "$w.want" ]
}

# --- THE HISTORY REWRITE: build a temp file beside the history, verify it, rename it over -------
# Order: prechecks (symlink, hard links, history writable, directory writable, sticky directory),
# then build the temp (mktemp in the history's directory, `cp -p`, write, size check), then the
# archive append, then `mv -f temp history`, then the snapshot truncate. Nothing ever writes INTO
# the history, so there is no partial history to recover from.
#
# Every guard gets a subject no other guard can see, forced where no real file produces it:
#   tlate / tshort   a `cat` shim on the temp write (the one call whose first argument ends
#                    `/preamble`) writes every byte then exits 1 / drops one byte and exits 0.
#                    Only the write's status check / size check sees each. Both refuse BEFORE the
#                    archive append, so the archive is asserted absent.
#   rohist / rodir   a 444 history / a 555 history directory: refused before any write.
#   links            a symlinked history and a hard-linked history: refused before any write.
#   mode             a 640 history keeps 640 across the rename (`cp -p`).
#   atomic           an `mv` shim fails the rename WITHOUT renaming: rc 1, the history
#                    byte-identical, and no temp file left.
#   killed           a KILL-POINT SWEEP: the rotator is SIGKILLed at its Nth external command,
#                    for EVERY N, each followed by a plain re-run (see arm_killed); plus a kill
#                    at the staging without --absorb, then re-run plainly.
#
# A shim that acts does it itself: it appends its mode to a sentinel file and exits without calling
# the real program. Nothing outlives the act, and there is no watcher polling a process table.
# Every shim arm asserts the sentinel counted exactly one action, so an arm whose shim never fired
# cannot pass.
TMPNAME=".pipeline-snapshot-history.md.rotate"
tmpcount() { local n; n="$(ls -a "$1/_bmad-output" | grep -c "^${TMPNAME}\.")" || n=0; printf '%s\n' "$n"; }
REAL_MV="$(command -v mv)"
REAL_GIT="$(command -v git)"
RSHIM="$SHIM/rw"
GSHIM="$SHIM/git"
mkdir -p "$RSHIM" "$GSHIM" || { echo "FIXTURE ERROR: cannot build the rewrite shims" >&2; exit 2; }
cat > "$RSHIM/cat" <<'SHIMEOF'
#!/bin/sh
R="$SNAPROT_REAL_CAT"; m="${SNAPROT_SHIM_MODE:-}"; hit=""
case "$m:$#:${1:-}" in
  tlate:2:*/preamble|tshort:2:*/preamble) hit=1 ;;
esac
[ -n "$hit" ] || exec "$R" "$@"
printf '%s\n' "$m" >> "$SNAPROT_SHIM_SENT"
case "$m" in
  tlate) "$R" "$@"; exit 1 ;;
  tshort) "$R" "$@" > "$SNAPROT_SHIM_SENT.buf" || exit 1
          n=$(wc -c < "$SNAPROT_SHIM_SENT.buf"); head -c $((n - 1)) "$SNAPROT_SHIM_SENT.buf"; exit 0 ;;
esac
SHIMEOF
cat > "$RSHIM/mv" <<'SHIMEOF'
#!/bin/sh
case "${SNAPROT_SHIM_MODE:-}" in
  mvfail) printf 'mvfail\n' >> "$SNAPROT_SHIM_SENT"; exit 1 ;;
esac
exec "$SNAPROT_REAL_MV" "$@"
SHIMEOF
cat > "$GSHIM/git" <<'SHIMEOF'
#!/bin/sh
if [ "${SNAPROT_SHIM_MODE:-}" = gitkill ] && [ "${3:-}" = add ]; then
  printf 'gitkill\n' >> "$SNAPROT_SHIM_SENT"; kill -KILL "$PPID"; exit 1
fi
if [ "${SNAPROT_SHIM_MODE:-}" = gitfail ] && [ "${3:-}" = add ]; then
  printf 'gitfail\n' >> "$SNAPROT_SHIM_SENT"; exit 1
fi
exec "$SNAPROT_REAL_GIT" "$@"
SHIMEOF
chmod +x "$RSHIM/cat" "$RSHIM/mv" "$GSHIM/git" || { echo "FIXTURE ERROR: cannot chmod the rewrite shims" >&2; exit 2; }

# THE KILL-POINT SWEEP'S TRACE. The sweep is not a set of PATH shims: a shim sees only a command
# resolved through PATH, so a write-through spelled with builtins (`while read; do printf; done >
# history`), with an absolute path (`/bin/cat x > history`) or with `command -p` never reached it,
# and three such rotators lost 18-21 lines each while the shim sweep and the receipt both passed.
# Instead the rotator's OWN shell is traced: `BASH_ENV` names the file below, which bash sources
# before the rotator's first line. It sets `set -T` (functions, command substitutions and subshells
# inherit the trap) and a DEBUG trap, which bash runs before every simple command -- builtin,
# function call, assignment, absolute-path or `command -p` external, redirection-only command, in
# the main shell or any subshell, and inside an EXIT or ERR trap handler, whether the command is
# written inline in the handler's string or in a function the handler calls. Measured on bash
# 3.2.57 and 5.2.15 with this file: a 3000-byte write inline in an EXIT handler is cut at 1024
# bytes by a kill point, as one in a called function and one in the main body are. (A reading of
# `$BASH_COMMAND` inside a handler does not name the handler's commands, which is how an earlier
# revision came to say a handler was untraced.) The rotator's only trap is inline:
# `trap 'rm -rf "$TMPD"' EXIT`. MT pins this: a write-through inline in that handler is killed.
# BASH_ENV is NOT unset, so a CHILD `bash` the rotator starts plainly (`bash -c '...'`, a bash
# helper script) sources the same file and its simple commands are points too, numbered in the
# same counter: a write-through done in such a child is killed part-way like one in the rotator's
# own shell (MH). With the unset in place, MH passed the sweep and lost 6 of 37 lines once it was
# removed. A child bash started as `bash --posix`, as `bash -p`, with POSIXLY_CORRECT set, or under
# `env -i` does NOT source BASH_ENV, so it is untraced. The shipped rotator starts no child bash, so
# its point count is the same either way.
#
# Each simple command claims the next number. THE COUNTER IS AN O_EXCL CREATE, BECAUSE PIPELINE
# STAGES AND COMMAND SUBSTITUTIONS RUN THE TRAP IN THEIR OWN PROCESSES, CONCURRENTLY. A read-add-write
# counter races there (two stages read the same value and both write n+1, and a later N is never
# reached). Under `set -C` a `>` onto an absent file is an O_EXCL create, which is atomic: the trap
# claims the first free number above the hint, so every point gets a distinct number and the numbers
# are dense. The claim writes NO byte, so it succeeds under a 0-block limit; the command text is
# appended after it and may fail there (a claim loop keyed on a write that fails never ends). All of
# it is builtins; the trap forks nothing.
#
# At point N the trap ignores SIGXFSZ and sets the shell's file-size limit to SNAPROT_KL blocks of
# 1024 bytes, so command N runs to its end under that limit: at 0 it can open, truncate, create,
# rename and remove, and write no byte into a regular file; at 1 it writes the first 1024 bytes of a
# longer file and then fails. At point N+1 -- the next simple command anywhere in the rotator -- the
# trap SIGKILLs the rotator (`$$` is the rotator's pid in every subshell). Point N's command text is
# recorded, so a failure names the command it killed after.
KENV="$WORK/sweep-env.sh"
cat > "$KENV" <<'ENVEOF'
set -T
trap '_kp_n=""; read -r _kp_n < "$SNAPROT_KC/h"; _kp_n=$(( ${_kp_n:-0} + 1 )); case $- in *C*) _kp_c=1 ;; *) _kp_c="" ;; esac; set -C; while ! : 2>/dev/null > "$SNAPROT_KC/$_kp_n"; do _kp_n=$(( _kp_n + 1 )); done; [ -n "$_kp_c" ] || set +C; printf "%s\n" "$BASH_COMMAND" 2>/dev/null >> "$SNAPROT_KC/$_kp_n"; echo "$_kp_n" 2>/dev/null >| "$SNAPROT_KC/h"; if [ "$_kp_n" -eq "$SNAPROT_KN" ]; then trap "" XFSZ; ulimit -f "$SNAPROT_KL"; elif [ "$SNAPROT_KN" -gt 0 ] && [ "$_kp_n" -gt "$SNAPROT_KN" ]; then kill -KILL $$; exit 137; fi' DEBUG
ENVEOF
# The kill-point sweep runs this many workers at once; every kill point has its own world, its own
# TMPDIR and its own counter. KL is the limit at the point, in 1024-byte blocks: 1, so a write of a
# longer file lands part-way (arm_killed asserts the seed makes both histories longer than that).
KPAR=12
KL=1
KSTRIDE=8
# The forms that turn the sweep's trace off from inside the rotator (see arm_killed's header).
# Self-probe, both directions, before any rotator is read: each escape form matches, and the
# shipped rotator's own `set` and `trap` lines do not.
KESC_RE='set[[:blank:]]+\+[A-Za-z]*T|set[[:blank:]]+\+o[[:blank:]]+functrace|trap[[:blank:]].*DEBUG'
for _k in 'set +T' 'set +eT' 'set +o functrace' 'trap - DEBUG' "trap '' DEBUG"; do
  grep -qE "$KESC_RE" <<<"$_k" || { echo "FIXTURE BROKEN: KESC_RE does not match '$_k'" >&2; exit 2; }
done
for _k in 'set -uo pipefail' "trap 'rm -rf \"\$TMPD\"' EXIT" 'set -T'; do
  grep -qE "$KESC_RE" <<<"$_k" && { echo "FIXTURE BROKEN: KESC_RE matches the near-miss '$_k'" >&2; exit 2; }
done

# The expected new history of the `above` world, from the SHIPPED rotator on an unmodified copy, so a
# mutant under test cannot move its own yardstick. Asserted to differ from the pre-run history.
EXPECT="$WORK/expect.above"
expect_above() {
  [ -s "$EXPECT" ] && return 0
  local c; c="$(world above)" || return 1
  bash "$ROT" "$c/$HIST_REL" --apply >/dev/null 2>&1 || return 1
  cp "$c/$HIST_REL" "$EXPECT" && ! cmp -s "$EXPECT" "$TMPL/above/$HIST_REL" && [ -s "$EXPECT" ]
}
fmode() { ls -l "$1" | cut -c1-10; }

# rshim <mode> <world> [PATH prefix]: drive the rotator on the world with a shim, sets OUT/RC/SENT.
# TMPDIR inside WORK: a SIGKILLed rotator never runs its EXIT trap, so its mktemp dir is left.
rshim() {
  local sent="$2.sent"; : > "$sent"
  OUT="$(TMPDIR="$WORK" SNAPROT_REAL_CAT="$REAL_CAT" SNAPROT_REAL_MV="$REAL_MV" SNAPROT_REAL_GIT="$REAL_GIT" \
    SNAPROT_SHIM_MODE="$1" SNAPROT_SHIM_SENT="$sent" \
    PATH="${3:-$RSHIM}:$PATH" bash "$R_" "$2/$HIST_REL" ${4:+--absorb "$2/$SNAP_REL"} --apply 2>&1)"; RC=$?
  SENT="$(grep -c "^$1\$" "$sent")" || SENT=0
}

# tlate / tshort: the temp write fails. Refused before the archive append: the history and the
# snapshot byte-identical, no archive. (The temp files left count is reported; atomic owns it.)
arm_tshim() {  # <tlate|tshort>
  local w pre hpre hid sid nt; w="$(world above)" || { MSG="world copy failed"; return 1; }
  pre="$(snap_copy "$w")" || { MSG="snapshot copy failed"; return 1; }
  hpre="$w.hist"; cp "$w/$HIST_REL" "$hpre" || { MSG="history copy failed"; return 1; }
  rshim "$1" "$w" "$RSHIM" absorb
  hid=no; cmp -s "$hpre" "$w/$HIST_REL" && hid=yes
  sid=no; cmp -s "$pre" "$w/$SNAP_REL" && sid=yes
  nt="$(tmpcount "$w")"
  MSG="shim=$1 acted ${SENT}x, rc=${RC}, names-rewrite=$(grep -c 'writing the new history failed' <<<"$OUT"), history-identical=${hid}, snapshot-identical=${sid}, archive=$([ -e "$w/$ARCH_REL" ] && echo yes || echo no), temp files left=${nt}"
  [ "$SENT" -eq 1 ] && [ "$RC" -eq 1 ] && grep -q 'writing the new history failed' <<<"$OUT" \
    && [ "$hid" = yes ] && [ "$sid" = yes ] && [ ! -e "$w/$ARCH_REL" ]
}

# rohist: a read-only history is refused before any write. `[ -w ]` is true for root on a 444 file
# and so is the write, so under root the world cannot express the subject: the arm says SKIP in its
# own message and m14's score line says it too, rather than reading as a pass.
ROHIST_SKIP=""
arm_rohist() {
  local w pre hpre hid sid; w="$(world above)" || { MSG="world copy failed"; return 1; }
  pre="$(snap_copy "$w")" || { MSG="snapshot copy failed"; return 1; }
  hpre="$w.hist"; cp "$w/$HIST_REL" "$hpre" || { MSG="history copy failed"; return 1; }
  chmod 444 "$w/$HIST_REL" || { MSG="chmod failed"; return 1; }
  if [ -w "$w/$HIST_REL" ]; then ROHIST_SKIP=yes; MSG="SKIP: a 444 file is writable to this user (root)"; return 0; fi
  OUT="$(bash "$R_" "$w/$HIST_REL" --absorb "$w/$SNAP_REL" --apply 2>&1)"; RC=$?
  chmod 644 "$w/$HIST_REL"
  hid=no; cmp -s "$hpre" "$w/$HIST_REL" && hid=yes
  sid=no; cmp -s "$pre" "$w/$SNAP_REL" && sid=yes
  MSG="rc=${RC}, names not-writable=$(grep -c 'the history is not writable' <<<"$OUT"), archive exists=$([ -e "$w/$ARCH_REL" ] && echo yes || echo no), history-identical=${hid}, snapshot-identical=${sid}"
  [ "$RC" -eq 1 ] && grep -q 'the history is not writable' <<<"$OUT" && [ ! -e "$w/$ARCH_REL" ] \
    && [ "$hid" = yes ] && [ "$sid" = yes ]
}

# rosnap: a read-only snapshot. The append succeeds and the truncate cannot. The rotator must say so,
# exit 1, and leave the snapshot's size unchanged -- never print "truncated it to 0 bytes" over a
# full file. Under root a 444 file is writable: SKIP, as rohist does.
arm_rosnap() {
  local w b0 b1; w="$(world nohist)" || { MSG="world copy failed"; return 1; }
  b0="$(fbytes "$w/$SNAP_REL")"
  chmod 444 "$w/$SNAP_REL" || { MSG="chmod failed"; return 1; }
  if [ -w "$w/$SNAP_REL" ]; then ROHIST_SKIP=yes; MSG="SKIP: a 444 file is writable to this user (root)"; return 0; fi
  OUT="$(bash "$R_" "$w/$HIST_REL" --absorb "$w/$SNAP_REL" --apply 2>&1)"; RC=$?
  b1="$(fbytes "$w/$SNAP_REL")"
  chmod 644 "$w/$SNAP_REL"
  MSG="rc=${RC}, snapshot ${b0} -> ${b1} bytes, says archived but not emptied=$(grep -c 'archived but NOT emptied' <<<"$OUT"), claims truncated=$(grep -c 'truncated it to 0 bytes' <<<"$OUT")"
  [ "$RC" -eq 1 ] && [ -n "$b0" ] && [ "$b0" -gt 0 ] && [ "$b1" = "$b0" ] && grep -q 'archived but NOT emptied' <<<"$OUT"
}

# rodir: a writable history in a directory that is not writable (555). `[ -w history ]` passes, and
# no temp file can be created beside it. Refused before any write: the archive stays absent, on the
# first run and on a second one. The archive's own directory is pre-created so that only the
# history's directory is locked. Under root a 555 directory is writable: SKIP, as rohist does.
arm_rodir() {
  local w pre hpre rc2 a1 a2 sid hid
  w="$(world above)" || { MSG="world copy failed"; return 1; }
  mkdir -p "$w/$(dirname "$ARCH_REL")" || { MSG="cannot pre-create the archive directory"; return 1; }
  pre="$(snap_copy "$w")" || { MSG="snapshot copy failed"; return 1; }
  hpre="$w.hist"; cp "$w/$HIST_REL" "$hpre" || { MSG="history copy failed"; return 1; }
  chmod 555 "$w/_bmad-output" || { MSG="chmod failed"; return 1; }
  if [ -w "$w/_bmad-output" ]; then chmod 755 "$w/_bmad-output"; ROHIST_SKIP=yes; MSG="SKIP: a 555 directory is writable to this user (root)"; return 0; fi
  if [ ! -w "$w/$HIST_REL" ]; then chmod 755 "$w/_bmad-output"; MSG="SEED WRONG: the history itself is not writable"; return 1; fi
  OUT="$(bash "$R_" "$w/$HIST_REL" --absorb "$w/$SNAP_REL" --apply 2>&1)"; RC=$?
  a1="$(fbytes "$w/$ARCH_REL")"
  bash "$R_" "$w/$HIST_REL" --absorb "$w/$SNAP_REL" --apply >/dev/null 2>&1; rc2=$?
  a2="$(fbytes "$w/$ARCH_REL")"
  chmod 755 "$w/_bmad-output"
  hid=no; cmp -s "$hpre" "$w/$HIST_REL" && hid=yes
  sid=no; cmp -s "$pre" "$w/$SNAP_REL" && sid=yes
  MSG="rc=${RC} then ${rc2}, names the directory=$(grep -c "directory is not writable" <<<"$OUT"), archive bytes ${a1:-absent} then ${a2:-absent}, history-identical=${hid}, snapshot-identical=${sid}"
  [ "$RC" -eq 1 ] && [ "$rc2" -eq 1 ] && grep -q "directory is not writable" <<<"$OUT" \
    && [ -z "$a1" ] && [ -z "$a2" ] && [ "$hid" = yes ] && [ "$sid" = yes ]
}

# links: a symlinked history and a hard-linked history are each REFUSED before any write. A rename
# would turn the link into a regular file (orphaning its target) or split the history from its
# peer. The positive conjunct is rc 1 with the refusal naming the reason; a rotator that emits
# nothing and exits 0 fails it.
arm_links() {
  local w pre rc out isl tid sid pid hid ok_all=1 real="_bmad-output/real-history.md" peer="_bmad-output/peer-history.md"
  MSG=""
  w="$(world above)" || { MSG="world copy failed"; return 1; }
  pre="$(snap_copy "$w")" || { MSG="snapshot copy failed"; return 1; }
  mv "$w/$HIST_REL" "$w/$real" && ln -s real-history.md "$w/$HIST_REL" && cp "$w/$real" "$w.real0" \
    || { MSG="cannot build the symlinked history"; return 1; }
  out="$(bash "$R_" "$w/$HIST_REL" --absorb "$w/$SNAP_REL" --apply 2>&1)"; rc=$?
  isl=no; [ -L "$w/$HIST_REL" ] && isl=yes
  tid=no; cmp -s "$w.real0" "$w/$real" && tid=yes
  sid=no; cmp -s "$pre" "$w/$SNAP_REL" && sid=yes
  MSG="symlink: rc=${rc} names it=$(grep -c 'is a symlink' <<<"$out") still-a-link=${isl} target-identical=${tid} snapshot-identical=${sid} archive=$([ -e "$w/$ARCH_REL" ] && echo yes || echo no); "
  { [ "$rc" -eq 1 ] && grep -q 'is a symlink' <<<"$out" && [ "$isl" = yes ] && [ "$tid" = yes ] \
      && [ "$sid" = yes ] && [ ! -e "$w/$ARCH_REL" ]; } || ok_all=0
  w="$(world above)" || { MSG="world copy failed"; return 1; }
  pre="$(snap_copy "$w")" || { MSG="snapshot copy failed"; return 1; }
  cp "$w/$HIST_REL" "$w.hist" && ln "$w/$HIST_REL" "$w/$peer" || { MSG="cannot hard-link the history"; return 1; }
  out="$(bash "$R_" "$w/$HIST_REL" --absorb "$w/$SNAP_REL" --apply 2>&1)"; rc=$?
  hid=no; cmp -s "$w.hist" "$w/$HIST_REL" && hid=yes
  pid=no; cmp -s "$w.hist" "$w/$peer" && pid=yes
  sid=no; cmp -s "$pre" "$w/$SNAP_REL" && sid=yes
  MSG="${MSG}hard link: rc=${rc} names it=$(grep -c 'more than one hard link' <<<"$out") history-identical=${hid} peer-identical=${pid} snapshot-identical=${sid} archive=$([ -e "$w/$ARCH_REL" ] && echo yes || echo no)"
  { [ "$rc" -eq 1 ] && grep -q 'more than one hard link' <<<"$out" && [ "$hid" = yes ] && [ "$pid" = yes ] \
      && [ "$sid" = yes ] && [ ! -e "$w/$ARCH_REL" ]; } || ok_all=0
  [ "$ok_all" -eq 1 ]
}

# mode: a 640 history rotates, and after the rename it is still 640 (`cp -p` onto the 0600 mktemp
# file before the content is written). A peer file in the same directory is untouched. chmod has no
# meaning on FAT, so this arm is about the host it runs on.
arm_mode() {
  local w rc md hr pr
  expect_above || { MSG="cannot build the expected new history"; return 1; }
  w="$(world above)" || { MSG="world copy failed"; return 1; }
  chmod 640 "$w/$HIST_REL" || { MSG="chmod failed"; return 1; }
  printf 'a peer file beside the history, not the rotator'"'"'s to touch\n' > "$w/_bmad-output/peer.md" \
    && cp "$w/_bmad-output/peer.md" "$w.peer" || { MSG="cannot seed the peer file"; return 1; }
  bash "$R_" "$w/$HIST_REL" --absorb "$w/$SNAP_REL" --apply >/dev/null 2>&1; rc=$?
  md="$(fmode "$w/$HIST_REL")"
  hr=no; cmp -s "$w/$HIST_REL" "$EXPECT" && hr=yes
  pr=no; cmp -s "$w.peer" "$w/_bmad-output/peer.md" && pr=yes
  MSG="rc=${rc} mode=${md} rotated=${hr} peer-identical=${pr}"
  [ "$rc" -eq 0 ] && [ "$md" = "-rw-r-----" ] && [ "$hr" = yes ] && [ "$pr" = yes ]
}

# atomic: an `mv` shim fails the rename WITHOUT renaming. rc 1, the history byte-identical, the
# snapshot byte-identical (its truncate comes after the rename), and NO file left at the temp name:
# the refusal removes the temp it built. This is the only arm that can assert "no temp left" on a
# failure after the append; a killed run legitimately leaves one.
arm_atomic() {
  local w pre hpre hid sid nt
  w="$(world above)" || { MSG="world copy failed"; return 1; }
  pre="$(snap_copy "$w")" || { MSG="snapshot copy failed"; return 1; }
  hpre="$w.hist"; cp "$w/$HIST_REL" "$hpre" || { MSG="history copy failed"; return 1; }
  rshim mvfail "$w" "$RSHIM" absorb
  hid=no; cmp -s "$hpre" "$w/$HIST_REL" && hid=yes
  sid=no; cmp -s "$pre" "$w/$SNAP_REL" && sid=yes
  nt="$(tmpcount "$w")"
  MSG="shim acted ${SENT}x, rc=${RC}, names the rename=$(grep -c 'rename over the history failed' <<<"$OUT"), history-identical=${hid}, snapshot-identical=${sid}, temp files left=${nt}"
  [ "$SENT" -eq 1 ] && [ "$RC" -eq 1 ] && grep -q 'rename over the history failed' <<<"$OUT" \
    && [ "$hid" = yes ] && [ "$sid" = yes ] && [ "$nt" -eq 0 ]
}

# killed: the case rounds 4-6 could not pass cleanly. The kill is not keyed on a command SHAPE:
# a kill keyed on "any `mv`" or "a one-argument `cat` of the temp" accepted a rotator that renames
# and then copies the history back through itself (`cp history x && cat x > history`), which loses
# 21 of 26 lines on a kill between the shell's truncate and the write. So:
#   sweep   -- with --absorb, traced by the DEBUG trap above. One UNKILLED counted run first: rc 0,
#              the history equal to a clean rotation, and T traced points numbered densely 1..T.
#              Then, each in a fresh world with its own TMPDIR and counter, the rotator is run with
#              point N under `ulimit -f L` and SIGKILLed at point N+1, and the SAME caller re-runs
#              plainly (no restore, no cleanup). For each killed run: run 2 rc 0; ZERO pre-run
#              history and snapshot lines missing from the tracked corpus (`git ls-files` *.md,
#              which is the history and the staged archive); the final history EQUAL to a clean
#              rotation (a rotator that never rewrites the history also exits 0 and loses nothing,
#              so this separates them).
#              TWO LIMITS, because each has a subject only it reaches. L = 1 leaves a write of a
#              file over 1 KiB cut part-way (MZ2, which restores only an EMPTY history, passes
#              L = 0 and dies here); L = 0 leaves it empty (MZ3, which restores only a NON-empty
#              shorter history, passes L = 1 and dies here). L = 1 runs at EVERY point 1..T. L = 0
#              runs at every point from W0 to T, where W0 is the point before the counted run's
#              first traced `mv` (the rename), and at every KSTRIDE-th point below W0; a trace with
#              no `mv` gets every point. The schedule is then CHECKED: the first point whose L = 1
#              kill found the new history already in place must lie above W0, or the arm fails.
#              The sampling exists for wall clock (every point at both limits measured 90s; 18
#              workers in place of 12 measured no faster). ITS GAP: a write-through BEFORE the
#              rename whose recovery tells an empty history from a partial one can be missed. L = 1
#              runs at those points, but only L = 0 leaves the empty history that recovery keys on,
#              and the L = 0 sampling below W0 can skip the point (measured: MZ3's copy-back moved
#              before the rename, at 8 offsets, was killed at 1 of the 8). BL-321's receipt runs
#              every point at both limits and kills all 8. EVERY killed run gets its own plain
#              re-run. No killed world is ever judged equal to the template and handed another
#              run's verdict: a history made unwritable by a file flag (`chflags uchg`, MCF) or a
#              deny-write ACL (MCA) is invisible to `diff -r` and to `ls -lAnR`, and reading
#              either needs `ls -O` / `ls -e`, which are BSD-only.
#              The LAST point T is never killed (no point follows it): it runs under each limit
#              and must complete with rc 0 and a clean rotation, its own assertion.
#              The sweep proves its own reach: every point-limit run it scheduled produced a verdict
#              (swept = T + the L = 0 count, T - 1 + that count - 1 of them killed), the L = 0 set
#              covers every point from W0 to T, at least one kill per limit lands after the rename,
#              one per limit lands ON the `mv`, and at least one kill leaves a history or temp file
#              of exactly 1024 bytes -- a partial write, which the seed is asserted large enough to
#              produce (both the pre-run and the new history over 1 KiB). A stray temp may be left.
#              KPAR workers run the jobs, job i on worker i mod KPAR, from N = T down, no barrier.
#              A failing point drops a stop file and every worker stops before its next job.
#              WHAT IT CANNOT REACH. The kill lands only BETWEEN simple commands of the rotator's
#              own shell or of a child bash it starts plainly (BASH_ENV is inherited, so `bash -c`
#              and a bash helper script are traced too, and so is every command in an EXIT or ERR
#              trap handler, inline or in a called function). A child started as `bash --posix`,
#              as `bash -p`, with POSIXLY_CORRECT set, or under `env -i` skips BASH_ENV and is
#              untraced. A program that is not bash -- sh or dash, zsh,
#              perl, python, awk, a compiled tool -- runs its internal steps to completion under the
#              limit: one that writes the history and then does anything else (renames, re-opens,
#              retries) is observed only after all of it, so a kill between two of its own writes
#              is never modelled. On a host where `sh` IS bash it sources BASH_ENV only when not
#              started in POSIX mode, which `sh` is, so an `sh -c` helper is untraced there too. A
#              pipeline stage or background job still running when the kill lands is not killed
#              with the rotator (`kill $$` names the shell alone). A write through the history of
#              1024 bytes or fewer is whole under L = 1.
#              A rotator that switches the trace OFF itself (`set +T`, `set +o functrace`,
#              `trap - DEBUG`, `trap '' DEBUG`) runs every later command untraced and unkilled: MTU
#              survived 269 kills that way. The sweep cannot reach that, so the arm REFUSES any
#              rotator whose own text matches KESC_RE before it sweeps (MTU pins the refusal). The
#              refusal reads the rotator's text only: the same switch spelled through `eval`, a
#              variable, or a sourced file is not seen, and such a rotator is unreached.
#
# staged: WITHOUT --absorb, two halves. (1) The kill lands on `git add` of the archive, which now
# runs BEFORE the rename: the history is still the pre-run file, the archive untracked; the plain
# re-run rotates again (a duplicate block), rc 0, the archive tracked, the history equal to a clean
# rotation, every pre-run line in the tracked corpus. (2) A history ALREADY CUT whose archive is
# untracked -- what an earlier revision, which staged after the rename, left on a kill there -- is
# seeded directly (a clean rotation, then `git rm --cached` of the archive). The re-run lands on
# "nothing to rotate" and must stage it. The sweep does not stand in for (2): with --absorb the
# re-run's absorb stages the archive itself, so m18 (no staging on the cut-floor path) passed all 63
# kill points of the round-8 sweep and dies only here.
sweep_one() {  # <N> <L> <dir>: one kill point at limit L; writes <dir>/r.<N>.<L>, and <dir>/stop if it fails
  local N="$1" L="$2" d="$3" w c rc1 rc2 post heq miss hb pb f at
  w="$d/w$N.$L"; c="$d/c$N.$L"
  cp -R "$TMPL/above" "$w" && mkdir -p "$c" "$w.tmp" && echo 0 > "$c/h" || { echo "ERR $N" > "$d/r.$N.$L"; : > "$d/stop"; return; }
  ( cd "$w" && TMPDIR="$w.tmp" SNAPROT_KC="$c" SNAPROT_KN="$N" SNAPROT_KL="$L" BASH_ENV="$KENV" \
      bash "$R_" "$HIST_REL" --absorb "$SNAP_REL" --apply ) >/dev/null 2>"$w.err1"; rc1=$?
  if [ "$rc1" -ne 137 ]; then
    # Not killed: N = 0 (the counted run) or N = T (the last point, whose command is the run's own
    # final one, so no later point exists to kill at). Either must complete: rc 0, a clean rotation.
    heq=no; cmp -s "$w/$HIST_REL" "$EXPECT" && heq=yes
    echo "UNKILLED $N $rc1 $heq" > "$d/r.$N.$L"
    [ "$rc1" -eq 0 ] && [ "$heq" = yes ] || : > "$d/stop"
    return
  fi
  # A file the killed run left at the history's own name, or at a temp name beside it, holding
  # exactly L KiB: under `ulimit -f 1` that is a write of a longer file cut part-way.
  pb=0
  if [ "$L" -gt 0 ]; then
    for f in "$w/_bmad-output/.pipeline-snapshot-history.md.rotate."* "$w/$HIST_REL"; do
      [ -f "$f" ] || continue
      hb="$(wc -c < "$f" | tr -d ' ')"
      if [ "$hb" -eq $(( L * 1024 )) ]; then
        case "$f" in "$w/$HIST_REL") pb=history ;; *) pb=temp ;; esac
      fi
    done
  fi
  hb="$(fbytes "$w/$HIST_REL")"
  post=no; cmp -s "$w/$HIST_REL" "$EXPECT" && post=yes
  # The plain re-run, on THIS killed world, every time. No world is judged equal to the template and
  # handed a verdict computed elsewhere: MCH (mode bits), MCF (a `chflags uchg` file flag) and MCA
  # (a deny-write ACL) each leave a killed world whose bytes are the template's and whose re-run is
  # refused, and no portable reading sees the flag or the ACL.
  # TMPDIR inside the world, as run 1 has: an interrupt reaps this re-run by SIGKILL, which runs no
  # EXIT trap, and its mktemp directory must then be under $WORK, not in the caller's TMPDIR.
  ( cd "$w" && TMPDIR="$w.tmp" bash "$R_" "$HIST_REL" --absorb "$SNAP_REL" --apply ) >/dev/null 2>&1; rc2=$?
  ( cd "$w" && git ls-files -z -- '*.md' | xargs -0 cat 2>/dev/null ) | sort -u > "$w.corpus"
  miss="$(comm -23 "$d/want" "$w.corpus" | wc -l | tr -d ' ')"
  heq=no; cmp -s "$w/$HIST_REL" "$EXPECT" && heq=yes
  # The trap wrote each point's command text into its counter file.
  at="$(tr -s ' \t' '__' < "$c/$N" 2>/dev/null | cut -c1-60)"
  echo "KILLED $N $rc1 $rc2 $miss $heq $post $(wc -l < "$d/want" | tr -d ' ') ${hb:-absent} $pb ${at:-unrecorded}" > "$d/r.$N.$L"
  [ "$rc2" -eq 0 ] && [ "$miss" -eq 0 ] && [ "$heq" = yes ] || : > "$d/stop"
}
sweep_worker() {  # <job list file> <dir>: each "N L" line in turn, until a stop file.
  local N L
  while read -r N L; do
    [ -e "$2/stop" ] && return
    sweep_one "$N" "$L" "$2"
  done < "$1"
}
sweep_pass() {  # <dir> <job list>: KPAR workers, job i to worker (i mod KPAR), no barrier between jobs.
  local j=0
  while [ "$j" -lt "$KPAR" ]; do
    awk -v w="$j" -v k="$KPAR" '(NR - 1) % k == w' "$2" > "$2.$j"
    sweep_worker "$2.$j" "$1" & KPIDS="$KPIDS $!"; j=$((j + 1))
  done
  # The worker pids are recorded (KPIDS) so an interrupt can reap their trees; see the EXIT handler.
  # SNAPROT_SWEEP_STARTED names a file written once every worker is running, so a probe that
  # interrupts this fixture mid-sweep waits on a condition rather than on a process table.
  [ -n "${SNAPROT_SWEEP_STARTED:-}" ] && echo "$KPIDS" > "$SNAPROT_SWEEP_STARTED"
  wait
  KPIDS=""
}
arm_killed() {
  local heq ok_all=1 d T N j k L bad nk npost nmiss nmv npart first swept stop bh be tk tl W0 n0 n1 wpost
  local f1 f2 f3 f4 f5 f6 f7 f8 f9 f10 f11 part1
  expect_above || { MSG="cannot build the expected new history"; return 1; }
  MSG=""
  if grep -qE "$KESC_RE" "$R_"; then
    MSG="sweep: REFUSED -- the rotator switches off its own DEBUG trace ($(grep -nE "$KESC_RE" "$R_" | head -1 | cut -c1-60)), so no kill point after it can be reached"
    return 1
  fi
  # SIZING. `ulimit -f 1` writes 1024 bytes and stops, which is a PARTIAL write only of a file longer
  # than that. Both the pre-run history and the new history must be, or every limited write is whole.
  bh="$(fbytes "$TMPL/above/$HIST_REL")"; be="$(fbytes "$EXPECT")"
  if ! { [ "${bh:-0}" -gt $(( KL * 1024 )) ] && [ "${be:-0}" -gt $(( KL * 1024 )) ]; }; then
    MSG="sweep: SEED TOO SMALL for a partial write under ulimit -f ${KL}: history ${bh:-absent} bytes, new history ${be:-absent} bytes"
    return 1
  fi
  d="$(mktemp -d "$WORK/sweep.XXXXXX")" || { MSG="sweep dir failed"; return 1; }
  # The pre-run lines: the template's history and snapshot, the same for every kill point.
  sort -u "$TMPL/above/$HIST_REL" "$TMPL/above/$SNAP_REL" > "$d/want" && [ -s "$d/want" ] \
    || { MSG="cannot list the pre-run lines"; return 1; }
  # The counted unkilled run (N = 0 never matches a point and never kills): rc 0, a clean rotation,
  # and T traced points, which must be the dense numbers 1..T (the counter's own proof).
  sweep_one 0 1 "$d"
  read -r f1 f2 f3 f4 < "$d/r.0.1"
  T="$(ls "$d/c0.1" | grep -c '^[0-9][0-9]*$')" || T=0
  tk=""; [ "$T" -gt 0 ] && [ -f "$d/c0.1/$T" ] && [ ! -e "$d/c0.1/$(( T + 1 ))" ] && tk=dense
  if ! { [ "$f1" = UNKILLED ] && [ "$f3" -eq 0 ] && [ "$f4" = yes ] && [ "$tk" = dense ]; }; then
    MSG="sweep: the counted unkilled run did not complete cleanly ($f1 $f2 $f3, history == clean rotation: ${f4}, points ${T} ${tk:-NOT dense})"
    return 1
  fi
  bad=0; nk=0; npost=0; nmiss=0; nmv=0; npart=0; part1=""; first=""; swept=0; stop=0; tl=""
  # ONE PASS, no barrier. Limit KL at every point 1..T. Limit 0 SAMPLED: every point from W0 to T,
  # plus every KSTRIDE-th point below W0. W0 is SCHEDULED from the counted run's own trace -- the
  # point before its first `mv` command, the rename -- and then CHECKED against what the limit-KL
  # kills observed: the first point whose kill found the new history already in place must be above
  # W0, or the window missed the rename and the arm fails. A trace with no `mv` gets W0 = 1 (every
  # point at both limits). See the arm header for what the sampling costs.
  W0=1; k=1
  while [ "$k" -le "$T" ]; do
    read -r f1 f2 < "$d/c0.1/$k" 2>/dev/null
    if [ "$f1" = mv ]; then W0=$(( k > 1 ? k - 1 : 1 )); break; fi
    k=$((k + 1))
  done
  k="$T"; : > "$d/jobs"; : > "$d/jobs0"; : > "$d/jobs1"
  while [ "$k" -ge 1 ]; do
    echo "$k $KL" >> "$d/jobs"; echo "$k" >> "$d/jobs1"
    if [ "$k" -ge "$W0" ] || [ $(( k % KSTRIDE )) -eq 0 ]; then echo "$k 0" >> "$d/jobs"; echo "$k" >> "$d/jobs0"; fi
    k=$((k - 1))
  done
  sweep_pass "$d" "$d/jobs"
  n0="$(wc -l < "$d/jobs0" | tr -d ' ')"; n1="$(wc -l < "$d/jobs1" | tr -d ' ')"
  [ -e "$d/stop" ] && stop=1
  # The check on the schedule: the lowest point whose limit-KL kill found the new history in place.
  wpost=""; k=1
  while [ "$k" -lt "$T" ]; do
    f7=""; [ -f "$d/r.$k.$KL" ] && read -r f1 f2 f3 f4 f5 f6 f7 f8 < "$d/r.$k.$KL"
    if [ "$f7" = yes ]; then wpost="$k"; break; fi
    k=$((k + 1))
  done
  k="$T"
  while [ "$k" -ge 1 ]; do
    for L in $KL 0; do
      f1=NOTSWEPT; f2=""; f3=""; f4=""; f5=""; f6=""; f7=""; f8=""; f9=""; f10=""; f11=""
      [ -f "$d/r.$k.$L" ] && read -r f1 f2 f3 f4 f5 f6 f7 f8 f9 f10 f11 < "$d/r.$k.$L"
      if [ "$f1" = NOTSWEPT ]; then :
      elif [ "$k" -eq "$T" ]; then
        # THE LAST POINT. No point follows it, so nothing kills; its command still runs under the
        # limit, and the run must complete: rc 0 and a clean rotation. This is its own assertion.
        swept=$((swept + 1))
        if [ "$f1" = UNKILLED ] && [ "$f3" -eq 0 ] && [ "$f4" = yes ]; then tl="${tl}ok"
        else bad=$((bad + 1)); tl="${tl}FAILED"; [ -n "$first" ] || first="N=${k} limit ${L} (the last point, unkilled) did not complete a clean rotation: $f1 rc=$f3 clean=$f4"; fi
      elif [ "$f1" = KILLED ]; then
        swept=$((swept + 1)); nk=$((nk + 1))
        [ "$f7" = yes ] && npost=$((npost + 1))
        case "$f11" in mv_*) nmv=$((nmv + 1)) ;; esac
        if [ "$f10" != 0 ]; then npart=$((npart + 1)); [ -n "$part1" ] || part1="N=${k} after ${f11}: the ${f10} file cut at $(( KL * 1024 )) bytes, history ${f9} bytes"; fi
        if ! { [ "$f4" -eq 0 ] && [ "$f5" -eq 0 ] && [ "$f6" = yes ] && [ "$f8" -gt 0 ]; }; then
          bad=$((bad + 1)); [ "$f5" -gt 0 ] && nmiss=$((nmiss + 1))
          [ -n "$first" ] || first="N=${k} limit ${L} KiB after ${f11}: history left at ${f9} bytes, re-run rc=${f4}, ${f5} of ${f8} pre-run lines missing, history == clean rotation: ${f6}"
        fi
      else
        swept=$((swept + 1)); bad=$((bad + 1)); [ -n "$first" ] || first="N=${k} limit ${L} of ${T} was not killed: $f1 rc=$f3"
      fi
    done
    k=$((k - 1))
  done
  if [ "$stop" -eq 0 ] && { [ -z "$wpost" ] || [ "$wpost" -le "$W0" ]; }; then
    bad=$((bad + 1)); [ -n "$first" ] || first="the limit-0 window from N=${W0} (scheduled from the trace) does not contain the first observed post-rename kill (N=${wpost:-none})"
  fi
  MSG="sweep: ${T} traced points unkilled (history ${bh} -> ${be} bytes); limit ${KL} KiB at all ${n1}, limit 0 at ${n0} (every point from N=${W0}, the one before the traced mv, first post-rename kill observed at N=${wpost:-none}, and every ${KSTRIDE}th below); ${swept} of $(( T + n0 )) point-limit runs swept (from N=${T} down$([ "$stop" -eq 1 ] && echo ', stopped at the first failure')): ${nk} killed, ${bad} failed (${nmiss} lost lines), the last point unkilled and clean at both limits=${tl:-not swept}, ${npost} after the rename, ${nmv} at mv, ${npart} with a history or temp cut at $(( KL * 1024 )) bytes (first: ${part1:-none}); first failure (highest N): ${first:-none}"
  { [ "$n0" -gt $(( T - W0 )) ] && [ "$n1" -eq "$T" ] && [ "$swept" -eq $(( n1 + n0 )) ] && [ "$nk" -eq $(( n1 + n0 - 2 )) ] && [ "$tl" = okok ] \
      && [ "$bad" -eq 0 ] && [ "$npost" -ge 2 ] && [ "$nmv" -ge 2 ] && [ "$npart" -ge 1 ]; } || ok_all=0
  [ "$ok_all" -eq 1 ]
}
arm_staged() {
  local w hpre rc1 n1 o2 rc2 heq trk0 trk1 miss
  expect_above || { MSG="cannot build the expected new history"; return 1; }
  w="$(world above)" || { MSG="world copy failed"; return 1; }
  hpre="$w.hist"; cp "$w/$HIST_REL" "$hpre" || { MSG="history copy failed"; return 1; }
  rshim gitkill "$w" "$GSHIM"; rc1=$RC; n1=$SENT
  trk0=no; tracked "$w" "$ARCH_REL" && trk0=yes
  local hk=no; cmp -s "$hpre" "$w/$HIST_REL" && hk=yes
  o2="$(bash "$R_" "$w/$HIST_REL" --apply 2>&1)"; rc2=$?
  trk1=no; tracked "$w" "$ARCH_REL" && trk1=yes
  heq=no; cmp -s "$w/$HIST_REL" "$EXPECT" && heq=yes
  sort -u "$hpre" > "$w.want"
  ( cd "$w" && git ls-files -z -- '*.md' | xargs -0 cat 2>/dev/null ) | sort -u > "$w.corpus"
  miss="$(comm -23 "$w.want" "$w.corpus" | wc -l | tr -d ' ')"
  # (2) an already-cut history with an untracked archive.
  local w2 o3 rc3 trk2 trk3 heq2
  w2="$(world above)" || { MSG="world copy failed"; return 1; }
  bash "$ROT" "$w2/$HIST_REL" --apply >/dev/null 2>&1
  ( cd "$w2" && git rm -q --cached -- "$ARCH_REL" ) >/dev/null 2>&1
  trk2=no; tracked "$w2" "$ARCH_REL" && trk2=yes
  o3="$(bash "$R_" "$w2/$HIST_REL" --apply 2>&1)"; rc3=$?
  trk3=no; tracked "$w2" "$ARCH_REL" && trk3=yes
  heq2=no; cmp -s "$w2/$HIST_REL" "$EXPECT" && heq2=yes
  MSG="staging killed: shim acted ${n1}x, run 1 rc=${rc1}, history unchanged after run 1=${hk}, archive tracked after run 1=${trk0}; run 2 rc=${rc2}, archive tracked=${trk1}, history == clean rotation: ${heq}, pre-run lines missing from the tracked corpus=${miss}; already-cut + untracked: tracked before=${trk2}, re-run rc=${rc3} ($(head -1 <<<"$o3" | cut -c1-60)), tracked after=${trk3}, history == clean rotation: ${heq2}"
  [ "$n1" -eq 1 ] && [ "$rc1" -eq 137 ] && [ "$hk" = yes ] && [ "$trk0" = no ] && [ "$rc2" -eq 0 ] \
    && [ "$trk1" = yes ] && [ "$heq" = yes ] && [ -s "$w.want" ] && [ "$miss" -eq 0 ] \
    && [ "$trk2" = no ] && [ "$rc3" -eq 0 ] && grep -q 'nothing to rotate' <<<"$o3" \
    && [ "$trk3" = yes ] && [ "$heq2" = yes ]
}

# --- BL-322's edge inputs. Every world asserts CONSERVATION: a refusal leaves the history, the
# snapshot and the archive byte-identical (or absent); a rotation leaves pre-run == preamble + moved +
# kept byte for byte, the new history == preamble + kept, and the archive's last lines == moved.
# conserved <before> <after> <archive> <preamble lines>: the rotation half of that.
conserved() {
  local lb la k P="$4"
  lb="$(wc -l < "$1" | tr -d ' ')"; la="$(wc -l < "$2" | tr -d ' ')"; k=$(( lb - la ))
  [ "$k" -gt 0 ] || return 1
  head -n "$P" "$1" > "$1.pre"; sed -n "$(( P + 1 )),$(( P + k ))p" "$1" > "$1.mov"
  tail -n +"$(( P + k + 1 ))" "$1" > "$1.kept"
  cat "$1.pre" "$1.kept" | cmp -s - "$2" && cat "$1.pre" "$1.mov" "$1.kept" | cmp -s - "$1" \
    && tail -n "$k" "$3" | cmp -s "$1.mov" -
}
# unchanged <world> <history copy> <snapshot copy>: history and snapshot byte-identical, no archive.
unchanged() { cmp -s "$2" "$1/$HIST_REL" && cmp -s "$3" "$1/$SNAP_REL" && [ ! -e "$1/$ARCH_REL" ]; }

# H1HEAD: a history whose line 1 is a `## ` heading (no preamble) rotates, and conserves. Its control,
# the same bytes with the preamble, is arm `above`.
arm_h1head() {
  local w b out rc; w="$(world above)" || { MSG="world copy failed"; return 1; }
  tail -n +3 "$TMPL/above/$HIST_REL" > "$w/$HIST_REL" || { MSG="history strip failed"; return 1; }
  ( cd "$w" && git add -A && git -c user.email=f@f -c user.name=f commit -qm h1 ) >/dev/null 2>&1
  b="$w.hist"; cp "$w/$HIST_REL" "$b"
  out="$(bash "$R_" "$w/$HIST_REL" --apply 2>&1)"; rc=$?
  local c=no; conserved "$b" "$w/$HIST_REL" "$w/$ARCH_REL" 0 && c=yes
  MSG="line 1 = '$(head -1 "$b" | cut -c1-20)', rc=${rc}, conserved=${c}: $(head -1 <<<"$out" | cut -c1-90)"
  [ "$(head -c 3 "$b")" = '## ' ] && [ "$rc" -eq 0 ] && [ "$c" = yes ]
}
# NOVAL: --archive, --keep-entries and --absorb each given as the LAST argument, and --archive given
# an option as its value: each rc 2 (usage), nothing written.
arm_noval() {
  local w h s o rcs="" ok_all=1; w="$(world above)" || { MSG="world copy failed"; return 1; }
  h="$w.hist"; s="$w.snap"; cp "$w/$HIST_REL" "$h"; cp "$w/$SNAP_REL" "$s"
  for o in --archive --keep-entries --absorb; do
    bash "$R_" "$w/$HIST_REL" --apply "$o" >/dev/null 2>&1; rc=$?; rcs="${rcs} ${o}=${rc}"
    [ "$rc" -eq 2 ] || ok_all=0
  done
  bash "$R_" "$w/$HIST_REL" --archive --apply >/dev/null 2>&1; rc=$?; rcs="${rcs} --archive-then-option=${rc}"
  [ "$rc" -eq 2 ] || ok_all=0
  local u=no; unchanged "$w" "$h" "$s" && u=yes
  MSG="rc:${rcs}; unchanged=${u}"
  [ "$ok_all" -eq 1 ] && [ "$u" = yes ]
}
# KEEP0: --keep-entries 0 is refused as usage, before any `sed` runs, and writes nothing.
arm_keep0() {
  local w h s out rc; w="$(world above)" || { MSG="world copy failed"; return 1; }
  h="$w.hist"; s="$w.snap"; cp "$w/$HIST_REL" "$h"; cp "$w/$SNAP_REL" "$s"
  out="$(bash "$R_" "$w/$HIST_REL" --keep-entries 0 --absorb "$w/$SNAP_REL" --apply 2>&1)"; rc=$?
  local u=no; unchanged "$w" "$h" "$s" && u=yes
  MSG="rc=${rc}, sed errors=$(grep -c '^sed:' <<<"$out"), names the option=$(grep -c 'keep-entries' <<<"$out"), unchanged=${u}"
  [ "$rc" -eq 2 ] && ! grep -q '^sed:' <<<"$out" && grep -q 'keep-entries' <<<"$out" && [ "$u" = yes ]
}
# SAME: --archive naming the absorbed snapshot (a second spelling through `..`), and --archive naming
# the history: each rc 2, nothing written. The run is bounded by `ulimit -f` because the defect is an
# append of a file to itself, which on a subject without the guard never ends.
arm_same() {
  local w h s rc1 rc2 alias; w="$(world above)" || { MSG="world copy failed"; return 1; }
  h="$w.hist"; s="$w.snap"; cp "$w/$HIST_REL" "$h"; cp "$w/$SNAP_REL" "$s"
  alias="$w/_bmad-output/../_bmad-output/pipeline-snapshot.md"
  ( ulimit -f 4096; bash "$R_" "$w/$HIST_REL" --archive "$alias" --absorb "$w/$SNAP_REL" --apply ) >/dev/null 2>&1; rc1=$?
  local u1=no; cmp -s "$h" "$w/$HIST_REL" && cmp -s "$s" "$w/$SNAP_REL" && u1=yes
  ( ulimit -f 4096; bash "$R_" "$w/$HIST_REL" --archive "$w/$HIST_REL" --apply ) >/dev/null 2>&1; rc2=$?
  local u2=no; cmp -s "$h" "$w/$HIST_REL" && cmp -s "$s" "$w/$SNAP_REL" && [ ! -e "$w/$ARCH_REL" ] && u2=yes
  MSG="archive==absorb rc=${rc1} unchanged=${u1} (snapshot $(fbytes "$w/$SNAP_REL") bytes); archive==history rc=${rc2} unchanged=${u2}"
  [ "$rc1" -eq 2 ] && [ "$u1" = yes ] && [ "$rc2" -eq 2 ] && [ "$u2" = yes ]
}
# GITFAIL: `git add` of the archive fails (a shim, exit 1) on the rotation path with --absorb: rc 1,
# the history and the snapshot byte-identical (the stage precedes the rename and the truncate), the
# archive untracked, and the refusal says so. It was a WARNING with rc 0 over a shrunk history.
arm_gitfail() {
  local w h s trk; w="$(world above)" || { MSG="world copy failed"; return 1; }
  h="$w.hist"; s="$w.snap"; cp "$w/$HIST_REL" "$h"; cp "$w/$SNAP_REL" "$s"
  rshim gitfail "$w" "$GSHIM" absorb
  local u=no; cmp -s "$h" "$w/$HIST_REL" && cmp -s "$s" "$w/$SNAP_REL" && u=yes
  trk=no; tracked "$w" "$ARCH_REL" && trk=yes
  MSG="shim acted ${SENT}x, rc=${RC}, refused=$(grep -c 'REFUSED -- could not stage' <<<"$OUT"), history+snapshot unchanged=${u}, archive tracked=${trk}"
  [ "$SENT" -ge 1 ] && [ "$RC" -eq 1 ] && grep -q 'REFUSED -- could not stage' <<<"$OUT" && [ "$u" = yes ] && [ "$trk" = no ]
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

ARMS="swap neg nohist floor above ign unw ulim wlate wshort rew tlate tshort rohist links mode atomic killed staged args idem ro rodir rosnap h1head noval keep0 same gitfail"
arm_run() {
  case "$1" in
    h1head)   arm_h1head ;;
    noval)    arm_noval ;;
    keep0)    arm_keep0 ;;
    same)     arm_same ;;
    gitfail)  arm_gitfail ;;
    rosnap)   arm_rosnap ;;
    tlate)    arm_tshim tlate ;;
    tshort)   arm_tshim tshort ;;
    rohist)   arm_rohist ;;
    rodir)    arm_rodir ;;
    links)    arm_links ;;
    mode)     arm_mode ;;
    atomic)   arm_atomic ;;
    killed)   arm_killed ;;
    staged)   arm_staged ;;
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
    rew)    what="REFUSAL — the history REWRITE fails under ulimit -f (sizing proven by an unlimited control): rc 1 before the archive append, history and snapshot byte-identical, no archive, no pre-run history line lost" ;;
    tlate)    what="REFUSAL — the temp write lands every byte then reports failure: rc 1 before the archive append, history and snapshot byte-identical (only the write's status check sees this)" ;;
    tshort)   what="REFUSAL — the temp write drops one byte and reports success: rc 1 before the archive append, history and snapshot byte-identical (only the size check sees this)" ;;
    rohist)   what="REFUSAL — a read-only (444) history: rc 1 before ANY write (no archive), history and snapshot byte-identical" ;;
    rodir)    what="REFUSAL — a writable history in a 555 directory: rc 1 before ANY write, twice, the archive never created, history and snapshot byte-identical" ;;
    rosnap)   what="REFUSAL — a read-only snapshot on --absorb: rc 1, the snapshot unchanged in size, and the refusal says it is archived but NOT emptied" ;;
    links)    what="REFUSAL — a symlinked history and a hard-linked history: each rc 1 before ANY write, the link and its target / the peer byte-identical, snapshot byte-identical, no archive" ;;
    mode)     what="MODE — a 640 history rotates to the clean result and is still 640 after the rename; a peer file beside it is untouched" ;;
    atomic)   what="ATOMIC — the rename fails (an mv shim that never renames): rc 1, history and snapshot byte-identical, NO temp file left" ;;
    killed)   what="KILLED — a kill-point sweep with --absorb, traced by a DEBUG trap in the rotator's own shell (builtins, redirections, absolute paths, command -p, subshells): simple command N runs under ulimit -f 1 at every N and ulimit -f 0 at every N from the rename on plus every 8th before, SIGKILL at N+1, the last point unkilled and clean, a kill on mv, one after the rename and one leaving a 1024-byte partial write; each then a plain re-run: rc 0, 0 pre-run history and snapshot lines missing from the tracked corpus, history == clean rotation" ;;
    staged)   what="STAGED — SIGKILL at the staging after the rename, without --absorb (then a plain re-run: rc 0, archive tracked, history == clean rotation, no pre-run line missing from the corpus)" ;;
    args)   what="USAGE on the no-history path — unknown option rc 2, --absorb naming no file rc 2" ;;
    idem)   what="idempotent — absorbing the already-empty snapshot appends nothing" ;;
    ro)     what="REPORT-ONLY — --absorb without --apply on no history, the floor and above it writes nothing (git status empty, snapshot byte-identical, no archive) and says what it would do" ;;
    h1head)   what="LINE-1 HEADING — a history with no preamble rotates (rc 0) and conserves: pre-run == moved + kept byte for byte, the archive's tail == moved" ;;
    noval)    what="USAGE — --archive, --keep-entries, --absorb given no value, and --archive given an option as its value: each rc 2, nothing written" ;;
    keep0)    what="USAGE — --keep-entries 0: rc 2 naming the option, no sed error, nothing written" ;;
    same)     what="USAGE — --archive naming the absorbed snapshot (by a second spelling) or the history: each rc 2, nothing written (no self-append)" ;;
    gitfail)  what="REFUSAL — git add of the archive fails: rc 1, history and snapshot byte-identical, archive untracked" ;;
  esac
  ROHIST_SKIP=""
  if arm_run "$a"; then
    if [ -n "$ROHIST_SKIP" ]; then printf '  skip  %s (%s)\n' "$what" "$MSG"
    elif [ "$a" = killed ]; then ok "$what ($MSG)"   # the sweep's reach is part of its verdict
    else ok "$what"; fi
  else bad "$what ($MSG)"; fi
done

# --- MUTANTS of the absorb swap ---------------------------------------------------------------
# Each is a copy with ONE edit, keyed on a line the subject carries exactly once, and asserted to
# have applied (the anchor count goes 1 -> 0 and the copy differs) before its verdict is read. The
# copies are driven by the SAME arm functions, and an unmutated copy from the same directory is
# driven through EVERY arm first: it must pass them all, so a mutant verdict is a verdict about the
# edit, not the harness. Each mutant then runs ONLY the arm that owns it. Re-running every arm per
# mutant cost most of the fixture's wall clock and scored nothing more: the verdict read is whether
# the owning arm failed.
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
  # ENVIRON, not -v: `awk -v` strips one level of backslashes, and m17's anchor carries `\"`.
  MUT_A="$3" MUT_B="$4" awk '$0 == ENVIRON["MUT_A"] { print ENVIRON["MUT_B"]; next } { print }' "$1" > "$2" || return 1
  post="$(grep -cxF -- "$3" "$2")" || post=0
  [ "$post" -eq 0 ] && ! cmp -s "$1" "$2"
}
# mut_before <src> <dst> <anchor line> <inserted line>: insert a line before the anchor.
mut_before() {
  local pre
  pre="$(grep -cxF -- "$3" "$1")" || pre=0
  [ "$pre" -eq 1 ] || return 1
  MUT_A="$3" MUT_B="$4" awk '$0 == ENVIRON["MUT_A"] { print ENVIRON["MUT_B"] } { print }' "$1" > "$2" || return 1
  grep -qxF -- "$4" "$2" && ! cmp -s "$1" "$2"
}

# mut_after <src> <dst> <anchor line> <inserted line>: insert a line directly AFTER the anchor, which
# stays byte-identical. Applied means: the anchor is in the source exactly once; the anchor followed
# by its ORIGINAL next line occurs once before and 0 times after; the inserted line occurs 0 times
# before and once after; and the copy differs.
mut_after() {
  local pre inb ina
  pre="$(grep -cxF -- "$3" "$1")" || pre=0
  [ "$pre" -eq 1 ] || return 1
  MUT_A="$3" MUT_B="$4" awk '{ print } $0 == ENVIRON["MUT_A"] { print ENVIRON["MUT_B"] }' "$1" > "$2" || return 1
  inb="$(grep -cxF -- "$4" "$1")" || inb=0
  ina="$(grep -cxF -- "$4" "$2")" || ina=0
  [ "$(pair_count "$1" "$1" "$3")" -eq 1 ] && [ "$(pair_count "$1" "$2" "$3")" -eq 0 ] \
    && [ "$inb" -eq 0 ] && [ "$ina" -eq 1 ] && ! cmp -s "$1" "$2"
}
# pair_count <orig> <file> <anchor>: how often <file> holds the anchor followed by the line that
# follows it in <orig>.
pair_count() {
  MUT_A="$3" awk 'NR == FNR { if (p) { nx = $0; p = 0 } if ($0 == ENVIRON["MUT_A"]) p = 1; next }
    { if (q && $0 == nx) n++; q = ($0 == ENVIRON["MUT_A"]) } END { print n + 0 }' "$1" "$2"
}

run_arms "$MD/rot-control.sh" "$MD/hooks/ai-dlc-continue.sh" "$MD/hooks/ai-dlc-pause.sh"
if [ -z "$FAILED" ]; then
  ok "MUTANT CONTROL: the unmutated copies in the mutant tree pass every arm — the harness runs"
else
  bad "MUTANT CONTROL: the unmutated copies FAILED:${FAILED} — no mutant verdict below is evidence"
fi

# score <label> <must-fail arm> <rotator> <continue> <pause> <what>
score() {
  R_="$3"; HC_="$4"; HP_="$5"; MSG=""; ROHIST_SKIP=""
  if arm_run "$2"; then
    if [ -n "$ROHIST_SKIP" ]; then
      printf '  skip  %s NOT SCORED: arm %s cannot express its subject for this user (%s) — %s\n' "$1" "'$2'" "$MSG" "$6"
    else
      bad "$1 SURVIVED: arm '$2' did not fail ($MSG) — $6"
    fi
  else
    ok "$1 KILLED by '$2' ($MSG) — $6"
  fi
}
CH="$MD/hooks/ai-dlc-continue.sh"; PH="$MD/hooks/ai-dlc-pause.sh"

# m1 is RE-ANCHORED: the truncate is now its own line followed by a check that the file is present
# and empty. Both layers go, or the check refuses the removal and m1 proves only the check.
if mut_line "$ROT" "$MD/m1a.sh" '  { : > "$ABSORB"; } 2>/dev/null' '  rm -f "$ABSORB"' \
   && mut_line "$MD/m1a.sh" "$MD/m1.sh" '  if ! { [ -f "$ABSORB" ] && [ ! -s "$ABSORB" ]; }; then' '  if false; then'; then
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

# m12: the history is rewritten in place again. Both layers go: the `cp -p` of the old history
# (which under the limit fails first and would refuse before the in-place write is reached) and
# the write into the temp, which now writes into the history and copies it back to the temp.
M12_CP='cp -p -- "$HISTORY" "$HIST_NEW" || rewrite_fail "cp -p of the history failed"'
M12_OLD='cat "$TMPD/preamble" "$TMPD/tail" > "$HIST_NEW" || rewrite_fail "the write failed"'
M12_NEW='cat "$TMPD/preamble" "$TMPD/tail" > "$HISTORY" || rewrite_fail "the write failed"; cp "$HISTORY" "$HIST_NEW"'
if mut_line "$ROT" "$MD/m12a.sh" "$M12_CP" ':' && mut_line "$MD/m12a.sh" "$MD/m12.sh" "$M12_OLD" "$M12_NEW"; then
  score m12 rew "$MD/m12.sh" "$CH" "$PH" "the history is rewritten in place (cat preamble tail > history)"
else bad "m12 DID NOT APPLY — the cp -p line or the temp write line is not in the rotator exactly once"; fi

# The temp build's two guards, each deleted alone and each killed by the arm built for it.
MA_OLD='[ "$B_GOT" -eq "$B_WANT" ] || rewrite_fail "it holds ${B_GOT} bytes where ${B_WANT} were written"'
if mut_line "$ROT" "$MD/mA.sh" "$MA_OLD" ':'; then
  score mA tshort "$MD/mA.sh" "$CH" "$PH" "the temp write's size check deleted"
else bad "mA DID NOT APPLY — the size check is not in the rotator exactly once"; fi

if mut_line "$ROT" "$MD/mC.sh" "$M12_OLD" 'cat "$TMPD/preamble" "$TMPD/tail" > "$HIST_NEW"'; then
  score mC tlate "$MD/mC.sh" "$CH" "$PH" "the temp write's status check deleted"
else bad "mC DID NOT APPLY — the temp write line is not in the rotator exactly once"; fi

if mut_line "$ROT" "$MD/m14.sh" 'if [ ! -w "$HISTORY" ]; then' 'if false; then'; then
  score m14 rohist "$MD/m14.sh" "$CH" "$PH" "the history-writable precheck deleted"
else bad "m14 DID NOT APPLY — the [ -w ] precheck is not in the rotator exactly once"; fi

# m18: the staging call on the cut-floor path deleted. A run killed after the rename and before
# its staging leaves the archive untracked, and the plain re-run lands on that path.
if mut_line "$ROT" "$MD/m18.sh" '  stage_existing_archive # at the cut floor' '  :'; then
  score m18 staged "$MD/m18.sh" "$CH" "$PH" "the archive is not staged on the nothing-to-rotate path"
else bad "m18 DID NOT APPLY — the cut-floor staging call is not in the rotator exactly once"; fi

# m19: the history-directory precheck deleted.
if mut_line "$ROT" "$MD/m19.sh" 'if [ ! -w "$HIST_DIR" ]; then' 'if false; then'; then
  score m19 rodir "$MD/m19.sh" "$CH" "$PH" "the history-directory-writable precheck deleted"
else bad "m19 DID NOT APPLY — the directory precheck is not in the rotator exactly once"; fi

# m23: the post-truncate check deleted.
if mut_line "$ROT" "$MD/m23.sh" '  if ! { [ -f "$ABSORB" ] && [ ! -s "$ABSORB" ]; }; then' '  if false; then'; then
  score m23 rosnap "$MD/m23.sh" "$CH" "$PH" "the snapshot truncate is no longer verified"
else bad "m23 DID NOT APPLY — the post-truncate check is not in the rotator exactly once"; fi

# The rename design's own guards.
# mL1 / mL2: each link precheck deleted alone. Without `-L` the symlink is followed by `cp -p` and
# replaced by a regular file; without the `-links` refusal the peer is split off holding the old
# content. Each half of the links arm sees only its own.
if mut_line "$ROT" "$MD/mL1.sh" 'if [ -L "$HISTORY" ]; then' 'if false; then'; then
  score mL1 links "$MD/mL1.sh" "$CH" "$PH" "the symlink precheck deleted"
else bad "mL1 DID NOT APPLY — the [ -L ] precheck is not in the rotator exactly once"; fi

if mut_line "$ROT" "$MD/mL2.sh" 'if [ -n "$LINKED" ]; then' 'if false; then'; then
  score mL2 links "$MD/mL2.sh" "$CH" "$PH" "the hard-link precheck deleted"
else bad "mL2 DID NOT APPLY — the -links refusal is not in the rotator exactly once"; fi

# mM: `cp -p` becomes `cp`, so the 0600 mktemp file keeps its own mode and the history comes back 600.
if mut_line "$ROT" "$MD/mM.sh" "$M12_CP" 'cp -- "$HISTORY" "$HIST_NEW" || rewrite_fail "cp -p of the history failed"'; then
  score mM mode "$MD/mM.sh" "$CH" "$PH" "cp -p replaced by cp (the history's mode is lost across the rename)"
else bad "mM DID NOT APPLY — the cp -p line is not in the rotator exactly once"; fi

# mR: rewrite_fail no longer removes the temp it built, so a failed rename leaves it beside the history.
if mut_line "$ROT" "$MD/mR.sh" '  [ -n "$HIST_NEW" ] && rm -f "$HIST_NEW"' '  :'; then
  score mR atomic "$MD/mR.sh" "$CH" "$PH" "a refused rewrite leaves its temp file behind"
else bad "mR DID NOT APPLY — rewrite_fail's remove is not in the rotator exactly once"; fi

# mK: the rename becomes a copy-back through the history (`cat temp > history`), the in-place shape.
# The shell truncates the history when it opens it, and the killed arm's shim then SIGKILLs the
# rotator before a byte is written: the plain re-run finds an empty history and the kept tail is
# lost. The shipped rename is atomic at the same kill point.
MK_OLD='mv -f -- "$HIST_NEW" "$HISTORY" || rewrite_fail "the rename over the history failed"'
if mut_line "$ROT" "$MD/mK.sh" "$MK_OLD" 'cat "$HIST_NEW" > "$HISTORY" || rewrite_fail "the rename over the history failed"'; then
  score mK killed "$MD/mK.sh" "$CH" "$PH" "the rename replaced by a copy-back through the history, killed between its truncate and its write"
else bad "mK DID NOT APPLY — the rename line is not in the rotator exactly once"; fi

# MX2 / MX: the two rotators the shape-keyed kill ACCEPTED, each a whole-line replacement of the
# rename line (so the anchor goes 1 -> 0). MX2 keeps the shipped `mv -f` byte for byte and THEN
# writes the history back through itself from a copy: no one-argument `cat` of a `.rotate.` file,
# and the `mv` shim killed at a rename that was in fact atomic. MX renames to a side file outside
# the corpus and then writes the history from it (`cat side > history`). Each loses lines on a kill
# between the shell's truncate and the write, which the sweep reaches by count, not by shape.
MX2_NEW="${MK_OLD}; cp -- \"\$HISTORY\" \"\$TMPD/h2\" && cat \"\$TMPD/h2\" > \"\$HISTORY\""
if mut_line "$ROT" "$MD/mX2.sh" "$MK_OLD" "$MX2_NEW"; then
  score MX2 killed "$MD/mX2.sh" "$CH" "$PH" "the shipped rename kept, then the history copied back through itself (cp history h2 && cat h2 > history)"
else bad "MX2 DID NOT APPLY — the rename line is not in the rotator exactly once"; fi

MX_NEW='HREAL="$HISTORY"; HISTORY="$HIST_DIR/.stage-x"; mv -f -- "$HIST_NEW" "$HISTORY" || rewrite_fail "the rename over the history failed"; HISTORY="$HREAL"; cat "$HIST_DIR/.stage-x" > "$HISTORY"; rm -f "$HIST_DIR/.stage-x"'
if mut_line "$ROT" "$MD/mX.sh" "$MK_OLD" "$MX_NEW"; then
  score MX killed "$MD/mX.sh" "$CH" "$PH" "the rename goes to a side file, then the history is written from it (cat side > history)"
else bad "MX DID NOT APPLY — the rename line is not in the rotator exactly once"; fi

# MB / MA2 / MZ2: three rotators the round-8 PATH-shim sweep ACCEPTED, each keeping the shipped rename
# line byte for byte and inserting the write-through on the line after it (mut_after proves the edit
# applied). MB copies the history back through itself with BUILTINS only (`while read; printf; done >
# history`), which no PATH shim sees. MA2 does it by ABSOLUTE path (`/bin/cp`, `/bin/cat`), which
# bypasses PATH. MZ2 copies back through a keep file named like the temp, and a start-up recovery
# restores that keep file only when the history is EMPTY -- the only state `ulimit -f 0` leaves, so
# it passed a 0-block limit and loses lines at a 1-block one. Each loses 6+ lines on a kill after a
# partial write, which the traced sweep reaches because it kills in the rotator's own shell.
MB_NEW='cp -- "$HISTORY" "$TMPD/h2" && while IFS= read -r _l || [ -n "$_l" ]; do printf "%s\n" "$_l"; done < "$TMPD/h2" > "$HISTORY"'
if mut_after "$ROT" "$MD/mB.sh" "$MK_OLD" "$MB_NEW"; then
  score MB killed "$MD/mB.sh" "$CH" "$PH" "after the rename, the history copied back through itself by builtins only (while read; printf; done > history)"
else bad "MB DID NOT APPLY — the rename line is not in the rotator exactly once, or the insert did not land"; fi

MA2_NEW='/bin/cp -- "$HISTORY" "$TMPD/h2" && /bin/cat "$TMPD/h2" > "$HISTORY"'
if mut_after "$ROT" "$MD/mA2.sh" "$MK_OLD" "$MA2_NEW"; then
  score MA2 killed "$MD/mA2.sh" "$CH" "$PH" "after the rename, the history copied back through itself by absolute path (/bin/cp, /bin/cat)"
else bad "MA2 DID NOT APPLY — the rename line is not in the rotator exactly once, or the insert did not land"; fi

MZ2_NEW='K_="$HIST_DIR/.$HIST_BASE.rotate.keep"; cp -- "$HISTORY" "$K_" && cat "$K_" > "$HISTORY" && rm -f -- "$K_"'
MZ2_REC='for _t in "$HIST_DIR/.$HIST_BASE.rotate."*; do if [ -f "$_t" ] && [ -s "$_t" ] && [ -f "$HISTORY" ] && [ ! -s "$HISTORY" ]; then mv -f -- "$_t" "$HISTORY"; fi; done'
if mut_after "$ROT" "$MD/mZ2a.sh" "$MK_OLD" "$MZ2_NEW" \
   && mut_after "$MD/mZ2a.sh" "$MD/mZ2.sh" 'HIST_BASE="$(basename "$HISTORY")"' "$MZ2_REC"; then
  score MZ2 killed "$MD/mZ2.sh" "$CH" "$PH" "after the rename, a copy-back through a keep file, recovered at start-up only when the history is EMPTY"
else bad "MZ2 DID NOT APPLY — the rename line or the HIST_BASE line is not in the rotator exactly once, or an insert did not land"; fi

# MZ3: MZ2's mirror. The keep file is restored only when the history is NON-EMPTY and shorter than
# it -- the only state `ulimit -f 1` leaves -- so it passes every limit-1 point and loses lines at the
# limit-0 point on the same command (the history truncated to 0 bytes). This is why the sweep runs
# every point at both limits: each limit has a mutant only it kills.
MZ3_REC='for _t in "$HIST_DIR/.$HIST_BASE.rotate."*; do if [ -f "$_t" ] && [ -s "$_t" ] && [ -s "$HISTORY" ] && [ "$(wc -c < "$HISTORY")" -lt "$(wc -c < "$_t")" ]; then mv -f -- "$_t" "$HISTORY"; fi; done'
if mut_after "$ROT" "$MD/mZ3a.sh" "$MK_OLD" "$MZ2_NEW" \
   && mut_after "$MD/mZ3a.sh" "$MD/mZ3.sh" 'HIST_BASE="$(basename "$HISTORY")"' "$MZ3_REC"; then
  score MZ3 killed "$MD/mZ3.sh" "$CH" "$PH" "MZ2's copy-back, recovered at start-up only when the history is NON-empty and shorter than the keep file"
else bad "MZ3 DID NOT APPLY — the rename line or the HIST_BASE line is not in the rotator exactly once, or an insert did not land"; fi

# MH: after the rename, a write-through in a CHILD bash that heals itself when its own write fails
# (`|| mv` restores the copy). It passed while the trap file unset BASH_ENV, because the child was
# untraced and its write ran whole; traced, a kill between the child's truncate and its write loses
# lines.
MH_NEW='bash -c '"'"'cp -- "$1" "$2" && { cat "$2" > "$1" || mv -f -- "$2" "$1"; }'"'"' _ "$HISTORY" "$TMPD/h2"'
if mut_after "$ROT" "$MD/mH.sh" "$MK_OLD" "$MH_NEW"; then
  score MH killed "$MD/mH.sh" "$CH" "$PH" "after the rename, a self-healing write-through in a child bash (bash -c 'cp; cat > history || mv')"
else bad "MH DID NOT APPLY — the rename line is not in the rotator exactly once, or the insert did not land"; fi

# MT: after the rename, the history written back through itself INLINE in the rotator's EXIT trap
# string (`cp history keep && cat keep > history`). It pins that a command written inline in a trap
# handler is a kill point: were it not, the write-through would run whole and MT would survive.
# Two edits, both proven to apply: the trap line replaced, and a flag set on the line after the
# rename so the handler writes only on a run that renamed.
MT_TRAP_OLD='trap '"'"'rm -rf "$TMPD"'"'"' EXIT'
MT_TRAP_NEW='trap '"'"'if [ -n "${_mt:-}" ]; then cp -- "$HISTORY" "$HIST_DIR/.mt-keep" && cat "$HIST_DIR/.mt-keep" > "$HISTORY"; rm -f -- "$HIST_DIR/.mt-keep"; fi; rm -rf "$TMPD"'"'"' EXIT'
if mut_line "$ROT" "$MD/mTa.sh" "$MT_TRAP_OLD" "$MT_TRAP_NEW" \
   && mut_after "$MD/mTa.sh" "$MD/mT.sh" "$MK_OLD" '_mt=1'; then
  score MT killed "$MD/mT.sh" "$CH" "$PH" "after the rename, the history copied back through itself inline in the EXIT trap string (a trap handler's inline commands are kill points)"
else bad "MT DID NOT APPLY — the EXIT trap line or the rename line is not in the rotator exactly once, or the insert did not land"; fi

# --- MUTANTS of BL-322's five edge-input fixes, each killed by the arm built for it ---------------
if mut_line "$ROT" "$MD/mH1.sh" 'if [ "$PREAMBLE_END" -gt 0 ]; then' 'if true; then'; then
  score mH1 h1head "$MD/mH1.sh" "$CH" "$PH" "the empty-preamble branch removed (sed -n 1,0p prints line 1)"
else bad "mH1 DID NOT APPLY — the preamble guard is not in the rotator exactly once"; fi

if mut_line "$ROT" "$MD/mNV.sh" 'need_value() {' 'need_value() { return 0'; then
  score mNV noval "$MD/mNV.sh" "$CH" "$PH" "a value-taking option's missing value no longer refused as usage"
else bad "mNV DID NOT APPLY — 'need_value() {' is not in the rotator exactly once"; fi

if mut_line "$ROT" "$MD/mK0.sh" 'if [ "$KEEP_ENTRIES" -lt 1 ]; then' 'if false; then'; then
  score mK0 keep0 "$MD/mK0.sh" "$CH" "$PH" "--keep-entries 0 no longer refused"
else bad "mK0 DID NOT APPLY — the zero guard is not in the rotator exactly once"; fi

if mut_line "$ROT" "$MD/mSM.sh" 'same_file() {' 'same_file() { return 1'; then
  score mSM same "$MD/mSM.sh" "$CH" "$PH" "the same-file guard removed (the archive appended to itself)"
else bad "mSM DID NOT APPLY — 'same_file() {' is not in the rotator exactly once"; fi

# Two layers, one mutant each: the refusal made a warning again, and the stage moved back after the
# rename (with its refusal intact, it then refuses over a history already shrunk).
if mut_line "$ROT" "$MD/mGF.sh" '    git -C "$GITROOT" add -- "$ARCHIVE" >/dev/null 2>&1 || {' '    git -C "$GITROOT" add -- "$ARCHIVE" >/dev/null 2>&1 || true || {'; then
  score mGF gitfail "$MD/mGF.sh" "$CH" "$PH" "a failed git add of the archive no longer refuses"
else bad "mGF DID NOT APPLY — the staging line is not in the rotator exactly once"; fi
if mut_line "$ROT" "$MD/mGOa.sh" 'stage_archive' ':' && mut_after "$MD/mGOa.sh" "$MD/mGO.sh" "$MK_OLD" 'stage_archive'; then
  score mGO gitfail "$MD/mGO.sh" "$CH" "$PH" "the stage moved back after the rename"
else bad "mGO DID NOT APPLY — the top-level stage call or the rename line is not in the rotator exactly once"; fi

# MTU: a rotator that turns off the sweep's DEBUG trace before its writes. The sweep cannot kill past
# it, so arm_killed refuses it by text; this pins the refusal.
if mut_after "$ROT" "$MD/mTU.sh" 'HIST_BASE="$(basename "$HISTORY")"' 'trap - DEBUG'; then
  score MTU killed "$MD/mTU.sh" "$CH" "$PH" "the rotator runs 'trap - DEBUG' before its writes (the sweep's trace switched off)"
else bad "MTU DID NOT APPLY — the HIST_BASE line is not in the rotator exactly once"; fi

# unw_probe asks whether THIS host and user can make a scratch file read as not writable (`[ -w ]`
# false, which is what the rotator's precheck reads) by one means: `mode` (chmod a-w, MCH), `flag`
# (chflags uchg, MCF) or `acl` (chmod +a, MCA). Where it cannot, the mutant is reported NOT SCORED,
# never KILLED: a mutant whose unwritable state this user writes through cannot die, and its
# survival is a fact about the user, not about the arm. The mutant is still built and proven to apply.
unw_probe() {  # <mode|flag|acl>: 0 when the means is available here and makes `[ -w ]` false
  local f="$WORK/unw-probe.$1" r=1
  : > "$f" || return 1
  case "$1" in
    mode) if chmod a-w "$f" 2>/dev/null; then [ -w "$f" ] || r=0; chmod u+w "$f"; fi ;;
    flag) if chflags uchg "$f" 2>/dev/null; then [ -w "$f" ] || r=0; chflags nouchg "$f"; fi ;;
    acl)  if chmod +a "user:$(id -un) deny write,append" "$f" 2>/dev/null; then [ -w "$f" ] || r=0; chmod -N "$f"; fi ;;
  esac
  rm -f "$f"; return "$r"
}

# MCH: the history made read-only at start-up and writable again just before the prechecks. A kill
# in between leaves every file's bytes as the template's and the history at mode 444; the re-run is
# refused (rc 1). It passed in round 9, when a killed world `diff -r` scored identical to the
# template skipped its own re-run; every killed world is re-run now. Root writes a 444 file and
# `[ -w ]` says so, so as root the re-run is NOT refused and the mutant cannot die: measured in
# Debian bookworm as root, MCH survived 269 kills with 0 failed. It is gated on unw_probe (below)
# exactly as MCF and MCA are: NOT SCORED where the mode bits cannot make a file read as unwritable.
MCH_RO='_ro=""; if [ -f "$HISTORY" ] && [ -w "$HISTORY" ]; then chmod a-w -- "$HISTORY"; _ro=1; fi'
MCH_RW='if [ -n "$_ro" ]; then chmod u+w -- "$HISTORY"; fi'
if mut_after "$ROT" "$MD/mCHa.sh" 'HIST_BASE="$(basename "$HISTORY")"' "$MCH_RO" \
   && mut_after "$MD/mCHa.sh" "$MD/mCH.sh" '# temp that cannot be built never leaves a block in the archive.' "$MCH_RW"; then
  if unw_probe mode; then
    score MCH killed "$MD/mCH.sh" "$CH" "$PH" "the history chmod a-w at start-up and u+w before the prechecks (a killed world differs from the template only in a mode)"
  else
    printf '  skip  %s NOT SCORED: this user can write a file with no write bits (root), so chmod a-w cannot make it read as not writable\n' MCH
  fi
else bad "MCH DID NOT APPLY — the HIST_BASE line or the precheck comment is not in the rotator exactly once, or an insert did not land"; fi

# MCF / MCA: MCH's shape with the unwritable state carried by a file FLAG (`chflags uchg`) and by a
# deny-write ACL (`chmod +a`) instead of the mode bits. A kill in between leaves every file's bytes
# AND every `ls -lAnR` field as the template's, and the re-run is refused (rc 1). Both passed in
# round 10, when a killed world matching the template by those two readings skipped its own re-run;
# each is killed only because every killed world is re-run. Both tools are
# BSD-only; each is gated on unw_probe, as MCH is.
MCF_RO='_ro=""; if [ -f "$HISTORY" ] && [ -w "$HISTORY" ]; then chflags uchg "$HISTORY"; _ro=1; fi'
MCF_RW='if [ -n "$_ro" ]; then chflags nouchg "$HISTORY"; fi'
if mut_after "$ROT" "$MD/mCFa.sh" 'HIST_BASE="$(basename "$HISTORY")"' "$MCF_RO" \
   && mut_after "$MD/mCFa.sh" "$MD/mCF.sh" '# temp that cannot be built never leaves a block in the archive.' "$MCF_RW"; then
  if unw_probe flag; then
    score MCF killed "$MD/mCF.sh" "$CH" "$PH" "the history chflags uchg at start-up and nouchg before the prechecks (a killed world differs from the template only in a file flag)"
  else
    printf '  skip  %s NOT SCORED: this host or user cannot make a file read as not writable with chflags uchg\n' MCF
  fi
else bad "MCF DID NOT APPLY — the HIST_BASE line or the precheck comment is not in the rotator exactly once, or an insert did not land"; fi

MCA_RO='_ro=""; if [ -f "$HISTORY" ] && [ -w "$HISTORY" ]; then chmod +a "user:$(id -un) deny write,append" "$HISTORY"; _ro=1; fi'
MCA_RW='if [ -n "$_ro" ]; then chmod -N "$HISTORY"; fi'
if mut_after "$ROT" "$MD/mCAa.sh" 'HIST_BASE="$(basename "$HISTORY")"' "$MCA_RO" \
   && mut_after "$MD/mCAa.sh" "$MD/mCA.sh" '# temp that cannot be built never leaves a block in the archive.' "$MCA_RW"; then
  if unw_probe acl; then
    score MCA killed "$MD/mCA.sh" "$CH" "$PH" "a deny-write ACL on the history at start-up, removed before the prechecks (a killed world differs from the template only in an ACL)"
  else
    printf '  skip  %s NOT SCORED: this host or user cannot make a file read as not writable with chmod +a (a BSD ACL)\n' MCA
  fi
else bad "MCA DID NOT APPLY — the HIST_BASE line or the precheck comment is not in the rotator exactly once, or an insert did not land"; fi

echo
if [ "$fails" -eq 0 ]; then
  echo "snapshot-archive-rotate: PASS"
else
  echo "snapshot-archive-rotate: FAIL ($fails)" >&2; exit 1
fi
