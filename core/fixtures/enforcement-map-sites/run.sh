#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
# enforcement-map-sites — assert the enforcement-map validator reads the tree it is given, and
# stays quiet on near-misses.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the check regressed, 2 = fixture broken.
#
# THE SUBJECT. `scripts/validate-enforcement-map.sh` derives its tree from its own location, so
# every assertion here seeds a copy of the distribution (seed.sh), plants one input in the copy
# and runs the copy's validator over it, in process (`vem_entry`). What is asserted:
#
#   A00  the pristine copy passes every arm. It runs first and alone: every other assertion reads
#        a verdict of the same validator, and a validator that errors for its own reasons would
#        make each negative below read as a pass.
#   A10, A29, A35, A39  near-miss inputs the named arm must leave silent (I16, I54, I93 arm D,
#        I93 arm E), each beside a run that still reaches the validator's OK verdict.
#   A40-A43  I91 / I94 / I95 / I81 name a seeded offender from every cwd: a scratch directory,
#        a decoy root, "$ROOT/core" by a relative path, and an inherited VEM_SELF. Each carries
#        a command-line half where the property exists only for a started program.
#   eq   `vem_entry` and a command-line start of the same file agree byte for byte (eq_pair).
#
# SHARDS. Shards a, b and c are dealt the assertions after A00 round-robin, in the order this
# file DEFINES them; the cwd assertions are defined first so that I91 and I81 land in shard a,
# I94 in b and I95 in c, which is where each directory's cells.decl declares its command-line
# cell. The `eq` group (enforcement-map-sites-d) runs the full-run equivalence pairs only.
set -uo pipefail

# I10's scrub: a fixture must not inherit a tunable that changes what it measures. A43 names a
# hook path, which puts this file in I10's hook-driving set, and it never executes the hook.
#
# Ordered before HERE= and before the pool: the worker wrapper reads AI_DLC_EMS_SELF and
# AI_DLC_EMS_OUT in its own `bash -c`, ahead of the run.sh it then invokes, so unsetting them
# here cannot reach the values already resolved.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../lib/layout.sh" || { echo "FIXTURE BROKEN: cannot source lib/layout.sh" >&2; exit 2; }

# Distribution-only. `validate-enforcement-map.sh` is not shipped by install.sh (it checks
# the distribution's own two writers against each other — a consumer has neither), so in a
# consumer tree there is nothing to test. Say so and stop; do not fake a pass.
if [ ! -f "$HERE/../../../scripts/validate-enforcement-map.sh" ]; then
  echo "enforcement-map-sites: SKIP — distribution-only (validate-enforcement-map.sh is not shipped to consumers)"
  fx_skip_exit "$HERE"
fi
# The validator is present and about to be driven; inputs.decl marks it REQUIRED.
echo "HERMETIC-CONSUMED scripts/validate-enforcement-map.sh" >&2

