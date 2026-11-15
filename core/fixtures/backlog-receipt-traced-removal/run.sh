#!/usr/bin/env bash
# backlog-receipt-traced-removal -- BL-899 in scripts/validate-backlog-receipts.sh: M1 (driver-absent in R7's
# cannot-measure set, lead ruling L3 (a)-(d)), R13 (traced removal over the NAMED closure, read set by atime after a
# forced epoch, the in-arm instrument check, the must-miss and must-hit controls, the 32-removal ceiling) and M3 (the
# per-receipt green record). Distribution-only: its .dist-only says why.
#
# HOW IT DRIVES THE VALIDATOR (lead ruling (a), batch 256). Each distinct state is ONE FXCELL-tagged `cli` start of a
# copy of the validator, run from the copy's tree in its cheap mode `--r13-drive <corpus|score>` (the
# validator's header beside DEFAULT_MAX_R13), and every worker that start launches (--score-one, --closed-one,
# --r13-one) is covered by the ONE self-nested row of cells.decl. The in-process passes that remain (fx_inproc) are
# r13_untraced called as a function, and vbr_sec_setup alone for the --base states; none of them reaches score_ledger, score_closed or r13_removals, so none starts a worker. ONE end-to-end
# CLI run (cell cli-wire) proves the corpus wiring and the --traced-removal flag.
# THE WORLDS ARE BUILT ONCE: the one-receipt worlds g/u/o/x/e as templates copied per drive (a drive that commits or writes a record gets its own
# copy and its own record store, so no drive replays a green another drive wrote).
#
# A SANDBOX THAT DENIES `touch -a`, OR A FILESYSTEM WHERE ATIME DOES NOT MOVE, is FIXTURE BROKEN (exit 2), never a
# skip: the control captures carry `R13-INSTRUMENT-REFUSED` and every control below reads that first.
#
# CONTROLS: the corpus write on world g, replay, moved named file, moved judge byte, red, overflow, not-run, untraced
# (function-level), the two-sided ceiling (c-stale-high, c-committed), the within-ceiling record and its replay
# (c-within-write, c-within), a DRIVEN instrument refusal (c-instr-refused, through the validator's documented test
# seam BR_R13_PROBE_DIR with a pre-placed unreadable `read`; no command is shadowed), the three states of a given
# --base (m1-base3), the replayed population figures (c-pop-live, c-replay-pop), and the CLI.
# The trustctime setting's effect across a second boundary is inferred from git's documented ctime granularity, not
# measured; the function-level seed proves only that the setting is applied.
#
# Usage: run.sh
# Exit:  0 = every control holds, 1 = one regressed, 2 = fixture broken.
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
unset BR_RECEIPTS_RUNNING BR_R13_RECORD_DIR BR_R13_PROBE_DIR

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
  v="$(sed -n 's/^RESTRICTED: verdict-rc=\([0-9][0-9]*\) -- this run was restricted and is never a gate pass$/\1/p' "$o" | tail -1)"
  case "$raw" in
    3) echo "${v:-none}" > "$o.rc" ;;
    2) echo 2 > "$o.rc" ;;
    *) echo "$raw" > "$o.rc"
       bad "restricted -- cell $id exited $raw, not the restricted 3 (or a refusal's 2)" ;;
  esac
}
has() { grep -qF -- "$2" "$1"; }
rcof() { cat "$1.rc" 2>/dev/null; }
klist() { sed -n 's/^R13-RECORD: WRITTEN BL-1401 (K=\([0-9a-f]*\))$/\1/p' "$1"; }
instr_refused() { has "$1" "R13-INSTRUMENT-REFUSED" && broken "atime is not a working read instrument here: $(grep -F R13-INSTRUMENT-REFUSED "$1" | head -1)"; return 0; }

