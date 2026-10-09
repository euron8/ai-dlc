#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "readset-skip-digest-mutants: FIXTURE BROKEN: core/fixtures/lib/preamble.sh is absent" >&2; exit 2; }
# Mutation battery for BL-471's committed-digest clearing, scored by the SHIPPED worlds of
# `readset-skip`: this file sources that fixture's CK_HELPERS and DG_WORLDS spans, so a mutant is
# judged by exactly the worlds the shipped fixture asserts, never by a restatement of them.
#
# WHY A SEPARATE FIXTURE. Each mutant drives every DG world (about fifty pushes); run inside
# `readset-skip` that cost lands on the suite's pole. Here it is a unit of its own.
#
# EVERY MUTANT DECLARES THE EXACT SET OF WORLDS IT MOVES. A mutant that moves one more world than it
# declares is entanglement, one fewer is a world that cannot see its subject -- both fail.
# --- THE SHARD SPLIT. Unsharded this battery was the suite's single longest directory, so it is dealt
# across five drivers: this directory is shard 'a', and `-b` to `-e` are one-line drivers that exec this
# file with `--group <x>`. A mutant's id is DERIVED from its own call line (dg_<name> for dg_mut,
# dd_<name> for dg_mut_deriver, tk_<name> for tk_mut), the partition is declared HERE, and the coverage
# join J0 compares it with the ids derived from this file's own lines, so no mutant can fall out of every
# shard and no shard is declared without a driver. EVERY shard pays the unmutated control and the
# impossible-anchor control, because a shard that skipped them could report a kill against a harness that
# never ran. The tool-key block (its own span, control and count) runs only in a shard dealt a tk_ id.
# The shard arrives as an ARGUMENT, never the environment: the scrub below unsets AI_DLC_*.
SHARDS="a b c d e"
MUTANTS_a="dg_bypass dg_nodigest_valid dg_nodigest_unmapped dg_needs_deriver"
MUTANTS_b="dg_needs_localmap dg_b1_hashleak dg_selfread dg_stale_runs"
MUTANTS_c="dg_nopublish dg_deriver_ignored dg_noexplain dg_dirvalue"
MUTANTS_d="dg_dirlocal dg_dirdash dg_listload dg_listvalue"
MUTANTS_e="dd_dirplain tk_inherited tk_xpenv tk_devdir tk_noamnesty tk_nopublish tk_filetoo tk_carrytools"
set -u
# THE ROOT IS READ BEFORE THE SCRUB: the hermetic runner exports AI_DLC_PROJECT_ROOT (its sandbox is not a
# git repository) and the scrub below would discard it. Outside the runner it is unset and git answers.
ROOT="${AI_DLC_PROJECT_ROOT:-}"
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
GROUP=a
if [ "${1:-}" = "--group" ]; then GROUP="${2:-}"; [ -n "$GROUP" ] || { echo "FIXTURE ERROR: --group needs a shard name" >&2; exit 2; }; fi
case " $SHARDS " in *" $GROUP "*) ;; *) echo "FIXTURE ERROR: unknown shard '$GROUP' (known: $SHARDS)" >&2; exit 2 ;; esac
eval "MINE=\"\${MUTANTS_$GROUP:-}\""
[ -n "$MINE" ] || { echo "FIXTURE ERROR: shard '$GROUP' has no MUTANTS_$GROUP list; a shard dealt nothing passes everything it never checked" >&2; exit 2; }
NAME="readset-skip-digest-mutants"; [ "$GROUP" = a ] || NAME="$NAME-$GROUP"
mine() { case " $MINE " in *" $1 "*) return 0 ;; esac; return 1; }

asserts=0; fails=0
ok()     { printf '  ok    %s\n' "$1"; asserts=$((asserts+1)); }
bad()    { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); asserts=$((asserts+1)); }
broken() { printf '  FAIL  %s\n' "$1" >&2; echo "$NAME: FIXTURE BROKEN" >&2; exit 2; }
echo "$NAME:"

[ -n "$ROOT" ] || ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || broken "no AI_DLC_PROJECT_ROOT and not in a git repo"
HERE="$ROOT/core/fixtures/readset-skip-digest-mutants"
HOOK="$ROOT/.githooks/pre-push"
DERIVER="$ROOT/core/scripts/derive-fixture-readsets.sh"
VICTIM="$ROOT/core/fixtures/readset-skip/run.sh"
for p in "$HOOK" "$DERIVER" "$VICTIM"; do [ -f "$p" ] || broken "cannot locate $p"; done
echo "  hook:   ${HOOK#"$ROOT"/}"

