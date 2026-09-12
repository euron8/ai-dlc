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
# `model_requested` populated on purpose: with a null field here this arm rides on the
# sentinel mutant, which shifts every later column — including the schema marker, so the
# skipped row reads as one the guard did not write and the arm moves for the wrong reason.
row general-purpose inherit inherit false false gp-utility            > "$WORK/outscope.jsonl"
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
# the 25 true findings.
#
# **UNCITED ON PURPOSE, and an earlier revision of this row was NOT.** Spelled `cited=true`
# it reached the loop through the CITED disjunct, so it asserted nothing about the
# declaration it exists to test — disabling the declared-role disjunct entirely left this
# arm unmoved. Uncited, the DECLARATION is the only thing keeping it in scope. Its asserted
# violation stays the TIER MISMATCH rather than the missing citation, so the `cited` mutant
# does not move it and the two arms stay independent.
row adversary sonnet sonnet false true adv-wrongtier                  > "$WORK/declared-nonfive.jsonl"
# Every in-sprint row out of scope. Nothing was compared, so this must not read as a pass.
row general-purpose inherit '' false false gp-only                    > "$WORK/allout.jsonl"
# THE SHAPE THE SCOPE FILTER CANNOT SEE BY ROLE. A real team role dispatched through the
# harness's generic agent type records `role: general-purpose`, so the role field carries the
# agent type and the violation at once. 18 of the 49 rows the filter skips on the reference
# consumer are this. The dispatch NAME is the only surviving signal.
row general-purpose inherit '' false false dev-story-1                > "$WORK/suspect.jsonl"
row dev sonnet sonnet true true dev-beside-suspect                   >> "$WORK/suspect.jsonl"
# THE NEAR-MISS SITS BESIDE THE OFFENDER, IN THE SAME RUN. `devops-audit` shares a prefix with
# the declared role `dev` and is not it; the match needs the role to be the whole name or to be
# followed by a dash. A second clean run could only ask whether the NOTE fires at all, never
# whether it fires on the right names.
row general-purpose inherit '' false false devops-audit             >> "$WORK/suspect.jsonl"
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
     && grep -q 'examined 1 S900 spawn row' <<<"$out" \
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
   && ! grep -q "^NOTE: \[devops-audit\]" <<<"$out" \
   && grep -q '1 of them named after a declared role' <<<"$out" \
   && ! grep -q '^FAIL: \[' <<<"$out"; then
  ok "a skipped row whose dispatch NAME is a declared role is NOTED by name and counted, while devops-audit BESIDE it stays quiet — the one signal left when the role field carries the agent type, and a NOTE rather than a FAIL because a utility named dev-* is a live false-positive path"
else
  bad "the suspect row was not surfaced (rc=$rc): $out"
fi

# And the BOUNDARY is load-bearing, not decoration: widened to a bare prefix, the near-miss
# beside the offender is flagged too, and the arm above would be reporting on a substring.
sed 's|      "\$nr_k"\|"\$nr_k"-\*) |      "$nr_k"*) |' "$VSL" > "$WORK/widen.sh"
if cmp -s "$VSL" "$WORK/widen.sh"; then
  bad "FIXTURE BROKEN: the name_role boundary pattern was renamed, so this mutant proves nothing"
else
  out="$(bash "$WORK/widen.sh" --ledger "$WORK/suspect.jsonl" --sprint 900 --settings "$WORK/settings.json" 2>&1)"
  if grep -q '^NOTE: \[devops-audit\]' <<<"$out"; then
    ok "MUTANT nameboundary: dropping the dash boundary flags devops-audit as the role dev — the boundary is what makes the NOTE a name match rather than a substring match"
  else
    bad "MUTANT nameboundary survived: devops-audit stayed quiet without the boundary"
  fi
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

# --- 8. an empty role is not a declared one -----------------------------------
# `DECLARED_NL` is two newlines when the settings file declares nothing, and that is exactly
# the pattern an empty role builds — so a role-less row matched the declared-membership test
# and was JUDGED, and its scope depended on whether the file declared any role at all. The
# guard never writes a null role, but the ledger has more than one writer.
row '' inherit '' false true norole                                   > "$WORK/norole.jsonl"

