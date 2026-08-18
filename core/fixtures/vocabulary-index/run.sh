#!/usr/bin/env bash
# Exercise scripts/render-vocabulary-index.sh -- the renderer that derives
# docs/vocabulary-index.md from the `# vocabulary:` markers in
# scripts/validate-enforcement-map.sh plus every enum in core/schemas/*.json, and
# byte-compares it at pre-push.
#
# Two controls plus eleven mutants, each a throwaway repo under a temp dir.
# Exit 0 iff both controls are green AND all eleven mutants are killed by their own arm.
#
#   controlA  the REAL repo: `--check` against the committed index      -> must PASS
#   controlB  a synthetic seed: render, then `--check`                   -> must PASS
#   m1  drift        a row appended to the rendered index                -> must FAIL
#   m2  missing      the index deleted                                   -> must FAIL
#   m3  bad-slug     a marker naming an extractor nobody implements      -> must FAIL
#   m4  dead-extractor  a marker deleted, orphaning an implemented slug  -> must FAIL
#   m5  demand       a vocabulary-shaped arm header carrying no marker   -> must FAIL
#   m6  zero-markers the marker grammar matches nothing                  -> must FAIL
#   m7  dead-id      a marker citing an ID the invariant index lacks     -> must FAIL
#   m8  no-owner     a marker naming an owner file that does not exist   -> must FAIL
#   m9  no-reader    a marker naming a reader file that does not exist   -> must FAIL
#   m10 empty-set    an owner reshaped so its extractor yields nothing   -> must FAIL
#   m11 both-shapes  (consumer-owned) declared alongside an extractor    -> must FAIL
#
# WHY THIS FIXTURE IS THE ONLY EVIDENCE THE RENDERER WORKS. Its finding set over the real
# tree is EMPTY by design -- a green `--check` is the steady state, and a renderer that
# silently stopped parsing markers would print that same green line. Every arm here exists
# to prove one specific way it can still fail.
#
# WHY THE SYNTHETIC SEED DECLARES EVERY EXTRACTOR. The renderer joins its implemented
# slugs against the declared ones in BOTH directions, so a seed naming one slug would fail
# on all the others -- correctly. Declaring every one costs a tiny owner file each and buys
# the thing a toy seed usually loses: every extractor is exercised against a synthetic owner
# whose shape is stated here, so a change to any extractor's grammar shows up as a fixture
# failure rather than as a silently emptier index. The count is deliberately NOT written in
# this comment: it moved from six to seven the first time an extractor was added, and a
# number here decays into a lie while the join below stays true. The seed's own assertion
# is the count, and it is one line.
#
# THE `empty-subject-verdict` OWNER IS ALSO A NEAR-MISS CONTROL. Its extractor reads a
# scoped YAML block, and `token:` is a two-character word any later block could reuse, so
# the seeded owner carries a `token:` on BOTH sides of its block. A file-wide extractor
# renders three members where the vocabulary has one, and the member assertion below catches
# it -- the same near-miss the renderer asserts in its own probe, asserted here against the
# shipping renderer rather than against a copy of its reasoning.
#
# WHY `cmp -s` GUARDS EVERY sed. A sed whose pattern stopped matching produces a
# byte-identical copy; the renderer then correctly passes and the arm reports SURVIVED for a
# mutation that never happened.
#
# A mutant must fail ONLY its own assertion, so each verdict asserts the expected message
# rather than merely a non-zero exit -- "it failed" is satisfied by a broken harness too.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"

# BOTH LAYOUTS NAMED, never a single walk-up (I33c). In this repo the fixture sits at
# core/fixtures/<name>/; the consumer layout puts it at tests/fixtures/<name>/. This unit is
# .dist-only and only ever runs here, but a resolver that names one layout is the shape the
# invariant forbids.
RENDERER=""; REPO=""
for cand in "$DIR/../../.." "$DIR/../.."; do
  if [ -f "$cand/scripts/render-vocabulary-index.sh" ] && [ -f "$cand/VERSION" ]; then
    REPO="$(cd "$cand" && pwd)"; RENDERER="$REPO/scripts/render-vocabulary-index.sh"; break
  fi
done
if [ -z "$RENDERER" ]; then
  echo "run.sh: could not locate scripts/render-vocabulary-index.sh from $DIR" >&2
  exit 2
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
rc=0
note() { printf '%s\n' "$*"; }

