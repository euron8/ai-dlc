#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# self-update-join-gate — prove the self-update gate refuses to cut a branch when the
# machinery slice cannot be green without the rulebook.
#
# THE DEFECT. Step 2 of ai-dlc-update installs MACHINERY and deliberately excludes the
# RULEBOOK, on the stated premise that "a fixture's subject is always machinery". That
# premise is false. Measured on the reference consumer pulling 0.249.0 -> 0.261.0, 7 of
# that tree's 109 fixtures are red in the state step 2 constructs, through two couplings:
# enforcement-map.yaml (machinery) is joined to CHECK_LOADED anchors in gate-validation.md
# (rulebook), and some fixtures assert on the shipped SKILL.md directly. The operator who
# hit this had to cut a branch, write 17 paths and run 43 fixtures to find out.
#
# THE ASSERTION THAT CARRIES THE RELEASE IS 3, NOT 1. An arm that defers whenever a fixture
# merely MENTIONS rulebook would defer on every pull, stranding the machinery slice for no
# reason — the exact false positive self-update-gate.sh's own header warns about. The arm
# is a DIFFERENTIAL: it fires only when the rulebook is ALSO about to change. Assertion 3
# is the one that proves it, and if it ever goes red this release has become the thing it
# was written to prevent.
#
# THE GATE RUNS GO THROUGH A POOL, AND THE REASON IS THE SUITE'S CRITICAL PATH. One gate
# invocation costs ~21s (it extracts each gating script at two refs and runs BOTH against a
# consumer tree), the six invocations below are independent, and run end to end they made
# this fixture the pre-push suite's pole: measured 248s against a 249s makespan, where the
# suite's own floor -- total unit cost over sixteen workers -- is ~159s. A pool's makespan is
# bounded below by its longest single unit, so a fixture that is internally serial sets the
# whole suite's wall clock no matter what AI_DLC_FIXTURE_JOBS is.
#
# ONE CONSUMER COPY PER RUN, which is a correctness requirement and not a tidiness one. The
# gate `cd`s into the consumer root and executes the incoming and current copies of every
# gating validator there. Three of the runs below take the same seeded consumer, so sharing
# one directory would have two of those validator executions writing in the same cwd at the
# same time -- an intermittent red that would look like a gate defect. A consumer copies in
# well under a second; the isolated form is also the cheap one.
#
# Usage: run.sh [--matrix]
#
# THE MUTANT MATRIX (mutant-battery rule). Each gate-run mutant is driven ONCE, in the pool, and that output is
# read through every arm whose predicate reads a gate output: a1 (DEFER), a2 (names the unanchored checks), a3 (no
# DEFER), a4 (the fixture-coupling arm). Mutant C is driven through the rc-pair harness and read through the rc22
# and rc11 cells. No arm adds a gate run, so the per-push gate-run count is unchanged. PER PUSH a mutant's
# DECIDING arm and its named TWIN are scored; with --matrix every arm is scored and printed as one
# `MATRIX <mutant> <arm> KILLED|GREEN` row. An arm is KILLED when its unmutated assertion no longer holds on the
# mutant's output. The block below is the one source; a plain run refuses a mutant with no row, and a cell that
# disagrees with its row is a failure. Arm tokens are the base-pass flag names without the B_ prefix.
# RE-MEASURE whenever an arm or a mutant is added or changed. hermetic-run.sh forwards no argument, so --matrix is
# run directly from the repo root of the branch, where seed.sh takes its range from range.sh (the same file
# git.decl's `range @range.sh` line derives the sandbox range from).
# MUTANT-MATRIX-REMEASURE bash core/fixtures/self-update-join-gate/run.sh --matrix
# MUTANT-MATRIX A decides=a2,a3 twins=a1
# MUTANT-MATRIX B decides=a2,a3 twins=a1
# MUTANT-MATRIX C decides=rc11 twins=rc22
# MUTANT-MATRIX F decides=lay,rec twins=nav
# A MATRIX row is a measurement and not a second kill emission: its kill goes through mutant_killed behind the
# base-pass flag of the cell's own arm. The mutant names reach mutant_killed as literals at their kill sites and
# as a variable in mx_cell.
# MUTANT-MATRIX-DYNAMIC mx_cell why=passes each of the mutant names A B C as a variable and every name keeps its own row
# MUTANT-MATRIX-CONTROL CONTROL why=the unmutated gate copy must reproduce the real DEFER verdict so a mutant's change is attributable
#
# ONE REAL SAFE-STOP WALK, ON r_old, AND EVERY OTHER GATE RUN PASSES `--no-safe-stop-advice`. A deferring classify
# spawns `advise_safe_stop`, a walk that runs one nested classify per release candidate in the range; no assertion
# here except the walk's own end-to-end proof reads a SAFE-STOP row, so the walk is kept on r_old alone and every
# other run (the registry, the rc-pair table, the copies and mutants) skips it. The flag skips that function and
# nothing else, and three arms hold it there: `nav` (the run prints NOT-A-VERDICT on stderr), `rec` and `lay` (under
# the flag the verdict record is still opened and the enclosed-layout refusal still fires), with mutant F -- the
# flag reusing the walk's own AI_DLC_GATE_IN_SAFE_STOP cost guard, which disables both -- killed by rec and lay.
# Arm `cs` holds the other half: no shipped caller passes the flag.
#
# r_noanchor's assertion reads its R1 UNDECIDED row, which R1 emits before any advise_safe_stop call, so its walk
# is skipped too; the arm still requires that row in the flagged run.
#
# EVERY GATE COPY IS A COPY OF THE WHOLE core/skills/ai-dlc-update/ TREE, its gate still named self-update-gate.sh.
# The gate resolves preclassify.sh beside itself (`dirname "$SELF_SRC"`) and preclassify.sh resolves
# ../fixture-manifest.md, so a lone copy runs arm C without its siblings; and the invocation budget's gate row
# counts a start by that path suffix, so the copies are counted as the gate starts they are.
set -uo pipefail
MATRIX=0
for _a in "$@"; do
  case "$_a" in
    --matrix) MATRIX=1 ;;
    *) echo "FIXTURE ERROR: unknown argument '$_a' (only --matrix)" >&2; exit 2 ;;
  esac
