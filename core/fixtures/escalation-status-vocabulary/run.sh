#!/usr/bin/env bash
# escalation-status-vocabulary/run.sh — prove the vocabulary check fires, and that its
# vocabulary is DERIVED.
#
# THE DEFECT. gate-validation.md Check 2 branches on HARD_BLOCK / DECIDED_AUTONOMOUSLY /
# DEFERRAL_REQUEST and has no else. An entry on a fourth token satisfies no branch: Check 2
# does not block on it, does not surface it, and does not record it. It is silently skipped,
# and the gate reports Check 2 as passing. The failure is not a wrong verdict — it is an
# entry no verdict was ever computed for, which is a green indistinguishable from having
# examined nothing.
#
# Measured on the reference consumer: 8 entries on FILED and OPEN, accumulated across the
# sprints they were written in, every gate in that window reporting Check 2 as passing.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

echo "escalation-status-vocabulary:"

# --- Assertion 1: POSITIVE CONTROL — the published set passes ----------------
# Without this, every assertion below is satisfied by a validator that reds on everything.
if bash "$VALIDATOR" "$CLEAN" "$SPEC_SRC" >/dev/null 2>&1; then
  ok "positive control: every token the spec publishes passes"
else
  bad "the check reds on entries using only the published set — it would fail every gate: $(bash "$VALIDATOR" "$CLEAN" "$SPEC_SRC" 2>&1 | grep FAIL | head -1)"
fi

# --- Assertion 2: THE DEFECT — out-of-vocabulary tokens FAIL -----------------
OUT="$(bash "$VALIDATOR" "$DRIFT" "$SPEC_SRC" 2>&1)"; rc=$?
if [ "$rc" -eq 1 ] && grep -q "FILED" <<<"$OUT" && grep -q "OPEN" <<<"$OUT"; then
  ok "drifted entries FAIL (rc=1) and both offending tokens are named"
else
  bad "out-of-vocabulary entries did not fail as expected (rc=$rc): $(printf '%s' "$OUT" | head -2 | tr '\n' ' ')"
fi

# --- Assertion 3: the count is exact, not approximate ------------------------
# 3 entries, 2 of them bad. A validator that reports "some" rather than which is not
# actionable, and one that over-counts is a validator nobody will keep enabled.
if grep -q "FAIL: 2 of 3 escalation entries" <<<"$OUT"; then
  ok "reports exactly 2 of 3 entries out of vocabulary"
else
  bad "wrong count: $(printf '%s\n' "$OUT" | grep 'of .* escalation entries' | head -1)"
fi

# --- Assertion 4: a Status field NOT at line start is still caught ------------
# The naive validator anyone writes first anchors `**Status:**` to line start. Check 2 has
# no such blind spot — it reads the entry — so a mid-entry token is just as silently
# skipped, and a checker that misses it reports a green it did not earn.
if ! bash "$VALIDATOR" "$MIDENTRY" "$SPEC_SRC" >/dev/null 2>&1; then
  ok "a mid-entry **Status:** token outside the set is caught (not only line-anchored ones)"
else
  bad "a mid-entry out-of-vocabulary token passed — the check has the line-anchored blind spot"
fi

# --- Assertion 5: THE DESIGN CLAIM — the set is DERIVED, not restated ---------
# This is the assertion that distinguishes this validator from the hand-listed copy it
# replaces. Add FILED to escalations.md's terminal-status line and the SAME drifted file
# must now pass. If it still fails, the script is carrying its own private set and the
# derivation is decoration.
SPEC_MUT="$WORK/escalations-mutant.md"
# APPEND to whatever the line publishes; do not restate its current contents. This
# anchor used to carry the literal `RESOLVED | OVERRIDDEN`, which made the fixture go
# STALE the moment a token was added to the published set — a hand-listed copy of the
# very set this fixture exists to prove is DERIVED. Insert before the closing backtick
# instead, so the mutant widens the vocabulary whatever it currently holds.
sed 's/^\(\*\*Terminal statuses\*\*.*\)`$/\1 | FILED | OPEN`/' \
  "$SPEC_SRC" > "$SPEC_MUT"
if ! grep -q 'FILED | OPEN' "$SPEC_MUT"; then
  bad "FIXTURE STALE: could not extend the terminal-status line — escalations.md's '**Terminal statuses**' line was reworded"
