#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# layer-conforms-to — prove the per-entry contract receipt (E17 / W6) and the
# LAYER_CONFORMANCE machine footer can FAIL, and prove the one property that is an
# ABSENCE: the receipt never silences a clause.
#
# Usage: run.sh [--matrix] [path-to-validate-layer-entries.sh]
# Exit:  0 = every assertion holds, 1 = something regressed.
#
# THE LOAD-BEARING ASSERTION IS PART 3. `conforms_to` was specified — in the contract's own
# header for eight versions, and in the plan that scheduled this work — as a SKIP: "an entry
# declaring conforms_to: N is held only to clauses with since <= N". Built that way it is a
# one-line-per-file escape hatch from every clause core has allocated since, and the reference
# consumer's 49 band ERRORs sit at since 4 and since 8. So the shipped reader reports scope and
# subtracts nothing, and that is a property no ordinary assertion can see: the code for it is
# absent. MUTANT m2 supplies the missing skip and the assertion catches the entry going quiet.
#
# Every mutant is a COPY guarded by `cmp -s`, is accompanied by an UNMUTATED control copy from
# the same directory, asserts a POSITIVE measured outcome rather than the absence of a message,
# and is scored so that it fails only its own assertion.
#
# THE MUTANT MATRIX (mutant-battery rule). A mutant is driven ONCE, over one tree, and that output can be read
# through every arm that reads the same tree: BAD (undeclared abovecv band), NOLC (nolc nolcfooter), CONS (entries
# atcur) and SEALED (sealed onemsg). PER PUSH a mutant's DECIDING arm and its named TWIN are scored; with --matrix
# every arm over the mutant's own drive is scored and printed as one `MATRIX <mutant> <arm> KILLED|GREEN` row. An
# arm is KILLED when the predicate its unmutated ok asserts no longer holds on the mutant's output. The block below
# is the one source; a plain run refuses a mutant with no row, and a cell that disagrees with its row is a failure.
# Arm tokens are the base-pass flag names without the B_ prefix. No new harness: each mutant's output is the one
# its kill already reads.
# RE-MEASURE whenever an arm or a mutant is added or changed. hermetic-run.sh runs a fixture under `env -i` and
# forwards no argument, so the matrix is NOT reached through it; run.sh is invoked directly from the repo root.
# MUTANT-MATRIX-REMEASURE bash core/fixtures/layer-conforms-to/run.sh --matrix
# MUTANT-MATRIX m1 decides=undeclared twins=abovecv
# MUTANT-MATRIX m2 decides=band twins=undeclared
# MUTANT-MATRIX m3 decides=nolc twins=nolcfooter
# MUTANT-MATRIX m4 decides=entries twins=atcur
# MUTANT-MATRIX m5 decides=abovecv twins=undeclared
# MUTANT-MATRIX m6 decides=sealed,onemsg twins=- why=m6's drive has two cells, sealed and onemsg, and both read KILLED
# MUTANT-MATRIX m7 decides=onemsg twins=sealed
# A MATRIX row is a measurement and not a second kill emission: its kill goes through mutant_killed behind the
# base-pass flag of the cell's own arm. The mutant name reaches mutant_killed as a variable:
# MUTANT-MATRIX-DYNAMIC mx_cell why=passes each of the seven mutant names m1 to m7 as a variable and every name keeps its own row
# MUTANT-MATRIX-CONTROL CONTROL why=the unmutated copy beside every mutant must reproduce the shipped error count so a mutant's change is attributable
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
MATRIX=0; LARG=""
for _a in "$@"; do
  case "$_a" in
    --matrix) MATRIX=1 ;;
    *) LARG="$_a" ;;
  esac
done

pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
LINTER="$(pick "$LARG" "$HERE/../../../scripts/ai-dlc/validate-layer-entries.sh" \
                        "$HERE/../../scripts/validate-layer-entries.sh" \
                        "$HERE/../../../core/scripts/validate-layer-entries.sh")"
