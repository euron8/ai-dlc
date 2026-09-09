#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# check5-anchor-base — the prior-sprint audit anchor: its ONE resolver, and both its callers.
#
# ORIGINALLY: prove mandatory-rules Check 5 FIRES at retro time by diffing from the prior-sprint
# audit-anchor SHA, not main..HEAD (which is empty on a retro branch cut from main after the
# sprint merged — the CANNOT-FIRE bug), and that removing the anchor base reintroduces the SKIP.
#
# THE DEFECT THAT EXISTS TO CATCH. Check 5 diffed main..HEAD. At retro time the sprint's web/**
# changes are ancestors of main, so main..HEAD is empty and Check 5 SKIPped every sprint — a check
# that cannot fire reads exactly like one that passed. The fix resolves the base from
# audit-anchors.md's prior-sprint SHA so [anchor..HEAD] is the sprint's real change set. The
# scenario below has the web change ALREADY merged to main (main..HEAD empty), so only the anchor
# base can see it.
#
# NOW ALSO: the resolution itself. gate-validation Check 18 stated the same predicate in prose —
# "resolve <prior_sprint_sha> from the most recent prior sprint entry (current sprint number minus
# one); if absent the gate FAILS CLOSED" — and shipped no program, so an agent performed it by
# reading a paragraph at every sprint-review gate while an awk in validate-mandatory-rules.sh did
# the same job in a copy no gate could reach. `validate-audit-anchors.sh --prior-sprint-sha` is now
# the single home. Assertions 4+ drive it directly; assertions 1-3 are unchanged and now pass
# THROUGH it, which is what makes the two callers one behaviour rather than two.
#
# EVERY ARM IS ASSERTED ON ITS OWN WORDING. The four failure causes — no entries, no entry for the
# prior sprint, a PENDING placeholder, a sha that does not resolve — all exit 1 and would all match
# a grep for "FAIL". A mutant that collapses two of them into one is exactly what this catches.
#
# AND SINCE close_reason: a sprint can now close without a retro-PR merge, anchored at the commit it
# stopped at. Two questions follow, and the second is the one worth the arms: does the resolver
# resolve through such a record and SAY it is not a merge base, and did giving a closed sprint an
# anchor give any sprint a way past one. The C token answers the first; X and PC answer the second
# by asserting the gate stays shut AND no sha reaches stdout — the thing the caller consumes.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"

# Both layouts, never by hop count: core/scripts + core/schemas upstream, scripts/ai-dlc +
# .claude/schemas in a consumer.
if   [ -n "$ROOT" ] && [ -f "$ROOT/core/scripts/validate-mandatory-rules.sh" ]; then
  VMR="$ROOT/core/scripts/validate-mandatory-rules.sh"
  VAA="$ROOT/core/scripts/validate-audit-anchors.sh"
  SCHEMA="$ROOT/core/schemas/audit-anchors.json"
elif [ -n "$ROOT" ] && [ -f "$ROOT/scripts/ai-dlc/validate-mandatory-rules.sh" ]; then
  VMR="$ROOT/scripts/ai-dlc/validate-mandatory-rules.sh"
  VAA="$ROOT/scripts/ai-dlc/validate-audit-anchors.sh"
  SCHEMA="$ROOT/.claude/schemas/audit-anchors.json"
else
  echo "FIXTURE ERROR: validate-mandatory-rules.sh not found in either layout" >&2
  exit 2
fi
[ -f "$VAA" ]    || { echo "FIXTURE ERROR: validate-audit-anchors.sh not found beside it" >&2; exit 2; }
[ -f "$SCHEMA" ] || { echo "FIXTURE ERROR: audit-anchors.json not found at $SCHEMA" >&2; exit 2; }
command -v git >/dev/null 2>&1 || { echo "FIXTURE ERROR: git not on PATH" >&2; exit 2; }
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

WORK="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd)"
trap 'rm -rf "$WORK"' EXIT

fails=0
asserted=0
ok()  { printf '  ok    %s\n' "$1"; asserted=$((asserted+1)); }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); asserted=$((asserted+1)); }

# Isolated toolchain dir: the real validators + no-op sibling stubs so Checks 1/2 do not
# interfere with the Check 5 line we read. Check 5 reads audit-anchors/gate-log/git from CWD.
# `schemas/` sits beside `bin/` because validate-audit-anchors.sh resolves its schema at
# $SCRIPT_DIR/../schemas first — the same relative shape both shipped layouts have, and the
# same one $WORK/mut/../schemas gives the mutant copies below.
mkdir -p "$WORK/bin" "$WORK/schemas" "$WORK/mut"
cp "$VMR" "$WORK/bin/validate-mandatory-rules.sh"
cp "$VAA" "$WORK/bin/validate-audit-anchors.sh"
cp "$SCHEMA" "$WORK/schemas/audit-anchors.json"
printf '#!/bin/sh\nexit 0\n' > "$WORK/bin/validate-retro-evidence.sh"
printf '#!/bin/sh\nexit 0\n' > "$WORK/bin/validate-cycle-commits.sh"
chmod +x "$WORK/bin/validate-retro-evidence.sh" "$WORK/bin/validate-cycle-commits.sh"

cd "$WORK" || exit 2
git -c init.defaultBranch=main init -q . 2>/dev/null || { echo "FIXTURE ERROR: git init failed" >&2; exit 2; }
git config user.email f@example.com; git config user.name Fixture; git config commit.gpgsign false
mkdir -p _bmad-output/implementation-artifacts

