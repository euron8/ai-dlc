#!/usr/bin/env bash
# mandatory-rules-skip-accounting — a SKIPPED check is not a PASSED check, and the summary
# line has to be able to tell the reader which it got.
#
# THE DEFECT THIS EXISTS TO CATCH. validate-mandatory-rules.sh has six checks and three of
# them (2, 4, 5) carry legitimate SKIP branches: a consumer on the per-artifact-changelog
# model ships no validation-cycle-log.md, `validate-retro-prereq.sh` is consumer-provided, and
# a sprint whose diff base will not resolve has no determinable web/** change set. None of
# those is a failure. But no SKIP branch touched a counter, and the final line read
# `all 6 checks passed` whether six checks ran or three did, on the same exit code 0.
# Measured on the reference consumer: two checks SKIPped on EVERY sprint from 296 through
# 302, and `retro.md` accepts this validator on its exit code alone — so seven consecutive
# retros closed against a sentence asserting six verified checks when the true floor was four.
# That is this repo's recurring class: a check that cannot fire reads exactly like one that
# passed, and here it was three of them at once, saying so in the summary.
#
# THE EXIT CODE IS DELIBERATELY UNCHANGED. A skip is legitimate; blocking on one would be
# wrong, and arm F below is the assertion that the new accounting cannot swallow a real
# failure. What changes is that the two roads to exit 0 stop sharing one sentence.
#
# WHY THE ZERO-SKIP ARM IS FIRST AND HAS ITS OWN MUTANT. The first spelling of the counter was
# `printf ... | sort -u | grep -c . || echo 0`. On the zero-skip input `grep -c` prints "0" AND
# exits 1, so `||` appended a second "0"; the variable held two lines, `[ -eq 0 ]` died with
# "integer expression expected" and fell through to the skip branch on a tree where nothing had
# skipped -- and `$((6 - SKIPPED_UNIQUE))` then hit a multi-line operand, which bash treats as a
# FATAL arithmetic syntax error. The shell aborted mid-summary: no verdict line at all, and
# rc=1. `retro.md` accepts this validator on its exit code alone, so the fix for a summary that
# could not tell a skip from a pass would have HARD-FAILED every retro that skipped nothing.
# `zeroskipbug` restores that spelling, and its arm asserts the empty summary AND the rc=1 --
# a mutant asserted only on the missing wording would have scored the abort as a kill for the
# wrong reason.
#
# CHECKS 1, 2 AND 4 ARE DRIVEN THROUGH STUBBED SIBLINGS, and that is the point rather than a
# shortcut: this fixture's subject is the SUMMARY ACCOUNTING, not the siblings' logic, and the
# sibling contract those three checks publish is an exit code. Arm F flips the Check 1 stub to
# exit 1, which is the control proving the stubs are live — without it every PASS here could be
# a run in which no check ran at all.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"

# Both layouts, never by hop count (I33): core/scripts + core/schemas upstream,
# scripts/ai-dlc + .claude/schemas in a consumer.
if   [ -n "$ROOT" ] && [ -f "$ROOT/core/scripts/validate-mandatory-rules.sh" ]; then
  VMR="$ROOT/core/scripts/validate-mandatory-rules.sh"
  VAA="$ROOT/core/scripts/validate-audit-anchors.sh"
  SS="$ROOT/core/scripts/sprint-status.sh"
  ANCHOR_SCHEMA="$ROOT/core/schemas/audit-anchors.json"
  STATUS_SCHEMA="$ROOT/core/schemas/sprint-status.json"
elif [ -n "$ROOT" ] && [ -f "$ROOT/scripts/ai-dlc/validate-mandatory-rules.sh" ]; then
  VMR="$ROOT/scripts/ai-dlc/validate-mandatory-rules.sh"
  VAA="$ROOT/scripts/ai-dlc/validate-audit-anchors.sh"
  SS="$ROOT/scripts/ai-dlc/sprint-status.sh"
  ANCHOR_SCHEMA="$ROOT/.claude/schemas/audit-anchors.json"
  STATUS_SCHEMA="$ROOT/.claude/schemas/sprint-status.json"
else
  echo "FIXTURE ERROR: validate-mandatory-rules.sh not found in either layout" >&2
  exit 2
