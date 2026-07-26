#!/usr/bin/env bash
# validate-ac-falsifiability.sh — Rule 26(c) acceptance-criterion falsifiability
#
# Usage: ./scripts/ai-dlc/validate-ac-falsifiability.sh <story-file> [<story-file>...]
#        ./scripts/ai-dlc/validate-ac-falsifiability.sh --lexicon-from <path> <story-file>
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
#   1  -- a forbidden term on an unwaived AC, or an unresolvable prior_evidence
#   2  -- DISARMED or usage error. The lexicon could not be read, or parsed to
#         zero terms. An empty term list scans every story clean and prints the
#         same shape of output as a real pass, so it must not be able to exit 0.

set -u

PROG="validate-ac-falsifiability.sh"
LEXICON=""
FILES=()

while [ $# -gt 0 ]; do
  case "$1" in
    --lexicon-from) LEXICON="${2:-}"; shift 2 || { echo "$PROG: --lexicon-from needs a path" >&2; exit 2; } ;;
    -h|--help) echo "usage: $PROG [--lexicon-from PATH] <story-file>..." >&2; exit 2 ;;
    -*) echo "$PROG: unknown option $1" >&2; exit 2 ;;
    *) FILES+=("$1"); shift ;;
  esac
done

[ "${#FILES[@]}" -gt 0 ] || { echo "usage: $PROG [--lexicon-from PATH] <story-file>..." >&2; exit 2; }

# Locate the step file that owns the term list, FROM THE PROJECT ROOT, never from
# $0. This script installs at core/scripts/ in the distribution and scripts/ai-dlc/
# in a consumer, so counting `..` from its own location resolves to a different
# tree in each -- and the wrong answer is a directory that exists and holds
# something else, which is silently wrong rather than absent.
if [ -z "$LEXICON" ]; then
  ROOT="${AI_DLC_PROJECT_ROOT:-.}"
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
  echo "$PROG: DISARMED — the AC_UNBOUNDED_TERMS block in $LEXICON parsed to ZERO terms. Either the sentinels moved or the list was emptied. Exiting 2: a zero-term scan passes every story and prints the same shape of output as a full one." >&2
  exit 2
fi

rc=0
waivers=0
checked=0

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
  while IFS='|' read -r ac_id start end; do
    [ -n "$ac_id" ] && block_ids+=("$ac_id|$start|$end")
  done < <(awk '
    {
      if (match($0, /^[[:space:]]*[-*+][[:space:]]*\*\*AC[0-9]+[a-z]?[[:space:]]*(\(|—|-|:)/)) {
        if (id != "") print id "|" start "|" NR-1
        match($0, /AC[0-9]+[a-z]?/); id = substr($0, RSTART, RLENGTH)
        start = NR; next
      }
      if ($0 ~ /^#{1,6}[[:space:]]/ && id != "") { print id "|" start "|" NR-1; id = "" }
    }
    END { if (id != "") print id "|" start "|" NR }
  ' "$story")

  # DISARM: a story that declares acceptance criteria but presents none in the declared
  # form is not a clean story -- it is a story this script cannot read. Reporting PASS
  # on it is the exact defect this validator exists to catch, committed by the validator.
  if [ "${#block_ids[@]}" -eq 0 ] \
     && grep -qiE '^#{1,6}[[:space:]]*Acceptance Criteria|^acceptance_criteria:[[:space:]]*[1-9]' "$story"; then
    echo "$PROG: DISARMED — $story declares acceptance criteria but none are in the form stories-test-strategy.md mandates ('- **AC<n> (<tags>).**' or '- **AC<n> — <title>.**'). Exiting 2 rather than 0: an AC this script cannot read is not an AC that passed. Re-author the headers in the declared form." >&2
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
    printf '%s\n' "$body" | grep -qE '^[[:space:]]*falsifiability_waiver:[[:space:]]*[^[:space:]]' && waived=1

    while IFS= read -r term; do
      [ -n "$term" ] || continue
      if printf '%s\n' "$body" | grep -qiE "(^|[^[:alnum:]_])${term}([^[:alnum:]_]|\$)"; then
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
    done < <(printf '%s\n' "$body" | sed -n 's/^[[:space:]]*prior_evidence:[[:space:]]*//p' | tr -d '`')
  done
done

if [ "$rc" -eq 0 ]; then
  echo "$PROG: PASS (${#FILES[@]} story file(s), $checked AC block(s), $TERM_COUNT term(s) loaded, $waivers waiver(s))"
fi
exit $rc
