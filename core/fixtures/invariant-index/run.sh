#!/usr/bin/env bash
# Exercise scripts/render-invariant-index.sh -- the renderer that derives docs/invariant-index.md
# from the arm headers in scripts/validate-enforcement-map.sh and byte-compares it at pre-push.
#
# Two controls plus six mutants, each a throwaway repo under a temp dir.
# Exit 0 iff both controls are green AND all six mutants are killed by their own arm.
#
#   controlA  the REAL repo: `--check` against the committed index   -> must PASS
#   controlB  a synthetic seed: render, then `--check`                -> must PASS
#   m1  drift      a byte appended to the rendered index             -> must FAIL
#   m2  missing    the index deleted                                 -> must FAIL
#   m3  orphan     an `err` call sitting outside every declared arm   -> must FAIL
#   m4  silent     a declared arm containing no emitter               -> must FAIL
#   m5  collision  one ID claimed by two solo arm headers             -> must FAIL
#   m6  zero-arms  a source the header grammar cannot parse at all    -> must FAIL
#
# WHY THIS FIXTURE IS THE ONLY EVIDENCE THE RENDERER WORKS. Its finding set over the real
# tree is EMPTY by design -- a green `--check` is the steady state, and a renderer that
# silently stopped parsing would produce exactly that same green line. Every arm here exists
# to prove one specific way the thing can still fail.
#
# WHY TWO CONTROLS AND NOT ONE. controlB proves the synthetic seed is well-formed, so a
# mutant's FAIL is attributable to the mutation rather than to a seed that never rendered.
# controlA proves the shipping path -- the real 6,000-line validator, the real committed
# index -- because a fixture that only ever sees a four-arm toy source would keep passing
# after the grammar stopped matching anything in the file it actually guards.
#
# WHY `cmp -s` GUARDS EVERY sed. A sed whose pattern stopped matching produces a
# byte-identical copy; the renderer then correctly passes and the arm reports SURVIVED for a
# mutation that never happened. The guard turns that into an explicit failure.
#
# A mutant must fail ONLY its own assertion, so each verdict asserts the expected message
# rather than merely a non-zero exit -- "it failed" is satisfied by a broken harness too.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"

# BOTH LAYOUTS NAMED, never a single walk-up (I33c). In this repo the fixture sits at
# core/fixtures/<name>/; the consumer layout puts it at tests/fixtures/<name>/. This unit is
# .dist-only and only ever runs here, but a resolver that names one layout is the shape the
# invariant forbids, and a fixture is not the place to make an exception to it.
RENDERER=""; REPO=""
for cand in "$DIR/../../.." "$DIR/../.."; do
  if [ -f "$cand/scripts/render-invariant-index.sh" ] && [ -f "$cand/VERSION" ]; then
    REPO="$(cd "$cand" && pwd)"; RENDERER="$REPO/scripts/render-invariant-index.sh"; break
  fi
done
if [ -z "$RENDERER" ]; then
  echo "run.sh: could not locate scripts/render-invariant-index.sh from $DIR" >&2
  exit 2
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
rc=0
note() { printf '%s\n' "$*"; }

# The synthetic source. Three arms declaring three invariants: a solo arm, an OVERVIEW header
# declaring two, and one of those two carrying its own solo arm below it. That last pair is
# the case that must NOT score as a collision, and it is the shape the real file has at
# `# --- I36/I37/I38: ... ---` with I37's own arm underneath.
seed() {
  local d="$1"
  mkdir -p "$d/scripts" "$d/docs"
  echo "0.0.0" > "$d/VERSION"
  cp "$RENDERER" "$d/scripts/render-invariant-index.sh"
  cat > "$d/scripts/validate-enforcement-map.sh" <<'EOF'
#!/usr/bin/env bash
err() { echo "FAIL: $*" >&2; fail=1; }
# --- I1: the catalog join ----------------------------------------------------
[ -n "${a:-}" ] && err "I1 fired"
# --- I2 / I3: the overview above two sub-arms --------------------------------
[ -n "${b:-}" ] && err "overview fired"
# --- I3: its own arm ---------------------------------------------------------
[ -n "${c:-}" ] && err "I3 fired"
EOF
}

render_in() { ( cd "$1" && bash scripts/render-invariant-index.sh 2>&1 ); }
check_in()  { ( cd "$1" && bash scripts/render-invariant-index.sh --check 2>&1 ); }

# --- controlA: the real repo ------------------------------------------------
if outA="$( cd "$REPO" && bash scripts/render-invariant-index.sh --check 2>&1 )" \
   && grep -q "^OK: docs/invariant-index.md in sync" <<<"$outA"; then
  note "ok    controlA -- the committed index matches the real validator's arm headers"
else
  note "FIXTURE BROKEN: --check does not pass against the real repo. Every verdict below is meaningless."
  printf '%s\n' "$outA" | sed 's/^/      /' | head -8
  exit 1
fi

