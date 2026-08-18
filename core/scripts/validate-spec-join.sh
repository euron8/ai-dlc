#!/usr/bin/env bash
# validate-spec-join.sh — the spec traceability joins
#
# Usage: ./scripts/ai-dlc/validate-spec-join.sh --spec DIR --prd FILE [--story FILE]...
#                                              [--spine-lint JSON] [--trace-verdict FILE]
#
# Gate-validation Check 30 enforcer (story gates).
#
# WHAT IT GUARDS. The chain from operator intent to a test is
#
#   LOCKED_REQUIREMENTS -> CAP-N -> FR-<n> -> story AC -> test
#
# and until now its middle joins were hand-typed prose. A PRD carries
# `FR-S290-1 (<- LR-S290-1)`; the arrow is a character, not a join, and nothing
# reads it. Two failures follow, both silent:
#
#   - A requirement reaches no capability. Observed: a locked requirement dropped
#     during an ADR pivot with no SUPERSEDED disposition — it simply stopped being
#     mentioned, and every artifact downstream stayed internally consistent.
#   - A definition is re-transcribed instead of cited. Observed: a roster of
#     always-on safety pollers restated per-story, at 5, 6 and 4 members in three
#     places, because no story pointed at one canonical definition.
#
# BMAD supplies the stable IDs this needs and does not join them: `bmad-spec`
# guarantees `CAP-N` is never reused or renumbered, `bmad-architecture` gives
# `AD-n`, and `bmad-create-epics-and-stories` emits an `FR Coverage Map`. What
# none of them does is FAIL. This is the caller that decides.
#
# THE JOINS, all ID-mechanical:
#   (1) every LOCKED_REQUIREMENTS bullet in the spec's memlog maps to >=1 CAP-N
#   (2) every CAP-N in SPEC.md is cited by a functional-requirement entry in prd.md
#       -- NOT in BMAD's FR Coverage Map, whose content propagates whatever FR label
#       the PRD used and is therefore a derived surface, not an independent one
#  (2a) every CAP-N is bound by an architecture decision (`- **Binds:**` in the spine)
#   (3) every `capabilities:` entry in a story frontmatter resolves to a CAP-N
#       that SPEC.md defines
#
# ANCHOR ON THE MEMLOG, NOT SPEC.md. `bmad-spec` is the single writer of SPEC.md
# and re-derives it from `.memlog.md` on every run: "a hand-edit to SPEC.md from
# outside is unsupported and is overwritten on the next derive." A byte anchor into
# a re-rendered file holds until the next derive and then reports a drift that never
# happened. `.memlog.md` is append-only and never reordered, so requirement text is
# anchored there.
#
# TWO BORROWED VERDICTS, EACH READ FROM A NAMED KEY. `--spine-lint` takes
# `lint_spine.py`'s JSON, which always exits 0 by design and lets the caller decide;
# severity comes from its own `severity` field (any `high` fails, `low` records), never
# from a hand-list of category names -- it has four, and the two an earlier version
# listed omitted `ad_id`, which is the ID-stability failure every join here rests on.
# `--trace-verdict` takes `bmad-testarch-trace`'s `gate-decision.json` and reads
# `gate_status`; the same file carries `p0_status`, `p1_status` and a prose `rationale`,
# so a whole-file grep for FAIL fails a gate the tool passed. Both are OPT-IN FLAGS:
# whether they ran is the gate's evidence question, not something this script can infer.
#
# EXIT CODES
#   0  -- every join closes
#   1  -- an orphan or a dangling reference
#   2  -- DISARMED or usage error: a required input is unreadable, or SPEC.md
#         defines ZERO capabilities. A zero-capability spec closes every join
#         vacuously and prints the same line as a spec that closes them for real.

set -u

PROG="validate-spec-join.sh"
SPEC=""; PRD=""; SPINE=""; SPINE_MD=""; TRACE=""; BASELINE=""
STORIES=()

