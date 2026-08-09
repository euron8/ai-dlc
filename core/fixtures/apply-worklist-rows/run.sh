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
OVR_M='.claude/skills/ai-dlc/overrides/multi-key.md'
OVR_A='.claude/skills/ai-dlc/overrides/multi-adopted.md'
OVR_J="overrides/steps__w__adjudicated.md"
ANCHOR='steps/w.md#4a. Close-Out Sweep'

# Build a reconcile directory: every shipped script, with layer-drift replaced by a stub emitting
# the three detail shapes whose rendering differs.
#
#   one-key       `replaces_with=` only          -> 1/2 write the key, 2/2 --stamp retire
#   multi-key     `replaces_with=` + `retire_anchor=` -> 1/2 write the key, 2/2 NARROW shadows:
#   multi-adopted `retire_anchor=` alone         -> one row, NARROW shadows:, no ATOMIC sequence
#
# One key is the case that emitted zero rows, and it is also the only shape core has ever
# declared with a key. `multi-adopted` is the shape that makes the token parse POSITIONAL: read
# with the old `${detail#replaces_with=}` + equality guard it yields `env_key=retire_anchor=<...>`
# and instructs the operator to write that string into settings.json as an environment key.
build_rec() { # build_rec <dir>
  mkdir -p "$1" && cp "$REC"/*.sh "$1"/ || return 1
  # THE STUB CARRIES `ADJ_ROW_TOKEN` BECAUSE THE REAL SCRIPT DECLARES IT. apply.sh resolves
  # that declaration from its sibling rather than restating the literal (I86), and a double
  # that omits a field the original declares is an incomplete double: without this line
  # apply.sh fails closed on every row here and all three assertions go vacuous at once.
  cat > "$1/layer-drift.sh" <<STUB
#!/usr/bin/env bash
ADJ_ROW_TOKEN="adjudicated"
printf 'OVERRIDE-SUPERSEDED\t${OVR}\tsteps/w.md\treplaces_with=AI_DLC_ONE_KEY :: core 0.1.0 provides what this entry was written to work around.\n'
printf 'OVERRIDE-SUPERSEDED\t${OVR_M}\tsteps/w.md\treplaces_with=AI_DLC_ONE_KEY :: retire_anchor=${ANCHOR} :: core 0.1.0 provides what this entry'"'"'s shadow was written to work around.\n'
printf 'OVERRIDE-SUPERSEDED\t${OVR_A}\tsteps/w.md\tretire_anchor=${ANCHOR} :: core 0.1.0 ADOPTED what this entry says under that anchor.\n'
printf 'OVERRIDE-SUPERSEDED\t${OVR_J}\tsteps/w.md\tadjudicated=still-additive :: replaces_with=AI_DLC_ONE_KEY :: retire_anchor=${ANCHOR} :: core 0.1.0 provides what this entry was written to work around.\n'
STUB
  chmod +x "$1/layer-drift.sh"
}

# Rows for ONE entry, one per line, TAB-separated as apply.sh prints them. The whole manifest is
# regenerated per call rather than cached, so a mutant is always read from its own run.
rows_for() { # rows_for <rec-dir> <entry>
  bash "$1/apply.sh" "$W/dist" HEAD "$W/cons" HEAD 2>/dev/null \
    | awk -F'\t' -v o="$2" '$1=="WORKLIST" && $2=="override-retire" && $3==o'
}
retire_rows() { rows_for "$1" "$OVR"; }

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

# --- ASSERTION 3: a superseded ANCHOR is narrowed, never retired -----------------------------
#
# `readopt-override.sh --stamp retire` DELETES THE OVERRIDE FILE; there is no per-anchor retire.
# When core supersedes ONE anchor of a multi-anchor `shadows:`, an operator obeying a retire row
# throws away the anchors core did NOT supersede, and every section they shadowed silently
# reverts to core. This is the one row in the file whose failure direction is destroying consumer
# text, so it is asserted on the RENDERED row rather than on the token layer-drift emits.
M_ROWS="$(rows_for "$W/rec" "$OVR_M")"
M_LAST="$(last_detail "$M_ROWS")"
case "$M_LAST" in
  *"remove the anchor"*"$ANCHOR"*) ok "a multi-anchor supersession's LAST step narrows shadows: and names the anchor" ;;
  *"--stamp retire"*)              bad "the last step is still a retire stamp on a multi-anchor entry — obeying it deletes the anchors core did NOT supersede" ;;
  *)                               bad "the multi-anchor last step names no action this fixture recognises: ${M_LAST:0:80}" ;;
esac
case "$M_LAST" in
  *"NOT --stamp retire"*) ok "  and it says outright that the retire stamp is the wrong action here" ;;
  *)                      bad "  the row narrows the shadow but never warns off --stamp retire, which is the instruction the operator already knows" ;;
esac

# --- ASSERTION 4: the token prefix is parsed positionally, not searched for -------------------
# An env-LESS multi-anchor detail leads with `retire_anchor=`. Read by the old
# `${detail#replaces_with=}` + "equals the whole detail" guard, that yields
# `env_key=retire_anchor=steps/w.md#4a. Close-Out Sweep` and renders a 1/2 ATOMIC row telling the
# operator to write that string into settings.json "env" as a key. There is no such key.
A_ROWS="$(rows_for "$W/rec" "$OVR_A")"
if [ "$(printf '%s\n' "$A_ROWS" | grep -c 'ATOMIC' || true)" -eq 0 ]; then
  ok "an env-less supersession renders NO ATOMIC sequence — there is no key to write, so there is no order to enforce"
else
  bad "an env-less detail rendered an ATOMIC sequence: the token after the prefix was parsed as an environment key, and the operator is told to write it into settings.json"
fi
case "$(last_detail "$A_ROWS")" in
  *"remove the anchor"*"$ANCHOR"*) ok "  and its single row still narrows shadows: rather than retiring the entry" ;;
  *)                               bad "  the env-less multi-anchor row does not narrow the shadow: $(last_detail "$A_ROWS" | cut -c1-80)" ;;
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

# MUTANT 3 — drop the `retire_anchor=` branch, so the last step is a retire stamp again.
# Assertion 3 must go red; assertions 1 and 2 must NOT, because the one-key entry carries no
# token and its two rows are untouched.
build_rec "$W/mut3"
sed 's@^    retire_anchor=\*) drop_anchor="\${det_rest#retire_anchor=}"; drop_anchor="\${drop_anchor%% ::\*}" ;;@    retire_anchor=*) : ;;@' \
  "$REC/apply.sh" > "$W/mut3/apply.sh"
if cmp -s "$REC/apply.sh" "$W/mut3/apply.sh"; then
  bad "MUTANT 3 did not apply — the retire_anchor= parse it targets has been respelled, so this mutant proves nothing"
else
  case "$(last_detail "$(rows_for "$W/mut3" "$OVR_M")")" in
    *"--stamp retire"*) ok "MUTANT 3 (retire_anchor= unparsed): the multi-anchor row reverts to a retire stamp — the token is what redirects the action" ;;
    *)                  bad "MUTANT 3 SURVIVED: the row still narrows the shadow without parsing the token, so assertion 3 is not testing the parse" ;;
  esac
  M3_ONE="$(rows_for "$W/mut3" "$OVR")"
  if assert_count "$M3_ONE" && case "$(last_detail "$M3_ONE")" in *ATOMIC*) true ;; *) false ;; esac; then
    ok "  and the one-key entry's count and detail are untouched by it — the arms are not entangled"
  else
    bad "  MUTANT 3 also moved the one-key entry's rows: assertions 1 and 2 are entangled with the token parse"
  fi
fi

# MUTANT 4 — the token parse back to the un-anchored `${detail#...}` + equality guard. Assertion 4
# must go red; assertion 3 must NOT, because the multi-KEY detail does lead with `replaces_with=`
# and still parses correctly under the old form.
build_rec "$W/mut4"
sed 's@^  case "\$detail" in$@  env_key="${detail#replaces_with=}"; env_key="${env_key%% ::*}"; [ "$env_key" = "$detail" ] \&\& env_key=""; case "" in@' \
  "$REC/apply.sh" > "$W/mut4/apply.sh"
if cmp -s "$REC/apply.sh" "$W/mut4/apply.sh"; then
  bad "MUTANT 4 did not apply — the env_key prefix case it targets has been respelled, so this mutant proves nothing"
else
  if [ "$(rows_for "$W/mut4" "$OVR_A" | grep -c 'ATOMIC' || true)" -ge 1 ]; then
    ok "MUTANT 4 (env_key read without its prefix): the env-less row renders an ATOMIC sequence naming a key that does not exist"
  else
    bad "MUTANT 4 SURVIVED: the env-less detail stayed key-less without the prefix guard, so assertion 4 is not testing it"
  fi
  case "$(last_detail "$(rows_for "$W/mut4" "$OVR_M")")" in
    *"remove the anchor"*) ok "  and the multi-KEY row still narrows the shadow under it — the arms are not entangled" ;;
    *)                     bad "  MUTANT 4 also broke the multi-key row: assertions 3 and 4 are entangled" ;;
  esac
fi

# --- ASSERTION 5: a row carrying a RECORDED VERDICT emits no retire steps -------------------
# PC-S327: apply.sh built this worklist from layer-drift's rows and never asked whether the
# project had already decided. layer-drift.sh now writes `adjudicated=<verdict>` into the row
# when a verdict exists for that digest, and apply.sh must emit a NOTE instead of the ATOMIC
# retire sequence. Acting on those steps would UNDO a decision, not complete one — on the
# reference consumer, 119 consumer-only lines including a live closure guard.
#
# BOTH DIRECTIONS IN ONE ARM, because suppression that cannot be turned off is an exemption:
# the three rows above carry no token and must still produce their retire rows, which the
# assertions above already require. This one requires the fourth to produce none.
ADJ_ROWS="$(rows_for "$W/rec" "$OVR_J")"
ADJ_N="$(printf '%s\n' "$ADJ_ROWS" | grep -c . || true)"
ADJ_NOTE="$(bash "$W/rec/apply.sh" "$W/dist" HEAD "$W/cons" HEAD 2>/dev/null \
  | awk -F'\t' -v o="$OVR_J" '$1=="NOTE" && $2=="override-adjudicated" && $3==o' | grep -c . || true)"
if [ "$ADJ_N" -eq 0 ] && [ "$ADJ_NOTE" -ge 1 ]; then
  ok "a supersession row carrying a recorded verdict emits a NOTE and NO retire steps"
else
  bad "an adjudicated supersession row emitted $ADJ_N retire row(s) and $ADJ_NOTE note(s) — apply.sh is prescribing work over a recorded verdict (PC-S327)"
fi

echo ""
if [ "$fails" -eq 0 ]; then echo "apply-worklist-rows: PASS"; exit 0; fi
echo "apply-worklist-rows: FAIL ($fails)"; exit 1