fi
for f in "$VAA" "$SS" "$ANCHOR_SCHEMA" "$STATUS_SCHEMA"; do
  [ -f "$f" ] || { echo "FIXTURE ERROR: required file not found: $f" >&2; exit 2; }
done
command -v git >/dev/null 2>&1 || { echo "FIXTURE ERROR: git not on PATH" >&2; exit 2; }
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

WORK="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd)"
trap 'rm -rf "$WORK"' EXIT

fails=0
asserted=0
ok()  { printf '  ok    %s\n' "$1"; asserted=$((asserted+1)); }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); asserted=$((asserted+1)); }

echo "mandatory-rules-skip-accounting:"

# ============================================================================
# The project tree. One git repo, shaped so that with every input present all six checks
# run and PASS, and each input can then be withdrawn to make exactly one check SKIP.
# `schemas/` sits beside every toolchain dir because validate-audit-anchors.sh resolves its
# schema at $SCRIPT_DIR/../schemas — the relative shape both shipped layouts have.
#
# sprint-status.json is there for the SAME reason and was added when Check 6 stopped restating
# the story corpus path: it now resolves `stories_dir` from the schema (I84), so a toolchain dir
# with no schema beside it makes Check 6 fail closed on an unresolvable corpus. That is the
# designed behaviour and not something to work around — the fixture simply has to build a tree
# that has the schema, which every real layout does.
# ============================================================================
mkdir -p "$WORK/schemas" "$WORK/proj/_bmad-output/implementation-artifacts"
cp "$ANCHOR_SCHEMA" "$WORK/schemas/audit-anchors.json"
cp "$STATUS_SCHEMA" "$WORK/schemas/sprint-status.json"

P="$WORK/proj"
export AI_DLC_SPRINT_STATUS_SCHEMA="$STATUS_SCHEMA"
bash "$SS" roll  --sprint 900 --intensity full --root "$P" >/dev/null 2>&1
bash "$SS" close --evidence "fixture: PR merged, deploy green, smoke pass" --root "$P" >/dev/null 2>&1
[ -f "$P/_bmad-output/implementation-artifacts/sprint-status.yaml" ] \
  || { echo "FIXTURE ERROR: sprint-status.sh did not write the envelope Check 3 reads" >&2; exit 2; }

cd "$P" || exit 2
git -c init.defaultBranch=main init -q . 2>/dev/null || { echo "FIXTURE ERROR: git init failed" >&2; exit 2; }
git config user.email f@example.com; git config user.name Fixture; git config commit.gpgsign false
git add -A && git commit -q -m "prior sprint boundary"
PRIOR_SHA="$(git rev-parse HEAD)"

# The sprint's web/** change, so Check 5 has something to verify once its base resolves.
mkdir -p web/src; echo "console.log('ui')" > web/src/app.js
# Check 6 needs a story corpus for THIS sprint. Without one it now reports SKIP rather than
# the zero-verification PASS it used to print, which would move the verified floor in every
# arm below and make this fixture's subject -- the skip accounting for checks 2, 4 and 5 --
# unreadable through a sixth skip it is not testing. Seeding a conforming story keeps the
# arms isolated AND drives Check 6's live path instead of its skip path.
mkdir -p _bmad-output/planning-artifacts/s900/stories
printf '# Story 900-1\n\n## Dev Agent Record\n\ndev (delegated) implemented this.\n' \
  > _bmad-output/planning-artifacts/s900/stories/story-1-fixture.md
git add -A && git commit -q -m "Sprint 900 web change"
git checkout -q -b ai-dlc/retro/sprint-900

printf '## Gate Log: Sprint 900\n\n| Gate | Result | Notes |\n|------|--------|-------|\n| Deploy Status Report | PASS | USER-CONFIRMED visual verification captured |\n' \
  > _bmad-output/implementation-artifacts/gate-log.md

ANCHORS="$P/_bmad-output/audit-anchors.md"
CYCLELOG="$P/_bmad-output/validation-cycle-log.md"
anchors_on()  { printf -- '- sprint: 899\n  sha: %s\n- sprint: 900\n  sha: <PENDING-S900-RETRO>\n' "$PRIOR_SHA" > "$ANCHORS"; }
anchors_off() { rm -f "$ANCHORS"; }
cyclelog_on()  { printf '# Validation Cycle Log\n\n- sprint 900: three cycles\n' > "$CYCLELOG"; }
cyclelog_off() { rm -f "$CYCLELOG"; }

