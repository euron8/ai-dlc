#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# Ambient AI_DLC_* cleared, as the suite does: the R arms drive the real hook-registration gate, and
# an inherited tunable would test the operator's config, not the runner. AI_DLC_PROJECT_ROOT is set
# per invocation below, never inherited, so clearing it here loses nothing.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
# post-write-gates — reconcile/post-write-gates.sh keys every post-write gate's verdict on the gate's
# OWN exit code, never on its text, and a gate whose exit code was not observed is UNDECIDED.
#
# THE DEFECT. A consumer session ran the update skill's post-write gates as
# `setup-site-drift.sh … | tail -3; echo "rc=${pipestatus[1]}"`, read `rc=` with nothing after it,
# and passed the gates on the last three lines of prose. A gate that prints a clean last line and
# exits non-zero, or prints its refusal above the last three lines, read as clean.
#
# TWO KINDS OF ARM.
#   A*  every gate replaced by a stub (`--stub <gate>=<script>`) whose output and exit code this
#       fixture controls, so each arm separates the two: a clean last line over a non-zero exit, a
#       refusal above three clean lines, the word FAIL in prose over exit 0, a gate program that is
#       not there, a gate that exits 127, the hard-blockers rows its print mode exits 0 over.
#   R*  ONE gate left REAL and the other three stubbed, against a seeded world the real program
#       accepts, so the runner's own INVOCATION of that gate — its flags and argument order — is
#       what the arm reads. A stub-only suite cannot see that wiring at all: dropping `--root` from
#       the hook-registration call, `--post-apply` from the hard-blockers call, or swapping
#       setup-site-drift's arguments all passed every A arm. R0 runs all four real and is the only
#       arm that can reach exit 0, so the standard is shown SATISFIABLE.
# Every arm is PRESENCE-shaped — it requires a specific `GATE`/`POST-WRITE-GATES` line, or a line in
# the gate's own out file, to APPEAR — so a runner that prints nothing fails all of them.
#
# A RUN WITH ANY OVERRIDE EXITS 1. The runner exits 0 only when every gate passed AND no gate was
# stubbed, and says `overrides-in-force` on its summary otherwise; every A and R arm but R0 is a
# stubbed run and expects exactly that.
#
# THE MUTANTS are copies of the runner, each built with a literal replace that must match exactly
# once (a no-op mutation is DID NOT APPLY, never a kill) and guarded by `cmp -s`. A mutant sits in a
# directory of symlinks to the real reconcile siblings, so the R arms reach the real gates from it.
# Each mutant runs only the arms named to kill it and must turn every one of them red; an unmutated
# copy built the same way must pass every arm.
#
# A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECT: an absent runner prints SKIP and exits 0, never an ok.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
PWG="$(pick "$HERE/../../skills/ai-dlc-update/reconcile/post-write-gates.sh" \
            "$HERE/../../../.claude/skills/ai-dlc-update/reconcile/post-write-gates.sh")"
echo "HERMETIC-CONSUMED core/skills/ai-dlc-update/reconcile/"
if [ -z "$PWG" ]; then
  echo "SKIP: subject absent — reconcile/post-write-gates.sh predates this fixture's pull"
  exit 0
fi
RDIR="$(cd "$(dirname "$PWG")" && pwd)"
# The hook-registration gate runs the CONSUMER's installed validator, so the seeded consumer gets a
# copy of the real one: core/scripts/ in the distribution, scripts/ai-dlc/ on a consumer.
HRV="$(pick "$HERE/../../scripts/validate-hook-registration.sh" \
            "$HERE/../../../scripts/ai-dlc/validate-hook-registration.sh")"

fails=0; asserts=0
ok()  { asserts=$((asserts+1)); printf '  ok    %s\n' "$1"; }
bad() { asserts=$((asserts+1)); fails=$((fails+1)); printf '  FAIL  %s\n' "$1"; }
. "$HERE/../lib/mutant.sh"
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"

W="$(mktemp -d "${TMPDIR:-/tmp}/pwg-fx-XXXXXX")" || { echo "FIXTURE BROKEN: mktemp failed" >&2; exit 2; }
trap 'chmod -R u+rwx "$W" 2>/dev/null; rm -rf "$W"' EXIT
S="$W/stubs"; mkdir -p "$S"
for need in hard-blockers.sh setup-site-drift.sh settings-merge.sh; do
  [ -f "$RDIR/$need" ] || { echo "FIXTURE BROKEN: reconcile/$need is not beside the runner at $RDIR" >&2; exit 2; }
