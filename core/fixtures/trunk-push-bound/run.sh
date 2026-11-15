#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
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
# Clear every inherited AI_DLC_* tunable and CLAUDE_PROJECT_DIR so a bare run judges the code, not the caller environment.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset CLAUDE_PROJECT_DIR

HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
. "$HERE/../lib/report.sh" || { echo "FIXTURE ERROR: lib/report.sh not found" >&2; exit 2; }

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
echo "HERMETIC-CONSUMED $(cd "$(dirname "$V")" && pwd)/$(basename "$V")"

WORK="$(mktemp -d)" || exit 2
trap 'rm -rf "$WORK"' EXIT
REPO="$WORK/repo"; mkdir -p "$REPO"

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
if [ "$RC" -eq 0 ] && grep -q "1 commit(s) judged" <<<"$OUT"; then
  ok "the Step 5b backfill commit passes, and the run states how many commits it judged"
else
  bad "the licensed commit did not pass cleanly (rc=$RC): $OUT"
fi

# --- Assertion 2: that path, rewritten alone, under any other subject ---------------
push "$V" "$C_BARE" "$C_OK"
if [ "$RC" -ne 0 ] && grep -q "under a subject Step 5b does not license" <<<"$OUT"; then
  ok "rewriting the anchors file alone under an unlicensed subject is REJECTED"
else
  bad "an unlicensed direct-to-trunk rewrite of the anchors file was allowed (rc=$RC)"
fi

# --- Assertion 3: the licensed subject cannot carry anything else -------------------
# Clause (c): a backfill that also carries source is not a backfill. Without this, the
# subject becomes a password for pushing arbitrary code straight to the trunk.
push "$V" "$C_SMUG" "$C_BARE"
if [ "$RC" -ne 0 ] && grep -q "claims the Step 5b backfill subject while touching" <<<"$OUT"; then
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
if [ "$RC" -eq 0 ] && grep -q "does not target" <<<"$OUT"; then
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
if [ "$RC" -eq 0 ] && grep -q "NO REF LINES ON STDIN" <<<"$OUT" \
   && ! grep -q "PASS" <<<"$OUT"; then
  ok "reading no refs reports that it judged nothing, in wording no passing run emits"
else
  bad "a run that judged nothing was indistinguishable from a clean push: $OUT"
fi

# --- Assertion 7: creating the ref is not judging the whole history -----------------
# The absorbed consumer script takes range="$local_sha" here, which is every ancestor:
# the first push of a trunk lists the entire history and cannot land. Core will not.
push "$V" "$C_RETRO" "$ZERO"
if [ "$RC" -eq 0 ] && grep -q "creating the remote ref" <<<"$OUT"; then
  ok "creating the remote ref judges no delta (the absorbed script judged every ancestor and blocked the push)"
else
  bad "creating the trunk ref was judged against the whole history (rc=$RC): $OUT"
fi

# --- Assertion 8: the trunk name is a tunable, not a literal ------------------------
OUT="$(printf 'refs/heads/main %s refs/heads/main %s\n' "$C_BARE" "$C_OK" \
      | AI_DLC_TRUNK=develop AI_DLC_AUDIT_ANCHORS_SCHEMA="$S" bash "$V" --trunk-push 2>&1)"; RC=$?
if [ "$RC" -eq 0 ] && grep -q "develop" <<<"$OUT"; then
  ok "AI_DLC_TRUNK repoints the trunk (the same tunable validate-cycle-commits.sh reads)"
else
  bad "AI_DLC_TRUNK was ignored and 'main' was judged regardless (rc=$RC)"
fi

report_end trunk-push-bound
