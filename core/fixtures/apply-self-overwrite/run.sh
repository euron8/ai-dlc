#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# apply-self-overwrite/run.sh — prove the resolution driver survives replacing ITSELF, and that
# a failed fetch cannot leave an empty core file where the old one was.
#
# The behavioural arms only. The mutation battery that proves each of them can fail is
# `apply-self-overwrite-mutants`, distribution-only, which sources the SAME worlds and predicates
# from `lib.sh` beside this file. The battery mutates copies of core's own `reconcile/apply.sh`,
# which a consumer cannot edit, so the consumer keeps every correctness arm and loses only that proof.
#
# THE DEFECT, reported by the consumer and reproduced at ground truth before anything was fixed.
# `skills/*` maps to `.claude/%s` (core-paths.sh), so `core/skills/ai-dlc-update/reconcile/
# apply.sh` lands at `.claude/skills/ai-dlc-update/reconcile/apply.sh`. That file is UPSTREAM-ONLY
# on any range that changed it, so phase 1 writes it — and SKILL.md step 7 tells the session to run
# `reconcile/apply.sh <dist> <base> <consumer> <theirs>`, a relative path inside the installed
# skill, i.e. that exact copy. The driver overwrote itself while running.
#
# `git show > "$cons"` is a shell redirect: open+truncate+write, SAME INODE. bash executes a script
# by reading it incrementally and keeping a byte offset, so after the truncate its next read lands
# at the same offset in DIFFERENT content.
#
# THE QUESTION WAS SETTLED BY EXPERIMENT BEFORE ANY FIX, because the answer decides whether the
# defect is live or latent:
#
#   in-place overwrite (same inode)   bash resumed inside the NEW text, ran the replacement's
#                                     tail, and exited rc=0
#   atomic replace via mv (new inode) unaffected; the original ran to completion
#   no replacement (control)          unaffected
#
# Then reproduced on a scratch consumer installed at 0.310.0 and pulled to 0.312.0. Same dist,
# same range, same tree, same 8 pure-applies; the ONLY variable was where the running copy lived:
#
#   running copy = the consumer's own     rc=2, `line 251: syntax error near ';;'`, stamp
#                                         withheld, .ai-dlc-applying LEFT, tree partially applied
#   running copy = out-of-tree (control)  rc=0, no stderr, re-stamped, marker cleared
#
# THE ABORT IS THE LUCKY END OF THE BAND, and that is why this fixture asserts a POSITIVE outcome
# rather than the absence of that particular message. Whether the shifted bytes fail to parse or
# merely parse into something else is not under anyone's control — the bash arm above shows the
# same mechanism producing rc=0 with the wrong code executed.
#
# HOW IT DRIVES THE REAL SCRIPT. A synthetic pull: two throwaway git repos where the distribution
# carries `core/skills/ai-dlc-update/reconcile/apply.sh` and the consumer carries it at the mapped
# `.claude/...` path, so preclassify classifies it UPSTREAM-ONLY and phase 1 writes it. The copy
# under test is the SHIPPED file, byte for byte; only `layer-drift.sh` is stubbed, so the run does
# not depend on a layer corpus this fixture has no business seeding.
#
# THE SECOND DEFECT THIS FILE OWNS (assertions 5–8): the `driver-self-update` row prescribed a
# bare re-run and called it idempotent, and the union gate the same range installed refuses that
# re-run — with a message naming two causes that are both false. Post-apply, the approved report
# describes the tree BEFORE the apply moved it, so the detectors render every applied path as
# already-at-theirs and the region cannot match; upstream had not moved and nothing was
# hand-edited. Reported by the reference consumer on its 0.482.0 -> 0.489.0 pull, by obeying the
# row. The refusal is correct (nothing is left to write); the DIAGNOSIS was not, and the row must
# not prescribe an action the same release makes unexecutable in the state the row is printed in.
# The gate now DECIDES the third cause from the stamp's `commit:`, compared by `core/` tree, and
# prints the record it matched; the row points at that refusal instead of prescribing the re-run.
# Driven here because this file already drives the self-replacement that emits the row. The
# carve-out — let a post-apply re-run through — was built and scored before this was written: it
# re-wedges a consumer that has already `--finish`ed by hand (the semantic-merge WORKLIST returns
# and the marker with it), so the refusal stays.
#
# AND NOT FROM THE IN-FLIGHT MARKER, which v0.493.0 shipped and v0.494.0 took back. The marker's
# `theirs:` is written by apply.sh from its own fourth argument before phase 1 writes anything, so
# a diagnosis keyed on it is true by construction on every re-run and fired on a tree still
# byte-identical to base — and the `--finish` that message offered stamped 2.0.0 over a 1.0.0
# tree. Assertion 8 holds that state, and the battery's M8 restores the marker arm.
#
# lib.sh resolves reconcile/ in either layout from its own directory, sets the shell options, and
# owns W and its one EXIT trap.
HERE="$(cd "$(dirname "$0")" && pwd)"
NAME="apply-self-overwrite"
[ -f "$HERE/lib.sh" ] || { echo "$NAME: FIXTURE BROKEN — $HERE/lib.sh is absent; nothing was asserted" >&2; exit 2; }
. "$HERE/lib.sh"

