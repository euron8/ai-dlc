#!/usr/bin/env bash
# reconcile-region: exempt — the WRITER. It acts on the region after the operator approves it; it is not a finding in it.
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
#   WORKLIST <kind> <subject> <detail>    concrete work that CLEARS when the work is done, so the
#                                         re-stamp is withheld until it is. Every kind is named at
#                                         its own emitting site below.
#   DECISION <kind> <path> <why>          a genuine operator call (unknown drift refile-vs-revert,
#                                         a deletion, a value with no default)
#   DECISION restamp-withheld <stamp>     work is still outstanding — a file that SHOULD have
#                                         applied mechanically did not, or a WORKLIST/DECISION row
#                                         above is undisposed — so the stamp was NOT advanced and
#                                         the in-flight marker was NOT cleared. Finish the rows,
#                                         then re-run with --finish.
#
# THE KIND SET IS DERIVED FROM THIS FILE, NEVER HAND-LISTED HERE, AND THAT IS A REPAIR RATHER
# THAN A STYLE CHOICE. This block used to name three WORKLIST kinds. It was eleven by the time
# anybody counted, and the eight it had silently stopped covering were invisible precisely
# because the list LOOKED complete -- a reader checking whether a class was routed consulted a
# header that had been wrong for eight additions. A restatement drifts tighter than what it
# restates, and nothing compares the two. The live set is one command:
#
#   grep -oE '^[[:blank:]]*say (WORKLIST|DECISION) [a-z-]+' apply.sh | awk '{print $2, $3}' | sort -u
#
# Read that, not a paragraph. The SHAPE above is the contract; the membership is the code's.
#
# THE STAMP IS THE NEXT PULL'S BASE, AND A HAND-BACK IS NOT DONE WHEN THIS PROGRAM EXITS.
# This driver used to gate the stamp on `mech_fail` alone -- its own inability to place a file --
# and to treat every WORKLIST/DECISION row as work "the caller completes in this same run, so the
# stamp is still true once it does". The caller completes it AFTER this program has exited, and
# nothing made that true. Filed by the reference consumer as
# PC-S304-APPLY-SH-RESTAMPS-BEFORE-THE-WORKLIST-IS-DONE, reproduced across two pulls a month
# apart: one run printed `RESOLVED restamp` beside 37 outstanding rows -- 13 semantic merges, 4
# override readopts, 20 extension re-reads. An apply that then aborts, errors, or is simply
# abandoned leaves a tree CLAIMING to be at theirs. The next pull diffs from that stamp, sees no
# delta for the un-merged files, and the work becomes invisible: not BOTH-CHANGED, not
# UPSTREAM-ONLY, but ALREADY-AT-THEIRS-shaped to every detector that compares against the stamp.
#
# So the stamp is now withheld while ANY row is outstanding, and `--finish` is the act that
# advances it once they are disposed. Withholding without a reachable finisher would WEDGE the
# consumer -- `core/git-hooks/pre-push` refuses the fixture suite while the marker exists -- so
# the withheld row names the exact command, and the fixture asserts that it does.
#
# Usage:  apply.sh [--carried-machinery-slice] <dist> <base> <consumer> <theirs>
#         apply.sh --finish [--carried-machinery-slice] <dist> <base> <consumer> <theirs>
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
#
# `--finish` is the SECOND HALF of a withheld run: it skips every resolution phase and does only
# the re-stamp and the marker clear, for a tree whose worklist the caller has since disposed. It
# is a mode rather than a separate script because the stamp is written in exactly one place and a
# second copy of that logic is a second thing to drift.
#
# IT VERIFIES THE TREE BEFORE IT STAMPS, and does not take the caller's word for it: the identity
# of <theirs>, then BASE against the stamp, then preclassify's own pure-apply buckets -- any file
# still reading as a pure apply is a WORKLIST row and the stamp is withheld. Without that, it
# stamped theirs over a tree where nothing had been applied. See finish_verify_tree(). It then
# re-checks the two DECISION remedies only a fresh ordinary run performs -- the known_skills refile
# and the exec-bit audit -- and withholds while either is still owed. See finish_reapply_owed(). And
# it withholds while a file the ordinary run handed back as a semantic merge is still byte-identical
# to the copy that run recorded in the marker. See finish_classify_unmerged().
CARRIED_MACHINERY=0
FINISH=0
_pos_n=0
for _a in "$@"; do
  case "$_a" in
    --carried-machinery-slice) CARRIED_MACHINERY=1 ;;
    --finish) FINISH=1 ;;
    --*)
      echo "apply: unknown option: $_a" >&2
      echo "usage: apply.sh [--finish] [--carried-machinery-slice] <dist> <base> <consumer> <theirs>" >&2
      exit 2 ;;
    *)
      _pos_n=$((_pos_n+1))
      case "$_pos_n" in
        1) _p1="$_a" ;; 2) _p2="$_a" ;; 3) _p3="$_a" ;; 4) _p4="$_a" ;;
        *) echo "apply: too many arguments: $_a" >&2
           echo "usage: apply.sh [--finish] [--carried-machinery-slice] <dist> <base> <consumer> <theirs>" >&2
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
#
# THE HAND-BACK COUNT IS TAKEN HERE, IN THE EMITTER, AND NOT AT THE CALL SITES. There are 22
# `say WORKLIST` sites and 39 `say DECISION` sites today (non-comment lines), and a counter incremented at
# each is a hand-list that the next row added silently falls out of -- the same shape as the
# `mech_fail` list below, which is why that one had to be measured rather than trusted. Every row
# reaches this function, so this is the one place the duty cannot be missed.
#
# `restamp-withheld` and the `restamp-failed` rows are DECISIONs too, and they self-count. That is
# harmless: they are emitted at or after the guard reads the value, so they cannot cause the
# withholding they report. The fixture's C3 arm is what proves a clean run still stamps.
#
# TWO COUNTERS, BECAUSE THE TWO MODES CAN GATE ON DIFFERENT THINGS AND ONE OF THEM MUST
# TERMINATE. Measured on the first end-to-end run of this change: `--finish` counted every row it
# re-derived, the hook-registration site emitted `DECISION hook-registration-unchecked` on a
# consumer with no `validate-hook-registration.sh`, and the finisher withheld -- FOREVER. That
# row's own stated remedy is to re-run the apply, which is how the validator arrives, and
# `--finish` skips the phase that delivers it. A withheld stamp the operator cannot clear leaves
# `.ai-dlc-applying` in place and `core/git-hooks/pre-push` refusing the fixture suite, so the
# consumer is wedged with no exit. That is the failure this change exists to avoid, reintroduced
# one layer down by the change itself.
#
# So: the ORDINARY run gates on both kinds, which is the filed fix shape and is terminating
# because `--finish` is the exit. `--finish` gates on WORKLIST only -- a row naming concrete work
# that clears when the work is done -- and never on a DECISION, which at that point is either
# already adjudicated by the operator or is this program saying it could not look.
#
# A THIRD COUNT, `reapply_owed`, IS TAKEN HERE FOR THE SAME REASON: it is every row whose detail
# carries `reapply_remedy` below, the rows only a fresh ordinary run clears. Keyed on the detail
# text at the emitter rather than on a list of call sites, so a fifth such row is counted without
# anyone remembering to. The withheld-stamp row reads it to decide which next step it names.
handback=0
worklist_n=0
reapply_owed=0
say() {
  case "$1" in WORKLIST|DECISION) handback=$((handback+1)) ;; esac
  case "$1" in WORKLIST)          worklist_n=$((worklist_n+1)) ;; esac
  case "${4:-}" in *"$reapply_remedy"*) reapply_owed=$((reapply_owed+1)) ;; esac
  if [ -n "${4:-}" ]; then printf '%s\t%s\t%s\t%s\n' "$1" "$2" "${3:-}" "$4"
  else                     printf '%s\t%s\t%s\n'     "$1" "$2" "${3:-}"
  fi
}
err() { echo "apply: $*" >&2; exit 1; }

# THE REMEDY FOR A ROW THAT ONLY A FRESH ORDINARY RUN CAN CLEAR, STATED ONCE. Four rows used to end
# in "re-run" or "re-run apply": the provenance refile whose diff did not run, and the three
# exec-bit rows. Each is printed by a run that has ALREADY WRITTEN the tree, so a bare re-run is
# refused by the union gate above (the approved report describes the tree before this run moved
# it) -- measured on both shapes, rc 1 and the stamp left at base. And `--finish`, which the
# restamp-withheld row offers, skips every resolution phase: measured, it stamped theirs with the
# known_skills edit unrefiled and the schema still drifted, and it stamped theirs over a 100755
# validator still not executable. The procedure whose SUCCESS implies the work was done is the
# union gate's own: re-render, re-approve, apply -- that run refiles, and that run re-audits.
#
# `--finish` NOW RE-CHECKS BOTH AND REFUSES, rather than stamping over them (finish_reapply_owed
# below), and the withheld row no longer offers it while one of these rows is outstanding. It
# still does not REDO either step, which is why this remedy does not name it.
reapply_remedy="re-render the report with \`emit-report.sh ${DIST} ${BASE} ${CONSUMER} ${THEIRS}\` from the tree as it now stands, re-approve it, then re-run apply with the same four arguments. A bare re-run is refused by the union gate, because this run already wrote the tree the approved report describes; and the finish mode does not redo this step -- it re-checks it and withholds the stamp while it is still undone."

# --- MECHANICAL UNION GATE, CONDITION (1), DRIVEN HERE RATHER THAN NARRATED ----
# SKILL.md step 7 lets `apply` write only after
# `emit-report.sh --verify <report> <dist> <base> <consumer> <theirs>` exits 0. That gate was
# PROSE, and `theirs` was an argument the executing session supplied — so a session could verify
# the report against the ref the REPORT names while this program resolves a NEWER one, and get a
# clean exit 0 over a region describing a different upstream.
#
# THE CHECK WAS NEVER BLIND; THE AFFORDANCE WAS. The rendered region carries theirs' `core/`
# tree hash, so --verify does see a moved ref. Measured across one release: rc=0 verifying at
# the ref the region was rendered for, rc=1 one release later, the two `core/` trees differing.
# A symbolic `origin/main` does not defeat it either — the ref STRING is stable across the move
# and the tree hash is not. Nothing made the two `theirs` values the same one. They are the same
# by construction here, because this call passes the `$THEIRS` this program is about to apply.
#
# AN ABSENT REPORT DOES NOT BLOCK, deliberately rather than as a hole left open. This driver has
# never required a report and two dozen fixture directories drive it without one; refusing would
# wedge every one of them while changing no operator outcome, since step 5 writes the report
# before step 7 runs. A row is emitted instead, so "nothing checked this" reaches the manifest
# the operator reads rather than being absent from it.
#
# NOTE AND NOT DECISION, ON BOTH ROWS. `say` counts WORKLIST and DECISION into `handback`, and a
# non-zero hand-back WITHHOLDS the re-stamp. A DECISION here would withhold it on every apply
# that has no report — which is every fixture — and a withheld stamp leaves `.ai-dlc-applying`
# in place with no way to clear it. That is the wedge the two-counter design above exists to
# avoid, and this gate must not reintroduce it one layer up.
#
# NOT UNDER `--finish`, for the same reason: that mode writes no core file, so there is no write
# for this condition to authorize, and a finisher that refuses cannot be cleared.
UNION_REPORT="$CONSUMER/_bmad-output/ai-dlc-update/reconcile-report.md"
if [ "$FINISH" = 0 ]; then
  if [ -f "$UNION_REPORT" ]; then
    # STDERR IS KEPT, NOT DISCARDED: --verify decides the cause of a mismatch on its own exit code
    # (3 = the approved region lists HARD-* rows that no longer render, refs unchanged, nothing
    # HARD new) and prints the rows it decided from. The refusal below quotes that line rather
    # than restating the grammar, so the two programs cannot disagree about what was decided.
    _ug_verr="$(bash "$SELF/emit-report.sh" --verify "$UNION_REPORT" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>&1 >/dev/null)"
    _ug_rc=$?
    if [ "$_ug_rc" -eq 0 ]; then
      say NOTE report-verified "${UNION_REPORT#"${CONSUMER}"/}" "union-gate condition (1): the approved report's mechanical region matches what the detectors render at THIS run's theirs ($THEIRS)."
    else
      # THE THIRD CAUSE, DECIDED RATHER THAN LISTED. A region also fails to match when an apply
      # of THIS theirs has already written this tree: the approved report describes the tree
      # BEFORE that apply moved it, so the detectors now render every applied path as
      # already-at-theirs and the bytes cannot agree. Measured on the reference consumer's
      # 0.482.0 -> 0.489.0 pull, by obeying the driver-self-update row this file used to emit:
      # rc=1, 26 rows moved UPSTREAM-ONLY -> ALREADY-AT-THEIRS, upstream unmoved, nothing
      # hand-edited -- and the message named the two causes that were false and not the one
      # that was true. The REFUSAL stands either way (there is nothing left for this run to
      # write); the DIAGNOSIS is what was wrong. It is decided from the STAMP's `commit:` alone,
      # compared by `core/` TREE, for the reason the --finish identity guard below gives: two
      # refs can differ as commits while the bytes this pull writes are identical.
      #
      # NOT FROM THE IN-FLIGHT MARKER, and v0.493.0 shipped that and had to take it back. The
      # marker's `theirs:` is written by THIS program, from THIS run's `$THEIRS`, before phase 1
      # writes anything -- so `marker.theirs:core == THEIRS:core` holds by construction on every
      # re-run with the same fourth argument, whatever the tree contains. It records that a run
      # BEGAN, never that the tree was WRITTEN. Measured: a marker left by an aborted run over a
      # tree still byte-identical to base made the diagnosis fire, and the `--finish` that
      # message then offered stamped 2.0.0 over a tree at 1.0.0 -- the PC-S304 shape, reached
      # through advice. A withheld-stamp re-run therefore falls through to the listed message
      # below, which now names this cause as a POSSIBILITY; under-firing is the safe direction.
      #
      # THE STAMP IS A CLAIM ABOUT THE TREE, NOT A MEASUREMENT OF IT. It says an earlier apply
      # brought this tree to theirs; it cannot say what was done by hand since. So the diagnosed
      # message asserts only what the stamp asserts, states that limit, and prescribes nothing
      # that writes: no `--finish`, no "nothing left to write". Absent or unresolvable stamp
      # falls through to the listed message, never to a pass.
      _ug_at=""
      _ug_tt="$(git -C "$DIST" rev-parse "${THEIRS}:core" 2>/dev/null || true)"
      _ug_sc="$(sed -n 's/^commit:[[:space:]]*//p' "$CONSUMER/.claude/.ai-dlc-version" 2>/dev/null | head -1)"
      if [ -n "$_ug_sc" ] && [ -n "$_ug_tt" ] \
         && [ "$(git -C "$DIST" rev-parse "${_ug_sc}:core" 2>/dev/null || true)" = "$_ug_tt" ]; then
        _ug_at="$_ug_sc"
      fi
      # THE FOURTH CAUSE, DECIDED BY --verify ITSELF (exit 3) AND THE COMMON ONE. SKILL.md step 7
      # requires every HARD-* blocker resolved BEFORE this program writes, and each resolution
      # rewrites the region the operator approved — `--stamp readopt` turns a
      # HARD-OVERRIDE-DRIFT-SECTION row into OVERRIDE-OK, a register row removes a
      # HARD-LAYER-ADJUDICATION-MISSING row — so on any pull that had a blocker the approved report
      # lists findings that no longer exist and the bytes cannot agree. Measured on the reference
      # consumer: four of six applies since v0.488.0 re-rendered the region after resolving as an
      # unwritten workaround; the fifth got the listed message below, both of whose named causes
      # were false. Filed as PC-S305-UNION-GATE-UNPASSABLE-ON-ANY-PULL-THAT-HAD-A-BLOCKER.
      #
      # STILL A REFUSAL, and after the stamp arm above on purpose: a post-apply re-run is the more
      # specific state (nothing is left to write) and can carry resolved rows too. The remedy here
      # is one re-render and one re-approval, and the message says so — the safe direction (a HARD
      # row the operator has NOT seen) never reaches this branch, because --verify keys the cause on
      # the approved region losing HARD rows and the fresh render gaining none.
      # The cause line is matched on its `cause:` label at any indent, and an absent line falls
      # back to naming the exit code rather than to an empty string: a prefix drift in --verify
      # must not silently delete the diagnosis from the refusal.
      _ug_cause="$(printf '%s\n' "$_ug_verr" | sed -n 's/^[[:space:]]*cause: //p' | head -1)"
      : "${_ug_cause:=cause not reported by --verify (exit ${_ug_rc})}"
      # THE DIFF REACHES THE OPERATOR. --verify prints the cause, the rows it decided from and the
      # want-vs-report diff to stderr; a refusal that says "read the diff" over a discarded diff is
      # a pointer to a tool the operator must re-run. Forwarded whole, before the verdict line.
      printf '%s\n' "$_ug_verr" >&2
      if [ -n "$_ug_at" ]; then
        err "the report at ${UNION_REPORT#"${CONSUMER}"/} does not match what the detectors render at this run's theirs ($THEIRS) — and the consumer's stamp records ${_ug_at}, whose core/ tree is theirs'. That stamp says an earlier apply already brought this tree to theirs, so this is a post-apply re-run (the one the driver-self-update row used to prescribe): the approved report describes the tree BEFORE that apply moved it, and a report rendered then cannot verify against the tree as it now stands. The stamp is a claim about the tree, not a measurement of it — if a core file or the report was changed by hand since, this refusal cannot see that. To see the current driver's reading of this tree, re-run the dry run at $THEIRS so the report is rendered from the tree as it now stands, re-approve it, then apply. NOTHING HAS BEEN WRITTEN."
      elif [ "$_ug_rc" -eq 3 ]; then
        err "the report at ${UNION_REPORT#"${CONSUMER}"/} does not match what the detectors render at this run's theirs ($THEIRS) — and the only difference in the blocking list is that the approved region lists HARD-* row(s) the detectors no longer render, with upstream unchanged. ${_ug_cause} Those blockers were resolved after the report was rendered — step 7's own work (a --stamp readopt, a register row) — so no HARD-* row is hidden from the approval; but the operator approved a region that no longer describes this tree, and the 'unseen:' lines above are rows a resolution left that they have not read. One step closes it: re-render the region with emit-report.sh $DIST $BASE $CONSUMER $THEIRS from the tree as it now stands, re-approve it, then re-run apply with the same four arguments. NOTHING HAS BEEN WRITTEN."
      else
        err "the report at ${UNION_REPORT#"${CONSUMER}"/} does not match what the detectors render at this run's theirs ($THEIRS). SKILL.md step 7 lets apply write only after emit-report.sh --verify exits 0, and it does not. ${_ug_cause} Either upstream moved after that report was rendered — which is what this gate exists to catch — or the region was hand-edited or a detector now renders a finding the approval never saw, or an earlier apply of this same range already moved this tree and its stamp is still withheld (a re-run after a withheld run). Re-run the dry run at $THEIRS, or name the ref the report describes explicitly so the two agree, then re-approve. NOTHING HAS BEEN WRITTEN."
      fi
    fi
  else
    say NOTE report-unverified "" "union-gate condition (1) was NOT evaluated: no report at ${UNION_REPORT#"${CONSUMER}"/}. This does not block — the driver has never required one — but nothing here has confirmed an operator approved a region matching theirs ($THEIRS)."
  fi
fi

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
#
# NOT REWRITTEN UNDER `--finish`. That mode writes nothing to core, so there is no window to
# mark; re-creating the marker there would only re-assert a mixture this invocation is about to
# declare resolved. It clears the marker only once finish_verify_tree() finds no file still
# reading as a pure apply; a withheld finish leaves it in place.
#
# WRITTEN AFTER PRECLASSIFY HAS CLASSIFIED, not here. A preclassify refusal stops the run before
# any write, and a marker written ahead of it was left on a tree nothing had touched -- blocking
# the next push with advice about a mid-pull tree that never was one. The write sits directly
# below that stop, still ahead of the first core write; everything between here and there only
# defines functions.
APPLYING="$CONSUMER/.claude/.ai-dlc-applying"
mkdir -p "$CONSUMER/.claude" 2>/dev/null || true

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
  mode="$(git -C "$DIST" -c core.quotePath=false ls-tree "$THEIRS" -- "core/$1" 2>/dev/null | awk '{print $1}')"
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