[ -n "$LINTER" ] || { echo "FIXTURE ERROR: cannot locate validate-layer-entries.sh" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/scripts/validate-layer-entries.sh"
[ -f "$(dirname "$LINTER")/artifact-path-config.sh" ] && echo "HERMETIC-CONSUMED core/scripts/artifact-path-config.sh"

ROOT="$(bash "$HERE/seed.sh")"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/layer-conforms-to-m.XXXXXX")"
trap 'rm -rf "$ROOT" "$TMP"' EXIT
CONS="$ROOT/consumer"; BAD="$ROOT/bad-consumer"; NOLC="$ROOT/no-contract"

fails=0
ASSERTIONS=0
ok()  { ASSERTIONS=$((ASSERTIONS+1)); printf '  ok    %s\n' "$1"; }
bad() { ASSERTIONS=$((ASSERTIONS+1)); fails=$((fails+1)); printf '  FAIL  %s\n' "$1"; }
say() { if [ "$1" = 1 ]; then ok "$2"; else bad "$2"; fi; }
MUT_LIB="$(cd "$HERE/../lib" 2>/dev/null && pwd)/mutant.sh"
[ -f "$MUT_LIB" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $HERE" >&2; exit 2; }
. "$MUT_LIB"
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"

# NO run() HELPER, deliberately. `OUT="$(run ...)"` evaluates the helper in a SUBSHELL, so an
# rc it assigns to a global is discarded and every exit-code assertion below would read a stale
# 0 — the `$( )` swallowing state that cost v0.217.0 a whole silent mutant. Each call site
# captures `$?` on the same line as its own command substitution.

# footer_field <output> <name> -> the value of name= on the LAYER_CONFORMANCE line
# A HERE-STRING, not a pipe, and for I54's reason one reader over: this awk program `exit`s at
# the first match, so under pipefail a large enough value would make the writer die on EPIPE and
# the field read as absent. The redirect goes at the end of the awk command and the pipe is gone.
footer_field() {
  awk -v k="$2" '
    /^LAYER_CONFORMANCE / { for (i=2; i<=NF; i++) { split($i, p, "="); if (p[1] == k) { print p[2]; exit } } }' <<<"$1"
}

echo "layer-conforms-to:"

# ---------------------------------------------------------------------------
# Part 1 — the conforming consumer, and the footer's counts
# ---------------------------------------------------------------------------
CLEAN_OUT="$(bash "$LINTER" "$CONS" 2>&1)"; CLEAN_RC=$?
say "$([ "$CLEAN_RC" -eq 0 ] && echo 1 || echo 0)" \
  "a consumer whose every entry carries a current receipt exits 0"
if [ "$(footer_field "$CLEAN_OUT" entries)" = 3 ]; then
  ok "the footer counts 3 entries — 2 extensions AND the override, so the pass walks both layers"; B_entries=1
else
  bad "the footer counts 3 entries — 2 extensions AND the override, so the pass walks both layers"
fi
if [ "$(footer_field "$CLEAN_OUT" at_current)" = 3 ]; then ok "the footer counts 3 at_current"; B_atcur=1
else bad "the footer counts 3 at_current"; fi
say "$([ "$(footer_field "$CLEAN_OUT" contract_version)" = "$(awk '/^contract_version:/{print $2; exit}' "$CONS/.claude/skills/ai-dlc/layer-contract.yaml")" ] && echo 1 || echo 0)" \
  "the footer's contract_version is READ from the consumer's own installed contract"

# ---------------------------------------------------------------------------
# Part 2 — one arm per malformed receipt
# ---------------------------------------------------------------------------
BAD_OUT="$(bash "$LINTER" "$BAD" 2>&1)"; BAD_RC=$?
has() { grep -Fq "$1" <<<\"$BAD_OUT\"; }

say "$([ "$BAD_RC" -eq 1 ] && echo 1 || echo 0)"  "a malformed receipt exits 1 — the consumer's pre-push refuses"
say "$(has "no-receipt.md: missing 'conforms_to:'" && echo 1 || echo 0)"      "E17 reports a MISSING receipt"
say "$(has "not-a-number.md: conforms_to 'eight' is not" && echo 1 || echo 0)" "E17 reports a NON-NUMERIC receipt"
# DERIVED, not written down. This read `conforms_to 10`, which was one above the contract at
# the release that shipped it and became the contract's OWN version at the next bump — the
# assertion then asked E17 to reject a receipt that had become legal, and went red for a
# reason that had nothing to do with E17. The seed already derives the value as CV+1; this
# side has to derive it from the same place or the pair drifts on every bump.
CV_NOW="$(awk '/^contract_version:/{print $2; exit}' "$CONS/.claude/skills/ai-dlc/layer-contract.yaml")"
[ -n "$CV_NOW" ] || { echo "FIXTURE ERROR: no contract_version in the seeded contract" >&2; exit 2; }
if has "above-cv.md: conforms_to $((CV_NOW + 1)) claims a contract version"; then
  ok "E17 reports a receipt ABOVE contract_version — a version no distribution has reached"; B_abovecv=1
else
  bad "E17 reports a receipt ABOVE contract_version — a version no distribution has reached"
fi
if [ "$(footer_field "$BAD_OUT" undeclared)" = 1 ]; then
  ok "the footer's undeclared count is the measured 1, not a restatement of the error count"; B_undeclared=1
else
  bad "the footer's undeclared count is the measured 1, not a restatement of the error count"
fi

# W6 — one line per run, and it must name the entry AND the clauses that postdate it.
say "$(has 'W6 1 of 4 layer entr' && echo 1 || echo 0)" \
  "W6 reports the behind entry once per run, against a measured total"
say "$(grep -Fq 'LC-N5' <<<\"$BAD_OUT\" && echo 1 || echo 0)" \
  "W6's worklist names LC-N5 — a clause introduced after the entry's declared version"
say "$([ "$(footer_field "$BAD_OUT" behind)" = 1 ] && echo 1 || echo 0)" "the footer counts 1 behind"

# ---------------------------------------------------------------------------
# Part 3 — THE NON-SILENCING PROPERTY
# ---------------------------------------------------------------------------
# behind-and-in-core-range.md declares conforms_to: 1 and allocates a heading number core
# already defines. LC-N5 was introduced at since 4. Under the skip semantics the contract
# specified for eight versions this entry escapes the band ERROR outright.
if has 'behind-and-in-core-range.md: SECTION ID OUT OF BAND'; then
  ok "an entry at conforms_to 1 STILL takes the band ERROR from a clause introduced at since 4"; B_band=1
else
  bad "an entry at conforms_to 1 STILL takes the band ERROR from a clause introduced at since 4"
fi

# ---------------------------------------------------------------------------
# Part 4 — the refusal arm: an absent contract is not a clean one
# ---------------------------------------------------------------------------
NOLC_OUT="$(bash "$LINTER" "$NOLC" 2>&1)"; NOLC_RC=$?
if [ "$NOLC_RC" -eq 1 ]; then
  ok "a consumer with no installed layer-contract.yaml exits 1 rather than reporting clean"; B_nolc=1
else
  bad "a consumer with no installed layer-contract.yaml exits 1 rather than reporting clean"
fi
say "$(grep -Fq 'went UNCHECKED in this run' <<<\"$NOLC_OUT\" && echo 1 || echo 0)" \
  "the refusal says the receipts were not judged, rather than judging them clean"
if [ "$(footer_field "$NOLC_OUT" contract_version)" = '-' ]; then
  ok "the footer reads contract_version=- when the contract could not be read, never a plausible number"; B_nolcfooter=1
else bad "the footer reads contract_version=- when the contract could not be read, never a plausible number"; fi

# ---------------------------------------------------------------------------
# Part 4b — PRESENT BUT UNREADABLE is not MALFORMED, and the two must not share a message
# ---------------------------------------------------------------------------
# An awk that cannot open the contract prints nothing and exits 2; a contract lacking
# `contract_version:` prints nothing and exits 0. Keyed on the value alone both drew
# `got '<none>'`, and the operator was told to repair a file that is intact. The pair below is
# the discriminating input: the SAME consumer, once sealed at mode 000 and once readable with
# the version line deleted. Each must draw its own message and not the other's.
SEALED="$TMP/sealed"; MALF="$TMP/malformed"
cp -R "$CONS" "$SEALED"; cp -R "$CONS" "$MALF"
SEALED_LC="$SEALED/.claude/skills/ai-dlc/layer-contract.yaml"
MALF_LC="$MALF/.claude/skills/ai-dlc/layer-contract.yaml"
awk '!/^contract_version:/' "$CONS/.claude/skills/ai-dlc/layer-contract.yaml" > "$MALF_LC"
chmod 000 "$SEALED_LC"
# Restore on exit: a mode-000 file is the one thing in TMP a later cleanup could trip on.
trap 'chmod -R u+rwX "$TMP" 2>/dev/null; rm -rf "$ROOT" "$TMP"' EXIT
# The seal must take, or every assertion below is about a READABLE file. Under root it does
# not, and that is a broken fixture rather than a regression.
if awk '{exit}' "$SEALED_LC" 2>/dev/null; then
  echo "FIXTURE BROKEN: chmod 000 did not make the contract unreadable (running as root?) — Part 4b cannot express its subject" >&2
  exit 2
fi
grep -q '^contract_version:' "$MALF_LC" && { echo "FIXTURE BROKEN: the malformed contract still carries contract_version:" >&2; exit 2; }
SEAL_OUT="$(bash "$LINTER" "$SEALED" 2>&1)"; SEAL_RC=$?
MALF_OUT="$(bash "$LINTER" "$MALF" 2>&1)"
UNREAD_MSG='is present but UNREADABLE'
if [ "$SEAL_RC" -eq 1 ] && grep -Fq "$UNREAD_MSG" <<<"$SEAL_OUT"; then
  ok "a contract present at mode 000 exits 1 and is reported as UNREADABLE, by its own E17 message"; B_sealed=1
else
  bad "a contract present at mode 000 exits 1 and is reported as UNREADABLE, by its own E17 message"
fi
if grep -Fq "got '<none>'" <<<"$SEAL_OUT" || grep -Fq 'read ZERO clauses' <<<"$SEAL_OUT" || grep -Fq "could not read 'consumer_crosswalk_file:'" <<<"$SEAL_OUT"; then
  bad "the sealed contract draws NONE of the malformed-contract messages (got '<none>', ZERO clauses, missing crosswalk key) — one cause, one message"
else
  ok "the sealed contract draws NONE of the malformed-contract messages (got '<none>', ZERO clauses, missing crosswalk key) — one cause, one message"; B_onemsg=1
fi
say "$(grep -Fq "got '<none>'" <<<"$MALF_OUT" && ! grep -Fq "$UNREAD_MSG" <<<"$MALF_OUT" && echo 1 || echo 0)" \
  "NEAR-MISS: a READABLE contract missing contract_version still says got '<none>' and is NOT called unreadable"
say "$(grep -Fq "$UNREAD_MSG" <<<"$CLEAN_OUT" && echo 0 || echo 1)" \
  "the readable, well-formed consumer never draws the UNREADABLE message"

# ---------------------------------------------------------------------------
# Part 5 — mutants
# ---------------------------------------------------------------------------
mk() { # mk <name> <sed-or-awk-command...>  -- build a mutant copy, guarded by cmp -s
  local name="$1"; shift
  if ! "$@" < "$LINTER" > "$TMP/$name.sh"; then
    bad "MUTANT $name: the mutating command itself failed, so nothing below is a kill"
    return 1
  fi
  if cmp -s "$LINTER" "$TMP/$name.sh"; then
    bad "MUTANT $name: the mutation matched NOTHING, so its kill below would prove nothing"
    return 1
  fi
  # A truncated or unparseable copy dies before it lints anything, and a run that emits no
  # findings is indistinguishable from one the mutation silenced.
  if ! bash -n "$TMP/$name.sh" 2>/dev/null; then
    bad "MUTANT $name: the mutated copy does not parse, so its silence is a syntax error and not a kill"
    return 1
  fi
  return 0
}

# THE UNMUTATED CONTROL, from the same directory as every mutant. A copy that dies for an
# unrelated reason emits nothing, and "no output" otherwise scores as a kill.
cp "$LINTER" "$TMP/control.sh"
CTL_OUT="$(bash "$TMP/control.sh" "$BAD" 2>&1)"; CTL_RC=$?
if [ "$CTL_RC" -eq 1 ] && [ "$(footer_field "$CTL_OUT" errors)" = "$(footer_field "$BAD_OUT" errors)" ]; then
  ok "CONTROL: an unmutated copy reproduces the shipped error count, so a mutant's change is attributable"; B_ctl=1
else
  bad "CONTROL: an unmutated copy reproduces the shipped error count, so a mutant's change is attributable"
fi

# --- the matrix, read off each mutant's own output (no extra run) ----------------------------------
MX_SRC="$HERE/run.sh"; MX_CELLS=0; MX_RUN=0; MX_SEEN=""
mx_row() { grep -m 1 -F -- "# MUTANT-MATRIX $1 decides=" "$MX_SRC"; }
mx_role() { # <mutant> <arm> -> D (decides), T (twin) or - (neither), read from the header block
  local line d tw; line="$(mx_row "$1")"
  [ -n "$line" ] || { echo -; return; }
  d="${line#*decides=}"; d="${d%% *}"; tw="${line#*twins=}"; tw="${tw%% *}"
  case ",$d," in *",$2,"*) echo D; return ;; esac
  case ",$tw," in *",$2,"*) echo T; return ;; esac
  echo -
}
mx_has_row() { [ -n "$(mx_row "$1")" ]; }
# mx_holds <arm> <output> <rc> -> 0 when the arm's unmutated assertion still holds on that output
mx_holds() {
  case "$1" in
    undeclared) [ "$(footer_field "$2" undeclared)" = 1 ] ;;
    abovecv)    grep -Fq "above-cv.md: conforms_to $((CV_NOW + 1)) claims a contract version" <<<"$2" ;;
    band)       grep -Fq 'behind-and-in-core-range.md: SECTION ID OUT OF BAND' <<<"$2" ;;
    nolc)       [ "$3" -eq 1 ] ;;
    nolcfooter) [ "$(footer_field "$2" contract_version)" = '-' ] ;;
    entries)    [ "$(footer_field "$2" entries)" = 3 ] ;;
    atcur)      [ "$(footer_field "$2" at_current)" = 3 ] ;;
    sealed)     [ "$3" -eq 1 ] && grep -Fq "$UNREAD_MSG" <<<"$2" ;;
    onemsg)     ! { grep -Fq "got '<none>'" <<<"$2" || grep -Fq 'read ZERO clauses' <<<"$2" || grep -Fq "could not read 'consumer_crosswalk_file:'" <<<"$2"; } ;;
  esac
}
mx_flag() { case "$1" in
    undeclared) echo "${B_undeclared:-0}" ;; abovecv) echo "${B_abovecv:-0}" ;; band) echo "${B_band:-0}" ;;
    nolc) echo "${B_nolc:-0}" ;; nolcfooter) echo "${B_nolcfooter:-0}" ;; entries) echo "${B_entries:-0}" ;;
    atcur) echo "${B_atcur:-0}" ;; sealed) echo "${B_sealed:-0}" ;; onemsg) echo "${B_onemsg:-0}" ;;
  esac; }
