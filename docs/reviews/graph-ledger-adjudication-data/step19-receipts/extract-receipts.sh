#!/usr/bin/env bash
# Extract the drafted step-19 replacement receipts out of the per-batch markdown and render
# docs/reviews/graph-ledger-adjudication-data/replacement-receipts.tsv, which render-brief.sh
# reads for the brief's section E.
#
# EXTRACTED, NOT RETYPED. The receipts are `eval`ed by the consumer's engine, so quoting is part
# of the predicate and a hand-transcribed receipt is a different program.
#
# THE `rc` COLUMN IS MEASURED HERE BY RUNNING THE RECEIPT, NOT PARSED OUT OF THE PROSE.
# Measured on the real corpus: batch-3.md:123 states "measured rc=1 today" about an ABSENCE arm
# inside a section whose receipt measures 0, so the first `rc=` in a section is not the section's
# result. A prose figure and a measurement read identically in a TSV and only one of them is
# evidence.
#
# THE LABEL COLUMN COMES FROM THE PHASE 0 CENSUS, NOT FROM THE BATCH HEADING. Measured: the
# heading at batch-3.md:186 abbreviates its own label by five words, and 39 of 115 ids in this
# program's register were abbreviations before that was caught. An id that exists nowhere closes
# nothing, silently.
#
# POLARITY, from ledger-reverify.sh's own `sh` dispatch and not from any header: for the CONSUMER
# engine rc=0 is STILL-LIVE and non-zero is CLOSE-CANDIDATE. Every `sh` receipt here must measure
# 0 today, because every subject is a live defect. A non-zero is a FALSE CLOSE and this script
# refuses to record one.
#
# Usage: extract-receipts.sh [--check | --probe]
#   --check   byte-compare a fresh extraction against the committed TSV
#   --probe   seed offenders and near-misses under mktemp and assert every arm fires

set -u

# --- repo root: walk up for the VERSION marker, never count `..` hops -------------------------
root=$(cd "$(dirname "$0")" && pwd)
while [ "$root" != "/" ] && [ ! -f "$root/VERSION" ]; do root=$(dirname "$root"); done
[ -f "$root/VERSION" ] || { echo "REFUSING: no VERSION marker above $0" >&2; exit 1; }

DD="$root/docs/reviews/graph-ledger-adjudication-data"
SD="${AI_DLC_S19_DIR:-$DD/step19-receipts}"
CENSUS="${AI_DLC_S19_CENSUS:-$DD/adjudicable-entries.tsv}"
# The Phase 0 census stops at the corpus pin (the ledger's first 4356 lines), so the three entries
# graph filed above the pin resolve in NEITHER of its columns. Two of them owe a receipt, so the
# label map is the union of the census and the post-pin verdicts -- otherwise ARM 5 refuses a
# perfectly good receipt for a pin the census structurally cannot contain.
POSTPIN="${AI_DLC_S19_POSTPIN:-$DD/post-pin-verdicts.tsv}"
OUT="${AI_DLC_S19_OUT:-$DD/replacement-receipts.tsv}"

MODE="${1:-}"
[ "$MODE" = "--probe" ] && { exec bash "$0" --probe-run; }

