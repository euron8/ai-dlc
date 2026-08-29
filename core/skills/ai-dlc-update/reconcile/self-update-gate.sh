#!/usr/bin/env bash
# self-update-gate.sh — may the autonomous self-update cycle PUSH, or must it defer?
#
# THE DEFECT THIS EXISTS FOR. SKILL.md step 2 runs the machinery self-update autonomously: it cuts
# a branch, writes the machinery slice, runs the derived fixtures, pushes, opens a PR and
# squash-auto-merges — with no operator gate. The machinery slice includes `core/scripts/*`, and the
# consumer's own `.githooks/pre-push` INVOKES several of those scripts. So the cycle can install a
# validator that then fails the very push the cycle is making, on layer state that predates it and
# whose remedy is rulebook-side work the cycle deliberately does not do.
#
# Observed at v0.183.0 on the reference consumer, filed as
# `PC-S308-SELF-UPDATE-INSTALLS-THE-VALIDATOR-THAT-BLOCKS-ITS-OWN-PUSH`. The ERROR tier shipped in
# that release fires on three pre-existing declaration defects; step 2 would have installed it and
# then been unable to push. It does not deadlock — SKILL.md says a failed push commits locally and
# does not block the run — which is worse in one respect: what it leaves behind is an orphaned local
# branch whose push is PERMANENTLY blocked and a `skill_version` advanced on a commit that will
# never merge. The operator who hit this had to derive the collapsed ordering by hand.
#
# THE GATING SET IS DERIVED, NEVER LISTED. Which scripts can block a push is a property of the
# consumer's pre-push hook, so it is read out of that hook: every `scripts/ai-dlc/<name>.sh` it
# invokes. Hand-listing them here would rot the moment the hook gains a step — and the hook gaining
# a step is exactly when this check matters most. Four are invoked as of v0.184.0; this file names
# none of them.
#
# THE VERDICT IS A DIFFERENTIAL, NOT AN EXIT CODE. Running the incoming copy from a temp path can
# fail for reasons that have nothing to do with its findings — a script that resolves its own
# location, a missing sibling, an unreadable dependency. A bare non-zero would turn any of those
# into a confident "defer", which is a false positive that strands the machinery slice for no
# reason. So each gating script is run TWICE under identical conditions, incoming and current:
#
#   current 0, incoming non-zero  -> DEFER      the incoming version finds something new. Real.
#   both non-zero                 -> UNDECIDED  pre-existing failure or a harness artifact; NOT
#                                               attributable to the incoming version, so it must
#                                               not silently become a defer verdict.
#   incoming 0                    -> OK
#
# MODES
#   self-update-gate.sh <dist-repo> <base-sha> <theirs-ref> <consumer-root>
#       classify. The only mode step 2 runs. (arg order matches layer-drift.sh)
#   self-update-gate.sh --safe-stop <dist-repo> <base-sha> <theirs-ref> <consumer-root>
#       print the FURTHEST release ref in base..theirs that still self-updates cleanly, or
#       nothing (rc 1) if even the first one defers. See below for why this exists.
#
# WHY --safe-stop EXISTS. A DEFER verdict is correct and it is also a dead end: it says the
# machinery slice cannot stand alone, so the slice folds into the gated apply at step 7 --
# which runs AFTER step 3's classify. Any improvement to the CLASSIFIER therefore arrives one
# phase too late to classify the pull that delivers it, and the operator sees a report written
# by the engine they were trying to replace.
#
# Measured on the reference consumer at 0.274.0 -> 0.277.0: this gate returned DEFER, classify
# ran the stale engine, and three overrides upstream had just ABSORBED were reported as
# ordinary HARD-OVERRIDE-DRIFT-SECTION -- "re-adopt the new wording" -- which is the exact
# misreading override_supersessions was built to end. The remedy was to stop at 0.275.0 first,
# where the slice is machinery-only, and nothing in the tree said so or could be asked.
#
# THE CANDIDATES ARE RELEASE COMMITS, not every commit: the stamp records a VERSION, so a
# mid-release stop is not a state a consumer can hold. And the verdict per candidate is
# obtained by RUNNING THIS SCRIPT, never by re-deriving its arms -- a second implementation of
# the predicate is the one whose bugs nobody finds, and the walk must agree with the gate by
# construction rather than by review.
#
# Output: TSV — STATUS<TAB>SCRIPT<TAB>DETAIL
#   SELF-UPDATE-OK        nothing in the slice can block the push; proceed autonomously.
#   SELF-UPDATE-DEFER     an incoming script the consumer's pre-push runs fails on the consumer's
#                         EXISTING tree. Do NOT cut the self-update branch and do NOT push. Fold
#                         the machinery slice into the gated apply, where the operator fixes the
#                         layer state and machinery + rulebook land on one branch.
#   SELF-UPDATE-UNDECIDED the differential could not attribute the failure. Report it; treat as
#                         DEFER, because acting autonomously on an unattributable failure is the
#                         one thing this gate exists to prevent.
#   SELF-UPDATE-CARRY     ADVISORY, and it accompanies any verdict including OK. One row per
#                         machinery path the consumer has DIVERGED on. It does not stop the
#                         cycle; it removes that path from it. Step 2 writes none of them and
#                         carries each to the step-7 gated apply, where apply.sh already emits
#                         a WORKLIST semantic-merge row. A CARRY row beside an OK verdict means
#                         "self-update the rest, hand this path to the operator" -- the case
#                         step 2 previously had no disposition for at all.
#   SELF-UPDATE-SAFE-STOP accompanies every DEFER: the furthest release in the range that DOES
#                         self-update cleanly, so the operator can split the pull and land the
#                         engine before it is used — or the explicit statement that no such
#                         release exists, which is a different answer from silence. When the
#                         consumer's own `skill_commit` is already at or past the named ref its
#                         machinery has already landed, and the row says the split buys nothing
#                         rather than recommending a hop that would advance only the rulebook.
# Exit:   0 ALWAYS. A classifier, not a gate — the CALLER decides, same posture as layer-drift.sh.
set -uo pipefail

