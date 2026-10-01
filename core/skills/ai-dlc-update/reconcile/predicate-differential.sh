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
#       self-update-gate.sh. (layer-drift.sh shares the classifier posture but NOT the exit:
#       it exits 2 when a row could not be written.)
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
#
# `corpus-root:` is OPTIONAL and defaults to `_bmad-output`, the root every site used before the
# field existed. The default is emitted HERE, never left empty: tab is IFS whitespace to `read`,
# so an empty column collapses and every later field shifts one place left.
#
# A `corpus-root:` that could leave the consumer tree or split the TSV is refused here and the
# refusal is carried to the site's row as `!bad:<reason>`: a `..` component, a leading `/`, or
# any whitespace. The value is taken by stripping the key, never by `index($0,$2)`, which finds
# a value like `root` inside the key itself.
#
# `pass:` is OPTIONAL: a `sed -nE` expression matching the line the predicate prints when it
# PASSES. With it, a series yielding no verdict token on either side is counted as passed when
# both sides print that line and unclassified otherwise. Without it, a grammar that spells only
# failures cannot tell those two apart, and the row says so instead of printing a number. It is
# emitted as `-` when absent, for the same collapsing-tab reason as the root default.
awk '
  /^reads:[[:space:]]/       { r=substr($0, index($0,$2)); e=""; c=""; s=""; i=""; v=""; k=""; p=""; next }
  /^entry:[[:space:]]/       { e=$2; next }
  /^corpus-root:[[:space:]]/ { k=$0; sub(/^corpus-root:[[:space:]]*/, "", k); sub(/[[:space:]]+$/, "", k);
                               if (k ~ /[[:space:]]/)                 k="!bad:whitespace";
                               else if (k ~ /^\//)                    k="!bad:absolute";
                               else if (k ~ /(^|\/)\.\.(\/|$)/)       k="!bad:parent";
                               next }
  /^corpus:[[:space:]]/      { c=substr($0, index($0,$2)); next }
  /^series:[[:space:]]/      { s=substr($0, index($0,$2)); next }
  /^invoke:[[:space:]]/      { i=substr($0, index($0,$2)); next }
  /^pass:[[:space:]]/        { p=$0; sub(/^pass:[[:space:]]*/, "", p); next }
  /^verdict:[[:space:]]/     { v=substr($0, index($0,$2));
                               if (k=="") k="_bmad-output";
                               if (p=="") p="-";
                               if (r!="" && e!="" && c!="" && s!="" && i!="" && v!="")
                                 printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", r, e, c, s, i, v, k, p;
                               r=""; next }
' "$MANIFEST" > "$TMP/sites.tsv"

# THE CONSUMER'S KNOWN-SKILLS EXTENSION, RESOLVED ONCE, THE WAY A VALIDATOR ROOTED AT THE CONSUMER
# WOULD. Each side below runs with its project root pinned to its own probe root, so a predicate
# that searches for this file under that root finds nothing on EITHER side -- an identical empty
# input that parses as agreement. It is consumer DATA, not distribution data, so both sides get
# the consumer's copy, by path. A caller that set the variable explicitly keeps its value. An
# absent file is passed as an empty value, which the validator reads as "no extension".
if [ -n "${AI_DLC_KNOWN_SKILLS_EXT+x}" ]; then
  PD_EXT="$AI_DLC_KNOWN_SKILLS_EXT"
else
  PD_EXT=""
  for cand in "$CONSUMER/.claude/skills/ai-dlc/extensions/known-skills.json" \
              "$CONSUMER/skills/ai-dlc/extensions/known-skills.json"; do
    [ -f "$cand" ] && { PD_EXT="$cand"; break; }
  done
fi

if [ ! -s "$TMP/sites.tsv" ]; then
  emit PREDICATE-UNDECIDABLE "predicate-sites.md" "the manifest parsed to ZERO complete sites. An empty site set produces no rows and reads exactly like a clean differential, so it is reported instead."
  exit 0
fi

while IFS="$(printf '\t')" read -r P_READS P_ENTRY P_CORPUS P_SERIES P_INVOKE P_VERDICT P_ROOT P_PASS; do
  [ -n "${P_READS:-}" ] || continue
  p_name="$(basename "$P_ENTRY")"
  case "$P_ROOT" in
    '!bad:'*)
      emit PREDICATE-UNDECIDABLE "$p_name" "the site's corpus-root: value is refused (${P_ROOT#!bad:}). It must be a directory relative to the consumer root, with no '..' component, no leading '/', and no whitespace; anything else could read outside the consumer or split this row. Nothing was compared."
      continue ;;
  esac
  # THE POPULATION DEFINITION, ON EVERY ROW THAT GOT PAST THE MANIFEST. A count a second party
  # cannot re-derive is not a measurement, and the definition is where every past disagreement
  # over these figures lived -- never in the arithmetic. One fixed spelling so one grep finds it,
  # each value backticked so a glob reaches a markdown report as code rather than as emphasis.
  # It is STATIC -- built from the manifest alone -- so `emit-report.sh` can carry it into the
  # byte-compared region without a corpus that grew between approve and verify failing the check.
  p_pop="population: root=\`${P_ROOT}\` corpus=\`${P_CORPUS}\` series=\`${P_SERIES}\`"

  # ---- MATERIALIZE THE WHOLE READ-SET PER SIDE, INTO A PROBE ROOT -------------------
  # Not the script alone. A predicate that resolves a SCHEMA at runtime moves when the schema
  # moves and the script does not -- measured at v0.382.0 (`d71d981e`), where
  # provenance-block.json changed and validate-provenance-block.sh was byte-identical on both
  # sides. Comparing scripts there returns 0 BY CONSTRUCTION, which is the failure this whole
  # detector exists to catch. The probe root preserves dist-relative paths so the incoming
  # script resolves the incoming schema by its own walk-up, exactly as it will on the consumer.
  side_missing=0; side_absent_at_base=0
  for side in base theirs; do
    [ "$side" = base ] && ref="$BASE" || ref="$THEIRS"
    rm -rf "$TMP/root-$side"; mkdir -p "$TMP/root-$side"
    set -f
    for member in $P_READS; do
      set +f
      # quotePath=false: a non-ASCII member is otherwise listed C-quoted, `git show` is handed a
      # path that names nothing, and the side reads as unmaterializable.
      for f in $(git -C "$DIST" -c core.quotePath=false ls-files --with-tree="$ref" -- "$member" 2>/dev/null); do
        mkdir -p "$TMP/root-$side/$(dirname "$f")"
        git -C "$DIST" show "${ref}:${f}" > "$TMP/root-$side/$f" 2>/dev/null || side_missing=1
      done
      set -f
    done
    set +f
    [ -f "$TMP/root-$side/$P_ENTRY" ] || { [ "$side" = base ] && side_absent_at_base=1 || side_missing=1; }
  done

  if [ "$side_absent_at_base" -eq 1 ]; then
    emit PREDICATE-STABLE "$p_name" "the predicate does not exist at ${BASE}, so this pull ADDS it. There is no prior verdict for a stored artifact to be reclassified AGAINST, and a first-time verdict is not a reclassification. ${p_pop}; nothing compared."
    continue
  fi
  if [ "$side_missing" -eq 1 ]; then
    emit PREDICATE-UNDECIDABLE "$p_name" "could not materialize the declared read-set [$P_READS] at ${THEIRS}, so the differential has no incoming side. This is not the same as the predicate being unchanged. ${p_pop}; nothing compared."
    continue
  fi

  # THE TWO SIDES MUST DIFFER, AND THE SUBJECT OF THAT TEST IS THE READ-SET. Two runs of one
  # program produce a perfect null that reads exactly like agreement -- `verification-discipline.md`,
  # "a differential must prove its two sides differ". Unchanged is a real and common answer; it
  # is just not a measured one.
  if diff -r -q "$TMP/root-base" "$TMP/root-theirs" >/dev/null 2>&1; then
    emit PREDICATE-STABLE "$p_name" "the whole declared read-set [$P_READS] is byte-identical at ${BASE} and ${THEIRS} — this pull moves neither the predicate nor any schema it reads, so no stored verdict can change. Reported rather than skipped: a null taken over two runs of the SAME program is not evidence about anything. ${p_pop}; nothing compared."
    continue
  fi

  # ---- the consumer's stored corpus --------------------------------------------------
  # READ THE LIVE TREE, and FINGERPRINT IT EITHER SIDE OF THE RUN. The discriminating
  # artifacts are the ones PREDATING the change, and a frozen or committed-only corpus
  # silently drops the in-flight ones. But a consumer's `_bmad-output/` is written by its own
  # running pipeline -- measured moving twice during a single upstream session -- so a figure
  # taken across a moving corpus is a snapshot of a file somebody else is holding open. The
  # honest handling is to take it live and refuse the answer if it moved underneath.
  #
  # THE ROOT IS THE SITE'S `corpus-root:`, consumer-relative. A predicate whose stored subject
  # lives outside `_bmad-output/` -- `docs/escalations/pending.md` -- was otherwise unreachable,
  # and its site reported UNDECIDABLE on every consumer that had the file.
  find "$CONSUMER/$P_ROOT" -type f -name "$P_CORPUS" 2>/dev/null | sort > "$TMP/records"
  fp_before="$(wc -c < "$TMP/records" | tr -d ' ')"

  if [ ! -s "$TMP/records" ]; then
    emit PREDICATE-UNDECIDABLE "$p_name" "the corpus pattern [$P_CORPUS] matched NO stored artifact under ${CONSUMER}/${P_ROOT}. A pattern that matches nothing reports zero reclassifications and reads exactly like a clean tree; those are different answers and this is the second one. ${p_pop}; records=0."
    continue
  fi

  sed -E "$P_SERIES" "$TMP/records" | sort -u > "$TMP/series"
  n_series="$(grep -c . < "$TMP/series")"

  : > "$TMP/pairs"
  n_parsed=0; n_passed=0
  while IFS= read -r s; do
    [ -n "$s" ] || continue
    rel="${s#"$CONSUMER"/}"
    # shellcheck disable=SC2086 -- P_INVOKE is a declared argument FORM, deliberately split.
    inv="$(printf '%s' "$P_INVOKE" | sed "s|{series}|$rel|")"
    # EACH SIDE IS ROOTED AT ITS OWN PROBE ROOT. A predicate that resolves a schema under its
    # project root otherwise falls through to the consumer's INSTALLED schema on both sides --
    # the cwd is the consumer, and `CLAUDE_PROJECT_DIR` or an inherited `AI_DLC_PROJECT_ROOT`
    # point there too -- so a schema-only change compares one schema with itself and reads
    # STABLE. A walk-up marker alone does not fix that: an inherited AI_DLC_PROJECT_ROOT wins
    # over the walk. Consumer data the probe root cannot hold is passed by path (PD_EXT above).
    ( cd "$CONSUMER" && AI_DLC_PROJECT_ROOT="$TMP/root-base" AI_DLC_KNOWN_SKILLS_EXT="$PD_EXT" bash "$TMP/root-base/$P_ENTRY"   $inv ) > "$TMP/out-base" 2>&1
    ( cd "$CONSUMER" && AI_DLC_PROJECT_ROOT="$TMP/root-theirs" AI_DLC_KNOWN_SKILLS_EXT="$PD_EXT" bash "$TMP/root-theirs/$P_ENTRY" $inv ) > "$TMP/out-theirs" 2>&1
    a_base="$(sed -nE "$P_VERDICT" "$TMP/out-base" | sort -u | tr '\n' ',')"
    a_theirs="$(sed -nE "$P_VERDICT" "$TMP/out-theirs" | sort -u | tr '\n' ',')"
    if [ -n "$a_base" ] || [ -n "$a_theirs" ]; then
      n_parsed=$((n_parsed + 1))
    elif [ "$P_PASS" != - ] && [ -n "$(sed -nE "$P_PASS" "$TMP/out-base")" ] && [ -n "$(sed -nE "$P_PASS" "$TMP/out-theirs")" ]; then
      n_passed=$((n_passed + 1))
    fi
    printf '%s\t%s\t%s\n' "$a_base" "$a_theirs" "$rel" >> "$TMP/pairs"
  done < "$TMP/series"

  find "$CONSUMER/$P_ROOT" -type f -name "$P_CORPUS" 2>/dev/null | sort > "$TMP/records2"
  fp_after="$(wc -c < "$TMP/records2" | tr -d ' ')"
  # THE COUNTS EVERY COMPARED ROW CARRIES. `compared` is the series yielding a verdict token on
  # at least one side. Of the rest, a site declaring `pass:` splits them: `passed` printed the
  # pass line on BOTH sides, and `unclassified` did neither -- the series this run could not
  # classify. A site with no `pass:` cannot make that split, so it prints `unclassified=n/a`
  # rather than a number that would read as one: there, a tokenless series is either a pass or
  # unparseable, and nothing in the output says which.
  n_records="$(grep -c . < "$TMP/records")" || n_records=0
  if [ "$P_PASS" = - ]; then
    p_counts="records=${n_records} series=${n_series} compared=${n_parsed} unclassified=n/a (grammar spells failures only)"
  else
    p_counts="records=${n_records} series=${n_series} compared=${n_parsed} passed=${n_passed} unclassified=$((n_series - n_parsed - n_passed))"
  fi
  if [ "$fp_before" != "$fp_after" ]; then
    emit PREDICATE-UNDECIDABLE "$p_name" "the consumer's artifact corpus CHANGED while the differential was running (${fp_before} -> ${fp_after} bytes of path list) — its own pipeline is live. Any count taken across a moving corpus is a snapshot of a file another party is holding open. Re-run against a quiescent tree. ${p_pop}; ${p_counts}."
    continue
  fi

  # A CORPUS THAT PARSED TO NOTHING CANNOT DISCRIMINATE. If the verdict grammar extracted no
  # token from EITHER side of any series, the grammar is wrong or the predicate never ran, and
  # both of those report zero reclassifications. `verification-discipline.md`: point a search
  # grammar at its own subject before trusting its zero.
  if [ "$n_parsed" -eq 0 ]; then
    emit PREDICATE-UNDECIDABLE "$p_name" "the verdict grammar extracted NO token from either side across all ${n_series} series, so nothing was compared. A grammar that cannot spell its own subject scores every series as unchanged. This is a floor of unknown depth, not a clean result. ${p_pop}; ${p_counts}."
    continue
  fi

  n_changed="$(awk -F'\t' '$1!=$2' "$TMP/pairs" | grep -c . || true)"

  if [ "$n_changed" -eq 0 ]; then
    emit PREDICATE-STABLE "$p_name" "the read-set moved and NO stored artifact changes verdict between ${BASE} and ${THEIRS}: ${n_series} series compared, ${n_parsed} of them yielding a verdict token on at least one side. THIS IS AN ENDPOINT COMPARISON AND SAYS NOTHING ABOUT THE INTERIOR of the range — a release that reclassifies and a later one in the same range that corrects it net to zero here, correctly, and that is not this detector failing. Measured: 0.441.0 -> 0.442.0 reclassifies, 0.442.0 -> 0.443.0 repairs, 0.441.0 -> 0.443.0 is silent. If you need per-release visibility, walk the release commits as \`self-update-gate.sh --safe-stop\` does. The ${n_parsed} is the discriminating subset and it is a FLOOR. ${p_pop}; ${p_counts}."
    continue
  fi

  # THE COUNT IS A FLOOR AND THE ROW SAYS SO IN ITS OWN TEXT. Artifacts written UNDER the
  # incoming predicate agree with it by construction, so they cannot discriminate; the series
  # that can are the ones predating the change, and which those are is not derivable here. A
  # detector that printed a bare count would reproduce the vacuous-clean failure one level up.
  emit PREDICATE-RECLASSIFIES "$p_name" "AT LEAST ${n_changed} of ${n_series} stored series change verdict between ${BASE} and ${THEIRS} (${n_parsed} yielded a comparable verdict at all). This is a FLOOR, not a count: a series written under the incoming predicate agrees with it by construction and cannot discriminate, and one whose verdict is unparseable on both sides is scored unchanged. Nothing in the pull's own diff is wrong — the artifacts did not move, the verdict on them did. Review the changed series before accepting this pull, and note that accepting it is a legitimate choice: this row does not block. AND THIS IS AN ENDPOINT COMPARISON: a release INSIDE the range that reclassifies and a later one that corrects it cancel here, so this count can be far smaller than the disruption any single interior release would have caused. Measured on the reference consumer: 0.441.0 -> 0.442.0 moves 48 of 119 series, while 0.438.0 -> 0.443.0 across the same corpus moves 1, because 0.443.0 repaired 0.442.0. Both are correct answers to different questions. For per-release visibility, walk the release commits as \`self-update-gate.sh --safe-stop\` does. ${p_pop}; ${p_counts}."

  awk -F'\t' '$1!=$2 {print $3"\t["$1"] -> ["$2"]"}' "$TMP/pairs" \
  | while IFS="$(printf '\t')" read -r c_path c_delta; do
      emit PREDICATE-RECLASSIFIES "$c_path" "verdict tokens $c_delta under $p_name."
    done
done < "$TMP/sites.tsv"

exit 0
