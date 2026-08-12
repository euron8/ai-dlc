#!/usr/bin/env bash
# apply.sh — the RESOLUTION half of ai-dlc-update. Executes every MECHANICAL resolution a pull
# needs, and emits a worklist of the only things left: the genuinely SEMANTIC merges (which the
# skill does inline) and the genuine OPERATOR decisions. The point of the whole skill is that the
# operator runs the update and it lands — not that a report tells them to go do the fixes by hand.
#
# WHAT IT RESOLVES MECHANICALLY (writes to the consumer; the caller wraps this in a branch+commit):
#   - pure applies        UPSTREAM-ONLY / UPSTREAM-ONLY-ADD core files overwritten from theirs
#   - token substitution  a new SETUP-TOKENS file is applied from theirs; model config no longer
#                         flows through tokens (role files name an aiDlcModels key), so no fill
#   - drift refile        a known in-place core-list drift refiled to its consumer-extension point
#                         (provenance-block.json known_skills -> extensions/known-skills.json) and
#                         the core file reverted — the "migrate the drift" chore, automated
#   - catalog relabel     relabel-extension-checks.sh --apply (labels NEW-THIS-PULL collisions)
#   - re-stamp            .ai-dlc-version base -> theirs, and ONLY if every mechanical apply
#                         landed. The stamp asserts "this tree is at theirs"; if a file that
#                         should have been placed was not, it says so instead (see phase 5).
#
# WHAT IT HANDS BACK (it does NOT guess these):
#   WORKLIST semantic-merge   <path>      a BOTH-CHANGED file needing a 3-way PROSE merge (LLM)
#   WORKLIST override-readopt <override>  a HARD-OVERRIDE-DRIFT-SECTION: merge the section, then
#                                         readopt-override.sh --stamp readopt (LLM + gated script)
#   WORKLIST extension-reread <entry>     an EXTENSION-HOOK-DRIFT: the hooked core file changed,
#                                         so re-read the entry and record a verdict (LLM)
#   DECISION <kind> <path> <why>          a genuine operator call (unknown drift refile-vs-revert,
#                                         a deletion, a value with no default)
#   DECISION restamp-withheld <stamp>     a file that SHOULD have applied mechanically did not,
#                                         so the stamp was NOT advanced — this one is a bug in
#                                         THIS file, not a call the operator can make
#
# Usage:  apply.sh [--carried-machinery-slice] <dist> <base> <consumer> <theirs>
# Exit:   0 = mechanical resolution completed (a residual WORKLIST/DECISION is normal, not failure)
#         1 = an error while resolving; 2 = usage.
set -uo pipefail

# --- ARGUMENTS: four positionals, and ONE flag that changes what the re-stamp CLAIMS ---------
#
# `--carried-machinery-slice` says: step 2's self-update DEFERRED and handed its machinery slice
# to this run, so the machinery this apply just wrote is theirs' and the stamp's
# `skill_version`/`skill_commit` must advance with `version`/`commit`. Without the flag they are
# PRESERVED — the ordinary case, and the correct one: a rulebook-only apply must not claim a
# machinery version it did not install.
#
# WHY A FLAG AND NOT A DEFAULT EITHER WAY. `ai-dlc-update/SKILL.md` carried BOTH instructions,
# 1100 lines apart: step 2's defer branch said advance the skill pair with the step-7 apply,
# step 7's re-stamp said preserve it. Whichever the agent read, the other was disobeyed, and
# this file implemented preserve by never touching the fields at all — so the pair was advanced
# by hand on every pull, or not at all. Neither instruction is wrong; they describe different
# runs, and the CALLER is the only thing that knows which run this is. It says so here instead
# of leaving two prose sites to contradict each other.
#
# THE FAILURE A STALE `skill_commit` PRODUCES is `unregistered-drift.sh`'s. Its
# `CORE-AT-SELF-UPDATE` suppression — "not drift, no action" — holds a machinery file
# byte-identical to the distribution at `skill_commit`, read from this same stamp. Leave the
# field behind and the machinery files this apply wrote from THEIRS are no longer identical to
# that ref, so each reads as consumer drift and draws a status whose printed remedy is to revert
# upstream's own text. That is verbatim the failure v0.309.0 fixed, arriving through the stamp
# instead of through the scan.
#
# POSITION-INDEPENDENT, and documented FIRST at both call sites, matching the shape
# `emit-report.sh --verify <report> …` already uses. Measured before shipping: 21 invocation
# sites, every one exactly four positional arguments, NONE passing a fifth — so no existing
# caller changes behaviour. (Control: the same extraction reports four redirection-carrying
# lines as non-four, so it is not an argument counter stuck on the answer it was looking for.)
CARRIED_MACHINERY=0
_pos_n=0
for _a in "$@"; do
  case "$_a" in
    --carried-machinery-slice) CARRIED_MACHINERY=1 ;;
    --*)
      echo "apply: unknown option: $_a" >&2
      echo "usage: apply.sh [--carried-machinery-slice] <dist> <base> <consumer> <theirs>" >&2
      exit 2 ;;
    *)
      _pos_n=$((_pos_n+1))
      case "$_pos_n" in
        1) _p1="$_a" ;; 2) _p2="$_a" ;; 3) _p3="$_a" ;; 4) _p4="$_a" ;;
        *) echo "apply: too many arguments: $_a" >&2
           echo "usage: apply.sh [--carried-machinery-slice] <dist> <base> <consumer> <theirs>" >&2
           exit 2 ;;
      esac ;;
  esac
done

DIST="${_p1:?usage: apply.sh [--carried-machinery-slice] <dist> <base> <consumer> <theirs>}"
BASE="${_p2:?}"
CONSUMER="${_p3:?}"
THEIRS="${_p4:?}"

SELF="$(cd "$(dirname "$0")" && pwd)"

# The running script AS A FILE, not as the directory above. Used only to notice that this
# driver is among the files it is about to replace -- see overwrite_from_theirs().
#
# COMPARED WITH `-ef`, WHICH IS device+inode, NEVER BY PATH STRING. `$0` is whatever the caller
# typed, `consumer_path()` builds `$CONSUMER/<rel>`, and the two spell the same file differently
# on every real invocation (`.claude/skills/...` against an absolute consumer root, with `..`
# and symlinks possible in either). A string compare here would silently never match, which is
# the shape of check this repo keeps shipping: it would read exactly like "the driver was not
# in the set."
SELF_FILE="$SELF/$(basename "$0")"
self_replaced=0
# say — ONE ROW OF THE MANIFEST, AND IT CARRIES ITS DETAIL.
#
# This printed THREE fields while EIGHTEEN of its call sites passed FOUR, so every WORKLIST and
# DECISION detail in this file was computed and then discarded. The rows the operator actually
# read were `WORKLIST<TAB>override-retire<TAB><path>` and nothing else: no key to write, no
# ordering constraint, no reason. SKILL.md step 7 documents that field as contracted -- "a row
# whose detail begins `<i>/<n> ATOMIC` is one step of an ORDERED SEQUENCE... each step states its
# own consequence" -- so the reader was told to obey a field that was never printed.
#
# It was invisible because nothing drove this output. No fixture asserted a WORKLIST row's
# detail; the one fixture that greps a WORKLIST row (apply-drift-after-write) matches on the
# subject path, which is field 3 and survived. `core/fixtures/apply-worklist-rows` now drives
# the real script and asserts the field, with the 3-field spelling as one of its mutants.
#
# The fourth field is emitted only when non-empty, so a genuinely 3-argument call site
# (`semantic-merge` with no addendum) is byte-identical to what it printed before and no reader
# gains a trailing tab it did not have.
say() {
  if [ -n "${4:-}" ]; then printf '%s\t%s\t%s\t%s\n' "$1" "$2" "${3:-}" "$4"
  else                     printf '%s\t%s\t%s\n'     "$1" "$2" "${3:-}"
  fi
}
err() { echo "apply: $*" >&2; exit 1; }

# --- IN-FLIGHT MARKER: this tree is mid-pull and its self-tests do not hold ----
# A pull writes core one file at a time, so between the first write and the re-stamp the
# tree is a MIXTURE of two releases and its own fixture suite reports failures that are
# neither the consumer's fault nor a real regression. Measured on the 0.156.0 -> 0.162.0
# range, in BOTH directions: a fixture newer than its subject asserts behaviour that is
# not there yet (check-15-bypass could not find core-paths.sh; core-write-guard read the
# core-fixture deny as `allow` because the manifest had no fixtures/ entries), and a
# subject newer than its fixture breaks the old assertions (apply-restamp-theirs and
# apply-drift-refile both failed against the newer apply.sh). Ordering alone cannot fix
# that -- only one of the two directions can be last -- so the tree has to be able to say
# "do not judge me yet".
#
# The marker is written before the first core write and removed ONLY when the re-stamp is
# written. A withheld re-stamp leaves it in place deliberately: that tree really is
# inconsistent, and the next `git push` should block on it rather than run a suite whose
# result means nothing. `core/git-hooks/pre-push` refuses the fixture step while it
# exists, and names it so an abandoned pull can be cleared by hand.
#
# NOT a manifest entry: it is consumer runtime state, like .ai-dlc-version beside it.
APPLYING="$CONSUMER/.claude/.ai-dlc-applying"
mkdir -p "$CONSUMER/.claude" 2>/dev/null || true
printf 'base: %s\ntheirs: %s\n' "$BASE" "$THEIRS" > "$APPLYING" 2>/dev/null || true

# core/<rel> -> consumer path. ONE mapper.
#
# `preclassify.sh`'s map_consumer() IS the mapping, and I8 binds it at both ends: every
# core/<dir>/ on disk must have a site row, and that row's destination must be a path
# install.sh really writes. This function had its own hand-listed copy of the same table --
# a fourth statement of the map, bound to nothing -- and it drifted exactly as the earlier
# copies did. It enumerated destinations by hand and omitted core/session-driver/,
# core/ci-templates/ and core/git-hooks/, so those hit `*) return 1` and NEVER APPLIED while
# the same run re-stamped .ai-dlc-version -- a stamp claiming a version the tree lacks.
#
# It hid because the only delta core/session-driver/ ever carried was a mode bit (100644 ->
# 100755) that install.sh had already set on the consumer, so nothing observable broke.
# `skills/` was queued to be next: three hardcoded skill names, and a fourth would have
# fallen straight through.
#
# So: derive, never re-list. Note the direction -- preclassify already computes this and
# hands it back as column 3 of its own output, which this file then threw away to recompute
# with a worse mapper. I17 now evaluates this function against I8's table so it cannot grow
# a private one again.
eval "$(awk '/^map_consumer\(\) \{/,/^\}/' "$SELF/preclassify.sh" 2>/dev/null)"
command -v map_consumer >/dev/null 2>&1 || err "could not load map_consumer() from $SELF/preclassify.sh — refusing to guess consumer paths. Falling back to a private table is the exact bug this delegation removes: it would apply some subtrees, skip others, and re-stamp as though everything landed."

