#!/usr/bin/env bash
# fixture-inprocess -- drive the REAL scripts/validate-fixture-inprocess.sh (BL-879's static half) against seeded probe
# projects, and score one committed mutant per arm.
#
# THE SUBJECT is the shipping validator, copied byte-identical (cmp -s) with the two siblings it calls -- the judge
# scripts/validate-fixture-invocations.sh (its --static-join, --b2-census and --cells-parse) and
# scripts/validate-fixture-hygiene.sh (the ONE shared m4, extracted between its M4 markers) -- into each probe
# project, which carries VERSION so the validator's root walk resolves to the PROBE. Every verdict is read off the
# validator's output; nothing here re-implements a rule. The dynamic arms (C1-C3, the stale row) are the judge's and
# are scored by fixture-invocation-budget, through the real runner.
#
# THE WORLDS, each built once:
#   dirty   fnew starts g.sh once with no cells.decl (R), fwhy declares an e2e cell with an empty why= (C4), fguard
#           declares a cli cell on a subject whose only guard is a DATA STRING (C5); fok (one guarded cli cell) and
#           fzero (no start, no cells.decl) are the near-misses beside them. No allowlist.
#   clean   the same five, fixed: fnew gains its cell, fwhy its reason, fguard's subject a column-0 guard statement.
#   listed  clean plus an allowlist with one well-formed row naming fok (`--complete` must refuse it).
# THE ARMS, each one read of a validator run:
#   DR  dirty, gate          rc 1, `FAIL  R fnew: core/scripts/g.sh declares 1 start(s) against 0 cell(s)`
#   D4  dirty, gate          rc 1, the C4 line naming fwhy:1
#   D5  dirty, gate          rc 1, the C5 line naming fguard's data-string subject
#   DQ  dirty, gate          the near-misses fok and fzero carry no finding
#   C   clean, gate          rc 0 and the OK line (a run that scanned nothing cannot print it)
#   N   clean, gate          the scanned count is the probe's own (5 fixtures), so the root walk resolved to the probe
#   DV  dirty, --derive      writes exactly fguard, fnew and fwhy as rows, the same bytes on a second run
#   K   listed, --complete   rc 1, `INCOMPLETE  1 allowlist row(s) remain` (its twin is C: the empty list completes)
#   DG  both pre-push hooks: the READSET_VS span, extracted and sourced the way core/scripts/hermetic-run.sh does it,
#       gives a listed fixture's digest input `#inproc listed <its cells.decl sha256>` and an unlisted one's
#       `#inproc unlisted none` (dg.sh, no bash start beyond its own)
#   DS  the same span extracts with readset_vs_store, readset_vs_input and readset_vs_inproc defined (DG's twin)
# The dirty world's anp-shaped NP finding is held by the validator's own self-probe (anp FIRES, anpq QUIET).
#   NM  a plain run executes no matrix-only cell (control: the per-push mutant drives ran)
# THE MUTANTS are copies of the probe with one line of the validator (or of the judge, for C5) changed once, guarded
# by cmp -s. MR, MC5 and MN are refused by the validator's own self-probe, which runs before the corpus, so every arm
# of theirs is dead by construction and the kill is scored on that refusal; MK is past the self-probe and is decided
# by K alone.
# MUTANT-MATRIX MR decides=DR,D4,D5,DQ,C,N,DV,K twins=- why=the self-probe refuses the whole run when the R row is dropped
# MUTANT-MATRIX MC5 decides=DR,D4,D5,DQ,C,N,DV,K twins=- why=the self-probe refuses the whole run when C5 reads every subject as guarded
# MUTANT-MATRIX MN decides=DR,D4,D5,DQ,C,N,DV,K twins=- why=the self-probe refuses the whole run when scanned==listed is dropped
# MUTANT-MATRIX MK decides=K twins=C
# MUTANT-MATRIX MNP decides=DR,D4,D5,DQ,C,N,DV,K twins=- why=the self-probe refuses the whole run when the NP row is dropped
# MUTANT-MATRIX MDG decides=DG twins=DS
# MUTANT-MATRIX-REMEASURE bash core/fixtures/fixture-inprocess/run.sh --matrix
# Re-measure it whenever an arm or a mutant is added or changed.
#   MR   the unlisted-refusal R row is never printed         -> DR reads the self-probe refusal on the probe verdict
#   MC5  fxc_guarded counts every file as guarded (judge)    -> D5 reads the self-probe refusal: the judge's OWN
#        self-probe (C5 cell), run by --b2-census, is red, so the probe tree cannot be joined
#   MN   the scanned == listed refusal made false            -> N reads the self-probe refusal
#   MK   --complete's remaining-rows branch made false       -> K reads rc 0 on a non-empty allowlist (twin C holds)
#   MNP  np_rows' core/fixtures/ parent test made false      -> DR reads the self-probe refusal (anp no longer FIRES)
#   MDG  readset_vs_input's `readset_vs_inproc` call replaced by `:` in BOTH hooks -> DG reads no #inproc row in
#        either hook (twin DS holds: the span still extracts with every function defined)
#
# THE IN-PROCESS CELLS of this fixture are its own cells.decl: every validator start is one e2e cell, tagged at its
# start, and the judge starts the validator makes are covered by one nested row.
#
# Usage: run.sh [--matrix]     Exit: 0 pass, 1 FAIL, 2 FIXTURE BROKEN.
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "fixture-inprocess: FIXTURE BROKEN: core/fixtures/lib/preamble.sh is absent" >&2; exit 2; }
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
MODE=plain; [ "${1:-}" = --matrix ] && MODE=matrix
ROOT=""; d="$HERE"
while [ -n "$d" ] && [ "$d" != / ]; do
  [ -f "$d/scripts/validate-fixture-inprocess.sh" ] && [ -f "$d/scripts/validate-fixture-invocations.sh" ] && { ROOT="$d"; break; }
  d="$(dirname "$d")"