# --- the cells: each reads one capture and returns 0 when GREEN ----------------------------
cell_c_write() { has "$1" "R13-POPULATION: 1 open sh receipt(s), 1 traced, 2 named removals (0 replayed), 0 named-unread (0 replayed), " && has "$1" "removals: 1 exit 9, 2 in the cannot-measure set, 0 UNGUARDED-READ" && [ -n "$(klist "$1")" ] && has "$1" "R13-RC 0"; }
cell_c_enumline() { has "$1" ", 0 enumerated excluded (0 replayed), "; }
cell_c_instr() { has "$1" "R13-INSTRUMENT: atime moved on a read and on a second read after a second reset"; }
cell_c_replay() { has "$1" ", 1 replayed, " && [ -z "$(klist "$1")" ] && has "$1" "R13-RC 0"; }
cell_c_moved() { [ -n "$(klist "$1")" ] && [ "$(klist "$1")" != "$2" ]; }
cell_red_fail() { has "$1" "FAIL: R13" && has "$1" "R13-RC 1" && has "$1" "1 UNGUARDED-READ"; }
cell_red_norecord() { [ -z "$(ls -A "$2")" ] && [ -z "$(klist "$1")" ]; }
cell_c_overflow() { [ "$(rcof "$1")" = 2 ] && has "$1" "R13-NAMED-OVERFLOW BL-1401 34"; }
cell_c_notrun() { has "$1" "R13-POPULATION: NOT RUN"; }
cell_c_untraced() { [ "$(cat "$1" 2>/dev/null)" = "1 0 0" ]; }
cell_c_stale_high() { has "$1" "R13-RC 1" && has "$1" "BELOW the ceiling of 2" && has "$1" "lower DEFAULT_MAX_R13 in scripts/validate-backlog-receipts.sh to 1"; }
UROW="$(printf 'UNGUARDED-READ\tBL-1401\tw/data.txt\texit=1')"
cell_c_within_write() { [ -n "$(klist "$1")" ] && has "$1" "$UROW" && has "$1" "R13-RC 0"; }
cell_c_within_replay() { has "$2" ", 1 replayed, " && has "$2" "$UROW" && has "$2" "R13-RC 0" \
  && has "$3" ", 1 replayed, " && has "$3" "$UROW" && has "$3" "FAIL: R13" && has "$3" "R13-RC 1"; }
# BR_R13_PROBE_DIR makes the run RESTRICTED too; an instrument refusal is a refusal, so it leaves through the
# restricted trap as 2 (never 0 or 3) with `RESTRICTED: verdict-rc=2`.
cell_c_instr_refused() { [ "$(cat "$1.raw" 2>/dev/null)" = 2 ] && has "$1" "R13-INSTRUMENT-REFUSED read-not-moved" \
  && has "$1" "RESTRICTED: verdict-rc=2 -- this run was restricted and is never a gate pass"; }
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
C="$TMP/cap"; mkdir -p "$C"
# c-m1-e2e: M1 THROUGH REAL WORKERS. World
# m, one tagged start: BL-1401 `bash w/never.sh` (absent at HEAD and at --base) reads EXCLUDED-DRIVER-ABSENT-AT-BASE;
# BL-1402's guarded driver and BL-1403's driver, removed, read driver-absent (R13-PASS) and BL-1402's guarded file
# exits 9; BL-1403's unguarded file is UNGUARDED-READ (within a ceiling of 1). A --score-one worker classifies the
# baselines and --r13-one workers the removals.
cell_c_m1_e2e() { has "$1" "R13-POPULATION: 3 open sh receipt(s), 3 traced, " && has "$1" ", 1 EXCLUDED-DRIVER-ABSENT-AT-BASE, 0 baseline-cm, " \
  && has "$1" "removals: 1 exit 9, 3 in the cannot-measure set, 1 UNGUARDED-READ" \
  && has "$1" "$(printf 'UNGUARDED-READ\tBL-1403\tw/ud.txt\texit=1')" && [ "$(rcof "$1")" = 0 ]; }
