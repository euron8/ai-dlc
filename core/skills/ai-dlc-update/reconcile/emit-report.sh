#!/usr/bin/env bash
# reconcile-region: exempt — this file IS the driver that renders the region.
# emit-report.sh — the reconcile's MECHANICAL sections, RENDERED by a driver, not composed by the
# update skill's LLM. And a --verify that fails if a report's mechanical region is stale, missing,
# or hand-edited.
#
# WHY THIS EXISTS — the whole point.
#
# The dry-run report is authored by the update skill's LLM. It runs the detectors and narrates
# their output into a report. That makes every mechanical finding OPTIONAL BY OMISSION: a step the
# narrator forgets is silently skipped, and a `HARD-*` blocker dropped from the report is one the
# operator approves `apply` without seeing. It happened — an in-place core-schema edit was flagged
# HARD by the detector and left out of two real reports. Fixing the DETECTOR did not fix this,
# because an LLM stands between the detector and the operator and can drop the line.
#
# So the mechanical sections are no longer narrated. This driver runs every mechanical detector
# -- the set is DERIVED and bound by I105, never the parenthetical list this line used to carry --
# and RENDERS them into one
# `BEGIN/END GENERATED: reconcile-mechanical` region, deterministically. The skill pastes that
# region VERBATIM and writes only the genuinely semantic sections (the per-file 3-way prose merge
# results, the operator questions) AROUND it. `--verify` re-renders and byte-compares — so a report
# whose mechanical region drifted from the tools, or that never had one, FAILS. The operator can
# run `--verify` themselves: one command, and they know whether a report is sound, instead of
# re-running detectors by hand. The residual LLM work (prose merges) is irreducibly semantic; the
# mechanical findings are now un-droppable.
#
# The detectors take args in DIFFERENT orders (a pre-existing quirk); this wraps them:
#   preclassify.sh        <dist> <base> <theirs> <consumer>   KIND<TAB>path<TAB>cons<TAB>bucket
#   unregistered-drift.sh <dist> <base> <consumer> <theirs>   STATUS<TAB>file<TAB>detail
#   layer-drift.sh        <dist> <base> <theirs> <consumer>   STATUS<TAB>entry<TAB>tgt<TAB>detail
#   hard-blockers.sh      <dist> <base> <consumer> <theirs>   (its own wrapper, stripped here)
#                         — PRE-APPLY form. That wrapper also takes `--post-apply`, which is the
#                           right form once apply has written core; this renderer runs before any
#                           write, so the plain form is correct here and stays.
#   relabel-…             <consumer> --dist <dist> --theirs <theirs>
#   ledger-reverify.sh    <dist> <base> <consumer> <theirs>   STATUS<TAB>entry<TAB>detail
#   retired-tokens.sh     <dist> <base> <theirs> <consumer> [path]  STATUS<TAB>path<TAB>token
#   warn-shadowed-…       --root <consumer>                        STATUS<TAB>fork<TAB>detail
#   predicate-diff…       <dist> <base> <theirs> <consumer>        STATUS<TAB>subject<TAB>detail
#   retired-fixtures.sh   <dist> <theirs> <consumer>               STATUS<TAB>cons-path<TAB>detail
#   retired-layer-contract.sh / retired-layer-passage.sh / retired-layer-token.sh
#                         <dist> <base> <theirs> <consumer>        STATUS<TAB>path<TAB>detail
#
# WHICH SCRIPTS BELONG HERE IS A DERIVED JOIN, NOT A HAND-LIST. Every `reconcile/*.sh` is either
# invoked above or carries a `# reconcile-region: exempt — <reason>` line in its own header, and
# `I105` fails the build on any file that is neither or both. Step 5 promises this region carries
# "every mechanical finding, complete, from every detector"; before that binding existed the
# promise was prose and six shipped classifiers sat outside it, so `--verify` could not fail on
# an omission it could not see.
#
# Usage:
#   emit-report.sh <dist> <base> <consumer> <theirs>                 # print the mechanical region
#   emit-report.sh --verify <report.md> <dist> <base> <consumer> <theirs>
# Exit:
#   print  : 0 always.
#   verify : 0 = region present and current; 1 = missing / stale / hand-edited, or the fresh
#            render carries `DETECTOR-REFUSED  preclassify.sh` (cause PRECLASSIFY-REFUSED, decided
#            before the byte-compare, so a report carrying the same line fails too); 2 = usage;
#            3 = stale in the SAFE direction only: the refs are unchanged and the approved region
#                lists HARD-* row(s) the detectors no longer render, and none they newly do — the
#                blockers were RESOLVED after the render (the adjudication loop's own work). Still a
#                refusal; apply.sh names the cause and the remedy is a re-render and re-approval.
set -uo pipefail

MODE=print
REPORT=""
if [ "${1:-}" = "--verify" ]; then
  MODE=verify
  REPORT="${2:?usage: emit-report.sh --verify <report.md> <dist> <base> <consumer> <theirs>}"
  shift 2
fi
DIST="${1:?usage: emit-report.sh [--verify <report>] <dist> <base> <consumer> <theirs>}"
BASE="${2:?}"
CONSUMER="${3:?}"
THEIRS="${4:?}"

SELF="$(cd "$(dirname "$0")" && pwd)"
# The shared library is deliberately NOT dot-sourced here: this file calls none of its
# functions directly, only sets up the shared cache directory below and hands it to the
# sub-detector PROCESSES it execs, several of which load that library themselves. Loading
# it here too would add a second, unused emission of the exact source-line shape I105 keys
# on to decide "invoked" -- and that library's own header carries an exemption marker, so a
# second invocation site would read as one file that is both invoked and exempt, one of the
# two stale. (Spelled around the literal dotted-source form on purpose, for the same reason.)

# --- THE SHARED CROSS-PROCESS MEMO, OWNED HERE FOR THE WHOLE RENDER --------------------------
#
# batch 121: a single `render()` call below makes exactly 4 distinct git calls itself, and shells
# out to roughly a dozen INDEPENDENT reconcile/*.sh sub-detector SCRIPTS (preclassify.sh,
# hard-blockers.sh -> layer-drift.sh + unregistered-drift.sh, retired-tokens.sh once per CLASSIFY
# file, relabel-extension-checks.sh, ledger-reverify.sh, predicate-differential.sh,
# retired-fixtures.sh, the three retired-layer-*.sh, warn-shadowed-local-validators.sh) — each its
# own bash process, each re-reading the SAME `git ls-tree -r --name-only` and `git show` answers
# (a ref-scoped path) every sibling in this same render already read. Measured on the
# fixture's own 143-render matrix (13 programs x 11 worlds): 19219 total git invocations, 302
# distinct. An in-process memo (the shape `ledger-reverify.sh` carried before this) cannot see
# that repetition, because it never crosses the process boundary a `bash "$SELF/x.sh"` opens.
#
# ONE `mktemp -d` PER emit-report.sh INVOCATION, EXPORTED, so every child this process forks
# shares it — `lib.sh`'s `ai_dlc_memo_dir()` and `ledger-reverify.sh`'s own `blob_memo()` both
# prefer `AI_DLC_RECONCILE_MEMO` over building a private directory. SHARING IS OPT-IN ON THE
# ENVIRONMENT, not a fixed path: an operator invoking any one sub-detector standalone, or
# apply.sh, exports nothing and gets exactly the private-directory behavior each script already
# had. Two concurrent renders (the fixture's own 12-wide fixture pool, or two operators pulling
# at once) each make their OWN `mktemp -d` here and never share a directory, so they cannot
# collide — the exact hazard CLAUDE.md's cleanup-glob incident warns about.
#
# CLEANED BY THIS PROCESS'S OWN EXIT TRAP, and only if THIS process created it
# (`AI_DLC_MEMO_OWNED`, not `AI_DLC_MEMO_DIR`) — the same non-negotiable rule
# `core_map_cleanup` states for `ledger-reverify.sh`'s own temporaries: `rm -rf` must never act on
# a directory this process merely borrowed from a caller who intends to clean it up itself.
export AI_DLC_RECONCILE_MEMO
if [ -z "${AI_DLC_RECONCILE_MEMO:-}" ]; then
  AI_DLC_RECONCILE_MEMO="$(mktemp -d "${TMPDIR:-/tmp}/reconcile-memo.XXXXXX" 2>/dev/null || true)"
  if [ -n "$AI_DLC_RECONCILE_MEMO" ]; then
    _er_memo_owned="$AI_DLC_RECONCILE_MEMO"
  fi
fi
# THE DIFF STAGING DIRECTORY, ONE PER PROCESS, MADE HERE IN THE MAIN SHELL. Every verdict-bearing
# `diff` below reads a staged file, never a `<( )` process substitution: under concurrent
# bash 3.2 workers `diff <(printf …) file` exits 2 with `/dev/fd/63: Bad file descriptor` --
# measured at batch 160 at 3 and 8 in 2000 under 4 workers, against 0 in 2000 for the temp-file
# spelling in the same loop -- and that race was BL-230's pool trigger. Made here and not at the
# site because the orientation loop is a pipeline subshell, where an EXIT handler cannot clean up
# after itself. Empty when `mktemp -d` failed, and every site then REFUSES rather than diffing.
_er_tmp="$(mktemp -d "${TMPDIR:-/tmp}/emit-report.XXXXXX" 2>/dev/null)" || _er_tmp=""
trap '[ -n "${_er_memo_owned:-}" ] && rm -rf "$_er_memo_owned"; [ -n "${_er_tmp:-}" ] && rm -rf "$_er_tmp"; :' EXIT
# er_pdiff <staged-file> <other> — `diff - <other>` with the staged file PIPED in, never passed as a
# path: Apple diff hunks two REGULAR files differently from a pipe and a file (measured on a graph
# pull, 294 lines against 293, different hunk anchors), so a two-path diff would move every
# approved region, while the piped form is byte-identical to the old `<( )` output. Returns diff's
# own status (0 same, 1 differ, >=2 could not compare) and 2 when the `cat` failed, never 0 for a
# diff of nothing. A FUNCTION, not inline: a `case` inside `$( )` does not parse under bash 3.2.
er_pdiff() {
  cat "$1" | diff - "$2"
  local _c="${PIPESTATUS[0]}" _d="${PIPESTATUS[1]}"
  [ "$_c" -eq 0 ] || return 2
  return "$_d"
}
# NO HERE-STRING FEEDS A DECISION IN THIS FILE (BL-360). bash 3.2 stages every `<<<` to a temp file,
# and when that write fails -- `ulimit -f`, a full TMPDIR -- it runs the command on EMPTY stdin at
# the command's own exit: an awk sample read a real diff as `ONLY IN …: none`, the retired-token
# projection rendered `RETIRED-CONTRACT-TOKEN: none`, and `--verify` never saw preclassify's
# refusal and passed a region nobody classified. Each site now reads a file this helper wrote,
# with the write's status read and a named refusal on failure.
#
# er_stage <name> <value> -- writes the bytes a here-string would feed (`printf '%s\n'`) to
# $_er_tmp/<name> and returns the write's status; 125 when there is no staging directory. The
# builtin `printf` writes into a PIPE, never into the file, for apply.sh's `ap_stage` reason: a
# failed builtin write to a file leaves its unflushed bytes in this shell's stdout buffer, and in
# print mode the next stdout write is the REGION (measured on bash 3.2.57 under `ulimit -f 1`: a
# 2000-byte value, 1024 bytes landed, the other 977 came out ahead of the next echo). `cat`, a
# child, takes the write error, and `pipefail` (set above) hands its status back. There is no
# "first failure ends staging" flag as in `ap_stage`: the orientation loop is a pipeline subshell,
# so a flag set there dies with the iteration -- every site refuses on its own write instead.
er_stage() {
  [ -n "$_er_tmp" ] || return 125
  printf '%s\n' "$2" | cat > "$_er_tmp/$1"
}