# THE DIFF STAGING DIRECTORY, one per process, removed by this process's EXIT handler. The drift
# refile's `diff` reads theirs from a staged file, never a `<( )` process substitution: under
# concurrent bash 3.2 workers that exits 2 with `/dev/fd/63: Bad file descriptor` (3-8 in 2000 at
# batch 160, 0 staged). Empty when `mktemp -d` failed, and the site then refuses instead of diffing.
AP_TMP="$(mktemp -d "${TMPDIR:-/tmp}/apply-diff.XXXXXX" 2>/dev/null)" || AP_TMP=""
trap '[ -n "$AP_TMP" ] && rm -rf "$AP_TMP"; :' EXIT
# ap_pdiff <staged-file> <other> — the staged file PIPED into `diff -`, never passed as a path:
# Apple diff hunks two regular files differently from a pipe and a file. Returns diff's own
# status, or 2 when the `cat` failed. A function because a `case` or a PIPESTATUS read inside
# `$( )` is where bash 3.2 parsing breaks.
ap_pdiff() {
  cat "$1" | diff - "$2"
  local _c="${PIPESTATUS[0]}" _d="${PIPESTATUS[1]}"
  [ "$_c" -eq 0 ] || return 2
  return "$_d"
}

# THE DETECTOR STAGING, under the same directory and removed by the same EXIT handler. Every
# detector this file consults used to be called as `$(bash <detector> … 2>/dev/null | …)`, which
# keeps stdout and discards both the exit and the stderr, so a detector that REFUSED (exit 1 or
# 2, empty stdout, its reason on stderr) read here as one that found nothing -- and the WORKLIST
# lost the row with no trace. `emit-report.sh` renders the same refusal as `DETECTOR-REFUSED`;
# this is that token at apply time.
#
# detector_run <key> <script> <args…> -- stdout to $DT_DIR/<key>.out, stderr to <key>.err,
# returns the detector's exit. 126 with nothing run when no staging directory exists, which the
# caller reports as a refusal: an uncaptured detector is not a clean one.
# detector_refused <row-name> <script> <path|-> <rc> <key> -- the one spelling of the row. A
# DECISION, so it counts toward `handback` and withholds the re-stamp, and `--finish` does not
# gate on it (see the two counters above). The detail quotes the detector's own REFUSED line --
# the first stderr line matching `: REFUSED` -- when it printed one, and stderr's line 1
# otherwise. Line 1 alone is not the reason when a write failed: bash prints its own
# `printf: write error: ...` for every lost row BEFORE the detector can name the refusal.
DT_DIR=""
if [ -n "$AP_TMP" ] && mkdir -p "$AP_TMP/detectors" 2>/dev/null; then DT_DIR="$AP_TMP/detectors"; fi
detector_run() {
  local _k="$1" _s="$2"
  shift 2
  [ -n "$DT_DIR" ] || return 126
  bash "$SELF/$_s" "$@" > "$DT_DIR/$_k.out" 2> "$DT_DIR/$_k.err"
}
detector_refused() {
  local _first="(not captured: no staging directory)"
  if [ -n "$DT_DIR" ]; then
    _first="$(grep -m1 ': REFUSED' "$DT_DIR/$5.err" 2>/dev/null | tr '\t' ' ')"
    [ -n "$_first" ] || _first="$(sed -n '1p' "$DT_DIR/$5.err" 2>/dev/null | tr '\t' ' ')"
    [ -n "$_first" ] || _first="(empty)"
  fi
  say DECISION "$1-refused" "$3" "DETECTOR-REFUSED: $2 exited $4 — this section is NOT a finding of 'none'; stderr: ${_first}"
}

# NO HERE-STRING FEEDS A DECISION IN THIS FILE, FOR layer-drift.sh's REASON (its header carries the
# measurement). bash 3.2 stages every `<<<` to a temp file, and when that write fails -- `ulimit -f`,
# a full or read-only TMPDIR -- it runs the command with EMPTY stdin and the command's own exit:
# a loop runs zero times, a `grep -q` answers "absent". Here that read as no retire keys, no
# exec-bit finding and no dangling hook, each a clean answer.
#
# ap_stage <name> <value> -- writes the bytes a here-string would feed (`printf '%s\n'`) to
# $AP_TMP/<name> and returns the write's status. Loops then read the file in the main shell, so a
# counter set in the body survives. The builtin `printf` writes into a PIPE, never into the file:
# a failed builtin write leaves its unflushed bytes in this shell's stdout buffer, and the next
# write to stdout -- a manifest row -- carries them (measured on bash 3.2.57 under `ulimit -f 4`:
# the tail of the lost value printed ahead of the next row). A pipe cannot fail that way; `cat`,
# a child, takes the write error, and `pipefail` (set above) hands its status back.
#
# THE FIRST FAILED WRITE ENDS ALL STAGING FOR THE RUN. A staging directory that refused one write
# is not trusted for the next, so every later call refuses without writing, and every caller
# reports its own section through ap_staging_refused rather than reading an empty input.
#
# NL_CH is A LITERAL NEWLINE, for the whole-line membership tests in this file. Newline-separated
# lists need the candidate bracketed with newlines: a bare `*"$ovr"*` matches any path that
# CONTAINS this one, and override paths share long prefixes by construction. Built as an
# assignment rather than through `$( )`, which strips the trailing newline this needs. Defined
# here, above the phase guard, because `--finish` uses it too.
NL_CH='
'
ap_stage_dead=0
fv_unapplied=""
ap_stage() {
  local _rc=0
  { [ -n "$AP_TMP" ] && [ "$ap_stage_dead" = 0 ]; } || return 125
  printf '%s\n' "$2" | cat > "$AP_TMP/$1" || _rc=$?
  [ "$_rc" -eq 0 ] || ap_stage_dead=1
  return "$_rc"
}
# ap_staging_refused <subject> <what could not be staged> <rc> <remedy> -- the one spelling of the
# row. A WORKLIST under `--finish`, which gates on WORKLIST alone, so the finisher withholds rather
# than stamping over a section it could not read; a DECISION on the ordinary run, which withholds
# on both. It clears when the staging directory can be written again.
ap_staging_refused() {
  local _k=DECISION
  [ "$FINISH" = 1 ] && _k=WORKLIST
  say "$_k" staging-refused "$1" "$2 could not be staged (exit $3), so this section is UNKNOWN, not clean, and no row it would have produced was emitted. Check that TMPDIR (${TMPDIR:-/tmp}) is writable and has space and that no file-size limit is set, then $4"
}
# ap_stage_or_refuse <name> <value> <subject> <what> -- ap_stage, and on a failed write the
# staging-refused row plus a mechanical failure on the ordinary run. Returns 1 when the caller's
# loop must not run: it would read a file that was never written. The row-rendering loops of
# phase 3 use this; a loop that feeds the stamp decision states its own routing at its site.
#
# THE REMEDY IS THE ONE THAT CAN CLEAR THE ROW IN THIS MODE. These sites run AFTER the ordinary
# run's writes, where a bare re-run is refused by the union gate (the approved report describes the
# tree before this run moved it), so the ordinary run names `reapply_remedy` -- which `say` counts
# into `reapply_owed`, and the withheld row then names that procedure rather than `--finish`. Under
# `--finish` nothing was written and re-running it is the exit.
ap_rerun_remedy="$reapply_remedy"
[ "$FINISH" = 1 ] && ap_rerun_remedy="re-run --finish."
ap_stage_or_refuse() {
  local _rc=0
  ap_stage "$1" "$2" || _rc=$?
  [ "$_rc" -ne 0 ] || return 0
  ap_staging_refused "$3" "$4" "$_rc" "$ap_rerun_remedy"
  [ "$FINISH" = 1 ] || mech_fail=$((mech_fail+1))
  return 1
}

# --- THE IN-FLIGHT MARKER, AND THE CLASSIFY FILES IT RECORDS -----------------------------------
#
# A FILE HANDED BACK AS A SEMANTIC MERGE KEEPS A CONSUMER DELTA WHETHER OR NOT ANYONE MERGED IT, so
# preclassify buckets it `*CLASSIFY*` on every later run and `--finish` cannot read "merged" off the
# bucket. Measured in apply-drift-refile arm t's both-changed world: the ordinary run withheld on
# `WORKLIST semantic-merge`, and `--finish` on the untouched tree raised no row and stamped theirs
# with the merge never done. The tree carries no other trace of the merge, so the ordinary run
# records one: per `*CLASSIFY*` row -- the apply loop's own pattern, so a bucket that loop hands back
# is a bucket this records -- the consumer path's blob as it stood BEFORE any write. `--finish`
# withholds while a recorded file is still byte-identical to that blob (finish_classify_unmerged).
#
# KEYED ON THE CONSUMER PATH, column 3 of preclassify's row, because that is the file the operator
# edits. A SETUP-SITED path is excluded: setup fills its tokens, so it already gets `NOTE
# finish-unverified` and never withholds, and this record must not start withholding it. A path that
# is ABSENT on the consumer is not recorded: nothing can be byte-identical to it, and a deletion is a
# disposition. An existing path whose blob cannot be read records `-`, which `--finish` withholds on.
#
# THE BLOB AND THE EXEC BIT, BOTH. A range can change only a file's mode: theirs adds +x to a script
# the consumer edited, preclassify buckets it BOTH-CHANGED->CLASSIFY, and the whole merge is a
# `chmod +x` that leaves the blob alone. A blob-only record read that finished merge as untouched and
# withheld forever. The line is `classify: <blob> <755|644><TAB><path>`; a change in either is touched.
#
# NOT RECORDED WHERE THEIRS HAS NOTHING AT THE PATH TO MERGE IN: `UPSTREAM-DELETED+consumer-modified`
# (theirs deleted it) and `ORPHANED-UNKNOWN` (no release ever shipped it). Keeping the consumer's copy
# byte-for-byte is the NORMAL disposition for both, so a record would withhold on the ordinary
# outcome and send every such pull through the no-op exit. They are still handed back as
# `semantic-merge` and still listed there; only this check stands down for them.
#
# FIRST WRITE WINS, ACROSS EVERY RUN THAT STARTS FROM THE SAME BASE. The re-run that `reapply_remedy`
# prescribes runs this again over a tree where the operator may already have merged; recording that
# run's blob would make the merged copy the reference and the finisher would then withhold on the
# merge itself. The blob being recorded is a fact about the tree the pull STARTED from, so it is keyed
# on `base:` alone -- compared by `core/` tree -- and NOT on `theirs:`: a pull re-pointed at a newer
# theirs after a merge, or a second pull from the same base, still started from the same tree. Only a
# marker from another base is started fresh.
#
# A SAME-BASE MARKER WITH NO `classify-hashes:` LINE STAYS UNRECORDED. That is a marker an engine
# without this record wrote -- on the pull that DELIVERS this engine, the first ordinary run is the old
# one -- and the tree may already carry the operator's merges, so any blob read now could be a merged
# copy. This run writes no hash lines and no `classify-hashes:` line, and `--finish` says so on a NOTE.
#
# `classify-hashes: <n>` IS OTHERWISE ALWAYS WRITTEN, zero included. Without it a marker from this
# engine with no CLASSIFY row is byte-identical to one the previous engine wrote. The lines are SORTED
# so a re-run over the same state writes the same bytes: `self-update-gate.sh` records this file's
# digest and its runner compares it strictly, so a marker whose bytes moved without an apply having
# run would read as one that had.
#
# A DIRECTORY AT THE MARKER'S PATH IS A REFUSAL. `mv -f` moves the new file INTO it and exits 0, so the
# write reports success, nothing reads the record, and `core/git-hooks/pre-push` (which tests `-f`)
# never blocks.
#
# WRITTEN THROUGH A PIPE AND RENAMED, NEVER A BUILTIN REDIRECT. A failed builtin `printf > file`
# leaves its unflushed bytes in this shell's stdout and the next manifest row carries them (see
# ap_stage). A marker that could not be written is a DECISION: the fixture suite would then run over
# a mid-pull tree, and `--finish` would have no record to check the merges against.
ap_write_marker() {
  local _old="" _keep="" _rows="" _st _p _c _b _h _m _tab _n _ob _bt _tmp _rc=0 _sited _rest _l _unrec=0
  _tab="$(printf '\t')"
  if [ -d "$APPLYING" ]; then
    say DECISION applying-marker-unwritten "${APPLYING#"$CONSUMER"/}" "the in-flight marker's path is a DIRECTORY, so the marker cannot be written there: the fixture suite will not block on this mid-pull tree (\`core/git-hooks/pre-push\` tests for a file) and \`--finish\` has no record of which handed-back merges were still untouched. Remove that directory, then re-run apply with the same four arguments."
    return 0
  fi
  if [ -f "$APPLYING" ]; then
    _old="$(cat "$APPLYING" 2>/dev/null)" || _old=""
    _ob="$(printf '%s\n' "$_old" | sed -n 's/^base:[[:space:]]*//p' | head -1)"
    _bt="$(git -C "$DIST" rev-parse -q --verify "${BASE}:core" 2>/dev/null)"
    if [ -n "$_ob" ] && [ -n "$_bt" ] \
       && [ "$(git -C "$DIST" rev-parse -q --verify "${_ob}:core" 2>/dev/null)" = "$_bt" ]; then
      case "${NL_CH}${_old}" in
        *"${NL_CH}classify-hashes: "*) _keep="$(printf '%s\n' "$_old" | awk '/^classify: /')" ;;
        *) _unrec=1 ;;
      esac
    fi
  fi
  # The setup-sited set, loaded by preclassify's own `setup_sited_paths()` and status-checked at
  # every step: a function that did not load, or a manifest it could not read (4), would make every
  # sited path look unsited and record a CLASSIFY hash for a file `--finish` must not judge by bytes.
  _sited=""; _rc=0
  eval "$(awk '/^setup_sited_paths\(\) \{/,/^\}/' "$SELF/preclassify.sh" 2>/dev/null)" || _rc=$?
  command -v setup_sited_paths >/dev/null 2>&1 || _rc=127
  [ "$_rc" -ne 0 ] || _sited="$(setup_sited_paths)" || _rc=$?
  if [ "$_rc" -ne 0 ]; then
    say DECISION applying-marker-unwritten "${APPLYING#"$CONSUMER"/}" "the setup-sited path set could not be loaded out of preclassify.sh's \`setup_sited_paths()\` (exit ${_rc}), so which handed-back merges are setup-filled is unknown and the in-flight marker was not written: the fixture suite will not block on this mid-pull tree and \`--finish\` has no record to check the merges against. Check that reconcile/setup-sites.md and preclassify.sh are present and readable, then re-run apply with the same four arguments."
    return 0
  fi
  _rc=0
  # Walked by parameter expansion over the rows already in memory: no heredoc or here-string whose
  # staging could fail and read as "no CLASSIFY rows".
  _rest="$PC"
  while [ -n "$_rest" ]; do
    _l="${_rest%%"$NL_CH"*}"
    case "$_rest" in *"$NL_CH"*) _rest="${_rest#*"$NL_CH"}" ;; *) _rest="" ;; esac
    _st="${_l%%"$_tab"*}"; _l="${_l#*"$_tab"}"
    _p="${_l%%"$_tab"*}";  _l="${_l#*"$_tab"}"
    _c="${_l%%"$_tab"*}";  _b="${_l#*"$_tab"}"
    [ "$_unrec" = 0 ] || break
    case "$_b" in *CLASSIFY*) ;; *) continue ;; esac
    case "$_b" in UPSTREAM-DELETED*|ORPHANED-UNKNOWN*) continue ;; esac
    [ -n "$_c" ] || continue
    case "${NL_CH}${_sited}${NL_CH}" in *"${NL_CH}${_p}${NL_CH}"*) continue ;; esac
    case "${NL_CH}${_keep}${NL_CH}" in *"${_tab}${_c}${NL_CH}"*) continue ;; esac
    [ -e "$CONSUMER/$_c" ] || continue
    _h="$(git hash-object "$CONSUMER/$_c" 2>/dev/null)" || _h=""
    _m=644; [ -x "$CONSUMER/$_c" ] && _m=755
    _rows="${_rows}classify: ${_h:--} ${_m}${_tab}${_c}${NL_CH}"
  done
  _rows="$(printf '%s\n%s' "$_keep" "$_rows" | awk 'NF' | sort -t "$_tab" -k2,2 -u)"
  _n="$(printf '%s' "$_rows" | awk 'NF {n++} END {print n+0}')"
  _tmp="$APPLYING.incoming.$$"
  { printf 'base: %s\ntheirs: %s\n' "$BASE" "$THEIRS"
    if [ "$_unrec" = 0 ]; then
      printf 'classify-hashes: %s\n' "$_n"
      [ -z "$_rows" ] || printf '%s\n' "$_rows"
    fi
  } | cat > "$_tmp" 2>/dev/null || _rc=$?
  [ "$_rc" -eq 0 ] && { mv -f "$_tmp" "$APPLYING" 2>/dev/null || _rc=$?; }
  if [ "$_rc" -ne 0 ]; then
    rm -f "$_tmp" 2>/dev/null
    say DECISION applying-marker-unwritten "${APPLYING#"$CONSUMER"/}" "the in-flight marker could not be written (exit ${_rc}), so the fixture suite will not block on this mid-pull tree and \`--finish\` has no record of which handed-back merges were still untouched. Check that .claude/ is writable and that no file-size limit is set, then re-run apply with the same four arguments."
  fi
  return 0
}

# --- THE EXEC-BIT AUDIT, ONE BODY FOR BOTH MODES -----------------------------------------------
#
# LEVEL, NOT EDGE: it reads the whole shipped set against the tree as it stands, so it answers the
# same question on the ordinary run and under `--finish`. The ordinary run raises a DECISION per
# finding and counts it a mechanical failure (the rationale is at the call site in the resolution
# phases). Under `--finish` each finding is a WORKLIST row: the finisher used to skip this audit
# and stamped theirs over a 100755 validator still not executable, which is BL-402. There the fix
# is the `chmod` itself -- this audit re-runs on the next `--finish` and clears when it is done.
#
# THE LISTING'S STATUS IS READ. It used to be captured with its status discarded, so a failed
# `ls-tree` was an audit that named nothing -- a clean audit. Each line carries its direction
# (`N` = 100755 not executable, `X` = 100644 executable).
exec_audit() {
  local _ne _rc=0 mode _cp _rel cons _tab _dir
  _tab="$(printf '\t')"
  _ne="$(git -C "$DIST" -c core.quotePath=false ls-tree -r "$THEIRS" -- core/ 2>/dev/null \
    | awk '$1=="100755" || $1=="100644" { m = $1; sub(/^[^\t]*\t/, ""); print m "\t" $0 }')" || _rc=$?
  if [ "$_rc" -eq 0 ] && [ -z "$_ne" ]; then _rc=empty; fi
  if [ "$_rc" != 0 ]; then
    ap_staging_refused "core/" "the mode listing of \`${THEIRS}:core/\` (git ls-tree)" "$_rc" "$ap_rerun_remedy"
    [ "$FINISH" = 1 ] || mech_fail=$((mech_fail+1))
    return 0
  fi
  _rc=0; ap_stage exec-audit "$_ne" || _rc=$?
  if [ "$_rc" -ne 0 ]; then
    ap_staging_refused "core/" "the mode listing of \`${THEIRS}:core/\`" "$_rc" "$ap_rerun_remedy"
    [ "$FINISH" = 1 ] || mech_fail=$((mech_fail+1))
    return 0
  fi
  while IFS="$_tab" read -r mode _cp; do
    [ -n "$mode" ] || continue
    _rel="${_cp#core/}"
    cons="$(consumer_path "$_rel" 2>/dev/null)" || continue
    # Not every shipped file lands on every consumer (ci-templates only with
    # .github/, for one). Absent is a different finding, covered above.
    [ -f "$cons" ] || continue
    # The direction is decided ONCE, by one test per direction, for both modes.
    _dir=""
    if [ "$mode" = 100755 ] && [ ! -x "$cons" ]; then _dir=N
    elif [ "$mode" = 100644 ] && [ -x "$cons" ]; then _dir=X
    fi
    [ -n "$_dir" ] || continue
    if [ "$FINISH" = 1 ]; then
      # finish_verify_tree() OWNS a file in the range: its `finish-unapplied` row already names a
      # missing exec bit, so this audit stands down for that path and owns only the rest.
      case "${NL_CH}${fv_unapplied}${NL_CH}" in *"${NL_CH}${cons#"$CONSUMER"/}${NL_CH}"*) continue ;; esac
      case "$_dir" in
        N) say WORKLIST finish-exec-owed "${cons#"$CONSUMER"/}" \
             "upstream ships this 100755 but the consumer copy is not executable — installed and inert, and the stamp would claim theirs over it. \`chmod +x\` it, then re-run --finish: this audit runs again there and clears when the bit is set." ;;
        X) say WORKLIST finish-exec-owed "${cons#"$CONSUMER"/}" \
             "upstream ships this 100644 but the consumer copy is executable, and the stamp would claim theirs over it. \`chmod -x\` it, then re-run --finish: this audit runs again there and clears when the bit is cleared." ;;
      esac
      continue
    fi
    case "$_dir" in
      N) say DECISION not-executable "${cons#"$CONSUMER"/}" \
           "upstream ships this 100755 but the consumer copy is not executable — installed and inert; every call site that invokes it directly fails until it is fixed. \`chmod +x\` it, then ${reapply_remedy}" ;;
      X) say DECISION extra-executable "${cons#"$CONSUMER"/}" \
           "upstream ships this 100644 but the consumer copy is executable — a bit upstream does not grant, left by an earlier pull or by hand, and no later pull clears it unless it happens to rewrite this file. \`chmod -x\` it, then ${reapply_remedy}" ;;
    esac
    mech_fail=$((mech_fail+1))
  done < "$AP_TMP/exec-audit"
  return 0
}