done

for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
D_ROOT="$(cd "$HERE/../../.." && pwd)"
GATE="$D_ROOT/core/skills/ai-dlc-update/reconcile/self-update-gate.sh"
FLAG=--no-safe-stop-advice

# Distribution-only, and say WHY accurately. The gate IS shipped to consumers (it lands at
# .claude/skills/ai-dlc-update/reconcile/), so "not present" would be a false reason. What a
# consumer lacks is the distribution's GIT HISTORY: this fixture derives BASE and THEIRS from
# the commit that adds a CHECK_LOADED anchor and installs two consumer trees from those refs.
# A skip whose stated reason is wrong is worse than no skip — it sends the next reader after
# a file that is sitting right there. The history test asks git, never `-d .git`: in a linked
# worktree `.git` is a FILE, so a directory test skipped this fixture green in normal use.
if [ ! -f "$GATE" ] || ! git -C "$D_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  echo "self-update-join-gate: SKIP — distribution-only (needs the distribution's git history to derive a check-adding range)"
  exit 0
fi

WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }
MUT_LIB="$(cd "$HERE/../lib" 2>/dev/null && pwd)/mutant.sh"
[ -f "$MUT_LIB" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $HERE" >&2; exit 2; }
. "$MUT_LIB"
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"
echo "self-update-join-gate:"

OUTD="$WORK/out"; mkdir -p "$OUTD"

# clone_tree <src> <dst> — one consumer-tree copy, APFS-cloned when the platform allows it.
#
# SEVEN OF THESE RUN PER FIXTURE (one here, six in the pool below) over a ~500-file installed
# consumer, and `cp -c` (clonefile(2)) makes each of them a metadata operation instead of a
# byte copy.
#
# THE FALLBACK IS MANDATORY AND SO IS THE `rm -rf` IN FRONT OF IT. `core/fixtures/` is
# installed into consumer trees: GNU `cp` has no `-c` at all, and macOS `cp -c` FAILS rather
# than degrading when source and destination are on different volumes or on a non-APFS one.
# Either way `cp -c` can die PARTWAY, leaving a half-tree that the gate would then read as a
# consumer missing files — so the destination is removed before the slow path re-copies it.
#
# ONE IMPLEMENTATION, EXPORTED RATHER THAN RESTATED. The pool below runs in a child `bash -c`,
# and a second copy of this logic there is a copy that can drift from this one. `export -f`
# carries the function into the child; if that import ever fails the child's copy step fails,
# the `.done` marker is never written, and the `dropped` arm reports it as a failure — the
# broken state is loud rather than a silently slower path nobody compares.
clone_tree() {
  rm -rf "$2"
  cp -Rc "$1" "$2" 2>/dev/null || { rm -rf "$2"; cp -R "$1" "$2"; }
}
export -f clone_tree

# ======================= PHASE 1: build the mutants, serially =======================
# Before the pool, because a mutant that did not build must be REPORTED rather than
# scheduled: `cmp -s` proves the sed landed and `bash -n` proves the result is still a
# program. A copy that is not a program dies instantly and its silence would otherwise
# score as a kill.
# gate_copy <name> -> the path of self-update-gate.sh in a fresh copy of the whole core/skills/ai-dlc-update/ tree
# under $WORK/g-<name>, or the empty string when the copy lacks the gate or its preclassify.sh sibling. The whole
# skill directory, not reconcile/ alone: preclassify.sh also resolves ../fixture-manifest.md beside its own dir.
gate_copy() {
  local d="$WORK/g-$1/core/skills/ai-dlc-update"
  mkdir -p "${d%/*}" && clone_tree "$D_ROOT/core/skills/ai-dlc-update" "$d" || return 0
  [ -f "$d/reconcile/self-update-gate.sh" ] && [ -f "$d/reconcile/preclassify.sh" ] && printf '%s\n' "$d/reconcile/self-update-gate.sh"
}
# gate_mutate <name> <sed program> -> the path of a copy whose gate is the sed of the real one (empty: no copy).
# A sed that dies leaves the copy's unmutated gate in place, which mut_state then reports as vacuous.
gate_mutate() {
  local g; g="$(gate_copy "$1")"
  [ -n "$g" ] || return 0
  sed "$2" "$GATE" > "$g.mut" && mv "$g.mut" "$g"
  printf '%s\n' "$g"
}
# mut_state <copy path> -> ok, vacuous, notaprogram or nocopy. Derived from the copy, because `$( )` sets nothing here.
mut_state() { if [ -z "$1" ]; then echo nocopy; elif cmp -s "$GATE" "$1"; then echo vacuous; elif ! bash -n "$1" 2>/dev/null; then echo notaprogram; else echo ok; fi; }
CTRL="$(gate_copy CTRL)"
[ -n "$CTRL" ] && cmp -s "$GATE" "$CTRL" || { echo "FIXTURE ERROR: the unmutated control copy of the skill tree did not build beside its preclassify.sh" >&2; exit 2; }

MUT_A="$(gate_mutate MUT_A 's/^    r1_missing=.*/    r1_missing=""/')"; MUT_A_BUILD="$(mut_state "$MUT_A")"
MUT_B="$(gate_mutate MUT_B 's/^if \[ -n "\$R2_RB" \]; then/if true; then/')"; MUT_B_BUILD="$(mut_state "$MUT_B")"
# MUTANT F -- the flag reuses the walk's own cost guard instead of a variable of its own. That one change disables
# the verdict record and the enclosed-layout refusal under the flag, which arms rec and lay must catch.
MUT_F="$(gate_mutate MUT_F 's/^  GATE_NO_SS_ADVICE=1$/  GATE_NO_SS_ADVICE=1; AI_DLC_GATE_IN_SAFE_STOP=1/')"; MUT_F_BUILD="$(mut_state "$MUT_F")"

# The anchor-stripped consumer for assertion 5, also built here: its absence is a FIXTURE
# BROKEN verdict rather than an assertion, so it must be settled before anything schedules.
NOANCHOR="$WORK/cons-noanchors"
clone_tree "$CONS_OLD" "$NOANCHOR"
GVC="$NOANCHOR/.claude/skills/ai-dlc/steps/gate-validation.md"
NOANCHOR_BUILD=ok
if [ -f "$GVC" ]; then
  sed 's/^<!-- CHECK_LOADED:/<!-- XX_LOADED:/' "$GVC" > "$GVC.mut" && mv "$GVC.mut" "$GVC"
else
  NOANCHOR_BUILD=missing
fi

# ============================ PHASE 2: run the gates in a pool ============================
# The registry is <label>\t<gate-script>\t<consumer-source>\t<first argument>. Runs are declared here and
# rendered in this order below, so the output is byte-comparable against the serial version
# this replaces — which is the differential the refactor had to produce. Column 4 is `-` on r_old alone, the one
# run whose SAFE-STOP walk is real; every other run passes the flag.
RUNS="$WORK/runs"
: > "$RUNS"
printf '%s\t%s\t%s\t%s\n' r_old      "$GATE"  "$CONS_OLD"     -       >> "$RUNS"
printf '%s\t%s\t%s\t%s\n' r_current  "$GATE"  "$CONS_CURRENT" "$FLAG" >> "$RUNS"
[ "$NOANCHOR_BUILD" = ok ] && printf '%s\t%s\t%s\t%s\n' r_noanchor "$GATE" "$NOANCHOR" "$FLAG" >> "$RUNS"
printf '%s\t%s\t%s\t%s\n' r_control  "$CTRL"  "$CONS_OLD"     "$FLAG" >> "$RUNS"
[ "$MUT_A_BUILD" = ok ] && printf '%s\t%s\t%s\t%s\n' r_muta "$MUT_A" "$CONS_OLD"     "$FLAG" >> "$RUNS"
[ "$MUT_B_BUILD" = ok ] && printf '%s\t%s\t%s\t%s\n' r_mutb "$MUT_B" "$CONS_CURRENT" "$FLAG" >> "$RUNS"

N_RUNS="$(grep -c . "$RUNS" || true)"
if [ "$N_RUNS" -lt 4 ]; then
  echo "FIXTURE ERROR: registered only $N_RUNS gate run(s) — the registry did not fill, so nothing below is evidence" >&2
  exit 2
fi

# SEVEN, and fixed rather than tunable for the reason the sibling pools state in place: this
# pool nests inside the pre-push suite's own, so a knob here multiplies against the knob
# there and the PRODUCT is what lands on the machine. Seven is the run count — there is no
# gain from a wider pool than there is work, and every slot beyond it is contention the
# sibling fixtures pay for.
SUJG_JOBS=7
AI_DLC_SUJG_OUT="$OUTD" AI_DLC_SUJG_RUNS="$RUNS" \
  AI_DLC_SUJG_DIST="$DIST" AI_DLC_SUJG_BASE="$BASE" AI_DLC_SUJG_THEIRS="$THEIRS" \
  xargs -P "$SUJG_JOBS" -I{} bash -c '
    l="$1"
    g="$(awk -F"\t" -v k="$l" "\$1==k{print \$2}" "$AI_DLC_SUJG_RUNS")"
    c="$(awk -F"\t" -v k="$l" "\$1==k{print \$3}" "$AI_DLC_SUJG_RUNS")"
    f="$(awk -F"\t" -v k="$l" "\$1==k{print \$4}" "$AI_DLC_SUJG_RUNS")"
    [ -n "$g" ] && [ -n "$c" ] && [ -n "$f" ] || exit 0
    set --; [ "$f" = - ] || set -- "$f"
    priv="$AI_DLC_SUJG_OUT/$l.consumer"
    clone_tree "$c" "$priv" || exit 0
    bash "$g" "$@" "$AI_DLC_SUJG_DIST" "$AI_DLC_SUJG_BASE" "$AI_DLC_SUJG_THEIRS" "$priv" \
      > "$AI_DLC_SUJG_OUT/$l.txt" 2> "$AI_DLC_SUJG_OUT/$l.err"
    printf done > "$AI_DLC_SUJG_OUT/$l.done"
    rm -rf "$priv"
  ' _ {} < <(cut -f1 "$RUNS")

# verdict <label> — the captured output, or the empty string if the job was dropped.
# A MISSING VERDICT IS A FAILURE, not a gap: serially a run that never happened could not
# produce a grep hit either, but it also could not be mistaken for one that did. `.done` is
# written after the run, so its absence means the pool dropped work.
# stdout and stderr are captured apart so the `nav` arm can say which stream carried the banner; verdict() prints
# both, as the merged capture this replaced did, so every other arm reads what it always read.
have() { [ -f "$OUTD/$1.done" ]; }
verdict() { cat "$OUTD/$1.txt" "$OUTD/$1.err" 2>/dev/null; }
# THE GATE'S REQUIRED SENTINEL IS PRINTED HERE, once r_old produced a verdict, so a run in which no gate executed
# cannot satisfy it.
have r_old && echo "HERMETIC-CONSUMED core/skills/ai-dlc-update/reconcile/self-update-gate.sh"
dropped() { bad "$1 produced no verdict — the pool dropped work, and a short green run reads exactly like a passing one"; }

# ===================== PHASE 3: evaluate, serially, in declaration order =====================

# --- the matrix, read off each mutant's own gate output (no extra gate run) ---------------------
MX_SRC="$HERE/run.sh"; MX_CELLS=0; MX_RUN=0; MX_SEEN=""
mx_row() { grep -m 1 -F -- "# MUTANT-MATRIX $1 decides=" "$MX_SRC"; }
mx_role() { # <mutant> <arm> -> D (decides), T (twin) or - (neither), read from the header block
  local line d tw; line="$(mx_row "$1")"
  [ -n "$line" ] || { echo -; return; }
  d="${line#*decides=}"; d="${d%% *}"; tw="${line#*twins=}"; tw="${tw%% *}"
  case ",$d," in *",$2,"*) echo D; return ;; esac
  case ",$tw," in *",$2,"*) echo T; return ;; esac
  echo -
}
mx_has_row() { [ -n "$(mx_row "$1")" ]; }
# mx_holds <arm> <gate output> -> 0 when that arm's unmutated assertion still holds on the output
mx_holds() {
  case "$1" in
    a1) grep -q 'SELF-UPDATE-DEFER' <<<"$2" ;;
    a2) grep -q 'whose CHECK_LOADED anchor lives in' <<<"$2" && grep -qE 'check\(s\) \[[A-Za-z0-9]' <<<"$2" ;;
    a3) ! grep -q 'SELF-UPDATE-DEFER' <<<"$2" ;;
    a4) grep -q 'rulebook-coupled-fixtures' <<<"$2" ;;
    rc22) [ "$2" = "SELF-UPDATE-OK" ] ;;
    rc11) [ "$2" = "SELF-UPDATE-OK" ] ;;
    lay) awk -F'\t' '$1 == "SELF-UPDATE-UNDECIDED" && $2 == "pre-push" && $3 ~ /UNSUPPORTED LAYOUT/ {f = 1} END {exit !f}' <<<"$2" ;;
    rec) grep -q '^record: ' <<<"$2" && grep -qx 'RECORD-FILE-PRESENT' <<<"$2" ;;
    nav) grep -q 'NOT-A-VERDICT' <<<"$2" ;;
  esac
}
mx_flag() { case "$1" in a1) echo "${B_a1:-0}" ;; a2) echo "${B_a2:-0}" ;; a3) echo "${B_a3:-0}" ;; a4) echo "${B_a4:-0}" ;; rc22) echo "${B_rc22:-0}" ;; rc11) echo "${B_rc11:-0}" ;; lay) echo "${B_lay:-0}" ;; rec) echo "${B_rec:-0}" ;; nav) echo "${B_nav:-0}" ;; esac; }
# mx_cell <mutant> <arm> <the output the arm reads>
mx_cell() {
  local m="$1" t="$2" role
  case " $MX_SEEN " in
    *" $m "*) ;;
    *) MX_SEEN="$MX_SEEN $m"
       if ! mx_has_row "$m"; then bad "mutant $m has no MUTANT-MATRIX row in $MX_SRC -- a per-push run cannot know its deciding arm or its twins"; fi ;;
  esac
  role="$(mx_role "$m" "$t")"
  if [ "$MATRIX" != 1 ] && [ "$role" = - ]; then return 0; fi
  [ "$role" = - ] && MX_CELLS=$((MX_CELLS + 1))
  MX_RUN=$((MX_RUN + 1))
  if mx_holds "$t" "$3"; then
    ok "MATRIX $m $t GREEN"
    if [ "$MATRIX" != 1 ] && [ "$role" = D ]; then bad "mutant $m SURVIVED its deciding arm $t"; fi
  else
    mutant_killed "$(( $(mx_flag "$t") && ${B_ctl:-0} ))" "$m" "MATRIX $m $t KILLED"
    if [ "$MATRIX" != 1 ] && [ "$role" = T ]; then bad "mutant $m tripped arm $t, which the header names as its twin"; fi
  fi
}
mx_gate() { mx_cell "$1" a1 "$2"; mx_cell "$1" a2 "$2"; mx_cell "$1" a3 "$2"; mx_cell "$1" a4 "$2"; }

