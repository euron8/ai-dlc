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
# block is sourced with the trip set stubbed, and the override branch is eval'd against a SCOPED
# override profile (an `allow default (with report)` override would become `deny default` below, and
# sandbox-exec then refuses to exec the workload at all, rc 71). A text count of the clause is kept as
# a CONTROL only: a mutant moving the override and `--local-map` clauses onto `$MARKDIR` keeps that
# count at 3, and only the rendered runs see it.
#
# THE CHANNEL IS THE WORKLOAD'S OWN ERRNO, NOT THE KERNEL LOG STREAM (BL-868, BL-616's MAXATT retry).
# `/usr/bin/log stream` drops reports under load, so the stream judging needed a 30-attempt retry, a
# polled start/end sentinel and two sleeps -- a verdict that depended on load. Every rendered `.sb`
# is now MECHANICALLY REWRITTEN (deny_sb): each `(allow ... (with report) ...)` clause becomes `(deny
# ...)` with every `(with ...)` modifier stripped, the `--local-map` FXTAG message and its TRIP clause
# included. An operation the profile would REPORT is then an operation the kernel DENIES, so the
# workload sees it as a non-zero rc, synchronously, and nothing can drop it. The root-literal clause
# carries no `(with report)`, so it stays an ALLOW after the clause it follows and re-admits root
# metadata/existence. The workload runs each operation separately and prints one rc per operation.
# The scored ops: root `cd`, `[ -d ]`, `[ -e ]` (metadata/existence: rc 0 under the fix, non-zero
# under every mutant of the clause), root `ls` (file-read-data: must stay DENIED, i.e. still reported),
# a read and a test below the root (DENIED), and an `ls /` outside the tree (ALLOWED, the positive
# control that the sandbox is not denying everything). The same workload unsandboxed reads 0 on every
# op, so a non-zero rc is the profile's, not a missing file.
# MEASURED EQUIVALENT BEFORE THE STREAM ARMS WERE DELETED: `--matrix` on the stream channel (its last
# revision, run at 47102ad20, window judged on attempt 1 of 30) and on this errno channel printed the
# four MATRIX lines below byte-identically (`cmp` of the extracted MATRIX lines: equal), twins included:
#   MATRIX markdir-default decides=def:RED twins=lm:GREEN others=1/1
#   MATRIX markdir-ov-lm decides=lm:RED,ov:RED twins=def:GREEN others=0/0
#   MATRIX report-default decides=def:RED twins=ov:GREEN others=1/1
#   MATRIX report-lm decides=lm:RED twins=ov:GREEN others=1/1
#
# WHY A SEPARATE FIXTURE. Carried inside readset-stage1-verdict, its old stream arms SKIPped under the
# sandbox tracer and made that fixture's traced verdict differ from its untraced one. This fixture carries
# `inputs.decl`, so it is keyed on its declaration and never traced; its own sandbox-exec runs nested too
# (measured: a sandbox-exec under an allow-default profile ran a nested one, rc 0).
#
# Usage: run.sh [--matrix]
# Exit:  0 = every arm and mutant holds (or SKIP, stated), 1 = one regressed, 2 = fixture broken.
#
# THE MUTANT MATRIX. A cell is one EMITTER of the deriver (def = the default profile, lm = the `--local-map`
# profile, ov = the AI_DLC_READSET_SANDBOX_PROFILE override), RED on a mutant when that emitter, rendered from the
# mutated deriver, deny-rewritten and run under the sandbox, denies root metadata/existence. A mutant's row lists the
# emitters it breaks (decides) and the emitter it could plausibly co-trip but must leave GREEN (twins). Every rendering
# runs once and every cell reads that run's rc file, so a twin costs no extra render and no extra run. The matrix is re-measured
# whenever an arm or a mutant is added or changed, by the REMEASURE command below, run from the repo root. It
# scores every mutant against every emitter and prints one MATRIX line each.
# MUTANT-MATRIX markdir-default decides=def twins=lm
# MUTANT-MATRIX markdir-ov-lm decides=lm,ov twins=def
# MUTANT-MATRIX report-default decides=def twins=ov
# MUTANT-MATRIX report-lm decides=lm twins=ov
# MUTANT-MATRIX-DYNAMIC score_mutant why=score_mutant is one body called once per mutant, so the mutant id reaches mutant_killed as $m; every name it produces has its own MUTANT-MATRIX row above
# MUTANT-MATRIX-REMEASURE bash core/fixtures/readset-sandbox-root-clause/run.sh --matrix
set -u
# MODE is "matrix" only under the positional `--matrix`; an AI_DLC_* name would be scrubbed below. Anything else
# as an argument is a usage error, never a silent plain run.
MODE=plain
case "${1:-}" in
  "") ;;
  --matrix) MODE=matrix ;;
  *) echo "readset-sandbox-root-clause: usage: run.sh [--matrix]" >&2; exit 2 ;;
