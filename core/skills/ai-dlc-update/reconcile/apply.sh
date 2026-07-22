#!/usr/bin/env bash
# apply.sh — the RESOLUTION half of ai-dlc-update. Executes every MECHANICAL resolution a pull
# needs, and emits a worklist of the only things left: the genuinely SEMANTIC merges (which the
# skill does inline) and the genuine OPERATOR decisions. The point of the whole skill is that the
# operator runs the update and it lands — not that a report tells them to go do the fixes by hand.
#
# WHAT IT RESOLVES MECHANICALLY (writes to the consumer; the caller wraps this in a branch+commit):
#   - pure applies        UPSTREAM-ONLY / UPSTREAM-ONLY-ADD core files overwritten from theirs
#   - token substitution  a new SETUP-TOKENS file's {*_model_*} filled from the nearest-equivalent
#                         existing role (gate-adjudicator <- adversary; same opus tier), no prompt
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
#   DECISION <kind> <path> <why>          a genuine operator call (unknown drift refile-vs-revert,
#                                         a deletion, a value with no default)
#   DECISION restamp-withheld <stamp>     a file that SHOULD have applied mechanically did not,
#                                         so the stamp was NOT advanced — this one is a bug in
#                                         THIS file, not a call the operator can make
#
# Usage:  apply.sh <dist> <base> <consumer> <theirs>
# Exit:   0 = mechanical resolution completed (a residual WORKLIST/DECISION is normal, not failure)
#         1 = an error while resolving; 2 = usage.
set -uo pipefail

DIST="${1:?usage: apply.sh <dist> <base> <consumer> <theirs>}"
BASE="${2:?}"
CONSUMER="${3:?}"
THEIRS="${4:?}"

SELF="$(cd "$(dirname "$0")" && pwd)"
say() { printf '%s\t%s\t%s\n' "$1" "$2" "${3:-}"; }
err() { echo "apply: $*" >&2; exit 1; }

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

overwrite_from_theirs() { # <core-rel>
  local cp="$1" cons; cons="$(consumer_path "$cp")" || return 1
  mkdir -p "$(dirname "$cons")"
  git -C "$DIST" show "${THEIRS}:core/${cp}" > "$cons" 2>/dev/null || return 1
  sync_mode_from_theirs "$cp" "$cons"
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

# ---------------------------------------------------------------- 1. buckets (preclassify)
while IFS="$(printf '\t')" read -r kind path cons bucket; do
  [ -n "${bucket:-}" ] || continue
  rel="${path#core/}"
  case "$bucket" in
    UPSTREAM-ONLY|UPSTREAM-ONLY-ADD)
      overwrite_from_theirs "$rel" && say RESOLVED pure-apply "$rel" \
        || { say DECISION unmapped-path "$rel" "no consumer path mapping"; mech_fail=$((mech_fail+1)); } ;;
    *SETUP-TOKENS*)
      if overwrite_from_theirs "$rel"; then
        cons="$(consumer_path "$rel")"
        # Fill {gate_adjudicator_model_*} from the consumer's adversary role (same opus tier).
        adv="$CONSUMER/.claude/team-roles/adversary.md"
        if [ -f "$adv" ]; then
          p="$(sed -nE 's/^- Personal: `\/model (.+)`$/\1/p' "$adv" | head -1)"
          b="$(sed -nE 's/^- Bedrock: `\/model (.+)`$/\1/p' "$adv" | head -1)"
          [ -n "$p" ] && sed -i.bak "s|{gate_adjudicator_model_personal}|$p|g" "$cons"
          [ -n "$b" ] && sed -i.bak "s|{gate_adjudicator_model_bedrock}|$b|g" "$cons"
          rm -f "$cons.bak"
        fi
        # Fill {dev_escalated_model_*} from the consumer's protected-path-editor role (same opus
        # tier). dev-escalated is the standard Dev contract on a stronger model; ppe is the
        # nearest existing role that already pins the escalated tier the consumer chose.
        ppe="$CONSUMER/.claude/team-roles/protected-path-editor.md"
        if [ -f "$ppe" ]; then
          p="$(sed -nE 's/^- Personal: `\/model (.+)`$/\1/p' "$ppe" | head -1)"
          b="$(sed -nE 's/^- Bedrock: `\/model (.+)`$/\1/p' "$ppe" | head -1)"
          [ -n "$p" ] && sed -i.bak "s|{dev_escalated_model_personal}|$p|g" "$cons"
          [ -n "$b" ] && sed -i.bak "s|{dev_escalated_model_bedrock}|$b|g" "$cons"
          rm -f "$cons.bak"
        fi
        if grep -q '{[a-z_]*_model_[a-z]*}' "$cons" 2>/dev/null; then
          say DECISION setup-token "$rel" "a {*_model_*} token had no default source"
        else
          say RESOLVED token-substitute "$rel"
        fi
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
        git -C "$DIST" show "${THEIRS}:core/${rel}" > "$cons" 2>/dev/null
        sync_mode_from_theirs "$rel" "$cons"
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
LD_HARD="$(bash "$SELF/layer-drift.sh" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" 2>/dev/null | awk -F'\t' '$1=="HARD-OVERRIDE-DRIFT-SECTION"{print $2}')"
while IFS= read -r ovr; do
  [ -n "$ovr" ] || continue
  say WORKLIST override-readopt "$ovr" "merge the moved core section into the override body, then readopt-override.sh --stamp readopt"