elif bash "$VALIDATOR" "$DRIFT" "$SPEC_MUT" >/dev/null 2>&1; then
  ok "widening escalations.md's published set makes the same entries pass — the vocabulary is read, not restated"
else
  bad "the drifted file STILL fails after escalations.md was widened — the script carries a private set and 'derived' is decoration"
fi

# --- Assertion 6: MUTANT — narrowing the source must break the clean file -----
# The other direction. If the derivation ignored the format block, the clean file would
# pass no matter what that line says.
SPEC_NARROW="$WORK/escalations-narrow.md"
sed 's/^\*\*Status:\*\* HARD_BLOCK.*/**Status:** HARD_BLOCK/' "$SPEC_SRC" > "$SPEC_NARROW"
if ! grep -qx '\*\*Status:\*\* HARD_BLOCK' "$SPEC_NARROW"; then
  bad "FIXTURE STALE: could not narrow the entry-format Status line — escalations.md's format block was reworded"
elif ! bash "$VALIDATOR" "$CLEAN" "$SPEC_NARROW" >/dev/null 2>&1; then
  ok "narrowing the format block's Status line reds the clean file — BOTH source lines are read"
else
  bad "the clean file still passes with DECIDED_AUTONOMOUSLY/DEFERRAL_REQUEST removed from the source — the format block is not being read"
fi

# --- Assertion 7: unreadable vocabulary source REFUSES, never passes ----------
# A validator that falls back to a built-in set when it cannot read escalations.md has
# reintroduced the hand-listed copy silently. Exit 2 (refusal), not 0 (clean).
LONE="$WORK/lone"; mkdir -p "$LONE"
cp "$VALIDATOR" "$LONE/validate-escalation-status-vocabulary.sh"
LONE_OUT="$(cd "$LONE" && CLAUDE_PROJECT_DIR="$LONE" bash ./validate-escalation-status-vocabulary.sh "$DRIFT" 2>&1)"
lone_rc=$?
if [ "$lone_rc" -eq 2 ] && grep -q "will not guess" <<<"$LONE_OUT"; then
  ok "with escalations.md unreachable the check REFUSES (rc=2) instead of passing"
else
  bad "severed from its vocabulary source the check returned rc=$lone_rc — it guessed a built-in set or reported clean"
fi

# --- Assertions 8-10: WHICH occurrence of `**Status:**` is the entry's status -----
# Assertion 4 above establishes that a non-line-start token is READ. These three establish
# which one is ADJUDICATED when an entry carries more than one, and each is a PAIR: the
# offender must be reported, the near-miss must not.
#
# `rc_tok <file>` -> sets RC to the validator's exit and TOK to the token it named, so an
# arm can assert the token and not merely the verdict. NOT a printing function called
# through `$( )`: a command substitution runs in a SUBSHELL and the exit code assigned
# inside it never reaches the caller, which would make every arm here read 0.
RC=0; TOK=""
rc_tok() {
  local out
  out="$(bash "$VALIDATOR" "$1" "$SPEC_SRC" 2>&1)"; RC=$?
  TOK="$(sed -n "s@.*out-of-vocabulary status '\([^']*\)'.*@\1@p" <<<"$out" | head -1)"
}

# --- Assertion 8: (a) an APPENDED resolution is the token adjudicated -------------
# escalations.md prescribes append-do-not-overwrite and sets the terminal status in a later
# edit, so a resolved entry's live status is its LAST field and the authorship token above
# it is the one it REPLACED. A first-wins reader adjudicates the replaced token and reports
# PASS on the appended one — in the validator whose entire job is rejecting it.
rc_tok "$APPENDED"
if [ "$RC" -eq 1 ] && [ "$TOK" = "$BAD_TOK" ]; then
  ok "(a) an appended resolution status is the token adjudicated"
else
  bad "(a) an appended out-of-vocabulary resolution was not adjudicated (rc=$RC, token '${TOK:-none}') — the reader takes the token the resolution REPLACED"
fi
rc_tok "$APPENDED_OK"
if [ "$RC" -eq 0 ]; then
  ok "(a) near-miss: an appended IN-vocabulary resolution is quiet"
else
  bad "(a) near-miss: an appended legitimate resolution was reported (rc=$RC, token '${TOK:-none}') — the check reds on a correctly resolved entry"
fi

