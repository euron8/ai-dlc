#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
# content-seal/unit-arms.sh -- the content seal's LIBRARY decisions, asked IN PROCESS. Driven by run.sh.
#
# content-seal.sh is sourced once (its BASH_SOURCE guard keeps seal_main from running), and every cell calls
# the function a reader's mode calls: seal_check (--check), seal_row (--row), seal_last_tool_row
# (--last-tool-row), seal_record (--record), seal_admit_marker (--admit-marker), _seal_remedy. The recorder
# hook is SOURCED in a subshell fed its PostToolUse payload on stdin, so every seal row still comes from the
# real recorder and never from a hand-written row. What a READER does with an answer -- the merge's refusal,
# the join's, --merge's -- stays end to end in merge-arms.sh, join-arms.sh and gate-arms.sh, one run per
# distinct outcome (.claude/rules/fixture-mutants.md clauses 5 and 6).
#
# The admission mutants A3 and A4 edit content-seal.sh only, so they are scored here: the mutated library is
# sourced in a subshell and asked the same seal_admit_marker question over the same world. `--matrix` prints
# the full mutant x world matrix for them and stops (run.sh header MUTANT-MATRIX).
#
# Exit: 0 every cell passed, 1 a cell failed, 2 the fixture could not run.
set -u
NAME="content-seal-unit"
CS_HERE="$(cd "$(dirname "$0")" && pwd)"
broken() { echo "FIXTURE BROKEN: $NAME: $1" >&2; exit 2; }
# The library, the recorder and the shipped adversary role file, found by walking UP in both layouts.
SEAL=""; SEALHOOK=""; ROLE_CUR=""; _d="$CS_HERE"
while [ -n "$_d" ] && [ "$_d" != "/" ]; do
  if [ -f "$_d/core/scripts/content-seal.sh" ]; then
    SEAL="$_d/core/scripts/content-seal.sh"; SEALHOOK="$_d/core/hooks/ai-dlc-content-seal.sh"; ROLE_CUR="$_d/core/team-roles/adversary.md"; break
  elif [ -f "$_d/scripts/ai-dlc/content-seal.sh" ]; then
    SEAL="$_d/scripts/ai-dlc/content-seal.sh"; SEALHOOK="$_d/.claude/hooks/ai-dlc-content-seal.sh"; ROLE_CUR="$_d/.claude/team-roles/adversary.md"; break
  fi
  _d="$(dirname "$_d")"
done
[ -n "$SEAL" ] && [ -f "$SEALHOOK" ] && [ -f "$ROLE_CUR" ] || broken "content-seal.sh, its recorder or adversary.md not found above $CS_HERE in either layout; nothing was asserted"
command -v jq >/dev/null 2>&1 && command -v perl >/dev/null 2>&1 || broken "jq or perl absent"
# shellcheck source=/dev/null
. "$SEAL" || broken "sourcing $SEAL failed"
declare -F seal_check >/dev/null && declare -F seal_admit_marker >/dev/null \
  || broken "$SEAL defined no seal_check/seal_admit_marker when sourced"
# The precondition the CURRENT cells rest on: the shipped file instructs --mark and carries no fallback.
if ! grep -qF 'wait-for-deliverable.sh --mark ' "$ROLE_CUR" || grep -qF 'unknown arg: --mark' "$ROLE_CUR"; then
  broken "$ROLE_CUR is not in the CURRENT state (--mark instruction, no fallback); the admission cells have no subject"
fi
WORK="$(mktemp -d "${TMPDIR:-/tmp}/$NAME.XXXXXX")" || exit 2
trap 'rm -rf "$WORK"' EXIT
fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails + 1)); }
. "$CS_HERE/../lib/mutant.sh"
MX=0; [ "${1:-}" = --matrix ] && MX=1
US="$(printf '\037')"
TOKEN="changed after its last sealed write"
REMEDY="never amend a join input through Bash"

