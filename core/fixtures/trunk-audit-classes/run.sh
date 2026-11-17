#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
# trunk-audit-classes — assert `validate-cycle-commits.sh --audit-trunk` fires, and only where
# it should.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the mode regressed, 2 = fixture broken.
#
# THE GOAL THIS SERVES. Charter goal 5 is absorption of the consumer scripts that duplicate a
# core mechanism. The post-merge trunk audit was one of them: every ai-dlc consumer has a
# trunk, merges into it, and validators keyed to a class of change, and `gh pr merge --admin`,
# a web-UI merge and a direct push all bypass the PreToolUse hook and the pre-push hook alike.
# The mechanism is core's; only the CLASS TAXONOMY is the consumer's, and it is declared.
#
# WHY EACH ARM IS LOAD-BEARING:
#   1. A commit whose class's validators pass against ITS OWN TREE is CLEAN. Without this the
#      mode is a blanket failure and the first compliant trunk is wedged by its compliance.
#   2. A commit whose class's validator FAILS against its own tree is a finding. This is the
#      bypass itself — the verdict is re-derived from the committed tree, never from a log,
#      because the merge this exists to catch never wrote one.
#   3. A commit matching NO class is a finding, not a skip. Fail closed: an unclassifiable
#      change on the trunk is the shape of the thing being looked for.
#   4. A declared validator ABSENT from the audited tree is a finding. "It was not there" and
#      "it passed" are the same silence otherwise.
#   5. An UNDECLARED taxonomy prints a worklist and exits 0. This is the stop condition the
#      step spec wrote in advance: a project that has not adopted this must not have its trunk
#      wedged by it. E17/W6 and E18/W10 are the precedents and neither wedged anyone.
#   6. A MALFORMED taxonomy is not an empty one — it exits 1 and audits nothing.
#   7. The watermark advances to the last clean commit and STOPS at the first finding.
#   8. An empty range carries its control in the same run: a zero from an enumeration that
#      never ran reads exactly like a clean trunk.

set -uo pipefail
# Clear every inherited AI_DLC_* tunable and CLAUDE_PROJECT_DIR so a bare run judges the code, not the caller environment.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset CLAUDE_PROJECT_DIR

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"

if [ -n "$ROOT" ] && [ -f "$ROOT/core/scripts/validate-cycle-commits.sh" ]; then
  VAL="$ROOT/core/scripts/validate-cycle-commits.sh"
elif [ -n "$ROOT" ] && [ -f "$ROOT/scripts/ai-dlc/validate-cycle-commits.sh" ]; then
  VAL="$ROOT/scripts/ai-dlc/validate-cycle-commits.sh"
else
  echo "FIXTURE ERROR: validate-cycle-commits.sh not found in either layout" >&2; exit 2
fi
# BOTH LAYOUTS, because install.sh splits what shares a parent in core/ and a fixture that
# knows only the distribution path exits 2 in a consumer — which the suite reports as a FAIL,
# not as a skip. That is v0.234.1, produced by the sibling fixture one release earlier.
echo "HERMETIC-CONSUMED $VAL"
if [ -n "$ROOT" ] && [ -f "$ROOT/core/skills/ai-dlc/layer-contract.yaml" ]; then
  REAL_LC="$ROOT/core/skills/ai-dlc/layer-contract.yaml"
elif [ -n "$ROOT" ] && [ -f "$ROOT/.claude/skills/ai-dlc/layer-contract.yaml" ]; then
  REAL_LC="$ROOT/.claude/skills/ai-dlc/layer-contract.yaml"
else
  echo "FIXTURE ERROR: layer-contract.yaml was not found in either layout" >&2; exit 2
fi

WORK="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd)"
trap 'rm -rf "$WORK"' EXIT

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }

# IN PROCESS (BL-878). validate-cycle-commits.sh is LOADED once (core/fixtures/lib/inproc.sh inproc_load: its column-0
# guard returns after defining vcc_main) and every audit below is `inproc_run "$VAL" vcc_main --audit-trunk ...`: a
# subshell holding only the subject's functions, the caller's exported variables and a fresh bash's options (the
# subject sets none of its own), so the call starts as the program would. Each call is one fx_inproc pass (the
# inproc: row). Two cli cells, exit 0 (a clean range) and exit 1 (a finding), each compare the program's stdout,
# stderr and exit with the in-process call on the same world at the same path (cells.decl).
# A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECT: a validator with neither its `vcc_main() {` line nor the column-0 source
# guard predates the wrap and reads SKIP through fx_skip_exit (exit 0 on a consumer, never an ok; FIXTURE BROKEN in the
# distribution); exactly one half FAILs; an unreadable one is FIXTURE ERROR.
. "$HERE/../lib/mutant.sh" || { echo "FIXTURE BROKEN: cannot source lib/mutant.sh" >&2; exit 2; }
. "$HERE/../lib/layout.sh" || { echo "FIXTURE BROKEN: cannot source lib/layout.sh" >&2; exit 2; }
grep -q '^vcc_main() {$' "$VAL"; _wd=$?
grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$VAL"; _wg=$?
if [ "$_wd" -gt 1 ] || [ "$_wg" -gt 1 ]; then
  echo "FIXTURE ERROR: cannot read $VAL (grep exit $_wd/$_wg), so the in-process wrap cannot be judged; nothing was asserted" >&2; exit 2