consumer_path() { # <core-stripped rel> -> absolute consumer path
  local m; m="$(map_consumer "core/$1")"
  [ -n "$m" ] || return 1
  printf '%s/%s' "$CONSUMER" "$m"
}
# Carry THEIRS's file MODE, not just its bytes.
#
# `git show > file` is a shell redirect: it takes the mode from the umask when the
# file is NEW, and preserves the consumer's existing mode when it is not. So an
# UPDATED executable keeps working (install.sh chmod'd it once, and `>` leaves
# that alone) while a NEWLY SHIPPED executable lands 0644 and is INERT. Every
# reconcile verification still reports green, because they all diff CONTENT and
# the content is byte-perfect.
#
# That is the whole failure: v0.70.0's dispatch guard would install byte-identical
# and non-executable in every pulling consumer, its hard_block silently
# unenforced, with nothing anywhere reporting a problem. The check-that-cannot-
# fire class, one layer down — the check is fine, the file it polices cannot run.
# It stayed invisible for exactly as long as no release shipped a NEW hook that
# denied anything.
#
# DERIVE the bit from git's own tree (`ls-tree` reports 100755/100644) rather than
# hand-listing which paths are executable: a list would rot the first time someone
# adds a hook, which is precisely the case that is already broken.
sync_mode_from_theirs() { # <core-rel> <consumer-path>
  local mode
  mode="$(git -C "$DIST" ls-tree "$THEIRS" -- "core/$1" 2>/dev/null | awk '{print $1}')"
  case "$mode" in
    100755) chmod +x "$2" 2>/dev/null || true ;;
    100644) chmod -x "$2" 2>/dev/null || true ;;
    *) : ;;   # unknown/absent -> leave whatever is there; never guess
  esac
}

# WRITE A NEW INODE, NEVER TRUNCATE THE OLD ONE -- because THIS FILE is one of the files
# this function writes, and it is running while it does it.
#
# `skills/*` maps to `.claude/%s` (core-paths.sh), so `core/skills/ai-dlc-update/reconcile/
# apply.sh` lands at `.claude/skills/ai-dlc-update/reconcile/apply.sh`; it is UPSTREAM-ONLY
# on any range that changed it, so phase 1 writes it; and SKILL.md step 7 tells the session
# to run `reconcile/apply.sh <dist> <base> <consumer> <theirs>` -- a relative path inside the
# installed skill, i.e. that exact copy. The driver overwrites itself mid-run.
#
# `git show > "$cons"` is a shell redirect: open+truncate+write, SAME INODE. bash executes a
# script by reading it incrementally and keeping a byte offset, so after the truncate its next
# read lands at the same offset in DIFFERENT content.
#
# MEASURED, not recalled -- the question "does bash re-read a replaced script" was settled by
# experiment first, because the answer decides whether this is live or latent:
#
#   in-place overwrite (cp, same inode)  -> bash resumed inside the NEW text, ran the
#                                           replacement's tail, and exited rc=0
#   atomic replace (mv, new inode)       -> unaffected, original ran to completion
#   no replacement (control)             -> unaffected
#
# Then reproduced at ground truth on a scratch consumer installed at 0.310.0 and pulled to
# 0.312.0 (apply.sh's first differing byte is 2830 of 50463, well before bash's read offset at
# phase 1). Same dist, same range, same tree, same 8 pure-applies; the ONLY variable is where
# the running copy lives:
#
#   running copy = the consumer's own      rc=2, `line 251: syntax error near ';;'`,
#                                          stamp withheld, .ai-dlc-applying LEFT, tree partial
#   running copy = out-of-tree (control)   rc=0, no stderr, re-stamped 0.312.0, marker cleared
#
# THE ABORT IS THE LUCKY END OF THE BAND. Whether the shifted bytes fail to parse or merely
# parse into something else is not under anyone's control -- the bash arm above shows the same
# mechanism producing rc=0 with the wrong code executed. A driver that silently skips phases
# and then re-stamps is the failure this one must not have.
#
# The fix is the idiom this file already uses at five other write sites (`.incoming.$$` + mv):
# rename(2) swaps the directory entry and leaves the old inode alive for whoever holds it open,
# so the run finishes on the version the operator invoked and the next run uses the new one.
# It also removes a second, quieter defect: the redirect truncated `$cons` BEFORE `git show`
# ran, so a failed show left an EMPTY core file where the old one had been.
overwrite_from_theirs() { # <core-rel>
  local cp="$1" cons tmp; cons="$(consumer_path "$cp")" || return 1
  mkdir -p "$(dirname "$cons")"
  tmp="$cons.incoming.$$"
  # Recorded BEFORE the write, because after the rename the old inode no longer has this name.
  [ -e "$cons" ] && [ "$cons" -ef "$SELF_FILE" ] && self_replaced=1
  if ! git -C "$DIST" show "${THEIRS}:core/${cp}" > "$tmp" 2>/dev/null; then
    rm -f "$tmp"; return 1
  fi
  # chmod the TEMP, so the mode swaps atomically with the content rather than existing as a
  # window where the file is in place with the wrong bit. Same derivation, same function.
  sync_mode_from_theirs "$cp" "$tmp"
  mv "$tmp" "$cons" || { rm -f "$tmp"; return 1; }
}

# A file that SHOULD have been applied mechanically but could not be. NOT the same as the
# declared hand-backs: a WORKLIST semantic-merge or an operator DECISION is work the caller
# completes in this same run, and the stamp is still true once it does. This counter is for
# the other thing -- apply.sh not knowing how to place a file the pull classified and the
# installer ships. That is a bug in this file, and it must not end with a stamp saying the
# tree is at THEIRS.
mech_fail=0

# ------------------------------------------------- 0. MEASURE, before anything is written
#
# Every detector this file consults answers a question about the CONSUMER'S OWN STATE:
# preclassify buckets a file by how consumer, base and theirs relate; unregistered-drift
# asks whether a core file was edited in place, which it decides with
# `git show "${BASE}:${cp}" | cmp -s - "$cons"` (unregistered-drift.sh:187). Both are only
# meaningful BEFORE this script starts overwriting that state.
#
# The drift capture used to sit down in phase 2, AFTER phase 1 had already overwritten every
# pure-apply file from THEIRS. So any file that was both a pure-apply and changed upstream
# NECESSARILY reported as consumer drift -- the detector was measuring the write this driver
# had made moments earlier, in a pull with no consumer drift in it at all.
#
# That is not a spurious row. unregistered-drift.sh emits HARD-CORE-DRIFT-ABSORBED with a
# ready `git show ... > <consumer-path>` revert command and the line "This still blocks
# because a revert DELETES text and only you can confirm nothing was lost." A CLEAN pull
# therefore handed the operator a destructive instruction, confidently worded, at exactly
# the step where the tool asks for an irreversible decision. Observed on the v0.95.0 ->
# v0.99.0 pull: three findings on files this driver had just written, each detail string
# carrying its own refutation (`0 lines vs <base>` -- zero consumer-added lines).
#
# And it does not stop at noise: on a pull that DID carry real drift, the true rows would be
# indistinguishable from these. A poisoned signal is worse than a missing one.
#
# So both captures happen here, together, in the only state in which ours-vs-base means what
# the status name claims. Phases 1 and 2 consume what this phase measured.
#
# Phase 3's layer-drift.sh does NOT belong here and is not exposed to the same fault: its
# consumer-side reads are layer_files() (`:110`), which walks consumer-authored *.md under
# overrides/ and extensions/ -- files phase 1 never overwrites, README.md explicitly excluded
# -- and every core-side comparison resolves through `git -C "$DIST" show`, never the
# installed file. Leaving its call where it is keeps that visible.
PC="$(bash "$SELF/preclassify.sh" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" 2>/dev/null || true)"
UD="$(bash "$SELF/unregistered-drift.sh" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null | awk -F'\t' '$1=="HARD-UNREGISTERED-CORE-DRIFT"{print $2}')"

# A FIXTURE IS A TEST OF CORE, so it must never be written before the thing it tests.
# preclassify emits in path order, which puts core/fixtures/ FIRST -- 13 of the 25 paths in
# the 0.156.0 -> 0.162.0 range -- so the default order is exactly backwards. Partition the
# rows, stably, and drive the fixtures last. This does not make the window safe on its own
# (the reverse direction still breaks old assertions, which is what the in-flight marker is
# for); it makes the END state ordering correct, and it means an apply interrupted during
# the fixture batch leaves every subject already in place, so the fixtures that did land
# pass rather than fail.
PC="$(printf '%s\n' "$PC" | awk -F'\t' '
  $2 ~ /^core\/fixtures\//  { fx = fx $0 "\n"; next }
                            { print }
  END                       { printf "%s", fx }
')"

