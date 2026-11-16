#!/usr/bin/env bash
# seed-verdict-store-red-print -- drive scripts/seed-verdict-store.sh against stub fixtures and assert WHAT IT
# PRINTS when a fixture goes red (BL-882).
#
# THE DEFECT. The red branch printed `tail -5` of the fixture's output, so a J3 verdict row sitting above more than
# five trailing lines was never shown and the cause of a red seed was not derivable from the script's output.
#
# THE WORLD. One scratch git repo carries a stub .githooks/pre-push (a fxcount_arm that sets a counted store, which
# is all the subject extracts) and a stub core/scripts/hermetic-run.sh that emits three kinds of fixture output.
# ONE run of the subject covers all three:
#   red-filter  a J3 row, then eight noise lines, then the runner trailer, exit 1 (the row is ABOVE five lines)
#   red-plain   eight lines naming no verdict token, then the trailer, exit 1 (nothing for the filter to match)
#   green       a line that must NOT be printed, exit 0 (the pass path stays unchanged)
#
# ARMS   a1 the J3 row is printed, the noise is not, and the trailer is printed
#        a2 with no verdict line the WHOLE output is printed (first line included)
#        a3 the pass path prints its `rc=0` line and none of the fixture's output
#        a4 every hermetic-run.sh the subject starts reads /dev/null on stdin, as the push's pool gives it, though the
#           subject itself is driven from a regular file (BL-1053: a counted run inheriting a session's socket stdin
#           leaves a `bash -c` at shell level 1 uncounted)
#        a5 a line indented `      | ` (a fixture's evidence under its FAIL line) is printed, though it names no verdict
#           token, and the noise beside it is not
# BL-1092 CELLS (one drive each)
#   b_pred   census --predict lists both shipping units as `run <fx>@consumer`, CONSUMER 2, runs and writes nothing
#   b_only   census --only cl-a@consumer runs only cl-a; the re-predict then lists cl-b and no longer cl-a (seeding X@consumer
#            removes it from the re-predict)
#   b_run    a plain census runs every selected unit (the twin of --predict and --only)
#   c_skip   a census in a world with no scripts/gate-wait.sh prints that its wait was skipped
#   b_hpred b_moved   over the world's hook span: a never-recorded unit is selected; a seeded unit whose run.sh then
#            MOVED is selected again by the re-predict
#   g_live g_dead g_reuse g_cap g_gone   gate_wait: a live marker waits and releases; a dead pid and a reused pid (wrong start
#            time) are ignored; AI_DLC_GATE_WAIT_MAX=0 proceeds at once; a dead marker is deleted
#   h_green h_red h_int h_term   the hook's GATE_HELD span: one marker while the hook runs, none after a green, red, INT or TERM exit
#   h_nogate no marker when the push delivers no tree (PUSH_LINES empty)
#   s_route s_none s_skip   the seed's @consumer names go to the census as --only "<names>", rc 0/1 by its verdict line,
#            a name with no verdict is exit 2, and a missing scripts/gate-wait.sh prints that the wait was skipped
#   p_dist p_cons   predict-push-set prints its distribution lines, then CONSUMER <m> and `run <fx>@consumer`
#
# Usage: run.sh     Exit 0 = every arm holds, 1 = one regressed, 2 = fixture broken.
set -u

for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
[ -f "$HERE/../lib/preamble.sh" ] || { echo "FIXTURE ERROR: lib/preamble.sh not found beside $HERE" >&2; exit 2; }
. "$HERE/../lib/preamble.sh"
ROOT=""
for cand in "$HERE/../../.." "$HERE/../.."; do
  if [ -f "$cand/scripts/seed-verdict-store.sh" ]; then ROOT="$(cd "$cand" && pwd)"; break; fi
done
[ -n "$ROOT" ] || { echo "FIXTURE ERROR: no scripts/seed-verdict-store.sh above $HERE" >&2; exit 2; }
SUBJ="$ROOT/scripts/seed-verdict-store.sh"
echo "HERMETIC-CONSUMED scripts/seed-verdict-store.sh"

