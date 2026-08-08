#!/usr/bin/env bash
# apply-worklist-rows/run.sh — prove a WORKLIST row reaches the operator with its INSTRUCTION,
# and that an ATOMIC sequence emits every step it numbers.
#
# THE TWO DEFECTS THIS FIXTURE EXISTS FOR, both live in apply.sh until v0.311.0, both green
# everywhere, and both found only by RUNNING the script rather than reading it.
#
#   1. `say()` printed THREE fields while eighteen call sites passed FOUR. Every WORKLIST and
#      DECISION detail was computed and thrown away. The operator's row was
#      `WORKLIST<TAB>override-retire<TAB><path>` — no key, no ordering, no reason — while
#      SKILL.md step 7 told the reader to obey a detail field that was never printed.
#
#   2. The per-key loop was `printf '%s' "$keys" | tr ',' '\n' | while read`. `printf '%s'`
#      writes no trailing newline, so the LAST element arrives at EOF, `read` returns non-zero
#      and the body never runs on it. N keys emitted N-1 rows; the one-key case — every keyed
#      supersession core has ever declared — emitted ZERO. The sequence printed only its final
#      `2/2 ... --stamp retire` step while advertising a `1/2 write the key` step that did not
#      exist, which is the exact reverse of the order the block exists to enforce.
#
# WHY NOTHING CAUGHT EITHER. No fixture drove apply.sh's worklist rendering at all. The one
# fixture that greps a WORKLIST row (`apply-drift-after-write`) matches on the subject path,
# which is field 3 and survived both defects. `layer-readopt-gate` asserts the `replaces_with=`
# TOKEN that layer-drift.sh emits — the input to this rendering — and stops there. So the whole
# hand-off from detector to operator was untested end to end.
#
# HOW IT DRIVES THE REAL SCRIPT. apply.sh shells to `$SELF/layer-drift.sh` for its layer rows,
# so a copy of `reconcile/` with a STUB layer-drift makes the worklist a pure function of a TSV
# this file writes. Nothing is stubbed inside apply.sh itself: the rendering under test is the
# shipped code, byte for byte.
set -uo pipefail

# TWO LAYOUTS, and this fixture ships to consumers, so it must resolve in both. install.sh
# splits what shares a parent here: `core/skills/ai-dlc-update/reconcile/` in the distribution
# becomes `.claude/skills/ai-dlc-update/reconcile/` in a consumer. Both roots are the SAME three
# levels up from this file, so the discriminator is which of the two paths carries apply.sh --
# not a walk of a different depth. Resolved from `$0`, never from the process cwd, so the verdict
# does not depend on where the suite runner happens to stand.
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
if   [ -n "$ROOT" ] && [ -f "$ROOT/core/skills/ai-dlc-update/reconcile/apply.sh" ]; then
  REC="$ROOT/core/skills/ai-dlc-update/reconcile"
elif [ -n "$ROOT" ] && [ -f "$ROOT/.claude/skills/ai-dlc-update/reconcile/apply.sh" ]; then
  REC="$ROOT/.claude/skills/ai-dlc-update/reconcile"
else
  echo "apply-worklist-rows: FIXTURE BROKEN — reconcile/apply.sh not found in either layout" >&2
  exit 2
fi
W="$(mktemp -d)"
trap 'rm -rf "$W"' EXIT

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

echo "apply-worklist-rows:"



# --- the synthetic pull -------------------------------------------------------------------
# Two throwaway git repos. apply.sh needs both to resolve refs; neither carries a core/ tree,
# so its pure-apply phase has nothing to write and the only rows are the ones under test.
mk_repo() { mkdir -p "$1" && git -C "$1" init -q . && echo seed > "$1/f" \
  && git -C "$1" add -A >/dev/null 2>&1 \
  && git -C "$1" -c user.email=f@x -c user.name=f commit -qm seed >/dev/null 2>&1; }
mk_repo "$W/dist" || { bad "FIXTURE BROKEN — could not build the dist repo"; exit 2; }
mk_repo "$W/cons" || { bad "FIXTURE BROKEN — could not build the consumer repo"; exit 2; }