done
[ -n "$ROOT" ] || { echo "FIXTURE ERROR: no scripts/validate-fixture-inprocess.sh walking up from $HERE" >&2; exit 2; }
VREL=scripts/validate-fixture-inprocess.sh; JREL=scripts/validate-fixture-invocations.sh; HREL=scripts/validate-fixture-hygiene.sh
for p in "$VREL" "$JREL" "$HREL" core/fixtures/lib/mutant.sh; do [ -f "$ROOT/$p" ] || { echo "FIXTURE BROKEN: $p is absent under $ROOT" >&2; exit 2; }; done

WORK="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd -P)"
trap 'rm -rf "$WORK"' EXIT
FAILS=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; FAILS=$((FAILS + 1)); }
. "$ROOT/core/fixtures/lib/mutant.sh"

# --- the worlds -----------------------------------------------------------------------------------------------------
mkf() { # <world> <fixture> <invocations rows |-joined> <cells rows |-joined, or ->
  local f="$1/core/fixtures/$2"
  mkdir -p "$f" && printf ':\n' > "$f/run.sh" || return 1
  printf '!core/scripts/g.sh\n!core/scripts/d.sh\n' > "$f/inputs.decl"
  printf '%s\n' "$3" | tr '|' '\n' > "$f/invocations.decl"
  [ "$4" = - ] || printf '%s\n' "$4" | tr '|' '\n' > "$f/cells.decl"
}
mk_world() { # <dir> <dirty|clean|listed>
  local w="$1"
  # The judge's --b2-census runs its self-probe, which drives the real core/fixtures/lib/mutant.sh beside it.
  mkdir -p "$w/scripts" "$w/core/scripts" "$w/core/fixtures/lib" && : > "$w/VERSION" && cp -p "$ROOT/$VREL" "$ROOT/$JREL" "$ROOT/$HREL" "$w/scripts/" \
    && cp -p "$ROOT/core/fixtures/lib/mutant.sh" "$w/core/fixtures/lib/" || return 1
  cmp -s "$ROOT/$VREL" "$w/$VREL" && cmp -s "$ROOT/$JREL" "$w/$JREL" || return 1
  printf '#!/usr/bin/env bash\n[ "${BASH_SOURCE[0]}" = "$0" ] || return 0\n:\n' > "$w/core/scripts/g.sh"
  if [ "$2" = dirty ]; then printf '#!/usr/bin/env bash\necho "[ \\"${BASH_SOURCE[0]}\\" = \\"$0\\" ] || return 0"\n' > "$w/core/scripts/d.sh"
  else printf '#!/usr/bin/env bash\nif [ "${BASH_SOURCE[0]}" = "$0" ]; then\n  :\nfi\n' > "$w/core/scripts/d.sh"; fi
  mkf "$w" fok '2 *|1 core/scripts/g.sh|0 core/scripts/d.sh' 'cli core/scripts/g.sh a' || return 1
  mkf "$w" fzero '1 *|0 core/scripts/g.sh|0 core/scripts/d.sh' - || return 1
  mkf "$w" fguard '2 *|0 core/scripts/g.sh|1 core/scripts/d.sh' 'cli core/scripts/d.sh a' || return 1
  if [ "$2" = dirty ]; then
    mkf "$w" fnew '2 *|1 core/scripts/g.sh|0 core/scripts/d.sh' - || return 1
    mkf "$w" fwhy '2 *|1 core/scripts/g.sh|0 core/scripts/d.sh' 'e2e core/scripts/g.sh a why=' || return 1
  else
    mkf "$w" fnew '2 *|1 core/scripts/g.sh|0 core/scripts/d.sh' 'cli core/scripts/g.sh a' || return 1
    mkf "$w" fwhy '2 *|1 core/scripts/g.sh|0 core/scripts/d.sh' 'e2e core/scripts/g.sh a why=the wiring' || return 1
  fi
  [ "$2" = listed ] && printf '# probe\nfok\tseeded\n' > "$w/scripts/fixture-inprocess-allowlist.txt"
  return 0
}
mk_world "$WORK/w-dirty" dirty && mk_world "$WORK/w-clean" clean && mk_world "$WORK/w-listed" listed \
  || { echo "FIXTURE BROKEN: could not build the probe worlds byte-identical" >&2; exit 2; }

