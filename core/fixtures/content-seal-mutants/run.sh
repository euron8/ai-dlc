#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
# content-seal-mutants/run.sh -- the mutation battery behind `content-seal`. DISTRIBUTION-ONLY.
#
# Each mutant is a COPY of the whole declared tree (content-seal's own inputs.decl, plus the fixture
# itself), so every reader finds its siblings and the recorder finds its library -- a lone-script
# mutant would find none and be silent for that reason. One line family of one file is edited in the
# copy, guarded by a before/after count on the SUBJECT'S OWN predicate, and the shipped fixture's
# run.sh is run from the copy. Its `FAIL  CS-<id>:` lines are the kill set.
#
# THE KILL SET IS READ AGAINST THE UNMUTATED CONTROL, built and run the same way: a mutant's kill set
# is the arms it fails that the control passes. The control must itself have run (its output names a
# seal library under ITS copy root, and its baseline arms CS-M0, CS-J0 and CS-G0 print `ok`), or every
# mutant verdict is refused: two inert runs compare equal.
#
# THE MUTANTS, each required to kill EXACTLY its declared set:
#   SA  drop the seal append      the recorder computes the row and never writes it
#   SC  drop the sha comparison   --check accepts every file whatever its bytes
#   SF  restore the agent_id filter on seal rows (BOTH reads: the --check table and --row)
#   SP  drop the program seal row at all three --record call sites
#   SD  drop --merge's refusal of a sealless gate part once the recorder was live (D2)
#   KP  --mark drops its pre-check, so a Bash-amended sealed file is marked and re-sealed
#   KU  --mark seals unconditionally, so a file with no seal row gains one
#   KD  --mark seals the bytes on disk after its move, not the bytes it wrote
#   KR  the program:wait-for-deliverable remedy case is gone (the generic "re-run" one answers)
# Exit: 0 every mutant killed exactly its set and the control ran clean; 1 a mismatch; 2 broken.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT=""
_d="$HERE"
while [ -n "$_d" ] && [ "$_d" != "/" ]; do
  [ -f "$_d/core/fixtures/content-seal/inputs.decl" ] && { ROOT="$_d"; break; }
  _d="$(dirname "$_d")"
done
[ -n "$ROOT" ] || { echo "FIXTURE ERROR: core/fixtures/content-seal/inputs.decl not found above $HERE" >&2; exit 2; }
DECL="$ROOT/core/fixtures/content-seal/inputs.decl"
echo "HERMETIC-CONSUMED core/fixtures/content-seal/inputs.decl"
# macOS puts a trailing slash on TMPDIR; WORK is re-read through `pwd` so it is spelled exactly as the
# copy's own `cd && pwd` resolution spells it, which is what the control's path check compares.
WORK="$(mktemp -d "${TMPDIR:-/tmp}/content-seal-mutants.XXXXXX")" || exit 2
trap 'rm -rf "$WORK"' EXIT
WORK="$(cd "$WORK" && pwd)" || exit 2
fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails + 1)); }

# Each mutant must kill exactly its set, LESS the arms the unmutated control already fails: the
# control's FAIL set is subtracted from both sides, so an arm red on the base tree is never credited
# to a mutant and never owed by one. CS-M6, CS-J4 and CS-J5 are the widened-set arms (suffix-less
# shard dirs and the joined records sealed); on an engine that seals neither they are red on the
# control and drop out here, and on one that does they are owed as listed.
# THE SETS BELOW ARE EXPECTED, UNMEASURED for the widened engine: the additions over the measured
# b6822f00 kill sets -- SA: CS-G4 CS-J4 CS-M6 CS-M6b; SC: CS-J5 CS-M6 CS-M6b; SF: CS-J5; SP: CS-J5;
# SD: CS-G4 -- are derived from the engine, and this battery has not been run on it.
EXP_SA="CS-G1 CS-G2 CS-G3 CS-G4 CS-J1 CS-J2 CS-J3 CS-J4 CS-M1 CS-M2 CS-M3 CS-M3b CS-M4 CS-M5 CS-M6 CS-M6b"
EXP_SC="CS-G3 CS-J2 CS-J3 CS-J5 CS-M2 CS-M3 CS-M6 CS-M6b"
# SF owes CS-J5 too: a program row is appended with an EMPTY agent_id (content-seal.sh seal_record),
# so the filter drops it and the python3-rewritten joined record reads as never sealed.
EXP_SF="CS-J5 CS-M3"
EXP_SP="CS-G1b CS-J1b CS-J5 CS-M1b"
# SD: only the refusing cell of CS-G4; its two merging twins (CS-G4b, CS-G4c) pass either way.
EXP_SD="CS-G4"
# The --mark mutants. EXPECTED, UNMEASURED: derived from the arms, not yet scored.
EXP_KP="CS-J7 CS-K2"
EXP_KU="CS-J8 CS-K3"
EXP_KD="CS-J9 CS-K4"
EXP_KR="CS-K5"