sub() { printf '\n**%s**\n' "$1"; }
none_or() { if [ -n "$1" ]; then printf '%s\n' "$1"; else echo "none"; fi; }

render() {
  echo "<!-- BEGIN GENERATED: reconcile-mechanical — rendered by reconcile/emit-report.sh; do not hand-edit -->"
  # SINGLE-quoted: a backslash before a backtick is NOT an escape here, it is a literal
  # backslash, and this region is specified to be pasted VERBATIM into a markdown report —
  # where `\`` renders as an escaped backtick, so the one line naming the two shas showed
  # them wrapped in literal backslashes instead of as inline code. `--verify` byte-matches
  # the region against a fresh render, so a consumer who wrote correct markdown got a FAIL
  # and was pushed back to the malformed text.
  printf '\n_base_ `%s` → _theirs_ `%s`.\n' "$BASE" "$THEIRS"
  # THE BASE IS TAKEN ON FAITH WHILE THE TREE RECORDS THE ANSWER. `THEIRS` is rev-parsed and
  # refused if it does not resolve; `BASE` is `${2:?}` and validated nowhere, against a stamp whose
  # `commit:` field is exactly "the ref this tree was last reconciled to". Nothing in this pipeline
  # compares the two -- the stamp is read in four scripts and every one of them reads
  # `skill_commit`, never `commit`, except the post-write read-back in `apply.sh`.
  #
  # THE TRAP IS THAT THE STAMP CARRIES TWO SHA-SHAPED FIELDS AND BOTH LOOK LIKE PLAUSIBLE BASES.
  # Measured on the reference consumer, three times in one session: a cycle run with the PREVIOUS
  # `commit:` -- correct one pull earlier -- inflated the range from 1 path and 0 fixtures to 10 and
  # 5. `self-update-fixtures.sh` then refused, correctly, naming omitted fixtures; and the first
  # response was to WIDEN the input until the refusal went away rather than ask why the diff had
  # grown. A refusal computed from a bad input is not a verdict on the thing it names.
  #
  # A ROW, NOT A REFUSAL, and the asymmetry is the reason. Re-reconciling from an older base is
  # legitimate -- a deliberate re-run, a split pull, a recovery -- so denying it would wedge real
  # work. But silence here is indistinguishable from agreement, which is the failure this release
  # band has now fixed twice in other places, so a disagreement SAYS SO in the artifact the operator
  # approves from. An absent or unreadable stamp renders nothing rather than inventing a finding:
  # a consumer that has never been reconciled has no recorded base to disagree with.
  _rendered_stamp="$CONSUMER/.claude/.ai-dlc-version"
  if [ -f "$_rendered_stamp" ]; then
    _rendered_base="$(sed -n 's/^commit:[[:space:]]*\([^[:space:]]*\).*/\1/p' "$_rendered_stamp" | head -1)"
    if [ -n "$_rendered_base" ] && [ "$_rendered_base" != "$BASE" ]; then
      printf '_stamp_ records `commit: %s`, which is NOT the base above — re-derive the base before trusting this range.\n' "$_rendered_base"
    fi
  fi
  # THE REF'S SPELLING IS NOT THE REF, and this region is the only thing standing between a
  # moved upstream and a write. The line above renders what the caller TYPED. `--verify`
  # byte-compares the region, so a SYMBOLIC theirs -- `origin/main`, a branch, whatever a bare
  # invocation resolves "upstream HEAD" to -- renders identically at the dry run and at the
  # apply even when it has moved between them. Every other row here is a bucket or a status
  # keyed on STATUS+path and carries no content digest, so a core file whose bucket is
  # unchanged and whose CONTENT moved leaves the whole region byte-identical.
  #
  # Measured, driving this script against a consumer built by install.sh, with two refs two
  # core files apart: the ONLY differing line was the one above. Spelled as a branch that was
  # moved between render and verify, `--verify` exited 0 and printed "present, current, and
  # complete" -- SKILL.md's mechanical union gate authorising a write of content the operator
  # never saw, with apply.sh's re-stamp then attesting to it from a sha it resolves for itself
  # at apply time. A hand-edit of one byte still failed, so the gate discriminates; it was
  # simply never shown the thing that changed.
  #
  # KEYED ON THE `core/` TREE, NOT ON THE COMMIT, and that is the whole of the false-positive
  # story. The distribution commits docs and plans between releases, and a consumer whose
  # upstream gained one of those between its dry run and its apply must NOT be pushed back to
  # re-emit a sound report. The live incident that surfaced this was exactly that shape: the
  # ref moved by one docs-only commit and the `core` tree was unchanged. A commit-keyed line
  # fires on it and wedges the pull; a tree-keyed line stays quiet. This fires when, and only
  # when, the bytes this pull would WRITE have changed -- which is precisely the condition
  # that invalidates the operator's approval, so the false-positive set is empty by
  # construction rather than by narrowing.
  # A FAILED RESOLUTION MUST NOT RENDER AS A SHARED CONSTANT. Two different unresolvable refs that
  # both print `absent` are EQUAL to each other, so a report generated with a typo verifies clean
  # against the same typo. Naming the ref makes the failure distinguishable.
  printf '_theirs_ `core/` tree `%s`.\n' "$(git -C "$DIST" rev-parse "${THEIRS}:core" 2>/dev/null || echo "unresolvable:${THEIRS}")"
  # AND `VERSION`, WHICH IS NOT UNDER `core/` AND REACHES CONSUMER STATE ANYWAY.
  #
  # The `core/` tree above acquits every upstream move that changes no file under `core/`, and that
  # acquittal is the point -- a docs commit between releases must not wedge a pull. But it is one
  # field too wide. `write_stamp()` reads `${THEIRS}:VERSION` from the REPOSITORY ROOT and writes it
  # into the stamp's `version:` field, and under a carried machinery slice into `skill_version:`
  # too. So a move across a commit that bumps `VERSION` and touches nothing in `core/` changes what
  # the stamp CLAIMS while the tree hash above reports no change at all, and the stamp writer's own
  # comment says an overstating version silently mis-bases the next pull's merge.
  #
  # Measured over the last 400 commits on the distribution's default branch: 236 touch no `core/`
  # file and are acquitted here, 16 of those ALSO change `VERSION`, against a control of 164 that do
  # touch `core/`. Rendering `VERSION` beside the tree leaves 220 of the 236 still acquitted -- the
  # docs-only move still passes -- and covers the 16 that move a value the operator approved.
  _theirs_version="$(git -C "$DIST" show "${THEIRS}:VERSION" 2>/dev/null | tr -d '[:space:]')"
  printf '_theirs_ `VERSION` `%s`.\n' "${_theirs_version:-unresolvable:${THEIRS}}"

  local pc ud ld hb rl del classify pc_rc pc_refused="" pc_rng pc_rng_rc
  # A PRECLASSIFY THAT DID NOT CLASSIFY RENDERED AS `none` IN FIVE SECTIONS. This was
  # `2>/dev/null || true`: the rc was discarded, so a run that exited 2 (preclassify refuses on a
  # failed git call) or one that printed nothing over a range that moves `core/` rendered the same
  # empty buckets, empty worklist and empty deletions as a pull with nothing to do -- every pool
  # red of reconcile-emit-report in batch 151 was a render arm, which is this shape under load.
  #
  # TWO REFUSALS, THE SAME RULE `apply.sh --finish` AND `unregistered-drift.sh`'s carried-bucket
  # arm already apply: a non-zero exit, and an EMPTY row set while `base..theirs` changes `core/`.
  # A range that cannot be read is not evidence of an empty one, so it refuses too. On either,
  # `pc` is emptied -- a failed run may have printed a partial row set before it stopped, and no
  # reader below may consume it -- and every `pc`-derived section renders the refusal line.
  pc="$(bash "$SELF/preclassify.sh" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" 2>/dev/null)"
  pc_rc=$?
  if [ "$pc_rc" -ne 0 ]; then
    pc_refused="exited ${pc_rc} without classifying"
  elif [ -z "$pc" ]; then
    pc_rng="$(git -C "$DIST" -c core.quotePath=false diff --name-only "$BASE" "$THEIRS" -- core/ 2>/dev/null)"
    pc_rng_rc=$?
    if [ "$pc_rng_rc" -ne 0 ]; then
      pc_refused="returned no rows and whether \`${BASE}..${THEIRS}\` changes \`core/\` could not be read (git diff exited ${pc_rng_rc})"
    elif [ -n "$pc_rng" ]; then
      pc_refused="returned no rows while \`${BASE}..${THEIRS}\` changes \`core/\`"
    fi
  fi
  [ -n "$pc_refused" ] && pc=""
  # The ONE line every pc-derived section prints on a refusal. `--verify` keys on its
  # `DETECTOR-REFUSED  preclassify.sh (exited|returned)` prefix, which the `--templates` refusal
  # below does not share.
  pc_refusal() {
    echo "DETECTOR-REFUSED  preclassify.sh ${pc_refused}, so this section is NOT a finding of 'none'. Run it directly against this consumer to see why: reconcile/preclassify.sh <dist> <base> <theirs> <consumer>"
  }

  sub "Per-file buckets (STATUS  path):"
  if [ -n "$pc_refused" ]; then pc_refusal; else
    none_or "$(printf '%s\n' "$pc" | awk -F'\t' 'NF>=4 && $2!="" {print $4"  "$2}' | sort -u)"
  fi

  sub "Semantic worklist — files needing a 3-way merge (the LLM fills their result in the slot below, one per file):"
  classify="$(printf '%s\n' "$pc" | awk -F'\t' 'NF>=4 && $4 ~ /CLASSIFY/ {print $2}' | sort -u)"
  if [ -n "$pc_refused" ]; then pc_refusal; else none_or "$classify"; fi

  # ---- Orientation: which side actually holds what -------------------------
  # A CLASSIFY file's resolution is prose the LLM writes, and prose is where OURS and THEIRS
  # get swapped. Observed live on the 0.106.1 -> 0.113.1 pull: the report's comparison table
  # for a BOTH-ADDED template assigned each side the OTHER's content, and the recommended
  # action was written from the inverted table -- it would have filed the consumer's override
  # carrying UPSTREAM's rows (an override restating core, which layer-drift.sh flags) while
  # dropping the two domain classes that were the consumer's actual reason for the file.
  #
  # Nothing could catch it. The generated region named the file and its bucket correctly; the
  # claim about CONTENT lived in free prose that no detector compares to the files. That is the
  # same shape this region already exists to close one layer up (a narrated report silently
  # dropping a mechanical finding), so it gets the same treatment: render the orientation
  # facts HERE, inside the region --verify byte-compares, and have the prose derive from them.
  #
  # Deliberately NOT the full diff: these run 24-190 changed lines each on a real pull, and a
  # region nobody reads is a region nobody checks. What is emitted is the part that was gotten
  # wrong -- which side holds which lines -- capped, with the suppressed count STATED so a
  # truncated sample can never read as a complete one.
  if [ -n "$classify" ]; then
    # `--bucket-rows` HANDS DOWN THE ROWS THIS RENDER ALREADY PAID FOR, exactly as the
    # `unregistered-drift.sh` call below has since that flag existed. `retired-tokens.sh`
    # re-derived them by running `preclassify.sh "$DIST" "$BASE" "$THEIRS" "$CONSUMER"` itself —
    # byte-for-byte the call at the top of this function — ONCE PER CLASSIFY FILE. Measured on
    # the fixture's own render matrix: 594 preclassify invocations, of which 198 were this
    # re-derivation; handing the rows down leaves 396.
    #
    # WRITTEN OUTSIDE THE LOOP because the loop below is the right-hand side of a PIPELINE and
    # therefore a subshell: a temp file created inside it is created once per row and cannot be
    # cleaned by the caller.
    #
    # THE FLAG IS PASSED ONLY WHEN THE WRITE SUCCEEDED, never with an empty file standing in for
    # a real derivation. `retired-tokens.sh` falls back to deriving when the handed-down file is
    # empty — an empty set and a failed derivation are the same stdout, and its own refusal goes
    # to stderr, which this call discards. `retired-contract-token/run.sh` asserts both halves.
    local rt_pc=""
    rt_pc="$(mktemp 2>/dev/null)" || rt_pc=""
    # Through a pipe, for `er_stage`'s reason: a failed builtin write into the file would carry its
    # unflushed bytes into the region on the next stdout write.
    if [ -n "$rt_pc" ]; then
      printf '%s\n' "$pc" | cat > "$rt_pc" 2>/dev/null || { rm -f "$rt_pc"; rt_pc=""; }
    fi
    sub "Semantic worklist orientation — OURS = consumer, THEIRS = upstream at theirs. Every ours/theirs claim in the resolution prose MUST be derived from this block, never from recall:"
    printf '%s\n' "$pc" | awk -F'\t' 'NF>=4 && $4 ~ /CLASSIFY/ {print $2"\t"$3}' | sort -u \
    | while IFS="$(printf '\t')" read -r cp cons; do
        [ -n "${cp:-}" ] || continue
        local_ours="$CONSUMER/$cons"
        echo
        echo "  $cp"
        # `diff THEIRS OURS`: '<' lines are THEIRS, '>' lines are OURS. Stated because getting
        # this backwards is precisely the defect, and the fixture asserts the direction.
        #
        # A SAMPLE THAT DID NOT RUN RENDERED AS `ONLY IN …: none`, AND THAT IS BL-230's POOL FLAKE.
        # Every command in this block ended in `|| true` or `2>/dev/null` with its status unread:
        # `diff` exit 2 (it could not compare) was swallowed with exit 1 (it did), the
        # grep|sed|grep chain that cut the sample swallowed its own failures, `grep -c` turned an
        # empty count into `${n:-0}` = 0, and a FAILED `git show` rendered `THEIRS absent`.
        # Measured at batch 160: a 156-run pool put 1 red on the fixture at tip, mutant E3 on world
        # V-N scoring `3|BLOCKERS-RESOLVED|1|1|4|4`. Driven in a scratch copy, a PATH shim making
        # `diff` exit 2 with no output -- or making the first grep of the chain fail -- at APPROVE
        # time rendered `ONLY IN THEIRS: none` / `ONLY IN OURS: none` and exit 0, and scoring that
        # approval under E3 reproduced tip.32 byte-for-byte, same four `unseen:` rows and same
        # hunk. The approval had recorded a sample that never ran as an empty one.
        #
        # SO EVERY STEP'S STATUS IS READ, and a failed one renders ONE refusal line for THIS FILE
        # ONLY -- the other CLASSIFY files keep their own samples, because one fork refused under
        # load says nothing about the next. The same class `unregistered-drift.sh`'s
        # `is_unregistered()` closed at 0.625.0, one detector over.
        #
        # EVERY REFUSAL LINE IS AT COLUMN 0, never indented to match the block. `--verify` keys
        # `refused_new` and `unseen_rows()` on `^DETECTOR-REFUSED`; an indented refusal is scored as
        # an unseen FINDING row instead, and a verify of a resolved-blocker report under the same
        # failure then reads BLOCKERS-RESOLVED where it must read UNDECIDED.
        #
        # ABSENCE IS DECIDED BY `ls-tree`, NOT BY `git show` FAILING. `git show` exits 128 for a path
        # absent at theirs AND for a read that failed, and so does `cat-file -e`; `ls-tree` exits 0
        # with no row for the first and non-zero only for the second. An empty `t` from a SUCCESSFUL
        # show (an empty file) keeps its old rendering, so no healthy region moves.
        t=""; t_rc=0
        t_ls="$(git -C "$DIST" -c core.quotePath=false ls-tree "$THEIRS" -- "$cp" 2>/dev/null)"; t_ls_rc=$?
        if [ "$t_ls_rc" -eq 0 ] && [ -n "$t_ls" ]; then
          t="$(git -C "$DIST" show "${THEIRS}:${cp}" 2>/dev/null)"; t_rc=$?
        fi
        if [ "$t_ls_rc" -ne 0 ] || [ "$t_rc" -ne 0 ]; then
          echo "DETECTOR-REFUSED  orientation read of ${cp} at ${THEIRS} failed (ls-tree exited ${t_ls_rc}, show exited ${t_rc}), so THEIRS is NOT absent and this file's sample is NOT a finding of 'none'."
        elif [ -z "$t" ]; then
          echo "    THEIRS absent at ${THEIRS} — nothing upstream to compare"
        elif [ ! -f "$local_ours" ]; then
          echo "    OURS absent at ${cons} — nothing consumer-side to compare"
        else
          echo "    OURS   $cons ($(wc -l < "$local_ours" | tr -d ' ') lines)"
          echo "    THEIRS ${THEIRS}:${cp} ($(printf '%s\n' "$t" | wc -l | tr -d ' ') lines)"
          # diff's OWN contract: 0 = same, 1 = differ, >=2 = could not compare. Only the last is a
          # refusal; the rc is read off the bare command substitution, never after a `|| true`.
          # THEIRS is STAGED in a file, not fed through `<( )`: the fd race (3-8 in 2000 under 4
          # bash 3.2 workers, 0 staged) is what made this exit 2 in the pool. A staging that failed
          # is the refusal diff would have given, never an empty diff.
          # Piped through `er_pdiff`, whose header says why a two-path diff would move the region.
          d=""; d_rc=0
          if ! er_stage orient.theirs "$t" 2>/dev/null; then
            d_rc=staging-failed
          else
            d="$(er_pdiff "$_er_tmp/orient.theirs" "$local_ours" 2>/dev/null)"; d_rc=$?
          fi
          if [ "$d_rc" = staging-failed ] || [ "$d_rc" -ge 2 ]; then
            echo "DETECTOR-REFUSED  orientation diff exited ${d_rc} for ${cp}, so its ONLY IN sample is NOT a finding of 'none'."
          else
          for side in THEIRS OURS; do
            case "$side" in
              THEIRS) marker='<' ;;
              OURS)   marker='>' ;;
            esac
            # ONE awk replaces grep|sed|grep and the `grep -c` beside it, because awk exits 0 on
            # no match: a non-zero exit is a failure and nothing else, where grep's 1 was both "no
            # line" and indistinguishable from a chain that died. It prints the COUNT on its first
            # line and the sample after it, so the count is read off the same run as the lines and
            # a count that is not a number refuses rather than defaulting to 0. Same filter as the
            # chain it replaces: lines opening `< ` / `> `, marker stripped, whitespace-only dropped.
            # The diff is STAGED once per side and the awk reads the file (BL-360, `er_stage`): a
            # failed staging write is the refusal below, named `staging-<rc>`, never an empty diff.
            samp=""; samp_rc=0
            er_stage orient.diff "$d" 2>/dev/null || samp_rc="staging-$?"
            if [ "$samp_rc" = 0 ]; then
            samp="$(awk -v m="$marker" '
              substr($0, 1, 2) == m " " { x = substr($0, 3); if (x ~ /[^[:space:]]/) { c++; s = s x "\n" } }
              END { printf "%d\n%s", c, s }' "$_er_tmp/orient.diff")"; samp_rc=$?
            fi
            # `$nl`, not `$'\n'` inside the double-quoted expansion: bash 3.2 does not expand
            # ANSI-C quoting there, and the pattern would match a literal `$'\n'`.
            nl='
