#!/usr/bin/env bash
# fixture-hygiene -- drive the REAL scripts/validate-fixture-hygiene.sh against seeded probe projects and score one
# committed mutant per arm.
#
# THE SUBJECT is the shipping validator, copied byte-identical (cmp -s) with its sibling shard-stub resolver
# scripts/validate-fixture-invocations.sh into each probe project, which carries VERSION so the validator's root walk
# resolves to the PROBE, never to this repository; arm R asserts the corpus count it printed is the probe's. Nothing
# here re-implements a validator rule: every verdict is read off the validator's own output. This fixture never runs
# check mode on the real tree.
#
# THE WORLDS, each built once as a git repository (index only; the validator lists tracked files):
#   dirty  one offender per arm: H1 a `-d …/.git` skip, H2 a declared-tool skip, H3 a `sh -c` start and a written
#          `#!/bin/sh` stub run by path, H5 a battery with a mutation helper and no block, not on the allowlist, E1 a
#          receipt-x.sh that nothing reads, H6 an unguarded `. "$HERE/../lib/mutant.sh"`.
#   clean  the near-miss of each, carrying the property a regression would key on: a `-d …/.git` that exits 2, a
#          declared tool that exits 2, `sh` inside an awk program, the same chmod'ed stub run as `bash P` (which
#          ignores the shebang), a battery WITH a valid block, the same receipt-x.sh run by its run.sh, and the same
#          lib source carrying `|| { … exit 2; }`.
#   Both carry a docs/backlog.md (E1 does not read it; receipt-bl868's ledger mode of the shared inert() does).
# THE ARMS, each one read of a validator run:
#   D1 D2 D3 D5 D6 DE1  the dirty run (rc 1) names exactly its arm's seeded line under `FAIL H<n>:` / `FAIL E1:`
#   D7  IS receipt-bl921.sh (its exit and its `receipt-bl921: PASS` line): it seeds its OWN world, a new fixture dir
#       fx7 whose twin GONE7 no code path emits beside an all-real row, and drives the byte-identical validator (or,
#       for MH7, the mutant copy) over it. The clean world's fb emits its twin R2, so H7 is quiet there.
#   C   the clean run is rc 0 with the OK line, which counts 1 receipt and 0 inert (the positive control: a run that
#       scanned nothing cannot print it)
#   R   the clean run's OK line names the probe's corpus count (3 files), so the root walk resolved to the probe
#   DV  --derive over the dirty world prints exactly the battery's row
#   NM  a plain run executes no matrix-only cell (control: the per-push mutant drives ran)
# THE MUTANTS are copies of the dirty world with the validator's arm silenced, guarded by cmp -s and an exactly-once
# rewrite. Each is dead in every cell by construction: the validator's self-probe runs before the corpus and REFUSES
# (exit 2) on any silenced arm, so no arm of this fixture can hold under it -- what a mutant proves is that the
# validator's own self-probe catches the silenced arm, which is the defence a regression would meet first. Per push
# each runs its own D arm only, and the kill is scored on the refusal line naming that arm.
# MUTANT-MATRIX MH1 decides=D1,D2,D3,D5,D6,DE1,D7,D8,D9,C,R,DV twins=- why=the self-probe refuses the whole run when H1 is silenced
# MUTANT-MATRIX MH2 decides=D1,D2,D3,D5,D6,DE1,D7,D8,D9,C,R,DV twins=- why=the self-probe refuses the whole run when H2 is silenced
# MUTANT-MATRIX MH3 decides=D1,D2,D3,D5,D6,DE1,D7,D8,D9,C,R,DV twins=- why=the self-probe refuses the whole run when H3 is silenced
# MUTANT-MATRIX MH3S decides=D1,D2,D3,D5,D6,DE1,D7,D8,D9,C,R,DV twins=- why=the self-probe refuses the whole run when the H3 stub join is silenced
# MUTANT-MATRIX MH5 decides=D1,D2,D3,D5,D6,DE1,D7,D8,D9,C,R,DV twins=- why=the self-probe refuses the whole run when H5 is silenced
# MUTANT-MATRIX MH5N decides=D1,D2,D3,D5,D6,DE1,D7,D8,D9,C,R,DV twins=- why=the self-probe refuses the whole run when H5 reads a helper argument as a name
# MUTANT-MATRIX ME1 decides=D1,D2,D3,D5,D6,DE1,D7,D8,D9,C,R,DV twins=- why=the self-probe refuses the whole run when E1 reads every receipt as read
# MUTANT-MATRIX MH6 decides=D1,D2,D3,D5,D6,DE1,D7,D8,D9,C,R,DV twins=- why=the self-probe refuses the whole run when H6 is silenced
# MUTANT-MATRIX MH7 decides=D1,D2,D3,D5,D6,DE1,D7,D8,D9,C,R,DV twins=- why=the self-probe refuses the whole run when H7 is silenced
# MUTANT-MATRIX MH8O decides=D1,D2,D3,D5,D6,DE1,D7,D8,D9,C,R,DV twins=- why=the self-probe refuses the whole run when H8 ignores order
# MUTANT-MATRIX MH8G decides=D1,D2,D3,D5,D6,DE1,D7,D8,D9,C,R,DV twins=- why=the self-probe refuses the whole run when H8 accepts a GIT_ loop
# MUTANT-MATRIX MH8C decides=D1,D2,D3,D5,D6,DE1,D7,D8,D9,C,R,DV twins=- why=the self-probe refuses the whole run when H8 accepts a commented loop
# MUTANT-MATRIX MH8S decides=D1,D2,D3,D5,D6,DE1,D7,D8,D9,C,R,DV twins=- why=the self-probe refuses the whole run when H8 judges a stub by itself
# MUTANT-MATRIX MH8R decides=D1,D2,D3,D5,D6,DE1,D7,D8,D9,C,R,DV twins=- why=the self-probe refuses the whole run when H8 drops its stale-row check
# MUTANT-MATRIX MM4 decides=D1,D2,D3,D5,D6,DE1,D7,D8,D9,C,R,DV twins=- why=the self-probe refuses the whole run when M4 never refuses an added row
# MUTANT-MATRIX MM4R decides=D1,D2,D3,D5,D6,DE1,D7,D8,D9,C,R,DV twins=- why=the self-probe refuses the whole run when m4's rel default is another list
# MUTANT-MATRIX MM4A decides=D1,D2,D3,D5,D6,DE1,D7,D8,D9,C,R,DV twins=- why=the self-probe refuses the whole run when m4's arm default is another arm
# MUTANT-MATRIX MM4P decides=D1,D2,D3,D5,D6,DE1,D7,D8,D9,C,R,DV twins=- why=the self-probe refuses the whole run when m4 hands m4cmp a fixed M4
# MUTANT-MATRIX MM4B decides=D1,D2,D3,D5,D6,DE1,D7,D8,D9,C,R,DV twins=- why=the self-probe refuses the whole run when m4 hands m4base a fixed M4
# MUTANT-MATRIX-REMEASURE bash core/fixtures/fixture-hygiene/run.sh --matrix
# Re-measure it whenever an arm or a mutant is added or changed.
#   MH1  H1's branch verdict made false        -> D1 reads the self-probe refusal naming H1
#   MH2  H2's branch verdict made false        -> D2 reads the self-probe refusal naming H2
#   MH3  H3's offender print removed           -> D3 reads the self-probe refusal naming H3
#   MH3S H3's stub-join print made false       -> D3 reads the self-probe refusal naming H3 (the word-form rows stay)
#   MH5  H5's FLOOR verdict made false         -> D5 reads the self-probe refusal naming H5
#   MH5N H5's join re-reads the 1st argument of the fixture's mutation helper as a mutant name (the extraction the
#        emission-site join removed) -> D5 reads the self-probe refusal naming H5 AND its got-only JOIN row on the
#        seeded world-letter call `ck_mut A mutant-x` (m5m:5), so the kill is the world-letter cell, not MH5's
#   ME1  E1's inert print made false (every receipt read as a reader, the arm disabled) -> DE1 reads the self-probe
#        refusal naming E1
#   MH6  H6's offender print removed           -> D6 reads the self-probe refusal naming H6
#   MH7  H7's offender print made false        -> D7 (receipt-bl921.sh driving the mutant copy) reads the self-probe
#        refusal naming H7
#   MH8O MH8G MH8C MH8S MH8R  H8 presence-only (order ignored), the sed program read off the masked line only (a GIT_
#        loop accepted), the loop located on the unmasked line (a comment accepted), a stub not resolved to its IMPL,
#        the stale-row check removed -> D8 (receipt-bl929.sh driving the mutant copy) reads the self-probe refusal
#        naming H8, each scored on its OWN seed's diff row (h8srcb, h8git, h8cmt, h8stubok, h8stl)
#   MM4  M4's added-row refusal made false (m4 passes every list) -> D1 reads the self-probe refusal naming M4, on
#        the `added` case, so the M4 probe repos the validator builds are proven read by a case that can fail
#   MM4R m4()'s rel default reads the H7 list    -> D1 reads the self-probe refusal naming M4, on the `added` case
#        (the whole of m4 called with no rel, as the corpus's M4 call is: origin/main carries no H7 list, so it SKIPs)
#   MM4A m4()'s arm default reads H7-M4          -> D1 reads the self-probe refusal naming M4, on the `added` case
#        (rc 1 as wanted, its first line headed H7-M4)
#   MM4P m4() hands m4cmp a fixed M4, not its arm -> D1 reads the self-probe refusal naming M4, on the `swap` case
#        (the whole of m4 with an explicit arm, as the H7-M4, H8-M4 and E1-M4 corpus calls pass it)
#   MM4B m4() hands m4base a fixed M4, not its arm -> D1 reads the self-probe refusal naming M4, on the `nofile`
#        case (the whole of m4 with an explicit arm; its SKIP line is m4base's, headed M4 instead of P-M4)
#
# D8  IS receipt-bl929.sh, D9 IS receipt-bl930.sh: each seeds its OWN world and drives the validator (BL-929: a
#     scrubbed fixture and a scrubbed-IMPL stub read SCRUBBED, an unscrubbed unlisted one FAILs H8, a listed one
#     passes; BL-930: the GIT_-only hook driver I10 acquitted, and a listed hook driver, FAIL H8). The dirty and clean
#     worlds' fa and fb carry no scrub and are rows of the world's own H8 list, so H8 is quiet there.
#
# Usage: run.sh [--matrix]     Exit: 0 pass, 1 FAIL, 2 FIXTURE BROKEN.
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "fixture-hygiene: FIXTURE BROKEN: core/fixtures/lib/preamble.sh is absent" >&2; exit 2; }
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
MODE=plain; [ "${1:-}" = --matrix ] && MODE=matrix
ROOT=""; d="$HERE"
while [ -n "$d" ] && [ "$d" != / ]; do
  [ -f "$d/scripts/validate-fixture-hygiene.sh" ] && [ -f "$d/scripts/validate-fixture-invocations.sh" ] && { ROOT="$d"; break; }
  d="$(dirname "$d")"
