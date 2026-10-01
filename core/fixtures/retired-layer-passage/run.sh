#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# retired-layer-passage/run.sh — prove the passage detector fires on a reproduced core
# line, stays quiet on a paraphrase, and never emits a zero that cannot be told from a
# scan that opened nothing.
#
# THE DEFECT THIS EXISTS TO CATCH. `retired-layer-contract.sh` matches retired CONTRACT
# SHAPES — labelled directives and `{token}` placeholders — and states its own limit: a
# layer file carrying a retired construct as ordinary prose has no shape to match. Measured
# on the reference consumer, two extension entries reproduced deleted core lines VERBATIM
# and no detector in the directory opened them. The sibling could not have: on that pull
# its retired set was empty, so it exited before reading a layer file.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

echo "retired-layer-passage:"

OUT="$(bash "$SCRIPT" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" 2>/dev/null)"

# --- Assertion 0: SANITY -------------------------------------------------------
# Every negative assertion below would score a false pass against a detector emitting
# nothing at all, which is exactly how the sibling's blind spot survived nine releases.
if [ -n "$OUT" ]; then
  ok "the detector produced output against a layer file reproducing a deleted core line"
else
  bad "FIXTURE BROKEN — no output at all; every assertion below would be a false pass"
  echo; echo "retired-layer-passage: FIXTURE BROKEN" >&2; exit 2
fi

# --- Assertion 1: a renumbered, emphasised reproduction is flagged --------------
# The live findings differ from core only in list numbering and emphasis. If normalisation
# regresses, this arm is what notices.
grep -q 'extensions/restates.md' <<<"$OUT" \
  && ok "a deleted core line reproduced under different numbering and emphasis is flagged" \
  || bad "the reproduced core line was NOT flagged — normalisation no longer strips numbering or emphasis"

# --- Assertion 2: the row carries the LINE NUMBER of the layer file -------------
# Without this the operator gets a file and has to find the passage by hand, and a
# line-preserving normalisation could regress to a filtered one unnoticed.
grep -qE 'extensions/restates\.md:[0-9]+' <<<"$OUT" \
  && ok "  and the row names the line within that file" \
  || bad "  the row carries no line number — normalisation is dropping lines and the count has shifted"

# --- Assertion 3: a PARAPHRASE is NOT flagged -----------------------------------
# The documented limit, asserted so the matcher cannot drift into fuzzy comparison, which
# has no measured false-positive set behind it.
grep -q 'overrides/paraphrase.md' <<<"$OUT" \
  && bad "a paraphrase was flagged — the matcher has widened past exact reproduction" \
  || ok "a reworded paraphrase of a deleted line is NOT flagged (stated limit holds)"

# --- Assertion 4: an unrelated layer file is NOT flagged ------------------------
grep -q 'overrides/inert.md' <<<"$OUT" \
  && bad "a layer file reproducing nothing was flagged" \
  || ok "a layer file reproducing no deleted core line is not flagged"

# --- Assertion 5: nothing deleted -> no rows, and NEVER a silent zero -----------
# BOTH REFS ARE `BASE`, deliberately. This is the branch that produced the sibling's
# false clean: it exits before opening any layer file, so its output must say so or it
# reads exactly like a full scan that matched nothing.
NOOP="$(bash "$SCRIPT" "$DIST" "$BASE" "$BASE" "$CONSUMER" 2>/dev/null)"
[ -z "$NOOP" ] && ok "a release that deletes nothing reports no finding" \
  || bad "the detector reported a finding when base and theirs are identical"

NOOPERR="$(bash "$SCRIPT" "$DIST" "$BASE" "$BASE" "$CONSUMER" 2>&1 >/dev/null)"
grep -q 'NO layer file was opened' <<<"$NOOPERR" \
  && ok "  and that zero SAYS it opened no layer file, so it cannot read as coverage" \
  || bad "  a release deleting nothing produced a silent zero — the sibling's exact defect"
grep -q 'refusing to report clean' <<<"$NOOPERR" \
  && bad "  it reached the unreadable-corpus guard instead — this arm is testing the wrong branch" \
  || ok "  and it reached the nothing-deleted branch, not the unreadable-corpus guard"

