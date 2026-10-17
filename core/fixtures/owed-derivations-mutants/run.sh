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

anchor_count() { ANCHOR="$2" awk 'index($0, ENVIRON["ANCHOR"]) { n++ } END { print n + 0 }' "$1"; }
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

# M2 (REWRITTEN by the current-sprint-only ruling): the reader treats a PAST-sprint row as OPEN. The
# earlier M2, "reader filters to the step scan dir", is reversed along with the contract's STAYS-OPEN seeds.
mutate M2-reader-treats-past-as-open reader "Sp1 Sp5 Sp7" \
  'if [ "$sc" = PAST ]; then' \
  's/^  if \[ "\$sc" = PAST \]; then$/  if false; then/'

# M11 (RE-ANCHORED by BL-631): the helper runs an UNSCOPED join, so a past sprint's break is run, printed
# NEWLY-FAILING and offered to the writer. The writer's own PAST arm, this mutant's old subject, was deleted
# once the join itself kept only CURRENT and LIVING files; the property moved there, so the mutation does
# too: the helper's lift of vd_join() kills the scope gate on the way in. DECLARED SET, measured: Sp3a Sp3b Hw1
# Hw2 are the out-of-scope rows the dropped files no longer print; Wb Wc Wd We Wf Wg are the writer world,
# whose past-sprint break the unscoped join now runs, prints and records (BL-631 item 3, the helper's join). W0
# (exit 1 without --record-owed) holds: the LIVING break fails either way.
# Both strings carry single quotes, so they are read from quoted heredocs, byte for byte.
M11_ANCHOR="$(cat <<'M11A'
eval "$(awk '/^vd_join\(\) \{/,/^\}/' "$SELF/apply.sh" 2>/dev/null)"
M11A
)"
M11_SED="$(cat <<'M11S'
s#^eval "\$(awk '/\^vd_join\\(\\) \\{/,/\^\\}/' "\$SELF/apply.sh" 2>/dev/null)"$#eval "$(awk '/^vd_join\\(\\) \\{/,/^\\}/' "$SELF/apply.sh" 2>/dev/null | sed 's/^    if \\[ "\\$VD_HITS" -gt 0 \\] || \\[ "\\$VD_SCANNED" -lt "\\$VD_LISTED" \\]; then$/    if false; then/')"#
M11S
)"
mutate M11-writer-records-past writer "Sp3a Sp3b Hw1 Hw2 Wb Wc Wd We Wf Wg" "$M11_ANCHOR" "$M11_SED"

# M12: the classifier reads LIVING as PAST (a prd.md row stops being enforced, and the writer drops it).
# Hw2 Sp3b are BL-631's re-pointed out-of-scope rows; W0 Wb are the writer world's exit, which moves because the
# helper's join now reads this classifier and drops the LIVING break as PAST (BL-631 item 3).
mutate M12-classifier-living-as-past reader "B1b B1f B3a B5d B7a Bt1b Gf Ha3 Ha4 Ha5 Hc1 Hn Hw1 Hw2 Sc5 Sc7 Sc8 Sl1 Sl2 Sp3a Sp3b Sp4 W0 Wb Wc Wd We Wf Wg" \
  '  SCOPE_TOKEN=LIVING' \
  's/^  SCOPE_TOKEN=LIVING$/  SCOPE_TOKEN=PAST/'

# M13: the classifier matches the sprint segment as a SUBSTRING/prefix, so s19 reads as sprint 1.
mutate M13-classifier-substring-segment reader "Sc1 Sp7" \
  '    if [ "$((10#$SP_N))" -eq "$CUR" ]; then SCOPE_TOKEN=CURRENT; else SCOPE_TOKEN=PAST; fi' \
  's/^    if \[ "\$((10#\$SP_N))" -eq "\$CUR" \]; then SCOPE_TOKEN=CURRENT; else SCOPE_TOKEN=PAST; fi$/    case "$SP_N" in "$CUR"*) SCOPE_TOKEN=CURRENT ;; *) SCOPE_TOKEN=PAST ;; esac/'