done
[ -n "$ROOT" ] || { echo "FIXTURE ERROR: no scripts/validate-fixture-hygiene.sh walking up from $HERE" >&2; exit 2; }

WORK="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd -P)"
trap 'rm -rf "$WORK"' EXIT
FAILS=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; FAILS=$((FAILS + 1)); }
. "$ROOT/core/fixtures/lib/mutant.sh" || { echo "FIXTURE BROKEN: cannot source lib/mutant.sh" >&2; exit 2; }
VREL=scripts/validate-fixture-hygiene.sh
IREL=scripts/validate-fixture-invocations.sh
g() { env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE -u GIT_OBJECT_DIRECTORY git -c core.hooksPath=/dev/null "$@"; }

# --- the worlds -------------------------------------------------------------------------------------------------
put() { mkdir -p "$(dirname "$1")" && cat > "$1"; }
mk_world() { # <dir> <dirty|clean>
  local w="$1"
  mkdir -p "$w/scripts" && : > "$w/VERSION" && cp -p "$ROOT/$VREL" "$ROOT/$IREL" "$w/scripts/" || return 1
  cmp -s "$ROOT/$VREL" "$w/$VREL" && cmp -s "$ROOT/$IREL" "$w/$IREL" || return 1
  printf 'jq\n' > "$w/tools.tmp"
  if [ "$2" = dirty ]; then
    put "$w/core/fixtures/fa/run.sh" <<'EOF'
#!/usr/bin/env bash
if [ ! -d "$R/.git" ]; then
  echo "SKIP no history"
  exit 0
fi
command -v jq >/dev/null 2>&1 || { echo "SKIP no jq"; exit 0; }
sh -c 'exit 0' & p=$!
printf '#!/bin/sh\nexit 0\n' > "$W/stub" && chmod +x "$W/stub"
"$W/stub"
. "$HERE/../lib/mutant.sh"
EOF
    put "$w/core/fixtures/fb/run.sh" <<'EOF'
#!/usr/bin/env bash
mkmut() { :; }
EOF
    cp "$w/tools.tmp" "$w/core/fixtures/fa/tools.decl"
    printf '#!/usr/bin/env bash\nexit 0\n' > "$w/core/fixtures/fb/receipt-x.sh"
  else
    put "$w/core/fixtures/fa/run.sh" <<'EOF'
#!/usr/bin/env bash
if [ ! -d "$R/.git" ]; then
  echo "FIXTURE BROKEN: no history; exit 0 would lie"
  exit 2
fi
command -v jq >/dev/null 2>&1 || { echo "FIXTURE BROKEN: no jq"; exit 2; }
awk '{ if (sh != "") print sh }' f
printf '#!/bin/sh\nexit 0\n' > "$W/stub" && chmod +x "$W/stub"
bash "$W/stub"
. "$HERE/../lib/mutant.sh" || { echo "FIXTURE BROKEN: cannot source lib/mutant.sh" >&2; exit 2; }
EOF
    put "$w/core/fixtures/fb/run.sh" <<'EOF'
#!/usr/bin/env bash
# MUTANT-MATRIX MA decides=R1.cellA twins=R2
# MUTANT-MATRIX-REMEASURE bash core/fixtures/fb/run.sh --matrix
mkmut() { :; }
mkmut MA x
ok "R2 the twin cell"
bash "$HERE/receipt-x.sh"
EOF
    cp "$w/tools.tmp" "$w/core/fixtures/fa/tools.decl"
    printf '#!/usr/bin/env bash\nexit 0\n' > "$w/core/fixtures/fb/receipt-x.sh"
  fi
  rm -f "$w/tools.tmp"
  # fa and fb carry no AI_DLC_* scrub; in both worlds they are rows of the world's own H8 list, so H8 stays quiet
  printf '# probe\nfa\tworld seed\nfb\tworld seed\n' > "$w/scripts/env-scrub-allowlist.txt"
  mkdir -p "$w/docs" && printf '# ledger\n' > "$w/docs/backlog.md"
  env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE -u GIT_OBJECT_DIRECTORY git -c core.hooksPath=/dev/null init -q "$w" && g -C "$w" add -A core docs >/dev/null 2>&1
}
mk_world "$WORK/w-dirty" dirty && mk_world "$WORK/w-clean" clean \
  || { echo "FIXTURE BROKEN: could not build the probe worlds byte-identical" >&2; exit 2; }