# mx_cell <mutant> <arm> <output> <rc>. The matrix cells are not counted in the assertion floor below.
mx_cell() {
  local m="$1" t="$2" role a0="$ASSERTIONS"
  case " $MX_SEEN " in
    *" $m "*) ;;
    *) MX_SEEN="$MX_SEEN $m"
       if ! mx_has_row "$m"; then bad "mutant $m has no MUTANT-MATRIX row in $MX_SRC -- a per-push run cannot know its deciding arm or its twins"; fi ;;
  esac
  role="$(mx_role "$m" "$t")"
  if [ "$MATRIX" != 1 ] && [ "$role" = - ]; then ASSERTIONS="$a0"; return 0; fi
  [ "$role" = - ] && MX_CELLS=$((MX_CELLS + 1))
  MX_RUN=$((MX_RUN + 1))
  if mx_holds "$t" "$3" "$4"; then
    ok "MATRIX $m $t GREEN"
    if [ "$MATRIX" != 1 ] && [ "$role" = D ]; then bad "mutant $m SURVIVED its deciding arm $t"; fi
  else
    mutant_killed "$(( $(mx_flag "$t") && ${B_ctl:-0} ))" "$m" "MATRIX $m $t KILLED"
    if [ "$MATRIX" != 1 ] && [ "$role" = T ]; then bad "mutant $m tripped arm $t, which the header names as its twin"; fi
  fi
  ASSERTIONS="$a0"
}
mx_bad()    { mx_cell "$1" undeclared "$2" 0; mx_cell "$1" abovecv "$2" 0; mx_cell "$1" band "$2" 0; }
mx_nolc()   { mx_cell "$1" nolc "$2" "$3"; mx_cell "$1" nolcfooter "$2" "$3"; }
mx_cons()   { mx_cell "$1" entries "$2" 0; mx_cell "$1" atcur "$2" 0; }
mx_sealed() { mx_cell "$1" sealed "$2" "$3"; mx_cell "$1" onemsg "$2" "$3"; }

