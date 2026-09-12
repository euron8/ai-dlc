#!/usr/bin/env bash
# fp-sweep.sh — the DERIVER behind the false-positive figures in the sed write/exec
# comment of `validate-artifact-derivations.sh`.
#
# Usage: bash core/fixtures/artifact-derivations/fp-sweep.sh <corpus-dir> [<corpus-dir>...]
#
# IT EXTRACTS BOTH GRAMMARS FROM THE SHIPPING VALIDATOR RATHER THAN RESTATING THEM. A
# second copy of a grammar is an opinion whose bugs nobody finds, and a false-positive
# figure measured against a copy says nothing about the arm that ships. So:
#
#   - the quote-aware pipeline SPLITTER is extracted from `cmd_is_safe`'s `segs=` awk
#     program, which is what decides where a `sed` segment begins and ends;
#   - the sed WRITE/EXEC predicate is extracted from the `sed_verdict=` awk program.
#
# Both extractions carry a control: the extracted text must be non-empty AND must parse
# under `awk -f /dev/null`-style compilation, or this script exits 2 as a REFUSAL rather
# than printing a clean zero. An extraction that silently yielded nothing would report
# "0 false positives" over an empty scan, which is the shape this whole file exists to
# avoid producing.
#
# IT IS READ ONLY. It opens the corpus for reading and writes only under `mktemp`.
#
# Exit: 0 the sweep ran and its controls held | 2 an extraction or a control failed.
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
ROOT="${AI_DLC_PROJECT_ROOT:-}"
[ -n "$ROOT" ] || ROOT="$(ai_dlc_resolve_root "$HERE" || true)"
[ -n "$ROOT" ] || { echo "REFUSE: cannot resolve the project root from $HERE" >&2; exit 2; }

pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
V="$(pick "$ROOT/core/scripts/validate-artifact-derivations.sh" \
          "$ROOT/scripts/ai-dlc/validate-artifact-derivations.sh")"
[ -n "$V" ] || { echo "REFUSE: cannot locate validate-artifact-derivations.sh under $ROOT" >&2; exit 2; }

[ "$#" -ge 1 ] || { echo "usage: $0 <corpus-dir>..." >&2; exit 2; }

W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT

# --- EXTRACT THE SPLITTER -------------------------------------------------------------
# From the line after `segs="$(printf ... | awk '` up to the line carrying `}')"`.
awk "/segs=.*awk '/ { grab = 1; next } grab && /^    }'\)\"/ { print \"    }\"; exit } grab { print }" \
  "$V" > "$W/split.awk"
# --- EXTRACT THE SED PREDICATE --------------------------------------------------------
# From the line after `sed_verdict="$(printf ... | awk '` up to the `exit }')"` terminator.
awk "/sed_verdict=.*awk '/ { grab = 1; next } grab && /exit }'\)\"/ { print \"          exit }\"; exit } grab { print }" \
  "$V" > "$W/sed.awk"

# CONTROLS ON THE EXTRACTION ITSELF. Each must be non-empty and must COMPILE; and each
# must produce the right answer on one known input, because an awk program that compiles
# and matches nothing also prints nothing.
for part in split sed; do
  if [ ! -s "$W/$part.awk" ]; then
    echo "REFUSE: the $part grammar extracted EMPTY from $V -- the anchor moved." >&2; exit 2
  fi
  if ! awk -f "$W/$part.awk" </dev/null >/dev/null 2>&1; then
    echo "REFUSE: the extracted $part grammar does not compile." >&2; exit 2
  fi