SELF_SRC="$0"

if [ "${1:-}" = "--safe-stop" ]; then
  shift
  SS_DIST="${1:?usage: self-update-gate.sh --safe-stop <dist-repo> <base-sha> <theirs-ref> <consumer-root>}"
  SS_BASE="${2:?}"; SS_THEIRS="${3:?}"; SS_CONSUMER="${4:?}"

  # Release commits in base..theirs, OLDEST FIRST. A release is a commit that moves VERSION --
  # derived, because any hand-list of release shas rots on the next release, and the file that
  # defines a release is the one the release-triple validator already keys on.
  ss_cands="$(git -C "$SS_DIST" rev-list --reverse "${SS_BASE}..${SS_THEIRS}" -- VERSION 2>/dev/null)"
  if [ -z "$ss_cands" ]; then
    # NOT A SILENT ZERO. No release boundary in the range is a real answer (a docs-only range),
    # and it is also what a bad BASE looks like. Say which, on stderr, and return nothing.
    if git -C "$SS_DIST" rev-parse -q --verify "${SS_BASE}^{commit}" >/dev/null 2>&1; then
      printf 'self-update-gate --safe-stop: no commit touches VERSION in %s..%s, so there is no intermediate release to stop at.\n' "$SS_BASE" "$SS_THEIRS" >&2
    else
      printf 'self-update-gate --safe-stop: base %s does not resolve in %s — the range is unreadable, which is NOT the same as empty.\n' "$SS_BASE" "$SS_DIST" >&2
    fi
    exit 1
  fi

  # EVERY CANDIDATE IS EVALUATED, AND THE LATEST CLEAN ONE WINS. The first cut stopped at the
  # first candidate that deferred, on the reasoning that a later clean ref sits "behind" the
  # coupling — and that reasoning is wrong, because each verdict is computed BASE→candidate,
  # never incrementally. A release that introduces a coupling and a later one that resolves it
  # both sit in the range, and base→later is then a single clean hop that lands strictly more
  # than the early stop would. Breaking early silently under-reports how far the operator can
  # go, which is the same shape as any other check that answers before it has looked.
  #
  # The nested classify runs must not advise. This is a COST guard, not a termination one, and
  # the distinction is worth stating because the first version of this comment claimed
  # termination and a mutant removing the guard came back GREEN — the recursion is naturally
  # bounded, since a nested walk covers a strictly shorter range. What it buys is that a
  # deferring candidate does not trigger a full sub-walk of its own, which would make the whole
  # thing quadratic in the number of releases in the range. Set before the loop so every child
  # inherits it.
  export AI_DLC_GATE_IN_SAFE_STOP=1
  ss_best=""
  for ss_c in $ss_cands; do
    [ "$ss_c" = "$SS_THEIRS" ] && continue          # the full pull is what the caller already asked
    ss_out="$(bash "$SELF_SRC" "$SS_DIST" "$SS_BASE" "$ss_c" "$SS_CONSUMER" 2>/dev/null)"
    case "$ss_out" in
      *SELF-UPDATE-DEFER*|*SELF-UPDATE-UNDECIDED*) continue ;;
    esac
    ss_best="$ss_c"
  done
  [ -n "$ss_best" ] || exit 1
  printf '%s\n' "$ss_best"
  exit 0
fi

DIST="${1:?usage: self-update-gate.sh <dist-repo> <base-sha> <theirs-ref> <consumer-root>}"
BASE="${2:?}"
THEIRS="${3:?}"
CONSUMER="${4:?}"

