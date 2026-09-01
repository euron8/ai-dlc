#!/usr/bin/env bash
# check-22-spawn-ledger — Check 22's mechanical arms, and the proof they can fail.
#
# WHAT THIS EXISTS TO CATCH. gate-validation.md Check 22 published three field comparisons
# per spawn-ledger row — `model_bound` against `aiDlcRoles.<role>.model`,
# `role_contract_cited` true, `role_file_readable` not false — and its enforcement-map row
# carried `enforcer: []`, so a teammate performed all three by reading a paragraph at every
# implementation-phase gate. `validate-spawn-ledger.sh` is now their single home. The
# comparison itself was never new: `ai-dlc-dispatch-guard.sh` already made it at PreToolUse
# (it is where `model_bound` gets its value) in a copy no gate could reach, so `pin_key()`
# and `matches_pin()` are shared byte-identically and I56 binds them —
# `enforcement-map-sites` assertion 31 proves that binding fires; this file proves the
# validator does.
#
# EVERY ARM IS ASSERTED ON ITS OWN WORDING AND HAS ITS OWN SCENARIO FILE. Four of the arms
# below exit 1 and would all match a grep for "FAIL"; a mutant that collapses two of them
# into one is exactly what the per-arm battery catches. Reusing one scenario across arms is
# the recorded trap from v0.210.0, where a single off-by-one mutant failed three assertions
# at once and two of the three were therefore vacuous.
#
# PRE-LEDGER IS ITS OWN EXIT CODE and gets its own arm. "No violation found" and "no row was
# ever examined" are different facts, and a reader that cannot tell them apart passes
# vacuously on exactly the sprint where the mechanism was missing.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"

# Both layouts, never by hop count (I33): core/scripts upstream, scripts/ai-dlc in a consumer.
if   [ -n "$ROOT" ] && [ -f "$ROOT/core/scripts/validate-spawn-ledger.sh" ]; then
  VSL="$ROOT/core/scripts/validate-spawn-ledger.sh"
elif [ -n "$ROOT" ] && [ -f "$ROOT/scripts/ai-dlc/validate-spawn-ledger.sh" ]; then
  VSL="$ROOT/scripts/ai-dlc/validate-spawn-ledger.sh"
else
  echo "FIXTURE ERROR: validate-spawn-ledger.sh not found in either layout" >&2
  exit 2
fi
command -v jq >/dev/null 2>&1 || { echo "FIXTURE ERROR: jq not on PATH" >&2; exit 2; }
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

WORK="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd)"
trap 'rm -rf "$WORK"' EXIT

fails=0
asserted=0
ok()  { printf '  ok    %s\n' "$1"; asserted=$((asserted+1)); }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); asserted=$((asserted+1)); }

echo "check-22-spawn-ledger:"

# --- the consumer config every arm resolves its pin against --------------------
# `dev` pins the key `sonnet`, `protected-path-editor` pins `opus`, and `tea` is a party
# persona with an effort and NO model — a legitimate no-pin role, not a finding.
cat > "$WORK/settings.json" <<'JSON'
{
  "aiDlcModels": { "opus": "claude-opus-5[1m]", "sonnet": "claude-sonnet-5" },
  "aiDlcRoles": {
    "dev": { "model": "sonnet", "effort": "high" },
    "protected-path-editor": { "model": "opus" },
    "adversary": { "model": "opus" },
    "tea": { "effort": "medium" }
  }
}
JSON
chmod 000 "$WORK/unreadable.json" 2>/dev/null || :
printf '{}\n' > "$WORK/unreadable.json"
chmod 000 "$WORK/unreadable.json"

# A READABLE settings.json that has simply lost its role block — the key renamed, or the block
# dropped in a merge. `pin_key` returns empty for every role, so Rule 19(a) is compared zero
# times, and the readability refusal above cannot see this because the file reads fine.
cat > "$WORK/norolepins.json" <<'JSON'
{
  "aiDlcModels": { "opus": "claude-opus-5[1m]", "sonnet": "claude-sonnet-5" },
  "aiDlcRolesXX": { "dev": { "model": "sonnet", "effort": "high" } }
}
JSON

