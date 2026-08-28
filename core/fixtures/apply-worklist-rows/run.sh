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
OVR_JR="overrides/steps__w__adjudicated_act_twin.md"
OVR_KR="overrides/steps__w__adjudicated_act_key.md"
OVR_KC="overrides/steps__w__adjudicated_act_contra.md"
OVR_AR="overrides/steps__w__adjudicated_act_anchor.md"
ANCHOR='steps/w.md#4a. Close-Out Sweep'

# --- WHAT THE STUB HAS TO DECLARE, DERIVED FROM THE REAL SCRIPT --------------------------------
# apply.sh resolves the adjudication row's vocabulary from its SIBLING layer-drift.sh rather than
# holding literals (I86), and it fails closed when it cannot. So a stub that names only the
# declarations that existed when this fixture was written is an INCOMPLETE double: apply.sh exits
# 2 on every row and all the assertions below go vacuous in one step. That is measured, not
# hypothetical -- this file read `FIXTURE BROKEN` the moment `ADJ_KEEP_VERDICT` joined
# `ADJ_ROW_TOKEN`. Copying every PLAIN-LITERAL declaration verbatim means the next one arrives on
# its own. Literals only: the computed ones (`ADJ_VERDICTS` reads the schema out of a git ref)
# cannot run in a stub with no repository behind it, and apply.sh does not read them.
ADJ_DECLS="$(grep -E '^ADJ_[A-Z][A-Za-z0-9_]*="[^"$`]*"$' "$REC/layer-drift.sh" || true)"
ADJ_TOK="$(printf '%s\n' "$ADJ_DECLS" | sed -n 's/^ADJ_ROW_TOKEN="\([^"]*\)".*/\1/p' | head -1)"
ADJ_KEEP="$(printf '%s\n' "$ADJ_DECLS" | sed -n 's/^ADJ_KEEP_VERDICT="\([^"]*\)".*/\1/p' | head -1)"

# THE TWO VERDICTS THAT AUTHORIZE THE REMEDY, as seed input. The vocabulary is owned by
# `core/schemas/layer-adjudication-register.json`'s enum and bound to it by `layer-adjudication-tier`
# and by the distribution's own vocabulary join; nothing here restates it. These are the two members that
# are NOT the keep disposition, and the control below is what makes them so -- seeding a literal
# that silently became the keep verdict would leave every act-direction arm asserting the
# suppression it exists to forbid.
V_ACT1='retire'
V_ACT2='contradicts-core'

# CONTROLS ON THE SEED ITSELF, BEFORE ANY ROW IS READ. Each of these failing silently would make a
# whole direction of the fixture vacuous rather than red.
if [ -n "$ADJ_TOK" ] && [ -n "$ADJ_KEEP" ]; then
  ok "the stub's ADJ_ declarations are copied from the real layer-drift.sh (token '$ADJ_TOK', keep verdict '$ADJ_KEEP')"
else
  bad "FIXTURE BROKEN — could not resolve ADJ_ROW_TOKEN ('$ADJ_TOK') and/or ADJ_KEEP_VERDICT ('$ADJ_KEEP') from $REC/layer-drift.sh; apply.sh fails closed without them and every arm below would report on a run that emitted nothing"
  echo; echo "apply-worklist-rows: FIXTURE BROKEN" >&2; exit 2
fi
if [ "$V_ACT1" != "$ADJ_KEEP" ] && [ "$V_ACT2" != "$ADJ_KEEP" ]; then
  ok "  and the two act-direction seeds ('$V_ACT1', '$V_ACT2') are both DISTINCT from it — the arms below can tell the branch apart"
else
  bad "FIXTURE BROKEN — an act-direction seed equals the keep verdict '$ADJ_KEEP', so the arms requiring the retire sequence are asserting against the suppression path"
  echo; echo "apply-worklist-rows: FIXTURE BROKEN" >&2; exit 2
fi

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
  # THE STUB CARRIES THE REAL SCRIPT'S `ADJ_` DECLARATIONS, COPIED. See the derivation above for
  # why they are copied rather than written out here.
  #
  # THE FOUR ADJUDICATED ROWS DIFFER IN THE VERDICT AND IN NOTHING ELSE THAT MATTERS. `${OVR_J}`
  # and `${OVR_JR}` are byte-twins apart from the verdict and the subject path, which is what lets
  # the differential below assert that the branch reads the verdict rather than the token.
  #
  #   ${OVR_J}   keep verdict, key + anchor       -> NOTE, no steps
  #   ${OVR_JR}  act verdict,  key + anchor       -> 1/2 write the key, 2/2 NARROW shadows:
  #   ${OVR_KR}  act verdict,  key only           -> 1/2 write the key, 2/2 --stamp retire
  #   ${OVR_KC}  other act verdict, key only      -> same, and the row cites the verdict
  #   ${OVR_AR}  act verdict,  anchor only        -> one row, NARROW shadows:, no ATOMIC sequence
  #
  # `${OVR_AR}` is the destructive shape. The adjudication token is an ordered prefix AHEAD of
  # `replaces_with=`/`retire_anchor=`, so an act branch that emits the sequence without stripping
  # it leaves both later tokens unmatched, lands in the no-key/no-anchor arm and prescribes
  # `--stamp retire` -- which deletes the whole override file when core superseded ONE anchor.
  cat > "$1/layer-drift.sh" <<STUB
#!/usr/bin/env bash
${ADJ_DECLS}
printf 'OVERRIDE-SUPERSEDED\t${OVR}\tsteps/w.md\treplaces_with=AI_DLC_ONE_KEY :: core 0.1.0 provides what this entry was written to work around.\n'
printf 'OVERRIDE-SUPERSEDED\t${OVR_M}\tsteps/w.md\treplaces_with=AI_DLC_ONE_KEY :: retire_anchor=${ANCHOR} :: core 0.1.0 provides what this entry'"'"'s shadow was written to work around.\n'
printf 'OVERRIDE-SUPERSEDED\t${OVR_A}\tsteps/w.md\tretire_anchor=${ANCHOR} :: core 0.1.0 ADOPTED what this entry says under that anchor.\n'
printf 'OVERRIDE-SUPERSEDED\t${OVR_J}\tsteps/w.md\t${ADJ_TOK}=${ADJ_KEEP} :: replaces_with=AI_DLC_ONE_KEY :: retire_anchor=${ANCHOR} :: core 0.1.0 provides what this entry was written to work around.\n'
printf 'OVERRIDE-SUPERSEDED\t${OVR_JR}\tsteps/w.md\t${ADJ_TOK}=${V_ACT1} :: replaces_with=AI_DLC_ONE_KEY :: retire_anchor=${ANCHOR} :: core 0.1.0 provides what this entry was written to work around.\n'
printf 'OVERRIDE-SUPERSEDED\t${OVR_KR}\tsteps/w.md\t${ADJ_TOK}=${V_ACT1} :: replaces_with=AI_DLC_ONE_KEY :: core 0.1.0 provides what this entry was written to work around.\n'
printf 'OVERRIDE-SUPERSEDED\t${OVR_KC}\tsteps/w.md\t${ADJ_TOK}=${V_ACT2} :: replaces_with=AI_DLC_ONE_KEY :: core 0.1.0 provides what this entry was written to work around.\n'
printf 'OVERRIDE-SUPERSEDED\t${OVR_AR}\tsteps/w.md\t${ADJ_TOK}=${V_ACT1} :: retire_anchor=${ANCHOR} :: core 0.1.0 ADOPTED what this entry says under that anchor.\n'
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
# The COUNT of override-adjudicated NOTE rows for one entry, from the same driven run.
notes_for() { # notes_for <rec-dir> <entry>
  bash "$1/apply.sh" "$W/dist" HEAD "$W/cons" HEAD 2>/dev/null \
    | awk -F'\t' -v o="$2" '$1=="NOTE" && $2=="override-adjudicated" && $3==o' | grep -c . || true
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
ADJ_NOTE="$(notes_for "$W/rec" "$OVR_J")"
if [ "$ADJ_N" -eq 0 ] && [ "$ADJ_NOTE" -ge 1 ]; then
  ok "a KEEP verdict ('$ADJ_KEEP') emits a NOTE and NO retire steps"
else
  bad "an adjudicated supersession row carrying the KEEP verdict emitted $ADJ_N retire row(s) and $ADJ_NOTE note(s) — apply.sh is prescribing work over a recorded verdict (PC-S327)"
fi

# --- ASSERTION 6: an ACT verdict emits the sequence the operator recorded it to authorize ------
#
# PC-S307, the mirror of the arm above and produced by its fix. That fix keyed the suppression on
# the token's PRESENCE, so it fired for every member of the vocabulary: `adj_v` was extracted and
# then used for nothing but interpolation into the NOTE's own text, which asserts "acting on them
# would undo a decision, not complete one" -- a sentence that is true of the keep verdict alone.
# Recording the HONEST verdict was therefore what made the remedy unreachable, and the reference
# consumer hit it live on its 0.427.0 -> 0.430.1 pull.
#
# KEYED ON THE ROWS, NEVER ON A SPELLING. Which name the branch tests, and whether it tests a
# literal or a resolved declaration, is not this fixture's business: a grep for a verdict name in
# apply.sh passes against a mutant that mentions it in a comment and branches wrongly. What is
# asserted here is which rows reach the operator for which verdict.
assert_seq() { # assert_seq <subject> <expected-last-action-substring> <label>
  local rows n first last
  rows="$(rows_for "$W/rec" "$1")"
  n="$(printf '%s\n' "$rows" | grep -c . || true)"
  last="$(last_detail "$rows")"
  first="$(printf '%s\n' "$rows" | awk -F'\t' 'NF>=4 {print $4; exit}')"
  if [ "$n" -ne 2 ]; then
    bad "$3: the ATOMIC sequence emitted ${n} row(s), not 2 — a recorded verdict that AUTHORIZES the retire is suppressing the steps it authorizes (PC-S307)"
    return
  fi
  ok "$3: both numbered steps are emitted over the recorded verdict"
  case "$first" in
    "1/2 ATOMIC"*"AI_DLC_ONE_KEY"*) ok "  and step 1/2 is the key write, so the sequence still leads with the write" ;;
    *)                              bad "  step 1/2 is not the key write: ${first:0:80}" ;;
  esac
  case "$last" in
    "2/2 ATOMIC"*"$2"*) ok "  and step 2/2 — the LAST step — is the ${2:0:24}…, which is the order the block exists to enforce" ;;
    *"$2"*)             bad "  the expected last action appears but not as the numbered final step: ${last:0:80}" ;;
    *)                  bad "  the last step is not the expected action: ${last:0:90}" ;;
  esac
  case "$first" in
    *"--stamp retire"*|*"remove the anchor"*)
      bad "  the FIRST step already carries the destructive action — stamping before the key is written re-imposes the core constraint and reds the next gate" ;;
    *) ok "  and no earlier step carries it — the retire is LAST, not merely present" ;;
  esac
}
assert_seq "$OVR_KR" "--stamp retire"                "a '$V_ACT1' verdict on a keyed supersession"
assert_seq "$OVR_KC" "--stamp retire"                "a '$V_ACT2' verdict on a keyed supersession"
assert_seq "$OVR_JR" "remove the anchor \`$ANCHOR\`" "a '$V_ACT1' verdict on a MULTI-ANCHOR supersession"