# A ROW THE GUARD DID NOT WRITE. `--ledger` is an append-only file any session can write to,
# and the single-writer premise was a convention rather than a guarantee: this is the
# hand-written provenance schema found on the reference consumer, where 14 such rows produced
# 24 of the 25 violations the check reported. Its absent fields are not observations — the
# missing `role_contract_cited` reads as false and the missing `model_bound` compares as the
# empty string against a real pin — so judging it manufactures two findings from nothing.
# It names a DECLARED role and sits beside a genuine guard row in the SAME ledger.
fgn() { # role name
  jq -nc --arg r "$1" --arg n "$2" \
    '{sprint:900, role:$r, dispatched_at:"2026-08-22T12:05:00Z",
      deliverable:("_bmad-output/" + $n + ".md"), sha:"983048af", step:"research-requirements.md"}'
}
fgn dev fgn-dev                                                       > "$WORK/foreign.jsonl"
row dev sonnet sonnet true true dev-beside-foreign                    >> "$WORK/foreign.jsonl"
cat > "$WORK/noroles-block.json" <<'JSON'
{ "aiDlcModels": { "opus": "claude-opus-5[1m]" }, "aiDlcRoles": {} }
JSON
bash "$VSL" --ledger "$WORK/norole.jsonl" --sprint 900 --settings "$WORK/noroles-block.json" >"$WORK/nr-a.out" 2>&1; a=$?
bash "$VSL" --ledger "$WORK/norole.jsonl" --sprint 900 --settings "$WORK/settings.json"      >"$WORK/nr-b.out" 2>&1; b=$?
if [ "$a" -eq 3 ] && [ "$b" -eq 3 ] && grep -q '<none>' "$WORK/nr-a.out"; then
  ok "a role-less row is out of scope under BOTH an empty aiDlcRoles block and a populated one, and is named <none> — its scope does not depend on how many roles the settings file happens to declare"
else
  bad "the role-less row answered rc=$a with an empty roles block and rc=$b with a populated one; expected 3 and 3"
fi

sed 's/^  \[ -n "\$1" \] || return 1$/  : ; /' "$VSL" > "$WORK/noguard.sh"
if cmp -s "$VSL" "$WORK/noguard.sh"; then
  bad "FIXTURE BROKEN: the empty-role guard line was renamed, so this mutant proves nothing"
else
  bash "$WORK/noguard.sh" --ledger "$WORK/norole.jsonl" --sprint 900 --settings "$WORK/noroles-block.json" >/dev/null 2>&1; a=$?
  bash "$WORK/noguard.sh" --ledger "$WORK/norole.jsonl" --sprint 900 --settings "$WORK/settings.json"      >/dev/null 2>&1; b=$?
  if [ "$a" -ne "$b" ]; then
    ok "MUTANT emptyrole: without the guard the same role-less row answers rc=$a with an empty roles block and rc=$b with a populated one — the collision the guard exists to stop"
  else
    bad "MUTANT emptyrole survived: both configs answered rc=$a without the guard"
  fi
fi

# --- 8b. a row the guard did not write is not a dispatch record ---------------
# Kept out of the battery: the skip shares the loop's top with the scope filter, so a battery
# mutant on either moves both tokens.
out="$(bash "$VSL" --ledger "$WORK/foreign.jsonl" --sprint 900 --settings "$WORK/settings.json" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && ! grep -q '^FAIL: \[' <<<"$out" \
   && grep -q '1 row(s) the dispatch guard did not write (roles: dev)' <<<"$out" \
   && grep -q 'examined 1 S900 spawn row' <<<"$out"; then
  ok "a hand-written row naming a DECLARED role is counted and named as not-a-dispatch-record rather than judged, while the guard row beside it in the same ledger is still examined — its absent fields are not observations about a dispatch"
else
  bad "the foreign row was judged or miscounted (rc=$rc): $out"
fi