row() { # role bound requested cited readable name
  jq -nc --arg r "$1" --arg b "$2" --arg q "$3" --argjson c "$4" --argjson k "$5" --arg n "$6" \
    '{v:1, sprint:900, name:$n, role:$r,
      model_bound:$b,
      model_requested:(if $q == "" then null else $q end),
      role_contract_cited:$c, role_file_readable:$k}'
}

# ONE SCENARIO FILE PER ARM. Every field is populated except where the arm's own subject is
# an absent one, so a mutant to the field mapping moves the F arm and nothing else.
row dev sonnet sonnet true true dev-clean                          > "$WORK/clean.jsonl"
row tea inherit inherit true true tea-party                       >> "$WORK/clean.jsonl"
row dev sonnet sonnet true false dev-norolefile                    > "$WORK/unreadable.jsonl"
row dev sonnet sonnet false true dev-nocite                        > "$WORK/uncited.jsonl"
row dev opus opus true true dev-wrongtier                          > "$WORK/mismatch.jsonl"
row protected-path-editor 'claude-opus-5[1m]' 'claude-opus-5[1m]' true true ppe-fullstring > "$WORK/tolerance.jsonl"
row dev sonnet opus true true dev-corrected                        > "$WORK/corrected.jsonl"
row dev sonnet '' true true dev-norequest                          > "$WORK/nullfield.jsonl"
jq -nc '{v:1,sprint:899,name:"dev-lastsprint",role:"dev",model_bound:"sonnet",model_requested:"sonnet",role_contract_cited:true,role_file_readable:true}' \
                                                                   > "$WORK/othersprint.jsonl"
# A crashed or concurrent append: a full row, then a truncated one. `jq -s` fails on the
# whole file, and reporting zero rows for it would route to PRE-LEDGER — "the guard was not
# installed yet" — for a file that is full of rows.
{ row dev sonnet sonnet true true dev-ok; printf '{"v":1,"sprint":900,"name":"dev-tr\n'; } > "$WORK/corrupt.jsonl"

# --- Rule 19 SCOPE. The dispatch guard derives `role` from `subagent_type` when the prompt
# cited no role file, and that accepts any lowercase agent type — so the harness's own
# built-in types land here carrying no contract and no role file, which are two violations
# each for a dispatch Rule 19 does not bind. The offender sits BESIDE a clean in-scope row
# in the SAME run: a near-miss in a separate run can only ask whether the filter fires at
# all, never whether it fires on the right rows.
row general-purpose inherit '' false false gp-utility                 > "$WORK/outscope.jsonl"
row dev sonnet sonnet true true dev-beside-gp                        >> "$WORK/outscope.jsonl"
# The disjunct that keeps the filter from being a disarm: this dispatch CITED a role
# contract, so it is judged whatever settings.json declares — and it is the input that keeps
# the fail-closed role_file_readable arm reachable for an undeclared role.
# Every field populated: a null `model_requested` here would entangle this arm with the
# sentinel mutant, and the assertion is on the row being EXAMINED rather than on any
# violation, so it does not ride on the fail-closed arm either.
row general-purpose sonnet sonnet true true gp-cited                  > "$WORK/outscope-cited.jsonl"
# A DECLARED role outside Check 22's five gate-trigger roles. Narrowing the script to those
# five acquits this row; measured on the reference consumer, that narrowing dropped 23 of
# the 25 true findings. Its violation is a TIER MISMATCH, not a missing citation: asserted
# on the citation arm this row would move with the `cited` mutant and one of the two
# assertions would be vacuous.
row adversary sonnet sonnet true true adv-wrongtier                   > "$WORK/declared-nonfive.jsonl"
# Every in-sprint row out of scope. Nothing was compared, so this must not read as a pass.
row general-purpose inherit '' false false gp-only                    > "$WORK/allout.jsonl"
# THE SHAPE THE SCOPE FILTER CANNOT SEE BY ROLE. A real team role dispatched through the
# harness's generic agent type records `role: general-purpose`, so the role field carries the
# agent type and the violation at once. 18 of the 49 rows the filter skips on the reference
# consumer are this. The dispatch NAME is the only surviving signal.
row general-purpose inherit '' false false dev-story-1                > "$WORK/suspect.jsonl"
row dev sonnet sonnet true true dev-beside-suspect                   >> "$WORK/suspect.jsonl"
# Two skipped rows of the SAME role, so the COUNTS list has to de-duplicate more than its
# first element.
row general-purpose inherit '' false false gp-1                       > "$WORK/dupes.jsonl"
row fork inherit '' false false fk-1                                 >> "$WORK/dupes.jsonl"
row general-purpose inherit '' false false gp-2                      >> "$WORK/dupes.jsonl"
row dev sonnet sonnet true true dev-beside-dupes                     >> "$WORK/dupes.jsonl"