# uworld [current|legacy|none] -> UW (root), UST (state dir), UD (shard dir), UL (ledger): four adversary-shaped
# shards, the world's own copy of the library at the consumer spelling the recorder sources, and the role file.
uworld() {
  local k
  UW="$(mktemp -d "$WORK/u.XXXXXX")" || broken "cannot make a world"
  UST="$UW/_bmad-output"; UD="$UST/planning-artifacts/s1/shards/stories-p1"; UL="$UST/planning-artifacts/.artifact-writes.jsonl"
  mkdir -p "$UD" "$UW/scripts/ai-dlc" "$UW/.claude/team-roles" && cp "$SEAL" "$UW/scripts/ai-dlc/content-seal.sh" || broken "cannot seed $UW"
  for k in 1 2 3 4; do
    printf '# stories -- adversarial shard %s\n\n## Findings\n\ntool_use_id: NOT_ACCESSIBLE\n\n## Probed and found sound\n\nNothing further.\n' "$k" > "$UD/$k.md"
  done
  case "${1:-none}" in
    current) cp "$ROLE_CUR" "$UW/.claude/team-roles/adversary.md" ;;
    legacy) printf 'Close the shard with `scripts/ai-dlc/wait-for-deliverable.sh --mark <shard path> <step> adversary <shard> findings=<n>`.\nIf that call fails with `unknown arg: --mark`, append the bare line instead.\n' \
              > "$UW/.claude/team-roles/adversary.md" ;;
  esac
}
# rec <root> <tool> <file> <agent id or ""> -- the REAL recorder, sourced in a subshell with the PostToolUse
# payload a Write or Edit produces on stdin. An empty agent id is the top-level session's payload, which
# carries no agent_id key at all. Its `exit 0` ends the subshell, never this script.
rec() {
  local a=""
  [ -n "$4" ] && a=",\"agent_id\":\"$4\",\"agent_type\":\"fixture\""
  ( CLAUDE_PROJECT_DIR="$1"; . "$SEALHOOK" ) > /dev/null 2>&1 <<EOF
{"session_id":"fx-session","hook_event_name":"PostToolUse","tool_name":"$2","tool_input":{"file_path":"$3"},"tool_use_id":"toolu_01FxSealWrite","transcript_path":"$1/.harness/fx-session.jsonl","tool_response":{}$a}
EOF
}
seal_all() { local k; for k in 1 2 3 4; do rec "$UW" Write "$UD/$k.md" "a000000000000001$k"; done; }
nrows() { NR_=0; [ -f "$UL" ] && { NR_="$(grep -c '"kind":"content-seal"' "$UL")" || NR_=0; }; }
chk() { seal_check "$UST" "$@" > "$WORK/chk.out" 2>&1; RC=$?; }
says() { grep -qF -- "$1" "${2:-$WORK/chk.out}"; }
ltr() { # <file> -> LA LAID LT: the last TOOL seal row seal_last_tool_row reports for it, empty when none
  LA=""; LAID=""; LT=""
  seal_last_tool_row "$UST" "$1" > "$WORK/ltr.out" 2>&1
  IFS="$US" read -r _ LA LAID LT _ < "$WORK/ltr.out" || :
}
ss_edit() { # <file> <agent id or ""> -- an Edit that moves the bytes, sealed by the real recorder
  perl -0pi -e 's/Nothing further\./Nothing further, amended./' "$1"
  grep -q 'Nothing further, amended' "$1" || broken "ss_edit changed nothing in $1"
  rec "$UW" Edit "$1" "$2"
}

