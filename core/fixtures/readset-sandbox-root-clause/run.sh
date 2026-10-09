#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# readset-sandbox-root-clause -- BL-470, measured. Every sandbox-profile emitter in
# core/scripts/derive-fixture-readsets.sh (the AI_DLC_READSET_SANDBOX_PROFILE override, the
# `--local-map` profile and the default profile) ends with an allow clause on the tree ROOT literal
# carrying no `(with report)`. It removes the root-only file-read-metadata / file-test-existence
# reports -- every `cd` and `[ -d ]` a fixture makes on the root, which flooded the stream into drops
# -- and must keep `file-read-data` on the root (a listing, which IS a read) and every read below it.
#
# MEASURED, NOT READ OFF THE TEXT, AND FOR ALL THREE EMITTERS. Each emitter is extracted from the
# deriver's own text and rendered for its own tiny tree: the default line is eval'd, the `--local-map`
# block is sourced with the trip set stubbed, and the override branch is eval'd against an unscoped
# profile. Each rendering runs one workload under an unprivileged sandbox-exec while one `log stream`
# watches; a start sentinel opens the window and an end sentinel closes it. A text count of the clause
# is kept as a CONTROL only: a mutant moving the override and `--local-map` clauses onto `$MARKDIR`
# keeps that count at 3, and only the rendered runs see it.
#
# WHY A SEPARATE FIXTURE. Inside the sandbox tracer `log stream` answers "Cannot run while sandboxed",
# so this fixture SKIPs there by construction. Carried inside readset-stage1-verdict it made that
# fixture's traced verdict differ from its untraced one, and every trace discarded it. Here the SKIP
# costs only this small fixture.
#
# Usage: run.sh
# Exit:  0 = every arm and mutant holds (or SKIP, stated), 1 = one regressed, 2 = fixture broken.
set -u
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd -P)"
ROOT="$HERE"
while [ "$ROOT" != "/" ] && [ ! -f "$ROOT/core/scripts/derive-fixture-readsets.sh" ]; do ROOT="$(dirname "$ROOT")"; done
DERIVER="$ROOT/core/scripts/derive-fixture-readsets.sh"
[ -f "$DERIVER" ] || { echo "readset-sandbox-root-clause: FIXTURE BROKEN: no core/scripts/derive-fixture-readsets.sh above $HERE" >&2; exit 2; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/readset-sandbox-root-clause.XXXXXX")" || { echo "FIXTURE BROKEN: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd -P)"
LSP=""
reap() { [ -z "$LSP" ] || kill "$LSP" 2>/dev/null; }
trap reap EXIT

FAILS=0; ASSERTS=0
ok()     { printf '  ok    %s\n' "$1"; ASSERTS=$((ASSERTS + 1)); }
bad()    { printf '  FAIL  %s\n' "$1"; FAILS=$((FAILS + 1)); ASSERTS=$((ASSERTS + 1)); }
broken() { echo "readset-sandbox-root-clause: FIXTURE BROKEN: $*" >&2; echo "  (work kept at $WORK)" >&2; exit 2; }
echo "readset-sandbox-root-clause:"
echo "HERMETIC-CONSUMED core/scripts/derive-fixture-readsets.sh"

CLAUSE='(allow file-read-metadata file-test-existence (literal "%s"))'
cl_count() { awk -v k="$CLAUSE" '{ l = $0; sub(/^[ \t]+/, "", l) } substr(l, 1, 1) != "#" && index($0, k) { n++ } END { print n + 0 }' "$1"; }

# ------------------------------------------------------------------ mutants, as copies ----
# mk <name> <awk program>: a copy of the deriver edited by the program; the program prints the number of
# lines it changed to "$dst.count". DID NOT APPLY unless the copy differs and the count is as wanted.
MD="$WORK/mut"; mkdir -p "$MD" || broken "mkdir $MD"
mk() { # mk <name> <want-count> <awk program>
  local dst="$MD/$1.sh"
  awk -v CF="$dst.count" "$3"' { print } END { print c + 0 > CF }' "$DERIVER" > "$dst" || return 1
  [ "$(cat "$dst.count")" = "$2" ] || return 1
  if cmp -s "$DERIVER" "$dst"; then return 1; fi
  bash -n "$dst" 2>/dev/null
}
# The emitter lines, keyed on what SEPARATES them: the default line carries `> "$PROFILE" \`, the
# override line `>> "$PROFILE"`, the `--local-map` line neither and a six-space indent.
P_DEF='index($0, "> \"$PROFILE\" \\") && index($0, k)'
P_OV='index($0, ">> \"$PROFILE\"") && index($0, k)'
P_LM='index($0, "      printf \047" k) == 1'
K='BEGIN { k = "(allow file-read-metadata file-test-existence (literal \"%s\"))"; q = sprintf("%c", 39) }'
# The default line's argument list is `"$TREE" "$MARKDIR" "$TREE" > "$PROFILE"`; its clause's arg is the third.
mk markdir-default 1 "$K $P_DEF"' { if (sub(/"\$MARKDIR" "\$TREE" > "\$PROFILE"/, "\"$MARKDIR\" \"$MARKDIR\" > \"$PROFILE\"")) c++ }' \
  || broken "mutant markdir-default DID NOT APPLY"
mk markdir-ov-lm 2 "$K"' ('"$P_OV"') || ('"$P_LM"') { if (sub(/\047 "\$TREE"/, q " \"$MARKDIR\"")) c++ }' \
  || broken "mutant markdir-ov-lm DID NOT APPLY"
mk report-default 1 "$K $P_DEF"' { if (sub(/\(literal "%s"\)\)\\n\047 "\$TREE" "\$MARKDIR" "\$TREE"/, "(literal \"%s\") (with report))\\n" q " \"$TREE\" \"$MARKDIR\" \"$TREE\"")) c++ }' \
  || broken "mutant report-default DID NOT APPLY"
mk report-lm 1 "$K $P_LM"' { if (sub(/\(literal "%s"\)\)/, "(literal \"%s\") (with report))")) c++ }' \
  || broken "mutant report-lm DID NOT APPLY"

# ------------------------------------------------------------------ text control ----
echo " text control:"
n="$(cl_count "$DERIVER")"
if [ "$n" = 3 ]; then ok "the root-literal clause is on 3 uncommented emitter lines (control only; the rendered arms below decide)"; else bad "the root-literal clause is on $n uncommented emitter line(s), not 3"; fi
n="$(cl_count "$MD/markdir-ov-lm.sh")"
[ "$n" = 3 ] && ok "the markdir-ov-lm mutant keeps the text count at 3, so only a rendered run can kill it" \
  || bad "the markdir-ov-lm mutant moved the text count to $n; it no longer shows why the rendered arms exist"

# ------------------------------------------------------------------ the gate ----
LS_WHY=""
if ! command -v sandbox-exec >/dev/null 2>&1; then LS_WHY="no sandbox-exec (not macOS)"
elif [ ! -x /usr/bin/log ]; then LS_WHY="no /usr/bin/log"
elif [ "$(id -u)" = 0 ]; then LS_WHY="running as root"
else
  /usr/bin/log stream --style compact --timeout 1s --predicate 'sender == "readset-sandbox-root-clause-probe"' >/dev/null 2>"$WORK/ls.err"
  lsrc=$?
  if grep -q 'Cannot run while sandboxed' "$WORK/ls.err"; then LS_WHY="inside a sandbox: $(head -1 "$WORK/ls.err")"
  elif [ "$lsrc" != 0 ]; then LS_WHY="log stream unavailable here (rc $lsrc): $(head -1 "$WORK/ls.err")"; fi
fi
if [ -n "$LS_WHY" ]; then
  printf '  SKIP  rendered sandbox arms: %s\n' "$LS_WHY"
  echo
  if [ "$FAILS" -ne 0 ]; then echo "readset-sandbox-root-clause: $FAILS of $ASSERTS FAILED (work kept at $WORK)"; exit 1; fi
  case "$WORK" in */readset-sandbox-root-clause.??????) rm -rf "$WORK" ;; esac
  echo "readset-sandbox-root-clause: all $ASSERTS assertions hold (rendered arms SKIPPED: $LS_WHY)"
  exit 0
fi

# ------------------------------------------------------------------ rendering ----
# render3 <deriver> <dir>: writes <dir>/{def,lm,ov}.sb, each for its own tree <dir>/<e>/t.
render3() {
  local d="$1" o="$2" l ob e
  for e in def lm ov; do mkdir -p "$o/$e/t/d" "$o/$e/m" && echo x > "$o/$e/t/d/f" && echo y > "$o/$e/t/g" || return 1; done
  l="$(awk 'index($0, "printf \047(version 3)") && index($0, "> \"$PROFILE\" \\") { sub(/^[ \t]+/, ""); sub(/ > "\$PROFILE" \\$/, ""); print }' "$d")"
  [ -n "$l" ] || return 1
  ( TREE="$o/def/t"; MARKDIR="$o/def/m"; eval "$l" ) > "$o/def.sb" || return 1
  awk 'index($0, "{ printf \047(version 3)") { f = 1 } f { print } f && index($0, "} > \"$PROFILE\"") { exit }' "$d" \
    | sed 's/ || die "cannot write \$PROFILE"$//' > "$o/lm.blk"
  [ "$(grep -c . "$o/lm.blk")" -ge 3 ] || return 1
  ( TREE="$o/lm/t"; MARKDIR="$o/lm/m"; PROFILE="$o/lm.sb"; readset_trip_set() { echo /usr/bin/log; }; . "$o/lm.blk" ) || return 1
  ob="$(awk 'index($0, "if [ -n \"${AI_DLC_READSET_SANDBOX_PROFILE:-}\" ]; then") { f = 1; next } f && /^  elif / { exit } f { print }' "$d" | sed 's/ || die .*$//')"
  [ -n "$ob" ] || return 1
  printf '(version 3)\n(allow default (with report))\n' > "$o/unscoped.sb"
  ( TREE="$o/ov/t"; MARKDIR="$o/ov/m"; PROFILE="$o/ov.sb"; AI_DLC_READSET_SANDBOX_PROFILE="$o/unscoped.sb"; eval "$ob" ) || return 1
  for e in def lm ov; do [ -s "$o/$e.sb" ] || return 1; done
}
R="$WORK/r"
render3 "$DERIVER" "$R/fix" || broken "cannot render the deriver's three emitters"
for e in def lm ov; do
  grep -qF "(literal \"$R/fix/$e/t\")" "$R/fix/$e.sb" || broken "the rendered $e profile carries no root literal: $(tr '\n' ' ' < "$R/fix/$e.sb")"
