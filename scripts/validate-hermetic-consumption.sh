#!/usr/bin/env bash
# validate-hermetic-consumption.sh -- a SHIPPED fixture that marks an input REQUIRED (`!` in its
# inputs.decl) must emit that input's `HERMETIC-CONSUMED` sentinel in the CONSUMER layout too,
# not only in the distribution layout.
#
# THE DEFECT THIS BINDS. `core/scripts/hermetic-run.sh` requires, for every `!` input, a
# whole-line `HERMETIC-CONSUMED <path>` in the fixture's output, the path spelled as declared or
# as the consumer path it maps to. A fixture that resolves its subject in BOTH layouts through an
# if/elif chain, and echoes the sentinel only in the `core/` branch, passes every run in this
# repo -- the distribution layout is the only one this repo's suite ever executes -- and reports
# `required_missing=1` and rc 1 on every consumer. Two shipped fixtures did exactly that from
# 0.763.0, and nothing here could fail on it, because no gate in this repo runs a fixture in the
# installed layout.
#
# THE RULE, per `!` input whose consumer path differs from its declared path (as
# `core/scripts/core-paths.sh --map` answers it). A chain is JUDGED for that input when it is an
# if/elif chain that the input's own literal sentinel belongs to -- emitted inside one of its
# branches, or at if-depth 0 after its `fi` -- and one of its branch TESTS names the consumer
# path as the operand of a file test (`-f`, `-d`, `-e`, `-r`, `-s`, `-x`). Every such branch must
# then EITHER
#   (a) emit, at any depth inside it, a literal `HERMETIC-CONSUMED <consumer path | declared
#       path>`, the token compared WHOLE (with or without one trailing `/`), or
#   (b) be followed by a literal sentinel naming the input at if-depth 0 AFTER the chain's `fi`
#       (the declared spelling, which hermetic-run.sh accepts in both layouts).
# It keys on the `!` INPUT, never on "the core branch emitted": a chain resolving an input that
# is not marked `!` is never examined.
#
# REACH -- A CLEAN RESULT IS A FLOOR, NOT A PROOF. The grammar is line-oriented shell, and the
# summary line counts every input it could NOT score, so the floor's depth is printed, not
# assumed. Measured over the 157 shipped `!` fixtures (240 `!` inputs) at the tip that fixed
# the two offenders:
#   layout-independent=1   the declared path IS the consumer path, so no branch to judge;
#   variable-sentinel=113  run.sh names the input in no literal sentinel and emits at least one
#                          sentinel through a variable or a printf `%s` -- outside the grammar;
#   elsewhere=26           run.sh carries no sentinel for the input at all: it is emitted from a
#                          sibling shard's run.sh or a sourced file -- outside the grammar;
#   no-installed-branch=90 a literal sentinel, but no chain it belongs to tests the consumer path
#                          (a candidate loop, a single walk, a dist-only resolution) -- not scored;
#   scored=10, flagged=0.
# So the scan judges 10 of 240 inputs. It is exactly the shape that shipped broken twice, and it
# is a floor for everything else. A sentinel inside a heredoc body is skipped (it is text a
# fixture writes, not text it emits); a test continued across lines with `\` is read as its
# first line only.
#
# HOW THE FALSE-POSITIVE SET REACHED ZERO. Each narrowing below was measured by reverting it in a
# copy and scanning the same tip corpus, self-probe off:
#   - with no own-sentinel restriction (every chain whose test names the consumer path judged):
#     flagged 2 -- `process-rule-pins` (a layout-detecting chain whose sentinel is emitted later
#     through a variable) and `write-format-steering-multiformat` (a resolver inside a helper
#     that seeds worlds, the sentinel emitted unconditionally at the top). Neither chain is where
#     the input is consumed, so a chain is judged only when the input's own sentinel belongs to it;
#   - with a test naming the path ANYWHERE, not as a file-test operand: flagged 1 more,
#     `emit-report-refusal`, whose `grep -qF '...scripts/ai-dlc/validate-hook-registration.sh'`
#     names the path as a STRING it looks for; an earlier cut without the operand rule also
#     flagged `prepush-worktree-env-scrub` on a `cmp -s` naming `.githooks/pre-push`;
#   - keyed on EVERY decl line instead of `!` lines: flagged 0 here -- structurally, because no
#     unmarked input on today's corpus has the shape -- so the self-probe's `e-non-bang` seed (a
#     fixed `!` input beside an unmarked input echoed in its core branch only) is the only thing
#     that can tell the two apart, and the fixture's widening mutant asserts that it does;
#   - the sentinel token compared as a PREFIX: flagged 0 here, and accepts the `.bak` near-miss,
#     so it is compared whole and the self-probe's `d-bak` seed holds it.
# No input was exempted by name, and none is.
#
# WHY A STANDALONE SCRIPT AND NOT AN ARM IN THE ENFORCEMENT MAP. That validator is invoked by
# the suite's slowest fixtures and is held to `FORK_BUDGET`; this scan forks a fixed handful of
# times regardless of corpus size, and runs only from its own fixture,
# `core/fixtures/hermetic-consumption/`, which is the only thing that runs it at a push. It is
# distribution-only: its corpus is `core/fixtures/`, which no consumer holds.
#
# EVERY RUN SELF-PROBES FIRST, in both directions, under a mktemp tree: four seeded offenders
# (an echo in the dist branch only, a `.bak` near-miss in the consumer branch, an echo at the top
# of the file above the resolution, an echo in the override branch only) must each be flagged;
# three near-misses (the consumer-branch echo, the declared spelling after `fi`, and a fixed `!`
# input beside an unmarked input whose chain echoes in its core branch only) must stay quiet;
# and a `.dist-only` seed must not be scanned at all. A probe that disagrees refuses the corpus.
#
# Usage: validate-hermetic-consumption.sh [--quiet]
# Exit:  0 = clean, 1 = at least one finding, 2 = usage, environment, or a refused self-probe.
set -uo pipefail
export LC_ALL=C