# ============================================================================
# A toolchain dir per script under test: the real resolver, plus the three siblings whose
# contract is an exit code. `prereq_on/off` is the Check 4 toggle and `evidence_rc` is the
# Check 1 one, both per-dir so the battery can move them without touching another copy.
# ============================================================================
toolchain() {  # <dir> <script-to-install-as-validate-mandatory-rules.sh>
  mkdir -p "$1"
  cp "$2" "$1/validate-mandatory-rules.sh"
  cp "$VAA" "$1/validate-audit-anchors.sh"
  printf '#!/bin/sh\nexit 0\n' > "$1/validate-cycle-commits.sh"
  printf '#!/bin/sh\nexit 0\n' > "$1/validate-retro-evidence.sh"
  printf '#!/bin/sh\nexit 0\n' > "$1/validate-retro-prereq.sh"
  chmod +x "$1"/*.sh
}
prereq_on()   { printf '#!/bin/sh\nexit 0\n' > "$1/validate-retro-prereq.sh"; chmod +x "$1/validate-retro-prereq.sh"; }
prereq_off()  { rm -f "$1/validate-retro-prereq.sh"; }
evidence_rc() { printf '#!/bin/sh\nexit %s\n' "$2" > "$1/validate-retro-evidence.sh"; chmod +x "$1/validate-retro-evidence.sh"; }

# battery <toolchain-dir> -> six space-separated tokens, one per arm.
# Each arm withdraws exactly one input, so a mutant to one check's counter moves the arms
# that check skips in and nothing else.
battery() {
  local D="$1" out rc t=""
  run() { out="$( cd "$P" && bash "$D/validate-mandatory-rules.sh" 900 2>&1 )"; rc=$?; }
  summary() { grep -E 'checks (passed|verified)' <<<"$out" | head -1 | sed 's/^ *//'; }

  # A — every input present: six checks run, and the sentence says so.
  anchors_on; cyclelog_on; prereq_on "$D"; evidence_rc "$D" 0
  run
  if [ "$rc" -eq 0 ] && [ "$(summary)" = "Sprint 900: all 6 checks passed" ]; then t="A:6"; else t="A:[$(summary)]/$rc"; fi

  # B — no validation-cycle-log.md: Check 2 alone skips.
  cyclelog_off
  run
  if [ "$rc" -eq 0 ] && [ "$(summary)" = "Sprint 900: 5 of 6 checks verified; 1 SKIPPED (check 2)." ]; then t="$t B:5-2"; else t="$t B:[$(summary)]/$rc"; fi
  cyclelog_on

  # C — no validate-retro-prereq.sh sibling: Check 4 alone skips.
  prereq_off "$D"
  run
  if [ "$rc" -eq 0 ] && [ "$(summary)" = "Sprint 900: 5 of 6 checks verified; 1 SKIPPED (check 4)." ]; then t="$t C:5-4"; else t="$t C:[$(summary)]/$rc"; fi
  prereq_on "$D"

  # D — no audit-anchors.md: Check 5's diff base will not resolve, so Check 5 alone skips.
  anchors_off
  run
  if [ "$rc" -eq 0 ] && [ "$(summary)" = "Sprint 900: 5 of 6 checks verified; 1 SKIPPED (check 5)." ]; then t="$t D:5-5"; else t="$t D:[$(summary)]/$rc"; fi

  # E — the reference consumer's real shape: three inputs absent at once.
  cyclelog_off; prereq_off "$D"
  run
  if [ "$rc" -eq 0 ] && [ "$(summary)" = "Sprint 900: 3 of 6 checks verified; 3 SKIPPED (check 2 4 5)." ]; then t="$t E:3-245"; else t="$t E:[$(summary)]/$rc"; fi

  # F — a skip AND a real failure. The failure has to win, on wording and on exit code, or the
  #     accounting has bought a nicer sentence at the cost of the verdict. This is also the
  #     control that the stubs are live: flipping ONE of them changes the answer.
  evidence_rc "$D" 1
  run
  if [ "$rc" -eq 1 ] && grep -q 'VALIDATE-MANDATORY-RULES: FAIL' <<<"$out" \
     && ! grep -q 'checks verified' <<<"$out"; then t="$t F:fail"; else t="$t F:$rc"; fi

  anchors_on; cyclelog_on; prereq_on "$D"; evidence_rc "$D" 0
  printf '%s' "$t"
}

