#!/usr/bin/env bash
# validate-plan-shape.sh -- a plan in docs/plans/ must be RESUMABLE by a session that
# has never seen the one that wrote it.
#
# WHY THIS EXISTS. A long piece of work outlives its session. The handoff is the plan
# file, and until now nothing said what a plan had to contain, so the shape was held by
# whoever happened to write it. Measured on this repo's first plan, at the moment it was
# handed off:
#
#   - TWO status records, and the older one predated a release. A fresh reader hitting
#     it first gets a version of the world that is one release stale, with nothing
#     saying which to believe.
#   - Two release sections describing work that had ALREADY SHIPPED, still written in
#     the imperative. A session told to FOLLOW the file would have redone them.
#   - No statement of which repo it operates on, which repo it must not write, or what
#     to do first.
#
# None of that is a writing-quality complaint. Each one makes the file produce WRONG
# WORK when followed literally, which is the only thing a handoff is for.
#
# THE CHECKS ARE STRUCTURAL, NEVER STYLISTIC. This is a linter over prose, which is the
# genre most likely to fire on something a human did deliberately -- and the repo's own
# rule is that a linter erroring on first contact gets turned off and then catches
# nothing. So every check below is one with NO false-positive path: an absent required
# section, a citation that does not resolve, a plan with no next action, an identifier
# the file itself describes two contradictory ways. Nothing here has an opinion about
# wording.
#
# ON THE FALSE-POSITIVE MEASUREMENT, STATED PLAINLY. The repo's rule is to measure a new
# check's false-positive set before shipping. The corpus here is `docs/plans/*.md`, and
# at the release that shipped this it was ONE FILE. A one-file corpus cannot measure
# anything, and pretending otherwise would be the vacuous-measurement shape this repo
# names elsewhere. So the checks were chosen to have no FP path by construction rather
# than tuned against a corpus, and that is the whole of the argument for them.
#
# Usage: validate-plan-shape.sh [<plan-file>...]     (default: docs/plans/*.md)
# Exit:  0 = every plan conforms (warnings may print), 1 = at least one ERROR,
#        2 = bad usage / no corpus to check.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 2

if [ "$#" -gt 0 ]; then
  FILES=("$@")
else
  # A GLOB THAT MATCHES NOTHING MUST NOT REPORT SUCCESS. `for f in docs/plans/*.md` with
  # no matches iterates once over the literal pattern in some shells and zero times in
  # others; either way "no plans" would exit 0 and read exactly like "every plan passed".
  # This is the repo's a-zero-is-not-a-finding rule applied to the corpus itself.
  FILES=()
  while IFS= read -r f; do [ -n "$f" ] && FILES+=("$f"); done < <(find docs/plans -maxdepth 1 -name '*.md' 2>/dev/null | sort)
  if [ "${#FILES[@]}" -eq 0 ]; then
    echo "validate-plan-shape: no plan files under docs/plans/ — nothing to check." >&2
    echo "  This is a PASS only if the repo genuinely holds no plans. If you expected one," >&2
    echo "  the plan was never promoted out of ~/.claude/plans/ and will not survive the session." >&2
    exit 2
  fi
fi

errs=0; warns=0
err()  { printf 'ERROR %s: %s\n'   "$1" "$2"; errs=$((errs+1)); }
warn() { printf 'WARN  %s: %s\n'   "$1" "$2"; warns=$((warns+1)); }

