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
# THE WRAPPER IS DRIVEN AGAINST A STUB DERIVER in a fresh scratch repo per arm: the wrapper runs
# `<root>/core/scripts/derive-fixture-readsets.sh` from the root it walks up to, so the stub sits at
# that path. The stub REWRITES the map and leaves a copy of what it wrote, so the restore arm is
# shown to be load-bearing rather than restoring a map nothing touched.
#
# CWD-INVARIANCE IS ASSERTED HERE, not inherited from how the suite is driven: the scorer's output
# on two worlds is byte-compared across three working directories, one a dirty decoy repo, and the
# wrapper's ok run is driven from inside that decoy.
#
# Usage: run.sh
# Exit:  0 = every arm and mutant holds, 1 = one regressed, 2 = fixture broken.
set -u

# Every ambient AI_DLC_* key is cleared (I10/I87): the subjects read AI_DLC_READSET_STAGE1_LEDGER,
# and an inherited one would point them at the operator's ledger. Each arm passes its own.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd -P)"
ROOT="$HERE"
while [ "$ROOT" != "/" ] && [ ! -f "$ROOT/scripts/readset-stage1-verdict.sh" ]; do ROOT="$(dirname "$ROOT")"; done
SCORER="$ROOT/scripts/readset-stage1-verdict.sh"
WRAPPER="$ROOT/scripts/readset-stage1-run.sh"
[ -f "$SCORER" ] && [ -f "$WRAPPER" ] || { echo "FIXTURE BROKEN: no scripts/readset-stage1-{verdict,run}.sh above $HERE" >&2; exit 2; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/readset-stage1-fx.XXXXXX")" || { echo "FIXTURE BROKEN: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd -P)"
ORPHANS="$WORK/orphans"; : > "$ORPHANS"
reap() { local p; [ -f "$ORPHANS" ] || return 0; while IFS= read -r p; do case "$p" in ''|*[!0-9]*) ;; *) kill "$p" 2>/dev/null ;; esac; done < "$ORPHANS"; }
trap reap EXIT

FAILS=0; ASSERTS=0
ok()     { printf '  ok    %s\n' "$1"; ASSERTS=$((ASSERTS + 1)); }
bad()    { printf '  FAIL  %s\n' "$1"; FAILS=$((FAILS + 1)); ASSERTS=$((ASSERTS + 1)); }
broken() { echo "readset-stage1-verdict: FIXTURE BROKEN: $*" >&2; echo "  (work kept at $WORK)" >&2; exit 2; }
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
  local rd="$1" i="$2" base fx s e
  base=$((T0 + i * 1000))
  mkdir -p "$rd/root/w" "$rd/root/m" || return 1
  cp -R "$TPL" "$rd/root/t" || return 1
  printf '(version 1)\n' > "$rd/root/w/sandbox.sb"
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
lline() { local base=$((T0 + $2 * 1000)); printf '%s\t%s\t%s\t%s\t%s\n' "$1" "${3:-0}" "$base" $((base + 60)) "$TPL_SHA"; }

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

