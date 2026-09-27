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

# --- Assertions 16-18: at Checks 2 and 2a, `OK: EXAMINED NOTHING` IS a pass ----------------
# The escalations file exists only once something has been escalated, so its absence is
# exactly Check 2's predicate holding: no unresolved HARD_BLOCK. The three scripts have always
# said so. The enforcement map's postures for these two checks said the opposite -- "is not a
# pass, nothing was verified", the reading that is RIGHT at Checks 26/33/35, whose corpus must
# exist -- and the step text said nothing at all, so an adjudicator reading the map would fail
# every consumer that has never escalated.
#
# THREE CELLS, one per artifact an adjudicator reads, each scored over a FLATTENED section so a
# re-wrap of the prose cannot move a cell:
#   A gate-validation.md Check 2 section: states the absent/empty PASS, names the printed line,
#     and carries no "is not a pass"
#   B gate-validation.md Check 2a section: the same
#   C enforcement-map.yaml rows 2 and 2a: exactly three postures say IS a pass, none says
#     "is not a pass"
# Every cell is presence-shaped on its first conjunct, so an unreadable or missing file fails
# it rather than acquitting it.
EN_DIR="$(cd "$(dirname "$SPEC_SRC")" && pwd)"
EN_GV="$EN_DIR/steps/gate-validation.md"
EN_MAP="$EN_DIR/enforcement-map.yaml"
EN_PASS='IS a pass, because no escalation exists to be unresolved'
EN_CELLS=""
en_flat() {  # <file> <start-regex> <end-regex> -> the lines from start up to (not incl.) end, on one line
  awk -v s="$2" -v e="$3" '$0 ~ s { on = 1; print; next } on && $0 ~ e { exit } on { print }' "$1" 2>/dev/null \
    | tr '\n' ' ' | tr -s ' '
}
en_step_cell() {  # <flattened section> -> 1 or 0
  if grep -qF "An absent or empty \`pending.md\` is a PASS." <<<"$1" && grep -qF "$EN_PASS" <<<"$1" \
     && grep -qF 'OK: EXAMINED NOTHING' <<<"$1" && ! grep -qF 'is not a pass' <<<"$1"; then echo 1; else echo 0; fi
}
en_cells() {  # <gate-validation.md> <enforcement-map.yaml> -> sets EN_CELLS
  local s2 s2a m n
  s2="$(en_flat "$1" '^### 2\. ' '^### 2a\. ')"
  s2a="$(en_flat "$1" '^### 2a\. ' '^### 3\. ')"
  m="$(en_flat "$2" '^  - id: "2"$' '^  - id: "3"$')"
  n="$(grep -oF "$EN_PASS" <<<"$m" | grep -c .)" || n=0
  EN_CELLS="$(en_step_cell "$s2")$(en_step_cell "$s2a")"
  if [ "$n" -eq 3 ] && ! grep -qF 'is not a pass' <<<"$m"; then EN_CELLS="${EN_CELLS}1"; else EN_CELLS="${EN_CELLS}0"; fi
}
if [ ! -f "$EN_GV" ] || [ ! -f "$EN_MAP" ]; then
  bad "Checks 2/2a posture arms cannot run: gate-validation.md or enforcement-map.yaml is not beside $SPEC_SRC"
else
  en_cells "$EN_GV" "$EN_MAP"
fi
# A TREE THAT PREDATES THE RULING. This fixture ships, and a consumer can run it against step
# and map files installed before the ruling: all three cells read 0. SKIP there; FAIL here.
if [ -f "$EN_GV" ] && [ -f "$EN_MAP" ] && [ "$EN_CELLS" = "000" ] && [ "$VEN_IS_DIST" -ne 1 ]; then
  printf '  SKIP  the Checks 2/2a posture arms -- the installed step and map files predate the absent-file-is-a-pass reading\n'
