#!/usr/bin/env bash
# receipt-bl929.sh -- BL-929's receipt, and fixture-hygiene's arm D8 (run.sh invokes this file and reads its exit and
# its PASS line; it carries no second copy of this logic).
#
# It SEEDS its own probe world under mktemp and never reads the real fixture corpus: a VERSION marker, so the
# validator's root walk resolves to the PROBE; the shipping scripts/validate-fixture-hygiene.sh and its sibling
# resolver copied in; and five fixtures --
#   ra  run.sh scrubs ambient AI_DLC_* as its first statement after `set -u`, then starts a script. Want: `H8 SCRUBBED ra`.
#   rb  a shard stub (`exec bash "$IMPL"`) whose IMPL is ra. Want: `H8 SCRUBBED rb`, judged by its IMPL.
#   rc  no scrub, not on the allowlist. Want: FAIL H8, its one row naming rc.
#   rd  no scrub, a row of scripts/env-scrub-allowlist.txt. Want: quiet (one allowlisted unscrubbed).
#   rz  scrubbed, carrying one clean H1, H2 and H6 candidate, a MUTANT-MATRIX row with real twins and one receipt its
#       run.sh runs: the populations the validator requires before it trusts a corpus.
# One validator run reads all five: rc 1, `FAIL H8:` the only FAIL section, its one row rc's, the self-probe's H8 line
# ok, and the corpus count the probe's own (6 fixture .sh scanned, so the root walk did not reach the repo).
#
# usage:  receipt-bl929.sh [--validator <path>]
#   With no argument the subject is the repository's validator, and the copy is held byte-identical (cmp -s).
#   --validator names another copy (one of fixture-hygiene's H8 mutants); its stderr is passed through so the caller
#   can read the self-probe refusal, and PASS is printed only for the unmutated subject.
# Exit: 0 PASS, 1 FAIL, 2 the validator refused (its exit 2, passed through), 9 the receipt could not run.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE"
while [ "$ROOT" != "/" ] && [ ! -f "$ROOT/scripts/validate-fixture-hygiene.sh" ]; do ROOT="$(dirname "$ROOT")"; done
[ -f "$ROOT/scripts/validate-fixture-hygiene.sh" ] && [ -f "$ROOT/scripts/validate-fixture-invocations.sh" ] \
  || { echo "receipt-bl929: REFUSED -- no scripts/validate-fixture-hygiene.sh above $HERE" >&2; exit 9; }
SUBJ="$ROOT/scripts/validate-fixture-hygiene.sh"; REAL=1
case "${1:-}" in
  "") ;;
  --validator) [ -f "${2:-}" ] || { echo "receipt-bl929: REFUSED -- --validator names no file" >&2; exit 9; }; SUBJ="$2"; REAL=0 ;;
  *) echo "usage: receipt-bl929.sh [--validator <path>]" >&2; exit 9 ;;
esac
WORK="$(mktemp -d)" || { echo "receipt-bl929: REFUSED -- mktemp failed" >&2; exit 9; }
trap 'rm -rf "$WORK"' EXIT
W="$WORK/world"; F="$W/core/fixtures"
mkdir -p "$W/scripts" "$F/ra" "$F/rb" "$F/rc" "$F/rd" "$F/rz" && : > "$W/VERSION" \
  && cp -p "$SUBJ" "$W/scripts/validate-fixture-hygiene.sh" && cp -p "$ROOT/scripts/validate-fixture-invocations.sh" "$W/scripts/" \
  || { echo "receipt-bl929: REFUSED -- could not build the probe world" >&2; exit 9; }
if [ "$REAL" = 1 ]; then
  cmp -s "$SUBJ" "$W/scripts/validate-fixture-hygiene.sh" \
    || { echo "receipt-bl929: REFUSED -- the probe's validator is not byte-identical to $SUBJ" >&2; exit 9; }
fi
cat > "$F/ra/run.sh" <<'EOF'
#!/usr/bin/env bash
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
bash "$HERE/seed.sh"
EOF
# The stub is written by printf ARGUMENTS, never a heredoc: validate-fixture-invocations.sh --impl-of reads every
# fixture .sh line by line, and a column-0 `IMPL=` / `exec bash "$IMPL" --group` here would map fixture-hygiene
# ITSELF to the seed's IMPL (measured: H5 then refused fixture-hygiene's own MUTANT-MATRIX block as a stub's).
printf '%s\n' '#!/usr/bin/env bash' 'HERE="$(cd "$(dirname "$0")" && pwd)"' 'IMPL="$HERE/../ra/run.sh"' \
  'exec bash "$IMPL" --group b' > "$F/rb/run.sh"
