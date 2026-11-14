#!/usr/bin/env bash
# finding-grammar-binding/run.sh -- THE ONE FINDING GRAMMAR, BYTE-BOUND (BL-958; merge-adversarial-shards.sh header,
# FINDING GRAMMAR / THE FINDING ID). Three programs read an adversarial finding heading: the merge's parse_shard,
# join-remediator-shards.sh src_ids and validate-adversarial-convergence.sh j3_keys (J3). When they disagree, the merge
# counts a finding J3 cannot key, and the gate can never close it. This fixture holds the three copies to one text.
#
# Usage: run.sh [--matrix]   (--matrix also prints the MATRIX row of the one mutant)
# Exit:  0 = every assertion holds, 1 = the binding regressed, 2 = fixture broken.
#
# ARMS. BB0 self-probes FIRST, in a mktemp tree, both directions. BB1 binds the ID RULE, the FENCE RULE, sev() and the
# `## Findings` match across the three functions. BB2 counts every fence-rule copy in core/scripts/*.sh against an
# enumeration, so a fourth hand-copied grammar in a NEW file fails, and refuses a scanned set under a floor, so a sandbox
# that copies only the named carriers cannot pass it by counting four files. BIND3 (with its self-probes BIND0,
# BINDm-third, BINDQ3, BINDQ4, BINDF-BINDF5) counts every carrier of the join's SAME and DOUBLE-WRITE refusal phrases
# across core/scripts/*.sh and core/hooks/*.sh, so a third copy in any script or hook fails; its header is above it.
#
# WHY A FIXTURE OF ITS OWN. These arms were first written into adversarial-shard-merge, the suite's slowest fixture.
# BB2 reads the whole core/scripts/ directory, so that fixture re-ran on every edit to any core script. The binding
# reads only text and runs no program, so it lives here, where a core/scripts edit costs a few awk passes. BIND3 came
# from remediator-shard-join for the same reason (BL-967): it reads the whole of core/scripts/ and core/hooks/, which
# that fixture does not declare, so in the sandbox it counted only the declared files.
#
# MUTANT-MATRIX BINDm-third decides=BIND3 twins=- why=the third-carrier world is read by BIND3 alone; BIND0 is the unmutated control over the same tree
# MUTANT-MATRIX-REMEASURE bash core/fixtures/finding-grammar-binding/run.sh --matrix
#
# `.dist-only`: the reason is in the marker beside this file.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

. "$(cd "$(dirname "$0")/../lib" && pwd)/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }
MATRIX=0
[ "${1:-}" = --matrix ] && MATRIX=1
N_MROWS=0
mrow() { [ "$MATRIX" = 1 ] || return 0; N_MROWS=$((N_MROWS + 1)); echo "  MATRIX $*"; }

echo "finding-grammar-binding"

# The subject, found by walking UP from this file's directory for core/scripts/ -- never by counting `..`.
HERE="$(cd "$(dirname "$0")" && pwd)"
MUT_LIB="$(cd "$HERE/../lib" 2>/dev/null && pwd)/mutant.sh"
[ -f "$MUT_LIB" ] || { echo "FIXTURE BROKEN: lib/mutant.sh not found beside $HERE; nothing was asserted" >&2; exit 2; }
# shellcheck source=/dev/null
. "$MUT_LIB"
MERGE=""
_d="$HERE"
while [ -n "$_d" ] && [ "$_d" != "/" ]; do
  [ -f "$_d/core/scripts/merge-adversarial-shards.sh" ] && { MERGE="$_d/core/scripts/merge-adversarial-shards.sh"; break; }
  _d="$(dirname "$_d")"
done
[ -n "$MERGE" ] || { echo "FIXTURE BROKEN: core/scripts/merge-adversarial-shards.sh not found above $HERE; nothing was asserted" >&2; exit 2; }
SRCDIR="$(cd "$(dirname "$MERGE")" && pwd)"
JOIN="$SRCDIR/join-remediator-shards.sh"
CONV="$SRCDIR/validate-adversarial-convergence.sh"
for _f in "$JOIN" "$CONV" "$SRCDIR/merge-review-shards.sh"; do
  [ -f "$_f" ] || { echo "FIXTURE BROKEN: $_f is not beside the merge; nothing was asserted" >&2; exit 2; }