# --- ASSERTION 7: the act branch CITES the verdict as the authorization ------------------------
# Asserted on the `$V_ACT2` subject alone, deliberately: `--stamp retire` contains the string
# `$V_ACT1`, so that subject cannot tell a citation from the action's own name.
case "$(last_detail "$(rows_for "$W/rec" "$OVR_KC")")" in
  *"$V_ACT2"*) ok "  and the row NAMES the recorded verdict — the operator can see the steps are the decision being carried out, not the pull ignoring it" ;;
  *)           bad "  the emitted sequence never mentions the verdict that authorized it, so it is indistinguishable from a pull that never read the register" ;;
esac

# --- ASSERTION 8: the token is STRIPPED before the positional parse ----------------------------
#
# THE ONE DIRECTION HERE WHOSE FAILURE DESTROYS CONSUMER TEXT. `${ADJ_TOK}=` is an ordered prefix
# sitting AHEAD of `replaces_with=`/`retire_anchor=`, and those are parsed positionally. An act
# branch that falls through with the token still attached matches neither, so an env-less
# multi-anchor supersession lands in the no-key/no-anchor arm and the operator is handed
# `--stamp retire` — which deletes the whole override file, including the anchors core did NOT
# supersede. This failure cannot exist while the branch always suppresses, so it arrives WITH the
# fix and nothing before now could have caught it.
AR_ROWS="$(rows_for "$W/rec" "$OVR_AR")"
if [ "$(printf '%s\n' "$AR_ROWS" | grep -c 'ATOMIC' || true)" -eq 0 ]; then
  ok "an adjudicated env-LESS supersession renders NO ATOMIC sequence — the token did not parse as an environment key"