# `@` as the delimiter, because the expression itself contains `|` — the first spelling of
# this mutant used `|` and sed answered "bad flag in substitute command", which left a
# truncated copy that `cmp -s` happily called a mutation. A mutant file must also PARSE.
sed 's@(if (\.v | type) == "number" then "guard" else "foreign" end)@"guard"@' "$VSL" > "$WORK/noschema.sh"
if cmp -s "$VSL" "$WORK/noschema.sh"; then
  bad "FIXTURE BROKEN: the schema-marker projection was renamed, so this mutant proves nothing"
elif ! bash -n "$WORK/noschema.sh" 2>/dev/null; then
  bad "FIXTURE BROKEN: the schema mutant does not parse — the sed damaged the script rather than mutating it"
else
  out="$(bash "$WORK/noschema.sh" --ledger "$WORK/foreign.jsonl" --sprint 900 --settings "$WORK/settings.json" 2>&1)"; rc=$?
  n=$(grep -c '^FAIL: \[' <<<"$out") || n=0
  if [ "$rc" -eq 1 ] && [ "$n" -ge 2 ]; then
    ok "MUTANT foreignschema: treating every row as guard-written manufactures $n findings from the foreign row's ABSENT fields — 24 of 25 on the reference consumer"
  else
    bad "MUTANT foreignschema survived: rc=$rc with $n FAIL arm(s)"
  fi
fi

# --- 9. the DECLARED disjunct, on its own copy --------------------------------
# The cited disjunct has a mutant; this one had none, and the arm that was supposed to cover
# it reached the loop through the CITATION instead. Kept standalone because `uncited.jsonl`
# is also declared-and-uncited, so a battery mutant moves the B arm with it.
sed 's|^  case "\$DECLARED_NL" in \*"\${NL}\${1}\${NL}"\*) return 0 ;; esac$|  case "$DECLARED_NL" in *"__NEVER__"*) return 0 ;; esac|' "$VSL" > "$WORK/nodecl.sh"
if cmp -s "$VSL" "$WORK/nodecl.sh"; then
  bad "FIXTURE BROKEN: the declared-membership test was renamed, so this mutant proves nothing"
else
  bash "$VSL"           --ledger "$WORK/declared-nonfive.jsonl" --sprint 900 --settings "$WORK/settings.json" >/dev/null 2>&1; a=$?
  bash "$WORK/nodecl.sh" --ledger "$WORK/declared-nonfive.jsonl" --sprint 900 --settings "$WORK/settings.json" >/dev/null 2>&1; b=$?
  if [ "$a" -eq 1 ] && [ "$b" -eq 3 ]; then
    ok "MUTANT declaredisjunct: without it an UNCITED dispatch of a declared role falls out of scope (3) instead of being judged (1) — the declaration is what carries the D arm, and it is now asserted rather than assumed"
  else
    bad "MUTANT declaredisjunct: shipping gave rc=$a and the mutant rc=$b; expected 1 then 3"
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

# ============================================================================
# THE EFFORT ARM. Every other arm in this file compares two things the dispatch guard
# WROTE, so a guard that bound the wrong value writes a row agreeing with itself. This one
# joins the ledger's `effort_bound` to the `effort` the subagent probe read off the
# TEAMMATE'S OWN transcript -- the effort the API call was made at, written by the harness.
# ============================================================================
erow() { # role bound cited readable name definition_bound effort tool_use_id
  jq -nc --arg r "$1" --arg b "$2" --argjson c "$3" --argjson k "$4" --arg n "$5" \
         --argjson d "$6" --arg e "$7" --arg t "$8" \
    '{v:1, sprint:900, name:$n, role:$r, model_bound:$b, model_requested:$b,
      role_contract_cited:$c, role_file_readable:$k,
      definition_bound:$d, definition_stale:false, name_stripped:$n,
      effort_bound:(if $e == "" then null else $e end),
      tool_use_id:(if $t == "" then null else $t end)}'
}
prow() { # tool_use_id effort model transcript_version
  jq -nc --arg t "$1" --arg e "$2" --arg m "$3" --arg v "$4" \
    '{v:3, sprint:900, agent_id:("a" + $t), tool_use_id:$t,
      effort:$e, model:$m, transcript_version:$v,
      peak_tokens:1000, turns:1, compactions:0, duration_s:10}'
}
evsl() { # evsl <ledger> [probe] -> "<rc> <output>"
  local o r
  if [ -n "${2:-}" ]; then
    o="$(bash "$VSL" --ledger "$WORK/$1" --sprint 900 --settings "$WORK/settings.json" --probe "$WORK/$2" 2>&1)"; r=$?
  else
    o="$(bash "$VSL" --ledger "$WORK/$1" --sprint 900 --settings "$WORK/settings.json" 2>&1)"; r=$?
  fi
  printf '%s\n%s' "$r" "$o"
}
ercv() { printf '%s' "$1" | head -1; }

