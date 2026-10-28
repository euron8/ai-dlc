# vector() — the scoring function, sourced by run.sh AND by worker.sh.
#
# IT LIVES IN ITS OWN FILE BECAUSE TWO PROCESSES SCORE WITH IT. The mutants run under an
# inner `xargs -P` pool (run.sh Part 5), so the worker is a separate process and cannot
# inherit a function defined in run.sh. Restating it in the worker would be two copies of
# one grammar drifting apart — the failure `mechanism-design.md` names — so it is defined
# once here and sourced by both. A cell added here is scored by both readers or by neither.
#
# Requires in scope: DOMAIN (the seeded domain.md, read by the applicability cells).
#
# TWO ENTRY POINTS, ONE DEFINITION OF EVERY CELL. `vector` scores every cell (the live pass
# over the shipped linter and the `--matrix` measurement). `vector_cells` scores only the cells
# it is handed, so a per-push mutant run pays for the linter runs its deciding cell and its twin
# need and no more. Both go through `_vc`, so a cell is the same code in both.
# A linter run is fetched on first need and cached for ONE vector_cells call.

VECTOR_CELLS="d19b r19b r11b c34 c12 c7 alpha hk61 hk62 hk64 hk65 apform dotform w9miss w9dot w9ovr w9ok w9fence w9dist w9rdme w12t26 w12g24 w12q17 w12w19b w12x34 w12n8 w12p20 w12amb w12stem w12x26amb w12note w12self w12shadow5 w12wrap21 w12sect23"

# cell_of <vector-string> <cell> -> sets _R to that cell's value; returns 1 when absent
cell_of() {
  local _t; _R=''
  for _t in $1; do
    case "$_t" in "$2="*) _R="${_t#*=}"; return 0 ;; esac
  done
  return 1
}

_vc_fetch_out() { [ -n "${_vc_out+x}" ] || _vc_out="$(bash "$_vc_l" "$_vc_r" 2>&1)"; }
# I54: the listing is captured once and both readers get a here-string; `grep -q` never
# reads from a pipe, because it leaves at its first match and the writer takes the EPIPE.
_vc_fetch_refs() { [ -n "${_vc_refs+x}" ] || _vc_refs="$(bash "$_vc_l" "$_vc_r" --check-refs 2>&1)"; }

# three-state cell: W when the default output cites the check, else A when the --check-refs
# listing carries it as ambiguous, else -. `-` is also what a subject nothing reached looks like,
# so each mutant has to move its cell to W/A rather than merely leave it silent.
_vc_three() { # _vc_three <check-number>
  _vc_fetch_out
  if grep -q "cites \"Check $1\"" <<<"$_vc_out"; then _R=W; return 0; fi
  _vc_fetch_refs
  if grep -q "ambiguous.*\"Check $1\"" <<<"$_vc_refs"; then _R=A; else _R=-; fi
}

_vc_forms() { # the two applicability forms, from the default-output run
  local _a
  _a="$(grep -oE "SECTION ID OUT OF BAND(, ALREADY COLLIDED)? — '[^']*' allocates" <<<"$_vc_out" | grep -oE "'[^']*'" | tr -d "'")"
  apf="$(grep -E '^AP' <<<"$_a" | head -1)"
  dotf="$(grep -E '^7' <<<"$_a" | head -1)"
}