out="$(verdict r_old)"

# --- Assertion 1: a rulebook-joined pull DEFERS --------------------------------
if ! have r_old; then dropped r_old
elif grep -q 'SELF-UPDATE-DEFER' <<<"$out"; then
  ok "a pull whose map declares checks the consumer has no anchor for DEFERS"; B_a1=1
else
  bad "the gate returned no DEFER for a rulebook-joined pull — step 2 would cut a branch, write the slice, run the fixtures and revert"
  printf '%s\n' "$out" | sed 's/^/        /' | head -4
fi

# --- Assertion 2: it NAMES the missing anchors ---------------------------------
# The operator who hit this had to derive the collapsed ordering by hand. A defer that
# does not say which checks are unanchored costs exactly that again.
# Do not hardcode WHICH check: the seed derives its range from history, so the unanchored
# id moves as releases land. Require that the message names at least one concrete id.
if ! have r_old; then dropped r_old
elif grep -q 'whose CHECK_LOADED anchor lives in' <<<"$out" && grep -qE 'check\(s\) \[[A-Za-z0-9]' <<<"$out"; then
  ok "the defer NAMES the unanchored check ids rather than only announcing a conflict"; B_a2=1
else
  bad "the defer does not name the unanchored checks — the operator must re-derive them by hand"