'
            n="${samp%%${nl}*}"
            case "$samp_rc:$n" in
              # non-zero rc, an empty count, or a count carrying a non-digit
              [!0]*|0:|0:*[!0-9]*)
                echo "DETECTOR-REFUSED  orientation sample exited ${samp_rc} for ${cp} (${side}), so it is NOT a finding of 'none'."
                continue ;;
            esac
            lines=""
            case "$samp" in *"$nl"*) lines="${samp#*${nl}}" ;; esac
            # CAP=12, not 6. At 6 the sample was all boilerplate: on the pull that motivated
            # this block, both sides' first rows were table headers and the same four generic
            # class names, while the lines that actually decided the resolution -- the
            # consumer's two domain classes, upstream's two process classes -- sat in the
            # suppressed tail. A sample that shows only what the two sides have in COMMON
            # orients nobody. 12 covers that case whole; anything larger is read by command.
            if [ "$n" -eq 0 ]; then
              echo "    ONLY IN ${side}: none"
            else
              shown=12
              [ "$n" -lt "$shown" ] && shown="$n"
              if [ "$n" -gt 12 ]; then
                echo "    ONLY IN ${side} (${shown} of ${n} shown, $((n - shown)) suppressed — read the rest with the command below):"
              else
                echo "    ONLY IN ${side} (${n}, complete):"
              fi
              printf '%s\n' "$lines" | head -12 | cut -c1-100 | sed 's/^/      /'
            fi
          done
          fi
          # The escape hatch, printed for EVERY file so a truncated sample is never the only
          # thing available. Same argument order as above: theirs on the left, ours on the
          # right, so '<' stays THEIRS and '>' stays OURS in the operator's own terminal too.
          echo "      full: diff <(git -C $DIST show ${THEIRS}:${cp}) $CONSUMER/$cons   # '<' THEIRS, '>' OURS"

          # ---- RETIRED CONTRACT TOKENS -----------------------------------------
          # The one class of merge defect the sample above CANNOT surface: upstream
          # retires a shared contract and the consumer's own code inside the same file
          # still speaks the old one. diff3 merges it cleanly and the result is a gate
          # that cannot fire. retired-tokens.sh owns the derivation and the rationale;
          # this only renders it. UNCAPPED on purpose -- the signal was already inside
          # "ONLY IN OURS" above on the pull that motivated it, buried at "137
          # suppressed", and the cap is what hid it.
          #
          # ITS rc IS READ OFF THE BARE RUN. The header says "0 always", so a non-zero exit is a
          # crash, and before this it rendered `RETIRED-CONTRACT-TOKEN: none` -- the BL-230 class
          # (batch 160: a detector that did not run rendered as one that found nothing). The bare
          # run's stdout is captured whole and projected afterwards, so `$?` is the detector's and
          # not the projection's. Its refusal is no longer exit-0-with-stderr: a run that scanned
          # nothing (no CLASSIFY rows, a ref that did not resolve) now exits 2, so it reaches the
          # DETECTOR-REFUSED line below like any other non-zero status.
          if [ -n "$rt_pc" ]; then
            rt="$(bash "$SELF/retired-tokens.sh" --bucket-rows "$rt_pc" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" "$cp" 2>/dev/null)"
            rt_rc=$?
          else
            rt="$(bash "$SELF/retired-tokens.sh" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" "$cp" 2>/dev/null)"
            rt_rc=$?
          fi
          # The projection reads a STAGED copy of the rows (BL-360, `er_stage`); a failed write is
          # `staging-<rc>`, which the refusal below renders, never an empty token list.
          if [ "$rt_rc" -eq 0 ]; then
            if er_stage orient.rt "$rt" 2>/dev/null; then
              rt="$(awk -F'\t' '{print $3}' "$_er_tmp/orient.rt")" || rt_rc="projection-$?"
            else
              rt_rc="staging-$?"
            fi
          fi
          if [ "$rt_rc" != 0 ]; then
            echo "DETECTOR-REFUSED  retired-tokens.sh exited ${rt_rc} for ${cp} without scanning, so its RETIRED-CONTRACT-TOKEN line is NOT a finding of 'none'. Run it directly: reconcile/retired-tokens.sh <dist> <base> <theirs> <consumer> ${cp}"
          elif [ -n "$rt" ]; then
            echo "    RETIRED-CONTRACT-TOKEN — OURS still references what THEIRS eliminated (uncapped; resolve EVERY one):"
            printf '%s\n' "$rt" | sed 's/^/      /'
            echo "      Each is a live reference in the consumer's own code to a contract upstream"
            echo "      retired. The merge will carry it and stay syntactically valid. Find what"
            echo "      THEIRS replaced it with and re-point OURS at that, or state why it is safe."
          else
            echo "    RETIRED-CONTRACT-TOKEN: none"
          fi
        fi
      done
    [ -n "$rt_pc" ] && rm -f "$rt_pc"
  elif [ -n "$pc_refused" ]; then
    # The orientation block renders only when there is a worklist, so on a refusal it would simply
    # be ABSENT -- which is also what a pull with no CLASSIFY file looks like. It says why instead.
    sub "Semantic worklist orientation — OURS = consumer, THEIRS = upstream at theirs. Every ours/theirs claim in the resolution prose MUST be derived from this block, never from recall:"
    pc_refusal
  fi

  sub "Deletions (apply would git rm a consumer file — gated per-path):"
  del="$(printf '%s\n' "$pc" | awk -F'\t' '$4=="UPSTREAM-DELETED" || $4 ~ /^ORPHANED-RELOCATED/ {print $4"  "$2}' | sort -u)"
  if [ -n "$pc_refused" ]; then pc_refusal; else none_or "$del"; fi

  # STEP 3b WAS THE FOURTH MANDATED DETECTOR OUTSIDE THIS REGION, AND THE ONLY ONE THE SKILL TOLD
  # THE LLM TO RUN ITSELF. `preclassify.sh --templates` classifies the generated files that live
  # OUTSIDE `core/` — the consumer's CLAUDE.md, docs/coding-conventions.md, QUICKSTART.md and
  # .claude/settings.json — and its rows were narrated under a "Template-changes list" heading the
  # author wrote by hand. On the reference consumer's report that section was one sentence. A
  # narrated finding is one the narrator can drop, which is the whole reason this region exists,
  # and `--verify` could not fail on the omission because the rows were never in the region to
  # omit. `TEMPLATE-PROSE-MERGE` and `TEMPLATE-JSON-MERGE` both carry step-7 actions that rewrite
  # a live consumer file, so a dropped row is an unperformed merge nobody can see afterwards.
  #
  # SITED AFTER "Deletions" DELIBERATELY. `core/fixtures/reconcile-emit-report/run.sh` extracts
  # the orientation block with `awk '/Semantic worklist orientation/,/^\*\*Deletions/'` — a range
  # over section ORDER, not over content. A section inserted inside that range silently widens
  # what four of that fixture's arms read while every one of them stays green.
  #
  # PRECLASSIFY'S ARGUMENT ORDER, NOT THIS DRIVER'S. It takes <dist> <base> <theirs> <consumer>;
  # emit-report's own positional args are <dist> <base> <consumer> <theirs>. Transposed, the
  # classifier refuses at its `consumer-root not a directory` guard with a sha as the path — which
  # the refusal arm below renders as REFUSED rather than as `none`.
  #
  # AND THE rc IS READ, for the reason the four sites below it state: this classifier exits 2 when
  # it could not classify (an unreadable or empty template manifest), and a refusal rendered as
  # `none` is the same defect one level down. The read is the detector's status only under this
  # file's `set -o pipefail`, exactly as at the `retired-layer-token.sh` site.
  sub "Template pre-classification (generated files outside core/ — step 3b; BUCKET  consumer-path  <- template):"
  local tpl tpl_rc
  tpl="$(bash "$SELF/preclassify.sh" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" --templates 2>/dev/null | awk -F'\t' 'NF>=4 && $1=="T" {print $4"  "$3"  <- "$2}' | sort -u)"
  tpl_rc=$?
  if [ "$tpl_rc" -eq 0 ]; then none_or "$tpl"; else
    echo "DETECTOR-REFUSED  preclassify.sh --templates exited ${tpl_rc} without classifying, so this section is NOT a finding of 'none'. Run it directly: reconcile/preclassify.sh <dist> <base> <theirs> <consumer> --templates"
  fi

  # Rendered mechanically, inside the --verify'd region, precisely because the failure
  # this closes was a narrated report asserting OURS==BASE for all 25 validators against
  # a comparison that never ran. A +consumer-edited row means apply will overwrite a
  # locally adapted enforcer on the move; the operator confirms it was filed as a push
  # candidate first. Author prose cannot drop what the byte-compare requires to be here.
  sub "Scripts relocation (scripts/ → scripts/ai-dlc/; +consumer-edited = a local adaptation apply will discard — confirm the push-candidate ledger before apply):"
  reloc="$(printf '%s\n' "$pc" | awk -F'\t' '$4 ~ /^RELOCATE-MOVE/ {print $4"  "$2}' | sort -u)"
  if [ -n "$pc_refused" ]; then pc_refusal; else none_or "$reloc"; fi

  # HOOK REGISTRATION — the half of a hook delivery that no driver performs.
  #
  # `apply.sh` writes `.claude/hooks/ai-dlc-<x>.sh` mechanically; `settings-merge.sh` wires it
  # up and NOTHING CALLS `settings-merge.sh` — its only two invocation sites are prose, in
  # SKILL.md. A skipped prose step therefore ships a hook that is on disk, looks installed, and
  # never fires, and there is no absence anywhere for anyone to notice. Rendering the join here
  # puts it inside the --verify'd region for the same reason every other detector is here: a
  # finding the narrator can drop is a finding that gets dropped.
  #
  # THIS IS A STATE CHECK, NOT A DELTA CHECK, which is what makes it worth a section. Every
  # other row above answers "what changed base->theirs"; a settings.json that has been stale
  # since an earlier pull produces no delta at all — preclassify buckets it
  # TEMPLATE-UNCHANGED-NOOP whenever the template itself did not move — so the already-broken
  # consumer is exactly the one the delta view cannot see. Measured on the reference consumer
  # while this was written: `ai-dlc-rules-floor.sh` present and unregistered since v0.350.0,
  # six releases, with the template untouched for most of them.
  #
  # RUN THEIRS' COPY, not the consumer's: the pull that first DELIVERS this validator must
  # already be able to report with it, and at step 5 nothing has been written to the consumer
  # yet. A temp copy is safe here only because the validator resolves everything it reads from
  # its `--root` argument and nothing from its own location — running a validator from /tmp is
  # otherwise how a missing sibling gets reported as a failed check.
  #
  # BUT THE VALIDATOR PRINTS ITS OWN PATH, AND THE TEMP PATH CHANGES EVERY RENDER. Its FIX block
  # ends `bash <self> --root <consumer>`, and `<self>` was this mktemp copy -- so with any ai-dlc
  # hook unregistered, two renders differed in that line, `--verify` failed on every render, and
  # the union gate could not pass on that consumer state at all. The line is rewritten to the
  # consumer's INSTALLED path, `scripts/ai-dlc/validate-hook-registration.sh`: stable across
  # renders, and the path the remedy is run from once this pull is applied. The validator derives
  # `<self>` as `cd dirname && pwd` of the copy, which need not equal `$hrv` byte for byte (a
  # TMPDIR symlink or trailing slash), so the rewrite keys on the copy's BASENAME at the end of
  # the `bash` word, never on `$hrv`.
  sub "Hook registration (every shipped ai-dlc hook is wired in .claude/settings.json — a present-but-unregistered hook never fires):"
  local hrv hro
  hrv="$(mktemp)"
  if git -C "$DIST" show "$THEIRS:core/scripts/validate-hook-registration.sh" > "$hrv" 2>/dev/null && [ -s "$hrv" ]; then
    hro="$(bash "$hrv" --root "$CONSUMER" 2>&1)"
    # A rewrite that FAILED keeps the validator's own text: an unstable path line fails
    # `--verify` loudly, while an empty section would read as "nothing unregistered".
    local hrs
    hrs="$(printf '%s\n' "$hro" | HRB="${hrv##*/}" HRI="$CONSUMER/scripts/ai-dlc/validate-hook-registration.sh" \
      awk '{ i = index($0, "bash /"); if (i) { r = substr($0, i + 5); s = index(r, " "); w = s ? substr(r, 1, s - 1) : r
               n = length(ENVIRON["HRB"]); if (length(w) > n && substr(w, length(w) - n) == "/" ENVIRON["HRB"]) $0 = substr($0, 1, i + 4) ENVIRON["HRI"] (s ? substr(r, s) : "") }
             print }')" && [ -n "$hrs" ] && hro="$hrs"
  elif [ -x "$CONSUMER/scripts/ai-dlc/validate-hook-registration.sh" ]; then
    hro="$(bash "$CONSUMER/scripts/ai-dlc/validate-hook-registration.sh" --root "$CONSUMER" 2>&1)"
  else
    hro="  validator absent at ${THEIRS}:core/scripts/validate-hook-registration.sh and on the consumer — NOT CHECKED (this is not a pass)"
  fi
  rm -f "$hrv"
  printf '%s\n' "$hro" | grep -v '^hook-registration: root '

  # EACH DETECTOR RUNS ONCE PER RENDER, AND THE WRAPPER IS HANDED THE ROWS.
  #
  # This driver needs three OUTPUTS — the blocking list, and each detector's own section — and it
  # used to derive them from three PROCESSES: `hard-blockers.sh`, which runs both detectors, and
  # then the same two detectors again, directly. The refs cannot move within one invocation, so the
  # second run recomputed the first exactly. Measured on the reference consumer, both call sites
  # byte-identical (layer-drift.sh 50 rows, unregistered-drift.sh 85, degenerate-range control
  # proving the comparison could report DIFFER): layer-drift.sh 19-20s of a 60-64s render, and
  # `--verify` re-renders while `apply.sh` gates its writes on `--verify`, so a pull paid it three
  # times. Filed as PC-S308-EMIT-REPORT-RUNS-LAYER-DRIFT-AND-UNREGISTERED-DRIFT-TWICE.
  #
  # THE ROWS GO DOWN, THE BASE DOES NOT. `hard-blockers.sh` keeps the `HARD-` filter, the
  # `DRIFT-RANGE-DEGENERATE` qualifier and — the reason it exists — the per-detector base split
  # that `--post-apply` moves. This renderer runs strictly PRE-apply (see the header's note on the
  # wrapper's two forms), so the base it computes rows at is the base the wrapper would have used;
  # the wrapper REFUSES `--post-apply` with supplied rows rather than trusting that to stay true.
  #
  # A DETECTOR THAT DID NOT RUN RENDERS AS REFUSED, NOT AS `none`. Both classifiers exit 0
  # always when they classified and non-zero only when they could not (usage, an unsourceable
  # sibling, a consumer root that is not a directory). Inside a pipeline that rc was lost, so a
  # dead detector rendered the same `none` as a clean one — and, once --verify decides a
  # mismatch from HARD rows going ABSENT, a dead detector read as a blocker RESOLVED, by name.
  # The refused line is a row the approval never saw, so --verify treats it as it treats a new
  # HARD row: UNDECIDED, never BLOCKERS-RESOLVED. A detector that exits 0 having scanned nothing
  # is not visible here and is the detector's own honesty problem.
  #
  # THE rc IS CAPTURED OFF THE BARE RUN, NOT OFF A PIPELINE, and the rows are filtered afterwards.
  # The previous shape read `$?` after `cmd | awk | sort`, which under this file's `pipefail` is the
  # pipeline's status and not the detector's; it happened to agree because the readers exit 0, and
  # an agreement that holds by luck is the shape this region exists to end.
  # `--bucket-rows` HANDS DOWN THE PRECLASSIFY ROWS THIS RENDER ALREADY PAID FOR, and it is the
  # same shape `apply.sh` has passed since it grew the flag. `pc` above is
  # `preclassify.sh "$DIST" "$BASE" "$THEIRS" "$CONSUMER"` — byte-for-byte the argument order
  # `unregistered-drift.sh`'s carried-bucket arm re-derives when the flag is absent, which is why
  # handing it over changes who paid and never what is answered.
  #
  # THE FLAG IS PASSED ONLY WHEN THE TEMP FILE EXISTS, and never with an empty one standing in for
  # a real derivation. The scan's own guard refuses to read "no buckets" as "nothing diverged"
  # while the range still moves `core/`, so a failed write falls back to the HARD row rather than
  # acquitting — `apply-drift-after-write/run.sh:439` asserts exactly that, and its arm at :430
  # asserts the flagged and standalone runs agree row-for-row. Absent the temp file we pass no
  # flag at all, which is the pre-existing path and re-derives correctly.
  local ud_rc ld_rc ud_raw ld_raw ud_pc
  ld_raw="$(mktemp)"; ud_raw="$(mktemp)"
  bash "$SELF/layer-drift.sh"        "$DIST" "$BASE" "$THEIRS" "$CONSUMER" >"$ld_raw" 2>/dev/null
  ld_rc=$?
  ud_pc="$(mktemp 2>/dev/null)" || ud_pc=""
  # The write's status is READ (BL-360): a partial bucket file handed down as the flag would be
  # read as the whole classification. A failed write passes no flag, the re-deriving path above.
  if [ -n "$ud_pc" ] && ! printf '%s\n' "$pc" | cat > "$ud_pc" 2>/dev/null; then
    rm -f "$ud_pc"; ud_pc=""
  fi
  if [ -n "$ud_pc" ]; then
    bash "$SELF/unregistered-drift.sh" --bucket-rows "$ud_pc" \
         "$DIST" "$BASE" "$CONSUMER" "$THEIRS" >"$ud_raw" 2>/dev/null
    ud_rc=$?
    rm -f "$ud_pc"
  else
    bash "$SELF/unregistered-drift.sh" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" >"$ud_raw" 2>/dev/null
    ud_rc=$?
  fi

  sub "Blocking-layer (HARD-* — blocks apply):"
  # The wrapper gets the same REFUSED treatment as the two detectors it drives (below): print
  # mode exits 0 always, so a non-zero exit is a run that did not happen, and an empty blocking
  # list from one must not read as `0 HARD blockers.` — the one line the whole HARD- contract
  # keys on.
  local hb hb_rc
  hb="$(bash "$SELF/hard-blockers.sh" \
      --ld-rows "$ld_raw" --ld-rc "$ld_rc" \
      --ud-rows "$ud_raw" --ud-rc "$ud_rc" \
      "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null \
    | sed '/BEGIN GENERATED: hard-blockers/d;/END GENERATED: hard-blockers/d')"
  hb_rc=$?
  if [ "$hb_rc" -eq 0 ]; then printf '%s\n' "$hb"; else
    echo "DETECTOR-REFUSED  hard-blockers.sh exited ${hb_rc} without rendering the blocking list, so this section is NOT '0 HARD blockers.'. Run it directly against this consumer to see why: reconcile/hard-blockers.sh <dist> <base> <consumer> <theirs>"
  fi

  sub "Unregistered core drift (consumer in-place edits vs base):"
  ud="$(awk -F'\t' '$1!="CORE-OK"{print $1"  "$2}' "$ud_raw" | sort -u)"
  if [ "$ud_rc" -eq 0 ]; then none_or "$ud"; else
    echo "DETECTOR-REFUSED  unregistered-drift.sh exited ${ud_rc} without classifying, so this section is NOT a finding of 'none'. Run it directly against this consumer to see why: reconcile/unregistered-drift.sh <dist> <base> <consumer> <theirs>"
  fi

  sub "Layer drift (overrides/extensions vs new core):"
  ld="$(awk -F'\t' '$1!="EXTENSION-OK"{print $1"  "$2}' "$ld_raw" | sort -u)"
  if [ "$ld_rc" -eq 0 ]; then none_or "$ld"; else
    echo "DETECTOR-REFUSED  layer-drift.sh exited ${ld_rc} without classifying, so this section is NOT a finding of 'none'. Run it directly against this consumer to see why: reconcile/layer-drift.sh <dist> <base> <theirs> <consumer>"
  fi
  rm -f "$ld_raw" "$ud_raw"

  sub "Catalog relabel (extension check-number collisions, incl. NEW-THIS-PULL from theirs):"
  # `#{2,4}`, not a literal `### `: relabel matches headings at h2-h4, so filtering the
  # report to h3 dropped a real proposed relabel out of the operator-facing summary
  # while the tool itself reported it. The filter must be as wide as the tool.
  #
  # ITS rc IS READ OFF THE BARE RUN, AND ITS 1 IS A FINDING. This was `… | grep | sed | sort -u ||
  # true`, so a relabel run that died rendered `none` -- the same class BL-230 measured in the
  # orientation block at batch 160, where a forced exit 2 rendered an empty sample and scored a
  # resolved-blocker verify as BLOCKERS-RESOLVED. Its own header: 0 = nothing to do, 1 =
  # collisions found (dry-run with work outstanding), 2 = usage. So {0,1} ran and >=2 refused;
  # reading 1 as a refusal would hide exactly the rows this section exists to show. Captured into
  # a file for the reason the `ld`/`ud` runs above are: `$?` after a pipeline is the pipeline's.
  local rl rl_rc rl_raw
  rl_raw="$(mktemp)"
  bash "$SELF/relabel-extension-checks.sh" "$CONSUMER" --dist "$DIST" --theirs "$THEIRS" >"$rl_raw" 2>/dev/null
  rl_rc=$?
  # The FILTER is one awk, not grep|sed with `|| true`, for the orientation block's reason: awk
  # exits 0 on no match, so its non-zero status is a failure and is folded into the refusal.
  local rl_f_rc
  # `###?#? ` is `#{2,4} ` spelled without an interval expression, which not every awk honours.
  rl="$(awk '/^[[:space:]]+\+[[:space:]]+###?#? / { sub(/^[[:space:]]*\+[[:space:]]*/, "  "); print }' "$rl_raw" | sort -u)"
  rl_f_rc=$?
  rm -f "$rl_raw"
  [ "$rl_rc" -le 1 ] && [ "$rl_f_rc" -ne 0 ] && rl_rc="filter-${rl_f_rc}"
  if [ "$rl_rc" = 0 ] || [ "$rl_rc" = 1 ]; then none_or "$rl"; else
    echo "DETECTOR-REFUSED  relabel-extension-checks.sh exited ${rl_rc} without classifying, so this section is NOT a finding of 'none'. Run it directly against this consumer to see why: reconcile/relabel-extension-checks.sh <consumer> --dist <dist> --theirs <theirs>"
  fi

  # THE ROW MUST SAY WHY. This projected fields 1 and 2 and dropped field 3 — and field 3 is the
  # only place a NEEDS-REVIEW row names its cause (`unresolved:` / `vacuous predicate:` /
  # `unfalsifiable predicate:`). The report is the artifact the operator reads before approving
  # apply; a row there that says NEEDS-REVIEW and nothing else is a pointer to a tool they must
  # re-run to learn anything, which is how a rendered worklist becomes a table of contents.
  #
  # HAND-REVIEW is exempt: its detail is one constant sentence, so carrying it repeats the same
  # line once per manual entry — nine times on the reference consumer — and says nothing the
  # status has not already said.
  sub "Push-candidate ledger — CLOSE-CANDIDATE / NAMED-UPSTREAM / NAMED-UPSTREAM-DOCS-ONLY / NAMED-UPSTREAM-AMBIGUOUS / NEEDS-REVIEW / RECEIPTS-UNDECIDED / INPUT-UNRESOLVED (upstream absorbed the entry; the operator confirms and annotates, never auto-closed):"
  #
  # A LEDGER RUN THAT DIED RENDERED `none`, AND THAT ONE WAS DRIVEN. Batch 160, BL-230: a stub
  # `ledger-reverify.sh` exiting 2 turned the fixture's two NEEDS-REVIEW rows into `none`, render
  # rc 0, no DETECTOR-REFUSED anywhere -- while the `warn-shadowed` and `retired-layer-token`
  # sites under the same stub rendered their refusal. Its header says "Exit: 0 ALWAYS. A
  # classifier, not a gate", so any non-zero exit is a crash (it has `exit 1`/`exit 2` on an
  # unsourceable lib.sh or an unliftable close grammar). The rc is read off the BARE run into a
  # file, then filtered, for the `ld`/`ud` reason above; the same shape is used at every
  # "0 ALWAYS" site below. Its exit-0-with-stderr refusals are that detector's own contract and
  # are not decided here.
  local lr lr_rc lr_raw
  lr_raw="$(mktemp)"
  bash "$SELF/ledger-reverify.sh" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" >"$lr_raw" 2>/dev/null
  lr_rc=$?
  lr="$(awk -F'\t' '$1!="STILL-LIVE"{ d = ($1=="HAND-REVIEW") ? "" : "  "$3; print $1"  "$2 d }' "$lr_raw" | sort -u)"
  rm -f "$lr_raw"
  if [ "$lr_rc" -eq 0 ]; then none_or "$lr"; else
    echo "DETECTOR-REFUSED  ledger-reverify.sh exited ${lr_rc} without classifying, so this section is NOT a finding of 'none'. Run it directly against this consumer to see why: reconcile/ledger-reverify.sh <dist> <base> <consumer> <theirs>"
  fi

  # ITS TWINS WERE BOTH DRIVEN HERE AND IT WAS NOT, WHICH IS THE WHOLE DEFECT. This detector
  # names itself "the twin of ledger-reverify.sh's CLOSE-CANDIDATE and layer-drift.sh's
  # EXTENSION-RETIRE-CANDIDATE" in its own header; both of those render above. It shipped in
  # reconcile/, SKILL.md named it ZERO times, no step and no driver invoked it, and
  # core/fixtures/shadowed-local-validators/ was green over it the whole time -- a fixture
  # proving a detector works says nothing about whether anything RUNS it.
  #
  # THE 0/2 SPLIT IS ITS CONTRACT, and it is why this call does not end in `|| true` like the
  # ones above. Its own header: "a caller must be able to tell 'no forks are shadowed' from
  # 'this never ran', and those are the same empty output." Exit 2 is a refusal -- an
  # unresolvable root, an unsourceable lib.sh, or a close grammar `ledger_close_awk` would not
  # lift. Swallowing that would print `none` for a detector that never classified, which is
  # the exact shape of report this region exists to stop.
  #
  # `local` is declared SEPARATELY from the assignment on purpose: `local x="$(cmd)"` returns
  # the status of `local`, not of the command, so the refusal would read as success.
  sub "Shadowed local validators (a local fork whose divergence upstream has ADOPTED — the operator confirms and retires, never auto-retired):"
  local sv sv_rc
  sv="$(bash "$SELF/warn-shadowed-local-validators.sh" --root "$CONSUMER" 2>/dev/null)"
  sv_rc=$?
  if [ "$sv_rc" -eq 0 ]; then
    none_or "$(printf '%s' "$sv" | awk -F'\t' 'NF{print $1"  "$2"  "$3}' | sort -u)"
  else
    echo "DETECTOR-REFUSED  warn-shadowed-local-validators.sh exited ${sv_rc} without classifying, so this section is NOT a finding of 'none'. Run it directly against this consumer to see why: reconcile/warn-shadowed-local-validators.sh --root <consumer>"
  fi

  # FOUR CLASSIFIERS THAT SHIPPED OUTSIDE THIS REGION WHILE STEP 5 PROMISED IT CARRIED THEM ALL.
  # Each states in its own header that it is "a classifier, not a gate" emitting TSV for a caller
  # to read, and each was left to be NARRATED — which is the failure this driver's own header
  # says it exists to end: an LLM stands between the detector and the operator and can drop the
  # line. `--verify` could not fail on their omission because they were never in the region to
  # omit. `I105` now binds the set so a new detector cannot land outside it silently.
  #
  # ALL FOUR BELOW SAY "0 ALWAYS" IN THEIR OWN HEADERS, SO A NON-ZERO EXIT IS A CRASH, and each
  # used to read its rows through `| awk | sort -u` and render `none` whatever the detector's
  # status was -- the BL-230 class the orientation block and the ledger site above carried, where
  # batch 160 drove a dead detector into a clean-looking section. Each site now runs its detector
  # BARE into a file and reads the rc there (the call stays at the site, spelled
  # `"$SELF/<name>"`, because that literal is what I105 keys "invoked" on); `a0_render` then
  # projects the rows, so the status decided on is the detector's and not the projection's, and a
  # non-zero rc from either renders the refusal line. Their exit-0-with-stderr refusals are each
  # detector's own contract and are not decided here.
  # usage: a0_render <rc> <raw-file> <awk-program> <refusal-name-and-usage>
  a0_render() {
    local a0_rc="$1" a0_raw="$2" a0_prog="$3" a0_what="$4" a0_rows=""
    if [ "$a0_rc" -eq 0 ]; then
      a0_rows="$(awk -F'\t' "$a0_prog" "$a0_raw" | sort -u)" || a0_rc="projection-$?"
    fi
    rm -f "$a0_raw"
    if [ "$a0_rc" = 0 ]; then none_or "$a0_rows"; else
      echo "DETECTOR-REFUSED  ${a0_what%% *} exited ${a0_rc} without classifying, so this section is NOT a finding of 'none'. Run it directly against this consumer to see why: reconcile/${a0_what}"
    fi
  }
  local a0_raw a0_rc
  sub "Predicate reclassification (the incoming release moves an adjudication predicate over artifacts already stored):"
  a0_raw="$(mktemp)"
  bash "$SELF/predicate-differential.sh" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" >"$a0_raw" 2>/dev/null
  a0_rc=$?
  # A STABLE row is not dropped: its population definition is what lets a second party re-derive
  # the null, and a bare `none` carries none. ONLY THE STATIC DEFINITION is rendered, never the
  # counts after it: `--verify` byte-compares this region at step 7, the counts come from a live
  # corpus, and an artifact written between approve and verify would fail it as hand-edited.
  a0_render "$a0_rc" "$a0_raw" '$1!="PREDICATE-STABLE"{print $1"  "$2"  "$3; next} match($3, /population: root=`[^`]*` corpus=`[^`]*` series=`[^`]*`/){print $1"  "$2"  "substr($3, RSTART, RLENGTH); next} {print $1"  "$2}' "predicate-differential.sh <dist> <base> <theirs> <consumer>"

  sub "Retired core fixtures the consumer still carries (core stopped shipping them; the operator retires the orphan):"
  a0_raw="$(mktemp)"
  bash "$SELF/retired-fixtures.sh" "$DIST" "$THEIRS" "$CONSUMER" >"$a0_raw" 2>/dev/null
  a0_rc=$?
  a0_render "$a0_rc" "$a0_raw" 'NF{print $1"  "$2"  "$3}' "retired-fixtures.sh <dist> <theirs> <consumer>"

  sub "Retired contract shapes in consumer layer files:"
  a0_raw="$(mktemp)"
  bash "$SELF/retired-layer-contract.sh" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" >"$a0_raw" 2>/dev/null
  a0_rc=$?
  a0_render "$a0_rc" "$a0_raw" 'NF{print $1"  "$2"  "$3}' "retired-layer-contract.sh <dist> <base> <theirs> <consumer>"

  # THIS SECTION IS NO LONGER THE ONLY CHANNEL FOR THIS CLASS, AND THE HEADING CANNOT SAY SO.
  # `apply.sh` runs this same detector at step 7 and emits a `WORKLIST retired-layer-passage`
  # row, so the class now reaches the operator through the worklist a consumer already works and
  # the re-stamp is withheld until the row is disposed. This section remains the EARLIER look --
  # step 5, before any write -- and the two are the same finding rather than two. Stated here and
  # not in the rendered text because the region above is byte-compared by `--verify` against an
  # approved report: a heading edit invalidates every report approved before this release, which
  # is a cost paid by consumers for a sentence that belongs to the reader of this file.
  sub "Retired core passages still carried by a consumer layer file:"
  a0_raw="$(mktemp)"
  bash "$SELF/retired-layer-passage.sh" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" >"$a0_raw" 2>/dev/null
  a0_rc=$?
  a0_render "$a0_rc" "$a0_raw" 'NF{print $1"  "$2"  "$3}' "retired-layer-passage.sh <dist> <base> <theirs> <consumer>"

  # This sibling exits 2 when a corpus could not be read, because its empty-theirs failure
  # is a MAXIMAL report (every rulebook token retired) rather than a silent one; a refusal
  # that rendered as `none` here would be the third shape of the same defect. The `$?`
  # read below is the detector's status only under this file's `set -o pipefail`, as at
  # the four refusal sites above; without it the awk's 0 would render the refusal as `none`.
  sub "Retired status tokens reused in a consumer layer file's own prose:"
  local rlt rlt_rc
  rlt="$(bash "$SELF/retired-layer-token.sh" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" 2>/dev/null | awk -F'\t' 'NF{print $1"  "$2"  "$3}' | sort -u)"
  rlt_rc=$?
  if [ "$rlt_rc" -eq 0 ]; then none_or "$rlt"; else
    echo "DETECTOR-REFUSED  retired-layer-token.sh exited ${rlt_rc} without scanning, so this section is NOT a finding of 'none'. Run it directly against this consumer to see why: reconcile/retired-layer-token.sh <dist> <base> <theirs> <consumer>"
  fi

  echo
  echo "<!-- END GENERATED: reconcile-mechanical -->"
}