# `dev` pins effort high in the settings block every arm here resolves against.
erow dev sonnet true true dev-agree    true high toolu_AGREE    > "$WORK/e-agree.jsonl"
prow toolu_AGREE high claude-sonnet-5 2.1.269                   > "$WORK/e-agree.probe"
erow dev sonnet true true dev-disagree true high toolu_DISAGREE > "$WORK/e-disagree.jsonl"
prow toolu_DISAGREE low claude-sonnet-5 2.1.269                 > "$WORK/e-disagree.probe"
# The PENDING seed's probe carries a row for a DIFFERENT dispatch. An EMPTY probe file
# would let a reader that never opened it score the same way -- the emptiness would be
# doing the work, not the join.
erow dev sonnet true true dev-pending  true high toolu_PENDING  > "$WORK/e-pending.jsonl"
prow toolu_SOMEONE_ELSE high claude-sonnet-5 2.1.269            > "$WORK/e-pending.probe"
# NOT definition-bound: the configured effort reached this teammate as prose the guard
# appended, which is advisory by construction. Its probe row DISAGREES, so an arm that
# ignored `definition_bound` would fail it.
erow dev sonnet true true dev-prose    false high toolu_PROSE   > "$WORK/e-prose.jsonl"
prow toolu_PROSE low claude-sonnet-5 2.1.269                    > "$WORK/e-prose.probe"

# --- E1. agreement is VERIFIED, and the verdict says against what -------------
R="$(evsl e-agree.jsonl e-agree.probe)"
if [ "$(ercv "$R")" -eq 0 ] && grep -q 'effort: 1 verified' <<<"$R"; then
  ok "a definition-bound row whose own transcript records the configured effort is VERIFIED, and COUNTS says so -- the first thing in this check that reads ground truth rather than a record the guard wrote"
else
  bad "the agreeing row was not verified: $R"
fi

# --- E2. disagreement FAILS, names both values, and names the remedy ----------
R="$(evsl e-disagree.jsonl e-disagree.probe)"
if [ "$(ercv "$R")" -eq 1 ] && grep -q "records effort='low'" <<<"$R" \
   && grep -q "effort_bound=" <<<"$R" && grep -q "'high'" <<<"$R" \
   && grep -q "aiDlcRoles.dev.effort" <<<"$R" && grep -q 'effort: 0 verified.*1 mismatch' <<<"$R"; then
  ok "a definition-bound row whose transcript records a DIFFERENT effort FAILS, naming the LEDGER's bound level, the observed one, and the re-render remedy -- this is BL-240's whole subject, and nothing could see it before"
else
  bad "the disagreeing row did not fail as expected: $R"
fi

# --- E3. no joined probe row is PENDING, never FAIL and never a silent pass ---
# A consumer that pulls this release mid-sprint is in exactly this state for every row
# already dispatched. Failing it would wedge the sprint on a verification that could not
# have run; passing it silently would report a check that did not happen.
R="$(evsl e-pending.jsonl e-pending.probe)"
if [ "$(ercv "$R")" -eq 0 ] && grep -q '1 PENDING (no probe row joined' <<<"$R" \
   && ! grep -q '^FAIL: \[' <<<"$R"; then
  ok "a definition-bound row with no joined probe row is PENDING and COUNTED -- 'verified nothing' and 'found nothing' cannot read alike"
else
  bad "the unjoined row was not reported PENDING: $R"
fi

# ...and with NO --probe at all, which is every caller that has not been updated.
R="$(evsl e-pending.jsonl)"
if [ "$(ercv "$R")" -eq 0 ] && grep -q 'no --probe was passed' <<<"$R"; then
  ok "  and a caller passing no --probe is told so by name, rather than getting a clean-looking verdict over an arm that never ran"