# ---------------------------------------------------------------- 1. buckets (preclassify)
while IFS="$(printf '\t')" read -r kind path cons bucket; do
  [ -n "${bucket:-}" ] || continue
  rel="${path#core/}"
  case "$bucket" in
    UPSTREAM-ONLY|UPSTREAM-ONLY-ADD)
      overwrite_from_theirs "$rel" && say RESOLVED pure-apply "$rel" \
        || { say DECISION unmapped-path "$rel" "no consumer path mapping"; mech_fail=$((mech_fail+1)); } ;;
    *SETUP-TOKENS*)
      # A NEW role file no longer needs a model fill. Until v0.174.0 this block guessed
      # `{gate_adjudicator_model_*}` from the consumer's adversary role and
      # `{dev_escalated_model_*}` from protected-path-editor — nearest-equivalent roles on
      # the same tier — because a role arriving with an unfilled model token would dispatch
      # against a literal `{token}`, and there was no other source for it. Role files now
      # state neither a model nor an effort — `aiDlcRoles` in the consumer's
      # settings.json does, so a new role arrives already resolvable
      # and the guess has nothing left to guess. The hazard is gone rather than relocated:
      # a key the consumer's block does not define is caught upstream by I22, and at
      # dispatch the guard fails open rather than binding a literal.
      if overwrite_from_theirs "$rel"; then
        cons="$(consumer_path "$rel")"
        # Residual NON-model setup tokens ({ownership_paths}, {deploy_command}, ...) are
        # filled by ai-dlc-setup, not here; they are expected to survive an apply.
        say RESOLVED token-substitute "$rel"
      else
        say DECISION unmapped-path "$rel" "no consumer path mapping"; mech_fail=$((mech_fail+1))
      fi ;;
    *CLASSIFY*)
      # A semantic merge is not done when the text reconciles -- it is done when the
      # merged file still WORKS. retired-tokens.sh names the one way that can fail
      # invisibly: consumer-only code inside this file still referencing a contract
      # upstream retired. Carried on the worklist item itself so the obligation
      # arrives with the work, not in a report section that can be skimmed.
      rt="$(bash "$SELF/retired-tokens.sh" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" "$path" 2>/dev/null \
            | awk -F'\t' '{print $3}' | paste -sd' ' -)"
      if [ -n "${rt:-}" ]; then
        say WORKLIST semantic-merge "$rel" "MUST ALSO re-point retired contract token(s): ${rt} — re-run retired-tokens.sh after merging; a non-empty result means the merge is NOT complete"
      else
        say WORKLIST semantic-merge "$rel"
      fi ;;
    UPSTREAM-DELETED|ORPHANED-RELOCATED*)
      say DECISION deletion "$rel" "apply would remove a consumer file — gated" ;;
    RELOCATE-MOVE*)
      # Report-only. The level-triggered manifest_dests loop (section below) owns the
      # actual move: it places THEIRS at scripts/ai-dlc/ and empties the old path. A
      # +consumer-edited row is the report's disclosure that a moved copy carried a
      # local edit — overwrite-on-pull, not a decision — so it must NOT become a
      # semantic-merge worklist item here (which is what the old consumer-deleted
      # ->CLASSIFY verdict produced: a fake merge task beside a real move). No action. ;;
      : ;;
    ALREADY-AT-THEIRS|ALREADY-PRESENT|*NOOP|DIST-ONLY-SKIP) : ;;
    *) say DECISION unhandled-bucket "$rel" "$bucket"; mech_fail=$((mech_fail+1)) ;;
  esac
done <<EOF
$PC
EOF

# THE DRIVER REPLACED ITSELF, AND THE OPERATOR IS TOLD SO RATHER THAN LEFT TO INFER IT.
# The rename above makes this SAFE -- the run finishes on the version that was invoked -- but
# it does not make it invisible, and the difference matters: every row below this point was
# produced by the OLD driver, so a range that changed how apply.sh classifies or orders work
# was adjudicated by the pre-range rules. Re-running is cheap and idempotent (every pure-apply
# file already equals THEIRS, so a second run has nothing to place) and is the only way to see
# the new driver's own reading of the same range.
#
# Not a DECISION row: nothing is owed. The re-stamp below is still correct either way, because
# it asserts the TREE is at THEIRS, which it is.
if [ "$self_replaced" -eq 1 ]; then
  say RESOLVED driver-self-update "${SELF_FILE#"$CONSUMER"/}" \
    "this range updates apply.sh itself; the new copy is in place and this run continued on the version you invoked. Rows below were produced by the previous driver. Re-run it to see the new one's reading of the same range — it is idempotent."
fi

# ---------------------------------------------------------------- 2. drift refile (known patterns)
# provenance-block.json known_skills: the consumer added skill names in place. Refile them to the
# sanctioned extension point (extensions/known-skills.json) and revert the schema to theirs.
#
# UD was captured in phase 0, before phase 1 wrote anything. Do NOT recompute it here: at this
# point every pure-apply file already equals THEIRS, so a fresh run reports the driver's own
# writes as consumer drift. See phase 0.
while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  cons="$(consumer_path "$rel")" || { say DECISION drift "$rel" "no consumer path mapping"; mech_fail=$((mech_fail+1)); continue; }
  case "$rel" in
    schemas/provenance-block.json)
      added="$(diff <(git -C "$DIST" show "${THEIRS}:core/${rel}" 2>/dev/null) "$cons" 2>/dev/null \
               | sed -n 's/^> *//p' | grep -oE '"[^"]+"' | tr -d '"' | grep -v '^known_skills$' | sort -u)"
      if [ -n "$added" ]; then
        ext="$CONSUMER/.claude/skills/ai-dlc/extensions/known-skills.json"
        mkdir -p "$(dirname "$ext")"
        python3 - "$ext" $added <<'PY'
import json, os, sys
path = sys.argv[1]; new = sys.argv[2:]
cur = []
if os.path.isfile(path):
    try:
        d = json.load(open(path)); cur = d.get("known_skills", d) if isinstance(d, dict) else d
    except Exception: cur = []
merged = list(dict.fromkeys([str(x) for x in cur] + new))
open(path, "w").write(json.dumps({"known_skills": merged}, indent=2) + "\n")
PY
        # Through the helper, not a second redirect. This one is not the self-overwrite case --
        # provenance-block.json is data, not the running script -- but it carried the other half
        # of the same defect: `>` truncates before `git show` runs, so a failed show replaced the
        # consumer's schema with an EMPTY file. One writer, one set of guarantees.
        overwrite_from_theirs "$rel" || { say DECISION drift "$rel" "could not place theirs"; mech_fail=$((mech_fail+1)); continue; }
        say RESOLVED drift-refile "$rel" "-> extensions/known-skills.json ($(echo $added | tr '\n' ' '))"
      else
        say DECISION drift "$rel" "in-place schema edit is not an additive known_skills entry — refile-vs-revert"
      fi ;;
    *)
      say DECISION drift "$rel" "in-place core edit with no known refile pattern — refile-as-override or revert" ;;
  esac
done <<EOF
$UD
EOF

# ---------------------------------------------------------------- 3. override readopt (hand to LLM)
LD_OUT="$(bash "$SELF/layer-drift.sh" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" 2>/dev/null)"
LD_HARD="$(printf '%s\n' "$LD_OUT" | awk -F'\t' '$1=="HARD-OVERRIDE-DRIFT-SECTION"{print $2}')"
while IFS= read -r ovr; do
  [ -n "$ovr" ] || continue
  say WORKLIST override-readopt "$ovr" "merge the moved core section into the override body, then readopt-override.sh --stamp readopt"
done <<EOF
$LD_HARD
EOF

# A SUPERSEDED override is RETIRED, not re-adopted. Emitted separately from the readopt
# list above because an entry can be both -- the section moved AND core now provides the
# affordance the entry was written to supply -- and in that case the readopt is work whose
# result is an entry that still freezes its shadowed span. Each loop carries its own
# heredoc: sharing one silently leaves the other reading stdin, which parses fine.
TAB_CH="$(printf '\t')"

LD_SUP="$(printf '%s\n' "$LD_OUT" | awk -F'\t' '$1=="OVERRIDE-SUPERSEDED"{print $2 "\t" $4}')"
# THE ROW TOKEN IS RESOLVED FROM ITS ONE HOME, NEVER RESTATED HERE, AND ONLY WHEN THERE IS
# A ROW TO APPLY IT TO. layer-drift.sh declares it beside the only code that writes it; this
# file reads that declaration. A literal copy is a second thing to keep in step, and the
# failure mode is silent: a token that drifts leaves the case arm below matching nothing,
# which reads exactly like a pull with no adjudicated rows in it.
#
# GATED ON A NON-EMPTY $LD_SUP, and that scoping is not cosmetic. An earlier draft resolved
# the token unconditionally and FAILED CLOSED when it could not — which is right in
# principle and wrong here: apply-self-overwrite deliberately drives a LONE COPY of this
# script in a scratch directory with no sibling beside it, so the guard aborted a run that
# had no supersession rows to get wrong, and took an unrelated fixture's unmutated control
# down with it. No rows means no decision to contradict. When there ARE rows, an
# unresolvable token means this script cannot tell a decided one from an undecided one, and
# the safe answer there is still to stop rather than guess in either direction.
# TWO ROW CLASSES CARRY THE TOKEN NOW, so the gate asks about both. `EXTENSION-HOOK-DRIFT` joined
# `OVERRIDE-SUPERSEDED` when a recorded verdict stopped clearing only the retire sequence and
# started clearing the re-read worklist too; gating on `$LD_SUP` alone would leave the token unset
# on a run whose only adjudicated rows are extensions — and under `set -u` that is not a silent
# miss, it is a crash in the loop that reads it.
LD_HOOK="$(printf '%s\n' "$LD_OUT" | awk -F'\t' -v OFS='\t' '$1=="EXTENSION-HOOK-DRIFT"{print $2, $4}')"
if [ -n "$LD_SUP" ] || [ -n "$LD_HOOK" ]; then
  ADJ_ROW_TOKEN="$(sed -n 's/^ADJ_ROW_TOKEN="\([A-Za-z_][A-Za-z0-9_-]*\)".*/\1/p' "$SELF/layer-drift.sh" 2>/dev/null | head -1)"
  if [ -z "$ADJ_ROW_TOKEN" ]; then
    echo "apply.sh: FATAL — OVERRIDE-SUPERSEDED or EXTENSION-HOOK-DRIFT row(s) present and ADJ_ROW_TOKEN could not be resolved from $SELF/layer-drift.sh." >&2
    echo "  Without it this script cannot tell an ALREADY-ADJUDICATED row from an undecided one," >&2
    echo "  and would emit retire steps or a re-read worklist over a recorded verdict (PC-S327)." >&2
    exit 2
  fi
fi