fi
case "$_wd$_wg" in
  00) ;;
  11) echo "SKIP: subject predates the in-process wrap"; fx_skip_exit "$HERE" ;;
  10) echo "  FAIL $VAL defines \`vcc_main() {\` but carries no column-0 source guard -- a respelled subject; sourcing it would run vcc_main in this shell"; echo "trunk-audit-classes: FAIL (1 assertion(s))"; exit 1 ;;
  *) echo "  FAIL $VAL carries the column-0 source guard but no \`vcc_main() {\` line -- a respelled subject this fixture cannot drive"; echo "trunk-audit-classes: FAIL (1 assertion(s))"; exit 1 ;;
esac
. "$HERE/../lib/inproc.sh" || { echo "FIXTURE BROKEN: cannot source lib/inproc.sh" >&2; exit 2; }
inproc_load "$VAL" || { echo "FIXTURE BROKEN: sourcing $VAL defined nothing" >&2; exit 2; }
declare -F vcc_main >/dev/null || { echo "FIXTURE BROKEN: sourcing $VAL defined no vcc_main" >&2; exit 2; }

G() { git -C "$1" -c user.email=f@x -c user.name=F -c commit.gpgsign=false "${@:2}"; }

# A synthetic consumer that is also a git repo: a trunk, two validators (one that passes and
# one that fails), and a genesis commit. Prints the genesis SHA.
mkrepo() { # $1 = dir, $2 = taxonomy body ("" = no taxonomy file at all), $3 = "predates" to
           #                                    ship a contract with no declaration
  local d="$1" body="$2" mode="${3:-}"
  mkdir -p "$d/.claude/skills/ai-dlc" "$d/validators" "$d/_bmad-output"
  if [ "$mode" = "predates" ]; then
    printf 'contract_version: 13\n' > "$d/.claude/skills/ai-dlc/layer-contract.yaml"
  else
    printf 'contract_version: 13\nconsumer_pr_class_file: .claude/skills/ai-dlc/pr-classes.md\n' \
      > "$d/.claude/skills/ai-dlc/layer-contract.yaml"
  fi
  [ -n "$body" ] && printf 'x\n```\n%s\n```\n' "$body" > "$d/.claude/skills/ai-dlc/pr-classes.md"
  printf '#!/bin/bash\nexit 0\n' > "$d/validators/ok.sh";  chmod +x "$d/validators/ok.sh"
  printf '#!/bin/bash\nexit 1\n' > "$d/validators/bad.sh"; chmod +x "$d/validators/bad.sh"
  # The capture arms' instrument. It accepts ONE value and rejects every other, so a
  # substitution that silently produced the wrong string -- or produced nothing and left the
  # literal `{sprint}` -- is a FAIL rather than a pass. A validator that ignored its argument
  # would make every capture assertion below vacuous.
  printf '#!/bin/bash\necho "arg=$1"\n[ "$1" = "7" ] || exit 3\nexit 0\n' > "$d/validators/wants7.sh"
  chmod +x "$d/validators/wants7.sh"
  git init -q "$d" >/dev/null 2>&1
  git -C "$d" symbolic-ref HEAD refs/heads/main
  G "$d" add -A >/dev/null 2>&1
  G "$d" commit -q -m "genesis" >/dev/null 2>&1
  git -C "$d" rev-parse HEAD
}

# The taxonomy every positive case uses. `retro` before `code` so first-match-wins is
# exercised by the retro commit, which also touches nothing else.
TAX='class: retro
paths: ^docs/retro/
validator: validators/ok.sh

class: code
paths: ^src/
validator: validators/bad.sh

class: chore
paths: ^chore/
validator: none'

# The exit code goes to a FILE, not to a variable. Every caller here is `out="$(run_audit …)"`,
# and an assignment inside `$( )` dies with the subshell — the trap this repo has recorded and
# which cost this fixture its first run.
RCF="$WORK/rc"
# In process: the callers' locals (decl_case's o r, stdin_case's d g c o r) are unset here, repeatedly, so none of
# them reaches the subject; inproc_run unsets each visible name once, which would uncover an outer binding.
run_audit() { # $1 = repo, rest = args. Prints output; writes the exit code to $RCF.
  ( cd "$1" || exit 2; shift
    for _i in 1 2 3; do unset d g c o r 2>/dev/null; done; unset _i
    inproc_run "$VAL" vcc_main --audit-trunk "$@" 2>&1; echo "$?" > "$RCF" )
}
arc() { cat "$RCF"; }

