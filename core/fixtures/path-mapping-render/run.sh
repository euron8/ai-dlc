#!/usr/bin/env bash
# Exercise scripts/render-path-mapping.sh -- the renderer that derives the
# `## Path mapping (core/ -> consumer)` region of core/skills/ai-dlc-update/SKILL.md from
# map_consumer() in core/skills/ai-dlc-update/reconcile/preclassify.sh, and byte-compares it
# with `--check` at pre-push.
#
# Five controls plus six mutants and one near-miss, each a throwaway repo under a temp dir.
# Exit 0 iff every control is green, every mutant is killed by its OWN message, and the
# near-miss leaves `--check` silent.
#
#   controlA  the REAL repo: `--check` against the committed region        -> must PASS
#   controlB  a legacy hand-written section: `--write` repairs all four
#             PC-S330 defects, and the result survives its own `--check`   -> must PASS
#   controlC  `--write` is idempotent, and prose outside the region lives  -> must PASS
#   controlD  an arm added to the SANDBOX's own map_consumer() renders,
#             above the `core/` catch-all                                  -> must PASS
#   controlE  `--check` answers identically from three working directories -> must PASS
#   m1  arm-deleted   `core/git-hooks/*` removed from map_consumer()       -> must FAIL
#   m2  hand-edited   the rendered destination retyped in SKILL.md         -> must FAIL
#   m3  region-gone   the section's heading deleted from SKILL.md          -> must FAIL
#   m4  grammar       the `case` arms reformatted past the extractor        -> must FAIL
#   m5  no-loader     map_consumer() renamed, so the scrape defines nothing -> must FAIL
#   m6  source-gone   preclassify.sh absent                                 -> must FAIL
#   n1  near-miss     a change to preclassify.sh OUTSIDE map_consumer()     -> must stay QUIET
#
# WHY THIS FIXTURE IS THE ONLY EVIDENCE THE RENDERER WORKS. Its finding set over the real
# tree is EMPTY by design -- a green `--check` is the steady state, and a renderer whose
# extractor stopped matching, or whose scrape stopped defining map_consumer(), would print a
# green line too. Every arm below exists to prove one specific way the thing can still fail.
#
# WHY THE SUBJECT'S FAIL-CLOSED PATHS GET THEIR OWN MUTANTS. m4, m5 and m6 are the three ways
# the renderer can be handed a source it cannot read. Each of them, unguarded, renders an
# EMPTY table which byte-compares clean against a region someone emptied. Asking "would this
# arm pass against a subject replaced by `exit 0`" is what put them here: every verdict in
# this file asserts a POSITIVE message, so a subject that emits nothing scores no kills and
# no controls.
#
# WHY controlD EXISTS AND WHY IT INSERTS AN ARM NO REAL SOURCE HAS. A mutation applied to a
# file the run never loaded leaves every arm green and reads exactly like an arm that cannot
# fire -- `cmp -s` does not catch it, because the mutation applied cleanly. controlD renders a
# `core/probe-marker/*` row that exists nowhere in this repository; if it appears, the sandbox
# is genuinely the tree the renderer resolved.
#
# MEASURED, so the arm is not credited with more than it does: against a subject rewired to
# resolve a FIXED foreign tree, controlB fires first -- the sandbox's SKILL.md keeps its
# hand-written rows and the repair assertion catches it. What controlD detects on its own is
# the pair controlB cannot see: a new arm failing to appear at all, and the rows being
# re-sorted out of the `case`'s own precedence order. A subject that sorts the extracted
# patterns passes controlA, controlB and controlC, and is killed here.
#
# WHY `cmp -s` GUARDS EVERY MUTATION. A sed or awk whose pattern stopped matching produces a
# byte-identical copy; `--check` then correctly passes and the arm reports SURVIVED for a
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
  if [ -f "$cand/scripts/render-path-mapping.sh" ] && [ -f "$cand/VERSION" ]; then
    REPO="$(cd "$cand" && pwd)"; RENDERER="$REPO/scripts/render-path-mapping.sh"; break
  fi
done
if [ -z "$RENDERER" ]; then
  echo "run.sh: could not locate scripts/render-path-mapping.sh from $DIR" >&2
  exit 2
fi

