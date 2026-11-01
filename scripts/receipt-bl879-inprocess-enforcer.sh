#!/usr/bin/env bash
# Receipt: BL-879's in-process enforcer fails the push on a fixture that runs a subject as a separate program outside a
# declared cell, and passes the same fixture once its starts are declared and tagged.
# Usage: receipt-bl879-inprocess-enforcer.sh [<root>]      (<root> = a tree carrying scripts/; default: this script's repo)
# Copies the three SHIPPING programs of <root> -- scripts/validate-fixture-inprocess.sh, scripts/validate-fixture-invocations.sh and
# scripts/validate-fixture-hygiene.sh -- into a mktemp tree and DRIVES them; it reads no document they produced. Each arm is
# one run of a shipping program against a seeded tree, compared with the verdict it must give:
#   (a) the judge (validate-fixture-invocations.sh --fixture ... --log ...), the dynamic arms, on one synthetic start log each:
#       a start tagged with its declared cli cell -> rc 0 (the fix)
#       the same cells.decl with its rows reordered, the tagged start unchanged -> rc 0 (second spelling)
#       a child start covered by a `nested` row in place of a tag -> rc 0 (second spelling)
#       an untagged start (C1) -> rc 1 naming C1
#       a start tagged with an id no cells.decl row declares (C2) -> rc 1 naming C2
#       two starts tagged with one cell id (C3) -> rc 1 naming C3
#   (b) the static gate (validate-fixture-inprocess.sh --root ...) on one seeded tree:
#       a fixture whose subject row is 2 and whose one cell is declared and guarded -> quiet for it (the fix)
#       the same cells.decl rows reordered, with an `e2e` row spelled in place of a second `cli` row -> quiet (second spelling)
#       a fixture starting a subject with no cells.decl -> rc 1 naming it (R)
#       a `cli` subject with no column-0 BASH_SOURCE guard -> rc 1 naming C5
#       an `e2e` row with an empty why= -> rc 1 naming C4
#   (c) <root>/.githooks/pre-push: the static step `bash scripts/validate-fixture-inprocess.sh` is a non-comment line after
#       its one `PRESUITE_DONE=1` line (deleted, or moved before it, reads 1)
#   (d) each pre-push hook's READSET_VS span, sourced as hermetic-run.sh sources it: a fixture's store-digest input
#       carries its own `#inproc` row (listed with its cells.decl sha; unlisted with none)
# 0 = every arm gave the verdict it must (the defect is fixed). 1 = an arm gave another verdict (each prints a FAIL line).
# 9 = no verdict: no shipping program under <root>, or the scratch tree could not be built.
set -uo pipefail
r879_seam() { # walk up from $1 for the git-env seam; never count hops
  local d="$1"
  while [ -n "$d" ] && [ "$d" != "/" ] && [ "$d" != "." ]; do
    if [ -f "$d/core/fixtures/lib/preamble.sh" ]; then printf '%s\n' "$d/core/fixtures/lib/preamble.sh"; return 0; fi
    d="$(dirname "$d")"
  done
  return 1
}
_PRE="$(r879_seam "$(cd "$(dirname "$0")" && pwd)")" || _PRE=""
[ -n "$_PRE" ] && [ -f "$_PRE" ] || { echo "REFUSED: no git-env seam core/fixtures/lib/preamble.sh above $0" >&2; exit 9; }
. "$_PRE"
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
ROOT="$(cd "$ROOT" 2>/dev/null && pwd -P)" || { echo "REFUSED: no root" >&2; exit 9; }
for s in validate-fixture-inprocess validate-fixture-invocations validate-fixture-hygiene; do
  [ -f "$ROOT/scripts/$s.sh" ] || { echo "REFUSED: no scripts/$s.sh under $ROOT" >&2; exit 9; }
done
T="$(mktemp -d "${TMPDIR:-/tmp}/bl879.XXXXXX")" || exit 9
[ -d "$T" ] || exit 9
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/scripts" "$T/core/scripts" "$T/core/fixtures" || exit 9
for s in validate-fixture-inprocess validate-fixture-invocations validate-fixture-hygiene; do cp "$ROOT/scripts/$s.sh" "$T/scripts/$s.sh" || exit 9; done
printf '0.0.0\n' > "$T/VERSION"
# the judge's own self-probe drives the real counter rc and reads core/fixtures/lib/mutant.sh beside the scripts
[ -d "$ROOT/core/fixtures/lib" ] || { echo "REFUSED: no core/fixtures/lib under $ROOT" >&2; exit 9; }
cp -R "$ROOT/core/fixtures/lib" "$T/core/fixtures/lib" || exit 9
rc=0
fail() { echo "FAIL: $1"; rc=1; }
TAB="$(printf '\t')"

