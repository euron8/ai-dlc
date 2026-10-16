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
#   --check-evidence   audit the NEWEST gate's Check 14 row (selected by heading
#                  timestamp, not position) instead of measuring artifacts.
#                  gate-validation.md Check 15 runs this. See "THE EVIDENCE
#                  CELL" below. Optionally paired with --gate-log PATH.
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
STAMPS_ONLY=""
PAYLOAD_FILE=""
WHOLE_WRITE=0

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
    #
    # `--fail-on whole-read-pool` is the one non-basename token. It hardens the POOL row,
    # and its hard verdict is "over AND no OPEN carry-over item cites WHOLE-READ-POOL"
    # (see the breach block). No basename ever hardens the pool row.
    --fail-on)        FAIL_ON="$FAIL_ON ${2:-}"; shift 2 ;;
    --warn-only)      WARN_ONLY=1; shift ;;
    --quiet)          QUIET=1; shift ;;
    --check-evidence) CHECK_EVIDENCE=1; shift ;;
    --gate-log)       GATE_LOG="${2:-}"; shift 2 ;;
    # --stamps-only <snapshot> --payload <file>: the WRITE-TIME mode, called by the
    # derivation-capture PostToolUse hook on a write to pipeline-snapshot.md. It judges only
    # the lines this write carried; see "THE WRITE-TIME MODE" below.
    --stamps-only)    STAMPS_ONLY="${2:-}"; shift 2 ;;
    --payload)        PAYLOAD_FILE="${2:-}"; shift 2 ;;
    --whole-write)    WHOLE_WRITE=1; shift ;;
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

# pool_open_item <backlog> -> prints the heading of the first OPEN item citing the pool.
# An item is a `### ` block (the CO-S<N>-<id> grammar carry-over-evaluation.md owns); it
# is OPEN when a `Status:` line in it reads OPEN as its leading word (`**Status:** OPEN`,
# `**Status:** OPEN.` and the like), and it cites the pool when the stable token
# WHOLE-READ-POOL appears in its heading or body. A CLOSED or PARTIAL item carrying the
# token does not count: a closed record is not an outstanding instruction to anybody.
pool_open_item() {
  [ -f "$1" ] || return 0
  LC_ALL=C awk '
    function done_item() { if (h != "" && open && cites) { print h; found = 1; exit } }
    /^### / { done_item(); h = $0; open = 0; cites = 0 }
    /^## /  { done_item(); h = ""; open = 0; cites = 0; next }
    h == "" { next }
    /WHOLE-READ-POOL/ { cites = 1 }
    /(^|[^A-Za-z])Status:?(\*\*)?:?[[:space:]]*(\*\*)?[[:space:]]*OPEN([^A-Za-z]|$)/ { open = 1 }
    END { if (!found) done_item() }
  ' "$1" 2>/dev/null
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
# in the consumer's settings.json, then through ai_dlc_model_window in
# ai-dlc-window.sh -- the SAME family policy the context sensor bands against, so the
# two readers cannot drift. Precedence (the library owns layers 2-5):
#   1. AI_DLC_READER_WINDOW_TOKENS (this validator only)
#   2. process env AI_DLC_MODEL_<FAMILY>_WINDOW
#   3. `.env.AI_DLC_MODEL_<FAMILY>_WINDOW` in settings.local.json, then settings.json
#      (a declaration outside 50000..2000000 is rejected, named, and falls through)
#   4. a `[1m]` suffix -> 1000000
#   5. an EXACT bare alias: fable, opus, sonnet -> 1000000 (Claude Code maps a bare
#      alias to its 1M variant); haiku -> 200000. Any other id -> 200000: a full id
#      without `[1m]` (`claude-sonnet-4-5`) is the 200K variant.
# <FAMILY> is classified from the resolved `aiDlcModels[key]` value, falling back to
# the key itself when the key is absent from `aiDlcModels`.
#
# THE `[1m]` SUBSTRING USED TO BE THE ONLY 1M ROUTE, AND A BARE ALIAS FELL THROUGH IT.
# A template mapping `sonnet` -> `sonnet` read 200000 here, so the Step 1a pool fell from
# 330000 to 66000 and an in-budget pool became a HARD_BLOCK. The suffix survives as
# layer 4; it is no longer the policy.
#
# LIBRARY UNREADABLE -> THE PRE-LIBRARY PATH, NEVER AN EXIT. The library is searched
# in validate-compact-window.sh's order (AI_DLC_WINDOW_LIB, this script's ../hooks/,
# $ROOT/.claude/hooks/, $ROOT/core/hooks/). Where none is readable this validator
# falls back to `[1m]`-or-200000 and says so in WINDOW_SOURCE: a fixture that copies
# the validator alone (retired-contract-token) must still get a pool, and the fallback
# errs in the tightening direction.
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
# a 417% breach. (That consumer has since moved to bare aliases, which is what the
# bare-alias default in layer 5 exists for.)
#
# The comment two paragraphs up already named `aiDlcModels` as the source of truth; the
# code simply never read it. The resolution idiom below is the one
# `core/hooks/ai-dlc-dispatch-guard.sh:203-205` already uses, deliberately, rather than
# a second reading of the same config.
#
# UNRESOLVED FALLS BACK TO 200000, NEVER TO THE LARGER NUMBER. No settings.json, no
# jq, no `aiDlcRoles.analyst`, and a model string naming no known family all mean the
# same thing: we do not know. 200K is the OTHER family's default in the shared library
# (the same value the context sensor assumes for OTHER), so the unknown case tightens
# the gate rather than opening it. A key absent from `aiDlcModels` is classified from
# the key itself: `opus` dangling is still an opus alias, `mystery` dangling is OTHER
# and tightens. A consumer whose analyst
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
WINDOW_LIB=""
if [ -n "${AI_DLC_WINDOW_LIB:-}" ] && [ -r "${AI_DLC_WINDOW_LIB}" ]; then
  WINDOW_LIB="$AI_DLC_WINDOW_LIB"
elif [ -r "${AI_DLC_SELF_DIR}/../hooks/ai-dlc-window.sh" ]; then
  WINDOW_LIB="${AI_DLC_SELF_DIR}/../hooks/ai-dlc-window.sh"
elif [ -r "${ROOT}/.claude/hooks/ai-dlc-window.sh" ]; then
  WINDOW_LIB="${ROOT}/.claude/hooks/ai-dlc-window.sh"
elif [ -r "${ROOT}/core/hooks/ai-dlc-window.sh" ]; then
  WINDOW_LIB="${ROOT}/core/hooks/ai-dlc-window.sh"
fi
if [ -n "$WINDOW_LIB" ]; then
  # shellcheck source=/dev/null
  . "$WINDOW_LIB" 2>/dev/null || WINDOW_LIB=""
fi
command -v ai_dlc_model_window >/dev/null 2>&1 || WINDOW_LIB=""

# Echoes "<window>|<source>".
resolve_reader_window() {
  settings="$ROOT/.claude/settings.json"
  [ -r "$settings" ] || { printf '200000|no .claude/settings.json'; return; }
  command -v jq >/dev/null 2>&1 || { printf '200000|no jq'; return; }
  rrw_key="$(jq -r '.aiDlcRoles.analyst.model // empty' "$settings" 2>/dev/null || true)"
  [ -n "$rrw_key" ] || { printf '200000|no aiDlcRoles.analyst'; return; }
  rrw_model="$(jq -r --arg k "$rrw_key" '.aiDlcModels[$k] // empty' "$settings" 2>/dev/null || true)"
  [ -n "$rrw_model" ] || rrw_model="$rrw_key"
  if [ -n "$WINDOW_LIB" ]; then
    rrw_out="$(ai_dlc_model_window "$rrw_model" "$ROOT/.claude/settings.local.json" "$settings" 2>/dev/null || true)"
    rrw_win="${rrw_out%%|*}"
    rrw_src="${rrw_out##*|}"
    case "${rrw_win:-}" in ''|*[!0-9]*) ;; *)
      printf '%s|aiDlcRoles.analyst -> %s, %s' "$rrw_win" "$rrw_model" "$rrw_src"; return ;;
    esac
  fi
  case "$rrw_model" in
    *'[1m]'*) printf '1000000|aiDlcRoles.analyst -> %s, [1m] suffix (fallback: ai-dlc-window.sh not found)' "$rrw_model" ;;
    *)        printf '200000|aiDlcRoles.analyst -> %s, 200000 (fallback: ai-dlc-window.sh not found)' "$rrw_model" ;;
  esac
}