# J0, THE COVERAGE JOIN, in every shard before any world runs.
partition_ok() { # <declared ids file> <dealt ids file>
  local dup miss extra
  dup="$(sort "$2" | uniq -d | tr '\n' ' ')"
  miss="$(sort -u "$2" | comm -23 <(sort -u "$1") - | tr '\n' ' ')"
  extra="$(sort -u "$2" | comm -13 <(sort -u "$1") - | tr '\n' ' ')"
  [ -z "$dup$miss$extra" ] && return 0
  echo "dealt twice: {${dup% }} dealt to no shard: {${miss% }} dealt but not declared: {${extra% }}"
  return 1
}
JW="$(mktemp -d 2>/dev/null)" || broken "mktemp failed"
printf '%s\n' m1 m2 m3 > "$JW/pd"; printf '%s\n' m1 m2 m2 m3 > "$JW/pdup"
printf '%s\n' m1 m3 > "$JW/pmiss"; printf '%s\n' m3 m1 m2 > "$JW/pok"
if partition_ok "$JW/pd" "$JW/pdup" >/dev/null || partition_ok "$JW/pd" "$JW/pmiss" >/dev/null || ! partition_ok "$JW/pd" "$JW/pok" >/dev/null; then
  rm -rf "$JW"; broken "the coverage join's self-probe did not discriminate (duplicate, omission, exact)"
fi
SELF="$HERE/run.sh"; [ -f "$SELF" ] || { rm -rf "$JW"; broken "cannot read $SELF for the coverage join"; }
{ sed -n 's/^dg_mut \([a-z0-9_]*\) .*/dg_\1/p; s/^dg_mut_deriver \([a-z0-9_]*\) .*/dd_\1/p' "$SELF"
  sed -n 's/^ *tk_mut "[^"]*" \([a-z0-9_]*\) .*/tk_\1/p' "$SELF"; } > "$JW/declared"
for s in $SHARDS; do eval "printf '%s\n' \${MUTANTS_$s}"; done | grep . > "$JW/dealt"
ndecl="$(grep -c . "$JW/declared")" || ndecl=0
ndupdecl="$(sort "$JW/declared" | uniq -d | grep -c .)" || ndupdecl=0
{ [ "$ndecl" -gt 0 ] && [ "$ndupdecl" -eq 0 ]; } || { rm -rf "$JW"; broken "$ndecl mutant ids derived from $SELF ($ndupdecl declared twice)"; }
if ! why="$(partition_ok "$JW/declared" "$JW/dealt")"; then rm -rf "$JW"; broken "the shard partition does not cover the declared mutants exactly -- $why"; fi
for s in $SHARDS; do
  if [ "$s" = a ]; then drv="$SELF"; dp="core/fixtures/readset-skip-digest-mutants/run.sh"
  else
    drv="$ROOT/core/fixtures/readset-skip-digest-mutants-$s/run.sh"; dp="core/fixtures/readset-skip-digest-mutants-$s/run.sh"
    if [ ! -f "$drv" ] || ! grep -qF -- "--group $s" "$drv"; then rm -rf "$JW"; broken "shard '$s' is declared but $drv does not drive it"; fi
  fi
  [ "$s" = "$GROUP" ] || echo "HERMETIC-CONSUMED $dp"
done
rm -rf "$JW"
echo "  [J0] coverage join: $ndecl mutants derived from their call lines, dealt disjointly across {$SHARDS}, union exact; this shard runs {$MINE}"

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
echo "HERMETIC-CONSUMED core/fixtures/readset-skip/run.sh"
grep -q '^readset_hash_rows() {' "$DG_HASH" && grep -q '^readset_local_rows() {' "$DG_HASH" \
  && echo "HERMETIC-CONSUMED core/scripts/derive-fixture-readsets.sh"

POOL="$WORK/pool.sh"
sed -n '/# FIXTURE_POOL_BEGIN/,/# FIXTURE_POOL_END/p' "$HOOK" > "$POOL"
FX="$(sed -n 's|^FXROOT="\([A-Za-z0-9_./-]*\)/"$|\1|p' "$POOL" | sort -u)"
[ -n "$FX" ] || broken "no FXROOT in the extracted pool block"
echo "HERMETIC-CONSUMED .githooks/pre-push"