while [ $# -gt 0 ]; do
  case "$1" in
    --spec)          SPEC="${2:-}"; shift 2 || exit 2 ;;
    --prd)           PRD="${2:-}";  shift 2 || exit 2 ;;
    --story)         STORIES+=("${2:-}"); shift 2 || exit 2 ;;
    --spine)         SPINE_MD="${2:-}"; shift 2 || exit 2 ;;
    --spine-lint)    SPINE="${2:-}"; shift 2 || exit 2 ;;
    --trace-verdict) TRACE="${2:-}"; shift 2 || exit 2 ;;
    --baseline)      BASELINE="${2:-}"; shift 2 || exit 2 ;;
    -h|--help) echo "usage: $PROG --spec DIR --prd FILE [--story FILE]... [--spine FILE] [--spine-lint JSON] [--trace-verdict FILE] [--baseline FILE]" >&2; exit 2 ;;
    *) echo "$PROG: unexpected argument '$1'" >&2; exit 2 ;;
  esac
done

# --- the baseline, and the arm that stops it outliving its cause ---------------
# A CORRECTED CHECK THAT BLOCKS ON DEBT IT DID NOT CREATE GETS TURNED OFF. Adopting
# this check against an existing corpus means inheriting whatever orphans the chain
# already has -- 15 in the reference consumer (5 LR->CAP, 10 CAP->FR), none of them
# caused by adopting the check. `--baseline` names them so the gate reports them
# without blocking on them.
#
# THE SECOND ARM IS WHY THIS IS NOT A MUTE BUTTON. A baseline entry that does NOT
# reproduce is itself a FAIL. Without that, a baseline written once outlives the
# thing it excused: the orphan gets fixed, the entry stays, and the next real
# instance of the same id is silently suppressed by a line whose cause is gone. The
# entry must be deleted when the failure it names is, and this is what forces it.
#
# KEYS ARE NAMESPACED because two joins key on the same identifier -- join (2) and
# join (2a) both fail per CAP-<n>, so a bare `CAP-1` would suppress a capability
# missing its FR *and* the same capability missing its AD, on one line.
#
#   lr:<LR-id>        join (1)  requirement reaches no capability
#   fr:<CAP-id>       join (2)  capability cited by no functional requirement
#   ad:<CAP-id>       join (2a) capability bound by no architecture decision
#   story:<basename>  join (3)  story capabilities frontmatter
#
# THE BORROWED VERDICTS ARE NOT BASELINEABLE. `lint_spine.py` and
# `bmad-testarch-trace` publish their own findings with no stable per-item key here,
# and suppressing another tool's verdict from this side would be adopting a
# self-declared pass by omission.
BASELINE_KEYS=""
BASELINE_HIT=""
if [ -n "$BASELINE" ]; then
  [ -f "$BASELINE" ] || { echo "$PROG: DISARMED — --baseline names an unreadable file: $BASELINE. An unreadable baseline is not an empty one; exiting rather than reporting every baselined failure as new." >&2; exit 2; }
  BASELINE_KEYS="$(sed 's/#.*//; s/^[[:space:]]*//; s/[[:space:]]*$//' "$BASELINE" | grep -v '^$' || true)"
fi

# fail_join <namespaced-key> <message>
#   Emits FAIL and sets rc, unless the key is baselined -- in which case it records
#   the hit so the did-not-reproduce arm below can tell a live baseline from a stale one.
fail_join() {
  local key="$1" msg="$2"
  if [ -n "$BASELINE_KEYS" ] && grep -qxF -- "$key" <<<"$BASELINE_KEYS"; then
    echo "  BASELINED  $key — pre-existing, suppressed by $BASELINE (still reproducing)"
    BASELINE_HIT="${BASELINE_HIT}${key}
"
    return
  fi
  echo "FAIL: $msg" >&2
  rc=1
}

[ -n "$SPEC" ] && [ -d "$SPEC" ] || { echo "$PROG: DISARMED — --spec must name the spec folder (holding SPEC.md and .memlog.md); got '${SPEC:-<none>}'." >&2; exit 2; }
KERNEL="$SPEC/SPEC.md"
MEMLOG="$SPEC/.memlog.md"
[ -f "$KERNEL" ] || { echo "$PROG: DISARMED — no SPEC.md in $SPEC. Run bmad-spec before this gate; a missing kernel is not an empty one." >&2; exit 2; }
[ -f "$MEMLOG" ] || { echo "$PROG: DISARMED — no .memlog.md in $SPEC. The memlog is the append-only decision-of-record and the anchor surface for requirement text; without it join (1) cannot be checked at all." >&2; exit 2; }
[ -n "$PRD" ] && [ -f "$PRD" ] || { echo "$PROG: DISARMED — --prd must name a readable PRD; got '${PRD:-<none>}'." >&2; exit 2; }