# shellcheck source=/dev/null
. "$HERE/../lib/report.sh" || { echo "FIXTURE ERROR: lib/report.sh not found beside $HERE" >&2; exit 2; }
# shellcheck source=/dev/null
. "$HERE/../lib/pool-span.sh" || { echo "FIXTURE ERROR: lib/pool-span.sh not found beside $HERE" >&2; exit 2; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/w/.githooks" "$T/w/core/scripts" "$T/tmp" "$T/v"
cat > "$T/w/.githooks/pre-push" <<EOF
fxcount_arm() {
  vk=aaaaaaaaaaaa
  AI_DLC_VERDICT_STORE="$T/store/counted-\$vk"; export AI_DLC_VERDICT_STORE
  mkdir -p "\$AI_DLC_VERDICT_STORE"
}
EOF
cat > "$T/w/core/scripts/hermetic-run.sh" <<'EOF'
#!/bin/bash
fx="$1"; n=1
# a4's record: one line per start, `devnull` when stdin is /dev/null. The cwd is the scratch root, so ../ is outside it.
if [ /dev/stdin -ef /dev/null ]; then echo "$fx devnull" >> ../stdin.rec; else echo "$fx other" >> ../stdin.rec; fi
case "$fx" in
  red-filter) echo "J3 mismatch: cell-x counted 9, declared 4"; while [ "$n" -le 8 ]; do echo "noise $n"; [ "$n" = 4 ] && echo "      | evidence-under-fail"; n=$((n + 1)); done; r=1 ;;
  red-plain)  while [ "$n" -le 8 ]; do echo "plain $n"; n=$((n + 1)); done; r=1 ;;
  green)      echo "okline-must-not-print"; r=0 ;;
  *) exit 2 ;;
esac
printf 'hermetic-run: %s: rc=%s sandbox_files=0 required_missing=0\n' "$fx" "$r"
exit "$r"
EOF
mkdir -p "$T/w/scripts"
cat > "$T/w/scripts/census-consumer-layout.sh" <<'SC'
#!/bin/bash
# stub census: records its argv (one per line) in ../census.argv, answers per name
printf '%s\n' "$@" > ../census.argv
only=""; while [ "$#" -gt 0 ]; do case "$1" in --only) only="$2"; shift 2 ;; *) shift ;; esac; done
rc=0
for n in $only; do case "$n" in
  s-ok*) echo "$n@consumer ok" ;; s-red*) echo "$n@consumer FAIL"; rc=1 ;; s-cur*) echo "$n@consumer not selected: its record is current" ;; esac; done
echo "census: stub"; exit "$rc"
SC
(
  cd "$T/w" || exit 2
  git init -q . && git add -A \
    && git -c core.hooksPath=/dev/null -c user.name=fx -c user.email=fx@example.invalid commit -q -m world
) >/dev/null 2>&1 || { echo "FIXTURE BROKEN: could not build the scratch repo" >&2; exit 2; }

# drive <subject file> <out file> -- one run of the subject over all three stub fixtures, from the scratch root, with a
# regular file on stdin (never /dev/null, so a4 can tell the subject's redirect from the caller's). The stubs' stdin
# record is moved to <out file>.stdin.
printf 'not-devnull\n' > "$T/feed"
drive() {
  rm -f "$T/stdin.rec"
  ( cd "$T/w" && TMPDIR="$T/tmp" bash "$1" red-filter red-plain green > "$2" 2>&1 < "$T/feed"; echo "exit=$?" >> "$2" )
  if [ -f "$T/stdin.rec" ]; then mv "$T/stdin.rec" "$2.stdin"; else : > "$2.stdin"; fi
}
has() { grep -qF -- "$2" "$1"; }
cell() { # <arm> <out file> -> 0 when the arm holds on that output
  case "$1" in
    a1) has "$2" "J3 mismatch: cell-x counted 9" && ! has "$2" "noise 3" && has "$2" "hermetic-run: red-filter: rc=1" ;;
    a2) has "$2" "plain 1" && has "$2" "plain 8" && has "$2" "hermetic-run: red-plain: rc=1" ;;
    a3) has "$2" "green rc=0" && ! has "$2" "okline-must-not-print" ;;
    a4) [ "$(grep -c ' devnull$' "$2.stdin")" = 3 ] && [ "$(grep -c . "$2.stdin")" = 3 ] ;;
    a5) has "$2" "      | evidence-under-fail" && ! has "$2" "noise 5" ;;
  esac
}

cp "$SUBJ" "$T/v/control.sh"
drive "$T/v/control.sh" "$T/control.out"
# The control must prove the subject RAN before any verdict is read: a harness that died prints neither line.
if has "$T/control.out" "counted store: $T/store/counted-aaaaaaaaaaaa" && has "$T/control.out" "red-filter rc=1" && has "$T/control.out" "exit=1"; then
  ok "control: the subject ran against the stub world and exited 1 on the reds"
else
  echo "FIXTURE BROKEN: the subject did not run against the scratch world"; sed 's/^/  | /' "$T/control.out"; exit 2
