#!/bin/bash
#
# content-seal.sh -- THE CONTENT SEAL on gate join inputs. One file holds the SEALED SET, the seal
# row's shape, and the comparison every join reader runs; the recorder hook SOURCES it and the three
# join programs EXECUTE it, so no second copy of the set or the comparison exists anywhere.
#
# WHY IT EXISTS. Every write-capturing hook matches Edit|Write|MultiEdit, so a Bash rewrite of a join
# input -- `perl -0pi` inside a shell function, `sed -i`, a `python3` open-for-write, `printf >>`,
# `git checkout` -- reaches no hook, and the join then reads whatever bytes are on disk. The s319
# lead patched twelve adversary shards' `tool_use_id:` that way and the merge exited 0. A Bash DENY
# was weighed and refused: a census of the reference consumer's transcripts found it would refuse
# about 1,219 real calls, and its grammar could not see the motivating write. A seal does not
# enumerate commands. `ai-dlc-content-seal.sh` records, at PostToolUse, the sha256 of the bytes a
# sanctioned write left; a reader refuses a file whose bytes are not those, whatever channel changed them.
#
# THE SEALED SET IS WHAT THE JOIN PROGRAMS READ (`seal_sealed`, below, is its one declaration):
#   planning-artifacts/s<N>/shards/*/*.md          every shard file: adversary shards (suffixed
#                                                  `<x>-p<M>/` and unsuffixed, `requirements-elicitation/`,
#                                                  `stories-elicitation/`), remediator part records
#                                                  (`<x>-repair-p<M>/`, `requirements-party-repair/`,
#                                                  `requirements-elicitation-repair/`) and every
#                                                  section copy under them
#   planning-artifacts/s<N>/*-repair*.md           the JOINED RECORDS join-remediator-shards.sh writes:
#                                                  `<artifact>-repair-p<M>.md`, `requirements-party-repair.md`,
#                                                  `requirements-elicitation-repair.md`, `gate-<type>-repair-p<M>.md`
#   gate-adjudication/<nonce>.part-<i>of<N>.jsonl  gate-adjudicator part files
# Paths are relative to the state dir, EXCEPT the review shards (`seal_sealed_review`, the second
# declaration, header "REVIEW SHARDS" below), whose paths are relative to the project root of the
# worktree holding them. `*` in a `case` pattern crosses `/`, so a file in any
# subdirectory under `shards/` is sealed, section copies included, and a `-repair` file anywhere under
# `s<N>/` is too. That breadth is safe because every reader compares ONLY THE FILES IT READS: a seal row
# on a file no program consults is a record and nothing else, so a wider seal moves no verdict.
# `s<N>` is ANY sprint, not the snapshot's live one: reading the snapshot inside a hot matcher buys
# nothing, because a seal on a dead sprint's file reaches no reader unless one is pointed at that file,
# and then checking it is correct. OUT of the set: the snapshot, every arm-6 path of
# `ai-dlc-gate-remediation-guard.sh`, the gate verdict and the merged adversarial pass files (below).
#
# THE ROW, appended to `<state>/planning-artifacts/.artifact-writes.jsonl` beside the guard's
# `kind: "artifact-write"` rows:
#   {v:1, kind:"content-seal", ts, path, actor, agent_id, session, tool, tool_use_id,
#    transcript_path, root, sha256}
# `path` and `root` are spelled as `record_artifact_write` in the guard spells them: `path` from the
# state dir's NAME onward, `root` the physical tree holding the state dir. `actor` is `agent` (a
# dispatched agent: `agent_id` set), `session` (the top-level session: no `agent_id`), or
# `program:<name>` (a join program's own output, `--record`). `kind` is the second key so the literal
# `"kind":"content-seal"` that `jq -c` writes is a one-grep test for "this ledger holds seals"
# (`SEAL_KIND_ERE`). Every reader that keys on `kind == "artifact-write"` passes these rows over; the seal reads below
# key on `kind == "content-seal"` and carry NO `agent_id` filter, because a top-level session's row
# has an empty `agent_id` and is exactly the row that must be compared.
#
# PROGRAM ROWS, PER OUTPUT. A program appends a row (`--record`) for every file it writes. Whether a
# reader COMPARES on that row is decided by whether one of the three programs reads that output:
#   - join-remediator-shards.sh's JOINED RECORD is SEALED AND COMPARED. The join's own `--sources` and
#     `--escalations` modes read it, and run `--check` on it at mode entry. The serial remediator's
#     Edit append to it fires the recorder, whose newer row is the one compared, so a sanctioned
#     append matches and a Bash rewrite (the BL-530 third instance) is refused naming the newest writer.
#   - validate-gate-adjudication.sh --merge's VERDICT is RECORD-ONLY and outside the set, by ruling. A
#     verdict, merged or unsharded, is bound by its `gate-adjudication/.verdict-writes.jsonl` row and
#     the dispatch-binding arm alone; no mode compares its bytes with a seal. --merge still appends
#     its program row for the verdict, which names the writer and nothing keys on.
#   - merge-adversarial-shards.sh's PASS FILE (`<artifact>-adversarial-p<M>.md`,
#     `requirements-elicitation.md`) is RECORD-ONLY and outside the set. Its reader is Check 24
#     (`validate-adversarial-convergence.sh`). The merge looks at an existing pass file twice: a
#     `cmp -s` against what it would write, which already refuses any byte difference, and an EARLIER
#     pass's `findings_critical`, read for the summed-divergence stamp. LIMIT: a Bash edit of a prior
#     pass's count can move that stamp, and no seal comparison guards it; Check 24 reads the same bytes.
#
# NO SEAL ROW, NO COMPARISON. A sealed-set file that has never had a Write or Edit -- one created
# wholly through Bash -- carries no row and passes as it did before seals existed. For an adversary
# shard the merge's own "no write-ledger row" refusal still catches it. For a gate-adjudicator part
# `--merge` refuses a part with no row once this tree's ledger holds a tool seal row dated before the
# part's nonce (`--first-tool-ts`): the recorder was live when that gate began, so a part without a
# row was written through Bash. For a remediator part nothing here does. That is the price of moving
# nothing already on disk.
#
# USAGE (as a program; sourced, it only defines the functions)
#   content-seal.sh --check <state-dir> <file>... | -     compare each SEALED file that carries a seal
#        row against its bytes; `-` reads the file list from stdin, one per line. Exit 0: nothing
#        differs (an unsealed file, a file with no row, and a ledger with no seal row all pass, so a
#        tree written before the recorder existed reads as it always did). Exit 1: one line per file
#        whose bytes differ from its newest seal row, naming that row's writer and the remedy.
#        Exit 2: the ledger does not parse, jq is absent, or the state dir does not exist.
#   content-seal.sh --row <state-dir> <file>...           one line per file, in argument order: the
#        newest seal row for it (JSON), or `null`. Same root filter as --check.
#   content-seal.sh --last-tool-row <state-dir> <file>... | -   one line per SEALED file carrying a
#        TOOL seal row (actor `agent` or `session`): the LAST such row in file order, as
#        `file US actor US agent_id US tool US ts` (US = 0x1f), `file` as given; nothing for a file
#        with none. Program rows are skipped, so a `--mark` row cannot hide the tool write before it.
#        Same root filter as --check. The shard merge calls it once over all shards and refuses a
#        shard whose last tool write was the top-level session's.
#   content-seal.sh --record <state-dir> program:<name> <file>...   append a program row per file.
#        A file outside the state dir is skipped; a state dir with no planning-artifacts/ records
#        nothing (it is not a pipeline state dir) and exits 0.
#   content-seal.sh --record-expect <state-dir> program:<name> <sha256> <file>   append ONE program
#        row for <file> recording <sha256>, and only when the file's bytes on disk ARE that sha. A
#        program that wrote the file from bytes it hashed itself passes that sha, so a write landing
#        between its own write and this row is never sealed as the program's: exit 1, no row, and
#        the file stays refused by every reader. `wait-for-deliverable.sh --mark` is the caller.
#   content-seal.sh --first-tool-ts <state-dir>           the earliest `ts` of a TOOL seal row (actor
#        `agent` or `session`) in this tree's ledger, same root filter as --check, or nothing when
#        there is none. When the recorder first ran here; program rows do not count.
#   content-seal.sh --review-shard <shard file> [--legacy]   one line, then exit (header: "REVIEW SHARDS"):
#        0 `SEAL-OK`; 1 `SEAL-REFUSED: <reason>` naming the remedy (re-dispatch the reviewer for that
#        shard); 3 `SEAL-NONE` (with --legacy only: no row for the file); 2 a usage error or a file
#        that is not a review shard; 4 `SEAL-UNAVAILABLE: <reason>` -- the ENVIRONMENT cannot read the
#        seal (jq is not on PATH, git cannot place the file in a worktree, or the ledger does not
#        parse), a fault the lead repairs and re-dispatching a reviewer cannot. Never 0 or 3 then.
#   content-seal.sh --agent-ere                           print AGENT_ID_ERE.
#   content-seal.sh --admit-marker <file>... | -          (header: "THE MARKER ADMISSION") exit 0: every
#        file is admitted; 1: one line per refused file on stdout; 2: a usage error, or a seal comparison
#        that could not run (jq absent, a ledger that does not parse).
#
# THE MARKER ADMISSION (BL-750). `wait-for-deliverable.sh --complete`/`--complete-repair` and the shard
# merge's completion belt consume a file whose last non-blank line is a `seat-complete: ` or
# `repair-complete: serial ` marker. A marker with no `sha=` is a line any writer can append, a Bash
# `printf >>` included, so it is admitted ONLY inside the SEALED SET's legacy window, and only there:
#   - A file OUTSIDE the sealed set (`seal_sealed`) is admitted as before, whatever its marker. Graph
#     s319's `epics/part-<n>.md` end in a bare marker the lead's own brief writes; refusing them would
#     wedge a resume, and no join program reads them through a seal.
#   - A SEALED marker (`sha=<hex>`) must equal the sha256 of the body above it (wait-for-deliverable.sh's
#     `seal_body`, hashed as `seal_body_sha <file> 0`), and the file must pass `--check` against its
#     newest seal row.
#   - A BARE marker is admitted only while the ROLE FILE its kind names is in the LEGACY state: the seat
#     field (`seat-complete: <step> <seat> ...`, term 3) names `<seat>.md`; `repair-complete: serial`
#     names `remediator.md`. The role file is read beside the state dir's own project root, at
#     `<root>/.claude/team-roles/<seat>.md` then `<root>/core/team-roles/<seat>.md`. LEGACY means that
#     file still tells a seat to fall back to a bare line (`unknown arg: --mark`, the token
#     `process-rule-pins` pins out of the shipped role files), or carries no `wait-for-deliverable.sh
#     --mark` (`--mark-repair` for a repair record) instruction at all. That is the pull's step-3 ->
#     reconcile-merge window, where the engine is new and the installed role text is not; before 0.904.0
#     every role file carried BOTH the `--mark` instruction and the fallback, so the fallback is the
#     discriminator and the instruction's absence only covers role text older than `--mark` itself.
#   - A role file that does not resolve, cannot be read, or a seat field that is not a role name, does
#     NOT acquit: the file is refused. So is an absolute AI_DLC_STATE_DIR outside the project, whose
#     parent holds no role file -- the fail-closed direction.
# The admission keys on the file's path AS SPELLED (logical `pwd`), as `--mark` does, so the state dir is
# the prefix before the path's FIRST `/planning-artifacts/`.
#
# REVIEW SHARDS. `docs/reviews/s<N>/shards/<idx>-code-review-<sha12>[-p<M>]/<f>.md` and the
# `-qa-validation-` equivalent are written by a reviewer seat in the frozen dev WORKTREE, outside any
# state dir, and `merge-review-shards.sh` joins them. Their rows differ from the rows above in three
# fields: `path` is project-root-relative (`docs/reviews/...`), `root` is the shard's PHYSICAL worktree
# root (`git rev-parse --show-toplevel`, `pwd -P`), and `body_sha` -- carried on these rows only -- is
# the sha256 of the body wait-for-deliverable.sh's `seal_body` extracts: `seal_review_body <f> 1`, or
# `<f> 0` when the file's last non-blank line is a `seat-complete: ` marker (the marker dropped), so a
# seat that Edits a shard it already marked and re-marks it through the old Bash --mark still matches.
# The recorder writes them into its own LOG_DIR ledger, whatever tree holds the shard. A reader finds
# that ledger from ANY tree as
#   <parent of `git rev-parse --path-format=absolute --git-common-dir`>/${AI_DLC_STATE_DIR:-_bmad-output}/planning-artifacts/.artifact-writes.jsonl
# (an absolute AI_DLC_STATE_DIR is used as is), i.e. the MAIN checkout's state dir; never
# `<worktree>/_bmad-output`, which in a worktree is a tracked, stale copy. A git without
# `--path-format` (before 2.31) gets the plain `--git-common-dir`, asked from the worktree root and
# resolved against it when relative. LIMITS: a bare repository or a submodule has no main checkout
# beside its common dir, and the reader then finds no row and refuses; the recorder and the reader name
# the same ledger only when the recorder's own session project directory is the main checkout -- otherwise, again, a refusal.
# Review rows are matched on `root` EXACTLY (no empty-root leniency), and no existing reader sees them:
# `--check`, `--row` and `--last-tool-row` key on a state-dir-relative path no review row carries,
# and `--first-tool-ts` skips any row with `body_sha`.
#   --review-shard compares the NEWEST row for the file. Non-legacy: the whole-file sha256 must equal
# the row's, and a file with NO row is refused (a key= marker requires a row, so a mis-pointed ledger
# refuses rather than acquits). --legacy (a marker without key=, written before this engine): the
# whole-file sha256, OR the row's body_sha against the file's body with its last line -- which must be a
# `seat-complete: ` marker -- dropped (the old --mark's Bash append after the seat's Write); no row is
# SEAL-NONE. Both modes then refuse when the LAST TOOL row's actor is `session` (the
# merge-adversarial-shards.sh rule): a review shard is the reviewer's own.
#
# "NEWEST" IS FILE ORDER. The ledger is append-only and `ts` has one-second resolution, so the last
# matching line is the newest write. Rows whose `root` is another tree (a worktree's or a clone's write
# recorded in this session's ledger) are not this tree's seal and are skipped; a row with no `root` is
# read as this tree's.
#
# LIMITS, stated in the recorder's header and true here: a Bash write to the ledger can forge a seal,
# which is the floor every ledger in this pipeline shares; and a Write or Edit by any actor re-seals the
# file, so a seal attests the channel of the last write, not who should have made it.
#
# Compatible with bash 3.2 and BSD tools.