# mk_mutant <name> <old> <new>: the dirty world copied whole, the validator changed exactly once.
mk_mutant() {
  local m="$WORK/mut-$1"
  cp -R "$WORK/w-dirty" "$m" || return 1
  OLD="$2" NEW="$3" awk '{ i = index($0, ENVIRON["OLD"]); if (i > 0) { $0 = substr($0, 1, i - 1) ENVIRON["NEW"] substr($0, i + length(ENVIRON["OLD"])); n++ } print }
    END { if (n != 1) exit 3 }' "$WORK/w-dirty/$VREL" > "$m/$VREL.new" || return 1
  mv "$m/$VREL.new" "$m/$VREL" || return 1
  cmp -s "$WORK/w-dirty/$VREL" "$m/$VREL" && return 1
  [ -f "$m/$IREL" ] || return 1
}
mk_mutant MH1 'if (fails_to_exit0(i, st, qe, neg, pre0)) print "H1\t"' 'if (0) print "H1\t"' \
  || { echo "FIXTURE BROKEN: mutant MH1 DID NOT APPLY" >&2; exit 2; }
mk_mutant MH2 'if (fails_to_exit0(i, st, WEND, neg, pre0)) print "H2\t"' 'if (0) print "H2\t"' \
  || { echo "FIXTURE BROKEN: mutant MH2 DID NOT APPLY" >&2; exit 2; }
