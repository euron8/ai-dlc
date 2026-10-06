#!/usr/bin/env bash
# advisor-gate-deny-mutants/run.sh — the mutation battery behind the shipped `advisor-gate-deny`
# fixture. DISTRIBUTION-ONLY (see .dist-only). This file is shard 'a' and holds every mutant;
# the sibling directories advisor-gate-deny-mutants-<x> are one-line drivers that exec it with
# `--group <x>`.
#
# ONE COPY OF THE CELLS. Every shard sources `advisor-gate-deny/lib.sh`, so a mutant is scored by
# the same `score` over the same cells the shipped fixture runs. A mutant is a copy of the hook
# beside a copy of its provenance sibling, guarded with `cmp -s` so a `sed` that matched nothing
# reports DID NOT APPLY. Each declares the EXACT set of arms it must fail, and `mutc` also the
# exact set of CELLS, compared byte-for-byte with what `score` prints, so it dies on its own cell
# and on no other. An unmutated copy driven the same way must fail nothing, in every shard, and
# PUSH gives that control its positive conjunct.
#
# WHY SHARDED. Held in the shipped fixture, the battery was ~97% of its wall clock (every mutant
# drives every cell), and the pre-push suite is POLE-BOUND on its longest directory.
#
# THE DEAL IS DERIVED, NEVER WRITTEN. The declared set is this file's own `mut`/`mutc` lines, in
# order; mutant i goes to shard ((i-1) mod |SHARDS|). Every mutant drives the same cells, so the
# cost per mutant is roughly uniform and a round-robin deal balances. Before any mutant runs, every
# shard checks the deal is disjoint and its union is the declared set exactly (that check is
# probed on a seeded duplicate and omission first), that every declared shard has a driver
# directory naming it, and that the declared set has not shrunk below MIN_MUTANTS -- a deleted
# mutant line would otherwise just leave every shard shorter and green. After its mutants run, a
# shard asserts it ran exactly the ones dealt to it.
#
# Usage: run.sh [--group <shard>]
# Exit:  0 = every mutant dealt here is killed by exactly its arms and cells and the control fails
#        nothing, 1 = an assertion failed, 2 = fixture broken.
SHARDS="a b c d e"
# A ratchet, raised when a mutant is added: lowering it is a visible edit, a lost mutant is not.
MIN_MUTANTS=60
set -uo pipefail

# The pre-push gate exports AI_DLC_* tunables; none is read here, but scrub them all the same.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

GROUP=a
if [ "${1:-}" = "--group" ]; then
  GROUP="${2:-}"
  [ -n "$GROUP" ] || { echo "FIXTURE ERROR: --group needs a shard name" >&2; exit 2; }
fi
case " $SHARDS " in
  *" $GROUP "*) ;;
  *) echo "FIXTURE ERROR: unknown shard '$GROUP' (known: $SHARDS)" >&2; exit 2 ;;
esac
NAME="advisor-gate-deny-mutants"
[ "$GROUP" = a ] || NAME="$NAME-$GROUP"

HERE="$(cd "$(dirname "$0")" && pwd)"
SELF="$HERE/run.sh"
LIB="$HERE/../advisor-gate-deny/lib.sh"
[ -f "$SELF" ] || { echo "FIXTURE ERROR: cannot read $SELF for the coverage join" >&2; exit 2; }
[ -f "$LIB" ] || { echo "FIXTURE BROKEN: $LIB is absent; no cell exists to score a mutant against" >&2; exit 2; }