if [ "$MODE" = "--probe-run" ]; then
  # ---- SELF-PROBE, and it runs BEFORE any real corpus is touched --------------------------
  # Both directions for every arm: a seeded offender must be REFUSED with its own exit code, and
  # a seeded near-miss must PASS. An arm that refuses everything reads exactly like one that
  # discriminates.
  P=$(mktemp -d) || exit 1
  trap 'rm -rf "$P"' EXIT
  [ "$P" != "$SD" ] || { echo "PROBE BROKEN: probe dir equals the real dir" >&2; exit 1; }
  printf '999001\ttheirs_has\tPC-PROBE-SEEDED-LABEL\n' > "$P/census.tsv"
  mkdir -p "$P/d"
  seed() { # seed <name> <old-line> <new-line>
    cat > "$P/d/batch-$1.md" <<EOF
# probe $1

## Pin 999001 — \`PC-PROBE-SEEDED-LABEL\`

**OLD**

\`\`\`
$2
\`\`\`

**NEW**

\`\`\`
$3
\`\`\`
EOF
  }
  : > "$P/postpin.tsv"   # hermetic: the probe must not resolve a label out of the real corpus
  run() { AI_DLC_S19_DIR="$P/d" AI_DLC_S19_CENSUS="$P/census.tsv" AI_DLC_S19_OUT="$P/out.tsv" \
            AI_DLC_S19_POSTPIN="$P/postpin.tsv" bash "$0" >"$P/log" 2>&1; echo $?; }
  fail=0
  chk() { # chk <what> <expected-rc> <actual-rc>
    if [ "$2" = "$3" ]; then printf '  ok    %-46s exit %s\n' "$1" "$3"
    else printf '  FAIL  %-46s expected %s got %s\n' "$1" "$2" "$3"; sed 's/^/        /' "$P/log"; fail=1; fi
  }

  # A6 near-miss FIRST: a well-formed seed must PASS, or every later refusal is meaningless.
  seed 1 'verify: theirs_has core/x.md "s"' 'verify: sh true'
  chk 'near-miss: a well-formed batch passes' 0 "$(run)"

  # A1 empty corpus
  rm -f "$P/d"/batch-*.md
  chk 'A1 no batch files' 2 "$(run)"

  # A2 a section carrying one verify line, not two
  cat > "$P/d/batch-1.md" <<'EOF'
## Pin 999001 — `PC-PROBE-SEEDED-LABEL`

```
verify: sh true
```
EOF
  chk 'A2 section with one verify line' 3 "$(run)"

  # A3 the NEW line is neither `sh` nor `manual`
  seed 1 'verify: theirs_has core/x.md "s"' 'verify: theirs_lacks core/x.md "s"'
  chk 'A3 NEW verb is not sh/manual' 4 "$(run)"

  # A4 a pin the census cannot resolve
  seed 1 'verify: theirs_has core/x.md "s"' 'verify: sh true'
  sed 's/999001/999002/' "$P/d/batch-1.md" > "$P/d/batch-1.md.t" && mv "$P/d/batch-1.md.t" "$P/d/batch-1.md"
  chk 'A4 pin absent from the census' 5 "$(run)"

  # A5 an `sh` receipt that does NOT measure 0 -- a FALSE CLOSE
  seed 1 'verify: theirs_has core/x.md "s"' 'verify: sh false'
  chk 'A5 sh receipt measures non-zero' 6 "$(run)"

  # A7 a TAB inside a receipt would split the TSV column
  seed 1 'verify: theirs_has core/x.md "s"' 'verify: sh true'
  awk '{ if ($0 ~ /^verify: sh /) print "verify: sh\ttrue"; else print }' "$P/d/batch-1.md" > "$P/d/b.t" \
    && mv "$P/d/b.t" "$P/d/batch-1.md"
  chk 'A7 tab inside a receipt' 7 "$(run)"

  # A8 `manual` is accepted and carries rc=n/a
  seed 1 'verify: (absent — this entry carries no directive, so flush() emits no row for it)' \
         'verify: manual no mechanical predicate exists: the subject never shipped upstream'
  r=$(run); chk 'A8 manual receipt accepted' 0 "$r"
  if [ "$r" = "0" ]; then
    if LC_ALL=C awk -F'\t' 'NR>1 && $5=="n/a"{n++} END{exit !(n==1)}' "$P/out.tsv"; then
      echo '  ok    A8 manual row carries rc=n/a'
    else echo '  FAIL  A8 manual row rc column'; fail=1; fi
  fi

  [ "$fail" = 0 ] && { echo "PROBE: all arms fire in both directions"; exit 0; }
  echo "PROBE FAILED" >&2; exit 1
fi

# --- ARM 1: a glob that matches nothing must not report success -------------------------------
set -- "$SD"/batch-*.md
nb=0; for f in "$@"; do [ -e "$f" ] && nb=$((nb+1)); done
[ "$nb" -gt 0 ] || { echo "REFUSING: no batch-*.md under $SD -- an empty corpus reads exactly like a clean run" >&2; exit 2; }

TMP=$(mktemp -d) || exit 1
trap 'rm -rf "$TMP"' EXIT

# --- parse: the ONLY parser of the batch markdown ---------------------------------------------
# One record per pin section: pin, file, line of the NEW receipt, how many `verify:` lines the
# section carried, the OLD line, the NEW line. Four authors wrote four heading grammars
# (`## Entry N — pin X ·`, `## pin X —`, `## Pin X —`), so the pin is taken from the digits after
# `pin` and everything else about the heading is ignored -- including its label.
LC_ALL=C awk '
  function flush() {
    if (curpin == "") return
    printf "%s\t%s\t%s\t%s\t%s\t%s\n", curpin, curfile, newln, nv, old, new
    curpin = ""
  }
  /^## / {
    flush()
    if (match($0, /[Pp]in [0-9]+/)) {
      s = substr($0, RSTART, RLENGTH); gsub(/[^0-9]/, "", s)
      curpin = s; curfile = FILENAME; nv = 0; old = ""; new = ""; newln = 0
    }
    next
  }
  curpin != "" && /^verify: / {
    nv++
    if (nv == 1) old = $0
    new = $0; newln = FNR
    next
  }
  END { flush() }