elif [ -f "$EN_GV" ] && [ -f "$EN_MAP" ]; then
  i=0
  for nm in "A Check 2's step text states an absent or empty pending.md is a PASS" \
            "B Check 2a's step text states an absent or empty pending.md is a PASS" \
            "C the map's three Check 2/2a postures say OK: EXAMINED NOTHING IS a pass"; do
    i=$((i + 1))
    if [ "$(printf '%s' "$EN_CELLS" | cut -c"$i")" = "1" ]; then ok "posture cell $nm"
    else bad "posture cell $nm does not hold (cells=$EN_CELLS)"; fi
  done

  # --- the mutants restore the old reading, each in ONE artifact, in copies ----------------
  EN_MW="$WORK/posture-mut"; mkdir -p "$EN_MW"
  en_mut() {  # <name> <file> <literal-anchor> <replacement> -> prints the copy, or nothing
    local n
    n="$(grep -cF -- "$3" "$2")" || n=0
    [ "$n" -ge 1 ] || { echo "anchor matches 0 line(s) of $(basename "$2")" > "$EN_MW/$1.why"; return 1; }
    awk -v A="$3" -v R="$4" '{ i = index($0, A); if (i) $0 = substr($0, 1, i - 1) R substr($0, i + length(A)); print }' \
      "$2" > "$EN_MW/$1"
    if cmp -s "$2" "$EN_MW/$1"; then echo "changed no bytes" > "$EN_MW/$1.why"; return 1; fi
    printf '%s\n' "$EN_MW/$1"
  }
  en_score() {  # <label> <gv> <map> <want> <why> <mk-name>
    if [ -z "$2" ] || [ -z "$3" ]; then bad "$1 was never built: $(cat "$EN_MW/$6.why" 2>/dev/null || echo 'no reason recorded')"; return 0; fi
    en_cells "$2" "$3"
    if [ "$EN_CELLS" = "$4" ]; then ok "$1 scored $EN_CELLS -- $5"
    else bad "$1 scored $EN_CELLS, wanted $4 -- $5"; fi
  }
  # The step-text sentence is wrapped identically in both sections, so the anchor is each
  # section's OWN lead-in, which differs: Check 2's is a bullet, Check 2a's is a paragraph.
  EN_M1="$(en_mut gv-2 "$EN_GV" '- **An absent or empty `pending.md` is a PASS.** Both scripts' \
    '- **An absent or empty `pending.md` is not a pass, nothing was verified.** Both scripts')" || EN_M1=""
  en_score "MUTANT M-step-2 (Check 2 restores 'is not a pass')" "$EN_M1" "$EN_MAP" 011 "ONLY Check 2's step cell goes red" gv-2
  EN_M2="$(en_mut gv-2a "$EN_GV" '**An absent or empty `pending.md` is a PASS.** The script' \
    '**An absent or empty `pending.md` is not a pass, nothing was verified.** The script')" || EN_M2=""
  en_score "MUTANT M-step-2a (Check 2a restores 'is not a pass')" "$EN_M2" "$EN_MAP" 101 "ONLY Check 2a's step cell goes red" gv-2a
  EN_M3="$(en_mut map "$EN_MAP" 'with entries_scanned=0 when no escalations file exists or it holds nothing — IS a pass,' \
    'with entries_scanned=0 when no escalations file exists or it holds nothing — is not a pass, nothing was verified,')" || EN_M3=""
  en_score "MUTANT M-map (one Check 2 posture restores 'is not a pass')" "$EN_GV" "$EN_M3" 110 "ONLY the map cell goes red" map
fi

# fx_sub <src> <out> <anchor> <replacement> [<anchor> <replacement>]... -- a COPY of <src> with each
# anchor, which must sit on EXACTLY ONE line, replaced as a literal substring. Sets FX_WHY and returns
# 1 when an anchor matches 0 or 2+ lines or the copy is byte-identical. The strings reach awk through
# ENVIRON, never `-v`, because `-v` strips one level of backslash escaping.
FX_WHY=""
fx_sub() {
  local src="$1" out="$2" n
  shift 2
  cp "$src" "$out.work" || { FX_WHY="could not copy $src"; return 1; }
  while [ "$#" -ge 2 ]; do
    n="$(grep -cF -- "$1" "$out.work")" || n=0
    [ "$n" -eq 1 ] || { FX_WHY="anchor matches $n line(s), not 1 -- re-anchor it, never relax the arm: $1"; return 1; }
    A="$1" R="$2" awk '{ i = index($0, ENVIRON["A"]); if (i) $0 = substr($0, 1, i - 1) ENVIRON["R"] substr($0, i + length(ENVIRON["A"])); print }' \
      "$out.work" > "$out.next" || { FX_WHY="awk died applying: $1"; return 1; }
    mv "$out.next" "$out.work"
    shift 2
  done
  if cmp -s "$src" "$out.work"; then FX_WHY="changed no bytes -- it would score as a kill"; return 1; fi
  mv "$out.work" "$out"
}