fi
if cell a1 "$T/control.out"; then ok "a1 a red prints the J3 row above five trailing lines, not the noise, and the trailer"
else bad "a1 the J3 row, the absence of noise, or the trailer is wrong"; sed 's/^/  | /' "$T/control.out"; fi
if cell a2 "$T/control.out"; then ok "a2 a red with no verdict line prints the whole output"
else bad "a2 the whole-output fallback did not print"; sed 's/^/  | /' "$T/control.out"; fi
if cell a3 "$T/control.out"; then ok "a3 the pass path prints its rc line and none of the fixture's output"
else bad "a3 the pass path changed"; sed 's/^/  | /' "$T/control.out"; fi
if cell a4 "$T/control.out"; then ok "a4 every hermetic-run.sh the subject starts reads /dev/null on stdin, the subject itself driven from a file"
else bad "a4 a hermetic-run.sh the subject started did not read /dev/null on stdin"; sed 's/^/  | /' "$T/control.out.stdin"; fi
if cell a5 "$T/control.out"; then ok "a5 a red prints the evidence line indented under its FAIL line, sitting among unprinted noise"
else bad "a5 the indented evidence line was not printed, or the noise around it was"; sed 's/^/  | /' "$T/control.out"; fi


# ============================================================================================================
# BL-1092: the @consumer seed path, the census's --predict/--only, predict-push-set's consumer tail, gate-wait.sh and
# the hook's GATE_HELD marker. One drive per cell. Every verdict reads a value the subject printed or wrote, never elapsed time: a wait is
# ended by a condition (the waiter's own "waiting" line), and the cap cell uses AI_DLC_GATE_WAIT_MAX=0 so it fires
# on the first look.
# ============================================================================================================
CENSUS="$ROOT/scripts/census-consumer-layout.sh"; GATEW="$ROOT/scripts/gate-wait.sh"; PREDICT="$ROOT/scripts/predict-push-set.sh"
HOOKSRC="$ROOT/.githooks/pre-push"
for _f in "$CENSUS" "$GATEW" "$PREDICT" "$HOOKSRC"; do [ -f "$_f" ] || { echo "FIXTURE ERROR: $_f not found" >&2; exit 2; }; done
echo "HERMETIC-CONSUMED scripts/census-consumer-layout.sh"
echo "HERMETIC-CONSUMED scripts/gate-wait.sh"
echo "HERMETIC-CONSUMED scripts/predict-push-set.sh"
mkdir -p "$T/v2" "$T/cw0" || exit 2

# ---- the census world: the hook's FIXTURE_POOL span only, a stub install.sh, two shipping fixtures, committed.
CW="$T/cw0"; mkdir -p "$CW/.githooks" "$CW/scripts/ai-dlc" "$CW/core/fixtures/cl-a" "$CW/core/fixtures/cl-b" "$CW/lib"
pool_span "$HOOKSRC" "$CW/.githooks/pre-push" FIXTURE_POOL && grep -q '^cl_select() ' "$CW/.githooks/pre-push" \
  || { echo "FIXTURE ERROR: no FIXTURE_POOL span with cl_select in $HOOKSRC" >&2; exit 2; }
for _f in cl-a cl-b; do printf '#!/usr/bin/env bash\nexit 0\n' > "$CW/core/fixtures/$_f/run.sh"; done
printf 'input\n' > "$CW/lib/input.txt"
printf '#!/usr/bin/env bash\nexit 0\n' > "$CW/scripts/ai-dlc/hermetic-run.sh"
cat > "$CW/scripts/install.sh" <<'IN'
#!/usr/bin/env bash
t="${1:-.}"
[ -d "$t/_bmad" ] || exit 1
mkdir -p "$t/tests/fixtures" "$t/scripts/ai-dlc" || exit 1
for d in core/fixtures/*/; do
  [ -f "$d/run.sh" ] || continue
  b="${d%/}"; b="${b##*/}"; mkdir -p "$t/tests/fixtures/$b" && cp "$d"* "$t/tests/fixtures/$b/" || exit 1
done
cp scripts/ai-dlc/hermetic-run.sh "$t/scripts/ai-dlc/hermetic-run.sh"
mkdir -p "$t/.githooks" && cp .githooks/pre-push "$t/.githooks/pre-push" || exit 1
cp -R lib "$t/lib" || exit 1
mkdir -p "$t/.claude" && printf 'version: 1.%s\ncommit: c%s\ninstalled_at: %s\n' $$ $$ $$ > "$t/.claude/.ai-dlc-version" || exit 1
IN
cp "$CENSUS" "$CW/scripts/census-consumer-layout.sh"; cp "$GATEW" "$CW/scripts/gate-wait.sh"
( cd "$CW" && git init -q . && git add -A && git -c core.hooksPath=/dev/null -c user.name=fx -c user.email=fx@example.invalid commit -q -m world ) > /dev/null 2>&1 \
  || { echo "FIXTURE BROKEN: could not build the census world" >&2; exit 2; }