if [ "$MODE" = "print" ]; then
  render
  exit 0
fi

# --- verify ---
[ -f "$REPORT" ] || { echo "emit-report: report not found: $REPORT" >&2; exit 2; }
# The rendered region carries ONE machine-specific value: the absolute distribution path in
# each `full: diff <(git -C <dist> show …)` reproduction command. The path is deliberately
# concrete there — a command the operator must edit before running is a path out they cannot
# walk — but it makes the region unequal across checkouts, and `--verify` byte-compares.
#
# Consequence, measured: a consumer generated a report from a scratch clone under /private/tmp;
# verifying the SAME report from a normal checkout failed with "STALE or HAND-EDITED" on nothing
# but that path. That is a false accusation, and it sends the operator to regenerate a sound
# report. It also defeats the reason `--verify` is offered to operators at all — SKILL.md step 5
# says they "can run the same --verify to trust any report without re-running the detectors by
# hand", and before this they could only trust reports generated at their own dist path.
#
# So the dist path is normalized out of BOTH sides before comparing. Anchored on ` show
# <theirs>:` rather than a bare `[^ ]*`, so a checkout path containing spaces still normalizes.
# Nothing else is normalized: this is the one field whose value is a property of WHERE the
# detectors ran rather than WHAT they found, and a hand-edit anywhere else still fails.
norm_dist() { sed -E "s|git -C .* show ${THEIRS}:|git -C <dist> show ${THEIRS}:|g"; }
want="$(render | norm_dist)"
got="$(awk '/BEGIN GENERATED: reconcile-mechanical/{f=1} f{print} /END GENERATED: reconcile-mechanical/{f=0}' "$REPORT" | norm_dist)"
if [ -z "$got" ]; then
  echo "FAIL: the report has no 'reconcile-mechanical' GENERATED region. The mechanical sections" >&2
  echo "  (buckets, deletions, blocking-layer, drift, relabel) must be RENDERED by emit-report.sh," >&2
  echo "  not composed — or a finding can be silently dropped. Emit it and re-write the report." >&2
  exit 1