# --- Assertion 9: (b) prose ABOVE the field does not outrank it -------------------
# The match is deliberately not line-anchored (assertion 4), so under first-wins a
# `**Status:**` written inside a sentence SHIELDS the real field beneath it: the widening
# catches a case it also creates. The near-miss carries the same two tokens swapped, so a
# reader that simply prefers prose fails it rather than passing both.
rc_tok "$PROSE_ABOVE"
if [ "$RC" -eq 1 ] && [ "$TOK" = "$BAD_TOK" ]; then
  ok "(b) prose **Status:** ABOVE the field does not outrank the field"
else
  bad "(b) a bad field below a prose **Status:** was not adjudicated (rc=$RC, token '${TOK:-none}') — prose is SHIELDING the field"
fi
rc_tok "$PROSE_ABOVE_OK"
if [ "$RC" -eq 0 ]; then
  ok "(b) near-miss: a bad token in prose above a good field is not adjudicated"
else
  bad "(b) near-miss: prose above the field was adjudicated (rc=$RC, token '${TOK:-none}') — a mention is being read as the field"
fi

# --- Assertion 10: (d) prose BELOW the field, AND THE NEAR-MISS IS THE WHOLE ARM ---
# THE OFFENDER ALONE DOES NOT DISCRIMINATE HERE, AND THAT IS WHY BOTH HALVES ARE ASSERTED
# AND WHY THE OFFENDER'S ARM READS THE TOKEN. The shipped reading and the minimal
# last-match-ANYWHERE one BOTH exit 1 on the offender — one on the entry's real bad field,
# the other on a junk token it extracted from the prose. Right verdict, wrong reason, and
# an arm reading only the exit code scores them identically.
#
# The near-miss is where they part: a GOOD field with prose below it. The shipped reading is
# quiet; last-anywhere reads the token `I` out of "It therefore" and emits a FALSE FINDING.
# That shape is the reference consumer's own pending.md, so this is the arm standing between
# the gate and a finding against a correctly-filed entry.
rc_tok "$PROSE_BELOW_OK"
if [ "$RC" -eq 0 ]; then
  ok "(d) THE DISCRIMINATING NEAR-MISS: a good field with prose below it is quiet"
else
  bad "(d) a correctly-filed entry with prose below its field was REPORTED (rc=$RC, token '${TOK:-none}') — a last-match-ANYWHERE reader is extracting a word out of the prose and failing the gate on it"
fi
rc_tok "$PROSE_BELOW"
if [ "$RC" -eq 1 ] && [ "$TOK" = "$BAD_TOK" ]; then
  ok "(d) prose **Status:** BELOW the field does not outrank it — and the token named is the FIELD's"
else
  bad "(d) the entry was judged on something other than its field (rc=$RC, token '${TOK:-none}', wanted '$BAD_TOK') — an exit 1 here is not evidence the field was read"
fi

# --- THE MUTANTS. Four properties, and no arm above proves ITSELF load-bearing ------
# Assertions 8-10 each have an offender and a near-miss, which establishes that the arm
# discriminates between two inputs — not that it discriminates at all. Only a mutant
# establishes the second, so every candidate reading of `**Status:**` that a later hand
# might take for a simplification is BUILT here and scored.
#
# Each mutant is keyed on ONE line of the awk record-builder and probed on ONE input, owned
# by ONE arm. The `cmp -s` guard turns a mutation that matched nothing into a loud BAD: an
# unmutated copy answers the baseline on every probe and scores a survival that reads
# exactly like a working arm.
#
# THE MUTATIONS ARE APPLIED BY AWK PROGRAMS, NOT BY `sed` SUBSTITUTIONS. The replacement
# text is awk source carrying `&` and backslashes, and an `&` in a sed replacement is the
# whole matched line — a mutation that silently re-inserts the line inside itself applies
# cleanly, passes `cmp -s`, and tests nothing.
MUTD="$WORK/mut"; mkdir -p "$MUTD"

# The CONTROL is presence-shaped and runs FIRST. A copy that cannot run at all reports
# nothing, and an arm reading only "the offender was not reported" would score that silence
# as a kill on every mutant below.
cp "$VALIDATOR" "$MUTD/control.sh"
rc_ctl_bad=0; rc_ctl_ok=0
bash "$MUTD/control.sh" "$PROSE_BELOW" "$SPEC_SRC" >/dev/null 2>&1; rc_ctl_bad=$?
bash "$MUTD/control.sh" "$PROSE_BELOW_OK" "$SPEC_SRC" >/dev/null 2>&1; rc_ctl_ok=$?
if [ "$rc_ctl_bad" -eq 1 ] && [ "$rc_ctl_ok" -eq 0 ]; then
  ok "mutant control: an unmutated copy REPORTS the offender and stays quiet on the near-miss"