while IFS="$TAB_CH" read -r ovr detail; do
  [ -n "$ovr" ] || continue

  # A ROW THE PROJECT HAS ALREADY DECIDED IS NOT A WORKLIST ITEM.
  #
  # THIS SCRIPT HAD NO READER FOR THE ADJUDICATION REGISTER AT ALL, and layer-drift.sh --
  # which does -- correctly emitted NO blocking row for an entry carrying a recorded
  # `still-additive`. So the two tools disagreed: the gate said "decided, proceed" and this
  # manifest said "delete it", in a list the operator is told to work top-down. Measured on
  # the reference consumer: 0 mentions of the register here against 2 in layer-drift.sh,
  # and the prescribed step 2/2 would have removed a live stale-header closure guard and a
  # ceiling delegation -- 119 consumer-only lines -- that the recorded verdict exists to
  # keep. Filed by that consumer as PC-S327.
  #
  # THE VERDICT IS NOT RE-DERIVED HERE. layer-drift.sh computes it, digest-keyed, and says
  # so in the row; a second register reader in this file is a second thing to keep in step
  # with the schema. Because the digest covers the entry AND the core file it hooks at
  # theirs, a SPENT verdict cannot suppress anything -- the token is simply absent and the
  # sequence below is emitted as before. That is what keeps this from becoming a permanent
  # exemption for a path.
  case "$detail" in
    "$ADJ_ROW_TOKEN"=*)
      adj_v="${detail#"$ADJ_ROW_TOKEN"=}"; adj_v="${adj_v%% ::*}"
      say NOTE override-adjudicated "$ovr" "core superseded a shadowed anchor here, and this project has ALREADY RECORDED a verdict of '${adj_v}' for this exact subject in the layer adjudication register. No retire steps are emitted: acting on them would undo a decision, not complete one. The row is reported so the supersession stays visible. If you want to revisit it, change the register entry -- and note the verdict is digest-keyed, so it lapses on its own the next time either this entry or the core file it hooks moves."
      continue ;;
  esac
  # ORDERED AND ATOMIC, AS ROWS RATHER THAN AS PROSE.
  #
  # Retiring a superseded override is two writes that MUST land together, and the order is
  # not a preference. The override is what widens some core constraint; deleting it while
  # the replacement configuration is unwritten re-imposes the narrow core rule on a consumer
  # whose artifacts already violate it, and the next gate fails on a tree the operator just
  # "fixed". The reverse order is safe, so the reverse order is the one emitted.
  #
  # This was previously carried as a sentence in a human-written report, which is to say it
  # was carried by whoever happened to reason it out that pull. A constraint that only exists
  # when someone notices it is not a constraint. Each step is its own row so the sequence is
  # data the step-7 worker reads in order, and `ATOMIC` says they share one commit.
  # THE TOKENS ARE AN ORDERED PREFIX, SO THEY ARE PARSED POSITIONALLY.
  #
  # This read `env_key` unconditionally and nulled it only when the result equalled the whole
  # detail -- a guard that fires when the detail contains no ` ::` AT ALL, not when it lacks the
  # `replaces_with=` prefix. Latent while `replaces_with=` was the only token: the env-less
  # detail carried no ` ::` and the equality caught it. `retire_anchor=` makes it live, and an
  # env-less multi-anchor detail would otherwise yield `env_key=retire_anchor=<anchor>` and hand
  # the operator "write retire_anchor=steps/retro.md#4a. Close-Out Sweep into settings.json".
  # A `case` on the prefix is what the guard was always trying to say.
  env_key=""
  case "$detail" in
    replaces_with=*) env_key="${detail#replaces_with=}"; env_key="${env_key%% ::*}" ;;
  esac

  # `retire_anchor=` — THE LAST ROW IS NOT ALWAYS `--stamp retire`, AND GETTING THAT WRONG
  # DESTROYS CONSUMER TEXT. That stamp deletes the whole override file; there is no per-anchor
  # retire. When core supersedes ONE anchor of a multi-anchor `shadows:`, obeying a retire row
  # throws away the anchors core did NOT supersede, and every section they shadowed silently
  # reverts to core. layer-drift.sh emits this token on exactly that case and omits it otherwise,
  # so the single-anchor sequence below is byte-for-byte what it always was.
  det_rest="$detail"
  [ -n "$env_key" ] && det_rest="${det_rest#*" :: "}"
  drop_anchor=""
  case "$det_rest" in
    retire_anchor=*) drop_anchor="${det_rest#retire_anchor=}"; drop_anchor="${drop_anchor%% ::*}" ;;
  esac
  if [ -n "$drop_anchor" ]; then
    last_act="remove the anchor \`${drop_anchor}\` from ${ovr}'s shadows: and leave its other anchors byte-untouched. NOT --stamp retire: that deletes the whole file, and core superseded only this one anchor."
  else
    last_act="readopt-override.sh --stamp retire ${ovr}."
  fi

  if [ -n "$env_key" ]; then
    # N keys, N+1 rows. The count is derived from the field rather than fixed at two,
    # because a supersession needing a second key could not be expressed at all until
    # `settings_env_keys:` existed, and hardcoding `1/2` here would have made the list
    # form render a sequence whose own numbering lied about its length.
    #
    # THE RETIRE STAMP IS ALWAYS LAST, AND THAT ORDER IS THE WHOLE POINT OF `ATOMIC`.
    # Stamping first re-imposes the core constraint this entry was widening, with the
    # keys that replace it not yet written, and reds the next gate.
    key_total=$(( $(printf '%s' "$env_key" | tr ',' '\n' | grep -c .) + 1 ))
    key_n=0
    # `<<<`, NOT `printf | while read`, AND THE DIFFERENCE IS EVERY KEY ROW.
    #
    # `printf '%s'` writes NO trailing newline, so the final element reaches `read` at EOF:
    # `read` assigns it and returns NON-ZERO, and the loop body never runs on it. N keys emitted
    # N-1 rows -- and the one-key case, which is every supersession core has ever declared with a
    # key, emitted ZERO. So the sequence printed only its LAST step, `2/2 ATOMIC ... --stamp
    # retire`, while its own numbering announced a step 1/2 that had never been printed. The
    # operator was handed the retire and not the write, which is precisely the order this block
    # exists to forbid: retire first re-imposes the core constraint and reds the next gate.
    #
    # `key_total` was RIGHT throughout, because `grep -c` counts a final unterminated line. That
    # is why the numbering could keep advertising a row nobody emitted.
    #
    # A here-string appends the newline the last element needs, and it also drops the subshell
    # the pipeline created -- so `key_n` now survives the loop instead of being reset per run.
    while IFS= read -r one_key; do
      [ -n "$one_key" ] || continue
      key_n=$(( key_n + 1 ))
      say WORKLIST override-retire "$ovr" "${key_n}/${key_total} ATOMIC — write ${one_key} into .claude/settings.json \"env\" (derive its value per override_supersessions in layer-contract.yaml; do NOT copy the example). Doing the retire stamp first re-imposes the core constraint this entry was widening and reds the next gate."
    done <<< "$(printf '%s' "$env_key" | tr ',' '\n')"
    say WORKLIST override-retire "$ovr" "${key_total}/${key_total} ATOMIC — ${last_act} Same commit as the row(s) above."
  elif [ -n "$drop_anchor" ]; then
    # No key to write, so there is no ordering to enforce and no ATOMIC sequence — but the action
    # still is not a retire, and the single row has to SAY so rather than repeat the detail and
    # leave the operator to notice the difference between "delete this entry" and "delete one of
    # its anchors".
    say WORKLIST override-retire "$ovr" "core supersedes ONE anchor of this entry: ${last_act} Full reason: $detail"
  else
    say WORKLIST override-retire "$ovr" "core supersedes this entry: $detail"
  fi
done <<EOF
$LD_SUP
EOF

# EXTENSION-HOOK-DRIFT is NOT `HARD-`, and correctly so: an extension has no section anchor
# (`hooks:` is file-grain), so nothing can prove the entry is now wrong and blocking the pull
# on a suspicion would be a false gate. But "not blocking" was implemented as "not emitted",
# and the obligation SKILL.md states at the detector -- re-read the entry against the new core
# text -- named no actor and no deadline. It reached the report's layer-drift list and was
# carried as a follow-up, twice running on the reference consumer.
#
# A WORKLIST row is the weakest thing that still has an owner: the caller must dispose of it
# before the run is done, exactly like a semantic merge, and `apply` is not "clean" while one
# is outstanding. That is the difference between an instruction and a work item.
# AND A RECORDED VERDICT CLOSES IT, exactly as it does for the override retire-sequence above.
# `EXTENSION-HOOK-DRIFT` is an ADJUDICATED code, so a verdict clears its `HARD-` block — but this
# loop kept only the entry path and DISCARDED the detail field the token rides in, so there was
# nothing to test and every fully-adjudicated run still produced a work item. `apply` is not clean
# while a WORKLIST row is outstanding, and the only way to close this one was a second register row
# under a digest that already had one, which is `HARD-REGISTER-CONTRADICTION` the moment the
# verdicts differ. Filed by the reference consumer as
# `PC-S331` (apply.sh's extension re-read ignoring a recorded verdict), from a run that emitted the
# adjudicated `NOTE` and the unconditional `WORKLIST` together.
# `LD_HOOK` is computed with the token gate above, because that gate has to know whether this class
# is present before this loop runs.
while IFS="$TAB_CH" read -r ext detail; do
  [ -n "$ext" ] || continue
  case "$detail" in
    "$ADJ_ROW_TOKEN"=*)
      adj_v="${detail#"$ADJ_ROW_TOKEN"=}"; adj_v="${adj_v%% ::*}"
      say NOTE extension-adjudicated "$ext" "this entry's hooked core file changed, and this project has ALREADY RECORDED a verdict of '${adj_v}' for this exact subject in the layer adjudication register. No re-read is prescribed: the reading has been done. The row is reported so the drift stays visible. The verdict is digest-keyed over this entry AND the core file it hooks, so it lapses on its own the next time either moves."
      ;;
    *)
      say WORKLIST extension-reread "$ext" "hooked core file changed; re-read this entry against the new core text and record a verdict (still-additive / contradicts-core / retire)"
      ;;
  esac
done <<EOF
$LD_HOOK
EOF

# EXTENSION-TITLE-MATCHES-CORE gets a row for the reason the block above records: a status
# that reaches only the REPORT is an instruction, and an instruction names no actor and no
# deadline. This one has a narrower disposition than a re-read — the entry's heading names a
# core section, so either core carries the body and the entry retires, or it augments the
# section and says so in `extends:` — and either answer ends the row. Left in the report
# alone it would be carried as a follow-up, which is what happened to EXTENSION-HOOK-DRIFT
# twice running on the reference consumer before it was given a row.
#
# Not `HARD-`, and not an adjudication duty either: the candidate set is mechanized but the
# verdict needs the BODY read, and 12 blocking rows on first contact is how a check gets
# turned off. It ships as work with an owner, and promotion to the register is a later
# release's decision once this set has been burned down.
LD_TITLE="$(printf '%s\n' "$LD_OUT" | awk -F'\t' '$1=="EXTENSION-TITLE-MATCHES-CORE"{print $2 "\t" $4}')"
while IFS="$TAB_CH" read -r ext tdetail; do
  [ -n "$ext" ] || continue
  say WORKLIST extension-title-match "$ext" "$tdetail"
done <<EOF
$LD_TITLE
EOF