# --- THE KNOWN_SKILLS REFILE'S DIFF, ONE BODY FOR BOTH MODES -----------------------------------
#
# ap_ks_diff <rel> <consumer-file> -- sets `ap_d` to diff(theirs, consumer) and `ap_drc` to its
# status, or `staging-failed` when theirs could not be staged. Theirs is STAGED and diff's rc read
# off the bare run (0/1 ran, >=2 refused): the old `diff <(git show …) | …` read no status at all,
# and the `<( )` fd race (3-8 in 2000 under 4 bash 3.2 workers, batch 160) exits 2 -- which read
# as "no known_skills added". Piped through `ap_pdiff`; a failed `cat` is 2.
# ap_ks_added <diff> -- the skill names the CONSUMER side carries and theirs does not.
ap_ks_diff() {
  ap_d=""; ap_drc=staging-failed
  if [ -n "$AP_TMP" ] && git -C "$DIST" show "${THEIRS}:core/${1}" > "$AP_TMP/theirs" 2>/dev/null; then
    ap_d="$(ap_pdiff "$AP_TMP/theirs" "$2" 2>/dev/null)"; ap_drc=$?
  fi
  return 0
}
#
# A CONSUMER LINE THAT DIFFERS FROM A THEIRS LINE ONLY BY A TRAILING COMMA ADDS NOTHING. Appending
# an entry to a JSON list puts a comma on the line above it, so diff carries that unchanged entry
# on the consumer side too, and every name on it read as "added by the consumer": the refile wrote
# a theirs entry into the extension, and `--finish` demanded it of a hand-done refile forever. Each
# `>` line is cancelled against a `<` line equal to it once leading space and a trailing comma are
# stripped, LINE BY LINE -- never by subtracting names, which would drop a consumer skill whose
# name also appears on some unrelated changed line of theirs, and the overwrite would then lose it.
ap_ks_added() {
  printf '%s\n' "$1" | awk '
    function ks_norm(s) { s = substr(s, 3); sub(/^[[:space:]]+/, "", s); sub(/,?[[:space:]]*$/, "", s); return s }
    /^< / { old[ks_norm($0)]++; next }
    /^> / { n++; new_n[n] = ks_norm($0); new_r[n] = substr($0, 3); next }
    END { for (i = 1; i <= n; i++) { if (old[new_n[i]] > 0) { old[new_n[i]]--; continue } print new_r[i] } }' \
    | grep -oE '"[^"]+"' | tr -d '"' | grep -v '^known_skills$' | sort -u
}

# --- THE IN-PLACE-EDIT GATE, ONE BODY FOR BOTH MODES -------------------------------------------
#
# ud_capture [<bucket-rows-file>] -- runs unregistered-drift.sh and sets `UD` (the paths it calls
# HARD-UNREGISTERED-CORE-DRIFT, one per line), `UD_RC` (its exit) and `UD_NA` (the detail of a
# HARD-DRIFT-SCAN-UNAVAILABLE row, empty when there was none). It emits nothing: the ordinary run
# raises a DECISION on a refusal, `--finish` a WORKLIST, and each says so at its own call site.
#
# THE ORDINARY REFILE ENTERS ONLY FOR A PATH IN `UD`, and `--finish` used to drop that gate and diff
# theirs against the consumer copy directly. A schema the consumer never touched, in a range where
# upstream retired a skill, then carried the retired name on the consumer side, and `--finish` told
# the operator to add it to the extension -- bringing back a skill upstream removed. Both modes now
# ask this one function whether the schema is an in-place edit at all.
#
# The bucket rows are handed down through `UD_FLAG`/`UD_PC`, which each caller sets first (phase 0
# from `$PC`, `--finish` from finish_verify_tree's staged rows); empty `UD_FLAG` derives them.
ud_capture() {
  if [ -n "$UD_FLAG" ]; then
    detector_run ud unregistered-drift.sh "$UD_FLAG" "$UD_PC" "$DIST" "$BASE" "$CONSUMER" "$THEIRS"
  else
    detector_run ud unregistered-drift.sh "$DIST" "$BASE" "$CONSUMER" "$THEIRS"
  fi
  UD_RC=$?
  UD=""; UD_NA=""
  [ "$UD_RC" = 0 ] || return 0
  UD="$(awk -F'\t' '$1=="HARD-UNREGISTERED-CORE-DRIFT"{print $2}' "$DT_DIR/ud.out")"
  UD_NA="$(awk -F'\t' '$1=="HARD-DRIFT-SCAN-UNAVAILABLE"{print $3; exit}' "$DT_DIR/ud.out")"
  return 0
}

# =============================================================================================
# THE RESOLUTION PHASES. Everything to the matching `fi` -- phases 0 through the exec-bit audit
# -- is what `--finish` SKIPS. That mode exists to advance a stamp this program deliberately
# withheld on an earlier run, over a tree the caller has since finished by hand; re-running the
# phases there would not merely be wasted work, it would NOT TERMINATE. A file the caller
# semantically merged keeps a consumer delta by definition, so preclassify buckets it
# BOTH-CHANGED->CLASSIFY on every subsequent run (preclassify.sh, the `ours_h` comparisons) and
# the hand-back re-appears forever. The finisher must therefore be the stamp and nothing else.
# =============================================================================================
if [ "$FINISH" = 0 ]; then

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
#
# A CLASSIFIER THAT DID NOT CLASSIFY STOPS THE RUN BEFORE PHASE 1 WRITES ANYTHING. This was
# `2>/dev/null || true`, so a preclassify that exited 2 on a failed git call handed phase 1 an
# empty or partial row set, and the run went on to write and re-stamp as though that were the
# whole pull. Same two refusals as `--finish`'s tree check below and emit-report's render: a
# non-zero exit, and no rows while `base..theirs` changes `core/`. It stops through `err`, the
# shape the union gate above uses to refuse a stale report, and it names that nothing was written.
# The in-flight marker is written only AFTER these two refusals, so a stop here leaves the tree
# exactly as it was -- no marker for the next push to block on over a tree nothing touched. A
# marker a PREVIOUS aborted run left is not this run's to remove, and is left alone.
PC="$(bash "$SELF/preclassify.sh" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" 2>/dev/null)"
PC_RC=$?
if [ "$PC_RC" -ne 0 ]; then
  err "preclassify.sh exited ${PC_RC} without classifying, so which files this pull writes, merges or deletes is UNKNOWN. NOTHING HAS BEEN WRITTEN to core. Run reconcile/preclassify.sh $DIST $BASE $THEIRS $CONSUMER directly, fix what it reports, then re-run apply with the same four arguments."
fi
if [ -z "$PC" ]; then
  PC_RNG="$(git -C "$DIST" -c core.quotePath=false diff --name-only "$BASE" "$THEIRS" -- core/ 2>/dev/null)" \
    || err "preclassify.sh returned no rows and whether \`${BASE}..${THEIRS}\` changes \`core/\` could not be read. NOTHING HAS BEEN WRITTEN to core. Re-run apply with the same four arguments."
  [ -z "$PC_RNG" ] \
    || err "preclassify.sh returned no rows while \`${BASE}..${THEIRS}\` changes \`core/\`, which is not the same as nothing to apply. NOTHING HAS BEEN WRITTEN to core. Run reconcile/preclassify.sh $DIST $BASE $THEIRS $CONSUMER directly, fix what it reports, then re-run apply with the same four arguments."
fi

# The in-flight marker (see IN-FLIGHT MARKER above): ahead of every core write below. It also
# records the consumer blob of every file this run hands back as a semantic merge, so `--finish`
# can tell a merged file from one nobody touched (see ap_write_marker / finish_classify_unmerged).
ap_write_marker
# THE BUCKETS ARE HANDED DOWN, NOT RE-DERIVED. `unregistered-drift.sh`'s CORE-MACHINERY-CARRIED
# arm needs exactly the rows already in `$PC` -- same four arguments, same program -- and running
# preclassify a second time costs ~1.1s on any pull where the scan reaches a file past its
# byte-identity arms, carried or not (the derivation is lazy, so a consumer with no in-place core
# edit never pays it). Written
# to a file rather than passed as an argument because the rows are multi-line TSV. Same shape as
# `hard-blockers.sh`'s `--ud-rows`, and it does not change the scan's answer: without the flag
# the scan derives the identical rows itself, which the fixture asserts row-for-row.
#
# AN EMPTY FILE IS NOT AN ACQUITTAL. The scan's own guard refuses to read "no buckets" as "nothing
# diverged" while the range still moves core/, so a write that failed here leaves every carried
# path at its HARD row rather than silently clearing it.
#
# STAGED THROUGH ap_stage, NOT A BUILTIN REDIRECT. `printf … > "$UD_PC"` with its status unread
# left the bytes a failed write could not flush in this shell's stdout, and the next manifest row
# carried them: under `ulimit -f` 14 and 20 an ordinary apply printed a malformed row such as
# `.sh<TAB>UPSTREAM-ONLY`. A failed stage is a refusal; the scan then derives its own rows.
UD_PC=""
UD_FLAG=""
ud_pc_rc=0; ap_stage ud-bucket-rows "$PC" || ud_pc_rc=$?
if [ "$ud_pc_rc" -eq 0 ]; then
  UD_PC="$AP_TMP/ud-bucket-rows"
  UD_FLAG="--bucket-rows"
else
  ap_staging_refused "core/" "the preclassify bucket rows handed to unregistered-drift.sh" "$ud_pc_rc" "re-run apply with the same four arguments."
  mech_fail=$((mech_fail+1))
fi
# THE DETECTOR'S STDOUT, STDERR AND EXIT ARE STAGED AND READ, NOT PIPED PAST. This was
# `$(bash unregistered-drift.sh … 2>/dev/null | awk …)`: a detector that exited non-zero with
# empty stdout, or that emitted HARD-DRIFT-SCAN-UNAVAILABLE (its own "nothing was scanned" row,
# which it emits with exit 0 by contract -- exit 2 when that row itself could not be written),
# handed the drift loop below an empty list -- read as
# "no in-place core edit" -- and the run went on to overwrite core. Either now draws a DECISION
# row, which withholds the re-stamp; `detector_refused` is the one spelling of it.
ud_capture
if [ "$UD_RC" -ne 0 ]; then
  detector_refused unregistered-drift unregistered-drift.sh "-" "$UD_RC" ud
else
  if [ -n "$UD_NA" ]; then
    say DECISION unregistered-drift-refused "-" "DETECTOR-REFUSED: unregistered-drift.sh emitted HARD-DRIFT-SCAN-UNAVAILABLE — this section is NOT a finding of 'none'; ${UD_NA}"
  fi
fi
[ -n "$UD_PC" ] && rm -f "$UD_PC"

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

# `--bucket-rows` FOR retired-tokens.sh, THE SAME HAND-DOWN `unregistered-drift.sh` GETS ABOVE.
# That detector ran `preclassify.sh "$DIST" "$BASE" "$THEIRS" "$CONSUMER"` itself -- byte-for-byte
# `:486` -- once per CLASSIFY row of the loop below. It gets its own staged file, beside `$UD_PC`'s.
#
# MATERIALISED AFTER THE FIXTURES-LAST REORDER, which is safe because the detector derives its
# subject set through `sort -u`: the rows it receives are the same SET in a different order, and
# order is normalised away before anything reads them.
#
# THE FLAG IS PASSED ONLY WHEN THE WRITE SUCCEEDED. An empty handed-down file must never stand in
# for a real derivation -- "no rows" and "no retired token" are the same stdout, and the
# detector's refusal goes to stderr, which the call below discards. It falls back to deriving on
# an empty file for exactly that reason.
#
# STAGED THROUGH ap_stage FOR THE REASON THE `UD_PC` STAGE ABOVE GIVES. The redirect's status was
# read here, but a failed builtin write still leaked its tail into the next manifest row. A failed
# stage is a refusal row and a mechanical failure, not a quiet fall-back: the run already withholds
# (ap_stage_dead makes the bucket stage below refuse too), so the row names the cause.
RT_PC=""
rt_pc_rc=0; ap_stage rt-bucket-rows "$PC" || rt_pc_rc=$?
if [ "$rt_pc_rc" -eq 0 ]; then
  RT_PC="$AP_TMP/rt-bucket-rows"
else
  ap_staging_refused "core/" "the preclassify bucket rows handed to retired-tokens.sh" "$rt_pc_rc" "re-run apply with the same four arguments."
  mech_fail=$((mech_fail+1))
fi

# ---------------------------------------------------------------- 1. buckets (preclassify)
# Every loop below reads a STAGED file, never a heredoc: bash 3.2 stages a heredoc to a temp file
# too, and when that write fails it runs the loop on EMPTY stdin -- zero rows, read as zero work.
# A failed stage is a refusal that withholds the stamp (ap_stage, above the phase guard).
bk_rc=0; ap_stage buckets "$PC" || bk_rc=$?
if [ "$bk_rc" -ne 0 ]; then
  ap_staging_refused "core/" "the preclassify bucket rows (what this pull writes, merges and deletes)" "$bk_rc" "re-run apply with the same four arguments."
  mech_fail=$((mech_fail+1))
else
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
      # Staged and its exit read (see `detector_run`). A refusal does NOT cancel the merge: the
      # file still needs merging, so the plain `semantic-merge` row is emitted as always, and the
      # refusal row beside it says the token check behind it never ran.
      if [ -n "$RT_PC" ]; then
        detector_run rt retired-tokens.sh --bucket-rows "$RT_PC" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" "$path"
      else
        detector_run rt retired-tokens.sh "$DIST" "$BASE" "$THEIRS" "$CONSUMER" "$path"
      fi
      rt_rc=$?
      rt=""
      if [ "$rt_rc" -ne 0 ]; then
        say WORKLIST semantic-merge "$rel"
        detector_refused retired-tokens retired-tokens.sh "$rel" "$rt_rc" rt
      elif rt="$(awk -F'\t' '{print $3}' "$DT_DIR/rt.out" | paste -sd' ' -)" && [ -n "${rt:-}" ]; then
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
done < "$AP_TMP/buckets"
fi
[ -n "$RT_PC" ] && rm -f "$RT_PC"

# --- 1b. RETIRED CORE PASSAGES STILL CARRIED BY A LAYER FILE ---------------------------------
#
# THE DETECTOR IS SOUND AND ITS REMEDY CHANNEL WAS PROSE. `retired-layer-passage.sh` asks whether
# a consumer layer file still carries a LINE core had at base and deleted by theirs, and its rows
# reached `emit-report.sh`s report section and nothing else. The sibling TOKEN case has been wired
# into the worklist since the `*CLASSIFY*` arm above gained its `retired-tokens.sh` call, so the
# asymmetry sat inside this one file: one row for the token class, none for the passage class,
# while `ai-dlc-update/SKILL.md` step 3a-iv says in as many words that a passage row "is a worklist
# item". A consumer reads the worklist; a report section is read by whoever happens to read it.
#
# ONCE PER RUN, NOT ONCE PER PATH. The detector answers about the whole layer corpus in one call
# and its subject is a layer file, which the `*CLASSIFY*` loop above never iterates. Siting it
# inside that arm would fork the detector per classified path and ask it the same question every
# time.
#
# THE DETAIL SAYS RE-POINT, AND THAT IS A MEASUREMENT RATHER THAN A WORDING PREFERENCE. On the
# release pair that motivated this row, every reported row cited a line core STILL CARRIES at
# theirs -- the text was re-sited into another rulebook file, not retired. The detector cannot
# tell a move from a death, because its input is the removed-line set of one path glob; the
# remedy on a re-siting release is therefore a new citation, and a row that said "delete" would
# instruct the consumer to destroy text that is still current.
#
# INSIDE THE `FINISH=0` SPAN, DELIBERATELY, AND THE SITING IS THE LOAD-BEARING PART. `say`
# increments `handback` and `worklist_n`, and `--finish` gates its stamp on `worklist_n` alone.
# A row emitted where the trailing `hook_registration_row` / `transient_ignore_row` /
# `agent_definitions_row` run would be re-derived by the finisher, on a tree whose layer files the
# apply never rewrites, before `write_stamp` -- so the stamp would be withheld, `.ai-dlc-applying`
# would stay, and `core/git-hooks/pre-push` would refuse every push with no exit. The second
# disposition SKILL.md offers ("record why reproducing the retired text is still correct") changes
# nothing this detector reads and `layer-contract.yaml` carries no acknowledgement channel for it,
# so there is no work that clears such a row. Here the row is a hand-back on the ordinary run and
# `--finish` is the exit, which is the terminating shape the two counters above exist to preserve.
#
# STDERR IS DISCARDED AT THIS CALL SITE, AS AT EVERY OTHER IN THIS FILE, AND THAT MAKES ONE
# SILENCE INDISTINGUISHABLE FROM ANOTHER. The detector refuses to report clean when it cannot read
# `setup-sites.md`, but it refuses ON STDERR and returns no rows -- so a staging that ships this
# directory's `*.sh` without its `*.md` produces zero rows and no row here, which reads exactly
# like a clean corpus. The failure is in the safe direction (a missed row, never a false one) and
# it is the fixture that must assert the corpus was readable, not this driver.
#
# THE EXIT AND STDERR ARE NOW READ, and a non-zero exit is a DECISION row emitted after this block
# (see `detector_refused`). The unreadable-`setup-sites.md` refusal above still exits 0 and is
# still the residue described there. The capture stays one `$( )` of the bare detector, which
# carries its status, and this line keeps its column-0 opening: apply-restamp-worklist's BL
# mutants anchor on it, and on the FIRST column-0 `fi` after it, so the refusal check sits below
# that `fi` and reads the status with a default for the mutants that move this block.
RLP_OUT="$(bash "$SELF/retired-layer-passage.sh" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" 2>"${DT_DIR:-/nonexistent-apply-staging}/rlp.err")"; RLP_RC=$?
RLP_N="$(printf '%s\n' "$RLP_OUT" | awk -F'\t' '$1=="RETIRED-LAYER-PASSAGE"{n++} END{print n+0}')"
case "${RLP_N:-0}" in ''|*[!0-9]*) RLP_N=0 ;; esac
if [ "$RLP_N" -gt 0 ]; then
  RLP_FILES="$(printf '%s\n' "$RLP_OUT" \
    | awk -F'\t' '$1=="RETIRED-LAYER-PASSAGE"{p=$2; sub(/:[0-9]+$/,"",p); print p}' | sort -u)"
  RLP_NF="$(printf '%s\n' "$RLP_FILES" | sed '/^$/d' | wc -l | tr -d ' ')"
  RLP_LIST="$(printf '%s\n' "$RLP_FILES" | sed '/^$/d' | tr '\n' ' ')"
  # ON ONE LINE, LIKE THE TOKEN ROW ABOVE, AND THAT IS NOT A STYLE CHOICE. Every binding on this
  # class keys on the line that EMITS -- `^[[:blank:]]*say WORKLIST …` plus the class name -- and
  # a backslash continuation puts the class name on a line the anchor cannot reach, so the row
  # would exist and every grammar watching for it would read the same clean zero as its absence.
  say WORKLIST retired-layer-passage ".claude/skills/ai-dlc/" "${RLP_N} RETIRED-LAYER-PASSAGE row(s) across ${RLP_NF} layer file(s): each reproduces a rulebook line core carried at ${BASE} and no longer carries at ${THEIRS}. RE-POINT each one at the wording core carries now — measured on a re-siting release, every such row cited text that had MOVED to another rulebook file rather than been retired, so the remedy is a new citation and never a deletion. File(s): ${RLP_LIST}. Re-run \`reconcile/retired-layer-passage.sh <dist> ${BASE} ${THEIRS} <consumer>\` afterwards; an empty result is the clear, and read its stderr — a run that opened no layer file says so there and is not the same as finding none. This does NOT block the apply: a layer file is consumer-owned and this program never rewrites one."