if [ -n "${AI_DLC_READER_WINDOW_TOKENS:-}" ]; then
  READER_WINDOW_TOKENS="$AI_DLC_READER_WINDOW_TOKENS"
  WINDOW_SOURCE="AI_DLC_READER_WINDOW_TOKENS"
else
  _RRW="$(resolve_reader_window)"
  READER_WINDOW_TOKENS="${_RRW%%|*}"
  WINDOW_SOURCE=".claude/settings.json ${_RRW#*|}"
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
#
# THE LEADING DELIMITER IS OPTIONAL, AND REQUIRING IT MADE THIS CHECK BLIND TO THE
# ONE FILE IT EXISTS FOR. Markdown renders a table row with or without the opening
# `|`, and the reference consumer writes the bare form. Measured on its live
# snapshot: 5 lines in the section, 0 of them leading-pipe, so the gate admitted 0
# rows against a control of 2 on the piped shape in the same invocation. Its rows
# carry `delivered` and `stopped (...)`, and `delivered` is not a member of the set
# above -- the PASS was this gate never seeing the rows, not the rows being legal.
# The sibling check_inflight_rows never carried the gate (its awk is `f && /~~/`,
# content-keyed on the strikethrough), so two of the section's three readers gated
# on the delimiter and one did not, with nothing binding them to agree.
#
# THE HEADER IS PIPELESS TOO, AND SEPARATING IT FROM A DATA ROW IS THE WHOLE
# NARROWING. Dropping the gate to a bare `/\|/` is what the shape suggests and it
# is wrong: measured over the reference consumer's 9 In-Flight-bearing files, it
# reports 7 where the shipped gate reports 3, and one of the 4 new findings is
# PROSE -- an archived note ending `git log @{u}..HEAD --oneline | wc -l`, whose
# last pipe-delimited field is a shell fragment. So a line with no leading `|` must
# also carry the HEADER'S OWN COLUMN COUNT, recorded at the row that declares
# `status`. That is derived from the table, not a fitted constant, and it takes the
# false positive to zero: 6 findings, the 3 the gate already had plus exactly the 3
# live consumer rows. The header itself still exits at the `s == "status"` arm one
# line above, before any column test, so it is never scored as a data row.
#
# THE WIDTH TEST IS RESTRICTED TO PIPELESS LINES, AND THAT IS NOT COSMETIC. Applied
# to every row it is a REGRESSION, because a piped row whose cell contains a stray
# `|` splits one field wide and would be acquitted. Measured on the discriminating
# input -- two piped rows with illegal tokens, one carrying `x|y` inside a cell --
# the uniform form convicts 1 where the shipped gate convicts 2, and this form
# convicts 2. Every finding the leading-pipe gate produced is still produced: the
# relaxation is strictly additive, asserted as a superset over the same 9 files.
# -----------------------------------------------------------------------------
check_inflight_status() {
  awk '
    /^## In-Flight Teammates/ { f=1; declared=0; ncols=0; next }
    /^## /                    { f=0 }
    !f                        { next }
    !/\|/                     { next }        # prose, "(none)", blank lines
    /~~/                      { next }        # struck row: check_inflight_rows owns it
    {
      row = $0
      piped = ($0 ~ /^[[:space:]]*\|/)         # leading-delimiter shape, or the bare one
      sub(/^[[:space:]]*\|/, "", row)
      sub(/\|[[:space:]]*$/, "", row)
      n = split(row, cell, "|")
      if (n < 2) next                          # too few columns to carry a status
      s = cell[n]
      gsub(/`/, "", s)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
      if (s == "status") { declared = 1; ncols = n; next } # the header declares the column
      if (!declared) next                      # no status column: nothing to check
      if (!piped && n != ncols) next           # a pipeless line needs the header width
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

# -----------------------------------------------------------------------------
# A SNAPSHOT STAMP LATER THAN THE CLOCK IS FABRICATED, AND NOTHING COMPARED THEM.
#
# A `## Recent Activity` line and an In-Flight `dispatched-at` cell each record WHEN
# something happened. One stamped after the current UTC time records an event that has
# not happened yet. Measured on the reference consumer across sprints 317-318: 69 of 163
# snapshot revisions carried a stamp more than 10 minutes after their own commit time
# (figures beside FUTURE_SLACK_S) -- the defect is born at snapshot WRITE time, which is
# why this arm lives in the branch Check 14 runs at every gate write and not only at the
# resume.
#
# THE GRAMMAR IS NARROW ON PURPOSE. Only a single full stamp is checked:
# `YYYY-MM-DDTHH:MM(:SS)?Z`, NOT followed by `-`, an en dash, an arrow or a digit, and
# NOT preceded by `~`, `-`, an en dash or an arrow. Everything else is skipped:
#   a range (`T09:55Z-10:45Z`, `T09:55-10:45Z`) -- the end is a plan, not a record, and
#     the `-HH:MMZ` suffix must never be read as a UTC offset;
#   a SPACED range start (`T09:55Z - 10:45Z`, an en dash, an arrow, `T09:55Z to 10:45Z`) --
#     only when a digit follows the separator, so `T12:00Z - DEPLOY DONE` is still read.
#     The END of a spaced range is a full stamp preceded by a space and IS read: a bullet's
#     own `- ` is the same two bytes, so a preceding-separator skip would acquit every line;

#   an approximation (`~2026-...`) and an `x` placeholder (`Txx:xxZ`);
#   a date-only stamp and a bare `T09:55Z` -- neither names an instant.
# The FP set and how it reached zero are recorded beside FUTURE_SLACK_S below.
#
# IN-FLIGHT IS READ BY COLUMN, NEVER BY LINE. The status cell legitimately carries
# `in-flight, since <stamp>`; only the `dispatched-at` column the header declares is
# read, located exactly as check_inflight_status locates `status`.
#
# THE HISTORY FILE IS NEVER READ. pipeline-snapshot-history.md is write-only (Rule 25a);
# the stamps that matter are the ones a gate, a resume or a recovery will read.
#
# Epoch arithmetic is done in awk by hand: BSD awk has no mktime, and BSD date has no -d.
# -----------------------------------------------------------------------------
# A stamp more than this many seconds ahead of now is refused. Ten minutes absorbs a lead
# rounding to the next quarter hour and ordinary clock skew between hosts.
#
# THE FALSE-POSITIVE SET IS ZERO, AND HERE IS HOW IT WAS MEASURED. Population: the
# reference consumer's `git log --since=2026-10-09 -- _bmad-output/pipeline-snapshot.md`,
# 163 revisions spanning sprints 317-318, each run with now = that revision's own commit
# time. 69 revisions fire, 214 findings (127 Recent Activity, 87 dispatched-at), 201
# distinct stamp-lines. Every fire was re-derived independently (BSD `date -j` parse
# minus the commit time): 0 fall inside the 600 s slack, the smallest lead is 10 min.
# All 59 distinct fired line texts were read: each records an event (DONE, MERGED,
# HANDOFF, a dispatch) stamped after the commit that wrote it, none states a plan.
# THE NARROWING: 54 range forms (`T..Z-HH:MM`, en dash, arrow) sit in the same corpus,
# and every one is skipped; read as single stamps their END would fire as a plan. The
# In-Flight status cell's `since <stamp>` is excluded by reading the declared column.
# The SPACED-range skip (` - `, en dash, arrow, ` to `, then a digit) was re-measured on the
# same 163 revisions: 69 fire, 214 findings, 0 inside the slack -- identical, because the
# corpus carries one spaced range (` to `), and its stamps are past. The digit requirement is
# what keeps ` - DEPLOY DONE` read; the self-probe seeds both sides of it.
#
# A RECENT ACTIVITY LINE THAT LEADS WITH A STAMP HAS ONLY THAT STAMP READ. The whole-line scan
# refused a CORRECT future value: an operator-set monitor deadline recorded in an entry body
# (`2026-10-21T16:08:54Z`, 8294 min ahead), whose remedy told the lead to overwrite the ruling
# with `date -u`. Re-measured over the reference consumer's full committed history, 546
# revisions, now = each commit time: the whole-line scan 344 findings, this rule 342, 0 new.
# The 2 it acquits are ONE stamp named twice in one line, `recheck not before <stamp>` -- a
# recorded deadline, the case this narrowing exists for. LEADING-ONLY WAS MEASURED AND
# REJECTED: it acquitted 18, and 16 were true positives in the legacy form
# `gate PASSED -- <stamp>`, which puts the entry stamp LAST. So a line with no leading stamp
# is still read whole; that is where a future entry stamp lives when it is not first.
FUTURE_SLACK_S=600
check_future_stamps() { # check_future_stamps <file> <rel> <now-epoch>
  LC_ALL=C awk -v now="$3" -v slack="$FUTURE_SLACK_S" -v ART="$2" '
    function epoch(t,   y, mo, d, h, mi, s, yy, mm) {
      y = substr(t, 1, 4) + 0; mo = substr(t, 6, 2) + 0; d = substr(t, 9, 2) + 0
      h = substr(t, 12, 2) + 0; mi = substr(t, 15, 2) + 0
      s = (substr(t, 17, 1) == ":") ? substr(t, 18, 2) + 0 : 0
      yy = (mo <= 2) ? y - 1 : y; mm = (mo > 2) ? mo - 3 : mo + 9
      return ((365 * yy + int(yy / 4) - int(yy / 100) + int(yy / 400) \
               + int((153 * mm + 2) / 5) + d - 1 - 719468) * 86400) + h * 3600 + mi * 60 + s
    }
    function adj(c) { return (c == "-" || c == "~") }
    function wide(c3) { return (c3 == "\342\200\223" || c3 == "\342\206\222") }
    # A SPACED range start: one space, then `-`, an en dash, an arrow or the word `to`, then
    # an optional space, then a DIGIT. The digit is what separates `T09:55Z - 10:45Z` (a
    # range, skipped) from `T09:55Z - DEPLOY DONE` (a single stamp and a description, read).
    function spaced(s, b,   n) {
      if (substr(s, b, 1) != " ") return 0
      n = 0
      if (substr(s, b + 1, 1) == "-") n = 1
      else if (wide(substr(s, b + 1, 3))) n = 3
      else if (substr(s, b + 1, 2) == "to") n = 2
      if (!n) return 0
      n = b + 1 + n
      if (substr(s, n, 1) == " ") n++
      return (substr(s, n, 1) ~ /[0-9]/)
    }
    function scan(str, where,   pos, rest, t, a, b, b3, p, p3, ep) {
      pos = 0
      rest = str
      while (match(rest, /[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9](:[0-9][0-9])?Z/)) {
        t = substr(rest, RSTART, RLENGTH)
        a = pos + RSTART
        b = a + RLENGTH
        rest = substr(rest, RSTART + RLENGTH)
        pos = b - 1
        p = (a > 1) ? substr(str, a - 1, 1) : ""
        p3 = (a > 3) ? substr(str, a - 3, 3) : ""
        b3 = substr(str, b, 3)
        if (adj(p) || wide(p3)) continue
        if (substr(str, b, 1) ~ /[-0-9]/ || wide(b3)) continue
        if (spaced(str, b)) continue
        ep = epoch(t)
        if (ep - now > slack)
          printf "FUTURE  %s line %d: %s is %d min ahead of now (%s)\n", ART, NR, t, int((ep - now) / 60), where
      }
    }
    /^## / {
      sec = $0; sub(/^##[[:space:]]*/, "", sec)
      ra = (substr(sec, 1, 15) == "Recent Activity")
      inf = (substr(sec, 1, 19) == "In-Flight Teammates")
      col = 0; ncols = 0
      next
    }
    # A LINE THAT LEADS WITH A STAMP HAS ONLY THAT STAMP READ: the first token after an
    # optional list marker (`- `, `* `, `+ `, `N. `) and an optional `**`. That stamp is
    # when the entry happened; a later one in the same line is a date it RECORDS -- an
    # operator-set deadline, a planned window. The 8 bytes after the stamp are kept so the
    # range skips still see a range end. A line with NO leading stamp is read whole, as
    # before: the legacy form `gate PASSED -- <stamp>` puts the entry stamp at the END.
    ra {
      ld = $0
      if (match(ld, /^[[:space:]]*([-*+]|[0-9]+\.)?[[:space:]]*(\*\*)?/)) ld = substr(ld, RLENGTH + 1)
      if (match(ld, /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9](:[0-9][0-9])?Z/))
        scan(substr(ld, 1, RLENGTH + 8), "Recent Activity")
      else
        scan($0, "Recent Activity")
      next
    }
    inf && /\|/ {
      row = $0
      piped = ($0 ~ /^[[:space:]]*\|/)
      sub(/^[[:space:]]*\|/, "", row); sub(/\|[[:space:]]*$/, "", row)
      n = split(row, cell, "|")
      for (i = 1; i <= n; i++) {
        c = cell[i]; gsub(/`/, "", c); gsub(/^[[:space:]]+|[[:space:]]+$/, "", c)
        if (c == "dispatched-at") { col = i; ncols = n; next }
      }
      if (!col || col > n) next
      if (!piped && n != ncols) next
      scan(cell[col], "In-Flight Teammates dispatched-at")
    }
  ' "$1" 2>/dev/null
}

# -----------------------------------------------------------------------------
# A PLACEHOLDER WHERE A STAMP BELONGS. `YYYY-MM-DDTHH:` followed by anything but two digits
# (`T02:2xZ`, `T23:5Z`, `T11:2x EDT`) is an attempted stamp the author did not take from the
# clock. The future-stamp grammar above does not match it at all, so it reads as no stamp.
#
# EXEMPT: an `HH` that is not two digits (`Txx:xxZ`, the declared placeholder form), and a
# stamp preceded by `~` (an explicit approximation). Both are what the remedy asks for.
#
# WRITE-TIME ONLY, NEVER IN THE GATE SCAN. Measured over the reference consumer's 546
# committed snapshot revisions: this grammar fires in 45 revisions, 79 findings, 35 distinct
# texts, and every one is a real placeholder -- including the NEWEST revision's Open Items
# line `(2026-10-15T19:3xZ)`. In the gate scan that is text written before this rule existed
# blocking the next gate; at write time it is feedback on the line being written now. So the
# only caller is --stamps-only, whose input is the write payload.
check_malformed_stamps() { # check_malformed_stamps <file> <rel>
  LC_ALL=C awk -v ART="$2" '{
    rest = $0; pos = 0
    while (match(rest, /[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:/)) {
      a = pos + RSTART; b = a + RLENGTH
      rest = substr(rest, RSTART + RLENGTH); pos = b - 1
      if (substr($0, b, 2) ~ /^[0-9][0-9]$/) continue
      if (a > 1 && substr($0, a - 1, 1) == "~") continue
      printf "MALFORMED  %s line %d: %s is not a stamp\n", ART, NR, substr($0, a, 17)
    }
  }' "$1" 2>/dev/null
}

# -----------------------------------------------------------------------------
# A BACK-DATED dispatched-at. The In-Flight `dispatched-at` cell decides whether a
# deliverable on disk is newer than its dispatch (`_gate-procedures.md` passes it as the
# beat's `--since`). A stamp EARLIER than the dispatch widens that window to accept a file
# written before the teammate existed. Measured on the reference consumer: a resumed lead
# wrote `dispatched-at 02:15:40Z` for an Agent call at 02:17:32Z, with `date -u -v-2M`.
#
# THE JOIN: each row is judged against the spawn ledger (`spawn-ledger.jsonl`, written by
# ai-dlc-dispatch-guard.sh AT the dispatch). Same-role rows are those whose ledger `role`
# OR `name` equals the leading word of the row role cell, lowercased (`pm-escalated` is
# `name` on a `role: pm` row; `dev (sonnet)` is `dev`). Let B be the nearest same-role
# dispatch at or before stamp+T and A the nearest after it. FIRE when A exists and is
# nearer than B: the stamp sits before the dispatch it most plausibly records. A row stamped
# LATE (after its dispatch) stays quiet; this arm is about back-dating only.
#
# A ROW WHOSE AGENT CELL IS A LEDGER `name` JOINS ON THAT NAME ONLY. The nearest-dispatch rule
# alone reads an honest LATE row as back-dated when the NEXT same-role dispatch lands closer
# than its own: `dev-a` stamped 01:22:00 for its 01:19:55 dispatch, with `dev-b` dispatched at
# 01:23:30, read as 90 s early. Joined on `dev-a` it is 125 s late and quiet. A row whose agent
# cell names no ledger row (the motivating `fold`) still falls to the role rule. Re-measured on
# the corpus: the one in-flight fire is an exact-name join (`adversary-s301-prd-validate`,
# whose only ledger row is 254 s after the stamp) and stays.
# T is 60s for a stamp with seconds and 120s for minute-only, which rounds down by up to 59.
#
# ONLY ROWS WHOSE STATUS IS `in-flight`. A delivered row no longer decides anything.
#
# THE FALSE-POSITIVE SET IS ZERO, AND HERE IS THE POPULATION. The reference consumer's 546
# committed snapshot revisions, each against the ledger committed in the same revision:
# 40 carry a ledger and a dated row, 85 row-judgements. All statuses: 4 distinct rows fire,
# 141-680 s early, each with NO same-role dispatch before it and the next one after it --
# true back-dates (two match by exact agent name). In-flight only: 1 fires, 0 in the newest
# revision. The worst honest row in that corpus is 41 s early. The motivating row was never
# committed, so the receipt is the seeded probe, not this zero.
#
# SKIPPED, each visibly or by construction: no ledger file or no jq (one SKIP line, never a
# silent pass); ledger rows with no `ts` (14 historical rows carry a hand-written
# `dispatched_at` instead); a header with no `role` column; a role with no ledger row at all
# (not evidence). A row that PREDATES every ledger row is NOT skipped: it has no dispatch
# before it, so it fires only when a same-role dispatch follows -- and a skip keyed on the
# ledger first `ts` would hide exactly a back-date on a fresh ledger. Measured without that
# skip over the same corpus: 1 in-flight fire, unchanged.
# KNOWN BLIND SPOT: a DENIED dispatch writes no ledger row (dispatch-guard.sh, the deny
# path), so a row stamped honestly at a refused attempt and then re-sent reads as back-dated
# by the gap between the two calls. Re-stamp the row from the dispatch that went through.
BACKDATE_TOL_S=60
check_backdated_dispatch() { # check_backdated_dispatch <file> <rel> <ledger>
  [ -s "$3" ] || { printf 'SKIP  %s: no spawn ledger at %s, dispatched-at not compared\n' "$2" "$3"; return 0; }
  command -v jq >/dev/null 2>&1 || { printf 'SKIP  %s: no jq, dispatched-at not compared\n' "$2"; return 0; }
  jq -R -r 'fromjson? | select(type == "object" and (.ts | type) == "string")
    | (.ts | fromdateiso8601? ) as $e | select($e != null)
    | [$e, ((.role // "") | ascii_downcase), ((.name // "") | ascii_downcase)] | @tsv' "$3" 2>/dev/null \
  | LC_ALL=C awk -F'\t' -v ART="$2" -v tol="$BACKDATE_TOL_S" -v snap="$1" '
    function epoch(t,   y, mo, d, h, mi, s, yy, mm) {
      y = substr(t, 1, 4) + 0; mo = substr(t, 6, 2) + 0; d = substr(t, 9, 2) + 0
      h = substr(t, 12, 2) + 0; mi = substr(t, 15, 2) + 0
      s = (substr(t, 17, 1) == ":") ? substr(t, 18, 2) + 0 : 0
      yy = (mo <= 2) ? y - 1 : y; mm = (mo > 2) ? mo - 3 : mo + 9
      return ((365 * yy + int(yy / 4) - int(yy / 100) + int(yy / 400) \
               + int((153 * mm + 2) / 5) + d - 1 - 719468) * 86400) + h * 3600 + mi * 60 + s
    }
    FILENAME != snap { n++; T[n] = $1 + 0; R[n] = $2; N[n] = $3; next }
    /^## / { sec = $0; sub(/^##[[:space:]]*/, "", sec)
             inf = (substr(sec, 1, 19) == "In-Flight Teammates"); dcol = rcol = scol = 0; next }
    !inf || !/\|/ { next }
    {
      row = $0; sub(/^[[:space:]]*\|/, "", row); sub(/\|[[:space:]]*$/, "", row)
      m = split(row, cell, "|")
      for (i = 1; i <= m; i++) { c = cell[i]; gsub(/`/, "", c); gsub(/^[[:space:]]+|[[:space:]]+$/, "", c); cell[i] = c }
      for (i = 1; i <= m; i++) if (cell[i] == "dispatched-at") {
        dcol = i; rcol = scol = 0
        for (j = 1; j <= m; j++) { if (cell[j] == "role") rcol = j; if (cell[j] == "status" || cell[j] == "state") scol = j }
        next
      }
      if (!dcol || !rcol || !scol || dcol > m || rcol > m || scol > m) next
      if (tolower(cell[scol]) !~ /^in-flight/) next
      if (!match(cell[dcol], /[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9](:[0-9][0-9])?Z/)) next
      st = substr(cell[dcol], RSTART, RLENGTH); t = epoch(st)
      if (!match(cell[rcol], /[A-Za-z][A-Za-z-]*/)) next
      role = tolower(substr(cell[rcol], RSTART, RLENGTH))
      ag = tolower(cell[1]); named = 0
      for (k = 1; k <= n; k++) if (N[k] == ag) { named = 1; break }
      w = (length(st) == 20) ? tol : 2 * tol
      hb = 0; ha = 0
      for (k = 1; k <= n; k++) {
        if (named) { if (N[k] != ag) continue }
        else if (R[k] != role && N[k] != role) continue
        if (T[k] <= t + w) { if (!hb || T[k] > B) { B = T[k]; hb = 1 } }
        else if (!ha || T[k] < A) { A = T[k]; ha = 1 }
      }
      if (ha && (!hb || A - t < t - B))
        printf "BACKDATED  %s line %d: %s dispatched-at %s is %d s before its dispatch in the spawn ledger\n", ART, FNR, role, st, A - t
    }
  ' - "$1"
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
# SCOPE IS ONE ROW: THE NEWEST GATE'S. Older rows were written under older
# rules; indicting them would make this arm unpassable on a real consumer and
# it would be disabled rather than obeyed. WHICH row is newest is NOT
# positional. The live log is rotated per sprint, so it holds one sprint's
# sections, and measured on the reference consumer: its committed history APPENDS, one
# sprint's log PREPENDS (newest section first, so `tail -1` read the oldest
# gate's 3052 tok instead of the audited 5076), and backfill logs put the
# newest section in the MIDDLE. Any positional rule is right on one of those
# and wrong on another. The row is therefore chosen by each section's
# HEADING-BLOCK timestamp (step 12's `Timestamp:`), and the arm refuses rather
# than guess when a row-bearing section has none or two sections tie.
#
# The snapshot's `last_gate_passed` is a CROSS-CHECK, never the key. Searching
# section bodies for it was measured and rejected: a stale snapshot names the
# PREVIOUS gate, whose section then wins, so the artifact under audit chooses
# its own evidence.
# -----------------------------------------------------------------------------
if [ "$CHECK_EVIDENCE" -eq 1 ]; then
  # DISCOVERY PREFERS THE CANONICAL LIVE PATH. The `find` below matches on
  # BASENAME ALONE across the whole of `_bmad-output`, so any second
  # `gate-log.md` anywhere under that tree qualifies -- and readdir order, not
  # recency, decides which one wins. Measured on a real consumer holding three:
  # the winner was `planning-artifacts/s300/archive/cycle-1/gate-log.md`, an
  # archived copy from a closed sprint, and Check 15 printed a normal PASS on a
  # row belonging to a different sprint while the live log's row cited no
  # measurement at all. That is fails-open: the arm reported on a file nobody
  # was gating.
  #
  # `archive/` is where those extra copies come from TODAY; it is not the
  # condition. Excluding that one path segment would leave every other second
  # copy winning, and would REGRESS the consumer whose only gate log is an
  # archived one -- that tree passes today and must keep passing. So the
  # preference is stated positively and the discovery below is kept UNCHANGED
  # as the fallback: a tree with no canonical live log resolves exactly as it
  # did before, and a tree with none at all still reaches the loud failure.
  if [ -z "$GATE_LOG" ]; then
    if [ -f "$ROOT/_bmad-output/implementation-artifacts/gate-log.md" ]; then
      GATE_LOG="$ROOT/_bmad-output/implementation-artifacts/gate-log.md"
    else
      GATE_LOG="$(find "$ROOT/_bmad-output" -type f -name 'gate-log.md' 2>/dev/null | head -1)"
    fi
  fi
  [ -n "$GATE_LOG" ] && [ -f "$GATE_LOG" ] || {
    echo "FAIL: no gate-log.md found under $ROOT/_bmad-output (pass --gate-log PATH)" >&2
    exit 1; }

  # Both row shapes in use. The long form is gate-validation.md's own
  # (`| [core] 14 - Update pipeline snapshot | PASS (lead) | <evidence> |`); the
  # short form appears in the compact per-check tables some gates append
  # (`| 14 | lead | <evidence> |`). Matching only the long one would pass the
  # short one vacuously.
  ROWLINES="$(grep -nE '^\|[[:space:]]*(\[core\][[:space:]]*)?14[[:space:]]*(\||—|-)' "$GATE_LOG" 2>/dev/null | cut -d: -f1 | tr '\n' ' ')"

  if [ -z "${ROWLINES// /}" ]; then
    echo "FAIL: no Check 14 row found in ${GATE_LOG#"$ROOT"/}" >&2
    echo "      Check 15 cannot verify an assertion that was never recorded." >&2
    exit 1
  fi

  # SECTION SELECTION. Partition on `## ` headings; a section heading block runs
  # from its heading to its first table line. One row-bearing section needs no
  # choice. Otherwise every row-bearing section must carry an ISO timestamp in
  # its heading block (minute precision normalised to :00), and the greatest
  # one must be unique. Output: ONE|NOTS|TIE|NEWEST, tab-separated.
  SEL="$(LC_ALL=C awk -v rows="$ROWLINES" '
    function stamps(s,   out, t) {
      out = ""
      while (match(s, /[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9](:[0-9][0-9])?/)) {
        t = substr(s, RSTART, RLENGTH)
        if (RLENGTH == 16) t = t ":00"
        out = out " " t
        s = substr(s, RSTART + RLENGTH)
      }
      return out
    }
    BEGIN { k = split(rows, r, " "); for (i = 1; i <= k; i++) isrow[r[i]] = 1; sec = 0; inb = 1 }
    /^## /          { sec = NR; inb = 1 }
    inb && /^\|/    { inb = 0 }
    inb             { ts[sec] = ts[sec] stamps($0) }
    (NR in isrow)   { if (!(sec in last)) order[++n] = sec; last[sec] = NR }
    END {
      if (n == 1) { printf "ONE\t%s\t%s\n", order[1], last[order[1]]; exit }
      best = ""; tie = ""
      for (i = 1; i <= n; i++) {
        s = order[i]; m = ""
        c = split(ts[s], a, " ")
        for (j = 1; j <= c; j++) if (a[j] > m) m = a[j]
        if (m == "") { printf "NOTS\t%s\n", s; exit }
        if (m > best) { best = m; bsec = s; tie = "" }
        else if (m == best) tie = s
      }
      if (tie != "") { printf "TIE\t%s\t%s\t%s\n", bsec, tie, best; exit }
      printf "NEWEST\t%s\t%s\t%s\t%s\n", bsec, last[bsec], best, ts[bsec]
    }' "$GATE_LOG")"
  IFS="$(printf '\t')" read -r SEL_KIND SEL_SEC SEL_ROW SEL_TS SEL_ALL <<<"$SEL"

  case "$SEL_KIND" in
    ONE|NEWEST) ;;
    NOTS)
      echo "FAIL: ${GATE_LOG#"$ROOT"/} holds Check 14 rows in more than one section, and the section at line ${SEL_SEC} carries no ISO timestamp in its heading block." >&2
      echo "      Check 15 selects the newest gate by the heading block's Timestamp (gate-validation.md step 12) and will not pick a row by position." >&2
      exit 1 ;;
    TIE)
      echo "FAIL: ${GATE_LOG#"$ROOT"/} sections at lines ${SEL_SEC} and ${SEL_ROW} tie on the newest heading timestamp ${SEL_TS}." >&2
      echo "      Check 15 selects the newest gate by the heading block's Timestamp (gate-validation.md step 12) and will not pick a row by position." >&2
      exit 1 ;;
    *)
      echo "FAIL: could not partition ${GATE_LOG#"$ROOT"/} into sections." >&2
      exit 1 ;;
  esac
  ROW="${SEL_ROW}:$(sed -n "${SEL_ROW}p" "$GATE_LOG")"

  # SNAPSHOT CROSS-CHECK, several row-bearing sections only. The key is the
  # first ISO date in the `last_gate_passed` bullet and its indented
  # continuation lines, with its time when one follows it, cut at `(prior)`,
  # which introduces the previous gate.
  # Applied only to the canonical live log: an archived-only or --gate-log
  # elsewhere tree has no snapshot of its own gate and must keep passing.
  if [ "$SEL_KIND" = "NEWEST" ]; then
    SNAP_KEY="$(LC_ALL=C awk '
      on && (/^[[:space:]]*$/ || /^[^[:space:]]/ || /^[[:space:]]*[-*][[:space:]]/) { exit }
      !on && /^[[:space:]]*[-*][[:space:]].*last_gate_passed/ { on = 1 }
      on { buf = buf " " $0 }
      END {
        i = index(buf, "(prior)"); if (i) buf = substr(buf, 1, i - 1)
        if (match(buf, /[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/)) {
          t = substr(buf, RSTART, 10); rest = substr(buf, RSTART + 10)
          if (match(rest, /^T[0-9][0-9]:[0-9][0-9](:[0-9][0-9])?/)) {
            t = t substr(rest, 1, RLENGTH); if (RLENGTH == 6) t = t ":00"
          }
          print t
        }
      }' "$ROOT/_bmad-output/pipeline-snapshot.md" 2>/dev/null)"
    LIVE_DIR="$ROOT/_bmad-output/implementation-artifacts"
    if [ "$GATE_LOG" != "$LIVE_DIR/gate-log.md" ]; then
      SNAP_NOTE="not checked: not the canonical live gate log"
    elif [ -z "$SNAP_KEY" ]; then
      SNAP_NOTE="absent"
    else
      SNAP_NOTE="$SNAP_KEY"
      # A DATE-ONLY key (`2026-08-13`, no time) is still a key. Measured on a
      # consumer snapshot written that way: read as absent, the cross-check
      # was skipped and a row two days older passed. It matches the DATE of
      # the selected section's newest heading timestamp, and nothing coarser.
      SNAP_OK=0
      if [ "${#SNAP_KEY}" -eq 10 ]; then
        [ "$SNAP_KEY" = "${SEL_TS%%T*}" ] && SNAP_OK=1
      else
        case " $SEL_ALL " in *" $SNAP_KEY "*) SNAP_OK=1 ;; esac
      fi
      if [ "$SNAP_OK" -eq 0 ]; then
        # WHICH gate the key names decides the message. Measured on a consumer
        # state whose snapshot named an implementation gate-3: that section
        # logged no Check 14 row at all, so "stale snapshot" sent the reader
        # to the wrong file. Search every heading block for the key and name
        # the newest section carrying it; the refusal stands either way.
        KEY_HIT="$(LC_ALL=C awk -v rows="$ROWLINES" -v key="$SNAP_KEY" '
          BEGIN { k = split(rows, r, " "); for (i = 1; i <= k; i++) isrow[r[i]] = 1; inb = 1 }
          /^## /        { sec = NR; inb = 1 }
          inb && /^\|/  { inb = 0 }
          (NR in isrow) { has[sec] = 1 }
          inb {
            s = $0
            while (match(s, /[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9](:[0-9][0-9])?/)) {
              t = substr(s, RSTART, RLENGTH); if (RLENGTH == 16) t = t ":00"
              s = substr(s, RSTART + RLENGTH)
              hit = (length(key) == 10) ? (substr(t, 1, 10) == key) : (t == key)
              if (hit && t >= best) { best = t; bsec = sec }
            }
          }
          END { if (bsec != "") printf "%s\t%s\n", bsec, (bsec in has) ? 1 : 0 }' "$GATE_LOG")"
        IFS="$(printf '\t')" read -r HIT_SEC HIT_ROW <<<"$KEY_HIT"
        if [ -n "$HIT_SEC" ] && [ "$HIT_ROW" = "0" ]; then
          echo "FAIL: the snapshot's last_gate_passed names ${SNAP_KEY}, the gate whose section heads line ${HIT_SEC}: $(sed -n "${HIT_SEC}p" "$GATE_LOG" | cut -c1-120)" >&2
          echo "      the gate the snapshot names logged no Check 14 row. Check 15 has no evidence cell for the gate under audit; the newest section that carries one is line ${SEL_SEC} (${SEL_TS})." >&2
          exit 1
        fi
        echo "FAIL: the snapshot's last_gate_passed names ${SNAP_KEY}, which is not a heading timestamp of the newest gate section (line ${SEL_SEC}, ${SEL_TS})." >&2
        echo "      The snapshot is stale or names a different gate than the newest entry in the canonical live gate log; Check 15 will not verify either against the other." >&2
        exit 1
      fi
    fi
  fi

  say "gate log            : ${GATE_LOG#"$ROOT"/}"
  [ "$SEL_KIND" = "ONE" ] || \
    say "selected section    : line ${SEL_SEC} (newest heading timestamp ${SEL_TS}; snapshot key ${SNAP_NOTE})"
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
FUTURE_FILE="$TMPROOT/future-stamp"
BACKDATE_FILE="$TMPROOT/backdated"

