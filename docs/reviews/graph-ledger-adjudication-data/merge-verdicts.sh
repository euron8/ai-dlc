#!/usr/bin/env bash
# Apply refutation outcomes to the Phase 1 verdicts, and route each close to the channel that
# can actually carry it.
#
# CLOSE-CONFIRMED -> the Phase 1 verdict stands.
# CLOSE-NARROWED  -> the close stands BUT a named sub-claim must be filed before it ships.
# REFUTED         -> the close is withdrawn; the entry returns to the live set.
#
# A close with NO refutation row is NOT confirmed - it is UNVERIFIED, and is reported as such
# rather than silently inheriting the Phase 1 verdict. That distinction is the whole point:
# "nobody checked" and "checked and survived" must not render identically.
#
# THIS SCRIPT NAMED TWO FILES THAT DO NOT EXIST, so as committed it exited 2 and recomputed
# nothing. It was cited as the way to reproduce final-disposition.tsv, which means the one
# mechanism standing between a hand-edited disposition table and a derived one was dead. The
# inputs are now the committed filenames. Repaired, it reproduces the committed table
# byte-identically; `cmp` detects a one-character mutant, so that comparison can fail.
#
# CHANNEL, THE SIXTH COLUMN, AND WHY A CLOSE IS NOT ONE THING. The only two ways a close
# reaches the consumer are a CHANGELOG naming the entry's `PC-` id VERBATIM -- which graph's
# ledger-reverify.sh turns into a NAMED-UPSTREAM row -- and an annotation the operator carries
# into a graph session. The first is unavailable to two disjoint sets of entries, and both were
# about to be reported as though it were:
#
#   - An entry with NO `verify:` receipt emits no row at all. `flush()` in ledger-reverify.sh
#     gates on `has_verify &&`, so no CHANGELOG citation, however correct, can produce a
#     NAMED-UPSTREAM row for it.
#   - An entry whose label is not id-shaped is rejected by `named_absorbed()` on its first
#     line: `case "$_id" in *[!A-Z0-9-]*|'') return 0`. A bullet-form entry labelled with a
#     path or a sentence has nothing to cite verbatim in the first place.
#
# Those entries still close. `ledger-rotate.sh` archives on the strict annotation form
# `**ADOPTED UPSTREAM (v<digit>` ALONE -- it contains no `has_verify` test anywhere -- so the
# brief's rendered annotation retires them. What changes is the EVIDENCE: a NAMED-UPSTREAM row
# for the citable ones, an archived entry for the rest. Emitting one acceptance criterion over
# both sets would be unreachable for the second, and an unreachable criterion reads exactly
# like one that passed.
#
# BOTH GATES, AND THE FIRST CUT OF THIS COLUMN IMPLEMENTED ONLY ONE. Keying the channel on
# id-shape alone marks four receiptless-but-id-shaped entries `changelog-cite`, which is the
# same false-green this column exists to prevent: they are id-shaped, so they LOOK citable, and
# `flush()` still emits nothing for them. A NAMED-UPSTREAM row needs the receipt AND the
# id-shape, so the conjunction is the predicate.
#
# Both halves are read from the Phase 0 census, which was lifted from the shipping tool's own
# extraction program -- the receipt kind in its second field, the label in its third. Deriving
# either here by re-reading the ledger would be a second implementation whose bugs nobody
# finds, and restating the register's ids by hand is what put 39 wrong ones in it: 17 on rows
# bound for the CHANGELOG.
set -uo pipefail
S="$(cd "$(dirname "$0")" && pwd)"
LC_ALL=C awk -F'\t' '
  # Pass 1: the census. Field 2 is the receipt kind (NO-RECEIPT / theirs_has / manual / sh /
  # theirs_lacks), field 3 the authoritative label.
  FNR==NR && FILENAME ~ /adjudicable-entries/ { rcpt[$1]=$2; cid[$1]=$3; next }
  FILENAME ~ /refutation-verdicts/ { r[$1]=$2; next }
  {
    line=$1; id=$2; v=$3; sys=$4
    if (v ~ /^(ALREADY-FIXED|FALSIFIED|DUPLICATE-OF)/) {
      o = (line in r) ? r[line] : "UNVERIFIED"
      if (o=="REFUTED")            final="LIVE (close withdrawn)"
      else if (o=="CLOSE-NARROWED") final="CLOSE + file the sub-claim"
      else if (o=="CLOSE-CONFIRMED") final="CLOSE"
      else                          final="CLOSE (UNVERIFIED)"
    } else { o="n/a"; final="LIVE" }
    # The channel is a property of the ENTRY, not of the verdict: a live entry that is later
    # remediated is cited in the CHANGELOG too, and hits the same wall.
    has_id   = (cid[line] ~ /^PC-[A-Z0-9-]+$/)
    has_rcpt = (rcpt[line] != "NO-RECEIPT" && rcpt[line] != "")
    channel = (has_id && has_rcpt) ? "changelog-cite" : "brief-annotation"
    # WHY it is unreachable, not merely that it is -- an operator reading `brief-annotation`
    # otherwise cannot tell a missing receipt from an unusable label, and the remedies differ:
    # one wants a receipt supplied, the other has no id to cite at all.
    if (channel == "changelog-cite") why="-"
    else if (!has_id && !has_rcpt)  why="no-pc-id+no-receipt"
    else if (!has_id)               why="no-pc-id"
    else                            why="no-receipt"
    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", line, id, v, o, final, sys, channel, why
  }
' "$S/adjudicable-entries.tsv" "$S/refutation-verdicts.tsv" "$S/phase1-verdicts.tsv"
