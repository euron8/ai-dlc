#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# readset-stage1-verdict -- drive scripts/readset-stage1-verdict.sh (the stage-1 scorer) and
# scripts/readset-stage1-run.sh (the stage-1 run wrapper) over SEEDED worlds, and kill a mutant of
# every arm, refusal and wrapper property they claim.
#
# WHY THE SEEDED ALL-MET WORLD IS THE CENTRE OF THIS FILE. Stage 1 has never been met on real data,
# so the MET verdict has never fired anywhere. A scorer that can only refuse or report NOT-MET reads
# exactly like one that has simply not seen three good runs yet. The ALL-MET world below is the only
# evidence that MET can fire, and every mutant is required to still score it MET (its liveness
# arm), so a copy that died on a syntax error cannot score as a kill.
#
# EVERY WORLD IS THE ALL-MET BASE PLUS ONE EDIT, and a NOT-MET world is asserted on the EXACT set
# of (run, subject, arm) tuples it prints, never on arm IDs alone: a substring name match in A1/A5
# emits the SAME arm id on one EXTRA subject, which an arm-id assertion cannot see. A refusal world
# is asserted on exit 2 plus its reason text, because R2's string-compare mutant still refuses the
# symlinked world -- for a different reason, which only the message shows.
#
# TWO ARMS CANNOT FAIL ALONE IN THE DERIVER'S REAL SHAPE, AND ARE ISOLATED DELIBERATELY. The deriver
# prints `<fx> OMITTED (...)` INSTEAD OF `<fx> <n> paths` (:1037/:1041), so a real A1 always drags
# A5 with it, and A3's `LOSS CANARY: unreadable` clause needs an OMITTED line, so it drags A1. The A1
# world keeps the paths line and adds the OMITTED line; the unreadable-canary world is asserted as
# the A1+A3 pair it really is, and the 1-line `.canary` world carries A3 alone.
#
# MUTANTS ARE BUILT FROM A SCRATCH COPY, never the tree. A scorer mutant is built from a CONTROL copy
# whose `self_probe` call is disabled -- otherwise most arm deletions would die at exit 2 inside the
# scorer's own self-probe, which proves the probe and not these worlds. The control copy must agree
# with the shipping scorer on every world. Each mutation must replace exactly one line, and the copy
# must differ from its source (`cmp -s` non-zero), or the mutant is reported DID NOT APPLY.
#
# IN PROCESS, ONE END-TO-END RUN PER CLI OUTCOME. Both subjects carry a BASH_SOURCE guard over sections that are
# functions (scorer: stage1_entry, stage1_score; wrapper: stage1_preflight .. stage1_launch, sample, finish). Every
# world and every mutant is asked in process -- the copy sourced in a subshell, the section called -- and the CLI
# runs as a process only once per distinct outcome: the scorer's MET/NOT-MET/REFUSED (the equivalence cell, which
# also proves the two paths byte-identical) and --self-probe; the wrapper's exit 0, 1, 143 (TERM), 137 (SIGKILL)
# and one exit-2 refusal.
#
# THE WRAPPER IS DRIVEN AGAINST A STUB DERIVER in a fresh scratch repo per arm: the wrapper runs
# `<root>/core/scripts/derive-fixture-readsets.sh` from the root it walks up to, so the stub sits at
# that path. The stub REWRITES the map and leaves a copy of what it wrote, so the restore arm is
# shown to be load-bearing rather than restoring a map nothing touched.
#
# CWD-INVARIANCE IS ASSERTED HERE, not inherited from how the suite is driven: the scorer's output
# on two worlds is byte-compared across three working directories, one a dirty decoy repo, and the
# wrapper's ok run is driven from inside that decoy.
#
# The mutant matrix: outside its declared decides set, each mutant co-trips no other arm, measured at authoring; a
# twins=- row is dead in every cell by construction, as its why= states. Per push a mutant drives its
# deciding cell(s) and one named twin that the matrix shows green for it. The matrix is re-measured whenever
# an arm or a mutant is added or changed.
#
# MUTANT-MATRIX del-A1 decides=a1,a3u twins=met
# MUTANT-MATRIX del-A2 decides=a2 twins=met
# MUTANT-MATRIX del-A3 decides=a3,a3u twins=met
# MUTANT-MATRIX del-A4 decides=a4,a4-after twins=met
# MUTANT-MATRIX del-A5 decides=a5,a5n twins=met
# MUTANT-MATRIX del-A6 decides=a6,a6-gitignore,a6-owntree,a6-p2,a6-dir twins=met
# MUTANT-MATRIX a6-owntree decides=a6-owntree twins=met
# MUTANT-MATRIX a6-caret-git decides=a6-gitignore twins=met
# MUTANT-MATRIX a1-substring decides=a1,a3u twins=met
# MUTANT-MATRIX a5-substring decides=a5 twins=met
# MUTANT-MATRIX a2-reads-log decides=a2 twins=met
# MUTANT-MATRIX a4-whole-file decides=a4,a4-after twins=met
# MUTANT-MATRIX del-R0 decides=r0-log,r0-sb,r0-profile twins=met
# MUTANT-MATRIX r2-string decides=r2-link twins=met
# MUTANT-MATRIX rl-skip decides=rl-rc,rl-skip twins=met
# MUTANT-MATRIX rl-skip-started decides=rl-started,rl-foreign twins=met
# MUTANT-MATRIX a2-ending decides=a2 twins=met
# MUTANT-MATRIX a4-open-end decides=a4-after twins=met
# MUTANT-MATRIX a6-regular-file decides=a6-dir twins=met
# MUTANT-MATRIX r0-no-profile decides=r0-profile twins=met
# MUTANT-MATRIX r6-paths-only decides=r6-omitted twins=met
# MUTANT-MATRIX r2-first-only decides=r2-one twins=met
# MUTANT-MATRIX rl-pair-unchecked decides=rl-foreign,rl-epoch,rl-head twins=met
# MUTANT-MATRIX rl-pair-no-epoch decides=rl-epoch twins=met
# MUTANT-MATRIX rl-pair-no-head decides=rl-head twins=met
# MUTANT-MATRIX probe-owntree decides=selfprobe twins=- why=dead in every cell: the mutated scorer's own self-probe refuses before any world is scored, so every world cell reads 1 (all printed in the matrix log)
# MUTANT-MATRIX probe-a2-ending decides=selfprobe twins=- why=dead in every cell: the mutated scorer's own self-probe refuses before any world is scored, so every world cell reads 1 (all printed in the matrix log)
# MUTANT-MATRIX probe-a4-open-end decides=selfprobe twins=- why=dead in every cell: the mutated scorer's own self-probe refuses before any world is scored, so every world cell reads 1 (all printed in the matrix log)
# MUTANT-MATRIX probe-a6-regular-file decides=selfprobe twins=- why=dead in every cell: the mutated scorer's own self-probe refuses before any world is scored, so every world cell reads 1 (all printed in the matrix log)
# MUTANT-MATRIX probe-r0-no-profile decides=selfprobe twins=- why=dead in every cell: the mutated scorer's own self-probe refuses before any world is scored, so every world cell reads 1 (all printed in the matrix log)
# MUTANT-MATRIX probe-r6-paths-only decides=selfprobe twins=- why=dead in every cell: the mutated scorer's own self-probe refuses before any world is scored, so every world cell reads 1 (all printed in the matrix log)
# MUTANT-MATRIX probe-r2-first-only decides=selfprobe twins=- why=dead in every cell: the mutated scorer's own self-probe refuses before any world is scored, so every world cell reads 1 (all printed in the matrix log)
# MUTANT-MATRIX probe-rl-no-pairing decides=selfprobe twins=- why=dead in every cell: the mutated scorer's own self-probe refuses before any world is scored, so every world cell reads 1 (all printed in the matrix log)
# MUTANT-MATRIX probe-rl-pair-unchecked decides=selfprobe twins=- why=dead in every cell: the mutated scorer's own self-probe refuses before any world is scored, so every world cell reads 1 (all printed in the matrix log)
# MUTANT-MATRIX load-under-root decides=sample twins=profile
# MUTANT-MATRIX load-5min decides=sample twins=profile
# MUTANT-MATRIX profile-passed-through decides=profile twins=sample
# MUTANT-MATRIX no-started-line decides=started twins=sample
# MUTANT-MATRIX no-orphan-check decides=orphan-live twins=orphan-dead
# MUTANT-MATRIX no-restore decides=restore twins=groupkill
# MUTANT-MATRIX single-pid-kill decides=groupkill twins=restore
# MUTANT-MATRIX pk-bare decides=pk-site1,pk-site2 twins=clause-count
# MUTANT-MATRIX pk-wrong-parent decides=pk-site1,pk-site2 twins=clause-count
# MUTANT-MATRIX sb-one-emitter decides=clause-count twins=pk-sites
# MUTANT-MATRIX og-pass decides=og-stall twins=og-reaped
# MUTANT-MATRIX-DYNAMIC smut why=every scorer-mutant name reaches mutant_killed as a variable; each name carries its own row above
# MUTANT-MATRIX-DYNAMIC pmut why=every self-probe mutant name reaches mutant_killed as a variable; each carries its own row above
# MUTANT-MATRIX-DYNAMIC wmut why=every wrapper-mutant name reaches mutant_killed as a variable; each carries its own row above
# MUTANT-MATRIX-DYNAMIC pkmut why=each pkill-reaping mutant name reaches mutant_killed as a variable; each carries its own row above
# MUTANT-MATRIX-REMEASURE bash core/fixtures/readset-stage1-verdict/run.sh --matrix
#
# Usage: run.sh            the per-push run (mode PUSH)
#        run.sh --matrix   the full mutant x cell matrix (mode FULL), measured at authoring
# Exit:  0 = every arm and mutant holds, 1 = one regressed, 2 = fixture broken.
set -u

MATRIX=0
[ "${1:-}" = --matrix ] && MATRIX=1
MCELLS=0
if [ "$MATRIX" = 1 ]; then echo "readset-stage1-verdict: mode FULL (--matrix)"; else echo "readset-stage1-verdict: mode PUSH"; fi

# Every ambient AI_DLC_* key is cleared (I10/I87): the subjects read AI_DLC_READSET_STAGE1_LEDGER,
# and an inherited one would point them at the operator's ledger. Each arm passes its own.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd -P)"
ROOT="$HERE"
while [ "$ROOT" != "/" ] && [ ! -f "$ROOT/scripts/readset-stage1-verdict.sh" ]; do ROOT="$(dirname "$ROOT")"; done
SCORER="$ROOT/scripts/readset-stage1-verdict.sh"
WRAPPER="$ROOT/scripts/readset-stage1-run.sh"
[ -f "$SCORER" ] && [ -f "$WRAPPER" ] || { echo "FIXTURE BROKEN: no scripts/readset-stage1-{verdict,run}.sh above $HERE" >&2; exit 2; }
echo "HERMETIC-CONSUMED $SCORER"
echo "HERMETIC-CONSUMED $WRAPPER"
# The wrapper's own terminal word for a TERMed run, read from the wrapper rather than restated: the
# arms below assert the ledger and RUN_DIR/rc carry exactly what the wrapper writes.
KILLTOK="$(awk 'match($0, /; RC="[a-z]+";/) { print substr($0, RSTART + 6, RLENGTH - 8); exit }' "$WRAPPER")"
[ -n "$KILLTOK" ] || { echo "FIXTURE BROKEN: no RC=\"<word>\" terminal assignment in $WRAPPER" >&2; exit 2; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/readset-stage1-fx.XXXXXX")" || { echo "FIXTURE BROKEN: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd -P)"
ORPHANS="$WORK/orphans"; : > "$ORPHANS"
reap() { local p; [ -f "$ORPHANS" ] || return 0; while IFS= read -r p; do case "$p" in ''|*[!0-9]*) ;; *) kill "$p" 2>/dev/null ;; esac; done < "$ORPHANS"; }
trap reap EXIT

FAILS=0; ASSERTS=0
ok()     { printf '  ok    %s\n' "$1"; ASSERTS=$((ASSERTS + 1)); }
bad()    { printf '  FAIL  %s\n' "$1"; FAILS=$((FAILS + 1)); ASSERTS=$((ASSERTS + 1)); }
broken() { echo "readset-stage1-verdict: FIXTURE BROKEN: $*" >&2; echo "  (work kept at $WORK)" >&2; exit 2; }
MUT_LIB="$HERE/../lib/mutant.sh"
[ -f "$MUT_LIB" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $HERE" >&2; exit 2; }
. "$MUT_LIB"
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"
echo "readset-stage1-verdict:"

SUBJ="enforcement-map-sites enforcement-map-sites-b enforcement-map-sites-c validator-arm-selection validator-arm-selection-b"
T0=1790000000   # 2026-09-21, nowhere near a DST boundary in any zone the deriver runs in
gitc() { git -c user.name=fx -c user.email=fx@example.invalid -c commit.gpgsign=false "$@"; }

# ------------------------------------------------------------------ scorer worlds ----
# The tree every run's root/t copies: a real git repository, because R4 reads its HEAD.
TPL="$WORK/tpl"
mkdir -p "$TPL/.githooks" "$TPL/d" || broken "cannot build the template tree"
( cd "$TPL" && git init -q . ) || broken "git init failed for the template tree"
printf 'x\n' > "$TPL/present1"; printf 'x\n' > "$TPL/.gitignore"; printf 'x\n' > "$TPL/.githooks/pre-push"; printf 'x\n' > "$TPL/d/p"
for fx in $SUBJ; do mkdir -p "$TPL/core/fixtures/$fx"; printf 'x\n' > "$TPL/core/fixtures/$fx/run.sh"; done
( cd "$TPL" && git add -A && gitc commit -qm tpl ) || broken "template commit failed"
TPL_SHA="$(git -C "$TPL" rev-parse HEAD)" || broken "template has no HEAD"
[ -d "$TPL/.git" ] || broken "the template is not a repository"

ts() { date -r "$1" '+%Y-%m-%d %H:%M:%S'; }

# THE SANDBOX PROFILE IS SEEDED FROM THE PRODUCER. R0 compares root/w/sandbox.sb byte for byte with
# the scorer's copy of the deriver's default-profile `printf`, so every run here carries a profile
# rendered from the format the DERIVER writes, extracted from its own line, and the scorer's copy is
# required to be the same bytes. A drift in either file fails here rather than at a real run.
DERIVER="$ROOT/core/scripts/derive-fixture-readsets.sh"
[ -f "$DERIVER" ] || broken "no deriver at $DERIVER"
fmt_of() { # $1 file  $2 a fixed string the format line must also carry
  awk -v k="$2" 'index($0, "printf '"'"'(version 3)") && index($0, k) {
      s = substr($0, index($0, "'"'"'") + 1); print substr(s, 1, index(s, "'"'"'") - 1) }' "$1"
}
DFMT="$(fmt_of "$DERIVER" '"$TREE" "$MARKDIR" "$TREE" > "$PROFILE"')"
SFMT="$(fmt_of "$SCORER" '"$1/t" "$1/m" "$1/t"')"
n="$(printf '%s\n' "$DFMT" | grep -c 'with report')" || n=0
[ "$n" = 1 ] || broken "the deriver carries $n default-profile printf line(s) with a report clause, not 1"
case "$DFMT" in *'(subpath "%s") (subpath "%s") (with report))\n(allow file-read-metadata file-test-existence (literal "%s"))\n') ;; *) broken "the deriver's default-profile format is not the two-subpath shape ending in the root-literal clause (BL-470): $DFMT" ;; esac
[ "$DFMT" = "$SFMT" ] || broken "the scorer's default-profile format differs from the deriver's: [$SFMT] vs [$DFMT]"

