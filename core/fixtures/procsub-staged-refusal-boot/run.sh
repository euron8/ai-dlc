#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# procsub-staged-refusal-boot — the four BOOTSTRAPPING reconcile scripts refuse when a producer
# they read fails, where they used to read the failure as an empty input.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = an assertion failed, 2 = fixture broken.
#
# THE DEFECT. A `<( )` producer's exit status is discarded, so a producer that failed fed its
# reader an EMPTY stream and the script decided on it. In these four scripts the empty stream was
# a verdict, and at every site armed below it was the CLEAN one:
#
#   L1  ledger-reverify  receipt_absent_subjects  empty token list = "every named path exists"
#                        -> a false CLOSE-CANDIDATE, the verdict that retires a live entry
#   L2  ledger-reverify  receipt_named_subjects   empty token list = "names no subject"
#                        -> STILL-LIVE, and the NEEDS-REVIEW the split would raise goes silent
#   L3  ledger-reverify  core_map ls-tree         a PARTIAL listing passes the emptiness guard
#                        -> STILL-LIVE "consumer-owned", the bucket-2 all-clear
#   P1  preclassify      orphan-pass find         a failed walk = "no orphan here"
#                        -> rc 0 with zero O rows
#   E1  emit-report      --verify set difference  a failed want side = every approved row
#                        resolved -> exit 3 BLOCKERS-RESOLVED
#   S1  self-update-gate arm R1 comm              a failed difference = "no anchor missing"
#                        -> SELF-UPDATE-OK, record `# verdict: OK`
#   S2  self-update-gate GATING grep -Fxf         grep's exit 2 swallowed by `|| true`
#                        -> SELF-UPDATE-OK, record `# verdict: OK`
#   S3  self-update-gate changed-script git diff  a failed diff = "changes no core/scripts/ path"
#                        -> SELF-UPDATE-OK, record `# verdict: OK`
#   U1  unregistered-drift  empty scan set        grep's 1 for "no .md/.sh/.json" became the
#                        script's exit -> rc 1, which emit-report renders DETECTOR-REFUSED
#   U2  unregistered-drift  both listings fail    rc 1 with no row, where the contract is 0 always
#                        and a named HARD-DRIFT-SCAN-UNAVAILABLE row
#   U3  unregistered-drift  file-type grep exit 2 rc 2 with no row
#   U4  unregistered-drift  prefix grep exit 2    the base FELL BACK to the direct listing and
#                        scanned; the staged spelling refuses instead (safe direction, same shape
#                        at base and tip on U2b below, so U4's base shape is SCANNED)
#   U2b unregistered-drift  memo listing alone fails -- the NEAR-MISS for U2: the direct listing
#                        still answers, so the scan must still run. A refusal keyed on the memo's
#                        failure alone would pass U2 and fail here.
#   U5  unregistered-drift  stdout CLOSED         the HARD row cannot be written -> rc 0 with the
#                        row gone; now rc 2 and one named `unregistered-drift: REFUSED` line
#   U5b unregistered-drift  EFBIG mid-stream      20 rows, then the HARD row last, into a 1 KiB file
#                        -> rc 0 with the HARD row lost; now rc 2 and the named line. The case a
#                        one-shot probe of stdout at start cannot see.
#   U6  unregistered-drift  memo SERVE fails      the cached listing's `cat` fails -> the cached 0
#   (-hit, -fill)        was returned, the scan set was empty, rc 0 with no row; now 125, the
#                        direct listing runs and the file is scanned. One cell per code path.
#   L5  layer-drift      stdout CLOSED, a HARD-LAYER-ADJUDICATION-MISSING world -> rc 0 with every
#                        row gone; now rc 2 and one `layer-drift: REFUSED` line naming N=0
#   L5c layer-drift      the same, --list-adjudications: its listing is the writer -> rc 0; now rc 2
#   L5b layer-drift      EFBIG mid-stream (`ulimit -f`, SIGXFSZ ignored), the cut inside an
#                        EXTENSION-OK row with more entries after it -> rc 0, the HARD row lost; now
#                        rc 2, N == the whole rows in the file, and ZERO outer-loop iterations after
#                        the first write error. The case a one-shot probe of stdout cannot see.
#   L5b-hard             the cut inside the HARD row itself, written LAST by `emit_raw` -> rc 0; now
#                        rc 2. The only cell whose one failed write is emit_raw's.
#   L5d layer-drift      an overrides-only world whose FINAL rows are an OVERRIDE-DOUBLE-SHADOW
#                        pair, the cut inside that pair -> rc 0; now rc 2. The block's emit used to
#                        run inside `| while | while`, where its count is thrown away.
#   L5e layer-drift      the same world, the cut inside an OVERRIDE-OK row with more overrides after
#                        it: the OVERRIDES loop's own stop, which L5b (extensions) cannot see.
#   L5-pre               THE PRECONDITION: a world whose layer-contract.yaml is larger than the limit.
#                        bash 3.2 writes a here-string to a temp file under the same limit, and the
#                        a0a9c556 engine read the contract through `<<<`: a failed one read as an
#                        EMPTY contract (no HARD row, rc 0, for a reason that is not the emit). On
#                        that engine this cell must read BROKEN-HEREDOC, proving the detector the
#                        L5b/L5d cells refuse on can fire; any OTHER cell reading it ends the fixture
#                        FIXTURE BROKEN, never a verdict. The tip carries no here-string (BL-359) and
#                        refuses naming the contract read instead: REFUSED-CONTRACT.
#   C*  layer-drift      BL-359: an input the engine used to read through a `<<<` that could not be
#                        staged, read as EMPTY at rc 0. Each cell's base shape is that silent read.
#   C1                   the contract larger than the limit, every other write under it, cold memo
#                        -> rc 0 with no HARD row; now a refusal naming the contract read.
#   C1w                  the same with a WARM memo, so the contract reaches the engine with no file
#                        written: the tip classifies in full under the limit, base still loses it.
#                        The discriminating input for M3 (the awk fed by `<<<` again).
#   C4                   C1's world and limit, --adjudicated-codes -> rc 0 and an EMPTY code set,
#                        which that mode documents as a legitimate answer; now a refusal.
#   C2                   an override whose shadow target at theirs is larger than the limit, cold
#                        memo -> OVERRIDE-OK read as OVERRIDE-DRIFT-FILE at rc 0 (the consumer's
#                        measured exposure); now a refusal naming the target read.
#   C2w                  the same, warm memo: the target's STAGING write is the first to fail.
#                        The discriminating input for M1 (the staging write's status ignored).
#   C2s                  C2's world, no limit, `section_of`'s own mktemp copy failed by a stub ->
#                        OVERRIDE-DRIFT-FILE; now a refusal naming section_of. C2 and C2w refuse
#                        at the read or the staging BEFORE section_of runs, so neither can see M4.
#   C3                   an `awk` stub that reads the contract program's input and prints nothing
#                        -> the tier switched off at rc 0; now the R2 post-condition refuses.
#   C5-ld hard-blockers  --ld-rows supplied with --ld-rc 2 -> `0 HARD blockers.` over a partial
#                        list; now the DETECTOR-REFUSED row and no affirmative line.
#   C5-ud hard-blockers  --ud-rows supplied with --ud-rc 2 -> `0 HARD blockers.`; now neither the
#                        affirmative line nor a second refusal row (emit-report renders that one).
#   SPELL                layer-drift.sh carries no non-comment `<<<`, probed both ways first.
#   A*  apply.sh         each of the four detectors it consults, and the scan-unavailable row:
#                        a refusal (exit 2, reason on stderr) read as "found nothing" -> no row.
#                        Now a `DECISION <detector>-refused` row carrying the exit and the first
#                        stderr line; for retired-tokens the `WORKLIST semantic-merge` stands.
#
# EACH ARM IS FORCED WITH A PATH STUB, NEVER SAMPLED. The stub fails ONE call shape and execs
# the real binary for every other call, and it appends a line to its own FIRED file per call it
# claims. Every forced arm requires FIRED > 0: a stub that stopped matching the engine's call
# shape would otherwise read exactly like an engine that stopped refusing -- or, under a mutant,
# like a kill. Every forced arm is paired with a NO-STUB control over the same world, which must
# reach that world's ordinary verdict, so the world is shown to express the case before the
# forced run is read.
#
# WHY S1, S2 AND E1 FAIL THE READER AND NOT THE PRODUCER. Their `<( )` producers were the
# `printf` BUILTIN, which no PATH stub can reach. What the base spelling lost there was the
# reader's own status (`comm`'s, `grep`'s) or a `sed` running INSIDE the substitution, so those
# are what the stubs fail. E1's stub fails `norm_rows`' sed only when its input LACKS this world's
# hand-edit marker, which selects the fresh render's side (the report's side carries the marker):
# failing both sides leaves both sets empty, which reads UNDECIDED at base too and discriminates
# nothing.
#
# SHAPES, NOT PASS/FAIL. Every arm classifies its run into a named SHAPE, and the expectation
# table below names the shape the fixed code must produce (tip) and the one the base spelling
# produces (base). Run on the four scripts as they stood at the parent release, every forced arm
# reports its base shape. A MUTANT IS KILLED ONLY WHEN ITS OWN ARM REPORTS THE BASE SHAPE, never
# merely when the arm fails: every base shape is presence-shaped (a named row, a record verdict,
# exit 3, a non-O row), so a mutant copy that died on its own -- a lib.sh it could not source --
# cannot score a kill. A mutant must also leave every OTHER arm of its script at the tip shape,
# or two arms are entangled.
#
# MUTANTS restore ONE site's base block verbatim in a copy of the WHOLE reconcile/ directory
# (these scripts resolve lib.sh and each other beside themselves). Each mutation's anchors are
# counted exactly once before it is applied, the copy must differ (`cmp -s`), must parse
# (`bash -n`), and must carry the base spelling once and the staged spelling zero times.
set -uo pipefail

# HERMETIC -- scrub the operator's tuning before invoking any reconcile script (I10).
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
# DISTRIBUTION-ONLY (see .dist-only), so one layout. The tree top is NOT spelled `$ROOT`:
# self-update-gate.sh's arm R2 scans every distribution fixture for a rulebook path beside a
# `$ROOT`-family variable and defers a pull that changes rulebook when one matches. This file names
# `skills/ai-dlc/steps/` only inside the synthetic gate worlds below, never in the live tree, so a
# match here would be a false rulebook coupling.
TREE_TOP="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
RECON="$TREE_TOP/core/skills/ai-dlc-update/reconcile"
[ -n "$TREE_TOP" ] && [ -f "$RECON/ledger-reverify.sh" ] \
  || { echo "FIXTURE ERROR: core/skills/ai-dlc-update/reconcile/ledger-reverify.sh not found — this fixture is distribution-only" >&2; exit 2; }
for _s in ledger-reverify.sh preclassify.sh emit-report.sh self-update-gate.sh lib.sh apply.sh \
          unregistered-drift.sh retired-tokens.sh retired-layer-passage.sh layer-drift.sh; do
  [ -f "$RECON/$_s" ] || { echo "FIXTURE ERROR: reconcile/$_s is missing beside ledger-reverify.sh" >&2; exit 2; }
done
SIB="$HERE/../reconcile-emit-report"
[ -f "$SIB/seed.sh" ] || { echo "FIXTURE ERROR: sibling reconcile-emit-report/seed.sh not found beside this unit" >&2; exit 2; }