done
[ -n "$HRV" ] || { echo "FIXTURE BROKEN: validate-hook-registration.sh found in neither layout" >&2; exit 2; }

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
# A5b: the gate's own file exists and a program IT runs does not — the validator's body is python3.
stub gate127 127 "validate-hook-registration.sh: line 147: python3: command not found"
# A6: hard-blockers shapes. The degenerate row is spelled as hard-blockers.sh prints it
# (`%-32s %s`, inside the generated region, under the affirmative line), at exit 0.
stub hb-rc1   1 "0 HARD blockers."
stub hb-ref   0 "DETECTOR-REFUSED                 layer-drift.sh exited 2 without classifying"
stub hb-hard  0 "HARD-OVERRIDE-DRIFT-SECTION      .claude/skills/ai-dlc/steps/x.md"
stub hb-deg   0 "<!-- BEGIN GENERATED: hard-blockers — rendered by reconcile/hard-blockers.sh; do not hand-edit -->" \
                "0 HARD blockers." \
                "DRIFT-RANGE-DEGENERATE           this run could not fire layer-drift.sh's range-keyed adjudication arms — base and theirs resolve to the same commit — so the list above is silent about the layer rather than clean on it. Re-run with the PULL's base; post-apply, pass --post-apply." \
                "<!-- END GENERATED: hard-blockers -->"

ARGS="$W/dist $W/base $W/consumer $W/theirs"
OK_LT="leftover-tokens=$S/ok-lt.sh"; OK_SSD="setup-site-drift=$S/ok-ssd.sh"
OK_HR="hook-registration=$S/ok-hr.sh"; OK_HB="hard-blockers=$S/ok-hb.sh"
GATE_NAMES="leftover-tokens setup-site-drift hook-registration hard-blockers"
okstub() { case "$1" in leftover-tokens) echo "$S/ok-lt.sh" ;; setup-site-drift) echo "$S/ok-ssd.sh" ;;
                         hook-registration) echo "$S/ok-hr.sh" ;; hard-blockers) echo "$S/ok-hb.sh" ;; esac; }

# --- the real-gate world ------------------------------------------------------------------------
# A distribution repo with two commits and a consumer that each real gate accepts post-apply:
#   setup-site-drift   the four files setup-sites.md declares, with every site locatable in theirs;
#                      the consumer fills the two heading-block sites and is byte-identical elsewhere.
#   leftover-tokens    the consumer's team-role files carry no `{token}` on a live line.
#   hook-registration  one ai-dlc hook on disk, registered in settings.json, and settings-merge.sh
#                      where the validator binds its ownership pattern.
#   hard-blockers      a non-degenerate range, and the reconcile-blocking-list seed's wrong-base
#                      artefact: a non-machinery step file whose non-token line moved upstream, which
#                      the consumer carries at theirs with its token substituted. Against the PULL's
#                      base it is HARD-UNREGISTERED-CORE-DRIFT; under --post-apply it is not. That
#                      is what lets an arm see a dropped `--post-apply`.
# A DECOY tree is exported as AI_DLC_PROJECT_ROOT for every R run. Its one registration DANGLES, so a
# validator invoked without `--root` judges the decoy and exits 1; with `--root` it judges the
# consumer. Without the decoy the validator would walk up from its own install path to the same
# consumer and a dropped `--root` would be invisible.
RW="$W/world"; RD="$RW/dist"; RC="$RW/consumer"; RX="$RW/decoy"
mkdir -p "$RD/core/team-roles" "$RD/core/skills/ai-dlc/steps" \
         "$RC/.claude/team-roles" "$RC/.claude/skills/ai-dlc/steps" "$RC/.claude/hooks" \
         "$RC/.claude/skills/ai-dlc-update/reconcile" "$RC/scripts/ai-dlc" \
         "$RX/.claude/skills/ai-dlc-update/reconcile"
role() { printf '# %s\n\n## Ownership\n\n%s\n\n## Responsibilities\n\n- build\n' "$1" "$2"; }
role dev '{ownership_paths}' > "$RD/core/team-roles/dev.md"
role qa  '{ownership_paths}' > "$RD/core/team-roles/qa.md"
printf '%s\n' '# Deploy' '' '### 2. Deploy' '' "Run the project's deployment command:" '```' '{deploy_command}' '```' \
  '' '### 3. Smoke Tests' '' '```' '{smoke_test_command} 2>&1 | tee test-results/smoke-test-output.txt' '```' \
  > "$RD/core/skills/ai-dlc/steps/deploy-validate.md"
