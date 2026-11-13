#!/usr/bin/env bash
# BL-844's second subject, carried by BL-1030: after a gate-3 rework, are gates 1 and 2 re-run?
# Read ONLY from committed graph refs (git ls-tree / git show / git log / git diff; no fetch, no checkout).
# Each following seat also prints its delta against the same gate's previous pass: the count of
# paths outside docs/, _bmad-output/ and test-results/ (0 = a records-only delta). A path count, not
# GATE1-SKIP's code-line test, so 0 here is necessary for a skip and not sufficient.
#
# Usage: bash derive-g3.sh [<graph repo path>] [<ref>]   (defaults: /Users/n8/git/graph main)
# Runs from any cwd.
#
# POPULATION, derived: every story with a gate-3 plan at pass >= 2,
# `_bmad-output/implementation-artifacts/s<N>/gate-transition/<idx>-g3-p<M>.plan`, in s321 and s322
# (s320 has no gate plans). The index is compared with `.` and `-` unified (1.4 == 1-4).
#
# EACH GATE-1 / GATE-2 PLAN is joined to its review file: `docs/reviews/s<N>/[<n>-]<idx>-code-review[-p<M>].md`
# (gate 1) or `...-qa-validation[-p<M>].md` (gate 2), the one whose `reviewed-sha:` is the plan's `sha:`.
#
# CLASSIFICATION of a gate-1 / gate-2 seat, from its review file, first rule that holds:
#   (c) REMEDY: the review's text before its `## Verdict` heading has a line naming gate 3 (`gate-3`
#       or `gate 3`) and a `Check <n>`: a re-review gate 3 asked for (for example "It exists because
#       gate-3 Check 19 FAILed pass 1"). These must NOT be skipped.
#   (b) SAME-GATE RE-REVIEW: the review of the same gate's previous pass reads NEEDS_REWORK.
#   (a) RE-RUN: anything else. This is BL-1030's subject.
# A verdict is the first non-blank line under a `## Verdict` heading, else a `Verdict: <X>` line.
#
# ORDER AND THE TIE CONVENTION: by the committer time t of the commit each plan's `sha:` names (plan
# and review files were committed in one batch per sprint, so their own commit times cannot order
# anything). Rework M (the work between gate-3 pass M-1 and pass M) owns:
#   a class (a) or (b) plan with  t(g3 p<M-1>) <  t <= t(g3 p<M>)   (a go-signal gate 3 then judged);
#   a class (c) plan with         t(g3 p<M-1>) <= t <  t(g3 p<M>)   (a remedy of the failed pass M-1,
#     which is run at the very sha that pass failed, with no new commit, so a pure time window
#     cannot place it).
# The tie is broken by CONTENT (the remedy citation), never by time.
set -u
GRAPH="${1:-/Users/n8/git/graph}"
REF="${2:-main}"
GREP=/usr/bin/grep
P=_bmad-output/implementation-artifacts
NEG=ZZNOPE-8f3a1q

# The GATE1-RERUN control below reads the gate-transition fixture's own expectation. Find it FIRST,
# by walking up from this script for core/fixtures/gate-transition/run.sh, and refuse before any
# output when it is absent (a copy run outside the ai-dlc tree): a control that is skipped prints
# nothing, which reads exactly like one that passed.
FXREL=core/fixtures/gate-transition/run.sh
d="$(cd "$(dirname "$0")" && pwd)"; FX=""
while [ "$d" != / ]; do [ -f "$d/$FXREL" ] && { FX="$d/$FXREL"; break; }; d="$(dirname "$d")"; done
[ -n "$FX" ] || { echo "derive-g3.sh: REFUSED -- ${FXREL} not found walking up from $(cd "$(dirname "$0")" && pwd); the GATE1-RERUN control cannot run, so no result is printed. Run this script from inside the ai-dlc tree." >&2; exit 2; }

SHA="$(git -C "$GRAPH" rev-parse --verify -q "${REF}^{commit}")" || { echo "derive-g3.sh: cannot resolve ${REF} in ${GRAPH}" >&2; exit 2; }
echo "graph ${GRAPH} ref ${REF} = ${SHA}; order = committer time of each plan's sha:, ties by remedy citation"