# cw_run <variant census file|-> <tag> <args...>: the census over a FRESH copy of the world (its own store), run from
# the world root; its output in $T/cw.<tag>.out, the exit in $T/cw.<tag>.rc. The world dir is $T/cw.<tag>.
# The variant replaces the world's census, or the world file CW_DST names (the hook span, for the b_moved cells).
cw_run() {
  local v="$1" tag="$2" dst="${CW_DST:-scripts/census-consumer-layout.sh}"; shift 2
  [ -d "$T/cw.$tag" ] || { cp -Rp "$CW" "$T/cw.$tag" || return 1; }
  if [ "$v" != - ] && ! cmp -s "$v" "$T/cw.$tag/$dst"; then
    cp "$v" "$T/cw.$tag/$dst" \
      && ( cd "$T/cw.$tag" && git add -A && git -c core.hooksPath=/dev/null -c user.name=fx -c user.email=fx@example.invalid commit -q -m variant ) > /dev/null 2>&1 || return 1
  fi
  ( cd "$T/cw.$tag" && unset PREPUSH_POOL_DEPTH PREPUSH_CL_ENTRY AI_DLC_FX_CL_TREE \
    && AI_DLC_VERDICT_STORE="$T/cw.$tag.vs" AI_DLC_READSET_LIVE_TRACE=0 TMPDIR="$T/tmp" \
       bash scripts/census-consumer-layout.sh "$@" > "$T/cw.$tag.out" 2>&1 < /dev/null; echo "$?" > "$T/cw.$tag.rc" )
}
cw_keys() { ls "$T/cw.$1.vs/consumer-placement-keys"/*/ 2>/dev/null | grep -c '\.key$' || true; }
# cell b_pred: --predict lists both shipping units as run <fx>@consumer, says CONSUMER 2, exits 0, runs and writes nothing
cell_b_pred() { # <variant|-> <tag>
  cw_run "$1" "$2" --predict || return 1
  has "$T/cw.$2.out" "CONSUMER 2" && has "$T/cw.$2.out" "run cl-a@consumer" && has "$T/cw.$2.out" "run cl-b@consumer" \
    && [ "$(cat "$T/cw.$2.rc")" = 0 ] && ! has "$T/cw.$2.out" "census:" && [ "$(cw_keys "$2")" = 0 ]
}
# cell b_only: --only cl-a@consumer runs ONLY cl-a (ok, 1 unit run); the re-predict then lists cl-b and no longer cl-a
cell_b_only() { # <variant|-> <tag>
  cw_run "$1" "$2" --only cl-a@consumer || return 1
  has "$T/cw.$2.out" "cl-a@consumer ok" && has "$T/cw.$2.out" "census: 1 unit(s) run, 1 passed" && ! has "$T/cw.$2.out" "cl-b@consumer ok" \
    && [ "$(cat "$T/cw.$2.rc")" = 0 ] || return 1
  cp "$T/cw.$2.out" "$T/cw.$2.only.out"
  cw_run "$1" "$2" --predict || return 1
  has "$T/cw.$2.out" "CONSUMER 1" && has "$T/cw.$2.out" "run cl-b@consumer" && ! has "$T/cw.$2.out" "run cl-a@consumer"
}

# cell b_run: a plain census (no flag) runs every selected unit, so --only and --predict are the only narrowing
cell_b_run() { # <variant|-> <tag>
  cw_run "$1" "$2" || return 1
  has "$T/cw.$2.out" "census: 2 unit(s) run, 2 passed" && [ "$(cat "$T/cw.$2.rc")" = 0 ]
}
# cell c_skip: a world with no scripts/gate-wait.sh: the census PRINTS that its wait was skipped (a name it does not
# select, so no unit runs)
cell_c_skip() { # <variant|-> <tag>
  if [ ! -d "$T/cw.$2" ]; then
    cp -Rp "$CW" "$T/cw.$2" && ( cd "$T/cw.$2" && git rm -q scripts/gate-wait.sh \
      && git -c core.hooksPath=/dev/null -c user.name=fx -c user.email=fx@example.invalid commit -q -m nowait ) > /dev/null 2>&1 || return 1
  fi
  cw_run "$1" "$2" --only zz-none@consumer || return 1
  has "$T/cw.$2.out" "census-consumer-layout: wait skipped, no scripts/gate-wait.sh here" && has "$T/cw.$2.out" "zz-none@consumer not selected"
}
# the b_moved cells run over a variant of the world's hook span (the FIXTURE_POOL span cl_select keys with)
SUBJ_HOOK="$T/v2/cl.base.sh"; cp "$CW/.githooks/pre-push" "$SUBJ_HOOK" || exit 2
# cell b_hpred: b_pred over the hook variant: a never-recorded unit is selected
cell_b_hpred() { # <hook variant|-> <tag>
  local CW_DST=.githooks/pre-push
  cell_b_pred "$1" "$2"
}
# cell b_moved: cl-a seeded, then its run.sh MOVED and committed: the re-predict lists cl-a@consumer again
cell_b_moved() { # <hook variant|-> <tag>
  local CW_DST=.githooks/pre-push
  cw_run "$1" "$2" --only cl-a@consumer || return 1
  has "$T/cw.$2.out" "cl-a@consumer ok" || return 1
  cw_run "$1" "$2" --predict || return 1
  has "$T/cw.$2.out" "CONSUMER 1" && ! has "$T/cw.$2.out" "run cl-a@consumer" || return 1
  printf '#!/usr/bin/env bash\n# moved\nexit 0\n' > "$T/cw.$2/core/fixtures/cl-a/run.sh"
  ( cd "$T/cw.$2" && git add -A && git -c core.hooksPath=/dev/null -c user.name=fx -c user.email=fx@example.invalid commit -q -m moved ) > /dev/null 2>&1 || return 1
  cw_run "$1" "$2" --predict || return 1
  has "$T/cw.$2.out" "run cl-a@consumer" && [ "$(cat "$T/cw.$2.rc")" = 0 ]
}

# ---- the gate_wait cells, over a variant of scripts/gate-wait.sh, in a scratch repo $T/gwr
mkdir -p "$T/gwr" && ( cd "$T/gwr" && git init -q . ) > /dev/null 2>&1 || { echo "FIXTURE BROKEN: gwr" >&2; exit 2; }
gw_run() { # <variant gate-wait.sh> <mode> <out file>: modes live dead reuse cap
  local v="$1" mode="$2" out="$3" sp w maxv=3 dead
  rm -f "$T/gwr/.git"/ai-dlc-gate-held.* "$out"; : > "$out"
  tail -f /dev/null > /dev/null 2>&1 & sp=$!
  case "$mode" in
    live)  maxv=600; printf '%s %s\n' "$sp" "$(ps -o lstart= -p "$sp")" > "$T/gwr/.git/ai-dlc-gate-held.$sp" ;;
    cap)   maxv=0;   printf '%s %s\n' "$sp" "$(ps -o lstart= -p "$sp")" > "$T/gwr/.git/ai-dlc-gate-held.$sp" ;;
    reuse) printf '%s Thu Jan  1 00:00:00 1970\n' "$sp" > "$T/gwr/.git/ai-dlc-gate-held.$sp" ;;
    dead)  dead="$(bash -c 'echo $$')"; printf '%s\n' "$dead" > "$T/gwr/.git/ai-dlc-gate-held.$dead" ;;
  esac
  # the variant is sourced under one fixed literal name, so the in-process scan resolves the operand (no subject)
  cp "$v" "$T/gwr/gw-under-test.sh" || return 1
  ( cd "$T/gwr" && AI_DLC_GATE_WAIT_POLL=1 AI_DLC_GATE_WAIT_MAX="$maxv" bash -c '. ./gw-under-test.sh; gate_wait probe' > "$out" 2>&1 < /dev/null ) &
  w=$!
  # a live gate is ended by a CONDITION: the waiter said it is waiting (or it already left)
  while kill -0 "$w" 2>/dev/null && ! grep -q 'waiting' "$out"; do sleep 0.2; done
  ls "$T/gwr/.git" | grep -c 'ai-dlc-gate-held' > "$T/gw.markers.$mode" || true
  kill "$sp" 2>/dev/null; wait "$w" 2>/dev/null; wait "$sp" 2>/dev/null
  rm -f "$T/gwr/.git"/ai-dlc-gate-held.*
  return 0
}
cell_g_live()  { gw_run "$1" live  "$T/gw.live.out";  has "$T/gw.live.out" "probe: waiting, a push gate" && has "$T/gw.live.out" "no push gate is running now" && ! has "$T/gw.live.out" "anyway"; }
cell_g_dead()  { gw_run "$1" dead  "$T/gw.dead.out";  [ ! -s "$T/gw.dead.out" ]; }
cell_g_reuse() { gw_run "$1" reuse "$T/gw.reuse.out"; [ ! -s "$T/gw.reuse.out" ]; }
cell_g_cap()   { gw_run "$1" cap   "$T/gw.cap.out";   has "$T/gw.cap.out" "past AI_DLC_GATE_WAIT_MAX=0; proceeding anyway" && ! has "$T/gw.cap.out" "no push gate is running now"; }
# the dead marker is also DELETED by the waiter (a stale marker never lingers)
cell_g_gone() { gw_run "$1" dead "$T/gw.gone.out"; [ "$(cat "$T/gw.markers.dead")" = 0 ]; }

# ---- the hook's GATE_HELD marker, over a variant of the span, in a scratch repo $T/ghr
mkdir -p "$T/ghr" && ( cd "$T/ghr" && git init -q . ) > /dev/null 2>&1 || { echo "FIXTURE BROKEN: ghr" >&2; exit 2; }
sed -n '/^# GATE_HELD_BEGIN$/,/^# GATE_HELD_END$/p' "$HOOKSRC" > "$T/v2/gh.base.sh"
grep -q 'ai-dlc-gate-held' "$T/v2/gh.base.sh" || { echo "FIXTURE ERROR: no GATE_HELD span in $HOOKSRC" >&2; exit 2; }
gh_run() { # <variant span> <push lines> <exit mode: green red int term> -> "<markers while running>|<markers after exit>"
  local v="$1" pl="$2" mode="$3" during after body rcx
  rm -f "$T/ghr/.git"/ai-dlc-gate-held.*
  case "$mode" in green) body='exit 0' ;; red) body='exit 1' ;; int) body='kill -INT $$; :' ;; term) body='kill -TERM $$; :' ;; esac
  # under job control the drive has the default INT disposition, which a caller's plain `&` would have turned to ignored
  # the variant span is sourced under one fixed literal name, so the in-process scan resolves the operand (no subject)
  cp "$v" "$T/ghr/gh-under-test.sh" || return 1
  set -m
  ( cd "$T/ghr" && env -u PREPUSH_POOL_DEPTH PUSH_LINES="$pl" bash -c '. ./gh-under-test.sh; ls .git | grep -c "ai-dlc-gate-held"; '"$body" > "$T/gh.out" 2> /dev/null; echo "$?" > "$T/gh.rc" ) 2> /dev/null &
  wait "$!"
  set +m
  during="$(sed -n 1p "$T/gh.out")"; rcx="$(cat "$T/gh.rc")"
  after="$(ls "$T/ghr/.git" | grep -c 'ai-dlc-gate-held')" || after=0
  rm -f "$T/ghr/.git"/ai-dlc-gate-held.*
  printf '%s|%s|%s' "$during" "$after" "$rcx"
}
# the exit status is part of the cell: an INT or TERM cell that the hook did not die from would read as a pass
cell_h_green()  { [ "$(gh_run "$1" 'a b c d' green)" = '1|0|0' ]; }
cell_h_red()    { [ "$(gh_run "$1" 'a b c d' red)" = '1|0|1' ]; }
cell_h_int()    { [ "$(gh_run "$1" 'a b c d' int)" = '1|0|130' ]; }
cell_h_term()  { [ "$(gh_run "$1" 'a b c d' term)" = '1|0|143' ]; }
cell_h_nogate() { [ "$(gh_run "$1" '' green)" = '0|0|0' ]; }

# ---- the seed's @consumer routing, over a variant of scripts/seed-verdict-store.sh, in the stub world $T/w (whose stub
# census records its argv in ../census.argv and answers per name: s-ok* ok, s-red* FAIL, s-cur* not selected, else silence)
drive_s() { # <variant> <out> <names...>
  local v="$1" o="$2"; shift 2
  rm -f "$T/census.argv"
  ( cd "$T/w" && TMPDIR="$T/tmp" bash "$v" "$@" > "$o" 2>&1 < "$T/feed"; echo "exit=$?" >> "$o" )
}
cell_s_route() { # <variant>
  drive_s "$1" "$T/s.route.out" s-ok@consumer s-red@consumer s-cur@consumer
  # s-cur, not selected, prints its own line and no rc line: a current record is never read as a fresh pass
  has "$T/s.route.out" "s-ok@consumer rc=0" && has "$T/s.route.out" "s-red@consumer rc=1" \
    && has "$T/s.route.out" "s-cur@consumer not-selected (record current; nothing ran)" && ! grep -qF "s-cur@consumer rc=" "$T/s.route.out" \
    && has "$T/s.route.out" "exit=1" && [ "$(sed -n 1p "$T/census.argv" 2>/dev/null)" = "--only" ] \
    && [ "$(sed -n 2p "$T/census.argv" 2>/dev/null)" = " s-ok s-red s-cur" ] \
    && ! grep -qxF -- --dirty-ok "$T/census.argv"
}
cell_s_none() { # a name the census gives no verdict for is a refusal, never a pass
  drive_s "$1" "$T/s.none.out" s-none@consumer
  has "$T/s.none.out" "s-none@consumer gave no verdict" && has "$T/s.none.out" "exit=2"
}
cell_s_skip() { # no scripts/gate-wait.sh in the world: the skipped wait is PRINTED
  drive_s "$1" "$T/s.skip.out" s-ok@consumer
  has "$T/s.skip.out" "seed-verdict-store: wait skipped, no scripts/gate-wait.sh here"
}

# ---- predict-push-set.sh's consumer tail, over a variant, in the stub world $T/pw (a stub hook span whose composer
# says `fxa` runs, and a stub census whose --predict says stub-x@consumer runs)
pw_run() { # <variant> <out>
  rm -rf "$T/pw.o"
  ( cd "$T/pw" && AI_DLC_VERDICT_STORE="" bash "$1" "$T/pw" "$T/pw.o" > "$2" 2>&1 < /dev/null; echo "exit=$?" >> "$2" )
}
cell_p_dist() { pw_run "$1" "$T/p.out"; has "$T/p.out" "RUN 1" && has "$T/p.out" "run fxa"; }
cell_p_cons() { pw_run "$1" "$T/p.out"; has "$T/p.out" "CONSUMER 1" && has "$T/p.out" "run stub-x@consumer" && has "$T/p.out" "exit=0"; }


# ---- the predict world
mkdir -p "$T/pw/.githooks" "$T/pw/core/fixtures/fxa" "$T/pw/scripts" || exit 2
cat > "$T/pw/.githooks/pre-push" <<PWH
# FIXTURE_POOL_BEGIN
FXROOT=core/fixtures/
KEYS_DIR=/dev/null/k; VERIFIED_RECORD=/dev/null/v; VERIFIED_FORMAT=/dev/null/v.format
apply_readset_skip() { printf 'fxa\trun\tr\tk\n' > "\$2/.kdec"; echo "   ..    read-set keys: 1 of 1 fixture(s) run"; }
# FIXTURE_POOL_END
fxcount_arm() {
  AI_DLC_VERDICT_STORE="$T/pw.store/counted-aaaaaaaaaaaa"; export AI_DLC_VERDICT_STORE
  mkdir -p "\$AI_DLC_VERDICT_STORE"
}
PWH
printf '#!/usr/bin/env bash\nexit 0\n' > "$T/pw/core/fixtures/fxa/run.sh"
cat > "$T/pw/scripts/census-consumer-layout.sh" <<'PWC'
#!/bin/bash
echo "tree: /nowhere"
echo "   ..    consumer layout: 1 of 1 shipping fixture(s) run as <fx>@consumer in /nowhere"
echo "   ..      stub-x@consumer: changed somewhere"
echo "CONSUMER 1"
echo "run stub-x@consumer"
PWC
( cd "$T/pw" && git init -q . && git add -A && git -c core.hooksPath=/dev/null -c user.name=fx -c user.email=fx@example.invalid commit -q -m world ) > /dev/null 2>&1 \
  || { echo "FIXTURE BROKEN: could not build the predict world" >&2; exit 2; }

# ---- every cell on the subjects
G_CELLS="b_pred b_only b_run c_skip b_hpred b_moved g_live g_dead g_reuse g_cap g_gone h_green h_red h_int h_term h_nogate s_route s_none s_skip p_dist p_cons"
SUBJ_CENSUS="$CENSUS"; SUBJ_GATEW="$GATEW"; SUBJ_SPAN="$T/v2/gh.base.sh"; SUBJ_PRED="$PREDICT"
cell_of() { # <cell> <variant> -> 0 when the cell holds
  case "$1" in
    b_pred) cell_b_pred "$2" "$1.$$.$RANDOM" ;; b_run) cell_b_run "$2" "$1.$$.$RANDOM" ;; b_only) cell_b_only "$2" "$1.$$.$RANDOM" ;;
    c_skip) cell_c_skip "$2" "$1.$$.$RANDOM" ;; b_hpred) cell_b_hpred "$2" "$1.$$.$RANDOM" ;; b_moved) cell_b_moved "$2" "$1.$$.$RANDOM" ;;
    g_live) cell_g_live "$2" ;; g_dead) cell_g_dead "$2" ;; g_reuse) cell_g_reuse "$2" ;; g_cap) cell_g_cap "$2" ;; g_gone) cell_g_gone "$2" ;;
    h_green) cell_h_green "$2" ;; h_red) cell_h_red "$2" ;; h_int) cell_h_int "$2" ;; h_term) cell_h_term "$2" ;; h_nogate) cell_h_nogate "$2" ;;
    s_route) cell_s_route "$2" ;; s_none) cell_s_none "$2" ;; s_skip) cell_s_skip "$2" ;;
    p_dist) cell_p_dist "$2" ;; p_cons) cell_p_cons "$2" ;;
  esac
}
subj_of() { # <cell> -> the subject file
  case "$1" in b_hpred|b_moved) echo "$SUBJ_HOOK" ;; b_*|c_*) echo "$SUBJ_CENSUS" ;; g_*) echo "$SUBJ_GATEW" ;; h_*) echo "$SUBJ_SPAN" ;; s_*) echo "$T/v/control.sh" ;; p_*) echo "$SUBJ_PRED" ;; esac
}
if cell_of b_pred "$(subj_of b_pred)"; then ok "n-b_pred holds on the unmutated subject"; else bad "n-b_pred does not hold on the unmutated subject"; fi
if cell_of b_only "$(subj_of b_only)"; then ok "n-b_only holds on the unmutated subject"; else bad "n-b_only does not hold on the unmutated subject"; fi
if cell_of b_run "$(subj_of b_run)"; then ok "n-b_run holds on the unmutated subject"; else bad "n-b_run does not hold on the unmutated subject"; fi
if cell_of c_skip "$(subj_of c_skip)"; then ok "n-c_skip holds on the unmutated subject"; else bad "n-c_skip does not hold on the unmutated subject"; fi
if cell_of b_hpred "$(subj_of b_hpred)"; then ok "n-b_hpred holds on the unmutated subject"; else bad "n-b_hpred does not hold on the unmutated subject"; fi
if cell_of b_moved "$(subj_of b_moved)"; then ok "n-b_moved holds on the unmutated subject"; else bad "n-b_moved does not hold on the unmutated subject"; fi
if cell_of g_live "$(subj_of g_live)"; then ok "n-g_live holds on the unmutated subject"; else bad "n-g_live does not hold on the unmutated subject"; fi
if cell_of g_dead "$(subj_of g_dead)"; then ok "n-g_dead holds on the unmutated subject"; else bad "n-g_dead does not hold on the unmutated subject"; fi
if cell_of g_reuse "$(subj_of g_reuse)"; then ok "n-g_reuse holds on the unmutated subject"; else bad "n-g_reuse does not hold on the unmutated subject"; fi
if cell_of g_cap "$(subj_of g_cap)"; then ok "n-g_cap holds on the unmutated subject"; else bad "n-g_cap does not hold on the unmutated subject"; fi
if cell_of g_gone "$(subj_of g_gone)"; then ok "n-g_gone holds on the unmutated subject"; else bad "n-g_gone does not hold on the unmutated subject"; fi
if cell_of h_green "$(subj_of h_green)"; then ok "n-h_green holds on the unmutated subject"; else bad "n-h_green does not hold on the unmutated subject"; fi
if cell_of h_red "$(subj_of h_red)"; then ok "n-h_red holds on the unmutated subject"; else bad "n-h_red does not hold on the unmutated subject"; fi
if cell_of h_int "$(subj_of h_int)"; then ok "n-h_int holds on the unmutated subject"; else bad "n-h_int does not hold on the unmutated subject"; fi
if cell_of h_term "$(subj_of h_term)"; then ok "n-h_term holds on the unmutated subject"; else bad "n-h_term does not hold on the unmutated subject"; fi
if cell_of h_nogate "$(subj_of h_nogate)"; then ok "n-h_nogate holds on the unmutated subject"; else bad "n-h_nogate does not hold on the unmutated subject"; fi
if cell_of s_route "$(subj_of s_route)"; then ok "n-s_route holds on the unmutated subject"; else bad "n-s_route does not hold on the unmutated subject"; fi
if cell_of s_none "$(subj_of s_none)"; then ok "n-s_none holds on the unmutated subject"; else bad "n-s_none does not hold on the unmutated subject"; fi
if cell_of s_skip "$(subj_of s_skip)"; then ok "n-s_skip holds on the unmutated subject"; else bad "n-s_skip does not hold on the unmutated subject"; fi
if cell_of p_dist "$(subj_of p_dist)"; then ok "n-p_dist holds on the unmutated subject"; else bad "n-p_dist does not hold on the unmutated subject"; fi
if cell_of p_cons "$(subj_of p_cons)"; then ok "n-p_cons holds on the unmutated subject"; else bad "n-p_cons does not hold on the unmutated subject"; fi

echo "seed-verdict-store-red-print: 5 arms; BL-1092: $(printf "%s" "$G_CELLS" | wc -w | tr -d " ") cells"
report_end seed-verdict-store-red-print
