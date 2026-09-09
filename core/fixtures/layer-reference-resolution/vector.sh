# vector() — the scoring function, sourced by run.sh AND by worker.sh.
#
# IT LIVES IN ITS OWN FILE BECAUSE TWO PROCESSES SCORE WITH IT. The mutants run under an
# inner `xargs -P` pool (run.sh Part 5), so the worker is a separate process and cannot
# inherit a function defined in run.sh. Restating it in the worker would be two copies of
# one grammar drifting apart — the failure `mechanism-design.md` names — so it is defined
# once here and sourced by both. A cell added here is scored by both readers or by neither.
#
# Requires in scope: DOMAIN (the seeded domain.md, read by the applicability cells).

# vector <linter> <root> -> one line, one cell per case
#
# Scored as a VECTOR rather than per row: several of these cells are served by one branch, and
# per-row scoring reports entanglement on every mutant in that shape. One assertion per mutant,
# stating the complete expected vector positively.
vector() {
  local out v=''
  out="$(bash "$1" "$2" 2>&1)"
  # W7 subjects, by (file, id)
  v="d19b=$(grep -q 'checks/domain.md: references "Check 19b"' <<<"$out" && echo W || echo -)"
  v="$v r19b=$(grep -q 'roles/dev.md: references "Check 19b"' <<<"$out" && echo W || echo -)"
  v="$v r11b=$(grep -q 'roles/dev.md: references "Check 11b"' <<<"$out" && echo W || echo -)"
  v="$v c34=$(grep -q 'references "Check 34"' <<<"$out" && echo W || echo -)"
  v="$v c12=$(grep -q 'references "Check 12"' <<<"$out" && echo W || echo -)"
  v="$v c7=$(grep -q 'references "Check 7"' <<<"$out" && echo W || echo -)"
  v="$v alpha=$(grep -qE 'references "Check (A|N)"' <<<"$out" && echo W || echo -)"
  # THE HOOK NAMESPACE — a check implemented in a shipped hook is defined in no rendered-
  # rulebook file and no crosswalk row, so a CORRECT citation of one used to report as
  # dangling. Four cells, and each is silent or loud for a reason no other cell shares:
  #   hk61  the hook named on the line DECLARES it            -> silent
  #   hk62  the OTHER hook declares it, this one does not     -> reports (the per-hook join)
  #   hk64  the hook MENTIONS it and declares nothing         -> reports (declaration, not mention)
  #   hk65  no hook named at all                              -> reports (pre-existing path)
  # hk62 lives in its own file on purpose: W7's grain is (file, id), so seeded beside the
  # correct 62 citation it would be shadowed by it and the cell would be silent for a reason
  # that has nothing to do with the resolver.
  v="$v hk61=$(grep -q 'hook-citations.md: references \"Check 61\"' <<<"$out" && echo W || echo -)"
  v="$v hk62=$(grep -q 'hook-cross.md: references \"Check 62\"' <<<"$out" && echo W || echo -)"
  v="$v hk64=$(grep -q 'hook-citations.md: references \"Check 64\"' <<<"$out" && echo W || echo -)"
  v="$v hk65=$(grep -q 'hook-citations.md: references \"Check 65\"' <<<"$out" && echo W || echo -)"
  # APPLICABILITY: is the form E15 emits actually present in the file it is emitted about?
  # This is the property that failed, and it is not the same as "the message changed".
  local apf dotf
  apf="$(grep -oE "SECTION ID OUT OF BAND(, ALREADY COLLIDED)? — '[^']*' allocates" <<<"$out" | grep -oE "'[^']*'" | tr -d "'" | grep -E '^AP' | head -1)"
  dotf="$(grep -oE "SECTION ID OUT OF BAND(, ALREADY COLLIDED)? — '[^']*' allocates" <<<"$out" | grep -oE "'[^']*'" | tr -d "'" | grep -E '^7' | head -1)"
  v="$v apform=$([ -n "$apf" ] && grep -qF -- "$apf" "$DOMAIN" && echo OK || echo BAD)"
  v="$v dotform=$([ -n "$dotf" ] && grep -qF -- "$dotf" "$DOMAIN" && echo OK || echo BAD)"
  # W9 — the script-citation namespace. Three subjects that must report and four that must
  # not, and each silent cell is silent for a DIFFERENT reason: the file resolves, the path
  # is fenced, the path is not root-relative, the file is not an entry.
  v="$v w9miss=$(grep -q 'roles/dev.md: names `scripts/missing-tool.sh`' <<<"$out" && echo W || echo -)"
  v="$v w9dot=$(grep -q 'roles/dev.md: names `scripts/dot-slash-missing.sh`' <<<"$out" && echo W || echo -)"
  v="$v w9ovr=$(grep -q 'overrides/gate-validation__8.md: names `scripts/override-missing.sh`' <<<"$out" && echo W || echo -)"
  v="$v w9ok=$(grep -q 'names `scripts/present.sh`' <<<"$out" && echo W || echo -)"
  v="$v w9fence=$(grep -q 'names `scripts/fenced-missing.sh`' <<<"$out" && echo W || echo -)"
  v="$v w9dist=$(grep -q 'dist-only-missing.sh' <<<"$out" && echo W || echo -)"
  v="$v w9rdme=$(grep -q 'names `scripts/readme-missing.sh`' <<<"$out" && echo W || echo -)"
  # W12 — the citation that RESOLVES and still names the wrong check. Every silent cell here
  # is silent for a different reason, which is what the six mutants below take apart. The
  # grammar is `cites`, never `references`: W7's message uses the other verb on the same ids,
  # and a cell keyed on the id alone would score W7's finding as this arm's.
  v="$v w12t26=$(grep -q 'cites \"Check 26\"' <<<"$out" && echo W || echo -)"
  v="$v w12g24=$(grep -q 'cites \"Check 24\"' <<<"$out" && echo W || echo -)"
  v="$v w12q17=$(grep -q 'cites \"Check 17\"' <<<"$out" && echo W || echo -)"
  v="$v w12w19b=$(grep -q 'cites \"Check 19b\"' <<<"$out" && echo W || echo -)"
  v="$v w12x34=$(grep -q 'cites \"Check 34\"' <<<"$out" && echo W || echo -)"
  v="$v w12n8=$(grep -q 'cites \"Check 8\"' <<<"$out" && echo W || echo -)"
  v="$v w12p20=$(grep -q 'cites \"Check 20\"' <<<"$out" && echo W || echo -)"
  # The AMBIGUOUS bucket is not a warning, so it cannot be read off the default output. It is
  # a POSITIVE assertion on the listing: a count alone would be satisfied by two rows that are
  # not the two seeded, and the bare-stem case is the one this fixture exists to pin.
  # I54, and it bit here before it was spotted: `grep -q` leaves at its first match, the
  # writer takes the EPIPE, and under `set -o pipefail` the pipeline reports NOT-FOUND on
  # input that contains the pattern. The count cell survived it only because `grep -c` reads
  # to EOF. Run once, capture, and feed both readers a here-string.
  local refs_out
  refs_out="$(bash "$1" "$2" --check-refs 2>&1)"
  v="$v w12amb=$(grep -c '^  ambiguous ' <<<"$refs_out")"
  v="$v w12stem=$(grep -q 'ambiguous.*"Check 30"' <<<"$refs_out" && echo A || echo -)"
  # THE RESTRAINT HALF of the crosswalk rule: a corroborating row removes the EXEMPTION and
  # must not PROMOTE. Asserted on the listing, positively, because "no warning for Check 26"
  # is also what a stood-down subject looks like.
  v="$v w12x26amb=$(grep -q 'ambiguous.*"Check 26"' <<<"$refs_out" && echo A || echo -)"
  # THE COUNT LINE ITSELF. Its whole job is to stop a reader inferring "N genuinely
  # undecidable" from N, so the caveat is the payload and not decoration — a note that keeps
  # the number and loses the sentence is the failure this cell exists to catch.
  v="$v w12note=$(grep -q 'UNADJUDICATED is not UNDECIDABLE' <<<"$out" && echo N || echo -)"
  # THE SELF-REFERENCE SIGNAL: a bare sub-band citation inside the section defining its own
  # band counterpart. No title, no tag — the position is the whole evidence.
  v="$v w12self=$(grep -q 'from INSIDE the section that defines' <<<"$out" && echo W || echo -)"
  # THE `shadows:` SIGNAL, three-state on purpose. `-` is also what a subject that was never
  # reached looks like, so the cell has to distinguish quiet-by-declaration from absent: the
  # mutant that disables the branch must move it to A, not merely leave it at `-`.
  v="$v w12shadow5=$(grep -q 'cites \"Check 5\"' <<<"$out" && echo W \
      || { grep -q 'ambiguous.*\"Check 5\"' <<<"$refs_out" && echo A || echo -; })"
  # THE WRAPPED QUALIFIER and THE SECTION REBUTTAL, both three-state for the same reason the
  # shadows cell is: `-` is also what a subject nothing reached looks like, and each mutant
  # below has to move its cell to W rather than merely leave it silent.
  v="$v w12wrap21=$(grep -q 'cites \"Check 21\"' <<<"$out" && echo W \
      || { grep -q 'ambiguous.*\"Check 21\"' <<<"$refs_out" && echo A || echo -; })"
  v="$v w12sect23=$(grep -q 'cites \"Check 23\"' <<<"$out" && echo W \
      || { grep -q 'ambiguous.*\"Check 23\"' <<<"$refs_out" && echo A || echo -; })"
  printf '%s' "$v"
}