printf '%s\n' '# Implementation' '' '- Dev teammates run live smoke tests' \
  '  ({smoke_test_command}) and log output in the story file. Unit tests' '  alone are not sufficient.' \
  > "$RD/core/skills/ai-dlc/steps/implementation.md"
moved() { printf '# Moved step\n\nowner: %s\npad line one, unchanged across the range.\npad line two, unchanged across the range.\nrule: %s\n' "$1" "$2"; }
moved '{project_name}' base-text > "$RD/core/skills/ai-dlc/steps/moved.md"
gd() { git -C "$RD" -c user.email=f@f -c user.name=fixture "$@" >/dev/null 2>&1; }
gd init -q && gd add -A && gd commit -q -m base || { echo "FIXTURE BROKEN: could not commit the world's base" >&2; exit 2; }
R_BASE="$(git -C "$RD" rev-parse HEAD)"
moved '{project_name}' theirs-text > "$RD/core/skills/ai-dlc/steps/moved.md"
gd add -A && gd commit -q -m theirs || { echo "FIXTURE BROKEN: could not commit the world's theirs" >&2; exit 2; }
R_THEIRS="$(git -C "$RD" rev-parse HEAD)"
role dev 'src/'   > "$RC/.claude/team-roles/dev.md"
role qa  'tests/' > "$RC/.claude/team-roles/qa.md"
cp "$RD/core/skills/ai-dlc/steps/deploy-validate.md" "$RD/core/skills/ai-dlc/steps/implementation.md" "$RC/.claude/skills/ai-dlc/steps/"
moved acme theirs-text > "$RC/.claude/skills/ai-dlc/steps/moved.md"
printf '#!/usr/bin/env bash\n# probe hook for the post-write-gates fixture\nexit 0\n' > "$RC/.claude/hooks/ai-dlc-probe.sh"
printf '{"hooks":{"PreToolUse":[{"hooks":[{"type":"command","command":"bash \\"$CLAUDE_PROJECT_DIR\\"/.claude/hooks/%s"}]}]}}\n' \
  ai-dlc-probe.sh > "$RC/.claude/settings.json"
printf '{"hooks":{"PreToolUse":[{"hooks":[{"type":"command","command":"bash \\"$CLAUDE_PROJECT_DIR\\"/.claude/hooks/%s"}]}]}}\n' \
  ai-dlc-gone.sh > "$RX/.claude/settings.json"
cp "$RDIR/settings-merge.sh" "$RC/.claude/skills/ai-dlc-update/reconcile/"
cp "$RDIR/settings-merge.sh" "$RX/.claude/skills/ai-dlc-update/reconcile/"
cp "$HRV" "$RC/scripts/ai-dlc/validate-hook-registration.sh"
R_ARGS="$RD $R_BASE $RC $R_THEIRS"

# drive <runner> <tag> <ssd-stub> <hb-stub> [extra stub args] — every gate stubbed; writes $W/<tag>.{o,rc}
drive() {
  local r="$1" t="$2" ssd="$3" hb="$4"; shift 4
  bash "$r" --out "$W/out-$t" --stub "$OK_LT" --stub "setup-site-drift=$ssd" --stub "$OK_HR" \
       --stub "hard-blockers=$hb" "$@" $ARGS > "$W/$t.o" 2>&1
  echo $? > "$W/$t.rc"
}
# drive_real <runner> <tag> <gate|all> — that gate real (or all four), the rest stubbed, in the world.
drive_real() {
  local r="$1" t="$2" g="$3" a sa=""
  for a in $GATE_NAMES; do
    [ "$g" = all ] || [ "$a" = "$g" ] || sa="$sa --stub $a=$(okstub "$a")"
  done
  AI_DLC_PROJECT_ROOT="$RX" bash "$r" --out "$W/out-$t" $sa $R_ARGS > "$W/$t.o" 2>&1
  echo $? > "$W/$t.rc"
}
hasre() { grep -qE -- "$2" "$W/$1.o"; }
rc_of() { cat "$W/$1.rc"; }
outf() { printf '%s' "$W/out-$1/$2.out"; }
SUM_STUBBED_PASS4='^POST-WRITE-GATES PASS gates=4/4 pass=4 fail=0 undecided=0 overridden=4 overrides-in-force out='
SUM_STUBBED_PASS3='^POST-WRITE-GATES PASS gates=4/4 pass=4 fail=0 undecided=0 overridden=3 overrides-in-force out='

