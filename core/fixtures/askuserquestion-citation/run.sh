#!/usr/bin/env bash
# askuserquestion-citation/run.sh — prove --cite accepts an AskUserQuestion answer, that it
# accepts ONLY the answer, and that Check B was not widened along with it.
#
# THE DEFECT. genuineOperatorText returns "" for any user record carrying a tool_result. An
# AskUserQuestion answer IS that shape, so --cite structurally could not accept any
# AskUserQuestion-sourced operator decision — a closed class, not one bad citation. Rule 11(a)
# names AskUserQuestion as the sanctioned mechanism for exactly this decision, so citing a
# genuine, deliberate, timestamped operator selection failed with the identical message the
# S290 FABRICATION case produced. The mirror image of the failure Check 2a exists to catch.
#
# THE HAZARD THE FIX MUST NOT CREATE. The tool_result text carries the QUESTIONS as well as
# the answers, and the questions are text the LEAD authored. A fix that accepted the whole
# string would let a lead cite its own words and pass the provenance check — reintroducing
# S290 through the repair of its mirror image. Assertion 2 is the one that guards that.
#
# Arm names are A1-A5 (assertions 1-5), P1-P6 (the pruned-world arms), F1-F17 (the --accept-captured worlds) and D1-D8 (the
# disposition-shaped quotes, BL-950).
# G1 holds the four --cite callers to never passing --accept-captured. Its population is the
# declared caller set (G1_CALLERS, mirrored in inputs.decl); RESIDUAL: a new caller outside that
# set is not covered until it is declared. The completeness half runs only on a git-readable
# distribution tree, never inside the hermetic sandbox.
#
# Usage: run.sh
set -uo pipefail
# Clear every inherited AI_DLC_* tunable and CLAUDE_PROJECT_DIR so a bare run judges the code, not the caller environment.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset CLAUDE_PROJECT_DIR

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"
# The REQUIRED input of inputs.decl: every assertion below drives this file, and seed.sh has
# already copied it into the seeded tree, so this is the point the declaration is consumed.
echo "HERMETIC-CONSUMED $VALIDATOR"

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }
# Capture, never pipe. --cite exits 2 on NOMATCH, and under `set -o pipefail` a
# `cite ... | grep -q NOMATCH` pipeline inherits that 2 even when grep matched — so every
# assertion expecting NOMATCH would take its else branch and report a failure that did not
# happen. Caught by this fixture on its first run.
cite() { bash "$VALIDATOR" --transcript "$1" --cite "$2" 2>/dev/null || true; }

echo "askuserquestion-citation:"

# --- Assertion 1: THE FIX — an AskUserQuestion ANSWER is citable --------------
R="$(cite "$ASK" "$ANSWER")"
case "$R" in
  MATCH*) ok "an AskUserQuestion answer cites as a genuine operator message" ;;
  *)      bad "the operator's AskUserQuestion answer still cannot be cited ($R) — Check 2a rejects the pipeline's own sanctioned mechanism" ;;
esac

# --- Assertion 2: THE HAZARD — the LEAD-AUTHORED QUESTION is NOT citable ------
# Same record, same string. If this matches, a lead can author a question, have the operator
# pick any option at all, and then cite its own question text as operator authorization.
R="$(cite "$ASK" "$QUESTION")"
case "$R" in
  NOMATCH*) ok "the lead-authored QUESTION in the same tool_result is NOT citable — only the answer side is read" ;;
  *)        bad "FABRICATION VECTOR OPEN ($R): the lead's own question text cited as operator authorization. This is S290 reintroduced through the fix for its mirror image." ;;
esac

# --- Assertion 3: a non-AskUserQuestion tool_result stays rejected -------------
# Its bytes are an answer block verbatim. Only the PAIRED tool_use distinguishes it.
R="$(cite "$OTHER" "$ANSWER")"
case "$R" in
  NOMATCH*) ok "an identical string in a Bash tool_result is rejected — the pairing decides, not the bytes" ;;
  *)        bad "any tool_result that LOOKS like an answer block is now citable ($R) — the predicate is sniffing text instead of resolving the tool_use" ;;
esac

# --- Assertion 4: REGRESSION — a freely-typed message still cites --------------
R="$(cite "$TYPED" "$ANSWER")"
case "$R" in
  MATCH*) ok "a freely-typed operator message still cites (the original path is intact)" ;;
  *)      bad "the split broke plain typed-message citation ($R) — the regression this change must not cause" ;;
