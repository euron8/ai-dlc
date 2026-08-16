#!/usr/bin/env bash
# Render the adjudication register's two tables from the TSVs that own them.
#
# WHY THIS EXISTS. The register's 115-row verdict table was typed by hand, and 39 of its ids
# were abbreviations of the ledger's real label -- 17 of them on rows bound for the CHANGELOG,
# where the id has to appear VERBATIM or graph's closer cannot join it. Nothing was wrong with
# the adjudication; the ids decayed in transcription, silently, in the one column where a
# character matters. A table a model retypes is a table that drifts from the data it reports, so
# this renders it instead and `--check` byte-compares at the gate.
#
# Usage:  render-register-tables.sh            rewrite the GENERATED regions in place
#         render-register-tables.sh --check    exit 1 if the file is not what this would render
set -uo pipefail

S="$(cd "$(dirname "$0")" && pwd)"
REG="$S/../graph-ledger-full-adjudication.md"
MODE="${1:-write}"

for f in adjudicable-entries.tsv phase1-verdicts.tsv refutation-verdicts.tsv final-disposition.tsv post-pin-verdicts.tsv; do
  [ -r "$S/$f" ] || { echo "render-register-tables: missing input $f" >&2; exit 2; }
done
[ -r "$REG" ] || { echo "render-register-tables: missing register $REG" >&2; exit 2; }

# A GLOB THAT MATCHES NOTHING MUST NOT REPORT SUCCESS, and the same holds for an empty TSV: an
# empty corpus renders an empty table and reads exactly like "every row agreed".
rows="$(LC_ALL=C awk 'END{print NR}' "$S/final-disposition.tsv")"
[ "${rows:-0}" -gt 0 ] || { echo "render-register-tables: final-disposition.tsv is empty" >&2; exit 2; }

render_verdict_table() {
  printf '| pin | entry | verdict | subsystem | close channel |\n'
  printf '|---|---|---|---|---|\n'
  # Sorted by ledger order, numerically -- the pin column is an offset, so a lexical sort puts
  # line 1069 before line 297 and the table stops tracking the ledger it claims to mirror.
  LC_ALL=C sort -t"$(printf '\t')" -k1,1n "$S/final-disposition.tsv" | LC_ALL=C awk -F'\t' '
    {
      ch = ($7 == "changelog-cite") ? "changelog" : "brief (" $8 ")"
      printf "| %s | `%s` | **%s** | %s | %s |\n", $1, $2, $3, $6, ch
    }'
}

render_disposition_table() {
  printf '| disposition | count | via CHANGELOG cite | via brief annotation |\n'
  printf '|---|---|---|---|\n'
  LC_ALL=C awk -F'\t' '
    { n[$5]++; if ($7=="changelog-cite") c[$5]++; else b[$5]++ }
    END {
      # Fixed order, not the hash order: awk iterates an array unpredictably, and a table whose
      # row order moves between runs cannot be byte-compared.
      split("LIVE|CLOSE|CLOSE + file the sub-claim|LIVE (close withdrawn)|CLOSE (UNVERIFIED)", k, "|")
      for (i = 1; i <= 5; i++) {
        d = k[i]
        if (!(d in n)) continue
        printf "| %s | %d | %d | %d |\n", d, n[d], c[d]+0, b[d]+0
      }
    }' "$S/final-disposition.tsv"
}

render_postpin_table() {
  # Keyed by line in the LIVE ledger, not the pin -- these entries were filed after the pin was
  # taken, so a pin offset does not locate them and pretending otherwise would give the reader a
  # citation that resolves to the wrong entry. Kept in a table of their own for the same reason:
  # folding them into the 115 would silently restate a verified, closed count.
  printf '| live line | entry | verdict | receipt |\n'
  printf '|---|---|---|---|\n'
  LC_ALL=C sort -t"$(printf '\t')" -k1,1n "$S/post-pin-verdicts.tsv" | LC_ALL=C awk -F'\t' '
    { r = ($5 == "NO-RECEIPT") ? "**none — invisible to the closer**" : "`" $5 "`"
      printf "| %s | `%s` | **%s** | %s |\n", $1, $2, $3, r }'
}

render_withdrawn_table() {
  # THE LAST HAND-TYPED ID COLUMN IN THIS FILE, and it had already decayed the same way the 39
  # did: pin 4216 was written `PC-S303-POSTCOMPACT-RECOVERY-MANDATE-NO-STATED-EXCEPTION` and the
  # ledger spells it `...-MANDATE-HAS-NO-STATED-EXCEPTION`. Measured by joining every `PC-` token
  # in the register against every one in the pinned ledger: 93 resolve, and of the 16 that do not,
  # 14 are deliberate prose shorthand and 2 sat in an id column of this table. A wrong id in a
  # prose sentence costs a reader a grep; a wrong id in an id column is what a citation is drafted
  # from, and a CHANGELOG citing it closes nothing while looking exactly like one that did.
  printf '| pin | entry | was | why it broke |\n'
  printf '|---|---|---|---|\n'
  LC_ALL=C awk -F'\t' '
    # `LC_ALL=C` makes substr/length count BYTES, so a naive cut lands mid-UTF-8 and emits an
    # invalid sequence into a committed file -- and these why-strings do carry multibyte: one
    # carries Cyrillic, several carry em-dashes. Dropping the whole trailing sequence is the safe
    # trim: at worst it costs one character at a cut that is already lossy. The byte-range class
    # is correct HERE precisely because the locale is C; it is matching lead/continuation bytes,
    # not a character.
    function clip(s,   t) {
      if (length(s) <= 150) return s
      t = substr(s, 1, 150)
      sub(/[\300-\377][\200-\277]*$/, "", t)
      return t "…"
    }
    FILENAME ~ /refutation-verdicts/ { why[$1] = $3; next }
    $5 == "LIVE (close withdrawn)" {
      printf "| %s | `%s` | `%s` | %s |\n", $1, $2, $3, clip(why[$1])
    }' "$S/refutation-verdicts.tsv" "$S/final-disposition.tsv"
}