# M15: HISTORY is checked AFTER the sprint classification instead of first: a history file inside the
# current sprint (s<current>/archive/) reads CURRENT again, and the writer records it. Hw3 is BL-631's
# never-RUN arm for the dropped history file. Wd is not declared: the writer records only what the join keeps
# (BL-631 item 3), so the row it compares no longer moves; M3 is Wd's killer.
mutate M15-history-checked-after-current reader "Ha6 Hl3 Hr Hs Hw1 Hw2 Hw3 Sl4 Wc Wf Wg" \
  '  if is_history "$p"; then SCOPE_TOKEN=HISTORY; return 0; fi' \
  '/^  if is_history "\$p"; then SCOPE_TOKEN=HISTORY; return 0; fi$/d;s/^  SCOPE_TOKEN=LIVING$/  if is_history "$p"; then SCOPE_TOKEN=HISTORY; return 0; fi; SCOPE_TOKEN=LIVING/'

# M16: the classifier never returns HISTORY. Ha7 Ha8 Ha9 are BL-631's history-companion arms and Hw3 its
# never-RUN arm; Wd is not declared, as for M15.
mutate M16-classifier-never-history reader "Ha6 Ha7 Ha8 Ha9 Hl3 Hr Hs Hw1 Hw2 Hw3 Sl4 Wc Wf Wg" \
  '  if is_history "$p"; then SCOPE_TOKEN=HISTORY; return 0; fi' \
  's/^  if is_history "\$p"; then SCOPE_TOKEN=HISTORY; return 0; fi$/  if false; then SCOPE_TOKEN=HISTORY; return 0; fi/'

# M17 (REPLACED): EVERY file in the live gate-adjudication directory is CURRENT, whatever its stem. The
# older-stem and no-live-stem worlds read HISTORY, so only they can see it.
mutate M17-every-live-dir-file-current reader "Hl4 Hl5 Hl8 Hl9" \
  '          SCOPE_TOKEN=HISTORY' \
  's/^          SCOPE_TOKEN=HISTORY$/          SCOPE_TOKEN=CURRENT/'

# M20: the OLDER stem is picked as the live one (the comparison is reversed). Both the live-nonce world
# (now HISTORY) and the older-stem world (now CURRENT) see it.
mutate M20-older-stem-picked-as-live reader "Hl1 Hl1b Hl2 Hl4 Hl5" \
  '    if [ "$_ts" \> "$LIVE_TS" ]; then LIVE_TS="$_ts"; LIVE_STEM="$_stem"; fi' \
  's/if \[ "\$_ts" \\> "\$LIVE_TS" \]; then/if [ -z "$LIVE_TS" ] || [ "$_ts" \\< "$LIVE_TS" ]; then/'

# M18: the batch classifier resolves and classifies nothing and defaults every path to LIVING. --scope runs
# through scope_batch too, so every --scope arm moves; the reader's per-row scoping calls classify directly,
# so Wg (the reader over the writer's over-recorded rows) stays green and is not declared. Ha7 Ha8 Ha9 are
# BL-631's history-companion arms, Hw3 and Sp3c its never-RUN arms; Wd is not declared, as for M15.
mutate M18-batch-defaults-living reader "Bt1b Ha1 Ha2 Ha6 Ha7 Ha8 Ha9 Hc2 Hl1 Hl1b Hl3 Hl4 Hl6 Hl7 Hl8 Hl9 Hn Hs Hw1 Hw2 Hw3 Sc1 Sc2 Sc3 Sc4 Sc6 Sc9 Sl Sl3 Sl4 Sp3a Sp3b Sp3c Wc Wf" \
  '    classify "$_bp"' \
  's/^    classify "\$_bp"$/    SCOPE_TOKEN=LIVING/'

# (M19 and the Bd binding arms are REMOVED: HISTORY no longer copies is_archive, it matches exact names.)

