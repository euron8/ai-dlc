#!/usr/bin/env bash
# layer-absorption-retire — prove LC-E6's code can FIRE, and that what distinguishes it from its
# sibling is the one fact it claims.
#
# THE GAP THIS CLOSES. `EXTENSION-RETIRE-CANDIDATE` [LC-E6] carried `fixture: none` in
# layer-contract.yaml — a DECLARED I65 gap, honestly recorded, and v0.273.0's notes say why the
# obvious home was refused: `layer-title-join` asserts LC-E6's ABSENCE and never makes it fire,
# and "binding a clause to a fixture that cannot prove it is the gap wearing a receipt." So no
# run anywhere had ever produced this status. Its zero on the reference consumer was therefore
# not a measurement — it was a silence, and plan item 6 (promoting LC-E6 to ADJUDICATED) is
# blocked on knowing the difference.
#
# WHAT MAKES THE STATUS HARD TO TEST AND EASY TO GET WRONG. LC-E6 and LC-E5
# (`EXTENSION-RESTATES-CORE`) come out of the SAME comparison and differ on ONE bit: whether the
# core anchor the entry duplicates existed at BASE. Present at base -> PRE-EXISTING -> LC-E5,
# "you have been shipping a duplicate". Absent at base -> NEW-THIS-PULL -> LC-E6, "upstream just
# absorbed this; retire your copy". A fixture that asserted only "some absorption row appeared"
# would score the wrong one as a pass, which is why every arm below names the status.
#
# Usage: run.sh [path-to-layer-drift.sh]
# Exit:  0 = every assertion holds, 1 = an arm regressed, 2 = the fixture could not run.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

# BOTH LAYOUTS, and never by walking up from one core file to another (I33). `pick` takes the
# first candidate that exists, so the distribution's `core/…` and a consumer's `.claude/…` are
# each named outright rather than derived from the other.
pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
DRIFT="$(pick "${1:-}" "$HERE/../../skills/ai-dlc-update/reconcile/layer-drift.sh" \
                       "$HERE/../../../core/skills/ai-dlc-update/reconcile/layer-drift.sh" \
                       "$HERE/../../../.claude/skills/ai-dlc-update/reconcile/layer-drift.sh")"
# A MISSING SUBJECT IS NOT A PASS. Every assertion here is "did this row appear", so a run that
# cannot invoke the classifier produces no rows and would score green on the negative arms.
[ -n "$DRIFT" ] || { echo "FIXTURE ERROR: cannot locate layer-drift.sh" >&2; exit 2; }

ROOT="$(mktemp -d "${TMPDIR:-/tmp}/layer-absorption-retire.XXXXXX")"
trap 'rm -rf "$ROOT"' EXIT
DIST="$ROOT/dist"; CONS="$ROOT/consumer"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

echo "layer-absorption-retire:"

mkdir -p "$DIST/core/skills/ai-dlc/steps" "$DIST/core/schemas" "$CONS/.claude/skills/ai-dlc/extensions"
git -C "$DIST" init -q 2>/dev/null || { echo "FIXTURE ERROR: git init failed" >&2; exit 2; }

# The adjudication vocabulary is read from the SCHEMA at theirs; a synthetic dist that omits it
# makes layer-drift exit 1 the moment any clause sits at ADJUDICATED. Copy the real file rather
# than restating an enum beside it.
ADJ_SRC="$(pick "$HERE/../../schemas/layer-adjudication-register.json" \
                "$HERE/../../../core/schemas/layer-adjudication-register.json" \
                "$HERE/../../../.claude/schemas/layer-adjudication-register.json")"
[ -n "$ADJ_SRC" ] || { echo "FIXTURE ERROR: layer-adjudication-register.json not found in either layout" >&2; exit 2; }
cp "$ADJ_SRC" "$DIST/core/schemas/" || { echo "FIXTURE ERROR: cannot seed the adjudication schema" >&2; exit 2; }

cat > "$DIST/core/skills/ai-dlc/core-manifest.md" <<'MD'
<!-- CORE_MANIFEST v1 -->
machinery:
  - core-manifest.md