# --- Assertion 6: scanned-but-no-match carries its denominator ------------------
EMPTYC="$WORK/empty-consumer"
mkdir -p "$EMPTYC/.claude/skills/ai-dlc/overrides"
printf '# reproduces nothing core ever carried\n' > "$EMPTYC/.claude/skills/ai-dlc/overrides/x.md"
DEN="$(bash "$SCRIPT" "$DIST" "$BASE" "$THEIRS" "$EMPTYC" 2>&1 >/dev/null)"
grep -qE 'deleted rulebook line\(s\) checked against [1-9][0-9]* layer file\(s\)' <<<"$DEN" \
  && ok "a scanned-but-no-match run reports its denominator, so the zero has a control" \
  || bad "a scanned-but-no-match run reported no denominator — indistinguishable from opening nothing"
DENOUT="$(bash "$SCRIPT" "$DIST" "$BASE" "$THEIRS" "$EMPTYC" 2>/dev/null)"
[ -z "$DENOUT" ] \
  && ok "  and that run emits no finding row, so the denominator describes a genuine zero" \
  || bad "  the empty-consumer run emitted a finding — the denominator arm is not measuring a zero"

# --- Assertion 7: an unreadable rulebook list WARNS, never reports clean --------
# The corpus is read from setup-sites.md. If that read fails the retired set is empty and
# the run would otherwise be indistinguishable from a release that deleted nothing.
BADSCRIPT="$WORK/orphan.sh"
cp "$SCRIPT" "$BADSCRIPT"          # a copy whose sibling setup-sites.md does not exist
ORPHERR="$(bash "$BADSCRIPT" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" 2>&1 >/dev/null)"; ORPHRC=$?
# THE EXIT IS THE HALF THE DRIVER READS. `apply.sh` refuses on this detector's non-zero exit only,
# so a refusal LINE beside exit 0 reached it as a clean run with no row -- the words were right and
# the status contradicted them. Modelled on retired-layer-token's assertion 14.
{ grep -q 'refusing to report clean' <<<"$ORPHERR" && [ "$ORPHRC" -eq 2 ]; } \
  && ok "an unreadable rulebook list warns loudly instead of reporting clean, and exits 2" \
  || bad "an unreadable rulebook list produced no warning or did not exit 2 (rc=$ORPHRC) — apply.sh would read it as a clean run"

# --- Assertion 7b: a setup-sites.md that EXISTS and cannot be READ refuses, exit 2 -
# The orphan above has NO file; this world has one the read fails on. It is a DIRECTORY named
# setup-sites.md rather than a mode-000 file, because root reads a mode-000 file and the arm would
# then drive the healthy path under another name; a directory is unreadable as a file for every
# user. The copy is the WHOLE reconcile directory, so lib.sh sits beside it and the only thing
# missing is a readable rulebook list.
RLP_SRC="$(cd "$(dirname "$SCRIPT")" && pwd)"
rlp_unreadable() { # rlp_unreadable <reconcile-dir-copy> -> 0 when the copy refuses with exit 2 and no row
  local d="$1" out err rc
  rm -f "$d/setup-sites.md"; mkdir "$d/setup-sites.md" || return 1
  out="$(bash "$d/retired-layer-passage.sh" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" 2>"$WORK/rlp-unread.err")"; rc=$?
  err="$(cat "$WORK/rlp-unread.err")"
  RLP_WHY="rc=$rc rows=$(printf '%s' "$out" | grep -c .) err=$(printf '%s' "$err" | head -1 | cut -c1-100)"
  [ "$rc" -eq 2 ] && [ -z "$out" ] && grep -q 'could not read the rulebook list from setup-sites.md' <<<"$err"
}
rlp_copy() { # rlp_copy <dir> -> a whole copy of the reconcile directory whose unmutated run still flags the row
  mkdir -p "$1" && cp -R "$RLP_SRC"/. "$1"/ && [ -f "$1/lib.sh" ] && [ -f "$1/setup-sites.md" ]
}
UNR="$WORK/unreadable-sites"
if ! rlp_copy "$UNR"; then
  bad "FIXTURE BROKEN — could not copy the reconcile directory for the unreadable-setup-sites.md arm"
