#!/usr/bin/env bash
#
# Drives ai-dlc-dispatch-guard.sh against a seeded layered consumer.
#
# v0.79.x: the guard SETS the model instead of DENYING a wrong/absent one. On the correcting path
# it returns `permissionDecision: "allow"` with `updatedInput.model` = the role's pinned tier; on an
# already-correct or fail-open dispatch it exits 0 with NO output. So the assertions check the
# INJECTED tier, not a deny verdict.
#
# THE TEETH, restated for the flip. The motivating failure was a no-param spawn on a resumed session
# running on an undetermined model. The correcting cases below (absent param, wrong tier) must now
# emit `updatedInput.model` = the pin. If the guard silently reverted to allow-all, every correcting
# assertion reads empty and FAILS — the check cannot pass vacuously. The already-correct and
# fail-open cases must emit NOTHING (no forced approval, no injection), or the guard would be
# rewriting inputs it has no pin for, or force-approving dispatches another hook may need to deny.
#
set -uo pipefail

# The pre-push gate exports every AI_DLC_* tunable a consumer set in settings.json into this
# process. Scrub them so the hook is tested against its own defaults, not the tester's env.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }
# shellcheck source=/dev/null
. "$HERE/../lib/layout.sh" || { echo "FIXTURE ERROR: lib/layout.sh not found" >&2; exit 2; }
# shellcheck source=/dev/null
. "$HERE/../lib/inproc.sh" || { echo "FIXTURE ERROR: lib/inproc.sh not found" >&2; exit 2; }

# IN PROCESS (BL-878). The two subjects this fixture asks directly (section 15t) are asked through vsl_f / vga_f, which
# hand the file to lib/inproc.sh's inproc_run; each distinct CLI outcome keeps one program start in eqv() below, compared
# byte for byte with the in-process answer. THE OPERAND IS A LITERAL TAIL, "${_f%/*}/<subject>.sh": this fixture drives
# unguarded bash subjects (the hooks), and arm P2 of scripts/validate-fixture-invocations.sh rows an inproc_run whose
# operand no literal path resolves in such a fixture. The guard HOOK runs in process too (dgrun -> dg_main, a pass of
# $HOOK); one program start per distinct outcome (cli-dg-set, cli-dg-deny, cli-dg-quiet) is compared byte for byte with
# the in-process answer at the end. The starts the hook makes of validate-spawn-ledger.sh and merge-adversarial-shards.sh
# (--remediated-keys, --check-shard-dir) are routed by dg_bash to vsl_main / merge_main in a subshell (the fixture-side bash
# shim); the stand-in validator that exits 2 stays a program start, the e2e cell dg-vsl-stub of cells.decl.
# A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECT. A present subject with neither the `<p>_main() {` line nor the column-0
# source guard predates the wrap: SKIP and exit 0 (FIXTURE BROKEN in the distribution). Exactly one half FAILS. An
# unreadable subject is FIXTURE ERROR.
echo "HERMETIC-CONSUMED $HOOK"
REM_ROOT="$(cd "$(dirname "$HOOK")/../.." && pwd)"
VSL=""; for _c in "$REM_ROOT/core/scripts/validate-spawn-ledger.sh" "$REM_ROOT/scripts/ai-dlc/validate-spawn-ledger.sh"; do
  [ -f "$_c" ] && { VSL="$_c"; break; }; done
VGA=""; for _c in "$REM_ROOT/core/scripts/validate-gate-adjudication.sh" "$REM_ROOT/scripts/ai-dlc/validate-gate-adjudication.sh"; do
  [ -f "$_c" ] && { VGA="$_c"; break; }; done
MRG=""; for _c in "$REM_ROOT/core/scripts/merge-adversarial-shards.sh" "$REM_ROOT/scripts/ai-dlc/merge-adversarial-shards.sh"; do
  [ -f "$_c" ] && { MRG="$_c"; break; }; done
dm_halves() { # dm_halves <file> <entry> -> "<def><guard>" (1 present, 0 absent); exit 2 on an unreadable file
  local d=0 g=0 x
  grep -qxF "$2() {" "$1"; x=$?
  [ "$x" -le 1 ] || { echo "FIXTURE ERROR: cannot read $1 (grep exit $x) -- an unreadable subject is not one that predates the wrap" >&2; exit 2; }
  [ "$x" -ne 0 ] || d=1
  grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$1"; x=$?
  [ "$x" -le 1 ] || { echo "FIXTURE ERROR: cannot read $1 (grep exit $x) -- an unreadable subject is not one that predates the wrap" >&2; exit 2; }
  [ "$x" -ne 0 ] || g=1
  printf '%s%s' "$d" "$g"
}
_dm_pre=""
dm_check() { # dm_check <file> <entry>
  [ -n "$1" ] || return 0
  _gh="$(dm_halves "$1" "$2")" || exit 2
  case "$_gh" in
    11) : ;;
    00) _dm_pre="$_dm_pre $1" ;;
    *) bad "$1 carries one half of the in-process wrap ($2 line, column-0 source guard: $_gh) -- a respelled subject this fixture cannot drive"
       report_end dispatch-model-guard ;;
  esac
}
dm_check "$HOOK" dg_main
dm_check "$VSL" vsl_main
dm_check "$VGA" vga_main
dm_check "$MRG" merge_main
if [ -n "$_dm_pre" ]; then echo "SKIP: dispatch-model-guard:$_dm_pre predate(s) the in-process wrap"; fx_skip_exit "$HERE"; fi
vsl_f() { # vsl_f <file> [args...] -> vsl_main's stdout, stderr and exit, logged as a pass of $VSL
  local _f="$1"; shift
  case "$_f" in */validate-spawn-ledger.sh) ;; *) echo "FIXTURE BROKEN: vsl_f was handed $_f, not a validate-spawn-ledger.sh" >&2; return 125 ;; esac
  ( [ "$_f" = "$VSL" ] || INPROC_LOADED="$VSL"; inproc_run "${_f%/*}/validate-spawn-ledger.sh" vsl_main "$@" )
}
vga_f() { # vga_f <file> [args...] -> vga_main's stdout, stderr and exit, logged as a pass of $VGA
  local _f="$1"; shift
  case "$_f" in */validate-gate-adjudication.sh) ;; *) echo "FIXTURE BROKEN: vga_f was handed $_f, not a validate-gate-adjudication.sh" >&2; return 125 ;; esac
  ( [ "$_f" = "$VGA" ] || INPROC_LOADED="$VGA"; inproc_run "${_f%/*}/validate-gate-adjudication.sh" vga_main "$@" )
}
dg_fresh() { # unset every unexported variable a fresh bash does not start with (the loaded-subject discipline of lib/inproc.sh)
  local _x _v
  _x=" $(compgen -e) "; _x="${_x//$'\n'/ }"
  for _v in $(compgen -v); do
    case "$_x" in *" $_v "*) continue ;; esac
    case "$_v" in
      _x|_v|_f|_e|_p|_h) continue ;;
      BASH|BASH_*|BASHOPTS|BASHPID|COMP_WORDBREAKS|DIRSTACK|EUID|FUNCNAME|GROUPS|HISTCMD|HOSTNAME|HOSTTYPE) continue ;;
      IFS|LINENO|MACHTYPE|OPTERR|OPTIND|OSTYPE|PIPESTATUS|PPID|PS4|PWD|OLDPWD|RANDOM|SECONDS|SHELL|SHELLOPTS) continue ;;
      SHLVL|TERM|UID|_) continue ;;
    esac
    unset "$_v" 2>/dev/null
  done
  OPTIND=1; set +eufx +o pipefail; hash -r
}
dg_vsl() { # dg_vsl <file> [args...] -> vsl_main in a fresh-options subshell, logged as a pass of the file
  local _p="$1"; shift
  (
    dg_fresh
    fx_inproc "$_p"
    . "$_p" && vsl_main "$@"
  )
}
dg_mrg() { # dg_mrg <file> [args...] -> merge_main in a fresh-options subshell, logged as a pass of the file
  local _p="$1"; shift
  (
    dg_fresh
    fx_inproc "$_p"
    . "$_p" && merge_main "$@"
  )
}
dg_bash() { # the guard's own `bash <sibling>` start of the ledger validator or the merge runs its entry in process; any other start is real
  local _p="${1:-}"
  case "$_p" in
    */validate-spawn-ledger.sh) grep -qxF 'vsl_main() {' "$_p" 2>/dev/null && { dg_vsl "$@"; return; } ;;
    */merge-adversarial-shards.sh) grep -qxF 'merge_main() {' "$_p" 2>/dev/null && { dg_mrg "$@"; return; } ;;
  esac
  command bash "$@"
}
dgrun() { # dgrun <guard file> [args...] -> dg_main's stdout, stderr and exit, logged as a pass of $HOOK (stdin and prefix assignments pass through)
  local _f="$1" _h="$HOOK"; shift
  (
    dg_fresh
    bash() { dg_bash "$@"; }
    fx_inproc "$_h"
    . "$_f" || exit 126
    dg_main "$@"
  )
}
vsl() { vsl_f "$VSL" "$@"; }
vga() { vga_f "$VGA" "$@"; }
EQ="$WORK/eq"; mkdir -p "$EQ" || { echo "FIXTURE ERROR: mkdir eq" >&2; exit 2; }
eqv() { # eqv <cell-id> <file> <in-process fn> [args...] -> $EQ/<id>.{ip,cl}.{out,err,rc}; 0 when all three agree
  local id="$1" f="$2" fn="$3"; shift 3
  "$fn" "$@" > "$EQ/$id.ip.out" 2> "$EQ/$id.ip.err"; echo "$?" > "$EQ/$id.ip.rc"
  FXCELL="$id" command bash "$f" "$@" > "$EQ/$id.cl.out" 2> "$EQ/$id.cl.err"; echo "$?" > "$EQ/$id.cl.rc"
  cmp -s "$EQ/$id.ip.out" "$EQ/$id.cl.out" && cmp -s "$EQ/$id.ip.err" "$EQ/$id.cl.err" && cmp -s "$EQ/$id.ip.rc" "$EQ/$id.cl.rc"
}
# raw <project_dir> <json> -> hook stdout (decision JSON on a set, empty on a plain allow).
raw() { printf '%s' "$2" | CLAUDE_PROJECT_DIR="$1" dgrun "$HOOK" 2>/dev/null; }

# setmodel <project> <json> -> the injected updatedInput.model (empty if the hook emitted nothing).
setmodel() { raw "$1" "$2" | jq -r '.hookSpecificOutput.updatedInput.model // empty' 2>/dev/null; }
# verdict <project> <json> -> the permissionDecision (empty if the hook emitted nothing).
verdict() { raw "$1" "$2" | jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null; }

# mkjson <tool> <role|-> [model]   — builds an Agent dispatch binding a role file.
mkjson() {
  local bind=""
  [ "$2" != "-" ] && bind="Your operating contract is \`.claude/team-roles/$2.md\`. Read it first."
  jq -nc --arg t "$1" --arg p "$bind Do the work." --arg m "${3-}" '
    {tool_name: $t, tool_input: {prompt: $p, name: "teammate-s291-1"}}
    | if $m != "" then .tool_input.model = $m else . end'
}

# expect_set <project> <json> <want-tier> <label>
expect_set() {
  local got; got="$(setmodel "$1" "$2")"
  [ "$got" = "$3" ] && ok "$4 → set model=$3" \
    || bad "$4 → injected '$got', expected '$3' (the guard is not binding the pinned tier)"
}
# expect_untouched <project> <json> <label>  — no injection, no forced verdict.
expect_untouched() {
  local out; out="$(raw "$1" "$2")"
  [ -z "$out" ] && ok "$3 → untouched (exit 0, no decision)" \
    || bad "$3 → hook emitted '$out', expected NOTHING (it must not inject or force-approve here)"
}

expect_deny() { # expect_deny <out> <label>
  if [ "$(printf '%s' "$1" | jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null)" = deny ] \
     && printf '%s' "$1" | jq -e '.hookSpecificOutput | has("updatedInput") | not' >/dev/null 2>&1; then
    ok "$2 -> DENIED, with no updatedInput"
  else bad "$2 -> expected a deny with no updatedInput, got '$(printf '%s' "$1" | cut -c1-200)'"; fi
}
expect_quiet() { # expect_quiet <out> <label>
  [ -z "$1" ] && ok "$2 -> allowed (no decision)" || bad "$2 -> expected NO decision, got '$(printf '%s' "$1" | cut -c1-200)'"
}

# ONE copy of the hooks directory serves every guard copy: the guard resolves exactly one sibling
# (ai-dlc-context-provenance.sh, by `dirname "${BASH_SOURCE[0]}"`), and every copy is a
# differently NAMED guard file inside that one directory, so each still finds its sibling beside
# itself. Built at top level, not lazily: a lazy build inside the `$( )` that calls mk_hooks_copy
# would be discarded with that subshell.
HOOKS_SRC="$(dirname "$HOOK")"
HOOKS_SHARED="$(mktemp -d "$WORK/hooks-shared.XXXXXX")" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
cp -R "$HOOKS_SRC/." "$HOOKS_SHARED/" || { echo "FIXTURE ERROR: hooks copy failed" >&2; exit 2; }
mk_hooks_copy() { # mk_hooks_copy <tag> -> path of a byte-identical guard copy beside the shared sibling
  local g="$HOOKS_SHARED/$(basename "$HOOK").$1"
  cp "$HOOKS_SHARED/$(basename "$HOOK")" "$g" || return 1
  printf '%s' "$g"
}

# The prompt the guard hands back, for the prompt-integrity assertions.
newprompt() { raw "$1" "$2" | jq -r '.hookSpecificOutput.updatedInput.prompt // ""' 2>/dev/null; }

# THE GUARD AMENDS PARAMETERS AND NEVER THE PROMPT, and these two arms are what holds it
# there. The Agent tool has no effort parameter and prompt text is read back by nothing --
# `validate-spawn-ledger.sh` resolves a teammate's actual level from that teammate's own
# transcript -- so a sentence appended here reaches no mechanism while making every dispatch
# with a configured effort a correcting dispatch. The two arms are keyed on DIFFERENT
# observables on purpose: one on byte identity, one on the text a directive would produce.
# A single grammar scoring its own subject as a non-instance is how an absence scan reports
# a floor of unknown depth.
#
# expect_prompt_verbatim <root> <json> <label>
# Only meaningful on a dispatch that EMITS -- a silent one hands back no prompt at all, so
# the emission is ASSERTED here rather than assumed, and an arm pointed at a silent dispatch
# reports that it cannot see its subject instead of passing over an empty string.
expect_prompt_verbatim() {
  local out got want
  out="$(raw "$1" "$2")"
  if [ -z "$out" ]; then
    bad "$3 -> the guard emitted NOTHING, so no returned prompt exists to compare — this arm needs a correcting dispatch and is asserting nothing here"
    return
  fi
  got="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.updatedInput.prompt // "<unset>"' 2>/dev/null)"
  want="$(printf '%s' "$2" | jq -r '.tool_input.prompt // "<unset>"')"
  [ "$got" = "$want" ] \
    && ok "$3 -> the outgoing prompt is byte-identical to the one dispatched" \
    || bad "$3 -> the guard REWROTE the prompt. sent: '$want' / returned: '$got'"
}
# expect_no_effort_prose <root> <json> <label>
# Keyed on the OBSERVABLE a re-added directive produces -- any sentence naming a level of
# the configured vocabulary -- rather than on one spelling, so a reworded line is caught too.
expect_no_effort_prose() {
  local got; got="$(newprompt "$1" "$2" | grep -oiE '(reasoning )?effort[^.]{0,40}(low|medium|high|xhigh|max)' | head -1)"
  [ -z "$got" ] \
    && ok "$3 -> the outgoing prompt states no effort level" \
    || bad "$3 -> the outgoing prompt states an effort ('$got') — the guard has no effort channel and must not put one in the prompt"
}
expect_model_kept() { # expect_model_kept <root> <json> <label>
  # The guard emitted (for another trigger) but did NOT rewrite `model`. Distinguishes
  # "left the model alone" from "emitted nothing" on a dispatch that emits for a reason
  # other than the model.
  local m; m="$(raw "$1" "$2" | jq -r '.hookSpecificOutput.updatedInput.model // "<unset>"' 2>/dev/null)"
  local want; want="$(printf '%s' "$2" | jq -r '.tool_input.model // "<unset>"')"
  [ "$m" = "$want" ] \
    && ok "$3 -> model left as '$want'" \
    || bad "$3 -> model was rewritten to '$m', expected it left as '$want'"
}
expect_no_model() { # expect_no_model <root> <json> <label>
  raw "$1" "$2" | jq -e '.hookSpecificOutput.updatedInput | has("model") | not' >/dev/null 2>&1 \
    && ok "$3 -> no model bound" \
    || bad "$3 -> a model was bound where none is configured"
}

echo "dispatch-model-guard"

# --- 1. gate-adjudicator with NO model param -> SET opus ---------------------
# The motivating failure. Absent model was UNDETERMINED; the guard now binds the pin.
expect_set "$CONSUMER" "$(mkjson Agent gate-adjudicator)" opus \
  "gate-adjudicator, no model param"

# --- 1b. the emission is `allow` (least restrictive) and names the tier + source ---
# allow is what makes this SAFE: deny > defer > ask > allow, so this cannot override the pause
# hook's deny. And the reason must name what it bound, or a reader cannot audit the correction.
J="$(mkjson Agent gate-adjudicator)"
[ "$(verdict "$CONSUMER" "$J")" = allow ] \
  && ok "set emits permissionDecision=allow (cannot override another hook's deny)" \
  || bad "set did not emit allow — either it still denies, or it emits a more-restrictive verdict"
# THIS ARM WAS SATISFIED BY THE WRONG STRING. It used to require the literal `role file`
# anywhere in the hook's output, and what supplied it was the EFFORT directive's own wording
# ("...before reading your role file."), not the reason. The reason has always cited
# `aiDlcRoles.<role>` in settings.json — which is the actual provenance, since the config is
# authoritative for both values and the role file states neither. Rewording the effort line
# turned the arm red and exposed that it was keyed on an unrelated sentence. It now asserts the
# config entry, which is the thing whose absence would make the correction unauditable.
raw_out="$(raw "$CONSUMER" "$J")"
if grep -q 'opus' <<<"$raw_out" && grep -q 'aiDlcRoles' <<<"$raw_out"; then
  ok "the correction names the tier it bound and cites the aiDlcRoles entry as the source"
else
  bad "the correction does not explain what it set or from where — unauditable"
fi
# and the injected input PRESERVES the rest of the call (the role binding is not dropped)
raw "$CONSUMER" "$J" | jq -e '.hookSpecificOutput.updatedInput.prompt | contains("team-roles/gate-adjudicator.md")' >/dev/null 2>&1 \
  && ok "updatedInput preserves the original prompt/role binding" \
  || bad "updatedInput dropped the prompt — the guard is replacing the input, not amending it"

# --- 2. remediator with no param -> SET opus --------------------------------
expect_set "$CONSUMER" "$(mkjson Agent remediator)" opus "remediator, no model param"

# --- 3. THE REAL S291 DEFECT: an EXPLICIT wrong tier -> OVERRIDE to opus -----
# remediator-s291-disc-p1/-prd-p1 requested sonnet against remediator's opus pin. The guard now
# corrects the call to the pin rather than rejecting it — a call site cannot override the role file.
expect_set "$CONSUMER" "$(mkjson Agent remediator sonnet)" opus \
  "remediator explicitly requested sonnet against an opus pin (the real S291 defect)"

# --- 4. correct tier -> UNTOUCHED (happy path keeps its approval posture) ----
# THE TRIGGER SET IS TWO, NOT THREE, AND THESE ARMS ARE WHERE THAT IS OBSERVABLE. A
# configured effort is not a trigger: the only channel that reaches a teammate's effort is
# the rendered definition, which `NEEDS_TYPE` already selects. So a dispatch whose model is
# already right and whose role has NO rendered definition needs nothing and must emit
# NOTHING — it keeps whatever approval posture it would otherwise have. Every role in this
# block pins an effort and has no definition, so each of these used to emit purely to append
# a prompt sentence, and each is now silent.
expect_untouched "$CONSUMER" "$(mkjson Agent gate-adjudicator opus)" \
  "gate-adjudicator requested opus against an opus config"
expect_untouched "$CONSUMER" "$(mkjson Agent analyst sonnet)" \
  "analyst requested sonnet against a sonnet config"

# --- 5. a request CARRYING the key matches ----------------------------------
# The key is `opus`; a full model string containing it is the same model -> untouched.
# The tolerance is bounded by the DECLARED key, not by a hardcoded tier table.
expect_untouched "$CONSUMER" "$(mkjson Agent gate-adjudicator 'claude-opus-5[1m]')" \
  "full model string carrying the configured key (key compare, not a tier guess)"

# --- 6. unpinned role -> UNTOUCHED (fail-open: tea/sm/ux/cis declare nothing)-
# `tea` configures an effort and NO model, and has no rendered definition. With effort gone
# as a trigger there is nothing left for the guard to do on either shape, so both are total
# no-ops rather than emissions that bind no model.
expect_untouched "$CONSUMER" "$(mkjson Agent tea)" \
  "tea configures an effort but no model — nothing to correct"
expect_untouched "$CONSUMER" "$(mkjson Agent tea opus)" \
  "tea with an explicit model: the guard has no configured value to correct it to"

# --- 6b. a party persona WITH a model -> BOUND like any role -------------------
# A persona's model is optional. `sm` sets one (the shipped template's shape), so the guard
# binds it exactly as it binds `dev`: absent param set, wrong tier corrected, right tier left
# alone. One property apart from the tea cells above -- the presence of the model key.
expect_set "$CONSUMER" "$(mkjson Agent sm)" sonnet \
  "sm (a party persona that SETS a model), no model param"
expect_set "$CONSUMER" "$(mkjson Agent sm opus)" sonnet \
  "sm requested opus against its sonnet config → corrected (a /bmad-party-mode spawn is bound like any role)"
expect_untouched "$CONSUMER" "$(mkjson Agent sm sonnet)" \
  "sm requested sonnet against its sonnet config"

# --- 7. model key not defined in aiDlcModels -> NO MODEL BOUND (fail-open) ---
# architect's entry names `ghostkey`, which aiDlcModels does not define, so nothing resolves
# to bind. Its effort is valid and still cannot be delivered by this guard: architect has no
# rendered definition, so the level reaches the teammate through no channel at all and the
# guard stays silent rather than emitting prose about it.
expect_untouched "$CONSUMER" "$(mkjson Agent architect)" \
  "role whose configured model key is absent from aiDlcModels — nothing bound, nothing emitted"
expect_untouched "$CONSUMER" "$(mkjson Agent architect sonnet)" \
  "and an explicitly wrong model is NOT corrected against an unresolvable key"

# --- 8. the Ollama prose line is not a pin; the `- Model:` key binds ---------
expect_untouched "$CONSUMER" "$(mkjson Agent dev sonnet)" \
  "dev configured sonnet: a sonnet request is left alone"
expect_set "$CONSUMER" "$(mkjson Agent dev opus)" sonnet \
  "dev.md opus request is corrected to the pinned sonnet (prose /model line is not the pin)"

# --- 8b. dev-escalated: model escalation is a ROLE, and its pin is bound ------
expect_untouched "$CONSUMER" "$(mkjson Agent dev-escalated opus)" \
  "dev-escalated requested opus against its opus config (escalation happy path)"
expect_set "$CONSUMER" "$(mkjson Agent dev-escalated sonnet)" opus \
  "dev-escalated requested sonnet against its opus pin → corrected to opus (the escalation slip)"
expect_set "$CONSUMER" "$(mkjson Agent dev-escalated)" opus \
  "dev-escalated with no model param → set opus"

# --- 9. no role binding in the prompt -> UNTOUCHED --------------------------
expect_untouched "$CONSUMER" "$(mkjson Agent - opus)" \
  "dispatch with no role binding (not ours)"

# --- 10. non-dispatch tool -> UNTOUCHED ------------------------------------
expect_untouched "$CONSUMER" "$(jq -nc '{tool_name:"Edit",tool_input:{file_path:"/tmp/x",old_string:"a",new_string:"b"}}')" \
  "Edit (out of scope)"

# --- 11. activation gate: unstamped tree -> total no-op --------------------
expect_untouched "$NOSTAMP" "$(mkjson Agent gate-adjudicator)" \
  "unstamped tree (not a layered consumer)"

# --- 11b. no aiDlcModels block at all -> total no-op ------------------------
# A consumer whose settings.json predates the block (or was hand-trimmed) has no
# resolvable key for ANY role. The guard must bind nothing rather than fall back
# to a guess — this is the branch that makes a missing block safe to ship into.
expect_untouched "$NOMODELS" "$(mkjson Agent gate-adjudicator)" \
  "consumer settings.json carries no aiDlcModels block — fail-open"
expect_untouched "$NOMODELS" "$(mkjson Agent gate-adjudicator sonnet)" \
  "no aiDlcModels block, explicit wrong model — still fail-open, never a guess"

# --- 12. unknown role file -> UNTOUCHED (fail-open) ------------------------
expect_untouched "$CONSUMER" "$(mkjson Agent nonexistent-role)" \
  "unreadable/unknown role file — fail-open"

# --- 13. Task tool is in scope too -----------------------------------------
expect_set "$CONSUMER" "$(mkjson Task remediator)" opus \
  "Task-tool dispatch is policed like Agent"

# --- 13b. THE PROMPT IS NOT A CHANNEL: the guard amends PARAMETERS ONLY -------
# The Agent tool has no `effort` parameter, and a sentence in the prompt is read back by
# nothing — `validate-spawn-ledger.sh` resolves a teammate's level from that teammate's own
# transcript, never from what was said to it. So the guard hands the prompt back UNCHANGED on
# every path, and a configured effort is delivered by the rendered definition or not at all.
#
# BOTH ARMS RUN ON A DISPATCH THAT EMITS, or they are reading an empty string. Two are driven:
# a model correction (no definition involved) and a definition-bound rewrite (whose role pins
# an effort and whose definition supplies it), because those are the two emitting paths and a
# reinstated append could sit on either one.
EFFJ_MODEL="$(mkjson Agent remediator sonnet)"
EFFJ_DEF="$(mkjson Agent defok sonnet)"
expect_prompt_verbatim "$CONSUMER" "$EFFJ_MODEL" \
  "model-correcting dispatch (remediator pins effort high)"
expect_prompt_verbatim "$CONSUMER" "$EFFJ_DEF" \
  "definition-bound dispatch (defok pins effort high and its definition binds it)"
expect_no_effort_prose "$CONSUMER" "$EFFJ_MODEL" \
  "model-correcting dispatch"
expect_no_effort_prose "$CONSUMER" "$EFFJ_DEF" \
  "definition-bound dispatch"

# A role with an effort and NO model — the party-persona shape. Nothing about it is
# correctable, so the whole dispatch is a no-op rather than an emission carrying prose.
expect_untouched "$CONSUMER" "$(mkjson Agent tea)" \
  "tea has an effort and no model, and no definition — nothing to bind"

# A role configured with an INVALID effort level. Its model still resolves and is still
# corrected, and the unrecognised level reaches the outgoing call through nothing.
expect_set "$CONSUMER" "$(mkjson Agent badeffort opus)" sonnet \
  "a role with an invalid effort level still has its model corrected"
expect_no_effort_prose "$CONSUMER" "$(mkjson Agent badeffort opus)" \
  "a role configured with an invalid effort level"

# --- 13c. IDEMPOTENCE: a well-formed dispatch keeps its approval posture -----
# The guard emits `allow` to carry `updatedInput`. If it emitted on every dispatch it would
# change the approval posture of calls it has nothing to correct. With effort no longer a
# trigger, a dispatch whose model is already right and whose role has no rendered definition
# is such a call — and its prompt is irrelevant to that verdict, which is what the pair below
# asserts: the SAME dispatch is silent with and without an effort sentence in its prompt.
IDEM="$(jq -nc --arg p "contract is .claude/team-roles/gate-adjudicator.md" \
  '{tool_name:"Agent",tool_input:{model:"opus",prompt:$p,name:"t"}}')"
expect_untouched "$CONSUMER" "$IDEM" \
  "a dispatch already carrying the configured model"

# THE LEGACY PROMPT, one property apart. A consumer dispatching from a cached prompt still
# carries the sentence the guard used to append. It is not a trigger, not a dedupe key and not
# something the guard strips — the verdict must be identical to the arm above, or prompt text
# is still steering a decision somewhere.
IDEM_LEGACY="$(jq -nc --arg p "contract is .claude/team-roles/gate-adjudicator.md