else
  bad "an invocation without --probe did not say so: $R"
fi

# --- E4. a row that bound NO effort is UNDECLARED: never a FAIL, and never silent ------
# The prose-only dispatch got its configured level as a sentence the guard appended, which
# the Agent tool has no parameter to apply, so the teammate ran at whatever its session
# resolved. Its probe row DISAGREES on purpose: an arm that judged this row would fail it.
R="$(evsl e-prose.jsonl e-prose.probe)"
if [ "$(ercv "$R")" -eq 0 ] && ! grep -q '^FAIL: \[' <<<"$R"; then
  ok "a row that bound no effort is not judged on it even when its transcript disagrees -- the guard's prompt sentence is advisory by construction and failing it would be a FAIL on correct data"
else
  bad "a row that bound no effort was judged on effort: $R"
fi
# ...AND IT IS COUNTED, which is the half that stops the acquittal from being a skip. A row
# passed over in silence and a row examined and found to have bound nothing print the same
# verdict otherwise, and a sprint whose every row bound nothing would read exactly like one
# where every row was verified. The COUNTS line is what tells them apart.
if grep -q '1 row(s) that bound no effort' <<<"$R" \
   && grep -q 'effort: 0 verified' <<<"$R"; then
  ok "  and the COUNTS line REPORTS it as a row that bound no effort rather than passing over it -- 'nothing to verify' and 'nothing found wrong' cannot read alike"
else
  bad "  the row that bound no effort was acquitted without being counted, so it is indistinguishable from a row the arm never reached: $R"
fi

# --- E5. THE DISCRIMINATING SEED: two SAME-ROLE spawns, out of order ----------
# THE CASE EVERY ORDERED JOIN GETS WRONG, AND THE REASON THIS ARM EXISTS AT ALL. The
# ledger is written at DISPATCH; the probe fires at COMPLETION. Two `dev` spawns that
# finish in reverse dispatch order are indistinguishable to a join keyed on (role,
# most-recent-unmatched) -- and because both pin the SAME configured effort, the
# comparison PASSES on the wrong pairing and reports an agreement it never established.
#
# A seed with two DIFFERENT roles resolves 100% under any join and discriminates nothing,
# which is why both rows here are `dev`. `dev-first` ran at the wrong level; `dev-second`
# ran correctly; the telemetry is written in the order they COMPLETED, which is second
# then first.
{ erow dev sonnet true true dev-first  true high toolu_FIRST
  erow dev sonnet true true dev-second true high toolu_SECOND; } > "$WORK/e-sameRole.jsonl"
{ prow toolu_SECOND high claude-sonnet-5 2.1.269
  prow toolu_FIRST  low  claude-sonnet-5 2.1.269; } > "$WORK/e-sameRole.probe"
R="$(evsl e-sameRole.jsonl e-sameRole.probe)"
if [ "$(ercv "$R")" -eq 1 ] && grep -q 'FAIL: \[dev-first\]' <<<"$R" \
   && ! grep -q 'FAIL: \[dev-second\]' <<<"$R" \
   && grep -q 'effort: 1 verified.*1 mismatch' <<<"$R"; then
  ok "E5 two SAME-ROLE spawns completing in REVERSE dispatch order: the offender is named as dev-first and dev-second is verified -- the join resolves on the tool-use id, which no completion order can permute"
else
  bad "E5 the same-role out-of-order pair was mis-scored: $R"
fi

# THE MIRROR, in the same run. Reversing the TELEMETRY order must not move the verdict:
# that invariance IS the property, and a single ordering cannot establish it -- an ordered
# join is right on one of the two and wrong on the other, which reads exactly like working.
{ prow toolu_FIRST  low  claude-sonnet-5 2.1.269
  prow toolu_SECOND high claude-sonnet-5 2.1.269; } > "$WORK/e-sameRole2.probe"
R2="$(evsl e-sameRole.jsonl e-sameRole2.probe)"
if [ "$(ercv "$R2")" -eq 1 ] && grep -q 'FAIL: \[dev-first\]' <<<"$R2" \
   && ! grep -q 'FAIL: \[dev-second\]' <<<"$R2"; then
  ok "  and reversing the telemetry order names the SAME offender -- order-invariance asserted, not assumed"