done
WORK="$(mktemp -d)" || { echo "FIXTURE BROKEN: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

# Each carrier holds the ID RULE and the FENCE RULE, located INSIDE the named function by content, exactly once each,
# and compared with leading whitespace stripped: all three copies of each rule byte-equal. The ID RULE is src_ids'
# derivation -- the 4 lines opening `s = $0; sub(/^#+[ \t]+/, "", s);`, then the closing line after the next one; the
# line between is each site's own print, and the selector line above is each site's own, so neither can be a copy.
# The FENCE RULE is the 3 lines opening `fence && $0 ~ /^[ \t]*(```+|~~~+)[ \t]*$/ {`. parse_shard and j3_keys (not
# src_ids, which reads every heading level) also share sev() -- the 9 lines opening `function sev(h,` -- and each
# carries the merge's `## Findings` match `/^## Findings[ \t]*$/`. They share the SHARD MAP too -- the 4 lines opening
# `/^## Shard: / { h = substr($0, 11); sh = "?"; fnd = 0`, the shard file J3 keys the findings after a `## Shard:`
# heading under, which the merge reads to refuse a shard whose own such heading names another file (BL-958, D-1); the
# line after them is each site's own (J3's `next`, the merge's `S` print). A site not found is a FAIL, never a skip.
# bind_check <merge> <join> <validator> -> BB_MSG, rc 0 iff bound.
BB_FN="parse_shard src_ids j3_keys"
bind_check() {
  BB_MSG="$(awk -v fns="$BB_FN" '
    BEGIN { split(fns, F, " ") }
    FNR == 1 { fi++; on = 0 }
    $0 == F[fi] "() {" { on = 1; seen[fi] = 1; next }
    on && /^}/ { on = 0; next }
    !on { next }
    { l = $0; sub(/^[ \t]+/, "", l) }
    index(l, "s = $0; sub(/^#+[ \\t]+/, \"\", s);") == 1 { ni[fi]++; idl = 6 }
    index(l, "fence && $0 ~ /^[ \\t]*(```+|~~~+)[ \\t]*$/ {") == 1 { nf[fi]++; fdl = 3 }
    index(l, "function sev(h,") == 1 { ns[fi]++; sdl = 9 }
    index(l, "/^## Shard: / { h = substr($0, 11); sh = \"?\"; fnd = 0") == 1 { nm[fi]++; mdl = 4 }
    idl > 0 { if (idl != 2) ID[fi] = ID[fi] l "\n"; idl-- }
    fdl > 0 { FE[fi] = FE[fi] l "\n"; fdl-- }
    sdl > 0 { SV[fi] = SV[fi] l "\n"; sdl-- }
    mdl > 0 { SM[fi] = SM[fi] l "\n"; mdl-- }
    index(l, "/^## Findings[ \\t]*$/") > 0 { fm[fi]++ }
    END {
      for (i = 1; i <= 3; i++) {
        if (!seen[i]) { print "no function " F[i] "() in " ARGV[i]; bad = 1; continue }
        if (ni[i] != 1) { print F[i] ": the ID RULE site is found " ni[i] + 0 " time(s), not once"; bad = 1 }
        if (nf[i] != 1) { print F[i] ": the FENCE RULE site is found " nf[i] + 0 " time(s), not once"; bad = 1 }
        if (i != 2 && ns[i] != 1) { print F[i] ": the sev() site is found " ns[i] + 0 " time(s), not once"; bad = 1 }
        if (i != 2 && nm[i] != 1) { print F[i] ": the SHARD MAP site is found " nm[i] + 0 " time(s), not once"; bad = 1 }
      }
      if (!bad) {
        if (ID[2] != ID[1]) { print "src_ids ID RULE differs from parse_shard"; bad = 1 }
        if (ID[3] != ID[1]) { print "j3_keys ID RULE differs from parse_shard"; bad = 1 }
        if (FE[2] != FE[1]) { print "src_ids FENCE RULE differs from parse_shard"; bad = 1 }
        if (FE[3] != FE[1]) { print "j3_keys FENCE RULE differs from parse_shard"; bad = 1 }
        if (SV[3] != SV[1]) { print "j3_keys sev() differs from parse_shard"; bad = 1 }
        if (SM[3] != SM[1]) { print "j3_keys SHARD MAP differs from parse_shard"; bad = 1 }
      }
      if (!fm[1]) { print "parse_shard carries no /^## Findings[ \\t]*$/ match"; bad = 1 }
      if (!fm[3]) { print "j3_keys carries no /^## Findings[ \\t]*$/ match"; bad = 1 }
      if (!bad) print "BOUND"
    }' "$1" "$2" "$3" 2>&1)"
  [ "$BB_MSG" = BOUND ]
}