echo "seed" > seed.txt; git add -A && git commit -q -m "prior sprint boundary"; git branch -M main
PRIOR_SHA="$(git rev-parse HEAD)"

# The sprint's web change, merged to main (so main..HEAD will be empty on the retro branch).
mkdir -p web/src; echo "console.log('ui')" > web/src/app.js
git add -A && git commit -q -m "Sprint 900 web change"

# audit-anchors.md: prior sprint 899 -> the boundary SHA (mandatory-rules reads PRIOR_SPRINT = 899).
printf -- '- sprint: 899\n  sha: %s\n- sprint: 900\n  sha: <PENDING-S900-RETRO>\n' "$PRIOR_SHA" \
  > _bmad-output/audit-anchors.md

# Retro branch == main tip: main..HEAD is empty; PRIOR_SHA..HEAD carries the web change.
git checkout -q -b ai-dlc/retro/sprint-900

GATE_LOG="_bmad-output/implementation-artifacts/gate-log.md"
write_gatelog() {  # <notes-cell>
  printf '## Gate Log: Sprint 900\n\n| Gate | Result | Notes |\n|------|--------|-------|\n| Deploy Status Report | PASS | %s |\n' "$1" > "$GATE_LOG"
}
check5_line() { ( cd "$WORK" && bash "$1" 900 2>/dev/null ) | grep -i 'CHECK 5:' | head -1; }

echo "check5-anchor-base"

# --- 1. web changed (anchor base) + NO visual evidence -> Check 5 FIRES and FAILs ---
write_gatelog "deploy completed"
L="$(check5_line "$WORK/bin/validate-mandatory-rules.sh")"
if grep -qi 'CHECK 5: FAIL' <<<"$L"; then
  ok "fires and FAILs on a web/** change with no visual evidence (main..HEAD would have SKIPped)"
else
  bad "Check 5 did not fire+FAIL — got: ${L:-<no CHECK 5 line>}"
fi

# --- 2. web changed + USER-CONFIRMED -> Check 5 PASS --------------------------
write_gatelog "USER-CONFIRMED visual verification captured"
L="$(check5_line "$WORK/bin/validate-mandatory-rules.sh")"
if grep -qi 'CHECK 5: PASS' <<<"$L"; then
  ok "PASSes with USER-CONFIRMED evidence in the sprint gate-log section"
else
  bad "Check 5 did not PASS with evidence — got: ${L:-<no CHECK 5 line>}"
fi

# --- 3. MUTATION: revert the base to main..HEAD -> Check 5 SKIPs (cannot fire) ---
MUTANT="$WORK/mbin/validate-mandatory-rules.sh"
mkdir -p "$WORK/mbin"
cp "$WORK/bin/validate-retro-evidence.sh" "$WORK/bin/validate-cycle-commits.sh" \
   "$WORK/bin/validate-audit-anchors.sh" "$WORK/mbin/"
sed 's/${CHECK5_BASE}/main/g' "$WORK/bin/validate-mandatory-rules.sh" > "$MUTANT" || exit 2
if cmp -s "$WORK/bin/validate-mandatory-rules.sh" "$MUTANT"; then
  echo "FIXTURE ERROR: mutation matched nothing — the CHECK5_BASE reference was renamed" >&2
  exit 2
fi
write_gatelog "deploy completed"   # no evidence: under the anchor base this FAILs
L="$(check5_line "$MUTANT")"
if grep -qi 'CHECK 5: SKIP' <<<"$L"; then
  ok "MUTATION: reverting the base to main..HEAD makes Check 5 SKIP (the anchor base is what fires it)"
else
  bad "MUTATION: Check 5 did not SKIP on main..HEAD — got: ${L:-<no CHECK 5 line>}"
fi

# --- 3b. the caller DELEGATES: with the resolver removed, Check 5 says so by name ---
# The awk this replaced lived inside validate-mandatory-rules.sh, so a "delegation" that quietly
# kept a local copy would pass assertions 1-3 unchanged. This is the arm that distinguishes them.
NODELEG="$WORK/nodeleg"
mkdir -p "$NODELEG"
cp "$WORK/bin/validate-mandatory-rules.sh" "$WORK/bin/validate-retro-evidence.sh" \
   "$WORK/bin/validate-cycle-commits.sh" "$NODELEG/"
write_gatelog "deploy completed"
L="$(check5_line "$NODELEG/validate-mandatory-rules.sh")"
if grep -qi 'CHECK 5: SKIP' <<<"$L" && grep -qi 'validate-audit-anchors.sh not found' <<<"$L"; then
  ok "Check 5 resolves the base THROUGH validate-audit-anchors.sh — removing it SKIPs by name, no local fallback"
else
  bad "Check 5 still resolved a base with validate-audit-anchors.sh absent — the awk was not retired. Got: ${L:-<no CHECK 5 line>}"
fi

# ============================================================================
# The resolver itself. Five arms, four causes plus the usage/absence separation.
#
# EACH ARM GETS ITS OWN SCENARIO FILE, chosen so that the minus-one is NOT the thing that
# distinguishes it. Reusing one file made the off-by-one mutant fail three arms at once, which is
# entanglement: two failures mean one of the assertions is vacuous.
# ============================================================================
printf -- '- sprint: 899\n  sha: %s\n- sprint: 900\n  sha: <PENDING-S900-RETRO>\n' "$PRIOR_SHA" > "$WORK/good.md"
printf -- '- sprint: 900\n  sha: PENDING\n- sprint: 901\n  sha: <PENDING-S901-RETRO>\n'          > "$WORK/pending.md"
printf -- '- sprint: 500\n  sha: %s\n' "$PRIOR_SHA"                                             > "$WORK/noentry.md"
printf -- '- sprint: 899\n  sha: deadbeefdeadbeefdeadbeefdeadbeefdeadbeef\n- sprint: 900\n  sha: deadbeefdeadbeefdeadbeefdeadbeefdeadbeef\n' > "$WORK/unresolved.md"