# ONE TREE PER ASSERTION, IN ONE PROCESS PER ASSERTION, AND THE REASON IS WALL CLOCK.
# Each assertion seeds its own tree, plants its input and runs `validate-enforcement-map.sh` over
# it. They are independent, so each is a function, each runs in its own process against its own
# seed, and the driver at the foot of this file runs them through a worker pool.
#
# THE CONTROL STAYS SERIAL AND STAYS FIRST. Assertion 0 asserts the PRISTINE tree passes;
# running it concurrently with the assertions it licenses would report them in an order where
# that licence had not yet been established.
#
# SEEDED ONCE PER SHARD, COPIED PER TREE. `seed.sh` copies core/, scripts/, .githooks/ and
# templates/ out of the LIVE distribution. The shard driver runs `seed.sh` ONCE into a template,
# checks it, and hands its path to every cell as an ARGUMENT; `seed_tree` copies the template.
#
# EMS_TEMPLATE IS AN ARGUMENT SLOT, NEVER AN `AI_DLC_*` ENVIRONMENT NAME: the scrub above unsets
# those before `--run-one` reads anything (the same reason `--group` and the ledger are arguments).
# There is NO FALLBACK to `seed.sh` and none to the live root: a cell with no usable template
# exits 2.
#
# EMS_DECOY is the A40-A43 cwd-battery root, a SECOND argument slot, built by the driver beside the
# template: a copy of it plus a seeded VERSION and a `git init`. Cells never copy it, so
# every seeded ROOT still lacks VERSION (the validator's I45 guard keys on that); the decoy carries
# both markers so a validator that walks UP from its cwd for one resolves to the decoy. Same
# fail-closed rule: no usable decoy, exit 2.
EMS_TEMPLATE=""
EMS_DECOY=""
seed_tree() {
  # Refused HERE as well as at --run-one, because every subject calls this: an empty value would
  # make the copy below `cp -RX /.`, the whole filesystem.
  if [ -z "$EMS_TEMPLATE" ] || [ ! -f "$EMS_TEMPLATE/scripts/validate-enforcement-map.sh" ]; then
    echo "FIXTURE ERROR: seed_tree has no usable seed template (EMS_TEMPLATE='$EMS_TEMPLATE'); there is no fallback to seed.sh or to the live root" >&2
    exit 2
  fi
  ROOT="$(mktemp -d "${TMPDIR:-/tmp}/enforcement-map-sites.XXXXXX")" || { echo "FIXTURE ERROR: seed failed (mktemp)" >&2; exit 2; }
  cp -RX "$EMS_TEMPLATE/." "$ROOT/" || { echo "FIXTURE ERROR: seed failed (copy of template $EMS_TEMPLATE)" >&2; exit 2; }
  V="$ROOT/scripts/validate-enforcement-map.sh"
  # THE TREE'S VALIDATOR IS SOURCED ONCE, BY ITS ABSOLUTE PATH, IN THE PROCESS THAT RUNS THIS CELL.
  # Sourcing defines vem_entry and returns at the column-0 source guard; every run below is
  # `vem_entry [--arms I<n>]`, a subshell of this process, never a separate program.
  case "$V" in /*) : ;; *) echo "FIXTURE ERROR: the seeded validator path '$V' is not absolute; vem_entry refuses a relative source" >&2; exit 2 ;; esac
  # shellcheck disable=SC1090
  . "$V" || { echo "FIXTURE ERROR: sourcing the seeded validator $V failed" >&2; exit 2; }
  declare -F vem_entry >/dev/null || { echo "FIXTURE ERROR: sourcing $V defined no vem_entry" >&2; exit 2; }
}

broken=0
. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }
MUT_LIB="$HERE/../lib/mutant.sh"
[ -f "$MUT_LIB" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $HERE" >&2; exit 2; }
. "$MUT_LIB"

# `mkbak <path>` -> a backup of <path> OUTSIDE the seeded tree, printing the backup's path. A copy
# beside the original would sit inside the population the validator sweeps.
mkbak() {
  local b
  b="$(mktemp)" || { echo "FIXTURE ERROR: mktemp failed for a backup of $1" >&2; exit 2; }
  cp "$1" "$b" || { echo "FIXTURE ERROR: could not back up $1" >&2; exit 2; }
  printf '%s\n' "$b"
}

# ONE VALIDATOR RUN PER ASSERTION, AND THE ARM IT SELECTS IS DERIVED FROM THE CALLER'S NAME.
# `validate-enforcement-map.sh --arms I<n>` runs one selectable unit plus the prologue and the
# verdict block. Every assertion below declares the invariant it tests in its own function name
# -- `A10_i16_precision` tests I16 -- so that embedded segment IS the selector. Nothing here
# hand-lists one.
#
# THREE FAILURE SHAPES, and none of them may reach an assertion's predicate:
#   - a frame whose name carries no derivable `i<id>` segment;
#   - `--arms <id>` naming an id no arm declares, or any other selection/usage failure;
#   - a generated subprogram that never reached the verdict block.
# The validator answers all three with exit 2, which is never an invariant violation, so each is
# FIXTURE BROKEN, named, with the validator's own message. THERE IS DELIBERATELY NO FALLBACK TO A
# FULL RUN: a fallback would satisfy the same grep and leave a selector that resolves to nothing
# looking identical to one that resolved correctly.
#
# THE BROKEN SIGNAL GOES THROUGH A FILE. `out="$(vrun)"` runs this function inside a command
# substitution, so an `exit 2` here kills the SUBSHELL; `--run-one` reads the marker after the
# assertion returns and exits 2 itself, which is the code the driver routes to FIXTURE BROKEN.
VRUN_LOG=""
VRUN_BROKEN=""
# The validator's exit status, for a caller that asserts it. `vrun` runs inside `$( )`, so the
# status cannot come back as a variable; when this names a file, vrun writes the status there.
VRUN_RCF=""
# `vrun` -- one in-process `vem_entry --arms <id>` of the tree's validator, sourced once by
# seed_tree. The cwd-invariance cells call it from other directories; their two command-line
# cells (a relative self path, an inherited VEM_SELF) start the program themselves (cwd_cli).
vrun() {
  local frame seg id vout rc
  id=""
  for frame in "${FUNCNAME[@]}"; do
    case "$frame" in
      A[0-9]*_i[0-9]*)
        seg="${frame#A}"; seg="${seg#*_}"; seg="${seg%%_*}"
        case "$seg" in
          i[0-9]*) id="I${seg#i}"; break ;;
        esac
        ;;
    esac
  done
  if [ -z "$id" ]; then
    [ -n "$VRUN_BROKEN" ] && printf 'FIXTURE BROKEN: vrun found no A<nn>_i<id>_ frame to derive an --arms selector from (frames: %s). The naming grammar the selector is derived from has moved, and there is no full-run fallback on purpose.\n' "${FUNCNAME[*]}" >> "$VRUN_BROKEN"
    return 2
  fi
  vout="$(fx_inproc "$V"; vem_entry --arms "$id" 2>&1)"; rc=$?
  [ -n "$VRUN_RCF" ] && printf '%s\n' "$rc" > "$VRUN_RCF"
  if [ "$rc" = "2" ]; then
    [ -n "$VRUN_BROKEN" ] && printf 'FIXTURE BROKEN: validate-enforcement-map.sh --arms %s exited 2. That is a SELECTION failure -- an unknown id, a malformed flag, or a generated subprogram that never reached the verdict -- not an invariant finding: %s\n' "$id" "$vout" >> "$VRUN_BROKEN"
    return 2
  fi
  [ -n "$VRUN_LOG" ] && printf '%s\n' "$id" >> "$VRUN_LOG"
  printf '%s\n' "$vout"
}

# --- Assertion 0: SANITY ------------------------------------------------------
# The pristine tree must PASS. If it does not, the validator is erroring for some reason
# of its own and every other assertion's verdict is about that error.
#
# THE ONE ASSERTION THAT KEEPS A FULL RUN: "the pristine tree passes" is an ABSENCE over EVERY
# arm, not over one.
#
# THE FAILING RUN'S OWN WORDS ARE KEPT. Its stderr (every `FAIL:` line the validator's err()
# writes) is captured and printed under the broken verdict, indented off `^  FAIL`, so the next
# occurrence names its arm.
A00_sanity() {
local a00_err a00_rc
fx_inproc "$V"
a00_err="$(vem_entry 2>&1 >/dev/null)"; a00_rc=$?
if [ "$a00_rc" -eq 0 ]; then
  ok "pristine distribution tree passes (the assertions below read a validator that is not simply broken)"
else
  bad "FIXTURE BROKEN — the pristine tree does not pass validate-enforcement-map.sh (rc=$a00_rc). Every assertion below would be read against a broken validator."
  if [ -n "$a00_err" ]; then
    awk 'NR <= 40 { print "      | " $0 }' <<<"$a00_err"
  else
    printf '      | (the validator wrote nothing to stderr)\n'
  fi
fi
}

# --- Assertions 40-43: I91 / I94 / I95 / I81 READ THE TREE THEY VALIDATE, FROM ANY CWD ------
# Those four arms once spelled their corpus relative to the PROCESS cwd. A seeded copy run from a
# scratch directory reported the schema or the hooks "missing" (rc 1); the same copy run from the
# repo root read the LIVE tree and returned a false clean on an offender planted only in the seed.
#
# FOUR CELLS PER ID, each against the SEEDED validator with the offender present ONLY in the
# seed. Every cell requires rc 1 AND the finding naming the seeded file AND output byte-equal
# to C1 -- a cell keyed on equality alone scores two identical "schema missing" runs as a pass:
#   C1  from a fresh `mktemp -d` cwd.
#   C2  from a DECOY ROOT ($EMS_DECOY): the shard's seed template plus a seeded VERSION and a
#       `git init`, a complete tree carrying no offender. A cwd-reading validator returns rc 0
#       there; a validator that walks UP from the cwd for VERSION, or asks `git rev-parse
#       --show-toplevel`, resolves to the decoy and reads it. The cells' own trees are copied
#       from the template, NOT the decoy, so they still lack VERSION (the I45 guard).
#       The messages say "live root" for this cell; the word names the cell, and the cell is the decoy.
#   C3  from "$ROOT/core", by the RELATIVE path ../scripts/validate-enforcement-map.sh.
#   C4  from a fresh cwd with VEM_SELF EXPORTED, naming the decoy's validator. The validator
#       honours VEM_SELF only when its own shell set it.
#
# IN PROCESS, WITH TWO COMMAND-LINE HALVES. C1-C4 each run the tree's validator through vem_entry
# from their own cwd. Two properties exist only when the validator is STARTED as a program: a
# relative self path resolved across the prologue's cd (vem_entry refuses a relative source
# path), and the prologue's own `[ "${VEM_SELF_PID:-}" = "$$" ] || unset VEM_SELF` guard
# (vem_entry unsets an inherited VEM_SELF before the eval). So C3 additionally carries a
# command-line cell started BY THE RELATIVE PATH from "$ROOT/core" on every control, and C4 a
# command-line cell started with VEM_SELF exported on I81's control. A cell that carries a
# command-line half scores 1 only when BOTH halves score 1, each byte-equal to C1's in-process
# s.out, and its rc in CW_RCS is the command-line one. Each start is tagged with its cells.decl id.
CWD_SELF_REL="../scripts/validate-enforcement-map.sh"

# cwd_cli <rel|env> <cell id> <out file> <rc file> -- one command-line start of the tree's validator.
cwd_cli() {
  local how="$1" cell="$2" o="$3" rcf="$4" s rc
  s="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp -d failed" >&2; exit 2; }
  if [ "$how" = rel ]; then
    (cd "$ROOT/core" && FXCELL="$cell" bash "$CWD_SELF_REL" --arms "$CW_ID") > "$o" 2>&1; rc=$?
  else
    (export VEM_SELF="$EMS_DECOY/scripts/validate-enforcement-map.sh"; cd "$s" && FXCELL="$cell" bash "$V" --arms "$CW_ID") > "$o" 2>&1; rc=$?
  fi
  rmdir "$s" 2>/dev/null
  printf '%s\n' "$rc" > "$rcf"
}

# cwd_cells <ERE naming the seeded finding>
# Sets CW_BITS (e.g. 1111) and CW_RCS, and leaves C1's output in "$CW_DIR/s.out".
cwd_cells() {
  local want="$1" s rcf rc_s rc_r rc_rel rc_env b1=0 b2=0 b3=0 b4=0 cli_rel="" cli_env="" rc_crel="" rc_cenv=""
  # Which command-line halves this call starts: the relative path on every id, the inherited
  # VEM_SELF on I81. Cell ids are the cells.decl rows.
  cli_rel="cwd-rel-$CW_ID"
  [ "$CW_ID" = I81 ] && cli_env="cwd-env-$CW_ID"
  s="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp -d failed" >&2; exit 2; }
  rcf="$CW_DIR/rc"
  printf 'none\n' > "$rcf"
  (VRUN_RCF="$rcf"; cd "$s" && vrun) > "$CW_DIR/s.out"
  rc_s="$(cat "$rcf")"
  printf 'none\n' > "$rcf"
  (VRUN_RCF="$rcf"; cd "$EMS_DECOY" && vrun) > "$CW_DIR/r.out"
  rc_r="$(cat "$rcf")"
  printf 'none\n' > "$rcf"
  (VRUN_RCF="$rcf"; cd "$ROOT/core" && vrun) > "$CW_DIR/rel.out"
  rc_rel="$(cat "$rcf")"
  printf 'none\n' > "$rcf"
  (VRUN_RCF="$rcf"; export VEM_SELF="$EMS_DECOY/scripts/validate-enforcement-map.sh"; cd "$s" && vrun) > "$CW_DIR/env.out"
  rc_env="$(cat "$rcf")"
  rmdir "$s" 2>/dev/null
  if [ -n "$cli_rel" ]; then
    cwd_cli rel "$cli_rel" "$CW_DIR/rel.cli" "$CW_DIR/rc.cli"; rc_crel="$(cat "$CW_DIR/rc.cli")"
    # An exit 2 on the unmodified validator is a broken run, never a finding.
    if [ "$rc_crel" = 2 ] && [ -n "$VRUN_BROKEN" ]; then
      printf 'FIXTURE BROKEN: the command-line cell %s exited 2 on the validator: %s\n' "$cli_rel" "$(head -3 "$CW_DIR/rel.cli" | tr '\n' ' ')" >> "$VRUN_BROKEN"
    fi
  fi
  if [ -n "$cli_env" ]; then
    cwd_cli env "$cli_env" "$CW_DIR/env.cli" "$CW_DIR/rc.cli"; rc_cenv="$(cat "$CW_DIR/rc.cli")"
    if [ "$rc_cenv" = 2 ] && [ -n "$VRUN_BROKEN" ]; then
      printf 'FIXTURE BROKEN: the command-line cell %s exited 2 on the validator: %s\n' "$cli_env" "$(head -3 "$CW_DIR/env.cli" | tr '\n' ' ')" >> "$VRUN_BROKEN"
    fi
  fi
  if [ "$rc_s" = 1 ] && grep -qE -- "$want" "$CW_DIR/s.out"; then b1=1; fi
  if [ "$rc_r" = 1 ] && grep -qE -- "$want" "$CW_DIR/r.out" && cmp -s "$CW_DIR/s.out" "$CW_DIR/r.out"; then b2=1; fi
  if [ "$rc_rel" = 1 ] && grep -qE -- "$want" "$CW_DIR/rel.out" && cmp -s "$CW_DIR/s.out" "$CW_DIR/rel.out"; then b3=1; fi
  if [ "$rc_env" = 1 ] && grep -qE -- "$want" "$CW_DIR/env.out" && cmp -s "$CW_DIR/s.out" "$CW_DIR/env.out"; then b4=1; fi
  # The command-line halves, each held to the same predicate and to C1's in-process bytes. Its
  # output replaces the cell's file, so cwd_why shows the half that decided.
  if [ -n "$cli_rel" ]; then
    rc_rel="$rc_crel"
    if [ "$b3" = 1 ] && ! { [ "$rc_crel" = 1 ] && grep -qE -- "$want" "$CW_DIR/rel.cli" && cmp -s "$CW_DIR/s.out" "$CW_DIR/rel.cli"; }; then b3=0; mv "$CW_DIR/rel.cli" "$CW_DIR/rel.out"; fi
    rm -f "$CW_DIR/rel.cli"
  fi
  if [ -n "$cli_env" ]; then
    rc_env="$rc_cenv"
    if [ "$b4" = 1 ] && ! { [ "$rc_cenv" = 1 ] && grep -qE -- "$want" "$CW_DIR/env.cli" && cmp -s "$CW_DIR/s.out" "$CW_DIR/env.cli"; }; then b4=0; mv "$CW_DIR/env.cli" "$CW_DIR/env.out"; fi
    rm -f "$CW_DIR/env.cli"
  fi
  rm -f "$CW_DIR/rc.cli"
  CW_BITS="$b1$b2$b3$b4"
  CW_RCS="rc scratch=$rc_s live-root=$rc_r relative=$rc_rel inherited-VEM_SELF=$rc_env"
  CW_RC_ROOT="$rc_r"
}

# cwd_why <expected bits> [scored bits] [ERE] -- the EVIDENCE behind a non-green cwd verdict,
# appended to that verdict's FAIL line: `bad "<message>$(cwd_why <expected>)"`. Every line it
# prints begins with a newline and `      | `, so the message keeps its own line, the evidence
# sits below it, and no evidence line can read as `^  FAIL` to the driver's count. It runs on no
# passing verdict, so a green run's stdout is unchanged.
# A cell's outputs are deleted by cwd_finish, so a cell that flipped once under load would
# otherwise leave no trace of its cause.
# Per failing cell: its rc (from $CW_RCS), whether the ERE (default $want) matched its output,
# and its first differing lines against C1's s.out, at most 12 lines cut to 200 chars; for C1
# itself, the head of s.out instead. The scored bits come from $CW_BITS or the second argument;
# no cell predicate is recomputed here.
# A fifth bit is FULL (cwd_full's full.out), and its head is printed when it differs either way.
cwd_why() {
  local exp="$1" got="${2:-${CW_BITS:-}}" ere="${3:-${want:-}}" i f cell rc m d l rcw
  read -r -a rcw <<<"${CW_RCS:-}"
  for i in 0 1 2 3 4; do
    [ "$i" -lt "${#exp}" ] || break
    case "$i" in
      # No quoted blank in these assignments: validate-fixture-hygiene's H7 reads a quoted word
      # list as a roster, and the cell names here would then resolve the C<n> twins it lists as built.
      0) cell=C1-scratch; f=s.out ;;
      1) cell=C2-live-root; f=r.out ;;
      2) cell=C3-relative; f=rel.out ;;
      3) cell=C4-inherited-VEM_SELF; f=env.out ;;
      4) cell=FULL; f=full.out ;;
    esac
    if [ "$i" = 4 ]; then
      [ "${exp:4:1}" != "${got:4:1}" ] || continue
      printf '\n      | %s: expected %s, scored %s; head of %s:' "$cell" "${exp:4:1}" "${got:4:1}" "$f"
      d="$(head -n 12 "$CW_DIR/$f" 2>&1 | cut -c1-200)" || true
    else
      [ "${exp:$i:1}" = 1 ] && [ "${got:$i:1}" = 0 ] || continue
      rc="${rcw[$((i+1))]:-unrecorded}"; rc="${rc#*=}"
      m=no; grep -qE -- "$ere" "$CW_DIR/$f" 2>/dev/null && m=yes
      printf '\n      | %s (%s): expected 1, scored 0; rc %s; want /%s/ matched: %s' "$cell" "$f" "$rc" "$ere" "$m"
      if [ "$i" = 0 ]; then
        printf '\n      | head of s.out:'
        d="$(head -n 12 "$CW_DIR/s.out" 2>&1 | cut -c1-200)" || true
      else
        # The cell's OWN lines (`>`) first: C1's side can run past the bound alone, and the
        # cell's side is where a transient failure's text lands.
        printf '\n      | diff s.out %s (C1 against this cell, the cell'"'"'s own > lines first):' "$f"
        d="$(diff "$CW_DIR/s.out" "$CW_DIR/$f" 2>&1)" || true
        if [ -n "$d" ]; then
          d="$( { grep '^>' <<<"$d"; grep -v '^>' <<<"$d"; } | head -n 12 | cut -c1-200)" || true
        else
          d="(byte-equal to C1's s.out)"
        fi
      fi
    fi
    while IFS= read -r l; do printf '\n      | %s' "$l"; done <<<"$d"
  done
}

# The cwd control. Its positive conjunct is the finding itself: every cell demands it be
# PRESENT, so a validator that prints nothing cannot score 1111.
cwd_control() {
  local want="$1"
  CW_DIR="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp -d failed" >&2; exit 2; }
  cwd_cells "$want"
  if [ "$CW_BITS" = 1111 ]; then
    ok "$CW_ID: the seeded offender is named from a scratch cwd, and byte-identically from the live distribution root, from \$ROOT/core by a relative path, and with an inherited VEM_SELF naming the live validator ($CW_RCS)"
  else
    bad "$CW_ID: the validator scored $CW_BITS on the cwd cells ($CW_RCS) -- it does not read the seeded tree from every cwd, or the seeded offender went unreported$(cwd_why 1111)"
  fi
}

# FULL MODE, scored on I91 only. Every cell above runs `--arms`, but the pre-push hook and most
# seeded callers run the validator with NO flags: one full run from the decoy root, requiring rc 1
# and the seeded finding.
cwd_full_bit() { # cwd_full_bit <ERE> -> prints 1 or 0, and leaves the run in "$CW_DIR/full.out"
  local rc
  (cd "$EMS_DECOY" && fx_inproc "$V" && vem_entry) > "$CW_DIR/full.out" 2>&1; rc=$?
  if [ "$rc" = 1 ] && grep -qE -- "$1" "$CW_DIR/full.out"; then echo 1; else echo 0; fi
}
cwd_full() {
  local want="$1" fb
  fb="$(cwd_full_bit "$want")"
  if [ "$fb" = 1 ]; then
    ok "$CW_ID FULL MODE: the seeded validator with no --arms, run from the live root, names the seeded offender"
  else
    bad "$CW_ID FULL MODE: the seeded validator with no --arms, run from the live root, did not name the seeded offender -- it read the live tree ($(grep -cE '^FAIL' "$CW_DIR/full.out") FAIL line(s))"
  fi
}

cwd_finish() { rm -f "$CW_DIR/s.out" "$CW_DIR/r.out" "$CW_DIR/rel.out" "$CW_DIR/env.out" "$CW_DIR/full.out" "$CW_DIR/rc"; rmdir "$CW_DIR" 2>/dev/null; }

A40_i91_cwd_invariance() {
CW_ID=I91
i91_pfx='<task-notification'
printf 'x="%s"\n' "$i91_pfx" > "$ROOT/core/scripts/zz-i91-cwd-offender.sh"
# A core/fixtures/ copy for that exemption, and every exempt file asserted to CARRY the prefix:
# a near-miss without it would be acquitted for having nothing to report, not by the exemption.
printf 'x="%s"\n' "$i91_pfx" > "$ROOT/core/fixtures/enforcement-map-sites/zz-i91-nearmiss.txt"
i91_nm_ok=1
for f in core/schemas/harness-origin.json core/scripts/validate-steering-budget.sh \
         scripts/validate-enforcement-map.sh core/fixtures/enforcement-map-sites/zz-i91-nearmiss.txt; do
  grep -qF -- "$i91_pfx" "$ROOT/$f" || { i91_nm_ok=0; bad "FIXTURE BROKEN: exempt file $f does not carry $i91_pfx, so the I91 near-miss would be acquitted for having nothing to report"; }
done
# I91 emits one indented `path:literal` line per copy (one grep -roF pass over core/ and scripts/).
want='^  core/scripts/zz-i91-cwd-offender\.sh:<task-notification$'
cwd_control "$want"
if [ "$i91_nm_ok" = 1 ]; then
  i91_hits="$(grep -E -- '^  [^[:space:]]+:' "$CW_DIR/s.out")"
  if [ -z "$i91_hits" ]; then
    bad "I91 near-miss: the scratch-cwd run printed no copy-hit line at all, so the exemption has nothing to be read against"
  elif grep -qE 'core/schemas/harness-origin\.json|core/scripts/validate-steering-budget\.sh|scripts/validate-enforcement-map\.sh|core/fixtures/' <<<"$i91_hits"; then
    bad "I91 near-miss: an exempt file (the schema, the JS predicate, the validator or a core/fixtures/ file) was reported as a copy from a scratch cwd -- the exclusion filters no longer match the paths the scan emits"
  else
    ok "I91 near-miss: the schema, validate-steering-budget.sh, the validator and a core/fixtures/ file all carry the prefix and none is reported, beside the seeded offender that is"
  fi
fi
cwd_full "$want"
cwd_finish
}

A41_i94_cwd_invariance() {
CW_ID=I94
python3 - "$ROOT/core/schemas/pause-routing.json" "$ROOT/core/rules/zz-i94-cwd-offender.md" <<'PY' || { bad "FIXTURE BROKEN: could not seed the I94 offender from the declared pause_branch_text"; return; }
import json, sys
v = json.load(open(sys.argv[1]))["pause_branch_text"]
assert v
open(sys.argv[2], "w").write(v + "\n")
PY
want='pause_branch_text -> .*core/rules/zz-i94-cwd-offender\.md'
cwd_control "$want"
i94_hits="$(grep -E -- ' -> ' "$CW_DIR/s.out")"
if [ -z "$i94_hits" ]; then
  bad "I94 near-miss: the scratch-cwd run printed no copy-hit line at all, so the schema exclusion has nothing to be read against"
elif grep -q 'core/schemas/pause-routing\.json' <<<"$i94_hits"; then
  bad "I94 near-miss: the declaration itself was reported as a copy from a scratch cwd -- the compare against the schema path no longer matches what the scan emits"
else
  ok "I94 near-miss: the declaration carries every value and is not reported, beside the seeded copy that is"
fi
cwd_finish
}

A42_i95_cwd_invariance() {
CW_ID=I95
printf 'X="${STATE_DIR}/.zz-i95-cwd-undeclared"\n' > "$ROOT/core/hooks/zz-i95-cwd-offender.sh"
want='I95: \.zz-i95-cwd-undeclared is constructed at core/hooks/zz-i95-cwd-offender\.sh:1'
cwd_control "$want"
cwd_finish
}

# I81 has no copy scan, so its offender is the invariant's own violating shape: the two hooks'
# live-series blocks made to differ, in the seed only.
A43_i81_cwd_invariance() {
CW_ID=I81
i81_h="$ROOT/core/hooks/ai-dlc-acknowledge.sh"
i81_bak="$(mkbak "$i81_h")"
awk '{ print } />>> I81 LIVE-SERIES BLOCK >>>/ { print "  : i81-cwd-seed" }' "$i81_bak" > "$i81_h"
rm -f "$i81_bak"
if [ "$(grep -c 'i81-cwd-seed' "$i81_h")" != 1 ]; then
  bad "FIXTURE BROKEN: the I81 seed did not land exactly once inside acknowledge.sh's live-series block"
  return
fi
want='i81-cwd-seed'
cwd_control "$want"
if grep -q 'derive the live adversarial series DIFFERENTLY' "$CW_DIR/s.out"; then
  ok "I81: the seeded divergence is reported as the two hooks disagreeing, not by another I81 message that happens to echo the block"
else
  bad "I81: the scratch-cwd run did not report the seeded block as a divergence between the two hooks"
fi
cwd_finish
}

# --- Assertion 9: I16 PRECISION -----------------------------------------------
# The word "core" is everywhere in this rulebook ("core rule", "core catalog", "core-path wiring"),
# and the update machinery cites `core/...` paths BY DESIGN — comparing distribution to consumer is
# its whole job. If I16 flags either, it gets switched off and stops catching a dead prose path.
A10_i16_precision() {
printf '\nThe core rule lives in the core catalog; core-path wiring is a core concern.\n' \
  >> "$ROOT/core/skills/ai-dlc/steps/gate-validation.md"
printf '\nDiff base->theirs restricted to `core/skills/ai-dlc-update/**` and `core/team-roles/dev.md`.\n' \
  >> "$ROOT/core/skills/ai-dlc-update/SKILL.md"
out="$(vrun)"
if grep -q "runtime-pipeline prose cites a distribution path" <<<"$out"; then
  bad "A10-c1: I16 fired on the English word 'core' or on ai-dlc-update's by-design core/ citations — a check with false positives is a check the operator turns off"
else
  ok "A10-c1: I16 ignores the English word 'core' and ai-dlc-update's by-design core/ paths (precise enough to stay on)"
fi
}

A29_i54_early_exit_reader() {
# I54 bans writing a shell variable into a reader that stops at its first match. Under
# pipefail such a pipeline reports the WRITER's status, and a writer that still had bytes
# to push has taken EPIPE -- so the test answers "not found" on input containing the
# pattern. An ordinary command piped into the same reader is safe and ubiquitous; a blanket
# ban would be an unmeasured lint. Asserted on I54 being SILENT about this file.
#
# EVERY LITERAL OF THE BANNED SHAPE IS ASSEMBLED AT RUNTIME. I54's scan covers
# core/fixtures/, so a fixture that spelled the shape out would be reported by the very
# invariant it exists to test. `$_g` below is the reader; nothing on any line here forms the
# pattern I54 matches.
_g="gre""p -q"
I54_TGT="core/fixtures/ledger-rotate/run.sh"
printf '\nif false; then\n  git log --oneline | %s I54_SENTINEL_BETA\nfi\n' "$_g" >> "$ROOT/$I54_TGT"
out="$(vrun)"
if grep -q 'I54 found' <<<"$out"; then
  bad "A29-c1: I54 reported an ordinary command piped into a first-match reader — that shape is permitted, and a check with that false-positive set is one the operator switches off"
else
  ok "A29-c1: an ordinary command piped into the same reader does NOT fail I54 (the subject set is a builtin writing a variable, not every pipe)"
fi
}

# `i93_token` -> the declared empty-subject verdict token, read out of the SEED's own owner.
#
# NEVER TYPED HERE: a fixture that restates a controlled vocabulary is a second copy of it.
# Callers must treat an empty result as FIXTURE BROKEN -- a seed emitting the empty string
# reaches no branch, arm D correctly stays quiet, and that silence would be an absence.
i93_token() {
  awk '
    /^empty_subject_verdict:/ { on = 1; next }
    on && /^[^[:space:]#]/    { exit }
    on && /^  token:/         { sub(/^  token:[[:space:]]*/, ""); print; exit }
  ' "$ROOT/core/skills/ai-dlc/enforcement-map.yaml"
}

