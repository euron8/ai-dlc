#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
# remediator-shard-join/run.sh -- join-remediator-shards.sh and the write ledger it reads. The
# behavioural arms only: the JX mutation battery that once proved each of them can fail
# has been retired; the predicates live in `lib.sh` beside this file. The battery mutates copies of core's own join, which a consumer
# cannot edit, so the consumer keeps every correctness arm and loses only that proof.
# The hard-coded `@` expectations go red in a consumer whose pair readers were carried at their pre-`@`
# version; read such a red as "a reader is carried", not as a merge or join regression.
#
# WHY A FIXTURE OF ITS OWN. No existing fixture owns this script. gate-remediation-deny owns the
# remediation-guard HOOK and its deny paths; check-24-adversarial-convergence owns arm H, which
# reads the ONE repair record the join writes. The join is the program between them: it proves the
# sharded remediators wrote DISJOINT file sets from rows the hook recorded, and only then writes
# the record arm H reads.
#
# THE LEDGER IS WRITTEN BY THE REAL HOOK. Every `.artifact-writes.jsonl` row below comes from
# driving `ai-dlc-gate-remediation-guard.sh` with a PreToolUse payload carrying a harness-shaped
# `agent_id` (17 hex characters, the shape the reference consumer's `.verdict-writes.jsonl`
# carries). No row is hand-written, so a change to what the hook records is a change this fixture
# sees. The one exception is AL2, which strips the three evidence keys from real rows with
# `jq del(...)` to build a pre-upgrade ledger; the re-run arms pin the hook's clock through a
# `date` shim and still let the hook write every row. The PARTS carry no agent id at all: the join keys a part on the files its `edit:` lines
# cite, never on an id a model reports about itself.
#
# SEEDS ARE REAL CONSUMER BYTES, TRIMMED. `seed.story-*.md` are the first 12 lines of three
# stories of one reference-consumer sprint (s305), and `seed.block-*.md` are three finding blocks
# of that sprint's real repair record, one per story, each ending at its `derivation:` label. The
# worlds are built AS sprint 305, so every `edit:` path is the consumer's own spelling, verbatim.
# `seed.block-epics.md` is a block of a DIFFERENT sprint's record (s310 stories pass 1, MINOR-1)
# whose `edit:` line cites ONLY `epics/epics.md` -- the shape of 101 of the 174 `edit:` lines
# in that consumer's stories repair records, and the reason `--artifact-path` is the sprint slot.
#
# lib.sh sets the shell options, scrubs AI_DLC_*, owns WORK and its one EXIT trap.
# ---------------------------------------------------------------------------- shards (BL-1095)
# THIS FILE IS TWO SHARDS OF ONE FIXTURE, AND THE SPLIT IS A SCHEDULING BOUNDARY, NOT A SUBJECT BOUNDARY. The arms
# after the header are two UNITS guarded by `if sg <unit>; then` ... `fi # sg <unit>`; `--group <x>` runs the units
# dealt to shard <x>. The sibling `remediator-shard-join-b/run.sh` is a one-line driver that execs this file with
# `--group b`; no `--group` is shard a. Units that are bash children (unit-*.sh) ride with the unit that calls them.
#   a  head   unit-reader-b, unit-parts, PS1/PS7/PS8, unit-record, unit-reader, unit-bind, R1, unit-mark, EC40-EC43
#   b  tail   unit-reader-a, DK1/DK2, the SR/SRC/CPS seat-row arms
# THE SEED AND THE LIBRARY ARE NOT UNITS: every shard pays them.
# THE COVERAGE JOIN runs in EVERY shard before the library is sourced: the declared units are DERIVED from this file's
# `if sg <unit>; then` lines, the dealt lists must be disjoint and their union the declared set exactly, and every
# declared shard must have a driver directory. It proves it can fire first, on a seeded duplicate and omission.
SHARDS="a b"
UNITS_a="head"
UNITS_b="tail"
GROUP=a
while [ $# -gt 0 ]; do
  case "$1" in
    --group) GROUP="${2:-}"; [ -n "$GROUP" ] || { echo "FIXTURE ERROR: --group needs a shard name" >&2; exit 2; }; shift 2 ;;
    *) echo "FIXTURE ERROR: unknown argument '$1'" >&2; exit 2 ;;
  esac
done
case " $SHARDS " in
  *" $GROUP "*) ;;
  *) echo "FIXTURE ERROR: unknown shard '$GROUP' (known: $SHARDS)" >&2; exit 2 ;;
esac
eval "MINE=\"\${UNITS_$GROUP:-}\""
NAME="remediator-shard-join"; [ "$GROUP" = a ] || NAME="remediator-shard-join-$GROUP"
rj_broken() { echo "FIXTURE BROKEN: $1" >&2; echo "$NAME: FIXTURE BROKEN" >&2; exit 2; }
[ -n "$MINE" ] || rj_broken "shard '$GROUP' has no UNITS_$GROUP list; a shard dealt nothing passes everything it never checked"
sg() { case " $MINE " in *" $1 "*) return 0 ;; esac; return 1; }
RJ_SELF="$0"
[ -f "$RJ_SELF" ] || rj_broken "cannot read $RJ_SELF for the coverage join"
rj_partition_ok() { # <declared ids file> <dealt ids file> -> 0 when dealt is disjoint and covers declared exactly
  local dup miss extra
  dup="$(sort "$2" | uniq -d | tr '\n' ' ')"
  miss="$(sort -u "$2" | comm -23 <(sort -u "$1") - | tr '\n' ' ')"
  extra="$(sort -u "$2" | comm -13 <(sort -u "$1") - | tr '\n' ' ')"
  [ -z "$dup$miss$extra" ] && return 0
  echo "dealt twice: {${dup% }} dealt to no shard: {${miss% }} dealt but not declared: {${extra% }}"
  return 1
}
RJ_JW="$(mktemp -d "${TMPDIR:-/tmp}/remediator-join-shards.XXXXXX")" || rj_broken "mktemp failed"
printf '%s\n' u1 u2 u3 > "$RJ_JW/pd"; printf '%s\n' u1 u2 u2 u3 > "$RJ_JW/pdup"; printf '%s\n' u1 u3 > "$RJ_JW/pmiss"; printf '%s\n' u3 u1 u2 > "$RJ_JW/pok"
if rj_partition_ok "$RJ_JW/pd" "$RJ_JW/pdup" >/dev/null || rj_partition_ok "$RJ_JW/pd" "$RJ_JW/pmiss" >/dev/null \
   || ! rj_partition_ok "$RJ_JW/pd" "$RJ_JW/pok" >/dev/null; then
  rm -rf "$RJ_JW"; rj_broken "the coverage join's self-probe did not discriminate (duplicate, omission, exact)"
fi
sed -n 's/^[[:space:]]*if sg \([a-z0-9_][a-z0-9_]*\); then$/\1/p' "$RJ_SELF" > "$RJ_JW/declared"
for _s in $SHARDS; do eval "printf '%s\n' \${UNITS_$_s}" | tr ' ' '\n'; done | grep . > "$RJ_JW/dealt"
rj_ndecl="$(grep -c . "$RJ_JW/declared")" || rj_ndecl=0
rj_ndup="$(sort "$RJ_JW/declared" | uniq -d | grep -c .)" || rj_ndup=0
[ "$rj_ndecl" -gt 0 ] && [ "$rj_ndup" -eq 0 ] || { rm -rf "$RJ_JW"; rj_broken "$rj_ndecl unit guards derived from $RJ_SELF ($rj_ndup declared twice)"; }
rj_why="$(rj_partition_ok "$RJ_JW/declared" "$RJ_JW/dealt")" || { rm -rf "$RJ_JW"; rj_broken "the shard partition does not cover the guarded units exactly -- $rj_why"; }
for _s in $SHARDS; do
  [ "$_s" = a ] && continue
  _drv="$(cd "$(dirname "$RJ_SELF")" && pwd)/../remediator-shard-join-$_s/run.sh"
  [ -f "$_drv" ] && grep -qF -- "--group $_s" "$_drv" || { rm -rf "$RJ_JW"; rj_broken "shard '$_s' is declared but $_drv does not drive it"; }
done
rm -rf "$RJ_JW"
echo "  [J0] coverage join: $rj_ndecl units derived from the sg guards, dealt disjointly across {$SHARDS}, union exact; this shard runs {$MINE}"
[ -f "$(cd "$(dirname "$0")" && pwd)/lib.sh" ] || { echo "FIXTURE BROKEN: lib.sh is absent beside $0; nothing was asserted" >&2; exit 2; }
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
MUT_LIB="$(cd "$HERE/../lib" 2>/dev/null && pwd)/mutant.sh"
[ -f "$MUT_LIB" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $HERE" >&2; exit 2; }
. "$MUT_LIB"
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"

# ---------------------------------------------------------------------------------- the arms
echo "$NAME:"
echo "HERMETIC-CONSUMED core/scripts/join-remediator-shards.sh"
echo "HERMETIC-CONSUMED core/hooks/ai-dlc-gate-remediation-guard.sh"

if sg head; then
echo "HERMETIC-CONSUMED core/scripts/serial-remediation-worklist.sh"  # the join starts it beside itself in every head subject assembly
# ---- unit-reader-b.sh: L1-L4, J, D, A, B2/SJ0, PS5/PS6/PS9/PS12, SP1-SP11, AW1, CP1/CP3/CP4, MKP, D5/D6, H1/H2, UF1
# asked in process through the same lib.sh predicates; its SEAM-B and CLI-B cells keep one CLI pass and refusal per join
# mode it owns. End to end here: PS1 (a party join), PS7 (--sources passes), PS8 (--sources refuses). One literal call line.
bash "$HERE/unit-reader-b.sh"; _urb=$?
case "$_urb" in 0) ;; 1) fails=$((fails + 1)) ;; *) bad "unit-reader-b.sh exited $_urb (FIXTURE BROKEN); nothing was asserted" ;; esac