# mk_mutant <name> <world> <file rel> <old> <new>: the world copied whole, one file changed exactly once.
mk_mutant() {
  local m="$WORK/mut-$1"
  cp -R "$WORK/w-$2" "$m" || return 1
  OLD="$4" NEW="$5" awk '{ i = index($0, ENVIRON["OLD"]); if (i > 0) { $0 = substr($0, 1, i - 1) ENVIRON["NEW"] substr($0, i + length(ENVIRON["OLD"])); n++ } print }
    END { if (n != 1) exit 3 }' "$WORK/w-$2/$3" > "$m/$3.new" || return 1
  mv "$m/$3.new" "$m/$3" || return 1
  cmp -s "$WORK/w-$2/$3" "$m/$3" && return 1
  [ -f "$m/$JREL" ] && [ -f "$m/$HREL" ] || return 1
}
mk_mutant MR dirty "$VREL" 'END { for (f in X) if (!(f in L)) print "R " f ": " X[f]' 'END { for (f in X) if (0) print "R " f ": " X[f]' \
  || { echo "FIXTURE BROKEN: mutant MR DID NOT APPLY (the R row moved in $VREL)" >&2; exit 2; }
mk_mutant MC5 dirty "$JREL" 'l == a || l == b { g = 1 }' '{ g = 1 }' \
  || { echo "FIXTURE BROKEN: mutant MC5 DID NOT APPLY (fxc_guarded's statement test moved in $JREL)" >&2; exit 2; }
mk_mutant MN clean "$VREL" 'if [ "$sc" != "$(cat "$o.listed")" ]; then echo "REFUSED N:' 'if false; then echo "REFUSED N:' \
  || { echo "FIXTURE BROKEN: mutant MN DID NOT APPLY (the scanned==listed refusal moved in $VREL)" >&2; exit 2; }