' "$@" > "$TMP/parsed"

n=$(wc -l < "$TMP/parsed" | tr -d ' ')
[ "$n" -gt 0 ] || { echo "REFUSING: $nb batch file(s) parsed to zero sections" >&2; exit 3; }

# --- ARM 2: exactly two `verify:` lines per section ------------------------------------------
if bad=$(LC_ALL=C awk -F'\t' '$4 != 2 {printf "  %s pin %s carries %s verify: line(s), expected 2\n", $2, $1, $4}' "$TMP/parsed"); [ -n "$bad" ]; then
  echo "REFUSING: malformed section(s):" >&2; printf '%s\n' "$bad" >&2; exit 3
fi

# --- ARM 3: no TAB inside a receipt, or the TSV column silently splits ------------------------
# THIS ARM RUNS BEFORE THE VERB ARM AND THE ORDER IS LOAD-BEARING. A tab inside the NEW receipt
# shifts every field after it, so `$6` becomes the text following the tab and the verb arm below
# refuses first, with a message about a verb rather than about a tab. Found by this script's own
# probe, which expected exit 7 and got 4.
if bad=$(LC_ALL=C awk -F'\t' 'NF != 6 {printf "  %s pin %s: a receipt contains a TAB\n", $2, $1}' "$TMP/parsed"); [ -n "$bad" ]; then
  echo "REFUSING: tab-bearing receipt(s):" >&2; printf '%s\n' "$bad" >&2; exit 7
fi

# --- ARM 4: the NEW line must be a verb the engine dispatches --------------------------------
if bad=$(LC_ALL=C awk -F'\t' '$6 !~ /^verify: (sh|manual) ./ {printf "  %s pin %s NEW is not sh/manual: %s\n", $2, $1, substr($6,1,60)}' "$TMP/parsed"); [ -n "$bad" ]; then
  echo "REFUSING: bad NEW directive(s):" >&2; printf '%s\n' "$bad" >&2; exit 4
fi

# --- ARM 5: every pin resolves to an authoritative label -------------------------------------
[ -f "$CENSUS" ] || { echo "REFUSING: census $CENSUS absent" >&2; exit 5; }
LC_ALL=C awk -F'\t' -v OFS='\t' '{print $1, $3}' "$CENSUS" > "$TMP/labels"
[ -f "$POSTPIN" ] && LC_ALL=C awk -F'\t' -v OFS='\t' '{print $1, $2}' "$POSTPIN" >> "$TMP/labels"
if bad=$(LC_ALL=C awk -F'\t' 'NR==FNR{lbl[$1]=$2;next} !($1 in lbl){printf "  %s pin %s resolves in neither the census nor the post-pin verdicts\n", $2, $1}' "$TMP/labels" "$TMP/parsed"); [ -n "$bad" ]; then
  echo "REFUSING: unresolved pin(s):" >&2; printf '%s\n' "$bad" >&2; exit 5