mk_mutant MH3 'print "H3\t" REL ":" i "\t" trim(O[i])' 'H3N++' \
  || { echo "FIXTURE BROKEN: mutant MH3 DID NOT APPLY" >&2; exit 2; }
mk_mutant MH3S 'if (x) print "H3\t"' 'if (0) print "H3\t"' \
  || { echo "FIXTURE BROKEN: mutant MH3S DID NOT APPLY" >&2; exit 2; }
mk_mutant MH5 'if (!(f in LISTED)) print "FLOOR\t"' 'if (0) print "FLOOR\t"' \
  || { echo "FIXTURE BROKEN: mutant MH5 DID NOT APPLY" >&2; exit 2; }
mk_mutant MH5N 'if (ISRUN && !HDL[i] && O[i] ~' 'if (S1[FX] != "" && match(s, "(^|[[:space:];&|(!])" S1[FX] "[[:space:]]+")) { k = literal(wordat(O[i], RSTART + RLENGTH)); if (k != "") print "K\t" FX "\t" REL ":" i "\t" k }
    if (ISRUN && !HDL[i] && O[i] ~' \
  || { echo "FIXTURE BROKEN: mutant MH5N DID NOT APPLY" >&2; exit 2; }
mk_mutant ME1 'for (c in C) if (!(c in LIVE)) print c' 'for (c in C) if (0) print c' \
  || { echo "FIXTURE BROKEN: mutant ME1 DID NOT APPLY" >&2; exit 2; }
mk_mutant MH6 'print "H6\t" REL ":" i "\t" trim(O[i])' 'H6N++' \
  || { echo "FIXTURE BROKEN: mutant MH6 DID NOT APPLY" >&2; exit 2; }
mk_mutant MH7 'else print "H7\t" TWW7[x]' 'else H7N++; if (0) print "H7\t" TWW7[x]' \
  || { echo "FIXTURE BROKEN: mutant MH7 DID NOT APPLY" >&2; exit 2; }
mk_mutant MH8O 'return "O" EL[f, k] ": " ET[f, k]' 'continue' \
  || { echo "FIXTURE BROKEN: mutant MH8O DID NOT APPLY" >&2; exit 2; }
mk_mutant MH8G 'if (prog != PROG8) return' 'if (0) return' \
  || { echo "FIXTURE BROKEN: mutant MH8G DID NOT APPLY" >&2; exit 2; }
mk_mutant MH8C 'o = O[i]; s = M[i]' 'o = O[i]; s = O[i]' \
  || { echo "FIXTURE BROKEN: mutant MH8C DID NOT APPLY" >&2; exit 2; }
mk_mutant MH8S 't = (f in IMPL && IMPL[f] != "!") ? IMPL[f] : f' 't = f' \
  || { echo "FIXTURE BROKEN: mutant MH8S DID NOT APPLY" >&2; exit 2; }
mk_mutant MH8R 'if (f in LISTED) print "H8STALE\t" f "\tthe fixture is SCRUBBED' 'if (0) print "H8STALE\t" f "\tthe fixture is SCRUBBED' \
  || { echo "FIXTURE BROKEN: mutant MH8R DID NOT APPLY" >&2; exit 2; }
mk_mutant MM4 'if [ -n "$added" ]; then' 'if [ -n "" ]; then' \
  || { echo "FIXTURE BROKEN: mutant MM4 DID NOT APPLY" >&2; exit 2; }
mk_mutant MM4R 'local rel="${4:-$ALLOW_REL}" arm="${5:-M4}" rc' 'local rel="${4:-$H7_ALLOW_REL}" arm="${5:-M4}" rc' \
  || { echo "FIXTURE BROKEN: mutant MM4R DID NOT APPLY" >&2; exit 2; }
mk_mutant MM4A 'arm="${5:-M4}" rc' 'arm="${5:-H7-M4}" rc' \
  || { echo "FIXTURE BROKEN: mutant MM4A DID NOT APPLY" >&2; exit 2; }
mk_mutant MM4P 'm4cmp "$2" "$3" "$rel" "$arm" "$remedy" "$noun"' 'm4cmp "$2" "$3" "$rel" M4 "$remedy" "$noun"' \
  || { echo "FIXTURE BROKEN: mutant MM4P DID NOT APPLY" >&2; exit 2; }
mk_mutant MM4B 'm4base "$1" "$3" "$rel" "$arm"' 'm4base "$1" "$3" "$rel" M4' \
  || { echo "FIXTURE BROKEN: mutant MM4B DID NOT APPLY" >&2; exit 2; }

# --- one validator run per distinct state -------------------------------------------------------------------------
drive() { # <tag> <world dir> [--derive]
  ( cd "$2" && unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE && bash "$2/$VREL" ${3:+"$3"} ) > "$WORK/c.$1.out" 2> "$WORK/c.$1.err"
  echo $? > "$WORK/c.$1.rc"
}
# d7drive <tag> [<validator>]: arm D7 IS receipt-bl921.sh, which seeds its own world (a NEW fixture dir fx7 with a
# dangling twin, beside an all-real row) and drives the byte-identical validator, or the named mutant copy, over it.
d7drive() {
  bash "$HERE/receipt-bl921.sh" ${2:+--validator "$2"} > "$WORK/c.$1.out" 2> "$WORK/c.$1.err"
  echo $? > "$WORK/c.$1.rc"
}
# d8drive / d9drive <tag> [<validator>]: arms D8 and D9 ARE receipt-bl929.sh and receipt-bl930.sh, each seeding its
# own world (BL-929: a scrubbed fixture, a scrubbed-IMPL stub, an unscrubbed unlisted and an allowlisted one; BL-930:
# the GIT_-only hook driver I10 acquitted and a listed hook driver) and driving the validator, or a mutant copy.
d8drive() {
  bash "$HERE/receipt-bl929.sh" ${2:+--validator "$2"} > "$WORK/c.$1.out" 2> "$WORK/c.$1.err"
  echo $? > "$WORK/c.$1.rc"
}
d9drive() {
  bash "$HERE/receipt-bl930.sh" ${2:+--validator "$2"} > "$WORK/c.$1.out" 2> "$WORK/c.$1.err"
  echo $? > "$WORK/c.$1.rc"
}
has()  { grep -qF -- "$2" "$WORK/c.$1.out" "$WORK/c.$1.err"; }
rcis() { [ "$(cat "$WORK/c.$1.rc" 2>/dev/null)" = "$2" ]; }
# section <tag> <arm>: the lines under `FAIL <arm>:` up to the next unindented line
section() { awk -v A="FAIL $2:" '$0 == A { on = 1; next } on && /^    / { print; next } on { exit }' "$WORK/c.$1.out"; }
verdict() { # <arm> <tag>
  local t="$2"
  case "$1" in
    D1) rcis "$t" 1 && [ "$(section "$t" H1)" = '    core/fixtures/fa/run.sh:2: if [ ! -d "$R/.git" ]; then' ] ;;
    D2) rcis "$t" 1 && [ "$(section "$t" H2)" = '    core/fixtures/fa/run.sh:6: command -v jq >/dev/null 2>&1 || { echo "SKIP no jq"; exit 0; }' ] ;;
    D3) rcis "$t" 1 && [ "$(section "$t" H3)" = "    core/fixtures/fa/run.sh:7: sh -c 'exit 0' & p=\$!
    core/fixtures/fa/run.sh:8: a #!/bin/sh stub \$W/stub written here is executed at :9: \"\$W/stub\"" ] ;;
    D5) rcis "$t" 1 && [ "$(section "$t" H5)" = '    FLOOR fb: S1 mkmut()' ] ;;
    D6) rcis "$t" 1 && [ "$(section "$t" H6)" = '    core/fixtures/fa/run.sh:10: . "$HERE/../lib/mutant.sh"' ] ;;
    DE1) rcis "$t" 1 && [ "$(section "$t" E1)" = '    INERT core/fixtures/fb/receipt-x.sh' ] ;;
    D7) rcis "$t" 0 && { has "$t" 'receipt-bl921: PASS' || has "$t" 'receipt-bl921: held under a substituted validator'; } ;;
    D8) rcis "$t" 0 && { has "$t" 'receipt-bl929: PASS' || has "$t" 'receipt-bl929: held under a substituted validator'; } ;;
    D9) rcis "$t" 0 && { has "$t" 'receipt-bl930: PASS' || has "$t" 'receipt-bl930: held under a substituted validator'; } ;;
    C)  rcis "$t" 0 && has "$t" 'OK: validate-fixture-hygiene -- self-probe fired both ways' && has "$t" 'E1 1 receipt(s), 0 inert' ;;
    R)  rcis "$t" 0 && has "$t" '; 3 fixture .sh scanned;' ;;
    DV) rcis "$t" 0 && [ "$(cat "$WORK/c.$t.out")" = "$(printf 'fb\tno MUTANT-MATRIX block; floor: S1 mkmut()')" ] ;;
    *) return 1 ;;
  esac
}
REFUSAL() { printf 'self-probe %s: FAIL' "$1"; }