else
  bad "mutant control: an unmutated copy answered offender=$rc_ctl_bad near-miss=$rc_ctl_ok — the mutants below would be scoring the harness, not the reader"
fi

# name | awk program | probe file | the exit the mutant must produce | the arm that owns it
MUT_NAMES="canon-guard-deleted line-anchored first-canonical-wins first-wins-outright"

mut_prog() {  # <name> -> writes the awk program for that mutant to stdout
  case "$1" in
    # (d): drop the guard entirely and the reader becomes LAST ANYWHERE.
    canon-guard-deleted) cat <<'AWKP'
/^[[:space:]]*if \(canon && / { hits++; next }
{ print }
AWKP
      ;;
    # (M): anchor the rule's own pattern to line start. This is the candidate that reads
    # most like a tightening, and assertion 4 is the only thing in the repo that refuses it.
    line-anchored) cat <<'AWKP'
$0 == "  /\\*\\*[Ss]tatus:\\*\\*/ {" { hits++; print "  /^\\*\\*[Ss]tatus:\\*\\*/ {"; next }
{ print }
AWKP
      ;;
    # (a): keep the field-vs-prose distinction but take the FIRST field.
    first-canonical-wins) cat <<'AWKP'
/^[[:space:]]*if \(canon && / { hits++; print "    if (canon) next"; next }
{ print }
AWKP
      ;;
    # (b): the state this change replaced — first occurrence anywhere wins.
    first-wins-outright) cat <<'AWKP'
/^[[:space:]]*if \(canon && / { hits++; print "    if (status != \"\") next"; next }
{ print }
AWKP
      ;;
  esac
}

mut_probe() {   # <name> -> the input this mutant is scored on
  case "$1" in
    canon-guard-deleted)  printf '%s' "$PROSE_BELOW_OK" ;;
    line-anchored)        printf '%s' "$MIDENTRY" ;;
    first-canonical-wins) printf '%s' "$APPENDED" ;;
    first-wins-outright)  printf '%s' "$PROSE_ABOVE_OK" ;;
  esac
}
mut_want() {    # <name> -> the exit code the MUTANT produces on that input
  case "$1" in
    canon-guard-deleted)  printf '1' ;;
    line-anchored)        printf '0' ;;
    first-canonical-wins) printf '0' ;;
    first-wins-outright)  printf '1' ;;
  esac
}
mut_why() {     # <name> -> which arm owns the kill, and what the mutant costs
  case "$1" in
    canon-guard-deleted)
      printf '%s' "(d)'s near-miss — last-match-ANYWHERE reads a word out of the prose and reports a correctly-filed entry" ;;
    line-anchored)
      printf '%s' "(M), assertion 4 — a mid-entry token goes unexamined, a coverage regression dressed as a tightening" ;;
    first-canonical-wins)
      printf '%s' "(a) — the appended resolution is ignored and the token it REPLACED is adjudicated" ;;
    first-wins-outright)
      printf '%s' "(b)'s near-miss — a prose mention above the field becomes the entry's status. (a) also moves under this mutant and stands down for (b): both are genuinely broken by first-wins, and (b) owns it because the near-miss is the cell no other mutant here reaches" ;;
  esac
}

for mname in $MUT_NAMES; do
  copy="$MUTD/$mname.sh"
  mut_prog "$mname" > "$MUTD/$mname.awk"
  awk -f "$MUTD/$mname.awk" "$VALIDATOR" > "$copy" 2>/dev/null
  if cmp -s "$VALIDATOR" "$copy"; then
    bad "MUTANT $mname — the anchor matched nothing, so no mutation applied and nothing was proven. The awk record-builder was reworded; re-anchor it on the line that spells the rule, never relax the assertion."
    continue
  fi
  probe="$(mut_probe "$mname")"
  want="$(mut_want "$mname")"
  bash "$copy" "$probe" "$SPEC_SRC" >/dev/null 2>&1; got=$?
  if [ "$got" -eq "$want" ]; then
    ok "MUTANT $mname killed by $(mut_why "$mname")"
  else
    bad "MUTANT $mname SURVIVED — $(basename "$probe") answered rc=$got, wanted rc=$want. The arm that should own this reading is not reading it."
  fi
