#!/usr/bin/env bash
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
# (preclassify, unregistered-drift, layer-drift, hard-blockers, relabel) and RENDERS them into one
# `BEGIN/END GENERATED: reconcile-mechanical` region, deterministically. The skill pastes that
# region VERBATIM and writes only the genuinely semantic sections (the per-file 3-way prose merge
# results, the operator questions) AROUND it. `--verify` re-renders and byte-compares — so a report
# whose mechanical region drifted from the tools, or that never had one, FAILS. The operator can
# run `--verify` themselves: one command, and they know whether a report is sound, instead of
# re-running detectors by hand. The residual LLM work (prose merges) is irreducibly semantic; the
# mechanical findings are now un-droppable.
#
# The four detectors take args in DIFFERENT orders (a pre-existing quirk); this wraps them:
#   preclassify.sh        <dist> <base> <theirs> <consumer>   KIND<TAB>path<TAB>cons<TAB>bucket
#   unregistered-drift.sh <dist> <base> <consumer> <theirs>   STATUS<TAB>file<TAB>detail
#   layer-drift.sh        <dist> <base> <theirs> <consumer>   STATUS<TAB>entry<TAB>tgt<TAB>detail
#   hard-blockers.sh      <dist> <base> <consumer> <theirs>   (its own wrapper, stripped here)
#   relabel-…             <consumer> --dist <dist> --theirs <theirs>
#   ledger-reverify.sh    <dist> <base> <consumer> <theirs>   STATUS<TAB>entry<TAB>detail
#
# Usage:
#   emit-report.sh <dist> <base> <consumer> <theirs>                 # print the mechanical region
#   emit-report.sh --verify <report.md> <dist> <base> <consumer> <theirs>
# Exit:
#   print  : 0 always.
#   verify : 0 = region present and current; 1 = missing / stale / hand-edited; 2 = usage.
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

sub() { printf '\n**%s**\n' "$1"; }
none_or() { if [ -n "$1" ]; then printf '%s\n' "$1"; else echo "none"; fi; }