printf '#!/usr/bin/env bash\nset -u\nbash "$HERE/seed.sh"\n' > "$F/rc/run.sh"
printf '#!/usr/bin/env bash\nset -u\necho listed\n' > "$F/rd/run.sh"
printf 'jq\n' > "$F/rz/tools.decl"
cat > "$F/rz/run.sh" <<'EOF'
#!/usr/bin/env bash
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
# MUTANT-MATRIX MR decides=A1 twins=B2
# MUTANT-MATRIX-REMEASURE bash core/fixtures/rz/run.sh --matrix
[ -d "$R/.git" ] || { echo "FIXTURE BROKEN: no history"; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "FIXTURE BROKEN: no jq"; exit 2; }
. "$HERE/../lib/mutant.sh" || { echo "FIXTURE BROKEN: cannot source lib/mutant.sh" >&2; exit 2; }
mkmut() { :; }
ok "A1 holds"
ok "B2 holds"
bash "$HERE/receipt-z.sh"
EOF
printf '#!/usr/bin/env bash\nexit 0\n' > "$F/rz/receipt-z.sh"
printf '# probe\nrd\tunscrubbed, listed\n' > "$W/scripts/env-scrub-allowlist.txt"
{ env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE -u GIT_OBJECT_DIRECTORY git -c core.hooksPath=/dev/null init -q "$W" \
  && env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE -u GIT_OBJECT_DIRECTORY git -C "$W" add -A core; } >/dev/null 2>&1 \
  || { echo "receipt-bl929: REFUSED -- could not index the probe world" >&2; exit 9; }

( cd "$W" && unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE && bash "$W/scripts/validate-fixture-hygiene.sh" ) > "$WORK/out" 2> "$WORK/err"
vrc=$?
cat "$WORK/err" >&2
[ "$vrc" = 2 ] && { echo "receipt-bl929: the validator REFUSED (exit 2)"; exit 2; }
f=0
no() { echo "receipt-bl929: FAIL -- $1"; f=1; }
[ "$vrc" = 1 ] || no "the validator exited $vrc over a world with one unscrubbed unlisted fixture, want 1"
grep -qF 'self-probe H8: ok' "$WORK/err" || no "no 'self-probe H8: ok' line"
grep -qF 'validate-fixture-hygiene: 6 fixture .sh scanned;' "$WORK/out" \
  || no "the corpus count is not the probe's 6 files, so the root walk did not resolve to the probe"
for x in ra rb rz; do grep -qxF "H8 SCRUBBED $x" "$WORK/out" || no "no 'H8 SCRUBBED $x' row"; done
for x in rc rd; do grep -qxF "H8 SCRUBBED $x" "$WORK/out" && no "the unscrubbed $x was read SCRUBBED"; done
grep -qF 'validate-fixture-hygiene: H8 3 fixture(s) SCRUBBED, 1 allowlisted unscrubbed' "$WORK/out" \
  || no "the H8 summary is not 3 SCRUBBED and 1 allowlisted (the listed rd must pass)"
nf="$(grep -c '^FAIL ' "$WORK/out")" || nf=0
[ "$nf" = 1 ] && grep -qx 'FAIL H8:' "$WORK/out" || no "want exactly one FAIL section, FAIL H8 (got $nf: $(grep '^FAIL ' "$WORK/out" | tr '\n' ' '))"
sec="$(awk '$0 == "FAIL H8:" { on = 1; next } on && /^    / { print; next } on { exit }' "$WORK/out")"
[ "$sec" = '    H8 rc: run.sh carries no env-derived AI_DLC_* unset loop on a code line' ] \
  || no "the H8 section is not exactly rc's row: $(printf '%s' "$sec" | tr '\n' '|')"
[ "$f" = 0 ] || exit 1
[ "$REAL" = 1 ] || { echo "receipt-bl929: held under a substituted validator (no PASS is printed for a copy)"; exit 0; }
echo "receipt-bl929: PASS"
exit 0
