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

echo
if [ "$fails" -eq 0 ]; then echo "retired-layer-passage: PASS"; exit 0; fi
echo "retired-layer-passage: $fails assertion(s) FAILED" >&2
exit 1