# Capabilities the kernel defines.
CAPS="$(grep -ohE '\bCAP-[0-9]+\b' "$KERNEL" | sort -u -V)"
NCAPS="$(printf '%s\n' "$CAPS" | grep -c . )"
if [ "$NCAPS" -eq 0 ]; then
  echo "$PROG: DISARMED — $KERNEL defines ZERO capabilities (no CAP-<n> found). Every join below would close against an empty set and print the same PASS line as a spec that closes them for real." >&2
  exit 2
fi

rc=0
note=0

# --- (1) every locked requirement reaches a capability -------------------------
# The memlog is TYPED -- `- (capability) ...`, `- (constraint) ...`, `- (event) ...`
# -- and this join reads CAPABILITY ENTRIES ONLY.
#
# READING ANY LINE IS THE DEFECT, NOT A SHORTCUT. bmad-spec's Self-Validate appends
# its own verdict as an `(event)` entry, and that verdict enumerates the very
# mapping this join checks:
#
#   - (event) pass 2 preservation PASS: LR-S300-1 -> CAP-1 + routing-knob constraint,
#     LR-S300-2 -> CAP-2 + BLOCKS constraint, LR-S300-3 -> CAP-3 + $0.00 constraint
#
# A predicate that scans every line mentioning the LR is satisfied by that summary.
# Measured against real bmad-spec output: severing the actual `(capability)` entry
# for a requirement left the join PASSING, because the spec's own claim that the
# join holds was being read as evidence that it holds. That is the self-declared
# verdict Rule 30 forbids adopting, committed by the check meant to enforce it.
# The tag grammar is the PRODUCER's and the qualifier is optional per append: the memlog
# writer emits `(<type>)`, or `(<type> by <author>)` when the append carried an author. So
# `(capability)` and `(capability by bmad-spec)` are the SAME entry type and both are read
# here. This accepts anything after the type word rather than ` by ` specifically, because
# the type itself is free text on the producer's side and a narrower predicate would have to
# track its wording. The `[[:space:]]` inside the optional group is load-bearing: without it
# the group also swallows `(capability-review)`, and the join widens to a different type.
CAP_ENTRIES="$(grep -E '^[[:space:]]*[-*][[:space:]]*\((capability|capabilities)([[:space:]][^)]*)?\)' "$MEMLOG")"
if [ -z "$CAP_ENTRIES" ]; then
  echo "$PROG: DISARMED — $MEMLOG contains no '(capability)' entries. The LR->CAP join reads those entries and only those; with none present it would close against an empty set. An optional qualifier after the type — '(capability by <author>)' — is legal and is read here; a memlog with neither form has no capability entries at all. If bmad-spec's memlog entry TYPES change, this predicate must change with them rather than fall back to scanning every line." >&2
  exit 2
fi

LRS="$(grep -ohE '\bLR-[A-Za-z0-9]+-[0-9]+[a-z]?\b' "$MEMLOG" | sort -u)"
NLRS="$(printf '%s\n' "$LRS" | grep -c . )"
if [ "$NLRS" -eq 0 ]; then
  echo "$PROG: DISARMED — no LR-<...> identifiers found in $MEMLOG. Join (1) has nothing to check, which is not the same as closing." >&2
  exit 2
fi
for lr in $LRS; do
  # A `(capability)` entry naming both this LR and a CAP-N is the join. Nothing else
  # counts -- see the note above on why scanning every line reads a self-report.
  if ! printf '%s\n' "$CAP_ENTRIES" | grep -E "(^|[^A-Za-z0-9-])$lr([^A-Za-z0-9-]|\$)" | grep -qE '\bCAP-[0-9]+\b'; then
    fail_join "lr:$lr" "$lr appears in the memlog but no capability entry cites it alongside a CAP-<n>. A locked requirement that reaches no capability is dropped, and every artifact downstream stays internally consistent while it is missing. Either map it to a capability or record an explicit SUPERSEDED/AMENDED disposition for it."
  fi
done