elif ! grep -q 'extensions/restates.md' <<<"$(bash "$UNR/retired-layer-passage.sh" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" 2>/dev/null)"; then
  bad "FIXTURE BROKEN — the unmutated directory copy does not flag restates.md, so a refusal below would be the copy failing, not the read"
elif rlp_unreadable "$UNR"; then
  ok "a setup-sites.md that exists and cannot be read refuses with exit 2 and no row ($RLP_WHY)"
else
  bad "a setup-sites.md that cannot be read did not refuse with exit 2 and no row ($RLP_WHY) — apply.sh reads exit 0 as a clean run"
fi

# --- Mutant for 7/7b: the refusal's `exit 2` restored to the base `exit 0` -------
# Both arms are EXIT-shaped, and the refusal line prints either way, so only a mutant shows the
# exit is what they read. Built in a whole directory copy (lib.sh beside it), anchored on the
# `exit` that follows the refusal line, guarded by `cmp -s` and `bash -n`, and given a PRESENCE
# control: the mutant copy must still flag restates.md with a readable list, so a copy that never
# ran cannot score the kill.
MUT="$WORK/mut-exit0"
if ! rlp_copy "$MUT"; then
  bad "MUTANT HARNESS BROKEN [rlp-exit0]: could not copy the reconcile directory"
elif ! sed '/could not read the rulebook list from setup-sites.md/{n;s/^  exit 2$/  exit 0/;}' \
       "$RLP_SRC/retired-layer-passage.sh" > "$MUT/retired-layer-passage.sh"; then
  bad "MUTANT DID NOT APPLY [rlp-exit0]: sed exited non-zero, so no mutant exists"
elif cmp -s "$RLP_SRC/retired-layer-passage.sh" "$MUT/retired-layer-passage.sh"; then
  bad "FIXTURE STALE [rlp-exit0]: the mutation matched nothing in retired-layer-passage.sh. Re-anchor on the exit after the refusal line, never relax the assertion"
elif ! bash -n "$MUT/retired-layer-passage.sh" 2>/dev/null; then
  bad "FIXTURE STALE [rlp-exit0]: the mutant does not parse"
elif ! grep -q 'extensions/restates.md' <<<"$(bash "$MUT/retired-layer-passage.sh" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" 2>/dev/null)"; then
  bad "MUTANT HARNESS BROKEN [rlp-exit0]: the mutant copy does not flag restates.md with a readable list, so it is not running"
elif rlp_unreadable "$MUT"; then
  bad "MUTANT SURVIVED [rlp-exit0]: restoring exit 0 after the refusal line still passed 7b ($RLP_WHY), so the arm does not read the exit"
else
  ok "mutant [rlp-exit0] KILLED by 7b: with the base exit 0 restored, the unreadable list reads as a clean run ($RLP_WHY)"
fi

# --- BL-355: an accented capital still folds to its lower-case form ----------------
# norm_lines folded case under LC_ALL=C, which folds ASCII only: core deleting `1. Élan must …` and a
# layer carrying `- élan must …` stopped matching. The fold now runs in the caller's locale when the
# staged stream is valid UTF-8, and under C otherwise -- so a Latin-1 layer file is still READ.
#   N1 a UTF-8 caller, a layer reproducing the deleted line with the accented capital lowered -> its row
#   N2 a UTF-8 caller, a SECOND consumer that also holds a Latin-1 file reproducing an ASCII deleted
#      line -> exit 0 and the Latin-1 file's row (a fold run in the caller's locale on Latin-1 bytes
#      dies with "Illegal byte sequence" and the run refuses)
#   N0 control: a same-case accented reproduction, under a C caller -> its row
#   N3 the N1 run with a BYTE-WISE `tr` stub first on PATH -> the same rows and exit as the system `tr`
N_SKIP=0
if ! grep -qF 'iconv -f UTF-8 -t UTF-8' "$RLP_SRC/lib.sh"; then
  case "$RLP_SRC" in
    */core/skills/ai-dlc-update/reconcile) echo "  --    (BL-355: this lib.sh carries no iconv-gated fold; in the distribution N0-N2 run anyway and must go red)" ;;
    *) echo "  SKIP  BL-355 N0-N2 -- the installed lib.sh predates the locale-aware fold; it lands with the pull that carries this fixture"; N_SKIP=1 ;;
  esac