# --- Assertions 19-24: an UNREADABLE or NON-REGULAR escalations path REFUSES, exit 2 ---------------
# `grep -q '[^[:space:]]'` exits 2 on a file it cannot read, and the validator used to branch on
# `-eq 1` alone: a status of 2 fell through, the parser's own read failure was swallowed, and the run
# printed an ordinary `OK: n=[]` line over entries nobody read. A DIRECTORY at the path failed `-f`
# and printed "no escalations file" -- the line Check 2 reads as a pass. Now both refuse: `REFUSED:`
# on stderr, exit 2, nothing on stdout.
#
# SIX CELLS, ONE STRING, so each mutant below is held to moving only the cells its layer owns:
#   A  mode-000 file carrying an out-of-vocabulary entry -> exit 2, `could not be read`
#   B  a DIRECTORY at the path                         -> exit 2, `is not a regular file`
#   C  a DANGLING SYMLINK at the path (fails -e AND -f) -> exit 2, `is not a regular file`
#   D  a READABLE file whose blank probe grep exits 2 (PATH stub; the stub must FIRE)
#                                                      -> exit 2, `failed (grep exited 2)`
#   E  near-miss: a whitespace-only readable file      -> exit 0, the existing "present but empty" line
#   F  near-miss: a readable file with a finding       -> exit 1, unchanged
# A through D are presence-shaped (a REFUSED line must appear), so a subject that prints nothing
# fails them. Cell A is `S` when mode 000 does not stop this process reading -- root does, and the
# guard deliberately does not refuse on the mode bit alone.
VR="$WORK/refusal"; mkdir -p "$VR"
VR_LOCKED="$VR/pending-locked.md"; cp "$DRIFT" "$VR_LOCKED"; chmod 000 "$VR_LOCKED"
VR_DIR="$VR/pending-dir.md"; mkdir -p "$VR_DIR"
VR_LINK="$VR/pending-dangling.md"; ln -s "$VR/pending-target-never-written.md" "$VR_LINK"
VR_IO="$VR/pending-io.md"; cp "$DRIFT" "$VR_IO"
VR_SKIP_A=""
if [ "$(id -u)" -eq 0 ]; then VR_SKIP_A="running as root, which reads a mode-000 file"
elif cat "$VR_LOCKED" >/dev/null 2>&1; then VR_SKIP_A="this host reads a mode-000 file, so the seed cannot express unreadable"; fi
[ -n "$VR_SKIP_A" ] && printf '  SKIP  refusal cell A (mode-000 file) -- %s\n' "$VR_SKIP_A"
if ! { [ -L "$VR_LINK" ] && [ ! -e "$VR_LINK" ]; }; then bad "FIXTURE BROKEN: the dangling-symlink seed is not a link to a missing target"; fi
# THE STUB claims only the blank probe's argv (`-q [^[:space:]] <file>`), logs each claimed call and
# execs the real grep for everything else.
VR_STUB="$VR/stub"; mkdir -p "$VR_STUB"
VR_REALGREP="$(command -v grep)" || { echo "FIXTURE ERROR: grep is not on PATH" >&2; exit 2; }
{
  printf '#!/bin/sh\ncase "$*" in\n'
  printf '  %s) printf "x\\n" >> "%s/LOG"; echo "grep: forced failure" >&2; exit 2 ;;\n' "'-q [^[:space:]] '*" "$VR_STUB"
  printf 'esac\nexec "%s" "$@"\n' "$VR_REALGREP"
} > "$VR_STUB/grep"
chmod +x "$VR_STUB/grep"
VR_RC=0; VR_O=""; VR_E=""
vr_run() {  # <validator> <file> [stub-dir] -> VR_RC VR_O VR_E
  local p="$PATH"
  [ -n "${3:-}" ] && p="$3:$PATH"
  : > "$VR_STUB/LOG"
  VR_O="$(PATH="$p" bash "$1" "$2" "$SPEC_SRC" 2>"$VR/err")"; VR_RC=$?
  VR_E="$(cat "$VR/err")"
}
vr_refused() {  # <reason-ERE> -> the last run refused, for that reason, with stdout empty
  [ "$VR_RC" -eq 2 ] && [ -z "$VR_O" ] && grep -qE "^REFUSED: .*$1" <<<"$VR_E"
}
VR_CELLS=""
vr_cells() {  # <validator> -> VR_CELLS
  local v="$1" c=""
  if [ -n "$VR_SKIP_A" ]; then c="${c}S"
  else vr_run "$v" "$VR_LOCKED"; if vr_refused 'could not be read'; then c="${c}1"; else c="${c}0"; fi; fi
  vr_run "$v" "$VR_DIR";  if vr_refused 'is not a regular file'; then c="${c}1"; else c="${c}0"; fi
  vr_run "$v" "$VR_LINK"; if vr_refused 'is not a regular file'; then c="${c}1"; else c="${c}0"; fi
  vr_run "$v" "$VR_IO" "$VR_STUB"
  if [ -s "$VR_STUB/LOG" ] && vr_refused 'failed \(grep exited 2\)'; then c="${c}1"; else c="${c}0"; fi
  vr_run "$v" "$BLANK"
  if [ "$VR_RC" -eq 0 ] && grep -qF 'present but empty' <<<"$VR_O" && ! grep -qF 'REFUSED' <<<"$VR_O$VR_E"; then c="${c}1"; else c="${c}0"; fi
  vr_run "$v" "$DRIFT"
  if [ "$VR_RC" -eq 1 ] && grep -qF 'out-of-vocabulary status' <<<"$VR_O$VR_E" && ! grep -qF 'REFUSED' <<<"$VR_O$VR_E"; then c="${c}1"; else c="${c}0"; fi
  VR_CELLS="$c"
}
vr_want() { if [ -n "$VR_SKIP_A" ]; then printf 'S%s' "${1#?}"; else printf '%s' "$1"; fi; }
vr_cells "$VALIDATOR"
# A SUBJECT THAT PREDATES THE REFUSAL. This fixture ships one pull ahead of the validator: there B, C
# and D read 0 and E, F still hold. SKIP there; FAIL here.
if [ "$(printf '%s' "$VR_CELLS" | cut -c2-4)" = "000" ] && [ "$(printf '%s' "$VR_CELLS" | cut -c5-6)" = "11" ] \
   && [ "$VEN_IS_DIST" -ne 1 ]; then
  printf '  SKIP  the refusal arms -- the installed validator predates the unreadable-file refusal; this fixture ships one pull ahead of it\n'