fi

# --- Assertion 3: A MACHINERY-ONLY PULL STILL PROCEEDS -------------------------
# The false positive that would make this release worse than the defect. If the rulebook
# is not changing, no fixture can break on it, and step 2 must stay autonomous.
out_mo="$(verdict r_current)"
if ! have r_current; then dropped r_current
elif ! grep -q 'SELF-UPDATE-DEFER' <<<"$out_mo"; then
  ok "a pull that changes no rulebook file does NOT defer — the arm is a differential"; B_a3=1
else
  bad "a pull with NO rulebook change DEFERRED — the arm is static, not differential, and it strands the machinery slice on every pull"
  printf '%s\n' "$out_mo" | sed 's/^/        /' | head -3
fi

# --- Assertion 4: the fixture-coupling arm names its subjects ------------------
if ! have r_old; then dropped r_old
elif grep -q 'rulebook-coupled-fixtures' <<<"$out"; then
  ok "the fixture-coupling arm fires and names itself"; B_a4=1
else
  bad "the fixture-coupling arm never fired — postcompact-rulebook-recovery is exactly the case it exists for"
fi

# --- Assertion 5: an unparseable anchor side REFUSES, never agrees -------------
# A zero must not be a false zero: if the anchor grammar moves, an empty set compares
# equal to anything and the gate would report agreement it never computed.
if [ "$NOANCHOR_BUILD" != ok ]; then
  bad "FIXTURE BROKEN — no gate-validation.md in the seeded consumer, so assertion 5 tests nothing"
