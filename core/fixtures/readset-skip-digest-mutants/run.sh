#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# Mutation battery for BL-471's committed-digest clearing, scored by the SHIPPED worlds of
# `readset-skip`: this file sources that fixture's CK_HELPERS and DG_WORLDS spans, so a mutant is
# judged by exactly the worlds the shipped fixture asserts, never by a restatement of them.
#
# WHY A SEPARATE FIXTURE. Each mutant drives all eight worlds (about thirty pushes); run inside
# `readset-skip` that cost lands on the suite's pole. Here it is a unit of its own.
#
# EVERY MUTANT DECLARES THE EXACT SET OF WORLDS IT MOVES. A mutant that moves one more world than it
# declares is entanglement, one fewer is a world that cannot see its subject -- both fail.
set -u
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

asserts=0; fails=0
ok()     { printf '  ok    %s\n' "$1"; asserts=$((asserts+1)); }
bad()    { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); asserts=$((asserts+1)); }
broken() { printf '  FAIL  %s\n' "$1" >&2; echo "readset-skip-digest-mutants: FIXTURE BROKEN" >&2; exit 2; }
echo "readset-skip-digest-mutants:"

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || broken "not in a git repo"
HOOK="$ROOT/.githooks/pre-push"
DERIVER="$ROOT/core/scripts/derive-fixture-readsets.sh"
VICTIM="$ROOT/core/fixtures/readset-skip/run.sh"
for p in "$HOOK" "$DERIVER" "$VICTIM"; do [ -f "$p" ] || broken "cannot locate $p"; done
echo "  hook:   ${HOOK#"$ROOT"/}"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/readset-dgmut.XXXXXX")" || broken "mktemp failed"
trap 'rm -rf "$WORK"' EXIT
CK_W="$WORK/ck"; mkdir -p "$CK_W" || broken "mkdir failed"

SPAN="$WORK/span.sh"
{ sed -n '/^# CK_HELPERS_BEGIN/,/^# CK_HELPERS_END$/p' "$VICTIM"
  sed -n '/^# DG_WORLDS_BEGIN$/,/^# DG_WORLDS_END$/p' "$VICTIM"; } > "$SPAN"
grep -q '^ck_push() ' "$SPAN" && grep -q '^dg_all() ' "$SPAN" && grep -q '^DG_WANT_w8=' "$SPAN" \
  || broken "readset-skip's CK_HELPERS or DG_WORLDS span is missing a function this battery drives"
# shellcheck disable=SC1090
. "$SPAN"

POOL="$WORK/pool.sh"
sed -n '/# FIXTURE_POOL_BEGIN/,/# FIXTURE_POOL_END/p' "$HOOK" > "$POOL"
FX="$(sed -n 's|^FXROOT="\([A-Za-z0-9_./-]*\)/"$|\1|p' "$POOL" | sort -u)"
[ -n "$FX" ] || broken "no FXROOT in the extracted pool block"

# UNMUTATED CONTROL, PRESENCE-SHAPED: every world must reach its want on the shipped block, or every
# kill below is a harness that never ran.
dg_all "$POOL" "$FX" ctl
n_ok=0
for w in $DG_WORLDS; do [ "$(cat "$CK_W/dg.ctl.$w.got")" = "$(dg_want "$w")" ] && n_ok=$((n_ok+1)); done
if [ "$n_ok" -eq 10 ]; then ok "CONTROL: all 10 committed-digest worlds reach their want on the unmutated block"
else broken "CONTROL: only $n_ok of 10 worlds reach their want on the unmutated block -- no mutant verdict below would be attributable"; fi