else
  i=0
  for nm in "A mode-000 file refuses: exit 2, REFUSED could not be read, stdout empty" \
            "B a directory at the path refuses: exit 2, REFUSED is not a regular file" \
            "C a dangling symlink at the path refuses: exit 2, REFUSED is not a regular file" \
            "D a readable file whose blank probe exits 2 refuses: exit 2, REFUSED grep exited 2 (stub fired)" \
            "E near-miss: a whitespace-only readable file is still OK EXAMINED NOTHING, exit 0" \
            "F near-miss: a readable file with a finding still exits 1"; do
    i=$((i + 1))
    case "$(printf '%s' "$VR_CELLS" | cut -c"$i")" in
      1) ok "refusal cell $nm" ;;
      S) ;;
      *) bad "refusal cell $nm does not hold (cells=$VR_CELLS)" ;;
    esac
  done

  # --- the mutants: one per layer of the guard, plus one reverting EVERY layer ---------------------
  # Siblings in ONE copy of the whole scripts directory; the unmutated control is a sibling too, so a
  # copy that cannot run fails the control's presence cells rather than scoring as a kill.
  VR_MD="$VR/mut"
  cp -R "$(cd "$(dirname "$VALIDATOR")" && pwd)" "$VR_MD" || bad "refusal mutants: could not copy the scripts directory"
  VR_SRC="$VR_MD/$(basename "$VALIDATOR")"
  VR_G1='if { [ -e "$ESCALATIONS" ] || [ -L "$ESCALATIONS" ]; } && [ ! -f "$ESCALATIONS" ]; then'
  VR_G1L='{ [ -e "$ESCALATIONS" ] || [ -L "$ESCALATIONS" ]; }'
  VR_G2='if [ "$ESC_BLANK_RC" -gt 1 ]; then'
  VR_G3='if [ ! -r "$ESCALATIONS" ]; then'
  vr_score() {  # <label> <name> <want> <why> <anchor> <replacement> [...]
    local label="$1" name="$2" want out
    want="$(vr_want "$3")"
    shift 4
    out="$VR_MD/_vr_$name.sh"
    if [ "$#" -eq 0 ]; then cp "$VR_SRC" "$out"
    elif ! fx_sub "$VR_SRC" "$out" "$@"; then bad "$label DID NOT APPLY: $FX_WHY"; return 0
    elif ! bash -n "$out" 2>/dev/null; then bad "$label DID NOT APPLY: the mutated copy does not parse"; return 0; fi
    vr_cells "$out"
    if [ "$VR_CELLS" = "$want" ]; then ok "$label scored $VR_CELLS"
    else bad "$label scored $VR_CELLS, wanted $want"; fi
  }
  vr_score "MUTANT refusal-control (unmutated sibling copy): every cell holds" ctl 111111 ""
  vr_score "MUTANT R-revert-all (every layer removed, grep status 2 falls through): A-D red, E and F hold" \
    revert-all 000011 "" "$VR_G1" 'if false; then' "$VR_G2" 'if false; then'
  vr_score "MUTANT R-nonregular (the -e/-L guard removed): ONLY the directory and symlink cells go red" \
    nonregular 100111 "" "$VR_G1" 'if false; then'
  vr_score "MUTANT R-no-symlink (-L dropped beside -e): ONLY the dangling-symlink cell goes red" \
    no-symlink 110111 "" "$VR_G1L" '[ -e "$ESCALATIONS" ]'
  vr_score "MUTANT R-rc (the status > 1 guard removed): the mode-000 and I/O cells go red" \
    rc 011011 "" "$VR_G2" 'if false; then'
  vr_score "MUTANT R-readable-never (the -r test never true): ONLY the mode-000 cell's reason goes red" \
    readable-never 011111 "" "$VR_G3" 'if false; then'
  vr_score "MUTANT R-readable-always (the -r test always true): ONLY the I/O cell's reason goes red" \
    readable-always 111011 "" "$VR_G3" 'if true; then'
