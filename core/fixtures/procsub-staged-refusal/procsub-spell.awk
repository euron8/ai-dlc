# procsub-spell.awk -- THE ONE SPELLING GRAMMAR for lines ADDED to shipped core/*.sh. Run it as
# `awk -f scripts/procsub-spell.awk <unified-diff>`; it prints `<rule>: <line>` per offending added line.
#
# TWO READERS LOAD THIS FILE AND NOTHING RESTATES IT: core/fixtures/procsub-staged-refusal/run.sh (the
# spelling arm, diffed against its PIN) and scripts/pregate-self-check.sh (the builder's own diff against
# a base). A byte copy in either is the drift this file exists to prevent.
#
# Lines ADDED to shipped core/*.sh must not carry:
#   r1  `done <<< "$(`                 a here-string of a substitution: the producer's status is lost
#   r2  `| while `                     a loop in a pipeline: its refusals end a subshell
#   r3  `> file ... || true` / `|| :`  a staging redirect whose failure is folded into success
#   r4  a heredoc whose body line opens with `$(`   the same loss as r1, spelled as a heredoc
# Comment lines are skipped. `2>/dev/null` and `>&N` are removed before r3 is tested, so a
# silenced stderr is not a staging redirect. A QUOTED heredoc delimiter expands nothing and is not r4.
# NO EXEMPTION LIST: a correct site that matches is respelled, never listed.
/^\+\+\+ / { next }
/^@@/ { prev = ""; next }
/^\+/ {
  l = substr($0, 2)
  if (l ~ /^[[:blank:]]*#/) { prev = ""; next }
  hit = ""
  if (l ~ /done[[:blank:]]*<<<[[:blank:]]*"?\$\(/) hit = "r1"
  else if (l ~ /(^|[^|])\|[[:blank:]]*while[[:blank:]]/) hit = "r2"
  else {
    s = l
    gsub(/[0-9]*>[[:blank:]]*\/dev\/null/, "", s)
    gsub(/>&[0-9]/, "", s)
    if (s ~ />[^|]*\|\|[[:blank:]]*(true|:)([[:blank:]]|;|\)|$)/) hit = "r3"
    else if (l ~ /^\$\(/ && prev ~ /<<-?[A-Za-z_]+[[:blank:]]*$/) hit = "r4"
  }
  if (hit != "") print hit ": " l
  prev = l
  next
}
{ prev = "" }