copy_tree() { # <dest> -- every declared path, and the fixture directory itself
  local dst="$1" p
  mkdir -p "$dst" || return 1
  while IFS= read -r p; do
    p="${p#!}"; p="${p%/}"
    [ -n "$p" ] || continue
    mkdir -p "$dst/$(dirname "$p")" || return 1
    cp -R "$ROOT/$p" "$dst/$p" || return 1
  done <<DECLEOF
$(grep -v '^#' "$DECL" | grep .)
core/fixtures/content-seal
DECLEOF
}
# run_copy <copy root> <out file> -> FAILSET (sorted ids, space-joined), RANOK (1 when the copy ran)
run_copy() {
  bash "$1/core/fixtures/content-seal/run.sh" > "$2" 2>&1
  FAILSET="$(sed -n 's/^  FAIL  \(CS-[A-Za-z0-9]*\):.*/\1/p' "$2" | sort -u | tr '\n' ' ')"; FAILSET="${FAILSET% }"
  RANOK=0
  grep -qF "resolved seal library = $1/core/scripts/content-seal.sh" "$2" \
    && grep -q '^  ok    CS-M0:' "$2" && grep -q '^  ok    CS-J0:' "$2" && grep -q '^  ok    CS-G0:' "$2" \
    && ! grep -qE 'FIXTURE (BROKEN|ERROR)' "$2" && RANOK=1
  return 0
}
minus() { # <set A> <set B> -> A \ B, sorted, space-joined
  local a
  a="$(printf '%s\n' $1 | grep . | sort -u | comm -23 - <(printf '%s\n' $2 | grep . | sort -u) | tr '\n' ' ')"
  printf '%s' "${a% }"
}
norm() { local a; a="$(printf '%s\n' $1 | grep . | sort -u | tr '\n' ' ')"; printf '%s' "${a% }"; }

# mutate <copy root> <rel file> <perl substitution> <count-before ERE> <count-after ERE>
# Refuses (rc 1) unless the before-pattern was present and the after-pattern is gone.
mutate() {
  local f="$1/$2" b a
  b="$(grep -cE "$4" "$f")" || b=0
  [ "$b" -gt 0 ] || { echo "DID NOT APPLY: $2 holds no match for $4" >&2; return 1; }
  perl -0pi -e "$3" "$f" || { echo "DID NOT APPLY: perl failed on $2" >&2; return 1; }
  a="$(grep -cE "$5" "$f")" || a=0
  [ "$a" = 0 ] || { echo "DID NOT APPLY: $2 still holds $a match(es) for $5" >&2; return 1; }
  return 0
}

echo "content-seal-mutants:"
# MC: the unmutated control.
C0="$WORK/control"; copy_tree "$C0" || { echo "FIXTURE ERROR: the control copy failed" >&2; exit 2; }
run_copy "$C0" "$WORK/control.out"; BASE="$FAILSET"
# Only the widened-set arms may be red on the control; any other red arm is a harness or engine
# defect, and subtracting it would excuse every mutant that also fails it.
WIDENED="CS-J4 CS-J5 CS-M6"
[ -z "$(minus "$BASE" "$WIDENED")" ] || { echo "FIXTURE BROKEN: the unmutated control fails {$(minus "$BASE" "$WIDENED")}, outside the widened-set arms {$WIDENED}" >&2; exit 2; }
if [ "$RANOK" = 1 ]; then ok "MC: the unmutated copy ran (seal library resolved under the copy, baselines ok); base FAIL set {${BASE}}"
else echo "FIXTURE BROKEN: the unmutated control did not run; its output:" >&2; grep -E 'resolved seal|CS-[MJG]0|FIXTURE' "$WORK/control.out" >&2; exit 2; fi

score() { # <id> <expected set> -- the copy at $WORK/<id> is already mutated
  local id="$1" exp got
  run_copy "$WORK/$id" "$WORK/$id.out"
  [ "$RANOK" = 1 ] || { bad "$id: the mutated copy did not run, so its verdict is not a kill: $(grep -E 'BROKEN|ERROR' "$WORK/$id.out" | head -1)"; return; }
  got="$(minus "$FAILSET" "$BASE")"; exp="$(minus "$2" "$BASE")"
  if [ -n "$got" ] && [ "$got" = "$exp" ]; then ok "$id: killed exactly {$got}"
  else bad "$id: killed {$got}, expected {$exp}"; fi
}

# SA: the recorder's one append becomes a no-op.
copy_tree "$WORK/SA" && mutate "$WORK/SA" core/hooks/ai-dlc-content-seal.sh \
  's/^seal_append "\$\{LOG_DIR\}/: "\${LOG_DIR}/m' '^seal_append "' '^seal_append "' \
  && score SA "$EXP_SA" || bad "SA: the mutant was not built"
# SC: the byte comparison is gone; every row-bearing file passes.
copy_tree "$WORK/SC" && mutate "$WORK/SC" core/scripts/content-seal.sh \
  's/\[ -n "\$have" \] && \[ "\$have" = "\$want" \] && continue/continue/' '"\$have" = "\$want"' '"\$have" = "\$want"' \
  && score SC "$EXP_SC" || bad "SC: the mutant was not built"