# ---- unit-parts.sh: the parts-mode and --sources ENTRY-CONTRACT cells (EC1-EC13, EC15-EC17, EC27, PS2-PS4, PS10, PS11) asked in
# process against the sourced join. One end to end run per mode stays: EC32 (parts refusal, CLI-A in unit-reader-a.sh), PS1 (parts join), PS8
# (--sources refusal), PS7 (--sources pass). One literal call line, never a loop variable.
bash "$HERE/unit-parts.sh"; _up=$?
case "$_up" in 0) ;; 1) fails=$((fails + 1)) ;; *) bad "unit-parts.sh: FIXTURE BROKEN, exit $_up" ;; esac
# ---- party repairs (BL-462). Each refusal has its ALLOW twin one property apart in the same run.
p_party "$JOIN" && ok "PS1: a party repair (--artifact stories-party), sources keyed on (seat file, id) -- F-1 in BOTH dev-1 and tea-1, and graph's \`## Finding D4-1\` form -> JOINED, the tokens carried into the record" \
  || bad "PS1: a party repair with resolving sources did not join (rc=$RC): $(cat "$JO")"
p_srcok "$JOIN" && ok "PS7: --sources on a record no join wrote -- colliding F-1 keyed by file -> rc 0, '2 entries, 3 sources'" \
  || bad "PS7: --sources refused a resolving record (rc=$RC): $(cat "$JO")"
p_srcunres "$JOIN" && ok "PS8: --sources, one property apart (F-4 under dev-1) -> rc 2, UNRESOLVED, the carrying seat named" \
  || bad "PS8: --sources accepted an id only another seat carries (rc=$RC): $(cat "$JO")"

# ---- the entry contract (BL-508, BL-519). Each refusal has its ALLOW twin one property apart.
bash "$HERE/unit-record.sh"; _ur=$?
case "$_ur" in 0) ;; 1) fails=$((fails + 1)) ;; *) bad "unit-record.sh exited $_ur (FIXTURE BROKEN); nothing was asserted" ;; esac
# ---- unit-reader.sh: SEAM-JOIN and SEAM-HOOK, the in-process (join_main, hook_pretool_head) answers pinned byte-identical to the CLI's.
bash "$HERE/unit-reader.sh"; _urd=$?
case "$_urd" in 0) ;; 1) fails=$((fails + 1)) ;; *) bad "unit-reader.sh exited $_urd (FIXTURE BROKEN); nothing was asserted" ;; esac
# ---- unit-bind.sh: BIND0-BIND2, the join's SAME and DOUBLE-WRITE refusal text bound to the merge's, self-probed first.
bash "$HERE/unit-bind.sh"; _ubd=$?
case "$_ubd" in 0) ;; 1) fails=$((fails + 1)) ;; *) bad "unit-bind.sh exited $_ubd (FIXTURE BROKEN); nothing was asserted" ;; esac



# R1: the role file the remediator is bound to teaches the write tool and the citation form. Walked
# up from this fixture in both layouts; install copies team-roles/ verbatim, so no render exists.
ROLE=""
_d="$HERE"
while [ -n "$_d" ] && [ "$_d" != "/" ]; do
  for _c in "$_d/core/team-roles/remediator.md" "$_d/.claude/team-roles/remediator.md"; do
    [ -f "$_c" ] && { ROLE="$_c"; break 2; }
  done
  _d="$(dirname "$_d")"
done
if [ -z "$ROLE" ]; then
  bad "R1: FIXTURE BROKEN -- remediator.md not found above $HERE in either layout"
else
  role_flat="$(tr '\n' ' ' < "$ROLE" | tr -s ' ')"
  n_rel="$(grep -o "the project-relative path in the ledger's spelling" <<<"$role_flat" | grep -c .)" || n_rel=0
  n_full="$(grep -c 'FULL path' "$ROLE")" || n_full=0
  if grep -qF "every edit to a file under the sprint slot goes through Edit, Write or MultiEdit, never a Bash redirect" <<<"$role_flat" \
     && [ "$n_rel" -eq 2 ] && [ "$n_full" -eq 0 ]; then
    ok "R1: $ROLE teaches Edit/Write/MultiEdit for slot edits and the ledger-spelled citation at both sites (2), with no FULL path left"
  else
    bad "R1: $ROLE -- Edit/Write/MultiEdit sentence absent, or ledger-spelled citations=$n_rel (want 2), FULL path=$n_full (want 0)"
  fi
fi


# ---- unit-mark.sh: MK0, the in-process --mark seam pinned to the CLI. EC37 and EC40-EC43 below drive the same seam.
bash "$HERE/unit-mark.sh"; _um=$?
case "$_um" in 0) ;; 1) fails=$((fails + 1)) ;; *) bad "unit-mark.sh exited $_um (FIXTURE BROKEN); nothing was asserted" ;; esac
if p_markderive "$SRCDIR/wait-for-deliverable.sh"; then ok "EC40: --mark on a remediator part derives the words from the path -- coe-repair-p1/2.md written coe remediator 2, the shifted call coe 7 remediator 7 written coe remediator 7, requirements-party-repair/05.md called with wrong words written requirements-party remediator 05 and 03.md keeps its correct spelling, coe-party-serial-repair-p1/lane-1.md keeps lane-1, a 1/8 brief shard becomes the file name; a plain/ file keeps the caller's words"
else bad "EC40: --mark did not derive the remediator part marker words (BL-796)"; fi
# EC41 (BL-804): --mark / --mark-repair replay a remediator record stating `derivations: not replayed`.
if p_replay "$SRCDIR/wait-for-deliverable.sh"; then ok "EC41: --mark replays a not replayed remediator part -- two reproducing fences under one triple written replayed 2 and sealed, a stale fence refused 64 with the file byte-identical (the deferral remedy only in a section-split dir), a deferred line, a non-repair seat and a part with no repaired entry untouched; --mark-repair on a joined record rewrites the serial block's own line to replayed 3 and leaves the shard body's line alone"
else bad "EC41: the --mark replay failed at case ${R804:-?} (BL-804)"; fi
# EC42 (BL-816): --mark checks a claimed `replayed <n>` and refuses only on a stale fence inside the block it seals.
if p_claim "$SRCDIR/wait-for-deliverable.sh"; then ok "EC42: --mark checks a claimed replay -- a clean joined record and a part claiming replayed 7 over 2 reproducing fences marked, sealed and never rewritten; a stale fence on the FIRST and on the LAST fence line of the serial block, and in a part, refused 64 with the file byte-identical; a stale fence in the SHARD segment above it left to the join, the serial block marked"
else bad "EC42: the claimed-replay check failed at case ${R816:-?} (BL-816)"; fi
# EC43 (BL-816, B1): a validator exit 1 with no `FAIL: <n> stale or unrunnable` summary is a crash, never a FAIL set
# that misses the block being sealed. Predicate p_vcrash in lib.sh.
if p_vcrash "$SRCDIR"; then ok "EC43: a validator that dies under set -u (exit 1, no FAIL line) -> --mark-repair over a stale replayed 2 block and --mark over a clean not-replayed part each refused 64 as no verdict, the file byte-identical; the real validator marks a clean record and refuses a stale fence as stale"
else bad "EC43: the crashed-validator refusal failed at case ${RVC:-?} (BL-816)"; fi

# EC39 (BL-734): a closing entry appended to a joined record -- the BADSIB refusal line, its two accepted
# near-misses, then the writer paragraphs of both role files.
RP="$(dirname "${ROLE:-/nonexistent/x}")/pm-escalated.md"
if [ -z "${ROLE:-}" ] || [ ! -f "$RP" ]; then
  bad "EC39: FIXTURE BROKEN -- remediator.md or pm-escalated.md not found beside the role directory"
else
  if p_bl734 "$JOIN"; then ok "EC39a: --escalations over a joined record with an appended closing entry -- 'siblings: checked' is REFUSED with the BADSIB line itself, rc 2; the field then a blank line then a fence, and a fence directly under it, both rc 0"
  else bad "EC39a: the appended closing entry's siblings: shapes were not judged as specified (rc=$RC): $(cat "$JO")"; fi
  p_bl734prose "$ROLE" "$RP" && ok "EC39b: each role file's writer paragraph carries join-remediator-shards.sh --escalations with --sprint, remediator.md before --mark-repair and after the SPEC re-render, and the 'no procedure runs' negation is gone" \
    || bad "EC39b: a writer paragraph lacks the --escalations instruction (with --sprint), it precedes --mark-repair, or the old negation remains"