# A dispatched agent's id as the harness spells it in a hook payload: `a` and sixteen hex digits.
# Measured on the reference consumer's transcripts and on two scratch PostToolUse captures. A value of
# any other shape is never compared, only ignored, so a lead whose ids look different loses the
# comparison and never gains a refusal.
AGENT_ID_ERE='^a[0-9a-f]{16}$'
# The cheap presence test for "this ledger holds seal rows", before any jq. Whitespace-tolerant, so a
# row not written by `jq -c` is still seen; a ledger with none is read exactly as before seals existed.
SEAL_KIND_ERE='"kind":[[:space:]]*"content-seal"'

seal_sealed() { # $1 path relative to the state dir -> 0 when it is in the sealed set
  case "$1" in
    planning-artifacts/s[0-9]*/shards/*/*.md) return 0 ;;
    planning-artifacts/s[0-9]*/*-repair*.md) return 0 ;;
    gate-adjudication/*.part-*.jsonl) return 0 ;;
  esac
  return 1
}

# The REVIEW-SHARD set (header: "REVIEW SHARDS"), the second declaration. Its paths are relative to
# the PROJECT ROOT of the worktree holding the shard, never to a state dir, and no reader of the
# first declaration ever sees one.
seal_sealed_review() { # $1 path relative to its worktree root -> 0 when it is a review shard
  case "$1" in
    docs/reviews/s[0-9]*/shards/*-code-review-*/*.md|docs/reviews/s[0-9]*/shards/*-qa-validation-*/*.md) return 0 ;;
  esac
  return 1
}

