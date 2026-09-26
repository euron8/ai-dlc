#!/usr/bin/env bash
# validate-spawn-ledger.sh -- Check 22's mechanical arms, decided by a program instead
# of by an agent re-reading a paragraph at every implementation gate.
#
# WHY THIS EXISTS (v0.211.0). gate-validation.md Check 22 ("teammate-spawn role
# binding") publishes a fully decidable predicate: read `_bmad-output/spawn-ledger.jsonl`,
# filter to this sprint, and for EVERY row confirm that `model_bound` matches
# `aiDlcRoles.<role>.model`, that `role_contract_cited` is true, and that
# `role_file_readable` is not false. Three field comparisons per row against a JSON
# config. Its enforcement-map row carried `enforcer: []`, so a teammate performed all
# three by hand at every implementation-phase gate of every sprint.
#
# AND THE COMPARISON WAS ALREADY PROGRAMMED. `core/hooks/ai-dlc-dispatch-guard.sh`
# resolves the same pin and applies the same match tolerance at PreToolUse -- that is
# how `model_bound` gets its value in the first place. But a PreToolUse hook cannot run
# at a gate, so the gate restated the guard's rule in prose and asked an agent to
# execute it. That is the shape this program keeps finding: the program exists, in a
# copy nothing at the gate can reach.
#
# So `pin_key()` and `matches_pin()` below are the guard's, byte-identical, bound by
# I56 in scripts/validate-enforcement-map.sh. Two copies rather than a sourced helper
# for I25's reason -- a guard that sources a helper fails OPEN when a partial install
# omits it, and a dispatch guard that binds nothing is far worse than a duplicated
# eleven lines. What makes the duplication safe is the assertion, not the discipline:
# before this release the guard carried TWO definitions of `matches_pin()`, verbatim,
# with the first shadowed and dead, and nothing was looking.
#
# WHAT THIS DOES NOT DECIDE, deliberately. Check 22 stays `adjudication: llm`:
#
#   * EVERY recorded violation this script FAILS on has the SAME CLEARING PATH with
#     four arms -- a Rule 19(a) tier mismatch, a missing Rule 19(b) role-contract
#     citation, an unreadable role file, and an effort mismatch, which are four routes
#     into one exit code and not four dispositions. Arm 4 -- the escalation entry states
#     the remediation and names its artifact -- is a judgement about content. Arm 3 is
#     `validate-escalation-resolution.sh`, which this script does not invoke: the two
#     answer different questions about different files and the gate runs both. This
#     script reports the violation; the adjudicator decides whether it is cleared.
#   * STORY ROUTING (a `protected_path_editor: true` story serviced by a
#     `protected-path-editor` spawn) is mechanical in form but its subject set is the
#     sprint's story files, which this script is not given and cannot derive -- the
#     ledger names spawns, not stories. Left with the adjudicator, and said so here
#     rather than implying whole-check coverage.
#   * A `model_requested` that disagrees with `model_bound` is REPORTED and does not
#     fail. That is Check 22's own rule: the guard caught the slip and the teammate ran
#     on the key its role names.
#
# THE EFFORT ARM IS THE FIRST THING HERE THAT READS GROUND TRUTH RATHER THAN A RECORD OF
# INTENT, and that is why it is a separate arm rather than a fourth field comparison.
# Every other arm compares two things the dispatch guard wrote, or one of them against
# the config the guard read -- so a guard that bound the wrong value writes a row that
# agrees with itself. This arm reads `effort_bound`, which the guard writes from the
# DEFINITION the harness selects and leaves null on every dispatch that bound no effort,
# and joins it to the `effort` the subagent probe read off the teammate's OWN transcript
# -- the effort the API call was made at, written by the harness and not by us.
#
# IT IS THE FIELD'S ONLY READER, AND THAT IS WHY THE COMPARISON IS KEYED ON IT RATHER THAN
# ON SETTINGS. A ledger field nothing reads is a field nothing can hold correct; keying the
# comparison on the config read at GATE time instead would leave it unread and would compare
# a past dispatch against a present configuration, which are two different claims whenever a
# role is reconfigured between the spawn and the gate.
#
# --probe IS OPTIONAL AND ITS ABSENCE IS PENDING, NEVER PASS. A consumer that pulls this
# release mid-sprint has a ledger full of rows and a telemetry file whose first row is the
# next completion, exactly as PRE-LEDGER describes one level up. Failing those rows would
# wedge live work; passing them would report a verification that did not happen. The arm
# reports PENDING per row and the counts line carries the number, so "every row verified"
# and "no row could be verified" cannot read alike.
#
# AND IT REFUSES TO SCORE A RECORD OLDER THAN THE FIX THAT MADE THE FIELD MEAN ANYTHING.
# CC 2.1.259/2.1.267 fixed `effort:` on models whose launch effort is PINNED, so on such a
# model a value read off an earlier build is not evidence. The refusal is narrow by
# measurement, not by caution: it fires only where the row's model is one of the pinned
# family AND the transcript version is below 2.1.267, because on an unpinned model the
# field was already correct and refusing there would discard the whole population this
# release exists to verify.
#
# WHAT IT JUDGES, and the reason the scope is derived rather than listed. A row is in
# Rule 19 scope when it CITED a role contract, or when its role is declared in
# `aiDlcRoles`. Rows outside that -- the harness's own built-in agent types, which the
# dispatch guard's `subagent_type` fallback records with no contract and no role file --
# are counted and named in `COUNTS:` and are not judged. They are not Rule 19 dispatches:
# there is no contract for them to cite and no role file for them to resolve, so judging
# them is a false FAIL on correct data, which mechanism-design forbids.
#
# PRE-LEDGER IS ITS OWN EXIT CODE, and that is the point of writing this down. Zero
# rows and zero spawns are different states, and Check 22 was rewritten once already
# because a reader that cannot tell them apart passes vacuously on exactly the sprint
# where the mechanism was missing. Exit 3 is neither a pass nor a finding: it says the
# ledger covers nothing for this sprint and the verdict must rest on the gate log's
# lead-authored spawn table instead. The counts print on every path, including this
# one, because "found no violation" and "examined nothing" must not read alike.
#
# USAGE
#   validate-spawn-ledger.sh --ledger <spawn-ledger.jsonl> --sprint <N> --settings <settings.json>
#                            [--probe <subagent-context.jsonl>]
#
# EXIT
#   0  every row for this sprint carries a resolvable role file, a Rule 19(b) contract
#      citation, and a model matching its role's configured pin
#   1  at least one row does not, or its effort_bound disagrees with its own transcript
#      (a Rule 19 violation on any of those four routes, clearable only per Check 22's
#      four-arm disposition, which covers every one of them)
#   2  bad arguments, an unreadable settings.json, or no jq -- nothing was compared
#   3  NOTHING WAS COMPARED. Either PRE-LEDGER (the ledger names no row for this sprint)
#      or every row it does name is outside Rule 19 scope. Not a pass either way.
#
# MODE --fold-architect (Check 17's fold architecture gate)
#   validate-spawn-ledger.sh --fold-architect <s<N>/fold-architecture-<slug>.md>
#                            <s<N>/bug-fix-oneshot-<slug>.md> [--ledger <spawn-ledger.jsonl>]
#                            [--snapshot <pipeline-snapshot.md>] [--route <route.md>]
#                            [--sprint-status <sprint-status.yaml>]
#                            [--variant <pipeline_variant>]   (explicit override, for tests)
#   Decides whether an ARCHITECT dispositioned a folded bug-fix story, from a record the lead
#   does not write: the residue's `tool_use_id` must resolve to a spawn-ledger row with role
#   `architect`, the one-shot's sprint, a `ts` at or after the `ts` of the one-shot's OWN
#   adversary row (joined by the one-shot's `tool_use_id`; `invoked_at` decides nothing), and no
#   other `fold-architecture-*.md` in that `s<N>/` may cite the same id. The residue's
#   `artifact:` must name the story the one-shot names, by full path. The story itself must carry
#   the stamp, and the stamp's `tool_use_id` must EQUAL the one-shot's. Only once all of that
#   holds is the residue's own shape checked, by running the sibling
#   `validate-provenance-block.sh <residue> --require-skill bmad-review-adversarial-general` --
#   the fold gate is ONE command, and NOT-OWED and SKIP never read the residue at all.
#   The variant resolves in order: `--variant`; else the `pipeline_variant:` line of the snapshot
#   (default `_bmad-output/pipeline-snapshot.md`, fenced code blocks and HTML comments skipped);
#   else the top-level `variant:` of `sprint-status.yaml` (default
#   `_bmad-output/implementation-artifacts/sprint-status.yaml`). A snapshot that exists but
#   carries no parseable line falls through to sprint-status rather than refusing. A value from
#   the first two is cross-checked against sprint-status when that file carries one. A variant
#   whose route.md sequence runs no architecture step owes nothing (NOT-OWED, exit 0), the set
#   read from route.md's variant table (default `.claude/skills/ai-dlc/steps/route.md`), never
#   listed here. None of the three: the fold is OWED.
#   EXIT 0 PASS, NOT-OWED, or SKIP-PRE-ADOPTION (the sprint carries no `tool_use_id`, or the
#          one-shot's id joins no row of a PARTIALLY adopted sprint) -- each prints its own line
#        1 a finding, including a legacy `bug-fix-oneshot.md` where the fold is owed, a one-shot
#          id missing from a FULLY adopted sprint or resolving to a non-adversary row, an
#          unstamped or re-pointed story, and a residue failing its shape check
#        2 usage, a flag with no value, an unreadable input, an unparseable ledger, an UNKNOWN
#          variant, a snapshot/sprint-status variant disagreement, or a failed self-probe
#   The ledger defaults to `_bmad-output/spawn-ledger.jsonl`. An ABSENT ledger is exit 2, not
#   SKIP: a mistyped path must not read as a sprint that predates the ledger.
set -u

LEDGER=""
SPRINT=""
SETTINGS=""
PROBE=""
MODE="check22"
FA_RES=""
FA_ONE=""
FA_VARIANT=""
FA_ROUTE=""
FA_SNAPSHOT=""
FA_SSTATUS=""
while [ $# -gt 0 ]; do
  # No MODE_DISPATCH markers here on purpose. I49 and I53 bind the MODES of core-paths.sh
  # and validate-escalation-resolution.sh -- verbs another file names in prose and calls by
  # name. Nothing reads a marker block in THIS file, so writing one would put a marker here
  # that looks bound and is not. `--fold-architect` is the one mode; everything else is an
  # argument of Check 22's invocation.
  case "$1" in
    --fold-architect)
      [ $# -ge 3 ] || { echo "FAIL: --fold-architect takes two paths: <fold-architecture residue> <bug-fix one-shot>" >&2; exit 2; }
      MODE="fold"; FA_RES="$2"; FA_ONE="$3"; shift 3 ;;
    --variant)
      [ $# -ge 2 ] || { echo "FAIL: --variant takes a pipeline_variant name" >&2; exit 2; }
      FA_VARIANT="$2"; shift 2 ;;
    --route)
      [ $# -ge 2 ] || { echo "FAIL: --route takes the path of route.md" >&2; exit 2; }
      FA_ROUTE="$2"; shift 2 ;;
    --snapshot)
      [ $# -ge 2 ] || { echo "FAIL: --snapshot takes the path of pipeline-snapshot.md" >&2; exit 2; }
      FA_SNAPSHOT="$2"; shift 2 ;;
    --sprint-status)
      [ $# -ge 2 ] || { echo "FAIL: --sprint-status takes the path of sprint-status.yaml" >&2; exit 2; }
      FA_SSTATUS="$2"; shift 2 ;;
    # EVERY VALUE-TAKING FLAG REFUSES A MISSING VALUE. `shift 2` with one argument left fails
    # WITHOUT shifting, so a trailing `--ledger` used to leave $# at 1 and spin this loop forever.
    --ledger)
      [ $# -ge 2 ] || { echo "FAIL: --ledger takes the path of spawn-ledger.jsonl" >&2; exit 2; }
      LEDGER="$2"; shift 2 ;;
    --sprint)
      [ $# -ge 2 ] || { echo "FAIL: --sprint takes a sprint number" >&2; exit 2; }
      SPRINT="$2"; shift 2 ;;
    --settings)
      [ $# -ge 2 ] || { echo "FAIL: --settings takes the path of settings.json" >&2; exit 2; }
      SETTINGS="$2"; shift 2 ;;
    # OPTIONAL, and deliberately not promoted to a fourth required argument. Every
    # existing caller passes three; making it four would turn every one of them into the
    # exit-2 usage fault this block exists to keep distinguishable from a finding.
    --probe)
      [ $# -ge 2 ] || { echo "FAIL: --probe takes the path of subagent-context.jsonl" >&2; exit 2; }
      PROBE="$2"; shift 2 ;;
    -h|--help)  sed -n '2,62p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