# --- CLOSE RECORDS ------------------------------------------------------------------------
# A sprint reset or abandoned after consuming its number reaches no retro and no merge SHA, so it
# used to leave a HOLE and the next sprint's Check 18 failed closed on it. `close_reason` gives that
# sprint a real anchor — the commit it stopped at. The resolver has to resolve through one AND say
# so, because an operator reading an audit window cannot otherwise tell a merge base from a
# stopped-at base.
#
# BOTH close files carry the SAME reason and the SAME sha at sprint N-1 and N, deliberately: the
# minus-one is arm 4's R token to own, and a close arm that also moved under the off-by-one mutant
# would make one of the two vacuous. Two files with DIFFERENT reasons, because a NOTE that named a
# hardcoded word would satisfy a single one.
printf -- '- sprint: 949\n  sha: %s\n  close_reason: reset\n- sprint: 950\n  sha: %s\n  close_reason: reset\n' \
  "$PRIOR_SHA" "$PRIOR_SHA" > "$WORK/close-reset.md"
printf -- '- sprint: 959\n  sha: %s\n  close_reason: abandoned\n- sprint: 960\n  sha: %s\n  close_reason: abandoned\n' \
  "$PRIOR_SHA" "$PRIOR_SHA" > "$WORK/close-abandoned.md"

# --- THE ANTI-EXEMPTION FILES -------------------------------------------------------------
# The whole risk in this change is that a way to anchor a closed sprint becomes a way PAST the
# anchor. Both files are shaped so that the only difference from a resolvable one is the thing that
# must NOT be waived, and both are asserted on stdout being EMPTY as well as a non-zero exit: the
# gate consumes the printed sha, so "it complained and printed one anyway" is the failure that
# matters. Asserting emptiness rather than the message is also what keeps these two out of the
# no-entry and placeholder arms' territory — those own the WORDING; these own the fail-closed.
printf -- '- sprint: 800\n  sha: %s\n  close_reason: reset\n- sprint: 801\n  sha: %s\n  close_reason: abandoned\n' \
  "$PRIOR_SHA" "$PRIOR_SHA" > "$WORK/close-noentry.md"
printf -- '- sprint: 979\n  sha: <PENDING-S979-RETRO>\n  close_reason: reset\n- sprint: 980\n  sha: <PENDING-S980-RETRO>\n  close_reason: reset\n' \
  > "$WORK/close-pending.md"

# battery <script> -> five space-separated tokens, one per arm. A mutant must move EXACTLY one.
battery() {
  local S="$1" out rc t
  t=""

  out="$( ( cd "$WORK" && bash "$S" --prior-sprint-sha good.md 900 ) 2>/dev/null )"; rc=$?
  if [ "$rc" -eq 0 ] && [ "$out" = "$PRIOR_SHA" ]; then t="R:sha"; else t="R:no"; fi

  out="$( ( cd "$WORK" && bash "$S" --prior-sprint-sha noentry.md 902 ) 2>&1 >/dev/null )"; rc=$?
  if [ "$rc" -ne 0 ] && grep -q 'no entry for sprint' <<<"$out"; then t="$t N:named"; else t="$t N:no"; fi

  out="$( ( cd "$WORK" && bash "$S" --prior-sprint-sha pending.md 901 ) 2>&1 >/dev/null )"; rc=$?
  if [ "$rc" -ne 0 ] && grep -q 'placeholder' <<<"$out"; then t="$t P:named"; else t="$t P:no"; fi

  out="$( ( cd "$WORK" && bash "$S" --prior-sprint-sha unresolved.md 900 ) 2>&1 >/dev/null )"; rc=$?
  if [ "$rc" -ne 0 ] && grep -q 'does not resolve to a commit' <<<"$out"; then t="$t U:named"; else t="$t U:no"; fi

  ( cd "$WORK" && bash "$S" --prior-sprint-sha good.md not-a-number ) >/dev/null 2>&1; rc=$?
  if [ "$rc" -eq 2 ]; then t="$t A:usage"; else t="$t A:$rc"; fi

  # C — resolves THROUGH a close record and NAMES the reason on stderr. Both reasons, from two
  # files, so the NOTE is proven to be read from the entry rather than printed from one spelling.
  local c1 c2
  out="$( ( cd "$WORK" && bash "$S" --prior-sprint-sha close-reset.md 950 ) 2>"$WORK/cr.err" )"; rc=$?
  c1=no; if [ "$rc" -eq 0 ] && [ "$out" = "$PRIOR_SHA" ] && grep -q 'close_reason: reset' "$WORK/cr.err"; then c1=yes; fi
  out="$( ( cd "$WORK" && bash "$S" --prior-sprint-sha close-abandoned.md 960 ) 2>"$WORK/ca.err" )"; rc=$?
  c2=no; if [ "$rc" -eq 0 ] && [ "$out" = "$PRIOR_SHA" ] && grep -q 'close_reason: abandoned' "$WORK/ca.err"; then c2=yes; fi
  if [ "$c1$c2" = "yesyes" ]; then t="$t C:noted"; else t="$t C:$c1$c2"; fi

  # X — THE ANTI-EXEMPTION ARM. Close records are present in the file; the PRIOR sprint still has
  # none. The gate must stay closed and no sha may reach stdout. A fix that let a nearby close
  # record stand in for a missing one would pass every other arm here.
  out="$( ( cd "$WORK" && bash "$S" --prior-sprint-sha close-noentry.md 803 ) 2>/dev/null )"; rc=$?
  if [ "$rc" -ne 0 ] && [ -z "$out" ]; then t="$t X:closed"; else t="$t X:open"; fi

  # PC — the same question for the OTHER half of the fail-closed rule: an entry that carries a
  # close_reason and a PENDING sha is still a hole. `close_reason` says why the anchor is not a
  # merge SHA; it never says the anchor may be absent.
  out="$( ( cd "$WORK" && bash "$S" --prior-sprint-sha close-pending.md 980 ) 2>/dev/null )"; rc=$?
  if [ "$rc" -ne 0 ] && [ -z "$out" ]; then t="$t PC:closed"; else t="$t PC:open"; fi

  printf '%s' "$t"
}