# --- Assertion 35: I93 arm D — the near-miss ----------------------------------
# Arm D's false-positive narrowing is the emission SITE: a `#` line carrying the token is a
# validator's exit-code table, not an emission, and there are dozens of those. A whole-file
# `grep -qF` would fire on all of them.
A35_i93_reverse_join() {
local esv_tok esv_core_new
esv_tok="$(i93_token)"
if [ -z "$esv_tok" ]; then
  bad "FIXTURE BROKEN: could not derive empty_subject_verdict.token from the seed's enforcement-map.yaml — the seed below would emit nothing, arm D would rightly stay quiet, and that silence would mean nothing"
  return
fi
# Deliberately not named validate-*.sh: arm D's population is every FILE in the directory.
esv_core_new="$ROOT/core/scripts/esv-newcomer.sh"
printf '%s\n' '#!/usr/bin/env bash' "#   78 = $esv_tok, in an exit-code table" \
              "  #   and once more, indented, as a header records a retirement" > "$esv_core_new"
out="$(vrun)"
if grep -q 'esv-newcomer.sh' <<<"$out"; then
  bad "A35-c1: arm D fired on a file whose only mention of the token is a COMMENT — every emitter's own exit-code table is that shape, so the arm would demand a declaration for each of them"
elif grep -q '^OK: enforcement-map.yaml in sync' <<<"$out"; then
  ok "A35-c1: a core/scripts/ file carrying the token only in a comment does NOT fail I93, and the run still reaches its verdict (the narrowing is the emission site, not the token)"
else
  bad "A35-c1: the near-miss tree neither failed on the seeded path nor reached I93's OK verdict — the run did not get far enough for this arm's silence to mean anything"
fi
rm -f "$esv_core_new"
}

