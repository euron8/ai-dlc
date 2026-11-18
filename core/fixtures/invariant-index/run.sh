#!/usr/bin/env bash
# Exercise scripts/render-invariant-index.sh -- the renderer that derives docs/invariant-index.md
# from the arm headers in scripts/validate-enforcement-map.sh and byte-compares it at pre-push.
#
# One control, a near-miss and a refusal, each a copy of one seeded repo under a temp dir, plus one cli
# equivalence cell per distinct CLI outcome. Exit 0 iff every assertion is green.
#
#   controlB  a synthetic seed: render, then `--check`                -> must PASS
#   n1  group-prefix     two group headers sharing only a prefix      -> must PASS
#   r1  missing          the rendered index deleted, then `--check`   -> must FAIL (exit 1)
#
# IN PROCESS (BL-878). Every drive is inproc_run of the world's own renderer COPY, which defines rii_main and
# returns at its column-0 source guard; inproc_run sources it in a subshell made to look like a fresh
# `bash <copy>` and calls rii_main there, so `${BASH_SOURCE[0]}` names the copy and the root walk resolves the
# world, as the program does. The renderer runs as a program only in its three cli cells (cells.decl):
# cli-ok (exit 0, controlB --check), cli-missing (exit 1, r1 --check) and cli-usage (exit 2, --bogus), each
# compared byte for byte (stdout, stderr, exit) with the in-process run the assertion above it read.
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
note() { printf '%s\n' "$*"; }
# shellcheck source=/dev/null
. "$DIR/../lib/report.sh" || { echo "FIXTURE ERROR: lib/report.sh not found" >&2; exit 2; }
# shellcheck source=/dev/null
. "$DIR/../lib/inproc.sh" || { echo "FIXTURE BROKEN: cannot source lib/inproc.sh" >&2; exit 2; }
# THE WRAP IS THIS FIXTURE'S PRECONDITION. A renderer with neither half cannot be driven in process, and one
# with a single half is a respelled subject; either is FIXTURE BROKEN here (.dist-only: the subject is always
# present, so there is no consumer SKIP).
grep -q '^rii_main() {$' "$RENDERER"; g_def=$?
grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$RENDERER"; g_guard=$?
if [ "$g_def" != 0 ] || [ "$g_guard" != 0 ]; then
  echo "FIXTURE BROKEN: $RENDERER lacks the \`rii_main() {\` line (grep $g_def) or the column-0 source guard (grep $g_guard)" >&2
  exit 2
fi
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

# THE WORLDS ARE BUILT ONCE AND COPIED (fixture-mutants clause 4): the seed is written into $SEED a single time
# and every world below is a `cp -R` of it, so each world differs from the seed only by the edit it names.
SEED="$TMP/seed"
seed "$SEED"
world() { cp -R "$SEED" "$1" || { echo "FIXTURE BROKEN: cannot copy the seed to $1" >&2; exit 2; }; }

# THE IN-PROCESS DRIVE. drive <id> <world> [args...]: the world's renderer copy, in process, from cwd <world>;
# its stdout, stderr and exit land in $EQ/<id>.ip.{out,err,rc}, and DOUT/DRC carry the combined text and status
# the assertions read. A cli cell later compares its program run against these same three files.
EQ="$TMP/eq"; mkdir -p "$EQ"
DOUT=""; DRC=0
drive() {
  local id="$1" w="$2"; shift 2
  ( cd "$w" && inproc_run "$w/scripts/render-invariant-index.sh" rii_main "$@" ) \
    > "$EQ/$id.ip.out" 2> "$EQ/$id.ip.err"
  DRC=$?; echo "$DRC" > "$EQ/$id.ip.rc"
  DOUT="$(<"$EQ/$id.ip.out")"$'\n'"$(<"$EQ/$id.ip.err")"
}
# THE CLI CELL. eqv <id> <world> <want rc> [args...]: one `FXCELL=<id> bash <copy>` start, invoked by the same
# absolute path the in-process side sourced, from the same cwd, and compared byte for byte with drive <id>'s
# three files. Presence-shaped: the program's exit must also be the outcome the cell names.
eqv() {
  local id="$1" w="$2" want="$3"; shift 3
  [ -f "$EQ/$id.ip.rc" ] || { echo "FIXTURE BROKEN: cli cell $id has no in-process run to compare" >&2; exit 2; }
  ( cd "$w" && FXCELL="$id" bash "$w/scripts/render-invariant-index.sh" "$@" ) \
    > "$EQ/$id.cl.out" 2> "$EQ/$id.cl.err"
  echo "$?" > "$EQ/$id.cl.rc"
  if [ "$(<"$EQ/$id.cl.rc")" = "$want" ] && cmp -s "$EQ/$id.ip.rc" "$EQ/$id.cl.rc" \
     && cmp -s "$EQ/$id.ip.out" "$EQ/$id.cl.out" && cmp -s "$EQ/$id.ip.err" "$EQ/$id.cl.err"; then
    ok "$id -- the program and the in-process call agree byte for byte (stdout, stderr, exit $want)"
  else
    bad "$id -- program vs in-process differ, or exit is not $want (rc $(<"$EQ/$id.cl.rc") vs $(<"$EQ/$id.ip.rc"))"
    diff "$EQ/$id.ip.out" "$EQ/$id.cl.out" | sed 's/^/      /' | head -5
    diff "$EQ/$id.ip.err" "$EQ/$id.cl.err" | sed 's/^/      /' | head -5
  fi
}

