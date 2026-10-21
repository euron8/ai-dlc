#!/usr/bin/env bash
# fp-sweep.sh — the DERIVER behind the option table's corpus counts in
# `validate-artifact-derivations.sh`, and the measured cost of its NEVER set.
#
# Usage: bash core/fixtures/artifact-derivations/fp-sweep.sh <corpus-root> [<corpus-dir>...]
#
#   <corpus-root>   the repository the derivations run in (their paths, globs and `git -C`
#                   resolve against it, so the argv the sweep reads is the argv they would run)
#   <corpus-dir>    the directories to walk; default <corpus-root>. Every `.md` file is walked,
#                   frozen records included -- the `--all` population.
#
# IT HAS NO GRAMMAR OF ITS OWN. Every `$ ` command is handed to the shipping validator's
# `--explain-cmd -`, which prints bash's argv for each segment, each word's class and the verdict.
# A count taken through a second tokeniser says nothing about the boundary that ships, so this
# script only extracts `$ ` lines and tallies what the validator printed.
#
# WHAT IT EMITS:
#   1. a per-row count: every table row, with how many corpus words matched it (0 = FLAGGED, needs
#      a reason in the row's note, never removed by this script);
#   2. every corpus option NOT in the table, with its count and one file:line;
#   3. every corpus command that uses a NEVER-set option, with its file:line -- the NEVER set wins
#      over the corpus, and these records are the measured cost of that.
#
# CONTROLS, in the same invocation, scored through the same `--explain-cmd` run as the corpus:
# seeded write/exec forms must come back REFUSED, and a negative control on an impossible token
# must come back OK, with that token absent from the corpus.
#
# IT IS READ ONLY. It reads the corpus and writes only under `mktemp`. It RUNS NOTHING it reads:
# `--explain-cmd` evaluates each segment only as `set -- <segment>`, after the validator's own
# refusal of every substitution and expansion.
#
# Exit: 0 the sweep ran and its controls held | 2 a control failed or the corpus is empty.
set -uo pipefail

ai_dlc_resolve_root() {
  local d="$1"
  while [ -n "$d" ] && [ "$d" != "/" ] && [ "$d" != "." ]; do
    if [ -e "$d/.git" ] || [ -d "$d/.claude" ] || [ -d "$d/core/skills/ai-dlc" ]; then
      printf '%s\n' "$d"; return 0
    fi
    d="$(dirname "$d")"
  done
  return 1
}
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(ai_dlc_resolve_root "$HERE" || true)"
[ -n "$ROOT" ] || { echo "REFUSE: cannot resolve this repo's root from $HERE" >&2; exit 2; }

pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
V="$(pick "$ROOT/core/scripts/validate-artifact-derivations.sh" \
          "$ROOT/scripts/ai-dlc/validate-artifact-derivations.sh")"
[ -n "$V" ] || { echo "REFUSE: cannot locate validate-artifact-derivations.sh under $ROOT" >&2; exit 2; }

[ "$#" -ge 1 ] || { echo "usage: $0 <corpus-root> [<corpus-dir>...]" >&2; exit 2; }
CROOT="$(cd "$1" 2>/dev/null && pwd)" || { echo "REFUSE: no such corpus root: $1" >&2; exit 2; }
shift
[ "$#" -ge 1 ] || set -- "$CROOT"
for d in "$@"; do [ -d "$d" ] || { echo "REFUSE: no such corpus directory: $d" >&2; exit 2; }; done

W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT

# --- THE CORPUS: every `$ ` line, keyed by file:line --------------------------------------------
find "$@" -type f -name '*.md' > "$W/files.txt"
files="$(wc -l < "$W/files.txt" | tr -d ' ')"
[ "$files" -gt 0 ] || { echo "REFUSE: the corpus holds 0 markdown files -- an empty scan reads as a clean one." >&2; exit 2; }
: > "$W/in.tsv"
while IFS= read -r f; do
  awk -v f="$f" '{ s = $0; sub(/^[ \t]*/, "", s); if (substr(s, 1, 2) == "$ ") printf "%s:%d\t%s\n", f, NR, substr(s, 3) }' "$f" >> "$W/in.tsv"
done < "$W/files.txt"
dollar="$(wc -l < "$W/in.tsv" | tr -d ' ')"

# --- CONTROLS, appended to the same input --------------------------------------------------------
NEG=ZZQQ9_NEVER_OPT_TOKEN
# CTL-POS-1..4 are one HARMLESS unlisted option in four spellings: plain, single-quoted,
# brace-expanded, and a unique PREFIX of a listed long option, refused because the match is exact.
{ printf 'CTL-POS-1\tsort --zz-unlisted-opt d.txt\n'
  printf "CTL-POS-2\tsort '--zz-unlisted-opt' d.txt\n"
  printf 'CTL-POS-3\tsort {--zz-unlisted-opt,} d.txt\n'
  printf 'CTL-POS-4\tsort --dictionary d.txt\n'
  printf "CTL-POS-5\tsed -n 'w canary' data.txt\n"
  printf 'CTL-POS-6\tfind . -delete\n'
  printf 'CTL-POS-7\tgit log --format --output=x\n'
  printf "CTL-POS-8\tawk 'BEGIN { system (\"\") }'\n"
  printf 'CTL-POS-9\tgrep -e -- --zzunlisted f\n'
  printf 'CTL-NEG-1\tgrep -c x %s.txt\n' "$NEG"
} >> "$W/in.tsv"

