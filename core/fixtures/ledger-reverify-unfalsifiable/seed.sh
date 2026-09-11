#!/usr/bin/env bash
# ledger-reverify-unfalsifiable/seed.sh — a synthetic dist + consumer carrying TWO
# `theirs_lacks` entries whose substrings are absent at BOTH base and theirs.
#
# That is the state two refs cannot decide: it is the normal state of a live push
# candidate AND the state of a predicate no adoption will ever satisfy. The two entries
# differ in exactly ONE variable — whether the substring exists in the consumer's own
# implementation — so any verdict difference between them is attributable to that and
# nothing else.
#
#   PC-GOOD  anchors on `--strict-provenance`, a flag the consumer really implements.
#            A fix upstream cannot be written without naming it. Must stay STILL-LIVE.
#   PC-BAD   anchors on "strict provenance enforced by default", prose invented to
#            describe the fix. Exists nowhere and never will. Must be NEEDS-REVIEW.
#
# Self-contained: builds its own dist repo rather than pinning shas from the real
# history, so the fixture cannot rot when upstream moves. Idempotent.
set -uo pipefail

WORK="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }

HERE="$(cd "$(dirname "$0")" && pwd)"
# Walk UP for the marker rather than counting `..` hops — the fixture must resolve from
# either layout (dist `core/`, consumer `.claude/`) and from any depth.
RV=""
d="$HERE"
while [ "$d" != "/" ]; do
  for cand in "$d/core/skills/ai-dlc-update/reconcile/ledger-reverify.sh" \
              "$d/.claude/skills/ai-dlc-update/reconcile/ledger-reverify.sh"; do
    [ -f "$cand" ] && { RV="$cand"; break 2; }
  done
  d="$(dirname "$d")"
done
[ -n "$RV" ] || { echo "FIXTURE ERROR: ledger-reverify.sh not found in either layout" >&2; exit 2; }

g() { git -C "$1" -c user.email=f@f -c user.name=f -c commit.gpgsign=false "${@:2}"; }

