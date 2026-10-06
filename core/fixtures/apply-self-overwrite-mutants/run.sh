#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# apply-self-overwrite-mutants/run.sh -- the mutation battery behind `apply-self-overwrite`.
# DISTRIBUTION-ONLY (see .dist-only).
#
# Usage: run.sh [--rows <file>]
#        --rows  append one `<label>TAB<killed set>` row per scored mutant, in dispatch order, the
#                killed set in P_ALL order and space-joined (empty for a mutant that killed nothing).
# Exit:  0 = every mutant killed exactly its expected set and the control killed nothing,
#        1 = an assertion failed, 2 = fixture broken.
#
# WHY THIS IS SPLIT OUT. Held inside the shipped fixture, eight mutants each built and drove one to
# three synthetic pulls serially after the arms had run. The battery mutates copies of core's own
# `reconcile/apply.sh`, which a consumer is denied editing, so proving the arms can fail is a
# question about a file only this repository changes. The consumer keeps every behavioural arm.
#
# ONE COPY OF THE PREDICATES. Both fixtures source `apply-self-overwrite/lib.sh`, so a mutant is
# scored by the very predicate bodies the shipped arms run, over the very worlds they build. The
# join below asserts the shipped fixture's predicate calls and P_ALL are the same set, so a
# predicate added to one and not the other cannot leave an arm unproven or a mutant scored against
# an arm nobody runs.
#
# EVERY MUTANT IS SCORED AGAINST EVERY PREDICATE. The unsplit fixture scored each mutant on the one
# arm it must move and, for M4-M8, the one neighbour it must leave alone. Here each mutant's killed
# set is the whole matrix row, so a mutant that also moves an arm nobody looked at is visible. Where
# a mutant kills more than one predicate, its comment says why every finding is true.
#
# THE TWO MUTANTS OF ONE FUNCTION. The repair has two independent failure directions and a single
# revert would kill both arms at once. So M1 destroys the inode swap while keeping the temp file
# (self-corruption returns), and M3 copies instead of renaming and never removes the temp (litter
# returns -- and, measured, self-corruption with it, since `cp` writes the same inode).
#
# SCORED IN PARALLEL, AND THE SILENT LOSS IS THE FAILURE MODE THIS SHAPE HAS TO CLOSE. A pool that
# drops a scorer reports fewer verdicts, and fewer verdicts read exactly like fewer failures. So:
#   - each scorer runs in its own subshell and builds every world under `$W/mut-<id>/`;
#   - it writes ONE verdict file, temp-then-mv, carrying the number of predicates it evaluated;
#   - the parent counts verdicts against dispatches, and judges each with `judge`, which treats a
#     missing verdict, a TIMEOUT, or an evaluated count other than |P_ALL| as a FAIL;
#   - `judge` itself is probed every run, on a real verdict file, in both directions.
# The pool is a FIXED width of 8 (no knob); completion is read from sentinel files the scorers
# write, never from the process table.
#
# THE WATCHDOG. bash 3.2 has no `wait -n`, so each scorer runs under a slot that polls it and,
# past SCORER_BOUND seconds, writes a TIMEOUT marker and kills the scorer's whole process tree
# (stopped first, then children before parents, so nothing reparents to init and keeps spinning).
# A scorer measured about 15s solo; a unit under the gate's pool has measured 4x its solo time, and
# 600s is roughly 10x that loaded figure.
HERE="$(cd "$(dirname "$0")" && pwd)"
NAME="apply-self-overwrite-mutants"
ROWS=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --rows) ROWS="${2:-}"; [ -n "$ROWS" ] || { echo "usage: run.sh [--rows <file>]" >&2; exit 2; }; shift 2 ;;
    *) echo "usage: run.sh [--rows <file>]" >&2; exit 2 ;;
  esac
done
command -v python3 >/dev/null 2>&1 || { echo "FIXTURE ERROR: python3 not on PATH (the mutation helper)" >&2; exit 2; }
SIB="$HERE/../apply-self-overwrite"
[ -f "$SIB/lib.sh" ] || { echo "FIXTURE BROKEN: $SIB/lib.sh is absent; no predicate exists to score a mutant against" >&2; exit 2; }
[ -f "$SIB/run.sh" ] || { echo "FIXTURE BROKEN: $SIB/run.sh is absent; the arm/P_ALL join has no subject" >&2; exit 2; }
. "$SIB/lib.sh"
if [ -n "$ROWS" ]; then : >> "$ROWS" || { echo "FIXTURE ERROR: cannot write --rows $ROWS" >&2; exit 2; }; fi