# verdict <scorer> <world> [cwd] -> `rc|spec`. spec: MET / sorted tuples / the refusal line.
verdict() {
  local s="$1" w="$2" cwd="${3:-$WORK}" out rc
  out="$(cd "$cwd" && TMPDIR="$w/tmp" AI_DLC_READSET_STAGE1_LEDGER="$w/ledger" bash "$s" 2>&1)"; rc=$?
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
W="$(mkworld rl-short)" || broken seed; head -2 "$W/ledger" > "$W/l2"; mv "$W/l2" "$W/ledger"
want rl-short 2 "holds 2 run(s)"
W="$(mkworld rl-format)" || broken seed; { head -2 "$W/ledger"; printf '%s\t0\t%s\n' "$W/r3" $((T0 + 3000)); } > "$W/l3"; mv "$W/l3" "$W/ledger"
want rl-format 2 "RL ledger line 3 is not"
W="$(mkworld rl-missing)" || broken seed; { lline "$W/r1" 1; lline "$W/nowhere" 2; lline "$W/r3" 3; } > "$W/ledger"
want rl-missing 2 "RL run 2: $W/nowhere does not exist"
W="$(mkworld rl-rc)" || broken seed; { lline "$W/r1" 1; lline "$W/r2" 2 1; lline "$W/r3" 3; } > "$W/ledger"
want rl-rc 2 "RL run 2: $W/r2 is recorded with rc '1'"
W="$(mkworld rl-rcfile)" || broken seed; printf '1\n' > "$W/r2/rc"
want rl-rcfile 2 "RL run 2: $W/r2/rc reads '1'"
# THE DISCRIMINATING LEDGER for the skip mutant: FOUR lines, the first three good and the LAST bad.
# A three-line ledger with one bad line refuses under both the scorer and the mutant.
W="$(mkworld rl-skip)" || broken seed; seed_run "$W/r4" 4 || broken seed; printf 'killed\n' > "$W/r4/rc"; lline "$W/r4" 4 killed >> "$W/ledger"
want rl-skip 2 "RL run 3: $W/r4 is recorded with rc 'killed'"

# R0 -- a sandbox run.
W="$(mkworld r0-log)" || broken seed; log_sub "$W/r2/deriver.log" 'sandbox tracer: fixtures run as' "[00:10:00] fs_usage runs as root; fixtures run as 'fx'"
want r0-log 2 "R0 $W/r2: deriver.log carries no 'sandbox tracer"
W="$(mkworld r0-sb)" || broken seed; rm -f "$W/r3/root/w/sandbox.sb"
want r0-sb 2 "R0 $W/r3: root/w/sandbox.sb is absent"
# R1 -- the log is this root's.
W="$(mkworld r1)" || broken seed; log_sub "$W/r1/deriver.log" 'copying the tree to' "[00:10:01] copying the tree to /private/tmp/elsewhere/t"
want r1 2 "R1 $W/r1: deriver.log copied the tree to '/private/tmp/elsewhere/t'"
# R2 -- three distinct runs.
W="$(mkworld r2-link)" || broken seed; ln -s "$W/r1" "$W/r1link"; { lline "$W/r1" 1; lline "$W/r1link" 2; lline "$W/r3" 3; } > "$W/ledger"
want r2-link 2 "R2: two ledger lines resolve to one root"
W="$(mkworld r2-copy)" || broken seed; for fx in $SUBJ; do cp "$W/r1/root/w/$fx.raw" "$W/r2/root/w/$fx.raw"; done
want r2-copy 2 "R2: enforcement-map-sites.raw is byte-identical in two runs"
W="$(mkworld r2-overlap)" || broken seed; { lline "$W/r1" 1; printf '%s\t0\t%s\t%s\t%s\n' "$W/r2" $((T0 + 1030)) $((T0 + 2060)) "$TPL_SHA"; lline "$W/r3" 3; } > "$W/ledger"
want r2-overlap 2 "R2: the ledger windows are not time-ordered and disjoint"
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

# A1 alone, on a PREFIX-SHARING name: `-b` is OMITTED, `enforcement-map-sites` is not. The paths
# line is kept so A5 stays quiet (see the header).
W="$(mkworld a1)" || broken seed; printf '  %-32s OMITTED (fixture exited 1) -- will always run\n' enforcement-map-sites-b >> "$W/r2/deriver.log"
want a1 1 "$(tuples 'run2 enforcement-map-sites-b A1')"
# A2 alone: the drop notice is in the .win and nowhere in deriver.log.
W="$(mkworld a2)" || broken seed; printf '=== Messages dropped during live streaming ===\n' > "$W/r1/root/w/validator-arm-selection.win"
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
sp="$(TMPDIR="$WORK/w" bash "$SCORER" --self-probe 2>&1)"; rc=$?
case "$rc|$sp" in "0|self-probe: "*" probes answered as expected") ok "--self-probe exits 0 ($sp)" ;; *) bad "--self-probe: rc=$rc $sp" ;; esac
while IFS="$(printf '\t')" read -r name wrc wspec; do
  got="$(verdict "$SCORER" "$(w_of "$name")")"
  if matches "$got" "$wrc" "$wspec"; then ok "$name -> $got"; else bad "$name -> $got (want $wrc|$wspec)"; fi