for f in "${FILES[@]}"; do
  [ -f "$f" ] || { err "$f" "not a readable file"; continue; }
  rel="${f#./}"

  # --- P1: the entry point ---------------------------------------------------------
  # A resuming session reads top-down and acts on the first thing that looks like an
  # instruction. Without a declared entry point that is whatever section happens to be
  # first, which on the measured plan was a status table one release out of date.
  if ! grep -qE '^#{1,3}[[:space:]]+Start here[[:space:]]*$' "$f"; then
    err "$rel" "no '## Start here' section. A resuming session has no declared entry point, so it acts on whichever section it reads first."
  fi

  # --- P2: an ordered next action --------------------------------------------------
  # "FOLLOW this plan" needs something to follow. A plan that records state and never
  # says what to do next is a report.
  if ! grep -qE '^[[:space:]]*1\.[[:space:]]+' "$f"; then
    err "$rel" "no numbered action list (no line starting '1. '). A plan with no ordered next action cannot be followed, only read."
  fi

  # --- P3: the read/write boundary -------------------------------------------------
  # Every plan in this repo so far operates on two trees, one of which must never be
  # written. That boundary is the single most expensive thing to get wrong and the
  # cheapest to state.
  if ! grep -qiE 'never (write|edit) it|read it, never write|do not (write|edit)' "$f"; then
    warn "$rel" "states no read/write boundary. If this plan touches a tree it must not write, say so here — the operator's repo is the usual one."
  fi

  # --- P3b: the operator ping ------------------------------------------------------
  # A PLAN IS EXECUTED BY A SESSION THE OPERATOR CANNOT SEE. Without an explicit
  # instruction to speak, the two states "still working" and "stopped, needs a decision"
  # look identical from outside, and the only way to tell them apart is to poll. Measured
  # across this repo's own plan runs: every stall in a consumer session ended with the
  # operator asking, not the session reporting -- including one that sat on a genuine
  # blocking question, and one that had FINISHED.
  #
  # This is the same class the repo names everywhere else: a state that cannot be
  # distinguished from a healthy one reads as healthy. Here the undistinguishable pair is
  # progress versus a silent block, and the reader paying for it is a human.
  #
  # REQUIRED, not advisory, and it must survive into plans nobody here writes -- a
  # convention with no enforcer is a suggestion, which is why this is a check and not a
  # sentence in a template. The grammar is deliberately loose: any phrasing that names
  # pinging/notifying/reporting to the operator satisfies it, because pinning an exact
  # sentence would make this a copy-paste ritual instead of an instruction the author
  # meant.
  if ! grep -qiE '(ping|notify|report (back )?to|surface (it |them )?to|check in with)[^.]{0,40}(the )?operator|operator[^.]{0,40}(ping|notified|informed)' "$f"; then
    err "$rel" "no operator-ping instruction. A session executing this plan must be told to ping the operator on any question or decision, and when execution completes — otherwise 'still working' and 'stopped, needs you' are indistinguishable from outside and the operator has to poll."
  fi

  # --- P4: citations resolve -------------------------------------------------------
  # `path:line` is this repo's evidence form, and a plan is mostly evidence. A citation
  # that cannot be located at resume time is the promissory-note defect the pm role file
  # names: by then it is too late to backfill, and the reader must either re-derive the
  # relationship or accept an unfalsifiable claim.
  #
  # Scoped to paths under a top-level directory that EXISTS, so a plan naming a file it
  # intends to CREATE is out of scope by construction rather than by exemption.
  while IFS= read -r cite; do
    [ -n "$cite" ] || continue
    p="${cite%:*}"; ln="${cite##*:}"
    top="${p%%/*}"
    [ -d "$top" ] || continue                 # not a path into this repo
    if [ ! -f "$p" ]; then
      err "$rel" "cites '$cite' and '$p' does not exist. A resuming session cannot verify the claim this line was evidence for."
    else
      have="$(wc -l < "$p" | tr -d ' ')"
      [ "$ln" -le "$have" ] 2>/dev/null || \
        err "$rel" "cites '$cite' but '$p' has only $have lines. The citation resolves to nothing."
    fi
  done < <(grep -oE '\b[A-Za-z0-9_.-]+(/[A-Za-z0-9_.-]+)+:[0-9]+\b' "$f" | sort -u)

  # --- P5: no identifier described two contradictory ways --------------------------
  # THE DEFECT THIS EXISTS FOR, measured on the first plan: R2 and R5 were merged and
  # their sections still read as work to do, while a table elsewhere correctly said
  # merged. A session told to FOLLOW the file would have redone shipped releases.
  #
  # Derived from the file's own identifiers, never a hand-list: any `R<n>` the file
  # marks SHIPPED/merged must not also be marked not-started anywhere in it.
  shipped="$(grep -oiE '\bR[0-9]+\b.{0,80}(SHIPPED|merged)' "$f" | grep -oE '^R[0-9]+' | sort -u)"
  notstarted="$(grep -oiE '\bR[0-9]+\b.{0,80}(not started|not yet started|TODO)' "$f" | grep -oE '^R[0-9]+' | sort -u)"
  if [ -n "$shipped" ] && [ -n "$notstarted" ]; then
    both="$(comm -12 <(printf '%s\n' "$shipped") <(printf '%s\n' "$notstarted") | tr '\n' ' ' | sed 's/ *$//')"
    [ -n "$both" ] && err "$rel" "describes [$both] as BOTH shipped and not-started. A session told to follow this plan redoes merged work."
  fi

  # --- P6: one current status record ------------------------------------------------
  # Two status sections is not a formatting nit: the reader believes whichever they hit
  # first, and on the measured plan that was the stale one. A superseded section is fine
  # — it just has to say so, in the section, where the reader is.
  statuses="$(grep -nE '^#{1,3}[[:space:]]+(Status|Where things stand|Current state)[[:space:]]*$' "$f" | cut -d: -f1)"
  n_status="$(printf '%s\n' "$statuses" | grep -c . || true)"
  if [ "${n_status:-0}" -gt 1 ]; then
    # THE WINDOW STOPS AT THE NEXT HEADING, and a fixed line count is why it has to.
    # A flat `ln,ln+4` window bleeds into whatever follows, so a section is scored
    # MARKED by text that belongs to the next one. It happened immediately: the seeded
    # negative case read "does not say it is superseded", the window reached it, `supersed`
    # matched, and the arm went silent on the exact defect it was written for. A window
    # that can read another section's text is not reading this section.
    unmarked=0
    while IFS= read -r ln; do
      [ -n "$ln" ] || continue
      # HERE-STRING, NOT A PIPE (I54b). `awk | grep -q` under pipefail answers with the
      # WRITER's EPIPE once the section clears the pipe buffer, so a long section reports
      # 'no marker found' on text that contains one — and P6 would then error on a plan
      # that had correctly marked its superseded record.
      sect="$(awk -v start="$ln" '
        NR < start { next }
        NR > start && /^#/ { exit }
        { print }
      ' "$f")"
      grep -qiE 'supersed|out of date|no longer current|see .*(RESUME|Start here)' <<<"$sect" || unmarked=$((unmarked+1))
    done < <(printf '%s\n' "$statuses")
    [ "$unmarked" -gt 1 ] && err "$rel" "carries $n_status status sections and $unmarked of them claim to be current. The reader believes whichever they reach first."
  fi

  # --- P7: an instruction that ships its own opt-out --------------------------------
  # THE DEFECT, measured on this repo's own runbook before it was handed over. A section
  # told a graph session to run a consolidation pass. Beside it sat a fenced decision
  # table -- `ok -> no target, stop` / `OVER -> run it` -- and a paragraph of sizes
  # "for the record". Every figure in it was true and freshly measured. Together they
  # were an OPT-OUT KIT: a session told to do a thing, reading in the same section that
  # its subject looks healthy, can talk itself out of the work and cite the plan while
  # doing so. The operator's words for it are the name of this arm.
  #
  # A plan is a set of instructions. If an action is genuinely conditional, the condition
  # belongs in the numbered action list where the executor decides it deliberately -- not
  # in a code comment beside the instruction, where it reads as permission.
  #
  # WHY THE GRAMMAR IS THIS NARROW, and it is the whole false-positive argument. The arm
  # matches ONE shape: a `#` comment carrying an arrow that resolves an outcome to NOT
  # acting. Measured over `docs/plans/*.md` at the release that shipped it -- 9 plans,
  # every one of them long and instruction-dense -- the false-positive set is EMPTY, and
  # the same expression fires on the historical revision that carried the defect
  # (`git show dd9caf3`, line 452). Prose conditionals are deliberately out of scope:
  # "a different answer means STOP and ping the operator" is a correct instruction and
  # this arm must never touch it.
  #
  # A WARNING, NOT AN ERROR, and that is not timidity. Conditional steps are legitimate
  # -- this repo's own runbooks stop on a stamp mismatch. What the arm can prove is the
  # SHAPE, never that this particular condition is illegitimate, so it names the line and
  # leaves the judgement with the author. The binding statement is in CLAUDE.md.
  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    warn "$rel" "line ${hit%%:*} is an opt-out inside an instruction: a comment that maps an outcome to NOT doing the work ('${hit#*:}'). If the action is conditional, put the condition in the numbered action list where the executor decides it; beside the instruction it reads as permission to skip."
  done < <(grep -nE '^[[:space:]]*#.*(->|→).*([Ss]top|[Ss]kip|do not|don.t|nothing to (do|rotate)|no [A-Za-z-]+ (target|subject))' "$f" | cut -c1-200)
done

echo "validate-plan-shape: ${#FILES[@]} plan(s) checked, $errs error(s), $warns warning(s)."
[ "$errs" -eq 0 ] || exit 1
exit 0