done

# --- Assertions 11-15: an EMPTY file is the ABSENT state, and only an empty one -----
# A file that exists and holds no non-whitespace byte used to fall through to the parser and
# print `OK: n=[] no **Status:** entries found` -- the same line a POPULATED file whose entries
# carry no `**Status:**` field prints. The first is nothing to examine; the second is a
# grammar failure over live entries. Only the first may say EXAMINED NOTHING.
#
# FIVE CELLS, SCORED AS ONE STRING, so a mutant can be held to moving ONLY its own cell:
#   A empty                rc 0, the token, and the "present but empty" reason
#   B whitespace           the same -- a `[ -s ]` fix calls this file populated and fails here
#   C absent               rc 0, the token, the absent-file reason, NOT the empty one (unchanged)
#   D populated-zero-record  heading-only AND the bullet-entry shape: rc 0, the `n=[]` line,
#                          NO token. One cell, because no zero-record predicate can move one of
#                          the two without the other.
#   E finding              the drifted file: rc 1 (unchanged)
# Every cell is presence-shaped on at least one conjunct, so a subject that prints nothing
# fails every one of them.
VEN_CELLS=""
ven_cells() {  # <validator> -> sets VEN_CELLS
  local v="$1" o o2 rc rc2 c=""
  o="$(bash "$v" "$EMPTY" "$SPEC_SRC" 2>/dev/null)"; rc=$?
  if [ "$rc" -eq 0 ] && grep -qF "EXAMINED NOTHING" <<<"$o" && grep -qF "present but empty" <<<"$o"; then c="${c}1"; else c="${c}0"; fi
  o="$(bash "$v" "$BLANK" "$SPEC_SRC" 2>/dev/null)"; rc=$?
  if [ "$rc" -eq 0 ] && grep -qF "EXAMINED NOTHING" <<<"$o" && grep -qF "present but empty" <<<"$o"; then c="${c}1"; else c="${c}0"; fi
  o="$(bash "$v" "$WORK/pending-never-written.md" "$SPEC_SRC" 2>/dev/null)"; rc=$?
  if [ "$rc" -eq 0 ] && grep -qF "EXAMINED NOTHING" <<<"$o" && grep -qF "no escalations file" <<<"$o" \
     && ! grep -qF "present but empty" <<<"$o"; then c="${c}1"; else c="${c}0"; fi
  o="$(bash "$v" "$HEADING" "$SPEC_SRC" 2>/dev/null)"; rc=$?
  o2="$(bash "$v" "$UNPARSED" "$SPEC_SRC" 2>/dev/null)"; rc2=$?
  if [ "$rc" -eq 0 ] && [ "$rc2" -eq 0 ] && ! grep -qF "EXAMINED NOTHING" <<<"$o$o2" \
     && grep -qF "n=[]" <<<"$o" && grep -qF "n=[]" <<<"$o2"; then c="${c}1"; else c="${c}0"; fi
  o="$(bash "$v" "$DRIFT" "$SPEC_SRC" 2>&1)"; rc=$?
  if [ "$rc" -eq 1 ] && grep -qF "out-of-vocabulary status" <<<"$o"; then c="${c}1"; else c="${c}0"; fi
  VEN_CELLS="$c"
}
VEN_IS_DIST=0
case "$(cd "$(dirname "$VALIDATOR")" && pwd)" in */core/scripts) VEN_IS_DIST=1 ;; esac
ven_cells "$VALIDATOR"
# A SUBJECT THAT PREDATES THE FIX. This fixture ships and can reach a consumer one pull ahead of
# the validator: cells A and B read 0 and nothing else moves. SKIP there; FAIL here.
if [ "$(printf '%s' "$VEN_CELLS" | cut -c1-2)" = "00" ] && [ "$(printf '%s' "$VEN_CELLS" | cut -c3-5)" = "111" ] \
   && [ "$VEN_IS_DIST" -ne 1 ]; then
  printf '  SKIP  the empty-file arms -- the installed validator predates the empty-file verdict; this fixture ships one pull ahead of it\n'