# THE FENCE COPIES: every core script line carrying the fence closer `length(frr) >= fln`, counted per file against
# this enumeration -- a NEW copy anywhere (or one dropped) fails, so a fourth hand-copied grammar cannot appear
# unseen. merge-adversarial-shards.sh 2 (parse_shard, same_set), join-remediator-shards.sh 6 (src_ids and five
# readers), merge-review-shards.sh 7, validate-adversarial-convergence.sh 2 (:3113 and j3_keys). LIMIT: it keys on that
# text, so a copy whose variables are renamed escapes it.
# THE FLOOR. The census is only as wide as the directory it is handed, and under hermetic-run.sh that directory holds
# what inputs.decl copies: declare the four carriers file by file and it scans four files, every count matches, and it
# passes having looked nowhere a new copy could appear. So the scanned set must hold at least FC_FLOOR files. Measured at
# authoring: `ls core/scripts/*.sh | wc -l` and `git ls-files 'core/scripts/*.sh' | wc -l` both 73. The floor sits well
# BELOW that so deleting a script never reds this fixture, and well ABOVE any file-by-file declaration (the largest in
# this tree names about a dozen scripts), so a narrowed sandbox cannot reach it.
# fence_census <dir> <floor> -> FC_MSG, rc 0 iff every count matches, the scanned set holds the merge and at least <floor> files.
FC_WANT="join-remediator-shards.sh=6 merge-adversarial-shards.sh=2 merge-review-shards.sh=7 validate-adversarial-convergence.sh=2"
FC_FLOOR=40
fence_census() {
  FC_MSG="$(awk -v want="$FC_WANT" -v floor="$2" '
    BEGIN { n = split(want, W, " "); for (i = 1; i <= n; i++) { split(W[i], kv, "="); E[kv[1]] = kv[2] } }
    FNR == 1 { b = FILENAME; sub(/.*\//, "", b); scanned[b] = 1; ns++ }
    index($0, "length(frr) >= fln") > 0 { b2 = FILENAME; sub(/.*\//, "", b2); C[b2]++ }
    END {
      if (!("merge-adversarial-shards.sh" in scanned)) { print "the scanned set (" ns + 0 " files) lacks merge-adversarial-shards.sh"; bad = 1 }
      if (ns + 0 < floor + 0) { print "the scanned set holds " ns + 0 " files, under the floor " floor " -- the directory is narrowed, so a new copy elsewhere would go unseen"; bad = 1 }
      for (k in E) if (C[k] + 0 != E[k] + 0) { print k " carries " C[k] + 0 " fence copies, the enumeration " E[k]; bad = 1 }
      for (k in C) if (!(k in E)) { print k " carries " C[k] " fence copies, absent from the enumeration"; bad = 1 }
      if (!bad) print "COUNTED " ns
    }' "$1"/*.sh 2>&1)"
  case "$FC_MSG" in "COUNTED "*) return 0 ;; esac; return 1
}

# BB0: self-probes FIRST, in a mktemp tree, both directions. A validator stand-in whose j3_keys IS the merge's
# parse_shard body binds (re-indented too); the same with the bracket strip dropped, with its fence lines dropped, with a
# reordered sev() and with no j3_keys at all each fail naming the site. A census dir holding the enumerated counts
# passes; one more copy in a new file fails; the four carriers alone fail the real floor; and the same four padded with
# non-carrier files up to the floor pass it.
bbp="$WORK/bb"; mkdir -p "$bbp"; bb_ok=1
awk '$0 == "parse_shard() {" { on = 1; print "j3_keys() {"; next } on { print } on && /^}/ { exit }' "$MERGE" > "$bbp/v.ok"
sed 's/^    /		/' "$bbp/v.ok" > "$bbp/v.indent"
awk '{ i = index($0, "gsub(/[][]/, \"\", s); "); if (i) $0 = substr($0, 1, i - 1) substr($0, i + 21) } { print }' "$bbp/v.ok" > "$bbp/v.nobr"
grep -vF 'frr' "$bbp/v.ok" | grep -vxF '    fence { next }' > "$bbp/v.nofence"
printf 'x() {\n  :\n}\n' > "$bbp/v.nofn"
sed 's/split("CRITICAL MAJOR MINOR NIT"/split("MAJOR CRITICAL MINOR NIT"/' "$bbp/v.ok" > "$bbp/v.sev"
awk '{ i = index($0, "sh = (a[2] + 0) \".md\""); if (i) $0 = substr($0, 1, i - 1) "sh = a[2] \".md\"" substr($0, i + 21) } { print }' "$bbp/v.ok" > "$bbp/v.ord"
grep -vF '/^## Shard: / {' "$bbp/v.ok" > "$bbp/v.nomap"
[ -s "$bbp/v.ok" ] || { bb_ok=0; bad "BB0: FIXTURE BROKEN -- no parse_shard() body was extracted from $MERGE"; }
cmp -s "$bbp/v.ok" "$bbp/v.indent" && { bb_ok=0; bad "BB0: FIXTURE BROKEN -- the re-indent probe edit matched nothing"; }
cmp -s "$bbp/v.ok" "$bbp/v.sev" && { bb_ok=0; bad "BB0: FIXTURE BROKEN -- the sev() probe edit matched nothing"; }
cmp -s "$bbp/v.ok" "$bbp/v.nobr" && { bb_ok=0; bad "BB0: FIXTURE BROKEN -- the bracket-strip probe edit matched nothing"; }
cmp -s "$bbp/v.ok" "$bbp/v.nofence" && { bb_ok=0; bad "BB0: FIXTURE BROKEN -- the fence probe edit matched nothing"; }
cmp -s "$bbp/v.ok" "$bbp/v.ord" && { bb_ok=0; bad "BB0: FIXTURE BROKEN -- the shard-ordinal probe edit matched nothing"; }
cmp -s "$bbp/v.ok" "$bbp/v.nomap" && { bb_ok=0; bad "BB0: FIXTURE BROKEN -- the shard-map probe edit matched nothing"; }
if bind_check "$MERGE" "$JOIN" "$bbp/v.ok" && bind_check "$MERGE" "$JOIN" "$bbp/v.indent"; then :; else bb_ok=0; bad "BB0: the canonical stand-in did not bind: $BB_MSG"; fi
bind_check "$MERGE" "$JOIN" "$bbp/v.nobr" && { bb_ok=0; bad "BB0: a j3_keys without the bracket strip BOUND"; }
case "$BB_MSG" in *"j3_keys ID RULE differs from parse_shard"*) ;; *) bb_ok=0; bad "BB0: the bracket-strip probe did not name j3_keys's ID RULE: $BB_MSG" ;; esac
bind_check "$MERGE" "$JOIN" "$bbp/v.nofence" && { bb_ok=0; bad "BB0: a j3_keys without the fence lines BOUND"; }
case "$BB_MSG" in *"j3_keys: the FENCE RULE site is found 0 time(s)"*) ;; *) bb_ok=0; bad "BB0: the fence probe did not name the missing site: $BB_MSG" ;; esac
bind_check "$MERGE" "$JOIN" "$bbp/v.sev" && { bb_ok=0; bad "BB0: a j3_keys with a reordered sev() BOUND"; }
case "$BB_MSG" in *"j3_keys sev() differs from parse_shard"*) ;; *) bb_ok=0; bad "BB0: the sev() probe did not name j3_keys's sev(): $BB_MSG" ;; esac
bind_check "$MERGE" "$JOIN" "$bbp/v.ord" && { bb_ok=0; bad "BB0: a j3_keys reading the shard ordinal raw BOUND"; }
case "$BB_MSG" in *"j3_keys SHARD MAP differs from parse_shard"*) ;; *) bb_ok=0; bad "BB0: the shard-ordinal probe did not name j3_keys's SHARD MAP: $BB_MSG" ;; esac
bind_check "$MERGE" "$JOIN" "$bbp/v.nomap" && { bb_ok=0; bad "BB0: a j3_keys with no shard map BOUND"; }
case "$BB_MSG" in *"j3_keys: the SHARD MAP site is found 0 time(s)"*) ;; *) bb_ok=0; bad "BB0: the shard-map probe did not name the missing site: $BB_MSG" ;; esac
bind_check "$MERGE" "$JOIN" "$bbp/v.nofn" && { bb_ok=0; bad "BB0: a validator with no j3_keys BOUND"; }
case "$BB_MSG" in *"no function j3_keys()"*) ;; *) bb_ok=0; bad "BB0: the no-function probe did not say so: $BB_MSG" ;; esac
mkdir -p "$bbp/sd"; cp "$MERGE" "$JOIN" "$SRCDIR/merge-review-shards.sh" "$bbp/sd/" \
  && printf 'length(frr) >= fln\nlength(frr) >= fln\n' > "$bbp/sd/validate-adversarial-convergence.sh"
