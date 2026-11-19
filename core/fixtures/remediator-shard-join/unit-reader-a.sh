#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
# remediator-shard-join/unit-reader-a.sh -- the reader-level cells of half A, asked IN PROCESS. Driven by run.sh;
# the header block is run.sh's.
#
# Families: SJ1-SJ9 and SJ1o; EC14 EC18 EC19 EC25 EC32 EC36 EC37 EC38; RR1-RR20; AL1-AL9; NW1-NW2; LN1-LN8 and LN10-LN16;
# LP1-LP5; NL1-NL8c. Each cell asserts the decision its end-to-end cell in
# run.sh asserted, through the SAME lib.sh predicate, unchanged. What changes is how a predicate's `bash <subject>`
# runs: the `bash` function below catches the two subjects by path and runs each in a subshell of this process --
#   the join                 join_main, the join sourced ONCE here
#   a join copy              join_main of the copy: SJ1o scores each copy inside ONE subshell that sourced it once
#                            (ua_oldsib)
#   the remediation guard    hook_pretool_head, the hook sourced in the subshell of each drive:
#                            its top level binds CLAUDE_PROJECT_DIR, AI_DLC_STATE_DIR and TIMESTAMP (through `date`,
#                            which the drive's shim pins) per call, so it cannot be sourced once
# -- and every other program, and every program a subject itself starts, as a child, exactly as before. The subshell
# first reduces its names to what a CLI child starts with (ua_scrub): the exported environment, a VAR=x prefix
# included, plus the join's own measured top-level names; `set +o pipefail`, which lib.sh sets and no subject does;
# and LC_ALL as the subject itself sets it (the join exports C, the hook inherits the caller's).
#
# WORLDS BUILT ONCE. Each hook-written world builder used more than once (g6_world, r5_world, nl_world, subj_world,
# doc_world) builds its world once per key and restores a byte copy AT THE SAME PATH for every later call: the
# ledger's root and transcript_path and the split manifests are absolute. three_writers appends a template's three
# hook rows with root rewritten. SEAM-A-TPL holds a restored world equal to a freshly built one.
#
# WHAT A SUBSHELL CANNOT REPRODUCE: hook_pretool_head is arms 0-2 only. A LEAD payload falls past arm 2 here where
# the CLI runs later arms; no cell here drives one, and LEAD-A fails if any drive did.
# SEAM-A cells hold each in-process route byte-identical to the CLI on one passing and one refusing input. CLI-A
# cells keep ONE end-to-end pass and refusal per join mode this half owns (clause 6): UA_CLI=1 in front of the same
# predicate runs every subject as a child.
#
# Exit: 0 every cell passed, 1 a cell failed, 2 the fixture could not run (or UA_ONLY ran a subset).
set -u
NAME="remediator-shard-join-reader-a"
UA_HERE="$(cd "$(dirname "$0")" && pwd)"
[ -f "$UA_HERE/lib.sh" ] || { echo "FIXTURE BROKEN: lib.sh is absent beside $0; nothing was asserted" >&2; exit 2; }
# shellcheck source=/dev/null
. "$UA_HERE/lib.sh" > /dev/null || { echo "FIXTURE BROKEN: sourcing lib.sh failed" >&2; exit 2; }
MUT_LIB="$(cd "$HERE/../lib" 2>/dev/null && pwd)/mutant.sh"
[ -f "$MUT_LIB" ] || { echo "FIXTURE BROKEN: lib/mutant.sh not found beside $HERE" >&2; exit 2; }
# shellcheck source=/dev/null
. "$MUT_LIB"
# each in-process pass of a subject below is logged by fx_inproc (lib/mutant.sh) under its root-relative path
RSJ_J=core/scripts/join-remediator-shards.sh; RSJ_H=core/hooks/ai-dlc-gate-remediation-guard.sh
# UA_ONLY=<group ...> runs a subset while a cell is developed; such a run never exits 0.
ua_on() { [ -z "${UA_ONLY:-}" ] && return 0; case " $UA_ONLY " in *" $1 "*) return 0 ;; esac; return 1; }

# ------------------------------------------------------------------------- the in-process route
UA_LC0="${LC_ALL-}"; UA_LCSET="${LC_ALL+1}"
UA_V0=" $(compgen -v | tr '\n' ' ') "; UA_F0=" $(compgen -A function | tr '\n' ' ') "
# shellcheck source=/dev/null
fx_inproc "$JOIN" && . "$JOIN" || { echo "FIXTURE BROKEN: sourcing $JOIN failed" >&2; exit 2; }
declare -F join_main >/dev/null || { echo "FIXTURE BROKEN: $JOIN defined no join_main when sourced; nothing was asserted" >&2; exit 2; }
# The join's own top-level names: what sourcing it added, measured, never hand-listed.
UA_JV=""; for _ua in $(compgen -v); do case "$UA_V0" in *" $_ua "*) ;; *) UA_JV="$UA_JV $_ua" ;; esac; done
UA_JF=""; for _ua in $(compgen -A function); do case "$UA_F0" in *" $_ua "*) ;; *) UA_JF="$UA_JF $_ua" ;; esac; done
case " $UA_JV " in *" refuse_n "*) ;; *) echo "FIXTURE BROKEN: the join's measured top-level names lack refuse_n" >&2; exit 2 ;; esac
# The join exports LC_ALL=C at its top level; this process keeps the caller's, and each route sets the subject's own.
ua_lc0() { if [ -n "$UA_LCSET" ]; then export LC_ALL="$UA_LC0"; else unset LC_ALL; fi; }
ua_lc0
ua_scrub() { # <keep vars> <keep funcs> -- this subshell's names reduced to a CLI child's
  local _uv _ue
  _ue=" $(compgen -e | tr '\n' ' ') "
  for _uv in $(compgen -v); do
    case "$_uv" in
      BASH*|IFS|OPTIND|OPTERR|OPTARG|PPID|UID|EUID|SHELLOPTS|HISTCMD|LINENO|RANDOM|SECONDS|FUNCNAME|PIPESTATUS|GROUPS|DIRSTACK|HOSTTYPE|MACHTYPE|OSTYPE|HOSTNAME|SHLVL|PWD|OLDPWD|_|UA_*|_uv|_ue|PS1|PS2|PS4) continue ;;
    esac
    case "$_ue" in *" $_uv "*) continue ;; esac
    case " $1 " in *" $_uv "*) continue ;; esac
    unset -v "$_uv" 2>/dev/null; unset -v "$_uv" 2>/dev/null
  done
  for _uv in $(compgen -A function); do
    case " $2 bash ua_scrub ua_lc0 " in *" $_uv "*) ;; *) unset -f "$_uv" ;; esac
  done
}
bash() {
  if [ -n "${UA_IN:-}" ] || [ -n "${UA_CLI:-}" ]; then command bash "$@"; return; fi
  case "${1:-}" in
    "${UA_OLDSIB:-/nonexistent/ua}") UA_K=join ;;
    "$JOIN") if [ -n "${UA_OLDSIB:-}" ]; then command bash "$@"; return; fi; UA_K=join ;;
    */ai-dlc-gate-remediation-guard.sh) UA_K=hook ;;
    *) command bash "$@"; return ;;
  esac
  UA_F="$1"; shift
  (
    UA_IN=1; set +o pipefail
    case "$UA_K" in
      join) fx_inproc $RSJ_J; ua_scrub "$UA_JV" "$UA_JF"; export LC_ALL=C; join_main "$@" ;;
      hook) fx_inproc $RSJ_H; ua_scrub "" ""; ua_lc0; set --; ( . "$UA_F"; hook_pretool_head
            : > "$UA_LEADF" ) ;;
    esac
  )
}
# ua_oldsib <join copy> <command...> -- the command in ONE subshell that sourced the copy once; a call naming
# the copy runs its join_main, a call naming the current join runs a CLI child. RC and the p_lc results come back.
UA_ST="$WORK/ua.state"
# A hook drive that returns from hook_pretool_head instead of exiting in it was a lead (or non-edit) payload.
UA_LEADF="$WORK/ua.lead"
ua_oldsib() {
  local m="$1" s; shift
  [ -f "$m" ] || { echo "FIXTURE BROKEN: $NAME: the join copy $m is absent" >&2; exit 2; }
  (
    UA_OLDSIB="$m"
    # shellcheck source=/dev/null
    . "$m" > /dev/null 2>&1 || exit 97
    declare -F join_main > /dev/null || exit 97
    ua_lc0
    "$@"; _s=$?
    for _v in RC; do printf '%s=%q\n' "$_v" "${!_v-}"; done > "$UA_ST"
    exit "$_s"
  ); s=$?
  [ "$s" = 97 ] && { echo "FIXTURE BROKEN: $NAME: the join copy $m could not be sourced" >&2; exit 2; }
  # shellcheck source=/dev/null
  . "$UA_ST"
  return "$s"
}