done
for m in markdir-default markdir-ov-lm report-default report-lm; do render3 "$MD/$m.sh" "$R/$m" || broken "cannot render mutant $m"; done
# The clause-less control: the default profile as it was before BL-470, which MUST report root md/exist.
mkdir -p "$R/base/def/t/d" "$R/base/def/m" && echo x > "$R/base/def/t/d/f" && echo y > "$R/base/def/t/g" || broken "base tree"
printf '(version 3)\n(allow default)\n(allow file* process-exec* (subpath "%s") (subpath "%s") (with report))\n' "$R/base/def/t" "$R/base/def/m" > "$R/base/def.sb"
mkdir -p "$R/end/t" && echo s > "$R/end/t/s" && echo e > "$R/end/t/e" || broken "sentinel tree"
printf '(version 3)\n(allow default)\n(allow file-read* (subpath "%s") (with report))\n' "$R/end/t" > "$R/end.sb"

# ------------------------------------------------------------------ one stream ----
# ONLY A WINDOW WITH ZERO DROP NOTICES IS JUDGED, AND A LOSSY ONE IS RETRIED, NOT SCORED. A dropped
# report makes every count below a floor, so a lossy window can neither pass nor fail an arm. One
# attempt refused as BROKEN on any notice, and on a loaded box that is most attempts: measured at
# load 41-42, 2 of 3 single attempts dropped 1-2 notices. Ten attempts, a pause between them so a
# load spike can pass; all ten lossy is still BROKEN. The attempt count is printed on every run.
sentinel() { local i=0; while [ "$i" -lt 50 ]; do sandbox-exec -f "$R/end.sb" /bin/cat "$R/end/t/$1" >/dev/null 2>&1 </dev/null; grep -qF "file-read-data $R/end/t/$1" "$WORK/raw" && return 0; sleep 0.2; i=$((i + 1)); done; return 1; }
ATT=0; NDS=""
while [ "$ATT" -lt 10 ]; do
  ATT=$((ATT + 1))
  [ "$ATT" -eq 1 ] || sleep 2
  /usr/bin/log stream --style compact --predicate "eventMessage CONTAINS \"$R/\"" > "$WORK/raw" 2>&1 &
  LSP=$!
  sentinel s || broken "the sandbox stream never delivered the start sentinel (attempt $ATT)"
  for sb in "$R"/*/*.sb; do
    case "$sb" in "$R/end/"*|*/unscoped.sb) continue ;; esac
    t="${sb%.sb}/t"
    sandbox-exec -D FXTAG=r -f "$sb" /bin/bash -c 'cd "$1" && [ -d "$1" ] && [ -e "$1" ] && ls "$1" >/dev/null && cat "$1/g" "$1/d/f" >/dev/null && [ -f "$1/d/f" ]' _ "$t" </dev/null \
      || broken "the rendering $sb refused the probe workload"
  done
  sentinel e || broken "the sandbox stream never delivered the end sentinel (attempt $ATT)"
  sleep 1; kill "$LSP" 2>/dev/null; wait "$LSP" 2>/dev/null; LSP=""
  nd="$(grep -c 'dropped during' "$WORK/raw")" || nd=0
  [ "$nd" = 0 ] && break
  NDS="$NDS $nd"