Your configured reasoning effort for this role is high. Operate at that level." \
  '{tool_name:"Agent",tool_input:{model:"opus",prompt:$p,name:"t"}}')"
expect_untouched "$CONSUMER" "$IDEM_LEGACY" \
  "the same dispatch whose prompt still carries the sentence the guard used to append"

# A prompt naming a DIFFERENT level is the same non-event. Under the old dedupe this input
# was the one that forced an emission; nothing reads it now.
IDEM_WRONGLEVEL="$(jq -nc --arg p "contract is .claude/team-roles/gate-adjudicator.md

Your configured reasoning effort for this role is medium. Operate at that level." \
  '{tool_name:"Agent",tool_input:{model:"opus",prompt:$p,name:"t"}}')"
expect_untouched "$CONSUMER" "$IDEM_WRONGLEVEL" \
  "the same dispatch whose prompt names a level the config does not"


# --- 13d. a role with no config entry -> UNTOUCHED (fail-open) --------------
expect_untouched "$CONSUMER" "$(mkjson Agent nocfg)" \
  "role file with no aiDlcRoles entry — fail-open, binds nothing"

# --- 14. FIXTURE STALENESS: the real core role files must still parse -------
[ -r "$SRC_ROLES/gate-adjudicator.md" ] && echo "HERMETIC-CONSUMED core/team-roles/gate-adjudicator.md"
REAL_PTR="$(grep -c 'aiDlcRoles\.' "$SRC_ROLES/gate-adjudicator.md" 2>/dev/null)"; REAL_PTR="${REAL_PTR:-0}"
[ "$REAL_PTR" -gt 0 ] && ok "real core gate-adjudicator.md points at its aiDlcRoles entry" \
  || bad "FIXTURE STALE: core/team-roles/gate-adjudicator.md no longer names aiDlcRoles — the role file and the config have been decoupled without updating this fixture"

REAL_PIN="$(grep -c '^- Model: \|^- `/effort ' "$SRC_ROLES/gate-adjudicator.md" 2>/dev/null)"; REAL_PIN="${REAL_PIN:-0}"
[ "$REAL_PIN" -eq 0 ] && ok "real core role files state no model or effort of their own (config owns both)" \
  || bad "FIXTURE STALE: core/team-roles/gate-adjudicator.md has grown a '- Model:' or '- /effort' line back. Two sources for one value is the drift this release removed; the guard reads only the config, so an in-file value would be silently ignored."

# --- SPAWN LEDGER (v0.158.0) --------------------------------------------------
# Check 22 reads this file instead of a table the lead writes about itself. The
# assertions below are what make that substitution safe: a row per dispatch, the
# model ACTUALLY bound (not requested), and the Rule 19(b) citation observed
# rather than claimed.
LEDGER="$CONSUMER/_bmad-output/spawn-ledger.jsonl"
mkdir -p "$CONSUMER/_bmad-output"
printf -- '- **sprint_id:** 291\n' > "$CONSUMER/_bmad-output/pipeline-snapshot.md"
lrow() { jq -c 'select(.name != null)' "$LEDGER" 2>/dev/null | tail -1; }
# `tostring`, NOT `// "null"`: jq's alternative operator treats `false` as absent,
# so `.role_contract_cited // "null"` reports "null" for the very value these
# assertions exist to catch — a boolean field read through `//` can never be false.
lfield() { lrow | jq -r "$1 | tostring" 2>/dev/null; }

# A corrected dispatch must record BOTH values. Recording only the bound model
# would hide the slip; only the requested one would misreport what ran.
rm -f "$LEDGER"
raw "$CONSUMER" "$(mkjson Agent remediator sonnet)" >/dev/null
[ "$(lfield .model_requested)" = "sonnet" ] && [ "$(lfield .model_bound)" = "opus" ] \
  && ok "corrected dispatch records requested=sonnet AND bound=opus (the slip stays visible)" \
  || bad "ledger recorded requested='$(lfield .model_requested)' bound='$(lfield .model_bound)', expected sonnet/opus"

[ "$(lfield .role_contract_cited)" = "true" ] \
  && ok "role_contract_cited=true when the prompt names team-roles/<role>.md" \
  || bad "role_contract_cited='$(lfield .role_contract_cited)', expected true"

# An ALREADY-CORRECT dispatch emits nothing on stdout but must still be recorded,
# or Check 22 sees only the sprint's mistakes and reads a clean sprint as no spawns.
rm -f "$LEDGER"
raw "$CONSUMER" "$(mkjson Agent gate-adjudicator opus)" >/dev/null
[ "$(wc -l < "$LEDGER" 2>/dev/null | tr -d ' ')" = "1" ] \
  && ok "an already-correct dispatch is still recorded (silence on stdout is not silence on disk)" \
  || bad "already-correct dispatch wrote $(wc -l < "$LEDGER" 2>/dev/null | tr -d ' ') row(s), expected 1"

# subagent_type-only: before v0.158.0 this was a total no-op — no binding, no row.
# It is the likeliest route by which a protected-path-editor reached sonnet on the
# reference consumer while the guard sat installed and green.
#
# THIS IS THE NO-DEFINITION WORLD. `remediator` has no rendered `.claude/agents/` file in
# the seed. The model-binding subject is the CITED twin (the brief names the role file), so
# the injection is asserted where the dispatch is allowed; the uncited twin is THE CITATION
# DENY's: neither carrier delivers the Rule 19(b) line to a declared role, so it is refused
# with no row (the false/null record is observable only on the fail-open world below).
rm -f "$LEDGER"
JC="$(jq -nc '{tool_name:"Agent",tool_input:{name:"t-1",model:"sonnet",subagent_type:"remediator",prompt:"Your operating contract is `.claude/team-roles/remediator.md`. Read it first. Do the work."}}')"
JC_OUT="$(raw "$CONSUMER" "$JC")"
JC_MODEL="$(jq -r '.hookSpecificOutput.updatedInput.model // empty' <<<"$JC_OUT" 2>/dev/null)"
JC_DEC="$(jq -r '.hookSpecificOutput.permissionDecision // "none"' <<<"$JC_OUT" 2>/dev/null)"
[ "$JC_MODEL" = "opus" ] \
  && ok "subagent_type-only dispatch is bound (was a silent no-op before v0.158.0)" \
  || bad "subagent_type-only dispatch injected '$JC_MODEL', expected opus"
rm -f "$LEDGER"
J="$(jq -nc '{tool_name:"Agent",tool_input:{name:"t-1",model:"sonnet",subagent_type:"remediator",prompt:"Do the work."}}')"
J_OUT="$(raw "$CONSUMER" "$J")"
expect_deny "$J_OUT" "CITATION DENY: the same dispatch with no Rule 19(b) line (a declared role, no definition)"
[ ! -s "$LEDGER" ] && ok "  and writes no ledger row" || bad "  the denied uncited dispatch wrote a row: $(lrow)"
grep -qF 'refused a `remediator` dispatch, because the Rule 19(b) role-contract line' <<<"$J_OUT" \
  && ok "  and the reason names the role" || bad "  the citation deny does not name \`remediator\`"
# OUT OF SCOPE: an undeclared agent type with no line is the measured false-positive class.
GPJ="$(jq -nc '{tool_name:"Agent",tool_input:{description:"walk",subagent_type:"general-purpose",prompt:"Walk the rubric."}}')"
GP_D="$(raw "$CONSUMER" "$GPJ" | jq -r '.hookSpecificOutput.permissionDecision // "none"' 2>/dev/null)"
[ "$GP_D" != deny ] && ok "CITATION DENY: general-purpose with no line is NOT denied (decision '$GP_D')" \
  || bad "CITATION DENY: general-purpose with no line was DENIED -- the deny is not scoped to declared roles"
# FAIL OPEN: settings.json unparseable, so no declared set can be read. The dispatch is allowed
# and the row is still written with the uncited record Check 22 reads on this path.
FO="$WORK/citefailopen"
mkdir -p "$FO/.claude" "$FO/_bmad-output"
cp -R "$CONSUMER/.claude/team-roles" "$FO/.claude/"
cp "$CONSUMER/.claude/.ai-dlc-version" "$FO/.claude/"
printf '{ not json\n' > "$FO/.claude/settings.json"
printf -- '- sprint_id: 291\n' > "$FO/_bmad-output/pipeline-snapshot.md"
FO_D="$(raw "$FO" "$J" | jq -r '.hookSpecificOutput.permissionDecision // "none"' 2>/dev/null)"
FO_R="$(jq -r '"\(.role)/\(.role_contract_cited | tostring)/\(.contract_via | tostring)"' "$FO/_bmad-output/spawn-ledger.jsonl" 2>/dev/null | tail -1)"
[ "$FO_D" != deny ] && [ "$FO_R" = "remediator/false/null" ] \
  && ok "CITATION DENY fail-open: unparseable settings -> not denied, row records remediator/false/null" \
  || bad "CITATION DENY fail-open: decision '$FO_D', row '$FO_R'; expected not-deny and remediator/false/null"

# Fail-closed: a role file that does not resolve is a Rule 19 violation, and it
# must be RECORDED. Exiting before the write would make it look like no dispatch.
rm -f "$LEDGER"
raw "$CONSUMER" "$(mkjson Agent nonexistent-role opus)" >/dev/null
[ "$(lfield .role_file_readable)" = "false" ] \
  && ok "unresolvable role file is recorded (role_file_readable=false), not silently skipped" \
  || bad "unresolvable role file recorded readable='$(lfield .role_file_readable)', expected false"

# A dispatch with no role at all is not a teammate spawn — no row, or Check 22
# inherits noise it must then explain away.
rm -f "$LEDGER"
raw "$CONSUMER" "$(mkjson Agent - opus)" >/dev/null
[ ! -s "$LEDGER" ] \
  && ok "a dispatch binding no role writes no row (not our spawn)" \
  || bad "a role-less dispatch wrote a ledger row: $(lrow)"

# --- CONTRACT CARRIER: role_contract_cited and contract_via ------------------------
# The Rule 19(b) line reaches a teammate by one of two carriers: the dispatch PROMPT naming
# `team-roles/<role>.md`, or the BODY of the `.claude/agents/<role>.md` definition the dispatch
# selects, which is the subagent system prompt. The row records which in `contract_via`, and
# `role_contract_cited` is true when either delivered it. A record of delivery-as-selected at
# PreToolUse, never of the read.
#
# THE WORLDS, each keyed to one property, scored `<decision>:<rows added>:<cited/via>`:
#   a  defok, subagent_type only, no prompt citation      -> allow:1:true/definition
#   b  defok, prompt cites the role AND definition bound  -> allow:1:true/prompt   (prompt wins)
#   c  defnoline, bound, body carries neither line         -> allow:1:true/prompt (line injected)
#   d  defwrongrole, bound, body carries defok's line 1 and region -> deny:0:- (a foreign body)
#   e  remediator, no definition at all                    -> deny:0:-
#   f  defok, a two-document input the emit cannot amend  -> see its own comment
# a, c, d and f carry session_id `s-dmg-1`, whose SessionStart snapshot seed.sh wrote: the guard
# reads the definition body from that copy. c's snapshot body is not a carrier for its role, so
# the guard puts the Rule 19(b) line at the head of the prompt (THE CITATION INJECTION) and the
# row reads true/prompt; a carrier crediting the body would read true/definition. d's body is
# ANOTHER role's (line 1 and region name defok), so no line is injected and the deny decides.
# THE CARRIER'S `false` IS NOW A DECISION, NOT A ROW. A declared role with no bound definition
# and no prompt citation is refused by THE CITATION DENY before the append, so e reads deny with
# no row, and so does d, whose body is another role's; a bound definition that is merely not a
# current carrier gets the injected line instead, so c reads allow:1:true/prompt. The uncited false/null ROW survives only where the deny cannot
# decide (the fail-open world above).
# c and d are MARKED and AGREE with settings, so the guard binds them exactly as it binds
# defok; only the body differs, which is the property under test. The definition_bound
# controls below say so in this run, or a false there would be a false for the wrong reason.
#
# EVERY DRIVE SEEDS AN EPOCH ROW FIRST, and it is not the subject. A one-row ledger makes the
# subject its own epoch and `tail -1` then reads whatever row exists; here the subject must be
# row 2 and must carry its own role, or the cell reports the row it did read. The epoch row is
# prompt-cited (true/prompt), so a subject that wrote nothing cannot pass a false/null arm on it.
EPOCHJ="$(mkjson Agent gate-adjudicator opus)"
# ccell <guard> <json> <subject-role> -> "<decision>:<rows added after the epoch>:<cited/via>"
# of the subject (`-` when it wrote no row). The decision is read literally, `none` when the hook
# printed nothing, so a crashed hook cannot pass for an allowed or a denied one.
ccell() {
  local n d o c=-
  rm -f "$LEDGER"
  printf '%s' "$EPOCHJ" | CLAUDE_PROJECT_DIR="$CONSUMER" dgrun "$1" >/dev/null 2>&1
  o="$(printf '%s' "$2" | CLAUDE_PROJECT_DIR="$CONSUMER" dgrun "$1" 2>/dev/null)"
  d="$(jq -r '.hookSpecificOutput.permissionDecision // "none"' <<<"$o" 2>/dev/null)"; [ -n "$d" ] || d=none
  n="$(wc -l < "$LEDGER" 2>/dev/null | tr -d ' ')"; n="${n:-0}"
  [ "$n" = 2 ] && c="$(tail -1 "$LEDGER" | jq -r --arg r "$3" \
    'if .role == $r then "\(.role_contract_cited | tostring)/\(.contract_via | tostring)" else "WRONGROW:\(.role)" end' 2>/dev/null)"
  printf '%s:%s:%s' "$d" "$((n - 1))" "$c"
}
CW_A="$(jq -nc '{session_id:"s-dmg-1",tool_name:"Agent",tool_input:{name:"t-a",subagent_type:"defok",prompt:"Do the work."}}')"
CW_B="$(mkjson Agent defok)"
CW_C="$(jq -nc '{session_id:"s-dmg-1",tool_name:"Agent",tool_input:{name:"t-c",subagent_type:"defnoline",prompt:"Do the work."}}')"
CW_D="$(jq -nc '{session_id:"s-dmg-1",tool_name:"Agent",tool_input:{name:"t-d",subagent_type:"defwrongrole",prompt:"Do the work."}}')"
CW_E="$(jq -nc '{tool_name:"Agent",tool_input:{name:"t-e",subagent_type:"remediator",prompt:"Do the work."}}')"

# CONTROLS: c and d are bound (so the body is what decides), e is not. Their uncited dispatch is
# denied with no row, so binding is read off the PROMPT-CITED twin of the same role and world:
# definition binding is decided before the citation is, and does not read the prompt's line.
cited_twin() { printf '%s' "$1" | jq -c --arg r "$2" '.tool_input.prompt = ("Your operating contract is `.claude/team-roles/" + $r + ".md`. Read it first. " + .tool_input.prompt)'; }
for _cw in "a:defok:$CW_A" "c:defnoline:$CW_C" "d:defwrongrole:$CW_D"; do
  _cr="${_cw#*:}"; _cj="${_cr#*:}"; _cr="${_cr%%:*}"
  rm -f "$LEDGER"; raw "$CONSUMER" "$(cited_twin "$_cj" "$_cr")" >/dev/null
  [ "$(lfield .definition_bound)" = "true" ] \
    && ok "CONTROL world ${_cw%%:*}: the definition is BOUND (read on its cited twin), so the cell below is decided by the body" \
    || bad "CONTROL world ${_cw%%:*}: definition_bound='$(lfield .definition_bound)' on the cited twin, expected true — the world is not the one its arm claims"
done
rm -f "$LEDGER"; raw "$CONSUMER" "$(cited_twin "$CW_E" remediator)" >/dev/null
[ "$(lfield .definition_bound)" = "false" ] \
  && ok "CONTROL world e: remediator has no definition (definition_bound=false, on its cited twin)" \
  || bad "CONTROL world e: definition_bound='$(lfield .definition_bound)', expected false"

TIP_A="$(ccell "$HOOK" "$CW_A" defok)"
[ "$TIP_A" = "allow:1:true/definition" ] \
  && ok "(a) definition-bound, subagent_type-only, no prompt citation -> allowed, cited=true contract_via=definition" \
  || bad "(a) scored '$TIP_A', expected 'allow:1:true/definition' — the selected definition body carries the role line and the guard says it was not delivered"
TIP_B="$(ccell "$HOOK" "$CW_B" defok)"
[ "$TIP_B" = "allow:1:true/prompt" ] \
  && ok "(b) prompt citation with a definition ALSO bound -> allowed, contract_via=prompt (the prompt wins)" \
  || bad "(b) scored '$TIP_B', expected 'allow:1:true/prompt'"
TIP_C="$(ccell "$HOOK" "$CW_C" defnoline)"
[ "$TIP_C" = "allow:1:true/prompt" ] \
  && ok "(c) marked, agreeing definition whose body lacks the line -> the line is injected into the prompt, contract_via=prompt (the frontmatter is not the carrier)" \
  || bad "(c) scored '$TIP_C', expected 'allow:1:true/prompt' — a bound definition was credited without its body being read"
TIP_D="$(ccell "$HOOK" "$CW_D" defwrongrole)"
[ "$TIP_D" = "deny:0:-" ] \
  && ok "(d) role R definition carrying role S line 1 and S's embedded contract -> DENIED, no row (a foreign body is never patched with a line)" \
  || bad "(d) scored '$TIP_D', expected 'deny:0:-' — another role's contract would reach this role's teammate"
TIP_E="$(ccell "$HOOK" "$CW_E" remediator)"
[ "$TIP_E" = "deny:0:-" ] \
  && ok "(e) no definition file, no prompt citation -> DENIED, no row" \
  || bad "(e) scored '$TIP_E', expected 'deny:0:-'"

# (f) THE INPUT THE EMIT CANNOT AMEND. Two JSON documents on stdin: every read takes the first,
# so the role resolves and the definition binds, but the final decision build receives two
# values and fails, and the guard FAILS OPEN — it emits nothing and the rewrite that selects
# the definition never reaches the harness. The ledger row is written BEFORE the emit, from
# the selection, so it records true/definition anyway. THIS ARM RECORDS THAT BEHAVIOUR, it
# does not endorse it: contract_via is delivery-as-SELECTED at PreToolUse, and here the
# selection was not delivered. Asserted so a change to it is seen, in either direction.
CW_F="$(printf '%s {"x":1}' "$CW_A")"
rm -f "$LEDGER"
F_OUT="$(printf '%s' "$CW_F" | CLAUDE_PROJECT_DIR="$CONSUMER" dgrun "$HOOK" 2>/dev/null)"
[ -z "$F_OUT" ] \
  && ok "(f) CONTROL: the two-document input takes the fail-open path (no decision emitted)" \
  || bad "(f) CONTROL: the guard emitted on the two-document input, so this world is not the fail-open path: '$F_OUT'"
TIP_F="$(ccell "$HOOK" "$CW_F" defok)"
[ "$TIP_F" = "none:1:true/definition" ] \
  && ok "(f) fail-open emit: the row still records true/definition — a record of the selection, not of a rewrite that reached the harness" \
  || bad "(f) fail-open emit recorded '$TIP_F', expected 'true/definition' (the recorded behaviour changed; decide whether that is intended)"

# --- THE SESSION SNAPSHOT: the definition carrier is read from the copy THIS session loaded -------
# The harness loads .claude/agents/ once per process, so the guard credits the embedded role contract
# only from <state dir>/.agent-definitions/<session_id>/, and only when its ROLE-CONTRACT region equals
# the installed role file. Every other case cites the role file at the head of the prompt; none is denied.
# Scored `<decision>:<contract_via>:<prompt head>` (`line` when the prompt starts with the role line,
# `brief` when it is the brief as sent, `-` when no updatedInput prompt came back):
#   sa  positive: snapshot current, region equals the role file   -> allow:definition:brief
#   sm  missing snapshot (a session the snapshot step never saw)   -> allow:prompt:line
#   ss  stale: role file edited AND re-rendered after the snapshot -> allow:prompt:line
# ss is the mid-session re-render: the on-disk definition is current again, so a guard reading it
# instead of the snapshot would credit a body this session does not hold and score sa's cell.
snapcell() { # snapcell <consumer> <json> -> the score above
  local o d v h
  rm -f "$1/_bmad-output/spawn-ledger.jsonl"
  o="$(printf '%s' "$2" | CLAUDE_PROJECT_DIR="$1" dgrun "$HOOK" 2>/dev/null)"
  d="$(jq -r '.hookSpecificOutput.permissionDecision // "none"' <<<"$o" 2>/dev/null)"; [ -n "$d" ] || d=none
  v="$(tail -1 "$1/_bmad-output/spawn-ledger.jsonl" 2>/dev/null | jq -r '.contract_via | tostring' 2>/dev/null)"
  h="$(jq -r '.hookSpecificOutput.updatedInput.prompt // "-"' <<<"$o" 2>/dev/null | head -1)"
  case "$h" in
    'Your operating contract is `.claude/team-roles/defok.md`. Read it and follow it as your FIRST action'*) h=line ;;
    'Do the work.') h=brief ;;
    *) h="-" ;;
  esac
  printf '%s:%s:%s' "$d" "${v:--}" "$h"
}
SN_SA="$(snapcell "$CONSUMER" "$CW_A")"
[ "$SN_SA" = "allow:definition:brief" ] \
  && ok "(sa) snapshot current and its region equals the role file -> the definition carries the contract, the brief is sent as written" \
  || bad "(sa) scored '$SN_SA', expected 'allow:definition:brief'"
SN_SM="$(snapcell "$CONSUMER" "$(jq -c '.session_id = "s-dmg-nosnap"' <<<"$CW_A")")"
[ "$SN_SM" = "allow:prompt:line" ] \
  && ok "(sm) no snapshot for this session -> the role line is put at the head of the prompt, contract_via=prompt, never a deny" \
  || bad "(sm) scored '$SN_SM', expected 'allow:prompt:line'"
SS_W="$WORK/snapstale"
rm -rf "$SS_W"; cp -R "$CONSUMER" "$SS_W"
printf 'A clause added mid-session.\n' >> "$SS_W/.claude/team-roles/defok.md"
awk -v rf="$SS_W/.claude/team-roles/defok.md" '/^<!-- ROLE-CONTRACT BEGIN /{print; while ((getline l < rf) > 0) print l; skip=1; next}
  /^<!-- ROLE-CONTRACT END -->$/{skip=0} !skip' "$CONSUMER/.claude/agents/defok.md" > "$SS_W/.claude/agents/defok.md"
grep -qxF 'A clause added mid-session.' "$SS_W/.claude/agents/defok.md" \
  && ! grep -qxF 'A clause added mid-session.' "$SS_W/_bmad-output/.agent-definitions/s-dmg-1/defok.md" \
  && ok "(ss) CONTROL: the on-disk definition carries the edited role file and the snapshot does not" \
  || bad "(ss) CONTROL: the re-render or the snapshot is not the world this arm claims"
SN_SS="$(snapcell "$SS_W" "$CW_A")"
[ "$SN_SS" = "allow:prompt:line" ] \
  && ok "(ss) role file edited and re-rendered after the snapshot -> the snapshot body is stale, the role line is put at the head of the prompt" \
  || bad "(ss) scored '$SN_SS', expected 'allow:prompt:line' — a body this session does not hold was credited"

# --- THE SHARD LINE: AN INVENTED SERIAL EXCEPTION IS RECORDED, NEVER LAUNDERED TO NULL --------
# Rule 28 names four serial exceptions. A `none` naming anything else records
# `invalid-exception` plus the lead text in `shard_raw`, which Check 22 arm S3 FAILS on. Seeded
# from what leads actually wrote: the consumer briefs carried `none (serial-document). Files
# you may edit...` (a valid exception followed by prose) and reasons outside the four.
#
# SIX WORLDS, ONE PROPERTY EACH, every drive behind an epoch row that is not the subject:
#   inv   `none (serial cross-file repair: a, b)`  -> invalid-exception|<that text>
#   ac    `none (authoring-chain)`                  -> none (3)|null
#   sd    `none (serial-document). Files you...`    -> none (4)|null     (trailing prose ignored)
#   dash  `none — serial because`                   -> invalid-exception|<that text>
#   two   an invented line AND a valid line         -> invalid-exception (a repeat cannot launder it)
#   ord   `3/7 x`                                   -> 3/7 x|null        (the awk ran at all)
#   upper `SHARD: none (made up)`                   -> invalid-exception (the KEY is case-folded)
#   wrap  `shard: **none (made up)**`               -> invalid-exception (the VALUE is unwrapped)
#   title `Shard: None (4)`                         -> none (4)          (key AND token folded)
# `ord` is in the vector so an awk that dies reads as every cell moving. The last three are spellings no consumer brief carries today; each
# laundered an invented exception to null before the fold and the unwrap existed.
#
# THESE WORLDS DRIVE `dev-escalated`, A NON-SHARDABLE ROLE, ON PURPOSE. On a shardable role the
# guard now REFUSES an invented exception before any row is written (THE SHARD DENY), so a
# remediator subject would leave the parse with no row to read and
# no subject. `dev-escalated` is outside the guard's fixed shardable list and the seeded role
# files carry no party-seat sentence, so the parse is still recorded here. The deny is asserted
# by its own pair below (SHARD DENY), one property apart from these worlds.
SHARD_EPOCH="$(mkjson Agent gate-adjudicator opus)"
shard_payload() { # shard_payload <brief lines...> -> a dev-escalated (non-shardable) dispatch carrying them
  local p; p="Your operating contract is \`.claude/team-roles/dev-escalated.md\`. Read it first."
  for _l in "$@"; do p="$p"$'\n'"$_l"; done
  jq -nc --arg p "$p"$'\n'"Do the work." '{tool_name:"Agent",tool_input:{name:"rem-shard",prompt:$p}}'
}
SH_INV="$(shard_payload 'shard: none (serial cross-file repair: a, b)')"
SH_AC="$(shard_payload 'shard: none (authoring-chain)')"
SH_SD="$(shard_payload 'shard: none (serial-document). Files you may edit: docs/a.md')"
SH_DASH="$(shard_payload 'shard: none — serial because the files interlock')"
SH_TWO="$(shard_payload 'shard: none (invented reason)' 'shard: none (4)')"
SH_ORD="$(shard_payload 'shard: 3/7 x')"
SH_UPPER="$(shard_payload 'SHARD: none (made up)')"
SH_WRAP="$(shard_payload 'shard: **none (made up)**')"
SH_TITLE="$(shard_payload 'Shard: None (4)')"
# scell <guard> <json> -> "<shard>|<shard_raw>" of the subject row (row 2), or a diagnostic.
scell() {
  local n
  rm -f "$LEDGER"
  printf '%s' "$SHARD_EPOCH" | CLAUDE_PROJECT_DIR="$CONSUMER" dgrun "$1" >/dev/null 2>&1
  printf '%s' "$2" | CLAUDE_PROJECT_DIR="$CONSUMER" dgrun "$1" >/dev/null 2>&1
  n="$(wc -l < "$LEDGER" 2>/dev/null | tr -d ' ')"
  [ "$n" = 2 ] || { printf 'ROWS=%s' "${n:-0}"; return; }
  tail -1 "$LEDGER" | jq -r 'if .role == "dev-escalated" then "\(.shard | tostring)|\(.shard_raw | tostring)" else "WRONGROW:\(.role)" end' 2>/dev/null
}
svec() {
  printf 'inv=%s;ac=%s;sd=%s;dash=%s;two=%s;ord=%s;upper=%s;wrap=%s;title=%s' \
    "$(scell "$1" "$SH_INV")" "$(scell "$1" "$SH_AC")" "$(scell "$1" "$SH_SD")" \
    "$(scell "$1" "$SH_DASH")" "$(scell "$1" "$SH_TWO")" "$(scell "$1" "$SH_ORD")" \
    "$(scell "$1" "$SH_UPPER")" "$(scell "$1" "$SH_WRAP")" "$(scell "$1" "$SH_TITLE")"
}
SV_INV='inv=invalid-exception|none (serial cross-file repair: a, b)'
SV_AC='ac=none (3)|null'
SV_SD='sd=none (4)|null'
SV_DASH='dash=invalid-exception|none — serial because the files interlock'
SV_TWO='two=invalid-exception|none (invented reason)'
SV_ORD='ord=3/7 x|null'
SV_UPPER='upper=invalid-exception|none (made up)'
SV_WRAP='wrap=invalid-exception|none (made up)'
SV_TITLE='title=none (4)|null'
SV_TIP="$(svec "$HOOK")"
for _c in "$SV_INV" "$SV_AC" "$SV_SD" "$SV_DASH" "$SV_TWO" "$SV_ORD" "$SV_UPPER" "$SV_WRAP" "$SV_TITLE"; do
  case ";$SV_TIP;" in
    *";$_c;"*) ok "SHARD ${_c%%=*}: recorded '${_c#*=}' (shard|shard_raw)" ;;
    *) bad "SHARD ${_c%%=*}: expected '${_c#*=}', got vector '$SV_TIP'" ;;
  esac