elif ! have r_noanchor; then dropped r_noanchor
elif grep -q 'SELF-UPDATE-UNDECIDED' <<<"$(verdict r_noanchor)"; then
  ok "an unparseable anchor side returns UNDECIDED — an empty set does not read as agreement (read with the SAFE-STOP walk skipped: R1 emits it before any walk)"
else
  bad "a consumer with no parseable anchors did not return UNDECIDED — a false zero would read as a clean join"
fi

# --- WALK: r_old's one real SAFE-STOP walk ran, and the flagged runs ran none ------
# The end-to-end proof that the walk works is r_old's SELF-UPDATE-SAFE-STOP row; the flagged registry runs that
# defer (r_noanchor, r_control) must carry none, or the flag did not skip it.
ss_flagged=""
for l in r_noanchor r_control; do
  have "$l" && grep -q 'SELF-UPDATE-SAFE-STOP' <<<"$(verdict "$l")" && ss_flagged="$ss_flagged $l"
done
if ! have r_old; then dropped r_old
elif ! grep -q 'SELF-UPDATE-SAFE-STOP' <<<"$out"; then
  bad "WALK: r_old, the one run without the flag, carries no SELF-UPDATE-SAFE-STOP row — the kept walk is not exercised"
elif [ -n "$ss_flagged" ]; then
  bad "WALK: flagged run(s)$ss_flagged still carry a SELF-UPDATE-SAFE-STOP row — --no-safe-stop-advice did not skip the walk"
else
  ok "WALK: r_old's real walk emits its SAFE-STOP row, and the flagged deferring runs emit none"
fi

# --- nav: every flagged run says NOT-A-VERDICT on STDERR, and only there -----------
# r_old, the unflagged run, is the in-run control: the banner must be absent from it, so a banner printed
# unconditionally cannot pass.
nav_bad=""; nav_n=0
for l in r_current r_noanchor r_control r_muta r_mutb; do
  have "$l" || continue
  nav_n=$((nav_n + 1))
  grep -q 'NOT-A-VERDICT' "$OUTD/$l.err" 2>/dev/null || nav_bad="$nav_bad $l:no-stderr-banner"
  grep -q 'NOT-A-VERDICT' "$OUTD/$l.txt" 2>/dev/null && nav_bad="$nav_bad $l:banner-on-stdout"
done
if [ "$nav_n" -lt 5 ]; then
  bad "nav: only $nav_n of the 5 flagged registry runs produced a verdict"
elif grep -q 'NOT-A-VERDICT' "$OUTD/r_old.err" "$OUTD/r_old.txt" 2>/dev/null; then
  bad "nav: the UNFLAGGED r_old printed NOT-A-VERDICT — the banner is unconditional, so it marks nothing"
elif [ -n "$nav_bad" ]; then
  bad "nav: the NOT-A-VERDICT banner is wrong on$nav_bad"
else
  ok "nav: all $nav_n flagged runs print NOT-A-VERDICT on stderr and not on stdout; unflagged r_old prints none"; B_nav=1
fi

# ------------------------------------------------------------------------------
# MUTANTS. Copies, never in-place edits; built and guarded in phase 1. The unmutated
# control comes first: this gate shells out to git, and a copy that fails for its own
# reasons would score every mutant below as a kill.
# ------------------------------------------------------------------------------
if ! have r_control; then
  dropped r_control
  CONTROL_OK=0
elif grep -q 'SELF-UPDATE-DEFER' <<<"$(verdict r_control)"; then
  ok "CONTROL: an unmutated copy reproduces the real verdict"; B_ctl=1
  CONTROL_OK=1
else
  bad "CONTROL: an unmutated copy did not reproduce the real verdict — every mutant below is uninterpretable"
  CONTROL_OK=0
fi

if [ "${CONTROL_OK:-0}" = "1" ]; then
  # MUTANT A: the anchor join stops comparing. Assertion 1's ANCHOR half must go quiet.
  if [ "$MUT_A_BUILD" = vacuous ]; then
    bad "MUTANT A changed nothing — the anchor is stale and the mutant is a no-op"
  elif [ "$MUT_A_BUILD" = notaprogram ]; then
    bad "MUTANT A is not a valid program — its silence would have scored as a kill"
  elif ! have r_muta; then
    dropped r_muta
  elif grep -q 'whose CHECK_LOADED anchor lives in' <<<"$(verdict r_muta)"; then
    bad "MUTANT A SURVIVED: it did not silence the anchor arm — assertion 2 is not testing the join"
  else
    mx_gate A "$(verdict r_muta)"
    mutant_killed "$(( ${B_a2:-0} && ${B_ctl:-0} ))" A "MUTANT A killed — without the anchor comparison the unanchored checks go unreported"
  fi

  # MUTANT B: the fixture arm stops being differential — drop the rulebook-changed guard.
  # It must then defer on the machinery-only pull, which is assertion 3's whole point.
  if [ "$MUT_B_BUILD" = vacuous ]; then
    bad "MUTANT B changed nothing — anchor stale"
  elif [ "$MUT_B_BUILD" = notaprogram ]; then
    bad "MUTANT B is not a valid program"
  elif ! have r_mutb; then
    dropped r_mutb
  elif grep -q 'SELF-UPDATE-DEFER' <<<"$(verdict r_mutb)"; then
    mx_gate B "$(verdict r_mutb)"
    mutant_killed "$(( ${B_a3:-0} && ${B_ctl:-0} ))" B "MUTANT B killed — dropping the differential guard defers a machinery-only pull (assertion 3 has teeth)"
  else
    bad "MUTANT B SURVIVED: it did not defer the machinery-only pull — assertion 3 is not testing the differential"
  fi
