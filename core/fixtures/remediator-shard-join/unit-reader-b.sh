#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
# remediator-shard-join/unit-reader-b.sh -- the reader-level cells of half B, asked IN PROCESS. Driven by run.sh,
# which passes its own arguments through (--matrix prints this file's MATRIX rows; the header block is run.sh's).
#
# Families: L1-L4 and HX, J, D, A, U1-U5, B2 and SJ0 (one subject world), PS5 PS6 PS9 PS12, SP1-SP11, AW, CP/CP2,
# D5/D6 and DX1, H1/H2, UF/UFm, PLAIN-B. Each cell asserts the decision its end-to-end cell in run.sh asserted, through
# the SAME lib.sh predicate, unchanged. What changes is how a predicate's `bash <subject>` runs: the `bash` function
# below catches the five subjects by path and runs each in a subshell of this process --
#   the join (and any mutated copy)     join_main, the join sourced once here (a copy is sourced in its subshell)
#   the remediation guard hook (+copy)  hook_pretool_head, the hook sourced in the subshell (its top level reads
#                                       CLAUDE_PROJECT_DIR and stamps TIMESTAMP through `date`, so per call)
#   the derivation-capture hook (+copy) the hook sourced in the subshell with no arguments, as its CLI has
#   validate-artifact-derivations.sh    sourced in the subshell with the CLI's arguments
#   validate-adversarial-convergence.sh the same (H1/H2); it resolves its siblings from BASH_SOURCE, not $0
# -- and every other program, and every program a subject itself starts, as a child, exactly as before. The subshell
# first reduces its names to what a CLI child starts with (ub_scrub): the exported environment, a VAR=x prefix
# included, plus the join's own top-level names; and `set +o pipefail`, which lib.sh sets and no subject does.
#
# WHAT A SUBSHELL CANNOT REPRODUCE, and why it does not move a decision here:
# - hook_pretool_head is arms 0-2 only. A dispatched (agent_id) Edit/Write/MultiEdit ends inside it, exactly as the
#   CLI does. A LEAD payload (no agent_id) or a Read falls past arm 2 in the CLI and through the end of the function
#   here; only arm 2 writes the artifact or verdict ledger, so L1's "the lead's edit and a Read add no row" is the
#   same decision either way. No cell here reads a lead drive's hook output.
# SEAM-B cells below hold each in-process route byte-identical to the CLI on one passing and one refusing input.
# CLI-B cells keep ONE end-to-end pass and refusal per join mode this half owns (clause 6): UB_CLI=1 in front of
# the same predicate runs every subject as a child.
#
# MUTANTS. Each mutant is a mutated copy in a copy of its program's directory, cmp -s guarded, and scores only the
# cells its MUTANT-MATRIX row in run.sh names (the deciding cell and its twin), in process: a join copy is sourced
# inside the subshell of each join call the owning predicate makes, a hook copy likewise.
#
# Exit: 0 every cell passed, 1 a cell failed, 2 the fixture could not run.
set -u
NAME="remediator-shard-join-reader-b"
MATRIX=0
[ "${1:-}" = --matrix ] && MATRIX=1
UB_HERE="$(cd "$(dirname "$0")" && pwd)"
[ -f "$UB_HERE/lib.sh" ] || { echo "FIXTURE BROKEN: lib.sh is absent beside $0; nothing was asserted" >&2; exit 2; }
# shellcheck source=/dev/null
. "$UB_HERE/lib.sh" > /dev/null || { echo "FIXTURE BROKEN: sourcing lib.sh failed" >&2; exit 2; }
MUT_LIB="$(cd "$HERE/../lib" 2>/dev/null && pwd)/mutant.sh"
[ -f "$MUT_LIB" ] || { echo "FIXTURE BROKEN: lib/mutant.sh not found beside $HERE" >&2; exit 2; }
# shellcheck source=/dev/null
. "$MUT_LIB"
N_MROWS=0
mrow() { [ "$MATRIX" = 1 ] || return 0; N_MROWS=$((N_MROWS + 1)); echo "  MATRIX $*"; }

# ------------------------------------------------------------------------- the in-process route
UB_V0=" $(compgen -v | tr '\n' ' ') "; UB_F0=" $(compgen -A function | tr '\n' ' ') "
# shellcheck source=/dev/null
. "$JOIN" || { echo "FIXTURE BROKEN: sourcing $JOIN failed" >&2; exit 2; }
declare -F join_main >/dev/null || { echo "FIXTURE BROKEN: $JOIN defined no join_main when sourced; nothing was asserted" >&2; exit 2; }
# The join's own top-level names: what sourcing it added, measured, never hand-listed.
UB_JV=""; for _ub in $(compgen -v); do case "$UB_V0" in *" $_ub "*) ;; *) UB_JV="$UB_JV $_ub" ;; esac; done
UB_JF=""; for _ub in $(compgen -A function); do case "$UB_F0" in *" $_ub "*) ;; *) UB_JF="$UB_JF $_ub" ;; esac; done
case " $UB_JV " in *" refuse_n "*) ;; *) echo "FIXTURE BROKEN: the join's measured top-level names lack refuse_n" >&2; exit 2 ;; esac
ub_scrub() { # <keep vars> <keep funcs> -- this subshell's names reduced to a CLI child's
  local _uv _ue
  _ue=" $(compgen -e | tr '\n' ' ') "
  for _uv in $(compgen -v); do
    case "$_uv" in
      BASH*|IFS|OPTIND|OPTERR|OPTARG|PPID|UID|EUID|SHELLOPTS|HISTCMD|LINENO|RANDOM|SECONDS|FUNCNAME|PIPESTATUS|GROUPS|DIRSTACK|HOSTTYPE|MACHTYPE|OSTYPE|HOSTNAME|SHLVL|PWD|OLDPWD|_|UB_*|_uv|_ue|PS1|PS2|PS4) continue ;;
    esac
    case "$_ue" in *" $_uv "*) continue ;; esac
    case " $1 " in *" $_uv "*) continue ;; esac
    unset -v "$_uv" 2>/dev/null; unset -v "$_uv" 2>/dev/null
  done
  for _uv in $(compgen -A function); do
    case " $2 bash ub_scrub " in *" $_uv "*) ;; *) unset -f "$_uv" ;; esac
  done
}
bash() {
  if [ -n "${UB_IN:-}" ] || [ -n "${UB_CLI:-}" ]; then command bash "$@"; return; fi
  case "${1:-}" in
    "$JOIN") UB_K=join ;;
    */join-remediator-shards.sh) UB_K=jcopy ;;
    */ai-dlc-gate-remediation-guard.sh) UB_K=hook ;;
    */ai-dlc-derivation-capture.sh) UB_K=cap ;;
    */validate-artifact-derivations.sh|*/validate-adversarial-convergence.sh) UB_K=dval ;;
    *) command bash "$@"; return ;;
  esac
  UB_F="$1"; shift
  (
    UB_IN=1; set +o pipefail
    case "$UB_K" in
      join) ub_scrub "$UB_JV" "$UB_JF"; join_main "$@" ;;
      jcopy) ub_scrub "" ""; . "$UB_F"; join_main "$@" ;;
      hook) ub_scrub "" ""; set --; . "$UB_F"; hook_pretool_head ;;
      cap) ub_scrub "" ""; set --; . "$UB_F" ;;
      dval) ub_scrub "" ""; . "$UB_F" "$@" ;;
    esac
  )
}