done

# THE ROW SURVIVES A RAW TEXT CUT INSIDE A MULTIBYTE CHARACTER (non-shardable role, as above). `shard_raw` is the first 160
# bytes, and a cut through a UTF-8 sequence must not fail the single jq that writes the WHOLE
# row: losing the row would cost every other field for this one.
_mb=""; for _i in $(seq 1 100); do _mb="${_mb}é"; done
SH_MB="$(shard_payload "shard: none (x${_mb})")"
_mbc="$(scell "$HOOK" "$SH_MB")"
case "$_mbc" in
  invalid-exception\|"none (x"*) ok "SHARD multibyte: a 160-byte cut inside a UTF-8 character still writes the row (invalid-exception, raw kept)" ;;
  *) bad "SHARD multibyte: a raw text cut inside a UTF-8 character recorded '$_mbc' — the row build failed or the value changed" ;;
esac

# --- THE SHARD DENY: AN INVENTED EXCEPTION ON A SHARDABLE ROLE IS REFUSED, WITH NO ROW --------
# The row a shardable role writes under `invalid-exception` is one Check 22 arm S3 FAILS, so the
# guard refuses the dispatch before the ledger append. Scored as ONE vector of
# `<decision>:<rows added after the epoch>:<row-2 shard>` cells; the decision is read literally
# (`none` when the hook printed nothing), never normalised, so a crashed hook cannot pass for an
# allowed one. The pair `rinv`/`ninv` is ONE property apart (the role): the same invented line is
# denied with no row on `remediator` and recorded on `dev-escalated`. The other cells are
# shardable-role spellings that must stay allowed with their row.
dpayload() { # dpayload <role> [brief line] -> an Agent dispatch of <role> carrying the line
  local p; p="Your operating contract is \`.claude/team-roles/$1.md\`. Read it first."
  [ -n "${2-}" ] && p="$p"$'\n'"$2"
  jq -nc --arg p "$p"$'\n'"Do the work." '{tool_name:"Agent",tool_input:{name:"shard-deny",prompt:$p}}'
}
DOUT=""; DCELL=""
dcell() { # dcell <guard> <role> [brief line] -> prints "<decision>:<rows added>:<row-2 shard>"
  # and sets DCELL to it and DOUT to the hook's stdout (call without $( ) to keep the two).
  local n d s
  rm -f "$LEDGER"
  printf '%s' "$SHARD_EPOCH" | CLAUDE_PROJECT_DIR="$CONSUMER" dgrun "$1" >/dev/null 2>&1
  DOUT="$(dpayload "$2" "${3-}" | CLAUDE_PROJECT_DIR="$CONSUMER" dgrun "$1" 2>/dev/null)"
  d="$(jq -r '.hookSpecificOutput.permissionDecision // "none"' <<<"$DOUT" 2>/dev/null)"
  [ -n "$d" ] || d=none
  n="$(wc -l < "$LEDGER" 2>/dev/null | tr -d ' ')"; n="${n:-0}"
  if [ "$n" = 2 ]; then s="$(tail -1 "$LEDGER" | jq -r '.shard | tostring' 2>/dev/null)"; else s=-; fi
  DCELL="$d:$((n - 1)):$s"
  printf '%s' "$DCELL"
}
DINV='shard: none (serial cross-section remediator, after join)'
# THE DENY READS THE SHARDABLE SET, NOT THE WORD `remediator`. Two more denied cells carry the
# same invented line on shardable roles that are not the remediator: `qa` (a member of the fixed
# list, with no role file in this consumer) and `seatx`, a party seat the set picks up only from
# its role file's opening line. A deny keyed on the literal role `remediator` keeps rinv and
# loses both of these.
printf 'The lead spawns you as a party-mode persona. You speak as seatx.\n' > "$CONSUMER/.claude/team-roles/seatx.md"
dvec() {
  printf 'rinv=%s;qinv=%s;pinv=%s;ninv=%s;rac=%s;r3=%s;r11=%s;romit=%s;rsd=%s;rtitle=%s;rord=%s' \
    "$(dcell "$1" remediator "$DINV")" "$(dcell "$1" qa "$DINV")" "$(dcell "$1" seatx "$DINV")" \
    "$(dcell "$1" dev-escalated "$DINV")" \
    "$(dcell "$1" remediator 'shard: none (authoring-chain)')" "$(dcell "$1" remediator 'shard: none (3)')" \
    "$(dcell "$1" remediator 'shard: 1/1 x')" "$(dcell "$1" remediator)" \
    "$(dcell "$1" remediator 'shard: none (serial-document). Files you may edit: docs/a.md')" \
    "$(dcell "$1" remediator 'Shard: None (4)')" "$(dcell "$1" remediator 'shard: 3/7 x')"
}
DV_RINV='rinv=deny:0:-'
DV_QPINV='qinv=deny:0:-;pinv=deny:0:-'
DV_NINV='ninv=allow:1:invalid-exception'
DV_REST='rac=allow:1:none (3);r3=allow:1:none (3);r11=allow:1:1/1 x;romit=allow:1:null;rsd=allow:1:none (4);rtitle=allow:1:none (4);rord=allow:1:3/7 x'
DV_WANT="$DV_RINV;$DV_QPINV;$DV_NINV;$DV_REST"
DV_TIP="$(dvec "$HOOK")"
_old_ifs="$IFS"; IFS=';'
for _c in $DV_WANT; do
  case ";$DV_TIP;" in
    *";$_c;"*) ok "SHARD DENY ${_c%%=*}: '${_c#*=}' (decision:rows added:shard)" ;;
    *) bad "SHARD DENY ${_c%%=*}: expected '${_c#*=}', got vector '$DV_TIP'" ;;
  esac
done
IFS="$_old_ifs"

# The deny reason keeps the raw invented text, since no row carries `shard_raw` for it.
dcell "$HOOK" remediator "$DINV" >/dev/null
_drs="$(jq -r '.hookSpecificOutput.permissionDecisionReason // empty' <<<"$DOUT" 2>/dev/null)"
case "$_drs" in
  *"$DINV"*) ok "SHARD DENY reason: quotes the raw line '$DINV'" ;;
  *) bad "SHARD DENY reason does not quote '$DINV': '$(printf '%s' "$_drs" | cut -c1-200)'" ;;
esac
case "$_drs" in
  *"shard: none (authoring-chain)"*) ok "  and names 'shard: none (authoring-chain)' for the serial remediator" ;;
  *) bad "  the deny reason does not name 'shard: none (authoring-chain)'" ;;
esac

# A DENIED BRIEF RE-SENT WITH A VALID LINE IS ALLOWED, AND ONLY THE RE-SEND WRITES A ROW. The
# ledger is NOT cleared between the two drives, so the deny must have left exactly the epoch.
rm -f "$LEDGER"
printf '%s' "$SHARD_EPOCH" | CLAUDE_PROJECT_DIR="$CONSUMER" dgrun "$HOOK" >/dev/null 2>&1
_rs1="$(dpayload remediator "$DINV" | CLAUDE_PROJECT_DIR="$CONSUMER" dgrun "$HOOK" 2>/dev/null)"
_rs1d="$(jq -r '.hookSpecificOutput.permissionDecision // "none"' <<<"$_rs1" 2>/dev/null)"
_rs1n="$(wc -l < "$LEDGER" 2>/dev/null | tr -d ' ')"
_rs2="$(dpayload remediator 'shard: none (authoring-chain)' | CLAUDE_PROJECT_DIR="$CONSUMER" dgrun "$HOOK" 2>/dev/null)"
_rs2d="$(jq -r '.hookSpecificOutput.permissionDecision // "none"' <<<"$_rs2" 2>/dev/null)"
_rs2n="$(wc -l < "$LEDGER" 2>/dev/null | tr -d ' ')"
_rs2s="$(tail -1 "$LEDGER" 2>/dev/null | jq -r '.shard | tostring' 2>/dev/null)"
[ "$_rs1d:$_rs1n:$_rs2d:$_rs2n:$_rs2s" = "deny:1:allow:2:none (3)" ] \
  && ok "SHARD DENY re-send: denied with the epoch row only, then the corrected brief is allowed and records none (3)" \
  || bad "SHARD DENY re-send: got '$_rs1d:$_rs1n:$_rs2d:$_rs2n:$_rs2s', expected 'deny:1:allow:2:none (3)'"

# A RAW TEXT CUT INSIDE A MULTIBYTE CHARACTER ON THE DENY PATH: the reason carries the raw prefix,
# and the hook's output must still be one valid JSON object, or the harness reads no decision.
dcell "$HOOK" remediator "shard: none (x${_mb})" >/dev/null; _mbd="$DCELL"
if [ "$_mbd" = "deny:0:-" ] && jq -e . >/dev/null 2>&1 <<<"$DOUT" \
   && case "$(jq -r '.hookSpecificOutput.permissionDecisionReason // empty' <<<"$DOUT" 2>/dev/null)" in *"shard: none (x"*) true ;; *) false ;; esac; then
  ok "SHARD DENY multibyte: a 160-byte cut inside a UTF-8 character still emits a valid deny carrying the raw prefix"
else
  bad "SHARD DENY multibyte: cell '$_mbd', output '$(printf '%s' "$DOUT" | cut -c1-200)'"
fi

rm -f "$CONSUMER/.claude/team-roles/seatx.md"

# --- THE COVER DENY: THE ONE CROSS AGENT (G=1) WHOSE ORDINALS OMIT A PART OF 1..K -----------
# Arm S4 fails such a row at the gate, so the guard refuses it before the append, naming the
# missing ordinals. Cells reuse dcell's `<decision>:<rows added after the epoch>:<row-2 shard>`.
# gap/full are ONE property apart (ordinal 3); the G>1 per-group cross covers a subset by design
# and is untouched; zpad is the zero-padded full list partition-document.sh emits at K>=10.
xvec() { # xvec <guard> <gap cell, already scored by the caller outside any $( )>
  printf 'gap=%s;full=%s;group=%s;zpad=%s' \
    "$2" "$(dcell "$1" remediator 'shard: cross/3 g1/1 1,2,3')" \
    "$(dcell "$1" remediator 'shard: cross/3 g1/2 1,2')" "$(dcell "$1" remediator 'shard: cross/3 g1/1 01,02,03')"
}
XV_WANT='gap=deny:0:-;full=allow:1:cross/3 g1/1 1,2,3;group=allow:1:cross/3 g1/2 1,2;zpad=allow:1:cross/3 g1/1 01,02,03'
# The gap cell runs ONCE, unwrapped, so its DOUT survives for the reason check below; the vector reuses its value.
dcell "$HOOK" remediator 'shard: cross/3 g1/1 1,2' >/dev/null
_xgap="$DCELL"; _xrs="$(jq -r '.hookSpecificOutput.permissionDecisionReason // empty' <<<"$DOUT" 2>/dev/null)"
XV_TIP="$(xvec "$HOOK" "$_xgap")"
_old_ifs="$IFS"; IFS=';'
for _c in $XV_WANT; do
  case ";$XV_TIP;" in
    *";$_c;"*) ok "COVER DENY ${_c%%=*}: '${_c#*=}' (decision:rows added:shard)" ;;
    *) bad "COVER DENY ${_c%%=*}: expected '${_c#*=}', got vector '$XV_TIP'" ;;
  esac
done
IFS="$_old_ifs"
case "$_xrs" in *"omits part(s) 3 of 1..3"*) ok "COVER DENY reason names the missing ordinal: 'omits part(s) 3 of 1..3'" ;;
  *) bad "COVER DENY reason does not name ordinal 3: '$(printf '%s' "$_xrs" | cut -c1-200)'" ;; esac
# --- THE COVER DENY READS ONLY THE ORDINAL LIST: A PROSE SUFFIX IS IGNORED (BL-887) -------------
# The list is the longest leading run of digits, commas, blanks and tabs after `g1/1 `. A complete
# list followed by either suffix shape a consumer ledger recorded (` (...)`, `. Step ...`) is
# ALLOWED: no deny AND exactly one appended row whose `.shard` is the canonical value, suffix
# included. The gap twin (ordinal 8 dropped, same suffix) is DENIED naming 8, and plain is the
# unsuffixed complete list, so a reader that refuses or accepts every suffixed line cannot pass.
XS_P='shard: cross/8 g1/1 1,2,3,4,5,6,7,8 (you are the ONE cross QA for this pass)'
XS_S='shard: cross/8 g1/1 1,2,3,4,5,6,7,8. Step test-strategy-p3. Brief: cross QA'
XS_G='shard: cross/8 g1/1 1,2,3,4,5,6,7 (you are the ONE cross QA for this pass)'
XS_N='shard: cross/8 g1/1 1,2,3,4,5,6,7,8'
xs_cell() { # xs_cell <guard> <cell> -> that cell's "decision:rows:shard" value
  case "$2" in
    sfxp) dcell "$1" remediator "$XS_P" ;; sfxs) dcell "$1" remediator "$XS_S" ;;
    sfxgap) dcell "$1" remediator "$XS_G" ;; plain) dcell "$1" remediator "$XS_N" ;;
  esac
}
XS_WANT="sfxp=allow:1:${XS_P#shard: };sfxs=allow:1:${XS_S#shard: };sfxgap=deny:0:-;plain=allow:1:${XS_N#shard: }"
# The gap cell runs ONCE, unwrapped, so its DOUT survives for the reason check.
dcell "$HOOK" remediator "$XS_G" >/dev/null
_xsgap="$DCELL"; _xsrs="$(jq -r '.hookSpecificOutput.permissionDecisionReason // empty' <<<"$DOUT" 2>/dev/null)"
XS_TIP="sfxp=$(xs_cell "$HOOK" sfxp);sfxs=$(xs_cell "$HOOK" sfxs);sfxgap=$_xsgap;plain=$(xs_cell "$HOOK" plain)"
_old_ifs="$IFS"; IFS=';'
for _c in $XS_WANT; do
  case ";$XS_TIP;" in
    *";$_c;"*) ok "COVER SUFFIX ${_c%%=*}: '${_c#*=}' (decision:rows added:shard)" ;;
    *) bad "COVER SUFFIX ${_c%%=*}: expected '${_c#*=}', got vector '$XS_TIP'" ;;
  esac
done
IFS="$_old_ifs"
case "$_xsrs" in *"omits part(s) 8 of 1..8"*) ok "COVER SUFFIX deny reason names the missing ordinal: 'omits part(s) 8 of 1..8'" ;;
  *) bad "COVER SUFFIX deny reason does not name ordinal 8 alone: '$(printf '%s' "$_xsrs" | cut -c1-200)'" ;; esac

# --- THE MARK LINE: A BRIEF WHOSE `--mark` THE ENGINE WILL REFUSE IS DENIED; A RENDERED ONE IS RECORDED ---
# dg_mark_scan is the one predicate. Each cell is `<decision>:<rows written>:<mark field>`, the
# decision read literally (`none` when the hook printed nothing), so a crashed hook cannot pass for
# an allowed one; `-` when no row was written. Allowed cells read `allow` because the remediator
# dispatch carries no model param and is corrected, which is the same on every cell.
MCELL=""; MOUT=""
mcell() { # mcell <guard> <brief line> -> sets MCELL and MOUT
  local d n m
  rm -f "$LEDGER"
  MOUT="$(dpayload remediator "$2" | CLAUDE_PROJECT_DIR="$CONSUMER" dgrun "$1" 2>/dev/null)"
  d="$(jq -r '.hookSpecificOutput.permissionDecision // "none"' <<<"$MOUT" 2>/dev/null)"; [ -n "$d" ] || d=none
  n="$(wc -l < "$LEDGER" 2>/dev/null | tr -d ' ')"; n="${n:-0}"
  if [ "$n" = 1 ]; then m="$(jq -r '.mark | tostring' "$LEDGER" 2>/dev/null)"; else m=-; fi
  MCELL="$d:$n:$m"
}
ML_ROWS='/p/scripts/ai-dlc/wait-for-deliverable.sh --mark /x/dv.md deploy-validate qa deferred-ac-predicates rows=34'
ML_CHAIN='cd /x && /p/wait-for-deliverable.sh --mark /f.md s q k rows=3'
ML_PH='Close it with `<lead engine>/wait-for-deliverable.sh --mark <file> <step> <role> <shard> findings=<n>`.'
ML_RED='/p/wait-for-deliverable.sh --mark /f.md deploy-validate ops a2 findings=<number of RED verdicts>'
ML_PROSE='Then run /p/wait-for-deliverable.sh --mark /f.md deploy-validate qa k findings=0. Evidence blocks come first.'
ML_S319='When done run /g/scripts/ai-dlc/wait-for-deliverable.sh --mark /g/_bmad-output/dv-s319.md deploy-validate qa deferred-ac-predicates rows=<n>. A trailer naming the model goes last.'
ML_NONE='Write the result to /f.md and stop.'
ML_GOOD='/g/scripts/ai-dlc/wait-for-deliverable.sh --mark /g/_bmad-output/dv.md deploy-validate qa deferred-ac-predicates findings=0'
mvec() {
  local o=""
  mcell "$1" "$ML_ROWS";  o="rows=$MCELL"
  mcell "$1" "$ML_CHAIN"; o="$o;chain=$MCELL"
  mcell "$1" "$ML_PH";    o="$o;ph=$MCELL"
  mcell "$1" "$ML_RED";   o="$o;red=$MCELL"
  mcell "$1" "$ML_PROSE"; o="$o;prose=$MCELL"
  mcell "$1" "$ML_S319";  o="$o;s319=$MCELL"
  mcell "$1" "$ML_NONE";  o="$o;none=$MCELL"
  mcell "$1" "$ML_GOOD";  o="$o;good=$MCELL"
  printf '%s' "$o"
}
MV_WANT='rows=deny:0:-;chain=deny:0:-;ph=allow:1:rendered;red=allow:1:rendered;prose=allow:1:rendered;s319=deny:0:-;none=allow:1:null;good=allow:1:rendered'
MV_TIP="$(mvec "$HOOK")"
_old_ifs="$IFS"; IFS=';'
for _c in $MV_WANT; do
  case ";$MV_TIP;" in
    *";$_c;"*) ok "MARK LINE ${_c%%=*}: '${_c#*=}' (decision:rows:mark)" ;;
    *) bad "MARK LINE ${_c%%=*}: expected '${_c#*=}', got vector '$MV_TIP'" ;;
  esac
done
IFS="$_old_ifs"
# The deny text is the engine refusal plus the corrected line, rendered from the offending one.
mcell "$HOOK" "$ML_ROWS"
_mrs="$(jq -r '.hookSpecificOutput.permissionDecisionReason // empty' <<<"$MOUT" 2>/dev/null)"
case "$_mrs" in
  *"the last field must be findings=<n> (got 'rows=34')"*"/p/scripts/ai-dlc/wait-for-deliverable.sh --mark /x/dv.md deploy-validate qa deferred-ac-predicates findings=<n>"*)
    ok "MARK LINE reason: the engine refusal naming rows=34, then the rendered line to copy" ;;
  *) bad "MARK LINE reason lacks the refusal or the rendered line: '$(printf '%s' "$_mrs" | cut -c1-300)'" ;;
esac
# THE FIELD RULE: a trigger alone writes no field. `rendered` is written only for a line the engine's
# arity and last-field check would ACCEPT -- five fields or more (the file plus four) with the last
# starting `findings=`. Each of these lines triggers the scan and is not denied, and the engine
# refuses every one (exit 64), so a field on any of them arms --complete on a marker that never
# lands. Cell fgood is the well-formed control in the same vector.
MF_NOFIND='/p/wait-for-deliverable.sh --mark /f.md s q k'
MF_ZERO='/p/wait-for-deliverable.sh --mark /f.md s q k 0'
MF_BARE='/p/wait-for-deliverable.sh --mark /f.md'
MF_PROSE='Do NOT run wait-for-deliverable.sh --mark yourself; the lead does.'
MF_SHORT='/p/wait-for-deliverable.sh --mark /f.md s findings=0'
# The reference consumer's s319 ops brief: the engine reads the last field as `findings=0)`.
MF_PAREN='all: /g/wait-for-deliverable.sh --mark /g/dv-4b-a1.md deploy-validate ops a1 findings=0 (the last field must be findings=<n>, use findings=<number of RED probes>). If anything looks unsafe, stop.'
# One well-formed line beside one refused line: the field is owed to neither.
MF_MIXED="$ML_GOOD
$MF_NOFIND"
mfvec() {
  local o=""
  mcell "$1" "$MF_NOFIND"; o="nofind=$MCELL"
  mcell "$1" "$MF_ZERO";   o="$o;zero=$MCELL"
  mcell "$1" "$MF_BARE";   o="$o;bare=$MCELL"
  mcell "$1" "$MF_PROSE";  o="$o;fprose=$MCELL"
  mcell "$1" "$MF_SHORT";  o="$o;short=$MCELL"
  mcell "$1" "$MF_PAREN";  o="$o;paren=$MCELL"
  mcell "$1" "$MF_MIXED";  o="$o;mixed=$MCELL"
  mcell "$1" "$ML_GOOD";   o="$o;fgood=$MCELL"
  printf '%s' "$o"
}
MF_WANT='nofind=allow:1:null;zero=allow:1:null;bare=allow:1:null;fprose=allow:1:null;short=allow:1:null;paren=allow:1:null;mixed=allow:1:null;fgood=allow:1:rendered'
MF_TIP="$(mfvec "$HOOK")"
_old_ifs="$IFS"; IFS=';'
for _c in $MF_WANT; do
  case ";$MF_TIP;" in
    *";$_c;"*) ok "MARK FIELD ${_c%%=*}: '${_c#*=}' (decision:rows:mark)" ;;
    *) bad "MARK FIELD ${_c%%=*}: expected '${_c#*=}', got vector '$MF_TIP'" ;;
  esac
done
IFS="$_old_ifs"

# THE SEAT FILE (`mark_file`): the row names the file its brief marks, copied from the brief, ONLY when exactly one
# invocation triggered and the row carries `mark: "rendered"`. Each cell is `<decision>:<rows>:<mark>:<mark_file>`.
# G-c1 one well-formed invocation -> its path, and `mark` still `rendered`; G-c2 no `--mark` -> neither key;
# G-c3 two well-formed invocations -> `mark` but no `mark_file` (no single file is named).
# G-c4 one invocation whose consumer root carries a BLANK -> `mark_file` is the `party-mode/s321/<basename>` tail, not
# the text before the blank; G-c5 is the same brief with no blank, its twin. Both read `tail` when the recorded value
# ends in `party-mode/s321/<seat basename>`, else the raw value, so the twin is equal whether the tail is extracted or not.
GF_ONE='Run `/g/scripts/ai-dlc/wait-for-deliverable.sh --mark /g/_bmad-output/party-mode/s321/architecture-dev-01.md architecture dev 1/6 findings=0`.'
GF_TWO='Run `/p/wait-for-deliverable.sh --mark /f.md s q k findings=0`, then `/p/wait-for-deliverable.sh --mark /f2.md s q k2 findings=1`.'
GF_BLANK='Run `/Users/n8/My Drive/graph/scripts/ai-dlc/wait-for-deliverable.sh --mark /Users/n8/My Drive/graph/_bmad-output/party-mode/s321/architecture-tea-01.md architecture tea 1/6 findings=0`.'
GF_NOBLANK='Run `/Users/n8/graph/scripts/ai-dlc/wait-for-deliverable.sh --mark /Users/n8/graph/_bmad-output/party-mode/s321/architecture-tea-01.md architecture tea 1/6 findings=0`.'
# G-c6: the same brief with its path double-quoted -> the tail stops before the closing `"`.
GF_QUOTED='Run `/Users/n8/graph/scripts/ai-dlc/wait-for-deliverable.sh --mark "/Users/n8/graph/_bmad-output/party-mode/s321/architecture-tea-01.md" architecture tea 1/6 findings=0`.'
# G-c7: the same brief with its path single-quoted -> the tail stops before the closing apostrophe.
GF_SQUOTED="Run \`/Users/n8/graph/scripts/ai-dlc/wait-for-deliverable.sh --mark '/Users/n8/graph/_bmad-output/party-mode/s321/architecture-tea-01.md' architecture tea 1/6 findings=0\`."
# G-c8: an unfilled `<...>` seat-file argument (the placeholder a remediator brief carried) names no seat, so the row records
# no mark_file; G-c9 is its near-miss, a real path merely containing `<`, which stays rendered with its path.
GF_PH='Run `/g/scripts/ai-dlc/wait-for-deliverable.sh --mark <record> architecture dev 1/6 findings=0`.'
GF_PHNEAR='Run `/g/scripts/ai-dlc/wait-for-deliverable.sh --mark /g/<x>.md architecture dev 1/6 findings=0`.'
GCELL=""
gcell() { # gcell <guard> <brief line> -> sets GCELL
  local d n m f
  rm -f "$LEDGER"
  MOUT="$(dpayload remediator "$2" | CLAUDE_PROJECT_DIR="$CONSUMER" dgrun "$1" 2>/dev/null)"
  d="$(jq -r '.hookSpecificOutput.permissionDecision // "none"' <<<"$MOUT" 2>/dev/null)"; [ -n "$d" ] || d=none
  n="$(wc -l < "$LEDGER" 2>/dev/null | tr -d ' ')"; n="${n:-0}"
  if [ "$n" = 1 ]; then m="$(jq -r '"\(.mark):\(.mark_file)"' "$LEDGER" 2>/dev/null)"; else m="-:-"; fi
  GCELL="$d:$n:$m"
}
gf_cell() { # gf_cell <guard> <cell> -> that cell's value
  local j
  case "$2" in gc1) j="$GF_ONE" ;; gc2) j="$ML_NONE" ;; gc3) j="$GF_TWO" ;; gc4) j="$GF_BLANK" ;; gc5) j="$GF_NOBLANK" ;; gc6) j="$GF_QUOTED" ;; gc7) j="$GF_SQUOTED" ;; gc8) j="$GF_PH" ;; gc9) j="$GF_PHNEAR" ;; esac
  gcell "$1" "$j"
  case "$2:$GCELL" in gc[4567]:*:*party-mode/s321/architecture-tea-01.md) GCELL="${GCELL%:*}:tail" ;; esac
  printf '%s' "$GCELL"
}
GF_WANT='gc1=allow:1:rendered:party-mode/s321/architecture-dev-01.md;gc2=allow:1:null:null;gc3=allow:1:rendered:null;gc4=allow:1:rendered:tail;gc5=allow:1:rendered:tail;gc6=allow:1:rendered:tail;gc7=allow:1:rendered:tail;gc8=allow:1:rendered:null;gc9=allow:1:rendered:/g/<x>.md'
GF_TIP="gc1=$(gf_cell "$HOOK" gc1);gc2=$(gf_cell "$HOOK" gc2);gc3=$(gf_cell "$HOOK" gc3);gc4=$(gf_cell "$HOOK" gc4);gc5=$(gf_cell "$HOOK" gc5);gc6=$(gf_cell "$HOOK" gc6);gc7=$(gf_cell "$HOOK" gc7);gc8=$(gf_cell "$HOOK" gc8);gc9=$(gf_cell "$HOOK" gc9)"
_old_ifs="$IFS"; IFS=';'
for _c in $GF_WANT; do
  case ";$GF_TIP;" in
    *";$_c;"*) ok "MARK FILE G-${_c%%=*}: '${_c#*=}' (decision:rows:mark:mark_file)" ;;
    *) bad "MARK FILE G-${_c%%=*}: expected '${_c#*=}', got vector '$GF_TIP'" ;;
  esac
done
IFS="$_old_ifs"