SRC_PRECLASS="$REPO/core/skills/ai-dlc-update/reconcile/preclassify.sh"
SRC_SKILL="$REPO/core/skills/ai-dlc-update/SKILL.md"
if [ ! -f "$SRC_PRECLASS" ] || [ ! -f "$SRC_SKILL" ]; then
  echo "run.sh: the renderer's own source or target is missing under $REPO" >&2
  exit 2
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
rc=0
note() { printf '%s\n' "$*"; }

HEADING='## Path mapping (core/ → consumer)'
OK_MSG='render-path-mapping: OK'
OK_TAIL='path-mapping region matches map_consumer()'

# --- the seed ---------------------------------------------------------------
# THE SOURCE IS THE REAL PRODUCER, COPIED. A hand-written toy map_consumer() would be a seed
# derived from what the extractor accepts, and it would stay green through a change to both.
# The SKILL.md half is seeded in its PRE-FIX state: the four-ways-wrong hand-written table
# PC-S330 was filed against -- `core/scripts/<x>` claiming the stale `scripts/<x>`, and the
# fixtures, ci-templates and git-hooks subtrees simply absent.
seed() {
  local d="$1"
  mkdir -p "$d/scripts" "$d/core/skills/ai-dlc-update/reconcile"
  echo "0.0.0" > "$d/VERSION"
  cp "$RENDERER" "$d/scripts/render-path-mapping.sh"
  cp "$SRC_PRECLASS" "$d/core/skills/ai-dlc-update/reconcile/preclassify.sh"
  cat > "$d/core/skills/ai-dlc-update/SKILL.md" <<EOF
# ai-dlc-update

PREAMBLE-SENTINEL: prose above the region, which a region rewrite must not touch.

$HEADING

| core path | consumer destination |
|-----------|----------------------|
| \`core/scripts/<x>\` | \`scripts/<x>\` |
| \`core/<x>\` | \`.claude/<x>\` |

## Reconcile

TRAILER-SENTINEL: prose below the region, which a region rewrite must not touch.
EOF
}

# Sandbox invocations run from a NEUTRAL working directory -- never the sandbox, never the
# repo root. The renderer resolves its root from \$0; running it from a cwd that agrees with
# that root would hide a cwd-derived resolution rather than exercise it.
render_in() { ( cd "$TMP" && bash "$1/scripts/render-path-mapping.sh" 2>&1 ); }
write_in()  { ( cd "$TMP" && bash "$1/scripts/render-path-mapping.sh" --write 2>&1 ); }
check_in()  { ( cd "$TMP" && bash "$1/scripts/render-path-mapping.sh" --check 2>&1 ); }

skill_of() { printf '%s\n' "$1/core/skills/ai-dlc-update/SKILL.md"; }
preclass_of() { printf '%s\n' "$1/core/skills/ai-dlc-update/reconcile/preclassify.sh"; }

# prep: seed and render. A failed `--write` makes every verdict below it meaningless, so it
# aborts the whole unit rather than being reported as a kill.
prep() {
  local d="$1" out
  seed "$d"
  if ! out="$(write_in "$d")"; then
    note "FIXTURE BROKEN: --write failed while preparing ${d##*/}."
    printf '%s\n' "$out" | sed 's/^/      /' | head -6
    exit 1
  fi
}

mutate() { # mutate <file> <sed-expr> ; guarded so a no-op sed cannot pass as a mutation
  local f="$1" expr="$2"
  cp "$f" "$f.orig"
  sed "$expr" "$f.orig" > "$f"
  if cmp -s "$f" "$f.orig"; then rm -f "$f.orig"; return 1; fi
  rm -f "$f.orig"; return 0
}

mutate_awk() { # mutate_awk <file> <awk-prog> ; same guard, for edits sed cannot express
  local f="$1" prog="$2"
  cp "$f" "$f.orig"
  awk "$prog" "$f.orig" > "$f"
  if cmp -s "$f" "$f.orig"; then rm -f "$f.orig"; return 1; fi
  rm -f "$f.orig"; return 0
}

kill_check() { # kill_check <name> <dir> <expected-substring>
  local n="$1" d="$2" pat="$3" out rc_v
  out="$(check_in "$d")"; rc_v=$?
  if [ "$rc_v" -eq 0 ]; then
    note "FAIL  $n -- mutant SURVIVED (--check exited 0)"; rc=1; return
  fi
  if ! grep -qF "$pat" <<<"$out"; then
    note "FAIL  $n -- --check failed, but not on its own assertion (wanted: $pat)"
    printf '%s\n' "$out" | sed 's/^/      /' | head -5; rc=1; return
  fi
  note "ok    $n -- killed by its own arm"
}

quiet_check() { # quiet_check <name> <dir>
  local n="$1" d="$2" out rc_v
  out="$(check_in "$d")"; rc_v=$?
  if [ "$rc_v" -ne 0 ] || ! grep -qF "$OK_TAIL" <<<"$out"; then
    note "FAIL  $n -- a change that does not touch map_consumer() disturbed --check"
    printf '%s\n' "$out" | sed 's/^/      /' | head -6; rc=1; return
  fi
  note "ok    $n -- quiet, as a change outside map_consumer() must be"
}

no_mutation() { note "FAIL  $1 -- the mutation matched nothing; no mutant was built"; rc=1; }

# --- controlA: the real repo ------------------------------------------------
if outA="$( cd "$REPO" && bash scripts/render-path-mapping.sh --check 2>&1 )" \
   && grep -qF "$OK_TAIL" <<<"$outA"; then
  # PC-S330 BY NAME. The git-hooks omission is the one that cost a consumer a silent no-op
  # self-update -- the hook written to `.claude/git-hooks/pre-push`, an inert orphan, while
  # every gate went green because the live hook was never touched.
  if grep -qF '| `core/git-hooks/<x>` | `.githooks/<x>` |' "$SRC_SKILL"; then
    note "ok    controlA   the committed region matches map_consumer(), git-hooks row present"
  else
    note "FIXTURE BROKEN: --check passes on the real repo but the git-hooks row is not in SKILL.md."
    exit 1
  fi
else
  note "FIXTURE BROKEN: --check does not pass against the real repo. Every verdict below is meaningless."
  printf '%s\n' "$outA" | sed 's/^/      /' | head -8
  exit 1
fi

# --- controlB: the legacy hand-written section, repaired --------------------
prep "$TMP/controlB"
B_SKILL="$(skill_of "$TMP/controlB")"
b_bad=""
for row in \
  '| `core/scripts/<x>` | `scripts/ai-dlc/<x>` |' \
  '| `core/fixtures/<x>` | `tests/fixtures/<x>` |' \
  '| `core/ci-templates/<x>` | `.github/workflows/<x>` |' \
  '| `core/git-hooks/<x>` | `.githooks/<x>` |' \
  '| `core/<x>` | `.claude/<x>` |'
do
  grep -qF "$row" "$B_SKILL" || b_bad="$b_bad
      missing row: $row"
done
# The stale row is the fourth defect, and a WRONG row is worse than a missing one: the reader
# does not go and look, because the section answered. Its removal is asserted, not assumed.
if grep -qF '| `core/scripts/<x>` | `scripts/<x>` |' "$B_SKILL"; then
  b_bad="$b_bad
      stale row survived: | \`core/scripts/<x>\` | \`scripts/<x>\` |"
fi
if [ -n "$b_bad" ]; then
  note "FIXTURE BROKEN: --write did not repair the four PC-S330 defects.$b_bad"
  exit 1
fi
if outB="$(check_in "$TMP/controlB")" && grep -qF "$OK_TAIL" <<<"$outB"; then
  note "ok    controlB   hand-written section repaired by --write and round-trips through --check"
else
  note "FIXTURE BROKEN: a freshly written region did not survive its own --check."
  printf '%s\n' "$outB" | sed 's/^/      /' | head -6
  exit 1
fi

# --- controlC: idempotence, and prose outside the region ---------------------
prep "$TMP/controlC"
C_SKILL="$(skill_of "$TMP/controlC")"
cp "$C_SKILL" "$TMP/controlC.after-first-write"
if ! outC="$(write_in "$TMP/controlC")"; then
  note "FIXTURE BROKEN: the second --write failed."
  printf '%s\n' "$outC" | sed 's/^/      /' | head -6
  exit 1
fi
c_bad=""
cmp -s "$C_SKILL" "$TMP/controlC.after-first-write" || c_bad="$c_bad
      a second --write changed the file; the region rewrite is not idempotent"
grep -qF 'PREAMBLE-SENTINEL' "$C_SKILL" || c_bad="$c_bad
      prose above the region was destroyed"
grep -qF 'TRAILER-SENTINEL' "$C_SKILL" || c_bad="$c_bad
      prose below the region was destroyed"
grep -qF '## Reconcile' "$C_SKILL" || c_bad="$c_bad
      the heading after the region was destroyed"
if [ -n "$c_bad" ]; then
  note "FIXTURE BROKEN: --write is not a region rewrite.$c_bad"
  exit 1
fi
note "ok    controlC   --write is idempotent and leaves everything outside the region alone"

# --- controlD: the sandbox's OWN map_consumer() is what gets rendered --------
# The inserted arm exists in no real source in this repository, so its row can only come from
# the sandbox copy. This is the arm that separates "the mutants are being read" from "the
# renderer resolved the real repo root and every mutation was applied to a file nobody read".
seed "$TMP/controlD"
if mutate_awk "$(preclass_of "$TMP/controlD")" '
  /^map_consumer\(\) \{/ { inf=1 }
  inf && /^\}/           { inf=0 }
  inf && !ins && /^[[:space:]]*core\/\*\)/ {
    print "    core/probe-marker/*) echo \"probe-dest/${1#core/probe-marker/}\" ;;"
    ins=1
  }
  { print }
'; then
  if ! outD="$(write_in "$TMP/controlD")"; then
    note "FIXTURE BROKEN: --write failed on the probe-arm sandbox."
    printf '%s\n' "$outD" | sed 's/^/      /' | head -6
    exit 1
  fi
  D_SKILL="$(skill_of "$TMP/controlD")"
  d_probe="$(grep -nF '| `core/probe-marker/<x>` | `probe-dest/<x>` |' "$D_SKILL" | head -1 | cut -d: -f1)"
  d_catch="$(grep -nF '| `core/<x>` | `.claude/<x>` |' "$D_SKILL" | head -1 | cut -d: -f1)"
  if [ -z "$d_probe" ]; then
    note "FAIL  controlD   the sandbox's own new arm did not render; the renderer read some other tree"
    grep -n '^| ' "$D_SKILL" | sed 's/^/      /'; rc=1
  elif [ -z "$d_catch" ] || [ "$d_probe" -ge "$d_catch" ]; then
    # First match wins in a `case`, so a specific subtree rendered BELOW the catch-all is a
    # table that lies about precedence.
    note "FAIL  controlD   the new arm rendered at or below the core/ catch-all; precedence is not source order"
    grep -n '^| ' "$D_SKILL" | sed 's/^/      /'; rc=1
  else
    note "ok    controlD   a new arm renders from the sandbox's own source, above the catch-all"
  fi
else
  no_mutation "controlD"
fi

# --- controlE: --check is cwd-invariant --------------------------------------
# The renderer walks up from `$0` for a VERSION marker rather than counting `..` hops, and a
# fixture that is green only from one cwd may be asserting nothing. Three cwds, one answer.
e_root="$( cd "$REPO" && bash "$RENDERER" --check 2>&1; echo "rc=$?" )"
e_slash="$( cd / && bash "$RENDERER" --check 2>&1; echo "rc=$?" )"
e_tmp="$( cd "$TMP" && bash "$RENDERER" --check 2>&1; echo "rc=$?" )"
if [ "$e_root" = "$e_slash" ] && [ "$e_root" = "$e_tmp" ] && grep -qF "$OK_TAIL" <<<"$e_root"; then
  note "ok    controlE   --check answers identically from the repo root, / and a temp dir"
else
  note "FAIL  controlE   --check is cwd-dependent, or did not pass from all three"
  printf 'root : %s\n/    : %s\ntmp  : %s\n' "$e_root" "$e_slash" "$e_tmp" | sed 's/^/      /' | head -9
  rc=1
fi

# --- m1: the arm PC-S330 was filed about, deleted ---------------------------
# THIS IS THE REGRESSION THAT SHIPPED. With the arm gone the function no longer answers
# `.githooks/` for a hook, the rendered table loses the row, and the committed region is
# stale. Nothing else in the tree notices: I16 puts core/skills/ai-dlc-update/** out of
# scope by name.
prep "$TMP/m1"
if mutate "$(preclass_of "$TMP/m1")" '/core\/git-hooks\/\*)/d'; then
  kill_check "m1 arm-deleted  core/git-hooks/* removed from map_consumer()" "$TMP/m1" \
    "does not match what map_consumer() renders today"
else
  no_mutation "m1 arm-deleted"
fi

# --- m2: the rendered region retyped by hand ---------------------------------
# The destination the pre-fix section actually sent readers to.
prep "$TMP/m2"
if mutate "$(skill_of "$TMP/m2")" 's|`\.githooks/<x>`|`.claude/git-hooks/<x>`|'; then
  kill_check "m2 hand-edited  destination retyped in SKILL.md" "$TMP/m2" \
    "does not match what map_consumer() renders today"
else
  no_mutation "m2 hand-edited"
fi

# --- m3: the section removed outright ----------------------------------------
prep "$TMP/m3"
if mutate "$(skill_of "$TMP/m3")" '/^## Path mapping/d'; then
  kill_check "m3 region-gone  the section heading deleted" "$TMP/m3" \
    "no generated path-mapping region in"
else
  no_mutation "m3 region-gone"
fi

# --- m4: the `case` reformatted past the extractor ---------------------------
# A PURE REFORMAT -- map_consumer() still answers exactly as before, and the scrape still
# defines it, so this mutant reaches the arm-count floor and nothing else. Unguarded it
# renders an EMPTY table, which byte-compares clean against a region someone emptied.
prep "$TMP/m4"
if mutate_awk "$(preclass_of "$TMP/m4")" '
  /^map_consumer\(\) \{/ { inf=1 }
  inf && /^\}/           { inf=0 }
  inf && match($0, /\)[ \t]+echo/) {
    print substr($0, 1, RSTART)
    print "      " substr($0, RSTART + RLENGTH - 4)
    next
  }
  { print }
'; then
  kill_check "m4 grammar      case arms reformatted past the extractor" "$TMP/m4" \
    "case arm(s) from map_consumer()"
else
  no_mutation "m4 grammar"
fi

# --- m5: the scrape defines nothing ------------------------------------------
# Refusing to guess is the whole posture: a private fallback table here would be the exact
# bug the renderer removes, so an unloadable source must be a FAILURE and never a skipped row.
prep "$TMP/m5"
if mutate "$(preclass_of "$TMP/m5")" 's|^map_consumer() {|map_consumer_renamed() {|'; then
  kill_check "m5 no-loader    map_consumer() renamed out of the scrape" "$TMP/m5" \
    "could not load map_consumer() from"
else
  no_mutation "m5 no-loader"
fi

# --- m6: the source is not there at all --------------------------------------
prep "$TMP/m6"
rm -f "$(preclass_of "$TMP/m6")"
if [ ! -f "$(preclass_of "$TMP/m6")" ]; then
  kill_check "m6 source-gone  preclassify.sh absent" "$TMP/m6" "source missing:"
else
  no_mutation "m6 source-gone"
fi

# --- n1: the near-miss -------------------------------------------------------
# A SECOND echoing `case`, in a second function, immediately below map_consumer(). It is
# shaped exactly like what the extractor hunts for, and it must not be read: an extraction
# that leaked past the function's closing brace would render a `core/nope/<x>` row and drift.
prep "$TMP/n1"
N1_PRE="$(preclass_of "$TMP/n1")"
cp "$N1_PRE" "$N1_PRE.orig"
cat >> "$N1_PRE" <<'EOF'

map_something_else() { # a second mapper the renderer must never read
  case "$1" in
    core/nope/*) echo "WRONG/${1#core/nope/}" ;;
    *)           echo "$1" ;;
  esac
}
EOF
if cmp -s "$N1_PRE" "$N1_PRE.orig"; then
  rm -f "$N1_PRE.orig"
  no_mutation "n1 near-miss"
else
  rm -f "$N1_PRE.orig"
  quiet_check "n1 near-miss   a change to preclassify.sh outside map_consumer()" "$TMP/n1"
fi

if [ "$rc" -eq 0 ]; then
  note "PASS  path-mapping-render -- 5 controls green, 6/6 mutants killed by their own arm, near-miss quiet"
fi
exit "$rc"