fence_census "$bbp/sd" 4 || { bb_ok=0; bad "BB0: the enumerated census did not pass: $FC_MSG"; }
printf 'length(frr) >= fln\n' > "$bbp/sd/zz-new.sh"
fence_census "$bbp/sd" 4 && { bb_ok=0; bad "BB0: a fourth-file fence copy was not counted"; }
case "$FC_MSG" in *"zz-new.sh carries 1 fence copies, absent from the enumeration"*) ;; *) bb_ok=0; bad "BB0: the census probe did not name the new copy: $FC_MSG" ;; esac
rm -f "$bbp/sd/zz-new.sh"
fence_census "$bbp/sd" "$FC_FLOOR" && { bb_ok=0; bad "BB0: the four carriers alone passed the floor $FC_FLOOR"; }
case "$FC_MSG" in *"the scanned set holds 4 files, under the floor $FC_FLOOR"*) ;; *) bb_ok=0; bad "BB0: the narrowed census did not name the floor: $FC_MSG" ;; esac
_i=4; while [ "$_i" -lt "$FC_FLOOR" ]; do printf 'echo pad\n' > "$bbp/sd/pad-$_i.sh"; _i=$((_i + 1)); done
fence_census "$bbp/sd" "$FC_FLOOR" || { bb_ok=0; bad "BB0: the carriers padded to the floor ($FC_FLOOR files) did not pass: $FC_MSG"; }
[ "$FC_MSG" = "COUNTED $FC_FLOOR" ] || { bb_ok=0; bad "BB0: the padded census counted '$FC_MSG', not COUNTED $FC_FLOOR"; }
[ "$bb_ok" = 1 ] && ok "BB0: self-probes -- the canonical j3_keys stand-in binds (re-indented too); no bracket strip, no fence lines, a reordered sev(), a shard ordinal read raw, no shard map, no j3_keys each fail naming the site; a new fence copy in a new file fails the census; the four carriers alone fail the floor $FC_FLOOR and pass it padded to $FC_FLOOR files"

