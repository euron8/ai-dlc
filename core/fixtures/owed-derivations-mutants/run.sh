#!/usr/bin/env bash
# owed-derivations-mutants -- the mutation battery behind core/fixtures/owed-derivations.
# DISTRIBUTION-ONLY (see .dist-only).
#
# Usage: run.sh
# Exit:  0 every mutant applied and was killed by (at least) its declared arms,
#        1 a mutant survived, did not apply, or was not killed by the arm that owns it,
#        2 the harness could not run, so no verdict is readable.
#
# Each mutant removes ONE behaviour from a COPY of the subject (the reader is one file; the writer is
# copied with its whole reconcile directory, because it lifts functions out of apply.sh and
# preclassify.sh beside itself). The sibling fixture is then driven against the copy and the set of
# arms that FAIL must CONTAIN the set the mutant declares. Every anchor is asserted UNIQUE in the
# pristine subject first, against an impossible-anchor control that must count 0, and the driver must
# print the path of the COPY it resolved, so a mutant that killed nothing cannot be a file never loaded.
# THE CONTROL IS THE UNMUTATED COPY and carries positive conjuncts (`all assertions hold`, an arm row).
set -uo pipefail

for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset CLAUDE_PROJECT_DIR 2>/dev/null || true

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE"
while [ "$ROOT" != "/" ] && [ ! -f "$ROOT/scripts/install.sh" ]; do ROOT="$(dirname "$ROOT")"; done
[ -f "$ROOT/scripts/install.sh" ] \
  || { echo "FIXTURE ERROR: no scripts/install.sh above $HERE -- cannot resolve the distribution root" >&2; exit 2; }
RECON="$ROOT/core/skills/ai-dlc-update/reconcile"
READER="$ROOT/core/scripts/check-owed-derivations.sh"
WRITER="$RECON/derivation-differential.sh"
DRIVER="$ROOT/core/fixtures/owed-derivations/run.sh"
for f in "$READER" "$WRITER" "$DRIVER"; do
  [ -f "$f" ] || { echo "FIXTURE ERROR: $f not found -- this battery is distribution-only" >&2; exit 2; }
done

WORK="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails + 1)); }

echo "owed-derivations-mutants:"
printf 'HERMETIC-CONSUMED core/scripts/check-owed-derivations.sh\n'
printf 'HERMETIC-CONSUMED core/skills/ai-dlc-update/reconcile/derivation-differential.sh\n'

anchor_count() { awk -v a="$2" 'index($0, a) { n++ } END { print n + 0 }' "$1"; }
if [ "$(anchor_count "$READER" 'ZQXJ-no-such-anchor-in-this-reader')" = 0 ] && [ "$(anchor_count "$READER" 'set -uo pipefail')" = 1 ]; then
  ok "anchor control: an impossible anchor counts 0 and a known line counts 1"
else
  bad "anchor control: the counter cannot tell 0 from 1 -- every uniqueness claim below is unreadable"
  exit 2
fi

failed_arms() { sed -n 's/^  FAIL  \([A-Z][0-9a-z]*\) .*/\1/p' "$1" | sort -u; }

# ---- the unmutated control: driven through a COPY of the whole reconcile directory -----------
CW="$WORK/control-recon"; mkdir -p "$CW"; cp -R "$RECON/." "$CW/" || { echo "FIXTURE ERROR: could not copy $RECON" >&2; exit 2; }
for s in apply.sh preclassify.sh derivation-differential.sh; do
  [ -f "$CW/$s" ] || { echo "FIXTURE ERROR: the copied reconcile directory lacks $s" >&2; exit 2; }
done
cp "$READER" "$WORK/control-reader.sh"
bash "$DRIVER" "$WORK/control-reader.sh" "$CW/derivation-differential.sh" > "$WORK/control.log" 2>&1; crc=$?
if [ "$crc" -eq 0 ] && grep -q '^  all assertions hold$' "$WORK/control.log" \
   && grep -q '^  ok    B1a ' "$WORK/control.log" \
   && grep -q '^  ok    Wd ' "$WORK/control.log" \
   && grep -qF "reader: $WORK/control-reader.sh" "$WORK/control.log" \
   && grep -qF "writer: $CW/derivation-differential.sh" "$WORK/control.log"; then
  ok "control: the unmutated copies pass every arm, B1a and Wd are present, and the driver resolved the COPIES"