# THE CLOCK THE FUTURE-STAMP ARM COMPARES AGAINST. `date -u +%s` is the only portable
# spelling; AI_DLC_SNAPSHOT_NOW_EPOCH replaces it so a fixture can pin "now" and a
# history sweep can replay each revision against its own commit time. A clock that
# cannot be read is a refusal, never a skip: a skipped comparison reads exactly like a
# snapshot with no future stamp in it.
SNAP_NOW="${AI_DLC_SNAPSHOT_NOW_EPOCH:-}"
[ -n "$SNAP_NOW" ] || SNAP_NOW="$(date -u +%s 2>/dev/null)"
case "$SNAP_NOW" in
  ''|*[!0-9]*)
    echo "FAIL: cannot read the UTC clock for the snapshot future-stamp check (got '${SNAP_NOW}')." >&2
    echo "      Set AI_DLC_SNAPSHOT_NOW_EPOCH to a whole number of seconds, or fix \`date -u +%s\`." >&2
    exit 2 ;;
esac

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

# THE FUTURE-STAMP AND POOL-ITEM SELF-PROBES, for the same reason as the one above and
# with the same posture: fatal, both directions, on mktemp files, before the corpus. Now
# is pinned to 2026-01-01T00:00:00Z (1767225600) so the probe never depends on the clock.
#   OFFENDER   a Recent Activity stamp 60 min ahead, one 120 min ahead followed by ` - text`
#              (the spaced-range skip must not acquit it), a dispatched-at cell 60 min ahead
#   NEAR-MISS  a range with an offset-shaped suffix, spaced ranges (` - `, ` to `, arrow), a
#              stamp 5 min ahead, a date-only stamp, an `x` placeholder, a `~` approximation,
#              a CLOCK CORRECTION line naming the old stamps as bare HH:MMZ (the remedy's own
#              form, which must not re-fire), a future deadline in the body of a line that
#              leads with a past stamp, and a future `since` in the STATUS cell
FPROBE="$TMPROOT/probe-future.md"
{
  printf '## Recent Activity\n'
  printf -- '- 2026-01-01T01:00Z OFFENDER-RA\n'
  printf -- '- 2026-01-01T09:55-10:45Z range, 2026-01-01T09:55Z-10:45Z range, 2026-01-01T00:05Z five ahead, 2026-01-02 date only\n'
  printf -- '- 2026-01-01Txx:xxZ placeholder, ~2026-01-01T05:00Z approx, 2026-01-01T03:00Z - 04:00Z, 2026-01-01T03:00Z to 04:00Z, 2026-01-01T03:00Z \342\206\222 04:00Z spaced\n'
  printf -- '- 2026-01-01T02:00Z - OFFENDER-DASH\n'
  printf -- '- 2025-12-31T23:59Z CLOCK CORRECTION: rewrote 2 future stamp(s) to date -u: 01:00Z, 02:45Z\n'
  printf -- '- 2025-12-31T23:58Z operator set the monitor deadline 2026-01-07T16:08:54Z\n'
  printf '## In-Flight Teammates\n'
  printf 'agent | role | deliverable | dispatched-at | status\n'
  printf -- '--- | --- | --- | --- | ---\n'
  printf 'dev-a | dev | s1 | 2026-01-01T01:00Z | in-flight\n'
  printf 'dev-b | dev | s2 | 2025-12-31T23:00Z | in-flight, since 2026-01-01T05:00Z\n'
} > "$FPROBE"
FPROBE_OUT="$(check_future_stamps "$FPROBE" probe 1767225600)"
FPROBE_N="$(printf '%s\n' "$FPROBE_OUT" | grep -c '^FUTURE ')" || FPROBE_N=0
case "$FPROBE_OUT" in *'line 2:'*'(Recent Activity)'*) FP_RA=1 ;; *) FP_RA=0 ;; esac
case "$FPROBE_OUT" in *'line 5:'*'(Recent Activity)'*) FP_DASH=1 ;; *) FP_DASH=0 ;; esac
case "$FPROBE_OUT" in *'line 11:'*'dispatched-at)'*) FP_IF=1 ;; *) FP_IF=0 ;; esac
rm -f "$FPROBE"
if [ "$FP_RA" -ne 1 ] || [ "$FP_DASH" -ne 1 ] || [ "$FP_IF" -ne 1 ] || [ "$FPROBE_N" -ne 3 ]; then
  echo "FAIL: the future-stamp self-probe expected exactly its three OFFENDERS (Recent Activity" >&2
  echo "  lines 2 and 5, dispatched-at line 11) and got ${FPROBE_N} finding(s):" >&2
  printf '%s\n' "$FPROBE_OUT" | sed 's/^/    /' >&2
  echo "  A missing offender means the arm cannot fire; an extra one means a skipped form" >&2
  echo "  (range, spaced range, 5-min slack, date-only, x, ~, a CLOCK CORRECTION line naming" >&2
  echo "  bare HH:MMZ, a deadline in the body of a stamp-led line, status-cell since) is being read." >&2
  exit 1