EXPECTED="A:6 B:5-2 C:5-4 D:5-5 E:3-245 F:fail"

# --- 1. the shipping validator answers every arm ------------------------------
toolchain "$WORK/bin" "$VMR"
GOT="$(battery "$WORK/bin")"
if [ "$GOT" = "$EXPECTED" ]; then
  ok "all six arms: zero skips says 'all 6 checks passed', each of checks 2/4/5 skipping alone names ITSELF and reports a floor of 5, three at once reports a floor of 3, and a real failure still FAILs at rc=1"
else
  bad "battery: expected [$EXPECTED], got [$GOT]"
fi

# --- 2. the skip verdict is its own headline, not a footnote ------------------
# `PASS` and `PASS WITH SKIPS` are different facts, and retro.md reads this script's output as
# well as its exit code. A floor buried under an unchanged headline is the defect one layer up.
cyclelog_off; anchors_on; prereq_on "$WORK/bin"; evidence_rc "$WORK/bin" 0
OUT="$( cd "$P" && bash "$WORK/bin/validate-mandatory-rules.sh" 900 2>&1 )"; RC=$?
if [ "$RC" -eq 0 ] && grep -q '^VALIDATE-MANDATORY-RULES: PASS WITH SKIPS$' <<<"$OUT" \
   && grep -q 'A skipped check is not a passed one' <<<"$OUT" \
   && grep -q 'the verified floor here is 5, not 6' <<<"$OUT"; then
  ok "a skipping run gets its own headline (PASS WITH SKIPS), names the floor, and still exits 0 — a skip is legitimate and is not blocked"
else
  bad "the skipping run did not carry the distinct headline and floor — rc=$RC, got: $OUT"
fi

cyclelog_on
OUT="$( cd "$P" && bash "$WORK/bin/validate-mandatory-rules.sh" 900 2>&1 )"; RC=$?
if [ "$RC" -eq 0 ] && grep -q '^VALIDATE-MANDATORY-RULES: PASS$' <<<"$OUT" \
   && ! grep -q 'WITH SKIPS' <<<"$OUT" && ! grep -q 'SKIPPED' <<<"$OUT"; then
  ok "and the zero-skip run does NOT carry it — the two roads to exit 0 are separable by a reader and by a grep"
else
  bad "the zero-skip run was reported as a skipping one — rc=$RC, got: $OUT"
fi

# ============================================================================
# MUTANTS. Each is a COPY in its own toolchain directory, guarded by `cmp -s`, beside an
# UNMUTATED CONTROL built the same way — a copy that cannot resolve ../schemas emits nothing,
# and "no output" otherwise scores as a kill for every mutant at once.
#
# Each mutant declares the EXACT set of arms it moves. One summary line serves several arms, so
# a per-check counter legitimately moves two of them; what would be vacuous is two mutants with
# the same moved-set, and no two below share one.
# ============================================================================
toolchain "$WORK/mut-control" "$VMR"
CTL="$(battery "$WORK/mut-control")"
if [ "$CTL" = "$EXPECTED" ]; then
  ok "CONTROL: an unmutated copy in its own toolchain dir answers every arm (so a mutant's silence below is the mutation, not the copy)"
else
  echo "FIXTURE ERROR: the unmutated control does not reproduce the battery — expected [$EXPECTED], got [$CTL]." >&2
  echo "  Every mutant verdict below would be meaningless." >&2
  exit 2
fi

mutate() {  # <tag> <sed-program> <expected-battery> <what-it-proves>
  local tag="$1" prog="$2" want="$3" claim="$4"
  local D="$WORK/mut-$tag" M="$WORK/staged-$tag.sh" got
  sed "$prog" "$VMR" > "$M" || { bad "MUTANT $tag: sed failed"; return; }
  if cmp -s "$VMR" "$M"; then
    echo "FIXTURE ERROR: mutant '$tag' matched nothing — the line it targets was renamed, so it proves nothing." >&2
    exit 2
  fi
  toolchain "$D" "$M"
  got="$(battery "$D")"
  if [ "$got" = "$want" ]; then
    ok "MUTANT $tag: $claim"
  elif [ "$got" = "$EXPECTED" ]; then
    bad "MUTANT $tag survived: $claim — every arm unchanged, so nothing here can catch it"
  else
    bad "MUTANT $tag ($claim): expected battery [$want], got [$got]"
  fi
}