# relog <rd>: the deriver.log in real shape, its per-fixture counts taken from the .set files.
relog() {
  local rd="$1" rp fx
  rp="$(cd "$rd/root" && pwd -P)"
  {
    echo "[00:10:00] sandbox tracer: fixtures run as 'fx' under sandbox-exec; no root anywhere"
    echo "[00:10:01] copying the tree to $rp/t"
    for fx in $SUBJ; do printf '  %-32s %5s paths\n' "$fx" "$(grep -c . "$rd/root/w/$fx.set")"; done
  } > "$rd/deriver.log"
}

# seed_run <rd> <i>: one run in the deriver's real layout, window [base+10, base+51].
seed_run() {
  local rd="$1" i="$2" base fx s e rp
  base=$((T0 + i * 1000))
  mkdir -p "$rd/root/w" "$rd/root/m" || return 1
  cp -R "$TPL" "$rd/root/t" || return 1
  rp="$(cd "$rd/root" && pwd -P)" || return 1
  printf "$DFMT" "$rp/t" "$rp/m" "$rp/t" > "$rd/root/w/sandbox.sb"
  printf 'a\0b\0' > "$rd/root/w/copy.list"
  s="$(ts $((base + 10)))"; e="$(ts $((base + 50)))"
  for fx in $SUBJ; do
    {
      echo "Filtering the log data using \"sender == \"Sandbox\" AND composedMessage CONTAINS \"/x/\"\""
      echo "Timestamp               Ty Process[PID:TID]"
      echo "$s.313 Df kernel[0:1] (Sandbox) Sandbox: cat(1) allow file-read-data /x/m/.readset-sentinel"
      echo "$s.900 Df kernel[0:1] (Sandbox) Sandbox: bash(2) allow file-read-data /x/t/run$i-$fx"
      echo "$e.832 Df kernel[0:1] (Sandbox) Sandbox: cat(3) allow file-test-existence /x/m/.readset-end"
    } > "$rd/root/w/$fx.raw"
    : > "$rd/root/w/$fx.win"; : > "$rd/root/w/$fx.canary"
    printf 'core/fixtures/%s/run.sh\npresent1\n.gitignore\n.githooks/pre-push\n' "$fx" > "$rd/root/w/$fx.set"
  done
  printf '0\n' > "$rd/rc"
  printf '%s\t1.00\n%s\t5.00\n%s\t1.00\n' $((base - 5)) $((base + 20)) $((base + 70)) > "$rd/load.tsv"
  relog "$rd"
}
# The wrapper's two ledger lines per run: `started` before the launch, the terminal at the end.
lpair() { printf '%s\tstarted\t%s\t%s\n%s\t%s\t%s\t%s\t%s\n' "$1" "$3" "$TPL_SHA" "$1" "$2" "$3" "$4" "$TPL_SHA"; }
lstarted() { printf '%s\tstarted\t%s\t%s\n' "$1" "$2" "$TPL_SHA"; }
lline() { local base=$((T0 + $2 * 1000)); lpair "$1" "${3:-0}" "$base" $((base + 60)); }

# mkworld <name>: three runs and their ledger. Prints the world dir.
mkworld() {
  local w="$WORK/w/$1" i
  mkdir -p "$w/tmp" || return 1
  for i in 1 2 3; do seed_run "$w/r$i" "$i" || return 1; done
  { lline "$w/r1" 1; lline "$w/r2" 2; lline "$w/r3" 3; } > "$w/ledger"
  printf '%s\n' "$w"
}
w_of() { printf '%s\n' "$WORK/w/$1"; }

# log_sub <log> <substring> <replacement line>; log_del_paths <log> <fx>
log_sub() { ENV_OLD="$2" ENV_NEW="$3" awk 'index($0, ENVIRON["ENV_OLD"]) { print ENVIRON["ENV_NEW"]; next } { print }' "$1" > "$1.new" && mv "$1.new" "$1"; }
log_del_paths() { awk -v f="$2" '!($1 == f && $3 == "paths")' "$1" > "$1.new" && mv "$1.new" "$1"; }

# score_in <scorer copy> <world> <cwd> [probe]: the scoring the CLI runs, ASKED IN PROCESS. The copy is sourced in a
# subshell (its BASH_SOURCE guard keeps the CLI body from running; its own `set -uo pipefail` stays inside the
# subshell, as it is inside the CLI) and stage1_score is called -- the function the CLI calls after its self-probe.
# `probe` runs stage1_entry first, the self-probe path the CLI takes. A per-cell subshell rather than one top-level
# source: the scorer defines a seed_run of its own that would replace this file's, and every mutant is its own copy.
score_in() {
  ( cd "$3" || exit 2
    TMPDIR="$2/tmp"; AI_DLC_READSET_STAGE1_LEDGER="$2/ledger"; export TMPDIR AI_DLC_READSET_STAGE1_LEDGER
    . "$1" || exit 2
    [ "${4:-}" = probe ] && stage1_entry
    stage1_score ) 2>&1
}
# score_cli <scorer> <world> <cwd>: the same question through the CLI, for the equivalence cell and one run per outcome.
score_cli() { ( cd "$3" && TMPDIR="$2/tmp" AI_DLC_READSET_STAGE1_LEDGER="$2/ledger" bash "$1" 2>&1 ); }
# verdict <scorer> <world> [cwd] [probe|cli] -> `rc|spec`. spec: MET / sorted tuples / the refusal line.
verdict() {
  local s="$1" w="$2" cwd="${3:-$WORK}" out rc
  if [ "${4:-}" = cli ]; then out="$(score_cli "$s" "$w" "$cwd")"; rc=$?
  else out="$(score_in "$s" "$w" "$cwd" "${4:-}")"; rc=$?; fi
  printf '%s\n' "$out" > "$w/raw.$(basename "$s")"
  case "$rc" in
    0) case "$out" in MET:*) printf '0|MET\n' ;; *) printf '0|?%s\n' "$out" ;; esac ;;
    1) printf '1|%s\n' "$(printf '%s\n' "$out" | awk '$1 == "NOT-MET" {
           l = $2; sub(/\(.*$/, "", l)
           if ($4 ~ /^A[0-9]:$/) { a = $4; sub(/:$/, "", a); print l " " $3 " " a }
           else if ($3 ~ /^A[0-9]:$/) { a = $3; sub(/:$/, "", a); if (a == "A6") print "- " l " " a; else print l " - " a } }' \
         | LC_ALL=C sort | tr '\n' ';')" ;;
    *) printf '%s|%s\n' "$rc" "$(printf '%s\n' "$out" | head -1)" ;;
  esac
}
tuples() { local t; for t in "$@"; do printf '%s\n' "$t"; done | LC_ALL=C sort | tr '\n' ';'; }

# matches <got> <want-rc> <want-spec>: rc 2 matches the reason by substring, the rest exactly.
matches() {
  case "$1" in "$2|"*) ;; *) return 1 ;; esac
  if [ "$2" = 2 ]; then case "${1#*|}" in *"$3"*) return 0 ;; *) return 1 ;; esac; fi
  [ "${1#*|}" = "$3" ]
}