if [ "$MODE" = matrix ]; then
  : > "$WORK/mx.ran"
  for m in MH1 MH2 MH3 MH3S MH5 MH5N ME1 MH6 MH7 MH8O MH8G MH8C MH8S MH8R MM4 MM4R MM4A MM4P MM4B; do
    cp -R "$WORK/w-clean" "$WORK/mclean-$m" && cp -p "$WORK/mut-$m/$VREL" "$WORK/mclean-$m/$VREL" \
      || { echo "FIXTURE BROKEN: could not build the clean world for $m" >&2; exit 2; }
    drive "$m.d" "$WORK/mut-$m" & drive "$m.v" "$WORK/mut-$m" --derive & drive "$m.c" "$WORK/mclean-$m" &
    d7drive "$m.7" "$WORK/mut-$m/$VREL" & d8drive "$m.8" "$WORK/mut-$m/$VREL" & d9drive "$m.9" "$WORK/mut-$m/$VREL" &
  done; wait
  for m in MH1 MH2 MH3 MH3S MH5 MH5N ME1 MH6 MH7 MH8O MH8G MH8C MH8S MH8R MM4 MM4R MM4A MM4P MM4B; do
    dec=""; tw=""
    for a in D1 D2 D3 D5 D6 DE1; do if verdict "$a" "$m.d"; then tw="$tw,$a"; else dec="$dec,$a"; fi; done
    if verdict D7 "$m.7"; then tw="$tw,D7"; else dec="$dec,D7"; fi
    if verdict D8 "$m.8"; then tw="$tw,D8"; else dec="$dec,D8"; fi
    if verdict D9 "$m.9"; then tw="$tw,D9"; else dec="$dec,D9"; fi
    for a in C R; do if verdict "$a" "$m.c"; then tw="$tw,$a"; else dec="$dec,$a"; fi; done
    if verdict DV "$m.v"; then tw="$tw,DV"; else dec="$dec,DV"; fi
    printf 'MATRIX %s decides=%s twins=%s\n' "$m" "${dec#,}" "${tw#,}"
  done
  exit 0
