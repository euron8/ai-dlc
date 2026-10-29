#!/usr/bin/env bash
# validate-ac-falsifiability.sh — Rule 26(c) acceptance-criterion falsifiability
#
# Usage: ./scripts/ai-dlc/validate-ac-falsifiability.sh <story-file> [<story-file>...]
#        ./scripts/ai-dlc/validate-ac-falsifiability.sh --lexicon-from <path> <story-file>
#        ./scripts/ai-dlc/validate-ac-falsifiability.sh --stories-dir <dir> [<story-file>...]
#
# Gate-validation Check 31 enforcer (story gates).
#
# WHAT IT GUARDS. Check 3a asks whether a story's acceptance criteria COVER its
# requirement. It never reads whether an individual AC states a predicate a
# verifier can fail. An AC can cover every element of its requirement and still
# assert nothing: "Exhaustive reference search across CDK source, EFS TOML
# template, SSM parameters" names no set, so no run of it can come back red, and
# the gate that reads it records PASS for a verification that was never
# performed. Same shape: an AC requiring a fact be "stated definitively" with no
# definition of what definitive means, and an AC citing a prior story's scale
# anchor in prose that proves unlocatable at verification time.
#
# TWO CLAUSES, both mechanical:
#
#   (a) TERM BAN. No term from the `AC_UNBOUNDED_TERMS` list appears in an AC
#       block, unless that block carries a `falsifiability_waiver:` line. A term
#       is on that list because no run of a predicate stated with it can come
#       back red — a property of the word, not of how often anyone has used it.
#
#   (b) PRIOR-EVIDENCE RESOLVABILITY. Every `prior_evidence:` citation resolves
#       to a path on disk, and to a literal present in that file when an anchor
#       is given. This proves RETRIEVABILITY, not provenance: it cannot say
#       whether the cited file is the one that produced the number. Do not read
#       more into a pass than that.
#
#   (c) RUN WINDOW INSIDE THE PLANNED CLOSE. An AC whose earliest permitted run
#       time falls after the sprint's planned close cannot be discharged inside
#       the sprint, so the sprint either closes over an undischarged AC or waits
#       on it. Measured: s320 story 1.3 AC4 could not run before
#       2026-10-29T09:36:22Z, and nothing in the story or the envelope said the
#       sprint would close first. Two per-AC lines, inside the AC block, in the
#       same shape as `falsifiability_waiver:`:
#
#         run_not_before: <YYYY-MM-DDTHH:MM:SSZ>   earliest permitted run, UTC
#         defers_to: CO-S<N>-<descriptor>          the AC is planned for deferral;
#                                                  id grammar from
#                                                  carry-over-evaluation.md
#
#       and one sprint-level key, `planned_close: <YYYY-MM-DDTHH:MM:SSZ>`, in the
#       sprint block of the canonical sprint-status yaml, written by the lead at
#       sprint planning (stories-test-strategy.md §3).
#
#       REFUSED run-window-after-close <story> <AC>
#           run_not_before is later than planned_close and the AC has no
#           defers_to. Equal is inside the window.
#       REFUSED planned-close-missing <story>
#           the floor is in force, some AC in the story carries run_not_before,
#           and no canonical carries planned_close.
#       REFUSED run-window-malformed / planned-close-malformed / defers-to-malformed
#           the offending text is named. A malformed timestamp compared as a
#           string is a silent wrong verdict, and a free-text defers_to would be
#           an exemption anyone can write, so neither is read past.
#
#       THE NARROWING, AND WHY. A story with NO run_not_before line is never
#       refused for a missing planned_close. The refusal guards a comparison;
#       with no window there is nothing to compare, and refusing anyway would
#       fail every story gate of a sprint planned before this release, over a
#       key nothing in that sprint needs.
#
#       NOTHING IS RESOLVED UNTIL A WINDOW EXISTS. The canonical yaml, the floor
#       and the floor's script are read only when some AC in the run carries
#       run_not_before. A consumer whose stories carry no window runs exactly as
#       before this clause existed.
#
#       NOT OPT-IN: THE CANONICAL IS READ FROM THE PROJECT ROOT, NOT FROM AN
#       ARGUMENT. Check 31 invokes this script with story paths and nothing else,
#       so a `--status <yaml>` flag would be a check nobody's gate passes. The
#       canonicals are the two sprint-status.sh writes:
#       _bmad-output/implementation-artifacts/sprint-status.yaml, then
#       _bmad-output/planning-artifacts/sprint-status.yaml. `sprint:` is read from
#       the first that exists; `planned_close:` from the first that carries a
#       non-empty one, because the producer names "the sprint-status yaml"
#       without naming a view. Both are col-0 scalar lines read with one sed in
#       the shape of the schema's `keys.sprint_re`; sprint-status.sh has no mode
#       printing a top-level scalar (`sprint-id` applies done -> N+1, which is the
#       wrong number here). AI_DLC_PROJECT_ROOT overrides the root.
#
#       THE FLOOR IS CHECK 28'S, THE SAME ONE CHECKS 29/30/31 USE:
#       `validate-spec-adoption.sh --verdict <sprint>`, the sibling of this script
#       in both layouts. The sprint passed is the canonical's own `sprint:`, the
#       sprint whose planned_close is being compared. No mechanical
#       creation-sprint source exists; Checks 30/31 name the creation sprint in
#       prose only.
#         SKIPPED-PRE-ADOPTION -> `SKIP RUN-WINDOW (below floor)`, exit unchanged
#         IN-FORCE             -> clause (c) is judged
#         PENDING / malformed  -> `SKIP RUN-WINDOW (floor undeclared|malformed)`,
#                                 exit unchanged. A DECISION, and the one branch
#                                 shaped like a fail-open: Check 28 already FAILS
#                                 every planning gate on both states, so refusing
#                                 here too would double-report one defect.
#         the script absent    -> DISARMED, exit 2.
#
#       --stories-dir <dir> runs every *.md in <dir> and prints ONE line,
#       `EARLIEST-CLOSE <iso>`: the max over the well-formed run_not_before values
#       of ACs that carry no well-formed defers_to, or `EARLIEST-CLOSE none`. The
#       wave plan copies that line; it never computes one. Printed on every run in
#       that mode, refusals included, and independent of the floor.
#
# BLOCK SCOPE, NOT LINE SCOPE. A line-scoped predicate is evaded by pressing
# Enter: a forbidden term on an AC's second line is the same defect as one on its
# first. Segmentation is per AC block.
#
# NO ENUMERATION ESCAPE. An exemption for an AC that "also contains an
# enumeration" cannot be built: every structural proxy for it (a comma-bearing
# parenthetical, a counted quantifier) is satisfied by the tag parenthetical
# `(UNIVERSAL, live_ops)` or by boilerplate, so the exemption swallows the very
# ACs the ban exists to reject while printing output identical to a real pass.
# The only exemption is the explicit, greppable, always-reported waiver token.
#
# ONE LIST, NOT TWO. The term list is read out of the step file at run time,
# between the `AC_UNBOUNDED_TERMS` sentinels. This script carries no fallback
# copy. A second copy is a copy that drifts, and a drifted copy under-fires
# silently — the same defect the gate manifest was restructured to remove.
#
# EXIT CODES
#   0  -- every AC block clean (waivers printed, not fatal)
#   1  -- a forbidden term on an unwaived AC, an unresolvable prior_evidence, or a
#         clause (c) refusal
#   2  -- DISARMED or usage error. The lexicon could not be read, or parsed to
#         zero terms, or a read of a story did not run. An empty term list scans every story clean and prints the
#         same shape of output as a real pass, so it must not be able to exit 0.
#         Also: a window exists and no canonical, no `sprint:`, or no floor script
#         could be read; or --stories-dir holds no *.md.