# THE SAME LINE: every invocation on a line is scanned, not only the first. A refused invocation
# after a good one on the same line withholds the field (or denies, for a `name=` last field), and an
# invocation ends where the token carrying the next engine name begins, so an unfenced refused one
# does not borrow the next one's `findings=`. THE TRAILING DOT: a teammate copies `findings=0.` and
# the engine refuses it, so a last field made `findings=...` only by cutting a trailing period is not
# well formed; cell nodot is the same line without the period.
SL_GOOD='/p/wait-for-deliverable.sh --mark /f.md s q k findings=0'
SL_GB="Run \`$SL_GOOD\`, then \`/p/wait-for-deliverable.sh --mark /f2.md s findings=0\`."
SL_BG="Run \`/p/wait-for-deliverable.sh --mark /f2.md s findings=0\`, then \`$SL_GOOD\`."
SL_GG="Run \`$SL_GOOD\`, then \`/p/wait-for-deliverable.sh --mark /f2.md s q k2 findings=1\`."
SL_DENY="Run \`$SL_GOOD\`, then \`/p/wait-for-deliverable.sh --mark /f2.md s q k rows=34\`."
SL_NOSEP="/p/wait-for-deliverable.sh --mark /f2.md s q k rows=3; $SL_GOOD"
SL_DOT="Then run $SL_GOOD."
SL_NODOT="Then run $SL_GOOD"
# THE BOUND KEYS ON AN INVOCATION, not on any token naming the engine: a field that merely CONTAINS
# the engine name stays a field the engine reads. engtok-log and engtok-prose end in such a token,
# which the engine takes as the last field and refuses; engtok-deny is a name= last field carrying
# the name; engtok-path is a well-formed line whose FILE carries the name.
SL_ETLOG="Run /p/wait-for-deliverable.sh --mark a.md s1 qa none findings=0 wait-for-deliverable.sh.log"
SL_ETPROSE="Run /p/wait-for-deliverable.sh --mark a.md s1 qa none findings=0 (wait-for-deliverable.sh refuses any other last field)"
SL_ETDENY="Run /p/wait-for-deliverable.sh --mark a.md s1 qa 1 x=wait-for-deliverable.sh"
SL_ETPATH="Run /p/wait-for-deliverable.sh --mark /x/wait-for-deliverable.sh.md s1 qa none findings=0"
slvec() {
  local o=""
  mcell "$1" "$SL_GB";    o="samelinegb=$MCELL"
  mcell "$1" "$SL_BG";    o="$o;samelinebg=$MCELL"
  mcell "$1" "$SL_GG";    o="$o;samelinegg=$MCELL"
  mcell "$1" "$SL_DENY";  o="$o;sameline-deny=$MCELL"
  mcell "$1" "$SL_NOSEP"; o="$o;nosep=$MCELL"
  mcell "$1" "$SL_DOT";   o="$o;dot=$MCELL"
  mcell "$1" "$SL_NODOT"; o="$o;nodot=$MCELL"
  mcell "$1" "$SL_ETLOG";   o="$o;engtok-log=$MCELL"
  mcell "$1" "$SL_ETPROSE"; o="$o;engtok-prose=$MCELL"
  mcell "$1" "$SL_ETDENY";  o="$o;engtok-deny=$MCELL"
  mcell "$1" "$SL_ETPATH";  o="$o;engtok-path=$MCELL"
  printf '%s' "$o"
}
SL_WANT='samelinegb=allow:1:null;samelinebg=allow:1:null;samelinegg=allow:1:rendered;sameline-deny=deny:0:-;nosep=deny:0:-;dot=allow:1:null;nodot=allow:1:rendered;engtok-log=allow:1:null;engtok-prose=allow:1:null;engtok-deny=deny:0:-;engtok-path=allow:1:rendered'
SL_TIP="$(slvec "$HOOK")"
_old_ifs="$IFS"; IFS=';'
for _c in $SL_WANT; do
  case ";$SL_TIP;" in
    *";$_c;"*) ok "MARK LINE ${_c%%=*}: '${_c#*=}' (decision:rows:mark)" ;;
    *) bad "MARK LINE ${_c%%=*}: expected '${_c#*=}', got vector '$SL_TIP'" ;;
  esac
done
IFS="$_old_ifs"
# The deny on the SECOND invocation renders the correction from that invocation, not the first.
mcell "$HOOK" "$SL_DENY"
_sls="$(jq -r '.hookSpecificOutput.permissionDecisionReason // empty' <<<"$MOUT" 2>/dev/null)"
case "$_sls" in
  *"(got 'rows=34')"*"/p/wait-for-deliverable.sh --mark /f2.md s q k findings=<n>"*)
    ok "MARK LINE sameline-deny reason: names rows=34 and renders the second invocation's line" ;;
  *) bad "MARK LINE sameline-deny reason does not render the second invocation: '$(printf '%s' "$_sls" | cut -c1-300)'" ;;
esac

# THE SCAN FAILS OPEN. A failed dg_mark_scan is neither a deny nor a field, so a broken scan reads
# exactly like a clean brief; this cell is the only thing that can tell the two apart. FORCED by a
# PATH shim for `awk` -- the hook resolves awk through PATH -- that exits 2 with no output ONLY for
# the awk program carrying the mark-scan token and execs the real awk for every other program, so
# the scan fails the way a broken awk would while the shard parse and frontmatter reads still run.
# The brief is the rows=34 line a working scan denies, so `allow:1:null` can only mean the scan
# failed and the dispatch went on. Cell fo-ctl is the same brief through the same PATH with the
# shim absent: denied. The shim token is checked to be in the hook before the cell is trusted.
ML_SHIM="$WORK/ml-awk-shim"; mkdir -p "$ML_SHIM"
ML_AWK="$(command -v awk)"
printf '#!/bin/bash\ncase "$*" in *wait-for-deliverable.sh*) exit 2 ;; esac\nexec %s "$@"\n' "$ML_AWK" > "$ML_SHIM/awk"
chmod +x "$ML_SHIM/awk"
# The shim must be the awk a PATH lookup finds, or the fail-open cell reads a working scan's deny.
[ "$(PATH="$ML_SHIM:$PATH" bash -c 'command -v awk')" = "$ML_SHIM/awk" ] \
  || bad "MARK LINE fail-open FIXTURE BROKEN: the awk shim is not what PATH resolves (not executable?), so the scan cannot be forced to fail"
fo_cell() { # fo_cell <guard> <path-prefix> -> "<decision>:<rows>:<mark>"
  local o d n m
  rm -f "$LEDGER"
  o="$(dpayload remediator "$ML_ROWS" | PATH="$2$PATH" CLAUDE_PROJECT_DIR="$CONSUMER" dgrun "$1" 2>/dev/null)"
  d="$(jq -r '.hookSpecificOutput.permissionDecision // "none"' <<<"$o" 2>/dev/null)"; [ -n "$d" ] || d=none
  n="$(wc -l < "$LEDGER" 2>/dev/null | tr -d ' ')"; n="${n:-0}"
  if [ "$n" = 1 ]; then m="$(jq -r 'if has("mark") then .mark else "NOKEY" end' "$LEDGER" 2>/dev/null)"; else m=-; fi
  printf '%s:%s:%s' "$d" "$n" "$m"
}
_fo_tok="$(grep -c 'BEGIN { W = "wait-for-deliverable.sh"' "$HOOK")" || _fo_tok=0
[ "$_fo_tok" = 1 ] || bad "MARK LINE fail-open FIXTURE BROKEN: the shim token is on $_fo_tok lines of the guard, expected 1, so the shim would not fail the scan"
_fo_ctl="$(fo_cell "$HOOK" "")"
[ "$_fo_ctl" = "deny:0:-" ] && ok "MARK LINE fo-ctl: the rows=34 brief with the scan intact is denied, no row ($_fo_ctl)" \
  || bad "MARK LINE fo-ctl: expected 'deny:0:-', got '$_fo_ctl'"
_fo_got="$(fo_cell "$HOOK" "$ML_SHIM:")"
[ "$_fo_got" = "allow:1:NOKEY" ] && ok "MARK LINE fail-open: awk failing inside dg_mark_scan allows the rows=34 brief and writes its row with NO mark key ($_fo_got)" \
  || bad "MARK LINE fail-open: expected 'allow:1:NOKEY', got '$_fo_got'"

# --- SPRINT STAMP: THE READER MUST NOT SPELL THE DECORATION -------------------
# EVERY SEED HERE USED TO BE THE EMPHASISED BULLET, WHICH IS THE FORM THE READER
# ALREADY ACCEPTED. That is seeding from the reader's accept-set: it proved the
# hook accepts its own grammar and stayed green while the hook resolved EMPTY on
# the plain bullet the snapshot writer actually emits. Measured over 2066 real
# snapshot revisions, the old spelling resolved nothing on 195 of them.
# Both forms are asserted BESIDE each other, in this run, because a second clean
# tree can only ask whether the read fires at all -- never whether it fires on
# the right shape. Every arm is PRESENCE-shaped: it demands a specific sprint
# value, so a hook that resolves nothing fails it rather than passing quietly.
sprint_of() { # sprint_of <snapshot-line>  -> the .sprint the guard recorded
  rm -f "$LEDGER"
  printf -- '%s\n' "$1" > "$CONSUMER/_bmad-output/pipeline-snapshot.md"
  raw "$CONSUMER" "$(mkjson Agent remediator sonnet)" >/dev/null
  lfield .sprint
}

[ "$(sprint_of '- sprint_id: 291')" = "291" ] \
  && ok "plain bullet resolves the sprint (the form the snapshot writer emits)" \
  || bad "plain '- sprint_id: 291' recorded sprint='$(sprint_of '- sprint_id: 291')', expected 291 — the reader is spelling the decoration again"

[ "$(sprint_of '- **sprint_id:** 291')" = "291" ] \
  && ok "  and the emphasised bullet still resolves it (the fix widened, it did not move)" \
  || bad "emphasised bullet recorded sprint='$(sprint_of '- **sprint_id:** 291')', expected 291 — this is the regression the fix must not cause"

# The near-miss, beside the offender: a non-numeric value is the schema saying no
# sprint is assigned yet, and null is the right answer. Without this arm the two
# above are satisfied by a read that matches anything after the colon.
[ "$(sprint_of '- sprint_id: TBD')" = "null" ] \
  && ok "  and a non-numeric value stays null (TBD/none/S270 mean no sprint is assigned)" \
  || bad "'- sprint_id: TBD' recorded sprint='$(sprint_of '- sprint_id: TBD')', expected null"

# The three readers share one expression by hand, and I104 fails the push if they
# diverge. This asserts the BEHAVIOUR the invariant protects is actually present
# in the copy this fixture drives, so a byte-identical set of three broken reads
# cannot pass on agreement alone.
printf -- '- **sprint_id:** 291\n' > "$CONSUMER/_bmad-output/pipeline-snapshot.md"

# --- 13e. THE RENDERED DEFINITION: subagent_type rewrite, name and model deleted ----
# A definition's `effort:` is APPLIED by the harness, and it is the ONLY channel that
# reaches a teammate's effort at all. Three properties, and all three must hold together or
# the dispatch silently loses its effort:
#
#   * `subagent_type` names the role, so the harness selects `.claude/agents/<role>.md`;
#   * `name` is GONE, because a name routes the spawn to the in-process teammate runner,
#     which spreads the definition's model and NOT its effort;
#   * `model` is GONE, because an explicit param outranks the definition's `model:`.
#
# EACH IS ASSERTED SEPARATELY AND THE WRONG FIXES ARE SEEDED BELOW. A single arm reading
# "the type was rewritten" passes against a guard that rewrites the type and leaves the
# name — which is the shape that reads as working and delivers nothing.
defout() { raw "$CONSUMER" "$1"; }
defui()  { defout "$1" | jq -c '.hookSpecificOutput.updatedInput' 2>/dev/null; }

DEFJ="$(mkjson Agent defok sonnet)"
[ "$(defui "$DEFJ" | jq -r '.subagent_type // "<unset>"')" = "defok" ] \
  && ok "definition-bound: subagent_type rewritten to the role (the harness selects .claude/agents/defok.md)" \
  || bad "definition-bound: subagent_type is '$(defui "$DEFJ" | jq -r '.subagent_type // "<unset>"')', expected 'defok' — the definition is not selected and its effort cannot apply"
defui "$DEFJ" | jq -e 'has("name") | not' >/dev/null 2>&1 \
  && ok "  and \`name\` is DELETED (a name routes to the teammate runner, which drops effort)" \
  || bad "  \`name\` SURVIVED the rewrite: $(defui "$DEFJ" | jq -r '.name') — the spawn goes to the runner that ignores the definition's effort"
defui "$DEFJ" | jq -e 'has("model") | not' >/dev/null 2>&1 \
  && ok "  and \`model\` is DELETED (an explicit param outranks the definition's model:)" \
  || bad "  \`model\` SURVIVED the rewrite: $(defui "$DEFJ" | jq -r '.model') — two live sources for one value"
# The prompt is amended, never replaced — same property the model path asserts.
defui "$DEFJ" | jq -e '.prompt | contains("team-roles/defok.md")' >/dev/null 2>&1 \
  && ok "  and the original prompt/role binding survives the rewrite" \
  || bad "  the rewrite dropped the prompt — the guard is replacing the input, not amending it"

# THE LEDGER RECORDS THE ACT. `name_stripped` carries the deleted value, so a reader can
# still identify the dispatch; `model_bound` is read from the DEFINITION FILE, not from
# settings, because the file is what the harness selects and the two diverge on a stale
# render. `tool_use_id` is the join key Check 22's effort arm resolves on.
rm -f "$LEDGER"
DEFJT="$(printf '%s' "$DEFJ" | jq -c '. + {tool_use_id: "toolu_FIXTURE_1"}')"
raw "$CONSUMER" "$DEFJT" >/dev/null
[ "$(lfield .definition_bound)" = "true" ] \
  && ok "  ledger records definition_bound=true" \
  || bad "  ledger recorded definition_bound='$(lfield .definition_bound)', expected true"
[ "$(lfield .name_stripped)" = "teammate-s291-1" ] \
  && ok "  ledger records the name it deleted (name_stripped), so the dispatch stays identifiable" \
  || bad "  name_stripped='$(lfield .name_stripped)', expected 'teammate-s291-1' — the deletion is unrecorded"
[ "$(lfield .model_bound)" = "opus" ] \
  && ok "  model_bound is the definition's model: line, which is what the harness applies" \
  || bad "  model_bound='$(lfield .model_bound)', expected 'opus'"
[ "$(lfield .tool_use_id)" = "toolu_FIXTURE_1" ] \
  && ok "  ledger records tool_use_id — the order-free join key Check 22's effort arm needs" \
  || bad "  tool_use_id='$(lfield .tool_use_id)', expected 'toolu_FIXTURE_1'; without it the effort arm joins on an ORDERED key and mis-pairs two same-role spawns that finish out of order"

# `effort_bound` MIRRORS `model_bound`: the DISPATCH, not the config. Read from the seeded
# definition rather than written here, for the reason model_bound is read from the file — a
# hardcoded expectation is satisfied by a guard that copies settings whenever settings and
# the definition agree, which is every green tree.
DEFOK_EFFORT="$(awk '/^effort:[[:space:]]/{sub(/^effort:[[:space:]]*/,""); print; exit}' \
                   "$CONSUMER/.claude/agents/defok.md")"
[ -n "$DEFOK_EFFORT" ] \
  && ok "  CONTROL: the seeded defok.md declares an effort ($DEFOK_EFFORT) — the arm below has a value to compare"  \
  || bad "  CONTROL is dead: .claude/agents/defok.md carries no effort: line, so the assertion below compares nothing"
[ "$(lfield .effort_bound)" = "$DEFOK_EFFORT" ] \
  && ok "  effort_bound is the definition's effort: line, which is what the harness applies" \
  || bad "  effort_bound='$(lfield .effort_bound)', expected '$DEFOK_EFFORT' from .claude/agents/defok.md"

# THE DISCRIMINATING SEED. `defnodef` pins an effort in settings and has NO rendered
# definition, so nothing binds an effort for it: the configured level reaches the teammate
# through no channel at all. A row claiming an effort
# was bound there is the defect — it is what makes an unbound dispatch read as a bound one,
# and it is what this guard recorded before `effort_bound` moved off the config.
NODEF_PIN="$(jq -r '.aiDlcRoles.defnodef.effort // ""' "$CONSUMER/.claude/settings.json")"
[ -n "$NODEF_PIN" ] && [ ! -e "$CONSUMER/.claude/agents/defnodef.md" ] \
  && ok "  CONTROL: defnodef pins effort '$NODEF_PIN' in settings AND has no rendered definition — the two states the arm below separates" \
  || bad "  CONTROL is dead: defnodef pins '$NODEF_PIN' and its definition is $( [ -e "$CONSUMER/.claude/agents/defnodef.md" ] && echo present || echo absent ) — a null here would prove nothing"
rm -f "$LEDGER"; raw "$CONSUMER" "$(mkjson Agent defnodef)" >/dev/null
[ "$(lfield .effort_bound)" = "null" ] \
  && ok "  a dispatch with no definition records effort_bound=null even though its role pins one — no channel carries that level" \
  || bad "  effort_bound='$(lfield .effort_bound)' on a dispatch that bound no effort, expected null: the field is recording the CONFIG, so a row nothing applied an effort to reads as one that did"
# ...and the row exists, so the null above is a recorded null and not an unwritten row.
[ "$(lfield .role)" = "defnodef" ] \
  && ok "  CONTROL: that dispatch wrote a row at all — the null is a recorded value, not a missing one" \
  || bad "  CONTROL: no row was written for the defnodef dispatch, so the null above is the absence of a row"

# --- 13f. A STALE DEFINITION IS NOT SELECTED --------------------------------
# A rendered file that no longer projects the config would run the teammate on a value
# nobody declared. The guard falls back to today's behaviour and SAYS so. Both stale
# shapes are asserted — model-disagrees and effort-disagrees — because the agreement test
# is a conjunction and a seed exercising one half leaves the other droppable.
for _r in defstalemodel defstaleeffort; do
  _j="$(mkjson Agent "$_r")"
  [ "$(defui "$_j" | jq -r '.subagent_type // "<unset>"')" = "<unset>" ] \
    && ok "stale definition ($_r): subagent_type NOT rewritten — a drifted render is never selected" \
    || bad "stale definition ($_r): the guard selected it anyway (subagent_type=$(defui "$_j" | jq -r '.subagent_type'))"
  rm -f "$LEDGER"; raw "$CONSUMER" "$_j" >/dev/null
  [ "$(lfield .definition_stale)" = "true" ] && [ "$(lfield .definition_bound)" = "false" ] \
    && ok "  and the row says definition_stale=true, definition_bound=false" \
    || bad "  row recorded stale='$(lfield .definition_stale)' bound='$(lfield .definition_bound)', expected true/false"
done
# ...and the drift is REPORTED to the lead, with the remedy named. A silent fallback is
# how a drifted definition stays drifted.
# Captured, not piped into `grep -q` — see the I54 note on the absent-definition arm below.
STALE_CTX="$(raw "$CONSUMER" "$(mkjson Agent defstalemodel)" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null)"
grep -q 'STALE' <<<"$STALE_CTX" \
  && ok "  and the lead is told the definition is STALE and how to re-render it" \
  || bad "  the stale fallback is silent — nothing tells the lead the binding half did not happen"

# --- 13g. AN UNMARKED FILE IS A CONSUMER'S OWN AND IS LEFT ALONE -------------
# `.claude/agents/` is consumer-writable. The seeded `defunmarked.md` AGREES with settings
# in every field and differs from a rendered one only by the marker, so this arm can only
# be satisfied by a guard that keys on the marker — not by one that keys on disagreement.
[ "$(defui "$(mkjson Agent defunmarked)" | jq -r '.subagent_type // "<unset>"')" = "<unset>" ] \
  && ok "an UNMARKED .claude/agents file is never selected, even though it agrees with settings" \
  || bad "the guard selected a file this distribution did not render — the marker is not being read"

# --- 13h. ABSENT DEFINITION: today's behaviour, and the lead is told why -----
# THE FAIL-OPEN DIRECTION. `subagent_type` must never be rewritten to a name the harness
# cannot resolve: that ERRORS the spawn, which is worse than mis-binding it.
ABSJ="$(mkjson Agent defnodef)"
[ "$(defui "$ABSJ" | jq -r '.subagent_type // "<unset>"')" = "<unset>" ] \
  && ok "absent definition: subagent_type NOT rewritten (a type the harness cannot resolve errors the spawn)" \
  || bad "absent definition: the guard rewrote subagent_type to a definition that does not exist"
[ "$(defui "$ABSJ" | jq -r '.model // "<unset>"')" = "opus" ] \
  && ok "  and today's behaviour still applies — the model is bound as before" \
  || bad "  the absent branch stopped binding the model: got '$(defui "$ABSJ" | jq -r '.model // "<unset>"')'"
rm -f "$LEDGER"; raw "$CONSUMER" "$ABSJ" >/dev/null
[ "$(lfield .definition_bound)" = "false" ] && [ "$(lfield .definition_stale)" = "false" ] \
  && ok "  row records definition_bound=false with definition_stale=false — absent and drifted are different facts" \
  || bad "  row recorded bound='$(lfield .definition_bound)' stale='$(lfield .definition_stale)', expected false/false"
# NO `| grep -q` OFF A PIPELINE (I54): grep leaves at its first match while the writer is
# still pushing, and under pipefail the pipeline answers with the writer's EPIPE — NOT-FOUND
# on input that contains the pattern, above a size threshold and with no symptom. Capture,
# then feed the reader a here-string.
ABS_CTX="$(raw "$CONSUMER" "$ABSJ" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null)"
grep -q 'no rendered .claude/agents/defnodef.md' <<<"$ABS_CTX" \
  && ok "  and the lead is told the definition is MISSING and given the render command" \
  || bad "  the missing definition is not reported — the lead cannot see that the effort binding did not happen"

# A role whose settings declare NO effort, rendered with no `effort:` line: absent must
# AGREE with absent. Without this, every such render reads as stale and binds nothing.
[ "$(defui "$(mkjson Agent defnoeffort)" | jq -r '.subagent_type // "<unset>"')" = "defnoeffort" ] \
  && ok "a definition with no effort: line AGREES with a role declaring no effort (absent == absent)" \
  || bad "a role declaring no effort was called stale against a render that correctly omits the key"