# battery <script> -> ten space-separated tokens, one per arm. A mutant must move EXACTLY one.
battery() {
  local S="$1" out rc t=""
  run() { out="$( bash "$S" --ledger "$WORK/$1" --sprint 900 --settings "$WORK/${2:-settings.json}" 2>&1 )"; rc=$?; }

  run clean.jsonl
  if [ "$rc" -eq 0 ] && grep -q 'OK: all 2 S900 spawn row' <<<"$out"; then t="C:ok"; else t="C:$rc"; fi

  run unreadable.jsonl
  if [ "$rc" -eq 1 ] && grep -q 'role_file_readable=false' <<<"$out"; then t="$t R:named"; else t="$t R:$rc"; fi

  run uncited.jsonl
  if [ "$rc" -eq 1 ] && grep -q 'role_contract_cited=false' <<<"$out"; then t="$t B:named"; else t="$t B:$rc"; fi

  run mismatch.jsonl
  if [ "$rc" -eq 1 ] && grep -q 'Rule 19(a) tier' <<<"$out"; then t="$t M:named"; else t="$t M:$rc"; fi

  run tolerance.jsonl
  if [ "$rc" -eq 0 ]; then t="$t T:ok"; else t="$t T:$rc"; fi

  run othersprint.jsonl
  if [ "$rc" -eq 3 ] && grep -q 'PRE-LEDGER' <<<"$out"; then t="$t P:preledger"; else t="$t P:$rc"; fi

  run corrected.jsonl
  if [ "$rc" -eq 0 ] && grep -q '^NOTE: \[dev-corrected\]' <<<"$out"; then t="$t N:noted"; else t="$t N:$rc"; fi

  run nullfield.jsonl
  if [ "$rc" -eq 0 ] && ! grep -q '^NOTE:' <<<"$out"; then t="$t F:aligned"; else t="$t F:misread"; fi

  run clean.jsonl unreadable.json
  if [ "$rc" -eq 2 ]; then t="$t S:refused"; else t="$t S:$rc"; fi

  run corrupt.jsonl
  if [ "$rc" -eq 2 ] && grep -q 'not parseable as JSONL' <<<"$out"; then t="$t J:refused"; else t="$t J:$rc"; fi

  bash "$S" --ledger "$WORK/clean.jsonl" --sprint 900 >/dev/null 2>&1; rc=$?
  if [ "$rc" -eq 2 ]; then t="$t A:usage"; else t="$t A:$rc"; fi

  # A ledger of genuinely mismatched rows, against a readable settings.json whose role block
  # has been renamed away. Every row resolves, cites its contract, and pins nothing, so 19(a)
  # runs zero comparisons — and the verdict must say that rather than claim the pin matched.
  run mismatch.jsonl norolepins.json
  if [ "$rc" -eq 0 ] && grep -q '^OK WITH NO PIN COMPARED:' <<<"$out"; then t="$t U:nopin"; else t="$t U:$rc"; fi

  # An out-of-scope row BESIDE an in-scope one: the built-in agent type is skipped and NAMED,
  # and the dev row beside it is still examined. Both halves, one run.
  run outscope.jsonl
  if [ "$rc" -eq 0 ] && grep -q '1 row(s) out of Rule 19 scope (roles: general-purpose)' <<<"$out" \
     && grep -q 'examined 1 S900 spawn row' <<<"$out" && ! grep -q '^FAIL: \[' <<<"$out"
  then t="$t X:skipped"; else t="$t X:$rc"; fi

  # Same undeclared role, but it CITED a contract: EXAMINED, not skipped.
  run outscope-cited.jsonl
  if [ "$rc" -eq 0 ] && grep -q 'examined 1 S900 spawn row' <<<"$out" \
     && grep -q '0 row(s) out of Rule 19 scope' <<<"$out"; then t="$t Y:judged"; else t="$t Y:$rc"; fi

  # A declared role outside the five gate-trigger roles is judged, not acquitted.
  run declared-nonfive.jsonl
  if [ "$rc" -eq 1 ] && grep -q 'Rule 19(a) tier' <<<"$out" \
     && grep -q "role 'adversary'" <<<"$out"; then t="$t D:judged"; else t="$t D:$rc"; fi

  printf '%s' "$t"
}