esac
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd -P)"
ROOT="$HERE"
while [ "$ROOT" != "/" ] && [ ! -f "$ROOT/core/scripts/derive-fixture-readsets.sh" ]; do ROOT="$(dirname "$ROOT")"; done
DERIVER="$ROOT/core/scripts/derive-fixture-readsets.sh"
[ -f "$DERIVER" ] || { echo "readset-sandbox-root-clause: FIXTURE BROKEN: no core/scripts/derive-fixture-readsets.sh above $HERE" >&2; exit 2; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/readset-sandbox-root-clause.XXXXXX")" || { echo "FIXTURE BROKEN: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd -P)"

FAILS=0; ASSERTS=0
ok()     { printf '  ok    %s\n' "$1"; ASSERTS=$((ASSERTS + 1)); }
bad()    { printf '  FAIL  %s\n' "$1"; FAILS=$((FAILS + 1)); ASSERTS=$((ASSERTS + 1)); }
broken() { echo "readset-sandbox-root-clause: FIXTURE BROKEN: $*" >&2; echo "  (work kept at $WORK)" >&2; exit 2; }
echo "readset-sandbox-root-clause:"
echo "HERMETIC-CONSUMED core/scripts/derive-fixture-readsets.sh"
SELF_FILE="$HERE/$(basename "$0")"
# The shared mutant-kill helper: a kill is emitted only through mutant_killed, behind a same-run base-pass flag.
MUT_LIB="$HERE/../lib/mutant.sh"
[ -f "$MUT_LIB" ] || { echo "readset-sandbox-root-clause: FIXTURE BROKEN: no lib/mutant.sh beside $HERE" >&2; exit 2; }
. "$MUT_LIB"

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
# A missing sandbox-exec is not normal use here (this fixture's subject is a macOS tracer), so it SKIPs. A
# sandbox-exec that refuses a trivial profile is a broken harness, never a SKIP.
SB_WHY=""
if ! command -v sandbox-exec >/dev/null 2>&1; then SB_WHY="no sandbox-exec (not macOS)"; fi
if [ -n "$SB_WHY" ]; then
  printf '  SKIP  rendered sandbox arms: %s\n' "$SB_WHY"
  if [ "$MODE" = matrix ]; then echo "readset-sandbox-root-clause: MATRIX BROKEN: the rendered arms are SKIPPED here ($SB_WHY), so nothing was measured" >&2; exit 2; fi
  echo
  if [ "$FAILS" -ne 0 ]; then echo "readset-sandbox-root-clause: $FAILS of $ASSERTS FAILED (work kept at $WORK)"; exit 1; fi
  case "$WORK" in */readset-sandbox-root-clause.??????) rm -rf "$WORK" ;; esac
  echo "readset-sandbox-root-clause: all $ASSERTS assertions hold (rendered arms SKIPPED: $SB_WHY)"
  exit 0
fi

# ------------------------------------------------------------------ rendering ----
# render3 <deriver> <dir>: writes <dir>/{def,lm,ov}.sb, each for its own tree <dir>/<e>/t. The override is a
# SCOPED profile in the shipped default's shape, written with the `@TREE@`/`@MARK@` tokens the override branch
# substitutes, so its substitution is exercised too.
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
  printf '(version 3)\n(allow default)\n(allow file* process-exec* (subpath "@TREE@") (subpath "@MARK@") (with report))\n' > "$o/scoped.sb"
  ( TREE="$o/ov/t"; MARKDIR="$o/ov/m"; PROFILE="$o/ov.sb"; AI_DLC_READSET_SANDBOX_PROFILE="$o/scoped.sb"; eval "$ob" ) || return 1
  for e in def lm ov; do [ -s "$o/$e.sb" ] || return 1; done
}
# deny_sb <in.sb> <out.sb>: THE CHANNEL. Every clause carrying `(with report)` must open `(allow `; it becomes
# `(deny ` and loses every `(with ...)` modifier, nested parens included. Any other line is copied unchanged.
# Refuses (rc 1) when a reported clause is not an allow, a modifier is unbalanced, no clause was rewritten, or a
# `(with ` survives -- a rewrite that silently did nothing would score every cell GREEN.
deny_sb() {
  awk -v CF="$2.n" '
    index($0, "(with report)") {
      n++
      if (!sub(/^\(allow /, "(deny ")) bad = 1
      while ((i = index($0, " (with ")) > 0) {
        dp = 0
        for (j = i + 1; j <= length($0); j++) {
          ch = substr($0, j, 1)
          if (ch == "(") dp++
          else if (ch == ")") { dp--; if (dp == 0) break }
        }
        if (dp != 0) { bad = 1; break }
        $0 = substr($0, 1, i - 1) substr($0, j + 1)
      }
    }
    { print }
    END { print n + 0 > CF; exit bad }' "$1" > "$2" || return 1
  [ "$(cat "$2.n")" -ge 1 ] || return 1
  if grep -qF '(with ' "$2"; then return 1; fi
}
R="$WORK/r"
render3 "$DERIVER" "$R/fix" || broken "cannot render the deriver's three emitters"
for e in def lm ov; do
  grep -qF "(literal \"$R/fix/$e/t\")" "$R/fix/$e.sb" || broken "the rendered $e profile carries no root literal: $(tr '\n' ' ' < "$R/fix/$e.sb")"
done
for m in markdir-default markdir-ov-lm report-default report-lm; do render3 "$MD/$m.sh" "$R/$m" || broken "cannot render mutant $m"; done
# The clause-less control: the default profile as it was before BL-470, which MUST deny root md/exist once rewritten.
mkdir -p "$R/base/def/t/d" "$R/base/def/m" && echo x > "$R/base/def/t/d/f" && echo y > "$R/base/def/t/g" || broken "base tree"
printf '(version 3)\n(allow default)\n(allow file* process-exec* (subpath "%s") (subpath "%s") (with report))\n' "$R/base/def/t" "$R/base/def/m" > "$R/base/def.sb"

# ------------------------------------------------------------------ one run per rendering ----
# The workload runs each operation SEPARATELY and prints its rc, in this fixed order, on one line:
#   cd-root  [ -d root ]  [ -e root ]  ls root  cat below  [ -f below ]  ls /
# The first three are the root metadata/existence ops the clause re-admits; `ls root` is the root's
# file-read-data, which must stay reported (denied here); the two below-root ops must stay denied; `ls /`
# is outside the tree and must be allowed, so a profile denying everything cannot read as a kill.
WL='t="$1"
if cd "$t" 2>/dev/null; then a=0; else a=$?; fi
[ -d "$t" ]; b=$?
[ -e "$t" ]; c=$?
ls "$t" >/dev/null 2>&1; d=$?
cat "$t/g" >/dev/null 2>&1; e=$?
[ -f "$t/d/f" ]; f=$?
ls / >/dev/null 2>&1; g=$?
echo "$a $b $c $d $e $f $g"'
# The same workload UNSANDBOXED on the fix tree, in a subshell (no new bash start): every op 0, so a non-zero rc
# below is the profile's, not a missing file.
( set -- "$R/fix/def/t"; eval "$WL" ) > "$WORK/nosb.rc" </dev/null || broken "the unsandboxed workload failed"
[ "$(cat "$WORK/nosb.rc")" = "0 0 0 0 0 0 0" ] || broken "the unsandboxed workload read [$(cat "$WORK/nosb.rc")], not every op 0"
for sb in "$R"/*/*.sb; do
  case "$sb" in */scoped.sb|*.deny.sb) continue ;; esac
  deny_sb "$sb" "${sb%.sb}.deny.sb" || broken "cannot deny-rewrite $sb: $(tr '\n' ' ' < "$sb")"
  sandbox-exec -D FXTAG=r -f "${sb%.sb}.deny.sb" /bin/bash -c "$WL" _ "${sb%.sb}/t" > "${sb%.sb}.rc" 2>"${sb%.sb}.err" </dev/null \
    || broken "sandbox-exec refused the rewritten $sb (rc $?): $(head -1 "${sb%.sb}.err")"
