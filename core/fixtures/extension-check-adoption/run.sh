#!/usr/bin/env bash
# extension-check-adoption — exercise reconcile/adopt-extension-checks.sh, the remedy
# for validate-gate-manifest.sh's GM1 (UNLOADABLE) arm.
#
# Exit 0 iff:
#   - the dry-run names exactly the unanchored ids, and NEITHER the already-adopted
#     entry, NOR the out-of-scope entry, NOR the extension that augments a core check
#   - the alphabetic id (`## Check XVH —`) is among them — the shape a narrower
#     heading grammar could not see
#   - `--apply` without `--gate-types` is REFUSED (2), never a half-write
#   - `--apply --gate-types <not in the manifest's enum>` is REFUSED (2)
#   - `--apply --gate-types planning` writes anchors AND frontmatter, and
#     validate-gate-manifest.sh then exits 0
#   - re-running --apply is a no-op (level-triggered, idempotent)
#   - NON-VACUITY: stripping the written `gate_types:` back out turns the tree ORPHAN,
#     which is what proves the atomicity requirement is real rather than decoration
#   - MUTATION: each half of the write is load-bearing, and each mutant fails ONLY its
#     own assertion — asserted on the emitted CODE, not on exit status, because both
#     halves fail with exit 1 and would otherwise entangle
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"

T=""
for cand in \
  "$DIR/../../skills/ai-dlc-update/reconcile/adopt-extension-checks.sh" \
  "$DIR/../../../.claude/skills/ai-dlc-update/reconcile/adopt-extension-checks.sh" \
  "$DIR/../../core/skills/ai-dlc-update/reconcile/adopt-extension-checks.sh"; do
  [ -f "$cand" ] && T="$cand" && break
done
[ -n "$T" ] || { echo "run.sh: could not locate adopt-extension-checks.sh" >&2; exit 2; }

V=""
for cand in \
  "$DIR/../../scripts/validate-gate-manifest.sh" \
  "$DIR/../../../scripts/ai-dlc/validate-gate-manifest.sh" \
  "$DIR/../../core/scripts/validate-gate-manifest.sh"; do
  [ -f "$cand" ] && V="$cand" && break
done
[ -n "$V" ] || { echo "run.sh: could not locate validate-gate-manifest.sh" >&2; exit 2; }

rc=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1" >&2; rc=1; }

fresh() { bash "$DIR/seed.sh"; }
# The operator's answer to the NEEDS DECISION row: the entry really is a check and its
# `kind:` was wrong. Applied explicitly rather than seeded already-correct, so the path
# under test is the whole remedy — report the decision, take the answer, then adopt.
decide() { perl -0pi -e 's/^kind: step-domain$/kind: check/m' \
             "$1/.claude/skills/ai-dlc/extensions/checks/out-of-scope.md"; }
echo "extension-check-adoption:"

# --- 1. the dry-run's subject set --------------------------------------------------
R="$(fresh)"; S="$R/.claude/skills/ai-dlc"
OUT="$(bash "$T" "$R" 2>&1)"; g=$?
[ "$g" -eq 1 ] && ok "dry-run with work outstanding exits 1" \
               || bad "dry-run exited $g, expected 1"

for want in 915 919b XVH; do
  grep -qF -- "$want" <<<"$OUT" && ok "dry-run names adoptable id '$want'" \
                                || bad "dry-run did not name '$want'"
done
grep -qF -- "XVH" <<<"$OUT" \
  && ok "ALPHABETIC id is in the subject set (the shape a narrower heading grammar cannot see)" \
  || bad "the alphabetic id was invisible — the grammar has forked from GM1's"

# The three over-fire controls. Each is a DIFFERENT reason to be out of scope, so a
# rule that collapses them shows up here rather than in production.
grep -qF -- "930" <<<"$OUT" && bad "OVER-FIRE: the already-adopted check was reported as adoptable" \
                            || ok "OVER-FIRE CONTROL: an already-anchored+declared check is not reported"
