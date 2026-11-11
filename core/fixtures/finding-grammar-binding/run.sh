#!/usr/bin/env bash
# finding-grammar-binding/run.sh -- THE ONE FINDING GRAMMAR, BYTE-BOUND (BL-958; merge-adversarial-shards.sh header,
# FINDING GRAMMAR / THE FINDING ID). Three programs read an adversarial finding heading: the merge's parse_shard,
# join-remediator-shards.sh src_ids and validate-adversarial-convergence.sh j3_keys (J3). When they disagree, the merge
# counts a finding J3 cannot key, and the gate can never close it. This fixture holds the three copies to one text.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the binding regressed, 2 = fixture broken.
#
# ARMS. BB0 self-probes FIRST, in a mktemp tree, both directions. BB1 binds the ID RULE, the FENCE RULE, sev() and the
# `## Findings` match across the three functions. BB2 counts every fence-rule copy in core/scripts/*.sh against an
# enumeration, so a fourth hand-copied grammar in a NEW file fails, and refuses a scanned set under a floor, so a sandbox
# that copies only the named carriers cannot pass it by counting four files.
#
# WHY A FIXTURE OF ITS OWN. These arms were first written into adversarial-shard-merge, the suite's slowest fixture.
# BB2 reads the whole core/scripts/ directory, so that fixture re-ran on every edit to any core script. The binding
# reads only text and runs no program, so it lives here, where a core/scripts edit costs a few awk passes.
#
# `.dist-only`: the reason is in the marker beside this file.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails + 1)); }

echo "finding-grammar-binding"

# The subject, found by walking UP from this file's directory for core/scripts/ -- never by counting `..`.
HERE="$(cd "$(dirname "$0")" && pwd)"
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

echo
if [ "$fails" -eq 0 ]; then echo "finding-grammar-binding: PASS"; exit 0; fi
echo "finding-grammar-binding: $fails assertion(s) FAILED" >&2
exit 1