REAL_TR="$(command -v tr)"; REAL_GIT="$(command -v git)"; REAL_FIND="$(command -v find)"
REAL_SED="$(command -v sed)"; REAL_COMM="$(command -v comm)"; REAL_GREP="$(command -v grep)"
REAL_BASH="$(command -v bash)"; REAL_CAT="$(command -v cat)"
REAL_AWK="$(command -v awk)"; REAL_MKTEMP="$(command -v mktemp)"
for _b in "$REAL_TR" "$REAL_GIT" "$REAL_FIND" "$REAL_SED" "$REAL_COMM" "$REAL_GREP" "$REAL_BASH" "$REAL_CAT" "$REAL_AWK" "$REAL_MKTEMP"; do
  case "$_b" in /*) ;; *) echo "FIXTURE ERROR: tr/git/find/sed/comm/grep/bash/cat/awk/mktemp must resolve to binaries on PATH (got '$_b'), or no stub can pass through" >&2; exit 2 ;; esac
done

WORK="$(mktemp -d "${TMPDIR:-/tmp}/psb-boot.XXXXXX")" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd)"
EW=""
# A RUN THAT NEVER REACHED ITS VERDICT EXITS 2. A `set -u` abort mid-battery reaches this trap with
# `$?` = 0 on bash 3.2 (measured: the fixture exited 0 over an unbound-variable abort, every later
# mutant unscored), so the status cannot be recovered here -- only the flag the verdict sets can say
# whether the run got that far.
PSB_DONE=0
trap 'rm -rf "$WORK"; [ -n "$EW" ] && rm -rf "$EW"; [ "$PSB_DONE" = 1 ] || { echo "FIXTURE BROKEN: procsub-staged-refusal-boot stopped before its verdict" >&2; exit 2; }' EXIT

fails=0; asserts=0
ok()  { printf '  ok    %s\n' "$1"; asserts=$((asserts+1)); }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); asserts=$((asserts+1)); }
# ---------------------------------------------------------------------------- shards ----
# THIS FILE IS THREE SHARDS OF ONE FIXTURE, AND THE SPLIT IS A SCHEDULING BOUNDARY, NOT A SUBJECT
# BOUNDARY. Every assertion-bearing section below is a UNIT guarded by `if sg <unit>; then ... fi`, or, for
# the control/forced loop, by the key-to-unit map; `--group <x>` runs the units dealt to shard <x>. The two
# siblings `procsub-staged-refusal-boot-{b,c}/run.sh` are one-line drivers that `exec bash` this file with
# their group (the readset-skip shape), so the pre-push pool starts each on its own. No `--group` runs
# shard 'a', so `bash core/fixtures/procsub-staged-refusal-boot/run.sh` is shard a.
#
# THE WORLDS, THE SHARED HELPERS AND THE STAGED PRE-FIX ENGINES ARE NOT UNITS: every shard builds them,
# because the units read each other's worlds (hb reads the ld ext world's rows, b360 the ld block size).
#   a  lrpe ud      ledger-reverify, preclassify, emit-report --verify, self-update-gate; unregistered-drift
#   b  ld b360      layer-drift L cells and mutants; the BL-360 emit-report cells and mutants
#   c  lc ap spell  the BL-359 C cells and mutants, hard-blockers; apply.sh; the two preclassify/layer-drift spell probes
# A unit may carry several guards (ld has three); the declared set is the DISTINCT names.
SHARDS="a b c"
UNITS_a="lrpe ud"
UNITS_b="ld b360"
UNITS_c="lc ap spell"
GROUP=a
if [ "${1:-}" = "--group" ]; then
  GROUP="${2:-}"
  [ -n "$GROUP" ] || { echo "FIXTURE ERROR: --group needs a shard name" >&2; exit 2; }
fi
case " $SHARDS " in
  *" $GROUP "*) ;;
  *) echo "FIXTURE ERROR: unknown shard '$GROUP' (known: $SHARDS)" >&2; exit 2 ;;
esac
eval "MINE=\"\${UNITS_$GROUP:-}\""
NAME="procsub-staged-refusal-boot"; [ "$GROUP" = a ] || NAME="procsub-staged-refusal-boot-$GROUP"
[ -n "$MINE" ] || { echo "FIXTURE ERROR: shard '$GROUP' has no UNITS_$GROUP list; a shard dealt nothing passes everything it never checked" >&2; exit 2; }
sg() { case " $MINE " in *" $1 "*) return 0 ;; esac; return 1; }
# unit_of_key <EXPECT key> -> the unit that owns the control and forced arms of that key
unit_of_key() {
  case "$1" in
    lr|pc|pm|er|sg) echo lrpe ;;
    ud) echo ud ;;
    ap) echo ap ;;
    ld) echo ld ;;
    lc|lo|hb) echo lc ;;
    *) echo "unit-of-$1-unknown" ;;
  esac
}
SELF="$0"
[ -f "$SELF" ] || { echo "FIXTURE ERROR: cannot read $SELF for the coverage join" >&2; exit 2; }
partition_ok() { # <declared ids file> <dealt ids file> -> 0 when dealt is disjoint and covers declared exactly
  local dup miss extra
  dup="$(sort "$2" | uniq -d | tr '\n' ' ')"
  miss="$(sort -u "$2" | comm -23 <(sort -u "$1") - | tr '\n' ' ')"
  extra="$(sort -u "$2" | comm -13 <(sort -u "$1") - | tr '\n' ' ')"
  [ -z "$dup$miss$extra" ] && return 0
  echo "dealt twice: {${dup% }} dealt to no shard: {${miss% }} dealt but not declared: {${extra% }}"
  return 1
}
JW="$WORK/join"; mkdir -p "$JW" || { echo "FIXTURE ERROR: mkdir join" >&2; exit 2; }
printf '%s\n' u1 u2 u3 > "$JW/pd"; printf '%s\n' u1 u2 u2 u3 > "$JW/pdup"; printf '%s\n' u1 u3 > "$JW/pmiss"; printf '%s\n' u3 u1 u2 > "$JW/pok"
if partition_ok "$JW/pd" "$JW/pdup" >/dev/null || partition_ok "$JW/pd" "$JW/pmiss" >/dev/null \
   || ! partition_ok "$JW/pd" "$JW/pok" >/dev/null; then
  echo "FIXTURE ERROR: the coverage join's self-probe did not discriminate (duplicate, omission, exact)" >&2; exit 2
fi
sed -n 's/^[[:space:]]*if sg \([a-z0-9_][a-z0-9_]*\); then$/\1/p' "$SELF" | sort -u > "$JW/declared"
for _s in $SHARDS; do eval "printf '%s\n' \${UNITS_$_s}" | tr ' ' '\n'; done | grep . > "$JW/dealt"
ndecl="$(grep -c . "$JW/declared")" || ndecl=0
if [ "$ndecl" -eq 0 ]; then
  echo "FIXTURE ERROR: 0 unit guards derived from $SELF" >&2; exit 2
fi
# THE KEY MAP MUST NAME A DECLARED UNIT FOR EVERY EXPECT KEY, or a key's control arms run in no shard.
if ! _why="$(partition_ok "$JW/declared" "$JW/dealt")"; then
  echo "FIXTURE ERROR: the shard partition does not cover the guarded units exactly -- $_why" >&2; exit 2
fi
for _s in $SHARDS; do
  [ "$_s" = a ] && continue
  _drv="$HERE/../procsub-staged-refusal-boot-$_s/run.sh"
  if [ ! -f "$_drv" ] || ! grep -qF -- "--group $_s" "$_drv"; then
    echo "FIXTURE ERROR: shard '$_s' is declared but $_drv does not drive it" >&2; exit 2
  fi
done
echo "  [J0] coverage join: $ndecl units derived from the sg guards, dealt disjointly across {$SHARDS}, union exact; this shard runs {$MINE}"
echo "$NAME:"

# --- STUBS ---------------------------------------------------------------------------------------
# stub <dir> <tool> <real-binary> <case-pattern over "$*"> <action>
# The action runs only for a call whose joined arguments match the pattern; it must log to "$F"
# itself, so a stub whose action passes through (E1's other side) logs nothing it did not fail.
stub() {
  local d="$1" t="$2" real="$3" pat="$4" act="$5"
  mkdir -p "$d"; : > "$d/FIRED"
  {
    printf '#!/bin/sh\nF="%s/FIRED"\n' "$d"
    printf 'case "$*" in\n  %s)\n    %s ;;\nesac\n' "$pat" "$act"
    printf 'exec "%s" "$@"\n' "$real"
  } > "$d/$t"
  chmod +x "$d/$t"
}
fired() { local n; n="$("$REAL_GREP" -c . "$1/FIRED" 2>/dev/null)" || n=0; printf '%s' "$n"; }
LOGF='echo "$*" >> "$F"'
# mkstub_for <arm> <dir>: the one stub each forced arm uses.
mkstub_for() {
  case "$1" in
    L1|L2) stub "$2" tr "$REAL_TR" "'-c A-Za-z0-9_./\$- '*" "$LOGF; exit 1" ;;
    L3)    stub "$2" git "$REAL_GIT" "*' ls-tree -r --name-only '*' -- core/'" \
             "$LOGF; \"$REAL_GIT\" \"\$@\" | head -n 1; exit 1" ;;
    P1)    stub "$2" find "$REAL_FIND" "*'/.claude/fixtures -type f'" "$LOGF; echo 'find: forced failure' >&2; exit 1" ;;
    # P2 / P3 fail nothing: their forcing input is the file-size limit pm_shape runs them under. The
    # stub logs the subject's own blob lookup, so FIRED > 0 proves the run reached the bucket arm.
    # It logs one short word, never "$*": the FIRED file is a regular file under the same limit.
    P2)    stub "$2" git "$REAL_GIT" "*' rev-parse -q --verify '*':core/zz-psb-sited/new-sited.md'" "echo x >> \"\$F\"" ;;
    P3)    stub "$2" git "$REAL_GIT" "*' rev-parse -q --verify '*':core/skills/ai-dlc-update/zz-psb-subject.md'" "echo x >> \"\$F\"" ;;
    E1)    stub "$2" sed "$REAL_SED" "'-E s/[[:space:]]+/ /g'" \
             "t=\"\$(mktemp)\" || exit 3; cat > \"\$t\"; if \"$REAL_GREP\" -q ZZ-PSB-HAND-EDIT \"\$t\"; then \"$REAL_SED\" \"\$@\" < \"\$t\"; r=\$?; rm -f \"\$t\"; exit \$r; fi; rm -f \"\$t\"; $LOGF; exit 2" ;;
    S1)    stub "$2" comm "$REAL_COMM" "'-23 '*" "$LOGF; echo 'comm: forced failure' >&2; exit 2" ;;
    S2)    stub "$2" grep "$REAL_GREP" "'-Fxf '*" "$LOGF; echo 'grep: forced failure' >&2; exit 2" ;;
    S3)    stub "$2" git "$REAL_GIT" "*' diff --name-only '*' -- core/scripts/'" "$LOGF; echo 'fatal: forced failure' >&2; exit 2" ;;
    # U1 FAILS NOTHING: its discriminating input is the WORLD. The stub only logs the listing and
    # passes through, so FIRED > 0 proves the run reached the scan rather than dying before it.
    U1)    stub "$2" git "$REAL_GIT" "*' ls-tree '*" "$LOGF" ;;
    U2)    stub "$2" git "$REAL_GIT" "*' ls-tree '*" "$LOGF; echo 'fatal: forced failure' >&2; exit 128" ;;
    # The memo's call shape alone: the full listing ENDS at the ref, the direct one carries ` -- `.
    U2b)   stub "$2" git "$REAL_GIT" "*' ls-tree -r --name-only $(cat "$UW_OK/B")'" "$LOGF; echo 'fatal: forced failure' >&2; exit 128" ;;
    U3)    stub "$2" grep "$REAL_GREP" "*'(md|sh|json)'*" "$LOGF; echo 'grep: forced failure' >&2; exit 2" ;;
    U4)    stub "$2" grep "$REAL_GREP" "*'core/team-roles/|core/hooks/'*" "$LOGF; echo 'grep: forced failure' >&2; exit 2" ;;
    # U5 and U5b fail nothing either: their forcing input is the CLOSED STDOUT, or the 1 KiB
    # file-size limit, that ud_shape runs them under. The stub proves the run reached the listing.
    U5|U5b) stub "$2" git "$REAL_GIT" "*' ls-tree '*" "$LOGF" ;;
    # U6: the memo's serve of the cached ls-tree listing -- the `t <dist> <ref>` key's `.c` file --
    # exits 1 with no output. lib.sh calls `cat` by bare name, so the PATH stub reaches it.
    U6-hit|U6-fill) stub "$2" cat "$REAL_CAT" "*'/t '*'.c'" "$LOGF; exit 1" ;;
    # The L cells fail nothing: their forcing input is the closed stdout or the file-size limit
    # ld_shape runs them under. The stub logs layer_files' walk, so FIRED > 0 proves the run reached it.
    L5|L5c|L5b|L5b-hard|L5d|L5e) stub "$2" find "$REAL_FIND" "*' -type f -name '*" "$LOGF" ;;
    # L5-pre, C1, C4: the tip refuses at the contract read, BEFORE layer_files' walk, so the stub
    # logs the read itself -- a cold memo's fill runs `git show` of the contract.
    L5-pre|C1|C4) stub "$2" git "$REAL_GIT" "*' show '*':core/skills/ai-dlc/layer-contract.yaml'" "$LOGF" ;;
    # C1w / C2w: a WARM memo serves the blob with `cat` of its `.c` file and runs no git at all.
    C1w)   stub "$2" cat "$REAL_CAT" "*'layer-contract.yaml.c'" "$LOGF" ;;
    C2)    stub "$2" git "$REAL_GIT" "*' show '*':core/skills/ai-dlc/steps/zz-psb-huge.md'" "$LOGF" ;;
    C2w)   stub "$2" cat "$REAL_CAT" "*'zz-psb-huge.md.c'" "$LOGF" ;;
    # C2s: `mktemp` with NO argument is section_of's copy of its stdin (lib.sh); the staging
    # directory and the memo pass arguments and reach the real binary.
    C2s)   stub "$2" mktemp "$REAL_MKTEMP" "''" "echo mktemp-no-args >> \"\$F\"; exit 1" ;;
    # C3: the ADJUDICATED code-set program alone (the only awk program carrying this comparison).
    # It READS its input, so the writer cannot EPIPE, and prints nothing: a reader that did not read.
    C3)    stub "$2" awk "$REAL_AWK" "*'lvl == \"ADJUDICATED\"'*" "echo contract-program >> \"\$F\"; cat > /dev/null; exit 0" ;;
    C5-ld|C5-ud) stub "$2" cat "$REAL_CAT" "*'/hb-rows-'*" "$LOGF" ;;
    Aud)   ap_stub "$2" unregistered-drift ;;
    Art)   ap_stub "$2" retired-tokens ;;
    Arlp)  ap_stub "$2" retired-layer-passage ;;
    Ald)   ap_stub "$2" layer-drift ;;
    Ana)   stub "$2" bash "$REAL_BASH" "*'/unregistered-drift.sh '*" \
             "$LOGF; printf 'HARD-DRIFT-SCAN-UNAVAILABLE\\tcore/\\tZZ-PSB-NA-DETAIL forced\\n'; exit 0" ;;
  esac
}
# ap_stub <dir> <detector>: `bash <reconcile>/<detector>.sh …` refuses the way a detector does --
# exit 2, empty stdout, the reason on stderr -- and every other `bash` call passes through.
ap_stub() {
  stub "$1" bash "$REAL_BASH" "*'/$2.sh '*" "$LOGF; echo 'ZZ-PSB-STDERR-$2 forced refusal' >&2; exit 2"
}

gi() { git -C "$1" -c user.email=f@f -c user.name=fixture -c commit.gpgsign=false "${@:2}"; }

# === WORLD lr: ledger-reverify ====================================================================
# One core subject that upstream ships and moves (validate-thing.sh), and `aaa-first.md`, which
# sorts FIRST in theirs' `core/` listing: L3's stub hands the reader that one line and fails, so
# the partial table the base spelling accepted lacks the subject.
LW="$WORK/lw"; LD="$LW/dist"; LC="$LW/consumer"
mkdir -p "$LD/core/scripts" "$LC/scripts/ai-dlc"
printf '0.1.0\n' > "$LD/VERSION"
printf 'first\n' > "$LD/core/aaa-first.md"
printf '#!/bin/bash\nrun_thing() { :; }\n' > "$LD/core/scripts/validate-thing.sh"
{ gi "$LD" init -q && gi "$LD" add -A && gi "$LD" commit -qm base; } >/dev/null 2>&1 || { echo "FIXTURE ERROR: lr dist base" >&2; exit 2; }
LB="$(git -C "$LD" rev-parse HEAD)"
printf '0.2.0\n' > "$LD/VERSION"
printf '# theirs moved\n' >> "$LD/core/scripts/validate-thing.sh"
{ gi "$LD" add -A && gi "$LD" commit -qm theirs; } >/dev/null 2>&1 || { echo "FIXTURE ERROR: lr dist theirs" >&2; exit 2; }
LT="$(git -C "$LD" rev-parse HEAD)"
git -C "$LD" show "${LB}:core/scripts/validate-thing.sh" > "$LC/scripts/ai-dlc/validate-thing.sh"
printf '#!/bin/bash\necho keep\n' > "$LC/scripts/keep.sh"
{ gi "$LC" init -q && gi "$LC" add -A && gi "$LC" commit -qm consumer; } >/dev/null 2>&1 || { echo "FIXTURE ERROR: lr consumer" >&2; exit 2; }
# L1: the receipt exits non-zero (grep on a file that is not there) and NAMES that missing file,
# so the healthy reading is NEEDS-REVIEW "DO NOT EXIST", never a close.
cat > "$LW/ledger-absent.md" <<'EOM'
## PSB-ABSENT — a receipt whose subject moved away

verify: sh cd "$CONSUMER" && grep -q psb_needle scripts/psb-moved-away.sh

---
EOM
# L2/L3: the receipt exits 0, names neither $THEIRS nor $DIST, and reads a file upstream SHIPS,
# so the healthy reading is NEEDS-REVIEW "unfalsifiable predicate:" (bucket 3).
cat > "$LW/ledger-named.md" <<'EOM'
## PSB-NAMED — a receipt that reads only the installed copy of a shipped file

verify: sh cd "$CONSUMER" && [ -f scripts/ai-dlc/validate-thing.sh ] && ! grep -q ZZ_PSB_NEVER scripts/ai-dlc/validate-thing.sh

---
EOM
[ "$(git -C "$LD" ls-tree -r --name-only "$LT" -- core/ | head -n 1)" = core/aaa-first.md ] \
  || { echo "FIXTURE ERROR: lr world: core/aaa-first.md is not the first entry of theirs' core/ listing, so L3's partial table would carry the subject" >&2; exit 2; }

# lr_shape <recon> <arm> <stub-dir or -> -> prints the SHAPE of one ledger-reverify run
lr_shape() {
  local recon="$1" arm="$2" sd="$3" led label out err rc row det p="$PATH"
  case "$arm" in L1) led="$LW/ledger-absent.md"; label=PSB-ABSENT ;; *) led="$LW/ledger-named.md"; label=PSB-NAMED ;; esac
  [ "$sd" = - ] || p="$sd:$PATH"
  err="$WORK/lr.err.$$"
  out="$(PATH="$p" bash "$recon/ledger-reverify.sh" "$LD" "$LB" "$LC" "$LT" "$led" 2>"$err")"; rc=$?
  row="$(awk -F'\t' -v l="$label" '$2==l {print $1; exit}' <<<"$out")"
  det="$(awk -F'\t' -v l="$label" '$2==l {print $3; exit}' <<<"$out")"
  if [ "$rc" -eq 2 ] && [ -z "$row" ] && "$REAL_GREP" -qF 'receipt_absent_subjects returned' "$err"; then echo REFUSED-ABSENT
  elif [ "$rc" -eq 2 ] && [ -z "$row" ] && "$REAL_GREP" -qF 'receipt_named_subjects returned' "$err"; then echo REFUSED-NAMED
  elif [ "$rc" -eq 0 ] && [ "$row" = CLOSE-CANDIDATE ]; then echo CLOSE-CANDIDATE
  elif [ "$rc" -eq 0 ] && [ "$row" = NEEDS-REVIEW ] && grep -qF 'DO NOT EXIST' <<<"$det"; then echo NEEDS-REVIEW-ABSENT
  elif [ "$rc" -eq 0 ] && [ "$row" = NEEDS-REVIEW ] && grep -qF 'unfalsifiable predicate:' <<<"$det"; then echo NEEDS-REVIEW-UNFALSIFIABLE
  elif [ "$rc" -eq 0 ] && [ "$row" = STILL-LIVE ] && grep -qF 'names no path-shaped subject' <<<"$det"; then echo STILL-LIVE-NO-SUBJECT
  elif [ "$rc" -eq 0 ] && [ "$row" = STILL-LIVE ] && grep -qF "'git ls-tree -r" <<<"$det" && grep -qF 'failed in' <<<"$det"; then echo STILL-LIVE-LSTREE-FAILED
  elif [ "$rc" -eq 0 ] && [ "$row" = STILL-LIVE ] && grep -qF 'CONSUMER-OWNED' <<<"$det"; then echo STILL-LIVE-CONSUMER-OWNED
  else echo "OTHER(rc=$rc,row=${row:-none})"
  fi
  rm -f "$err"
}

# === WORLD pc: preclassify ========================================================================
# A consumer holding a pre-0.49.0 copy of a core fixture at `.claude/fixtures/`, byte-identical to
# base: the orphan pass must report it. core/rules/r.md moves base->theirs so the changed-files
# pass emits a non-O row -- the positive conjunct that separates "ran, found no orphan" (base
# shape) from a copy that never ran.
PW="$WORK/pw"; PD="$PW/dist"; PC="$PW/consumer"
mkdir -p "$PD/core/fixtures/old" "$PD/core/rules" "$PC/.claude/fixtures/old" "$PC/.claude/rules"
printf '0.1.0\n' > "$PD/VERSION"
printf '#!/usr/bin/env bash\necho old\n' > "$PD/core/fixtures/old/run.sh"
printf 'rule base\n' > "$PD/core/rules/r.md"
{ gi "$PD" init -q && gi "$PD" add -A && gi "$PD" commit -qm base; } >/dev/null 2>&1 || { echo "FIXTURE ERROR: pc dist base" >&2; exit 2; }
PB="$(git -C "$PD" rev-parse HEAD)"
printf '0.2.0\n' > "$PD/VERSION"; printf 'rule theirs\n' > "$PD/core/rules/r.md"
{ gi "$PD" add -A && gi "$PD" commit -qm theirs; } >/dev/null 2>&1 || { echo "FIXTURE ERROR: pc dist theirs" >&2; exit 2; }
PT="$(git -C "$PD" rev-parse HEAD)"
cp "$PD/core/fixtures/old/run.sh" "$PC/.claude/fixtures/old/run.sh"
git -C "$PD" show "${PB}:core/rules/r.md" > "$PC/.claude/rules/r.md"
printf 'version: 0.1.0\ncommit: %s\n' "$PB" > "$PC/.claude/.ai-dlc-version"

pc_shape() { # <recon> <stub-dir or ->
  local p="$PATH" out err rc no nn
  [ "$2" = - ] || p="$2:$PATH"
  err="$WORK/pc.err.$$"
  out="$(PATH="$p" bash "$1/preclassify.sh" "$PD" "$PB" "$PT" "$PC" 2>"$err")"; rc=$?
  no="$(awk -F'\t' '$1=="O"' <<<"$out" | "$REAL_GREP" -c .)" || no=0
  nn="$(awk -F'\t' 'NF>=4 && $1!="O"' <<<"$out" | "$REAL_GREP" -c .)" || nn=0
  if [ "$rc" -eq 2 ] && "$REAL_GREP" -qF 'the orphan walk of' "$err" && "$REAL_GREP" -qF 'did not complete' "$err"; then echo REFUSED
  elif [ "$rc" -eq 0 ] && [ "$no" -eq 0 ] && [ "$nn" -gt 0 ]; then echo NO-ORPHAN-ROWS
  elif [ "$rc" -eq 0 ] && [ "$no" -gt 0 ]; then echo ORPHAN-ROWS
  else echo "OTHER(rc=$rc,O=$no,other=$nn)"
  fi
  rm -f "$err"
}

# === WORLDS pm: preclassify's two whole-line MEMBERSHIP tests (BL-360) ============================
# `setup_sited` and `is_machinery` were `grep -qxF` fed by a here-string and a heredoc. Under
# `trap '' XFSZ; ulimit -f 1` a haystack past one block cannot be staged, grep never runs, and the
# test answers "not a member" at rc 0 -- so the run buckets a path wrong and exits clean.
#   P2  a NEW upstream file declared setup-sited, consumer lacks it. Healthy
#       `UPSTREAM-ONLY-ADD+SETUP-TOKENS->SUBSTITUTE`; base under the limit `UPSTREAM-ONLY-ADD`.
#       The haystack is read out of `setup-sites.md` BESIDE the engine, so every run gets its own
#       copy of the recon directory with forty padding paths and the subject appended LAST.
#   P3  a machinery file (`core/skills/ai-dlc-update/**`) whose consumer copy is the distribution's
#       blob at the consumer's own `skill_commit`, neither base nor theirs. Healthy `UPSTREAM-ONLY`;
#       base under the limit `BOTH-CHANGED->CLASSIFY`. Thirty long-named machinery paddings make the
#       machinery listing larger than one block.
# Every OTHER file the run writes under the limit -- the staged relocation listing and changed rows,
# the memo's sha files -- is far below one block, so the membership haystack is the only input the
# limit can take. The tip's forced reading being the HEALTHY one is what shows that.
PMW_S="$WORK/pmw-s"; PMW_M="$WORK/pmw-m"
mk_pm_world() { # <dir> <s|m>
  local W="$1" D="$1/dist" C="$1/consumer" i
  mkdir -p "$D/core/rules" "$C/.claude" || return 1
  printf '0.1.0\n' > "$D/VERSION"; printf 'rule\n' > "$D/core/rules/keep.md"
  if [ "$2" = m ]; then
    mkdir -p "$D/core/skills/ai-dlc-update/zz-psb-pad" "$C/.claude/skills/ai-dlc-update" || return 1
    i=0; while [ "$i" -lt 30 ]; do
      printf 'pad\n' > "$D/core/skills/ai-dlc-update/zz-psb-pad/a-machinery-padding-file-whose-name-is-long-$(printf '%03d' "$i").md"
      i=$((i+1)); done
    printf 'v1\n' > "$D/core/skills/ai-dlc-update/zz-psb-subject.md"
  fi
  { gi "$D" init -q && gi "$D" add -A && gi "$D" commit -qm base; } >/dev/null 2>&1 || return 1
  git -C "$D" rev-parse HEAD > "$W/B"
  if [ "$2" = m ]; then
    printf 'v2\n' > "$D/core/skills/ai-dlc-update/zz-psb-subject.md"
    { gi "$D" add -A && gi "$D" commit -qm self-update; } >/dev/null 2>&1 || return 1
    git -C "$D" rev-parse HEAD > "$W/M"
    printf 'v3\n' > "$D/core/skills/ai-dlc-update/zz-psb-subject.md"
    printf 'v2\n' > "$C/.claude/skills/ai-dlc-update/zz-psb-subject.md"
    printf 'version: 0.1.0\ncommit: %s\nskill_commit: %s\n' "$(cat "$W/B")" "$(cat "$W/M")" > "$C/.claude/.ai-dlc-version"
  else
    mkdir -p "$D/core/zz-psb-sited" || return 1
    printf 'model: {model}\n' > "$D/core/zz-psb-sited/new-sited.md"
    printf 'version: 0.1.0\ncommit: %s\n' "$(cat "$W/B")" > "$C/.claude/.ai-dlc-version"
  fi
  printf '0.2.0\n' > "$D/VERSION"
  { gi "$D" add -A && gi "$D" commit -qm theirs; } >/dev/null 2>&1 || return 1
  git -C "$D" rev-parse HEAD > "$W/T"
}
mk_pm_world "$PMW_S" s || { echo "FIXTURE ERROR: pm sited world" >&2; exit 2; }
mk_pm_world "$PMW_M" m || { echo "FIXTURE ERROR: pm machinery world" >&2; exit 2; }
pm_sited_recon() { # <recon> -> a copy whose setup-sites.md declares the padding and the subject, LAST
  local d i=0
  d="$(mktemp -d "$WORK/pm-recon.XXXXXX")" || return 1
  cp -R "$1/." "$d/" || return 1
  { while [ "$i" -lt 40 ]; do
      printf '  file: core/zz-psb-pad/a-setup-sited-padding-path-whose-name-is-long-%03d.md\n' "$i"; i=$((i+1)); done
    printf '  file: core/zz-psb-sited/new-sited.md\n'; } >> "$d/setup-sites.md" || return 1
  printf '%s' "$d"
}
pm_shape() { # <recon> <P2|P3> <stub-dir or ->
  local R="$1" W p="$PATH" out err rc row nr hd hay subj healthy wrong hs ws
  [ "$3" = - ] || p="$3:$PATH"
  case "$2" in
    P2) W="$PMW_S"; subj=core/zz-psb-sited/new-sited.md
        healthy='UPSTREAM-ONLY-ADD+SETUP-TOKENS->SUBSTITUTE'; wrong=UPSTREAM-ONLY-ADD; hs=SITED; ws=UNSITED-HEREDOC
        R="$(pm_sited_recon "$1")" || { echo "OTHER(recon-copy)"; return 0; }
        hay="$(awk '/^[ \t]*file:[ \t]*core\//{sub(/^[ \t]*file:[ \t]*/,""); print}' "$R/setup-sites.md" | sort -u | wc -c | tr -d ' ')" ;;
    P3) W="$PMW_M"; subj=core/skills/ai-dlc-update/zz-psb-subject.md
        healthy=UPSTREAM-ONLY; wrong='BOTH-CHANGED->CLASSIFY'; hs=AT-SELF-UPDATE; ws=NOT-MACHINERY-HEREDOC
        hay="$(git -C "$W/dist" ls-files --with-tree="$(cat "$W/T")" -- 'core/skills/ai-dlc-update/**' | wc -c | tr -d ' ')" ;;
  esac
  out="$(mktemp "$WORK/pm-out.XXXXXX")" || { echo "OTHER(mktemp)"; return 0; }
  if [ "$3" = - ]; then
    err="$( ( PATH="$p"; export PATH
      exec "$REAL_BASH" "$R/preclassify.sh" "$W/dist" "$(cat "$W/B")" "$(cat "$W/T")" "$W/consumer" > "$out" ) 2>&1 )"; rc=$?
  else
    # SIGXFSZ ignored, so the staging write fails with EFBIG the way a full disk fails it. Stderr goes
    # to a PIPE, never to a file the limit binds.
    err="$( ( trap '' XFSZ; ulimit -f 1; PATH="$p"; export PATH
      exec "$REAL_BASH" "$R/preclassify.sh" "$W/dist" "$(cat "$W/B")" "$(cat "$W/T")" "$W/consumer" > "$out" ) 2>&1 )"; rc=$?
  fi
  row="$(awk -F'\t' -v s="$subj" '$2==s {print $4}' "$out")"
  nr="$(awk -F'\t' -v s="$subj" '$2==s' "$out" | "$REAL_GREP" -c .)" || nr=0
  hd="$("$REAL_GREP" -c 'cannot create temp file for here' <<<"$err")" || hd=0
  rm -f "$out"
  # THE CALIBRATION, read on the control: a haystack that fits in one block cannot be lost under
  # `ulimit -f 1`, and a forced run over it would read exactly like a fixed engine.
  # THE FORCED READING ACCEPTS EITHER CORRECT ANSWER, and names them as one shape. A conversion that
  # cannot lose its input reads the healthy bucket; a conversion that stages the haystack, reads the
  # write status and refuses through the engine's own `preclassify:` line is equally correct. A cell
  # demanding the first would fail a competent author's second spelling. The CONTROL still demands
  # the healthy bucket alone.
  if [ "$3" = - ] && [ "${hay:-0}" -le "$LD_BLK" ]; then echo "OTHER(calibration:haystack=${hay}B<=block=${LD_BLK}B)"
  elif [ "$rc" -eq 0 ] && [ "$nr" -eq 1 ] && [ "$row" = "$healthy" ] && [ "$hd" -eq 0 ]; then
    if [ "$3" = - ]; then echo "$hs"; else echo "$hs-OR-REFUSED"; fi
  elif [ "$3" != - ] && [ "$rc" -eq 2 ] && [ "$nr" -eq 0 ] && "$REAL_GREP" -q '^preclassify: ' <<<"$err"; then echo "$hs-OR-REFUSED"
  elif [ "$rc" -eq 0 ] && [ "$nr" -eq 1 ] && [ "$row" = "$wrong" ] && [ "$hd" -ge 1 ]; then echo "$ws"
  else echo "OTHER(rc=$rc,rows=$nr,bucket=${row:-none},heredoc=$hd)"
  fi
}

# === WORLD er: emit-report --verify ===============================================================
# The sibling's seed, and a report that is its approved region plus ONE line the detectors never
# render. Healthy, that is a mismatch with no HARD row gone: UNDECIDED (the generic cause). With the
# fresh render's side emptied, every approved row -- the HARD ones included -- reads as gone.
EW="$(bash "$SIB/seed.sh")" || { echo "FIXTURE ERROR: the sibling seed failed" >&2; exit 2; }
# shellcheck source=/dev/null
. "$EW/env.sh"
ER_REPORT="$WORK/report-hand-edited.md"
awk '/END GENERATED: reconcile-mechanical/ { print "ZZ-PSB-HAND-EDIT a line no detector renders" } { print }' "$REPORT_GOOD" > "$ER_REPORT"
_h="$("$REAL_GREP" -c '^HARD-' "$ER_REPORT")" || _h=0
_m="$("$REAL_GREP" -c '^ZZ-PSB-HAND-EDIT' "$ER_REPORT")" || _m=0
if [ "$_h" -lt 1 ] || [ "$_m" -ne 1 ]; then
  echo "FIXTURE ERROR: er world: the approved region carries $_h column-0 HARD row(s) (want >= 1) and $_m hand-edit marker(s) (want 1), so E1 cannot express a false BLOCKERS-RESOLVED" >&2; exit 2
fi
er_shape() { # <recon> <stub-dir or ->
  local p="$PATH" err rc
  [ "$2" = - ] || p="$2:$PATH"
  err="$WORK/er.err.$$"
  PATH="$p" bash "$1/emit-report.sh" --verify "$ER_REPORT" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" >/dev/null 2>"$err"; rc=$?
  if [ "$rc" -eq 1 ] && "$REAL_GREP" -qF 'cause: UNDECIDED — the region does not match, but which rows differ could not be computed' "$err"; then echo UNDECIDED-UNCOMPUTED
  elif [ "$rc" -eq 3 ] && "$REAL_GREP" -qF 'cause: BLOCKERS-RESOLVED' "$err"; then echo BLOCKERS-RESOLVED
  elif [ "$rc" -eq 1 ] && "$REAL_GREP" -qF 'cause: UNDECIDED — the fresh render carries' "$err"; then echo UNDECIDED-DIFF
  else echo "OTHER(rc=$rc)"
  fi
  rm -f "$err"
}

# === WORLDS sg: self-update-gate ==================================================================
# Two worlds, because an arm-R1 DEFER exits before the GATING intersection is ever read.
#   r1  theirs' gate-validation.md anchors `psb-b`, the consumer's does not; no core/scripts path
#       moves. Healthy: R1 DEFERs naming psb-b. Silenced: the gate falls through to "changes no
#       core/scripts/ path" -- OK.
#   gt  no gate-validation.md at all (R1 has no subject); the pull changes gate-defer.sh, which the
#       consumer's hook invokes, and the incoming copy exits 1 where the current exits 0. Healthy:
#       DEFER. Silenced: an empty intersection -- OK.
# Neither consumer is a git work tree, so the gate's enclosed-layout arm stays silent; the gate
# runs no pre-push hook in any world (the push wrapper owns that one run).
mk_gate_world() { # <dir> <r1|gt>
  local W="$1" D="$1/dist" C="$1/consumer"
  mkdir -p "$D/core/scripts" "$C/scripts/ai-dlc" "$C/.githooks"
  printf '0.1.0\n' > "$D/VERSION"
  if [ "$2" = r1 ]; then
    mkdir -p "$D/core/skills/ai-dlc/steps" "$C/.claude/skills/ai-dlc/steps"
    printf '#!/bin/sh\nexit 0\n' > "$D/core/scripts/keep.sh"
    printf '# gate\n<!-- CHECK_LOADED: psb-a -->\n' > "$D/core/skills/ai-dlc/steps/gate-validation.md"
  else
    printf '#!/bin/sh\nexit 0\n' > "$D/core/scripts/gate-defer.sh"
  fi
  { gi "$D" init -q && gi "$D" add -A && gi "$D" commit -qm base; } >/dev/null 2>&1 || return 1
  git -C "$D" rev-parse HEAD > "$W/B"
  printf '0.2.0\n' > "$D/VERSION"
  if [ "$2" = r1 ]; then
    printf '# gate\n<!-- CHECK_LOADED: psb-a -->\n<!-- CHECK_LOADED: psb-b -->\n' > "$D/core/skills/ai-dlc/steps/gate-validation.md"
    git -C "$D" show "$(cat "$W/B"):core/skills/ai-dlc/steps/gate-validation.md" > "$C/.claude/skills/ai-dlc/steps/gate-validation.md"
    cp "$D/core/scripts/keep.sh" "$C/scripts/ai-dlc/keep.sh"
    printf '#!/usr/bin/env bash\nbash scripts/ai-dlc/keep.sh\n' > "$C/.githooks/pre-push"
  else
    printf '#!/bin/sh\n# the incoming check finds something\nexit 1\n' > "$D/core/scripts/gate-defer.sh"
    printf '#!/bin/sh\nexit 0\n' > "$C/scripts/ai-dlc/gate-defer.sh"
    printf '#!/usr/bin/env bash\nbash scripts/ai-dlc/gate-defer.sh\n' > "$C/.githooks/pre-push"
  fi
  chmod +x "$C/.githooks/pre-push" "$C/scripts/ai-dlc/"*.sh
  { gi "$D" add -A && gi "$D" commit -qm theirs; } >/dev/null 2>&1 || return 1
  git -C "$D" rev-parse HEAD > "$W/T"
}
mk_gate_world "$WORK/gw-r1" r1 || { echo "FIXTURE ERROR: sg r1 world" >&2; exit 2; }
mk_gate_world "$WORK/gw-gt" gt || { echo "FIXTURE ERROR: sg gt world" >&2; exit 2; }
# ONE FRESH CONSUMER COPY PER RUN: the gate writes its record into the consumer, and the record's
# `# verdict:` is half of what every S arm reads, so a copy shared between runs would let one run's
# record answer for another. `mktemp -d`, because this runs inside `$( )` and a counter would not
# survive it.
sg_shape() { # <recon> <arm S1|S2> <stub-dir or ->
  local W p="$PATH" run out rc rec v
  case "$2" in S1) W="$WORK/gw-r1" ;; *) W="$WORK/gw-gt" ;; esac
  [ "$3" = - ] || p="$3:$PATH"
  run="$(mktemp -d "$WORK/sg-run.XXXXXX")" || { echo "OTHER(mktemp)"; return 0; }
  cp -R "$W/consumer/." "$run/" || { echo "OTHER(copy)"; return 0; }
  out="$(PATH="$p" bash "$1/self-update-gate.sh" "$W/dist" "$(cat "$W/B")" "$(cat "$W/T")" "$run" 2>/dev/null)"; rc=$?
  rec="$(ls "$run"/_bmad-output/ai-dlc-update/self-update-gate-*.md 2>/dev/null | head -n 1)"
  v="$(sed -n 's/^# verdict: //p' "$rec" 2>/dev/null | head -n 1)"
  local n_ok n_def n_und und_row
  n_ok="$(awk -F'\t' '$1=="SELF-UPDATE-OK"' <<<"$out" | "$REAL_GREP" -c .)" || n_ok=0
  n_def="$(awk -F'\t' '$1=="SELF-UPDATE-DEFER"' <<<"$out" | "$REAL_GREP" -c .)" || n_def=0
  n_und="$(awk -F'\t' '$1=="SELF-UPDATE-UNDECIDED"' <<<"$out" | "$REAL_GREP" -c .)" || n_und=0
  # S3's row must also NAME the diff's exit: `could not be computed` alone is S2's spelling too.
  if [ "$2" = S3 ]; then
    und_row="$(awk -F'\t' '$1=="SELF-UPDATE-UNDECIDED" && $3 ~ /could not be computed/ && $3 ~ /core\/scripts\/ exited 2/' <<<"$out" | "$REAL_GREP" -c .)" || und_row=0
  else
    und_row="$(awk -F'\t' '$1=="SELF-UPDATE-UNDECIDED" && $3 ~ /could not be computed/' <<<"$out" | "$REAL_GREP" -c .)" || und_row=0
  fi
  if [ "$rc" -ne 0 ] || [ -z "$v" ]; then echo "OTHER(rc=$rc,record=${v:-none})"
  elif [ "$v" = OK ] && [ "$n_ok" -gt 0 ] && [ "$n_def" -eq 0 ] && [ "$n_und" -eq 0 ]; then echo OK
  elif [ "$v" != OK ] && [ "$und_row" -gt 0 ] && [ "$n_ok" -eq 0 ]; then echo "UNDECIDED-UNCOMPUTED/$v"
  elif [ "$v" = DEFER ] && [ "$n_und" -eq 0 ] && [ "$n_ok" -eq 0 ]; then echo DEFER
  else echo "OTHER(record=$v,ok=$n_ok,defer=$n_def,undecided=$n_und)"
  fi
}