fi
# A FRESH RENDER WHOSE CLASSIFIER REFUSED CANNOT VERIFY ANYTHING, WHATEVER THE REPORT SAYS. The
# comparison below would pass a report whose approved region carries the same refusal -- a report
# rendered while preclassify was failing, approved, and then verified while it still fails -- and
# `apply.sh` writes on a 0 from here. The buckets, worklist and deletions are exactly what the
# approval was for, so a render that has none of them is refused before the byte-compare.
#
# SCOPED TO preclassify's OWN REFUSAL PREFIX, never to `^DETECTOR-REFUSED` at large: a report may
# legitimately carry another detector's refusal line that the operator read and approved (the
# seeded fixture world carries a retired-layer-token.sh one), and that report must still verify.
# The `--templates` refusal is a different line (`preclassify.sh --templates exited`) and is not
# matched either; it is decided by the byte-compare like every other detector's.
#
# A STAGED FILE, NOT `printf | grep -q` AND NOT A HERE-STRING. `grep -q` leaves at its first match
# while printf is still writing a render that can exceed the pipe buffer (I54/I54b). The here-string
# that replaced it is staged by bash itself, and a failed staging write ran grep on EMPTY stdin --
# "no refusal line" -- so a render whose classifier refused verified as present, current and
# complete, and apply.sh writes on that 0 (BL-360). The render is staged once with its status read,
# and ONE grep both decides and extracts: 0 = the refusal is there, 1 = it is not, >=2 = grep could
# not read, which is a refusal too and never "not there". The cause is cut with parameter expansion,
# so no third reader exists. A failed staging or read decides nothing: UNDECIDED, exit 1 -- never 3,
# which tells apply.sh the difference is safe.
if er_stage verify.render "$want" 2>/dev/null; then
  _pc_cause="$(grep -m1 -E '^DETECTOR-REFUSED  preclassify\.sh (exited|returned) ' "$_er_tmp/verify.render")"; _pc_rc=$?