done
# rcs <variant> <emitter>: binds C_CD C_TD C_TE C_LSR C_CATB C_TB C_LSO from that rendering's one run (no fork).
rcs() {
  C_LSO=""
  read -r C_CD C_TD C_TE C_LSR C_CATB C_TB C_LSO < "$R/$1/$2.rc" || true
  case "$C_CD$C_TD$C_TE$C_LSR$C_CATB$C_TB$C_LSO" in ''|*[!0-9]*) broken "the run of $1/$2 printed no seven rcs: [$(cat "$R/$1/$2.rc")]" ;; esac
}

echo " the deriver's three emitters, rendered, deny-rewritten and run:"
rcs base def
if [ "$C_CD" != 0 ] && [ "$C_TD" != 0 ] && [ "$C_TE" != 0 ] && [ "$C_LSO" = 0 ]; then
  ok "control: the clause-less default profile denies root cd/test-d/test-e ($C_CD $C_TD $C_TE) and allows ls / ($C_LSO)"; B_ctl=1
else bad "control: the clause-less profile read root cd/test-d/test-e $C_CD $C_TD $C_TE, ls / $C_LSO (want non-zero x3, then 0), so a 0 below proves nothing"; fi
for e in def lm ov; do
  rcs fix "$e"
  if [ "$C_CD$C_TD$C_TE" = 000 ] && [ "$C_LSR" != 0 ] && [ "$C_CATB" != 0 ] && [ "$C_TB" != 0 ] && [ "$C_LSO" = 0 ]; then
    ok "$e emitter: root cd/test-d/test-e allowed (0 0 0), root ls denied ($C_LSR), below-root read and test denied ($C_CATB $C_TB), ls / allowed"
    case "$e" in def) B_def=1 ;; lm) B_lm=1 ;; ov) B_ov=1 ;; esac
  else
    bad "$e emitter: root cd/test-d/test-e $C_CD $C_TD $C_TE (want 0 0 0), root ls $C_LSR, below read $C_CATB, below test $C_TB (each want non-zero), ls / $C_LSO (want 0)"
  fi
