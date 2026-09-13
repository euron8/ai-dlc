#!/bin/bash
#
# AI/DLC Artifact-Size Budget Validator (Rule 25)
#
# WHY THIS EXISTS
# Living planning artifacts grow every sprint. Rule 25 has always said so, and
# Rule 25(d) has always had thresholds -- but they were WARN-ONLY and they fired
# at RETRO. That is a ratchet with no pawl: the only mechanism that notices an
# oversized artifact runs at the end of the sprint that already paid for it. Every
# sprint starts a little slower than the last, and nothing ever intervenes in time.
#
# Measured in the reference consumer at sprint 289, in a planning phase that ran
# 3h16m without finishing:
#
#   product-brief.md              480 KB  ~120k tok   2x its 60k threshold
#   pipeline-snapshot.md           50 KB   ~12k tok   2x its  6k threshold
#   pipeline-continuation-log.md  1.3 MB  ~330k tok  33x its 10k threshold
#   context-mode-protection-log   210 KB   ~53k tok   NO threshold existed at all
#
# The snapshot is the expensive one and the reason this runs at GATES too, not
# only at sprint start: the protocol whole-reads it at every gate (Checks 14/15),
# on every resume, and after every compaction (ai-dlc-recover.sh). At 50 KB and 8
# reads it was the single largest byte-injector in the session -- larger than any
# source file -- and the reads it forced are what drove 6 auto-compactions at
# ~33-minute intervals. Rule 23's exemption that lets the gate re-read it whole is
# explicitly "conditional on their staying small, which is not automatic." This
# script is what makes it automatic.
#
# WHAT IT MEASURES
# Bytes / AI_DLC_BYTES_PER_TOKEN for each known living artifact found under the
# project's _bmad-output/ and docs/. The divisor is the same NUMBER
# validate-reattach-budget.sh uses, but NOT the same measurement -- and the
# difference matters in the direction of the error.
#
# THE DIVISOR UNDER-COUNTS ON THIS POPULATION, BY 5-11%.
# validate-reattach-budget.sh calibrated bytes/4 against SKILL.md's recovery
# protocol (17,990 bytes ~= 4,439 tokens -> ~4.05 B/tok) and concluded the divisor
# is "slightly conservative, i.e. it over-counts." That is true OF THAT TEXT. This
# script inherited the sentence and applied it to a different population -- prose-
# heavy planning artifacts -- where the ratio, and therefore the DIRECTION of the
# error, reverses.
#
# Measured at sprint 290 in the reference consumer against a 147,176-byte planning
# artifact with four tokenizers (@anthropic-ai/tokenizer, and tiktoken cl100k_base
# / o200k_base / gpt2): 3.62-3.84 bytes/token, so bytes/4 reports ~5-11% FEWER
# tokens than exist. The same four run against SKILL.md returned 3.94-4.22, which
# brackets 4.05 -- so both statements are correct about their own file, and the
# copied one was never re-measured here.
#
# CAVEAT ON THAT MEASUREMENT: no ground-truth Claude tokenizer was reachable (no
# API key in that environment). All four numbers are proxies -- three OpenAI
# vocabularies, plus Anthropic's own local package, which bundles the older Claude
# 1/2 vocab and not the current family's BPE. They converge within a ~15% band,
# which is why the direction is trustworthy; the exact percentage is not. Anyone
# with `count_tokens` access should re-run it and replace this range.
#
# THE DIVISOR STANDS ANYWAY. 5-11% sits inside the 10% grace band below and changed
# no pass/fail verdict found when it was measured. But it errs toward PASSING, not
# toward tripping early, so do not reason about a near-budget artifact as though the
# estimate were conservative. It is not.
#
# History/archive files are NOT measured. Rule 25(a) makes them write-only -- never
# read in the hot path -- so their growth is free. That is the whole point of
# rotation: product-brief-history.md is 2.6 MB in the reference consumer and costs
# nothing, because nothing reads it.
#
# THE THRESHOLD TABLE LIVES HERE, AND ONLY HERE.
# It used to live in retro.md prose. Two copies of a number is one copy too many:
# retro.md and this script would drift, and the prose copy is the one nobody can
# execute. retro.md now calls this script instead of restating it.
#
# USAGE
#   core/scripts/validate-artifact-budget.sh [--root PATH] [--only NAME]
#                                            [--warn-only] [--quiet]
#
#   --only NAME    check a single artifact by basename (gates use
#                  `--only pipeline-snapshot.md`)
#   --check-evidence   audit the gate log's LAST Check 14 row instead of measuring
#                  artifacts. gate-validation.md Check 15 runs this. See "THE
#                  EVIDENCE CELL" below. Optionally paired with --gate-log PATH.
#   --warn-only    report breaches but exit 0 (retro's Rule 25(d) posture: the
#                  sprint is over, blocking it helps nobody). retro.md is its ONLY
#                  caller. Gate Check 14 and the sub-step path deliberately do not
#                  pass it -- there the sprint is still running and the artifact is
#                  still growing, which is the only reason those two enforce at all.
#                  Reading this flag as a general "defer the breach" lever is how a
#                  blocking gate quietly becomes a log line.
#
# WARN AT 100%, BLOCK AT 100% + GRACE.
# The grace band is not softness, it is aim. This check exists to stop a RATCHET,
# and a ratchet announces itself in multiples, not percentages: in the reference
# consumer the real breaches were 161%, 215%, 526% and 3311% of budget. A gate that
# also FAILS at 104% buys nothing and costs a lot -- the lead trims 300 tokens, the
# snapshot grows back by the next gate, and it fails again. That treadmill turns a
# real signal into noise, and noisy gates get ignored. So: anything over budget is
# REPORTED (the number is the truth and you should see it), but only a breach past
# the grace band BLOCKS.
#
# ENV OVERRIDES
#   AI_DLC_BYTES_PER_TOKEN   bytes-per-token divisor          (default 4)
#   AI_DLC_BUDGET_GRACE_PCT  block above budget + this %      (default 10)
#   AI_DLC_BUDGET_<NAME>     per-artifact override in tokens, NAME upper-snaked
#                            from the basename: AI_DLC_BUDGET_PRD_MD=90000
#   AI_DLC_SNAPSHOT_EXTRA_SECTIONS
#                            comma- or newline-separated snapshot section names this
#                            PROJECT adds to the canonical set (default: none, i.e.
#                            core's seven and nothing else). Prefix-matched, like the
#                            core names. See is_canonical_section() for why this is a
#                            declaration and not a loophole.
#
# EXIT
#   0  nothing past the grace band (over-budget-but-within-grace is reported, not
#      fatal), or --warn-only
#   1  an artifact is past budget + grace, or input unreadable

set -u

BPT="${AI_DLC_BYTES_PER_TOKEN:-4}"
GRACE_PCT="${AI_DLC_BUDGET_GRACE_PCT:-10}"
# --- AI_DLC_ROOT ------------------------------------------------------------
# Resolve the project root by walking UP for a marker, never by a fixed number of
# `..` hops. This script runs from three layouts:
#   <root>/core/scripts/X      distribution
#   <root>/scripts/ai-dlc/X    consumer, v0.126.0+
#   <root>/scripts/X           consumer, pre-v0.126.0
# and no fixed hop count fits all three. v0.126.0 moved the validators one level
# deeper, which silently turned every `dirname $0/..` root into <root>/scripts:
# this script then found no docs/retro/, printed "Scanned 0 retros, 0 gates
# declared, 0 dormant" and exited 0 — a check that could no longer fire, reading
# exactly like one that passed.
# Inline on purpose, in every script that needs it: a shared lib cannot fix this,
# because locating the lib is the same unsolved problem. Duplication is correct
# here. core/fixtures/validator-path-resolution asserts both layouts agree.
ai_dlc_resolve_root() {
  local d="$1"
  while [ -n "$d" ] && [ "$d" != "/" ] && [ "$d" != "." ]; do
    if [ -e "$d/.git" ] || [ -d "$d/.claude" ] || [ -d "$d/core/skills/ai-dlc" ]; then
      printf '%s\n' "$d"; return 0
    fi
    d="$(dirname "$d")"
  done
  return 1
}
AI_DLC_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AI_DLC_ROOT="${AI_DLC_PROJECT_ROOT:-}"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="$(ai_dlc_resolve_root "$AI_DLC_SELF_DIR" || true)"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="${CLAUDE_PROJECT_DIR:-}"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="$(ai_dlc_resolve_root "$(pwd)" || true)"
[ -n "$AI_DLC_ROOT" ] || {
  echo "ERROR: cannot resolve the project root from ${AI_DLC_SELF_DIR} (no .git or" >&2
  echo "  .claude/ marker in any parent). Set AI_DLC_PROJECT_ROOT to the repo root." >&2
  exit 2
}
# --- end AI_DLC_ROOT --------------------------------------------------------

ROOT="$AI_DLC_ROOT"
ONLY=""
WARN_ONLY=0
QUIET=0
CHECK_EVIDENCE=0
GATE_LOG=""
FAIL_ON=""

while [ $# -gt 0 ]; do
  case "$1" in
    --root)           ROOT="${2:-}"; shift 2 ;;
    --only)           ONLY="${2:-}"; shift 2 ;;
    # --fail-on <artifact>: take a HARD verdict on ONE artifact while the run stays
    # --warn-only overall. Retro needs exactly this and had no way to say it.
    #
    # WHY THE POSTURE IS PER-ARTIFACT RATHER THAN PER-RUN. Retro's budget audit is
    # --warn-only for a stated reason: the sprint has already paid for every oversized
    # read, so blocking at retro helps nobody. That reasoning is about the PLANNING
    # artifacts, whose growth is monotonic by construction. It does not transfer to
    # `pipeline-snapshot.md`, which is trimmable by design -- its remedy is to move
    # superseded entries to the write-only history file, an action available at retro
    # and nowhere else. A ceiling nobody is ever blocked by is a number, not a ceiling.
    #
    # Repeatable. `--fail-on a --fail-on b` hardens both.
    --fail-on)        FAIL_ON="$FAIL_ON ${2:-}"; shift 2 ;;
    --warn-only)      WARN_ONLY=1; shift ;;
    --quiet)          QUIET=1; shift ;;
    --check-evidence) CHECK_EVIDENCE=1; shift ;;
    --gate-log)       GATE_LOG="${2:-}"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 1 ;;
  esac
done

say() { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }

# Is this artifact one the caller hardened with --fail-on? Matched on BASENAME, so
# `--fail-on pipeline-snapshot.md` hardens it wherever under the root it sits.
#
# The leading/trailing spaces are load-bearing: without them `--fail-on snapshot.md`
# would match `pipeline-snapshot.md` and harden an artifact the operator did not name.
is_fail_on() {
  case " $FAIL_ON " in
    *" $(basename "$1") "*) return 0 ;;
    *) return 1 ;;
  esac
}

# The verdict posture for ONE artifact: hard when --fail-on names it, otherwise
# whatever --warn-only says. Returns 0 when a breach must set RC=1.
hard_verdict() {
  is_fail_on "$1" && return 0
  [ "$WARN_ONLY" -eq 1 ] && return 1
  return 0
}

[ -d "$ROOT" ] || { echo "FAIL: project root not readable: $ROOT" >&2; exit 1; }

