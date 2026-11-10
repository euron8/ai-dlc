#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
# remediator-shard-join/unit-bind.sh -- BIND1-BIND3: the join's SAME and DOUBLE-WRITE refusal text bound to the
# merge's. Driven by run.sh, which passes its own arguments through (--matrix prints this file's MATRIX rows; the
# header block is run.sh's). The merge (merge-adversarial-shards.sh) is the REFERENCE: its text is fixed and the
# join's is held to it.
#
# BIND1, the SAME pin. Each script carries exactly one `SAME) refuse "` line. The text from `refuse "` to the
# closing `"` is compared: the merge's carries `${REC_PREFIX}${_c}` exactly once (its `${_c}` is relative), the
# join's carries `${_c}` and no REC_PREFIX at all (its `${_c}` is already the full path, and the join never defines
# REC_PREFIX, so a prefix there is an unbound-variable crash under set -u), and removing that ONE token from the
# merge's text leaves the two byte-equal. The emitted strings are then identical; the source spellings differ by
# the one token and nothing else.
#
# BIND2, the DOUBLE-WRITE pin. Each script carries exactly one `refuse "DOUBLE-WRITE ` line. The two cannot be
# byte-equal, so the merge's text is rewritten through the DECLARED differences and only then compared with the
# join's, byte for byte. THE ALLOWED-DIFFERENCE LIST, each applied exactly once on the merge's side (a substitution
# that matched nothing is a FAIL, so a reworded merge cannot pass by skipping one):
#   - `${_tb}` -> `${_a}` (every occurrence): the merge names a shard, the join names a part;
#   - the merge's seal clause `; ${_tsl}` before ` -- ` is DROPPED: the join has no seal-holder read;
#   - `a NEW adversary for` -> `a NEW remediator for`;
#   - `and merge with --rerun` -> `and join with --rerun`;
#   - `the merged shard is not independent` -> `the joined part is not independent`;
#   - the join-specific SPAN variables: after the above, every `${...}` other than `${_a}` is generalised to one
#     placeholder on BOTH sides, so the join may name its file and writer spans as it likes, while their number
#     and positions stay pinned.
# Anything else that differs is an undeclared drift and fires. The shared clause `start can pass, because a writer
# kept writing after another writer's first row (a stop directive not honored)` is also required literally in both.
#
# BIND3, the carrier count: no THIRD copy of either refusal. Corpus: every `*.sh` in the join's own scripts dir
# ($SRCDIR) and the hooks dir beside the recording hook ($HOOK), resolved from lib.sh the way unit-reader-a.sh
# resolves its siblings, never a literal `core/` glob, so it reads the same in either layout. FIXTURES ARE
# EXCLUDED: a fixture pins these strings on purpose. Counted: non-comment LINES (first non-blank byte not `#`)
# carrying `both before the re-run start and at` or `a writer kept writing after another writer's first row`.
# OWNERSHIP SPLIT, so a mutant fails exactly one arm: BIND1/BIND2 own "exactly one per subject" (their extraction
# refuses zero or two); BIND3 owns "at most one per subject and zero in every other file". Together that is
# exactly one per script.
# FLOOR: both subject basenames must be in the scanned set, the number of files awk actually read must equal the
# glob's list, and an empty glob REFUSES -- never a silent pass.
# KNOWN LIMITS: inside hermetic-run's sandbox the glob sees only the files inputs.decl declares, so a third carrier
# in an undeclared core/scripts file is invisible there (the whole directory is deliberately NOT declared: this
# fixture would then re-run on every core/scripts edit); and a paraphrase of either phrase evades the count.
#
# SELF-PROBES run BEFORE the real check, on mktemp copies of the two scripts, never on the real files. BIND0 asserts
# the unmutated copies pass (the base every kill is gated on). Each mutant must fail its own arm and only it:
#   BINDm-strip   the merge copy's SAME line loses `${REC_PREFIX}`       -> BIND1
#   BINDm-prefix  the join copy's SAME line gains `${REC_PREFIX}`        -> BIND1
#   BINDm-same    one word of the join copy's SAME text changed          -> BIND1
#   BINDm-dw      one word of the join copy's shared DW clause changed   -> BIND2
#   BINDm-dwdel   the join copy's DW line deleted                        -> BIND2
#   BINDm-third   a third carrier seeded as a scripts-dir x.sh           -> BIND3
# and each near-miss must stay QUIET:
#   BINDQ1  a comment line inserted in the case arm and the SAME and DW lines re-indented (never the prefix);
#   BINDQ3  both phrases on a `#` comment line of a scripts-dir x.sh (the comment exclusion exercised).
#   BINDQ4  an EMPTY .sh in the hooks dir, counted by the floor (an empty file has no FNR==1 record).
#   (no fixture-dir near-miss: the corpus is two non-recursive globs, so a fixtures path is unreachable by construction.)
# BINDF   the floor: an empty scripts and hooks dir REFUSES.
# BINDF2  the floor: an unopenable listed .sh (chmod 000, non-root) REFUSES.
#
# Exit: 0 every cell passed, 1 a cell failed, 2 the fixture could not run.
set -u
NAME="remediator-shard-join-bind"
MATRIX=0
[ "${1:-}" = --matrix ] && MATRIX=1
UBD_HERE="$(cd "$(dirname "$0")" && pwd)"
[ -f "$UBD_HERE/lib.sh" ] || { echo "FIXTURE BROKEN: $NAME: lib.sh is absent beside $0; nothing was asserted" >&2; exit 2; }
# shellcheck source=/dev/null
. "$UBD_HERE/lib.sh" > /dev/null || { echo "FIXTURE BROKEN: $NAME: sourcing lib.sh failed" >&2; exit 2; }
MUT_LIB="$(cd "$HERE/../lib" 2>/dev/null && pwd)/mutant.sh"
[ -f "$MUT_LIB" ] || { echo "FIXTURE BROKEN: $NAME: lib/mutant.sh not found beside $HERE" >&2; exit 2; }
# shellcheck source=/dev/null
. "$MUT_LIB"
N_MROWS=0
mrow() { [ "$MATRIX" = 1 ] || return 0; N_MROWS=$((N_MROWS + 1)); echo "  MATRIX $*"; }

