#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# post-write-gates — reconcile/post-write-gates.sh keys every post-write gate's verdict on the gate's
# OWN exit code, never on its text, and a gate whose exit code was not observed is UNDECIDED.
#
# THE DEFECT. A consumer session ran the update skill's post-write gates as
# `setup-site-drift.sh … | tail -3; echo "rc=${pipestatus[1]}"`, read `rc=` with nothing after it,
# and passed the gates on the last three lines of prose. A gate that prints a clean last line and
# exits non-zero, or prints its refusal above the last three lines, read as clean.
#
# HOW THE ARMS ARE BUILT. Every default gate is replaced by a stub (`--stub <gate>=<script>`) whose
# output and exit code this fixture controls, so each arm separates the two: a clean last line over
# a non-zero exit, a refusal above three clean lines, the word FAIL in prose over exit 0, a gate
# program that is not there. Every arm is PRESENCE-shaped — it requires a specific `GATE` or
# `POST-WRITE-GATES` line to APPEAR — so a runner that prints nothing fails all of them.
#
# THE MUTANTS are copies of the runner, each built with a literal replace that must match exactly
# once (a no-op mutation is DID NOT APPLY, never a kill) and guarded by `cmp -s`. Each must turn at
# least one named arm red, and an unmutated copy built the same way must turn none red.
#
# A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECT: an absent runner prints SKIP and exits 0, never an ok.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
PWG="$(pick "$HERE/../../skills/ai-dlc-update/reconcile/post-write-gates.sh" \
            "$HERE/../../../.claude/skills/ai-dlc-update/reconcile/post-write-gates.sh" \
            "$HERE/../../core/skills/ai-dlc-update/reconcile/post-write-gates.sh")"
echo "HERMETIC-CONSUMED core/skills/ai-dlc-update/reconcile/post-write-gates.sh"
if [ -z "$PWG" ]; then
  echo "SKIP: subject absent — reconcile/post-write-gates.sh predates this fixture's pull"
  exit 0
fi

fails=0; asserts=0
ok()  { asserts=$((asserts+1)); printf '  ok    %s\n' "$1"; }
bad() { asserts=$((asserts+1)); fails=$((fails+1)); printf '  FAIL  %s\n' "$1"; }