else
  _pc_rc="staging-$?"
fi
if [ "$_pc_rc" != 0 ] && [ "$_pc_rc" != 1 ]; then
  echo "FAIL: the fresh render could not be checked for a preclassify refusal (${_pc_rc}), so whether its buckets, worklist and deletions were classified on this run is unknown — the region cannot be verified." >&2
  echo "  cause: UNDECIDED — the fresh render could not be staged or read for the preclassify check (${_pc_rc}); check that TMPDIR (${TMPDIR:-/tmp}) is writable and has space and that no file-size limit is set, then re-run --verify. Do not re-approve on this run's reading." >&2
  exit 1
fi
if [ "$_pc_rc" = 0 ]; then
  echo "FAIL: preclassify.sh did not classify on this run, so the mechanical region cannot be verified — its buckets, worklist and deletions are unknown, not empty." >&2
  _pc_cause="${_pc_cause#DETECTOR-REFUSED  }"
  _pc_cause="${_pc_cause%%, so this section*}"
  echo "  cause: PRECLASSIFY-REFUSED — ${_pc_cause}. Run reconcile/preclassify.sh <dist> <base> <theirs> <consumer> directly, fix what it reports, then re-render and re-approve." >&2
  exit 1
fi
if [ "$want" = "$got" ]; then
  echo "emit-report: the report's mechanical region is present, current, and complete."
  exit 0