else
  bad "control: the unmutated copies did not pass cleanly (exit $crc) -- no mutant verdict below is readable"
  sed 's/^/        | /' "$WORK/control.log" | head -30
  exit 2
fi

# mutate <label> <reader|writer> <declared arms> <anchor> <sed script>
mutate() {
  local label="$1" which="$2" declared="$3" anchor="$4" script="$5" subj d n rc missed rd wr
  if [ "$which" = reader ]; then subj="$READER"; else subj="$WRITER"; fi
  n="$(anchor_count "$subj" "$anchor")"
  if [ "$n" != 1 ]; then
    bad "$label: DID NOT APPLY -- its anchor occurs $n time(s) in the subject, expected exactly 1: $anchor"
    return
  fi
  d="$WORK/$label"; mkdir -p "$d"; cp -R "$RECON/." "$d/" || { bad "$label: could not copy the reconcile directory"; return; }
  if ! sed "$script" "$subj" > "$d/mutant.out" 2>"$WORK/$label.sed.err"; then
    bad "$label: DID NOT APPLY -- sed failed: $(head -2 "$WORK/$label.sed.err" | tr '\n' ' ')"
    return
  fi
  if cmp -s "$subj" "$d/mutant.out"; then
    bad "$label: DID NOT APPLY -- the sed matched nothing, the copy is byte-identical"
    return
  fi
  rd="$READER"; wr="$d/derivation-differential.sh"
  if [ "$which" = reader ]; then rd="$d/check-owed-derivations.sh"; mv "$d/mutant.out" "$rd"; else mv "$d/mutant.out" "$wr"; fi
  [ -f "$d/apply.sh" ] && [ -f "$d/preclassify.sh" ] || { bad "$label: the sibling programs are absent from the mutant's directory"; return; }
  ok "$label: applied ($(diff "$subj" "$d/$( [ "$which" = reader ] && echo check-owed-derivations.sh || echo derivation-differential.sh )" | grep -c '^[<>]') changed line(s))"
  bash "$DRIVER" "$rd" "$wr" > "$WORK/$label.log" 2>&1; rc=$?
  if ! grep -qF "reader: $rd" "$WORK/$label.log" || ! grep -qF "writer: $wr" "$WORK/$label.log"; then
    bad "$label: the driver did not resolve the mutated copy -- its verdict is about another file"
    return
  fi
  failed_arms "$WORK/$label.log" > "$WORK/$label.moved"
  printf '%s\n' $declared | sort -u > "$WORK/$label.declared"
  if [ "$rc" -eq 0 ] || [ ! -s "$WORK/$label.moved" ]; then
    bad "$label: SURVIVED -- the driver exited $rc with no arm failing"
    return
  fi
  if [ "$rc" -ne 1 ]; then
    bad "$label: the driver exited $rc, not 1 -- the harness broke rather than an arm"
    return
  fi
  missed="$(comm -13 "$WORK/$label.moved" "$WORK/$label.declared" | tr '\n' ' ')"
  extra="$(comm -23 "$WORK/$label.moved" "$WORK/$label.declared" | tr '\n' ' ')"
  if [ -z "$missed" ] && [ -z "$extra" ]; then
    ok "$label: KILLED -- the failing set EQUALS its declared arms: $(tr '\n' ' ' < "$WORK/$label.declared")"
  else
    bad "$label: failing set differs from the declared arms. declared-but-green: [${missed}] failed-but-undeclared: [${extra}]"
  fi
}

# M1: the reader trusts status TEXT: a file whose prose says "closed" is never reported open.
mutate M1-reader-trusts-status-text reader "B2a B2b" \
  '  if [ -n "$reason" ]; then' \
  's/^  if \[ -n "\$reason" \]; then$/  if [ -n "$reason" ] \&\& ! grep -qi closed "$ROOT\/$rel" 2>\/dev\/null; then/'

# M2: the reader filters to the step scan dir: rows outside s<N>/ are skipped unread.
mutate M2-reader-filters-to-scan-dir reader "B1b B3a B7a Wg Gf" \
  '  reason=""' \
  's/^  reason=""$/  reason=""; case "$rel" in _bmad-output\/planning-artifacts\/s[0-9]*\/*) ;; *) continue ;; esac/'