# ---- 1: a compliant commit is CLEAN, and the watermark advances to it
R1="$WORK/r1"; g1="$(mkrepo "$R1" "$TAX")"
mkdir -p "$R1/docs/retro"; printf 'retro\n' > "$R1/docs/retro/sprint-1.md"
G "$R1" add -A >/dev/null 2>&1; G "$R1" commit -q -m "retro sprint 1" >/dev/null 2>&1
c1="$(git -C "$R1" rev-parse HEAD)"
out1="$(run_audit "$R1" "$g1")"; rc1="$(arc)"

grep -qE "^  CLEAN   ${c1} \(retro\)" <<<"$out1" \
  && ok "a commit whose class validator passes against its own tree is CLEAN" \
  || bad "a compliant commit was not reported CLEAN — the mode fails a trunk for complying"
[ "$rc1" -eq 0 ] && ok "a clean range exits 0" || bad "a clean range exited $rc1, not 0"
grep -qE 'findings=0' <<<"$out1" && ok "the census reports zero findings on a clean range" \
                                 || bad "the census did not report findings=0 on a clean range"
[ "$(cat "$R1/_bmad-output/.audit-watermark" 2>/dev/null)" = "$c1" ] \
  && ok "the watermark advances to the last clean commit" \
  || bad "the watermark did not advance to the clean commit — the next run re-audits it"

# ---- 2: a commit whose class validator FAILS against its own tree is a finding.
# This is the bypass itself: the verdict is re-derived from the committed tree.
R2="$WORK/r2"; g2="$(mkrepo "$R2" "$TAX")"
mkdir -p "$R2/src"; printf 'code\n' > "$R2/src/app.txt"
G "$R2" add -A >/dev/null 2>&1; G "$R2" commit -q -m "bypassed merge" >/dev/null 2>&1
c2="$(git -C "$R2" rev-parse HEAD)"
out2="$(run_audit "$R2" "$g2")"; rc2="$(arc)"

grep -qE "^  FAIL    ${c2} \(code\)" <<<"$out2" \
  && ok "a commit whose class validator fails against its own tree is a finding" \
  || bad "a bypassed merge was NOT reported — the whole mechanism is silent on its subject"
grep -q "validators/bad.sh" <<<"$out2" \
  && ok "the finding names the validator that rejected the tree" \
  || bad "the finding does not name the validator — an un-actionable report"
[ "$rc2" -eq 1 ] && ok "a finding exits 1" || bad "a finding exited $rc2, not 1"
[ "$(cat "$R2/_bmad-output/.audit-watermark" 2>/dev/null)" = "$g2" ] \
  && ok "the watermark does NOT advance past a finding" \
  || bad "the watermark advanced past a finding — the next run would skip it"

# ---- 3: a commit matching no declared class is a finding, not a skip. FAIL CLOSED.
R3="$WORK/r3"; g3="$(mkrepo "$R3" "$TAX")"
mkdir -p "$R3/weird"; printf 'x\n' > "$R3/weird/thing.txt"
G "$R3" add -A >/dev/null 2>&1; G "$R3" commit -q -m "unclassifiable" >/dev/null 2>&1
c3="$(git -C "$R3" rev-parse HEAD)"
out3="$(run_audit "$R3" "$g3")"; rc3="$(arc)"

grep -qE "^  FAIL    ${c3} \(UNRESOLVED\)" <<<"$out3" \
  && ok "a commit matching no declared class is a finding (fail closed)" \
  || bad "an unresolvable commit was skipped — the audit passes exactly what it hunts"
[ "$rc3" -eq 1 ] && ok "an unresolved class exits 1" || bad "an unresolved class exited $rc3, not 1"

# ---- 4: a declared validator that is ABSENT from the audited tree is a finding.
# "It was not there" and "it passed" are the same silence otherwise.
R4="$WORK/r4"; g4="$(mkrepo "$R4" 'class: retro
paths: ^docs/retro/
validator: validators/missing.sh')"
mkdir -p "$R4/docs/retro"; printf 'retro\n' > "$R4/docs/retro/sprint-1.md"
G "$R4" add -A >/dev/null 2>&1; G "$R4" commit -q -m "retro" >/dev/null 2>&1
out4="$(run_audit "$R4" "$g4")"; rc4="$(arc)"

grep -q "does not exist in this commit's own tree" <<<"$out4" \
  && ok "a declared validator absent from the audited tree is a finding" \
  || bad "an absent validator passed silently — an un-run check reads as a clean one"
