#!/usr/bin/env bash
# Exercise scripts/render-invariant-index.sh -- the renderer that derives docs/invariant-index.md
# from the arm headers in scripts/validate-enforcement-map.sh and byte-compares it at pre-push.
#
# Two controls, a near-miss and seven mutants, each a throwaway repo under a temp dir.
# Exit 0 iff every control is green AND every mutant is killed by its own arm.
#
#   controlA  the REAL repo: `--check` against the committed index   -> must PASS
#   controlB  a synthetic seed: render, then `--check`                -> must PASS
#   m1  drift      a byte appended to the rendered index             -> must FAIL
#   m2  missing    the index deleted                                 -> must FAIL
#   m3  orphan     an `err` call sitting outside every declared arm   -> must FAIL
#   m4  silent     a declared arm containing no emitter               -> must FAIL
#   m5  collision  one ID claimed by two solo arm headers             -> must FAIL
#   m6  zero-arms  a source the header grammar cannot parse at all    -> must FAIL
#   m7  group-collision  one ID claimed by two GROUP headers          -> must FAIL
#   n1  group-prefix     two group headers sharing only a prefix      -> must PASS
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
#
# THE MUTANT MATRIX (mutant-battery rule). The six arms are the six distinct expected messages (drift, missing,
# orphan, silent, collision, zero-arms); m5 and m7 both print the collision message, so they share that one arm.
# Every mutant could be read through every arm. PER PUSH a
# mutant is read through its DECIDING arm and its named TWIN only; with --matrix it is read through all six and
# prints one `MATRIX <mutant> <arm> KILLED|GREEN` row per pair. The block below is the one source: a plain run
# refuses a mutant with no row, and a cell that disagrees with its row is a failure. An arm reads the mutant tree
# in its own mode (a copy of the tree, so one reading never alters another) and is KILLED when the renderer exits
# non-zero AND prints the arm's message.
# RE-MEASURE whenever an arm or a mutant is added or changed. hermetic-run.sh runs a fixture under `env -i` and
# forwards no argument, so the matrix is NOT reached through it; run.sh is invoked directly from the repo root.
# MUTANT-MATRIX-REMEASURE bash core/fixtures/invariant-index/run.sh --matrix
# MUTANT-MATRIX m1 decides=drift twins=missing
# MUTANT-MATRIX m2 decides=missing twins=drift
# MUTANT-MATRIX m3 decides=orphan twins=silent
# MUTANT-MATRIX m4 decides=silent twins=orphan
# MUTANT-MATRIX m5 decides=collision twins=zero-arms
# MUTANT-MATRIX m6 decides=zero-arms twins=orphan
# MUTANT-MATRIX m7 decides=collision twins=zero-arms
# A MATRIX row is a measurement and not a second kill emission: its kill goes through mutant_killed behind the
# same base-pass flag as the original. The mutant name reaches mutant_killed as a variable:
# MUTANT-MATRIX-DYNAMIC mx_cell why=reads the mutant names m1 to m7 as a variable and every name keeps its own row
# MUTANT-MATRIX-CONTROL CONTROL-A why=the real repo's committed index must pass --check before any mutant is read
# MUTANT-MATRIX-CONTROL CONTROL-B why=the synthetic seed must render and round-trip so a mutant's failure is attributable to the mutation
set -u
MATRIX=0
for _a in "$@"; do
  case "$_a" in
    --matrix) MATRIX=1 ;;
    *) echo "FIXTURE ERROR: unknown argument '$_a' (only --matrix)" >&2; exit 2 ;;
  esac