# =================================================================================
# --fold-architect: CHECK 17'S FOLD ARCHITECTURE GATE, LEDGER HALF.
#
# THE DEFECT. A fix story folded into a sprint after its architecture step never reached an
# architect: the only disposition a folded `capital_path` edit got was a lead-written No-AD
# citing the sprint's stale architecture assessment. bug-investigation.md section 4 now
# dispatches ONE architect after the one-shot, and that architect writes the residue this mode
# reads. The residue is text the lead could also have written, so the residue alone proves
# nothing. What the lead does NOT write is the spawn ledger -- the dispatch guard does, at
# PreToolUse -- so the proof is a join from the residue into the ledger.
#
# EVERY CLAUSE OF THE JOIN EXCLUDES A MEASURED IMPOSTOR, and dropping any one readmits it:
#   * role `architect` -- the one-shot's own dispatch is an ADVERSARY row in the same sprint,
#     minutes earlier, and its id is the one already sitting in the one-shot's block.
#   * the one-shot's sprint -- an architect id from another sprint resolves too.
#   * `ts` at or after the one-shot's OWN ledger row -- the sprint's own architecture-step
#     dispatch is an architect row in the same sprint; it is the one that wrote the stale
#     assessment, and it precedes every fold. The anchor is the adversary row the one-shot's
#     `tool_use_id` joins, never its `invoked_at`, which the lead writes: a backdated
#     `invoked_at` once admitted the stale architect, or turned the fold into a SKIP.
#   * cited by no other `fold-architecture-*.md` in the same `s<N>/` -- one architect
#     dispatch cannot stand for two folded stories.
#   * the residue's `artifact:` equal to the one-shot's by FULL path (a leading `./` aside) --
#     a basename comparison accepts `other-dir/<same basename>`.
# WHAT IT CANNOT EXCLUDE: an UNRELATED architect dispatch later in the same sprint satisfies
# every clause, and nothing proves the residue TEXT came from the architect. This proves an
# architect was dispatched after the fold and that its id is cited once; it does not prove
# what that architect was asked.
#
# SKIP-PRE-ADOPTION, never PASS, where the ledger cannot answer. The guard began writing
# `tool_use_id` mid-history (measured on the reference consumer: absent on every row through
# S310, 17 of 78 S311 rows missing, present on all of S312 and S313). A sprint with no id at
# all SKIPs. In a PARTIALLY adopted sprint a one-shot whose own id joins no adversary row may
# have been one of the id-less dispatches, so it SKIPs too; in a FULLY adopted sprint the same
# miss is a finding, because every dispatch there was recorded with its id. That is the
# pre-migration state mechanism-design says to report rather than fail -- and reporting it
# as a pass would be the empty-ledger silence this mode exists to end.
#
# THE STORY'S STAMP MUST CARRY THE ONE-SHOT'S OWN ID. The ordering anchor is the adversary row
# the one-shot's `tool_use_id` joins, and that id is a line the lead can rewrite: re-pointing it
# at a LATER adversary row moves the anchor past any architect it likes. The stamp on the story
# (stamp-story-provenance.sh copies the one-shot's `tool_use_id` verbatim) must equal it. What
# that BUYS: an edit to the one-shot alone, without touching the story, is caught. What it does
# not: the one-shot's id can be re-pointed at any time, and a re-stamp through the shipped
# writer, or a hand-written block carrying the new id, restores agreement -- the stamp is the
# sanctioned writer, so no record here is one the lead cannot rewrite. A stated residual, not a
# closed hole. A story carrying no block citing the one-shot's skill was never stamped by it.
#
# THE RESIDUE'S SHAPE IS CHECKED HERE, AND ONLY WHERE THE FOLD IS OWED AND THE JOIN HELD. It
# used to be a separate first command at the gate, and that command read the residue for EVERY
# declared folded story -- so a `bug`-variant sprint, whose per-bug one-shot is a declared fold
# with no architecture step and so no residue, failed Check 17 on correct work. Running the
# sibling `validate-provenance-block.sh` from inside this mode puts it behind the NOT-OWED and
# SKIP decisions, which never read the residue at all.
#
# ORDER IS LOAD-BEARING: NOT-OWED (variant), then SKIP (no ids), then the legacy name, then the
# one-shot's own row, then the residue join, then the story stamp, then the residue's shape. A
# residue check first would FAIL every pre-adoption fold for lacking a residue no step asked for
# when it ran, and every bug-variant fold for lacking one no step writes.
# =================================================================================
fa_story_blocks() {  # <file> -> one "<skill>TAB<tool_use_id>" line per provenance block
  awk '
    index($0, "<!-- SKILL_INVOCATION_PROVENANCE v1") { on = 1; s = ""; t = ""; next }
    on && index($0, "SKILL_INVOCATION_PROVENANCE_END") { printf "%s\t%s\n", (s == "" ? "__NONE__" : s), (t == "" ? "__NONE__" : t); on = 0; next }
    on && index($0, "skill:") == 1 { s = substr($0, 7); sub(/^[ \t]+/, "", s); sub(/[ \t\r]+$/, "", s) }
    on && index($0, "tool_use_id:") == 1 { t = substr($0, 13); sub(/^[ \t]+/, "", t); sub(/[ \t\r]+$/, "", t) }
  ' "$1" 2>/dev/null
}

fa_sstatus_variant() {  # <sprint-status.yaml> -> the TOP-LEVEL variant value, or empty
  # Column-0 `variant:` only, the line sprint-status.sh roll writes (core/schemas/sprint-status.json
  # declares the field). An indented `variant:` belongs to a nested mapping and is not the sprint.
  awk '
    index($0, "variant:") == 1 {
      v = substr($0, 9); sub(/[ \t]+#.*$/, "", v); sub(/^[ \t]+/, "", v); sub(/[ \t\r]+$/, "", v)
      q = sprintf("%c", 39); f = substr(v, 1, 1)
      if ((f == "\"" || f == q) && length(v) >= 2 && substr(v, length(v), 1) == f) v = substr(v, 2, length(v) - 2)
      print v; exit
    }' "$1" 2>/dev/null
}

fa_field() {  # <file> <key> -> the key value in the FIRST provenance block, or empty
  awk -v k="$2" '
    index($0, "<!-- SKILL_INVOCATION_PROVENANCE v1") { on = 1; next }
    on && index($0, "SKILL_INVOCATION_PROVENANCE_END") { exit }
    on && index($0, k ":") == 1 {
      v = substr($0, length(k) + 2); sub(/^[ \t]+/, "", v); sub(/[ \t\r]+$/, "", v)
      print v; exit
    }' "$1" 2>/dev/null
}

fa_variant_arch() {  # <route.md> <variant> -> yes | no | unknown
  # Read off route.md variant table (Step 6), the one place a variant sequence is written.
  # A sequence token equal to `architecture` once brackets and emphasis are stripped is the
  # architecture step; `deep-codebase-analysis` and `codebase-inventory` are not.
  awk -v want="$2" '
    /^\| *Variant *\| *Pipeline Sequence *\|/ { t = 1; next }
    t && /^\|[- |]+\|$/ { next }
    t && !/^\|/ { exit }
    t {
      n = split($0, c, "|"); v = c[2]; gsub(/^ +| +$/, "", v)
      if (v != want) next
      s = c[3]; gsub(/[][*()]/, " ", s)
      m = split(s, w, " "); r = "no"
      for (i = 1; i <= m; i++) if (w[i] == "architecture") r = "yes"
      print r; found = 1; exit
    }
    END { if (!found) print "unknown" }' "$1" 2>/dev/null
}

fa_snapshot_variant() {  # <pipeline-snapshot.md> -> the pipeline_variant value, or empty
  # The FIRST line naming the key, once list dashes, emphasis and backticks are stripped. The
  # reference consumer's snapshot writes `- pipeline_variant: carry-over`; its history also
  # carries `- **pipeline_variant:** feature` and a backticked form. Only the first token after
  # the colon is the value, so a prose line (`not yet resolved.`) yields a token that is no row
  # of route.md's table, and that is an UNKNOWN variant -- exit 2, never NOT-OWED.
  #
  # FENCED CODE BLOCKS AND HTML COMMENTS ARE NOT THE SNAPSHOT, and the first-line rule made them
  # its answer: a quoted `pipeline_variant: bug` in a fence or a comment above the real line won,
  # measured, and turned an owed fold into NOT-OWED. A fence is a line opening with three
  # backticks or three tildes; a comment runs from its opener to its closer across lines, and the
  # text outside it on the same line is still read.
  awk '
    { raw = $0 }
    incom { p = index(raw, "-->"); if (!p) next; raw = substr(raw, p + 3); incom = 0 }
    raw ~ /^[ \t]*(```|~~~)/ { fence = !fence; next }
    fence { next }
    {
      while ((p = index(raw, "<!--")) > 0) {
        rest = substr(raw, p + 4); c = index(rest, "-->")
        if (c) raw = substr(raw, 1, p - 1) substr(rest, c + 3)
        else { raw = substr(raw, 1, p - 1); incom = 1; break }
      }
    }
    { l = raw; gsub(/[*`]/, "", l); sub(/^[ \t]*-?[ \t]*/, "", l) }
    index(l, "pipeline_variant:") == 1 {
      v = substr(l, length("pipeline_variant:") + 1); sub(/^[ \t]+/, "", v)
      split(v, w, /[ \t]+/); print w[1]; exit
    }' "$1" 2>/dev/null
}

# THE RESIDUE'S READER IS A SIBLING, RESOLVED BESIDE THIS FILE. Both land in one directory in
# both layouts -- core/scripts/ here, scripts/ai-dlc/ on a consumer -- so no walk up and no
# second subtree is involved (I33/I33b/I33c bind fixture walks into a DIFFERENT subtree; this
# is neither). Not sourced: it is run as a program, and an absent one is exit 2, never a pass.
FA_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FA_VPB="${FA_SELF_DIR}/validate-provenance-block.sh"

fa_xcheck() {  # <resolved variant> <source label> <sprint-status.yaml or empty> -> 0 agree/none, 2 disagree
  # BOTH RECORDS ARE LEAD-WRITTEN. This raises the cost of a false variant from one line to two;
  # it does not remove it. An absent file or an absent top-level `variant:` is no cross-check.
  local ssv
  [ -n "$3" ] && [ -f "$3" ] || return 0
  ssv="$(fa_sstatus_variant "$3")"
  [ -n "$ssv" ] || return 0
  [ "$ssv" = "$1" ] && return 0
  echo "FAIL: variant disagreement: snapshot says $1, sprint-status says ${ssv} (variant from $2; sprint-status from $3)." >&2
  echo "      Both are lead-written records of one sprint; reconcile them before the fold is decided." >&2
  return 2
}

fa_resolve_variant() {  # <--variant value or ""> <snapshot path> <sprint-status path> -> sets FA_RV (empty: none) and FA_RVSRC; rc 0, or 2 on disagreement
  # THE RESOLUTION ORDER: (1) `--variant`; (2) the snapshot's `pipeline_variant:` line; (3) the
  # TOP-LEVEL `variant:` of sprint-status.yaml; (4) none of the three prints nothing, and the
  # caller holds the fold OWED. A snapshot that EXISTS but yields no line falls through to (3):
  # the reference consumer's snapshot history spells the variant `- **Variant:** bug`,
  # `**Pipeline variant:**` and `- variant:` in hundreds of revisions, and an exit 2 there wedged a
  # correct gate before NOT-OWED was decided. The disagreement cross-check applies only when a
  # value came from (1) or (2) AND sprint-status carries one; a value from (3) has nothing to
  # disagree with. Whichever source won, an UNKNOWN value is still the caller's exit 2.
  local v="$1" src="--variant" ssv=""
  FA_RV=""; FA_RVSRC=""
  if [ -z "$v" ]; then
    src=""
    [ -f "$2" ] && v="$(fa_snapshot_variant "$2")"
    # A snapshot with no parseable line is not a refusal; it falls through to sprint-status.
    [ -n "$v" ] && src="$2"
  fi
  if [ -n "$v" ]; then
    fa_xcheck "$v" "$src" "$3" || return 2
  else
    [ -n "$3" ] && [ -f "$3" ] && ssv="$(fa_sstatus_variant "$3")"
    [ -n "$ssv" ] && { v="$ssv"; src="$3"; }
  fi
  FA_RV="$v"; FA_RVSRC="$src"
  return 0
}