# --- 13i. IDEMPOTENCE ON THE DEFINITION PATH --------------------------------
# The rewrite emits `allow` to carry `updatedInput`, so it must not fire on a dispatch
# already in the target shape, or every correct call has its approval posture changed.
IDEMDEF="$(jq -nc --arg p "Your operating contract is \`.claude/team-roles/defok.md\`." \
  '{tool_name:"Agent",tool_input:{subagent_type:"defok",prompt:$p}}')"
expect_untouched "$CONSUMER" "$IDEMDEF" \
  "a dispatch already carrying the rewritten type, no name and no model"

# ...and the three conditions are read SEPARATELY. A guard that keyed idempotence on the
# type alone would leave a surviving `name` in place — the exact state that drops effort —
# while reporting nothing. Each near-miss differs from the idempotent call by ONE property.
IDEM_NAME="$(printf '%s' "$IDEMDEF" | jq -c '.tool_input.name = "surviving-name"')"
[ -n "$(raw "$CONSUMER" "$IDEM_NAME")" ] \
  && ok "  a correct type WITH a surviving name still fires (the name is what drops the effort)" \
  || bad "  a dispatch carrying a name was read as already-correct — it routes to the teammate runner and the definition's effort never applies"
IDEM_MODEL="$(printf '%s' "$IDEMDEF" | jq -c '.tool_input.model = "opus"')"
[ -n "$(raw "$CONSUMER" "$IDEM_MODEL")" ] \
  && ok "  a correct type WITH a surviving model param still fires (the param outranks the definition)" \
  || bad "  a dispatch carrying a model param was read as already-correct — two live sources for one value"

# The ledger must never be able to block a spawn.
rm -rf "$CONSUMER/_bmad-output"
OUT_RO="$(setmodel "$CONSUMER" "$(mkjson Agent remediator sonnet)")"
[ "$OUT_RO" = "opus" ] \
  && ok "binding still works with the state dir absent (bookkeeping never blocks a dispatch)" \
  || bad "with no state dir the guard injected '$OUT_RO', expected opus — the ledger write is not fail-open"
mkdir -p "$CONSUMER/_bmad-output"

# --- 14. DENY ARM 1: A CAP-REJECTED SPAWN RE-SENT BEFORE ANY AGENT EXITED ---------
# FALSE-POSITIVE SET, measured by driving this guard at each of the 233 same-description lead
# re-sends in the reference consumer's nine cap-rejecting sessions (transcript cut at the re-send's
# record): 3 denied, 3 of them rejected again by the harness, 0 launched. It reached zero through two
# narrowings, each with its own case here: releasing on a non-rejected Agent result (14b; without it
# 48 held, 33 launched) and counting the queue ENQUEUE as an agent exit (14c''; without it 6 held, 3
# launched). Slowest call on the corpus, a 44 MB transcript, 0.34 s.
# The rejection is produced by Claude Code AFTER PreToolUse, so it can only be SEEDED: the real
# record shapes, taken from the reference consumer's lead transcripts, are an assistant
# `tool_use` and a user `tool_result` whose content is the cap text with `is_error: true`. Every
# dispatch below is `dev` with `model: sonnet`, a call the model path leaves UNTOUCHED -- so any
# output at all is this arm's, an allow is the empty string, and a deny is `deny`.
CAPTXT='Concurrent subagent limit reached. You can run 20 subagents at once. Do not retry. If the user wants more concurrent subagents, ask them to increase CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS.'
t_use() { # t_use <id> <tool> <description> [command]
  jq -nc --arg id "$1" --arg n "$2" --arg d "$3" --arg c "${4-}" '{type:"assistant",isSidechain:false,
    message:{role:"assistant",content:[{type:"tool_use",id:$id,name:$n,
      input:({description:$d} + (if $c != "" then {command:$c} else {} end))}]}}'
}
t_res() { # t_res <id> <text> <is_error>
  jq -nc --arg id "$1" --arg t "$2" --argjson e "$3" '{type:"user",isSidechain:false,
    message:{role:"user",content:[{type:"tool_result",tool_use_id:$id,content:$t,is_error:$e}]}}'
}
t_note() { # t_note <summary-kind>   -- a notification as the harness records it: origin.kind on the record
  jq -nc --arg c "$(printf '<task-notification>\n<task-id>a0</task-id>\n<status>completed</status>\n<summary>%s "seat" finished</summary>\n</task-notification>' "$1")" \
    '{type:"user",isSidechain:false,origin:{kind:"task-notification"},message:{role:"user",content:$c}}'
}
CAPDIR="$WORK/cap"; mkdir -p "$CAPDIR"
# The rejected spawn, preceded by an UNRELATED launched one, so the rejection is not the first
# record and a launch BEFORE it must not release it.
{ t_use u0 Agent "Earlier seat"; t_res u0 "Async agent launched successfully." false
  t_use u1 Agent "Party seat 7"; t_res u1 "$CAPTXT" true; } > "$CAPDIR/a.jsonl"
{ cat "$CAPDIR/a.jsonl"; t_use u2 Agent "Party seat 8"; t_res u2 "Async agent launched successfully." false; } > "$CAPDIR/b.jsonl"
{ cat "$CAPDIR/a.jsonl"; t_note Agent; } > "$CAPDIR/c.jsonl"
# c3: the agent's exit recorded ONLY as the harness's queue ENQUEUE, before delivery -- the
# earliest record of an exit, and the one a lead re-send most often races.
{ cat "$CAPDIR/a.jsonl"
  jq -nc --arg c "$(printf '<%s>\n<status>completed</status>\n<summary>Agent "seat" finished</summary>' task-notification)" \
    '{type:"queue-operation",operation:"enqueue",content:$c}'; } > "$CAPDIR/c3.jsonl"
# c2: the near-miss for (c) -- a notification for a BACKGROUND COMMAND, which is no agent exiting.
{ cat "$CAPDIR/a.jsonl"; t_note "Background command"; } > "$CAPDIR/c2.jsonl"
# d: the cap text ONLY in a Bash call's command and that call's error result. The Bash tool_use
# carries a `description` equal to the re-sent one, so an arm that read every tool's results
# would hold it. No Agent call was ever rejected here.
{ t_use b1 Bash "Party seat 7" "grep -c 'Concurrent subagent limit reached' t.jsonl"
  t_res b1 "$CAPTXT" true; } > "$CAPDIR/d.jsonl"

capj() { # capj <transcript> <description> [agent_id]
  mkjson Agent dev sonnet | jq -c --arg t "$1" --arg d "$2" --arg a "${3-}" \
    '.transcript_path = $t | .tool_input.description = $d | if $a != "" then .agent_id = $a else . end'
}
capout() { raw "${3:-$CONSUMER}" "$(capj "$1" "$2" "${4-}")"; }
CAP_A="$(capout "$CAPDIR/a.jsonl" "Party seat 7")"
expect_deny "$CAP_A" "14a a re-send of a cap-rejected description with nothing released since"
grep -qF 'an agent of this session has exited since the rejection' <<<"$CAP_A" \
  && ok "  and the remedy quotes Rule 28's held-set paragraph" \
  || bad "  the deny does not quote Rule 28's held-set release condition"
BCX="$(capout "$CAPDIR/b.jsonl" "Party seat 7")"; expect_quiet "$BCX" "14b the same, after a non-rejected Agent result (the cap admitted a spawn)"
BCX="$(capout "$CAPDIR/c.jsonl" "Party seat 7")"; expect_quiet "$BCX" "14c the same, after an agent task-notification (an agent exited)"
BCX="$(capout "$CAPDIR/c3.jsonl" "Party seat 7")"; expect_quiet "$BCX" "14c'' the same, after an agent exit recorded only as the queue enqueue"
BCX="$(capout "$CAPDIR/c2.jsonl" "Party seat 7")"; expect_deny "$BCX" "14c' the same, after only a BACKGROUND-COMMAND notification"
BCX="$(capout "$CAPDIR/d.jsonl" "Party seat 7")"; expect_quiet "$BCX" "14d the cap text only inside a Bash command and its result"
BCX="$(capout "$CAPDIR/a.jsonl" "Party seat 9")"; expect_quiet "$BCX" "14e a different description"
BCX="$(capout "$CAPDIR/a.jsonl" "Party seat 7" "" a1234567890abcdef)"; expect_quiet "$BCX" "14f a subagent's call (agent_id set)"
expect_quiet "$(capout "$CAPDIR/a.jsonl" "Party seat 7" "$NOSTAMP")" "14g a non-layered tree"

# 14w. A FAILED TAIL WRITE FAILS OPEN. The write is made to fail PART-WAY with a file-size limit
# (SIGXFSZ ignored, so `tail` gets EFBIG and exits non-zero) on a transcript that HOLDS when read
# whole: the rejection sits in the first records and Bash padding, which releases nothing, pushes
# the file past the limit. The partial file therefore still carries the rejection, so a guard
# that greps after a failed write denies -- an EMPTY failed write could not tell the two apart.
CAPPAD="$CAPDIR/pad.jsonl"
{ cat "$CAPDIR/a.jsonl"; _i=0
  while [ "$_i" -lt 40 ]; do t_use "p$_i" Bash "pad $_i" "true"; t_res "p$_i" "padding output line $_i" false; _i=$((_i+1)); done
} > "$CAPPAD"
CAP_LIM_KB=4
cap_lim() { # cap_lim <script> <transcript> <description> -> decision or empty, under the size limit
  ( trap '' XFSZ; ulimit -f "$CAP_LIM_KB" || exit 3
    printf '%s' "$(capj "$2" "$3")" | CLAUDE_PROJECT_DIR="$CONSUMER" dgrun "$1" 2>/dev/null ) \
    | jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null
}
_lt="$WORK/cap-limtail.out"
( trap '' XFSZ; ulimit -f "$CAP_LIM_KB" && tail -c 1048576 "$CAPPAD" > "$_lt" ) 2>/dev/null && _lt_rc=0 || _lt_rc=$?
if [ "$_lt_rc" -ne 0 ] && [ -s "$_lt" ] && grep -qF 'Concurrent subagent limit reached' "$_lt" \
   && [ "$(wc -c < "$_lt")" -lt "$(wc -c < "$CAPPAD")" ]; then
  ok "14w precondition: under the limit \`tail\` exits $_lt_rc with a PARTIAL file that still holds the rejection"
else
  bad "14w FIXTURE BROKEN: the size limit did not produce a failed, partial, rejection-bearing tail (rc=$_lt_rc) -- 14w asserts nothing"
fi
expect_deny "$(capout "$CAPPAD" "Party seat 7")" "14w' the padded transcript, written whole, HOLDS"
_cl="$(cap_lim "$HOOK" "$CAPPAD" "Party seat 7")"
[ -z "$_cl" ] && ok "14w the same transcript, its tail write failing part-way -> allowed (fail open)" \
  || bad "14w a failed tail write -> expected NO decision, got '$_cl'"

# 14h. `--hold-status [<description>] --transcript <path>` answers from the SAME computation the
# PreToolUse arm uses (dg_hold_compute): 0 no hold, 1 a hold is live, 2 cannot tell. Cells differ from
# the live-hold cell in ONE input each: b.jsonl (a launch released it), a missing transcript, a
# different description. The PreToolUse path is re-asserted beside them: 14a still denies.
hs() { dgrun "$HOOK" --hold-status "$@" >/dev/null 2>&1; echo $?; }
[ "$(hs --transcript "$CAPDIR/a.jsonl")" = 1 ] && ok "14h hold-status, a live hold, any description -> exit 1" \
  || bad "14h hold-status on a seeded live hold did not exit 1"
[ "$(hs "Party seat 7" --transcript "$CAPDIR/a.jsonl")" = 1 ] && ok "14h hold-status, a live hold for the description -> exit 1" \
  || bad "14h hold-status on a seeded live hold for its description did not exit 1"
[ "$(hs "Party seat 9" --transcript "$CAPDIR/a.jsonl")" = 0 ] && ok "14h hold-status, a hold for a different description -> exit 0" \
  || bad "14h hold-status for a description with no hold did not exit 0"
[ "$(hs --transcript "$CAPDIR/b.jsonl")" = 0 ] && ok "14h hold-status, no hold (a launch released it) -> exit 0" \
  || bad "14h hold-status with no live hold did not exit 0"
[ "$(hs --transcript "$CAPDIR/c.jsonl")" = 0 ] && ok "14h hold-status, no hold (an agent exited) -> exit 0" \
  || bad "14h hold-status after an agent exit did not exit 0"
[ "$(hs --transcript "$CAPDIR/no-such-transcript.jsonl")" = 2 ] && ok "14h hold-status, an unreadable transcript -> exit 2" \
  || bad "14h hold-status on an unreadable transcript did not exit 2"
[ "$(hs)" = 2 ] && ok "14h hold-status, no transcript given -> exit 2" || bad "14h hold-status with no transcript did not exit 2"
[ "$(AI_DLC_HOLD_TRANSCRIPT="$CAPDIR/a.jsonl" hs)" = 1 ] && ok "14h hold-status takes the transcript from AI_DLC_HOLD_TRANSCRIPT" \
  || bad "14h hold-status did not read AI_DLC_HOLD_TRANSCRIPT"
expect_deny "$(capout "$CAPDIR/a.jsonl" "Party seat 7")" "14h PreToolUse path after the refactor: a held re-send"

# --- 15. DENY ARM 2: A GATE-ADJUDICATOR DISPATCHED OVER A WAIVER CHECK 22 WILL REJECT ---------
# FALSE-POSITIVE SET, measured by driving this guard over the reference consumer's live pending.md
# and pending-archive.md (each alone and concatenated) with its real ledger, probe rows and
# team-roles, sprints 298-318, under an implementation nonce. Clause 1 (names no spawn): 0 denies;
# it reached 0 by excluding names equal to their role (15a) and by keying on a Check 22
# DISPOSITION rather than a substring (15i) -- the substring form scored 19 of 32
# OVERRIDDEN entries and denied S302 (two S302-5 entries, Check 11 and Check 16 dispositions citing
# "Check-22 pattern by analogy" in their Resolution) and S307 (a Check 929 entry whose Blocker type
# reads "Rule 19-adjacent"); the keyed form scores the other 16.
# Re-measured after the Remediation field was assembled across wrapped lines and the negation test
# scoped to the claim's own clause: archive+live concatenated, S298-S318, denies S316 and S317 only,
# and clause 1 still denies 0. Live alone also denies S318 once the consumer rotated its S318
# exception-(3)/(2) entry into the archive (live then holds no S318 OVERRIDDEN entry); the prior
# guard gives the identical live answer, so that row is the corpus moving, not this arm. Implementation scope over the 264 lead adjudicator
# briefs: 178 judged (every brief whose own nonce is implementation), 86 not (32 planning, 38
# sprint-review, 15 story, 1 sprint-review brief citing an earlier implementation nonce).
# Clause 2 (uncovered invalid-exception row): it denies live S316 (3 rows) and S317 (11 rows), and
# archive S316/S317/S318. Each of those rows is one validate-spawn-ledger.sh arm S3 FAILS, which
# makes each a true positive: Check 22 would discard the pass. The archived S318 rows are covered
# in the live file by an entry citing exceptions (3) and (2). Clause 2 reached that set by scoping
# to S3's shardable roles (15g; without it S316 adds a dev-escalated row S3 does not judge).
# Each world is a fresh project: stamp, roles and settings copied from CONSUMER, a snapshot
# naming the sprint, a seeded spawn ledger and a seeded pending.md. The ledger holds a non-subject
# epoch row FIRST, so no arm passes by reading only the first row.
WAIVER_SRC="$HERE/s317-tier-pin-waiver.md"
[ -r "$WAIVER_SRC" ] || bad "15 the extracted s317 waiver body ($WAIVER_SRC) is missing -- section 15 asserts nothing"
ledrow() { # ledrow <sprint> <name> <role> <tool_use_id> [shard]
  jq -nc --argjson s "$1" --arg n "$2" --arg r "$3" --arg t "$4" --arg sh "${5-}" \
    '{v:1,sprint:$s,name:$n,role:$r,tool_use_id:$t,shard:(if $sh == "" then null else $sh end)}'
}
mkworld() { # mkworld <name> <sprint> -> prints the project dir; ledger and pending.md from stdin-free files
  local p="$WORK/waiver-$1"
  mkdir -p "$p/.claude" "$p/_bmad-output" "$p/docs/escalations"
  cp -R "$CONSUMER/.claude/team-roles" "$p/.claude/"
  cp "$CONSUMER/.claude/.ai-dlc-version" "$CONSUMER/.claude/settings.json" "$p/.claude/"
  printf -- '- sprint_id: %s\n' "$2" > "$p/_bmad-output/pipeline-snapshot.md"
  { ledrow 316 epoch-row analyst toolu_EPOCH0
    ledrow 317 dev dev toolu_01DEVROW000000000000001
    ledrow 317 code-reviewer code-reviewer toolu_01CRROW0000000000000001
    ledrow 317 s317-w8 dev toolu_01W8ROW0000000000000001
  } > "$p/_bmad-output/spawn-ledger.jsonl"
  : > "$p/docs/escalations/pending.md"
  printf '%s\n' "$p"
}
entry() { # entry <file> <header> <body-line>...
  local f="$1" h="$2"; shift 2
  { printf '\n%s\n**Status:** OVERRIDDEN\n' "$h"; for l in "$@"; do printf '%s\n' "$l"; done; } >> "$f"
}
# Every adjudicator brief carries its gate nonce, as all 264 of the reference consumer's do; the
# arm judges IMPLEMENTATION gates only (Check 22's manifest row), so a world driven without one
# would assert nothing.
adjj() { mkjson Agent gate-adjudicator opus | jq -c --arg n "${1:-implementation-20261010T230257Z}" \
  '.tool_input.prompt += (" gate_nonce: " + $n)'; }
adj() { raw "$1" "$(adjj "${2-}")"; }
ADJ_REM="**Remediation:** outputs verified against the role contract."

W1="$(mkworld unnamed 317)"; cat "$WAIVER_SRC" >> "$W1/docs/escalations/pending.md"
W1_OUT="$(adj "$W1")"
expect_deny "$W1_OUT" "15a the real s317 tier-pin waiver (names 82 dev and 42 code-reviewer rows, no spawn)"
grep -qF 'names no spawn' <<<"$W1_OUT" && ok "  and the reason names the unnamed-waiver clause" \
  || bad "  the deny does not say the waiver names no spawn"
expect_quiet "$(raw "$W1" "$(mkjson Agent dev sonnet)")" "15a' the same world, a NON-adjudicator dispatch"

W2="$(mkworld tooluse 317)"
entry "$W2/docs/escalations/pending.md" "## [S317-CHECK22-WAIVER] lead - 2026-10-10" \
  "**Context:** Check 22 tier mismatch on toolu_01DEVROW000000000000001." "$ADJ_REM"
expect_quiet "$(adj "$W2")" "15b a Check 22 waiver naming a ledger tool_use_id"

W3="$(mkworld nameonly 317)"
entry "$W3/docs/escalations/pending.md" "## [S317-CHECK22-WAIVER] lead - 2026-10-10" \
  "**Context:** Check 22 tier mismatch on the dispatch s317-w8." "$ADJ_REM"
BCX="$(adj "$W3")"; expect_quiet "$BCX" "15c a Check 22 waiver naming a ledger dispatch name only"

W4="$(mkworld prior 318)"; cat "$WAIVER_SRC" >> "$W4/docs/escalations/pending.md"
BCX="$(adj "$W4")"; expect_quiet "$BCX" "15d the same unnamed waiver, from a PRIOR sprint"

# THE INVALID-EXCEPTION CLAUSE. One remediator row recorded `invalid-exception` in S317.
inv_world() { # inv_world <name> <entry-body-line> -> project dir
  local p; p="$(mkworld "$1" 317)"
  ledrow 317 remediator remediator toolu_01REMINV000000000000001 invalid-exception >> "$p/_bmad-output/spawn-ledger.jsonl"
  [ -n "$2" ] && entry "$p/docs/escalations/pending.md" "## [S317-CHECK22-S3] lead - 2026-10-10" \
    "**Context:** Check 22 arm S3 on toolu_01REMINV000000000000001." "$2"
  printf '%s\n' "$p"
}
W5="$(inv_world uncovered "**Remediation:** no Rule 28 exception applies, and none is invented here.")"
W5_OUT="$(adj "$W5")"
expect_deny "$W5_OUT" "15e an invalid-exception row named by a waiver that cites no exception"
grep -qF 'toolu_01REMINV000000000000001' <<<"$W5_OUT" && ok "  and the reason names the uncovered row" \
  || bad "  the deny does not name the uncovered invalid-exception row"
expect_deny "$(adj "$(inv_world generic "**Remediation:** one of Rule 28's four serial exceptions applied.")")" \
  "15e' the same, citing the exceptions only as \"the four\" (the s317 124524Z form)"
expect_quiet "$(adj "$(inv_world covered "**Remediation:** the exception that applied is exception (4), a serial document.")")" \
  "15f the same row, covered by an entry citing exception (4)"
W7="$(mkworld nonshard 317)"
ledrow 317 dev-escalated dev-escalated toolu_01DEVESCINV00000000001 invalid-exception >> "$W7/_bmad-output/spawn-ledger.jsonl"
BCX="$(adj "$W7")"; expect_quiet "$BCX" "15g an invalid-exception row on a NON-shardable role (Check 22 arm S3 does not judge it)"

# 15w. A FAILED KEY PRODUCER FAILS OPEN. 15a's world plus one ledger row whose tool_use_id is a
# NUMBER: the guard's `"K\t" + .tool_use_id` cannot add a string and a number. It is the LAST row
# because jq 1.8.1 exits 5 only when the failing input is the last one -- mid-stream it exits 0 and
# drops that row's keys silently, which no status can see. Every earlier row still keys, so the
# file is non-empty and only the recorded status can make the arm stand down. 15a is the control:
# the same world without the row denies.
# An ALLOWED drive appends its own ledger row after this arm runs, which would push the numeric row
# off the end, so every drive gets a FRESH world and asserts the row is last before it runs.
numid_world() { # numid_world <name> -> project dir
  local p; p="$(mkworld "$1" 317)"; cat "$WAIVER_SRC" >> "$p/docs/escalations/pending.md"
  printf '%s\n' '{"v":1,"sprint":317,"name":"s317-numid","role":"dev","tool_use_id":42,"shard":null}' \
    >> "$p/_bmad-output/spawn-ledger.jsonl"
  printf '%s\n' "$p"
}
numid_last() { [ "$(tail -1 "$1/_bmad-output/spawn-ledger.jsonl" | jq -r '.tool_use_id | type' 2>/dev/null)" = number ]; }
W11="$(numid_world numid)"
# PRECONDITION: this host's jq must actually FAIL on the seed, or 15w's allow is unearned. The
# expression is the guard's own key term; a jq that exits 0 here never reaches the fail-open path.
if jq -Rr 'fromjson? | select(type == "object") | "K\t" + .tool_use_id' \
     "$W11/_bmad-output/spawn-ledger.jsonl" >/dev/null 2>&1; then
  bad "15w FIXTURE BROKEN: this jq exits 0 on a final numeric tool_use_id row, so the producer never fails and 15w asserts nothing"
else
  ok "15w precondition: the key term exits non-zero on the seeded ledger's final numeric row"
fi
if numid_last "$W11"; then
  expect_quiet "$(adj "$W11")" "15w the 15a waiver, the key producer failing on a numeric tool_use_id -> fail open"
else bad "15w FIXTURE BROKEN: the numeric tool_use_id row is not the ledger's last row"; fi

# THE SHARDED-REMEDIATION ARM of clause 2: Check 22 clearing arm 4 accepts, for this class, "the
# work was re-dispatched sharded" as well as a named exception. The three near-misses each carry
# `re-dispatch` and `shard` in the entry and must still deny: an UNCHOSEN option (the s317 form),
# a negated remediation, and one that never says sharded.
W8="$(inv_world sharded "**Remediation:** the work was re-dispatched sharded as rem-p1a and rem-p1b; output verified.")"
BCX="$(adj "$W8")"; expect_quiet "$BCX" "15h an invalid-exception row covered by a Remediation stating a sharded re-dispatch"
W8I="$(inv_world shardinline "Remediation: the work was re-dispatched sharded as rem-p1a and rem-p1b; output verified.")"
expect_quiet "$(adj "$W8I")" "15h' the same, written as an inline Remediation: (the adversary's s9 form)"
W8O="$(inv_world shardoption "**Options:** (a) OVERRIDDEN [chosen]; (b) re-dispatch the nine as sharded spawns.")"
BCX="$(adj "$W8O")"; expect_deny "$BCX" "15h'' a sharded re-dispatch only as an UNCHOSEN option (the s317 124524Z entry's form)"
W8N="$(inv_world shardneg "**Remediation:** No spawn is re-dispatched sharded; outputs verified.")"
BCX="$(adj "$W8N")"; expect_deny "$BCX" "15h''' a negated sharded re-dispatch in the Remediation"
W8U="$(inv_world shardnone "**Remediation:** the work was re-dispatched serially; output verified.")"
expect_deny "$(adj "$W8U")" "15h'''' a re-dispatch that is not sharded"

# CLAUSE 1 KEYS ON A CHECK 22 DISPOSITION. The near-miss carries both shapes the reference
# consumer's two false positives had: `Rule 19` in a field (S307 Check 929's "Rule 19-adjacent")
# and `Check-22` only in a Resolution (S302-5's "Check-22 pattern by analogy").
W9="$(mkworld substr 317)"
entry "$W9/docs/escalations/pending.md" "## [S317-Z] lead - 2026-10-10" \
  "**Blocker type:** Check 30 spec join ruling; unrelated to the Rule 19(b) binding." \
  "**Resolution:** disposition by the Check-22 pattern, by analogy."
BCX="$(adj "$W9")"; expect_quiet "$BCX" "15i an OVERRIDDEN Check 30 entry mentioning Rule 19(b) and Check-22 only in passing"
W9P="$(mkworld substrpos 317)"
entry "$W9P/docs/escalations/pending.md" "## [S317-Z] lead - 2026-10-10" \
  "**Blocker type:** Check 30 spec join ruling; unrelated to the Rule 19(b) binding." \
  "**Context:** Check 22 tier mismatch on the dev rows." "$ADJ_REM"
expect_deny "$(adj "$W9P")" "15i' its twin: the same entry with Check 22 in its Context (a disposition naming no spawn)"
W9C="$(mkworld substrcont 317)"
entry "$W9C/docs/escalations/pending.md" "## [S317-Z] lead - 2026-10-10" \
  "**Context:** Gate 3 ran the ledger validator, and" "the Check 22 FAIL lists the dev rows." "$ADJ_REM"
expect_deny "$(adj "$W9C")" "15i'' Check 22 on a wrapped continuation line of the Context field"

# ENTRIES SPLIT ON `## ` ONLY: a `###` subheading carrying the waiver's spawn list is the entry's.
W10="$(mkworld h3 317)"
entry "$W10/docs/escalations/pending.md" "## [S317-Y] lead - 2026-10-10" \
  "**Context:** Check 22 tier mismatch waived." "$ADJ_REM" "### Spawns waived" "toolu_01DEVROW000000000000001"
BCX="$(adj "$W10")"; expect_quiet "$BCX" "15j a Check 22 waiver whose spawn list sits under a ### subheading"

# ONLY AN IMPLEMENTATION GATE, read from the brief's OWN nonce: the first after its `gate_nonce`
# key, else the first anywhere; case-insensitive; a hyphenated prefix glued on still counts.
# `adjj` writes " gate_nonce: <arg>", so the arg's first nonce is the brief's own.
BCX="$(adj "$W1" sprint-review-20261011T101010Z)"; expect_quiet "$BCX" "15k the 15a world, a SPRINT-REVIEW adjudicator"
expect_quiet "$(raw "$W1" "$(mkjson Agent gate-adjudicator opus | jq -c '.tool_input.prompt += " cites implementation-20261010T230257Z. gate_nonce: sprint-review-20261011T101010Z"')")" \
  "15k' the 15a world, a sprint-review brief that CITES an earlier implementation nonce"
expect_quiet "$(raw "$W1" "$(mkjson Agent gate-adjudicator opus)")" "15k'' the 15a world, a brief naming no nonce"
expect_deny "$(adj "$W1" "implementation-20261010T230257Z; story verdict story-20261009T101010Z")" \
  "15k''' the 15a world, an implementation brief that also cites a story nonce (judged)"
BCX="$(adj "$W1" gate-adjudicator-implementation-20261010T230257Z)"; expect_deny "$BCX" \
  "15k'''' the 15a world, an implementation nonce glued to a hyphenated prefix (judged)"
expect_deny "$(adj "$W1" IMPLEMENTATION-20261010T230257Z)" "15k''''' the 15a world, an upper-case implementation nonce (judged)"

# THE NONCE READ SEES THE BRIEF FILE: a gate nonce only inside the `Brief:` file judges the dispatch like a literal one.
mkdir -p "$W1/_bmad-output/planning-artifacts"
printf 'gate_nonce: implementation-20261010T230257Z\n' > "$W1/_bmad-output/planning-artifacts/b-nonce-impl.md"
printf 'gate_nonce: sprint-review-20261011T101010Z\n' > "$W1/_bmad-output/planning-artifacts/b-nonce-sr.md"
expect_deny "$(raw "$W1" "$(mkjson Agent gate-adjudicator opus | jq -c '.tool_input.prompt += "\nBrief: _bmad-output/planning-artifacts/b-nonce-impl.md"')")" \
  "15k6 the 15a world, an implementation nonce only inside the Brief: file (judged)"
expect_quiet "$(raw "$W1" "$(mkjson Agent gate-adjudicator opus | jq -c '.tool_input.prompt += "\nBrief: _bmad-output/planning-artifacts/b-nonce-sr.md"')")" \
  "15k7 the 15a world, a sprint-review nonce only inside the Brief: file (not judged)"
printf 'Deliverable: x/y.md\nSee `.claude/team-roles/qa.md` for the reviewer appendix.\n' > "$W1/_bmad-output/planning-artifacts/b-role2.md"
raw "$W1" "$(mkjson Agent dev sonnet | jq -c '.tool_input.prompt += "\nBrief: _bmad-output/planning-artifacts/b-role2.md"')" >/dev/null
[ "$(tail -1 "$W1/_bmad-output/spawn-ledger.jsonl" | jq -r '.role' 2>/dev/null)" = dev ] \
  && ok "15k8 a Brief: file citing a SECOND role file leaves the spawn's own literal role (dev) on its ledger row" \
  || bad "15k8 the ledger row's role is '$(tail -1 "$W1/_bmad-output/spawn-ledger.jsonl" | jq -r '.role' 2>/dev/null)', expected dev: the role read is not the literal prompt's"

# A REFUSED DISPATCH WRITES NO LEDGER ROW; an allowed one in the same world writes exactly one.
L0="$(wc -l < "$W1/_bmad-output/spawn-ledger.jsonl" | tr -d ' ')"
adj "$W1" >/dev/null
L1="$(wc -l < "$W1/_bmad-output/spawn-ledger.jsonl" | tr -d ' ')"
adj "$W1" sprint-review-20261011T101010Z >/dev/null
L2="$(wc -l < "$W1/_bmad-output/spawn-ledger.jsonl" | tr -d ' ')"
[ "$L1" = "$L0" ] && [ "$L2" = "$((L0 + 1))" ] \
  && ok "15l a denied adjudicator dispatch leaves no ledger row; the allowed control adds one ($L0 -> $L1 -> $L2)" \
  || bad "15l ledger rows $L0 -> $L1 (denied) -> $L2 (allowed); expected $L0 -> $L0 -> $((L0 + 1))"


# THE REMEDIATION IS ASSEMBLED ACROSS WRAPPED LINES, AND NEGATION IS SCOPED TO THE CLAIM'S CLAUSE.
# The reference consumer wraps its fields (62 continuation lines inside OVERRIDDEN entries). Every
# world below is the 15e row named by an entry whose Remediation is the given text.
WRP="$(inv_world wrappos "$(printf '%s\n%s' '**Remediation:** the work was re-dispatched' 'sharded as rem-p1a and rem-p1b; output verified.')")"
BCX="$(adj "$WRP")"; expect_quiet "$BCX" "15m a sharded Remediation wrapped across two lines (re-dispatched / sharded)"
WRN="$(inv_world wrapneg "$(printf '%s\n%s' '**Remediation:** the work was not' 're-dispatched sharded; outputs verified.')")"
BCX="$(adj "$WRN")"; expect_deny "$BCX" "15m' its negated twin, the negator on the line BEFORE the claim (not / re-dispatched sharded)"
WSN="$(inv_world notserial "**Remediation:** the work was re-dispatched sharded, not serially, as rem-p1a and rem-p1b.")"
BCX="$(adj "$WSN")"; expect_quiet "$BCX" "15n a negation AFTER the claim (\"re-dispatched sharded, not serially\")"
expect_quiet "$(adj "$(inv_world soexc "**Remediation:** re-dispatched sharded as rem-p1a and rem-p1b, so no Rule 28 exception is claimed.")")" \
  "15n' a negated trailing clause (\"..., so no Rule 28 exception is claimed\")"
expect_quiet "$(adj "$(inv_world emdash "$(printf '**Remediation:** the work was re-dispatched sharded as rem-p1a and rem-p1b \342\200\224 none of the four exceptions applied.')")")" \
  "15n'' an em-dash clause after the claim (\"-- none of the four exceptions applied\")"
expect_quiet "$(adj "$(inv_world runt "**Remediation:** the work was re-dispatched sharded as s317-rem-run-t1 and s317-rem-run-t2.")")" \
  "15n''' a shard name the old n.t stand-in read as a negator (s317-rem-run-t1)"
WAP="$(inv_world apos "**Remediation:** the work wasn't re-dispatched sharded; outputs verified.")"
BCX="$(adj "$WAP")"; expect_deny "$BCX" "15o a straight-apostrophe negator before the claim (wasn't re-dispatched sharded)"
WCU="$(inv_world curly "$(printf '**Remediation:** the work wasn\342\200\231t re-dispatched sharded; outputs verified.')")"
BCX="$(adj "$WCU")"; expect_deny "$BCX" "15o' a curly-apostrophe negator before the claim"
WEN="$(inv_world excneg "**Remediation:** Rule 28 exception (3) does not apply; outputs verified.")"
BCX="$(adj "$WEN")"; expect_deny "$BCX" "15p a negated exception citation (\"exception (3) does not apply\")"
expect_deny "$(adj "$(inv_world excneg2 "**Remediation:** no exception (3) applies; outputs verified.")")" \
  "15p' a negator before the citation (\"no exception (3) applies\")"
expect_quiet "$(adj "$(inv_world excpos "**Remediation:** exception (3) applied, and no other was considered.")")" \
  "15p'' its twin: a cited exception with a negation in a LATER clause"