# --- Assertion 39: I93 arm E -- the near-misses --------------------------------
# Arm E refuses a FOURTH spelling of the empty-subject verdict. A fire-only arm passes against
# one that reports every `echo`, which would red the tree on every validator's diagnostics, so
# the shapes below are real things in this corpus that must stay silent.
#
# THE SPELLING IS NOVEL BY CONSTRUCTION, NOT BY ASSERTION: built from the DERIVED token and
# checked against it, so if the token ever becomes the seed's own words this assertion says
# FIXTURE BROKEN.
A39_i93_novel_spelling() {
local esv_tok esv_novel_say esv_core_new
esv_tok="$(i93_token)"
if [ -z "$esv_tok" ]; then
  bad "FIXTURE BROKEN: could not derive empty_subject_verdict.token, so arm E's seeds would be read against nothing"
  return
fi
esv_novel_say='NOTHING TO EXAMINE HERE'
case "$esv_tok" in
  *"$esv_novel_say"*) bad "FIXTURE BROKEN: the declared token now CONTAINS this arm's novel phrase, so a finding could belong to arm A or arm C rather than to arm E"; return ;;
esac
esv_core_new="$ROOT/core/scripts/esv-fourth.sh"

# NEAR-MISS 1 -- four shapes in ONE file, because each is a real thing in this corpus and any
# one of them firing reds the tree on a conforming validator:
#   a `#` comment      -- every emitter's exit-code table
#   an `err` argument  -- a FAILURE message, which is not the empty-subject state; eight lines
#                         INSIDE the I93 unit itself are this shape
#   a `%-Ns` row       -- sprint-status.sh's per-view report line
#   a `> path` write   -- a probe seeding a fixture tree, including arm E's own seeds
printf '%s\n' '#!/usr/bin/env bash' \
  "#   0 = $esv_novel_say, in an exit-code table" \
  'err "the corpus is empty: found nothing to scan. Failing closed."' \
  'print("  %-15s no key — nothing to compare" % view)' \
  'printf "%s\n" "audited nothing" > "$TMP/seed.sh"' > "$esv_core_new"
out="$(vrun)"
if grep -q 'esv-fourth.sh' <<<"$out"; then
  bad "A39-c1: arm E fired on a comment, an err() argument, a padded table row or a probe seed write — each is a live shape in this corpus, so the arm would red the tree on validators that are conforming, and the first one alone appears eight times inside the I93 unit it lives in"