m1e2e_run() { # m1e2e_run <copy> <out> <cell>
  local w; w="$(world m)"; wcheck "$w"
  cli "$3" "$1" "$2" "$(store)" - --r13-drive corpus --traced-removal --max-unguarded 1 \
    --base "$(git -C "$w" rev-parse HEAD)" "$w/docs/backlog.md"
}
m1e2e_run "$D" "$C/m1e2e" c-m1-e2e
if cell_c_m1_e2e "$C/m1e2e"; then ok "c-m1-e2e -- real workers read an EXCLUDED driver, two guarded driver removals and one UNGUARDED-READ"
else bad "c-m1-e2e -- rc $(rcof "$C/m1e2e"): $(grep -E 'R13-POPULATION|UNGUARDED|FAIL' "$C/m1e2e" | tr '\n' ' ')"; fi

WG="$(world g)"; wcheck "$WG"; S1="$(store)"
cli c-write "$D" "$C/write" "$S1" - --r13-drive corpus --traced-removal "$WG/docs/backlog.md"
instr_refused "$C/write"
if cell_c_instr "$C/write"; then ok "c-instr -- the in-arm instrument probe ran and atime moved"; else bad "c-instr -- no R13-INSTRUMENT line"; fi
if cell_c_write "$C/write"; then ok "c-write -- R13 traced, removed 2 named reads (both guarded), and wrote one record"
else bad "c-write -- $(grep -E 'R13-POPULATION|R13-RC' "$C/write" | tr '\n' ' ')"; fi
if cell_c_enumline "$C/write"; then ok "c-enumline -- the population line prints the enumerated-excluded count"; else bad "c-enumline -- no enumerated count"; fi
K1="$(klist "$C/write")"
[ "$(ls -A "$S1" | grep -c '\.green$')" = 1 ] || bad "c-write -- the store holds $(ls -A "$S1" | grep -c '\.green$') records, want 1"

cli c-replay "$D" "$C/replay" "$S1" - --r13-drive corpus --traced-removal "$WG/docs/backlog.md"
if cell_c_replay "$C/replay"; then ok "c-replay -- an unmoved key replayed: no removal, no new record"
else bad "c-replay -- $(grep -E 'R13-POPULATION|R13-RC|R13-RECORD' "$C/replay" | tr '\n' ' ')"; fi