[ "$rc4" -eq 1 ] && ok "an absent validator exits 1" || bad "an absent validator exited $rc4, not 1"

# ---- 5: an UNDECLARED taxonomy prints a worklist and exits 0.
# The stop condition, written in advance: adoption is not compliance's precondition.
R5="$WORK/r5"; g5="$(mkrepo "$R5" "")"
mkdir -p "$R5/src"; printf 'x\n' > "$R5/src/app.txt"
G "$R5" add -A >/dev/null 2>&1; G "$R5" commit -q -m "anything" >/dev/null 2>&1
out5="$(run_audit "$R5" "$g5")"; rc5="$(arc)"

grep -q 'AUDIT-TRUNK: WORKLIST' <<<"$out5" \
  && ok "an unscaffolded taxonomy prints a worklist line" \
  || bad "an unscaffolded taxonomy printed no worklist — silence and adoption look alike"
[ "$rc5" -eq 0 ] && ok "an unscaffolded taxonomy exits 0 (it does not wedge the trunk)" \
                 || bad "an unscaffolded taxonomy exited $rc5 — a consumer is wedged by a mechanism it has not adopted"

# ---- 6: the literal `none` is a complete answer, and still not a clean trunk
R6="$WORK/r6"; g6="$(mkrepo "$R6" "none")"
mkdir -p "$R6/src"; printf 'x\n' > "$R6/src/app.txt"
G "$R6" add -A >/dev/null 2>&1; G "$R6" commit -q -m "anything" >/dev/null 2>&1
out6="$(run_audit "$R6" "$g6")"; rc6="$(arc)"
grep -q "declares 'none'" <<<"$out6" && [ "$rc6" -eq 0 ] \
  && ok "the literal 'none' is reported as declared-empty and exits 0" \
  || bad "an explicit 'none' was not honoured (rc=$rc6) — an empty taxonomy is a legal answer"

# ---- 7: a MALFORMED taxonomy is not an empty one
R7="$WORK/r7"; g7="$(mkrepo "$R7" 'class: retro
paths: ^docs/retro/')"
mkdir -p "$R7/docs/retro"; printf 'x\n' > "$R7/docs/retro/sprint-1.md"
G "$R7" add -A >/dev/null 2>&1; G "$R7" commit -q -m "retro" >/dev/null 2>&1
out7="$(run_audit "$R7" "$g7")"; rc7="$(arc)"
grep -q "declares no 'validator:'" <<<"$out7" && [ "$rc7" -eq 1 ] \
  && ok "a class with no validator is a declaration error and nothing is audited" \
  || bad "a class owing nothing by omission was accepted (rc=$rc7)"
grep -q 'NOTHING was audited' <<<"$out7" \
  && ok "the malformed run says nothing was audited rather than reporting a count" \
  || bad "a malformed taxonomy did not say that nothing was audited"

# ---- 8: an empty range carries its control in the same run
out8="$(run_audit "$R1" "$(git -C "$R1" rev-parse HEAD)")"; rc8="$(arc)"
grep -q 'audited=0' <<<"$out8" && [ "$rc8" -eq 0 ] \
  && ok "an empty range exits 0 and says so" || bad "an empty range misreported (rc=$rc8)"
grep -q 'control: the trunk holds' <<<"$out8" \
  && ok "the empty-range zero carries a same-run control that the enumeration ran" \
  || bad "an empty range reported a bare zero — indistinguishable from an enumeration that died"

# ---- 9: a contract that PREDATES the declaration is silent. v0.228.0's defect.
R9="$WORK/r9"; g9="$(mkrepo "$R9" "$TAX" predates)"
mkdir -p "$R9/src"; printf 'x\n' > "$R9/src/app.txt"
G "$R9" add -A >/dev/null 2>&1; G "$R9" commit -q -m "anything" >/dev/null 2>&1
out9="$(run_audit "$R9" "$g9")"; rc9="$(arc)"
grep -q 'predates the trunk audit' <<<"$out9" && [ "$rc9" -eq 0 ] \
  && ok "a contract predating the declaration is silent and exits 0" \
  || bad "a contract with no declaration was reported (rc=$rc9) — v0.228.0's defect exactly"

# ---- 10: the join to the file core actually ships. Every case above seeds its own
# synthetic contract, so without this the whole fixture passes on a distribution that
# never shipped the declaration at all.
grep -q '^consumer_pr_class_file:' "$REAL_LC" \
  && ok "core's shipped layer-contract.yaml declares consumer_pr_class_file:" \
  || bad "core's own contract does not declare consumer_pr_class_file: — every case above tested a synthetic one"