WXS="$(inv_world excprior "**Remediation:** The four were not invented. Exception (3) applied to toolu_01REMINV000000000000001.")"
BCX="$(adj "$WXS")"; expect_quiet "$BCX" "15p''' a cited exception with a negator in the PRIOR sentence"

# 15q. THE OPERATOR-FREE REMEDY (BL-842). An invalid-exception row V is covered with NO pending.md
# entry when a LATER row R of its sprint and role, that RAN (joined in subagent-context.jsonl) and
# carries a real `i/N` shard, names V on a `remediates:` brief line. The guard does not decide that:
# it asks validate-spawn-ledger.sh --remediated-keys, located by walking up from the hook's own
# directory, and reads any failure of that call as an EMPTY set (deny stands, one could-not-run line).
# R is written by the REAL guard from a real brief, never hand-seeded; V is hand-seeded because a
# current guard refuses an invented exception (THE SHARD DENY) and never writes one.
[ -n "$VSL" ] && echo "HERMETIC-CONSUMED $VSL" || bad "15q FIXTURE BROKEN: validate-spawn-ledger.sh not found beside $HOOK"
[ -n "$VGA" ] && [ -f "$(dirname "$VGA")/gate_adjudication.py" ] && echo "HERMETIC-CONSUMED $(dirname "$VGA")/gate_adjudication.py"
[ -n "$VGA" ] && echo "HERMETIC-CONSUMED $VGA" || bad "15q FIXTURE BROKEN: validate-gate-adjudication.sh not found beside $HOOK"
REM_V=toolu_01REMINV000000000000001
REM_R=toolu_01REMR00000000000000001
# remdisp <role> <tool_use_id> <brief line>... -> an Agent dispatch of <role> carrying the lines,
# with the PreToolUse tool_use_id the guard records (and the probe joins on).
remdisp() {
  local r="$1" t="$2" p; shift 2
  p="Your operating contract is \`.claude/team-roles/$r.md\`. Read it first."
  for _l in "$@"; do p="$p"$'\n'"$_l"; done
  jq -nc --arg p "$p"$'\n'"Do the work." --arg t "$t" --arg n "s317-$r-${t#toolu_01}" \
    '{tool_name:"Agent",tool_use_id:$t,tool_input:{name:$n,prompt:$p}}'
}
# ran <project> <tool_use_id> <role> -> one subagent-context.jsonl row, the shape SubagentStop writes.
ran() {
  local m; m="$(jq -r --arg r "$3" '.aiDlcModels[.aiDlcRoles[$r].model // ""] // ""' "$1/.claude/settings.json")"
  jq -nc --arg t "$2" --arg r "$3" --arg m "$m" \
    '{v:3,ts:"2026-10-10T23:00:00Z",sprint:317,agent_id:("a" + $t),model:$m,role:$r,tool_use_id:$t}' \
    >> "$1/_bmad-output/subagent-context.jsonl"
}
# rem_world <name> <key R names> [ran: 1|0] -> project dir: the 15e row V, then the real guard's R.
rem_world() {
  local p; p="$(mkworld "$1" 317)"
  ledrow 317 remediator remediator "$REM_V" invalid-exception >> "$p/_bmad-output/spawn-ledger.jsonl"
  raw "$p" "$(remdisp remediator "$REM_R" 'shard: 1/2 rem-fix-a' "remediates: $2")" >/dev/null
  [ "${3:-1}" = 1 ] && ran "$p" "$REM_R" remediator
  printf '%s\n' "$p"
}
last_field() { tail -1 "$1/_bmad-output/spawn-ledger.jsonl" | jq -r "$2 | tostring" 2>/dev/null; }

# THE GUARD WRITES THE FIELD FROM THE BRIEF. One line -> `remediates`; two -> `remediates_invalid`.
WRA="$(rem_world allow "$REM_V")"
[ "$(last_field "$WRA" .tool_use_id):$(last_field "$WRA" .remediates):$(last_field "$WRA" .shard)" = "$REM_R:$REM_V:1/2 rem-fix-a" ] \
  && ok "15q the guard writes R's row: tool_use_id $REM_R, remediates $REM_V, shard 1/2 rem-fix-a" \
  || bad "15q R's row is '$(tail -1 "$WRA/_bmad-output/spawn-ledger.jsonl" | cut -c1-300)'; expected remediates=$REM_V (the R dispatch may have been denied)"
WR2="$(mkworld remtwo 317)"
raw "$WR2" "$(remdisp remediator toolu_01REMTWO000000000000001 'shard: 1/2 rem-fix-a' "remediates: $REM_V" 'remediates: toolu_01DEVROW000000000000001')" >/dev/null
[ "$(last_field "$WR2" .tool_use_id):$(last_field "$WR2" .remediates_invalid):$(last_field "$WR2" 'has("remediates")')" = "toolu_01REMTWO000000000000001:multiple:false" ] \
  && ok "15q' two remediates: lines -> remediates_invalid=multiple and NO remediates field" \
  || bad "15q' two remediates: lines wrote '$(tail -1 "$WR2/_bmad-output/spawn-ledger.jsonl" | cut -c1-300)'"

# ALLOW / DENY TWINS, one property apart: the key R names.
expect_quiet "$(adj "$WRA")" "15r an invalid-exception row remediated by a later run R naming it, pending.md EMPTY"
[ ! -s "$WRA/docs/escalations/pending.md" ] && ok "  and pending.md holds no entry (0 bytes)" || bad "  15r's pending.md is not empty"
WRD="$(rem_world deny toolu_01NOTTHEROW00000000000001)"
WRD_OUT="$(adj "$WRD")"
expect_deny "$WRD_OUT" "15r' its twin: R names a DIFFERENT id"
grep -qF "$REM_V" <<<"$WRD_OUT" && ok "  and the reason names V ($REM_V)" || bad "  15r' deny does not name V"
grep -qF 'could not run' <<<"$WRD_OUT" && bad "  15r' says the predicate could not run -- it must have run and found nothing" \
  || ok "  and the predicate ran (no could-not-run line)"
WRP2="$(rem_world pending "$REM_V" 0)"
expect_deny "$(adj "$WRP2")" "15r'' R names V but never RAN (no subagent-context row)"
# THE NAME KEY: V carries a tool_use_id AND a dispatch name distinct from its role; R names it by
# the NAME. The guard keys the uncovered row by tool_use_id, so this allows only when the
# validator's REMEDIATED line reports V by that same tool_use_id.
WRN2="$(mkworld remname 317)"
ledrow 317 s317-rem-inv remediator "$REM_V" invalid-exception >> "$WRN2/_bmad-output/spawn-ledger.jsonl"
raw "$WRN2" "$(remdisp remediator "$REM_R" 'shard: 1/2 rem-fix-a' 'remediates: s317-rem-inv')" >/dev/null
ran "$WRN2" "$REM_R" remediator
expect_quiet "$(adj "$WRN2")" "15r''' V named by its distinct dispatch NAME on R's remediates: line"

# THE PREDICATE CANNOT RUN -> DENY, never skip. Guard copies sit in a tree where the walk-up finds a
# validator we place: the real one (control, must ALLOW 15r) or a stub exiting 2.
rem_tree() { # rem_tree <tag> <validator source> -> path of a guard copy whose walk-up finds <source>
  local d; d="$(mktemp -d "$WORK/remtree-$1.XXXXXX")" || return 1
  mkdir -p "$d/core/hooks" "$d/core/scripts" && cp -R "$HOOKS_SRC/." "$d/core/hooks/" \
    && cp "$2" "$d/core/scripts/validate-spawn-ledger.sh" || return 1
  printf '%s/core/hooks/%s' "$d" "$(basename "$HOOK")"
}
printf '#!/usr/bin/env bash\nexit 2\n' > "$WORK/q0-vsl-exit2.sh"
REM_X2="$(rem_tree exit2 "$WORK/q0-vsl-exit2.sh")"
X2_OUT="$(printf '%s' "$(adjj)" | FXCELL=dg-vsl-stub CLAUDE_PROJECT_DIR="$WRA" dgrun "$REM_X2" 2>/dev/null)"
expect_deny "$X2_OUT" "15s the 15r world, the validator exiting 2"
grep -qF 'The remediation predicate could not run, so no row was counted remediated: validate-spawn-ledger.sh --remediated-keys exited rc 2' <<<"$X2_OUT" \
  && grep -qF "$REM_V" <<<"$X2_OUT" \
  && ok "  and the reason carries the could-not-run line (rc 2) and names V" \
  || bad "  15s deny lacks the could-not-run line or V: '$(printf '%s' "$X2_OUT" | cut -c1-300)'"

# 15t. NO PATH REQUIRES AN OPERATOR ENTRY (BL-842's owed item, realised structurally). One world
# whose ONLY Check 22 violations are three remediated rows, one per remediable class (cite: Rule
# 19(b) uncited; shard: S3 invented exception; cover: S4 one-cross gap), and whose pending.md is
# EMPTY. In it the guard allows the implementation adjudicator, validate-spawn-ledger.sh exits 0
# printing a REMEDIATED line per pair and remediated=3, and validate-gate-adjudication.sh --series
# exits 0 over a 22 FAIL -> PASS series carrying the lead's resolution record. Every row is written
# by the REAL guard from a real brief, the epoch row in an earlier sprint FIRST; each V is then
# edited in place to its violation (a current guard refuses all three at dispatch, so none can be
# produced there), keeping every other field the guard wrote.
NOP="$WORK/waiver-nooperator"
mkdir -p "$NOP/.claude" "$NOP/_bmad-output/gate-adjudication" "$NOP/_bmad-output/planning-artifacts/s317" "$NOP/docs/escalations"
cp -R "$CONSUMER/.claude/team-roles" "$NOP/.claude/"
cp "$CONSUMER/.claude/.ai-dlc-version" "$CONSUMER/.claude/settings.json" "$NOP/.claude/"
: > "$NOP/docs/escalations/pending.md"
printf -- '- sprint_id: 316\n' > "$NOP/_bmad-output/pipeline-snapshot.md"
raw "$NOP" "$(remdisp dev toolu_01NOPEPOCH00000000000001)" >/dev/null
printf -- '- sprint_id: 317\n' > "$NOP/_bmad-output/pipeline-snapshot.md"
NV_S=toolu_01REMINV000000000000001; NR_S=toolu_01REMR00000000000000001
NV_C=toolu_01CITV000000000000000001; NR_C=toolu_01CITR000000000000000001
NV_X=toolu_01COVV000000000000000001; NR_X=toolu_01COVR000000000000000001
raw "$NOP" "$(remdisp remediator "$NV_S" 'shard: 1/2 rem-fix-a')" >/dev/null
raw "$NOP" "$(remdisp analyst "$NV_C" 'shard: 1/1 analysis')" >/dev/null
raw "$NOP" "$(remdisp analyst "$NV_X" 'shard: cross/3 g1/1 1,2,3')" >/dev/null
raw "$NOP" "$(remdisp remediator "$NR_S" 'shard: 1/2 rem-fix-a' "remediates: $NV_S")" >/dev/null
raw "$NOP" "$(remdisp analyst "$NR_C" 'shard: 1/1 analysis' "remediates: $NV_C")" >/dev/null
raw "$NOP" "$(remdisp analyst "$NR_X" 'shard: cross/3 g1/1 1,2,3' "remediates: $NV_X")" >/dev/null
NOP_L="$NOP/_bmad-output/spawn-ledger.jsonl"
jq -c --arg s "$NV_S" --arg c "$NV_C" --arg x "$NV_X" '
  if .tool_use_id == $s then .shard = "invalid-exception" | .shard_raw = "none (serial cross-section remediator)"
  elif .tool_use_id == $c then .role_contract_cited = false | .contract_via = null
  elif .tool_use_id == $x then .shard = "cross/3 g1/1 1,2"
  else . end' "$NOP_L" > "$NOP_L.new" && mv "$NOP_L.new" "$NOP_L"
for _t in toolu_01NOPEPOCH00000000000001:dev "$NV_S:remediator" "$NV_C:analyst" "$NV_X:analyst" \
          "$NR_S:remediator" "$NR_C:analyst" "$NR_X:analyst"; do ran "$NOP" "${_t%%:*}" "${_t#*:}"; done
[ "$(jq -sr 'map(.tool_use_id) | join(" ")' "$NOP_L" 2>/dev/null)" = "toolu_01NOPEPOCH00000000000001 $NV_S $NV_C $NV_X $NR_S $NR_C $NR_X" ] \
  && ok "15t world: seven guard-written rows in ledger order (epoch, three V, three R)" \
  || bad "15t FIXTURE BROKEN: the ledger is '$(jq -sr 'map(.tool_use_id // "?") | join(" ")' "$NOP_L" 2>/dev/null)' -- a dispatch was denied or misordered"
expect_quiet "$(adj "$NOP")" "15t the guard: an implementation adjudicator over a sprint whose only violations are remediated"
eqv cli-vsl-pass "$VSL" vsl --ledger "$NOP_L" --sprint 317 --settings "$NOP/.claude/settings.json" \
  --probe "$NOP/_bmad-output/subagent-context.jsonl" --context "$NOP/_bmad-output/subagent-context.jsonl"; _eq1=$?
NOP_VO="$(cat "$EQ/cli-vsl-pass.ip.out" "$EQ/cli-vsl-pass.ip.err")"; NOP_VR="$(cat "$EQ/cli-vsl-pass.ip.rc")"
[ "$_eq1" = 0 ] && [ "$(cat "$EQ/cli-vsl-pass.cl.rc")" = 0 ] \
  && ok "  cli-vsl-pass: the program's stdout, stderr and exit 0 equal the in-process call's" \
  || bad "  cli-vsl-pass: the program and the in-process call differ, or the outcome is not exit 0"
[ "$NOP_VR" = 0 ] && grep -qF "REMEDIATED: $NV_S by $NR_S (shard)" <<<"$NOP_VO" \
  && grep -qF "REMEDIATED: $NV_C by $NR_C (cite)" <<<"$NOP_VO" && grep -qF "REMEDIATED: $NV_X by $NR_X (cover)" <<<"$NOP_VO" \
  && grep -qE '^COUNTS:' <<<"$NOP_VO" && grep -qE 'remediation \(classes: cite shard cover\): remediated=3 pending-remedy=0' <<<"$NOP_VO" \
  && ok "15t the validator: exit 0, one REMEDIATED line per class, remediated=3" \
  || bad "15t the validator exited $NOP_VR: '$(printf '%s' "$NOP_VO" | tr '\n' ' ' | cut -c1-600)'"
# THE SAME LEDGER WITHOUT R's RUN: every V is still a violation, so exit 1 -- the 15t exit 0 is
# the remedies' doing, not a validator that judges nothing.
grep -vF "$NR_S" "$NOP/_bmad-output/subagent-context.jsonl" | grep -vF "$NR_C" | grep -vF "$NR_X" > "$WORK/q0-nop-norun.jsonl"
eqv cli-vsl-refuse "$VSL" vsl --ledger "$NOP_L" --sprint 317 --settings "$NOP/.claude/settings.json" \
  --probe "$WORK/q0-nop-norun.jsonl" --context "$WORK/q0-nop-norun.jsonl"; _eq2=$?
_nr="$(cat "$EQ/cli-vsl-refuse.ip.rc")"
[ "$_eq2" = 0 ] && [ "$(cat "$EQ/cli-vsl-refuse.cl.rc")" = 1 ] \
  && ok "  cli-vsl-refuse: the program's stdout, stderr and exit 1 equal the in-process call's" \
  || bad "  cli-vsl-refuse: the program and the in-process call differ, or the outcome is not exit 1"
[ "$_nr" = 1 ] && ok "  its control: the same ledger with no R joined exits 1" || bad "  15t control: no R joined exited $_nr, expected 1"
cat > "$NOP/_bmad-output/planning-artifacts/s317/gate-implementation-resolution-p1.md" <<NOPEOF
# Gate resolution record — implementation gate, pass 1

## Check 22 — spawn ledger