fi
# Captured, never `locale -a | grep -q`: under pipefail grep's early exit gives `locale` an EPIPE
# and the pipeline reports NOT-FOUND on a list that contains the locale.
N_LOCALES="$(locale -a 2>/dev/null)" || N_LOCALES=""
if [ "$N_SKIP" = 0 ] && ! grep -qx 'en_US.UTF-8' <<<"$N_LOCALES"; then
  bad "FIXTURE BROKEN -- en_US.UTF-8 is not installed here, so BL-355's caller-locale fold cannot be expressed"
  N_SKIP=1
fi
if [ "$N_SKIP" = 0 ]; then
  NW="$WORK/bl355"; ND="$NW/dist"; mkdir -p "$ND/core/skills/ai-dlc/steps" || exit 2
  git -C "$ND" init -q || exit 2
  printf '# Accent step\n\n1. \303\211lan must always be recorded in the story file before merge.\n2. Caf\303\251 owners sign the release note.\n3. Every gate run is logged before the merge.\n' \
    > "$ND/core/skills/ai-dlc/steps/accent.md"
  git -C "$ND" -c user.email=f@f -c user.name=f add -A && git -C "$ND" -c user.email=f@f -c user.name=f commit -qm base || exit 2
  NB="$(git -C "$ND" rev-parse HEAD)"
  printf '# Accent step\n\n1. Nothing here any more.\n' > "$ND/core/skills/ai-dlc/steps/accent.md"
  git -C "$ND" -c user.email=f@f -c user.name=f commit -qam theirs || exit 2
  NT="$(git -C "$ND" rev-parse HEAD)"
  N1C="$NW/c1"; mkdir -p "$N1C/.claude/skills/ai-dlc/extensions" || exit 2
  printf -- '- \303\251lan must always be recorded in the story file before merge.\n' > "$N1C/.claude/skills/ai-dlc/extensions/lowered.md"
  printf -- '- Caf\303\251 owners sign the release note.\n' > "$N1C/.claude/skills/ai-dlc/extensions/samecase.md"
  N2C="$NW/c2"; cp -R "$N1C" "$N2C" || exit 2
  printf -- '# caf\351\n- Every gate run is logged before the merge.\n' > "$N2C/.claude/skills/ai-dlc/extensions/latin1.md"
  # SEED CONTROL: the Latin-1 file really is invalid UTF-8, or N2 cannot express the refusal.
  iconv -f UTF-8 -t UTF-8 < "$N2C/.claude/skills/ai-dlc/extensions/latin1.md" >/dev/null 2>&1 \
    && { bad "FIXTURE BROKEN -- the Latin-1 seed validates as UTF-8, so N2 expresses nothing"; N_SKIP=1; }
  # N3's world: a BYTE-WISE `tr` first on PATH, the shape GNU coreutils `tr` has under a UTF-8
  # locale (measured: `É` = \303\211 folds to \343\211). The stub handles only the case fold in a
  # UTF-8 locale -- +0x20 on A-Z and on \300-\336 -- and execs the real `tr` for everything else, so
  # `norm()`'s `tr 'A-Z' 'a-z'`, `tr -d` and the C fold run the system binary.
  N_REAL_TR="$(command -v tr)" || N_REAL_TR=""
  NSTUB="$NW/trstub"; mkdir -p "$NSTUB" || exit 2
  cat > "$NSTUB/tr" <<'TRSTUB'
#!/usr/bin/env bash
_lc="${LC_ALL:-${LC_CTYPE:-${LANG:-}}}"
case "$_lc" in *UTF-8*|*utf8*|*UTF8*|*utf-8*)
  if [ "$#" -eq 2 ] && [ "$1" = '[:upper:]' ] && [ "$2" = '[:lower:]' ]; then
    [ -n "${FX_TR_HITS:-}" ] && echo hit >> "$FX_TR_HITS"
    LC_ALL=C exec "$FX_REAL_TR" 'A-Z\300-\336' 'a-z\340-\376'
  fi ;;