W="$(mktemp -d "${TMPDIR:-/tmp}/pwg-fx-XXXXXX")" || { echo "FIXTURE BROKEN: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$W"' EXIT
S="$W/stubs"; mkdir -p "$S"

stub() { # stub <name> <exit> <line>... — a gate that prints the lines and exits <exit>
  local n="$1" x="$2"; shift 2
  { echo '#!/usr/bin/env bash'; for l in "$@"; do printf 'echo %q\n' "$l"; done; echo "exit $x"; } > "$S/$n.sh"
}
stub ok-lt   0 "LEFTOVER-TOKENS none"
stub ok-ssd  0 "SETUP-SITE-SCANNED 4 files" "SETUP-SITE-OK"
stub ok-hr   0 "UNREGISTERED none" "DANGLING none"
stub ok-hb   0 "<!-- BEGIN GENERATED: hard-blockers -->" "0 HARD blockers." "<!-- END GENERATED: hard-blockers -->"
# A1: the filed shape — a clean last line over a non-zero exit.
stub cleanlast 1 "SETUP-SITE-SCANNED 4 files" "SETUP-SITE-OK"
# A3: the refusal is printed ABOVE the last three lines, which are clean.
stub buried 1 "SETUP-SITE-DRIFT steps/deploy-validate.md:26 outside every declared span" \
              "SETUP-SITE-OK team-roles/dev.md" "SETUP-SITE-OK team-roles/qa.md" "SETUP-SITE-SCANNED 4 files"
# A4: the ALLOW twin — the word FAIL in prose, exit 0. A runner keyed on words calls this a FAIL.
stub prosefail 0 "note: a FAIL here would name the file" "SETUP-SITE-OK"
# A6: hard-blockers shapes.
stub hb-rc1   1 "0 HARD blockers."
stub hb-ref   0 "DETECTOR-REFUSED                 layer-drift.sh exited 2 without classifying"
stub hb-hard  0 "HARD-OVERRIDE-DRIFT-SECTION      .claude/skills/ai-dlc/steps/x.md"

ARGS="$W/dist $W/base $W/consumer $W/theirs"
OK_LT="leftover-tokens=$S/ok-lt.sh"; OK_SSD="setup-site-drift=$S/ok-ssd.sh"
OK_HR="hook-registration=$S/ok-hr.sh"; OK_HB="hard-blockers=$S/ok-hb.sh"

# drive <runner> <tag> <ssd-stub> <hb-stub> [extra stub args] — every gate stubbed; writes $W/<tag>.{o,rc}
drive() {
  local r="$1" t="$2" ssd="$3" hb="$4"; shift 4
  bash "$r" --out "$W/out-$t" --stub "$OK_LT" --stub "setup-site-drift=$ssd" --stub "$OK_HR" \
       --stub "hard-blockers=$hb" "$@" $ARGS > "$W/$t.o" 2>&1
  echo $? > "$W/$t.rc"
}
has() { grep -qxF -- "$2" "$W/$1.o"; }
hasre() { grep -qE -- "$2" "$W/$1.o"; }
rc_of() { cat "$W/$1.rc"; }

# check <runner-tag-prefix> — runs every arm against a runner; prints one `ok`/`FAIL` per arm.
# ARM ids are stable so a mutant's kill set can be named.
arms() {
  local r="$1" p="$2"
  drive "$r" "${p}A2" "$S/ok-ssd.sh" "$S/ok-hb.sh"
  if [ "$(rc_of "${p}A2")" = 0 ] \
     && [ "$(grep -c '^GATE ' "$W/${p}A2.o")" = 4 ] \
     && hasre "${p}A2" '^GATE leftover-tokens PASS rc=0 ' && hasre "${p}A2" '^GATE setup-site-drift PASS rc=0 ' \
     && hasre "${p}A2" '^GATE hook-registration PASS rc=0 ' && hasre "${p}A2" '^GATE hard-blockers PASS rc=0 hard=0 refused=0 degenerate=0 ' \
     && hasre "${p}A2" '^POST-WRITE-GATES PASS gates=4/4 pass=4 fail=0 undecided=0 overridden=4 '; then
    echo "A2"
  fi
  drive "$r" "${p}A1" "$S/cleanlast.sh" "$S/ok-hb.sh"
  if [ "$(rc_of "${p}A1")" = 1 ] && hasre "${p}A1" '^GATE setup-site-drift FAIL rc=1 ' \
     && hasre "${p}A1" '^POST-WRITE-GATES FAIL gates=4/4 pass=3 fail=1 undecided=0 '; then
    echo "A1"
  fi
  drive "$r" "${p}A3" "$S/buried.sh" "$S/ok-hb.sh"
  if [ "$(rc_of "${p}A3")" = 1 ] && hasre "${p}A3" '^GATE setup-site-drift FAIL rc=1 ' \
     && grep -qF 'SETUP-SITE-DRIFT steps/deploy-validate.md:26' "$W/out-${p}A3/setup-site-drift.out"; then
    echo "A3"
  fi
  drive "$r" "${p}A4" "$S/prosefail.sh" "$S/ok-hb.sh"
  if [ "$(rc_of "${p}A4")" = 0 ] && hasre "${p}A4" '^GATE setup-site-drift PASS rc=0 ' \
     && hasre "${p}A4" '^POST-WRITE-GATES PASS '; then
    echo "A4"
  fi
  drive "$r" "${p}A5" "$S/no-such-gate.sh" "$S/ok-hb.sh"
  if [ "$(rc_of "${p}A5")" = 1 ] && hasre "${p}A5" '^GATE setup-site-drift UNDECIDED rc=none ' \
     && hasre "${p}A5" '^POST-WRITE-GATES UNDECIDED gates=4/4 pass=3 fail=0 undecided=1 '; then
    echo "A5"
  fi
  drive "$r" "${p}A6a" "$S/ok-ssd.sh" "$S/hb-rc1.sh"
  if [ "$(rc_of "${p}A6a")" = 1 ] && hasre "${p}A6a" '^GATE hard-blockers FAIL rc=1 '; then echo "A6a"; fi
  drive "$r" "${p}A6b" "$S/ok-ssd.sh" "$S/hb-ref.sh"
  if [ "$(rc_of "${p}A6b")" = 1 ] && hasre "${p}A6b" '^GATE hard-blockers FAIL rc=0 hard=0 refused=1 '; then echo "A6b"; fi
  drive "$r" "${p}A6c" "$S/ok-ssd.sh" "$S/hb-hard.sh"
  if [ "$(rc_of "${p}A6c")" = 0 ] && hasre "${p}A6c" '^GATE hard-blockers PASS rc=0 hard=1 refused=0 '; then echo "A6c"; fi
  bash "$r" --stub "no-such-gate=$S/ok-ssd.sh" $ARGS > "$W/${p}A7.o" 2>&1; local a7=$?
  if [ "$a7" = 2 ] && grep -q "names no gate 'no-such-gate'" "$W/${p}A7.o"; then echo "A7"; fi
}
ALL_ARMS="A1 A2 A3 A4 A5 A6a A6b A6c A7"

echo "post-write-gates:"
got="$(arms "$PWG" t-)"
for a in $ALL_ARMS; do
  case " $(echo $got) " in *" $a "*) ok "$a on the shipped runner" ;; *) bad "$a on the shipped runner"; sed 's/^/        /' "$W/t-$a.o" 2>/dev/null ;; esac
done