else
  bad "an adjudicated env-less detail rendered an ATOMIC sequence: the adjudication token was read as a key and the operator is told to write it into settings.json"
fi
case "$(last_detail "$AR_ROWS")" in
  *"remove the anchor"*"$ANCHOR"*) ok "  and its single row narrows shadows: rather than retiring the entry" ;;
  *"--stamp retire"*)              bad "  an adjudicated env-less multi-anchor row prescribes --stamp retire: the adjudication prefix was not stripped, retire_anchor= never matched, and obeying this row DELETES the anchors core did not supersede" ;;
  "")                              bad "  the adjudicated env-less multi-anchor supersession emitted NO row at all — the verdict suppressed the narrowing it authorized (PC-S307)" ;;
  *)                               bad "  the adjudicated env-less row names no action this fixture recognises: $(last_detail "$AR_ROWS" | cut -c1-90)" ;;
esac

# --- ASSERTION 9: the DIFFERENTIAL, which is what makes the arms above about the VERDICT --------
# `$OVR_J` and `$OVR_JR` carry the same key, the same anchor and the same prose; they differ in
# the verdict alone. Asserting the two row sets DIFFER is the one arm here that cannot be
# satisfied by any implementation reading the token's presence, whatever it spells its branch,
# and it is checked against the seeds actually built rather than assumed.
if [ "$ADJ_N" -eq 0 ] && [ "$(printf '%s\n' "$(rows_for "$W/rec" "$OVR_JR")" | grep -c . || true)" -eq 2 ]; then
  ok "two rows identical but for the verdict produce DIFFERENT row sets (0 steps vs 2) — the branch reads the verdict, not the token's presence"
