#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
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

# --- PART 2: AN UNREADABLE BASE OBJECT REFUSES; A PATH ABSENT AT BASE DOES NOT (BL-376) ----------
#
# THE DEFECT. Five reads take the hooked core file at the BASE side of the range -- three at `$BASE`
# (the numbered catalog that decides the tag above, the unnumbered title arm, the extends: span
# compare) and two at an override's `base_sha` (the supersession surplus measure and the section
# drift compare). `git_show` reads an object it cannot read as an EMPTY file, so with the base blob
# missing the duplicate core carried for releases came back NEW-THIS-PULL and "retire your copy",
# a `## ` title match the same, a span that did not move read as ANCHOR-DRIFT, a section that did
# not move as HARD-OVERRIDE-DRIFT-SECTION -- every one at rc 0.
#
# ONE CONSUMER PER REFUSING SITE, because a refusal exits and a second entry in the same tree would
# never be read: R<k> reaches exactly one base read each, which is what lets each gate's mutant fail
# exactly one arm. The S entry's anchor exists at base and NOT at theirs, so its pair loop stops
# before the section compare and the surplus measure is the only base read it makes -- with an
# anchor present at both, removing that gate would still refuse at the section compare with a
# byte-identical line and its mutant would survive.
#
# NM IS THE NEAR-MISS, AND IT IS THE ARM THE OBVIOUS WRONG FIX FAILS. Every NM entry hooks a core
# file that is NEW this pull, on the SAME damaged store: absent at base is the true answer and must
# keep its empty read, so the absorption still says NEW-THIS-PULL. `have ... || continue` is
# byte-identical to the fix on every healthy world and drops these rows. H is the healthy control:
# the same R entries on the undamaged dist, PRESENCE-shaped, so the refusing worlds differ from a
# clean run by the one missing object.
#
# This part ships ahead of the engine change it guards. A consumer whose installed layer-drift.sh
# predates it SKIPS; in the distribution it runs, so a pre-fix engine goes red.
echo
echo "Part 2 — BL-376: an unreadable base object refuses; a core file new this pull still reads NEW-THIS-PULL"
B376_MARK='EVERY BASE READ IS GATED ON `have`'
case "$DRIFT" in */core/skills/ai-dlc-update/reconcile/layer-drift.sh) b376_isdist=1 ;; *) b376_isdist=0 ;; esac
b376_run=1
if ! grep -qF "$B376_MARK" "$DRIFT"; then
  if [ "$b376_isdist" = 0 ]; then
    printf '  SKIP  BL-376 part 2 -- the installed layer-drift.sh predates the base-read gate; it lands with the pull that carries this fixture\n'
    b376_run=0
  else
    printf '  --    (BL-376: this layer-drift.sh carries no base-read gate; in the distribution part 2 runs anyway and must go red)\n'
  fi
fi