# THE WORLD TABLE: name, expected rc, expected spec. Built below, one edit each.
TABLE="$WORK/table"; : > "$TABLE"
want() { printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$TABLE"; }

W="$(mkworld met)" || broken "cannot seed the ALL-MET world"
want met 0 MET

# RL -- the ledger line resolves.
W="$(mkworld rl-short)" || broken seed; head -4 "$W/ledger" > "$W/l2"; mv "$W/l2" "$W/ledger"
want rl-short 2 "holds 4 line(s)"
W="$(mkworld rl-format)" || broken seed; { head -4 "$W/ledger"; lstarted "$W/r3" $((T0 + 3000)); printf '%s\t0\t%s\n' "$W/r3" $((T0 + 3000)); } > "$W/l3"; mv "$W/l3" "$W/ledger"
want rl-format 2 "RL ledger line 6 of the last six is not"
# A `kill -9` of the wrapper: a started line with no terminal, BETWEEN runs 1 and 2. The six-line
# tail holds it; a scorer that skipped it would score three non-consecutive runs MET.
W="$(mkworld rl-started)" || broken seed; { lline "$W/r1" 1; lstarted "$W/k9" $((T0 + 1500)); lline "$W/r2" 2; lline "$W/r3" 3; } > "$W/ledger"
want rl-started 2 "RL ledger line 2 of the last six: $W/k9 started at $((T0 + 1500)) and recorded no terminal line"
# Near-miss: the same killed run OLDER than the last three pairs does not block, as an older
# `killed` terminal does not (rl-skip).
W="$(mkworld rl-started-old)" || broken seed; { lstarted "$W/k9" $((T0 + 500)); lline "$W/r1" 1; lline "$W/r2" 2; lline "$W/r3" 3; } > "$W/ledger"
want rl-started-old 0 MET
# A terminal with no started line before it (a pre-started-line ledger, or a hand-appended line).
W="$(mkworld rl-nostart)" || broken seed; { lline "$W/r0" 0; lline "$W/r1" 1; lline "$W/r2" 2; printf '%s\t0\t%s\t%s\t%s\n' "$W/r3" $((T0 + 3000)) $((T0 + 3060)) "$TPL_SHA"; } > "$W/ledger"
want rl-nostart 2 "RL ledger line 6 of the last six: the terminal line for $W/r3 is not preceded by its own started line"
# A terminal preceded by ANOTHER run's started line: a killed run A started between run 1's own
# started line and run 1's terminal, so run 1's started line falls outside the six and A's sits
# where run 1's belongs. Every line is well-formed; only the RUN_DIR equality refuses it.
W="$(mkworld rl-foreign)" || broken seed
{ lstarted "$W/r1" $((T0 + 1000)); lstarted "$W/kA" $((T0 + 1500)); printf '%s\t0\t%s\t%s\t%s\n' "$W/r1" $((T0 + 1000)) $((T0 + 1060)) "$TPL_SHA"; lline "$W/r2" 2; lline "$W/r3" 3; } > "$W/ledger"
want rl-foreign 2 "RL ledger line 2 of the last six: the terminal line for $W/r1 is preceded by the started line of $W/kA ($((T0 + 1500))) -- not its own"
# The same RUN_DIR with a different start epoch, and then with a different HEAD: each is a started
# line that is not this terminal's own, and each is refused on that one field alone.
W="$(mkworld rl-epoch)" || broken seed
{ lline "$W/r1" 1; lstarted "$W/r2" $((T0 + 2001)); printf '%s\t0\t%s\t%s\t%s\n' "$W/r2" $((T0 + 2000)) $((T0 + 2060)) "$TPL_SHA"; lline "$W/r3" 3; } > "$W/ledger"
want rl-epoch 2 "RL ledger line 4 of the last six: the terminal line for $W/r2 is preceded by the started line of $W/r2 ($((T0 + 2001))) -- not its own"
W="$(mkworld rl-head)" || broken seed
{ lline "$W/r1" 1; lline "$W/r2" 2; printf '%s\tstarted\t%s\t%s\n' "$W/r3" $((T0 + 3000)) 0000000000000000000000000000000000000000; printf '%s\t0\t%s\t%s\t%s\n' "$W/r3" $((T0 + 3000)) $((T0 + 3060)) "$TPL_SHA"; } > "$W/ledger"
want rl-head 2 "RL ledger line 6 of the last six: the terminal line for $W/r3 is preceded by the started line of $W/r3 ($((T0 + 3000))) -- not its own"
W="$(mkworld rl-missing)" || broken seed; { lline "$W/r1" 1; lline "$W/nowhere" 2; lline "$W/r3" 3; } > "$W/ledger"
want rl-missing 2 "RL run 2: $W/nowhere does not exist"
W="$(mkworld rl-rc)" || broken seed; { lline "$W/r1" 1; lline "$W/r2" 2 1; lline "$W/r3" 3; } > "$W/ledger"
want rl-rc 2 "RL run 2: $W/r2 is recorded with rc '1'"
W="$(mkworld rl-rcfile)" || broken seed; printf '1\n' > "$W/r2/rc"
want rl-rcfile 2 "RL run 2: $W/r2/rc reads '1'"
# THE DISCRIMINATING LEDGER for the skip mutant: FOUR lines, the first three good and the LAST bad.
# A three-line ledger with one bad line refuses under both the scorer and the mutant.
W="$(mkworld rl-skip)" || broken seed; seed_run "$W/r4" 4 || broken seed; printf '%s\n' "$KILLTOK" > "$W/r4/rc"; lline "$W/r4" 4 "$KILLTOK" >> "$W/ledger"
want rl-skip 2 "RL run 3: $W/r4 is recorded with rc '$KILLTOK'"

# R0 -- a sandbox run.
W="$(mkworld r0-log)" || broken seed; log_sub "$W/r2/deriver.log" 'sandbox tracer: fixtures run as' "[00:10:00] fs_usage runs as root; fixtures run as 'fx'"
want r0-log 2 "R0 $W/r2: deriver.log carries no 'sandbox tracer"
W="$(mkworld r0-sb)" || broken seed; rm -f "$W/r3/root/w/sandbox.sb"
want r0-sb 2 "R0 $W/r3: root/w/sandbox.sb is absent"
# A NARROWED profile, as AI_DLC_READSET_SANDBOX_PROFILE would substitute: file reads under the tree only.
W="$(mkworld r0-profile)" || broken seed; printf '(version 3)\n(allow default)\n(allow file-read* (subpath "%s/t") (with report))\n' "$(cd "$W/r2/root" && pwd -P)" > "$W/r2/root/w/sandbox.sb"
want r0-profile 2 "R0 $W/r2: root/w/sandbox.sb is not the deriver's default profile"
# R1 -- the log is this root's.
W="$(mkworld r1)" || broken seed; log_sub "$W/r1/deriver.log" 'copying the tree to' "[00:10:01] copying the tree to /private/tmp/elsewhere/t"
want r1 2 "R1 $W/r1: deriver.log copied the tree to '/private/tmp/elsewhere/t'"
# R2 -- three distinct runs.
W="$(mkworld r2-link)" || broken seed; ln -s "$W/r1" "$W/r1link"; { lline "$W/r1" 1; lline "$W/r1link" 2; lline "$W/r3" 3; } > "$W/ledger"
want r2-link 2 "R2: two ledger lines resolve to one root"
W="$(mkworld r2-copy)" || broken seed; for fx in $SUBJ; do cp "$W/r1/root/w/$fx.raw" "$W/r2/root/w/$fx.raw"; done
want r2-copy 2 "R2: enforcement-map-sites.raw is byte-identical in two runs"
W="$(mkworld r2-overlap)" || broken seed; { lline "$W/r1" 1; lpair "$W/r2" 0 $((T0 + 1030)) $((T0 + 2060)); lline "$W/r3" 3; } > "$W/ledger"
want r2-overlap 2 "R2: the ledger windows are not time-ordered and disjoint"
# R2 refuses ONE subject's .raw copied, the other four distinct: the contract requires EVERY
# subject's .raw to differ. A MIDDLE subject, because the first and last subjects' .raw carry the
# A4 window, and copying either would move run 2's window onto run 1's load samples (R5).
W="$(mkworld r2-one)" || broken seed; cp "$W/r1/root/w/enforcement-map-sites-b.raw" "$W/r2/root/w/enforcement-map-sites-b.raw"
want r2-one 2 "R2: enforcement-map-sites-b.raw is byte-identical in two runs"
# R3 -- per-subject inputs exist.
W="$(mkworld r3)" || broken seed; rm -f "$W/r2/root/w/enforcement-map-sites-c.canary"
want r3 2 "R3 $W/r2: root/w/enforcement-map-sites-c.canary is absent"
# R4 -- one tree.
W="$(mkworld r4-head)" || broken seed; ( cd "$W/r3/root/t" && gitc commit -q --allow-empty -m drift ) || broken "r4 commit"
want r4-head 2 "R4: the three trees are not at one HEAD"
W="$(mkworld r4-copylist)" || broken seed; printf 'a\0c\0' > "$W/r3/root/w/copy.list"
want r4-copylist 2 "R4: root/w/copy.list differs"
W="$(mkworld r4-dirty)" || broken seed; echo "[00:10:02] note: deriving from a tree with 3 uncommitted path(s); the guard measures growth beyond that" >> "$W/r2/deriver.log"
want r4-dirty 2 "R4 $W/r2: deriver.log carries the 'uncommitted path(s)' note"
# R5 -- a load sample inside the window. Both samples outside it are ABOVE the floor.
W="$(mkworld r5)" || broken seed; printf '%s\t9.00\n%s\t9.00\n' $((T0 + 3000 - 5)) $((T0 + 3000 + 70)) > "$W/r3/load.tsv"
want r5 2 "R5 run 3: no load sample"
# R6 -- the five subjects and no other.
W="$(mkworld r6)" || broken seed; printf '  %-32s %5s paths\n' plan-shape 3 >> "$W/r1/deriver.log"
want r6 2 "R6 $W/r1: deriver.log traced 'plan-shape'"
W="$(mkworld r6-omitted)" || broken seed; printf '  %-32s OMITTED (fixture exited 1) -- will always run\n' plan-shape >> "$W/r3/deriver.log"
want r6-omitted 2 "R6 $W/r3: deriver.log traced 'plan-shape'"

# A1 alone, on a PREFIX-SHARING name: `-b` is OMITTED, `enforcement-map-sites` is not. The paths
# line is kept so A5 stays quiet (see the header).
W="$(mkworld a1)" || broken seed; printf '  %-32s OMITTED (fixture exited 1) -- will always run\n' enforcement-map-sites-b >> "$W/r2/deriver.log"
want a1 1 "$(tuples 'run2 enforcement-map-sites-b A1')"
# A2 alone: the drop notice is in the .win and nowhere in deriver.log. It is `log stream`'s own
# line, byte for byte as a real .win carries it -- never a spelling the reader happens to accept.
W="$(mkworld a2)" || broken seed; printf '%s\n' '=== Messages dropped during live streaming (use `log show` to see what they were)' > "$W/r1/root/w/validator-arm-selection.win"
want a2 1 "$(tuples 'run1 validator-arm-selection A2')"
# A3 alone: a 1-line canary.
W="$(mkworld a3)" || broken seed; printf 'core/x.sh\n' > "$W/r3/root/w/enforcement-map-sites-c.canary"
want a3 1 "$(tuples 'run3 enforcement-map-sites-c A3')"
# A3's unreadable-canary clause, with the A1 it necessarily carries.
W="$(mkworld a3u)" || broken seed; printf '  %-32s OMITTED (LOSS CANARY: unreadable path(s) the fixture read (atime) are absent from the stream) -- will always run\n' enforcement-map-sites-c >> "$W/r1/deriver.log"
want a3u 1 "$(tuples 'run1 enforcement-map-sites-c A1' 'run1 enforcement-map-sites-c A3')"
# A5 alone, two shapes: the paths line ABSENT for the prefix name (every subject's count is equal,
# so a substring match reading `-b`'s line passes), and a count unequal to the .set.
W="$(mkworld a5)" || broken seed; log_del_paths "$W/r1/deriver.log" enforcement-map-sites
want a5 1 "$(tuples 'run1 enforcement-map-sites A5')"
W="$(mkworld a5n)" || broken seed; log_sub "$W/r2/deriver.log" ' validator-arm-selection-b ' "$(printf '  %-32s %5s paths' validator-arm-selection-b 7)"
want a5n 1 "$(tuples 'run2 validator-arm-selection-b A5')"
# A4 alone: 6.00 BEFORE the window, 3.00 inside it. The message must carry the seeded window.
W="$(mkworld a4)" || broken seed; printf '%s\t6.00\n%s\t3.00\n%s\t1.00\n' $((T0 + 2000 - 5)) $((T0 + 2000 + 20)) $((T0 + 2000 + 70)) > "$W/r2/load.tsv"
want a4 1 "$(tuples 'run2 - A4')"
# A4 near-miss: exactly 4.50 inside the window is MET.
W="$(mkworld a4-edge)" || broken seed; printf '%s\t1.00\n%s\t4.50\n' $((T0 + 1000 - 5)) $((T0 + 1000 + 20)) > "$W/r1/load.tsv"
want a4-edge 0 MET
# A4 has an END: 4.40 inside the window, 6.00 nine seconds AFTER its end (base+51, ceiled).
W="$(mkworld a4-after)" || broken seed; printf '%s\t1.00\n%s\t4.40\n%s\t6.00\n' $((T0 + 3000 - 5)) $((T0 + 3000 + 20)) $((T0 + 3000 + 60)) > "$W/r3/load.tsv"
want a4-after 1 "$(tuples 'run3 - A4')"
# A6 alone: run 2 loses a present path; its paths count follows, and its canary stays empty, so
# neither A5 nor A3 fires.
W="$(mkworld a6)" || broken seed; printf 'core/fixtures/validator-arm-selection/run.sh\n.gitignore\n.githooks/pre-push\n' > "$W/r2/root/w/validator-arm-selection.set"; relog "$W/r2"
want a6 1 "$(tuples '- validator-arm-selection A6')"
# A6 on `.gitignore`, which a `^\.git` exclusion drops in every run.
W="$(mkworld a6-gitignore)" || broken seed; printf 'core/fixtures/enforcement-map-sites/run.sh\npresent1\n.githooks/pre-push\n' > "$W/r3/root/w/enforcement-map-sites.set"; relog "$W/r3"
want a6-gitignore 1 "$(tuples '- enforcement-map-sites A6')"
# A6 OWN-TREE world: run 1's tree LACKS d/p and run 1 reports it; runs 2-3 have d/p and lost it.
# The union filter keeps d/p (it exists in run 2's tree); a per-run own-tree filter drops it from
# run 1 alone and reads three equal sets.
W="$(mkworld a6-owntree)" || broken seed; rm -f "$W/r1/root/t/d/p"; printf 'd/p\n' >> "$W/r1/root/w/enforcement-map-sites-b.set"; relog "$W/r1"
want a6-owntree 1 "$(tuples '- enforcement-map-sites-b A6')"
# The contract's P2 world: run 1's tree lacks d/p, run 2 lost it, run 3 reports it.
W="$(mkworld a6-p2)" || broken seed; rm -f "$W/r1/root/t/d/p"; printf 'd/p\n' >> "$W/r3/root/w/enforcement-map-sites-b.set"; relog "$W/r3"
want a6-p2 1 "$(tuples '- enforcement-map-sites-b A6')"
# A6 on a DIRECTORY row: real .set files carry directories (`core`, `.githooks`, each fixture's
# dir). Runs 1 and 3 report core/fixtures/validator-arm-selection-b, run 2 lost it.
W="$(mkworld a6-dir)" || broken seed
for i in 1 3; do printf 'core/fixtures/validator-arm-selection-b\n' >> "$W/r$i/root/w/validator-arm-selection-b.set"; relog "$W/r$i"; done
[ -d "$W/r2/root/t/core/fixtures/validator-arm-selection-b" ] || broken "the directory row names no directory"
want a6-dir 1 "$(tuples '- validator-arm-selection-b A6')"
# A6 near-misses: an ABSENT-only difference, and a `.git/` row in one run, both MET.
W="$(mkworld a6-absent)" || broken seed; printf 'absent/nowhere\n' >> "$W/r2/root/w/validator-arm-selection-b.set"; relog "$W/r2"
want a6-absent 0 MET
W="$(mkworld a6-dotgit)" || broken seed; printf '.git/HEAD\n' >> "$W/r1/root/w/enforcement-map-sites.set"; relog "$W/r1"
[ -f "$W/r1/root/t/.git/HEAD" ] || broken "the .git near-miss row names no file"
want a6-dotgit 0 MET

NWORLDS="$(grep -c . "$TABLE")" || NWORLDS=0
[ "$NWORLDS" -ge 30 ] || broken "the world table holds $NWORLDS rows"

# ------------------------------------------------------------------ the shipping scorer ----
echo " the shipping scorer, every world:"
sp="$(TMPDIR="$WORK/w" FXCELL=score-selfprobe bash "$SCORER" --self-probe 2>&1)"; rc=$?
case "$rc|$sp" in "0|self-probe: "*" probes answered as expected") B_sp=1; ok "--self-probe exits 0 ($sp)" ;; *) bad "--self-probe: rc=$rc $sp" ;; esac
while IFS="$(printf '\t')" read -r name wrc wspec; do
  got="$(verdict "$SCORER" "$(w_of "$name")")"
  eval "GOT_${name//-/_}=\$got"
  if matches "$got" "$wrc" "$wspec"; then ok "$name -> $got"; eval "B_w_${name//-/_}=1"; else bad "$name -> $got (want $wrc|$wspec)"; fi
done < "$TABLE"

# THE EQUIVALENCE CELL, and the one end-to-end run per distinct CLI outcome (exit 0 MET, exit 1 NOT-MET, exit 2
# REFUSED): the CLI, run as a process, prints byte-for-byte what the in-process stage1_score printed for the same
# world, with the same exit. The three worlds differ (control: their outputs are pairwise distinct), so an
# in-process path that answered every world alike could not pass.
eqv=""; eqo=""
for name in met a1 r1; do
  W="$(w_of "$name")"
  ip="$(score_in "$SCORER" "$W" "$WORK")"; iprc=$?
  cl="$(FXCELL="score-cli-$name" score_cli "$SCORER" "$W" "$WORK")"; clrc=$?
  [ "$iprc|$ip" = "$clrc|$cl" ] || eqv="$eqv $name[in-process rc=$iprc, cli rc=$clrc]"
  eqo="$eqo$clrc:$(printf '%s' "$cl" | cksum | cut -d' ' -f1) "
done
neq="$(printf '%s\n' $eqo | sort -u | grep -c .)" || neq=0
if [ -z "$eqv" ] && [ "$neq" = 3 ]; then ok "equivalence: the CLI and the in-process stage1_score print byte-identical output with the same exit on met (0), a1 (1) and r1 (2), three distinct answers"
else bad "equivalence: in-process and CLI differ:$eqv (distinct answers $neq of 3)"; fi

# THE MET LINE NAMES THE SEEDED RUN DIRS -- the ledger override was delivered, not the default.
W="$(w_of met)"
out="$(cat "$W/raw.$(basename "$SCORER")")"
case "$out" in *"($W/r1, $W/r2, $W/r3)"*) ok "the MET line names the three seeded runs" ;; *) bad "the MET line does not name the seeded runs: $out" ;; esac
# THE A4 WINDOW ROUND-TRIPS the local-time .raw stamps to the seeded epochs.
W="$(w_of a4)"
out="$(cat "$W/raw.$(basename "$SCORER")")"
case "$out" in *"peak 1-min load 3.00 inside the window $((T0 + 2010))-$((T0 + 2051)) "*) ok "A4 reads the seeded window $((T0 + 2010))-$((T0 + 2051)) off local-time .raw stamps" ;; *) bad "A4 window did not round-trip: $out" ;; esac
# THE SCORER LEAVES NO SCRATCH DIRECTORY BEHIND.
left="$(find "$WORK/w/met/tmp" "$WORK/w/a4/tmp" -mindepth 1 -maxdepth 1 -name 'readset-stage1-verdict.*' 2>/dev/null | grep -c .)" || left=0
ctl="$(find "$WORK/w/met" -mindepth 1 -maxdepth 1 -name ledger | grep -c .)" || ctl=0
if [ "$left" -eq 0 ] && [ "$ctl" -eq 1 ]; then ok "no readset-stage1-verdict.* scratch left in TMPDIR (control: the find sees the ledger)"; else bad "scratch left behind: $left (control $ctl)"; fi

# CWD-INVARIANCE: two worlds, three working directories, one a dirty decoy repo carrying its own
# default-path ledger. Byte-identical or the scorer resolved something from where it was run.
DECOY="$WORK/decoy"; mkdir -p "$DECOY" && ( cd "$DECOY" && git init -q . ) || broken "decoy repo"
printf 'garbage\tledger\n' > "$DECOY/.git/ai-dlc-readset-stage1.ledger"; printf 'dirt\n' > "$DECOY/untracked"
for name in met a4; do
  eval "a=\$GOT_$name"; b="$(verdict "$SCORER" "$(w_of "$name")" /)"; c="$(verdict "$SCORER" "$(w_of "$name")" "$DECOY")"
  if [ "$a" = "$b" ] && [ "$b" = "$c" ] && [ -n "$a" ]; then ok "cwd-invariant on $name ($a)"; else bad "cwd changes $name: [$a] [$b] [$c]"; fi
done

# ------------------------------------------------------------------ scorer mutants ----
# mut <src> <dst>: replace exactly ONE line equal to $MUT_OLD with $MUT_NEW. Fails if the count is
# not 1, if the copy does not differ from its source, or if the copy does not parse.
mut() {
  awk -v CF="$2.count" '$0 == ENVIRON["MUT_OLD"] { $0 = ENVIRON["MUT_NEW"]; c++ } { print } END { print c + 0 > CF }' "$1" > "$2" || return 1
  [ "$(cat "$2.count")" = 1 ] || return 1
  if cmp -s "$1" "$2"; then return 1; fi
  bash -n "$2" 2>/dev/null
}
MD="$WORK/mut"; mkdir -p "$MD"
CTL="$MD/control.sh"
export MUT_OLD='self_probe' MUT_NEW=': self_probe disabled in the control copy'
mut "$SCORER" "$CTL" || broken "the control copy did not apply (self_probe call line not found exactly once)"
WORLDS="$WORK/worlds"; cut -f1 "$TABLE" > "$WORLDS"

# THE CONTROL COPY IS A DIFFERENT PROGRAM FROM THE SHIPPING SCORER, so its differences are counted, not
# read: `diff` lines of the copy against the shipping scorer must be exactly one removed and one added,
# and the same count of the scorer against itself is the control that the count can read zero.
dn_same="$(diff "$SCORER" "$SCORER" | grep -c '^[<>]')" || dn_same=0
dn_ctl="$(diff "$SCORER" "$CTL" | grep -c '^[<>]')" || dn_ctl=0
if [ "$dn_same" = 0 ] && [ "$dn_ctl" = 2 ]; then ok "the control copy differs from the shipping scorer in exactly one line (diff: $dn_ctl changed lines; the scorer against itself: $dn_same)"; else bad "the control copy differs from the shipping scorer in $dn_ctl diff line(s) (want 2); self-diff $dn_same (want 0)"; fi