seal_sha() { # $1 file -> its sha256, or nothing
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" 2>/dev/null | cut -d' ' -f1
  else sha256sum "$1" 2>/dev/null | cut -d' ' -f1; fi
}

# seal_norm <file_path as a payload spells it> <state dir name> <state dir as the session spells it>
# -> sets SEAL_REL (from the state dir's name onward) and SEAL_ROOT (physical tree), rc 1 when the
# path is under no state dir. The three spellings `record_artifact_write` accepts, in its order: the
# session's own state dir first, so a directory under it that shares the name cannot move the cut.
seal_norm() {
  local raw_root="${3%/*}"
  SEAL_REL=""; SEAL_ROOT=""
  case "$1" in
    "$3"/*) SEAL_REL="$2/${1#"$3"/}" ;;
    */"$2"/*) SEAL_REL="$2/${1#*/"$2"/}"; raw_root="${1%%/"$2"/*}" ;;
    "$2"/*) SEAL_REL="$1" ;;
    *) return 1 ;;
  esac
  SEAL_ROOT="$(cd "$raw_root" 2>/dev/null && pwd -P)" || SEAL_ROOT="$raw_root"
  return 0
}

# seal_append <ledger> <path> <root> <actor> <agent_id> <session> <tool> <tool_use_id> <transcript> <sha> [<body_sha>]
# <body_sha> is passed for a review-shard row only; every other row is written without the key, byte
# for byte as before it existed.
seal_append() {
  jq -nc --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg path "$2" --arg root "$3" --arg actor "$4" \
         --arg aid "$5" --arg sid "$6" --arg tool "$7" --arg tuid "$8" --arg tp "$9" --arg sha "${10}" \
         --arg bs "${11:-}" \
    '{v: 1, kind: "content-seal", ts: $ts, path: $path, actor: $actor, agent_id: $aid, session: $sid,
      tool: $tool, tool_use_id: $tuid, transcript_path: $tp, root: $root, sha256: $sha}
     + (if $bs == "" then {} else {body_sha: $bs} end)' >> "$1"
}

# ---------------------------------------------------------------- review shards (header: "REVIEW SHARDS")
# The body a seat-complete marker binds, as wait-for-deliverable.sh's `seal_body` extracts it: every
# line above the LAST NON-BLANK line, or with $2 = 1 that line too. The awk program is BYTE-IDENTICAL
# to `seal_body` in wait-for-deliverable.sh; the two must hash the same bytes.
seal_review_body() {  # $1 = path, $2 = 1 to keep the last non-blank line -> bytes on stdout
  awk -v k="${2:-0}" 'NF { L = NR } { a[NR] = $0 } END { if (k == 1) L++; for (i = 1; i < L; i++) print a[i] }' "$1" 2>/dev/null
}
seal_body_sha() { # $1 file, $2 keep flag -> sha256 of seal_review_body, or nothing
  if command -v shasum >/dev/null 2>&1; then seal_review_body "$1" "$2" | shasum -a 256 2>/dev/null | cut -d' ' -f1
  else seal_review_body "$1" "$2" | sha256sum 2>/dev/null | cut -d' ' -f1; fi
}

# seal_review_locate <file> -> sets _RV_FP (physical file), _RV_TOP (physical worktree root), _RV_REL
# (project-root-relative path), _RV_STATE (the MAIN checkout's state dir) and _RV_LEDGER; rc 1 with
# _RV_ERR set when git cannot place the file. git runs with GIT_DIR/GIT_WORK_TREE/GIT_COMMON_DIR unset,
# so an inherited environment cannot repoint it at another repository.
seal_review_locate() {
  local d top common
  _RV_FP=""; _RV_TOP=""; _RV_REL=""; _RV_STATE=""; _RV_LEDGER=""; _RV_ERR=""
  d="$(cd "$(dirname "$1")" 2>/dev/null && pwd -P)" || { _RV_ERR="its directory does not exist"; return 1; }
  _RV_FP="${d}/$(basename "$1")"
  top="$( unset GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR; git -C "$d" rev-parse --show-toplevel 2>/dev/null )" \
    && [ -n "$top" ] || { _RV_ERR="git cannot name the worktree holding it"; return 1; }
  _RV_TOP="$(cd "$top" 2>/dev/null && pwd -P)" || { _RV_ERR="its worktree root $top does not resolve"; return 1; }
  case "$_RV_FP" in "$_RV_TOP"/*) _RV_REL="${_RV_FP#"$_RV_TOP"/}" ;; *) _RV_ERR="it is not under its worktree root $_RV_TOP"; return 1 ;; esac
  # `--path-format=absolute` (git 2.31+) first. An older git prints the option back or fails, and the
  # plain form's answer is relative to the directory git ran in, so it is asked from the root and a
  # relative answer is resolved against the root.
  common="$( unset GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR; git -C "$_RV_TOP" rev-parse --path-format=absolute --git-common-dir 2>/dev/null )"
  case "$common" in
    /*) ;;
    *) common="$( unset GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR; git -C "$_RV_TOP" rev-parse --git-common-dir 2>/dev/null )" \
         || { _RV_ERR="git cannot name its common git dir"; return 1; }
       case "$common" in /*) ;; ?*) common="${_RV_TOP}/${common}" ;; *) _RV_ERR="git named no common git dir"; return 1 ;; esac ;;
  esac
  common="$(cd "$common" 2>/dev/null && pwd -P)" || { _RV_ERR="its common git dir does not resolve"; return 1; }
  case "${AI_DLC_STATE_DIR:-_bmad-output}" in
    /*) _RV_STATE="${AI_DLC_STATE_DIR}" ;;
    *)  _RV_STATE="${common%/*}/${AI_DLC_STATE_DIR:-_bmad-output}" ;;
  esac
  _RV_LEDGER="${_RV_STATE}/planning-artifacts/.artifact-writes.jsonl"
  return 0
}

# seal_review_record_row <ledger> <file> <actor> <agent_id> <session> <tool> <tool_use_id> <transcript> [<want sha>]
# -> append a review-shard row for <file> (already located), sha256 and body_sha taken from disk now;
# rc 1 and no row when the bytes move between the two hashes, or are not <want sha>.
seal_review_record_row() {
  local sha bsha keep=1
  sha="$(seal_sha "$_RV_FP")"; [ -n "$sha" ] || return 1
  # body_sha is the body WITHOUT a trailing seat-complete line, so a seat that Edits a shard it already
  # marked (then re-marks through the old Bash --mark) keeps a body the legacy reader can match.
  case "$(awk 'NF { l = $0 } END { print l }' "$_RV_FP" 2>/dev/null)" in 'seat-complete: '*) keep=0 ;; esac
  bsha="$(seal_body_sha "$_RV_FP" "$keep")"; [ -n "$bsha" ] || return 1
  # Both hashes must describe ONE set of bytes: a write landing between them records nothing.
  [ "$(seal_sha "$_RV_FP")" = "$sha" ] || return 1
  [ -z "${9:-}" ] || [ "$sha" = "$9" ] || return 1
  seal_append "$1" "$_RV_REL" "$_RV_TOP" "$3" "$4" "$5" "$6" "$7" "$8" "$sha" "$bsha"
}

# seal_review_shard <file> [--legacy] -> one line; 0 SEAL-OK / 1 SEAL-REFUSED / 3 SEAL-NONE / 2 usage /
# 4 SEAL-UNAVAILABLE (the environment: jq, git placement, an unparseable ledger)
seal_review_shard() {
  local f="$1" legacy="${2:-}" tab us has want bwant actor aid tool ts tactor taid ttool tts have hb last rm
  local nr='re-dispatch the reviewer for that shard, which writes it with Write and marks it with wait-for-deliverable.sh --mark; never amend a review shard through Bash or a lead Write/Edit'
  [ -f "$f" ] || { echo "SEAL-REFUSED: $f is not a file; $nr"; return 1; }
  local ne='the environment cannot read the seal, which re-dispatching the reviewer does not repair: fix it in the lead checkout, then merge or mark again'
  if ! seal_review_locate "$f"; then echo "SEAL-UNAVAILABLE: $f cannot be placed in a git worktree ($_RV_ERR), so its content-seal row cannot be found; $ne"; return 4; fi
  seal_sealed_review "$_RV_REL" || { echo "content-seal: --review-shard: $f is $_RV_REL relative to its worktree root, not docs/reviews/s<N>/shards/<idx>-code-review-<sha12>[-p<M>]/<f>.md or the qa-validation equivalent" >&2; return 2; }
  command -v jq >/dev/null 2>&1 || { echo "SEAL-UNAVAILABLE: $f: jq is not on PATH, so the seal rows in $_RV_LEDGER cannot be read; $ne"; return 4; }
  tab=""
  if [ -f "$_RV_LEDGER" ]; then
    tab="$(jq -rn --arg p "$_RV_REL" --arg r "$_RV_TOP" '
      reduce (inputs | select(type == "object") | select(.kind == "content-seal") | select(.path == $p)
              | select(.root == $r)) as $x ({n: null, t: null};
        .n = $x | if ($x.actor == "agent" or $x.actor == "session") then .t = $x else . end)
      | [(if .n == null then "N" else "Y" end), (.n.sha256 // ""), (.n.body_sha // ""), (.n.actor // ""),
         (.n.agent_id // ""), (.n.tool // ""), (.n.ts // ""), (.t.actor // ""), (.t.agent_id // ""),
         (.t.tool // ""), (.t.ts // "")] | map(tostring) | join("\u001f")' "$_RV_LEDGER")" \
      || { echo "SEAL-UNAVAILABLE: $f: the write ledger $_RV_LEDGER does not parse as JSON lines; $ne"; return 4; }
  fi
  us="$(printf '\037')"
  has=N
  [ -n "$tab" ] && IFS="$us" read -r has want bwant actor aid tool ts tactor taid ttool tts <<< "$tab"
  if [ "$has" != Y ]; then
    if [ "$legacy" = --legacy ]; then
      echo "SEAL-NONE: $f carries no content-seal row in $_RV_LEDGER (legacy marker: accepted without a seal comparison)"
      return 3
    fi
    echo "SEAL-REFUSED: $f carries no content-seal row in $_RV_LEDGER (path $_RV_REL, root $_RV_TOP). Either the shard was not written with Write or Edit by its seat: re-dispatch the reviewer for that shard. Or the content-seal recorder is not registered, or produced no row: check .claude/settings.json for ai-dlc-content-seal.sh under PostToolUse Write|Edit|MultiEdit, then re-dispatch the reviewer"
    return 1
  fi
  have="$(seal_sha "$_RV_FP")"
  rm=0
  if [ -n "$have" ] && [ "$have" = "$want" ]; then rm=1
  elif [ "$legacy" = --legacy ] && [ -n "$bwant" ]; then
    # The old --mark appended its marker through Bash after the seat's Write: the body above that
    # marker is what the Write sealed. Only a seat-complete line may be dropped, never another line.
    last="$(awk 'NF { l = $0 } END { print l }' "$_RV_FP" 2>/dev/null)"
    case "$last" in
      'seat-complete: '*) hb="$(seal_body_sha "$_RV_FP" 0)"; [ -n "$hb" ] && [ "$hb" = "$bwant" ] && rm=1 ;;
    esac
  fi
  if [ "$rm" != 1 ]; then
    echo "SEAL-REFUSED: $f changed after its last sealed write: the content seal $(_seal_writer "$actor" "$aid" "$tool") wrote at ${ts:-<no ts>} records sha256 ${want:-<none>} and the file is ${have:-<unreadable>} on disk, so its bytes came through a channel that records no seal (a Bash redirect, sed -i, perl -pi, a python3 open, git checkout); $(_seal_remedy "$actor" "$_RV_REL")"
    return 1
  fi
  if [ "$tactor" = session ]; then
    echo "SEAL-REFUSED: $f was last written by $(_seal_writer "$tactor" "$taid" "$ttool") at ${tts:-<no ts>}, not by its reviewer; a lead Write or Edit re-seals the bytes but a review shard is the reviewer's own; $(_seal_remedy "$tactor" "$_RV_REL")"
    return 1
  fi
  echo "SEAL-OK: $f matches its newest content-seal row ($(_seal_writer "$actor" "$aid" "$tool") at ${ts:-<no ts>})"
  return 0
}

# ---------------------------------------------------------------- the readers' side (program mode)
_seal_state() { # $1 state dir -> sets _SP (physical), _SN (name), _SR (root), _SL (ledger); rc 2 if absent
  _SP="$(cd "$1" 2>/dev/null && pwd -P)" || { echo "content-seal: the state dir $1 does not exist" >&2; return 2; }
  # The NAME as spelled, as the recorder spells it (basename of AI_DLC_STATE_DIR); the root as the
  # guard and the recorder compute it, the physical form of the state dir's SPELLED parent.
  _SN="${1%/}"; _SN="${_SN##*/}"
  _SR="$(cd "$(dirname "${1%/}")" 2>/dev/null && pwd -P)" || _SR="${_SP%/*}"
  _SL="${_SP}/planning-artifacts/.artifact-writes.jsonl"
  return 0
}
_seal_rel() { # $1 file -> sets _REL (under the state dir) and _FP (physical); rc 1 if outside
  local d
  d="$(cd "$(dirname "$1")" 2>/dev/null && pwd -P)" || return 1
  _FP="${d}/$(basename "$1")"
  case "$_FP" in "$_SP"/*) _REL="${_FP#"$_SP"/}"; return 0 ;; esac
  return 1
}
_seal_has_rows() { [ -f "$_SL" ] && grep -qE "$SEAL_KIND_ERE" "$_SL"; }
# The newest seal row per path in this tree, one line each: path US sha US actor US agent_id US tool US ts.
# US (0x1f) and not a tab, because `read` collapses runs of a whitespace IFS and an empty agent_id
# would shift every field after it.
_seal_table() {
  jq -rn --arg r "$_SR" '
    reduce (inputs | select(type == "object") | select(.kind == "content-seal")
            | select((.path | type) == "string")
            | select((.root // "") == "" or .root == $r)) as $x ({}; .[$x.path] = $x)
    | .[] | [.path, (.sha256 // ""), (.actor // ""), (.agent_id // ""), (.tool // ""), (.ts // "")]
    | map(tostring) | join("\u001f")' "$_SL"
}
_seal_writer() { # actor agent_id tool -> words naming the writer
  case "$1" in
    program:*) printf 'program %s' "${1#program:}" ;;
    *) if [ -n "$2" ]; then printf 'agent %s (%s)' "$2" "${3:-tool}"
       else printf 'the top-level session, which carries no agent_id (%s)' "${3:-tool}"; fi ;;
  esac
}
_seal_remedy() { # actor, path relative to the state dir (or, for a review shard, to its worktree root) -> the remedy sentence
  case "$2" in
    docs/reviews/s[0-9]*/shards/*/*.md)
      # A review shard is the reviewer's alone: a lead Edit re-seals the bytes but leaves a shard last
      # written by the top-level session, which --review-shard refuses, and --mark never seals Bash bytes.
      printf 're-dispatch the reviewer for that shard, which rewrites it with Write and marks it with wait-for-deliverable.sh --mark (a lead Write or Edit re-seals the bytes but leaves a shard last written by the top-level session, which is refused), and never amend a review shard through Bash'
      return ;;
  esac
  case "$2" in
    planning-artifacts/s[0-9]*/shards/*-repair-p*/*.md) ;;
    planning-artifacts/s[0-9]*/shards/*/*.md)
      # A shard --mark sealed keeps the restore-then-mark remedy below.
      if [ "$1" != program:wait-for-deliverable ]; then
      # Same shape as the gate part: a lead Write or Edit re-seals the bytes, and the merge then
      # refuses a shard last written by the top-level session. Remediator parts (-repair-p) go
      # through the join, which has no session-row refusal, so they keep the generic remedy.
      printf 're-dispatch the adversary for that shard, then merge with merge-adversarial-shards.sh --rerun <shard>.md@<ISO> (a lead Write or Edit re-seals the bytes but leaves a shard last written by the top-level session, which the merge refuses), and never amend a join input through Bash'
      return
      fi ;;
  esac
  case "$2" in
    gate-adjudication/*.part-*.jsonl)
      # A lead Edit would re-seal the bytes, and --merge then refuses a part last written by the
      # top-level session, so the only remedy that clears is a fresh adjudicator dispatch.
      printf 're-dispatch the gate-adjudicator for that slice, which writes the file with Write and seals it again (a lead Edit re-seals the bytes but leaves a part the top-level session wrote, which --merge refuses), and never amend a gate file through Bash'
      return ;;
  esac
  case "$1" in
    # --mark appends a marker; re-running it over amended bytes is refused, and it never stacks a
    # second marker, so the only remedy is the bytes it sealed, restored with Edit, then the mark.
    program:wait-for-deliverable) printf 'restore the bytes with Edit, then re-run wait-for-deliverable.sh --mark (or --mark-repair), which re-seals the file' ;;
    program:*) printf 're-run %s, which writes the file and seals it again (it never overwrites, so move the file aside first), or restore its bytes with Edit, which seals them again' "${1#program:}" ;;
    *) printf 'restore the file with Write or Edit (which seals it again) or re-dispatch its writer, and never amend a join input through Bash' ;;
  esac
}

seal_check() { # <state dir> <file>... -> exit 0 / 1 (lines on stdout) / 2
  local st="$1" f tab row want actor aid tool ts have rc=0 us
  shift
  _seal_state "$st" || return 2
  _seal_has_rows || return 0
  command -v jq >/dev/null 2>&1 || { echo "content-seal: jq is not on PATH; the seal rows in $_SL cannot be read" >&2; return 2; }
  tab="$(_seal_table)" || { echo "content-seal: the write ledger $_SL does not parse as JSON lines" >&2; return 2; }
  [ -n "$tab" ] || return 0
  us="$(printf '\037')"
  for f in "$@"; do
    [ -n "$f" ] || continue
    _seal_rel "$f" || continue
    seal_sealed "$_REL" || continue
    row="$(printf '%s\n' "$tab" | awk -F "$us" -v p="${_SN}/${_REL}" '$1 == p { print; exit }')"
    [ -n "$row" ] || continue
    IFS="$us" read -r _ want actor aid tool ts <<< "$row"
    have="$(seal_sha "$_FP")"
    [ -n "$have" ] && [ "$have" = "$want" ] && continue
    printf '%s changed after its last sealed write: the content seal %s wrote at %s records sha256 %s and the file is %s on disk, so its bytes came through a channel that records no seal (a Bash redirect, sed -i, perl -pi, a python3 open, git checkout), or a Write/Edit whose seal has not landed yet; re-run; %s\n' \
      "$f" "$(_seal_writer "$actor" "$aid" "$tool")" "${ts:-<no ts>}" "${want:-<none>}" "${have:-<unreadable>}" "$(_seal_remedy "$actor" "$_REL")"
    rc=1
  done
  return "$rc"
}

seal_row() { # <state dir> <file>... -> one line per file: the newest seal row, or null
  local st="$1" f
  shift
  _seal_state "$st" || return 2
  if ! _seal_has_rows; then for f in "$@"; do echo null; done; return 0; fi
  command -v jq >/dev/null 2>&1 || { echo "content-seal: jq is not on PATH" >&2; return 2; }
  for f in "$@"; do
    if _seal_rel "$f" && seal_sealed "$_REL"; then
      jq -cn --arg p "${_SN}/${_REL}" --arg r "$_SR" '
        reduce (inputs | select(type == "object") | select(.kind == "content-seal") | select(.path == $p)
                | select((.root // "") == "" or .root == $r)) as $x (null; $x)' "$_SL" \
        || { echo "content-seal: the write ledger $_SL does not parse as JSON lines" >&2; return 2; }
    else
      echo null
    fi
  done
}

seal_first_tool_ts() { # <state dir> -> the earliest ts of a tool seal row in this tree, or nothing
  _seal_state "$1" || return 2
  _seal_has_rows || return 0
  command -v jq >/dev/null 2>&1 || { echo "content-seal: jq is not on PATH" >&2; return 2; }
  jq -rn --arg r "$_SR" '
    [inputs | select(type == "object") | select(.kind == "content-seal")
     | select(.actor == "agent" or .actor == "session")
     | select(has("body_sha") | not)
     | select((.root // "") == "" or .root == $r)
     | select((.ts | type) == "string") | .ts] | min // empty' "$_SL" \
    || { echo "content-seal: the write ledger $_SL does not parse as JSON lines" >&2; return 2; }
}

seal_last_tool_row() { # <state dir> <file>... -> per sealed file with a tool row: path US actor US agent_id US tool US ts
  local st="$1" f tab us row
  shift
  _seal_state "$st" || return 2
  _seal_has_rows || return 0
  command -v jq >/dev/null 2>&1 || { echo "content-seal: jq is not on PATH" >&2; return 2; }
  # The LAST tool row per path in file order: program rows (`--record`, `--mark`) are skipped, so a
  # program row appended after a session Edit cannot hide it. Same root filter as --check.
  tab="$(jq -rn --arg r "$_SR" '
    reduce (inputs | select(type == "object") | select(.kind == "content-seal")
            | select((.path | type) == "string") | select(.actor == "agent" or .actor == "session")
            | select((.root // "") == "" or .root == $r)) as $x ({}; .[$x.path] = $x)
    | .[] | [.path, (.actor // ""), (.agent_id // ""), (.tool // ""), (.ts // "")]
    | map(tostring) | join("\u001f")' "$_SL")" \
    || { echo "content-seal: the write ledger $_SL does not parse as JSON lines" >&2; return 2; }
  [ -n "$tab" ] || return 0
  us="$(printf '\037')"
  for f in "$@"; do
    [ -n "$f" ] || continue
    _seal_rel "$f" || continue
    seal_sealed "$_REL" || continue
    row="$(printf '%s\n' "$tab" | awk -F "$us" -v p="${_SN}/${_REL}" '$1 == p { print; exit }')"
    [ -n "$row" ] && printf '%s%s%s\n' "$f" "$us" "${row#*"$us"}"
  done
  return 0
}

seal_record() { # <state dir> program:<name> <file>...
  local st="$1" actor="$2" f sha
  shift 2
  case "$actor" in program:[a-z0-9]*) ;; *) echo "content-seal: --record takes program:<name>, not '$actor'" >&2; return 2 ;; esac
  _seal_state "$st" || return 2
  [ -d "${_SP}/planning-artifacts" ] || return 0
  command -v jq >/dev/null 2>&1 || { echo "content-seal: jq is not on PATH" >&2; return 2; }
  for f in "$@"; do
    _seal_rel "$f" || continue
    [ -f "$_FP" ] || continue
    sha="$(seal_sha "$_FP")"
    [ -n "$sha" ] || continue
    seal_append "$_SL" "${_SN}/${_REL}" "$_SR" "$actor" "" "" "" "" "" "$sha" || return 2
  done
}

seal_record_expect() { # <state dir> program:<name> <sha256> <file> -> 0 row appended / 1 bytes moved / 2
  local st="$1" actor="$2" want="$3" f="$4" have
  case "$actor" in program:[a-z0-9]*) ;; *) echo "content-seal: --record-expect takes program:<name>, not '$actor'" >&2; return 2 ;; esac
  case "$want" in *[!0-9a-f]*|'') echo "content-seal: --record-expect takes a sha256, not '$want'" >&2; return 2 ;; esac
  _seal_state "$st" || return 2
  [ -d "${_SP}/planning-artifacts" ] || return 0
  command -v jq >/dev/null 2>&1 || { echo "content-seal: jq is not on PATH" >&2; return 2; }
  if ! _seal_rel "$f"; then
    # A review shard lives outside the state dir (header: "REVIEW SHARDS"); its row goes to the
    # ledger the shard's own git common dir names, which must be this state dir's.
    seal_review_locate "$f" && seal_sealed_review "$_RV_REL" || return 0
    [ "$(cd "$_RV_STATE" 2>/dev/null && pwd -P)" = "$_SP" ] || {
      echo "content-seal: $f is a review shard whose ledger is $_RV_LEDGER, not under $st; no row was recorded" >&2; return 2; }
    have="$(seal_sha "$_RV_FP")"
    if [ "$have" != "$want" ]; then
      echo "content-seal: $f is $have on disk, not the $want $actor wrote; no row was recorded" >&2
      return 1
    fi
    seal_review_record_row "$_SL" "$f" "$actor" "" "" "" "" "" "$want" || {
      echo "content-seal: $f changed while its row was being taken; no row was recorded" >&2; return 1; }
    return 0
  fi
  have="$(seal_sha "$_FP")"
  if [ "$have" != "$want" ]; then
    echo "content-seal: $f is $have on disk, not the $want $actor wrote; no row was recorded" >&2
    return 1
  fi
  seal_append "$_SL" "${_SN}/${_REL}" "$_SR" "$actor" "" "" "" "" "" "$want" || return 2
}

# seal_admit_marker <file>... (header: "THE MARKER ADMISSION") -> 0 every file admitted / 1 a line per
# refused file on stdout / 2 a seal comparison that could not run
seal_admit_marker() {
  local f lp st rel l kind seat want have out crc rf root c needle rc=0
  for f in "$@"; do
    [ -n "$f" ] || continue
    lp="$(cd "$(dirname "$f")" 2>/dev/null && pwd)" \
      || { echo "$f: its directory does not exist, so no marker on it can be admitted"; rc=1; continue; }
    lp="${lp}/$(basename "$f")"
    case "$lp" in */planning-artifacts/*) ;; *) continue ;; esac
    st="${lp%%/planning-artifacts/*}"; rel="planning-artifacts/${lp#"$st"/planning-artifacts/}"
    seal_sealed "$rel" || continue
    l="$(awk 'NF { l = $0 } END { print l }' "$f" 2>/dev/null)"
    case "$l" in
      "seat-complete: "*) kind=seat-complete; seat="$(printf '%s\n' "$l" | awk '{ print $3 }')"; needle='wait-for-deliverable.sh --mark ' ;;
      "repair-complete: serial "*) kind=repair-complete; seat=remediator; needle='wait-for-deliverable.sh --mark-repair' ;;
      *) continue ;;
    esac
    want="$(printf '%s\n' "$l" | awk '{ n = split($0, w, /[ \t]+/); for (i = 1; i <= n; i++) if (w[i] ~ /^sha=/) { y = 1; s = substr(w[i], 5) } } END { if (y) print "Y" s }')"
    if [ -n "$want" ]; then
      want="${want#Y}"; have="$(seal_body_sha "$f" 0)"
      if [ -z "$want" ] || [ "$have" != "$want" ]; then
        echo "$f ends in a $kind: marker whose sha=${want:-<empty>} is not the body above it (${have:-<unreadable>}): the file changed after it was marked; restore it, then re-mark with wait-for-deliverable.sh --mark"
        rc=1; continue
      fi
      out="$(seal_check "$st" "$f")"; crc=$?
      case "$crc" in
        0) ;;
        1) printf '%s\n' "$out"; rc=1 ;;
        *) echo "$f: the content-seal comparison for its $kind: marker could not run (exit $crc), so it is not admitted"; return 2 ;;
      esac
      continue
    fi
    root="$(dirname "$st")"; rf=""
    case "$seat" in
      ''|-*|*[!a-z0-9-]*) ;;
      *) for c in "$root/.claude/team-roles/$seat.md" "$root/core/team-roles/$seat.md"; do
           if [ -f "$c" ]; then rf="$c"; break; fi
         done ;;
    esac
    if [ -z "$rf" ] || [ ! -r "$rf" ]; then
      echo "$f ends in a bare $kind: marker (no sha=) and no readable role file for seat '${seat}' resolves under $root (.claude/team-roles/ or core/team-roles/), so the legacy window for a bare marker cannot be shown open; re-mark it with wait-for-deliverable.sh --mark, which seals it"
      rc=1; continue
    fi
    grep -qF -- 'unknown arg: --mark' "$rf" && continue
    grep -qF -- "$needle" "$rf" || continue
    echo "$f ends in a bare $kind: marker (no sha=), and $rf already instructs ${needle#wait-for-deliverable.sh }, so the legacy window is closed and any writer could have appended this line; re-mark it with wait-for-deliverable.sh ${needle#wait-for-deliverable.sh }, which seals it"
    rc=1
  done
  return "$rc"
}

seal_main() {
  local mode="${1:-}" st
  case "$mode" in
    --admit-marker)
      [ "$#" -ge 2 ] || { echo "usage: $0 --admit-marker <file>... | -" >&2; return 2; }
      shift
      if [ "$#" -eq 1 ] && [ "$1" = "-" ]; then
        set --
        while IFS= read -r _l; do [ -n "$_l" ] && set -- "$@" "$_l"; done
        [ "$#" -gt 0 ] || return 0
      fi
      seal_admit_marker "$@" ;;
    --check|--row|--last-tool-row)
      [ "$#" -ge 3 ] || { echo "usage: $0 $mode <state-dir> <file>... | -" >&2; return 2; }
      st="$2"; shift 2
      if [ "$#" -eq 1 ] && [ "$1" = "-" ]; then
        set --
        while IFS= read -r _l; do [ -n "$_l" ] && set -- "$@" "$_l"; done
        [ "$#" -gt 0 ] || return 0
      fi
      case "$mode" in
        --check) seal_check "$st" "$@" ;;
        --row) seal_row "$st" "$@" ;;
        *) seal_last_tool_row "$st" "$@" ;;
      esac ;;
    --record)
      [ "$#" -ge 4 ] || { echo "usage: $0 --record <state-dir> program:<name> <file>..." >&2; return 2; }
      st="$2"; shift
      seal_record "$st" "${2}" "${@:3}" ;;
    --record-expect)
      [ "$#" -eq 5 ] || { echo "usage: $0 --record-expect <state-dir> program:<name> <sha256> <file>" >&2; return 2; }
      seal_record_expect "$2" "$3" "$4" "$5" ;;
    --first-tool-ts)
      [ "$#" -eq 2 ] || { echo "usage: $0 --first-tool-ts <state-dir>" >&2; return 2; }
      seal_first_tool_ts "$2" ;;
    --review-shard)
      { [ "$#" -eq 2 ] || { [ "$#" -eq 3 ] && [ "$3" = --legacy ]; }; } \
        || { echo "usage: $0 --review-shard <shard file> [--legacy]" >&2; return 2; }
      seal_review_shard "$2" "${3:-}" ;;
    --agent-ere) printf '%s\n' "$AGENT_ID_ERE" ;;
    *) echo "usage: $0 --check|--row|--last-tool-row <state-dir> <file>... | --record <state-dir> program:<name> <file>... | --record-expect <state-dir> program:<name> <sha256> <file> | --first-tool-ts <state-dir> | --review-shard <shard file> [--legacy] | --admit-marker <file>... | - | --agent-ere" >&2
       return 2 ;;
  esac
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  seal_main "$@"
  exit $?
fi