echo "HERMETIC-CONSUMED core/scripts/merge-adversarial-shards.sh"
echo "HERMETIC-CONSUMED core/scripts/join-remediator-shards.sh"
echo "HERMETIC-CONSUMED core/scripts/validate-adversarial-convergence.sh"
if bind_check "$MERGE" "$JOIN" "$CONV"; then ok "BB1: parse_shard, src_ids and j3_keys carry byte-identical ID RULE and FENCE RULE copies (indentation aside), parse_shard and j3_keys one sev() and one SHARD MAP, and both readers the merge's ## Findings match"
else bad "BB1: the finding grammar is not one text across the merge, the join and J3: $(printf '%s' "$BB_MSG" | tr '\n' ';')"; fi
echo "HERMETIC-CONSUMED core/scripts/"
if fence_census "$SRCDIR" "$FC_FLOOR"; then ok "BB2: the fence-rule copies in $(basename "$SRCDIR")/ are exactly the enumerated ones ($FC_MSG files scanned, floor $FC_FLOOR)"
else bad "BB2: the fence-rule copies drifted from the enumeration, or the scanned set is narrowed: $(printf '%s' "$FC_MSG" | tr '\n' ';')"; fi

# ------------------------------------------------------------------------- BIND3, the refusal carrier count
# BIND3: no THIRD copy of the join's SAME or DOUBLE-WRITE refusal. remediator-shard-join's unit-bind.sh owns BIND1 and
# BIND2 ("exactly one per subject": its extraction refuses zero or two, and the join's text is held to the merge's);
# BIND3 owns "at most one per subject and zero in every other file". Together that is exactly one per script.
# Moved here from that fixture (BL-967): its inputs.decl names single files, so inside hermetic-run.sh's sandbox the
# glob saw only those, and a third carrier in any undeclared script or hook passed. This fixture declares both whole
# directories, `!core/scripts/` and `!core/hooks/`.
# Corpus: every `*.sh` in the merge's own scripts dir ($SRCDIR) and the hooks dir beside it under the same root
# ($HOOKDIR). FIXTURES ARE EXCLUDED: a fixture pins these strings on purpose, and the two globs are non-recursive, so
# a fixtures path is unreachable by construction (no fixture-dir near-miss is probed: it would stay quiet whatever
# the code does). Counted: non-comment LINES (first non-blank byte not `#`) carrying `both before the re-run start
# and at` or `a writer kept writing after another writer's first row`.
# FLOOR, every clause a refusal and never a silent pass: an empty glob refuses; both subject basenames must be in the
# scanned set; the scripts dir must hold at least FC_FLOOR files and the hooks dir at least HK_FLOOR, each counted
# on its own, so a sandbox that drops one directory cannot pass on the size of the other; and the number of files
# awk actually opened must equal the list. The floors are COMMITTED CONSTANTS, never a count of the listing being
# judged. HK_FLOOR measured at authoring: `ls core/hooks/*.sh | wc -l` and `git ls-files 'core/hooks/*.sh' | wc -l`
# both 29; the largest file-by-file declaration of core/hooks/ in any core/fixtures/*/inputs.decl names 6
# (pause-hook-origin). 15 sits below 29, so deleting a hook never reds this fixture, and above 6, so a narrowed
# sandbox cannot reach it.
# LIMIT: a paraphrase of either phrase evades the count.
#
# SELF-PROBES run BEFORE the real check, in mktemp trees holding copies of the merge and the join, never the real
# directories. BIND0 asserts the unmutated tree passes over exactly its 2 files (the base the kill is gated on).
#   BINDm-third  a third carrier seeded as a scripts-dir x.sh                     -> BIND3 (KILLED)
#   BINDQ3       both phrases on a `#` comment line of a scripts-dir x.sh         -> quiet, scanned (3 files)
#   BINDQ4       an EMPTY .sh in the hooks dir, counted (an empty file has no FNR==1 record) -> quiet (3 files)
#   BINDF        an empty scripts and hooks dir                                  -> REFUSES
#   BINDF2       an unopenable listed .sh (chmod 000, non-root)                   -> REFUSES (awk read 2 of 3)
#   BINDF3       scripts padded to FC_FLOOR, hooks holding 2                      -> REFUSES naming the hooks floor
#   BINDF4       hooks padded to HK_FLOOR, scripts holding the 2 subjects         -> REFUSES naming the scripts floor
#   BINDF5       both padded to their floors                                      -> PASS over FC_FLOOR + HK_FLOOR files
HK_FLOOR=15
BD_P1='both before the re-run start and at'
BD_P2="a writer kept writing after another writer's first row"
HOOKDIR="$(dirname "$SRCDIR")/hooks"
MB="$(basename "$MERGE")"; JB="$(basename "$JOIN")"

