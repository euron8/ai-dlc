# BL-909 loose grammar (batch b255): the awk program that derives the keyword-free mutant-verdict population.
# Applied once per file, in C-locale glob order, with /usr/bin/awk (macOS, version 20200816), from the root of a
# tree at the measured commit:
#   env -i PATH=/usr/bin:/bin LC_ALL=C bash -c 'for f in core/fixtures/*/run.sh; do
#     /usr/bin/awk -v F="$f" -f docs/analysis/bl909-loose-grammar.awk "$f"; done'
# Each output line is <path>:<line number>:<line>. At cb6e0ab80 (265 run.sh files) it prints the 747 lines in
# 169 fixtures recorded in BL-909, byte-identical to docs/analysis/bl909-loose-pop-cb6e0ab80.txt.
# Rule order is the grammar: a comment line, a line routed through mutant_killed, and a line carrying a KILLED or
# killed token are dropped; what remains must carry ok or note before a quote and name a mutant or mutation.
/^[[:blank:]]*#/ { next }
{
  line=$0
  if (line ~ /mutant_killed/) next
  if (line ~ /KILLED|killed/) next
  if (line !~ /(^|[^A-Za-z0-9_])(ok|note)[[:blank:]]+["\x27]/) next
  if (line !~ /[Mm][Uu][Tt][Aa][Nn][Tt]|[Mm][Uu][Tt][Aa][Tt][Ii][Oo][Nn]/) next
  print F ":" NR ":" line
}