mk_mutant MK listed "$VREL" 'elif [ "$nal" -gt 0 ]; then' 'elif false; then' \
  || { echo "FIXTURE BROKEN: mutant MK DID NOT APPLY (--complete's remaining-rows branch moved in $VREL)" >&2; exit 2; }
mk_mutant MKC clean "$VREL" 'elif [ "$nal" -gt 0 ]; then' 'elif false; then' \
  || { echo "FIXTURE BROKEN: mutant MK's clean twin DID NOT APPLY" >&2; exit 2; }
mk_mutant MNP dirty "$VREL" 'if (substr(p, 1, 14) == "core/fixtures/") print "NP "' 'if (0) print "NP "' \
  || { echo "FIXTURE BROKEN: mutant MNP DID NOT APPLY (the NP row moved in $VREL)" >&2; exit 2; }

# --- THE #inproc DIGEST ROW (arms DG, DS), read through each hook's READSET_VS span ----------------------------------
# dg.sh <hooks dir> <seed root>: for each of the two hooks, the span is extracted and sourced exactly as
# core/scripts/hermetic-run.sh does it (the sed span, then the `^readset_vs_store() ` guard, then `.` in a subshell, no
# new bash), and readset_vs_input is driven over a LISTED fixture with a cells.decl and an UNLISTED one with none.
# Prints `DS ok <hook>` when the span extracts with readset_vs_store and readset_vs_input defined (DG's twin, which a
# mutant of the call site leaves standing), and `DG ok <hook>` when both digest inputs carry their exact `#inproc` row.
cat > "$WORK/dg.sh" <<'DG'
#!/usr/bin/env bash
set -u
H="$1"; S="$2"
sha="$(shasum -a 256 < "$S/core/fixtures/vl/cells.decl" | cut -d' ' -f1)"
: > "$S/rows"
for h in .githooks/pre-push core/git-hooks/pre-push; do
  sed -n '/^# READSET_VS_BEGIN$/,/^# READSET_VS_END$/p' "$H/$h" > "$S/vs.$$.sh"
  grep -q '^readset_vs_store() ' "$S/vs.$$.sh" || { echo "DS BAD $h no span"; continue; }
  ( . "$S/vs.$$.sh"; type readset_vs_input > /dev/null 2>&1 && type readset_vs_inproc > /dev/null 2>&1 ) && echo "DS ok $h" || echo "DS BAD $h"
  gl="$( . "$S/vs.$$.sh" && readset_vs_input vl "a b" "$S/rows" "$S" | grep '^#inproc ')"
  gu="$( . "$S/vs.$$.sh" && readset_vs_input vu "a b" "$S/rows" "$S" | grep '^#inproc ')"
  if [ "$gl" = "#inproc listed $sha" ] && [ "$gu" = "#inproc unlisted none" ]; then echo "DG ok $h"; else echo "DG BAD $h [$gl] [$gu]"; fi
done
DG
DGS="$WORK/dg-seed"; mkdir -p "$DGS/scripts" "$DGS/core/fixtures/vl" "$DGS/core/fixtures/vu" \
  && printf 'cli core/scripts/g.sh a\n' > "$DGS/core/fixtures/vl/cells.decl" \
  && printf '# probe\nvl\tseeded\n' > "$DGS/scripts/fixture-inprocess-allowlist.txt" \
  || { echo "FIXTURE BROKEN: could not seed the digest-row world" >&2; exit 2; }
DGH="$WORK/dg-hooks"; DGM="$WORK/dg-mut"
for h in .githooks/pre-push core/git-hooks/pre-push; do
  mkdir -p "$DGH/${h%/*}" "$DGM/${h%/*}" && cp -p "$ROOT/$h" "$DGH/$h" && cmp -s "$ROOT/$h" "$DGH/$h" \
    || { echo "FIXTURE BROKEN: could not copy $h byte-identical" >&2; exit 2; }
  OLD='  readset_vs_inproc "$1" "${4:-.}"' awk '$0 == ENVIRON["OLD"] { $0 = "  :"; n++ } { print } END { if (n != 1) exit 3 }' "$DGH/$h" > "$DGM/$h" \
    && ! cmp -s "$DGH/$h" "$DGM/$h" || { echo "FIXTURE BROKEN: mutant MDG DID NOT APPLY to $h (the readset_vs_inproc call moved)" >&2; exit 2; }