fi

drive dirty "$WORK/w-dirty" & drive clean "$WORK/w-clean" & drive derive "$WORK/w-dirty" --derive &
for m in MH1 MH2 MH3 MH3S MH5 MH5N ME1 MH6 MM4 MM4R MM4A MM4P MM4B; do drive "$m" "$WORK/mut-$m" & done
d7drive d7 & d7drive MH7 "$WORK/mut-MH7/$VREL" &
d8drive d8 & d9drive d9 &
for m in MH8O MH8G MH8C MH8S MH8R; do d8drive "$m" "$WORK/mut-$m/$VREL" & done
wait
B_DIRTY=0
for a in D1 D2 D3 D5 D6 DE1; do
  if verdict "$a" dirty; then ok "$a the dirty world names exactly its seeded line"; : > "$WORK/base.$a"
  else bad "$a fails on the unmutated validator (rc $(cat "$WORK/c.dirty.rc")): $(head -c 800 "$WORK/c.dirty.out" | tr '\n' ' ')"; fi
done
if verdict D7 d7 && grep -qxF 'receipt-bl921: PASS' "$WORK/c.d7.out"; then
  ok "D7 receipt-bl921.sh: a dangling twin in its own world FAILs H7 by name, the all-real row stays quiet"; : > "$WORK/base.D7"
  grep -xF 'receipt-bl921: PASS' "$WORK/c.d7.out"   # the receipt's own line, re-emitted for BL-921's verify: line
else bad "D7 receipt-bl921.sh did not PASS on the unmutated validator (rc $(cat "$WORK/c.d7.rc")): $(head -c 800 "$WORK/c.d7.out" | tr '\n' ' ')"; fi
if verdict D8 d8 && grep -qxF 'receipt-bl929: PASS' "$WORK/c.d8.out"; then
  ok "D8 receipt-bl929.sh: a scrubbed fixture and a scrubbed-IMPL stub read SCRUBBED, an unscrubbed unlisted one FAILs H8, a listed one passes"; : > "$WORK/base.D8"
  grep -xF 'receipt-bl929: PASS' "$WORK/c.d8.out"   # the receipt's own line, re-emitted for BL-929's verify: line
else bad "D8 receipt-bl929.sh did not PASS on the unmutated validator (rc $(cat "$WORK/c.d8.rc")): $(head -c 800 "$WORK/c.d8.out" | tr '\n' ' ')"; fi
if verdict D9 d9 && grep -qxF 'receipt-bl930: PASS' "$WORK/c.d9.out"; then
  ok "D9 receipt-bl930.sh: the GIT_-only hook driver I10 acquitted, and a listed hook driver, FAIL H8; the AI_DLC_ near-miss reads SCRUBBED"
  grep -xF 'receipt-bl930: PASS' "$WORK/c.d9.out"   # the receipt's own line, re-emitted for BL-930's verify: line
