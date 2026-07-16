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

# --- Assertion 1: WITHOUT theirs, the pull-created collision is INVISIBLE (the bug) ---
out="$(bash "$SCRIPT" "$CONSUMER" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q "no unlabelled core-number collisions"; then
  ok "plain dry-run (no --theirs) reports no collision — reproduces the blind spot"
else
  bad "plain dry-run did NOT report clean (rc=$rc) — the reproduction is off"
fi

# --- Assertion 2: WITH --theirs, the dry-run PREVIEWS the collision (exit 1) ----------
out="$(bash "$SCRIPT" "$CONSUMER" --dist "$DIST" --theirs "$THEIRS" 2>&1)"; rc=$?
if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q '\[ext:mydomain\]'; then
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
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q "no unlabelled core-number collisions"; then
  ok "re-run after --apply is clean (exit 0) — the relabel is idempotent"
else
  bad "re-run after --apply still reports work (rc=$rc)"
fi

echo
if [ "$fails" -eq 0 ]; then echo "relabel-theirs-collision: PASS"; exit 0; fi
echo "relabel-theirs-collision: $fails assertion(s) FAILED" >&2
exit 1