fi

# THE MALFORMED-STAMP AND BACK-DATED-DISPATCH SELF-PROBES, same posture: fatal, both directions.
#   MALFORMED  OFFENDER  `T02:2xZ` and `T23:5Z`
#              NEAR-MISS `Txx:xxZ`, `~...T19:3xZ` (an explicit approximation), a full stamp
#   BACKDATED  OFFENDER  an in-flight pm-escalated row stamped 112 s before its ledger row
#              NEAR-MISS the same role stamped 1 s AFTER (honest); a row stamped LATE (00:35,
#                        nearest dispatch is 75 min BEFORE it); a delivered row stamped early;
#                        a name-joined LATE row whose next same-role dispatch is nearer than
#                        its own (dev-x, 01:22:00 for 01:19:55, dev-y at 01:23:30);
#                        a minute-only stamp 50 s before its dispatch (rounding); a role with no
#                        ledger row at all
MPROBE="$TMPROOT/probe-malformed.md"
printf -- '- 2026-01-01T02:17Z advisor DONE 2026-01-01T02:2xZ\n- 2026-01-01T23:5Z late\n- 2026-01-01Txx:xxZ declared placeholder, ~2026-01-01T19:3xZ approx, 2026-01-01T19:30Z full\n' > "$MPROBE"
MPROBE_OUT="$(check_malformed_stamps "$MPROBE" probe)"
rm -f "$MPROBE"
if [ "$(printf '%s\n' "$MPROBE_OUT" | grep -c '^MALFORMED ')" != 2 ] \
   || ! grep -q 'line 1: 2026-01-01T02:2xZ' <<<"$MPROBE_OUT" \
   || ! grep -q 'line 2: 2026-01-01T23:5Z' <<<"$MPROBE_OUT"; then
  echo "FAIL: the malformed-stamp self-probe expected exactly T02:2xZ (line 1) and T23:5Z (line 2), got:" >&2
  printf '%s\n' "$MPROBE_OUT" | sed 's/^/    /' >&2
  exit 1
