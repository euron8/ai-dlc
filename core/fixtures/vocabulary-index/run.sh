#!/usr/bin/env bash
# Exercise scripts/render-vocabulary-index.sh -- the renderer that derives
# docs/vocabulary-index.md from the `# vocabulary:` markers in
# scripts/validate-enforcement-map.sh plus every enum in core/schemas/*.json, and
# byte-compares it at pre-push.
#
# Two controls, one near-miss control and a mutant per failure mode, each a throwaway repo
# under a temp dir. Exit 0 iff every control is green AND every mutant is killed by its own arm.
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
#   m12 bad-sentinel @owner-declares on a slug with no path extractor    -> must FAIL
#   m13 empty-derived  an owner whose derived path list is empty         -> must FAIL
#   m14 derived-absent a DERIVED path naming a file that does not exist  -> must FAIL
#   n1  block-scope  one field once in each of two ADJACENT blocks       -> must PASS
#   m15 dup-field    `vocabulary-readers:` declared twice in one block   -> must FAIL
#   m16 dup-other    `vocabulary-owner:` twice, in a different block     -> must FAIL
#   m17 dup-empty    an EMPTY declaration then a valued one, same field  -> must FAIL
#   m18 dup-invariant `vocabulary-invariant:` twice, two live citations  -> must FAIL
#   m19 dup-emitters `vocabulary-emitters:` twice, literal AND sentinel  -> must FAIL
#   m20 dup-same-value a field repeated VERBATIM, so the values agree    -> must FAIL
#   m21 unreadable-src the marker corpus at mode 000 -- exists, unreadable -> must FAIL
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
# WHY THE DUPLICATE-FIELD GROUP IS FOUR ARMS AND NOT ONE. The refusal it guards is
# BLOCK-SCOPED, and a file-wide refusal is the failure mode that reads identically to a
# working one over any corpus where each block is complete: every seed here declares
# `vocabulary-owner:` eight times, once per block, so an arm keyed on a repeated field
# ANYWHERE would refuse the seed itself. controlB already covers the file-wide shape. n1
# covers the one it cannot see -- two blocks separated ONLY by a `# vocabulary:` line, with
# no arm header between them, which is a flush point the seed never exercises on its own.
# m15, m16, m18, m19 and m20 cover all FIVE fields, in four different blocks, because
# guarding one field and leaving the other four last-wins is the obvious partial
# implementation and a single-field arm cannot see it. m17 seeds an EMPTY first declaration, which is the case a
# refusal written as "the field already holds a value" silently accepts and a refusal
# written as a seen-flag catches; without it the two implementations are indistinguishable.
#
# The verdicts assert the FIELD NAME and BOTH VALUES rather than a sentence, because the
# contract is that the message names them; a fixture keyed on the wording would be asserting
# the implementation it was written beside.
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
  #
  # IT IS ALSO THE ONLY OWNER THAT DECLARES ITS OWN EMITTER AND READER LISTS, which is what
  # the `@owner-declares` sentinel resolves against. Both lists are seeded, and BOTH are
  # bracketed by decoy lists under other top-level keys, so a path reader that keys on `- `
  # indentation rather than on the block AND the list name renders the decoys.
  printf '%s\n' 'preamble:' '  token: BEFORE-BLOCK' '  emitters:' '    - owners/decoy-before.sh' \
                'empty_subject_verdict:' \
                '  token: SEEDED NOTHING' \
                '  emitters:' '    - owners/emap-emitter.sh' \
                '  readers:' '    - readers/emap.md' \
                'after:' '  token: AFTER-BLOCK' '  readers:' '    - readers/decoy-after.md' \
                > "$d/owners/emap.yaml"
  printf 'echo "SEEDED NOTHING"\n' > "$d/owners/emap-emitter.sh"

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
# vocabulary-emitters: @owner-declares
# vocabulary-readers: @owner-declares
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
# THE DERIVED COLUMNS, ASSERTED AS PRESENCE. `@owner-declares` on I810 means the emitters and
# readers cells come from the OWNER rather than from the marker, and a resolver that silently
# returned nothing would render two em dashes -- which reads exactly like a vocabulary with no
# emitters. Both cells are demanded by content, and the two DECOY lists the seeded owner
# carries under neighbouring top-level keys are demanded ABSENT in the same arm: a reader
# keyed on `- ` indentation instead of on the block and the list name passes the first half
# and fails this one.
if ! grep -q '| `owners/emap-emitter.sh` | `readers/emap.md` |' "$TMP/controlB/docs/vocabulary-index.md"; then
  note "FIXTURE BROKEN: the @owner-declares sentinel did not resolve to the owner's own emitter and reader lists."
  grep 'empty-subject' "$TMP/controlB/docs/vocabulary-index.md" | sed 's/^/      /'
  exit 1
