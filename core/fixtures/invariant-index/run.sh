#!/usr/bin/env bash
# Exercise scripts/render-invariant-index.sh -- the renderer that derives docs/invariant-index.md
# from the arm headers in scripts/validate-enforcement-map.sh and byte-compares it at pre-push.
#
# One control and a near-miss, each a throwaway repo under a temp dir. Exit 0 iff both are green.
#
#   controlB  a synthetic seed: render, then `--check`                -> must PASS
#   n1  group-prefix     two group headers sharing only a prefix      -> must PASS
#
# WHY THIS FIXTURE IS THE ONLY EVIDENCE THE RENDERER WORKS. Its finding set over the real
# tree is EMPTY by design -- a green `--check` is the steady state, and a renderer that
# silently stopped parsing would produce exactly that same green line. Every arm here exists
# to prove one specific way the thing can still fail.
#
# WHY ONE CONTROL. controlB proves the synthetic seed is well-formed, so a later failure is attributable to
# the renderer rather than to a seed that never rendered. The real tree's `--check` is not repeated here: the
# pre-push hook runs `scripts/render-invariant-index.sh --check` itself before the suite starts.
#
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
# The renderer is located and about to be driven; inputs.decl marks it REQUIRED.
echo "HERMETIC-CONSUMED scripts/render-invariant-index.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
rc=0
note() { printf '%s\n' "$*"; }
# ok/bad: bad sets rc, the variable this script exits on.
ok()  { note "ok    $1"; }
bad() { note "FAIL  $1"; rc=1; }
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
# THE OVERVIEW MUST LOSE TO THE SOLO ARM. If this ever inverts, the collision check stops distinguishing a
# real ID collision from an ordinary sub-arm and the collision verdict becomes noise.
if ! grep -qF "| I3 | its own arm |" "$TMP/controlB/docs/invariant-index.md"; then
  note "FIXTURE BROKEN: I3's solo arm description did not win over the overview's."
  grep '^| I' "$TMP/controlB/docs/invariant-index.md" | sed 's/^/      /'
  exit 1
fi
if outB2="$(check_in "$TMP/controlB")" && grep -q "in sync" <<<"$outB2"; then
  ok "CONTROL-B -- synthetic seed renders, round-trips, and the solo arm wins"; B_ctlB=1
else
  note "FIXTURE BROKEN: a freshly rendered index did not survive its own --check."
  printf '%s\n' "$outB2" | sed 's/^/      /' | head -6
  exit 1
fi

# n1 -- two group headers sharing only a PREFIX (I3 and I30) are not a collision and must render.
seed "$TMP/n1"
printf '# --- I30 / I4: a second overview, a prefix neighbour ---\n[ -n "${z:-}" ] && err "second overview"\n' \
  >> "$TMP/n1/scripts/validate-enforcement-map.sh"
if outN="$(render_in "$TMP/n1")" && grep -q "5 invariant(s) across 4 arm(s)" <<<"$outN" \
   && grep -qF "| I30 | a second overview, a prefix neighbour |" "$TMP/n1/docs/invariant-index.md"; then
  note "ok    n1 group-prefix  two overviews sharing a prefix render"
else
  note "FAIL  n1 group-prefix  a prefix neighbour was refused or did not render"
  printf '%s\n' "$outN" | sed 's/^/      /' | head -5; rc=1
fi

if [ "$rc" -eq 0 ]; then
  note "PASS  invariant-index -- 1 control + 1 near-miss green"
fi
exit "$rc"