emit() { printf '%s\t%s\t%s\n' "$1" "$2" "$3"; }

# A DEFER WITHOUT A NEXT STEP IS A DEAD END, and the operator's next step is not obvious:
# it is a REF, derivable only by running this gate against each release in the range. So
# every DEFER terminal ends with the answer or with the explicit statement that there is
# none. Suppressed under --safe-stop, which is what would otherwise re-enter this walk.
#
# AND THE RECOMMENDATION IS DERIVED FROM THE RANGE, WHICH IS ONLY HALF THE QUESTION. The row's
# whole rationale is "step 3 would classify this pull with the engine this pull was going to
# replace". On a consumer whose MACHINERY is already at or past the ref it names, that premise is
# false: the engine has already landed, and the split it urges would advance only the rulebook
# pair. Filed by the reference consumer as
# `PC-S331-SAFE-STOP-IGNORES-THE-CONSUMERS-OWN-SKILL-COMMIT` after a pull from a stamp whose skill
# pair was two releases ahead of its rulebook pair — the row named v0.340.0's commit while the
# consumer's `skill_commit` already sat one commit past it. Measured there: `grep -cF skill_commit`
# over this file returned **0**.
#
# THE ROW IS ANNOTATED, NEVER SUPPRESSED. A DEFER whose next step is silence is the dead end this
# whole function exists to remove, so the answer stays and gains the fact that changes what it
# means. `skill_commit` is read from the stamp rather than taken as an argument, and
# `unregistered-drift.sh` reads the same field the same way for the structurally identical reason
# (an intermediate machinery ref that is neither `commit` nor `theirs`).
advise_safe_stop() {
  [ -n "${AI_DLC_GATE_IN_SAFE_STOP:-}" ] && return 0
  # SET HERE, not only inside the guard that fills it. This file runs under `set -u`, the message
  # below interpolates `$_sk`, and the only assignment used to live in `machinery_at_or_past` — so
  # any path that reached the message without running the guard died on an unbound variable and
  # emitted NO ROW AT ALL. Found by a mutant: bypassing the guard was supposed to make the row fire
  # unconditionally and instead made it disappear, which is the failure mode where a check that
  # crashed and a check that had nothing to say are the same empty output.
  _sk=""
  _ss="$(bash "$SELF_SRC" --safe-stop "$DIST" "$BASE" "$THEIRS" "$CONSUMER" 2>/dev/null)"
  if [ -n "$_ss" ]; then
    _sv="$(git -C "$DIST" show "${_ss}:VERSION" 2>/dev/null | tr -d '[:space:]')"
    if machinery_at_or_past "$_ss"; then
      emit SELF-UPDATE-SAFE-STOP "$_ss" "SPLIT BUYS NOTHING HERE — this consumer's own \`skill_commit\` (${_sk}) is already at or past ${_sv:-$_ss}, so its machinery has already landed and step 3 will classify on an engine that is NOT the one this pull replaces. Pulling to ${_ss} first would advance only the rulebook pair. Fold the slice into the gated apply. The DEFER above still stands and is unaffected by this."
    else
      emit SELF-UPDATE-SAFE-STOP "$_ss" "pull to ${_sv:-$_ss} FIRST — its slice self-updates cleanly, so the engine lands and step 2 re-invokes on it. Then pull again for the rest. Without the split, step 3 classifies this pull with the engine this pull was going to replace, and any classifier improvement in the range reports nothing. Run: ai-dlc-update ${_ss} apply, then ai-dlc-update apply."
    fi
  else
    emit SELF-UPDATE-SAFE-STOP "-" "no intermediate release in ${BASE}..${THEIRS} self-updates cleanly, so the split that would land the engine first does not exist here. Fold the slice into the gated apply and expect step 3 to classify on the CURRENT engine."
  fi
}

# Is the consumer's machinery already at or past $1? Sets `_sk` to the stamp's `skill_commit` for
# the caller's message.
#
# THE ANCESTRY TEST ALREADY ANSWERS NO FOR EVERY DEGENERATE STAMP, so this carries no special case
# for them and that is a measured decision, not an oversight. `unregistered-drift.sh` reads the same
# field and DOES guard `skill_commit == commit` and an unresolvable ref, because it compares BYTE
# IDENTITY, where a missing guard changes the answer. Here the question is ancestry:
#
#   skill_commit == commit   `$1` is a release in BASE..THEIRS, so it is a DESCENDANT of BASE and
#                            can never be its ancestor -> false, with no guard needed.
#   unresolvable ref         `merge-base --is-ancestor` exits non-zero on a bad object -> false.
#
# Both guards were written, and both were then DELETED because their mutants came back GREEN: a
# guard whose removal changes no answer is a check that cannot fire, which this repo treats as
# indistinguishable from one that passed. The two states are still asserted in the fixture — what
# holds them is the ancestry test, which is the honest place for them to be held.
machinery_at_or_past() {
  _sk=""
  _st="$CONSUMER/.claude/.ai-dlc-version"
  [ -f "$_st" ] || return 1
  _sk="$(sed -n 's/^skill_commit:[[:space:]]*\([^[:space:]]*\).*/\1/p' "$_st" | head -1)"
  [ -n "$_sk" ] || return 1
  # `--is-ancestor` is true for equality too, which is the "at" in "at or past".
  git -C "$DIST" merge-base --is-ancestor "$1" "$_sk" 2>/dev/null
}