grep -qF -- "950" <<<"$OUT" && bad "OVER-FIRE: an entry hooking a DIFFERENT step file was reported" \
                            || ok "OVER-FIRE CONTROL: an entry hooking another step file is out of scope (GM1 does not count it either)"
# The kind mismatch is NOT an over-fire control: GM1 counts it, so silence here would be
# a remedy that cannot reach something the check names. It must be REPORTED and NOT written.
grep -q "NEEDS DECISION" <<<"$OUT" && grep -qF -- "940" <<<"$OUT" \
  && ok "a non-\`check\` entry hooking the manifest is REPORTED as a decision, not silently skipped" \
  || bad "the kind-mismatch entry was not reported — GM1 counts it and this tool would be unable to reach it"
grep -qF -- "augments-core" <<<"$OUT" && bad "OVER-FIRE: an extension augmenting a CORE-anchored check was reported" \
                                      || ok "OVER-FIRE CONTROL: an id core already anchors drops out by subtraction"

# Non-vacuity for the three controls above: the same reader must still SEE a positive.
grep -qF -- "numeric.md" <<<"$OUT" \
  && ok "CONTROL: the same reader sees a reported entry (the three over-fire oks are not silence)" \
  || bad "FIXTURE ERROR: the dry-run reported no entry at all — the over-fire controls proved nothing"

# --- 2. the enum is DERIVED from the manifest, not from a literal -------------------
grep -q "gate-type enum : universal planning story implementation sprint-review retro" <<<"$OUT" \
  && ok "the legal gate types are read out of the manifest's own first column" \
  || bad "the gate-type enum did not match the seeded GATE_MANIFEST table"

# --- 3. refusals: never a half-write ------------------------------------------------
bash "$T" "$R" --apply >/dev/null 2>&1
[ $? -eq 2 ] && ok "--apply WITHOUT --gate-types is refused (2) — the slice is not inferable" \
             || bad "--apply without --gate-types was not refused; a default here is the inference this tool exists not to make"

bash "$T" "$R" --apply --gate-types nosuchtype >/dev/null 2>&1
[ $? -eq 2 ] && ok "--gate-types outside the derived enum is refused (2)" \
             || bad "an unrecognised gate type was accepted — it would just move the failure to GM2"

# Neither refusal may have written anything.
if grep -q 'CHECK_LOADED: 915' "$S/extensions/checks/numeric.md"; then
  bad "a REFUSED run still wrote an anchor — that is the half-write this tool must never produce"
else
  ok "a refused run wrote nothing"
fi


# --- a `team-roles/` hook must not be FATAL ------------------------------------------
# It resolves OUTSIDE the skill dir. The tool joined it under the skill dir and exited 2 on
# failure, so one role extension made it scan NOTHING -- and a GM1 tool that prints nothing
# reads exactly like a clean one. The dry-run above already exercised this seed; assert the
# code, because rc 2 and rc 1 are "died" and "found work".
RN="$(fresh)"; SN="$RN/.claude/skills/ai-dlc"
bash "$T" "$RN" >/dev/null 2>&1
[ $? -ne 2 ] && ok "a team-roles/ hook does not kill the run (it resolves outside the skill dir)" \
             || bad "a team-roles/ hook still exits 2 — the tool scans nothing on any consumer with a role extension"

# --- the GLOBAL flag is REFUSED across several undeclared entries ---------------------
# `gate_types:` is entry frontmatter and the right answer differs per entry; the reference
# consumer needed four different values. One flag wrote one value into all four, silently,
# including entries the operator never considered.
bash "$T" "$RN" --apply --gate-types planning >/dev/null 2>&1
[ $? -eq 2 ] && ok "a GLOBAL --gate-types across >1 undeclared entry is REFUSED" \
             || bad "a global --gate-types wrote to several entries at once — the silent wrong-value write"
if grep -q 'CHECK_LOADED' "$SN/extensions/checks/numeric.md"; then
  bad "the REFUSED run still wrote — a refusal that writes is not a refusal"
else
  ok "the refused run wrote nothing"
fi