esac
exec "$FX_REAL_TR" "$@"
TRSTUB
  chmod +x "$NSTUB/tr" || exit 2
  # SEED CONTROL: the stub resolves first and really corrupts the multibyte capital, or N3 expresses nothing.
  _sb="$(printf '\303\211' | PATH="$NSTUB:$PATH" FX_REAL_TR="$N_REAL_TR" LC_ALL=en_US.UTF-8 tr '[:upper:]' '[:lower:]' 2>/dev/null)"
  if [ -z "$N_REAL_TR" ] || [ "$_sb" != "$(printf '\343\211')" ]; then
    bad "FIXTURE BROKEN -- the byte-wise tr stub does not fold \\303\\211 to \\343\\211, so N3 expresses nothing"; N_SKIP=1
  fi
fi
if [ "$N_SKIP" = 0 ]; then
  score_355() { # score_355 <reconcile-dir> -> failing cells, then `.`
    local _r="" _o _rc
    _o="$(env -u LANG LC_ALL=C bash "$1/retired-layer-passage.sh" "$ND" "$NB" "$NT" "$N1C" 2>/dev/null)"
    grep -q 'extensions/samecase.md' <<<"$_o" || _r="${_r}N0"
    _o="$(env -u LANG LC_ALL=en_US.UTF-8 bash "$1/retired-layer-passage.sh" "$ND" "$NB" "$NT" "$N1C" 2>/dev/null)"
    grep -q 'extensions/lowered.md' <<<"$_o" || _r="${_r}N1"
    _o="$(env -u LANG LC_ALL=en_US.UTF-8 bash "$1/retired-layer-passage.sh" "$ND" "$NB" "$NT" "$N2C" 2>/dev/null)"; _rc=$?
    { [ "$_rc" -eq 0 ] && grep -q 'extensions/latin1.md' <<<"$_o"; } || _r="${_r}N2"
    # N3: the N1 run with the byte-wise stub first on PATH reads exactly what the system `tr` reads --
    # the same rows and the same exit (no red, no silent wrong match). Whether that verdict is the
    # RIGHT one is N1's; N3 owns only its independence from the `tr` implementation.
    local _s _src
    _s="$(env -u LANG LC_ALL=en_US.UTF-8 bash "$1/retired-layer-passage.sh" "$ND" "$NB" "$NT" "$N1C" 2>/dev/null)"; _src=$?
    _o="$(env -u LANG LC_ALL=en_US.UTF-8 PATH="$NSTUB:$PATH" FX_REAL_TR="$N_REAL_TR" FX_TR_HITS="$NW/stub.hits" \
      bash "$1/retired-layer-passage.sh" "$ND" "$NB" "$NT" "$N1C" 2>/dev/null)"; _rc=$?
    { [ "$_rc" -eq "$_src" ] && [ -n "$_o" ] && [ "$_o" = "$_s" ]; } || _r="${_r}N3"
    printf '%s.' "$_r"
  }
  : > "$NW/stub.hits"
  got="$(score_355 "$RLP_SRC")"
  # POSITIVE CONTROL for N3: the subject's fold reached the stub, or N3 compared two system-tr runs.
  [ -s "$NW/stub.hits" ] || bad "FIXTURE BROKEN -- the byte-wise tr stub was never invoked, so N3 compared two system-tr runs"
  case "$got" in
    .) ok "BL-355 N0-N3: an accented capital folds under a UTF-8 caller, a same-case control matches under C, a Latin-1 layer file is still read (exit 0), and a byte-wise tr first on PATH changes no verdict" ;;
    *.) bad "BL-355 cell(s) [${got%.}] failed: an accented reproduction is missed, a Latin-1 file refuses the run, or the verdict depends on which tr resolves" ;;
    *) bad "FIXTURE BROKEN -- the BL-355 cells did not complete" ;;
  esac
  n355_mut() { # n355_mut <name> <want> <find> <replace>
    local _d="$WORK/bl355-$1"
    if ! rlp_copy "$_d"; then bad "MUTANT HARNESS BROKEN [BL-355 $1]: could not copy the reconcile directory"; return; fi
    if ! python3 - "$RLP_SRC/lib.sh" "$_d/lib.sh" "$3" "$4" <<'PY'
import sys
src, dst, f, r = sys.argv[1:5]
s = open(src, encoding="utf-8").read()
if s.count(f) != 1: sys.exit(1)
open(dst, "w", encoding="utf-8").write(s.replace(f, r))
PY
    then bad "FIXTURE STALE [BL-355 $1]: its anchor did not match exactly once in lib.sh -- re-anchor on the same observable"; return; fi
    if cmp -s "$RLP_SRC/lib.sh" "$_d/lib.sh" || ! bash -n "$_d/lib.sh" 2>/dev/null; then
      bad "FIXTURE STALE [BL-355 $1]: the mutation did not apply or does not parse"; return; fi
    got="$(score_355 "$_d")"
    case "$got" in
      "$2.") ok "MUTANT (BL-355 $1) fails exactly [$2]" ;;
      .)     bad "MUTANT SURVIVED [BL-355 $1]: every cell still passed" ;;
      *)     bad "MUTANT [BL-355 $1] failed [${got%.}], expected exactly [$2]" ;;
    esac
  }
  # THE HOST's `tr` DECIDES WHAT TWO OF THESE MUTANTS CAN EXPRESS, so their vectors are derived from
  # it, never hardcoded. Measured with GNU tr 9.11 first on PATH: it folds byte by byte (so trusting it
  # misses N1 as well) and passes a Latin-1 byte through rather than dying (so dropping the C locale
  # from the fallback breaks nothing on that host). Both facts are probed here, in the cells' locale.
  H_TR_FOLDS=0; H_TR_REFUSES=0
  [ "$(printf '\303\211' | LC_ALL=en_US.UTF-8 tr '[:upper:]' '[:lower:]' 2>/dev/null)" = "$(printf '\303\251')" ] && H_TR_FOLDS=1
  [ "$(printf 'caf\351\n' | LC_ALL=en_US.UTF-8 tr '[:upper:]' '[:lower:]' 2>/dev/null)" = "$(printf 'caf\351')" ] || H_TR_REFUSES=1
  echo "  --    (BL-355 host: tr=$(command -v tr) folds-multibyte=$H_TR_FOLDS refuses-latin1=$H_TR_REFUSES)"
  # the 0.652.0 shape: the fold always byte-wise
  n355_mut c-fold N1 '; then _nf="$(_norm_fold_probe)"; fi' '; then _nf=c; fi'
  # the ungated fix: LC_ALL=C dropped from the C fold, so a Latin-1 file is folded in the caller's locale
  if [ "$H_TR_REFUSES" = 1 ]; then
    n355_mut no-gate N2 "      *)   LC_ALL=C tr '[:upper:]' '[:lower:]' < \"\$_nt\" || _rc=\$? ;;" "      *)   tr '[:upper:]' '[:lower:]' < \"\$_nt\" || _rc=\$? ;;"
  else
    echo "  SKIP  MUTANT (BL-355 no-gate) -- this host's tr reads a Latin-1 byte under UTF-8 without refusing, so the mutant expresses nothing here"
  fi
  # the unprobed fold: the locale `tr` trusted whatever resolves on PATH (the tip shape GNU tr broke)
  if [ "$H_TR_FOLDS" = 1 ]; then w_np=N3; else w_np=N1N3; fi
  n355_mut no-probe "$w_np" '; then _nf="$(_norm_fold_probe)"; fi' '; then _nf=tr; fi'
  # the probe without its awk candidate: a byte-wise tr falls to the C fold and misses the accent
  if [ "$H_TR_FOLDS" = 1 ]; then w_na=N3; else w_na=N1; fi
  n355_mut no-awk "$w_na" '  [ "$_got" = "$_want" ] && { echo awk; return 0; }' '  :'
fi

echo
if [ "$fails" -eq 0 ]; then echo "retired-layer-passage: PASS"; exit 0; fi
echo "retired-layer-passage: $fails assertion(s) FAILED" >&2
exit 1