elif grep -q '^OK: enforcement-map.yaml in sync' <<<"$out"; then
  ok "A39-c1: a file carrying the phrase ONLY as a comment, an err() argument, a %-Ns table row and a file-redirected seed write does NOT fail I93, and the run still reaches its verdict (the narrowing is the emission site, not the words)"
else
  bad "A39-c1: the near-miss tree neither failed on the seeded path nor reached I93's OK verdict — the run did not get far enough for this arm's silence to mean anything"
fi

# NEAR-MISS 2 -- A FILE THAT ALREADY EMITS THE DECLARED TOKEN IS NOT REPORTED, even when it also
# states an empty subject in its own words elsewhere. This is validate-bmad-invocations.sh's
# real shape: it prints the token at one line for one state and says "nothing to resolve
# against" at another for a different one.
printf '%s\n' '#!/usr/bin/env bash' "echo \"DISARMED — $esv_tok — no corpus.\"" \
  "echo \"and separately: $esv_novel_say\"" > "$esv_core_new"
out="$(vrun)"
if grep -q "esv-fourth.sh.* states an empty-subject verdict" <<<"$out"; then
  bad "A39-c2: arm E reported a file that ALREADY emits the declared token — a conforming emitter is told to adopt a token it prints, and every declared emitter carrying prose about an empty subject would red the tree"
else
  ok "A39-c2: a file already emitting the declared token is NOT reported by arm E even when it states an empty subject in its own words elsewhere (the join is per FILE, which is what the arm actually asks)"
fi
rm -f "$esv_core_new"
}

# ---------------------------------------------------------------------------
# THE DRIVER
# ---------------------------------------------------------------------------
# THE ASSERTION LIST IS DERIVED FROM THIS FILE'S OWN DEFINITIONS, in source order. A
# hand-written list here would let an assertion dropped from it run nothing and print
# nothing, and a suite reporting fewer greens reads exactly like one that passed. The zero
# guard is the same argument -- a naming grammar that stops matching yields an empty list.
#
# THE OPTIONAL LETTER IS LOAD-BEARING: `vrun` derives the arm id from a lettered frame, so the
# enumerator must be able to spell one.
NAMES="$(grep -oE '^A[0-9]{2}[a-z]?_[a-z0-9_]+\(\) \{' "$0" | sed 's/() {$//')"
N_LISTED="$(printf '%s\n' "$NAMES" | grep -c . || true)"
# EXACT, not a floor: a floor below the live count lets an assertion vanish with the enumerator still
# above it. Adding or removing an A<nn>_ function changes this number in the same edit.
EXPECTED_ASSERTIONS=9
if [ "$N_LISTED" -ne "$EXPECTED_ASSERTIONS" ]; then
  echo "FIXTURE ERROR: derived $N_LISTED assertion(s) from this file, expected exactly $EXPECTED_ASSERTIONS — the A<nn>_ naming grammar moved, or an assertion was added or removed without updating EXPECTED_ASSERTIONS" >&2
  exit 2
fi

# EVERY DEFINED ASSERTION IS A DISPATCHED ASSERTION, AND THE TWO SIDES USE DIFFERENT GRAMMARS
# ON PURPOSE. A count taken with the enumerator's own regex agrees with the enumerator by
# construction, so it could never fire. This side is deliberately LOOSE: any function whose
# name starts `A<digit>`, with or without `function`, indentation or spacing before `()`. A
# definition the strict enumerator cannot spell is counted here and missed there, and the run
# refuses rather than shipping an arm that runs nowhere.
N_DEFINED="$(grep -cE '^[[:space:]]*(function[[:space:]]+)?A[0-9][A-Za-z0-9_]*[[:space:]]*\(\)' "$0" || true)"
if [ "$N_DEFINED" -ne "$N_LISTED" ]; then
  echo "FIXTURE BROKEN: this file DEFINES $N_DEFINED assertion function(s) but the enumerator lists $N_LISTED." >&2
  echo "  The difference is defined, reads as coverage, and is dispatched by no shard. Rename it to A<nn>[a-z]_i<id>_<what> or widen the enumerator." >&2
  exit 2
fi

# SEED.SH RUNS ONCE PER SHARD, AND THIS FILE HAS EXACTLY ONE CALL SITE FOR IT. The driver's.
# `seed_tree` copies the template; a second call site produces the same trees and the same
# verdicts, so nothing behavioural can see it, and every cell would go back to re-copying the
# live distribution under the tracer. Counted loosely (any `seed.sh` invocation, any quoting)
# against the one expected site.
N_SEED_SITES="$(grep -cE '^[^#]*bash[[:space:]]+"?\$\{?HERE\}?/seed\.sh' "$0" || true)"
if [ "$N_SEED_SITES" -ne 1 ]; then
  echo "FIXTURE BROKEN: this file invokes seed.sh at $N_SEED_SITES site(s); exactly 1 (the shard driver's template build) is expected." >&2
  echo "  Every other tree is a copy of that template. A second call site re-seeds from the live distribution per tree, which is the cost this file was changed to remove." >&2
  exit 2
fi

# `--run-one <assertion>` is one assertion, in one process, against one freshly seeded
# tree. It is the unit the pool schedules and it is also how a human runs a single
# assertion while working on it.
#
# IT RUNS ONLY WHAT THE SHARDS WOULD. A name that is a defined function but not in $NAMES is
# refused, so a hand-run of an undispatched arm fails instead of printing `ok` for a guard the
# suite never executes.
if [ "${1:-}" = "--run-one" ]; then
  FN="${2:-}"
  declare -F "$FN" >/dev/null 2>&1 || {
    echo "FIXTURE ERROR: --run-one needs an assertion function name; '$FN' is not one" >&2
    exit 2
  }
  case "
$NAMES
" in
    *"
$FN
"*) ;;
    *) echo "FIXTURE ERROR: '$FN' is defined but is not in the dispatched assertion list, so no shard runs it; a hand-run here would certify a guard the suite never executes" >&2
       exit 2 ;;
  esac
  # THE LEDGER ARRIVES AS AN ARGUMENT, NEVER AS ENVIRONMENT, for the same reason --group does:
  # this file scrubs every ambient AI_DLC_* name above, so an environment variable would be
  # unset before the line that read it and the selection control at the foot would report a
  # conversion that never happened.
  VRUN_LOG="${3:-}"
  # THE TEMPLATE IS THE THIRD ARGUMENT AFTER THE NAME, and it is also the A40-A43 decoy root.
  # Same predicate `seed.sh` applies to the distribution: a directory carrying the validator.
  EMS_TEMPLATE="${4:-}"
  if [ -z "$EMS_TEMPLATE" ] || [ ! -d "$EMS_TEMPLATE" ] || [ ! -f "$EMS_TEMPLATE/scripts/validate-enforcement-map.sh" ]; then
    echo "FIXTURE ERROR: --run-one needs a seeded template as its 4th argument (EMS_TEMPLATE, after <assertion> and <vrun-ledger>); got '$EMS_TEMPLATE', which is unset, empty, not a directory, or carries no scripts/validate-enforcement-map.sh." >&2
    echo "  Build one by hand with: T=\"\$(bash core/fixtures/enforcement-map-sites/seed.sh)\"; D=\"\$(mktemp -d)\"; cp -RX \"\$T/.\" \"\$D/\"; printf 'seeded\\n' > \"\$D/VERSION\"; git init -q \"\$D\"; bash core/fixtures/enforcement-map-sites/run.sh --run-one $FN \"\" \"\$T\" \"\$D\"" >&2
    echo "  There is no fallback to seed.sh or to the live root on purpose." >&2
    exit 2
  fi
  # THE DECOY IS THE 5TH ARGUMENT: the template plus VERSION and a .git (see EMS_DECOY above).
  EMS_DECOY="${5:-}"
  if [ -z "$EMS_DECOY" ] || [ ! -d "$EMS_DECOY" ] || [ ! -f "$EMS_DECOY/scripts/validate-enforcement-map.sh" ] \
     || [ ! -f "$EMS_DECOY/VERSION" ] || [ ! -d "$EMS_DECOY/.git" ]; then
    echo "FIXTURE ERROR: --run-one needs a decoy root as its 5th argument (EMS_DECOY: the template plus VERSION and a .git); got '$EMS_DECOY', which is unset, empty, not a directory, or lacks scripts/validate-enforcement-map.sh, VERSION or .git." >&2
    echo "  The shard driver builds one; by hand, see the template message's recipe. There is no fallback to the live root on purpose." >&2
    exit 2
  fi
  VRUN_BROKEN="$(mktemp)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
  seed_tree
  trap 'rm -rf "$ROOT"; rm -f "$VRUN_BROKEN"' EXIT
  "$FN"
  # A SELECTION FAILURE IS NOT A FINDING. vrun cannot exit the process from inside a command
  # substitution, so it records here instead; 2 is the code the driver routes to FIXTURE
  # BROKEN, which is the answer "nothing was tested" rather than "the check regressed".
  if [ -s "$VRUN_BROKEN" ]; then
    cat "$VRUN_BROKEN" >&2
    exit 2
  fi
  [ "$fails" -eq 0 ] || exit 1
  exit 0
fi

