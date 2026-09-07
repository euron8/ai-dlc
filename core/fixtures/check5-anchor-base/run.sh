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

echo
# Liveness: a harness that silently stopped running assertions reads exactly like a clean pass.
if [ "$asserted" -ne 14 ]; then
  echo "check5-anchor-base: FIXTURE ERROR — ran $asserted assertions, expected 14" >&2
  exit 2
fi
if [ "$fails" -eq 0 ]; then
  echo "check5-anchor-base: PASS ($asserted assertions)"
  exit 0
fi
echo "check5-anchor-base: FAIL ($fails of $asserted assertion(s))"
exit 1