fi
if command -v jq >/dev/null 2>&1; then
  BPROBE="$TMPROOT/probe-backdate.md"; BLEDGER="$TMPROOT/probe-ledger.jsonl"
  printf '%s\n' '{"ts":"2026-01-01T00:17:08Z","name":"pm-escalated","role":"pm-escalated"}' \
    '{"ts":"2026-01-01T01:50:21Z","name":"pm-escalated","role":"pm"}' \
    '{"ts":"2026-01-01T02:17:32Z","name":"pm-escalated","role":"pm"}' \
    '{"ts":"2026-01-01T03:00:50Z","name":"dev","role":"dev"}' \
    '{"ts":"2026-01-01T01:19:55Z","name":"dev-x","role":"dev"}' \
    '{"ts":"2026-01-01T01:23:30Z","name":"dev-y","role":"dev"}' \
    '{"dispatched_at":"2026-01-01T00:00:00Z","role":"qa"}' 'not json' > "$BLEDGER"
  {
    printf '## In-Flight Teammates\n'
    printf 'agent | role | deliverable | dispatched-at | status\n--- | --- | --- | --- | ---\n'
    printf 'fold | pm-escalated | d1 | 2026-01-01T02:15:40Z | in-flight\n'
    printf 'fold2 | pm-escalated | d2 | 2026-01-01T02:17:33Z | in-flight\n'
    printf 'late | pm-escalated (a57) | d3 | 2026-01-01T00:35:00Z | in-flight, since 01:00Z\n'
    printf 'spec | pm-escalated | d4 | 2026-01-01T01:48:00Z | delivered\n'
    printf 'dev-a | dev | d5 | 2026-01-01T03:00Z | in-flight\n'
    printf 'arch | architect | d6 | 2026-01-01T00:10:00Z | in-flight\n'
    printf 'dev-x | dev | d7 | 2026-01-01T01:22:00Z | in-flight\n'
  } > "$BPROBE"
  BPROBE_OUT="$(check_backdated_dispatch "$BPROBE" probe "$BLEDGER")"
  rm -f "$BPROBE" "$BLEDGER"
  if [ "$(printf '%s\n' "$BPROBE_OUT" | grep -c '^BACKDATED ')" != 1 ] \
     || ! grep -q 'line 4: pm-escalated dispatched-at 2026-01-01T02:15:40Z is 112 s' <<<"$BPROBE_OUT"; then
    echo "FAIL: the back-dated-dispatch self-probe expected exactly the line 4 row, 112 s early, got:" >&2
    printf '%s\n' "$BPROBE_OUT" | sed 's/^/    /' >&2
    echo "  A missing offender means the arm cannot fire; an extra one means an honest, late," >&2
    echo "  delivered, minute-rounded or unledgered row is being refused." >&2
    exit 1
  fi