# WORLDS ARE BUILT ONCE AND COPIED. Two templates are built through uworld and the REAL recorder: TPL_U (four
# unsealed shards) and TPL_S (the same, every shard sealed by its adversary). uclone copies one to a fresh root and
# relocates the root every ledger row records (rows name the PHYSICAL root and the transcript path as spelled, and
# --check skips a row whose root is another tree). The relocation is held by two controls below (CS-U-W0): a
# relocated copy is compared against, and a copy left unrelocated stops comparing.
uvars() { UST="$UW/_bmad-output"; UD="$UST/planning-artifacts/s1/shards/stories-p1"; UL="$UST/planning-artifacts/.artifact-writes.jsonl"; }
uclone() { # <template root> [current|legacy|none] -> UW UST UD UL
  local t="$1" op ol np nl
  UW="$(mktemp -d "$WORK/u.XXXXXX")" || broken "cannot make a world"
  cp -Rp "$t/." "$UW/" || broken "cannot copy $t"
  uvars
  if [ -f "$UL" ]; then
    op="$(cd "$t" && pwd -P)"; np="$(cd "$UW" && pwd -P)"
    sed -e "s|$op|$np|g" -e "s|$t|$UW|g" "$UL" > "$UL.new" && cat "$UL.new" > "$UL" && rm -f "$UL.new" || broken "cannot relocate $UL"
  fi
  rm -f "$UW/.claude/team-roles/adversary.md"
  case "${2:-none}" in
    current) cp "$ROLE_CUR" "$UW/.claude/team-roles/adversary.md" ;;
    legacy) printf 'Close the shard with `scripts/ai-dlc/wait-for-deliverable.sh --mark <shard path> <step> adversary <shard> findings=<n>`.\nIf that call fails with `unknown arg: --mark`, append the bare line instead.\n' \
              > "$UW/.claude/team-roles/adversary.md" ;;
  esac
}
uworld; TPL_U="$UW"
uworld; seal_all; TPL_S="$UW"

echo "$NAME:"

# CS-U-W0: the copy is a sound stand-in for a freshly sealed world. A relocated copy of TPL_S passes --check and
# reports a Bash amendment (rows still compared); the same copy WITHOUT the relocation compares nothing, so the
# amendment goes unreported, which is exactly why the relocation is there. The two differ.
uclone "$TPL_S"; printf '\nlate line\n' >> "$UD/1.md"; chk "$UD/1.md"; w_rel="$RC"; says "$UD/1.md $TOKEN" && w_tok=1 || w_tok=0
UW="$(mktemp -d "$WORK/u.XXXXXX")"; cp -Rp "$TPL_S/." "$UW/"; uvars; printf '\nlate line\n' >> "$UD/1.md"; chk "$UD/1.md"; w_raw="$RC"
if [ "$w_rel" = 1 ] && [ "$w_tok" = 1 ] && [ "$w_raw" = 0 ]; then ok "CS-U-W0: a relocated copy of the sealed template still compares its rows (Bash amendment reported); the unrelocated copy compares none"
else bad "CS-U-W0: relocated copy rc=$w_rel (want 1, token=$w_tok), unrelocated copy rc=$w_raw (want 0)"; fi

# CS-U-M1 and CS-U-M2 (a sealed untouched set passes; perl -0pi after the seal is reported) are the library half of
# merge-arms.sh CS-M1 and CS-M2, which drive the same worlds through the merge, so they are not asked twice here.

