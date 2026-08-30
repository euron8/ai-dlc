#!/usr/bin/env bash
# predicate-differential.sh — does the INCOMING release reclassify artifacts the consumer has
# already STORED?
#
# THE DEFECT THIS EXISTS FOR. A release that moves an adjudication predicate re-renders every
# verdict that predicate has already given. The artifacts do not change, the incoming script is
# correct, no file in the pull's diff is wrong — and the consumer's stored history silently
# means something different afterwards. Nothing in the pull path looks, because every detector
# in `reconcile/` compares TEXT: core against core, or core against a consumer layer file. This
# is not a text difference. Only the VERDICT the one renders on the other has moved, and
# measuring that needs an EXECUTION over the consumer's own artifacts.
#
# Observed on the reference consumer at `0.438.0 -> 0.443.0` and filed as
# `PC-S307-PULL-CANNOT-SEE-WHAT-A-PREDICATE-CHANGE-RECLASSIFIES`. 0.442.0 changed arm B of
# validate-adversarial-convergence.sh from an equality on zero to a comparison against a new
# ceiling; that turned 33 of 105 stored adversarial series from pass to fail, three of them in a
# sprint that had been PAUSED. The pull reported nothing: 15 UPSTREAM-ONLY pure applies, zero
# conflicts, zero semantic merges, every bucket clean. It was caught by hand.
#
# THE DISTRIBUTION STRUCTURALLY CANNOT RUN THIS CHECK ITSELF, which is why it is sited in the
# pull. `consumer-boundary.md` is unconditional: no gate upstream reaches a consumer tree. And
# the failure is not hypothetical — the distribution DID run the same differential over its own
# check-24 fixture seeds before shipping 0.442.0, got two rows, and could not tell them apart,
# because the same session had authored both the predicate and the seed declaring the second row
# correct. A green fixture, a green mutant battery and a green gate were all consistent with the
# regression. The pull is the one process that runs on both sides of the boundary: it holds
# `base`, `theirs` and the consumer root at once, which is exactly the three inputs a
# differential needs.
#
# THE COMPARABLE VERDICT IS THE NAMED ARM, NEVER THE EXIT CODE, AND THAT IS MEASURED. The first
# cut of this script compared exit codes across the regression range over the reference
# consumer's real corpus and reported ZERO reclassifications. Sixteen series, sixteen identical
# 1 -> 1 pairs: this predicate fails CLOSED when `--transcript` is absent, the probe cannot
# supply one, so every series failed for the same unrelated reason on both sides. That null is
# two runs of a question neither side could answer, and it reads exactly like agreement — the
# precise shape `self-update-gate.sh`'s header warns about, arriving through a fail-closed flag
# instead of a usage error. Comparing the arm each side NAMES, same corpus, same refs, reports 1
# series gaining `B -- CONSISTENCY`, which is the arm the consumer's own filing named.
#
# IT REPORTS, IT NEVER BLOCKS. A consumer may legitimately accept a reclassification — the
# criteria genuinely moved and the new verdict is genuinely the right one. What is not
# acceptable is that it happen unremarked. So every row is advisory and the exit is always 0.
#
# Output: TSV — STATUS<TAB>SUBJECT<TAB>DETAIL, the same grammar as self-update-gate.sh.
#   PREDICATE-RECLASSIFIES  the incoming predicate renders a DIFFERENT verdict on stored
#                           artifacts. Carries a FLOOR, not a count — see below.
#   PREDICATE-STABLE        the predicate moved and no stored artifact changes verdict.
#   PREDICATE-UNDECIDABLE   the differential could not attribute an answer. Reported, never
#                           silently folded into STABLE: a detector that cannot read its own
#                           subject must not return clean.
# Exit: 0 ALWAYS. A classifier, not a gate — the CALLER decides, same posture as
#       self-update-gate.sh and layer-drift.sh.
set -uo pipefail

DIST="${1:?usage: predicate-differential.sh <dist-repo> <base-sha> <theirs-ref> <consumer-root>}"
BASE="${2:?}"
THEIRS="${3:?}"
CONSUMER="${4:?}"

emit() { printf '%s\t%s\t%s\n' "$1" "$2" "$3"; }

SELF_SRC="$0"
MANIFEST="$(dirname "$SELF_SRC")/predicate-sites.md"