done
[ "$nd" = 0 ] || broken "the stream dropped reports in all $ATT attempts (notices per attempt:$NDS); the counts below would be floors"
printf '  note  stream window judged on attempt %s of 10 (drop notices in the lossy attempts before it:%s)\n' "$ATT" "${NDS:- none}"

# cnt <variant> <emitter> <op ERE> <suffix ERE>
cnt() { local n; n="$(grep -cE "($3) $R/$1/$2/t$4( |\$)" "$WORK/raw")" || n=0; printf '%s' "$n"; }
OPS='file-read-metadata|file-test-existence'

echo " the deriver's three emitters, rendered and run:"
b="$(cnt base def "$OPS" '')"
if [ "$b" -gt 0 ]; then ok "control: the clause-less default profile reports root metadata/existence ($b)"; else bad "control: the clause-less profile reported no root metadata/existence, so a 0 below proves nothing"; fi
for e in def lm ov; do
  rm="$(cnt fix "$e" "$OPS" '')"; rd="$(cnt fix "$e" file-read-data '')"; brd="$(cnt fix "$e" file-read-data '/.+')"; bmd="$(cnt fix "$e" "$OPS" '/.+')"
  if [ "$rm" = 0 ] && [ "$rd" -gt 0 ] && [ "$brd" -gt 0 ] && [ "$bmd" -gt 0 ]; then
    ok "$e emitter: root metadata/existence 0, root file-read-data $rd, below-root reads $brd, below-root metadata $bmd"
  else
    bad "$e emitter: root metadata/existence $rm (want 0), root file-read-data $rd, below-root reads $brd, below-root metadata $bmd (each want >0)"
  fi
done

echo " mutants:"
for m in markdir-default markdir-ov-lm report-default report-lm; do
  why=""; ran=1
  for e in def lm ov; do
    brd="$(cnt "$m" "$e" file-read-data '/.+')"; [ "$brd" -gt 0 ] || ran=0
    rm="$(cnt "$m" "$e" "$OPS" '')"; [ "$rm" = 0 ] || why="$why $e:$rm"
  done
  if [ "$ran" = 0 ]; then bad "mutant $m did not run: an emitter shows no below-root reads"
  elif [ -n "$why" ]; then ok "mutant $m KILLED (root metadata/existence reported by emitter(s)$why)"
  else bad "mutant $m SURVIVED"; fi
done

echo
if [ "$FAILS" -ne 0 ]; then
  echo "readset-sandbox-root-clause: $FAILS of $ASSERTS FAILED (work kept at $WORK)"
  exit 1
fi
case "$WORK" in */readset-sandbox-root-clause.??????) rm -rf "$WORK" ;; esac
echo "readset-sandbox-root-clause: all $ASSERTS assertions hold"
exit 0