EXPECTED="R:sha N:named P:named U:named A:usage C:noted X:closed PC:closed"

# --- 4. the shipping resolver answers all five arms --------------------------
GOT="$(battery "$WORK/bin/validate-audit-anchors.sh")"
if [ "$GOT" = "$EXPECTED" ]; then
  ok "--prior-sprint-sha: resolves sprint N-1 (through a close record too, naming its reason), names each of no-entry / placeholder / unresolvable separately, keeps a wrong argument at exit 2, and stays CLOSED with no sha on stdout when the prior sprint has no entry or only a PENDING one"
else
  bad "--prior-sprint-sha battery: expected [$EXPECTED], got [$GOT]"
fi

# --- 5. it reports what it scanned -------------------------------------------
# A resolution that found its answer in an empty file would otherwise print what a real one prints.
CNT="$( ( cd "$WORK" && bash "$WORK/bin/validate-audit-anchors.sh" --prior-sprint-sha good.md 900 ) 2>&1 >/dev/null )"
if grep -q 'scanned 2 entries' <<<"$CNT" && grep -q 'sprint 899' <<<"$CNT"; then
  ok "--prior-sprint-sha reports its counts: how many entries it scanned and which sprint it matched"
else
  bad "--prior-sprint-sha resolved without saying what it looked at — got: ${CNT:-<nothing on stderr>}"
fi

# ============================================================================
# MUTANTS. Each is a COPY guarded by `cmp -s`, all in one directory beside an UNMUTATED CONTROL
# copied from the same place — a lone copy that cannot find its schema emits nothing, and "no
# output" otherwise scores as a kill for every mutant at once.
# ============================================================================
CTL="$WORK/mut/control.sh"
cp "$WORK/bin/validate-audit-anchors.sh" "$CTL"
CGOT="$(battery "$CTL")"
if [ "$CGOT" = "$EXPECTED" ]; then
  ok "CONTROL: an unmutated copy in the mutant directory answers identically (the harness itself is not what fails below)"
else
  echo "FIXTURE ERROR: the unmutated control does not reproduce the battery — expected [$EXPECTED], got [$CGOT]." >&2
  echo "  Every mutant verdict below would be meaningless. Most likely the copy cannot resolve ../schemas/." >&2
  exit 2
fi

# mutate <tag> <sed-program> <expected-battery> <what-it-proves>
mutate() {
  local tag="$1" prog="$2" want="$3" claim="$4"
  local M="$WORK/mut/$tag.sh" got
  sed "$prog" "$WORK/bin/validate-audit-anchors.sh" > "$M" || { bad "MUTANT $tag: sed failed"; return; }
  if cmp -s "$WORK/bin/validate-audit-anchors.sh" "$M"; then
    echo "FIXTURE ERROR: mutant '$tag' matched nothing — the line it targets was renamed." >&2
    exit 2
  fi
  got="$(battery "$M")"
  if [ "$got" = "$want" ]; then
    ok "MUTANT $tag: $claim"
  else
    bad "MUTANT $tag ($claim): expected battery [$want], got [$got]"
  fi
}

# The minus-one. Without it the resolver returns the CURRENT sprint's anchor, which on a live file
# is the PENDING one the retro has not backfilled yet — so it fails where it should have resolved.
mutate offbyone \
  's/prior   = current - 1/prior   = current - 0/' \
  "R:no N:named P:named U:named A:usage C:noted X:closed PC:closed" \
  "dropping the minus-one stops sprint N-1 resolving, and moves nothing else"

# The placeholder arm. Removing it does not make a PENDING file pass — git still refuses the value
# — it makes the resolver report the WRONG CAUSE, which is the failure a grep for FAIL cannot see.
mutate placeholder \
  's/if "PENDING" in raw.upper():/if False and "PENDING" in raw.upper():/' \
  "R:sha N:named P:no U:named A:usage C:noted X:closed PC:closed" \
  "without its own arm a PENDING anchor is reported as an unresolvable sha, not as an unmerged retro"

# The git resolution. Without it an anchor that names no commit in this repository passes.
mutate resolve \
  's/if rc != 0 or not resolved:/if False and (rc != 0 or not resolved):/' \
  "R:sha N:named P:named U:no A:usage C:noted X:closed PC:closed" \
  "without the rev-parse verdict a sha that resolves to nothing is accepted as the audit base"

# The no-entry arm — the one Check 18's own text calls out: silent skip on a missing anchor is
# forbidden, so the absence has to be a named finding rather than whatever falls out downstream.
mutate noentry \
  's/^    if not matches:/    if False:/' \
  "R:sha N:no P:named U:named A:usage C:noted X:closed PC:closed" \
  "without its own arm a missing prior-sprint entry stops being a named finding"