done

# --- one drive per cell ---------------------------------------------------------------------------------------------
# drive <tag> <world dir> [mode]: the validator once, its start tagged with the cell <tag> (cells.decl).
drive() {
  ( cd "$2" && unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE && FXCELL="$1" bash "$2/$VREL" ${3:+"$3"} ) > "$WORK/c.$1.out" 2> "$WORK/c.$1.err"
  echo $? > "$WORK/c.$1.rc"
}
has()  { grep -qF -- "$2" "$WORK/c.$1.out" "$WORK/c.$1.err"; }
rcis() { [ "$(cat "$WORK/c.$1.rc" 2>/dev/null)" = "$2" ]; }
rows() { awk -F'\t' '$0 !~ /^[[:space:]]*(#|$)/ { print $1 }' "$1" 2>/dev/null | tr '\n' ' '; }
verdict() { # <arm> <tag> [<world dir> for DV]
  local t="$2"
  case "$1" in
    DR) rcis "$t" 1 && has "$t" '  FAIL  R fnew: core/scripts/g.sh declares 1 start(s) against 0 cell(s)' ;;
    D4) rcis "$t" 1 && has "$t" '  FAIL  C4 fwhy:1: an empty why= on an e2e row' ;;
    D5) rcis "$t" 1 && has "$t" '  FAIL  C5 fguard:1: cli subject core/scripts/d.sh carries no column-0 BASH_SOURCE source guard statement' ;;
    DQ) rcis "$t" 1 && has "$t" '5 fixture(s) scanned' && ! grep -qE 'FAIL  [A-Z0-9]+ (fok|fzero)[:]' "$WORK/c.$t.out" ;;
    C)  rcis "$t" 0 && has "$t" 'OK: validate-fixture-inprocess -- self-probe fired both ways; 5 fixture(s) scanned' ;;
    N)  rcis "$t" 0 && has "$t" 'judges GRAMMAR only' && has "$t" '; 5 fixture(s) scanned; 5 predicted to pass, 0 refused' ;;
    DV) rcis "$t" 0 && has "$t" '--derive wrote 3 row(s)' && [ "$(rows "$3/scripts/fixture-inprocess-allowlist.txt")" = "fguard fnew fwhy " ] \
          && cmp -s "$3/scripts/fixture-inprocess-allowlist.txt" "$3.first" ;;
    K)  rcis "$t" 1 && has "$t" '  INCOMPLETE  1 allowlist row(s) remain in scripts/fixture-inprocess-allowlist.txt' ;;
    DG) [ "$(grep -c '^DG ok ' "$WORK/c.$t.out")" = 2 ] && ! grep -q '^DG BAD' "$WORK/c.$t.out" ;;
    DS) [ "$(grep -c '^DS ok ' "$WORK/c.$t.out")" = 2 ] && ! grep -q '^DS BAD' "$WORK/c.$t.out" ;;
    *) return 1 ;;
  esac
}
# dv <tag> <world>: --derive twice into a copy of the world, keeping the first output for the byte comparison.
dv() {
  local c="$WORK/dv-$1"
  cp -R "$2" "$c" || return 1
  drive "$1.first" "$c" --derive; cp "$c/scripts/fixture-inprocess-allowlist.txt" "$c.first" 2>/dev/null || : > "$c.first"
  drive "$1" "$c" --derive
}
REFUSAL='validate-fixture-inprocess: REFUSED -- the self-probe is red'