# world_hit <script> <world> [probe]: 1 when the script answers the world differently from the table, else 0.
# `probe` asks it the way the CLI does, self-probe first (the self-probe mutants' matrix rows need that path).
world_hit() {
  local wrc wspec got
  wrc="$(awk -F'\t' -v n="$2" '$1 == n { print $2 }' "$TABLE")"; wspec="$(awk -F'\t' -v n="$2" '$1 == n { print $3 }' "$TABLE")"
  got="$(verdict "$1" "$(w_of "$2")" "$WORK" "${3:-}")"
  if matches "$got" "$wrc" "$wspec"; then echo 0; else echo 1; fi
}
# mx_judge <name> <decides csv> <killed csv>: the measured killed set equals the declared deciding set.
mx_judge() {
  local d k
  d="$(printf '%s\n' ${2//,/ } | LC_ALL=C sort | tr '\n' ',')"; k="$(printf '%s\n' ${3//,/ } | LC_ALL=C sort | tr '\n' ',')"
  if [ "$d" = "$k" ]; then ok "MATRIX $1: the tripped cells are exactly the deciding set ($2)"; else bad "MATRIX $1: tripped cells [$3] differ from the deciding set [$2]"; fi
}
# matrix_row <name> <script> <decides csv>: every world scored against the mutant, one row, matrix mode only.
matrix_row() {
  local w h cells="" ks=""
  while IFS= read -r w; do
    MCELLS=$((MCELLS + 1))
    h="$(world_hit "$2" "$w")"
    cells="$cells $w:$h"
    [ "$h" = 1 ] && ks="$ks,$w"
  done < "$WORLDS"
  echo "MATRIX $1$cells"
  mx_judge "$1" "$3" "${ks#,}"
}

echo " the probe-disabled control copy agrees with the shipping scorer (one world per outcome class):"
for name in met a1 r1; do
  eval "a=\$GOT_${name//-/_}"; b="$(verdict "$CTL" "$(w_of "$name")")"
  case "$name" in met) cls=MET ;; a1) cls=NOT-MET ;; *) cls=REFUSED ;; esac
  if [ "$a" = "$b" ]; then ok "control copy = shipping scorer on $name ($cls: $a)"; else bad "control copy disagrees with the shipping scorer on $name ($cls): [$a] vs [$b]"; fi
done
if [ "$MATRIX" = 1 ]; then
  echo " matrix: the control copy on every other world:"
  while IFS= read -r name; do
    case "$name" in met|a1|r1) continue ;; esac
    MCELLS=$((MCELLS + 1))
    eval "a=\$GOT_${name//-/_}"; b="$(verdict "$CTL" "$(w_of "$name")")"
    if [ "$a" = "$b" ]; then ok "matrix: control copy = shipping scorer on $name"; else bad "matrix: control copy disagrees with the shipping scorer on $name: [$a] vs [$b]"; fi
  done < "$WORLDS"
fi

# smut <flag> <name> <decides csv> <twin world> <old line> <new line>: a scorer mutant from the CONTROL
# copy. KILLED on each deciding world (the verdict differs from the table); the twin world must stay
# GREEN under it, which is also the liveness check that the mutant still scores the ALL-MET world.
# The flag is the conjunction of the base-pass flags of the worlds it reads, set by the shipping loop.
smut() {
  local flag="$1" name="$2" decides="$3" twin="$4" dst="$MD/$2.sh" w
  export MUT_OLD="$5" MUT_NEW="$6"
  mut "$CTL" "$dst" || { bad "mutant $name DID NOT APPLY"; return; }
  [ "$(world_hit "$dst" "$twin")" = 0 ] || { bad "mutant $name is not confined: its twin world $twin answers differently under it"; return; }
  for w in ${decides//,/ }; do
    if [ "$(world_hit "$dst" "$w")" = 1 ]; then mutant_killed "$flag" "$name" "mutant $name KILLED on $w (applied; twin $twin green)"; else bad "mutant $name SURVIVED on $w"; fi
  done
  if [ "$MATRIX" = 1 ]; then matrix_row "$name" "$dst" "$decides"; fi
}
echo " scorer mutants:"
smut "$(( ${B_w_a1:-0} && ${B_w_a3u:-0} && ${B_w_met:-0} ))" del-A1 a1,a3u met '    a1_omitted "$rd/deriver.log" "$fx" "$label" || FAILED=1' '    :'
smut "$(( ${B_w_a2:-0} && ${B_w_met:-0} ))" del-A2 a2 met '    a2_dropped "$rd/root/w/$fx.win" "$fx" "$label" || FAILED=1' '    :'
smut "$(( ${B_w_a3:-0} && ${B_w_a3u:-0} && ${B_w_met:-0} ))" del-A3 a3,a3u met '    a3_canary "$rd/root/w/$fx.canary" "$rd/deriver.log" "$fx" "$label" || FAILED=1' '    :'
smut "$(( ${B_w_a4:-0} && ${B_w_a4_after:-0} && ${B_w_met:-0} ))" del-A4 a4,a4-after met '  a4_load "$rd/load.tsv" "$ws" "$we" "$label" || FAILED=1' '  :'
smut "$(( ${B_w_a5:-0} && ${B_w_a5n:-0} && ${B_w_met:-0} ))" del-A5 a5,a5n met '    a5_paths "$rd/deriver.log" "$rd/root/w/$fx.set" "$fx" "$label" || FAILED=1' '    :'
smut "$(( ${B_w_a6:-0} && ${B_w_a6_gitignore:-0} && ${B_w_a6_owntree:-0} && ${B_w_a6_p2:-0} && ${B_w_a6_dir:-0} && ${B_w_met:-0} ))" del-A6 a6,a6-gitignore,a6-owntree,a6-p2,a6-dir met '  a6_compare "$RD1" "$RD2" "$RD3" "$fx" "$SCRATCH" || FAILED=1' '  :'
smut "$(( ${B_w_a6_owntree:-0} && ${B_w_met:-0} ))" a6-owntree a6-owntree met \
  '    LC_ALL=C comm -12 "$s/a6.$i" "$s/a6.keep" > "$s/a6.f$i"' \
  '    eval "rd=\"\$$i\""; while IFS= read -r p; do if [ -e "$rd/root/t/$p" ] || [ -L "$rd/root/t/$p" ]; then printf "%s\n" "$p"; fi; done < "$s/a6.$i" > "$s/a6.f$i"'
smut "$(( ${B_w_a6_gitignore:-0} && ${B_w_met:-0} ))" a6-caret-git a6-gitignore met \
  "    awk '\$0 != \"\" && \$0 != \".git\" && index(\$0, \".git/\") != 1' \"\$rd/root/w/\$fx.set\" | LC_ALL=C sort -u > \"\$s/a6.\$i\" \\" \
  "    awk '\$0 != \"\" && \$0 !~ /^\\.git/' \"\$rd/root/w/\$fx.set\" | LC_ALL=C sort -u > \"\$s/a6.\$i\" \\"
smut "$(( ${B_w_a1:-0} && ${B_w_a3u:-0} && ${B_w_met:-0} ))" a1-substring a1,a3u met \
  "  hit=\"\$(awk -v f=\"\$2\" '\$1 == f && \$2 == \"OMITTED\" { print; exit }' \"\$1\")\"" \
  "  hit=\"\$(awk -v f=\"\$2\" 'index(\$1, f) == 1 && \$2 == \"OMITTED\" { print; exit }' \"\$1\")\""
smut "$(( ${B_w_a5:-0} && ${B_w_met:-0} ))" a5-substring a5 met \
  "  logged=\"\$(awk -v f=\"\$3\" '\$1 == f && \$3 == \"paths\" { print \$2; exit }' \"\$1\")\"" \
  "  logged=\"\$(awk -v f=\"\$3\" 'index(\$1, f) == 1 && \$3 == \"paths\" { print \$2; exit }' \"\$1\")\""
smut "$(( ${B_w_a2:-0} && ${B_w_met:-0} ))" a2-reads-log a2 met '    a2_dropped "$rd/root/w/$fx.win" "$fx" "$label" || FAILED=1' '    a2_dropped "$rd/deriver.log" "$fx" "$label" || FAILED=1'
smut "$(( ${B_w_a4:-0} && ${B_w_a4_after:-0} && ${B_w_met:-0} ))" a4-whole-file a4,a4-after met '  cp="$(window_load "$1" "$2" "$3")"; peak="${cp#* }"' '  cp="$(window_load "$1" 0 99999999999)"; peak="${cp#* }"'
smut "$(( ${B_w_r0_log:-0} && ${B_w_r0_sb:-0} && ${B_w_r0_profile:-0} && ${B_w_met:-0} ))" del-R0 r0-log,r0-sb,r0-profile met '  why="$(r0_sandbox "$rd" "$SCRATCH")" || refuse "$why"' '  :'
smut "$(( ${B_w_r2_link:-0} && ${B_w_met:-0} ))" r2-string r2-link met \
  '  a="$(cd "$1/root" 2>/dev/null && pwd -P)"; b="$(cd "$2/root" 2>/dev/null && pwd -P)"; c="$(cd "$3/root" 2>/dev/null && pwd -P)"' \
  '  a="$1/root"; b="$2/root"; c="$3/root"'
# The ledger read, two skip mutants. Each drops the bad run's lines BOTH (started and terminal), so
# what is left is three well-formed pairs and the mutant scores MET: a skip, not a different refusal.
L6_OLD="awk 'NF > 0' \"\$LEDGER\" | tail -n 6 > \"\$SCRATCH/last6\" || refuse \"cannot read the ledger \$LEDGER\""
smut "$(( ${B_w_rl_rc:-0} && ${B_w_rl_skip:-0} && ${B_w_met:-0} ))" rl-skip rl-rc,rl-skip met "$L6_OLD" \
  "awk -F'\\t' 'NR == FNR { if (\$2 != \"started\" && \$2 != \"0\") b[\$1] = 1; next } NF > 0 && !(\$1 in b)' \"\$LEDGER\" \"\$LEDGER\" | tail -n 6 > \"\$SCRATCH/last6\" || refuse \"cannot read the ledger \$LEDGER\""
smut "$(( ${B_w_rl_started:-0} && ${B_w_rl_foreign:-0} && ${B_w_met:-0} ))" rl-skip-started rl-started,rl-foreign met "$L6_OLD" \
  "awk -F'\\t' 'NR == FNR { if (\$2 != \"started\") t[\$1] = 1; next } NF > 0 && !(\$2 == \"started\" && !(\$1 in t))' \"\$LEDGER\" \"\$LEDGER\" | tail -n 6 > \"\$SCRATCH/last6\" || refuse \"cannot read the ledger \$LEDGER\""
# A2 keyed on an ending `log stream` never writes: dies on the producer's verbatim line.
A2_OLD="  n=\"\$(grep -c 'dropped during' \"\$1\" 2>/dev/null)\""
A2_NEW="  n=\"\$(grep -c 'dropped during live streaming ===\$' \"\$1\" 2>/dev/null)\""
smut "$(( ${B_w_a2:-0} && ${B_w_met:-0} ))" a2-ending a2 met "$A2_OLD" "$A2_NEW"
# A4 bounded at the start only (15 s of slack past the end): dies on 6.00 sampled after the window.
A4_OLD='    $1 ~ /^[0-9]+$/ && $2 ~ /^[0-9]+(\.[0-9]+)?$/ && $1 + 0 >= s + 0 && $1 + 0 <= e + 0 {'
A4_NEW='    $1 ~ /^[0-9]+$/ && $2 ~ /^[0-9]+(\.[0-9]+)?$/ && $1 + 0 >= s + 0 && $1 + 0 <= e + 15 {'
smut "$(( ${B_w_a4_after:-0} && ${B_w_met:-0} ))" a4-open-end a4-after met "$A4_OLD" "$A4_NEW"
# A6 with a regular-file-only existence filter: dies on the directory row.
A6P_OLD='a6_present() { [ -e "$1" ] || [ -L "$1" ]; }'
A6P_NEW='a6_present() { [ -f "$1" ]; }'
smut "$(( ${B_w_a6_dir:-0} && ${B_w_met:-0} ))" a6-regular-file a6-dir met "$A6P_OLD" "$A6P_NEW"
# R0 without the profile comparison: dies on the narrowed profile.
R0_OLD='  cmp -s "$2/r0.sb" "$1/root/w/sandbox.sb" \'
R0_NEW='  true \'
smut "$(( ${B_w_r0_profile:-0} && ${B_w_met:-0} ))" r0-no-profile r0-profile met "$R0_OLD" "$R0_NEW"
# R6 reading only `paths` lines: dies on a foreign OMITTED line.
R6_OLD="    substr(\$0, 1, 2) == \"  \" && (\$2 == \"OMITTED\" || \$3 == \"paths\") && index(subj, \" \" \$1 \" \") == 0 { print \$1; exit }' \"\$1/deriver.log\")\""
R6_NEW="    substr(\$0, 1, 2) == \"  \" && \$3 == \"paths\" && index(subj, \" \" \$1 \" \") == 0 { print \$1; exit }' \"\$1/deriver.log\")\""
smut "$(( ${B_w_r6_omitted:-0} && ${B_w_met:-0} ))" r6-paths-only r6-omitted met "$R6_OLD" "$R6_NEW"
# R2 comparing run 1 with run 2 for the FIRST subject only (1-3 and 2-3 for all): dies on the one
# middle subject copied from run 1 to run 2, while r2-copy, which copies all five, cannot tell it
# from the scorer.
R2_OLD='    if cmp -s "$1/root/w/$fx.raw" "$2/root/w/$fx.raw" || cmp -s "$1/root/w/$fx.raw" "$3/root/w/$fx.raw" \'
R2_NEW='    if [ "$fx" = "$FIRST_SUBJECT" ] && cmp -s "$1/root/w/$fx.raw" "$2/root/w/$fx.raw" || cmp -s "$1/root/w/$fx.raw" "$3/root/w/$fx.raw" \'
smut "$(( ${B_w_r2_one:-0} && ${B_w_met:-0} ))" r2-first-only r2-one met "$R2_OLD" "$R2_NEW"
# The pair check itself: unchecked, and with either the epoch or the HEAD conjunct dropped. Each
# dies on the one world whose started line differs from its terminal in that field alone.
RLP_OLD='    [ "$sr" = "$tr" ] && [ "$ss" = "$ts" ] && [ "$sh" = "$th" ] \'
smut "$(( ${B_w_rl_foreign:-0} && ${B_w_rl_epoch:-0} && ${B_w_rl_head:-0} && ${B_w_met:-0} ))" rl-pair-unchecked rl-foreign,rl-epoch,rl-head met "$RLP_OLD" '    true \'
smut "$(( ${B_w_rl_epoch:-0} && ${B_w_met:-0} ))" rl-pair-no-epoch rl-epoch met "$RLP_OLD" '    [ "$sr" = "$tr" ] && [ "$sh" = "$th" ] \'
smut "$(( ${B_w_rl_head:-0} && ${B_w_met:-0} ))" rl-pair-no-head rl-head met "$RLP_OLD" '    [ "$sr" = "$tr" ] && [ "$ss" = "$ts" ] \'

# THE SCORER'S OWN SELF-PROBE must refuse each of these mutations too: applied to the SHIPPING
# scorer, self-probe live, `--self-probe` exits 2.
pmut() { # pmut <flag> <name> <old> <new>: decides selfprobe alone (the self-probe runs before any world, so every world refuses: dead in every cell)
  local flag="$1" name="$2" rc sp m w
  export MUT_OLD="$3" MUT_NEW="$4"
  if mut "$SCORER" "$MD/$name.sh"; then
    # IN PROCESS: the mutated copy sourced in a subshell and asked stage1_entry --self-probe, the path `--self-probe` takes.
    sp="$( ( TMPDIR="$MD"; export TMPDIR; . "$MD/$name.sh" || exit 9; stage1_entry --self-probe ) 2>&1)"; rc=$?
    if [ "$rc" = 2 ]; then mutant_killed "$flag" "$name" "the scorer's --self-probe refuses $name (rc 2)"; else bad "the scorer's --self-probe passed $name (rc $rc: $sp)"; fi
    if [ "$MATRIX" = 1 ]; then
      m=""; while IFS= read -r w; do MCELLS=$((MCELLS + 1)); m="$m $w:$(world_hit "$MD/$name.sh" "$w" probe)"; done < "$WORLDS"
      echo "MATRIX $name selfprobe:$([ "$rc" = 2 ] && echo 1 || echo 0)$m"
    fi
  else
    bad "self-probe mutant $name DID NOT APPLY"
  fi
}
pmut "${B_sp:-0}" probe-owntree '    LC_ALL=C comm -12 "$s/a6.$i" "$s/a6.keep" > "$s/a6.f$i"' \
  '    eval "rd=\"\$$i\""; while IFS= read -r p; do if [ -e "$rd/root/t/$p" ] || [ -L "$rd/root/t/$p" ]; then printf "%s\n" "$p"; fi; done < "$s/a6.$i" > "$s/a6.f$i"'
pmut "${B_sp:-0}" probe-a2-ending "$A2_OLD" "$A2_NEW"
pmut "${B_sp:-0}" probe-a4-open-end "$A4_OLD" "$A4_NEW"
pmut "${B_sp:-0}" probe-a6-regular-file "$A6P_OLD" "$A6P_NEW"
pmut "${B_sp:-0}" probe-r0-no-profile "$R0_OLD" "$R0_NEW"
pmut "${B_sp:-0}" probe-r6-paths-only "$R6_OLD" "$R6_NEW"
pmut "${B_sp:-0}" probe-r2-first-only "$R2_OLD" "$R2_NEW"
# The pairing walk with no pair check at all: the self-probe's killed-run ledger must refuse.
pmut "${B_sp:-0}" probe-rl-no-pairing '  for k in 3 2 1; do' '  for k in; do'
# The pair check unchecked: the self-probe's foreign-started ledger must refuse.
pmut "${B_sp:-0}" probe-rl-pair-unchecked "$RLP_OLD" '    true \'

# ------------------------------------------------------------------ the wrapper ----
STUB="$WORK/stub.sh"
cat > "$STUB" <<'STUB_EOF'
#!/usr/bin/env bash
# A stub of core/scripts/derive-fixture-readsets.sh: NO trap, like the real deriver. It records its
# argv and trace root, rewrites the map, keeps a copy of what it wrote, then exits per STUB_MODE.
# `hang-late` writes the map AFTER its children end, as the real deriver writes it LAST: that is
# the SIGKILL arm's shape, where the map is clean while the orphan lives. `hang` writes it FIRST,
# for the TERM arm, which must show the restore undoing a write -- a trap-less stub TERMed inside
# its `wait` never reaches a late write, so `hang-late` there would leave the restore with nothing
# to undo.
root="$AI_DLC_READSET_TRACE_ROOT"
mkdir -p "$root/w" "$root/m" "$root/t"
echo "stub: argv: $*"
echo "stub: trace root: $root"
env > "$root/w/stub.env"
write_map() { printf 'stub-wrote\n' >> .ai-dlc-fixture-readsets.tsv; cp .ai-dlc-fixture-readsets.tsv "$root/w/map.written"; }
[ "${STUB_MODE:-ok}" = hang-late ] || write_map
case "${STUB_MODE:-ok}" in
  ok) exit 0 ;;
  fail) exit 1 ;;
  hang|hang-late)
    sleep 300 & echo "$!" >> "$STUB_PIDS"
    sleep 300 & echo "$!" >> "$STUB_PIDS"
    echo "$$" >> "$STUB_PIDS"
    : > "$STUB_READY"
    wait
    [ "$STUB_MODE" = hang ] || write_map ;;