EXPECTED="C:ok R:named B:named M:named T:ok P:preledger N:noted F:aligned S:refused J:refused A:usage U:nopin X:skipped Y:judged D:judged"

# --- 1. the shipping validator answers every arm ------------------------------
GOT="$(battery "$VSL")"
if [ "$GOT" = "$EXPECTED" ]; then
  ok "all fifteen arms: clean, unreadable role file, missing 19(b) citation, tier mismatch, the containment tolerance, PRE-LEDGER, a guard-corrected request, a null field, an unreadable settings.json, an unparseable ledger, a fumbled invocation, a readable settings.json that pins no role at all, an out-of-scope built-in agent type beside an in-scope row, that same type when it CITED a contract, and a declared role outside the five gate-trigger roles"
else
  bad "battery: expected [$EXPECTED], got [$GOT]"
fi

# --- 1b. THE OK SENTENCE MAY ONLY CLAIM WHAT WAS TESTED -----------------------
# Rule 19(a) is compared only where the role pins a model, and the unpinned rows were already
# counted — the count was here, its comment already named the hazard, and NOTHING READ IT. So
# the closing sentence went on asserting "a model matching their role's configured pin" over a
# run in which the pin was never fetched. The two arms below are the same ledger under two
# readable configs, and they must not produce the same claim.
out="$(bash "$VSL" --ledger "$WORK/mismatch.jsonl" --sprint 900 --settings "$WORK/norolepins.json" 2>&1)"
if grep -q 'Rule 19(a) was NOT tested on any row' <<<"$out" \
   && grep -q 'the comparison ran zero times' <<<"$out" \
   && ! grep -q 'a model matching their role' <<<"$out"; then
  ok "a settings.json with its role block renamed away clears every row and SAYS the pin was never compared — it does not borrow the verified sentence"
else
  bad "the no-pin run reused the verified OK wording — got: $out"
fi

out="$(bash "$VSL" --ledger "$WORK/clean.jsonl" --sprint 900 --settings "$WORK/settings.json" 2>&1)"
if grep -q 'a model matching their role' <<<"$out" \
   && grep -q '1 row(s) pin no model and were not compared' <<<"$out"; then
  ok "and the genuinely-verified sentence still carries its own exception — 1 of the 2 clean rows pinned nothing, and the OK line names that rather than folding it into the claim"
else
  bad "the verified OK sentence did not qualify its uncompared rows — got: $out"
fi

# --- 2. an absent ledger is PRE-LEDGER, not a clean pass ----------------------
# The file-absent and every-row-is-another-sprint's cases are ONE case, and this is the half
# the battery does not cover.
out="$(bash "$VSL" --ledger "$WORK/no-such-file.jsonl" --sprint 900 --settings "$WORK/settings.json" 2>&1)"; rc=$?
if [ "$rc" -eq 3 ] && grep -q 'PRE-LEDGER: 0 row' <<<"$out"; then
  ok "an ABSENT ledger is PRE-LEDGER (exit 3) and says it read zero rows — never a clean pass"
else
  bad "an absent ledger reported rc=$rc: ${out%%$'\n'*}"
fi