done
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
# ok/bad exist for lib/mutant.sh, which reports through them: bad sets rc, the variable this script exits on.
ok()  { note "ok    $1"; }
bad() { note "FAIL  $1"; rc=1; }
MUT_LIB="$(cd "$DIR/../lib" 2>/dev/null && pwd)/mutant.sh"
[ -f "$MUT_LIB" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $DIR" >&2; exit 2; }
. "$MUT_LIB"
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"

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
  note "ok    CONTROL-A -- the committed index matches the real validator's arm headers"
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
  ok "CONTROL-B -- synthetic seed renders, round-trips, and the solo arm wins"; B_ctlB=1
else
  note "FIXTURE BROKEN: a freshly rendered index did not survive its own --check."
  printf '%s\n' "$outB2" | sed 's/^/      /' | head -6
  exit 1
fi

# --- mutant driver ----------------------------------------------------------
MX_SRC="$DIR/run.sh"; MX_RUN=0; MX_OFFSUBSET=0; MX_SEEN=""
mx_role() { # <mutant> <arm> -> D (decides), T (twin) or - (neither), read from the header block
  awk -v m="$1" -v t="$2" '
    $1 == "#" && $2 == "MUTANT-MATRIX" && $3 == m {
      for (i = 4; i <= NF; i++) {
        split($i, kv, "="); if (kv[1] != "decides" && kv[1] != "twins") continue
        n = split(kv[2], a, ",")
        for (j = 1; j <= n; j++) if (a[j] == t) { print (kv[1] == "decides" ? "D" : "T"); found = 1; exit }
      }
    }
    END { if (!found) print "-" }' "$MX_SRC"
}
mx_has_row() { awk -v m="$1" '$1 == "#" && $2 == "MUTANT-MATRIX" && $3 == m && $4 ~ /^decides=/ { f = 1 } END { exit f ? 0 : 1 }' "$MX_SRC"; }
# The arms: <arm> <mode> <message the renderer must print>. An arm reads a COPY of the mutant tree in its own mode.
ARM_LIST="drift missing orphan silent collision zero-arms"
arm_mode() { case "$1" in drift|missing) echo check ;; *) echo render ;; esac; }
arm_msg() {
  case "$1" in
    drift) echo "docs/invariant-index.md is STALE" ;;
    missing) echo "does not exist" ;;
    orphan) echo "sit outside every declared arm" ;;
    silent) echo "contain no err/warn/fail call" ;;
    collision) echo "claimed by more than one arm" ;;
    zero-arms) echo "parsed ZERO arm headers" ;;
  esac
}
# mx_read <mutant> <dir> <arm> -> 0 when the arm KILLS the mutant (exit non-zero AND its own message), else 1.
# THE SUBJECT RUNS ONCE PER (MUTANT, MODE), NOT ONCE PER ARM. The six arms read only two distinct states of a mutant
# tree: `--check` (drift, missing) and a render (orphan, silent, collision, zero-arms), and the arms of one mode differ
# only in which message they grep. The output of each mode is cached per mutant. `--check` writes nothing under the tree
# (it renders to a temp and compares), so it reads the mutant tree itself; a render WRITES docs/invariant-index.md, so
# it reads one private copy, and a later check of the same mutant therefore still sees the tree as built.
mx_read() {
  local m="$1" d="$2" a="$3" mode out rc_v
  mode="$(arm_mode "$a")"
  if [ ! -f "$TMP/out.$m.$mode" ]; then
    if [ "$mode" = render ]; then
      [ -d "$d.render" ] || cp -R "$d" "$d.render"
      out="$(render_in "$d.render")"; rc_v=$?
    else
      out="$(check_in "$d")"; rc_v=$?
    fi
    printf '%s' "$out" > "$TMP/out.$m.$mode"; printf '%s' "$rc_v" > "$TMP/rc.$m.$mode"
  fi
  rc_v="$(cat "$TMP/rc.$m.$mode")"; out="$(cat "$TMP/out.$m.$mode")"
  [ "$rc_v" -ne 0 ] && grep -qF "$(arm_msg "$a")" <<<"$out"
}
# mx_cell <mutant> <dir> <arm> <base-pass flag>
mx_cell() {
  local m="$1" d="$2" t="$3" fl="$4" role
  role="$(mx_role "$m" "$t")"
  if [ "$MATRIX" != 1 ] && [ "$role" = - ]; then return 0; fi
  [ "$role" = - ] && MX_OFFSUBSET=$((MX_OFFSUBSET + 1))
  MX_RUN=$((MX_RUN + 1))
  if mx_read "$m" "$d" "$t"; then
    mutant_killed "$fl" "$m" "MATRIX $m $t KILLED"
    if [ "$MATRIX" != 1 ] && [ "$role" = T ]; then bad "$m failed arm $t, which the header names as its twin"; fi
  else
    ok "MATRIX $m $t GREEN"
    if [ "$MATRIX" != 1 ] && [ "$role" = D ]; then bad "$m SURVIVED its deciding arm $t -- the renderer did not fail on its own assertion"; fi
  fi
}
kill_check() { # kill_check <name> <dir> <deciding arm> <base-pass flag>
  local n="${1%% *}" d="$2" a
  case " $MX_SEEN " in
    *" $n "*) ;;
    *) MX_SEEN="$MX_SEEN $n"
       if [ "$MATRIX" != 1 ] && ! mx_has_row "$n"; then
         bad "$n has no MUTANT-MATRIX row in $MX_SRC -- a per-push run cannot know its deciding arm or its twins"
       fi ;;
  esac
  for a in $ARM_LIST; do mx_cell "$n" "$d" "$a" "$4"; done
}