MERGE="$SRCDIR/merge-adversarial-shards.sh"
HOOKDIR="$(cd "$(dirname "$HOOK")" && pwd)"
[ -f "$MERGE" ] || { echo "FIXTURE BROKEN: $NAME: $MERGE is not beside the join; nothing was asserted" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/scripts/merge-adversarial-shards.sh"

BD_P1='both before the re-run start and at'
BD_P2="a writer kept writing after another writer's first row"
BD_CL="start can pass, because a writer kept writing after another writer's first row (a stop directive not honored)"

# bd_pins <merge> <join> -- BIND1 and BIND2. Prints one `PASS <arm>` or `FAIL <arm> <why>` line per arm.
bd_pins() {
  awk -v CL="$BD_CL" '
    function cnt(s, t,   n, i) { n = 0; while ((i = index(s, t)) > 0) { n++; s = substr(s, i + length(t)) } return n }
    function rep1(s, a, b,   i) { i = index(s, a); if (i == 0) return s; return substr(s, 1, i - 1) b substr(s, i + length(a)) }
    function repall(s, a, b,   o, i) { o = ""; while ((i = index(s, a)) > 0) { o = o substr(s, 1, i - 1) b; s = substr(s, i + length(a)) } return o s }
    function gen(s,   o, i, j, v) { o = ""
      while ((i = index(s, "${")) > 0) { j = index(substr(s, i), "}"); if (j == 0) break
        v = substr(s, i, j); o = o substr(s, 1, i - 1) ((v == "${_a}") ? v : "${*}"); s = substr(s, i + j) }
      return o s }
    function msg(l,   i, s) { i = index(l, "refuse \""); s = substr(l, i + 8); sub(/"[^"]*$/, "", s); return s }
    FNR == 1 { fi++ }
    $0 ~ /^[[:space:]]*SAME\) refuse "/ { ns[fi]++; S[fi] = msg($0) }
    index($0, "refuse \"DOUBLE-WRITE ") > 0 { nd[fi]++; D[fi] = msg($0) }
    END {
      # BIND1
      if (ns[1] != 1 || ns[2] != 1) print "FAIL BIND1 SAME refuse lines: merge=" ns[1] + 0 " join=" ns[2] + 0 " (want 1 each)"
      else if (cnt(S[1], "${REC_PREFIX}${_c}") != 1 || cnt(S[1], "REC_PREFIX") != 1) print "FAIL BIND1 the merge SAME text carries ${REC_PREFIX}${_c} " cnt(S[1], "${REC_PREFIX}${_c}") " time(s) and REC_PREFIX " cnt(S[1], "REC_PREFIX") " (want 1 and 1)"
      else if (cnt(S[2], "REC_PREFIX") != 0 || cnt(S[2], "${_c}") < 1) print "FAIL BIND1 the join SAME text carries REC_PREFIX " cnt(S[2], "REC_PREFIX") " time(s) and ${_c} " cnt(S[2], "${_c}") " (want 0 and at least 1)"
      else if (rep1(S[1], "${REC_PREFIX}", "") != S[2]) print "FAIL BIND1 the SAME texts differ beyond ${REC_PREFIX}: merge-minus-prefix=[" rep1(S[1], "${REC_PREFIX}", "") "] join=[" S[2] "]"
      else print "PASS BIND1"
      # BIND2
      if (nd[1] != 1 || nd[2] != 1) { print "FAIL BIND2 DOUBLE-WRITE refuse lines: merge=" nd[1] + 0 " join=" nd[2] + 0 " (want 1 each)"; exit 0 }
      m = D[1]; bad = ""
      if (index(m, CL) == 0 || index(D[2], CL) == 0) bad = bad " the shared clause is not literal in both (merge=" (index(m, CL) > 0) " join=" (index(D[2], CL) > 0) ");"
      if (cnt(m, "${_tb}") < 1) bad = bad " ${_tb} absent from the merge;"
      m = repall(m, "${_tb}", "${_a}")
      n = split("; ${_tsl} -- |a NEW adversary for|and merge with --rerun|the merged shard is not independent", A, "|")
      split(" -- |a NEW remediator for|and join with --rerun|the joined part is not independent", B, "|")
      for (k = 1; k <= n; k++) { if (cnt(m, A[k]) != 1) bad = bad " declared difference [" A[k] "] occurs " cnt(m, A[k]) " time(s) in the merge (want 1);"; m = rep1(m, A[k], B[k]) }
      if (bad == "" && gen(m) != gen(D[2])) bad = " undeclared drift: merge-normalised=[" gen(m) "] join=[" gen(D[2]) "]"
      if (bad != "") print "FAIL BIND2" bad; else print "PASS BIND2"
    }' "$1" "$2"
}