# The usage/absence separation. A fumbled argument must not arrive as exit 1, which Check 18 reads
# as "the anchor is missing" and fails the gate on.
mutate usagesplit \
  's/if \[ "\$MODE" = "prior-sprint-sha" \]; then/if [ "$MODE" = "prior-sprint-sha-DISABLED" ]; then/' \
  "R:sha N:named P:named U:named A:1 C:noted X:closed PC:closed" \
  "without the argument check a non-numeric sprint exits 1, which a caller reads as a missing anchor"

# THE EXEMPTION THAT WAS AVAILABLE AND NOT TAKEN. This one is not a revert of a layer — it is the
# wrong fix, written out: let a close record anywhere in the file stand in for the prior sprint's
# missing entry. It is the shape the filing invites ("the sprint was closed, so the chain is fine")
# and it passes every other arm here, including the no-entry arm, because a file with no close
# records at all is unaffected. X is the only thing that sees it.
mutate exemption \
  's/^    matches = \[e for e in entries if e.get("sprint", "") == str(prior)\]$/    matches = [e for e in entries if e.get("sprint", "") == str(prior)] or [e for e in entries if e.get("close_reason")]/' \
  "R:sha N:named P:named U:named A:usage C:noted X:open PC:closed" \
  "a close record standing in for a MISSING prior-sprint entry opens the gate, and only the anti-exemption arm sees it"

# PC has no mutant of its own, and that is a finding rather than a gap: no single-layer removal
# opens it. The placeholder arm closes it first, and with that arm disabled the rev-parse verdict
# closes it anyway — the two layers already carry the `placeholder` and `resolve` mutants above, and
# PC asserts they compose on an entry that carries a close_reason.

# The close-record NOTE. Removing it does not stop a close record RESOLVING — the sha is real, so
# the gate still passes on it — it makes the resolution look identical to one anchored on a retro-PR
# merge. That is the whole difference the field exists to carry, and it is invisible to an exit
# code: an operator reading the audit window would be told a merge base where none exists.
mutate closenote \
  's/^    if cr:$/    if False:/' \
  "R:sha N:named P:named U:named A:usage C:nono X:closed PC:closed" \
  "without the NOTE a sprint closed WITHOUT a retro-PR merge resolves silently, reading exactly like a merge anchor"

# ============================================================================
# THE TEST-ONLY CARVE-OUT. Check 5 fires on ANY web/** member of the diff, so a sprint whose
# entire web/** change is one test file — no source, no rendering — FAILed for want of visual
# evidence of a rendering that did not change. The consumer that filed it had exactly one changed
# file, a `.test.jsx` beside its component.
#
# SIX WORLDS, and the three that matter are the ones a WRONG fix passes:
#
#   H  a helper under a tests dir with NO suffix. A directory-keyed rule acquits it; it is source,
#      and Check 5 must still fire. This is the seed that kills the directory rule, and the
#      consumer corpus has exactly one such file.
#   E  an e2e `.spec.` under `web/tests/e2e/`. THE ACQUITTAL PROBE, and it is asserted as a SKIP:
#      the suffix rule DOES acquit an all-e2e diff. That is stated as a decision, not hidden —
#      what a directory rule would additionally acquit is every source file that happens to live
#      under such a directory, which is strictly worse. See the report below.
#   B  twenty-one test files and ONE source file, sorted so the source falls past position 20.
#      The emptiness test the carve-out was grafted onto carried a `| head -20`, which answers
#      the "is it empty" question correctly and the "is EVERY member a test" question WRONGLY.
#
# M is the ALL-not-ANY arm and it is the one this whole change turns on: one test file beside one
# source file must still FIRE. N is the pre-existing no-web/** skip, asserted on its own wording so
# a mutant that collapses the two skip reasons into one is visible.
# ============================================================================
c5_world() {  # <branch-suffix> <file>...  — a tree whose PRIOR_SHA..HEAD is exactly these files
  local tag="$1"; shift
  ( cd "$WORK" && git checkout -q -B "c5w-$tag" "$PRIOR_SHA" ) || return 1
  local f
  for f in "$@"; do
    ( cd "$WORK" && mkdir -p "$(dirname "$f")" && printf 'x\n' > "$f" )
  done
  # `git add -- "$@"`, NEVER `git add -A`. Measured while building this: an `-A` swept the
  # UNTRACKED audit-anchors.md and gate-log.md into the world's commit, and the next world's
  # `checkout PRIOR_SHA` then DELETED both — every later world reported
  # "cannot resolve diff base", which reads as the carve-out having broken the anchor resolution
  # rather than as the harness eating its own inputs.
  if [ "$#" -gt 0 ]; then
    ( cd "$WORK" && git add -- "$@" && git commit -q -m "world $tag" ) || return 1
  fi
  # Recreated per world rather than assumed: the directory is empty in PRIOR_SHA's tree, so git
  # does not carry it, and a world that inherited a previous world's gate-log asserts nothing.
  mkdir -p "$WORK/_bmad-output/implementation-artifacts"
  printf -- '- sprint: 899\n  sha: %s\n- sprint: 900\n  sha: <PENDING-S900-RETRO>\n' "$PRIOR_SHA" \
    > "$WORK/_bmad-output/audit-anchors.md"
  write_gatelog "deploy completed"   # no visual evidence: a firing Check 5 FAILs
}