# ---- ARM C: A MACHINERY PATH THE CONSUMER HAS DIVERGED ON ------------------------------
# Step 2 justifies autonomy -- no operator gate, auto-merged PR -- on the declaration that the
# skill's own files are overwrite-safe, and then writes the whole MACHINERY set from `theirs`.
# For a machinery path the consumer has edited those two sentences conflict and the step used
# to supply no rule, so the literal reading destroys the consumer's delta. Filed on the
# reference consumer as PC-S330-STEP-2-HAS-NO-DISPOSITION-FOR-A-CONSUMER-MODIFIED-MACHINERY-PATH
# after that tree's own `.githooks/pre-push` -- the fourth `machinery:` entry -- came back
# BOTH-CHANGED->CLASSIFY on a live pull. The operator stopped and reasoned about it by hand;
# nothing in the tooling would have.
#
# ADVISORY, NOT A VERDICT. This does not stop the cycle and must not: the remaining paths
# self-update perfectly well. It removes paths FROM the cycle, one SELF-UPDATE-CARRY row each,
# and step 2 carries them to the step-7 gated apply where `apply.sh` already emits a
# `WORKLIST semantic-merge <path>` row. Deferring the whole slice instead would strand it for
# a reason the operator-gated half already handles, which is the false positive this file's
# header exists to warn about.
#
# THE BUCKET IS NOT RE-DERIVED HERE. `preclassify.sh` owns the base/theirs/ours comparison and
# step 2 already calls it for the ALREADY-AT-THEIRS subtraction; a second implementation of
# that rule is the one whose drift nobody finds. This arm runs it and filters.
#
# KEYED ON THE `->CLASSIFY` MARKER, NOT ON `BOTH-CHANGED`. That token is only the
# modified-both-sides member. `BOTH-ADDED->CLASSIFY`, `UPSTREAM-DELETED+consumer-modified->CLASSIFY`
# and `UPSTREAM-MOD+consumer-deleted->CLASSIFY` all carry consumer state on a machinery path,
# and a subtraction spelled with the one bucket name overwrites three of the four cases while
# reading as if it had fixed them. `RELOCATE-MOVE+consumer-edited` records a divergence without
# the marker, so it is matched by name -- the only bucket that has to be.
#
# THAT KEY IS NOT INVENTED HERE. `apply.sh`'s own dispatch already reads the same marker the same
# way -- its `*CLASSIFY*)` arm is what turns such a path into the `WORKLIST semantic-merge` row
# this arm tells step 2 to carry it to. Keying on anything narrower would name a set the
# downstream half does not agree with, which is how the two would drift apart silently.
if [ -z "${AI_DLC_GATE_IN_SAFE_STOP:-}" ]; then
  # Suppressed under --safe-stop for COST, not correctness: that walk reads only DEFER and
  # UNDECIDED, so an advisory row cannot change any answer it computes, and running this once
  # per release candidate in the range buys nothing. Same reasoning as advise_safe_stop's guard.

  # The machinery globs, read from the co-located manifest rather than listed here -- the list
  # gaining an entry is exactly when this arm matters most. `core/scripts/ai-dlc/*` is the one
  # CONSUMER-shaped entry: upstream the path is `core/scripts/<name>`, and matching a dist path
  # against it directly yields nothing at all, silently. SKILL.md documents the same
  # substitution for the same reason.
  #
  # `set -f` IS LOAD-BEARING AND ITS ABSENCE IS SILENT. These entries are git PATHSPECS, and an
  # unquoted `$C_GLOBS` in a `for` is subject to shell pathname expansion first -- so
  # `core/rules/*.md` expands against the CWD before git ever sees it, and every glob entry
  # degrades to whatever happened to be on disk there. Measured while building this arm: the
  # machinery set collapsed from thirteen globs to the ONE entry that carries no glob character,
  # the arm went quiet on two real divergences, and nothing anywhere reported an error.
  #
  # RESOLVED AGAINST BOTH REFS, NOT THE WORKING TREE. A machinery path DELETED at `theirs` is
  # absent from a `ls-files` of the checkout, and that path is exactly the
  # `UPSTREAM-DELETED+consumer-modified->CLASSIFY` case -- the one where the consumer's copy is
  # the only copy left. Keying on the checkout drops it, quietly, and it is the divergence with
  # the most to lose.
  #
  # `ls-files --with-tree`, NOT `ls-tree`. These entries are the manifest's own glob dialect and
  # only the index commands speak it: `ls-tree` matches a pathspec by literal prefix, returns
  # EMPTY for every globbed entry, and reports no error while doing it -- and `:(glob)` magic is
  # rejected by that command outright. `--with-tree=<ref>` gives ls-files semantics against an
  # arbitrary ref, which is what resolving each entry at BASE and at THEIRS requires.
  C_MANIFEST="$(dirname "$SELF_SRC")/setup-sites.md"
  C_PATHS=""
  if [ -f "$C_MANIFEST" ]; then
    C_GLOBS="$(awk '/^machinery:/{f=1;next} f&&/^  - /{sub(/^  - /,"");print;next} f{exit}' "$C_MANIFEST")"
    set -f
    for c_g in $C_GLOBS; do
      case "$c_g" in core/scripts/ai-dlc/*) c_g="core/scripts/${c_g#core/scripts/ai-dlc/}" ;; esac
      C_PATHS="$C_PATHS
$(git -C "$DIST" ls-files --with-tree="$BASE" -- "$c_g" 2>/dev/null)
$(git -C "$DIST" ls-files --with-tree="$THEIRS" -- "$c_g" 2>/dev/null)"
    done
    set +f
    C_PATHS="$(printf '%s\n' "$C_PATHS" | grep -v '^$' | sort -u)"
  fi

  C_PRE="$(dirname "$SELF_SRC")/preclassify.sh"
  if [ -n "$C_PATHS" ] && [ -f "$C_PRE" ]; then
    c_out="$(bash "$C_PRE" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" 2>/dev/null || true)"

    # A SILENT ZERO HERE IS THE FAILURE MODE THIS ARM WOULD OTHERWISE HAVE. preclassify
    # printing nothing reads exactly like "no path diverged", and both produce no CARRY row.
    # So the emptiness is only believed when the range is genuinely empty; a non-empty
    # base..theirs with no buckets at all means the derivation did not run, and this gate's
    # own doctrine for an unattributable failure is UNDECIDED -- reported, treated as defer,
    # never silently OK.
    if [ -z "$c_out" ] \
       && [ -n "$(git -C "$DIST" diff --name-only "${BASE}..${THEIRS}" -- core/ 2>/dev/null)" ]; then
      emit SELF-UPDATE-UNDECIDED "preclassify.sh" "the bucket derivation returned no rows while ${BASE}..${THEIRS} changes core/ paths, so whether any machinery path is consumer-modified is UNKNOWN. An empty bucket set reads exactly like a clean one; a gate that cannot read its own subject must not return OK."
    else
      while IFS="$(printf '\t')" read -r c_st c_path c_cons c_bucket; do
        [ -n "${c_bucket:-}" ] && [ -n "${c_path:-}" ] || continue
        case "$c_bucket" in
          *'->CLASSIFY'*|*consumer-edited*) ;;
          *) continue ;;
        esac
        grep -qxF "$c_path" <<EOF || continue
$C_PATHS
EOF
        emit SELF-UPDATE-CARRY "$c_path" "the consumer's copy at ${c_cons:-?} has DIVERGED (status ${c_st:-?}, bucket $c_bucket). This is a machinery path, so the self-update would write \`theirs\` over it autonomously and auto-merge the result. Do NOT write it: drop it from the slice, report it, and carry it to the step-7 gated apply, which emits a WORKLIST semantic-merge row for it. The rest of the slice is unaffected by this row."
      done <<EOF
$c_out
EOF
    fi
  fi
fi

# ---- THE MACHINERY SLICE CANNOT ALWAYS STAND ALONE -------------------------------------
# Step 2's stated premise is "a fixture's subject is always machinery". It is FALSE, and the
# arms below are the two ways it fails. Both were measured on the reference consumer at
# 0.249.0 against 0.261.0: 7 of that tree's 109 fixtures are red in the state step 2 builds,
# and the operator had to cut a branch, write 17 paths and run 43 fixtures to discover it.
#
# This runs BEFORE the push-blocking differential below because it is cheaper and it is a
# harder stop: the push arm asks whether the slice can be PUSHED, this asks whether the slice
# can be GREEN at all. Both answer SELF-UPDATE-DEFER so step 2 needs no new vocabulary --
# the existing "fold the machinery slice into the gated apply" handling is exactly right.

# --- ARM R1: the map declares a check whose anchor is rulebook-side ----------------------
# enforcement-map.yaml is MACHINERY; the `CHECK_LOADED` anchors it is joined against live in
# steps/gate-validation.md, which is RULEBOOK and which step 2 deliberately excludes. So a
# release that adds a check makes the map (new) reference an anchor (old) that does not exist
# yet, and validate-enforcement-map.sh fails on the consumer's tree through no fault of it.
# Measured: checks 33, 34 and 35 on the reference consumer.
#
# BOTH SIDES DERIVED, and scoped to ids that are anchored UPSTREAM -- 14 of the map's entries
# are named validators with no gate section at all, and demanding an anchor for those would
# defer every pull forever.
R1_GV_THEIRS="$(git -C "$DIST" show "${THEIRS}:core/skills/ai-dlc/steps/gate-validation.md" 2>/dev/null || true)"
R1_GV_OURS=""
for cand in "$CONSUMER/.claude/skills/ai-dlc/steps/gate-validation.md" \
            "$CONSUMER/core/skills/ai-dlc/steps/gate-validation.md"; do
  [ -f "$cand" ] && { R1_GV_OURS="$(cat "$cand")"; break; }
done
if [ -n "$R1_GV_THEIRS" ] && [ -n "$R1_GV_OURS" ]; then
  r1_theirs="$(grep -oE '^<!-- CHECK_LOADED: [^ ]+ -->' <<<"$R1_GV_THEIRS" | sed 's/.*: //; s/ -->//' | sort -u)"
  r1_ours="$(grep -oE '^<!-- CHECK_LOADED: [^ ]+ -->' <<<"$R1_GV_OURS" | sed 's/.*: //; s/ -->//' | sort -u)"
  # A zero here must not be a false zero: if either side parsed to nothing the anchor grammar
  # moved, and comparing an empty set to anything reports agreement it never computed.
  if [ -z "$r1_theirs" ] || [ -z "$r1_ours" ]; then
    emit SELF-UPDATE-UNDECIDED "gate-validation.md" "could not parse CHECK_LOADED anchors from one side (theirs=$(grep -c . <<<"$r1_theirs"), ours=$(grep -c . <<<"$r1_ours")). An empty anchor set compares equal to nothing, so this must not read as agreement."
  else
    r1_missing="$(comm -23 <(printf '%s\n' "$r1_theirs") <(printf '%s\n' "$r1_ours") | tr '\n' ' ' | sed 's/ *$//')"
    if [ -n "$r1_missing" ]; then
      emit SELF-UPDATE-DEFER "enforcement-map.yaml" "the incoming map declares check(s) [$r1_missing] whose CHECK_LOADED anchor lives in steps/gate-validation.md -- RULEBOOK, which step 2 excludes. Installing the map without it leaves validate-enforcement-map.sh failing on the consumer's own tree, and every fixture that drives it red. Machinery and rulebook must land together: fold the slice into the gated apply."
      deferred_join=1
    fi
  fi
fi

# --- ARM R2: a derived fixture asserts on rulebook that is about to differ ---------------
# The arm the reference consumer actually hit. postcompact-rulebook-recovery runs
# validate-reattach-budget.sh against the SHIPPED SKILL.md and mutates its mandate -- its
# subject is rulebook, not machinery. A fixture like that cannot be green while machinery is
# at theirs and rulebook at ours, whatever the slice contains.
#
# DIFFERENTIAL, NOT STATIC. Asking "does any fixture touch rulebook" would defer on a consumer
# whose rulebook is already current, stranding the machinery slice for no reason -- the exact
# false positive this file's header warns about. So the arm fires only when the rulebook is
# ALSO about to change. If ours already equals theirs, no fixture can break on it.
# COMPARE OURS AGAINST THEIRS, NEVER THE RANGE. The first version of this arm asked
# `git diff base..theirs`, which is a question about the DISTRIBUTION's history and not
# about this consumer. A consumer that already holds theirs' rulebook still shows a
# non-empty range diff, so the arm deferred a pull it had no business deferring — the
# machinery slice stranded for no reason, which is the precise false positive this file's
# header warns about and which the fixture's assertion 3 exists to catch. What matters is
# whether the consumer's OWN rulebook is about to change, so each candidate is compared by
# CONTENT against theirs and only genuine differences count.
R2_CAND="$(git -C "$DIST" diff --name-only "${BASE}..${THEIRS}" -- \
           core/skills/ai-dlc/SKILL.md \
           core/skills/ai-dlc/steps/ \
           core/skills/ai-dlc/escalations.md \
           core/skills/ai-dlc/rule-authoring.md \
           core/team-roles/ 2>/dev/null)"
R2_RB=""
for r2p in $R2_CAND; do
  r2_consumer="$CONSUMER/.claude/${r2p#core/}"
  # Absent at the consumer means this pull ADDS it, which is a change by definition.
  if [ ! -f "$r2_consumer" ]; then
    R2_RB="$R2_RB $(basename "$r2p")"; continue
  fi
  if ! git -C "$DIST" show "${THEIRS}:${r2p}" 2>/dev/null | cmp -s - "$r2_consumer"; then
    R2_RB="$R2_RB $(basename "$r2p")"
  fi
done
R2_RB="$(printf '%s' "${R2_RB# }")"
if [ -n "$R2_RB" ]; then
  # Fixtures whose NON-COMMENT code resolves a rulebook file in the LIVE tree. A comment
  # naming SKILL.md is not a subject -- a whole-file grep is satisfied by prose.
  R2_HITS=""
  for fx in "$DIST"/core/fixtures/*/; do
    [ -d "$fx" ] || continue
    # Read once into a variable and feed the readers a HERE-STRING. `... | grep -q` under
    # `pipefail` reports the WRITER's EPIPE once the upstream's output past the match
    # exceeds the pipe buffer, so the test answers "not found" on input that contains the
    # pattern -- a size threshold, wrong permanently and with no symptom. I54b catches it.
    r2_body="$(grep -hv '^[[:space:]]*#' "$fx"*.sh 2>/dev/null || true)"
    grep -qE '(SKILL\.md|escalations\.md|rule-authoring\.md|skills/ai-dlc/steps/)' <<<"$r2_body" || continue
    grep -qE '\$\{?(D_ROOT|ROOT|REPO_ROOT|AI_DLC_ROOT)\b' <<<"$r2_body" || continue
    R2_HITS="$R2_HITS $(basename "${fx%/}")"
  done
  if [ -n "$R2_HITS" ]; then
    emit SELF-UPDATE-DEFER "rulebook-coupled-fixtures" "this pull changes rulebook file(s) [$R2_RB], and fixture(s)${R2_HITS} assert against a rulebook file resolved in the live tree. Step 2 installs machinery without rulebook, so those fixtures judge new machinery against the OLD rulebook and go red on a pull that broke nothing. Fold the slice into the gated apply so both land on one branch."
    deferred_join=1
  fi