# --- A8: the leftover-tokens subcommand, against real team-role trees -------------------------
LT="$W/lt"; mkdir -p "$LT/live/.claude/team-roles" "$LT/comment/.claude/team-roles" "$LT/none"
printf '# dev\n\n## Ownership\n{ownership_paths}\n' > "$LT/live/.claude/team-roles/dev.md"
printf '# dev\n<!-- {ownership_paths} is filled by setup -->\nsrc/\n' > "$LT/comment/.claude/team-roles/dev.md"
bash "$PWG" --leftover-tokens "$LT/live" > "$W/lt-live.o" 2>&1; r1=$?
bash "$PWG" --leftover-tokens "$LT/comment" > "$W/lt-comment.o" 2>&1; r2=$?
bash "$PWG" --leftover-tokens "$LT/none" > "$W/lt-none.o" 2>&1; r3=$?
[ "$r1" = 1 ] && grep -qF '{ownership_paths}' "$W/lt-live.o" && ok "A8a a live {token} line exits 1 and is named" || bad "A8a live token: rc=$r1"
[ "$r2" = 0 ] && grep -qxF 'LEFTOVER-TOKENS none' "$W/lt-comment.o" && ok "A8b a {token} inside an HTML comment exits 0" || bad "A8b comment token: rc=$r2"
[ "$r3" = 2 ] && grep -qF 'LEFTOVER-TOKENS REFUSED' "$W/lt-none.o" && ok "A8c no team-roles dir is a refusal (2), never a clean" || bad "A8c no dir: rc=$r3"

# --- the mutants ------------------------------------------------------------------------------
# mkmut <tag> <old> <new> — a copy of the runner with <old> replaced by <new>; must match exactly once.
mkmut() {
  local t="$1" d="$W/mut-$1"; mkdir -p "$d"
  O="$2" N="$3" awk 'BEGIN { o = ENVIRON["O"]; n = ENVIRON["N"]; c = 0 }
    { i = index($0, o); if (i) { $0 = substr($0, 1, i - 1) n substr($0, i + length(o)); c++ } print }
    END { exit (c == 1 ? 0 : 3) }' "$PWG" > "$d/post-write-gates.sh" || { echo "DID NOT APPLY"; return 1; }
  if [ "$t" != control ] && cmp -s "$PWG" "$d/post-write-gates.sh"; then echo "DID NOT APPLY"; return 1; fi
  printf '%s' "$d/post-write-gates.sh"
}
# expect_kill <tag> <path> <arm>... — the mutant must turn every named arm red.
expect_kill() {
  local t="$1" m="$2"; shift 2
  case "$m" in "DID NOT APPLY"*|"") bad "mutant $t DID NOT APPLY"; return ;; esac
  local g missing="" a; g=" $(echo $(arms "$m" "m$t-")) "
  for a in "$@"; do case "$g" in *" $a "*) missing="$missing $a" ;; esac; done
  [ -z "$missing" ] && ok "mutant $t killed by:$(printf ' %s' "$@")" || bad "mutant $t SURVIVED arm(s):$missing"
}

# control: an unmutated copy built the same way turns no arm red (and every arm green).
c="$(mkmut control 'set -uo pipefail' 'set -uo pipefail')"
cg=" $(echo $(arms "$c" mc-)) "
cmiss=""; for a in $ALL_ARMS; do case "$cg" in *" $a "*) : ;; *) cmiss="$cmiss $a" ;; esac; done
[ -z "$cmiss" ] && ok "unmutated copy passes every arm" || bad "unmutated copy FAILED arm(s):$cmiss (the harness, not the runner)"

# M1 the filed shape: read the tail of the output instead of the exit code.
expect_kill tail "$(mkmut tail '    rc=$?' '    tail -3 "$out" > "$out.tail"; if grep -qE "FAIL|DRIFT|REFUSED" "$out.tail"; then rc=1; else rc=0; fi')" A1 A3
# M2 the filed capture's truncation: `| tail -3` keeps the status under the runner's pipefail but
# cuts the evidence, so the refusal printed above the last three lines never reaches the out file.
expect_kill pipe "$(mkmut pipe '    "$@" > "$out" 2>&1' '    "$@" 2>&1 | tail -3 > "$out"')" A3
# M3 an unobserved rc defaults to PASS.
expect_kill rcdefault "$(mkmut rcdefault "''|*[!0-9]*) verdict=UNDECIDED" "''|*[!0-9]*) verdict=PASS")" A5
# M4 a gate dropped from the fixed list (coherently: the count goes with it).
m4="$(mkmut drop 'GATES="leftover-tokens setup-site-drift hook-registration hard-blockers"' 'GATES="leftover-tokens setup-site-drift hook-registration"')"
case "$m4" in "DID NOT APPLY"*) bad "mutant drop DID NOT APPLY" ;; *)
  O='N_GATES=4' N='N_GATES=3' awk 'BEGIN{o=ENVIRON["O"];n=ENVIRON["N"]} $0==o{$0=n;c++} {print} END{exit c==1?0:3}' "$m4" > "$m4.2" \
    && mv "$m4.2" "$m4" && expect_kill drop "$m4" A2 A6a A6b A6c || bad "mutant drop DID NOT APPLY (count line)" ;; esac
# M5 the hard-blockers refusal conjunct removed: its print mode exits 0 over a refusal.
expect_kill hbconj "$(mkmut hbconj 'if [ "$verdict" = PASS ] && {' 'if false && {')" A6b

echo
echo "post-write-gates: $((asserts - fails))/$asserts assertions passed"
[ "$fails" -eq 0 ] || { echo "post-write-gates: FAIL ($fails)"; exit 1; }
echo "post-write-gates: PASS"
exit 0
