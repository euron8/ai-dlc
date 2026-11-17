#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
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

echo "HERMETIC-CONSUMED $SCRIPT"

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }
# A literal-tail path, never `. "$VAR"`: in a fixture opted in by an inproc: row, P1 reads an opaque source as a drive.
. "$HERE/../lib/mutant.sh" || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $HERE" >&2; exit 2; }
. "$HERE/../lib/inproc.sh" || { echo "FIXTURE ERROR: lib/inproc.sh not found beside $HERE" >&2; exit 2; }
. "$HERE/../lib/layout.sh" || { echo "FIXTURE ERROR: lib/layout.sh not found beside $HERE" >&2; exit 2; }

# IN PROCESS (BL-878). The subject is SOURCED ONCE (inproc_load; its guard returns after defining rec_main) and
# every drive is `rec_ip <args>`, which answers what `bash "$SCRIPT" <args>` gives in a subshell made to look like a
# fresh bash (core/fixtures/lib/inproc.sh), so the subject's `exit`, `set -uf` and EXIT trap stay there. A CORE
# FIXTURE SHIPS AHEAD OF ITS SUBJECT: a subject with neither the `rec_main() {` line nor the column-0 source guard
# predates the wrap and reads SKIP (exit 0, never an ok); exactly one half is a respelled subject and FAILs; a subject
# grep cannot READ is FIXTURE ERROR. The cli cells at the end run the program once per distinct CLI outcome.
wrap_gate() { # wrap_gate <file> <entry> -> 0 wrapped, 3 predates the wrap, 1 one half only (FAIL printed), 2 unreadable
  local d g
  grep -q "^$2() {\$" "$1"; d=$?
  grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$1"; g=$?
  if [ "$d" -gt 1 ] || [ "$g" -gt 1 ]; then
    echo "FIXTURE ERROR: cannot read $1 (grep exit $d/$g), so the in-process wrap cannot be judged; nothing was asserted" >&2
    return 2
  fi
  [ "$d$g" = 00 ] && return 0
  [ "$d$g" = 11 ] && return 3
  if [ "$d" = 1 ]; then echo "  FAIL  $1 carries the column-0 source guard but no \`$2() {\` line -- a respelled subject this fixture cannot drive"
  else echo "  FAIL  $1 defines \`$2() {\` but carries no column-0 source guard -- a respelled subject; sourcing it would run $2 in this shell"; fi
  return 1
}
wrap_gate "$SCRIPT" rec_main; g_rec=$?
[ "$g_rec" != 2 ] || exit 2
[ "$g_rec" != 1 ] || { echo "relabel-theirs-collision: 1 FAILED" >&2; exit 1; }
[ "$g_rec" != 3 ] || { echo "SKIP: subject predates the in-process wrap"; fx_skip_exit "$HERE"; }
inproc_load "$SCRIPT" || { echo "FIXTURE BROKEN: sourcing $SCRIPT defined nothing" >&2; exit 2; }
declare -F rec_main > /dev/null || { echo "FIXTURE BROKEN: sourcing $SCRIPT defined no rec_main" >&2; exit 2; }
rec_ip() { inproc_run "$SCRIPT" rec_main "$@"; }

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
out="$(rec_ip "$CONSUMER" 2>&1)"
if grep -q '\[ext:mydomain\]' <<<"$out"; then
  bad "plain dry-run (no --theirs) already previews the 26 relabel — the NEW-THIS-PULL reproduction is off"
else
  ok "plain dry-run (no --theirs) does not see the pull-created 26 collision — reproduces the blind spot"
fi

# --- Assertion 2: WITH --theirs, the dry-run PREVIEWS the collision (exit 1) ----------
# --- the cli cells (cells.decl): the subject run as a PROGRAM once per distinct CLI outcome ----------------------
# The outcomes are exit 1 with the previewed rewrites (here), exit 0 with the clean line (after --apply, below) and
# exit 2 with the usage line (no consumer root). One `FXCELL=<id> bash "$SCRIPT"` start per outcome, compared with
# the in-process call on the same input: stdout, stderr and exit separately, byte for byte. Each cell also asserts
# its own outcome, so two runs that both printed nothing cannot read as equivalent.
EQ="$WORK/eq"; mkdir -p "$EQ" || { echo "FIXTURE ERROR: mkdir $EQ" >&2; exit 2; }
eqv() { # <cell-id> <subject args...> -> $EQ/<id>.{ip,cl}.{out,err,rc}; 0 when the two agree byte for byte
  local id="$1"; shift
  rec_ip "$@" > "$EQ/$id.ip.out" 2> "$EQ/$id.ip.err"; echo "$?" > "$EQ/$id.ip.rc"
  FXCELL="$id" bash "$SCRIPT" "$@" > "$EQ/$id.cl.out" 2> "$EQ/$id.cl.err"; echo "$?" > "$EQ/$id.cl.rc"
  cmp -s "$EQ/$id.ip.out" "$EQ/$id.cl.out" && cmp -s "$EQ/$id.ip.err" "$EQ/$id.cl.err" && cmp -s "$EQ/$id.ip.rc" "$EQ/$id.cl.rc"
}
eq_twin() { printf 'in-process rc=%s lines=%s err=[%s] / program rc=%s lines=%s err=[%s]' "$(cat "$EQ/$1.ip.rc")" "$(grep -c . "$EQ/$1.ip.out")" \
  "$(head -1 "$EQ/$1.ip.err")" "$(cat "$EQ/$1.cl.rc")" "$(grep -c . "$EQ/$1.cl.out")" "$(head -1 "$EQ/$1.cl.err")"; }