WGJ="$(world g)"; wcheck "$WGJ"; SJ="$(store)"; cp "$S1"/*.green "$SJ/" 2>/dev/null
mkdist "$TMP/distj" "$D" || broken "the moved-judge copy did not build"
printf '# a moved judge byte\n' >> "$TMP/distj/scripts/validate-backlog-receipts.sh"
cli c-moved-judge "$TMP/distj/scripts/validate-backlog-receipts.sh" "$C/judge" "$SJ" - --r13-drive corpus --traced-removal "$WGJ/docs/backlog.md"
if cell_c_moved "$C/judge" "$K1"; then ok "c-moved-judge -- one changed byte of the judge moved the key and R13 re-ran"
else bad "c-moved-judge -- K '$(klist "$C/judge")' against '$K1'"; fi

printf 'moved\n' >> "$WG/w/data.txt"
git -C "$WG" -c commit.gpgsign=false commit -q -am moved >/dev/null 2>&1 || broken "the moved-named commit did not build"
cli c-moved-named "$D" "$C/moved" "$S1" - --r13-drive corpus --traced-removal "$WG/docs/backlog.md"
if cell_c_moved "$C/moved" "$K1"; then ok "c-moved-named -- a changed NAMED file moved the key and R13 re-ran"
else bad "c-moved-named -- K '$(klist "$C/moved")' against '$K1'"; fi

SU="$(store)"
cli red "$D" "$C/red" "$SU" - --r13-drive corpus --traced-removal "$(world u)/docs/backlog.md"
if cell_red_fail "$C/red"; then ok "red-fail -- an unguarded named read is UNGUARDED-READ over a ceiling of 0"
else bad "red-fail -- $(grep -E 'R13-POPULATION|R13-RC|FAIL' "$C/red" | tr '\n' ' ')"; fi
if cell_red_norecord "$C/red" "$SU"; then ok "red-norecord -- a red R13 wrote no record (store empty before and after)"; else bad "red-norecord -- the store holds: $(ls -A "$SU" | tr '\n' ' ')"; fi

cli overflow "$D" "$C/over" "$(store)" - --r13-drive corpus --traced-removal "$(world o)/docs/backlog.md"
if cell_c_overflow "$C/over"; then ok "c-overflow -- 34 named reads printed R13-NAMED-OVERFLOW and refused"
else bad "c-overflow -- rc $(rcof "$C/over"): $(grep -E 'R13-' "$C/over" | tr '\n' ' ')"; fi

cli notrun "$D" "$C/notrun" "$(store)" - --r13-drive corpus "$(world g)/docs/backlog.md"
if cell_c_notrun "$C/notrun"; then ok "c-notrun -- without --traced-removal R13 says NOT RUN"; else bad "c-notrun -- no NOT RUN line"; fi
# c-restricted: a restricted start whose verdict is GREEN exits 3, never 0, and says its verdict.
cell_c_restricted() { [ "$(cat "$1.raw" 2>/dev/null)" = 3 ] && has "$1" "RESTRICTED: verdict-rc=0 -- this run was restricted and is never a gate pass"; }
if cell_c_restricted "$C/notrun"; then ok "c-restricted -- a restricted start with a green verdict exited 3, not 0, and printed verdict-rc=0"
else bad "c-restricted -- raw exit $(cat "$C/notrun.raw" 2>/dev/null): $(grep -F 'RESTRICTED:' "$C/notrun" | tr '\n' ' ')"; fi

untraced_fn "$D" "$C/untraced"
if cell_c_untraced "$C/untraced"; then ok "c-untraced -- r13_untraced reads 1 untraced, then 0 when traced, then 0 when R2 refused it before a checkout"
else bad "c-untraced -- read '$(cat "$C/untraced")', want '1 0 0'"; fi

# THE TWO-SIDED CEILING. c-stale-high: world u (1 unguarded row) under a ceiling of 2 FAILS with the lower-it message;
# the equal case is c-within-write below, and the above case is red-fail above.
cli c-stale-high "$D" "$C/stale" "$(store)" - --r13-drive corpus --traced-removal --max-unguarded 2 "$(world u)/docs/backlog.md"
if cell_c_stale_high "$C/stale"; then ok "c-stale-high -- a live count below the ceiling failed and named the count to lower it to"
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
cli c-committed "$D" "$C/committed" "$(store)" - --r13-drive corpus --traced-removal --max-unguarded "$N_COMMITTED" "$WF/docs/backlog.md"
if has "$C/committed" "R13-RC 0" && has "$C/committed" "$N_COMMITTED UNGUARDED-READ (ceiling $N_COMMITTED)"; then
  ok "c-committed -- a world with exactly the committed $N_COMMITTED unguarded reads passes at that ceiling"
else bad "c-committed -- $(grep -E 'R13-POPULATION|R13-RC|FAIL: R13' "$C/committed" | tr '\n' ' ')"; fi

# THE CEILING WITH NOTHING TO COUNT. c-empty-stale: an EMPTY open sh population (world n, `verify: manual` only) under a
# ceiling of 1 fails stale-high and names 0. c-nothing-judged: world x's one receipt is baseline cannot-measure (its
# driver was deleted on HEAD and --base has it), so nothing is judged; under a ceiling of 1 the run fails saying
# NOTHING WAS JUDGED, never "BELOW the ceiling".
cell_c_empty_stale() { [ "$(rcof "$1")" = 1 ] && has "$1" "R13-POPULATION: EMPTY" && has "$1" "the open sh population is EMPTY, so the live UNGUARDED-READ count is 0, BELOW the ceiling of 1" && has "$1" "to 0"; }
cell_c_nothing_judged() { [ "$(rcof "$1")" = 1 ] && has "$1" "FAIL: R13: NOTHING WAS JUDGED -- 0 of 1 traced" && ! has "$1" "BELOW the ceiling"; }
empty_run() { cli "$1" "$2" "$3" "$(store)" - --r13-drive corpus --traced-removal --max-unguarded 1 "$(world n)/docs/backlog.md"; }
judged_run() { # judged_run <cell> <copy> <out>
  local w; w="$(world x)"; wcheck "$w"
  cli "$1" "$2" "$3" "$(store)" - --r13-drive corpus --traced-removal --max-unguarded 1 --base "$(cat "$w/.git/fx-base")" "$w/docs/backlog.md"
}
empty_run c-empty-stale "$D" "$C/empty"
if cell_c_empty_stale "$C/empty"; then ok "c-empty-stale -- an EMPTY population under a ceiling of 1 failed and named 0"
else bad "c-empty-stale -- verdict $(rcof "$C/empty"): $(grep -E 'R13-POPULATION|FAIL: R13' "$C/empty" | tr '\n' ' ')"; fi
judged_run c-nothing-judged "$D" "$C/judged"
if cell_c_nothing_judged "$C/judged"; then ok "c-nothing-judged -- a run that judged nothing under a ceiling of 1 failed saying NOTHING WAS JUDGED"
else bad "c-nothing-judged -- verdict $(rcof "$C/judged"): $(grep -E 'R13-POPULATION|FAIL: R13' "$C/judged" | tr '\n' ' ')"; fi

# pop_run <copy> <prefix> <id-prefix> -- world e (2 named removals, 1 named-unread, 1 enumerated), one store: a live
# write, then its replay. c-replay-pop: the replay prints the live run's figures, labelled replayed.
pop_run() {
  local s w; s="$(store)"; w="$(world e)"; wcheck "$w"
  cli "$3-1" "$1" "$2.1" "$s" - --r13-drive corpus --traced-removal "$w/docs/backlog.md"
  cli "$3-2" "$1" "$2.2" "$s" - --r13-drive corpus --traced-removal "$w/docs/backlog.md"
}
pop_run "$D" "$C/pop" pop
if cell_c_pop_live "$C/pop.1"; then ok "c-pop-live -- the live run printed 2 named removals, 1 named-unread and 1 enumerated excluded"
else bad "c-pop-live -- $(grep -E 'R13-POPULATION|R13-RC' "$C/pop.1" | tr '\n' ' ')"; fi
if cell_c_replay_pop "$C/pop.1" "$C/pop.2"; then ok "c-replay-pop -- the replay re-printed the live run's population figures, labelled replayed"
else bad "c-replay-pop -- $(grep -E 'R13-POPULATION' "$C/pop.2" | tr '\n' ' ')"; fi

# within_run <copy> <prefix> <id-prefix> -- world u, one store, three starts: write at ceiling 1, replay at 1, replay at 0.
within_run() {
  local s w; s="$(store)"; w="$(world u)"; wcheck "$w"
  cli "$3-1" "$1" "$2.1" "$s" - --r13-drive corpus --traced-removal --max-unguarded 1 "$w/docs/backlog.md"
  cli "$3-2" "$1" "$2.2" "$s" - --r13-drive corpus --traced-removal --max-unguarded 1 "$w/docs/backlog.md"
  cli "$3-3" "$1" "$2.3" "$s" - --r13-drive corpus --traced-removal --max-unguarded 0 "$w/docs/backlog.md"
}
within_run "$D" "$C/within" within
if cell_c_within_write "$C/within.1"; then ok "c-within-write -- an UNGUARDED-READ within the ceiling wrote the record"
else bad "c-within-write -- $(grep -E 'R13-POPULATION|R13-RC|R13-RECORD' "$C/within.1" | tr '\n' ' ')"; fi
if cell_c_within_replay "$C/within.1" "$C/within.2" "$C/within.3"; then ok "c-within -- its replay re-printed the stored row, passed at ceiling 1 and failed at ceiling 0"
else bad "c-within -- replay at 1: $(grep -E 'R13-RC' "$C/within.2" | tr '\n' ' ') replay at 0: $(grep -E 'R13-RC|FAIL: R13' "$C/within.3" | tr '\n' ' ')"; fi

# c-instr-refused, through the documented seam BR_R13_PROBE_DIR: its `read` is pre-placed at mode 0200, so the probe's
# cat cannot open it and its atime stays at the epoch. No command is shadowed.
AG="$TMP/aged-probe"; mkdir -p "$AG" && printf 'r\n' > "$AG/read" && chmod 0200 "$AG/read" || broken "the aged probe dir did not build"
cli c-instr-refused "$D" "$C/irefused" "$(store)" "BR_R13_PROBE_DIR=$AG" --r13-drive corpus --traced-removal "$(world g)/docs/backlog.md"
if cell_c_instr_refused "$C/irefused"; then ok "c-instr-refused -- an atime that did not move on a read refused R13 (exit 2)"
else bad "c-instr-refused -- rc $(rcof "$C/irefused"): $(grep -E 'R13-INSTRUMENT' "$C/irefused" | tr '\n' ' ')"; fi

# m1-base3: three states of a GIVEN --base. (i) and (ii) are vbr_sec_setup alone (in process); (iii) scores world x.
WX="$(world x)"; wcheck "$WX"; XB="$(cat "$WX/.git/fx-base")"
base_setup "$D" "$C/base3.1" "$XB" "$WX/docs/backlog.md"
base_setup "$D" "$C/base3.2" refs/heads/no-such-base-zz "$WX/docs/backlog.md"
cli base3-3 "$D" "$C/base3.3" "$(store)" - --r13-drive score --base "$XB" "$WX/docs/backlog.md"
if cell_m1_base3 "$C/base3.1" "$C/base3.2" "$C/base3.3"; then ok "m1-base3 -- a resolving --base passes, an unresolvable one refuses with M1-BASE-UNRESOLVED (exit 2), and a removed driver reads DRIVER-REMOVED"
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
   && has "$C/cli" "R13-RECORD: WRITTEN BL-1401"; then
  ok "cli-wire -- the CLI with --traced-removal ran R13 end to end and wrote its record"
else bad "cli-wire -- rc $(rcof "$C/cli"): $(grep -E 'R13-|FAIL' "$C/cli" | head -5 | tr '\n' ' ')"; fi


# THE CELLS THIS RUN TAGGED ARE THE ONES cells.decl DECLARES, EACH ONCE (the judge's C3, predicted here). One cmp of
# the sorted lists decides both: cells.decl declares each id once (the parse refuses a duplicate), so a cell tagged
# twice is a second line on the used side and the two files differ. No separate duplicate test.
sort "$CELLS_USED" > "$TMP/cells.used.s"
sed -n 's/^cli scripts\/validate-backlog-receipts\.sh \([A-Za-z0-9_.-]*\)$/\1/p' "$FX/cells.decl" | sort > "$TMP/cells.decl.s"
if cmp -s "$TMP/cells.used.s" "$TMP/cells.decl.s"; then
  ok "cells -- the $(grep -c . "$TMP/cells.used.s") tagged starts are exactly the cli cells of cells.decl, each once"
else bad "cells -- tagged and declared differ: $(diff "$TMP/cells.decl.s" "$TMP/cells.used.s" | grep '^[<>]' | tr '\n' ' ')"; fi

if [ "$FAILS" -ne 0 ]; then echo "$NAME: $FAILS failure(s)"; exit 1; fi
echo "PASS: $NAME"
exit 0