esac

# --- Assertion 5: Check B was NOT widened -------------------------------------
# The lead SOLICITED the answer, then advanced. No pause flag is set, because a tool result is
# not a UserPromptSubmit, and no acknowledgement is owed. If AskUserQuestion answers entered
# Check B, every checkpoint in every sprint would score as a steamroll.
COUNT="$(bash "$VALIDATOR" --transcript "$ASK" --count 2>/dev/null)"
if [ "$COUNT" = "0" ]; then
  ok "Check B counts 0 on AskUserQuestion -> advance (the predicate was split, not widened)"
else
  bad "Check B counted $COUNT on an AskUserQuestion the lead itself solicited — every operator checkpoint now reads as a steamroll"
fi

# --- The pruned-session world: NOMATCH-TRANSCRIPT-PRUNED ------------------------
# An answer the capture hook logged, whose transcript Claude Code has since deleted, used to
# read NOMATCH -- the verdict a fabricated authorization gets. It now reads its own token, with
# exit 2 unchanged so no reader is acquitted by it. Every arm asserts the stdout VALUE and the
# exit.
# pc <validator> <cwd> <quote> [extra args] -> "<rc> <stdout>"; the root comes from the caller.
pc() { local v="$1" d="$2" q="$3"; shift 3; local o r
  o="$(cd "$d" && bash "$v" --dir "$CORPUS" --cite "$q" "$@" 2>/dev/null)"; r=$?
  printf '%s %s' "$r" "$o"; }
# The fixture's copy of the validator sits inside the distribution, so its own-install walk
# resolves the REPO; the root is handed over explicitly. Arm P6 covers the walk.
pr() { local v="$1"; shift; AI_DLC_PROJECT_ROOT="$PROJ" pc "$v" "$PROJ" "$@"; }
p_arms() { # p_arms <validator> [letters] -> one letter per arm asked for (default ABCDE), upper case = holds
  local v="$1" sel="${2:-ABCDE}" s=""
  case "$sel" in *A*) [ "$(pr "$v" "$Q_PRUNED")" = "2 NOMATCH-TRANSCRIPT-PRUNED" ] && s="${s}A" || s="${s}a" ;; esac
  case "$sel" in *B*) [ "$(pr "$v" "$Q_LIVE")" = "2 NOMATCH" ] && s="${s}B" || s="${s}b" ;; esac
  case "$sel" in *C*) [ "$(pr "$v" "$Q_OLD" --since 2010-01-01T00:00:00Z)" = "2 NOMATCH" ] && s="${s}C" || s="${s}c" ;; esac
  case "$sel" in *D*) [ "$(pr "$v" "$Q_ASKED")" = "2 NOMATCH" ] && s="${s}D" || s="${s}d" ;; esac
  case "$sel" in *E*) [ "$(pr "$v" "a phrase nobody logged or typed")" = "2 NOMATCH" ] && s="${s}E" || s="${s}e" ;; esac
  printf '%s' "$s"
}
# P6 runs the INSTALLED copy from a subdirectory with no root in the environment, so only the
# walk from the script's own location can find the log.
p_installed() { local v="$1"
  [ "$(env -u AI_DLC_PROJECT_ROOT -u CLAUDE_PROJECT_DIR bash -c 'o="$(cd "$1" && bash "$2" --dir "$3" --cite "$4" 2>/dev/null)"; printf "%s %s" "$?" "$o"' _ "$PROJ/sub" "$v" "$CORPUS" "$Q_PRUNED")" = "2 NOMATCH-TRANSCRIPT-PRUNED" ] && printf F || printf f; }

# Controls first: the corpus must be READ (a record it holds cites), and the OLD transcript
# must really be dropped by the bound, or arm C cannot separate disk from scan list.
R="$(AI_DLC_PROJECT_ROOT="$PROJ" pc "$VALIDATOR" "$PROJ" "an unrelated operator turn about lunch")"
case "$R" in "0 MATCH"*) ok "control: the pruned-world corpus is read (a turn it holds cites)" ;;
  *) bad "FIXTURE BROKEN: the pruned-world corpus did not cite its own turn ($R)" ;; esac
