#!/usr/bin/env bash
# trunk-push-bound — assert the ONE commit retro.md Step 5b licenses is actually bounded.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the check regressed, 2 = fixture broken.
#
# THE DEFECT THIS EXISTS TO CATCH. Step 5b cannot route one commit through a PR: the
# retro-PR merge SHA is not knowable until that PR has merged, so the step tells the lead
# to push it straight to the trunk. That sentence is a standing licence to write to `main`
# outside the PR route, and core shipped it defining nothing about what it licenses — no
# subject, no path bound, and no reader. On the reference consumer the licence has been
# exercised 106 times, every one of them unexamined by anything core ships.
#
# WHAT MUST HOLD, and the second half is the half that gets lost first:
#   - the licensed commit is bounded (right subject, and that path ALONE), and
#   - nothing else on the trunk is judged at all.
# A check that blocks every direct push would pass arms 1-3 and be wrong: core states no
# branch policy, and the schema that carries this bound also carries the record of what a
# linter erroring on real data on first contact costs ($fields_comment). Assertion 4 is
# that half, and it is the one a "tighten it up" edit deletes.
#
# EVERY OUTCOME IS ASSERTED ON ITS OWN WORDING. The pass, the two rejections, the
# not-my-ref case and the read-nothing case would all match a grep for "trunk-push".
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
fails=0
ok()  { printf '   ok    %s\n' "$1"; }
bad() { printf '   FAIL  %s\n' "$1" >&2; fails=$((fails + 1)); }

# Resolve the script and schema in BOTH layouts: core/scripts + core/schemas in the
# distribution, scripts/ai-dlc + .claude/schemas in a consumer. Never by hop count.
if [ -f "$HERE/../../scripts/validate-audit-anchors.sh" ]; then
  V="$HERE/../../scripts/validate-audit-anchors.sh"; S="$HERE/../../schemas/audit-anchors.json"
elif [ -f "$HERE/../../../scripts/ai-dlc/validate-audit-anchors.sh" ]; then
  V="$HERE/../../../scripts/ai-dlc/validate-audit-anchors.sh"; S="$HERE/../../../.claude/schemas/audit-anchors.json"
else
  echo "FIXTURE ERROR: cannot locate validate-audit-anchors.sh in either layout" >&2; exit 2
fi
[ -f "$S" ] || { echo "FIXTURE ERROR: cannot locate audit-anchors.json ($S)" >&2; exit 2; }

WORK="$(mktemp -d)" || exit 2
trap 'rm -rf "$WORK"' EXIT
REPO="$WORK/repo"; MUT="$WORK/mut"; mkdir -p "$REPO" "$MUT"

ANCHORS="_bmad-output/audit-anchors.md"
ZERO="0000000000000000000000000000000000000000"

# --- seed a history carrying one of every shape ------------------------------------
cd "$REPO" || exit 2
git init -q . && git config user.email f@f && git config user.name f
mkdir -p _bmad-output
echo base > README.md; git add -A; git commit -qm "base"
C_BASE="$(git rev-parse HEAD)"

echo v1 > "$ANCHORS"; git add -A
git commit -qm "chore(s299): backfill audit-anchor SHA after retro PR #828 merge"
C_OK="$(git rev-parse HEAD)"

echo v2 > "$ANCHORS"; git add -A
git commit -qm "chore: quick fix to the anchor sha"
C_BARE="$(git rev-parse HEAD)"

echo v3 > "$ANCHORS"; echo x > server.py; git add -A
git commit -qm "chore(s300): backfill audit-anchor SHA after retro PR #900 merge"
C_SMUG="$(git rev-parse HEAD)"

echo v4 > "$ANCHORS"; echo y > retro-doc.md; git add -A
git commit -qm "docs(retro): sprint 300 retrospective"
C_RETRO="$(git rev-parse HEAD)"

# push <script> <local-sha> <remote-sha> [ref] -> stdout+stderr, sets RC
push() {
  local s="$1" l="$2" r="$3" ref="${4:-refs/heads/main}"
  OUT="$(printf '%s %s %s %s\n' "$ref" "$l" "$ref" "$r" \
        | AI_DLC_AUDIT_ANCHORS_SCHEMA="$SCHEMA_USE" bash "$s" --trunk-push 2>&1)"
  RC=$?
}
SCHEMA_USE="$S"

echo "trunk-push-bound: shipped code"

# --- Assertion 1: the licensed commit lands ----------------------------------------
push "$V" "$C_OK" "$C_BASE"
if [ "$RC" -eq 0 ] && printf '%s' "$OUT" | grep -q "1 commit(s) judged"; then
  ok "the Step 5b backfill commit passes, and the run states how many commits it judged"