# =============================================================================
# THE PLANNING-ARTIFACT BUDGET IS DERIVED. HERE IS THE DERIVATION.
# =============================================================================
#
# The four planning artifacts used to carry per-file budgets of
# 60000/60000/40000/60000 tokens. Those numbers had NO derivation: no ADR, no
# measurement, no named reader. They were a bash literal with a per-artifact env
# override -- and a physical limit does not ship with an override flag. Asked "is
# 60K a true hard line?", nobody could say. The honest answer was no.
#
# That mattered, because the gate they back is a HARD_BLOCK at sprint start
# (route.md Step 1a) over artifacts holding LOCKED requirements (Rule 13) that no
# rule retires. Growth is monotonic by construction, so those constants made the
# gate eventually unpassable -- and the standing remedy was to relocate locked
# requirements in order to satisfy a number nobody derived. In the reference
# consumer that relocation ran at S242, S247 and S274; it grew back every time.
#
# So: derive it from the only thing that is actually physical -- the reader.
#
#   WHO WHOLE-READS THEM. Exactly one agent. carry-over-evaluation.md section 1
#   (Rule 25(b)) reads carry-over-backlog.md, docs/architecture.md,
#   product-brief.md and prd.md IN FULL into a single Rule-24 analyst subagent.
#   No other step whole-reads them; the lead only ever slice-reads. So the
#   quantity that binds is the SUM of the four against ONE context window -- not
#   four separate per-file limits, which bounded nothing real.
#
#   THE WINDOW IS RESOLVED, NOT ASSUMED. See resolve_reader_window() below. The
#   reference consumer derived this same pool with the window written in as
#   1,000,000 and a comment telling a human "if that model line changes, THIS
#   NUMBER CHANGES. Re-derive; do not inherit." Core cannot execute an
#   instruction to a human, and the number is not core's to inherit: core ships
#   team-roles/analyst.md naming a model KEY, and the consumer's `aiDlcModels`
#   block maps that key to whatever model this project runs -- so the window is a
#   per-project fact core cannot know. Shipping 1,000,000 to every consumer would hand a
#   200K-window analyst a pool 1.65x its entire context -- a fail-open at a
#   HARD_BLOCK, on exactly the gate that exists to prevent the analyst blowing
#   its window one step later.
#
#   THE SHARE. The analyst does not only read these four files. It also reads the
#   carry-over items in detail, docs/escalations/pending.md, the last retro, git
#   history and source, plus its own tool output -- and it must have room left to
#   reason and to write its draft. Giving the four artifacts ONE THIRD of the
#   window and leaving two thirds for everything else is the one judgement call in
#   this derivation, and it is stated here rather than hidden in a constant.
#
#   WHOLE_READ_POOL = <resolved window> * 33%, for all four combined.
#
# This is a SUBTRACTION: four underived constants -> one derived one. It is also
# still a real gate, not a rubber stamp. At the sprint that first derived it the
# four artifacts summed to 324,037 tokens against a 330,000 pool -- 98%, inside
# the grace band and warning. It binds today.
#
# WHAT IT DOES NOT FIX. The pool does not stop the ratchet, it only prices it
# honestly. Rule 13 locks requirements and nothing retires them, so the sum can
# only rise. The real cure is a RETIREMENT PATH for locked requirements. Raising
# the pool again, or overriding it below, instead of building one, is the failure
# this comment exists to make visible.
# -----------------------------------------------------------------------------
WHOLE_READ_SET="prd.md product-brief.md architecture.md carry-over-backlog.md"

# Whole-read artifacts that live in the CURRENT SPRINT'S SLOT rather than at an area
# root, and are pooled from there.
#
# THIS ARM EXISTS BECAUSE THE CHANGE THAT NEEDED IT WOULD OTHERWISE HAVE GRADED ITSELF.
# is_sprint_slotted() below exempts every `s<N>/` path from the pool, and it is right to
# for the four basenames above: a slot copy of `architecture.md` is that sprint's
# archive, and counting it is the 2.35x overstatement v0.317.0 fixed. But
# `discovery.md` §4a now writes the sprint's LOCKED_REQUIREMENTS block to
# `s<N>/locked-requirements.md`, and the analyst reads that block whole every sprint.
# Left to the exemption, moving 54% of the reference consumer's brief into the slot
# would have dropped the pooled sum by three quarters of that artifact with the same
# bytes still read -- a row going green for a reason unrelated to anything getting
# smaller.
#
# ONLY THE LIVE SPRINT'S COPY IS POOLED. Every earlier sprint's block is a closed
# record nothing reads whole, so the resolution below asks `sprint-status.sh sprint-id`
# rather than globbing `s*/`. A glob would sum every sprint that ever ran, which is the
# same defect one level along.
SPRINT_WHOLE_READ_SET="locked-requirements.md"

# The analyst's context window, resolved through `aiDlcRoles.analyst` -> `aiDlcModels`
# in the consumer's settings.json. `[1m]` is Claude Code's own suffix for the
# 1M-context variant, which is why it is the token matched rather than a model-name
# table -- a name table is a hand-maintained list that goes stale silently, and the
# suffix is the thing that actually selects the window.
#
# THIS FUNCTION USED TO GREP THE ROLE FILE FOR `^- Personal:`, AND THAT LINE HAS NOT
# EXISTED SINCE v0.174.0. It shipped at v0.124.0, when role files carried
# `- Personal: /model {analyst_model_personal}` filled in by setup. v0.174.0
# (`989939a`, "model strings move to one consumer-owned config block") deleted the
# line and v0.175.0 finished the move -- fifty releases before anyone read this
# function again. Controlled at the time this was fixed: `^- Personal:` matched
# NOTHING under core/team-roles/ (control: `^- ` bullets in every role file), `[1m]`
# matched nothing there either, and the ONLY occurrence of the string `Personal:` in
# core/, templates/, scripts/ and install.sh combined was the grep on this line.
#
# So the `1000000` arm was unreachable on every consumer, and every consumer had been
# silently taking the `200000` fallback -- the branch this derivation deliberately
# made the TIGHTENING default for the UNKNOWN case, used instead as the only reachable
# one. Measured on the reference consumer: its analyst resolves to `claude-sonnet-5[1m]`
# through the config block, a 330,000 pool, and the validator was reporting 66,000 and
# a 417% breach.
#
# The comment two paragraphs up already named `aiDlcModels` as the source of truth; the
# code simply never read it. The resolution idiom below is the one
# `core/hooks/ai-dlc-dispatch-guard.sh:203-205` already uses, deliberately, rather than
# a second reading of the same config.
#
# UNRESOLVED FALLS BACK TO 200000, NEVER TO THE LARGER NUMBER. No settings.json, no
# jq, no `aiDlcRoles.analyst`, a key absent from `aiDlcModels`, and an unrecognised
# model string all mean the same thing: we do not know. 200K is the standard window and
# the value the context sensor already defaults to (`*) MODEL_MAX=200000`), so the
# unknown case tightens the gate rather than opening it. A consumer whose analyst
# genuinely has more room sets AI_DLC_READER_WINDOW_TOKENS -- and unlike the four
# constants this replaces, the number being overridden has a derivation to argue
# against.
#
# THE FAILURE MODES ARE NOT SYMMETRIC, which is why the unknown case is stated five
# times rather than once. Resolving unknown to 1M is a fail-open at a HARD_BLOCK, on
# the very gate that exists to stop the analyst blowing its window one step later.
# Resolving a genuine 1M consumer to 200K -- what this function did for fifty releases
# -- is a gate that cannot be passed, which is the inert-mechanism class and trains the
# operator to ignore the row. Both are defects; only one is safe to guess.
resolve_reader_window() {
  settings="$ROOT/.claude/settings.json"
  [ -r "$settings" ] || { printf '200000'; return; }
  command -v jq >/dev/null 2>&1 || { printf '200000'; return; }
  rrw_key="$(jq -r '.aiDlcRoles.analyst.model // empty' "$settings" 2>/dev/null || true)"
  [ -n "$rrw_key" ] || { printf '200000'; return; }
  rrw_model="$(jq -r --arg k "$rrw_key" '.aiDlcModels[$k] // empty' "$settings" 2>/dev/null || true)"
  case "$rrw_model" in
    *'[1m]'*) printf '1000000' ;;
    *)        printf '200000' ;;
  esac
}

if [ -n "${AI_DLC_READER_WINDOW_TOKENS:-}" ]; then
  READER_WINDOW_TOKENS="$AI_DLC_READER_WINDOW_TOKENS"
  WINDOW_SOURCE="AI_DLC_READER_WINDOW_TOKENS"
else
  READER_WINDOW_TOKENS="$(resolve_reader_window)"
  WINDOW_SOURCE=".claude/settings.json aiDlcRoles.analyst"
fi
ARTIFACT_SHARE_PCT="${AI_DLC_ARTIFACT_SHARE_PCT:-33}"
WHOLE_READ_POOL=$(( READER_WINDOW_TOKENS * ARTIFACT_SHARE_PCT / 100 ))

# -----------------------------------------------------------------------------
# The per-file Rule 25(d) budgets. Format: basename|tokens|remedy
#
# These are the artifacts the LEAD reads, not the analyst -- a different reader
# and a different constraint, so they stay per-file. They are bounded by rotation
# and trimming, which are mechanical and lossless; unlike consolidation, neither
# can drop a locked requirement, so a wrong number here costs minutes, not
# fidelity. The four whole-read planning artifacts are NOT in this table; they are
# bounded as a sum by the pool above.
#
# remedy is the BOUNDING MECHANISM for that artifact's class, not a generic
# "make it smaller" -- the remedies are genuinely different and applying the
# wrong one destroys data:
#
#   consolidate  living planning artifact -> the one-shot, operator-invoked,
#                fidelity-critical rewrite (artifact-consolidation.md). Rule 25(a)
#                moves superseded content to *-history.md; nothing is dropped.
#   rotate       append-only log -> move the epoch to
#                implementation-artifacts/s<N>/<basename>-archive.md (Rule 25(c),
#                destination owned by artifact-path-grammar.md). NOT a dated name:
#                the directory is the only sprint slot and no basename carries a
#                sprint token. A second rotation into one slot appends an ordinal.
#                COVERAGE OF THAT ORDINAL IS NOT GENERAL, so do not assume it:
#                is_archive() below and ai-dlc-protect.sh carry both spellings,
#                report-propagation-fanout.sh's FROZEN_NAME_GLOBS had only the
#                plain one until v0.471.0, and a consumer path-set exemption keyed
#                on `-archive.md$` still drops an ordinal rotation out of its
#                exemption. Widening a reader to `-archive(-[0-9]+)?\.md` is the
#                fix; assuming it already reads that way is how this was missed.
#                A live log over threshold means a rotation was MISSED, not that it
#                needs a rewrite. artifact-consolidation.md rejects logs as targets.
#                audit-anchors.md is in this class and is the reason the class needed
#                a completeness check: it is read EVERY sprint (carry-over-evaluation
#                Step 1a, gate Check 18) but only ONE entry deep, and it sat in
#                neither this table nor is_archive() for 120 sprints. Ungoverned is
#                not the same as unrotated -- nothing measured it, so nothing could
#                report it. retro.md Step 5b prunes it to the 3 most recent entries.
#   trim         pipeline-snapshot.md -> MOVE superseded content verbatim to
#                pipeline-snapshot-history.md (write-only, Rule 25(a)), THEN delete
#                it from the live file. Check 14 owns the schema. It is SEVEN
#                sections since v0.50.0 -- In-Flight Teammates is one of them, and
#                it is the ledger that stops the lead re-dispatching live teammates.
#                Do not delete it. Never consolidation. A snapshot over threshold
#                means the schema stopped being enforced at gate passages, and the
#                gates that let it grow are the finding -- not the file.
#
#                THE DESTINATION IS THE LOAD-BEARING WORD, and this arm did not
#                carry one. Its two siblings above both name where the bytes go;
#                only this one said what to make the file, never what to do with
#                what came out. A lead holding a post-compaction rule set -- which
#                is Rules 1-13, so NOT Rule 25(a) -- has this string as its only
#                instruction, and an instruction to shrink a file with nowhere to
#                put the content is an instruction to delete it.
#
#                Measured in the reference consumer across one sprint: of 2,524
#                substantive lines deleted from the snapshot, 2,141 (84%) are
#                absent from the repository entirely -- gate dispositions, operator
#                override citations and adversarial verdicts. 69 of the 70 commits
#                touching the file destroyed at least one line. The history file is
#                not the problem: 17 commits touch it and NONE deletes a line.
#                Append-only holds. Coverage is what fails, and it fails because
#                this string never asked for any.
# -----------------------------------------------------------------------------
BUDGETS="
gate-log.md|25000|rotate
compaction-log.md|10000|rotate
pipeline-continuation-log.md|10000|rotate
context-mode-protection-log.md|10000|rotate
audit-anchors.md|4000|rotate
pipeline-snapshot.md|6000|trim
"