set -u

PROG="validate-ac-falsifiability.sh"
LEXICON=""
STORIES_DIR=""
FILES=()

while [ $# -gt 0 ]; do
  case "$1" in
    --lexicon-from) LEXICON="${2:-}"; shift 2 || { echo "$PROG: --lexicon-from needs a path" >&2; exit 2; } ;;
    --stories-dir) STORIES_DIR="${2:-}"; shift 2 || { echo "$PROG: --stories-dir needs a directory" >&2; exit 2; } ;;
    -h|--help) echo "usage: $PROG [--lexicon-from PATH] [--stories-dir DIR] <story-file>..." >&2; exit 2 ;;
    -*) echo "$PROG: unknown option $1" >&2; exit 2 ;;
    *) FILES+=("$1"); shift ;;
  esac
done

if [ -n "$STORIES_DIR" ]; then
  [ -d "$STORIES_DIR" ] || { echo "$PROG: DISARMED — --stories-dir $STORIES_DIR is not a directory" >&2; exit 2; }
  _sd_n=0
  for _sd_f in "$STORIES_DIR"/*.md; do
    [ -f "$_sd_f" ] || continue
    FILES+=("$_sd_f"); _sd_n=$((_sd_n+1))
  done
  # A glob that matched nothing must not read as a directory with no windows.
  [ "$_sd_n" -gt 0 ] || { echo "$PROG: DISARMED — --stories-dir $STORIES_DIR holds no *.md story file; EARLIEST-CLOSE none would read as a sprint with no windows" >&2; exit 2; }
fi

[ "${#FILES[@]}" -gt 0 ] || { echo "usage: $PROG [--lexicon-from PATH] [--stories-dir DIR] <story-file>..." >&2; exit 2; }

# Locate the step file that owns the term list, FROM THE PROJECT ROOT, never from
# $0. This script installs at core/scripts/ in the distribution and scripts/ai-dlc/
# in a consumer, so counting `..` from its own location resolves to a different
# tree in each -- and the wrong answer is a directory that exists and holds
# something else, which is silently wrong rather than absent.
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

if [ -z "$LEXICON" ]; then
  ROOT="$AI_DLC_ROOT"
  for cand in \
    "$ROOT/.claude/skills/ai-dlc/steps/stories-test-strategy.md" \
    "$ROOT/core/skills/ai-dlc/steps/stories-test-strategy.md"; do
    [ -f "$cand" ] && { LEXICON="$cand"; break; }
  done
fi

if [ -z "$LEXICON" ] || [ ! -f "$LEXICON" ]; then
  echo "$PROG: DISARMED — could not locate stories-test-strategy.md to read the AC_UNBOUNDED_TERMS list from. Pass --lexicon-from <path>. Exiting 2 rather than 0: with no term list this script reports every story clean, which is indistinguishable from a real pass." >&2
  exit 2
fi

TERMS="$(sed -n '/<!-- AC_UNBOUNDED_TERMS v1 -->/,/<!-- AC_UNBOUNDED_TERMS_END -->/p' "$LEXICON" \
  | sed '1d;$d' | tr ',' '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v '^$' | sort -u)"

TERM_COUNT="$(printf '%s\n' "$TERMS" | grep -c . )"
if [ "$TERM_COUNT" -eq 0 ]; then
  echo "$PROG: DISARMED — EXAMINED NOTHING — the AC_UNBOUNDED_TERMS block in $LEXICON parsed to ZERO terms. Either the sentinels moved or the list was emptied. Exiting 2: a zero-term scan passes every story and prints the same shape of output as a full one." >&2
  exit 2
fi

rc=0
waivers=0
checked=0

# EVERY LOOP FEED BELOW IS STAGED TO A FILE AND ITS PRODUCER'S STATUS IS READ. They used to read
# `done < <(awk …)` and `done < <(printf | sed | tr)`, which discard the status: an awk that could
# not read a story segmented it into ZERO AC blocks, the label probe could not read it either,
# and the story was skipped and the run printed PASS -- a false clear. This file does not set
# `pipefail`, so each fallible stage is staged ALONE. A producer that did not run is DISARMED,
# exit 2, this script's existing refusal. One directory per run, removed on exit.
ACF_T="$(mktemp -d "${TMPDIR:-/tmp}/validate-ac-falsifiability.XXXXXX")" || {
  echo "$PROG: DISARMED — the staging directory did not run (mktemp failed); no verdict." >&2
  exit 2
}
trap 'rm -rf "$ACF_T"' EXIT
acf_refuse() { # acf_refuse <what> <status>
  echo "$PROG: DISARMED — $1 did not run (exit $2). Exiting 2 rather than 0: a story this script could not read is not a story that passed." >&2
  exit 2
}

# --- clause (c) helpers. Pure bash: no fork per value. ---------------------------
rw_clean() { # <raw> -> the value without a trailing `# comment`, surrounding blanks, or one layer of quotes
  local v="$1"
  v="${v%%[[:space:]]#*}"
  v="${v#"${v%%[![:space:]]*}"}"
  v="${v%"${v##*[![:space:]]}"}"
  case "$v" in
    \"*\"|\'*\'|\`*\`) v="${v#?}"; v="${v%?}" ;;
  esac
  printf '%s' "$v"
}
rw_iso_ok() { # <text> -> 0 iff YYYY-MM-DDTHH:MM:SSZ with in-range fields. Only then is string order time order.
  case "$1" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z) ;;
    *) return 1 ;;
  esac
  local mo=$((10#${1:5:2})) dd=$((10#${1:8:2})) hh=$((10#${1:11:2})) mi=$((10#${1:14:2})) ss=$((10#${1:17:2}))
  [ "$mo" -ge 1 ] && [ "$mo" -le 12 ] && [ "$dd" -ge 1 ] && [ "$dd" -le 31 ] \
    && [ "$hh" -le 23 ] && [ "$mi" -le 59 ] && [ "$ss" -le 59 ]
}
rw_co_ok() { # <text> -> 0 iff a carry-over id, CO-S<sprint>-<descriptor> (carry-over-evaluation.md)
  case "$1" in
    CO-S[0-9]*-[A-Za-z0-9]*) ;;
    *) return 1 ;;
  esac
  local n="${1#CO-S}"; n="${n%%-*}"
  case "$n" in ''|*[!0-9]*) return 1 ;; esac
  case "${1#CO-S"$n"-}" in *[!A-Za-z0-9._-]*) return 1 ;; esac
  return 0
}

for story in "${FILES[@]}"; do
  if [ ! -f "$story" ]; then
    echo "$PROG: DISARMED — no such story file: $story" >&2
    exit 2
  fi
  story_dir="$(cd "$(dirname "$story")" && pwd)"

  # Segment into AC blocks against the ONE declared header form (stories-test-strategy.md,
  # "AC header form"):  - **AC<n> (<tags>).**   or   - **AC<n> — <title>.**
  #
  # ONE FORM, DECLARED, NOT A DIALECT SURVEY. A recognizer that tries to accept every
  # shape an author might pick is guessing, and every shape it fails to guess is a
  # story reported clean without being read. The step file mandates the form; this
  # reads exactly that form; anything else disarms below. The mandate is the mechanism.
  #
  # A BLOCK CLOSES AT THE NEXT AC HEADER OR THE NEXT MARKDOWN HEADING. The second half
  # is load-bearing: without it the final AC absorbs every trailing section, and prose
  # describing a fixture ("this exhaustive fixture also discharges AC1's property") is
  # judged as that AC's predicate.
  block_ids=()
  _acf_rc=0
  awk '
    {
      if (match($0, /^[[:space:]]*[-*+][[:space:]]*\*\*AC[0-9]+[a-z]?[[:space:]]*(\(|—|-|:)/)) {
        if (id != "") print id "|" start "|" NR-1
        match($0, /AC[0-9]+[a-z]?/); id = substr($0, RSTART, RLENGTH)
        start = NR; next
      }
      if ($0 ~ /^#{1,6}[[:space:]]/ && id != "") { print id "|" start "|" NR-1; id = "" }
    }
    END { if (id != "") print id "|" start "|" NR }
  ' "$story" > "$ACF_T/ac-blocks" || _acf_rc=$?
  [ "$_acf_rc" -eq 0 ] || acf_refuse "segmenting $story into AC blocks" "$_acf_rc"
  while IFS='|' read -r ac_id start end; do
    [ -n "$ac_id" ] && block_ids+=("$ac_id|$start|$end")
  done < "$ACF_T/ac-blocks"

  # DISARM: a story that declares acceptance criteria but presents none in the declared
  # form is not a clean story -- it is a story this script cannot read. Reporting PASS
  # on it is the exact defect this validator exists to catch, committed by the validator.
  #
  # THE TRIGGER SET IS WIDE ON PURPOSE. A first version tested only for a
  # `## Acceptance Criteria` HEADING or an `acceptance_criteria:` frontmatter field.
  # `bmad-create-epics-and-stories` emits neither: its real output carries a BOLD
  # INLINE `**Acceptance Criteria:**` label followed by unnumbered Given/When/Then
  # blocks, and contains ZERO `AC` tokens. Measured against that real output, this
  # script reported PASS with "0 AC block(s)" on a story whose criteria contained both
  # `definitively` and `exhaustive` — a silent false pass, which is the defect class
  # this check exists to remove, committed by the check.
  #
  # Any of: an Acceptance-Criteria label in heading, bold or bare form; or a
  # Given/When/Then block. Zero parsed AC blocks alongside any of them is a story this
  # script cannot read.
  if [ "${#block_ids[@]}" -eq 0 ] && grep -qiE \
       '^#{1,6}[[:space:]]*\**[[:space:]]*Acceptance[[:space:]]+Criteria|^[[:space:]]*\*\*Acceptance[[:space:]]+Criteria|^acceptance_criteria:[[:space:]]*[1-9]|^[[:space:]]*\*\*(Given|When|Then)\*\*' \
       "$story"; then
    echo "$PROG: DISARMED — $story presents acceptance criteria that are not in the form stories-test-strategy.md mandates ('- **AC<n> (<tags>).**' or '- **AC<n> — <title>.**'). Exiting 2 rather than 0: an AC this script cannot read is not an AC that passed. If these came from bmad-create-epics-and-stories, its Given/When/Then blocks must be re-authored into numbered ACs when the story file is created — that is stories-test-strategy.md's job, not this script's." >&2
    exit 2
  fi

  # bash 3.2 expands ${arr[@]} on an EMPTY array as unbound under `set -u`, so a
  # story with no AC blocks would abort here rather than report cleanly. Guard on
  # the count; do not drop `set -u`.
  [ "${#block_ids[@]}" -eq 0 ] && continue

  for entry in "${block_ids[@]}"; do
    ac_id="${entry%%|*}"; rest="${entry#*|}"
    start="${rest%%|*}"; end="${rest##*|}"
    body="$(sed -n "${start},${end}p" "$story")"
    checked=$((checked+1))

    waived=0
    grep -qE '^[[:space:]]*falsifiability_waiver:[[:space:]]*[^[:space:]]' <<<"$body" && waived=1

    while IFS= read -r term; do
      [ -n "$term" ] || continue
      if grep -qiE "(^|[^[:alnum:]_])${term}([^[:alnum:]_]|\$)" <<<"$body"; then
        if [ "$waived" -eq 1 ]; then
          wtext="$(printf '%s\n' "$body" | sed -n 's/^[[:space:]]*falsifiability_waiver:[[:space:]]*//p' | head -1)"
          echo "  waiver  $story $ac_id '$term' — $wtext"
          waivers=$((waivers+1))
        else
          excerpt="$(printf '%s\n' "$body" | grep -iE "(^|[^[:alnum:]_])${term}([^[:alnum:]_]|\$)" | head -1 | cut -c1-100)"
          echo "FAIL: $story $ac_id states its predicate with '$term', which names no bounded set — no run of this AC can come back red, so a gate reading it records PASS for a verification never performed. Replace the term with the enumerated members, their count, and an EQUALS assertion against the observed set; or add 'falsifiability_waiver: <what is unbounded, and why>' inside this AC. Line: $excerpt" >&2
          rc=1
        fi
        break
      fi
    done <<< "$TERMS"

    printf '%s\n' "$body" > "$ACF_T/ac-body" || acf_refuse "staging $story $ac_id" "$?"
    _acf_rc=0
    sed -n 's/^[[:space:]]*prior_evidence:[[:space:]]*//p' "$ACF_T/ac-body" > "$ACF_T/ac-cites-raw" || _acf_rc=$?
    [ "$_acf_rc" -eq 0 ] || acf_refuse "reading the prior_evidence citations of $story $ac_id" "$_acf_rc"
    tr -d '`' < "$ACF_T/ac-cites-raw" > "$ACF_T/ac-cites" || _acf_rc=$?
    [ "$_acf_rc" -eq 0 ] || acf_refuse "unquoting the prior_evidence citations of $story $ac_id" "$_acf_rc"
    while IFS= read -r cite; do
      [ -n "$cite" ] || continue
      cpath="$cite"; anchor=""
      case "$cite" in
        *:*) cpath="${cite%:*}"; anchor="${cite##*:}" ;;
      esac
      resolved=""
      for base in "." "$story_dir"; do
        [ -f "$base/$cpath" ] && { resolved="$base/$cpath"; break; }
      done
      if [ -z "$resolved" ]; then
        echo "FAIL: $story $ac_id cites 'prior_evidence: $cite' and that path is not on disk. An AC consuming a value it cannot retrieve is a promissory note against evidence that may never have existed. Correct the path, or produce the artifact in this story." >&2
        rc=1
      elif [ -n "$anchor" ] && ! grep -qF -- "$anchor" "$resolved"; then
        echo "FAIL: $story $ac_id cites 'prior_evidence: $cite' but '$anchor' is absent from $resolved. The file resolves and the anchor does not, so the citation points into a document that no longer says what the AC assumes." >&2
        rc=1
      fi
    done < "$ACF_T/ac-cites"

    # Clause (c), collection only. Judged after every story is read, so the canonical and
    # the floor are resolved once and only when a window exists.
    _acf_rc=0
    sed -n 's/^[[:space:]]*run_not_before:[[:space:]]*//p' "$ACF_T/ac-body" > "$ACF_T/ac-rnb" || _acf_rc=$?
    [ "$_acf_rc" -eq 0 ] || acf_refuse "reading the run_not_before line of $story $ac_id" "$_acf_rc"
    sed -n 's/^[[:space:]]*defers_to:[[:space:]]*//p' "$ACF_T/ac-body" > "$ACF_T/ac-dto" || _acf_rc=$?
    [ "$_acf_rc" -eq 0 ] || acf_refuse "reading the defers_to line of $story $ac_id" "$_acf_rc"
    rnb_raw=""; IFS= read -r rnb_raw < "$ACF_T/ac-rnb"
    dto_raw=""; IFS= read -r dto_raw < "$ACF_T/ac-dto"
    deferred=0
    if [ -s "$ACF_T/ac-dto" ]; then
      dto="$(rw_clean "$dto_raw")"
      if rw_co_ok "$dto"; then
        deferred=1
      else
        echo "REFUSED defers-to-malformed $story $ac_id — 'defers_to: $dto_raw' is not a carry-over id CO-S<sprint>-<descriptor> (carry-over-evaluation.md). A free-text deferral is an exemption anyone can write." >&2
        rc=1
      fi
    fi
    if [ -s "$ACF_T/ac-rnb" ]; then
      rnb="$(rw_clean "$rnb_raw")"
      if rw_iso_ok "$rnb"; then
        printf '%s|%s|%s|%s\n' "$story" "$ac_id" "$rnb" "$deferred" >> "$ACF_T/windows" \
          || acf_refuse "staging the run window of $story $ac_id" "$?"
      else
        echo "REFUSED run-window-malformed $story $ac_id — 'run_not_before: $rnb_raw' is not YYYY-MM-DDTHH:MM:SSZ (UTC, Z suffix, in-range fields)." >&2
        rc=1
      fi
    fi
  done
