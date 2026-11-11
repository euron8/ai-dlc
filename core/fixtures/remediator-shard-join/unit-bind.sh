#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
# remediator-shard-join/unit-bind.sh -- BIND1-BIND2: the join's SAME and DOUBLE-WRITE refusal text bound to the
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
# OWNERSHIP SPLIT: BIND1/BIND2 own "exactly one per subject" (their extraction refuses zero or two). "No THIRD
# copy of either refusal in any other core script or hook" is BIND3, which lives in the distribution-only fixture
# finding-grammar-binding: it reads the whole core/scripts/ and core/hooks/ directories, which this fixture does
# not declare, so inside hermetic-run's sandbox it could only ever have counted the declared files (BL-967).
#
# SELF-PROBES run BEFORE the real check, on mktemp copies of the two scripts, never on the real files. BIND0 asserts
# the unmutated copies pass (the base every kill is gated on). Each mutant must fail its own arm and only it:
#   BINDm-strip   the merge copy's SAME line loses `${REC_PREFIX}`       -> BIND1
#   BINDm-prefix  the join copy's SAME line gains `${REC_PREFIX}`        -> BIND1
#   BINDm-same    one word of the join copy's SAME text changed          -> BIND1
#   BINDm-dw      one word of the join copy's shared DW clause changed   -> BIND2
#   BINDm-dwdel   the join copy's DW line deleted                        -> BIND2
# and the near-miss must stay QUIET:
#   BINDQ1  a comment line inserted in the case arm and the SAME and DW lines re-indented (never the prefix).
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
[ -f "$MERGE" ] || { echo "FIXTURE BROKEN: $NAME: $MERGE is not beside the join; nothing was asserted" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/scripts/merge-adversarial-shards.sh"

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

# bd_check <merge> <join> -- both arms into $BD_OUT; the failing arms' codes, comma separated, in BD_FAILED (empty
# when both passed).
bd_check() {
  bd_pins "$1" "$2" > "$BD_OUT"
  BD_FAILED="$(awk '$1 == "FAIL" { printf "%s%s", s, $2; s = "," }' "$BD_OUT")"
}
BD_OUT="$WORK/bind.out"

# ------------------------------------------------------------------------- the self-probes, before the real check
bd_tree() { # <name> -- a fresh probe tree holding copies of the two real scripts; prints its root
  local _t
  _t="$(mktemp -d "$WORK/bind-$1.XXXXXX")" || return 1
  mkdir -p "$_t/core/scripts" || return 1
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
bd_run() { bd_check "$1/core/scripts/$MB" "$1/core/scripts/$JB"; }

B_BIND0=0
t0="$(bd_tree base)" || { echo "FIXTURE BROKEN: $NAME: no probe tree" >&2; exit 2; }
bd_run "$t0"
if [ -z "$BD_FAILED" ] && [ "$(grep -c '^PASS ' "$BD_OUT")" = 2 ]; then ok "BIND0: the unmutated probe copies of the merge and the join pass BIND1 and BIND2"; B_BIND0=1
else bad "BIND0: the unmutated probe copies did not pass every bind arm (failed=$BD_FAILED): $(tr '\n' ' ' < "$BD_OUT")"; fi

# bd_score <tree> <want failing codes> -- 0 when exactly the wanted arms failed
bd_score() { bd_run "$1"; [ "$BD_FAILED" = "$2" ]; }
bd_cells() { # <decides list> -- the 0/1 cells of BIND1..BIND2 for an mrow
  local _a _o=""
  for _a in BIND1 BIND2; do case ",$BD_FAILED," in *",$_a,"*) _o="$_o $_a=1" ;; *) _o="$_o $_a=0" ;; esac; done
  printf '%s' "$_o"
}

if [ "$B_BIND0" != 1 ]; then
  bad "FIXTURE BROKEN: BINDm-* and BINDQ1 not scored -- the unmutated probe copies did not pass (BIND0), so every mutant cell would read the base failing"
else
t="$(bd_tree strip)" &&bd_mut "$t" "$MB" '/^[[:space:]]*SAME\) refuse "/ { i = index($0, PFX); if (i) $0 = substr($0, 1, i - 1) substr($0, i + length(PFX)) } { print }' \
  && { bd_score "$t" BIND1; _r=$?; mrow BINDm-strip $(bd_cells); [ "$_r" = 0 ]; } \
  && mutant_killed "$B_BIND0" BINDm-strip "BINDm-strip the merge copy's SAME line without \${REC_PREFIX}: KILLED by [BIND1], BIND2 stays green" \
  || bad "BINDm-strip: SURVIVED, entangled or not applied (failed=${BD_FAILED:-none}, want BIND1)"