# === WORLDS ud: unregistered-drift ================================================================
#   ne  the scan-set subtrees hold NO .md/.sh/.json file (one .txt): an empty scan set, which the
#       base spelling exited 1 on through `pipefail` -- grep's "no match" as the script's status.
#   ok  one .md, consumer copy byte-identical to base: one CORE-OK row, the positive conjunct that
#       separates a scan that ran from a copy that never did.
#   hu  one .md the consumer edited in place: one HARD-UNREGISTERED-CORE-DRIFT row. U5 runs it with
#       STDOUT CLOSED, so that row cannot be written. The parent release (c8491750) discarded
#       printf's status and ended in `exit 0`: rc 0, the row gone, the truncated set read as "no
#       in-place core edit". The fix counts every failed emit and exits 2 with a named stderr line.
#   big 20 CORE-OK .md files and ONE in-place edit sorted LAST (`zz-last.md`). U5b runs it with the
#       file-size limit at 1 KiB: the first rows land, the HARD row does not. This is the MID-STREAM
#       write failure a one-shot probe of stdout at start cannot see -- stdout is a writable file
#       when the script begins -- so it is the input that separates a per-emit count from a probe.
#   U6 (world ok) fails the memo's SERVE of the cached `ls-tree` listing -- a PATH `cat` that exits
#       1 with no output on the `t <dist> <ref>` key's `.c` file. The parent lib.sh returned the
#       CACHED 0 for that serve, the prefix filter ran over an empty listing and the scan set was
#       empty: rc 0, no row. Two cells, because the two serves are two code paths: U6-hit (a memo
#       warmed by one healthy run, the hit path) and U6-fill (a fresh memo, `_ai_dlc_memo_commit`).
mk_ud_world() { # <dir> <ne|ok|hu|big>
  local D="$1/dist" C="$1/consumer" i
  mkdir -p "$D/core/skills/ai-dlc/steps" "$C/.claude/skills/ai-dlc/steps"
  printf '0.1.0\n' > "$D/VERSION"
  if [ "$2" = ne ]; then
    printf 'n\n' > "$D/core/skills/ai-dlc/notes.txt"; printf 'n\n' > "$C/.claude/skills/ai-dlc/notes.txt"
  elif [ "$2" = big ]; then
    for i in 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19 20; do
      printf '# a%s\n' "$i" > "$D/core/skills/ai-dlc/steps/a$i.md"
      cp "$D/core/skills/ai-dlc/steps/a$i.md" "$C/.claude/skills/ai-dlc/steps/a$i.md"
    done
    printf '# Last step\n\nThe lead reads this file at the top of the last phase.\n' > "$D/core/skills/ai-dlc/steps/zz-last.md"
    cp "$D/core/skills/ai-dlc/steps/zz-last.md" "$C/.claude/skills/ai-dlc/steps/zz-last.md"
    printf 'The consumer added this long line to the last phase in place.\n' >> "$C/.claude/skills/ai-dlc/steps/zz-last.md"
  elif [ "$2" = hu ]; then
    printf '# One step\n\nThe lead reads this file at the top of the one phase.\n' > "$D/core/skills/ai-dlc/steps/one.md"
    cp "$D/core/skills/ai-dlc/steps/one.md" "$C/.claude/skills/ai-dlc/steps/one.md"
    printf 'The consumer added this long line to the one phase in place.\n' >> "$C/.claude/skills/ai-dlc/steps/one.md"
  else
    printf '# one\n' > "$D/core/skills/ai-dlc/steps/one.md"; cp "$D/core/skills/ai-dlc/steps/one.md" "$C/.claude/skills/ai-dlc/steps/one.md"
  fi
  { gi "$D" init -q && gi "$D" add -A && gi "$D" commit -qm base; } >/dev/null 2>&1 || return 1
  git -C "$D" rev-parse HEAD > "$1/B"
  printf '0.2.0\n' > "$D/VERSION"
  { gi "$D" add -A && gi "$D" commit -qm theirs; } >/dev/null 2>&1 || return 1
  git -C "$D" rev-parse HEAD > "$1/T"
  printf 'version: 0.1.0\ncommit: %s\n' "$(cat "$1/B")" > "$C/.claude/.ai-dlc-version"
}
UW_NE="$WORK/uw-ne"; UW_OK="$WORK/uw-ok"; UW_HU="$WORK/uw-hu"; UW_BIG="$WORK/uw-big"
mk_ud_world "$UW_NE" ne || { echo "FIXTURE ERROR: ud ne world" >&2; exit 2; }
mk_ud_world "$UW_OK" ok || { echo "FIXTURE ERROR: ud ok world" >&2; exit 2; }
mk_ud_world "$UW_HU" hu || { echo "FIXTURE ERROR: ud hu world" >&2; exit 2; }
_n="$(git -C "$UW_NE/dist" ls-tree -r --name-only "$(cat "$UW_NE/B")" -- core/skills/ai-dlc | "$REAL_GREP" -cE '\.(md|sh|json)$')" || _n=0
_c="$(git -C "$UW_NE/dist" ls-tree -r --name-only "$(cat "$UW_NE/B")" -- core/skills/ai-dlc | "$REAL_GREP" -c .)" || _c=0
[ "$_n" -eq 0 ] && [ "$_c" -ge 1 ] \
  || { echo "FIXTURE ERROR: ud ne world: its scan subtree lists $_c path(s), $_n of them .md/.sh/.json (want >= 1 and 0), so U1 cannot express an EMPTY scan set" >&2; exit 2; }
mk_ud_world "$UW_BIG" big || { echo "FIXTURE ERROR: ud big world" >&2; exit 2; }
# The 1 KiB limit binds EVERY regular file the run writes, the staged listing and the memo's copy
# of it included. A listing that itself overflowed would drop `zz-last.md` from the scan set and
# lose the HARD row for a reason that is not the emit -- so the listing must fit.
_c="$(git -C "$UW_BIG/dist" ls-tree -r --name-only "$(cat "$UW_BIG/B")" | wc -c | tr -d ' ')" || _c=0
_n="$(git -C "$UW_BIG/dist" ls-tree -r --name-only "$(cat "$UW_BIG/B")" -- core/skills/ai-dlc/steps | "$REAL_GREP" -c '\.md$')" || _n=0
[ "$_c" -gt 0 ] && [ "$_c" -lt 1024 ] && [ "$_n" -eq 21 ] \
  || { echo "FIXTURE ERROR: ud big world: its listing is $_c byte(s) (want 1..1023, so the staged listing survives the 1 KiB limit) with $_n .md file(s) (want 21)" >&2; exit 2; }
# ud_named <stderr-text> -> how many lines carry the detector's own refusal. Keyed on its PREFIX and
# its phrase, never on "write error": bash prints `printf: write error: ...` itself, at base too.
ud_named() {
  local n
  n="$(awk '/^unregistered-drift: REFUSED/ && /could not be written to stdout/' <<<"$1" | "$REAL_GREP" -c .)" || n=0
  printf '%s' "$n"
}
ud_shape() { # <recon> <arm> <stub-dir or ->
  local W p="$PATH" out rc n nun nok nhu det err nm md mv=""
  case "$2" in U1) W="$UW_NE" ;; U5) W="$UW_HU" ;; U5b) W="$UW_BIG" ;; *) W="$UW_OK" ;; esac
  [ "$3" = - ] || p="$3:$PATH"
  if [ "$2" = U5 ] && [ "$3" != - ]; then
    # stderr to the capture, THEN stdout closed -- in that order, or the capture is closed too.
    err="$(PATH="$p" "$REAL_BASH" "$1/unregistered-drift.sh" "$W/dist" "$(cat "$W/B")" "$W/consumer" "$(cat "$W/T")" 2>&1 >&-)"; rc=$?
    nm="$(ud_named "$err")"
    # rc 2 WITHOUT the line, or the line with another rc, is OTHER: an early exit 2 for a different
    # reason must not pass. rc 0 is the parent release (the row lost silently); rc 1 is the
    # pipe-to-`while` listing before it (M-U-base), where the failed write became the loop's status.
    if [ "$rc" -eq 2 ] && [ "$nm" -eq 1 ]; then echo CLOSED-RC2-NAMED
    elif [ "$rc" -le 1 ] && [ "$nm" -eq 0 ]; then echo "CLOSED-RC$rc"
    else echo "OTHER(rc=$rc,named=$nm)"
    fi
    return 0
  fi
  if [ "$2" = U5b ]; then
    # THE rc IS READ THROUGH THE SUBSHELL ONLY. SIGXFSZ is ignored, so a write past 1 KiB fails with
    # EFBIG instead of killing the script, which is what a regular staged file does under a quota.
    # STDERR GOES TO A PIPE, NOT A FILE: the limit binds every regular file the process writes, and
    # bash's own `<path>: line N: printf: write error: File too large`, one per lost row, fills a
    # 1 KiB stderr FILE before the named line is reached -- which would read as the fix not naming it.
    out="$(mktemp "$WORK/u5b-out.XXXXXX")" || { echo "OTHER(mktemp)"; return 0; }
    if [ "$3" = - ]; then
      err="$( ( exec "$REAL_BASH" "$1/unregistered-drift.sh" "$W/dist" "$(cat "$W/B")" "$W/consumer" "$(cat "$W/T")" > "$out" ) 2>&1 )"; rc=$?
    else
      # UNDER XTRACE, so the scan loop's iterations can be COUNTED (`+ rel=` is its first assignment
      # after the break). After a failed write bash leaks the unwritten row into every later `$( )`,
      # so an iteration past the failure skips its file and emits nothing, and no PATH binary runs in
      # it: a scan that did NOT stop there prints exactly what one that stopped prints -- same rc,
      # same rows, same N (measured: 11 rows, N=10, both ways) -- and differs only in iterations,
      # 11 against 21. bash 3.2 has no BASH_XTRACEFD, so the trace shares the stderr pipe.
      err="$( ( trap '' XFSZ; ulimit -f 1; PATH="$p"; export PATH
        exec "$REAL_BASH" -x "$1/unregistered-drift.sh" "$W/dist" "$(cat "$W/B")" "$W/consumer" "$(cat "$W/T")" > "$out" ) 2>&1 )"; rc=$?
    fi
    nok="$(awk -F'\t' '$1=="CORE-OK"' "$out" | "$REAL_GREP" -c .)" || nok=0
    nhu="$(awk -F'\t' '$1=="HARD-UNREGISTERED-CORE-DRIFT" && $2=="skills/ai-dlc/steps/zz-last.md"' "$out" | "$REAL_GREP" -c .)" || nhu=0
    n="$("$REAL_GREP" -c . "$out")" || n=0
    nm="$(ud_named "$err")"
    local nb nit nw nn; nb="$(wc -c < "$out" | tr -d ' ')"
    # nw: rows that landed WHOLE (the last one the limit cut is not); nn: the N the refusal names.
    nw="$(awk -F'\t' -v b="byte-identical to $(cat "$W/B")" '$1=="CORE-OK" && $3==b' "$out" | "$REAL_GREP" -c .)" || nw=0
    nit="$("$REAL_GREP" -c '^+ rel=' <<<"$err")" || nit=0
    nn="$(awk '/^unregistered-drift: REFUSED/ { for (i=1;i<=NF;i++) if ($i=="after") { print $(i+1); exit } }' <<<"$err")"
    case "$nn" in ''|*[!0-9]*) nn=-1 ;; esac
    if [ "$3" = - ]; then
      # A WORLD WHOSE WHOLE OUTPUT FITS IN 1 KiB CANNOT HIT THE LIMIT, and its forced run would read
      # exactly like a fixed script. The control asserts the full output is larger than the limit.
      if [ "$rc" -eq 0 ] && [ "$n" -eq 21 ] && [ "$nok" -eq 20 ] && [ "$nhu" -eq 1 ] && [ "$nb" -gt 1024 ]; then echo ALL-ROWS
      else echo "OTHER(rc=$rc,rows=$n,ok=$nok,hard=$nhu,bytes=$nb)"; fi
    # Both forced shapes demand that SOME rows landed and that the HARD row, written last, did not:
    # a write failure that began at the first row is U5's case, not this one.
    elif [ "$rc" -le 1 ] && [ "$nhu" -eq 0 ] && [ "$nok" -ge 1 ] && [ "$nm" -eq 0 ]; then echo "XFSZ-RC$rc-LOST"
    # The fixed shape also STOPPED: every row it wrote came from its own iteration, so iterations are
    # the whole rows plus the one whose write failed, and the refusal's N is the whole rows.
    elif [ "$rc" -eq 2 ] && [ "$nhu" -eq 0 ] && [ "$nok" -ge 1 ] && [ "$nm" -eq 1 ] \
         && [ "$nn" -eq "$nw" ] && [ "$nit" -eq $(( nw + 1 )) ]; then echo XFSZ-RC2-NAMED
    elif [ "$rc" -eq 2 ] && [ "$nhu" -eq 0 ] && [ "$nm" -eq 1 ] && [ "$nit" -gt $(( nw + 1 )) ]; then echo XFSZ-RC2-NOSTOP
    else echo "OTHER(rc=$rc,ok=$nok,whole=$nw,N=$nn,iterations=$nit,hard=$nhu,named=$nm,bytes=$nb)"
    fi
    rm -f "$out"
    return 0
  fi
  case "$2" in
    U6-hit|U6-fill)
      # A MEMO THE RUN IS HANDED, per call: the hit cell's must hold the `t` key's answer before the
      # forced run (warmed by one healthy run), the fill cell's must not -- or the two cells would
      # exercise one code path twice.
      md="$(mktemp -d "$WORK/u6-memo.XXXXXX")" || { echo "OTHER(mktemp)"; return 0; }
      if [ "$2" = U6-hit ]; then
        AI_DLC_RECONCILE_MEMO="$md" "$REAL_BASH" "$1/unregistered-drift.sh" "$W/dist" "$(cat "$W/B")" "$W/consumer" "$(cat "$W/T")" >/dev/null 2>&1
      fi
      set -- "$1" "$2" "$3" "$(ls "$md" | "$REAL_GREP" -c '^t .*\.s$')"
      case "$2:$4" in U6-hit:1|U6-fill:0) ;; *) echo "OTHER(memo-t-keys=$4)"; return 0 ;; esac
      mv="$md" ;;
  esac
  if [ -n "$mv" ]; then
    out="$(AI_DLC_RECONCILE_MEMO="$mv" PATH="$p" "$REAL_BASH" "$1/unregistered-drift.sh" "$W/dist" "$(cat "$W/B")" "$W/consumer" "$(cat "$W/T")" 2>/dev/null)"; rc=$?
  else
    out="$(PATH="$p" "$REAL_BASH" "$1/unregistered-drift.sh" "$W/dist" "$(cat "$W/B")" "$W/consumer" "$(cat "$W/T")" 2>/dev/null)"; rc=$?
  fi
  n="$("$REAL_GREP" -c . <<<"$out")" || n=0
  nun="$(awk -F'\t' '$1=="HARD-DRIFT-SCAN-UNAVAILABLE"' <<<"$out" | "$REAL_GREP" -c .)" || nun=0
  nok="$(awk -F'\t' '$1=="CORE-OK"' <<<"$out" | "$REAL_GREP" -c .)" || nok=0
  nhu="$(awk -F'\t' '$1=="HARD-UNREGISTERED-CORE-DRIFT"' <<<"$out" | "$REAL_GREP" -c .)" || nhu=0
  det="$(awk -F'\t' '$1=="HARD-DRIFT-SCAN-UNAVAILABLE" {print $3; exit}' <<<"$out")"
  if [ "$rc" -eq 0 ] && [ "$n" -eq 1 ] && [ "$nun" -eq 1 ]; then
    case "$det" in
      *"memo_ls_tree exited 128, git ls-tree exited 128"*) echo UNAVAILABLE-LISTING ;;
      *"the file-type filter over the tree listing exited 2"*) echo UNAVAILABLE-EXT ;;
      *"the scan-set prefix filter over the cached tree listing exited 2"*) echo UNAVAILABLE-PREFIX ;;
      *) echo "OTHER(unavailable-unnamed)" ;;
    esac
  elif [ "$rc" -eq 0 ] && [ "$n" -eq 1 ] && [ "$nok" -eq 1 ]; then echo SCANNED
  elif [ "$rc" -eq 0 ] && [ "$n" -eq 1 ] && [ "$nhu" -eq 1 ]; then echo HARD-UNREG
  elif [ "$rc" -eq 0 ] && [ "$n" -eq 0 ]; then echo EMPTY
  elif [ "$n" -eq 0 ]; then echo "RC${rc}-NOROW"
  else echo "OTHER(rc=$rc,rows=$n)"
  fi
}

# === WORLD ap: apply.sh ===========================================================================
# One core step both sides moved (BOTH-CHANGED->CLASSIFY), so the run reaches all four detectors
# and retired-tokens runs for a real path. Healthy, every detector exits 0 on it and the run emits
# `WORKLIST semantic-merge skills/ai-dlc/steps/m.md` -- the positive conjunct every shape keys on,
# so an apply.sh copy that never ran reads OTHER, never a clean pass.
AW="$WORK/aw"; AD="$AW/dist"; AC="$AW/consumer"
mkdir -p "$AD/core/skills/ai-dlc/steps" "$AC/.claude/skills/ai-dlc/steps"
printf '0.1.0\n' > "$AD/VERSION"
printf '# M step\n\nThe lead reads this file at the top of the m phase.\n' > "$AD/core/skills/ai-dlc/steps/m.md"
{ gi "$AD" init -q && gi "$AD" add -A && gi "$AD" commit -qm base; } >/dev/null 2>&1 || { echo "FIXTURE ERROR: ap dist base" >&2; exit 2; }
git -C "$AD" rev-parse HEAD > "$AW/B"
printf '0.2.0\n' > "$AD/VERSION"
printf 'Upstream added this long line to the m phase for the pull.\n' >> "$AD/core/skills/ai-dlc/steps/m.md"
{ gi "$AD" add -A && gi "$AD" commit -qm theirs; } >/dev/null 2>&1 || { echo "FIXTURE ERROR: ap dist theirs" >&2; exit 2; }
git -C "$AD" rev-parse HEAD > "$AW/T"
git -C "$AD" show "$(cat "$AW/B"):core/skills/ai-dlc/steps/m.md" > "$AC/.claude/skills/ai-dlc/steps/m.md"
printf 'The consumer added this long line to the m phase in place.\n' >> "$AC/.claude/skills/ai-dlc/steps/m.md"
printf 'version: 0.1.0\ncommit: %s\n' "$(cat "$AW/B")" > "$AC/.claude/.ai-dlc-version"
ap_det() { case "$1" in Aud|Ana) echo unregistered-drift ;; Art) echo retired-tokens ;; Arlp) echo retired-layer-passage ;; Ald) echo layer-drift ;; esac; }
# ONE FRESH CONSUMER COPY PER RUN, for the reason sg_shape states: apply.sh writes the consumer.
ap_shape() { # <recon> <arm> <stub-dir or ->
  local p="$PATH" run out rc nref nmerge row path det d
  [ "$3" = - ] || p="$3:$PATH"
  d="$(ap_det "$2")"
  run="$(mktemp -d "$WORK/ap-run.XXXXXX")" || { echo "OTHER(mktemp)"; return 0; }
  cp -R "$AC/." "$run/" || { echo "OTHER(copy)"; return 0; }
  out="$(PATH="$p" "$REAL_BASH" "$1/apply.sh" "$AD" "$(cat "$AW/B")" "$run" "$(cat "$AW/T")" 2>/dev/null)"; rc=$?
  nref="$(awk -F'\t' '$1=="DECISION" && $2 ~ /-refused$/' <<<"$out" | "$REAL_GREP" -c .)" || nref=0
  nmerge="$(awk -F'\t' '$1=="WORKLIST" && $2=="semantic-merge" && $3=="skills/ai-dlc/steps/m.md"' <<<"$out" | "$REAL_GREP" -c .)" || nmerge=0
  row="$(awk -F'\t' '$1=="DECISION" && $2 ~ /-refused$/ {print $2; exit}' <<<"$out")"
  path="$(awk -F'\t' '$1=="DECISION" && $2 ~ /-refused$/ {print $3; exit}' <<<"$out")"
  det="$(awk -F'\t' '$1=="DECISION" && $2 ~ /-refused$/ {print $4; exit}' <<<"$out")"
  if [ "$rc" -ne 0 ]; then echo "OTHER(rc=$rc)"; return 0; fi
  if [ "$nref" -eq 0 ] && [ "$nmerge" -ge 1 ]; then echo NO-REFUSAL; return 0; fi
  if [ "$nref" -ne 1 ] || [ "$row" != "$d-refused" ]; then echo "OTHER(refused=$nref,row=${row:-none},merge=$nmerge)"; return 0; fi
  case "$2" in
    Ana) case "$det" in *"emitted HARD-DRIFT-SCAN-UNAVAILABLE"*"ZZ-PSB-NA-DETAIL forced"*) ;; *) echo "OTHER(na-detail)"; return 0 ;; esac ;;
    *)   case "$det" in "DETECTOR-REFUSED: $d.sh exited 2 "*"stderr: ZZ-PSB-STDERR-$d forced refusal") ;; *) echo "OTHER(detail)"; return 0 ;; esac ;;
  esac
  if [ "$2" = Art ] && [ "$path" != skills/ai-dlc/steps/m.md ]; then echo "OTHER(path=$path)"; return 0; fi
  if [ "$nmerge" -eq 0 ]; then echo REFUSED-NOMERGE; else echo REFUSED; fi
}

# === WORLDS ld: layer-drift =======================================================================
# THE FAILING CONTROL IS THE PRE-FIX ENGINE ITSELF, staged from the release before the fix into a
# copy of the whole reconcile/ directory (it sources lib.sh beside itself). Every L cell runs on it
# in the same run and must read its base shape there -- that is what proves each cell can fail.
LD_BASE_SHA=a0a9c556
#   ext  twelve extensions hooking a core step that never moves (EXTENSION-OK), and ONE hooking a
#        step that moves, sorted LAST: its EXTENSION-HOOK-DRIFT row is at an ADJUDICATED clause, so
#        `emit_raw` writes a HARD-LAYER-ADJUDICATION-MISSING row after it, the last row of the run.
#   ds   overrides only: twelve OVERRIDE-OK entries and a pair declaring the same shadow target, whose
#        two OVERRIDE-DOUBLE-SHADOW rows are the FINAL rows (the block runs after the loop).
#   big  ext with a layer-contract.yaml padded past the file-size limit: L5-pre's world.
# EVERY FILE THE ENGINE READS THROUGH A HERE-STRING IS SMALL, and the contract and schema are seeded,
# never copied from this tree (the real contract is tens of KB). A HOOKED PATH THAT IS LONG is the
# lever: it widens every row without widening the staged listing of entry paths, which is itself a
# regular file under the limit -- a listing past the limit fails the walk (a refusal of its own).
LD_HOOK="steps/zz-psb-a-hooked-core-directory-whose-name-is-long-so-every-extension-ok-row-is-hundreds-of-bytes-wide-and-outweighs-its-own-entry/zz-psb-a-hooked-core-step-that-never-moves-across-the-range-and-whose-name-is-long-for-the-same-reason-as-its-directory-so-the-rows-fill-the-limit-before-any-staged-file.md"
LD_LAST=".claude/skills/ai-dlc/extensions/zz-psb-the-entry-hooking-the-moving-step-sorts-last.md"
#   huge (BL-359) overrides only: ONE override shadowing `## Tail Rule`, the LAST section of a core
#        step padded past the C2 limit. Only its HEAD section moves, so the healthy row is OVERRIDE-OK.
LD_HUGE_REL="steps/zz-psb-huge.md"
ld_huge_md() { # <base|theirs>
  local i=0
  printf '# Huge\n\n## Head Rule\n\n%s head body\n\n## Padding\n\n' "$1"
  while [ "$i" -lt 400 ]; do printf 'padding line %03d that makes this core step larger than the file-size limit of the C2 cells\n' "$i"; i=$((i+1)); done
  printf '\n## Tail Rule\n\ntail body that never moves\n'
}
mk_ld_world() { # <dir> <ext|ds|big|huge>
  local W="$1" D="$1/dist" C="$1/consumer" X i
  X="$C/.claude/skills/ai-dlc"
  mkdir -p "$D/core/skills/ai-dlc/$(dirname "$LD_HOOK")" "$D/core/schemas" "$X/extensions" "$X/overrides" \
           "$C/_bmad-output/ai-dlc-update" || return 1
  printf '0.1.0\n' > "$D/VERSION"
  { printf 'clauses:\n  - id: LC-E4\n    level: ADJUDICATED\n    code: EXTENSION-HOOK-DRIFT\n'
    if [ "$2" = big ]; then
      i=0; while [ "$i" -lt 200 ]; do printf '# padding line %03d that makes this contract larger than the file-size limit\n' "$i"; i=$((i+1)); done
    fi
  } > "$D/core/skills/ai-dlc/layer-contract.yaml"
  printf '{\n  "properties": {\n    "verdict": {\n      "enum": [\n        "still-additive",\n        "retire"\n      ]\n    }\n  }\n}\n' \
    > "$D/core/schemas/layer-adjudication-register.json"
  printf '# Moving\n\n## Gamma\n\nbase body\n' > "$D/core/skills/ai-dlc/steps/moving.md"
  { printf '# Still\n\n## Alpha\n\nbody\n'; for i in 1 2 3 4 5 6 7 8 9 10 11 12; do printf '\n## Rule %s\n\ncore rule %s\n' "$i" "$i"; done; } \
    > "$D/core/skills/ai-dlc/$LD_HOOK"
  printf '# Skill\n\n## Rule 7\n\nseven\n' > "$D/core/skills/ai-dlc/SKILL.md"
  [ "$2" = huge ] && ld_huge_md base > "$D/core/skills/ai-dlc/$LD_HUGE_REL"
  { gi "$D" init -q && gi "$D" add -A && gi "$D" commit -qm base; } >/dev/null 2>&1 || return 1
  git -C "$D" rev-parse HEAD > "$W/B"
  printf '0.2.0\n' > "$D/VERSION"
  printf '# Moving\n\n## Gamma\n\ntheirs body REWRITTEN\n' > "$D/core/skills/ai-dlc/steps/moving.md"
  [ "$2" = huge ] && ld_huge_md theirs > "$D/core/skills/ai-dlc/$LD_HUGE_REL"
  { gi "$D" add -A && gi "$D" commit -qm theirs; } >/dev/null 2>&1 || return 1
  git -C "$D" rev-parse HEAD > "$W/T"
  if [ "$2" = huge ]; then
    # ONE override, shadowing the section at the very END of a core file larger than the limit.
    # The file moves base->theirs (its HEAD section), the shadowed section does not: OVERRIDE-OK.
    printf -- '---\nshadows: %s#Tail Rule\nbase_sha: %s\nreason: seeded\n---\n\n## Tail Rule\n\nconsumer text.\n' \
      "$LD_HUGE_REL" "$(cat "$W/B")" > "$X/overrides/huge.md"
  elif [ "$2" = ds ]; then
    for i in 01 02 03 04 05 06 07 08 09 10 11 12; do
      printf -- '---\nshadows: %s#Rule %s\nbase_sha: %s\nreason: seeded\n---\n\n## Rule %s\n\nconsumer text.\n' \
        "$LD_HOOK" "${i#0}" "$(cat "$W/B")" "${i#0}" > "$X/overrides/r$i.md"
    done
    for i in a b; do
      printf -- '---\nshadows: SKILL.md#Rule 7\nbase_sha: %s\nreason: seeded, entry %s of two claiming one anchor\n---\n\n## Rule 7\n\nconsumer text %s.\n' \
        "$(cat "$W/B")" "$i" "$i" > "$X/overrides/dup-$i.md"
    done
  else
    for i in 01 02 03 04 05 06 07 08 09 10 11 12; do
      printf -- '---\nkind: check\nhooks: %s\nreason: seeded\n---\n\n### 9%s. [ext:a%s] Entry.\n\nBody.\n' "$LD_HOOK" "$i" "$i" > "$X/extensions/a$i.md"
    done
    printf -- '---\nkind: check\nhooks: steps/moving.md\nreason: seeded\n---\n\n### 999. [ext:zz] Entry.\n\nBody.\n' > "$C/$LD_LAST"
  fi
  { gi "$C" init -q && gi "$C" add -A && gi "$C" commit -qm consumer; } >/dev/null 2>&1 || return 1
}
LW_EXT="$WORK/ldw-ext"; LW_DS="$WORK/ldw-ds"; LW_BIG="$WORK/ldw-big"; LW_HUGE="$WORK/ldw-huge"
mk_ld_world "$LW_EXT" ext || { echo "FIXTURE ERROR: ld ext world" >&2; exit 2; }
mk_ld_world "$LW_DS" ds || { echo "FIXTURE ERROR: ld ds world" >&2; exit 2; }
mk_ld_world "$LW_BIG" big || { echo "FIXTURE ERROR: ld big world" >&2; exit 2; }
mk_ld_world "$LW_HUGE" huge || { echo "FIXTURE ERROR: ld huge world" >&2; exit 2; }
# The base copy carries a0a9c556's hard-blockers.sh too: the C5 cells' failing control.
LD_BASE="$WORK/ld-base"
mkdir -p "$LD_BASE" && cp -R "$RECON/." "$LD_BASE/" \
  && git -C "$TREE_TOP" show "${LD_BASE_SHA}:core/skills/ai-dlc-update/reconcile/layer-drift.sh" > "$LD_BASE/layer-drift.sh" 2>/dev/null \
  && git -C "$TREE_TOP" show "${LD_BASE_SHA}:core/skills/ai-dlc-update/reconcile/hard-blockers.sh" > "$LD_BASE/hard-blockers.sh" 2>/dev/null \
  || { echo "FIXTURE BROKEN: could not stage layer-drift.sh and hard-blockers.sh at ${LD_BASE_SHA}, the failing control of every L and C cell" >&2; exit 2; }