done
probe="$(printf "%s\n" "grep -c x f | wc -l" | awk -f "$W/split.awk" | wc -l | tr -d ' ')"
[ "$probe" = "2" ] || { echo "REFUSE: the extracted splitter answered $probe segments for a two-stage pipeline, not 2." >&2; exit 2; }
probe="$(printf "%s\n" "sed -n 'w canary' data.txt" | awk -f "$W/sed.awk")"
[ -n "$probe" ] || { echo "REFUSE: the extracted sed predicate ALLOWED \`sed -n 'w canary'\` -- it is not the shipping arm." >&2; exit 2; }
probe="$(printf "%s\n" "sed -n '/w/p' f" | awk -f "$W/sed.awk")"
[ -z "$probe" ] || { echo "REFUSE: the extracted sed predicate REFUSED \`sed -n '/w/p'\` -- it is not the shipping arm." >&2; exit 2; }
echo "extraction controls: splitter 2 segments, predicate refuses 'w canary' and allows '/w/p'  OK"
echo

# --- THE CORPUS ------------------------------------------------------------------------
files=0
for d in "$@"; do
  [ -d "$d" ] || { echo "REFUSE: no such corpus directory: $d" >&2; exit 2; }
done
find "$@" -type f -name '*.md' > "$W/files.txt"
files="$(wc -l < "$W/files.txt" | tr -d ' ')"
[ "$files" -gt 0 ] || { echo "REFUSE: the corpus holds 0 markdown files -- an empty scan reads as a clean one." >&2; exit 2; }

# Every `$ `-prefixed line, fence indent and marker shed.
grep -rhE '^[[:blank:]]*\$ ' --include='*.md' "$@" | sed 's/^[[:blank:]]*\$ //' > "$W/cmds.txt"
dollar="$(wc -l < "$W/cmds.txt" | tr -d ' ')"

# Split each into segments with the VALIDATOR'S splitter, keep the sed ones.
: > "$W/segs.txt"
while IFS= read -r line; do
  printf '%s\n' "$line" | awk -f "$W/split.awk" 2>/dev/null | while IFS= read -r seg; do
    f="$(printf '%s' "$seg" | sed 's/^[[:space:]]*//' | awk '{print $1}')"
    [ "$f" = "sed" ] && printf '%s\n' "$seg"
  done
done < "$W/cmds.txt" >> "$W/segs.txt"
segs="$(wc -l < "$W/segs.txt" | tr -d ' ')"
uniq_segs="$(sort -u "$W/segs.txt" | wc -l | tr -d ' ')"

# --- THE SWEEP, WITH ITS CONTROLS IN THE SAME INVOCATION -------------------------------
# 9 POSITIVE controls (each must be refused) and 1 NEGATIVE control on an impossible
# token (which must be allowed) are appended to the SAME input the corpus goes through.
{ cat "$W/segs.txt"
  printf "sed -n 'w canary' data.txt\n"
  printf "sed 's/a/b/w canary' data.txt\n"
  printf "sed '/a/w canary' data.txt\n"
  printf "sed 's/a/b/gw canary' data.txt\n"
  printf "sed -n 'W canary' data.txt\n"
  printf "sed '1e touch canary' data.txt\n"
  printf "sed 's/a/b/e' data.txt\n"
  printf "sed -n -f evil.sed data.txt\n"
  printf "sed -ibak 's/a/b/' data.txt\n"
  printf "sed -n 'p' ZZQQ9_NEVER_SED_TOKEN.txt\n"
} > "$W/input.txt"

# One record per line. The predicate emits nothing for an allowed segment, so the verdict
# column is built per line rather than read off a bulk run -- a bulk run would collapse
# the allowed lines and lose the join to the segment that produced each verdict.
: > "$W/verdicts.txt"
while IFS= read -r seg; do
  v="$(printf '%s\n' "$seg" | awk -f "$W/sed.awk")"
  [ -n "$v" ] || v="OK"
  printf '%s\n' "$v"
done < "$W/input.txt" >> "$W/verdicts.txt"

vn="$(wc -l < "$W/verdicts.txt" | tr -d ' ')"
inn="$(wc -l < "$W/input.txt" | tr -d ' ')"
[ "$vn" = "$inn" ] || { echo "REFUSE: $inn inputs produced $vn verdicts." >&2; exit 2; }