# --- per-entry answers, and they must DIFFER -----------------------------------------
bash "$T" "$RN" --apply \
  --entry extensions/checks/numeric.md --gate-types planning \
  --entry extensions/checks/alpha.md   --gate-types "story, implementation" >/dev/null 2>&1
a=$?
[ "$a" -eq 0 ] && ok "per-entry --entry/--gate-types applies" || bad "per-entry apply exited $a"
if grep -q '^gate_types: \[planning\]' "$SN/extensions/checks/numeric.md" && \
   grep -q '^gate_types: \[story, implementation\]' "$SN/extensions/checks/alpha.md"; then
  ok "each entry got its OWN value — the per-entry question its header documents is now expressible"
else
  bad "per-entry values did not land distinctly: $(grep -h '^gate_types:' "$SN/extensions/checks/numeric.md" "$SN/extensions/checks/alpha.md" | tr '\n' ' ')"
fi
rm -rf "$RN"

# --- 4. baseline: GM1 fires on the seeded tree --------------------------------------
MF="$S/steps/gate-validation.md"
GOUT="$(bash "$V" "$MF" 2>&1)"; g=$?
if [ "$g" -eq 1 ] && grep -q 'FAIL GM1' <<<"$GOUT"; then
  ok "BASELINE: validate-gate-manifest.sh fires GM1 on the seeded tree"
else
  bad "BASELINE: expected GM1 at exit 1, got exit $g"
fi
grep -q 'adopt-extension-checks.sh' <<<"$GOUT" \
  && ok "the GM1 message names the tool that remedies it (a prohibition with a mechanism behind it)" \
  || bad "GM1 names no remedy tool — the operator is told what is wrong and given nothing that does it"

# --- 5. apply: both halves, then GM1 is clear ---------------------------------------
bash "$T" "$R" --apply --entry extensions/checks/numeric.md --gate-types planning --entry extensions/checks/alpha.md --gate-types planning --entry extensions/checks/out-of-scope.md --gate-types planning >/dev/null 2>&1
a=$?
[ "$a" -eq 0 ] && ok "--apply --gate-types planning exits 0" || bad "--apply exited $a, expected 0"

grep -q 'CHECK_LOADED: 915'  "$S/extensions/checks/numeric.md" && \
grep -q 'CHECK_LOADED: 919b' "$S/extensions/checks/numeric.md" && \
grep -q 'CHECK_LOADED: XVH'  "$S/extensions/checks/alpha.md" \
  && ok "APPLY wrote the anchors, alphabetic id included" \
  || bad "APPLY did not write every anchor"

grep -q '^gate_types: \[planning\]' "$S/extensions/checks/numeric.md" && \
grep -q '^gate_types: \[planning\]' "$S/extensions/checks/alpha.md" \
  && ok "APPLY wrote gate_types: into the entry frontmatter" \
  || bad "APPLY did not write gate_types:"

grep -q 'CHECK_LOADED: 940' "$S/extensions/checks/out-of-scope.md" \
  && bad "APPLY rewrote the out-of-scope entry" \
  || ok "APPLY left the out-of-scope entry untouched"

# GM1 cannot be clear yet: the kind-mismatch entry's heading is still UNLOADABLE and
# the tool REFUSED to write it. That refusal is correct, and asserting it here is what
# stops "GM1 clear" from being reachable by a tool that writes indiscriminately.
bash "$V" "$MF" >/dev/null 2>&1
[ $? -ne 0 ] && ok "GM1 still fires while the NEEDS DECISION entry is unresolved (the refusal is not a silent skip)" \
             || bad "GM1 went clear with the kind-mismatch entry unresolved — something wrote into it"

decide "$R"
# The operator answered the decision, so the entry is now a `check` and needs its OWN
# gate types -- naming only the earlier two would leave it undeclared, which is the point.
bash "$T" "$R" --apply --entry extensions/checks/out-of-scope.md --gate-types planning >/dev/null 2>&1
bash "$V" "$MF" >/dev/null 2>&1
g=$?
[ "$g" -eq 0 ] && ok "after the operator answers the decision and re-runs, GM1 is CLEAR" \
               || bad "the manifest still does not resolve after the full remedy path (exit $g)"