if cmp -s "$RECON/hard-blockers.sh" "$LD_BASE/hard-blockers.sh"; then
  echo "FIXTURE BROKEN: the staged ${LD_BASE_SHA} hard-blockers.sh is identical to tip, so the C5 cells have no failing control" >&2; exit 2
fi
_h="$("$REAL_GREP" -c 'ld_finish\|ld_emit_failed' "$LD_BASE/layer-drift.sh")" || _h=0
_t="$("$REAL_GREP" -c 'ld_finish' "$RECON/layer-drift.sh")" || _t=0
if cmp -s "$RECON/layer-drift.sh" "$LD_BASE/layer-drift.sh" || [ "$_h" -ne 0 ] || [ "$_t" -eq 0 ]; then
  echo "FIXTURE BROKEN: the staged ${LD_BASE_SHA} layer-drift.sh is not the pre-fix engine (identical to tip, or it carries $_h ld_finish/ld_emit_failed line(s); tip carries $_t ld_finish)" >&2; exit 2
fi
# `ulimit -f` counts in BLOCKS, and the block is measured here rather than assumed.
LD_BLK="$( ( trap '' XFSZ; ulimit -f 1; printf '%08192d' 0 > "$WORK/ld-blk" ) 2>/dev/null; wc -c < "$WORK/ld-blk" | tr -d ' ')"
case "$LD_BLK" in ''|*[!0-9]*|0) echo "FIXTURE ERROR: could not measure the ulimit -f block (got '$LD_BLK')" >&2; exit 2 ;; esac
ld_run() { # <recon> <world> [flag] -> the healthy stdout
  local R="$1" W="$2"; shift 2
  "$REAL_BASH" "$R/layer-drift.sh" "$@" "$W/dist" "$(cat "$W/B")" "$(cat "$W/T")" "$W/consumer" 2>/dev/null
}
ld_run "$RECON" "$LW_EXT" > "$LW_EXT.out" && ld_run "$RECON" "$LW_DS" > "$LW_DS.out" \
  || { echo "FIXTURE ERROR: ld worlds: a healthy tip run exited non-zero" >&2; exit 2; }
# ld_cut <world> <status> <first-L> -> the smallest limit L >= first-L whose boundary L*BLK falls
# STRICTLY INSIDE a row of that status (never on its newline), or empty. Read off the healthy run.
ld_cut() {
  awk -F'\t' -v s="$2" -v b="$LD_BLK" -v l0="$3" '
    BEGIN { n = 0; o = 0 }
    { st = o; o += length($0) + 1; if ($1 == s) { lo[n] = st; hi[n] = o; n++ } }
    END { for (L = l0; L * b < o; L++) for (i = 0; i < n; i++) if (lo[i] < L * b && L * b < hi[i] - 1) { print L; exit } }' "$1.out"
}
ld_whole() { # <world> <L> -> the rows of the healthy output that end at or before L*BLK
  awk -v c="$(( $2 * LD_BLK ))" '{ o += length($0) + 1; if (o <= c) n++ } END { print n + 0 }' "$1.out"
}
_lx="$("$REAL_FIND" "$LW_EXT/consumer/.claude/skills/ai-dlc/extensions" -type f | wc -c | tr -d ' ')"
_lo="$("$REAL_FIND" "$LW_DS/consumer/.claude/skills/ai-dlc/overrides" -type f | wc -c | tr -d ' ')"
# NO CUT BELOW 2 BLOCKS. Measured: at a 1-block limit the pre-fix engine, scanning on past its failed
# write, fed a later here-string larger than 1 KiB and hit the here-string floor -- BROKEN-HEREDOC
# on the base side of L5e, which the precondition correctly refused as a verdict.
_fx=$(( _lx / LD_BLK + 1 )); [ "$_fx" -ge 2 ] || _fx=2
_fo=$(( _lo / LD_BLK + 1 )); [ "$_fo" -ge 2 ] || _fo=2
LD_L_MID="$(ld_cut "$LW_EXT" EXTENSION-OK "$_fx")"
LD_L_HARD="$(ld_cut "$LW_EXT" HARD-LAYER-ADJUDICATION-MISSING "$_fx")"
LD_L_OVR="$(ld_cut "$LW_DS" OVERRIDE-OK "$_fo")"
LD_L_DS="$(ld_cut "$LW_DS" OVERRIDE-DOUBLE-SHADOW "$_fo")"
[ -n "$LD_L_MID" ] && [ -n "$LD_L_HARD" ] && [ -n "$LD_L_OVR" ] && [ -n "$LD_L_DS" ] \
  || { echo "FIXTURE ERROR: ld worlds: no file-size limit cuts inside an EXTENSION-OK row (L=$LD_L_MID), the HARD row (L=$LD_L_HARD), an OVERRIDE-OK row (L=$LD_L_OVR) or an OVERRIDE-DOUBLE-SHADOW row (L=$LD_L_DS) above the staged listings ($_lx / $_lo bytes, block $LD_BLK)" >&2; exit 2; }
LD_W_MID="$(ld_whole "$LW_EXT" "$LD_L_MID")"; LD_W_HARD="$(ld_whole "$LW_EXT" "$LD_L_HARD")"
LD_W_OVR="$(ld_whole "$LW_DS" "$LD_L_OVR")"; LD_W_DS="$(ld_whole "$LW_DS" "$LD_L_DS")"
# THE WORLDS EXPRESS THEIR CASES: the HARD row is the ext world's LAST row; the double-shadow pair
# is the ds world's last two; and the L5b / L5e cuts leave ENTRIES STILL TO SCAN after the row they
# cut, or a scan that failed to stop would read exactly like one that stopped.
_r="$(awk -F'\t' '{print $1}' "$LW_EXT.out" | tr '\n' ' ')"
_s="$(awk -F'\t' '{print $1}' "$LW_DS.out" | tr '\n' ' ')"
case "$_r|$_s" in
  *"EXTENSION-OK EXTENSION-HOOK-DRIFT HARD-LAYER-ADJUDICATION-MISSING |"*"OVERRIDE-OK OVERRIDE-DOUBLE-SHADOW OVERRIDE-DOUBLE-SHADOW ") ;;
  *) echo "FIXTURE ERROR: ld worlds do not end on the HARD row ($_r) and on the double-shadow pair ($_s)" >&2; exit 2 ;;
esac
_ne="$(awk -F'\t' '$1=="EXTENSION-OK"' "$LW_EXT.out" | "$REAL_GREP" -c .)" || _ne=0
_no="$(awk -F'\t' '$1=="OVERRIDE-OK"' "$LW_DS.out" | "$REAL_GREP" -c .)" || _no=0
[ "$LD_W_MID" -le $(( _ne - 2 )) ] && [ "$LD_W_OVR" -le $(( _no - 2 )) ] \
  || { echo "FIXTURE ERROR: ld worlds: the L5b cut leaves $LD_W_MID of $_ne EXTENSION-OK rows whole and the L5e cut $LD_W_OVR of $_no OVERRIDE-OK rows (want at most two short of each, so an entry remains after the cut row)" >&2; exit 2; }
echo "  (ld worlds: block $LD_BLK B; L5b cut at $LD_L_MID block(s) after $LD_W_MID whole row(s), L5b-hard at $LD_L_HARD after $LD_W_HARD, L5e at $LD_L_OVR after $LD_W_OVR, L5d at $LD_L_DS after $LD_W_DS; staged listings $_lx / $_lo B)"
# The refusal line, keyed on its PREFIX and phrase UNANCHORED (a leaked stdout buffer was measured
# prefixing it; `apply.sh` reads it the same way), never on "write error". Xtrace lines are skipped:
# under `bash -x` the printf that writes the refusal is traced with the same words.
ld_named() {
  local n
  n="$(awk '!/^\+/ && /layer-drift: REFUSED/ && /could not be written to stdout/' <<<"$1" | "$REAL_GREP" -c .)" || n=0
  printf '%s' "$n"
}
ld_n() {
  local nn
  nn="$(awk '!/^\+/ && /layer-drift: REFUSED/ { for (i=1;i<=NF;i++) if ($i=="after") { print $(i+1); exit } }' <<<"$1")"
  case "$nn" in ''|*[!0-9]*) nn=-1 ;; esac
  printf '%s' "$nn"
}
LD_HEREDOC_BAD="$WORK/ld-heredoc-broken"
# ld_shape <recon> <arm> <stub-dir or -> -> the SHAPE of one layer-drift run
ld_shape() {
  local W p="$PATH" out err rc nm nn nsub nb nw nit want L m="" subj=HARD-LAYER-ADJUDICATION-MISSING full=1
  # `full` is how many subject rows the healthy run writes; a forced run holding fewer LOST one.
  case "$2" in L5d|L5e) W="$LW_DS"; subj=OVERRIDE-DOUBLE-SHADOW; full=2 ;; L5-pre) W="$LW_BIG" ;; *) W="$LW_EXT" ;; esac
  case "$2" in L5c) m=--list-adjudications ;; esac
  [ "$3" = - ] || p="$3:$PATH"
  if [ "$3" = - ]; then
    # THE CONTROL: stdout open, no limit. Presence-shaped -- the subject row must be THERE.
    out="$(PATH="$p" "$REAL_BASH" "$1/layer-drift.sh" $m "$W/dist" "$(cat "$W/B")" "$(cat "$W/T")" "$W/consumer" 2>/dev/null)"; rc=$?
    if [ -n "$m" ]; then
      nsub="$(awk -F'\t' -v e="$LD_LAST" '$1=="ADJUDICABLE" && $2==e' <<<"$out" | "$REAL_GREP" -c .)" || nsub=0
      if [ "$rc" -eq 0 ] && [ "$nsub" -eq 1 ]; then echo LISTED; else echo "OTHER(rc=$rc,listed=$nsub)"; fi
    else
      nsub="$(awk -F'\t' -v s="$subj" '$1==s' <<<"$out" | "$REAL_GREP" -c .)" || nsub=0
      case "$subj:$rc:$nsub" in
        HARD-*:0:1) echo ALL-ROWS ;; OVERRIDE-*:0:2) echo ALL-ROWS-DS ;; *) echo "OTHER(rc=$rc,subject=$nsub)" ;;
      esac
    fi
    return 0
  fi
  case "$2" in
    L5|L5c)
      # stderr to the capture, THEN stdout closed -- in that order, or the capture is closed too.
      err="$(PATH="$p" "$REAL_BASH" "$1/layer-drift.sh" $m "$W/dist" "$(cat "$W/B")" "$(cat "$W/T")" "$W/consumer" 2>&1 >&-)"; rc=$?
      nm="$(ld_named "$err")"; nn="$(ld_n "$err")"
      if [ "$rc" -eq 2 ] && [ "$nm" -eq 1 ] && [ "$nn" -eq 0 ]; then echo CLOSED-RC2-N0
      elif [ "$rc" -eq 0 ] && [ "$nm" -eq 0 ]; then echo CLOSED-RC0
      else echo "OTHER(rc=$rc,named=$nm,N=$nn)"; fi
      return 0 ;;
  esac
  case "$2" in
    L5b|L5-pre) L="$LD_L_MID"; want="$LD_W_MID" ;; L5b-hard) L="$LD_L_HARD"; want="$LD_W_HARD" ;;
    L5e) L="$LD_L_OVR"; want="$LD_W_OVR" ;; L5d) L="$LD_L_DS"; want="$LD_W_DS" ;;
  esac
  out="$(mktemp "$WORK/ld-out.XXXXXX")" || { echo "OTHER(mktemp)"; return 0; }
  # SIGXFSZ ignored, so a write past the limit fails with EFBIG and N is EXACT: a row either landed
  # whole before the limit or its write failed. Stderr goes to a PIPE, never a file the limit binds.
  # UNDER XTRACE, so the outer loops' iterations after the first failed write can be COUNTED --
  # `+ entry=` is each loop's first assignment after its break. bash 3.2 has no BASH_XTRACEFD.
  err="$( ( trap '' XFSZ; ulimit -f "$L"; PATH="$p"; export PATH
    exec "$REAL_BASH" -x "$1/layer-drift.sh" "$W/dist" "$(cat "$W/B")" "$(cat "$W/T")" "$W/consumer" > "$out" ) 2>&1 )"; rc=$?
  # THE PRECONDITION. bash 3.2 writes a here-string to a temp file under the SAME limit, and the
  # a0a9c556 engine read layer-contract.yaml through `<<<`: a failed one read as an EMPTY contract,
  # the adjudication disarmed and the HARD row never existed, at rc 0 -- a reason that is not the
  # emit. Such a run is no verdict. L5-pre is the one cell built to reach it, and on that engine it
  # still reads BROKEN-HEREDOC. The tip carries no here-string (BL-359), so on the tip L5-pre reads
  # REFUSED-CONTRACT: the contract's READ fails under the limit and the engine refuses naming it,
  # exit non-zero with no row. A tip run that prints the here-string message at all means a `<<<`
  # came back; the SPELL arm below owns that, and this cell then reads BROKEN-HEREDOC, not its tip shape.
  if "$REAL_GREP" -q 'cannot create temp file for here' <<<"$err"; then
    [ "$2" = L5-pre ] || printf '%s via %s\n' "$2" "$1" >> "$LD_HEREDOC_BAD"
    echo BROKEN-HEREDOC; rm -f "$out"; return 0
  fi
  nm="$(ld_named "$err")"; nn="$(ld_n "$err")"
  nw="$(tr -cd '\n' < "$out" | wc -c | tr -d ' ')"
  # Only WHOLE rows count as written: the row the limit cut is a fragment, not a row.
  nsub=0
  [ "$nw" -eq 0 ] || { nsub="$(head -n "$nw" "$out" | awk -F'\t' -v s="$subj" '$1==s' | "$REAL_GREP" -c .)" || nsub=0; }
  nb="$(wc -c < "$out" | tr -d ' ')"
  nit="$(awk '/write error/ && !f { f=1; next } f && /^\+ entry=/ { n++ } END { print n+0 }' <<<"$err")"
  rm -f "$out"
  # The refusal line is read UNTRACED: under `bash -x` its echo is traced as `+ echo '...'`, so only
  # a line OPENING with the prefix is the engine's own output.
  local nrc
  nrc="$(awk 'index($0, "layer-drift: REFUSED — reading core/skills/ai-dlc/layer-contract.yaml at ") == 1' <<<"$err" | "$REAL_GREP" -c .)" || nrc=0
  if [ "$2" = L5-pre ]; then
    if [ "$rc" -ne 0 ] && [ "$nw" -eq 0 ] && [ "$nrc" -eq 1 ]; then echo REFUSED-CONTRACT
    else echo "OTHER(no-heredoc-failure,rc=$rc,whole=$nw,contract-refusal=$nrc)"; fi
  elif [ "$nw" -ne "$want" ]; then echo "OTHER(whole=$nw,want=$want,rc=$rc)"
  elif [ "$rc" -eq 0 ] && [ "$nsub" -lt "$full" ] && [ "$nm" -eq 0 ]; then echo XFSZ-RC0-LOST
  elif [ "$rc" -eq 2 ] && [ "$nsub" -lt "$full" ] && [ "$nm" -eq 1 ] && [ "$nn" -eq "$nw" ] && [ "$nit" -eq 0 ]; then echo XFSZ-RC2-NAMED
  elif [ "$rc" -eq 2 ] && [ "$nsub" -lt "$full" ] && [ "$nm" -eq 1 ] && [ "$nit" -gt 0 ]; then echo XFSZ-RC2-NOSTOP
  # A row lost UNCOUNTED, and the scan ran on into a memo read the leaked stdout buffer corrupted:
  # the memo's own refusal at rc 1, never the write-failure line. Only an engine that stops counting
  # failed writes can reach it -- the tip's `ld_refuse` defers to `ld_finish` once a row is lost.
  elif [ "$rc" -eq 1 ] && [ "$nsub" -lt "$full" ] && [ "$nm" -eq 0 ] \
       && awk '!/^\+/ && /could not be served by the reconcile memo/ { f=1 } END { exit !f }' <<<"$err"; then echo XFSZ-RC1-MEMO
  else echo "OTHER(rc=$rc,whole=$nw,N=$nn,iterations=$nit,subject=$nsub,named=$nm,bytes=$nb)"; fi
}
# A non-precondition L cell that hit the here-string floor ends the run BROKEN. Only a pre-fix copy
# (the a0a9c556 engine, a mutant restoring a `<<<`) can: the tip carries none. The C cells below
# reach the floor on purpose on the base engine and keep their own reading, so they never log here.
ld_heredoc_gate() {
  if [ -s "$LD_HEREDOC_BAD" ]; then
    echo "FIXTURE BROKEN: an L cell's run failed a here-string under its file-size limit ($(tr '\n' ';' < "$LD_HEREDOC_BAD")) -- its shape is not a verdict about the emit" >&2
    exit 2
  fi
}

# === WORLDS lc / hb: BL-359, the here-string that could not be staged ============================
# EVERY C CELL RUNS WITHOUT XTRACE, stderr to a PIPE and stdout to a file under the limit. The limit
# LD_LC is chosen so exactly ONE input is larger than it -- the contract (big world) or the huge
# step (huge world) -- and everything else the run writes fits: asserted below, or a cell's shape
# would be the result of a different write failing. The cold cells run with the engine's own fresh
# memo, so the subject's FIRST read is a memo fill that fails; the warm (`w`) cells hand the engine a
# memo one healthy run of the SAME engine filled, so the subject arrives through `cat` of a cached
# file with nothing written, and the first write that fails is the engine's own staging of it.
LD_LC=12
ld_run "$RECON" "$LW_BIG" > "$LW_BIG.out" && ld_run "$RECON" "$LW_HUGE" > "$LW_HUGE.out" \
  || { echo "FIXTURE ERROR: lc worlds: a healthy tip run exited non-zero" >&2; exit 2; }
_cb="$(wc -c < "$LW_BIG/dist/core/skills/ai-dlc/layer-contract.yaml" | tr -d ' ')"
_hb="$(git -C "$LW_HUGE/dist" cat-file -s "$(cat "$LW_HUGE/T"):core/skills/ai-dlc/$LD_HUGE_REL")" || _hb=0
_ob="$( { git -C "$LW_BIG/dist" ls-tree -r -l "$(cat "$LW_BIG/T")"; git -C "$LW_HUGE/dist" ls-tree -r -l "$(cat "$LW_HUGE/T")"
          git -C "$LW_HUGE/dist" ls-tree -r -l "$(cat "$LW_HUGE/B")"; } \
        | awk '$5 !~ /layer-contract[.]yaml$/ && $5 !~ /zz-psb-huge[.]md$/ && $4 + 0 > m { m = $4 + 0 } END { print m + 0 }')"
_bo="$(wc -c < "$LW_BIG.out" | tr -d ' ')"; _ho="$(wc -c < "$LW_HUGE.out" | tr -d ' ')"
_lim=$(( LD_LC * LD_BLK ))
if [ "$_cb" -le $(( _lim + LD_BLK )) ] || [ "$_hb" -le $(( _lim + LD_BLK )) ] || [ "$_ob" -ge "$_lim" ] \
   || [ "$_bo" -ge "$_lim" ] || [ "$_ho" -ge "$_lim" ] || [ "$_lx" -ge "$_lim" ]; then
  echo "FIXTURE ERROR: lc worlds: the limit ($_lim B) must lie below the contract ($_cb B) and the huge step ($_hb B) by a block and above every other blob ($_ob B), each healthy output ($_bo / $_ho B) and the staged listing ($_lx B)" >&2; exit 2
fi
_ho_row="$(awk -F'\t' '$2 == ".claude/skills/ai-dlc/overrides/huge.md" {print $1}' "$LW_HUGE.out" | tr '\n' ' ')"
[ "$_ho_row" = "OVERRIDE-OK " ] \
  || { echo "FIXTURE ERROR: lc huge world: the healthy run's rows for overrides/huge.md are '$_ho_row', want exactly one OVERRIDE-OK -- the shadowed section must be unchanged while its file moves" >&2; exit 2; }
# The two warm memos, filled ONCE by a healthy tip run each (see lc_shape's C1w/C2w branch).
LC_MEMO_BIG="$WORK/lc-memo-big"; LC_MEMO_HUGE="$WORK/lc-memo-huge"
mkdir -p "$LC_MEMO_BIG" "$LC_MEMO_HUGE" || { echo "FIXTURE ERROR: mkdir lc memos" >&2; exit 2; }
AI_DLC_RECONCILE_MEMO="$LC_MEMO_BIG" ld_run "$RECON" "$LW_BIG" >/dev/null \
  && AI_DLC_RECONCILE_MEMO="$LC_MEMO_HUGE" ld_run "$RECON" "$LW_HUGE" >/dev/null \
  || { echo "FIXTURE ERROR: lc worlds: a healthy memo-warming run exited non-zero" >&2; exit 2; }
echo "  (lc worlds: limit $LD_LC block(s) = $_lim B; contract $_cb B, huge step $_hb B, largest other blob $_ob B, healthy outputs $_bo / $_ho B)"