# M3: the writer drops the recorded and actual outputs from the record row.
mutate M3-writer-drops-recorded-actual writer "Wd We" \
  'rr = (k in REC) ? REC[k] : ""; aa = (k in ACT) ? ACT[k] : ""' \
  's/rr = (k in REC) ? REC\[k\] : ""; aa = (k in ACT) ? ACT\[k\] : ""/rr = ""; aa = ""/'

# M4: an absent record is treated as a refusal, and it PRINTS one (a silent exit 2 would leave B4b green).
mutate M4-absent-treated-as-refusal reader "B4a B4b" \
  '[ -e "$REC" ] || [ -L "$REC" ] || exit 0' \
  's/^\[ -e "\$REC" \] || \[ -L "\$REC" \] || exit 0$/[ -e "$REC" ] || [ -L "$REC" ] || { echo "REFUSED: absent" >\&2; exit 2; }/'

# M5: an unreadable record is treated as absent (exit 0). It still prints REFUSED, so only the EXIT-CODE arms see it.
mutate M5-unreadable-treated-as-absent reader "B4d B4e B4f" \
  'exists and cannot be read as a file' \
  '/exists and cannot be read as a file/s/exit 2; }/exit 0; }/'

# M6: the command-equality conjunct of the false-zero guard is removed: a `$ ` line in a derived fence
# is accepted whatever command it holds. B5c has the file present and the recorded line holding a
# DIFFERENT `$ ` command that reproduces, so the validator is silent and the row would read closed.
mutate M6-reader-trusts-any-command-line reader "B5c" \
  'st == 2 && substr(t, 1, 2) == "$ " && substr(t, 3) == want { print NR }' \
  's/ \&\& substr(t, 3) == want//'

# M7: supersession is ignored: a superseded key is judged by its own (silent) verdict, not its later copy's.
mutate M7-reader-ignores-supersession reader "B6a" \
  '      if [ -n "$sup" ]; then' \
  's/^      if \[ -n "\$sup" \]; then$/      if false; then/'

# M8: the writer writes WITHOUT the flag (a default record under TMPDIR). Only the no-flag control sees it.
mutate M8-writer-writes-without-flag writer "Wa" \
  'OWED_FILE=""; OWED_SET=0; LOG_NAME="reconcile-log-unnamed"' \
  's|^OWED_FILE=""; OWED_SET=0;|OWED_FILE="${TMPDIR:-/tmp}/owed-default.tsv"; OWED_SET=1;|'

# M9: a malformed row is accepted instead of refusing the record.
mutate M9-malformed-row-accepted reader "B4g B4h B4i B4j" \
  '{ bad = NR; exit }' \
  's/{ bad = NR; exit }/{ }/'

# M10: a row the validator could not assess (exit 2) reads closed instead of UNASSESSED.
mutate M10-unassessed-reads-closed reader "B8b" \
  'reason="UNASSESSED"' \
  's/reason="UNASSESSED"/reason=""/'

# ---- P: the caller prose (dist-only: a consumer at update step 2 still holds the OLD rulebook) ------
STEPS="$ROOT/core/skills/ai-dlc/steps"
pk() { if grep -qF -- "$2" "$STEPS/$3" 2>/dev/null; then ok "$1"; else bad "$1 -- $STEPS/$3 lacks: $2"; fi; }
pk "Pa route.md Step 0a runs the reader on resume" "check-owed-derivations.sh" route.md
pk "Pb the gate site REFUSES the gate on an open row" "The gate is REFUSED while an owed derivation is open" _gate-procedures.md
pk "Pc the sprint-close site carries open rows forward, one item per key" "ONE" retro.md
pk "Pd retro.md names the reader" "check-owed-derivations.sh" retro.md
if grep -qF -- "ZQXJ-no-such-string-in-the-rulebook" "$STEPS/route.md" 2>/dev/null; then bad "Pe control: an impossible string was found"; else ok "Pe control: an impossible string is absent from route.md"; fi

if [ "$fails" -ne 0 ]; then
  printf '  %s assertion(s) FAILED\n' "$fails"; exit 1
fi
printf '  all mutants applied and killed\n'
exit 0
