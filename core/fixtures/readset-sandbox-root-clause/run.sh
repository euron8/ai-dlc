#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
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
# a CONTROL only.
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
# The scored ops: root `cd`, `[ -d ]`, `[ -e ]` (metadata/existence: rc 0 under the fix), root `ls`
# (file-read-data: must stay DENIED, i.e. still reported),
# a read and a test below the root (DENIED), and an `ls /` outside the tree (ALLOWED, the positive
# control that the sandbox is not denying everything). The same workload unsandboxed reads 0 on every
# op, so a non-zero rc is the profile's, not a missing file.
#
# WHY A SEPARATE FIXTURE. Carried inside readset-stage1-verdict, its old stream arms SKIPped under the
# sandbox tracer and made that fixture's traced verdict differ from its untraced one. This fixture carries
# `inputs.decl`, so it is keyed on its declaration and never traced; its own sandbox-exec runs nested too
# (measured: a sandbox-exec under an allow-default profile ran a nested one, rc 0).
#
# Usage: run.sh
# Exit:  0 = every arm holds (or SKIP, stated), 1 = one regressed, 2 = fixture broken.
set -u
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd -P)"
ROOT="$HERE"
while [ "$ROOT" != "/" ] && [ ! -f "$ROOT/core/scripts/derive-fixture-readsets.sh" ]; do ROOT="$(dirname "$ROOT")"; done
DERIVER="$ROOT/core/scripts/derive-fixture-readsets.sh"
[ -f "$DERIVER" ] || { echo "readset-sandbox-root-clause: FIXTURE BROKEN: no core/scripts/derive-fixture-readsets.sh above $HERE" >&2; exit 2; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/readset-sandbox-root-clause.XXXXXX")" || { echo "FIXTURE BROKEN: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd -P)"

# shellcheck source=/dev/null
. "$HERE/../lib/report.sh" || { echo "FIXTURE ERROR: lib/report.sh not found" >&2; exit 2; }
broken() { echo "readset-sandbox-root-clause: FIXTURE BROKEN: $*" >&2; echo "  (work kept at $WORK)" >&2; exit 2; }
echo "readset-sandbox-root-clause:"
echo "HERMETIC-CONSUMED core/scripts/derive-fixture-readsets.sh"

CLAUSE='(allow file-read-metadata file-test-existence (literal "%s"))'
cl_count() { awk -v k="$CLAUSE" '{ l = $0; sub(/^[ \t]+/, "", l) } substr(l, 1, 1) != "#" && index($0, k) { n++ } END { print n + 0 }' "$1"; }

# ------------------------------------------------------------------ text control ----
echo " text control:"
n="$(cl_count "$DERIVER")"
if [ "$n" = 3 ]; then ok "the root-literal clause is on 3 uncommented emitter lines (control only; the rendered arms below decide)"; else bad "the root-literal clause is on $n uncommented emitter line(s), not 3"; fi

# ------------------------------------------------------------------ the gate ----
# A missing sandbox-exec is not normal use here (this fixture's subject is a macOS tracer), so it SKIPs. A
# sandbox-exec that refuses a trivial profile is a broken harness, never a SKIP.
SB_WHY=""
if ! command -v sandbox-exec >/dev/null 2>&1; then SB_WHY="no sandbox-exec (not macOS)"; fi
if [ -n "$SB_WHY" ]; then
  printf '  SKIP  rendered sandbox arms: %s\n' "$SB_WHY"
  echo
  if [ "$fails" -ne 0 ]; then echo "readset-sandbox-root-clause: work kept at $WORK"
  else case "$WORK" in */readset-sandbox-root-clause.??????) rm -rf "$WORK" ;; esac; fi
  echo "readset-sandbox-root-clause: rendered arms SKIPPED: $SB_WHY"
  report_end readset-sandbox-root-clause
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
  ok "control: the clause-less default profile denies root cd/test-d/test-e ($C_CD $C_TD $C_TE) and allows ls / ($C_LSO)"
else bad "control: the clause-less profile read root cd/test-d/test-e $C_CD $C_TD $C_TE, ls / $C_LSO (want non-zero x3, then 0), so a 0 below proves nothing"; fi
for e in def lm ov; do
  rcs fix "$e"
  if [ "$C_CD$C_TD$C_TE" = 000 ] && [ "$C_LSR" != 0 ] && [ "$C_CATB" != 0 ] && [ "$C_TB" != 0 ] && [ "$C_LSO" = 0 ]; then
    ok "$e emitter: root cd/test-d/test-e allowed (0 0 0), root ls denied ($C_LSR), below-root read and test denied ($C_CATB $C_TB), ls / allowed"
  else
    bad "$e emitter: root cd/test-d/test-e $C_CD $C_TD $C_TE (want 0 0 0), root ls $C_LSR, below read $C_CATB, below test $C_TB (each want non-zero), ls / $C_LSO (want 0)"
  fi
done

# ------------------------------------------------------------------ the nest shim and its guard (BL-1068) ----
# Three cells, each written as "$R/<variant>/<cell>.red" (0 GREEN, 1 RED), from the variant deriver's OWN functions:
#   nb  readset_nest_bypass over two windows in the kernel's line shape: an escaped sandbox-exec exec paired with the
#       shim's marker read under the same pid reads 0, one with no marker read under its pid (a peer pid carries one)
#       reads 1. Pure text in, a count out: no stream.
#   nm  the shim, run under the deny-rewritten form of a tree+marker report clause (the errno channel above): its
#       marker read is DENIED, so the read shows on the shim's stderr naming the marker, and the exec still reaches
#       the next sandbox-exec (a recorder stub). Presence-shaped: the stub's argv record must exist.
#   nc  the shim, run unsandboxed: the stub's profile has the caller's `(version 1)` form, then the inserted clause,
#       then the caller's rule, and `-D` survives ahead of the stub's `-f`.
# nest_cells <deriver> <dir>
nest_cells() {
  local d="$1" o="$2" fn
  mkdir -p "$o/t" "$o/m" "$o/s" "$o/stub" || return 1
  for fn in readset_write_nest_shim readset_nest_bypass; do
    awk -v f="$fn" '$0 == f "() {" || index($0, f "() { ") == 1 { p = 1 } p { print } p && /^}$/ { exit }' "$d" > "$o/$fn.fn" || return 1
    [ -s "$o/$fn.fn" ] || return 1
  done
  printf '#!/bin/bash\nprintf "%%s\\n" "$@" > "%s/args"\nwhile [ $# -gt 0 ]; do [ "$1" = -f ] && { cat "$2" > "%s/prof"; break; }; shift; done\nexit 0\n' "$o" "$o" > "$o/stub/sandbox-exec" \
    && chmod +x "$o/stub/sandbox-exec" || return 1
  (
    . "$o/readset_write_nest_shim.fn"; . "$o/readset_nest_bypass.fn"
    MARKDIR="$o/m"; L="2026-11-14 00:00:00.000000-0500 0x1 Default 0x0 0 0 kernel: [com.apple.sandbox.reporting:violation] Sandbox:"
    printf '%s bash(101) allow file-read-data %s\n%s bash(101) allow process-exec* /usr/bin/sandbox-exec\n' "$L" "$o/m/.readset-nest" "$L" > "$o/w.paired"
    printf '%s bash(303) allow file-read-data %s\n%s bash(202) allow process-exec* /usr/bin/sandbox-exec\n' "$L" "$o/m/.readset-nest" "$L" > "$o/w.bare"
    nb="$(readset_nest_bypass "$o/m/.readset-nest" < "$o/w.paired")|$(readset_nest_bypass "$o/m/.readset-nest" < "$o/w.bare")"
    [ "$nb" = "0|1" ]; printf '%s\n' "$?" > "$o/nb.red"; printf '%s\n' "$nb" > "$o/nb.val"
    INS="(allow file* (subpath \"$o/t\") (subpath \"$o/m\") (with report))"
    SBX="$(command -v sandbox-exec)"; PATH="$o/stub:$PATH"; hash -r
    readset_write_nest_shim "$o/s" "$INS" || exit 1
    "$o/s/sandbox-exec" -D K=V -p '(version 1)(allow default)' /usr/bin/true 2> "$o/nc.err" < /dev/null
    { [ "$(sed -n 1p "$o/args")" = -D ] && [ "$(sed -n 2p "$o/args")" = K=V ] && [ "$(sed -n 3p "$o/args")" = -f ] \
      && [ "$(sed -n 1p "$o/prof")" = '(version 1)' ] && [ "$(sed -n 2p "$o/prof")" = "$INS" ] && [ "$(sed -n 3p "$o/prof")" = '(allow default)' ]; }
    printf '%s\n' "$?" > "$o/nc.red"
    rm -f "$o/args"
    printf '(version 3)\n(allow default)\n(deny file* process-exec* (subpath "%s") (subpath "%s"))\n' "$o/t" "$o/m" > "$o/deny.sb"
    "$SBX" -f "$o/deny.sb" "$o/s/sandbox-exec" -p '(version 1)(allow default)' /usr/bin/true 2> "$o/nm.err" < /dev/null
    [ -s "$o/args" ] || exit 1
    grep -qF "$o/m/.readset-nest" "$o/nm.err"; printf '%s\n' "$?" | awk '{ print ($1 == 0 ? 0 : 1) }' > "$o/nm.red"
  ) || return 1
  for c in nb nm nc; do [ -s "$o/$c.red" ] || return 1; done
}
nest_cells "$DERIVER" "$R/fix" || broken "cannot build the nest cells for the deriver"
echo " the nest shim and its bypass guard:"
nred() { [ "$(cat "$R/$2/$1.red")" = 1 ]; }
if ! nred nb fix; then ok "guard: a shim-paired escaped exec reads 0 bypasses and an unpaired one reads 1 ($(cat "$R/fix/nb.val"))"
else bad "guard: the paired|unpaired windows read $(cat "$R/fix/nb.val"), want 0|1"; fi
if ! nred nm fix; then ok "shim: under the deny channel its marker read is denied on its stderr before it execs the next sandbox-exec"
else bad "shim: no denied marker read on its stderr before the exec: $(tr '\n' ' ' < "$R/fix/nm.err")"; fi
if ! nred nc fix; then ok "shim: the composed profile is the caller's (version 1), the inserted clause, then the caller's rule, with -D kept"
else bad "shim: the composed profile or argv is wrong: [$(tr '\n' ' ' < "$R/fix/prof" 2>/dev/null)]"; fi
echo
if [ "$fails" -ne 0 ]; then echo "readset-sandbox-root-clause: work kept at $WORK"
else case "$WORK" in */readset-sandbox-root-clause.??????) rm -rf "$WORK" ;; esac; fi
report_end readset-sandbox-root-clause