if [ "$b376_run" = 1 ]; then
  BW="$ROOT/b376"; BD="$BW/dist"; BX="$BW/dist-hidden"
  BWP="core/skills/ai-dlc/steps/widget.md"
  mkdir -p "$BD/core/skills/ai-dlc/steps" "$BD/core/schemas"
  bg() { git -C "$BD" -c user.email=f@x -c user.name=f "$@" >/dev/null 2>&1; }
  bg init -q || { echo "FIXTURE ERROR: git init failed for part 2" >&2; exit 2; }
  cp "$ADJ_SRC" "$BD/core/schemas/" || { echo "FIXTURE ERROR: cannot seed the adjudication schema for part 2" >&2; exit 2; }
  cp "$DIST/core/skills/ai-dlc/core-manifest.md" "$BD/core/skills/ai-dlc/"
  printf 'contract_version: 16\n' > "$BD/core/skills/ai-dlc/layer-contract.yaml"
  printf '# Widget\n\n## Widget Overview\n\nCore overview.\n\n### 3. Widget Check.\n\nCore check.\n\n### 9. Retired Section.\n\nOld core text.\n\n## Stable Notes\n\nUnchanged core notes.\n' > "$BD/$BWP"
  bg add -A; bg commit -qm base
  BB="$(git -C "$BD" rev-parse -q --verify HEAD 2>/dev/null)" || BB=""
  printf '# Widget\n\n## Widget Overview\n\nCore overview.\n\n### 3. Widget Check.\n\nCore check, reworded this pull.\n\n## Stable Notes\n\nUnchanged core notes.\n' > "$BD/$BWP"
  printf '# Fresh\n\n## Fresh Overview\n\nNew core overview.\n\n### 7. Fresh Check.\n\nNew core check.\n' > "$BD/core/skills/ai-dlc/steps/fresh.md"
  printf 'contract_version: 16\noverride_supersessions:\n  - shadows: steps/widget.md#9. Retired Section.\n    since_core_version: "9.9.9"\n    reason: core took it.\n  - shadows: steps/fresh.md#7. Fresh Check.\n    since_core_version: "9.9.9"\n    reason: core took it.\n' > "$BD/core/skills/ai-dlc/layer-contract.yaml"
  bg add -A; bg commit -qm theirs
  BT="$(git -C "$BD" rev-parse -q --verify HEAD 2>/dev/null)" || BT=""
  BBS="${BB:0:12}"

  # The damaged copy: widget.md's BASE blob moved aside. Each way the build can fail is named.
  b376_why=""
  BBLOB="$(git -C "$BD" rev-parse -q --verify "${BB}:${BWP}" 2>/dev/null)" || BBLOB=""
  BTBLOB="$(git -C "$BD" rev-parse -q --verify "${BT}:${BWP}" 2>/dev/null)" || BTBLOB=""
  if [ -z "$BB" ] || [ -z "$BT" ] || [ -z "$BBLOB" ] || [ "$BBLOB" = "$BTBLOB" ]; then
    b376_why="base '$BB' theirs '$BT' base blob '$BBLOB' theirs blob '$BTBLOB' -- the two sides must be distinct commits with distinct widget.md blobs"
  else
    cp -R "$BD" "$BX"
    BOBJ="$BX/.git/objects/${BBLOB:0:2}/${BBLOB:2}"
    if ! git -C "$BX" cat-file -e "$BBLOB" 2>/dev/null; then
      b376_why="blob $BBLOB is not readable in the copy BEFORE hiding"
    elif [ ! -f "$BOBJ" ]; then
      b376_why="blob $BBLOB is readable but not loose, so something packed the store"
    elif ! mv "$BOBJ" "$BW/hidden-$BBLOB"; then
      b376_why="blob $BBLOB is loose and could not be moved aside"
    elif [ -z "$(git -C "$BX" ls-tree --full-tree "$BB" -- "$BWP" 2>/dev/null)" ]; then
      b376_why="with the blob hidden the base tree no longer names $BWP"
    elif git -C "$BX" cat-file -e "${BB}:${BWP}" 2>/dev/null; then
      b376_why="with the blob hidden ${BB}:${BWP} still reads"
    elif ! git -C "$BX" cat-file -e "${BT}:${BWP}" 2>/dev/null; then
      b376_why="hiding the base blob also lost the theirs blob, so the world damages more than the base side"
    fi
  fi

  b376_ext() { # <cons> <name> <hooks> <extends or empty> <body>
    local f="$1/.claude/skills/ai-dlc/extensions/$2.md"
    mkdir -p "$1/.claude/skills/ai-dlc/extensions" "$1/.claude/skills/ai-dlc/overrides"
    { printf -- '---\nkind: step-domain\nhooks: %s\nid: %s\npush_candidate: false\nconforms_to: 16\n' "$3" "$2"
      [ -z "$4" ] || printf "extends: '%s'\n" "$4"
      printf -- '---\n\n%s\n' "$5"; } > "$f"
  }
  b376_ovr() { # <cons> <name> <shadows> <body>
    mkdir -p "$1/.claude/skills/ai-dlc/extensions" "$1/.claude/skills/ai-dlc/overrides"
    printf -- '---\nshadows: %s\nbase_sha: %s\nreason: fixture\nconforms_to: 16\n---\n\n%s\n' "$3" "$BB" "$4" \
      > "$1/.claude/skills/ai-dlc/overrides/$2.md"
  }
  b376_r() { # <cons> <arm> -- the one entry that reaches that arm's base read
    case "$2" in
      N) b376_ext "$1" RN steps/widget.md "" $'### 3. Widget Check.\n\nThe consumer copy.' ;;
      T) b376_ext "$1" RT steps/widget.md "" $'### Widget Overview\n\nThe consumer copy.' ;;
      X) b376_ext "$1" RX steps/widget.md '#Stable Notes' 'Prose that augments the stable notes, no heading.' ;;
      O) b376_ovr "$1" RO 'steps/widget.md#Stable Notes' $'## Stable Notes\n\nUnchanged core notes.\nConsumer hardening.' ;;
      S) b376_ovr "$1" RS 'steps/widget.md#9. Retired Section.' $'### 9. Retired Section.\n\nOld core text.\nConsumer surplus.' ;;
    esac
  }
  for k in N T X O S; do b376_r "$BW/c$k" "$k"; b376_r "$BW/cH" "$k"; done
  b376_ext "$BW/cNM" NN steps/fresh.md "" $'### 7. Fresh Check.\n\nThe consumer copy.'
  b376_ext "$BW/cNM" NT steps/fresh.md "" $'### Fresh Overview\n\nThe consumer copy.'
  b376_ext "$BW/cNM" NX steps/fresh.md '#7. Fresh Check.' 'Prose that augments check 7, no heading.'
  b376_ovr "$BW/cNM" NS 'steps/fresh.md#7. Fresh Check.' $'### 7. Fresh Check.\n\nNew core check.\nConsumer surplus.'

  if [ -n "$b376_why" ]; then
    bad "FIXTURE ERROR: part 2's damaged world could not be built -- $b376_why -- so every refusing arm would measure a healthy store"
  else
    ok "part 2 world: widget.md's base blob is unreadable in the copy while its tree entry and its theirs blob are intact"

    # b376_drive <engine> <tag> <dist> <cons> -- one run, stdout/stderr/rc to files under $BW.
    b376_drive() {
      bash "$1" "$3" "$BB" "$BT" "$4" > "$BW/$2.out" 2> "$BW/$2.err"
      echo "$?" > "$BW/$2.rc"
    }
    b376_rc()  { cat "$BW/$1.rc" 2>/dev/null; }
    b376_ref() { awk -v n="core/skills/ai-dlc/steps/widget.md at ${BBS}" 'index($0, "layer-drift: REFUSED") == 1 && index($0, n) { f = 1 } END { exit !f }' "$BW/$1.err"; }
    b376_row() { # <tag> <status> <entry basename> [<needle in detail>]
      awk -F'\t' -v s="$2" -v e="/$3.md" -v n="${4:-}" '$1 == s && substr($2, length($2) - length(e) + 1) == e && index($0, n) { f = 1 } END { exit !f }' "$BW/$1.out"
    }
    # The six runs of one scoring are independent, so they run together; each writes its own files.
    b376_score() { # <engine> -> b376_v "N=ok T=ok ..."
      local e="$1" k r
      for k in N T X O S; do b376_drive "$e" "R$k" "$BX" "$BW/c$k" & done
      b376_drive "$e" NM "$BX" "$BW/cNM" &
      wait
      b376_v=""
      for k in N T X O S; do
        r=no
        if [ "$(b376_rc "R$k")" = 1 ] && b376_ref "R$k" && ! grep -q 'surplus measure' "$BW/R$k.err"; then r=ok; fi
        b376_v="$b376_v $k=$r"
      done
      local nm=no; [ "$(b376_rc NM)" = 0 ] && ! grep -q 'layer-drift: REFUSED' "$BW/NM.err" && nm=yes
      r=no; [ "$nm" = yes ] && b376_row NM EXTENSION-RETIRE-CANDIDATE NN 'NEW-THIS-PULL' && r=ok; b376_v="$b376_v NN=$r"
      r=no; [ "$nm" = yes ] && b376_row NM EXTENSION-TITLE-MATCHES-CORE NT 'NEW-THIS-PULL' && r=ok; b376_v="$b376_v NT=$r"
      r=no; [ "$nm" = yes ] && b376_row NM EXTENSION-ANCHOR-DRIFT NX && r=ok; b376_v="$b376_v NX=$r"
      r=no; [ "$nm" = yes ] && b376_row NM HARD-OVERRIDE-DRIFT-SECTION NS && r=ok; b376_v="$b376_v NO=$r"
      r=no; [ "$nm" = yes ] && b376_row NM OVERRIDE-SUPERSEDED NS 'could NOT be measured' && r=ok; b376_v="$b376_v NSS=$r"
      b376_v="${b376_v# }"
    }
    B376_ALLOK="N=ok T=ok X=ok O=ok S=ok NN=ok NT=ok NX=ok NO=ok NSS=ok"

    # H: the healthy control, PRESENCE-shaped -- every R entry gives its pre-existing reading.
    b376_drive "$DRIFT" H "$BD" "$BW/cH"
    if [ "$(b376_rc H)" = 0 ] && ! grep -q 'layer-drift: REFUSED' "$BW/H.err" \
       && b376_row H EXTENSION-RESTATES-CORE RN 'PRE-EXISTING' && b376_row H EXTENSION-TITLE-MATCHES-CORE RT 'PRE-EXISTING' \
       && b376_row H EXTENSION-OK RX && b376_row H OVERRIDE-OK RO && b376_row H OVERRIDE-SUPERSEDED RS 'MEASURED:'; then
      ok "part 2 H: on the undamaged dist the same five entries read PRE-EXISTING / OK / MEASURED at rc 0 -- the refusing worlds differ by the one hidden object"
    else
      bad "part 2 H: the healthy control did not give the pre-existing readings (rc $(b376_rc H)) -- the refusing arms below would compare against a broken seed"
    fi

    b376_score "$DRIFT"
    for b376_a in $b376_v; do
      case "$b376_a" in
        N=ok)   ok "part 2 N: the numbered catalog read at base refuses rc 1 naming widget.md at base, rather than tagging a pre-existing duplicate NEW-THIS-PULL" ;;
        T=ok)   ok "part 2 T: the unnumbered title read at base refuses rc 1 naming widget.md at base" ;;
        X=ok)   ok "part 2 X: the extends: span read at base refuses rc 1 naming widget.md at base, rather than reporting an unmoved span as ANCHOR-DRIFT" ;;
        O=ok)   ok "part 2 O: an override's section read at base_sha refuses rc 1 naming widget.md, rather than reporting HARD-OVERRIDE-DRIFT-SECTION" ;;
        S=ok)   ok "part 2 S: the supersession surplus read at base_sha refuses rc 1 naming widget.md, and NOT as a staging failure of the surplus measure" ;;
        NN=ok)  ok "part 2 NM: a numbered duplicate of a core file NEW this pull still reads EXTENSION-RETIRE-CANDIDATE NEW-THIS-PULL on the damaged store, rc 0" ;;
        NT=ok)  ok "part 2 NM: a title match on the new file still reads NEW-THIS-PULL" ;;
        NX=ok)  ok "part 2 NM: an extends: span on the new file still reads EXTENSION-ANCHOR-DRIFT" ;;
        NO=ok)  ok "part 2 NM: an override of the new file still reads HARD-OVERRIDE-DRIFT-SECTION (absent at base_sha is an empty section, not a skip)" ;;
        NSS=ok) ok "part 2 NM: its supersession row still says the surplus could NOT be measured, rather than vanishing" ;;
        *)      bad "part 2 ${b376_a%%=*}: arm failed on the engine under test ($b376_v)" ;;
      esac
    done

    # MUTANTS -- one gate removed, one gate turned into the skip-on-absent wrong fix, and the gate
    # moved inside sup_measure's `$( )`. Built in a copy of the whole reconcile directory, each anchor
    # counted (0 = STALE, >1 = AMBIGUOUS), `cmp -s`-guarded, scored by EXACT arm vector. The three
    # `$BASE` gate lines are byte-identical, so each anchor is the gate PLUS the read under it.
    BM="$BW/mut"; mkdir -p "$BM"
    cp "$(dirname "$DRIFT")"/*.sh "$BM/" 2>/dev/null || true
    b376_mut() { # <id> -> writes $BM/layer-drift-<id>.sh; prints OK, STALE or AMBIGUOUS
      python3 - "$DRIFT" "$BM/layer-drift-$1.sh" "$1" <<'B376PY'
import sys
src, dst, mid = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(src).read()
G = {
  "n": ('    have "$BASE" "$cp" || :\n', '    base_anchors="$(git_show "$BASE" "$cp"'),
  "t": ('    have "$BASE" "$cp" || :\n', '    base_titles="$(git_show "$BASE" "$cp"'),
  "x": ('      have "$BASE" "$cp" || :\n', '      ext_old="$(git_show "$BASE" "$cp"'),
  "o": ('    have "$base_sha" "$a_cp" || :\n', '    s_base="$(git_show "$base_sha" "$a_cp"'),
  "s": ('      have "$base_sha" "$(dist_path "${sup_raw%%#*}")" || :\n', '      sup_surplus="$(sup_measure "$sup_raw")"'),
}
kind, site = mid[0], mid[1]
gate, nxt = G[site]
anchor = gate + nxt
n = s.count(anchor)
if n == 0: print("STALE"); sys.exit(0)
if n > 1: print("AMBIGUOUS"); sys.exit(0)
if kind == "g":
    s = s.replace(anchor, nxt, 1)
elif kind == "c":
    s = s.replace(anchor, gate.replace("|| :", "|| continue") + nxt, 1)
elif kind == "w":
    inner = '        cs="$(git_show "$base_sha" "$(dist_path "$fpart")"'
    if s.count(inner) != 1: print("STALE" if s.count(inner) == 0 else "AMBIGUOUS"); sys.exit(0)
    s = s.replace(anchor, nxt, 1)
    s = s.replace(inner, '        have "$base_sha" "$(dist_path "$fpart")" || :\n' + inner, 1)
open(dst, "w").write(s)
print("OK")
B376PY
    }
    cp "$DRIFT" "$BM/layer-drift-unmutated.sh"
    b376_score "$BM/layer-drift-unmutated.sh"
    if [ "$b376_v" != "$B376_ALLOK" ]; then
      bad "FIXTURE ERROR: the UNMUTATED copy in $BM scores '$b376_v', not all-ok, so no mutant verdict below is attributable"
    else
      ok "part 2 CONTROL: an unmutated copy in the mutant directory scores every arm ok, NM's rows present"
      for b376_m in \
        "gn:N=no T=ok X=ok O=ok S=ok NN=ok NT=ok NX=ok NO=ok NSS=ok:the numbered-catalog base gate removed" \
        "gt:N=ok T=no X=ok O=ok S=ok NN=ok NT=ok NX=ok NO=ok NSS=ok:the title-arm base gate removed" \
        "gx:N=ok T=ok X=no O=ok S=ok NN=ok NT=ok NX=ok NO=ok NSS=ok:the extends: span base gate removed" \
        "go:N=ok T=ok X=ok O=no S=ok NN=ok NT=ok NX=ok NO=ok NSS=ok:the override section base_sha gate removed" \
        "gs:N=ok T=ok X=ok O=ok S=no NN=ok NT=ok NX=ok NO=ok NSS=ok:the surplus-measure base_sha gate removed" \
        "cn:N=ok T=ok X=ok O=ok S=ok NN=no NT=ok NX=ok NO=ok NSS=ok:the numbered-catalog gate skipping an absent path" \
        "ct:N=ok T=ok X=ok O=ok S=ok NN=ok NT=no NX=ok NO=ok NSS=ok:the title-arm gate skipping an absent path" \
        "cx:N=ok T=ok X=ok O=ok S=ok NN=ok NT=ok NX=no NO=ok NSS=ok:the extends: span gate skipping an absent path" \
        "co:N=ok T=ok X=ok O=ok S=ok NN=ok NT=ok NX=ok NO=no NSS=ok:the override section gate skipping an absent path" \
        "cs:N=ok T=ok X=ok O=ok S=ok NN=ok NT=ok NX=ok NO=ok NSS=no:the surplus gate skipping an absent path" \
        "ws:N=ok T=ok X=ok O=ok S=no NN=ok NT=ok NX=ok NO=ok NSS=ok:the surplus gate moved inside sup_measure's subshell (refuses under the staging message)"; do
        b376_id="${b376_m%%:*}"; b376_rest="${b376_m#*:}"; b376_want="${b376_rest%%:*}"; b376_what="${b376_rest#*:}"
        b376_ap="$(b376_mut "$b376_id")"; b376_f="$BM/layer-drift-$b376_id.sh"
        if [ "$b376_ap" = STALE ]; then
          bad "FIXTURE STALE: part 2 mutant $b376_id ($b376_what) found no anchor -- the gate moved; re-anchor it, never drop it"
        elif [ "$b376_ap" != OK ] || [ ! -s "$b376_f" ] || cmp -s "$DRIFT" "$b376_f"; then
          bad "FIXTURE ERROR: part 2 mutant $b376_id ($b376_what) did not apply (python said '$b376_ap')"
        elif ! bash -n "$b376_f" 2>/dev/null; then
          bad "FIXTURE ERROR: part 2 mutant $b376_id ($b376_what) does not parse"
        else
          b376_score "$b376_f"
          if [ "$b376_v" = "$b376_want" ]; then
            ok "part 2 MUTANT $b376_id -- $b376_what: KILLED by exactly $(printf '%s' "$b376_v" | tr ' ' '\n' | grep '=no' | cut -d= -f1 | tr '\n' ' ' | sed 's/ $//')"
          else
            bad "part 2 MUTANT $b376_id -- $b376_what: scored '$b376_v', want '$b376_want'"
          fi
        fi
      done
    fi
  fi
fi

echo ""
if [ "$fails" -eq 0 ]; then echo "layer-absorption-retire: PASS"; exit 0; fi
echo "layer-absorption-retire: FAIL ($fails)"; exit 1