R="$(AI_DLC_PROJECT_ROOT="$PROJ" pc "$VALIDATOR" "$PROJ" "another unrelated operator turn" --since 2010-01-01T00:00:00Z)"
[ "$R" = "2 NOMATCH" ] && ok "control: --since drops the OLD transcript from the scan while it stays on disk" \
  || bad "FIXTURE BROKEN: the OLD transcript was not excluded by --since ($R), so arm C tests nothing"

PA="$(p_arms "$VALIDATOR")"
case "$PA" in A*) ok "P1: a logged answer whose session transcript is gone reads NOMATCH-TRANSCRIPT-PRUNED, exit 2" ;;
  *) bad "P1: a pruned-session answer reads as never given ($(pr "$VALIDATOR" "$Q_PRUNED"))" ;; esac
case "$PA" in ?B*) ok "P2: a logged answer whose transcript IS on disk and refutes it stays plain NOMATCH" ;;
  *) bad "P2: the token fired for a session whose transcript is on disk" ;; esac
case "$PA" in ??C*) ok "P3: a session merely older than --since is ON DISK and stays plain NOMATCH" ;;
  *) bad "P3: a --since-filtered session read as pruned -- absence was judged on the scan list, not the disk" ;; esac
case "$PA" in ???D*) ok "P4: the quote as the lead-authored QUESTION of a pruned-session entry stays plain NOMATCH" ;;
  *) bad "P4: the lead's own question text in the answers log earned the pruned token" ;; esac
case "$PA" in ????E) ok "P5: a quote no answer ever carried stays plain NOMATCH" ;;
  *) bad "P5: an unlogged quote got a non-NOMATCH verdict" ;; esac
[ "$(p_installed "$PROJ/scripts/ai-dlc/validate-steering-budget.sh")" = F ] \
  && ok "P6: the installed copy, run from a subdirectory with no root in the environment, finds the log" \
  || bad "P6: the installed copy could not find the answers log from a subdirectory"

# --- The --accept-captured worlds (BL-939) --------------------------------------
# F1 is the ALLOW twin: a flagged, in-window, exact, hash-true entry whose session transcript is
# gone. Every other cell differs from F1 by ONE property, so each denial is keyed on that property.
# fr <validator> <world> <quote> <authorized-at> [extra args] -> "<rc> <stdout>" (stderr to $FERR).
FERR="$WORK/fr.err"
fr() { local v="$1" w="$2" q="$3" at="$4"; shift 4; local o r
  o="$(cd "$FW/$w/proj" && env AI_DLC_PROJECT_ROOT="$FW/$w/proj" ${FENV:-} bash "$v" --dir "$CORPUS" --cite "$q" --authorized-at "$at" "$@" 2>"$FERR")"; r=$?
  printf '%s %s' "$r" "$o"; }
F_OK="0 MATCH $FAUTH"; F_PR="2 NOMATCH-TRANSCRIPT-PRUNED"
R="$(fr "$VALIDATOR" w1 "$FQ" "$FAUTH" --accept-captured)"
if [ "$R" = "$F_OK" ] && [ "$(grep -c '^cite: accepted under --accept-captured: captured in' "$FERR")" = 1 ] && [ "$(grep -c '^cite: scanned' "$FERR")" -ge 1 ]; then
  ok "F1: a flagged, in-window, exact, hash-true entry of a pruned session reads MATCH <ts>, exit 0, with the acceptance named on stderr beside the scan line"
else bad "F1: the allow twin did not accept ($R) -- every denial cell below is then keyed on nothing"; fi
fcell() { # fcell <name> <expected> <what> <fr args...>
  local n="$1" e="$2" w="$3" r; shift 3; r="$(fr "$@")"
  if [ "$r" = "$e" ]; then ok "$n: $w"; else bad "$n: $w -- got ($r), wanted ($e)"; fi; }