# ---------------------------------------------------------------------------
# THE SHARD SPLIT
# ---------------------------------------------------------------------------
# The pre-push suite is POLE-BOUND: its makespan tracks its single longest unit, and the unit is a
# DIRECTORY, because `core/fixtures/*/run.sh` is what the outer pool schedules. So the fixture is
# SHARDED ACROSS DIRECTORIES: each shard is a directory the outer pool can start independently.
#
# ROUND-ROBIN, NOT CONTIGUOUS THIRDS: dealing the assertions out in turn spreads cost without a
# cost table that would go stale. The order is the order this file DEFINES them (see the header).
#
# EVERY SHARD RUNS THE CONTROL. A00 is the arm that says the validator is not simply broken, and a
# shard without it would report its own assertions against a tree nobody checked.
SHARDS="a b c"

# THE SHARD ARRIVES AS AN ARGUMENT, NOT AS AN ENVIRONMENT VARIABLE: this file scrubs every ambient
# AI_DLC_* name near the top for I10, and an `AI_DLC_EMS_GROUP` would be unset before this line
# read it, so every shard would silently fall back to 'a'. Arguments survive the scrub.
GROUP=a
if [ "${1:-}" = "--group" ]; then
  GROUP="${2:-}"
  [ -n "$GROUP" ] || { echo "FIXTURE ERROR: --group needs a shard name" >&2; exit 2; }
fi
# THE `eq` GROUP IS NOT A DEALT SHARD, so it is deliberately NOT in SHARDS: that list drives the
# round-robin deal below, and naming `eq` there would hand it assertions. It runs the full-run
# equivalence pairs (eq-pass, eq-refuse, eq-usage) and nothing else, from its own driver directory
# enforcement-map-sites-d, so those full runs and command-line starts sit off the pole.
case " $SHARDS eq " in
  *" $GROUP "*) ;;
  *) echo "FIXTURE ERROR: unknown shard '$GROUP' (known: $SHARDS eq)" >&2; exit 2 ;;
esac

# THE COVERAGE JOIN. Sharding moves assertions out of this directory, so the failure mode it
# introduces is a shard whose directory is deleted, renamed, or never installed: the suite
# then runs fewer assertions and reports a shorter green run. Shard `a` therefore DERIVES the
# set of shards that actually exist beside it and refuses to pass if any declared shard has
# no driver.
if [ "$GROUP" = a ]; then
  missing=""
  for _s in $SHARDS; do
    [ "$_s" = a ] && continue
    [ -f "$HERE/../enforcement-map-sites-$_s/run.sh" ] || missing="$missing $_s"
  done
  # The `eq` group's driver is enforcement-map-sites-d. Without it the full-run equivalence pairs
  # run nowhere and this shard stays green, so its absence refuses the same way.
  [ -f "$HERE/../enforcement-map-sites-d/run.sh" ] || missing="$missing eq(enforcement-map-sites-d)"
  if [ -n "$missing" ]; then
    echo "FIXTURE ERROR: shard(s)$missing declared in SHARDS have no driver directory beside this one." >&2
    echo "  Their assertions would run NOWHERE, and this suite would report a shorter green run." >&2
    exit 2
  fi
fi

NAME="enforcement-map-sites"
[ "$GROUP" = a ] || NAME="enforcement-map-sites-$GROUP"
[ "$GROUP" = eq ] && NAME="enforcement-map-sites-d"

# THE INNER POOL WIDTH, resolved BEFORE the control so a bad value refuses in milliseconds.
# Default 8. The read-set deriver runs every shard with EMS_POOL_WIDTH=1: at 8 the concurrent seed
# copies push the sandbox tracer's `log stream` into dropping reports, and a window carrying a drop
# notice is OMITTED from the map. The width changes the SCHEDULE, not the work.
# NO AI_DLC_ PREFIX, AND HERE THAT IS LOAD-BEARING: the scrub near the top of this file unsets
# every ambient AI_DLC_* name, so a prefixed knob would be gone before this line read it.
# A value that is not an integer from 1 to 64 is FIXTURE BROKEN (exit 2), never a regression:
# `xargs -P 0` means UNLIMITED on BSD, and a non-number makes xargs refuse, which the verdict
# loop below would charge as dropped work. The length is bounded before any numeric test,
# because a 20-digit value overflows `test` into FALSE.
JOBS="${EMS_POOL_WIDTH:-8}"
case "$JOBS" in
  *[!0-9]*) echo "FIXTURE BROKEN: EMS_POOL_WIDTH='$JOBS' is not an integer from 1 to 64" >&2; exit 2 ;;
esac
if [ "${#JOBS}" -gt 3 ] || [ "$JOBS" -lt 1 ] || [ "$JOBS" -gt 64 ]; then
  echo "FIXTURE BROKEN: EMS_POOL_WIDTH='$JOBS' is not an integer from 1 to 64" >&2; exit 2
fi
SELF_W="$HERE/$(basename "$0")"
# The cheap re-entry mode the width arm below drives: the resolved width, and nothing else.
if [ "${1:-}" = "--print-width" ]; then
  printf '%s\n' "$JOBS"; exit 0
fi

echo "$NAME:"

# --- THE WIDTH KNOB: unset is 8, 1 reaches the pool, a bad value is FIXTURE BROKEN ----------
# Shard a only, so the knob is asserted once rather than three times. Driven through
# `--print-width`, which prints the very variable the pool reads. Each cell is presence-shaped:
# a resolver that ignored the knob fails the `1` cell, one that ignored the default fails the
# unset cell, one that accepted anything fails the refusal cells. `env -u` keeps the unset cell
# true when this fixture itself runs under the read-set deriver, where the knob IS set.
if [ "$GROUP" = a ]; then
  w_unset="$(env -u EMS_POOL_WIDTH bash "$SELF_W" --print-width 2>/dev/null)"; w_unset_rc=$?
  w_one="$(EMS_POOL_WIDTH=1 bash "$SELF_W" --print-width 2>/dev/null)"; w_one_rc=$?
  EMS_POOL_WIDTH=0 bash "$SELF_W" --print-width >/dev/null 2>&1; w_zero_rc=$?
  EMS_POOL_WIDTH=abc bash "$SELF_W" --print-width >/dev/null 2>&1; w_abc_rc=$?
  EMS_POOL_WIDTH=99999999999999999999 bash "$SELF_W" --print-width >/dev/null 2>&1; w_big_rc=$?
  EMS_POOL_WIDTH=65 bash "$SELF_W" --print-width >/dev/null 2>&1; w_65_rc=$?
  w_64="$(EMS_POOL_WIDTH=64 bash "$SELF_W" --print-width 2>/dev/null)"; w_64_rc=$?
  if [ "$w_unset_rc:$w_unset" = "0:8" ]; then
    ok "WIDTH: with EMS_POOL_WIDTH unset the inner pool width resolves to 8"
  else
    bad "WIDTH: with EMS_POOL_WIDTH unset --print-width gave rc $w_unset_rc and '$w_unset' (expected 0 and 8) — the pre-push default moved"
  fi
  if [ "$w_one_rc:$w_one" = "0:1" ]; then
    ok "WIDTH: EMS_POOL_WIDTH=1 resolves the inner pool width to 1, so the deriver's knob reaches the pool"
  else
    bad "WIDTH: EMS_POOL_WIDTH=1 gave rc $w_one_rc and '$w_one' (expected 0 and 1) — the deriver's knob does not reach the pool"
  fi
  if [ "$w_zero_rc" -eq 2 ] && [ "$w_abc_rc" -eq 2 ]; then
    ok "WIDTH: EMS_POOL_WIDTH=0 and =abc both exit 2 (FIXTURE BROKEN), never a regression"
  else
    bad "WIDTH: a bad width was not refused at exit 2: '0' exited $w_zero_rc, 'abc' exited $w_abc_rc"
  fi
  if [ "$w_big_rc" -eq 2 ] && [ "$w_65_rc" -eq 2 ] && [ "$w_64_rc:$w_64" = "0:64" ]; then
    ok "WIDTH: a 20-digit width and 65 both exit 2 (FIXTURE BROKEN), and 64 still resolves to 64"
  else
    bad "WIDTH: the width ceiling is wrong: 20 digits exited $w_big_rc and 65 exited $w_65_rc (expected 2 and 2); 64 gave rc $w_64_rc and '$w_64' (expected 0 and 64)"
  fi
fi

OUT="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
TPL=""
DCY=""
trap 'rm -rf "$OUT"; [ -n "$TPL" ] && rm -rf "$TPL"; [ -n "$DCY" ] && rm -rf "$DCY"' EXIT
SELF="$HERE/$(basename "$0")"