fi
if [ "${RLP_RC:-0}" -ne 0 ]; then
  detector_refused retired-layer-passage retired-layer-passage.sh "-" "$RLP_RC" rlp
fi

# --- 1c. RECORDED DERIVATIONS STRANDED BY THE SAME RELOCATION --------------------------------
#
# THE SAME ASYMMETRY ONE POPULATION OVER. The rows above are about a layer file reproducing core
# TEXT. This one is about a planning artifact whose ```derived fence EXECUTES a core path: the
# fence records a command and the output it produced, and when core text is re-sited the command
# runs against a file that no longer holds the text it was written to measure. It does not fail
# loudly. It re-runs green or red by accident of what still resolves at the old path.
#
# A ROUTING ROW, NOT A SECOND DETECTOR, BECAUSE THE DETECTOR ALREADY SHIPS.
# `core/scripts/validate-artifact-derivations.sh` re-runs every fenced command and names the ones
# that no longer reproduce; building a staleness check here would split that corpus in two and
# neither half would see everything. What is missing is not the check, it is the routing: nothing
# on the pull path tells a consumer that this release is the one that stranded its citations.
#
# THE GATE IS A PATH JOIN AND IT DECIDES RELEVANCE, NEVER STALENESS. It asks only whether some
# fenced command names a core path this range CHANGED. It does not parse a derivation, does not
# run one, and reaches no verdict about any of them -- the validator named in the row owns that
# question, on the operator's invocation.
#
# CHANGED, NOT DELETED, AND THE DIFFERENCE IS THE WHOLE ARM. The obvious predicate -- a fence
# naming a core path present at base and ABSENT at theirs -- scores ZERO on the case that
# motivated this row: the relocation moved text INSIDE files that exist at both ends, so no core
# path was deleted at all. A deletion-keyed gate here is a check that cannot fire, which reads
# exactly like one that passed.
#
# NOT RUN FROM HERE. The validator executes the commands it finds; parse-only over a real
# consumer's artifact corpus is tens of seconds and execution is more. An apply may spend one
# cheap scan to decide whether to NAME the work. It may not spend the work itself.
#
# GATED ON THE JOIN BEING NON-EMPTY, WHICH IS THE DECLARATION AND NOT THE VALIDATOR, and that is
# `transient_ignore_row`s measured false positive taken forward rather than re-learned. Keying an
# absent-branch on the TOOL fires on every consumer predating the mechanism -- a tree with neither
# half is not a defect, it is a tree this release has nothing to say about -- and that is what
# failed `apply-restamp-worklist`s C4, whose consumer asserts ZERO hand-back rows. A consumer with
# no artifact corpus, or one whose fences cite nothing this range touched, gets no row from either
# branch here. Only once real stranded citations exist does a missing validator become a
# reportable split.
#
# INSIDE THE `FINISH=0` SPAN FOR A REASON OF ITS OWN, NOT BY ANALOGY WITH THE ROW ABOVE. The
# remedy re-anchors a citation at the path core carries NOW -- and on the motivating range that
# replacement path is itself in the changed set, so the join still matches after the work is
# correctly done. A row whose own remedy cannot clear it must never reach the finisher, which
# gates on `worklist_n`: it would withhold the stamp forever. Here it is a hand-back on the
# ordinary run, and `--finish` is the exit.
#
# THE JOIN IS `vd_join()`, AND IT HAS TWO CALLERS. This driver decides from it whether to NAME the
# work; `reconcile/derivation-differential.sh` re-derives the row's file set from it to CHECK the
# work, lifting the function out of this file with the same `awk '/^name\(\) \{/,/^\}/'` + `eval`
# shape map_consumer() is lifted with. A second copy of the join in the helper is two statements
# of which files the row names, and the operator would be clearing a set the row never named.
# It must stay at column 0 and close on a column-0 `}` -- that is the lift's grammar.
#
# vd_join <dist> <base> <theirs> <artifact-dir>  ->  sets VD_MOVED VD_LISTED VD_SCANNED VD_HITS
# VD_NF VD_FILES. VD_FILES is the newline-joined, sorted set of artifact files carrying at least
# one hit -- the row's file set, and the helper's corpus. The scan runs only when the changed set
# is non-empty and the corpus lists at least one file; otherwise the counts are 0 and the caller's
# own guard decides.
vd_join() {
  VD_MOVED=""; VD_LISTED=0; VD_SCAN=""; VD_SCANNED=0; VD_HITS=0; VD_NF=0; VD_FILES=""
  # Consumer-relative, because that is how an artifact writes a path. `map_consumer` is the one
  # mapper this program has (loaded from preclassify.sh above); a private table here is the
  # defect I17 exists to prevent.
  VD_MOVED="$(git -C "$1" -c core.quotePath=false diff --name-only "$2" "$3" -- core/ 2>/dev/null \
    | while IFS= read -r _vp; do [ -n "$_vp" ] && map_consumer "$_vp"; done | sort -u | paste -sd'|' -)"
  VD_LISTED="$(find "$4" -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')"
  case "${VD_LISTED:-0}" in ''|*[!0-9]*) VD_LISTED=0 ;; esac
  if [ -n "${VD_MOVED:-}" ] && [ "$VD_LISTED" -gt 0 ]; then
    # THE NEEDLES RIDE IN `-v`, NOT IN A FILE awk OPENS. `getline < file` returns -1 for an
    # unopenable file and 0 for an empty one and raises nothing, so a needle set that failed to
    # load scores every artifact as a non-instance and the run reads clean. A `-v` that did not
    # bind is visible as an empty split. `|` is the separator because it cannot occur in a path
    # this mapper emits, and `awk -v` carries no newline at all.
    #
    # EACH INVOCATION REPORTS WHAT IT OPENED. `xargs` splits the corpus into batches, so the
    # counts are summed below and compared against the `find` listing: a batch that never ran
    # produces the same empty stdout as a batch that matched nothing.
    #
    # EACH BATCH ALSO NAMES ITS HIT FILES, one `F<TAB>path` line per file, and the count line
    # stays the only line whose first field is numeric. The sums skip the `F` lines, so the
    # three counts the rows print are computed exactly as they were before the file names rode
    # along -- the names are an addition to the scan's output, never a change to its arithmetic.
    #
    # OPENED IS COUNTED BY A PROBE READ IN BEGIN, NOT BY `FNR == 1`. An EMPTY file has no first
    # record, so a counter on `FNR == 1` scores it unopened, and one zero-byte log in the corpus
    # turns every pull into `artifact-derivations-unreadable` -- measured on the reference
    # consumer, 4556 of 4557 on the 0.614.0 -> 0.618.0 reconcile. `getline` answers -1 only for a
    # file it cannot open and 0 for an empty one, which is exactly the distinction wanted here.
    VD_SCAN="$(find "$4" -type f -name '*.md' -print0 2>/dev/null \
      | xargs -0 awk -v paths="$VD_MOVED" '
          BEGIN { n = split(paths, A, "|"); for (i = 1; i <= n; i++) if (A[i] != "") P[A[i]] = 1
                  for (i = 1; i < ARGC; i++) if ((getline _vl < ARGV[i]) >= 0) { files++; close(ARGV[i]) } }
          FNR == 1 { infence = 0 }
          /^[[:blank:]]*```derived[[:blank:]]*$/ { infence = 1; next }
          infence && /^[[:blank:]]*```[[:blank:]]*$/ { infence = 0; next }
          infence && /^[[:blank:]]*\$ / {
            for (p in P) if (index($0, p) > 0) { hits++; H[FILENAME] = 1; break }
          }
          END { m = 0; for (f in H) { m++; printf "F\t%s\n", f }; printf "%d\t%d\t%d\n", files + 0, hits + 0, m }
        ' 2>/dev/null)"
    VD_FILES="$(printf '%s\n' "$VD_SCAN" | awk -F'\t' '$1 == "F" { print substr($0, 3) }' | sort -u)"
    VD_SCANNED="$(printf '%s\n' "$VD_SCAN" | awk -F'\t' '$1 != "F" {a+=$1} END{print a+0}')"
    VD_HITS="$(printf '%s\n' "$VD_SCAN" | awk -F'\t' '$1 != "F" {a+=$2} END{print a+0}')"
    VD_NF="$(printf '%s\n' "$VD_SCAN" | awk -F'\t' '$1 != "F" {a+=$3} END{print a+0}')"
    case "${VD_SCANNED:-0}" in ''|*[!0-9]*) VD_SCANNED=0 ;; esac
    case "${VD_HITS:-0}" in ''|*[!0-9]*) VD_HITS=0 ;; esac
    case "${VD_NF:-0}" in ''|*[!0-9]*) VD_NF=0 ;; esac
  fi
}
VD_ART="$CONSUMER/_bmad-output"
VD_VALIDATOR="$CONSUMER/scripts/ai-dlc/validate-artifact-derivations.sh"
if [ -d "$VD_ART" ]; then
  vd_join "$DIST" "$BASE" "$THEIRS" "$VD_ART"
  if [ -n "${VD_MOVED:-}" ] && [ "$VD_LISTED" -gt 0 ]; then
    if [ "$VD_SCANNED" -lt "$VD_LISTED" ]; then
      say DECISION artifact-derivations-unreadable "_bmad-output/" \
        "the artifact corpus could not be fully read — ${VD_SCANNED} of ${VD_LISTED} markdown file(s) were opened — so whether this range stranded a recorded derivation is UNKNOWN, and unknown reads exactly like clean. Run \`bash scripts/ai-dlc/validate-artifact-derivations.sh _bmad-output/\` by hand before treating this pull as done."
    elif [ "$VD_HITS" -gt 0 ] && [ -f "$VD_VALIDATOR" ]; then
      say WORKLIST artifact-derivations "_bmad-output/" \
        "${VD_HITS} recorded \`derived\` command(s) across ${VD_NF} artifact file(s) name a core path this range CHANGED between ${BASE} and ${THEIRS}. Core text that moved leaves each of those commands measuring whatever still happens to sit at the old path, which re-runs without failing. RE-POINT each one this range broke at the path core carries at ${THEIRS}. The check is \`bash .claude/skills/ai-dlc-update/reconcile/derivation-differential.sh <dist> ${BASE} . ${THEIRS}\`, run before the apply is committed: it re-derives this row's file set with the same join, runs the installed validator over those files once against the pre-apply tree and once against this one, and keys each derivation on its pass/fail STATUS. The clear is ZERO NEWLY-FAILING — a derivation that passed before this apply and fails after it; exit 0 is that clear, exit 1 names each newly-failing one, exit 2 is a refusal and is never a clear. A derivation that was already stale before the apply is OUT OF THIS ROW'S SCOPE: this range did not break it, and the whole-corpus validator's exit 0 is a clear no edit made for this pull can reach. UNASSESSABLE derivations (refused by the validator on either side: ALLOWLIST, GRAMMAR, READS-STDIN) are LISTED, never counted as cleared — adjudicate each by hand. NOT run from here: it executes the commands it finds, twice, and that is a cost this driver must not charge on a pull."
    elif [ "$VD_HITS" -gt 0 ]; then
      say DECISION artifact-derivations-unchecked "_bmad-output/" \
        "${VD_HITS} recorded \`derived\` command(s) across ${VD_NF} artifact file(s) name a core path this range changed, and scripts/ai-dlc/validate-artifact-derivations.sh is not on this consumer, so nothing can re-run them. It is delivered by install.sh's copy loop over core/scripts/; run a fresh install of that script, then \`bash scripts/ai-dlc/validate-artifact-derivations.sh _bmad-output/\`."
    fi
  fi
fi

# THE DRIVER REPLACED ITSELF, AND THE OPERATOR IS TOLD SO RATHER THAN LEFT TO INFER IT.
# The rename above makes this SAFE -- the run finishes on the version that was invoked -- but
# it does not make it invisible, and the difference matters: every row below this point was
# produced by the OLD driver, so a range that changed how apply.sh classifies or orders work
# was adjudicated by the pre-range rules.
#
# THIS ROW USED TO PRESCRIBE A BARE RE-RUN AND CALL IT IDEMPOTENT. The resolution phases are;
# the run is not, once the union gate above precedes them. Post-apply, the approved report no
# longer matches what the detectors render (every applied path is now already-at-theirs), so
# the re-run is refused before it reaches phase 1 -- measured on the reference consumer's
# 0.482.0 -> 0.489.0 pull by obeying this row: rc=1, nothing written, and a refusal whose two
# stated causes were both false. A row must not prescribe an action the same release makes
# unexecutable in the state the row is printed in. The gate's post-apply branch carries the
# procedure that does work, so this row points at it rather than restating it.
#
# Not a DECISION row: nothing is owed. The re-stamp below is still correct either way, because
# it asserts the TREE is at THEIRS, which it is.
if [ "$self_replaced" -eq 1 ]; then
  say RESOLVED driver-self-update "${SELF_FILE#"$CONSUMER"/}" \
    "this range updates apply.sh itself; the new copy is in place and this run continued on the version you invoked. Rows below were produced by the previous driver. A bare re-run will NOT show you the new driver's reading: the union gate refuses it, because the approved report describes the tree before this run moved it, and its refusal names the procedure that does."
fi

# ---------------------------------------------------------------- 2. drift refile (known patterns)
# provenance-block.json known_skills: the consumer added skill names in place. Refile them to the
# sanctioned extension point (extensions/known-skills.json) and revert the schema to theirs.
#
# UD was captured in phase 0, before phase 1 wrote anything. Do NOT recompute it here: at this
# point every pure-apply file already equals THEIRS, so a fresh run reports the driver's own
# writes as consumer drift. See phase 0.
ud_stage_rc=0; ap_stage ud-paths "$UD" || ud_stage_rc=$?
if [ "$ud_stage_rc" -ne 0 ]; then
  ap_staging_refused "core/" "the list of core files edited in place (unregistered-drift.sh)" "$ud_stage_rc" "re-run apply with the same four arguments."
  mech_fail=$((mech_fail+1))
fi
[ "$ud_stage_rc" -eq 0 ] && while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  cons="$(consumer_path "$rel")" || { say DECISION drift "$rel" "no consumer path mapping"; mech_fail=$((mech_fail+1)); continue; }
  case "$rel" in
    schemas/provenance-block.json)
      # The diff is ap_ks_diff's, which `--finish` re-runs to see whether this refile is still
      # owed. A failed show, staging or diff is a DECISION that withholds the stamp, never an
      # empty diff.
      ap_ks_diff "$rel" "$cons"
      if [ "$ap_drc" = staging-failed ] || [ "$ap_drc" -ge 2 ]; then
        say DECISION drift "$rel" "the diff against ${THEIRS} did not run (${ap_drc}) — whether this edit is an additive known_skills entry is UNKNOWN, not no. Fix what stopped it (the consumer copy unreadable, or no staging directory), then ${reapply_remedy}"
        mech_fail=$((mech_fail+1)); continue
      fi
      added="$(ap_ks_added "$ap_d")"
      if [ -n "$added" ]; then
        ext="$CONSUMER/.claude/skills/ai-dlc/extensions/known-skills.json"
        mkdir -p "$(dirname "$ext")"
        # THE PROGRAM IS AN ARGUMENT, NOT A HEREDOC, AND ITS EXIT IS READ. Fed as `python3 - <<'PY'`,
        # a heredoc bash 3.2 could not stage handed python EMPTY stdin -- an empty program, exit 0 --
        # and the line below then overwrote the schema with theirs: the consumer's skill gone from
        # both places. A refile that did not write the extension now leaves the schema as it is.
        ks_rc=0
        python3 -c '
import json, os, sys
path = sys.argv[1]; new = sys.argv[2:]
cur = []
if os.path.isfile(path):
    try:
        d = json.load(open(path)); cur = d.get("known_skills", d) if isinstance(d, dict) else d
    except Exception: cur = []
merged = list(dict.fromkeys([str(x) for x in cur] + new))
open(path, "w").write(json.dumps({"known_skills": merged}, indent=2) + "\n")
' "$ext" $added || ks_rc=$?
        if [ "$ks_rc" -ne 0 ]; then
          say DECISION drift "$rel" "the refile could not write extensions/known-skills.json (python3 exited ${ks_rc}), so the schema was NOT reverted and its in-place entries are still the only record of them. Fix what stopped it, then ${reapply_remedy}"
          mech_fail=$((mech_fail+1)); continue
        fi
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
done < "$AP_TMP/ud-paths"

# ---------------------------------------------------------------- 3. override readopt (hand to LLM)
# Staged and its exit read (see `detector_run`). A refusal leaves `LD_OUT` empty, so every
# section below derives no row from it, and the DECISION row says why instead.
detector_run ld layer-drift.sh "$DIST" "$BASE" "$THEIRS" "$CONSUMER"
LD_RC=$?
LD_OUT=""
if [ "$LD_RC" -ne 0 ]; then
  detector_refused layer-drift layer-drift.sh "-" "$LD_RC" ld
else
  LD_OUT="$(cat "$DT_DIR/ld.out")"
fi
LD_HARD="$(printf '%s\n' "$LD_OUT" | awk -F'\t' '$1=="HARD-OVERRIDE-DRIFT-SECTION"{print $2}')"
ap_stage_or_refuse ld-hard "$LD_HARD" "-" "the layer-drift override-readopt list" \
&& while IFS= read -r ovr; do
  [ -n "$ovr" ] || continue
  say WORKLIST override-readopt "$ovr" "merge the moved core section into the override body, then readopt-override.sh --stamp readopt"
done < "$AP_TMP/ld-hard"

# A SUPERSEDED override is RETIRED, not re-adopted. Emitted separately from the readopt
# list above because an entry can be both -- the section moved AND core now provides the
# affordance the entry was written to supply -- and in that case the readopt is work whose
# result is an entry that still freezes its shadowed span. Each loop reads its own staged
# file: sharing one silently leaves the other reading stdin, which parses fine.
TAB_CH="$(printf '\t')"
# `$LD_HARD` and `$LD_SUP` below are newline-separated lists, tested for membership with
# NL_CH (defined above the phase guard, with the reason it brackets the candidate).

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
  # THE VERDICT THAT MEANS "KEEP", RESOLVED THE SAME WAY AND FROM THE SAME FILE, AND FATAL FOR
  # THE SAME REASON. Which verdicts a recorded decision AUTHORIZES is the whole content of the
  # branch below; unresolvable, this script is back to reading the token's presence and cannot
  # tell a decision that forbids the remedy from one that orders it. Stopping is the only answer
  # that is wrong in neither direction — guessing "keep" re-creates PC-S307 and guessing "act"
  # re-creates PC-S327, and those are the two defects this arm sits between.
  ADJ_KEEP_VERDICT="$(sed -n 's/^ADJ_KEEP_VERDICT="\([A-Za-z][A-Za-z0-9_-]*\)".*/\1/p' "$SELF/layer-drift.sh" 2>/dev/null | head -1)"
  if [ -z "$ADJ_KEEP_VERDICT" ]; then
    echo "apply.sh: FATAL — OVERRIDE-SUPERSEDED or EXTENSION-HOOK-DRIFT row(s) present and ADJ_KEEP_VERDICT could not be resolved from $SELF/layer-drift.sh." >&2
    echo "  Without it this script cannot tell a verdict that FORBIDS the retire sequence from one" >&2
    echo "  that ORDERS it, and either default is a filed defect: PC-S327 one way, PC-S307 the other." >&2
    exit 2
  fi