# --- controlB: a synthetic seed renders and round-trips ----------------------
seed "$TMP/controlB"
outB="$(render_in "$TMP/controlB")"
if grep -q "3 invariant(s) across 3 arm(s)" <<<"$outB" && \
   grep -q "0 orphaned, 0 silent" <<<"$outB"; then
  :
else
  note "FIXTURE BROKEN: the synthetic seed did not render 3 invariants across 3 arms."
  printf '%s\n' "$outB" | sed 's/^/      /' | head -6
  exit 1
fi
# THE OVERVIEW MUST LOSE TO THE SOLO ARM. If this ever inverts, m5 stops distinguishing a
# real ID collision from an ordinary sub-arm and the collision verdict becomes noise.
if ! grep -qF "| I3 | its own arm |" "$TMP/controlB/docs/invariant-index.md"; then
  note "FIXTURE BROKEN: I3's solo arm description did not win over the overview's."
  grep '^| I' "$TMP/controlB/docs/invariant-index.md" | sed 's/^/      /'
  exit 1
fi
if outB2="$(check_in "$TMP/controlB")" && grep -q "in sync" <<<"$outB2"; then
  note "ok    controlB -- synthetic seed renders, round-trips, and the solo arm wins"
else
  note "FIXTURE BROKEN: a freshly rendered index did not survive its own --check."
  printf '%s\n' "$outB2" | sed 's/^/      /' | head -6
  exit 1
fi

# --- mutant driver ----------------------------------------------------------
kill_check() { # kill_check <name> <dir> <expected-substring> [check|render]
  local n="$1" d="$2" pat="$3" mode="${4:-check}" out rc_v
  if [ "$mode" = render ]; then out="$(render_in "$d")"; else out="$(check_in "$d")"; fi
  rc_v=$?
  if [ "$rc_v" -eq 0 ]; then
    note "FAIL  $n -- mutant SURVIVED (renderer exited 0)"; rc=1; return
  fi
  if ! grep -qF "$pat" <<<"$out"; then
    note "FAIL  $n -- renderer failed, but not on its own assertion (wanted: $pat)"
    printf '%s\n' "$out" | sed 's/^/      /' | head -5; rc=1; return
  fi
  note "ok    $n -- killed by its own arm"
}

mutate() { # mutate <file> <sed-expr> ; guarded so a no-op sed cannot pass as a mutation
  local f="$1" expr="$2"
  cp "$f" "$f.orig"
  sed "$expr" "$f.orig" > "$f"
  if cmp -s "$f" "$f.orig"; then rm -f "$f.orig"; return 1; fi
  rm -f "$f.orig"; return 0
}

# m1 -- a stale index
seed "$TMP/m1"; render_in "$TMP/m1" >/dev/null
printf '| I999 | a row nobody rendered |\n' >> "$TMP/m1/docs/invariant-index.md"
kill_check "m1 drift      stale index" "$TMP/m1" "docs/invariant-index.md is STALE"

# m2 -- no index at all
seed "$TMP/m2"; render_in "$TMP/m2" >/dev/null
rm -f "$TMP/m2/docs/invariant-index.md"
kill_check "m2 missing    index absent" "$TMP/m2" "does not exist"

# m3 -- an emitter outside every arm
seed "$TMP/m3"
printf 'err "a finding belonging to no declared invariant"\n' >> "$TMP/m3/scripts/validate-enforcement-map.sh"
mv "$TMP/m3/scripts/validate-enforcement-map.sh" "$TMP/m3/v.tmp"
{ printf '#!/usr/bin/env bash\nerr "loose finding before any arm"\n'; tail -n +2 "$TMP/m3/v.tmp"; } \
  > "$TMP/m3/scripts/validate-enforcement-map.sh"
rm -f "$TMP/m3/v.tmp"
kill_check "m3 orphan     emitter outside every arm" "$TMP/m3" "sit outside every declared arm" render

# m4 -- a declared arm that cannot emit
seed "$TMP/m4"
printf '# --- I9: an arm with no emitter at all ---\nx=1\n' >> "$TMP/m4/scripts/validate-enforcement-map.sh"
kill_check "m4 silent     arm with no emitter" "$TMP/m4" "contain no err/warn/fail call" render

# m5 -- one ID, two solo arms
seed "$TMP/m5"
printf '# --- I1: a second arm claiming the same ID ---\n[ -n "${z:-}" ] && err "second I1"\n' \
  >> "$TMP/m5/scripts/validate-enforcement-map.sh"
kill_check "m5 collision  one ID, two solo arms" "$TMP/m5" "claimed by more than one arm" render

# m6 -- the grammar parses nothing
seed "$TMP/m6"
if mutate "$TMP/m6/scripts/validate-enforcement-map.sh" 's|^# --- |# === |'; then
  kill_check "m6 zero-arms  header grammar matches nothing" "$TMP/m6" "parsed ZERO arm headers" render
else
  note "SKIP  m6 -- sed matched nothing; no mutation occurred"; rc=1
fi

if [ "$rc" -eq 0 ]; then
  note "PASS  invariant-index -- 2 controls green, 6/6 mutants killed by their own arm"
fi
exit "$rc"