# ============================================================================
# CAPTURES — v0.236.0. A duty keyed to something the COMMIT determines.
#
# The gap this closes was measured on the reference consumer rather than imagined: three of
# its four retro-class obligations take the commit's sprint number as an argument, so the
# declared taxonomy re-ran 2 where the incumbent script re-ran 4, and that is the single
# reason 364 lines of consumer machinery could not retire.
#
# EVERY ARM BELOW EXISTS BECAUSE THE OTHERS ARE SATISFIABLE WITHOUT IT. The pair 11a/11b is
# the load-bearing one: a run that goes green proves the command ran, not that the right
# VALUE reached its argv, and the only way to tell those apart is a validator that rejects
# every value but one and a second commit that hands it a different one.
# ============================================================================

CAPTAX='class: sprintdoc
paths: ^docs/s/
capture: sprint ^docs/s/sprint-([0-9]+)\.md$
validator: validators/wants7.sh {sprint}

class: rest
paths: .
validator: none'

RC="$WORK/rc-cap"; gc="$(mkrepo "$RC" "$CAPTAX")"
mkdir -p "$RC/docs/s"; printf 'a\n' > "$RC/docs/s/sprint-7.md"
G "$RC" add -A >/dev/null 2>&1; G "$RC" commit -q -m "sprint 7" >/dev/null 2>&1
cc7="$(git -C "$RC" rev-parse HEAD)"
outc7="$(run_audit "$RC" "$gc")"; rcc7="$(arc)"

# ---- 11a: the captured value REACHES the validator's argv, and it is the right one
grep -qE "^  CLEAN   ${cc7} \(sprintdoc\)" <<<"$outc7" && [ "$rcc7" -eq 0 ] \
  && ok "a capture resolves and its value reaches the validator's argv (rc=0)" \
  || bad "the capture did not reach the validator (rc=$rcc7) — a {name} that is not substituted is a validator run against a literal"

# ---- 11b: the SAME taxonomy on a commit whose capture yields a different value FAILS.
# Without this, 11a passes just as well against a substitution that always produced `7`.
printf 'b\n' > "$RC/docs/s/sprint-9.md"
G "$RC" add -A >/dev/null 2>&1; G "$RC" commit -q -m "sprint 9" >/dev/null 2>&1
cc9="$(git -C "$RC" rev-parse HEAD)"
outc9="$(run_audit "$RC" "$cc7")"; rcc9="$(arc)"
grep -q 'arg=9' <<<"$outc9" && [ "$rcc9" -eq 1 ] \
  && ok "a different commit yields a DIFFERENT captured value, so 11a is not a constant" \
  || bad "the capture did not vary with the commit (rc=$rcc9) — 11a proved nothing"

# ---- 12: a capture that matches NO changed path is a finding, not a skip.
# Same fail-closed reasoning as an unresolved class: the class's stated obligation could not
# be built, and saying nothing about that reads exactly like having run it.
RCN="$WORK/rc-none"; gcn="$(mkrepo "$RCN" "$CAPTAX")"
mkdir -p "$RCN/docs/s"; printf 'x\n' > "$RCN/docs/s/notes.md"
G "$RCN" add -A >/dev/null 2>&1; G "$RCN" commit -q -m "a docs/s file with no sprint number" >/dev/null 2>&1
outcn="$(run_audit "$RCN" "$gcn")"; rccn="$(arc)"
grep -q "capture 'sprint' matched none of this commit's" <<<"$outcn" && [ "$rccn" -eq 1 ] \
  && ok "a capture matching no changed path is a finding (rc=1), not a silent skip" \
  || bad "an unresolvable capture was skipped (rc=$rccn) — the obligation went un-run and un-reported"

# ---- 13: two changed paths yielding DIFFERENT values is a finding. Core will not guess.
RCA="$WORK/rc-amb"; gca="$(mkrepo "$RCA" "$CAPTAX")"
mkdir -p "$RCA/docs/s"; printf 'a\n' > "$RCA/docs/s/sprint-7.md"; printf 'b\n' > "$RCA/docs/s/sprint-8.md"
G "$RCA" add -A >/dev/null 2>&1; G "$RCA" commit -q -m "two sprints in one commit" >/dev/null 2>&1
outca="$(run_audit "$RCA" "$gca")"; rcca="$(arc)"
grep -q "matched 2 DIFFERENT values in one commit" <<<"$outca" && [ "$rcca" -eq 1 ] \
  && ok "an ambiguous capture is a finding rather than a guess" \
  || bad "an ambiguous capture did not report (rc=$rcca) — a validator ran against one of two candidate values"
grep -qE '\(7 8|8 7\)' <<<"$outca" \
  && ok "the ambiguity finding names BOTH values it found" \
  || bad "the ambiguity finding does not name the values — un-actionable"

