#!/usr/bin/env bash
# BL-543 receipt: a mixed EDIT + WRITE repair, the Write NOT first, read by the shipping splitter and
# worklist. Exit 0 only when (1) the split keeps `sections/.before` through --assemble, (2) the
# worklist lists the replaced text of BOTH hunks with a HIT in the sibling file, (3) a cite below the
# moved line is a MOVED-CITE and one above it is not, (5) that emitted run removes `sections/.before`,
# and (4) the re-run, now with no pre-repair copy, exits 3 with an UNASSESSABLE line, never a clean 0.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
R="$(cd "$(dirname "$0")/../../.." && pwd)"
S="$R/core/scripts"; [ -f "$S/serial-remediation-worklist.sh" ] || S="$R/scripts/ai-dlc"
[ -f "$S/serial-remediation-worklist.sh" ] && [ -f "$S/partition-document.sh" ] || { echo "receipt: subject absent" >&2; exit 1; }
W="$(mktemp -d "${TMPDIR:-/tmp}/bl543.XXXXXX")" || exit 2
trap 'rm -rf "$W"' EXIT
W="$(cd "$W" && pwd -P)"; mkdir -p "$W/.git"
L() { local i; for i in $(seq 1 "$2"); do printf '%s line %d with enough words to weigh as real prose.\n' "$1" "$i"; done; }
{ printf '## A\n\n'; L a 5; printf 'Section A keeps a hardcoded floor of one hundred units.\n'; L a2 4
  printf '\n## B\n\n'; L b 10
  printf '\n## C\n\n'; L c 5; printf 'Section C defers the rebind to the next sprint entirely.\n'; L c2 4; } > "$W/d.md"
bash "$S/partition-document.sh" --split "$W/d.md" "$W/r" >/dev/null 2>&1 || exit 1
a="$(awk -F'\t' '$1=="part" && $5=="## A" {print $2}' "$W/r/sections/.manifest")"
c="$(awk -F'\t' '$1=="part" && $5=="## C" {print $2}' "$W/r/sections/.manifest")"
[ -n "$a" ] && [ -n "$c" ] && [ "$a" != "$c" ] || exit 1
# The Edit (section A: one line becomes two) and the Write (section C rewritten), Write second.
sed 's/^Section A keeps a hardcoded floor of one hundred units\.$/Section A reads the floor from config.\
It is compared in USD./' "$W/r/sections/$a.md" > "$W/t" && mv "$W/t" "$W/r/sections/$a.md"
{ printf '\n## C\n\n'; L cc 5; printf 'Section C ships the rebind now.\n'; L cc2 4; } > "$W/r/sections/$c.md"
bash "$S/partition-document.sh" --assemble "$W/r" >/dev/null 2>&1 || exit 1
[ -f "$W/r/sections/.before" ] || exit 1
bl="$(grep -n '^b line 2 ' "$W/d.md" | cut -d: -f1)"; bl=$((bl - 1))
{ echo 'Copy: Section A keeps a hardcoded floor of one hundred units.'
  echo 'Copy: Section C defers the rebind to the next sprint entirely.'
  printf 'See `d.md:%s` and `d.md:2`.\n' "$bl"; } > "$W/o.md"
out="$(cd "$W" && AI_DLC_PROJECT_ROOT="$W" bash "$S/serial-remediation-worklist.sh" "$W/r" --also "$W/o.md" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || exit 1
grep -qx '    HIT o.md:1' <<<"$out" && grep -qx '    HIT o.md:2' <<<"$out" || exit 1
grep -q "^MOVED-CITE o.md:3  d.md:$bl -> " <<<"$out" && ! grep -q '^MOVED-CITE o.md:3  d.md:2 ' <<<"$out" || exit 1
# (5) the emitted worklist consumed its pre-repair copy -- the re-run below then has none.
[ ! -e "$W/r/sections/.before" ] || exit 1
out="$(cd "$W" && AI_DLC_PROJECT_ROOT="$W" bash "$S/serial-remediation-worklist.sh" "$W/r" 2>&1)"; rc=$?
[ "$rc" -eq 3 ] && grep -q '^UNASSESSABLE d\.md:' <<<"$out" || exit 1
echo "BL-543 receipt: PASS"