else
  bad "two rows identical but for the verdict produced the SAME outcome — apply.sh is matching the token's presence, so the recorded verdict changes nothing (PC-S307)"
fi

# --- ASSERTION 10: the un-adjudicated baseline acquires no NOTE --------------------------------
# The mirror of assertion 5. A branch that emits its NOTE outside the token arm tells the operator
# a verdict was recorded for a subject the register has never seen.
BASE_NOTES=$(( $(notes_for "$W/rec" "$OVR") + $(notes_for "$W/rec" "$OVR_M") + $(notes_for "$W/rec" "$OVR_A") ))
if [ "$BASE_NOTES" -eq 0 ]; then
  ok "the three token-LESS subjects acquire no override-adjudicated NOTE — the note is a property of the row, not of the run"
else
  bad "$BASE_NOTES token-less subject(s) were reported as adjudicated: apply.sh is claiming a recorded verdict for a subject with none"
fi

# --- MUTANT 5 — the keep branch stops suppressing. Assertion 5 must go red; the act-direction
# arms must NOT, because they never took that path.
build_rec "$W/mut5"
sed 's@^      if \[ "\$adj_v" = "\$ADJ_KEEP_VERDICT" \]; then$@      if false; then@' \
  "$REC/apply.sh" > "$W/mut5/apply.sh"
if cmp -s "$REC/apply.sh" "$W/mut5/apply.sh"; then
  bad "MUTANT 5 did not apply — the keep-verdict branch it targets is spelled differently or is not there, so this mutant proves nothing"
else
  if [ "$(printf '%s\n' "$(rows_for "$W/mut5" "$OVR_J")" | grep -c . || true)" -ge 1 ]; then
    ok "MUTANT 5 (the keep branch never taken): the KEEP verdict is handed retire steps — assertion 5 is testing the suppression, not the presence of a NOTE"
  else
    bad "MUTANT 5 SURVIVED: the keep verdict emitted no steps with its branch disabled, so assertion 5 would pass against an implementation that suppresses unconditionally"
  fi
  if [ "$(printf '%s\n' "$(rows_for "$W/mut5" "$OVR_KR")" | grep -c . || true)" -eq 2 ]; then
    ok "  and the act-direction rows are untouched by it — the two directions are not entangled"
  else
    bad "  MUTANT 5 also moved the act-direction rows: assertions 5 and 6 are entangled and one of them proves nothing on its own"
  fi
fi

