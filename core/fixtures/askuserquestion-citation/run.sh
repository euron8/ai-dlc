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
# The mutant matrix replaces an exact-vector assertion per mutant: per push each mutant runs its
# deciding arm and its twin, and the matrix is re-measured whenever an arm or a mutant changes.
# Arm names are A1-A5 (assertions 1-5) and P1-P6 (the pruned-world arms); they are the column
# names `--matrix` prints.
# MUTANT-MATRIX whole-string decides=A2 twins=A1
# MUTANT-MATRIX no-token decides=P1 twins=P2
# MUTANT-MATRIX quote-anywhere decides=P4 twins=P1
# MUTANT-MATRIX scan-list decides=P3 twins=P4
# MUTANT-MATRIX no-disk-check decides=P2 twins=P1
# MUTANT-MATRIX cwd-root decides=P6 twins=P1
# MUTANT-MATRIX-DYNAMIC mutant_score-name why=mutant_score() passes its first argument "$n" to mutant_killed; each mutant_score call (whole-string, no-token, ...) names a literal mutant that carries its own row in this block
# MUTANT-MATRIX-REMEASURE bash core/fixtures/askuserquestion-citation/run.sh --matrix
#
# Usage: run.sh [--matrix]
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"
# The REQUIRED input of inputs.decl: every assertion below drives this file, and seed.sh has
# already copied it into the seeded tree, so this is the point the declaration is consumed.
echo "HERMETIC-CONSUMED $VALIDATOR"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }
MATRIX=0; MROWS=0; GREEN=""
if [ "${1:-}" = "--matrix" ]; then MATRIX=1; fi
. "$HERE/../lib/mutant.sh" || { echo "FIXTURE ERROR: lib/mutant.sh not found" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"
. "$HERE/matrix.sh" || { echo "FIXTURE ERROR: matrix.sh not found" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/fixtures/askuserquestion-citation/matrix.sh"
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

# --- Assertion 6: MUTANT — answer-side extraction is what makes 2 hold ---------
# Widen the extraction to the whole tool_result string, exactly as a naive fix would, and the
# lead-authored question MUST become citable. If it does not, assertion 2 is passing for some
# other reason and proves nothing about the extraction.
# (The whole-string mutant is scored with the others in the MUTANTS section below.)

# --- The pruned-session world: NOMATCH-TRANSCRIPT-PRUNED ------------------------
# An answer the capture hook logged, whose transcript Claude Code has since deleted, used to
# read NOMATCH -- the verdict a fabricated authorization gets. It now reads its own token, with
# exit 2 unchanged so no reader is acquitted by it. Every arm asserts the stdout VALUE and the
# exit, and each has a mutant below that flips it.
# pc <validator> <cwd> <quote> [extra args] -> "<rc> <stdout>"; the root comes from the caller.
pc() { local v="$1" d="$2" q="$3"; shift 3; local o r
  o="$(cd "$d" && bash "$v" --dir "$CORPUS" --cite "$q" "$@" 2>/dev/null)"; r=$?
  printf '%s %s' "$r" "$o"; }
# The fixture's copy of the validator sits inside the distribution, so its own-install walk
# resolves the REPO; the root is handed over explicitly. Arm P6 covers the walk.
pr() { local v="$1"; shift; AI_DLC_PROJECT_ROOT="$PROJ" pc "$v" "$PROJ" "$@"; }
p_arms() { # p_arms <validator> [letters] -> one letter per arm asked for (default ABCDE), upper case = holds
  # A mutant is scored over the arms its pattern constrains, not all five: each arm is one node run.
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

# MUTANTS. Each is one plausible wrong build of the same feature and must flip exactly the arm
# written against it. Built by literal string replacement; a mutant that does not apply is a
# stale fixture, never a pass.
mut() { # mut <out> <from> <to>
  node -e 'const fs=require("fs");const [f,o,a,b]=process.argv.slice(1);const s=fs.readFileSync(f,"utf8");if(!s.includes(a))process.exit(3);fs.writeFileSync(o,s.split(a).join(b));' \
    "$VALIDATOR" "$1" "$2" "$3"; }

# ARMS, as one function of (arm, validator) -> "<rc> <stdout>". A1-A5 are assertions 1-5 above and
# P1-P6 the pruned-world arms; every mutant is scored through the same function the shipped
# validator is, so a verdict is comparable cell for cell. P6 installs the validator it is handed.
ARMS="A1 A2 A3 A4 A5 P1 P2 P3 P4 P5 P6"
arm_out() { # arm_out <arm> <validator>
  local a="$1" v="$2" o r
  case "$a" in
    A1) o="$(bash "$v" --transcript "$ASK" --cite "$ANSWER" 2>/dev/null)"; r=$?; printf '%s %s' "$r" "$o" ;;
    A2) o="$(bash "$v" --transcript "$ASK" --cite "$QUESTION" 2>/dev/null)"; r=$?; printf '%s %s' "$r" "$o" ;;
    A3) o="$(bash "$v" --transcript "$OTHER" --cite "$ANSWER" 2>/dev/null)"; r=$?; printf '%s %s' "$r" "$o" ;;
    A4) o="$(bash "$v" --transcript "$TYPED" --cite "$ANSWER" 2>/dev/null)"; r=$?; printf '%s %s' "$r" "$o" ;;
    A5) o="$(bash "$v" --transcript "$ASK" --count 2>/dev/null)"; r=$?; printf '%s %s' "$r" "$o" ;;
    P1) pr "$v" "$Q_PRUNED" ;;
    P2) pr "$v" "$Q_LIVE" ;;
    P3) pr "$v" "$Q_OLD" --since 2010-01-01T00:00:00Z ;;
    P4) pr "$v" "$Q_ASKED" ;;
    P5) pr "$v" "a phrase nobody logged or typed" ;;
    P6) cp "$v" "$PROJ/scripts/ai-dlc/mx-p6.sh" || { printf 'COPY-FAILED'; return 0; }
        env -u AI_DLC_PROJECT_ROOT -u CLAUDE_PROJECT_DIR bash -c 'o="$(cd "$1" && bash "$2" --dir "$3" --cite "$4" 2>/dev/null)"; printf "%s %s" "$?" "$o"' _ "$PROJ/sub" "$PROJ/scripts/ai-dlc/mx-p6.sh" "$CORPUS" "$Q_PRUNED" ;;
  esac
}
arm_holds() { # arm_holds <arm> <arm_out>: does the arm's own expectation hold on that output
  case "$1:$2" in
    A1:[0-9]" MATCH"*|A4:[0-9]" MATCH"*) return 0 ;;
    A2:[0-9]" NOMATCH"*|A3:[0-9]" NOMATCH"*) return 0 ;;
    A5:[0-9]" 0") return 0 ;;
    P1:"2 NOMATCH-TRANSCRIPT-PRUNED"|P6:"2 NOMATCH-TRANSCRIPT-PRUNED") return 0 ;;
    P2:"2 NOMATCH"|P3:"2 NOMATCH"|P4:"2 NOMATCH"|P5:"2 NOMATCH") return 0 ;;
  esac
  return 1
}
# ship_get <arm> sets SHIPV to the shipped validator's output for the arm, computed once per arm.
ship_get() { local a="$1" v; eval "v=\${SHIP_$a-__unset__}"
  if [ "$v" = __unset__ ]; then v="$(arm_out "$a" "$VALIDATOR")"; printf -v "SHIP_$a" '%s' "$v"; fi
  SHIPV="$v"; }