# --- (2) every capability is cited by a functional requirement -----------------
# READ THE PRD's FR ENTRIES, NOT BMAD's FR COVERAGE MAP.
#
# The Coverage Map is bmad-create-epics-and-stories' artifact and its template emits
# `FR1: Epic 1 - <description>` — an FR-to-EPIC mapping with no capability token in
# it at all. The first version of this join required each CAP to appear there, which
# would have failed every capability against a perfectly correct map: a hard false
# positive blocking every planning gate. Reading the real template settled it; a
# paraphrase had already said `FR1: Epic 1` and the `(CAP-1)` was invented here.
#
# FR-to-epic coverage is already `bmad-check-implementation-readiness` step 03's job,
# so duplicating it would violate Rule 26(b). What ai-dlc owns is prd.md's own FR
# entries — `research-requirements.md` mandates the capability citation there, e.g.
# `- **FR-S300-1 (CAP-1)** ...` alongside the existing `(← LR-...)` form.
FR_LINES="$(grep -nE '(^|[^A-Za-z0-9-])N?FR-?[A-Za-z0-9]*-?[0-9]+' "$PRD")"
if [ -z "$FR_LINES" ]; then
  echo "$PROG: DISARMED — $PRD contains no functional-requirement identifiers (nothing matching FR-<n> / FR-S<N>-<n>). Join (2) has nothing to read, which is not the same as closing." >&2
  exit 2
fi
for cap in $CAPS; do
  if ! grep -qE "(^|[^A-Za-z0-9-])$cap([^A-Za-z0-9-]|\$)" <<<"$FR_LINES"; then
    fail_join "fr:$cap" "$cap is defined in SPEC.md but no functional requirement in $PRD cites it. A capability with no FR behind it is specified and unplanned — it reaches no epic, no story and no test. Add the citation to the FR entry, in the form research-requirements.md mandates."
  fi
done

# --- (3) every story capability reference resolves -----------------------------
if [ "${#STORIES[@]}" -gt 0 ]; then
  for s in "${STORIES[@]}"; do
    [ -f "$s" ] || { echo "$PROG: DISARMED — --story names an unreadable file: $s" >&2; exit 2; }
    refs="$(sed -n '/^capabilities:/{s/^capabilities:[[:space:]]*//; s/[][]//g; s/,/ /g; p; }' "$s" | head -1)"
    # THREE STATES, NOT ONE. An empty `$refs` was reported as "carries no 'capabilities:'
    # frontmatter field" regardless of why it was empty, and that sentence is FALSE for two
    # of the three cases. Measured on the reference consumer: of the 4 in-scope stories, 3
    # carry a `capabilities:` line that is EMPTY and were told they carry none.
    #
    # A WRONG DIAGNOSIS ON A HARD BLOCK IS HOW CHECKS GET TURNED OFF. The author reads
    # "carries no field", looks at the field sitting in the frontmatter, and concludes the
    # check is broken -- which, on that sentence, it is. The remedy it names does not apply
    # and the real one is never stated.
    #
    #   key absent          the story predates the frontmatter contract or ignored it.
    #                       Nothing was claimed. Add the field.
    #   key empty, no why   the story CLAIMS it implements no capability. That is a real
    #                       claim about the chain and it is unexplained -- which is a
    #                       different defect with a different remedy, not a missing field.
    #   key empty + why     the claim is DECLARED, in the pattern Check 33's
    #                       `NOT-IN-SCOPE` disposition already establishes: an explicit,
    #                       visible, per-item disposition beats an unexplained blank.
    #                       Recorded as a note, not a pass in silence.
    if [ -z "$refs" ]; then
      cap_rationale="$(sed -n 's/^capabilities_rationale:[[:space:]]*//p' "$s" | head -1 | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
      if ! grep -q '^capabilities:' "$s"; then
        fail_join "story:$(basename "$s")" "$s carries no 'capabilities:' frontmatter field at all. That field is the only mechanical link from a story to the spec; without it the story's place in the chain is prose. Add it — with the CAP-<n> ids this story implements, or empty plus a 'capabilities_rationale:' saying why it implements none."
      elif [ -n "$cap_rationale" ]; then
        echo "  note  $(basename "$s") declares no capability, with a rationale: $cap_rationale"
        note=$((note+1))
      else
        fail_join "story:$(basename "$s")" "$s declares 'capabilities:' EMPTY and gives no 'capabilities_rationale:'. The field IS present — this is not a missing field, it is an unexplained claim that this story implements none of the spec's capabilities. Either name the CAP-<n> ids it implements, or state why it implements none: 'capabilities_rationale: <reason>'."
      fi
      continue
    fi
    for r in $refs; do
      case "$r" in CAP-*) ;; *) continue ;; esac
      if ! grep -qx -- "$r" <<<"$CAPS"; then
        echo "FAIL: $s cites '$r' and $KERNEL defines no such capability. A story pointing at an ID that does not exist is a story nobody can trace, and CAP-<n> is never renumbered — so this is a typo or a stale reference, not a renumbering." >&2
        rc=1
      fi
    done
  done