# lc_shape <recon> <arm> <stub-dir or -> -> the SHAPE of one BL-359 layer-drift run.
# A forced run whose stderr carries bash's here-string failure leaves a HEREDOC marker in its stub
# directory, which is what the base loop keys INCONCLUSIVE on: a bash that feeds a here-string
# without a temp file cannot lose one, and the cell then discriminates nothing on that bash.
lc_shape() {
  local R="$1" A="$2" sd="$3" W p="$PATH" b t out err rc m="" memo="" lim="" her=0 ref nrow nhard ndrift ovr
  case "$A" in C2|C2w|C2s) W="$LW_HUGE" ;; *) W="$LW_BIG" ;; esac
  b="$(cat "$W/B")"; t="$(cat "$W/T")"
  [ "$A" = C4 ] && m=--adjudicated-codes
  if [ "$sd" != - ]; then
    p="$sd:$PATH"
    case "$A" in C1|C1w|C4|C2|C2w) lim="$LD_LC" ;; esac
    case "$A" in
      C1w|C2w)
        # A FRESH memo per drive, COPIED from the one warmed once per world below: a memo holds git's
        # blobs keyed by dist and ref, never an engine's answer, so a copy warmed by the tip serves a
        # mutant or the base the same bytes -- and a fresh copy means no drive reads another's fills.
        memo="$(mktemp -d "$WORK/lc-memo.XXXXXX")" || { echo "OTHER(mktemp)"; return 0; }
        case "$A" in C1w) cp -R "$LC_MEMO_BIG/." "$memo/" ;; *) cp -R "$LC_MEMO_HUGE/." "$memo/" ;; esac \
          || { echo "OTHER(memo-copy)"; return 0; }
        # The memo key embeds the ref, so the check names THEIRS: the huge step is read at base_sha too.
        case "$A" in C1w) set -- "$R" "$A" "$sd" "${t}:core%2Fskills%2Fai-dlc%2Flayer-contract.yaml.c" ;;
                     *)   set -- "$R" "$A" "$sd" "${t}:core%2Fskills%2Fai-dlc%2Fsteps%2Fzz-psb-huge.md.c" ;; esac
        [ "$(ls "$memo" | "$REAL_GREP" -cF -- "$4")" -eq 1 ] || { echo "OTHER(memo-not-warm)"; return 0; }
        # C2w's BASE EXISTENCE KEY IS DROPPED FROM THE COPY, so the only guard deciding the cell is
        # the THEIRS staging write it is about. The engine gates its base read of the shadowed file
        # on `have`, and a warm `have` answers from the `e` key's `.s` file through a `$( )` capture.
        # Under M1 the staging write fails EFBIG and the run CONTINUES, leaving bytes in bash 3.2's
        # stdout buffer that the capture then reads back as the status: `have` misreads a healthy
        # store as "object is missing" and refuses, which pre-empts the OK-LOST shape M1 is scored on
        # and makes the two guards cover one subject. With the key absent `have` asks git fresh and
        # passes. A memo warmed by an engine that does not gate that read (pre-0.680.0) carries no
        # such key, so 0 is accepted; more than one is a harness fault. The theirs `.c` check above
        # stays the warm control: the cell still reads the subject from the memo.
        # Keyed on the `e ` PREFIX and the ref:path SUFFIX, never on the dist spelling between them
        # (the engine's, not this file's): memo_show's `s ` key ends identically and must survive.
        if [ "$A" = C2w ]; then
          local _ek=0 _ekf
          for _ekf in "$memo"/"e "*" ${b}:core%2Fskills%2Fai-dlc%2Fsteps%2Fzz-psb-huge.md.s"; do
            [ -e "$_ekf" ] || continue
            _ek=$((_ek + 1)); rm -f "$_ekf"
            [ ! -e "$_ekf" ] || { echo "OTHER(base-e-key-kept)"; return 0; }
          done
          [ "$_ek" -le 1 ] || { echo "OTHER(base-e-key-count=$_ek)"; return 0; }
        fi ;;
    esac
  fi
  out="$(mktemp "$WORK/lc-out.XXXXXX")" || { echo "OTHER(mktemp)"; return 0; }
  err="$( ( trap '' XFSZ; [ -z "$lim" ] || ulimit -f "$lim"; PATH="$p"; export PATH
            [ -z "$memo" ] || { AI_DLC_RECONCILE_MEMO="$memo"; export AI_DLC_RECONCILE_MEMO; }
            if [ -n "$m" ]; then exec "$REAL_BASH" "$R/layer-drift.sh" "$m" "$W/dist" "$t" > "$out"
            else exec "$REAL_BASH" "$R/layer-drift.sh" "$W/dist" "$b" "$t" "$W/consumer" > "$out"; fi ) 2>&1 )"; rc=$?
  if "$REAL_GREP" -qF 'cannot create temp file for here' <<<"$err"; then her=1; [ "$sd" = - ] || : > "$sd/HEREDOC"; fi
  ref="$(awk 'index($0, "layer-drift: REFUSED — ") == 1 { print; exit }' <<<"$err")"
  nrow="$("$REAL_GREP" -c . "$out")" || nrow=0
  nhard="$(awk -F'\t' '$1=="HARD-LAYER-ADJUDICATION-MISSING"' "$out" | "$REAL_GREP" -c .)" || nhard=0
  ndrift="$(awk -F'\t' '$1=="EXTENSION-HOOK-DRIFT"' "$out" | "$REAL_GREP" -c .)" || ndrift=0
  ovr="$(awk -F'\t' '$2 == ".claude/skills/ai-dlc/overrides/huge.md" {print $1; exit}' "$out")"
  rm -f "$out"
  # A REFUSAL is exit non-zero, NO row, and the engine's own `REFUSED —` line naming the site.
  if [ "$rc" -ne 0 ] && [ "$nrow" -eq 0 ]; then
    case "$ref" in
      *"REFUSED — reading core/skills/ai-dlc/layer-contract.yaml at "*) echo REFUSED-CONTRACT ;;
      *"REFUSED — the ADJUDICATED code set out of "*"could not be staged"*) echo REFUSED-CODES ;;
      *"clause(s) at level ADJUDICATED and the code set read out of it is EMPTY"*) echo REFUSED-R2 ;;
      *"REFUSED — reading core/skills/ai-dlc/$LD_HUGE_REL at "*) echo REFUSED-READ ;;
      *"REFUSED — core/skills/ai-dlc/$LD_HUGE_REL at "*"could not be staged"*) echo REFUSED-STAGE ;;
      *"REFUSED — section_of for "*) echo REFUSED-SECTION ;;
      *) echo "OTHER(rc=$rc,no-row,refusal=${ref:-none})" | tr ' ' '_' ;;
    esac
    return 0
  fi
  [ "$rc" -eq 0 ] || { echo "OTHER(rc=$rc,rows=$nrow)"; return 0; }
  case "$A" in
    C4)
      # --adjudicated-codes prints bare codes, one per line: the world's one ADJUDICATED clause keys
      # EXTENSION-HOOK-DRIFT, so the healthy listing IS that line (counted by `ndrift` above).
      if [ "$nrow" -eq 1 ] && [ "$ndrift" -eq 1 ]; then echo CODES-LISTED
      elif [ "$nrow" -eq 0 ] && [ "$her" -eq 1 ]; then echo CODES-EMPTY-HEREDOC
      elif [ "$nrow" -eq 0 ]; then echo CODES-EMPTY
      else echo "OTHER(rows=$nrow)"; fi ;;
    C2|C2w|C2s)
      # THE SHAPE IS "THE OK ROW WAS LOST", and deliberately not the name of the row that replaced it:
      # these cells are about a silent read of the shadow target, not about LC-O7's whole-file shadow,
      # and naming that clause's code at a code line would enter this fixture in I65's index as LC-O7's
      # proof. Measured on the base engine: the lost row is the unprovable-anchor one (the anchor
      # resolves to nothing in an empty blob); under M1 it is the section-drift one (a truncated blob).
      # The -HEREDOC suffix is what separates base's lost row from M1's on C2w.
      if [ "$ovr" = OVERRIDE-OK ]; then echo OVERRIDE-OK
      elif [ -z "$ovr" ]; then echo "OTHER(no-row-for-the-override)"
      elif [ "$her" -eq 1 ]; then echo OK-LOST-HEREDOC
      else echo OK-LOST; fi ;;
    *)
      # The positive conjunct: the EXTENSION-HOOK-DRIFT row the adjudicated clause keys on is THERE,
      # so a run that lost the HARD row still classified -- it is not a copy that never ran.
      if [ "$ndrift" -ne 1 ]; then echo "OTHER(hook-drift=$ndrift,hard=$nhard)"
      elif [ "$nhard" -eq 1 ]; then echo ALL-ROWS
      elif [ "$her" -eq 1 ]; then echo LOST-HEREDOC
      else echo TIER-OFF; fi ;;
  esac
}

# hb_shape <recon> <arm> <stub-dir or -> -> the SHAPE of one hard-blockers.sh render from SUPPLIED
# rows. The layer-drift rows are a PARTIAL set -- three non-HARD rows of the ext world's healthy run,
# a prefix of what a refused run leaves behind -- and unregistered-drift's are empty. The forcing input
# is the supplied rc: 2 for the cell's own detector when forced, 0 for both in the control.
HB_LD_ROWS="$WORK/hb-rows-ld"; HB_UD_ROWS="$WORK/hb-rows-ud"
head -n 3 "$LW_EXT.out" > "$HB_LD_ROWS"; : > "$HB_UD_ROWS"
_n="$(awk -F'\t' '$1 !~ /^HARD-/' "$HB_LD_ROWS" | "$REAL_GREP" -c .)" || _n=0
[ "$_n" -eq 3 ] || { echo "FIXTURE ERROR: hb rows: the partial layer-drift set holds $_n non-HARD row(s), want 3" >&2; exit 2; }
hb_shape() {
  local R="$1" A="$2" sd="$3" p="$PATH" out rc lrc=0 urc=0 nref nld naff nb ne
  if [ "$sd" != - ]; then
    p="$sd:$PATH"
    case "$A" in C5-ld) lrc=2 ;; C5-ud) urc=2 ;; esac
  fi
  out="$(PATH="$p" "$REAL_BASH" "$R/hard-blockers.sh" --ld-rows "$HB_LD_ROWS" --ld-rc "$lrc" --ud-rows "$HB_UD_ROWS" --ud-rc "$urc" \
           "$LW_EXT/dist" "$(cat "$LW_EXT/B")" "$LW_EXT/consumer" "$(cat "$LW_EXT/T")" 2>/dev/null)"; rc=$?
  nref="$("$REAL_GREP" -c '^DETECTOR-REFUSED' <<<"$out")" || nref=0
  nld="$("$REAL_GREP" -c '^DETECTOR-REFUSED.*layer-drift[.]sh exited 2 ' <<<"$out")" || nld=0
  naff="$("$REAL_GREP" -cxF '0 HARD blockers.' <<<"$out")" || naff=0
  nb="$("$REAL_GREP" -c '^<!-- BEGIN GENERATED: hard-blockers' <<<"$out")" || nb=0
  ne="$("$REAL_GREP" -c '^<!-- END GENERATED: hard-blockers' <<<"$out")" || ne=0
  # The region's two markers are the positive conjunct: a copy that never ran renders neither.
  if [ "$rc" -ne 0 ] || [ "$nb" -ne 1 ] || [ "$ne" -ne 1 ]; then echo "OTHER(rc=$rc,begin=$nb,end=$ne)"
  elif [ "$naff" -eq 1 ] && [ "$nref" -eq 0 ]; then echo AFFIRMATIVE
  elif [ "$naff" -eq 0 ] && [ "$nref" -eq 1 ] && [ "$nld" -eq 1 ]; then echo REFUSED-ROW
  elif [ "$naff" -eq 0 ] && [ "$nref" -eq 0 ]; then echo NO-AFFIRMATIVE
  else echo "OTHER(affirmative=$naff,refused=$nref,ld-refused=$nld)"; fi
}

# === ONE ARM ======================================================================================
# arm_shape <arm> <recon> <stub-dir or -> -> the shape
arm_shape() {
  case "$1" in
    L1|L2|L3) lr_shape "$2" "$1" "$3" ;;
    P1) pc_shape "$2" "$3" ;;
    P2|P3) pm_shape "$2" "$1" "$3" ;;
    E1) er_shape "$2" "$3" ;;
    S1|S2|S3) sg_shape "$2" "$1" "$3" ;;
    U1|U2|U2b|U3|U4|U5|U5b|U6-hit|U6-fill) ud_shape "$2" "$1" "$3" ;;
    Aud|Art|Arlp|Ald|Ana) ap_shape "$2" "$1" "$3" ;;
    L5|L5c|L5b|L5b-hard|L5d|L5e|L5-pre) ld_shape "$2" "$1" "$3" ;;
    C1|C1w|C4|C2|C2w|C2s|C3) lc_shape "$2" "$1" "$3" ;;
    C5-ld|C5-ud) hb_shape "$2" "$1" "$3" ;;
  esac
}
# THE EXPECTATION TABLE. <arm> <key> <control shape> <tip shape> <base shape>
EXPECT='L1 lr NEEDS-REVIEW-ABSENT REFUSED-ABSENT CLOSE-CANDIDATE
L2 lr NEEDS-REVIEW-UNFALSIFIABLE REFUSED-NAMED STILL-LIVE-NO-SUBJECT
L3 lr NEEDS-REVIEW-UNFALSIFIABLE STILL-LIVE-LSTREE-FAILED STILL-LIVE-CONSUMER-OWNED
P1 pc ORPHAN-ROWS REFUSED NO-ORPHAN-ROWS
P2 pm SITED SITED-OR-REFUSED UNSITED-HEREDOC
P3 pm AT-SELF-UPDATE AT-SELF-UPDATE-OR-REFUSED NOT-MACHINERY-HEREDOC
E1 er UNDECIDED-DIFF UNDECIDED-UNCOMPUTED BLOCKERS-RESOLVED
S1 sg DEFER UNDECIDED-UNCOMPUTED/DEFER OK
S2 sg DEFER UNDECIDED-UNCOMPUTED/UNDECIDED OK
S3 sg DEFER UNDECIDED-UNCOMPUTED/UNDECIDED OK
U1 ud EMPTY EMPTY RC1-NOROW
U2 ud SCANNED UNAVAILABLE-LISTING RC1-NOROW
U2b ud SCANNED SCANNED SCANNED
U3 ud SCANNED UNAVAILABLE-EXT RC2-NOROW
U4 ud SCANNED UNAVAILABLE-PREFIX SCANNED
U5 ud HARD-UNREG CLOSED-RC2-NAMED CLOSED-RC0
U5b ud ALL-ROWS XFSZ-RC2-NAMED XFSZ-RC0-LOST
U6-hit ud SCANNED SCANNED EMPTY
U6-fill ud SCANNED SCANNED EMPTY
Aud ap NO-REFUSAL REFUSED NO-REFUSAL
Art ap NO-REFUSAL REFUSED NO-REFUSAL
Arlp ap NO-REFUSAL REFUSED NO-REFUSAL
Ald ap NO-REFUSAL REFUSED NO-REFUSAL
Ana ap NO-REFUSAL REFUSED NO-REFUSAL
L5 ld ALL-ROWS CLOSED-RC2-N0 CLOSED-RC0
L5c ld LISTED CLOSED-RC2-N0 CLOSED-RC0
L5b ld ALL-ROWS XFSZ-RC2-NAMED XFSZ-RC0-LOST
L5b-hard ld ALL-ROWS XFSZ-RC2-NAMED XFSZ-RC0-LOST
L5d ld ALL-ROWS-DS XFSZ-RC2-NAMED XFSZ-RC0-LOST
L5e ld ALL-ROWS-DS XFSZ-RC2-NAMED XFSZ-RC0-LOST
L5-pre ld ALL-ROWS REFUSED-CONTRACT BROKEN-HEREDOC
C1 lc ALL-ROWS REFUSED-CONTRACT LOST-HEREDOC
C1w lc ALL-ROWS ALL-ROWS LOST-HEREDOC
C4 lc CODES-LISTED REFUSED-CONTRACT CODES-EMPTY-HEREDOC
C2 lo OVERRIDE-OK REFUSED-READ OK-LOST-HEREDOC
C2w lo OVERRIDE-OK REFUSED-STAGE OK-LOST-HEREDOC
C2s lo OVERRIDE-OK REFUSED-SECTION OK-LOST
C3 lc ALL-ROWS REFUSED-R2 TIER-OFF
C5-ld hb AFFIRMATIVE REFUSED-ROW AFFIRMATIVE
C5-ud hb AFFIRMATIVE NO-AFFIRMATIVE AFFIRMATIVE'
# The base cells whose base reading IS a here-string that could not be staged. On a bash that feeds
# a here-string without a temp file the base cannot lose one, and those cells then read INCONCLUSIVE
# -- keyed on the base run printing bash's own message, never on the bash version.
LC_HEREDOC_ARMS=' C1 C1w C4 C2w '
col() { awk -v a="$1" -v c="$2" '$1==a {print $c}' <<<"$EXPECT"; }
arms_of() { awk -v k="$1" '$2==k {print $1}' <<<"$EXPECT"; }

# forced <arm> <recon> <tag> -> "<shape> <fired>"
forced() {
  local sd="$WORK/stub/$3-$1" s
  mkstub_for "$1" "$sd"
  s="$(arm_shape "$1" "$2" "$sd")"
  printf '%s %s\n' "$s" "$(fired "$sd")"
}

# --- CONTROLS AND FORCED ARMS ON THE SHIPPED SCRIPTS ----------------------------------------------
for A in $(awk '{print $1}' <<<"$EXPECT"); do
  sg "$(unit_of_key "$(col "$A" 2)")" || continue
  c="$(arm_shape "$A" "$RECON" -)"
  if [ "$c" = "$(col "$A" 3)" ]; then
    ok "$A control (no stub): $c -- the world expresses the healthy verdict"
  else
    bad "$A control (no stub): $c, expected $(col "$A" 3) -- the world does not express the case, so the forced arm below is unattributable"
  fi
  set -- $(forced "$A" "$RECON" tip)
  if [ "${2:-0}" -gt 0 ] && [ "$1" = "$(col "$A" 4)" ]; then
    ok "$A forced (stub fired ${2}x): $1 -- the tip shape (base spelling reads $(col "$A" 5))"
  elif [ "${2:-0}" -eq 0 ]; then
    bad "$A FIXTURE BROKEN: the stub never fired, so its shape ($1) says nothing about the site"
  else
    bad "$A forced (stub fired ${2}x): $1, expected $(col "$A" 4) -- a failed producer read as $1"
  fi
done

# --- MUTANTS: one per forced site, the site's base block restored verbatim ------------------------
# mut <name> <script> <awk-program> <base-line-literal> <staged-token> <anchor-literal...>
# The awk program reads ENVIRON; every anchor must match exactly one whole line before mutation.
MUTROOT="$WORK/mut"
mkdir -p "$MUTROOT" || { echo "FIXTURE ERROR: mkdir $MUTROOT" >&2; exit 2; }
# `mut` runs inside `$( )`, where a `bad` would lose both its line and its count. It writes the
# reason to a file instead and returns 1; the caller's `mutreport` turns that into the FAIL, and a
# mut that returned 1 with no reason written is reported as a harness fault, never as silence.
mutbad() { printf '%s\n' "$1" > "$MUTROOT/$n.why"; }
mutreport() {
  if [ -s "$MUTROOT/$1.why" ]; then bad "$(cat "$MUTROOT/$1.why")"
  else bad "MUTANT HARNESS [$1]: the mutant was not scored and no reason was recorded"; fi
}
mut() {
  local n="$1" s="$2" prog="$3" base_line="$4" staged="$5" d="$MUTROOT/$1" a h
  shift 5
  for a in "$@"; do
    h="$("$REAL_GREP" -cxF -- "$a" "$RECON/$s")" || h=0
    [ "$h" -eq 1 ] || { mutbad "MUTANT STALE [$n]: anchor matches $h line(s) of $s, not 1 -- re-anchor on the same site, never relax the arm: $a"; return 1; }
  done
  h="$("$REAL_GREP" -cxF -- 'ZZ-PSB-NO-SUCH-LINE-ZZ' "$RECON/$s")" || h=0
  [ "$h" -eq 0 ] || { mutbad "MUTANT HARNESS [$n]: the impossible-anchor control matched $h line(s)"; return 1; }
  mkdir -p "$MUTROOT"; cp -R "$RECON" "$d" || { mutbad "MUTANT HARNESS [$n]: copy failed"; return 1; }
  awk "$prog" "$RECON/$s" > "$d/$s" || { mutbad "MUTANT DID NOT APPLY [$n]: awk failed"; return 1; }
  if cmp -s "$RECON/$s" "$d/$s"; then mutbad "MUTANT DID NOT APPLY [$n]: the copy is byte-identical"; return 1; fi
  bash -n "$d/$s" 2>/dev/null || { mutbad "MUTANT DID NOT APPLY [$n]: the mutant does not parse"; return 1; }
  h="$("$REAL_GREP" -cxF -- "$base_line" "$d/$s")" || h=0
  [ "$h" -eq 1 ] || { mutbad "MUTANT DID NOT APPLY [$n]: the base spelling is present $h time(s), not 1"; return 1; }
  # `-` for a mutant that DELETES a line with no staged counterpart (M-Art-merge): its anchors and
  # its base line still bind it, and `cmp -s` proves it applied.
  if [ "$staged" != - ]; then
    h="$("$REAL_GREP" -cF -- "$staged" "$d/$s")" || h=0
    [ "$h" -eq 0 ] || { mutbad "MUTANT PARTIAL [$n]: the staged spelling '$staged' survives $h time(s) -- a partial revert proves the layer left in place"; return 1; }
  fi
  [ -f "$d/lib.sh" ] || { mutbad "MUTANT HARNESS [$n]: lib.sh is not beside the mutant"; return 1; }
  printf '%s\n' "$d"
}
# Line-for-line replacement: drop each line equal to $DROP1/$DROP2, replace the line equal to $OLD.
SWAP='$0==ENVIRON["DROP1"] {next} $0==ENVIRON["DROP2"] {next} $0==ENVIRON["OLD"] {print ENVIRON["NEW"]; next} {print}'
# Block replacement: from the line equal to $START through the $NFI-th following line equal to $END
# (inclusive), print $NEW instead.
BLOCK='!inb && $0==ENVIRON["START"] {inb=1; seen=0; print ENVIRON["NEW"]; next}
       inb { if ($0==ENVIRON["END"]) { seen++; if (seen==ENVIRON["NFI"]+0) inb=0 } next }
       {print}'

# score <mutant-name> <own-arm> <recon-copy>
score() {
  local m="$1" own="$2" d="$3" k A s want got_own="" others_ok=1 detail=""
  k="$(col "$own" 2)"
  for A in $(arms_of "$k"); do
    set -- $(forced "$A" "$d" "$m")
    if [ "$A" = "$own" ]; then
      got_own="$1 fired=${2:-0}"
      [ "${2:-0}" -gt 0 ] && [ "$1" = "$(col "$A" 5)" ] || got_own="!$got_own"
    else
      [ "${2:-0}" -gt 0 ] && [ "$1" = "$(col "$A" 4)" ] || { others_ok=0; detail="$detail $A=$1"; }
    fi
  done
  report_score "$m" "$own" "$k" "$got_own" "$others_ok" "$detail" "$(col "$own" 5)"
  return 0
}
# score_as <mutant-name> <key> <recon-copy> <arm=shape>... -- for a mutant whose own arm lands on a
# shape OTHER than the base spelling's (M-U2a reads EMPTY, the silent clear, where the whole base
# pipeline read rc 1), or that two arms genuinely both own. Every arm NOT named must stay at its
# tip shape, so an undeclared move is still ENTANGLED.
# ITS LOCAL IS `sfails`, NEVER `fails`: a local of that name shadows the global counter, and `bad`'s
# `$((fails+1))` then evaluates the SURVIVED detail (`U5b=XFSZ-RC0-LOST(...)`) as arithmetic, which
# under `set -u` aborts the whole fixture on its first unbound word -- exit 0 through the EXIT trap,
# every later mutant unscored. Measured on the first survivor this function ever reported.
score_as() {
  local m="$1" k="$2" d="$3" A want got sfails="" others_ok=1 detail="" named=""
  shift 3
  for A in $(arms_of "$k"); do
    want=""
    for _p in "$@"; do [ "${_p%%=*}" = "$A" ] && want="${_p#*=}"; done
    set -- $(forced "$A" "$d" "$m") "$@"
    got="$1"; local fired="${2:-0}"; shift 2
    if [ -n "$want" ]; then
      named="$named $A=$got"
      [ "$fired" -gt 0 ] && [ "$got" = "$want" ] || sfails="$sfails $A=$got(want $want,fired=$fired)"
    else
      [ "$fired" -gt 0 ] && [ "$got" = "$(col "$A" 4)" ] || { others_ok=0; detail="$detail $A=$got"; }
    fi
  done
  if [ -n "$sfails" ]; then bad "MUTANT SURVIVED [$m]:$sfails -- the arm cannot see its own site revert"
  elif [ "$others_ok" -eq 1 ]; then ok "MUTANT KILLED [$m]:$named, every other $k arm stays at its tip shape"
  else bad "MUTANT ENTANGLED [$m]:$named but undeclared arm(s) moved too:$detail"; fi
  return 0
}
report_score() { # <m> <own> <k> <got_own> <others_ok> <detail> <base-shape>
  local m="$1" own="$2" k="$3" got_own="$4" others_ok="$5" detail="$6"
  case "$got_own" in
    '!'*) bad "MUTANT SURVIVED [$m]: arm $own read ${got_own#!}, expected the base shape $7 -- the arm cannot see its own site revert" ;;
    *) if [ "$others_ok" -eq 1 ]; then
         ok "MUTANT KILLED [$m]: $own reads $got_own (the base shape), every other $k arm stays at its tip shape"
       else
         bad "MUTANT ENTANGLED [$m]: $own reads $got_own but other arm(s) moved too:$detail"
       fi ;;
  esac
  return 0
}

LR=ledger-reverify.sh
if sg lrpe; then
  d="$(DROP1='  receipt_path_tokens "$_norev" > "$LR_STAGE/absent-tokens" || return 3' DROP2='ZZ-PSB-NONE' \
       OLD='  done < "$LR_STAGE/absent-tokens"' NEW='  done < <(receipt_path_tokens "$_norev")' \
       mut M-L1 "$LR" "$SWAP" '  done < <(receipt_path_tokens "$_norev")' 'absent-tokens' \
         '  receipt_path_tokens "$_norev" > "$LR_STAGE/absent-tokens" || return 3' '  done < "$LR_STAGE/absent-tokens"')" \
    && score M-L1 L1 "$d" \
    || mutreport M-L1
  d="$(DROP1='  receipt_path_tokens "$1" > "$LR_STAGE/named-tokens" || return 3' DROP2='ZZ-PSB-NONE' \
       OLD='  done < "$LR_STAGE/named-tokens"' NEW='  done < <(receipt_path_tokens "$1")' \
       mut M-L2 "$LR" "$SWAP" '  done < <(receipt_path_tokens "$1")' 'named-tokens' \
         '  receipt_path_tokens "$1" > "$LR_STAGE/named-tokens" || return 3' '  done < "$LR_STAGE/named-tokens"')" \
    && score M-L2 L2 "$d" \
    || mutreport M-L2
  d="$(DROP1='  git -C "$DIST" -c core.quotePath=false ls-tree -r --name-only "${THEIRS}" -- core/ > "$LR_STAGE/core-map-ls-tree" 2>/dev/null || return 1' DROP2='ZZ-PSB-NONE' \
       OLD='  done < "$LR_STAGE/core-map-ls-tree" > "$CORE_MAP"' \
       NEW='  done < <(git -C "$DIST" -c core.quotePath=false ls-tree -r --name-only "${THEIRS}" -- core/ 2>/dev/null) > "$CORE_MAP"' \
       mut M-L3 "$LR" "$SWAP" '  done < <(git -C "$DIST" -c core.quotePath=false ls-tree -r --name-only "${THEIRS}" -- core/ 2>/dev/null) > "$CORE_MAP"' 'core-map-ls-tree' \
         '  git -C "$DIST" -c core.quotePath=false ls-tree -r --name-only "${THEIRS}" -- core/ > "$LR_STAGE/core-map-ls-tree" 2>/dev/null || return 1' \
         '  done < "$LR_STAGE/core-map-ls-tree" > "$CORE_MAP"')" \
    && score M-L3 L3 "$d" \
    || mutreport M-L3
  # The walk and its sort are four lines (two commands, each with its `|| pc_refuse` continuation);
  # all four go, and the reader line gets the base substitution back, in one copy.
  d="$(START='  find "$CONS/$old_prefix" -type f > "$PC_STAGE/orphan-walk" 2>/dev/null \' \
       END='    || pc_refuse "the orphan walk of $CONS/$old_prefix could not be sorted (sort exited $?)"' NFI=1 NEW='' \
       OLD='  done < "$PC_STAGE/orphan-sorted"' NEW2='  done < <(find "$CONS/$old_prefix" -type f 2>/dev/null | sort)' \
       mut M-P1 preclassify.sh '!inb && $0==ENVIRON["START"] {inb=1; next}
             inb { if ($0==ENVIRON["END"]) inb=0; next }
             $0==ENVIRON["OLD"] {print ENVIRON["NEW2"]; next} {print}' \
         '  done < <(find "$CONS/$old_prefix" -type f 2>/dev/null | sort)' 'orphan-walk' \
         '  find "$CONS/$old_prefix" -type f > "$PC_STAGE/orphan-walk" 2>/dev/null \' \
         '    || pc_refuse "the orphan walk of $CONS/$old_prefix could not be sorted (sort exited $?)"' \
         '  done < "$PC_STAGE/orphan-sorted"')" \
    && score M-P1 P1 "$d" \
    || mutreport M-P1
  # M-P2 / M-P3: each membership test fed by its 1749b545 here-string / heredoc again. The base
  # shape is keyed on bash's own staging message, so a bash that stages nothing reads OTHER, not a kill.
  PM_S_T='setup_sited() { pc_has_line "$SETUP_SITED_PATHS" "$1"; }'
  PM_S_B='setup_sited() { grep -qxF "$1" <<<"$SETUP_SITED_PATHS"; }'
  d="$(DROP1=ZZ-PSB-NONE DROP2=ZZ-PSB-NONE OLD="$PM_S_T" NEW="$PM_S_B" \
       mut M-P2 preclassify.sh "$SWAP" "$PM_S_B" 'pc_has_line "$SETUP_SITED_PATHS"' "$PM_S_T")" \
    && score M-P2 P2 "$d" \
    || mutreport M-P2
  PM_M_T='is_machinery() { pc_has_line "$MACHINERY_PATHS" "$1"; }'
  PM_M_B='is_machinery() { grep -qxF "$1" <<EOF'
  d="$(DROP1=ZZ-PSB-NONE DROP2=ZZ-PSB-NONE OLD="$PM_M_T" NEW="$PM_M_B"$'\n$MACHINERY_PATHS\nEOF\n}' \
       mut M-P3 preclassify.sh "$SWAP" "$PM_M_B" 'pc_has_line "$MACHINERY_PATHS"' "$PM_M_T")" \
    && score M-P3 P3 "$d" \
    || mutreport M-P3
  E_B1='only_render="$(LC_ALL=C comm -23 <(printf '"'"'%s\n'"'"' "$want" | norm_rows) <(printf '"'"'%s\n'"'"' "$got" | norm_rows))"'
  E_B2='only_report="$(LC_ALL=C comm -13 <(printf '"'"'%s\n'"'"' "$want" | norm_rows) <(printf '"'"'%s\n'"'"' "$got" | norm_rows))"'
  d="$(START='er_sets_why=""' END='fi' NFI=1 NEW="$E_B1