# --- synthetic distribution: base and theirs, neither carrying either substring -------
mkdir -p "$WORK/dist/core/scripts"
cd "$WORK/dist" || exit 2
git init -q .
printf '0.1.0\n' > VERSION
cat > core/scripts/validate-thing.sh <<'EOS'
#!/bin/bash
# upstream's version: no strict mode of any kind
run_thing() { :; }
EOS
# A file LARGER than the pipe buffer (~64 KB), carrying its needle at the very top. Any
# match test that pipes into `grep -q` under `set -o pipefail` reports this as NOT FOUND:
# grep exits on the first line, the writer takes SIGPIPE, and the pipeline's status becomes
# that failure. Under 64 KB the write completes first and the same code is correct, which is
# why the defect presents as flakiness rather than a size threshold. run.sh pins the verdict
# across repeated runs.
{
  printf 'NEEDLE_AT_TOP_OF_A_LARGE_FILE\n'
  i=0; while [ "$i" -lt 3000 ]; do
    printf 'padding line %s ---------------------------------------------------------\n' "$i"
    i=$((i + 1))
  done
} > core/scripts/big-rule-file.md
# The both-refs subject exists AT BASE carrying the variant already — that is the whole point
# of the case, and seeding it only at theirs would make it indistinguishable from the ordinary
# near-miss. See its second write below.
cat > core/scripts/both-refs-subject.sh <<'EOS'
#!/bin/bash
# present at BASE already: a variant here proves nothing about upstream movement
carry_bothrefs_flag() { :; }
EOS
# The bare-swap subject ALSO exists at base, carrying the COMPOSED variant, which is what
# disqualifies that generator and leaves the bare swap as the only one that can close. Without
# this base state the composed variant would reach the fix too and the seed would isolate nothing.
cat > core/scripts/bare-swap-subject.sh <<'EOS'
#!/bin/bash
# the composed variant is present at BASE, so only the bare swap can close
bare-swap-flag() { :; }
EOS
g "$WORK/dist" add -A; g "$WORK/dist" commit -qm base
BASE="$(git -C "$WORK/dist" rev-parse HEAD)"
printf '0.2.0\n' > VERSION
cat >> core/scripts/validate-thing.sh <<'EOS'
# theirs moved, but still has no strict mode
EOS
# THE NEAR-MISS SUBJECT, AND IT IS A SEPARATE FILE ON PURPOSE. Upstream introduces
# `near-miss-flag:` (HYPHEN) between base and theirs; the ledger's receipt anchors on
# `near_miss_flag:` (UNDERSCORE). Sharing `validate-thing.sh` with PC-GOOD/PC-BAD would let a
# guard that mis-resolves the path reach the right bytes for the wrong entry, and two guards
# covering one subject report zero failures.
cat > core/scripts/near-miss-subject.sh <<'EOS'
#!/bin/bash
# theirs introduces the fix, spelled with hyphens
emit_header() { printf '# near-miss-flag: %s\n' "$1"; }
# The multi-substring world's bait, and it is the WHOLE QUOTED RUN swapped, because that is what
# `$sub` holds for a two-substring predicate. An implementation without the skip builds its
# variant from this run and reports a two-token guess as the spelling that closes. Present only
# at theirs, so the skip is the only thing standing between it and a mis-anchored row.
# multi-alpha-x" "multi-beta-y
EOS
# THE COLON-STRIP SUBJECT. The hyphen/underscore seed above cannot separate an arm that
# implements BOTH transforms from one that implements only the swap: its closing spelling
# differs from the anchor in a separator, so a swap-only arm finds it. Here the anchor and
# the closing spelling differ ONLY by a trailing colon, so an arm that never strips the colon
# reports STILL-LIVE and the near-miss goes unreported. A receipt with one transform's seed
# accepts an implementation carrying half the transform set.
cat > core/scripts/colon-strip-subject.sh <<'EOS'
#!/bin/bash
# theirs introduces the fix; the anchor differs from it only by a trailing colon
emit_flag() { printf '%s\n' "colonstripflag value"; }
EOS
# THE COMPOSED-VARIANT SUBJECT, AND IT IS THE ARM'S OWN MOTIVATING SPELLING. `anchor_variants`
# emits THREE generators — the swap, the colon strip, and their COMPOSITION — and the two seeds
# above each have their closing spelling reachable by TWO of the three, so neither can isolate a
# member. Measured: dropping the composed variant leaves the whole fixture PASSING with a
# byte-identical ok-set.
#
# That is not a hypothetical gap. On the real case this release was cut for — anchor
# `skill_commit:`, fix `skill-commit` — the swap gives `skill-commit:` (0 at theirs), the strip
# gives `skill_commit` (present at BASE, so disqualified), and ONLY the composition `skill-commit`
# reaches. A build without it reports `unfalsifiable` on the exact case the arm exists for.
# Here the anchor carries both a separator to swap and a colon to strip, and only doing BOTH finds
# the fix.
cat > core/scripts/composed-variant-subject.sh <<'EOS'
#!/bin/bash
# theirs introduces the fix: hyphen AND no trailing colon. Neither transform alone reaches it.
emit_combo() { printf '%s\n' "combo-flag is the shipped spelling"; }
EOS
# THE BARE-SWAP SUBJECT, the mirror. An implementation dropping the SWAP but keeping the strip
# and the composition also survives everything above. It needs a world where the composed variant
# is DISQUALIFIED — present at base — while the bare swap is the one that closes.
cat >> core/scripts/bare-swap-subject.sh <<'EOS'
# theirs adds the COLON-BEARING swap, which only the bare-swap generator produces
emit_bare() { printf '%s\n' "bare-swap-flag: value"; }
EOS
# THE BOTH-REFS SUBJECT — the FALSE-ACCUSATION direction, which no seed above can reach.
# The variant is present at theirs AND at base, so upstream did NOT move under it and the
# receipt is not mis-anchored. An arm that tests the variant at theirs only, dropping the
# `absent at base` conjunct, accuses a healthy receipt. Every other seed here has its variant
# absent at base, so none of them can tell the two implementations apart.
cat > core/scripts/both-refs-subject.sh <<'EOS'
#!/bin/bash
# present at BASE already: a variant here proves nothing about upstream movement
carry_bothrefs_flag() { :; }
EOS
g "$WORK/dist" add -A; g "$WORK/dist" commit -qm theirs
THEIRS="$(git -C "$WORK/dist" rev-parse HEAD)"