else
  bad "  reversing the telemetry order changed the verdict, so the join IS order-dependent: $R2"
fi

# --- E6. the pre-2.1.267 refusal, with its own control -----------------------
# CC 2.1.259/2.1.267 fixed `effort:` on models whose launch effort is PINNED, so a value
# read off an earlier build is not evidence there. REFUSED is its own outcome and not
# PENDING: "no ground truth yet" and "ground truth I will not trust" have different
# remedies, and collapsing them makes an unverifiable row read as an unwritten one.
erow dev sonnet true true dev-pinned true high toolu_PINNED > "$WORK/e-pinned.jsonl"
prow toolu_PINNED low claude-opus-4-8 2.1.250               > "$WORK/e-old.probe"
prow toolu_PINNED low claude-opus-4-8 2.1.269               > "$WORK/e-new.probe"
R="$(evsl e-pinned.jsonl e-old.probe)"
if [ "$(ercv "$R")" -eq 0 ] && grep -q '1 refused on a pre-2.1.267' <<<"$R" \
   && grep -q 'PENDING: \[dev-pinned\]' <<<"$R"; then
  ok "a pinned-effort model on a pre-2.1.267 transcript is REFUSED and named, not scored -- the field is not evidence on that build"
else
  bad "the pre-2.1.267 pinned row was not refused: $R"
fi
# THE CONTROL, and it is the half that proves the floor DISCRIMINATES. Same row, same
# disagreement, same model -- only the version differs. Without it the refusal could be
# refusing on the model alone, or on everything, and both read identically.
R="$(evsl e-pinned.jsonl e-new.probe)"
if [ "$(ercv "$R")" -eq 1 ] && grep -q '1 mismatch' <<<"$R"; then
  ok "  CONTROL: the SAME pinned model at 2.1.269 IS scored and fails -- the refusal keys on the version, not on the model alone"
else
  bad "  CONTROL: the pinned model at 2.1.269 was not scored, so the refusal is wider than the version floor: $R"
fi

# --- E7. WHICH SIDE THE COMPARISON READS, and no arm above can tell. Every seed so far
# gives the ledger and the settings block the SAME effort, so a validator reading either one
# scores identically on all of them -- the classic non-discriminating seed. The pair below
# makes them DISAGREE, which is the state a role reconfigured between the spawn and the gate
# is in, and it is the only input that separates the two readings.
#
# THE ROW IS A FACT ABOUT THE PAST. `effort_bound` says what the harness was asked to apply
# to THAT dispatch; settings at gate time says what the role is configured for NOW. Scoring a
# dispatch against a configuration written after it ran fails a teammate that did exactly what
# it was told, and passes one that did not, depending only on which way the edit went. Both
# directions are seeded here, in the same run, because one alone reads identically under a
# validator that has simply stopped comparing.
#
# THESE TWO ROWS ARE HAND-WRITTEN AND NO GUARD CAN EMIT THEM AGAINST THESE SETTINGS, WHICH IS
# THE POINT AND IS STATED SO NOBODY READS THEM AS OBSERVED DISPATCHES. The guard sets
# `definition_bound` only when the rendered definition agrees with settings on effort, so a
# row it wrote carries an `effort_bound` equal to the configured level AT DISPATCH. Reaching
# this state on a real consumer takes a settings edit BETWEEN the dispatch and the gate, which
# leaves the ledger untouched and is exactly the sequence under test -- unconstructible in one
# snapshot of a tree, so the row is written directly. It is reachable under the mechanism's own
# contract; it is only unreachable from a single reading of the config.
cat > "$WORK/settings-reconfigured.json" <<'JSON'
{
  "aiDlcModels": { "opus": "claude-opus-5[1m]", "sonnet": "claude-sonnet-5" },
  "aiDlcRoles": {
    "dev": { "model": "sonnet", "effort": "low" },
    "protected-path-editor": { "model": "opus" },
    "adversary": { "model": "opus" },
    "tea": { "effort": "medium" }
  }
}
JSON
# CONTROL, and it runs before the arms: the two settings files must actually disagree on the
# field under test, or both arms below are asking one question twice.
S_OLD="$(jq -r '.aiDlcRoles.dev.effort' "$WORK/settings.json")"
S_NEW="$(jq -r '.aiDlcRoles.dev.effort' "$WORK/settings-reconfigured.json")"
if [ "$S_OLD" = "high" ] && [ "$S_NEW" = "low" ]; then
  ok "E7 CONTROL: the two settings files declare dev.effort as '$S_OLD' and '$S_NEW' -- the sides of this differential differ, so a null below would mean something"