# mutant_score <name> <deciding arm> <twin arm> <what the mutant does> <from> <to>
# Per push: the deciding arm must diverge from the shipped verdict and no longer hold, and the twin
# must answer exactly as the shipped validator does. With --matrix: every arm against the mutant.
mutant_score() {
  local n="$1" d="$2" tw="$3" m="$WORK/mut-$1.sh" a o w kd base
  if ! mut "$m" "$5" "$6"; then bad "FIXTURE STALE: mutant $n did not apply -- the line it rewrites moved"; return; fi
  if [ "$MATRIX" = 1 ]; then
    for a in $ARMS; do
      ship_get "$a"; o="$(arm_out "$a" "$m")"
      if arm_holds "$a" "$o"; then w=GREEN; else w=TRIPPED; fi
      if [ "$o" = "$SHIPV" ]; then kd=no; else kd=yes; fi
      matrix_row "$n" "$a" "${o%% *}" "$w" "$kd"; MROWS=$((MROWS + 1))
    done
    ok "MATRIX $n measured against $ARMS"
    return 0
  fi
  ship_get "$d"; if arm_holds "$d" "$SHIPV"; then base=1; else base=0; fi
  o="$(arm_out "$d" "$m")"
  if [ "$o" != "$SHIPV" ] && ! arm_holds "$d" "$o"; then mutant_killed "$base" "$n" "mutant $n: $4 ($d)"
  else bad "MUTANT $n SURVIVED on $d ($o) -- $4"; fi
  ship_get "$tw"; o="$(arm_out "$tw" "$m")"
  if [ "$o" = "$SHIPV" ]; then ok "T-$n twin $tw stays GREEN under mutant $n (the change is confined to its deciding arm)"
  else bad "T-$n twin $tw changed under mutant $n ($o vs shipped $SHIPV) -- the matrix row for this mutant moved"; fi
}