# --- 6. idempotence ------------------------------------------------------------------
BEFORE="$(cat "$S/extensions/checks/numeric.md")"
bash "$T" "$R" --apply --entry extensions/checks/numeric.md --gate-types planning --entry extensions/checks/alpha.md --gate-types planning --entry extensions/checks/out-of-scope.md --gate-types planning >/dev/null 2>&1
[ "$(cat "$S/extensions/checks/numeric.md")" = "$BEFORE" ] \
  && ok "re-running --apply is a no-op (level-triggered on tree STATE, not on a diff)" \
  || bad "re-running --apply changed the tree — it is edge-triggered and will double-write"

# --- 7. NON-VACUITY: the atomicity requirement is real ------------------------------
# Strip the gate_types: this run just wrote and keep the anchors. If that does NOT turn
# the tree red, then "the two writes must land together" is decoration and the whole
# reason this tool exists is unfounded.
perl -0pi -e 's/^gate_types: \[planning\]\n//m' "$S/extensions/checks/numeric.md"
MF="$S/steps/gate-validation.md"
GOUT="$(bash "$V" "$MF" 2>&1)"; g=$?
if [ "$g" -ne 0 ] && grep -q 'ORPHAN' <<<"$GOUT"; then
  ok "NON-VACUITY: anchors WITHOUT gate_types: make the tree ORPHAN — the two writes really are one edit"
else
  bad "NON-VACUITY: stripping gate_types: left the tree green (exit $g) — the atomicity claim is unfounded"
fi
rm -rf "$R"

# --- 8. MUTANTS: one per half of the write, each failing only its own assertion -----
# Asserted on the CODE the manifest resolver emits, not on exit status: both halves
# fail at exit 1, so an exit-status assertion would let these two entangle and one
# would be vacuous.
# mutate <name> <literal-substring> <replacement> -> prints the mutant path, or empty
# if the substring matched nothing. LITERAL, via python: the subject lines are python
# source full of regex metacharacters, and a sed/perl spelling of them is a second
# escaping problem whose failure mode is a mutant identical to the subject — which then
# "fails as expected" for the wrong reason. `cmp -s` is what catches that, and it did:
# the first draft of these three matched nothing and the fixture refused to score them.
mutate() {
  local name="$1" M
  M="$(mktemp "${TMPDIR:-/tmp}/adopt-mutant-$name.XXXXXX")"
  cp "$T" "$M"
  MUT_OLD="$2" MUT_NEW="$3" python3 - "$M" <<'MPY'
import os, sys
p = sys.argv[1]
s = open(p).read()
old, new = os.environ["MUT_OLD"], os.environ["MUT_NEW"]
open(p, "w").write(s.replace(old, new, 1))
MPY
  if cmp -s "$T" "$M"; then rm -f "$M"; printf ''; else printf '%s' "$M"; fi
}

code_of() { # run the manifest resolver, echo the code it emits
  local root="$1" out
  out="$(bash "$V" "$root/.claude/skills/ai-dlc/steps/gate-validation.md" 2>&1)"
  if   grep -q 'FAIL GM1' <<<"$out"; then echo GM1
  elif grep -q 'FAIL GM2' <<<"$out"; then echo GM2
  elif grep -q 'ORPHAN  (anchor, no manifest claim): [^n]' <<<"$out"; then echo ORPHAN
  elif grep -q 'PASS' <<<"$out"; then echo PASS
  else echo OTHER; fi
}

# M1 — neuter the ANCHOR write. `gate_types:` lands, the anchors do not, so the entry
# declares loading for an id that exists nowhere: GM2, "the declaration claims loading
# for nothing". M2 below neuters the other half and produces ORPHAN. TWO DIFFERENT
# CODES from the two halves is the point — it is what proves the assertions are not
# entangled, and it is why these assert on the code rather than on exit status, which
# is 1 for both.
M1="$(mutate anchor ' + f"<!-- CHECK_LOADED: {i} -->\n"' ' + ""')"
if [ -z "$M1" ]; then
  bad "FIXTURE ERROR: the anchor-write mutation matched nothing — assertion 5 proves nothing"