# ---------------------------------------------------------------- 4. catalog relabel (mechanical)
#
# THE EXIT STATUS CANNOT TELL WORK FROM NO WORK, AND THIS IS A ROW STEP 7 TELLS THE READER TO
# TRUST. `relabel-extension-checks.sh` exits 0 three separate ways: it labelled n headings, it
# found nothing to label, or the consumer has no `extensions/` directory at all. Guarding on the
# invocation's status, with its output discarded, therefore printed
# `RESOLVED relabel ext-check collisions labelled` on a tree whose catalog was never colliding.
# Filed by the reference consumer as PC-S332 and measured on its own 0.345.0 -> 0.347.0 apply,
# where the tool said `no unlabelled core-number collisions.` and the manifest said the
# collisions had been labelled.
#
# Why the row matters more than the miscount: step 7 says "Do NOT re-do a `RESOLVED` row by
# hand". A row asserting an action that did not occur reads as "your catalog was colliding and I
# fixed it" to a reader who is instructed not to check. That is the same vacuous-pass shape this
# file already refuses for the reconcile log, whose fixture states the rule outright -- a receipt
# for an unwritten artifact is worse than silence.
#
# So read the COUNT the tool already prints, and say nothing when there was nothing to do. Parsed
# with parameter expansion rather than a pipeline: feeding a variable into a reader is the I54b
# shape, and this value decides whether a manifest row exists.
relabel_out="$(bash "$SELF/relabel-extension-checks.sh" "$CONSUMER" --apply --dist "$DIST" --theirs "$THEIRS" 2>/dev/null || true)"
relabel_n=""
case "$relabel_out" in
  *"relabel-extension-checks: labelled "*)
    relabel_n="${relabel_out##*relabel-extension-checks: labelled }"
    relabel_n="${relabel_n%% *}"
    ;;
esac
case "$relabel_n" in ''|*[!0-9]*) relabel_n=0 ;; esac
if [ "$relabel_n" -gt 0 ]; then
  # The subject is the count, because every other RESOLVED arm in this file names its subject --
  # `restamp` carries `<base> -> <sha>`, `relocate-move` leads with `${legacy_moved_n}`. `relabel`
  # and `consistent` were the only two bare rows, and a bare row is the one a reader cannot
  # sanity-check against their own tree.
  say RESOLVED relabel "${relabel_n} colliding heading(s)" "labelled with their \`[ext:<id>]\` tag so the consumer's extension checks no longer collide with core's numbering."
fi

# ---------------------------------------------------------------- 5. re-stamp
#
# The stamp asserts "this tree is at THEIRS". It used to be written unconditionally, so a
# pull that silently failed to place a file still ended with a record claiming the new
# version -- the same shape as the v0.70.1 exec-bit defect, where every content check
# reported green over a file that could not run. A record that cannot be wrong about the
# thing it records is worthless.
#
# Withholding is the safe direction: the stamp stays at BASE, so the next pull simply
# re-applies from BASE. Overwriting an unchanged file twice costs nothing; believing a
# -----------------------------------------------------------------------------
# LEGACY SCRIPT LOCATION (pre-0.126.0). Core validators used to be installed loose
# in scripts/; they now live in scripts/ai-dlc/. This driver places the new copies
# and NEVER deletes the old ones -- but silence here would be worse than the mess.
#
# The move made the old path INVISIBLE to every detector at once, and that is the
# reason this block exists rather than a line in the changelog:
#
#   - map_consumer() now sends core/scripts/X to scripts/ai-dlc/X. On a consumer
#     that has not moved yet, that path does not exist, so the file classifies as a
#     clean ADD. The copy at scripts/X is no longer compared against anything.
#   - unregistered-drift.sh deliberately excludes scripts/ ("an edit breaks LOUDLY,
#     not silently"). That premise was already thin -- the reference consumer had a
#     validator 160 lines diverged from upstream, silently, until it was diffed by
#     hand -- and after the move nothing scans the old path at all.
#
# Before the move, an edited scripts/X surfaced as a BOTH-CHANGED conflict. Losing
# that without replacing it would turn a real local change into an orphan: not
# clobbered, just never mentioned again. So the check moves here, where the mapping
# already lives.
#
# REPORTS, NEVER DELETES. A difference is a local edit -- the very thing the new
# boundary exists to prevent -- and it belongs upstream as a push candidate, not in
# the bin. An operator who has read the diff can remove them in one command.
# LEVEL-TRIGGERED, for the same reason the orphan pass in preclassify.sh is: a
# relocation is a STATE of the consumer tree, not an event in upstream history.
#
# This matters more here than anywhere else, because preclassify enumerates
# `git diff --name-status BASE THEIRS -- core/` -- only files that CHANGED. On the
# 0.119.1 -> 0.126.0 pull just five of the twenty-five validators changed, so an
# event-driven migration would write five files into scripts/ai-dlc/ and leave the
# other twenty behind, while every core reference now points at the new directory.
# That is not a stale duplicate, it is a pipeline that breaks at the first gate
# calling a validator that was never written.
#
# It cannot use preclassify's RELOCATIONS table either. Every prefix in that table
# (.claude/fixtures, .claude/ci-templates, .claude/git-hooks) is a directory that is
# exclusively ours, so it can `find` the whole tree. scripts/ is SHARED -- 103 files
# in the reference consumer, 78 of them theirs -- so the same walk would indict their
# tooling and would descend into scripts/ai-dlc/ and call our own new copies orphans.
#
# THE MANIFEST IS THE DECLARATION -- of the directory AND of where it goes. Git
# supplies the membership.
#
# The manifest used to spell out all 27 validators, and this loop iterated the names.
# v0.160.0 replaced them with `scripts/ai-dlc/*`, so a glob entry is expanded against
# THEIRS' tree to get its members. That is still ONE declaration of the path: the
# entry states which directory is ours and where it goes, and `ls-tree` answers only
# "what is in it at THEIRS". The rejected alternative was to take the destination from
# map_consumer()'s prefix rule as well -- THAT would be a second statement of a path,
# and the two would drift the first time a relocation was half-applied.
#
# Reading a glob entry LITERALLY is the failure this shape exists to prevent: `base`
# becomes `*`, every cat-file probe misses, the loop runs zero times, and manifest_n
# is 1 -- so the silent-zero guard below does not fire and the pull relocates nothing
# while still re-stamping. core/fixtures/apply-legacy-script-path/ case 7 drives the
# shipped glob form for exactly that reason; cases 1-6 write enumerated stand-ins and
# cannot see it.
#
# setup-sites.md, not core-manifest.md: this skill's HARD CONSTRAINT is that it reads
# only its own reconcile/ files, which is exactly why that duplicate copy exists. I5
# binds the two copies, so reading either yields the same declaration.
#
# map_consumer() deliberately stays a prefix mapper and is NOT rewritten to consult
# this list. It must map ARBITRARY core paths -- including `core/scripts/PROBE`, which
# I8 synthesises to test the mapping and which no manifest will ever contain. A lookup
# table cannot answer for a path that does not exist yet; a prefix rule can.
manifest_dests() { # -> consumer-relative destinations declared under scripts/ai-dlc/
  awk '
    /^core_manifest:/ {f=1; next}
    f && /^[ \t]*-[ \t]+/ { v=$0; sub(/^[ \t]*-[ \t]+/,"",v); sub(/[ \t]+$/,"",v); print v; next }
    f && /^[^ \t]/ { f=0 }
  ' "$SELF/setup-sites.md" 2>/dev/null | sed -e 's#^core/##' -e '/^scripts\/ai-dlc\//!d' \
  | while IFS= read -r decl; do
      case "$decl" in
        # A glob entry names the directory; its members come from THEIRS' tree.
        scripts/ai-dlc/\*)
          git -C "$DIST" ls-tree --name-only "$THEIRS" -- core/scripts/ 2>/dev/null \
            | sed -n 's#^core/scripts/#scripts/ai-dlc/#p' ;;
        # A literal entry passes through, so a future single-file entry still works.
        *) printf '%s\n' "$decl" ;;
      esac
    done
}

legacy_moved=""
legacy_moved_n=0
manifest_n=0
for dest in $(manifest_dests); do
  manifest_n=$((manifest_n+1))
  base="${dest#scripts/ai-dlc/}"
  old="$CONSUMER/scripts/$base"
  new="$CONSUMER/$dest"

  # Belt and braces. Under the glob entry the member list came from `ls-tree $THEIRS`,
  # so a file reported there cannot be absent from THEIRS. The probe still runs because
  # a LITERAL entry is passed through unexpanded, and a literal naming a file THEIRS
  # does not ship is a distribution inconsistency. Treating that as a mechanical failure
  # HERE would block a pull over a defect the consumer cannot fix and did not cause.
  git -C "$DIST" cat-file -e "${THEIRS}:core/scripts/${base}" 2>/dev/null || continue

  # 1. Place it if the changed-files pass did not. Never overwrite: a file already
  #    at the new path was written by that pass from this same THEIRS.
  if [ ! -f "$new" ]; then
    if overwrite_from_theirs "scripts/$base"; then
      say RESOLVED relocate "$dest" "placed at its declared location (unchanged in this range, so the changed-files pass did not carry it)"
    else
      say DECISION unmapped-path "scripts/$base" "declared at $dest but could not be placed"
      mech_fail=$((mech_fail+1))
    fi
  fi

  # 2. MOVE: the old path is emptied once the new one holds THEIRS' content. A
  #    leftover is not harmless -- it shadows nothing, nothing refreshes it, and it
  #    silently diverges from the file it is a copy of, which is the rot the pull
  #    exists to prevent.
  #
  #    A LOCAL EDIT IS OVERWRITTEN, NOT ADJUDICATED. Core is upstream-owned and
  #    overwrite-on-pull; validators are machinery with no consumer layer, exactly
  #    like hooks -- there is no overrides/ shadow and no extensions/ entry for one.
  #    So an edited copy at the old path is a boundary violation the new layout
  #    prevents, not a decision the operator owes an answer to. It gets the same
  #    treatment every other core file gets on every pull.
  #
  #    Nothing is lost that was not already recoverable: consumers are git
  #    repositories and these files were tracked. This step deliberately does NOT
  #    compare old against new first -- a differ/identical split would put a row in
  #    front of the operator implying a call to make, and there is none.
  [ -f "$old" ] || continue
  rm -f "$old"
  legacy_moved="${legacy_moved}${legacy_moved:+ }scripts/$base"
  legacy_moved_n=$((legacy_moved_n+1))
done