# Rule 25(a): history/archive files are write-only and their growth is free.
# Measuring them would flag a 2.6 MB product-brief-history.md that costs nothing
# and whose whole job is to BE big so the live file is not.
#
# ONE OF THEM IS NOT FREE, AND THIS EXEMPTION IS WHY NOBODY NOTICED.
# `pipeline-snapshot-history.md` is fed by the `trim` remedy at every GATE, not at a
# sprint close, and it matches `*-history.md` -- so it is skipped here, before any
# measurement, and no sweep in this file has ever reported a number for it. Measured on
# the reference consumer: 87 KB -> 617 KB in four weeks, 29 commits, all `del=0`. It is
# now bounded by `rotate-snapshot-archive.sh`, which moves the old part to
# `pipeline-history/pipeline-snapshot-archive.md`. BOTH names match the arms below, which
# is deliberate: the live file stays exempt from measurement and the rotator is what
# bounds it. Rule 25(a) in SKILL.md carries the full statement.
#
# THE DOT GRAMMAR IS RETIRED RATHER THAN ADMITTED. `*.archive.*` is matched by
# ai-dlc-protect.sh's EXCLUDED_PATTERNS and NOT by this predicate, which is how 158 dated
# `pipeline-snapshot.archive.<ISO>.md` files on the reference consumer stayed invisible to
# this sweep. Widening this list was the obvious fix and is the wrong one: the two lists
# live in different install layouts (`core/scripts/` -> `scripts/ai-dlc/`, `core/hooks/` ->
# `.claude/hooks/`), so a shared predicate is the cross-file walk I33 fails the build on,
# and the hook runs on EVERY tool call where a `source` is a per-call cost. The gap is
# closed at the producer instead: route.md no longer mints the dot form.
is_archive() {
  case "$1" in
    *-history.md|*-archive.md|*-archive-*.md|*.precompact.md) return 0 ;;
    *) return 1 ;;
  esac
}

# A copy under the artifact-path grammar's reserved `s<N>/` slot is that sprint's
# ARCHIVED artifact, not the live one, and the whole-read pool must not sum it.
#
# THIS IS A MIGRATION-INDUCED REGRESSION, and the sweep was correct before it.
# Every historical copy used to carry a per-sprint BASENAME (`architecture-s251.md`),
# which the pool's `find -name architecture.md` could not match. Item 10's migration
# moved them all to `s251/architecture.md` -- the live basename -- and the same search
# started counting every one of them.
#
# Measured on the reference consumer when this shipped: 30 files summed under a label
# reading "(4 planning artifacts)" -- 23 per-sprint `architecture.md` archives, 3
# party-mode transcript copies, 4 live. 275,812 tok reported against 117,379 live, a
# 2.35x overstatement that reported OVER on a consumer sitting at 36% of its pool.
# ALL 26 spurious rows carried an `s<N>` component; one rule excludes all of them.
#
# `s[0-9]+` matched against a whole path COMPONENT is the grammar's own spelling of
# the slot (validate-artifact-paths.sh:167,241), reused rather than re-invented. It is
# a component match and not a substring, so `s301-close-out/` is not a slot; and the
# FILENAME is dropped before the search, because a file is never a slot.
is_sprint_slotted() {
  case "$1" in
    */*) ;;
    *)   return 1 ;;
  esac
  printf '%s\n' "${1%/*}" | tr '/' '\n' | grep -qxE 's[0-9]+'
}

# Not a live artifact, however it is named. `architecture.md` is the trap: the
# ai-dlc STEP FILE is also called architecture.md, so a bare basename search finds
# the skill's own source under .claude/skills/ and under every pre-ai-dlc snapshot
# the consumer has ever taken. Measuring a step file against an artifact budget is
# a category error -- it would pass, silently, and teach us nothing.
is_not_artifact() {
  case "$1" in
    */.claude/*|*/pre-ai-dlc/*|*/_divergence/*|*/node_modules/*|*/.git/*) return 0 ;;
    *) return 1 ;;
  esac
}

# -----------------------------------------------------------------------------
# THE SNAPSHOT'S SEVEN-SECTION SCHEMA (gate-validation.md Check 14 owns it).
#
# Check 14 enumerates seven sections to REFRESH. It never said "and no others,"
# and nothing counted them -- so the schema was a REQUIRED-set, not a CLOSED-set.
# An eighth section was invisible to every check until total BYTES breached, and
# by then the remedy text below was pointing at a schema nothing could evaluate.
#
# Measured in the reference consumer at sprint 296, mid-sprint: the snapshot held
# TEN `## ` sections at 141% of budget. Three were lead invention that no hook, no
# step and no script writes -- `Teammate Ledger (detail)` (5.7 KB), `Discovery
# phase -- CLOSED` (1.9 KB), `Post-compact recovery log` (1.4 KB): 9.0 KB of 34 KB,
# accumulated between gates, undetectable until the byte budget finally tripped.
#
# PREFIX match, not exact. `## In-Flight Teammates (none)` is that section wearing
# a decoration, and failing it would be noise -- and noisy gates get ignored (see
# "WARN AT 100%" above; same reasoning). `## Teammate Ledger (detail)` is not a
# decoration of anything, and fails.
#
# CLOSED-set ONLY -- this deliberately does NOT require all seven to be PRESENT.
# A snapshot is legitimately under-populated between route.md Step 0 and the first
# gate, and this script runs on the BLOCKING sub-step path (_gate-procedures.md
# "Sub-step snapshot update" step 5, "Exit 1 -> TRIM NOW"). A presence rule there
# would stall a pipeline over a snapshot that is merely young. ABSENCE is Check
# 14's to judge, against a snapshot it has just written. INVENTION is this
# script's: it is never legitimate, at any age.
# -----------------------------------------------------------------------------
# THE SEVEN ARE DATA, WRITTEN ONCE, AND THREE READERS LOAD THEM.
# `is_canonical_section` asks "may this heading be here at all" (the seven PLUS a
# project's declared additions). `is_core_section` asks the smaller question, "is
# this one of core's own seven", which the entry-shape arm below needs because core
# does not know what belongs under a name core does not define. The entry-shape arm
# is an awk program and cannot call a shell function, so it takes the same string by
# `-v`. A case list written three times is two chances to drift; this is one string.
# The names are newline-delimited and matched as a PREFIX, exactly as before:
# `## In-Flight Teammates (none)` is that section wearing a decoration.
CORE_SECTIONS='Pipeline Position
Sprint Context
Recent Activity
Open Items
Locked Decisions
In-Flight Teammates
Context Reminders'

# The one of the seven that a dated activity entry BELONGS under. Named once, and
# read by the entry-shape arm and by its remedy text, so the arm and the remedy
# cannot come to name different sections.
ACTIVITY_SECTION='Recent Activity'

is_core_section() {
  local want
  while IFS= read -r want; do
    [ -n "$want" ] || continue
    case "$1" in "$want"*) return 0 ;; esac
  done <<EOF
$CORE_SECTIONS
EOF
  return 1
}

is_canonical_section() {
  is_core_section "$1" && return 0

  # PROJECT-DECLARED ADDITIONS -- data, not a case list, so a consumer whose snapshot
  # legitimately carries an eighth section does not have to shadow the whole rule to
  # say so. The reference consumer did exactly that: it wrote an override replacing
  # Check 14 IN FULL to widen the set, recorded in its own text that this "does not
  # unblock the validator" because the set is a hardcoded case statement, and asked
  # for the list to become data. Restating a whole section to change one clause also
  # freezes every other line in it at the override's base_sha, which is how a later
  # core fix to an unrelated line in the same section stopped reaching that consumer.
  #
  # THIS IS A DECLARATION, NOT A LOOPHOLE, and the distinction is the whole design.
  # The closed set exists because a lead invented three sections mid-sprint that no
  # hook, step or script writes, and they grew 9 KB between gates on the artifact that
  # is whole-read at every gate. A lead inventing a section at runtime cannot set the
  # project's configuration; a project declaring one has stated it on the record. So
  # the defect the closed set catches is still caught, and only the declared name is
  # admitted.
  [ -n "${AI_DLC_SNAPSHOT_EXTRA_SECTIONS:-}" ] || return 1
  local want
  while IFS= read -r want; do
    want="${want#"${want%%[![:space:]]*}"}"; want="${want%"${want##*[![:space:]]}"}"
    [ -n "$want" ] || continue
    case "$1" in "$want"*) return 0 ;; esac
  done <<< "$(printf '%s' "${AI_DLC_SNAPSHOT_EXTRA_SECTIONS}" | tr ',' '\n')"
  return 1
}

# $1 = file path, $2 = path relative to ROOT (for the message)
# SUPERSESSION-BY-MARKING. Superseded content belongs in the write-only history file,
# physically MOVED there -- not struck through, bracketed, or stamped in place. Marked
# content passes every check that already exists: it sits under a canonical heading, so
# the seven-section schema check is happy, and it costs bytes like any other prose, so
# the budget only notices once the file is already too big. The trim remedy then reads
# as "delete text" when the correct action is "relocate text", and the deletion loses
# the record the history file exists to keep.
#
# SCOPED OUTSIDE `## In-Flight Teammates` DELIBERATELY. That section is the dispatch
# ledger and `check_inflight_rows` already greps `~~` inside it; its row schema owns the
# status column. Scoping this arm out of that section means a struck In-Flight row is
# reported ONCE, by the check that owns it, rather than twice under two remedies.
#
# CASING IS THE DISCRIMINATOR, ON PURPOSE, AND THIS IS THE WHOLE FALSE-POSITIVE STORY.
# All-caps SUPERSEDED is the deliberate status stamp. Lowercase "superseded" is ordinary
# English -- "superseded by the short form" -- and appears many times per snapshot
# legitimately; flagging it would red every clean retro run, which is the
# safeguard-that-blocks-throughput failure. The one all-caps exception is the compound
# category label `WONTFIX/SUPERSEDED`, a CLASS of backlog item rather than a mark on this
# content, and the `/`-adjacency guard excludes it.
#
# BARE STRIKETHROUGH IS NOT IN THE DEFAULT SET, AND THAT IS A DECISION WITH A FIXTURE
# BEHIND IT. `inflight-row-shape` asserts that a `~~struck~~` line outside the dispatch
# ledger is out of scope, on the reasoning that Recent Activity LEGITIMATELY strikes
# superseded entries and indicting them would make the check noise. That position is
# core's and it is correct as a default: `~~` is ordinary markdown emphasis, whereas an
# all-caps SUPERSEDED stamp is unambiguously a status claim. A project that has decided
# strikethrough is never legitimate in its snapshot sets
# `AI_DLC_SNAPSHOT_STRIKETHROUGH=forbid` and gets the stricter arm; the default `allow`
# leaves core's documented position untouched.
STRIKETHROUGH_POSTURE="${AI_DLC_SNAPSHOT_STRIKETHROUGH:-allow}"
case "$STRIKETHROUGH_POSTURE" in
  allow|forbid) ;;
  *) echo "FAIL: AI_DLC_SNAPSHOT_STRIKETHROUGH must be 'allow' or 'forbid', got '$STRIKETHROUGH_POSTURE'" >&2; exit 2 ;;
esac

check_supersession_markers() {
  awk -v strike="$STRIKETHROUGH_POSTURE" '
    /^## In-Flight Teammates/ { inflight=1; next }
    /^## /                    { inflight=0 }
    {
      if (inflight) next
      cls=""
      if (strike == "forbid" && $0 ~ /~~[^~]*~~/)  cls = cls "strikethrough(~~...~~); "
      if ($0 ~ /\*\*\[[^]]*SUPERSEDED[^]]*\]\*\*/) cls = cls "bracket-annotation(**[...SUPERSEDED...]**); "
      else if ($0 ~ /(^|[^A-Za-z0-9\/])SUPERSEDED([^A-Za-z0-9\/]|$)/) cls = cls "bare-status-word(SUPERSEDED); "
      if (cls != "") printf "  %s line %d: supersession marker [%s]\n", ART, NR, cls
    }
  ' ART="$2" "$1" >> "$MARKER_FILE"
}