echo "$NAME:"
echo "$NAME: resolved subject = $REC/apply.sh"

# THE JOIN: every predicate the shipped fixture calls -- through `arm`, or directly as one of its
# two sanity gates -- is scored here, and every predicate scored here is one the shipped fixture
# runs. Read from the shipped run.sh's own call lines, so the shipped set is never restated.
ARMS="$(sed -n -e 's/^arm \([a-z0-9_][a-z0-9_]*\) .*/\1/p' -e 's/^p_\([a-z0-9_][a-z0-9_]*\) "\$W\/s" || broken .*/\1/p' "$SIB/run.sh" | sort)"
PSET="$(printf '%s\n' $P_ALL | sort)"
na="$(grep -c . <<<"$ARMS")" || na=0
np="$(grep -c . <<<"$PSET")" || np=0
if [ "$na" -eq 0 ] || [ "$np" -eq 0 ]; then
  bad "J1: FIXTURE BROKEN -- read $na predicate call(s) from the shipped run.sh and $np from P_ALL; an empty side agrees with anything"
elif [ "$ARMS" = "$PSET" ]; then
  ok "J1: the shipped fixture's $na predicate calls and the $np in P_ALL are the same set"
else
  printf '%s\n' "$ARMS" > "$W/j1.arms"; printf '%s\n' "$PSET" > "$W/j1.pset"
  bad "J1: called but not in P_ALL [$(comm -23 "$W/j1.arms" "$W/j1.pset" | tr '\n' ' ')], P_ALL but not called [$(comm -13 "$W/j1.arms" "$W/j1.pset" | tr '\n' ' ')]"
fi
set -- $P_ALL; N_ALL=$#