esac
STUB_EOF

# mkrepo <dir> <wrapper-source>: a main checkout holding the wrapper, the stub and a tracked map.
mkrepo() {
  mkdir -p "$1/scripts" "$1/core/scripts" || return 1
  cp "$2" "$1/scripts/readset-stage1-run.sh" && cp "$STUB" "$1/core/scripts/derive-fixture-readsets.sh" || return 1
  printf 'fixture\tpath\nseeded-row\tcore/x\n' > "$1/.ai-dlc-fixture-readsets.tsv"
  ( cd "$1" && git init -q . && git add -A && gitc commit -qm seed ) || return 1
  [ -d "$1/.git" ] && cp "$1/.ai-dlc-fixture-readsets.tsv" "$1.map.orig"
}

# A STUB sysctl, first on PATH and alone in its directory so git/awk/date still resolve. It prints
# three DISTINCT loads, so a wrapper sampling the 5- or 15-minute figure records the wrong one. The
# wrapper calls `sysctl` by PATH (bare name in sample()), so no override is needed to reach it.
SBIN="$WORK/sbin"; mkdir -p "$SBIN" || broken "stub sysctl dir"
printf '#!/bin/sh\n[ "$1 $2" = "-n vm.loadavg" ] || exit 9\necho "{ 1.11 2.22 3.33 }"\n' > "$SBIN/sysctl" && chmod +x "$SBIN/sysctl" || broken "stub sysctl"
[ "$(PATH="$SBIN:$PATH" sysctl -n vm.loadavg)" = "{ 1.11 2.22 3.33 }" ] || broken "the stub sysctl is not first on PATH"
# An inherited replacement profile, which the wrapper must not pass to the deriver.
printf '(version 3)\n(allow default)\n' > "$WORK/narrow.sb"

# wrap_ok <wrapper-source> <tag>: the exit-0 run, driven from the dirty decoy with the stub sysctl
# first on PATH and AI_DLC_READSET_SANDBOX_PROFILE set. Echoes nothing; records failures. Returns 1
# if any property failed (the mutant scorer uses that).
wrap_ok() {
  local src="$1" t="$2" R="$WORK/wr/$2" rd L f
  mkrepo "$R/repo" "$src" || broken "mkrepo $t"
  rd="$R/run"; L="$R/ledger"; f=0
  ( cd "$DECOY" && PATH="$SBIN:$PATH" AI_DLC_READSET_SANDBOX_PROFILE="$WORK/narrow.sb" AI_DLC_READSET_STAGE1_LEDGER="$L" \
      FXCELL=wrap-ok bash "$R/repo/scripts/readset-stage1-run.sh" "$rd" ) > "$R/out" 2>&1; rc=$?
  # THE ENVIRONMENT ARM, with its control: the stub's env dump must exist and carry the ledger
  # variable the wrapper DID pass, so an absent profile variable is not an absent dump.
  grep -q '^AI_DLC_READSET_TRACE_ROOT=' "$rd/root/w/stub.env" 2>/dev/null || { echo "    [$t] the stub recorded no environment (control)"; f=1; }
  ! grep -q '^AI_DLC_READSET_SANDBOX_PROFILE=' "$rd/root/w/stub.env" 2>/dev/null \
    || { echo "    [$t] AI_DLC_READSET_SANDBOX_PROFILE reached the deriver"; f=1; }
  awk -F'\t' '$2 == "1.11" { n++ } END { exit !(n >= 2 && n == NR) }' "$rd/load.tsv" 2>/dev/null \
    || { echo "    [$t] load.tsv column 2 is not the stub's 1-minute load 1.11 on every sample: $(cut -f2 "$rd/load.tsv" 2>/dev/null | tr '\n' ' ')"; f=1; }
  [ "$rc" = 0 ] || { echo "    [$t] wrapper exited $rc: $(tail -2 "$R/out" | tr '\n' ' ')"; f=1; }
  cmp -s "$R/repo.map.orig" "$R/repo/.ai-dlc-fixture-readsets.tsv" || { echo "    [$t] the map was not restored"; f=1; }
  grep -qx 'stub-wrote' "$rd/root/w/map.written" 2>/dev/null || { echo "    [$t] the stub never rewrote the map (restore arm would be vacuous)"; f=1; }
  [ -z "$(git -C "$R/repo" status --porcelain)" ] || { echo "    [$t] the checkout is dirty after the run"; f=1; }
  awk -F'\t' -v rd="$rd" -v sha="$(git -C "$R/repo" rev-parse HEAD)" '
      NR == 1 && NF == 4 && $1 == rd && $2 == "started" && $3 ~ /^[0-9]+$/ && $4 == sha { s = $3; n++ }
      NR == 2 && NF == 5 && $1 == rd && $2 == "0" && $3 == s && $4 ~ /^[0-9]+$/ && $3 <= $4 && $5 == sha { n++ }
      END { exit !(n == 2 && NR == 2) }' "$L" 2>/dev/null \
    || { echo "    [$t] the ledger does not hold exactly <rd> started <start> <HEAD> then <rd> 0 <start> <end> <HEAD>"; f=1; }
  [ ! -e "$R/repo/.git/ai-dlc-readset-stage1.ledger" ] || { echo "    [$t] the default ledger was written although the override was set"; f=1; }
  grep -qF "stub: argv: --list $SUBJ --tracer sandbox" "$rd/deriver.log" 2>/dev/null || { echo "    [$t] deriver.log lacks the five-subject sandbox argv"; f=1; }
  grep -qxF "stub: trace root: $rd/root" "$rd/deriver.log" 2>/dev/null || { echo "    [$t] the deriver was not handed RUN_DIR/root"; f=1; }
  [ "$(cat "$rd/rc" 2>/dev/null)" = 0 ] || { echo "    [$t] RUN_DIR/rc is not 0"; f=1; }
  awk -F'\t' 'NF == 2 && $1 ~ /^[0-9]+$/ && $2 ~ /^[0-9.]+$/ { n++ } END { exit !(n >= 2 && n == NR) }' "$rd/load.tsv" 2>/dev/null \
    || { echo "    [$t] RUN_DIR/load.tsv is not >= 2 epoch<TAB>load samples"; f=1; }
  for b in deriver.log rc load.tsv map.before; do
    [ -f "$rd/$b" ] || { echo "    [$t] $b is not beside root/"; f=1; }
    [ -z "$(find "$rd/root" -name "$b" 2>/dev/null)" ] || { echo "    [$t] $b was written under root/"; f=1; }
  done
  [ -n "$(find "$rd/root" -type f 2>/dev/null)" ] || { echo "    [$t] root/ is empty, so the not-under-root find saw nothing"; f=1; }
  return "$f"
}