done < "$TABLE"

# THE MET LINE NAMES THE SEEDED RUN DIRS -- the ledger override was delivered, not the default.
W="$(w_of met)"
out="$(TMPDIR="$W/tmp" AI_DLC_READSET_STAGE1_LEDGER="$W/ledger" bash "$SCORER" 2>&1)"
case "$out" in *"($W/r1, $W/r2, $W/r3)"*) ok "the MET line names the three seeded runs" ;; *) bad "the MET line does not name the seeded runs: $out" ;; esac
# THE A4 WINDOW ROUND-TRIPS the local-time .raw stamps to the seeded epochs.
W="$(w_of a4)"
out="$(TMPDIR="$W/tmp" AI_DLC_READSET_STAGE1_LEDGER="$W/ledger" bash "$SCORER" 2>&1)"
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
  a="$(verdict "$SCORER" "$(w_of "$name")" "$WORK")"; b="$(verdict "$SCORER" "$(w_of "$name")" /)"; c="$(verdict "$SCORER" "$(w_of "$name")" "$DECOY")"
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
echo " the probe-disabled control copy agrees with the shipping scorer:"
while IFS="$(printf '\t')" read -r name wrc wspec; do
  a="$(verdict "$SCORER" "$(w_of "$name")")"; b="$(verdict "$CTL" "$(w_of "$name")")"
  [ "$a" = "$b" ] || bad "control copy disagrees on $name: [$a] vs [$b]"
done < "$TABLE"
ok "control copy = shipping scorer on all $NWORLDS worlds"

# smut <name> <target-world> <old line> <new line> [probe]: a scorer mutant from the CONTROL copy
# (or, with `probe`, from the shipping scorer with its self-probe live). KILLED iff the target world
# answers differently from the table; it must still score the ALL-MET world MET (liveness).
smut() {
  local name="$1" world="$2" dst="$MD/$1.sh" wrc wspec got live
  export MUT_OLD="$3" MUT_NEW="$4"
  mut "$CTL" "$dst" || { bad "mutant $name DID NOT APPLY"; return; }
  live="$(verdict "$dst" "$(w_of met)")"
  [ "$live" = "0|MET" ] || { bad "mutant $name is not live: it scores the ALL-MET world $live"; return; }
  wrc="$(awk -F'\t' -v n="$world" '$1 == n { print $2 }' "$TABLE")"; wspec="$(awk -F'\t' -v n="$world" '$1 == n { print $3 }' "$TABLE")"
  got="$(verdict "$dst" "$(w_of "$world")")"
  if matches "$got" "$wrc" "$wspec"; then bad "mutant $name SURVIVED on $world ($got)"; else ok "mutant $name KILLED on $world (applied, live; mutant says $got)"; fi
}
echo " scorer mutants:"
smut del-A1 a1 '    a1_omitted "$rd/deriver.log" "$fx" "$label" || FAILED=1' '    :'
smut del-A2 a2 '    a2_dropped "$rd/root/w/$fx.win" "$fx" "$label" || FAILED=1' '    :'
smut del-A3 a3 '    a3_canary "$rd/root/w/$fx.canary" "$rd/deriver.log" "$fx" "$label" || FAILED=1' '    :'
smut del-A4 a4 '  a4_load "$rd/load.tsv" "$ws" "$we" "$label" || FAILED=1' '  :'
smut del-A5 a5 '    a5_paths "$rd/deriver.log" "$rd/root/w/$fx.set" "$fx" "$label" || FAILED=1' '    :'
smut del-A6 a6 '  a6_compare "$RD1" "$RD2" "$RD3" "$fx" "$SCRATCH" || FAILED=1' '  :'
smut a6-owntree a6-owntree \
  '    LC_ALL=C comm -12 "$s/a6.$i" "$s/a6.keep" > "$s/a6.f$i"' \
  '    eval "rd=\"\$$i\""; while IFS= read -r p; do if [ -e "$rd/root/t/$p" ] || [ -L "$rd/root/t/$p" ]; then printf "%s\n" "$p"; fi; done < "$s/a6.$i" > "$s/a6.f$i"'