eqv cli-preview "$CONSUMER" --dist "$DIST" --theirs "$THEIRS"; eq_preview=$?
out="$(cat "$EQ/cli-preview.ip.out" "$EQ/cli-preview.ip.err")"; rc="$(cat "$EQ/cli-preview.ip.rc")"
if [ "$eq_preview" -eq 0 ] && [ "$(cat "$EQ/cli-preview.cl.rc")" = 1 ] && grep -q '\[ext:mydomain\]' "$EQ/cli-preview.cl.out"; then
  ok "cli-preview: the program previews the relabel exactly as the in-process call does (stdout, stderr, exit 1)"
else
  bad "cli-preview: the program and the in-process call differ, or the outcome is not exit 1 with the [ext:mydomain] preview ($(eq_twin cli-preview))"
fi
if [ "$rc" -eq 1 ] && grep -q '\[ext:mydomain\]' <<<"$out"; then
  ok "dry-run with --theirs previews the relabel to '[ext:mydomain]' and flags work outstanding (exit 1)"
else
  bad "dry-run with --theirs did NOT preview the collision (rc=$rc) — theirs union not working"
fi

# --- Assertion 3: --apply with --theirs writes the label; re-run is clean -------------
rec_ip "$CONSUMER" --apply --dist "$DIST" --theirs "$THEIRS" >/dev/null 2>&1
if grep -qE '^### 26\. \[ext:mydomain\] Ext deployed-ranges consistency gate\.$' "$EXT"; then
  ok "--apply labelled the heading '### 26. [ext:mydomain] …' (integer unchanged)"
else
  bad "--apply did not write the expected labelled heading"
fi
eqv cli-clean "$CONSUMER" --dist "$DIST" --theirs "$THEIRS"; eq_clean=$?
out="$(cat "$EQ/cli-clean.ip.out" "$EQ/cli-clean.ip.err")"; rc="$(cat "$EQ/cli-clean.ip.rc")"
if [ "$rc" -eq 0 ] && grep -q "no unlabelled core-number collisions" <<<"$out"; then
  ok "re-run after --apply is clean (exit 0) — the relabel is idempotent"
else
  bad "re-run after --apply still reports work (rc=$rc)"
fi
if [ "$eq_clean" -eq 0 ] && [ "$(cat "$EQ/cli-clean.cl.rc")" = 0 ] && grep -q "no unlabelled core-number collisions" "$EQ/cli-clean.cl.out"; then
  ok "cli-clean: the program reports the clean re-run exactly as the in-process call does (stdout, stderr, exit 0)"
else
  bad "cli-clean: the program and the in-process call differ, or the outcome is not exit 0 with the clean line ($(eq_twin cli-clean))"
fi
eqv cli-usage; eq_usage=$?
if [ "$eq_usage" -eq 0 ] && [ "$(cat "$EQ/cli-usage.cl.rc")" = 2 ] && [ ! -s "$EQ/cli-usage.cl.out" ] \
   && grep -q '^usage: relabel-extension-checks.sh <consumer-root>' "$EQ/cli-usage.cl.err"; then
  ok "cli-usage: the program refuses a missing consumer root exactly as the in-process call does (stdout, stderr, exit 2)"
else
  bad "cli-usage: the program and the in-process call differ, or the outcome is not exit 2 with the usage line ($(eq_twin cli-usage))"
fi
if ! cmp -s "$EQ/cli-preview.cl.rc" "$EQ/cli-clean.cl.rc" && ! cmp -s "$EQ/cli-clean.cl.rc" "$EQ/cli-usage.cl.rc" \
   && ! cmp -s "$EQ/cli-preview.cl.out" "$EQ/cli-clean.cl.out"; then
  ok "cli cells discriminate: the preview, the clean re-run and the usage refusal give three different exits"
else
  bad "cli cells do not discriminate: two of cli-preview, cli-clean and cli-usage gave the same exit or stdout"
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
  ok "control (mutant guard): kind: role left untouched (the filter widened to two kinds, not to all)"
else
  bad "mutant guard: a kind: role entry was relabelled — the kind filter is now accepting everything"
fi

echo
report_end relabel-theirs-collision
