#!/usr/bin/env bash
# fixture-inprocess -- drive the REAL scripts/validate-fixture-inprocess.sh (BL-879's static half) against seeded probe
# projects.
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
#   K   listed, --complete   rc 1, `INCOMPLETE  1 allowlist row(s) remain`
#   DG  both pre-push hooks: the READSET_VS span, extracted and sourced the way core/scripts/hermetic-run.sh does it,
#       gives a listed fixture's digest input `#inproc listed <its cells.decl sha256>` and an unlisted one's
#       `#inproc unlisted none` (dg.sh, no bash start beyond its own)
#   DS  the same span extracts with readset_vs_store, readset_vs_input and readset_vs_inproc defined
# The dirty world's anp-shaped NP finding is held by the validator's own self-probe (anp FIRES, anpq QUIET).
#
# THE IN-PROCESS CELLS of this fixture are its own cells.decl: every validator start is one e2e cell, tagged at its
# start, and the judge starts the validator makes are covered by one nested row.
#
# Usage: run.sh     Exit: 0 pass, 1 FAIL, 2 FIXTURE BROKEN.
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "fixture-inprocess: FIXTURE BROKEN: core/fixtures/lib/preamble.sh is absent" >&2; exit 2; }
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
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
# shellcheck source=/dev/null
. "$HERE/../lib/report.sh" || { echo "FIXTURE ERROR: lib/report.sh not found" >&2; exit 2; }

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

# --- THE #inproc DIGEST ROW (arms DG, DS), read through each hook's READSET_VS span ----------------------------------
# dg.sh <hooks dir> <seed root>: for each of the two hooks, the span is extracted and sourced exactly as
# core/scripts/hermetic-run.sh does it (the sed span, then the `^readset_vs_store() ` guard, then `.` in a subshell, no
# new bash), and readset_vs_input is driven over a LISTED fixture with a cells.decl and an UNLISTED one with none.
# Prints `DS ok <hook>` when the span extracts with readset_vs_store and readset_vs_input defined,
# and `DG ok <hook>` when both digest inputs carry their exact `#inproc` row.
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
DGH="$WORK/dg-hooks"
for h in .githooks/pre-push core/git-hooks/pre-push; do
  mkdir -p "$DGH/${h%/*}" && cp -p "$ROOT/$h" "$DGH/$h" && cmp -s "$ROOT/$h" "$DGH/$h" \
    || { echo "FIXTURE BROKEN: could not copy $h byte-identical" >&2; exit 2; }
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
          && cmp -s "$3/scripts/fixture-inprocess-allowlist.txt" "$3.first" \
          && [ "$(awk -F'\t' '$1 == "fnew" { print $2 }' "$3/scripts/fixture-inprocess-allowlist.txt")" = "core/scripts/g.sh runs outside a declared cell" ] ;;
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

# --- the unmutated arms ---------------------------------------------------------------------------------------------
drive dirty "$WORK/w-dirty" & drive clean "$WORK/w-clean" & drive k "$WORK/w-listed" --complete &
dv derive "$WORK/w-dirty" &
bash "$WORK/dg.sh" "$DGH" "$DGS" > "$WORK/c.dg.out" 2>&1 &
wait
B_DR=0; B_C=0
dfail() { bad "$1 fails on the dirty world (rc $(cat "$WORK/c.dirty.rc")): $(head -c 600 "$WORK/c.dirty.out" | tr '\n' ' ')"; }
cfail() { bad "$1 fails on the clean world (rc $(cat "$WORK/c.clean.rc")): $(head -c 600 "$WORK/c.clean.out" | tr '\n' ' ') $(head -c 300 "$WORK/c.clean.err")"; }
if verdict DR dirty; then ok "DR holds on the dirty world"; B_DR=1; else dfail DR; fi
if verdict D4 dirty; then ok "D4 holds on the dirty world"; else dfail D4; fi
if verdict D5 dirty; then ok "D5 holds on the dirty world"; else dfail D5; fi
if verdict DQ dirty; then ok "DQ holds on the dirty world"; else dfail DQ; fi
if verdict C clean; then ok "C holds on the clean world"; B_C=1; else cfail C; fi
if verdict N clean; then ok "N holds on the clean world"; else cfail N; fi
if verdict DV derive "$WORK/dv-derive"; then
  ok "DV --derive writes exactly the three refused fixtures, byte-identical twice, each reason count-free"; echo "receipt-bl928: PASS"
else echo "receipt-bl928: FAIL";  bad "DV: $(tr '\n' ' ' < "$WORK/c.derive.out") rows [$(rows "$WORK/dv-derive/scripts/fixture-inprocess-allowlist.txt")]"; fi
if verdict K k; then ok "K --complete refuses a non-empty allowlist"; else bad "K (rc $(cat "$WORK/c.k.rc")): $(head -c 400 "$WORK/c.k.out" | tr '\n' ' ')"; fi
B_DG=0
if verdict DG dg; then ok "DG both hooks' digest inputs carry the fixture's own #inproc row (listed with its cells.decl sha, unlisted none)"; B_DG=1; else bad "DG: $(tr '\n' ' ' < "$WORK/c.dg.out")"; fi
if verdict DS dg; then ok "DS both hooks' READSET_VS span extracts with readset_vs_store, readset_vs_input and readset_vs_inproc"; else bad "DS: $(tr '\n' ' ' < "$WORK/c.dg.out")"; fi
if [ "$B_DR" = 1 ] && [ "$B_C" = 1 ]; then
  echo "HERMETIC-CONSUMED $VREL"
  echo "HERMETIC-CONSUMED $JREL"
  echo "HERMETIC-CONSUMED $HREL"
fi
if [ "$B_DG" = 1 ]; then
  echo "HERMETIC-CONSUMED .githooks/pre-push"
  echo "HERMETIC-CONSUMED core/git-hooks/pre-push"
fi

report_end fixture-inprocess