# THE WAITS BELOW END ON AN EVENT OR ON A FACT, NEVER ON ELAPSED TIME OR A WINDOW OF POLLS (BL-868). Each
# waits for one event the wrapper or its stub produces (a `ready` file, a pgid file, a process exiting);
# `await` gives up only when the process that should produce it has EXITED first, or -- for a wait on a
# process ENDING -- when every process it waits on is BLOCKED WITH NO SIGNAL PENDING (st_settled): it was
# never signalled and nothing will end it. A signalled process is runnable, exiting or carries the signal
# pending, so a slow death on a loaded box never reads settled. The idle-seconds window this replaced
# refused a correct run whenever the box was slow enough. A wait that reaches neither blocks until the
# gate's own watchdog takes the run: a hang to read, never a verdict.
# st_blocked <pid>: 0 when alive, in state S/I/T and with no signal pending. A pid `ps` gives no state for
# is a refusal, exit 2, never a pass or a FAIL.
st_blocked() {
  local st pd
  kill -0 "$1" 2>/dev/null || return 1
  st="$(ps -o stat= -p "$1" 2>/dev/null | tr -d ' ')"; pd="$(ps -o pending= -p "$1" 2>/dev/null | tr -d ' ')"
  # No state (the read-set tracer's sandbox refuses the setuid /bin/ps): not known blocked, so the wait goes on
  # until the pid is gone. Only a survivor then hangs, and the tracer's own ceiling ends that run.
  [ -n "$st" ] || return 1
  case "$st" in S*|I*|T*) ;; *) return 1 ;; esac
  case "$pd" in ''|*[!0]*) return 1 ;; esac
}
# st_settled <pid file>: 0 when at least one recorded pid is alive and every live one is st_blocked.
st_settled() { local p n=0; while IFS= read -r p; do case "$p" in ''|*[!0-9]*) continue ;; esac; kill -0 "$p" 2>/dev/null || continue; st_blocked "$p" || return 1; n=$((n + 1)); done < "$1"; [ "$n" -gt 0 ]; }
# st_group_settled <pgid>: the same over a process group's live members.
st_group_settled() { local p n=0; for p in $(pgrep -g "$1" 2>/dev/null); do kill -0 "$p" 2>/dev/null || continue; st_blocked "$p" || return 1; n=$((n + 1)); done; [ "$n" -gt 0 ]; }
# st_tree_settled <pid file> <leader pid>: st_settled over the file's pids PLUS every live descendant of the
# leader. The TERMed wrapper's finish() also waits on its load sampler (stop_sampler: kill, then wait) and
# the sampler's own sleep, and neither is a pid the stub recorded: with the stub's tree already gone the
# wrapper alone sits blocked in that wait with nothing pending while the sampler dies, which reads settled
# although the wrapper is about to exit. Only a settled tree, sampler included, is a wrapper nothing will end.
st_tree_settled() {
  local t="$1.tree" p c g
  { cat "$1"; for p in $(pgrep -P "$2" 2>/dev/null); do echo "$p"; for c in $(pgrep -P "$p" 2>/dev/null); do echo "$c"; for g in $(pgrep -P "$c" 2>/dev/null); do echo "$g"; done; done; done; } > "$t"
  st_settled "$t"
}
AWAIT_WHY=""
# await <scope-dir> <watch-pid | -> <what> <test...> [-- <final test...>]: 0 once <test> holds; 1 with AWAIT_WHY
# set when the watched pid exited first, or when the optional final test holds (the awaited thing will never come).
await() {
  local sc="$1" wpid="$2" what="$3" t=() f=()
  shift 3
  while [ $# -gt 0 ] && [ "$1" != -- ]; do t+=("$1"); shift; done
  [ "${1:-}" = -- ] && { shift; f=("$@"); }
  while ! "${t[@]}"; do
    if [ "$wpid" != - ] && ! kill -0 "$wpid" 2>/dev/null; then
      "${t[@]}" && return 0
      AWAIT_WHY="process $wpid exited before $what"; return 1
    fi
    if [ "${#f[@]}" -gt 0 ] && "${f[@]}"; then
      "${t[@]}" && return 0
      AWAIT_WHY="$what will never happen: every process it waits on is blocked with no signal pending"; return 1
    fi
    sleep 0.1
  done
}
is_file() { [ -f "$1" ]; }
ready_and_pgid() { [ -f "$1" ] && [ -s "$2" ]; }
pid_gone() { ! kill -0 "$1" 2>/dev/null; }
group_gone() { ! kill -0 -- "-$1" 2>/dev/null; }
all_gone() { local p; while IFS= read -r p; do kill -0 "$p" 2>/dev/null && return 1; done < "$1"; return 0; }

# wrap_term <wrapper-source> <tag>: the wrapper is TERMed while the trap-less stub holds two
# background children. Prints the property lines; returns 1 if any failed.
wrap_term() {
  local src="$1" t="$2" R="$WORK/wr/$2" rd L f p n alive
  mkrepo "$R/repo" "$src" || broken "mkrepo $t"
  rd="$R/run"; L="$R/ledger"; f=0
  : > "$R/pids"
  FXCELL=wrap-term AI_DLC_READSET_STAGE1_LEDGER="$L" STUB_MODE=hang STUB_PIDS="$R/pids" STUB_READY="$R/ready" \
    bash "$R/repo/scripts/readset-stage1-run.sh" "$rd" > "$R/out" 2>&1 &
  wp=$!
  await "$R" "$wp" "the stub's ready file" is_file "$R/ready" \
    || { kill "$wp" 2>/dev/null; cat "$R/pids" >> "$ORPHANS"; broken "[$t] the stub never signalled ready: $AWAIT_WHY"; }
  cat "$R/pids" >> "$ORPHANS"
  kill -TERM "$wp"
  # The wrapper's finish() TERMs the stub's group and then WAITS on the stub, so the wrapper alone is briefly
  # blocked with nothing pending while its child is still dying: read alone that is a false settle at any
  # load. The settle set is the wrapper plus every pid the stub recorded, which are not all blocked until
  # the group kill has truly not reached them.
  { printf '%s\n' "$wp"; cat "$R/pids"; } > "$R/wp.pid"
  await "$R" - "the TERMed wrapper's exit" pid_gone "$wp" -- st_tree_settled "$R/wp.pid" "$wp" \
    || { kill -KILL "$wp" 2>/dev/null; broken "[$t] the TERMed wrapper did not exit: $AWAIT_WHY"; }
  wait "$wp"; rc=$?
  # THE ONE WALL BOUND, AND WHY IT CANNOT BE PROGRESS. The wrapper's finish() TERMs the stub's whole
  # process group but waits only on the stub itself, so its two `sleep 300` children can still be
  # dying when the wrapper returns. A signalled process exiting is a single step with nothing
  # observable in between, so nothing can be keyed on progress here; the property read is binary
  # (every recorded pid gone, or one alive), and the bound only says how long a pid may take to
  # die. It replaces a fixed `sleep 0.5`, which read a loaded box as a surviving tree. It must stay
  # far below the children's 300s, or a group kill that never happened would pass once they exit
  # on their own. NOW A FACT, NOT A BOUND: wait until every pid is gone or every survivor is blocked with
  # no signal pending (st_settled) -- a child the kill never reached; a TERMed one is never read so.
  while ! all_gone "$R/pids" && ! st_settled "$R/pids"; do sleep 0.1; done
  [ "$rc" = 143 ] || { echo "    [$t] the TERMed wrapper exited $rc, not 143"; f=1; }
  cmp -s "$R/repo.map.orig" "$R/repo/.ai-dlc-fixture-readsets.tsv" || { echo "    [$t] the map was not restored after TERM"; f=1; }
  grep -qx 'stub-wrote' "$rd/root/w/map.written" 2>/dev/null || { echo "    [$t] the stub never rewrote the map"; f=1; }
  awk -F'\t' -v rd="$rd" -v kt="$KILLTOK" 'NR == 1 && NF == 4 && $1 == rd && $2 == "started" { s = $3; n++ }
      NR == 2 && NF == 5 && $1 == rd && $2 == kt && $3 == s { n++ } END { exit !(n == 2 && NR == 2) }' "$L" 2>/dev/null \
    || { echo "    [$t] the ledger does not record the run as started then $KILLTOK"; f=1; }
  [ "$(cat "$rd/rc" 2>/dev/null)" = "$KILLTOK" ] || { echo "    [$t] RUN_DIR/rc is not '$KILLTOK'"; f=1; }
  alive=""; n=0
  while IFS= read -r p; do n=$((n + 1)); kill -0 "$p" 2>/dev/null && alive="$alive $p"; done < "$R/pids"
  [ "$n" = 3 ] || { echo "    [$t] the stub recorded $n pids, not 3"; f=1; }
  [ -z "$alive" ] || { echo "    [$t] the deriver's process tree survived the TERM:$alive"; f=1; }
  return "$f"
}

echo " the wrapper, against a stub deriver:"
if wrap_ok "$WRAPPER" ok; then B_wr_ok=1; ok "exit 0 run (driven from a dirty decoy repo, stub sysctl first on PATH, a replacement profile in the env): map restored, started + terminal ledger lines, load.tsv is the 1-min figure, profile not passed on, files beside root/ and not under it, override delivered"; else bad "the exit 0 run"; fi

R="$WORK/wr/fail"; mkrepo "$R/repo" "$WRAPPER" || broken "mkrepo fail"
FXCELL=wrap-fail AI_DLC_READSET_STAGE1_LEDGER="$R/ledger" STUB_MODE=fail bash "$R/repo/scripts/readset-stage1-run.sh" "$R/run" > "$R/out" 2>&1; rc=$?
if [ "$rc" = 1 ] && cmp -s "$R/repo.map.orig" "$R/repo/.ai-dlc-fixture-readsets.tsv" && grep -qx 'stub-wrote' "$R/run/root/w/map.written" \
   && awk -F'\t' '(NR == 1 && NF == 4 && $2 == "started") || (NR == 2 && NF == 5 && $2 == "1") { n++ } END { exit !(n == 2 && NR == 2) }' "$R/ledger" \
   && [ "$(cat "$R/run/rc")" = 1 ]; then
  ok "exit 1 run: wrapper exits 1, map restored, ledger says started then 1, RUN_DIR/rc says 1"
else
  bad "exit 1 run: rc=$rc"
fi

if wrap_term "$WRAPPER" term; then B_wr_term=1; ok "TERM: exit 143, map restored, ledger says $KILLTOK, and every pid in the stub's tree is gone"; else bad "the TERM run"; fi


# wrap_kill9 <wrapper-source> <tag>: SIGKILL, which no trap sees, against a stub that writes the
# map LAST, as the real deriver does. Three phases, in order:
#  (a) straight after the kill the map is CLEAN and the deriver is an orphan still alive in its own
#      process group; the next run refuses on the live orphan, adds no ledger line, makes no RUN_DIR;
#  (b) the orphan's children are ended, it reaches its final write and exits; the map is now dirty
#      and the next run refuses on the dirty tree;
#  (c) the ALLOW twin: the map checked out clean, the orphan gone, the started line still open --
#      the next run proceeds and exits 0. A wrapper that refused on any open started line, alive or
#      not, would pass (a) and (b) and wedge here.
# The sampler is orphaned by design and reaped here.
wrap_kill9() {
  local src="$1" t="$2" R="$WORK/wr/$2" rd L f p n out rc2 pg sp
  mkrepo "$R/repo" "$src" || broken "mkrepo $t"
  rd="$R/run"; L="$R/ledger"; f=0
  : > "$R/pids"
  FXCELL=wrap-late AI_DLC_READSET_STAGE1_LEDGER="$L" STUB_MODE=hang-late STUB_PIDS="$R/pids" STUB_READY="$R/ready" \
    bash "$R/repo/scripts/readset-stage1-run.sh" "$rd" > "$R/out" 2>&1 &
  wp=$!
  await "$R" "$wp" "the stub's ready file and the wrapper's pgid file" ready_and_pgid "$R/ready" "$rd/pgid" \
    || { kill "$wp" 2>/dev/null; cat "$R/pids" >> "$ORPHANS"; broken "[$t] the stub never signalled ready, or the wrapper wrote no pgid: $AWAIT_WHY"; }
  cat "$R/pids" >> "$ORPHANS"; cat "$rd/sampler.pid" >> "$ORPHANS" 2>/dev/null
  # CONTROL: RUN_DIR/pgid is the stub's own pid, which leads its process group (third STUB_PIDS line).
  pg="$(cat "$rd/pgid")"; sp="$(sed -n 3p "$R/pids")"
  [ -n "$pg" ] && [ "$pg" = "$sp" ] || { echo "    [$t] RUN_DIR/pgid reads '$pg', not the stub's pid '$sp'"; f=1; }
  kill -KILL "$wp"; { wait "$wp"; } 2>/dev/null; rc=$?
  [ "$rc" = 137 ] || { echo "    [$t] the SIGKILLed wrapper exited $rc, not 137"; f=1; }
  p="$(cat "$rd/sampler.pid" 2>/dev/null)"; [ -n "$p" ] && kill "$p" 2>/dev/null
  awk -F'\t' -v rd="$rd" -v sha="$(git -C "$R/repo" rev-parse HEAD)" \
      'NR == 1 && NF == 4 && $1 == rd && $2 == "started" && $3 ~ /^[0-9]+$/ && $4 == sha { n++ } END { exit !(n == 1 && NR == 1) }' "$L" 2>/dev/null \
    || { echo "    [$t] the ledger does not hold exactly the started line after SIGKILL"; f=1; }
  # (a) the map is CLEAN here -- the dirty-tree check is checked first and cannot be what refuses.
  cmp -s "$R/repo.map.orig" "$R/repo/.ai-dlc-fixture-readsets.tsv" || { echo "    [$t] the map is dirty straight after SIGKILL, so (a) cannot show the orphan refusal"; f=1; }
  kill -0 -- "-$pg" 2>/dev/null || { echo "    [$t] the orphaned process group $pg is not alive after SIGKILL"; f=1; }
  out="$(FXCELL=wrap-run2 AI_DLC_READSET_STAGE1_LEDGER="$L" STUB_MODE=ok bash "$R/repo/scripts/readset-stage1-run.sh" "$R/run2" 2>&1)"; rc2=$?
  case "$rc2|$out" in 2*"(process group $pg) is still alive"*) ;; *) echo "    [$t] (a) the run beside the live orphan did not refuse on it: rc=$rc2 $out"; f=1 ;; esac
  [ "$(grep -c . "$L")" = 1 ] || { echo "    [$t] (a) the refused run beside the orphan wrote to the ledger"; f=1; }
  [ ! -e "$R/run2" ] || { echo "    [$t] (a) the refused run beside the orphan created its RUN_DIR"; f=1; }
  # (b) end the orphan's two children: its `wait` returns, it writes the map LAST and exits.
  sed -n '1,2p' "$R/pids" | while IFS= read -r p; do kill "$p" 2>/dev/null; done
  # Its progress between here and its exit is the map write: `root/w/map.written` and the repo map.
  await "$R" - "the orphaned group $pg's exit" group_gone "$pg" -- st_group_settled "$pg" \
    || broken "[$t] the orphaned process group $pg did not exit after its children were ended: $AWAIT_WHY"
  grep -qx 'stub-wrote' "$rd/root/w/map.written" 2>/dev/null || { echo "    [$t] (b) the orphan never reached its final map write"; f=1; }
  cmp -s "$R/repo.map.orig" "$R/repo/.ai-dlc-fixture-readsets.tsv" && { echo "    [$t] (b) the map is clean after the orphan exited, so the dirty-tree refusal proves nothing"; f=1; }
  out="$(FXCELL=wrap-run3 AI_DLC_READSET_STAGE1_LEDGER="$L" STUB_MODE=ok bash "$R/repo/scripts/readset-stage1-run.sh" "$R/run3" 2>&1)"; rc2=$?
  case "$rc2|$out" in 2*"has uncommitted changes"*) ;; *) echo "    [$t] (b) the run after the orphan wrote the map did not refuse on the dirty map: rc=$rc2 $out"; f=1 ;; esac
  [ "$(grep -c . "$L")" = 1 ] || { echo "    [$t] (b) the refused run on the dirty map wrote to the ledger"; f=1; }
  [ ! -e "$R/run3" ] || { echo "    [$t] (b) the refused run on the dirty map created its RUN_DIR"; f=1; }
  # (c) the ALLOW twin.
  git -C "$R/repo" checkout -q -- .ai-dlc-fixture-readsets.tsv || broken "[$t] cannot check the map out clean"
  out="$(FXCELL=wrap-run4 AI_DLC_READSET_STAGE1_LEDGER="$L" STUB_MODE=ok bash "$R/repo/scripts/readset-stage1-run.sh" "$R/run4" 2>&1)"; rc2=$?
  [ "$rc2" = 0 ] || { echo "    [$t] (c) with the orphan gone and the map clean the next run did not proceed: rc=$rc2 $out"; f=1; }
  return "$f"
}
if wrap_kill9 "$WRAPPER" kill9; then B_wr_kill9=1; ok "SIGKILL: exit 137, the started line alone; (a) map clean, orphan alive, next run refuses on the orphan; (b) orphan writes the map and exits, next run refuses on the dirty tree; (c) map clean and orphan gone, next run proceeds"; else bad "the SIGKILL run"; fi

# The refusals: exit 2, the reason, and NOTHING recorded or created. ONE refusal runs end to end (the exit-2 CLI
# outcome, so the wiring of the guarded entry stays tested); the rest ask stage1_preflight IN PROCESS -- the
# function the CLI calls first -- from the repo's own copy of the wrapper, sourced in a subshell, so the
# root it resolves is the copy's, exactly as the CLI's BASH_SOURCE walk resolves it.
# pre_in <wrapper copy> <ledger> <rundir>: stage1_preflight in process; prints its output, returns its exit.
pre_in() { ( AI_DLC_READSET_STAGE1_LEDGER="$2"; export AI_DLC_READSET_STAGE1_LEDGER; . "$1" || exit 9; stage1_preflight "$3" ) 2>&1; }
refusal() { # refusal <tag> <reason> <rundir> <wrapper> [cli] -- run with the ledger override
  local L="$WORK/wr/$1.ledger" out rc
  if [ "${5:-}" = cli ]; then out="$(FXCELL=wrap-refuse-dirty-tree AI_DLC_READSET_STAGE1_LEDGER="$L" STUB_MODE=ok bash "$4" "$3" 2>&1)"; rc=$?
  else out="$(pre_in "$4" "$L" "$3")"; rc=$?; fi
  if [ "$rc" = 2 ] && case "$out" in *"$2"*) true ;; *) false ;; esac && [ ! -e "$L" ]; then
    ok "refuses $1: exit 2, '$2', no ledger line${5:+ (end to end)}"
  else
    bad "refusal $1: rc=$rc out=$out ledger=$([ -e "$L" ] && echo present || echo absent)"
  fi
}
R="$WORK/wr/dirty"; mkrepo "$R/repo" "$WRAPPER" || broken "mkrepo dirty"; printf 'x\n' > "$R/repo/dirt"
refusal dirty-tree "has uncommitted changes" "$R/run" "$R/repo/scripts/readset-stage1-run.sh" cli
[ ! -e "$R/run" ] && ok "dirty-tree refusal created no RUN_DIR" || bad "dirty-tree refusal created RUN_DIR"
R="$WORK/wr/exists"; mkrepo "$R/repo" "$WRAPPER" || broken "mkrepo exists"; mkdir -p "$R/run"; printf 'mine\n' > "$R/run/keep"
refusal existing-run-dir "already exists; RUN_DIR must be new" "$R/run" "$R/repo/scripts/readset-stage1-run.sh"
[ ! -e "$R/run/map.before" ] && [ "$(cat "$R/run/keep")" = mine ] && ok "existing RUN_DIR left untouched" || bad "existing RUN_DIR was written into"
R="$WORK/wr/linked"; mkrepo "$R/repo" "$WRAPPER" || broken "mkrepo linked"
git -C "$R/repo" worktree add -q --detach "$R/wt" 2>/dev/null || broken "git worktree add"
[ -f "$R/wt/.git" ] || broken "the linked worktree has no .git file"
refusal linked-worktree "is a LINKED worktree" "$R/run" "$R/wt/scripts/readset-stage1-run.sh"
R="$WORK/wr/inside"; mkrepo "$R/repo" "$WRAPPER" || broken "mkrepo inside"
refusal run-dir-inside-checkout "is inside the checkout" "$R/repo/run" "$R/repo/scripts/readset-stage1-run.sh"
# THE DEFAULT LEDGER, in process: with no override, stage1_preflight resolves the ledger to the git common dir's
# file, and stage1_started writes its started line there (control: the override cell above wrote to its own file).
R="$WORK/wr/default"; mkrepo "$R/repo" "$WRAPPER" || broken "mkrepo default"
out="$( ( unset AI_DLC_READSET_STAGE1_LEDGER; . "$R/repo/scripts/readset-stage1-run.sh" || exit 9
          stage1_preflight "$R/run" && stage1_state && stage1_started && printf 'LEDGER=%s\n' "$LEDGER" ) 2>&1)"; rc=$?