# partition_ok <declared file> <dealt file> -> 0 when dealt is disjoint and covers declared exactly.
partition_ok() {
  local dup miss extra
  dup="$(sort "$2" | uniq -d | tr '\n' ' ')"
  miss="$(sort -u "$2" | comm -23 <(sort -u "$1") - | tr '\n' ' ')"
  extra="$(sort -u "$2" | comm -13 <(sort -u "$1") - | tr '\n' ' ')"
  [ -z "$dup$miss$extra" ] && return 0
  echo "dealt twice: {${dup% }} dealt to no shard: {${miss% }} dealt but not declared: {${extra% }}"
  return 1
}
JW="$(mktemp -d "${TMPDIR:-/tmp}/agd-join.XXXXXX")" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
printf '%s\n' m1 m2 m3 > "$JW/pd"; printf '%s\n' m1 m2 m2 m3 > "$JW/pdup"
printf '%s\n' m1 m3 > "$JW/pmiss"; printf '%s\n' m3 m1 m2 > "$JW/pok"
if partition_ok "$JW/pd" "$JW/pdup" >/dev/null || partition_ok "$JW/pd" "$JW/pmiss" >/dev/null \
   || ! partition_ok "$JW/pd" "$JW/pok" >/dev/null; then
  echo "FIXTURE BROKEN: the coverage join's self-probe did not discriminate (duplicate, omission, exact)" >&2; exit 2
fi
awk '$1 == "mut" || $1 == "mutc" { print $2 }' "$SELF" > "$JW/declared"
ndecl="$(grep -c . "$JW/declared")" || ndecl=0
ndup="$(sort "$JW/declared" | uniq -d | grep -c .)" || ndup=0
if [ "$ndecl" -lt "$MIN_MUTANTS" ] || [ "$ndup" -ne 0 ]; then
  echo "FIXTURE BROKEN: $ndecl mutants declared in $SELF (floor $MIN_MUTANTS), $ndup declared twice" >&2; exit 2
fi
nsh=0; for _s in $SHARDS; do nsh=$((nsh+1)); done
: > "$JW/dealt"; MINE=""
_k=0
for _s in $SHARDS; do
  awk -v k="$_k" -v n="$nsh" '(NR - 1) % n == k' "$JW/declared" > "$JW/shard.$_s"
  [ -s "$JW/shard.$_s" ] || { echo "FIXTURE BROKEN: shard '$_s' is dealt no mutant; a shard dealt nothing passes everything it never checked" >&2; exit 2; }
  cat "$JW/shard.$_s" >> "$JW/dealt"
  [ "$_s" = "$GROUP" ] && MINE="$(tr '\n' ' ' < "$JW/shard.$_s" | sed 's/ $//')"
  _k=$((_k+1))
done
for _s in $SHARDS; do
  [ "$_s" = a ] && continue
  drv="$HERE/../advisor-gate-deny-mutants-$_s/run.sh"
  if [ ! -f "$drv" ] || ! grep -qF -- "--group $_s" "$drv"; then
    echo "FIXTURE BROKEN: shard '$_s' is declared but $drv does not drive it" >&2; exit 2
  fi
done
if ! why="$(partition_ok "$JW/declared" "$JW/dealt")"; then
  echo "FIXTURE BROKEN: the shard partition does not cover the declared mutants exactly -- $why" >&2; exit 2
fi
nmine=0; for _m in $MINE; do nmine=$((nmine+1)); done
[ "$nmine" -gt 0 ] || { echo "FIXTURE BROKEN: shard '$GROUP' has no mutants" >&2; exit 2; }

# shellcheck source=../advisor-gate-deny/lib.sh
. "$LIB"

echo "$NAME:"
printf '  hook  %s\n' "$HOOK"
printf '  cells %s\n' "$nc"
ok "[J0] coverage join: $ndecl mutants (floor $MIN_MUTANTS) derived from mut/mutc lines, dealt disjointly across {$SHARDS}, union exact; this shard runs $nmine: {$MINE}"