AI_DLC_PROJECT_ROOT="$CROOT" bash "$V" --explain-cmd - < "$W/in.tsv" > "$W/out.tsv" 2>"$W/err.txt" \
  || { echo "REFUSE: --explain-cmd exited non-zero: $(head -3 "$W/err.txt")" >&2; exit 2; }
inn="$(wc -l < "$W/in.tsv" | tr -d ' ')"
vn="$(awk -F'\t' '$2 == "VERDICT"' "$W/out.tsv" | wc -l | tr -d ' ')"
[ "$vn" = "$inn" ] || { echo "REFUSE: $inn commands produced $vn verdicts." >&2; exit 2; }

pos="$(awk -F'\t' '$1 ~ /^CTL-POS-/ && $2 == "VERDICT" && $3 == "REFUSED"' "$W/out.tsv" | wc -l | tr -d ' ')"
neg="$(awk -F'\t' '$1 == "CTL-NEG-1" && $2 == "VERDICT" { print $3 }' "$W/out.tsv")"
tok="$(grep -rlF "$NEG" --include='*.md' "$@" | wc -l | tr -d ' ')"
printf 'POSITIVE CONTROLS: %s of 9 seeded write/exec/unlisted forms refused\n' "$pos"
printf 'NEGATIVE CONTROL:  impossible-token command -> %s; token in %s corpus file(s) (must be 0)\n' "$neg" "$tok"
[ "$pos" = 9 ] || { echo "REFUSE: only $pos of 9 positive controls were refused." >&2; exit 2; }
[ "$neg" = OK ] || { echo "REFUSE: the negative control was refused." >&2; exit 2; }
[ "$tok" = 0 ] || { echo "REFUSE: the impossible token is PRESENT in the corpus." >&2; exit 2; }
echo

awk -F'\t' '$1 !~ /^CTL-/' "$W/out.tsv" > "$W/corpus.tsv"
ok="$(awk -F'\t' '$2 == "VERDICT" && $3 == "OK"' "$W/corpus.tsv" | wc -l | tr -d ' ')"
ref="$(awk -F'\t' '$2 == "VERDICT" && $3 == "REFUSED"' "$W/corpus.tsv" | wc -l | tr -d ' ')"
printf 'corpus root:            %s\n' "$CROOT"
printf 'markdown files:         %s\n' "$files"
printf '$-prefixed lines:       %s\n' "$dollar"
printf '  OK:                   %s\n' "$ok"
printf '  REFUSED:              %s\n' "$ref"
echo

# --- 1. PER-ROW COUNTS ---------------------------------------------------------------------------
# The table is read out of the validator itself, between its heredoc markers.
awk '/^OPT_TABLE_END$/ { exit } go { print } index($0, "read -r -d") == 1 && index($0, "OPT_TABLE_END") > 0 { go = 1 }' "$V" > "$W/table.txt"
rows="$(wc -l < "$W/table.txt" | tr -d ' ')"
[ "$rows" -gt 0 ] || { echo "REFUSE: read 0 table rows out of $V -- the heredoc marker moved." >&2; exit 2; }
echo "PER-ROW COUNTS ($rows rows; 0 = FLAGGED):"
# A WORD line is: id, WORD, cmd, sub, class, token, argv word.
awk -F'\t' 'FNR == NR { if ($2 == "WORD" && ($5 == "opt" || $5 == "num")) n[$3 "|" $4 "|" $6]++; next }
  { split($0, R, "|"); k = R[1] "|" R[2] "|" R[3]; c = n[k] + 0
    printf "  %6d  %s%s\n", c, $0, (c == 0 ? "  FLAGGED" : "") }' "$W/corpus.tsv" "$W/table.txt"
echo

# --- 2. CORPUS OPTIONS NOT IN THE TABLE ----------------------------------------------------------
echo "CORPUS OPTIONS NOT IN THE TABLE (count, cmd, sub, token, one example):"
awk -F'\t' '$2 == "WORD" && $5 == "unlisted" { k = $3 "\t" $4 "\t" $6; n[k]++; if (!(k in ex)) ex[k] = $1 }
  END { for (k in n) printf "  %6d  %s  %s\n", n[k], k, ex[k] }' "$W/corpus.tsv" | sort -rn
echo

# --- 3. COMMANDS USING A NEVER-SET OPTION --------------------------------------------------------
echo "COMMANDS USING A NEVER-SET OPTION (the measured cost of the NEVER set):"
awk -F'\t' '$2 == "WORD" && $5 == "never" && !seen[$1]++ { print $1 }' "$W/corpus.tsv" > "$W/never-ids.txt"
awk -F'\t' 'FNR == NR { want[$1] = 1; next } ($1 in want) { printf "  %s\n    $ %s\n", $1, $2 }' \
  "$W/never-ids.txt" "$W/in.tsv"
[ -s "$W/never-ids.txt" ] || echo '  (none)'
exit 0
