#!/usr/bin/env bash
# receipt-bl921.sh -- BL-921's receipt, and fixture-hygiene's arm D7 (run.sh invokes this file and reads its exit and
# its PASS line; it carries no second copy of this logic).
#
# It SEEDS its own probe world under mktemp and never reads the real fixture corpus: a VERSION marker, so the
# validator's root walk resolves to the PROBE; the shipping scripts/validate-fixture-hygiene.sh and its sibling
# resolver copied in; and two fixtures, one row each --
#   fx7  `twins=GONE7`, a twin no code path emits. GONE7 stands on code lines only in NON-emission positions (a
#        `grep -q` argument, an unquoted assignment, an echo string), so a validator reading every word would
#        acquit it. Want: FAIL H7, naming fx7's row and the token GONE7.
#   fy7  `twins=B2,C3.cell`, all real: B2 an `ok` message label, C3.cell a `<label>.<cell>` twin whose label a `bad`
#        message prints. Want: quiet.
#   fz7  no row: one clean H1, H2 and H6 candidate each and one receipt its run.sh runs, the populations the
#        validator requires before it trusts a corpus.
# One validator run reads all three: rc 1, `FAIL H7:` the only FAIL section, its one row fx7's GONE7, the self-probe's
# H7 line ok, and the corpus count the probe's own (4 fixture .sh scanned, so the root walk did not reach the repo).
#
# usage:  receipt-bl921.sh [--validator <path>]
#   With no argument the subject is the repository's validator, and the copy is held byte-identical (cmp -s).
#   --validator names another copy (fixture-hygiene's MH7 mutant); its stderr is passed through so the caller can read
#   the self-probe refusal, and PASS is printed only for the unmutated subject.
# Exit: 0 PASS, 1 FAIL, 2 the validator refused (its exit 2, passed through), 9 the receipt could not run.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE"
while [ "$ROOT" != "/" ] && [ ! -f "$ROOT/scripts/validate-fixture-hygiene.sh" ]; do ROOT="$(dirname "$ROOT")"; done
[ -f "$ROOT/scripts/validate-fixture-hygiene.sh" ] && [ -f "$ROOT/scripts/validate-fixture-invocations.sh" ] \
  || { echo "receipt-bl921: REFUSED -- no scripts/validate-fixture-hygiene.sh above $HERE" >&2; exit 9; }
SUBJ="$ROOT/scripts/validate-fixture-hygiene.sh"; REAL=1
case "${1:-}" in
  "") ;;
  --validator) [ -f "${2:-}" ] || { echo "receipt-bl921: REFUSED -- --validator names no file" >&2; exit 9; }; SUBJ="$2"; REAL=0 ;;
  *) echo "usage: receipt-bl921.sh [--validator <path>]" >&2; exit 9 ;;
esac
WORK="$(mktemp -d)" || { echo "receipt-bl921: REFUSED -- mktemp failed" >&2; exit 9; }
trap 'rm -rf "$WORK"' EXIT
W="$WORK/world"
mkdir -p "$W/scripts" "$W/core/fixtures/fx7" "$W/core/fixtures/fy7" && : > "$W/VERSION" \
  && cp -p "$SUBJ" "$W/scripts/validate-fixture-hygiene.sh" && cp -p "$ROOT/scripts/validate-fixture-invocations.sh" "$W/scripts/" \
  || { echo "receipt-bl921: REFUSED -- could not build the probe world" >&2; exit 9; }
if [ "$REAL" = 1 ]; then
  cmp -s "$SUBJ" "$W/scripts/validate-fixture-hygiene.sh" \
    || { echo "receipt-bl921: REFUSED -- the probe's validator is not byte-identical to $SUBJ" >&2; exit 9; }