fi

PPROBE="$TMPROOT/probe-backlog.md"
printf '### CO-S1-A WHOLE-READ-POOL closed\n**Status:** CLOSED\n### CO-S1-B unrelated\n**Status:** OPEN\n### CO-S1-C\n**Filed:** s1. **Status:** OPEN.\nthe WHOLE-READ-POOL is over\n' > "$PPROBE"
PPROBE_HIT="$(pool_open_item "$PPROBE")"
printf '### CO-S1-A WHOLE-READ-POOL closed\n**Status:** CLOSED\n### CO-S1-B unrelated\n**Status:** OPEN\n' > "$PPROBE"
PPROBE_MISS="$(pool_open_item "$PPROBE")"
rm -f "$PPROBE"
if [ "$PPROBE_HIT" != "### CO-S1-C" ] || [ -n "$PPROBE_MISS" ]; then
  echo "FAIL: the pool-item self-probe: found '${PPROBE_HIT}' (want '### CO-S1-C') and, with no" >&2
  echo "  OPEN item citing WHOLE-READ-POOL, found '${PPROBE_MISS}' (want nothing)." >&2
  exit 1
fi

# -----------------------------------------------------------------------------
# THE WRITE-TIME MODE. `--stamps-only <snapshot> --payload <file>`: the derivation-capture
# PostToolUse hook calls this on every Write|Edit|MultiEdit of pipeline-snapshot.md, so a
# future stamp, a placeholder stamp or a back-dated dispatched-at is named at the write that
# creates it, not at the next gate. Before this the arm ran only at Check 14 and Step 0a,
# and a lead wrote three future stamps in four Edits with nothing said.
#
# ONLY THE LINES THIS WRITE CARRIED ARE JUDGED. The snapshot is masked: a line equal to a
# payload line is kept, every `## ` heading and every row naming `dispatched-at` is kept so
# the section and column locators still work, and everything else is blanked with its line
# number preserved. Text already in the snapshot is the gate scan job, and a write that
# touches one line must not be refused for another -- the malformed arm in particular fires
# on 45 of the reference consumer committed revisions, newest included.
#
# THE PAYLOAD IS WHAT THE WRITE ADDED, NOT WHAT IT CARRIED. The hook subtracts each Edit's
# old_string lines from its new_string, so a placeholder kept as context is not re-judged
# (measured: 9 of 2961 real snapshot Edits on the reference consumer carried one). A full
# Write has no before-state in its PostToolUse payload, so `--whole-write` skips MALFORMED
# there -- RESIDUAL: a placeholder introduced by a whole-file Write is caught by nothing at
# write time. FUTURE and BACKDATED still run on a Write: an old line they fire on is still a
# live defect, where an old placeholder is only old text.
#
# NOT the full validator: budget, schema and marker findings stay at the gate, where their
# remedies apply. Exit 1 on a finding, 0 clean, 2 on bad usage -- the hook fails OPEN on 2.
#
# IT IS ADVISORY BY CONSTRUCTION. PostToolUse runs after the write landed; the hook exit 2
# only returns this text to the model. And a Bash `sed -i` on the snapshot is not a
# Write|Edit|MultiEdit, so it reaches no PostToolUse hook at all -- the gate scan is the
# only check that sees it.
if [ -n "$STAMPS_ONLY" ]; then
  [ -f "$STAMPS_ONLY" ] && [ -f "$PAYLOAD_FILE" ] || {
    echo "usage: --stamps-only <pipeline-snapshot.md> --payload <file-of-written-text>" >&2; exit 2; }
  _mask="$TMPROOT/stamps-mask.md"
  # A payload line also matches a file line that CONTAINS it: an Edit new_string may begin
  # or end mid-line, and its first and last lines are then fragments.
  # The floor is 17 bytes, the shortest full stamp (`YYYY-MM-DDTHH:MMZ`): a bare stamp written
  # into one cell still reaches its row, and a shorter common prefix (`- 2026-10-16T0`)
  # cannot unmask every old line of that day.
  LC_ALL=C awk 'FNR == NR { if ($0 != "") { P[$0] = 1; if (length($0) >= 17) F[++nf] = $0 } next }
    /^## / || (/\|/ && /dispatched-at/) || ($0 in P) { print; next }
    { for (i = 1; i <= nf; i++) if (index($0, F[i])) { print; next } print "" }' \
    "$PAYLOAD_FILE" "$STAMPS_ONLY" > "$_mask" || exit 2
  _rel="${STAMPS_ONLY##*/}"
  {
    check_future_stamps "$_mask" "$_rel" "$SNAP_NOW"
    [ "$WHOLE_WRITE" -eq 1 ] || check_malformed_stamps "$_mask" "$_rel"
    check_backdated_dispatch "$_mask" "$_rel" "$(dirname "$STAMPS_ONLY")/spawn-ledger.jsonl" | grep -v '^SKIP '
  } > "$TMPROOT/stamps-out"
  [ -s "$TMPROOT/stamps-out" ] || exit 0
  echo "FAIL: this write to ${_rel} carries a stamp the snapshot must not hold:" >&2
  cat "$TMPROOT/stamps-out" >&2
  cat >&2 <<'EOF'

      Fix it now, in the line you just wrote:
        FUTURE     rewrite the stamp to the current time from `date -u`. A date the entry
                   RECORDS (a deadline) belongs in the body of a line that leads with its
                   own past stamp; only the leading stamp is read there.
        MALFORMED  write the real stamp from the record that holds it (a transcript, a
                   ledger row, a commit). If none does, write an explicit approximation
                   with full digits and a leading `~` (`~2026-10-15T19:30Z`).
        BACKDATED  stamp dispatched-at from the dispatch itself: the spawn-ledger row for
                   this teammate (`ts`), or `date -u` taken right after the Agent call.
                   Never subtract minutes to make an older deliverable count.