# ------------------------------------------------------------------------------ the mutants
# A mutant is a copy of the WHOLE reconcile directory: apply.sh sources preclassify.sh beside it
# and reads setup-sites.md there, so a lone apply.sh copy refuses to run and reads as a kill.
mutdir() { # <name> -> a fresh dir holding every reconcile/*.sh and *.md
  local d
  d="$(mktemp -d "$W/rec-$1.XXXXXX")" || return 1
  cp "$REC"/*.sh "$REC"/*.md "$d/" || return 1
  chmod +x "$d"/*.sh || return 1
  printf '%s' "$d"
}
apply() { # <file> <old> <new>: exactly one occurrence, else exit 3
  M_OLD="$2" M_NEW="$3" python3 - "$1" <<'PY'
import os, sys
p = sys.argv[1]; old, new = os.environ["M_OLD"], os.environ["M_NEW"]
t = open(p, encoding="utf-8").read()
n = t.count(old)
if n != 1:
    sys.stderr.write("ANCHOR MATCHED %d TIMES, EXPECTED 1\n" % n); sys.exit(3)
open(p, "w", encoding="utf-8").write(t.replace(old, new))
PY
}

POOL=8
SCORER_BOUND=600
VD="$W/verdicts"; mkdir -p "$VD" || { echo "FIXTURE ERROR: cannot create $VD" >&2; exit 2; }
IDX="$W/dispatch.tsv"; : > "$IDX"
NDISP=0

# One scorer: build the shared worlds on <rec-dir>, then every predicate in P_ALL order.
scorer() { # <id> <label> <rec-dir>
  trap - EXIT
  local id="$1" label="$2" sd="$3" s p n=0 dead=""
  s="$W/mut-$id"
  worlds "$s" "$sd" || exit 1
  for p in $P_ALL; do n=$((n + 1)); WHY=""; "p_$p" "$s" || dead="$dead $p"; done
  dead="${dead# }"
  printf '%s\t%s\t%s\n' "$label" "$n" "$dead" > "$VD/$id.tmp" && mv "$VD/$id.tmp" "$VD/$id.v"
}
killtree() { # <pid>: stop it, take its children down first, then it
  local c
  kill -STOP "$1" 2>/dev/null
  for c in $(pgrep -P "$1" 2>/dev/null); do killtree "$c"; done
  kill -9 "$1" 2>/dev/null
}
slot() { # <id> <label> <rec-dir>: the scorer under its watchdog, then the completion sentinel
  trap - EXIT
  local id="$1" s t=0
  ( scorer "$@" ) &
  s=$!
  while kill -0 "$s" 2>/dev/null; do
    if [ "$t" -ge "$SCORER_BOUND" ]; then : > "$VD/$id.timeout"; killtree "$s"; break; fi
    sleep 1; t=$((t + 1))
  done
  wait "$s" 2>/dev/null
  : > "$VD/$id.done"
}
ndone() { set -- "$VD"/*.done; [ -e "$1" ] && echo "$#" || echo 0; }
dispatch() { # <label> <rec-dir> <expected dead set | NONE>
  local id
  while [ "$((NDISP - $(ndone)))" -ge "$POOL" ]; do sleep 1; done
  NDISP=$((NDISP + 1)); id="$(printf '%03d' "$NDISP")"
  printf '%s\t%s\t%s\n' "$id" "$1" "$3" >> "$IDX"
  slot "$id" "$1" "$2" &
}
# THE JUDGMENT, factored so it can be probed: no global is read or written but its arguments and
# the two constants; it prints its one line and returns 0 (ok) or 1 (FAIL).
judge() { # <verdict-stem> <label> <expected dead set | NONE>
  local stem="$1" label="$2" want="$3" lab n dead
  if [ -e "$stem.timeout" ]; then printf '%s: TIMEOUT -- the scorer ran past %ss and was killed; no verdict\n' "$label" "$SCORER_BOUND"; return 1; fi
  if [ ! -f "$stem.v" ]; then printf '%s: NO VERDICT -- the scorer wrote nothing; a lost scorer is never a pass\n' "$label"; return 1; fi
  IFS='	' read -r lab n dead < "$stem.v"
  if [ "$lab" != "$label" ]; then printf '%s: the verdict file carries the label [%s]\n' "$label" "$lab"; return 1; fi
  if [ "$n" != "$N_ALL" ]; then printf '%s: the scorer evaluated %s of %s predicates\n' "$label" "$n" "$N_ALL"; return 1; fi
  if [ "$want" = "NONE" ]; then
    if [ -z "$dead" ]; then printf '%s: every predicate HOLDS on the unmutated copy -- including both sanity gates, which require the pure-apply row and the post-apply stamp to APPEAR -- so each kill below is the mutation'"'"'s\n' "$label"; return 0; fi
    printf '%s: the UNMUTATED copy failed [%s]; every mutant verdict below is about a broken harness\n' "$label" "$dead"; return 1
  fi
  if [ -z "$dead" ]; then printf '%s SURVIVED -- no arm watches the line it edits\n' "$label"; return 1; fi
  if [ "$dead" = "$want" ]; then printf '%s: KILLED by [%s] and nothing else\n' "$label" "$want"; return 0; fi
  printf '%s killed [%s], expected exactly [%s] -- an arm is entangled or does not own this property\n' "$label" "$dead" "$want"; return 1
}
mutant() { # <label> <expected> <old> <new>
  local label="$1" want="$2" d; d="$(mutdir "${label%% *}")" || { bad "$label: FIXTURE BROKEN -- could not copy reconcile/"; return; }
  if ! apply "$d/apply.sh" "$3" "$4"; then
    bad "$label: FIXTURE STALE -- the mutation anchor is not in apply.sh exactly once; re-anchor it, never relax the assertion"; return
  fi
  if cmp -s "$REC/apply.sh" "$d/apply.sh"; then bad "$label: FIXTURE STALE -- the mutated copy is byte-identical"; return; fi
  bash -n "$d/apply.sh" 2>/dev/null || { bad "$label: FIXTURE BROKEN -- the mutated apply.sh does not parse"; return; }
  dispatch "$label" "$d" "$want"
}

# THE UNMUTATED CONTROL. The mutants are scored on a run DYING or a row VANISHING, and a reconcile
# copy that cannot stand up at all produces exactly that. Its verdict must be EMPTY over every
# predicate, and two of those predicates are presence-shaped sanity gates, so a copy that emits
# nothing cannot pass it.
C0="$(mutdir m0)"
if [ -n "$C0" ] && [ -f "$C0/apply.sh" ] && [ -f "$C0/preclassify.sh" ] && [ -f "$C0/emit-report.sh" ] && [ -f "$C0/setup-sites.md" ]; then
  ok "M-pre: the copy carries apply.sh, the preclassify.sh it sources, the emit-report.sh the report is rendered by, and the setup-sites.md it reads"
  dispatch "M0 control (unmutated copy)" "$C0" NONE
else
  bad "M-pre: FIXTURE BROKEN -- the reconcile copy lacks the subject or a sibling"
fi

NL='
'
MV_LINE='  mv "$tmp" "$cons" || { rm -f "$tmp"; return 1; }'
# M1 -- destroy the inode swap, KEEP the temp file. `cat > "$cons"` truncates the SAME inode, which
# is exactly what the redirect did, while the temp still holds the content. The driver corrupts
# itself mid-run, and the gate world's first run is the same self-replacing pull, so it dies there
# too: `gsane` and `diag` fall with `self`, and every finding is true -- the post-apply state the
# gate world needs is never reached. `silent` falls because the second run is driven by the copy
# the first run left half-applied. `rowtext` holds: the row is emitted before the run breaks.
mutant "M1 in-place write, temp kept" "self silent gsane diag" \
  "$MV_LINE" '  cat "$tmp" > "$cons"; rm -f "$tmp"'
# M2 -- never record the self-replacement. The write is untouched, so the run still completes and
# only the row disappears; the gate world's sanity reads the same row and falls with it.
mutant "M2 self-replacement never recorded" "row gsane rowtext" \
  "${NL}  [ -e \"\$cons\" ] && [ \"\$cons\" -ef \"\$SELF_FILE\" ] && self_replaced=1${NL}" "${NL}  :${NL}"
# M3 -- leave the temp in place. The unsplit fixture scored this on `litter` alone and said the
# driver still survives; the full matrix shows it does NOT. `cp` onto an existing file opens it
# with O_TRUNC, the SAME inode, so this is M1's self-corruption as well, and `self silent gsane
# diag` fall for M1's reasons. Every finding is true. `litter` is the one only M3 moves.
mutant "M3 temp never removed" "self silent litter gsane diag" \
  "$MV_LINE" '  cp "$tmp" "$cons"'
# M4 -- put the idempotence claim back on the row. The re-run still refuses with the diagnosis.
mutant "M4 idempotence claim restored" "rowtext" \
  'and its refusal names the procedure that does."' 'and its refusal names the procedure that does. Re-run it — it is idempotent."'
# M5 -- the diagnosis never fires: the match is found and thrown away. The re-run still refuses,
# with the two-cause message a post-apply consumer was actually shown.
mutant "M5 diagnosis never fires" "diag" \
  "${NL}        _ug_at=\"\$_ug_sc\"${NL}" "${NL}        :${NL}"
# M6 -- the diagnosis ALWAYS fires: `_ug_at` is seeded before the records are read, so a report
# stale because upstream moved is called post-apply. The marker world is a stale report too, so it
# is misdiagnosed for the same reason, and both findings are true.
mutant "M6 diagnosis fires on every mismatch" "stale marker" \
  "${NL}      _ug_at=\"\"${NL}" "${NL}      _ug_at=\"\$THEIRS\"${NL}"
# M7 -- THE CARVE-OUT: the post-apply branch reports instead of refusing, and the run proceeds.
# This is the alternative fix that was built and rejected: on a consumer that has already
# `--finish`ed a withheld run by hand, the semantic-merge WORKLIST re-appears and the marker with it.
M7_OLD='        err "the report at ${UNION_REPORT#"${CONSUMER}"/} does not match what the detectors render at this run'"'"'s theirs ($THEIRS) — and the consumer'"'"'s stamp records '
M7_NEW='        say NOTE report-unverified-post-apply "" "the report at ${UNION_REPORT#"${CONSUMER}"/} does not match what the detectors render at this run'"'"'s theirs ($THEIRS) — and the consumer'"'"'s stamp records '
mutant "M7 post-apply re-run let through" "diag" "$M7_OLD" "$M7_NEW"
# M8 -- the v0.493.0 defect: read the in-flight marker's `theirs:` as a second record when the
# stamp does not match. The post-apply world's stamp still matches first, so `diag` holds.
M8_AT='      _ug_sc="$(sed -n '"'"'s/^commit:[[:space:]]*//p'"'"' "$CONSUMER/.claude/.ai-dlc-version" 2>/dev/null | head -1)"'
M8_ADD='      [ -n "$_ug_sc" ] && [ "$(git -C "$DIST" rev-parse "${_ug_sc}:core" 2>/dev/null || true)" = "$_ug_tt" ] || _ug_sc="$(sed -n "s/^theirs:[[:space:]]*//p" "$CONSUMER/.claude/.ai-dlc-applying" 2>/dev/null | head -1)"'
mutant "M8 marker read as a record of a write" "marker" \
  "${M8_AT}${NL}" "${M8_AT}${NL}${M8_ADD}${NL}"

# ------------------------------------------------------------------------------ the reap
wait
nidx="$(grep -c . "$IDX")" || nidx=0
nd="$(ndone)"
if [ "$NDISP" -ge 2 ] && [ "$nidx" -eq "$NDISP" ] && [ "$nd" -eq "$NDISP" ]; then
  ok "MR: $NDISP scorers dispatched, $nidx recorded, $nd completed"
else
  bad "MR: $NDISP scorers dispatched, $nidx recorded, $nd completed -- a scorer was lost or never started"
fi
while IFS='	' read -r id label want; do
  if line="$(judge "$VD/$id" "$label" "$want")"; then ok "$line"; else bad "$line"; fi
  if [ -n "$ROWS" ] && [ -f "$VD/$id.v" ]; then
    IFS='	' read -r _l _n _d < "$VD/$id.v"; printf '%s\t%s\n' "$label" "$_d" >> "$ROWS"
  fi
done < "$IDX"

# THE JUDGMENT, PROBED ON A REAL VERDICT. M1's verdict file is copied aside and judged against a
# scratch counter: its own expected set must PASS (else the probe proves nothing about a judge that
# always fails), a deliberately wrong set must FAIL, the same stem beside a TIMEOUT marker must
# FAIL, and the same stem with the verdict file deleted must FAIL.
pv="$(awk -F'\t' 'index($2, "M1 ") == 1 { print $1; exit }' "$IDX")"
pw="$(awk -F'\t' 'index($2, "M1 ") == 1 { print $3; exit }' "$IDX")"
pl="$(awk -F'\t' 'index($2, "M1 ") == 1 { print $2; exit }' "$IDX")"
if [ -z "$pv" ] || [ ! -f "$VD/$pv.v" ]; then
  bad "MJ: FIXTURE BROKEN -- no M1 verdict file to probe the judgment with"
else
  pd="$(mktemp -d "$W/judge-probe.XXXXXX")" && cp "$VD/$pv.v" "$pd/p.v"
  red=0
  judge "$pd/p" "$pl" "$pw" > /dev/null || red=$((red + 100))
  judge "$pd/p" "$pl" "litter" > /dev/null || red=$((red + 1))
  : > "$pd/p.timeout"
  judge "$pd/p" "$pl" "$pw" > /dev/null || red=$((red + 1))
  rm -f "$pd/p.timeout" "$pd/p.v"
  judge "$pd/p" "$pl" "$pw" > /dev/null || red=$((red + 1))
  if [ "$red" -eq 3 ]; then
    ok "MJ: the judgment passes M1's real verdict against its own set, and FAILS it against a wrong set, beside a TIMEOUT marker, and with the verdict file deleted"
  else
    bad "MJ: the judgment probe scored $red (want 3: real+right ok, real+wrong red, real+timeout red, deleted red; +100 means the right set failed)"
  fi
fi

echo
if [ "$fails" -eq 0 ]; then echo "$NAME: PASS"; exit 0; fi
echo "$NAME: $fails assertion(s) FAILED" >&2
exit 1