fa_judge() {  # <residue> <one-shot> <ledger> -> 0 PASS, 1 finding, 2 refusal, 3 SKIP
  # Called only where the fold is OWED: the caller has already answered NOT-OWED for a variant
  # whose route.md sequence runs no architecture step.
  local res="$1" one="$2" led="$3" dir onebase slug sprint story rart rtui sid q tag role rs rts rte
  local nid nidless one_e one_ts hits ok why other otui onerole oskill stids vout vrc nfind=0
  [ -r "$one" ] || { echo "FAIL: cannot read the one-shot $one" >&2; return 2; }
  dir="$(dirname "$one")"; onebase="$(basename "$one")"
  sprint="$(basename "$dir")"
  case "$sprint" in s[0-9]*) sprint="${sprint#s}" ;; *) sprint="" ;; esac
  case "$sprint" in ''|*[!0-9]*) echo "FAIL: $one does not sit in an s<N>/ planning slot, so its sprint is unknown" >&2; return 2 ;; esac
  [ -f "$led" ] || { echo "FAIL: no spawn ledger at $led. An absent ledger is not a pre-adoption sprint; pass --ledger." >&2; return 2; }
  sid="$(fa_field "$one" tool_use_id)"
  rtui=""
  [ -r "$res" ] && rtui="$(fa_field "$res" tool_use_id)"

  # ORDERING IS ANCHORED ON THE LEDGER, NEVER ON `invoked_at`. The one-shot's `invoked_at` is a
  # field the lead writes, so a backdated one turned the ordering clause into SKIP or PASS at
  # will. The one-shot's OWN `tool_use_id` joins an adversary row the dispatch guard wrote, and
  # that row's `ts` is the instant every architect row is ordered against.
  q="$(jq -rs --argjson s "$sprint" --arg t "${rtui:-__NO_ID__}" --arg o "${sid:-__NO_ID__}" '
      def epoch:
        if type != "string" then null else
        ((capture("^(?<d>[0-9]{4}-[0-9]{2}-[0-9]{2})T(?<h>[0-9]{2}):(?<m>[0-9]{2})(:(?<s>[0-9]{2}))?([.][0-9]+)?(?<z>Z|[+-][0-9]{2}:?[0-9]{2})$")) // null) as $c
        | if $c == null then null else
            ((($c.d + "T" + $c.h + ":" + $c.m + ":" + ($c.s // "00") + "Z") | fromdateiso8601)
             - (if $c.z == "Z" then 0 else
                  ($c.z | gsub(":"; "") | (if startswith("-") then -1 else 1 end)
                        * ((.[1:3] | tonumber) * 3600 + (.[3:5] | tonumber) * 60)) end))
          end end;
      def hasid: ((.tool_use_id // "") | type == "string" and length > 0);
      [ .[] | select(type == "object") ] as $all
      | [ $all[] | select((.sprint // null) == $s) ] as $sp
      | [ $sp[] | select((.tool_use_id // "") == $o and (.role // "") == "adversary")
          | {e: (.ts | epoch), ts: .ts} | select(.e != null) ] as $one
      | "NID\t\([ $sp[] | select(hasid) ] | length)",
        "NIDLESS\t\([ $sp[] | select(hasid | not) ] | length)",
        "ONE\t\(($one | map(.e) | max) // "__NONE__")\t\(($one | max_by(.e) | .ts) // "__NONE__")",
        ($all[] | select((.tool_use_id // "") == $o and (.role // "") != "adversary")
         | "ONEROLE\t\(.role // "__NONE__")\t\(.sprint // "__NONE__")"),
        ($all[] | select((.tool_use_id // "") == $t)
         | "HIT\t\(.role // "__NONE__")\t\(.sprint // "__NONE__")\t\(.ts // "__NONE__")\t\((.ts | epoch) // "__NONE__")")
    ' "$led" 2>/dev/null)" || {
    echo "FAIL: $led is not parseable as JSONL, so no dispatch can be joined against it." >&2
    return 2
  }
  nid="$(printf '%s\n' "$q" | awk -F'\t' '$1 == "NID" { print $2; exit }')"
  nidless="$(printf '%s\n' "$q" | awk -F'\t' '$1 == "NIDLESS" { print $2; exit }')"
  one_e="$(printf '%s\n' "$q" | awk -F'\t' '$1 == "ONE" { print $2; exit }')"
  one_ts="$(printf '%s\n' "$q" | awk -F'\t' '$1 == "ONE" { print $3; exit }')"

  if [ "${nid:-0}" -eq 0 ]; then
    echo "SKIP-PRE-ADOPTION: the ledger carries no tool_use_id on any S${sprint} row, so no"
    echo "  architect dispatch for $onebase can be joined. Not a pass: nothing was compared."
    return 3
  fi

  # THE LEGACY NAME IS NOT AN OPT-OUT where the fold is owed. It declared no folded story when
  # the per-bug name did not exist; in a sprint whose ledger can answer, renaming the one-shot
  # to the legacy name would otherwise make every fold vanish from this gate.
  if [ "$onebase" = "bug-fix-oneshot.md" ]; then
    echo "FAIL: legacy one-shot name in an architecture variant — rename to bug-fix-oneshot-<slug>.md" >&2
    echo "      ($one, S${sprint}). Only the bug variant, which runs no architecture step, owes no" >&2
    echo "      fold architect; this sprint's variant does or could not be resolved." >&2
    return 1
  fi
  case "$onebase" in
    bug-fix-oneshot-*.md) slug="${onebase#bug-fix-oneshot-}"; slug="${slug%.md}" ;;
    *) echo "FAIL: $onebase is not a per-bug one-shot (bug-fix-oneshot-<slug>.md). Only the per-bug name declares a folded story (Check 17), so nothing here is owed a fold architect." >&2; return 2 ;;
  esac
  [ -n "$slug" ] || { echo "FAIL: $onebase carries an empty slug" >&2; return 2; }
  story="$(fa_field "$one" artifact)"
  [ -n "$story" ] || { echo "FAIL: $one names no artifact:, so it declares no folded story" >&2; return 2; }
  case "$(basename "$res")" in
    "fold-architecture-${slug}.md") : ;;
    *) echo "FAIL: residue $(basename "$res") does not pair with $onebase -- expected fold-architecture-${slug}.md" >&2; return 2 ;;
  esac

  # THE ONE-SHOT'S ID NAMES A DISPATCH, AND IT IS THE WRONG KIND. An id the ledger DOES carry, on a
  # row whose role is not adversary, is not one of the id-less dispatches a partially adopted
  # sprint may hide -- it was recorded, and it is some other teammate. Pointing the one-shot at the
  # sprint's architecture-step architect would otherwise read as "id not in the ledger" in a fully
  # adopted sprint and as SKIP in a partial one, and neither message says what happened.
  onerole="$(printf '%s\n' "$q" | awk -F'\t' '$1 == "ONEROLE" { printf "%s%s (S%s)", sep, $2, $3; sep = ", " }')"
  if [ "${one_e:-__NONE__}" = "__NONE__" ] && [ -n "$onerole" ]; then
    echo "FAIL: one-shot id not in the ledger as an adversary dispatch -- $onebase cites tool_use_id" >&2
    echo "      '${sid}', which the ledger records as role ${onerole}, not adversary. The one-shot is" >&2
    echo "      the adversary's review; an id that resolves to another role is not its dispatch." >&2
    return 1
  fi

  if [ "${one_e:-__NONE__}" = "__NONE__" ]; then
    if [ "${nidless:-0}" -gt 0 ]; then
      echo "SKIP-PRE-ADOPTION: $onebase cites tool_use_id '${sid}', which joins no adversary row in"
      echo "  S${sprint}, and S${sprint} is PARTIALLY adopted (${nidless} of its rows carry no tool_use_id),"
      echo "  so its own dispatch may be one of those. Not a pass: nothing was compared."
      return 3
    fi
    echo "FAIL: one-shot id not in the ledger -- $onebase cites tool_use_id '${sid}', and no adversary" >&2
    echo "      row of S${sprint} carries it, while every S${sprint} row carries an id. Nothing orders an" >&2
    echo "      architect dispatch against a one-shot the dispatch guard never recorded." >&2
    return 1
  fi

  if [ ! -f "$res" ]; then
    echo "FAIL: no residue $res. The folded story $story was never dispositioned by an" >&2
    echo "      architect: bug-investigation.md section 4 dispatches ONE architect after the" >&2
    echo "      one-shot, and that architect writes this file. A lead-written No-AD is not it." >&2
    return 1
  fi
  # The FULL path as written, normalised for a leading `./` only. A basename comparison accepts
  # a residue over `other-dir/<same basename>`, which is a different story.
  rart="$(fa_field "$res" artifact)"
  if [ "${rart#./}" != "${story#./}" ]; then
    echo "FAIL: residue artifact: '${rart}' is not the story the one-shot names ('${story}')." >&2
    nfind=$((nfind + 1))
  fi
  case "$rtui" in
    ''|NOT_ACCESSIBLE)
      echo "FAIL: residue carries no joinable tool_use_id ('${rtui}'). The architect dispatch id" >&2
      echo "      is the whole of what proves an architect ran; recover it from the transcript." >&2
      return 1 ;;
  esac
  hits="$(printf '%s\n' "$q" | awk -F'\t' '$1 == "HIT"')"
  if [ -z "$hits" ]; then
    echo "FAIL: residue tool_use_id ${rtui} resolves to NO spawn-ledger row. Nothing the dispatch" >&2
    echo "      guard recorded says an architect was dispatched for this fold." >&2
    return 1
  fi
  ok=0; why=""
  while IFS="$(printf '\t')" read -r tag role rs rts rte; do
    [ "$tag" = "HIT" ] || continue
    if [ "$role" != "architect" ]; then why="${why}role '${role}' is not architect; "; continue; fi
    if [ "$rs" != "$sprint" ]; then why="${why}sprint ${rs} is not S${sprint}; "; continue; fi
    if [ "$rte" = "__NONE__" ] || awk -v a="$rte" -v b="$one_e" 'BEGIN { exit !(a + 0 < b + 0) }'; then
      why="${why}dispatched at ${rts}, before the one-shot ran (its own ledger row, ${one_ts}); "; continue
    fi
    ok=1
  done <<EOF
$hits
EOF
  if [ "$ok" -ne 1 ]; then
    echo "FAIL: residue tool_use_id ${rtui} joins no architect dispatch made in S${sprint} at or" >&2
    echo "      after the one-shot: ${why% }" >&2
    nfind=$((nfind + 1))
  fi
  for other in "$dir"/fold-architecture-*.md; do
    [ -f "$other" ] || continue
    [ "$(basename "$other")" = "$(basename "$res")" ] && continue
    otui="$(fa_field "$other" tool_use_id)"
    if [ "$otui" = "$rtui" ]; then
      echo "FAIL: $(basename "$other") cites the same architect dispatch ${rtui}. One dispatch" >&2
      echo "      cannot disposition two folded stories." >&2
      nfind=$((nfind + 1))
    fi
  done
  [ "$nfind" -eq 0 ] || return 1

  # THE STORY'S STAMP, keyed on the one-shot's own skill so a convergence block the story may
  # also carry is not read as the stamp. See the header: equality catches an edit to the one-shot
  # alone; a re-stamp, or a hand-written block carrying the new id, restores agreement.
  oskill="$(fa_field "$one" skill)"; [ -n "$oskill" ] || oskill="bmad-review-adversarial-general"
  [ -f "$story" ] || { echo "FAIL: story not stamped -- the one-shot's artifact: ${story} does not exist, so no stamp can be read." >&2; return 1; }
  [ -r "$story" ] || { echo "FAIL: cannot read the story ${story}" >&2; return 2; }
  stids="$(fa_story_blocks "$story" | awk -F'\t' -v k="$oskill" '$1 == k { print $2 }')"
  if [ -z "$stids" ]; then
    echo "FAIL: story not stamped -- ${story} carries no provenance block citing ${oskill}, so" >&2
    echo "      stamp-story-provenance.sh --profile bug-story-provenance never ran on it from ${onebase}." >&2
    return 1
  fi
  if ! grep -qxF -- "$sid" <<<"$stids"; then
    echo "FAIL: one-shot re-pointed after the story was stamped -- ${onebase} cites tool_use_id" >&2
    echo "      '${sid}', and the stamp on ${story} carries '$(printf '%s' "$stids" | tr '\n' ' ' | sed 's/ $//')'." >&2
    echo "      The stamp copies the one-shot's id verbatim, so they differ only if one moved." >&2
    return 1
  fi

  # THE RESIDUE'S SHAPE, by the reader that owns it, and only here: owed, joined, stamped.
  [ -r "$FA_VPB" ] || { echo "FAIL: the sibling validate-provenance-block.sh is not at ${FA_VPB}, so the residue's shape cannot be checked." >&2; return 2; }
  vout="$(bash "$FA_VPB" "$res" --require-skill bmad-review-adversarial-general 2>&1)"; vrc=$?
  if [ "$vrc" -ne 0 ]; then
    echo "FAIL: residue $(basename "$res") fails its shape check (validate-provenance-block.sh rc=${vrc}):" >&2
    printf '%s\n' "$vout" >&2
    [ "$vrc" -eq 1 ] && return 1
    return 2
  fi
  echo "PASS: ${onebase} -> $(basename "$res"): architect dispatch ${rtui} in S${sprint}, at or"
  echo "  after the one-shot's own dispatch (${one_ts}), cited by no other fold residue, over story ${story},"
  echo "  whose stamp carries the one-shot's id; the residue's block passes validate-provenance-block.sh."
  return 0
}

# --- SELF-PROBE, BEFORE THE REAL INPUT, IN BOTH DIRECTIONS ------------------------------
# The same fa_judge the real run uses, on a mktemp world. Each clause has an offender and a
# near-miss: ordering (architect before / after the one-shot's LEDGER row, and a backdated
# invoked_at that must neither SKIP nor rescue the early architect), adoption (no ids SKIP; a
# one-shot id missing from a PARTIALLY adopted sprint SKIPs; from a FULLY adopted one FAILs), the
# legacy name (owed -> FAIL; pre-adoption -> SKIP first), the artifact path (same basename in
# another directory FAILs; a leading `./` does not), role, uniqueness, and the two readers of
# the variant. Every SKIP asserts its FIRST LINE and that no line starts `PASS`, because SKIP
# and PASS share exit 0 at the caller. Round v3.3 adds: the one-shot's id resolving to an
# ARCHITECT row (FAIL naming the role, in a fully AND a partially adopted sprint -- never SKIP),
# the story stamp (absent -> FAIL; carrying another id -> FAIL; equal -> the passing world),
# the residue's shape through the sibling reader (wrong skill -> FAIL), the fence- and
# comment-blind snapshot reader, the sprint-status reader, and the variant cross-check.
fa_probe_block() {  # <file> <invoked_at> <tool_use_id> <artifact>
  printf '%s\n' '<!-- SKILL_INVOCATION_PROVENANCE v1' 'skill: bmad-review-adversarial-general' \
    "invoked_at: $2" "tool_use_id: $3" 'mode: subagent' \
    "artifact: $4" 'SKILL_INVOCATION_PROVENANCE_END -->' > "$1"
}
fa_probe_res() {  # <file> <tool_use_id> <artifact> [skill] -- every field the reader requires
  printf '%s\n' '# Fold architecture disposition' '' '- **No-AD:** CAP-1 -- REASON: probe.' '' \
    '<!-- SKILL_INVOCATION_PROVENANCE v1' "skill: ${4:-bmad-review-adversarial-general}" \
    'invoked_at: 2000-01-02T11:00:05Z' "tool_use_id: $2" 'mode: subagent' \
    'lead_role: bug-investigation.md' "artifact: $3" \
    'findings_critical: 0' 'findings_major: 0' 'findings_minor: 0' \
    'SKILL_INVOCATION_PROVENANCE_END -->' > "$1"
}
fa_probe_rc() {  # <expected rc> <message substring or ""> <label> <residue> <one-shot> <ledger>
  local out rc
  out="$(fa_judge "$4" "$5" "$6" 2>&1)"; rc=$?
  if [ "$rc" -ne "$1" ]; then
    echo "FAIL: fold-architect self-probe: $3 (rc=$rc, expected $1)." >&2; return 1
  fi
  if [ -n "$2" ] && ! grep -qF -- "$2" <<<"$out"; then
    echo "FAIL: fold-architect self-probe: $3 -- rc=$rc as expected, but not for the reason '$2'." >&2; return 1
  fi
  return 0
}
fa_probe_skip() {  # <label> <residue> <one-shot> <ledger> -> 0 when rc 3, first line SKIP, no PASS
  local out rc first
  out="$(fa_judge "$2" "$3" "$4" 2>&1)"; rc=$?
  first="$(sed -n 1p <<<"$out")"
  case "$first" in SKIP-PRE-ADOPTION:*) : ;; *) rc=99 ;; esac
  grep -q '^PASS' <<<"$out" && rc=98
  [ "$rc" -eq 3 ] || { echo "FAIL: fold-architect self-probe: $1 did not SKIP cleanly (rc=$rc, first='$first'); an unanswerable ledger must never read as a pass." >&2; return 1; }
  return 0
}
fa_self_probe() {
  local pd rc bad=0 side sides d S
  pd="$(mktemp -d 2>/dev/null)" || return 1
  [ -n "$pd" ] && [ -d "$pd" ] || return 1
  sides="pos neg role dup pre back backok part full leg legpre art artdot oid oidpart unst repoint shape"
  for side in $sides; do mkdir -p "$pd/$side/s900" "$pd/$side/s901" "$pd/$side/s902" || return 1; done
  mkdir -p "$pd/stories" || return 1
  cat > "$pd/ledger.jsonl" <<'JSONL'
{"v":1,"ts":"2000-01-01T00:00:00Z","sprint":900,"name":"dev","role":"dev","tool_use_id":"toolu_probeepoch0"}
{"v":1,"ts":"2000-01-02T09:00:00Z","sprint":900,"name":"architect","role":"architect","tool_use_id":"toolu_probeearly0"}
{"v":1,"ts":"2000-01-02T10:00:00Z","sprint":900,"name":"adversary","role":"adversary","tool_use_id":"toolu_probeoneshot"}
{"v":1,"ts":"2000-01-02T10:30:00Z","sprint":900,"name":"adversary","role":"adversary","tool_use_id":"toolu_probeadvmid"}
{"v":1,"ts":"2000-01-02T11:00:00Z","sprint":900,"name":"architect","role":"architect","tool_use_id":"toolu_probelate0"}
{"v":1,"ts":"2000-01-02T11:30:00Z","sprint":900,"name":"adversary","role":"adversary","tool_use_id":"toolu_probeadvlate"}
{"v":1,"ts":"2000-01-02T11:00:00Z","sprint":901,"name":"architect","role":"architect"}
{"v":1,"ts":"2000-01-03T08:00:00Z","sprint":902,"name":"adversary","role":"adversary"}
{"v":1,"ts":"2000-01-03T11:00:00Z","sprint":902,"name":"architect","role":"architect","tool_use_id":"toolu_probe902arch"}
JSONL
  # The story is named by an ABSOLUTE path so the probe reads it from any cwd; the stamp carries
  # the one-shot's id, as stamp-story-provenance.sh writes it. `unst` names a story with no block.
  S="$pd/stories/probe.md"; SU="$pd/stories/unstamped.md"
  printf '%s\n' '# Story probe' '' 'Status: ready-for-dev' '' '<!-- SKILL_INVOCATION_PROVENANCE v1' \
    'skill: bmad-review-adversarial-general' 'invoked_at: 2000-01-02T10:00:05Z' \
    'tool_use_id: toolu_probeoneshot' 'mode: subagent' "artifact: $S" \
    'SKILL_INVOCATION_PROVENANCE_END -->' > "$S"
  printf '%s\n' '# Story unstamped' '' 'Status: ready-for-dev' > "$SU"
  # The one-shot's invoked_at is written 5s AFTER its ledger row everywhere but `back`/`backok`,
  # where it is backdated a year -- before every row of the sprint, which is what the old
  # invoked_at ordering read as SKIP.
  for side in pos neg role dup shape; do fa_probe_block "$pd/$side/s900/bug-fix-oneshot-p.md" 2000-01-02T10:00:05Z toolu_probeoneshot "$S"; done
  fa_probe_block "$pd/oid/s900/bug-fix-oneshot-p.md" 2000-01-02T10:00:05Z toolu_probeearly0 "$S"
  fa_probe_block "$pd/oidpart/s902/bug-fix-oneshot-p.md" 2000-01-03T08:00:05Z toolu_probe902arch "$S"
  fa_probe_block "$pd/unst/s900/bug-fix-oneshot-p.md" 2000-01-02T10:00:05Z toolu_probeoneshot "$SU"
  fa_probe_block "$pd/repoint/s900/bug-fix-oneshot-p.md" 2000-01-02T10:30:05Z toolu_probeadvmid "$S"
  fa_probe_block "$pd/pre/s901/bug-fix-oneshot-p.md" 2000-01-02T10:00:05Z toolu_probeoneshot "$S"
  fa_probe_block "$pd/back/s900/bug-fix-oneshot-p.md" 1999-01-01T00:00:00Z toolu_probeoneshot "$S"
  fa_probe_block "$pd/backok/s900/bug-fix-oneshot-p.md" 1999-01-01T00:00:00Z toolu_probeoneshot "$S"
  fa_probe_block "$pd/part/s902/bug-fix-oneshot-p.md" 2000-01-03T08:00:05Z toolu_probe902absent "$S"
  fa_probe_block "$pd/full/s900/bug-fix-oneshot-p.md" 2000-01-02T10:00:05Z toolu_probe900absent "$S"
  fa_probe_block "$pd/leg/s900/bug-fix-oneshot.md" 2000-01-02T10:00:05Z toolu_probeoneshot "$S"
  fa_probe_block "$pd/legpre/s901/bug-fix-oneshot.md" 2000-01-02T10:00:05Z toolu_probeoneshot "$S"
  fa_probe_block "$pd/art/s900/bug-fix-oneshot-p.md" 2000-01-02T10:00:05Z toolu_probeoneshot "$S"
  fa_probe_block "$pd/artdot/s900/bug-fix-oneshot-p.md" 2000-01-02T10:00:05Z toolu_probeoneshot "$S"
  fa_probe_res "$pd/pos/s900/fold-architecture-p.md" toolu_probelate0 "$S"
  fa_probe_res "$pd/neg/s900/fold-architecture-p.md" toolu_probeearly0 "$S"
  fa_probe_res "$pd/pre/s901/fold-architecture-p.md" toolu_probelate0 "$S"
  fa_probe_res "$pd/role/s900/fold-architecture-p.md" toolu_probeadvlate "$S"
  fa_probe_res "$pd/dup/s900/fold-architecture-p.md" toolu_probelate0 "$S"
  fa_probe_res "$pd/dup/s900/fold-architecture-q.md" toolu_probelate0 "$S"
  fa_probe_res "$pd/back/s900/fold-architecture-p.md" toolu_probeearly0 "$S"
  fa_probe_res "$pd/backok/s900/fold-architecture-p.md" toolu_probelate0 "$S"
  fa_probe_res "$pd/part/s902/fold-architecture-p.md" toolu_probe902arch "$S"
  fa_probe_res "$pd/full/s900/fold-architecture-p.md" toolu_probelate0 "$S"
  fa_probe_res "$pd/art/s900/fold-architecture-p.md" toolu_probelate0 "other-dir/probe.md"
  fa_probe_res "$pd/artdot/s900/fold-architecture-p.md" toolu_probelate0 "./$S"
  fa_probe_res "$pd/oid/s900/fold-architecture-p.md" toolu_probelate0 "$S"
  fa_probe_res "$pd/oidpart/s902/fold-architecture-p.md" toolu_probe902arch "$S"
  fa_probe_res "$pd/unst/s900/fold-architecture-p.md" toolu_probelate0 "$SU"
  fa_probe_res "$pd/repoint/s900/fold-architecture-p.md" toolu_probelate0 "$S"
  fa_probe_res "$pd/shape/s900/fold-architecture-p.md" toolu_probelate0 "$S" ai-dlc-adversary-review
  printf '%s\n' '| Variant | Pipeline Sequence | First Step |' '|---|---|---|' \
    '| arch-v | requirements → architecture → stories-test-strategy | `r.md` |' \
    '| plain-v | bug-investigation → implementation | `b.md` |' '' > "$pd/route.md"
  printf '%s\n' '# Pipeline Snapshot' '' '## Pipeline Position' '- pipeline_variant: carry-over' \
    '- current_step_file: retro.md -- mentions pipeline_variant: feature later' > "$pd/snap-plain.md"
  printf '%s\n' '# Pipeline Snapshot' '- **`pipeline_variant`:** `feature`' > "$pd/snap-bold.md"
  printf '%s\n' '# Pipeline Snapshot' '- current_step_file: retro.md' > "$pd/snap-none.md"
  printf '%s\n' '# Pipeline Snapshot' '' '## Pipeline Position' '- **Variant:** bug' > "$pd/snap-legacy.md"
  # Decoys ABOVE the real line: a fenced one, a one-line comment, a multi-line comment, and a
  # comment closed mid-line with the real key after it (read, because it is outside the comment).
  printf '%s\n' '# Pipeline Snapshot' '```yaml' '- pipeline_variant: bug' '```' \
    '<!-- - pipeline_variant: bug -->' '<!-- example:' '- pipeline_variant: bug' '-->' \
    '- pipeline_variant: carry-over' > "$pd/snap-decoy.md"
  printf '%s\n' '# Pipeline Snapshot' '~~~' 'pipeline_variant: bug' '~~~' \
    '<!-- note --> - pipeline_variant: feature' > "$pd/snap-tail.md"
  printf '%s\n' 'sprint: 900' 'stories:' '  s1:' '    variant: bug' 'variant: carry-over  # routed' \
    'status: in_progress' > "$pd/ss-plain.yaml"
  printf '%s\n' 'sprint: 900' "variant: 'bug'" > "$pd/ss-quoted.yaml"
  printf '%s\n' 'sprint: 900' 'stories:' '  s1:' '    variant: bug' > "$pd/ss-none.yaml"

  fa_judge "$pd/pos/s900/fold-architecture-p.md" "$pd/pos/s900/bug-fix-oneshot-p.md" "$pd/ledger.jsonl" >/dev/null 2>&1; rc=$?
  [ "$rc" -eq 0 ] || { echo "FAIL: fold-architect self-probe: an architect row AFTER the one-shot's ledger row was not accepted (rc=$rc)." >&2; bad=1; }
  fa_judge "$pd/neg/s900/fold-architecture-p.md" "$pd/neg/s900/bug-fix-oneshot-p.md" "$pd/ledger.jsonl" >/dev/null 2>&1; rc=$?
  [ "$rc" -eq 1 ] || { echo "FAIL: fold-architect self-probe: an architect row BEFORE the one-shot was not reported (rc=$rc), so the ordering clause cannot fire." >&2; bad=1; }
  fa_judge "$pd/back/s900/fold-architecture-p.md" "$pd/back/s900/bug-fix-oneshot-p.md" "$pd/ledger.jsonl" >/dev/null 2>&1; rc=$?
  [ "$rc" -eq 1 ] || { echo "FAIL: fold-architect self-probe: a BACKDATED invoked_at citing the stale architect did not FAIL (rc=$rc); invoked_at is deciding the ordering." >&2; bad=1; }
  fa_judge "$pd/backok/s900/fold-architecture-p.md" "$pd/backok/s900/bug-fix-oneshot-p.md" "$pd/ledger.jsonl" >/dev/null 2>&1; rc=$?
  [ "$rc" -eq 0 ] || { echo "FAIL: fold-architect self-probe: a backdated invoked_at with a later architect did not PASS (rc=$rc); invoked_at must decide nothing, SKIP included." >&2; bad=1; }
  fa_judge "$pd/role/s900/fold-architecture-p.md" "$pd/role/s900/bug-fix-oneshot-p.md" "$pd/ledger.jsonl" >/dev/null 2>&1; rc=$?
  [ "$rc" -eq 1 ] || { echo "FAIL: fold-architect self-probe: a residue citing an ADVERSARY dispatch was not reported (rc=$rc), so the role clause cannot fire." >&2; bad=1; }
  fa_judge "$pd/dup/s900/fold-architecture-p.md" "$pd/dup/s900/bug-fix-oneshot-p.md" "$pd/ledger.jsonl" >/dev/null 2>&1; rc=$?
  [ "$rc" -eq 1 ] || { echo "FAIL: fold-architect self-probe: two residues citing one architect dispatch were not reported (rc=$rc), so the uniqueness clause cannot fire." >&2; bad=1; }
  # The SKIP assertion must itself be able to fire: on the PASSING world it must refuse.
  if fa_probe_skip "the passing world" "$pd/pos/s900/fold-architecture-p.md" "$pd/pos/s900/bug-fix-oneshot-p.md" "$pd/ledger.jsonl" 2>/dev/null; then
    echo "FAIL: fold-architect self-probe: the SKIP assertion accepted a PASS, so it cannot tell SKIP from PASS." >&2; bad=1
  fi
  fa_probe_skip "a sprint with no tool_use_id" "$pd/pre/s901/fold-architecture-p.md" "$pd/pre/s901/bug-fix-oneshot-p.md" "$pd/ledger.jsonl" || bad=1
  fa_probe_skip "a one-shot id absent from a PARTIALLY adopted sprint" "$pd/part/s902/fold-architecture-p.md" "$pd/part/s902/bug-fix-oneshot-p.md" "$pd/ledger.jsonl" || bad=1
  fa_judge "$pd/full/s900/fold-architecture-p.md" "$pd/full/s900/bug-fix-oneshot-p.md" "$pd/ledger.jsonl" >/dev/null 2>&1; rc=$?
  [ "$rc" -eq 1 ] || { echo "FAIL: fold-architect self-probe: a one-shot id absent from a FULLY adopted sprint did not FAIL (rc=$rc)." >&2; bad=1; }
  fa_judge "$pd/leg/s900/fold-architecture-p.md" "$pd/leg/s900/bug-fix-oneshot.md" "$pd/ledger.jsonl" >/dev/null 2>&1; rc=$?
  [ "$rc" -eq 1 ] || { echo "FAIL: fold-architect self-probe: a legacy one-shot name where the fold is owed did not FAIL (rc=$rc); the legacy name is an opt-out." >&2; bad=1; }
  fa_probe_skip "a legacy one-shot name in a sprint with no tool_use_id" "$pd/legpre/s901/fold-architecture-p.md" "$pd/legpre/s901/bug-fix-oneshot.md" "$pd/ledger.jsonl" || bad=1
  fa_judge "$pd/art/s900/fold-architecture-p.md" "$pd/art/s900/bug-fix-oneshot-p.md" "$pd/ledger.jsonl" >/dev/null 2>&1; rc=$?
  [ "$rc" -eq 1 ] || { echo "FAIL: fold-architect self-probe: a residue over other-dir/<same basename> was not reported (rc=$rc); the artifact is compared by basename." >&2; bad=1; }
  fa_judge "$pd/artdot/s900/fold-architecture-p.md" "$pd/artdot/s900/bug-fix-oneshot-p.md" "$pd/ledger.jsonl" >/dev/null 2>&1; rc=$?
  [ "$rc" -eq 0 ] || { echo "FAIL: fold-architect self-probe: a residue artifact differing only by a leading ./ was not accepted (rc=$rc)." >&2; bad=1; }
  [ "$(fa_variant_arch "$pd/route.md" arch-v)" = yes ] || { echo "FAIL: fold-architect self-probe: a variant running architecture read as not running it." >&2; bad=1; }
  [ "$(fa_variant_arch "$pd/route.md" plain-v)" = no ] || { echo "FAIL: fold-architect self-probe: a variant with no architecture step read as running one." >&2; bad=1; }
  [ "$(fa_variant_arch "$pd/route.md" nope-v)" = unknown ] || { echo "FAIL: fold-architect self-probe: a variant absent from the table did not read as unknown." >&2; bad=1; }
  [ "$(fa_snapshot_variant "$pd/snap-plain.md")" = carry-over ] || { echo "FAIL: fold-architect self-probe: the snapshot reader missed '- pipeline_variant: carry-over'." >&2; bad=1; }
  [ "$(fa_snapshot_variant "$pd/snap-bold.md")" = feature ] || { echo "FAIL: fold-architect self-probe: the snapshot reader missed the emphasised, backticked form." >&2; bad=1; }
  [ -z "$(fa_snapshot_variant "$pd/snap-none.md")" ] || { echo "FAIL: fold-architect self-probe: the snapshot reader invented a variant from a snapshot naming none." >&2; bad=1; }
  [ "$(fa_snapshot_variant "$pd/snap-decoy.md")" = carry-over ] || { echo "FAIL: fold-architect self-probe: a pipeline_variant quoted in a fence or an HTML comment above the real line won." >&2; bad=1; }
  [ "$(fa_snapshot_variant "$pd/snap-tail.md")" = feature ] || { echo "FAIL: fold-architect self-probe: the snapshot reader lost the text after a comment closed mid-line, or read a ~~~ fence." >&2; bad=1; }
  [ "$(fa_sstatus_variant "$pd/ss-plain.yaml")" = carry-over ] || { echo "FAIL: fold-architect self-probe: the sprint-status reader missed a top-level variant (or read a nested one)." >&2; bad=1; }
  [ "$(fa_sstatus_variant "$pd/ss-quoted.yaml")" = bug ] || { echo "FAIL: fold-architect self-probe: the sprint-status reader kept the quotes of a quoted variant." >&2; bad=1; }
  [ -z "$(fa_sstatus_variant "$pd/ss-none.yaml")" ] || { echo "FAIL: fold-architect self-probe: the sprint-status reader took a NESTED variant for the sprint's." >&2; bad=1; }
  fa_xcheck carry-over probe "$pd/ss-plain.yaml" 2>/dev/null || { echo "FAIL: fold-architect self-probe: agreeing snapshot and sprint-status variants were refused." >&2; bad=1; }
  fa_xcheck feature probe "$pd/ss-plain.yaml" 2>/dev/null; rc=$?
  [ "$rc" -eq 2 ] || { echo "FAIL: fold-architect self-probe: a snapshot/sprint-status variant disagreement was not refused (rc=$rc)." >&2; bad=1; }
  fa_xcheck feature probe "$pd/ss-none.yaml" 2>/dev/null || { echo "FAIL: fold-architect self-probe: a sprint-status with no top-level variant was cross-checked." >&2; bad=1; }
  fa_xcheck feature probe "$pd/ss-absent.yaml" 2>/dev/null || { echo "FAIL: fold-architect self-probe: an absent sprint-status was cross-checked." >&2; bad=1; }
  # The resolution order. A snapshot that exists but carries only the legacy `- **Variant:** bug`
  # spelling falls through to sprint-status (offender side: the old exit 2); with no sprint-status
  # it resolves to nothing, which the caller holds OWED (near-miss: never NOT-OWED by default).
  fa_resolve_variant "" "$pd/snap-legacy.md" "$pd/ss-quoted.yaml" 2>/dev/null; rc=$?
  [ "$rc" -eq 0 ] && [ "$FA_RV" = bug ] && [ "$FA_RVSRC" = "$pd/ss-quoted.yaml" ] \
    || { echo "FAIL: fold-architect self-probe: a snapshot with no pipeline_variant line did not fall through to sprint-status (rc=$rc, variant='$FA_RV')." >&2; bad=1; }
  fa_resolve_variant "" "$pd/snap-legacy.md" "$pd/ss-none.yaml" 2>/dev/null; rc=$?
  [ "$rc" -eq 0 ] && [ -z "$FA_RV" ] \
    || { echo "FAIL: fold-architect self-probe: no variant in any record resolved to '$FA_RV' (rc=$rc); it must resolve to none, the fold OWED." >&2; bad=1; }
  fa_resolve_variant "" "$pd/snap-plain.md" "$pd/ss-plain.yaml" 2>/dev/null; rc=$?
  [ "$rc" -eq 0 ] && [ "$FA_RV" = carry-over ] && [ "$FA_RVSRC" = "$pd/snap-plain.md" ] \
    || { echo "FAIL: fold-architect self-probe: an agreeing snapshot did not win over sprint-status (rc=$rc, source='$FA_RVSRC')." >&2; bad=1; }
  fa_resolve_variant "" "$pd/snap-plain.md" "$pd/ss-quoted.yaml" 2>/dev/null; rc=$?
  [ "$rc" -eq 2 ] || { echo "FAIL: fold-architect self-probe: a snapshot/sprint-status disagreement was resolved rather than refused (rc=$rc)." >&2; bad=1; }
  # The one-shot's id on an ARCHITECT row: a finding naming the role, fully AND partially adopted.
  fa_probe_rc 1 "as role architect" "a one-shot id resolving to an architect row in a FULLY adopted sprint did not FAIL naming the role" \
    "$pd/oid/s900/fold-architecture-p.md" "$pd/oid/s900/bug-fix-oneshot-p.md" "$pd/ledger.jsonl" || bad=1
  fa_probe_rc 1 "as role architect" "a one-shot id resolving to an architect row in a PARTIALLY adopted sprint did not FAIL naming the role (it must never SKIP)" \
    "$pd/oidpart/s902/fold-architecture-p.md" "$pd/oidpart/s902/bug-fix-oneshot-p.md" "$pd/ledger.jsonl" || bad=1
  # The story stamp: absent -> FAIL; re-pointed one-shot -> FAIL; the passing world is the near-miss.
  fa_probe_rc 1 "story not stamped" "a story carrying no stamp was not reported" \
    "$pd/unst/s900/fold-architecture-p.md" "$pd/unst/s900/bug-fix-oneshot-p.md" "$pd/ledger.jsonl" || bad=1
  fa_probe_rc 1 "one-shot re-pointed after the story was stamped" "a one-shot whose id differs from the stamp was not reported" \
    "$pd/repoint/s900/fold-architecture-p.md" "$pd/repoint/s900/bug-fix-oneshot-p.md" "$pd/ledger.jsonl" || bad=1
  # The residue's shape, through the sibling reader: the passing world differs by the skill only.
  fa_probe_rc 1 "fails its shape check" "a residue citing the wrong skill passed the shape check" \
    "$pd/shape/s900/fold-architecture-p.md" "$pd/shape/s900/bug-fix-oneshot-p.md" "$pd/ledger.jsonl" || bad=1
  fa_probe_rc 0 "whose stamp carries the one-shot's id" "the passing world did not PASS through the stamp and shape clauses" \
    "$pd/pos/s900/fold-architecture-p.md" "$pd/pos/s900/bug-fix-oneshot-p.md" "$pd/ledger.jsonl" || bad=1

  for side in $sides; do
    for d in s900 s901 s902; do rm -f "$pd/$side/$d"/*.md 2>/dev/null; rmdir "$pd/$side/$d" 2>/dev/null; done
    rmdir "$pd/$side" 2>/dev/null
  done
  rm -f "$pd/ledger.jsonl" "$pd/route.md" "$pd/snap-plain.md" "$pd/snap-bold.md" "$pd/snap-none.md" "$pd/snap-legacy.md" \
    "$pd/snap-decoy.md" "$pd/snap-tail.md" "$pd/ss-plain.yaml" "$pd/ss-quoted.yaml" "$pd/ss-none.yaml" \
    "$pd/stories/probe.md" "$pd/stories/unstamped.md" 2>/dev/null
  rmdir "$pd/stories" 2>/dev/null
  rmdir "$pd" 2>/dev/null
  return "$bad"
}

if [ "$MODE" = "fold" ]; then
  command -v jq >/dev/null 2>&1 || { echo "FAIL: jq is not on PATH; the ledger cannot be joined. Exit 2, not a pass." >&2; exit 2; }
  fa_self_probe || { echo "FAIL: the fold-architect self-probe did not hold, so a verdict on the real input would establish only that the join ran." >&2; exit 2; }
  [ -n "$LEDGER" ] || LEDGER="_bmad-output/spawn-ledger.jsonl"
  # THE VARIANT IS READ, NOT TYPED. `--variant` is an explicit override for tests; the gate
  # passes none. fa_resolve_variant owns the order: --variant, then the snapshot's
  # `pipeline_variant:` line, then sprint-status.yaml's top-level `variant:`. None of the three is
  # the fold OWED -- a missing record never reads as NOT-OWED.
  snap="${FA_SNAPSHOT:-_bmad-output/pipeline-snapshot.md}"
  if [ -z "$FA_VARIANT" ]; then
    if [ -f "$snap" ]; then
      [ -r "$snap" ] || { echo "FAIL: cannot read the pipeline snapshot $snap" >&2; exit 2; }
    elif [ -n "$FA_SNAPSHOT" ]; then
      echo "FAIL: no pipeline snapshot at $FA_SNAPSHOT. An absent --snapshot is a mistyped path, not a sprint with no variant." >&2
      exit 2
    fi
  fi
  # THE CROSS-CHECK RUNS BEFORE THE VARIANT DECIDES ANYTHING, and on `--variant` too: a false
  # `bug` in one record is the NOT-OWED opt-out, so it is compared before NOT-OWED can answer.
  sst="${FA_SSTATUS:-_bmad-output/implementation-artifacts/sprint-status.yaml}"
  if [ -n "$FA_SSTATUS" ] && [ ! -f "$FA_SSTATUS" ]; then
    echo "FAIL: no sprint-status file at $FA_SSTATUS. An absent --sprint-status is a mistyped path, not a sprint with no variant." >&2
    exit 2
  fi
  [ ! -f "$sst" ] || [ -r "$sst" ] || { echo "FAIL: cannot read $sst" >&2; exit 2; }
  fa_resolve_variant "$FA_VARIANT" "$snap" "$sst" || exit 2
  FA_VARIANT="$FA_RV"; FA_VSRC="$FA_RVSRC"
  if [ -n "$FA_VARIANT" ]; then
    [ -n "$FA_ROUTE" ] || FA_ROUTE=".claude/skills/ai-dlc/steps/route.md"
    [ -r "$FA_ROUTE" ] || { echo "FAIL: the variant needs a readable --route <route.md> (tried ${FA_ROUTE}), the file whose variant table decides whether an architecture step runs." >&2; exit 2; }
    case "$(fa_variant_arch "$FA_ROUTE" "$FA_VARIANT")" in
      no)  echo "NOT-OWED: variant '${FA_VARIANT}' runs no architecture step (route.md variant table, variant from ${FA_VSRC}), so no fold architect is owed."; exit 0 ;;
      yes) : ;;
      *)   echo "FAIL: variant '${FA_VARIANT}' (from ${FA_VSRC}) is not a row of the variant table in ${FA_ROUTE}. An unknown variant is a refusal, never NOT-OWED." >&2; exit 2 ;;
    esac
  fi
  fa_judge "$FA_RES" "$FA_ONE" "$LEDGER"; rc=$?
  case "$rc" in 0|3) exit 0 ;; 1) exit 1 ;; *) exit 2 ;; esac
fi

# A fumbled invocation must not share an exit code with a finding. Every argument
# fault exits 2, so a caller reading 1 as "a spawn violated Rule 19" cannot be
# reading a typo, and a caller reading 3 as PRE-LEDGER cannot be reading a path
# that was never passed.
if [ -z "$LEDGER" ] || [ -z "$SPRINT" ] || [ -z "$SETTINGS" ]; then
  echo "FAIL: --ledger <spawn-ledger.jsonl>, --sprint <N> and --settings <settings.json> are all required" >&2
  exit 2
fi
SPRINT_NUM="$(printf '%s' "$SPRINT" | tr -cd '0-9')"
[ -n "$SPRINT_NUM" ] || { echo "FAIL: --sprint must contain a number (got '$SPRINT')" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || {
  echo "FAIL: jq is not on PATH. The ledger is JSONL and nothing here can be compared without it;" >&2
  echo "      this exits 2 rather than reporting a clean ledger it never read." >&2
  exit 2
}
# An unreadable settings.json is NOT a consumer that pins no models -- it is a run that
# cannot answer the model arm at all. `pin_key` treats the two identically by design
# (the guard must fail open), so the distinction has to be made HERE, before the loop,
# or every spawn silently clears the arm it was written to check.
[ -r "$SETTINGS" ] || {
  echo "FAIL: cannot read $SETTINGS. Every role would resolve to 'pins nothing' and every" >&2
  echo "      spawn would clear the model arm without a comparison. Exits 2, not 0." >&2
  exit 2
}

# --- SHARED WITH core/hooks/ai-dlc-dispatch-guard.sh, byte-identical (I56) ------
# See this file's header for why these are copies and not a sourced helper. Do not
# edit one without the other; validate-enforcement-map.sh fails the build on a fork,
# and on either file defining either function more than once.
pin_key() {
  pk_k=""; pk_m=""
  [ -r "$1" ] || return 0
  pk_k="$(jq -r --arg r "$2" '.aiDlcRoles[$r].model // empty' "$1" 2>/dev/null || true)"
  [ -n "$pk_k" ] || return 0
  pk_m="$(jq -r --arg k "$pk_k" '.aiDlcModels[$k] // empty' "$1" 2>/dev/null || true)"
  [ -n "$pk_m" ] && printf '%s\n' "$pk_k"
  return 0
}

matches_pin() {
  [ -n "$EXPECT" ] || return 1
  case "$1" in
    "$EXPECT")   return 0 ;;
    *"$EXPECT"*) return 0 ;;
    *)           return 1 ;;
  esac
}
# --- end shared ----------------------------------------------------------------

# An absent ledger and a ledger holding only other sprints' rows are ONE state, and
# Check 22 says so: a consumer that pulls the guard mid-sprint gets a file whose first
# row is the NEXT dispatch, so "the file exists" and "this sprint is covered" are
# different claims. Both land on exit 3 below.
TOTAL=0
RECORDS=""
if [ -f "$LEDGER" ]; then
  # A ledger jq CANNOT PARSE is not an empty one. `jq -s` fails on the whole file for a
  # single truncated line -- the shape a crashed or concurrent append leaves -- and
  # swallowing that failure would report "0 row(s)" and route to PRE-LEDGER, which reads
  # as "the guard was not installed yet" for a file that is full of rows. Exit 2: nothing
  # was compared, and the reason is not the one PRE-LEDGER states.
  TOTAL="$(jq -rs '[ .[] | select(type == "object") ] | length' "$LEDGER" 2>/dev/null)" || {
    echo "FAIL: $LEDGER is not parseable as JSONL. A single truncated line fails the whole" >&2
    echo "      file, and reporting zero rows for it would be indistinguishable from a" >&2
    echo "      sprint that predates the dispatch guard. Repair or rotate the ledger." >&2
    exit 2
  }
  case "$TOTAL" in ''|*[!0-9]*) TOTAL=0 ;; esac
  # One TAB-separated record per in-sprint row. `sprint` is written as a number by the
  # guard and compared as one; a row whose sprint is null belongs to no sprint and is
  # counted as unattributed rather than silently swept into this one.
  #
  # NO FIELD MAY BE EMPTY, and that is not cosmetic. TAB is an IFS *whitespace*
  # character, so `read` collapses a run of them into one delimiter: a row with a null
  # `model_requested` would shift `role_contract_cited` into the `requested` variable
  # and every later field one place left, and the loop would compare the wrong strings
  # while reporting normally. Absent values carry a sentinel and the loop restores
  # them. (Measured on the first draft of this script: a null `model_requested`
  # reported `requested model='true'`.)
  RECORDS="$(jq -rs --argjson s "$SPRINT_NUM" '
      # `tostring` renders JSON null as the four-character string "null", which would
      # be compared against the pin as though the dispatch had asked for a model
      # called null. Nulls are mapped to the sentinel BEFORE any stringification.
      def tok: if . == null then "__NONE__"
               else (tostring | if . == "" then "__NONE__" else . end) end;
      .[]
      | select(type == "object")
      | select((.sprint // null) == $s)
      | [ (.name | tok),
          (.role | tok),
          (.model_bound | tok),
          (.model_requested | tok),
          (if .role_contract_cited == true then "true" else "false" end),
          (if .role_file_readable == false then "false" else "true" end),
          # THE SCHEMA MARKER, and it is the difference between a dispatch record and a
          # line somebody appended. The guard emits `v` on every row from one `jq -nc`
          # (ai-dlc-dispatch-guard.sh, SPAWN LEDGER block); a row without it was written
          # by something else, and its ABSENT fields are not evidence about a dispatch.
          (if (.v | type) == "number" then "guard" else "foreign" end),
          # THE THREE FIELDS THE EFFORT ARM READS, carrying the same `tok` sentinel as
          # every other. NO APOSTROPHE ANYWHERE IN THIS COMMENT: the whole projection is
          # one single-quoted jq program, so a possessive here CLOSES it and the shell
          # reports a syntax error two hundred lines further down, in an unrelated `echo`.
          # `definition_bound` is absent on every row written before this release,
          # and `tok` renders that absence as the sentinel rather than as the string
          # "null" -- which the loop would otherwise compare against "true" and get the
          # right answer for the wrong reason, silently, on a field whose absence is
          # exactly the pre-migration state the PENDING path exists for.
          (.definition_bound | tok),
          (.effort_bound | tok),
          (.tool_use_id | tok) ]
      | @tsv
    ' "$LEDGER" 2>/dev/null || true)"
fi

INSPRINT=0
if [ -n "$RECORDS" ]; then
  INSPRINT="$(printf '%s\n' "$RECORDS" | grep -c . || true)"
  case "$INSPRINT" in ''|*[!0-9]*) INSPRINT=0 ;; esac
fi

if [ "$INSPRINT" -eq 0 ]; then
  echo "PRE-LEDGER: ${TOTAL} row(s) in ${LEDGER}, NONE of them S${SPRINT_NUM}'s."
  echo "  This is not a pass. Zero rows and zero spawns are different states and this run"
  echo "  cannot tell them apart: a consumer that installed the dispatch guard mid-sprint"
  echo "  has a ledger whose first row is the NEXT dispatch. Fall back to the gate log's"
  echo "  spawn table and record in the gate log that the verdict rests on lead-authored"
  echo "  evidence rather than a machine record (Check 22)."
  exit 3
fi

CHECKED=0
VIOL=0
UNREADABLE=0
UNCITED=0
MISMATCH=0
CORRECTED=0
UNPINNED=0
OUTSCOPE=0
OUTSCOPE_ROLES=""
SUSPECT=0
FOREIGN=0
FOREIGN_ROLES=""
# The effort arm's four outcomes, counted separately because they carry four different
# remedies: verified, no ground truth yet, ground truth refused on a build where the
# field is not evidence, and a row that bound no effort at all. A single
# "not checked" bucket would make the second and third read alike, and only the third is
# a statement about the record's trustworthiness.
EFFORT_OK=0
EFFORT_PENDING=0
EFFORT_REFUSED=0
EFFORT_MISMATCH=0
EFFORT_UNDECLARED=0

# THE LEDGER HOLDS ROWS RULE 19 DOES NOT BIND, AND JUDGING THEM IS A FALSE FAIL ON
# CORRECT DATA. The dispatch guard derives `role` from `subagent_type` when the prompt
# carried no `team-roles/<role>.md` citation (ai-dlc-dispatch-guard.sh, FALLBACK branch),
# and that pattern accepts any lowercase agent type — so the harness's OWN built-in types
# (`general-purpose`, `fork`, `claude`) land in the ledger carrying
# `role_contract_cited=false` and `role_file_readable=false`, which are two Rule 19
# violations each, permanently, for a dispatch that has no role contract to cite and no
# role file to resolve. Measured on the reference consumer's ledger across sprints
# 298-307: 97 of the 111 role-arm violations were on rows the scope test now skips, and the
# lead re-derived the in-scope subset by hand at every implementation gate.
#
# **THAT 97 IS TWO POPULATIONS AND AN EARLIER REVISION OF THIS COMMENT CALLED IT ONE.** Split
# by whether the dispatch NAME is that of a declared role: 61 arms on agent types Rule 19
# genuinely does not bind, and 36 on 18 rows whose names say a real role was routed through
# the generic type -- which are not false at all. Those 36 leave the exit code and become the
# NOTEs below; they are not dismissed. Control: 61 + 36 = 97.
#
# THE SCOPE KEY IS DECLARATION, NOT A ROLE LIST. `aiDlcRoles` is Rule 19's single source
# of truth (see ai-dlc-dispatch-guard.sh's header) and this script already reads that file
# to resolve the pin, so the scope is derived from the consumer's own declaration rather
# than restated as a list here, which would be one more copy to drift.
#
# **I22 DOES NOT BIND THE FILE THIS READS, AND AN EARLIER REVISION OF THIS COMMENT SAID IT
# DID.** I22 joins `core/team-roles/*.md` to `templates/settings.json.template` — what a
# FRESH INSTALL starts from. `--settings` at gate time is the consumer's own
# `.claude/settings.json`, which that consumer may edit. So the vocabulary is bound at
# INSTALL and unbound thereafter, which is exactly why a role dropped from it must be
# visible rather than silently out of scope: see the out-of-scope naming below.
#
# THE `role_contract_cited` DISJUNCT IS WHAT KEEPS THE FIX FROM BEING A DISARM. A dispatch
# that cited `team-roles/<role>.md` CLAIMED an AI/DLC role contract, and it is judged
# whether or not settings.json still declares that role — so a consumer cannot silence a
# genuine violation by deleting an `aiDlcRoles` entry, and the fail-closed
# `role_file_readable=false` arm keeps its real subject: a cited role whose role FILE is
# absent, which is the partial-install case the guard's own comment names.
DECLARED_ROLES="$(jq -r '.aiDlcRoles // {} | keys[]' "$SETTINGS" 2>/dev/null || true)"
NL='
'
DECLARED_NL="${NL}${DECLARED_ROLES}${NL}"

# The scope test is a function so each half can be mutated on its own line. Spelled inline
# it was byte-identical to the Rule 19(b) arm below, and a mutant aimed at one hit both --
# caught by this check's own fixture before release.
row_in_scope() {  # role, role_contract_cited
  [ "$2" = "true" ] && return 0
  # AN EMPTY ROLE IS NOT A DECLARED ONE, and without this line it was — an empty
  # `DECLARED_ROLES` makes `DECLARED_NL` two newlines, which is exactly the pattern an
  # empty role builds, so a role-less row matched the membership test and was judged.
  # Its scope then depended on whether the settings file declared ANY role: measured, the
  # same row answered rc=1 under `aiDlcRoles: {}` and rc=3 under a one-key block.
  [ -n "$1" ] || return 1
  case "$DECLARED_NL" in *"${NL}${1}${NL}"*) return 0 ;; esac
  return 1
}

# THE SCOPE FILTER'S JOIN KEY IS THE FIELD THE VIOLATION CORRUPTS, so the filter needs a
# second reading that does not depend on it. A lead that dispatches a real team role with
# `subagent_type: general-purpose` and no contract citation produces a row whose `role` says
# `general-purpose` -- and that IS the Rule 19(b) violation, recorded in the one field the
# scope test reads. Measured on the reference consumer: 18 of the 49 rows this filter skips
# are named `dev-escalated-s299-1-v4`, `code-reviewer-s299-1-fixforward`,
# `gate-adjudicator-story-s302-v10` and so on -- role dispatches routed through the harness's
# generic agent type across four sprints. Naming the ROLE in `COUNTS:` cannot surface them,
# because the role reads `general-purpose` for every one.
#
# So the dispatch NAME is read as a second, independent signal. It is deliberately NOT a
# finding: the guard's own header says a name is a convention the lead chooses while the
# binding is the contract it must honour, and a consumer utility genuinely named `dev-tools-*`
# would be a false FAIL on correct data. It is a NOTE the adjudicator dispositions, in the
# same channel and for the same reason as a guard-corrected `model_requested`.
name_role() {  # dispatch name -> the longest declared role it is named after, or empty
  nr_best=""
  for nr_k in $DECLARED_ROLES; do
    case "$1" in
      "$nr_k"|"$nr_k"-*) [ "${#nr_k}" -gt "${#nr_best}" ] && nr_best="$nr_k" ;;
    esac
  done
  printf '%s' "$nr_best"
}

# --- THE EFFORT ARM'S GROUND TRUTH ---------------------------------------------
# `probe_effort <tool_use_id>` -> the effort the teammate's own transcript recorded, or
# empty when no probe row joins. THE JOIN IS THE EXACT TOOL-USE ID AND NOTHING ELSE.
#
# The ordered alternatives were measured and rejected: the ledger is written at dispatch
# and the telemetry at completion, so a join on (role, most-recent-unmatched) mis-pairs
# two same-role spawns that finish out of order -- and since those two share a configured
# effort, the comparison below PASSES on the wrong pairing. Measured on CC 2.1.269 with
# two same-definition spawns driven in both completion orders and scored by content: the
# id join paired 4 of 4, the ordered join 2 of 4. A join that is right on one ordering is
# not a join; it is a coin the gate cannot see.
#
# REFUSAL, NOT SILENCE, ON A PINNED-EFFORT MODEL BELOW 2.1.267. That build fixed `effort:`
# on models whose launch effort is pinned, so the field is not evidence there. It returns
# the sentinel `__REFUSED__` rather than empty, because empty means "no row joined" and
# routes to PENDING -- two different facts with two different remedies, and collapsing
# them is how an unverifiable row reads as an unwritten one.
PROBE_READABLE=false
[ -n "$PROBE" ] && [ -r "$PROBE" ] && PROBE_READABLE=true
probe_effort() {  # tool_use_id
  [ "$PROBE_READABLE" = true ] || return 0
  [ -n "$1" ] || return 0
  jq -rs --arg t "$1" '
      [ .[] | select(type == "object") | select((.tool_use_id // "") == $t) ] | last
      | if . == null then ""
        # The pinned family, named here because it is the population the version floor
        # applies to. An unpinned model carried a correct `effort` on every build, so
        # widening the refusal to every model would discard the rows this arm exists for.
        elif ((.model // "") | test("opus-4-7|opus-4-8|fable-5"))
             and (((.transcript_version // "0") | split(".") | map(tonumber? // 0))
                  < [2,1,267])
          then "__REFUSED__"
        else (.effort // "") end
    ' "$PROBE" 2>/dev/null || true
}

while IFS="$(printf '\t')" read -r name role bound requested cited readable schema defbound effortbound tui; do
  [ -n "$name" ] || continue
  [ "$name" = "__NONE__" ] && name="<unnamed>"
  [ "$role" = "__NONE__" ] && role=""
  [ "$bound" = "__NONE__" ] && bound=""
  [ "$requested" = "__NONE__" ] && requested=""
  [ "${defbound:-__NONE__}" = "__NONE__" ] && defbound=""
  [ "${effortbound:-__NONE__}" = "__NONE__" ] && effortbound=""
  [ "${tui:-__NONE__}" = "__NONE__" ] && tui=""

  # A ROW THE GUARD DID NOT WRITE IS NOT A DISPATCH RECORD, and judging one manufactures
  # violations out of ABSENT fields rather than observed ones. `--ledger` names an
  # append-only file any session can write to, and the single-writer premise this check
  # rested on is a convention, not a guarantee. Measured on the reference consumer: 14 rows
  # carry a hand-written provenance schema (`deliverable`, `dispatched_at`, `sha`, `step`
  # and no `v`), 13 of them name a DECLARED role, and they produced 24 of the 25 violations
  # this check reported after the scope filter landed -- 13 citation arms, because an absent
  # `role_contract_cited` reads as false, and 11 tier mismatches, because an absent
  # `model_bound` compares as the empty string against a real pin. Exactly ONE of the 25 was
  # a genuine finding by a guard-written row.
  #
  # They are NAMED rather than dropped: foreign content in the spawn ledger is itself
  # something an adjudicator should see, and it is a different fact from a dispatch of an
  # agent type Rule 19 does not bind.
  if [ "$schema" != "guard" ]; then
    FOREIGN=$((FOREIGN + 1))
    case "${NL}${FOREIGN_ROLES}" in
      *"${NL}${role:-<none>}${NL}"*) : ;;
      *) FOREIGN_ROLES="${FOREIGN_ROLES}${role:-<none>}${NL}" ;;
    esac
    continue
  fi

  # Out of scope is COUNTED and NAMED, never silently dropped. A real team role appearing
  # in this list is the visible symptom of a settings.json that lost its entry, which is
  # the one way this filter could hide a finding.
  if ! row_in_scope "$role" "$cited"; then
    OUTSCOPE=$((OUTSCOPE + 1))
    # NEWLINE-delimited accumulator, tested the same way. Spelled as a SPACE-separated list
    # against a newline-delimited membership test, the de-duplication silently matched only
    # the whole string -- so the first role de-duplicated and every later one repeated, and
    # `general-purpose fork general-purpose fork` reads as four skipped roles.
    case "${NL}${OUTSCOPE_ROLES}" in
      *"${NL}${role:-<none>}${NL}"*) : ;;
      *) OUTSCOPE_ROLES="${OUTSCOPE_ROLES}${role:-<none>}${NL}" ;;
    esac
    _nr="$(name_role "${name}")"
    if [ -n "$_nr" ]; then
      SUSPECT=$((SUSPECT + 1))
      echo "NOTE: [$name] skipped as out of Rule 19 scope, role '${role:-<none>}' -- but its"
      echo "      dispatch name is that of the declared role '${_nr}'. If it WAS that role, the"
      echo "      dispatch named it via subagent_type alone and cited no role contract, which is"
      echo "      the Rule 19(b) violation this check cannot see: the role field carries the"
      echo "      agent type, not the role. Disposition it in the gate log (Check 22)."
    fi
    continue
  fi

  CHECKED=$((CHECKED + 1))

  # Fail-closed arm, and it is unconditional: a teammate that ran without a resolvable
  # role-file binding is a Rule 19 violation, not a pass.
  if [ "$readable" = "false" ]; then
    echo "FAIL: [$name] role_file_readable=false -- role '${role:-<none>}' resolved to no readable" >&2
    echo "      role file, so this teammate ran with no contract at all (Rule 19, fail-closed)." >&2
    echo "      It is a fact about the past: clear it only through Check 22's" >&2
    echo "      four-arm disposition, never by re-running the gate." >&2
    VIOL=$((VIOL + 1)); UNREADABLE=$((UNREADABLE + 1))
  fi

  # Rule 19(b): the dispatch guard recorded that the contract line reached the teammate by
  # neither carrier -- not in the prompt, and not in the body of the definition the dispatch
  # selected (`contract_via` null). The guard bound the model anyway; the citation is still
  # owed. A row written before the guard read the definition body reads false here even
  # where that body carried the line, and it is NOT re-read: the row is a past record, and
  # it clears through the four-arm disposition like any other.
  if [ "$cited" != "true" ]; then
    echo "FAIL: [$name] role_contract_cited=false -- the dispatch of role '${role:-<none>}' carried the" >&2
    echo "      Rule 19(b) line in neither its prompt nor the definition it selected." >&2
    echo "      It is a fact about the past: clear it only through Check 22's" >&2
    echo "      four-arm disposition, never by re-running the gate." >&2
    VIOL=$((VIOL + 1)); UNCITED=$((UNCITED + 1))
  fi

  # Rule 19(a). EXPECT is a global because `matches_pin` reads one -- it is the guard's
  # function verbatim and closes over the same name there.
  EXPECT="$(pin_key "$SETTINGS" "$role")"
  if [ -z "$EXPECT" ]; then
    # A role with no pin, or a key mapping to nothing, binds no model. The party
    # personas legitimately carry an effort and no model, so this is a normal state
    # and not a finding -- but it is COUNTED, because a settings.json that lost its
    # aiDlcRoles block would otherwise clear every row in silence.
    UNPINNED=$((UNPINNED + 1))
  elif ! matches_pin "$bound"; then
    echo "FAIL: [$name] ran on model_bound='${bound}' against role '${role}' pinned to" >&2
    echo "      aiDlcRoles.${role}.model='${EXPECT}'. This is a recorded Rule 19(a) tier" >&2
    echo "      mismatch. It is a fact about the past: clear it only through Check 22's" >&2
    echo "      four-arm disposition, never by re-running the gate." >&2
    VIOL=$((VIOL + 1)); MISMATCH=$((MISMATCH + 1))
  elif [ -n "$requested" ] && ! matches_pin "$requested"; then
    # Reported, NOT failed. Check 22 is explicit: the guard caught the slip before the
    # work ran and the teammate ran on the key its role names.
    echo "NOTE: [$name] requested model='${requested}' against pin '${EXPECT}'; the guard"
    echo "      corrected it to '${bound}' before dispatch. Recorded, not a failure."
    CORRECTED=$((CORRECTED + 1))
  fi

  # --- THE EFFORT ARM. THE SCOPE KEY IS `effort_bound`, NOT `definition_bound`, and that
  # is the whole of what this arm can judge. A non-empty `effort_bound` is the guard saying
  # the harness was ASKED to apply a level to this dispatch; an empty one says nothing was,
  # whether because the row is prose-only, because its definition drifted or was absent, or
  # because the role declares no effort. Only the first class has a claim to check.
  #
  # SCOPING ON `definition_bound` INSTEAD WOULD BE THE SAME TEST WRITTEN INDIRECTLY, AND
  # WEAKER. The guard sets that flag only when the rendered definition AGREES with settings
  # on both model and effort (ai-dlc-dispatch-guard.sh, the AGREEMENT IS ON BOTH KEYS
  # block), so on a definition-bound row `effort_bound` equals the configured level by
  # construction -- which is why reading settings here scored identically on every row this
  # arm has ever seen, and why that agreement was never evidence the field was being read.
  # Keying on the field itself judges the same rows plus the ones the guard has told us it
  # bound nothing for, and it says so about THEM rather than skipping them in silence.
  #
  # THE COMPARED VALUE IS THE LEDGER'S, READ AT DISPATCH, NOT SETTINGS READ NOW. The two
  # agree on a tree nobody edited and are different claims once one is: settings at gate
  # time says what the role is configured for TODAY, and the row says what the harness was
  # asked to apply to THAT spawn. A role reconfigured between the dispatch and the gate
  # makes the settings read score every earlier row against a level no dispatch carried --
  # a FAIL on correct data in one direction and a silent pass in the other, on a comparison
  # whose whole purpose is to be a fact about the past.
  # BOTH DISJUNCTS ARE LIVE AND THEY EXCLUDE DIFFERENT ROWS. An empty `effort_bound` is
  # the guard reporting that nothing was bound. `definition_bound: false` beside a
  # NON-EMPTY one is a row no shipped guard writes -- the two are set together -- so it is
  # a hand-written or pre-migration row asserting a binding that the same row denies
  # happened, and judging a teammate on it would be judging an unwritten claim.
  if [ -z "$effortbound" ] || [ "$defbound" != "true" ]; then
    # NOTHING BOUND AN EFFORT HERE, AND THAT IS A COUNTED FACT RATHER THAN A SKIPPED ROW.
    # A prose-only dispatch got the configured level as a sentence the guard appended,
    # which is advisory by construction -- the Agent tool has no effort parameter, so the
    # teammate ran at whatever its session resolved. Failing that would be failing correct
    # data for doing what it was designed to do; passing it SILENTLY would let a sprint
    # whose every row bound nothing read exactly like one where every row was verified.
    EFFORT_UNDECLARED=$((EFFORT_UNDECLARED + 1))
  else
    EFF_OBSERVED="$(probe_effort "$tui")"
    if [ "$EFF_OBSERVED" = "__REFUSED__" ]; then
      echo "PENDING: [$name] ran on a pinned-effort model against a transcript below"
      echo "      CC 2.1.267, where the recorded \`effort\` is not evidence about what"
      echo "      applied. Not scored, and not a pass."
      EFFORT_REFUSED=$((EFFORT_REFUSED + 1))
    elif [ -z "$EFF_OBSERVED" ]; then
      # PENDING, NOT FAIL. No probe row joined: no --probe was passed, the telemetry
      # predates this row, or the teammate is still running. A consumer that pulls this
      # release mid-sprint is in exactly this state for every row already dispatched,
      # and failing it would wedge the sprint on a verification that could not have run.
      EFFORT_PENDING=$((EFFORT_PENDING + 1))
    elif [ "$EFF_OBSERVED" = "$effortbound" ]; then
      EFFORT_OK=$((EFFORT_OK + 1))
    else
      echo "FAIL: [$name] was dispatched definition-bound with effort_bound=" >&2
      echo "      '${effortbound}', and its own transcript records effort='${EFF_OBSERVED}'." >&2
      echo "      The definition did not apply: the teammate ran at a level nothing bound." >&2
      echo "      Both sides are ground truth -- the left is what the guard recorded binding" >&2
      echo "      at dispatch, the right is the harness's own transcript, and neither is a" >&2
      echo "      self-report. Re-render .claude/agents/${role}.md from aiDlcRoles.${role}.effort" >&2
      echo "      and confirm the dispatch passed no \`name\`, which routes the spawn to the" >&2
      echo "      runner that drops effort." >&2
      echo "      The spawn that already ran is a fact about the past: clear it only through" >&2
      echo "      Check 22's four-arm disposition, never by re-running the gate." >&2
      VIOL=$((VIOL + 1)); EFFORT_MISMATCH=$((EFFORT_MISMATCH + 1))
    fi
  fi
done <<EOF
$RECORDS
EOF

# The counts line prints on every outcome. A verdict that does not say what it compared
# cannot be told apart from one that compared nothing -- which is the whole reason this
# check has an enforcer.
echo "COUNTS: examined ${CHECKED} S${SPRINT_NUM} spawn row(s) of ${TOTAL} in ${LEDGER};"
echo "  ${UNREADABLE} unreadable role file(s), ${UNCITED} missing Rule 19(b) citation(s),"
echo "  ${MISMATCH} tier mismatch(es), ${CORRECTED} guard-corrected request(s) (not failures),"
echo "  ${UNPINNED} row(s) whose role pins no model in ${SETTINGS},"
# THE EFFORT ARM REPORTS WHAT IT COMPARED ON EVERY PATH, for the reason the line above it
# exists: a run that verified nothing and a run that found nothing print the same verdict
# otherwise, and on this arm "nothing to verify" is the NORMAL state of a consumer that
# has not yet pulled the renderer. The PENDING figure is what tells the two apart.
# ONE expansion, not `${PROBE:+…}${PROBE:-…}` — those are not the two halves of an
# either-or. `:+` fires on a SET value and `:-` on an UNSET one, but `:-` substitutes its
# word only when the variable is empty, so with `PROBE` set BOTH expanded and the line
# printed the path twice, concatenated. Caught by reading the arm's own output.
if [ -n "$PROBE" ]; then PROBE_NOTE="probe: ${PROBE}"; else PROBE_NOTE="no --probe was passed"; fi
echo "  effort: ${EFFORT_OK} verified against the teammate's own transcript, ${EFFORT_MISMATCH} mismatch(es),"
echo "  ${EFFORT_PENDING} PENDING (no probe row joined; ${PROBE_NOTE}), ${EFFORT_REFUSED} refused on a pre-2.1.267 pinned-effort record,"
echo "  ${EFFORT_UNDECLARED} row(s) that bound no effort (no effort_bound: prose-only, drifted or absent definition, or a role declaring none);"
OUTSCOPE_LIST="$(printf '%s' "$OUTSCOPE_ROLES" | tr '\n' ' ')"
OUTSCOPE_LIST="${OUTSCOPE_LIST% }"
FOREIGN_LIST="$(printf '%s' "$FOREIGN_ROLES" | tr '\n' ' ')"
FOREIGN_LIST="${FOREIGN_LIST% }"
echo "  ${OUTSCOPE} row(s) out of Rule 19 scope${OUTSCOPE_LIST:+ (roles: ${OUTSCOPE_LIST})},"
echo "  ${SUSPECT} of them named after a declared role and NOTED above,"
echo "  ${FOREIGN} row(s) the dispatch guard did not write${FOREIGN_LIST:+ (roles: ${FOREIGN_LIST})} -- not dispatch records."

# EVERY IN-SPRINT ROW OUT OF SCOPE IS NOT A PASS, and it reaches this line by a different
# route than PRE-LEDGER does: the ledger DOES cover this sprint, and nothing in it was a
# role-bound dispatch this check can judge. The consequence is identical to PRE-LEDGER's --
# nothing was compared, so the verdict rests on the gate log's spawn table -- which is why
# it takes exit 3 rather than a new code the gate does not document. Without this arm the
# filter above would turn a settings.json that lost its `aiDlcRoles` block into a silent
# exit 0 on a sprint full of uncited dispatches.
if [ "$CHECKED" -eq 0 ]; then
  echo "NO ROLE-BOUND ROWS: EXAMINED NOTHING — ${INSPRINT} S${SPRINT_NUM} row(s) exist and NONE of them was judged"
  echo "  -- ${OUTSCOPE} out of Rule 19 scope${OUTSCOPE_LIST:+ (roles: ${OUTSCOPE_LIST})} and ${FOREIGN} not written by the dispatch"
  echo "  guard${FOREIGN_LIST:+ (roles: ${FOREIGN_LIST})}. This is not a pass: nothing was compared. If a real team"
  echo "  role is named in the out-of-scope list, that settings file has lost its aiDlcRoles"
  echo "  entry for it; if one is named in the guard list, something appended to the ledger."
  echo "  Fall back to the gate log's spawn table and record that the verdict rests on"
  echo "  lead-authored evidence rather than a machine record (Check 22)."
  exit 3
fi

if [ "$VIOL" -gt 0 ]; then
  echo "FAIL: ${VIOL} Rule 19 violation(s) across ${CHECKED} S${SPRINT_NUM} spawn row(s)." >&2
  exit 1
fi
# THE PIN CLAUSE OF THAT SENTENCE HAS TO HAVE BEEN TESTED TO BE SAID.
# Rule 19(a) is compared only where `EXPECT` is non-empty; a row whose role pins no
# model is COUNTED as UNPINNED and correctly not treated as a finding, because the party
# personas legitimately carry an effort and no model. The counting was already here, and
# the comment beside it already named the hazard -- a settings.json that lost its
# aiDlcRoles block clears every row in silence. But nothing ever READ the count, so the
# hazard it was counting for still ended in this sentence, which asserts every row's
# model matched a pin that was never fetched.
#
# Measured with one ledger, two settings files differing only in the key name
# (`aiDlcRoles` -> `aiDlcRolesXX`), both rows carrying a genuine tier mismatch:
# the intact settings gave `FAIL: 2 Rule 19 violation(s)` rc=1, and the renamed key gave
# the full OK sentence rc=0.
if [ "$CHECKED" -gt 0 ] && [ "$UNPINNED" -eq "$CHECKED" ]; then
  echo "OK WITH NO PIN COMPARED: all ${CHECKED} S${SPRINT_NUM} spawn row(s) carry a resolvable"
  echo "  role file and a Rule 19(b) contract citation. Rule 19(a) was NOT tested on any row:"
  echo "  every role pinned no model in ${SETTINGS}, so the comparison ran zero times."
  echo "  If that file is meant to carry an aiDlcRoles block, this is the shape a lost or"
  echo "  renamed key takes -- it clears every row rather than failing any."
  exit 0
fi
echo "OK: all ${CHECKED} S${SPRINT_NUM} spawn row(s) carry a resolvable role file, a Rule 19(b)"
echo "  contract citation, and a model matching their role's configured pin"
echo "  (${UNPINNED} row(s) pin no model and were not compared)."
exit 0