fi

# ============================================================================
# THE rc-PAIR TABLE. The gate probes each gating script BARE -- no arguments, no stdin --
# because it cannot know what the hook passes. For a script whose bare form is a usage error
# that probe asks nothing and gets "usage" back from BOTH sides, which used to land on the
# both-non-zero arm and DEFER. Measured across every script the reference consumer's pre-push
# invokes, three of five exit 2 bare (validate-audit-anchors, validate-layer-entries,
# validate-provenance-block; validate-compact-window and validate-fixture-drivability exit 0),
# so any machinery-only pull touching one of those three deferred permanently.
#
# THE WHOLE RISK OF THAT FIX IS THAT IT REMOVES THE GATE, so the table is driven directly here
# rather than inferred: a purpose-built dist and consumer where the changed script is a stub
# whose exit code is the input. `2,2` must now clear; every pair that represents a real change
# in what the hook will run must still defer. `0,2` is the arm that keeps the fix honest --
# an incoming version that NEWLY refuses its own invocation is a change, not a no-op.
RCD="$WORK/rcpair"
mkdir -p "$RCD/dist" "$RCD/consumer/scripts/ai-dlc" "$RCD/consumer/.githooks"
(
  cd "$RCD/dist" && git -c init.defaultBranch=main init -q . \
    && git config user.email f@example.com && git config user.name Fixture \
    && git config commit.gpgsign false && mkdir -p core/scripts
) || { echo "FIXTURE ERROR: rc-pair dist init failed" >&2; exit 2; }
printf 'exit 0\n' > "$RCD/dist/core/scripts/validate-probe.sh"
( cd "$RCD/dist" && git add -A && git commit -q -m base ) || exit 2
RC_BASE="$( cd "$RCD/dist" && git rev-parse HEAD )"
printf 'scripts/ai-dlc/validate-probe.sh\n' > "$RCD/consumer/.githooks/pre-push"

# rcpair <cur-rc> <new-rc> -> the gate's verdict token for validate-probe.sh
rcpair() {
  printf 'exit %s\n' "$1" > "$RCD/consumer/scripts/ai-dlc/validate-probe.sh"
  # THE MARKER IS LOAD-BEARING. The gating set is `invoked AND changed in BASE..THEIRS`, and
  # BASE ships `exit 0`. Without it, the pair `<cur> 0` writes a file byte-identical to BASE,
  # the script is not in the range's changed set, the gate emits nothing for it, and the arm
  # reads as an empty verdict rather than as a result. Every pair must be a real change.
  printf '# pair %s-%s\nexit %s\n' "$1" "$2" "$2" > "$RCD/dist/core/scripts/validate-probe.sh"
  ( cd "$RCD/dist" && git add -A && git commit -q -m "new $2" --allow-empty ) >/dev/null 2>&1
  local theirs; theirs="$( cd "$RCD/dist" && git rev-parse HEAD )"
  bash "${3:-$GATE}" "$FLAG" "$RCD/dist" "$RC_BASE" "$theirs" "$RCD/consumer" 2>&1 \
    | grep -oE 'SELF-UPDATE-(OK|DEFER|UNDECIDED)[[:space:]]+validate-probe\.sh' | head -1 \
    | awk '{print $1}'
}

RC_22="$(rcpair 2 2)"; RC_01="$(rcpair 0 1)"; RC_02="$(rcpair 0 2)"; RC_11="$(rcpair 1 1)"
RC_33="$(rcpair 3 3)"; RC_21="$(rcpair 2 1)"; RC_10="$(rcpair 1 0)"
if [ -z "$RC_22$RC_01$RC_02$RC_11$RC_33$RC_21$RC_10" ]; then
  bad "rc-pair harness produced no verdicts at all — the table below would be seven silent passes"