# UNMUTATED CONTROL, PRESENCE-SHAPED: every world must reach its want on the shipped block, or every
# kill below is a harness that never ran.
dg_all "$POOL" "$FX" ctl
n_ok=0
for w in $DG_WORLDS; do [ "$(cat "$CK_W/dg.ctl.$w.got")" = "$(dg_want "$w")" ] && n_ok=$((n_ok+1)); done
if [ "$n_ok" -eq 13 ]; then ok "CONTROL: all 13 committed-digest and local-map worlds reach their want on the unmutated block"
else broken "CONTROL: only $n_ok of 13 worlds reach their want on the unmutated block -- no mutant verdict below would be attributable"; fi

# The occurrence counter every mutant below applies, run alone: prints how many times <anchor> occurs in <file>.
dg_count() { MF="$2" awk 'BEGIN { f = ENVIRON["MF"]; n = 0 } { l = $0; while ((q = index(l, f)) > 0) { l = substr(l, q + length(f)); n++ } } END { print n }' "$1"; }
# IMPOSSIBLE-ANCHOR CONTROL: the counter must answer 0 for a token the pool cannot carry, and 1 for a real
# anchor in the same invocation, or a "matched 1 time" below is not a statement about the pool.
DG_Z="$(dg_count "$POOL" 'bad[f] = 1 NEVER-IN-ANY-POOL-BL480')"
DG_O="$(dg_count "$POOL" 'FILENAME == ENVIRON["RL_L"] { now[substr($1, 1, length($1) - 1)] = $2; next }')"
if [ "$DG_Z" = 0 ] && [ "$DG_O" = 1 ]; then ok "CONTROL: the anchor counter reads 0 for an impossible anchor and 1 for the listings-load line in ${HOOK#"$ROOT"/}"
else bad "CONTROL: the anchor counter read $DG_Z for an impossible anchor and $DG_O for the listings-load line, want 0 and 1"; fi