fi

if [ "${deferred_join:-0}" -eq 1 ]; then
  emit SELF-UPDATE-DEFER "-" "the machinery slice cannot be green on its own for this pull. Step 2's premise that a fixture's subject is always machinery does not hold here. Do NOT cut the self-update branch."
  advise_safe_stop
  exit 0
fi

# The consumer's hook is the authority on what can block ITS push. Fall back to the shipped copy
# only when the consumer has none — a consumer that has never armed the hook still deserves the
# right answer about what WOULD block once it does.
HOOK="$CONSUMER/.githooks/pre-push"
[ -f "$HOOK" ] || HOOK="$DIST/core/git-hooks/pre-push"
if [ ! -f "$HOOK" ]; then
  emit SELF-UPDATE-UNDECIDED "-" "no pre-push hook found at $CONSUMER/.githooks/pre-push or in the distribution, so the set of scripts that can block a push is unknown. A gate that cannot read its own subject must not return OK."
  exit 0
fi

# Scripts the hook invokes, by basename. Derived from the hook text.
INVOKED="$(grep -oE 'scripts/ai-dlc/[A-Za-z0-9._-]+\.sh' "$HOOK" | sed 's|.*/||' | sort -u)"

# Core scripts this pull changes, by basename.
CHANGED="$(git -C "$DIST" diff --name-only "${BASE}..${THEIRS}" -- core/scripts/ 2>/dev/null \
            | sed 's|.*/||' | sort -u)"