fi

# A refused stage reads /dev/null: the staging-refused row and the mechanical failure are already
# raised, and the loop head stays a line of its own (I86 locates this loop by it).
LD_SUP_SRC="$AP_TMP/ld-sup"
ap_stage_or_refuse ld-sup "$LD_SUP" "-" "the layer-drift override-superseded list" || LD_SUP_SRC=/dev/null
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
  # THE VERDICT IS READ, NOT COUNTED. This arm matched the token's PRESENCE and suppressed the
  # sequence for every member of the vocabulary, while `adj_v` was extracted for nothing but
  # interpolation into the message -- so the NOTE asserted a property of the verdict on a path
  # that never read the verdict. Its own sentence is the proof: "acting on them would undo a
  # decision, not complete one" is true of the keep verdict and FALSE of the other two, and on a
  # `retire` recording the honest answer is exactly what made the remedy unreachable. There was
  # no verdict available that both told the truth and left the steps emitted. Hit live on the
  # reference consumer's 0.427.0 -> 0.430.1 pull, filed as PC-S307.
  #
  # THE STRIP IS PART OF THE FIX AND NOT TIDYING. The tokens below are an ordered prefix parsed
  # positionally, and the adjudication token sits AHEAD of them; falling through with it still
  # attached makes `replaces_with=` and `retire_anchor=` both miss, which lands a superseded
  # single anchor in the `else` arm and prescribes `--stamp retire` -- deleting the whole
  # override file when core superseded ONE of its anchors. That failure could not exist while
  # this arm always `continue`d, so it arrives WITH the branch.
  adj_v=""
  case "$detail" in
    "$ADJ_ROW_TOKEN"=*)
      adj_v="${detail#"$ADJ_ROW_TOKEN"=}"; adj_v="${adj_v%% ::*}"
      if [ "$adj_v" = "$ADJ_KEEP_VERDICT" ]; then
        say NOTE override-adjudicated "$ovr" "core superseded a shadowed anchor here, and this project has ALREADY RECORDED a verdict of '${adj_v}' for this exact subject in the layer adjudication register. No retire steps are emitted: acting on them would undo a decision, not complete one. The row is reported so the supersession stays visible. If you want to revisit it, change the register entry. The verdict is digest-keyed over this entry AND the core file it hooks as of this pull, so it is spent when either changes NEXT -- which may be several pulls away, or never: this is not a decision that expires on its own schedule."
        continue
      fi
      detail="${detail#*" :: "}"
      ;;
  esac
  # THE RECORDED VERDICT IS THE AUTHORIZATION FOR THE ROWS, SO IT IS CITED IN THEM. An operator
  # who recorded a decision and is then handed destructive-looking steps needs to see that the
  # steps are the decision being carried out, not the pull ignoring it.
  adj_auth=""
  [ -n "$adj_v" ] && adj_auth=" This project has RECORDED the verdict '${adj_v}' for this exact subject in the layer adjudication register, and that verdict is what AUTHORIZES this sequence: acting on it completes the recorded decision rather than undoing one."
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

  # AN OVERRIDE CAN BE BOTH DRIFT-HARD AND SUPERSEDED, AND THE MANIFEST SAID SO NOWHERE.
  #
  # The co-emission is deliberate and the comment above the readopt loop has always said why:
  # under a supersession the readopt is "work whose result is an entry that still freezes its
  # shadowed span." That reason reached the SOURCE and never the OPERATOR, who was handed an
  # `override-readopt` row and a `--stamp retire` sequence for one path, in a list SKILL.md
  # tells them to work top-down, with nothing marking the first as subsumed by the second.
  # Filed by the reference consumer as PC-S331.
  #
  # SITED HERE, IN THE LOOP THAT ALREADY KNOWS. The readopt loop cannot answer this: it runs
  # before `$LD_SUP` is parsed, before the adjudication token is resolved, and before
  # `retire_anchor=` has been read -- so asking it would mean a second copy of all three
  # parses, and a second copy is a second thing to keep in step.
  #
  # A FULL RETIRE ONLY. The two cases that are NOT a full retire both leave the entry on disk,
  # where a readopt is real work rather than futile work, and neither may be suppressed:
  #   - `retire_anchor=` drops ONE anchor and leaves the file, so the sections it still
  #     shadows keep their override and the readopt is exactly how they get the moved text.
  #   - a recorded KEEP verdict `continue`s above and emits no retire at all.
  # Guarding on `$drop_anchor` covers the first; the second never reaches this line.
  if [ -z "$drop_anchor" ]; then
    case "${NL_CH}${LD_HARD}${NL_CH}" in
      *"${NL_CH}${ovr}${NL_CH}"*)
        say NOTE override-readopt-subsumed "$ovr" "The \`override-readopt\` row printed above for this same path is SUBSUMED by the retire sequence below and must NOT be landed. Core both moved the section this entry shadows AND now provides what the entry was written to supply; merging the moved section in would produce an entry that still freezes its shadowed span, and the retire then deletes the file you just edited. Do the retire sequence; skip the readopt."
        ;;
    esac
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
    # A STAGED FILE, NOT `printf | while read`, AND THE DIFFERENCE IS EVERY KEY ROW.
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
    # The list is now STAGED with `ap_stage`, which writes `printf '%s\n'` -- the trailing newline
    # the last element needs, exactly as the here-string supplied it -- and the loop reads that
    # file in the main shell, so `key_n` survives the loop. Not a here-string any more: a
    # here-string that could not be staged ran this loop ZERO times and the sequence lost every
    # write step. A staging failure is a row, and the retire step below is withheld with it,
    # because printing step N/N alone is the order this block exists to forbid.
    ok_rc=0; ap_stage env-keys "${env_key//,/$NL_CH}" || ok_rc=$?
    if [ "$ok_rc" -ne 0 ]; then
      ap_staging_refused "$ovr" "the settings_env_keys list of this supersession" "$ok_rc" "re-render the report and re-run apply with the same four arguments."
      continue
    fi
    while IFS= read -r one_key; do
      [ -n "$one_key" ] || continue
      key_n=$(( key_n + 1 ))
      say WORKLIST override-retire "$ovr" "${key_n}/${key_total} ATOMIC — write ${one_key} into .claude/settings.json \"env\" (derive its value per override_supersessions in layer-contract.yaml; do NOT copy the example). Doing the retire stamp first re-imposes the core constraint this entry was widening and reds the next gate."
    done < "$AP_TMP/env-keys"
    # "THE ROW(S) ABOVE" NAMED THE WRONG ROWS THE MOMENT ANYTHING ELSE PRINTED FOR THIS PATH.
    # The steps that must land together are the other steps of THIS sequence, and the phrase
    # said "above" -- which, for an override that is also drift-hard, points at an
    # `override-readopt` row for the same path that must NOT be in the commit at all. The
    # atomicity instruction is a safety property (SKILL.md:1131-1137), so it is reworded to
    # name its own sequence rather than dropped.
    say WORKLIST override-retire "$ovr" "${key_total}/${key_total} ATOMIC — ${last_act} Same commit as the other $(( key_total - 1 )) step(s) of THIS ATOMIC sequence, and nothing else.${adj_auth}"
  elif [ -n "$drop_anchor" ]; then
    # No key to write, so there is no ordering to enforce and no ATOMIC sequence — but the action
    # still is not a retire, and the single row has to SAY so rather than repeat the detail and
    # leave the operator to notice the difference between "delete this entry" and "delete one of
    # its anchors".
    say WORKLIST override-retire "$ovr" "core supersedes ONE anchor of this entry: ${last_act} Full reason: ${detail}${adj_auth}"
  else
    say WORKLIST override-retire "$ovr" "core supersedes this entry: ${detail}${adj_auth}"
  fi
done < "$LD_SUP_SRC"

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
ap_stage_or_refuse ld-hook "$LD_HOOK" "-" "the layer-drift extension-hook list" \
&& while IFS="$TAB_CH" read -r ext detail; do
  [ -n "$ext" ] || continue
  case "$detail" in
    "$ADJ_ROW_TOKEN"=*)
      adj_v="${detail#"$ADJ_ROW_TOKEN"=}"; adj_v="${adj_v%% ::*}"
      # A RECORDED VERDICT DISCHARGES THE RE-READ, BUT ONLY THE KEEP VERDICT DISCHARGES THE ENTRY.
      # `retire` and `contradicts-core` are honest answers that AUTHORIZE work, and this loop used to
      # print the keep NOTE for all three -- "no re-read is prescribed" -- so a consumer that recorded
      # `retire` was told nothing about the retirement it had just decided on. Each now names its
      # actor. NOTE, not WORKLIST: an extension retired at SECTION grain (the retired passage cut,
      # the entry kept) leaves a file this loop cannot tell from an unretired one, and a gating row
      # would withhold the stamp forever over work already done. The members are unquoted `case`
      # labels; the keep member is never spelled here at all, it is resolved from layer-drift.sh.
      # The `*)` arm is a verdict this driver does not route -- a register value outside the
      # schema's enum, or a member a later schema adds -- and it says so rather than reading as keep.
      if [ "$adj_v" = "$ADJ_KEEP_VERDICT" ]; then  # extension keep test
        say NOTE extension-adjudicated "$ext" "this entry's hooked core file changed, and this project has ALREADY RECORDED a verdict of '${adj_v}' for this exact subject in the layer adjudication register. No re-read is prescribed: the reading has been done. The row is reported so the drift stays visible. The verdict is digest-keyed over this entry AND the core file it hooks as of this pull, so it is spent when either changes NEXT -- which may be several pulls away, or never: this is not a decision that expires on its own schedule."
      else
        case "$adj_v" in
          retire)
            say NOTE extension-retire "$ext" "this project has RECORDED the verdict 'retire' for this entry against its hooked core file as of this pull, and that verdict authorizes the retirement: delete the entry per Rule 27(b), or cut the retired section from it; either edit respends the digest, so the verdict is spent by the act it authorizes. Nothing else carries this decision -- no later pull re-raises it while the digest holds." ;;
          contradicts-core)
            say NOTE extension-contradicts-core "$ext" "this project has RECORDED the verdict 'contradicts-core' for this entry against its hooked core file as of this pull: the entry no longer adds to core, it disagrees with it, and an extension is additive-only. Refile the entry as an override with a base_sha (extensions/README.md, LC-E5), or edit it so it adds to the new core text; either edit respends the digest. Nothing else carries this decision -- no later pull re-raises it while the digest holds." ;;
          *)
            say NOTE extension-adjudicated-unrouted "$ext" "this entry's hooked core file changed, and the register records a verdict of '${adj_v}' for it, which this driver does not route to any remedy. It is NOT read as a keep: check the register entry against the verdict enum in .claude/schemas/layer-adjudication-register.json." ;;
        esac
      fi
      ;;
    *)
      say WORKLIST extension-reread "$ext" "hooked core file changed; re-read this entry against the new core text and record a verdict (still-additive / contradicts-core / retire)"
      ;;
  esac
done < "$AP_TMP/ld-hook"

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
ap_stage_or_refuse ld-title "$LD_TITLE" "-" "the layer-drift extension-title list" \
&& while IFS="$TAB_CH" read -r ext tdetail; do
  [ -n "$ext" ] || continue
  say WORKLIST extension-title-match "$ext" "$tdetail"
done < "$AP_TMP/ld-title"

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
#
# AND ITS EXIT IS READ, NOT FOLDED INTO SUCCESS. This was `2>/dev/null || true`, so a tool that
# REFUSED (exit 2: no staging directory, an extension walk that did not run, a core anchor set
# that could not be staged) printed no count and read here as "nothing to relabel". Under
# `--apply` the tool exits 0 on every outcome it decided, so any non-zero is a refusal, reported
# through `detector_run`/`detector_refused` like every other sibling this file consults.
relabel_out=""
detector_run relabel relabel-extension-checks.sh "$CONSUMER" --apply --dist "$DIST" --theirs "$THEIRS"
RELABEL_RC=$?
if [ "$RELABEL_RC" -ne 0 ]; then
  detector_refused relabel relabel-extension-checks.sh ".claude/skills/ai-dlc/extensions/" "$RELABEL_RC" relabel
else
  relabel_out="$(cat "$DT_DIR/relabel.out")" || relabel_out=""
fi
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
          git -C "$DIST" -c core.quotePath=false ls-tree --name-only "$THEIRS" -- core/scripts/ 2>/dev/null \
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
  want="$(git -C "$DIST" -c core.quotePath=false ls-tree "$THEIRS" -- "core/scripts/${base}" 2>/dev/null | awk '{print $1}')"
  if [ "$want" = "100755" ] && [ ! -x "$target" ]; then
    say DECISION declared-not-executable "$dest" \
      "shipped 100755 upstream but not executable here — installed and inert. \`chmod +x\` it, then ${reapply_remedy}"
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
#
# BOTH DIRECTIONS, ONE WALK. The audit kept `100755` alone, so a path upstream ships `100644`
# whose consumer copy IS executable produced no finding anywhere, ever. `sync_mode_from_theirs`
# clears that bit only on a file a pull APPLIES, so a bit left set by an earlier pull -- one that
# predates the classifier's mode conjunct -- is invisible to every later one: an EDGE-triggered
# check in the direction this block's own header says must be LEVEL. Each line below carries its
# direction (`N` = 100755 not executable, `X` = 100644 executable) so each gets its own row kind:
# `not-executable`'s text says "upstream ships this 100755", which is false of the mirror case.
# FALSE-POSITIVE FLOOR, measured at the distribution's HEAD before shipping: 0 `100644` `*.sh`
# files under core/ against 434 `100755` entries, so the mirror names nothing a fresh install
# writes. It is a mechanical failure for the same reason as the other direction -- preclassify's
# `mode_at_theirs` already reads 100644-plus-exec as NOT at theirs, and a stamp claiming theirs
# over it would disagree with the classifier the next pull runs.
# The body is exec_audit(), above the phase guard, because `--finish` runs the same audit (BL-402).
# The listing is staged to a file with its status read and the loop reads that file in the main
# shell -- never a `| while`, whose subshell drops its refusals, and never a here-string, which
# reads a failed staging as an empty listing.
exec_audit

fi  # ---- end of the resolution phases; see the `--finish` guard that opens them --------------

# --- `--finish`: IS <theirs> THE REF THIS TREE WAS WRITTEN FROM? -------------------------------
#
# RESOLVABLE IS NOT THE SAME QUESTION AS CORRECT, AND THE GUARD IN write_stamp() ONLY EVER ASKED THE
# FIRST. It refuses a ref that names nothing. A ref that names the WRONG thing resolves perfectly,
# and every arm there then does its job over it: the stamp takes its sha, the read-back agrees with
# what was just written, `RESOLVED consistent "the tree matches <ref>"` is printed over a tree that
# was never brought there, and the marker is removed. Measured on `--finish`, with the marker
# recording one ref and argv carrying another: the run reported success on both rows and cleared
# the marker. The bogus-ref control refused in the same run, which is what makes this a gap in the
# guard rather than an absent guard.
#
# THE SECOND SIDE OF THE JOIN ALREADY EXISTED AND NOTHING HAD EVER READ IT. `.ai-dlc-applying`
# records `theirs:` at the top of this file, and a census of the whole tracked tree found no
# parser of it at all -- every reader is an existence test (`core/git-hooks/pre-push` asks only
# whether the file is there). It is written by the ORDINARY run and deliberately NOT rewritten
# under `--finish`, so on the one path that is retyped by hand it still holds the ref whose
# content was actually applied. That makes it the record of what the operator approved, sitting
# unread beside the argument most likely to be fumbled, and deleted by the same run that ignores
# it.
#
# KEYED ON THE `core/` TREE, for the reason `emit-report.sh` is: a distribution ships docs
# between releases, so two refs can differ as commits while the bytes this pull WRITES are
# identical. Refusing on the commit would wedge a finisher whose only sin is naming the newer of
# two equivalent refs; refusing on the tree fires exactly when the finish would stamp content
# the tree does not carry.
#
# IT NEVER FAILS FOR WANT OF THE RECORD. A missing marker, a marker with no `theirs:` line, or a
# recorded ref that no longer resolves are all UNCHECKED rather than refused -- a consumer whose
# marker was cleared by hand (the remedy `core/git-hooks/pre-push` itself prints) must still be
# able to finish. Those states say so on their own row instead of passing silently, because an
# unchecked identity reported as a clean one is the failure this guard exists to end.
#
# A FUNCTION, CALLED ONCE, BEFORE THE WITHHOLDING GUARD. It sets the two variables and emits
# nothing; write_stamp() prints the rows. finish_verify_tree() reads the same answer, so the
# comparison exists in one place and the tree check never runs against a ref the record disputes.
finish_identity() {
  # A DIRECTORY AT THE MARKER'S PATH is neither a marker nor its absence: every `-f` reader skips it,
  # so without this the finisher stamps unchecked over an unmerged tree, says "fixture suite
  # re-enabled", and its `rm -f` then fails on the directory. A WORKLIST row, because that withholds.
  [ -d "$APPLYING" ] && { say WORKLIST finish-marker-directory "${APPLYING#"$CONSUMER"/}" "the in-flight marker's path is a DIRECTORY, so the record of which ref this tree was written from and which handed-back merges were untouched cannot be read, and the stamp is not advanced. Move that directory aside, restore the marker file if you have it (otherwise re-run apply with the same four arguments), then re-run --finish."; return 0; }
  if [ ! -f "$APPLYING" ]; then
    finish_id_note="no \`${APPLYING##*/}\` on the consumer, so the ref this tree was actually written from is not recorded anywhere and \`${THEIRS}\` could not be checked against it"
  else
    _m_theirs="$(sed -n 's/^theirs:[[:space:]]*//p' "$APPLYING" 2>/dev/null | head -1)"
    if [ -z "$_m_theirs" ]; then
      finish_id_note="\`${APPLYING##*/}\` carries no \`theirs:\` line, so there is nothing to check \`${THEIRS}\` against"
    else
      _m_tree="$(git -C "$DIST" rev-parse "${_m_theirs}:core" 2>/dev/null || true)"
      _a_tree="$(git -C "$DIST" rev-parse "${THEIRS}:core" 2>/dev/null || true)"
      if [ -z "$_m_tree" ] || [ -z "$_a_tree" ]; then
        finish_id_note="\`${_m_theirs}:core\` or \`${THEIRS}:core\` does not resolve in ${DIST}, so the recorded ref and the argument could not be compared"
      elif [ "$_m_tree" != "$_a_tree" ]; then
        finish_id_mismatch="this tree was written from \`${_m_theirs}\` (\`core/\` tree ${_m_tree}), but this command names \`${THEIRS}\` (\`core/\` tree ${_a_tree})"
      fi
    fi
  fi
}