fi
if grep -qE 'decoy-before|decoy-after' "$TMP/controlB/docs/vocabulary-index.md"; then
  note "FIXTURE BROKEN: a derived column picked up a list from OUTSIDE the empty_subject_verdict: block."
  grep 'empty-subject' "$TMP/controlB/docs/vocabulary-index.md" | sed 's/^/      /'
  exit 1
fi
if outB2="$(check_in "$TMP/controlB")" && grep -q "in sync" <<<"$outB2"; then
  note "ok    controlB -- seed renders every extractor, the derived columns, the consumer-owned row, and round-trips"
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

kill_check_all() { # kill_check_all <name> <dir> <check|render> <substring>... ; !<substring> = must be ABSENT
  # As kill_check, but every substring must appear. A message naming a repeated FIELD and
  # ONE of its two values is a message that has not reported the contradiction.
  #
  # A `!`-prefixed pattern must be ABSENT, and that arm exists because a non-zero exit does
  # not say WHICH guard produced it. A mutant can print the refusal, fail to act on it, and
  # be killed several checks downstream by a guard complaining about the wreckage -- which
  # satisfies "exited non-zero AND the refusal is in the output" and is not the subject. The
  # absence half never runs alone: the presence patterns in the same call are its control.
  local n="$1" d="$2" mode="$3"; shift 3
  local out rc_v p miss=""
  if [ "$mode" = render ]; then out="$(render_in "$d")"; else out="$(check_in "$d")"; fi
  rc_v=$?
  if [ "$rc_v" -eq 0 ]; then
    note "FAIL  $n -- mutant SURVIVED (renderer exited 0)"; rc=1; return
  fi
  for p in "$@"; do
    case "$p" in
      '!'*) grep -qF "${p#\!}" <<<"$out" && miss="$miss [must-be-absent: ${p#\!}]" ;;
      *)    grep -qF "$p" <<<"$out" || miss="$miss [$p]" ;;
    esac
  done
  if [ -n "$miss" ]; then
    note "FAIL  $n -- renderer failed, but its message omits:$miss"
    printf '%s\n' "$out" | sed 's/^/      /' | head -5; rc=1; return
  fi
  note "ok    $n -- killed by its own arm"
}