OVR='.claude/skills/ai-dlc/overrides/one-key.md'

# Build a reconcile directory: every shipped script, with layer-drift replaced by a stub that
# emits ONE keyed supersession. One key is the case that emitted zero rows, and it is also the
# only shape core has ever declared with a key.
build_rec() { # build_rec <dir>
  mkdir -p "$1" && cp "$REC"/*.sh "$1"/ || return 1
  cat > "$1/layer-drift.sh" <<STUB
#!/usr/bin/env bash
printf 'OVERRIDE-SUPERSEDED\t${OVR}\tsteps/w.md\treplaces_with=AI_DLC_ONE_KEY :: core 0.1.0 provides what this entry was written to work around.\n'
STUB
  chmod +x "$1/layer-drift.sh"
}

# Rows for the entry under test, one per line, TAB-separated as apply.sh prints them.
retire_rows() { # retire_rows <rec-dir>
  bash "$1/apply.sh" "$W/dist" HEAD "$W/cons" HEAD 2>/dev/null \
    | awk -F'\t' -v o="$OVR" '$1=="WORKLIST" && $2=="override-retire" && $3==o'
}

build_rec "$W/rec" || { bad "FIXTURE BROKEN — could not stage reconcile/"; echo; echo "apply-worklist-rows: FIXTURE BROKEN" >&2; exit 2; }

ROWS="$(retire_rows "$W/rec")"
N_ROWS="$(printf '%s\n' "$ROWS" | grep -c . || true)"

# --- SANITY: the harness produced rows at all ----------------------------------------------
# Both assertions below read this output. A run that emitted nothing — a stub apply.sh could
# not source, a changed row vocabulary — would satisfy neither by failing, which is the state
# this arm exists to separate from a real regression.
if [ "$N_ROWS" -ge 1 ]; then
  ok "the driven apply.sh emitted override-retire rows for the seeded supersession ($N_ROWS)"
else
  bad "FIXTURE BROKEN — apply.sh emitted NO override-retire row; the two assertions below would be vacuous"
  echo; echo "apply-worklist-rows: FIXTURE BROKEN" >&2; exit 2
fi

# --- ASSERTION 1: the ATOMIC sequence emits every step it numbers ---------------------------
# One declared key means two steps: write the key, then retire. The count is what defect 2
# broke, and it is deliberately insensitive to whether the detail field prints — so a
# regression in `say()` cannot also red this arm.
assert_count() { # assert_count <rows> <label>
  local n; n="$(printf '%s\n' "$1" | grep -c . || true)"
  [ "$n" -eq 2 ]
}
if assert_count "$ROWS"; then
  ok "a one-key supersession emits BOTH numbered steps (1/2 write the key, 2/2 retire)"
else
  bad "the ATOMIC sequence emitted ${N_ROWS} row(s), not 2 — a step it numbers is never printed, and the retire is the one that survives"
fi

# --- ASSERTION 2: a row carries its instruction ---------------------------------------------
# Read the LAST step's detail, not the first: the last row is emitted under BOTH defects, so
# this arm moves only when the detail field itself is lost. Asserting a POSITIVE outcome — the
# field is present and names the ordered step — rather than the absence of an old shape.
last_detail() { printf '%s\n' "$1" | awk -F'\t' 'NF>=4 {d=$4} END {print d}'; }
D_LAST="$(last_detail "$ROWS")"
case "$D_LAST" in
  *"ATOMIC"*) ok "  and the row carries its detail — the step the operator must perform is printed, not just its subject" ;;
  "")         bad "the worklist row printed NO detail field at all: the key to write, the ordering constraint and the reason were computed and discarded, and SKILL.md tells the reader to obey a field that is not there" ;;
  *)          bad "the detail field is present but does not name the ordered step: ${D_LAST:0:70}" ;;
esac

# --- MUTANTS -------------------------------------------------------------------------------
# Each is a COPY of the whole reconcile directory (apply.sh loads map_consumer() from its
# sibling preclassify.sh, so a lone script copy dies before printing anything), guarded by
# `cmp -s` so a sed that matched nothing cannot pass as a mutation, and aimed at ONE assertion.
#
# THE UNMUTATED CONTROL IS NOT OPTIONAL HERE. Both mutants below are copies into fresh
# directories, and a copy that cannot run emits nothing — which is indistinguishable from the
# mutant being killed. The control proves the copying itself is sound.
build_rec "$W/mut-ctl" && cp "$REC/apply.sh" "$W/mut-ctl/apply.sh"
CTL_ROWS="$(retire_rows "$W/mut-ctl")"
if assert_count "$CTL_ROWS" && case "$(last_detail "$CTL_ROWS")" in *ATOMIC*) true ;; *) false ;; esac; then
  ok "CONTROL: an unmutated copy in a fresh directory reproduces both outcomes (so a mutant's silence is the mutation, not the copy)"
else
  bad "CONTROL: the unmutated copy did not reproduce the shipped behaviour — every mutant verdict below is unreadable"
fi

# MUTANT 1 — say() back to three fields. Assertion 2 must go red; assertion 1 must NOT, because
# the row COUNT does not depend on the field count.
build_rec "$W/mut1"
sed "s@^  if \[ -n \"\${4:-}\" \]; then printf '%s\\\\t%s\\\\t%s\\\\t%s\\\\n' \"\$1\" \"\$2\" \"\${3:-}\" \"\$4\"@  if false; then printf '%s\\\\t%s\\\\t%s\\\\n' \"\$1\" \"\$2\" \"\${3:-}\"@" \
  "$REC/apply.sh" > "$W/mut1/apply.sh"
if cmp -s "$REC/apply.sh" "$W/mut1/apply.sh"; then
  bad "MUTANT 1 did not apply — the say() spelling it targets has changed, so this mutant proves nothing"
else
  M1="$(retire_rows "$W/mut1")"
  m1_detail="$(last_detail "$M1")"
  if [ -z "$m1_detail" ]; then
    ok "MUTANT 1 (say drops the 4th field): the detail assertion goes red — it is what holds the instruction in the row"
  else
    bad "MUTANT 1 SURVIVED: the detail is still present with say() printing three fields, so assertion 2 is not testing the field"
  fi
  if assert_count "$M1"; then
    ok "  and the COUNT assertion stays green under it — the two arms are not entangled"
  else
    bad "  MUTANT 1 also killed the count assertion: the two arms are entangled and one of them proves nothing on its own"
  fi
fi

# MUTANT 2 — the key loop back to `printf | while read`, which drops its last element. Assertion
# 1 must go red; assertion 2 must NOT, because the surviving row is the one whose detail is read.
build_rec "$W/mut2"
sed "s@^    done <<< \"\$(printf '%s' \"\$env_key\" | tr ',' '\\\\n')\"@    done < <(printf '%s' \"\$env_key\" | tr ',' '\\\\n')@" \
  "$REC/apply.sh" > "$W/mut2/apply.sh"
if cmp -s "$REC/apply.sh" "$W/mut2/apply.sh"; then
  bad "MUTANT 2 did not apply — the here-string spelling it targets has changed, so this mutant proves nothing"
else
  M2="$(retire_rows "$W/mut2")"
  if assert_count "$M2"; then
    bad "MUTANT 2 SURVIVED: the sequence still emits both steps without the trailing newline, so assertion 1 is not testing the drop"
  else
    ok "MUTANT 2 (unterminated key stream): the count assertion goes red — the write-the-key step is the one that disappears"
  fi
  case "$(last_detail "$M2")" in
    *ATOMIC*) ok "  and the DETAIL assertion stays green under it — the two arms are not entangled" ;;
    *)        bad "  MUTANT 2 also killed the detail assertion: the two arms are entangled and one of them proves nothing on its own" ;;
  esac
fi

echo ""
if [ "$fails" -eq 0 ]; then echo "apply-worklist-rows: PASS"; exit 0; fi
echo "apply-worklist-rows: FAIL ($fails)"; exit 1