# --- 3. it reports what it compared, on every path ----------------------------
# A verdict that does not say what it examined cannot be told apart from one that examined
# nothing — which is the whole reason this check has an enforcer.
out="$(bash "$VSL" --ledger "$WORK/clean.jsonl" --sprint 900 --settings "$WORK/settings.json" 2>&1)"
if grep -q 'COUNTS: examined 2 S900 spawn row(s) of 2' <<<"$out" \
   && grep -q '1 row(s) whose role pins no model' <<<"$out"; then
  ok "COUNTS names the rows examined, the rows in the file, and the rows whose role pins nothing (a party persona is a normal state, and a counted one)"
else
  bad "the clean run did not report its counts — got: $out"
fi

out="$(bash "$VSL" --ledger "$WORK/mismatch.jsonl" --sprint 900 --settings "$WORK/settings.json" 2>&1)"
if grep -q 'COUNTS: examined 1 S900 spawn row' <<<"$out" && grep -q '1 tier mismatch' <<<"$out"; then
  ok "the FAILING run reports its counts too (a gate log entry can cite them either way)"
else
  bad "the failing run printed no counts line — got: $out"
fi

# --- 4. the pin is the CONFIG's, read at gate time ----------------------------
# The ledger carries `tier_pinned` — the guard's own answer — and reading it would make this
# check a self-report by the mechanism it audits, and blind to a settings.json that changed
# after the dispatch. Same row, two configs, two verdicts.
cat > "$WORK/repinned.json" <<'JSON'
{ "aiDlcModels": { "opus": "claude-opus-5[1m]", "sonnet": "claude-sonnet-5" },
  "aiDlcRoles": { "dev": { "model": "opus" } } }
JSON
bash "$VSL" --ledger "$WORK/clean.jsonl" --sprint 900 --settings "$WORK/settings.json" >/dev/null 2>&1; a=$?
bash "$VSL" --ledger "$WORK/clean.jsonl" --sprint 900 --settings "$WORK/repinned.json" >/dev/null 2>&1; b=$?
if [ "$a" -eq 0 ] && [ "$b" -eq 1 ]; then
  ok "the verdict follows settings.json, not the ledger's own tier_pinned — repinning dev to opus turns the same clean row into a mismatch"
else
  bad "the same ledger gave rc=$a and rc=$b across two different pins; expected 0 then 1 (the check is reading the guard's answer back, not the config)"
fi

# --- 5. every in-sprint row out of scope is NOT a pass ------------------------
# The filter's own failure mode: a settings.json that lost its `aiDlcRoles` block, on a
# sprint whose dispatches cited nothing, would drop every row and exit 0 having compared
# nothing. Kept OUT of the battery deliberately — a mutant that disables the skip moves this
# arm and the X arm together, and two moved tokens make one of them vacuous.
out="$(bash "$VSL" --ledger "$WORK/allout.jsonl" --sprint 900 --settings "$WORK/settings.json" 2>&1)"; rc=$?
if [ "$rc" -eq 3 ] && grep -q 'NO ROLE-BOUND ROWS' <<<"$out" && grep -q 'general-purpose' <<<"$out"; then
  ok "a sprint whose every row is out of scope exits 3 and NAMES the roles it skipped — not a pass, and the one way the filter could hide a real role is visible in the message"
else
  bad "an all-out-of-scope ledger reported rc=$rc: ${out%%$'\n'*}"
fi

# And prove that arm can fail, on its own copy: without it the same input exits 0.
sed 's/^if \[ "\$CHECKED" -eq 0 \]; then$/if false; then/' "$VSL" > "$WORK/nzs.sh"
if cmp -s "$VSL" "$WORK/nzs.sh"; then
  bad "FIXTURE BROKEN: the all-out-of-scope guard's line was renamed, so this mutant proves nothing"
else
  bash "$WORK/nzs.sh" --ledger "$WORK/allout.jsonl" --sprint 900 --settings "$WORK/settings.json" >/dev/null 2>&1; rc=$?
  if [ "$rc" -eq 0 ]; then
    ok "MUTANT norolebound: dropping that guard turns the same all-out-of-scope ledger into a silent exit 0 — the arm above is load-bearing"
  else
    bad "MUTANT norolebound survived: rc=$rc without the guard, so the arm above cannot be what produced the 3"
  fi
fi