fi

fi # sg head
if sg tail; then
# ---- unit-reader-a.sh: SJ1-SJ9/SJ1o, EC14 EC18 EC19 EC25 EC32 EC36 EC37 EC38, RR1-RR20, AL1-AL9, NW1, LN1-LN8 and
# LN10-LN16, LP1-LP5, NL1-NL8c, asked in process through the same lib.sh predicates;
# its SEAM-A and CLI-A cells keep one CLI pass and refusal per join mode it owns. One literal call line.
bash "$HERE/unit-reader-a.sh"; _ura=$?
case "$_ura" in 0) ;; 1) fails=$((fails + 1)) ;; *) bad "unit-reader-a.sh exited $_ura (FIXTURE BROKEN); nothing was asserted" ;; esac

# ---- BL-823: one disposition-key predicate (DISP_KEY_ERE) at every site. A capitalised LIST ITEM is the key, so an
# out-of-set value under it is refused BADDISP; a capitalised column-0 summary is not, so it neither refuses nor
# overwrites the entry's disposition (graph s292's `**Disposition:** 4 repaired / 0 escalated.`).
if p_dispcap "$JOIN"; then ok "DK1: \`- **Disposition:** frobnicated\` in era -> REFUSED BADDISP by name, not NODISP"
else bad "DK1: a capitalised list-item disposition outside the vocabulary was not refused BADDISP (rc=$RC): $(grep -m2 -E 'REFUSED|JOINED|ESCALATED' "$JO")"; fi
if p_dispsummary "$JOIN"; then ok "DK2: a column-0 \`**Disposition:** 4 repaired / 0 escalated.\` summary, in the preamble and inside an in-era entry -> rc 0, nothing refused"
else bad "DK2: a capitalised summary line was read as a disposition key (rc=$RC): $(grep -m2 -E 'REFUSED|ESCALATED' "$JO")"; fi

# Worlds and the --sources drive shared by the SR, SRC and CPS arms below: pcb_src (a --sources world), pcb_party (a party parts world), pcd_src.
pcb_src() { local w; w="$(mktemp -d "$WORK/pcsrc.XXXXXX")" && mkdir -p "$w/.claude" && seat_seed "$w" 305 && printf '%s' "$w"; }
pcb_party() { local w; w="$(party_world)" || return 1
  ppart "$w" 01 2.1 "architecture-dev-1.md#F-1 architecture-tea-1.md#F-1"; ppart "$w" 02 2.2 "_bmad-output/party-mode/s305/architecture-dev-4.md#D4-1"
  ppart "$w" 03 3.1 "architecture-tea-1.md#F-4"; printf '%s' "$w"; }
pcd_src() { src_rec "$2" '### F-1\n- disposition: repaired\n- source: architecture-dev-1.md#F-1 architecture-tea-1.md#F-1\n' "$1"; }

# ---- SEAT SPAWN ROWS: a sharded party seat's record is its role-bound spawn-ledger row (seat_row_check). One --sources
# world per state, the seeded seats sharded by name (architecture-<seat>-<ordinal>.md, K = 4 from dev-4). SR1 seeds
# every seat's row except tea-1, whose rows are one property off each (role_contract_cited false; ordinal 2, K 4):
# REFUSED by name. SR7 gives tea-1 one role-bound row at K 5 instead, so the round's seats share no K: REFUSED as a
# K disagreement naming 4 and 5, no seat named. SR2 is SR1 plus tea-1's role-bound 1/4 row: SOURCES. SR3 installs a rulebook WITHOUT the sentence and no
# ledger: one SKIP line, rc 0. The installed sentence is the rulebook's own line, verbatim.
# SRT: the token the join greps for is read out of the join itself and must sit on exactly ONE line of the REAL
# rulebook of the tree under test (found by walking up, either layout); SR_LINE is that real line, never a copy.
GP=""; _d="$HERE"
while [ -n "$_d" ] && [ "$_d" != "/" ]; do
  for _c in "$_d/core/skills/ai-dlc/steps/_gate-procedures.md" "$_d/.claude/skills/ai-dlc/steps/_gate-procedures.md"; do
    [ -f "$_c" ] && { GP="$_c"; break 2; }
  done
  _d="$(dirname "$_d")"