# ------------------------------------------------------------------------- worlds built once
# ua_tpl <key> <builder> [args] -> the world path. The first call builds and snapshots beside it; every later call
# moves the used world aside and restores the snapshot at the same path. State lives on disk: builders run in $( ).
ua_tpl() {
  local f="$WORK/ua-tpl.$1" b="$2" w; shift 2
  # A CLI-A run builds every world afresh, so its hook rows come from the CLI hook too.
  if [ -n "${UA_CLI:-}" ]; then ua_build "$b" "$@"; return; fi
  if [ -s "$f" ]; then
    w="$(cat "$f")"
    if [ -e "$w" ]; then mv "$w" "$(mktemp -d "$WORK/ua-used.XXXXXX")/w" || return 1; fi
    cp -Rp "$w.tpl" "$w" || return 1
  else
    w="$(ua_build "$b" "$@")" && [ -n "$w" ] && [ -d "$w" ] || return 1
    cp -Rp "$w" "$w.tpl" || return 1
    printf '%s' "$w" > "$f"
  fi
  printf '%s' "$w"
}
# ua_build <builder> [args]: each builder called by its literal name, and the rename below spelled `name() body`, so
# P2 (scripts/validate-fixture-invocations.sh) resolves every command word here to a non-entry.
ua_build() {
  local b="$1"; shift
  case "$b" in
    _ua_orig_g6_world) _ua_orig_g6_world "$@" ;;
    _ua_orig_r5_world) _ua_orig_r5_world "$@" ;;
    _ua_orig_nl_world) _ua_orig_nl_world "$@" ;;
    _ua_orig_doc_world) _ua_orig_doc_world "$@" ;;
    _ua_orig_subj_world) _ua_orig_subj_world "$@" ;;
    *) echo "FIXTURE BROKEN: ua_tpl has no builder $b" >&2; return 2 ;;
  esac
}
for _f in g6_world r5_world nl_world subj_world doc_world three_writers; do
  declare -F "$_f" > /dev/null || { echo "FIXTURE BROKEN: lib.sh defines no $_f" >&2; exit 2; }
  UA_DF="$(declare -f "$_f")"; UA_DP="$_f () "
  [ "${UA_DF#$UA_DP}" != "$UA_DF" ] || { echo "FIXTURE BROKEN: declare -f $_f does not open with '$UA_DP'" >&2; exit 2; }
  eval "_ua_orig_${_f}() ${UA_DF#$UA_DP}"
done
g6_world() { ua_tpl g6 _ua_orig_g6_world; }
r5_world() { ua_tpl r5 _ua_orig_r5_world; }
# al_world and nest_world are built once per variant already, so they are not snapshotted (a copy would only add work).
nl_world() { ua_tpl "nl-$1" _ua_orig_nl_world "$1"; }
doc_world() { ua_tpl doc _ua_orig_doc_world; }
# subj_world reads SJRD SJPA SPECREL SJSD and AI_DLC_STATE_DIR, which p_sjgate and p_sjnest override: all in the key.
subj_world() { ua_tpl "sj-$(printf '%s|' "$SJRD" "$SJPA" "$SPECREL" "$SJSD" "${AI_DLC_STATE_DIR-}" | cksum | cut -d' ' -f1)" _ua_orig_subj_world; }
# three_writers: the template's three hook rows appended with root rewritten for the world they land in.
UA_TW="$(new_world)" && _ua_orig_three_writers "$UA_TW" || { echo "FIXTURE BROKEN: the template three-writer world did not build" >&2; exit 2; }
UA_TL="$UA_TW/_bmad-output/planning-artifacts/.artifact-writes.jsonl"
[ "$(grep -c . "$UA_TL")" = 3 ] || { echo "FIXTURE BROKEN: the template ledger does not hold 3 rows" >&2; exit 2; }
ua_tw_copy() { # <world> [keep-root]
  local r; r="$(cd "$1" && pwd -P)" || return 1
  if [ -n "${2:-}" ]; then cat "$UA_TL" >> "$1/_bmad-output/planning-artifacts/.artifact-writes.jsonl"
  else jq -c --arg r "$r" '.root = $r' "$UA_TL" >> "$1/_bmad-output/planning-artifacts/.artifact-writes.jsonl"; fi
}
ua_tree() { # <world> -> every file's relative path and bytes, the ledger's unpinned ts and the world's path normalised
  local f p; p="$(cd "$1" && pwd -P)"
  ( cd "$1" && find . -type f -not -path './.git/*' | LC_ALL=C sort ) | while IFS= read -r f; do
    printf '== %s\n' "$f"
    case "$f" in *.jsonl) jq -c '.' "$1/$f" | sed -e "s#$p#WORLD#g" -e "s#$1#WORLD#g" ;; *) sed -e "s#$p#WORLD#g" -e "s#$1#WORLD#g" "$1/$f" ;; esac
  done
}