if [ ! -f "$MANIFEST" ]; then
  emit PREDICATE-UNDECIDABLE "predicate-sites.md" "the site manifest is absent beside this script, so the set of adjudication predicates is unknown. A detector that cannot read its own population must not report clean."
  exit 0
fi

TMP="$(mktemp -d "${TMPDIR:-/tmp}/predicate-differential-XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

# The manifest's site blocks. Field-per-line, one block per predicate; a block is complete when
# `verdict:` closes it. `verdict:` is REQUIRED and a site missing it is refused rather than
# scored zero -- a site with no comparable verdict cannot produce a meaningful null.
awk '
  /^predicate:[[:space:]]/ { p=$2; c=""; s=""; i=""; v=""; next }
  /^corpus:[[:space:]]/    { c=substr($0, index($0,$2)); next }
  /^series:[[:space:]]/    { s=substr($0, index($0,$2)); next }
  /^invoke:[[:space:]]/    { i=substr($0, index($0,$2)); next }
  /^verdict:[[:space:]]/   { v=substr($0, index($0,$2));
                             if (p!="" && c!="" && s!="" && i!="" && v!="")
                               printf "%s\t%s\t%s\t%s\t%s\n", p, c, s, i, v;
                             p=""; next }
' "$MANIFEST" > "$TMP/sites.tsv"

if [ ! -s "$TMP/sites.tsv" ]; then
  emit PREDICATE-UNDECIDABLE "predicate-sites.md" "the manifest parsed to ZERO complete sites. An empty site set produces no rows and reads exactly like a clean differential, so it is reported instead."
  exit 0
fi