done
srt_check() { # <join> <rulebook> -> 0 only when the join's SEAT_ROW_TOKEN is non-empty and on exactly one rulebook line
  local t n; t="$(sed -n 's/^SEAT_ROW_TOKEN="\(.*\)"$/\1/p' "$1" 2>/dev/null | head -1)"
  [ -n "$t" ] || return 1
  n="$(grep -cF -e "$t" "$2" 2>/dev/null)" || n=0
  [ "$n" = 1 ]
}
SR_TOKEN="$(sed -n 's/^SEAT_ROW_TOKEN="\(.*\)"$/\1/p' "$JOIN" | head -1)"
SR_LINE=""; [ -n "$GP" ] && [ -n "$SR_TOKEN" ] && SR_LINE="$(grep -F -e "$SR_TOKEN" "$GP" | head -1)"
if [ -n "$GP" ] && srt_check "$JOIN" "$GP"; then ok "SRT1: the join's SEAT_ROW_TOKEN sits on exactly one line of the real _gate-procedures.md"
else bad "SRT1: SEAT_ROW_TOKEN is empty, unextractable, or not on exactly one line of the real _gate-procedures.md (gp=${GP:-absent}) -- every consumer join would print SEAT-ROWS: SKIP"; fi
# Every seeded row carries SR_TS; the world's install commit is dated SR_INST (epoch seconds), so SR_TS post-dates it
# unless a cell passes the pre-install stamp. The install commit is the seeded git repo's one commit of the rulebook.
SR_POST="2030-01-01T00:00:00Z"; SR_PRE="2020-01-01T00:00:00Z"; SR_INST=1700000000; SR_TS="$SR_POST"
sr_row() { printf '{"v":1,"ts":"%s","sprint":305,"role":"%s","role_contract_cited":%s,"tool_use_id":"toolu_sr%s","shard":"%s"}\n' "$SR_TS" "$1" "$2" "$3" "$4"; }
sr_world() { # <with tea-1 row 0|1> <rulebook carries the sentence 0|1> [ts] [git 0|1] [drop dev-4 0|1] [tea row shard] [seat commit epoch] [noledger] -> a --sources world
  local w; w="$(pcb_src)" || return 1
  SR_TS="${3:-$SR_POST}"
  mkdir -p "$w/.claude/skills/ai-dlc/steps" || return 1
  if [ "$2" = 1 ]; then printf '# Gate procedures\n\n%s\n' "$SR_LINE"; else printf '# Gate procedures\n\nNo seat sentence.\n'; fi \
    > "$w/.claude/skills/ai-dlc/steps/_gate-procedures.md" || return 1
  if [ "$2" = 1 ]; then
    { sr_row architect true 1 "1/4 ## A"; sr_row dev true 2 "1/4 ## A"; sr_row dev true 3 "4/4 ## D"
      sr_row tea false 4 "1/4 ## A"; sr_row tea true 5 "${6:-2/4} ## A"
      if [ "$1" = 1 ]; then sr_row tea true 6 "1/4 ## A"; fi; } > "$w/_bmad-output/spawn-ledger.jsonl" || return 1
  fi
  [ "${5:-0}" = 1 ] && { rm "$w/_bmad-output/party-mode/s305/architecture-dev-4.md" || return 1; }
  [ "${8:-}" = noledger ] && { rm -f "$w/_bmad-output/spawn-ledger.jsonl" || return 1; }
  if [ "${4:-1}" = 1 ]; then
    git -C "$w" init -q . || return 1
    if [ -n "${7:-}" ]; then sr_commit "$w" "${7}" _bmad-output/party-mode || return 1; fi
    sr_commit "$w" "$SR_INST" .claude/skills/ai-dlc/steps/_gate-procedures.md || return 1
  fi
  printf '%s' "$w"
}
sr_commit() { # <world> <epoch> <path> -- one commit of that path, dated
  git -C "$1" add "$3" && GIT_AUTHOR_DATE="$2 +0000" GIT_COMMITTER_DATE="$2 +0000" git -C "$1" -c user.name=fx -c user.email=fx@fx -c commit.gpgsign=false commit -q -m "$3"
}
sr_drive() { pcd_src "$1" "$2"; }
SR_REF="seat file architecture-tea-1.md is a sharded party seat (tea, shard 1/4) with no role-bound row"
sr1() { [ "$RC" -eq 2 ] && has "$JO" "$SR_REF" && ! has "$JO" "architecture-dev-1.md is a sharded" && ! has "$JO" "SOURCES:"; }
sr2() { [ "$RC" -eq 0 ] && has "$JO" "SOURCES:" && ! has "$JO" "is a sharded party seat" && ! has "$JO" "SEAT-ROWS: SKIP"; }
# hasl <file> <text>: some line OPENS with <text> (a literal prefix, never a regex). SR3 reads its SKIP line anchored,
# so a NOTE: prefix leaking into --sources fails it.
hasl() { awk -v p="$2" 'index($0, p) == 1 { f = 1 } END { exit !f }' "$1"; }
sr3() { [ "$RC" -eq 0 ] && hasl "$JO" "SEAT-ROWS: SKIP -- the installed" && has "$JO" "SOURCES:" && ! has "$JO" "is a sharded party seat"; }
SR1W="$(sr_world 0 1)"; SR2W="$(sr_world 1 1)"; SR3W="$(sr_world 0 0)"
SR_SPRE=$((SR_INST - 1000)); SR_SPOST=$((SR_INST + 1000))
SR4W="$(sr_world 0 1 "$SR_PRE" 1 0 2/4 "$SR_SPRE")"; SR5W="$(sr_world 0 1 "$SR_POST" 0)"; SR6W="$(sr_world 1 1 "$SR_POST" 1 1)"
SR7W="$(sr_world 0 1 "$SR_POST" 1 0 1/5)"
sr4() { [ "$RC" -eq 0 ] && has "$JO" "SEAT-ROWS: SKIP legacy-round architecture" && has "$JO" "SOURCES:" && ! has "$JO" "is a sharded party seat"; }
sr5() { [ "$RC" -eq 0 ] && has "$JO" "SEAT-ROWS: SKIP install-date-unreadable" && has "$JO" "SOURCES:" && ! has "$JO" "is a sharded party seat"; }
sr6() { [ "$RC" -eq 0 ] && has "$JO" "SOURCES:" && ! has "$JO" "is a sharded party seat" && ! has "$JO" "SEAT-ROWS: SKIP"; }
sr7() { [ "$RC" -eq 2 ] && has "$JO" "the sharded party round architecture's spawn-ledger rows disagree on K" && has "$JO" "at shard counts 4 5 with no single K" && ! has "$JO" "is a sharded party seat" && ! has "$JO" "SOURCES:"; }
# SR8, the mid-sprint pull: an old round's role-bound rows for all four seats at K 4, stamped before the install, then
# a new round with the same roles, ordinals and K stamped after it for every seat but tea-1. The seat files are committed
# before the install, so a round dated off its rows falls to the seat dating and reads legacy, never undatable. Rows name no step, so the
# new round's seats match the old rows too: dated by their EARLIEST row it SKIPped as legacy, and tea-1 joined the old
# round's 1/4 row. Judged and refused by name, its covered siblings not named. SR8b adds tea-1's own post-install row:
# the same mixed ledger, every seat covered -> SOURCES, no SKIP (the allow twin, one row apart).
sr_mixed() { # <tea-1 new-round row 0|1> -> a --sources world
  local w; w="$(pcb_src)" || return 1
  mkdir -p "$w/.claude/skills/ai-dlc/steps" || return 1
  printf '# Gate procedures\n\n%s\n' "$SR_LINE" > "$w/.claude/skills/ai-dlc/steps/_gate-procedures.md" || return 1
  { SR_TS="$SR_PRE"; sr_row architect true 1 "1/4 ## A"; sr_row dev true 2 "1/4 ## A"; sr_row dev true 3 "4/4 ## D"; sr_row tea true 4 "1/4 ## A"
    SR_TS="$SR_POST"; sr_row architect true 5 "1/4 ## A"; sr_row dev true 6 "1/4 ## A"; sr_row dev true 7 "4/4 ## D"
    if [ "$1" = 1 ]; then sr_row tea true 8 "1/4 ## A"; fi; } > "$w/_bmad-output/spawn-ledger.jsonl" || return 1
  git -C "$w" init -q . && sr_commit "$w" "$SR_SPRE" _bmad-output/party-mode && sr_commit "$w" "$SR_INST" .claude/skills/ai-dlc/steps/_gate-procedures.md || return 1
  printf '%s' "$w"
}
SR8W="$(sr_mixed 0)"; SR8BW="$(sr_mixed 1)"
sr8() { [ "$RC" -eq 2 ] && has "$JO" "$SR_REF" && ! has "$JO" "SEAT-ROWS: SKIP" && ! has "$JO" "architecture-dev-1.md is a sharded" && ! has "$JO" "SOURCES:"; }
sr8b() { [ "$RC" -eq 0 ] && has "$JO" "SOURCES:" && ! has "$JO" "is a sharded party seat" && ! has "$JO" "SEAT-ROWS: SKIP"; }
# A round with NO post-install row is dated by its seat files' newest-add commits, and is undatable when any is not clean. SR9: every row pre-install, every
# seat committed AFTER the install -> judged, all four seats refused by name (shard <o>/K: no post-install row names
# K). SR10: the same rows, the seats never committed -> SKIP round-undatable naming 4 seats, never legacy, rc 0.
# SR4 above is the legacy twin: the same rows, the seats committed BEFORE the install. SR11: SR4 with no spawn
# ledger at all -> SKIP legacy-round, rc 0, no missing-ledger refusal. SR12: a depth-1 clone of the SR1 history with a
# later commit on top -> SKIP install-date-unreadable naming the shallow clone, no seat judged.
SR9W="$(sr_world 0 1 "$SR_PRE" 1 0 2/4 "$SR_SPOST")"; SR10W="$(sr_world 0 1 "$SR_PRE")"
SR11W="$(sr_world 0 1 "$SR_PRE" 1 0 2/4 "$SR_SPRE" noledger)"
sr_shallow() {
  local o w; o="$(sr_world 0 1)" || return 1
  sr_commit "$o" "$SR_SPRE" _bmad-output && printf 'x\n' > "$o/later" && sr_commit "$o" "$SR_SPOST" later || return 1
  w="$(mktemp -d "$WORK/srsh.XXXXXX")" && git clone -q --depth 1 "file://$o" "$w/c" 2>/dev/null || return 1
  [ "$(git -C "$w/c" rev-parse --is-shallow-repository)" = true ] || return 1
  printf '%s' "$w/c"
}
SR12W="$(sr_shallow)"
# SR13: the SR4 legacy round (rows and seat commits all pre-install), then every seat file overwritten by a re-run and
# left uncommitted -> SKIP round-undatable 4 seats, never legacy, rc 0. SR14: the seats committed pre-install, deleted,
# and re-added AFTER the install, every row pre-install -> dated by the NEWEST add, judged, all 4 seats refused. SR15:
# the SR9 round (committed after the install) beside two untracked decoys, an unsharded `architecture-dev.md` and a
# sharded seat of another step `architecture-x-dev-01.md` -> still judged and all 4 refused (the dating list is the
# scan's parsed seats, never a `<step>-*` glob).
sr_rerun() { local w; w="$(sr_world 0 1 "$SR_PRE" 1 0 2/4 "$SR_SPRE")" || return 1
  for f in "$w"/_bmad-output/party-mode/s305/architecture-*.md; do printf '\nre-run\n' >> "$f" || return 1; done; printf '%s' "$w"; }
sr_readd() { local w; w="$(sr_world 0 1 "$SR_PRE" 1 0 2/4 "$SR_SPRE")" || return 1
  git -C "$w" rm -q -r _bmad-output/party-mode || return 1
  GIT_AUTHOR_DATE="$SR_SPOST +0000" GIT_COMMITTER_DATE="$SR_SPOST +0000" git -C "$w" -c user.name=fx -c user.email=fx@fx -c commit.gpgsign=false commit -q -m del || return 1
  seat_seed "$w" 305 && sr_commit "$w" "$((SR_SPOST + 10))" _bmad-output/party-mode || return 1; printf '%s' "$w"; }
sr_decoy() { local w; w="$(sr_world 0 1 "$SR_PRE" 1 0 2/4 "$SR_SPOST")" || return 1
  printf '# x\n' > "$w/_bmad-output/party-mode/s305/architecture-dev.md" && printf '# x\n' > "$w/_bmad-output/party-mode/s305/architecture-x-dev-01.md" || return 1
  printf '%s' "$w"; }
# SR16: the SR10 round (never committed) with party-mode excluded in .git/info/exclude, so `git status` reports
# nothing -> still round-undatable from the never-committed count, never legacy.
sr_hidden() { local w; w="$(sr_world 0 1 "$SR_PRE")" || return 1
  printf '_bmad-output/party-mode/\n' >> "$w/.git/info/exclude" || return 1
  [ -z "$(git -C "$w" status --porcelain -- _bmad-output/party-mode)" ] || return 1; printf '%s' "$w"; }