# The unmutated-copy control (a copy in the mutant directory, three arms spanning the cite path, the
# token path and the installed-copy path): the harness must itself run the shipped behaviour green.
CTL="$WORK/mut-control.sh"; cp "$VALIDATOR" "$CTL" || { echo "FIXTURE ERROR: cannot copy the validator" >&2; exit 2; }
cn=0
for a in A2 P1 P6; do
  ship_get "$a"; o="$(arm_out "$a" "$CTL")"
  if arm_holds "$a" "$o" && [ "$o" = "$SHIPV" ]; then cn=$((cn + 1)); fi
done
[ "$cn" -eq 3 ] && ok "CONTROL: an unmutated copy of the validator holds arms A2, P1 and P6 and answers as the shipped one does -- the mutant harness is not what fails" \
  || bad "CONTROL: an unmutated copy held $cn of 3 arms -- the mutant harness, not the mutants, is broken"

mutant_score whole-string A2 A1 "accepting the whole tool_result makes the lead's own question citable -- assertion 2 has teeth" \
  'for (const m of raw.matchAll(/"\s*=\s*"([^"]*)"/g)) out.push(m[1]);' 'out.push(raw);'
mutant_score no-token P1 P2 "emitting plain NOMATCH instead of the token fails P1" \
  'console.log("NOMATCH-TRANSCRIPT-PRUNED")' 'console.log("NOMATCH")'
mutant_score quote-anywhere P4 P1 "matching the quote anywhere in an entry fails P4" \
  '!norm(body).includes(needle)) continue;' '!norm(e).includes(needle)) continue;'
mutant_score scan-list P3 P4 "judging absence on the --since-filtered scan list fails P3" \
  'if (!fs.existsSync(path.join(tdir, sid + ".jsonl"))) pruned.add(sid);' \
  'if (!files.some(f => path.basename(f) === sid + ".jsonl")) pruned.add(sid);'
mutant_score no-disk-check P2 P1 "skipping the on-disk check fails P2" \
  'if (!fs.existsSync(path.join(tdir, sid + ".jsonl"))) pruned.add(sid);' 'pruned.add(sid);'
mutant_score cwd-root P6 P1 "reading the log from CLAUDE_PROJECT_DIR or cwd fails P6" \
  'const LOGROOT = process.env.AI_DLC_LOGROOT || "/nonexistent";' \
  'const LOGROOT = process.env.CLAUDE_PROJECT_DIR || ".";'

# A plain run executes no matrix-only cell; --matrix executes one row per mutant per arm.
if [ "$MATRIX" = 0 ]; then
  if [ "$MROWS" -eq 0 ]; then ok "MX plain run executed no matrix-only cell (matrix rows=0)"
  else bad "MX plain run executed $MROWS matrix-only rows"; fi
else
  if [ "$MROWS" -eq 66 ]; then ok "MX matrix run measured 66 mutant x arm cells (6 mutants x 11 arms)"
  else bad "MX matrix run measured $MROWS cells, 66 expected"; fi
fi

echo
if [ "$fails" -eq 0 ]; then echo "askuserquestion-citation: PASS"; exit 0; fi
echo "askuserquestion-citation: $fails assertion(s) FAILED" >&2
exit 1