# --- the arms: each prints its own id when it holds -----------------------------------------------
arm_A2() { local t="$2A2"; drive "$1" "$t" "$S/ok-ssd.sh" "$S/ok-hb.sh"
  [ "$(rc_of "$t")" = 1 ] && [ "$(grep -c '^GATE ' "$W/$t.o")" = 4 ] \
  && hasre "$t" '^GATE leftover-tokens PASS rc=0 ' && hasre "$t" '^GATE setup-site-drift PASS rc=0 ' \
  && hasre "$t" '^GATE hook-registration PASS rc=0 ' && hasre "$t" '^GATE hard-blockers PASS rc=0 hard=0 refused=0 degenerate=0 ' \
  && hasre "$t" "$SUM_STUBBED_PASS4" && echo A2; }
arm_A1() { local t="$2A1"; drive "$1" "$t" "$S/cleanlast.sh" "$S/ok-hb.sh"
  [ "$(rc_of "$t")" = 1 ] && hasre "$t" '^GATE setup-site-drift FAIL rc=1 ' \
  && hasre "$t" '^POST-WRITE-GATES FAIL gates=4/4 pass=3 fail=1 undecided=0 ' && echo A1; }
arm_A3() { local t="$2A3"; drive "$1" "$t" "$S/buried.sh" "$S/ok-hb.sh"
  [ "$(rc_of "$t")" = 1 ] && hasre "$t" '^GATE setup-site-drift FAIL rc=1 ' \
  && grep -qF 'SETUP-SITE-DRIFT steps/deploy-validate.md:26' "$(outf "$t" setup-site-drift)" && echo A3; }
arm_A4() { local t="$2A4"; drive "$1" "$t" "$S/prosefail.sh" "$S/ok-hb.sh"
  [ "$(rc_of "$t")" = 1 ] && hasre "$t" '^GATE setup-site-drift PASS rc=0 ' \
  && hasre "$t" "$SUM_STUBBED_PASS4" && echo A4; }
arm_A5() { local t="$2A5"; drive "$1" "$t" "$S/no-such-gate.sh" "$S/ok-hb.sh"
  [ "$(rc_of "$t")" = 1 ] && hasre "$t" '^GATE setup-site-drift UNDECIDED rc=none ' \
  && hasre "$t" '^POST-WRITE-GATES UNDECIDED gates=4/4 pass=3 fail=0 undecided=1 ' && echo A5; }
arm_A5b() { local t="$2A5b"; drive "$1" "$t" "$S/gate127.sh" "$S/ok-hb.sh"
  [ "$(rc_of "$t")" = 1 ] && hasre "$t" '^GATE setup-site-drift UNDECIDED rc=127 ' \
  && hasre "$t" '^POST-WRITE-GATES UNDECIDED gates=4/4 pass=3 fail=0 undecided=1 ' && echo A5b; }
arm_A6a() { local t="$2A6a"; drive "$1" "$t" "$S/ok-ssd.sh" "$S/hb-rc1.sh"
  [ "$(rc_of "$t")" = 1 ] && hasre "$t" '^GATE hard-blockers FAIL rc=1 ' && echo A6a; }
arm_A6b() { local t="$2A6b"; drive "$1" "$t" "$S/ok-ssd.sh" "$S/hb-ref.sh"
  [ "$(rc_of "$t")" = 1 ] && hasre "$t" '^GATE hard-blockers FAIL rc=0 hard=0 refused=1 degenerate=0 ' && echo A6b; }
arm_A6c() { local t="$2A6c"; drive "$1" "$t" "$S/ok-ssd.sh" "$S/hb-hard.sh"
  [ "$(rc_of "$t")" = 1 ] && hasre "$t" '^GATE hard-blockers PASS rc=0 hard=1 refused=0 degenerate=0 ' \
  && hasre "$t" "$SUM_STUBBED_PASS4" && echo A6c; }
arm_A6d() { local t="$2A6d"; drive "$1" "$t" "$S/ok-ssd.sh" "$S/hb-deg.sh"
  [ "$(rc_of "$t")" = 1 ] && hasre "$t" '^GATE hard-blockers FAIL rc=0 hard=0 refused=0 degenerate=1 ' \
  && hasre "$t" '^POST-WRITE-GATES FAIL gates=4/4 pass=3 fail=1 undecided=0 ' && echo A6d; }