# ------------------------------------------------------------------------- SEAM-A: the routes and the templates
if ua_on SEAM; then
  # SEAM-A-TPL: a world restored from the template equals one the builder drove afresh (the hook's pinned rows, the
  # split, the parts); the control -- the same restore plus one more pinned drive -- differs.
  # The restores share one path, so each is read before the next restore moves it aside.
  _ta="$(_ua_orig_g6_world)"; _tA="$(ua_tree "$_ta")"
  _tb="$(g6_world)"; _tb="$(g6_world)"; _tB="$(ua_tree "$_tb")"
  _tc="$(g6_world)"; gsec "$_tc" 4 "$G_NEW" 19:52:00; _tC="$(ua_tree "$_tc")"
  _tw1="$(new_world)"; _ua_orig_three_writers "$_tw1"; _tw2="$(new_world)"; ua_tw_copy "$_tw2"; _tw3="$(new_world)"; ua_tw_copy "$_tw3" keep
  _w1="$(ua_tree "$_tw1" | sed 's/"ts":"[^"]*"/"ts":"TS"/')"; _w2="$(ua_tree "$_tw2" | sed 's/"ts":"[^"]*"/"ts":"TS"/')"; _w3="$(ua_tree "$_tw3" | sed 's/"ts":"[^"]*"/"ts":"TS"/')"
  if [ "$_tA" = "$_tB" ] && [ "$_tA" != "$_tC" ] && grep -qF 'sections/.manifest' <<<"$_tA" \
     && [ "$_w1" = "$_w2" ] && [ "$_w1" != "$_w3" ] && grep -qF '"root":"WORLD"' <<<"$_w1"; then
    ok "SEAM-A-TPL: a g6 world restored from its template equals one the builder drove afresh, whole tree, and one more drive differs; three template rows with root rewritten equal three hook drives (ts aside), and root left unrewritten differs"
  else
    bad "SEAM-A-TPL: g6 restored=fresh $([ "$_tA" = "$_tB" ] && echo y || echo n), control differs $([ "$_tA" != "$_tC" ] && echo y || echo n); three-writer copied=driven $([ "$_w1" = "$_w2" ] && echo y || echo n), root-kept differs $([ "$_w1" != "$_w3" ] && echo y || echo n)"
  fi
  # SEAM-A-HOOK: one pinned dispatched drive, in process and as a CLI child, writes the same row (root aside).
  ua_hook() { # <cli 0|1> <agent> <ts> -> the ledger row and the hook's output|rc
    local w o rc; w="$(new_world)"
    jq -nc --arg f "$w/$REL/$S21" --arg a "$2" --arg tp "$w/projects/s.jsonl" '{session_id:"t", tool_name:"Edit", transcript_path:$tp, tool_use_id:"toolu_SEAM", tool_input:{file_path:$f}} + (if $a == "" then {} else {agent_id:$a} end)' > "$WORK/uah.payload"
    o="$(UA_CLI="${1#0}" FIX_DRIVE_TS="$3" PATH="$DSHIM:$PATH" CLAUDE_PROJECT_DIR="$w" bash "$HOOK" < "$WORK/uah.payload" 2>&1)"; rc=$?
    jq -c 'del(.root)' "$w/_bmad-output/planning-artifacts/.artifact-writes.jsonl" 2>/dev/null | sed "s#$w#WORLD#g"
    printf '%s|%s' "${o//$w/WORLD}" "$rc"
  }
  _hi="$(ua_hook 0 "$AG1" 2026-10-15T19:25:00Z)"; _hc="$(ua_hook 1 "$AG1" 2026-10-15T19:25:00Z)"
  _gi="$(ua_hook 0 "$G_NEW" 2026-10-15T19:50:00Z)"; _gc="$(ua_hook 1 "$G_NEW" 2026-10-15T19:50:00Z)"
  if [ "$_hi" = "$_hc" ] && [ "$_gi" = "$_gc" ] && [ "$_hc" != "$_gc" ] && grep -qF '"ts":"2026-10-15T19:25:00Z"' <<<"$_hc" \
     && grep -qF '"tool_use_id":"toolu_SEAM"' <<<"$_hc"; then
    ok "SEAM-A-HOOK: hook_pretool_head in process writes the CLI hook's row byte-for-byte (root aside), the shim's pinned ts and the payload's tool_use_id included, for two agents and two ts, and the two rows differ"
  else
    bad "SEAM-A-HOOK: AG1 in=[$_hi] cli=[$_hc]; G_NEW in=[$_gi] cli=[$_gc]"
  fi
  # SEAM-A-SUBJ: --subject over one world, restored at its own path before each run: the pass (rc 0) and the refusal
  # (a second agent on the whole-file SPEC part, rc 2), in process and as a CLI child, byte-identical output and record.
  _sw="$(subj_world)"; sj_all "$_sw"; stamp "$_sw"; cp -Rp "$_sw" "$_sw.pass"
  drive "$_sw" Edit "$_sw/$SPECREL" a9999999999999999; cp -Rp "$_sw" "$_sw.refuse"
  _su="$(jnow)"
  ua_sj() { # <cli 0|1> <snapshot pass|refuse> -> "rc|output|record"
    local o rc; mv "$_sw" "$(mktemp -d "$WORK/ua-used.XXXXXX")/w" && cp -Rp "$_sw.$2" "$_sw" || return 1
    o="$(UA_CLI="${1#0}" AI_DLC_PROJECT_ROOT="$_sw" bash "$JOIN" --subject 9 --pass 1 --since 2000-01-01T00:00:00Z --until "$_su" 2>&1)"; rc=$?
    printf '%s|%s|%s' "$rc" "$o" "$(cat "$(sj_out "$_sw")" 2>/dev/null)"
  }
  _pi="$(ua_sj 0 pass)"; _pc="$(ua_sj 1 pass)"; _ri="$(ua_sj 0 refuse)"; _rc="$(ua_sj 1 refuse)"
  if [ "${_pc%%|*}" = 0 ] && [ "${_rc%%|*}" = 2 ] && [ "$_pi" = "$_pc" ] && [ "$_ri" = "$_rc" ] && [ "$_pc" != "$_rc" ] \
     && grep -qF -- '- artifact: ' <<<"$_pc"; then
    ok "SEAM-A-SUBJ: join_main in process answers --subject byte-identically to the CLI (output and record) on a join (rc 0) and a two-writer refusal (rc 2), and the two differ"
  else
    bad "SEAM-A-SUBJ: pass cli rc=${_pc%%|*} equal=$([ "$_pi" = "$_pc" ] && echo y || echo n); refuse cli rc=${_rc%%|*} equal=$([ "$_ri" = "$_rc" ] && echo y || echo n)"
  fi
fi
three_writers() { if [ -n "${UA_CLI:-}" ]; then _ua_orig_three_writers "$1"; else ua_tw_copy "$1"; fi; }

# ------------------------------------------------------------------------- SJ: subject mode
if ua_on SJ; then
p_sjoin "$JOIN" && ok "SJ1: --subject, one writer per part -> JOINED; prd assembled, SPEC edited in place, the unchanged brief untouched; per-stem <stem>@<sha> before/after lists, artifact: the manifest" \
  || bad "SJ1: the subject join (rc=$RC): $(cat "$JO")"
# SJ1o: the join asks the SIBLING merge's --pair-sep and writes `@` only on exit 0 with exactly `@`.
# A copy of the join's scripts dir with an OLD merge beside it must write `=`. The old merge is a
# stub this fixture writes, never a vendored copy of core's own script: it does what a merge before
# --pair-sep does with that flag (measured), printing REFUSED on stdout and exiting 2. The
# unmodified copy, driven the same way, writes `@`: the merge sibling is what moved the record.
SJO_OLD="$WORK/sjo-old-merge.sh"
printf '%s\n' '#!/bin/bash' "printf 'REFUSED: shard directory --pair-sep does not exist\\n'" 'exit 2' > "$SJO_OLD"
sjo_cur="$(mktemp -d "$WORK/sjo-cur.XXXXXX")/scripts"; sjo_old="$(mktemp -d "$WORK/sjo-old.XXXXXX")/scripts"
# The merge's key (c) asks validate-provenance-block.sh, which finds the schema at ../schemas beside
# its own dir when the world carries none, so each copy carries the schema there. It is found by
# walking up from the join for either layout's schema dir, never by counting `..`.
SJO_SCH=""
_d="$SRCDIR"
while [ -n "$_d" ] && [ "$_d" != "/" ]; do
  for _c in "$_d/core/schemas/provenance-block.json" "$_d/.claude/schemas/provenance-block.json"; do
    [ -f "$_c" ] && { SJO_SCH="$_c"; break 2; }
  done
  _d="$(dirname "$_d")"
done
if [ ! -s "$SJO_OLD" ] || [ ! -f "$SRCDIR/merge-adversarial-shards.sh" ] || [ -z "$SJO_SCH" ]; then
  bad "SJ1o: FIXTURE BROKEN -- $SJO_OLD, $SRCDIR/merge-adversarial-shards.sh or provenance-block.json above $SRCDIR is absent; nothing was asserted"
elif ! { cp -Rp "$SRCDIR" "$sjo_cur" && cp -Rp "$SRCDIR" "$sjo_old" && cp "$SJO_OLD" "$sjo_old/merge-adversarial-shards.sh" \
         && mkdir "$sjo_cur/../schemas" "$sjo_old/../schemas" \
         && cp "$SJO_SCH" "$sjo_cur/../schemas/" && cp "$SJO_SCH" "$sjo_old/../schemas/"; }; then
  bad "SJ1o: FIXTURE BROKEN -- the scripts-dir copies did not build"
elif cmp -s "$sjo_cur/merge-adversarial-shards.sh" "$sjo_old/merge-adversarial-shards.sh"; then
  bad "SJ1o: FIXTURE BROKEN -- the old merge is byte-identical to the current one"
else
  # Each copy sourced once, in its own subshell, so its join resolves the merge sibling beside it.
  ua_oldsib "$sjo_old/join-remediator-shards.sh" p_sjoin "$sjo_old/join-remediator-shards.sh" "=" && r_o=0 || r_o=1; o_rc=$RC
  ua_oldsib "$sjo_cur/join-remediator-shards.sh" p_sjoin "$sjo_cur/join-remediator-shards.sh" "@" && r_c=0 || r_c=1
  [ "$r_o" -eq 0 ] && [ "$r_c" -eq 0 ] \
    && ok "SJ1o: the join beside an old merge sibling (REFUSED on --pair-sep) writes <stem>=<sha> before/after lists; the same copy with the current merge writes <stem>@<sha>" \
    || bad "SJ1o: old-merge join matched '=' -> $r_o (rc=$o_rc), current-merge copy matched '@' -> $r_c (want 0 0): $(cat "$JO")"
fi
p_sjspec2 "$JOIN" && ok "SJ2: the whole-file SPEC part written by two agents -> REFUSED 'more than one agent', no record" || bad "SJ2: (rc=$RC) $(cat "$JO")"
p_sjoos "$JOIN" && ok "SJ3: prd.md written IN PLACE while its sections were out (out-of-scope text) -> REFUSED naming the file, no record" || bad "SJ3: (rc=$RC) $(cat "$JO")"
p_sjnopart "$JOIN" && ok "SJ4: the unchanged brief (no part) written in the window -> REFUSED, no record" || bad "SJ4: (rc=$RC) $(cat "$JO")"
p_sjnames "$JOIN" && ok "SJ5: --pass party reads shards/requirements-party-repair/ and writes requirements-party-repair.md, never a *-repair-p<M>.md" || bad "SJ5: (rc=$RC) $(cat "$JO")"
p_sjbase "$JOIN" && ok "SJ6: --base other than the manifest's -> REFUSED, no record" || bad "SJ6: (rc=$RC) $(cat "$JO")"
p_sjgate "$JOIN" && ok "SJ7: --subject --artifact gate-planning --pass 1 -> JOINED as gate-planning-repair-p1.md from shards/gate-planning-repair-p1/, and no requirements-repair-p1.md" || bad "SJ7: $(cat "$JO")"
p_sjgatenear "$JOIN" && ok "SJ8: near-misses -- --artifact stories, and --artifact gate-planning with --pass party -> REFUSED, nothing written" || bad "SJ8: $(cat "$JO")"
p_sjnest "$JOIN" && ok "SJ9: a nested AI_DLC_STATE_DIR (out/bmad) -> map, split and join agree and the record is the manifest's root-relative path (SJ1 is the default-layout control)" || bad "SJ9: $(cat "$JO")"
fi

# ------------------------------------------------------------------------- EC: the entry contract, read in parts mode
if ua_on EC; then
p_sibdoc "$JOIN" && ok "EC14: --document, one section part omitting siblings: -> REFUSED naming it with the pre-install re-dispatch remedy, the document not assembled" \
  || bad "EC14: a --document part omitting siblings: was not refused (rc=$RC): $(cat "$JO")"
p_sibstale "$JOIN" && ok "EC18: the joined fence, its text later rewritten -> the slot-wide derivations re-run reads no STALE; the same fence re-labelled derived reads STALE" \
  || bad "EC18: the siblings fence is replayed by the derivations validator, or the derived control did not go stale (rc=$RC dv=${DV_RC:-}): $(cat "$JO" "$SB_W/dv.out" 2>/dev/null | head -20)"
p_escpath "$JOIN" && ok "EC19: an escalated entry naming the sibling's path on edit:, beside the shard that repairs that file -> JOINED (the escalated path is no citation)" \
  || bad "EC19: an escalated entry's edit: path collided with another shard's citation (rc=$RC): $(cat "$JO")"
p_srcparts "$JOIN" && ok "EC25: --sources on a record citing only part tokens, seats present -> ONE refusal naming --escalations; a seat-token record resolves" \
  || bad "EC25: --sources did not refuse a part-token record by name, or refused the party control (rc=$RC): $(cat "$JO")"
p_partsilent "$JOIN" && ok "EC32: a REFUSED parts join prints no ESCALATED: line and no count -- nothing was joined (record mode prints through a refusal; parts mode by design does not)" \
  || bad "EC32: a refused parts join printed an escalation report, or did not refuse (rc=$RC): $(cat "$JO")"
p_fencenest "$JOIN" && ok "EC36: the record readers close a four-backtick fence only on a run at least as long -- content after its inner three-backtick block is no entry, no check line, no source token and no heading" || bad "EC36: a record reader closed a four-backtick fence on its inner three-backtick line (rc=$RC): $(cat "$JO")"
p_partmark "$JOIN" && ok "EC37: a part closed by the real --mark joins beside an unmarked one, its seat-complete: line kept in the record; a serial block appended after the LAST marked part is segmented at its own triple -- stating both check lines rc 0, stating neither REFUSED naming its repair-complete: serial line and never a seat-complete: line" || bad "EC37: a marked part broke the joined record or its serial block (rc=$RC): $(cat "$JO")"
p_advname "$JOIN" && ok "EC38: an artifact ending in -adversarial is REFUSED in document and files mode, naming <artifact>-repair-p<M> and arm H, nothing written; shards/x-repair-p1/ joins and shards/adversarial-notes-repair-p1/ draws no such refusal" \
  || bad "EC38: an -adversarial artifact was not refused as specified, or a -repair-p dir drew the refusal (rc=$RC): $(cat "$JO")"
fi

# ------------------------------------------------------------------------- RR, AL, NW: re-runs, aliases, nested writers
if ua_on RR; then
# ---- re-run of one part (--rerun <part>.md@<ISO>): graph's S319 shape, its refusals, and every mode.
p_rrgraph "$JOIN" && ok "RR1: six sections, section 2 by its original writer, an orphan and the original again, then a NEW agent after S_P -> REFUSED without --rerun; JOINED with it, the rerun: line naming both superseded ids (3 rows), the outer window kept, 'in its window', '3 superseded rows'" \
  || bad "RR1: the graph-shape re-run did not refuse-then-join as specified (rc=$RC): $(cat "$JO")"
p_rrout "$JOIN" && ok "RR2: section 3's owner also wrote section 2 before S_P -> REFUSED, a superseded writer with a row outside the re-run part's files" \
  || bad "RR2: a superseded writer that owns another section was not refused (rc=$RC): $(cat "$JO")"
p_rrlate "$JOIN" && ok "RR3: the original still writing after S_P outside F_P -> REFUSED in both spellings (still writing, and outside the part's files)" \
  || bad "RR3: a superseded writer writing after S_P outside F_P was not refused in both spellings (rc=$RC): $(cat "$JO")"
if p_rrlatein "$JOIN"; then ok "RR4: the original still writing after S_P inside F_P, beside the new writer -> no start can pass: DOUBLE-WRITE with every writer's span, the only --rerun refusal, no SAME; the distinct-writer and SPAN lines beside it, three in all"
else bad "RR4: a no-admissible-start re-run inside F_P was not refused DOUBLE-WRITE alone (rc=$RC): $(cat "$JO")"; fi
if p_rrsame "$JOIN"; then ok "RR5: the same id both sides of S_P, the orphan inside its span, no new writer -> DOUBLE-WRITE naming both spans, no SAME"
else bad "RR5: a no-admissible-start re-run by the superseded writer itself was not refused DOUBLE-WRITE (rc=$RC): $(cat "$JO")"; fi
if p_rrsamew "$JOIN"; then ok "RR16: graph's re-run with the start inside the original's span -> SAME, no DOUBLE-WRITE (a later start passes), and that later start JOINS"
else bad "RR16: a too-early start where another start passes did not read SAME-then-JOIN (rc=$RC): $(cat "$JO")"; fi
if p_rrdwrec "$JOIN"; then ok "RR17: RR5's world plus a NEW agent writing 2.md's record after every F_P row -> DOUBLE-WRITE at S_P; the record-only start and a start before every row both REFUSED on two writers"
else bad "RR17: the record-only start was not shown unable to pass beside DOUBLE-WRITE (rc=$RC): $(cat "$JO")"; fi
if p_rrdwal "$JOIN"; then ok "RR18: the alias world under --rerun -> a start inside the raw span keeps SAME, no DOUBLE-WRITE, and a start before every row JOINS with its alias row"
else bad "RR18: the alias gate let DOUBLE-WRITE claim no start where an aliased start joins (rc=$RC): $(cat "$JO")"; fi
if p_rrdwmf "$JOIN"; then ok "RR19: part 5 cites two files, its one writer of sections/5.md straddles S_P and another writer of sections/4.md sits inside its span -> DOUBLE-WRITE over the file set, no SAME"
else bad "RR19: NOADM was not decided over the whole cited file set (rc=$RC): $(cat "$JO")"; fi
if p_rrdwtwo "$JOIN"; then ok "RR20: RR4's world with the original writing sections/2.md twice after S_P -> exactly one DOUBLE-WRITE 2.md line, spans through the second row"
else bad "RR20: two post-start superseded rows on one NOADM part did not print exactly one DOUBLE-WRITE line (rc=$RC): $(cat "$JO")"; fi
p_rrspan "$JOIN" && ok "RR6: the re-run writer also writes section 4 -> REFUSED, section 4 has two writers" \
  || bad "RR6: a re-run writer writing another section was not refused (rc=$RC): $(cat "$JO")"
p_rrprlate "$JOIN" && ok "RR10: the original writes 2.md's own part record after S_P -> REFUSED, a superseded writer writing an account" \
  || bad "RR10: a superseded writer's part-record row after S_P was not refused (rc=$RC): $(cat "$JO")"
p_rrprout "$JOIN" && ok "RR11: the original wrote another part's record (3.md) before S_P -> REFUSED, it was not only 2.md's writer" \
  || bad "RR11: a superseded writer's row on another part's record was not refused (rc=$RC): $(cat "$JO")"
p_rrprforeign "$JOIN" && ok "RR12: another agent writes 2.md's record after S_P beside the re-run's -> REFUSED, the account is the re-run writer's alone" \
  || bad "RR12: a foreign row on the re-run part's record after S_P was not refused (rc=$RC): $(cat "$JO")"
p_rrprnone "$JOIN" && ok "RR13: the re-run never writes 2.md's record -> REFUSED, the covering account is not the re-run's" \
  || bad "RR13: a re-run with no part-record row was not refused (rc=$RC): $(cat "$JO")"
p_rrreuse "$JOIN" && ok "RR14: section 3's finished owner does the section-2 re-run -> REFUSED on its section-3 file and its 3.md record" \
  || bad "RR14: a finished part's agent re-running another part was not refused (rc=$RC): $(cat "$JO")"
p_rrargs "$JOIN" && ok "RR7: --rerun argument refusals -- an unknown part, a part named twice, a start outside the window, a malformed start, no @, a part citing no written file, and --rerun with --escalations" \
  || bad "RR7: a --rerun argument refusal did not fire as named (rc=$RC): $(cat "$JO")"
p_rrfiles "$JOIN" && ok "RR8: FILES mode -- story 2.1 re-run by a new agent -> REFUSED without --rerun, JOINED with it, its rerun: line and '1 superseded rows'" \
  || bad "RR8: a files-mode re-run did not refuse-then-join (rc=$RC): $(cat "$JO")"
p_rrsubj "$JOIN" && ok "RR9: SUBJECT mode -- one sectioned part re-run by a new agent -> REFUSED without --rerun, JOINED with it, 'in its window'" \
  || bad "RR9: a subject-mode re-run did not refuse-then-join (rc=$RC): $(cat "$JO")"

# ---- the alias rule: a no-transcript id whose tool_use_id is ONE assistant tool_use in another writer's transcript.
p_alias "$JOIN" && ok "AL1: the orphan row's tool_use_id is one assistant tool_use in the other writer's transcript, the orphan has none -> JOINED, '1 alias rows', the alias: line in the record" \
  || bad "AL1: a transcript-evidenced alias did not join (rc=$RC): $(cat "$JO")"
p_alnokeys "$JOIN" && ok "AL2: AL1's ledger with the three keys stripped (pre-upgrade) -> REFUSED as before, no evidence line" \
  || bad "AL2: a keyless ledger was not judged as before (rc=$RC): $(cat "$JO")"
p_alresult "$JOIN" && ok "AL3: the id appears only inside a tool_result -> REFUSED, 'held by no writer's transcript'" \
  || bad "AL3: an id quoted in a tool_result was read as a tool_use (rc=$RC): $(cat "$JO")"
p_alown "$JOIN" && ok "AL4: the orphan has its own transcript -> REFUSED, the transcript named as existing" \
  || bad "AL4: an agent with its own transcript was aliased (rc=$RC): $(cat "$JO")"
p_alsecond "$JOIN" && ok "AL5: a genuine second remediator sharing the parent transcript_path -> REFUSED (a shared transcript_path is never evidence)" \
  || bad "AL5: a second remediator sharing transcript_path was aliased (rc=$RC): $(cat "$JO")"
p_alother "$JOIN" && ok "AL6: the orphan id has a second row in the file set -> REFUSED, '2 row(s)' named" \
  || bad "AL6: an id with another row was aliased (rc=$RC): $(cat "$JO")"
p_alsess "$JOIN" && ok "AL7: the holding tool_use is in the transcript of a writer whose rows are in ANOTHER session -> REFUSED" \
  || bad "AL7: an alias across sessions was accepted (rc=$RC): $(cat "$JO")"
p_altwo "$JOIN" && ok "AL8: the id is held by TWO tool_use blocks -> REFUSED, '2 block(s)' named" \
  || bad "AL8: an id held by two tool_use blocks was aliased (rc=$RC): $(cat "$JO")"
p_altool "$JOIN" && ok "AL9: the one tool_use holding the id is a Read -> REFUSED" \
  || bad "AL9: an id held by a non-write tool_use was aliased (rc=$RC): $(cat "$JO")"
p_rronly "$JOIN" && ok "RR15: a record-only re-run of 5.md -> JOINED with 'record-only', nothing on sections/5.md dropped; writing nothing -> PRNONE; the original rewriting 5.md, or two agents writing it -> REFUSED; a nested child of the re-run writer writing sections/5.md -> the re-run writer" || bad "RR15: the record-only re-run did not hold (rc=$RC): $(cat "$JO")"
p_nested "$JOIN" && ok "NW1: a nested writer (its probe row and a spawn row naming its dispatcher) on its dispatcher's file -> JOINED as one writer with the nested: line; a lead-issued spawn, a key-less spawn row and a missing probe row -> REFUSED naming the ledger" || bad "NW1: the nested-writer fold did not hold (rc=$RC): $(cat "$JO")"
p_member "$JOIN" && ok "NW2: a round-dispatcher's members (its meta.json spawn has no spawn-ledger row) are their own writers: one member per story -> JOINED, 3 writers, no nested: line; two members on one story -> REFUSED naming each as a round member" || bad "NW2: a round member was folded into its dispatcher (rc=$RC): $(cat "$JO")"
fi

# ------------------------------------------------------------------------- LN: serial lanes
if ua_on LN; then
# ---- serial lanes (BL-716): one serial remediator per lane of FILES, then one fan-in. LN3 is the world that
# kills "one LANE per part": its three prd parts share prd.md, and a MOVED-CITE joins architecture-impact to it.
[ -f "$SRCDIR/serial-remediation-worklist.sh" ] || { echo "FIXTURE BROKEN: serial-remediation-worklist.sh is not beside the join; the lane arms would read every edge UNASSESSED" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/scripts/serial-remediation-worklist.sh"
p_lanefiles "$JOIN" && ok "LN1: files mode, three disjoint parts -> 3 lanes, each file-less escalation and the sweep to FANIN, no worklist edge" \
  || bad "LN1: files-mode lanes answered wrongly (rc=$RC): $(grep -E '^(LANE|FANIN)' "$JO")"
p_lanedoc "$JOIN" && ok "LN2: document mode, three section parts of one document -> ONE lane (a shared file), the worklist ran, FANIN-COUNT: 0" \
  || bad "LN2: section parts of one document were not one lane (rc=$RC): $(grep -E '^(LANE|FANIN)' "$JO")"
if p_lanesubj "$JOIN"; then ok "LN3: subject mode, prd's three sections one lane and a MOVED-CITE joining architecture-impact to it -> 2 lanes, the cite that lane's item"
else bad "LN3: the shared-file or MOVED-CITE edge did not join lanes (rc=$RC): $(grep -E '^(LANE|FANIN)' "$JO")"; fi
p_lanesubjnear "$JOIN" && ok "LN4: LN3 one property apart, no cite -> 3 lanes" \
  || bad "LN4: lanes joined with no edge (rc=$RC): $(grep -E '^(LANE|FANIN)' "$JO")"
p_lanehit "$JOIN" && ok "LN5: a replaced line still standing in two other lanes' files -> 3 lanes, ONE FANIN HIT item (a HIT never joins lanes)" \
  || bad "LN5: a cross-lane HIT joined lanes or was not one fan-in item (rc=$RC): $(grep -E '^(LANE|FANIN)' "$JO")"
p_laneround "$JOIN" && ok "LN7: the lane round's own join (--artifact stories-serial) JOINS its lane parts and prints no LANE or FANIN line" \
  || bad "LN7: the lane round's join did not join or printed lanes (rc=$RC): $(cat "$JO")"
# ---- BL-716 second build: the ADJUDICATION PARTITION (LN10-LN12), an escalation's own unedited file (LN13, LN14), and the lane
# round's read-only adjudicator arm (LN15, LN16).
if p_adjfour "$JOIN"; then ok "LN10: four fan-in items -> ADJUDICATE fanin 1/2 and 2/2, two items each, the sweep never dealt, ADJUDICATOR-COUNT: 2"
else bad "LN10: the fan-in was not dealt into two batches (rc=$RC): $(grep -E '^(FANIN|ADJUDICAT)' "$JO")"; fi
p_adjthree "$JOIN" && ok "LN11: three fan-in items -> no ADJUDICATE line, ADJUDICATOR-COUNT: 0 (the writer adjudicates)" \
  || bad "LN11: three items were dealt (rc=$RC): $(grep -E '^(FANIN|ADJUDICAT)' "$JO")"
p_adjcap "$JOIN" && ok "LN12: eleven fan-in items -> k capped at 4, no batch over 3, ADJUDICATOR-COUNT: 4" \
  || bad "LN12: eleven items were not dealt into four batches (rc=$RC): $(grep -E '^(FANIN|ADJUDICAT)' "$JO")"
if p_planfile "$JOIN"; then ok "LN17: the join's last line is PLAN-FILE naming <shard dir>/.join-plan, which holds every line from JOINED: on byte for byte (fan-in dealt 2/2); a re-join refuses naming that file; with it gone the refusal says no plan file is there"
else bad "LN17: the plan file failed at case ${RPLAN:-?} (rc=$RC): $(tail -n 3 "$JO")"; fi
if p_escown "$JOIN"; then ok "LN13: an escalation naming an unedited story in the slot -> a lane of its own, the escalation its LANE-ITEM, not FANIN"
else bad "LN13: the unedited-file escalation was not a lane (rc=$RC): $(grep -E '^(LANE|FANIN)' "$JO")"; fi
p_escnear "$JOIN" && ok "LN14: the same escalation naming an absent story, a file outside the slot, or two part lanes' files -> FANIN, LANE-COUNT: 2 (no lane added, none merged)" \
  || bad "LN14: a near-miss escalation was made a lane or merged lanes (rc=$RC): $(grep -E '^(LANE|FANIN)' "$JO")"
if p_adjwrote "$JOIN"; then ok "LN15: an adjudicator that edited a story BEFORE the lane window -> the lane join REFUSES, naming agent, file and ts"
else bad "LN15: an adjudicator's artifact write was not refused (rc=$RC): $(grep -m2 REFUSED "$JO")"; fi
p_adjclean "$JOIN" && ok "LN16: LN15 one write apart, the adjudicator wrote only its batch file -> JOINED" \
  || bad "LN16: a read-only adjudicator was refused (rc=$RC): $(grep -m2 REFUSED "$JO")"
if p_lanerec "$JOIN"; then ok "LN6: --escalations reads the lane round's record after round 1 and closes by it; either record alone REFUSED; the subject party record owes requirements-party-serial-repair-p1.md; no LANE/FANIN line in a record mode"
else bad "LN6: the lane round's record was not read with round 1 (rc=$RC): $(cat "$JO")"; fi
p_lanename "$JOIN" && ok "LN8: the subject party join prints LANE-ARTIFACT: requirements-party-serial --pass 1, derived from its record" \
  || bad "LN8: the lane round's name was not derived from the record (rc=$RC): $(grep -E '^LANE-ARTIFACT' "$JO")"
# ---- BL-716 route file (header 4d): serial-routed findings dealt as CROSS items; LN18-LN22. Every older arm above is an absent-file run and asserts no CROSS byte.
if p_xdeal "$JOIN"; then ok "LN18: a route file -> CROSS-COUNT right after SERIAL-REQUIRED; one lane's CROSS items dealt (2 batches), a two-lane file and a - file FANIN items, lanes unmerged; the plan file carries them"
else bad "LN18: the route file was not dealt (rc=$RC): $(grep -E '^(CROSS|LANE|FANIN|ADJ)' "$JO")"; fi
p_xrefuse "$JOIN" && ok "LN19: a bad header, field count, key grammar, 01.md/1.md duplicate, .. path, absolute path, empty files field or non-serial first field -> exit 2, its own REFUSED text, no record and no .join-plan" \
  || bad "LN19: a malformed route file did not refuse as expected (rc=$RC): $(grep -m2 REFUSED "$JO")"
p_xzero "$JOIN" && ok "LN20: a zero-lane round with one routed finding -> the FANIN CROSS line, LANE-COUNT: 0, ADJUDICATOR-COUNT: 0" \
  || bad "LN20: the zero-lane route case failed (rc=$RC): $(cat "$JO")"
p_xlane "$JOIN" && ok "LN21: the lane round's join REFUSES a route file in its shard dir, writing nothing" \
  || bad "LN21: the lane round read or ignored a route file (rc=$RC): $(cat "$JO")"
p_xcover "$JOIN" && ok "LN22: --escalations prints CROSS-OPEN for a route key no later record's source: carries (round one's own never acquit; same-basename keys in two dirs are two keys), silent for a covered one (03.md = 3.md), count 0 once a later record covers it, nothing new with no file" \
  || bad "LN22: the CROSS-OPEN coverage failed (rc=$RC): $(cat "$JO")"
fi

# ------------------------------------------------------------------------- LP: the lane path
if ua_on LP; then
# ---- the lane path (BL-802): the round-one join prints LANE-ARTIFACT-PATH, the lane join copies it, and the
# ledger holds exactly one row for the lane writer's in-place edit of the assembled document. p_lc in lib.sh.
LP_OUT=docs/design-notes.md; LP_COE=_bmad-output/planning-artifacts/s305/coe.md
p_lc "$HOOK" "$JOIN" _bmad-output "$LP_OUT"
if lc_joined "$LP_OUT"; then ok "LP1: a sections document outside the state dir ($LP_OUT): LANE-ARTIFACT-PATH prints it project-relative, the lane join given that path JOINS 1 part / 1 writer, ONE row at that path"
else bad "LP1: the out-of-state lane did not join on the copied path ($(lc_why))"; fi
p_lc "$HOOK" "$JOIN" x/_bmad-output "x/$LP_OUT"
lc_joined "x/$LP_OUT" && ok "LP2: the same under AI_DLC_STATE_DIR=x/_bmad-output: the row and LANE-ARTIFACT-PATH are x/$LP_OUT (project-relative, not relative to the state dir's parent) and JOINED" \
  || bad "LP2: the nested out-of-state lane did not join ($(lc_why))"
p_lc "$HOOK" "$JOIN" _bmad-output "$LP_COE"
if lc_joined "$LP_COE"; then ok "LP3: an in-state (coe) document: LANE-ARTIFACT-PATH prints the state spelling $LP_COE, ONE row, JOINED"
else bad "LP3: the in-state lane did not join ($(lc_why))"; fi
p_lc "$HOOK" "$JOIN" x/_bmad-output "x/$LP_COE"
if lc_joined "$LP_COE"; then ok "LP4: the in-state (coe) document under x/_bmad-output: LANE-ARTIFACT-PATH prints $LP_COE (the state basename, not x/...), ONE row, JOINED"
else bad "LP4: the nested in-state lane did not join ($(lc_why))"; fi
p_lc "$HOOK" "$JOIN" _bmad-output "$LP_OUT" "$AG2"
if [ "$LC_LAP" = "$LP_OUT" ] && [ "$RC" = 2 ] && has "$JO" "$LP_OUT was written by more than one agent in the window" && [ ! -e "$LC_OUT" ]; then
  ok "LP5: LP1 one property apart, a second dispatched agent also edits the document in the window -> the lane join REFUSES (exit 2) naming it, no record"
else
  bad "LP5: two writers of the lane's document were not refused ($(lc_why))"
fi
fi

# ------------------------------------------------------------------------- NL: a round in which no lane wrote the subject
if ua_on NL; then
# ---- BL-807, claim 1: a round in which no lane wrote the subject joins; a lane that cited a file, a lane agent with a
# subject row outside the window, or a part record with no row still refuses. Predicates in lib.sh (p_nl*).
if p_nl2lane "$JOIN"; then ok "NL1: the lane round's two lanes, both \`edit: n/a\`, an empty ledger window -> JOINED (2 parts, 0 writers), the header's no-lane line REPLACING the one-writer sentence, no lane report (-serial)"
else bad "NL1: the two-lane no-edit round did not join with the no-lane header (rc=$RC): $(grep -m1 REFUSED "$JO")"; fi
p_nlesc "$JOIN" && ok "NL2: a round-one record, one lane \`edit: n/a\` and one ESCALATED entry naming a story -> JOINED, ESCALATED-COUNT 1, that unedited story one lane, the escalation its item" \
  || bad "NL2: the n/a + escalated round did not join (rc=$RC): $(grep -m1 REFUSED "$JO")"
if p_nlcites "$JOIN"; then ok "NL3: one lane cites a file it never ledgered, the window empty -> REFUSED with the 'records no dispatched write' line verbatim AND the coverage join's UNWRITTEN line"
else bad "NL3: a lane citing an unledgered edit was not refused with both lines (rc=$RC): $(grep -m2 REFUSED "$JO" | tr '\n' ' ')"; fi
if p_nloutside "$JOIN"; then ok "NL4: a lane agent's only subject write lies BEFORE --since and is cited by no part -> REFUSED naming the row"
else bad "NL4: a lane agent's out-of-window subject write was not refused (rc=$RC): $(grep -m1 -E 'REFUSED|JOINED' "$JO")"; fi
if p_nlnorow "$JOIN"; then ok "NL5: a part record with no ledger row -> REFUSED (its writer is unknown), never accepted over an empty lane set"
else bad "NL5: a part with no ledger row was not refused (rc=$RC): $(grep -m1 -E 'REFUSED|JOINED' "$JO")"; fi
p_nldoc "$JOIN" && ok "NL6: --document, every section part \`edit: n/a\`, no section copy written -> JOINED, assembled, the section sentence replaced by the no-lane line" \
  || bad "NL6: the no-edit document round did not join with the no-lane header (rc=$RC): $(grep -m1 REFUSED "$JO")"
# NL7: key 2 judges the edit: VALUE, not its tokens. The same world (a Bash write to the subject, no ledger row)
# refuses with an extension-less cite and joins with the ALLOW twin `` `n/a` (escalated) ``, one property apart.
if p_nlnoext "$JOIN"; then
  _nl7=$RC; p_nlnoext "$JOIN" '`n/a` (escalated)'
  if [ "$RC" -eq 0 ] && has "$JO" "stories-serial-repair-p1.md (2 parts, 0 writers)"; then
    ok "NL7: a lane citing the subject with no extension (\`.../story-2.1-positions-on-demand\` line 3), its write unledgered -> REFUSED 'records no dispatched write' (rc=$_nl7); the same world with \`n/a\` (escalated) -> JOINED"
  else bad "NL7: the ALLOW twin \`n/a\` (escalated) did not join (rc=$RC): $(grep -m1 REFUSED "$JO")"; fi
else
  bad "NL7: a lane citing the subject with no extension was not refused (rc=$RC): $(grep -m1 -E 'REFUSED|JOINED' "$JO")"
fi
# NL8: an absent edit: line is not a no-edit value. A part whose second entry is repaired with NO edit: line refuses;
# the same part with that entry `skipped (nit)` (graph's only no-edit-line shape) joins, one property apart.
# The operator-ruling case also draws the missing-ruling-cite refusal; NL8 requires the key-2 line beside it.
if p_nlnoedit "$JOIN" && p_nlnoedit "$JOIN" 'operator-ruling (F-3 is ruled)'; then
  _nl8=$RC; p_nlnoedit "$JOIN" 'skipped (nit)'
  if [ "$RC" -eq 0 ] && has "$JO" "stories-serial-repair-p1.md (2 parts, 0 writers)"; then
    ok "NL8: a lane's repaired entry, and an operator-ruling entry, with no edit: line -> REFUSED 'records no dispatched write' (rc=$_nl8); the same entry \`skipped (nit)\` -> JOINED"
  else bad "NL8: the ALLOW twin \`skipped (nit)\` with no edit: line did not join (rc=$RC): $(grep -m1 REFUSED "$JO")"; fi
else
  bad "NL8: a lane's repaired or operator-ruling entry with no edit: line was not refused (rc=$RC): $(grep -m1 -E 'REFUSED|JOINED' "$JO")"
fi
# NL8 twin: the KEY is matched case-insensitively. `- Disposition: Repaired` with no edit: line refuses exactly as the
# lowercase spelling does; the ALLOW twin is the same capitalised key with `Skipped (nit)`.
p_nlnoedit_cap() { p_nlnoedit "$1" 'Repaired' 'Disposition'; }
if p_nlnoedit_cap "$JOIN"; then
  _nl8c=$RC; p_nlnoedit "$JOIN" 'Skipped (nit)' 'Disposition'
  if [ "$RC" -eq 0 ] && has "$JO" "stories-serial-repair-p1.md (2 parts, 0 writers)"; then
    ok "NL8c: a lane's \`- Disposition: Repaired\` entry with no edit: line -> REFUSED 'records no dispatched write' (rc=$_nl8c); the same capitalised key \`Skipped (nit)\` -> JOINED"
  else bad "NL8c: the ALLOW twin \`Disposition: Skipped (nit)\` did not join (rc=$RC): $(grep -m1 REFUSED "$JO")"; fi
else
  bad "NL8c: a capitalised \`Disposition: Repaired\` entry with no edit: line was not refused (rc=$RC): $(grep -m1 -E 'REFUSED|JOINED' "$JO")"
fi
fi

# ------------------------------------------------------------------------- CLI-A: one end to end per mode (clause 6)
# The same predicates with every subject a CLI child and every world built afresh by the CLI hook. A pass and a
# refusal for each join mode this half owns: subject (SJ1, SJ2), files parts (J-shaped lanes LN1, EC32), document
# --rerun (RR1, which refuses then joins), the two-record --escalations (LN6), and the explicit window (NL1, NL3).
if ua_on CLI; then
ua_cli() { # <label> <predicate>
  local l="$1"; shift
  if UA_CLI=1 "$@" "$JOIN"; then ok "CLI-A $l: $1 holds end to end, every subject a CLI child"
  else bad "CLI-A $l: $1 failed end to end (rc=${RC:-?}): $(head -3 "$JO" 2>/dev/null)"; fi
}
ua_cli subject-pass p_sjoin
ua_cli subject-refuse p_sjspec2
ua_cli files-refuse p_partsilent
ua_cli files-lanes-pass p_lanefiles
ua_cli document-rerun p_rrgraph
ua_cli escalations-two-records p_lanerec
ua_cli window-pass p_nl2lane
ua_cli window-refuse p_nlcites
fi

# LEAD-A: no hook drive above fell past arm 2 (a lead or non-edit payload), where in process and CLI part ways.
# Its self-probe first: one lead drive in process, with the marker pointed at a scratch path, must write it.
_lp="$WORK/ua.lead-probe"
( UA_LEADF="$_lp"; _w="$(new_world)"; drive "$_w" Edit "$_w/$REL/$S21" "" )
if [ ! -e "$_lp" ]; then bad "LEAD-A: FIXTURE BROKEN -- the self-probe's lead drive wrote no marker, so LEAD-A cannot fire"
elif [ ! -e "$UA_LEADF" ]; then ok "LEAD-A: every in-process hook drive was a dispatched edit that ended inside hook_pretool_head"
else bad "LEAD-A: a hook drive returned from hook_pretool_head (a lead or non-edit payload); its later arms ran in no process"; fi
echo "$NAME: $fails failure(s)"
[ -z "${UA_ONLY:-}" ] || { echo "$NAME: UA_ONLY=$UA_ONLY ran a subset; never a verdict" >&2; exit 2; }
[ "$fails" -eq 0 ]