fi
cat > "$W/core/fixtures/fx7/run.sh" <<'EOF'
#!/usr/bin/env bash
# MUTANT-MATRIX MD decides=A1 twins=GONE7
# MUTANT-MATRIX-REMEASURE bash core/fixtures/fx7/run.sh --matrix
mkmut() { :; }
ok "A1 holds"
grep -q GONE7 "$f"
x=GONE7
echo "GONE7 is data here"
EOF
# fz7 carries no row: one clean candidate each for H1, H2 and H6, which the validator requires before it trusts a
# corpus (a grammar that matched nothing is a refusal, not a clean tree).
mkdir -p "$W/core/fixtures/fz7" && printf 'jq\n' > "$W/core/fixtures/fz7/tools.decl"
cat > "$W/core/fixtures/fz7/run.sh" <<'EOF'
#!/usr/bin/env bash
[ -d "$R/.git" ] || { echo "FIXTURE BROKEN: no history"; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "FIXTURE BROKEN: no jq"; exit 2; }
. "$HERE/../lib/mutant.sh" || { echo "FIXTURE BROKEN: cannot source lib/mutant.sh" >&2; exit 2; }
bash "$HERE/receipt-z.sh"
EOF
printf '#!/usr/bin/env bash\nexit 0\n' > "$W/core/fixtures/fz7/receipt-z.sh"
cat > "$W/core/fixtures/fy7/run.sh" <<'EOF'
#!/usr/bin/env bash
# MUTANT-MATRIX MR decides=A1 twins=B2,C3.cell
# MUTANT-MATRIX-REMEASURE bash core/fixtures/fy7/run.sh --matrix
mkmut() { :; }
ok "A1 holds"
ok "B2 holds"
bad "C3 broke"
EOF
{ env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE -u GIT_OBJECT_DIRECTORY git -c core.hooksPath=/dev/null init -q "$W" \
  && env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE -u GIT_OBJECT_DIRECTORY git -C "$W" add -A core; } >/dev/null 2>&1 \
  || { echo "receipt-bl921: REFUSED -- could not index the probe world" >&2; exit 9; }

( cd "$W" && unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE && bash "$W/scripts/validate-fixture-hygiene.sh" ) > "$WORK/out" 2> "$WORK/err"
vrc=$?
cat "$WORK/err" >&2
[ "$vrc" = 2 ] && { echo "receipt-bl921: the validator REFUSED (exit 2)"; exit 2; }
f=0
no() { echo "receipt-bl921: FAIL -- $1"; f=1; }
[ "$vrc" = 1 ] || no "the validator exited $vrc over a world with one dangling twin, want 1"
grep -qF 'self-probe H7: ok' "$WORK/err" || no "no 'self-probe H7: ok' line"
grep -qF 'validate-fixture-hygiene: 4 fixture .sh scanned;' "$WORK/out" \
  || no "the corpus count is not the probe's 4 files, so the root walk did not resolve to the probe"
nf="$(grep -c '^FAIL ' "$WORK/out")" || nf=0
[ "$nf" = 1 ] && grep -qx 'FAIL H7:' "$WORK/out" || no "want exactly one FAIL section, FAIL H7 (got $nf: $(grep '^FAIL ' "$WORK/out" | tr '\n' ' '))"
sec="$(awk '$0 == "FAIL H7:" { on = 1; next } on && /^    / { print; next } on { exit }' "$WORK/out")"
case "$sec" in
  "    H7 fx7:2:GONE7: twin GONE7 names no label"*) ;;
  *) no "the H7 section is not exactly fx7's dangling twin GONE7: $(printf '%s' "$sec" | tr '\n' '|')" ;;
esac
[ "$(printf '%s\n' "$sec" | grep -c .)" = 1 ] || no "the H7 section carries more than fx7's one row (the all-real fy7 row must stay quiet)"
case "$sec" in *fy7*) no "the all-real row fy7 was reported" ;; esac
[ "$f" = 0 ] || exit 1
[ "$REAL" = 1 ] || { echo "receipt-bl921: held under a substituted validator (no PASS is printed for a copy)"; exit 0; }
echo "receipt-bl921: PASS"
exit 0
