#!/usr/bin/env bash
# Apply refutation outcomes to the Phase 1 verdicts.
#
# CLOSE-CONFIRMED -> the Phase 1 verdict stands.
# CLOSE-NARROWED  -> the close stands BUT a named sub-claim must be filed before it ships.
# REFUTED         -> the close is withdrawn; the entry returns to the live set.
#
# A close with NO refutation row is NOT confirmed - it is UNVERIFIED, and is reported as such
# rather than silently inheriting the Phase 1 verdict. That distinction is the whole point:
# "nobody checked" and "checked and survived" must not render identically.
set -uo pipefail
S="$(cd "$(dirname "$0")" && pwd)"
LC_ALL=C awk -F'\t' '
  NR==FNR { r[$1]=$2; next }
  {
    line=$1; id=$2; v=$3; sys=$4
    if (v ~ /^(ALREADY-FIXED|FALSIFIED|DUPLICATE-OF)/) {
      o = (line in r) ? r[line] : "UNVERIFIED"
      if (o=="REFUTED")            final="LIVE (close withdrawn)"
      else if (o=="CLOSE-NARROWED") final="CLOSE + file the sub-claim"
      else if (o=="CLOSE-CONFIRMED") final="CLOSE"
      else                          final="CLOSE (UNVERIFIED)"
    } else { o="n/a"; final="LIVE" }
    printf "%s\t%s\t%s\t%s\t%s\t%s\n", line, id, v, o, final, sys
  }
' "$S/refute-all.tsv" "$S/verdicts.tsv"