# M23: HISTORY matches a basename by SUBSTRING/suffix (`*-history.md`, `*-archive*.md`), as the old is_archive
# copy did. The live look-alikes then read HISTORY. RE-ANCHORED by BL-631 on the companion line, which gained
# carry-over-backlog-archive.md and architecture-history.md; the property is unchanged. DECLARED SET: measured
# in the slot and sent to the lead before it is written (the archive-notes near-miss joins Hn).
mutate M23-substring-archive-match reader "Ha1 Ha2 Ha3 Hn" \
  '    prd-history.md|product-brief-history.md|carry-over-backlog-archive.md|architecture-history.md) return 0 ;;' \
  's/^    prd-history\.md|product-brief-history\.md|carry-over-backlog-archive\.md|architecture-history\.md) return 0 ;;$/    *-history.md|*-archive*.md|prd-history.md|product-brief-history.md|carry-over-backlog-archive.md|architecture-history.md) return 0 ;;/'

# M24: the `archive` directory is matched as a SUBSTRING of a component, so `archived/` and `archive-notes/`
# read HISTORY.
mutate M24-archive-dir-substring reader "Ha4 Ha5 Hn" \
  '  case "$p" in _bmad-output/*) case "/${p%/*}/" in */archive/*) return 0 ;; esac ;; esac' \
  's|\*/archive/\*) return 0|*/archive*/*) return 0|'

# ---- Bs: the SLOT_RE copy is BOUND to what `artifact-path-config.sh --slot-re` prints ----------------
# Both are asserted on the pristine reader (equal), and a drifted copy must differ, so the arm can fail.
slot_of() { sed -n "s/^SLOT_RE='\(.*\)'\$/\1/p" "$1" | head -1; }
slot_cfg="$(AI_DLC_PROJECT_ROOT="$ROOT" bash "$ROOT/core/scripts/artifact-path-config.sh" --slot-re 2>/dev/null)"
if [ -n "$slot_cfg" ] && [ "$(slot_of "$READER")" = "$slot_cfg" ]; then ok "Bs1 the reader's SLOT_RE equals what artifact-path-config.sh --slot-re prints ($slot_cfg)"; else bad "Bs1 SLOT_RE copy ($(slot_of "$READER")) differs from --slot-re ($slot_cfg)"; fi
sed "s/^SLOT_RE='\^s\[0-9\]+\$'/SLOT_RE='^s[0-9]*\$'/" "$READER" > "$WORK/slotdrift.sh"
if cmp -s "$READER" "$WORK/slotdrift.sh"; then bad "Bs2 the slot drift mutation DID NOT APPLY"
elif [ "$(slot_of "$WORK/slotdrift.sh")" != "$slot_cfg" ]; then ok "Bs2 M21-slot-re-copy-drifts: KILLED by the binding arm (declared: Bs1 on the pristine copy, Bs2 on the drifted one)"
else bad "Bs2 M21-slot-re-copy-drifts: SURVIVED"; fi

# ---- Bh: the HISTORY companion names are BOUND to the writer's own pair list ---------------------------
# SKILL.md's "Current-state live, history archive" rule names each living artifact beside the file its
# superseded text is MOVED to (`<live>` -> `<history>`). Every history side must be on the reader's companion
# case line and no live side may be. Derived, never hand-listed: two names were once missing from a hand list.
# A pair list shorter than the floor means the paragraph was respelled and the join reads nothing, so it
# refuses rather than passing; a copy with one companion deleted must fail, so the arm can fire.
SKILL="$ROOT/core/skills/ai-dlc/SKILL.md"
printf 'HERMETIC-CONSUMED core/skills/ai-dlc/SKILL.md\n'
bh_pairs() { awk '/Current-state live, history archive/ { s = 1 } s { printf "%s ", $0 } s && /Nothing is ever dropped/ { exit }' "$SKILL" \
  | grep -oE '`[a-z0-9.-]+\.md` -> `[a-z0-9.-]+\.md`' | tr -d '`' | sed 's/ -> /\t/'; }