smut a6-caret-git a6-gitignore \
  "    awk '\$0 != \"\" && \$0 != \".git\" && index(\$0, \".git/\") != 1' \"\$rd/root/w/\$fx.set\" | LC_ALL=C sort -u > \"\$s/a6.\$i\" \\" \
  "    awk '\$0 != \"\" && \$0 !~ /^\\.git/' \"\$rd/root/w/\$fx.set\" | LC_ALL=C sort -u > \"\$s/a6.\$i\" \\"
smut a1-substring a1 \
  "  hit=\"\$(awk -v f=\"\$2\" '\$1 == f && \$2 == \"OMITTED\" { print; exit }' \"\$1\")\"" \
  "  hit=\"\$(awk -v f=\"\$2\" 'index(\$1, f) == 1 && \$2 == \"OMITTED\" { print; exit }' \"\$1\")\""
smut a5-substring a5 \
  "  logged=\"\$(awk -v f=\"\$3\" '\$1 == f && \$3 == \"paths\" { print \$2; exit }' \"\$1\")\"" \
  "  logged=\"\$(awk -v f=\"\$3\" 'index(\$1, f) == 1 && \$3 == \"paths\" { print \$2; exit }' \"\$1\")\""
smut a2-reads-log a2 '    a2_dropped "$rd/root/w/$fx.win" "$fx" "$label" || FAILED=1' '    a2_dropped "$rd/deriver.log" "$fx" "$label" || FAILED=1'
smut a4-whole-file a4 '  cp="$(window_load "$1" "$2" "$3")"; peak="${cp#* }"' '  cp="$(window_load "$1" 0 99999999999)"; peak="${cp#* }"'
smut del-R0 r0-log '  why="$(r0_sandbox "$rd")" || refuse "$why"' '  :'
smut r2-string r2-link \
  '  a="$(cd "$1/root" 2>/dev/null && pwd -P)"; b="$(cd "$2/root" 2>/dev/null && pwd -P)"; c="$(cd "$3/root" 2>/dev/null && pwd -P)"' \
  '  a="$1/root"; b="$2/root"; c="$3/root"'
smut rl-skip rl-skip \
  "awk 'NF > 0' \"\$LEDGER\" | tail -n 3 > \"\$SCRATCH/last3\" || refuse \"cannot read the ledger \$LEDGER\"" \
  "awk -F'\\t' 'NF > 0 && \$2 == \"0\"' \"\$LEDGER\" | tail -n 3 > \"\$SCRATCH/last3\" || refuse \"cannot read the ledger \$LEDGER\""

# THE SCORER'S OWN SELF-PROBE must refuse the own-tree A6 filter: the same mutation applied to the
# SHIPPING scorer, self-probe live, exits 2 on --self-probe.
export MUT_OLD='    LC_ALL=C comm -12 "$s/a6.$i" "$s/a6.keep" > "$s/a6.f$i"'
export MUT_NEW='    eval "rd=\"\$$i\""; while IFS= read -r p; do if [ -e "$rd/root/t/$p" ] || [ -L "$rd/root/t/$p" ]; then printf "%s\n" "$p"; fi; done < "$s/a6.$i" > "$s/a6.f$i"'
if mut "$SCORER" "$MD/probe-owntree.sh"; then
  sp="$(TMPDIR="$MD" bash "$MD/probe-owntree.sh" --self-probe 2>&1)"; rc=$?
  if [ "$rc" = 2 ]; then ok "the scorer's --self-probe refuses an own-tree A6 filter (rc 2)"; else bad "the scorer's --self-probe passed an own-tree A6 filter (rc $rc: $sp)"; fi
