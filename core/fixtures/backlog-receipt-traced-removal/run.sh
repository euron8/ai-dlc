#!/usr/bin/env bash
# backlog-receipt-traced-removal -- BL-899 in scripts/validate-backlog-receipts.sh: M1 (driver-absent in R7's
# cannot-measure set, lead ruling L3 (a)-(d)), R13 (traced removal over the NAMED closure, read set by atime after a
# forced epoch, the in-arm instrument probe, the must-miss and must-hit controls, the 32-removal ceiling) and M3 (the
# per-receipt green record), and the mutants behind them. Distribution-only: its .dist-only says why.
#
# HOW IT DRIVES THE VALIDATOR (lead ruling (a), batch 256). Each distinct state is ONE FXCELL-tagged `cli` start of a
# copy of the validator, run from the copy's tree in its cheap mode `--r13-drive <m1|probe|corpus|score>` (the
# validator's header beside DEFAULT_MAX_R13), and every worker that start launches (--score-one, --closed-one,
# --r13-one) is covered by the ONE self-nested row of cells.decl. The in-process passes that remain (fx_inproc) are
# the probe-world build (r13_world), r13_untraced called as a function, and vbr_sec_setup alone for the --base
# states; none of them reaches score_ledger, score_closed or r13_removals, so none starts a worker. ONE end-to-end
# CLI run (cell cli-wire) proves the corpus wiring and the --traced-removal flag.
# THE WORLDS ARE BUILT ONCE: the R13 probe world by r13_world into $PW (every probe start passes --probe-world), the
# one-receipt worlds g/u/o/x/e as templates copied per drive (a drive that commits or writes a record gets its own
# copy and its own record store, so no mutant replays a green the unmutated copy wrote). A mutant re-runs ONLY its
# killing seed: `--probe-seeds <BL-id>` restricts the M1 and R13 self-probes to it, and `--probe-seeds -` keeps a
# corpus-level mutant's self-probe from running seeds it does not need.
#
# A SANDBOX THAT DENIES `touch -a`, OR A FILESYSTEM WHERE ATIME DOES NOT MOVE, is FIXTURE BROKEN (exit 2), never a
# skip: the control captures carry `R13-INSTRUMENT-REFUSED` and every control below reads that first.
#
# CONTROLS: the M1 drive (B_m1), the corpus write on world g (B_write; it fires vbr_probe_r13 over all 14 seeds, the
# base of every probe-mode mutant), replay, moved named file, moved judge byte, red, overflow, not-run, untraced
# (function-level), the two-sided ceiling (c-stale-high, c-committed), the within-ceiling record and its replay
# (c-within-write, c-within), a DRIVEN instrument refusal (c-instr-refused, through the validator's documented test
# seam BR_R13_PROBE_DIR with a pre-placed unreadable `read`; no command is shadowed), the three states of a given
# --base (m1-base3), the replayed population figures (c-pop-live, c-replay-pop), and the CLI. Each mutant is killed by
# the cell that names it, read off its own capture; its twin is a cell of the same capture, or, for a caller-wiring mutant, a separate start of the same mutated copy, that stays GREEN.
# The trustctime setting's effect across a second boundary is inferred from git's documented ctime granularity, not
# measured; the function-level seed proves only that the setting is applied.
#
# MUTANT-MATRIX m-r13-skipped decides=c-write twins=c-instr
# MUTANT-MATRIX m-removal-not-applied decides=p1 twins=c-instr
# MUTANT-MATRIX m-cm-widened decides=p4 twins=c-instr
# MUTANT-MATRIX m-l3b-widened decides=m1-c twins=- why=a restricted M1 drive runs only its own seed, so no other arm reads the capture
# MUTANT-MATRIX m-any-bash-line decides=m1-nearmiss twins=- why=a restricted M1 drive runs only its own seed, so no other arm reads the capture
# MUTANT-MATRIX m-no-exist-conjunct decides=m1-present twins=- why=a restricted M1 drive runs only its own seed, so no other arm reads the capture
# MUTANT-MATRIX m-no-options decides=m1-option twins=- why=a restricted M1 drive runs only its own seed, so no other arm reads the capture
# MUTANT-MATRIX m-no-long-options decides=m1-option-long twins=- why=a restricted M1 drive runs only its own seed, so no other arm reads the capture
# MUTANT-MATRIX m-no-optarg decides=m1-option-arg twins=- why=a restricted M1 drive runs only its own seed, so no other arm reads the capture
# MUTANT-MATRIX m-first-segment decides=m1-chain twins=- why=a restricted M1 drive runs only its own seed, so no other arm reads the capture
# MUTANT-MATRIX m-no-rc1-branch decides=m1-option-e twins=- why=a restricted M1 drive runs only its own seed, so no other arm reads the capture
# MUTANT-MATRIX m-red-writes decides=red-norecord twins=red-fail
# MUTANT-MATRIX m-replay-drops-rows decides=c-within twins=c-within-write
# MUTANT-MATRIX m-replay-drops-counts decides=c-replay-pop twins=c-pop-live
# MUTANT-MATRIX m-base-refusal-pass decides=m1-base3 twins=- why=the three base3 captures are read by m1-base3 alone
# MUTANT-MATRIX m-key-no-blobs decides=c-moved-named twins=c-write
# MUTANT-MATRIX m-no-enum-count decides=c-enumline twins=c-write
# MUTANT-MATRIX m-key-no-judge decides=c-moved-judge twins=c-write
# MUTANT-MATRIX m-depth1 decides=p2 twins=c-instr
# MUTANT-MATRIX m-named-all-reads decides=p6-enum twins=c-instr
# MUTANT-MATRIX m-basename decides=p2-basename twins=c-instr
# MUTANT-MATRIX m-no-epoch decides=must-miss twins=c-instr
# MUTANT-MATRIX m-no-must-hit decides=failure-probe twins=c-instr
# MUTANT-MATRIX m-atime-never decides=must-hit twins=c-instr
# MUTANT-MATRIX m-instrument-skipped decides=c-instr twins=c-write
# MUTANT-MATRIX m-comments-named decides=p4-comment twins=c-instr
# MUTANT-MATRIX m-expand-any-named decides=p14-string twins=c-instr
# MUTANT-MATRIX m-no-overflow decides=p8-overflow twins=c-instr
# MUTANT-MATRIX m-trustctime-dropped decides=trustctime twins=c-instr
# MUTANT-MATRIX m-no-settle decides=p9-gitstatus twins=c-instr
# MUTANT-MATRIX m-no-stale-high decides=c-stale-high twins=c-instr
# MUTANT-MATRIX m-closure-after-reset decides=p10-unread twins=c-instr
# MUTANT-MATRIX m-no-named-read-rule decides=no-named-read twins=c-instr
# MUTANT-MATRIX m-no-untraced-check decides=c-untraced twins=- why=a function-level cell, one value per capture
# MUTANT-MATRIX m-l3-base-not-exported decides=c-m1-e2e twins=m1
# MUTANT-MATRIX m-cm-m1-call-dropped decides=c-m1-e2e twins=m1
# MUTANT-MATRIX m-excluded-call-dropped decides=c-m1-e2e twins=m1
# MUTANT-MATRIX m-empty-stale-dropped decides=c-empty-stale twins=c-instr
# MUTANT-MATRIX m-nothing-judged-dropped decides=c-nothing-judged twins=c-instr
# MUTANT-MATRIX m-restricted-trigger-drive-only decides=c-restricted-seeds twins=- why=its one efficiency-only start carries no other arm
# MUTANT-MATRIX m-restricted-exit-dropped decides=c-restricted twins=- why=its one restricted start carries no other arm
# MUTANT-MATRIX-DYNAMIC verdicts why=probe_mut, m1_mut, corpus_mut and keymut pass their mutant name to mutant_killed; every caller names a literal mutant that carries its own row in this block
# MUTANT-MATRIX-REMEASURE bash core/fixtures/backlog-receipt-traced-removal/run.sh --matrix
#
# Usage: run.sh [--matrix]
# Exit:  0 = every control holds and every mutant is killed, 1 = one regressed, 2 = fixture broken.
set -u
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
FX="$(cd "$(dirname "$0")" && pwd)"
NAME="backlog-receipt-traced-removal"
broken() { echo "$NAME: FIXTURE BROKEN -- $1" >&2; exit 2; }
[ -f "$FX/../lib/preamble.sh" ] || broken "lib/preamble.sh is absent beside $FX"
# shellcheck source=/dev/null
. "$FX/../lib/preamble.sh"
# The repository root, by walking up for the subject, never by counting hops.
R="$FX"
while [ "$R" != "/" ] && [ ! -f "$R/scripts/validate-backlog-receipts.sh" ]; do R="$(dirname "$R")"; done
[ -f "$R/scripts/validate-backlog-receipts.sh" ] || broken "no scripts/validate-backlog-receipts.sh above $FX"
for _f in scripts/backlog-receipt-lib.sh scripts/backlog-reverify.sh core/skills/ai-dlc-update/reconcile/lib.sh \
          core/skills/ai-dlc-update/reconcile/ledger-reverify.sh; do
  [ -f "$R/$_f" ] || broken "$_f is absent under $R"
done
for _t in git awk sed find touch xargs sort cmp mktemp; do command -v "$_t" >/dev/null 2>&1 || broken "the declared tool $_t is not on PATH"; done
MATRIX=0; [ "${1:-}" = "--matrix" ] && MATRIX=1
# Every `!` (REQUIRED) input of inputs.decl, said consumed once it is resolved: hermetic-run refuses a run that never
# names one.
echo "HERMETIC-CONSUMED scripts/validate-backlog-receipts.sh"

FAILS=0
ok()  { echo "ok    $*"; }
bad() { echo "FAIL  $*"; FAILS=$(( FAILS + 1 )); }
# shellcheck source=/dev/null
. "$FX/../lib/mutant.sh" || broken "cannot source lib/mutant.sh"