# ---------------------------------------------------------------------------------------
# The synthetic seed: a whole miniature repo the renderer can answer about.
# ---------------------------------------------------------------------------------------
seed() {
  local d="$1"
  mkdir -p "$d/scripts" "$d/docs" "$d/owners" "$d/readers" "$d/core/schemas"
  echo "0.0.0" > "$d/VERSION"
  cp "$RENDERER" "$d/scripts/render-vocabulary-index.sh"

  # --- the six owners, one per implemented extractor ---
  printf '%s\n' 'emit ALPHA' '    emit BETA' 'echo "emit NOT-A-STATUS"' > "$d/owners/ledger.sh"
  printf '%s\n' "LAYER_KINDS='kind-one kind-two'" > "$d/owners/kinds.sh"
  printf '%s\n' '  - id: a' '    level: ADJUDICATED' '    code: CODE-A' \
                '  - id: b' '    level: HARD' '    code: CODE-B' > "$d/owners/contract.yaml"
  printf '%s\n' '      keyone|keytwo)' '      keythree)' '      *)' > "$d/owners/cycle.sh"
  printf '%s\n' '| Intensity | Trigger | Minimum |' '|---|---|---|' \
                '| `heavy` | x | y |' '| `light` | x | y |' '' > "$d/owners/skill.md"
  printf '%s\n' '# SYNTAX_GLOB_BEGIN' '  for f in one/*.sh \' '           two/*.sh; do' \
                '# SYNTAX_GLOB_END' > "$d/owners/hook"
  # The block reader gets a `token:` on BOTH sides of its block, so this owner is also
  # the seed's standing proof that the extractor is SCOPED rather than matching `token:`
  # file-wide -- the near-miss the renderer's own probe asserts, asserted here too.
  printf '%s\n' 'preamble:' '  token: BEFORE-BLOCK' 'empty_subject_verdict:' \
                '  token: SEEDED NOTHING' '  emitters:' '    - a.sh' 'after:' \
                '  token: AFTER-BLOCK' > "$d/owners/emap.yaml"

  # --- the readers each vocabulary is joined to ---
  for r in ledger kinds contract cycle skill hook emap; do
    printf 'reader\n' > "$d/readers/$r.md"
  done

  # --- the marker corpus ---
  cat > "$d/scripts/validate-enforcement-map.sh" <<'EOF'
#!/usr/bin/env bash
err() { echo "FAIL: $*" >&2; fail=1; }
# --- I801: the ledger status vocabulary is one set ---------------------------
# vocabulary: ledger statuses
# vocabulary-invariant: I801
# vocabulary-owner: owners/ledger.sh
# vocabulary-extract: ledger-statuses
# vocabulary-readers: readers/ledger.md
err "I801 fired"
# --- I802: the kind vocabulary is one set ------------------------------------
# vocabulary: kinds
# vocabulary-invariant: I802
# vocabulary-owner: owners/kinds.sh
# vocabulary-extract: extension-kinds
# vocabulary-readers: readers/kinds.md
err "I802 fired"
# --- I803: the adjudicated code vocabulary is one set ------------------------
# vocabulary: adjudicated codes
# vocabulary-invariant: I803
# vocabulary-owner: owners/contract.yaml
# vocabulary-extract: adjudicated-codes
# vocabulary-readers: readers/contract.md
err "I803 fired"
# --- I804: the class grammar is ONE key set ----------------------------------
# vocabulary: class keys
# vocabulary-invariant: I804
# vocabulary-owner: owners/cycle.sh
# vocabulary-extract: pr-class-keys
# vocabulary-readers: readers/cycle.md
err "I804 fired"
# --- I805: the intensity vocabulary is one set -------------------------------
# vocabulary: intensities
# vocabulary-invariant: I805
# vocabulary-owner: owners/skill.md
# vocabulary-extract: intensity-table
# vocabulary-readers: readers/skill.md
err "I805 fired"
# --- I806: the syntax glob vocabulary is one set -----------------------------
# vocabulary: syntax globs
# vocabulary-invariant: I806
# vocabulary-owner: owners/hook
# vocabulary-extract: syntax-globs
# vocabulary-readers: readers/hook.md
err "I806 fired"
# --- I807: the gadget taxonomy is declared once ------------------------------
# vocabulary: gadget classes
# vocabulary-invariant: I807
# vocabulary-owner: (consumer-owned) the set lives in THEIRS and is read through git show
err "I807 fired"
# --- I810: the empty-subject verdict token is one string ---------------------
# vocabulary: empty-subject tokens
# vocabulary-invariant: I810
# vocabulary-owner: owners/emap.yaml
# vocabulary-extract: empty-subject-verdict
# vocabulary-readers: readers/emap.md
err "I810 fired"
# --- I808: an ordinary arm, and a NEAR MISS -- it binds ONE string, not a set -
# The wording is deliberate. `one string` is one character-class away from `one set`, which
# is what the demand arm keys on, so this line is the seed's standing proof that the arm
# discriminates rather than firing on every header that mentions a join. It is also how
# this fixture caught its own first draft, whose ordinary arm said "binding no vocabulary
# at all" and was correctly demanded.
err "I808 fired"
EOF

  # --- the invariant index the markers' citations resolve against ---
  {
    printf '# Invariant index\n\n| ID | What it binds |\n|----|---------------|\n'
    for i in 801 802 803 804 805 806 807 808 810; do printf '| I%s | seeded |\n' "$i"; done
  } > "$d/docs/invariant-index.md"

  # --- one schema, so the second table is non-empty ---
  cat > "$d/core/schemas/seeded.json" <<'EOF'
{"fields": [{"name": "verdict", "enum": ["YES", "NO"]}]}
EOF
}

render_in() { ( cd "$1" && bash scripts/render-vocabulary-index.sh 2>&1 ); }
check_in()  { ( cd "$1" && bash scripts/render-vocabulary-index.sh --check 2>&1 ); }

# --- controlA: the real repo -------------------------------------------------
if outA="$( cd "$REPO" && bash scripts/render-vocabulary-index.sh --check 2>&1 )" \
   && grep -q "^OK: docs/vocabulary-index.md in sync" <<<"$outA"; then
  note "ok    controlA -- the committed index matches the real markers and schemas"
else
  note "FIXTURE BROKEN: --check does not pass against the real repo. Every verdict below is meaningless."
  printf '%s\n' "$outA" | sed 's/^/      /' | head -8
  exit 1
fi

# --- controlB: the synthetic seed renders and round-trips --------------------
seed "$TMP/controlB"
outB="$(render_in "$TMP/controlB")"
if ! grep -q "8 cross-file vocabular(ies), 1 schema enum(s)" <<<"$outB"; then
  note "FIXTURE BROKEN: the synthetic seed did not render 8 vocabularies and 1 schema enum."
  printf '%s\n' "$outB" | sed 's/^/      /' | head -6
  exit 1
fi
# EVERY EXTRACTOR MUST HAVE PRODUCED ITS MEMBERS. Without this the seed proves only that the
# marker reader ran; six extractors could each be returning nothing and the row count would
# be identical.
missing=""
for want in 'ALPHA' 'kind-one' 'CODE-A' 'keyone' 'heavy' 'one/\*.sh' 'YES' 'SEEDED NOTHING'; do
  grep -qE "$want" "$TMP/controlB/docs/vocabulary-index.md" || missing="$missing $want"
done
if [ -n "$missing" ]; then
  note "FIXTURE BROKEN: rendered index is missing member(s) from the seed:$missing"
  exit 1
fi
# The consumer-owned row must render WITHOUT members and must not have shifted its fields.
if ! grep -q '| gadget classes | — consumer-owned | (consumer-owned)' "$TMP/controlB/docs/vocabulary-index.md"; then
  note "FIXTURE BROKEN: the consumer-owned row did not render with an empty member cell."
  grep 'gadget' "$TMP/controlB/docs/vocabulary-index.md" | sed 's/^/      /'
  exit 1
fi
if outB2="$(check_in "$TMP/controlB")" && grep -q "in sync" <<<"$outB2"; then
  note "ok    controlB -- seed renders all six extractors, the consumer-owned row, and round-trips"
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

MAP='scripts/validate-enforcement-map.sh'

# m1 -- a stale index
seed "$TMP/m1"; render_in "$TMP/m1" >/dev/null
printf '| ghost | `x` | `y` | I801 | `z` |\n' >> "$TMP/m1/docs/vocabulary-index.md"
kill_check "m1  drift          stale index" "$TMP/m1" "docs/vocabulary-index.md is STALE"

# m2 -- no index at all
seed "$TMP/m2"; render_in "$TMP/m2" >/dev/null
rm -f "$TMP/m2/docs/vocabulary-index.md"
kill_check "m2  missing        index absent" "$TMP/m2" "does not exist"

# m3 -- a marker naming an extractor nobody implements
seed "$TMP/m3"
if mutate "$TMP/m3/$MAP" 's|^# vocabulary-extract: ledger-statuses$|# vocabulary-extract: no-such-slug|'; then
  kill_check "m3  bad-slug       extractor not implemented" "$TMP/m3" "implements no such extractor" render
else
  note "SKIP  m3 -- sed matched nothing; no mutation occurred"; rc=1
fi

# m4 -- an implemented extractor that no marker declares
#
# THE HEADER IS REWORDED IN THE SAME MUTATION, and that is not cosmetic. Deleting only the
# marker leaves a header still reading "the syntax glob vocabulary is one set", which the
# DEMAND arm catches first -- so the mutant dies, by the wrong arm, and m4 would report a
# kill for a condition it never tested. This fixture's first run did exactly that.
seed "$TMP/m4"
if mutate "$TMP/m4/$MAP" '
    s|^# --- I806: the syntax glob vocabulary is one set.*|# --- I806: an arm about globs ---|
    /^# vocabulary: syntax globs$/,/^# vocabulary-readers: readers\/hook.md$/d'; then
  kill_check "m4  dead-extractor slug declared nowhere" "$TMP/m4" "no marker in" render
else
  note "SKIP  m4 -- sed matched nothing; no mutation occurred"; rc=1
fi

# m5 -- a vocabulary-shaped header with no marker at all
seed "$TMP/m5"
printf '# --- I809: the doohickey vocabulary is one set ---\nerr "I809 fired"\n' >> "$TMP/m5/$MAP"
kill_check "m5  demand         vocabulary header, no marker" "$TMP/m5" "carry no" render

# m6 -- the marker grammar matches nothing
seed "$TMP/m6"
if mutate "$TMP/m6/$MAP" 's|^# vocabulary|# VOCABULARY|'; then
  kill_check "m6  zero-markers   grammar matches nothing" "$TMP/m6" "parsed ZERO vocabulary markers" render
else
  note "SKIP  m6 -- sed matched nothing; no mutation occurred"; rc=1
fi

# m7 -- a citation the invariant index does not carry
seed "$TMP/m7"
if mutate "$TMP/m7/$MAP" 's|^# vocabulary-invariant: I801$|# vocabulary-invariant: I899|'; then
  kill_check "m7  dead-id        citation not in the index" "$TMP/m7" "docs/invariant-index.md does not list it" render
else
  note "SKIP  m7 -- sed matched nothing; no mutation occurred"; rc=1
fi

# m8 -- an owner that does not exist
seed "$TMP/m8"
if mutate "$TMP/m8/$MAP" 's|^# vocabulary-owner: owners/kinds.sh$|# vocabulary-owner: owners/gone.sh|'; then
  kill_check "m8  no-owner       owner file absent" "$TMP/m8" "which does not exist. An extraction over a missing file" render
else
  note "SKIP  m8 -- sed matched nothing; no mutation occurred"; rc=1
fi

# m9 -- a reader that does not exist
seed "$TMP/m9"
if mutate "$TMP/m9/$MAP" 's|^# vocabulary-readers: readers/kinds.md$|# vocabulary-readers: readers/gone.md|'; then
  kill_check "m9  no-reader      reader file absent" "$TMP/m9" "names reader" render
else
  note "SKIP  m9 -- sed matched nothing; no mutation occurred"; rc=1
fi

# m10 -- an owner whose shape the extractor no longer matches
seed "$TMP/m10"
if mutate "$TMP/m10/owners/kinds.sh" 's|LAYER_KINDS=|OTHER_KINDS=|'; then
  kill_check "m10 empty-set      extractor yields nothing" "$TMP/m10" "extracted ZERO members" render
else
  note "SKIP  m10 -- sed matched nothing; no mutation occurred"; rc=1
fi

# m11 -- both declaration shapes at once
seed "$TMP/m11"
if mutate "$TMP/m11/$MAP" 's|^# vocabulary-owner: (consumer-owned) the set lives in THEIRS and is read through git show$|# vocabulary-owner: (consumer-owned) the set lives in THEIRS\n# vocabulary-extract: extension-kinds|'; then
  kill_check "m11 both-shapes    consumer-owned AND an extractor" "$TMP/m11" "AND names an extractor" render
else
  note "SKIP  m11 -- sed matched nothing; no mutation occurred"; rc=1
fi

if [ "$rc" -eq 0 ]; then
  note "PASS  vocabulary-index -- 2 controls green, 11/11 mutants killed by their own arm"
fi
exit "$rc"