mutate() { # mutate <file> <sed-expr> ; guarded so a no-op sed cannot pass as a mutation
  local f="$1" expr="$2"
  cp "$f" "$f.orig"
  sed "$expr" "$f.orig" > "$f"
  if cmp -s "$f" "$f.orig"; then rm -f "$f.orig"; return 1; fi
  rm -f "$f.orig"; return 0
}

# m1 -- a stale index. controlB, m1 and m2 are the SAME world (seed, then render), so it is built once above and copied.
cp -R "$TMP/controlB" "$TMP/m1"
printf '| I999 | a row nobody rendered |\n' >> "$TMP/m1/docs/invariant-index.md"
kill_check "m1 drift      stale index" "$TMP/m1" drift "${B_ctlB:-0}"

# m2 -- no index at all (the controlB world again, copied)
cp -R "$TMP/controlB" "$TMP/m2"
rm -f "$TMP/m2/docs/invariant-index.md"
kill_check "m2 missing    index absent" "$TMP/m2" missing "${B_ctlB:-0}"

# m3 -- an emitter outside every arm
seed "$TMP/m3"
printf 'err "a finding belonging to no declared invariant"\n' >> "$TMP/m3/scripts/validate-enforcement-map.sh"
mv "$TMP/m3/scripts/validate-enforcement-map.sh" "$TMP/m3/v.tmp"
{ printf '#!/usr/bin/env bash\nerr "loose finding before any arm"\n'; tail -n +2 "$TMP/m3/v.tmp"; } \
  > "$TMP/m3/scripts/validate-enforcement-map.sh"
rm -f "$TMP/m3/v.tmp"
kill_check "m3 orphan     emitter outside every arm" "$TMP/m3" orphan "${B_ctlB:-0}"

# m4 -- a declared arm that cannot emit
seed "$TMP/m4"
printf '# --- I9: an arm with no emitter at all ---\nx=1\n' >> "$TMP/m4/scripts/validate-enforcement-map.sh"
kill_check "m4 silent     arm with no emitter" "$TMP/m4" silent "${B_ctlB:-0}"

# m5 -- one ID, two solo arms
seed "$TMP/m5"
printf '# --- I1: a second arm claiming the same ID ---\n[ -n "${z:-}" ] && err "second I1"\n' \
  >> "$TMP/m5/scripts/validate-enforcement-map.sh"
kill_check "m5 collision  one ID, two solo arms" "$TMP/m5" collision "${B_ctlB:-0}"

# m7 -- one ID, two GROUP headers. The group path was first-wins and silent: the second
# header's description was dropped at exit 0. I3 is shared by the seed's own overview and a
# second overview appended here, so the seed's solo I3 arm is also present -- the refusal must
# fire on the group count, not only when no solo arm exists.
seed "$TMP/m7"
printf '# --- I3 / I4: a second overview claiming I3 ---\n[ -n "${z:-}" ] && err "second overview"\n' \
  >> "$TMP/m7/scripts/validate-enforcement-map.sh"
kill_check "m7 group-collision one ID, two group headers" "$TMP/m7" collision "${B_ctlB:-0}"

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

# m6 -- the grammar parses nothing
seed "$TMP/m6"
if mutate "$TMP/m6/scripts/validate-enforcement-map.sh" 's|^# --- |# === |'; then
  kill_check "m6 zero-arms  header grammar matches nothing" "$TMP/m6" zero-arms "${B_ctlB:-0}"
else
  note "SKIP  m6 -- sed matched nothing; no mutation occurred"; rc=1
fi

# MX0: a plain run executes no matrix-only cell; --matrix scores every cell and says how many.
if [ "$MATRIX" = 1 ]; then
  echo "MATRIX MODE: $MX_RUN cells"
  if [ "$MX_RUN" -gt 0 ]; then ok "MX0 matrix mode: $MX_RUN cells scored"; else bad "MX0 matrix mode: --matrix scored no cell"; fi
elif [ "$MX_OFFSUBSET" -eq 0 ]; then ok "MX0 per-push run: matrix-only cells run = 0 (cells scored: $MX_RUN)"
else bad "MX0 per-push run: $MX_OFFSUBSET matrix-only cell(s) ran"; fi

if [ "$rc" -eq 0 ]; then
  note "PASS  invariant-index -- 2 controls + 1 near-miss green, 7/7 mutants scored on their own arm"
fi
exit "$rc"
