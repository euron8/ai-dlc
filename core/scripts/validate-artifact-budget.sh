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
#
# EXIT
#   0  nothing past the grace band (over-budget-but-within-grace is reported, not
#      fatal), or --warn-only
#   1  an artifact is past budget + grace, or input unreadable

set -u

BPT="${AI_DLC_BYTES_PER_TOKEN:-4}"
GRACE_PCT="${AI_DLC_BUDGET_GRACE_PCT:-10}"
ROOT="${CLAUDE_PROJECT_DIR:-.}"
ONLY=""
WARN_ONLY=0
QUIET=0
CHECK_EVIDENCE=0
GATE_LOG=""

while [ $# -gt 0 ]; do
  case "$1" in
    --root)           ROOT="${2:-}"; shift 2 ;;
    --only)           ONLY="${2:-}"; shift 2 ;;
    --warn-only)      WARN_ONLY=1; shift ;;
    --quiet)          QUIET=1; shift ;;
    --check-evidence) CHECK_EVIDENCE=1; shift ;;
    --gate-log)       GATE_LOG="${2:-}"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 1 ;;
  esac
done

say() { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }

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
#   team-roles/analyst.md as a TEMPLATE (`{analyst_model_personal}`) that setup
#   fills per project. Shipping 1,000,000 to every consumer would hand a
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

# The analyst's context window, from the role file setup writes. `[1m]` is Claude
# Code's own suffix for the 1M-context variant, which is why it is the token
# matched rather than a model-name table -- a name table is a hand-maintained list
# that goes stale silently, and the suffix is the thing that actually selects the
# window.
#
# UNRESOLVED FALLS BACK TO 200000, NEVER TO THE LARGER NUMBER. An unfilled
# template, a missing role file and an unrecognised model all mean the same thing:
# we do not know. 200K is the standard window and the value the context sensor
# already defaults to (`*) MODEL_MAX=200000`), so the unknown case tightens the
# gate rather than opening it. A consumer whose analyst genuinely has more room
# sets AI_DLC_READER_WINDOW_TOKENS -- and unlike the four constants this replaces,
# the number being overridden has a derivation to argue against.
resolve_reader_window() {
  role="$ROOT/.claude/team-roles/analyst.md"
  [ -f "$role" ] || role="$ROOT/core/team-roles/analyst.md"
  [ -f "$role" ] || { printf '200000'; return; }
  case "$(grep -m1 '^- Personal:' "$role" 2>/dev/null)" in
    *'[1m]'*) printf '1000000' ;;
    *)        printf '200000' ;;
  esac
}

if [ -n "${AI_DLC_READER_WINDOW_TOKENS:-}" ]; then
  READER_WINDOW_TOKENS="$AI_DLC_READER_WINDOW_TOKENS"
  WINDOW_SOURCE="AI_DLC_READER_WINDOW_TOKENS"
else
  READER_WINDOW_TOKENS="$(resolve_reader_window)"
  WINDOW_SOURCE="team-roles/analyst.md"
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
#   rotate       append-only log -> move the epoch to a dated archive (Rule 25(c)).
#                A live log over threshold means a rotation was MISSED, not that it
#                needs a rewrite. artifact-consolidation.md rejects logs as targets.
#   trim         pipeline-snapshot.md -> trim to its 7-section schema (Rule 25(a)).
#                Check 14 owns the schema. It is SEVEN sections since v0.50.0 --
#                In-Flight Teammates is one of them, and it is the ledger that
#                stops the lead re-dispatching live teammates. Do not delete it.
#                Never consolidation. A snapshot over threshold means the schema
#                stopped being enforced at gate passages, and the gates that let it
#                grow are the finding -- not the file.
# -----------------------------------------------------------------------------
BUDGETS="
gate-log.md|25000|rotate
compaction-log.md|10000|rotate
pipeline-continuation-log.md|10000|rotate
context-mode-protection-log.md|10000|rotate
pipeline-snapshot.md|6000|trim
"

# Rule 25(a): history/archive files are write-only and their growth is free.
# Measuring them would flag a 2.6 MB product-brief-history.md that costs nothing
# and whose whole job is to BE big so the live file is not.
is_archive() {
  case "$1" in
    *-history.md|*-archive.md|*-archive-*.md|*.precompact.md) return 0 ;;
    *) return 1 ;;
  esac
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
# by then the remedy text ("trim to its 7-section schema", below) was pointing at
# a schema nothing could evaluate.
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
is_canonical_section() {
  case "$1" in
    "Pipeline Position"*|\
    "Sprint Context"*|\
    "Recent Activity"*|\
    "Open Items"*|\
    "Locked Decisions"*|\
    "In-Flight Teammates"*|\
    "Context Reminders"*) return 0 ;;
    *) return 1 ;;
  esac
}

# $1 = file path, $2 = path relative to ROOT (for the message)
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
  ROW="$(grep -nE '^\|[[:space:]]*(\[core\][[:space:]]*)?14[[:space:]]*[|—-]' "$GATE_LOG" 2>/dev/null | tail -1)"

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

  if printf '%s' "$ROW" | grep -q 'PASS' && [ "$CITED" -gt "$CEILING" ]; then
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
INFLIGHT_FILE="$TMPROOT/inflight"

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
      bytes="$(wc -c < "$f" | tr -d ' ')"
      printf '%s|%s\n' "$(( bytes / BPT ))" "${f#"$ROOT"/}" >> "$POOL_TMP"
    done
  done

  POOL_TOTAL=0
  say "whole-read pool     : ${WHOLE_READ_POOL} tok  (${ARTIFACT_SHARE_PCT}% of the analyst's ${READER_WINDOW_TOKENS}-tok window, resolved from ${WINDOW_SOURCE})"
  if [ -s "$POOL_TMP" ]; then
    while IFS='|' read -r tokens rel; do
      POOL_TOTAL=$(( POOL_TOTAL + tokens ))
      [ "$QUIET" -eq 1 ] || printf '      %-44s %8s tok\n' "$rel" "$tokens"
    done < "$POOL_TMP"
  fi
  rm -f "$POOL_TMP"

  POOL_LABEL="WHOLE-READ POOL (4 planning artifacts)"
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
      check_inflight_rows "$f" "$rel"
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
if [ -s "$BREACH_FILE" ]; then
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
        rotate      -> a rotation was MISSED. Move the epoch to a dated archive
                       (Rule 25(c)); never rewrite a log.
        trim        -> trim pipeline-snapshot.md to its 7-section schema (gate-validation
                       Check 14 owns it). The gates that let it grow past 6k are the
                       finding, not the file. NOTE: In-Flight Teammates is one of the
                       seven -- it is the dispatch ledger, and deleting it is how a lead
                       re-dispatches a teammate that is still alive.
EOF
  [ "$WARN_ONLY" -eq 1 ] || RC=1
fi
rm -f "$BREACH_FILE"

# Reported SEPARATELY from the byte budget, and never folded into that count: an
# invented section is not "over the Rule 25(d) budget", and saying so would send
# the lead to the wrong remedy. Trimming bytes out of a section that should not
# exist is how 9 KB of invention survives a trim.
if [ -s "$SCHEMA_FILE" ]; then
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
      `status: idle-reusable`. That is what the column is for. Striking the row
      instead keeps every byte, keeps growing, and loses the one fact the section
      exists to carry -- who is actually outstanding.
EOF
  [ "$WARN_ONLY" -eq 1 ] || RC=1
fi
rm -f "$INFLIGHT_FILE"

if [ "$RC" -eq 0 ]; then
  say ""
  say "PASS  every measured living artifact is within its Rule 25(d) budget."
fi
exit "$RC"