fi

# --- Assertions 25-31: the Check 2/2a text says an unreadable pending.md REFUSES, never "FAIL" -------
# The existing posture cells FAIL on the literal `is not a pass` in those sections and count three
# `IS a pass` phrases in the map. Neither sees a sentence that appends "treat that line as a FAIL" to
# the pass ruling, which re-inverts it for an adjudicator, nor the refusal clause being dropped. And
# Checks 26/33/35, whose corpus MUST exist, still carry the opposite reading.
#   A  map, Check 2/2a postures: exactly 3 carry the refusal clause
#   B  step text, Check 2: the refusal sentence and its `REFUSED:` / never-a-pass tail
#   C  step text, Check 2a: the same
#   D2, D2a, Dm  no sentence containing "treat that line as a FAIL" (any case) in step 2, step 2a, map 2/2a
#   E  map rows 26, 33, 35: "is not a pass, nothing was verified" once in each, 3 in total
RP_MAP='unreadable or non-regular `pending.md` is a REFUSAL, exit 2 with `REFUSED:` on stderr, never a pass'
RP_STEP='An unreadable or non-regular `pending.md` is a REFUSAL:'
RP_TAIL='with `REFUSED:` on stderr, and that is never a pass.'
RP_FAIL='treat that line as a fail'
RP_NOTPASS='is not a pass, nothing was verified'
RP_CELLS=""
rp_count() { local n; n="$(grep -oF -- "$1" <<<"$2" | grep -c .)" || n=0; printf '%s' "$n"; }
rp_has_fail() { local lc; lc="$(tr '[:upper:]' '[:lower:]' <<<"$1")"; grep -qF -- "$RP_FAIL" <<<"$lc"; }
rp_cells() {  # <gate-validation.md> <enforcement-map.yaml> -> RP_CELLS
  local s2 s2a m m26 m33 m35 c="" n26 n33 n35
  s2="$(en_flat "$1" '^### 2\. ' '^### 2a\. ')"
  s2a="$(en_flat "$1" '^### 2a\. ' '^### 3\. ')"
  m="$(en_flat "$2" '^  - id: "2"$' '^  - id: "3"$')"
  m26="$(en_flat "$2" '^  - id: "26"$' '^  - id: "')"
  m33="$(en_flat "$2" '^  - id: "33"$' '^  - id: "')"
  m35="$(en_flat "$2" '^  - id: "35"$' '^  - id: "')"
  if [ "$(rp_count "$RP_MAP" "$m")" -eq 3 ]; then c="${c}1"; else c="${c}0"; fi
  if grep -qF -- "$RP_STEP" <<<"$s2" && grep -qF -- "$RP_TAIL" <<<"$s2"; then c="${c}1"; else c="${c}0"; fi
  if grep -qF -- "$RP_STEP" <<<"$s2a" && grep -qF -- "$RP_TAIL" <<<"$s2a"; then c="${c}1"; else c="${c}0"; fi
  if [ -n "$s2" ] && ! rp_has_fail "$s2"; then c="${c}1"; else c="${c}0"; fi
  if [ -n "$s2a" ] && ! rp_has_fail "$s2a"; then c="${c}1"; else c="${c}0"; fi
  if [ -n "$m" ] && ! rp_has_fail "$m"; then c="${c}1"; else c="${c}0"; fi
  n26="$(rp_count "$RP_NOTPASS" "$m26")"; n33="$(rp_count "$RP_NOTPASS" "$m33")"; n35="$(rp_count "$RP_NOTPASS" "$m35")"
  if [ "$n26" -ge 1 ] && [ "$n33" -ge 1 ] && [ "$n35" -ge 1 ] && [ $((n26 + n33 + n35)) -eq 3 ]; then c="${c}1"; else c="${c}0"; fi
  RP_CELLS="$c"
}
# SELF-PROBE FIRST, on synthesized files, both directions: a conforming pair scores every cell, the
# same pair with "Treat that line as a FAIL." appended to step 2 moves ONLY D2, and a near-miss
# ("Treat that line as a PASS.") stays quiet.
RPP="$WORK/rp-probe"; mkdir -p "$RPP"
rpp_gv() {  # <extra sentence for step 2> -> a synthesized gate-validation.md on stdout
  printf '### 2. No unresolved HARD_BLOCKs?\n\nAbsent is a PASS. %s\n  REFUSAL: both scripts exit 2 %s%s\n\n' "$RP_STEP" "$RP_TAIL" "$1"
  printf '### 2a. Citation?\n\n%s\nREFUSAL: the script exits 2 %s\n\n### 3. Next.\n' "$RP_STEP" "$RP_TAIL"
}
{
  printf 'checks:\n  - id: "2"\n'
  for _p in a b c; do printf '    posture: IS a pass; an %s)\n' "$RP_MAP"; done
  printf '  - id: "3"\n'
  for _id in 26 33 35; do printf '  - id: "%s"\n    posture: %s\n' "$_id" "$RP_NOTPASS"; done
  printf '  - id: "36"\n'
} > "$RPP/map.yaml"
rpp_gv "" > "$RPP/gv-ok.md"
rpp_gv " Treat that line as a FAIL." > "$RPP/gv-fail.md"
rpp_gv " Treat that line as a PASS." > "$RPP/gv-near.md"
rp_cells "$RPP/gv-ok.md" "$RPP/map.yaml"; RPP_OK="$RP_CELLS"
rp_cells "$RPP/gv-fail.md" "$RPP/map.yaml"; RPP_FAIL="$RP_CELLS"
rp_cells "$RPP/gv-near.md" "$RPP/map.yaml"; RPP_NEAR="$RP_CELLS"
if [ "$RPP_OK" = 1111111 ] && [ "$RPP_FAIL" = 1110111 ] && [ "$RPP_NEAR" = 1111111 ]; then
  ok "refusal-prose self-probe: a conforming pair scores 1111111, the FAIL sentence moves ONLY D2, the near-miss is quiet"