# bd_carriers <scripts dir> <hooks dir> <merge basename> <join basename> <scripts floor> <hooks floor> -- BIND3 and
# its floor. Prints one `PASS BIND3 over <n> file(s)` or `FAIL BIND3 <why>` line.
bd_carriers() {
  local _f _list="" _nl=0 _ns=0 _nh=0 _hm=0 _hj=0
  for _f in "$1"/*.sh; do
    [ -f "$_f" ] || continue
    _list="$_list $_f"; _nl=$((_nl + 1)); _ns=$((_ns + 1))
    case "$(basename "$_f")" in "$3") _hm=1 ;; "$4") _hj=1 ;; esac
  done
  for _f in "$2"/*.sh; do
    [ -f "$_f" ] || continue
    _list="$_list $_f"; _nl=$((_nl + 1)); _nh=$((_nh + 1))
  done
  if [ "$_nl" -eq 0 ]; then echo "FAIL BIND3 REFUSED: the corpus glob over $1 and $2 matched no file"; return 0; fi
  if [ "$_hm" = 0 ] || [ "$_hj" = 0 ]; then echo "FAIL BIND3 REFUSED: the scanned set lacks a subject (merge=$_hm join=$_hj) over $_nl file(s)"; return 0; fi
  if [ "$_ns" -lt "$5" ]; then echo "FAIL BIND3 REFUSED: the scripts dir holds $_ns .sh file(s), under the floor $5 -- the directory is narrowed, so a third carrier elsewhere would go unseen"; return 0; fi
  if [ "$_nh" -lt "$6" ]; then echo "FAIL BIND3 REFUSED: the hooks dir holds $_nh .sh file(s), under the floor $6 -- the directory is narrowed, so a third carrier elsewhere would go unseen"; return 0; fi
  # shellcheck disable=SC2086
  awk -v P1="$BD_P1" -v P2="$BD_P2" -v M="$3" -v J="$4" -v NL="$_nl" '
    # The floor opens each listed file in BEGIN: getline returns -1 for an unopenable file and 0 for an empty one,
    # so an empty readable file counts as read (it has no FNR==1 record) and an unopenable one still refuses.
    BEGIN { for (i = 1; i < ARGC; i++) { if ((getline line < ARGV[i]) >= 0) nread++; close(ARGV[i]) }
      if (nread != NL) { print "FAIL BIND3 REFUSED: awk read " nread + 0 " of the " NL " listed file(s)"; refused = 1; exit 0 } }
    /^[[:space:]]*#/ { next }
    { b = FILENAME; sub(/.*\//, "", b)
      if (index($0, P1) > 0) c1[b]++
      if (index($0, P2) > 0) c2[b]++ }
    END {
      if (refused) exit 0
      bad = ""
      for (b in c1) if ((b == M || b == J) ? c1[b] > 1 : c1[b] > 0) bad = bad " " b " carries the SAME phrase on " c1[b] " line(s);"
      for (b in c2) if ((b == M || b == J) ? c2[b] > 1 : c2[b] > 0) bad = bad " " b " carries the DOUBLE-WRITE phrase on " c2[b] " line(s);"
      if (bad != "") print "FAIL BIND3" bad; else print "PASS BIND3 over " nread " file(s)"
    }' $_list
}
BD_OUT="$WORK/bind.out"
bd_tree() { # <name> -- a fresh probe tree holding copies of the merge and the join; prints its root
  local _t
  _t="$(mktemp -d "$WORK/bind-$1.XXXXXX")" || return 1
  mkdir -p "$_t/core/scripts" "$_t/core/hooks" || return 1
  cp "$MERGE" "$JOIN" "$_t/core/scripts/" || return 1
  printf '%s\n' "$_t"
}
bd_pad() { # <dir> <from> <to> -- non-carrier pad files numbered <from>..<to>-1
  local _i="$2"
  while [ "$_i" -lt "$3" ]; do printf 'echo pad\n' > "$1/pad-$_i.sh" || return 1; _i=$((_i + 1)); done
}
# bd_run <tree> [<scripts floor> <hooks floor>] -- BIND3 over the tree into $BD_OUT; BD_FAILED is BIND3 or empty.
bd_run() {
  bd_carriers "$1/core/scripts" "$1/core/hooks" "$MB" "$JB" "${2:-0}" "${3:-0}" > "$BD_OUT"
  BD_FAILED="$(awk '$1 == "FAIL" { printf "%s%s", s, $2; s = "," }' "$BD_OUT")"
}

B_BIND0=0
t0="$(bd_tree base)" || { echo "FIXTURE BROKEN: no BIND3 probe tree" >&2; exit 2; }
bd_run "$t0"
if [ -z "$BD_FAILED" ] && grep -qx 'PASS BIND3 over 2 file(s)' "$BD_OUT"; then ok "BIND0: the unmutated probe tree (the merge and the join) passes BIND3 over its 2 files"; B_BIND0=1
else bad "BIND0: the unmutated probe tree did not pass BIND3 over 2 files: $(tr '\n' ' ' < "$BD_OUT")"; fi

if [ "$B_BIND0" != 1 ]; then
  bad "FIXTURE BROKEN: BINDm-third and BINDQ3 not scored -- the unmutated probe tree did not pass (BIND0), so the mutant cell would read the base failing"
else
t="$(bd_tree third)" && printf '%s\n' '#!/usr/bin/env bash' "  refuse \"--rerun x: y wrote z $BD_P1 w, after it\"" > "$t/core/scripts/x.sh" \
  && { bd_run "$t"; mrow BINDm-third "BIND3=$([ "$BD_FAILED" = BIND3 ] && echo 1 || echo 0)"; [ "$BD_FAILED" = BIND3 ]; } \
  && grep -q '^FAIL BIND3 x\.sh carries the SAME phrase on 1 line(s);$' "$BD_OUT" \
  && mutant_killed "$B_BIND0" BINDm-third "BINDm-third a third carrier seeded as a scripts-dir x.sh: KILLED by [BIND3], naming x.sh" \
  || bad "BINDm-third: SURVIVED or not applied (failed=${BD_FAILED:-none}, want BIND3 naming x.sh): $(tr '\n' ' ' < "$BD_OUT")"

t="$(bd_tree q3)" && printf '%s\n' '#!/usr/bin/env bash' "  # quoting the refusal: $BD_P1, and $BD_P2" > "$t/core/scripts/x.sh" \
  && bd_run "$t" && [ -z "$BD_FAILED" ] && grep -qx 'PASS BIND3 over 3 file(s)' "$BD_OUT" \
  && ok "BINDQ3: both phrases on a comment line of a scripts-dir x.sh, scanned (3 files) -> BIND3 stays green" \
  || bad "BINDQ3: a comment-line carrier fired BIND3, or x.sh was not scanned (failed=${BD_FAILED:-none}): $(tr '\n' ' ' < "$BD_OUT")"
fi

t="$(mktemp -d "$WORK/bind-floor.XXXXXX")" && mkdir -p "$t/s" "$t/h" \
  && bd_carriers "$t/s" "$t/h" "$MB" "$JB" 0 0 > "$BD_OUT" && grep -q '^FAIL BIND3 REFUSED: the corpus glob' "$BD_OUT" \
  && ok "BINDF: an empty scripts and hooks dir -> BIND3 REFUSES, never a silent pass" \
  || bad "BINDF: an empty corpus did not refuse: $(tr '\n' ' ' < "$BD_OUT")"

t="$(bd_tree q4)" && : > "$t/core/hooks/empty.sh" \
  && bd_run "$t" && [ -z "$BD_FAILED" ] && grep -qx 'PASS BIND3 over 3 file(s)' "$BD_OUT" \
  && ok "BINDQ4: an empty .sh in the scanned hooks dir, counted (3 files) -> BIND3 stays green" \
  || bad "BINDQ4: an empty .sh fired BIND3 or was not counted (failed=${BD_FAILED:-none}): $(tr '\n' ' ' < "$BD_OUT")"

if [ "$(id -u)" = 0 ]; then echo "SKIP-NOTE BINDF2: running as root, chmod 000 does not make a file unopenable; the unopenable-file probe is not seeded"
else
t="$(bd_tree f2)" && printf 'x\n' > "$t/core/hooks/locked.sh" && chmod 000 "$t/core/hooks/locked.sh" \
  && bd_run "$t" && grep -q '^FAIL BIND3 REFUSED: awk read 2 of the 3 listed' "$BD_OUT" \
  && ok "BINDF2: an unopenable listed .sh -> BIND3 REFUSES (awk read 2 of the 3), never a silent pass" \
  || bad "BINDF2: an unopenable listed file did not refuse: $(tr '\n' ' ' < "$BD_OUT")"
fi

# The three real-floor probes are one property apart: which directory is padded to its committed floor.
t="$(bd_tree f3)" && bd_pad "$t/core/scripts" 2 "$FC_FLOOR" && bd_pad "$t/core/hooks" 0 2 \
  && bd_run "$t" "$FC_FLOOR" "$HK_FLOOR" && grep -qx "FAIL BIND3 REFUSED: the hooks dir holds 2 .sh file(s), under the floor $HK_FLOOR -- the directory is narrowed, so a third carrier elsewhere would go unseen" "$BD_OUT" \
  && ok "BINDF3: scripts padded to the floor $FC_FLOOR, hooks holding 2 -> BIND3 REFUSES on the hooks floor $HK_FLOOR" \
  || bad "BINDF3: a narrowed hooks dir did not refuse on the hooks floor: $(tr '\n' ' ' < "$BD_OUT")"
t="$(bd_tree f4)" && bd_pad "$t/core/hooks" 0 "$HK_FLOOR" \
  && bd_run "$t" "$FC_FLOOR" "$HK_FLOOR" && grep -qx "FAIL BIND3 REFUSED: the scripts dir holds 2 .sh file(s), under the floor $FC_FLOOR -- the directory is narrowed, so a third carrier elsewhere would go unseen" "$BD_OUT" \
  && ok "BINDF4: hooks padded to the floor $HK_FLOOR, scripts holding the 2 subjects -> BIND3 REFUSES on the scripts floor $FC_FLOOR" \
  || bad "BINDF4: a narrowed scripts dir did not refuse on the scripts floor: $(tr '\n' ' ' < "$BD_OUT")"
t="$(bd_tree f5)" && bd_pad "$t/core/scripts" 2 "$FC_FLOOR" && bd_pad "$t/core/hooks" 0 "$HK_FLOOR" \
  && bd_run "$t" "$FC_FLOOR" "$HK_FLOOR" && [ -z "$BD_FAILED" ] && grep -qx "PASS BIND3 over $((FC_FLOOR + HK_FLOOR)) file(s)" "$BD_OUT" \
  && ok "BINDF5: both dirs padded to their floors ($FC_FLOOR + $HK_FLOOR files) -> BIND3 passes" \
  || bad "BINDF5: both dirs at their floors did not pass over $((FC_FLOOR + HK_FLOOR)) files: $(tr '\n' ' ' < "$BD_OUT")"

echo "HERMETIC-CONSUMED core/hooks/"
bd_carriers "$SRCDIR" "$HOOKDIR" "$MB" "$JB" "$FC_FLOOR" "$HK_FLOOR" > "$BD_OUT"
case "$(< "$BD_OUT")" in
  "PASS BIND3 over "*) ok "BIND3: no third carrier of either refusal phrase, $(sed 's/^PASS BIND3 //' "$BD_OUT") under $(basename "$SRCDIR")/ and $(basename "$HOOKDIR")/ (floors $FC_FLOOR and $HK_FLOOR)" ;;
  "FAIL BIND3"*) bad "BIND3:$(sed 's/^FAIL BIND3//' "$BD_OUT")" ;;
  *) bad "BIND3: FIXTURE BROKEN -- unreadable verdict [$(tr '\n' ' ' < "$BD_OUT")]" ;;
esac

if [ "$MATRIX" = 1 ]; then echo "  (matrix mode: $N_MROWS MATRIX row(s) printed)"
elif [ "$N_MROWS" -eq 0 ]; then ok "PLAIN: a plain run printed no matrix-only cell"
else bad "PLAIN: a plain run printed $N_MROWS matrix row(s)"; fi

echo
report_end finding-grammar-binding