# --- synthetic consumer: implements the innovation PC-GOOD anchors on -----------------
mkdir -p "$WORK/consumer/_bmad-output/ai-dlc-update" "$WORK/consumer/scripts" "$WORK/consumer/notes"
cat > "$WORK/consumer/scripts/thing.sh" <<'EOS'
#!/bin/bash
# the local hardening this consumer built and wants upstreamed
case "${1:-}" in --strict-provenance) STRICT=1 ;; esac
EOS
# A file that SURVIVES run.sh's mutation. Without it, removing the anchor also empties the
# scan set, the undecidable path fires, and the mutation would "pass" for the wrong reason.
cat > "$WORK/consumer/scripts/keep.sh" <<'EOS'
#!/bin/bash
echo "unrelated; keeps the scan set non-empty under mutation"
EOS
# --- subjects for the `verify: sh` arm's unfalsifiability guard ------------------------
# The consumer's copy sits at BASE, which is the ordinary state and the one that makes a
# negated grep exit 0 (= still reproduces) while the token exists upstream at THEIRS.
# map_consumer() sends core/scripts/<x> to scripts/ai-dlc/<x>, so THAT is where a receipt
# naming this subject has to point; a copy under plain scripts/ maps to nothing and would
# make every arm below undecidable rather than testing anything.
mkdir -p "$WORK/consumer/scripts/ai-dlc"
git -C "$WORK/dist" show "${BASE}:core/scripts/validate-thing.sh" \
  > "$WORK/consumer/scripts/ai-dlc/validate-thing.sh"
# A SECOND, INDEPENDENT subject. Without it the watchdog arm and the alternation arm would
# share one file, and a guard that mis-reads either would be covered by the other reaching
# the same bytes — two guards covering each other report ZERO failures, which is
# indistinguishable from two that never fired.
cat > "$WORK/consumer/scripts/ai-dlc/retired-marker.sh" <<'EOS'
#!/bin/bash
# the replacement token a STAYS-RETIRED watchdog asserts is present
use_new_anchor() { :; }
EOS
# THE MASK. This is what made the near-miss case invisible rather than merely unreported:
# the misspelled anchor is REACHABLE in the consumer's own tracked tree through unrelated
# prose, so `consumer_reachable` returns 0 and the unfalsifiability guard cannot fire. The
# row is then a DECIDED STILL-LIVE. Without this file the near-miss entry would be caught by
# the OLD guard and the new arm would be scoring a case that was already handled — the seed
# would prove nothing. Measured on the reference consumer: 80 tracked files carried the
# underscore spelling against 0 for an impossible token.
cat > "$WORK/consumer/notes/unrelated-prose.md" <<'EOS'
# design notes

An earlier draft called this field `near_miss_flag:` before the spelling was settled.
Nothing reads this file; it exists so the token is reachable in the tracked tree.
EOS
cat > "$WORK/consumer/_bmad-output/ai-dlc-update/push-candidate-ledger.md" <<'EOM'
## PC-GOOD — anchored on a flag the fix cannot be written without

The consumer runs a strict provenance mode upstream lacks.

verify: theirs_lacks core/scripts/validate-thing.sh "--strict-provenance"

---

## PC-BAD — anchored on prose describing the wanted fix

Upstream should enforce provenance strictly by default.

verify: theirs_lacks core/scripts/validate-thing.sh "strict provenance enforced by default"

---

## PC-NEARMISS — the anchor is one character off the token the fix shipped