# --- m1: the receipt made OPTIONAL ------------------------------------------------------
if mk m1 sed 's@^    ct="$(fm "$f" conforms_to)" || entry_unreadable "$f"$@    ct="$(fm "$f" conforms_to)" || entry_unreadable "$f"; [ -n "$ct" ] || continue@'; then
  M1_OUT="$(bash "$TMP/m1.sh" "$BAD" 2>&1)"
  if [ "$(footer_field "$M1_OUT" errors)" = 3 ] && [ "$(footer_field "$M1_OUT" undeclared)" = 0 ]; then
    mutant_killed "$(( ${B_undeclared:-0} && ${B_ctl:-0} ))" m1 "MUTANT m1 killed: with the missing-key arm skipped the error count drops 4 -> 3 and undeclared reads 0 on a tree that has one"
  else
    bad "MUTANT m1 SURVIVED: with the missing-key arm skipped the error count drops 4 -> 3 and undeclared reads 0 on a tree that has one"
  fi
  mx_bad m1 "$M1_OUT"
fi

# --- m2: THE SKIP. The semantics this release did NOT build. -----------------------------
# `layer_files()` stops yielding an entry whose receipt is below the `since` of the band
# clause — the practical shape of "held only to clauses with since <= N" for that clause. If
# the fixture cannot see the difference, the non-silencing property in Part 3 is decorative.
if mk m2 sed 's|^layer_files() { \[ -d "$1" \] .*$|layer_files() { [ -d "$1" ] \|\| return 0; find "$1" -type f -name "*.md" ! -name "README.md" 2>/dev/null \| sort \| while IFS= read -r _lf; do _lc="$(fm "$_lf" conforms_to)"; case "$_lc" in ""\|*[!0-9]*) printf "%s\\n" "$_lf" ;; *) [ "$_lc" -ge 4 ] \&\& printf "%s\\n" "$_lf" ;; esac; done; }|'; then
  M2_OUT="$(bash "$TMP/m2.sh" "$BAD" 2>&1)"
  if grep -Fq 'behind-and-in-core-range.md: SECTION ID OUT OF BAND' <<<\"$M2_OUT\"; then
    bad "MUTANT m2 SURVIVED: made subtractive, the receipt at version 1 silences the band ERROR that Part 3 asserts still fires"
  else
    mutant_killed "$(( ${B_band:-0} && ${B_ctl:-0} ))" m2 "MUTANT m2 killed: made subtractive, the receipt at version 1 silences the band ERROR that Part 3 asserts still fires"
  fi
  say "$(grep -Fq "no-receipt.md: missing 'conforms_to:'" <<<\"$M2_OUT\" && echo 1 || echo 0)" \
    "MUTANT m2 leaves the malformed-receipt arms alive (Part 2 and Part 3 are not entangled)"
  mx_bad m2 "$M2_OUT"