else
  bad "E7 CONTROL is dead: settings declare '$S_OLD' and '$S_NEW'; with the two agreeing, neither arm below can discriminate"
fi

evslx() { # evslx <ledger> <probe> <settings> -> "<rc>\n<output>"
  local o r
  o="$(bash "$VSL" --ledger "$WORK/$1" --sprint 900 --settings "$WORK/$3" --probe "$WORK/$2" 2>&1)"; r=$?
  printf '%s\n%s' "$r" "$o"
}

# The row bound `high` and the teammate ran at `high`: the dispatch did exactly what it was
# asked. Settings now say `low`. A validator reading the LEDGER verifies it; one reading
# SETTINGS reports a mismatch against a level no dispatch ever carried.
erow dev sonnet true true dev-reconf true high toolu_RECONF > "$WORK/e-reconf.jsonl"
prow toolu_RECONF high claude-sonnet-5 2.1.269              > "$WORK/e-reconf.probe"
R="$(evslx e-reconf.jsonl e-reconf.probe settings-reconfigured.json)"
if [ "$(ercv "$R")" -eq 0 ] && grep -q 'effort: 1 verified' <<<"$R" \
   && ! grep -q '^FAIL: \[' <<<"$R"; then
  ok "E7 a row that bound 'high' and ran at 'high' is VERIFIED even though settings now say 'low' -- the comparison reads what the dispatch was asked to apply, not what the role was reconfigured to afterwards"
else
  bad "E7 the reconfigured-role row was not verified against its own effort_bound: $R"
fi

# THE MIRROR, same run, the disagreement inverted. The row bound `low`, the teammate ran at
# `high`, and settings say `high`: the dispatch did NOT get what it bound. A validator reading
# settings passes it; one reading the ledger fails it. Without this half the arm above is
# satisfied by a validator that stopped judging effort at all.
erow dev sonnet true true dev-reconf2 true low toolu_RECONF2 > "$WORK/e-reconf2.jsonl"
prow toolu_RECONF2 high claude-sonnet-5 2.1.269              > "$WORK/e-reconf2.probe"
R="$(evsl e-reconf2.jsonl e-reconf2.probe)"
if [ "$(ercv "$R")" -eq 1 ] && grep -q 'FAIL: \[dev-reconf2\]' <<<"$R" \
   && grep -q "'low'" <<<"$R" && grep -q "records effort='high'" <<<"$R" \
   && grep -q 'effort: 0 verified.*1 mismatch' <<<"$R"; then
  ok "E7 MIRROR a row that bound 'low' and ran at 'high' FAILS while settings declare 'high' -- the ledger value is the one compared, in both directions"
else
  bad "E7 MIRROR the row that bound 'low' was not failed against its own effort_bound: $R"
fi

# A row flagged definition-bound and carrying NO effort_bound bound nothing, so it is
# UNDECLARED rather than a mismatch against whatever settings happen to say. Its probe row
# JOINS and disagrees with settings, so a validator that fell back to the settings read would
# fail it -- which is what makes this the arm that separates the two readings on a row the old
# scope test DID judge.
erow dev sonnet true true dev-noeffort true '' toolu_NOEFFORT > "$WORK/e-noeffort.jsonl"
prow toolu_NOEFFORT low claude-sonnet-5 2.1.269               > "$WORK/e-noeffort.probe"
R="$(evsl e-noeffort.jsonl e-noeffort.probe)"
if [ "$(ercv "$R")" -eq 0 ] && grep -q '1 row(s) that bound no effort' <<<"$R" \
   && ! grep -q '^FAIL: \[' <<<"$R"; then
  ok "E7 a row flagged definition-bound with a NULL effort_bound is UNDECLARED and counted, not scored against settings -- the scope key is the field, not the flag"