# battery5 <script> -> six tokens. A mutant must move a set no other mutant moves.
battery5() {
  local S="$1" L t=""

  c5_world testonly web/src/components/PositionRangeGauge.test.jsx
  L="$(check5_line "$S")"
  case "$L" in
    *"SKIP (test-only"*) t="T:skip-named" ;;
    *SKIP*)              t="T:skip-unnamed" ;;
    *FAIL*)              t="T:FAIL" ;;
    *)                   t="T:none" ;;
  esac

  c5_world mixed web/src/components/PositionRangeGauge.test.jsx web/src/components/PositionRangeGauge.jsx
  L="$(check5_line "$S")"
  case "$L" in *FAIL*) t="$t M:fires" ;; *SKIP*) t="$t M:SKIPPED" ;; *) t="$t M:none" ;; esac

  c5_world e2e web/tests/e2e/navigation.spec.js
  L="$(check5_line "$S")"
  case "$L" in
    *"SKIP (test-only"*) t="$t E:skip" ;;
    *SKIP*)              t="$t E:skip-other" ;;
    *FAIL*)              t="$t E:fires" ;;
    *)                   t="$t E:none" ;;
  esac

  c5_world noweb docs/notes.md
  L="$(check5_line "$S")"
  case "$L" in
    *"no web/** file changes"*) t="$t N:noweb" ;;
    *SKIP*)                     t="$t N:skip-other" ;;
    *)                          t="$t N:none" ;;
  esac

  c5_world helper web/src/tests/contract/helpers.js
  L="$(check5_line "$S")"
  case "$L" in *FAIL*) t="$t H:fires" ;; *SKIP*) t="$t H:SKIPPED" ;; *) t="$t H:none" ;; esac

  # P — a web file at the TOP LEVEL of web/, under neither src/ nor tests/. Every other world's
  # files sit under one of those two, so the bare `web/**` glob in the pathspec is asserted by
  # nothing without this: narrowing the pathspec to two globs returns an EMPTY diff, and Check 5
  # then reports "no web/** file changes" — a SKIP that reads exactly like a sprint with no web
  # work. Asserted on the FAIL, because the narrowed form's answer is a skip.
  c5_world toplevel web/index.html
  L="$(check5_line "$S")"
  case "$L" in *FAIL*) t="$t P:fires" ;; *SKIP*) t="$t P:SKIPPED" ;; *) t="$t P:none" ;; esac

  # R — a source file RENAMED to a test-suffixed name. git detects renames by default and
  # enumerates the pair as ONE line, the test path, so a diff that DELETED a rendered component
  # reads as test-only. `--no-renames` is what makes both paths appear and the check fire.
  #
  # THE SOURCE FILE MUST EXIST AT THE DIFF BASE, which is what makes this world's anchor its own.
  # Seeded and renamed inside one range, the base never held the source, the range is a bare ADD
  # of the test path, and the world asserts nothing — it would be green under both spellings. So
  # the anchor is REWRITTEN to the commit that added the source, and the rename is the only thing
  # in the range.
  c5_world renamesrc web/src/components/Gauge.jsx
  local rbase
  rbase="$( cd "$WORK" && git rev-parse HEAD )"
  ( cd "$WORK" && git mv web/src/components/Gauge.jsx web/src/components/Gauge.test.jsx \
      && git commit -q -m "rename a source file to a test name" ) >/dev/null 2>&1
  printf -- '- sprint: 899\n  sha: %s\n- sprint: 900\n  sha: <PENDING-S900-RETRO>\n' "$rbase" \
    > "$WORK/_bmad-output/audit-anchors.md"
  L="$(check5_line "$S")"
  case "$L" in *FAIL*) t="$t R:fires" ;; *SKIP*) t="$t R:SKIPPED" ;; *) t="$t R:none" ;; esac

  # Sorted, the lone source file lands at position 22 of 22.
  c5_world big web/src/c/a1.test.jsx web/src/c/a2.test.jsx web/src/c/a3.test.jsx \
    web/src/c/a4.test.jsx web/src/c/a5.test.jsx web/src/c/a6.test.jsx web/src/c/a7.test.jsx \
    web/src/c/a8.test.jsx web/src/c/a9.test.jsx web/src/c/a10.test.jsx web/src/c/a11.test.jsx \
    web/src/c/a12.test.jsx web/src/c/a13.test.jsx web/src/c/a14.test.jsx web/src/c/a15.test.jsx \
    web/src/c/a16.test.jsx web/src/c/a17.test.jsx web/src/c/a18.test.jsx web/src/c/a19.test.jsx \
    web/src/c/a20.test.jsx web/src/c/a21.test.jsx web/src/c/zsource.jsx
  L="$(check5_line "$S")"
  case "$L" in *FAIL*) t="$t B:fires" ;; *SKIP*) t="$t B:SKIPPED" ;; *) t="$t B:none" ;; esac

  printf '%s' "$t"
}

EXPECTED5="T:skip-named M:fires E:skip N:noweb H:fires P:fires R:fires B:fires"

# --- 6. the shipping validator answers every world -----------------------------
GOT5="$(battery5 "$WORK/bin/validate-mandatory-rules.sh")"
if [ "$GOT5" = "$EXPECTED5" ]; then
  ok "test-only carve-out: an all-test web/** diff SKIPs and SAYS test-only, a test file BESIDE a source file still FIREs, a no-suffix helper under a tests dir still FIREs, the pre-existing no-web/** skip keeps its own wording, and a 22-file diff whose only source sits past position 20 still FIREs"
else
  bad "test-only battery: expected [$EXPECTED5], got [$GOT5]"
fi