# The zero-skip path, and the bug the first draft of this fix shipped. `grep -c .` prints "0"
# and exits 1 on empty input, so `|| echo 0` makes the variable two lines long; `[ -eq 0 ]`
# then errors out and the run falls into the skip branch having skipped nothing. Only arm A
# moves, because on every other arm the pipeline has lines to count and answers correctly.
mutate zeroskipbug \
  '/^SKIPPED_UNIQUE=0$/d; s@^for _skipped in .*@SKIPPED_UNIQUE="$(tr " " "\\n" <<<"$SKIPPED_LIST" | grep -c . 2>/dev/null || echo 0)"@' \
  'A:[]/1 B:5-2 C:5-4 D:5-5 E:3-245 F:fail' \
  "the original grep -c spelling aborts the zero-skip run on a fatal arithmetic error — no summary line at all, rc=1, on exactly the tree where every check ran"

# Check 2's counter. Arm B is the only arm where Check 2 skips alone, and E is the only other
# arm where it skips at all.
mutate c2counter \
  's@^  SKIPPED_CHECKS="\$SKIPPED_CHECKS 2"$@  :@' \
  'A:6 B:[Sprint 900: all 6 checks passed]/0 C:5-4 D:5-5 E:[Sprint 900: 4 of 6 checks verified; 2 SKIPPED (check 4 5).]/0 F:fail' \
  "not counting Check 2's skip returns its arm to 'all 6 checks passed' and under-reports the three-skip run as two"

mutate c4counter \
  's@^  SKIPPED_CHECKS="\$SKIPPED_CHECKS 4"$@  :@' \
  'A:6 B:5-2 C:[Sprint 900: all 6 checks passed]/0 D:5-5 E:[Sprint 900: 4 of 6 checks verified; 2 SKIPPED (check 2 5).]/0 F:fail' \
  "not counting Check 4's skip hides the exact skip the reference consumer takes on every sprint"

mutate c5counter \
  's@^  SKIPPED_CHECKS="\$SKIPPED_CHECKS 5"$@  :@' \
  'A:6 B:5-2 C:5-4 D:[Sprint 900: all 6 checks passed]/0 E:[Sprint 900: 4 of 6 checks verified; 2 SKIPPED (check 2 4).]/0 F:fail' \
  "not counting Check 5's skip returns the unresolvable-diff-base run to a full pass"

# The branch itself. With it always taking the zero-skip road, every counter above still runs
# and every skipping arm still reports the pre-fix sentence — which is what the whole release
# is about, so it must move every skipping arm and neither A nor F.
mutate zerobranch \
  's@^  if \[ "\$SKIPPED_UNIQUE" -eq 0 \]; then$@  if true; then@' \
  'A:6 B:[Sprint 900: all 6 checks passed]/0 C:[Sprint 900: all 6 checks passed]/0 D:[Sprint 900: all 6 checks passed]/0 E:[Sprint 900: all 6 checks passed]/0 F:fail' \
  "forcing the zero-skip road restores the pre-fix summary on all four skipping arms and leaves the other two alone"

# The failure road. The accounting sits inside the FAILURES==0 branch, and a mutant that lets a
# failing run reach it would buy a better sentence at the cost of the verdict.
mutate failwins \
  's@^if \[ \$FAILURES -eq 0 \]; then$@if true; then@' \
  'A:6 B:5-2 C:5-4 D:5-5 E:3-245 F:0' \
  "routing a failing run into the skip accounting turns a failed Check 1 into exit 0 — the F token falls to its raw rc, which is the whole finding"

echo
# Liveness: a harness that silently stopped running assertions reads exactly like a clean pass.
if [ "$asserted" -ne 10 ]; then
  echo "mandatory-rules-skip-accounting: FIXTURE ERROR — ran $asserted assertions, expected 10" >&2
  exit 2
fi
if [ "$fails" -eq 0 ]; then
  echo "mandatory-rules-skip-accounting: PASS ($asserted assertions)"
  exit 0
fi
echo "mandatory-rules-skip-accounting: FAIL ($fails of $asserted assertion(s))" >&2
exit 1