done

echo " mutants:"
# cell_red <emitter> <mutant>: RED when the emitter rendered from the mutated deriver, deny-rewritten, denies root
# metadata/existence. Returns 0 RED, 1 GREEN, 2 UNKNOWN CELL (an unknown name must never read as GREEN).
cell_red() {
  case "$1" in def|lm|ov) ;; *) return 2 ;; esac
  rcs "$2" "$1"
  [ "$C_CD$C_TD$C_TE" != 000 ]
}
# The header IS the decides/twins list: nothing else in this file restates it.
mx_row() { # mx_row <mutant> <decides|twins>
  awk -v n="$1" -v f="$2" '
    $1 == "#" && $2 == "MUTANT-MATRIX" && $3 == n {
      c++; for (i = 4; i <= NF; i++) if (index($i, f "=") == 1) v = substr($i, length(f) + 2)
    }
    END { if (c == 1) print v }' "$SELF_FILE"
}
MXL="$WORK/mx.ledger"; : > "$MXL"
BROKEN=0; MX_FAILS=0
# mx_twins <mutant>: per-push, every twin emitter must be GREEN on the SAME run's rc files, which costs no render.
mx_twins() {
  local m="$1" tw t r
  tw="$(mx_row "$m" twins)"
  if [ -z "$tw" ]; then BROKEN=$((BROKEN + 1)); printf '  FIXTURE BROKEN %s: no single MUTANT-MATRIX row names its twins\n' "$m"; return; fi
  printf 'plain-twins %s\n' "$m" >> "$MXL"
  for t in $(printf '%s' "$tw" | tr ',' ' '); do
    cell_red "$t" "$m"; r=$?
    if [ "$r" -eq 2 ]; then BROKEN=$((BROKEN + 1)); printf '  FIXTURE BROKEN %s: twin %s names no cell\n' "$m" "$t"
    elif [ "$r" -eq 0 ]; then bad "mutant $m: its twin $t also denied root metadata/existence, so the kill is not confined to its own emitter"; fi
  done
}
# mx_score <mutant>: MATRIX-ONLY. Scores the mutant against every emitter. It records itself in the ledger first (rule 9).
mx_score() {
  local m="$1" dec tw c r uex="" dl="" tl="" g=0 tot=0
  printf 'mx-score %s\n' "$m" >> "$MXL"
  dec="$(mx_row "$m" decides)"; tw="$(mx_row "$m" twins)"
  for c in $(printf '%s' "$dec" | tr ',' ' '); do
    cell_red "$c" "$m"; r=$?
    if [ "$r" -eq 0 ]; then dl="$dl,$c:RED"; else dl="$dl,$c:GREEN"; uex="$uex $c:GREEN"; fi
  done
  for c in $(printf '%s' "$tw" | tr ',' ' '); do
    cell_red "$c" "$m"; r=$?
    if [ "$r" -eq 0 ]; then tl="$tl,$c:RED"; uex="$uex $c:RED"; else tl="$tl,$c:GREEN"; fi
  done
  for c in def lm ov; do
    case ",$dec,$tw," in *",$c,"*) continue ;; esac
    tot=$((tot + 1)); cell_red "$c" "$m" || g=$((g + 1))
  done
  if [ -n "$uex" ]; then
    printf 'MATRIX %s decides=%s twins=%s others=%d/%d UNEXPECTED=%s\n' "$m" "${dl#,}" "${tl#,}" "$g" "$tot" "$(printf '%s' "${uex# }" | tr ' ' ',')"
    MX_FAILS=$((MX_FAILS + 1))
  else
    printf 'MATRIX %s decides=%s twins=%s others=%d/%d\n' "$m" "${dl#,}" "${tl#,}" "$g" "$tot"
  fi
}
# score_mutant <flag> <mutant>: the flag is the same-run base pass of the control and of every deciding emitter.
# The mutant is killed when every deciding emitter, deny-rewritten, denies root metadata/existence. Its twins are
# checked on the same run. Only the passing branch of the unmutated arms ever sets a flag.
score_mutant() {
  local flag="$1" m="$2" dec c ran=1 miss=""
  # RAN: every emitter's rendering still denies the below-root read and allows `ls /`, so the profile was in force
  # and scoped, and a RED cell is the clause's doing rather than a profile that denied nothing or everything.
  for c in def lm ov; do
    rcs "$m" "$c"
    [ "$C_CATB" != 0 ] && [ "$C_LSO" = 0 ] || ran=0
  done
  dec="$(mx_row "$m" decides)"
  for c in $(printf '%s' "$dec" | tr ',' ' '); do cell_red "$c" "$m" || miss="$miss $c"; done
  if [ "$ran" = 0 ]; then bad "mutant $m did not run: an emitter allowed the below-root read or denied ls /"
  elif [ -z "$miss" ]; then mutant_killed "$flag" "$m" "mutant $m KILLED (root metadata/existence denied by emitter(s) $dec)"
  else bad "mutant $m SURVIVED (emitter(s)$miss allowed root metadata/existence)"; fi
  mx_twins "$m"
  if [ "$MODE" = matrix ]; then mx_score "$m"; fi
}
score_mutant "$(( ${B_ctl:-0} && ${B_def:-0} ))" markdir-default
score_mutant "$(( ${B_ctl:-0} && ${B_lm:-0} && ${B_ov:-0} ))" markdir-ov-lm
score_mutant "$(( ${B_ctl:-0} && ${B_def:-0} ))" report-default
score_mutant "$(( ${B_ctl:-0} && ${B_lm:-0} ))" report-lm