n_mut=0; n_kill=0; n_seen=0
[ -f "$PROV" ] && cp "$PROV" "$MUT/ai-dlc-context-provenance.sh"
# mutc <name> <expected-failing-arms> <expected-failing-cells or -> <sed-expr>...
mutc() {
  local name="$1" want="$2" wantc="$3"; shift 3
  case " $MINE " in *" $name "*) ;; *) return 0 ;; esac
  n_seen=$((n_seen+1))
  local m="$MUT/hook-$name.sh"
  if ! sed "$@" "$HOOK" > "$m"; then bad "mutant $name: sed failed -- DID NOT APPLY"; return; fi
  if cmp -s "$HOOK" "$m"; then bad "mutant $name: sed matched nothing -- DID NOT APPLY (the anchor moved)"; return; fi
  n_mut=$((n_mut+1))
  local got gotc; got="$(score "$m" "$W/failed.$name")"; gotc="$(cells_of "$W/failed.$name")"
  if [ "$got" = "$want" ] && { [ "$wantc" = - ] || [ "$gotc" = "$wantc" ]; }; then
    n_kill=$((n_kill+1))
    if [ "$wantc" = - ]; then ok "mutant $name killed by exactly: $want"
    else ok "mutant $name killed by exactly: $want, on cell(s) $gotc only"; fi
  elif [ -z "$got" ]; then
    bad "mutant $name SURVIVED every arm (expected to fail: $want)"
  else
    bad "mutant $name failed [$got] on cells [$gotc], expected exactly [$want] on [$wantc]"
  fi
}
# mut <name> <expected-failing-arms> <sed-expr>...
mut() { local name="$1" want="$2"; shift 2; mutc "$name" "$want" - "$@"; }

cp "$HOOK" "$MUT/hook-control.sh"
CTL="$(score "$MUT/hook-control.sh" "$W/failed.control")"
[ -z "$CTL" ] && ok "unmutated copy from the mutant directory passes every arm" \
              || bad "unmutated copy fails [$CTL] -- the harness, not a mutant, is what fails"

# Expected sets are C-locale sorted, which is what score() prints.
# 1. the whole subject replaced by silence: every arm holding a DENY, WARN or stderr cell fails.
mut silence "BASHC BODY CLOSE DENIED DETACHED ENVELOPE FAILOPEN GATELOG GHREPO MATE MATEABSENT MATEPATH MATEREWRITE MCPNAME MERGE ORDER PATHGIT PERKIND PUSH QUOTEDC QUOTEDENV REARM REASON REDISPATCH SELF SELFLAST STACK TWRITE UNAV UPDATE UPDATECUT UPDATEREF WITHDRAWN WRAP" -e '2i\
exit 0'
# 2. warn-only: the rejected design, the same text as context with no decision.
#    UNAV survives it by design: the warn path is its own emission and this mutant leaves it intact.
mut warn-only "BASHC BODY CLOSE DENIED DETACHED ENVELOPE GATELOG GHREPO MATE MATEPATH MATEREWRITE MCPNAME MERGE ORDER PATHGIT PERKIND PUSH QUOTEDC QUOTEDENV REARM REASON REDISPATCH SELF SELFLAST STACK TWRITE UPDATE UPDATECUT UPDATEREF WITHDRAWN WRAP" \
  -e 's/permissionDecision: "deny", permissionDecisionReason: \$m/additionalContext: $m/'
# 3. no grant test: a hook with a knob-free default of ON.
mut no-grant-test "NOGRANT WITHDRAWN" -e '/^\[ "\${GRANT:-none}" = on \] || exit 0$/d'
# 4. a withdrawn grant still counts as granted.
mut withdrawn-ignored "WITHDRAWN" -e 's/\.grant = ((\$l\.attachment\.available != false) and (\$l\.attachment\.toolChange != "remove"))/.grant = true/'
# 5. the unavailable carve-out removed: the deny nothing can clear.
mut no-unavailable-warn "UNAV" -e 's/if \[ "\${LAST_RES:--}" = U \]; then/if [ "${LAST_RES:--}" = NEVER ]; then/'
# 6. a later success does not re-arm.
mut no-rearm "REARM" -e 's/then "U" else "R" end)/then "U" else .res end)/'
# 7. only a SUCCESSFUL attempt clears: an errored attempt is discarded.
mut error-does-not-clear "ERRCLEAR" \
  -e 's/elif \$b\.type == "advisor_tool_result" then/elif $b.type == "advisor_tool_result" and ((($b.content | if type == "object" then .error_code else null end) \/\/ "unavailable") != "unavailable") then .adv = 0 elif $b.type == "advisor_tool_result" then/'