else
  bad "the licensed commit did not pass cleanly (rc=$RC): $OUT"
fi

# --- Assertion 2: that path, rewritten alone, under any other subject ---------------
push "$V" "$C_BARE" "$C_OK"
if [ "$RC" -ne 0 ] && printf '%s' "$OUT" | grep -q "under a subject Step 5b does not license"; then
  ok "rewriting the anchors file alone under an unlicensed subject is REJECTED"
else
  bad "an unlicensed direct-to-trunk rewrite of the anchors file was allowed (rc=$RC)"
fi

# --- Assertion 3: the licensed subject cannot carry anything else -------------------
# Clause (c): a backfill that also carries source is not a backfill. Without this, the
# subject becomes a password for pushing arbitrary code straight to the trunk.
push "$V" "$C_SMUG" "$C_BARE"
if [ "$RC" -ne 0 ] && printf '%s' "$OUT" | grep -q "claims the Step 5b backfill subject while touching"; then
  ok "a commit claiming the licensed subject while carrying other paths is REJECTED"
else
  bad "the licensed subject smuggled a source file onto the trunk (rc=$RC)"
fi

# --- Assertion 4: THE BOUND IS ON THE LICENCE, NOT ON THE TRUNK ---------------------
# An ordinary retro commit touches the anchors file AND much else. It claims no licence,
# so it is none of this check's business. Core states no branch policy; a check that
# rejected this would wedge every consumer that lands a retro by local merge.
push "$V" "$C_RETRO" "$C_SMUG"
if [ "$RC" -eq 0 ]; then
  ok "an ordinary commit touching the anchors file among others is NOT judged (the bound is on the licence, not the trunk)"
else
  bad "the check policed the trunk instead of bounding the licensed commit: $OUT"
fi

# --- Assertion 5: another ref is not the trunk --------------------------------------
push "$V" "$C_BARE" "$C_OK" "refs/heads/feat/x"
if [ "$RC" -eq 0 ] && printf '%s' "$OUT" | grep -q "does not target"; then
  ok "a push to a non-trunk ref says so in its own words (the same commit arm 2 rejects)"
else
  bad "a non-trunk push was judged as if it were the trunk (rc=$RC)"
fi

# --- Assertion 6: READING NOTHING IS NOT PASSING ------------------------------------
# This mode is fed by git on stdin. Wire it where stdin does not reach and it judges
# nothing on every push, forever, while printing what a clean push prints. That is this
# repo's named defect class, and it is not hypothetical here: the first draft read
# sys.stdin inside a `python3 - <<PY` heredoc, so it read the heredoc's leftovers --
# nothing -- in all nine cases it was tested against.
OUT="$(printf '' | AI_DLC_AUDIT_ANCHORS_SCHEMA="$S" bash "$V" --trunk-push 2>&1)"; RC=$?
if [ "$RC" -eq 0 ] && printf '%s' "$OUT" | grep -q "NO REF LINES ON STDIN" \
   && ! printf '%s' "$OUT" | grep -q "PASS"; then
  ok "reading no refs reports that it judged nothing, in wording no passing run emits"
else
  bad "a run that judged nothing was indistinguishable from a clean push: $OUT"
fi

# --- Assertion 7: creating the ref is not judging the whole history -----------------
# The absorbed consumer script takes range="$local_sha" here, which is every ancestor:
# the first push of a trunk lists the entire history and cannot land. Core will not.
push "$V" "$C_RETRO" "$ZERO"
if [ "$RC" -eq 0 ] && printf '%s' "$OUT" | grep -q "creating the remote ref"; then
  ok "creating the remote ref judges no delta (the absorbed script judged every ancestor and blocked the push)"
else
  bad "creating the trunk ref was judged against the whole history (rc=$RC): $OUT"
fi

# --- Assertion 8: the trunk name is a tunable, not a literal ------------------------
OUT="$(printf 'refs/heads/main %s refs/heads/main %s\n' "$C_BARE" "$C_OK" \
      | AI_DLC_TRUNK=develop AI_DLC_AUDIT_ANCHORS_SCHEMA="$S" bash "$V" --trunk-push 2>&1)"; RC=$?
if [ "$RC" -eq 0 ] && printf '%s' "$OUT" | grep -q "develop"; then
  ok "AI_DLC_TRUNK repoints the trunk (the same tunable validate-cycle-commits.sh reads)"
else
  bad "AI_DLC_TRUNK was ignored and 'main' was judged regardless (rc=$RC)"
fi

# ===================================================================================
# MUTANTS. Each is a COPY guarded by `cmp -s`, so a sed that matched nothing cannot
# score as a mutation. Each must fail ONLY its own assertion: two failures would mean
# the assertions are entangled and one of them proves nothing.
# ===================================================================================
echo
echo "trunk-push-bound: mutants"