check_snapshot_sections() {
  grep '^## ' "$1" 2>/dev/null \
    | sed -e 's/^##[[:space:]]*//' -e 's/[[:space:]]*$//' \
    | while IFS= read -r heading; do
        [ -n "$heading" ] || continue
        is_canonical_section "$heading" && continue
        printf 'SCHEMA  %-32s unknown section: ## %s\n' "$2" "$heading" >> "$SCHEMA_FILE"
      done
}

# -----------------------------------------------------------------------------
# A DATED ACTIVITY ENTRY BELONGS UNDER `Recent Activity`, AND ONLY THE HEADINGS
# WERE EVER CHECKED.
#
# The seven-section schema above is a CLOSED SET OF HEADINGS. Nothing reads what
# sits UNDER one. `_gate-procedures.md` "Sub-step snapshot update" tells the writer
# to append a timestamped one-line entry to `Recent Activity`; `route.md` Check 3
# reads headings only. So a dated activity entry filed under `## Sprint Context`
# satisfies every check that exists: the heading is canonical, the bytes are priced
# like any other prose, and the recovery path that whole-reads the snapshot reads
# the misfile as sprint context. The section that is supposed to be the activity
# log stops holding the activity, and nothing anywhere says so.
#
# WARN, NEVER A FAIL, AND NOT IN RC. This script runs on the BLOCKING sub-step path
# (`_gate-procedures.md` step 5, "Exit 1 -> TRIM NOW"). A misfiled line is a filing
# error a lead fixes by MOVING one line; wedging a gate over it is the
# safeguard-that-blocks-throughput failure the grace band and the coverage WARN
# above both already avoid. It is also why this is not folded into the SCHEMA
# verdict: that one says DELETE the section, this one says MOVE the line, and a
# lead reading the wrong remedy deletes a canonical section.
#
# THE FALSE-POSITIVE SET IS ZERO, AND HERE IS THE NARROWING THAT GOT IT THERE.
# Measured over all 514 revisions of `_bmad-output/pipeline-snapshot.md` on the
# reference consumer's first-parent history, by section, revisions carrying >=1
# matching line:
#
#   grammar                                   RecentAct  InFlight  SprintCtx  CtxRem  PipelinePos
#   no leading anchor (substring "T##:##")        343        80        18       76       396
#   leading anchor, bullet OPTIONAL               239         8         1        1         0
#   leading anchor, bullet REQUIRED               239         0         1        1         0
#   + optional ` and ** after the bullet          249         0         1        1         0   <- shipped
#
# THE LEADING ANCHOR is what excludes `Pipeline Position`, whose rows legitimately
# carry a timestamp MID-line (`last_gate_passed: ... 2026-09-12T22:14:00Z`) on 396
# of the 514. Without it this arm indicts 77% of the corpus and is noise.
#
# THE LEADING ANCHOR IS ALSO STRICT ABOUT INDENT, and that is a second measurement.
# Allowing `^[[:blank:]]*` before the bullet adds 178 lines across the corpus --
# Pipeline Position 58, Locked Decisions 45, Context Reminders 12, Open Items 10 --
# and every one is a soft-wrapped continuation whose predecessor line is non-empty.
# A continuation is not an entry. The bullet must sit at column 1.
#
# THE REQUIRED BULLET is what excludes `In-Flight Teammates`, and the reason is
# SOFT-WRAP, not that section's row schema. Its 8 hits are ONE line (`ff5920ff3:151`,
# whose predecessor ends mid-sentence): a WRAPPED PROSE CONTINUATION inside that
# section's parenthetical note --
# `2026-09-09T14:05:45Z; \`dev-s309-review-fixforward\` (sonnet) delivered ...`,
# the second line of a sentence that began on the line above. It is not an entry
# and it is not a misfile; a grammar that indicts it indicts reflowed prose
# everywhere. Requiring the bullet takes In-Flight to 0 and leaves the two real
# misfiles standing, so In-Flight is NOT exempted by section -- it is excluded by
# the grammar, and a genuinely bulleted dated entry there is still reported.
#
# The optional backtick and `**` after the bullet are the consumer's own two
# decorations of a legitimate entry, added because a grammar that misses them
# misses the offender wearing them; they cost nothing outside `Recent Activity`
# (both columns stay at 1 and 0 above).
#
# THE TWO SURVIVORS ARE BOTH REAL MISFILES, inspected individually: `66d0eb165`
# carries 29 dated entries under `## Sprint Context` and `580f156cc` carries 7
# under `## Context Reminders`. Neither section's schema has anything to do with a
# dated log line. The false-positive set is therefore EMPTY over the corpus, and
# the finding set is 2 of 514.
#
# DECLARED EXTRA SECTIONS ARE OUT OF SCOPE. A project that declares a section under
# `AI_DLC_SNAPSHOT_EXTRA_SECTIONS` owns its shape; core does not know what belongs
# under a name core does not define. `is_core_section` is the predicate, not
# `is_canonical_section`, and that is the whole difference between the two.
# -----------------------------------------------------------------------------
check_snapshot_entry_shape() {
  # THE LIST CROSSES INTO awk THROUGH THE ENVIRONMENT, NOT THROUGH `-v`.
  # `awk -v` carries no newline at all: the newline-delimited list arrives as a
  # literal backslash-n or aborts with "newline in string", depending on the awk.
  # `ENVIRON` passes the bytes through intact and needs no escaping of the data,
  # which is the property that matters for a list a project can never edit but a
  # future author might extend with a name carrying punctuation.
  # `LC_ALL=C` for the same reason the reader below carries it: snapshot prose is
  # full of em-dashes and arrows, and a BSD tool that decodes them can abort
  # mid-file having already printed a partial answer.
  LC_ALL=C CORE_SECTIONS="$CORE_SECTIONS" awk -v HOME_SECTION="$ACTIVITY_SECTION" '
    BEGIN { n = split(ENVIRON["CORE_SECTIONS"], S, "\n") }
    /^## / {
      sec=$0; sub(/^##[[:space:]]*/,"",sec); sub(/[[:space:]]*$/,"",sec)
      core=0
      # PREFIX membership by substr() on LITERAL strings, never a regex built by
      # concatenation: a section name carrying a `.` or a `(` is a metacharacter in
      # a dynamic regex, and escaping a data list is the shape that has shipped
      # wrong here before.
      for (i=1; i<=n; i++)
        if (S[i] != "" && substr(sec, 1, length(S[i])) == S[i]) core=1
      # The activity log is the section this line BELONGS to; never report it there.
      if (substr(sec, 1, length(HOME_SECTION)) == HOME_SECTION) core=0
      next
    }
    core {
      # Anchored at column 1: a bullet, then the entry, optionally wearing one
      # backtick and/or bold. A timestamp anywhere else on the line is Pipeline
      # Position row data or reflowed prose and is not an entry.
      if ($0 !~ /^([-*]|[0-9]+\.)[[:blank:]]+/) next
      p=$0
      sub(/^([-*]|[0-9]+\.)[[:blank:]]+/,"",p)
      sub(/^`/,"",p); sub(/^\*\*/,"",p); sub(/^`/,"",p)
      if (p !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]/) next
      # THE DETAIL LINE OPENS WITH `misfiled`, AND THAT IS A CONTRACT WITH verdict.sh.
      # NO APOSTROPHE MAY APPEAR IN THIS COMMENT: the awk program is single-quoted
      # and one closes it, which bash then reports as a syntax error 20 lines away.
      # verdict.sh:122 surfaces at most AI_DLC_VERDICT_LINES (6) lines matching
      # ^[[:space:]]*(ok|warn|OK:|PASS|WARN|OVER) after PASS <name>, and that window
      # is what the Check 14 evidence cell pastes. One WARN per misfiled line would
      # fill it -- the reference consumer has a revision carrying 29 of them -- and
      # push the budget summary line out of the verdict entirely. So this arm emits
      # exactly ONE matching line per artifact, aggregated, and every detail line
      # below it is deliberately unmatchable by that grammar.
      # The leading `SEC<tab>` field is what the aggregate line below counts by
      # section; it is stripped before the detail is printed. Deriving the tally
      # from this channel rather than from a second awk pass means the count and
      # the rows can never disagree -- they are the same records.
      printf "SEC\t%s\t      misfiled  %s line %d: dated entry under ## %s -- %s\n", sec, ART, NR, sec, substr($0,1,60)
    }
  ' ART="$2" "$1" >> "$ENTRY_FILE"
}

# -----------------------------------------------------------------------------
# IN-FLIGHT TEAMMATES: ROWS ONLY, NEVER STRUCK.
#
# gate-validation.md and _gate-procedures.md both say a row is DELETED at join
# and that the section carries "no struck-through history". Two other core files
# said the opposite -- route.md, which is the file that CREATES the section and so
# is the schema a lead reads first, and implementation.md -- both saying rows are
# "struck at join". Core contradicted itself two homes to two; the contradiction
# is removed in the same change as this check.
#
# Measured in the reference consumer at sprint 296: the section held 7
# struck-through consumed rows and 302 lines of prose, 29.7 KB -- 28% of a
# snapshot at 446% of budget, inside a canonical section where v0.118.0's
# closed-set check cannot see it. That is the `Teammate Ledger (detail)` v0.118.0
# deleted as an invented section, re-grown in a legal home.
#
# STRIKETHROUGH ONLY, NOT A PROSE-LINE CAP. Measured across 25 historical
# snapshots in that consumer: zero struck rows in all 25, seven in the live file
# -- one true positive, no false positives, and no threshold to fit. A prose-line
# cap was measured too and dropped: every one of the 25 carries some In-Flight
# prose (1-8 lines saying what is outstanding), so the cap would need a constant
# tuned to sit between them and the violations, and a fitted constant is the
# mistake this file's own budget table had to unwind once already. The prose is
# priced by the byte budget, which is the thing bytes are for; the reason it was
# written is removed by the row schema's `status` column.
# -----------------------------------------------------------------------------
check_inflight_rows() {
  awk '/^## In-Flight Teammates/{f=1;next} /^## /{f=0} f && /~~/{print}' "$1" 2>/dev/null \
    | while IFS= read -r line; do
        printf 'INFLIGHT  %-30s struck row: %s\n' "$2" "$(printf '%s' "$line" | cut -c1-70)" \
          >> "$INFLIGHT_FILE"
      done
}