# ============================================================================
# MUTANTS. Each is a COPY guarded by `cmp -s`, all in one directory beside an UNMUTATED
# CONTROL copied from the same place. The control earns its keep here: a lone copy that
# cannot start emits nothing, and "no output" otherwise scores as a kill for every mutant
# at once.
#
# Each mutant must move EXACTLY ONE token of the battery. Two moved tokens mean the
# assertions are entangled and one of them is vacuous.
# ============================================================================
mkdir -p "$WORK/mut"
cp "$VSL" "$WORK/mut/control.sh"

CTL="$(battery "$WORK/mut/control.sh")"
if [ "$CTL" = "$EXPECTED" ]; then
  ok "CONTROL: an unmutated copy in the mutant directory answers every arm (so a mutant's silence is the mutation, not the copy)"
else
  bad "CONTROL copy did not reproduce the shipping battery: expected [$EXPECTED], got [$CTL]"
fi

# moved <expected-token-position-name> <mutant-battery> -> prints the differing arm names
moved() {
  local got="$1" i=1 e m out=""
  for e in $EXPECTED; do
    m="$(printf '%s' "$got" | cut -d' ' -f$i)"
    [ "$e" != "$m" ] && out="$out ${e%%:*}"
    i=$((i+1))
  done
  printf '%s' "${out# }"
}

mutant() { # name sed-expression expected-arm description
  local n="$1" expr="$2" arm="$3" desc="$4" M="$WORK/mut/$1.sh" got mv
  sed "$expr" "$WORK/mut/control.sh" > "$M" || { bad "FIXTURE BROKEN: could not write mutant $n"; return; }
  if cmp -s "$WORK/mut/control.sh" "$M"; then
    bad "FIXTURE BROKEN: mutation '$n' matched nothing — the line it targets was renamed, so this mutant proves nothing"
    return
  fi
  got="$(battery "$M")"
  mv="$(moved "$got")"
  if [ "$mv" = "$arm" ]; then
    ok "MUTANT $n: $desc — and it moves ONLY the $arm arm"
  elif [ -z "$mv" ]; then
    bad "MUTANT $n survived: $desc left every arm unchanged, so that arm cannot fire"
  else
    bad "MUTANT $n moved [$mv], expected only [$arm] — entangled assertions, at least one of them vacuous"
  fi
}

# 1. the fail-closed role-file arm.
mutant readable 's/if \[ "\$readable" = "false" \]; then/if false; then/' R \
  "removing the role_file_readable arm lets a teammate that ran with no resolvable contract pass"

# 2. the Rule 19(b) citation arm.
mutant cited 's/if \[ "\$cited" != "true" \]; then/if false; then/' B \
  "removing the role_contract_cited arm lets a subagent_type-only dispatch pass"

# 3. the match tolerance. `matches_pin` is the guard's function verbatim; narrowing it here
#    is what I56 binds against, and this is the behavioural half of that binding.
mutant tolerance 's@^    \*"\$EXPECT"\*) return 0 ;;@    *"$EXPECT"*) return 1 ;;@' T \
  "narrowing matches_pin to exact equality reports a mismatch on a spawn the guard bound from a full model string"

# 4. PRE-LEDGER collapsing into a pass — the defect this check was rewritten to stop.
mutant preledger 's/^  exit 3$/  exit 0/' P \
  "returning 0 instead of 3 makes an out-of-sprint ledger indistinguishable from a clean one"

# 5. the unreadable-settings guard. Without it pin_key returns empty for every role — the
#    guard's deliberate fail-open — and every spawn clears the model arm having compared
#    nothing.
#    `|| true ||` and not `|| false ||`: `||` short-circuits on SUCCESS, so the `false`
#    spelling leaves the block reachable on exactly the input that reaches it today and is a
#    byte-different no-op — which `cmp -s` passes. Both were tried; only the assertion told
#    them apart, which is why `cmp -s` proves a mutation happened and never that it mutated
#    the thing under test.
mutant settings 's/^\[ -r "\$SETTINGS" \] || {$/[ -r "\$SETTINGS" ] || true || {/' S \
  "dropping the settings-readability refusal clears the model arm on every row without a comparison"

