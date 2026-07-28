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
#   retired-tokens.sh     <dist> <base> <theirs> <consumer> [path]  STATUS<TAB>path<TAB>token
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
  # SINGLE-quoted: a backslash before a backtick is NOT an escape here, it is a literal
  # backslash, and this region is specified to be pasted VERBATIM into a markdown report —
  # where `\`` renders as an escaped backtick, so the one line naming the two shas showed
  # them wrapped in literal backslashes instead of as inline code. `--verify` byte-matches
  # the region against a fresh render, so a consumer who wrote correct markdown got a FAIL
  # and was pushed back to the malformed text.
  printf '\n_base_ `%s` → _theirs_ `%s`.\n' "$BASE" "$THEIRS"

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

          # ---- RETIRED CONTRACT TOKENS -----------------------------------------
          # The one class of merge defect the sample above CANNOT surface: upstream
          # retires a shared contract and the consumer's own code inside the same file
          # still speaks the old one. diff3 merges it cleanly and the result is a gate
          # that cannot fire. retired-tokens.sh owns the derivation and the rationale;
          # this only renders it. UNCAPPED on purpose -- the signal was already inside
          # "ONLY IN OURS" above on the pull that motivated it, buried at "137
          # suppressed", and the cap is what hid it.
          rt="$(bash "$SELF/retired-tokens.sh" "$DIST" "$BASE" "$THEIRS" "$CONSUMER" "$cp" 2>/dev/null \
                | awk -F'\t' '{print $3}')"
          if [ -n "$rt" ]; then
            echo "    RETIRED-CONTRACT-TOKEN — OURS still references what THEIRS eliminated (uncapped; resolve EVERY one):"
            printf '%s\n' "$rt" | sed 's/^/      /'
            echo "      Each is a live reference in the consumer's own code to a contract upstream"
            echo "      retired. The merge will carry it and stay syntactically valid. Find what"
            echo "      THEIRS replaced it with and re-point OURS at that, or state why it is safe."
          else
            echo "    RETIRED-CONTRACT-TOKEN: none"
          fi
        fi
      done
  fi

  sub "Deletions (apply would git rm a consumer file — gated per-path):"
  del="$(printf '%s\n' "$pc" | awk -F'\t' '$4=="UPSTREAM-DELETED" || $4 ~ /^ORPHANED-RELOCATED/ {print $4"  "$2}' | sort -u)"
  none_or "$del"

  # Rendered mechanically, inside the --verify'd region, precisely because the failure
  # this closes was a narrated report asserting OURS==BASE for all 25 validators against
  # a comparison that never ran. A +consumer-edited row means apply will overwrite a
  # locally adapted enforcer on the move; the operator confirms it was filed as a push
  # candidate first. Author prose cannot drop what the byte-compare requires to be here.
  sub "Scripts relocation (scripts/ → scripts/ai-dlc/; +consumer-edited = a local adaptation apply will discard — confirm the push-candidate ledger before apply):"
  reloc="$(printf '%s\n' "$pc" | awk -F'\t' '$4 ~ /^RELOCATE-MOVE/ {print $4"  "$2}' | sort -u)"
  none_or "$reloc"

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

  # THE ROW MUST SAY WHY. This projected fields 1 and 2 and dropped field 3 — and field 3 is the
  # only place a NEEDS-REVIEW row names its cause (`unresolved:` / `vacuous predicate:` /
  # `unfalsifiable predicate:`). The report is the artifact the operator reads before approving
  # apply; a row there that says NEEDS-REVIEW and nothing else is a pointer to a tool they must
  # re-run to learn anything, which is how a rendered worklist becomes a table of contents.
  #
  # HAND-REVIEW is exempt: its detail is one constant sentence, so carrying it repeats the same
  # line once per manual entry — nine times on the reference consumer — and says nothing the
  # status has not already said.
  sub "Push-candidate ledger — CLOSE-CANDIDATE / NAMED-UPSTREAM / NEEDS-REVIEW (upstream absorbed the entry; the operator confirms and annotates, never auto-closed):"
  local lr
  lr="$(bash "$SELF/ledger-reverify.sh" "$DIST" "$BASE" "$CONSUMER" "$THEIRS" 2>/dev/null | awk -F'\t' '$1!="STILL-LIVE"{ d = ($1=="HAND-REVIEW") ? "" : "  "$3; print $1"  "$2 d }' | sort -u)"
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
# The rendered region carries ONE machine-specific value: the absolute distribution path in
# each `full: diff <(git -C <dist> show …)` reproduction command. The path is deliberately
# concrete there — a command the operator must edit before running is a path out they cannot
# walk — but it makes the region unequal across checkouts, and `--verify` byte-compares.
#
# Consequence, measured: a consumer generated a report from a scratch clone under /private/tmp;
# verifying the SAME report from a normal checkout failed with "STALE or HAND-EDITED" on nothing
# but that path. That is a false accusation, and it sends the operator to regenerate a sound
# report. It also defeats the reason `--verify` is offered to operators at all — SKILL.md step 5
# says they "can run the same --verify to trust any report without re-running the detectors by
# hand", and before this they could only trust reports generated at their own dist path.
#
# So the dist path is normalized out of BOTH sides before comparing. Anchored on ` show
# <theirs>:` rather than a bare `[^ ]*`, so a checkout path containing spaces still normalizes.
# Nothing else is normalized: this is the one field whose value is a property of WHERE the
# detectors ran rather than WHAT they found, and a hand-edit anywhere else still fails.
norm_dist() { sed -E "s|git -C .* show ${THEIRS}:|git -C <dist> show ${THEIRS}:|g"; }
want="$(render | norm_dist)"
got="$(awk '/BEGIN GENERATED: reconcile-mechanical/{f=1} f{print} /END GENERATED: reconcile-mechanical/{f=0}' "$REPORT" | norm_dist)"
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