n="$(grep -c . "$R/repo/.git/ai-dlc-readset-stage1.ledger" 2>/dev/null)" || n=0
want="$(cd "$R/repo/.git" && pwd -P)/ai-dlc-readset-stage1.ledger"
if [ "$rc" = 0 ] && [ "$n" = 1 ] && [ "$out" = "LEDGER=$want" ]; then ok "with no override the ledger is the git common dir's (stage1_preflight resolves it; stage1_started writes its line there)"
else bad "default ledger: rc=$rc lines=$n out=[$out] want LEDGER=$want"; fi

# ------------------------------------------------------------------ wrapper mutants ----
# THE WRAPPER'S PROPERTIES, ASKED IN PROCESS. Each cell sources a wrapper copy (the shipping one, or a mutant) in a
# subshell -- its BASH_SOURCE guard keeps the launch from running -- and calls the ONE section the property lives in:
# sample (the load sampler), stage1_profile (the profile unset), stage1_started (the started line), stage1_preflight
# (the live-orphan refusal and its ALLOW twin), and finish (the map restore, and the deriver's process-group kill).
# The end-to-end runs above (exit 0, 1, 143, 137 and one refusal) keep the wiring between those sections tested; a
# mutant runs only the in-process cell its property decides, plus its twin.
# ic_<cell> <wrapper copy> <dir>: 0 when the property holds, else 1 with the why on stdout.
ic_repo() { mkrepo "$1" "$2" >/dev/null 2>&1 || broken "mkrepo $1"; }
ic_sample() { # sample() appends `<epoch>\t<1-min load>` to RUN_DIR/load.tsv, never under root/
  ( RUN_DIR="$2/run"; mkdir -p "$RUN_DIR/root"; PATH="$SBIN:$PATH"; . "$1" || exit 9
    sample; sample
    awk -F'\t' 'NF == 2 && $1 ~ /^[0-9]+$/ && $2 == "1.11" { n++ } END { exit !(n == 2 && NR == 2) }' "$RUN_DIR/load.tsv" 2>/dev/null \
      || { echo "load.tsv column 2 is not the stub's 1-minute load 1.11 on both samples, beside root/: $(cut -f2 "$RUN_DIR/load.tsv" 2>/dev/null | tr '\n' ' ')"; exit 1; }
    [ ! -e "$RUN_DIR/root/load.tsv" ] || { echo "load.tsv was written under root/"; exit 1; } )
}
ic_profile() { # stage1_profile removes an inherited AI_DLC_READSET_SANDBOX_PROFILE from what the deriver inherits
  ( AI_DLC_READSET_SANDBOX_PROFILE="$WORK/narrow.sb"; export AI_DLC_READSET_SANDBOX_PROFILE; . "$1" || exit 9
    [ -n "${AI_DLC_READSET_SANDBOX_PROFILE:-}" ] || { echo "control: the profile variable was not set before the call"; exit 1; }
    stage1_profile
    ! env | grep -q '^AI_DLC_READSET_SANDBOX_PROFILE=' || { echo "AI_DLC_READSET_SANDBOX_PROFILE reached the deriver's environment"; exit 1; } )
}
ic_started() { # stage1_started writes exactly `<rd> started <epoch> <HEAD>` before any launch
  ic_repo "$2/repo" "$1"
  ( L="$2/ledger"; AI_DLC_READSET_STAGE1_LEDGER="$L"; export AI_DLC_READSET_STAGE1_LEDGER; . "$2/repo/scripts/readset-stage1-run.sh" || exit 9
    stage1_preflight "$2/run" > /dev/null 2>&1 || { echo "control: preflight refused a clean repo"; exit 1; }
    stage1_state; stage1_started
    awk -F'\t' -v rd="$RUN_DIR" -v sha="$HEAD_SHA" -v s="$START" \
        'NR == 1 && NF == 4 && $1 == rd && $2 == "started" && $3 == s && $4 == sha { n++ } END { exit !(n == 1 && NR == 1) }' "$L" 2>/dev/null \
      || { echo "the ledger does not hold exactly the started line after stage1_started"; exit 1; } )
}
# THE ORPHAN WORLD: a ledger whose last line is an open `started` line, its RUN_DIR/pgid naming a process group
# this cell started under `set -m` (a sleeping leader). orphan-live: the group is alive, preflight must refuse on
# it; orphan-dead: the same ledger with the group gone, preflight must pass (the ALLOW twin, one property apart).
ic_orphan() { # <wrapper copy> <dir> <live|dead>
  local pg rc out
  ic_repo "$2/repo" "$1"
  mkdir -p "$2/open"; printf '%s\tstarted\t%s\t%s\n' "$2/open" "$(date +%s)" deadbeef > "$2/ledger"
  set -m; sleep 300 </dev/null >/dev/null 2>&1 & pg=$!; set +m
  echo "$pg" >> "$ORPHANS"; printf '%s\n' "$pg" > "$2/open/pgid"
  if [ "$3" = dead ]; then kill "$pg" 2>/dev/null; wait "$pg" 2>/dev/null; fi
  if [ "$3" = live ] && ! kill -0 -- "-$pg" 2>/dev/null; then echo "control: the seeded orphan group $pg is not alive"; return 1; fi
  out="$(pre_in "$2/repo/scripts/readset-stage1-run.sh" "$2/ledger" "$2/run")"; rc=$?
  kill "$pg" 2>/dev/null; wait "$pg" 2>/dev/null
  if [ "$3" = live ]; then
    case "$rc|$out" in 2*"(process group $pg) is still alive"*) return 0 ;; esac
    echo "(a) the run beside the live orphan did not refuse on it: rc=$rc $out"; return 1
  fi
  [ "$rc" = 0 ] || { echo "with the orphan gone the preflight did not proceed: rc=$rc $out"; return 1; }
}
ic_restore() { # finish() copies map.before back over a map the deriver rewrote, byte-identically
  ic_repo "$2/repo" "$1"
  ( AI_DLC_READSET_STAGE1_LEDGER="$2/ledger"; export AI_DLC_READSET_STAGE1_LEDGER; . "$2/repo/scripts/readset-stage1-run.sh" || exit 9
    stage1_preflight "$2/run" > /dev/null 2>&1 || { echo "control: preflight refused a clean repo"; exit 1; }
    stage1_state
    printf 'stub-wrote\n' >> "$MAP"; cmp -s "$SNAP" "$MAP" && { echo "control: the map rewrite changed nothing"; exit 1; }
    finish > /dev/null 2>&1
    cmp -s "$2/repo.map.orig" "$MAP" || { echo "the map was not restored by finish"; exit 1; } )
  local r=$?
  [ "$r" = 3 ] && echo "finish exited 3: the map was not restored by finish"
  [ "$r" = 0 ]
}
ic_groupkill() { # finish() TERMs the deriver's whole process group: a trap-less leader and its two children all end
  ic_repo "$2/repo" "$1"
  : > "$2/pids"
  ( AI_DLC_READSET_STAGE1_LEDGER="$2/ledger"; export AI_DLC_READSET_STAGE1_LEDGER; . "$2/repo/scripts/readset-stage1-run.sh" || exit 9
    stage1_preflight "$2/run" > /dev/null 2>&1 || { echo "control: preflight refused a clean repo"; exit 1; }
    stage1_state
    # The leader is a fresh trap-less bash with two background children, as the stub deriver is; `set -m` around
    # its launch gives it its own process group, exactly as stage1_launch does.
    set -m
    PF="$2/pids" bash -c 'sleep 300 </dev/null >/dev/null 2>&1 & echo "$!" >> "$PF"; sleep 300 </dev/null >/dev/null 2>&1 & echo "$!" >> "$PF"; wait' </dev/null >/dev/null 2>&1 &
    DPID=$!
    set +m
    echo "$DPID" >> "$2/pids"
    while [ "$(grep -c . "$2/pids")" -lt 3 ] && kill -0 "$DPID" 2>/dev/null; do sleep 0.01; done
    [ "$(grep -c . "$2/pids")" = 3 ] || { echo "control: the seeded deriver group recorded $(grep -c . "$2/pids") pids, not 3"; exit 1; }
    finish > /dev/null 2>&1 )
  local r=$? p alive="" n=0
  cat "$2/pids" >> "$ORPHANS"
  [ "$r" = 0 ] || { echo "finish failed in the group-kill world (rc $r)"; return 1; }
  # As wrap_term's: gone, or every survivor blocked with no signal pending -- one the kill never reached.
  while ! all_gone "$2/pids" && ! st_settled "$2/pids"; do sleep 0.1; done
  while IFS= read -r p; do kill -0 "$p" 2>/dev/null && alive="$alive $p"; done < "$2/pids"
  [ -z "$alive" ] || { echo "the deriver's process tree survived the TERM:$alive"; return 1; }
}
IC_CELLS="sample profile started orphan-live orphan-dead restore groupkill"
# wcell <script> <cell> <name>: 0 when the in-process cell holds under the script, else 1; the why-lines land in
# $WORK/wr/m-<name>-<cell>.why.
WCN=0
wcell() {
  local d
  WCN=$((WCN + 1)); d="$WORK/wr/ic-$3-$2-$WCN"; mkdir -p "$d"
  case "$2" in
    orphan-live) ic_orphan "$1" "$d" live ;;
    orphan-dead) ic_orphan "$1" "$d" dead ;;
    *) "ic_$2" "$1" "$d" ;;
  esac > "$WORK/wr/m-$3-$2.why" 2>&1
}
echo " the wrapper's sections, in process (the shipping wrapper):"
for c in $IC_CELLS; do
  if wcell "$WRAPPER" "$c" shipping; then
    ok "in process: $c holds under the shipping wrapper"
    case "$c" in
      sample) B_ic_sample=1 ;;
      profile) B_ic_profile=1 ;;
      started) B_ic_started=1 ;;
      orphan-live) B_ic_orphan_live=1 ;;
      orphan-dead) B_ic_orphan_dead=1 ;;
      restore) B_ic_restore=1 ;;
      groupkill) B_ic_groupkill=1 ;;
    esac
  else bad "in process: $c fails under the shipping wrapper: $(head -1 "$WORK/wr/m-shipping-$c.why")"; fi