# CONTROLS FIRST, before any corpus figure is printed.
pos_refused=0
i=0
while IFS= read -r v; do
  i=$((i + 1))
  if [ "$i" -gt "$segs" ] && [ "$i" -le $((segs + 9)) ] && [ "$v" != "OK" ]; then
    pos_refused=$((pos_refused + 1))
  fi
  [ "$i" = "$inn" ] && neg="$v"
done < "$W/verdicts.txt"
printf 'POSITIVE CONTROLS: %s of 9 seeded write/exec forms refused\n' "$pos_refused"
printf 'NEGATIVE CONTROL:  impossible-token segment -> %s\n' "$neg"
tok="$(grep -rlF 'ZZQQ9_NEVER_SED_TOKEN' --include='*.md' "$@" | wc -l | tr -d ' ')"
printf 'NEGATIVE CONTROL:  that token appears in %s corpus file(s) (must be 0)\n' "$tok"
[ "$pos_refused" = "9" ] || { echo "REFUSE: only $pos_refused of 9 positive controls were refused." >&2; exit 2; }
[ "$neg" = "OK" ] || { echo "REFUSE: the negative control was refused." >&2; exit 2; }
[ "$tok" = "0" ] || { echo "REFUSE: the impossible token is PRESENT in the corpus, so it is not an impossible token." >&2; exit 2; }
echo

# --- THE FIGURES -----------------------------------------------------------------------
head -n "$segs" "$W/verdicts.txt" > "$W/v.txt"
paste "$W/v.txt" "$W/segs.txt" > "$W/joined.txt"
# The population the arm RUNS on: `cmd_is_safe` refuses these metacharacters before any
# segment is scanned. The filter is applied to FIELD 2, never to the joined line -- the
# verdict text itself carries backticks, and filtering the join dropped four real rows and
# read as a cleaner set than the truth.
awk -F'\t' '$2 !~ /[;&><`]/ && $2 !~ /\$\(/ && $2 !~ /\$\{/ && $2 !~ /\|\|/' "$W/joined.txt" > "$W/b.txt"
banned="$(awk -F'\t' '$2 ~ /[;&><`]/ || $2 ~ /\$\(/ || $2 ~ /\$\{/ || $2 ~ /\|\|/' "$W/joined.txt" | wc -l | tr -d ' ')"
bn="$(wc -l < "$W/b.txt" | tr -d ' ')"
b_ok="$(awk -F'\t' '$1 == "OK"' "$W/b.txt" | wc -l | tr -d ' ')"
b_bad="$(awk -F'\t' '$1 != "OK"' "$W/b.txt" | wc -l | tr -d ' ')"
# `-i` is refused by the SHIPPED option table independently of this arm, so a `-i`
# refusal is not an incremental false positive of it.
inc="$(awk -F'\t' '$1 != "OK" && $2 !~ /(^| )-[a-zA-Z]*i/' "$W/b.txt" | wc -l | tr -d ' ')"

printf 'markdown files:                        %s\n' "$files"
printf '$-prefixed command lines:              %s\n' "$dollar"
printf 'sed pipeline segments:                 %s  (%s distinct)\n' "$segs" "$uniq_segs"
printf 'refused upstream by the metachar ban:  %s\n' "$banned"
printf 'POPULATION THIS ARM RUNS ON:           %s\n' "$bn"
printf '  ALLOWED:                             %s\n' "$b_ok"
printf '  REFUSED:                             %s\n' "$b_bad"
printf '  of which a `sed -i` the shipped table already refuses: %s\n' "$((b_bad - inc))"
printf 'INCREMENTAL FALSE-POSITIVE SET:        %s\n' "$inc"
[ "$b_ok" -gt 0 ] || { echo "REFUSE: 0 segments were ALLOWED -- the predicate refuses everything." >&2; exit 2; }
echo
echo 'Every refusal over that population, enumerated:'
awk -F'\t' '$1 != "OK" { printf "  %s\n    %s\n", $2, $1 }' "$W/b.txt" | sort -u
[ "$b_bad" -gt 0 ] || echo '  (none)'
exit 0