THE OFFENDER. Upstream really did move: `near-miss-flag:` is absent at base and present at
theirs. This receipt anchors on `near_miss_flag:` — underscore — which is absent at BOTH, so
the two refs alone say "still live". The old guard cannot catch it either, because the
misspelled token IS reachable in this consumer's own tracked tree (notes/unrelated-prose.md),
so `consumer_reachable` returns 0 and the row is DECIDED. Must be NEEDS-REVIEW naming the
hyphen spelling.

verify: theirs_lacks core/scripts/near-miss-subject.sh "near_miss_flag:"

---

## PC-NOMISS — absent at both, and NO variant of it closes either

THE NEAR-MISS SEED, one property apart from PC-NEARMISS: same subject, same shape, absent at
both refs, unreachable in the consumer — but neither the hyphen swap nor the colon strip finds
anything at theirs, so there is no misspelling to report. It must fall through to the EXISTING
unfalsifiable arm and not be claimed by the new one. Without this, an arm that reported
mis-anchored on every absent-at-both anchor would pass every other assertion here.

verify: theirs_lacks core/scripts/near-miss-subject.sh "ZZQQ_NO_SUCH_TOKEN:"

---

## PC-COLONSTRIP — the closing spelling differs from the anchor ONLY by a trailing colon

SEPARATES BOTH TRANSFORMS FROM THE SWAP ALONE. `PC-NEARMISS` above differs by a separator, so a
swap-only implementation finds its closing spelling and passes. Here the anchor carries a trailing
colon the fix does not, and nothing but the colon strip reaches it. Must be NEEDS-REVIEW naming
`colonstripflag`.

verify: theirs_lacks core/scripts/colon-strip-subject.sh "colonstripflag:"

---

## PC-COMBO — only the COMPOSED variant reaches the fix, and it is the real case's shape

ISOLATES THE THIRD GENERATOR. `combo_flag:` swaps to `combo-flag:` (absent at theirs) and strips
to `combo_flag` (absent at theirs); only swap-THEN-strip gives `combo-flag`, which theirs carries.
This is the shape of the release's own motivating case — anchor `skill_commit:`, fix
`skill-commit` — where the swap alone is absent at theirs and the strip alone is disqualified at
base. An implementation without the composition reports `unfalsifiable` here and passes everything
else. Must be NEEDS-REVIEW naming `combo-flag`.

verify: theirs_lacks core/scripts/composed-variant-subject.sh "combo_flag:"

---

## PC-BARESWAP — the composed variant is DISQUALIFIED at base, so only the bare swap closes

ISOLATES THE FIRST GENERATOR, and it is the mirror of PC-COMBO. `bare_swap_flag:` swaps to
`bare-swap-flag:` — absent at base, present at theirs, so it closes. The composed variant
`bare-swap-flag` is present at BASE, which disqualifies it. An implementation that drops the bare
swap and keeps the strip and the composition reports `unfalsifiable` here while passing every
other world. Must be NEEDS-REVIEW naming `bare-swap-flag:`.

verify: theirs_lacks core/scripts/bare-swap-subject.sh "bare_swap_flag:"

---

## PC-BOTHREFS — the variant is present at theirs AND at base, so upstream did not move

THE FALSE-ACCUSATION DIRECTION, and no other seed here can reach it. Every other near-miss world
has its variant absent at base, so an arm that tests only "present at theirs" and drops the
"absent at base" conjunct passes all of them. It fails here, because `carry_bothrefs_flag` is at
BOTH refs: the receipt is not mis-anchored and accusing it would be a false finding about a
healthy entry. Must NOT be claimed by the near-miss arm.

verify: theirs_lacks core/scripts/both-refs-subject.sh "carry-bothrefs-flag"

---

## PC-MULTISUB — two substrings, so which one was misspelled is not derivable

THE MULTI-SUBSTRING SKIP'S ONLY SUBJECT. `all_present` requires EVERY substring, so `$sub` here is
the whole quoted run and a variant of it is a two-token guess naming something no fix ever wrote.
An implementation with the skip removed emits a `mis-anchored` row quoting that guess. Nothing else
in this fixture carries a multi-substring predicate, so without this world the skip is unprovable
and its removal is a silent widening.