green_check() { # green_check <name> <dir> <expected-output-substring> <expected-index-row>...
  # A NEAR MISS must render, so this arm is the mirror of kill_check. It is PRESENCE-shaped
  # in both halves -- a renderer replaced by `exit 0` writes no index and fails it -- because
  # "exited 0 and reported nothing" is exactly what a subject that never ran looks like.
  local n="$1" d="$2" pat="$3"; shift 3
  local out rc_v p miss=""
  out="$(render_in "$d")"
  rc_v=$?
  if [ "$rc_v" -ne 0 ]; then
    note "FAIL  $n -- near-miss REFUSED (renderer exited $rc_v); the refusal is not block-scoped"
    printf '%s\n' "$out" | sed 's/^/      /' | head -5; rc=1; return
  fi
  if ! grep -qF "$pat" <<<"$out"; then
    note "FAIL  $n -- renderer exited 0 but did not report a render (wanted: $pat)"
    printf '%s\n' "$out" | sed 's/^/      /' | head -5; rc=1; return
  fi
  for p in "$@"; do
    grep -qF "$p" "$d/docs/vocabulary-index.md" 2>/dev/null || miss="$miss [$p]"
  done
  if [ -n "$miss" ]; then
    note "FAIL  $n -- rendered, but the index is missing row(s):$miss"; rc=1; return
  fi
  note "ok    $n -- rendered, both blocks intact"
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

# m12 -- the @owner-declares sentinel on a row whose extractor cannot yield paths
#
# NOT the empty-subject row: the sentinel is CORRECT there, so the mutation has to move it
# somewhere it is wrong. The ledger owner is a shell script declaring MEMBERS and nothing
# about who reads them, which is precisely the case the literal form exists for.
seed "$TMP/m12"
if mutate "$TMP/m12/$MAP" 's|^# vocabulary-readers: readers/ledger.md$|# vocabulary-readers: @owner-declares|'; then
  kill_check "m12 bad-sentinel   derive from a slug with no path extractor" "$TMP/m12" "implements no path extractor" render
else
  note "SKIP  m12 -- sed matched nothing; no mutation occurred"; rc=1
fi

# m13 -- the owner's derived list emptied. An empty column renders as an em dash, which reads
# exactly like a vocabulary nobody reads, so ZERO derived paths must be a failure.
seed "$TMP/m13"
if mutate "$TMP/m13/owners/emap.yaml" '/^    - readers\/emap.md$/d'; then
  kill_check "m13 empty-derived  owner declares no readers" "$TMP/m13" "got ZERO paths" render
else
  note "SKIP  m13 -- sed matched nothing; no mutation occurred"; rc=1
fi

# m14 -- a DERIVED path that does not exist. m9 covers the literal form; this is the same
# duty on the other shape, and without it the sentinel would be the one way into this index
# that skips the existence check.
seed "$TMP/m14"
if mutate "$TMP/m14/owners/emap.yaml" 's|^    - owners/emap-emitter.sh$|    - owners/gone.sh|'; then
  kill_check "m14 derived-absent derived emitter file absent" "$TMP/m14" "names emitters" render
else
  note "SKIP  m14 -- sed matched nothing; no mutation occurred"; rc=1
fi

# --- the duplicate-field group ----------------------------------------------
#
# Each of the five marker fields may be declared AT MOST ONCE within one marker block. A
# second declaration must make the renderer refuse, naming the field and both values, rather
# than overwrite the first and render from the last.
#
# THE TOKENS BELOW ARE DERIVED, NOT TYPED TWICE. Each arm names its two values once, uses
# them to build the mutation, and asserts on the same variables -- so a seed whose paths move
# breaks the `mutate` guard rather than leaving an arm hunting a string nothing emits.

# n1 -- THE NEAR MISS THE WHOLE GROUP TURNS ON, and it must stay GREEN.
#
# Deleting the I802 arm header leaves two COMPLETE marker blocks separated only by the
# `# vocabulary: kinds` line. Both declare `vocabulary-owner:`, `vocabulary-extract:`,
# `vocabulary-invariant:` and `vocabulary-readers:` -- once each, in their own block -- so a
# refusal scoped to the file, or one whose seen-flags are cleared by an arm header but not by
# a `# vocabulary:` line, reports a duplicate here and is wrong. The unmutated seed cannot
# see that second shape: every block in it is bounded by an arm header, so the two
# implementations render it identically.
seed "$TMP/n1"
if mutate "$TMP/n1/$MAP" '/^# --- I802: the kind vocabulary is one set/d'; then
  green_check "n1  block-scope    two adjacent blocks, one field each" "$TMP/n1" \
    "8 cross-file vocabular(ies), 1 schema enum(s)" '| ledger statuses |' '| kinds |'
else
  note "SKIP  n1 -- sed matched nothing; no mutation occurred"; rc=1
fi

# m15 -- one field declared twice in one block, with CONTRADICTORY values.
#
# Both readers exist, so under a renderer that overwrites silently the mutant renders and
# exits 0 -- which is the defect, and is what makes this arm a real one rather than a
# restatement of m9.
DUP_R_A='readers/kinds.md'; DUP_R_B='readers/ledger.md'
seed "$TMP/m15"
if [ ! -f "$TMP/m15/$DUP_R_A" ] || [ ! -f "$TMP/m15/$DUP_R_B" ]; then
  note "SKIP  m15 -- the seed no longer carries $DUP_R_A and $DUP_R_B"; rc=1
elif mutate "$TMP/m15/$MAP" \
     "s|^# vocabulary-readers: ${DUP_R_A}\$|# vocabulary-readers: ${DUP_R_A}\\n# vocabulary-readers: ${DUP_R_B}|"; then
  kill_check_all "m15 dup-field      one field declared twice in one block" "$TMP/m15" render \
    'vocabulary-readers' "$DUP_R_A" "$DUP_R_B"
else
  note "SKIP  m15 -- sed matched nothing; no mutation occurred"; rc=1
fi

# m16 -- a SECOND field, in a DIFFERENT block. A refusal that guards `vocabulary-readers:`
# and leaves the other four last-wins is the obvious partial implementation, and m15 alone
# cannot tell it from a complete one. The second owner is a copy of the first, so the
# extractor yields the same members and the mutant cannot die by m8's or m10's arm.
DUP_O_A='owners/ledger.sh'; DUP_O_B='owners/ledger-copy.sh'
seed "$TMP/m16"
if ! cp "$TMP/m16/$DUP_O_A" "$TMP/m16/$DUP_O_B" 2>/dev/null; then
  note "SKIP  m16 -- the seed no longer carries $DUP_O_A"; rc=1
elif mutate "$TMP/m16/$MAP" \
     "s|^# vocabulary-owner: ${DUP_O_A}\$|# vocabulary-owner: ${DUP_O_A}\\n# vocabulary-owner: ${DUP_O_B}|"; then
  kill_check_all "m16 dup-other      a second field, in another block" "$TMP/m16" render \
    'vocabulary-owner' "$DUP_O_A" "$DUP_O_B"
else
  note "SKIP  m16 -- sed matched nothing; no mutation occurred"; rc=1
fi

# m17 -- an EMPTY declaration followed by a valued one.
#
# THE EMPTY ONE IS FIRST, and the order is the whole point. A refusal written as "this field
# already holds a value" sees an empty string, concludes nothing was declared, and accepts --
# rendering the correct index from the second declaration, exactly as the unfixed renderer
# does. A refusal written as a seen-flag catches it. With the empty declaration SECOND both
# implementations fire and the arm would discriminate nothing.
DUP_E='owners/kinds.sh'
seed "$TMP/m17"
if mutate "$TMP/m17/$MAP" \
     "s|^# vocabulary-owner: ${DUP_E}\$|# vocabulary-owner:\\n# vocabulary-owner: ${DUP_E}|"; then
  # THE `!declares no` CLAUSE IS WHAT MAKES THIS ARM ITS OWN. m17 is the only dup mutant
  # whose discarded value is EMPTY, so it is the only one that leaves a downstream guard with
  # something to say: if the refusal reports and does not act, the empty owner survives and
  # `the vocabulary ... declares no vocabulary-owner:` supplies the non-zero exit instead.
  # Without this clause m17 prints `killed by its own arm` for a kill another guard earned --
  # the exact shape the "a mutant must fail only its own assertion" rule forbids.
  kill_check_all "m17 dup-empty      an empty declaration still counts" "$TMP/m17" render \
    'vocabulary-owner' "$DUP_E" '!declares no'
else
  note "SKIP  m17 -- sed matched nothing; no mutation occurred"; rc=1
fi

# m18 -- `vocabulary-invariant:` twice. The third of the five fields, and the one whose
# discarded value is a CITATION: both IDs are in the seeded invariant index, so under a
# renderer that overwrites, the row cites the second and nothing anywhere records that the
# arm was ever bound to the first.
DUP_I_A='I801'; DUP_I_B='I808'
seed "$TMP/m18"
if ! grep -q "| ${DUP_I_B} |" "$TMP/m18/docs/invariant-index.md"; then
  note "SKIP  m18 -- the seeded invariant index no longer lists ${DUP_I_B}"; rc=1
elif mutate "$TMP/m18/$MAP" \
     "s|^# vocabulary-invariant: ${DUP_I_A}\$|# vocabulary-invariant: ${DUP_I_A}\\n# vocabulary-invariant: ${DUP_I_B}|"; then
  kill_check_all "m18 dup-invariant  two citations for one vocabulary" "$TMP/m18" render \
    'vocabulary-invariant' "$DUP_I_A" "$DUP_I_B"
else
  note "SKIP  m18 -- sed matched nothing; no mutation occurred"; rc=1
fi

# m19 -- `vocabulary-emitters:` twice, and this is the shape BL-094 was FILED on: a literal
# path inserted immediately above the `@owner-declares` sentinel. The two declarations are
# not merely different values, they are different SHAPES -- one literal, one derived -- and
# the renderer refuses that contradiction for `vocabulary-owner:` (m11) while accepting it
# here. The fourth of the five fields, and the only one the seed declares as a sentinel.
DUP_M_A='@owner-declares'; DUP_M_B='owners/emap-emitter.sh'
seed "$TMP/m19"
if [ ! -f "$TMP/m19/$DUP_M_B" ]; then
  note "SKIP  m19 -- the seed no longer carries $DUP_M_B"; rc=1
elif mutate "$TMP/m19/$MAP" \
     "s|^# vocabulary-emitters: ${DUP_M_A}\$|# vocabulary-emitters: ${DUP_M_B}\\n# vocabulary-emitters: ${DUP_M_A}|"; then
  kill_check_all "m19 dup-emitters    a literal above the sentinel" "$TMP/m19" render \
    'vocabulary-emitters' "$DUP_M_A" "$DUP_M_B"
else
  note "SKIP  m19 -- sed matched nothing; no mutation occurred"; rc=1
fi

# m20 -- `vocabulary-extract:` twice with the SAME value, which is two things at once.
#
# It is the fifth field, and it is the only one whose two declarations CANNOT differ: a
# second slug would leave the first declared nowhere, and the mutant would die by m4's arm
# instead of this one. So the value is repeated verbatim -- and that makes this the arm that
# separates a refusal keyed on the DECLARATION from one keyed on the DISAGREEMENT. A
# renderer that reports only when the two values differ renders this mutant happily, which
# is the same silence BL-094 filed, over a field that is now declared twice with nobody
# holding it to once.
DUP_X='ledger-statuses'
seed "$TMP/m20"
if mutate "$TMP/m20/$MAP" \
     "s|^# vocabulary-extract: ${DUP_X}\$|# vocabulary-extract: ${DUP_X}\\n# vocabulary-extract: ${DUP_X}|"; then
  kill_check_all "m20 dup-same-value  a field repeated verbatim" "$TMP/m20" render \
    'vocabulary-extract' "$DUP_X"
else
  note "SKIP  m20 -- sed matched nothing; no mutation occurred"; rc=1
fi

# m21 -- the marker corpus EXISTS and cannot be READ.
#
# THE EXIT CODE WAS ALREADY CORRECT AND THE ATTRIBUTION WAS WRONG, which is why this arm
# asserts a string and an ABSENCE rather than a status. A mode-000 corpus passes `[ -f ]`;
# BSD awk then ABORTS on it rather than skipping, and every marker reader is a pipeline
# ending in a filter, so each returns EMPTY and the abort is swallowed. The renderer failed
# closed -- and named the wrong cause, sending the reader to inspect a marker grammar that
# was never the problem. An arm keyed on a non-zero exit passes against that defect.
#
# THE ABSENCE IS KEYED ON WHAT SEPARATES THE TWO MESSAGES, NOT ON WHAT THEY SHARE. The
# first draft of this arm demanded `marker grammar` be ABSENT and reported a false positive
# against the correct renderer, because the correct message names the misattribution in
# order to deny it -- "the failure would be reported as a changed marker grammar". The
# discriminating string is the misattributed VERDICT, `parsed ZERO vocabulary markers`,
# which the wrong message emits and the right one does not.
#
# THE ABSENCE HALF CARRIES ITS CONTROL IN THE SAME INVOCATION: `cannot READ` must be
# present, a token known to be in the same output. On its own, "the wrong verdict is absent"
# is satisfied by no output at all.
#
# THE READABILITY PRECONDITION IS ASSERTED, NOT ASSUMED. Under a uid that ignores the mode
# bits -- root, or a suite run in a container as root -- `chmod 000` leaves the file readable,
# the renderer parses it normally and this arm reports a kill it did not earn. That state is
# indistinguishable from a working arm, so it is refused rather than tolerated.
seed "$TMP/m21"
chmod 000 "$TMP/m21/$MAP"
if [ -r "$TMP/m21/$MAP" ]; then
  chmod 644 "$TMP/m21/$MAP"
  note "SKIP  m21 -- chmod 000 left $MAP readable (running as a uid that ignores mode bits?);"
  note "      the seed cannot express the defect, so a kill here would be unearned"; rc=1
else
  out21="$(render_in "$TMP/m21")"; rc21=$?
  chmod 644 "$TMP/m21/$MAP"
  if [ "$rc21" -eq 0 ]; then
    note "FAIL  m21 unreadable-src  an unreadable corpus -- mutant SURVIVED (renderer exited 0)"; rc=1
  elif ! grep -qF 'cannot READ' <<<"$out21"; then
    note "FAIL  m21 unreadable-src  renderer exited $rc21 but did not name the READ fault"
    printf '%s\n' "$out21" | sed 's/^/      /' | head -5; rc=1
  elif ! grep -qF "$MAP" <<<"$out21"; then
    note "FAIL  m21 unreadable-src  the READ fault does not name $MAP"
    printf '%s\n' "$out21" | sed 's/^/      /' | head -5; rc=1
  elif grep -qF 'parsed ZERO vocabulary markers' <<<"$out21"; then
    note "FAIL  m21 unreadable-src  a READ fault was MISATTRIBUTED to the marker grammar"
    printf '%s\n' "$out21" | sed 's/^/      /' | head -5; rc=1
  else
    note "ok    m21 unreadable-src  unreadable corpus named as a READ fault, not a grammar change"
  fi
fi

if [ "$rc" -eq 0 ]; then
  note "PASS  vocabulary-index -- 2 controls + 1 near-miss green, 21/21 mutants killed by their own arm"
fi
exit "$rc"