bh_line() { grep -E '^    prd-history\.md\|' "$1" | head -1; }
bh_miss() { # <reader> -> problems, empty when bound
  local f="$1" line live hist out=""
  line="|$(bh_line "$f" | sed 's/) return 0 ;;$//; s/^ *//')|"
  while IFS="$(printf '\t')" read -r live hist; do
    case "$line" in *"|$hist|"*) ;; *) out="$out missing:$hist" ;; esac
    case "$line" in *"|$live|"*) out="$out live-listed:$live" ;; esac
  done <<<"$(bh_pairs)"
  printf '%s' "$out"
}
bh_n="$(bh_pairs | grep -c .)" || bh_n=0
if [ "$bh_n" -lt 4 ]; then bad "Bh0 SKILL.md's live -> history pair list yields $bh_n pair(s), below the floor of 4 -- the paragraph was respelled and the binding reads nothing"
elif [ -z "$(bh_line "$READER")" ]; then bad "Bh1 the reader carries no companion case line opening with prd-history.md"
elif [ -z "$(bh_miss "$READER")" ]; then ok "Bh1 every one of SKILL.md's $bh_n history companions is on the reader's companion line, and no live side is"
else bad "Bh1 companion binding broken:$(bh_miss "$READER")"; fi
sed 's/|architecture-history\.md) return 0 ;;$/) return 0 ;;/' "$READER" > "$WORK/bhdrift.sh"
if cmp -s "$READER" "$WORK/bhdrift.sh"; then bad "Bh2 the companion-deletion mutation DID NOT APPLY"
elif [ -n "$(bh_miss "$WORK/bhdrift.sh")" ]; then ok "Bh2 M25-companion-dropped: KILLED by the binding arm (declared: Bh1 on the pristine reader, Bh2 on the drifted copy)"
else bad "Bh2 M25-companion-dropped: SURVIVED"; fi

# ---- Bg: the live-stem rule is BOUND to the guard's own lines (core/hooks/ai-dlc-gate-remediation-guard.sh:790-804)
# The guard is frozen and is not edited. The three lines that DEFINE the rule must appear byte-for-byte in
# both files, and a drifted reader copy (a shorter timestamp pattern) must lose one.
GUARD="$ROOT/core/hooks/ai-dlc-gate-remediation-guard.sh"
bg_lines='  _ts="${_stem##*-}"
    [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]T[0-9][0-9][0-9][0-9][0-9][0-9]Z) ;;
if [ "$_ts" \> "$LIVE_TS" ]; then LIVE_TS="$_ts"'
bg_miss() { # <file> -> names of the bound lines it lacks
  local f="$1" l n=0 miss=""
  while IFS= read -r l; do
    l="${l#"${l%%[![:space:]]*}"}"; n=$((n + 1))
    grep -qF -- "$l" "$f" || miss="$miss $n"
  done <<<"$bg_lines"
  printf '%s' "$miss"
}
if [ -z "$(bg_miss "$GUARD")" ] && [ -z "$(bg_miss "$READER")" ]; then ok "Bg1 the guard and the reader carry the same three live-stem rule lines"; else bad "Bg1 live-stem rule lines differ: guard lacks [$(bg_miss "$GUARD")] reader lacks [$(bg_miss "$READER")]"; fi
sed 's/T\[0-9\]\[0-9\]\[0-9\]\[0-9\]\[0-9\]\[0-9\]Z) ;;/T[0-9]Z) ;;/' "$READER" > "$WORK/gdrift.sh"
if cmp -s "$READER" "$WORK/gdrift.sh"; then bad "Bg2 the guard drift mutation DID NOT APPLY"
elif [ -n "$(bg_miss "$WORK/gdrift.sh")" ]; then ok "Bg2 M22-live-stem-rule-copy-drifts: KILLED by the binding arm (declared: Bg1 on the pristine pair, Bg2 on the drifted copy)"
else bad "Bg2 M22-live-stem-rule-copy-drifts: SURVIVED"; fi