fi

# --- m3: the missing-contract refusal removed -------------------------------------------
if mk m3 sed 's|^  err E17 "cannot read the layer contract|  : "cannot read the layer contract|'; then
  M3_OUT="$(bash "$TMP/m3.sh" "$NOLC" 2>&1)"; M3_RC=$?
  if [ "$M3_RC" -eq 0 ] && [ "$(footer_field "$M3_OUT" contract_version)" = '-' ]; then
    mutant_killed "$(( ${B_nolc:-0} && ${B_ctl:-0} ))" m3 "MUTANT m3 killed: without the refusal an uninstalled contract exits 0 while the footer still admits it read no version"
  else
    bad "MUTANT m3 SURVIVED: without the refusal an uninstalled contract exits 0 while the footer still admits it read no version"
  fi
  mx_nolc m3 "$M3_OUT" "$M3_RC"
fi

# --- m4: the footer's counts detached from the run --------------------------------------
if mk m4 sed 's|^    LC_ENTRIES=$((LC_ENTRIES+1))$|    LC_ENTRIES=$((LC_ENTRIES+0))|'; then
  M4_OUT="$(bash "$TMP/m4.sh" "$CONS" 2>&1)"
  if [ "$(footer_field "$M4_OUT" entries)" = 0 ]; then
    mutant_killed "$(( ${B_entries:-0} && ${B_ctl:-0} ))" m4 "MUTANT m4 killed: the footer reports entries=0 on a tree with three, so its counts are produced by the walk and not by the printf"
  else
    bad "MUTANT m4 SURVIVED: the footer reports entries=0 on a tree with three, so its counts are produced by the walk and not by the printf"
  fi
  mx_cons m4 "$M4_OUT"