# 6. the field sentinel. TAB is IFS whitespace, so an empty field collapses and every later
#    field shifts one place left. Measured on this script's first draft.
#
#    The NULL branch, not the empty-string branch. `model_requested` is JSON null here, so
#    mutating `if . == "" then "__NONE__"` changes bytes and nothing else — the second
#    byte-different no-op this mutant set produced before the arms separated them.
mutant sentinel 's/if \. == null then "__NONE__"/if . == null then ""/' F \
  "emptying the null-field sentinel shifts every field after an absent one and the loop compares the wrong strings"

# 7. the unparseable-ledger refusal. Swallowing jq's failure reports zero rows for a file
#    full of them, and zero rows routes to PRE-LEDGER — a different fact with a different
#    remedy.
#
#    `|| echo 0` INSIDE the substitution, so it succeeds and the refusal block below it
#    becomes unreachable — the exact spelling this script carried before the arm existed.
#    Putting the mutation on the `||` itself instead makes the block run on EVERY input and
#    moves eight arms, which is a broken mutant reading as a strong kill.
mutant corrupt 's@"\$LEDGER" 2>/dev/null)" || {@"$LEDGER" 2>/dev/null || echo 0)" || {@' J \
  "swallowing a parse failure reports a truncated ledger as zero rows, which reads as a sprint that predates the guard"

# 8. the untested-pin verdict. Removing it is not a byte-different no-op: the run falls through
#    to the plain OK sentence, which is the exact claim the run cannot support. It moves only
#    the U arm — the clean arm still has a pinned row, so its sentence is still earned.
mutant nopincompared 's/^if \[ "\$CHECKED" -gt 0 \] && \[ "\$UNPINNED" -eq "\$CHECKED" \]; then$/if false; then/' U \
  "dropping the untested-pin verdict lets a settings.json that lost its role block clear a mismatched ledger under the sentence that says the pin matched"

# 9. the Rule 19 scope filter. Without it every built-in agent type the dispatch guard
#    recorded from `subagent_type` is judged against a contract it never had — 97 of the 111
#    role-arm violations on the reference consumer's ledger were exactly that.
#    Targets the `continue` in the out-of-scope branch, not the scope test above it:
#    mutating the test makes every row out of scope and moves four arms at once.
mutant scopefilter 's/^    continue$/    :/' X \
  "dropping the scope skip judges a built-in agent type against Rule 19 and fails a gate on correct data"

# 10. the disjunct that keeps the filter from being a disarm is asserted BELOW rather than
#     here: it is what keeps a contract-citing row in scope when settings.json declares
#     nothing, which is also exactly what the U arm rests on, so a battery mutant moves both
#     tokens by construction and one of the two would be vacuous.

# --- 6. the skipped row the ROLE field cannot describe ------------------------
# The scope filter's join key is the field the violation corrupts: a lead that dispatches a
# real team role through `subagent_type: general-purpose` with no contract citation produces a
# row whose role reads `general-purpose`, and naming the ROLE in COUNTS surfaces nothing.
# Kept out of the battery: the NOTE lives inside the skip branch, so the scopefilter mutant
# moves this arm and the X arm together.
out="$(bash "$VSL" --ledger "$WORK/suspect.jsonl" --sprint 900 --settings "$WORK/settings.json" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && grep -q "^NOTE: \[dev-story-1\]" <<<"$out" \
   && grep -q "declared role 'dev'" <<<"$out" \
   && grep -q '1 of them named after a declared role' <<<"$out" \
   && ! grep -q '^FAIL: \[' <<<"$out"; then
  ok "a skipped row whose dispatch NAME is a declared role is NOTED by name and counted — the one signal left when the role field carries the agent type — and it is a NOTE, not a FAIL, because a consumer utility named dev-* would be a false FAIL on correct data"
else
  bad "the suspect row was not surfaced (rc=$rc): $out"
fi

sed 's/^    _nr="\$(name_role "\${name}")"$/    _nr=""/' "$VSL" > "$WORK/nosus.sh"
if cmp -s "$VSL" "$WORK/nosus.sh"; then
  bad "FIXTURE BROKEN: the name_role call site was renamed, so this mutant proves nothing"