# subjects: g.sh carries the guard, u.sh does not, kid.sh is a child.
printf '#!/usr/bin/env bash\nm() { :; }\n[ "${BASH_SOURCE[0]}" = "$0" ] || return 0\nm\n' > "$T/core/scripts/g.sh"
printf '#!/usr/bin/env bash\n:\n' > "$T/core/scripts/u.sh"
printf ':\n' > "$T/core/scripts/kid.sh"
G="$T/core/scripts/g.sh"; K="$T/core/scripts/kid.sh"; R0="$T/x/run.sh${TAB}100${TAB}${TAB}"

# fx <dir> <star> <g count> <kid count> <cells.decl body (rows |-joined) or ->
fx() {
  local d="$T/core/fixtures/$1"; mkdir -p "$d"; printf ':\n' > "$d/run.sh"
  printf '!core/scripts/g.sh\n!core/scripts/u.sh\n!core/scripts/kid.sh\n' > "$d/inputs.decl"
  printf '%s *\n%s core/scripts/g.sh\n0 core/scripts/u.sh\n%s core/scripts/kid.sh\n' "$2" "$3" "$4" > "$d/invocations.decl"
  rm -f "$d/cells.decl"; [ "$5" = - ] || printf '%s\n' "$5" | tr '|' '\n' > "$d/cells.decl"
}
# judge <name> <want rc> <want substring or -> <log rows...>  (the fixture dir is core/fixtures/<name>, already seeded)
judge() {
  local n="$1" want="$2" sub="$3" out got; shift 3
  printf '%s\n' "$@" > "$T/log.$n"
  out="$(bash "$T/scripts/validate-fixture-invocations.sh" --fixture "$n" --decl "$T/core/fixtures/$n/invocations.decl" --log "$T/log.$n" --root "$T" 2>&1)"; got=$?
  if [ "$got" != "$want" ]; then fail "judge $n: rc $got, want $want: $(printf '%s' "$out" | head -2 | tr '\n' ' ')"; return; fi
  if [ "$sub" != - ] && ! grep -qF -- "$sub" <<<"$out"; then fail "judge $n: output lacks '$sub'"; fi
}
fx jok 2 1 0 'cli core/scripts/g.sh a'
judge jok 0 - "$R0" "$G${TAB}101${TAB}a${TAB}100"
fx jre 3 2 0 'cli core/scripts/g.sh b|cli core/scripts/g.sh a'
judge jre 0 - "$R0" "$G${TAB}101${TAB}a${TAB}100" "$G${TAB}102${TAB}b${TAB}100"
fx jne 3 1 1 'cli core/scripts/g.sh a|nested core/scripts/g.sh core/scripts/kid.sh why=the subject runs its child'
judge jne 0 - "$R0" "$G${TAB}101${TAB}a${TAB}100" "$K${TAB}102${TAB}${TAB}101"
fx jc1 2 1 0 'cli core/scripts/g.sh a'
judge jc1 1 'C1' "$R0" "$G${TAB}101${TAB}${TAB}100"
fx jc2 2 1 0 'cli core/scripts/g.sh a'
judge jc2 1 'C2' "$R0" "$G${TAB}101${TAB}zzz${TAB}100"
fx jc3 3 2 0 'cli core/scripts/g.sh a'
judge jc3 1 'C3' "$R0" "$G${TAB}101${TAB}a${TAB}100" "$G${TAB}102${TAB}a${TAB}100"

# static gate: the fix tree, then one offender at a time on a copy of it.
S="$T/s"; mkdir -p "$S/core/scripts" "$S/core/fixtures" "$S/scripts"
cp "$T/core/scripts/"*.sh "$S/core/scripts/"; printf '0.0.0\n' > "$S/VERSION"
sfx() { # same as fx but under $S
  local d="$S/core/fixtures/$1"; mkdir -p "$d"; printf ':\n' > "$d/run.sh"
  printf '!core/scripts/g.sh\n!core/scripts/u.sh\n!core/scripts/kid.sh\n' > "$d/inputs.decl"
  printf '%s *\n%s core/scripts/g.sh\n%s core/scripts/u.sh\n0 core/scripts/kid.sh\n' "$2" "$3" "$4" > "$d/invocations.decl"
  rm -f "$d/cells.decl"; [ "$5" = - ] || printf '%s\n' "$5" | tr '|' '\n' > "$d/cells.decl"
}
sfx sok 3 2 0 'cli core/scripts/g.sh a|cli core/scripts/g.sh b'
sfx sre 3 2 0 'cli core/scripts/g.sh b|cli core/scripts/g.sh a'
sfx se2 3 2 0 'e2e core/scripts/g.sh b why=the wiring|cli core/scripts/g.sh a'
gate() { # <label> <want rc> <must-contain or -> <must-not-contain or ->
  local out got
  out="$(bash "$T/scripts/validate-fixture-inprocess.sh" --root "$S" 2>&1)"; got=$?
  if [ "$got" != "$2" ]; then fail "gate $1: rc $got, want $2: $(printf '%s' "$out" | head -3 | tr '\n' ' ')"; return; fi
  if [ "$3" != - ] && ! grep -qF -- "$3" <<<"$out"; then fail "gate $1: output lacks '$3'"; fi
  if [ "$4" != - ] && grep -qF -- "$4" <<<"$out"; then fail "gate $1: output carries '$4'"; fi
}
gate fix 0 - -
sfx snew 2 1 0 -
gate no-cells 1 'R snew' 'sok'
rm -rf "$S/core/fixtures/snew"
sfx su5 2 0 1 'cli core/scripts/u.sh a'
gate unguarded 1 'C5 su5' 'sok'
rm -rf "$S/core/fixtures/su5"
sfx swhy 3 2 0 'cli core/scripts/g.sh a|e2e core/scripts/g.sh b why= '
gate empty-why 1 'C4 swhy' 'sok'
rm -rf "$S/core/fixtures/swhy"