QUIET=0
case "${1:-}" in
  "") : ;;
  --quiet) QUIET=1 ;;
  *) echo "usage: $(basename "$0") [--quiet]" >&2; exit 2 ;;
esac

# Walk UP for the marker, never count `..` hops, so this answers identically from the repo
# root, from a subdirectory, and from a fixture sandbox that copied it.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
while [ "$ROOT" != "/" ] && [ ! -f "$ROOT/VERSION" ]; do ROOT="$(dirname "$ROOT")"; done
[ -f "$ROOT/VERSION" ] || { echo "validate-hermetic-consumption: no VERSION marker above $0" >&2; exit 2; }
CP="$ROOT/core/scripts/core-paths.sh"
[ -f "$CP" ] || { echo "validate-hermetic-consumption: core/scripts/core-paths.sh not found under $ROOT" >&2; exit 2; }
[ -d "$ROOT/core/fixtures" ] || { echo "validate-hermetic-consumption: no core/fixtures under $ROOT" >&2; exit 2; }

say() { [ "$QUIET" = "1" ] || printf '%s\n' "$*"; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/hermetic-consumption.XXXXXX")" || { echo "validate-hermetic-consumption: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

# Which inputs.decl lines are keyed. Only `!` (REQUIRED) lines: an unmarked input owes no sentinel.
BANG_RE='^!'

# The judging program. Argument 1 is the fixture<TAB>declared<TAB>consumer triples file; every
# later argument is one fixture run.sh. Writes FLAG rows to FLAGS and one summary row to SUMMARY.
# shellcheck disable=SC2016
JUDGE='
function same(tok, p) { return tok == p || tok == p "/" }
function names(t, p,    i, off, pre, post, head) {
  off = 0
  while ((i = index(substr(t, off + 1), p)) > 0) {
    i += off
    pre = (i > 1) ? substr(t, i - 1, 1) : ""
    post = substr(t, i + length(p), 1)
    head = substr(t, 1, i - 1)
    sub(/[^[:space:]]*$/, "", head)
    if (pre !~ /[A-Za-z0-9_.-]/ && post !~ /[A-Za-z0-9_.-]/ && head ~ /(^|[[:space:]])-[defrsx][[:space:]]+$/) return 1
    off = i
  }
  return 0
}
function reset() { dep = 0; nch = 0; ns = 0; hd = ""; hdtab = 0; anyvar = 0 }
function judge(   k, d, m, j, c, b, lit, ok, hasbr, bad, local_) {
  for (k = 1; k <= nt[cur]; k++) {
    d = td[cur, k]; m = tm[cur, k]; sub(/\/$/, "", d); sub(/\/$/, "", m)
    ninputs++
    if (d == m) { nsame++; continue }
    lit = 0
    for (j = 1; j <= ns; j++) if (same(stok[j], d) || same(stok[j], m)) lit = 1
    if (!lit) { if (anyvar) nvar++; else nelse++; continue }
    bad = 0; hasbr = 0
    for (c = 1; c <= nch; c++) {
      local_ = 0
      for (j = 1; j <= ns; j++) if (same(stok[j], d) || same(stok[j], m)) {
        if (index(senc[j], " " c ":") > 0) local_ = 1
        if (sdep[j] == 0 && cend[c] > 0 && sline[j] > cend[c]) local_ = 1
      }
      if (!local_) continue
      for (b = 1; b <= nb[c]; b++) if (names(tt[c, b], m)) {
        hasbr = 1; ok = 0
        for (j = 1; j <= ns; j++) {
          if (!(same(stok[j], d) || same(stok[j], m))) continue
          if (index(senc[j], " " c ":" b " ") > 0) ok = 1
          if (sdep[j] == 0 && cend[c] > 0 && sline[j] > cend[c]) ok = 1
        }
        if (!ok) bad = 1
      }
    }
    if (!hasbr) { nnobr++; continue }
    nscored++
    if (bad) { nflag++; printf "%s\t%s\t%s\n", cur, td[cur, k], tm[cur, k] > FLAGS }
  }
}
NR == FNR { nt[$1]++; td[$1, nt[$1]] = $2; tm[$1, nt[$1]] = $3; next }
FNR == 1 { if (cur != "") judge(); cur = FILENAME; sub(/\/run\.sh$/, "", cur); opened++; reset() }
{
  line = $0
  if (hd != "") { x = line; if (hdtab) sub(/^\t+/, "", x); if (x == hd) hd = ""; next }
  if (line ~ /^[[:space:]]*#/) next
  if (match(line, HRE) && substr(line, RSTART - 1, 1) != "<") {
    h = substr(line, RSTART, RLENGTH); hdtab = (h ~ /^<<-/)
    sub(/^<<-?[[:space:]]*/, "", h); gsub(QC, "", h); hd = h
  }
  isif = 0
  if (line ~ /^[[:space:]]*if[[:space:]!]/) {
    nch++; c = nch; stk[++dep] = c; nb[c] = 1; tt[c, 1] = line; cend[c] = 0; isif = 1
  } else if (dep > 0 && line ~ /^[[:space:]]*elif[[:space:]]/) {
    c = stk[dep]; nb[c]++; tt[c, nb[c]] = line
  } else if (dep > 0 && line ~ /^[[:space:]]*else([[:space:];]|$)/) {
    c = stk[dep]; nb[c]++; tt[c, nb[c]] = ""
  }
  if (line ~ /HERMETIC-CONSUMED/ && line ~ /(echo|printf)[[:space:]]/) {
    s = line; sub(/.*HERMETIC-CONSUMED[[:space:]]+/, "", s); sub(TEND, "", s)
    if (s ~ /[$%`]/ || s == "") { anyvar = 1 } else {
      ns++; stok[ns] = s; sdep[ns] = dep; sline[ns] = FNR; e = " "
      for (i = 1; i <= dep; i++) e = e stk[i] ":" nb[stk[i]] " "
      senc[ns] = e
    }
  }
  if (dep > 0 && (line ~ /^[[:space:]]*fi([^A-Za-z0-9_]|$)/ || (isif && line ~ /[;[:space:]]fi[[:space:]]*([;|&>]|$)/))) {
    cend[stk[dep]] = FNR; dep--
  }
}
END {
  if (cur != "") judge()
  printf "%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\n", opened, ninputs, nsame, nvar, nelse, nnobr, nscored, nflag > SUMMARY
}'

# scan <fixtures dir> <out dir> -- writes <out>/flags and <out>/summary. Returns 2 on a refusal.
scan() {
  local fx="$1" o="$2" d n_decl=0 n_run=0 opened=""
  mkdir -p "$o" || return 2
  : > "$o/flags"; : > "$o/decls"
  for d in "$fx"/*/; do
    d="${d%/}"
    [ -f "$d/.dist-only" ] && continue
    [ -f "$d/inputs.decl" ] || continue
    printf '%s\n' "$d/inputs.decl" >> "$o/decls"; n_decl=$((n_decl + 1))
  done
  [ "$n_decl" -gt 0 ] || { echo "validate-hermetic-consumption: no shipped fixture under $fx declares inputs -- an empty corpus is not a clean one" >&2; return 2; }
  local decl_args=()
  while IFS= read -r d; do decl_args+=("$d"); done < "$o/decls"
  awk -v re="$BANG_RE" -v OPENED="$o/decls.opened" '
    FNR == 1 { opened++ }
    $0 ~ re { p = $0; sub(/^!/, "", p); sub(/[[:space:]]+$/, "", p); if (p == "") next
              f = FILENAME; sub(/\/inputs\.decl$/, "", f); print f "\t" p }
    END { print opened + 0 > OPENED }' "${decl_args[@]}" > "$o/bang" || { echo "validate-hermetic-consumption: reading inputs.decl failed" >&2; return 2; }
  opened="$(cat "$o/decls.opened")"
  [ "$opened" = "$n_decl" ] || { echo "validate-hermetic-consumption: listed $n_decl inputs.decl, opened $opened -- an unopened file reads as an empty one" >&2; return 2; }
  [ -s "$o/bang" ] || { echo "validate-hermetic-consumption: no shipped fixture under $fx marks an input REQUIRED -- zero scanned is a refusal, not a pass" >&2; return 2; }
  cut -f2 "$o/bang" > "$o/bang.paths"
  bash "$CP" --map < "$o/bang.paths" > "$o/bang.mapped" || { echo "validate-hermetic-consumption: core-paths.sh --map refused a declared path (above) -- that input has no consumer location to judge" >&2; return 2; }
  [ "$(wc -l < "$o/bang.paths")" = "$(wc -l < "$o/bang.mapped")" ] || { echo "validate-hermetic-consumption: core-paths.sh --map answered a different number of lines than it was asked" >&2; return 2; }
  paste "$o/bang" "$o/bang.mapped" > "$o/triples"
  cut -f1 "$o/bang" | uniq > "$o/fixtures"
  local run_args=()
  while IFS= read -r d; do
    [ -f "$d/run.sh" ] || { echo "validate-hermetic-consumption: $d marks an input REQUIRED and has no run.sh" >&2; return 2; }
    run_args+=("$d/run.sh"); n_run=$((n_run + 1))
  done < "$o/fixtures"
  awk -v FLAGS="$o/flags" -v SUMMARY="$o/summary" -v QC="[\"']" \
      -v HRE="<<-?[[:space:]]*[\"']?[A-Za-z_][A-Za-z0-9_]*" -v TEND="[\"'[:space:];)].*\$" \
      "$JUDGE" "$o/triples" "${run_args[@]}" || { echo "validate-hermetic-consumption: the judging pass failed" >&2; return 2; }
  [ "$(cut -f1 "$o/summary")" = "$n_run" ] || { echo "validate-hermetic-consumption: listed $n_run run.sh, opened $(cut -f1 "$o/summary")" >&2; return 2; }
  return 0
}

# probe_seed <fixtures dir> <name> <variant> -- one seeded fixture, shaped like the real producer
# (consumer-machinery-inventory's resolver: an override branch, a core branch, a consumer branch).
probe_seed() {
  local d="$1/$2" v="$3" ce="" ue="" oe="" top="" after=""
  mkdir -p "$d" || return 2
  printf '%s\n' '!core/scripts/probe-subject.sh' 'core/fixtures/lib/' > "$d/inputs.decl"
  ce='  echo "HERMETIC-CONSUMED core/scripts/probe-subject.sh"'
  case "$v" in
    fix-a|non-bang) ue='  echo "HERMETIC-CONSUMED scripts/ai-dlc/probe-subject.sh"' ;;
    dist-only)      : ;;
    fix-b)          ce=""; after='echo "HERMETIC-CONSUMED core/scripts/probe-subject.sh"' ;;
    bak)            ue='  echo "HERMETIC-CONSUMED scripts/ai-dlc/probe-subject.sh.bak"' ;;
    top)            top='echo "HERMETIC-CONSUMED scripts/ai-dlc/probe-subject.sh"' ;;
    override)       ce=""; oe='  echo "HERMETIC-CONSUMED core/scripts/probe-subject.sh"' ;;
    *) return 2 ;;
  esac
  {
    printf '%s\n' '#!/usr/bin/env bash' 'set -uo pipefail' 'ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"'
    [ -z "$top" ] || printf '%s\n' "$top"
    printf '%s\n' 'if [ -n "${AI_DLC_PROBE_SUBJECT:-}" ] && [ -f "${AI_DLC_PROBE_SUBJECT}" ]; then' '  VAL="${AI_DLC_PROBE_SUBJECT}"'
    [ -z "$oe" ] || printf '%s\n' "$oe"
    printf '%s\n' 'elif [ -n "$ROOT" ] && [ -f "$ROOT/core/scripts/probe-subject.sh" ]; then' '  VAL="$ROOT/core/scripts/probe-subject.sh"'
    [ -z "$ce" ] || printf '%s\n' "$ce"
    printf '%s\n' 'elif [ -n "$ROOT" ] && [ -f "$ROOT/scripts/ai-dlc/probe-subject.sh" ]; then' '  VAL="$ROOT/scripts/ai-dlc/probe-subject.sh"'
    [ -z "$ue" ] || printf '%s\n' "$ue"
    printf '%s\n' 'else' '  echo "FIXTURE ERROR: probe-subject.sh not found in either layout" >&2; exit 2' 'fi'
    [ -z "$after" ] || printf '%s\n' "$after"
    if [ "$v" = "non-bang" ]; then
      printf '%s\n' 'cat > "$ROOT/probe.out" <<'"'"'EOF'"'"'' 'if [ -f x ]; then' 'fi' 'EOF'
      printf '%s\n' 'if [ -f "$ROOT/core/skills/probe/notes.md" ]; then' '  NOTES="$ROOT/core/skills/probe/notes.md"' \
        '  echo "HERMETIC-CONSUMED core/skills/probe/notes.md"' \
        'elif [ -f "$ROOT/.claude/skills/probe/notes.md" ]; then' '  NOTES="$ROOT/.claude/skills/probe/notes.md"' 'fi'
    fi
    printf '%s\n' 'bash "$VAL"'
  } > "$d/run.sh"
  [ "$v" != "non-bang" ] || printf '%s\n' 'core/skills/probe/notes.md' >> "$d/inputs.decl"
  return 0
}

# The seeds, in an order where a quiet seed comes first and the offenders are not adjacent, so a
# scan that judged only the first fixture cannot pass. `h-dist-marked` carries a dist-only echo
# AND a `.dist-only` marker: it must not be scanned, so `scanned` must read 7, not 8.
PROBE_FIRE="b-dist-only d-bak f-top g-override"
PROBE_QUIET="a-fix-a c-fix-b e-non-bang"
self_probe() {
  local fx="$WORK/probe/fx" o="$WORK/probe/out" bad=0 n s
  for s in a-fix-a:fix-a b-dist-only:dist-only c-fix-b:fix-b d-bak:bak e-non-bang:non-bang f-top:top g-override:override h-dist-marked:dist-only; do
    probe_seed "$fx" "${s%%:*}" "${s#*:}" || { echo "validate-hermetic-consumption: self-probe could not seed ${s%%:*}" >&2; return 2; }
  done
  printf '%s\n' 'seeded: its subject is not present on a consumer' > "$fx/h-dist-marked/.dist-only"
  mkdir -p "$fx/i-no-decl" && printf '%s\n' 'echo "HERMETIC-CONSUMED core/scripts/probe-subject.sh"' > "$fx/i-no-decl/run.sh"
  scan "$fx" "$o" || { echo "validate-hermetic-consumption: self-probe: the scan refused its own seeded tree" >&2; return 2; }
  n="$(cut -f1 "$o/summary")"
  [ "$n" = "7" ] || { echo "validate-hermetic-consumption: self-probe: scanned $n seeded fixtures, expected 7 -- the corpus walk is not the one this probe seeded" >&2; bad=1; }
  for s in $PROBE_FIRE; do
    grep -q "^$fx/$s	" "$o/flags" || { echo "validate-hermetic-consumption: self-probe: seeded offender $s was NOT flagged" >&2; bad=1; }
  done
  for s in $PROBE_QUIET; do
    grep -q "^$fx/$s	" "$o/flags" && { echo "validate-hermetic-consumption: self-probe: seeded near-miss $s WAS flagged" >&2; bad=1; }
  done
  [ "$bad" = "0" ] || return 2
  say "self-probe: ok -- 4 seeded offenders flagged, 3 near-misses quiet, 1 .dist-only seed not scanned"
  return 0
}

self_probe || { echo "validate-hermetic-consumption: REFUSED -- the self-probe disagrees with its seeds, so a clean corpus result would mean nothing" >&2; exit 2; }

scan "$ROOT/core/fixtures" "$WORK/corpus" || exit 2
IFS="$(printf '\t')" read -r c_open c_inputs c_same c_var c_else c_nobr c_scored c_flag < "$WORK/corpus/summary"
while IFS="$(printf '\t')" read -r f d m; do
  printf 'FAIL: %s: REQUIRED input %s is consumed only in the distribution layout -- no branch testing %s emits HERMETIC-CONSUMED %s (or %s), and no sentinel follows the chain'"'"'s fi, so hermetic-run.sh reports required_missing=1 on every consumer\n' \
    "${f#"$ROOT"/}" "$d" "$m" "$m" "$d" >&2
done < "$WORK/corpus/flags"
say "hermetic-consumption: scanned=$c_open required-inputs=$c_inputs layout-independent=$c_same variable-sentinel=$c_var elsewhere=$c_else no-installed-branch=$c_nobr scored=$c_scored flagged=$c_flag"
[ "$c_flag" = "0" ] || exit 1
exit 0