else
  if [ "$RC_22" = "SELF-UPDATE-OK" ]; then
    ok "rc 2,2 (both refuse the bare probe) is OK — a usage error on both sides is not a differential signal; two of the seven scripts the pre-push invokes exit 2 bare"; B_rc22=1
  else
    bad "rc 2,2 gave [$RC_22], expected SELF-UPDATE-OK — the three usage-error scripts still strand the machinery slice"
  fi
  [ "$RC_01" = "SELF-UPDATE-DEFER" ] \
    && ok "rc 0,1 still DEFERS — an incoming version that newly fails against this tree is the case the gate exists for, and the 2,2 arm did not swallow it" \
    || bad "rc 0,1 gave [$RC_01], expected SELF-UPDATE-DEFER — the fix REMOVED the gate"
  [ "$RC_02" = "SELF-UPDATE-DEFER" ] \
    && ok "rc 0,2 still DEFERS — a version that NEWLY refuses its own invocation changed what the hook runs, so the exemption is scoped to BOTH sides agreeing and not to either side alone" \
    || bad "rc 0,2 gave [$RC_02], expected SELF-UPDATE-DEFER — the arm keyed on one side, so a newly-broken invocation reads as a no-op"
  # 1,1 CHANGED VERDICT IN v0.297.0 AND THE REASON IS MEASURED, NOT PREFERRED. It used to read
  # as "a genuine pre-existing failure, unattributable, defer". `audit-rule-files.sh` is the
  # counter-example: bare it defaults to `--fail-on=any` while the pre-push passes
  # `--fail-on=deterministic`, so it exits 1 while printing `tier-1 findings: 0` — failing a
  # threshold the hook never applies, identically on both sides. Agreement carries no
  # differential information whatever the code; only DISAGREEMENT does.
  if [ "$RC_11" = "SELF-UPDATE-OK" ]; then
    ok "rc 1,1 is OK — equal codes are not a differential signal, and deferring on them stranded every pull touching a script whose bare default differs from the hook's flag"; B_rc11=1
  else
    bad "rc 1,1 gave [$RC_11], expected SELF-UPDATE-OK — a pull touching audit-rule-files.sh still folds the machinery slice into the gated apply"
  fi
  # Equality, not a whitelist of codes. If the arm were written as a set of blessed exit codes
  # this would fail, and that is the point of testing a code no script in the tree returns.
  [ "$RC_33" = "SELF-UPDATE-OK" ] \
    && ok "rc 3,3 is OK — the exemption is EQUALITY, not a list of blessed codes" \
    || bad "rc 3,3 gave [$RC_33], expected SELF-UPDATE-OK — the arm is keyed on particular values, so the next script with its own exit vocabulary strands again"
  # THE ARMS THAT KEEP THE WIDENING FROM REMOVING THE GATE. Both sides non-zero but DIFFERENT is
  # still a disagreement, and a disagreement is the only thing this gate can read.
  [ "$RC_21" = "SELF-UPDATE-UNDECIDED" ] \
    && ok "rc 2,1 still defers — two non-zero codes that DISAGREE are not agreement, so widening to equality did not swallow the both-non-zero arm" \
    || bad "rc 2,1 gave [$RC_21], expected SELF-UPDATE-UNDECIDED — the widening reaches unequal pairs and the gate is gone"
  [ "$RC_10" = "SELF-UPDATE-OK" ] \
    && ok "rc 1,0 is OK — an incoming version that FIXES a pre-existing failure cannot block the push" \
    || bad "rc 1,0 gave [$RC_10], expected SELF-UPDATE-OK"

  # MUTANT C — the equality arm narrowed back to v0.288.0's `2 and 2`. A copy, cmp -s guarded,
  # driven through the same rc-pair harness. It must move 1,1 and ONLY 1,1: 2,2 was already
  # covered by the narrow form, so a mutant that moved both would mean the two arms are one
  # assertion wearing two labels.
  GATE_C="$(gate_mutate C 's|^    if \[ "\$rc_cur" -ne "\$rc_new" \] && \[ "\$rc_new" -ne 0 \]; then$|    if ! { [ "$rc_cur" -eq 2 ] \&\& [ "$rc_new" -eq 2 ]; } \&\& [ "$rc_new" -ne 0 ]; then|')"
  if [ -z "$GATE_C" ]; then
    bad "FIXTURE BROKEN: the skill-tree copy for MUTANT C did not build"
  elif cmp -s "$GATE" "$GATE_C"; then
    bad "FIXTURE STALE: could not build MUTANT C — the equality arm's condition was reworded, so the widening is asserted by nothing"
  elif ! bash -n "$GATE_C" 2>/dev/null; then
    bad "MUTANT C is not a valid program — its silence would have scored as a kill"
  else
    C_11="$(rcpair 1 1 "$GATE_C")"; C_22="$(rcpair 2 2 "$GATE_C")"
    if [ "$C_11" = "SELF-UPDATE-UNDECIDED" ] && [ "$C_22" = "SELF-UPDATE-OK" ]; then
      mx_cell C rc22 "$C_22"; mx_cell C rc11 "$C_11"
      mutant_killed "$(( ${B_rc11:-0} && ${B_rc22:-0} ))" C "MUTANT C killed — narrowed back to 2-and-2, rc 1,1 defers again while 2,2 does not move: the widening is what the 1,1 arm tests"
    else
      bad "MUTANT C SURVIVED: it moved the wrong set — 1,1 gave [$C_11] (expected SELF-UPDATE-UNDECIDED) and 2,2 gave [$C_22] (expected SELF-UPDATE-OK). Either the 1,1 arm is vacuous or it is entangled with the 2,2 arm."
    fi
  fi
fi

# ============================================================================
# THE FLAG SKIPS advise_safe_stop ONLY: rec and lay, and MUTANT F. Two gate runs, both flagged, on the rc world's
# tiny dist with the rc consumer copied INSIDE an enclosing repository, where the gate stops at its layout arm about
# a second in. Under the flag, the unmutated gate must still open its verdict record (`record:` on stderr and the file
# on disk) and still refuse the enclosed layout. MUTANT F reuses the walk's AI_DLC_GATE_IN_SAFE_STOP guard for the
# flag, which silences both; F must still print the banner and a SELF-UPDATE- row, so a copy that never ran cannot
# score as the kill.
ENC="$WORK/enc"
mkdir -p "$ENC" && git -C "$ENC" -c init.defaultBranch=main init -q . \
  || { echo "FIXTURE ERROR: could not init the enclosing repository" >&2; exit 2; }
RC_THEIRS="$( cd "$RCD/dist" && git rev-parse HEAD )"
# enc_run <label> <gate> -> runs the flagged gate on a fresh enclosed copy; prints the stdout+stderr, then the line
# RECORD-FILE-PRESENT when a verdict record exists in that copy afterwards (derived from the disk, not the text).
enc_run() {
  local sub="$ENC/sub-$1" n=0 f
  clone_tree "$RCD/consumer" "$sub"
  # The rc-pair runs above recorded into the rc consumer; a copied record would satisfy rec for any gate.
  rm -rf "$sub/_bmad-output"
  bash "$2" "$FLAG" "$RCD/dist" "$RC_BASE" "$RC_THEIRS" "$sub" > "$WORK/$1.enc.out" 2> "$WORK/$1.enc.err"
  for f in "$sub/_bmad-output/ai-dlc-update/"self-update-gate-*.md; do [ -f "$f" ] && n=$((n + 1)); done
  cat "$WORK/$1.enc.out" "$WORK/$1.enc.err"
  [ "$n" -gt 0 ] && echo RECORD-FILE-PRESENT
}
E_U="$(enc_run u "$GATE")"
if grep -q 'NOT-A-VERDICT' "$WORK/u.enc.err" 2>/dev/null && ! grep -q 'NOT-A-VERDICT' "$WORK/u.enc.out" 2>/dev/null; then :; else
  bad "nav: the flagged enclosed run did not print NOT-A-VERDICT on stderr alone"; fi