# A declaration that yields nothing is one this driver could not read, and a silent
# zero here relocates NOTHING while the run still re-stamps -- the stamp then claims a
# version whose validators are not where every core reference points. Same posture as
# install.sh refusing to install zero validators.
#
# The glob covers a second failure with the same guard: an unreadable manifest AND an
# empty `ls-tree` both arrive here as zero. Against the old enumeration this guard could
# not distinguish them, because a manifest read as one literal glob entry counted 1.
if [ "$manifest_n" -eq 0 ]; then
  say DECISION manifest-unreadable "reconcile/setup-sites.md" \
    "the core_manifest block yielded no scripts/ai-dlc/ destinations — either it is unreadable or THEIRS ships no core/scripts/ files. Refusing to treat that as 'nothing to relocate'."
  mech_fail=$((mech_fail+1))
fi

if [ "$legacy_moved_n" -gt 0 ]; then
  say RESOLVED relocate-move "$legacy_moved" \
    "${legacy_moved_n} core validator(s) removed from the pre-0.126.0 path; upstream's copy is at the declared location. Core is overwrite-on-pull and a validator has no consumer layer, so a local edit here is superseded like any other core file's."
fi

# -----------------------------------------------------------------------------
# THE DECLARED SET IS VERIFIED WHOLE, after every move.
#
# Not "what this run touched" -- every file the manifest declares, whether it was
# just relocated, placed by the changed-files pass, already correct, or never
# examined at all. A migration that half-lands is the failure mode here: the old
# path is now empty, so a validator missing from the new path is missing FULL STOP,
# and every core reference to it resolves to nothing.
#
# Presence AND mode, together, because they fail differently and both fail silently.
# An absent validator makes its call site error; a present non-executable one makes
# it error too, but v0.70.1 showed the second kind survives every content-diff
# verification looking green. Neither is visible without asking directly.
declared_bad=0
for dest in $(manifest_dests); do
  base="${dest#scripts/ai-dlc/}"
  git -C "$DIST" cat-file -e "${THEIRS}:core/scripts/${base}" 2>/dev/null || continue
  target="$CONSUMER/$dest"
  if [ ! -f "$target" ]; then
    say DECISION declared-missing "$dest" \
      "declared in the core manifest and shipped by THEIRS, but not present after apply. The pre-0.126.0 path is empty now, so every reference to this validator resolves to nothing."
    declared_bad=$((declared_bad+1))
    continue
  fi
  want="$(git -C "$DIST" ls-tree "$THEIRS" -- "core/scripts/${base}" 2>/dev/null | awk '{print $1}')"
  if [ "$want" = "100755" ] && [ ! -x "$target" ]; then
    say DECISION declared-not-executable "$dest" \
      "shipped 100755 upstream but not executable here — installed and inert. \`chmod +x\` and re-run."
    declared_bad=$((declared_bad+1))
  fi
done
[ "$declared_bad" -eq 0 ] || mech_fail=$((mech_fail + declared_bad))

# -----------------------------------------------------------------------------
# THE CONSUMER-OWNED CROSSWALK FILE IS SCAFFOLDED HERE, and the reason it has to be
# here is that `install.sh` is the only other writer of it and NO CONSUMER RUNS
# install.sh AGAIN. A pull is how an existing consumer receives everything; a
# create-once file introduced after that consumer installed therefore arrives
# through this driver or it never arrives at all.
#
# MEASURED ON THE REFERENCE CONSUMER, which is what put this block here. The
# release that moved the crosswalk table to a consumer-owned path shipped the
# installer arm and a fixture that drives it, and both were green. The pull that
# delivered it left the declared path EMPTY: the contract arrived declaring
# `consumer_crosswalk_file:`, the template arrived under `templates/`, the
# validator's W8 told the operator to move their rows to a file that did not
# exist, and nothing anywhere reported an absence. `install.sh` and this driver
# are different programs and only the first had been exercised.
#
# IT REFUSES RATHER THAN GUESSING, on both legs, and both legs are the
# distribution's fault rather than the consumer's — which is exactly why they must
# be loud here. A pull that silently declares a path it did not create hands the
# next migration a destination that is not there, and the failure surfaces as rows
# written into a file nothing reads. That is the state this whole mechanism
# replaced.
#
# The template's name is DERIVED from the declared path's basename rather than
# spelled: the declaration is the one string, and a second literal here would be
# the drift I67 exists to prevent.
# SCOPED TO A THEIRS THAT SHIPS A CONTRACT, and the scoping was measured rather than
# reasoned: without it `apply-drift-refile` and `apply-restamp-theirs` both went red. Their
# synthetic distributions ship no layer-contract.yaml at all, which is not a malformed
# declaration — it is a version from before the crosswalk mechanism existed, and a pull from
# one has nothing to scaffold. Refusing there would wedge every consumer updating across that
# boundary. The subject is a contract that is PRESENT and silent about the key, which is the
# only state this block can speak to — the same scoping, for the same reason, that
# validate-layer-entries.sh's own E16 arm carries.
CW_LC='core/skills/ai-dlc/layer-contract.yaml'
CW_REL="$(git -C "$DIST" show "${THEIRS}:${CW_LC}" 2>/dev/null \
  | sed -n 's/^consumer_crosswalk_file:[[:space:]]*//p' | head -1 | sed 's/[[:space:]]*$//')"
if ! git -C "$DIST" cat-file -e "${THEIRS}:${CW_LC}" 2>/dev/null; then
  : # THEIRS predates the layer contract; there is no declared crosswalk file to create.
elif [ -z "$CW_REL" ]; then
  say DECISION crosswalk-undeclared "core/skills/ai-dlc/layer-contract.yaml" \
    "THEIRS declares no 'consumer_crosswalk_file:', so this driver cannot know where the consumer's crosswalk table lives and will not guess. The validator reads that declaration too: without it LC-N6 and LC-R2 evaluate against a table nothing read, which is indistinguishable from an empty one."
  mech_fail=$((mech_fail+1))
elif [ ! -f "$CONSUMER/$CW_REL" ]; then
  cw_tpl="core/skills/ai-dlc/templates/$(basename "$CW_REL")"
  cw_tmp="$CONSUMER/$CW_REL.incoming.$$"
  mkdir -p "$(dirname "$CONSUMER/$CW_REL")" 2>/dev/null || true
  if git -C "$DIST" show "${THEIRS}:${cw_tpl}" > "$cw_tmp" 2>/dev/null && [ -s "$cw_tmp" ]; then
    mv "$cw_tmp" "$CONSUMER/$CW_REL"
    say RESOLVED crosswalk-scaffold "$CW_REL" \
      "created from ${cw_tpl}; the contract declares this path and nothing was there. It is YOURS from here — no pull writes to it again, and the branch above is why: this driver only ever creates it when absent."
  else
    rm -f "$cw_tmp"
    say DECISION crosswalk-template-missing "$cw_tpl" \
      "THEIRS declares '$CW_REL' but ships no template to scaffold it from, so the declared path would stay empty while the validator reports rows against it. Fix upstream and re-run; this is a distribution packaging defect and not something to work around here."
    mech_fail=$((mech_fail+1))
  fi
fi

# The machinery inventory, scaffolded on exactly the same terms as the crosswalk above and
# scoped the same way: silent when THEIRS predates the contract, a DECISION when the contract
# is present and silent about the key. v0.228.0 is why this block exists at all -- a
# create-once file scaffolded only by install.sh reaches no consumer that already installed.
MC_REL="$(git -C "$DIST" show "${THEIRS}:${CW_LC}" 2>/dev/null \
  | sed -n 's/^consumer_machinery_file:[[:space:]]*//p' | head -1 | sed 's/[[:space:]]*$//')"
if ! git -C "$DIST" cat-file -e "${THEIRS}:${CW_LC}" 2>/dev/null; then
  : # THEIRS predates the layer contract; nothing declared, nothing to scaffold.
elif [ -z "$MC_REL" ]; then
  : # THEIRS predates the machinery declaration specifically. Not a failure -- the key
    # arrived at contract version 13 and a consumer updating across that boundary has
    # nothing to create. E16's scoping lesson, applied before it could cost a release.
elif [ ! -f "$CONSUMER/$MC_REL" ]; then
  mc_tpl="core/skills/ai-dlc/templates/$(basename "$MC_REL")"
  mc_tmp="$CONSUMER/$MC_REL.incoming.$$"
  mkdir -p "$(dirname "$CONSUMER/$MC_REL")" 2>/dev/null || true
  if git -C "$DIST" show "${THEIRS}:${mc_tpl}" > "$mc_tmp" 2>/dev/null && [ -s "$mc_tmp" ]; then
    mv "$mc_tmp" "$CONSUMER/$MC_REL"
    say RESOLVED machinery-scaffold "$MC_REL" \
      "created from ${mc_tpl}; the contract declares this path and nothing was there. It is YOURS from here — no pull writes it again. Declare which of your scripts are ai-dlc machinery, or leave the literal 'none' if this project has none of its own."
  else
    rm -f "$mc_tmp"
    say DECISION machinery-template-missing "$mc_tpl" \
      "THEIRS declares '$MC_REL' but ships no template to scaffold it from, so the declared path would stay empty while the contract says it is the inventory's home."
    mech_fail=$((mech_fail+1))
  fi
fi

# The PR-class taxonomy the post-merge trunk audit reads, on the same terms and with the same
# scoping as the two blocks above.
PC_REL="$(git -C "$DIST" show "${THEIRS}:${CW_LC}" 2>/dev/null \
  | sed -n 's/^consumer_pr_class_file:[[:space:]]*//p' | head -1 | sed 's/[[:space:]]*$//')"
if ! git -C "$DIST" cat-file -e "${THEIRS}:${CW_LC}" 2>/dev/null; then
  : # THEIRS predates the layer contract; nothing declared, nothing to scaffold.
elif [ -z "$PC_REL" ]; then
  : # THEIRS predates the PR-class declaration specifically. The audit's own arm is silent
    # in that state too, so a consumer updating across the boundary is not wedged by either.
elif [ ! -f "$CONSUMER/$PC_REL" ]; then
  pc_tpl="core/skills/ai-dlc/templates/$(basename "$PC_REL")"
  pc_tmp="$CONSUMER/$PC_REL.incoming.$$"
  mkdir -p "$(dirname "$CONSUMER/$PC_REL")" 2>/dev/null || true
  if git -C "$DIST" show "${THEIRS}:${pc_tpl}" > "$pc_tmp" 2>/dev/null && [ -s "$pc_tmp" ]; then
    mv "$pc_tmp" "$CONSUMER/$PC_REL"
    say RESOLVED pr-class-scaffold "$PC_REL" \
      "created from ${pc_tpl}; the contract declares this path and nothing was there. It is YOURS from here — no pull writes it again. Declare your trunk's classes and the validators each owes, or leave the literal 'none': until you do, 'validate-cycle-commits.sh --audit-trunk' prints a worklist line and audits nothing."
  else
    rm -f "$pc_tmp"
    say DECISION pr-class-template-missing "$pc_tpl" \
      "THEIRS declares '$PC_REL' but ships no template to scaffold it from, so the declared path would stay empty while the trunk audit has nothing to resolve commits against."
    mech_fail=$((mech_fail+1))
  fi