render() {
  echo "<!-- BEGIN GENERATED: reconcile-mechanical — rendered by reconcile/emit-report.sh; do not hand-edit -->"
  printf '\n_base_ \`%s\` → _theirs_ \`%s\`.\n' "$BASE" "$THEIRS"

  local pc ud ld hb rl del classify
  pc="$(bash "$SELF/preclassify.sh" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" 2>/dev/null || true)"

  sub "Per-file buckets (STATUS  path):"
  none_or "$(printf '%s\n' "$pc" | awk -F'\t' 'NF>=4 && $2!="" {print $4"  "$2}' | sort -u)"

  sub "Semantic worklist — files needing a 3-way merge (the LLM fills their result in the slot below, one per file):"
  classify="$(printf '%s\n' "$pc" | awk -F'\t' 'NF>=4 && $4 ~ /CLASSIFY/ {print $2}' | sort -u)"
  none_or "$classify"

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
    sub "Semantic worklist orientation — OURS = consumer, THEIRS = upstream at theirs. Every ours/theirs claim in the resolution prose MUST be derived from this block, never from recall:"
    printf '%s\n' "$pc" | awk -F'\t' 'NF>=4 && $4 ~ /CLASSIFY/ {print $2"\t"$3}' | sort -u \
    | while IFS="$(printf '\t')" read -r cp cons; do
        [ -n "${cp:-}" ] || continue
        local_ours="$CONSUMER/$cons"
        echo
        echo "  $cp"
        # `diff THEIRS OURS`: '<' lines are THEIRS, '>' lines are OURS. Stated because getting
        # this backwards is precisely the defect, and the fixture asserts the direction.
        t="$(git -C "$DIST" show "${THEIRS}:${cp}" 2>/dev/null)"
        if [ -z "$t" ]; then
          echo "    THEIRS absent at ${THEIRS} — nothing upstream to compare"
        elif [ ! -f "$local_ours" ]; then
          echo "    OURS absent at ${cons} — nothing consumer-side to compare"
        else
          echo "    OURS   $cons ($(wc -l < "$local_ours" | tr -d ' ') lines)"
          echo "    THEIRS ${THEIRS}:${cp} ($(printf '%s\n' "$t" | wc -l | tr -d ' ') lines)"
          d="$(diff <(printf '%s\n' "$t") "$local_ours" 2>/dev/null || true)"
          for side in THEIRS OURS; do
            case "$side" in
              THEIRS) marker='^< ' ;;
              OURS)   marker='^> ' ;;
            esac
            lines="$(printf '%s\n' "$d" | grep -E "$marker" | sed -E 's/^[<>] //' | grep -vE '^[[:space:]]*$' || true)"
            n="$(printf '%s\n' "$lines" | grep -c . || true)"
            # CAP=12, not 6. At 6 the sample was all boilerplate: on the pull that motivated
            # this block, both sides' first rows were table headers and the same four generic
            # class names, while the lines that actually decided the resolution -- the
            # consumer's two domain classes, upstream's two process classes -- sat in the
            # suppressed tail. A sample that shows only what the two sides have in COMMON
            # orients nobody. 12 covers that case whole; anything larger is read by command.
            if [ "${n:-0}" -eq 0 ]; then
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
          # The escape hatch, printed for EVERY file so a truncated sample is never the only
          # thing available. Same argument order as above: theirs on the left, ours on the
          # right, so '<' stays THEIRS and '>' stays OURS in the operator's own terminal too.
          echo "      full: diff <(git -C $DIST show ${THEIRS}:${cp}) $CONSUMER/$cons   # '<' THEIRS, '>' OURS"
        fi
      done
  fi

  sub "Deletions (apply would git rm a consumer file — gated per-path):"
  del="$(printf '%s\n' "$pc" | awk -F'\t' '$4=="UPSTREAM-DELETED" || $4 ~ /^ORPHANED-RELOCATED/ {print $4"  "$2}' | sort -u)"
  none_or "$del"

  sub "Blocking-layer (HARD-* — blocks apply):"
  bash "$SELF/hard-blockers.sh" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null \
    | sed '/BEGIN GENERATED: hard-blockers/d;/END GENERATED: hard-blockers/d'

  sub "Unregistered core drift (consumer in-place edits vs base):"
  ud="$(bash "$SELF/unregistered-drift.sh" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null | awk -F'\t' '$1!="CORE-OK"{print $1"  "$2}' | sort -u)"
  none_or "$ud"

  sub "Layer drift (overrides/extensions vs new core):"
  ld="$(bash "$SELF/layer-drift.sh" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" 2>/dev/null | awk -F'\t' '$1!="EXTENSION-OK"{print $1"  "$2}' | sort -u)"
  none_or "$ld"

  sub "Catalog relabel (extension check-number collisions, incl. NEW-THIS-PULL from theirs):"
  # `#{2,4}`, not a literal `### `: relabel matches headings at h2-h4, so filtering the
  # report to h3 dropped a real proposed relabel out of the operator-facing summary
  # while the tool itself reported it. The filter must be as wide as the tool.
  rl="$(bash "$SELF/relabel-extension-checks.sh" "$CONSUMER" --dist "$DIST" --theirs "$THEIRS" 2>/dev/null | grep -E '^[[:space:]]+\+[[:space:]]+#{2,4} ' | sed 's/^[[:space:]]*+[[:space:]]*/  /' | sort -u || true)"
  none_or "$rl"

  sub "Push-candidate ledger — CLOSE-CANDIDATE / NEEDS-REVIEW (upstream absorbed the entry; the operator confirms and annotates, never auto-closed):"
  local lr
  lr="$(bash "$SELF/ledger-reverify.sh" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null | awk -F'\t' '$1!="STILL-LIVE"{print $1"  "$2}' | sort -u)"
  none_or "$lr"

  echo
  echo "<!-- END GENERATED: reconcile-mechanical -->"
}

if [ "$MODE" = "print" ]; then
  render
  exit 0
fi

# --- verify ---
[ -f "$REPORT" ] || { echo "emit-report: report not found: $REPORT" >&2; exit 2; }
want="$(render)"
got="$(awk '/BEGIN GENERATED: reconcile-mechanical/{f=1} f{print} /END GENERATED: reconcile-mechanical/{f=0}' "$REPORT")"
if [ -z "$got" ]; then
  echo "FAIL: the report has no 'reconcile-mechanical' GENERATED region. The mechanical sections" >&2
  echo "  (buckets, deletions, blocking-layer, drift, relabel) must be RENDERED by emit-report.sh," >&2
  echo "  not composed — or a finding can be silently dropped. Emit it and re-write the report." >&2
  exit 1
fi
if [ "$want" = "$got" ]; then
  echo "emit-report: the report's mechanical region is present, current, and complete."
  exit 0
fi
echo "FAIL: the report's 'reconcile-mechanical' region is STALE or HAND-EDITED — it does not match" >&2
echo "  what the detectors render now. Re-render with emit-report.sh and re-emit the report." >&2
echo "  Diff (want vs report):" >&2
diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") >&2 || true
exit 1