SR13W="$(sr_rerun)"; SR14W="$(sr_readd)"; SR15W="$(sr_decoy)"; SR16W="$(sr_hidden)"
# SR17, the sprint squash: ONE commit, dated SR_INST, both introduces the sentence into the tracked rulebook AND adds the
# round's seat files; every row pre-install -> the install commit's own adds are legacy: SKIP legacy-round, rc 0, never
# undatable, no seat refused. SR18, its discriminating control: the rulebook commit alone, then the seats in a LATER
# commit pinned to the SAME committer date (GIT_COMMITTER_DATE) -> judged by sha, all 4 seats refused. The pair separates
# the sha compare from a ts-only `>=` (SR17 judged) and from a strict ts `>` (SR18 legacy).
sr_squash() { # <seats in the install commit 1|0> -> a --sources world
  local w; w="$(sr_world 0 1 "$SR_PRE" 0)" || return 1
  git -C "$w" init -q . || return 1
  if [ "$1" = 1 ]; then git -C "$w" add _bmad-output/party-mode || return 1; sr_commit "$w" "$SR_INST" .claude/skills/ai-dlc/steps/_gate-procedures.md || return 1
  else sr_commit "$w" "$SR_INST" .claude/skills/ai-dlc/steps/_gate-procedures.md && sr_commit "$w" "$SR_INST" _bmad-output/party-mode || return 1; fi
  [ "$(git -C "$w" rev-list --count HEAD)" = "$((2 - $1))" ] || return 1
  printf '%s' "$w"; }
# SR19: SR17's squash (the install commit adds the seats), then the seats deleted and re-added by LATER commits, every
# row pre-install -> each seat's newest add is a post-install commit whose sha is not the install's: judged, all 4
# refused. A seat's date and sha come from ONE add.
sr_squash_readd() { local w; w="$(sr_squash 1)" || return 1
  git -C "$w" rm -q -r _bmad-output/party-mode || return 1
  GIT_AUTHOR_DATE="$SR_SPOST +0000" GIT_COMMITTER_DATE="$SR_SPOST +0000" git -C "$w" -c user.name=fx -c user.email=fx@fx -c commit.gpgsign=false commit -q -m del || return 1
  seat_seed "$w" 305 && sr_commit "$w" "$((SR_SPOST + 10))" _bmad-output/party-mode || return 1; printf '%s' "$w"; }
SR17W="$(sr_squash 1)"; SR18W="$(sr_squash 0)"; SR19W="$(sr_squash_readd)"
sr17() { sr4 && ! has "$JO" "round-undatable" && ! has "$JO" "no role-bound row"; }
sr13() { [ "$RC" -eq 0 ] && has "$JO" "SEAT-ROWS: SKIP round-undatable architecture 4 seats" && ! has "$JO" "legacy-round" && has "$JO" "SOURCES:" && ! has "$JO" "is a sharded party seat"; }
sr9() { [ "$RC" -eq 2 ] && [ "$(grep -c 'is a sharded party seat' "$JO")" = 4 ] && has "$JO" "seat file architecture-tea-1.md is a sharded party seat (tea, shard 1/K)" && ! has "$JO" "SEAT-ROWS: SKIP" && ! has "$JO" "SOURCES:"; }
sr10() { [ "$RC" -eq 0 ] && has "$JO" "SEAT-ROWS: SKIP round-undatable architecture 4 seats" && ! has "$JO" "legacy-round" && has "$JO" "SOURCES:" && ! has "$JO" "is a sharded party seat"; }
sr11() { [ "$RC" -eq 0 ] && has "$JO" "SEAT-ROWS: SKIP legacy-round architecture" && has "$JO" "SOURCES:" && ! has "$JO" "have no spawn ledger"; }
sr12() { [ "$RC" -eq 0 ] && has "$JO" "SEAT-ROWS: SKIP install-date-unreadable" && has "$JO" "is a shallow clone" && has "$JO" "SOURCES:" && ! has "$JO" "is a sharded party seat"; }
if [ -z "$SR1W" ] || [ -z "$SR2W" ] || [ -z "$SR3W" ] || [ -z "$SR4W" ] || [ -z "$SR5W" ] || [ -z "$SR6W" ] || [ -z "$SR7W" ] || [ -z "$SR8W" ] || [ -z "$SR8BW" ] \
  || [ -z "$SR9W" ] || [ -z "$SR10W" ] || [ -z "$SR11W" ] || [ -z "$SR12W" ] || [ -z "$SR13W" ] || [ -z "$SR14W" ] || [ -z "$SR15W" ] || [ -z "$SR16W" ] || [ -z "$SR17W" ] || [ -z "$SR18W" ] || [ -z "$SR19W" ]; then bad "SR: FIXTURE BROKEN -- a seat-row world could not be built"
else
  sr_drive "$JOIN" "$SR1W"
  if sr1; then ok "SR1: a sharded seat (tea-1) whose rows are role_contract_cited false and ordinal 2 -> REFUSED rc 2 naming it, its covered siblings not named"
  else bad "SR1: a sharded seat with no role-bound row was not refused by name (rc=$RC): $(head -3 "$JO")"; fi
  sr_drive "$JOIN" "$SR2W"
  if sr2; then ok "SR2: the near-miss, every sharded seat with its role-bound row (tea-1 1/4 added) -> SOURCES, rc 0, no seat refused"
  else bad "SR2: every seat carried its row and the join did not pass (rc=$RC): $(head -3 "$JO")"; fi
  sr_drive "$JOIN" "$SR3W"
  if sr3; then ok "SR3: the installed rulebook lacks the seat-record sentence -> one SEAT-ROWS: SKIP line, SOURCES, no seat refused"
  else bad "SR3: under a rulebook before the shape the join did not SKIP the seat-row join (rc=$RC): $(head -3 "$JO")"; fi
  sr_drive "$JOIN" "$SR4W"
  if sr4; then ok "SR4: the SR1 round with every row stamped before the install commit -> SEAT-ROWS: SKIP legacy-round, SOURCES, no seat refused"
  else bad "SR4: a round dispatched before the install was judged or not skipped by name (rc=$RC): $(head -3 "$JO")"; fi
  sr_drive "$JOIN" "$SR5W"
  if sr5; then ok "SR5: the rulebook is not tracked (no install commit) -> SEAT-ROWS: SKIP install-date-unreadable, rc 0, never a refusal"
  else bad "SR5: an unreadable install date did not SKIP with its reason (rc=$RC): $(head -3 "$JO")"; fi
  sr_drive "$JOIN" "$SR6W"
  if sr6; then ok "SR6: the top-ordinal seat file (dev-4) never delivered, its siblings' rows carry K 4 -> every delivered seat joins, nothing refused"
  else bad "SR6: K was taken from the delivered files, so a round missing its top ordinal refused its delivered seats (rc=$RC): $(head -3 "$JO")"; fi
  sr_drive "$JOIN" "$SR7W"
  if sr7; then ok "SR7: tea-1's only role-bound row is at K 5, its siblings' at K 4 -> REFUSED rc 2 as a K disagreement naming 4 and 5, no seat named"
  else bad "SR7: seat rows sharing no K were not refused as a disagreement naming both values (rc=$RC): $(head -3 "$JO")"; fi
  sr_drive "$JOIN" "$SR8W"
  if sr8; then ok "SR8: a post-install round sharing roles, ordinals and K with a pre-install round of the sprint, tea-1 covered only by the old round's row -> judged, no SKIP, REFUSED rc 2 naming tea-1 alone"
  else bad "SR8: the mixed sprint's post-install round was skipped as legacy or its old-row-only seat joined (rc=$RC): $(head -3 "$JO")"; fi
  sr_drive "$JOIN" "$SR8BW"
  if sr8b; then ok "SR8b: the same mixed ledger with tea-1's own post-install row -> SOURCES, rc 0, no SKIP, no seat refused"
  else bad "SR8b: a judged round with every seat's post-install row did not pass over the old round's rows (rc=$RC): $(head -3 "$JO")"; fi
  sr_drive "$JOIN" "$SR9W"
  if sr9; then ok "SR9: every row pre-install, every seat committed after the install -> judged, all 4 seats REFUSED by name at shard <o>/K, no SKIP"
  else bad "SR9: a round with no post-install row and post-install seat commits was not judged (rc=$RC): $(head -3 "$JO")"; fi
  sr_drive "$JOIN" "$SR10W"
  if sr10; then ok "SR10: every row pre-install, the seats never committed -> SEAT-ROWS: SKIP round-undatable architecture 4 seats, not legacy, rc 0"
  else bad "SR10: a round with uncommitted seats and no post-install row was not SKIPped as undatable (rc=$RC): $(head -3 "$JO")"; fi
  sr_drive "$JOIN" "$SR11W"
  if sr11; then ok "SR11: the legacy SR4 round with no spawn ledger -> SKIP legacy-round, rc 0, no missing-ledger refusal"
  else bad "SR11: a legacy round with no ledger was refused for the ledger or not skipped (rc=$RC): $(head -3 "$JO")"; fi
  sr_drive "$JOIN" "$SR12W"
  if sr12; then ok "SR12: a depth-1 shallow clone -> SEAT-ROWS: SKIP install-date-unreadable naming the shallow clone, rc 0, no seat judged"
  else bad "SR12: a shallow clone's boundary commit was read as the install (rc=$RC): $(head -3 "$JO")"; fi
  sr_drive "$JOIN" "$SR13W"
  if sr13; then ok "SR13: the legacy SR4 round's committed seats overwritten by a re-run and left uncommitted -> SEAT-ROWS: SKIP round-undatable architecture 4 seats, not legacy, rc 0"
  else bad "SR13: a round whose committed pre-install seats were modified in the working tree read legacy or was judged (rc=$RC): $(head -3 "$JO")"; fi
  sr_drive "$JOIN" "$SR14W"
  if sr9; then ok "SR14: seats added pre-install, deleted, re-added after the install, every row pre-install -> dated by the newest add, judged, all 4 seats REFUSED"
  else bad "SR14: a round re-added after the install was dated by its oldest add (rc=$RC): $(head -3 "$JO")"; fi
  sr_drive "$JOIN" "$SR15W"
  if sr9; then ok "SR15: the SR9 round beside untracked decoys architecture-dev.md and architecture-x-dev-01.md -> still judged, all 4 seats REFUSED, never undatable"
  else bad "SR15: an unsharded or other-step file beside the round entered its dating list (rc=$RC): $(head -3 "$JO")"; fi
  sr_drive "$JOIN" "$SR16W"
  if sr10; then ok "SR16: the SR10 round's never-committed seats hidden from git status by .git/info/exclude -> still SEAT-ROWS: SKIP round-undatable architecture 4 seats, not legacy"
  else bad "SR16: a never-committed round invisible to git status read legacy or was judged (rc=$RC): $(head -3 "$JO")"; fi
  sr_drive "$JOIN" "$SR17W"
  if sr17; then ok "SR17: one commit installs the seat-record sentence AND adds the round's seats, every row pre-install -> SEAT-ROWS: SKIP legacy-round architecture, rc 0, no round-undatable, no seat refused"
  else bad "SR17: the install commit's own seat adds were read as judged or undatable (rc=$RC): $(head -3 "$JO")"; fi
  sr_drive "$JOIN" "$SR18W"
  if sr9; then ok "SR18: the seats added by a LATER commit at the install's own committer date -> judged by sha, all 4 seats REFUSED, no SKIP"
  else bad "SR18: a seat added after the install at the same ct read legacy (rc=$RC): $(head -3 "$JO")"; fi
  sr_drive "$JOIN" "$SR19W"
  if sr9; then ok "SR19: seats added by the install commit, deleted and re-added by later commits, every row pre-install -> dated by the newest add's own sha, judged, all 4 seats REFUSED"
  else bad "SR19: a seat re-added after the install read legacy off the install commit's sha (rc=$RC): $(head -3 "$JO")"; fi