# --- MUTANT 6 — the PC-S307 defect restored, with the verdict names spelled into the message.
# This is the NEAR-MISS: apply.sh then CONTAINS every verdict literal an arm might grep for while
# branching on none of them. The act-direction arms must still report it broken.
build_rec "$W/mut6"
sed -e 's@^      if \[ "\$adj_v" = "\$ADJ_KEEP_VERDICT" \]; then$@      if [ -n "$adj_v" ]; then@' \
    -e "s@a verdict of '\\\${adj_v}'@a verdict of '\${adj_v}' (one of ${V_ACT1}, ${V_ACT2}, ${ADJ_KEEP})@" \
  "$REC/apply.sh" > "$W/mut6/apply.sh"
if cmp -s "$REC/apply.sh" "$W/mut6/apply.sh"; then
  bad "MUTANT 6 did not apply — the keep-verdict branch it targets is spelled differently or is not there, so this mutant proves nothing"
elif ! grep -q 'if \[ -n "\$adj_v" \]; then' "$W/mut6/apply.sh"; then
  # BOTH HALVES OR NEITHER. The near-miss half edits the NOTE's text and applies to a presence-keyed
  # apply.sh as readily as to a branched one, so `cmp -s` alone reports a mutation that left the
  # branch intact — and against a presence-keyed subject the act rows are already absent, which
  # scores as a kill this mutant did not make.
  bad "MUTANT 6 applied only its near-miss half — the branch-disabling half did not land, so its kill below would be the subject's own behaviour rather than the mutation"
elif ! grep -qF -- "$V_ACT2" "$W/mut6/apply.sh"; then
  bad "MUTANT 6 applied but its near-miss half did not: the verdict literals are absent from the mutant, so it is not testing a spelling-keyed arm"
else
  if [ "$(printf '%s\n' "$(rows_for "$W/mut6" "$OVR_KR")" | grep -c . || true)" -eq 0 ]; then
    ok "MUTANT 6 (suppress on the token's PRESENCE, verdict names spelled in the text): the act-direction arms go red although apply.sh now names every verdict — they are keyed on the rows"
  else
    bad "MUTANT 6 SURVIVED: an act verdict still produced its sequence under a presence-keyed suppression, so assertion 6 is not testing the branch"
  fi
  if [ "$(printf '%s\n' "$(rows_for "$W/mut6" "$OVR_J")" | grep -c . || true)" -eq 0 ] && [ "$(notes_for "$W/mut6" "$OVR_J")" -ge 1 ]; then
    ok "  and the KEEP direction stays green under it — assertion 5 is not entangled with the act direction"
  else
    bad "  MUTANT 6 also moved the keep direction: assertions 5 and 6 are entangled"
  fi
fi

# --- MUTANT 7 — the adjudication prefix left attached on the act path. Assertion 8 must go red;
# assertion 5 must NOT, because the keep path never reaches the strip.
build_rec "$W/mut7"
sed 's@^      detail="\${detail#\*" :: "}"$@      :@' "$REC/apply.sh" > "$W/mut7/apply.sh"
if cmp -s "$REC/apply.sh" "$W/mut7/apply.sh"; then
  bad "MUTANT 7 did not apply — the prefix strip it targets is spelled differently or is not there, so this mutant proves nothing"
else
  case "$(last_detail "$(rows_for "$W/mut7" "$OVR_AR")")" in
    *"remove the anchor"*) bad "MUTANT 7 SURVIVED: the env-less multi-anchor row still narrowed the shadow with the prefix attached, so assertion 8 is not testing the strip" ;;
    *)                     ok "MUTANT 7 (adjudication prefix not stripped): the env-less multi-anchor row loses its narrowing — the strip is what keeps the positional parse reachable" ;;
  esac
  if [ "$(printf '%s\n' "$(rows_for "$W/mut7" "$OVR_J")" | grep -c . || true)" -eq 0 ] && [ "$(notes_for "$W/mut7" "$OVR_J")" -ge 1 ]; then
    ok "  and the keep direction is untouched by it — assertions 5 and 8 are not entangled"
  else
    bad "  MUTANT 7 also moved the keep direction: assertions 5 and 8 are entangled"
  fi
fi

echo ""
if [ "$fails" -eq 0 ]; then echo "apply-worklist-rows: PASS"; exit 0; fi
echo "apply-worklist-rows: FAIL ($fails)"; exit 1