# ---- 14: a value outside [A-Za-z0-9._-] is a finding. The command is EVALUATED, so the
# capture is an injection surface the repository's own paths feed, and `(.*)` is legal to write.
RCU="$WORK/rc-unsafe"; gcu="$(mkrepo "$RCU" 'class: sprintdoc
paths: ^docs/s/
capture: v ^docs/s/(.*)$
validator: validators/wants7.sh {v}

class: rest
paths: .
validator: none')"
mkdir -p "$RCU/docs/s/nested"; printf 'x\n' > "$RCU/docs/s/nested/deep.md"
G "$RCU" add -A >/dev/null 2>&1; G "$RCU" commit -q -m "a nested path" >/dev/null 2>&1
outcu="$(run_audit "$RCU" "$gcu")"; rccu="$(arc)"
grep -q 'which is outside \[A-Za-z0-9._-\]' <<<"$outcu" && [ "$rccu" -eq 1 ] \
  && ok "a capture value carrying characters outside the safe set is a finding" \
  || bad "an unsafe capture value was substituted into an evaluated command (rc=$rccu)"

# ---- 15: captures are PER CLASS and do not leak. A commit resolving to a class with no
# capture runs its validator exactly as before — which is the release's no-behaviour-change
# promise, asserted rather than assumed.
RCP="$WORK/rc-perclass"; gcp="$(mkrepo "$RCP" 'class: sprintdoc
paths: ^docs/s/
capture: sprint ^docs/s/sprint-([0-9]+)\.md$
validator: validators/wants7.sh {sprint}

class: plain
paths: ^src/
validator: validators/ok.sh')"
mkdir -p "$RCP/src"; printf 'x\n' > "$RCP/src/app.txt"
G "$RCP" add -A >/dev/null 2>&1; G "$RCP" commit -q -m "code only" >/dev/null 2>&1
ccp="$(git -C "$RCP" rev-parse HEAD)"
outcp="$(run_audit "$RCP" "$gcp")"; rccp="$(arc)"
grep -qE "^  CLEAN   ${ccp} \(plain\)" <<<"$outcp" && [ "$rccp" -eq 0 ] \
  && ok "a class with no capture is unaffected by a sibling class that declares one" \
  || bad "a capture in one class changed another class's behaviour (rc=$rccp)"

# ---- 16-22: the DECLARATION-time arms. Every one of these stops the run before a single
# commit is audited, and that is what makes an unsubstituted {name} unable to reach a
# validator's argv — which is why there is no runtime arm for it. One repo, rewritten
# taxonomy per case: the taxonomy is read from the working tree, so re-seeding a git repo
# per case would buy nothing but wall clock.
RCD="$WORK/rc-decl"; gcd="$(mkrepo "$RCD" "$CAPTAX")"
mkdir -p "$RCD/docs/s"; printf 'a\n' > "$RCD/docs/s/sprint-7.md"
G "$RCD" add -A >/dev/null 2>&1; G "$RCD" commit -q -m "sprint 7" >/dev/null 2>&1

decl_case() { # $1 = label, $2 = taxonomy body, $3 = ERE the error must match
  printf 'x\n```\n%s\n```\n' "$2" > "$RCD/.claude/skills/ai-dlc/pr-classes.md"
  local o r
  o="$(run_audit "$RCD" "$gcd")"; r="$(arc)"
  if grep -qE "$3" <<<"$o" && [ "$r" -eq 1 ] && grep -q 'NOTHING was audited' <<<"$o"; then
    ok "$1"
  else
    bad "$1 — rc=$r, output did not match '$3'"
  fi
}

decl_case "a {name} with no capture behind it is a declaration error, and nothing is audited" \
  'class: c
paths: .
capture: sprint ^docs/s/sprint-([0-9]+)\.md$
validator: validators/wants7.sh {sprint} {nosuch}' \
  "naming \{nosuch\} and declares no 'capture: nosuch'"

decl_case "a capture no validator reads is a declaration error" \
  'class: c
paths: .
capture: sprint ^docs/s/sprint-([0-9]+)\.md$
validator: validators/ok.sh' \
  "declares 'capture: sprint' and no validator: names \{sprint\}"

decl_case "an UNANCHORED capture regex is refused, because a capture extracts rather than tests" \
  'class: c
paths: .
capture: sprint docs/s/sprint-([0-9]+)
validator: validators/wants7.sh {sprint}' \
  'is not anchored'

decl_case "a capture regex with NO capturing group is refused" \
  'class: c
paths: .
capture: sprint ^docs/s/sprint-[0-9]+\.md$
validator: validators/wants7.sh {sprint}' \
  'contains no capturing group'

decl_case "a capture name declared twice in one class is refused" \
  'class: c