# -----------------------------------------------------------------------------
# IN-FLIGHT TEAMMATES: THE STATUS TOKEN IS A CLOSED SET OF THREE.
#
# The column carries one of three facts and no fourth: the teammate has not
# delivered (`in-flight`), it has delivered and the lead can still reach it
# (`delivered-reachable`), or it was STOPPED before delivering and will not be
# reached again (`stopped`). An unrecognised token means the row no longer says
# which of the three it is, and the section's whole purpose is to say exactly that.
#
# `stopped` IS A THIRD STATE AND NOT A SPELLING OF THE OTHER TWO. Neither of the
# original pair is true of a stopped teammate: it has not delivered, and it
# cannot be messaged. This set was closed at TWO on the reasoning that "a row
# that will not be reached again is DELETED, so there is no token for it" -- and
# steps/handoff.md step 1 is the case that reasoning does not cover. At a handoff
# the row must SURVIVE, because the successor session needs to know what was
# running and a deleted row is indistinguishable from a teammate that never
# existed.
#
# MEASURED, on the reference consumer at sprint 308, one row varied against two
# held constant beside it in the same run:
#
#   stopped (operator-requested handoff)   exit 1   <- this check
#   ~~stopped~~                            exit 1   <- check_inflight_rows
#   in-flight                              exit 0   <- but ai-dlc-continue.sh
#                                                      Check 0 blocks the handoff
#   delivered-reachable                    exit 0   <- false: it never delivered
#
# So of the four dispositions available to a lead, three were refused and the
# only passing one was DELETION, which steps/handoff.md and the remedy text of
# ai-dlc-continue.sh:390 both instruct against in as many words. That consumer
# hit this twice in one sprint and worked around it by deleting the row, which
# is the record loss the instruction exists to prevent.
#
# LEADING TOKEN, NOT THE WHOLE CELL. Measured on the reference consumer's live
# snapshot: its status cells are `in-flight, retrying Write`, `in-flight, since
# 2026-07-27T21:12:41Z`, and `in-flight (VERIFY pass, resolves_divergence: ...)`.
# An equality check would have failed every one of them on the day it shipped.
# The delimiter is whitespace OR a comma OR a semicolon, because the observed
# rows use all three -- an earlier draft split on punctuation only and still
# failed the live file. The trailing qualifier is a lead's own note and is priced
# by the byte budget, like every other byte in the section. This mirrors the
# PREFIX decision `is_canonical_section` already takes for section headings.
#
# THE HEADER DECLARES THE COLUMN, AND NOTHING IS CHECKED WITHOUT IT. Measured
# across the reference consumer's 151 snapshots (1 live, 150 archived): four
# archives predate the current five-column row and declare
# `| teammate | deliverable | dispatched-at | state |` or a four-column table
# with no status at all. Their last cell is a deliverable or a timestamp, and
# indicting it would be the check reading a column that does not exist. So the
# scan arms only after a header row whose last cell is `status`, which is the
# table declaring it has one. This is derived from the table itself, not a
# fitted exception list.
#
# A closed set is legitimate here because it bounds NAMES, never CONTENT: the
# three tokens are defined by gate-validation.md and _gate-procedures.md, and
# this is the mechanism that keeps a renamed token from drifting back.
#
# The excluded rows are enumerated rather than pattern-guessed, because each is
# a real line the section carries and none of them is a violation: the header
# row (last cell `status`), the alignment separator (last cell `---` or `:---:`),
# any line that is not a pipe row at all (the section's prose, and the `(none)`
# body), and a row with too few cells to have a status column.
#
# A STRUCK ROW IS EXEMPT, and that is not leniency. check_inflight_rows already
# indicts it, and its remedy is DELETE THE ROW while this one's is RELABEL IT.
# Firing both at one row hands the lead two contradictory instructions, and it
# entangles the two checks: struck rows historically carry a dash in the status
# cell, so without this line every struck-row assertion would also be a status
# assertion and neither would prove anything on its own.
# -----------------------------------------------------------------------------
check_inflight_status() {
  awk '
    /^## In-Flight Teammates/ { f=1; declared=0; next }
    /^## /                    { f=0 }
    !f                        { next }
    !/^[[:space:]]*\|/        { next }        # prose, "(none)", blank lines
    /~~/                      { next }        # struck row: check_inflight_rows owns it
    {
      row = $0
      sub(/^[[:space:]]*\|/, "", row)
      sub(/\|[[:space:]]*$/, "", row)
      n = split(row, cell, "|")
      if (n < 2) next                          # too few columns to carry a status
      s = cell[n]
      gsub(/`/, "", s)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
      if (s == "status") { declared = 1; next } # the header declares the column
      if (!declared) next                      # no status column: nothing to check
      if (s ~ /^:?-+:?$/) next                 # alignment separator
      tok = s
      sub(/[[:space:],;].*$/, "", tok)         # keep the leading token only
      if (tok == "in-flight") next
      if (tok == "delivered-reachable") next
      if (tok == "stopped") next
      print
    }' "$1" 2>/dev/null \
    | while IFS= read -r line; do
        printf 'INFLIGHT  %-30s unknown status: %s\n' "$2" "$(printf '%s' "$line" | cut -c1-70)" \
          >> "$STATUS_FILE"
      done
}

env_override() {
  # prd.md -> AI_DLC_BUDGET_PRD_MD
  local key
  key="AI_DLC_BUDGET_$(printf '%s' "$1" | tr '[:lower:].-' '[:upper:]__')"
  eval "printf '%s' \"\${$key:-}\""
}

# -----------------------------------------------------------------------------
# THE EVIDENCE CELL (--check-evidence). gate-validation.md Check 15 runs this.
#
# Check 14 runs the budget check and writes its own result into the gate log.
# Check 15 verifies Check 14's assertion took effect. For every other part of
# Check 14 that verification reads the snapshot; for the budget it had nothing to
# read but the same self-report, so the loop was closed on itself.
#
# It failed exactly that way. In the reference consumer at gate
# `story-20260722T014002Z` the evidence cell read:
#
#     Budget validator: `PASS  validate-artifact-budget.sh` (exit 0).
#
# The snapshot measured 126% of budget at the commit before that gate and 212% at
# the commit after; the validator exits 1 at both. The cell was not empty and not
# a paraphrase of the "budget OK" kind Check 15 already rejected -- it was the
# validator's real PASS format, which at the time carried no run-specific content
# and so could be written without running anything. verdict.sh now puts the
# measurement in that line (see its header); this arm requires the measurement to
# be there.
#
# TWO PREDICATES, BOTH DERIVABLE FROM THE ROW ALONE:
#
#   1. The cell carries a token measurement (`<n> tok`). One predicate covers the
#      whole observed failure population: the 12 consecutive `-` cells v0.118.0
#      found, and the content-free PASS string above.
#   2. If the row claims PASS, that number is within budget + grace. A row cannot
#      cite a breaching measurement and call itself passing. UNOBSERVED -- no real
#      cell has ever done this; predicate 1 caught every one of them. It is here
#      because it costs nothing and needs no constant, not because it was measured.
#      Do not read it as evidence of a failure mode that happened.
#
# WHAT THIS DELIBERATELY DOES NOT DO: join the cited number against the snapshot
# on disk. That needs a drift tolerance -- the snapshot keeps being written after
# the row -- and a tolerance would be a fitted constant with no derivation, which
# is the mistake this file's own budget table had to unwind once already. No
# observed failure needed it: every real one cited no number at all.
#
# SCOPE IS THE LAST ROW ONLY. Gate logs are append-only and hold years of rows
# written under older rules; indicting them retroactively would make this arm
# unpassable on any real consumer and it would be disabled rather than obeyed.
# The gate being logged right now is the one Check 15 is verifying.
# -----------------------------------------------------------------------------
if [ "$CHECK_EVIDENCE" -eq 1 ]; then
  if [ -z "$GATE_LOG" ]; then
    GATE_LOG="$(find "$ROOT/_bmad-output" -type f -name 'gate-log.md' 2>/dev/null | head -1)"
  fi
  [ -n "$GATE_LOG" ] && [ -f "$GATE_LOG" ] || {
    echo "FAIL: no gate-log.md found under $ROOT/_bmad-output (pass --gate-log PATH)" >&2
    exit 1; }

  # Both row shapes in use. The long form is gate-validation.md's own
  # (`| [core] 14 - Update pipeline snapshot | PASS (lead) | <evidence> |`); the
  # short form appears in the compact per-check tables some gates append
  # (`| 14 | lead | <evidence> |`). Matching only the long one would pass the
  # short one vacuously.
  ROW="$(grep -nE '^\|[[:space:]]*(\[core\][[:space:]]*)?14[[:space:]]*(\||—|-)' "$GATE_LOG" 2>/dev/null | tail -1)"

  if [ -z "$ROW" ]; then
    echo "FAIL: no Check 14 row found in ${GATE_LOG#"$ROOT"/}" >&2
    echo "      Check 15 cannot verify an assertion that was never recorded." >&2
    exit 1
  fi

  say "gate log            : ${GATE_LOG#"$ROOT"/}"
  say "last Check 14 row   : line ${ROW%%:*}"
  say ""

  SNAP_BUDGET="$(printf '%s\n' "$BUDGETS" | grep '^pipeline-snapshot.md|' | cut -d'|' -f2)"
  ov="$(env_override pipeline-snapshot.md)"; [ -z "$ov" ] || SNAP_BUDGET="$ov"
  CEILING=$(( SNAP_BUDGET + (SNAP_BUDGET * GRACE_PCT / 100) ))

  # `26774 tok` / `26,774 tok`. Commas stripped before the comparison.
  CITED="$(printf '%s\n' "$ROW" | grep -oE '[0-9][0-9,]*[[:space:]]*tok' | tail -1 \
           | tr -d ', ' | sed 's/tok$//')"

  if [ -z "$CITED" ]; then
    echo "FAIL: the last Check 14 row cites no budget measurement." >&2
    printf '      %s\n' "$(printf '%s' "$ROW" | cut -c1-160)" >&2
    cat >&2 <<'EOF'

      Check 14 must paste verdict.sh's line for
      `validate-artifact-budget --only pipeline-snapshot.md` into its evidence
      cell, and that line carries the measured token count.

      A cell reading `-`, or `done after this entry`, or a bare
      `PASS  validate-artifact-budget.sh`, records that nothing was measured --
      not that the check passed. The two are indistinguishable afterwards, which
      is the whole reason this arm exists.
EOF
    exit 1
  fi

  if grep -q 'PASS' <<<"$ROW" && [ "$CITED" -gt "$CEILING" ]; then
    echo "FAIL: the last Check 14 row claims PASS while citing ${CITED} tok, past the ${CEILING} ceiling (budget ${SNAP_BUDGET} + ${GRACE_PCT}% grace)." >&2
    echo "      A row cannot cite a breaching measurement and call itself passing." >&2
    exit 1
  fi

  say "PASS  Check 14 evidence cell cites ${CITED} tok (budget ${SNAP_BUDGET}, ceiling ${CEILING})."
  exit 0
fi

BREACH=0
CHECKED=0

# The subshell channels. These exist because the scan loops run on the right of a
# `|` and cannot export a variable back (documented at the reporting block below);
# a file is how the verdict escapes.
#
# THEY LIVE IN A PRIVATE TEMP DIR, NOT THE PROJECT ROOT. They used to be
# `$ROOT/.ai-dlc-*.tmp`, and that was wrong three ways at once:
#
#   1. LITTER. Nothing gitignores them -- not the consumer's .gitignore, not the
#      distribution's, and install.sh writes no rule. A killed run left them
#      untracked in the project root, where a broad `git add -A` at sprint-review
#      or deploy-validate commits them.
#   2. A STALE FILE IS UNFALSIFIABLE TO A READER. Clearing them at start stopped a
#      leftover producing a false verdict from the SCRIPT, but not from a human or
#      agent who opens the file. That is not hypothetical: a v0.118.1 reconcile
#      report quoted a 12-minute-old leftover as this run's evidence. It happened
#      to be accurate; nothing about the file could have said otherwise.
#   3. CROSS-RUN STATE AT ALL. Two runs in the same project shared a path.
#
# A fresh mktemp dir per run removes the class rather than defending against it:
# there is no leftover to gitignore, to clear, or to misread.
TMPROOT="$(mktemp -d 2>/dev/null)" || {
  echo "FAIL: could not create a temp dir for the scan channels" >&2; exit 1; }
trap 'rm -rf "$TMPROOT"' EXIT
BREACH_FILE="$TMPROOT/breach"
SCHEMA_FILE="$TMPROOT/schema"
ENTRY_FILE="$TMPROOT/entry-shape"
MARKER_FILE="$TMPROOT/marker"
INFLIGHT_FILE="$TMPROOT/inflight"
STATUS_FILE="$TMPROOT/inflight-status"

# -----------------------------------------------------------------------------
# THE ENTRY-SHAPE SELF-PROBE, AND IT RUNS BEFORE THE CORPUS.
#
# An arm reporting nothing without first proving it can produce a finding has
# established that it ran, not that the snapshot is clean -- and this arm's whole
# output is a WARN that changes no exit status, so a silently dead copy of it looks
# exactly like a correctly quiet one on every green run there has ever been. There
# is no exit code to notice its absence. That is why this probe is here and why it
# is FATAL: nothing downstream would ever miss this arm.
#
# BOTH DIRECTIONS, on a mktemp file, never the real corpus:
#   OFFENDER  a bulleted dated entry under `## Sprint Context`   -> must be reported
#   NEAR-MISS four lines that must NOT be:
#             - a MID-line timestamp under `## Pipeline Position` (real row data on
#               396 of the consumer's 514 revisions; indicting it makes this noise)
#             - an INDENTED line opening with a timestamp under `## Pipeline
#               Position` (a soft-wrapped continuation; admitting leading blanks
#               before the bullet flags 178 extra lines across the corpus, every one
#               of them a continuation whose predecessor is non-empty)
#             - a bulleted dated entry under `## Recent Activity` (its own section)
#             - an UNBULLETED dated line under `## In-Flight Teammates` (a wrapped
#               prose continuation; all 8 of the corpus's In-Flight hits are one)
# An arm that flags the near-miss flags most of the corpus, which is a scan that
# discriminates nothing and reads exactly like one that discriminates perfectly.
# -----------------------------------------------------------------------------
_probe_seed() { # _probe_seed <file>
  {
    printf '## Pipeline Position\n'
    printf -- '- last_gate_passed: planning at 2026-09-12T22:14:00Z\n'
    printf '  2026-09-12T22:20:00Z a soft-wrapped continuation, indented\n'
    printf '## Sprint Context\n'
    printf -- '- 2026-09-12T02:53Z: routed fresh, step 1a\n'
    printf '## Recent Activity\n'
    printf -- '- 2026-09-12T03:00Z: this one is where it belongs\n'
    printf '## In-Flight Teammates\n'
    printf '2026-09-09T14:05:45Z; a wrapped prose continuation, not an entry\n'
    printf '## Open Items\n## Locked Decisions\n## Context Reminders\n'
  } > "$1"
}
PROBE_FILE="$TMPROOT/probe-snapshot.md"
_probe_seed "$PROBE_FILE"
ENTRY_FILE_SAVE="$ENTRY_FILE"
ENTRY_FILE="$TMPROOT/probe-entry"
: > "$ENTRY_FILE"
check_snapshot_entry_shape "$PROBE_FILE" "probe-snapshot.md"
PROBE_OUT="$(cat "$ENTRY_FILE" 2>/dev/null)"
rm -f "$ENTRY_FILE" "$PROBE_FILE"
ENTRY_FILE="$ENTRY_FILE_SAVE"

_probe_has() { case "$PROBE_OUT" in *"$1"*) return 0 ;; esac; return 1; }
PROBE_RC=0
if ! _probe_has 'under ## Sprint Context'; then
  echo "FAIL: the entry-shape self-probe's OFFENDER was not reported. A bulleted dated" >&2
  echo "  entry seeded under ## Sprint Context went unseen by the same function the" >&2
  echo "  corpus arm runs, so its silence below would mean only that it executed." >&2
  PROBE_RC=1
fi
if _probe_has 'under ## Pipeline Position'; then
  echo "FAIL: the entry-shape self-probe's NEAR-MISS fired on a MID-line timestamp under" >&2
  echo "  ## Pipeline Position. That is legitimate row data on most of the reference" >&2
  echo "  consumer's snapshot revisions; this arm would report nearly all of them." >&2
  PROBE_RC=1
fi
if _probe_has "under ## ${ACTIVITY_SECTION}"; then
  echo "FAIL: the entry-shape self-probe reported an entry under ## ${ACTIVITY_SECTION}," >&2
  echo "  which is the section such entries BELONG under. The arm indicts correct filing." >&2
  PROBE_RC=1
fi
if _probe_has 'under ## In-Flight Teammates'; then
  echo "FAIL: the entry-shape self-probe's NEAR-MISS fired on an UNBULLETED dated line." >&2
  echo "  Every In-Flight hit in the measured corpus is a wrapped prose continuation;" >&2
  echo "  the required bullet is what holds this arm's false-positive set at zero." >&2
  PROBE_RC=1
fi
[ "$PROBE_RC" -eq 0 ] || exit 1

say "bytes/token divisor : ${BPT} (calibrated with validate-reattach-budget.sh; under-counts 5-11% on this population)"
say "project root        : ${ROOT}"
say ""

# -----------------------------------------------------------------------------
# THE WHOLE-READ POOL. The four planning artifacts are measured as a SUM against
# one analyst window, per the derivation at the top of this file.
#
# Skipped when --only names an artifact outside the set: the pool is a property of
# the four together, and reporting it while the caller asked about
# pipeline-snapshot.md would be noise at the two enforcement points (Check 14 and
# the sub-step path) that only ever ask about the snapshot. --only naming one OF
# the four still measures all four, because the pool is the only budget any of
# them has.
# -----------------------------------------------------------------------------
POOL_APPLIES=0
if [ -z "$ONLY" ]; then
  POOL_APPLIES=1
else
  for n in $WHOLE_READ_SET; do
    [ "$ONLY" = "$n" ] && POOL_APPLIES=1
  done
fi

if [ "$POOL_APPLIES" -eq 1 ]; then
  POOL_TMP="$TMPROOT/pool"
  rm -f "$POOL_TMP"
  for name in $WHOLE_READ_SET; do
    find "$ROOT/_bmad-output" "$ROOT/docs" -type f -name "$name" 2>/dev/null | while read -r f; do
      is_archive "$f" && continue
      is_not_artifact "$f" && continue
      is_sprint_slotted "${f#"$ROOT"/}" && continue
      bytes="$(wc -c < "$f" | tr -d ' ')"
      printf '%s|%s\n' "$(( bytes / BPT ))" "${f#"$ROOT"/}" >> "$POOL_TMP"
    done
  done

  # The live sprint's slot-resident whole-read artifacts. Resolved through the sibling
  # sprint-status.sh, which is where sprint_id is defined -- a second reading of the
  # canonicals here would be a second implementation of route.md Step 6.
  LIVE_SPRINT=""
  if [ -x "$AI_DLC_SELF_DIR/sprint-status.sh" ] || [ -f "$AI_DLC_SELF_DIR/sprint-status.sh" ]; then
    LIVE_SPRINT="$(bash "$AI_DLC_SELF_DIR/sprint-status.sh" sprint-id --root "$ROOT" 2>/dev/null | tr -dc '0-9')"
  fi
  if [ -z "$LIVE_SPRINT" ]; then
    # NOT SILENT. A pool arm that contributes nothing because its resolver failed reads
    # exactly like one whose subject is absent, and this whole arm exists because a
    # silently-zero pool row is the defect it was written against.
    say "  note: live sprint unresolved (sprint-status.sh sprint-id) -- ${SPRINT_WHOLE_READ_SET} not pooled"
  else
    for name in $SPRINT_WHOLE_READ_SET; do
      f="$ROOT/_bmad-output/planning-artifacts/s${LIVE_SPRINT}/$name"
      [ -f "$f" ] || continue
      is_archive "$f" && continue
      bytes="$(wc -c < "$f" | tr -d ' ')"
      printf '%s|%s\n' "$(( bytes / BPT ))" "${f#"$ROOT"/}" >> "$POOL_TMP"
    done
  fi

  POOL_TOTAL=0
  POOL_FILES=0
  say "whole-read pool     : ${WHOLE_READ_POOL} tok  (${ARTIFACT_SHARE_PCT}% of the analyst's ${READER_WINDOW_TOKENS}-tok window, resolved from ${WINDOW_SOURCE})"
  if [ -s "$POOL_TMP" ]; then
    while IFS='|' read -r tokens rel; do
      POOL_TOTAL=$(( POOL_TOTAL + tokens ))
      POOL_FILES=$(( POOL_FILES + 1 ))
      [ "$QUIET" -eq 1 ] || printf '      %-44s %8s tok\n' "$rel" "$tokens"
    done < "$POOL_TMP"
  fi
  rm -f "$POOL_TMP"

  # DERIVED, not the literal "4" this label carried. The count and the sum come from
  # the same rows, so a label reading "4" while the sum covered 30 files cannot recur
  # -- and if a consumer legitimately holds one of the four at two live paths (the
  # sprint-status.yaml lesson below), the label says so instead of lying about it.
  # Core Rule 31: a count asserted in prose beside a number derived from a different
  # set is the defect, not the number.
  POOL_LABEL="WHOLE-READ POOL (${POOL_FILES} planning artifact$([ "$POOL_FILES" -eq 1 ] || printf s))"
  POOL_CEILING=$(( WHOLE_READ_POOL + (WHOLE_READ_POOL * GRACE_PCT / 100) ))
  POOL_PCT=$(( POOL_TOTAL * 100 / WHOLE_READ_POOL ))
  if [ "$POOL_TOTAL" -gt "$POOL_CEILING" ]; then
    printf 'OVER  %-44s %8s tok  (pool %6s, %s%% of it)  -> consolidate\n' \
      "$POOL_LABEL" "$POOL_TOTAL" "$WHOLE_READ_POOL" "$POOL_PCT" >> "$BREACH_FILE"
  elif [ "$POOL_TOTAL" -gt "$WHOLE_READ_POOL" ]; then
    printf 'warn  %-44s %8s tok  (pool %6s, %s%% — within %s%% grace)  -> consolidate soon\n' \
      "$POOL_LABEL" "$POOL_TOTAL" "$WHOLE_READ_POOL" "$POOL_PCT" "$GRACE_PCT"
  else
    [ "$QUIET" -eq 1 ] || printf '  ok  %-44s %8s tok  (pool %6s, %s%% of it)\n' \
      "$POOL_LABEL" "$POOL_TOTAL" "$WHOLE_READ_POOL" "$POOL_PCT"
  fi
  say ""
fi

printf '%s\n' "$BUDGETS" | while IFS='|' read -r name budget remedy; do
  [ -n "$name" ] || continue
  [ -z "$ONLY" ] || [ "$ONLY" = "$name" ] || continue

  ov="$(env_override "$name")"
  [ -z "$ov" ] || budget="$ov"

  # Find every live copy. sprint-status.yaml taught us the reference consumer can
  # hold the SAME artifact at two paths, so measure them all rather than assuming
  # one canonical location.
  find "$ROOT/_bmad-output" "$ROOT/docs" -type f -name "$name" 2>/dev/null | while read -r f; do
    is_archive "$f" && continue
    is_not_artifact "$f" && continue
    bytes="$(wc -c < "$f" | tr -d ' ')"
    tokens=$(( bytes / BPT ))
    rel="${f#"$ROOT"/}"
    ceiling=$(( budget + (budget * GRACE_PCT / 100) ))

    # Schema and budget are INDEPENDENT verdicts. An in-budget snapshot can still
    # carry an invented section (that is how the 296 one started), and the point
    # of checking here is to catch it while it is still cheap.
    if [ "$name" = "pipeline-snapshot.md" ]; then
      check_snapshot_sections "$f" "$rel"
      check_snapshot_entry_shape "$f" "$rel"
      check_inflight_rows "$f" "$rel"
      check_inflight_status "$f" "$rel"
      check_supersession_markers "$f" "$rel"
    fi

    if [ "$tokens" -gt "$ceiling" ]; then
      over=$(( tokens * 100 / budget ))
      printf 'OVER  %-32s %7s tok  (budget %6s, %s%% of it)  -> %s\n' \
        "$rel" "$tokens" "$budget" "$over" "$remedy" >> "$BREACH_FILE"
    elif [ "$tokens" -gt "$budget" ]; then
      # Over budget but inside the grace band. Say so -- the number is the truth --
      # but do not block: see "WARN AT 100%, BLOCK AT 100% + GRACE" in the header.
      over=$(( tokens * 100 / budget ))
      printf 'warn  %-32s %7s tok  (budget %6s, %s%% — within %s%% grace)  -> %s soon\n' \
        "$rel" "$tokens" "$budget" "$over" "$GRACE_PCT" "$remedy"
    else
      [ "$QUIET" -eq 1 ] || printf '  ok  %-32s %7s tok  (budget %6s)\n' "$rel" "$tokens" "$budget"
    fi
  done
done

# The `while` above runs in a subshell (pipe), so BREACH cannot escape it. The
# temp file is the channel. Deliberate: rewriting this as a process-substitution
# loop is a bashism and install.sh targets /bin/bash but consumers have run this
# under sh before.
RC=0

# WHAT WAS EMITTED, tracked separately from RC, and the two are NOT the same question.
# RC answers "does this run block the caller". These answer "did this run print a finding".
# Under --warn-only they diverge by design, and the summary line below has to be a function
# of THESE -- keying it on RC is what let a single run print `WARN: N artifact(s) over the
# Rule 25(d) budget.`, list every OVER row, and then close with `PASS  every measured living
# artifact is within its Rule 25(d) budget.` Filed by the reference consumer as
# PC-S303-BUDGET-SCRIPT-PASS-LINE-UNCONDITIONAL after reproducing it in two sprints.
#
# The verdict files are removed as each block finishes, so the flag is set where the block
# runs and not read back off the filesystem afterwards.
SAW_BREACH=0
SAW_SCHEMA=0
SAW_STATUS=0
SAW_UNGOV=0

if [ -s "$BREACH_FILE" ]; then
  SAW_BREACH=1
  BREACH=$(wc -l < "$BREACH_FILE" | tr -d ' ')
  say ""
  if [ "$WARN_ONLY" -eq 1 ]; then
    echo "WARN: ${BREACH} artifact(s) over the Rule 25(d) budget."
  else
    echo "FAIL: ${BREACH} artifact(s) over the Rule 25(d) budget." >&2
  fi
  cat "$BREACH_FILE" >&2
  cat >&2 <<'EOF'

      Every read of an over-budget artifact is context the pipeline does not get
      back, and the reads compound: the snapshot alone is whole-read at every gate,
      on every resume, and after every compaction.

      Remedies (they are NOT interchangeable):
        consolidate -> artifact-consolidation.md. Operator-invoked, fidelity-critical.
                       The WHOLE-READ POOL breaches as a SUM, so the remedy is chosen
                       across the four, not per file. Before consolidating: check
                       whether the growth is locked requirements (Rule 13), because
                       consolidation cannot retire one and relocating them needs
                       operator sign-off. Raising the pool is NOT a remedy.
        rotate      -> a rotation was MISSED. Move the epoch to
                       implementation-artifacts/s<N>/<basename>-archive.md
                       (Rule 25(c)); never rewrite a log. <N> is the sprint that
                       CLOSED. If that slot is already filled -- which is the
                       normal case at sprint START, where the only s<N>/ on disk
                       belongs to the sprint whose retro just rotated this log --
                       append an ordinal (-archive-2.md, then -3) and state the
                       epoch's span in the archive's FIRST LINE. Overwriting the
                       existing archive is a Rule 25(a) no-loss breach and is
                       irreversible outside git recovery. Do NOT create the next
                       sprint's directory here, and do NOT put a date or status
                       token in the basename.
        trim        -> MOVE superseded content verbatim to pipeline-snapshot-history.md
                       (write-only, Rule 25(a)), THEN delete it from
                       pipeline-snapshot.md. Never delete it outright -- moving it is
                       the remedy, and deleting it is the defect this line exists to
                       stop. The live file keeps all seven sections (gate-validation
                       Check 14 owns them): a section is trimmed by moving its
                       SUPERSEDED ENTRIES out, never by dropping the section. The gates
                       that let it grow past 6k are the finding, not the file. NOTE:
                       In-Flight Teammates is one of the seven -- it is the dispatch
                       ledger, and deleting it is how a lead re-dispatches a teammate
                       that is still alive.
EOF
  # --fail-on is checked per BREACHING artifact, not per run. A --warn-only run whose
  # only breach is an artifact the caller hardened must still exit 1, and a --warn-only
  # run whose breaches are all unhardened must still exit 0 -- both directions, or the
  # flag is decoration. The breach lines are `OVER  <rel>  ...`, so field 2 is the path.
  if [ "$WARN_ONLY" -eq 1 ]; then
    while read -r _verdict brel _rest; do
      [ -n "${brel:-}" ] || continue
      if is_fail_on "$brel"; then
        echo "FAIL: $brel is over budget and was hardened with --fail-on, so this run blocks despite --warn-only." >&2
        RC=1
      fi
    done < "$BREACH_FILE"
  else
    RC=1
  fi
fi
rm -f "$BREACH_FILE"

# Reported SEPARATELY from the byte budget, and never folded into that count: an
# invented section is not "over the Rule 25(d) budget", and saying so would send
# the lead to the wrong remedy. Trimming bytes out of a section that should not
# exist is how 9 KB of invention survives a trim.
if [ -s "$SCHEMA_FILE" ]; then
  SAW_SCHEMA=1
  say ""
  if [ "$WARN_ONLY" -eq 1 ]; then
    echo "WARN: pipeline-snapshot.md carries section(s) outside its seven-section schema."
  else
    echo "FAIL: pipeline-snapshot.md carries section(s) outside its seven-section schema." >&2
  fi
  cat "$SCHEMA_FILE" >&2
  cat >&2 <<'EOF'

      The seven sections are Pipeline Position, Sprint Context, Recent Activity,
      Open Items, Locked Decisions, In-Flight Teammates, Context Reminders.
      gate-validation.md Check 14 defines them; nothing else may be added.

      Remedy: move each unknown section verbatim to pipeline-snapshot-history.md
      (write-only, Rule 25(a)) and delete it here. Do NOT fold its content into one
      of the seven -- that keeps the bytes and loses the finding.

      A section nothing in core writes is a section nothing in core reads. It is
      not recovered after compaction, not consumed at any gate, and not part of the
      handoff contract -- it is context the pipeline pays for on every whole-read
      and never spends.
EOF
  [ "$WARN_ONLY" -eq 1 ] || RC=1
fi
rm -f "$SCHEMA_FILE"

# A WARN THAT NEVER TOUCHES RC, ON EVERY PATH, INCLUDING --fail-on.
#
# The three verdicts above each become a FAIL without --warn-only. This one does
# not, and the asymmetry is the point: each of those says an artifact is over
# budget, carries a section that must not exist, or holds a row that no longer
# says what it means. This one says one line is filed under the wrong heading.
# The remedy is to MOVE it, it costs one edit, and the gate it would otherwise
# wedge is the BLOCKING sub-step path. A lint that stops a pipeline over a
# misfiled line is a lint the operator turns off.
#
# So RC is not written here at all -- not under --fail-on, which hardens an
# artifact's BUDGET verdict and has never spoken to this one. A future author
# adding `RC=1` inside this block changes the gate's behaviour, not its output;
# `budget-summary-verdict` and `snapshot-entry-shape` both assert the exit status
# is unchanged by this finding, in both directions.
if [ -s "$ENTRY_FILE" ]; then
  say ""
  # ONE line matching verdict.sh's surface grammar, carrying the count AND the
  # per-section breakdown, so the evidence cell says what was found without the
  # rows. The rows follow on `misfiled` lines that grammar cannot match.
  # EVERY READER OF THIS CHANNEL RUNS UNDER `LC_ALL=C`, AND THAT IS NOT STYLE.
  # MEASURED against the reference consumer's `66d0eb165`: BSD `cut` aborts with
  # "Illegal byte sequence" on the multibyte characters real snapshot prose carries,
  # having printed only the rows before the first one. It emitted 8 of 29 detail
  # rows, wrote its complaint to the same stderr the rows go to, and the run still
  # exited 0 -- a truncated finding list that reads exactly like a complete one.
  # Under `LC_ALL=C` the bytes are bytes and all 29 survive. The count comes from
  # `wc -l` on the same records, so a future truncation disagrees with its own
  # aggregate line instead of shrinking quietly.
  ENTRY_N="$(wc -l < "$ENTRY_FILE" | tr -d ' ')"
  ENTRY_BY_SEC="$(LC_ALL=C awk -F'\t' '{c[$2]++; if (!(($2) in o)) { o[$2]=++k } }
    END { for (s in c) printf "%d\t%s %d\n", o[s], s, c[s] }' "$ENTRY_FILE" \
    | LC_ALL=C sort -n | LC_ALL=C cut -f2- | tr '\n' ';' | sed -e 's/;$//' -e 's/;/, /g')"
  echo "WARN: pipeline-snapshot.md files ${ENTRY_N} dated activity entr$( [ "$ENTRY_N" -eq 1 ] && echo y || echo ies ) outside ${ACTIVITY_SECTION} (${ENTRY_BY_SEC}) -- move each to ${ACTIVITY_SECTION}."
  ENTRY_SHOWN="$(LC_ALL=C cut -f3- "$ENTRY_FILE" | tee /dev/stderr | wc -l | tr -d ' ')"
  if [ "$ENTRY_SHOWN" != "$ENTRY_N" ]; then
    echo "      (only ${ENTRY_SHOWN} of ${ENTRY_N} rows above were renderable -- the list is TRUNCATED)" >&2
  fi
  cat >&2 <<EOF

      A line that opens with a bullet and a timestamp is an ACTIVITY ENTRY.
      _gate-procedures.md "Sub-step snapshot update" appends those to
      \`## ${ACTIVITY_SECTION}\` and nowhere else.

      Remedy: MOVE each line above to \`## ${ACTIVITY_SECTION}\`. Do not delete it
      and do not rename the heading it is under -- both of those are a different
      remedy for a different finding.

      Filed elsewhere it is invisible: the seven-section schema check reads
      headings only and passes it, the byte budget prices it like any other prose,
      and every whole-read at a gate, a resume or a recovery reads the section it
      landed in as though a log entry were that section's content.

      This does NOT change the exit status, at any flag. It is a filing error, and
      the path this script runs on at a sub-step blocks the pipeline.

      Sections a project DECLARES in AI_DLC_SNAPSHOT_EXTRA_SECTIONS are out of
      scope: a project that names its own section owns what goes under it.
EOF
fi
rm -f "$ENTRY_FILE"

# A THIRD INDEPENDENT VERDICT, for the same reason the schema check is a second one.
# Marked-superseded content is neither "over budget" nor "an invented section": it sits
# under a canonical heading, at whatever size, and both existing checks pass it. Folding
# it into either count would send the lead to the wrong remedy -- trimming BYTES out of
# content whose defect is that it was never MOVED, and the trim then destroys the record
# the write-only history file exists to keep.
if [ -s "$MARKER_FILE" ]; then
  say ""
  if [ "$WARN_ONLY" -eq 1 ] && ! is_fail_on "pipeline-snapshot.md"; then
    echo "WARN: pipeline-snapshot.md marks superseded content in place."
  else
    echo "FAIL: pipeline-snapshot.md marks superseded content in place." >&2
    RC=1
  fi
  cat "$MARKER_FILE" >&2
  cat >&2 <<'EOF'

      Superseded content is MOVED, not marked. Strikethrough, a bracketed
      SUPERSEDED annotation, or a bare all-caps SUPERSEDED stamp all leave dead
      prose under a live heading, where the seven-section schema check and the
      byte budget both pass it in silence.

      Remedy: move each marked line's superseded content VERBATIM to
      pipeline-snapshot-history.md (write-only, Rule 25a) and delete it here.

      NOT flagged, deliberately: lowercase "superseded" as ordinary prose, and the
      compound category label WONTFIX/SUPERSEDED, which names a class of backlog
      item rather than marking this content. `## In-Flight Teammates` is out of
      scope here -- its struck rows belong to the In-Flight row check, and
      reporting them twice would offer two remedies for one line.
EOF
fi
rm -f "$MARKER_FILE"

# A THIRD independent verdict, for the same reason the schema one is separate: a
# struck row is not "over budget", and sending the lead to `trim` would have it
# shrink the prose around a row whose whole problem is that the row still exists.
if [ -s "$INFLIGHT_FILE" ]; then
  say ""
  if [ "$WARN_ONLY" -eq 1 ]; then
    echo "WARN: In-Flight Teammates carries struck-through row(s)."
  else
    echo "FAIL: In-Flight Teammates carries struck-through row(s)." >&2
  fi
  cat "$INFLIGHT_FILE" >&2
  cat >&2 <<'EOF'

      Rows only. A row is DELETED when the teammate will not be messaged again --
      never struck. gate-validation.md defines the section; _gate-procedures.md
      step 3 reconciles it.

      A teammate that has delivered but is still alive and re-messageable is not
      history and does not need a strikethrough to say so: give its row
      `status: delivered-reachable`. That is what the column is for. Striking the
      row instead keeps every byte, keeps growing, and loses the one fact the
      section exists to carry -- who is actually outstanding.
EOF
  [ "$WARN_ONLY" -eq 1 ] || RC=1
fi
rm -f "$INFLIGHT_FILE"

# A FOURTH independent verdict, and separate for the same reason again: an
# unrecognised status token is not a struck row, and the remedy is the opposite
# one. `struck row` says DELETE the row; `unknown status` says KEEP the row and
# say which of the two states it is in. Merged into one verdict, a lead reading
# the struck-row remediation would delete a row it was supposed to relabel.
if [ -s "$STATUS_FILE" ]; then
  SAW_STATUS=1
  say ""
  if [ "$WARN_ONLY" -eq 1 ]; then
    echo "WARN: In-Flight Teammates carries row(s) with an unrecognised status."
  else
    echo "FAIL: In-Flight Teammates carries row(s) with an unrecognised status." >&2
  fi
  cat "$STATUS_FILE" >&2
  cat >&2 <<'EOF'

      The status column is a closed set of three, and the leading token of the
      cell must be one of them:

        in-flight            -- dispatched, has not delivered yet
        delivered-reachable  -- delivered, and the lead can still message it
        stopped              -- stopped before delivering, will not be reached

      A teammate that delivered and will not be messaged again has no token:
      DELETE its row. A teammate STOPPED at a handoff keeps its row and takes
      `stopped` -- steps/handoff.md step 1 requires the row to survive, because
      the successor session cannot tell a deleted row from a teammate that never
      existed. A trailing note after a comma is allowed and priced by the byte
      budget (`stopped, operator-requested handoff`); only the leading token is
      checked.

      gate-validation.md defines the column, _gate-procedures.md step 3
      reconciles it, and Rule 28 bounds what a message to a reachable teammate
      may carry -- additive to its original brief, never a retraction and never
      a scope-distinct new task.
EOF
  [ "$WARN_ONLY" -eq 1 ] || RC=1
fi
rm -f "$STATUS_FILE"

# -----------------------------------------------------------------------------
# A FOURTH verdict: COVERAGE. Everything above measures artifacts this table
# already names. It cannot say anything about an artifact the table FORGOT --
# and a forgotten artifact reads exactly like a passing one, because no row is
# printed either way.
#
# That is not hypothetical. audit-anchors.md is read every sprint
# (carry-over-evaluation Step 1a, gate Check 18), was in neither BUDGETS nor
# is_archive(), and reached 37k tokens over 120 sprints -- one entry of which is
# ever read. Nothing was broken; nothing was measuring it.
#
# So: derive the read-path set from the STEP FILES, which are what actually names
# the artifacts the pipeline reads, and report anything in it that no budget
# governs. Derived, never hand-listed -- a second hand-maintained list would drift
# from the first and the stale list becomes the bug.
#
# WARN-ONLY, ALWAYS, and never folded into RC. "No budget covers this" is not a
# Rule 25(d) breach; it is a gap in the table, and the operator decides whether
# the artifact needs a budget or is bounded by being rewritten rather than
# appended. The floor keeps it quiet until the answer starts to matter: an
# unmeasured artifact is only interesting once it is big enough to cost a read.
# -----------------------------------------------------------------------------
UNGOVERNED_FLOOR="${AI_DLC_UNGOVERNED_FLOOR:-2000}"

STEPS_DIR=""
for cand in "$ROOT/.claude/skills/ai-dlc/steps" "$ROOT/core/skills/ai-dlc/steps"; do
  [ -d "$cand" ] && STEPS_DIR="$cand" && break
done

if [ -n "$STEPS_DIR" ] && [ -z "$ONLY" ]; then
  UNGOV_FILE="$TMPROOT/ungoverned"
  rm -f "$UNGOV_FILE"
  : > "$UNGOV_FILE"

  grep -Eho '_bmad-output/[A-Za-z0-9_./-]*\.(md|yaml|yml|json)' "$STEPS_DIR"/*.md 2>/dev/null |
    sed 's#.*/##' | sort -u | while read -r name; do
      [ -n "$name" ] || continue
      # `sprint-<N>.md`, `story-{id}.md` and friends name a CLASS, not a file.
      case "$name" in *'<'*|*'>'*|*'{'*|*'}'*|*'*'*|*'$'*) continue ;; esac
      is_archive "$name" && continue
      grep -q "^${name}|" <<<"$BUDGETS" && continue
      pooled=0
      for w in $WHOLE_READ_SET; do [ "$w" = "$name" ] && pooled=1; done
      [ "$pooled" -eq 1 ] && continue

      find "$ROOT/_bmad-output" "$ROOT/docs" -type f -name "$name" 2>/dev/null | while read -r f; do
        is_archive "$f" && continue
        is_not_artifact "$f" && continue
        tokens=$(( $(wc -c < "$f" | tr -d ' ') / BPT ))
        [ "$tokens" -ge "$UNGOVERNED_FLOOR" ] || continue
        printf '      %-44s %7s tok\n' "${f#"$ROOT"/}" "$tokens" >> "$UNGOV_FILE"
      done
    done

  if [ -s "$UNGOV_FILE" ]; then
    SAW_UNGOV=1
    say ""
    echo "WARN: read-path artifact(s) over ${UNGOVERNED_FLOOR} tok that NO budget governs."
    cat "$UNGOV_FILE" >&2
    cat >&2 <<'EOF'

      Each of these is named by a step file, so the pipeline reads it, and none of
      them is in the BUDGETS table or exempt as a write-only *-history/*-archive
      sink. They are unmeasured, not necessarily too big.

      Decide per artifact, and record the decision in the table or the exemption:
        appended every sprint  -> give it a budget and a rotation (audit-anchors.md
                                  is the worked example: prune at retro Step 5b).
        rewritten per run      -> a budget still bounds a runaway; pick one.
        write-only sink        -> rename it *-history.md / *-archive.md so
                                  is_archive() exempts it and says so out loud.

      Tune the floor with AI_DLC_UNGOVERNED_FLOOR. Silencing a row by raising the
      floor is a decision too -- make it deliberately.
EOF
  fi
  rm -f "$UNGOV_FILE"
fi

# THE SUMMARY LINE IS A FUNCTION OF WHAT THIS RUN PRINTED, NEVER OF RC.
#
# It used to be `if [ "$RC" -eq 0 ]`, and RC is deliberately 0 on the --warn-only path when
# no breaching artifact was hardened with --fail-on. So a run could print the WARN count,
# list every OVER row, and then close by claiming every artifact was within budget. Both
# statements in the same run, one of them false.
#
# THE CLEAN LINE IS BYTE-IDENTICAL TO WHAT IT ALWAYS WAS. Only the runs that had something
# to report change, because the clean string is the one anything downstream may already
# match on -- and a fix that moves the passing output is a fix nobody can adopt quietly.
#
# The four channels are NOT interchangeable and the summary must not flatten them:
#   breach/schema/status -- findings about artifacts this table measures. A run that printed
#                           one of these has NOT established that everything is within
#                           budget, whatever its exit code says.
#   coverage             -- artifacts NO budget governs. Its WARN and the clean claim are
#                           both literally true at once, because an ungoverned artifact is
#                           unmeasured rather than over budget. That run is not a
#                           contradiction; it is a pass with a stated blind spot, and saying
#                           so is the difference between legible and merely quiet.
if [ "$RC" -eq 0 ]; then
  say ""
  if [ "$SAW_BREACH" -eq 1 ] || [ "$SAW_SCHEMA" -eq 1 ] || [ "$SAW_STATUS" -eq 1 ]; then
    _what=""
    [ "$SAW_BREACH" -eq 1 ] && _what="${_what}, over-budget artifact(s)"
    [ "$SAW_SCHEMA" -eq 1 ] && _what="${_what}, off-schema section(s)"
    [ "$SAW_STATUS" -eq 1 ] && _what="${_what}, unrecognised In-Flight status row(s)"
    _what="${_what#, }"
    say "WARN  this run reported ${_what} and is NOT a clean result."
    say "      Exit status is 0 because --warn-only was passed and no reported artifact was"
    say "      hardened with --fail-on. Read the rows above; do not read this run as a pass."
  elif [ "$SAW_UNGOV" -eq 1 ]; then
    say "PASS  every measured living artifact is within its Rule 25(d) budget."
    say "      Measured is not everything: this run also reported read-path artifact(s) that"
    say "      NO budget governs. They are unmeasured, not within budget."
  else
    say "PASS  every measured living artifact is within its Rule 25(d) budget."
  fi
fi
exit "$RC"