else
  bad "refusal-prose self-probe read ok=$RPP_OK fail=$RPP_FAIL near=$RPP_NEAR, wanted 1111111/1110111/1111111 -- the cells cannot be trusted on the real files"
fi
if [ ! -f "$EN_GV" ] || [ ! -f "$EN_MAP" ]; then
  bad "refusal-prose arms cannot run: gate-validation.md or enforcement-map.yaml is not beside $SPEC_SRC"
else
  rp_cells "$EN_GV" "$EN_MAP"
  # A TREE THAT PREDATES THE REFUSAL SENTENCE: A, B and C all read 0 there. SKIP on a consumer only.
  if [ "$(printf '%s' "$RP_CELLS" | cut -c1-3)" = "000" ] && [ "$VEN_IS_DIST" -ne 1 ]; then
    printf '  SKIP  the refusal-prose arms -- the installed step and map files predate the unreadable-file refusal\n'
  else
    i=0
    for nm in "A the map's three Check 2/2a postures carry the refusal clause" \
              "B Check 2's step text carries the refusal sentence" \
              "C Check 2a's step text carries the refusal sentence" \
              "D2 Check 2's step text has no 'treat that line as a FAIL'" \
              "D2a Check 2a's step text has no 'treat that line as a FAIL'" \
              "Dm the map's Check 2/2a rows have no 'treat that line as a FAIL'" \
              "E Checks 26, 33 and 35 still say 'is not a pass, nothing was verified', once each"; do
      i=$((i + 1))
      if [ "$(printf '%s' "$RP_CELLS" | cut -c"$i")" = "1" ]; then ok "refusal-prose cell $nm"
      else bad "refusal-prose cell $nm does not hold (cells=$RP_CELLS)"; fi
    done
    RP_MW="$WORK/rp-mut"; mkdir -p "$RP_MW"
    rp_score() {  # <label> <which: gv|map> <name> <want-rp> <want-en> <anchor> <replacement>
      local label="$1" which="$2" out gv="$EN_GV" map="$EN_MAP" wrp="$4" wen="$5"
      out="$RP_MW/$3"
      shift 5
      if [ "$which" = gv ]; then fx_sub "$EN_GV" "$out" "$@" && gv="$out"; else fx_sub "$EN_MAP" "$out" "$@" && map="$out"; fi
      if [ ! -f "$out" ]; then bad "$label DID NOT APPLY: $FX_WHY"; return 0; fi
      rp_cells "$gv" "$map"; en_cells "$gv" "$map"
      if [ "$RP_CELLS" = "$wrp" ] && [ "$EN_CELLS" = "$wen" ]; then ok "$label scored refusal=$RP_CELLS posture=$EN_CELLS"
      else bad "$label scored refusal=$RP_CELLS posture=$EN_CELLS, wanted $wrp/$wen"; fi
    }
    # THE BL-353 GAP: the old posture cells stay 111 under this mutant, and only the new D2 cell sees it.
    rp_score "MUTANT RP-fail-sentence (step 2 appends 'Treat that line as a FAIL.'): ONLY D2 goes red; the old posture cells cannot see it" \
      gv fail-sentence 1110111 111 \
      'both scripts exit 2 with `REFUSED:` on stderr, and that is never a pass.' \
      'both scripts exit 2 with `REFUSED:` on stderr, and that is never a pass. Treat that line as a FAIL.'
    rp_score "MUTANT RP-map-clause (one Check 2 posture drops the refusal clause): ONLY A goes red" \
      map map-clause 0111111 111 \
      'because no escalation exists to be unresolved; an unreadable or non-regular' \
      'because no escalation exists to be unresolved; a missing'
    rp_score "MUTANT RP-step-2a-tail (Check 2a drops the REFUSED: tail): ONLY C goes red" \
      gv step2a-tail 1101111 111 \
      'REFUSAL: the script exits 2 with `REFUSED:` on stderr' 'REFUSAL: the script exits 2 on stderr'
    rp_score "MUTANT RP-check-26 (Check 26 turns 'is not a pass' into a pass): ONLY E goes red" \
      map check-26 1111110 111 \
      'is not a pass, nothing was verified — no verdict carried a gate_series_id' 'is a pass — no verdict carried a gate_series_id'
  fi
fi

echo
if [ "$fails" -eq 0 ]; then echo "escalation-status-vocabulary: PASS"; exit 0; fi
echo "escalation-status-vocabulary: $fails assertion(s) FAILED" >&2
exit 1