TMP="$(mktemp -d)" || broken "mktemp -d"
trap 'rm -rf "$TMP"' EXIT
export GIT_AUTHOR_NAME=fx GIT_AUTHOR_EMAIL=fx@local GIT_COMMITTER_NAME=fx GIT_COMMITTER_EMAIL=fx@local
unset BR_PROBE_RECORD BR_RECEIPTS_RUNNING BR_R13_RECORD_DIR BR_R13_PROBE_DIR

# --- the trees -----------------------------------------------------------------------------
# mkdist <dir> <validator> -- the files the validator resolves beside itself.
mkdist() {
  mkdir -p "$1/scripts" "$1/core/skills/ai-dlc-update/reconcile" || return 1
  echo "0.0.0" > "$1/VERSION"
  cp "$2" "$1/scripts/validate-backlog-receipts.sh" && cp "$R/scripts/backlog-receipt-lib.sh" "$1/scripts/" \
    && cp "$R/scripts/backlog-reverify.sh" "$1/scripts/" \
    && cp "$R/core/skills/ai-dlc-update/reconcile/lib.sh" "$1/core/skills/ai-dlc-update/reconcile/" \
    && cp "$R/core/skills/ai-dlc-update/reconcile/ledger-reverify.sh" "$1/core/skills/ai-dlc-update/reconcile/"
}
# mkworld <dir> g|u|o|x|e -- a one-receipt repository: g reads a guarded file, u an unguarded one, o 33 named files,
# x has its driver deleted on HEAD (the seed commit recorded in .git/fx-base), e reads one enumerated and names one
# unread file.
mkworld() {
  local d="$1" l i
  mkdir -p "$d/docs" "$d/w" || return 1
  case "$2" in
    g) printf 'grep -q GUARDTOKEN w/data.txt || exit 9\n' > "$d/w/drv.sh"; printf 'GUARDTOKEN\n' > "$d/w/data.txt" ;;
    u) printf 'grep -q x w/data.txt || exit 1\n' > "$d/w/drv.sh"; printf 'x\n' > "$d/w/data.txt" ;;
    e) printf '%s\n' 'F=w' 'cat "$F/hidden.txt" > /dev/null' 'if false; then cat w/nev.txt; fi' \
         'grep -q GUARDTOKEN w/data.txt || exit 9' > "$d/w/drv.sh"
       printf 'GUARDTOKEN\n' > "$d/w/data.txt"; printf 'h\n' > "$d/w/hidden.txt"; printf 'n\n' > "$d/w/nev.txt" ;;
    o) l="cat"; i=1
       while [ "$i" -le 33 ]; do printf 'f\n' > "$d/w/f$i.txt"; l="$l w/f$i.txt"; i=$(( i + 1 )); done
       printf '%s > /dev/null\n' "$l" > "$d/w/drv.sh" ;;
    x) printf 'exit 0\n' > "$d/w/drv.sh" ;;
    m) printf 'grep -q GUARDTOKEN w/gd.txt || exit 9\n' > "$d/w/g.sh"; printf 'GUARDTOKEN\n' > "$d/w/gd.txt"
       printf 'grep -q x w/ud.txt || exit 1\n' > "$d/w/u.sh"; printf 'x\n' > "$d/w/ud.txt" ;;
  esac
  if [ "$2" = n ]; then
    : > "$d/w/keep.txt"
    printf '# Probe backlog\n\n## BL-1401 — manual only\n\nverify: manual\n' > "$d/docs/backlog.md"
  elif [ "$2" = m ]; then
    printf '# Probe backlog\n\n## BL-1401 — never built\n\nverify: sh bash w/never.sh\n\n## BL-1402 — guarded\n\nverify: sh bash w/g.sh\n\n## BL-1403 — unguarded\n\nverify: sh bash w/u.sh\n' > "$d/docs/backlog.md"
  else
    printf '# Probe backlog\n\n## BL-1401 — world %s\n\nverify: sh bash w/drv.sh\n' "$2" > "$d/docs/backlog.md"
  fi
  ( cd "$d" && git init -q . && git add -A && git -c commit.gpgsign=false commit -q -m seed ) >/dev/null 2>&1
  [ -d "$d/.git" ] || return 1
  if [ "$2" = x ]; then
    git -C "$d" rev-parse HEAD > "$d/.git/fx-base" 2>/dev/null \
      && git -C "$d" rm -q w/drv.sh >/dev/null 2>&1 && git -C "$d" -c commit.gpgsign=false commit -q -m gone >/dev/null 2>&1 || return 1
  fi
  return 0
}
mkdist "$TMP/dist" "$R/scripts/validate-backlog-receipts.sh" || broken "the validator copy did not build"
D="$TMP/dist/scripts/validate-backlog-receipts.sh"
for _k in g u o x e m n; do mkworld "$TMP/tpl-$_k" "$_k" || broken "world $_k did not build"; done
# world / store are called inside $( ), so a counter would be lost to the subshell: each takes a fresh mktemp dir.
world() { local d; d="$(mktemp -d "$TMP/w.XXXXXX")" && cp -R "$TMP/tpl-$1/." "$d/" || broken "world $1 did not copy"; printf '%s' "$d"; }
store() { local d; d="$(mktemp -d "$TMP/s.XXXXXX")" || broken "a record store did not create"; printf '%s' "$d"; }
# wcheck <path> -- a world captured through $( ) is EMPTY when its copy failed, and a `cd ""` stays in the caller's
# tree; every world a command later commits in, or runs the CLI in, is checked first.
wcheck() { case "$1" in "$TMP"/*) [ -d "$1/.git" ] || broken "the world $1 has no .git" ;; *) broken "a world did not copy" ;; esac; }

# THE R13 PROBE WORLD, BUILT ONCE (in process: r13_world writes and commits files; it starts no worker).
PW="$TMP/pw/world"; mkdir -p "$TMP/pw" || broken "the probe-world dir did not create"
( cd "$TMP/dist" || exit 2
  fx_inproc scripts/validate-backlog-receipts.sh
  # shellcheck source=/dev/null
  . scripts/validate-backlog-receipts.sh || exit 2
  r13_world "$PW" ) > /dev/null 2>&1 || broken "the R13 probe world did not build"
[ -f "$PW.base" ] && [ -f "$PW.ledger" ] && [ -d "$PW/.git" ] || broken "the R13 probe world is incomplete"
WL="$(world g)"; wcheck "$WL"; LEDGER0="$WL/docs/backlog.md"   # the ledger a probe-mode start is given (setup needs one)

# cli <cell> <copy> <out> <store> <env words or -> <args...> -- ONE FXCELL-tagged start of a validator copy, from its
# tree, `--max-unguarded 0` first (a seeded world's own count is 0 unless the cell's flag after it says otherwise).
CELLS_USED="$TMP/cells.used"; : > "$CELLS_USED"
cli() {
  local id="$1" c="$2" o="$3" s="$4" e="$5"; shift 5
  [ "$e" = - ] && e=""
  # shellcheck disable=SC2086
  ( cd "$(dirname "$(dirname "$c")")" && env FXCELL="$id" BR_R13_RECORD_DIR="$s" $e bash scripts/validate-backlog-receipts.sh --max-unguarded 0 "$@" ) > "$o" 2>&1
  local raw=$? v
  printf '%s\n' "$id" >> "$CELLS_USED"
  echo "$raw" > "$o.raw"
  # EVERY start here is RESTRICTED (--r13-drive), so it must exit 3 with its verdict on `RESTRICTED: verdict-rc=`, or
  # refuse with 2; <out>.rc is the VERDICT the cells read. Any other exit is a failure of the restricted contract.
  v="$(sed -n 's/^RESTRICTED: verdict-rc=\([0-9][0-9]*\) -- this run narrowed the self-probes and is never a gate pass$/\1/p' "$o" | tail -1)"
  case "$raw" in
    3) echo "${v:-none}" > "$o.rc" ;;
    2) echo 2 > "$o.rc" ;;
    *) echo "$raw" > "$o.rc"
       case "$id" in m-restricted-exit-dropped|m-restricted-trigger-drive-only) ;; *) false ;; esac || bad "restricted -- cell $id exited $raw, not the restricted 3 (or a refusal's 2)" ;;
  esac
}
has() { grep -qF -- "$2" "$1"; }
rcof() { cat "$1.rc" 2>/dev/null; }
klist() { sed -n 's/^R13-RECORD: WRITTEN BL-1401 (K=\([0-9a-f]*\))$/\1/p' "$1"; }
instr_refused() { has "$1" "R13-INSTRUMENT-REFUSED" && broken "atime is not a working read instrument here: $(grep -F R13-INSTRUMENT-REFUSED "$1" | head -1)"; return 0; }

# --- the cells: each reads one capture and returns 0 when GREEN ----------------------------
seed_ok() { ! has "$1" "SELF-PROBE FAILED -- $2: seed $3:"; }
cell_c_write() { has "$1" "R13-POPULATION: 1 open sh receipt(s), 1 traced, 2 named removals (0 replayed), 0 named-unread (0 replayed), " && has "$1" "removals: 1 exit 9, 2 in the cannot-measure set, 0 UNGUARDED-READ" && [ -n "$(klist "$1")" ] && has "$1" "R13-RC 0 R13 fired both directions"; }
# c-write without its "self-probe fired over every seed" clause: what a corpus-level mutant's start (seeds `-`) shows.
cell_c_write_nf() { has "$1" "R13-POPULATION: 1 open sh receipt(s), 1 traced, 2 named removals (0 replayed), 0 named-unread (0 replayed), " && has "$1" "removals: 1 exit 9, 2 in the cannot-measure set, 0 UNGUARDED-READ" && [ -n "$(klist "$1")" ] && has "$1" "R13-RC 0 "; }
cell_c_enumline() { has "$1" ", 0 enumerated excluded (0 replayed), "; }
cell_c_instr() { has "$1" "R13-INSTRUMENT: atime moved on a read and on a second read after a second reset"; }
cell_c_replay() { has "$1" ", 1 replayed, " && [ -z "$(klist "$1")" ] && has "$1" "R13-RC 0 R13 self-probe not fired"; }
cell_c_moved() { [ -n "$(klist "$1")" ] && [ "$(klist "$1")" != "$2" ]; }
cell_red_fail() { has "$1" "FAIL: R13" && has "$1" "R13-RC 1 " && has "$1" "1 UNGUARDED-READ"; }
cell_red_norecord() { [ -z "$(ls -A "$2")" ] && [ -z "$(klist "$1")" ]; }
cell_c_overflow() { [ "$(rcof "$1")" = 2 ] && has "$1" "R13-NAMED-OVERFLOW BL-1401 34"; }
cell_c_notrun() { has "$1" "R13-POPULATION: NOT RUN"; }
cell_c_untraced() { [ "$(cat "$1" 2>/dev/null)" = "1 0 0" ]; }
cell_c_stale_high() { has "$1" "R13-RC 1 " && has "$1" "BELOW the ceiling of 2" && has "$1" "lower DEFAULT_MAX_R13 in scripts/validate-backlog-receipts.sh to 1"; }
UROW="$(printf 'UNGUARDED-READ\tBL-1401\tw/data.txt\texit=1')"
cell_c_within_write() { [ -n "$(klist "$1")" ] && has "$1" "$UROW" && has "$1" "R13-RC 0 "; }
cell_c_within_replay() { has "$2" ", 1 replayed, " && has "$2" "$UROW" && has "$2" "R13-RC 0 " \
  && has "$3" ", 1 replayed, " && has "$3" "$UROW" && has "$3" "FAIL: R13" && has "$3" "R13-RC 1 "; }
# BR_R13_PROBE_DIR makes the run RESTRICTED too; an instrument refusal is a refusal, so it leaves through the
# restricted trap as 2 (never 0 or 3) with `RESTRICTED: verdict-rc=2`.
cell_c_instr_refused() { [ "$(cat "$1.raw" 2>/dev/null)" = 2 ] && has "$1" "R13-INSTRUMENT-REFUSED read-not-moved" \
  && has "$1" "RESTRICTED: verdict-rc=2 -- this run narrowed the self-probes and is never a gate pass"; }
cell_m1_base3() { [ "$(rcof "$1")" = 0 ] && has "$1" "SETUP-OK" && ! has "$1" "M1-BASE-UNRESOLVED" \
  && [ "$(rcof "$2")" = 2 ] && has "$2" "M1-BASE-UNRESOLVED:" && ! has "$2" "SETUP-OK" \
  && [ "$(rcof "$3")" = 0 ] && has "$3" "base-exit=127-cannot-measure=driver-absent/DRIVER-REMOVED"; }
cell_c_pop_live() { has "$1" ", 2 named removals (0 replayed), 1 named-unread (0 replayed), 1 enumerated excluded (0 replayed), " && [ -n "$(klist "$1")" ]; }
cell_c_replay_pop() { has "$2" ", 1 replayed, " && has "$2" ", 2 named removals (2 replayed), 1 named-unread (1 replayed), 1 enumerated excluded (1 replayed), "; }

# The in-process function and setup passes (no worker can start from them; see the header).
# untraced_fn <copy> <out> -- r13_untraced over: 0 traced of 1 scored (1 untraced), 1 of 1 (0), and 0 traced of 1
# receipt R2 refused before a checkout (0).
untraced_fn() {
  ( cd "$(dirname "$(dirname "$1")")" || exit 2
    fx_inproc scripts/validate-backlog-receipts.sh
    # shellcheck source=/dev/null
    . scripts/validate-backlog-receipts.sh || exit 2
    # Each in-process call is paired with its own fx_inproc (P2): the first by the line before the source above.
    printf '%s %s %s\n' "$(r13_untraced 0 "$(printf 'DRIVER\tBL-1\tbase-exit=0')" 1)" \
      "$(fx_inproc scripts/validate-backlog-receipts.sh; r13_untraced 1 "$(printf 'DRIVER\tBL-1\tbase-exit=0')" 1)" \
      "$(fx_inproc scripts/validate-backlog-receipts.sh; r13_untraced 0 "$(printf 'UNSCORABLE\tBL-1\tempty-sh-one-liner')" 1)" ) > "$2" 2>&1
}
# base_setup <copy> <out> <base> <ledger> -- vbr_sec_setup alone, with a GIVEN --base.
base_setup() {
  ( cd "$(dirname "$(dirname "$1")")" || exit 2
    fx_inproc scripts/validate-backlog-receipts.sh
    # shellcheck source=/dev/null
    . scripts/validate-backlog-receipts.sh || exit 2
    # Each in-process call is paired with its own fx_inproc (P2): vbr_sec_env by the line before the source above.
    vbr_sec_env; fx_inproc scripts/validate-backlog-receipts.sh; vbr_sec_args --base "$3" "$4"
    fx_inproc scripts/validate-backlog-receipts.sh; vbr_sec_setup; echo "SETUP-OK" ) > "$2" 2>&1
  echo "$?" > "$2.rc"
}

# --- controls ------------------------------------------------------------------------------
B_m1=0; B_write=0; B_enum=0; B_instr=0; B_moved=0; B_judge=0; B_redn=0; B_untr=0; B_stale=0; B_within=0; B_base3=0; B_pop=0
C="$TMP/cap"; mkdir -p "$C"
cli m1 "$D" "$C/m1" "$(store)" - --r13-drive m1 "$LEDGER0"
if [ "$(rcof "$C/m1")" = 0 ] && has "$C/m1" "M1-OK M1 fired both directions"; then B_m1=1; ok "m1 -- M1 fired both directions over its seeds and L3 (d)"
else bad "m1 -- vbr_probe_m1 did not pass (rc $(rcof "$C/m1")): $(grep -F 'SELF-PROBE FAILED' "$C/m1" | head -1)"; fi
# c-restricted: a restricted start whose verdict is GREEN exits 3, never 0, and says its verdict.
cell_c_restricted() { [ "$(cat "$1.raw" 2>/dev/null)" = 3 ] && has "$1" "RESTRICTED: verdict-rc=0 -- this run narrowed the self-probes and is never a gate pass"; }
B_restr=0
if cell_c_restricted "$C/m1"; then B_restr=1; ok "c-restricted -- a restricted start with a green verdict exited 3, not 0, and printed verdict-rc=0"
else bad "c-restricted -- raw exit $(cat "$C/m1.raw" 2>/dev/null): $(grep -F 'RESTRICTED:' "$C/m1" | tr '\n' ' ')"; fi

# c-m1-e2e: M1 THROUGH REAL WORKERS (lead condition; vbr_probe_m1 is start-free and cannot see a caller defect). World
# m, one tagged start: BL-1401 `bash w/never.sh` (absent at HEAD and at --base) reads EXCLUDED-DRIVER-ABSENT-AT-BASE;
# BL-1402's guarded driver and BL-1403's driver, removed, read driver-absent (R13-PASS) and BL-1402's guarded file
# exits 9; BL-1403's unguarded file is UNGUARDED-READ (within a ceiling of 1). A --score-one worker classifies the
# baselines and --r13-one workers the removals.
cell_c_m1_e2e() { has "$1" "R13-POPULATION: 3 open sh receipt(s), 3 traced, " && has "$1" ", 1 EXCLUDED-DRIVER-ABSENT-AT-BASE, 0 baseline-cm, " \
  && has "$1" "removals: 1 exit 9, 3 in the cannot-measure set, 1 UNGUARDED-READ" \
  && has "$1" "$(printf 'UNGUARDED-READ\tBL-1403\tw/ud.txt\texit=1')" && [ "$(rcof "$1")" = 0 ]; }
m1e2e_run() { # m1e2e_run <copy> <out> <cell>
  local w; w="$(world m)"; wcheck "$w"
  cli "$3" "$1" "$2" "$(store)" - --r13-drive corpus --traced-removal --probe-seeds - --max-unguarded 1 \
    --base "$(git -C "$w" rev-parse HEAD)" "$w/docs/backlog.md"
}
B_m1e2e=0
m1e2e_run "$D" "$C/m1e2e" c-m1-e2e
if cell_c_m1_e2e "$C/m1e2e"; then B_m1e2e=1; ok "c-m1-e2e -- real workers read an EXCLUDED driver, two guarded driver removals and one UNGUARDED-READ"
else bad "c-m1-e2e -- rc $(rcof "$C/m1e2e"): $(grep -E 'R13-POPULATION|UNGUARDED|FAIL' "$C/m1e2e" | tr '\n' ' ')"; fi

WG="$(world g)"; wcheck "$WG"; S1="$(store)"
cli c-write "$D" "$C/write" "$S1" - --r13-drive corpus --traced-removal --probe-world "$PW" "$WG/docs/backlog.md"
instr_refused "$C/write"
if cell_c_instr "$C/write"; then B_instr=1; ok "c-instr -- the in-arm instrument probe ran and atime moved"; else bad "c-instr -- no R13-INSTRUMENT line"; fi
if cell_c_write "$C/write"; then B_write=1; ok "c-write -- R13 traced, removed 2 named reads (both guarded), wrote one record, and its self-probe fired over every seed"
else bad "c-write -- $(grep -E 'R13-POPULATION|SELF-PROBE FAILED|R13-RC' "$C/write" | tr '\n' ' ')"; fi
if cell_c_enumline "$C/write"; then B_enum=1; ok "c-enumline -- the population line prints the enumerated-excluded count"; else bad "c-enumline -- no enumerated count"; fi
K1="$(klist "$C/write")"
[ "$(ls -A "$S1" | grep -c '\.green$')" = 1 ] || bad "c-write -- the store holds $(ls -A "$S1" | grep -c '\.green$') records, want 1"

cli c-replay "$D" "$C/replay" "$S1" - --r13-drive corpus --traced-removal --probe-seeds - "$WG/docs/backlog.md"
if cell_c_replay "$C/replay"; then ok "c-replay -- an unmoved key replayed: no removal, no self-probe, no new record"
else bad "c-replay -- $(grep -E 'R13-POPULATION|R13-RC|R13-RECORD' "$C/replay" | tr '\n' ' ')"; fi

WGJ="$(world g)"; wcheck "$WGJ"; SJ="$(store)"; cp "$S1"/*.green "$SJ/" 2>/dev/null
mkdist "$TMP/distj" "$D" || broken "the moved-judge copy did not build"
printf '# a moved judge byte\n' >> "$TMP/distj/scripts/validate-backlog-receipts.sh"
cli c-moved-judge "$TMP/distj/scripts/validate-backlog-receipts.sh" "$C/judge" "$SJ" - --r13-drive corpus --traced-removal --probe-seeds - "$WGJ/docs/backlog.md"
if cell_c_moved "$C/judge" "$K1"; then B_judge=1; ok "c-moved-judge -- one changed byte of the judge moved the key and R13 re-ran"
else bad "c-moved-judge -- K '$(klist "$C/judge")' against '$K1'"; fi

printf 'moved\n' >> "$WG/w/data.txt"
git -C "$WG" -c commit.gpgsign=false commit -q -am moved >/dev/null 2>&1 || broken "the moved-named commit did not build"
cli c-moved-named "$D" "$C/moved" "$S1" - --r13-drive corpus --traced-removal --probe-seeds - "$WG/docs/backlog.md"
if cell_c_moved "$C/moved" "$K1"; then B_moved=1; ok "c-moved-named -- a changed NAMED file moved the key and R13 re-ran"
else bad "c-moved-named -- K '$(klist "$C/moved")' against '$K1'"; fi

SU="$(store)"
cli red "$D" "$C/red" "$SU" - --r13-drive corpus --traced-removal --probe-seeds - "$(world u)/docs/backlog.md"
if cell_red_fail "$C/red"; then ok "red-fail -- an unguarded named read is UNGUARDED-READ over a ceiling of 0"
else bad "red-fail -- $(grep -E 'R13-POPULATION|R13-RC|FAIL' "$C/red" | tr '\n' ' ')"; fi
if cell_red_norecord "$C/red" "$SU"; then B_redn=1; ok "red-norecord -- a red R13 wrote no record (store empty before and after)"; else bad "red-norecord -- the store holds: $(ls -A "$SU" | tr '\n' ' ')"; fi

cli overflow "$D" "$C/over" "$(store)" - --r13-drive corpus --traced-removal --probe-seeds - "$(world o)/docs/backlog.md"
if cell_c_overflow "$C/over"; then ok "c-overflow -- 34 named reads printed R13-NAMED-OVERFLOW and refused"
else bad "c-overflow -- rc $(rcof "$C/over"): $(grep -E 'R13-' "$C/over" | tr '\n' ' ')"; fi

cli notrun "$D" "$C/notrun" "$(store)" - --r13-drive corpus "$(world g)/docs/backlog.md"
if cell_c_notrun "$C/notrun"; then ok "c-notrun -- without --traced-removal R13 says NOT RUN"; else bad "c-notrun -- no NOT RUN line"; fi

untraced_fn "$D" "$C/untraced"
if cell_c_untraced "$C/untraced"; then B_untr=1; ok "c-untraced -- r13_untraced reads 1 untraced, then 0 when traced, then 0 when R2 refused it before a checkout"
else bad "c-untraced -- read '$(cat "$C/untraced")', want '1 0 0'"; fi

# THE TWO-SIDED CEILING. c-stale-high: world u (1 unguarded row) under a ceiling of 2 FAILS with the lower-it message;
# the equal case is c-within-write below, and the above case is red-fail above.
cli c-stale-high "$D" "$C/stale" "$(store)" - --r13-drive corpus --traced-removal --probe-seeds - --max-unguarded 2 "$(world u)/docs/backlog.md"
if cell_c_stale_high "$C/stale"; then B_stale=1; ok "c-stale-high -- a live count below the ceiling failed and named the count to lower it to"
else bad "c-stale-high -- $(grep -E 'R13-RC|FAIL: R13' "$C/stale" | tr '\n' ' ')"; fi
# c-committed: the window is reachable AT THE COMMITTED VALUE. N is read from the subject's own DEFAULT_MAX_R13 line;
# a world with exactly N unguarded named reads, run at that ceiling, passes.
N_COMMITTED="$(sed -n 's/^DEFAULT_MAX_R13=\([0-9][0-9]*\)$/\1/p' "$R/scripts/validate-backlog-receipts.sh")"
case "$N_COMMITTED" in ''|*[!0-9]*) broken "no DEFAULT_MAX_R13=<n> line in the subject" ;; esac
[ "$N_COMMITTED" -le 31 ] || broken "DEFAULT_MAX_R13=$N_COMMITTED would overflow the 32-removal ceiling in one seeded receipt"
WF="$(mktemp -d "$TMP/wf.XXXXXX")" || broken "the committed-value world dir did not create"
mkdir -p "$WF/docs" "$WF/w" || broken "the committed-value world did not build"
: > "$WF/w/drv.sh"; _i=1
while [ "$_i" -le "$N_COMMITTED" ]; do
  printf 'x\n' > "$WF/w/f$_i.txt"; printf 'grep -q x w/f%s.txt || exit 1\n' "$_i" >> "$WF/w/drv.sh"; _i=$(( _i + 1 ))
done
printf 'exit 0\n' >> "$WF/w/drv.sh"
printf '# Probe backlog\n\n## BL-1401 — world f\n\nverify: sh bash w/drv.sh\n' > "$WF/docs/backlog.md"
( cd "$WF" && git init -q . && git add -A && git -c commit.gpgsign=false commit -q -m seed ) >/dev/null 2>&1
wcheck "$WF"
cli c-committed "$D" "$C/committed" "$(store)" - --r13-drive corpus --traced-removal --probe-seeds - --max-unguarded "$N_COMMITTED" "$WF/docs/backlog.md"
if has "$C/committed" "R13-RC 0 " && has "$C/committed" "$N_COMMITTED UNGUARDED-READ (ceiling $N_COMMITTED)"; then
  ok "c-committed -- a world with exactly the committed $N_COMMITTED unguarded reads passes at that ceiling"
else bad "c-committed -- $(grep -E 'R13-POPULATION|R13-RC|FAIL: R13' "$C/committed" | tr '\n' ' ')"; fi

# THE CEILING WITH NOTHING TO COUNT. c-empty-stale: an EMPTY open sh population (world n, `verify: manual` only) under a
# ceiling of 1 fails stale-high and names 0. c-nothing-judged: world x's one receipt is baseline cannot-measure (its
# driver was deleted on HEAD and --base has it), so nothing is judged; under a ceiling of 1 the run fails saying
# NOTHING WAS JUDGED, never "BELOW the ceiling".
cell_c_empty_stale() { [ "$(rcof "$1")" = 1 ] && has "$1" "R13-POPULATION: EMPTY" && has "$1" "the open sh population is EMPTY, so the live UNGUARDED-READ count is 0, BELOW the ceiling of 1" && has "$1" "to 0"; }
cell_c_nothing_judged() { [ "$(rcof "$1")" = 1 ] && has "$1" "FAIL: R13: NOTHING WAS JUDGED -- 0 of 1 traced" && ! has "$1" "BELOW the ceiling"; }
empty_run() { cli "$1" "$2" "$3" "$(store)" - --r13-drive corpus --traced-removal --probe-seeds - --max-unguarded 1 "$(world n)/docs/backlog.md"; }
judged_run() { # judged_run <cell> <copy> <out>
  local w; w="$(world x)"; wcheck "$w"
  cli "$1" "$2" "$3" "$(store)" - --r13-drive corpus --traced-removal --probe-seeds - --max-unguarded 1 --base "$(cat "$w/.git/fx-base")" "$w/docs/backlog.md"
}
B_empty=0; B_judged=0
empty_run c-empty-stale "$D" "$C/empty"
if cell_c_empty_stale "$C/empty"; then B_empty=1; ok "c-empty-stale -- an EMPTY population under a ceiling of 1 failed and named 0"
else bad "c-empty-stale -- verdict $(rcof "$C/empty"): $(grep -E 'R13-POPULATION|FAIL: R13' "$C/empty" | tr '\n' ' ')"; fi
judged_run c-nothing-judged "$D" "$C/judged"
if cell_c_nothing_judged "$C/judged"; then B_judged=1; ok "c-nothing-judged -- a run that judged nothing under a ceiling of 1 failed saying NOTHING WAS JUDGED"
else bad "c-nothing-judged -- verdict $(rcof "$C/judged"): $(grep -E 'R13-POPULATION|FAIL: R13' "$C/judged" | tr '\n' ' ')"; fi

# pop_run <copy> <prefix> <id-prefix> -- world e (2 named removals, 1 named-unread, 1 enumerated), one store: a live
# write, then its replay. c-replay-pop: the replay prints the live run's figures, labelled replayed.
pop_run() {
  local s w; s="$(store)"; w="$(world e)"; wcheck "$w"
  cli "$3-1" "$1" "$2.1" "$s" - --r13-drive corpus --traced-removal --probe-seeds - "$w/docs/backlog.md"
  cli "$3-2" "$1" "$2.2" "$s" - --r13-drive corpus --traced-removal --probe-seeds - "$w/docs/backlog.md"
}
pop_run "$D" "$C/pop" pop
if cell_c_pop_live "$C/pop.1"; then ok "c-pop-live -- the live run printed 2 named removals, 1 named-unread and 1 enumerated excluded"
else bad "c-pop-live -- $(grep -E 'R13-POPULATION|R13-RC' "$C/pop.1" | tr '\n' ' ')"; fi
if cell_c_replay_pop "$C/pop.1" "$C/pop.2"; then B_pop=1; ok "c-replay-pop -- the replay re-printed the live run's population figures, labelled replayed"
else bad "c-replay-pop -- $(grep -E 'R13-POPULATION' "$C/pop.2" | tr '\n' ' ')"; fi

# within_run <copy> <prefix> <id-prefix> -- world u, one store, three starts: write at ceiling 1, replay at 1, replay at 0.
within_run() {
  local s w; s="$(store)"; w="$(world u)"; wcheck "$w"
  cli "$3-1" "$1" "$2.1" "$s" - --r13-drive corpus --traced-removal --probe-seeds - --max-unguarded 1 "$w/docs/backlog.md"
  cli "$3-2" "$1" "$2.2" "$s" - --r13-drive corpus --traced-removal --probe-seeds - --max-unguarded 1 "$w/docs/backlog.md"
  cli "$3-3" "$1" "$2.3" "$s" - --r13-drive corpus --traced-removal --probe-seeds - --max-unguarded 0 "$w/docs/backlog.md"
}
within_run "$D" "$C/within" within
if cell_c_within_write "$C/within.1"; then ok "c-within-write -- an UNGUARDED-READ within the ceiling wrote the record"
else bad "c-within-write -- $(grep -E 'R13-POPULATION|R13-RC|R13-RECORD' "$C/within.1" | tr '\n' ' ')"; fi
if cell_c_within_replay "$C/within.1" "$C/within.2" "$C/within.3"; then B_within=1; ok "c-within -- its replay re-printed the stored row, passed at ceiling 1 and failed at ceiling 0"
else bad "c-within -- replay at 1: $(grep -E 'R13-RC' "$C/within.2" | tr '\n' ' ') replay at 0: $(grep -E 'R13-RC|FAIL: R13' "$C/within.3" | tr '\n' ' ')"; fi

# c-instr-refused, through the documented seam BR_R13_PROBE_DIR: its `read` is pre-placed at mode 0200, so the probe's
# cat cannot open it and its atime stays at the epoch. No command is shadowed.
AG="$TMP/aged-probe"; mkdir -p "$AG" && printf 'r\n' > "$AG/read" && chmod 0200 "$AG/read" || broken "the aged probe dir did not build"
cli c-instr-refused "$D" "$C/irefused" "$(store)" "BR_R13_PROBE_DIR=$AG" --r13-drive corpus --traced-removal --probe-seeds - "$(world g)/docs/backlog.md"
if cell_c_instr_refused "$C/irefused"; then ok "c-instr-refused -- an atime that did not move on a read refused R13 (exit 2)"
else bad "c-instr-refused -- rc $(rcof "$C/irefused"): $(grep -E 'R13-INSTRUMENT' "$C/irefused" | tr '\n' ' ')"; fi

# m1-base3: three states of a GIVEN --base. (i) and (ii) are vbr_sec_setup alone (in process); (iii) scores world x.
WX="$(world x)"; wcheck "$WX"; XB="$(cat "$WX/.git/fx-base")"
base_setup "$D" "$C/base3.1" "$XB" "$WX/docs/backlog.md"
base_setup "$D" "$C/base3.2" refs/heads/no-such-base-zz "$WX/docs/backlog.md"
cli base3-3 "$D" "$C/base3.3" "$(store)" - --r13-drive score --base "$XB" "$WX/docs/backlog.md"
if cell_m1_base3 "$C/base3.1" "$C/base3.2" "$C/base3.3"; then B_base3=1; ok "m1-base3 -- a resolving --base passes, an unresolvable one refuses with M1-BASE-UNRESOLVED (exit 2), and a removed driver reads DRIVER-REMOVED"
else bad "m1-base3 -- rc $(rcof "$C/base3.1")/$(rcof "$C/base3.2")/$(rcof "$C/base3.3"): $(grep -hE 'M1-BASE|SETUP-OK|base-exit' "$C/base3.1" "$C/base3.2" "$C/base3.3" | tr '\n' ' ')"; fi

# cli-wire: the one end-to-end run -- the CLI's own path, vbr_sec_corpus's R13 call lines, the --traced-removal flag.
WC="$(world g)"; wcheck "$WC"
mkdir -p "$WC/scripts" "$WC/core/skills/ai-dlc-update/reconcile" "$WC/core/skills/ai-dlc/steps" \
         "$WC/docs/analysis/pipeline-efficiency-s317-s320/scripts" || broken "the CLI world did not build"
cp "$TMP/dist/VERSION" "$WC/" && cp "$TMP/dist/scripts/"*.sh "$WC/scripts/" \
  && cp "$TMP/dist/core/skills/ai-dlc-update/reconcile/"*.sh "$WC/core/skills/ai-dlc-update/reconcile/" || broken "the CLI world did not copy"
printf '%s\n' 'STEP_RE = re.compile(r"skills/ai-dlc(?:-update)?/steps/([A-Za-z0-9_.-]+)\.md")' \
  'SUBPROC = {"_gate-procedures", "_dispatch-protocol"}' > "$WC/docs/analysis/pipeline-efficiency-s317-s320/scripts/extract.py"
printf '%s\n' 'GROUPS = [' "    ('one step', 'pipeline', {'implementation'})," \
  "    ('the whole pipeline bucket', 'pipeline', None)," ']' > "$WC/docs/analysis/pipeline-efficiency-s317-s320/scripts/roll.py"
: > "$WC/core/skills/ai-dlc/steps/implementation.md"
( cd "$WC" && git add -A && git -c commit.gpgsign=false commit -q -m cli ) >/dev/null 2>&1 || broken "the CLI world did not commit"
SC="$(store)"
( cd "$WC" && env FXCELL=cli-wire BR_R13_RECORD_DIR="$SC" bash scripts/validate-backlog-receipts.sh --traced-removal --max-unguarded 0 --min-entries 1 ) > "$C/cli" 2>&1
echo "$?" > "$C/cli.rc"; printf 'cli-wire\n' >> "$CELLS_USED"
instr_refused "$C/cli"
if [ "$(rcof "$C/cli")" = 0 ] && has "$C/cli" "R13-POPULATION: 1 open sh receipt(s), 1 traced, 2 named removals" \
   && has "$C/cli" "R13-RECORD: WRITTEN BL-1401" && has "$C/cli" "R13 fired both directions"; then
  ok "cli-wire -- the CLI with --traced-removal ran R13 end to end and wrote its record"
else bad "cli-wire -- rc $(rcof "$C/cli"): $(grep -E 'R13-|FAIL' "$C/cli" | head -5 | tr '\n' ' ')"; fi
# c-restricted-seeds: a start given ONLY `--probe-seeds -` (no --r13-drive) is restricted too. The cheapest green verdict
# with no drive is `--efficiency-only` in the CLI world (no receipt, no worker): it must exit 3 with verdict-rc=0.
B_rseeds=0
cli c-restricted-seeds "$WC/scripts/validate-backlog-receipts.sh" "$C/rseeds" "$(store)" - --efficiency-only --probe-seeds - "$WC/docs/backlog.md"
if cell_c_restricted "$C/rseeds"; then B_rseeds=1; ok "c-restricted-seeds -- a start given only --probe-seeds exited 3 with verdict-rc=0"
else bad "c-restricted-seeds -- raw exit $(cat "$C/rseeds.raw" 2>/dev/null): $(grep -E 'RESTRICTED:|FAIL' "$C/rseeds" | head -3 | tr '\n' ' ')"; fi

# --- the mutants ---------------------------------------------------------------------------
# mkmut <name> <old> <new> [<old> <new>]... -- a whole-tree copy whose validator has each <old> (a literal that must
# occur on exactly ONE line) replaced by <new>; prints the copy's validator, or nothing when a mutation did not apply.
mkmut() {
  local n="$1" d="$TMP/m-$1" f; shift
  mkdist "$d" "$D" || return 1
  f="$d/scripts/validate-backlog-receipts.sh"
  while [ "$#" -ge 2 ]; do
    [ "$(OLD="$1" awk 'BEGIN { o = ENVIRON["OLD"] } index($0, o) { c++ } END { print c + 0 }' "$f")" = 1 ] \
      || { echo "MUTANT $n -- its anchor is not on exactly one line: $1" >&2; return 1; }
    cp "$f" "$f.pre"
    OLD="$1" NEW="$2" awk 'BEGIN { o = ENVIRON["OLD"]; w = ENVIRON["NEW"] }
      { i = index($0, o); if (i) $0 = substr($0, 1, i - 1) w substr($0, i + length(o)); print }' "$f.pre" > "$f" \
      || { echo "MUTANT $n -- its rewrite died" >&2; return 1; }
    if cmp -s "$f" "$f.pre"; then echo "MUTANT $n -- DID NOT APPLY: $1" >&2; return 1; fi
    rm -f "$f.pre"; shift 2
  done
  bash -n "$f" 2>/dev/null || { echo "MUTANT $n -- the mutated validator does not parse" >&2; return 1; }
  [ -f "$d/scripts/backlog-receipt-lib.sh" ] || { echo "MUTANT $n -- its copy lacks the sibling lib" >&2; return 1; }
  printf '%s' "$f"
}
# mut_or_broken <name> <path> -- `exit` inside $( ) ends only the subshell, so the caller checks the captured path.
mut_or_broken() { [ -n "$2" ] && [ -f "$2" ] || broken "MUTANT $1 did not build (reason above)"; }
# A probe-mode mutant re-runs ONLY its killing seed (<id>, or `-` for a function-level seed) on the shared world; its
# own cell is that seed's SELF-PROBE FAILED line, its twin c-instr.
probe_mut() { # probe_mut <name> <seed> <seed id or -> <old> <new> [...]
  local n="$1" s="$2" id="$3" f o; shift 3
  f="$(mkmut "$n" "$@")"; mut_or_broken "$n" "$f"
  o="$TMP/cap/$n"; cli "$n" "$f" "$o" "$(store)" - --r13-drive probe --traced-removal --probe-world "$PW" --probe-seeds "$id" "$LEDGER0"
  [ "$MATRIX" = 1 ] && { echo "MATRIX $n trips: $(sed -n 's/.*SELF-PROBE FAILED -- \([A-Z0-9]*\): seed \([^:]*\):.*/\1:\2/p' "$o" | tr '\n' ' ') c-instr=$(cell_c_instr "$o" && echo GREEN || echo TRIP)"; return 0; }
  if ! seed_ok "$o" R13 "$s" && cell_c_instr "$o"; then mutant_killed "$B_write" "$n" "MUTANT $n KILLED by $s -- seed $s refused it, c-instr green"
  else bad "MUTANT $n SURVIVED -- want SELF-PROBE FAILED -- R13: seed $s (got: $(grep -F 'SELF-PROBE FAILED' "$o" | head -1))"; fi
}
m1_mut() { # m1_mut <name> <seed> <seed id> <old> <new> [...]
  local n="$1" s="$2" id="$3" f o; shift 3
  f="$(mkmut "$n" "$@")"; mut_or_broken "$n" "$f"
  o="$TMP/cap/$n"; cli "$n" "$f" "$o" "$(store)" - --r13-drive m1 --probe-seeds "$id" "$LEDGER0"
  [ "$MATRIX" = 1 ] && { echo "MATRIX $n trips: $(sed -n 's/.*SELF-PROBE FAILED -- \([A-Z0-9]*\): seed \([^:]*\):.*/\1:\2/p' "$o" | tr '\n' ' ')"; return 0; }
  if ! seed_ok "$o" M1 "$s"; then mutant_killed "$B_m1" "$n" "MUTANT $n KILLED by $s -- seed $s refused it"
  else bad "MUTANT $n SURVIVED -- want SELF-PROBE FAILED -- M1: seed $s (got: $(grep -F 'SELF-PROBE FAILED' "$o" | head -1))"; fi
}
# corpus_mut <name> <world> <decides-fn> <twin-fn> <flag> <old> <new> [...] -- one corpus start, self-probe seeds `-`.
corpus_mut() {
  local n="$1" w="$2" dc="$3" tw="$4" fl="$5" f o s; shift 5
  f="$(mkmut "$n" "$@")"; mut_or_broken "$n" "$f"
  o="$TMP/cap/$n"; s="$(store)"; cli "$n" "$f" "$o" "$s" - --r13-drive corpus --traced-removal --probe-seeds - "$(world "$w")/docs/backlog.md"
  [ "$MATRIX" = 1 ] && { echo "MATRIX $n $dc=$("$dc" "$o" "$s" && echo GREEN || echo TRIP) $tw=$("$tw" "$o" "$s" && echo GREEN || echo TRIP)"; return 0; }
  if ! "$dc" "$o" "$s" && "$tw" "$o" "$s"; then mutant_killed "$fl" "$n" "MUTANT $n KILLED by ${dc#cell_} -- its own cell tripped, ${tw#cell_} green"
  else bad "MUTANT $n SURVIVED -- ${dc#cell_} did not trip, or ${tw#cell_} tripped too"; fi
}
# keymut <name> <how> <flag> <old> <new> -- the M3 key mutants: a write, then a move, on ONE store; the second must re-run.
# The write's own c-write reading is its twin, so its self-probe seeds are `-` and c-write is read without its fired clause.
keymut() {
  local n="$1" how="$2" fl="$3" f o1 o2 s w k f2; shift 3
  f="$(mkmut "$n" "$@")"; mut_or_broken "$n" "$f"
  s="$(store)"; w="$(world g)"; o1="$TMP/cap/$n.1"; o2="$TMP/cap/$n.2"
  case "$w" in "$TMP"/*) [ -d "$w/.git" ] || broken "MUTANT $n: its world has no .git" ;; *) broken "MUTANT $n: its world did not copy" ;; esac
  cli "$n-1" "$f" "$o1" "$s" - --r13-drive corpus --traced-removal --probe-seeds - "$w/docs/backlog.md"
  k="$(klist "$o1")"; f2="$f"
  case "$how" in
    named) printf 'moved\n' >> "$w/w/data.txt"; git -C "$w" -c commit.gpgsign=false commit -q -am moved >/dev/null 2>&1 || broken "MUTANT $n: the moved-named commit did not build" ;;
    judge) mkdist "$TMP/m-$n-j" "$f" || broken "MUTANT $n: its moved-judge copy did not build"; f2="$TMP/m-$n-j/scripts/validate-backlog-receipts.sh"; printf '# a moved judge byte\n' >> "$f2" ;;
  esac
  cli "$n-2" "$f2" "$o2" "$s" - --r13-drive corpus --traced-removal --probe-seeds - "$w/docs/backlog.md"
  [ "$MATRIX" = 1 ] && { echo "MATRIX $n c-moved-$how=$(cell_c_moved "$o2" "$k" && echo GREEN || echo TRIP) c-write=$([ -n "$k" ] && echo GREEN || echo TRIP)"; return 0; }
  if ! cell_c_moved "$o2" "$k" && [ -n "$k" ]; then mutant_killed "$fl" "$n" "MUTANT $n KILLED by c-moved-$how -- the moved $how replayed a stale record, c-write green"
  else bad "MUTANT $n SURVIVED -- a moved $how still re-ran (or its write wrote no record)"; fi
}

corpus_mut m-r13-skipped g cell_c_write_nf cell_c_instr "$B_write" 'r13_corpus() {' 'r13_corpus() { return 0;'
probe_mut m-removal-not-applied p1 BL-1301 \
  '  git -C "$TA" rm -q -- "$_p" >/dev/null 2>&1 \' '  true \' \
  'commit -q --no-verify -m "r13 removal"' 'commit -q --allow-empty --no-verify -m "r13 removal"' \
  'r13_removed_ok() {' 'r13_removed_ok() { return 0;'
probe_mut m-cm-widened p4 BL-1304 'r13_judge_rc() { [ -n "$2" ]; }' 'r13_judge_rc() { [ -n "$2" ] || [ "$1" = 1 ]; }'
m1_mut m-l3b-widened m1-c BL-1321 \
  "    if [ -z \"\${BR_L3_BASE:-}\" ]; then printf 'driver-absent/DRIVER-ABSENT-UNRESOLVED-BASE'" \
  "    if true; then printf 'EXCLUDED-DRIVER-ABSENT-AT-BASE'"
m1_mut m-any-bash-line m1-nearmiss BL-1324 '$(m1_driver_ops "$4")' "\$(sed -n 's/^bash: \\(.*\\): No such file or directory\$/0 \\1/p' \"\$2\")"
m1_mut m-no-exist-conjunct m1-present BL-1325 '    [ ! -e "$_tree/$_p" ] || continue' '    :'
m1_mut m-no-options m1-option BL-1326 '      while (i <= nw && substr(T[i], 1, 1) == "-") {' '      while (0) {'
m1_mut m-no-long-options m1-option-long BL-1329 '        if (T[i] ~ /^--[a-z][a-z-]*$/) { o = 1; i++; continue }' '        if (0) { o = 1; i++; continue }'
m1_mut m-no-optarg m1-option-arg BL-1330 \
  '        if (T[i] == "-o" || T[i] == "-O" || T[i] == "--rcfile" || T[i] == "--init-file") { o = 1; i += 2; continue }' \
  '        if (0) { o = 1; i += 2; continue }'
m1_mut m-first-segment m1-chain BL-1327 'for (k = 1; k <= ns; k++)' 'for (k = 1; k <= 1; k++)'
m1_mut m-no-rc1-branch m1-option-e BL-1328 '  case "$_rc" in 127|1) ;; *) return 0 ;; esac' '  case "$_rc" in 127) ;; *) return 0 ;; esac'
corpus_mut m-red-writes u cell_red_norecord cell_red_fail "$B_redn" 'in the script it runs. A red R13 writes no record." >&2' 'in the script it runs. A red R13 writes no record." >&2; r13_records "$_sd"'
# m-replay-drops-rows: the replay keeps no stored rows, so the replay at ceiling 0 passes. Twin: c-within-write.
f="$(mkmut m-replay-drops-rows "    sed '1,/^#r13-rows\$/d' \"\$BR_R13_STORE/\$_k.green\" | awk '!/^#r13-pop /' > \"\$_d/\$n.replayrows\"" '    : > "$_d/$n.replayrows"')"
mut_or_broken m-replay-drops-rows "$f"
within_run "$f" "$TMP/cap/m-replay-drops-rows" m-replay-drops-rows
if [ "$MATRIX" = 1 ]; then echo "MATRIX m-replay-drops-rows c-within=$(cell_c_within_replay "$TMP/cap/m-replay-drops-rows.1" "$TMP/cap/m-replay-drops-rows.2" "$TMP/cap/m-replay-drops-rows.3" && echo GREEN || echo TRIP) c-within-write=$(cell_c_within_write "$TMP/cap/m-replay-drops-rows.1" && echo GREEN || echo TRIP)"
elif ! cell_c_within_replay "$TMP/cap/m-replay-drops-rows.1" "$TMP/cap/m-replay-drops-rows.2" "$TMP/cap/m-replay-drops-rows.3" && cell_c_within_write "$TMP/cap/m-replay-drops-rows.1"; then
  mutant_killed "$B_within" m-replay-drops-rows "MUTANT m-replay-drops-rows KILLED by c-within -- a replay without its stored rows passed a lowered ceiling, c-within-write green"
else bad "MUTANT m-replay-drops-rows SURVIVED -- c-within did not trip, or c-within-write tripped too"; fi
# m-replay-drops-counts: the replay keeps no stored population figures, so it prints zeros.
f="$(mkmut m-replay-drops-counts "    sed -n 's/^#r13-pop //p' \"\$BR_R13_STORE/\$_k.green\" > \"\$_d/\$n.replaypop\"" '    : > "$_d/$n.replaypop"')"
mut_or_broken m-replay-drops-counts "$f"
pop_run "$f" "$TMP/cap/m-replay-drops-counts" m-replay-drops-counts
if [ "$MATRIX" = 1 ]; then echo "MATRIX m-replay-drops-counts c-replay-pop=$(cell_c_replay_pop "$TMP/cap/m-replay-drops-counts.1" "$TMP/cap/m-replay-drops-counts.2" && echo GREEN || echo TRIP) c-pop-live=$(cell_c_pop_live "$TMP/cap/m-replay-drops-counts.1" && echo GREEN || echo TRIP)"
elif ! cell_c_replay_pop "$TMP/cap/m-replay-drops-counts.1" "$TMP/cap/m-replay-drops-counts.2" && cell_c_pop_live "$TMP/cap/m-replay-drops-counts.1"; then
  mutant_killed "$B_pop" m-replay-drops-counts "MUTANT m-replay-drops-counts KILLED by c-replay-pop -- a replay without its stored figures printed zeros, c-pop-live green"
else bad "MUTANT m-replay-drops-counts SURVIVED -- c-replay-pop did not trip, or c-pop-live tripped too"; fi
# m-base-refusal-pass: an unresolvable GIVEN --base no longer refuses; only state (ii) is re-run (in process).
f="$(mkmut m-base-refusal-pass '  exit 2 # M1-BASE-UNRESOLVED refuses' '  return 0 # M1-BASE-UNRESOLVED refuses')"
mut_or_broken m-base-refusal-pass "$f"
base_setup "$f" "$TMP/cap/m-base-refusal-pass.2" refs/heads/no-such-base-zz "$WX/docs/backlog.md"
if [ "$MATRIX" = 1 ]; then echo "MATRIX m-base-refusal-pass m1-base3=$(cell_m1_base3 "$C/base3.1" "$TMP/cap/m-base-refusal-pass.2" "$C/base3.3" && echo GREEN || echo TRIP)"
elif ! cell_m1_base3 "$C/base3.1" "$TMP/cap/m-base-refusal-pass.2" "$C/base3.3"; then
  mutant_killed "$B_base3" m-base-refusal-pass "MUTANT m-base-refusal-pass KILLED by m1-base3 -- an unresolvable given --base passed setup"
else bad "MUTANT m-base-refusal-pass SURVIVED -- m1-base3 did not trip"; fi
keymut m-key-no-blobs named "$B_moved" \
  '{ m++; printf "named %s %s base=%s\n", $0, ($0 in B ? B[$0] : "-"), (nb ? P[m] : "-") }' \
  '{ m++; printf "named %s base=%s\n", $0, (nb ? P[m] : "-") }'
corpus_mut m-no-enum-count g cell_c_enumline cell_c_write_nf "$B_enum" '$(( _en + _enr )) enumerated excluded ($_enr replayed), ' ''
keymut m-key-no-judge judge "$B_judge" "  printf 'r13-judge %s\n' \$_ids" '  :'
probe_mut m-depth1 p2 BL-1302 '  q = 1; scanned = 0; unread = 0' '  q = 1; scanned = 0; unread = 0; qmax = ne' '  while (q <= ne) {' '  while (q <= qmax) {'
probe_mut m-named-all-reads p6-enum BL-1308 '| LC_ALL=C sort -u > "$_d/$n.reads"' '| LC_ALL=C sort -u > "$_d/$n.reads"; cp "$_d/$n.reads" "$_d/$n.named"'
probe_mut m-basename p2-basename BL-1302 \
  '{ TR[$0] = 1; ntr++ }' '{ TR[$0] = 1; ntr++; b = $0; sub(/.*\//, "", b); BNL[b] = BNL[b] " " $0 }' \
  '        if (!(c in NAMED)) { NAMED[c] = 1; nn++; NEW[nn] = c }' \
  '        b = c; sub(/.*\//, "", b); nb2 = split(BNL[b], BB, " "); for (j = 1; j <= nb2; j++) if (!(BB[j] in NAMED)) { NAMED[BB[j]] = 1; nn++; NEW[nn] = BB[j] }'
probe_mut m-no-epoch must-miss BL-1301 '  find "$1" "$2" -path "$1/.git" -prune -o -exec touch -a -h -t 200001010000 {} + 2>/dev/null' '  :'
probe_mut m-no-must-hit failure-probe BL-1301 \
  '    if [ -n "$_drv" ] && grep -qxF -- "$_drv" "$_sd/$_n.named" && ! grep -qxF -- "$_drv" "$_sd/$_n.reads"; then' '    if false; then'
probe_mut m-atime-never must-hit BL-1301 "    | awk -v p=\"\$_t/\" 'index(\$0, p) == 1 { print substr(\$0, length(p) + 1) }' > \"\$_d/\$n.allreads\"" \
  '    | cat > /dev/null; : > "$_d/$n.allreads"'
corpus_mut m-instrument-skipped g cell_c_instr cell_c_write_nf "$B_instr" '  r13_instrument_probe "${BR_R13_PROBE_DIR:-$WORK/r13i}" || exit 2' '  : || exit 2'
probe_mut m-comments-named p4-comment BL-1304 '      if (substr(t, 1, 1) == "#") continue' '      t = t'
probe_mut m-expand-any-named p14-string BL-1315 '        if (isx) push(c)' '        push(c)'
probe_mut m-no-overflow p8-overflow BL-1310 '    if [ "$_nr" -gt "$R13_MAX_REMOVALS" ]; then' '    if false; then'
# m-trustctime-dropped is killed by the function-level seed `trustctime`, not by p9: git compares ctime at one-second
# granularity, so p9 can only see the setting missing when its epoch crosses a second (see the validator).
probe_mut m-trustctime-dropped trustctime - \
  'r13_eval_env() { export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.trustctime GIT_CONFIG_VALUE_0=false; }' 'r13_eval_env() { :; }'
probe_mut m-closure-after-reset p10-unread BL-1312 '  r13_reset "$_t" "$_d/$n.ctl"' \
  '  r13_reset "$_t" "$_d/$n.ctl"; awk -v root="$_t" -v recf="$_d/$n.receipt" -f "$BR_R13_AWK" "$_d/$n.tracked" > /dev/null 2>&1'
probe_mut m-no-named-read-rule no-named-read BL-1313 '    if [ -s "$_sd/$_n.named" ] && [ "$_nr" -eq 0 ]; then' '    if false; then'
# m-no-stale-high: the below-ceiling side removed; c-stale-high's start then passes.
f="$(mkmut m-no-stale-high '  [ "$_ng" -lt "$MAX_R13" ] && {' '  false && {')"
mut_or_broken m-no-stale-high "$f"
cli m-no-stale-high "$f" "$TMP/cap/m-no-stale-high" "$(store)" - --r13-drive corpus --traced-removal --probe-seeds - --max-unguarded 2 "$(world u)/docs/backlog.md"
if [ "$MATRIX" = 1 ]; then echo "MATRIX m-no-stale-high c-stale-high=$(cell_c_stale_high "$TMP/cap/m-no-stale-high" && echo GREEN || echo TRIP) c-instr=$(cell_c_instr "$TMP/cap/m-no-stale-high" && echo GREEN || echo TRIP)"
elif ! cell_c_stale_high "$TMP/cap/m-no-stale-high" && cell_c_instr "$TMP/cap/m-no-stale-high"; then
  mutant_killed "$B_stale" m-no-stale-high "MUTANT m-no-stale-high KILLED by c-stale-high -- a live count below the ceiling passed, c-instr green"
else bad "MUTANT m-no-stale-high SURVIVED -- c-stale-high did not trip, or c-instr tripped too"; fi
# m-no-settle: the index settle dropped; every file of p9's racily-clean checkout is re-read by its git status.
probe_mut m-no-settle p9-gitstatus BL-1311 '  r13_settle_index "$_t" || { r13_state refused index-settle; return 0; }' '  :'
# m-l3-base-not-exported: THE CALLER-WIRING MUTANT. score_ledger no longer exports BR_L3_BASE to its workers, so every
# M1 function is intact and only the worker's input is broken: c-m1-e2e must trip (BL-1401 reads L3 (d) and becomes
# baseline-cm), and the start-free function-level probe, which sets BR_L3_BASE itself, must stay GREEN (its twin).
f="$(mkmut m-l3-base-not-exported \
  '  export BR_WORK BR_SUBJECT_ROOT BR_PATH_CLASS BR_TOKAWK BR_GENERIC_SEED BR_SENTINEL BR_LIB_VARS BR_L3_BASE' \
  '  export BR_WORK BR_SUBJECT_ROOT BR_PATH_CLASS BR_TOKAWK BR_GENERIC_SEED BR_SENTINEL BR_LIB_VARS')"
mut_or_broken m-l3-base-not-exported "$f"
m1e2e_run "$f" "$TMP/cap/m-l3-base-not-exported.1" m-l3-base-not-exported-1
cli m-l3-base-not-exported-2 "$f" "$TMP/cap/m-l3-base-not-exported.2" "$(store)" - --r13-drive m1 "$LEDGER0"
_m1fn_green=0; [ "$(rcof "$TMP/cap/m-l3-base-not-exported.2")" = 0 ] && has "$TMP/cap/m-l3-base-not-exported.2" "M1-OK M1 fired both directions" && _m1fn_green=1
if [ "$MATRIX" = 1 ]; then echo "MATRIX m-l3-base-not-exported c-m1-e2e=$(cell_c_m1_e2e "$TMP/cap/m-l3-base-not-exported.1" && echo GREEN || echo TRIP) m1=$([ "$_m1fn_green" = 1 ] && echo GREEN || echo TRIP)"
elif ! cell_c_m1_e2e "$TMP/cap/m-l3-base-not-exported.1" && [ "$_m1fn_green" = 1 ]; then
  mutant_killed "$B_m1e2e" m-l3-base-not-exported "MUTANT m-l3-base-not-exported KILLED by c-m1-e2e -- the worker read no base and the function-level probe stayed green"
else bad "MUTANT m-l3-base-not-exported SURVIVED -- c-m1-e2e did not trip, or the function-level probe tripped too"; fi
# wiring_mut <name> <old> <new> -- a CALLER-WIRING mutant: c-m1-e2e must trip on its end-to-end start, and the
# start-free function-level probe, a separate start of the same copy, must stay GREEN.
wiring_mut() {
  local n="$1" f g; shift
  f="$(mkmut "$n" "$@")"; mut_or_broken "$n" "$f"
  m1e2e_run "$f" "$TMP/cap/$n.1" "$n-1"
  cli "$n-2" "$f" "$TMP/cap/$n.2" "$(store)" - --r13-drive m1 "$LEDGER0"
  g=0; [ "$(rcof "$TMP/cap/$n.2")" = 0 ] && has "$TMP/cap/$n.2" "M1-OK M1 fired both directions" && g=1
  if [ "$MATRIX" = 1 ]; then echo "MATRIX $n c-m1-e2e=$(cell_c_m1_e2e "$TMP/cap/$n.1" && echo GREEN || echo TRIP) m1=$([ "$g" = 1 ] && echo GREEN || echo TRIP)"
  elif ! cell_c_m1_e2e "$TMP/cap/$n.1" && [ "$g" = 1 ]; then
    mutant_killed "$B_m1e2e" "$n" "MUTANT $n KILLED by c-m1-e2e -- real workers misread M1 while the function-level probe stayed green"
  else bad "MUTANT $n SURVIVED -- c-m1-e2e did not trip, or the function-level probe tripped too"; fi
}
# m-cm-m1-call-dropped: cm_reason no longer calls M1, so a removed driver is never cannot-measure in a worker.
wiring_mut m-cm-m1-call-dropped '         else _cm_m1="$(m1_driver_absent "$1" "$2" "${TA:-}" "$REST")"' '         else _cm_m1=""'
# m-excluded-call-dropped: the worker no longer asks M1 whether a driver absent at HEAD is EXCLUDED (L3 (b)).
wiring_mut m-excluded-call-dropped \
  '  [ -z "$BASE_CM" ] && [ "$(m1_driver_absent "$BASE_RC" "$W/t/$n.err" "$TA" "$REST")" = EXCLUDED-DRIVER-ABSENT-AT-BASE ] && BASE_X="-excluded=driver-absent-at-base"' '  :'
# m-empty-stale-dropped / m-nothing-judged-dropped: the two-sided ceiling no longer holds with nothing to count.
f="$(mkmut m-empty-stale-dropped '    [ "$MAX_R13" -gt 0 ] && { echo "FAIL: R13: the open sh population is EMPTY' '    false && { echo "FAIL: R13: the open sh population is EMPTY')"
mut_or_broken m-empty-stale-dropped "$f"
empty_run m-empty-stale-dropped "$f" "$TMP/cap/m-empty-stale-dropped"
if [ "$MATRIX" = 1 ]; then echo "MATRIX m-empty-stale-dropped c-empty-stale=$(cell_c_empty_stale "$TMP/cap/m-empty-stale-dropped" && echo GREEN || echo TRIP) c-instr=$(cell_c_instr "$TMP/cap/m-empty-stale-dropped" && echo GREEN || echo TRIP)"
elif ! cell_c_empty_stale "$TMP/cap/m-empty-stale-dropped" && cell_c_instr "$TMP/cap/m-empty-stale-dropped"; then
  mutant_killed "$B_empty" m-empty-stale-dropped "MUTANT m-empty-stale-dropped KILLED by c-empty-stale -- an EMPTY population passed a ceiling of 1, c-instr green"
else bad "MUTANT m-empty-stale-dropped SURVIVED -- c-empty-stale did not trip, or c-instr tripped too"; fi
f="$(mkmut m-nothing-judged-dropped '  [ "$_jd" -eq 0 ] && [ "$MAX_R13" -gt 0 ] && {' '  false && {')"
mut_or_broken m-nothing-judged-dropped "$f"
judged_run m-nothing-judged-dropped "$f" "$TMP/cap/m-nothing-judged-dropped"
if [ "$MATRIX" = 1 ]; then echo "MATRIX m-nothing-judged-dropped c-nothing-judged=$(cell_c_nothing_judged "$TMP/cap/m-nothing-judged-dropped" && echo GREEN || echo TRIP) c-instr=$(cell_c_instr "$TMP/cap/m-nothing-judged-dropped" && echo GREEN || echo TRIP)"
elif ! cell_c_nothing_judged "$TMP/cap/m-nothing-judged-dropped" && cell_c_instr "$TMP/cap/m-nothing-judged-dropped"; then
  mutant_killed "$B_judged" m-nothing-judged-dropped "MUTANT m-nothing-judged-dropped KILLED by c-nothing-judged -- a run that judged nothing read as a count of 0, c-instr green"
else bad "MUTANT m-nothing-judged-dropped SURVIVED -- c-nothing-judged did not trip, or c-instr tripped too"; fi
# m-restricted-trigger-drive-only: only --r13-drive arms the restricted exit, so a --probe-seeds-only start exits 0.
# Its copy sits in a copy of the CLI world, which the efficiency arms need.
f="$(mkmut m-restricted-trigger-drive-only '[ -n "$R13_DRIVE$PROBE_SEEDS$PROBE_WORLD${BR_R13_PROBE_DIR:-}" ] && trap vbr_restricted_exit EXIT' '[ -n "$R13_DRIVE" ] && trap vbr_restricted_exit EXIT')"
mut_or_broken m-restricted-trigger-drive-only "$f"
cp -R "$WC" "$TMP/wcm" && cp "$f" "$TMP/wcm/scripts/validate-backlog-receipts.sh" || broken "MUTANT m-restricted-trigger-drive-only: its CLI-world copy did not build"
cli m-restricted-trigger-drive-only "$TMP/wcm/scripts/validate-backlog-receipts.sh" "$TMP/cap/m-restricted-trigger-drive-only" "$(store)" - --efficiency-only --probe-seeds - "$TMP/wcm/docs/backlog.md"
if [ "$MATRIX" = 1 ]; then echo "MATRIX m-restricted-trigger-drive-only c-restricted-seeds=$(cell_c_restricted "$TMP/cap/m-restricted-trigger-drive-only" && echo GREEN || echo TRIP)"
elif ! cell_c_restricted "$TMP/cap/m-restricted-trigger-drive-only"; then
  mutant_killed "$B_rseeds" m-restricted-trigger-drive-only "MUTANT m-restricted-trigger-drive-only KILLED by c-restricted-seeds -- a --probe-seeds-only start exited $(cat "$TMP/cap/m-restricted-trigger-drive-only.raw")"
else bad "MUTANT m-restricted-trigger-drive-only SURVIVED -- c-restricted-seeds did not trip"; fi
# m-restricted-exit-dropped: the restricted exit gives back the verdict's 0, so a narrowed run reads as a gate pass.
f="$(mkmut m-restricted-exit-dropped '  case "$_rc" in 0|1) exit 3 ;; *) exit "$_rc" ;; esac' '  case "$_rc" in 0|1) exit "$_rc" ;; *) exit "$_rc" ;; esac')"
mut_or_broken m-restricted-exit-dropped "$f"
cli m-restricted-exit-dropped "$f" "$TMP/cap/m-restricted-exit-dropped" "$(store)" - --r13-drive m1 --probe-seeds - "$LEDGER0"
if [ "$MATRIX" = 1 ]; then echo "MATRIX m-restricted-exit-dropped c-restricted=$(cell_c_restricted "$TMP/cap/m-restricted-exit-dropped" && echo GREEN || echo TRIP)"
elif ! cell_c_restricted "$TMP/cap/m-restricted-exit-dropped"; then
  mutant_killed "$B_restr" m-restricted-exit-dropped "MUTANT m-restricted-exit-dropped KILLED by c-restricted -- a narrowed run with a green verdict exited $(cat "$TMP/cap/m-restricted-exit-dropped.raw")"
else bad "MUTANT m-restricted-exit-dropped SURVIVED -- c-restricted did not trip"; fi
# m-no-untraced-check: r13_untraced reads every population as accounted for (in process, a function call).
f="$(mkmut m-no-untraced-check "  printf '%s' \"\$(( \$3 - \$1 - _pre ))\"" "  printf '0'")"
mut_or_broken m-no-untraced-check "$f"
untraced_fn "$f" "$TMP/cap/m-no-untraced-check"
if [ "$MATRIX" = 1 ]; then echo "MATRIX m-no-untraced-check c-untraced=$(cell_c_untraced "$TMP/cap/m-no-untraced-check" && echo GREEN || echo TRIP)"
elif ! cell_c_untraced "$TMP/cap/m-no-untraced-check"; then
  mutant_killed "$B_untr" m-no-untraced-check "MUTANT m-no-untraced-check KILLED by c-untraced -- r13_untraced read an untraced receipt as accounted for"
else bad "MUTANT m-no-untraced-check SURVIVED -- c-untraced did not trip"; fi

# THE CELLS THIS RUN TAGGED ARE THE ONES cells.decl DECLARES, EACH ONCE (the judge's C3, predicted here). One cmp of
# the sorted lists decides both: cells.decl declares each id once (the parse refuses a duplicate), so a cell tagged
# twice is a second line on the used side and the two files differ. No separate duplicate test.
sort "$CELLS_USED" > "$TMP/cells.used.s"
sed -n 's/^cli scripts\/validate-backlog-receipts\.sh \([A-Za-z0-9_.-]*\)$/\1/p' "$FX/cells.decl" | sort > "$TMP/cells.decl.s"
if cmp -s "$TMP/cells.used.s" "$TMP/cells.decl.s"; then
  ok "cells -- the $(grep -c . "$TMP/cells.used.s") tagged starts are exactly the cli cells of cells.decl, each once"
else bad "cells -- tagged and declared differ: $(diff "$TMP/cells.decl.s" "$TMP/cells.used.s" | grep '^[<>]' | tr '\n' ' ')"; fi

[ "$MATRIX" = 1 ] && exit 0
if [ "$FAILS" -ne 0 ]; then echo "$NAME: $FAILS failure(s)"; exit 1; fi
echo "PASS: $NAME"
exit 0