dg_mut() { # <name> "<declared worlds>" then triples <count> <from> <to>
  local name="$1" want="$2" dst="$CK_W/dgmut.$1.sh" n o moved=""; shift 2
  cp "$POOL" "$dst" || { bad "MUTANT $name: copy failed"; return; }
  while [ $# -ge 3 ]; do
    MF="$2" MT="$3" MC="$CK_W/dgmut.$name.n" awk '
      BEGIN { f = ENVIRON["MF"]; t = ENVIRON["MT"]; n = 0 }
      { line = $0; o = ""
        while ((q = index(line, f)) > 0) { o = o substr(line, 1, q - 1) t; line = substr(line, q + length(f)); n++ }
        print o line }
      END { print n > ENVIRON["MC"] }' "$dst" > "$dst.t" && mv "$dst.t" "$dst"
    n="$(cat "$CK_W/dgmut.$name.n" 2>/dev/null)"
    [ "$n" = "$1" ] || { bad "MUTANT $name: anchor matched ${n:-nothing} time(s), not $1 -- DID NOT APPLY"; return; }
    shift 3
  done
  cmp -s "$POOL" "$dst" && { bad "MUTANT $name: the copy is unchanged"; return; }
  dg_all "$dst" "$FX" "m.$name"
  for o in $DG_WORLDS; do
    [ "$(cat "$CK_W/dg.m.$name.$o.got")" = "$(dg_want "$o")" ] || moved="$moved $o"
  done
  if [ "${moved# }" = "$want" ]; then ok "MUTANT $name is KILLED by exactly ($want)"
  else bad "MUTANT $name moved '${moved# }', declared '$want'"; fi
}

# Committed validation bypassed: no committed digest ever clears.
dg_mut bypass "w1 w5 w7 w8" 1 '{ if ($2 == "match") m[$1] = 1; next }' '{ next }'
# D3 / BL-471 "2-field read as valid": a fixture with rows and no digest reads as matching.
dg_mut nodigest_valid "w3 w6" 1 '(!(f in w) ? "nodigest" :' '(!(f in w) ? "match" :'
# D3: a fixture with no digest read as UNMAPPED -- its committed rows stop selecting it, so it is keyed
# on the whole tree. w3 and w6 by their seed; w1, w7 and w8 on the pushes before their digest lands.
dg_mut nodigest_unmapped "w1 w3 w6 w7 w8 w9" 1 '  readset_rows "$out" rows | cut -f1 | sort -u > "$out/.mapped.all"' \
  '  readset_rows "$out" rows | cut -f1 | sort -u | awk -v c="$out/.cdig" '"'"'BEGIN { while ((getline l < c) > 0) { split(l, a, "\t"); if (a[2] == "nodigest") nd[a[1]] = 1 } } !($1 in nd)'"'"' > "$out/.mapped.all"'
# D2: committed validation made to need the deriver -- w1, w5 and w8 have none in their tree. w2 and w3
# move too, and rightly: with no committed verdict the stale explanation cannot name its reason.
dg_mut needs_deriver "w1 w2 w3 w5 w8" 1 '  readset_committed_digests "$out"' '  [ -n "$dsha" ] && readset_committed_digests "$out"'
# D0: committed validation only where a local map exists -- w5, w7 and w8 have none (w2, w3 as above).
dg_mut needs_localmap "w2 w3 w5 w7 w8" 1 '  readset_committed_digests "$out"' '  [ "$rl_loc" != /dev/null ] && readset_committed_digests "$out"'
# B1: the `#` filter on the committed map gone, so every `# digest` line reaches the row sets.
dg_mut b1_hashleak "w1 w2 w3 w4 w5 w7 w8 w9" 1 "[ -s \"\$READSET_MAP\" ] && grep -v '^#' \"\$READSET_MAP\" | sed" "[ -s \"\$READSET_MAP\" ] && cat \"\$READSET_MAP\" | sed"
# B2: the map's own path not skipped by the digest -- w8's alpha reads the map.
dg_mut selfread "w8" 1 '($2 in k) && $2 != skip {' '($2 in k) {'
# D1: a validated stale fixture still runs, as before this change.
dg_mut stale_runs "w1 w4 w7 w10" 1 'else if (st == "stale" && !(f in LOC)) {' 'else if (st == "stale") {'
# D1: the cleared record is not published, so it reads stale again on the next push.
dg_mut nopublish "w1 w4 w7 w10" 1 '($5 == "seeded" || $4 == "v" || $4 == "m")' '($5 == "seeded" || $4 == "m")'
# BL-471 "deriver sha ignored": the LOCAL validator stops comparing the deriver sha.
dg_mut deriver_ignored "w6" 1 '$2 == "#deriver" { dok[$1] = ($3 == dsha); next }' '$2 == "#deriver" { dok[$1] = 1; next }'
# F471d: the per-stale explanation line gone.
dg_mut noexplain "w2 w3" 1 '          for (r in l) print "   ..    stale, "' '          for (r in l) if (0) print "   ..    stale, "'
# dirvalue: a directory row's digest value is `-` again (the listing never substituted), so w9's grown
# src/d is invisible to the digest and the seed-time digest clears a record it must not.
dg_mut dirvalue "w9" 1 '$3 == "-" && (($2 "/") in l) {' '$3 == "-" && 0 && (($2 "/") in l) {'
# dirlocal: the local validator stops treating a `-` directory row as a match (equivalent to local rows
# carrying `#listing:` values, which the deriver's --local-map path must not write): w10's beta cannot clear.
dg_mut dirlocal "w10" 1 'if ($3 == "-") { if ($2 in now) bad[f] = 1 }' 'if (0) { if ($2 in now) bad[f] = 1 }'

# ------------------------------------------------------------------ tool-key mutants ----
# The mutants of readset-skip's tool-key worlds (inv pos mig migrun), moved here so their re-runs of
# those four worlds are a unit of this battery rather than weight on the suite's pole. This block is
# self-contained: its own span, control and count. The worlds are the SHIPPED ones, sourced from
# readset-skip's TK_WORLDS span on top of the CK_HELPERS already sourced above.
TKSPAN="$WORK/tkspan.sh"
sed -n '/^# TK_WORLDS_BEGIN/,/^# TK_WORLDS_END$/p' "$VICTIM" > "$TKSPAN"
grep -q '^tk_all() ' "$TKSPAN" && grep -q '^TK_WANT_migrun=' "$TKSPAN" \
  || broken "readset-skip's TK_WORLDS span is missing a function this battery drives"
# shellcheck disable=SC1090
. "$TKSPAN"
TK_P1="$POOL"; TK_X1="$FX"
tkm_before=$asserts
# UNMUTATED CONTROL, PRESENCE-SHAPED: all four tool-key worlds reach their want on the shipped block.
tk_all "$POOL" "$FX" ctl
tk_ok=0
for w in $TK_WORLDS; do [ "$(cat "$CK_W/tk.ctl.$w.got")" = "$(tk_want "$w")" ] && tk_ok=$((tk_ok+1)); done
if [ "$tk_ok" -eq 4 ]; then ok "CONTROL: all 4 tool-key worlds reach their want on the unmutated block"
else broken "CONTROL: only $tk_ok of 4 tool-key worlds reach their want on the unmutated block -- no TK mutant verdict below would be attributable"; fi

tk_mut() { # <declared worlds> <name> <count> <from> <to>
  local want="$1" name="$2" dst="$CK_W/tkmut.$2.sh" n o moved=""
  cp "$TK_P1" "$dst" || { bad "TK MUTANT $name: copy failed"; return; }
  MF="$4" MT="$5" MC="$CK_W/tkmut.$name.n" awk '
    BEGIN { f = ENVIRON["MF"]; t = ENVIRON["MT"]; n = 0 }
    { line = $0; o = ""
      while ((p = index(line, f)) > 0) { o = o substr(line, 1, p - 1) t; line = substr(line, p + length(f)); n++ }
      print o line }
    END { print n > ENVIRON["MC"] }' "$dst" > "$dst.t" && mv "$dst.t" "$dst"
  n="$(cat "$CK_W/tkmut.$name.n" 2>/dev/null)"
  [ "$n" = "$3" ] || { bad "TK MUTANT $name: anchor matched ${n:-nothing} time(s), not $3 — DID NOT APPLY"; return; }
  cmp -s "$TK_P1" "$dst" && { bad "TK MUTANT $name: the copy is unchanged"; return; }
  tk_all "$dst" "$TK_X1" "m.$name"
  for o in $TK_WORLDS; do
    [ "$(cat "$CK_W/tk.m.$name.$o.got")" = "$(tk_want "$o")" ] || moved="$moved $o"
  done
  if [ "$moved" = " $want" ]; then ok "TK MUTANT $name is KILLED by ($want) alone"
  else bad "TK MUTANT $name moved worlds '${moved# }', not ($want) alone"; fi
}
if true; then
  tk_mut "inv pos mig" inherited 1 '( IFS=:; for p in $xp:$READSET_TOOL_DIRS; do' '( IFS=:; for p in $PATH; do'
  tk_mut "inv" xpenv 1 '/usr/bin/env -u DEVELOPER_DIR -u GIT_EXEC_PATH "$g" --exec-path' '"$g" --exec-path'
  if [ "$TK_DEV_ALT" = 1 ]; then
    tk_mut "inv" devdir 1 '-u DEVELOPER_DIR -u GIT_EXEC_PATH "$g"' '-u GIT_EXEC_PATH "$g"'
  else
    printf '  SKIP  TK MUTANT devdir: no alternate developer dir on this machine, so DEVELOPER_DIR cannot move git --exec-path here\n'
  fi
  tk_mut "mig migrun" noamnesty 1 'mig = (!seed && (f in RST) && RTL[f] != "canonical")' 'mig = 0'
  tk_mut "mig" nopublish 1 '$4 == "v" || $4 == "m")' '$4 == "v")'
  tk_mut "migrun" filetoo 1 '            if (cur(k) == R[k]) continue' '            if (cur(k) == R[k] || mig) continue'
  tk_mut "mig" carrytools 1 'for (k in R) if (substr(k, 1, 1) != "/") X[k] = 1 }' 'for (k in R) X[k] = 1 }'
fi
tkm_want=$(( 1 + 6 + TK_DEV_ALT ))
if [ $((asserts - tkm_before)) -ne "$tkm_want" ]; then
  printf '  FAIL  the tool-key block ran %s assertions; it carries %s\n' "$((asserts - tkm_before))" "$tkm_want"; fails=$((fails+1))
fi

EXPECTED=$(( 14 + tkm_want ))
if [ "$asserts" -lt "$EXPECTED" ]; then
  printf '  FAIL  only %s assertions ran; this battery carries %s\n' "$asserts" "$EXPECTED"; fails=$((fails+1))
fi
echo
if [ "$fails" -eq 0 ]; then echo "readset-skip-digest-mutants: PASS ($asserts assertions)"; exit 0; fi
echo "readset-skip-digest-mutants: $fails of $asserts assertion(s) FAILED"; exit 1