# --- 7. THE ACQUITTED SUFFIX SET IS PINNED, not merely its two members exercised ---
# A BATTERY OF WORLDS CANNOT SEE A WIDENING IT DOES NOT SPELL. Every world above names a
# `.test.` or a `.spec.` file, so adding a THIRD member to the acquittal list — `.stories.`, say,
# which is a rendering artifact and exactly the acquittal this change argues against for e2e
# specs — moves no world and passes every arm. The gap is in the SEED and cannot be closed by
# another world: a fourth suffix has the same problem, and so would a fifth.
#
# So the SET is read off the line that EMITS it and compared to the whole declared value.
# Extracted from `$NF !~ /\.(...)\./` on the CHECK5_WEB_NONTEST assignment — the emission site,
# not a comment that mentions the members and not a grep for either name, both of which a
# widening leaves satisfied. The control is the extraction itself: a sed that matched nothing
# yields an empty string, which would compare equal to nothing and pass silently, so an empty
# extraction is a FIXTURE ERROR rather than a finding.
c5_suffix_set() {  # <script> -> the alternation inside the acquittal regex, verbatim
  sed -n 's/^CHECK5_WEB_NONTEST=.*\$NF !~ \/\\\.(\([^)]*\))\\\.\/.*/\1/p' "$1" | head -1
}
SUFFIX_SET="$(c5_suffix_set "$WORK/bin/validate-mandatory-rules.sh")"
if [ -z "$SUFFIX_SET" ]; then
  echo "FIXTURE ERROR: could not extract the acquitted suffix set from the CHECK5_WEB_NONTEST assignment — the emitting line was reshaped, so the set-lock arm below would compare two empty strings and pass." >&2
  exit 2
fi
# The control the extraction needs: the same sed against a line that is NOT the emission site
# must yield nothing, or the extractor is matching on something other than what it claims.
SUFFIX_CTL="$(printf '%s\n' 'CHECK5_WEB_N="$(printf ... )"' | sed -n 's/^CHECK5_WEB_NONTEST=.*\$NF !~ \/\\\.(\([^)]*\))\\\.\/.*/\1/p')"
if [ "$SUFFIX_SET" = "test|spec" ] && [ -z "$SUFFIX_CTL" ]; then
  ok "the acquitted suffix SET is exactly [test|spec] at the emission site (control: the same extraction against a non-emitting line yields nothing) — a THIRD suffix cannot be added without failing here, which no battery of worlds can see"
else
  bad "acquitted suffix set is [$SUFFIX_SET], expected [test|spec] — a member was added or removed. If this widening is intended, the change belongs in a release that argues for it, and this arm is where it is argued. (extraction control returned [$SUFFIX_CTL], expected empty)"
fi

# --- 8. CONTROL: an unmutated copy in the mutant directory answers identically ---
C5CTL="$WORK/mut5-control/validate-mandatory-rules.sh"
mkdir -p "$WORK/mut5-control"
cp "$WORK/bin/validate-mandatory-rules.sh" "$WORK/bin/validate-audit-anchors.sh" \
   "$WORK/bin/validate-retro-evidence.sh" "$WORK/bin/validate-cycle-commits.sh" "$WORK/mut5-control/"
C5GOT="$(battery5 "$C5CTL")"
if [ "$C5GOT" = "$EXPECTED5" ]; then
  ok "CONTROL: an unmutated copy beside the mutants answers every world (a mutant's silence below is the mutation, not a copy that could not find its siblings)"
else
  echo "FIXTURE ERROR: the unmutated Check 5 control does not reproduce the battery — expected [$EXPECTED5], got [$C5GOT]." >&2
  exit 2
fi

# mutate5 <tag> <sed-program> <expected-battery> <what-it-proves>
mutate5() {
  local tag="$1" prog="$2" want="$3" claim="$4"
  local D="$WORK/mut5-$tag" got
  mkdir -p "$D"
  cp "$WORK/bin/validate-audit-anchors.sh" "$WORK/bin/validate-retro-evidence.sh" \
     "$WORK/bin/validate-cycle-commits.sh" "$D/"
  sed "$prog" "$WORK/bin/validate-mandatory-rules.sh" > "$D/validate-mandatory-rules.sh" \
    || { bad "MUTANT $tag: sed DID NOT APPLY"; return; }
  if cmp -s "$WORK/bin/validate-mandatory-rules.sh" "$D/validate-mandatory-rules.sh"; then
    echo "FIXTURE ERROR: mutant '$tag' matched nothing — the line it targets was renamed." >&2
    exit 2
  fi
  got="$(battery5 "$D/validate-mandatory-rules.sh")"
  if [ "$got" = "$want" ]; then
    ok "MUTANT $tag: $claim"
  elif [ "$got" = "$EXPECTED5" ]; then
    bad "MUTANT $tag SURVIVED: $claim — every world unchanged, so nothing here can catch it"
  else
    bad "MUTANT $tag ($claim): expected battery [$want], got [$got]"
  fi
}

# WRONG FIX 1, keyed on the containing DIRECTORY as WELL as the suffix — "a test file is one that
# carries the suffix OR lives under a tests dir". This is the shape to build, not a pure directory
# rule: a pure one fails the FILED case (the consumer's `.test.jsx` sits under no tests dir), so it
# would never have been proposed. The union fixes the filing AND acquits the helper, which is
# exactly how a wrong fix survives review — and H is the only world that separates them.
mutate5 dirkey \
  "s@-F/ 'NF && \$NF !~ /@-F/ 'NF \&\& \$0 !~ /(^|\\\\/)tests?\\\\// \&\& \$NF !~ /@" \
  "T:skip-named M:fires E:skip N:noweb H:SKIPPED P:fires R:fires B:fires" \
  "widening the rule to acquit anything under a tests dir lets a no-suffix HELPER — source, and the consumer has exactly one — pass as a test file, and no other world can see it"