dg_mut() { # <name> "<declared worlds>" then triples <count> <from> <to>
  local name="$1" want="$2" dst="$CK_W/dgmut.$1.sh" n o moved=""; shift 2
  mine "dg_$name" || return 0
  echo "  mutating: ${HOOK#"$ROOT"/} (pool extracted to ${POOL#"$WORK"/}) for $name"
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
# w11 w12 w13 seed no committed digest, so their fixture's committed rows read as matching and clear the
# record the local rows must not: w11 and w13 skip at push 5, w12's beta clears at push 3.
dg_mut nodigest_valid "w3 w6 w11 w12 w13" 1 '(!(f in w) ? "nodigest" :' '(!(f in w) ? "match" :'
# D3: a fixture with no digest read as UNMAPPED -- its committed rows stop selecting it, so it is keyed
# on the whole tree. w3 and w6 by their seed; w1, w7 and w8 on the pushes before their digest lands; w11, w12
# and w13 carry no digest at all, so their fixture is keyed on the whole tree on every push.
dg_mut nodigest_unmapped "w1 w3 w6 w7 w8 w9 w11 w12 w13" 1 '  readset_rows "$out" rows | cut -f1 | sort -u > "$out/.mapped.all"' \
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
# D1: a validated stale fixture still runs, as before this change. w13's alpha clears on local rows at push 3.
dg_mut stale_runs "w1 w4 w7 w10 w13" 1 'else if (st == "stale" && !(f in LOC) && !((f in DECL) && RK[f] != "")) {' 'else if (st == "stale") {'
# D1: the cleared record is not published, so it reads stale again on the next push (w13's s3 included).
dg_mut nopublish "w1 w4 w7 w10 w13" 1 '($5 == "seeded" || $4 == "v" || $4 == "m" || $4 == "b")' '($5 == "seeded" || $4 == "m" || $4 == "b")'
# BL-471 "deriver sha ignored": the LOCAL validator stops comparing the deriver sha.
dg_mut deriver_ignored "w6" 1 '$2 == "#deriver" { dok[$1] = ($3 == dsha); next }' '$2 == "#deriver" { dok[$1] = 1; next }'
# F471d: the per-stale explanation line gone.
dg_mut noexplain "w2 w3" 1 '          for (r in l) print "   ..    stale, "' '          for (r in l) if (0) print "   ..    stale, "'
# dirvalue: a directory row's digest value is `-` again (the listing never substituted), so w9's grown
# src/d is invisible to the digest and the seed-time digest clears a record it must not. w10 too: its local
# rows are seeded through dg_local_rows, which sources this pool's readset_dir_values, so src/d is seeded `-`
# and refused. w11 cannot see it -- a `-` row for a directory is refused, which is w11's want.
dg_mut dirvalue "w9 w10" 1 '$3 == "-" && (($2 "/") in l) {' '$3 == "-" && 0 && (($2 "/") in l) {'
# dirlocal: the local validator's `-` branch gone, so a `-` row falls to the equality test and is refused
# whatever exists. w13's ABSENT name (src/ghost.sh, recorded `-`) can then never clear alpha. w12's `-` row
# is refused under the fix too, so w12 cannot see this mutant; w10's rows carry no `-` at all.
dg_mut dirlocal "w13" 1 'if ($3 == "-") { if ($2 in now) bad[f] = 1 }' 'if (0) { if ($2 in now) bad[f] = 1 }'
# dirdash: a `-` row accepted UNCONDITIONALLY -- the hole BL-480 closed. w12's `-` row for the directory src/d
# clears beta, and w13's `-` row for a name that is now a FILE clears alpha at push 4, so push 5 skips it.
dg_mut dirdash "w12 w13" 1 'if ($3 == "-") { if ($2 in now) bad[f] = 1 }' 'if ($3 == "-") { if (0) bad[f] = 1 }'
# listload: the local validator's listings never loaded into now[]. One line owns both observables: w10's
# `#listing:` row has nothing to equal and is refused, and w12's `-` row for src/d finds no such name and
# is accepted.
dg_mut listload "w10 w12" 1 'FILENAME == ENVIRON["RL_L"] { now[substr($1, 1, length($1) - 1)] = $2; next }' 'FILENAME == ENVIRON["RL_L"] { if (0) now[substr($1, 1, length($1) - 1)] = $2; next }'
# listvalue: a recorded value accepted whenever its name exists, never compared. w11's src/d grew, its
# listing moved, and the seed-time row still clears beta, so push 5 skips it over an edit to the new file.
dg_mut listvalue "w11" 1 'else if (!(($2 in now) && now[$2] == $3)) bad[f] = 1' 'else if (!($2 in now)) bad[f] = 1'

# ------------------------------------------------------------- deriver-side mutants ----
# dg_mut_deriver: the same scoring on a mutated copy of the deriver's READSET_LOCALMAP span, which the DG
# worlds source through $DG_HASH -- dg_local_rows calls its readset_local_rows. dg_digest sources the span
# too but calls only readset_hash_rows, so a mutant of readset_local_rows reaches the local-map worlds alone.
dg_mut_deriver() { # <name> "<declared worlds>" <count> <from> <to>
  local name="$1" want="$2" dst="$CK_W/dgmutd.$1.sh" n o moved="" keep="$DG_HASH"
  mine "dd_$name" || return 0
  echo "  mutating: ${DERIVER#"$ROOT"/} READSET_LOCALMAP span (extracted to ${DG_HASH#"$WORK"/}) for $name"
  cp "$DG_HASH" "$dst" || { bad "DERIVER MUTANT $name: copy failed"; return; }
  MF="$4" MT="$5" MC="$CK_W/dgmutd.$name.n" awk '
    BEGIN { f = ENVIRON["MF"]; t = ENVIRON["MT"]; n = 0 }
    { line = $0; o = ""
      while ((q = index(line, f)) > 0) { o = o substr(line, 1, q - 1) t; line = substr(line, q + length(f)); n++ }
      print o line }
    END { print n > ENVIRON["MC"] }' "$DG_HASH" > "$dst" || { bad "DERIVER MUTANT $name: awk failed -- DID NOT APPLY"; return; }
  n="$(cat "$CK_W/dgmutd.$name.n" 2>/dev/null)"
  [ "$n" = "$3" ] || { bad "DERIVER MUTANT $name: anchor matched ${n:-nothing} time(s), not $3 -- DID NOT APPLY"; return; }
  cmp -s "$DG_HASH" "$dst" && { bad "DERIVER MUTANT $name: the copy is unchanged -- DID NOT APPLY"; return; }
  DG_HASH="$dst"; dg_all "$POOL" "$FX" "md.$name"; DG_HASH="$keep"
  for o in $DG_WORLDS; do
    [ "$(cat "$CK_W/dg.md.$name.$o.got")" = "$(dg_want "$o")" ] || moved="$moved $o"
  done
  if [ "${moved# }" = "$want" ]; then ok "DERIVER MUTANT $name is KILLED by exactly ($want)"
  else bad "DERIVER MUTANT $name moved '${moved# }', declared '$want'"; fi
}
# dirplain: --local-map records every directory as `-` again (readset_dir_values never consulted). w10's
# beta then carries a `-` row for the directory src/d and cannot clear. w11 wants beta refused, and a `-`
# row for a directory IS refused, so w11 cannot see this mutant -- listvalue is its killer.
dg_mut_deriver dirplain "w10" 1 'if [ "$(type -t readset_dir_values 2>/dev/null)" = function ]' 'if false && [ "$(type -t readset_dir_values 2>/dev/null)" = function ]'

# ------------------------------------------------------------------ tool-key mutants ----
# The mutants of readset-skip's tool-key worlds (inv pos mig migrun), moved here so their re-runs of
# those four worlds are a unit of this battery rather than weight on the suite's pole. This block is
# self-contained: its own span, control and count. The worlds are the SHIPPED ones, sourced from
# readset-skip's TK_WORLDS span on top of the CK_HELPERS already sourced above.
TK_MINE=""; for _m in $MINE; do case "$_m" in tk_*) TK_MINE="$TK_MINE $_m" ;; esac; done
tkm_before=$asserts; tkm_want=0
if [ -n "$TK_MINE" ]; then
TKSPAN="$WORK/tkspan.sh"
sed -n '/^# TK_WORLDS_BEGIN/,/^# TK_WORLDS_END$/p' "$VICTIM" > "$TKSPAN"
grep -q '^tk_all() ' "$TKSPAN" && grep -q '^TK_WANT_migrun=' "$TKSPAN" \
  || broken "readset-skip's TK_WORLDS span is missing a function this battery drives"