arm_A7() { local t="$2A7"; bash "$1" --stub "no-such-gate=$S/ok-ssd.sh" $ARGS > "$W/$t.o" 2>&1; local a7=$?
  [ "$a7" = 2 ] && grep -q "names no gate 'no-such-gate'" "$W/$t.o" && echo A7; }
# A8d: grep's own 2 with the directory PRESENT — one unreadable file under it. The readable file is
# clean, so a runner that took grep's 2 as "no match" would print `LEFTOVER-TOKENS none` and exit 0.
arm_A8d() { local t="$2A8d"; bash "$1" --leftover-tokens "$LT/unread" > "$W/$t.o" 2>&1; echo $? > "$W/$t.rc"
  [ "$(rc_of "$t")" = 2 ] && hasre "$t" '^LEFTOVER-TOKENS REFUSED — grep exited 2 reading ' && echo A8d; }
# R arms. Each asserts the GATE line AND a line only the REAL program prints, read off its out file.
arm_RLT() { local t="$2RLT"; drive_real "$1" "$t" leftover-tokens
  [ "$(rc_of "$t")" = 1 ] && hasre "$t" '^GATE leftover-tokens PASS rc=0 ' && hasre "$t" "$SUM_STUBBED_PASS3" \
  && grep -qxF 'LEFTOVER-TOKENS none' "$(outf "$t" leftover-tokens)" && echo RLT; }
arm_RSSD() { local t="$2RSSD"; drive_real "$1" "$t" setup-site-drift
  [ "$(rc_of "$t")" = 1 ] && hasre "$t" '^GATE setup-site-drift PASS rc=0 ' && hasre "$t" "$SUM_STUBBED_PASS3" \
  && grep -qE '^SETUP-SITE-SCANNED.*across 4 file\(s\)' "$(outf "$t" setup-site-drift)" \
  && grep -qE '^SETUP-SITE-OK[[:space:]]+\.claude/team-roles/dev\.md[[:space:]]+differs from theirs only inside declared spans' "$(outf "$t" setup-site-drift)" \
  && echo RSSD; }
arm_RHR() { local t="$2RHR"; drive_real "$1" "$t" hook-registration
  [ "$(rc_of "$t")" = 1 ] && hasre "$t" '^GATE hook-registration PASS rc=0 ' && hasre "$t" "$SUM_STUBBED_PASS3" \
  && grep -qxF "hook-registration: root $RC" "$(outf "$t" hook-registration)" \
  && grep -qF 'UNREGISTERED: none (1 present hook(s) checked)' "$(outf "$t" hook-registration)" && echo RHR; }
arm_RHB() { local t="$2RHB"; drive_real "$1" "$t" hard-blockers
  [ "$(rc_of "$t")" = 1 ] && hasre "$t" '^GATE hard-blockers PASS rc=0 hard=0 refused=0 degenerate=0 ' \
  && hasre "$t" "$SUM_STUBBED_PASS3" && grep -qxF '0 HARD blockers.' "$(outf "$t" hard-blockers)" && echo RHB; }
arm_R0() { local t="$2R0"; drive_real "$1" "$t" all
  [ "$(rc_of "$t")" = 0 ] && ! grep -q '^OVERRIDE ' "$W/$t.o" && [ "$(grep -c ' PASS rc=0 ' "$W/$t.o")" = 4 ] \
  && hasre "$t" '^POST-WRITE-GATES PASS gates=4/4 pass=4 fail=0 undecided=0 overridden=0 out=' && echo R0; }