fi

# --- (2a) every capability is bound by an architecture decision ----------------
# bmad-architecture renders each decision as `### AD-<n> — <title>` followed by
# `- **Binds:** <what>`, and Binds names CAPABILITIES: a real generated spine reads
# `- **Binds:** CAP-1`. So the CAP -> AD leg is a real join, and the chain this check
# documents asserted it without checking it. A leg claimed and unenforced is the same
# defect as a rule with no mechanism.
#
# `all` binds every capability -- a spine-wide invariant, which is how the real output
# expresses a decision that governs everything.
if [ -n "$SPINE_MD" ]; then
  [ -f "$SPINE_MD" ] || { echo "$PROG: DISARMED — --spine names an unreadable file: $SPINE_MD" >&2; exit 2; }
  BINDS="$(grep -E '^[[:space:]]*[-*][[:space:]]*\*\*Binds:\*\*' "$SPINE_MD")"
  if [ -z "$BINDS" ]; then
    echo "$PROG: DISARMED — $SPINE_MD contains no '- **Binds:**' entries, so no AD declares what it governs. Either this is not an ARCHITECTURE-SPINE.md or the AD entry shape changed; both would close this join against an empty set." >&2
    exit 2
  fi
  if grep -qiE '\*\*Binds:\*\*[[:space:]]*all\b' <<<"$BINDS"; then
    :   # a spine-wide AD binds every capability
  else
    for cap in $CAPS; do
      if ! grep -qE "(^|[^A-Za-z0-9-])$cap([^A-Za-z0-9-]|\$)" <<<"$BINDS"; then
        fail_join "ad:$cap" "$cap is defined in SPEC.md but no architecture decision in $SPINE_MD binds it. A capability no AD governs was never designed — it reaches implementation with no invariant constraining how."
      fi
    done
  fi
fi

# --- borrowed verdict: lint_spine.py ------------------------------------------
if [ -n "$SPINE" ]; then
  [ -f "$SPINE" ] || { echo "$PROG: DISARMED — --spine-lint names an unreadable file: $SPINE" >&2; exit 2; }
  # lint_spine.py always exits 0 by design and publishes its verdict in an envelope:
  #   {"ok": bool, "spine": str, "total_findings": int, "by_severity": {...},
  #    "findings": [{"category": ..., "severity": ..., "detail": ..., "location": ...}]}
  #
  # READ THE ENVELOPE, DO NOT HAND-LIST CATEGORIES. The first version of this checked
  # for two category names, `ad_fields` and `placeholder`. There are four —
  # `ad_id` and `version_pin` were silently ignored, and `ad_id` is "id reused" /
  # "non-monotonic; ids must ascend and never renumber", i.e. exactly the ID-stability
  # failure this whole check's premise rests on. A hand-list also goes stale the moment
  # BMAD adds a fifth category, with no signal that it has.
  #
  # Severity comes from the script, not from here: any `high` finding fails, `low` is
  # reported. `low` is its "possible unfilled template token (verify)" class, and
  # failing a gate on a maybe is how a live check earns a blanket waiver.
  sev="$(sed -n 's/.*"severity"[[:space:]]*:[[:space:]]*"\([a-z]*\)".*/\1/p' "$SPINE" | sort -u)"
  total="$(sed -n 's/.*"total_findings"[[:space:]]*:[[:space:]]*\([0-9]\{1,\}\).*/\1/p' "$SPINE" | head -1)"
  if [ -z "$total" ]; then
    echo "$PROG: DISARMED — $SPINE carries no \"total_findings\" key, so it is not a lint_spine.py envelope. Exiting 2 rather than reporting a clean spine: a file this script cannot parse is not a file with no findings." >&2
    exit 2
  fi
  if grep -qx high <<<"$sev"; then
    n_high="$(grep -c '"severity"[[:space:]]*:[[:space:]]*"high"' "$SPINE")"
    echo "FAIL: lint_spine.py reported $n_high high-severity finding(s) in the architecture spine ($total total, $SPINE). It exits 0 by design and leaves the decision to its caller; this is that decision. An AD missing Binds/Prevents/Rule binds nothing, a reused or non-monotonic AD id breaks the ID stability every downstream join depends on, and an unfilled placeholder is an unratified decision." >&2
    grep -E '"(category|detail)"' "$SPINE" | sed 's/^[[:space:]]*/    /' >&2
    rc=1
  elif [ "$total" -gt 0 ]; then
    echo "  note  lint_spine.py reported $total low-severity finding(s) in $SPINE — recorded, not gating."
    note=$((note+1))
  fi