EOF
  exit 1
fi

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
POOL_OVER=0
POOL_BACKLOGS=""
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
      case "$rel" in carry-over-backlog.md|*/carry-over-backlog.md) POOL_BACKLOGS="${POOL_BACKLOGS}${rel}
" ;; esac
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
    POOL_OVER=1
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
      check_future_stamps "$f" "$rel" "$SNAP_NOW" >> "$FUTURE_FILE"
      check_backdated_dispatch "$f" "$rel" "$(dirname "$f")/spawn-ledger.jsonl" >> "$BACKDATE_FILE"
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
# The marked-superseded and struck-row channels set their own flags too. They used to set none,
# so a --warn-only run whose ONLY finding was a struck In-Flight row printed that row's `WARN:`
# and then closed with the bare PASS line -- the same contradiction as the breach case above, on
# the channel retro.md Step 5c's own invocation leaves at exit 0.
SAW_MARKER=0
SAW_INFLIGHT=0
SAW_FUTURE=0

# A FIFTH INDEPENDENT VERDICT: a stamp after the clock. Not a size, a section, or a
# marker, so it is folded into none of them. Hard on every path that does not ask for
# --warn-only, and hard under --warn-only when the snapshot is hardened with --fail-on,
# exactly as the marker verdict: Check 14, Step 0a, Step 1a and the sub-step path all
# block on it, and retro's own invocation hardens the snapshot.
#
# IT IS PRINTED FIRST, AND ITS VERDICT LINE CARRIES THE WHOLE REMEDY, BECAUSE THE LEAD READS
# IT THROUGH verdict.sh. Check 14, Step 0a check 1 and the between-gates sub-step all call
# this validator through `verdict.sh`, which surfaces at most AI_DLC_VERDICT_LINES (6) lines
# matching its FAIL/OVER/WARN/FUTURE alternation and drops the heredoc below entirely.
# Printed after the budget verdict, a co-occurring OVER (the reference consumer's live
# snapshot already spends 2 of the 6 on one) pushed the FUTURE rows past the cap, and the
# remedy never reached the lead at all -- who then cleared the check by TRIMMING the future
# lines into the history file, which is the one outcome the remedy exists to prevent. So
# this verdict leads, and the one line verdict.sh is certain to show says what to do.
#
# THE OLD STAMPS ARE NAMED AS BARE `HH:MMZ`. A correction line that leads with its own stamp
# has only that stamp read, so a full-ISO old stamp in its body no longer re-fires; but a
# correction line written WITHOUT a leading stamp is read whole, and there the full form
# does. The bare form is safe under both, which is why the remedy keeps asking for it.
report_future_stamps() {
  [ -s "$FUTURE_FILE" ] || return 0
  SAW_FUTURE=1
  say ""
  if [ "$WARN_ONLY" -eq 1 ] && ! is_fail_on "pipeline-snapshot.md"; then
    echo "WARN: pipeline-snapshot.md carries stamp(s) later than the current UTC time -- rewrite each FUTURE stamp below to \`date -u\` in place (keep line order), then add ONE Recent Activity line \`<date -u> CLOCK CORRECTION: rewrote <n> future stamp(s) to date -u: <old stamps as bare HH:MMZ>\`; do this WITHOUT ASKING and before any trim or move."
  else
    echo "FAIL: pipeline-snapshot.md carries stamp(s) later than the current UTC time -- rewrite each FUTURE stamp below to \`date -u\` in place (keep line order), then add ONE Recent Activity line \`<date -u> CLOCK CORRECTION: rewrote <n> future stamp(s) to date -u: <old stamps as bare HH:MMZ>\`; do this WITHOUT ASKING and before any trim or move." >&2
    RC=1
  fi
  cat "$FUTURE_FILE" >&2
  cat >&2 <<'EOF'

      A Recent Activity entry or an In-Flight dispatched-at cell stamped more than
      10 minutes after now records an event that has not happened. Every reader of
      the snapshot -- a gate, a resume, a recovery -- orders by these stamps.

      Remedy, applied by the lead WITHOUT ASKING, BEFORE any trim or section move:
        1. Rewrite each stamp named above to the current time from `date -u`
           (e.g. `date -u +%Y-%m-%dT%H:%MZ`). Keep every line where it is; do not
           re-order the section, and do not move the line to the history file --
           trimming a future stamp away hides it instead of correcting it.
        2. Add ONE Recent Activity line, stamped from `date -u`, that reads
           `CLOCK CORRECTION: rewrote <n> future stamp(s) to date -u: <old>` and
           names each old stamp as a bare `HH:MMZ` (e.g. `02:30Z, 02:45Z`). Lead
           the line with its own stamp: a line that does has only that stamp read,
           and one that does not is read whole, old stamps included.
        3. Re-run this check.

      Never take a stamp from memory or from another line -- `date -u` is the only
      clock. Ranges (also spaced: ` - `, ` to `, an arrow, before a digit), `~`
      approximations, `x` placeholders and date-only stamps are not checked.
EOF
}
report_future_stamps
rm -f "$FUTURE_FILE"