if grep -q '^record: ' <<<"$E_U" && grep -qx 'RECORD-FILE-PRESENT' <<<"$E_U"; then
  ok "rec: under --no-safe-stop-advice the gate still opens its verdict record (stderr names it, the file is on disk)"; B_rec=1
else
  bad "rec: under --no-safe-stop-advice no verdict record was written — the flag reached past advise_safe_stop"
fi
if awk -F'\t' '$1 == "SELF-UPDATE-UNDECIDED" && $2 == "pre-push" && $3 ~ /UNSUPPORTED LAYOUT/ {f = 1} END {exit !f}' <<<"$E_U"; then
  ok "lay: under --no-safe-stop-advice a consumer inside an enclosing repository is still refused UNSUPPORTED LAYOUT"; B_lay=1
else
  bad "lay: under --no-safe-stop-advice the enclosed consumer was not refused — the flag reached the layout arm"
fi
if [ "$MUT_F_BUILD" != ok ]; then
  bad "MUTANT F did not build ($MUT_F_BUILD) — the flag's own assignment line moved, so rec and lay are guarded by nothing"
else
  E_F="$(enc_run f "$MUT_F")"
  if ! grep -q 'NOT-A-VERDICT' <<<"$E_F" || ! grep -q '^SELF-UPDATE-' <<<"$E_F"; then
    bad "MUTANT F printed no banner or no SELF-UPDATE- row — a copy that did not run cannot score a kill"
  else
    mx_cell F lay "$E_F"; mx_cell F rec "$E_F"; mx_cell F nav "$E_F"
    if ! mx_holds lay "$E_F" && ! mx_holds rec "$E_F"; then
      mutant_killed "$(( ${B_lay:-0} && ${B_rec:-0} ))" F "MUTANT F killed — the flag reusing the walk's guard drops the record and the layout refusal, and rec and lay both fail on it"
    else
      bad "MUTANT F SURVIVED: with the flag on the walk's guard, rec or lay still held — that arm is not testing the flag's scope"
    fi
  fi
fi

# ============================================================================
# cs: NO SHIPPED CALLER PASSES THE FLAG. One awk over every file of core/skills/ai-dlc-update/ except the gate,
# which defines it: non-comment lines carrying --no-safe-stop-advice (want 0), and, in the SAME invocation, non-comment
# lines naming self-update-gate.sh (the control, want >= 1, so a zero is a scan that saw the call sites). Scoped to
# the skill directory because every non-comment mention of the gate in core/ outside core/fixtures/ lives there
# (measured over all of core/ at the time of writing); declaring all of core/ would rekey this fixture on every core
# change. core/fixtures/ is excluded by construction -- this fixture passes the flag. A self-probe runs the same awk
# on a seeded tree first: one non-comment flag line and one commented, so it must answer exactly 1.
cs_scan() { # <dir> <excluded file> -> "<files> <control> <hits>"
  find "$1" -type f ! -path "$2" -print0 | xargs -0 awk 'FNR == 1 {nf++} /^[[:blank:]]*#/ {next}
    /self-update-gate\.sh/ {c++} /--no-safe-stop-advice/ {h++} END {print nf + 0, c + 0, h + 0}'
}
CSP="$WORK/cs-probe"; mkdir -p "$CSP"
printf 'bash self-update-gate.sh --no-safe-stop-advice a b c d\n' > "$CSP/call.sh"
printf '# bash self-update-gate.sh --no-safe-stop-advice in prose\n' > "$CSP/prose.sh"
read -r csp_f csp_c csp_h <<<"$(cs_scan "$CSP" /dev/null)"
read -r cs_f cs_c cs_h <<<"$(cs_scan "$D_ROOT/core/skills/ai-dlc-update" "$GATE")"
if [ "${csp_f:-0}" -ne 2 ] || [ "${csp_h:-0}" -ne 1 ] || [ "${csp_c:-0}" -ne 1 ]; then
  bad "cs: FIXTURE BROKEN — the scan's self-probe read files=$csp_f control=$csp_c hits=$csp_h, want 2 1 1"
elif [ "${cs_f:-0}" -lt 1 ] || [ "${cs_c:-0}" -lt 1 ]; then
  bad "cs: the scan saw $cs_f file(s) and $cs_c gate call site(s) under core/skills/ai-dlc-update — a zero here is a scan that read nothing"
elif [ "${cs_h:-0}" -ne 0 ]; then
  bad "cs: $cs_h non-comment line(s) under core/skills/ai-dlc-update pass --no-safe-stop-advice — a shipped caller would read a DEFER with no SAFE-STOP row as the answer"
else
  ok "cs: no shipped caller passes --no-safe-stop-advice ($cs_f files, control: $cs_c non-comment lines naming the gate)"
fi

# MX0: a plain run executes no matrix-only cell; --matrix scores every cell and says how many.
if [ "$MATRIX" = 1 ]; then
  echo "MATRIX MODE: $MX_RUN cells"
  if [ "$MX_RUN" -gt 0 ]; then ok "MX0 matrix mode: $MX_RUN cells scored"; else bad "MX0 matrix mode: --matrix scored no cell"; fi
elif [ "$MX_CELLS" -eq 0 ]; then ok "MX0 per-push run: matrix-only cells run = 0 (cells scored: $MX_RUN)"
else bad "MX0 per-push run: $MX_CELLS matrix-only cell(s) ran"; fi
echo
if [ "$fails" -ne 0 ]; then
  echo "self-update-join-gate: $fails assertion(s) FAILED" >&2
  exit 1
fi
echo "self-update-join-gate: all assertions passed"