done
# wmut <flag> <name> <decides csv> <twin cell | -> <old> <new> [<expected killed csv>]: KILLED iff a deciding
# cell's properties fail under the mutant; the twin cell is GREEN under it. Matrix mode runs the remaining
# cells and prints every one; <expected> overrides the deciding set for a row dead in every cell.
wmut() {
  local flag="$1" name="$2" decides="$3" twin="$4" dst="$MD/w-$2.sh" c ks="" cells=""
  export MUT_OLD="$5" MUT_NEW="$6"
  mut "$WRAPPER" "$dst" || { bad "wrapper mutant $name DID NOT APPLY"; return; }
  for c in ${decides//,/ }; do
    if wcell "$dst" "$c" "$name"; then bad "wrapper mutant $name SURVIVED on $c"
    else mutant_killed "$flag" "$name" "wrapper mutant $name KILLED on $c (applied; twin $twin; $(head -1 "$WORK/wr/m-$name-$c.why" | sed 's/^ *//'))"; fi
  done
  if [ "$twin" != - ]; then wcell "$dst" "$twin" "$name" && ok "wrapper mutant $name leaves its twin $twin green" || bad "wrapper mutant $name is not confined: its twin $twin fails under it"; fi
  if [ "$MATRIX" = 1 ]; then
    for c in $IC_CELLS; do
      MCELLS=$((MCELLS + 1))
      if wcell "$dst" "$c" "$name"; then cells="$cells $c:0"; else cells="$cells $c:1"; ks="$ks,$c"; fi
      reap
    done
    echo "MATRIX $name$cells"
    mx_judge "$name" "${7:-$decides}" "${ks#,}"
  fi
}
echo " wrapper mutants:"
S1="sample() { printf '%s\\t%s\\n' \"\$(date +%s)\" \"\$(sysctl -n vm.loadavg | awk '{ print \$2 }')\" >> \"\$RUN_DIR/load.tsv\"; }"
wmut "${B_ic_sample:-0}" load-under-root sample profile "$S1" \
  "sample() { printf '%s\\t%s\\n' \"\$(date +%s)\" \"\$(sysctl -n vm.loadavg | awk '{ print \$2 }')\" >> \"\$RUN_DIR/root/load.tsv\"; }"
wmut "${B_ic_sample:-0}" load-5min sample profile "$S1" \
  "sample() { printf '%s\\t%s\\n' \"\$(date +%s)\" \"\$(sysctl -n vm.loadavg | awk '{ print \$3 }')\" >> \"\$RUN_DIR/load.tsv\"; }"
wmut "${B_ic_profile:-0}" profile-passed-through profile sample 'unset AI_DLC_READSET_SANDBOX_PROFILE' ': profile left in the environment'
wmut "${B_ic_started:-0}" no-started-line started sample "printf '%s\\tstarted\\t%s\\t%s\\n' \"\$RUN_DIR\" \"\$S_EPOCH\" \"\$HEAD_SHA\" >> \"\$LEDGER\" \\" ': \'
reap
# No orphan check: the run beside a live SIGKILLed deriver proceeds, which (a) refuses. The mutated line is
# read from the wrapper itself, whole, so the fixture restates none of the wrapper's refusal vocabulary.
OPEN_LINE="$(awk 'index($0, "if [ -n \"$OPEN_PG\" ] && kill -0 --") == 1 { print; exit }' "$WRAPPER")"
[ -n "$OPEN_LINE" ] || broken "no orphan-check line in $WRAPPER"
wmut "$(( ${B_ic_orphan_live:-0} && ${B_ic_orphan_dead:-0} ))" no-orphan-check orphan-live orphan-dead "$OPEN_LINE" ': orphan check removed'
if grep -q '(a) the run beside the live orphan did not refuse' "$WORK/wr/m-no-orphan-check-orphan-live.why" 2>/dev/null; then mutant_killed "${B_ic_orphan_live:-0}" no-orphan-check "the no-orphan-check mutant died on arm (a), the live-orphan refusal"; else bad "the no-orphan-check mutant did not die on arm (a)"; fi
reap
RESTORE='  cp -p "$SNAP" "$MAP" 2>/dev/null'
wmut "${B_ic_restore:-0}" no-restore restore groupkill "$RESTORE" '  :'
wmut "${B_ic_groupkill:-0}" single-pid-kill groupkill restore \
  '  if [ -n "$DPID" ]; then kill -TERM -- "-$DPID" 2>/dev/null; wait "$DPID" 2>/dev/null; fi' \
  '  if [ -n "$DPID" ]; then kill "$DPID" 2>/dev/null; wait "$DPID" 2>/dev/null; fi'
if grep -q 'process tree survived' "$WORK/wr/m-single-pid-kill-groupkill.why" 2>/dev/null; then mutant_killed "${B_ic_groupkill:-0}" single-pid-kill "the single-pid-kill mutant died on the process-tree arm (orphans: $(grep 'process tree' "$WORK/wr/m-single-pid-kill-groupkill.why" | sed 's/.*TERM://'))"; else bad "the single-pid-kill mutant did not die on the process-tree arm"; fi
reap

# ------------------------------------------------------------------ the deriver's tracer reaping (BL-466) ----
# The deriver reaps its fs_usage tracer with `pkill -P $$ -x fs_usage` at two sites. A bare
# `pkill -x fs_usage` killed EVERY fs_usage on the box, so parallel runs captured nothing and wrote
# rows that look like small read-sets. Each shipped line is extracted and EVALUATED in a deriver-shaped
# shell whose pipeline's left element is a symlinked stub, with a decoy forked by THIS fixture outside
# it: the child must die and the decoy must live. fs_usage needs root, so a real one is never started.
# THE STUB CARRIES A UNIQUE NAME, substituted for `fs_usage` in the extracted line, because a stub
# named `fs_usage` is killed by any other run's reaping on the same box -- measured, within 2.5 s --
# and a mutant must never reach a tracer this fixture did not start. The probe does NOT `wait` on the
# pipeline before the pkill: `wait` on a pipeline job blocks until its left element ends, which is
# the stub's whole sleep, after which both stubs are dead for a reason that is not the pkill.
echo " the deriver reaps only its own fs_usage (BL-466):"
CLAUSE='(allow file-read-metadata file-test-existence (literal "%s"))'
cl_count() { awk -v k="$CLAUSE" '{ l = $0; sub(/^[ \t]+/, "", l) } substr(l, 1, 1) != "#" && index($0, k) { n++ } END { print n + 0 }' "$1"; }
pk_lines() { # $1 deriver -> the uncommented lines carrying both `pkill` and `fs_usage`
  awk 'index($0, "pkill") && index($0, "fs_usage") { l = $0; sub(/^[ \t]+/, "", l); if (substr(l, 1, 1) != "#") print l }' "$1"
}
PKN="fsux$$"; PKB="$WORK/pkbin"; mkdir -p "$PKB" && ln -s /bin/sleep "$PKB/$PKN" || broken "cannot build the fs_usage stub"
# pk_probe <pkill line>: prints `child=<alive|dead> decoy=<alive|dead>`, or `child=none` if no child.
pk_probe() {
  local d="$WORK/pk.$$.$RANDOM" dec
  mkdir -p "$d" || return 1
  printf '%s\n' "${1//fs_usage/$PKN}" > "$d/line"
  cat > "$d/deriver.sh" <<'PK_EOF'
"$PKN" 60 2>/dev/null </dev/null | grep --line-buffered -F x > /dev/null &
fs_pid=$!
until child="$(pgrep -P $$ -x "$PKN")"; do kill -0 "$fs_pid" 2>/dev/null || break; sleep 0.01; done
[ -n "$child" ] || { echo "child=none"; exit 0; }
echo "$child" >> "$ORPHANS"
eval "$(cat "$PKD/line")"
while kill -0 "$child" 2>/dev/null; do
  st="$(ps -o stat= -p "$child" 2>/dev/null | tr -d ' ')"; pd="$(ps -o pending= -p "$child" 2>/dev/null | tr -d ' ')"
  case "$st:$pd" in [SIT]*:0) break ;; esac
  sleep 0.01
done
if kill -0 "$child" 2>/dev/null; then printf 'child=alive '; else printf 'child=dead '; fi
kill "$child" "$fs_pid" 2>/dev/null
PK_EOF
  PATH="$PKB:$PATH" "$PKN" 60 >/dev/null 2>&1 </dev/null & dec=$!
  echo "$dec" >> "$ORPHANS"
  PATH="$PKB:$PATH" PKN="$PKN" PKD="$d" ORPHANS="$ORPHANS" bash "$d/deriver.sh" </dev/null
  if kill -0 "$dec" 2>/dev/null; then echo "decoy=alive"; else echo "decoy=dead"; fi
  kill "$dec" 2>/dev/null; wait "$dec" 2>/dev/null
}
# pk_score <deriver> -> one verdict per extracted line, joined by `;`
pk_score() { local l; pk_lines "$1" | { [ -z "${2:-}" ] && cat || sed -n "${2}p"; } | while IFS= read -r l; do pk_probe "$l"; done | tr '\n' ';'; }
n="$(pk_lines "$DERIVER" | grep -c .)" || n=0
[ "$n" = 2 ] || broken "the deriver carries $n uncommented pkill fs_usage line(s), not the 2 reaping sites"
got="$(pk_score "$DERIVER")"
case "$got" in *none*) broken "the stub pipeline left no child of the deriver-shaped shell: $got" ;; esac
if [ "$got" = 'child=dead decoy=alive;child=dead decoy=alive;' ]; then B_pk=1; ok "both reaping lines kill the deriver's own stub tracer and leave a decoy outside it alive ($got)"; else bad "the deriver's reaping lines: $got (want child=dead decoy=alive at both sites)"; fi
# Mutants: every site edited (a fix layered on one site only reverts at both), on a COPY.
# pkmut <name> <awk gsub from> <awk gsub to>: decides pk-site1 (the first reaping line, probed alone per push),
# twin clause-count (the root-literal clause count on the same copy stays 3). Matrix mode scores both sites.
pkmut() {
  local dst="$MD/pk-$1.sh" c g cc
  awk -v f="$2" -v t="$3" -v CF="$dst.count" '{ c += gsub(f, t) } { print } END { print c + 0 > CF }' "$DERIVER" > "$dst" || { bad "pkill mutant $1 DID NOT APPLY"; return; }
  c="$(cat "$dst.count")"
  if [ "$c" != 2 ] || cmp -s "$DERIVER" "$dst"; then bad "pkill mutant $1 DID NOT APPLY ($c site(s))"; return; fi
  g="$(pk_score "$dst")"; cc="$(cl_count "$dst")"
  if [ "$g" = 'child=dead decoy=alive;child=dead decoy=alive;' ]; then bad "pkill mutant $1 SURVIVED ($g)"; else mutant_killed "${B_pk:-0}" "pk-$1" "pkill mutant $1 KILLED ($g; twin clause-count $cc)"; fi
  [ "$cc" = 3 ] || bad "pkill mutant $1 is not confined: the root-literal clause count is $cc under it, not 3"
  if [ "$MATRIX" = 1 ]; then
    MCELLS=$((MCELLS + 3))
    echo "MATRIX pk-$1 pk-site1:$([ "${g%%;*}" = 'child=dead decoy=alive' ] && echo 0 || echo 1) pk-site2:$([ "${g#*;}" = 'child=dead decoy=alive;' ] && echo 0 || echo 1) clause-count:$([ "$cc" = 3 ] && echo 0 || echo 1)"
  fi
}
pkmut bare 'pkill -P [$][$] -x fs_usage' 'pkill -x fs_usage'
pkmut wrong-parent 'pkill -P [$][$] -x fs_usage' 'pkill -P $PPID -x fs_usage'

# ------------------------------------------------------------------ the sandbox profile's root clause (BL-470) ----
# TEXT ARMS ONLY. Every profile emitter ends with an allow clause on the tree ROOT literal carrying no
# `(with report)`. Its BEHAVIOUR -- all three emitters rendered and run under sandbox-exec with
# `log stream` watching -- is core/fixtures/readset-sandbox-root-clause, kept out of this file because
# `log stream` refuses inside the sandbox tracer: an arm that SKIPs traced and passes untraced makes
# this fixture's verdict differ under the trace, and every trace discarded it. Nothing here execs
# `log` or `sandbox-exec`.
echo " the sandbox profile's root-literal clause (BL-470), text:"
n="$(cl_count "$DERIVER")"
if [ "$n" = 3 ]; then B_cl=1; ok "the root-literal clause is emitted by all three profile emitters (3 uncommented lines)"; else bad "the root-literal clause is on $n uncommented emitter line(s), not 3"; fi
OM="$MD/sb-one-emitter.sh"
awk -v k="$CLAUSE" '{ l = $0; sub(/^[ \t]+/, "", l) } index($0, k) && !index($0, "> \"$PROFILE\" \\") && substr(l, 1, 1) != "#" { print "      :"; c++; next } { print } END { exit c != 2 }' "$DERIVER" > "$OM" && ! cmp -s "$DERIVER" "$OM" \
  || bad "clause mutant one-emitter DID NOT APPLY"
n="$(cl_count "$OM")"
pkn="$(pk_lines "$OM" | grep -c .)" || pkn=0
if [ "$n" != 3 ]; then mutant_killed "${B_cl:-0}" sb-one-emitter "clause mutant one-emitter KILLED (the clause on $n emitter line(s); twin pk-sites $pkn)"; else bad "clause mutant one-emitter SURVIVED"; fi
[ "$pkn" = 2 ] || bad "clause mutant one-emitter is not confined: $pkn pkill fs_usage line(s) under it, not 2"
if [ "$MATRIX" = 1 ]; then MCELLS=$((MCELLS + 2)); echo "MATRIX sb-one-emitter clause-count:$([ "$n" != 3 ] && echo 1 || echo 0) pk-sites:$([ "$pkn" = 2 ] && echo 0 || echo 1)"; fi

# NO STUB PROCESS OUTLIVES THE FIXTURE, counted from the pid file every arm appended to -- never from
# the process table. The control is that the file holds pids at all. The property is binary: every
# recorded pid gone (a zombie counts as gone -- it has died and awaits only its reaper). A just-killed
# pid can read alive for a moment, so the read waits WHILE THE ALIVE SET SHRINKS, and decides only
# when that set has not changed for the stall window. The fixture's own `reap` has been sent to every
# recorded pid before this reads them -- the subject's tree kill is judged in wrap_term's own arm --
# and a recorded pid can be reused by an unrelated process. So a survivor is the harness's failure or
# an unreadable pid, never a verdict on the subject: it REFUSES, exit 2, and never FAILs on a count.
# orphans_gone <pidfile> <stall polls>: 0 when every pid is gone; 2 with ORPHANS_WHY on no progress.
orphans_gone() {
  local pf="$1" lim="$2" p live st last="" still=0
  ORPHANS_WHY=""
  while :; do
    live=""
    while IFS= read -r p; do
      case "$p" in ''|*[!0-9]*) continue ;; esac
      kill -0 "$p" 2>/dev/null || continue
      # `ps` is in tools.decl, but /bin/ps is setuid and the read-set tracer's sandbox refuses it. Refused, st is empty, a
      # zombie reads live, and the arm can only REFUSE (exit 2) on it -- never pass a survivor, never FAIL.
      st="$(ps -o stat= -p "$p" 2>/dev/null)"
      case "$st" in *Z*) continue ;; esac
      live="$live $p"
    done < "$pf"
    [ -z "$live" ] && return 0
    # FINAL ON A FACT (BL-868): every live recorded pid blocked with no signal pending will never die; a
    # just-killed one is runnable, exiting or carries the signal, at any load. <lim> is unused, kept for callers.
    for p in $live; do echo "$p"; done > "$WORK/og.live"
    if st_settled "$WORK/og.live"; then ORPHANS_WHY="recorded pid(s)$live alive, each blocked with no signal pending"; return 2; fi
    sleep 0.01
  done
}
# THE ARM'S OWN PROBE, BOTH DIRECTIONS, before it reads the corpus: a sleep that is never killed must
# refuse, and a reaped pid beside it in a second file must read gone.
OGP="$WORK/og-probe"; sleep 300 </dev/null >/dev/null 2>&1 & ogl=$!
bash -c 'exit 0' & ogd=$!; wait "$ogd"
printf '%s\n' "$ogl" > "$OGP.live"; printf '%s\n' "$ogd" > "$OGP.dead"
orphans_gone "$OGP.live" 50; ogr1=$?
orphans_gone "$OGP.dead" 50; ogr2=$?
kill "$ogl" 2>/dev/null; wait "$ogl" 2>/dev/null
if [ "$ogr1" = 2 ] && [ "$ogr2" = 0 ]; then B_og=1; ok "orphans_gone refuses on a pid that never dies (rc $ogr1) and passes a reaped pid (rc $ogr2)"; else bad "orphans_gone probe: live pid rc=$ogr1 (want 2), reaped pid rc=$ogr2 (want 0)"; fi
# MUTANT: the decision on a stall replaced by a pass, built as a copy of the function and scored by the same probe.
OGM="$MD/og-pass.sh"
awk '/^orphans_gone\(\) \{$/,/^}$/' "$HERE/run.sh" > "$OGM.src" 2>/dev/null
export MUT_OLD='    if st_settled "$WORK/og.live"; then ORPHANS_WHY="recorded pid(s)$live alive, each blocked with no signal pending"; return 2; fi' \
  MUT_NEW='    if st_settled "$WORK/og.live"; then return 0; fi'
mut "$OGM.src" "$OGM" \
  || broken "orphans_gone mutant og-pass DID NOT APPLY"
sleep 300 </dev/null >/dev/null 2>&1 & ogl=$!
printf '%s\n' "$ogl" > "$OGP.live"
( . "$OGM"; orphans_gone "$OGP.live" 50 ); ogr1=$?
printf '%s\n' "$ogd" > "$OGP.dead"; ( . "$OGM"; orphans_gone "$OGP.dead" 50 ); ogr2=$?
kill "$ogl" 2>/dev/null; wait "$ogl" 2>/dev/null
if [ "$ogr1" != 2 ]; then mutant_killed "${B_og:-0}" og-pass "orphans_gone mutant og-pass KILLED (a never-dying pid read rc $ogr1; twin reaped-pid rc $ogr2)"; else bad "orphans_gone mutant og-pass SURVIVED"; fi
[ "$ogr2" = 0 ] || bad "orphans_gone mutant og-pass is not confined: the reaped pid reads rc $ogr2, not 0"
if [ "$MATRIX" = 1 ]; then MCELLS=$((MCELLS + 2)); echo "MATRIX og-pass og-stall:$([ "$ogr1" != 2 ] && echo 1 || echo 0) og-reaped:$([ "$ogr2" = 0 ] && echo 0 || echo 1)"; fi
NREC="$(grep -c '^[0-9][0-9]*$' "$ORPHANS")" || NREC=0
if [ "$NREC" -lt 1 ]; then
  bad "the pid file records no stub or sampler pid, so the orphan check reads nothing"
else
  orphans_gone "$ORPHANS" 0 || broken "a stub or sampler pid outlived the fixture's own reap: $ORPHANS_WHY"
  ok "no stub or sampler pid is alive: 0 of $NREC recorded in the pid file"
fi

# A PLAIN RUN EXECUTES NO MATRIX-ONLY CELL (the counter only moves under --matrix).
if [ "$MATRIX" = 1 ]; then
  if [ "$MCELLS" -gt 0 ]; then ok "matrix mode drove $MCELLS matrix-only cell(s)"; else bad "matrix mode drove no matrix-only cell"; fi
else
  if [ "$MCELLS" = 0 ]; then ok "a plain run executed no matrix-only cell"; else bad "a plain run executed $MCELLS matrix-only cell(s)"; fi
fi

echo
if [ "$FAILS" -ne 0 ]; then
  echo "readset-stage1-verdict: $FAILS of $ASSERTS FAILED (work kept at $WORK)"
  exit 1
fi
case "$WORK" in */readset-stage1-fx.??????) rm -rf "$WORK" ;; esac
echo "readset-stage1-verdict: all $ASSERTS assertions hold"
exit 0