fcell F2 "2 NOMATCH" "a flagged quote the log never carried stays plain NOMATCH" "$VALIDATOR" w1 "a sentence nobody captured" "$FAUTH" --accept-captured
fcell F3 "$F_PR" "a flagged entry outside the +/-7200s window stays PRUNED" "$VALIDATOR" w3 "$FQ" "$FAUTH" --accept-captured
fcell F4 "$F_PR" "the F1 world WITHOUT the flag stays PRUNED (acquits nothing elsewhere)" "$VALIDATOR" w1 "$FQ" "$FAUTH"
fcell F5 "1 " "an empty --authorized-at under the flag refuses with exit 1" "$VALIDATOR" w1 "$FQ" "" --accept-captured
fcell F6 "1 " "a date-only --authorized-at under the flag refuses with exit 1" "$VALIDATOR" w1 "$FQ" "2026-07-21" --accept-captured
fcell F7 "$F_PR" "a needle that is a strict substring of the in-window pruned body stays PRUNED (equality, not includes)" "$VALIDATOR" w7 "$FQ" "$FAUTH" --accept-captured
fcell F8 "$F_PR" "the same exact in-window quote also captured in a session whose transcript IS on disk stays PRUNED (the contradiction)" "$VALIDATOR" w8 "$FQ" "$FAUTH" --accept-captured
fcell F9 "$F_PR" "an accepting entry back-dated out of header order stays PRUNED" "$VALIDATOR" w9 "$FQ" "$FAUTH" --accept-captured
R="$(FENV=AI_DLC_ACC=1 fr "$VALIDATOR" w1 "$FQ" "$FAUTH")"
[ "$R" = "$F_PR" ] && ok "F10: AI_DLC_ACC=1 in the environment with no argv flag stays PRUNED (argv only)" || bad "F10: the environment turned the acceptance on ($R)"
R="$(cd "$FW/w1/proj" && AI_DLC_PROJECT_ROOT="$FW/w1/proj" bash "$VALIDATOR" --dir "$CORPUS" --accept-captured 2>/dev/null)"; r=$?
[ "$r" = 1 ] && [ -z "$R" ] && ok "F11: --accept-captured without --cite refuses with exit 1" || bad "F11: the flag without --cite gave rc $r ($R)"
fcell F12 "$F_PR" "an entry whose SHA256 line was altered stays PRUNED" "$VALIDATOR" w12 "$FQ" "$FAUTH" --accept-captured
fcell F13 "$F_OK" "an on-disk exact copy OUTSIDE the window contradicts nothing, so the in-window pruned entry is accepted" "$VALIDATOR" w13 "$FQ" "$FAUTH" --accept-captured
# F14-F17: --authorized-at needs a time of day, not seconds (escalations.md allows any ISO-8601 UTC
# timestamp). F14 is the minute form graph's two real minute lines carry; F15 is the transcript
# route at minute precision, and its stderr must NOT name the captured acceptance, or the cell
# cannot tell which route verified; F16 is a malformed time; F17 is a zone-less minute under a
# non-UTC TZ, which reads as UTC only if the zone-less widening reached the parser too.
R="$(fr "$VALIDATOR" w1 "$FQ" "$FAUTH_MIN" --accept-captured)"
if [ "$R" = "$F_OK" ] && [ "$(grep -c '^cite: accepted under --accept-captured: captured in' "$FERR")" = 1 ]; then
  ok "F14: a minute-precision --authorized-at ($FAUTH_MIN) under the flag is accepted on the captured route, exit 0"
else bad "F14: a minute-precision authorization was refused on the captured route ($R)"; fi
R="$(fr "$VALIDATOR" w1 "$Q_TURN" "$TURN_MIN" --accept-captured)"
if [ "$R" = "0 MATCH $TURN_TS" ] && [ "$(grep -c 'accepted under --accept-captured' "$FERR")" = 0 ]; then
  ok "F15: a minute-precision --authorized-at ($TURN_MIN) under the flag verifies on the TRANSCRIPT route (MATCH, no captured-acceptance line)"
else bad "F15: the transcript route at minute precision gave ($R)"; fi
fcell F16 "1 " "a malformed time of day under the flag refuses with exit 1" "$VALIDATOR" w1 "$FQ" "2026-07-21T~" --accept-captured
R="$(FENV=TZ=America/New_York fr "$VALIDATOR" w1 "$FQ" "${FAUTH_MIN%Z}" --accept-captured)"
[ "$R" = "$F_OK" ] && ok "F17: a zone-less minute value under TZ=America/New_York is read as UTC, so the in-window entry is accepted" \
  || bad "F17: a zone-less minute value was read in the runner's local time ($R)"