# (c) THE PRE-PUSH STEP, keyed on its emission site in <root>/.githooks/pre-push: exactly one `PRESUITE_DONE=1` line,
#     and after it a non-comment line on which `bash scripts/validate-fixture-inprocess.sh` is a command word (at
#     the line start, or after a blank, so a one-line `step "..." bash scripts/...` spelling counts too). The step's
#     quoted label names the same path after `(`, never after `bash `, so a path grep alone would be satisfied by the
#     label with the command deleted; this arm reads the `bash` word.
HOOK="$ROOT/.githooks/pre-push"
[ -f "$HOOK" ] || { echo "REFUSED: no .githooks/pre-push under $ROOT" >&2; exit 9; }
nd="$(grep -c '^PRESUITE_DONE=1$' "$HOOK")" || nd=0
if [ "$nd" != 1 ]; then fail "pre-push: $nd PRESUITE_DONE=1 line(s), want exactly 1"
else
  awk '/^PRESUITE_DONE=1$/ { after = 1; next } /^[[:blank:]]*#/ { next }
    /(^|[[:blank:]])bash[[:blank:]]+scripts\/validate-fixture-inprocess\.sh([[:blank:]]|$)/ { if (after) a++; else b++ }
    END { exit (a >= 1) ? 0 : 1 }' "$HOOK" || fail "pre-push: no non-comment \`bash scripts/validate-fixture-inprocess.sh\` line after PRESUITE_DONE=1"
fi
# (d) THE #inproc DIGEST ROW, through the hook's own READSET_VS span, extracted and sourced as
#     core/scripts/hermetic-run.sh does (the sed span, then the readset_vs_store guard): readset_vs_input over a listed
#     fixture with a cells.decl carries `#inproc listed <sha256 of its cells.decl>`; over an unlisted one with none,
#     `#inproc unlisted none`.
D="$T/vs"; mkdir -p "$D/scripts" "$D/core/fixtures/vl" "$D/core/fixtures/vu" || exit 9
printf 'cli core/scripts/g.sh a\n' > "$D/core/fixtures/vl/cells.decl"
printf '# probe\nvl\tseeded\n' > "$D/scripts/fixture-inprocess-allowlist.txt"
: > "$D/rows"
for h in .githooks/pre-push core/git-hooks/pre-push; do
  [ -f "$ROOT/$h" ] || continue
  sed -n '/^# READSET_VS_BEGIN$/,/^# READSET_VS_END$/p' "$ROOT/$h" > "$T/vs.sh"
  if ! grep -q '^readset_vs_store() ' "$T/vs.sh"; then fail "$h: no READSET_VS span carrying readset_vs_store"; continue; fi
  sha="$(shasum -a 256 < "$D/core/fixtures/vl/cells.decl" | cut -d' ' -f1)"
  gl="$( . "$T/vs.sh" && readset_vs_input vl "a b" "$D/rows" "$D" | grep '^#inproc ')"
  gu="$( . "$T/vs.sh" && readset_vs_input vu "a b" "$D/rows" "$D" | grep '^#inproc ')"
  [ "$gl" = "#inproc listed $sha" ] || fail "$h: the listed fixture's digest input carries [$gl], want [#inproc listed $sha]"
  [ "$gu" = "#inproc unlisted none" ] || fail "$h: the unlisted fixture's digest input carries [$gu], want [#inproc unlisted none]"
  # second spelling: the same listed fixture over a NON-empty key-rows file carries the same row.
  printf '#tool bash x\n' > "$D/rows2"
  g2="$( . "$T/vs.sh" && readset_vs_input vl "a b" "$D/rows2" "$D" | grep '^#inproc ')"
  [ "$g2" = "#inproc listed $sha" ] || fail "$h: over non-empty key rows the listed fixture's digest input carries [$g2], want [#inproc listed $sha]"
done

[ "$rc" = 0 ] && echo "ok: every arm gave the verdict it must"
exit "$rc"