# --- controlB: a synthetic seed renders and round-trips ----------------------
world "$TMP/controlB"
drive render-B "$TMP/controlB"; outB="$DOUT"
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
drive cli-ok "$TMP/controlB" --check
if [ "$DRC" = 0 ] && grep -q "in sync" <<<"$DOUT"; then
  ok "CONTROL-B -- synthetic seed renders, round-trips, and the solo arm wins"
else
  note "FIXTURE BROKEN: a freshly rendered index did not survive its own --check."
  printf '%s\n' "$DOUT" | sed 's/^/      /' | head -6
  exit 1
fi

# n1 -- two group headers sharing only a PREFIX (I3 and I30) are not a collision and must render.
world "$TMP/n1"
printf '# --- I30 / I4: a second overview, a prefix neighbour ---\n[ -n "${z:-}" ] && err "second overview"\n' \
  >> "$TMP/n1/scripts/validate-enforcement-map.sh"
drive render-n1 "$TMP/n1"
if [ "$DRC" = 0 ] && grep -q "5 invariant(s) across 4 arm(s)" <<<"$DOUT" \
   && grep -qF "| I30 | a second overview, a prefix neighbour |" "$TMP/n1/docs/invariant-index.md"; then
  ok "n1 group-prefix  two overviews sharing a prefix render"
else
  bad "n1 group-prefix  a prefix neighbour was refused or did not render"
  printf '%s\n' "$DOUT" | sed 's/^/      /' | head -5
fi

# r1 -- the seed never rendered: `--check` must refuse on the missing index, exit 1, and write nothing.
world "$TMP/r1"
drive cli-missing "$TMP/r1" --check
if [ "$DRC" = 1 ] && grep -qF "$TMP/r1/docs/invariant-index.md does not exist" <<<"$DOUT" \
   && [ ! -e "$TMP/r1/docs/invariant-index.md" ]; then
  ok "r1 missing  --check refuses an absent index (exit 1) and names it"
else
  bad "r1 missing  --check on an absent index exited $DRC or did not name the index"
  printf '%s\n' "$DOUT" | sed 's/^/      /' | head -5
fi

# The usage refusal, in process: exit 2 and the usage line naming the renderer by its own file name.
drive cli-usage "$TMP/controlB" --bogus
if [ "$DRC" = 2 ] && grep -qF "usage: render-invariant-index.sh [--check|--arm-lines" <<<"$DOUT"; then
  ok "usage  an unknown flag refuses with exit 2 and the usage line"
else
  bad "usage  an unknown flag exited $DRC or printed no usage line"
  printf '%s\n' "$DOUT" | sed 's/^/      /' | head -3
fi

# --- the cli cells: one program run per distinct CLI outcome ------------------
eqv cli-ok      "$TMP/controlB" 0 --check
eqv cli-missing "$TMP/r1"       1 --check
eqv cli-usage   "$TMP/controlB" 2 --bogus

report_end invariant-index 7