fi

# The derivable story-field list `sprint-status.sh derive-stories` reads, on the same terms and
# with the same scoping as the three blocks above.
SF_REL="$(git -C "$DIST" show "${THEIRS}:${CW_LC}" 2>/dev/null \
  | sed -n 's/^consumer_story_fields_file:[[:space:]]*//p' | head -1 | sed 's/[[:space:]]*$//')"
if ! git -C "$DIST" cat-file -e "${THEIRS}:${CW_LC}" 2>/dev/null; then
  : # THEIRS predates the layer contract; nothing declared, nothing to scaffold.
elif [ -z "$SF_REL" ]; then
  : # THEIRS predates the story-field declaration specifically. The derive's own arm is silent
    # in that state too, so a consumer updating across the boundary is not wedged by either.
elif [ ! -f "$CONSUMER/$SF_REL" ]; then
  sf_tpl="core/skills/ai-dlc/templates/$(basename "$SF_REL")"
  sf_tmp="$CONSUMER/$SF_REL.incoming.$$"
  mkdir -p "$(dirname "$CONSUMER/$SF_REL")" 2>/dev/null || true
  if git -C "$DIST" show "${THEIRS}:${sf_tpl}" > "$sf_tmp" 2>/dev/null && [ -s "$sf_tmp" ]; then
    mv "$sf_tmp" "$CONSUMER/$SF_REL"
    say RESOLVED story-fields-scaffold "$SF_REL" \
      "created from ${sf_tpl}; the contract declares this path and nothing was there. It is YOURS from here — no pull writes it again. List the story-entry fields this project DERIVES from its story files, or leave the literal 'none': until you do, 'sprint-status.sh derive-stories' prints a worklist line and derives only \`status\`, which comes from the schema and is not declarable."
  else
    rm -f "$sf_tmp"
    say DECISION story-fields-template-missing "$sf_tpl" \
      "THEIRS declares '$SF_REL' but ships no template to scaffold it from, so the declared path would stay empty while the derive has nothing to read."
    mech_fail=$((mech_fail+1))
  fi
fi

# The artifact kinds and areas rule 4 of artifact-path-grammar.md reads, on the same terms and
# with the same scoping as the four blocks above.
AP_REL="$(git -C "$DIST" show "${THEIRS}:${CW_LC}" 2>/dev/null \
  | sed -n 's/^consumer_artifact_paths_file:[[:space:]]*//p' | head -1 | sed 's/[[:space:]]*$//')"
if ! git -C "$DIST" cat-file -e "${THEIRS}:${CW_LC}" 2>/dev/null; then
  : # THEIRS predates the layer contract; nothing declared, nothing to scaffold.
elif [ -z "$AP_REL" ]; then
  : # THEIRS predates the artifact-paths declaration specifically. Rule 4 is silent in that
    # state too, so a consumer updating across the boundary is not wedged by either.
elif [ ! -f "$CONSUMER/$AP_REL" ]; then
  ap_tpl="core/skills/ai-dlc/templates/$(basename "$AP_REL")"
  ap_tmp="$CONSUMER/$AP_REL.incoming.$$"
  mkdir -p "$(dirname "$CONSUMER/$AP_REL")" 2>/dev/null || true
  if git -C "$DIST" show "${THEIRS}:${ap_tpl}" > "$ap_tmp" 2>/dev/null && [ -s "$ap_tmp" ]; then
    mv "$ap_tmp" "$CONSUMER/$AP_REL"
    say RESOLVED artifact-paths-scaffold "$AP_REL" \
      "created from ${ap_tpl}; the contract declares this path and nothing was there. It is YOURS from here — no pull writes it again. Declare the artifact kinds and any extra area roots this project uses, or leave the literal 'none': until you do, rule 4 of artifact-path-grammar.md (kind comes from a declared closed set) has nothing to check against. The other four rules do not depend on it."
  else
    rm -f "$ap_tmp"
    say DECISION artifact-paths-template-missing "$ap_tpl" \
      "THEIRS declares '$AP_REL' but ships no template to scaffold it from, so the declared path would stay empty while the grammar says it is the kind set's home."
    mech_fail=$((mech_fail+1))
  fi
fi

# -----------------------------------------------------------------------------
# EXEC-BIT AUDIT. Every file upstream ships as 100755 must be executable in the
# consumer tree once this driver is done.
#
# sync_mode_from_theirs() already chmods each file it writes, and derives the bit
# from git's own tree rather than a hand-list. But it chmods with `|| true`, so a
# failure is silent -- and nothing anywhere asserted the RESULT. That is the exact
# shape of the v0.70.1 defect: `git show > file` is a shell redirect that takes the
# mode from the umask, the dispatch guard installed non-executable and INERT, and
# every content-diff verification reported green over a file that could not run.
# WIRED IS NOT CAN-RUN, and a content check cannot tell the difference.
#
# LEVEL, NOT EDGE. It audits the whole shipped set, not just what this run wrote:
# a file left non-executable by an EARLIER pull is still a validator that cannot
# run, and an event-driven audit would never look at it again.
#
# COUNTS AS A MECHANICAL FAILURE, so the re-stamp is withheld. A stamp asserting
# THEIRS over a tree whose validators cannot execute is precisely the claim v0.70.1
# showed is worse than no stamp: the next pull bases its merge on it.
# A command substitution, not a temp file: the scan runs in a subshell either way,
# but `$(...)` carries its output back to the parent without putting a channel file
# anywhere. The budget validator's scan channels had to be moved out of the project
# root in v0.118.2 for exactly that reason -- nothing gitignored them, and a killed
# run left litter a broad `git add -A` then committed.
NOEXEC="$(
  git -C "$DIST" ls-tree -r "$THEIRS" -- core/ 2>/dev/null \
    | awk '$1=="100755"{ sub(/^[^\t]*\t/,""); print }' \
    | while IFS= read -r cp; do
        rel="${cp#core/}"
        cons="$(consumer_path "$rel" 2>/dev/null)" || continue
        # Not every shipped file lands on every consumer (ci-templates only with
        # .github/, for one). Absent is a different finding, covered above.
        [ -f "$cons" ] || continue
        [ -x "$cons" ] && continue
        printf '%s\n' "$cons"
      done
)"

if [ -n "$NOEXEC" ]; then
  while IFS= read -r cons; do
    [ -n "$cons" ] || continue
    say DECISION not-executable "${cons#"$CONSUMER"/}" \
      "upstream ships this 100755 but the consumer copy is not executable — installed and inert. \`chmod +x\` it and re-run; every call site that invokes it directly fails until then."
    mech_fail=$((mech_fail+1))
  done <<EOF
$NOEXEC
EOF
fi

# version landed when it did not costs a silent divergence nobody looks for.
STAMP="$CONSUMER/.claude/.ai-dlc-version"
# BOTH PAIRS OR NEITHER. The skill pair is written inside the same branch as the rulebook pair,
# so a withheld re-stamp withholds it too. Advancing `skill_version` over a tree that is missing
# machinery files is the same false claim as advancing `version` over it -- and it is the worse
# half, because `unregistered-drift.sh` reads `skill_commit` as a suppression ref: a stamp
# naming a ref the tree does not match turns the NEXT pull's report into false drift work.
withheld_extra=""
if [ "$CARRIED_MACHINERY" = 1 ]; then
  withheld_extra=" This run carried step 2's deferred machinery slice, so \`skill_version\`/\`skill_commit\` are withheld with it — both pairs or neither."
fi
if [ "$mech_fail" -gt 0 ]; then
  say DECISION restamp-withheld "$STAMP" "${mech_fail} file(s) could not be placed mechanically — the stamp would claim ${THEIRS} while the tree lacks them. Left at ${BASE}; fix the paths above and re-run.${withheld_extra}"