else
  out="$(bash "$WORK/nosus.sh" --ledger "$WORK/suspect.jsonl" --sprint 900 --settings "$WORK/settings.json" 2>&1)"
  if ! grep -q '^NOTE: \[dev-story-1\]' <<<"$out"; then
    ok "MUTANT suspectnote: without the name reading, a misrouted role dispatch is skipped in total silence — 18 of them on the reference consumer"
  else
    bad "MUTANT suspectnote survived: the NOTE still printed without name_role"
  fi
fi

# --- 7. the COUNTS role list de-duplicates past its first element -------------
# Spelled as a SPACE-separated accumulator against a NEWLINE-delimited membership test, the
# de-duplication matched only the whole string: the first role de-duplicated and every later
# one repeated. Measured on the reference consumer before the repair:
# `(roles: general-purpose fork general-purpose fork)` for two distinct roles.
out="$(bash "$VSL" --ledger "$WORK/dupes.jsonl" --sprint 900 --settings "$WORK/settings.json" 2>&1)"
if grep -q '3 row(s) out of Rule 19 scope (roles: general-purpose fork),' <<<"$out"; then
  ok "three skipped rows over two distinct roles name each role ONCE — the accumulator and its membership test use the same delimiter"
else
  bad "the COUNTS role list did not de-duplicate: $(grep 'out of Rule 19 scope' <<<"$out")"
fi

sed 's/^      \*) OUTSCOPE_ROLES="\${OUTSCOPE_ROLES}\${role:-<none>}\${NL}" ;;$/      *) OUTSCOPE_ROLES="${OUTSCOPE_ROLES}${OUTSCOPE_ROLES:+ }${role:-<none>}" ;;/' "$VSL" > "$WORK/nodedup.sh"
if cmp -s "$VSL" "$WORK/nodedup.sh"; then
  bad "FIXTURE BROKEN: the accumulator line was renamed, so this mutant proves nothing"
else
  out="$(bash "$WORK/nodedup.sh" --ledger "$WORK/dupes.jsonl" --sprint 900 --settings "$WORK/settings.json" 2>&1)"
  if grep -q 'general-purpose fork general-purpose' <<<"$out"; then
    ok "MUTANT dedup: the space-separated accumulator against a newline-delimited test repeats every role after the first"
  else
    bad "MUTANT dedup survived: the list still de-duplicated with the delimiters mismatched"
  fi
fi

# --- the cited disjunct, on its own copy --------------------------------------
# A dispatch that CITED `team-roles/<role>.md` is judged whether or not settings.json still
# declares that role. Without it, deleting one `aiDlcRoles` entry silences every finding
# against that role — a one-line disarm — and the fail-closed role_file_readable arm loses
# its reachable input for any role the settings file does not name.
sed 's/^  \[ "$2" = "true" \] && return 0$/  [ "$2" = "NEVER" ] \&\& return 0/' "$VSL" > "$WORK/nodisj.sh"
if cmp -s "$VSL" "$WORK/nodisj.sh"; then
  bad "FIXTURE BROKEN: the cited disjunct's line was renamed, so this mutant proves nothing"
else
  bash "$VSL"          --ledger "$WORK/mismatch.jsonl" --sprint 900 --settings "$WORK/norolepins.json" >/dev/null 2>&1; a=$?
  bash "$WORK/nodisj.sh" --ledger "$WORK/mismatch.jsonl" --sprint 900 --settings "$WORK/norolepins.json" >/dev/null 2>&1; b=$?
  if [ "$a" -eq 0 ] && [ "$b" -eq 3 ]; then
    ok "MUTANT citeddisjunct: without it a settings.json that lost its role block drops every contract-citing row as out of scope (3) instead of examining them (0) — the disjunct is what stops an aiDlcRoles deletion disarming the check"
  else
    bad "MUTANT citeddisjunct: shipping gave rc=$a and the mutant rc=$b; expected 0 then 3"
  fi
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "check-22-spawn-ledger: PASS ($asserted assertions)"
  exit 0
fi
echo "check-22-spawn-ledger: $fails of $asserted assertion(s) FAILED" >&2
exit 1