verify: theirs_lacks core/scripts/near-miss-subject.sh "multi_alpha_x" "multi_beta_y"

---

## PC-BIG — a defect in a file larger than the pipe buffer

Upstream still carries the marker, in a file over 64 KB.

verify: theirs_has core/scripts/big-rule-file.md "NEEDLE_AT_TOP_OF_A_LARGE_FILE"

---

## PC-SH-UPSTREAM — bucket 1: the receipt consults THEIRS, so a pull can settle it

Reads the upstream blob directly, which is what the falsifiable shape looks like.

verify: sh cd "$CONSUMER" && ! grep -qF ZZ_NEVER_EXISTS <<<"$(git -C "$DIST" show "${THEIRS}:core/scripts/validate-thing.sh")"

---

## PC-SH-INSTALLED — bucket 3: consumer-side only, but upstream SHIPS this subject

THE DEFECT, and the shape the reference consumer actually hit. The predicate never mentions
`$THEIRS` or `$DIST`, so it reads the consumer's INSTALLED copy — frozen at base until an
apply — while `core/scripts/validate-thing.sh` exists upstream and is where the fix lands.
The verdict can therefore never change, whatever tokens it keys on. Its token is deliberately
one that no fix would ever introduce, to make the point that TOKEN CHOICE IS NOT THE DEFECT:
a perfectly-anchored version of this same receipt is equally permanently green.

verify: sh cd "$CONSUMER" && [ -f scripts/ai-dlc/validate-thing.sh ] && ! grep -q ZZ_NEVER_EXISTS scripts/ai-dlc/validate-thing.sh

---

## PC-SH-CONSUMER-OWNED — bucket 2: consumer-side only, and upstream ships NO counterpart

THE ARM'S LOAD-BEARING DISTINCTION, paired with PC-SH-INSTALLED above. Structurally identical
receipt — same verb, same negation, same token, also never consulting upstream — differing in
ONE property: `scripts/keep.sh` has no core preimage, because map_consumer() sends
`core/scripts/<x>` to `scripts/ai-dlc/<x>` and never to bare `scripts/`. No pull can settle
this, and that is not a defective receipt but a standing consumer-side invariant, so it must
NOT be accused.

Its subject is a DIFFERENT FILE from PC-SH-INSTALLED's on purpose. Sharing one would let a
guard that mis-resolves the mapping reach the same bytes for both, and two guards covering one
subject report zero failures — indistinguishable from two that never fired.

verify: sh cd "$CONSUMER" && [ -f scripts/keep.sh ] && ! grep -q ZZ_NEVER_EXISTS scripts/keep.sh

---

## PC-SH-WATCHDOG — a STAYS-RETIRED watchdog, whose permanent exit 0 is CORRECT

Asserts a retired token has not come back and its replacement is present. Exit 0 forever is
the healthy steady state; it flips only on a regression. Scans tree-wide with no named
subject, which is the clause that must keep this out of the guard's population.

The `:(exclude)` pathspecs are copied from the two live receipts of this shape, not invented:
without them the scan finds the retired token IN THIS VERY ENTRY and the watchdog reports a
close it never earned. A seed built from what the reader accepts instead of what the real
producer emits would have missed that and tested a shape nobody ships.

verify: sh cd "$CONSUMER" && ! git grep -qF ZZ_RETIRED_TOKEN -- ":(exclude)_bmad-output" ":(exclude)docs" && git grep -qF use_new_anchor -- ":(exclude)_bmad-output" ":(exclude)docs"

---
EOM
cd "$WORK/consumer" || exit 2
git init -q .
g "$WORK/consumer" add -A; g "$WORK/consumer" commit -qm consumer

cat > "$WORK/env.sh" <<EOF
WORK="$WORK"
RV="$RV"
DIST="$WORK/dist"
CONSUMER="$WORK/consumer"
BASE="$BASE"
THEIRS="$THEIRS"
EOF

printf '%s\n' "$WORK"