elif [ -f "$STAMP" ]; then
  theirs_sha="$(git -C "$DIST" rev-parse --short "$THEIRS" 2>/dev/null || echo "$THEIRS")"
  # From THEIRS, not the working tree. Every file copy above resolves through
  # `git show "${THEIRS}:core/..."`; reading VERSION with `cat` was the one place that
  # trusted whatever ref the operator's distribution checkout happened to be sitting on.
  # Hit live on the v0.92.0 pull: the checkout was on a v0.93.0 branch while theirs was
  # origin/main at v0.92.0, so the stamp was written `version: 0.93.0` against 0.92.0
  # content — beside a `commit:` taken correctly from theirs, which is what makes the
  # result incoherent rather than merely stale. The stamp is the one field the NEXT pull
  # trusts to compute its base, so an overstating version silently mis-bases that merge.
  ver="$(git -C "$DIST" show "${THEIRS}:VERSION" 2>/dev/null || true)"
  sed -i.bak -E "s/^(commit:).*/\1 ${theirs_sha}/" "$STAMP" 2>/dev/null || true
  [ -n "$ver" ] && sed -i.bak -E "s/^(version:).*/\1 ${ver}/" "$STAMP" 2>/dev/null || true
  rm -f "$STAMP.bak"

  # THE DEFERRED-SLICE CASE. Only here does this run install machinery, so only here may the
  # stamp say the installed TOOL moved. The write is guarded three ways, because every one of
  # them is a way for it to report success and do nothing:
  #   - `ver` empty means VERSION was unreadable at theirs; write nothing and say so.
  #   - fields ABSENT (a stamp predating the v0.17.0 schema, or a partial one) cannot be
  #     rewritten by a `sed` keyed on them -- the substitution matches nothing and exits 0,
  #     which is indistinguishable from having written. So they are INSERTED, in schema order,
  #     immediately after `commit:`.
  #   - the result is READ BACK. A stamp with no `commit:` line at all leaves nowhere to insert,
  #     and that case must reach the operator as a row rather than as a silent preserve.
  # Written through `.incoming.$$` + `mv` rather than in place: the idiom this file already uses
  # at five sites, and v0.316.0's lesson about rewriting a file a running program is reading.
  if [ "$CARRIED_MACHINERY" = 1 ]; then
    if [ -z "$ver" ]; then
      say DECISION skill-restamp-withheld "$STAMP" "this run carried the deferred machinery slice, but VERSION could not be read at ${THEIRS}, so \`skill_version\` has no value to take. \`skill_commit\` is left with it — half a machinery stamp is a stamp nothing can trust. Set both by hand to theirs, or re-run against a resolvable ref."
    else
      if grep -q '^skill_version:' "$STAMP" && grep -q '^skill_commit:' "$STAMP"; then
        sed -i.bak -E "s/^(skill_version:).*/\1 ${ver}/; s/^(skill_commit:).*/\1 ${theirs_sha}/" "$STAMP" 2>/dev/null || true
        rm -f "$STAMP.bak"
      else
        awk -v v="$ver" -v s="$theirs_sha" '
          $0 !~ /^skill_version:/ && $0 !~ /^skill_commit:/ { print }
          /^commit:/ && !ins { print "skill_version: " v; print "skill_commit: " s; ins=1 }
        ' "$STAMP" > "$STAMP.incoming.$$" 2>/dev/null && mv -f "$STAMP.incoming.$$" "$STAMP"
        rm -f "$STAMP.incoming.$$"
      fi
      got_sv="$(sed -n 's/^skill_version:[[:space:]]*//p' "$STAMP" | head -1)"
      got_sc="$(sed -n 's/^skill_commit:[[:space:]]*//p' "$STAMP" | head -1)"
      if [ "$got_sv" = "$ver" ] && [ "$got_sc" = "$theirs_sha" ]; then
        say RESOLVED restamp-machinery "$BASE -> $theirs_sha" "step 2 deferred its self-update and this apply carried the machinery slice, so \`skill_version\`/\`skill_commit\` advance to ${ver} @ ${theirs_sha} with the rulebook pair. Without this the next pull reads every machinery file this run wrote as consumer drift."
      else
        say DECISION skill-restamp-failed "$STAMP" "this run carried the deferred machinery slice, but the stamp still reads \`skill_version: ${got_sv:-<absent>}\` / \`skill_commit: ${got_sc:-<absent>}\` rather than ${ver} @ ${theirs_sha}. The stamp has no \`commit:\` line to write beside — a legacy single-line stamp. Rewrite it in schema (version/commit/skill_version/skill_commit/installed_at/upstream) and re-run."
      fi
    fi
  fi

  # READ THE STAMP BACK, FOR THE REASON THE MACHINERY ARM DIRECTLY ABOVE ALREADY GIVES.
  # Both writes at the top of this branch are `sed` substitutions keyed on a field, and a
  # substitution keyed on an ABSENT field matches nothing and exits 0 -- indistinguishable from
  # having written. Lines above say exactly that, and act on it, for `skill_version`/`skill_commit`.
  # This arm is one branch up and did not: a stamp lacking `commit:`/`version:` -- a legacy
  # single-line stamp, or a partial one -- took zero substitutions, both seds exited 0, and the row
  # printed anyway. `elif [ -f "$STAMP" ]` proves the file exists, never that it was written.
  #
  # This is the field the NEXT pull trusts to compute its base, so a row claiming a stamp that did
  # not land does not merely misreport: it mis-bases the following merge.
  got_c="$(sed -n 's/^commit:[[:space:]]*//p' "$STAMP" | head -1)"
  got_v="$(sed -n 's/^version:[[:space:]]*//p' "$STAMP" | head -1)"
  if [ "$got_c" = "$theirs_sha" ] && { [ -z "$ver" ] || [ "$got_v" = "$ver" ]; }; then
    say RESOLVED restamp "$BASE -> $theirs_sha"
    # The tree is consistent again, and ONLY here. Cleared beside the re-stamp rather than
    # in a trap, so an exit that withholds the stamp also leaves the marker: a partially
    # applied tree must keep blocking its own fixture suite until the pull is finished.
    #
    # It sits INSIDE the read-back for the same reason. "The tree matches THEIRS" asserted beside a
    # stamp that demonstrably does not read THEIRS is the strongest false claim this manifest can
    # make, and it was previously unconditional. This does not make the row fully earned -- nothing
    # here verifies file CONTENTS against theirs -- but it can no longer fire over a stamp that was
    # never written.
    rm -f "$APPLYING"
    say RESOLVED consistent "the tree matches $theirs_sha; fixture suite re-enabled"
  else
    say DECISION restamp-failed "$STAMP" "the stamp still reads \`commit: ${got_c:-<absent>}\` / \`version: ${got_v:-<absent>}\` rather than ${ver:-<unreadable>} @ ${theirs_sha}. A \`sed\` keyed on a field the stamp does not carry matches nothing and exits 0, so the write reported success and did nothing — a legacy single-line stamp, or one missing these fields. Rewrite it in schema (version/commit/skill_version/skill_commit/installed_at/upstream) and re-run. The in-flight marker is deliberately left in place, so the fixture suite keeps blocking until it is."
  fi

  # THE ONE STEP-7 ARTIFACT THIS TOOL DOES NOT WRITE, SAID AT THE MOMENT IT IS OWED.
  #
  # Filed by the reference consumer as PC-S329-APPLY-SH-NEVER-WRITES-THE-RECONCILE-LOG: step 7
  # hands the re-stamp and the log to the reader in one bullet, and this program did the first
  # and not the second. Measured: ZERO occurrences of the token in this file against NINE files
  # in the distribution that name the artifact -- the contract stated everywhere except in the
  # program a reader takes to be doing it.
  #
  # THE FIX IS NOT TO WRITE IT HERE, and that is a measurement rather than a preference. A real
  # reconcile log records the gates before the first write, the post-apply re-runs on their own
  # bases, the validator outcomes, the ledger decisions and what was deliberately NOT done. This
  # program sees none of those. A skeleton it could fill would be a file whose empty sections
  # read as written ones -- the vacuous-double shape this repo has shipped before.
  #
  # So the boundary is stated HERE, on the successful run, where the omission actually happens.
  # Prose alone was what failed the first time.
  echo "apply: NOT WRITTEN BY THIS TOOL -- _bmad-output/ai-dlc-update/reconcile-log-<ts>.md" >&2
  echo "  It records the gates, the post-apply re-runs, the validators and the ledger decisions." >&2
  echo "  This program can see none of those, so it does not write them. Step 7 is where you do." >&2
fi

# --- HOOK REGISTRATION: the other half of a hook delivery, which this tool does NOT do ------
#
# THE SHAPE OF THE DEFECT. A hook arrives on a consumer in two halves. The FILE is a pure
# apply -- this program writes `.claude/hooks/ai-dlc-<x>.sh` from theirs, with a manifest row,
# mechanically. The REGISTRATION is `reconcile/settings-merge.sh` rewriting
# `.claude/settings.json`, and NOTHING CALLS IT: its only two invocation sites in the whole
# distribution are prose, in `ai-dlc-update/SKILL.md`, and this file names it zero times.
#
# So the enforced half puts the file on disk and the prose half wires it up. Skip the prose and
# the hook ships, sits there, looks installed, and never fires -- with no error, no log line,
# and no absence anywhere for a later run to notice. `settings-merge.sh` is right to be a
# script ("prose that an agent retypes as jq drifts", its own header); the residual is that its
# INVOCATION is still prose, and this row is what stops that from being invisible.
#
# WHY A `WORKLIST` ROW AND NOT A CALL TO `settings-merge.sh` HERE. The merge takes an operator
# answer -- `--model-row`, obtained at the step-5 report -- and this driver has no channel to
# ask for one. That is also why `.claude/settings.json` is absent from the mechanical set on
# purpose rather than by oversight: EVERY template-derived consumer file is (`TEMPLATE-` appears
# zero times in this program, against three `UPSTREAM-ONLY`), because each of the four is a
# user-owned file whose merge is operator-gated. Calling the merge from here would either
# discard that gate or invent an answer. Naming the work does neither, and the driver stating
# it is the difference between an instruction and a hope.
#
# WHY IT RUNS AFTER THE RE-STAMP RATHER THAN GATING IT. At this point in step 7 the tree is
# SUPPOSED to be in this state: the pull writes hook files here and merges settings.json
# several bullets later. A gate would fire on every correct run. The delivery gate lives at
# the end of step 7, beside `setup-site-drift.sh`; this row is what tells the reader the work
# exists, by name, at the moment it is created.
#
# UNCONDITIONAL -- outside the re-stamp branch above -- because a withheld stamp does not make
# an inert hook less inert.
HR_VALIDATOR=""
if [ -x "$CONSUMER/scripts/ai-dlc/validate-hook-registration.sh" ]; then
  # Theirs' copy: the pure-apply phase above already wrote scripts/ai-dlc/ from THEIRS.
  HR_VALIDATOR="$CONSUMER/scripts/ai-dlc/validate-hook-registration.sh"
fi
if [ -n "$HR_VALIDATOR" ]; then
  hr_out="$(bash "$HR_VALIDATOR" --root "$CONSUMER" 2>&1)"; hr_rc=$?
  hr_names="$(printf '%s\n' "$hr_out" | sed -n 's@^ *\.claude/hooks/@@p' | tr '\n' ' ')"
  if [ "$hr_rc" = "1" ] && [ -n "$hr_names" ]; then
    say WORKLIST settings-merge ".claude/settings.json" \
      "hook(s) present and UNREGISTERED after this apply: ${hr_names}— each is on disk, wired to nothing, and indistinguishable from one that is working. Run the settings reconcile, which is the one program that owns this contract: \`t=\$(mktemp); git -C <dist> show <theirs>:templates/settings.json.template > \"\$t\"; reconcile/settings-merge.sh --consumer .claude/settings.json --template \"\$t\" [--model-row <operator's answer>]\`. Re-run scripts/ai-dlc/validate-hook-registration.sh afterwards; it must exit 0 before delivery."
  elif [ "$hr_rc" = "2" ]; then
    say DECISION hook-registration-unreadable ".claude/settings.json" \
      "the hook-registration check could not run, so whether this pull's hooks are wired is UNKNOWN — and unknown reads exactly like clean. Detail: $(printf '%s' "$hr_out" | tr '\n' ' ')"
  fi
else
  # NOT a silent skip. A pull old enough to predate the validator cannot check this, and saying
  # so is the difference between "checked and clean" and "never looked".
  say DECISION hook-registration-unchecked ".claude/settings.json" \
    "scripts/ai-dlc/validate-hook-registration.sh is not on this consumer, so nothing verified that the hook files this apply wrote are registered in settings.json. Run the settings reconcile (step 7's TEMPLATE-JSON-MERGE bullet) and re-run this apply; from the next pull on, the check is automatic."
fi

exit 0