# 8. any advisor call ever clears, whatever came after it. UNAV and REARM die too: both worlds
#    hold an advisor call BEFORE the owed push, so the mutant allows where they warn and deny;
#    so do ENVELOPE, REDISPATCH (a9) and SELFLAST, whose deny cells all sit after an older advisor.
mut any-advisor-clears "DENIED ENVELOPE ORDER PERKIND REARM REDISPATCH SELF SELFLAST UNAV" -e 's/\[ "\${LAST_ADV:-0}" -gt "\${LAST_ACT:-0}" \]/[ "${LAST_ADV:-0}" -gt 0 ]/'
# 9. a branch delete is gated.
mut delete-gated "DELETE" -e 's/gitpush and (isdelete | not)/gitpush/'
# 10. the MCP merge tool escapes.
mut no-mcp-merge "MCPNAME MERGE" -e 's/startswith("mcp__") and endswith("__merge_pull_request")/startswith("mcp__NEVER")/'
# 11. `record` gated alongside `close`.
mut record-gated "CLOSE" -e 's/\\\\sclose(\\\\s|\$)/\\\\s(close|record)(\\\\s|$)/'
# 12. the push match loses its start anchor, so a mention is a push -- including the mentions
#     that are the allow twins of BASHC and BODY.
mut push-unanchored "BASHC BODY MENTION" -e 's/^def gitre: "^/def gitre: "/'
# 13. the update skill's branch is gated.
mut update-gated "UPDATE" -e 's|ai-dlc-update/\*) exit 0 ;;|ai-dlc-update-NEVER/*) exit 0 ;;|'
# 14. a detached HEAD or a git failure is read as the update branch.
mut detached-excluded "DETACHED" -e 's|\|\| _br=""$|\|\| _br="ai-dlc-update/unknown"|'
# 15. a teammate is judged on the handed (parent) transcript. Every teammate world whose parent
#     holds an advisor call dies, which is the point: the parent's call clears the teammate.
mut mate-on-parent "MATE MATEABSENT MATEPATH MATEREWRITE REDISPATCH" -e 's|^\[ -z "\$AID" \] \|\| JUDGED=.*$|:|'
# 16. an absent teammate file falls back to the handed path (the operator's local hook).
mut mate-fallback "MATEABSENT" -e 's/^\[ -r "\$JUDGED" \] || {/[ -r "$JUDGED" ] || JUDGED="$TP"; [ -r "$JUDGED" ] || {/'
# 17. a teammate's push is gated like the lead's.
mut mate-push-gated "MATEPUSH" -e 's/def kind(\$role): if \$role == "lead" then leadkind else matekind end;/def kind($role): leadkind + matekind;/'
# 18. every teammate write is a verdict.
mut mate-any-write "MATEPATH" -e 's/then "verdict" else "" end/then "verdict" else "verdict" end/'
# 19. a re-write of the agent's own deliverable is a new gated action. REDISPATCH dies too: its
#     notification twins are re-writes that stay exempt only through the same exemption.
mut no-rewrite-exemption "MATEREWRITE REDISPATCH" -e 's/\[ "\${SAME:-0}" -gt 0 \]/[ "${SAME:-0}" -gt 99999 ]/'
# 20. a call this hook denied is counted as a gated action.
mut denied-counted "DENIED" -e 's/\.g |= del(\.\[(\$b\.tool_use_id \/\/ "") | tostring\])/./'
# 21. the incoming call, already on disk, is counted against itself.
mut self-counted "SELF" -e 's/and ((\$b\.id | tostring) != \$tuid)/and true/'
# 22. the transcript-write deny is conditioned on the grant (deleting the grant line disables it).
mut twrite-needs-grant "TWRITE" -e 's/^if \[ "\$KIND" = twrite \]; then$/if [ "$KIND" = twrite ] \&\& grep -q advisor_tool "$TP" 2>\/dev\/null; then/'
# 23. the projects directory is assumed at ~/.claude/projects rather than derived.
mut twrite-fixed-dir "TWRITE" -e 's|(\$tp \| if test("^.+/\[^/\]+/\[^/\]+\\\\.jsonl\$") then sub("/\[^/\]+/\[^/\]+\$"; "") else "" end) as \$proj|($home + "/.claude/projects") as $proj|'
# 24. a mention of the transcript plus any `>` is read as a write.
mut twrite-any-redirect "TWRITEREAD" -e 's/((\$c | redirs | map(expand(\$home) | under(\$proj)) | any)/((($c | contains($proj + "\/")) and ($c | contains(">")))/'
# 25. any Write to gate-log.md is Check 12, the header-only rotation included.
mut gatelog-by-path "GATELOG" -e 's/then (if ((\.input\.content \/\/ "") | tostring | heads) > 0 then "gatelogw" else "" end)/then "gatelog"/'