if [ "$MODE" = matrix ]; then
  : > "$WORK/mx.ran"
  for m in MR MC5 MN MK MNP; do
    drive "$m.dirty" "$WORK/mut-$m" & drive "$m.clean" "$WORK/mut-$m" & drive "$m.k" "$WORK/mut-$m" --complete &
  done; wait
  for m in MR MC5 MN MK MNP; do
    printf 'MATRIX %s dirty-rc=%s clean-rc=%s complete-rc=%s refused=%s\n' "$m" "$(cat "$WORK/c.$m.dirty.rc")" "$(cat "$WORK/c.$m.clean.rc")" \
      "$(cat "$WORK/c.$m.k.rc")" "$(grep -qF "$REFUSAL" "$WORK/c.$m.dirty.err" && echo yes || echo no)"
  done
  bash "$WORK/dg.sh" "$DGM" "$DGS" > "$WORK/c.MDG.out" 2>&1
  printf 'MATRIX MDG decides=%s twins=%s\n' "$(verdict DG MDG && echo - || echo DG)" "$(verdict DS MDG && echo DS || echo -)"
fi
[ "$MODE" = matrix ] && exit 0

# --- the unmutated arms ---------------------------------------------------------------------------------------------
drive dirty "$WORK/w-dirty" & drive clean "$WORK/w-clean" & drive k "$WORK/w-listed" --complete &
dv derive "$WORK/w-dirty" &
bash "$WORK/dg.sh" "$DGH" "$DGS" > "$WORK/c.dg.out" 2>&1 &
wait
B_DR=0; B_D5=0; B_N=0; B_C=0; B_K=0
dfail() { bad "$1 fails on the dirty world (rc $(cat "$WORK/c.dirty.rc")): $(head -c 600 "$WORK/c.dirty.out" | tr '\n' ' ')"; }
cfail() { bad "$1 fails on the clean world (rc $(cat "$WORK/c.clean.rc")): $(head -c 600 "$WORK/c.clean.out" | tr '\n' ' ') $(head -c 300 "$WORK/c.clean.err")"; }
if verdict DR dirty; then ok "DR holds on the dirty world"; B_DR=1; else dfail DR; fi
if verdict D4 dirty; then ok "D4 holds on the dirty world"; else dfail D4; fi
if verdict D5 dirty; then ok "D5 holds on the dirty world"; B_D5=1; else dfail D5; fi
if verdict DQ dirty; then ok "DQ holds on the dirty world"; else dfail DQ; fi
if verdict C clean; then ok "C holds on the clean world"; B_C=1; else cfail C; fi
if verdict N clean; then ok "N holds on the clean world"; B_N=1; else cfail N; fi
if verdict DV derive "$WORK/dv-derive"; then ok "DV --derive writes exactly the three refused fixtures, byte-identical twice"; else bad "DV: $(tr '\n' ' ' < "$WORK/c.derive.out") rows [$(rows "$WORK/dv-derive/scripts/fixture-inprocess-allowlist.txt")]"; fi
if verdict K k; then ok "K --complete refuses a non-empty allowlist"; B_K=1; else bad "K (rc $(cat "$WORK/c.k.rc")): $(head -c 400 "$WORK/c.k.out" | tr '\n' ' ')"; fi
B_DG=0; B_DS=0
if verdict DG dg; then ok "DG both hooks' digest inputs carry the fixture's own #inproc row (listed with its cells.decl sha, unlisted none)"; B_DG=1; else bad "DG: $(tr '\n' ' ' < "$WORK/c.dg.out")"; fi
if verdict DS dg; then ok "DS both hooks' READSET_VS span extracts with readset_vs_store, readset_vs_input and readset_vs_inproc"; B_DS=1; else bad "DS: $(tr '\n' ' ' < "$WORK/c.dg.out")"; fi
if [ "$B_DR" = 1 ] && [ "$B_C" = 1 ]; then
  echo "HERMETIC-CONSUMED $VREL"
  echo "HERMETIC-CONSUMED $JREL"
  echo "HERMETIC-CONSUMED $HREL"
fi
if [ "$B_DG" = 1 ]; then
  echo "HERMETIC-CONSUMED .githooks/pre-push"
  echo "HERMETIC-CONSUMED core/git-hooks/pre-push"