- disposition: remediated (classes shard, cite, cover); no escalation entry
- edit: _bmad-output/spawn-ledger.jsonl — $NR_S remediates: $NV_S; $NR_C remediates: $NV_C; $NR_X remediates: $NV_X
- derivation:
  \`\`\`
$(printf '%s\n' "$NOP_VO" | grep -E '^(REMEDIATED|COUNTS):|remediation \(classes:' | sed 's/^/  /')
  \`\`\`
NOPEOF
for _p in "implementation-20261010T230257Z FAIL 2026-10-10T23:02:57Z" "implementation-20261010T234500Z PASS 2026-10-10T23:45:00Z"; do
  set -- $_p
  jq -n --arg n "$1" --arg v "$2" --arg g "$3" '{schema_id:"GATE_ADJUDICATION_VERDICT v1",gate_type:"implementation",
    gate_series_id:"implementation-gate-20261010T2300Z",gate_nonce:$n,generated_at:$g,adjudicator_agent_id:("agent-" + $n),
    catalog:"core",verdicts:[{check_id:"22",verdict:$v,evidence:"validate-spawn-ledger.sh --sprint 317"}]}' \
    > "$NOP/_bmad-output/gate-adjudication/$1.verdict.json"
done
set --
eqv cli-vga-pass "$VGA" vga --series "$NOP/_bmad-output/gate-adjudication"; _eq3=$?; _sr="$(cat "$EQ/cli-vga-pass.ip.rc")"
[ "$_eq3" = 0 ] && [ "$(cat "$EQ/cli-vga-pass.cl.rc")" = 0 ] \
  && ok "  cli-vga-pass: the program's stdout, stderr and exit 0 equal the in-process call's" \
  || bad "  cli-vga-pass: the program and the in-process call differ, or the outcome is not exit 0"
[ "$_sr" = 0 ] && ok "15t --series: 22 FAIL -> PASS with the resolution record exits 0" || bad "15t --series exited $_sr, expected 0"
mv "$NOP/_bmad-output/planning-artifacts/s317/gate-implementation-resolution-p1.md" "$WORK/q0-nop-record.md"
eqv cli-vga-refuse "$VGA" vga --series "$NOP/_bmad-output/gate-adjudication"; _eq4=$?; _sr="$(cat "$EQ/cli-vga-refuse.ip.rc")"
[ "$_eq4" = 0 ] && [ "$(cat "$EQ/cli-vga-refuse.cl.rc")" = 1 ] \
  && ok "  cli-vga-refuse: the program's stdout, stderr and exit 1 equal the in-process call's" \
  || bad "  cli-vga-refuse: the program and the in-process call differ, or the outcome is not exit 1"
[ "$_sr" = 1 ] && ok "  its control: the same series without the record exits 1" || bad "  15t --series without the record exited $_sr, expected 1"
[ ! -s "$NOP/docs/escalations/pending.md" ] && ok "15t pending.md is EMPTY throughout: no path above required an operator entry" \
  || bad "15t pending.md was written"

# BL-515 SAME-BATCH ORDER. Claude Code writes each tool_use of one assistant message as its own
# record sharing `message.id`. A sibling the cap ADMITTED in the rejection's own batch frees no slot.
t_usem() { # t_usem <message-id> <id> <description>
  jq -nc --arg m "$1" --arg id "$2" --arg d "$3" '{type:"assistant",isSidechain:false,
    message:{id:$m,role:"assistant",content:[{type:"tool_use",id:$id,name:"Agent",input:{description:$d}}]}}'
}
{ t_usem msg_B1 v1 "Party seat 7"; t_usem msg_B1 v2 "Party seat 8"
  t_res v1 "$CAPTXT" true; t_res v2 "Async agent launched successfully." false; } > "$CAPDIR/sb.jsonl"
{ t_usem msg_B1 v1 "Party seat 7"; t_res v1 "$CAPTXT" true
  t_usem msg_B2 v2 "Party seat 8"; t_res v2 "Async agent launched successfully." false; } > "$CAPDIR/sb2.jsonl"
BCX="$(capout "$CAPDIR/sb.jsonl" "Party seat 7")"; expect_deny "$BCX" "14h a re-send whose only later launch was a sibling in the rejection's own batch"
BCX="$(capout "$CAPDIR/sb2.jsonl" "Party seat 7")"; expect_quiet "$BCX" "14h' its twin: the same launch from a LATER message releases"

# BL-515 AN ERROR RESULT RELEASES NOTHING. A later Agent call that a HOOK refused (this guard's own
# deny among them) is an is_error tool_result that launched no agent, so no slot freed.
{ cat "$CAPDIR/a.jsonl"; t_use u5 Agent "Party seat 8"; t_res u5 "PreToolUse:Agent hook error: refused" true; } > "$CAPDIR/he.jsonl"
BCX="$(capout "$CAPDIR/he.jsonl" "Party seat 7")"; expect_deny "$BCX" "14i a re-send after only a HOOK-REFUSED Agent result (is_error, not the cap)"

# --- 16. WHO ISSUED THE SPAWN: parent_agent_id --------------------------------------------------
# A spawn made from inside a teammate carries the payload `agent_id`; the lead's carries none. The
# row records it as `parent_agent_id`, the EMPTY STRING for the lead and never null, so a join that
# counts writers can attribute a nested writer to the agent that dispatched it. The subject shape is
# the reference consumer's own nested call: `subagent_type: general-purpose`, no `name`, no role
# citation, a role with no team-roles file, issued by a requirements teammate.
#   16a a teammate-issued spawn writes a row at all, and is not denied
#   16b that row carries the teammate's agent_id
#   16c the same call from the lead writes `parent_agent_id: ""` -- the key present, a string, empty
PA_ID="a1c69096c184098d6"
PA_LEAD="$(jq -nc '{tool_name:"Agent",tool_use_id:"toolu_pa_lead",transcript_path:"/nonexistent",
  tool_input:{description:"PRD rubric walker",subagent_type:"general-purpose",prompt:"Walk the PRD rubric.",run_in_background:true}}')"
PA_MATE="$(printf '%s' "$PA_LEAD" | jq -c --arg a "$PA_ID" '.agent_id = $a | .tool_use_id = "toolu_pa_mate"')"
# pa_cell <guard> <json> -> "<rows>|<decision>|<parent_agent_id as JSON>" for one drive on an empty ledger.
pa_cell() {
  local out n p
  rm -f "$LEDGER"
  out="$(printf '%s' "$2" | CLAUDE_PROJECT_DIR="$CONSUMER" dgrun "$1" 2>/dev/null \
    | jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null)"
  n="$(wc -l < "$LEDGER" 2>/dev/null | tr -d ' ')"
  p="$(tail -1 "$LEDGER" 2>/dev/null | jq -c 'if has("parent_agent_id") then .parent_agent_id else "ABSENT" end' 2>/dev/null)"
  printf '%s|%s|%s' "${n:-0}" "${out:-none}" "${p:-NOROW}"
}
pa_vec() { printf '%s %s' "$(pa_cell "$1" "$PA_MATE")" "$(pa_cell "$1" "$PA_LEAD")"; }
PA_WANT="1|none|\"$PA_ID\" 1|none|\"\""
PA_GOT="$(pa_vec "$HOOK")"
PA_M="${PA_GOT%% *}"; PA_L="${PA_GOT#* }"
case "$PA_M" in 1\|none\|*) ok "16a a teammate-issued general-purpose spawn writes exactly one row and is not denied" ;;
  *) bad "16a a teammate-issued spawn produced '$PA_M' (rows|decision|parent), expected one row and no decision" ;; esac
[ "${PA_M##*|}" = "\"$PA_ID\"" ] && ok "16b the teammate row carries parent_agent_id = the payload agent_id" \
  || bad "16b the teammate row carries parent_agent_id ${PA_M##*|}, expected \"$PA_ID\""
[ "$PA_L" = '1|none|""' ] && ok "16c the lead row carries parent_agent_id \"\" (present, a string, empty)" \
  || bad "16c the lead row produced '$PA_L', expected '1|none|\"\"'"
# 16d/16e A ROLE-LESS spawn: `subagent_type: Explore` (the role pattern rejects a capital) and one
# carrying no `subagent_type`. From inside a teammate each is RECORDED with `role: ""` and its
# issuer; from the lead neither writes a row, which is the state the role-less arm above asserts.
# rl_cell <guard> <json> -> "<rows>|<decision>|<role>|<parent>" on an empty ledger.
rl_cell() {
  local out n r
  rm -f "$LEDGER"
  out="$(printf '%s' "$2" | CLAUDE_PROJECT_DIR="$CONSUMER" dgrun "$1" 2>/dev/null \
    | jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null)"
  n="$(wc -l < "$LEDGER" 2>/dev/null | tr -d ' ')"
  r="$(tail -1 "$LEDGER" 2>/dev/null | jq -r '"\(.role | tojson)|\(.parent_agent_id | tojson)"' 2>/dev/null)"
  printf '%s|%s|%s' "${n:-0}" "${out:-none}" "${r:-NOROW}"
}
RL_EXL="$(printf '%s' "$PA_LEAD" | jq -c '.tool_input.subagent_type = "Explore"')"
RL_EXM="$(printf '%s' "$RL_EXL" | jq -c --arg a "$PA_ID" '.agent_id = $a')"
RL_NTM="$(printf '%s' "$PA_MATE" | jq -c 'del(.tool_input.subagent_type)')"
rl_vec() { printf '%s %s %s' "$(rl_cell "$1" "$RL_EXM")" "$(rl_cell "$1" "$RL_NTM")" "$(rl_cell "$1" "$RL_EXL")"; }
RL_WANT="1|none|\"\"|\"$PA_ID\" 1|none|\"\"|\"$PA_ID\" 0|none|NOROW"
RL_GOT="$(rl_vec "$HOOK")"
case "$RL_GOT" in "1|none|\"\"|\"$PA_ID\" 1|none|\"\"|\"$PA_ID\" "*)
  ok "16d a teammate's Explore and type-less spawns are each recorded, role \"\", issuer named, no decision" ;;
  *) bad "16d role-less teammate spawns produced '$RL_GOT', expected the first two cells of '$RL_WANT'" ;; esac
[ "${RL_GOT##* }" = "0|none|NOROW" ] && ok "16e the lead's Explore spawn writes no row and gets no decision" \
  || bad "16e the lead's Explore spawn produced '${RL_GOT##* }', expected '0|none|NOROW'"
[ "$RL_GOT" = "$RL_WANT" ] || bad "16d/e FIXTURE BROKEN: unmutated vector '$RL_GOT' is not '$RL_WANT'"

# --- 16f-16h A ROLE-BOUND spawn from inside a subagent ---------------------------------------------
# The round dispatcher spawns its members from INSIDE a subagent, so the guard must bind such a spawn
# to its role exactly as it binds the lead's. The subject cites `analyst` (pinned sonnet) and requests
# opus, so the correcting path must rewrite the model. The lead's call is the control: the identical
# payload with no agent_id.
#   16f the nested spawn gets the same decision, rewritten model and role row as the lead's twin
#   16g that row carries role analyst and parent_agent_id = the payload agent_id
#   16h the twin's row carries parent_agent_id ""
AB_ID="a0123456789abcdef"
AB_LEAD="$(mkjson Agent analyst opus | jq -c '.tool_use_id = "toolu_ab_lead"')"
AB_MATE="$(printf '%s' "$AB_LEAD" | jq -c --arg a "$AB_ID" '.agent_id = $a | .tool_use_id = "toolu_ab_mate"')"
# ab_cell <guard> <json> -> "<rows>|<decision>|<injected model>|<row role>|<row parent_agent_id>" on an empty ledger.
ab_cell() {
  local out n d m r
  rm -f "$LEDGER"
  out="$(printf '%s' "$2" | CLAUDE_PROJECT_DIR="$CONSUMER" dgrun "$1" 2>/dev/null)"
  d="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null)"
  m="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.updatedInput.model // empty' 2>/dev/null)"
  n="$(wc -l < "$LEDGER" 2>/dev/null | tr -d ' ')"
  r="$(tail -1 "$LEDGER" 2>/dev/null | jq -r '"\(.role | tojson)|\(.parent_agent_id | tojson)"' 2>/dev/null)"
  printf '%s|%s|%s|%s' "${n:-0}" "${d:-none}" "${m:-none}" "${r:-NOROW}"
}
AB_M="$(ab_cell "$HOOK" "$AB_MATE")"; AB_L="$(ab_cell "$HOOK" "$AB_LEAD")"
[ "$AB_L" = '1|allow|sonnet|"analyst"|""' ] && [ "${AB_M%|*}" = "${AB_L%|*}" ] \
  && ok "16f a nested analyst spawn gets the lead twin's decision and rewrite (allow, model sonnet, one row)" \
  || bad "16f nested '$AB_M' differs from the lead twin '$AB_L' (expected the twin to be '1|allow|sonnet|\"analyst\"|\"\"')"
[ "$AB_M" = "1|allow|sonnet|\"analyst\"|\"$AB_ID\"" ] && ok "16g the nested row carries role analyst and parent_agent_id = the payload agent_id" \
  || bad "16g the nested spawn produced '$AB_M', expected '1|allow|sonnet|\"analyst\"|\"$AB_ID\"'"
[ "${AB_L##*|}" = '""' ] && ok "16h the lead twin's row carries parent_agent_id \"\"" \
  || bad "16h the lead twin produced '$AB_L', expected parent_agent_id \"\""
[ "$PA_GOT" = "$PA_WANT" ] || bad "16 FIXTURE BROKEN: the vector '$PA_GOT' is not '$PA_WANT'"


# --- THE GATE-PLAN DENY: AN IMPLEMENTATION GATE DISPATCH RUNS ONLY ON A PLAN -------------------
# One cell per contract bullet, scored as `<decision>:<note>:<reason>`. decision is read literally
# (`none` when the hook printed no permissionDecision). note is L for a pre-era note (the guard must never emit one), E for the
# EMPTY-position line, - for neither. reason is the deny condition the reason text names (a, b, c,
# c5, d, f1, e, f2, f26, g) or - for no deny, so two conditions that would both refuse one cell
# stay distinguishable. code-reviewer, its escalated twin and qa have no role file here, so an
# allowed dispatch of theirs prints nothing; gate-adjudicator is pinned, so its allow carries the
# model binding. Worlds are built once. The armed world GW carries the whole-line sentinel and a
# single `implementation.md` position; the plans are the program's line spellings.
GP_NS='implementation-20261104T010101Z'; GP_NX='implementation-20261104T020202Z'; GP_NF='implementation-20261104T030303Z'
GP_S1=1111111111111111111111111111111111111111; GP_S2=2222222222222222222222222222222222222222
GP_SENT='<!-- ai-dlc: gate-transition-plan-required v1 -->'
GP_PD='_bmad-output/implementation-artifacts/s320/gate-transition'
GP_MAN='_bmad-output/implementation-artifacts/s320/7-3-review-shards/.manifest'
gp_world() { # gp_world <name> <step-file body> <position block> -> prints the project dir
  local p="$WORK/gp-$1"
  mkdir -p "$p/.claude/skills/ai-dlc/steps" "$p/_bmad-output/.gate-checkpoint" "$p/$GP_PD" "$(dirname "$p/$GP_MAN")"
  cp -R "$CONSUMER/.claude/team-roles" "$p/.claude/"
  cp "$CONSUMER/.claude/.ai-dlc-version" "$CONSUMER/.claude/settings.json" "$p/.claude/"
  printf '%s\n' "$2" > "$p/.claude/skills/ai-dlc/steps/implementation.md"
  printf '# Pipeline Snapshot\n\n## Pipeline Position\n%s\n- sprint_id: 320\n\n## Recent Activity\n- none\n' "$3" > "$p/_bmad-output/pipeline-snapshot.md"
  gp_plan() { # gp_plan <file> <story> <gate> <sha> <manifest> [nonce] [map lines...]
    local f="$p/$GP_PD/$1" st="$2" g="$3" sh="$4" mn="$5" nc="${6-}"
    shift 6 2>/dev/null || shift $#
    { printf 'story: %s\ngate: %s\npass: 1\nsha: %s\nworktree: /w/%s\nmanifest: %s\nroute: full\n' "$st" "$g" "$sh" "$st" "$mn"
      [ -n "$nc" ] && printf 'nonce: %s\n' "$nc"
      for l in "$@"; do printf '%s\n' "$l"; done
      printf 'brief: story file _bmad-output/implementation-artifacts/%s.md\n' "$st"; } > "$f"
  }
  gp_plan 7-2-g1-p1.plan 7-2 1 "$GP_S1" none ''
  gp_plan 7-3-g1-p1.plan 7-3 1 "$GP_S1" "$GP_MAN" '' $'1\tcore\tsrc/a.sh' $'2\tdocs\tdocs/b.md'
  gp_plan 7-8-g1-p1.plan 7-8 1 "$GP_S1" "$GP_MAN" '' $'1\tcore,lib\tsrc/a.sh\tlib/c.sh' $'2\tdocs\tdocs/b.md'
  gp_plan 7-4-g1-p1.plan 7-4 1 "$GP_S2" "$GP_MAN" '' $'1\tcore\tsrc/a.sh' $'2\tdocs\tdocs/b.md'
  gp_plan 7-5-g1-p1.plan 7-5 1 "$GP_S1" none '' $'1\tcore\tsrc/a.sh' $'2\tdocs\tdocs/b.md'
  gp_plan 7-2-g3-p1.plan 7-2 3 "$GP_S1" none "$GP_NS"
  gp_plan 7-6-g3-p1.plan 7-6 3 "$GP_S1" none "$GP_NX"
  gp_plan 7-2-gclose-p1.plan 7-2 close "$GP_S1" none "$GP_NS"
  gp_plan 7-7-gclose-p1.plan 7-7 close "$GP_S1" none "$GP_NF"
  gp_plan 7-2-g2-p1.plan 7-2 rerun "$GP_S1" none ''
  gp_plan 7-2-g2-p3.plan 7-2 2 "$GP_S1" none ''
  gp_plan 7-5-g2-p1.plan 7-5 2 "$GP_S1" none '' $'1\tcore\tsrc/a.sh' $'2\tdocs\tdocs/b.md'
  printf 'worktree\t/w/7-3\nbase\t%s\nsha\t%s\nmin-files\t2\nmax-parts\t8\npart\t1\tcore\tsrc/a.sh\npart\t2\tdocs\tdocs/b.md\n' "$GP_S2" "$GP_S1" > "$p/$GP_MAN"
  printf '%s\n' "$GP_NS" > "$p/_bmad-output/.gate-checkpoint/OPEN"
  printf '1\tPASS\t2026-11-04T01:02:00Z\t\n26\tPASS\t2026-11-04T01:09:00Z\t\n' > "$p/_bmad-output/.gate-checkpoint/$GP_NS.tsv"
  printf '26\tFAIL\t2026-11-04T03:09:00Z\t\n' > "$p/_bmad-output/.gate-checkpoint/$GP_NF.tsv"
  printf '%s\n' "$p"
}
GP_POS='- current_step_file: steps/implementation.md'
GW="$(gp_world armed "$(printf '# Implementation\n%s\nbody' "$GP_SENT")" "$GP_POS")"
GL="$(gp_world legacy '# Implementation (no sentinel)' "$GP_POS")"
# TWO near-misses: prose naming the gate-planning token, and a line QUOTING the whole sentinel
# inside longer text. Only a whole-line match arms the deny; a substring match arms it on the second.
GN="$(gp_world near "$(printf '# Implementation\nThe gate-planning pass names gate-transition-plan-required.\nThe era line is `%s` once the reconcile lands.' "$GP_SENT")" "$GP_POS")"
GD="$(gp_world deploy "$(printf '# Implementation\n%s' "$GP_SENT")" '- current_step_file: steps/deploy-validate.md')"
GV="$(gp_world gatev "$(printf '# Implementation\n%s' "$GP_SENT")" '- **Current step file:** `steps/gate-validation.md`')"
GE="$(gp_world empty "$(printf '# Implementation\n%s' "$GP_SENT")" "$(printf '%s\n%s' "$GP_POS" '- current_step_file: steps/deploy-validate.md')")"
gp_pay() { # gp_pay <role> <brief lines...> -> an Agent dispatch of <role> carrying the lines
  local p l; p="Your operating contract is \`.claude/team-roles/$1.md\`. Read it first."; shift
  for l in "$@"; do p="$p"$'\n'"$l"; done
  jq -nc --arg p "$p"$'\n'"Do the work." '{tool_name:"Agent",tool_input:{name:"gate-plan",prompt:$p}}'
}
gp_run() { # gp_run <guard> <world> <role> <brief lines...> -> "<decision>:<note>:<reason>"
  local g="$1" w="$2" o d n r rs; shift 2
  o="$(gp_pay "$@" | CLAUDE_PROJECT_DIR="$w" dgrun "$g" 2>/dev/null)"
  d="$(jq -r '.hookSpecificOutput.permissionDecision // "none"' <<<"$o" 2>/dev/null)"; [ -n "$d" ] || d=none
  case "$o" in *"LEGACY: gate-plan deny inactive"*) n=L ;; *"gate-plan deny inactive: Pipeline Position unresolved (EMPTY)"*) n=E ;; *) n=- ;; esac
  r=-
  if [ "$d" = deny ]; then
    rs="$(jq -r '.hookSpecificOutput.permissionDecisionReason // empty' <<<"$o" 2>/dev/null)"
    case "$rs" in
      *"cross dispatch"*) r=cx ;; *"under a serial exception"*) r=nx ;; *"more than one \`gate-plan:\` line"*) r=m ;;
      *"carries no \`gate-plan:\` line"*) r=a ;; *"names no readable plan"*) r=b ;; *"is for story"*) r=c ;;
      *"no line of its plan"*) r=c5 ;; *"says \`manifest: none\`"*) r=f1 ;; *"partition manifest"*) r=d ;;
      *"no live gate-checkpoint OPEN"*) r=e ;; *"no ledger"*) r=f2 ;; *"no \`26 PASS\` row"*) r=f26 ;;
      *"plan, which only"*|*"runs only on a gate-3 plan"*|*"not a gate this role"*) r=g ;; *) r=o ;;
    esac
    case "$rs" in *"scripts/ai-dlc/gate-transition.sh <story> <1|2|3|close>"*) ;; *) r="$r!noremedy" ;; esac
  fi
  printf '%s:%s:%s' "$d" "$n" "$r"
}
gp_cell() { # gp_cell <guard> <cell>
  local P="$GP_PD"
  case "$2" in
    nogp)    gp_run "$1" "$GW" code-reviewer 'shard: 1/1 7-2' ;;
    absent)  gp_run "$1" "$GW" code-reviewer 'shard: 1/1 7-2' "gate-plan: $P/7-2-g2-p2.plan" ;;
    story)   gp_run "$1" "$GW" code-reviewer 'shard: 1/1 7-9' "gate-plan: $P/7-2-g1-p1.plan" ;;
    match)   gp_run "$1" "$GW" code-reviewer 'shard: 1/1 7-2' "gate-plan: \`$P/7-2-g1-p1.plan\`" ;;
    part)    gp_run "$1" "$GW" code-reviewer 'shard: 2/2 docs' "gate-plan: $P/7-3-g1-p1.plan" ;;
    partx)   gp_run "$1" "$GW" code-reviewer 'shard: 2/2 core' "gate-plan: $P/7-3-g1-p1.plan" ;;
    sha)     gp_run "$1" "$GW" code-reviewer 'shard: 1/2 core' "gate-plan: $P/7-4-g1-p1.plan" ;;
    mnone)   gp_run "$1" "$GW" code-reviewer 'shard: 1/2 core' "gate-plan: $P/7-5-g1-p1.plan" ;;
    qamnone) gp_run "$1" "$GW" qa 'shard: 1/2 core' "gate-plan: $P/7-5-g2-p1.plan" ;;
    esc)     gp_run "$1" "$GW" code-reviewer-escalated 'shard: 1/1 7-2' ;;
    escok)   gp_run "$1" "$GW" code-reviewer-escalated 'shard: 1/1 7-2' "gate-plan: $P/7-2-g1-p1.plan" ;;
    cw)      gp_run "$1" "$GW" code-reviewer 'You are the closing writer for story 7-2.' 'shard: 1/1 7-2' "gate-plan: $P/7-2-g3-p1.plan" ;;
    cwword)  gp_run "$1" "$GW" code-reviewer 'You are the closing writer for story 7-2.' 'shard: 1/1 7-2' ;;
    cwnoled) gp_run "$1" "$GW" code-reviewer 'shard: 1/1 7-6' "gate-plan: $P/7-6-g3-p1.plan" ;;
    close)   gp_run "$1" "$GW" code-reviewer 'shard: 1/1 7-2' "gate-plan: $P/7-2-gclose-p1.plan" ;;
    close26) gp_run "$1" "$GW" code-reviewer 'shard: 1/1 7-7' "gate-plan: $P/7-7-gclose-p1.plan" ;;
    rerunqa) gp_run "$1" "$GW" qa 'shard: 1/1 7-2' "gate-plan: $P/7-2-g2-p1.plan" ;;
    rerunrv) gp_run "$1" "$GW" code-reviewer 'shard: 1/1 7-2' "gate-plan: $P/7-2-g2-p1.plan" ;;
    qag1)    gp_run "$1" "$GW" qa 'shard: 1/1 7-2' "gate-plan: $P/7-2-g1-p1.plan" ;;
    rvg2)    gp_run "$1" "$GW" code-reviewer 'shard: 1/1 7-2' "gate-plan: $P/7-2-g2-p3.plan" ;;
    qag2)    gp_run "$1" "$GW" qa 'shard: 1/1 7-2' "gate-plan: $P/7-2-g2-p3.plan" ;;
    packed)  gp_run "$1" "$GW" code-reviewer 'shard: 1/2 lib' "gate-plan: $P/7-8-g1-p1.plan" ;;
    packedx) gp_run "$1" "$GW" code-reviewer 'shard: 1/2 docs' "gate-plan: $P/7-8-g1-p1.plan" ;;
    cross)   gp_run "$1" "$GW" code-reviewer 'shard: cross/2 g1/1 1,2' "gate-plan: $P/7-3-g1-p1.plan" ;;
    crossx)  gp_run "$1" "$GW" code-reviewer 'shard: cross/3 g1/1 1,2,3' "gate-plan: $P/7-3-g1-p1.plan" ;;
    nonex)   gp_run "$1" "$GW" qa 'shard: none (4)' "gate-plan: $P/7-2-g1-p1.plan" ;;
    noshard) gp_run "$1" "$GW" code-reviewer 'Read the story.' ;;
    multi)   gp_run "$1" "$GW" code-reviewer 'shard: 1/1 7-2' "gate-plan: $P/7-2-g1-p1.plan" "gate-plan: $P/7-2-g1-p1.plan" ;;
    g3sh)    gp_run "$1" "$GW" code-reviewer 'shard: 1/2 core' "gate-plan: $P/7-2-g3-p1.plan" ;;
    adj)     gp_run "$1" "$GW" gate-adjudicator "gate_nonce: $GP_NS" 'story: 7-2' "gate-plan: $P/7-2-g3-p1.plan" ;;
    adjno)   gp_run "$1" "$GW" gate-adjudicator "gate_nonce: $GP_NX" 'story: 7-6' "gate-plan: $P/7-6-g3-p1.plan" ;;
    adjsh)   gp_run "$1" "$GW" gate-adjudicator 'shard: 1/3 implementation' 'story: 7-2' ;;
    adjnp)   gp_run "$1" "$GW" gate-adjudicator "gate_nonce: $GP_NS" 'story: 7-2' ;;
    adjsl)   gp_run "$1" "$GW" gate-adjudicator "gate_nonce: $GP_NS" ;;
    adjslsh) gp_run "$1" "$GW" gate-adjudicator "gate_nonce: $GP_NS" 'shard: 1/2 implementation' ;;
    legacy)  gp_run "$1" "$GL" code-reviewer 'shard: 1/1 7-2' ;;
    near)    gp_run "$1" "$GN" code-reviewer 'shard: 1/1 7-2' ;;
    deploy)  gp_run "$1" "$GD" code-reviewer 'shard: 1/1 7-2' ;;
    gv)      gp_run "$1" "$GV" qa 'shard: 1/1 7-2' ;;
    empty)   gp_run "$1" "$GE" code-reviewer 'shard: 1/1 7-2' ;;
  esac
}
ALL_GP=nogp,absent,story,match,part,partx,sha,mnone,esc,escok,cw,cwword,cwnoled,close,close26,g3sh,adj,adjno,adjsh,legacy,near,deploy,gv,empty,rerunqa,rerunrv,qag1,rvg2,qag2,qamnone,packed,packedx,cross,crossx,nonex,noshard,multi,adjnp,adjsl,adjslsh
GP_WANT='nogp=deny:-:a;absent=deny:-:b;story=deny:-:c;match=none:-:-;part=none:-:-;partx=deny:-:c5;sha=deny:-:d;mnone=deny:-:f1;esc=deny:-:a;escok=none:-:-;cw=none:-:-;cwword=deny:-:a;cwnoled=deny:-:f2;close=none:-:-;close26=deny:-:f26;g3sh=deny:-:g;adj=allow:-:-;adjno=deny:-:e;adjsh=deny:-:a;legacy=none:-:-;near=none:-:-;deploy=none:-:-;gv=deny:-:a;empty=none:E:-;rerunqa=deny:-:g;rerunrv=deny:-:g;qag1=deny:-:g;rvg2=deny:-:g;qag2=none:-:-;qamnone=deny:-:f1;packed=none:-:-;packedx=deny:-:c5;cross=none:-:-;crossx=deny:-:cx;nonex=deny:-:nx;noshard=none:-:-;multi=deny:-:m;adjnp=deny:-:a;adjsl=allow:-:-;adjslsh=allow:-:-'
GP_TIP="$(for _c in ${ALL_GP//,/ }; do printf '%s=%s;' "$_c" "$(gp_cell "$HOOK" "$_c")"; done)"
_old_ifs="$IFS"; IFS=';'
for _c in $GP_WANT; do
  case ";$GP_TIP" in
    *";$_c;"*) ok "GATE-PLAN ${_c%%=*}: '${_c#*=}' (decision:note:reason)" ;;
    *) bad "GATE-PLAN ${_c%%=*}: expected '${_c#*=}', got vector '$GP_TIP'" ;;
  esac
done
IFS="$_old_ifs"

# --- CHECK (e) ACROSS A GATE CLOSED EARLY AND THEN RESUMED (BL-1009) -------------------------------
# ai-dlc-handoff-entry.sh closes the OPEN marker when the lead whole-reads ANOTHER step while a gate
# is open, and gate-checkpoint.sh's `record` at the nonce LEFT names re-opens it. Check (e) reads only
# OPEN, so between those two acts the adjudicator is refused, and after the re-open it is allowed
# again. Nothing is hand-written to OPEN or LEFT here: the REAL hook closes, by a real PostToolUse
# Read payload, with STEP bound to the reading session as the engine writes it, and the checkpoint
# script under test (installed where the hook locates it) re-opens. A cell is
# "<gate-plan cell>|o<OPEN carries GP_NS: 1|0>|l<LEFT present: 1|0>". Each cell copies one base world.
LV_CKP=""; for _c in "$REM_ROOT/core/scripts/gate-checkpoint.sh" "$REM_ROOT/scripts/ai-dlc/gate-checkpoint.sh"; do
  [ -f "$_c" ] && { LV_CKP="$_c"; break; }; done
[ -n "$LV_CKP" ] && echo "HERMETIC-CONSUMED $LV_CKP" || bad "LEAVE FIXTURE BROKEN: gate-checkpoint.sh not found beside $HOOK"
LV_HE="$HOOKS_SRC/ai-dlc-handoff-entry.sh"
[ -f "$LV_HE" ] || bad "LEAVE FIXTURE BROKEN: ai-dlc-handoff-entry.sh not found beside $HOOK"
# THE FIXTURE SHIPS AHEAD OF ITS SUBJECT (consumer-boundary.md): a delivering pull can carry this
# section while the installed handoff-entry hook still predates the gate-leave close. Such a hook is
# detected by CODE, never by a comment: no line reads or writes `${<dir>}/STEP` before any `#`. Then
# every cell prints SKIP on a consumer (a FAIL in the distribution), by name, and
# none prints ok. The detector is probed
# both ways on seeded lines first: a commented write must read absent, the same write live present.
lv_has_m1() { local n; n="$(grep -cE '^[^#]*\}/STEP' "$1" 2>/dev/null)" || n=0; [ "$n" -gt 0 ]; }
LV_PR="$WORK/lv-m1-probe"
printf '#   printf x > "${d}/STEP"\n' > "$LV_PR.old"; printf '    printf x > "${d}/STEP"\n' > "$LV_PR.new"
if ! lv_has_m1 "$LV_PR.old" && lv_has_m1 "$LV_PR.new"; then
  ok "LEAVE m1-detector: a commented STEP write reads as no gate-leave close, a live one as present"
else bad "LEAVE m1-detector: cannot tell a commented STEP write from a live one -- the SKIP below is not believable"; fi
LV_M1=0; lv_has_m1 "$LV_HE" && LV_M1=1
LV_SID='lv-session-0001'
if [ "$LV_M1" = 1 ]; then
LV_BASE="$(gp_world leave "$(printf '# Implementation\n%s\nbody' "$GP_SENT")" "$GP_POS")"
printf 'implementation\t%s\n' "$LV_SID" > "$LV_BASE/_bmad-output/.gate-checkpoint/STEP"
lv_cell() { # lv_cell <gate-checkpoint script> <cell> -- a fresh copy per call (it runs inside $( ), so no counter survives)
  local w o l
  w="$(mktemp -d "$WORK/lv-$2.XXXXXX")" && cp -R "$LV_BASE/." "$w/" && mkdir -p "$w/scripts/ai-dlc" && cp "$1" "$w/scripts/ai-dlc/gate-checkpoint.sh" \
    && chmod +x "$w/scripts/ai-dlc/gate-checkpoint.sh" || { printf 'unbuilt'; return; }
  case "$2" in lvleft|lvback)
    jq -nc --arg f "$w/.claude/skills/ai-dlc/steps/deploy-validate.md" --arg s "$LV_SID" \
      '{session_id:$s,hook_event_name:"PostToolUse",tool_name:"Read",tool_input:{file_path:$f},tool_response:{}}' \
      | CLAUDE_PROJECT_DIR="$w" bash "$LV_HE" >/dev/null 2>&1 ;;
  esac
  [ "$2" = lvback ] && bash "$w/scripts/ai-dlc/gate-checkpoint.sh" --root "$w" --nonce "$GP_NS" record c1 PASS >/dev/null 2>&1
  o=0; [ "$(cat "$w/_bmad-output/.gate-checkpoint/OPEN" 2>/dev/null)" = "$GP_NS" ] && o=1
  l=0; [ -f "$w/_bmad-output/.gate-checkpoint/LEFT" ] && l=1
  printf '%s|o%s|l%s' "$(gp_run "$HOOK" "$w" gate-adjudicator "gate_nonce: $GP_NS" 'story: 7-2' "gate-plan: $GP_PD/7-2-g3-p1.plan")" "$o" "$l"
}
ALL_LV=lvopen,lvleft,lvback
LV_WANT='lvopen=allow:-:-|o1|l0;lvleft=deny:-:e|o0|l1;lvback=allow:-:-|o1|l0'
LV_TIP="$(for _c in ${ALL_LV//,/ }; do printf '%s=%s;' "$_c" "$(lv_cell "$LV_CKP" "$_c")"; done)"
_old_ifs="$IFS"; IFS=';'
for _c in $LV_WANT; do
  case ";$LV_TIP" in
    *";$_c;"*) ok "LEAVE ${_c%%=*}: '${_c#*=}' (decision:note:reason|OPEN|LEFT)" ;;
    *) bad "LEAVE ${_c%%=*}: expected '${_c#*=}', got vector '$LV_TIP'" ;;
  esac
done
IFS="$_old_ifs"
else
  # HARD in the distribution, SKIP on a consumer: gate-resume's skip() and its layout test (seed.sh,
  # IS_DIST: this repo carries core/skills/ai-dlc, a consumer does not). Here the hook IS the subject,
  # so a distribution hook without the close is a deleted close, never a pull still in flight.
  LV_IS_DIST=0; [ -d "$REM_ROOT/core/skills/ai-dlc" ] && LV_IS_DIST=1
  lv_skip() { # lv_skip <what> <why>
    if [ "$LV_IS_DIST" = 1 ]; then bad "$1 -- $2 (HARD in the distribution: the subject must be present here)"
    else printf '  SKIP  %s -- %s\n' "$1" "$2"; fi
  }
  for _c in lvopen lvleft lvback; do
    lv_skip "LEAVE $_c" "$LV_HE predates the gate-leave close (no code line reads or writes .gate-checkpoint/STEP), so this cell checked NOTHING"
  done
fi

# ===== THE DELIVERABLE-LINE DENY (BL-819) ==========================================================
# NO SKIP ARM FOR AN ABSENT GUARD BLOCK, BY RULING: this section ships in the SAME release as the guard
# block it drives, so no delivering pull carries one without the other, and a skip would be a check
# that cannot fire on the only path that reaches it.
# A LEAD dispatch of a role with a readable team-role file, whose prompt yields no path to deliverable_of
# and whose brief gives no mark_file, is refused when the project has a pipeline snapshot, an installed
# _gate-procedures.md carrying the era sentence, and the call is not foreground or from a nested agent
# or an /ai-dlc-update session. The cells drive that subject through the shipping guard in a seeded
# consumer; the step file is a COPY OF THE REAL ONE, so the era sentence is read from where it ships.
#
# deliverable_of IS SHARED BYTE-IDENTICALLY with ai-dlc-inflight-row.sh and this section binds the copies.
# The comparison is probed in both directions BEFORE it reads the real files, and the definition count
# is probed so that a missing or a doubled definition can fail.
dl_fn() { # dl_fn <file> -> the text of its deliverable_of definition, from its opening line to the first closing brace
  awk '/^deliverable_of\(\) \{$/ { f = 1 } f { print } f && /^\}$/ { exit }' "$1"
}
dl_ndef() { awk '/^deliverable_of\(\) \{/ { n++ } END { print n + 0 }'; }
dl_same() { # dl_same <text a> <text b> -> SAME | DIFFER, compared byte for byte
  if cmp -s <(printf '%s\n' "$1") <(printf '%s\n' "$2"); then echo SAME; else echo DIFFER; fi
}
DL_IFR="$(dirname "$HOOK")/ai-dlc-inflight-row.sh"
DL_RB=""; for _c in "$REM_ROOT/core/scripts/render-brief.sh" "$REM_ROOT/scripts/ai-dlc/render-brief.sh" "$REM_ROOT/.claude/scripts/ai-dlc/render-brief.sh"; do
  [ -f "$_c" ] && { DL_RB="$_c"; break; }; done
DL_FN_G="$(dl_fn "$HOOK")"; DL_FN_I="$(dl_fn "$DL_IFR")"
# the probe: two copies one byte apart (the sides are asserted to differ first), and a doubled/absent definition
DL_FN_P="${DL_FN_I/LC_ALL=C awk/LC_ALL=C awx}"
if [ "$DL_FN_P" != "$DL_FN_I" ] && [ "$(dl_same "$DL_FN_I" "$DL_FN_P")" = DIFFER ] && [ "$(dl_same "$DL_FN_I" "$DL_FN_I")" = SAME ] \
   && [ "$(printf '%s\n%s\n' "$DL_FN_I" "$DL_FN_I" | dl_ndef)" = 2 ] && [ "$(printf '%s\n' "$DL_FN_I" | dl_ndef)" = 1 ] \
   && [ "$(printf 'echo hi\n' | dl_ndef)" = 0 ]; then
  ok "DELIVERABLE-LINE bind probe: two copies one byte apart compare DIFFER, a copy against itself SAME, and the definition count reads 2, 1 and 0 on seeded text"
else bad "DELIVERABLE-LINE bind probe FAILED: the byte comparison or the definition count cannot tell its seeded cases apart, so the bind below is not believable"; fi
[ "$(dl_ndef < "$HOOK")" = 1 ] && [ "$(dl_ndef < "$DL_IFR")" = 1 ] \
  && ok "DELIVERABLE-LINE bind: exactly one deliverable_of definition in the guard and one in ai-dlc-inflight-row.sh" \
  || bad "DELIVERABLE-LINE bind: the guard has $(dl_ndef < "$HOOK") deliverable_of definitions and ai-dlc-inflight-row.sh has $(dl_ndef < "$DL_IFR"), expected 1 and 1"