# ------------------------------------------------------------------------- SEAM-B: each route byte-identical to the CLI
sj_world_pass() { local w; w="$(new_world)"; three_writers "$w"; part "$w" 01 2.1; part "$w" 02 2.2; part "$w" 03 3.1; stamp "$w"; printf '%s' "$w"; }
ub_join() { # <cli 0|1> <world> args... -> "rc|output", run on a fresh copy of the world
  local c="$1" d o rc; d="$(mktemp -d "$WORK/ub.XXXXXX")" && cp -R "$2" "$d/w" || return 1
  shift 2
  o="$(UB_CLI="${c#0}" AI_DLC_PROJECT_ROOT="$d/w" bash "$JOIN" "$@" 2>&1)"; rc=$?
  printf '%s|%s' "$rc" "${o//$d/WORLD}"
}
_w="$(sj_world_pass)"; _u="$(jnow)"
_pa=(--sprint 305 --artifact stories --pass 1 --artifact-path "$SLOT" --since 2000-01-01T00:00:00Z --until "$_u")
_ra=(--sprint 305 --artifact stories --pass 1 --since 2000-01-01T00:00:00Z --until "$_u")
_pi="$(ub_join 0 "$_w" "${_pa[@]}")"; _pc="$(ub_join 1 "$_w" "${_pa[@]}")"
_ri="$(ub_join 0 "$_w" "${_ra[@]}")"; _rc="$(ub_join 1 "$_w" "${_ra[@]}")"
if [ "${_pc%%|*}" = 0 ] && [ "${_rc%%|*}" = 2 ] && [ "$_pi" = "$_pc" ] && [ "$_ri" = "$_rc" ] && [ "$_pc" != "$_rc" ]; then
  ok "SEAM-B-JOIN: the bash override's in-process join (scrubbed names, pipefail off) answers byte-identically to the CLI child on a passing join (rc 0) and a refusing one (rc 2), and the two differ"
else
  bad "SEAM-B-JOIN: pass cli=[${_pc%%|*}] equal=$([ "$_pi" = "$_pc" ] && echo y || echo n); refuse cli=[${_rc%%|*}] equal=$([ "$_ri" = "$_rc" ] && echo y || echo n)"
fi
ub_hook() { # <cli 0|1> <agent> [ts] -> the world's ledger rows (ts and root removed when unpinned) and the hook's stdout|rc
  local w o rc; w="$(new_world)"
  jq -nc --arg f "$w/$REL/$S21" --arg a "$2" '{session_id:"t", tool_name:"Edit", transcript_path:"", tool_input:{file_path:$f}} + (if $a == "" then {} else {agent_id:$a} end)' > "$WORK/ubh.payload"
  if [ -n "${3:-}" ]; then
    o="$(UB_CLI="${1#0}" FIX_DRIVE_TS="$3" PATH="$DSHIM:$PATH" CLAUDE_PROJECT_DIR="$w" bash "$HOOK" < "$WORK/ubh.payload" 2>&1)"; rc=$?
    jq -c 'del(.root)' "$w/_bmad-output/planning-artifacts/.artifact-writes.jsonl" 2>/dev/null | sed "s#$w#WORLD#g"
  else
    o="$(UB_CLI="${1#0}" CLAUDE_PROJECT_DIR="$w" bash "$HOOK" < "$WORK/ubh.payload" 2>&1)"; rc=$?
    jq -c 'del(.ts, .root)' "$w/_bmad-output/planning-artifacts/.artifact-writes.jsonl" 2>/dev/null | sed "s#$w#WORLD#g"
  fi
  printf '%s|%s' "${o//$w/WORLD}" "$rc"
}
_hi="$(ub_hook 0 "$AG1" 2026-06-01T00:05:00Z)"; _hc="$(ub_hook 1 "$AG1" 2026-06-01T00:05:00Z)"
_ui="$(ub_hook 0 "$AG2")"; _uc="$(ub_hook 1 "$AG2")"
if [ "$_hi" = "$_hc" ] && [ "$_ui" = "$_uc" ] && [ "$_hc" != "$_uc" ] && printf '%s' "$_hc" | grep -qF '"ts":"2026-06-01T00:05:00Z"'; then
  ok "SEAM-B-HOOK: the override's in-process hook writes the CLI hook's ledger row byte-for-byte (root aside) with the date shim's pinned ts reaching the hook's TIMESTAMP, and the same for an unpinned drive"
else
  bad "SEAM-B-HOOK: pinned in=[$_hi] cli=[$_hc]; unpinned in=[$_ui] cli=[$_uc]"
fi
ub_cap() { # <cli 0|1> -> the D5 world's stale control (rc 2) and accepted document-naming part (rc 0), "rc:rc|stderr"
  local w c e1 e2 r1 r2
  w="$(deriv_world)" || { printf 'NOWORLD'; return; }
  c="$w/_bmad-output/ctl.md"
  printf '```derived\n$ grep -c Repaired %s\n5\n```\n' "$DOCREL" > "$c"
  UB_CLI="${1#0}" capture "$DHOOK" "$w" "$c"; r1=$CAP_RC; e1="$(sed -e "s#$w#WORLD#g" -e 's#ai-dlc-derivcap\.[A-Za-z0-9]*#DERIVCAP#g' "$CAP_ERR")"
  fence_part "$w" "$DOCREL"
  UB_CLI="${1#0}" capture "$DHOOK" "$w" "$w/$RDREL/2.md"; r2=$CAP_RC; e2="$(cat "$CAP_ERR")"
  printf '%s:%s|%s|%s' "$r1" "$r2" "$e1" "$e2"
}
_ci="$(ub_cap 0)"; _cc="$(ub_cap 1)"
if [ "${_cc%%|*}" = "2:0" ] && [ "$_ci" = "$_cc" ] && printf '%s' "$_cc" | grep -qF "is not backed by"; then
  ok "SEAM-B-CAPTURE: the derivation-capture hook sourced in process refuses D5's stale control (rc 2, the same stderr) and accepts the document-naming part (rc 0, silent), byte-identically to the CLI hook"
else
  bad "SEAM-B-CAPTURE: in=[${_ci%%|*}] cli=[${_cc%%|*}] equal=$([ "$_ci" = "$_cc" ] && echo y || echo n)"
fi
ub_dval() { # <cli 0|1> <world> <target> -> "rc|output"
  local o rc; o="$( cd "$2" && UB_CLI="${1#0}" AI_DLC_PROJECT_ROOT="$2" bash "$2/scripts/ai-dlc/validate-artifact-derivations.sh" "$3" 2>&1 )"; rc=$?
  printf '%s|%s' "$rc" "${o//$2/WORLD}"
}
_dw="$(deriv_world)" && printf '```derived\n$ grep -c Goals %s\n7\n```\n' "$DOCREL" > "$_dw/$SLOT/stale.md"
_vpi="$(ub_dval 0 "$_dw" "$SLOT/architecture-impact.md")"; _vpc="$(ub_dval 1 "$_dw" "$SLOT/architecture-impact.md")"
_vri="$(ub_dval 0 "$_dw" "$SLOT/stale.md")"; _vrc="$(ub_dval 1 "$_dw" "$SLOT/stale.md")"
if [ "${_vpc%%|*}" = 0 ] && [ "${_vrc%%|*}" = 1 ] && [ "$_vpi" = "$_vpc" ] && [ "$_vri" = "$_vrc" ]; then
  ok "SEAM-B-DVAL: validate-artifact-derivations.sh sourced in process answers a reproducing file (rc 0) and a stale one (rc 1) byte-identically to the CLI"
else
  bad "SEAM-B-DVAL: pass cli rc=${_vpc%%|*} equal=$([ "$_vpi" = "$_vpc" ] && echo y || echo n); stale cli rc=${_vrc%%|*} equal=$([ "$_vri" = "$_vrc" ] && echo y || echo n)"
fi

# THE THREE-WRITER LEDGER, BUILT ONCE. three_writers drives the real hook three times per world; here the three
# rows are driven ONCE into a template world and appended to each later world with `root` (the world's physical
# path, which content-seal.sh filters on) rewritten for it. SEAM-B-TPL holds a copied world equal to a
# hook-driven one over the whole tree, ts aside, and its control shows the comparison sees `root`.
UB_TW="$(new_world)" && three_writers "$UB_TW" || { echo "FIXTURE BROKEN: the template three-writer world did not build" >&2; exit 2; }
UB_TL="$UB_TW/_bmad-output/planning-artifacts/.artifact-writes.jsonl"
[ "$(grep -c . "$UB_TL")" = 3 ] || { echo "FIXTURE BROKEN: the template ledger holds $(grep -c . "$UB_TL") rows, not 3" >&2; exit 2; }
ub_tw_copy() { # <world> [keep-root] -- append the template rows, root rewritten unless keep-root
  local r; r="$(cd "$1" && pwd -P)" || return 1
  if [ -n "${2:-}" ]; then cat "$UB_TL" >> "$1/_bmad-output/planning-artifacts/.artifact-writes.jsonl"
  else jq -c --arg r "$r" '.root = $r' "$UB_TL" >> "$1/_bmad-output/planning-artifacts/.artifact-writes.jsonl"; fi
}
ub_tree() { # <world> -> every file's relative path and bytes, the ledger's ts and the world's path normalised
  local f; ( cd "$1" && find . -type f | LC_ALL=C sort ) | while IFS= read -r f; do
    printf '== %s\n' "$f"
    case "$f" in *.jsonl) jq -c '.ts = "TS"' "$1/$f" | sed "s#$(cd "$1" && pwd -P)#WORLD#g" ;; *) cat "$1/$f" ;; esac
  done
}
_ta="$(new_world)"; three_writers "$_ta"; _tb="$(new_world)"; ub_tw_copy "$_tb"; _tc="$(new_world)"; ub_tw_copy "$_tc" keep
_tA="$(ub_tree "$_ta")"; _tB="$(ub_tree "$_tb")"; _tC="$(ub_tree "$_tc")"
if [ "$_tA" = "$_tB" ] && [ "$_tA" != "$_tC" ] && printf '%s' "$_tA" | grep -qF '"root":"WORLD"'; then
  ok "SEAM-B-TPL: a world given the template's three rows (root rewritten) equals a world the hook drove three times, whole tree, ts aside; the same copy with root left as the template's differs"
else
  bad "SEAM-B-TPL: driven=copied $([ "$_tA" = "$_tB" ] && echo y || echo n); control (root kept) differs $([ "$_tA" != "$_tC" ] && echo y || echo n)"
fi
three_writers() { ub_tw_copy "$1"; }

# L1-L3: the ledger, as the REAL hook writes it.
w="$(new_world)"; three_writers "$w"
drive "$w" Edit "$w/$REL/$S21" ""                     # the LEAD: no agent_id
drive "$w" Read "$w/$REL/$S22" "$AG1"                 # not an edit
L="$w/_bmad-output/planning-artifacts/.artifact-writes.jsonl"
if [ -f "$L" ]; then
  n_rows="$(grep -c . "$L")" || n_rows=0
  n_kind="$(jq -r 'select(.kind == "artifact-write") | .path' "$L" | sort -u | grep -c .)" || n_kind=0
  n_path="$(jq -r '.path' "$L" | grep -c "^$REL/")" || n_path=0
  if [ "$n_rows" -eq 3 ] && [ "$n_kind" -eq 3 ] && [ "$n_path" -eq 3 ]; then
    ok "L1: three dispatched edits (absolute, relative, absolute) -> 3 rows, kind artifact-write, ONE path spelling; the lead's edit and a Read add none"
  else
    bad "L1: the hook wrote rows=$n_rows kind=$n_kind normalized=$n_path, expected 3/3/3: $(cat "$L")"
  fi
else
  bad "L1: the real hook wrote no .artifact-writes.jsonl for three dispatched edits"
fi
[ ! -e "$w/_bmad-output/gate-adjudication/.verdict-writes.jsonl" ] \
  && ok "L2: planning-artifact writes never reach .verdict-writes.jsonl, whose earliest row is the binding epoch" \
  || bad "L2: a planning-artifact write reached .verdict-writes.jsonl -- it moves the verdict binding's epoch"
w2="$(new_world)"
drive "$w2" Write "$w2/_bmad-output/gate-adjudication/story-20260811T193044Z.verdict.json" "$AG1"
if [ -f "$w2/_bmad-output/gate-adjudication/.verdict-writes.jsonl" ] \
   && [ ! -e "$w2/_bmad-output/planning-artifacts/.artifact-writes.jsonl" ]; then
  ok "L3: the mirror -- a dispatched verdict write lands in .verdict-writes.jsonl and not in the artifact ledger (the route is by path, both ways)"
else
  bad "L3: a dispatched verdict write did not route to .verdict-writes.jsonl alone"
fi

# L4: the hook's three evidence keys, on both ledgers. A payload carrying tool_use_id and the parent
# transcript_path -> the row carries that id and path; agent_transcript true exactly when
# <transcript minus .jsonl>/subagents/agent-<id>.jsonl exists; a payload with no tool_use_id -> the key
# present and EMPTY. The allow is unchanged: hook stdout and rc are byte-equal for the keyed and the
# keyless payload of the same write. A function of the hook, so the HX mutants below score it.
l4_check() { # <hook> -> 0 when every property holds; L4_MSG names what was read
  local HOOK="$1" w tp L V l4 l4v want l4k l4n
  w="$(new_world)"; tp="$w/projects/sess-9.jsonl"; mkdir -p "$w/projects/sess-9/subagents"
  : > "$w/projects/sess-9/subagents/agent-$AG1.jsonl"
  drive "$w" Edit "$w/$REL/$S21" "$AG1" toolu_L4A "$tp"
  drive "$w" Edit "$w/$REL/$S22" "$AG2" toolu_L4B "$tp"
  drive "$w" Edit "$w/$REL/$S31" "$AG3"
  drive "$w" Write "$w/_bmad-output/gate-adjudication/story-20260811T193044Z.verdict.json" "$AG1" toolu_L4V "$tp"
  L="$w/_bmad-output/planning-artifacts/.artifact-writes.jsonl"; V="$w/_bmad-output/gate-adjudication/.verdict-writes.jsonl"
  l4="$(jq -rs '[.[] | [.agent_id, (.tool_use_id | tostring), (.transcript_path | tostring), (.agent_transcript | tostring)] | join(",")] | join(" ")' "$L" 2>/dev/null)"
  l4v="$(jq -rs '[.[] | [(.tool_use_id | tostring), (.agent_transcript | tostring)] | join(",")] | join(" ")' "$V" 2>/dev/null)"
  want="$AG1,toolu_L4A,$tp,true $AG2,toolu_L4B,$tp,false $AG3,,,false"
  jq -nc --arg f "$w/$REL/$S21" --arg tp "$tp" --arg a "$AG1" '{session_id:"t", tool_name:"Edit", transcript_path:$tp, tool_use_id:"toolu_L4C", agent_id:$a, tool_input:{file_path:$f}}' > "$WORK/l4k.json"
  jq -nc --arg f "$w/$REL/$S21" --arg a "$AG1" '{session_id:"t", tool_name:"Edit", transcript_path:"", agent_id:$a, tool_input:{file_path:$f}}' > "$WORK/l4n.json"
  CLAUDE_PROJECT_DIR="$w" bash "$HOOK" < "$WORK/l4k.json" > "$WORK/l4k.out" 2>&1; l4k=$?
  CLAUDE_PROJECT_DIR="$w" bash "$HOOK" < "$WORK/l4n.json" > "$WORK/l4n.out" 2>&1; l4n=$?
  L4_MSG="rows [$l4] want [$want]; verdict row [$l4v] want [toolu_L4V,true]; hook rc keyed=$l4k keyless=$l4n; stdout equal: $(cmp -s "$WORK/l4k.out" "$WORK/l4n.out" && echo yes || echo no)"
  [ "$l4" = "$want" ] && [ "$l4v" = "toolu_L4V,true" ] && [ "$l4k" -eq 0 ] && [ "$l4n" -eq 0 ] && cmp -s "$WORK/l4k.out" "$WORK/l4n.out"
}
if l4_check "$HOOK"; then
  ok "L4: tool_use_id and transcript_path recorded from the payload on both ledgers, an absent id an EMPTY key, agent_transcript true only where the agent's own transcript exists; the allow byte-identical with and without the keys"; B_L4=1
else
  bad "L4: $L4_MSG"
fi
# HX1/HX2: L4's failing direction, on copies of the hook. tool_use_id never read from the payload
# (both ledgers), and agent_transcript never true -- each must turn L4 red.
for hx in 'HX1|s/tool_use_id: (\.tool_use_id \/\/ "")/tool_use_id: ""/g|tool_use_id never read' \
          'HX2|s/^    _rev_at=true$/    _rev_at=false/|agent_transcript never true'; do
  _id="${hx%%|*}"; _r="${hx#*|}"; _e="${_r%%|*}"; _lab="${_r#*|}"
  _hd="$(mktemp -d "$WORK/$_id.XXXXXX")" || exit 2
  sed "$_e" "$HOOK" > "$_hd/ai-dlc-gate-remediation-guard.sh"
  if cmp -s "$HOOK" "$_hd/ai-dlc-gate-remediation-guard.sh"; then
    bad "$_id: FIXTURE STALE -- the hook mutation ($_lab) matched nothing; re-anchor it, never relax the assertion"
  elif ! l4_check "$_hd/ai-dlc-gate-remediation-guard.sh"; then
    mrow "$_id" L4=1
    mutant_killed "${B_L4:-0}" "$_id" "$_id $_lab: KILLED by [L4]"
  else
    mrow "$_id" L4=0
    bad "$_id $_lab: SURVIVED -- L4 holds against a hook that does not record the key"
  fi
done

p_disjoint "$JOIN"  && ok "J1: three disjoint writers and three parts (real s305 repair blocks, no agent id) -> JOINED, 3 parts / 3 writers" \
  || bad "J1: a disjoint shard set did not join (rc=$RC): $(cat "$JO")"
p_overlap "$JOIN"   && ok "J2: one file written by two agents under two path spellings -> REFUSED 'more than one agent', nothing written" \
  || bad "J2: a two-writer file was not refused by the overlap arm (rc=$RC): $(cat "$JO")"
p_missing "$JOIN"   && ok "J3: a writer whose part never arrived -> REFUSED 'cited by no shard record -- a missing shard', nothing written" \
  || bad "J3: a missing part was not refused (rc=$RC): $(cat "$JO")"
p_unwritten "$JOIN" && ok "J4: a part citing a file no agent wrote -> REFUSED 'which no dispatched agent wrote', nothing written" \
  || bad "J4: a part citing an unwritten file was not refused (rc=$RC): $(cat "$JO")"
p_epics "$JOIN"     && ok "J6: a shard whose part cites ONLY epics/epics.md (a real s310 block), with --artifact-path the sprint slot -> JOINED, 4 parts / 4 writers" \
  || bad "J6: an epics-only shard did not join under the sprint slot (rc=$RC): $(cat "$JO")"
p_shardrow "$JOIN"  && ok "J7: remediators' own part-file writes under s305/shards/ are ledger rows and are not read as a missing shard -> JOINED" \
  || bad "J7: a part-file write under shards/ was read as an artifact write (rc=$RC): $(cat "$JO")"
p_bothdirs "$JOIN"  && ok "J5: shards/stories-p1/ (adversary) beside shards/stories-repair-p1/ for the same pass -> the join reads only its own dir, 3 parts" \
  || bad "J5: the join read the adversary shard dir of the same pass (rc=$RC): $(cat "$JO")"
p_docjoin "$JOIN"    && ok "D1: --document, three section writers and three parts -> JOINED, 3 parts / 3 writers, the document ASSEMBLED with all three edits, sections/ cleared, the record opening with the J2 link triple (root-relative artifact, split sha before, assembled sha after)" \
  || bad "D1: a disjoint section repair did not join and assemble (rc=$RC): $(cat "$JO")"
p_docoverlap "$JOIN" && ok "D2: --document, one section copy written by two agents -> REFUSED 'more than one agent', no record, the document untouched" \
  || bad "D2: two writers on one section were not refused, or the document moved (rc=$RC): $(cat "$JO")"
p_asmrefuse "$JOIN"  && ok "D3: --document over a document written in place after the split -> the assembler's REFUSED line, exit 2, NO record written" \
  || bad "D3: an assembly refusal did not stop the join before its record (rc=$RC): $(cat "$JO")"
p_filesguard "$JOIN" && ok "D4: the same split dir joined WITHOUT --document -> REFUSED 'was split by section', nothing written" \
  || bad "D4: a files-mode join accepted a section-split repair dir (rc=$RC): $(cat "$JO")"
p_absroot "$JOIN"    && ok "A1: a part citing its file ABSOLUTELY under the root -> JOINED, 1 part / 1 writer" \
  || bad "A1: an absolute citation under the root did not join (rc=$RC): $(cat "$JO")"
p_absforeign "$JOIN" && ok "A2: the same file cited under a FOREIGN root -> REFUSED 'which no dispatched agent wrote', nothing written" \
  || bad "A2: a foreign-root citation was not refused as unwritten (rc=$RC): $(cat "$JO")"
p_absnested "$JOIN"  && ok "A3: AI_DLC_STATE_DIR=out/_bmad-output, an absolute citation under it -> JOINED (the state dir's parent is stripped, not the root)" \
  || bad "A3: a nested state dir's absolute citation did not join (rc=$RC): $(cat "$JO")"
p_absslash "$JOIN"   && ok "A4: AI_DLC_PROJECT_ROOT with a trailing slash, an absolute citation -> JOINED" \
  || bad "A4: a trailing-slash root's absolute citation did not join (rc=$RC): $(cat "$JO")"
p_absdouble "$JOIN"  && ok "A7: an absolute citation carrying a doubled slash (a TMPDIR ending in /) -> JOINED" \
  || bad "A7: a doubled-slash absolute citation did not join (rc=$RC): $(cat "$JO")"
p_basecite "$JOIN"   && ok "A5: control -- a bare basename citation still resolves -> JOINED" \
  || bad "A5: a basename citation stopped resolving (rc=$RC): $(cat "$JO")"
if p_unwrittenmsg "$JOIN"; then ok "A6: the UNWRITTEN refusal names the Bash cause and the re-dispatch, and not hand-assembly"; B_A6=1
else bad "A6: the UNWRITTEN refusal line does not name the Bash cause and the re-dispatch, or names hand-assembly: $(cat "$JO")"; fi
# A8-A11 (BL-803): the UNWRITTEN remedy read from the ledger with the time filter dropped; A6 is the NONE control.
if p_uwbefore "$JOIN"; then ok "A8: the cited file written only BEFORE --since, at three ts by two agents neither of them the part's writer -> the LATEST row's ts and agent, the record-rewrite remedy, and no Bash cause"; B_A8=1
else bad "A8: the before-window remedy is not the latest row's, or still names the Bash cause (rc=$RC): $(cat "$JO")"; fi
p_uwafter "$JOIN" && ok "A9: the cited file written only AFTER --until -> the EARLIEST after-window row and the new --until remedy" \
  || bad "A9: the after-window remedy is absent or not the earliest row's (rc=$RC): $(cat "$JO")"
p_uwaside "$JOIN" && ok "A10: a --rerun part citing a file whose only in-window row the re-run superseded -> the set-aside remedy naming that row" \
  || bad "A10: the set-aside remedy is absent (rc=$RC): $(cat "$JO")"
p_uwboth "$JOIN" && ok "A11: a before- and an after-window row -> the BEFORE clause, then '; also ' and the AFTER clause" \
  || bad "A11: both window sides were not named, joined by '; also ' (rc=$RC): $(cat "$JO")"
if p_uwamb "$JOIN"; then ok "A12: a cited basename resolving to two paths once the time filter is dropped -> exactly the NONE clause"; B_A12=1
else bad "A12: the ambiguous-once-untimed remedy is not exactly the NONE clause (rc=$RC): $(cat "$JO")"; fi
p_sjaside "$JOIN" && ok "A13: subject mode, a part citing the prd.md written IN PLACE, no --rerun -> the no-rerun set-aside clause, and no '(a --rerun supersedes it)'" \
  || bad "A13: the subject-mode set-aside remedy is not the no-rerun text (rc=$RC): $(cat "$JO")"
if p_uwshard "$JOIN"; then ok "A14: a token that is a /-suffix only of a path under shards/, written in the window -> exactly the NONE clause"; B_A14=1
else bad "A14: the shards/ row reached the remedy lookup (rc=$RC): $(cat "$JO")"; fi
if p_sjrraside "$JOIN"; then ok "A15: subject mode WITH --rerun (A13's in-place prd.md row, another section re-run) -> exactly the rerun set-aside clause, '(a --rerun supersedes it)' included"; B_A15=1
else bad "A15: the subject-mode --rerun set-aside remedy is not the rerun text (rc=$RC): $(cat "$JO")"; fi
# U5: the ASIDE branch keyed on SUBJMODE instead of RERUN -> A15 dies, A6 unchanged. A10 (files, --rerun)
# and A13 (subject, none) cannot see it: across them the two flags vary together. The anchor is the
# ASIDE branch's own 6-space indent; the re-run narrowing's `if [ -n "$RERUN" ]` sits at column 0.
_ud="$(mktemp -d "$WORK/U5.XXXXXX")" || exit 2
cp "$(dirname "$JOIN")"/*.sh "$_ud/" || { echo "FIXTURE BROKEN: U5 could not copy the join's sibling scripts" >&2; exit 2; }
sed 's@^      if \[ -n "\$RERUN" \]; then$@      if [ "$SUBJMODE" != 1 ]; then@' "$JOIN" > "$_ud/join-remediator-shards.sh" \
  || { echo "FIXTURE BROKEN: U5 could not write the mutated join" >&2; exit 2; }
if cmp -s "$JOIN" "$_ud/join-remediator-shards.sh"; then
  bad "U5: FIXTURE STALE -- the ASIDE-branch mutation matched nothing in $JOIN; re-anchor it, never relax the assertion"
elif [ "$(diff "$JOIN" "$_ud/join-remediator-shards.sh" | grep -c '^>')" != 1 ]; then
  bad "U5: the ASIDE-branch mutation edited more than one line of $JOIN; re-anchor it on the ASIDE branch alone"
elif [ ! -f "$_ud/validate-adversarial-convergence.sh" ] || ! bash -n "$_ud/join-remediator-shards.sh" 2>/dev/null; then
  bad "U5: the sibling validator is absent from the copy or the mutated join does not parse"
elif p_sjrraside "$_ud/join-remediator-shards.sh"; then
  mrow U5 A15=0
  bad "U5 ASIDE keyed on SUBJMODE: SURVIVED -- A15 holds against the mutated join"
elif ! grep -qF "$SJPA/prd.md was written in the window at " "$JO"; then
  bad "U5: A15 failed for another reason than its remedy text (rc=$RC): $(cat "$JO")"
elif p_unwrittenmsg "$_ud/join-remediator-shards.sh"; then
  mrow U5 A15=1 A6=0
  mutant_killed "$(( ${B_A15:-0} && ${B_A6:-0} ))" U5 "U5 ASIDE keyed on SUBJMODE: KILLED by [A15], and A6 is UNCHANGED"
else
  mrow U5 A15=1 A6=1
  bad "U5: the NONE control A6 also moved under the mutant -- the arms are entangled"
fi
# U3: the lookup's resolution keeps a token resolving to MORE than one path -> A12 dies, A6 unchanged.
# U4: the lookup's SHARD_REL clause deleted (a shards/ row reaches it) -> A14 dies, A6 unchanged.
# Each is a copy in a copy of the join's directory, guarded by cmp -s. U4 deletes the clause only
# inside the lookup's jq program, which opens on the one `jq -rn --arg ap "$APATH"` line; ROWS and
# DROWS carry the same clause and are left alone.
for um in 'U3%s@^        if (n != 1) continue$@        if (n == 0) continue@%ambiguous token resolved%p_uwamb' \
          'U4%/jq -rn --arg ap "\$APATH" --arg sh/,/startswith(\$sh/{/startswith(\$sh/d;}%SHARD_REL clause deleted%p_uwshard'; do
  _id="${um%%\%*}"; _r="${um#*\%}"; _e="${_r%%\%*}"; _r="${_r#*\%}"; _lab="${_r%%\%*}"; _p="${_r#*\%}"
  case "$_p" in p_uwamb) _a=A12 ;; *) _a=A14 ;; esac
  _ud="$(mktemp -d "$WORK/$_id.XXXXXX")" || exit 2
  cp "$(dirname "$JOIN")"/*.sh "$_ud/" || { echo "FIXTURE BROKEN: $_id could not copy the join's sibling scripts" >&2; exit 2; }
  sed "$_e" "$JOIN" > "$_ud/join-remediator-shards.sh" || { echo "FIXTURE BROKEN: $_id could not write the mutated join" >&2; exit 2; }
  if cmp -s "$JOIN" "$_ud/join-remediator-shards.sh"; then
    bad "$_id: FIXTURE STALE -- the $_lab mutation matched nothing in $JOIN; re-anchor it, never relax the assertion"
  elif [ ! -f "$_ud/validate-adversarial-convergence.sh" ] || ! bash -n "$_ud/join-remediator-shards.sh" 2>/dev/null; then
    bad "$_id: the sibling validator is absent from the copy or the mutated join does not parse"
  elif "$_p" "$_ud/join-remediator-shards.sh"; then
    mrow "$_id" "$_a=0"
    bad "$_id $_lab: SURVIVED -- $_p holds against the mutated join"
  elif [ -z "$UW_L" ]; then
    bad "$_id: $_p failed for another reason than its remedy text (rc=$RC): $(cat "$JO")"
  elif p_unwrittenmsg "$_ud/join-remediator-shards.sh"; then
    mrow "$_id" "$_a=1" A6=0
    case "$_a" in
      A12) mutant_killed "$(( ${B_A12:-0} && ${B_A6:-0} ))" "$_id" "$_id $_lab: KILLED by [$_a], and A6 is UNCHANGED" ;;
      *)   mutant_killed "$(( ${B_A14:-0} && ${B_A6:-0} ))" "$_id" "$_id $_lab: KILLED by [$_a], and A6 is UNCHANGED" ;;
    esac
  else
    mrow "$_id" "$_a=1" A6=1
    bad "$_id: the NONE control A6 also moved under the mutant -- the arms are entangled"
  fi
done
# U1: the lookup disabled (every UNWRITTEN takes the NONE text) -> A8 dies, A6 unchanged.
# U2: the EARLIEST before-window row kept instead of the latest -> A8 dies, A6 unchanged.
# Each is a copy in a copy of the join's directory, guarded by cmp -s.
# The list separator is `%`: U2's expression carries `||`.
for um in 'U1%s@^if \[ -n "\$_uw" \]; then$@if false; then@%lookup disabled' \
          'U2%s@ || ts > bt\[p\]) { bt\[p\] = ts@ || ts < bt[p]) { bt[p] = ts@%earliest before-window row'; do
  _id="${um%%\%*}"; _r="${um#*\%}"; _e="${_r%%\%*}"; _lab="${_r#*\%}"
  _ud="$(mktemp -d "$WORK/$_id.XXXXXX")" || exit 2
  cp "$(dirname "$JOIN")"/*.sh "$_ud/" || { echo "FIXTURE BROKEN: $_id could not copy the join's sibling scripts" >&2; exit 2; }
  sed "$_e" "$JOIN" > "$_ud/join-remediator-shards.sh" || { echo "FIXTURE BROKEN: $_id could not write the mutated join" >&2; exit 2; }
  if cmp -s "$JOIN" "$_ud/join-remediator-shards.sh"; then
    bad "$_id: FIXTURE STALE -- the $_lab mutation matched nothing in $JOIN; re-anchor it, never relax the assertion"
  elif [ ! -f "$_ud/validate-adversarial-convergence.sh" ] || ! bash -n "$_ud/join-remediator-shards.sh" 2>/dev/null; then
    bad "$_id: the sibling validator is absent from the copy or the mutated join does not parse"
  elif p_uwbefore "$_ud/join-remediator-shards.sh"; then
    mrow "$_id" A8=0
    bad "$_id $_lab: SURVIVED -- A8 holds against the mutated join"
  elif ! uw_line >/dev/null; then
    bad "$_id: A8 failed for another reason than its remedy text (rc=$RC): $(cat "$JO")"
  elif p_unwrittenmsg "$_ud/join-remediator-shards.sh"; then
    mrow "$_id" A8=1 A6=0
    mutant_killed "$(( ${B_A8:-0} && ${B_A6:-0} ))" "$_id" "$_id $_lab: KILLED by [A8], and A6 is UNCHANGED"
  else
    mrow "$_id" A8=1 A6=1
    bad "$_id: the NONE control A6 also moved under the mutant -- the arms are entangled"
  fi
done

# ---- subject mode. B2 first: a dispatched Write of the SPEC under specs/s9/ is a ledger row, and a
# Write under specs/ outside a sprint slot is not (the near-miss).
SJW="$(subj_world)"
if [ -n "$SJW" ]; then
  drive "$SJW" Write "$SJW/$SPECREL" "$AG1"
  drive "$SJW" Write "$SJW/_bmad-output/specs/README.md" "$AG2"
  n_spec="$(grep -c "\"path\":\"$SPECREL\"" "$SJW/$SJPA/.artifact-writes.jsonl" 2>/dev/null)" || n_spec=0
  n_near="$(grep -c '"path":"_bmad-output/specs/README.md"' "$SJW/$SJPA/.artifact-writes.jsonl" 2>/dev/null)" || n_near=0
  [ "$n_spec" -eq 1 ] && [ "$n_near" -eq 0 ] \
    && ok "B2: the real hook ledgers a dispatched Write of specs/s9/kernel/SPEC.md (1 row) and not one of specs/README.md (0)" \
    || bad "B2: SPEC rows=$n_spec (want 1), specs/README.md rows=$n_near (want 0)"
  n_sec="$(awk -F'\t' '$1 == "part" && $7 != "-"' "$SJW/$SJRD/.subject" | grep -c .)" || n_sec=0
  n_whole="$(awk -F'\t' '$1 == "part" && $7 == "-"' "$SJW/$SJRD/.subject" | grep -c .)" || n_whole=0
  [ "$n_sec" -ge 2 ] && [ "$n_whole" -ge 2 ] \
    && ok "SJ0: the subject seed splits into $n_sec section part(s) and $n_whole whole-file part(s), so both join paths are reachable" \
    || bad "SJ0: FIXTURE BROKEN -- $n_sec section / $n_whole whole-file part(s)"
else
  bad "SJ0: FIXTURE BROKEN -- the subject world did not build"
fi

p_partydoc "$JOIN" && ok "PS5: seats x sections -- a document split into prd-party-repair-p1, joined with --document -> JOINED, sources resolved" \
  || bad "PS5: a section-sharded party repair did not join (rc=$RC): $(cat "$JO")"
p_sjpartysrc "$JOIN" && ok "PS6: --subject --pass party, every part citing a seat file sprint 9 lacks -> REFUSED 'names no seat file' (SJ5 is its ALLOW twin)" \
  || bad "PS6: a subject party repair accepted an unresolvable source (rc=$RC): $(cat "$JO")"
p_partymarked "$JOIN" && ok "PS9: every CITED seat file ends in seat-complete:, the uncited architect-1 does not -> JOINED (the belt is scoped to cited seats)" \
  || bad "PS9: a party repair over finished cited seats did not join (rc=$RC): $(cat "$JO")"
p_partyx4 "$JOIN" && ok "PS12: an earlier step's pre-marker seat cited beside marked architecture seats -> JOINED (its step has no marker)" \
  || bad "PS12: a pre-marker seat of another step was refused (rc=$RC): $(cat "$JO")"

p_specstale "$JOIN" && ok "SP1: --escalations, a spec memlog with a decision AFTER its last phrased Render -> rc 2, REFUSED naming the memlog and '1 (decision) entry(ies) after the last render'" \
  || bad "SP1: a decision after the last re-derived render was not refused (rc=$RC): $(cat "$JO")"
p_specfresh "$JOIN" && ok "SP2: the same memlog with its last decision before the phrased Render -> rc 0, 'rendered through its last decision', ESCALATED-COUNT still printed" \
  || bad "SP2: a rendered-through memlog was refused or its line was not printed (rc=$RC): $(cat "$JO")"
p_spechand "$JOIN" && ok "SP3: an unphrased '(event) Render' (a hand edit's disclosure) then a decision -> rc 0, SPEC-RENDER: SKIP, never read as rendered" \
  || bad "SP3: an unphrased Render line was read as a render (rc=$RC): $(cat "$JO")"
p_specnone "$JOIN" && ok "SP4: no specs directory in the world -> rc 0, SPEC-RENDER: SKIP naming the absent memlog glob" \
  || bad "SP4: an absent spec memlog was refused or not skipped visibly (rc=$RC): $(cat "$JO")"
p_spectwo "$JOIN" && ok "SP5: two memlogs under specs/s305/, one stale -> rc 0, SPEC-RENDER: SKIP naming 2 memlogs (the kernel is exactly one)" \
  || bad "SP5: two spec memlogs were not skipped as ambiguous (rc=$RC): $(cat "$JO")"
p_specother "$JOIN" && ok "SP9: --escalations, a stale memlog in the world but a record citing no specs/s305/ path -> rc 0, the 'cites no specs/s305/ file' SKIP, ESCALATED-COUNT printed" \
  || bad "SP9: a record that repaired no SPEC was judged against the sprint memlog (rc=$RC): $(cat "$JO")"
p_specunread "$JOIN" && ok "SP10: --escalations, a cited stale memlog made unreadable -> rc 2, 'the memlog could not be read' (SKIP SP10 (root) when uid 0)" \
  || bad "SP10: an unreadable memlog was not refused (rc=$RC): $(cat "$JO")"
p_specserial "$JOIN" && ok "SP11: --escalations, a joined record whose terminated serial block alone cites the spec memlog: a decision it appended after the last phrased Render is REFUSED naming the memlog; the Render written after it (before --mark-repair) passes, rendered through" \
  || bad "SP11: the serial block's stale SPEC was not refused, or its rendered SPEC was (rc=$RC): $(cat "$JO")"
p_sjspecstale "$JOIN" && ok "SP6: --subject, the SPEC part's memlog holds a decision after its last phrased Render -> rc 2, REFUSED naming the memlog, no record written" \
  || bad "SP6: subject mode did not refuse a stale SPEC memlog (rc=$RC): $(cat "$JO")"
p_sjspecfresh "$JOIN" && ok "SP7: --subject, the same memlog rendered through its last decision -> JOINED, the record written, SPEC-RENDER: rendered through its last decision" \
  || bad "SP7: subject mode refused or did not report a rendered-through SPEC memlog (rc=$RC): $(cat "$JO")"
p_sjspecnone "$JOIN" && ok "SP8: --subject, the SPEC part's memlog does not exist -> JOINED, SPEC-RENDER: SKIP naming that it does not exist" \
  || bad "SP8: subject mode did not skip a missing SPEC memlog visibly (rc=$RC): $(cat "$JO")"

p_agentwrites "$JOIN" && ok "AW1: --agent-writes <subject> over a ledger where a joined writer edited A, B and (earlier) D, a post-join non-subject edited F and the subject edited C and D -> exactly C, D and the not-covered trailer; an unknown agent -> the trailer alone, rc 0; an extra flag -> REFUSED rc 2" \
  || bad "AW1: --agent-writes did not print exactly the subject's paths plus the trailer, or the zero-row and extra-flag cases failed (rc=$RC): $(cat "$JO")"

if p_checkpart "$JOIN"; then ok "CP1: --check-part on the near-miss 'siblings: checked' part -> rc 2 with the join's own BADSIB line byte-for-byte; a well-formed text-fence part -> rc 0 and it joins; no field -> the re-check remedy, never a re-dispatch; an extra flag -> REFUSED"; B_CP1=1
else bad "CP1: --check-part did not reproduce the join's classifier (rc=$RC): $(cat "$JO")"; fi

# CP2: --check-part with contract_check removed from a copy of the join (the mode then exits 0 without
# classifying the part) -- CP1 must die. The copy sits beside its sibling scripts, which the join
# resolves from its own directory.
CPM="$(mktemp -d "$WORK/cp2.XXXXXX")" || exit 2
cp "$(dirname "$JOIN")"/*.sh "$CPM/" \
  || { echo "FIXTURE BROKEN: CP2 could not copy the join's sibling scripts into $CPM; a join run without them fails p_checkpart for that reason alone, which would read as a kill" >&2; exit 2; }
sed 's/^  contract_refusals 0 "\$(contract_check 0 "\$CHKPART")"$/  contract_refusals 0 ""/' "$JOIN" > "$CPM/join-remediator-shards.sh" \
  || { echo "FIXTURE BROKEN: CP2 could not write the mutated join into $CPM" >&2; exit 2; }
if cmp -s "$JOIN" "$CPM/join-remediator-shards.sh"; then
  bad "CP2: FIXTURE STALE -- the --check-part mutation matched nothing in $JOIN; re-anchor it, never relax the assertion"
elif ! p_checkpart "$CPM/join-remediator-shards.sh"; then
  mrow CP2 CP1=1
  mutant_killed "${B_CP1:-0}" CP2 "CP2 --check-part with contract_check skipped: KILLED by [CP1]"
else
  mrow CP2 CP1=0
  bad "CP2: SURVIVED -- CP1 holds against a --check-part that never runs contract_check"
fi

echo "HERMETIC-CONSUMED core/hooks/ai-dlc-derivation-capture.sh"
if p_derivdoc "$DHOOK"; then ok "D5: a part whose derivation names the DOCUMENT -> the capture hook accepts it (a stale control in the same world refused), the join assembles, the sprint-dir re-run skips the 2 frozen records -> rc 0, and the joined record named as a file reproduces"; B_D5=1
else bad "D5: a document-naming part derivation did not survive capture, join and the gate re-run (hook rc=${CAP_RC:-?}, join rc=$RC, derivations rc=${DV_RC:-?}): $(cat "$CAP_ERR" "$JO" "$DV_OUT" 2>/dev/null)"; fi
if p_derivsec "$DHOOK"; then ok "D6: a part whose derivation names the SECTION FILE -> the capture hook refuses it 'reads the section copy'; written past the hook, the joined record run as a file -> rc 1, and --all over the sprint dir -> rc 1, 2 stale"; B_D6=1
else bad "D6: a section-file part derivation was accepted at write time, or did not go stale at the join (hook rc=${CAP_RC:-?}, join rc=$RC, derivations rc=${DV_RC:-?}): $(cat "$CAP_ERR" "$JO" "$DV_OUT" 2>/dev/null)"; fi

# DX1: the part exemption removed from a copy of the capture hook -- a part whose fence names the
# document is then refused at write time, so D5 must die and D6 must hold.
DX="$(mktemp -d "$WORK/dx1.XXXXXX")" || exit 2
sed 's/^      SEC_DIR="\${PART_DIR}\/sections"$/      SEC_DIR="${PART_DIR}\/sections"; SELF_DOC=""/' "$DHOOK" > "$DX/ai-dlc-derivation-capture.sh"
if cmp -s "$DHOOK" "$DX/ai-dlc-derivation-capture.sh"; then
  bad "DX1: FIXTURE STALE -- the part-exemption mutation matched nothing in $DHOOK; re-anchor it, never relax the assertion"
else
  dx5=ok; p_derivdoc "$DX/ai-dlc-derivation-capture.sh" || dx5=dead
  dx6=ok; p_derivsec "$DX/ai-dlc-derivation-capture.sh" || dx6=dead
  mrow DX1 "D5=$([ "$dx5" = dead ] && echo 1 || echo 0)" "D6=$([ "$dx6" = dead ] && echo 1 || echo 0)"
  if [ "$dx5" = dead ] && [ "$dx6" = ok ]; then
    mutant_killed "$(( ${B_D5:-0} && ${B_D6:-0} ))" DX1 "DX1 the capture hook's part exemption removed: KILLED by [D5] and nothing else"
  else
    bad "DX1 the capture hook's part exemption removed: D5 $dx5, D6 $dx6 (expected D5 dead, D6 ok)"
  fi
fi

# H1/H2: arm H before and after the join, on a series the record repairs.
w="$(new_world)"; three_writers "$w"
part "$w" 01 2.1; part "$w" 02 2.2; part "$w" 03 3.1
pa="$w/_bmad-output/planning-artifacts/s305"
pass_file() { # <n> <major> <verdict> <invoked_at>
  printf '# stories -- adversarial pass %s\n\n<!-- SKILL_INVOCATION_PROVENANCE v1\nskill: ai-dlc-adversary-review\ninvoked_at: %s\ntool_use_id: toolu_01K5RNiCukf8wk54ucijhh%s\nmode: subagent\nlead_role: .claude/skills/ai-dlc/steps/stories-test-strategy.md\nfindings_critical: 0\nfindings_critical_prior_scope: 0\nfindings_major: %s\nfindings_major_underived: 0\nfindings_minor: 0\nverdict: %s\nSKILL_INVOCATION_PROVENANCE_END -->\n' \
    "$1" "$4" "$1" "$2" "$3" > "$pa/stories-adversarial-p$1.md"
}
pass_file 1 3 EXIT_CONDITION_NOT_MET 2026-08-24T15:08:19Z
pass_file 2 0 EXIT_CONDITION_MET 2026-08-24T15:30:09Z
bash "$CONV" --series "$pa/stories-adversarial-p" > "$WORK/h1.out" 2>&1; h1=$?
UB_CLI=1 command bash "$CONV" --series "$pa/stories-adversarial-p" > "$WORK/h1.cli" 2>&1; h1c=$?
run_join "$JOIN" "$w"; jrc=$RC
bash "$CONV" --series "$pa/stories-adversarial-p" > "$WORK/h2.out" 2>&1; h2=$?
UB_CLI=1 command bash "$CONV" --series "$pa/stories-adversarial-p" > "$WORK/h2.cli" 2>&1; h2c=$?
# SEAM-B-CONV: the convergence validator sourced in process answers H1's refusal and H2's pass byte-identically to
# the CLI child, on the same world, and the two answers differ.
if [ "$h1" = "$h1c" ] && [ "$h2" = "$h2c" ] && cmp -s "$WORK/h1.out" "$WORK/h1.cli" && cmp -s "$WORK/h2.out" "$WORK/h2.cli" \
   && [ "$h1c" -eq 1 ] && [ "$h2c" -eq 0 ]; then
  ok "SEAM-B-CONV: validate-adversarial-convergence.sh sourced in process answers arm H's refusal (rc 1) and its pass (rc 0) byte-identically to the CLI"
else
  bad "SEAM-B-CONV: before in=$h1 cli=$h1c equal=$(cmp -s "$WORK/h1.out" "$WORK/h1.cli" && echo y || echo n); after in=$h2 cli=$h2c equal=$(cmp -s "$WORK/h2.out" "$WORK/h2.cli" && echo y || echo n)"
fi
if [ "$h1" -eq 1 ] && has "$WORK/h1.out" "H -- REPAIR-RECORD"; then
  ok "H1: before the join arm H names the missing repair record (the parts in shards/ are invisible to its non-recursive glob)"
else
  bad "H1: before the join arm H did not name the missing record (rc=$h1): $(cat "$WORK/h1.out")"
fi
if [ "$jrc" -eq 0 ] && [ "$h2" -eq 0 ] && ! has "$WORK/h2.out" "H -- REPAIR-RECORD"; then
  ok "H2: after the join the SAME series passes the convergence gate -- the joined record reads structured to arm H"
else
  bad "H2: after the join (rc=$jrc) the convergence gate did not pass (rc=$h2): $(cat "$WORK/h2.out")"
fi
# CLI-B: one end-to-end pass and one end-to-end refusal per join mode this half owns, the same predicates with every
# subject a CLI child. Files mode is SEAM-B-JOIN's; --check-part and --agent-writes each hold rc 0 and rc 2 in one predicate.
ub_cli() { # <label> <predicate>... -> ok when it holds through the CLI
  local l="$1"; shift
  if UB_CLI=1 "$@" "$JOIN"; then ok "CLI-B $l: $1 holds end to end, every subject a CLI child"
  else bad "CLI-B $l: $1 failed end to end (rc=${RC:-?}): $(head -3 "$JO" 2>/dev/null)"; fi
}
ub_cli document-pass p_docjoin
ub_cli document-refuse p_docoverlap
ub_cli escalations-refuse p_specstale
ub_cli escalations-pass p_specfresh
ub_cli check-part p_checkpart
ub_cli agent-writes p_agentwrites
# ---- BL-807, claim 2: an --until later than the join's own clock + 120s is refused; one inside the slack proceeds.
p_untilfut "$JOIN" 3600
if [ "$RC" -eq 2 ] && has "$JO" "$FUT_TXT" && ! has "$JO" "JOINED:"; then
  p_untilfut "$JOIN" 60; _u60=$RC; p_untilfut "$JOIN" 0; _u0=$RC
  if [ "$_u60$_u0" = 00 ]; then ok "UF1: --until now+1h -> REFUSED with the take-it-from-date remedy; now+60s and now -> JOINED"; B_UF1=1
  else bad "UF1: an --until inside the slack did not join (now+60s rc=$_u60, now rc=$_u0)"; fi
else
  bad "UF1: an --until one hour ahead was not refused (rc=$RC): $(head -2 "$JO" | tr '\n' ' ')"
fi

# UFm: the future-until guard removed, in a copy of the join's whole directory, cmp -s guarded.
UFM="$(mktemp -d "$WORK/ufm.XXXXXX")" || exit 2
cp "$(dirname "$JOIN")"/*.sh "$UFM/" || { echo "FIXTURE BROKEN: UFm could not copy the join's sibling scripts" >&2; exit 2; }
sed 's/^  true) die "--until /  true) : "--until /' "$JOIN" > "$UFM/join-remediator-shards.sh" \
  || { echo "FIXTURE BROKEN: UFm could not write the mutated join" >&2; exit 2; }
if cmp -s "$JOIN" "$UFM/join-remediator-shards.sh" || ! command bash -n "$UFM/join-remediator-shards.sh" 2>/dev/null; then
  bad "UFm: FIXTURE STALE -- the guard mutation matched nothing in $JOIN, or the mutant does not parse; re-anchor it, never relax the assertion"
else
  _ufm="$UFM/join-remediator-shards.sh"
  p_untilfut "$_ufm" 0; _c=$RC; p_untilfut "$_ufm" 3600
  if [ "$_c" -ne 0 ]; then mrow UFm UF1.now=1; bad "UFm: the unmutated-shape control (until now) did not join under the mutant copy (rc=$_c)"
  elif [ "$RC" -eq 0 ] && has "$JO" "JOINED:"; then mrow UFm UF1=1 UF1.now=0; mutant_killed "${B_UF1:-0}" UFm "UFm the future-until guard removed: KILLED by [UF1] (now+1h JOINED under the mutant), the now control unchanged"
  else mrow UFm UF1=0 UF1.now=0; bad "UFm: SURVIVED or broke -- now+1h under the guardless copy rc=$RC: $(head -1 "$JO")"; fi
fi
# PLAIN-B: a plain run of this file prints no matrix-only cell; --matrix prints one row per mutant.
if [ "$MATRIX" = 1 ]; then echo "  (matrix mode, unit-reader-b.sh: $N_MROWS MATRIX row(s) printed)"
elif [ "$N_MROWS" -eq 0 ]; then ok "PLAIN-B: a plain run of unit-reader-b.sh printed no matrix-only cell"
else bad "PLAIN-B: a plain run of unit-reader-b.sh printed $N_MROWS matrix row(s)"; fi
echo "$NAME: $fails failure(s)"
[ "$fails" -eq 0 ]