# SF: both seal reads drop rows with an empty agent_id (the filter the artifact-write reads carry).
copy_tree "$WORK/SF" && mutate "$WORK/SF" core/scripts/content-seal.sh \
  's/select\(\.kind == "content-seal"\)/select(.kind == "content-seal") | select((.agent_id \/\/ "") != "")/g' \
  'select\(\.kind == "content-seal"\)' 'select\(\.kind == "content-seal"\)($| \| select\(\.path)' \
  && score SF "$EXP_SF" || bad "SF: the mutant was not built"
# SP: every program --record call becomes a no-op, in all three readers.
copy_tree "$WORK/SP" \
  && mutate "$WORK/SP" core/scripts/merge-adversarial-shards.sh 's/bash "\$SEAL" --record/true "\$SEAL" --record/' 'bash "\$SEAL" --record' 'bash "\$SEAL" --record' \
  && mutate "$WORK/SP" core/scripts/join-remediator-shards.sh 's/bash "\$SEAL" --record/true "\$SEAL" --record/' 'bash "\$SEAL" --record' 'bash "\$SEAL" --record' \
  && mutate "$WORK/SP" core/scripts/validate-gate-adjudication.sh 's/\["bash", SEAL_LIB, "--record"/["true", SEAL_LIB, "--record"/' '"bash", SEAL_LIB, "--record"' '"bash", SEAL_LIB, "--record"' \
  && score SP "$EXP_SP" || bad "SP: the mutant was not built"
# SD: the sealless-part refusal's condition never holds.
copy_tree "$WORK/SD" && mutate "$WORK/SD" core/scripts/validate-gate-adjudication.sh \
  's/if first_t is not None and nonce_t is not None and first_t < nonce_t:/if False:/' \
  'first_t < nonce_t:' 'first_t < nonce_t:' \
  && score SD "$EXP_SD" || bad "SD: the mutant was not built"
# KP: the sealed-bytes pre-check never refuses.
copy_tree "$WORK/KP" && mutate "$WORK/KP" core/scripts/wait-for-deliverable.sh \
  's/if \[ -z "\$MK_WANT" \] \|\| \[ "\$MK_HAVE" != "\$MK_WANT" \]; then/if false; then/' \
  '"\$MK_HAVE" != "\$MK_WANT"' '"\$MK_HAVE" != "\$MK_WANT"' \
  && score KP "$EXP_KP" || bad "KP: the mutant was not built"
# KU: every marked file under planning-artifacts/ is sealed, row or no row.
copy_tree "$WORK/KU" && mutate "$WORK/KU" core/scripts/wait-for-deliverable.sh \
  's/MK_STATE=""; MK_ROWED=0; MK_SRC=/MK_STATE=""; MK_ROWED=1; MK_SRC=/' \
  'MK_ROWED=0; MK_SRC=' 'MK_ROWED=0; MK_SRC=' \
  && score KU "$EXP_KU" || bad "KU: the mutant was not built"
# KD: the row records whatever is on disk after the move.
copy_tree "$WORK/KD" && mutate "$WORK/KD" core/scripts/wait-for-deliverable.sh \
  's/--record-expect "\$MK_STATE" program:wait-for-deliverable "\$MK_EXP" "\$MK_FILE"/--record "\$MK_STATE" program:wait-for-deliverable "\$MK_FILE"/' \
  'bash "\$MK_SEAL" --record-expect' 'bash "\$MK_SEAL" --record-expect' \
  && score KD "$EXP_KD" || bad "KD: the mutant was not built"
# KR: the --mark remedy case is deleted.
copy_tree "$WORK/KR" && mutate "$WORK/KR" core/scripts/content-seal.sh \
  's/^    program:wait-for-deliverable\) printf [^\n]*\n//m' \
  '^    program:wait-for-deliverable\) printf' '^    program:wait-for-deliverable\) printf' \
  && score KR "$EXP_KR" || bad "KR: the mutant was not built"
# The program-row mutant is keyed on the readers' own call: the three readers together must hold
# exactly three --record calls in the unmutated tree and none in the mutant.
n0="$(cat "$C0"/core/scripts/merge-adversarial-shards.sh "$C0"/core/scripts/join-remediator-shards.sh "$C0"/core/scripts/validate-gate-adjudication.sh | grep -cE 'bash "\$SEAL" --record|"bash", SEAL_LIB, "--record"')" || n0=0
n1="$(cat "$WORK"/SP/core/scripts/merge-adversarial-shards.sh "$WORK"/SP/core/scripts/join-remediator-shards.sh "$WORK"/SP/core/scripts/validate-gate-adjudication.sh | grep -cE 'bash "\$SEAL" --record|"bash", SEAL_LIB, "--record"')" || n1=0
if [ "$n0" = 3 ] && [ "$n1" = 0 ]; then ok "SP-K: the three readers hold 3 program --record calls, the SP mutant 0"
else bad "SP-K: program --record calls: control $n0 (want 3), mutant $n1 (want 0)"; fi

echo "content-seal-mutants: $fails failure(s)"
[ "$fails" -eq 0 ] && { echo "PASS content-seal-mutants"; exit 0; }
echo "FAIL content-seal-mutants"; exit 1