# THE ONE MATCHER for gate-1 re-run markers, used on the corpus and on the controls.
gate1_marks() { # stdin: plan text -> space-separated sorted marks, or `-`
  local m
  m="$($GREP -oE 'GATE1-(SKIP|RERUN)|^gate: rerun$' | sed 's/^gate: rerun$/gate:rerun/' | sort -u | tr '\n' ' ')"
  printf '%s\n' "${m:--}"
}
# THE ONE REMEDY MATCHER: 1 when the text before `## Verdict` cites a gate-3 Check, else 0.
cites_g3() { awk '/^##[ \t]+Verdict/ { exit } /[Gg]ate[- ]3/ && /Check [0-9]+/ { f = 1; exit } END { print f + 0 }'; }
# THE ONE VERDICT READER.
verdict_of() {
  awk 'f && NF { gsub(/[*`]/, ""); print $1; exit }
       /^##[ \t]+Verdict/ { f = 1; next }
       /^(\*\*)?Verdict:/ { s = $0; gsub(/[*`]/, "", s); sub(/^Verdict:[ \t]*/, "", s); split(s, a, " "); print a[1]; exit }'
}

# CONTROL: the matcher must find GATE1-RERUN in the form gate-transition.sh writes it. The form is
# taken from the gate-transition fixture's own expectation ($FX, found above or refused); a seeded
# plan in that form must read it.
fxn="$($GREP -c "grep -q '^route: rerun GATE1-RERUN: '" "$FX")" || fxn=0
echo "fixture expectation ${FXREL}: ${fxn} line(s) asserting '^route: rerun GATE1-RERUN: ' (must be > 0)"
[ "$fxn" -gt 0 ] || { echo "derive-g3.sh: the fixture no longer asserts the GATE1-RERUN form; the matcher control has no subject" >&2; exit 2; }
seed="$(printf 'story: 1-1\ngate: rerun\npass: 2\nroute: rerun GATE1-RERUN: seeded\n' | gate1_marks)"
nseed="$(printf 'story: 1-1\ngate: 2\npass: 2\nroute: record-only ROUTE: seeded\n' | gate1_marks)"
echo "matcher control: seeded rerun plan -> [${seed% }] (must carry GATE1-RERUN and gate:rerun); seeded record-only plan -> [${nseed% }] (must be -)"
case "$seed" in *GATE1-RERUN*gate:rerun*|*gate:rerun*GATE1-RERUN*) ;; *) echo "derive-g3.sh: matcher cannot match GATE1-RERUN" >&2; exit 2 ;; esac
[ "$nseed" = - ] || { echo "derive-g3.sh: matcher fires on a plan with no marker" >&2; exit 2; }
# CONTROL: the remedy matcher reads a seeded remedy before the verdict, and not one after it.
c1="$(printf '# Code Review\n\nIt exists because gate-3 Check 19 FAILed pass 1.\n\n## Verdict\nAPPROVED\n' | cites_g3)"
c0="$(printf '# Code Review\n\nSerial re-review of the fix delta.\n\n## Verdict\nAPPROVED\n\nSee gate-3 Check 19.\n' | cites_g3)"
v1="$(printf '# x\n\n## Verdict\n\nNEEDS_REWORK\n' | verdict_of)"; v2="$(printf '# x\n\n**Verdict:** PASS\n' | verdict_of)"
echo "remedy matcher control: seeded remedy -> ${c1} (must be 1); citation after the verdict -> ${c0} (must be 0); verdict reader -> ${v1} / ${v2} (must be NEEDS_REWORK / PASS)"
[ "$c1" = 1 ] && [ "$c0" = 0 ] && [ "$v1" = NEEDS_REWORK ] && [ "$v2" = PASS ] || { echo "derive-g3.sh: remedy or verdict control failed" >&2; exit 2; }
for S in s321 s322; do
  for k in GATE1-RERUN GATE1-SKIP; do
    c="$(git -C "$GRAPH" grep -l -F -- "$k" "$SHA" -- "$P/$S/gate-transition" | $GREP -c .)" || c=0
    printf '%s plans carrying %s: %s\n' "$S" "$k" "$c"
  done
done

TREE="$(git -C "$GRAPH" ls-tree -r --name-only "$SHA" -- "$P/s321/gate-transition" "$P/s322/gate-transition" docs/reviews/s321 docs/reviews/s322)"
nneg="$(printf '%s\n' "$TREE" | $GREP -c "/${NEG}-g[123]-p[0-9]*\.plan$")" || nneg=0
echo "negative control: plans for impossible story ${NEG}: ${nneg} (must be 0)"
[ "$nneg" = 0 ] || exit 2

shatime() { git -C "$GRAPH" log -1 --format=%ct "$1" 2>/dev/null || echo 0; }
iso() { git -C "$GRAPH" log -1 --format=%cI "$1" 2>/dev/null || echo NOSHA; }

# review_of <sprint> <story-re> <gate> <pass> <sha> -> the review file path, or nothing
review_of() {
  local kind sfx r rs
  [ "$3" = 1 ] && kind=code-review || kind=qa-validation
  [ "$4" = 1 ] && sfx="" || sfx="-p$4"
  for r in $(printf '%s\n' "$TREE" | $GREP -E "^docs/reviews/$1/([0-9]+-)?$2-${kind}${sfx}\.md$"); do
    rs="$(git -C "$GRAPH" show "${SHA}:${r}" | sed -n 's/^reviewed-sha: *`\{0,1\}\([0-9a-f]*\).*/\1/p' | head -1)"
    [ -n "$rs" ] && case "$5" in "$rs"*) printf '%s\n' "$r"; return ;; esac
  done
}

NR=0; NNONE=0; NA=0; NB=0; NC=0; SA=0; SB=0; SC=0; CTL=""
for S in s321 s322; do
  STREE="$(printf '%s\n' "$TREE" | $GREP "^${P}/${S}/gate-transition/")"
  stories="$(printf '%s\n' "$STREE" | $GREP -E -- '-g3-p[0-9]+\.plan$' | sed -e 's#.*/##' -e 's/-g3-p[0-9]*\.plan$//' | tr . - | sort -u)"
  for st in $stories; do
    re="$(printf '%s' "$st" | sed 's/-/[.-]/g')"
    plans="$(printf '%s\n' "$STREE" | $GREP -E "/${re}-g[123]-p[0-9]+\.plan$")"
    maxg3="$(printf '%s\n' "$plans" | $GREP -E -- '-g3-p[0-9]+\.plan$' | sed 's/.*-g3-p\([0-9]*\)\.plan$/\1/' | sort -n | tail -1)"
    [ "${maxg3:-1}" -ge 2 ] || continue
    # one row per plan: <time> <gate> <pass> <sha> <seats> <route> <marks> <review> <verdict> <cite>
    rows=""
    for f in $plans; do
      b="${f##*/}"; g="$(printf '%s' "$b" | sed 's/.*-g\([123]\)-p.*/\1/')"; pa="$(printf '%s' "$b" | sed 's/.*-p\([0-9]*\)\.plan$/\1/')"
      body="$(git -C "$GRAPH" show "${SHA}:${f}")"
      ps="$(printf '%s\n' "$body" | sed -n 's/^sha: //p' | head -1)"
      rt="$(printf '%s\n' "$body" | sed -n 's/^route: //p' | head -1)"
      nsh="$(printf '%s\n' "$body" | $GREP -cE '^[0-9]+	')" || nsh=0
      case "$rt" in
        partitioned*) se=$((nsh + 1)); rs="partitioned" ;;
        serial*) se=1; rs="serial($(printf '%s' "$rt" | sed -n 's/^serial SERIAL: \([0-9]*\) reviewable.*/\1/p')_reviewable)" ;;
        record-only*) se=1; rs="record-only" ;;
        gate3*) se=-; rs="gate3" ;;
        *) se="?"; rs="$(printf '%s' "$rt" | cut -d' ' -f1)" ;;
      esac
      mk="$(printf '%s\n' "$body" | gate1_marks)"; mk="$(printf '%s' "${mk% }" | tr ' ' ,)"
      rv=-; vd=-; ci=0
      if [ "$g" != 3 ]; then
        rv="$(review_of "$S" "$re" "$g" "$pa" "$ps")"
        if [ -n "$rv" ]; then
          rb="$(git -C "$GRAPH" show "${SHA}:${rv}")"
          vd="$(printf '%s\n' "$rb" | verdict_of)"; ci="$(printf '%s\n' "$rb" | cites_g3)"; rv="${rv##*/}"
        else rv=NONE; fi
      fi
      rows="${rows}$(shatime "$ps") ${g} ${pa} ${ps} ${se} ${rs} ${mk} ${rv} ${vd:--} ${ci}