# THE SHARD'S ONE SEED AND ONE DECOY, built ABOVE the control so the control runs on the same
# trees as every cell after it. Every `--run-one` copies the template; A40-A43 run their C2, C4
# and full-mode cells from the decoy (the template plus a seeded VERSION and a
# `git init`). Two checks before anything reads them, and the second is repeated after the pool:
#   presence  -- the validator, preclassify, and templates/ (I22 joins against
#                templates/settings.json.template; seed.sh copies it for that reason), and for
#                the decoy also VERSION and .git;
#   integrity -- a file count and an md5 over the sorted (path, md5) list of every file in each,
#                derived with `find` (never `git ls-files`, which cannot see an untracked file).
#                Re-taken after the pool: a cell that wrote into a shared tree -- rather than its
#                own copy -- changes it. tree_state RECORDS the directory it actually hashed, and
#                that is compared against the very paths handed to the cells.
# --- THE EQUIVALENCE CELLS: full runs in the `eq` group (enforcement-map-sites-d),
# --- `--arms I12` in shard a ------------------------------------------------------------------------
# Every run in the cells is `vem_entry`, the validator evaluated inside this process. These cells
# prove that answer IS the program's: for each distinct command-line outcome, the in-process call and
# a command-line start of the same file, from the same cwd, under this file's own `set -uo pipefail`,
# must agree byte for byte on stdout, on stderr and on the exit code.
#   eq-pass    a FULL run of a pristine copy of the template: exit 0, every arm, I49, I53, I60 and
#              I107 (the four `--exclude` reads of the self path) included.
#   eq-refuse  a FULL run of a copy carrying an offender (a core subtree with no destination row):
#              exit 1.
#   eq-usage   `--bogus` on the pristine copy: exit 2.
# Those three are the `cli` rows of enforcement-map-sites-d's cells.decl and run in the `eq` group
# alone, which builds the seed and nothing else (below the seed): no decoy, no control, no pool. It
# carries no A00: eq-pass's own predicate (exit 0 and the verdict block's OK line) is the full run
# over the pristine tree that A00 would have been.
# Shard a alone carries the pair eq-arms-pass and eq-arms-refuse, on the same two trees through the
# selected form every one of its cells uses: `--arms I12`, an arm the refusing tree's offender trips.
# Shards b and c build the same template from the same distribution and would run the same pair on
# the same bytes, so they carry none; shard a's cells.decl carries the two rows.
# The two inputs DIFFER and are asserted to: the refusing run must exit 1 and name the offender, the
# passing one exit 0 and print the verdict block's OK line, so two empty or two crashed runs cannot
# read as agreement. Each copy's validator is sourced once, in the subshell that runs its in-process
# half.
EQ_DIR=""
eq_pair() { # eq_pair <tree> <tag> <cli cell id> [args...] -> $EQ_DIR/<tag>.{i,c}.{out,err,rc}
  local t="$1" tag="$2" cell="$3"; shift 3
  ( cd "$t" || exit 2
    ( . "$t/scripts/validate-enforcement-map.sh" || exit 2; fx_inproc "$t/scripts/validate-enforcement-map.sh"; vem_entry "$@" ) > "$EQ_DIR/$tag.i.out" 2> "$EQ_DIR/$tag.i.err"
    printf '%s\n' "$?" > "$EQ_DIR/$tag.i.rc"
    FXCELL="$cell" bash "$t/scripts/validate-enforcement-map.sh" "$@" > "$EQ_DIR/$tag.c.out" 2> "$EQ_DIR/$tag.c.err"
    printf '%s\n' "$?" > "$EQ_DIR/$tag.c.rc" )
}
eq_start() {
  EQ_DIR="$OUT/eq"
  mkdir -p "$EQ_DIR/pass" "$EQ_DIR/refuse" || { echo "$NAME: FIXTURE ERROR — could not create the equivalence trees" >&2; exit 2; }
  cp -RX "$CELL_TPL/." "$EQ_DIR/pass/" && cp -RX "$CELL_TPL/." "$EQ_DIR/refuse/" \
    && mkdir -p "$EQ_DIR/refuse/core/brand-new-subtree" && printf 'x\n' > "$EQ_DIR/refuse/core/brand-new-subtree/thing.sh" \
    || { echo "$NAME: FIXTURE ERROR — could not build the equivalence trees from the template" >&2; exit 2; }
  # The two full-run pairs are the `eq` group's whole cost, so they run side by side, each waited on
  # by its own pid in eq_finish.
  if [ "$GROUP" = eq ]; then
    eq_pair "$EQ_DIR/pass" pass eq-pass &
    EQ_PID_PASS=$!
    eq_pair "$EQ_DIR/refuse" refuse eq-refuse &
    EQ_PID_REFUSE=$!
  fi
}
EQ_TAGS="arms-pass arms-refuse"
[ "$GROUP" = eq ] && EQ_TAGS="pass refuse usage"
eq_finish() {
  local t ok_t want_rc want_say
  if [ "$GROUP" = eq ]; then
    wait "$EQ_PID_PASS"; wait "$EQ_PID_REFUSE"
    eq_pair "$EQ_DIR/pass" usage eq-usage --bogus
  else
    eq_pair "$EQ_DIR/pass" arms-pass eq-arms-pass --arms I12
    eq_pair "$EQ_DIR/refuse" arms-refuse eq-arms-refuse --arms I12
  fi
  for t in $EQ_TAGS; do
    case "$t" in
      pass|arms-pass)     want_rc=0; want_say='^OK: enforcement-map.yaml in sync' ;;
      refuse)             want_rc=1; want_say='core/brand-new-subtree/ has no destination row' ;;
      arms-refuse)        want_rc=1; want_say='core/brand-new-subtree/ has no drift-scan policy row' ;;
      usage)              want_rc=2; want_say='^usage: validate-enforcement-map\.sh ' ;;
    esac
    ok_t=1
    for f in "$EQ_DIR/$t.i.rc" "$EQ_DIR/$t.c.rc"; do [ -s "$f" ] || ok_t=0; done
    if [ "$ok_t" = 0 ]; then
      bad "EQUIVALENCE eq-$t: a half recorded no exit status, so the pair never ran to a verdict"
    elif [ "$(cat "$EQ_DIR/$t.i.rc")" != "$want_rc" ] || ! grep -qE -- "$want_say" "$EQ_DIR/$t.i.out" "$EQ_DIR/$t.i.err"; then
      bad "EQUIVALENCE eq-$t: the in-process run exited $(cat "$EQ_DIR/$t.i.rc") (expected $want_rc) or did not print /$want_say/, so this pair does not hold the outcome it is the pair for: $(head -2 "$EQ_DIR/$t.i.err" | tr '\n' ' ' | cut -c1-200)"
    elif [ "$(cat "$EQ_DIR/$t.i.rc")" = "$(cat "$EQ_DIR/$t.c.rc")" ] && cmp -s "$EQ_DIR/$t.i.out" "$EQ_DIR/$t.c.out" && cmp -s "$EQ_DIR/$t.i.err" "$EQ_DIR/$t.c.err"; then
      ok "EQUIVALENCE eq-$t: the in-process vem_entry run and the command-line run agree byte for byte on stdout ($(grep -c '' < "$EQ_DIR/$t.i.out") line(s)), stderr ($(grep -c '' < "$EQ_DIR/$t.i.err") line(s)) and exit $want_rc"
    else
      bad "EQUIVALENCE eq-$t: the in-process run and the command-line run DIFFER (exit $(cat "$EQ_DIR/$t.i.rc") vs $(cat "$EQ_DIR/$t.c.rc")): $(diff "$EQ_DIR/$t.i.out" "$EQ_DIR/$t.c.out" | head -3 | tr '\n' ' ' | cut -c1-160) $(diff "$EQ_DIR/$t.i.err" "$EQ_DIR/$t.c.err" | head -3 | tr '\n' ' ' | cut -c1-160)"
    fi
  done
  local p=arms-pass r=arms-refuse
  [ "$GROUP" = eq ] && { p=pass; r=refuse; }
  if cmp -s "$EQ_DIR/$p.i.err" "$EQ_DIR/$r.i.err" && cmp -s "$EQ_DIR/$p.i.out" "$EQ_DIR/$r.i.out"; then
    bad "EQUIVALENCE: the passing and the refusing trees produced IDENTICAL output, so the two inputs do not differ and the pairs prove one outcome twice"
  fi
}

TPL="$(bash "$HERE/seed.sh")" || { echo "$NAME: FIXTURE ERROR — seed.sh failed to build the shard template" >&2; exit 2; }
# THE `eq` GROUP STOPS HERE: the seed is its only shared tree, and the equivalence cells above are its
# whole assertion set. Every tag must have printed exactly one EQUIVALENCE verdict line, counted from
# this run's own output, so a tag list that ran nothing cannot report PASS.
if [ "$GROUP" = eq ]; then
  [ -f "$TPL/scripts/validate-enforcement-map.sh" ] || { echo "$NAME: FIXTURE ERROR — the seed template $TPL carries no scripts/validate-enforcement-map.sh" >&2; exit 2; }
  CELL_TPL="$TPL"
  eq_start
  EQ_LOG="$OUT/eq.log"
  eq_finish > "$EQ_LOG"
  cat "$EQ_LOG"
  eq_want="$(printf '%s\n' $EQ_TAGS | grep -c .)" || eq_want=0
  eq_got="$(grep -cE '^  (ok    |FAIL  )EQUIVALENCE eq-' "$EQ_LOG")" || eq_got=0
  if [ "$eq_want" -ne 3 ] || [ "$eq_got" -ne "$eq_want" ]; then
    bad "EQUIVALENCE: the eq group printed $eq_got per-tag verdict line(s) for $eq_want tag(s) (expected 3 and 3), so a pair never reached a verdict"
  fi
  echo
  report_end "$NAME"
fi
DCY="$(mktemp -d "${TMPDIR:-/tmp}/enforcement-map-sites-decoy.XXXXXX")" || { echo "$NAME: FIXTURE ERROR — mktemp failed for the decoy" >&2; exit 2; }
cp -RX "$TPL/." "$DCY/" && printf 'seeded\n' > "$DCY/VERSION" \
  && ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY; git init -q "$DCY" ) >/dev/null 2>&1 \
  || { echo "$NAME: FIXTURE ERROR — could not build the decoy root $DCY (copy of the template, a seeded VERSION, git init)" >&2; exit 2; }