# _vc <cell> -> sets _R. Reads _vc_l (linter) and _vc_r (root) from vector_cells' frame.
_vc() {
  case "$1" in
    w12amb|w12stem|w12x26amb|w12shadow5|w12wrap21|w12sect23) ;;
    *) _vc_fetch_out ;;
  esac
  case "$1" in
    d19b)  grep -q 'checks/domain.md: references "Check 19b"' <<<"$_vc_out" && _R=W || _R=- ;;
    r19b)  grep -q 'roles/dev.md: references "Check 19b"' <<<"$_vc_out" && _R=W || _R=- ;;
    r11b)  grep -q 'roles/dev.md: references "Check 11b"' <<<"$_vc_out" && _R=W || _R=- ;;
    c34)   grep -q 'references "Check 34"' <<<"$_vc_out" && _R=W || _R=- ;;
    c12)   grep -q 'references "Check 12"' <<<"$_vc_out" && _R=W || _R=- ;;
    c7)    grep -q 'references "Check 7"' <<<"$_vc_out" && _R=W || _R=- ;;
    alpha) grep -qE 'references "Check (A|N)"' <<<"$_vc_out" && _R=W || _R=- ;;
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
    hk61) grep -q 'hook-citations.md: references "Check 61"' <<<"$_vc_out" && _R=W || _R=- ;;
    hk62) grep -q 'hook-cross.md: references "Check 62"' <<<"$_vc_out" && _R=W || _R=- ;;
    hk64) grep -q 'hook-citations.md: references "Check 64"' <<<"$_vc_out" && _R=W || _R=- ;;
    hk65) grep -q 'hook-citations.md: references "Check 65"' <<<"$_vc_out" && _R=W || _R=- ;;
    # APPLICABILITY: is the form E15 emits actually present in the file it is emitted about?
    # This is the property that failed, and it is not the same as "the message changed".
    apform)  _vc_forms; { [ -n "$apf" ] && grep -qF -- "$apf" "$DOMAIN"; } && _R=OK || _R=BAD ;;
    dotform) _vc_forms; { [ -n "$dotf" ] && grep -qF -- "$dotf" "$DOMAIN"; } && _R=OK || _R=BAD ;;
    # W9 — the script-citation namespace. Three subjects that must report and four that must
    # not, and each silent cell is silent for a DIFFERENT reason: the file resolves, the path
    # is fenced, the path is not root-relative, the file is not an entry.
    w9miss)  grep -q 'roles/dev.md: names `scripts/missing-tool.sh`' <<<"$_vc_out" && _R=W || _R=- ;;
    w9dot)   grep -q 'roles/dev.md: names `scripts/dot-slash-missing.sh`' <<<"$_vc_out" && _R=W || _R=- ;;
    w9ovr)   grep -q 'overrides/gate-validation__8.md: names `scripts/override-missing.sh`' <<<"$_vc_out" && _R=W || _R=- ;;
    w9ok)    grep -q 'names `scripts/present.sh`' <<<"$_vc_out" && _R=W || _R=- ;;
    w9fence) grep -q 'names `scripts/fenced-missing.sh`' <<<"$_vc_out" && _R=W || _R=- ;;
    w9dist)  grep -q 'dist-only-missing.sh' <<<"$_vc_out" && _R=W || _R=- ;;
    w9rdme)  grep -q 'names `scripts/readme-missing.sh`' <<<"$_vc_out" && _R=W || _R=- ;;
    # W12 — the citation that RESOLVES and still names the wrong check. The grammar is `cites`,
    # never `references`: W7's message uses the other verb on the same ids, and a cell keyed on
    # the id alone would score W7's finding as this arm's.
    w12t26)  grep -q 'cites "Check 26"' <<<"$_vc_out" && _R=W || _R=- ;;
    w12g24)  grep -q 'cites "Check 24"' <<<"$_vc_out" && _R=W || _R=- ;;
    w12q17)  grep -q 'cites "Check 17"' <<<"$_vc_out" && _R=W || _R=- ;;
    w12w19b) grep -q 'cites "Check 19b"' <<<"$_vc_out" && _R=W || _R=- ;;
    w12x34)  grep -q 'cites "Check 34"' <<<"$_vc_out" && _R=W || _R=- ;;
    w12n8)   grep -q 'cites "Check 8"' <<<"$_vc_out" && _R=W || _R=- ;;
    w12p20)  grep -q 'cites "Check 20"' <<<"$_vc_out" && _R=W || _R=- ;;
    # The AMBIGUOUS bucket is not a warning, so it cannot be read off the default output. It is
    # a POSITIVE assertion on the listing: a count alone would be satisfied by two rows that are
    # not the two seeded, and the bare-stem case is the one this fixture exists to pin.
    w12amb)  _vc_fetch_refs; _R="$(grep -c '^  ambiguous ' <<<"$_vc_refs")" ;;
    w12stem) _vc_fetch_refs; grep -q 'ambiguous.*"Check 30"' <<<"$_vc_refs" && _R=A || _R=- ;;
    # THE RESTRAINT HALF of the crosswalk rule: a corroborating row removes the EXEMPTION and
    # must not PROMOTE. Asserted on the listing, positively, because "no warning for Check 26"
    # is also what a stood-down subject looks like.
    w12x26amb) _vc_fetch_refs; grep -q 'ambiguous.*"Check 26"' <<<"$_vc_refs" && _R=A || _R=- ;;
    # THE COUNT LINE ITSELF. Its whole job is to stop a reader inferring "N genuinely
    # undecidable" from N, so the caveat is the payload and not decoration.
    w12note) grep -q 'UNADJUDICATED is not UNDECIDABLE' <<<"$_vc_out" && _R=N || _R=- ;;
    # THE SELF-REFERENCE SIGNAL: a bare sub-band citation inside the section defining its own
    # band counterpart. No title, no tag — the position is the whole evidence.
    w12self) grep -q 'from INSIDE the section that defines' <<<"$_vc_out" && _R=W || _R=- ;;
    # THE `shadows:` SIGNAL, THE WRAPPED QUALIFIER and THE SECTION REBUTTAL, all three-state.
    w12shadow5) _vc_three 5 ;;
    w12wrap21)  _vc_three 21 ;;
    w12sect23)  _vc_three 23 ;;
    *) echo "vector: unknown cell $1" >&2; return 2 ;;
  esac
}

# vector_cells <linter> <root> <cell>... -> "cell=value" per requested cell, in the order given.
# Scored as a VECTOR rather than per row: several of these cells are served by one branch, and
# per-row scoring reports entanglement on every mutant in that shape.
vector_cells() {
  local _vc_l="$1" _vc_r="$2" _c _v='' _vc_out _vc_refs apf='' dotf=''
  unset _vc_out _vc_refs
  shift 2
  for _c in "$@"; do
    _vc "$_c" || return 2
    _v="${_v:+$_v }$_c=$_R"
  done
  printf '%s' "$_v"
}

# vector <linter> <root> -> every cell
vector() { vector_cells "$1" "$2" $VECTOR_CELLS; }