fi

# ---- THE SEAT CHECKS AT THE SEAL: --check-part on a party part runs seat_complete_check in WARN FORM. A finding prints
# `WARN: the join will refuse: <the join's text>` and never refuses the part, ON PURPOSE (do not upgrade it to a refusal):
# the checks judge whole rounds and other agents' seat files, and the part's only clearing edit is deleting its source:
# citation (cited is built from source: lines alone; seat_row_check returns early with nothing cited), which silences the
# join too. The join and --sources still refuse the same text. Every seat-row SKIP line is prefixed `NOTE: ` in this mode
# only, the form wait-for-deliverable.sh --mark relays on a clean seal. The worlds are pcb_party's (part 01 cites
# architecture-dev-1.md#F-1 and architecture-tea-1.md#F-1; no rulebook carries the seat-record sentence).
# CPS1: dev-1 ends in its seat-complete: line, so step architecture is in the marker era and the cited tea-1 is
# unfinished -> the parts join over the tree REFUSES tea-1 (live run only); --check-part on part 01 -> rc 0, CHECK-PART:,
# a line opening `WARN: the join will refuse: seat file architecture-tea-1.md does not end in its 'seat-complete:'`.
# CPS2: no seat marked -> rc 0, CHECK-PART:, a line opening `NOTE: SEAT-ROWS: SKIP -- the installed`, no WARN.
# CPS4: a party world whose TRACKED rulebook carries the seat-record sentence (committed, the install), the seats committed
# after it, post-install rows for every seat but tea-1 -> judged; --check-part -> rc 0, CHECK-PART:, ONE line opening
# `WARN: the join will refuse: seat file architecture-tea-1.md is a sharded party seat` (seat_row_check's MISS site).
# CPS3: CPS4's world with jq off PATH -> rc 0, a line opening `NOTE: SEAT-ROWS: SKIP jq-absent`, no WARN.
# MKPW: CPS1's part sealed through the REAL wait-for-deliverable.sh --mark -> MARKED rc 0, the WARN and the NOTE relayed.
CPS_WARN="WARN: the join will refuse: seat file architecture-tea-1.md does not end in its 'seat-complete:'"
cps_world() { # <mark dev-1 0|1> -> a party world
  local w; w="$(pcb_party)" || return 1
  if [ "$1" = 1 ]; then printf '\nseat-complete: architecture dev 1 sha=%064d findings=3\n' 0 >> "$w/_bmad-output/party-mode/s305/architecture-dev-1.md" || return 1; fi
  printf '%s' "$w"
}
cps_tokworld() { # -> CPS4's world
  local w; w="$(pcb_party)" || return 1
  mkdir -p "$w/.claude/skills/ai-dlc/steps" && printf '# Gate procedures\n\n%s\n' "$SR_LINE" > "$w/.claude/skills/ai-dlc/steps/_gate-procedures.md" || return 1
  { SR_TS="$SR_POST"; sr_row architect true 1 "1/4 ## A"; sr_row dev true 2 "1/4 ## A"; sr_row dev true 3 "4/4 ## D"; } > "$w/_bmad-output/spawn-ledger.jsonl" || return 1
  git -C "$w" init -q . && sr_commit "$w" "$SR_INST" .claude/skills/ai-dlc/steps/_gate-procedures.md && sr_commit "$w" "$SR_SPOST" _bmad-output/party-mode || return 1
  printf '%s' "$w"
}
cps_part() { ppart "$1" 01 2.1 "architecture-dev-1.md#F-1 architecture-tea-1.md#F-1"; stamp "$1"; }
cps_chk() { # <join> <world> [PATH] -> RC, $JO: --check-part on part 01
  cps_part "$2"
  if [ -n "${3:-}" ]; then PATH="$3" AI_DLC_PROJECT_ROOT="$2" bash "$1" --check-part "$2/$PRD/01.md" > "$JO" 2>&1; RC=$?
  else AI_DLC_PROJECT_ROOT="$2" bash "$1" --check-part "$2/$PRD/01.md" > "$JO" 2>&1; RC=$?; fi
}
cps_nojq() { # -> a PATH on which `command -v jq` finds nothing: each dir carrying jq replaced by a link farm of it minus jq
  local d o="" i=0 s IFS=:
  for d in $PATH; do
    if [ -n "$d" ] && [ -x "$d/jq" ]; then i=$((i + 1)); s="$WORK/nojq$i"; mkdir -p "$s" && ln -s "$d"/* "$s/" 2>/dev/null; rm -f "$s/jq"; d="$s"; fi
    o="${o:+$o:}$d"
  done
  printf '%s' "$o"
}
cps1() { [ "$RC" -eq 0 ] && hasl "$JO" "$CPS_WARN" && has "$JO" "CHECK-PART:" && ! has "$JO" "REFUSED:"; }
cps2() { [ "$RC" -eq 0 ] && hasl "$JO" "NOTE: SEAT-ROWS: SKIP -- the installed" && has "$JO" "CHECK-PART:" && ! has "$JO" "WARN: the join will refuse" && ! has "$JO" "REFUSED:"; }
cps3() { [ "$RC" -eq 0 ] && hasl "$JO" "NOTE: SEAT-ROWS: SKIP jq-absent" && has "$JO" "CHECK-PART:" && ! has "$JO" "WARN: the join will refuse" && ! has "$JO" "REFUSED:"; }
CPS_MISS="WARN: the join will refuse: seat file architecture-tea-1.md is a sharded party seat"
cps_nmiss() { local n; n="$(grep -c '^WARN: the join will refuse: seat file .* is a sharded party seat' "$JO")" || n=0; printf '%s' "$n"; }
cps4() { [ "$RC" -eq 0 ] && hasl "$JO" "$CPS_MISS" && [ "$(cps_nmiss)" = 1 ] && has "$JO" "CHECK-PART:" && ! has "$JO" "REFUSED:"; }
CPS1W="$(cps_world 1)"; CPS2W="$(cps_world 0)"; CPS4W="$(cps_tokworld)"; CPS_NOJQ="$(cps_nojq)"
# The PATH is checked in a subshell after `hash -r`: this shell has already run jq, and `PATH=x command -v jq`
# answers the hashed farm path (measured), which would read a working jq-less PATH as broken.
if [ -z "$CPS1W" ] || [ -z "$CPS2W" ] || [ -z "$CPS4W" ] || [ -z "$CPS_NOJQ" ] || ( PATH="$CPS_NOJQ"; hash -r; command -v jq >/dev/null 2>&1 ) || ! ( PATH="$CPS_NOJQ"; hash -r; command -v git >/dev/null 2>&1 ); then
  bad "CPS: FIXTURE BROKEN -- a seal-time seat world, or a PATH with git and without jq, could not be built (w1=${CPS1W:-none} w2=${CPS2W:-none} w4=${CPS4W:-none} path=${CPS_NOJQ:-none} jq=$(PATH="$CPS_NOJQ"; hash -r; command -v jq) git=$(PATH="$CPS_NOJQ"; hash -r; command -v git))"
else
  run_pjoin "$JOIN" "$CPS1W"; _jr=0; [ "$RC" -eq 2 ] && has "$JO" "REFUSED: seat file architecture-tea-1.md does not end in its 'seat-complete:'" && _jr=1
  cps_chk "$JOIN" "$CPS1W"
  if [ "$_jr" = 1 ] && cps1; then ok "CPS1: a party part citing a marker-era unfinished seat -> the parts join REFUSES tea-1; --check-part on the part -> rc 0, CHECK-PART:, the same text as a line opening 'WARN: the join will refuse:'"
  else bad "CPS1: --check-part did not WARN the join's unfinished-seat refusal, or the join did not refuse it (join=$_jr rc=$RC): $(head -4 "$JO")"; fi
  cps_chk "$JOIN" "$CPS2W"
  if cps2; then ok "CPS2: a party part under a rulebook without the seat-record sentence -> --check-part rc 0 with a line opening 'NOTE: SEAT-ROWS: SKIP', no WARN"
  else bad "CPS2: --check-part did not print the seat-row SKIP as a NOTE: line (rc=$RC): $(head -4 "$JO")"; fi
  cps_chk "$JOIN" "$CPS4W"
  if cps4; then ok "CPS4: a tracked rulebook carrying the sentence, a judged round, tea-1 row-less -> --check-part rc 0, CHECK-PART:, one line opening 'WARN: the join will refuse: seat file architecture-tea-1.md is a sharded party seat'"
  else bad "CPS4: --check-part did not WARN seat_row_check's row-less seat (rc=$RC): $(head -4 "$JO")"; fi
  cps_chk "$JOIN" "$CPS4W" "$CPS_NOJQ"
  if cps3; then ok "CPS3: CPS4's world with jq off PATH -> --check-part rc 0 with a line opening 'NOTE: SEAT-ROWS: SKIP jq-absent', no WARN"
  else bad "CPS3: with jq absent the seat-row join did not SKIP by name (rc=$RC): $(head -4 "$JO")"; fi
  cps_part "$CPS1W"; cp "$CPS1W/$PRD/01.md" "$WORK/cps.before"
  # The world root is passed as cps_chk passes it: without it the join walks up from its own script dir, which in the
  # consumer layout is the consumer, whose installed rulebook carries the seat-record sentence (install-date-unreadable).
  AI_DLC_PROJECT_ROOT="$CPS1W" wfd_run "$SRCDIR/wait-for-deliverable.sh" --mark "$CPS1W/$PRD/01.md" stories remediator 01 findings=1 > "$JO" 2>&1; RC=$?
  if [ "$RC" -eq 0 ] && has "$JO" "MARKED " && hasl "$JO" "$CPS_WARN" && hasl "$JO" "NOTE: SEAT-ROWS: SKIP -- the installed" && ! has "$JO" "REFUSED" \
     && ! cmp -s "$WORK/cps.before" "$CPS1W/$PRD/01.md"; then ok "MKPW: CPS1's part sealed through the real wait-for-deliverable.sh --mark -> MARKED rc 0, the join's WARN and NOTE lines relayed"
  else bad "MKPW: the real --mark did not mark CPS1's part relaying the seat WARN and NOTE (rc=$RC): $(head -5 "$JO")"; fi
fi

# ---- SEAT FILE ROWS: a row carrying `mark_file` (the dispatch guard copies it from the brief) matches ONLY the cited seat
# whose path ends in `party-mode/s305/<that basename>`, never enters step/ordinal/K inference, dates its own seat, and
# covers it only when stamped at or after the install. Field-less rows keep the inference, for the seats no field-row
# matched. The cited round is always `architecture` (pcd_src); SRC1 and SRC4 add an uncited `requirements` round.
SR_G=/Users/n8/git/graph/_bmad-output/party-mode/s305
sr_frow() { printf '{"v":1,"ts":"%s","sprint":305,"role":"%s","role_contract_cited":true,"tool_use_id":"toolu_sf%s","shard":"%s","mark":"rendered","mark_file":"%s"}\n' "$SR_TS" "$1" "$2" "$3" "$4"; }
sr_fbuild() { # <seat commit epoch> <requirements seats 0|1> <rows fn> -> a --sources world
  local w s; w="$(pcb_src)" || return 1
  mkdir -p "$w/.claude/skills/ai-dlc/steps" && printf '# Gate procedures\n\n%s\n' "$SR_LINE" > "$w/.claude/skills/ai-dlc/steps/_gate-procedures.md" || return 1
  if [ "$2" = 1 ]; then for s in $SEATS; do printf '# x\n' > "$w/_bmad-output/party-mode/s305/requirements-$s.md" || return 1; done; fi
  "$3" > "$w/_bmad-output/spawn-ledger.jsonl" || return 1
  git -C "$w" init -q . && sr_commit "$w" "$1" _bmad-output/party-mode && sr_commit "$w" "$SR_INST" .claude/skills/ai-dlc/steps/_gate-procedures.md || return 1
  printf '%s' "$w"
}
# SRC1, DEFECT 1: the cited round's rows field-less and pre-install, the requirements round's rows post-install and naming
# their own seat files at the same roles, ordinals and K -> they cover and date nothing of architecture: legacy.
sr_rows_c1() { SR_TS="$SR_PRE"; sr_row architect true 1 "1/4 ## A"; sr_row dev true 2 "1/4 ## A"; sr_row dev true 3 "4/4 ## D"; sr_row tea true 4 "1/4 ## A"
  SR_TS="$SR_POST"; sr_frow architect 5 "1/4 ## A" "$SR_G/requirements-architect-1.md"; sr_frow dev 6 "1/4 ## A" "$SR_G/requirements-dev-1.md"
  sr_frow dev 7 "4/4 ## D" "$SR_G/requirements-dev-4.md"; sr_frow tea 8 "1/4 ## A" "$SR_G/requirements-tea-1.md"; }
# SRC2: tea-1's only row names a file that does not exist (`architecture-tea-01.md`) -> tea-1 refused, its siblings covered.
sr_rows_c2() { SR_TS="$SR_POST"; sr_row architect true 1 "1/4 ## A"; sr_row dev true 2 "1/4 ## A"; sr_row dev true 3 "4/4 ## D"
  sr_frow tea 4 "1/4 ## A" "_bmad-output/party-mode/s305/architecture-tea-01.md"; }
# SRC3: three seats by field-rows (worktree-relative), tea-1 by a field-less row -> the fallback still covers tea-1.
sr_rows_c3() { SR_TS="$SR_POST"; sr_frow architect 1 "1/4 ## A" "_bmad-output/party-mode/s305/architecture-architect-1.md"
  sr_frow dev 2 "1/4 ## A" "_bmad-output/party-mode/s305/architecture-dev-1.md"; sr_frow dev 3 "4/4 ## D" "_bmad-output/party-mode/s305/architecture-dev-4.md"
  sr_row tea true 4 "1/4 ## A"; }
# SRC4: tea-1 has no row; the requirements round's tea-1 field-row sits at tea 1/4 -> architecture-tea-1 is refused.
sr_rows_c4() { SR_TS="$SR_POST"; sr_row architect true 1 "1/4 ## A"; sr_row dev true 2 "1/4 ## A"; sr_row dev true 3 "4/4 ## D"
  sr_frow tea 4 "1/4 ## A" "$SR_G/requirements-tea-1.md"; }
# SRC5 / SRC5b: every seat by its own field-row, all stamped before the install. Seats committed before it -> legacy
# (SRC5); committed after it -> judged, and a pre-install field-row covers nothing: all four refused (SRC5b).
sr_rows_c5() { SR_TS="$SR_PRE"; sr_frow architect 1 "1/4 ## A" "$SR_G/architecture-architect-1.md"; sr_frow dev 2 "1/4 ## A" "$SR_G/architecture-dev-1.md"
  sr_frow dev 3 "4/4 ## D" "$SR_G/architecture-dev-4.md"; sr_frow tea 4 "1/4 ## A" "$SR_G/architecture-tea-1.md"; }
# SRC6, the relocated root: the same field-rows post-install, absolute under the reference consumer path while the join
# runs under a mktemp JR_ROOT, seats committed before the install -> dated by the rows, judged, every seat covered.
sr_rows_c6() { SR_TS="$SR_POST"; sr_frow architect 1 "1/4 ## A" "$SR_G/architecture-architect-1.md"; sr_frow dev 2 "1/4 ## A" "$SR_G/architecture-dev-1.md"
  sr_frow dev 3 "4/4 ## D" "$SR_G/architecture-dev-4.md"; sr_frow tea 4 "1/4 ## A" "$SR_G/architecture-tea-1.md"; }
SRC1W="$(sr_fbuild "$SR_SPRE" 1 sr_rows_c1)"; SRC2W="$(sr_fbuild "$SR_SPRE" 0 sr_rows_c2)"; SRC3W="$(sr_fbuild "$SR_SPRE" 0 sr_rows_c3)"
SRC4W="$(sr_fbuild "$SR_SPRE" 1 sr_rows_c4)"; SRC5W="$(sr_fbuild "$SR_SPRE" 0 sr_rows_c5)"; SRC5BW="$(sr_fbuild "$SR_SPOST" 0 sr_rows_c5)"
# SRC7: architect-1, dev-4 and tea-1 by field-less rows at K 4; dev-1 named by its own field-row AND carrying a field-less
# row at K 9 -> a field seat never votes K, so the round's K is 4 and dev-1 is covered by its field-row: SOURCES rc 0.
sr_rows_c7() { SR_TS="$SR_POST"; sr_row architect true 1 "1/4 ## A"; sr_row dev true 2 "1/9 ## A"; sr_row dev true 3 "4/4 ## D"; sr_row tea true 4 "1/4 ## A"
  sr_frow dev 5 "1/4 ## A" "$SR_G/architecture-dev-1.md"; }
# SRC8: a cited post-install DEV field-row names architecture-tea-1.md, and tea-1 has no row of its own -> an M row
# covers only the seat of its own role, so tea-1 is refused by name; the field-row still names it (no fallback).
sr_rows_c8() { SR_TS="$SR_POST"; sr_row architect true 1 "1/4 ## A"; sr_row dev true 2 "1/4 ## A"; sr_row dev true 3 "4/4 ## D"
  sr_frow dev 4 "1/4 ## A" "$SR_G/architecture-tea-1.md"; }
# SRC9: tea-1's only row carries a mark_file with no party-mode tail (the guard's unrendered placeholder) -> it names no
# seat file and is read as a field-less row: tea-1 covered at tea 1/4, SOURCES rc 0.
sr_rows_c9() { SR_TS="$SR_POST"; sr_row architect true 1 "1/4 ## A"; sr_row dev true 2 "1/4 ## A"; sr_row dev true 3 "4/4 ## D"
  sr_frow tea 4 "1/4 ## A" "<your seat file>"; }
# SRC10: SRC9's tail-less tea row (a path cut at a blank) plus an UNCITED tea field-row naming architecture-tea-1.md ->
# the seat is a field seat, so the tail-less row (field-less precedence) cannot cover it: tea-1 refused by name.
sr_rows_c10() { SR_TS="$SR_POST"; sr_row architect true 1 "1/4 ## A"; sr_row dev true 2 "1/4 ## A"; sr_row dev true 3 "4/4 ## D"
  sr_frow tea 4 "1/4 ## A" "/a"
  printf '{"v":1,"ts":"%s","sprint":305,"role":"tea","role_contract_cited":false,"tool_use_id":"toolu_sf5","shard":"1/4 ## A","mark":"rendered","mark_file":"%s"}\n' "$SR_TS" "$SR_G/architecture-tea-1.md"; }
SRC6W="$(sr_fbuild "$SR_SPRE" 0 sr_rows_c6)"; SRC7W="$(sr_fbuild "$SR_SPRE" 0 sr_rows_c7)"; SRC8W="$(sr_fbuild "$SR_SPRE" 0 sr_rows_c8)"
# SRC11: tea-1's only row is a field-row whose mark_file the brief quoted (`"<path>"`) -> one pair of quotes stripped,
# the tail matches architecture-tea-1.md: covered, SOURCES rc 0.
sr_rows_c11() { SR_TS="$SR_POST"; sr_row architect true 1 "1/4 ## A"; sr_row dev true 2 "1/4 ## A"; sr_row dev true 3 "4/4 ## D"
  sr_frow tea 4 "1/4 ## A" "\\\"$SR_G/architecture-tea-1.md\\\""; }
SRC9W="$(sr_fbuild "$SR_SPRE" 0 sr_rows_c9)"; SRC10W="$(sr_fbuild "$SR_SPRE" 0 sr_rows_c10)"; SRC11W="$(sr_fbuild "$SR_SPRE" 0 sr_rows_c11)"
if [ -z "$SRC1W" ] || [ -z "$SRC2W" ] || [ -z "$SRC3W" ] || [ -z "$SRC4W" ] || [ -z "$SRC5W" ] || [ -z "$SRC5BW" ] || [ -z "$SRC6W" ] || [ -z "$SRC7W" ] || [ -z "$SRC8W" ] || [ -z "$SRC9W" ] || [ -z "$SRC10W" ] || [ -z "$SRC11W" ] || [ -z "$SR_LINE" ]; then
  bad "SRC: FIXTURE BROKEN -- a seat-file-row world could not be built"
else
  sr_drive "$JOIN" "$SRC1W"
  if sr4; then ok "SRC1: architecture's rows field-less and pre-install, requirements' post-install field-rows at the same roles, ordinals and K -> SEAT-ROWS: SKIP legacy-round architecture, rc 0"
  else bad "SRC1: another round's field-rows dated or covered the cited round (rc=$RC): $(head -3 "$JO")"; fi
  sr_drive "$JOIN" "$SRC2W"
  if sr8; then ok "SRC2: tea-1's only row names an absent file -> REFUSED rc 2 naming tea-1 alone, the row covering no other seat"
  else bad "SRC2: a field-row naming an absent file covered a seat (rc=$RC): $(head -3 "$JO")"; fi
  sr_drive "$JOIN" "$SRC3W"
  if sr2; then ok "SRC3: three seats by relative field-rows, tea-1 by a field-less row -> the field-less fallback covers tea-1, SOURCES rc 0"
  else bad "SRC3: a field-less row beside field-rows no longer infers (rc=$RC): $(head -3 "$JO")"; fi
  sr_drive "$JOIN" "$SRC4W"
  if sr8; then ok "SRC4: another round's tea-1 field-row at tea 1/4 -> architecture-tea-1 REFUSED rc 2 by name"
  else bad "SRC4: a field-row covered a seat of another round (rc=$RC): $(head -3 "$JO")"; fi
  sr_drive "$JOIN" "$SRC5W"
  if sr4; then ok "SRC5: every seat by its own pre-install field-row, seats committed pre-install -> SEAT-ROWS: SKIP legacy-round architecture"
  else bad "SRC5: a round of pre-install field-rows was not legacy (rc=$RC): $(head -3 "$JO")"; fi
  sr_drive "$JOIN" "$SRC5BW"
  if sr9; then ok "SRC5b: the same pre-install field-rows, seats committed after the install -> judged, all 4 REFUSED: a pre-install field-row covers nothing"
  else bad "SRC5b: a pre-install field-row covered its seat (rc=$RC): $(head -3 "$JO")"; fi
  sr_drive "$JOIN" "$SRC6W"
  if sr2; then ok "SRC6: absolute ${SR_G} field-rows, the join under another JR_ROOT -> each matches its seat by tail, dated and covered, SOURCES rc 0"
  else bad "SRC6: a field-row under a relocated root did not match its seat (rc=$RC): $(head -3 "$JO")"; fi
  sr_drive "$JOIN" "$SRC7W"
  if sr2; then ok "SRC7: dev-1 named by its field-row and carrying a field-less row at K 9, its siblings at K 4 -> the field seat votes no K, SOURCES rc 0"
  else bad "SRC7: a field seat's field-less row voted K (rc=$RC): $(head -3 "$JO")"; fi
  sr_drive "$JOIN" "$SRC8W"
  if sr8; then ok "SRC8: a cited post-install dev field-row names architecture-tea-1.md -> tea-1 REFUSED rc 2 by name: a field-row covers only its own role's seat"
  else bad "SRC8: a field-row of another role covered tea-1 (rc=$RC): $(head -3 "$JO")"; fi
  sr_drive "$JOIN" "$SRC9W"
  if sr2; then ok "SRC9: tea-1's only row carries a tail-less mark_file -> read as a field-less row, tea-1 covered, SOURCES rc 0"
  else bad "SRC9: a tail-less mark_file row matched nothing (rc=$RC): $(head -3 "$JO")"; fi
  sr_drive "$JOIN" "$SRC10W"
  if sr8; then ok "SRC10: a tail-less tea row beside an uncited tea field-row naming tea-1 -> tea-1 REFUSED rc 2: the tail-less row cannot cover a field seat"
  else bad "SRC10: a tail-less row covered a seat a field-row names (rc=$RC): $(head -3 "$JO")"; fi
  sr_drive "$JOIN" "$SRC11W"
  if sr2; then ok "SRC11: tea-1's field-row carries a double-quoted mark_file -> the quotes stripped, it matches its seat, SOURCES rc 0"
  else bad "SRC11: a quoted mark_file did not match its seat (rc=$RC): $(head -3 "$JO")"; fi
fi
fi # sg tail

echo
if [ "$fails" -eq 0 ]; then echo "$NAME: PASS"; exit 0; fi
echo "$NAME: $fails assertion(s) FAILED" >&2
exit 1
