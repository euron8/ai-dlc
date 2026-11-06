#!/usr/bin/env bash
# receipt-bl930.sh -- BL-930's receipt, and fixture-hygiene's arm D9 (run.sh invokes this file and reads its exit and
# its PASS line; it carries no second copy of this logic).
#
# BL-930 retired I10 (validate-enforcement-map.sh), which acquitted a hook-driving fixture on ANY `unset "$_v"` loop,
# so a loop over GIT_* alone passed it (hermetic-runner, census-hermetic-coverage). H8 holds that population now. This
# receipt seeds the shapes I10 judged and drives the shipping validator over them:
#   gk  drives a hook, and its only loop unsets GIT_* -- the shape I10 acquitted. Want: FAIL H8 naming gk.
#   ga  drives a hook and scrubs AI_DLC_* (the near-miss: the identical loop over the other prefix). Want: SCRUBBED.
#   gl  drives a hook from its lib.sh, unscrubbed, and is a row of the allowlist -- I10 flagged it, so H8 must too: the
#       list never acquits a hook driver. Want: FAIL H8 naming gl.
#   gz  scrubbed, carrying the populations the validator requires (H1, H2, H6, H5, E1).
# usage:  receipt-bl930.sh [--validator <path>]   (as receipt-bl929.sh: a copy's stderr passes through, no PASS)
# Exit: 0 PASS, 1 FAIL, 2 the validator refused (its exit 2, passed through), 9 the receipt could not run.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE"
while [ "$ROOT" != "/" ] && [ ! -f "$ROOT/scripts/validate-fixture-hygiene.sh" ]; do ROOT="$(dirname "$ROOT")"; done
[ -f "$ROOT/scripts/validate-fixture-hygiene.sh" ] && [ -f "$ROOT/scripts/validate-fixture-invocations.sh" ] \
  || { echo "receipt-bl930: REFUSED -- no scripts/validate-fixture-hygiene.sh above $HERE" >&2; exit 9; }
SUBJ="$ROOT/scripts/validate-fixture-hygiene.sh"; REAL=1
case "${1:-}" in
  "") ;;
  --validator) [ -f "${2:-}" ] || { echo "receipt-bl930: REFUSED -- --validator names no file" >&2; exit 9; }; SUBJ="$2"; REAL=0 ;;
  *) echo "usage: receipt-bl930.sh [--validator <path>]" >&2; exit 9 ;;
esac
WORK="$(mktemp -d)" || { echo "receipt-bl930: REFUSED -- mktemp failed" >&2; exit 9; }
trap 'rm -rf "$WORK"' EXIT
W="$WORK/world"; F="$W/core/fixtures"
mkdir -p "$W/scripts" "$F/gk" "$F/ga" "$F/gl" "$F/gz" && : > "$W/VERSION" \
  && cp -p "$SUBJ" "$W/scripts/validate-fixture-hygiene.sh" && cp -p "$ROOT/scripts/validate-fixture-invocations.sh" "$W/scripts/" \
  || { echo "receipt-bl930: REFUSED -- could not build the probe world" >&2; exit 9; }
[ "$REAL" = 0 ] || cmp -s "$SUBJ" "$W/scripts/validate-fixture-hygiene.sh" \
  || { echo "receipt-bl930: REFUSED -- the probe's validator is not byte-identical to $SUBJ" >&2; exit 9; }
cat > "$F/gk/run.sh" <<'EOF'
#!/usr/bin/env bash
set -uo pipefail
for _v in $(env | sed -n 's/^\(GIT_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
bash "$ROOT/core/hooks/ai-dlc-x.sh" </dev/null
EOF
cat > "$F/ga/run.sh" <<'EOF'
#!/usr/bin/env bash
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
bash "$ROOT/core/hooks/ai-dlc-x.sh" </dev/null
EOF
printf '#!/usr/bin/env bash\n. "$HERE/lib.sh"\n' > "$F/gl/run.sh"
printf 'bash "$HOOK" </dev/null\n' > "$F/gl/lib.sh"
printf 'jq\n' > "$F/gz/tools.decl"
cat > "$F/gz/run.sh" <<'EOF'
#!/usr/bin/env bash
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
# MUTANT-MATRIX MR decides=A1 twins=B2
# MUTANT-MATRIX-REMEASURE bash core/fixtures/gz/run.sh --matrix
[ -d "$R/.git" ] || { echo "FIXTURE BROKEN: no history"; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "FIXTURE BROKEN: no jq"; exit 2; }
. "$HERE/../lib/mutant.sh" || { echo "FIXTURE BROKEN: cannot source lib/mutant.sh" >&2; exit 2; }
mkmut() { :; }
ok "A1 holds"
ok "B2 holds"
bash "$HERE/receipt-z.sh"
EOF
printf '#!/usr/bin/env bash\nexit 0\n' > "$F/gz/receipt-z.sh"
printf '# probe\ngl\tunscrubbed, listed, drives a hook\n' > "$W/scripts/env-scrub-allowlist.txt"
{ env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE -u GIT_OBJECT_DIRECTORY git -c core.hooksPath=/dev/null init -q "$W" \
  && env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE -u GIT_OBJECT_DIRECTORY git -C "$W" add -A core; } >/dev/null 2>&1 \
  || { echo "receipt-bl930: REFUSED -- could not index the probe world" >&2; exit 9; }

( cd "$W" && unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE && bash "$W/scripts/validate-fixture-hygiene.sh" ) > "$WORK/out" 2> "$WORK/err"
vrc=$?
cat "$WORK/err" >&2
[ "$vrc" = 2 ] && { echo "receipt-bl930: the validator REFUSED (exit 2)"; exit 2; }
f=0
no() { echo "receipt-bl930: FAIL -- $1"; f=1; }
[ "$vrc" = 1 ] || no "the validator exited $vrc, want 1"
grep -qF 'validate-fixture-hygiene: 6 fixture .sh scanned;' "$WORK/out" \
  || no "the corpus count is not the probe's 6 files, so the root walk did not resolve to the probe"
grep -qxF 'H8 SCRUBBED ga' "$WORK/out" || no "the AI_DLC_* loop near-miss ga was not read SCRUBBED"
grep -qxF 'H8 SCRUBBED gk' "$WORK/out" && no "the GIT_-only loop gk was read SCRUBBED, the shape I10 acquitted"
sec="$(awk '$0 == "FAIL H8:" { on = 1; next } on && /^    / { print; next } on { exit }' "$WORK/out")"
want="$(printf '%s\n' '    H8 gk: run.sh carries no env-derived AI_DLC_* unset loop on a code line' \
  '    H8 gl: allowlisted, but it drives a hook (core/fixtures/gl/lib.sh:1), and a hook-driving fixture is never acquitted by the list')"
[ "$sec" = "$want" ] || no "the H8 section is not exactly gk's and gl's rows: $(printf '%s' "$sec" | tr '\n' '|')"
nf="$(grep -c '^FAIL ' "$WORK/out")" || nf=0
[ "$nf" = 1 ] || no "want exactly one FAIL section, FAIL H8 (got $nf)"
[ "$f" = 0 ] || exit 1
[ "$REAL" = 1 ] || { echo "receipt-bl930: held under a substituted validator (no PASS is printed for a copy)"; exit 0; }
echo "receipt-bl930: PASS"
exit 0