"
    done
    # classes: c cites a gate-3 Check; b the same gate's previous pass reads NEEDS_REWORK; a otherwise.
    rows="$(printf '%s' "$rows" | sort -n | awk '{ r[NR] = $0; g[NR] = $2; p[NR] = $3; v[$2 " " $3] = $9 }
      END { for (i = 1; i <= NR; i++) { split(r[i], x, " "); c = "-"
              if (g[i] != 3) { if (x[10] == 1) c = "c"; else if (v[g[i] " " (p[i] - 1)] == "NEEDS_REWORK") c = "b"; else c = "a" }
              print r[i], c } }')"
    echo "== ${S} ${st}: gate-3 passes 1..${maxg3}"
    m=2
    while [ "$m" -le "$maxg3" ]; do
      lo="$(printf '%s\n' "$rows" | awk -v p=$((m - 1)) '$2 == 3 && $3 == p { print $1 }')"
      hi="$(printf '%s\n' "$rows" | awk -v p="$m" '$2 == 3 && $3 == p { print $1 }')"
      hs="$(printf '%s\n' "$rows" | awk -v p="$m" '$2 == 3 && $3 == p { print $4 }')"
      fol="$(printf '%s\n' "$rows" | awk -v lo="$lo" -v hi="$hi" '$2 != 3 && (($11 != "c" && $1 > lo && $1 <= hi) || ($11 == "c" && $1 >= lo && $1 < hi))')"
      NR=$((NR + 1))
      echo "  gate-3 rework -> g3 p${m} @ ${hs:0:10} ($(iso "$hs"))"
      if [ -z "$fol" ]; then
        NNONE=$((NNONE + 1)); echo "    no gate-1 or gate-2 plan between g3 p$((m - 1)) and g3 p${m}"
      else
        while read -r t g pa ps se rs mk rv vd ci cl; do
          # The delta against the same gate's previous pass: paths outside docs/, _bmad-output/ and
          # test-results/ (code, tests, scripts, config). 0 means a records-only delta.
          pp="$(printf '%s\n' "$rows" | awk -v g="$g" -v p=$((pa - 1)) '$2 == g && $3 == p { print $4 }')"
          nd=-; [ -n "$pp" ] && { nd="$(git -C "$GRAPH" diff --name-only "$pp" "$ps" | $GREP -cvE '^(docs/|_bmad-output/|test-results/)')" || nd=0; }
          echo "    g${g} p${pa} @ ${ps:0:10} ($(iso "$ps")) route=${rs} seats=${se} gate1-marks=[${mk}] review=${rv} verdict=${vd} class=${cl} non-record-paths-since-p$((pa - 1))=${nd}"
          [ "$cl" = a ] && [ "$nd" = 0 ] && A0=$((${A0:-0} + se))
          case "$cl" in a) NA=$((NA + 1)); SA=$((SA + se)) ;; b) NB=$((NB + 1)); SB=$((SB + se)) ;; c) NC=$((NC + 1)); SC=$((SC + se)) ;; esac
          CTL="${CTL} ${S}:${st}:g${g}p${pa}:${cl}"
        done <<EOF
$fol
EOF
      fi
      m=$((m + 1))
    done
  done
done
echo "== ${NR} gate-3 reworks; ${NNONE} followed by no gate-1 or gate-2 plan"
echo "== seats after a gate-3 rework: (a) re-run ${SA} seats in ${NA} plans; (b) same-gate re-review ${SB} seats in ${NB} plans; (c) gate-3 remedy ${SC} seats in ${NC} plans; total $((SA + SB + SC))"
echo "== class (a) seats over a records-only delta (0 non-record paths since the same gate's previous pass): ${A0:-0}"
# CONTROLS on the corpus: a known same-sha remedy (s322 1 g1 p2, at gate-3 p1's own sha) must be (c),
# and a known re-run (s322 3 g1 p2, the partitioned gate-1 pass after gate-3 p1) must be (a).
kc=0; ka=0
case "$CTL " in *" s322:1:g1p2:c "*) kc=1 ;; esac
case "$CTL " in *" s322:3:g1p2:a "*) ka=1 ;; esac
echo "positive controls: s322 1 g1 p2 classified (c): ${kc} (must be 1); s322 3 g1 p2 classified (a): ${ka} (must be 1)"
[ "$kc" = 1 ] && [ "$ka" = 1 ] || exit 2