# shellcheck disable=SC1090
. "$TKSPAN"
TK_P1="$POOL"; TK_X1="$FX"
# UNMUTATED CONTROL, PRESENCE-SHAPED: all four tool-key worlds reach their want on the shipped block.
tk_all "$POOL" "$FX" ctl
tk_ok=0
for w in $TK_WORLDS; do [ "$(cat "$CK_W/tk.ctl.$w.got")" = "$(tk_want "$w")" ] && tk_ok=$((tk_ok+1)); done
if [ "$tk_ok" -eq 4 ]; then ok "CONTROL: all 4 tool-key worlds reach their want on the unmutated block"
else broken "CONTROL: only $tk_ok of 4 tool-key worlds reach their want on the unmutated block -- no TK mutant verdict below would be attributable"; fi

tk_mut() { # <declared worlds> <name> <count> <from> <to>
  local want="$1" name="$2" dst="$CK_W/tkmut.$2.sh" n o moved=""
  mine "tk_$name" || return 0
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
  tk_mut "mig" nopublish 1 '$4 == "v" || $4 == "m" || $4 == "b")' '$4 == "v" || $4 == "b")'
  tk_mut "migrun" filetoo 1 '            if (cur(k) == R[k]) continue' '            if (cur(k) == R[k] || mig) continue'
  tk_mut "mig" carrytools 1 'for (k in R) if (substr(k, 1, 1) != "/") X[k] = 1 }' 'for (k in R) X[k] = 1 }'
fi
tkn=0; for _m in $TK_MINE; do tkn=$((tkn+1)); done
tkm_want=$(( 1 + tkn ))
case " $TK_MINE " in *" tk_devdir "*) [ "$TK_DEV_ALT" = 1 ] || tkm_want=$((tkm_want-1)) ;; esac
if [ $((asserts - tkm_before)) -ne "$tkm_want" ]; then
  printf '  FAIL  the tool-key block ran %s assertions; it carries %s\n' "$((asserts - tkm_before))" "$tkm_want"; fails=$((fails+1))
fi
fi

dgn=0; for _m in $MINE; do case "$_m" in dg_*|dd_*) dgn=$((dgn+1)) ;; esac; done
EXPECTED=$(( 2 + dgn + tkm_want ))
if [ "$asserts" -lt "$EXPECTED" ]; then
  printf '  FAIL  only %s assertions ran; this battery carries %s\n' "$asserts" "$EXPECTED"; fails=$((fails+1))
fi
echo
if [ "$fails" -eq 0 ]; then echo "$NAME: PASS ($asserts assertions)"; exit 0; fi
echo "$NAME: $fails of $asserts assertion(s) FAILED"; exit 1
