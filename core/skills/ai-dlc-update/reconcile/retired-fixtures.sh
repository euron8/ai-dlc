#!/usr/bin/env bash
# retired-fixtures.sh — flag a core fixture the consumer still carries after core
# stopped shipping it, so the operator retires the orphaned copy.
#
# WHY THIS EXISTS. `install.sh` and `apply.sh` copy a core fixture into the consumer.
# When core later marks that fixture `.dist-only` — or deletes it outright — both stop
# copying it, CORRECTLY. But the copy already installed becomes unreachable by every
# mechanism core has: nothing updates it, nothing removes it, and nothing says it is
# there. It is not drift (the consumer never edited it) and it is not a missing file
# (the consumer has one), so neither `unregistered-drift.sh` nor the apply buckets can
# see it. It simply freezes, at whatever version core last shipped, forever.
#
# MEASURED on the reference consumer at 0.232.0: `tests/fixtures/enforcement-map-sites/`
# was core's copy from 2026-07-14 — 110 lines against core's 1,782 that day — carried for
# 177 releases after core marked the fixture `.dist-only`. Its three `| grep -q` sites were
# core's own pre-sweep construct, frozen in a consumer that had long since pulled the sweep.
#
# WHAT IT DOES NOT DO. It does not delete anything and it never blocks. The file is the
# CONSUMER's; core's act is to say that it is there. This is the twin of
# `warn-shadowed-local-validators.sh`'s RETIRE-CANDIDATE and `layer-drift.sh`'s
# EXTENSION-RETIRE-CANDIDATE — a mechanical signal the OPERATOR confirms.
#
# THE PREDICATE, AND WHY IT NEEDS TWO ARMS. A consumer fixture directory is an orphan when
# core does not ship it AND core once did. "Core does not ship it" has two shapes and they
# are NOT interchangeable:
#
#   ARM A  core still HAS the directory and it carries `.dist-only`. Read from the tree at
#          THEIRS. Needs no history and therefore cannot answer a false zero.
#   ARM B  core has DELETED the directory. Only history can distinguish this from a fixture
#          the consumer wrote itself, so arm B is guarded — see the zero guard below.
#
# THE SECOND HALF OF THE PREDICATE IS WHAT KEEPS THIS OFF THE CONSUMER'S OWN FIXTURES, and
# it is the whole false-positive story. The reference consumer has 119 fixture directories;
# 90 are core's shipped set, and of the remaining 29 exactly ONE has ever existed in core's
# history. The other 28 are the consumer's own and this script is silent on every one. A
# predicate of "not in core's shipped set" alone would report all 29 — the unmeasured lint
# `CLAUDE.md` warns about, arriving as 28 false positives on the first run.
#
# Usage:  retired-fixtures.sh <dist-repo> <theirs-ref> <consumer-root>
# Output: TSV — STATUS<TAB>consumer-path<TAB>DETAIL
# Exit:   0 ALWAYS. A classifier, not a gate — the signal never blocks.
set -uo pipefail

DIST="${1:?usage: retired-fixtures.sh <dist-repo> <theirs-ref> <consumer-root>}"
THEIRS="${2:?usage: retired-fixtures.sh <dist-repo> <theirs-ref> <consumer-root>}"
CONSUMER="${3:?usage: retired-fixtures.sh <dist-repo> <theirs-ref> <consumer-root>}"

emit() { printf '%s\t%s\t%s\n' "$1" "$2" "$3"; }

# core/<path> -> consumer path. DELEGATED to preclassify.sh's map_consumer(), the single
# mapping I8 binds to install.sh, exactly as unregistered-drift.sh and apply.sh do. A
# private copy here would be a second home for the same list, and this repo has already
# paid for that twice — `unregistered-drift.sh`'s own header records its copy going wrong.
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
eval "$(awk '/^map_consumer\(\) \{/,/^\}/' "$SELF/preclassify.sh" 2>/dev/null)"
if ! command -v map_consumer >/dev/null 2>&1; then
  emit HARD-RETIRED-FIXTURE-SCAN-UNAVAILABLE "-" \
    "could not load map_consumer() from preclassify.sh — nothing was scanned. Refusing to fall back to a private path table: it would answer for one layout, be silently wrong in the other, and print an empty result that reads as no orphans."
  exit 0
fi

# The consumer's fixture root, DERIVED from the mapper rather than written here. Asking the
# mapper for a known core fixture path and taking its directory is what keeps this file out
# of the two-layouts trap: `install.sh` splits what shares a parent in `core/`, and I33
# fails the build on anything that walks up from one core file to find another.
fx_rel="$(map_consumer "core/fixtures/__probe__/run.sh")"
fx_root="${fx_rel%/__probe__/run.sh}"
if [ "$fx_root" = "$fx_rel" ] || [ -z "$fx_root" ]; then
  emit HARD-RETIRED-FIXTURE-SCAN-UNAVAILABLE "-" \
    "map_consumer() did not map a core fixture path to a consumer fixture path, so the consumer's fixture root could not be derived and nothing was scanned. The mapper's core/fixtures/* arm has moved or been removed."
  exit 0