else bad "D9 receipt-bl930.sh did not PASS on the unmutated validator (rc $(cat "$WORK/c.d9.rc")): $(head -c 800 "$WORK/c.d9.out" | tr '\n' ' ')"; fi
verdict C clean && ok "C the clean world (every near-miss) is rc 0 with the OK line" \
  || bad "C the clean world is not clean (rc $(cat "$WORK/c.clean.rc")): $(head -c 800 "$WORK/c.clean.out" | tr '\n' ' ')"
verdict R clean && ok "R the validator resolved the PROBE root (3 fixture .sh scanned, not this repository's corpus)" \
  || bad "R the clean run did not report the probe's 3-file corpus"
verdict DV derive && ok "DV --derive prints exactly the unblocked battery's row" \
  || bad "DV --derive printed: $(head -c 400 "$WORK/c.derive.out" | tr '\n' '|')"
if [ -e "$WORK/base.D1" ] && verdict C clean; then
  echo "HERMETIC-CONSUMED $VREL"
  echo "HERMETIC-CONSUMED $IREL"
fi

# --- the mutants, each on its deciding arm --------------------------------------------------------------------------
score() { # <mutant> <arm> <arm label in the self-probe>; 0 when the arm fails for its reason
  if verdict "$2" "$1"; then bad "$1 SURVIVED: arm $2 still holds under it"; return 1; fi
  rcis "$1" 2 && has "$1" "$(REFUSAL "$3")" || { bad "$1: arm $2 fails under it, but not by the self-probe naming $3 (rc $(cat "$WORK/c.$1.rc"))"; return 1; }
}
flag() { [ -e "$WORK/base.$1" ] && echo 1 || echo 0; }
BASE_D1="$(flag D1)"; BASE_D2="$(flag D2)"; BASE_D3="$(flag D3)"; BASE_D5="$(flag D5)"; BASE_D6="$(flag D6)"; BASE_DE1="$(flag DE1)"; BASE_D7="$(flag D7)"
score MH7 D7 H7 && mutant_killed "$([ "$BASE_D7" = 1 ] && echo 1 || echo 0)" MH7 "MH7: arm D7 fails by the self-probe refusal naming H7"
score MH6 D6 H6 && mutant_killed "$([ "$BASE_D6" = 1 ] && echo 1 || echo 0)" MH6 "MH6: arm D6 fails by the self-probe refusal naming H6"
score ME1 DE1 E1 && mutant_killed "$([ "$BASE_DE1" = 1 ] && echo 1 || echo 0)" ME1 "ME1: arm DE1 fails by the self-probe refusal naming E1"
score MH1 D1 H1 && mutant_killed "$([ "$BASE_D1" = 1 ] && echo 1 || echo 0)" MH1 "MH1: arm D1 fails by the self-probe refusal naming H1"
score MH2 D2 H2 && mutant_killed "$([ "$BASE_D2" = 1 ] && echo 1 || echo 0)" MH2 "MH2: arm D2 fails by the self-probe refusal naming H2"
score MH3 D3 H3 && mutant_killed "$([ "$BASE_D3" = 1 ] && echo 1 || echo 0)" MH3 "MH3: arm D3 fails by the self-probe refusal naming H3"
score MH3S D3 H3 && mutant_killed "$([ "$BASE_D3" = 1 ] && echo 1 || echo 0)" MH3S "MH3S: arm D3 fails by the self-probe refusal naming H3"
score MH5 D5 H5 && mutant_killed "$([ "$BASE_D5" = 1 ] && echo 1 || echo 0)" MH5 "MH5: arm D5 fails by the self-probe refusal naming H5"
# MH5N must die on the world-letter cell itself: the refusal alone is MH5's signal too.
WL_ROW="$(printf 'got-only  JOIN\tcore/fixtures/m5m/run.sh:5')"
if score MH5N D5 H5; then
  if has MH5N "$WL_ROW"; then mutant_killed "$([ "$BASE_D5" = 1 ] && echo 1 || echo 0)" MH5N "MH5N: arm D5 fails by the self-probe refusal naming H5, on the world-letter JOIN row m5m:5"
  else bad "MH5N: the self-probe refused, but not on the world-letter JOIN row m5m:5"; fi
fi
# MM4 must die on M4's `added` case: the refusal names M4 and the case that read the built M4 probe repo.
if score MM4 D1 M4; then
  if has MM4 'self-probe M4: FAIL -- case added got rc 0, want 1'; then mutant_killed "$([ "$BASE_D1" = 1 ] && echo 1 || echo 0)" MM4 "MM4: arm D1 fails by the self-probe refusal naming M4, on its added case"
  else bad "MM4: the self-probe refused, but not on M4's added case"; fi