else
  bad "E7 the null-effort_bound row was not reported UNDECLARED: $R"
fi

# --- E8. MUTANTS. Each arm above is PRESENCE-shaped, so a validator emitting nothing
# fails them -- but that does not establish which LINE produced each verdict.
sed 's/^  if \[ -z "\$effortbound" \] || \[ "\$defbound" != "true" \]; then$/  if true; then/' "$VSL" > "$WORK/noeffortarm.sh"
if cmp -s "$VSL" "$WORK/noeffortarm.sh"; then
  bad "FIXTURE BROKEN: the effort arm's scope test was renamed, so this mutant proves nothing"
else
  bash "$WORK/noeffortarm.sh" --ledger "$WORK/e-disagree.jsonl" --sprint 900 \
       --settings "$WORK/settings.json" --probe "$WORK/e-disagree.probe" >/dev/null 2>&1; rc=$?
  if [ "$rc" -eq 0 ]; then
    ok "MUTANT noeffortarm: dropping the arm turns a teammate that demonstrably ran at the wrong effort into a clean exit 0 -- E2 is load-bearing"
  else
    bad "MUTANT noeffortarm survived: rc=$rc without the arm, so E2 cannot be what produced the 1"
  fi
fi

# THE JOIN KEY ITSELF. Replacing the exact id match with a ROLE match is the ordered join
# this design rejected, expressed as a mutation: on the same-role pair it pairs both stops
# with whichever row jq returns last, so one of the two is scored against the other's
# transcript. The assertion is on the OFFENDER'S NAME, not on the exit code, because both
# implementations exit 1 here -- a code-only arm would score this mutant as killed while
# the mis-pairing went unseen.
sed 's@select((.tool_use_id // "") == \$t) \] | last@select(true) ] | last@' "$VSL" > "$WORK/rolejoin.sh"
if cmp -s "$VSL" "$WORK/rolejoin.sh"; then
  bad "FIXTURE BROKEN: the tool_use_id join expression was renamed, so this mutant proves nothing"
else
  out="$(bash "$WORK/rolejoin.sh" --ledger "$WORK/e-sameRole.jsonl" --sprint 900 \
         --settings "$WORK/settings.json" --probe "$WORK/e-sameRole.probe" 2>&1)"
  if grep -q 'FAIL: \[dev-second\]' <<<"$out" || ! grep -q 'FAIL: \[dev-first\]' <<<"$out"; then
    ok "MUTANT unjoined: with the id match removed the same-role pair is scored against the wrong transcript and the verdict names the wrong spawn -- E5 is what catches it, and an exit-code-only arm could not"
  else
    bad "MUTANT unjoined survived: the offender was still named correctly without the id match, so E5's join assertion is not load-bearing: $out"
  fi
fi

# The version floor, on its own copy: without it a pre-2.1.267 pinned record is scored as
# though the field meant something, and E6's refusal becomes a mismatch.
sed 's@< \[2,1,267\])@< [0,0,0])@' "$VSL" > "$WORK/nofloor.sh"
if cmp -s "$VSL" "$WORK/nofloor.sh"; then
  bad "FIXTURE BROKEN: the version floor was renamed, so this mutant proves nothing"
else
  bash "$WORK/nofloor.sh" --ledger "$WORK/e-pinned.jsonl" --sprint 900 \
       --settings "$WORK/settings.json" --probe "$WORK/e-old.probe" >/dev/null 2>&1; rc=$?
  if [ "$rc" -eq 1 ]; then
    ok "MUTANT nofloor: without the 2.1.267 floor a pinned-effort record from a build where the field was wrong is scored as a finding -- E6 is what stops a false FAIL on correct data"
  else
    bad "MUTANT nofloor survived: rc=$rc, so the floor is not what produced E6's refusal"
  fi
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "check-22-spawn-ledger: PASS ($asserted assertions)"
  exit 0
fi
echo "check-22-spawn-ledger: $fails of $asserted assertion(s) FAILED" >&2
exit 1