$E_B2
er_sets_why=\"\"" \
       mut M-E1 emit-report.sh "$BLOCK" "$E_B1" 'sets.want-rows' 'er_sets_why=""')" \
    && score M-E1 E1 "$d" \
    || mutreport M-E1
  S_B1='    r1_missing="$(comm -23 <(printf '"'"'%s\n'"'"' "$r1_theirs") <(printf '"'"'%s\n'"'"' "$r1_ours") | tr '"'"'\n'"'"' '"'"' '"'"' | sed '"'"'s/ *$//'"'"')"'
  d="$(START='    r1_why=""' END='    elif [ -n "$r1_missing" ]; then' NFI=1 NEW="$S_B1
    if [ -n \"\$r1_missing\" ]; then" \
       mut M-S1 self-update-gate.sh "$BLOCK" "$S_B1" 'r1-theirs' '    r1_why=""' '    elif [ -n "$r1_missing" ]; then')" \
    && score M-S1 S1 "$d" \
    || mutreport M-S1
  S_B2='GATING="$(printf '"'"'%s\n'"'"' "$INVOKED" | grep -Fxf <(printf '"'"'%s\n'"'"' "$CHANGED") 2>/dev/null || true)"'
  # The staged block closes with TWO column-0 `fi`s: the staging if/elif/else, then the refusal.
  d="$(START='gating_why=""' END='fi' NFI=2 NEW="$S_B2" \
       mut M-S2 self-update-gate.sh "$BLOCK" "$S_B2" 'gating-changed' 'gating_why=""')" \
    && score M-S2 S2 "$d" \
    || mutreport M-S2
  # S3: the staging block and its refusal, through the sed that reads the staged file, become the
  # base two-line pipeline again -- every layer in one copy.
  S_B3='CHANGED="$(git -C "$DIST" diff --name-only "${BASE}..${THEIRS}" -- core/scripts/ 2>/dev/null \'
  S_B3b='            | sed '"'"'s|.*/||'"'"' | sort -u)"'
  d="$(START='changed_why=""' END='CHANGED="$(sed '"'"'s|.*/||'"'"' "$TMP/changed-raw" | sort -u)"' NFI=1 NEW="$S_B3
$S_B3b" \
       mut M-S3 self-update-gate.sh "$BLOCK" "$S_B3" 'changed-raw' 'changed_why=""' \
         'CHANGED="$(sed '"'"'s|.*/||'"'"' "$TMP/changed-raw" | sort -u)"')" \
    && { score M-S3 S3 "$d"
         # THE HEALTHY PATH IS BYTE-IDENTICAL TO THE BASE SPELLING on the world S3 forces: same
         # stdout rows from the staged diff and from the pipeline it replaced, sides shown to differ.
         _o() { local r; r="$(mktemp -d "$WORK/sg-bi.XXXXXX")" && cp -R "$WORK/gw-gt/consumer/." "$r/" \
                  && "$REAL_BASH" "$1/self-update-gate.sh" "$WORK/gw-gt/dist" "$(cat "$WORK/gw-gt/B")" "$(cat "$WORK/gw-gt/T")" "$r" 2>/dev/null; }
         _a="$(_o "$RECON")"; _b="$(_o "$d")"
         if cmp -s "$RECON/self-update-gate.sh" "$d/self-update-gate.sh"; then bad "S3 healthy differential: the two gate copies are identical"
         elif [ -n "$_a" ] && [ "$_a" = "$_b" ]; then ok "S3 healthy: the staged diff prints byte-identical rows to the base pipeline ($(cut -f1 <<<"$_a" | sort | uniq -c | tr -s ' ' | tr '\n' ';'))"
         else bad "S3 healthy: the staged diff and the base pipeline disagree on a readable range"; fi; } \
    || mutreport M-S3
fi

UD=unregistered-drift.sh
N0='ZZ-PSB-NONE'
if sg ud; then
# M-U-base: THE WHOLE BASE LISTING PIPELINE RESTORED, which makes the copy byte-identical to
# unregistered-drift.sh at the parent release apart from its comments. It is the in-fixture form of
# "the parent's copy exits 1 on an empty scan set": every U arm must read its base shape at once.
# WRITTEN STRAIGHT TO A FILE, never through `$( )` or ENVIRON: bash 3.2 mis-scans the body's
# unbalanced `(` inside a heredoc in a command substitution, and BSD awk joins a backslash-newline
# inside an ENVIRON value. Measured both ways: the base-line count read 0 each time.
U_BASE_F="$MUTROOT/u-base-head.txt"
cat > "$U_BASE_F" <<'EOB' || { echo "FIXTURE ERROR: could not write $U_BASE_F" >&2; exit 2; }
{ { command -v memo_ls_tree >/dev/null 2>&1 \
    && memo_ls_tree "$DIST" "$BASE" \
       | grep -E '^(core/skills/ai-dlc/|core/skills/ai-dlc-setup/|core/team-roles/|core/hooks/|core/schemas/)'; } \
  || git -C "$DIST" ls-tree -r --name-only "$BASE" -- \
      core/skills/ai-dlc core/skills/ai-dlc-setup core/team-roles core/hooks core/schemas 2>/dev/null; } \
  | grep -E '\.(md|sh|json)$' \
  | while IFS= read -r cp; do