done

# --- clause (c), judged ---------------------------------------------------------------
if [ -s "$ACF_T/windows" ]; then
  RW_YAML=""
  for _c in "$AI_DLC_ROOT/_bmad-output/implementation-artifacts/sprint-status.yaml" \
            "$AI_DLC_ROOT/_bmad-output/planning-artifacts/sprint-status.yaml"; do
    [ -f "$_c" ] && { RW_YAML="$_c"; break; }
  done
  [ -n "$RW_YAML" ] || { echo "$PROG: DISARMED — an AC carries run_not_before and no canonical sprint-status.yaml exists under $AI_DLC_ROOT/_bmad-output/{implementation,planning}-artifacts/; the window has nothing to be compared against. Set AI_DLC_PROJECT_ROOT to the project root." >&2; exit 2; }
  RW_SPRINT="$(sed -n 's/^sprint:[[:space:]]*\([0-9][0-9]*\)[[:space:]]*\(#.*\)\{0,1\}$/\1/p' "$RW_YAML" | head -1)"
  [ -n "$RW_SPRINT" ] || { echo "$PROG: DISARMED — $RW_YAML has no top-level integer 'sprint:' line, so the spec-adoption floor cannot be asked about this sprint." >&2; exit 2; }
  RW_FLOOR_SH="$AI_DLC_SELF_DIR/validate-spec-adoption.sh"
  [ -f "$RW_FLOOR_SH" ] || { echo "$PROG: DISARMED — an AC carries run_not_before and $RW_FLOOR_SH, the Check 28 floor every spec check reads, is not beside this script." >&2; exit 2; }
  RW_VERDICT="$(bash "$RW_FLOOR_SH" --verdict "$RW_SPRINT" "$AI_DLC_ROOT" 2>/dev/null)"; RW_VRC=$?
  RW_STATE=""
  case "$RW_VRC" in
    0) case "$RW_VERDICT" in
         IN-FORCE*) RW_STATE=in-force ;;
         SKIPPED-PRE-ADOPTION*) RW_STATE="below floor" ;;
       esac ;;
    2) RW_STATE="floor undeclared" ;;
    1) RW_STATE="floor malformed" ;;
  esac
  [ -n "$RW_STATE" ] || { echo "$PROG: DISARMED — validate-spec-adoption.sh --verdict $RW_SPRINT answered rc=$RW_VRC '$RW_VERDICT', which is none of its four states." >&2; exit 2; }
  if [ "$RW_STATE" != in-force ]; then
    echo "SKIP RUN-WINDOW ($RW_STATE) s$RW_SPRINT — clause (c) not judged"
  else
    RW_CLOSE_RAW=""; RW_CLOSE_SRC=""
    for _c in "$AI_DLC_ROOT/_bmad-output/implementation-artifacts/sprint-status.yaml" \
              "$AI_DLC_ROOT/_bmad-output/planning-artifacts/sprint-status.yaml"; do
      [ -f "$_c" ] || continue
      _v="$(sed -n 's/^planned_close:[[:space:]]*//p' "$_c" | head -1)"
      _v="$(rw_clean "$_v")"
      [ -n "$_v" ] && { RW_CLOSE_RAW="$_v"; RW_CLOSE_SRC="$_c"; break; }
    done
    RW_CLOSE_OK=0
    if [ -n "$RW_CLOSE_RAW" ]; then
      if rw_iso_ok "$RW_CLOSE_RAW"; then
        RW_CLOSE_OK=1
      else
        echo "REFUSED planned-close-malformed — 'planned_close: $RW_CLOSE_RAW' in $RW_CLOSE_SRC is not YYYY-MM-DDTHH:MM:SSZ (UTC, Z suffix, in-range fields)." >&2
        rc=1
      fi
    fi
    _rw_last_missing=""
    while IFS='|' read -r w_story w_ac w_rnb w_def; do
      [ -n "$w_story" ] || continue
      if [ -z "$RW_CLOSE_RAW" ]; then
        # Once per story: the refusal is about the story's window, not each AC.
        if [ "$w_story" != "$_rw_last_missing" ]; then
          echo "REFUSED planned-close-missing $w_story — $w_ac carries run_not_before: $w_rnb and no canonical sprint-status.yaml carries planned_close for s$RW_SPRINT (floor in force). The lead writes planned_close at sprint planning." >&2
          rc=1; _rw_last_missing="$w_story"
        fi
        continue
      fi
      [ "$RW_CLOSE_OK" -eq 1 ] || continue
      [ "$w_def" = 1 ] && continue
      if [[ "$w_rnb" > "$RW_CLOSE_RAW" ]]; then
        echo "REFUSED run-window-after-close $w_story $w_ac — run_not_before $w_rnb is later than planned_close $RW_CLOSE_RAW and the AC names no defers_to. Move the window, move the close, or add 'defers_to: CO-S<N>-<descriptor>' inside the AC." >&2
        rc=1
      fi
    done < "$ACF_T/windows"
  fi
fi

if [ -n "$STORIES_DIR" ]; then
  RW_EARLIEST=""
  if [ -s "$ACF_T/windows" ]; then
    while IFS='|' read -r w_story w_ac w_rnb w_def; do
      [ "$w_def" = 0 ] || continue
      if [ -z "$RW_EARLIEST" ] || [[ "$w_rnb" > "$RW_EARLIEST" ]]; then RW_EARLIEST="$w_rnb"; fi
    done < "$ACF_T/windows"
  fi
  echo "EARLIEST-CLOSE ${RW_EARLIEST:-none}"
fi

if [ "$rc" -eq 0 ]; then
  echo "$PROG: PASS (${#FILES[@]} story file(s), $checked AC block(s), $TERM_COUNT term(s) loaded, $waivers waiver(s))"
  echo "  lexicon:     $LEXICON"
  echo "  story files: ${FILES[*]:-}"
fi
exit $rc