else
  R1="$(fresh)"; decide "$R1"; bash "$M1" "$R1" --apply --entry extensions/checks/numeric.md --gate-types planning --entry extensions/checks/alpha.md --gate-types planning --entry extensions/checks/out-of-scope.md --gate-types planning >/dev/null 2>&1
  c="$(code_of "$R1")"
  [ "$c" = "GM2" ] && ok "MUTANT anchor-write: without the anchor the declaration claims loading for nothing — GM2" \
                   || bad "MUTANT anchor-write: expected GM2, got $c"
  rm -rf "$R1" "$M1"
fi

# M2 — neuter the gate_types WRITE. Anchors land, declaration does not: ORPHAN.
M2="$(mutate gts '        if not declared:' '        if False:')"
if [ -z "$M2" ]; then
  bad "FIXTURE ERROR: the gate_types-write mutation matched nothing — assertion 5 proves nothing"
else
  R2="$(fresh)"; decide "$R2"; bash "$M2" "$R2" --apply --entry extensions/checks/numeric.md --gate-types planning --entry extensions/checks/alpha.md --gate-types planning --entry extensions/checks/out-of-scope.md --gate-types planning >/dev/null 2>&1
  c="$(code_of "$R2")"
  [ "$c" = "ORPHAN" ] && ok "MUTANT gate_types-write: without the declaration the anchors become ORPHANs (a DIFFERENT code, so the two assertions are not entangled)" \
                      || bad "MUTANT gate_types-write: expected ORPHAN, got $c"
  rm -rf "$R2" "$M2"
fi

# M3 — neuter the kind guard. The seeded `step-domain` entry hooks the SAME manifest,
# so the guard is the only thing between it and a written `gate_types:`. Without the
# guard the tool picks one of two opposite fixes by accident.
M3="$(mutate kind '        if frontmatter(t, "kind") != "check":' '        if False:')"
if [ -z "$M3" ]; then
  bad "FIXTURE ERROR: the entry-filter mutation matched nothing"
else
  R3="$(fresh)"; bash "$M3" "$R3" --apply --entry extensions/checks/numeric.md --gate-types planning --entry extensions/checks/alpha.md --gate-types planning --entry extensions/checks/out-of-scope.md --gate-types planning >/dev/null 2>&1
  if grep -q 'CHECK_LOADED: 940' "$R3/.claude/skills/ai-dlc/extensions/checks/out-of-scope.md" 2>/dev/null; then
    ok "MUTANT entry-filter: ignoring \`kind:\` rewrites a \`step-domain\` entry (that filter is load-bearing)"
  else
    bad "MUTANT entry-filter: the out-of-scope entry survived — the scope assertion proves nothing"
  fi
  rm -rf "$R3" "$M3"
fi

# --- unmutated control -------------------------------------------------------------
# A mutant copy that dies for its own reasons emits nothing, and "no output" would
# otherwise score as a kill.
MC="$(mktemp "${TMPDIR:-/tmp}/adopt-control.XXXXXX")"; cp "$T" "$MC"
RC="$(fresh)"; decide "$RC"; bash "$MC" "$RC" --apply --entry extensions/checks/numeric.md --gate-types planning --entry extensions/checks/alpha.md --gate-types planning --entry extensions/checks/out-of-scope.md --gate-types planning >/dev/null 2>&1
c="$(code_of "$RC")"
[ "$c" = "PASS" ] && ok "CONTROL: an UNMUTATED copy still clears GM1 (the mutants died of their edits, not of being copies)" \
                  || bad "CONTROL: the unmutated copy produced $c — every mutant verdict above is unattributable"
rm -rf "$RC" "$MC"

echo
if [ "$rc" -eq 0 ]; then echo "extension-check-adoption: PASS"; else echo "extension-check-adoption: FAILED" >&2; fi
exit $rc