render_gated_list() {
  # THE HEADING'S COUNT IS INSIDE THIS REGION ON PURPOSE. It was typed by hand as "fifteen", and
  # when pin 1254's sub-claim was refuted the derived table moved to fourteen while the prose and
  # its bullet list did not -- `--check` passed the whole time, because a hand-written section is
  # not a region it compares. A count in prose beside a table it does not come from is the same
  # stale-enumeration shape the verdict table was rendered to remove.
  LC_ALL=C awk -F'\t' '
    $5 == "CLOSE + file the sub-claim" { n++; label[n] = $2; pin[n] = $1 }
    END {
      printf "## The %d that close only once a sub-claim is filed\n\n", n
      print "Each is right about its headline and would bury a live finding that **no other entry owns**."
      print "These become `BL-` entries in `docs/backlog.md` before the close ships.\n"
      for (i = 1; i <= n; i++) printf "- **%s** (pin %s)\n", label[i], pin[i]
    }' "$S/final-disposition.tsv"
}

emit_region() { # <marker> <renderer>
  printf '<!-- BEGIN GENERATED: %s -->\n' "$1"
  "$2"
  printf '<!-- END GENERATED: %s -->\n' "$1"
}

build() {
  # Splice each region's body between its markers, leaving everything else byte-identical.
  #
  # NOT VIA `awk -v`. That strips one level of escaping and carries no newline, so a multi-line
  # table body passed through it arrives mangled while the call site still looks correct -- the
  # failure mode is a rendered table that differs from the data by an escape, which is exactly
  # the class of defect this renderer exists to remove. The regions go through FILES, whose
  # bytes survive verbatim, and awk reads them with `getline` at the marker.
  local tmp="$1"
  emit_region verdict-table     render_verdict_table     > "$RD/verdict-table"
  emit_region disposition-table render_disposition_table > "$RD/disposition-table"
  emit_region postpin-table     render_postpin_table     > "$RD/postpin-table"
  emit_region gated-list        render_gated_list        > "$RD/gated-list"
  emit_region withdrawn-table   render_withdrawn_table   > "$RD/withdrawn-table"
  LC_ALL=C awk -v dir="$RD" '
    function spill(name,   line) {
      while ((getline line < (dir "/" name)) > 0) print line
      close(dir "/" name)
    }
    /^<!-- BEGIN GENERATED: verdict-table -->$/     { spill("verdict-table");     skip=1; next }
    /^<!-- END GENERATED: verdict-table -->$/       { skip=0; next }
    /^<!-- BEGIN GENERATED: disposition-table -->$/ { spill("disposition-table"); skip=1; next }
    /^<!-- END GENERATED: disposition-table -->$/   { skip=0; next }
    /^<!-- BEGIN GENERATED: postpin-table -->$/     { spill("postpin-table");     skip=1; next }
    /^<!-- END GENERATED: postpin-table -->$/       { skip=0; next }
    /^<!-- BEGIN GENERATED: gated-list -->$/        { spill("gated-list");        skip=1; next }
    /^<!-- END GENERATED: gated-list -->$/          { skip=0; next }
    /^<!-- BEGIN GENERATED: withdrawn-table -->$/    { spill("withdrawn-table");   skip=1; next }
    /^<!-- END GENERATED: withdrawn-table -->$/      { skip=0; next }
    !skip { print }
  ' "$REG" > "$tmp"
}

TMP="$(mktemp)"; RD="$(mktemp -d)"; trap 'rm -rf "$TMP" "$RD"' EXIT
build "$TMP"

# BOTH MARKERS MUST HAVE BEEN PRESENT. Without this the script silently rewrites nothing when a
# marker is missing or misspelled, and --check then passes on a file it never rendered into --
# a check that cannot fire, reading exactly like one that passed.
for m in verdict-table disposition-table postpin-table gated-list withdrawn-table; do
  n="$(LC_ALL=C grep -cF "<!-- BEGIN GENERATED: $m -->" "$TMP")"
  [ "$n" = "1" ] || { echo "render-register-tables: region '$m' appears $n times after render, expected 1" >&2; exit 2; }
done

if [ "$MODE" = "--check" ]; then
  if cmp -s "$TMP" "$REG"; then
    echo "ok: register tables match the TSVs"
  else
    echo "FAIL: register tables are not what the TSVs render. Run render-register-tables.sh" >&2
    diff "$REG" "$TMP" | head -20 >&2
    exit 1
  fi
else
  cat "$TMP" > "$REG"
  echo "rendered: $(LC_ALL=C awk 'END{print NR}' "$S/final-disposition.tsv") rows into $REG"
fi