EOB
_h="$("$REAL_GREP" -c . "$U_BASE_F")" || _h=0
[ "$_h" -eq 7 ] || { echo "FIXTURE ERROR: the base listing block is $_h line(s), not 7" >&2; exit 2; }
# THE EMIT, EVERY LAYER. The tip counts each failed write and leaves through `ud_finish`; the base
# spelling discards printf's status and exits where it stands. M-U-base restores all of it, so the
# copy is the whole earlier program and not a hybrid whose listing is old and whose exit is new.
# U_EMIT_T is the tip emit's FAILURE branch -- the line that counts a lost row; U_EMIT_B the whole
# one-line base emit. U_BREAK_T is the scan loop's stop at the first failed write.
U_EMIT_T='  else ud_emit_failed=$(( ud_emit_failed + 1 )); fi'
U_EMIT_B="emit() { printf '%s\\t%s\\t%s\\n' \"\$1\" \"\$2\" \"\$3\"; }"
U_BREAK_T='      [ "$ud_emit_failed" -eq 0 ] || break'
U_BASE_PROG='!inb && $0==ENVIRON["START"] {inb=1; while ((getline l < ENVIRON["NEWF"]) > 0) print l; next}
  inb { if ($0==ENVIRON["END"]) inb=0; next }
  $0=="emit() {" {print ENVIRON["EMIT_B"]; ine=1; next}
  ine { if ($0=="}") ine=0; next }
  $0=="ud_emit_failed=0" || $0=="ud_emit_ok=0" || $0==ENVIRON["BREAK_T"] {next}
  $0=="ud_finish() {" {inf=1; next}
  inf { if ($0=="}") inf=0; next }
  $0=="  ud_finish" {print "  exit 0"; next}
  $0==ENVIRON["DONE_T"] {print "    done"; tail=1; next}
  tail && ($0 ~ /^#/ || $0=="ud_finish") {next}
  {print}'
  d="$(START='ud_scan_why=""' END='while IFS= read -r cp; do' NEWF="$U_BASE_F" DONE_T='    done < "$UD_DIFF_TMP/scan-set"' \
       EMIT_B="$U_EMIT_B" BREAK_T="$U_BREAK_T" \
       mut M-U-base "$UD" "$U_BASE_PROG" "  | grep -E '\\.(md|sh|json)\$' \\" 'ud_scan_why' \
         'ud_scan_why=""' 'while IFS= read -r cp; do' '    done < "$UD_DIFF_TMP/scan-set"' 'ud_finish' \
         'ud_emit_failed=0' 'ud_emit_ok=0' 'emit() {' 'ud_finish() {' "$U_EMIT_T" "$U_BREAK_T")" \
    && { _h="$("$REAL_GREP" -v '^ *#' "$d/$UD" | "$REAL_GREP" -c 'ud_finish\|ud_emit_failed\|ud_emit_ok')" || _h=0
         [ "$_h" -eq 0 ] || bad "MUTANT PARTIAL [M-U-base]: $_h code line(s) still carry ud_finish/ud_emit_failed/ud_emit_ok -- the emit layer was not restored"
         # U5 reads rc 1 here, not the parent release's 0: before the scan set was staged the loop
         # was the last stage of a pipeline, and the failed write became its status. U5b reads rc 0
         # even so (measured on the d1c72fa9 copy: rc 0, 11 of 21 rows, the HARD row lost) -- the
         # pipeline status carried a closed fd's failure and not EFBIG's.
         score_as M-U-base ud "$d" U1=RC1-NOROW U2=RC1-NOROW U2b=SCANNED U3=RC2-NOROW U4=SCANNED U5=CLOSED-RC1 U5b=XFSZ-RC0-LOST
         # THE HEALTHY PATH IS BYTE-IDENTICAL TO THE BASE SPELLING, on every world that scans a file.
         # The two sides are asserted to DIFFER first, or the comparison reads the same program twice.
         for _w in "$UW_OK" "$UW_HU" "$UW_BIG"; do
           _a="$("$REAL_BASH" "$RECON/$UD" "$_w/dist" "$(cat "$_w/B")" "$_w/consumer" "$(cat "$_w/T")" 2>/dev/null)"
           _b="$("$REAL_BASH" "$d/$UD" "$_w/dist" "$(cat "$_w/B")" "$_w/consumer" "$(cat "$_w/T")" 2>/dev/null)"
           if cmp -s "$RECON/$UD" "$d/$UD"; then bad "U healthy differential: the two unregistered-drift.sh copies are identical, so the comparison reads one program twice"
           elif [ -n "$_a" ] && [ "$_a" = "$_b" ]; then ok "U healthy ($(basename "$_w")): the staged listing prints byte-identical rows to the base pipeline ($(cut -f1 <<<"$_a" | tr '\n' ' '))"
           else bad "U healthy ($(basename "$_w")): the staged listing and the base pipeline disagree on a world both can scan (tip [$(cut -f1 <<<"$_a" | tr '\n' ' ')] base [$(cut -f1 <<<"$_b" | tr '\n' ' ')])"; fi
         done; } \
    || mutreport M-U-base
# THE WRITE-FAILURE FIX IS TWO LAYERS -- the per-emit COUNT and the CHECK in `ud_finish` that reads
# it -- and each has its own mutant. Either one alone restores the parent release's behaviour, so
# both land on U5 AND U5b at the parent's shapes: the two arms genuinely both own each of them.
# M-U-emit-status: emit discards printf's status again, so the count never moves. The emit's
# failure branch becomes a no-op; the success count is left as it is (nothing reads it on rc 0).
  d="$(DROP1="$N0" DROP2="$N0" OLD="$U_EMIT_T" NEW='  else :; fi' \
       mut M-U-emit-status "$UD" "$SWAP" '  else :; fi' 'else ud_emit_failed=$((' "$U_EMIT_T")" \
    && score_as M-U-emit-status ud "$d" U5=CLOSED-RC0 U5b=XFSZ-RC0-LOST \
    || mutreport M-U-emit-status
# M-U-exit: the final write-failure check deleted, so `ud_finish` exits 0 whatever the count says.
# (Before the fix this mutant deleted a trailing `exit 0`; that line is gone, and deleting the check
# is the mutation that asserts the same observable -- a lost row is not an rc-0 clean scan.)
  d="$(START='  if [ "$ud_emit_failed" -gt 0 ]; then' END='  fi' NFI=1 NEW='  : ZZ-PSB-M-UEXIT' \
       mut M-U-exit "$UD" "$BLOCK" '  : ZZ-PSB-M-UEXIT' 'the scan stopped there and its output is INCOMPLETE' \
         '  if [ "$ud_emit_failed" -gt 0 ]; then')" \
    && score_as M-U-exit ud "$d" U5=CLOSED-RC0 U5b=XFSZ-RC0-LOST \
    || mutreport M-U-exit
# M-U-probe: the per-emit count replaced by ONE pre-flight test of stdout at start -- the wrong fix
# that satisfies a closed-stdout arm. U5 CANNOT kill it (a closed fd fails the probe and the named
# refusal follows); U5b is its killer, because a file that accepts the first write and refuses a
# later one passes a probe taken before any row. That asymmetry is why U5b exists.
# The probe is `( exec 3>&1 )`, measured to fail on a closed fd and to PASS on a file that will hit
# EFBIG -- the pre-flight test a closed-stdout arm cannot tell from a count.
  d="$(E="$U_EMIT_T" \
       mut M-U-probe "$UD" '$0==ENVIRON["E"] {print "  else :; fi"; next}
         $0=="ud_emit_ok=0" {print; print "( exec 3>&1 ) 2>/dev/null || ud_emit_failed=1"; next} {print}' \
         '( exec 3>&1 ) 2>/dev/null || ud_emit_failed=1' 'else ud_emit_failed=$((' "$U_EMIT_T" 'ud_emit_ok=0')" \
    && score M-U-probe U5b "$d" \
    || mutreport M-U-probe
# M-U-nobreak: the scan loop's stop at the first failed write deleted. Its rc, its rows and its N
# are all the fixed script's (a leaked row makes every later iteration skip its file), so only the
# ITERATION count U5b reads can see it: XFSZ-RC2-NOSTOP. U5's one-file world cannot.
  d="$(BREAK_T="$U_BREAK_T" mut M-U-nobreak "$UD" '$0==ENVIRON["BREAK_T"] {next} {print}' '      rel="${cp#core/}"' '|| break' \
         "$U_BREAK_T" '      rel="${cp#core/}"')" \
    && score_as M-U-nobreak ud "$d" U5b=XFSZ-RC2-NOSTOP \
    || mutreport M-U-nobreak
# M-U-memo: the memo branch's status unread, so a failed memo listing is taken as an empty one and
# the direct listing is never tried. U2 reads EMPTY -- the silent clear, not the base's rc 1 -- and
# U2b, the near-miss whose direct listing WOULD have answered, reads EMPTY too: both own it. So do
# U6-hit and U6-fill: the memo's 125 for a failed serve reaches the fallback only through this read.
  d="$(DROP1="$N0" DROP2="$N0" OLD='    ud_memo_rc=$?' NEW='    ud_memo_rc=0' \
       mut M-U-memo "$UD" "$SWAP" '    ud_memo_rc=0' 'ud_memo_rc=$?' '    ud_memo_rc=$?')" \
    && score_as M-U-memo ud "$d" U2=EMPTY U2b=EMPTY U6-hit=EMPTY U6-fill=EMPTY \
    || mutreport M-U-memo
# lib.sh's two serves of the cached ls-tree listing, one mutant each, each killed by its own cell.
# M-L-cat-status: memo_ls_tree's HIT path returns the cached status whatever its `cat` did. The hit
# line is spelled identically in all four memo functions, so the mutation anchors on what SEPARATES
# them -- the first such line after `memo_ls_tree() {` -- and the other three stay fixed.
LIB=lib.sh
  d="$(mut M-L-cat-status "$LIB" '$0=="memo_ls_tree() {" {inl=1}
         inl && $0=="  cat \"$_f.c\" || return 125" {print "  cat \"$_f.c\""; inl=0; next} {print}' \
         '  cat "$_f.c"' - 'memo_ls_tree() {')" \
    && score M-L-cat-status U6-hit "$d" \
    || mutreport M-L-cat-status
# M-L-commit-status: `_ai_dlc_memo_commit` returns 0 after a failed serve of the fill. Returning
# cat's own 1 would NOT be this mutant: the callers fold any non-zero into 125.
  d="$(DROP1="$N0" DROP2="$N0" OLD='  cat "$1.c" || return 125' NEW='  cat "$1.c"; return 0' \
       mut M-L-commit-status "$LIB" "$SWAP" '  cat "$1.c"; return 0' - '  cat "$1.c" || return 125')" \
    && score M-L-commit-status U6-fill "$d" \
    || mutreport M-L-commit-status
# M-U-ext / M-U-pfx: a grep status >1 accepted as "no match", one filter each.
  d="$(DROP1="$N0" DROP2="$N0" OLD='    [ "$ud_rc" -le 1 ] || ud_scan_why="the file-type filter over the tree listing exited ${ud_rc}"' NEW='    : ZZ-PSB-M-UEXT' \
       mut M-U-ext "$UD" "$SWAP" '    : ZZ-PSB-M-UEXT' 'the file-type filter over the tree listing exited' \
         '    [ "$ud_rc" -le 1 ] || ud_scan_why="the file-type filter over the tree listing exited ${ud_rc}"')" \
    && score_as M-U-ext ud "$d" U3=EMPTY \
    || mutreport M-U-ext
  d="$(DROP1="$N0" DROP2="$N0" OLD='      [ "$ud_rc" -le 1 ] || ud_scan_why="the scan-set prefix filter over the cached tree listing exited ${ud_rc}"' NEW='      : ZZ-PSB-M-UPFX' \
       mut M-U-pfx "$UD" "$SWAP" '      : ZZ-PSB-M-UPFX' 'the scan-set prefix filter over the cached tree listing exited' \
         '      [ "$ud_rc" -le 1 ] || ud_scan_why="the scan-set prefix filter over the cached tree listing exited ${ud_rc}"')" \
    && score_as M-U-pfx ud "$d" U4=EMPTY \
    || mutreport M-U-pfx
fi

# apply.sh: each site's exit read turned off, one copy per site. The other four A arms must stay
# REFUSED, so a mutant cannot be killed by an arm that watches a different detector.
if sg ap; then
AP=apply.sh
ap_off() { # <mutant> <own-arm> <indent> <line-literal> <staged-token>
  local d
  d="$(DROP1="$N0" DROP2="$N0" OLD="$3$4" NEW="${3}if false; then" \
       mut "$1" "$AP" "$SWAP" "${3}if false; then" "$5" "$3$4")" \
    && score "$1" "$2" "$d" \
    || mutreport "$1"
}
ap_off M-Aud  Aud  ''       'if [ "$UD_RC" -ne 0 ]; then'         'UD_RC" -ne 0'
ap_off M-Art  Art  '      ' 'if [ "$rt_rc" -ne 0 ]; then'         'rt_rc" -ne 0'
ap_off M-Arlp Arlp ''       'if [ "${RLP_RC:-0}" -ne 0 ]; then'   'RLP_RC:-0}" -ne 0'
ap_off M-Ald  Ald  ''       'if [ "$LD_RC" -ne 0 ]; then'         'LD_RC" -ne 0'
ap_off M-Ana  Ana  '  '     'if [ -n "$UD_NA" ]; then'            'if [ -n "$UD_NA" ]; then'
# M-Art-merge: the refusal branch stops emitting the merge row. The row is spelled identically in the
# refusal branch and the plain branch, so the mutation anchors on what SEPARATES them: the line
# directly after the refusal test.
  d="$(mut M-Art-merge "$AP" '{ if (skip && $0=="        say WORKLIST semantic-merge \"$rel\"") { skip=0; next } skip=0 }
       $0=="      if [ \"$rt_rc\" -ne 0 ]; then" {skip=1} {print}' \
         '        detector_refused retired-tokens retired-tokens.sh "$rel" "$rt_rc" rt' - \
         '      if [ "$rt_rc" -ne 0 ]; then' '        detector_refused retired-tokens retired-tokens.sh "$rel" "$rt_rc" rt')" \
    && { _h="$("$REAL_GREP" -cxF '        say WORKLIST semantic-merge "$rel"' "$d/$AP")" || _h=0
         if [ "$_h" -eq 1 ]; then score_as M-Art-merge ap "$d" Art=REFUSED-NOMERGE
         else bad "MUTANT DID NOT APPLY [M-Art-merge]: the plain merge row is present $_h time(s) in the copy, want 1 (the refusal branch's removed, the plain branch's kept)"; fi; } \
    || mutreport M-Art-merge
fi

# === layer-drift: THE PRE-FIX ENGINE, EVERY L CELL ================================================
# Each L cell must read its BASE shape on the a0a9c556 engine in this same run: the cell is shown
# able to fail, on the input it discriminates, before its tip reading above is believed.
if sg ld; then
for A in $(arms_of ld); do
  set -- $(forced "$A" "$LD_BASE" base)
  if [ "${2:-0}" -gt 0 ] && [ "$1" = "$(col "$A" 5)" ]; then
    ok "$A on the ${LD_BASE_SHA} engine (stub fired ${2}x): $1 -- the cell fails the pre-fix engine"
  elif [ "${2:-0}" -eq 0 ]; then
    bad "$A FIXTURE BROKEN: on the ${LD_BASE_SHA} engine the stub never fired, so its shape ($1) says nothing"
  else
    bad "$A on the ${LD_BASE_SHA} engine: $1, expected $(col "$A" 5) -- the cell cannot tell the pre-fix engine from the fix"
  fi
done
fi
# The C cells on the same pre-fix copy (whose hard-blockers.sh is a0a9c556's too). A here-string cell
# whose base run did NOT print bash's here-string message reads INCONCLUSIVE, never ok and never FAIL:
# that bash lost nothing, so the cell discriminates nothing on it.
if sg lc; then
for A in $(arms_of lc) $(arms_of lo) $(arms_of hb); do
  set -- $(forced "$A" "$LD_BASE" base)
  case "$LC_HEREDOC_ARMS" in
    *" $A "*) if [ ! -f "$WORK/stub/base-$A/HEREDOC" ]; then
                printf '  INCONCLUSIVE  %s on the %s engine: %s, and the run printed no here-string failure -- this bash staged nothing it could lose, so the cell cannot fail the pre-fix engine here\n' "$A" "$LD_BASE_SHA" "$1"
                continue
              fi ;;
  esac
  if [ "${2:-0}" -gt 0 ] && [ "$1" = "$(col "$A" 5)" ]; then
    ok "$A on the ${LD_BASE_SHA} engine (stub fired ${2}x): $1 -- the cell fails the pre-fix engine"
  elif [ "${2:-0}" -eq 0 ]; then
    bad "$A FIXTURE BROKEN: on the ${LD_BASE_SHA} engine the stub never fired, so its shape ($1) says nothing"
  else
    bad "$A on the ${LD_BASE_SHA} engine: $1, expected $(col "$A" 5) -- the cell cannot tell the pre-fix engine from the fix"
  fi
done
fi

# === SPELL: layer-drift.sh carries no here-string =================================================
# A non-comment `<<<` count, probed on a mktemp copy BEFORE the corpus in both directions: a seeded
# offender must count, and a seeded near-miss -- the operator inside a comment, indented as the
# engine's own comments are -- must not. The a0a9c556 engine is the positive control on the real text.
spell_count() { awk '/^[[:space:]]*#/ { next } /<<</ { n++ } END { print n + 0 }' "$1"; }
if sg spell; then
_sp="$(mktemp -d "$WORK/spell.XXXXXX")" || { echo "FIXTURE ERROR: mktemp spell" >&2; exit 2; }
cp "$RECON/layer-drift.sh" "$_sp/offender.sh" && cp "$RECON/layer-drift.sh" "$_sp/nearmiss.sh" \
  || { echo "FIXTURE ERROR: spell probe copies" >&2; exit 2; }
printf '  x="$(awk %s <<<"$y")"\n' "'{print}'" >> "$_sp/offender.sh"
printf '    # a comment naming the here-string operator, <<<"$y", is not a site\n' >> "$_sp/nearmiss.sh"
_so="$(spell_count "$_sp/offender.sh")"; _sn="$(spell_count "$_sp/nearmiss.sh")"; _st="$(spell_count "$RECON/layer-drift.sh")"
_sb="$(spell_count "$LD_BASE/layer-drift.sh")"
if [ "$_so" -ne $(( _st + 1 )) ] || [ "$_sn" -ne "$_st" ] || [ "$_sb" -eq 0 ]; then
  bad "SPELL probe: a seeded offender counted $_so (want $(( _st + 1 ))), a seeded comment near-miss $_sn (want $_st), the ${LD_BASE_SHA} engine $_sb (want > 0) -- the count cannot discriminate, so its zero below is no finding"
elif [ "$_st" -eq 0 ]; then
  ok "SPELL: layer-drift.sh carries 0 non-comment here-strings (probe: offender +1, comment near-miss +0, the ${LD_BASE_SHA} engine $_sb)"
else
  bad "SPELL: layer-drift.sh carries $_st non-comment here-string(s) -- a \`<<<\` whose temp file cannot be written feeds its command EMPTY stdin at the command's own exit status (BL-359)"
fi
# === SPELL: preclassify.sh carries no here-string, no heredoc and no `< <(` (BL-360) ===============
# P2 and P3 force the two membership tests. The third site -- the orphan pass's relocation table, a
# `done <<'RELOCATIONS'` heredoc of ~70 bytes -- CANNOT be forced on its own: `ulimit -f` binds in
# 1 KiB blocks, and the run stages its changed rows (at least one byte) and its relocation listing
# before the orphan pass, so any limit that fails that heredoc refuses the run earlier, at base and
# tip alike. This spelling count is its guard, and it also refuses `done < <(printf …)`, which
# passes every forced cell because a `printf` producer cannot fail to stage. Probed on mktemp copies
# BEFORE the corpus, in both directions, with the 1749b545 engine as the positive control.
# The program spans lines so the `gsub` and the octal quote escape never share one: S7 of
# validate-shell-portability.sh reads `sub(` plus a later backslash-digit as a backreference.
pc_spell() { awk '/^[[:space:]]*#/ { next }
  { l = $0; gsub(/<<<<+/, "", l) }
  l ~ /<<</ || l ~ /<<-?[\047"]?[A-Za-z_]/ || l ~ /< <\(/ { n++ }
  END { print n + 0 }' "$1"; }
cp "$RECON/preclassify.sh" "$_sp/pc-offender.sh" && cp "$RECON/preclassify.sh" "$_sp/pc-nearmiss.sh" \
  && git -C "$TREE_TOP" show "1749b545:core/skills/ai-dlc-update/reconcile/preclassify.sh" > "$_sp/pc-base.sh" 2>/dev/null \
  || { echo "FIXTURE ERROR: preclassify spell probe copies" >&2; exit 2; }
printf 'done < <(printf %s "$x")\n' "'%s\n'" >> "$_sp/pc-offender.sh"
printf '  # a comment naming done <<EOF and < <(x) is not a site; echo "<<<<<<< x" neither\n' >> "$_sp/pc-nearmiss.sh"
printf 'echo "<<<<<<< x"\n' >> "$_sp/pc-nearmiss.sh"
_po="$(pc_spell "$_sp/pc-offender.sh")"; _pn="$(pc_spell "$_sp/pc-nearmiss.sh")"
_pt="$(pc_spell "$RECON/preclassify.sh")"; _pb="$(pc_spell "$_sp/pc-base.sh")"
if [ "$_po" -ne $(( _pt + 1 )) ] || [ "$_pn" -ne "$_pt" ] || [ "$_pb" -ne 3 ]; then
  bad "SPELL probe (preclassify): a seeded \`< <(\` counted $_po (want $(( _pt + 1 ))), a seeded comment/conflict-marker near-miss $_pn (want $_pt), the 1749b545 engine $_pb (want its 3 sites) -- the count cannot discriminate, so its zero below is no finding"
elif [ "$_pt" -eq 0 ]; then
  ok "SPELL: preclassify.sh carries 0 non-comment here-strings, heredocs or \`< <(\` (probe: offender +1, near-miss +0, the 1749b545 engine 3)"
else
  bad "SPELL: preclassify.sh carries $_pt non-comment here-string/heredoc/\`< <(\` site(s) -- an input bash 3.2 stages to a temp file reads EMPTY when that write fails (BL-360)"
fi
fi
if sg ld; then
# THE HEALTHY PATH IS BYTE-IDENTICAL TO THE PRE-FIX ENGINE, in both modes, on every L world. The two
# engine files are asserted to DIFFER first, or the comparison reads one program twice.
if cmp -s "$RECON/layer-drift.sh" "$LD_BASE/layer-drift.sh"; then
  bad "L healthy differential: the tip and ${LD_BASE_SHA} layer-drift.sh copies are identical"
else
  for _w in ext ds; do
    for _m in classify --list-adjudications; do
      case "$_w" in ext) _W="$LW_EXT" ;; *) _W="$LW_DS" ;; esac
      set -- ; [ "$_m" = classify ] || set -- "$_m"
      "$REAL_BASH" "$RECON/layer-drift.sh" "$@" "$_W/dist" "$(cat "$_W/B")" "$(cat "$_W/T")" "$_W/consumer" > "$WORK/ldh-tip" 2>/dev/null; _ra=$?
      "$REAL_BASH" "$LD_BASE/layer-drift.sh" "$@" "$_W/dist" "$(cat "$_W/B")" "$(cat "$_W/T")" "$_W/consumer" > "$WORK/ldh-base" 2>/dev/null; _rb=$?
      _n="$("$REAL_GREP" -c . "$WORK/ldh-tip")" || _n=0
      # ds has no adjudicable row, so its listing is legitimately empty; every other pair must carry rows.
      if [ "$_ra" -eq 0 ] && [ "$_rb" -eq 0 ] && cmp -s "$WORK/ldh-tip" "$WORK/ldh-base" \
         && { [ "$_n" -gt 0 ] || [ "$_w:$_m" = "ds:--list-adjudications" ]; }; then
        ok "L healthy ($_w, $_m): rc 0 both, tip stdout byte-identical to ${LD_BASE_SHA} ($_n row(s))"
      else
        bad "L healthy ($_w, $_m): tip rc $_ra, ${LD_BASE_SHA} rc $_rb, $_n tip row(s), outputs $(cmp -s "$WORK/ldh-tip" "$WORK/ldh-base" && echo equal || echo DIFFER)"
      fi
    done
  done
fi
fi

# === layer-drift MUTANTS ==========================================================================
# Each applied by anchor to a copy of the TIP engine in a copy of the whole reconcile/ directory.
LDS=layer-drift.sh
if sg ld; then
LD_BRK_O='  [ "$ld_emit_failed" -eq 0 ] || break'
LD_BRK_E='  [ "$ld_emit_failed" -eq 0 ] || break   # as in the overrides loop'
LD_EXT_WALK='layer_files "$EXT_DIR" > "$LD_T/extensions" || _lw_rc=$?'
ld_nobreak_check() { # <copy> <want-overrides-break> <want-extensions-break>
  local a b
  a="$("$REAL_GREP" -cxF -- "$LD_BRK_O" "$1/$LDS")" || a=0
  b="$("$REAL_GREP" -cxF -- "$LD_BRK_E" "$1/$LDS")" || b=0
  [ "$a" -eq "$2" ] && [ "$b" -eq "$3" ] && return 0
  bad "MUTANT PARTIAL: the overrides-loop break is present $a time(s) (want $2) and the extensions-loop break $b (want $3)"
  return 1
}
# m1: NO BREAK at either outer loop. Rows, rc and N are the fix's (every writer is guarded), so only
# the ITERATION count after the first failed write can see it: L5b (extensions) and L5e (overrides).
  d="$(O1="$LD_BRK_O" O2="$LD_BRK_E" mut M-LD-nobreak "$LDS" '$0==ENVIRON["O1"] || $0==ENVIRON["O2"] {next} {print}' \
         "$LD_EXT_WALK" - "$LD_BRK_O" "$LD_BRK_E" "$LD_EXT_WALK")" \
    && { ld_nobreak_check "$d" 0 0 && score_as M-LD-nobreak ld "$d" L5b=XFSZ-RC2-NOSTOP L5e=XFSZ-RC2-NOSTOP; } \
    || mutreport M-LD-nobreak
# m1a / m1b: one loop's break each, so each break has a cell the other cannot cover.
  d="$(O1="$LD_BRK_O" mut M-LD-nobreak-ovr "$LDS" '$0==ENVIRON["O1"] {next} {print}' \
         "$LD_EXT_WALK" - "$LD_BRK_O" "$LD_EXT_WALK")" \
    && { ld_nobreak_check "$d" 0 1 && score_as M-LD-nobreak-ovr ld "$d" L5e=XFSZ-RC2-NOSTOP; } \
    || mutreport M-LD-nobreak-ovr
  d="$(O2="$LD_BRK_E" mut M-LD-nobreak-ext "$LDS" '$0==ENVIRON["O2"] {next} {print}' \
         "$LD_EXT_WALK" - "$LD_BRK_E" "$LD_EXT_WALK")" \
    && { ld_nobreak_check "$d" 1 0 && score_as M-LD-nobreak-ext ld "$d" L5b=XFSZ-RC2-NOSTOP; } \
    || mutreport M-LD-nobreak-ext
# m2: the per-write count replaced by ONE pre-flight probe of stdout at start. A closed fd fails the
# probe, so L5 and L5c cannot kill it; every EFBIG cell does, because a file that accepts the first
# write and refuses a later one passes a probe taken before any row.
LD_FAILBR='  else ld_emit_failed=$(( ld_emit_failed + 1 )); fi'
LD_PROBE='( exec 3>&1 ) 2>/dev/null || ld_emit_failed=1'
  d="$(E="$LD_FAILBR" P="$LD_PROBE" mut M-LD-probe "$LDS" '$0==ENVIRON["E"] {print "  else :; fi"; next}
         $0=="ld_emit_failed=0" {print; print ENVIRON["P"]; next} {print}' \
         "$LD_PROBE" 'else ld_emit_failed=$((' "$LD_FAILBR" 'ld_emit_failed=0')" \
    && score_as M-LD-probe ld "$d" L5b=XFSZ-RC0-LOST L5b-hard=XFSZ-RC0-LOST L5d=XFSZ-RC1-MEMO L5e=XFSZ-RC0-LOST \
    || mutreport M-LD-probe
# m3: the OVERRIDE-DOUBLE-SHADOW block back in its `| while | while` subshells, the pre-fix shape
# restored line for line: the emit's count lands in a copy that is thrown away. L5d owns it.
LD_DS1="  ' | sort > \"\$LD_T/double-shadow\" || _ds_rc=\$?"
LD_DS2='  [ "$_ds_rc" -eq 0 ] || ld_refuse "the grouping of shadow targets for OVERRIDE-DOUBLE-SHADOW" "$_ds_rc"'
LD_DS3='  while IFS="$TAB" read -r label entries cnt; do'
LD_DS4='    while IFS= read -r one; do'
LD_DS5='    done < "$LD_T/double-shadow-entries"'
LD_DS6='  done < "$LD_T/double-shadow"'
# The entry split is staged too (its own status read, its own ld_refuse): the mutant deletes those
# three lines along with the grouping's, so the restored block is the pre-fix pipe and nothing else.
LD_DS7='    _dse_rc=0'
LD_DS8="    printf '%s\\n' \"\$entries\" | tr ',' '\\n' | sed 's/^ *//' > \"\$LD_T/double-shadow-entries\" || _dse_rc=\$?"
LD_DS9='    [ "$_dse_rc" -eq 0 ] || ld_refuse "the entry split for OVERRIDE-DOUBLE-SHADOW '"'"'${label}'"'"'" "$_dse_rc"'
LD_DS1B="  ' | sort | while IFS=\"\$TAB\" read -r label entries cnt; do"
LD_DS4B="    printf '%s\\n' \"\$entries\" | tr ',' '\\n' | sed 's/^ *//' | while IFS= read -r one; do"
  d="$(A1="$LD_DS1" A2="$LD_DS2" A3="$LD_DS3" A4="$LD_DS4" A5="$LD_DS5" A6="$LD_DS6" A7="$LD_DS7" A8="$LD_DS8" A9="$LD_DS9" N1="$LD_DS1B" N4="$LD_DS4B" \
       mut M-LD-ds-subshell "$LDS" '$0==ENVIRON["A1"] {print ENVIRON["N1"]; next}
         $0==ENVIRON["A2"] || $0==ENVIRON["A3"] {next}
         $0==ENVIRON["A7"] || $0==ENVIRON["A8"] || $0==ENVIRON["A9"] {next}
         $0==ENVIRON["A4"] {print ENVIRON["N4"]; next}
         $0==ENVIRON["A5"] {print "    done"; next}
         $0==ENVIRON["A6"] {print "  done"; next} {print}' \
         "$LD_DS4B" 'LD_T/double-shadow' "$LD_DS1" "$LD_DS2" "$LD_DS3" "$LD_DS4" "$LD_DS5" "$LD_DS6" "$LD_DS7" "$LD_DS8" "$LD_DS9")" \
    && { _h="$("$REAL_GREP" -cxF -- "$LD_DS1B" "$d/$LDS")" || _h=0
         if [ "$_h" -eq 1 ] && "$REAL_GREP" -qxF -- "$LD_DS1B" "$LD_BASE/$LDS" && "$REAL_GREP" -qxF -- "$LD_DS4B" "$LD_BASE/$LDS"; then
           score_as M-LD-ds-subshell ld "$d" L5d=XFSZ-RC0-LOST
         else bad "MUTANT DID NOT APPLY [M-LD-ds-subshell]: the restored pipe lines are not the ${LD_BASE_SHA} spelling (outer present $_h time(s))"; fi; } \
    || mutreport M-LD-ds-subshell
# m4: emit_raw uncounted -- the writer of every HARD-LAYER-ADJUDICATION-MISSING row. L5b-hard, whose
# one failed write is that row, reads rc 0; no other cell's failing write is emit_raw's.
LD_RAW="  printf '%s\\t%s\\t%s\\t%s\\n' \"\$1\" \"\$2\" \"\$3\" \"\$4\"; ld_wrote \$?"
LD_RAWB="  printf '%s\\t%s\\t%s\\t%s\\n' \"\$1\" \"\$2\" \"\$3\" \"\$4\""
  d="$(DROP1="$N0" DROP2="$N0" OLD="$LD_RAW" NEW="$LD_RAWB" \
       mut M-LD-raw-uncounted "$LDS" "$SWAP" "$LD_RAWB" - "$LD_RAW")" \
    && score_as M-LD-raw-uncounted ld "$d" L5b-hard=XFSZ-RC0-LOST \
    || mutreport M-LD-raw-uncounted
fi

if sg lc; then
# === BL-359 MUTANTS: each restores ONE silent-read site, anchored on the line that decides it ======
# TWO SCORING KEYS, lc (the contract cells, big world) and lo (the override cells, huge world), and
# the split is a COST decision: one key made every mutant re-run all seven cells, and the unit rose
# ~31% over its pre-change wall clock (interleaved, alone). Each mutant is now held to its own key's
# cells staying at the tip shape; every cell of both keys still runs once on the tip and once on the
# a0a9c556 engine above, so no cell is unscored -- what is given up is a cross-key ENTANGLEMENT read.
# M1: ld_stage's write status ignored. Under `trap '' XFSZ` the write fails EFBIG and leaves a
# TRUNCATED file, which the readers then take as whole: C2w's anchor sits past the cut, and the
# override loses its OK row at rc 0 (measured: to the section-drift row) with NO here-string failure
# -- OK-LOST, not base's OK-LOST-HEREDOC: the truncation alone is the wrong read.
LD_STAGE_T="  printf '%s\\n' \"\$2\" > \"\$1\" || _rc=\$?"
LD_STAGE_M="  printf '%s\\n' \"\$2\" > \"\$1\" || true"
  d="$(DROP1="$N0" DROP2="$N0" OLD="$LD_STAGE_T" NEW="$LD_STAGE_M" \
       mut M1-stage-status "$LDS" "$SWAP" "$LD_STAGE_M" - "$LD_STAGE_T")" \
    && score_as M1-stage-status lo "$d" C2w=OK-LOST \
    || mutreport M1-stage-status
# M2: the R2 post-condition deleted -- its test line through its closing `fi` (the ld_refuse line
# inside is anchored too, so the block the mutation removes is that one and no other).
LD_R2_IF='if [ "$_ac_n" -gt 0 ] && [ -z "$ADJ_CODES" ]; then'
LD_R2_REF='  ld_refuse "the ADJUDICATED code set out of $ADJ_CONTRACT_REL" 1'
  d="$(START="$LD_R2_IF" END='fi' NFI=1 NEW=': ZZ-PSB-M2-NO-R2' \
       mut M2-no-r2 "$LDS" "$BLOCK" ': ZZ-PSB-M2-NO-R2' 'set read out of it is EMPTY' "$LD_R2_IF" "$LD_R2_REF")" \
    && score M2-no-r2 C3 "$d" \
    || mutreport M2-no-r2
# M3: the ADJUDICATED code-set awk fed by `<<<` again. A cold contract read refuses before the awk
# runs, so only C1w -- the contract served from a warm memo with nothing written -- reaches it; there
# the here-string's temp file is what fails. THE FIX IS THREE LAYERS AT THIS SITE and each is scored:
#   M3  the feed alone: bash 3.2 does not run a command whose here-string cannot be staged and the
#       site returns 1, which the KEPT status read refuses -- REFUSED-CODES, not the tip's ALL-ROWS.
#   M3b the feed AND the status read: the capture comes back empty at 0, and R2 -- the contract carries
#       a level-ADJUDICATED line, the code set is empty -- is what refuses: REFUSED-R2.
#   M2 above deletes R2 alone, on C3. The three together say no one layer is standing in for another.
LD_CODES_T="ADJ_CODES=\"\$(printf '%s\\n' \"\$ADJ_CONTRACT_TEXT\" | awk '"
LD_CODES_E="')\" || _ac_rc=\$?"
LD_CODES_B="' <<<\"\$ADJ_CONTRACT_TEXT\")\" || _ac_rc=\$?"
LD_CODES_B2="' <<<\"\$ADJ_CONTRACT_TEXT\")\""
M3_PROG='$0==ENVIRON["S"] {print "ADJ_CODES=\"$(awk '"'"'"; inb=1; next}
         inb && $0==ENVIRON["E"] {print ENVIRON["NB"]; inb=0; next} {print}'
  d="$(S="$LD_CODES_T" E="$LD_CODES_E" NB="$LD_CODES_B" \
       mut M3-codes-herestring "$LDS" "$M3_PROG" "$LD_CODES_B" "$LD_CODES_T" "$LD_CODES_T")" \
    && score_as M3-codes-herestring lc "$d" C1w=REFUSED-CODES \
    || mutreport M3-codes-herestring
  d="$(S="$LD_CODES_T" E="$LD_CODES_E" NB="$LD_CODES_B2" \
       mut M3b-codes-herestring-unread "$LDS" "$M3_PROG" "$LD_CODES_B2" "$LD_CODES_T" "$LD_CODES_T")" \
    && score_as M3b-codes-herestring-unread lc "$d" C1w=REFUSED-R2 \
    || mutreport M3b-codes-herestring-unread
# M4: section_of's status discarded at the override site -- the refusal line after it deleted.
# C2 and C2w refuse at the blob's read or staging before section_of runs; C2s fails section_of's own
# mktemp and is the only cell that reaches this line with a failing call.
LD_SEC_R='    [ "$_at_rc" -eq 0 ] || ld_refuse_staging "section_of for ${entry} #${id}" "$_at_rc"'
  d="$(DROP1="$N0" DROP2="$N0" OLD="$LD_SEC_R" NEW='    : ZZ-PSB-M4-SECTION-UNREAD' \
       mut M4-section-status "$LDS" "$SWAP" '    : ZZ-PSB-M4-SECTION-UNREAD' '"section_of for ${entry}' \
         "$LD_SEC_R" '    s_theirs="$(section_of "$id" < "$LD_T/a_text")" || _at_rc=$?')" \
    && score M4-section-status C2s "$d" \
    || mutreport M4-section-status
# M5 / M6: hard-blockers.sh's two suppressions restored to the 31a056c3 spelling, one each. Anchored
# on the TEST lines, never on the DETECTOR-REFUSED row text, which is reworded independently.
HB=hard-blockers.sh
HB_LD_T='if [ "${LD_RC:-0}" -ne 0 ]; then'
HB_LD_B='if [ -z "$LD_ROWS_FILE" ] && [ "${LD_RC:-0}" -ne 0 ]; then'
  d="$(DROP1="$N0" DROP2="$N0" OLD="$HB_LD_T" NEW="$HB_LD_B" \
       mut M5-hb-ld "$HB" "$SWAP" "$HB_LD_B" - "$HB_LD_T")" \
    && score M5-hb-ld C5-ld "$d" \
    || mutreport M5-hb-ld
HB_UD_T='    [ -z "$REFUSALS" ] && [ -z "$UD_SUPPLIED_REFUSED" ] && echo "0 HARD blockers."'
HB_UD_B='    [ -z "$REFUSALS" ] && echo "0 HARD blockers."'
  d="$(DROP1="$N0" DROP2="$N0" OLD="$HB_UD_T" NEW="$HB_UD_B" \
       mut M6-hb-ud "$HB" "$SWAP" "$HB_UD_B" - "$HB_UD_T")" \
    && score M6-hb-ud C5-ud "$d" \
    || mutreport M6-hb-ud
fi

if sg b360; then
# === BL-360: emit-report.sh reads no here-string ==================================================
# Each cell FORCES its site under `trap '' XFSZ; ulimit -f N` (SIGXFSZ ignored: the full-disk model,
# ENOSPC and no signal) with an input calibrated past the limit, and reads the render's SHAPE:
#   O1  the orientation sample (`awk … <<<"$d"`): a diff larger than the limit. Base: bash cannot stage
#       the here-string, awk never runs, the site's rc 1 renders an UNNAMED `sample exited 1` refusal.
#       Tip: the staging write's own refusal, `exited staging-<rc>`.
#   O2  the retired-token projection (`awk … <<<"$rt"`): 400 token rows past the limit. Base: the
#       refusal names a PROJECTION failure (`projection-1`) that never happened. Tip: `staging-<rc>`.
#   O3  the orientation THEIRS staging (`printf … > file`, a builtin write): THEIRS larger than the
#       limit. Base refuses too, but the builtin's unflushed bytes come out on the next stdout write --
#       upstream content INSIDE the region, outside any sample (LEAKED). Tip writes through a pipe.
#   V1  `--verify`'s preclassify check (`grep <<<"$want"`, and the two extraction lines after it): a
#       render carrying the refusal, larger than the limit. Base: grep reads EMPTY stdin, the refusal
#       is not seen, the approved region byte-matches, exit 0 "present, current, and complete" --
#       apply.sh writes on that 0. Tip: exit 1, cause UNDECIDED, staging named.
# CALIBRATED, NOT ASSUMED, per world before any shape is read: the site's own input, fed as a
# here-string under the limit, must FAIL with bash's message; every other blob in the world must
# fit under it; and on the tip the forced render may differ from its unforced control ONLY in the
# cell's own lines -- or a cell's shape could be some other write failing. Each mutant restores ONE
# site's base text in a copy and must move only its own cell to the base shape. Every forced run's
# PATH stub logs the call that proves the render reached the site (FIRED > 0).
B360="$WORK/b360"; mkdir -p "$B360" || { echo "FIXTURE ERROR: mkdir b360" >&2; exit 2; }
ER_BASE_SHA=1749b545b2e05010adb5b197a5bfd67891c1bf3b
ER_BASE="$WORK/er-base"
mkdir -p "$ER_BASE" && cp -R "$RECON/." "$ER_BASE/" \
  && git -C "$TREE_TOP" show "${ER_BASE_SHA}:core/skills/ai-dlc-update/reconcile/emit-report.sh" > "$ER_BASE/emit-report.sh" 2>/dev/null \
  || { echo "FIXTURE BROKEN: could not stage emit-report.sh at ${ER_BASE_SHA}, the failing control of every BL-360 cell" >&2; exit 2; }
# THE PREDICATE SECTION IS KEPT OUT OF EVERY BL-360 WORLD. BL-360's sites are the orientation, token
# and verify stagings; the predicate section is a different detector whose projection a later release
# changed on purpose (STABLE rows now render their population), so tip and base render it differently
# for a reason that is not BL-360. Every BL-360 render already runs under a `bash` PATH stub, so that
# stub answers `predicate-differential.sh` with no rows: tip, base and every mutant render `none` there.
# Its firings are logged apart, and a run where it never fired is refused below: an exclusion that
# stopped matching would otherwise read as a healthy-path regression.
nopd() { # nopd <stub-dir>
  local d="$1"
  { head -2 "$d/bash"
    printf '%s\n' "case \"\$*\" in *'/predicate-differential.sh '*) echo x >> \"$d/PD_FIRED\"; exit 0 ;; esac"
    tail -n +3 "$d/bash"; } > "$d/bash.nopd" && mv "$d/bash.nopd" "$d/bash" && chmod +x "$d/bash"
}
# THE PUSH-CANDIDATE LEDGER HEADING IS LIKEWISE NOT A BL-360 SITE, and a later release moved it on
# purpose: 0.706.0 added `NAMED-UPSTREAM-CITED-ONLY` to the status list it names. Tip and base would
# otherwise render that heading differently for a reason that is not BL-360, so the tip's one heading
# line is carried into the staged base, by awk keyed on the line's prefix -- never sed, whose
# replacement would read any `&` in the heading as the whole match. Exactly ONE line must be
# replaced: zero means the heading moved and the carry stopped matching; two means the prefix is no
# longer a single site. Both are FIXTURE BROKEN, never a silent skip. The `<<<"$want"` count below
# still proves the staged engine is the pre-fix one, which this carry does not touch.
_erh="$("$REAL_GREP" -F '  sub "Push-candidate ledger — ' "$RECON/emit-report.sh")" || _erh=""
_erhn="$(printf '%s\n' "$_erh" | "$REAL_GREP" -c .)" || _erhn=0
if [ "$_erhn" -ne 1 ]; then
  echo "FIXTURE BROKEN: the tip emit-report.sh carries $_erhn push-candidate ledger heading line(s), want exactly 1 to carry into the staged base" >&2; exit 2
fi
ERH="$_erh" awk 'index($0, "  sub \"Push-candidate ledger — ") == 1 { print ENVIRON["ERH"]; n++; next } { print } END { exit (n == 1) ? 0 : 3 }' \
  "$ER_BASE/emit-report.sh" > "$ER_BASE/emit-report.sh.carry" \
  && mv "$ER_BASE/emit-report.sh.carry" "$ER_BASE/emit-report.sh" \
  || { echo "FIXTURE BROKEN: the push-candidate ledger heading did not replace exactly ONE line of the staged ${ER_BASE_SHA} emit-report.sh" >&2; exit 2; }
_h="$("$REAL_GREP" -cF '<<<"$want"' "$ER_BASE/emit-report.sh")" || _h=0
if cmp -s "$RECON/emit-report.sh" "$ER_BASE/emit-report.sh" || [ "$_h" -ne 2 ]; then
  echo "FIXTURE BROKEN: the staged ${ER_BASE_SHA} emit-report.sh is not the pre-fix engine (identical to tip, or it carries $_h \`<<<\"\$want\"\` line(s), want 2)" >&2; exit 2
fi
# --- the worlds ---
# eo: a.sh -- the consumer's copy is 600 lines larger than theirs, so the diff is past the limit while
#     theirs is not (O1 alone, not O3). b.sh -- 400 `$R/tNNNN` tokens at base, all gone at theirs, all
#     kept by the consumer, so the token rows are past the limit while each blob is not (O2 alone).
# ek: c.sh -- theirs is 600 marked lines past the limit, ours one line (O3).
mk_b360_world() { # <dir> <eo|ek>
  local W="$1" D="$1/dist" C="$1/consumer" i
  mkdir -p "$D/core/scripts" "$C/scripts/ai-dlc"
  printf '0.1.0\n' > "$D/VERSION"
  if [ "$2" = eo ]; then
    printf '#!/bin/sh\necho a base\n' > "$D/core/scripts/a.sh"
    { printf '#!/bin/sh\n'; i=0; while [ $i -lt 400 ]; do printf 'x=$R/t%04d\n' $i; i=$((i+1)); done; } > "$D/core/scripts/b.sh"
  else
    printf '#!/bin/sh\necho c base\n' > "$D/core/scripts/c.sh"
  fi
  { gi "$D" init -q && gi "$D" add -A && gi "$D" commit -qm base; } >/dev/null 2>&1 || return 1
  git -C "$D" rev-parse HEAD > "$W/B"
  printf '0.2.0\n' > "$D/VERSION"
  if [ "$2" = eo ]; then
    printf '#!/bin/sh\necho a theirs\n' > "$D/core/scripts/a.sh"
    printf '#!/bin/sh\necho b theirs\n' > "$D/core/scripts/b.sh"
  else
    { printf '#!/bin/sh\n'; i=0; while [ $i -lt 600 ]; do printf 'echo ZZ-PSB-LEAK upstream line %04d of the new body\n' $i; i=$((i+1)); done; } > "$D/core/scripts/c.sh"
  fi
  { gi "$D" add -A && gi "$D" commit -qm theirs; } >/dev/null 2>&1 || return 1
  git -C "$D" rev-parse HEAD > "$W/T"
  if [ "$2" = eo ]; then
    { printf '#!/bin/sh\necho a ours\n'; i=0; while [ $i -lt 600 ]; do printf 'echo consumer line number %04d of the local adaptation\n' $i; i=$((i+1)); done; } > "$C/scripts/ai-dlc/a.sh"
    { git -C "$D" show "$(cat "$W/B"):core/scripts/b.sh"; echo 'echo consumer kept'; } > "$C/scripts/ai-dlc/b.sh"
  else
    printf '#!/bin/sh\necho c ours\n' > "$C/scripts/ai-dlc/c.sh"
  fi
}
EOW="$WORK/b360-eo"; EKW="$WORK/b360-ek"
mk_b360_world "$EOW" eo && mk_b360_world "$EKW" ek || { echo "FIXTURE ERROR: b360 worlds" >&2; exit 2; }
B360_LIM_O=8; B360_LIM_V=3
# ev: the er world above (the sibling seed), with preclassify refusing. Its APPROVED report is the tip's
# own render under the same refusal and no limit, so the region matches and only the refusal can fail it.
B360_PC_STUB="$B360/pc-stub"
stub "$B360_PC_STUB" bash "$REAL_BASH" "*'/preclassify.sh '*" "case \"\$*\" in *' --templates') ;; *) $LOGF; exit 2 ;; esac"
nopd "$B360_PC_STUB"
PATH="$B360_PC_STUB:$PATH" "$REAL_BASH" "$RECON/emit-report.sh" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" > "$B360/ev-region" 2>/dev/null
B360_REPORT="$B360/ev-report.md"
{ echo "# Reconcile report (fixture)"; echo; cat "$B360/ev-region"; } > "$B360_REPORT"
_n="$("$REAL_GREP" -c '^DETECTOR-REFUSED  preclassify\.sh exited 2 ' "$B360_REPORT")" || _n=0
[ "$_n" -ge 1 ] && [ "$(fired "$B360_PC_STUB")" -gt 0 ] \
  || { echo "FIXTURE ERROR: b360 ev world: the approved render carries $_n preclassify refusal line(s) (stub fired $(fired "$B360_PC_STUB")x), so V1 has no subject" >&2; exit 2; }

# --- calibration (a)+(b): the site inputs fail as here-strings under the limit; nothing else is near it ---
b360_hs_fails() { # <bytes> <limit-blocks> -> 0 when a here-string of that size cannot be staged
  local e
  e="$( ( trap '' XFSZ; ulimit -f "$2"; v="$(printf "%0${1}d" 0)"; cat <<<"$v" > /dev/null ) 2>&1 )"
  case "$e" in *'cannot create temp file for here'*) return 0 ;; esac; return 1
}
_eo_b="$(cat "$EOW/B")"; _eo_t="$(cat "$EOW/T")"; _ek_t="$(cat "$EKW/T")"
_in_d="$(git -C "$EOW/dist" show "${_eo_t}:core/scripts/a.sh" | diff - "$EOW/consumer/scripts/ai-dlc/a.sh" | wc -c | tr -d ' ')"
_in_rt="$("$REAL_BASH" "$RECON/retired-tokens.sh" "$EOW/dist" "$_eo_b" "$_eo_t" "$EOW/consumer" core/scripts/b.sh 2>/dev/null | wc -c | tr -d ' ')"
_in_t="$(git -C "$EKW/dist" cat-file -s "${_ek_t}:core/scripts/c.sh")" || _in_t=0
_in_w="$(awk '/BEGIN GENERATED: reconcile-mechanical/{f=1} f{print} /END GENERATED: reconcile-mechanical/{f=0}' "$B360_REPORT" | wc -c | tr -d ' ')"
_ob_o="$( { git -C "$EOW/dist" ls-tree -r -l "$_eo_b"; git -C "$EOW/dist" ls-tree -r -l "$_eo_t"; git -C "$EKW/dist" ls-tree -r -l "$(cat "$EKW/B")"
            git -C "$EKW/dist" ls-tree -r -l "$_ek_t"; } | awk '$4 + 0 > m && !($5 == "core/scripts/c.sh" && $4 + 0 > 4096) { m = $4 + 0 } END { print m + 0 }')"