# bd_carriers <scripts dir> <hooks dir> <merge basename> <join basename> -- BIND3 and its floor.
bd_carriers() {
  local _f _list="" _nl=0 _hm=0 _hj=0
  for _f in "$1"/*.sh "$2"/*.sh; do
    [ -f "$_f" ] || continue
    _list="$_list $_f"; _nl=$((_nl + 1))
    case "$(basename "$_f")" in "$3") _hm=1 ;; "$4") _hj=1 ;; esac
  done
  if [ "$_nl" -eq 0 ]; then echo "FAIL BIND3 REFUSED: the corpus glob over $1 and $2 matched no file"; return 0; fi
  if [ "$_hm" = 0 ] || [ "$_hj" = 0 ]; then echo "FAIL BIND3 REFUSED: the scanned set lacks a subject (merge=$_hm join=$_hj) over $_nl file(s)"; return 0; fi
  # shellcheck disable=SC2086
  awk -v P1="$BD_P1" -v P2="$BD_P2" -v M="$3" -v J="$4" -v NL="$_nl" '
    # The floor opens each listed file in BEGIN: getline returns -1 for an unopenable file and 0 for an empty one,
    # so an empty readable file counts as read (it has no FNR==1 record) and an unopenable one still refuses.
    BEGIN { for (i = 1; i < ARGC; i++) { if ((getline line < ARGV[i]) >= 0) nread++; close(ARGV[i]) }
      if (nread != NL) { print "FAIL BIND3 REFUSED: awk read " nread + 0 " of the " NL " listed file(s)"; refused = 1; exit 0 } }
    /^[[:space:]]*#/ { next }
    { b = FILENAME; sub(/.*\//, "", b)
      if (index($0, P1) > 0) c1[b]++
      if (index($0, P2) > 0) c2[b]++ }
    END {
      if (refused) exit 0
      bad = ""
      for (b in c1) if ((b == M || b == J) ? c1[b] > 1 : c1[b] > 0) bad = bad " " b " carries the SAME phrase on " c1[b] " line(s);"
      for (b in c2) if ((b == M || b == J) ? c2[b] > 1 : c2[b] > 0) bad = bad " " b " carries the DOUBLE-WRITE phrase on " c2[b] " line(s);"
      if (bad != "") print "FAIL BIND3" bad; else print "PASS BIND3 over " nread " file(s)"
    }' $_list
}

# bd_check <merge> <join> <scripts dir> <hooks dir> -- all three arms into $BD_OUT; the failing arms' codes, comma
# separated, in BD_FAILED (empty when all three passed).
bd_check() {
  { bd_pins "$1" "$2"; bd_carriers "$3" "$4" "$(basename "$1")" "$(basename "$2")"; } > "$BD_OUT"
  BD_FAILED="$(awk '$1 == "FAIL" { printf "%s%s", s, $2; s = "," }' "$BD_OUT")"
}
BD_OUT="$WORK/bind.out"

# ------------------------------------------------------------------------- the self-probes, before the real check
bd_tree() { # <name> -- a fresh probe tree holding copies of the two real scripts; prints its root
  local _t
  _t="$(mktemp -d "$WORK/bind-$1.XXXXXX")" || return 1
  mkdir -p "$_t/core/scripts" "$_t/core/hooks" "$_t/core/fixtures/x" || return 1
  cp "$MERGE" "$_t/core/scripts/" && cp "$JOIN" "$_t/core/scripts/" || return 1
  printf '%s\n' "$_t"
}
MB="$(basename "$MERGE")"; JB="$(basename "$JOIN")"
# bd_mut <tree> <file> <awk program> -- rewrite one copy through awk; refuses (rc 1) when nothing changed.
bd_mut() {
  awk -v PFX='${REC_PREFIX}' "$3" "$1/core/scripts/$2" > "$1/core/scripts/$2.new" || return 1
  if cmp -s "$1/core/scripts/$2" "$1/core/scripts/$2.new"; then return 1; fi
  mv "$1/core/scripts/$2.new" "$1/core/scripts/$2"
}
bd_run() { bd_check "$1/core/scripts/$MB" "$1/core/scripts/$JB" "$1/core/scripts" "$1/core/hooks"; }

B_BIND0=0
t0="$(bd_tree base)" || { echo "FIXTURE BROKEN: $NAME: no probe tree" >&2; exit 2; }
bd_run "$t0"
if [ -z "$BD_FAILED" ] && [ "$(grep -c '^PASS ' "$BD_OUT")" = 3 ]; then ok "BIND0: the unmutated probe copies of the merge and the join pass BIND1, BIND2 and BIND3"; B_BIND0=1
else bad "BIND0: the unmutated probe copies did not pass every bind arm (failed=$BD_FAILED): $(tr '\n' ' ' < "$BD_OUT")"; fi

# bd_score <tree> <want failing codes> -- 0 when exactly the wanted arms failed
bd_score() { bd_run "$1"; [ "$BD_FAILED" = "$2" ]; }
bd_cells() { # <decides list> -- the 0/1 cells of BIND1..BIND3 for an mrow
  local _a _o=""
  for _a in BIND1 BIND2 BIND3; do case ",$BD_FAILED," in *",$_a,"*) _o="$_o $_a=1" ;; *) _o="$_o $_a=0" ;; esac; done
  printf '%s' "$_o"
}

if [ "$B_BIND0" != 1 ]; then
  bad "FIXTURE BROKEN: BINDm-* and BINDQ* not scored -- the unmutated probe copies did not pass (BIND0), so every mutant cell would read the base failing"
else
t="$(bd_tree strip)" &&bd_mut "$t" "$MB" '/^[[:space:]]*SAME\) refuse "/ { i = index($0, PFX); if (i) $0 = substr($0, 1, i - 1) substr($0, i + length(PFX)) } { print }' \
  && { bd_score "$t" BIND1; _r=$?; mrow BINDm-strip $(bd_cells); [ "$_r" = 0 ]; } \
  && mutant_killed "$B_BIND0" BINDm-strip "BINDm-strip the merge copy's SAME line without \${REC_PREFIX}: KILLED by [BIND1], BIND2 and BIND3 stay green" \
  || bad "BINDm-strip: SURVIVED, entangled or not applied (failed=${BD_FAILED:-none}, want BIND1)"

t="$(bd_tree prefix)" && bd_mut "$t" "$JB" '/^[[:space:]]*SAME\) refuse "/ { i = index($0, "wrote ${_c}"); if (i) $0 = substr($0, 1, i + 5) PFX substr($0, i + 6) } { print }' \
  && { bd_score "$t" BIND1; _r=$?; mrow BINDm-prefix $(bd_cells); [ "$_r" = 0 ]; } \
  && mutant_killed "$B_BIND0" BINDm-prefix "BINDm-prefix the join copy's SAME line given \${REC_PREFIX}: KILLED by [BIND1], BIND2 and BIND3 stay green" \
  || bad "BINDm-prefix: SURVIVED, entangled or not applied (failed=${BD_FAILED:-none}, want BIND1)"

t="$(bd_tree same)" && bd_mut "$t" "$JB" '/^[[:space:]]*SAME\) refuse "/ { sub(/NEW dispatch/, "fresh dispatch") } { print }' \
  && { bd_score "$t" BIND1; _r=$?; mrow BINDm-same $(bd_cells); [ "$_r" = 0 ]; } \
  && mutant_killed "$B_BIND0" BINDm-same "BINDm-same one word of the join copy's SAME text changed: KILLED by [BIND1], BIND2 and BIND3 stay green" \
  || bad "BINDm-same: SURVIVED, entangled or not applied (failed=${BD_FAILED:-none}, want BIND1)"

t="$(bd_tree dw)" && bd_mut "$t" "$JB" 'index($0, "refuse \"DOUBLE-WRITE ") { sub(/stop directive not honored/, "stop directive ignored") } { print }' \
  && { bd_score "$t" BIND2; _r=$?; mrow BINDm-dw $(bd_cells); [ "$_r" = 0 ]; } \
  && mutant_killed "$B_BIND0" BINDm-dw "BINDm-dw one word of the join copy's shared DOUBLE-WRITE clause changed: KILLED by [BIND2], BIND1 and BIND3 stay green" \
  || bad "BINDm-dw: SURVIVED, entangled or not applied (failed=${BD_FAILED:-none}, want BIND2)"

t="$(bd_tree dwdel)" && bd_mut "$t" "$JB" 'index($0, "refuse \"DOUBLE-WRITE ") { next } { print }' \
  && { bd_score "$t" BIND2; _r=$?; mrow BINDm-dwdel $(bd_cells); [ "$_r" = 0 ]; } \
  && mutant_killed "$B_BIND0" BINDm-dwdel "BINDm-dwdel the join copy's DOUBLE-WRITE line deleted: KILLED by [BIND2], BIND1 and BIND3 stay green" \
  || bad "BINDm-dwdel: SURVIVED, entangled or not applied (failed=${BD_FAILED:-none}, want BIND2)"

t="$(bd_tree third)" && printf '%s\n' '#!/usr/bin/env bash' "  refuse \"--rerun x: y wrote z $BD_P1 w, after it\"" > "$t/core/scripts/x.sh" \
  && { bd_score "$t" BIND3; _r=$?; mrow BINDm-third $(bd_cells); [ "$_r" = 0 ]; } \
  && mutant_killed "$B_BIND0" BINDm-third "BINDm-third a third carrier seeded as a scripts-dir x.sh: KILLED by [BIND3], BIND1 and BIND2 stay green" \
  || bad "BINDm-third: SURVIVED, entangled or not applied (failed=${BD_FAILED:-none}, want BIND3)"

# the near-misses: each must leave every arm green
t="$(bd_tree q1)" && bd_mut "$t" "$JB" '/^[[:space:]]*SAME\) refuse "/ || index($0, "refuse \"DOUBLE-WRITE ") { print "        # a near-miss comment inside the case arm"; $0 = "    " $0 } { print }' \
  && bd_run "$t" && [ -z "$BD_FAILED" ] \
  && ok "BINDQ1: a comment line inserted in the join copy's case arm and its SAME and DW lines re-indented -> every bind arm stays green" \
  || bad "BINDQ1: a whitespace and comment edit in the case arm fired a bind arm (failed=${BD_FAILED:-none}): $(tr '\n' ' ' < "$BD_OUT")"

# No fixture-dir near-miss is probed: the corpus is the two non-recursive globs over the scripts and hooks dirs, so a
# fixtures path is unreachable by construction and no exclusion exists to remove; a probe seeding one stays quiet
# whatever the code does and cannot fail.
t="$(bd_tree q3)" && printf '%s\n' '#!/usr/bin/env bash' "  # quoting the refusal: $BD_P1, and $BD_P2" > "$t/core/scripts/x.sh" \
  && bd_run "$t" && [ -z "$BD_FAILED" ] && grep -q '^PASS BIND3 over 3 file' "$BD_OUT" \
  && ok "BINDQ3: both phrases on a comment line of a scripts-dir x.sh, scanned (3 files) -> BIND3 stays green" \
  || bad "BINDQ3: a comment-line carrier fired BIND3, or x.sh was not scanned (failed=${BD_FAILED:-none}): $(tr '\n' ' ' < "$BD_OUT")"
fi

t="$(mktemp -d "$WORK/bind-floor.XXXXXX")" && mkdir -p "$t/s" "$t/h" \
  && bd_carriers "$t/s" "$t/h" "$MB" "$JB" > "$BD_OUT" && grep -q '^FAIL BIND3 REFUSED: the corpus glob' "$BD_OUT" \
  && ok "BINDF: an empty scripts and hooks dir -> BIND3 REFUSES, never a silent pass" \
  || bad "BINDF: an empty corpus did not refuse: $(tr '\n' ' ' < "$BD_OUT")"

t="$(bd_tree q4)" && : > "$t/core/hooks/empty.sh" \
  && bd_run "$t" && [ -z "$BD_FAILED" ] && grep -q '^PASS BIND3 over 3 file' "$BD_OUT" \
  && ok "BINDQ4: an empty .sh in the scanned hooks dir, counted (3 files) -> BIND3 stays green" \
  || bad "BINDQ4: an empty .sh fired BIND3 or was not counted (failed=${BD_FAILED:-none}): $(tr '\n' ' ' < "$BD_OUT")"

if [ "$(id -u)" = 0 ]; then echo "SKIP-NOTE BINDF2: running as root, chmod 000 does not make a file unopenable; the unopenable-file probe is not seeded"
else
t="$(bd_tree f2)" && : > "$t/core/hooks/locked.sh" && printf 'x\n' > "$t/core/hooks/locked.sh" && chmod 000 "$t/core/hooks/locked.sh" \
  && bd_run "$t" && grep -q '^FAIL BIND3 REFUSED: awk read 2 of the 3 listed' "$BD_OUT" \
  && ok "BINDF2: an unopenable listed .sh -> BIND3 REFUSES (awk read 2 of the 3), never a silent pass" \
  || bad "BINDF2: an unopenable listed file did not refuse: $(tr '\n' ' ' < "$BD_OUT")"
fi

# ------------------------------------------------------------------------- the real check
bd_check "$MERGE" "$JOIN" "$SRCDIR" "$HOOKDIR"
while read -r _v _arm _rest; do
  case "$_v $_arm" in
    "PASS BIND1") ok "BIND1: the join's SAME refusal is the merge's, byte for byte, but for the merge's one \${REC_PREFIX} ($JOIN, $MERGE)" ;;
    "PASS BIND2") ok "BIND2: the join's DOUBLE-WRITE refusal is the merge's through the declared differences only" ;;
    "PASS BIND3") ok "BIND3: no third carrier of either refusal phrase $_rest under $SRCDIR and $HOOKDIR (fixtures excluded)" ;;
    "FAIL "*) bad "$_arm: $_rest" ;;
    *) bad "BIND: FIXTURE BROKEN -- unreadable verdict line [$_v $_arm $_rest]" ;;
  esac
done < "$BD_OUT"
[ "$(grep -c '^PASS \|^FAIL ' "$BD_OUT")" = 3 ] || bad "BIND: FIXTURE BROKEN -- the real check printed $(grep -c . "$BD_OUT") verdict line(s), want 3"

if [ "$MATRIX" = 1 ]; then echo "  (matrix mode, unit-bind.sh: $N_MROWS MATRIX row(s) printed)"
elif [ "$N_MROWS" -eq 0 ]; then ok "PLAIN-BIND: a plain run of unit-bind.sh printed no matrix-only cell"
else bad "PLAIN-BIND: a plain run of unit-bind.sh printed $N_MROWS matrix row(s)"; fi
echo "$NAME: $fails failure(s)"
[ "$fails" -eq 0 ]