while IFS="$(printf '\t')" read -r P_PATH P_CORPUS P_SERIES P_INVOKE P_VERDICT; do
  [ -n "${P_PATH:-}" ] || continue
  p_name="$(basename "$P_PATH")"

  # ---- both sides, out of the distribution ------------------------------------------
  if ! git -C "$DIST" show "${BASE}:${P_PATH}" > "$TMP/base-$p_name" 2>/dev/null; then
    emit PREDICATE-STABLE "$p_name" "the predicate does not exist at ${BASE}, so this pull ADDS it. There is no prior verdict for a stored artifact to be reclassified AGAINST, and a first-time verdict is not a reclassification."
    continue
  fi
  if ! git -C "$DIST" show "${THEIRS}:${P_PATH}" > "$TMP/theirs-$p_name" 2>/dev/null; then
    emit PREDICATE-UNDECIDABLE "$p_name" "cannot read ${P_PATH} at ${THEIRS}, so the differential has no incoming side. This is not the same as the predicate being unchanged."
    continue
  fi

  # THE TWO SIDES MUST DIFFER. Two runs of one program produce a perfect null that reads
  # exactly like agreement -- `verification-discipline.md`, "a differential must prove its two
  # sides differ". Unchanged is a real and common answer; it is just not a measured one.
  if cmp -s "$TMP/base-$p_name" "$TMP/theirs-$p_name"; then
    emit PREDICATE-STABLE "$p_name" "byte-identical at ${BASE} and ${THEIRS} — this pull does not move this predicate, so no stored verdict can change. Reported rather than skipped: a null taken over two runs of the SAME program is not evidence about anything."
    continue
  fi

  # ---- the consumer's stored corpus --------------------------------------------------
  # READ THE LIVE TREE, and FINGERPRINT IT EITHER SIDE OF THE RUN. The discriminating
  # artifacts are the ones PREDATING the change, and a frozen or committed-only corpus
  # silently drops the in-flight ones. But a consumer's `_bmad-output/` is written by its own
  # running pipeline -- measured moving twice during a single upstream session -- so a figure
  # taken across a moving corpus is a snapshot of a file somebody else is holding open. The
  # honest handling is to take it live and refuse the answer if it moved underneath.
  find "$CONSUMER/_bmad-output" -type f -name "$P_CORPUS" 2>/dev/null | sort > "$TMP/records"
  fp_before="$(wc -c < "$TMP/records" | tr -d ' ')"

  if [ ! -s "$TMP/records" ]; then
    emit PREDICATE-UNDECIDABLE "$p_name" "the corpus pattern [$P_CORPUS] matched NO stored artifact under ${CONSUMER}/_bmad-output. A pattern that matches nothing reports zero reclassifications and reads exactly like a clean tree; those are different answers and this is the second one."
    continue
  fi

  sed -E "$P_SERIES" "$TMP/records" | sort -u > "$TMP/series"
  n_series="$(grep -c . < "$TMP/series")"

  : > "$TMP/pairs"
  n_parsed=0
  while IFS= read -r s; do
    [ -n "$s" ] || continue
    rel="${s#"$CONSUMER"/}"
    # shellcheck disable=SC2086 -- P_INVOKE is a declared argument FORM, deliberately split.
    inv="$(printf '%s' "$P_INVOKE" | sed "s|{series}|$rel|")"
    a_base="$( ( cd "$CONSUMER" && bash "$TMP/base-$p_name"   $inv 2>&1 ) | sed -nE "$P_VERDICT" | sort -u | tr '\n' ',')"
    a_theirs="$( ( cd "$CONSUMER" && bash "$TMP/theirs-$p_name" $inv 2>&1 ) | sed -nE "$P_VERDICT" | sort -u | tr '\n' ',')"
    [ -n "$a_base" ] || [ -n "$a_theirs" ] && n_parsed=$((n_parsed + 1))
    printf '%s\t%s\t%s\n' "$a_base" "$a_theirs" "$rel" >> "$TMP/pairs"
  done < "$TMP/series"

  find "$CONSUMER/_bmad-output" -type f -name "$P_CORPUS" 2>/dev/null | sort > "$TMP/records2"
  fp_after="$(wc -c < "$TMP/records2" | tr -d ' ')"
  if [ "$fp_before" != "$fp_after" ]; then
    emit PREDICATE-UNDECIDABLE "$p_name" "the consumer's artifact corpus CHANGED while the differential was running (${fp_before} -> ${fp_after} bytes of path list) — its own pipeline is live. Any count taken across a moving corpus is a snapshot of a file another party is holding open. Re-run against a quiescent tree."
    continue
  fi

  # A CORPUS THAT PARSED TO NOTHING CANNOT DISCRIMINATE. If the verdict grammar extracted no
  # token from EITHER side of any series, the grammar is wrong or the predicate never ran, and
  # both of those report zero reclassifications. `verification-discipline.md`: point a search
  # grammar at its own subject before trusting its zero.
  if [ "$n_parsed" -eq 0 ]; then
    emit PREDICATE-UNDECIDABLE "$p_name" "the verdict grammar extracted NO token from either side across all ${n_series} series, so nothing was compared. A grammar that cannot spell its own subject scores every series as unchanged. This is a floor of unknown depth, not a clean result."
    continue
  fi

  n_changed="$(awk -F'\t' '$1!=$2' "$TMP/pairs" | grep -c . || true)"

  if [ "$n_changed" -eq 0 ]; then
    emit PREDICATE-STABLE "$p_name" "the predicate moved and NO stored artifact changes verdict: ${n_series} series compared, ${n_parsed} of them yielding a verdict token on at least one side. The ${n_parsed} is the discriminating subset and it is a FLOOR — a series whose verdict is unparseable on both sides is counted as unchanged and cannot report otherwise."
    continue
  fi

  # THE COUNT IS A FLOOR AND THE ROW SAYS SO IN ITS OWN TEXT. Artifacts written UNDER the
  # incoming predicate agree with it by construction, so they cannot discriminate; the series
  # that can are the ones predating the change, and which those are is not derivable here. A
  # detector that printed a bare count would reproduce the vacuous-clean failure one level up.
  emit PREDICATE-RECLASSIFIES "$p_name" "AT LEAST ${n_changed} of ${n_series} stored series change verdict under the incoming ${p_name} (${n_parsed} yielded a comparable verdict at all). This is a FLOOR, not a count: a series written under the incoming predicate agrees with it by construction and cannot discriminate, and one whose verdict is unparseable on both sides is scored unchanged. Nothing in the pull's own diff is wrong — the artifacts did not move, the verdict on them did. Review the changed series before accepting this pull, and note that accepting it is a legitimate choice: this row does not block."

  awk -F'\t' '$1!=$2 {print $3"\t["$1"] -> ["$2"]"}' "$TMP/pairs" \
  | while IFS="$(printf '\t')" read -r c_path c_delta; do
      emit PREDICATE-RECLASSIFIES "$c_path" "verdict tokens $c_delta under $p_name."
    done
done < "$TMP/sites.tsv"

exit 0