if [ -z "$CHANGED" ]; then
  emit SELF-UPDATE-OK "-" "this pull changes no core/scripts/ path, so nothing the pre-push invokes can be replaced by the self-update."
  exit 0
fi

GATING="$(printf '%s\n' "$INVOKED" | grep -Fxf <(printf '%s\n' "$CHANGED") 2>/dev/null || true)"

if [ -z "$GATING" ]; then
  emit SELF-UPDATE-OK "-" "the slice changes $(printf '%s\n' "$CHANGED" | grep -c .) core script(s), none of which the consumer's pre-push invokes, so the self-update cannot install something that blocks its own push."
  exit 0
fi

TMP="$(mktemp -d "${TMPDIR:-/tmp}/self-update-gate-XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

deferred=0
while IFS= read -r name; do
  [ -n "$name" ] || continue

  # Incoming copy, out of the distribution at theirs.
  if ! git -C "$DIST" show "${THEIRS}:core/scripts/$name" > "$TMP/new-$name" 2>/dev/null; then
    emit SELF-UPDATE-UNDECIDED "$name" "cannot read core/scripts/$name at $THEIRS, so the differential has no incoming side to compare."
    deferred=1
    continue
  fi

  # The consumer's CURRENT copy is the control side. Same temp directory, so both runs meet the
  # same resolution conditions and a location-dependent failure cancels out instead of being
  # attributed to the incoming version.
  cur="$CONSUMER/scripts/ai-dlc/$name"
  if [ ! -f "$cur" ]; then
    emit SELF-UPDATE-OK "$name" "the consumer has no current copy at scripts/ai-dlc/$name, so this pull ADDS it rather than replacing something the hook already runs against this tree."
    continue
  fi
  cp "$cur" "$TMP/cur-$name"

  ( cd "$CONSUMER" && bash "$TMP/cur-$name" >/dev/null 2>&1 ); rc_cur=$?
  ( cd "$CONSUMER" && bash "$TMP/new-$name" >/dev/null 2>&1 ); rc_new=$?

  # AGREEMENT IS NOT A DIFFERENTIAL SIGNAL, WHATEVER THE CODE. This gate asks exactly one
  # question -- does the INCOMING version fail where the CURRENT one passes -- and two runs that
  # return the same code answer it with "no". Reading anything more into an equal pair requires
  # knowing WHY each side failed, which an exit code cannot supply.
  #
  # v0.288.0 scoped this exemption to 2 and 2 alone, on the ground that 2 is the declared token
  # for a fumbled invocation and this bare probe IS the fumbled caller. That reasoning was right
  # and the SCOPE was too narrow, because a probe can ask the wrong question without earning a
  # usage error. Re-measured against a consumer built by running install.sh into an empty tree,
  # over every script that consumer's pre-push actually invokes -- SEVEN, not the five v0.288.0
  # had:
  #
  #   script                           bare rc   how the pre-push invokes it
  #   validate-audit-anchors.sh              2   --trunk-push, with refs on stdin
  #   validate-provenance-block.sh           2   --strays
  #   audit-rule-files.sh                    1   --fail-on=deterministic
  #   validate-layer-entries.sh              0   bare
  #   validate-compact-window.sh             0
  #   validate-fixture-drivability.sh        0
  #   sync-taught-schema.sh                  0
  #
  # THREE OF SEVEN take arguments this probe cannot pass, and the third of them is the case the
  # 2,2 scope could not reach. `audit-rule-files.sh` bare defaults to `--fail-on=any` while the
  # hook passes `--fail-on=deterministic`, so the probe exits 1 while printing
  # `tier-1 findings: 0` -- it fails a threshold the hook never applies, identically on both
  # sides, and the old both-non-zero arm called that an unattributable failure and deferred.
  # Any pull touching that script therefore folded the machinery slice into the operator-gated
  # apply, for no rulebook reason: the exact cost `pull graph in TWO hops` exists to avoid,
  # arriving through a DIFFERENT DEFAULT rather than through a usage error.
  #
  # THE SCOPING THAT KEEPS THIS FROM REMOVING THE GATE IS UNCHANGED, and it is the arm below:
  # `rc_cur` 0 with a non-zero `rc_new` still DEFERS. A version that newly starts or stops
  # refusing its own invocation still disagrees with its predecessor and still falls through --
  # 0,2 and 2,1 alike. Equality is the whole exemption, and equality is what carries no
  # information.
  if [ "$rc_cur" -eq "$rc_new" ]; then
    emit SELF-UPDATE-OK "$name" "both versions exit $rc_cur against this consumer's tree. Equal codes are not a differential signal: this probe is bare -- no arguments, no stdin -- and cannot pass what the pre-push passes, so a shared non-zero says the probe asked the wrong question, not that the incoming version is worse. Deferring on agreement stranded the machinery slice on every pull touching such a script."
  elif [ "$rc_new" -eq 0 ]; then
    emit SELF-UPDATE-OK "$name" "the incoming version passes against this consumer's existing tree (current version rc=$rc_cur), so installing it cannot block the push."
  elif [ "$rc_cur" -eq 0 ]; then
    deferred=1
    emit SELF-UPDATE-DEFER "$name" "the INCOMING version exits $rc_new against this consumer's existing tree while the current version exits 0 — the self-update would install a check that then fails its own push, on state that predates this pull. Do NOT cut the self-update branch: fold the machinery slice into the gated apply so the operator can fix the layer state and land machinery + rulebook on one branch."
  else
    deferred=1
    emit SELF-UPDATE-UNDECIDED "$name" "both versions exit non-zero (current $rc_cur, incoming $rc_new), so the failure is pre-existing or a harness artifact and is NOT attributable to this pull. Treat as defer — acting autonomously on an unattributable failure is what this gate exists to prevent."
  fi
done <<EOF
$GATING
EOF

if [ "$deferred" -ne 0 ]; then
  emit SELF-UPDATE-DEFER "-" "at least one gating script defers; step 2 must not push. Fold the machinery slice into the gated apply."
  advise_safe_stop
fi
exit 0