fi

# --- measure every receipt, under the engine's own exported environment ----------------------
export DIST="$root"
export CONSUMER=/Users/n8/git/graph
export BASE=adec9ae
THEIRS=$(git -C "$DIST" rev-parse HEAD) || exit 1
export THEIRS

: > "$TMP/rows"
falseclose=""
while IFS=$'\t' read -r pin file newln nv old new; do
  case "$new" in
    "verify: manual "*) rc="n/a" ;;
    *)
      body=${new#verify: sh }
      ( cd "$DIST" && eval "$body" ) >/dev/null 2>&1
      rc=$?
      [ "$rc" -eq 0 ] || falseclose="$falseclose  $(basename "$file") pin $pin measured rc=$rc (non-zero = CLOSE-CANDIDATE = FALSE CLOSE)
"
      ;;
  esac
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$pin" "$file" "$newln" "$rc" "$old" "$new" >> "$TMP/rows"
done < "$TMP/parsed"

# --- ARM 6: an `sh` receipt measuring non-zero is a false close, not a result ----------------
if [ -n "$falseclose" ]; then
  echo "REFUSING: receipt(s) measured non-zero today:" >&2; printf '%s' "$falseclose" >&2
  echo "  For the CONSUMER engine rc=0 is STILL-LIVE. Every subject here is a live defect." >&2
  exit 6
fi

# --- render ----------------------------------------------------------------------------------
# The note column is DERIVED for every row rather than taken from each author's prose: whether the
# receipt carries the unresolvable-subject guard, and where the evidence for it lives. A relocated
# subject exits non-zero and reads as an absorption that never happened, so the presence or
# absence of that guard is the single most load-bearing fact about a receipt after its rc.
{
  printf 'pin\tlabel\told\tnew\trc\tnote\n'
  LC_ALL=C awk -F'\t' -v DD="docs/reviews/graph-ledger-adjudication-data/step19-receipts" '
    NR==FNR { lbl[$1]=$2; next }
    {
      pin=$1; f=$2; ln=$3; rc=$4; old=$5; new=$6
      n=split(f, pp, "/"); base=pp[n]
      if (rc == "n/a")
        note = "No mechanical predicate; reported as HAND-REVIEW, never as a close."
      else if (new ~ /exit 127/)
        note = "Guarded: an unresolvable subject exits 127, which the engine reports as NEEDS-REVIEW rather than as a close."
      else
        note = "NO 127 guard. A renamed or relocated subject would exit non-zero and read as an absorption that never happened -- confirm the subject resolves before acting on any future non-zero."
      printf "%s\t%s\t%s\t%s\t%s\t%s Evidence, two-sided probe and the author'"'"'s stated hesitation: `%s/%s:%s`.\n", \
        pin, lbl[pin], old, new, rc, note, DD, base, ln
    }
  ' "$TMP/labels" "$TMP/rows" | sort -t"$(printf '\t')" -k1,1n
} > "$TMP/out.tsv"

if [ "$MODE" = "--check" ]; then
  if cmp -s "$TMP/out.tsv" "$OUT"; then echo "ok: $(basename "$OUT") matches a fresh extraction"; exit 0
  else echo "DRIFT: $OUT does not match a fresh extraction" >&2; diff "$OUT" "$TMP/out.tsv" | head -20 >&2; exit 1; fi
fi

cp "$TMP/out.tsv" "$OUT"
rows=$(( $(wc -l < "$OUT" | tr -d ' ') - 1 ))
echo "extracted $rows receipt(s) from $nb batch file(s) -> ${OUT#"$root"/}"
LC_ALL=C awk -F'\t' 'NR>1 {printf "  pin %-6s rc=%-4s %s\n", $1, $5, substr($2,1,64)}' "$OUT"
