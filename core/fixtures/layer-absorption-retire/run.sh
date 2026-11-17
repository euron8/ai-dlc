#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
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
# Absolute, because the loaded ld_main locates its siblings from the path it was sourced by.
case "$DRIFT" in /*) ;; *) DRIFT="$PWD/$DRIFT" ;; esac
echo "HERMETIC-CONSUMED $(cd "$(dirname "$DRIFT")" && pwd)/$(basename "$DRIFT")"

ROOT="$(mktemp -d "${TMPDIR:-/tmp}/layer-absorption-retire.XXXXXX")"
trap 'rm -rf "$ROOT"' EXIT
DIST="$ROOT/dist"; CONS="$ROOT/consumer"

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }
# A literal-tail path, never `. "$VAR"`: in a fixture opted in by an inproc: row, P1 reads an opaque source as a drive.
[ -f "$HERE/../lib/mutant.sh" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $HERE" >&2; exit 2; }
. "$HERE/../lib/mutant.sh" || { echo "FIXTURE ERROR: sourcing lib/mutant.sh failed" >&2; exit 2; }
. "$HERE/../lib/inproc.sh" || { echo "FIXTURE ERROR: sourcing lib/inproc.sh failed" >&2; exit 2; }
. "$HERE/../lib/layout.sh" || { echo "FIXTURE ERROR: sourcing lib/layout.sh failed" >&2; exit 2; }
echo "layer-absorption-retire:"

# IN PROCESS (BL-878). layer-drift.sh is SOURCED ONCE (its guard returns after defining ld_main) and every drive
# is `ld_ip`, which runs ld_main through inproc_run in a subshell made to look like a fresh `bash layer-drift.sh`.
# lib.sh builds its own memo only at BASH_SUBSHELL 0, which no subshell is, so each run is handed a fresh private
# memo as private as the CLI's own; a caller that exports one (the memo cell below) keeps it. No cli cell here:
# layer-title-join owns layer-drift's cli equivalence cells. A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECT: a subject
# with neither the `ld_main() {` line nor the column-0 source guard predates the wrap and reads SKIP (exit 0, never
# an ok); exactly one half is a respelled subject and FAILs; a subject grep cannot READ is FIXTURE ERROR.
wrap_gate() { # wrap_gate <file> <entry> -> 0 wrapped, 3 predates the wrap, 1 one half only (FAIL printed), 2 unreadable
  local d g
  grep -q "^$2() {\$" "$1"; d=$?
  grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$1"; g=$?
  if [ "$d" -gt 1 ] || [ "$g" -gt 1 ]; then
    echo "FIXTURE ERROR: cannot read $1 (grep exit $d/$g), so the in-process wrap cannot be judged; nothing was asserted" >&2
    return 2
  fi
  [ "$d$g" = 00 ] && return 0
  [ "$d$g" = 11 ] && return 3
  if [ "$d" = 1 ]; then echo "  FAIL  $1 carries the column-0 source guard but no \`$2() {\` line -- a respelled subject this fixture cannot drive"
  else echo "  FAIL  $1 defines \`$2() {\` but carries no column-0 source guard -- a respelled subject; sourcing it would run $2 in this shell"; fi
  return 1
}
wrap_gate "$DRIFT" ld_main; g_ld=$?
[ "$g_ld" = 2 ] && exit 2
if [ "$g_ld" = 1 ]; then echo "layer-absorption-retire: 1 FAILED"; exit 1; fi
if [ "$g_ld" = 3 ]; then echo "SKIP: subject predates the in-process wrap"; fx_skip_exit "$HERE"; fi
inproc_load "$DRIFT" || { echo "FIXTURE BROKEN: sourcing $DRIFT defined nothing" >&2; exit 2; }
declare -F ld_main > /dev/null || { echo "FIXTURE BROKEN: sourcing $DRIFT defined no ld_main" >&2; exit 2; }
ld_ip() { # what `bash "$DRIFT" "$@"` gives, in process; a fresh private memo per run unless the caller exported one
  local _m _rc
  case "$(declare -p AI_DLC_RECONCILE_MEMO 2>/dev/null)" in "declare -x"*) inproc_run "$DRIFT" ld_main "$@"; return ;; esac
  _m="$(mktemp -d "${TMPDIR:-/tmp}/reconcile-memo.XXXXXX")" || return 125
  AI_DLC_RECONCILE_MEMO="$_m" inproc_run "$DRIFT" ld_main "$@"; _rc=$?
  rm -rf "$_m"; return "$_rc"
}

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

run_drift() { ld_ip "$DIST" "$BASE" "$THEIRS" "$CONS" 2>/dev/null; }
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
# The layout is WHICH candidate resolved, not a pattern on the path: $DRIFT keeps the `..`
# segments it was built from, so a `*/core/skills/...` glob never matches it and part 2 skipped in
# the distribution on a pre-fix engine.
b376_isdist=0; [ "$DRIFT" = "$HERE/../../skills/ai-dlc-update/reconcile/layer-drift.sh" ] && b376_isdist=1
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

    # b376_drive <engine> <tag> <dist> <cons> -- one in-process run, stdout/stderr/rc to files under $BW. <engine>
    # is always the loaded $DRIFT (no copy is driven), kept as an argument so the call sites read as before.
    b376_drive() {
      ld_ip "$3" "$BB" "$BT" "$4" > "$BW/$2.out" 2> "$BW/$2.err"
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
  fi
fi

# --- A MEMO THAT CANNOT SERVE THE BASE CATALOG REFUSES; IT NEVER RE-TAGS A DUPLICATE ---------------
# The numbered arm's base catalog was `git_show | anchors_of_stream`, whose final `grep -E '.'` exits 1
# on an empty stream. Under pipefail that 1 outranked a memo serve that failed EMPTY (125), so the
# base read as no catalog and PREEXISTING's LC-E5 became LC-E6 -- "retire your copy" -- at rc 0. A
# warm memo, the base blob of steps/widget.md emptied (`.s` and `.c`), and the refusal demanded.
LM="$ROOT/lar-memo"; mkdir -p "$LM"
AI_DLC_RECONCILE_MEMO="$LM" ld_ip "$DIST" "$BASE" "$THEIRS" "$CONS" > "$ROOT/lm.ctl" 2>/dev/null; lm_rc=$?
lm_n=0
for lm_f in "$LM"/"s "*" ${BASE}:core%2Fskills%2Fai-dlc%2Fsteps%2Fwidget.md.s"; do
  [ -f "$lm_f" ] || continue; lm_n=$((lm_n + 1)); : > "$lm_f"; : > "${lm_f%.s}.c"
done
AI_DLC_RECONCILE_MEMO="$LM" ld_ip "$DIST" "$BASE" "$THEIRS" "$CONS" > "$ROOT/lm.out" 2> "$ROOT/lm.err"; lm_frc=$?
if [ "$lm_rc" != 0 ] || ! awk -F'\t' '$1=="EXTENSION-RESTATES-CORE" && $2 ~ /PREEXISTING\.md$/ {f=1} END {exit !f}' "$ROOT/lm.ctl" \
   || [ "$lm_n" -ne 1 ]; then
  bad "FIXTURE BROKEN — the base-catalog memo cell's warm run was rc=$lm_rc without PREEXISTING's LC-E5 row, or found $lm_n memo key(s) for the base blob (want 1)"
elif [ "$lm_frc" = 1 ] && grep -qF 'could not be served by the reconcile memo' "$ROOT/lm.err" \
     && ! grep -q 'EXTENSION-RETIRE-CANDIDATE' "$ROOT/lm.out"; then
  ok "a base catalog the memo cannot serve REFUSES — exit 1, the memo named, no LC-E6 row"
else
  bad "a base catalog the memo cannot serve gave rc=$lm_frc and PREEXISTING '$(awk -F'\t' '$2 ~ /PREEXISTING\.md$/ {print $1}' "$ROOT/lm.out" | tr '\n' ' ')' — a lost cached object re-tagged a duplicate"
fi

echo ""
report_end layer-absorption-retire
