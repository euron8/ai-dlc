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
# WHAT COUNTS AS A SENTINEL -- a line the RUNNER would see, unconditionally. The `echo`/`printf`
# starts its statement (line start, or after `then`/`else`/`do`/`;`/`{`/`(`), so an `&&` or `||`
# before it on the same line disqualifies it: the emission is conditional. A quoted argument ends
# at its OWN closing quote, never at the first space, so `"HERMETIC-CONSUMED p "` is the token
# `p ` and is not `p`. After the argument only stderr redirections may follow before the
# statement ends: `> /dev/null`, `> file`, `| cmd` disqualify it. `>&2`, `1>&2` and `2>&1` are
# ACCEPTED ON PURPOSE, because hermetic-run.sh captures the fixture with `> "$HR_LOG" 2>&1` and
# greps that log, so a sentinel sent to stderr reaches it -- do not tighten past this. A line that
# is disqualified is counted under variable-sentinel (unscorable), never silently dropped.
#
# REACH -- A CLEAN RESULT IS A FLOOR, NOT A PROOF. The grammar is line-oriented shell, and the
# summary line counts every input it could NOT score, so the floor's depth is printed, not
# assumed. Measured over the 157 shipped `!` fixtures (240 `!` inputs) at the tip that fixed
# the two offenders:
#   layout-independent=1   the declared path IS the consumer path, so no branch to judge;
#   variable-sentinel=134  run.sh names the input in no qualifying literal sentinel and carries at
#                          least one sentinel line it cannot score: through a variable, a printf
#                          `%s`, or a conditional `[ -f x ] && echo` form -- outside the grammar;
#   elsewhere=26           run.sh carries no sentinel for the input at all: it is emitted from a
#                          sibling shard's run.sh or a sourced file -- outside the grammar;
#   no-installed-branch=69 a literal sentinel, but no chain it belongs to tests the consumer path
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
#     flagged 1 -- `write-format-steering-multiformat` (a resolver inside a helper that seeds
#     worlds, the sentinel emitted unconditionally at the top). Before the sentinel grammar
#     refused conditional emissions it also flagged `process-rule-pins` (a layout-detecting chain
#     whose sentinel is emitted later, behind `&&`). Neither chain is where the input is consumed,
#     so a chain is judged only when the input's own sentinel belongs to it;
#   - with a test naming the path ANYWHERE, not as a file-test operand: flagged 1,
#     `emit-report-refusal`, whose `grep -qF '...scripts/ai-dlc/validate-hook-registration.sh'`
#     names the path as a STRING it looks for. With BOTH narrowings reverted it flags 3, adding
#     `prepush-worktree-env-scrub` on a `cmp -s` naming `.githooks/pre-push`;
#   - keyed on EVERY decl line instead of `!` lines: flagged 0 here -- structurally, because no
#     unmarked input on today's corpus has the shape -- so the self-probe's `e-non-bang` seed (a
#     fixed `!` input beside an unmarked input echoed in its core branch only) is the only thing
#     that can tell the two apart, and the fixture's widening mutant asserts that it does;
#   - the sentinel token compared as a PREFIX: flagged 0 here, and accepts the `.bak` near-miss,
#     so it is compared whole and the self-probe's `d-bak` seed holds it.
# No input was exempted by name, and none is. The first two narrowings were held only by today's
# corpus until they got seeds of their own: `o-varlater` (a layout chain whose sentinel is emitted
# later through a variable) and `m-grepq` (a branch that names the consumer path in a `grep -qF`)
# must stay quiet, and removing either guard makes the self-probe refuse naming that seed. The
# heredoc skip is held by `p-heredoc`, whose heredoc body carries a column-0 sentinel after the
# chain that would otherwise acquit a dist-only echo.
#
# WHY A STANDALONE SCRIPT AND NOT AN ARM IN THE ENFORCEMENT MAP. That validator is invoked by
# the suite's slowest fixtures and is held to `FORK_BUDGET`; this scan forks a fixed handful of
# times regardless of corpus size, and runs only from its own fixture,
# `core/fixtures/hermetic-consumption/`, which is the only thing that runs it at a push. It is
# distribution-only: its corpus is `core/fixtures/`, which no consumer holds.
#
# EVERY RUN SELF-PROBES FIRST, in both directions, under a mktemp tree. Eight seeded offenders
# must each be flagged: an echo in the dist branch only, a `.bak` near-miss in the consumer
# branch, an echo at the top of the file above the resolution, an echo in the override branch
# only, a consumer echo sent to `> /dev/null`, one with a trailing space inside the quotes, one
# behind `[ ... ] &&`, and a dist-only echo beside a heredoc body carrying the consumer sentinel.
# Six near-misses must stay quiet: the consumer-branch echo, the declared spelling after `fi`, a
# fixed `!` input beside an unmarked input whose chain echoes in its core branch only, the
# consumer echo sent `>&2`, a `grep -qF` branch naming the consumer path, and a layout chain whose
# sentinel comes later through a variable. A `.dist-only` seed must not be scanned at all. A
# probe that disagrees refuses the corpus.
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
    off = i
    if (head !~ /(^|[[:space:]])-[defrsx][[:space:]]+$/) continue
    if (pre !~ /[A-Za-z0-9_.-]/ && post !~ /[A-Za-z0-9_.-]/) return 1
  }
  return 0
}
function reset() { dep = 0; nch = 0; ns = 0; hd = ""; hdtab = 0; anyvar = 0 }
# sentinel(line) -- record a literal sentinel only when the line EMITS it to the runner unconditionally:
# the echo or printf starts its statement, the argument ends at its own closing quote, and nothing
# after it sends stdout anywhere but stderr (which the runner also captures).
function sentinel(line,   p, pre, mm, cmdpre, q, cmd, rest, j, tok, tail, x) {
  p = index(line, "HERMETIC-CONSUMED")
  pre = substr(line, 1, p - 1)
  if (!match(pre, ECHORE)) { anyvar = 1; return }
  mm = substr(pre, RSTART, RLENGTH); cmdpre = substr(pre, 1, RSTART - 1)
  if (mm !~ /^(echo|printf)/) { cmdpre = cmdpre substr(mm, 1, 1); mm = substr(mm, 2) }
  q = substr(mm, length(mm), 1); if (q != DQ && q != SQ) q = ""
  cmd = (mm ~ /^printf/) ? "printf" : "echo"
  x = cmdpre; sub(/[[:space:]]+$/, "", x)
  if (index(cmdpre, "&&") || index(cmdpre, "||") || (x != "" && x !~ /(^|[[:space:];])(then|else|do)$/ && x !~ /[;{)]$/ && x !~ /(^|[^$])[(]$/)) { anyvar = 1; return }
  rest = substr(line, p + 17)
  if (q != "") {
    j = index(rest, q); if (j == 0) { anyvar = 1; return }
    tok = substr(rest, 1, j - 1); tail = substr(rest, j + 1)
  } else {
    if (match(rest, /[;|&<>)#`]/)) { tok = substr(rest, 1, RSTART - 1); tail = substr(rest, RSTART) } else { tok = rest; tail = "" }
    gsub(/[[:space:]]+/, " ", tok); sub(/ $/, "", tok)
  }
  if (substr(tok, 1, 1) != " ") return; tok = substr(tok, 2)
  if (cmd == "printf") sub(/\\n$/, "", tok)
  if (tok == "" || tok ~ /[$%`\\]/) { anyvar = 1; return }
  x = tail; sub(/^[[:space:]]+/, "", x)
  while (match(x, /^(1?>&2|2>&1|2>[^[:space:];&|]+)/)) { x = substr(x, RLENGTH + 1); sub(/^[[:space:]]+/, "", x) }
  if (x != "" && x !~ /^(;|&&|[|][|]|#|[}]|[)])/) { anyvar = 1; return }
  ns++; stok[ns] = tok; sdep[ns] = dep; sline[ns] = FNR; x = " "
  for (j = 1; j <= dep; j++) x = x stk[j] ":" nb[stk[j]] " "
  senc[ns] = x
}
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
  if (line ~ /HERMETIC-CONSUMED/ && line ~ /(echo|printf)[[:space:]]/) sentinel(line)
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
  awk -v FLAGS="$o/flags" -v SUMMARY="$o/summary" -v QC="[\"']" -v SQ="'" -v DQ='"' \
      -v HRE="<<-?[[:space:]]*[\"']?[A-Za-z_][A-Za-z0-9_]*" \
      -v ECHORE="(^|[^A-Za-z0-9_-])(echo|printf)[[:space:]]+(-[en]+[[:space:]]+)?[\"']?\$" \
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
  local grepq="" later="" here=""
  case "$v" in
    fix-a|non-bang) ue='  echo "HERMETIC-CONSUMED scripts/ai-dlc/probe-subject.sh"' ;;
    dist-only)      : ;;
    devnull)        ue='  echo "HERMETIC-CONSUMED scripts/ai-dlc/probe-subject.sh" > /dev/null' ;;
    stderr)         ue='  echo "HERMETIC-CONSUMED scripts/ai-dlc/probe-subject.sh" >&2' ;;
    tspace)         ue='  echo "HERMETIC-CONSUMED scripts/ai-dlc/probe-subject.sh "' ;;
    andand)         ue='  [ -n "${AI_DLC_PROBE_UNSET:-}" ] && echo "HERMETIC-CONSUMED scripts/ai-dlc/probe-subject.sh"' ;;
    grepq)          ue='  echo "HERMETIC-CONSUMED scripts/ai-dlc/probe-subject.sh"'; grepq=1 ;;
    varlater)       ue='  echo "HERMETIC-CONSUMED scripts/ai-dlc/probe-subject.sh"'; later=1 ;;
    heredoc)        here=1 ;;
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
    # grepq: a branch that names the consumer path as a STRING it searches for, not as a file-test
    # operand, and emits nothing -- it must not be judged as an installed-path branch.
    [ -z "$grepq" ] || printf '%s\n' 'elif grep -qF "scripts/ai-dlc/probe-subject.sh" "$ROOT/manifest.txt"; then' '  VAL="$ROOT/manifest.txt"'
    printf '%s\n' 'else' '  echo "FIXTURE ERROR: probe-subject.sh not found in either layout" >&2; exit 2' 'fi'
    [ -z "$after" ] || printf '%s\n' "$after"
    # varlater: a second, layout-DETECTING chain that tests the consumer path, sets a variable, and
    # whose sentinel is emitted later through that variable -- not where the input is consumed.
    [ -z "$later" ] || printf '%s\n' 'if [ -f "$ROOT/core/scripts/probe-subject.sh" ]; then' '  LAY=core/scripts' \
      'elif [ -f "$ROOT/scripts/ai-dlc/probe-subject.sh" ]; then' '  LAY=scripts/ai-dlc' 'fi' 'echo "HERMETIC-CONSUMED $LAY/probe-subject.sh"'
    # heredoc: the dist-only shape plus a heredoc body, after the chain, carrying a consumer-branch
    # sentinel at column 0 -- text written to a file, never emitted, so it must not acquit the input.
    [ -z "$here" ] || printf '%s\n' 'cat > "$ROOT/probe.sh" <<EOF' 'echo "HERMETIC-CONSUMED scripts/ai-dlc/probe-subject.sh"' 'echo "HERMETIC-CONSUMED core/scripts/probe-subject.sh"' 'EOF'
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
# AND a `.dist-only` marker: it must not be scanned, so `scanned` must read 14, not 15.
PROBE_FIRE="b-dist-only d-bak f-top g-override j-devnull l-tspace n-andand p-heredoc"
PROBE_QUIET="a-fix-a c-fix-b e-non-bang k-stderr m-grepq o-varlater"
self_probe() {
  local fx="$WORK/probe/fx" o="$WORK/probe/out" bad=0 n s
  for s in a-fix-a:fix-a b-dist-only:dist-only c-fix-b:fix-b d-bak:bak e-non-bang:non-bang f-top:top g-override:override h-dist-marked:dist-only \
           j-devnull:devnull k-stderr:stderr l-tspace:tspace m-grepq:grepq n-andand:andand o-varlater:varlater p-heredoc:heredoc; do
    probe_seed "$fx" "${s%%:*}" "${s#*:}" || { echo "validate-hermetic-consumption: self-probe could not seed ${s%%:*}" >&2; return 2; }
  done
  printf '%s\n' 'seeded: its subject is not present on a consumer' > "$fx/h-dist-marked/.dist-only"
  mkdir -p "$fx/i-no-decl" && printf '%s\n' 'echo "HERMETIC-CONSUMED core/scripts/probe-subject.sh"' > "$fx/i-no-decl/run.sh"
  scan "$fx" "$o" || { echo "validate-hermetic-consumption: self-probe: the scan refused its own seeded tree" >&2; return 2; }
  n="$(cut -f1 "$o/summary")"
  [ "$n" = "14" ] || { echo "validate-hermetic-consumption: self-probe: scanned $n seeded fixtures, expected 14 -- the corpus walk is not the one this probe seeded" >&2; bad=1; }
  for s in $PROBE_FIRE; do
    grep -q "^$fx/$s	" "$o/flags" || { echo "validate-hermetic-consumption: self-probe: seeded offender $s was NOT flagged" >&2; bad=1; }
  done
  for s in $PROBE_QUIET; do
    grep -q "^$fx/$s	" "$o/flags" && { echo "validate-hermetic-consumption: self-probe: seeded near-miss $s WAS flagged" >&2; bad=1; }
  done
  [ "$bad" = "0" ] || return 2
  say "self-probe: ok -- 8 seeded offenders flagged, 6 near-misses quiet, 1 .dist-only seed not scanned"
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
