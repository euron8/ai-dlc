#!/usr/bin/env bash
# relabel-theirs-collision/run.sh — prove relabel-extension-checks.sh sees a collision the pull
# CREATES, not only one already present in the installed core.
#
# THE DEFECT THIS EXISTS TO CATCH. The tool defined "core" as the consumer's INSTALLED core. In a
# dry-run before apply, that core does not yet carry the number the pull adds, so a NEW-THIS-PULL
# collision (upstream `### 26.` vs an extension's `### 26.`) read as "no collisions" — while the
# reconcile report's needs-confirmation list flagged it. The operator saw a flagged collision with
# no relabel option. --theirs unions the incoming core's numbers, so the dry-run previews it.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

echo "relabel-theirs-collision:"

# --- Assertion 0: SANITY — the extension heading starts unlabelled --------------------
if grep -qE '^### 26\. Ext' "$EXT" && ! grep -qE '^### 26\. \[ext:' "$EXT"; then
  ok "extension defines an unlabelled '### 26.' and installed core has no 26 (a pull-created collision)"
else
  bad "FIXTURE BROKEN — extension is not an unlabelled '### 26.'"; echo; echo "relabel-theirs-collision: FIXTURE BROKEN" >&2; exit 2
fi

# --- Assertion 1: WITHOUT theirs, the pull-created `26` collision is INVISIBLE (the bug) ---
# Scoped to 26: the step-domain and H1 collisions below are already in the INSTALLED core,
# so they surface without --theirs. Asserting a blanket "clean" here would fail for the
# right reason and hide the wrong one.
out="$(bash "$SCRIPT" "$CONSUMER" 2>&1)"
if grep -q '\[ext:mydomain\]' <<<"$out"; then
  bad "plain dry-run (no --theirs) already previews the 26 relabel — the NEW-THIS-PULL reproduction is off"
else
  ok "plain dry-run (no --theirs) does not see the pull-created 26 collision — reproduces the blind spot"
fi

# --- Assertion 2: WITH --theirs, the dry-run PREVIEWS the collision (exit 1) ----------
out="$(bash "$SCRIPT" "$CONSUMER" --dist "$DIST" --theirs "$THEIRS" 2>&1)"; rc=$?
if [ "$rc" -eq 1 ] && grep -q '\[ext:mydomain\]' <<<"$out"; then
  ok "dry-run with --theirs previews the relabel to '[ext:mydomain]' and flags work outstanding (exit 1)"
else
  bad "dry-run with --theirs did NOT preview the collision (rc=$rc) — theirs union not working"
fi

# --- Assertion 3: --apply with --theirs writes the label; re-run is clean -------------
bash "$SCRIPT" "$CONSUMER" --apply --dist "$DIST" --theirs "$THEIRS" >/dev/null 2>&1
if grep -qE '^### 26\. \[ext:mydomain\] Ext deployed-ranges consistency gate\.$' "$EXT"; then
  ok "--apply labelled the heading '### 26. [ext:mydomain] …' (integer unchanged)"
else
  bad "--apply did not write the expected labelled heading"
fi
out="$(bash "$SCRIPT" "$CONSUMER" --dist "$DIST" --theirs "$THEIRS" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && grep -q "no unlabelled core-number collisions" <<<"$out"; then
  ok "re-run after --apply is clean (exit 0) — the relabel is idempotent"
else
  bad "re-run after --apply still reports work (rc=$rc)"
fi

# --- Assertion 4 (B1): a step-domain extension colliding on a core STEP number --------
# `[ "$kind" = check ] || continue` skipped every step-domain entry. On the consumer that
# drove this fix, ALL SIX live collisions were step-domain, so the tool reported clean over
# every one of them while layer-drift.sh reported them correctly.
if grep -qE '^### 3\. \[ext:retro-push\] Ext retro push-candidate harvest\.$' "$EXT_STEP"; then
  ok "B1: step-domain extension colliding on core step 3 was seen and labelled '[ext:retro-push]'"
else
  bad "B1: step-domain collision NOT labelled — the kind filter still skips kind: step-domain"
fi

# --- Assertion 5 (B2): a LETTER anchor (H1) is an anchor ------------------------------
# core_num_stream required `[0-9]+` first, so core's real `### H1.` / `### H2.` in
# gate-validation.md yielded ZERO anchors and an extension colliding on H1 could never be
# relabelled. The em-dash here is inside the TITLE and must survive the rewrite verbatim.
if grep -qE '^### H1\. \[ext:harness-ext\] Ext harness meta-check — consumer fixtures\.$' "$EXT_H1"; then
  ok "B2: letter-anchor 'H1' collision was seen, labelled, and the title em-dash survived"
else
  bad "B2: H1 collision NOT labelled as expected — got: $(grep -E '^### H1' "$EXT_H1" || echo '<no H1 heading>')"
fi

# --- Assertion 6 (MUTANT GUARD): widening the filter must not mean "everything" -------
# If this trips, `case "$kind" in check|step-domain)` was loosened to accept any kind.
if grep -qE '^### 25\. Ext role-shaped entry that must never be relabelled\.$' "$EXT_ROLE"; then
  ok "mutant guard: kind: role left untouched (the filter widened to two kinds, not to all)"
else
  bad "mutant guard: a kind: role entry was relabelled — the kind filter is now accepting everything"
fi

echo
if [ "$fails" -eq 0 ]; then echo "relabel-theirs-collision: PASS"; exit 0; fi
echo "relabel-theirs-collision: $fails assertion(s) FAILED" >&2
exit 1