paths: .
capture: sprint ^docs/s/sprint-([0-9]+)\.md$
capture: sprint ^docs/s/x-([0-9]+)\.md$
validator: validators/wants7.sh {sprint}' \
  "declares capture 'sprint' twice"

decl_case "a capture name outside [A-Za-z][A-Za-z0-9_]* is refused" \
  'class: c
paths: .
capture: 9sprint ^docs/s/sprint-([0-9]+)\.md$
validator: validators/wants7.sh {9sprint}' \
  "declares capture name '9sprint'"

decl_case "a capture: appearing before any class: is refused" \
  'capture: sprint ^docs/s/sprint-([0-9]+)\.md$
class: c
paths: .
validator: validators/wants7.sh {sprint}' \
  "'capture:' appears before any 'class:' line"

# ---- 23: the name-with-no-regex case, AND the truncation defect it exposed.
# The parser's whitespace strip used to be a sed bracket class written with a backslash-t
# escape, which POSIX bracket expressions do not have: the class was SPACE, BACKSLASH and
# the letter, so every declaration line ending in one of those three lost its last
# character. `capture: sprint` arrived as a five-letter name nobody wrote. This asserts the
# value the parser SAW, which is the only reading that tells the fix from the defect.
# I71 in validate-enforcement-map.sh forbids the construct repo-wide; this proves the
# behaviour. The construct is DESCRIBED and not reproduced here, deliberately — writing it
# out would make this comment a live subject of the invariant it is explaining.
printf 'x\n```\n%s\n```\n' 'class: c
paths: .
capture: sprint
validator: validators/wants7.sh {sprint}' > "$RCD/.claude/skills/ai-dlc/pr-classes.md"
outct="$(run_audit "$RCD" "$gcd")"; rcct="$(arc)"
grep -q "has 'capture: sprint', which is a name with no regex" <<<"$outct" && [ "$rcct" -eq 1 ] \
  && ok "a capture with a name and no regex is refused, and the name is reported UNTRUNCATED" \
  || bad "the name-only capture was misreported (rc=$rcct) — a trailing 't' eaten by a sed bracket class reads as a different declaration"

# ---- 24: a validator that READS STDIN must not swallow the validators declared after it.
# The class's validators run in a `while read … done < valres` loop, so a validator's inherited
# stdin is THE REST OF THE CLASS'S VALIDATOR LIST. Measured before the fix: `cat >/dev/null`
# then `false` reported CLEAN, findings=0, the watermark advancing -- `false` never ran. The
# fix closes stdin on the eval INSIDE the `$( … )`; a retired mutation battery proved that the
# redirect removed, moved outside the substitution, or spelled `<&0` all turn these arms red.
#
# TWO SPELLINGS, because a fix keyed on one reader is not a fix for the class: `cat` drains
# the stream, `read -r _x` takes exactly one line -- which is here the whole remaining list.
# The assertion names `'false'`, so a fix that failed the READER instead of running the
# validator after it would still be red: a stdin reader is a legal validator here.
stdin_case() { # $1 = label, $2 = first validator, $3 = second validator, $4 = want FAIL|CLEAN
  local d="$WORK/rs-$1" g c o r
  g="$(mkrepo "$d" "class: docs
paths: ^docs/
validator: $2
validator: $3")"
  mkdir -p "$d/docs"; printf 'x\n' > "$d/docs/a.md"
  G "$d" add -A >/dev/null 2>&1; G "$d" commit -q -m "docs change" >/dev/null 2>&1
  c="$(git -C "$d" rev-parse HEAD)"
  o="$(run_audit "$d" "$g")"; r="$(arc)"
  if [ "$4" = FAIL ]; then
    if grep -qE "^  FAIL    ${c} \(docs\):.* 'false' exits non-zero" <<<"$o" && [ "$r" -eq 1 ]; then
      ok "a stdin-reading validator ($2) does not swallow the 'false' declared after it"
    else
      bad "a stdin-reading validator ($2) swallowed the validator after it (rc=$r) -- 'false' never ran and the class read clean"
    fi
  else
    if grep -qE "^  CLEAN   ${c} \(docs\)" <<<"$o" && [ "$r" -eq 0 ] \
       && [ "$(cat "$d/_bmad-output/.audit-watermark" 2>/dev/null)" = "$c" ]; then
      ok "near-miss: '$2' then '$3' is CLEAN and the watermark advances"
    else
      bad "near-miss: '$2' then '$3' was not CLEAN (rc=$r) -- the stdin fix fails a compliant class"
    fi
  fi
}
stdin_case cat      'cat >/dev/null'   'false' FAIL
stdin_case read     'read -r _x; true' 'false' FAIL
# NEAR-MISSES. `true` then `true` is the two-validator class with nothing reading stdin; the
# reader followed by a passing validator is the one an over-broad fix -- refusing any validator
# that reads stdin -- would turn red, which is why the reader itself is seeded green here.
stdin_case nm-true  'true'             'true'  CLEAN
stdin_case nm-cat   'cat >/dev/null'   'true'  CLEAN