# A SIXTH VERDICT: an in-flight dispatched-at earlier than its own dispatch. Same posture as
# the future-stamp verdict -- hard unless --warn-only without --fail-on the snapshot. A SKIP
# line (no ledger, no jq) is printed, never folded into a pass.
SAW_BACKDATE=0
if grep -q '^SKIP ' "$BACKDATE_FILE" 2>/dev/null; then
  say ""; grep '^SKIP ' "$BACKDATE_FILE" | while IFS= read -r _l; do say "$_l"; done
fi
if grep -q '^BACKDATED ' "$BACKDATE_FILE" 2>/dev/null; then
  SAW_BACKDATE=1
  say ""
  if [ "$WARN_ONLY" -eq 1 ] && ! is_fail_on "pipeline-snapshot.md"; then
    echo "WARN: pipeline-snapshot.md carries an in-flight dispatched-at earlier than its dispatch -- re-stamp each row below from its spawn-ledger \`ts\`; never back-date a row to make an older deliverable count."
  else
    echo "FAIL: pipeline-snapshot.md carries an in-flight dispatched-at earlier than its dispatch -- re-stamp each row below from its spawn-ledger \`ts\`; never back-date a row to make an older deliverable count." >&2
    RC=1
  fi
  grep '^BACKDATED ' "$BACKDATE_FILE" >&2
fi
rm -f "$BACKDATE_FILE"

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
      # The pool row's field 2 is `WHOLE-READ`, not a basename. It is hardened ONLY by
      # the `whole-read-pool` token below; matching it here would let a basename that
      # happens to equal a word of the label harden it by accident.
      [ "$brel" = "WHOLE-READ" ] && continue
      if is_fail_on "$brel"; then
        echo "FAIL: $brel is over budget and was hardened with --fail-on, so this run blocks despite --warn-only." >&2
        RC=1
      fi
    done < "$BREACH_FILE"
    # THE POOL'S HARD VERDICT AT RETRO, and it is NOT "the pool is over". Retro cannot
    # consolidate -- artifact-consolidation.md is operator-supervised, never automatic --
    # so blocking on the size alone would wedge a retro on an action it has no standing
    # to take. What retro CAN do is make sure the next sprint does not discover the
    # breach at route Step 1a after the fact: file an OPEN carry-over item that cites
    # the pool, which route Step 1 item 5 reads before Step 1a runs. So the verdict is
    # "pool OVER and no OPEN item in carry-over-backlog.md carries WHOLE-READ-POOL";
    # recording the item satisfies it, and an item retro's own sweep appends cannot
    # wedge it.
    if [ "$POOL_OVER" -eq 1 ] && is_fail_on "whole-read-pool"; then
      POOL_ITEM=""
      while IFS= read -r _bl; do
        [ -n "$_bl" ] || continue
        POOL_ITEM="$(pool_open_item "$ROOT/$_bl")"
        [ -n "$POOL_ITEM" ] && break
      done <<EOF
$POOL_BACKLOGS
EOF
      if [ -z "$POOL_ITEM" ]; then
        echo "FAIL: the WHOLE-READ POOL is over budget, was hardened with --fail-on whole-read-pool, and no OPEN carry-over item cites it." >&2
        cat >&2 <<'EOF'
      Remedy, applied by the lead without asking: file ONE item in
      _bmad-output/planning-artifacts/carry-over-backlog.md --
        ### CO-S<N>-WHOLE-READ-POOL-OVER -- <one line naming the pool figure>
        **Status:** OPEN
      -- whose body quotes this run's OVER line and names artifact-consolidation.md
      as the operator-supervised action owed before the next sprint's route. The
      heading or body must carry the token WHOLE-READ-POOL. Then re-run this check.
      Do NOT consolidate here: consolidation is never automatic.
EOF
        RC=1
      else
        say "      pool breach recorded: OPEN carry-over item ${POOL_ITEM}"
      fi
    fi
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
  SAW_MARKER=1
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
  SAW_INFLIGHT=1
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
#   breach/schema/marker/inflight/status
#                        -- findings about artifacts this table measures. A run that printed
#                           one of these has NOT established that everything is within
#                           budget, whatever its exit code says.
#   coverage             -- artifacts NO budget governs. Its WARN and the clean claim are
#                           both literally true at once, because an ungoverned artifact is
#                           unmeasured rather than over budget. That run is not a
#                           contradiction; it is a pass with a stated blind spot, and saying
#                           so is the difference between legible and merely quiet.
if [ "$RC" -eq 0 ]; then
  say ""
  if [ "$SAW_BREACH" -eq 1 ] || [ "$SAW_SCHEMA" -eq 1 ] || [ "$SAW_MARKER" -eq 1 ] \
     || [ "$SAW_INFLIGHT" -eq 1 ] || [ "$SAW_STATUS" -eq 1 ] || [ "$SAW_FUTURE" -eq 1 ] \
     || [ "$SAW_BACKDATE" -eq 1 ]; then
    _what=""
    [ "$SAW_BREACH" -eq 1 ] && _what="${_what}, over-budget artifact(s)"
    [ "$SAW_SCHEMA" -eq 1 ] && _what="${_what}, off-schema section(s)"
    [ "$SAW_MARKER" -eq 1 ] && _what="${_what}, superseded content marked in place"
    [ "$SAW_INFLIGHT" -eq 1 ] && _what="${_what}, struck-through In-Flight row(s)"
    [ "$SAW_STATUS" -eq 1 ] && _what="${_what}, unrecognised In-Flight status row(s)"
    [ "$SAW_FUTURE" -eq 1 ] && _what="${_what}, future-stamped snapshot entr(ies)"
    [ "$SAW_BACKDATE" -eq 1 ] && _what="${_what}, back-dated In-Flight dispatched-at row(s)"
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