# The UNMUTATED CONTROL, copied first and from the same directory. A lone copy of a
# script that dies on startup emits nothing, and "no output" scores as a kill for every
# mutant at once. This is the arm that catches that before any mutant is believed.
CTL="$MUT/control.sh"; cp "$V" "$CTL"
push "$CTL" "$C_OK" "$C_BASE"
if [ "$RC" -eq 0 ] && printf '%s' "$OUT" | grep -q "1 commit(s) judged"; then
  ok "CONTROL: an unmutated copy in the mutant directory still passes assertion 1"
else
  bad "CONTROL: the unmutated copy does not work from $MUT (rc=$RC) — every mutant below is unproven: $OUT"
fi

# mutate <name> <sed> ; sets M to the mutant path, or bad()s and returns 1
mutate() {
  M="$MUT/$1.sh"
  sed "$2" "$V" > "$M"
  if cmp -s "$V" "$M"; then
    bad "FIXTURE BROKEN: mutation '$1' matched nothing, so its assertion is unproven"
    return 1
  fi
  return 0
}

# M1 — drop the bare-rewrite arm.
if mutate m1 's@elif only_licensed and not claims:@elif False:@'; then
  push "$M" "$C_BARE" "$C_OK"; r2=$RC
  push "$M" "$C_SMUG" "$C_BARE"; r3=$RC
  if [ "$r2" -eq 0 ] && [ "$r3" -ne 0 ]; then
    ok "M1: dropping the bare-rewrite arm kills assertion 2 and ONLY assertion 2"
  else
    bad "M1: expected assertion 2 to die alone (rc2=$r2 rc3=$r3) — the two rejection arms are entangled"
  fi
fi

# M2 — drop the path bound on the licensed subject.
if mutate m2 's@if claims and not only_licensed:@if False:@'; then
  push "$M" "$C_SMUG" "$C_BARE"; r3=$RC
  push "$M" "$C_BARE" "$C_OK"; r2=$RC
  if [ "$r3" -eq 0 ] && [ "$r2" -ne 0 ]; then
    ok "M2: dropping the path bound kills assertion 3 and ONLY assertion 3"
  else
    bad "M2: expected assertion 3 to die alone (rc3=$r3 rc2=$r2)"
  fi
fi

# M3 — let an empty read report a pass. The mutant exits 0 either way, which is exactly
# why the assertion is on the WORDING: the arm that must survive is the one that tells a
# disarmed wiring apart from a clean push, and both exit 0.
if mutate m3 's@    if not refs:@    if False:@'; then
  OUT="$(printf '' | AI_DLC_AUDIT_ANCHORS_SCHEMA="$S" bash "$M" --trunk-push 2>&1)"
  if printf '%s' "$OUT" | grep -q "PASS" && ! printf '%s' "$OUT" | grep -q "NO REF LINES"; then
    ok "M3: without the empty-read branch a run that judged nothing reports a pass — assertion 6 dies"
  else
    bad "M3: the empty-read branch was removed and the output did not change: $OUT"
  fi
fi

# M4 — restore the absorbed script's ref-creation behaviour.
if mutate m4 's@        if remote_sha == ZERO:@        if False:@'; then
  push "$M" "$C_RETRO" "$ZERO"
  if ! printf '%s' "$OUT" | grep -q "creating the remote ref"; then
    ok "M4: without the ref-creation branch the first push of a trunk is no longer exempt — assertion 7 dies"
  else
    bad "M4: the ref-creation branch was removed and the note survived: $OUT"
  fi
fi

# M5 — THE SCHEMA IS THE DEFINITION, not a comment beside one. Mutating the SCHEMA (not
# the script) must change the verdict; if it does not, the matcher carries its own copy of
# the pattern and the schema is decoration. Same lesson the header of the schema records
# about the header region it replaced.
MS="$MUT/audit-anchors.json"
sed 's@\^chore@^release@' "$S" > "$MS"
if cmp -s "$S" "$MS"; then
  bad "FIXTURE BROKEN: the M5 schema mutation matched nothing, so schema-drivenness is unproven"
else
  SCHEMA_USE="$MS"; push "$V" "$C_OK" "$C_BASE"; SCHEMA_USE="$S"
  if [ "$RC" -ne 0 ]; then
    ok "M5: changing the pattern in the SCHEMA changes the verdict (the matcher reads it; it does not restate it)"
  else
    bad "M5: the schema pattern changed and the shipped verdict did not — the script carries its own copy"
  fi
fi

echo
if [ "$fails" -eq 0 ]; then echo "trunk-push-bound: PASS"; exit 0; fi
echo "trunk-push-bound: $fails assertion(s) FAILED" >&2
exit 1