# ---- the cli cells (cells.decl): the validator run as a PROGRAM once per distinct CLI outcome --------------------
# The outcomes this fixture reaches are exit 0 (a clean range) and exit 1 (a finding). One `FXCELL=<id> bash "$VAL"`
# start per outcome, each compared with the in-process call on the same world: --audit-trunk advances the watermark,
# so each side runs on a fresh copy of one template at the SAME path. stdout, stderr and exit separately, byte for
# byte; each cell also asserts its own outcome, and the two cells must differ.
EQ="$WORK/eq"; mkdir -p "$EQ"
EQW="$WORK/eqw"; mkdir -p "$EQW"
cp -R "$R1" "$EQW/clean.t"; git -C "$EQW/clean.t" rev-parse HEAD~1 > "$EQW/clean.t/_bmad-output/.audit-watermark"
EQG_CLEAN="$g1"
cp -R "$R2" "$EQW/finding.t"; printf '%s\n' "$g2" > "$EQW/finding.t/_bmad-output/.audit-watermark"
EQG_FINDING="$g2"
eqv() { # <cell-id> <template> <genesis> -> $EQ/<id>.{ip,cl}.{out,err,rc}
  local id="$1" t="$2" gen="$3" p="$EQW/$1"
  rm -rf "$p"; cp -R "$t" "$p"
  ( cd "$p" || exit 2; set -- "$gen"; for _i in 1 2 3; do unset id t gen p 2>/dev/null; done; unset _i
    inproc_run "$VAL" vcc_main --audit-trunk "$1" ) > "$EQ/$id.ip.out" 2> "$EQ/$id.ip.err"; echo "$?" > "$EQ/$id.ip.rc"
  rm -rf "$p"; cp -R "$t" "$p"
  ( cd "$p" || exit 2; FXCELL="$id" bash "$VAL" --audit-trunk "$gen" ) > "$EQ/$id.cl.out" 2> "$EQ/$id.cl.err"; echo "$?" > "$EQ/$id.cl.rc"
  cmp -s "$EQ/$id.ip.out" "$EQ/$id.cl.out" && cmp -s "$EQ/$id.ip.err" "$EQ/$id.cl.err" && cmp -s "$EQ/$id.ip.rc" "$EQ/$id.cl.rc"
}
eq_twin() { printf 'in-process rc=%s out=[%s] err=[%s] / program rc=%s out=[%s] err=[%s]' "$(cat "$EQ/$1.ip.rc")" \
  "$(cat "$EQ/$1.ip.out")" "$(cat "$EQ/$1.ip.err")" "$(cat "$EQ/$1.cl.rc")" "$(cat "$EQ/$1.cl.out")" "$(cat "$EQ/$1.cl.err")"; }
if eqv cli-clean "$EQW/clean.t" "$EQG_CLEAN" && [ "$(cat "$EQ/cli-clean.cl.rc")" = 0 ] \
   && grep -qE "^  CLEAN   ${c1} \(retro\)" "$EQ/cli-clean.cl.out" && grep -q 'findings=0' "$EQ/cli-clean.cl.out"; then
  ok "cli-clean: the program audits a clean range exactly as the in-process call does (stdout, stderr, exit 0)"
else bad "cli-clean: the program and the in-process call differ, or the outcome is not exit 0 with a CLEAN row ($(eq_twin cli-clean))"; fi
if eqv cli-finding "$EQW/finding.t" "$EQG_FINDING" && [ "$(cat "$EQ/cli-finding.cl.rc")" = 1 ] \
   && grep -qE "^  FAIL    ${c2} \(code\)" "$EQ/cli-finding.cl.out"; then
  ok "cli-finding: the program reports the finding exactly as the in-process call does (stdout, stderr, exit 1)"
else bad "cli-finding: the program and the in-process call differ, or the outcome is not exit 1 with a FAIL row ($(eq_twin cli-finding))"; fi
if ! cmp -s "$EQ/cli-clean.cl.out" "$EQ/cli-finding.cl.out" && ! cmp -s "$EQ/cli-clean.cl.rc" "$EQ/cli-finding.cl.rc"; then
  ok "cli cells discriminate: the clean and the finding world give different stdout and exit"
else bad "cli cells do not discriminate: cli-clean and cli-finding gave the same stdout or exit"; fi

# ---- the run itself is a control
[ -n "$out1" ] && ok "the audit produced output (the run is not a silent death)" \
               || bad "the audit printed NOTHING — every assertion above is vacuous"
report_end trunk-audit-classes