# 26. D1: any error result CONTAINING the token removes the call, so a push that ran is erased.
mut envelope-unanchored "ENVELOPE" -e 's/| test("^PreToolUse:\[A-Za-z_\]+ hook error: ai-dlc-advisor-gate: DENIED")/| contains("ai-dlc-advisor-gate: DENIED")/'
# 27. D4: a re-dispatch does not end the re-write exemption.
mut no-redispatch "REDISPATCH" -e 's/then \.g |= map_values(\.\[1\] = "") else \. end)/then . else . end)/'
# 28. D4 done wrong: a re-dispatch forgets the gated action itself, so an older advisor clears it.
mut redispatch-drops-action "REDISPATCH" -e 's/then \.g |= map_values(\.\[1\] = "") else \. end)/then .g = {} else . end)/'
# 29. the incoming call on the transcript's last line is counted against itself (the live wedge).
mut selflast-counted "SELFLAST" -e 's/(if \$tuid == "" then \.g |= with_entries(select(\.value\[0\] != \$last)) else \. end)/./'
# 30. D3: a push naming the update branch as its refspec is not excluded.
mut refspec-not-excluded "UPDATEREF" -e 's/((\$r | length) > 0 and (\$r | all(upd)))/false/'
# 31. D3: a branch cut in the same command is not read.
mut cut-not-excluded "UPDATECUT" -e 's/(\$s | map(cutupd(\$v)) | any) as \$cut/false as $cut/'
# 32. D3: a `$B` refspec is not resolved through its assignment.
mut no-var-resolution "UPDATECUT" -e 's/(if (\$c | test("ai-dlc-update\/")) then (\$c | vars) else {} end) as \$v/{} as $v/'
# 33. D5: no wrapper word is stripped. PUSH dies too: its `timeout 600 git push` cell is a wrapper.
mut no-wrappers "PUSH STACK WRAP" -e 's/(nohup|exec|command|time|sudo|setsid|caffeinate|then/(then/' -e 's/|g?timeout(\\\\s+-\\\\S+)\*\\\\s+\[0-9.\]+\[smhd\]?|env(\\\\s+(-u|--unset)\\\\s+\\\\S+|\\\\s+-\\\\S+)\*)/)/'
# 34. D5: wrappers strip once, not in a loop.
mut no-strip-loop "STACK" -e 's/then (\$n | strip) elif/then $n elif/'
# 35. D5: the string argument of `bash -c` is not read.
mut no-bashc "BASHC STACK" -e 's/elif test(bashc) then (sub(bashc; "") | strip)/elif false then ./'
# 36. D5: `git` must be bare, so `/usr/bin/git push` escapes.
mut no-path-git "PATHGIT" -e 's|^def gitre: "^(\\\\S\*/)?git|def gitre: "^git|'
# 37. D5: `if`/`for`/`{ }` bodies are not entered.
mut no-bodies "BODY" -e 's/|then|do|else|if|while|until|!|\\\\{)(/)(/'
# 38. D5: `git -c` takes an unquoted value only.
mut no-quoted-c "QUOTEDC" -e 's/--namespace)\\\\s+(\\"\[^\\"\]\*\\"|\\\\x27\[^\\\\x27\]\*\\\\x27|\\\\S+)/--namespace)\\\\s+(\\\\S+)/'
# 39. D5: an environment assignment takes an unquoted value only.
mut no-quoted-env "QUOTEDENV" -e 's/^def envre: .*$/def envre: "^[A-Za-z_][A-Za-z0-9_]*=\\\\S*\\\\s+";/'
# 40. D5: `gh -R <repo> pr merge` escapes.
mut no-gh-repo "GHREPO" -e 's/gh(\\\\s+(-R|--repo)(\\\\s+|=)\\\\S+)\*\\\\s+pr/gh\\\\s+pr/'
# 43. the kinds collapse back to one: any gated action owes the next.
mut kinds-collapsed "PERKIND" -e 's/(\[\.g\[\] | select(\.\[2\] == \$kind) | \.\[0\]\] | max \/\/ 0) as \$act/([.g[] | .[0]] | max \/\/ 0) as $act/'
# 42. the closing quote is shed from every segment, so a quoted pattern reads as a push.
mut quote-shed-always "QUOTEDPAT" -e 's/^def csegs: segs as \$s | if test(.*$/def csegs: segs as $s | if true/'
# 41. the template's regex is not mirrored: only the github server's tool is a merge.
mut mcp-exact-name "MCPNAME" -e 's/startswith("mcp__") and endswith("__merge_pull_request")/. == "mcp__github__merge_pull_request"/'