fi
echo "FAIL: the report's 'reconcile-mechanical' region is STALE or HAND-EDITED — it does not match" >&2
echo "  what the detectors render now. Re-render with emit-report.sh and re-emit the report." >&2
# --- THE MISMATCH IS DECIDED, NOT ONLY REPORTED ------------------------------------------------
# A region goes stale for three reasons, and only one of them is the unsafe direction this gate
# exists for. (a) Upstream moved after the render: the `_theirs_` tree or `VERSION` line differs,
# and the whole region describes another range. (b) The report was hand-edited, or a detector now
# renders a row the operator never saw: the fresh render carries a line the approved region lacks.
# (c) The approved region carries `HARD-*` row(s) the detectors no longer render, the refs are
# unchanged, and nothing HARD is new — the blockers were RESOLVED after the render. SKILL.md step 7
# demands that resolution before `apply` writes, and every resolution rewrites the region: a
# `--stamp readopt` turns `HARD-OVERRIDE-DRIFT-SECTION` into `OVERRIDE-OK`, a register row removes
# `HARD-LAYER-ADJUDICATION-MISSING`. So (c) is the COMMON path on any pull that had a blocker, not
# an edge case. Measured on the reference consumer: four of its six applies since this gate moved
# into apply.sh re-rendered the region after resolving blockers as an unwritten workaround, and the
# fifth got this FAIL first with a message naming (a) and (b), both false. Filed as
# PC-S305-UNION-GATE-UNPASSABLE-ON-ANY-PULL-THAT-HAD-A-BLOCKER.
#
# STILL A REFUSAL. The operator approved findings that no longer exist, and a resolution can add
# rows they have not seen (a merge that leaves OVERRIDE-ASSERTS-SHADOW-SURVIVES, say), so the
# post-resolution region is re-rendered and re-approved rather than waved through; a pass here
# would need a vocabulary of "benign" rows and would acquit whatever that vocabulary missed. What
# changes is the DIAGNOSIS: a distinct exit code so apply.sh can say which case this is, and a
# `cause:` line so an operator running --verify by hand reads the same answer.
#
# KEYED ON THE `HARD-` PREFIX ONLY, which is the contract SKILL.md already binds ("statuses
# prefixed HARD- must block apply"), never on a list of status names. A mismatch with no HARD row
# in it, or with a HARD row the operator has NOT seen, reads as (b) and gets the generic message,
# never (c). (a) is decided before (c) because a moved upstream makes every other line
# incomparable, including the HARD rows.
#
# TWO THINGS (c) DOES NOT SEPARATE, AND NEITHER IS THE UNSAFE DIRECTION. A report hand-edited to
# ADD a HARD row the detectors never rendered reads (c) too: the approval saw MORE than exists,
# nothing was hidden from it, and the remedy is the same re-render. And a resolution can leave
# rows that are NOT HARD and that the approval never saw (a merge that renders
# OVERRIDE-ANCHOR-UNRESOLVED or OVERRIDE-ASSERTS-SHADOW-SURVIVES, say); (c) still fires, because
# the HARD rule is the blocking contract, but the cause line COUNTS those rows rather than
# asserting they do not exist, and the re-approval is where they get read. That is why (c)
# refuses instead of passing.
# NORMALISED BEFORE THE SET DIFFERENCE, NOT AFTER. One blocker renders twice in the region with
# different padding — `%-32s %s` in the blocking list, `STATUS  path` in its detector's section
# — and a difference taken over raw lines then de-duplicated afterwards reports a blocker as
# GONE when only its padded copy is missing while the other copy still renders. Measured: a
# still-rendered blocker and a genuinely resolved one were indistinguishable that way. So both
# sides are whitespace-normalised and made unique first, and every count below is over sets.
#
# BOTH NORMALISED SIDES ARE STAGED, EACH WITH ITS STATUS READ, and the set difference is taken
# only over two files that were written. As `comm <(… | norm_rows) <(… | norm_rows)` a failed
# side was an EMPTY side: a failed `want` side left every approved row "only in the report", so
# every HARD row read as resolved and the run exited 3 -- BLOCKERS-RESOLVED, the one cause that
# tells the operator the difference is safe. Measured with a PATH stub failing `sed`. A side that
# could not be computed now decides the cause itself (UNDECIDED, exit 1, below): the mismatch is
# already established above, so this is never a pass -- only the diagnosis is withheld.
norm_rows() { sed -E 's/[[:space:]]+/ /g' | LC_ALL=C sort -u; }
er_sets_why=""
only_render=""; only_report=""
if [ -z "$_er_tmp" ]; then
  er_sets_why="no staging directory could be created"