fi
[ -d "${CONSUMER}/${fx_root}" ] || exit 0   # a consumer with no fixtures cannot hold an orphan

# --- ARM A: core still has it, marked `.dist-only` -----------------------------
# Read from the tree at THEIRS, so a fixture retired IN THIS PULL is reported by this pull.
# The marker set is DERIVED — it is 7 today and it moves every release, and a hand-list here
# would be the fourth restatement this program has had to unpick.
git -C "$DIST" ls-tree -r --name-only "$THEIRS" -- core/fixtures 2>/dev/null \
  | grep '/\.dist-only$' \
  | while IFS= read -r marker; do
      n="${marker#core/fixtures/}"; n="${n%/.dist-only}"
      [ -n "$n" ] || continue
      cons_rel="$(map_consumer "core/fixtures/${n}/run.sh")"; cons_rel="${cons_rel%/run.sh}"
      [ -d "${CONSUMER}/${cons_rel}" ] || continue
      emit RETIRED-FIXTURE-ORPHAN "$cons_rel" \
        "core marked this fixture .dist-only, so neither install nor apply ships it any more — but your copy was installed before that and nothing has updated it since. It is frozen at whatever core last shipped and no longer matches the mechanism it tests. Core cannot remove it: the file is yours. Retire it: rm -rf <consumer>/${cons_rel}. If you have edited it into a fixture of your own, rename the directory so it stops shadowing a core name."
    done

# --- ARM B: core deleted it outright -------------------------------------------
# THE ZERO GUARD, AND IT IS THE REASON THIS ARM IS SEPARATE. Arm B's question is "did core
# EVER have this directory", which only history answers. A shallow or partial clone answers
# EMPTY for every candidate, so the arm would report zero orphans on a tree full of them —
# a check that cannot fire reads exactly like one that passed, which is this repo's named
# defect. So the arm refuses to answer rather than answering wrongly, and it says so LOUDLY.
#
# THE GUARD ASKS GIT FOR A PROPERTY, NOT FOR A LOG, AND THE FIRST CUT OF IT DID THE
# OPPOSITE. It probed `log --all -- core/fixtures` on the reasoning that the directory has
# been in this repo's history for its whole life, so an empty answer means the history is
# gone. Measured: on a `--depth 1` clone that probe returns ONE commit — the tip still
# touches core/fixtures — while the question arm B actually asks, `log -- core/fixtures/<n>`
# for a directory deleted before the tip, returns ZERO. So the guard passed and the arm
# false-zeroed underneath it. **A control that survives the truncation it is testing for
# proves the command ran, not that the answer is available** — F-2.1's lesson, reproduced
# here and caught by this arm's own fixture skipping rather than passing.
#
# `--is-shallow-repository` is the property itself. The log probe is kept as a second
# condition because a partial (filtered) clone is not flagged shallow and can still answer
# empty.
dist_shallow="$(git -C "$DIST" rev-parse --is-shallow-repository 2>/dev/null)"
if [ "$dist_shallow" = "true" ] || [ -z "$(git -C "$DIST" log --all --format=%H -1 -- core/fixtures 2>/dev/null)" ]; then
  emit RETIRED-FIXTURE-HISTORY-UNAVAILABLE "-" \
    "this distribution clone is shallow or carries no history for core/fixtures, so a fixture core DELETED cannot be told apart from one you wrote yourself, and arm B did not run. Arm A (fixtures core marked .dist-only) needs no history, is unaffected, and its result above stands. Re-run from a full clone to complete the scan."
else
  for d in "${CONSUMER}/${fx_root}"/*/; do
    [ -d "$d" ] || continue
    n="$(basename "$d")"
    # Still shipped, or dist-only? Arm A owns it either way. NOT `ls-tree … | grep -q`:
    # this file enables pipefail, so the reader's early exit would answer with the writer's
    # EPIPE on a large enough tree. I54b bans exactly that and v0.231.0 swept 22 of them.
    core_has="$(git -C "$DIST" ls-tree -d --name-only "$THEIRS" -- "core/fixtures/${n}" 2>/dev/null)"
    [ -n "$core_has" ] && continue
    # Core does not have it at THEIRS. Did it ever?
    [ -n "$(git -C "$DIST" log --all --format=%H -1 -- "core/fixtures/${n}" 2>/dev/null)" ] || continue
    last="$(git -C "$DIST" log --all --format='%h (%ad)' --date=short -1 -- "core/fixtures/${n}" 2>/dev/null)"
    emit RETIRED-FIXTURE-ORPHAN "${fx_root}/${n}" \
      "core DELETED this fixture — it was last in core's tree at ${last} and is not at ${THEIRS} — but your copy is still here and nothing removed it. Core cannot: the file is yours. Retire it: rm -rf <consumer>/${fx_root}/${n}. If you have adopted it as a fixture of your own, rename the directory so it stops shadowing a core name."
  done
fi

exit 0   # classifier — the signal never blocks