if [ -n "$DL_RB" ]; then
  # three copies: the guard, the row writer and render-brief.sh; a fourth anywhere in the hook or script directories fails
  DL_NDEF_ALL="$(grep -rlE '^deliverable_of\(\) \{' "$(dirname "$HOOK")" "$(dirname "$DL_RB")" 2>/dev/null | wc -l | tr -d ' ')"
  [ "$(dl_ndef < "$DL_RB")" = 1 ] && [ "$DL_NDEF_ALL" = 3 ] \
    && ok "DELIVERABLE-LINE bind: render-brief.sh holds one deliverable_of definition and the hook and script directories hold exactly 3 files defining it" \
    || bad "DELIVERABLE-LINE bind: render-brief.sh has $(dl_ndef < "$DL_RB") definitions and $DL_NDEF_ALL files define deliverable_of, expected 1 and 3"
  [ -n "$DL_FN_G" ] && [ "$(dl_same "$DL_FN_G" "$(dl_fn "$DL_RB")")" = SAME ] \
    && ok "DELIVERABLE-LINE bind: render-brief.sh's deliverable_of is byte-identical to the guard's" \
    || bad "DELIVERABLE-LINE bind: render-brief.sh's deliverable_of DIFFERS from the guard's, so it renders a line the guard reads differently"
  # MARK-LINE: a JSON or JSONL deliverable's brief carries no closing --mark line; the .md twin in the same
  # directory, with json in its name, carries the exact one. One start per seed shape.
  echo "HERMETIC-CONSUMED $DL_RB"
  ML_D="$WORK/mark-line/_bmad-output/gate-adjudication"; ML_N=planning-20261123T100000Z
  ml_rb() { # ml_rb <cell> <deliverable> [render-brief args...] -> ML_RC, ML_B (the printed path)
    local c="$1" d="$2"; shift 2
    ML_B="$(FXCELL="$c" bash "$DL_RB" --role gate-adjudicator --step planning --deliverable "$d" --mark-step planning --out "$WORK/mark-line/briefs-$c" "$@" </dev/null 2>/dev/null)"; ML_RC=$?
  }
  ml_nomark() { # ml_nomark <deliverable>: rendered, Deliverable line present, no --mark line
    [ "$ML_RC" = 0 ] && [ -f "$ML_B" ] && grep -qxF "Deliverable: $1" "$ML_B" && ! grep -q -- '--mark' "$ML_B"
  }
  ml_rb cli-rb-jsonl "$ML_D/$ML_N.part-1of2.jsonl" --shard "1/2 planning"
  ml_nomark "$ML_D/$ML_N.part-1of2.jsonl" \
    && ok "MARK-LINE: a sharded .jsonl gate part's brief is rendered with its Deliverable line and no --mark line" \
    || bad "MARK-LINE: the .jsonl gate part's brief (rc=$ML_RC) lacks its Deliverable line or carries a --mark line the merge will refuse"
  ml_rb cli-rb-json "$ML_D/$ML_N.verdict.json"
  ml_nomark "$ML_D/$ML_N.verdict.json" \
    && ok "MARK-LINE: a .verdict.json deliverable's brief is rendered with its Deliverable line and no --mark line" \
    || bad "MARK-LINE: the .verdict.json brief (rc=$ML_RC) lacks its Deliverable line or carries a --mark line that breaks json.load"
  ml_rb cli-rb-md "$ML_D/$ML_N.json.md"
  [ "$ML_RC" = 0 ] && [ -f "$ML_B" ] \
    && grep -qF "\`scripts/ai-dlc/wait-for-deliverable.sh --mark $ML_D/$ML_N.json.md planning gate-adjudicator none findings=<n>\`" "$ML_B" \
    && ok "MARK-LINE twin: a .json.md deliverable in the same directory keeps its exact --mark line" \
    || bad "MARK-LINE twin: the .json.md deliverable's brief (rc=$ML_RC) lost its --mark line, so render-brief drops more than JSON"
else printf '  SKIP  DELIVERABLE-LINE bind: render-brief.sh is not installed beside the hooks (the subject ships ahead of a consumer pull)\n'; fi
be_fn() { awk '/^brief_expand\(\) \{/ { f = 1 } f { print } f && /^\}$/ { exit }' "$1"; }
DL_BE_G="$(be_fn "$HOOK")"; DL_BE_I="$(be_fn "$DL_IFR")"
[ -n "$DL_BE_G" ] && [ "$(printf '%s\n' "$DL_BE_G" | tail -1)" = "}" ] && [ "$(dl_same "$DL_BE_G" "$DL_BE_I")" = SAME ] \
  && [ "$(dl_same "$DL_BE_G" "${DL_BE_G/pwd -P/pwd}")" = DIFFER ] && [ "$(grep -c '^brief_expand() {' "$HOOK")" = 1 ] && [ "$(grep -c '^brief_expand() {' "$DL_IFR")" = 1 ] \
  && ok "BRIEF-EXPAND bind: one brief_expand in the guard and one in ai-dlc-inflight-row.sh, byte-identical, non-empty and closed" \
  || bad "BRIEF-EXPAND bind: the guard's and the row writer's brief_expand are missing, doubled or DIFFER"
[ -n "$DL_FN_G" ] && [ -n "$DL_FN_I" ] && [ "$(printf '%s\n' "$DL_FN_G" | tail -1)" = "}" ] && [ "$(printf '%s\n' "$DL_FN_I" | tail -1)" = "}" ] \
  && ok "DELIVERABLE-LINE bind: both extractions are non-empty and end at the closing brace" \
  || bad "DELIVERABLE-LINE bind: an extraction is empty or does not close (guard $(printf '%s' "$DL_FN_G" | wc -c | tr -d ' ') bytes, inflight-row $(printf '%s' "$DL_FN_I" | wc -c | tr -d ' ') bytes)"
[ -n "$DL_FN_G" ] && [ "$(dl_same "$DL_FN_G" "$DL_FN_I")" = SAME ] \
  && ok "DELIVERABLE-LINE bind: the guard's deliverable_of is byte-identical to ai-dlc-inflight-row.sh's" \
  || bad "DELIVERABLE-LINE bind: the two deliverable_of copies DIFFER, so the guard judges a brief by a grammar the row writer does not use"

DL_ERA="$(sed -n "s/^DG_DL_ERA='\(.*\)'\$/\1/p" "$HOOK")"
# rooted at the fixture's own location, both layouts named (I33): core/fixtures/<fx> and tests/fixtures/<fx>
DL_STEP="$HERE/../../skills/ai-dlc/steps/_gate-procedures.md"
[ -f "$DL_STEP" ] || DL_STEP="$HERE/../../../.claude/skills/ai-dlc/steps/_gate-procedures.md"
[ -n "$DL_ERA" ] && [ "$(grep -cF -- "$DL_ERA" "$DL_STEP" 2>/dev/null)" = 1 ] \
  && ok "DELIVERABLE-LINE era: the guard's era sentence is read from the hook and the shipped _gate-procedures.md carries it exactly once" \
  || bad "DELIVERABLE-LINE era: the era sentence '$DL_ERA' is empty or not carried exactly once by $DL_STEP"
DL_NOERA="$WORK/dl-step-noera.md"
grep -vF -- "$DL_ERA" "$DL_STEP" > "$DL_NOERA" || true
cmp -s "$DL_STEP" "$DL_NOERA" && bad "DELIVERABLE-LINE era: the era-less step file equals the real one, so the noera cell would not differ"
[ "$(grep -cF -- "$DL_ERA" "$DL_NOERA" 2>/dev/null)" = 0 ] || bad "DELIVERABLE-LINE era: the era-less step file still carries the sentence"

dl_world() { # dl_world <name> <step file|-> <snapshot yes|no> -> the project dir
  local p="$WORK/dl-$1"
  mkdir -p "$p/.claude/skills/ai-dlc/steps" "$p/_bmad-output"
  cp -R "$CONSUMER/.claude/team-roles" "$p/.claude/"
  cp "$CONSUMER/.claude/.ai-dlc-version" "$CONSUMER/.claude/settings.json" "$p/.claude/"
  [ "$2" = - ] || cp "$2" "$p/.claude/skills/ai-dlc/steps/_gate-procedures.md"
  if [ "$3" = yes ]; then printf '# Pipeline Snapshot\n\n## Pipeline Position\n- current_step_file: steps/implementation.md\n' > "$p/_bmad-output/pipeline-snapshot.md"; fi
  printf '%s\n' "$p"
}
DLA="$(dl_world armed "$DL_STEP" yes)"; DLB="$(dl_world nosnap "$DL_STEP" no)"; DLC="$(dl_world noera "$DL_NOERA" yes)"
# transcripts in the shapes the harness writes: the slash-command record and the Skill tool_use
DL_UPD_MSG="$(printf '<command-message>ai-dlc-update</command-message>\n<command-name>/ai-dlc-update</command-name>')"
DL_LEAD_MSG="$(printf '<command-message>ai-dlc</command-message>\n<command-name>/ai-dlc</command-name>')"
DL_REC_UPD="$(jq -nc --arg c "$DL_UPD_MSG" '{type:"user",message:{role:"user",content:$c}}')"
DL_REC_LEAD="$(jq -nc --arg c "$DL_LEAD_MSG" '{type:"user",message:{role:"user",content:$c}}')"
DL_REC_SKILL="$(jq -nc '{type:"assistant",message:{role:"assistant",content:[{type:"tool_use",id:"toolu_sk",name:"Skill",input:{skill:"ai-dlc-update"}}]}}')"
printf '%s\n' "$DL_REC_UPD" > "$WORK/dl-tr-updcmd.jsonl"
printf '%s\n' "$DL_REC_SKILL" > "$WORK/dl-tr-updskill.jsonl"
printf '%s\n%s\n' "$DL_REC_UPD" "$DL_REC_LEAD" > "$WORK/dl-tr-updlead.jsonl"
printf '%s\n' "$DL_REC_LEAD" > "$WORK/dl-tr-lead.jsonl"
DL_MARK='Run `scripts/ai-dlc/wait-for-deliverable.sh --mark _bmad-output/party-mode/s320/dev-1.md implementation dev 1/1 findings=0` when done.'
DLA_PA="$DLA/_bmad-output/planning-artifacts"; mkdir -p "$DLA_PA"
printf '# Brief\nDeliverable: x/y.md\n' > "$DLA_PA/b-ok.md"
printf '# Brief\nno deliverable line here\n' > "$DLA_PA/b-nodl.md"
printf '# Brief\nDeliverable: x/y.md\nYour operating contract is `.claude/team-roles/dev.md`.\n' > "$DLA_PA/b-role.md"
printf '# Brief\nDeliverable: x/y.md\n' > "$DLA/_bmad-output/escape.md"
DL_MARKBAD='Run `scripts/ai-dlc/wait-for-deliverable.sh --mark _bmad-output/party-mode/s320/dev-1.md implementation dev 1/1` when done.'
dl_base() { mkjson Agent dev sonnet | jq -c '.tool_use_id = "toolu_dl" | .transcript_path = "/nonexistent" | .tool_input.run_in_background = true'; }
dl_add() { jq -c --arg s "$2" '.tool_input.prompt += $s' <<<"$1"; } # dl_add <json> <text appended to the prompt>
dl_rows() { local n=0; [ -f "$1/_bmad-output/spawn-ledger.jsonl" ] && n="$(wc -l < "$1/_bmad-output/spawn-ledger.jsonl" | tr -d ' ')"; printf '%s' "${n:-0}"; }
dl_run() { printf '%s' "$3" | CLAUDE_PROJECT_DIR="$2" dgrun "$1" 2>/dev/null; } # dl_run <guard> <world> <json> -> hook stdout
dl_kind() { # dl_kind <hook stdout> -> dl (THIS deny) | other (a different deny) | pass
  local d rs
  d="$(jq -r '.hookSpecificOutput.permissionDecision // empty' <<<"$1" 2>/dev/null)"
  if [ "$d" = deny ]; then
    rs="$(jq -r '.hookSpecificOutput.permissionDecisionReason // empty' <<<"$1" 2>/dev/null)"
    case "$rs" in *'carries no `Deliverable: <path>` line'*) echo dl ;; *) echo other ;; esac
  else echo pass; fi
}
dl_cell() { # dl_cell <guard> <cell> -> "<kind>:<ledger rows after one call on a fresh ledger>"; seq -> the rows after allow, refuse, allow
  local g="$1" c="$2" w="$DLA" j o n1 n2 n3
  j="$(dl_base)"
  case "$c" in
    nodl|seq) ;;
    dl)       j="$(dl_add "$j" $'\nDeliverable: x/y.md')" ;;
    dlmid)    j="$(dl_add "$j" $'\nnotes first\nDeliverable: x/y.md\nand more')" ;;
    indent)   j="$(dl_add "$j" $'\n  Deliverable: x/y.md')" ;;
    bold)     j="$(dl_add "$j" $'\n**Deliverable:** x/y.md')" ;;
    nopath)   j="$(dl_add "$j" $'\nDeliverable: to be decided')" ;;
    bgabsent) j="$(jq -c 'del(.tool_input.run_in_background)' <<<"$j")" ;;
    agent)    j="$(jq -c '.agent_id = "a1c69096c184098d6"' <<<"$j")" ;;
    fg)       j="$(jq -c '.tool_input.run_in_background = false' <<<"$j")" ;;
    nosnap)   w="$DLB" ;;
    noera)    w="$DLC" ;;
    updcmd)   j="$(jq -c --arg t "$WORK/dl-tr-updcmd.jsonl" '.transcript_path = $t' <<<"$j")" ;;
    updskill) j="$(jq -c --arg t "$WORK/dl-tr-updskill.jsonl" '.transcript_path = $t' <<<"$j")" ;;
    updlead)  j="$(jq -c --arg t "$WORK/dl-tr-updlead.jsonl" '.transcript_path = $t' <<<"$j")" ;;
    leadtr)   j="$(jq -c --arg t "$WORK/dl-tr-lead.jsonl" '.transcript_path = $t' <<<"$j")" ;;
    role)     j="$(mkjson Agent ghostrole sonnet | jq -c '.tool_use_id = "toolu_dl" | .transcript_path = "/nonexistent" | .tool_input.run_in_background = true')" ;;
    mark)     j="$(dl_add "$j" $'\n'"$DL_MARK")" ;;
    markbad)  j="$(dl_add "$j" $'\n'"$DL_MARKBAD")" ;;
    brief)    j="$(dl_add "$j" $'\nBrief: _bmad-output/planning-artifacts/b-ok.md')" ;;
    briefnodl) j="$(dl_add "$j" $'\nBrief: _bmad-output/planning-artifacts/b-nodl.md')" ;;
    briefmiss) j="$(dl_add "$j" $'\nBrief: _bmad-output/planning-artifacts/b-absent.md')" ;;
    briefesc) j="$(dl_add "$j" $'\nBrief: _bmad-output/planning-artifacts/../escape.md')" ;;
    briefrole) j="$(mkjson Agent - sonnet | jq -c '.tool_use_id = "toolu_dl" | .transcript_path = "/nonexistent" | .tool_input.run_in_background = true')"
               j="$(dl_add "$j" $'\nBrief: _bmad-output/planning-artifacts/b-role.md')" ;;
  esac
  rm -f "$w/_bmad-output/spawn-ledger.jsonl"
  if [ "$c" = seq ]; then
    dl_run "$g" "$w" "$(dl_add "$(dl_base)" $'\nDeliverable: x/y.md')" >/dev/null; n1="$(dl_rows "$w")"
    dl_run "$g" "$w" "$j" >/dev/null; n2="$(dl_rows "$w")"
    dl_run "$g" "$w" "$(dl_add "$(dl_base)" $'\nDeliverable: x/y.md')" >/dev/null; n3="$(dl_rows "$w")"
    printf '%s-%s-%s' "$n1" "$n2" "$n3"; return
  fi
  o="$(dl_run "$g" "$w" "$j")"
  printf '%s:%s' "$(dl_kind "$o")" "$(dl_rows "$w")"
}
ALL_DL=nodl,dl,dlmid,indent,bold,nopath,bgabsent,agent,fg,nosnap,noera,updcmd,updskill,updlead,leadtr,role,mark,markbad,seq,brief,briefnodl,briefmiss,briefesc,briefrole
DL_WANT='nodl=dl:0;dl=pass:1;dlmid=pass:1;indent=dl:0;bold=dl:0;nopath=dl:0;bgabsent=dl:0;agent=pass:1;fg=pass:1;nosnap=pass:1;noera=pass:1;updcmd=pass:1;updskill=pass:1;updlead=dl:0;leadtr=dl:0;role=pass:1;mark=pass:1;markbad=dl:0;seq=1-1-2;brief=pass:1;briefnodl=dl:0;briefmiss=dl:0;briefesc=dl:0;briefrole=pass:0'
DL_LAB() { # DL_LAB <cell> -> what the cell establishes
  case "$1" in
    nodl) echo "a lead dispatch with no Deliverable line is refused by this deny and leaves no ledger row" ;;
    dl) echo "the same prompt plus a column-0 'Deliverable: x/y.md' is not refused by this deny and is recorded" ;;
    dlmid) echo "a column-0 Deliverable line after other prose is not refused (the grammar reads any line)" ;;
    indent) echo "an indented '  Deliverable: x/y.md' is still refused (the row writer reads column 0 only)" ;;
    bold) echo "'**Deliverable:** x/y.md' is still refused" ;;
    nopath) echo "a Deliverable line with no path-shaped token is still refused" ;;
    bgabsent) echo "a dispatch with no run_in_background key is refused (only an explicit false is foreground)" ;;
    agent) echo "a nested spawn (payload agent_id) is not judged, and is recorded" ;;
    fg) echo "run_in_background false is not judged" ;;
    nosnap) echo "no pipeline snapshot file: not judged" ;;
    noera) echo "the era sentence absent from the installed step file: not judged" ;;
    updcmd) echo "a transcript whose last marker is the /ai-dlc-update command: not judged" ;;
    updskill) echo "a transcript whose last marker is the ai-dlc-update Skill call: not judged" ;;
    updlead) echo "an update marker followed by a later /ai-dlc marker is refused (the LAST marker decides)" ;;
    leadtr) echo "a transcript whose last marker is /ai-dlc is refused" ;;
    role) echo "a role with no readable team-role file: not judged" ;;
    mark) echo "a brief whose one well-formed wait-for-deliverable.sh --mark line yields a mark_file: not this deny" ;;
    markbad) echo "the same mark line without its findings=<n> field yields no mark_file and is refused" ;;
    brief) echo "a prompt whose only Deliverable line is in the Brief: file under planning-artifacts is not refused and is recorded" ;;
    briefnodl) echo "a Brief: file with no Deliverable line is still refused" ;;
    briefmiss) echo "a Brief: path that does not exist is still refused" ;;
    briefesc) echo "a Brief: path that climbs out of planning-artifacts with .. (the target carries a Deliverable line) is still refused" ;;
    briefrole) echo "a team-roles line present only in the Brief: file derives NO role: the role-less lead dispatch stays unrecorded (no ledger row)" ;;
    seq) echo "the ledger row count is 1 after an allowed call, still 1 after a refused one, and 2 after the next allowed one" ;;
  esac
}
DL_TIP="$(for _c in ${ALL_DL//,/ }; do printf '%s=%s;' "$_c" "$(dl_cell "$HOOK" "$_c")"; done)"
_old_ifs="$IFS"; IFS=';'
for _c in $DL_WANT; do
  case ";$DL_TIP" in
    *";$_c;"*) ok "DELIVERABLE-LINE ${_c%%=*}: $(DL_LAB "${_c%%=*}") ('${_c#*=}')" ;;
    *) bad "DELIVERABLE-LINE ${_c%%=*}: expected '${_c#*=}' ($(DL_LAB "${_c%%=*}")), got vector '$DL_TIP'" ;;
  esac
done
IFS="$_old_ifs"

# ===== THE SHARD-DIR DENY (BL-976): an adversary brief naming a dir the merge refuses ========
# The guard selects every `planning-artifacts/s<N>/shards/<dir>` in an adversary brief and asks the
# MERGE (`merge-adversarial-shards.sh --check-shard-dir`), located by walking up from the guard. The
# real guard is driven in whichever layout this fixture runs in. A cell is
# "<decision>:<ledger rows added>:<reason>", reason `s` for the merge's series-stem refusal.
SD_MRG=""; for _c in "$REM_ROOT/core/scripts/merge-adversarial-shards.sh" "$REM_ROOT/scripts/ai-dlc/merge-adversarial-shards.sh"; do
  [ -f "$_c" ] && { SD_MRG="$_c"; break; }; done
[ -n "$SD_MRG" ] && echo "HERMETIC-CONSUMED $SD_MRG" || bad "SHARD-DIR FIXTURE BROKEN: merge-adversarial-shards.sh not found beside $HOOK"
SD_W="$(mkworld sdir 321)"
render_sd_role() { printf '# Role: %s\n\nDo the thing the role does.\n' "$1" > "$SD_W/.claude/team-roles/$1.md"; }
render_sd_role adversary
jq '.aiDlcRoles.adversary = {model: "opus", effort: "high"}' "$SD_W/.claude/settings.json" > "$SD_W/.claude/settings.json.n" \
  && mv "$SD_W/.claude/settings.json.n" "$SD_W/.claude/settings.json"
SD_PA=_bmad-output/planning-artifacts/s321/shards
sd_pay() { # sd_pay <role> <brief lines...>
  local r="$1" p; shift
  p="Your operating contract is \`.claude/team-roles/$r.md\`. Read it first."
  for _l in "$@"; do p="$p"$'\n'"$_l"; done
  jq -nc --arg p "$p"$'\n'"Do the work." '{tool_name:"Agent",tool_input:{name:"sdir",prompt:$p}}'
}
sd_run() { # sd_run <guard> <role> <brief lines...> -> "<decision>:<rows added>:<reason>"
  local g="$1" o d r rs n0 n1; shift
  n0="$(grep -c . "$SD_W/_bmad-output/spawn-ledger.jsonl")" || n0=0
  o="$(sd_pay "$@" | CLAUDE_PROJECT_DIR="$SD_W" dgrun "$g" 2>/dev/null)"
  n1="$(grep -c . "$SD_W/_bmad-output/spawn-ledger.jsonl")" || n1=0
  d="$(jq -r '.hookSpecificOutput.permissionDecision // "none"' <<<"$o" 2>/dev/null)"; [ -n "$d" ] || d=none
  r=-
  if [ "$d" = deny ]; then
    rs="$(jq -r '.hookSpecificOutput.permissionDecisionReason // empty' <<<"$o" 2>/dev/null)"
    case "$rs" in *"--check-shard-dir answered:"*"names the series, not the artifact"*) r=s ;; *) r=o ;; esac
  fi
  printf '%s:%s:%s' "$d" "$((n1 - n0))" "$r"
}
sd_cell() { # sd_cell <guard> <cell>
  case "$2" in
    sdbad)    sd_run "$1" adversary "Output (your shard): \`$SD_PA/architecture-adversarial-p1/6.md\`." ;;
    sdgood)   sd_run "$1" adversary "Output (your shard): \`$SD_PA/architecture-p1/6.md\`." ;;
    sdelic)   sd_run "$1" adversary "Output (your shard): \`$SD_PA/stories-elicitation/01.md\`." ;;
    sdreview) sd_run "$1" adversary "Output (your shard): \`docs/reviews/s321/shards/code-review-p1/1.md\`." ;;
    sdrem)    sd_run "$1" remediator "Read \`$SD_PA/architecture-adversarial-p1/6.md\` and repair." ;;
    sdmixed)  sd_run "$1" adversary "Read \`$SD_PA/coe-p1/1.md\`." "Output (your shard): \`$SD_PA/test-adversarial-p2/3.md\`." ;;
    sdtrail)  sd_run "$1" adversary "Write your shard under $SD_PA/architecture-adversarial-p1." ;;
    sdellip)  sd_run "$1" adversary "Shards live under $SD_PA/... as one file per seat; yours is \`$SD_PA/architecture-p1/6.md\`." ;;
  esac
}
ALL_SD=sdbad,sdgood,sdelic,sdreview,sdrem,sdmixed,sdtrail,sdellip
SD_WANT='sdbad=deny:0:s;sdgood=allow:1:-;sdelic=allow:1:-;sdreview=allow:1:-;sdrem=allow:1:-;sdmixed=deny:0:s;sdtrail=deny:0:s;sdellip=allow:1:-'
SD_TIP="$(for _c in ${ALL_SD//,/ }; do printf '%s=%s;' "$_c" "$(sd_cell "$HOOK" "$_c")"; done)"
_old_ifs="$IFS"; IFS=';'
for _c in $SD_WANT; do
  case ";$SD_TIP" in
    *";$_c;"*) ok "SHARD-DIR ${_c%%=*}: '${_c#*=}' (decision:rows added:reason)" ;;
    *) bad "SHARD-DIR ${_c%%=*}: expected '${_c#*=}', got vector '$SD_TIP'" ;;
  esac
done
IFS="$_old_ifs"
# FAIL OPEN: the guard copy in HOOKS_SHARED has no merge above it, so the refused brief
# is allowed and recorded -- a missing merge never blocks a spawn. Paired with sdbad above (deny).
SD_OPEN="$(sd_cell "$(mk_hooks_copy sd-open)" sdbad)"
[ "$SD_OPEN" = "allow:1:-" ] && ok "SHARD-DIR sdopen: no merge reachable -> '$SD_OPEN' (fail open; sdbad denies with one)" \
  || bad "SHARD-DIR sdopen: no merge reachable -> '$SD_OPEN', expected 'allow:1:-'"
# --- EQUIVALENCE: the guard run as a program answers what the in-process call answers -----------------------------
# One program start per distinct outcome: a correcting allow (updatedInput set), a deny, and no decision. Each compares
# stdout, stderr and exit with dgrun's, over the same world with the ledger reset before each run.
eqh() { # eqh <id> <project> <json> -> 0 when the program and the in-process call agree on stdout, stderr and exit
  local id="$1"
  rm -f "$LEDGER"
  printf '%s' "$3" | CLAUDE_PROJECT_DIR="$2" dgrun "$HOOK" > "$EQ/$id.ip.out" 2> "$EQ/$id.ip.err"; echo "$?" > "$EQ/$id.ip.rc"
  rm -f "$LEDGER"
  printf '%s' "$3" | CLAUDE_PROJECT_DIR="$2" FXCELL="$id" command bash "$HOOK" > "$EQ/$id.cl.out" 2> "$EQ/$id.cl.err"; echo "$?" > "$EQ/$id.cl.rc"
  rm -f "$LEDGER"
  cmp -s "$EQ/$id.ip.out" "$EQ/$id.cl.out" && cmp -s "$EQ/$id.ip.err" "$EQ/$id.cl.err" && cmp -s "$EQ/$id.ip.rc" "$EQ/$id.cl.rc"
}
EQ_SET="$(mkjson Agent gate-adjudicator)"
EQ_DENY="$(jq -nc '{tool_name:"Agent",tool_input:{name:"t-1",model:"sonnet",subagent_type:"remediator",prompt:"Do the work."}}')"
eqh cli-dg-set "$CONSUMER" "$EQ_SET"; _e1=$?
[ "$_e1" = 0 ] && [ "$(cat "$EQ/cli-dg-set.cl.rc")" = 0 ] && [ "$(jq -r '.hookSpecificOutput.updatedInput.model // empty' < "$EQ/cli-dg-set.cl.out")" = opus ] \
  && ok "  cli-dg-set: the program's stdout, stderr and exit equal the in-process call's, and it set the pinned tier" \
  || bad "  cli-dg-set: the program and the in-process call differ, or the program did not set the pinned tier"
eqh cli-dg-deny "$CONSUMER" "$EQ_DENY"; _e2=$?
[ "$_e2" = 0 ] && [ -s "$EQ/cli-dg-deny.cl.out" ] && [ "$(jq -r '.hookSpecificOutput.permissionDecision // empty' < "$EQ/cli-dg-deny.cl.out")" = deny ] \
  && ok "  cli-dg-deny: the program's stdout, stderr and exit equal the in-process call's, and both deny" \
  || bad "  cli-dg-deny: the program and the in-process call differ, or the program did not deny"
eqh cli-dg-quiet "$NOSTAMP" "$EQ_SET"; _e3=$?
[ "$_e3" = 0 ] && [ "$(cat "$EQ/cli-dg-quiet.cl.rc")" = 0 ] && [ ! -s "$EQ/cli-dg-quiet.cl.out" ] && [ "$(cat "$EQ/cli-dg-set.ip.rc")" = 0 ] \
  && ok "  cli-dg-quiet: the program's stdout, stderr and exit equal the in-process call's, and neither decides" \
  || bad "  cli-dg-quiet: the program and the in-process call differ, or one of them decided"
echo
report_end dispatch-model-guard