for _p in scripts/validate-enforcement-map.sh core/skills/ai-dlc-update/reconcile/preclassify.sh templates/settings.json.template; do
  [ -f "$TPL/$_p" ] || { echo "$NAME: FIXTURE ERROR — the seed template $TPL carries no $_p" >&2; exit 2; }
  [ -f "$DCY/$_p" ] || { echo "$NAME: FIXTURE ERROR — the decoy root $DCY carries no $_p" >&2; exit 2; }
done
[ -f "$DCY/VERSION" ] && [ -d "$DCY/.git" ] || { echo "$NAME: FIXTURE ERROR — the decoy root $DCY lacks VERSION or .git" >&2; exit 2; }
[ ! -e "$TPL/VERSION" ] || { echo "$NAME: FIXTURE ERROR — the seed template $TPL carries VERSION; seeded trees must not (the validator's I45 guard)" >&2; exit 2; }
# tree_state <dir> -> "<physical dir it hashed> <file count> <digest>"
tree_state() {
  (cd "$1" && printf '%s %s %s\n' "$(pwd -P)" "$(find . -type f | grep -c .)" \
     "$(find . -type f -print0 | LC_ALL=C sort -z | xargs -0 md5 -r | md5 -q)")
}
# The paths every cell is handed, fixed once here and used by the control, the pool AND the checks.
CELL_TPL="$TPL"
CELL_DCY="$DCY"
TPL_S0="$(tree_state "$CELL_TPL")"
DCY_S0="$(tree_state "$CELL_DCY")"
for _s in "$TPL_S0" "$DCY_S0"; do
  set -- $_s
  if [ "$#" -ne 3 ] || [ "${2:-0}" -lt 100 ]; then
    echo "$NAME: FIXTURE ERROR — a shared seed tree reads '$_s'; a partial tree is a decoy that discriminates nothing" >&2
    exit 2
  fi
done
set --

# The control, first and alone. Its verdict licenses every assertion after it, so a failure
# here stops the run rather than reporting unattributable verdicts.
CTL="$(printf '%s\n' "$NAMES" | head -1)"
bash "$SELF" --run-one "$CTL" "$OUT/$CTL.vrun" "$CELL_TPL" "$CELL_DCY" > "$OUT/$CTL" 2>"$OUT/$CTL.err"
ctl_rc=$?
cat "$OUT/$CTL"
# The control's ok lines count too, so the summary equals the ok lines printed.
_wok="$(grep -c '^  ok    ' "$OUT/$CTL")" || _wok=0
oks=$((oks + _wok))
if [ "$ctl_rc" -ne 0 ]; then
  [ -s "$OUT/$CTL.err" ] && cat "$OUT/$CTL.err" >&2
  echo
  echo "$NAME: 1 assertion(s) FAILED" >&2
  exit 2
fi

# The `--arms I12` equivalence trees (shard a only), built from the template the cells use; the pair
# runs after the pool, in eq_finish. The functions and the reasoning are above the seed.
[ "$GROUP" = a ] && eq_start

# EIGHT BY DEFAULT, and the pre-push suite never sets EMS_POOL_WIDTH: this pool nests inside
# the suite's own pool, so the product is what lands on the machine. The knob exists only so
# the read-set deriver can narrow the schedule; JOBS is resolved above.
# Deal the non-control assertions out to the shards in turn. The partition is DERIVED from
# the same list the control came off, so an assertion added to this file lands in a shard
# automatically rather than needing a table updated in a second place.
printf '%s\n' "$NAMES" | tail -n +2 \
  | awk -v g="$GROUP" -v shards="$SHARDS" '
      BEGIN { n = split(shards, S, " ") }
      { if (S[((NR - 1) % n) + 1] == g) print }
    ' > "$OUT/list"
N_MINE="$(grep -c . "$OUT/list" || true)"
if [ "$N_MINE" -eq 0 ]; then
  echo "$NAME: FIXTURE ERROR — shard '$GROUP' was dealt no assertions out of $N_LISTED; an empty shard passes every assertion it never made" >&2
  exit 2
fi
# The template and the decoy reach each worker as positional arguments ($2, $3), never
# environment names.
AI_DLC_EMS_SELF="$SELF" AI_DLC_EMS_OUT="$OUT" \
  xargs -P "$JOBS" -I{} bash -c '
    n="$1"
    bash "$AI_DLC_EMS_SELF" --run-one "$n" "$AI_DLC_EMS_OUT/$n.vrun" "$2" "$3" \
      > "$AI_DLC_EMS_OUT/$n" 2> "$AI_DLC_EMS_OUT/$n.err"
    printf %s $? > "$AI_DLC_EMS_OUT/$n.rc"
  ' _ {} "$CELL_TPL" "$CELL_DCY" < "$OUT/list"

# THE `--arms I12` EQUIVALENCE PAIR runs and is read here, after the pool (see eq_start, above the seed).
[ "$GROUP" = a ] && eq_finish

TPL_S1="$(tree_state "$CELL_TPL")"
DCY_S1="$(tree_state "$CELL_DCY")"
for _pair in "template|$CELL_TPL|$TPL_S0|$TPL_S1" "decoy|$CELL_DCY|$DCY_S0|$DCY_S1"; do
  _what="${_pair%%|*}"; _r="${_pair#*|}"; _dir="${_r%%|*}"; _r="${_r#*|}"; _s0="${_r%%|*}"; _s1="${_r#*|}"
  _phys="$(cd "$_dir" && pwd -P)"
  if [ "${_s0%% *}" != "$_phys" ] || [ "${_s1%% *}" != "$_phys" ]; then
    echo "$NAME: FIXTURE BROKEN — the $_what integrity check hashed '${_s0%% *}' / '${_s1%% *}', not the directory handed to the cells ($_phys), so it compared readings of a tree no cell used." >&2
    exit 2
  fi
  if [ "$_s0" != "$_s1" ]; then
    echo "$NAME: FIXTURE BROKEN — the shared $_what changed during the pool ('$_s0' before, '$_s1' after). A cell wrote into it instead of its own copy, so the cells after that write ran against a tree nobody seeded." >&2
    exit 2
  fi
done

# Rendered in SOURCE order, never completion order, so the output is diffable across runs.
#
# A MISSING VERDICT IS A FAILURE, not a gap. With a pool a dropped job is silent, so the verdict
# file's absence is asserted, and a worker that exited nonzero without printing a FAIL line (a
# crash, a failed seed) is charged one rather than counted as clean.
while IFS= read -r n; do
  [ -n "$n" ] || continue
  if [ ! -f "$OUT/$n.rc" ]; then
    printf '  FAIL  %s produced no verdict — the pool dropped work, and a short green run reads exactly like a passing one\n' "$n"
    fails=$((fails + 1))
    continue
  fi
  cat "$OUT/$n"
  # A worker's ok lines count here, as its FAIL lines do below, so the summary equals the ok lines printed.
  _wok="$(grep -c '^  ok    ' "$OUT/$n")" || _wok=0
  oks=$((oks + _wok))
  [ -s "$OUT/$n.err" ] && cat "$OUT/$n.err" >&2
  wrc="$(cat "$OUT/$n.rc")"
  # 2 IS NOT 1. `FIXTURE BROKEN` (a failed seed) and `an assertion regressed` are different
  # answers, and routing an assertion through a worker would otherwise collapse them.
  if [ "$wrc" = "2" ]; then broken=1; fi
  if [ "$wrc" != "0" ]; then
    c="$(grep -c '^  FAIL' "$OUT/$n" || true)"
    [ "$c" -gt 0 ] || { printf '  FAIL  %s exited nonzero without an assertion line — the assertion did not run to a verdict\n' "$n"; c=1; }
    fails=$((fails + c))
  fi
done < "$OUT/list"

# THE SELECTION CONTROL: A CONVERSION THAT STOPS SELECTING MUST BE RED, NOT MERELY SLOW.
# Each assertion runs the validator through `vrun`, which records the id it selected into a
# per-assertion ledger. A `vrun` call reverted to a full `bash "$V"` still passes its own
# predicate -- a full run contains everything a selected run would have printed -- so nothing
# in the assertions themselves can notice, and the only symptom would be the wall clock going
# back to where it was.
#
# BOTH SIDES ARE DERIVED, and neither is a list. The expectation is this shard's own dealt
# assertion list; the observation is which of those wrote a ledger. The complement is derived
# too: the control assertion -- the one deliberately left on a FULL run -- must have recorded
# nothing, so a control that quietly started selecting fails here as well. An empty dealt list
# is already a FIXTURE ERROR above, which is what stops this join being satisfied by having no
# subjects.
sel_got=0
sel_bad=""
while IFS= read -r n; do
  [ -n "$n" ] || continue
  if [ -s "$OUT/$n.vrun" ]; then sel_got=$((sel_got + 1)); else sel_bad="$sel_bad $n"; fi
done < "$OUT/list"
if [ -s "$OUT/$CTL.vrun" ]; then sel_bad="$sel_bad $CTL(selected an arm; it must stay a full run)"; fi
if [ "$sel_got" -ne "$N_MINE" ] || [ -n "$sel_bad" ]; then
  printf '  FAIL  arm selection did not happen as dealt: %d of %d assertion(s) in shard %s recorded an --arms run (offenders:%s). Every assertion but the control selects the one arm it tests; one that stopped is running every arm and asserting nothing more for it\n' "$sel_got" "$N_MINE" "$GROUP" "$sel_bad"
  fails=$((fails + 1))
fi

echo
if [ "$broken" -ne 0 ]; then
  echo "$NAME: FIXTURE BROKEN — an assertion could not run to a verdict" >&2
  exit 2
fi
report_end "$NAME"