elif ! er_stage sets.want "$want" 2>/dev/null || ! er_stage sets.got "$got" 2>/dev/null; then
  er_sets_why="the two regions could not be staged"
elif ! norm_rows < "$_er_tmp/sets.want" > "$_er_tmp/sets.want-rows"; then
  er_sets_why="normalising the fresh render's rows failed"
elif ! norm_rows < "$_er_tmp/sets.got" > "$_er_tmp/sets.got-rows"; then
  er_sets_why="normalising the approved report's rows failed"
elif ! only_render="$(LC_ALL=C comm -23 "$_er_tmp/sets.want-rows" "$_er_tmp/sets.got-rows")" \
     || ! only_report="$(LC_ALL=C comm -13 "$_er_tmp/sets.want-rows" "$_er_tmp/sets.got-rows")"; then
  er_sets_why="the set difference (comm) failed"
  only_render=""; only_report=""
fi
# `_base_`/`_theirs_` ONLY here. The `_stamp_` line is rendered from the CONSUMER's stamp and
# moves when the consumer re-stamps, not when upstream does; keyed with these it made a moved
# stamp read as "upstream moved" with both disjuncts false, and dropped from the key altogether
# a post-apply re-run (stamp legitimately at theirs, every applied path now already-at-theirs)
# read as blockers RESOLVED and was told to re-approve and apply a range already applied. So it
# is a THIRD cause, decided on that line alone, between (a) and (c): the tree's recorded
# position moved under the report, and the region is not comparable until the base is
# re-derived. apply.sh decides the post-apply case from the stamp before it ever reads this.
refs_render="$(printf '%s\n' "$want" | grep -E '^_(base|theirs)_ ')"
refs_report="$(printf '%s\n' "$got"  | grep -E '^_(base|theirs)_ ')"
stamp_render="$(printf '%s\n' "$want" | grep -E '^_stamp_ ')"
stamp_report="$(printf '%s\n' "$got"  | grep -E '^_stamp_ ')"
# The sets are already normalised and unique, so a HARD row here is one blocker, not one line.
hard_rows() { grep '^HARD-'; }
gone_rows="$(printf '%s\n' "$only_report" | hard_rows)"
new_rows="$(printf '%s\n' "$only_render"  | hard_rows)"
hard_gone="$(printf '%s\n' "$gone_rows" | grep -c '^HARD-')" || hard_gone=0
hard_new="$(printf '%s\n' "$new_rows"   | grep -c '^HARD-')" || hard_new=0
# Non-HARD lines the render carries and the approval never saw. Counted, never acquitted — and
# the LIST is the authority, the count is advisory. A resolution replaces a HARD row with a
# section's affirmative-empty text (`none`, `0 HARD blockers.`), or with an `-OK` row, or moves a
# `**section**` header into the diff; measured, a plain resolution and one hiding a real finding
# both counted 2 until those were excluded, because the finding REPLACED `none` rather than
# adding to it. So the boilerplate shapes are left out of the count and kept in the list.
unseen_rows() { grep -Ev '^HARD-|^DETECTOR-REFUSED|^$|^none$|^0 HARD blockers\.$|^\*\*|^[A-Z][A-Z-]*-OK([[:space:]]|$)|^<!--|^_(base|theirs|stamp)_ |: none$'; }
other_new="$(printf '%s\n' "$only_render" | unseen_rows | grep -c .)" || other_new=0
# A detector that REFUSED on this render is a HARD row's absence with no one to vouch for it: the
# rows it would have rendered are simply not there, which is exactly what (c) keys on. A new
# DETECTOR-REFUSED line therefore blocks (c) the way a new HARD row does.
refused_new="$(printf '%s\n' "$only_render" | grep -c '^DETECTOR-REFUSED')" || refused_new=0
if [ "$refs_render" != "$refs_report" ]; then
  cause=UPSTREAM-MOVED
  echo "  cause: UPSTREAM-MOVED — the region was rendered for a different range or a different core/ tree than this run's theirs; every other line is incomparable." >&2
elif [ "$stamp_render" != "$stamp_report" ]; then
  cause=STAMP-MOVED
  echo "  cause: STAMP-MOVED — the consumer's stamp (.claude/.ai-dlc-version commit:) changed since this report was rendered: an apply of this range already moved this tree (apply.sh decides that case from the stamp), or the stamp was edited by hand. The region is not comparable until the base is re-derived from the stamp as it now stands; re-run the dry run rather than re-approving this report. Beside the stamp, the fresh render carries ${hard_new} HARD-* row(s) the approved region lacks and lacks ${hard_gone} it carries." >&2
elif [ -n "$er_sets_why" ]; then
  cause=UNDECIDED
  echo "  cause: UNDECIDED — the region does not match, but which rows differ could not be computed (${er_sets_why}), so no HARD-* row can be called resolved or new. Re-run --verify once the fault is gone; do not re-approve on this run's reading." >&2
elif [ "$hard_gone" -gt 0 ] && [ "$hard_new" -eq 0 ] && [ "$refused_new" -eq 0 ]; then
  cause=BLOCKERS-RESOLVED
  echo "  cause: BLOCKERS-RESOLVED — ${hard_gone} HARD-* row(s) in the approved region no longer render, no HARD-* row is new, and the refs are unchanged: the blockers were resolved after this report was rendered (or the report carries a HARD row that never rendered; either way the approval saw more than exists). The fresh render carries ${other_new} finding row(s) the approval has not seen (listed below as unseen:, boilerplate excluded); re-render the region from the tree as it now stands and re-approve it reading them." >&2
  printf '%s\n' "$gone_rows" | sed 's/^/    resolved: /' >&2
  [ "$other_new" -gt 0 ] && printf '%s\n' "$only_render" | unseen_rows | sed 's/^/    unseen: /' >&2
else
  cause=UNDECIDED
  echo "  cause: UNDECIDED — the fresh render carries ${hard_new} HARD-* row(s) and ${refused_new} DETECTOR-REFUSED line(s) the approved region lacks (a finding the approval never saw, or a detector that did not run), or the difference is outside the blocking list. Read the diff." >&2
fi
echo "  Diff (want vs report):" >&2
# Staged, not `<( )`, for the fd race the orientation diff states (3-8 in 2000 under 4 bash 3.2
# workers). This diff is the operator's only view of WHAT differs, so a failed one says so
# instead of printing an empty section under the heading above.
if er_stage verify.want "$want" 2>/dev/null && er_stage verify.got "$got" 2>/dev/null; then
  # Piped through `er_pdiff`, not two paths, so the diagnostic reads exactly as it did.
  er_pdiff "$_er_tmp/verify.want" "$_er_tmp/verify.got" >&2; _vd_rc=$?
  [ "$_vd_rc" -ge 2 ] && echo "  (the diff itself failed, exit ${_vd_rc}: the difference above is decided, but its lines are not shown)" >&2
else
  echo "  (the want/report regions could not be staged for diff: the difference above is decided, but its lines are not shown)" >&2
fi
[ "$cause" = BLOCKERS-RESOLVED ] && exit 3
exit 1