fi

# --- the mutants, each on its deciding arm ----------------------------------------------------------------------------
drive MR "$WORK/mut-MR" & drive MC5 "$WORK/mut-MC5" & drive MN "$WORK/mut-MN" & drive MK "$WORK/mut-MK" --complete &
drive MKC "$WORK/mut-MKC" & drive MNP "$WORK/mut-MNP" &
bash "$WORK/dg.sh" "$DGM" "$DGS" > "$WORK/c.MDG.out" 2>&1 &
wait
refused() { rcis "$1" 2 && grep -qF "$REFUSAL" "$WORK/c.$1.err"; }
why() { printf '(rc %s) %s %s' "$(cat "$WORK/c.$1.rc")" "$(grep -v '^  ok' "$WORK/c.$1.out" | head -c 400 | tr '\n' ' ')" "$(head -c 200 "$WORK/c.$1.err" | tr '\n' ' ')"; }
if verdict DR MR; then bad "MR SURVIVED: DR still holds"; elif refused MR && has MR 'FAIL  self-probe the probe verdict (rc 1) was:'; then mutant_killed "${B_DR:-0}" MR "MR: arm DR fails by the self-probe refusal"; else bad "MR: DR fails but not by the self-probe refusal $(why MR)"; fi
if verdict D5 MC5; then bad "MC5 SURVIVED: D5 still holds"; elif refused MC5 && has MC5 'FAIL  self-probe the probe tree could not be joined (rc 2)'; then mutant_killed "${B_D5:-0}" MC5 "MC5: arm D5 fails by the self-probe refusal"; else bad "MC5: D5 fails but not by the self-probe refusal $(why MC5)"; fi
if verdict N MN; then bad "MN SURVIVED: N still holds"; elif refused MN && has MN 'FAIL  self-probe N: rc'; then mutant_killed "${B_N:-0}" MN "MN: arm N fails by the self-probe refusal naming N"; else bad "MN: N fails but not by the self-probe refusal naming N"; fi
if verdict K MK; then bad "MK SURVIVED: K still holds"
elif rcis MK 0 && verdict C MKC; then mutant_killed "$(( ${B_K:-0} && ${B_C:-0} ))" MK "MK: arm K reads rc 0 on a non-empty allowlist; twin C holds"
else bad "MK: K fails but not for its reason (rc $(cat "$WORK/c.MK.rc")), or twin C fails too"; fi
if verdict DR MNP; then bad "MNP SURVIVED: DR still holds"; elif refused MNP && has MNP 'FAIL  self-probe the probe verdict (rc 1) was:'; then mutant_killed "${B_DR:-0}" MNP "MNP: arm DR fails by the self-probe refusal (the NP row of anp is missing)"; else bad "MNP: DR fails but not by the self-probe refusal $(why MNP)"; fi
if verdict DG MDG; then bad "MDG SURVIVED: DG still holds with readset_vs_inproc's call replaced by : in both hooks"
elif grep -qF 'DG BAD .githooks/pre-push [] []' "$WORK/c.MDG.out" && grep -qF 'DG BAD core/git-hooks/pre-push [] []' "$WORK/c.MDG.out" && verdict DS MDG; then
  mutant_killed "$(( ${B_DG:-0} && ${B_DS:-0} ))" MDG "MDG: arm DG reads no #inproc row in either hook; twin DS holds"
else bad "MDG: DG fails but not for its reason, or twin DS fails too: $(tr '\n' ' ' < "$WORK/c.MDG.out")"; fi

if [ ! -e "$WORK/mx.ran" ] && [ -e "$WORK/c.MR.out" ] && [ -e "$WORK/c.MK.out" ]; then ok "NM a plain run executes no matrix-only cell, and the per-push mutant drives ran"
else bad "NM a plain run reached the matrix, or its per-push mutant drives did not run"; fi

[ "$FAILS" = 0 ] || { echo "fixture-inprocess: $FAILS FAILED"; exit 1; }
echo "fixture-inprocess: PASS"
exit 0