# M14: the reader trusts a REPOINTED row without re-deriving the new derivation.
mutate M14-reader-trusts-repointed reader "Rp2 Rp3 Rp3b Rp4b Rp7 Rp9" \
  '  pre=""; [ "$hops" -gt 0 ] && pre="REPOINTED-"' \
  's/^  pre=""; \[ "\$hops" -gt 0 \] \&\& pre="REPOINTED-"$/  pre=""; [ "$hops" -gt 0 ] \&\& continue/'

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
mutate M6-reader-trusts-any-command-line reader "B5c Rp3b" \
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
mutate M9-malformed-row-accepted reader "B4g B4h B4i B4j Rp5" \
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
# The in-tree side of the implementation-readiness-report HISTORY shape. The writer (BMAD's own skill, whose
# outputFile is `{planning_artifacts}/implementation-readiness-report-{{date}}.md`) is NOT in this repo and is
# NOT checked here; only that ai-dlc still invokes the skill at its two call sites.
pk "Pk1 route.md 0a says exit 0 can print INFO lines" "Exit 0 can still print INFO lines" route.md
pk "Pk2 route.md 0a names the history INFO kind" "INFO history" route.md
pk "Pk3 route.md 0a states the planning-gate-only sentence" "shown and carried but never refused" route.md
pk "Pk4 Check 37 states the planning-gate-only sentence" "shown and carried but never refused" gate-validation.md
pk "Pk5 retro.md discloses both INFO kinds as not closed" "INFO history" retro.md
pk "Pa2 architecture.md still invokes bmad-check-implementation-readiness" '/bmad-check-implementation-readiness' architecture.md
pk "Pa3 stories-test-strategy.md still invokes bmad-check-implementation-readiness" '/bmad-check-implementation-readiness' stories-test-strategy.md
pk "Pb gate-validation.md carries the owed-derivation check, keyed on any non-zero exit" "Any exit other than 0" gate-validation.md
pk "Pb2 and its deny text names the REPOINTED remedy" "REPOINTED<TAB>" gate-validation.md
pk "Pb3 and says exit 2 is refused and unassessed" "rows are REFUSED and unassessed, never closed" gate-validation.md
pk "Pb4 and the same-file UNRUN rule" "makes every owed row in it UNASSESSED" gate-validation.md
pk "Pb5 and the disclosure that past-sprint rows stop blocking" "STOPS BLOCKING" gate-validation.md
pk "Pb5b and the INFO history class" "INFO history" gate-validation.md
pk "Pb5c and the live gate-adjudication remedy" "is cleared by rotating it" gate-validation.md
pk "Pb6 the check is in the planning row of the gate manifest" "35, 36, 37" gate-validation.md
pk "Pb7 _gate-procedures.md keeps only a pointer" "refused at gate-validation.md Check 37" _gate-procedures.md
pk "Pc the sprint-close site carries open rows forward, one item per key" "ONE" retro.md
pk "Pd retro.md names the reader" "check-owed-derivations.sh" retro.md
pk "Pf route.md 0a names the REPOINTED remedy" "REPOINTED<TAB>" route.md
pk "Pg route.md 0a carries the disclosure that past-sprint rows stop blocking" "STOPS BLOCKING" route.md
printf 'HERMETIC-CONSUMED core/skills/ai-dlc-update/SKILL.md\n'
pk "Ph the update SKILL.md names the REPOINTED remedy" "REPOINTED<TAB>" "../../ai-dlc-update/SKILL.md"
if grep -qF -- "carries only a pointer line" "$STEPS/route.md"; then bad "Pi route.md still claims a snapshot pointer line exists"; else ok "Pi route.md claims no snapshot pointer line"; fi
if grep -qF -- "REPOINTED<TAB>" "$ROOT/core/skills/ai-dlc-update/reconcile/apply.sh"; then ok "Pj apply.sh row text names the REPOINTED remedy"; else bad "Pj apply.sh row text lacks the REPOINTED remedy"; fi
if grep -qF -- "ZQXJ-no-such-string-in-the-rulebook" "$STEPS/route.md" 2>/dev/null; then bad "Pe control: an impossible string was found"; else ok "Pe control: an impossible string is absent from route.md"; fi

if [ "$fails" -ne 0 ]; then
  printf '  %s assertion(s) FAILED\n' "$fails"; exit 1
fi
printf '  all mutants applied and killed\n'
exit 0