_ob_v="$(git -C "$DIST" ls-tree -r -l "$THEIRS" | awk '$4 + 0 > m { m = $4 + 0 } END { print m + 0 }')"
_cal=""
b360_hs_fails "$_in_d" "$B360_LIM_O" || _cal="$_cal O1-diff($_in_d B)-staged"
b360_hs_fails "$_in_rt" "$B360_LIM_O" || _cal="$_cal O2-rows($_in_rt B)-staged"
b360_hs_fails "$_in_t" "$B360_LIM_O" || _cal="$_cal O3-theirs($_in_t B)-staged"
b360_hs_fails "$_in_w" "$B360_LIM_V" || _cal="$_cal V1-render($_in_w B)-staged"
[ "$_ob_o" -lt $(( (B360_LIM_O - 1) * LD_BLK )) ] || _cal="$_cal eo/ek-largest-other-blob($_ob_o B)"
[ "$_ob_v" -lt $(( (B360_LIM_V - 1) * LD_BLK )) ] || _cal="$_cal ev-largest-blob($_ob_v B)"
b360_hs_fails $(( LD_BLK / 2 )) "$B360_LIM_V" && _cal="$_cal a-half-block-here-string-FAILED"
if [ -n "$_cal" ]; then
  echo "FIXTURE BROKEN: BL-360 calibration -- the limit no longer bites on the site input, or something else is near it:$_cal" >&2; exit 2
fi
ok "BL-360 calibration: under ${B360_LIM_O} block(s) the diff ($_in_d B), the token rows ($_in_rt B) and theirs ($_in_t B) cannot be staged as here-strings, under ${B360_LIM_V} the render ($_in_w B) cannot; every other blob fits ($_ob_o B / $_ob_v B), a half-block here-string stages"

# --- the runs ---
# b360_run <recon> <eo|ek|ev|evp> <ctl|forced> <tag> -- one render (evp: the ev world in PRINT mode),
# stdout and stderr each through a PIPE (a file under the limit would fail on its own); rc to a file.
b360_run() {
  local R="$1" w="$2" m="$3" o="$B360/$4" sd="$B360/$4.stub" lim="" W=""
  case "$w" in
    eo|ek) W="$EOW"; [ "$w" = ek ] && W="$EKW"
           stub "$sd" bash "$REAL_BASH" "*'/retired-tokens.sh '*" "$LOGF"
           [ "$m" = forced ] && lim="$B360_LIM_O" ;;
    *)     stub "$sd" bash "$REAL_BASH" "*'/preclassify.sh '*" "case \"\$*\" in *' --templates') ;; *) $LOGF; exit 2 ;; esac"
           [ "$m" = forced ] && lim="$B360_LIM_V" ;;
  esac
  nopd "$sd"
  ( ( trap '' XFSZ; [ -z "$lim" ] || ulimit -f "$lim"; PATH="$sd:$PATH"; export PATH
      case "$w" in
        eo|ek) "$REAL_BASH" "$R/emit-report.sh" "$W/dist" "$(cat "$W/B")" "$W/consumer" "$(cat "$W/T")" ;;
        ev)    "$REAL_BASH" "$R/emit-report.sh" --verify "$B360_REPORT" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" ;;
        evp)   "$REAL_BASH" "$R/emit-report.sh" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" ;;
      esac
      echo "$?" > "$o.rc" ) 2>&1 1>&3 3>&- | cat > "$o.err" ) 3>&1 | cat > "$o.out"
}
# Shapes. Each is PRESENCE-shaped: a named line or a counted row set must appear, so a copy that never
# ran reads OTHER, never a tip or base shape.
b360_c() { local n; n="$("$REAL_GREP" -cE -- "$1" "$2")" || n=0; printf '%s' "$n"; }
b360_shape() { # <cell> <tag>
  local o="$B360/$2.out" a b c
  case "$1" in
    O1) a="$(b360_c 'orientation sample exited staging-[0-9]+ for core/scripts/a\.sh' "$o")"
        b="$(b360_c 'orientation sample exited 1 for core/scripts/a\.sh' "$o")"
        c="$(b360_c '^    ONLY IN OURS \(12 of 601 shown' "$o")"
        if [ "$a" -eq 2 ] && [ "$b" -eq 0 ] && [ "$c" -eq 0 ]; then echo REFUSED-STAGING
        elif [ "$b" -eq 2 ] && [ "$a" -eq 0 ]; then echo REFUSED-RC1
        elif [ "$c" -eq 1 ] && [ "$a" -eq 0 ] && [ "$b" -eq 0 ]; then echo SAMPLE
        else echo "OTHER(staging=$a,rc1=$b,sample=$c)"; fi ;;
    O2) a="$(b360_c 'retired-tokens\.sh exited staging-[0-9]+ for core/scripts/b\.sh' "$o")"
        b="$(b360_c 'retired-tokens\.sh exited projection-1 for core/scripts/b\.sh' "$o")"
        c="$(b360_c '^      \$R/t[0-9]{4}$' "$o")"
        if [ "$a" -eq 1 ] && [ "$b" -eq 0 ] && [ "$c" -eq 0 ]; then echo REFUSED-STAGING
        elif [ "$b" -eq 1 ] && [ "$a" -eq 0 ] && [ "$c" -eq 0 ]; then echo REFUSED-PROJECTION
        elif [ "$c" -eq 400 ] && [ "$a" -eq 0 ] && [ "$b" -eq 0 ]; then echo TOKENS-ALL
        else echo "OTHER(staging=$a,projection=$b,rows=$c)"; fi ;;
    O3) a="$(b360_c '^DETECTOR-REFUSED  orientation diff exited staging-failed for core/scripts/c\.sh' "$o")"
        # The leak is the TAIL of the lost write -- the bytes past the last flushed buffer, starting
        # mid-line (measured: `pstream line 0157 of the new body`) -- so it is keyed on the line's END,
        # never on its marker at the start, which the flushed part took with it.
        b="$(awk '/ line [0-9][0-9][0-9][0-9] of the new body$/ && !/^      / { n++ } END { print n + 0 }' "$o")"
        c="$(b360_c '^    ONLY IN THEIRS \(12 of 600 shown' "$o")"
        if [ "$b" -gt 0 ]; then echo LEAKED
        elif [ "$a" -eq 1 ] && [ "$c" -eq 0 ]; then echo REFUSED-NOLEAK
        elif [ "$c" -eq 1 ] && [ "$a" -eq 0 ]; then echo SAMPLE
        else echo "OTHER(refused=$a,leak=$b,sample=$c)"; fi ;;
    V1) a="$(cat "$B360/$2.rc" 2>/dev/null)"
        if [ "$a" = 1 ] && "$REAL_GREP" -qF 'cause: UNDECIDED — the fresh render could not be staged or read for the preclassify check' "$B360/$2.err"; then echo UNDECIDED-STAGING
        elif [ "$a" = 1 ] && "$REAL_GREP" -qF 'cause: PRECLASSIFY-REFUSED — preclassify.sh exited 2 without classifying' "$B360/$2.err"; then echo PRECLASSIFY-REFUSED
        elif [ "$a" = 0 ] && "$REAL_GREP" -qF 'present, current, and complete' "$B360/$2.out"; then echo VERIFIED
        else echo "OTHER(rc=${a:-none})"; fi ;;
  esac
}
B360_EXPECT='O1 eo SAMPLE REFUSED-STAGING REFUSED-RC1
O2 eo TOKENS-ALL REFUSED-STAGING REFUSED-PROJECTION
O3 ek SAMPLE REFUSED-NOLEAK LEAKED
V1 ev PRECLASSIFY-REFUSED UNDECIDED-STAGING VERIFIED'
b360_col() { awk -v a="$1" -v c="$2" '$1==a {print $c}' <<<"$B360_EXPECT"; }
b360_cells() { awk -v k="$1" '$2==k {print $1}' <<<"$B360_EXPECT"; }

# --- the mutants: each restores ONE site's base text ---
ER=emit-report.sh
B360_O1_B='              END { printf "%d\n%s", c, s }'"'"' <<<"$d")"; samp_rc=$?'
B360_O1_NEW='            samp="$(awk -v m="$marker" '"'"'
              substr($0, 1, 2) == m " " { x = substr($0, 3); if (x ~ /[^[:space:]]/) { c++; s = s x "\n" } }
'"$B360_O1_B"
B360_O2_B='          [ "$rt_rc" -eq 0 ] && { rt="$(awk -F'"'"'\t'"'"' '"'"'{print $3}'"'"' <<<"$rt")" || rt_rc="projection-$?"; }'
B360_O3_T='          if ! er_stage orient.theirs "$t" 2>/dev/null; then'
B360_O3_B='          if [ -z "$_er_tmp" ] || ! printf '"'"'%s\n'"'"' "$t" > "$_er_tmp/orient.theirs" 2>/dev/null; then'
B360_V1_B="if grep -Eq '^DETECTOR-REFUSED  preclassify\\.sh (exited|returned) ' <<<\"\$want\"; then"
B360_V1_NEW="$B360_V1_B
  echo \"FAIL: preclassify.sh did not classify on this run, so the mechanical region cannot be verified — its buckets, worklist and deletions are unknown, not empty.\" >&2
  _pc_cause=\"\$(grep -m1 -E '^DETECTOR-REFUSED  preclassify\\.sh (exited|returned) ' <<<\"\$want\")\"
  _pc_cause=\"\$(sed -E 's/^DETECTOR-REFUSED  //; s/, so this section.*//' <<<\"\$_pc_cause\")\"
  echo \"  cause: PRECLASSIFY-REFUSED — \${_pc_cause}. Run reconcile/preclassify.sh <dist> <base> <theirs> <consumer> directly, fix what it reports, then re-render and re-approve.\" >&2
  exit 1
fi"
_mo1="$(START='            samp=""; samp_rc=0' END='            fi' NFI=1 NEW="$B360_O1_NEW" \
        mut M-B360-O1 "$ER" "$BLOCK" "$B360_O1_B" 'orient.diff' \
          '            samp=""; samp_rc=0' '            er_stage orient.diff "$d" 2>/dev/null || samp_rc="staging-$?"')" || mutreport M-B360-O1
_mo2="$(START='          if [ "$rt_rc" -eq 0 ]; then' END='          fi' NFI=1 NEW="$B360_O2_B" \
        mut M-B360-O2 "$ER" "$BLOCK" "$B360_O2_B" 'orient.rt' \
          '          if [ "$rt_rc" -eq 0 ]; then' '            if er_stage orient.rt "$rt" 2>/dev/null; then')" || mutreport M-B360-O2
_mo3="$(DROP1="$N0" DROP2="$N0" OLD="$B360_O3_T" NEW="$B360_O3_B" \
        mut M-B360-O3 "$ER" "$SWAP" "$B360_O3_B" 'er_stage orient.theirs' "$B360_O3_T")" || mutreport M-B360-O3
_mv1="$(START='if er_stage verify.render "$want" 2>/dev/null; then' END='fi' NFI=3 NEW="$B360_V1_NEW" \
        mut M-B360-V1 "$ER" "$BLOCK" "$B360_V1_B" 'verify.render' \
          'if er_stage verify.render "$want" 2>/dev/null; then' 'if [ "$_pc_rc" = 0 ]; then')" || mutreport M-B360-V1

# All renders are independent: run them in waves of six, each a background job writing its own files.
B360_JOBS="tip:eo:ctl tip:eo:forced tip:ek:ctl tip:ek:forced tip:ev:ctl tip:ev:forced tip:evp:forced
base:eo:ctl base:eo:forced base:ek:ctl base:ek:forced base:ev:forced base:evp:ctl"
[ -n "$_mo1" ] && B360_JOBS="$B360_JOBS M-B360-O1:eo:forced"
[ -n "$_mo2" ] && B360_JOBS="$B360_JOBS M-B360-O2:eo:forced"
[ -n "$_mo3" ] && B360_JOBS="$B360_JOBS M-B360-O3:ek:forced"
[ -n "$_mv1" ] && B360_JOBS="$B360_JOBS M-B360-V1:ev:forced"
_i=0
for _j in $B360_JOBS; do
  _p="${_j%%:*}"; _r="${_j#*:}"; _w="${_r%%:*}"; _m="${_r#*:}"
  case "$_p" in tip) _R="$RECON" ;; base) _R="$ER_BASE" ;; *) _R="$MUTROOT/$_p" ;; esac
  b360_run "$_R" "$_w" "$_m" "$_p-$_w-$_m" &
  _i=$((_i + 1)); [ $((_i % 6)) -eq 0 ] && wait
done
wait
_unfired=""
for _j in $B360_JOBS; do
  _t="$(printf '%s' "$_j" | tr ':' '-')"
  [ "$(fired "$B360/$_t.stub")" -gt 0 ] && [ -s "$B360/$_t.rc" ] || _unfired="$_unfired $_t"
  # Every render reaches the predicate section, so the exclusion must have fired in every run.
  [ -s "$B360/$_t.stub/PD_FIRED" ] || _unfired="$_unfired $_t(predicate-exclusion)"
done
[ -s "$B360_PC_STUB/PD_FIRED" ] || _unfired="$_unfired ev-region(predicate-exclusion)"
if [ -n "$_unfired" ]; then
  echo "FIXTURE BROKEN: BL-360 runs whose stub never fired or that wrote no exit status:$_unfired -- their shapes say nothing about the site" >&2; exit 2
fi

# --- calibration (c): on the tip, forced and unforced differ ONLY in the cells' own lines ---
_cx=""
for _w in eo ek; do
  diff "$B360/tip-$_w-ctl.out" "$B360/tip-$_w-forced.out" > "$B360/cal-$_w.diff"
  _rm="$(awk '/^< / && !/^<     ONLY IN (THEIRS|OURS) / && !/^<     RETIRED-CONTRACT-TOKEN( — |: none$)/ && !/^<       / { n++ } END { print n + 0 }' "$B360/cal-$_w.diff")"
  case "$_w" in
    eo) _ad="$(awk '/^> / && !/^> DETECTOR-REFUSED  orientation sample exited staging-[0-9]+ for core\/scripts\/a\.sh \((THEIRS|OURS)\)/ && !/^> DETECTOR-REFUSED  retired-tokens\.sh exited staging-[0-9]+ for core\/scripts\/b\.sh / { n++ } END { print n + 0 }' "$B360/cal-$_w.diff")"
        _an="$(b360_c '^> DETECTOR-REFUSED' "$B360/cal-$_w.diff")"; _aw=3 ;;
    # ek's THEIRS blob is ALSO what retired-tokens.sh stages for the same file, and that converted
    # sibling refuses on its own write (exit 2, its own named line): the same input, not a second
    # fault. Exactly that line, for c.sh, is accepted beside the cell's own; anything else is not.
    ek) _ad="$(awk '/^> / && !/^> DETECTOR-REFUSED  orientation diff exited staging-failed for core\/scripts\/c\.sh/ && !/^> DETECTOR-REFUSED  retired-tokens\.sh exited 2 for core\/scripts\/c\.sh / { n++ } END { print n + 0 }' "$B360/cal-$_w.diff")"
        _an="$(b360_c '^> DETECTOR-REFUSED' "$B360/cal-$_w.diff")"; _aw=2 ;;
  esac
  [ "$_rm" -eq 0 ] && [ "$_ad" -eq 0 ] && [ "$_an" -eq "$_aw" ] || _cx="$_cx $_w(removed-other=$_rm,added-other=$_ad,refusals=$_an/$_aw)"
done
cmp -s "$B360/tip-evp-forced.out" "$B360/ev-region" || _cx="$_cx ev(the render under ${B360_LIM_V} block(s) differs from the unlimited one)"
if [ -n "$_cx" ]; then
  echo "FIXTURE BROKEN: BL-360 calibration (c) -- a forced render moved lines outside its cells' own sites, so another write failed:$_cx" >&2; exit 2
fi
ok "BL-360 calibration (c): each forced tip render differs from its control only in its cells' own lines, and the ev render under the limit is byte-identical to the unlimited one"

# --- cells, then the base engine, then the healthy-path differential, then the mutants ---
for _A in O1 O2 O3 V1; do
  _k="$(b360_col "$_A" 2)"
  _c="$(b360_shape "$_A" "tip-$_k-ctl")"; _f="$(b360_shape "$_A" "tip-$_k-forced")"; _b="$(b360_shape "$_A" "base-$_k-forced")"
  [ "$_c" = "$(b360_col "$_A" 3)" ] && ok "BL-360 $_A control (no limit): $_c" \
    || bad "BL-360 $_A control (no limit): $_c, expected $(b360_col "$_A" 3) -- the world does not express the case"
  [ "$_f" = "$(b360_col "$_A" 4)" ] && ok "BL-360 $_A forced (${_k}): $_f -- the tip shape" \
    || bad "BL-360 $_A forced (${_k}): $_f, expected $(b360_col "$_A" 4) -- a staging failure read as $_f"
  [ "$_b" = "$(b360_col "$_A" 5)" ] && ok "BL-360 $_A on the ${ER_BASE_SHA%"${ER_BASE_SHA#????????}"} engine: $_b -- the cell fails the pre-fix engine" \
    || bad "BL-360 $_A on the ${ER_BASE_SHA%"${ER_BASE_SHA#????????}"} engine: $_b, expected $(b360_col "$_A" 5) -- the cell cannot tell the pre-fix engine from the fix"
done
_bh="$(b360_c 'cannot create temp file for here' "$B360/base-eo-forced.err")"
[ "$_bh" -ge 2 ] && ok "BL-360 base eo run printed bash's here-string failure ${_bh}x -- O1/O2's base shapes are the lost here-string, not another fault" \
  || bad "BL-360 base eo run printed bash's here-string failure ${_bh}x, want >= 2"
_hd=""
cmp -s "$B360/tip-eo-ctl.out" "$B360/base-eo-ctl.out" || _hd="$_hd eo"
cmp -s "$B360/tip-ek-ctl.out" "$B360/base-ek-ctl.out" || _hd="$_hd ek"
cmp -s "$B360/base-evp-ctl.out" "$B360/ev-region" || _hd="$_hd ev"
cmp -s "$RECON/emit-report.sh" "$ER_BASE/emit-report.sh" && _hd="$_hd (the two engines are identical)"
[ -z "$_hd" ] && ok "BL-360 healthy path: tip and ${ER_BASE_SHA%"${ER_BASE_SHA#????????}"} render the eo, ek and ev worlds byte-identically with no limit (an approved region does not move)" \
  || bad "BL-360 healthy path: tip and base renders differ with no limit:$_hd"
for _mm in M-B360-O1:O1 M-B360-O2:O2 M-B360-O3:O3 M-B360-V1:V1; do
  _m="${_mm%%:*}"; _own="${_mm#*:}"; _k="$(b360_col "$_own" 2)"
  [ -s "$B360/$_m-$_k-forced.rc" ] || continue
  _got="" _oth=""
  for _A in $(b360_cells "$_k"); do
    _s="$(b360_shape "$_A" "$_m-$_k-forced")"
    if [ "$_A" = "$_own" ]; then _got="$_s"
    elif [ "$_s" != "$(b360_col "$_A" 4)" ]; then _oth="$_oth $_A=$_s"; fi
  done
  if [ "$_got" != "$(b360_col "$_own" 5)" ]; then bad "MUTANT SURVIVED [$_m]: $_own reads $_got, expected the base shape $(b360_col "$_own" 5)"
  elif [ -n "$_oth" ]; then bad "MUTANT ENTANGLED [$_m]: $_own reads $_got but other $_k cell(s) moved:$_oth"
  else ok "MUTANT KILLED [$_m]: $_own reads $_got (the base shape), every other $_k cell stays at its tip shape"; fi
done

# --- SPELL: emit-report.sh carries no non-comment here-string (secondary to the cells above) ---
_sp="$(mktemp -d "$WORK/erspell.XXXXXX")" || { echo "FIXTURE ERROR: mktemp erspell" >&2; exit 2; }
cp "$RECON/emit-report.sh" "$_sp/offender.sh" && cp "$RECON/emit-report.sh" "$_sp/nearmiss.sh" \
  || { echo "FIXTURE ERROR: erspell probe copies" >&2; exit 2; }
printf '  x="$(awk %s <<<"$y")"\n' "'{print}'" >> "$_sp/offender.sh"
printf '    # a comment naming the here-string operator, <<<"$y", is not a site\n' >> "$_sp/nearmiss.sh"
_so="$(spell_count "$_sp/offender.sh")"; _sn="$(spell_count "$_sp/nearmiss.sh")"; _st="$(spell_count "$RECON/emit-report.sh")"
_sb="$(spell_count "$ER_BASE/emit-report.sh")"
if [ "$_so" -ne $(( _st + 1 )) ] || [ "$_sn" -ne "$_st" ] || [ "$_sb" -eq 0 ]; then
  bad "SPELL emit-report probe: offender $_so (want $(( _st + 1 ))), comment near-miss $_sn (want $_st), the base engine $_sb (want > 0) -- the count cannot discriminate"
elif [ "$_st" -eq 0 ]; then
  ok "SPELL: emit-report.sh carries 0 non-comment here-strings (probe: offender +1, comment near-miss +0, the base engine $_sb)"
else
  bad "SPELL: emit-report.sh carries $_st non-comment here-string(s) (BL-360)"
fi
fi
ld_heredoc_gate

echo
PSB_DONE=1
if [ "$fails" -eq 0 ]; then
  echo "$NAME: PASS ($asserts assertions)"
  exit 0
fi
echo "$NAME: FAIL ($fails of $asserts assertion(s))" >&2
exit 1