# WRONG FIX 2, ANY instead of ALL: skip as soon as one changed file is a test file. Both halves
# are flipped, because either alone is not the wrong fix — it is the pair.
mutate5 anyfix \
  's@\$NF !~ /\\.(test|spec)\\./@$NF ~ /\\.(test|spec)\\./@; s@elif \[ -z "\$CHECK5_WEB_NONTEST" \]@elif [ -n "$CHECK5_WEB_NONTEST" ]@' \
  "T:skip-named M:SKIPPED E:skip N:noweb H:fires P:fires R:SKIPPED B:SKIPPED" \
  "skipping when ANY changed file is a test acquits the mixed test+source diff AND the renamed-source diff — M owns the finding, and R moving is the same defect reached by a second road rather than a second one"

# The truncation the carve-out was grafted onto. It answers "is this list empty" correctly and
# "is EVERY member a test" wrongly, and only the 22-file world can see the difference.
mutate5 truncate \
  's@2>/dev/null)"$@2>/dev/null | head -20)"@' \
  "T:skip-named M:fires E:skip N:noweb H:fires P:fires R:fires B:SKIPPED" \
  "restoring the 20-line truncation on the enumeration acquits a diff whose only source file sorts past position 20, and moves no other world"

# The PATHSPEC. Narrowing it to the two `**`-suffixed globs is the plausible tidy-up — they look
# like they subsume the bare one, and they do not reach `web/index.html`. It does not error: the
# diff comes back EMPTY and Check 5 reports "no web/** file changes", a SKIP that reads exactly
# like a sprint which touched no web file at all.
mutate5 pathspec \
  "s@-- 'web/\*\*' 'web/src/\*\*' 'web/tests/\*\*'@-- 'web/src/**' 'web/tests/**'@" \
  "T:skip-named M:fires E:skip N:noweb H:fires P:SKIPPED R:fires B:fires" \
  "dropping the bare web/** glob makes a TOP-LEVEL web file invisible — it SKIPs as 'no web/** file changes' — and only the toplevel world can see it"

# RENAME DETECTION. Removing --no-renames restores git's default, under which a source file
# renamed to a test name enumerates as ONE line (the test path) and the deletion of the rendered
# component is laundered into a test-only diff.
mutate5 renames \
  's@--name-only --no-renames@--name-only@' \
  "T:skip-named M:fires E:skip N:noweb H:fires P:fires R:SKIPPED B:fires" \
  "without --no-renames a source file renamed to a test-suffixed name enumerates as one test path, and a diff that DELETED a rendered component is acquitted as test-only"

# THE SUFFIX WIDENING, scored differently from every mutant above BECAUSE THE BATTERY CANNOT SEE
# IT. `.stories.` is a rendering artifact, and adding it to the acquittal moves NO world — every
# world spells a `.test.` or a `.spec.`, so a battery of worlds is structurally blind to a third
# member. This asserts both halves: the battery is unchanged, AND the set-lock arm reads the
# widened set. That pair is the whole claim assertion 7 exists to carry.
C5STORIES="$WORK/mut5-stories"
mkdir -p "$C5STORIES"
cp "$WORK/bin/validate-audit-anchors.sh" "$WORK/bin/validate-retro-evidence.sh" \
   "$WORK/bin/validate-cycle-commits.sh" "$C5STORIES/"
sed 's@(test|spec)@(test|spec|stories)@' "$WORK/bin/validate-mandatory-rules.sh" \
  > "$C5STORIES/validate-mandatory-rules.sh" \
  || { echo "FIXTURE ERROR: mutant 'stories' sed DID NOT APPLY" >&2; exit 2; }
if cmp -s "$WORK/bin/validate-mandatory-rules.sh" "$C5STORIES/validate-mandatory-rules.sh"; then
  echo "FIXTURE ERROR: mutant 'stories' matched nothing — the acquittal regex was reshaped." >&2
  exit 2
fi
C5SGOT="$(battery5 "$C5STORIES/validate-mandatory-rules.sh")"
C5SSET="$(c5_suffix_set "$C5STORIES/validate-mandatory-rules.sh")"
if [ "$C5SSET" != "test|spec|stories" ]; then
  bad "MUTANT stories: the widened set extracted as [$C5SSET], expected [test|spec|stories] — the set-lock arm is not reading what it claims to read"
elif [ "$C5SGOT" != "$EXPECTED5" ]; then
  bad "MUTANT stories: expected the world battery to be UNCHANGED at [$EXPECTED5] — that blindness is the finding — but got [$C5SGOT]"
else
  ok "MUTANT stories: widening the acquittal to a THIRD suffix leaves every world unchanged, so no battery of worlds can catch it, and the set-lock arm is what reads [test|spec|stories] and refuses"
fi

echo
# Liveness: a harness that silently stopped running assertions reads exactly like a clean pass.
if [ "$asserted" -ne 23 ]; then
  echo "check5-anchor-base: FIXTURE ERROR — ran $asserted assertions, expected 23" >&2
  exit 2
fi
if [ "$fails" -eq 0 ]; then
  echo "check5-anchor-base: PASS ($asserted assertions)"
  exit 0
fi
echo "check5-anchor-base: FAIL ($fails of $asserted assertion(s))"
exit 1