# --- `--finish`: DOES THE TREE CARRY WHAT THE STAMP IS ABOUT TO CLAIM? -------------------------
#
# `--finish` skips the resolution phases, so `mech_fail` is always the `0` assigned above the
# phase guard, and before this check the finisher printed `RESOLVED consistent "the tree matches
# <theirs>"` over any tree handed to it. Measured on a synthetic tree where no file was ever
# applied: `--finish` stamped theirs and cleared the marker with the consumer's driver still
# byte-identical to base.
#
# THE UNAPPLIED SET IS PRECLASSIFY'S OWN, NOT A SECOND CLASSIFIER. The same call phase 1 makes, and
# a row counts only when its bucket is one phase 1 answers by overwriting from theirs -- the two
# families its `case` spells. A pure-apply bucket after the apply means the consumer copy still
# matches base, or is missing, or lacks theirs' exec bit: work the ordinary run would have done
# mechanically. A CLASSIFY row never counts HERE, so a file the operator merged by hand -- which
# keeps a consumer delta by definition -- cannot wedge the finisher. Comparing each copy against
# theirs' blob instead was built and refuted: it withholds every merged file forever. Whether a
# CLASSIFY file was merged AT ALL is finish_classify_unmerged()'s question, answered against the
# blob the ordinary run recorded, never against theirs.
#
# EACH ROW IS A WORKLIST, WHICH IS WHAT `--finish` GATES ON, and it clears when the file is
# written. No new counter: `say` counts it.
#
# FAILS CLOSED ON EVERY PRECONDITION. BASE must be a commit whose `core/` tree is the tree of the
# stamp's `commit:` -- a BASE typed as theirs makes every range empty and acquits everything, and
# the stamp is the record an EARLIER re-stamp wrote, which `--finish` has not touched yet. A
# preclassify that fails, or that returns no rows while BASE..THEIRS moves `core/`, is a withhold
# too: "no rows" and "nothing unapplied" print the same.
#
# A SETUP-SITED PATH is never byte-equal to base on a consumer, since setup filled its tokens, so
# it usually buckets CLASSIFY and is not counted. It gets a NOTE naming it, so what was not
# verified is visible rather than silent. NOTE does not count.
#
# An unresolvable <theirs> is left to write_stamp()'s `restamp-unresolvable` refusal, which
# already stamps nothing; this check has no ref to classify against.
finish_verify_tree() {
  local _fv_rows _fv_rc _fv_st _fv_path _fv_cons _fv_bucket _fv_sc _fv_bt _fv_st_t _fv_sited
  local _fv_stamp="$CONSUMER/.claude/.ai-dlc-version" _fv_why=""
  git -C "$DIST" rev-parse -q --verify "${THEIRS}^{commit}" >/dev/null 2>&1 || return 0
  if ! git -C "$DIST" rev-parse -q --verify "${BASE}^{commit}" >/dev/null 2>&1; then
    _fv_why="\`${BASE}\` is not a commit in ${DIST}"
  elif [ ! -f "$_fv_stamp" ]; then
    _fv_why="there is no version stamp, so nothing records the base this tree was installed at"
  else
    _fv_sc="$(sed -n 's/^commit:[[:space:]]*//p' "$_fv_stamp" 2>/dev/null | head -1)"
    _fv_bt="$(git -C "$DIST" rev-parse -q --verify "${BASE}:core" 2>/dev/null || true)"
    _fv_st_t=""
    [ -n "$_fv_sc" ] && _fv_st_t="$(git -C "$DIST" rev-parse -q --verify "${_fv_sc}:core" 2>/dev/null || true)"
    if [ -z "$_fv_sc" ]; then
      _fv_why="the stamp carries no \`commit:\` line to check \`${BASE}\` against"
    elif [ -z "$_fv_st_t" ] || [ -z "$_fv_bt" ]; then
      _fv_why="\`${_fv_sc}:core\` (the stamp's commit) or \`${BASE}:core\` does not resolve in ${DIST}"
    elif [ "$_fv_st_t" != "$_fv_bt" ]; then
      _fv_why="the stamp records \`${_fv_sc}\` (\`core/\` tree ${_fv_st_t}), but this command names \`${BASE}\` (\`core/\` tree ${_fv_bt}) as the base"
    fi
  fi
  if [ -n "$_fv_why" ]; then
    say WORKLIST finish-base-unverified "${_fv_stamp#"$CONSUMER"/}" "${_fv_why}. Whether this tree was brought to \`${THEIRS}\` is decided against the base it started from, and that base is not established, so nothing was verified and the stamp is not advanced. Re-run with the stamp's own \`commit:\`${_fv_sc:+ (\`${_fv_sc}\`)} as \`<base>\` -- the restamp-withheld row below echoes the \`<base>\` this command was given, so do not copy its command on this row."
    return 0
  fi
  _fv_rows="$(bash "$SELF/preclassify.sh" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" 2>/dev/null)"; _fv_rc=$?
  if [ "$_fv_rc" -ne 0 ]; then
    say WORKLIST finish-unverified-tree "" "preclassify.sh exited ${_fv_rc}, so which files are still at base is UNKNOWN and the stamp is not advanced. Re-run it by hand with the same four arguments and fix what it reports, then re-run --finish."
    return 0
  fi
  if [ -z "$_fv_rows" ] && [ "$_fv_bt" != "$(git -C "$DIST" rev-parse -q --verify "${THEIRS}:core" 2>/dev/null || true)" ]; then
    say WORKLIST finish-unverified-tree "" "preclassify.sh returned no rows while \`${BASE}..${THEIRS}\` changes \`core/\`, which is not the same as nothing being unapplied, so the stamp is not advanced. Re-run it by hand with the same four arguments and fix what it reports, then re-run --finish."
    return 0
  fi
  # The setup-sited set, read by preclassify's OWN `setup_sited_paths()` rather than a second
  # grammar -- the same load map_consumer() gets above. `$0` in it resolves to this file, which sits
  # beside setup-sites.md exactly as preclassify.sh does. Every step's status is read: a function
  # that did not load, or a manifest it could not read (4), is not an empty set -- it would drop
  # every setup-sited row below and the stamp would advance over files nobody verified.
  _fv_sited=""; _fv_rc=0
  eval "$(awk '/^setup_sited_paths\(\) \{/,/^\}/' "$SELF/preclassify.sh" 2>/dev/null)" || _fv_rc=$?
  command -v setup_sited_paths >/dev/null 2>&1 || _fv_rc=127
  [ "$_fv_rc" -ne 0 ] || _fv_sited="$(setup_sited_paths)" || _fv_rc=$?
  if [ "$_fv_rc" -ne 0 ]; then
    say WORKLIST finish-unverified-tree "" "the setup-sited path set could not be loaded out of preclassify.sh's \`setup_sited_paths()\` (exit ${_fv_rc}), so which changed files --finish cannot verify by bytes is UNKNOWN and the stamp is not advanced. Check that reconcile/setup-sites.md and preclassify.sh are present and readable, then re-run --finish."
    return 0
  fi
  [ -n "$_fv_sited" ] || say NOTE finish-unverified "reconcile/setup-sites.md" "the setup-sited path set came back empty, so no changed setup-sited path can be named here as unverified."
  # STAGED, AND A FAILED STAGE WITHHOLDS. This loop fed from a heredoc, and under a file-size limit
  # bash 3.2 could not write the heredoc's temp file and ran the loop on EMPTY stdin: zero rows, no
  # `finish-unapplied`, and the stamp advanced over 151 files still at base. ap_staging_refused is a
  # WORKLIST under `--finish`, which is what this mode gates on.
  _fv_rc=0; ap_stage fv-rows "$_fv_rows" || _fv_rc=$?
  if [ "$_fv_rc" -ne 0 ]; then
    ap_staging_refused "core/" "preclassify's bucket rows for the finish check (which files are still at base)" "$_fv_rc" "re-run --finish."
    return 0
  fi
  while IFS="$(printf '\t')" read -r _fv_st _fv_path _fv_cons _fv_bucket; do
    [ -n "${_fv_bucket:-}" ] || continue
    case "$_fv_bucket" in
      UPSTREAM-ONLY|UPSTREAM-ONLY-ADD|*SETUP-TOKENS*)
        fv_unapplied="${fv_unapplied}${NL_CH}${_fv_cons}"
        say WORKLIST finish-unapplied "$_fv_cons" "${_fv_bucket}: this file still reads as ${_fv_bucket} against \`${THEIRS}\` -- missing, still at base, or without theirs' exec bit -- so the tree does not carry what the stamp would claim. Write theirs' copy: \`git -C <dist> show \"${THEIRS}:${_fv_path}\" > ${_fv_cons}\` (and \`chmod +x\` it if upstream ships it executable), or re-run the ordinary apply, then re-run --finish." ;;
      *)
        case "$_fv_st" in R|O) continue ;; esac
        # A `case` membership test, not `grep -qxF <<<`: no temp file to lose, so a staging
        # failure cannot read as "not setup-sited" and drop the row.
        case "${NL_CH}${_fv_sited}${NL_CH}" in *"${NL_CH}${_fv_path}${NL_CH}"*)
          say NOTE finish-unverified "$_fv_cons" "setup-sited, bucketed ${_fv_bucket}: a setup-filled file never byte-matches base or theirs, so --finish cannot tell a merged copy from an untouched one. Confirm by hand that theirs' changes are in it." ;;
        esac ;;
    esac
  done < "$AP_TMP/fv-rows"
  return 0
}

# --- `--finish`: IS A HANDED-BACK SEMANTIC MERGE STILL UNTOUCHED? (BL-413) ----------------------
#
# finish_verify_tree() cannot see this, by design: a `*CLASSIFY*` file never counts there, because a
# merged copy keeps a consumer delta and would withhold forever. The ordinary run therefore recorded
# each such file's consumer blob in the marker before it wrote anything (ap_write_marker). A file
# still byte-identical to that blob is a merge nobody did, and is a WORKLIST row -- what this mode
# gates on -- that clears the moment the file changes. A file that is now ABSENT is not withheld: a
# deletion is a disposition. A `-` record, or a blob that cannot be read now, withholds: unknown is
# not merged.
#
# TOUCHED MEANS THE BLOB OR THE EXEC BIT MOVED. A range that changes only a file's mode is merged by a
# `chmod`, which leaves the blob alone. A line with no mode field is compared on the blob alone.
#
# A DELIBERATE NO-OP MERGE HAS AN EXIT FOR THAT FILE ALONE, AND IT IS NAMED IN THE ROW: delete that
# file's own `classify:` line from the marker and re-run `--finish`. The identity check and every
# other file's check still run, and the marker -- which keeps the fixture suite blocked -- stays until
# the stamp clears it. Removing the WHOLE marker also stamps, but it unblocks the fixture suite on a
# tree that may still be mid-pull and forfeits both checks, so the row names it last.
#
# A MARKER WITH NO `classify-hashes:` LINE WAS WRITTEN BY AN ENGINE THAT RECORDED NOTHING, or by this
# one over a same-base marker that engine wrote (see ap_write_marker). It gets a NOTE and the
# behaviour that engine had: this check cannot fire on the pull that delivers it.
finish_classify_unmerged() {
  local _ml _l _h _m _c _now _nm _tab
  [ -f "$APPLYING" ] || return 0
  _tab="$(printf '\t')"
  if ! grep -q '^classify-hashes: ' "$APPLYING" 2>/dev/null; then
    say NOTE finish-classify-unrecorded "${APPLYING#"$CONSUMER"/}" "this marker records no \`classify-hashes:\` line -- it was written by an apply that predates the record -- so whether a file handed back as a semantic merge was ever merged cannot be checked here. Confirm each \`semantic-merge\` row of that run by hand."
    return 0
  fi
  _ml="$(awk '/^classify: /' "$APPLYING" 2>/dev/null)" || {
    say WORKLIST finish-classify-unverified "${APPLYING#"$CONSUMER"/}" "the marker's semantic-merge record could not be read, so whether a handed-back merge is still undone is UNKNOWN and the stamp is not advanced. Make the file readable, then re-run --finish."
    return 0
  }
  while [ -n "$_ml" ]; do
    _l="${_ml%%"$NL_CH"*}"
    case "$_ml" in *"$NL_CH"*) _ml="${_ml#*"$NL_CH"}" ;; *) _ml="" ;; esac
    _l="${_l#classify: }"
    _h="${_l%%"$_tab"*}"; _c="${_l#*"$_tab"}"
    [ -n "$_c" ] && [ "$_c" != "$_l" ] || continue
    _m=""; case "$_h" in *" "*) _m="${_h#* }"; _h="${_h%% *}" ;; esac
    [ -e "$CONSUMER/$_c" ] || continue
    _now="$(git hash-object "$CONSUMER/$_c" 2>/dev/null)" || _now=""
    _nm=644; [ -x "$CONSUMER/$_c" ] && _nm=755
    if [ "$_h" = "-" ] || [ -z "$_now" ]; then
      say WORKLIST finish-classify-unverified "$_c" "handed back as a semantic merge, and its blob could not be read $([ "$_h" = "-" ] && printf 'when the apply recorded it' || printf 'now'), so whether the merge was done is UNKNOWN and the stamp is not advanced. Make the file readable, then re-run --finish."
    elif [ "$_now" = "$_h" ] && { [ -z "$_m" ] || [ "$_nm" = "$_m" ]; }; then
      say WORKLIST finish-classify-unmerged "$_c" "handed back as a semantic merge and still byte-identical to the copy the apply found (${_h}${_m:+, mode ${_m}}), so the merge was never done and the stamp would claim \`${THEIRS}\` over it. Merge theirs' changes into it (the \`semantic-merge\` row's 3-way merge, mode included), then re-run --finish. IF KEEPING THIS COPY AS IT IS IS THE DISPOSITION -- the merge is deliberately a no-op -- delete this file's own line from .claude/.ai-dlc-applying (the \`classify: … ${_c}\` line) and re-run --finish: every other check still runs, and the marker stays until the stamp clears it. A later ordinary run records the file again. Removing the whole marker (\`rm .claude/.ai-dlc-applying\`) is the last resort: it unblocks the fixture suite on a tree that may still be mid-pull, and stamps with \`DECISION restamp-identity-unchecked\`, forfeiting the check that \`${THEIRS}\` is the ref this tree was written from and this check over every other handed-back file."
    fi
  done
  return 0
}

# --- `--finish`: ARE THE TWO DECISION REMEDIES ONLY A FRESH RUN PERFORMS STILL OWED? (BL-402) -----
#
# finish_verify_tree() reads preclassify's pure-apply buckets and nothing else, so the two steps
# the ordinary run performs and `--finish` skips were never re-checked: the provenance refile and
# the exec-bit audit. Measured in apply-drift-refile's seeded world with the consumer schema at
# mode 000: apply raised `DECISION drift … did not run` and withheld the stamp, and `--finish` then
# stamped theirs with `my-persona-skill` unrefiled and the schema still drifted.
#
# So `--finish` re-checks both, against the tree as it now stands, and each still-owed one is a
# WORKLIST row -- what it gates on -- that clears when the work is done, by hand or by the fresh
# ordinary run the DECISION row prescribed. It does not PERFORM either step: a finisher that wrote
# core would be a second apply, and the reason it is the stamp and nothing else is stated above
# the phase guard.
#
# THE REFILE IS OWED WHILE A SKILL THE CONSUMER'S SCHEMA ADDS TO THEIRS' known_skills IS NOT IN
# THE EXTENSION. Keyed on that set and not on "the schema differs from theirs": a schema the
# operator kept in place after the refile-vs-revert DECISION differs forever, and keying on the
# difference would withhold every finish over it with no in-band exit. The predicate is the
# ordinary run's own, ALL of it: the same in-place-edit gate (ud_capture -- the refile loop enters
# only for a path unregistered-drift calls HARD-UNREGISTERED-CORE-DRIFT), then ap_ks_diff and
# ap_ks_added. Without the gate a schema still at BASE, in a range where upstream retired a skill,
# read the retired name as consumer-added and the row told the operator to restore it. A kept
# schema whose skills ARE in the extension owes nothing, so it cannot wedge the finisher; a
# trailing comma the appended entry put on the line above is cancelled in ap_ks_added.
# A schema byte-equal to theirs adds nothing, and the detector is not run for it. A diff or a
# drift scan that could not run is a withhold, never a pass.
finish_reapply_owed() {
  local _rel=schemas/provenance-block.json _cons _ext _owed _s _added
  # An unresolvable <theirs> is write_stamp()'s `restamp-unresolvable` refusal, as in
  # finish_verify_tree(); a row here would pre-empt it with a withheld row naming the wrong cause.
  git -C "$DIST" rev-parse -q --verify "${THEIRS}^{commit}" >/dev/null 2>&1 || return 0
  _cons="$(consumer_path "$_rel" 2>/dev/null)" || _cons=""
  if [ -n "$_cons" ] && [ -e "$_cons" ]; then
    ap_ks_diff "$_rel" "$_cons"
    if [ "$ap_drc" = 1 ]; then
      # finish_verify_tree's staged rows are the same preclassify call, handed down as phase 0
      # hands $PC down; absent (it returned early) the detector derives them itself.
      UD_FLAG=""; UD_PC=""
      if [ "$ap_stage_dead" = 0 ] && [ -f "$AP_TMP/fv-rows" ]; then UD_FLAG="--bucket-rows"; UD_PC="$AP_TMP/fv-rows"; fi
      ud_capture
      if [ "$UD_RC" != 0 ] || [ -n "$UD_NA" ]; then
        say WORKLIST finish-refile-unverified "$_rel" "unregistered-drift.sh $([ "$UD_RC" != 0 ] && printf 'exited %s' "$UD_RC" || printf 'could not scan (%s)' "$UD_NA"), so whether this schema is an in-place edit -- and so whether a known_skills entry is still unrefiled -- is UNKNOWN and the stamp is not advanced. Re-run reconcile/unregistered-drift.sh with the same four arguments, fix what it reports, then re-run --finish."
        ap_drc=refused
      else
        case "${NL_CH}${UD}${NL_CH}" in
          *"${NL_CH}${_rel}${NL_CH}"*) : ;;
          *) ap_drc=0 ;;
        esac
      fi
    fi
    if [ "$ap_drc" = refused ]; then
      :
    elif [ "$ap_drc" = staging-failed ] || [ "$ap_drc" -ge 2 ]; then
      say WORKLIST finish-refile-unverified "$_rel" "the diff against \`${THEIRS}\` did not run (${ap_drc}), so whether a known_skills entry is still unrefiled is UNKNOWN and the stamp is not advanced. Fix what stopped it (the consumer copy unreadable, or no staging directory), then re-run --finish."
    elif [ "$ap_drc" -eq 1 ]; then
      _ext="$CONSUMER/.claude/skills/ai-dlc/extensions/known-skills.json"
      # Empty means the edit adds no skill name -- the ordinary run's refile-vs-revert DECISION,
      # not a refile this mode can see owed. A name is owed unless the extension holds it quoted;
      # an extension that is absent or unreadable holds nothing (grep 1 or 2), so it withholds.
      _added="$(ap_ks_added "$ap_d")"
      _owed=""
      # Walked by parameter expansion, never `for _s in $_added`: a skill name is whatever the
      # consumer typed, and this file has no `set -f`, so an unquoted expansion would glob it.
      while [ -n "$_added" ]; do
        _s="${_added%%"$NL_CH"*}"
        case "$_added" in *"$NL_CH"*) _added="${_added#*"$NL_CH"}" ;; *) _added="" ;; esac
        [ -n "$_s" ] || continue
        grep -qF "\"${_s}\"" "$_ext" 2>/dev/null || _owed="${_owed}${_s} "
      done
      if [ -n "$_owed" ]; then
        say WORKLIST finish-refile-owed "$_rel" "known_skills the consumer added in place are still not in extensions/known-skills.json: ${_owed}— the refile the ordinary run performs was never done, so the stamp would claim theirs over drift it has not migrated. Add each to .claude/skills/ai-dlc/extensions/known-skills.json and restore the schema with \`git -C <dist> show \"${THEIRS}:core/${_rel}\" > .claude/${_rel}\`, or follow the drift row's re-render/re-approve/apply remedy, then re-run --finish."
      fi
    fi
  fi
  exec_audit
  return 0
}