else
  bad "self-probe own-tree mutant DID NOT APPLY"
fi

# ------------------------------------------------------------------ the wrapper ----
STUB="$WORK/stub.sh"
cat > "$STUB" <<'STUB_EOF'
#!/usr/bin/env bash
# A stub of core/scripts/derive-fixture-readsets.sh: NO trap, like the real deriver. It records its
# argv and trace root, rewrites the map, keeps a copy of what it wrote, then exits per STUB_MODE.
root="$AI_DLC_READSET_TRACE_ROOT"
mkdir -p "$root/w" "$root/m" "$root/t"
echo "stub: argv: $*"
echo "stub: trace root: $root"
printf 'stub-wrote\n' >> .ai-dlc-fixture-readsets.tsv
cp .ai-dlc-fixture-readsets.tsv "$root/w/map.written"
case "${STUB_MODE:-ok}" in
  ok) exit 0 ;;
  fail) exit 1 ;;
  hang)
    sleep 300 & echo "$!" >> "$STUB_PIDS"
    sleep 300 & echo "$!" >> "$STUB_PIDS"
    echo "$$" >> "$STUB_PIDS"
    : > "$STUB_READY"
    wait ;;
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

# wrap_ok <wrapper-source> <tag>: the exit-0 run, driven from the dirty decoy. Echoes nothing;
# records failures. Returns 1 if any property failed (the mutant scorer uses that).
wrap_ok() {
  local src="$1" t="$2" R="$WORK/wr/$2" rd L f
  mkrepo "$R/repo" "$src" || broken "mkrepo $t"
  rd="$R/run"; L="$R/ledger"; f=0
  ( cd "$DECOY" && AI_DLC_READSET_STAGE1_LEDGER="$L" bash "$R/repo/scripts/readset-stage1-run.sh" "$rd" ) > "$R/out" 2>&1; rc=$?
  [ "$rc" = 0 ] || { echo "    [$t] wrapper exited $rc: $(tail -2 "$R/out" | tr '\n' ' ')"; f=1; }
  cmp -s "$R/repo.map.orig" "$R/repo/.ai-dlc-fixture-readsets.tsv" || { echo "    [$t] the map was not restored"; f=1; }
  grep -qx 'stub-wrote' "$rd/root/w/map.written" 2>/dev/null || { echo "    [$t] the stub never rewrote the map (restore arm would be vacuous)"; f=1; }
  [ -z "$(git -C "$R/repo" status --porcelain)" ] || { echo "    [$t] the checkout is dirty after the run"; f=1; }
  awk -F'\t' -v rd="$rd" -v sha="$(git -C "$R/repo" rev-parse HEAD)" 'NF == 5 && $1 == rd && $2 == "0" && $3 ~ /^[0-9]+$/ && $4 ~ /^[0-9]+$/ && $3 <= $4 && $5 == sha { n++ } END { exit !(n == 1 && NR == 1) }' "$L" 2>/dev/null \
    || { echo "    [$t] the ledger does not hold exactly one line <rd> 0 <start> <end> <HEAD>"; f=1; }
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

# wrap_term <wrapper-source> <tag>: the wrapper is TERMed while the trap-less stub holds two
# background children. Prints the property lines; returns 1 if any failed.
wrap_term() {
  local src="$1" t="$2" R="$WORK/wr/$2" rd L f p n alive
  mkrepo "$R/repo" "$src" || broken "mkrepo $t"
  rd="$R/run"; L="$R/ledger"; f=0
  : > "$R/pids"
  AI_DLC_READSET_STAGE1_LEDGER="$L" STUB_MODE=hang STUB_PIDS="$R/pids" STUB_READY="$R/ready" \
    bash "$R/repo/scripts/readset-stage1-run.sh" "$rd" > "$R/out" 2>&1 &
  wp=$!
  n=0; while [ ! -f "$R/ready" ] && [ "$n" -lt 300 ]; do sleep 0.1; n=$((n + 1)); done
  [ -f "$R/ready" ] || { kill "$wp" 2>/dev/null; cat "$R/pids" >> "$ORPHANS"; broken "[$t] the stub never signalled ready"; }
  cat "$R/pids" >> "$ORPHANS"
  kill -TERM "$wp"; wait "$wp"; rc=$?
  sleep 0.5
  [ "$rc" = 143 ] || { echo "    [$t] the TERMed wrapper exited $rc, not 143"; f=1; }
  cmp -s "$R/repo.map.orig" "$R/repo/.ai-dlc-fixture-readsets.tsv" || { echo "    [$t] the map was not restored after TERM"; f=1; }
  grep -qx 'stub-wrote' "$rd/root/w/map.written" 2>/dev/null || { echo "    [$t] the stub never rewrote the map"; f=1; }
  awk -F'\t' -v rd="$rd" 'NF == 5 && $1 == rd && $2 == "killed" { n++ } END { exit !(n == 1 && NR == 1) }' "$L" 2>/dev/null \
    || { echo "    [$t] the ledger does not record the run as killed"; f=1; }
  [ "$(cat "$rd/rc" 2>/dev/null)" = killed ] || { echo "    [$t] RUN_DIR/rc is not 'killed'"; f=1; }
  alive=""; n=0
  while IFS= read -r p; do n=$((n + 1)); kill -0 "$p" 2>/dev/null && alive="$alive $p"; done < "$R/pids"
  [ "$n" = 3 ] || { echo "    [$t] the stub recorded $n pids, not 3"; f=1; }
  [ -z "$alive" ] || { echo "    [$t] the deriver's process tree survived the TERM:$alive"; f=1; }
  return "$f"
}

echo " the wrapper, against a stub deriver:"
if wrap_ok "$WRAPPER" ok; then ok "exit 0 run (driven from a dirty decoy repo): map restored, one ledger line, files beside root/ and not under it, override delivered"; else bad "the exit 0 run"; fi

R="$WORK/wr/fail"; mkrepo "$R/repo" "$WRAPPER" || broken "mkrepo fail"
AI_DLC_READSET_STAGE1_LEDGER="$R/ledger" STUB_MODE=fail bash "$R/repo/scripts/readset-stage1-run.sh" "$R/run" > "$R/out" 2>&1; rc=$?
if [ "$rc" = 1 ] && cmp -s "$R/repo.map.orig" "$R/repo/.ai-dlc-fixture-readsets.tsv" && grep -qx 'stub-wrote' "$R/run/root/w/map.written" \
   && awk -F'\t' 'NF == 5 && $2 == "1" { n++ } END { exit !(n == 1 && NR == 1) }' "$R/ledger" && [ "$(cat "$R/run/rc")" = 1 ]; then
  ok "exit 1 run: wrapper exits 1, map restored, ledger and RUN_DIR/rc say 1"
else
  bad "exit 1 run: rc=$rc"
fi

if wrap_term "$WRAPPER" term; then ok "TERM: exit 143, map restored, ledger says killed, and every pid in the stub's tree is gone"; else bad "the TERM run"; fi

R="$WORK/wr/default"; mkrepo "$R/repo" "$WRAPPER" || broken "mkrepo default"
STUB_MODE=ok bash "$R/repo/scripts/readset-stage1-run.sh" "$R/run" > "$R/out" 2>&1; rc=$?
n="$(grep -c . "$R/repo/.git/ai-dlc-readset-stage1.ledger" 2>/dev/null)" || n=0
if [ "$rc" = 0 ] && [ "$n" = 1 ]; then ok "with no override the ledger is the git common dir's"; else bad "default ledger: rc=$rc lines=$n"; fi

# The refusals: exit 2, the reason, and NOTHING recorded or created.
refusal() { # refusal <tag> <reason> <rundir> <wrapper> -- run with the ledger override
  local L="$WORK/wr/$1.ledger" out rc
  out="$(AI_DLC_READSET_STAGE1_LEDGER="$L" STUB_MODE=ok bash "$4" "$3" 2>&1)"; rc=$?
  if [ "$rc" = 2 ] && case "$out" in *"$2"*) true ;; *) false ;; esac && [ ! -e "$L" ]; then
    ok "refuses $1: exit 2, '$2', no ledger line"
  else
    bad "refusal $1: rc=$rc out=$out ledger=$([ -e "$L" ] && echo present || echo absent)"
  fi
}
R="$WORK/wr/dirty"; mkrepo "$R/repo" "$WRAPPER" || broken "mkrepo dirty"; printf 'x\n' > "$R/repo/dirt"
refusal dirty-tree "has uncommitted changes" "$R/run" "$R/repo/scripts/readset-stage1-run.sh"
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