# --- wrong builds the round-2 tip adversary found surviving, each dying on its own cell(s) ---
# 44. a background-task notification clears the re-write exemption (the measured wrong deny).
mutc notif-not-excluded "REDISPATCH" "REDISPATCH:rd-sys REDISPATCH:rd-task" -e 's/^def notif: .*$/def notif: false;/'
# 45. keyed on `isMeta`: the system form carries it, so does a real coordinator re-dispatch, and
#     the task form does not.
mutc notif-by-ismeta "REDISPATCH" "REDISPATCH:rd-meta REDISPATCH:rd-meta-adv REDISPATCH:rd-task" -e 's/^def notif: .*$/def notif: (.isMeta? == true);/'
# 46. keyed on the text anywhere in the line: a re-dispatch that mentions a notification is lost,
#     and the task form, whose text says it in lower case, is not excluded.
mutc notif-by-text "REDISPATCH" "REDISPATCH:rd-mid REDISPATCH:rd-task" -e 's/^def notif: .*$/def notif: ((.message.content? \/\/ "") | tostring | contains("NOTIFICATION"));/'
# 47/48. any origin read as a notification: a human or peer instruction no longer re-dispatches.
mutc notif-by-any-origin "REDISPATCH" "REDISPATCH:rd-human REDISPATCH:rd-peer" -e 's/^def notif: .*$/def notif: ((.origin.kind? \/\/ "") != "");/'
mutc notif-by-origin-object "REDISPATCH" "REDISPATCH:rd-human REDISPATCH:rd-peer" -e 's/^def notif: .*$/def notif: ((.origin? | type) == "object");/'
# 48. K: the review deliverables are not gated.
mutc K-no-reviews-path "MATEPATH" "MATEPATH:k-cr MATEPATH:k-qa" -e 's/test("\/docs\/reviews\/(\.+\/)?\[^\/\]\*(qa-validation|code-review)\[^\/\]\*\\\\.md\$")/false/'
# 49. K: the review shard directories are not gated.
mutc K-no-review-shards "MATEPATH" "MATEPATH:k-sh-cr MATEPATH:k-sh-qa" -e 's/test("\/docs\/reviews\/(\.+\/)?shards\/\[^\/\]\*(qa-validation|code-review)\[^\/\]\*\/\[^\/\]+\\\\.md\$")/false/'
# 50. L: a verdict shard part is not gated.
mutc L-no-part-jsonl "MATEPATH" "MATEPATH:l-part" -e 's/verdict\\\\.json|part-\[^\/\]+\\\\.jsonl|repair/verdict\\\\.json|repair/'
# 51. A: the envelope matched as an unanchored regex, so a push that ran and printed it is erased.
mutc A-envelope-unanchored-regex "ENVELOPE" "ENVELOPE:a-midline" -e 's/| test("^PreToolUse:\[A-Za-z_\]+ hook error: ai-dlc-advisor-gate: DENIED")/| test("PreToolUse:[A-Za-z_]+ hook error: ai-dlc-advisor-gate: DENIED")/'
# 52-55. B and C: one lead-kind pair collapsed into one kind.
mutc B-collapse-gatelog-push "PERKIND" "PERKIND:pk-push-gatelog" -e 's/(\[\.g\[\] | select(\.\[2\] == \$kind) | \.\[0\]\] | max \/\/ 0) as \$act/([.g[] | select(.[2] == $kind or ((.[2] == "gatelog" or .[2] == "push") and ($kind == "gatelog" or $kind == "push"))) | .[0]] | max \/\/ 0) as $act/'
mutc B-collapse-close-push "PERKIND" "PERKIND:pk-push-close" -e 's/(\[\.g\[\] | select(\.\[2\] == \$kind) | \.\[0\]\] | max \/\/ 0) as \$act/([.g[] | select(.[2] == $kind or ((.[2] == "close" or .[2] == "push") and ($kind == "close" or $kind == "push"))) | .[0]] | max \/\/ 0) as $act/'
mutc C-collapse-close-merge "PERKIND" "PERKIND:pk-merge-close" -e 's/(\[\.g\[\] | select(\.\[2\] == \$kind) | \.\[0\]\] | max \/\/ 0) as \$act/([.g[] | select(.[2] == $kind or ((.[2] == "close" or .[2] == "merge") and ($kind == "close" or $kind == "merge"))) | .[0]] | max \/\/ 0) as $act/'
mutc C-collapse-gatelog-merge "PERKIND" "PERKIND:pk-merge-gatelog" -e 's/(\[\.g\[\] | select(\.\[2\] == \$kind) | \.\[0\]\] | max \/\/ 0) as \$act/([.g[] | select(.[2] == $kind or ((.[2] == "gatelog" or .[2] == "merge") and ($kind == "gatelog" or $kind == "merge"))) | .[0]] | max \/\/ 0) as $act/'
# 56. F: the wrapper strip loop bounded at four.
mutc F-strip-depth4 "STACK" "STACK:f-five" -e 's/^def strip: (sub(wrapre; "") | sub(envre; "")) as \$n$/def strip1: (sub(wrapre; "") | sub(envre; "")) as $n/' -e 's/^  | if \$n != \. then (\$n | strip) elif test(bashc) then (sub(bashc; "") | strip) else \. end;$/  | if $n != . then $n elif test(bashc) then sub(bashc; "") else . end; def strip: strip1 | strip1 | strip1 | strip1;/'
# 57. H: any result opening with the envelope removes the call, error or not.
mutc H-denied-ignores-iserror "DENIED" "DENIED:h-noerr" -e 's/elif (\$b\.type == "tool_result" and \$b\.is_error == true/elif ($b.type == "tool_result"/'
# 58. I: a `tee` onto gate-log.md is not a Check 12 append.
mutc I-no-tee-gatelog "GATELOG" "GATELOG:i-tee" -e 's/+ \[\$s\[\] | words | select(length > 0 and \.\[0\] == "tee") | \.\[1:\]\[\]\]//'
# 59. J: a MultiEdit onto gate-log.md is not a Check 12 append.
mutc J-no-multiedit-gatelog "GATELOG" "GATELOG:j-multi" -e 's/(if (\[\.input\.edits\[\]? | ((\.new_string \/\/ "") | tostring | heads) - ((\.old_string \/\/ "") | tostring | heads)\]/(if ([0]/'


# Every mutant dealt to this shard must have RUN, and every one that ran must have died exactly.
[ "$n_seen" -eq "$nmine" ] || bad "[J1] shard '$GROUP' reached $n_seen mutants, $nmine dealt -- a dealt mutant never ran"
[ "$n_mut" -gt 0 ] && [ "$n_kill" -eq "$n_mut" ] && [ "$n_mut" -eq "$nmine" ] \
  && ok "$n_kill of $nmine mutants dealt to shard '$GROUP' killed" \
  || bad "$n_kill of $n_mut mutants scored ($nmine dealt) in shard '$GROUP' killed"

echo
if [ "$fails" -eq 0 ]; then echo "$NAME: PASS"; exit 0; fi
echo "$NAME: $fails assertion(s) FAILED" >&2
exit 1