# version landed when it did not costs a silent divergence nobody looks for.
#
# A FUNCTION BECAUSE IT HAS TWO CALL SITES AND ONE BODY. `--finish` runs it over a tree this
# program did not touch on this invocation; the ordinary run runs it after the phases above. The
# two orders are dispatched once, at the foot of this file, with the reason for each stated there.
write_stamp() {
STAMP="$CONSUMER/.claude/.ai-dlc-version"
# BOTH PAIRS OR NEITHER. The skill pair is written inside the same branch as the rulebook pair,
# so a withheld re-stamp withholds it too. Advancing `skill_version` over a tree that is missing
# machinery files is the same false claim as advancing `version` over it -- and it is the worse
# half, because `unregistered-drift.sh` reads `skill_commit` as a suppression ref: a stamp
# naming a ref the tree does not match turns the NEXT pull's report into false drift work.
withheld_extra=""
# BOTH DERIVED IN THE ONE BLOCK THAT ALREADY READS THE MACHINERY FLAG, and deliberately not in a
# second test on it beside the row below. `core/fixtures/apply-machinery-stamp` mutates every
# guard on that flag together and refuses to score a PARTIAL revert; a third reader would have
# left that battery proving the layer it could not reach. It caught this on the first run.
# `finish_flag` is what makes the printed command reproduce THIS invocation rather than a generic
# one -- a finisher run without the flag would withhold the machinery pair the first run was
# carrying, which is the same false claim in the opposite direction.
finish_flag=""
if [ "$CARRIED_MACHINERY" = 1 ]; then
  withheld_extra=" This run carried step 2's deferred machinery slice, so \`skill_version\`/\`skill_commit\` are withheld with it — both pairs or neither."
  finish_flag=" --carried-machinery-slice"
fi
# UNDER `--finish` THE TREE IS CHECKED HERE, BEFORE THE GUARD READS `worklist_n`: identity first,
# because an unapplied set computed against a fumbled <theirs> names content the tree was never
# approved for, and on a mismatch the tree check does not run at all -- the identity row below is
# the one the operator needs.
finish_id_mismatch=""
finish_id_note=""
if [ "$FINISH" = 1 ]; then
  finish_identity
  [ -z "$finish_id_mismatch" ] && finish_verify_tree
  [ -z "$finish_id_mismatch" ] && finish_classify_unmerged
  [ -z "$finish_id_mismatch" ] && finish_reapply_owed
fi
if [ "$FINISH" = 1 ]; then outstanding="$worklist_n"; else outstanding="$handback"; fi
if [ "$mech_fail" -gt 0 ] || [ "$outstanding" -gt 0 ]; then
  # A ROW ONLY A FRESH ORDINARY RUN CLEARS IS NOT FINISHED BY `--finish`, SO THE WITHHELD ROW DOES
  # NOT OFFER IT THEN (BL-402). It used to name `--finish` unconditionally, beside a drift row whose
  # own remedy said the finisher would stamp over the unrefiled tree -- and it did. `reapply_owed`
  # is counted in `say`, from the detail text, so this branch cannot miss a row the counter saw.
  if [ "$reapply_owed" -gt 0 ]; then
  say DECISION restamp-withheld "$STAMP" "${mech_fail} file(s) could not be placed mechanically and ${outstanding} WORKLIST/DECISION row(s) above are undisposed, ${reapply_owed} of them a step only a fresh ordinary run performs — the stamp would claim ${THEIRS} while the tree does not yet match it, and the next pull computes its merge base from that stamp. Left at ${BASE}, and \`${APPLYING##*/}\` is deliberately left in place so the fixture suite keeps blocking. Follow those rows' own remedy (re-render the report, re-approve it, re-run apply with the same four arguments); that run re-stamps when nothing is left. The finish mode is NOT the next step here: it re-checks those rows and withholds while they are undone.${withheld_extra}"
  else
  say DECISION restamp-withheld "$STAMP" "${mech_fail} file(s) could not be placed mechanically and ${outstanding} WORKLIST/DECISION row(s) above are undisposed — the stamp would claim ${THEIRS} while the tree does not yet match it, and the next pull computes its merge base from that stamp. Left at ${BASE}, and \`${APPLYING##*/}\` is deliberately left in place so the fixture suite keeps blocking. Do the rows above, then advance the stamp with: apply.sh --finish${finish_flag} <dist> ${BASE} <consumer> ${THEIRS}${withheld_extra}"
  fi
elif [ -f "$STAMP" ]; then
  # RESOLVE THEIRS BEFORE WRITING ANYTHING, AND REFUSE IF IT DOES NOT RESOLVE.
  #
  # `rev-parse ... || echo "$THEIRS"` falls back to the caller's LITERAL argument, and the two
  # `sed`s below then write that literal into `commit:` and report `RESOLVED restamp` over it.
  # Measured on `--finish <dist> <base> <consumer> no-such-ref-xyz`: the stamp came back
  # `commit: no-such-ref-xyz` with `version:` still at base, `RESOLVED consistent "the tree
  # matches no-such-ref-xyz"`, and the in-flight marker CLEARED. The stamp is the next pull's
  # merge base, so this is the exact false claim this whole guard exists to prevent, reached by
  # a typo.
  #
  # IT IS A `--finish`-SHAPED HAZARD SPECIFICALLY, which is why it is fixed here rather than
  # left. The ordinary run dies in its phases long before the stamp when `<dist>`/`<theirs>` are
  # wrong; `--finish` skips those phases, so this is the FIRST thing it touches. And the
  # finishing command is RETYPED BY HAND from the withheld row, which prints `<dist>` and
  # `<consumer>` as literal placeholders -- the one invocation in this program most exposed to a
  # fumbled argument.
  #
  # A BOGUS REF WITH A SLASH IN IT MASKS THIS, and that is how it was nearly missed: a
  # `refs/heads/nope` breaks the `sed` replacement, the `|| true` swallows it, the read-back
  # disagrees and the run correctly reports `restamp-failed`. Only a slash-FREE bogus ref
  # reaches the defect. The control has to be the input that discriminates.
  #
  # THE IDENTITY OF <theirs> -- `finish_id_mismatch` / `finish_id_note` -- IS DECIDED ONCE, BY
  # finish_identity() ABOVE, before the withholding guard. Both this arm and the tree check read it.
  if ! theirs_sha="$(git -C "$DIST" rev-parse --short "$THEIRS" 2>/dev/null)" || [ -z "$theirs_sha" ]; then
    say DECISION restamp-unresolvable "$STAMP" "\`${THEIRS}\` does not resolve in ${DIST}, so there is no sha to stamp and nothing was written. The stamp is left at ${BASE} and the in-flight marker is left in place. Check the <dist> path and the <theirs> ref -- if you retyped this from a withheld row, note that it prints <dist> and <consumer> as placeholders and passes <theirs> through verbatim."
  elif [ -n "$finish_id_mismatch" ]; then
    say DECISION restamp-identity-mismatch "$STAMP" "${finish_id_mismatch}. Nothing was written: the stamp is left at ${BASE} and \`${APPLYING##*/}\` is left in place, so the fixture suite keeps blocking rather than this tree being declared finished at a ref it does not carry. The two refs differ in \`core/\`, which is the content this pull writes -- a docs-only difference would not have stopped here. Re-run with the ref the withheld row named, or, if you intend to move this tree to \`${THEIRS}\`, run the ordinary apply against it rather than finishing to it."
  else
  # From THEIRS, not the working tree. Every file copy above resolves through
  # `git show "${THEIRS}:core/..."`; reading VERSION with `cat` was the one place that
  # trusted whatever ref the operator's distribution checkout happened to be sitting on.
  # Hit live on the v0.92.0 pull: the checkout was on a v0.93.0 branch while theirs was
  # origin/main at v0.92.0, so the stamp was written `version: 0.93.0` against 0.92.0
  # content — beside a `commit:` taken correctly from theirs, which is what makes the
  # result incoherent rather than merely stale. The stamp is the one field the NEXT pull
  # trusts to compute its base, so an overstating version silently mis-bases that merge.
  # SAID ON ITS OWN ROW, because the alternative is that "could not check" and "checked and
  # agreed" print the same thing -- which is the shape that let the unchecked case survive here
  # unnoticed in the first place. It is a DECISION and not a WORKLIST deliberately: `--finish`
  # gates on WORKLIST rows, and a consumer whose marker was legitimately cleared must still be
  # able to finish.
  if [ -n "$finish_id_note" ]; then
    say DECISION restamp-identity-unchecked "$STAMP" "the stamp was advanced to \`${THEIRS}\` WITHOUT confirming it is the ref this tree was written from: ${finish_id_note}. Verify by hand that the tree matches before trusting the next pull's merge base, which is computed from this stamp."
  fi
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
  fi  # ---- end of the resolvable-<theirs> arm; the else below is the no-stamp case ----
else
  # NO STAMP FILE AT ALL, AND THIS ARM USED TO BE ABSENT -- the `elif` simply fell through and the
  # run said NOTHING about the stamp, on either mode. Found by probing `--finish` against a
  # consumer with a bare `.claude/`: the operator invokes the finisher, whose entire purpose is
  # this one write, and gets a manifest with no stamp row in it. Silence there is the worst
  # available answer, because a missing row reads as a clean run to the reader and to every
  # grep over the manifest.
  say DECISION restamp-absent "$STAMP" "there is no version stamp on this consumer, so nothing recorded which release it is at and this run had nothing to advance. That is not an apply failure and it is not a success either — the next pull has no base to compute from. Write one in schema (version/commit/skill_version/skill_commit/installed_at/upstream) at ${BASE}, then re-run."
fi
}

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
# WHY A `WORKLIST` ROW AND NOT A CALL TO `settings-merge.sh` HERE. The merge rewrites a
# user-owned file whose step-5 report the operator reads and gates before step 7 applies it,
# and this driver has no channel to obtain that gate. That is also why `.claude/settings.json`
# is absent from the mechanical set on purpose rather than by oversight: EVERY template-derived
# consumer file is (`TEMPLATE-` appears zero times in this program, against three
# `UPSTREAM-ONLY`), because each of the four is a user-owned file whose merge is
# operator-gated. Calling the merge from here would discard that gate. Naming the work does
# not, and the driver stating it is the difference between an instruction and a hope.
#
# WHY IT RUNS AFTER THE RE-STAMP RATHER THAN GATING IT. At this point in step 7 the tree is
# SUPPOSED to be in this state: the pull writes hook files here and merges settings.json
# several bullets later. A gate would fire on every correct run. The delivery gate lives at
# the end of step 7, beside `setup-site-drift.sh`; this row is what tells the reader the work
# exists, by name, at the moment it is created.
#
# UNCONDITIONAL -- outside the re-stamp branch above -- because a withheld stamp does not make
# an inert hook less inert.
#
# UNDER `--finish` IT RUNS FIRST INSTEAD, AND THAT IS THE ONE ORDERING DIFFERENCE BETWEEN THE TWO
# MODES. The paragraph above is why it runs LAST on an ordinary apply: settings.json is merged
# several bullets later in step 7, so a gate here would fire on every correct run. `--finish` is
# invoked at the END of step 7, after that merge, which is exactly when the question becomes
# answerable -- and its answer is VERIFIED rather than attested, because the validator either
# exits 0 or names the unwired hooks. Running it first there means its row is counted by the same
# `handback` guard as every other, so the one WORKLIST site that structurally could not reach the
# stamp predicate now does, on the invocation where it means something.
hook_registration_row() {
HR_VALIDATOR=""
if [ -x "$CONSUMER/scripts/ai-dlc/validate-hook-registration.sh" ]; then
  # Theirs' copy: the pure-apply phase above already wrote scripts/ai-dlc/ from THEIRS.
  HR_VALIDATOR="$CONSUMER/scripts/ai-dlc/validate-hook-registration.sh"
fi
if [ -n "$HR_VALIDATOR" ]; then
  hr_out="$(bash "$HR_VALIDATOR" --root "$CONSUMER" 2>&1)"; hr_rc=$?
  hr_names="$(printf '%s\n' "$hr_out" | sed -n 's@^ *\.claude/hooks/@@p' | tr '\n' ' ')"
  # THE VALIDATOR HAS TWO FAILURE LISTS AND PRINTS THEM IN TWO SHAPES, AND THE `sed` ABOVE CAN READ
  # ONLY ONE. UNREGISTERED names carry a `.claude/hooks/` prefix; DANGLING names -- registered, no
  # file on disk -- are printed BARE, as `    ai-dlc-<x>.sh`. With the prefix parse alone, a tree
  # whose only failure was a dangling registration returned rc 1 with nothing parsed and this
  # function emitted NO row at all, on `--finish` too: the invocation meant to verify the finished
  # tree was silent over a registration Claude Code cannot run.
  #
  # SCOPED TO ITS BLOCK. The settings.local.json NOTE prints its names in the SAME bare shape a few
  # lines later, and a NOTE is not a failure -- the hook is live for whoever holds that file. An
  # unscoped parse (a second `sed` over every bare `    ai-dlc-*.sh` line) reports a working
  # local-only hook as dangling and hands the operator a remedy for a hook that is fine. Two things
  # end the DANGLING block: the first line not indented four spaces, and the NOTE header switching
  # the mode. Against today's validator output they COVER EACH OTHER -- the NOTE header is itself
  # the first non-4-space line after the list, so removing either one alone changes no row. The
  # stop is kept for the section the validator adds next, which the NOTE switch cannot know about.
  # The NOTE list is read on its own because it decides WHICH remedy a dangling name gets:
  # `settings-merge.sh` rewrites `.claude/settings.json` only, so a registration that lives in
  # settings.local.json survives the merge and has to be removed by hand.
  hr_blocks="$(printf '%s\n' "$hr_out" | awk '
    index($0, "  DANGLING ") == 1 { m = "D"; next }
    index($0, "  NOTE ") == 1 && index($0, "settings.local.json") > 0 { m = "L"; next }
    m != "" && $0 !~ /^    / { m = "" }
    m != "" && $0 ~ /^    ai-dlc-[^ ]*\.sh$/ { sub(/^    /, ""); print m, $0 }')"
  hr_local=" $(printf '%s\n' "$hr_blocks" | awk '$1 == "L" { print $2 }' | tr '\n' ' ')"
  # THE NOTE LIST IS `local - main`, SO IT CANNOT SEE A NAME REGISTERED IN BOTH FILES. Such a name
  # appears under DANGLING alone and would be routed to the merge only; the merge rewrites
  # settings.json and leaves the settings.local.json block in place, so the validator still exits
  # 1 and the operator is sent round a second time. So settings.local.json is read here directly,
  # with the validator's OWN grammar: the pattern it prints on its `pattern (from ...)` line (the
  # one it extracts from settings-merge.sh), applied to every `command` string under `hooks`, the
  # name being the last path segment of the match -- the walk `registered_in()` performs. Reading
  # the pattern off the output rather than restating it is what keeps the two from drifting.
  hr_pat="$(printf '%s\n' "$hr_out" | sed -n 's/^  pattern (from [^)]*): //p' | head -n 1)"
  hr_inlocal=" "
  if [ -n "$hr_pat" ] && [ -f "$CONSUMER/.claude/settings.local.json" ]; then
    hr_inlocal=" $(python3 -c '
import json, re, sys
rx = re.compile(sys.argv[2])
def walk(n, out):
    if isinstance(n, dict):
        for k, v in n.items():
            if k == "command" and isinstance(v, str):
                out.append(v)
            else:
                walk(v, out)
    elif isinstance(n, list):
        for v in n:
            walk(v, out)
doc = json.load(open(sys.argv[1], encoding="utf-8"))
cmds = []
walk(doc.get("hooks", {}) if isinstance(doc, dict) else {}, cmds)
for c in cmds:
    for hit in rx.finditer(c):
        print(hit.group(0).rsplit("/", 1)[-1])
' "$CONSUMER/.claude/settings.local.json" "$hr_pat" 2>/dev/null | tr '\n' ' ')"
  fi
  hr_dangle=""; hr_dangle_local=""
  # A `while read` OVER A STAGED FILE, NEVER `for _hn in $(...)`. This file has no `set -f`, and a
  # registered name is whatever the settings say: `.claude/hooks/ai-dlc-*.sh` matches the
  # validator's pattern, is printed under DANGLING as `ai-dlc-*.sh`, and an unquoted expansion
  # globs it against the cwd. Measured from `.claude/hooks`: it named all 21 hooks.
  #
  # Not a here-string either, and the two producers' statuses are read: a here-string that could
  # not be staged, or an `awk` that did not run, both read as "no dangling hook", and on `--finish`
  # that is a stamp over a registration Claude Code cannot run. Either is a refused section.
  hr_rc2=0
  hr_d_list="$(printf '%s\n' "$hr_blocks" | awk '$1 == "D" { print $2 }')" || hr_rc2=$?
  [ "$hr_rc2" -eq 0 ] && { ap_stage hr-dangling "$hr_d_list" || hr_rc2=$?; }
  [ "$hr_rc2" -eq 0 ] && { ap_stage hr-names "${hr_names// /$NL_CH}" || hr_rc2=$?; }
  if [ "$hr_rc2" -ne 0 ]; then
    ap_staging_refused ".claude/settings.json" "the hook-registration validator's name lists" "$hr_rc2" "re-run scripts/ai-dlc/validate-hook-registration.sh by hand, act on what it names, and then ${ap_rerun_remedy}"
    return 0
  fi
  while IFS= read -r _hn; do
    [ -n "$_hn" ] || continue
    case "$hr_local" in
      *" ${_hn} "*) hr_dangle_local="${hr_dangle_local}${_hn} " ;;
      *)            hr_dangle="${hr_dangle}${_hn} "
                    case "$hr_inlocal" in *" ${_hn} "*) hr_dangle_local="${hr_dangle_local}${_hn} " ;; esac ;;
    esac
  done < "$AP_TMP/hr-dangling"
  # AN UNREGISTERED HOOK THEIRS NEITHER SHIPS NOR REGISTERS IS NOT THE SETTINGS MERGE'S TO CLEAR.
  # `settings-merge.sh` re-applies the TEMPLATE's hook blocks and strips every other `ai-dlc-*`
  # block from settings.json, so the remedy the settings-merge row prints cannot register a name
  # the template does not carry -- measured: the validator stays at exit 1 after it, this row
  # stays, and `--finish` withholds on every run with no in-band exit. Reachable because a hook
  # upstream retires is a `DECISION deletion` this driver never acts on, so the file persists.
  # Such a name gets its own WORKLIST row, still GATING: the consumer's pre-push runs the same
  # validator, so a finisher that stamped past it would hand the operator a red push instead.
  # A name in `${THEIRS}:core/hooks/` keeps the merge row whether or not the template registers
  # it -- that is the shipped set I13 binds to the template, and the sourced libraries there are
  # the validator's own exemption, not this row's. UNREADABLE TEMPLATE AT THEIRS -> no partition:
  # without the template there is nothing to say a name is absent from, so today's row stands.
  hr_tmpl="$(git -C "$DIST" show "${THEIRS}:templates/settings.json.template" 2>/dev/null)"; hr_tmpl_rc=$?
  hr_orphan=""; hr_merge_names=""
  while IFS= read -r _hn; do
    [ -n "$_hn" ] || continue
    if [ "$hr_tmpl_rc" -eq 0 ] \
       && ! git -C "$DIST" cat-file -e "${THEIRS}:core/hooks/${_hn}" 2>/dev/null; then
      case "$hr_tmpl" in
        *"/hooks/${_hn}"[!A-Za-z0-9._-]*) hr_merge_names="${hr_merge_names}${_hn} " ;;
        *)                                 hr_orphan="${hr_orphan}${_hn} " ;;
      esac
    else
      hr_merge_names="${hr_merge_names}${_hn} "
    fi
  done < "$AP_TMP/hr-names"
  hr_names="$hr_merge_names"
  if [ "$hr_rc" = "1" ] && [ -n "$hr_orphan" ]; then
    say WORKLIST hook-unshipped ".claude/hooks/" \
      "hook(s) present and UNREGISTERED in the ai-dlc- namespace that theirs neither ships (core/hooks/) nor registers (templates/settings.json.template): ${hr_orphan}— the settings reconcile cannot clear this, because it registers only the template's hooks and strips every other ai-dlc- block from .claude/settings.json. Three exits, one per hook: (1) DELETE the file, if it is a hook upstream retired; (2) RENAME it out of the \`ai-dlc-\` namespace, if it is your own, and register it under the new name; (3) keep it and register it in .claude/settings.local.json, which settings-merge.sh never touches. Re-run scripts/ai-dlc/validate-hook-registration.sh afterwards; it must exit 0 before delivery."
  fi
  # ONE ROW PER REMEDY. Unregistered and dangling-in-settings.json are both cleared by the same
  # merge, so they share the one `settings-merge` row -- whose unregistered wording is unchanged.
  # A dangling registration held in settings.local.json is a different act on a different file,
  # so it gets its own row, and a name registered in BOTH files is named in both rows. Nothing
  # downstream collapses rows by id: `say` prints and counts each
  # one, so two rows here are two undisposed items to `handback` and to `worklist_n` alike.
  if [ "$hr_rc" = "1" ] && { [ -n "$hr_names" ] || [ -n "$hr_dangle" ] || [ -n "$hr_dangle_local" ]; }; then
    hr_what=""
    [ -n "$hr_names" ] && hr_what="hook(s) present and UNREGISTERED after this apply: ${hr_names}— each is on disk, wired to nothing, and indistinguishable from one that is working. "
    [ -n "$hr_dangle" ] && hr_what="${hr_what}hook(s) REGISTERED in .claude/settings.json with no file under .claude/hooks/ (DANGLING): ${hr_dangle}— Claude Code cannot run them; the hook was retired upstream and the strip half of the reconcile did not run. If a name is still in theirs' template, its FILE is what is missing: restore it with \`git -C <dist> show \"\${theirs}:core/hooks/<name>\" > .claude/hooks/<name>\` instead. "
    if [ -n "$hr_what" ]; then
      say WORKLIST settings-merge ".claude/settings.json" \
        "${hr_what}Run the settings reconcile, which is the one program that owns this contract: \`t=\$(mktemp); git -C <dist> show \"\${theirs}:templates/settings.json.template\" > \"\$t\"; reconcile/settings-merge.sh --consumer .claude/settings.json --template \"\$t\"\`. Re-run scripts/ai-dlc/validate-hook-registration.sh afterwards; it must exit 0 before delivery."
    fi
    if [ -n "$hr_dangle_local" ]; then
      say WORKLIST settings-local-dangling ".claude/settings.local.json" \
        "hook(s) registered in .claude/settings.local.json with no file under .claude/hooks/ (DANGLING): ${hr_dangle_local}— Claude Code cannot run them. \`reconcile/settings-merge.sh\` never touches settings.local.json, so the settings reconcile cannot clear this, including for a name the settings-merge row also lists: remove each named hook's block from .claude/settings.local.json by hand, on every machine that holds one. Re-run scripts/ai-dlc/validate-hook-registration.sh afterwards; it must exit 0 before delivery."
    fi
  elif [ "$hr_rc" = "2" ]; then
    say DECISION hook-registration-unreadable ".claude/settings.json" \
      "the hook-registration check could not run, so whether this pull's hooks are wired is UNKNOWN — and unknown reads exactly like clean. Detail: $(printf '%s' "$hr_out" | tr '\n' ' ')"
  elif [ "$hr_rc" != "0" ]; then
    # A NON-ZERO EXIT THAT NAMED NOTHING IS NOT A CLEAN RUN, AND IT WAS SILENT HERE. Measured: a
    # `.claude/settings.json` holding `[]` is valid JSON, so the validator's fail-closed path never
    # fires; `doc.get` then raises, python exits 1 with a traceback and no list, and the rc-1 arm
    # above -- keyed on names -- emitted nothing. A consumer with no `python3` exits 127 the same
    # way. Its own id rather than `-unreadable` (the validator's DECLARED refusal, rc 2) or
    # `-unchecked` (no validator at all, which the C8 arm of the apply-restamp-worklist fixture
    # keys on).
    #
    # A DECISION, SO `--finish` DOES NOT WITHHOLD ON IT -- deliberately. `--finish` gates on
    # `worklist_n` alone, and a missing `python3` is not work that clears: a finisher that
    # withheld here would leave the in-flight marker with no invocation able to remove it, the
    # wedge C8 exists to rule out. The ordinary run still counts it into `handback`.
    say DECISION hook-registration-unparsed ".claude/settings.json" \
      "the hook-registration check exited ${hr_rc} without naming a single hook, so whether this pull's hooks are wired is UNKNOWN — and unknown reads exactly like clean. It is not the validator's declared refusal (that is exit 2): an interpreter error or a missing \`python3\` both look like this. Fix what the detail shows, then re-run scripts/ai-dlc/validate-hook-registration.sh until it exits 0. Detail: $(printf '%s\n' "$hr_out" | tail -n 3 | tr '\n' ' ')"
  fi