ALL_ARMS="A1 A2 A3 A4 A5 A5b A6a A6b A6c A6d A7 A8d RLT RSSD RHR RHB R0"
# arms <runner> <tag-prefix> [arm ids] — runs the named arms (default: all); prints the ids that held.
arms() { local r="$1" p="$2" a; shift 2; [ $# -gt 0 ] || set -- $ALL_ARMS
  for a in "$@"; do "arm_$a" "$r" "$p"; done; }

# --- A8: the leftover-tokens subcommand, against real team-role trees -------------------------
LT="$W/lt"; mkdir -p "$LT/live/.claude/team-roles" "$LT/comment/.claude/team-roles" "$LT/none" "$LT/unread"
printf '# dev\n\n## Ownership\n{ownership_paths}\n' > "$LT/live/.claude/team-roles/dev.md"
printf '# dev\n<!-- {ownership_paths} is filled by setup -->\nsrc/\n' > "$LT/comment/.claude/team-roles/dev.md"
mkdir -p "$LT/unread/.claude/team-roles"
printf '# dev\nsrc/\n' > "$LT/unread/.claude/team-roles/dev.md"
printf '# qa\n{qa_ownership_paths}\n' > "$LT/unread/.claude/team-roles/qa.md"
chmod 000 "$LT/unread/.claude/team-roles/qa.md"

echo "post-write-gates:"
# WORLD CONTROLS — each proves the world can tell a mutant from the runner, before any arm is read.
if [ -r "$LT/unread/.claude/team-roles/qa.md" ]; then
  bad "WORLD: chmod 000 left qa.md readable (running as root?) — A8d cannot construct grep's exit 2"
else
  ok "WORLD: an unreadable team-role file is constructible, so A8d reaches grep's exit 2"
fi
wc_hb="$(bash "$RDIR/hard-blockers.sh" "$RD" "$R_BASE" "$RC" "$R_THEIRS" 2>/dev/null)"
grep -qE '^HARD-[A-Z-]+ +(\.claude/)?skills/ai-dlc/steps/moved\.md' <<<"$wc_hb" \
  && ok "WORLD: hard-blockers WITHOUT --post-apply names the wrong-base artefact, so RHB can see a dropped flag" \
  || bad "WORLD: hard-blockers without --post-apply printed no HARD row for moved.md — RHB cannot discriminate"
bash "$RC/scripts/ai-dlc/validate-hook-registration.sh" --root "$RX" > "$W/wc-decoy.o" 2>&1; wc_x=$?
[ "$wc_x" = 1 ] && grep -qF 'ai-dlc-gone.sh' "$W/wc-decoy.o" \
  && ok "WORLD: the decoy tree fails hook-registration (DANGLING), so RHR can see a dropped --root" \
  || bad "WORLD: the decoy tree read rc=$wc_x, not 1 with a DANGLING row — RHR cannot discriminate"

got=" $(echo $(arms "$PWG" t-)) "
for a in $ALL_ARMS; do
  case "$got" in *" $a "*) ok "$a on the shipped runner" ;; *) bad "$a on the shipped runner"; sed 's/^/        /' "$W/t-$a.o" 2>/dev/null ;; esac
done

bash "$PWG" --leftover-tokens "$LT/live" > "$W/lt-live.o" 2>&1; r1=$?
bash "$PWG" --leftover-tokens "$LT/comment" > "$W/lt-comment.o" 2>&1; r2=$?
bash "$PWG" --leftover-tokens "$LT/none" > "$W/lt-none.o" 2>&1; r3=$?
[ "$r1" = 1 ] && grep -qF '{ownership_paths}' "$W/lt-live.o" && ok "A8a a live {token} line exits 1 and is named" || bad "A8a live token: rc=$r1"
[ "$r2" = 0 ] && grep -qxF 'LEFTOVER-TOKENS none' "$W/lt-comment.o" && ok "A8b a {token} inside an HTML comment exits 0" || bad "A8b comment token: rc=$r2"
[ "$r3" = 2 ] && grep -qF 'LEFTOVER-TOKENS REFUSED' "$W/lt-none.o" && ok "A8c no team-roles dir is a refusal (2), never a clean" || bad "A8c no dir: rc=$r3"

# --- the mutants ------------------------------------------------------------------------------
# mkmut <tag> <old> <new> — a copy of the runner with <old> replaced by <new>; must match exactly once.
# The copy sits among symlinks to every real sibling, so `$SELF/<gate>.sh` resolves for the R arms.
mkmut() {
  local t="$1" d="$W/mut-$1" f b; mkdir -p "$d"
  for f in "$RDIR"/*; do b="${f##*/}"; [ "$b" = post-write-gates.sh ] || ln -s "$f" "$d/$b"; done
  O="$2" N="$3" awk 'BEGIN { o = ENVIRON["O"]; n = ENVIRON["N"]; c = 0 }
    { i = index($0, o); if (i) { $0 = substr($0, 1, i - 1) n substr($0, i + length(o)); c++ } print }
    END { exit (c == 1 ? 0 : 3) }' "$PWG" > "$d/post-write-gates.sh" || { echo "DID NOT APPLY"; return 1; }
  if [ "$t" != control ] && cmp -s "$PWG" "$d/post-write-gates.sh"; then echo "DID NOT APPLY"; return 1; fi
  printf '%s' "$d/post-write-gates.sh"
}
# expect_kill <tag> <path> <arm>... — the named arms are run against the mutant; every one must turn red.
expect_kill() {
  local t="$1" m="$2"; shift 2
  case "$m" in "DID NOT APPLY"*|"") bad "mutant $t DID NOT APPLY"; return ;; esac
  local g missing="" a; g=" $(echo $(arms "$m" "m$t-" "$@")) "
  for a in "$@"; do case "$g" in *" $a "*) missing="$missing $a" ;; esac; done
  if [ -z "$missing" ]; then
    mutant_killed "${B_CTL:-0}" "$t" "mutant $t killed by:$(printf ' %s' "$@")"
  else
    bad "mutant $t SURVIVED arm(s):$missing"
  fi
}