fi
# MM4R, MM4A and MM4P each die on the M4 case that reads what they break: m4's rel default (added SKIPs, rc 0), its arm
# default (added's first line headed H7-M4) and its hand-off of an explicit arm to m4cmp (swap's first line headed M4);
# MM4B its hand-off of that arm to m4base (nofile's SKIP line headed M4).
m4row() { # <mutant> <refusal text> <what>
  score "$1" D1 M4 || return 1
  has "$1" "$2" && return 0
  bad "$1: the self-probe refused, but not on $3"; return 1
}
m4row MM4R 'self-probe M4: FAIL -- case added got rc 0, want 1' "M4's added case at rc 0" && mutant_killed "$([ "$BASE_D1" = 1 ] && echo 1 || echo 0)" MM4R "MM4R: arm D1 fails by the self-probe refusal naming M4, on its added case (m4's rel default)"
m4row MM4A 'self-probe M4: FAIL -- case added got rc 1, want 1: FAIL H7-M4:' "M4's added case headed H7-M4" && mutant_killed "$([ "$BASE_D1" = 1 ] && echo 1 || echo 0)" MM4A "MM4A: arm D1 fails by the self-probe refusal naming M4, on its added case (m4's arm default)"
m4row MM4P 'self-probe M4: FAIL -- case swap got rc 1, want 1: FAIL M4:' "M4's swap case headed M4" && mutant_killed "$([ "$BASE_D1" = 1 ] && echo 1 || echo 0)" MM4P "MM4P: arm D1 fails by the self-probe refusal naming M4, on its swap case (m4's arm hand-off)"
m4row MM4B 'self-probe M4: FAIL -- case nofile got rc 0, want 0: SKIP M4:' "M4's nofile case headed M4" && mutant_killed "$([ "$BASE_D1" = 1 ] && echo 1 || echo 0)" MM4B "MM4B: arm D1 fails by the self-probe refusal naming M4, on its nofile case (m4's arm hand-off to m4base)"

# The five H8 mutants, each on D8 (receipt-bl929.sh driving the mutant copy), each killed on its OWN seed's row of the
# self-probe diff -- the refusal alone is every H8 mutant's signal, so the row is what tells one from another:
#   MH8O presence only, the ORDER rule ignored   -> h8srcb (the loop after a lib source) reads SCRUBBED
#   MH8G the sed program read off the masked line only, so a GIT_ loop of the same shape is a scrub -> h8git SCRUBBED
#   MH8C the loop located on the UNMASKED line, so a commented loop counts -> h8cmt SCRUBBED
#   MH8S a shard stub judged by itself, not its IMPL -> h8stubok (IMPL scrubs) loses its SCRUBBED row
#   MH8R the stale-row check removed              -> h8stl (listed and scrubbed) loses its H8STALE row
BASE_D8="$(flag D8)"
h8row() { # <mutant> <diff row> <what>: 0 when it fails D8 by the H8 refusal AND on its own seed's row
  score "$1" D8 H8 || return 1
  has "$1" "$2" && return 0
  bad "$1: the self-probe refused, but not on $3"; return 1
}
h8row MH8O "$(printf 'got-only  H8SCRUB\th8srcb')" "h8srcb" && mutant_killed "$([ "$BASE_D8" = 1 ] && echo 1 || echo 0)" MH8O "MH8O: arm D8 fails by the self-probe refusal naming H8, on h8srcb read SCRUBBED (order ignored)"
h8row MH8G "$(printf 'got-only  H8SCRUB\th8git')" "h8git" && mutant_killed "$([ "$BASE_D8" = 1 ] && echo 1 || echo 0)" MH8G "MH8G: arm D8 fails by the self-probe refusal naming H8, on h8git read SCRUBBED (a GIT_ loop accepted)"
h8row MH8C "$(printf 'got-only  H8SCRUB\th8cmt')" "h8cmt" && mutant_killed "$([ "$BASE_D8" = 1 ] && echo 1 || echo 0)" MH8C "MH8C: arm D8 fails by the self-probe refusal naming H8, on h8cmt read SCRUBBED (a commented loop accepted)"
h8row MH8S "$(printf 'want-only H8SCRUB\th8stubok')" "h8stubok" && mutant_killed "$([ "$BASE_D8" = 1 ] && echo 1 || echo 0)" MH8S "MH8S: arm D8 fails by the self-probe refusal naming H8, on h8stubok not SCRUBBED (the stub not mapped to its IMPL)"
h8row MH8R "$(printf 'want-only H8STALE\th8stl')" "h8stl" && mutant_killed "$([ "$BASE_D8" = 1 ] && echo 1 || echo 0)" MH8R "MH8R: arm D8 fails by the self-probe refusal naming H8, on h8stl not STALE (the stale-row check removed)"

if [ ! -e "$WORK/mx.ran" ] && [ -e "$WORK/c.MH5.out" ] && [ -e "$WORK/c.MH1.out" ] && [ -e "$WORK/c.MH7.out" ] && [ -e "$WORK/c.MH8R.out" ]; then ok "NM a plain run executes no matrix-only cell, and the per-push mutant drives ran"
else bad "NM a plain run reached the matrix, or its per-push mutant drives did not run"; fi

[ "$FAILS" = 0 ] || { echo "fixture-hygiene: $FAILS FAILED"; exit 1; }
echo "fixture-hygiene: PASS"
exit 0