fi

# --- m5: the above-version arm removed --------------------------------------------------
if mk m5 sed 's|^    elif \[ "$ct" -gt "$LC_CV" \]; then$|    elif false; then|'; then
  M5_OUT="$(bash "$TMP/m5.sh" "$BAD" 2>&1)"
  # With the arm off, an above-version receipt falls through to the else branch and is COUNTED
  # AS CURRENT — strictly worse than merely unreported, and the footer is what says so.
  if [ "$(footer_field "$M5_OUT" errors)" = 3 ] && [ "$(footer_field "$M5_OUT" at_current)" = 1 ]; then
    mutant_killed "$(( ${B_abovecv:-0} && ${B_ctl:-0} ))" m5 "MUTANT m5 killed: a receipt above contract_version stops being reported, drops the count 4 -> 3, and is tallied at_current=1"
  else
    bad "MUTANT m5 SURVIVED: a receipt above contract_version stops being reported, drops the count 4 -> 3, and is tallied at_current=1"
  fi
  mx_bad m5 "$M5_OUT"
fi

# --- m6: the read status discarded again (the BL-123 defect) -----------------------------
# Reverts the unreadable arm to nothing, so a sealed contract falls through to the value-keyed
# arms exactly as it did before. The kill is POSITIVE: the old wrong message must come back.
if mk m6 sed 's|^elif ! LC_CV="$(awk .*; then$|elif false; then|'; then
  M6_OUT="$(bash "$TMP/m6.sh" "$SEALED" 2>&1)"; M6_RC=$?
  if grep -Fq "got '<none>'" <<<"$M6_OUT" && ! grep -Fq "$UNREAD_MSG" <<<"$M6_OUT"; then
    mutant_killed "$(( ${B_sealed:-0} && ${B_ctl:-0} ))" m6 "MUTANT m6 killed: with the read status discarded, a sealed contract is told got '<none>' and the UNREADABLE message is gone"
  else
    bad "MUTANT m6 SURVIVED: with the read status discarded, a sealed contract is told got '<none>' and the UNREADABLE message is gone"
  fi
  say "$(grep -Fq "got '<none>'" <<<"$(bash "$TMP/m6.sh" "$MALF" 2>&1)" && echo 1 || echo 0)" \
    "MUTANT m6 leaves the malformed-contract arm alive (Part 4b's near-miss is not entangled with it)"
  mx_sealed m6 "$M6_OUT" "$M6_RC"