# control: an unmutated copy built the same way, in the same symlink farm, passes every arm.
c="$(mkmut control 'set -uo pipefail' 'set -uo pipefail')"
cg=" $(echo $(arms "$c" mc-)) "
cmiss=""; for a in $ALL_ARMS; do case "$cg" in *" $a "*) : ;; *) cmiss="$cmiss $a" ;; esac; done
if [ -z "$cmiss" ]; then
  ok "unmutated copy passes every arm"; B_CTL=1
else
  bad "unmutated copy FAILED arm(s):$cmiss (the harness, not the runner)"
fi

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
# M6 the degenerate row never counted (the conjunct itself untouched).
expect_kill degzero "$(mkmut degzero "n_deg=\"\$(grep -c '^DRIFT-RANGE-DEGENERATE' \"\$out\")\" || n_deg=0" 'n_deg=0')" A6d
# M7 the degenerate half of the conjunct removed; the refusal half kept.
expect_kill degconj "$(mkmut degconj '{ [ "$n_ref" -ne 0 ] || [ "$n_deg" -ne 0 ]; }' '[ "$n_ref" -ne 0 ]')" A6d
# M8 exit 0 under overrides: a stubbed run passes as a production one.
expect_kill ovrexit "$(mkmut ovrexit '[ "$overall" = PASS ] && [ "$n_over" -eq 0 ] && exit 0' '[ "$overall" = PASS ] && exit 0')" A2 A4 A6c RLT
# M9 the summary stops saying overrides were in force.
expect_kill ovrword "$(mkmut ovrword '[ "$n_over" -eq 0 ] || ovr=" overrides-in-force"' '[ "$n_over" -eq 0 ] || ovr=""')" A2 A4 RHR
# M10 exit 0 made unreachable: the all-real run can no longer pass.
expect_kill never0 "$(mkmut never0 '[ "$overall" = PASS ] && [ "$n_over" -eq 0 ] && exit 0' '[ "$overall" = PASS ] && [ "$n_over" -eq 99 ] && exit 0')" R0
# M11 the 126/127 row deleted in effect: a gate whose child program is missing reads FAIL, not UNDECIDED.
expect_kill r127 "$(mkmut r127 '126|127)     verdict=UNDECIDED ;;' '126|127)     verdict=FAIL ;;')" A5b
# M12 grep's 2 accepted as "no match": an unreadable team-role file scans as clean.
expect_kill ltrc "$(mkmut ltrc '[ "$lt_rc" -le 1 ] ||' 'true ||')" A8d
# M13-M16 the real-gate WIRING: each one passed every stub-only arm.
expect_kill ltarg "$(mkmut ltarg '--leftover-tokens "$CONSUMER"' '--leftover-tokens "$DIST"')" RLT
expect_kill ssdargs "$(mkmut ssdargs '"$DIST" "$CONSUMER" "$THEIRS" ;;' '"$DIST" "$THEIRS" "$CONSUMER" ;;')" RSSD
expect_kill noroot "$(mkmut noroot 'set -- bash "$prog" --root "$CONSUMER" ;;' 'set -- bash "$prog" ;;')" RHR
expect_kill nopostapply "$(mkmut nopostapply '--post-apply "$DIST"' '"$DIST"')" RHB

echo
echo "post-write-gates: $((asserts - fails))/$asserts assertions passed"
[ "$fails" -eq 0 ] || { echo "post-write-gates: FAIL ($fails)"; exit 1; }
echo "post-write-gates: PASS"
exit 0