t="$(bd_tree prefix)" && bd_mut "$t" "$JB" '/^[[:space:]]*SAME\) refuse "/ { i = index($0, "wrote ${_c}"); if (i) $0 = substr($0, 1, i + 5) PFX substr($0, i + 6) } { print }' \
  && { bd_score "$t" BIND1; _r=$?; mrow BINDm-prefix $(bd_cells); [ "$_r" = 0 ]; } \
  && mutant_killed "$B_BIND0" BINDm-prefix "BINDm-prefix the join copy's SAME line given \${REC_PREFIX}: KILLED by [BIND1], BIND2 stays green" \
  || bad "BINDm-prefix: SURVIVED, entangled or not applied (failed=${BD_FAILED:-none}, want BIND1)"

t="$(bd_tree same)" && bd_mut "$t" "$JB" '/^[[:space:]]*SAME\) refuse "/ { sub(/NEW dispatch/, "fresh dispatch") } { print }' \
  && { bd_score "$t" BIND1; _r=$?; mrow BINDm-same $(bd_cells); [ "$_r" = 0 ]; } \
  && mutant_killed "$B_BIND0" BINDm-same "BINDm-same one word of the join copy's SAME text changed: KILLED by [BIND1], BIND2 stays green" \
  || bad "BINDm-same: SURVIVED, entangled or not applied (failed=${BD_FAILED:-none}, want BIND1)"

t="$(bd_tree dw)" && bd_mut "$t" "$JB" 'index($0, "refuse \"DOUBLE-WRITE ") { sub(/stop directive not honored/, "stop directive ignored") } { print }' \
  && { bd_score "$t" BIND2; _r=$?; mrow BINDm-dw $(bd_cells); [ "$_r" = 0 ]; } \
  && mutant_killed "$B_BIND0" BINDm-dw "BINDm-dw one word of the join copy's shared DOUBLE-WRITE clause changed: KILLED by [BIND2], BIND1 stays green" \
  || bad "BINDm-dw: SURVIVED, entangled or not applied (failed=${BD_FAILED:-none}, want BIND2)"

t="$(bd_tree dwdel)" && bd_mut "$t" "$JB" 'index($0, "refuse \"DOUBLE-WRITE ") { next } { print }' \
  && { bd_score "$t" BIND2; _r=$?; mrow BINDm-dwdel $(bd_cells); [ "$_r" = 0 ]; } \
  && mutant_killed "$B_BIND0" BINDm-dwdel "BINDm-dwdel the join copy's DOUBLE-WRITE line deleted: KILLED by [BIND2], BIND1 stays green" \
  || bad "BINDm-dwdel: SURVIVED, entangled or not applied (failed=${BD_FAILED:-none}, want BIND2)"

# the near-miss: it must leave every arm green
t="$(bd_tree q1)" && bd_mut "$t" "$JB" '/^[[:space:]]*SAME\) refuse "/ || index($0, "refuse \"DOUBLE-WRITE ") { print "        # a near-miss comment inside the case arm"; $0 = "    " $0 } { print }' \
  && bd_run "$t" && [ -z "$BD_FAILED" ] \
  && ok "BINDQ1: a comment line inserted in the join copy's case arm and its SAME and DW lines re-indented -> every bind arm stays green" \
  || bad "BINDQ1: a whitespace and comment edit in the case arm fired a bind arm (failed=${BD_FAILED:-none}): $(tr '\n' ' ' < "$BD_OUT")"
fi

# ------------------------------------------------------------------------- the real check
bd_check "$MERGE" "$JOIN"
while read -r _v _arm _rest; do
  case "$_v $_arm" in
    "PASS BIND1") ok "BIND1: the join's SAME refusal is the merge's, byte for byte, but for the merge's one \${REC_PREFIX} ($JOIN, $MERGE)" ;;
    "PASS BIND2") ok "BIND2: the join's DOUBLE-WRITE refusal is the merge's through the declared differences only" ;;
    "FAIL "*) bad "$_arm: $_rest" ;;
    *) bad "BIND: FIXTURE BROKEN -- unreadable verdict line [$_v $_arm $_rest]" ;;
  esac
done < "$BD_OUT"
[ "$(grep -c '^PASS \|^FAIL ' "$BD_OUT")" = 2 ] || bad "BIND: FIXTURE BROKEN -- the real check printed $(grep -c . "$BD_OUT") verdict line(s), want 2"

if [ "$MATRIX" = 1 ]; then echo "  (matrix mode, unit-bind.sh: $N_MROWS MATRIX row(s) printed)"
elif [ "$N_MROWS" -eq 0 ]; then ok "PLAIN-BIND: a plain run of unit-bind.sh printed no matrix-only cell"
else bad "PLAIN-BIND: a plain run of unit-bind.sh printed $N_MROWS matrix row(s)"; fi
echo "$NAME: $fails failure(s)"
[ "$fails" -eq 0 ]