else
  # NOT a silent skip. A pull old enough to predate the validator cannot check this, and saying
  # so is the difference between "checked and clean" and "never looked".
  say DECISION hook-registration-unchecked ".claude/settings.json" \
    "scripts/ai-dlc/validate-hook-registration.sh is not on this consumer, so nothing verified that the hook files this apply wrote are registered in settings.json. Run the settings reconcile (step 7's TEMPLATE-JSON-MERGE bullet) and re-run this apply; from the next pull on, the check is automatic."
fi
}

# --- TRANSIENT IGNORE BLOCK: the other half of a DECLARATION delivery -------------------------
#
# THE SAME SHAPE AS THE HOOK ROW ABOVE, one schema over. A transient pipeline path arrives on a
# consumer in two halves. The DECLARATION is a pure apply -- this program writes
# `.claude/schemas/pipeline-state-paths.json` from theirs, mechanically, with a manifest row. The
# RENDER is `sync-transient-ignore.sh` projecting that declaration's transient half into the
# consumer's `.gitignore`, and on a PULL nothing calls it: its only invocation site in the whole
# distribution is `scripts/install.sh`, the path a NEW consumer takes.
#
# THE RENDERER'S OWN HEADER SAYS IT WAS MOVED OUT OF install.sh SO EXISTING CONSUMERS WOULD BE
# REACHED, AND THE SHIPPED CALL GRAPH REFUTES THAT. Moving it made the renderer REACHABLE on a
# consumer; nothing made it RUN there. So every pull since has delivered new transient names with
# no rule rendered for them, and the gap is invisible: a consumer whose block predates a
# declaration looks exactly like one whose block is current.
#
# WHAT IT COSTS, MEASURED ON THE REFERENCE CONSUMER RATHER THAN REASONED -- and stated as the
# SHAPE rather than as a count, because the count is a property of a tree somebody else is holding
# open. An earlier revision of this comment carried "declares 16 and renders 13"; that consumer
# re-rendered its own block hours later and the figure was false in resident prose before the
# release it shipped in had been merged a day. A raw total here decays silently and reads exactly
# like a fresh one. The CHANGELOG dates the measurement; this comment states what is durable:
#
# A consumer's block can carry FEWER patterns than its schema declares, and `.handoff-in-progress`
# -- the handoff entry marker, whose whole meaning is "the lead is INSIDE the handoff procedure" --
# has been one of the missing ones. With no rule, steps/handoff.md step 2's broad `git add` commits
# it, step 5's `rm -f` records no deletion, and the tracked blob re-materializes on every later
# checkout. A consumer hit exactly that: an unrelated pause re-armed the handoff guard from a marker
# no session had written, and the operator's first words were that no handoff had been requested.
#
# AND A CURRENT RULE IS SUFFICIENT FOR THAT CASE -- measured, not assumed. With the pattern in
# place, `git add -A`, `git add .` and `git add <dir>` all stage the real artifacts and skip the
# marker; naming it explicitly refuses loudly. Only `git add -f` captures it, and step 2 does not
# use it. The declaration was already right; only the render was missing.
#
# WHY A `WORKLIST` ROW AND NOT A CALL TO THE RENDERER HERE. `.gitignore` is a user-owned file. The
# renderer CUTS AND REWRITES a marker-bounded region of it, and this driver has no channel to
# obtain the operator's gate on that edit -- the same reason settings-merge.sh is named rather
# than called by the hook row above. Naming the work does not discard the gate.
#
# IT DRIVES THE CONSUMER'S OWN COPY, exactly as the hook row does: that is the copy which will run
# from now on, and `--check` never writes, so it is safe from a driver.
#
# THE `--check` ANSWER IS HALF THE SUBJECT, AND THE ROW SAYS SO RATHER THAN IMPLYING OTHERWISE.
# An ignore rule does nothing to a path git is ALREADY TRACKING, and `--check` cannot see that
# case at all: it returns at its block comparison, while the renderer's still-TRACKED scan sits on
# the write path below it. Driven on a probe tree with the marker tracked AND the block current,
# `--check` printed `OK: transient-state block current` and exited 0 while `git ls-files` returned
# the marker in the same invocation. So this row asks the consumer's index directly, and reports a
# tracked transient path even when the block itself is current -- otherwise the one state where
# the guard fires forever is the one state that reads clean.
#
# UNCONDITIONAL, like the hook row, and for the same reason: a withheld stamp does not make an
# unrendered ignore rule any more rendered.
transient_ignore_row() {
TI_RENDERER="$CONSUMER/scripts/ai-dlc/sync-transient-ignore.sh"
TI_SCHEMA="$CONSUMER/.claude/schemas/pipeline-state-paths.json"
# GATED ON THE DECLARATION, NOT ON THE RENDERER, AND THE DIFFERENCE IS A MEASURED FALSE POSITIVE.
# The first cut keyed its "not a silent skip" branch on the RENDERER's absence, mirroring the hook
# row above. That row's absent-branch fires only on a consumer whose validator is missing, which is
# rare; this one fired on EVERY consumer predating the mechanism, because a tree with neither half
# is not a defect -- it is a tree this release has nothing to say about. It failed
# `apply-restamp-worklist`'s C4, whose consumer asserts ZERO hand-back rows, and that fixture was
# right: a row on that tree is noise an operator cannot act on.
#
# The declaration and the renderer shipped in the same release, so "schema present, renderer
# absent" is a real and reportable split -- the declaration arrived and the thing that renders it
# did not -- while "neither present" is simply an older consumer. Gate on the schema and the two
# states stop reading alike.
[ -f "$TI_SCHEMA" ] || return 0
if [ -f "$TI_RENDERER" ]; then
  ti_out="$(bash "$TI_RENDERER" --check --root "$CONSUMER" 2>&1)"; ti_rc=$?
  if [ "$ti_rc" = "1" ]; then
    # TWO CAUSES, AND THE ROW MUST NOT FLATTEN THEM. `--check` exits 1 for a block that was NEVER
    # WRITTEN (`carries no ... block`) and for one that was written and has since DRIFTED from the
    # declaration (`does not match`), and it takes trouble to say which. An earlier revision of this
    # row reported both as "does NOT match the declaration this apply just delivered", which is a
    # WRONG CAUSE on the first: nothing drifted, no declaration moved, and the operator reading it
    # goes looking for a change that does not exist. The remedy is the same command either way; the
    # DIAGNOSIS is not, and this is the only channel the operator reads.
    case "$ti_out" in
      *"carries no AI/DLC transient-state block"*)
        say WORKLIST transient-ignore ".gitignore" \
          "this consumer has NEVER had a transient-state ignore block written. Nothing drifted — the rendered region does not exist, so every path the declaration marks transient is unignored, and a broad \`git add\` commits pipeline scratch state as a tracked file. That is how a stale handoff entry marker re-arms the handoff guard in sessions that never ran a handoff. Write it: \`bash scripts/ai-dlc/sync-transient-ignore.sh\` (it appends its own marker-bounded region and touches nothing else, and names anything already tracked). Detail: $(printf '%s' "$ti_out" | tr '\n' ' ')" ;;
      *)
        say WORKLIST transient-ignore ".gitignore" \
          "the transient-state ignore block no longer matches the declaration this apply just delivered. Every newly-declared transient path is unignored until it is re-rendered, and a broad \`git add\` then commits pipeline scratch state as a tracked file — which is how a stale handoff entry marker re-arms the handoff guard in sessions that never ran a handoff. Re-render it: \`bash scripts/ai-dlc/sync-transient-ignore.sh\` (it rewrites only its own marker-bounded region, and names anything already tracked). Detail: $(printf '%s' "$ti_out" | tr '\n' ' ')" ;;
    esac
  elif [ "$ti_rc" != "0" ]; then
    say DECISION transient-ignore-unreadable ".gitignore" \
      "the transient-state ignore check could not run, so whether this pull's newly-declared transient paths are ignored is UNKNOWN — and unknown reads exactly like clean. Detail: $(printf '%s' "$ti_out" | tr '\n' ' ')"
  fi
  # THE TRACKED HALF, ASKED OF THE INDEX AND NOT OF `--check`. Runs whatever `--check` answered:
  # a current block and a tracked path is a real and silent state, and it is the one that keeps
  # firing after the rule is correct.
  #
  # TWO REASONS, AND ONLY THE SECOND ONE IS STRUCTURAL. The first is that `--check` cannot SEE a
  # tracked path — it returns at its block comparison, above the renderer's own tracked scan. True
  # today and CONTINGENT: someone could widen `--check` to ask the index, and that justification
  # would evaporate while this arm was still required. The second holds whatever any checker does —
  # **an ignore rule has no effect on a file git is already tracking**, so the block being current
  # and the path being tracked are independent facts with independent remedies (`sync-transient-
  # ignore.sh` vs `git rm --cached`), and neither implies the other. Measured: once a path is
  # tracked, `git add -A` and `git commit -a` both capture it with the rule in place.
  if [ -f "$TI_SCHEMA" ] && command -v jq >/dev/null 2>&1 \
     && git -C "$CONSUMER" rev-parse --git-dir >/dev/null 2>&1; then
    ti_tracked=""
    ti_pats="$(jq -r '.paths[] | select(.transient) | .ignore // empty' "$TI_SCHEMA" 2>/dev/null)"
    # Staged like every other loop input here. This row runs AFTER the stamp on the ordinary run, so
    # a failed stage only renders a staging-refused row (a DECISION there, a WORKLIST under --finish,
    # where it runs before the stamp and withholds); it never reads as "nothing tracked".
    ap_stage_or_refuse ti-pats "$ti_pats" ".gitignore" "the transient path patterns of pipeline-state-paths.json" \
    && while IFS= read -r ti_p; do
      [ -n "$ti_p" ] || continue
      ti_n="$(git -C "$CONSUMER" -c core.quotePath=false ls-files -- "$ti_p" "${ti_p%/}" 2>/dev/null | wc -l | tr -d ' ')"
      [ "${ti_n:-0}" -gt 0 ] && ti_tracked="$ti_tracked ${ti_p}(${ti_n})"
    done < "$AP_TMP/ti-pats"
    if [ -n "${ti_tracked// /}" ]; then
      say WORKLIST transient-ignore-tracked ".gitignore" \
        "transient pipeline path(s) are TRACKED on this consumer, and an ignore rule does nothing to a file git already tracks:${ti_tracked}. Each one re-materializes on every checkout of this branch, so a marker no session wrote is present for hooks that read it. Untrack with \`git rm -r --cached <path>\` and commit. Not done here: rewriting an index is the operator's call."
    fi
  fi
else
  # NOT a silent skip -- the same reason the hook row states its own absence.
  say DECISION transient-ignore-unchecked ".gitignore" \
    "scripts/ai-dlc/sync-transient-ignore.sh is not on this consumer, so nothing verified that the transient paths this apply declared are ignored. It is delivered by install.sh's copy loop over core/scripts/; run a fresh install of that script, then \`bash scripts/ai-dlc/sync-transient-ignore.sh\`."
fi
}

# --- AGENT DEFINITIONS: a third DECLARATION delivered in two halves --------------------------
#
# THE SAME SHAPE AS THE TRANSIENT-IGNORE ROW ABOVE, one declaration over. `aiDlcRoles` reaches a
# consumer through the settings merge; `.claude/agents/<role>.md` is `render-agent-definitions.sh`
# projecting that declaration, and on a PULL nothing calls it -- its only invocation site in the
# distribution is `scripts/install.sh`, the path a NEW consumer takes.
#
# WHAT AN UNRENDERED PROJECTION COSTS. The definition is the ONLY channel that binds a role's
# reasoning EFFORT, and it OUTRANKS the session's own resolution rather than filling a gap in
# it. A prompt cannot set effort: measured on the reference consumer, every spawn ran at the
# effort the SESSION resolved -- from its launch flag, or from the user's
# `effortLevel`/`modelSettings` -- and never at the role's, whatever directive the prompt
# carried. A role with no definition is a role running at that session-resolved level, and the
# ledger says so by recording `effort_bound` null -- which names the state without naming its
# cause, since a drifted definition and an absent one are both null there.
#
# GATED ON `aiDlcRoles`, NOT ON THE RENDERER, for `transient_ignore_row`'s measured reason: a
# tree with neither half is not a defect, it is a tree this release has nothing to say about,
# and a row on it is noise the operator cannot act on. Here the renderer answers that question
# ITSELF -- exit 3 is NOT APPLICABLE -- so the gate is the renderer's own verdict rather than a
# second copy of the applicability test in this file. A restated predicate drifts; this one
# cannot, because there is only one.
#
# WHY A `WORKLIST` ROW AND NOT A CALL. `.claude/agents/` is a user-owned directory and the
# renderer DELETES stale generated files in it. This driver has no channel to obtain the
# operator's gate on that edit -- the same reason `settings-merge.sh` is named rather than
# called by the hook row. `--check` never writes, so it is safe from a driver.
agent_definitions_row() {
AD_RENDERER="$CONSUMER/scripts/ai-dlc/render-agent-definitions.sh"
AD_SETTINGS="$CONSUMER/.claude/settings.json"
# The renderer is what decides applicability, but it must EXIST to decide it. A consumer whose
# settings pin roles and whose renderer never arrived is the reportable split -- and it is
# exactly the state every consumer predating this mechanism is in, which is why the absent
# branch is gated on the declaration rather than firing on every older tree.
if [ -f "$AD_RENDERER" ]; then
  ad_out="$(bash "$AD_RENDERER" --check --root "$CONSUMER" 2>&1)"; ad_rc=$?
  case "$ad_rc" in
    0|3) : ;;
    1)
      say WORKLIST agent-definitions ".claude/agents/" \
        "the rendered agent definitions do not match \`aiDlcRoles\` in this consumer's settings. A role with no current definition runs at the session's launch-flag or settings-resolved reasoning effort, not at the one \`aiDlcRoles\` configures for it — the definition's \`effort:\` frontmatter is the only channel that binds the role's own level, and the dispatch guard's prompt sentence measurably does not. Re-render: \`bash scripts/ai-dlc/render-agent-definitions.sh\` (it writes only \`.claude/agents/<role>.md\` for roles \`aiDlcRoles\` declares with a model, removes its own stale projections, and leaves any hand-written definition alone). Detail: $(printf '%s' "$ad_out" | tr '\n' ' ')" ;;
    *)
      say DECISION agent-definitions-unreadable ".claude/agents/" \
        "the agent-definition check could not run, so whether this consumer's roles bind their configured effort is UNKNOWN — and unknown reads exactly like clean. Detail: $(printf '%s' "$ad_out" | tr '\n' ' ')" ;;
  esac
elif [ -f "$AD_SETTINGS" ] && command -v jq >/dev/null 2>&1 \
     && [ "$(jq -r 'has("aiDlcRoles")' "$AD_SETTINGS" 2>/dev/null)" = "true" ]; then
  # NOT a silent skip -- the same reason the two rows above state their own absence.
  say DECISION agent-definitions-unchecked ".claude/agents/" \
    "scripts/ai-dlc/render-agent-definitions.sh is not on this consumer, so nothing rendered the agent definitions its \`aiDlcRoles\` declares, so every role's spawns run at the session's launch-flag or settings-resolved reasoning effort rather than the role's own. It is delivered by install.sh's copy loop over core/scripts/; run a fresh install of that script, then \`bash scripts/ai-dlc/render-agent-definitions.sh\`."
fi
}

# --- THE TWO ORDERS, DISPATCHED ONCE ---------------------------------------------------------
#
# Ordinary apply: stamp, then the hook row. The hook row cannot gate the stamp here because the
# settings merge that answers it has not happened yet -- it is several bullets further into
# step 7 -- so gating on it would withhold every correct run and wedge the consumer.
#
# `--finish`: the hook row FIRST, then the stamp. This invocation happens after that merge, so
# the question is answerable and its answer is verified by a validator rather than attested. A
# still-unwired hook therefore raises `handback` before the guard reads it, and the finisher
# withholds -- which terminates, because registering the hooks is work that clears the row.
#
# The transient-ignore row rides with the hook row in both orders. It is answerable at either
# moment -- unlike the hook row it depends on no later step-7 bullet, because the declaration it
# checks was written by the pure-apply phase above -- so it takes the hook row's position rather
# than introducing a third ordering for a reader to reason about.
#
# THE AGENT-DEFINITION ROW RIDES BESIDE IT AND IS NOT ANSWERABLE THE SAME WAY IN BOTH ORDERS,
# which is stated rather than smoothed over. Its declaration is `aiDlcRoles` in
# `.claude/settings.json`, written by the settings MERGE -- a later step-7 bullet, exactly like
# the hook row's subject. On an ordinary apply it therefore reads the PRE-merge settings, and on
# `--finish` it reads the post-merge ones. Both answers are about a real state of the consumer
# and neither is withheld: a definition stale against the old settings is stale against the new
# ones too whenever the merge did not touch `aiDlcRoles`, and where the merge DID move a role,
# `--finish` is the invocation that sees it. Gating the stamp on the earlier answer is what
# would be wrong, and `say` never does that for a WORKLIST row on the ordinary path.
if [ "$FINISH" = 1 ]; then
  hook_registration_row
  transient_ignore_row
  agent_definitions_row
  write_stamp
else
  write_stamp
  hook_registration_row
  transient_ignore_row
  agent_definitions_row
fi

exit 0