rulebook:
  - steps/*.md
MD

cat > "$DIST/core/skills/ai-dlc/layer-contract.yaml" <<'YML'
contract_version: 16
YML

# --- BASE: core defines check 3 and nothing else numbered ----------------------------------
cat > "$DIST/core/skills/ai-dlc/steps/widget.md" <<'MD'
# Widget

### 3. Pre-existing Widget Check.

Core has carried this for releases.
MD
git -C "$DIST" add -A >/dev/null 2>&1
git -C "$DIST" -c user.email=f@x -c user.name=f commit -qm base >/dev/null 2>&1
BASE="$(git -C "$DIST" rev-parse --short HEAD)"

# --- THEIRS: core ABSORBS a check it did not have at base -----------------------------------
# This is the whole subject. `### 9.` is present at theirs and absent at base, which is the ONE
# fact that separates LC-E6 from LC-E5 on an otherwise identical comparison.
cat >> "$DIST/core/skills/ai-dlc/steps/widget.md" <<'MD'

### 9. Absorbed Widget Check.

Core adopted this on this pull.
MD
git -C "$DIST" add -A >/dev/null 2>&1
git -C "$DIST" -c user.email=f@x -c user.name=f commit -qm theirs >/dev/null 2>&1
THEIRS="$(git -C "$DIST" rev-parse --short HEAD)"

mkext() { # mkext <name> <hooks>  <body on stdin>
  cat > "$CONS/.claude/skills/ai-dlc/extensions/$1.md" <<EOF
---
kind: step-domain
hooks: $2
id: $1
push_candidate: false
conforms_to: 16
---

$(cat)
EOF
}

# THE SUBJECT: same number, same title, and core gained it on THIS pull.
mkext ABSORBED steps/widget.md <<'MD'
### 9. Absorbed Widget Check.

The consumer's copy of a check upstream has now taken.
MD

# THE CONTROL, and it is the sharp one. Identical in every respect — same entry shape, same
# hooked file, same number-and-title agreement with core — except that core's `### 3.` existed
# at BASE. An arm that fires LC-E6 on this is not reading the base at all; it is reporting
# "this entry duplicates core", which is LC-E5's weaker and non-destructive claim.
mkext PREEXISTING steps/widget.md <<'MD'
### 3. Pre-existing Widget Check.

A duplicate the consumer has been shipping for releases.
MD

# THE RENUMBERED PATH, which is a SECOND emit site and would otherwise be untested. Same title
# as core's new `### 9.`, filed under a different number — the case a number-keyed join cannot
# see, and the one core's own prose records as how a duplicate hid for ~35 minor versions.
mkext RENUMBERED steps/widget.md <<'MD'
### 5. Absorbed Widget Check.

The same check, carried under the consumer's own number.
MD

run_drift() { bash "${1:-$DRIFT}" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>/dev/null; }
OUT="$(run_drift)"
st() { printf '%s\n' "$OUT" | awk -F'\t' -v e="$1" '$2 ~ e {print $1}'; }

# --- SANITY: the classifier ran and classified these entries --------------------------------
if [ "$(printf '%s\n' "$OUT" | grep -c 'ABSORBED\.md')" -ge 1 ]; then
  ok "the classifier produced rows for the seeded entries"
else
  bad "FIXTURE BROKEN — no row for the subject entry at all; every assertion below would be vacuous"
  echo; echo "layer-absorption-retire: FIXTURE BROKEN" >&2; exit 2
fi

# --- ASSERTION 1: LC-E6 FIRES ---------------------------------------------------------------
# The first run anywhere to produce this status. Until this arm, `fixture: none` was accurate
# and the clause's zero on any consumer meant nothing.
if grep -qx EXTENSION-RETIRE-CANDIDATE <<<"$(st 'ABSORBED\.md$')"; then
  ok "EXTENSION-RETIRE-CANDIDATE [LC-E6] FIRES when upstream absorbs an entry's check on this pull"
else
  bad "LC-E6 did not fire on an absorption core landed between base and theirs — the clause has no demonstrated firing case, so no consumer's zero for it is readable"
fi

# --- ASSERTION 2: and it is the RIGHT one of the two ----------------------------------------
# The control must come back LC-E5, not LC-E6. Same comparison, opposite tag, decided only by
# the base. Asserting the control's POSITIVE status rather than the absence of LC-E6 on it:
# a classifier that had stopped classifying would satisfy the absence and fail this.
if grep -qx EXTENSION-RESTATES-CORE <<<"$(st 'PREEXISTING\.md$')"; then
  ok "  and a duplicate core ALREADY had at base comes back EXTENSION-RESTATES-CORE [LC-E5] instead"
else
  bad "  the pre-existing duplicate did not come back as LC-E5: $(st 'PREEXISTING\.md$' | tr '\n' ' ')"
fi
if grep -qx EXTENSION-RETIRE-CANDIDATE <<<"$(st 'PREEXISTING\.md$')"; then
  bad "  CONTROL: LC-E6 fired on a duplicate that predates the pull — the arm is reporting 'duplicates core', not 'core absorbed it', and its 'retire the copy' is then advice about text upstream did not just take"
else
  ok "  and LC-E6 stays silent on it — the tag is read from the base, not from the duplication"
fi

# --- ASSERTION 3: the RENUMBERED emit site ---------------------------------------------------
if grep -qx EXTENSION-RETIRE-CANDIDATE <<<"$(st 'RENUMBERED\.md$')"; then
  ok "  and an absorption landed under a DIFFERENT number fires it too (the second emit site)"
else
  bad "  an absorption renumbered by core went unreported — a number-keyed join is exactly how a duplicate hid across ~35 minor versions, which is why this arm exists"
fi

# --- MUTANTS ---------------------------------------------------------------------------------
# COPIES of the whole reconcile directory (layer-drift sources lib.sh from beside it, and a lone
# script copy dies before printing anything), `cmp -s`-guarded so a sed that matched nothing
# cannot pass as a mutation, each aimed at ONE assertion.
MUT="$ROOT/mut"; rm -rf "$MUT"; mkdir -p "$MUT"
cp "$(dirname "$DRIFT")"/*.sh "$MUT/" 2>/dev/null || true

# THE UNMUTATED CONTROL. Both mutants below assert that a row DISAPPEARS, and a copy that cannot
# run emits nothing — which reads exactly like a kill.
cp "$DRIFT" "$MUT/layer-drift.sh"
CTL="$(run_drift "$MUT/layer-drift.sh")"
ctl_n="$(printf '%s\n' "$CTL" | awk -F'\t' '$1=="EXTENSION-RETIRE-CANDIDATE"' | grep -c . || true)"
if [ "$ctl_n" -eq 2 ]; then
  ok "CONTROL: an unmutated copy in a fresh directory reproduces both LC-E6 rows"
else
  bad "CONTROL: the unmutated copy produced $ctl_n LC-E6 row(s), not 2 — the mutant verdicts below are unreadable"
fi

# MUTANT 1 — force the tag to PRE-EXISTING, i.e. stop consulting the base. Assertion 1 must go
# red; assertion 2's LC-E5 control must NOT, because that entry was already tagged PRE-EXISTING.
sed 's@then tag=PRE-EXISTING; else tag=NEW-THIS-PULL; fi@then tag=PRE-EXISTING; else tag=PRE-EXISTING; fi@' \
  "$DRIFT" > "$MUT/layer-drift.sh"
if cmp -s "$DRIFT" "$MUT/layer-drift.sh"; then
  bad "MUTANT 1 did not apply — the tag assignment it targets has been respelled, so it proves nothing"
else
  M1="$(run_drift "$MUT/layer-drift.sh")"
  m1_st() { printf '%s\n' "$M1" | awk -F'\t' -v e="$1" '$2 ~ e {print $1}'; }
  if grep -qx EXTENSION-RETIRE-CANDIDATE <<<"$(m1_st 'ABSORBED\.md$')"; then
    bad "MUTANT 1 SURVIVED: LC-E6 still fires with the tag forced PRE-EXISTING, so assertion 1 is not testing the base comparison"
  else
    ok "MUTANT 1 (tag forced PRE-EXISTING): LC-E6 goes silent — the base comparison is what makes it an absorption rather than a duplicate"
  fi
  if grep -qx EXTENSION-RESTATES-CORE <<<"$(m1_st 'PREEXISTING\.md$')"; then
    ok "  and the LC-E5 control is unmoved by it — the two arms are not entangled"
  else
    bad "  MUTANT 1 also moved the LC-E5 control: the two arms are entangled and one of them proves nothing alone"
  fi
fi

# MUTANT 2 — break the renumbered search's title predicate so only the same-number arm can fire.
# Assertion 3 must go red; assertion 1 must NOT, because ABSORBED matches core at the SAME number.
sed 's@^        same_section "\$t_ext" "\$t_up" || continue@        false \&\& same_section "$t_ext" "$t_up" || continue@' \
  "$DRIFT" > "$MUT/layer-drift.sh"
if cmp -s "$DRIFT" "$MUT/layer-drift.sh"; then
  bad "MUTANT 2 did not apply — the renumbered title search it targets has been respelled, so it proves nothing"
else
  M2="$(run_drift "$MUT/layer-drift.sh")"
  m2_st() { printf '%s\n' "$M2" | awk -F'\t' -v e="$1" '$2 ~ e {print $1}'; }
  if grep -qx EXTENSION-RETIRE-CANDIDATE <<<"$(m2_st 'RENUMBERED\.md$')"; then
    bad "MUTANT 2 SURVIVED: the renumbered entry still fires with the title search disabled, so assertion 3 is not testing that emit site"
  else
    ok "MUTANT 2 (renumbered title search disabled): only the renumbered row disappears"
  fi
  if grep -qx EXTENSION-RETIRE-CANDIDATE <<<"$(m2_st 'ABSORBED\.md$')"; then
    ok "  and the same-number row survives it — the two emit sites are asserted separately"
  else
    bad "  MUTANT 2 also killed the same-number row: assertions 1 and 3 are entangled"
  fi
fi

echo ""
if [ "$fails" -eq 0 ]; then echo "layer-absorption-retire: PASS"; exit 0; fi
echo "layer-absorption-retire: FAIL ($fails)"; exit 1