fi

# --- m7: the crosswalk-key arm no longer stands down for an unreadable contract ----------
if mk m7 sed 's|^if \[ "$LC_UNREADABLE" -eq 1 \]; then$|if false; then|'; then
  M7_OUT="$(bash "$TMP/m7.sh" "$SEALED" 2>&1)"; M7_RC=$?
  if grep -Fq "could not read 'consumer_crosswalk_file:'" <<<"$M7_OUT" && grep -Fq "$UNREAD_MSG" <<<"$M7_OUT"; then
    mutant_killed "$(( ${B_onemsg:-0} && ${B_ctl:-0} ))" m7 "MUTANT m7 killed: without the stand-down, the one unreadable file is reported a second time as a missing crosswalk key"
  else
    bad "MUTANT m7 SURVIVED: without the stand-down, the one unreadable file is reported a second time as a missing crosswalk key"
  fi
  mx_sealed m7 "$M7_OUT" "$M7_RC"
fi

# THE ASSERTION-COUNT FLOOR. Several arms above run inside `if mk ...; then` blocks, and a
# mutation that silently matched nothing skips its assertion entirely — a shorter green report,
# which reads exactly like a passing one. v0.217.0 shipped that exact shape once already.
EXPECTED_ASSERTIONS=30
# MX0: a plain run executes no matrix-only cell; --matrix scores every cell and says how many.
if [ "$MATRIX" = 1 ]; then
  echo "MATRIX MODE: $MX_RUN cells"
  if [ "$MX_RUN" -gt 0 ]; then printf '  ok    MX0 matrix mode: %s cells scored\n' "$MX_RUN"; else fails=$((fails+1)); printf '  FAIL  MX0 matrix mode: --matrix scored no cell\n'; fi
elif [ "$MX_CELLS" -eq 0 ]; then printf '  ok    MX0 per-push run: matrix-only cells run = 0 (cells scored: %s)\n' "$MX_RUN"
else fails=$((fails+1)); printf '  FAIL  MX0 per-push run: %s matrix-only cell(s) ran\n' "$MX_CELLS"; fi
echo
if [ "$ASSERTIONS" -ne "$EXPECTED_ASSERTIONS" ]; then
  printf 'layer-conforms-to: FAIL — %d assertions ran, %d expected. An arm did not execute.\n' \
    "$ASSERTIONS" "$EXPECTED_ASSERTIONS"
  exit 1
fi
if [ "$fails" -gt 0 ]; then
  printf 'layer-conforms-to: FAIL (%d of %d assertions)\n' "$fails" "$ASSERTIONS"
  exit 1
fi
printf 'layer-conforms-to: PASS (%d assertions)\n' "$ASSERTIONS"