done <<EOF
$LD_HARD
EOF

# ---------------------------------------------------------------- 4. catalog relabel (mechanical)
if bash "$SELF/relabel-extension-checks.sh" "$CONSUMER" --apply --dist "$DIST" --theirs "$THEIRS" >/dev/null 2>&1; then
  say RESOLVED relabel "ext-check collisions labelled"
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
# THE MANIFEST IS THE DECLARATION -- of the set AND of where each file goes.
#
# `ls-tree core/scripts` would give the same 25 files (validate-enforcement-map.sh
# I5b asserts the two agree in both directions, so neither can drift). It is not used
# because it answers only "what is shipped", and the destination would then have to
# come from map_consumer()'s `scripts/ai-dlc/` prefix rule -- a SECOND statement of a
# path the manifest entries already spell out in full. One declaration, or the two
# drift the first time a relocation is only half-applied.
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
  ' "$SELF/setup-sites.md" 2>/dev/null | sed -e 's#^core/##' -e '/^scripts\/ai-dlc\//!d'
}

legacy_moved=""
legacy_moved_n=0
manifest_n=0
for dest in $(manifest_dests); do
  manifest_n=$((manifest_n+1))
  base="${dest#scripts/ai-dlc/}"
  old="$CONSUMER/scripts/$base"
  new="$CONSUMER/$dest"

  # A declared file THEIRS does not ship. That is a distribution inconsistency and
  # validate-enforcement-map.sh I5b owns it -- it asserts the manifest and
  # core/scripts/ agree in both directions, so this cannot reach a real release.
  # Treating it as a mechanical failure HERE would block a pull over a defect the
  # consumer cannot fix and did not cause.
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

# A manifest that yields nothing is a manifest this driver could not read, and a
# silent zero here relocates NOTHING while the run still re-stamps -- the stamp then
# claims a version whose validators are not where every core reference points. Same
# posture as install.sh refusing to install zero validators.
if [ "$manifest_n" -eq 0 ]; then
  say DECISION manifest-unreadable "reconcile/setup-sites.md" \
    "no scripts/ai-dlc/ entries found in the core_manifest block — refusing to treat that as 'nothing to relocate'."
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
if [ "$mech_fail" -gt 0 ]; then
  say DECISION restamp-withheld "$STAMP" "${mech_fail} file(s) could not be placed mechanically — the stamp would claim ${THEIRS} while the tree lacks them. Left at ${BASE}; fix the paths above and re-run."
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
  say RESOLVED restamp "$BASE -> $theirs_sha"
fi

exit 0