echo "$NAME:"

echo "HERMETIC-CONSUMED core/skills/ai-dlc-update/reconcile/"
worlds "$W/s" "$REC"

# A predicate answering 2 could not stand up its world. For the two sanity predicates every arm
# after them reads that world, so the run stops; elsewhere it is one broken arm.
broken() { bad "FIXTURE BROKEN — $1"; echo; echo "$NAME: FIXTURE BROKEN" >&2; exit 2; }
arm() { # <predicate> <label-ok> <label-bad>
  local r
  WHY=""
  "p_$1" "$W/s"; r=$?
  case "$r" in
    0) ok "$2" ;;
    2) bad "FIXTURE BROKEN — $WHY" ;;
    *) bad "$3: $WHY" ;;
  esac
}

# --- SANITY: the driven apply.sh classified and wrote its own path -----------------------------
WHY=""
p_sane "$W/s" || broken "$WHY"
ok "the driven apply.sh classified its OWN path as a pure-apply and wrote it"

arm self "the driver ran to completion while replacing itself, and THEIRS landed (rc=0, no stderr)" \
         "the driver did not survive replacing itself"
arm row "  and it reports the self-update, so the operator knows the rows came from the previous driver" \
        "the driver replaced itself and said nothing: the operator cannot tell that the worklist below was produced by the pre-range rules"
arm silent "  and it is SILENT on a run that does not replace the driver (same tree, second run)" \
           "the driver-self-update row fires even when apply.sh was NOT replaced — it reports the run, not the event"
arm litter "the run left no .incoming. temp behind in the consumer tree" \
           "the run left .incoming. file(s) inside the consumer's tree; count"

# A DECLARED GAP, stated rather than faked. The repair has a SECOND failure direction this fixture
# does NOT drive: the old redirect truncated `$cons` BEFORE `git show` ran, so a show that FAILED
# left an empty core file where the consumer's working one had been. The obvious way to drive it —
# a THEIRS that does not carry the path — does not reach the writer at all, because preclassify
# then does not classify the path as a pure-apply. That was measured, not assumed: an earlier
# revision of this file asserted exactly that and a mutant restoring the redirect SURVIVED it,
# which is what proved the arm vacuous. The remaining ways to fail a `git show` on a path that IS
# classified are a corrupted or unreadable object, and a permission-based arm is precisely the one
# that passes for the wrong reason when the suite runs as root. So it is unasserted and said so.

# --- SANITY for 5–8 ---------------------------------------------------------------------------
WHY=""
p_gsane "$W/s" || broken "$WHY"
ok "gate world: the first run verified the pre-apply report, replaced the driver, and re-stamped to theirs ($WHY)"

arm rowtext "the driver-self-update row no longer prescribes a bare re-run, and says the gate will refuse one" \
            "the driver-self-update row is wrong"
arm diag "the bare re-run is refused (rc=1, nothing written) and the refusal names the post-apply cause with the stamp it matched" \
         "the bare re-run was not refused with the post-apply diagnosis"
arm stale "  and a report that is stale because UPSTREAM moved still gets the two-cause refusal, not the post-apply diagnosis" \
          "a stale-upstream report was misdiagnosed"
arm marker "  and a marker over an UNWRITTEN tree is not read as post-apply: listed refusal, no matched record, no --finish, stamp and driver still at base" \
           "a marker over an unwritten tree was misread as post-apply"

echo
if [ "$fails" -eq 0 ]; then
  echo "$NAME: PASS"
else
  echo "$NAME: FAIL ($fails)" >&2
  exit 1
fi