# RULE 9: a plain run executes NO matrix-only cell. Every matrix-only score appends `mx-score` to the ledger before
# anything else; the per-push twin check appends `plain-twins` to the SAME ledger. That second line is the CONTROL:
# it must be present, so a zero count of matrix-only cells cannot come from a ledger nothing writes.
mx_only="$(grep -c '^mx-score ' "$MXL")" || mx_only=0
mx_ctl="$(grep -c '^plain-twins ' "$MXL")" || mx_ctl=0
if [ "$MODE" = plain ]; then
  if [ "$mx_ctl" -eq 0 ]; then bad "rule-9: the matrix ledger control is EMPTY, so a zero count of matrix-only cells would mean nothing"
  elif [ "$mx_only" -ne 0 ]; then bad "rule-9: a plain run executed $mx_only matrix-only cell(s), so the --matrix measurement leaked into the per-push run"
  else ok "rule-9: a plain run executed no matrix-only cell, while its $mx_ctl per-push twin check(s) wrote to the same ledger"; fi
else
  mx_hdr="$(awk '$1 == "#" && $2 == "MUTANT-MATRIX" { print $3 }' "$SELF_FILE" | LC_ALL=C sort | tr '\n' ' ')"
  [ "$mx_hdr" = "markdir-default markdir-ov-lm report-default report-lm " ] || { BROKEN=$((BROKEN + 1)); echo "MATRIX BROKEN: the header rows are [$mx_hdr]"; }
  echo "MATRIX-SUMMARY $mx_only matrix-only cell(s) ran, $mx_ctl per-push twin check(s)"
  FAILS=$((FAILS + MX_FAILS))
fi
if [ "$BROKEN" -ne 0 ]; then echo "readset-sandbox-root-clause: FIXTURE BROKEN: $BROKEN mutant arm(s) could not be scored" >&2; exit 2; fi

echo
if [ "$FAILS" -ne 0 ]; then
  echo "readset-sandbox-root-clause: $FAILS of $ASSERTS FAILED (work kept at $WORK)"
  exit 1
fi
case "$WORK" in */readset-sandbox-root-clause.??????) rm -rf "$WORK" ;; esac
echo "readset-sandbox-root-clause: all $ASSERTS assertions hold"
exit 0