else
  i=0
  for nm in "A empty file" "B whitespace-only file" "C absent file (unchanged)" \
            "D populated file parsing to zero records carries NO token" "E a real finding still exits 1"; do
    i=$((i + 1))
    if [ "$(printf '%s' "$VEN_CELLS" | cut -c"$i")" = "1" ]; then ok "empty-file cell $nm"
    else bad "empty-file cell $nm does not hold (cells=$VEN_CELLS)"; fi
  done

  # --- the mutants, each in a copy of the WHOLE scripts dir, with an unmutated control ------
  VEN_SRC_DIR="$(cd "$(dirname "$VALIDATOR")" && pwd)"
  VEN_BASE="$(basename "$VALIDATOR")"
  VEN_MW="$WORK/empty-mut"; mkdir -p "$VEN_MW"
  # ven_mk RUNS INSIDE `$( )`, so it cannot call `bad`: the failure count it bumped would die
  # with the subshell and a mutant that never built would score nothing at all. It writes its
  # reason to VEN_MW/<name>.why and prints no path; ven_score reads the empty path and fails.
  ven_mk() {  # <name> <literal anchor, exactly one line, or empty for the control> <replacement file>
    local d="$VEN_MW/$1" n
    cp -R "$VEN_SRC_DIR" "$d" || { echo "could not copy $VEN_SRC_DIR" > "$VEN_MW/$1.why"; return 1; }
    [ -n "$2" ] || { printf '%s\n' "$d/$VEN_BASE"; return 0; }
    n="$(grep -cF -- "$2" "$VALIDATOR")" || n=0
    [ "$n" -eq 1 ] || { echo "anchor matches $n line(s), not 1 -- re-anchor it, never relax the arm" > "$VEN_MW/$1.why"; return 1; }
    awk -v A="$2" -v R="$3" '
      index($0, A) { while ((getline l < R) > 0) print l; close(R); next }
      { print }' "$VALIDATOR" > "$d/$VEN_BASE"
    if cmp -s "$VALIDATOR" "$d/$VEN_BASE"; then echo "changed no bytes -- it would score as a kill" > "$VEN_MW/$1.why"; return 1; fi
    bash -n "$d/$VEN_BASE" 2>/dev/null || { echo "does not parse" > "$VEN_MW/$1.why"; return 1; }
    printf '%s\n' "$d/$VEN_BASE"
  }
  ven_score() {  # <name> <path-or-empty> <want> <why> <mk-name>
    if [ -z "$2" ]; then bad "$1 was never built: $(cat "$VEN_MW/$5.why" 2>/dev/null || echo 'no reason recorded')"; return 0; fi
    ven_cells "$2"
    if [ "$VEN_CELLS" = "$3" ]; then ok "$1 scored $VEN_CELLS -- $4"
    else bad "$1 scored $VEN_CELLS, wanted $3 -- $4"; fi
  }
  printf '%s\n' 'if false; then' > "$VEN_MW/r-revert"
  printf '%s\n' 'if [ -z "$RECORDS" ]; then echo "OK: EXAMINED NOTHING — zero parsed records ($ESCALATIONS)."; exit 0; fi' \
                'if [ -z "$RECORDS" ]; then' > "$VEN_MW/r-zero"
  VEN_CTL="$(ven_mk control "" "")" || VEN_CTL=""
  ven_score "MUTANT control (unmutated whole-dir copy)" "$VEN_CTL" 11111 "every cell holds, so a mutant's red cell is the mutation's" control
  VEN_M1="$(ven_mk revert 'if [ "$ESC_BLANK_RC" -eq 1 ]; then' "$VEN_MW/r-revert")" || VEN_M1=""
  ven_score "MUTANT M-revert" "$VEN_M1" 00111 "the fix removed: ONLY the empty and whitespace cells go red" revert
  VEN_M2="$(ven_mk zero-records 'if [ -z "$RECORDS" ]; then' "$VEN_MW/r-zero")" || VEN_M2=""
  ven_score "MUTANT M-zero-records" "$VEN_M2" 11101 "zero parsed records read as empty: ONLY the populated-zero-record cell goes red" zero-records
fi

echo
if [ "$fails" -eq 0 ]; then echo "escalation-status-vocabulary: PASS"; exit 0; fi
echo "escalation-status-vocabulary: $fails assertion(s) FAILED" >&2
exit 1