# CS-U-M3: a top-level SESSION Write (no agent_id) then printf >> -> reported, naming the session. The session's
# row carries an EMPTY agent_id: this is the cell a seal read filtering agent_id != "" would pass.
uclone "$TPL_U"; rec "$UW" Write "$UD/3.md" ""; printf '\nlate line\n' >> "$UD/3.md"; chk "$UD"/*.md
if [ "$RC" = 1 ] && says "$UD/3.md $TOKEN" && says "the top-level session, which carries no agent_id (Write)"; then
  ok "CS-U-M3: a session Write then printf >>: reported, naming the top-level session as the sealed writer"
else bad "CS-U-M3: a session Write then printf >> was not reported (rc=$RC): $(head -2 "$WORK/chk.out")"; fi
# CS-U-M3b, its ALLOW twin one property apart: the same session seal, the adversary's Edit last, no append.
uclone "$TPL_U"; rec "$UW" Write "$UD/3.md" ""; rec "$UW" Edit "$UD/3.md" a0000000000000013; chk "$UD"/*.md
if [ "$RC" = 0 ] && grep -q '"actor":"session"' "$UL"; then ok "CS-U-M3b: the same session seal, untouched, its adversary's Edit last: --check passes"
else bad "CS-U-M3b: a session-sealed untouched shard did not pass (rc=$RC): $(head -2 "$WORK/chk.out")"; fi

# CS-U-S1: the LAST TOOL WRITE the merge's BL-669 refusal reads. (a) adversary Write, session Edit -> the
# session's Edit, while --check passes (the bytes were re-sealed, which is why the actor rule exists);
# (b) the adversary's own Edit -> agent; (c) session Edit then a program row -> still the session (program rows
# skipped); (d) session Edit then the adversary's later Write -> agent.
s1=""
uclone "$TPL_S"; ss_edit "$UD/2.md" ""; ltr "$UD/2.md"; chk "$UD/2.md"
[ "$LA|$LT" = "session|Edit" ] && [ "$RC" = 0 ] || s1="${s1}a[$LA|$LT rc=$RC] "
uclone "$TPL_S"; ss_edit "$UD/2.md" a0000000000000012; ltr "$UD/2.md"
[ "$LA|$LAID|$LT" = "agent|a0000000000000012|Edit" ] || s1="${s1}b[$LA|$LAID|$LT] "
uclone "$TPL_S"; ss_edit "$UD/2.md" ""; seal_record "$UST" program:wait-for-deliverable "$UD/2.md"; ltr "$UD/2.md"
{ grep -qF '"actor":"program:wait-for-deliverable"' "$UL" && [ "$LA" = session ]; } || s1="${s1}c[$LA] "
uclone "$TPL_S"; ss_edit "$UD/2.md" ""; rec "$UW" Write "$UD/2.md" a0000000000000012; ltr "$UD/2.md"
[ "$LA|$LT" = "agent|Write" ] || s1="${s1}d[$LA|$LT] "
if [ -z "$s1" ]; then ok "CS-U-S1: last tool row: session Edit over an adversary Write -> session (bytes still pass --check); the adversary's own Edit -> agent; a later program row -> still session; the adversary's later Write -> agent"
else bad "CS-U-S1: cases did not hold: $s1"; fi

# CS-U-L1: --last-tool-row over several files. Agent Write, session Edit, program row -> the session's Edit;
# a shard whose program row came last -> its agent Write; a tree with no seal row -> nothing.
uclone "$TPL_S"; ss_edit "$UD/1.md" ""; seal_record "$UST" program:wait-for-deliverable "$UD/1.md" "$UD/3.md"
seal_last_tool_row "$UST" "$UD/1.md" "$UD/3.md" > "$WORK/l1.out" 2>&1; cl=$?
l1="$(awk -F "$US" -v f="$UD/1.md" '$1 == f { print $2 "|" $3 "|" $4 }' "$WORK/l1.out")"
l3="$(awk -F "$US" -v f="$UD/3.md" '$1 == f { print $2 "|" $3 "|" $4 }' "$WORK/l1.out")"
dn="$WORK/ltrn/_bmad-output"; mkdir -p "$dn/planning-artifacts/s1/shards/stories-p1"; printf 'x\n' > "$dn/planning-artifacts/s1/shards/stories-p1/1.md"
seal_last_tool_row "$dn" "$dn/planning-artifacts/s1/shards/stories-p1/1.md" > "$WORK/ltrn.out" 2>&1; cn=$?
if [ "$cl" = 0 ] && [ "$l1" = "session||Edit" ] && [ "$l3" = "agent|a0000000000000013|Write" ] && [ "$cn" = 0 ] && [ ! -s "$WORK/ltrn.out" ]; then
  ok "CS-U-L1: last tool rows: the session's Edit behind a later program row, the agent's Write behind a program row, nothing where no seal row exists"
else bad "CS-U-L1: rc=$cl, 1.md [$l1] (want session||Edit), 3.md [$l3] (want agent|a0000000000000013|Write), unsealed rc=$cn [$(head -1 "$WORK/ltrn.out")]"; fi

# CS-U-M4: an Edit rewrite re-seals: the newest row is the Edit's and --check passes.
uclone "$TPL_S"
perl -0pi -e 's/Nothing further\./Nothing further, re-read after the first pass./' "$UD/1.md"
rec "$UW" Edit "$UD/1.md" a0000000000000011
seal_row "$UST" "$UD/1.md" > "$WORK/row.out" 2>&1; chk "$UD/1.md"
if [ "$RC" = 0 ] && says '"tool":"Edit"' "$WORK/row.out" && says 'a0000000000000011' "$WORK/row.out"; then ok "CS-U-M4: an Edit rewrite after the Write seal re-seals: the newest row is the Edit's, --check passes"
else bad "CS-U-M4: an Edit rewrite did not re-seal (rc=$RC, newest row: $(head -c 300 "$WORK/row.out"))"; fi

# CS-U-M5: a NEAR-MISS path chosen by asking the declaration (seal_sealed), never by restating it: a file
# directly under shards/, which passes the recorder's `/shards/` pre-filter and sits in no shard directory.
uclone "$TPL_S"; nm="$UST/planning-artifacts/s1/shards/README.md"; printf '# shard index\n' > "$nm"
if seal_sealed "planning-artifacts/s1/shards/README.md"; then bad "CS-U-M5: FIXTURE BROKEN -- the declaration now seals the near-miss; choose one it does not"
else
  nrows; b5="$NR_"; rec "$UW" Write "$nm" ""; nrows; a5="$NR_"; printf 'amended by Bash\n' >> "$nm"; chk "$nm"
  if [ "$b5" = 4 ] && [ "$a5" = 4 ] && [ "$RC" = 0 ]; then ok "CS-U-M5: near-miss shards/README.md (outside the declared set): the recorder writes no row, a Bash rewrite passes --check"
  else bad "CS-U-M5: near-miss: rows $b5 -> $a5 (want 4 -> 4), --check rc=$RC"; fi
fi

# CS-U-M6: the SUFFIX-LESS shard dir stories-elicitation/ (requirements-elicitation/ is merge-arms.sh CS-M6, end to end,
# so it is not asked twice here): a sealed shard rewritten by sed -i is reported; its untouched twin passes.
m6=""
for e in stories-elicitation; do
  uclone "$TPL_U"; ed="$UST/planning-artifacts/s9/shards/$e"; mkdir -p "$ed"
  printf 'Body.\n' > "$ed/01.md"; printf 'Body.\n' > "$ed/02.md"
  rec "$UW" Write "$ed/01.md" a0000000000000061; rec "$UW" Write "$ed/02.md" a0000000000000062
  sed -i.bak 's/^Body\.$/Body, amended by the lead./' "$ed/01.md" && rm -f "$ed/01.md.bak"
  chk "$ed/01.md"; r1="$RC"; says "$ed/01.md $TOKEN" || r1="$r1-no-token"
  chk "$ed/02.md"; [ "$r1|$RC" = "1|0" ] || m6="$m6 $e[rewritten=$r1 twin=$RC]"
done
if [ -z "$m6" ]; then ok "CS-U-M6: stories-elicitation/: a sealed shard rewritten by an in-place sed is reported; its untouched twin passes"
else bad "CS-U-M6:$m6"; fi

# CS-U-K5: a shard whose newest row is the --mark program row, amended through Bash -> reported, naming the
# program and the restore-then-mark remedy (no second marker stacked).
uclone "$TPL_S"; seal_record "$UST" program:wait-for-deliverable "$UD/1.md"; printf 'a line after the mark\n' >> "$UD/1.md"; chk "$UD/1.md"
if [ "$RC" = 1 ] && says "$UD/1.md $TOKEN" && says "program wait-for-deliverable" && says "restore the bytes with Edit, then re-run wait-for-deliverable.sh --mark"; then
  ok "CS-U-K5: a program-sealed shard amended through Bash: reported, naming program wait-for-deliverable and the restore-then-mark remedy"
else bad "CS-U-K5: a program-sealed shard amended through Bash was not reported with the --mark remedy (rc=$RC): $(head -2 "$WORK/chk.out")"; fi

# CS-U-K6: a SYMLINKED state dir. Rows are named by the state dir AS SPELLED; --record through the link and
# --check through the link agree on that name.
uclone "$TPL_U"; mv "$UST" "$UW/real-out" && ln -s real-out "$UST" || broken "CS-U-K6 cannot link the state dir"
[ -L "$UST" ] && [ "$(cd "$UST" && pwd -P)" != "$(cd "$UST" && pwd)" ] || broken "CS-U-K6: $UST is not a link to a differently named dir"
seal_all; seal_record "$UST" program:wait-for-deliverable "$UD"/*.md; chk "$UD"/*.md
np="$(grep -c '"actor":"program:wait-for-deliverable".*"path":"_bmad-output/\|"path":"_bmad-output/[^"]*","actor":"program:wait-for-deliverable"' "$UL")" || np=0
if [ "$RC" = 0 ] && [ "$np" = 4 ]; then ok "CS-U-K6: through a symlinked _bmad-output, program rows are named by the spelled state dir (4) and --check passes"
else bad "CS-U-K6: through a symlinked state dir: --check rc=$RC, program rows under the spelled name $np (want 4)"; fi

# ---- THE MARKER ADMISSION (content-seal.sh header "THE MARKER ADMISSION"), one world per distinct state:
#   dA CURRENT role, bare markers      dN NO role file, bare markers     dL LEGACY role, bare markers
#   dD CURRENT role, bare markers, then sealed     dLs LEGACY role, bare markers, then sealed
#   dE CURRENT role, sealed, sha= markers, program rows (as --mark leaves it)
#   dF CURRENT role, sha= markers, no seal row, one body changed through Bash
bare_marks() { local k; for k in 1 2 3 4; do printf '\nseat-complete: stories adversary %s findings=0\n' "$k" >> "$UD/$k.md"; done; }
sha_marks() { # the marker --mark appends: directly after the body, sha= the body's digest
  local k h
  for k in 1 2 3 4; do
    h="$(seal_body_sha "$UD/$k.md" 1)"; [ -n "$h" ] || broken "no body digest for $UD/$k.md"
    printf 'seat-complete: stories adversary %s findings=0 sha=%s\n' "$k" "$h" >> "$UD/$k.md"
  done
}
uclone "$TPL_U" current; bare_marks; dA="$UD"
uclone "$TPL_U" none; bare_marks; dN="$UD"
uclone "$TPL_U" legacy; bare_marks; dL="$UD"
uclone "$TPL_U" current; bare_marks; seal_all; dD="$UD"; dDst="$UST"
uclone "$TPL_U" legacy; bare_marks; seal_all; dLs="$UD"
uclone "$TPL_S" current; sha_marks; seal_record "$UST" program:wait-for-deliverable "$UD"/*.md; dE="$UD"
uclone "$TPL_U" current; sha_marks; perl -0pi -e 's/Nothing further\./Nothing further, after the mark./' "$UD/1.md"; dF="$UD"
adm() { # <shard dir> [mutated library] -> ARC, $WORK/adm.out: seal_admit_marker over every shard in it
  if [ -n "${2:-}" ]; then ( . "$2"; seal_admit_marker "$1"/*.md ) > "$WORK/adm.out" 2>&1
  else seal_admit_marker "$1"/*.md > "$WORK/adm.out" 2>&1; fi
  ARC=$?
}
for w in dA dN dL dD dLs dE dF; do eval "adm \"\$$w\""; eval "SV_$w=$ARC"; cp "$WORK/adm.out" "$WORK/adm.$w"; done
a1=""
{ [ "$SV_dA" = 1 ] && says "the legacy window is closed" "$WORK/adm.dA"; } || a1="${a1}a "
{ [ "$SV_dN" = 1 ] && says "no readable role file for seat 'adversary'" "$WORK/adm.dN"; } || a1="${a1}b "
{ [ "$SV_dL" = 0 ] && [ ! -s "$WORK/adm.dL" ]; } || a1="${a1}c "
chk_d=0; seal_check "$dDst" "$dD"/*.md > /dev/null 2>&1 || chk_d=$?
{ [ "$SV_dD" = 1 ] && [ "$chk_d" = 0 ] && says "the legacy window is closed" "$WORK/adm.dD"; } || a1="${a1}d "
{ [ "$SV_dE" = 0 ] && [ ! -s "$WORK/adm.dE" ]; } || a1="${a1}e "
{ [ "$SV_dF" = 1 ] && says "is not the body above it" "$WORK/adm.dF"; } || a1="${a1}f "
{ [ "$SV_dLs" = 0 ]; } || a1="${a1}Ls "
if [ -z "$a1" ]; then
  s_a=1; s_b=1; s_c=1
  ok "CS-U-A1: admission: bare markers under CURRENT -> refused; NO role file -> refused; LEGACY -> admitted; bare then sealed under CURRENT -> refused while --check passes; a sealed sha= set -> admitted; a broken sha= digest -> refused; LEGACY sealed -> admitted"
else
  s_a=0; s_b=0; s_c=0
  bad "CS-U-A1: cases [$a1] did not hold: a[$(head -1 "$WORK/adm.dA")] b[$(head -1 "$WORK/adm.dN")] c[$(head -1 "$WORK/adm.dL")] d[$(head -1 "$WORK/adm.dD") chk=$chk_d] f[$(head -1 "$WORK/adm.dF")]"
fi

# ---- the admission MUTANTS, each a copy of content-seal.sh with one anchor applied exactly once. A3 lets a
# missing role file acquit; A4 stops reading the fallback sentence, so a LEGACY role file reads as CURRENT.
mut_lib() { # <id> <old> <new> -> MUTP, empty when the anchor is not in content-seal.sh exactly once
  local m="$WORK/mut-$1.sh" n
  MUTP=""
  n="$(OLD="$2" awk 'BEGIN { o = ENVIRON["OLD"] } { s = $0; while ((i = index(s, o)) > 0) { n++; s = substr(s, i + length(o)) } } END { print n + 0 }' "$SEAL")"
  [ "$n" = 1 ] || return 0
  OLD="$2" NEW="$3" awk 'BEGIN { o = ENVIRON["OLD"]; w = ENVIRON["NEW"] } { i = index($0, o); if (i > 0) $0 = substr($0, 1, i - 1) w substr($0, i + length(o)); print }' \
    "$SEAL" > "$m" && ! cmp -s "$SEAL" "$m" || return 0
  MUTP="$m"
}
n0="$(OLD='NO-SUCH-ANCHOR-BL750-ADMIT' awk 'BEGIN { o = ENVIRON["OLD"] } { if (index($0, o)) n++ } END { print n + 0 }' "$SEAL")"
mut_lib A3 'if [ -z "$rf" ] || [ ! -r "$rf" ]; then' 'if false; then'; mA3="$MUTP"
mut_lib A4 "grep -qF -- 'unknown arg: --mark' \"\$rf\" && continue" ':'; mA4="$MUTP"
cell() { # <mutated library> <world name> -> KILL yes|no: the mutant's admission verdict against the shipped one
  local sv; eval "adm \"\$$2\" \"\$1\""; eval "sv=\$SV_$2"
  if [ "$ARC" != "$sv" ]; then KILL=yes; else KILL=no; fi
}
if [ "$MX" = 1 ]; then
  for _mm in A3 A4; do
    eval "_mp=\$m$_mm"; [ -n "$_mp" ] || { echo "MATRIX $_mm DID-NOT-APPLY"; exit 2; }
    _trip=""
    for _mw in dA dN dL dD dLs dE dF; do
      cell "$_mp" "$_mw"; eval "_sh=\$SV_$_mw"; echo "MATRIX $_mm $_mw shipped=$_sh mutant=$ARC killed=$KILL"
      [ "$KILL" = yes ] && _trip="$_trip $_mw"
    done
    echo "MATRIX-ROW $_mm tripped=[${_trip# }]"
  done
  exit 0
fi
if [ "$n0" != 0 ]; then bad "CS-U-A3/A4: FIXTURE BROKEN -- the impossible anchor control matched $n0 line(s)"
else
  if [ -z "$mA4" ]; then bad "CS-U-A4: DID NOT APPLY -- the fallback-sentence anchor is not in content-seal.sh exactly once"
  else
    cell "$mA4" dL; d_k=$KILL; d_v=$ARC; d_r="$(head -1 "$WORK/adm.out")"; cell "$mA4" dA; t_k=$KILL
    if [ "$d_k" = yes ] && [ "$d_v" = 1 ] && case "$d_r" in *"legacy window is closed"*) true ;; *) false ;; esac && [ "$t_k" = no ]; then
      mutant_killed "$([ "$s_a" = 1 ] && [ "$s_c" = 1 ] && echo 1)" A4 "CS-U-A4: killed -- a LEGACY role file read as CURRENT is refused at (c) (dL); twin (a) (dA) stays refused for the same reason"
    else bad "CS-U-A4: the fallback-sentence mutant did not die at (c) with (a) unchanged: (c) killed=$d_k rc=$d_v [$d_r], (a) killed=$t_k"; fi
  fi
  if [ -z "$mA3" ]; then bad "CS-U-A3: DID NOT APPLY -- the missing-role refusal anchor is not in content-seal.sh exactly once"
  else
    cell "$mA3" dN; d_k=$KILL; d_v=$ARC; cell "$mA3" dA; t_k=$KILL
    if [ "$d_k" = yes ] && [ "$d_v" = 0 ] && [ "$t_k" = no ]; then
      mutant_killed "$([ "$s_a" = 1 ] && [ "$s_b" = 1 ] && echo 1)" A3 "CS-U-A3: killed -- a missing role file acquits at (b) (dN); twin (a) (dA) stays refused"
    else bad "CS-U-A3: the missing-role mutant did not die at (b) with (a) unchanged: (b) killed=$d_k rc=$d_v, (a) killed=$t_k"; fi
  fi
fi

# CS-U-R1: the remedy for an adversary shard is the re-dispatch + --rerun one; a remediator part and a
# non-shard sealed path keep the generic text.
RD="re-dispatch the adversary for that shard, then merge with merge-adversarial-shards.sh --rerun"
r_shard="$(_seal_remedy "" planning-artifacts/s1/shards/stories-p1/2.md)"
r_part="$(_seal_remedy "" planning-artifacts/s1/shards/stories-repair-p1/1.md)"
r_other="$(_seal_remedy "" planning-artifacts/s1/stories/a.md)"
case "$r_shard" in "$RD"*) rs=1 ;; *) rs=0 ;; esac
case "$r_part$r_other" in *"$RD"*) rg=0 ;; *) rg=1 ;; esac
case "$r_part" in *"$REMEDY"*) rp=1 ;; *) rp=0 ;; esac
case "$r_other" in "restore the file with Write or Edit"*"$REMEDY") ro=1 ;; *) ro=0 ;; esac
if [ "$rs" = 1 ] && [ "$rg" = 1 ] && [ "$rp" = 1 ] && [ "$ro" = 1 ]; then ok "CS-U-R1: an adversary-shard path gets the re-dispatch and --rerun remedy; a remediator part and a non-shard sealed path keep the generic text"
else bad "CS-U-R1: remedy text wrong (shard=$rs generic-clean=$rg part=$rp other=$ro): $r_shard | $r_other"; fi

echo "$NAME: $fails failure(s)"
[ "$fails" -eq 0 ]