# --- G1: no caller of the citation query carries --accept-captured ---------------
# The flag belongs to gate-validation.md Check 9's retro acceptance alone; a caller that passed it
# would make that acceptance a property of automation. THE POPULATION IS DECLARED, not searched:
# the four programs that call `bash "$STEER_SCRIPT" ... --cite` (derived with I109's grammar,
# `bash .*--cite` over core/ minus fixtures, at BL-939), each declared REQUIRED in inputs.decl and
# resolved in both layouts. A consumer's gate logs, which legitimately record the Check 9 command,
# are outside it. RESIDUAL: a NEW caller added outside this set is not covered until it is added
# to G1_CALLERS and inputs.decl; the owed validate-enforcement-map arm (BL-939) closes that.
# gcall <file> prints the number of CALLS (backslash continuations folded, then a non-comment line
# carrying `bash ` and `--cite`) that also carry --accept-captured; gsites prints the call count.
gjoin() { awk '{ if (buf != "") { sub(/^[[:space:]]+/, "", $0); line = buf $0 } else line = $0
                 if (line ~ /\\$/) { sub(/\\$/, " ", line); buf = line; next }
                 buf = ""; print line }' "$1"; }
gsites() { local n; n="$(gjoin "$1" | grep -v '^[[:space:]]*#' | grep -E 'bash .*--cite' | grep -c .)" || n=0; printf '%s' "$n"; }
gcall() { local n; n="$(gjoin "$1" | grep -v '^[[:space:]]*#' | grep -E 'bash .*--cite' | grep -c -e '--accept-captured')" || n=0; printf '%s' "$n"; }
G1_CALLERS="core/hooks/ai-dlc-gate-remediation-guard.sh core/scripts/validate-escalation-resolution.sh core/scripts/validate-gate-adjudication.sh core/scripts/validate-adversarial-convergence.sh"
G1_ROOT="$(cd "$HERE/../../.." && pwd)"
g1_path() { # <dist path> -> the path in this layout, or empty
  if [ -f "$G1_ROOT/$1" ]; then printf '%s' "$G1_ROOT/$1"; return; fi
  case "$1" in
    core/scripts/*) [ -f "$G1_ROOT/scripts/ai-dlc/${1#core/scripts/}" ] && printf '%s' "$G1_ROOT/scripts/ai-dlc/${1#core/scripts/}" ;;
    core/hooks/*)   [ -f "$G1_ROOT/.claude/hooks/${1#core/hooks/}" ] && printf '%s' "$G1_ROOT/.claude/hooks/${1#core/hooks/}" ;;
  esac; }
# Controls first: both seeded flag-carrying calls found (one-line and continued), the near-miss not.
GC1="$(gcall "$WORK/guard/hit1.sh")"; GC2="$(gcall "$WORK/guard/hit2.sh")"; GCN="$(gcall "$WORK/guard/near.sh")"; GSN="$(gsites "$WORK/guard/near.sh")"
if [ "$GC1" = 1 ] && [ "$GC2" = 1 ] && [ "$GCN" = 0 ] && [ "$GSN" = 1 ]; then
  ghits=""; gsum=0; gn=0; gmiss=""
  for c in $G1_CALLERS; do
    p="$(g1_path "$c")"; [ -n "$p" ] || { gmiss="$gmiss $c"; continue; }
    echo "HERMETIC-CONSUMED $c"
    gn=$((gn + 1)); s="$(gsites "$p")"; gsum=$((gsum + s))
    [ "$s" -ge 1 ] || gmiss="$gmiss $c(no-call)"
    [ "$(gcall "$p")" = 0 ] || ghits="$ghits $c"
  done
  if [ -n "$gmiss" ]; then bad "G1: declared caller(s) absent or no longer calling --cite:$gmiss -- the population moved, re-derive it"
  elif [ -n "$ghits" ]; then bad "G1: caller(s) of validate-steering-budget --cite carry --accept-captured:$ghits -- Check 9's flag leaked into automation"
  else ok "G1: 0 of $gn declared callers ($gsum --cite calls) pass --accept-captured (controls: one-line and continued seeded calls found, near-miss not)"; fi
else bad "G1: the guard cannot fire (one-line $GC1/1, continued $GC2/1, near-miss $GCN/0 of $GSN/1 call) -- its zero would mean nothing"; fi
# COMPLETENESS, distribution only and only where the tree is git-readable: re-derive the caller set
# and compare. Inside the hermetic sandbox the tree holds only declared inputs, so the half is
# skipped with a printed note and no ok row.
if [ -d "$G1_ROOT/core/scripts" ] && git -C "$G1_ROOT" rev-parse --show-toplevel >/dev/null 2>&1 \
   && [ "$(git -C "$G1_ROOT" rev-parse --show-toplevel)" = "$G1_ROOT" ] && [ -n "$(git -C "$G1_ROOT" ls-files -- core/scripts/validate-steering-budget.sh)" ]; then
  gder="$(cd "$G1_ROOT" && git ls-files -- core ':!core/fixtures' | while IFS= read -r f; do [ "$(gsites "$f")" -ge 1 ] && printf '%s\n' "$f"; done | sort | tr '\n' ' ')"
  gdecl="$(printf '%s\n' $G1_CALLERS | sort | tr '\n' ' ')"
  [ "$gder" = "$gdecl" ] && ok "G1-completeness: the tree's --cite callers are exactly the declared set ($gdecl)" \
    || bad "G1-completeness: the tree's --cite callers ($gder) differ from the declared set ($gdecl)"
else echo "  note  G1-completeness: not run -- no git-readable distribution tree here (hermetic sandbox or consumer); the declared caller set is the population"; fi

# --- D1-D8: a disposition-shaped quote verifies only as ONE WHOLE AskUserQuestion answer (BL-950) ---
# `Strike|Reword|Confirm LR-S<n>-<m>` names an option the LEAD wrote, so the substring test let it
# verify against a longer answer, a longer id, the joined text of several answers, or typed prose.
# Each refusal cell has an allow cell one property apart; each cell is one transcript, read once.
D_OK="0 MATCH 2026-07-21T02:05:00Z"
# dc <validator> <transcript> <quote> -> "<rc> <stdout>" for the disposition-shaped cells.
dc() { local o r; o="$(bash "$1" --transcript "$WORK/$2" --cite "$3" 2>/dev/null)"; r=$?; printf '%s %s' "$r" "$o"; }
d_out() { # d_out <arm> <validator>
  local a="$1" v="$2"
  case "$a" in
    D1) dc "$v" disp-exact.jsonl "Strike LR-S7-2" ;;
    D2) dc "$v" disp-more.jsonl "Strike LR-S7-2" ;;
    D3) dc "$v" disp-prefix.jsonl "Strike LR-S7-2" ;;
    D4) dc "$v" disp-multi.jsonl "Strike LR-S7-4" ;;
    D5) dc "$v" ask.jsonl "$SUBQ" ;;
    D6) dc "$v" disp-typed.jsonl "Strike LR-S7-2" ;;
    D7) dc "$v" disp-badge.jsonl "Confirm LR-S7-2" ;;
    D8) dc "$v" disp-exact.jsonl "Strike LR-S7-2 (Recommended)" ;;
  esac
}
d_holds() { # d_holds <arm> <output>: does the arm's own expectation hold on that output
  case "$1:$2" in
    D1:"$D_OK"|D4:"$D_OK"|D5:"$D_OK"|D7:"$D_OK"|D8:"$D_OK") return 0 ;;
    D2:"2 NOMATCH"|D3:"2 NOMATCH"|D6:"2 NOMATCH") return 0 ;;
  esac
  return 1
}
dcell() { # dcell <arm> <what>
  local o; o="$(d_out "$1" "$VALIDATOR")"
  if d_holds "$1" "$o"; then ok "$1: $2"; else bad "$1: $2 -- got ($o)"; fi; }
dcell D1 "a disposition quote equal to one whole AskUserQuestion answer verifies"
dcell D2 "the same quote against the answer 'Strike LR-S7-2 but keep the index' is refused (option plus more text)"
dcell D3 "'Strike LR-S7-2' against only 'Strike LR-S7-20' is refused (prefix of a longer id)"
dcell D4 "'Strike LR-S7-4' verifies against a result answering 'Strike LR-S7-4' and 'Confirm LR-S7-5' (each answer is whole)"
dcell D5 "a non-disposition quote that is a substring of an answer still verifies (substring kept)"
dcell D6 "'Strike LR-S7-2' typed as prose, with no AskUserQuestion answer, is refused"
dcell D7 "bare 'Confirm LR-S7-2' verifies against the answer 'Confirm LR-S7-2 (Recommended)' (badge stripped)"
dcell D8 "badged 'Strike LR-S7-2 (Recommended)' verifies against the bare answer 'Strike LR-S7-2' (badge stripped from the quote too)"

echo
report_end askuserquestion-citation