# ------------------------------------------------------------------ wrapper mutants ----
# wmut <name> <old> <new> <ok|term>: KILLED iff the named run's properties fail under the mutant.
wmut() {
  local name="$1" dst="$MD/w-$1.sh"
  export MUT_OLD="$2" MUT_NEW="$3"
  mut "$WRAPPER" "$dst" || { bad "wrapper mutant $name DID NOT APPLY"; return; }
  if "wrap_$4" "$dst" "m-$name" > "$WORK/wr/m-$name.why" 2>&1; then
    bad "wrapper mutant $name SURVIVED"
  else
    ok "wrapper mutant $name KILLED (applied; $(head -1 "$WORK/wr/m-$name.why" | sed 's/^ *//'))"
  fi
}
echo " wrapper mutants:"
wmut load-under-root \
  "sample() { printf '%s\\t%s\\n' \"\$(date +%s)\" \"\$(sysctl -n vm.loadavg | awk '{ print \$2 }')\" >> \"\$RUN_DIR/load.tsv\"; }" \
  "sample() { printf '%s\\t%s\\n' \"\$(date +%s)\" \"\$(sysctl -n vm.loadavg | awk '{ print \$2 }')\" >> \"\$RUN_DIR/root/load.tsv\"; }" ok
wmut no-restore '  cp -p "$SNAP" "$MAP" 2>/dev/null' '  :' ok
wmut no-restore-on-term '  cp -p "$SNAP" "$MAP" 2>/dev/null' '  :' term
wmut single-pid-kill \
  '  if [ -n "$DPID" ]; then kill -TERM -- "-$DPID" 2>/dev/null; wait "$DPID" 2>/dev/null; fi' \
  '  if [ -n "$DPID" ]; then kill "$DPID" 2>/dev/null; wait "$DPID" 2>/dev/null; fi' term
grep -q 'process tree survived' "$WORK/wr/m-single-pid-kill.why" 2>/dev/null \
  && ok "the single-pid-kill mutant died on the process-tree arm (orphans: $(grep 'process tree' "$WORK/wr/m-single-pid-kill.why" | sed 's/.*TERM://'))" \
  || bad "the single-pid-kill mutant did not die on the process-tree arm"
reap

echo
if [ "$FAILS" -ne 0 ]; then
  echo "readset-stage1-verdict: $FAILS of $ASSERTS FAILED (work kept at $WORK)"
  exit 1
fi
case "$WORK" in */readset-stage1-fx.??????) rm -rf "$WORK" ;; esac
echo "readset-stage1-verdict: all $ASSERTS assertions hold"
exit 0