fi

# --- borrowed verdict: bmad-testarch-trace ------------------------------------
if [ -n "$TRACE" ]; then
  [ -f "$TRACE" ] || { echo "$PROG: DISARMED — --trace-verdict names an unreadable file: $TRACE. bmad-testarch-trace writes gate-decision.json only when the gate was evaluated AND produced PASS/CONCERNS/FAIL/WAIVED; its absence therefore means the gate did NOT evaluate, which is not the same as passing." >&2; exit 2; }
  # READ THE `gate_status` KEY, NOT THE WHOLE FILE. gate-decision.json also carries
  # `p0_status`, `p1_status`, `overall_status` and a prose `rationale`, any of which
  # can contain the token FAIL while the gate decision is CONCERNS. A whole-file grep
  # for FAIL therefore fails a gate the tool passed.
  gs="$(sed -n 's/.*"gate_status"[[:space:]]*:[[:space:]]*"\([A-Z_]*\)".*/\1/p' "$TRACE" | head -1)"
  case "${gs:-}" in
    FAIL)
      echo "FAIL: the traceability gate decision in $TRACE is FAIL. Requirements are not covered by tests; the matrix names which." >&2
      rc=1 ;;
    CONCERNS|WAIVED)
      echo "  note  traceability gate_status is $gs — recorded, not dropped. Matrix: $TRACE"
      note=$((note+1)) ;;
    PASS) ;;
    *)
      # Covers a missing/renamed key and NOT_EVALUATED, which the tool deliberately
      # excludes from this file. A trace that did not evaluate reads exactly like a
      # trace that passed, so it cannot be allowed to exit 0.
      echo "$PROG: DISARMED — $TRACE carries no readable \"gate_status\" (found '${gs:-<none>}'). Either the gate was not evaluated or the key was renamed; both would otherwise be indistinguishable from a PASS." >&2
      exit 2 ;;
  esac
fi

# --- the baseline must not outlive its cause ----------------------------------
# THE ARM THAT MAKES --baseline A LEDGER RATHER THAN A MUTE BUTTON. A baselined key
# that did not fire this run names a failure that is FIXED, and the line excusing it
# is now excusing nothing -- while still standing ready to suppress the next real
# instance of that same id, silently. That is a suppression with no lifetime, which is
# the shape this repo has already had to fix elsewhere.
#
# It is deliberately a FAIL and not a note: a note is what a stale baseline would
# accumulate for the rest of its life without anyone deleting a line.
n_base=0
if [ -n "$BASELINE_KEYS" ]; then
  while IFS= read -r bk; do
    [ -n "$bk" ] || continue
    n_base=$((n_base + 1))
    if ! grep -qxF -- "$bk" <<<"$BASELINE_HIT"; then
      echo "FAIL: baseline entry '$bk' in $BASELINE did NOT reproduce this run. The failure it was written to excuse is gone, so the entry now excuses nothing — and would silently suppress the next real instance of that same id. Delete the line. A baseline must not outlive its cause." >&2
      rc=1
    fi
  done <<<"$BASELINE_KEYS"
fi

if [ "$rc" -eq 0 ]; then
  echo "$PROG: PASS ($NLRS locked requirement(s), $NCAPS capability(ies), ${#STORIES[@]} story(ies), $note recorded note(s), $n_base baselined)"
fi
exit $rc
