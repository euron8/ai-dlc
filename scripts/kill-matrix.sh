#!/usr/bin/env bash
# kill-matrix.sh -- mutate ONE shipped subject at four sites and run every fixture that can read it,
# to answer BL-915 Fix item 1 (b): does a fixture kill at least one mutant that no other FIXTURE kills.
#
# Usage: kill-matrix.sh --subject <path> [--jobs N] [--sha <rev>] [--out DIR] [--seed S]
#                       [--exclude "<fixture> ..."] [--no-verdict "<fixture> ..."] [--timeout SECONDS]
#        kill-matrix.sh --self-probe-only [--jobs N] [--out DIR]
#        kill-matrix.sh --rescore <run dir>   (re-score a finished run from its stored logs and side files; runs nothing)
# Exit:  0 = it ran (whatever the verdicts), 2 = it could not run (self-probe, smoke, setup or usage refused).
#
# AN OPERATOR TOOL. It runs on no gate and no hook. It is a correctness run and is never timed.
#
# READ-ONLY OVER THE REAL TREE. Every run happens in a scratch `git worktree add --detach <sha>` under a
# fresh mktemp -d (one worktree per job; the subject swap is serialized per worktree), through
# core/scripts/hermetic-run.sh from that scratch root, with AI_DLC_PROJECT_ROOT set to it,
# AI_DLC_VERDICT_STORE on a mktemp dir and TMPDIR on a mktemp dir outside the copy. hermetic-run copies a
# declared file from the WORKING TREE, so an in-place swap of the tracked subject reaches the sandbox.
# The scratch worktrees are left in place and named at the end; nothing here deletes them.
#
# RUN POPULATION. Every fixture whose inputs.decl names the subject or a directory prefix of it, in
# hermetic-run's own declaration grammar: a leading `!` (REQUIRED) or `+` (keyed) marks a path that IS
# copied, so it is stripped, never read as a negation. The readset maps are not used. The report prints
# the population, how many fixtures reach it only through a `!` line, and a control count for a path that
# never existed (only bare-prefix declarers can cover it).
#
# MUTANTS. Exactly 4 sites, each in a DISTINCT top-level function of the subject, drawn by awk rand()
# under --seed. Operators replace one line with one line, so the line count is unchanged: negate a test
# (`! [`), swap the first && / || outside quotes, flip `return|exit 0` and `1`, replace a statement with
# `:`. Every variant must pass `bash -n` with the same line count; one that fails is STILLBORN, is never
# run, and the next candidate in the same function is drawn. Each site records its line, operator and
# the sha256 of the mutated file.
#
# SMOKE (before the corpus, after the self-probe). The first statement of the subject's most-called
# function is replaced by `exit 99`. Covering fixtures run under it one at a time, the first that sources
# lib/mutant.sh first, until one goes red (at most the whole population); that fixture's two base runs must
# then be green (its unmutated twin). The first fixture must print this run's overlay marker. No red, a red
# fixture whose base is not green, or a missing marker is exit 2. When NO covering fixture sources
# lib/mutant.sh the overlay cannot change any run, and the marker is reported as not owed.
#
# BATTERY ISOLATION, IN THE SCRATCH COPY ONLY. Before every run core/fixtures/lib/mutant.sh is rewritten as an
# overlay (km_overlay) that is BYTE-TRANSPARENT on stdout and stderr: need_base and mutant_killed are renamed
# and wrapped, the original bodies still emit, and the wrappers append records to the run's SIDE FILE
# (SOURCED <token>, MK <label>, NB <mutant>). The side file is the only channel: an ok or FAIL line it
# accounts for is a TAG -- never an arm, never a FAIL, and a need_base FIXTURE BROKEN line never marks a run
# BROKEN. A fixture that names lib/mutant.sh in its run.sh, lib.sh, seed.sh or world.sh and whose overlaid run
# carries no SOURCED record is REFUSED for that run (OVERLAY-NOT-SOURCED), never read as zero kills.
# TRANSPARENCY IS MEASURED: every fixture also gets one PLAIN run (the original lib/mutant.sh). A plain run
# that matches neither overlaid base run -- same rc and timeout flag, then byte-equal output, or, where either
# carries a temp path, the same ordered ok and FAIL lines with temp paths masked -- makes the fixture
# OVERLAY-OPAQUE: refused for scoring and never a co-killer.
# ONE SHORT ROOT. Every run's TMPDIR, verdict store and side file live under <root>/r<seq>, one fresh
# `mktemp -d /tmp/km.XXXXXX` (a deep --out made sandbox scratch paths too long for a fixture that pads
# them). Its path is recorded in the run dir; it is removed at the end by that recorded path only when the
# path has the /tmp/km.XXXXXX shape. CONCURRENT JOBS SHARE NO WRITABLE STATE: each job has its own worktree
# and back-off FIFO, each run its own TMPDIR, verdict store and side file, and the run-dir indexes
# (runs.tsv, lines.tsv, opaque.tsv, score/) are written by the parent only, after it has waited for every
# worker. No score, verdict or classification reads a clock; the one exception is the watchdog's wall
# timeout, whose run is TIMEOUT and never a kill. The fixture's argv is never touched: no `set --`, no --matrix.
#
# ATTRIBUTION. An arm is the masked label of a `  ok    <label>` line. The WEAK mask replaces the scratch
# root and mktemp-shaped absolute paths; the FULL mask also folds bracketed lists to [] and digit runs to #.
# Arms are FULL-masked labels compared as a multiset against the base.
#   UNSTABLE      a label whose count differs between the two base runs; never attributed.
#   RELABEL       a WEAK label missing in the mutant run whose FULL form is still there; no kill.
#   KILL          lost labels, in base order, credited up to the run's (untagged) FAIL-line count.
#   TRUNCATED     an uncredited lost label inside the lost SUFFIX of the base order; no kill.
#   UNATTRIBUTED  an uncredited lost label outside that suffix; no kill.
#   RED-UNATTRIBUTED  a red run with nothing credited; a FIXTURE-level kill that counts as another killer.
#   A green run is never a kill, whatever it lost.
#   RED-BROKEN    a mutant run with rc other than 0/1 or an untagged FIXTURE BROKEN / FIXTURE ERROR line,
#                 over a green base. The gate reads that run RED, so it is a FIXTURE-level kill: it blocks
#                 UNIQUE elsewhere and counts the mutant KILLED, but never makes its own fixture UNIQUE or
#                 COVERED.
#   TIMEOUT       a run the watchdog killed. Never a kill (a verdict that moves with load is a defect,
#                 BL-868); reported on its own.
#   FORK-FAIL     a run whose log carries a fork-failure signature. Re-run once; never a kill, never a green
#                 base; reported under the upper-bound banner. `ulimit -u` stays at start+1000 (lead rule).
#   PLAIN-RED     a red mutant run of an OVERLAY-OPAQUE fixture (run plain): it blocks UNIQUE elsewhere, earns
#                 its own fixture nothing, and never supplies COVERED.
#   EVERY red kill, of any kind, BLOCKS another fixture's UNIQUE. Only a behavioural kill of a fixture that
#   is not OVERLAY-OPAQUE can SUPPLY another fixture's COVERED (the greedy set R).
#   A need_base line is tagged from the side file WHATEVER the fixture's bad() prints in front of it, before
#   the BRK rule; a mutant run that exits before it sources lib/mutant.sh is scored, never refused.
# STATIC-TEXT. A kill is static-text when (a) the fixture is BYTE-SENSITIVE for that function -- the
#   ADAPTIVE NULL (the site line gets a trailing comment; bytes change, behaviour does not) turned it red --
#   or (b) the fixture's run.sh, seed.sh, lib.sh or world.sh reads the subject AS DATA (km_static: grep, sed,
#   awk, cmp, shasum, diff or cat on a line naming the subject's last two path components, directly or
#   through a variable). A static-text kill blocks another fixture's UNIQUE, never makes another fixture
#   COVERED, and never makes its own fixture UNIQUE or COVERED. The null runs only for (fixture, function) pairs that scored a kill.
# ADAPTIVE RE-RUN. A kill is re-run when it alone decides another fixture's UNIQUE (it is that fixture's
#   only other effective co-killer) or when it would make its OWN fixture UNIQUE (it has no effective
#   co-killer); a kill that does not reproduce is FLAKY and scores nothing.
# THE WATCHDOG counts the members of each run's recorded process group. A fixture or hook that starts its
#   own `set -m` workers puts them in process groups of their own, which that count cannot see; the wall
#   timeout is the backstop for them.
# --exclude drops fixtures from the run set, so they are NOT co-killers and UNIQUE is an upper bound
#   against the run set (the report says so). --no-verdict fixtures RUN and count as co-killers, but get
#   no verdict of their own.
#
# VERDICTS (unit: the FIXTURE; every kill is also kept as an arm-level row in kills.tsv).
#   UNIQUE                      holds a behavioural kill of a mutant no other fixture kills in ANY way (a
#                               FLAKY, TIMEOUT or FORK-FAIL run is no kill). Conclusive: keep.
#   COVERED-provisional         in the greedy cover set R: removing all of R leaves every killed mutant
#                               killed, so mutual co-killers are never both in R. Listed with co-killers.
#   COVER-RETAINED-provisional  kills, is not UNIQUE, and stays outside R to keep the cover.
#   NOKILL-provisional          no behavioural kill of its own on the 4 sites (RED-BROKEN and static-text
#                               kills are listed in kills.tsv but earn nothing).
#   NO-VERDICT                  a --no-verdict fixture.
#   BROKEN                      a base run was not green, or broke.
#   Provisional verdicts are "on 4 sampled sites", never a failure of (b) by themselves.
#
# SELF-PROBE. Always first, on a mktemp toy git repo, through the same worktree, hermetic-run, overlay and
# scorer path, one seeded fixture per scoring path. Every case must hold, AND every deliberately broken
# scorer in km_probe_patches, re-scored over the same recorded runs, must fail its named case (or any
# case), or this exits 2. The probe runs each mutant only against the toy fixtures that reach it.
set -u

KM_TAB="$(printf '\t')"
km_die() { printf 'kill-matrix: %s\n' "$*" >&2; exit 2; }
km_say() { printf 'kill-matrix: %s\n' "$*" >&2; }

# --- AI_DLC_ROOT ---------------------------------------------------------------
# override -> walk up from this script -> CLAUDE_PROJECT_DIR -> walk up from cwd -> exit 2. Never a hop count.
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
KM_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KM_SELF="$KM_SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"
KM_ROOT="${AI_DLC_PROJECT_ROOT:-}"
[ -n "$KM_ROOT" ] || KM_ROOT="$(ai_dlc_resolve_root "$KM_SCRIPT_DIR" || true)"
[ -n "$KM_ROOT" ] || KM_ROOT="${CLAUDE_PROJECT_DIR:-}"
[ -n "$KM_ROOT" ] || KM_ROOT="$(ai_dlc_resolve_root "$(pwd)" || true)"
[ -n "$KM_ROOT" ] || km_die "cannot resolve the project root from $KM_SCRIPT_DIR; set AI_DLC_PROJECT_ROOT"
# --- end AI_DLC_ROOT -----------------------------------------------------------
KM_ROOT="$(cd "$KM_ROOT" && pwd -P)" || km_die "project root unreadable"

KM_SUBJECT=""; KM_JOBS=3; KM_SHA=HEAD; KM_OUT=""; KM_SEED=1; KM_EXCLUDE=""; KM_NOVERDICT=""; KM_TIMEOUT=1800; KM_PROBE_ONLY=0; KM_RESCORE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --subject) [ $# -ge 2 ] || km_die "--subject needs a value"; KM_SUBJECT="$2"; shift 2 ;;
    --jobs) [ $# -ge 2 ] || km_die "--jobs needs a value"; KM_JOBS="$2"; shift 2 ;;
    --sha) [ $# -ge 2 ] || km_die "--sha needs a value"; KM_SHA="$2"; shift 2 ;;
    --out) [ $# -ge 2 ] || km_die "--out needs a value"; KM_OUT="$2"; shift 2 ;;
    --seed) [ $# -ge 2 ] || km_die "--seed needs a value"; KM_SEED="$2"; shift 2 ;;
    --exclude) [ $# -ge 2 ] || km_die "--exclude needs a value"; KM_EXCLUDE="$2"; shift 2 ;;
    --no-verdict) [ $# -ge 2 ] || km_die "--no-verdict needs a value"; KM_NOVERDICT="$2"; shift 2 ;;
    --timeout) [ $# -ge 2 ] || km_die "--timeout needs a value"; KM_TIMEOUT="$2"; shift 2 ;;
    --self-probe-only) KM_PROBE_ONLY=1; shift ;;
    --rescore) [ $# -ge 2 ] || km_die "--rescore needs a run dir"; KM_RESCORE="$2"; shift 2 ;;
    -h|--help) sed -n '2,12p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) km_die "unknown argument $1 (usage: --subject <path> [--jobs N] [--sha <rev>] [--out DIR] [--seed S] | --self-probe-only)" ;;
  esac
done
case "$KM_JOBS" in ''|*[!0-9]*) km_die "--jobs must be a positive integer" ;; esac
[ "$KM_JOBS" -ge 1 ] || km_die "--jobs must be at least 1"
case "$KM_SEED" in ''|*[!0-9]*) km_die "--seed must be a non-negative integer" ;; esac
case "$KM_TIMEOUT" in ''|*[!0-9]*) km_die "--timeout must be a positive integer" ;; esac
[ "$KM_PROBE_ONLY" = 1 ] || [ -n "$KM_RESCORE" ] || [ -n "$KM_SUBJECT" ] || km_die "--subject is required (or --self-probe-only, or --rescore <run dir>)"

if [ -z "$KM_RESCORE" ]; then
# The out dir holds the TMPDIR the sandboxes are minted under, so no project marker may sit above it. A given
# --out is resolved through its nearest EXISTING ancestor and checked BEFORE anything is created.
if [ -z "$KM_OUT" ]; then
  km_check="$(cd "${TMPDIR:-/tmp}" && pwd -P)" || km_die "TMPDIR unreadable"
else
  case "$KM_OUT" in /*) km_check="$KM_OUT" ;; *) km_check="$(pwd -P)/$KM_OUT" ;; esac
  km_rest=""
  while [ ! -d "$km_check" ]; do km_rest="/$(basename "$km_check")$km_rest"; km_check="$(dirname "$km_check")"; done
  km_check="$(cd "$km_check" && pwd -P)$km_rest" || km_die "out dir parent unreadable"
fi
km_marker_above="$(ai_dlc_resolve_root "$km_check" || true)"
[ -z "$km_marker_above" ] || km_die "out dir $km_check sits under a project marker ($km_marker_above); hermetic-run would refuse every run. Pick an --out outside any repository."
case "$km_check/" in "$KM_ROOT"/*) km_die "out dir must be outside the project root" ;; esac
if [ -z "$KM_OUT" ]; then
  KM_OUT="$(mktemp -d "$km_check/kill-matrix.XXXXXX")" || km_die "mktemp failed"
else
  mkdir -p "$km_check" || km_die "cannot create $km_check"; KM_OUT="$km_check"
fi
KM_OUT="$(cd "$KM_OUT" && pwd -P)" || km_die "out dir unreadable"
# every short root this invocation creates is recorded in $KM_OUT/short.roots and removed on EVERY exit path
trap 'km_cleanup_all >&2' EXIT
fi

for km_t in "$KM_ROOT/core/scripts/hermetic-run.sh" "$KM_ROOT/core/fixtures/lib/mutant.sh"; do
  [ -f "$km_t" ] || km_die "missing $km_t"
done
KM_HOOK=""
for km_t in .githooks/pre-push core/git-hooks/pre-push; do [ -f "$KM_ROOT/$km_t" ] && { KM_HOOK="$km_t"; break; }; done
[ -n "$KM_HOOK" ] || km_die "no pre-push hook under $KM_ROOT for hermetic-run to source"

# ============================================================================================
# SUBJECT SCAN, MUTATION AND VALIDATION
# ============================================================================================

# km_scan <file>: rows on stdout.
#   F <func> <header line> <calls>       one per top-level function
#   C <func> <line> <op> <pos>            one per candidate mutation site
#   S <func> <line>                       the function's first statement line (`:`-able), for the gross mutant
# Quote, comment and heredoc state is tracked across lines so a site is never inside a string body.
km_scan() {
  /usr/bin/awk '
  BEGIN { SQ = sprintf("%c", 39); DQ = "\""; st = "o"; hd = ""; fn = ""; prevcont = 0; nf = 0
          split("if then else elif fi do done case esac while until for function select in time", kw, " ")
          for (i in kw) KW[kw[i]] = 1 }
  {
    line = $0; sub(/\r$/, "", line); L[NR] = line
    if (hd != "") { t = line; sub(/^\t+/, "", t); if (t == hd) hd = ""; prevcont = 0; next }
    startst = st; hdopen = ""; mask = ""; cstart = 0; n = length(line); i = 1; ar = 0
    while (i <= n) {
      c = substr(line, i, 1)
      if (st == "s") { mask = mask "q"; if (c == SQ) st = "o"; i++; continue }
      if (st == "d") {
        if (c == "\\") { mask = mask "qq"; i += 2; continue }
        mask = mask "q"; if (c == DQ) st = "o"; i++; continue
      }
      if (c == "\\") { mask = mask "ee"; i += 2; continue }
      if (c == "#" && (i == 1 || substr(line, i - 1, 1) ~ /[ \t;]/)) { cstart = i; break }
      if (c == SQ) { st = "s"; mask = mask "q"; i++; continue }
      if (c == DQ) { st = "d"; mask = mask "q"; i++; continue }
      if (substr(line, i, 3) == "<<<") { mask = mask "ooo"; i += 3; continue }
      if (c == "(" && substr(line, i, 2) == "((") ar++
      if (c == ")" && substr(line, i, 2) == "))" && ar > 0) ar--
      if (substr(line, i, 2) == "<<" && ar == 0) {
        rest = substr(line, i + 2); sub(/^-/, "", rest); sub(/^[ \t]*/, "", rest)
        if (match(rest, "^[\"" SQ "]?[A-Za-z_][A-Za-z0-9_]*")) { w = substr(rest, 1, RLENGTH); gsub("[\"" SQ "]", "", w); hdopen = w }
      }
      mask = mask "o"; i++
    }
    code = (cstart > 0) ? substr(line, 1, cstart - 1) : line
    sub(/[ \t]+$/, "", code)
    endst = st
    ishdr = 0
    if (startst == "o" && match(line, /^(function[ \t]+)?[A-Za-z_][A-Za-z0-9_]*[ \t]*\(\)/)) {
      h = substr(line, 1, RLENGTH); sub(/^function[ \t]+/, "", h); sub(/[ \t]*\(\)$/, "", h)
      fn = h; nf++; FN[nf] = fn; FH[fn] = NR; ishdr = 1
      oneline = (code ~ /\}[ \t;]*$/ && code ~ /\{/)
    }
    if (!ishdr && startst == "o" && line ~ /^\}/) { fn = ""; prevcont = 0; if (hdopen != "") hd = hdopen; next }
    cand = (fn != "" && !ishdr && startst == "o" && endst == "o" && hdopen == "" && code != "" && code !~ /\\$/)
    if (cand) {
      # negate a test at the head of a statement
      if (!prevcont && match(code, /^[ \t]*((if|elif|while|until)[ \t]+)?\[\[?[ \t]/)) {
        p = RSTART + index(substr(code, RSTART, RLENGTH), "[") - 1
        if (substr(mask, p, 1) == "o") print "C\t" fn "\t" NR "\tnegtest\t" p
      }
      # swap the first && or || outside quotes
      for (j = 1; j < length(code); j++) {
        two = substr(code, j, 2)
        if ((two == "&&" || two == "||") && substr(mask, j, 2) == "oo") { print "C\t" fn "\t" NR "\tandor\t" j; break }
      }
      # flip return/exit 0 and 1
      if (match(code, /(^|[^A-Za-z0-9_$-])(return|exit)[ \t]+[01]([^0-9A-Za-z_]|$)/)) {
        s = substr(code, RSTART, RLENGTH); q = RSTART
        if (match(s, /(return|exit)[ \t]+/)) { p = q + RSTART - 1 + RLENGTH; if (substr(mask, p, 1) == "o") print "C\t" fn "\t" NR "\tretexit\t" p }
      }
      # replace a whole simple statement with :
      fw = code; sub(/^[ \t]+/, "", fw); w1 = fw; sub(/[ \t;&|<>()].*$/, "", w1)
      oc = gsub(/\(/, "(", code); cc = gsub(/\)/, ")", code); ob = gsub(/\{/, "{", code); cb = gsub(/\}/, "}", code)
      if (!prevcont && !(w1 in KW) && w1 ~ /^[A-Za-z_][A-Za-z0-9_]*(=.*)?$|^[A-Za-z_][A-Za-z0-9_]*\[/ && code !~ /(\||&&|\|\||\{|\(|;;)$/ \
          && code !~ /;;/ && oc == cc && ob == cb && index(code, "<<") == 0) {
        print "C\t" fn "\t" NR "\tcolon\t1"
        if (!(fn in FS1)) { FS1[fn] = NR; print "S\t" fn "\t" NR }
      }
    }
    prevcont = (code ~ /(\\|\||&&|\|\|)$/) ? 1 : 0
    if (ishdr && oneline) fn = ""
    if (hdopen != "") hd = hdopen
  }
  END {
    for (k = 1; k <= nf; k++) {
      f = FN[k]; c = 0; re = "(^|[^A-Za-z0-9_])" f "([^A-Za-z0-9_]|$)"
      for (r = 1; r <= NR; r++) { if (r == FH[f]) continue; t = L[r]; sub(/^[ \t]*#.*/, "", t); if (t ~ re) c++ }
      print "F\t" f "\t" FH[f] "\t" c
    }
  }' "$1"
}

# km_apply <src> <line> <op> <pos> [text] > variant. One line replaced by one line.
km_apply() {
  /usr/bin/awk -v L="$2" -v op="$3" -v pos="$4" -v txt="${5:-}" '
  NR == L+0 {
    line = $0; match(line, /^[ \t]*/); ind = substr(line, 1, RLENGTH)
    if (op == "negtest") line = substr(line, 1, pos - 1) "! " substr(line, pos)
    else if (op == "andor") { t = substr(line, pos, 2); line = substr(line, 1, pos - 1) ((t == "&&") ? "||" : "&&") substr(line, pos + 2) }
    else if (op == "retexit") { d = substr(line, pos, 1); line = substr(line, 1, pos - 1) ((d == "0") ? "1" : "0") substr(line, pos + 1) }
    else if (op == "colon") line = ind ":"
    else if (op == "null") line = line " # km-null"
    else if (op == "gross") line = ind "exit 99"
    else if (op == "set") line = txt
    print line; next }
  { print }' "$1"
}

# km_valid <orig> <variant>: 0 when the variant differs, keeps the line count and passes bash -n.
km_valid() {
  local a b
  cmp -s "$1" "$2" && return 1
  a="$(/usr/bin/awk 'END { print NR }' "$1")"; b="$(/usr/bin/awk 'END { print NR }' "$2")"
  [ "$a" = "$b" ] || return 1
  bash -n "$2" 2>/dev/null
}

km_sha() { shasum -a 256 "$1" | cut -d' ' -f1; }

# km_select <subject> <seed> <outdir>: writes <outdir>/sites.tsv (mut func line op sha status variant)
# with exactly 4 LIVE rows in distinct functions plus any STILLBORN draws, and <outdir>/scan.tsv.
# Prints "<functions total> <functions eligible>" on stdout. Returns 1 when fewer than 4 functions qualify.
km_select() {
  local subj="$1" seed="$2" d="$3" live=0 sb=0 cur="" got="" fnc func ln op pos v
  km_scan "$subj" > "$d/scan.tsv" || return 1
  : > "$d/sites.tsv"
  /usr/bin/awk -F'\t' -v seed="$seed" '
    $1 == "C" { n[$2]++; c[$2, n[$2]] = $3 "\t" $4 "\t" $5; if (!($2 in seen)) { seen[$2] = 1; fo[++nf] = $2 } }
    END { srand(seed + 0)
      for (i = 1; i <= nf; i++) { k[i] = rand(); idx[i] = i }
      for (i = 2; i <= nf; i++) { j = i; while (j > 1 && k[idx[j-1]] > k[idx[j]]) { t = idx[j]; idx[j] = idx[j-1]; idx[j-1] = t; j-- } }
      for (r = 1; r <= nf; r++) { f = fo[idx[r]]; m = n[f]
        for (i = 1; i <= m; i++) { kk[i] = rand(); ii[i] = i }
        for (i = 2; i <= m; i++) { j = i; while (j > 1 && kk[ii[j-1]] > kk[ii[j]]) { t = ii[j]; ii[j] = ii[j-1]; ii[j-1] = t; j-- } }
        for (i = 1; i <= m; i++) print r "\t" f "\t" c[f, ii[i]] } }' "$d/scan.tsv" > "$d/draws.tsv"
  while IFS="$KM_TAB" read -r fnc func ln op pos; do
    [ "$live" -lt 4 ] || break
    case " $got " in *" $func "*) continue ;; esac
    v="$d/variant.$func.$ln.$op"
    km_apply "$subj" "$ln" "$op" "$pos" > "$v" || return 1
    if km_valid "$subj" "$v"; then
      live=$((live + 1)); got="$got $func"
      printf 'M%s\t%s\t%s\t%s\t%s\tLIVE\t%s\t%s\n' "$live" "$func" "$ln" "$op" "$(km_sha "$v")" "$v" "$pos" >> "$d/sites.tsv"
    else
      sb=$((sb + 1))
      printf 'SB%s\t%s\t%s\t%s\t%s\tSTILLBORN\t%s\t%s\n' "$sb" "$func" "$ln" "$op" "$(km_sha "$v")" "$v" "$pos" >> "$d/sites.tsv"
    fi
  done < "$d/draws.tsv"
  printf '%s %s\n' "$(/usr/bin/awk -F'\t' '$1 == "F"' "$d/scan.tsv" | wc -l | tr -d ' ')" \
                   "$(/usr/bin/awk -F'\t' '$1 == "C" { s[$2] = 1 } END { for (f in s) n++; print n + 0 }' "$d/scan.tsv")"
  [ "$live" -eq 4 ]
}

# ============================================================================================
# POPULATION
# ============================================================================================

# km_population <root> <subject> <exclude list>: covering fixture names on stdout (sorted), and on stderr-free
# side files: <out>/population.only-required (names covered only through a `!` line).
km_population() {
  local root="$1" s="$2" ex="$3" d n
  for d in "$root"/core/fixtures/*/; do
    n="$(basename "$d")"
    [ -f "$d/inputs.decl" ] && [ -f "$d/run.sh" ] || continue
    case " $ex " in *" $n "*) continue ;; esac
    /usr/bin/awk -v s="$s" -v n="$n" '
      { sub(/\r$/, ""); if ($0 == "" || $0 ~ /^#/) next
        l = $0; req = 0; while (l ~ /^[!+]/) { if (substr(l, 1, 1) == "!") req = 1; l = substr(l, 2) }
        if (l == s || (l ~ /\/$/ && index(s, l) == 1)) { hit = 1; if (!req) plain = 1 } }
      END { if (hit) print n "\t" (plain ? "plain" : "required-only") }' "$d/inputs.decl"
  done | LC_ALL=C sort
}

# ============================================================================================
# THE RUNNER
# ============================================================================================

# km_overlay <dest> <original mutant.sh> <token> <short root>: write the overlaid lib/mutant.sh IN THE SCRATCH
# COPY ONLY. It is SILENT on stdout and stderr: the original need_base and mutant_killed are renamed and wrapped,
# every emission is still made by the original body, and the wrappers only append a record to the run's side
# file (SOURCED <token> at source time, MK <label> before a kill line, NB <mutant> before a need_base FAIL).
# Its BYTES ARE THE SAME ON EVERY RUN of one invocation: the side path is derived at SOURCE time from $TMPDIR,
# which hermetic-run sets per run under <short root>/r<seq>/tmp (a variable naming the path would not survive
# hermetic-run's `env -i`). A TMPDIR outside the short root writes no record, which a sourcer's base run
# reports as OVERLAY-NOT-SOURCED rather than as silence.
km_overlay() {
  /usr/bin/grep -q '^need_base() {$' "$2" && /usr/bin/grep -q '^mutant_killed() {$' "$2" || return 1
  {
    /usr/bin/sed -e 's/^need_base() {$/km_orig_need_base() {/' -e 's/^mutant_killed() {$/km_orig_mutant_killed() {/' "$2"
    printf '\n# kill-matrix overlay (scratch copy only): silent on stdout and stderr; records go to a side file.\n'
    printf "_km_root='%s'\n" "$4"
    cat <<'OVL'
case "${TMPDIR:-}" in "$_km_root"/r*) _km_r="${TMPDIR#"$_km_root"/}"; _km_side_file="$_km_root/${_km_r%%/*}/side" ;; *) _km_side_file="" ;; esac
km_side() { [ -n "$_km_side_file" ] || return 0; { printf '%s\t%s\n' "$1" "$2" >> "$_km_side_file"; } 2>/dev/null || :; }
need_base() { [ "$1" = 1 ] || km_side NB "$2"; km_orig_need_base "$@"; }
mutant_killed() { [ "$1" != 1 ] || km_side MK "$3"; km_orig_mutant_killed "$@"; }
OVL
    printf "km_side SOURCED '%s'\n" "$3"
  } > "$1"
}

# km_setup <git root> <sha> <rundir> <jobs> <subject>: scratch worktrees, original subject and mutant.sh copies,
# and ONE short root (`mktemp -d /tmp/km.XXXXXX`) holding every run's TMPDIR, verdict store and side file.
km_setup() {
  local root="$1" sha="$2" run="$3" jobs="$4" subj="$5" i wt
  mkdir -p "$run/wt" "$run/runs" "$run/variants" "$run/cmp" || return 1
  KM_RUN="$run"; KM_SUBJ="$subj"; KM_NJ="$jobs"
  KM_SHORT="$(mktemp -d /tmp/km.XXXXXX)" && KM_SHORT="$(cd "$KM_SHORT" && pwd -P)" || return 1
  printf '%s\n' "$KM_SHORT" > "$run/short.path"
  [ -z "${KM_OUT:-}" ] || printf '%s\t%s\n' "$$" "$KM_SHORT" >> "$KM_OUT/short.roots"
  KM_TOKEN="km-$$-$RANDOM$RANDOM"
  printf '%s\n' "$KM_TOKEN" > "$run/token"
  : > "$run/runs.tsv"; : > "$run/lines.tsv"; : > "$run/statics.tsv"; : > "$run/noverdict.txt"; : > "$run/opaque.tsv"; KM_RUNSEQ=0
  i=1
  while [ "$i" -le "$jobs" ]; do
    wt="$run/wt/w$i"
    git -C "$root" worktree add -q --detach "$wt" "$sha" > /dev/null 2>&1 || { km_say "git worktree add failed for $wt"; return 1; }
    # a FIFO per worker, opened read-write, gives its watchdog a fork-free 5 s back-off (`read -t`)
    mkfifo "$run/backoff.w$i" || return 1
    i=$((i + 1))
  done
  [ -f "$run/wt/w1/$subj" ] || { km_say "subject $subj is absent at $sha"; return 1; }
  cat "$run/wt/w1/$subj" > "$run/orig.subject" || return 1
  KM_ORIG="$run/orig.subject"
  cat "$run/wt/w1/core/fixtures/lib/mutant.sh" > "$run/mutant.orig" || return 1
  km_overlay "$run/overlay.check" "$run/mutant.orig" "$KM_TOKEN" /dev/null \
    && /usr/bin/grep -q '^km_orig_need_base() {$' "$run/overlay.check" && /usr/bin/grep -q '^km_orig_mutant_killed() {$' "$run/overlay.check" \
    || { km_say "lib/mutant.sh does not carry need_base() and mutant_killed() at column 0, so the overlay cannot wrap them"; return 1; }
}

# km_rm_short <path>: remove one short root by its RECORDED path, only when it has the /tmp/km.XXXXXX shape.
km_rm_short() {
  [ -e "$1" ] || return 0
  if printf '%s\n' "$1" | /usr/bin/grep -Eq '^(/private)?/tmp/km\.[A-Za-z0-9]{6}$'; then
    rm -rf -- "$1" && printf 'short root %s removed\n' "$1"
  else
    printf 'short root %s LEFT IN PLACE: it does not have the /tmp/km.XXXXXX shape\n' "$1"
  fi
}
# km_short_cleanup: this run dir's short root. km_cleanup_all: every root this invocation recorded (the EXIT trap).
km_short_cleanup() { km_rm_short "$(cat "$KM_RUN/short.path" 2>/dev/null)"; }
km_cleanup_all() {
  local o p
  [ -n "${KM_OUT:-}" ] && [ -f "$KM_OUT/short.roots" ] || return 0
  # rows are `<pid>\t<path>`; a reused --out holds other invocations' live roots, so only THIS pid's rows are ours
  while IFS="$KM_TAB" read -r o p; do [ "$o" = "$$" ] && [ -n "$p" ] && km_rm_short "$p"; done < "$KM_OUT/short.roots"
  return 0
}

# km_run_one <worktree> <fixture> <runid>: one hermetic run under set -m with its pgid recorded at spawn,
# a member-count watchdog (300) and a wall timeout. Nothing is killed by pattern. The run's TMPDIR, verdict
# store and side file are its own, under <short root>/r<seq>; the side file is copied into the run dir after.
km_run_one() {
  local wt="$1" fx="$2" rid="$3" log pid pg n start to=0 rc d
  log="$KM_RUN/runs/$rid.log"
  d="$KM_SHORT/r${rid##*-}"
  mkdir -p "$d/vs" "$d/tmp" && touch "$d/side" || { printf '2\t0\n' > "$KM_RUN/runs/$rid.rc"; return 0; }
  # Job control is on for the SPAWN only: on for the whole worker, every foreground sleep, ps and cat also
  # got a process group of its own, and bash reported `child setpgid ... Operation not permitted` races.
  set -m
  ( unset FXCOUNT_RC FXCOUNT_DIR FXCOUNT_JUDGE AI_DLC_HERMETIC_KEEP GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY
    export TMPDIR="$d/tmp" AI_DLC_PROJECT_ROOT="$wt" AI_DLC_VERDICT_STORE="$d/vs"
    bash "$wt/core/scripts/hermetic-run.sh" --root "$wt" "$fx" ) > "$log" 2>&1 < /dev/null &
  pid=$!
  set +m
  pg="$(ps -o pgid= -p "$pid" 2>/dev/null | tr -d ' ')"
  printf '%s\t%s\n' "$pid" "${pg:-exited}" > "$KM_RUN/runs/$rid.pgid"
  if [ -n "$pg" ] && [ "$pg" != "$pid" ]; then
    printf 'kill-matrix: run pid %s sits in pgid %s, not a group of its own; the watchdog cannot bound it\n' "$pid" "$pg" >> "$log.wd"
  fi
  start=$SECONDS
  while kill -0 "$pid" 2>/dev/null; do
    if [ $((SECONDS - start)) -gt "$KM_TIMEOUT" ]; then to=1; printf 'kill-matrix: watchdog: pgid %s past %ss\n' "$pid" "$KM_TIMEOUT" >> "$log.wd"; kill -KILL -- "-$pid" 2>/dev/null; break; fi
    # a failed ps fork backs off 5 s through the worker's FIFO (no fork), never spins
    n="$(ps -A -o pgid= | /usr/bin/awk -v g="$pid" '$1 == g { c++ } END { print c + 0 }')" || n=""
    case "$n" in ''|*[!0-9]*) read -r -t 5 km_x <> "$KM_RUN/backoff.${wt##*/}" || :; continue ;; esac
    if [ "$n" -gt 300 ]; then to=1; printf 'kill-matrix: watchdog: pgid %s past 300 members\n' "$pid" >> "$log.wd"; kill -KILL -- "-$pid" 2>/dev/null; break; fi
    sleep 0.3 || { read -r -t 5 km_x <> "$KM_RUN/backoff.${wt##*/}" || :; }
  done
  wait "$pid"; rc=$?
  cat "$d/side" > "$KM_RUN/runs/$rid.side" 2>/dev/null || : > "$KM_RUN/runs/$rid.side"
  printf '%s\t%s\n' "$rc" "$to" > "$KM_RUN/runs/$rid.rc"
}

# km_is_opaque <fixture>: 0 when the fixture is listed OVERLAY-OPAQUE in this run dir.
km_is_opaque() { /usr/bin/awk -F'\t' -v f="$1" '$1 == f { x = 1 } END { exit x ? 0 : 1 }' "$KM_RUN/opaque.tsv" 2>/dev/null; }

# km_worker <worktree> <taskfile>: the ONLY writer of its worktree. Before each run it swaps the subject and
# rewrites lib/mutant.sh: the overlay, or the original for a `plain` run and for EVERY run of an OVERLAY-OPAQUE
# fixture (its mutant, null and re-run runs are plain runs).
km_worker() {
  local wt="$1" rid cls fx mut rep var start
  start="$(ps -U "$(id -u)" -o pid= 2>/dev/null | wc -l | tr -d ' ')"
  ulimit -u $((start + 1000)) 2>/dev/null || :
  while IFS="$KM_TAB" read -r rid cls fx mut rep var; do
    if [ "$var" = - ]; then cat "$KM_ORIG" > "$wt/$KM_SUBJ"; else cat "$var" > "$wt/$KM_SUBJ"; fi \
      || { printf '2\t0\n' > "$KM_RUN/runs/$rid.rc"; continue; }
    if [ "$cls" = plain ] || km_is_opaque "$fx"; then cat "$KM_RUN/mutant.orig" > "$wt/core/fixtures/lib/mutant.sh"
    else km_overlay "$wt/core/fixtures/lib/mutant.sh" "$KM_RUN/mutant.orig" "$KM_TOKEN" "$KM_SHORT"; fi \
      || { printf '2\t0\n' > "$KM_RUN/runs/$rid.rc"; continue; }
    km_run_one "$wt" "$fx" "$rid"
  done < "$2"
  cat "$KM_ORIG" > "$wt/$KM_SUBJ"
  cat "$KM_RUN/mutant.orig" > "$wt/core/fixtures/lib/mutant.sh"
}

# km_phase <taskfile>: tasks are `<class> <fixture> <mut> <rep> <variant|->`. Run them over the workers
# (all tasks of one fixture on one worker), then -- in the parent, after every worker has been waited for --
# append runs.tsv and the parsed lines. Workers write only per-run files and their own worktree.
# A run whose log carries a fork-failure signature (FORK-FAIL) is re-run ONCE, as a later run that supersedes it;
# both stay in runs.tsv, and a re-run that fails to fork again stays FORK-FAIL.
km_phase() {
  local tf="$1" i pids="" p cls fx mut rep var rid rc to
  [ -s "$tf" ] || return 0
  : > "$tf.ids"
  while IFS="$KM_TAB" read -r cls fx mut rep var; do
    KM_RUNSEQ=$((KM_RUNSEQ + 1)); rid="$cls-$KM_RUNSEQ"
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$rid" "$cls" "$fx" "$mut" "$rep" "$var" >> "$tf.ids"
  done < "$tf"
  /usr/bin/awk -F'\t' -v nj="$KM_NJ" -v base="$tf.w" '
    !($3 in w) { w[$3] = (nw++ % nj) + 1 } { print > (base w[$3]) }' "$tf.ids"
  i=1
  while [ "$i" -le "$KM_NJ" ]; do
    if [ -s "$tf.w$i" ]; then km_worker "$KM_RUN/wt/w$i" "$tf.w$i" & pids="$pids $!"; fi
    i=$((i + 1))
  done
  for p in $pids; do wait "$p"; done
  : > "$tf.forkfail"
  while IFS="$KM_TAB" read -r rid cls fx mut rep var; do
    rc=2; to=0
    [ -f "$KM_RUN/runs/$rid.rc" ] && IFS="$KM_TAB" read -r rc to < "$KM_RUN/runs/$rid.rc"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$rid" "$cls" "$fx" "$mut" "$rep" "$rc" "$to" >> "$KM_RUN/runs.tsv"
    km_parse "$rid" "$fx" "$cls" > "$KM_RUN/cmp/parse.$rid"
    cat "$KM_RUN/cmp/parse.$rid" >> "$KM_RUN/lines.tsv"
    if /usr/bin/awk -F'\t' '$2 == "FORKFAIL" { f = 1 } END { exit f ? 0 : 1 }' "$KM_RUN/cmp/parse.$rid"; then
      printf '%s\t%s\t%s\t%s\t%s\n' "$cls" "$fx" "$mut" "$rep" "$var" >> "$tf.forkfail"
    fi
  done < "$tf.ids"
  case "$tf" in *.retry) return 0 ;; esac
  [ ! -s "$tf.forkfail" ] || { cp "$tf.forkfail" "$tf.retry" && km_phase "$tf.retry"; }
}

# km_sources_mutant <fixture>: 0 when its run.sh, lib.sh, seed.sh or world.sh names lib/mutant.sh on a
# non-comment line.
km_sources_mutant() {
  local f
  for f in run.sh lib.sh seed.sh world.sh; do
    [ -f "$KM_RUN/wt/w1/core/fixtures/$1/$f" ] || continue
    /usr/bin/awk '!/^[ \t]*#/ && index($0, "lib/mutant.sh") > 0 { f = 1 } END { exit f ? 0 : 1 }' "$KM_RUN/wt/w1/core/fixtures/$1/$f" && return 0
  done
  return 1
}

# km_parse <runid> <fixture> <class>: `<runid> <kind> <a> <b>` rows in order. ok and FAIL rows carry the weak and
# full label. A TAG row is a line the SIDE FILE accounts for, matched as a multiset, carrying the kind it would
# otherwise have had (ok, FAIL or other) and its full label: an MK label on an ok line (trailing blanks ignored),
# or ANY line carrying `FIXTURE BROKEN: MUTANT <n> ` for an NB mutant n, whatever the fixture's bad() prints in
# front of it -- tested BEFORE the BRK rule. A BRK row is any other FIXTURE BROKEN / FIXTURE ERROR line; a FORKFAIL
# row a fork-failure signature; one NOSRC row when the fixture sources lib/mutant.sh and this overlaid run's side
# file carries no SOURCED record for this tool's token. Nothing the fixture prints is ever a tag by itself.
km_parse() {
  local side="$KM_RUN/runs/$1.side" src=0
  [ -f "$side" ] || side=/dev/null
  if [ "$3" != plain ] && ! km_is_opaque "$2" && km_sources_mutant "$2"; then src=1; fi
  /usr/bin/awk -v id="$1" -v root="$KM_RUN" -v sidef="$side" -v src="$src" -v tok="$KM_TOKEN" '
  function lit(s, a, b,   i, o) { o = ""; while ((i = index(s, a)) > 0) { o = o substr(s, 1, i - 1) b; s = substr(s, i + length(a)) } return o s }
  function weak(s) { s = lit(s, root, "<ROOT>"); gsub(/\/[^ \t:,;"]*(tmp|var|private|hermetic-run|folders)[^ \t:,;"]*/, "<P>", s); return s }
  function full(s) { gsub(/\[[^\]]*\]/, "[]", s); gsub(/[0-9]+/, "#", s); return s }
  function kd(s) { return substr(s, 1, 8) == "  ok    " ? "ok" : (substr(s, 1, 8) == "  FAIL  " ? "FAIL" : "other") }
  function lb(s) { return kd(s) == "other" ? "-" : full(weak(substr(s, 9))) }
  FILENAME == sidef { t = $0; sub(/\r$/, "", t); i = index(t, "\t"); k = substr(t, 1, i - 1); v = substr(t, i + 1); gsub(/\t/, " ", v)
    if (k == "MK") { sub(/[ \t]+$/, "", v); mk[v]++ } else if (k == "NB") nb[v]++; else if (k == "SOURCED" && v == tok) srcd = 1
    next }
  { sub(/\r$/, ""); gsub(/\t/, " ")
    if (index($0, "FIXTURE BROKEN: MUTANT ") > 0) {
      for (n in nb) if (nb[n] > 0 && index($0, "FIXTURE BROKEN: MUTANT " n " ") > 0) { nb[n]--; print id "\tTAG\t" kd($0) "\t" lb($0); next } }
    if ($0 ~ /fork: Resource temporarily unavailable|Cannot fork|fork: retry/) print id "\tFORKFAIL\t-\t-"
    if (substr($0, 1, 8) == "  ok    ") { l = substr($0, 9); l2 = l; sub(/[ \t]+$/, "", l2)
      if (mk[l2] > 0) { mk[l2]--; print id "\tTAG\tok\t" lb($0); next }
      w = weak(l); print id "\tok\t" w "\t" full(w); next }
    if (substr($0, 1, 8) == "  FAIL  ") { l = substr($0, 9); w = weak(l); print id "\tFAIL\t" w "\t" full(w)
      if (l ~ /FIXTURE BROKEN|FIXTURE ERROR/) print id "\tBRK\t-\t-"; next }
    if ($0 ~ /FIXTURE BROKEN|FIXTURE ERROR/) print id "\tBRK\t-\t-" }
  END { if (src && !srcd) print id "\tNOSRC\t-\t-" }' "$side" "$KM_RUN/runs/$1.log"
}

# km_view <rid>: the SCORER's own view of a run, for the transparency comparison -- its rc and timeout flag, then
# the sorted multiset of its FULL-masked ok and FAIL labels, a tagged line counted under the kind it would have
# had. Never raw bytes.
km_view() {
  /usr/bin/awk -F'\t' -v r="$1" '$1 == r { print "rc\t" $6 "/" $7 }' "$KM_RUN/runs.tsv"
  /usr/bin/awk -F'\t' -v r="$1" '$1 == r && ($2 == "ok" || $2 == "FAIL") { print $2 "\t" $4 }
    $1 == r && $2 == "TAG" && ($3 == "ok" || $3 == "FAIL") { print $3 "\t" $4 }' "$KM_RUN/lines.tsv" | LC_ALL=C sort
}

# km_same_run <rid a> <rid b>: 0 when the two runs have the same scorer view.
km_same_run() {
  [ -n "$1" ] && [ -n "$2" ] || return 1
  km_view "$1" > "$KM_RUN/cmp/a"; km_view "$2" > "$KM_RUN/cmp/b"
  [ -s "$KM_RUN/cmp/a" ] && cmp -s "$KM_RUN/cmp/a" "$KM_RUN/cmp/b"
}

# km_opaque_compute <fixture list>: rewrite opaque.tsv -- a fixture whose plain run matches neither overlaid base run.
km_opaque_compute() {
  local fx rp rb1 rb2
  : > "$KM_RUN/opaque.tsv.new"
  while IFS= read -r fx; do
    IFS="$KM_TAB" read -r rp rb1 rb2 <<EOF4
$(/usr/bin/awk -F'\t' -v f="$fx" '$3 == f && $2 == "plain" { p = $1 } $3 == f && $2 == "base" && $5 == 1 { a = $1 } $3 == f && $2 == "base" && $5 == 2 { b = $1 } END { print p "\t" a "\t" b }' "$KM_RUN/runs.tsv")
EOF4
    km_same_run "$rp" "$rb1" || km_same_run "$rp" "$rb2" || printf '%s\tplain %s differs from base %s and %s\n' "$fx" "$rp" "$rb1" "$rb2" >> "$KM_RUN/opaque.tsv.new"
  done < "$1"
  mv "$KM_RUN/opaque.tsv.new" "$KM_RUN/opaque.tsv"
}

# km_base_red: one line counting base-red fixtures, then one per fixture with its first FAIL or refusal line.
km_base_red() {
  local fx rid line n rc
  /usr/bin/awk -F'\t' '$2 == "base" && ($6 != 0 || $7 == 1) && !($3 in s) { s[$3] = 1; print $3 "\t" $1 "\t" $6 }' "$KM_RUN/runs.tsv" > "$KM_RUN/base-red.tsv"
  n="$(wc -l < "$KM_RUN/base-red.tsv" | tr -d ' ')"
  printf 'base-red: %s fixture(s)\n' "$n"
  while IFS="$KM_TAB" read -r fx rid rc; do
    line="$(/usr/bin/awk '/FAIL  |FIXTURE ERROR|FIXTURE BROKEN/ { print; exit }
      /^hermetic-run: / && !/: rc=/ && !/verdict/ && h == "" { h = $0 } END { if (h != "") print h }' "$KM_RUN/runs/$rid.log" | head -1)"
    printf '  %s (rc %s): %s\n' "$fx" "$rc" "${line:-no FAIL line}"
  done < "$KM_RUN/base-red.tsv"
}

# ============================================================================================
# THE SCORER. stage A: needs nulls; B: needs re-runs; C: final rows. Inputs: sites, runs, lines, the
# static-read fixtures (statics.tsv) and the no-verdict fixtures (noverdict.txt).
# ============================================================================================
km_score() { # <rundir> <stage> <outdir>
  local run="$1" od="$3"
  mkdir -p "$od" || return 1
  /usr/bin/awk -v stage="$2" -v od="$od" '
  BEGIN { FS = OFS = "\t"; KF = od "/kills.tsv"; VF = od "/verdicts.tsv"; MF = od "/mutants.tsv"; NF_ = od "/needs.tsv"
          UF = od "/unstable.tsv"; XF = od "/flags.tsv"; printf "" > KF; printf "" > VF; printf "" > MF; printf "" > NF_; printf "" > UF; printf "" > XF }
  # The input is named by its ARGV position, never by counting files: an EMPTY input (no sites, no static
  # readers, no no-verdict fixtures) has no FNR == 1 and would shift every later file into the wrong role.
  FNR == 1 { fi = 0; for (a = 1; a < ARGC; a++) if (ARGV[a] == FILENAME) fi = a }
  fi == 1 { if ($6 == "LIVE") { nm++; M[nm] = $1; mf[$1] = $2 } next }
  fi == 2 { R = $1; rrc[R] = $6; rto[R] = $7
    if ($2 == "base") { if ($5 == 1) b1[$3] = R; else b2[$3] = R; if (!($3 in fxs)) { fxs[$3] = 1; FX[++nfx] = $3 } }
    else if ($2 == "mutant") mr[$4, $3] = R
    else if ($2 == "null") nr[$3, $4] = R
    else if ($2 == "rerun") rr[$4, $3] = R
    else if ($2 == "plain") pl[$3] = R
    next }
  fi == 3 { R = $1
    if ($2 == "ok") { k = ++nok[R]; okw[R, k] = $3; okf[R, k] = $4 }
    else if ($2 == "FAIL") nfail[R]++
    else if ($2 == "BRK") nbrk[R]++
    else if ($2 == "NOSRC") nsrc[R]++
    else if ($2 == "FORKFAIL") nff[R]++
    next }
  fi == 4 { st[$1] = 1; next }
  fi == 5 { if ($1 != "") nv[$1] = 1; next }
  fi == 6 { if ($1 != "") opq[$1] = 1; next }
  function istimeout(R) { return (rto[R] == 1) }
  # refused(R): an overlaid run of a lib/mutant.sh sourcer with no SOURCED record. Read on BASE runs only (nsb):
  # a mutant run may exit before it reaches the source line, and that exit is the kill.
  function refused(R) { return (nsrc[R] > 0) }
  function forkfail(R) { return (nff[R] > 0) }
  function isbrk(R) { return ((rrc[R] != 0 && rrc[R] != 1) || nbrk[R] > 0) }
  function kind(fx, m) { return (((fx SUBSEP mf[m]) in bs) || (fx in st)) ? "static-text" : "behavioural" }
  # -1 timeout or fork failure (never a kill), 0 green, 1 attributed or unattributed red, 2 RED-BROKEN or PLAIN-RED
  # (a fixture-level kill with no credit of its own)
  function eval_run(R, fx, m, emit,   i, j, L, W, nl, sfx, cred, nf, cls) {
    if (istimeout(R)) { if (emit) { print m, fx, "-", "TIMEOUT", "-" > KF; print "TIMEOUT", m, fx > XF } return -1 }
    if (forkfail(R)) { if (emit) { print m, fx, "-", "FORK-FAIL", "-" > KF; print "FORK-FAIL", m, fx > XF } return -1 }
    if (fx in opq) { if (rrc[R] != 0) { if (emit) print m, fx, "-", "PLAIN-RED", "-" > KF; return 2 } return 0 }
    if (isbrk(R)) { if (emit) print m, fx, "-", "RED-BROKEN", kind(fx, m) > KF; return 2 }
    if (rrc[R] == 0) return 0
    split("", cm); split("", cmw); split("", sn); split("", snw); split("", lost); split("", isl)
    for (i = 1; i <= nok[R]; i++) { cm[okf[R, i]]++; cmw[okw[R, i]]++ }
    nl = 0
    for (j = 1; j <= nbo[fx]; j++) {
      L = bo[fx, j]; W = bow[fx, j]; sn[L]++; snw[W]++
      if (sn[L] > cm[L] + 0) { lost[++nl] = j; isl[j] = 1 }
      else if (snw[W] > cmw[W] + 0) { if (emit) print m, fx, L, "RELABEL", "-" > KF }
    }
    sfx = nbo[fx] + 1; while (sfx > 1 && ((sfx - 1) in isl)) sfx--
    nf = nfail[R] + 0; cred = 0
    for (i = 1; i <= nl; i++) { j = lost[i]
      if (cred < nf) { cred++; cls = "KILL" } else if (j >= sfx) cls = "TRUNCATED"; else cls = "UNATTRIBUTED"
      if (emit) print m, fx, bo[fx, j], cls, (cls == "KILL" ? kind(fx, m) : "-") > KF }
    if (cred == 0 && emit) print m, fx, "-", "RED-UNATTRIBUTED", kind(fx, m) > KF
    return 1
  }
  # TWO SETS, AND EACH READER NAMES ITS OWN.
  #   blk[m, f]  every red kill of any kind (behavioural, static-text, RED-BROKEN, PLAIN-RED): it BLOCKS UNIQUE.
  #              Read by others(), so by the UNIQUE test, the unique witnesses, and the stage-B re-run choice.
  #   E[m, f]    a kill that can SUPPLY COVERED: behavioural (never static-text) and never an OVERLAY-OPAQUE
  #              PLAIN-RED kill of a fixture that has no null run and is typically red on any byte change.
  #              Read ONLY by the greedy cover set R.
  # others(m, X): the blocking co-killers of m other than X.
  function others(m, X,   z, Z, c) { c = 0; oy = ""; for (z = 1; z <= nfx; z++) { Z = FX[z]; if (Z != X && ((m, Z) in K) && blk[m, Z]) { c++; oy = Z } } return c }
  END {
    for (x = 1; x <= nfx; x++) { f = FX[x]; B1 = b1[f]; B2 = b2[f]
      nsb[f] = (B1 != "" && refused(B1)) || (B2 != "" && refused(B2))
      ffb[f] = (B1 != "" && forkfail(B1)) || (B2 != "" && forkfail(B2))
      bok[f] = (B1 != "" && B2 != "" && !istimeout(B1) && !istimeout(B2) && !isbrk(B1) && !isbrk(B2) && rrc[B1] == 0 && rrc[B2] == 0 \
                && !nsb[f] && !ffb[f] && !(f in opq))
      # an OPAQUE fixture is scored on its PLAIN runs, as a co-killer only, when its plain base run is green
      P0 = pl[f]; sc[f] = bok[f] || ((f in opq) && P0 != "" && rrc[P0] == 0 && !istimeout(P0) && !forkfail(P0))
      if (!bok[f]) continue
      split("", c1); split("", c2)
      for (i = 1; i <= nok[B1]; i++) c1[okf[B1, i]]++
      for (i = 1; i <= nok[B2]; i++) c2[okf[B2, i]]++
      for (L in c1) if (c1[L] != c2[L] + 0) { un[f, L] = 1; print f, L, c1[L], c2[L] + 0 > UF }
      for (L in c2) if (!(L in c1)) { un[f, L] = 1; print f, L, 0, c2[L] > UF }
      n = 0; for (i = 1; i <= nok[B1]; i++) { L = okf[B1, i]; if ((f SUBSEP L) in un) continue; n++; bo[f, n] = L; bow[f, n] = okw[B1, i] }
      nbo[f] = n
    }
    for (x = 1; x <= nfx; x++) { f = FX[x]; if (!bok[f]) continue
      for (k = 1; k <= nm; k++) { fn = mf[M[k]]; if ((f, fn) in nr) { R = nr[f, fn]; if (rrc[R] != 0 || rto[R] == 1 || forkfail(R)) bs[f, fn] = 1 } } }
    for (k = 1; k <= nm; k++) { m = M[k]
      for (x = 1; x <= nfx; x++) { f = FX[x]; if (!sc[f] || !((m, f) in mr)) continue
        v = eval_run(mr[m, f], f, m, 0); if (v >= 1) { K[m, f] = 1; if (v == 2) rb[m, f] = 1 } } }
    if (stage == "A") {
      for (k = 1; k <= nm; k++) for (x = 1; x <= nfx; x++) { m = M[k]; f = FX[x]
        if (((m, f) in K) && !(f in opq) && !((f, mf[m]) in done)) { done[f, mf[m]] = 1; print "null", f, mf[m] > NF_ } }
      exit 0 }
    # FLAKY: a re-run that does not reproduce the fixture-level kill scores nothing.
    for (k = 1; k <= nm; k++) for (x = 1; x <= nfx; x++) { m = M[k]; f = FX[x]
      if (((m, f) in K) && ((m, f) in rr) && eval_run(rr[m, f], f, m, 0) < 1) { delete K[m, f]; delete rb[m, f]; fl[m, f] = 1; print "FLAKY", m, f > XF } }
    # blk and E as above. own: the kill can make its OWN fixture UNIQUE or COVERED (RED-BROKEN, PLAIN-RED,
    # static-text and no-verdict never do).
    for (k = 1; k <= nm; k++) for (x = 1; x <= nfx; x++) { m = M[k]; f = FX[x]
      if ((m, f) in K) { blk[m, f] = 1; E[m, f] = (kind(f, m) == "behavioural") && !(f in opq)
        own[m, f] = !((m, f) in rb) && kind(f, m) == "behavioural" && !(f in nv); if (own[m, f]) nk[f]++ } }
    if (stage == "B") {
      for (k = 1; k <= nm; k++) { m = M[k]
        for (x = 1; x <= nfx; x++) { X = FX[x]; if (!((m, X) in K)) continue
          c = others(m, X)
          if (c == 1 && !((m, oy) in rr) && !((m, oy) in asked)) { asked[m, oy] = 1; print "rerun", oy, m > NF_ }
          if (c == 0 && own[m, X] && !((m, X) in rr) && !((m, X) in asked)) { asked[m, X] = 1; print "rerun", X, m > NF_ } } }
      exit 0 }
    for (b in bs) { split(b, pp, SUBSEP); print "BYTE-SENSITIVE", pp[1], pp[2] > XF }
    for (s in st) print "STATIC-READ", s > XF
    for (k = 1; k <= nm; k++) { m = M[k]
      for (x = 1; x <= nfx; x++) { f = FX[x]; if (!sc[f] || !((m, f) in mr)) continue
        if ((m, f) in fl) { print m, f, "-", "FLAKY", "-" > KF; continue }
        eval_run(mr[m, f], f, m, 1) } }
    for (x = 1; x <= nfx; x++) { X = FX[x]; if (!bok[X]) continue; wit[X] = ""
      for (k = 1; k <= nm; k++) { m = M[k]; if (!((m, X) in K) || !own[m, X]) continue
        if (others(m, X) == 0) { uq[X] = 1; wit[X] = wit[X] (wit[X] == "" ? "" : ",") m } } }
    nc = 0
    for (x = 1; x <= nfx; x++) { X = FX[x]; if (bok[X] && nk[X] > 0 && !(X in uq)) cand[++nc] = X }
    for (i = 2; i <= nc; i++) { j = i; while (j > 1 && (nk[cand[j-1]] > nk[cand[j]] || (nk[cand[j-1]] == nk[cand[j]] && cand[j-1] > cand[j]))) { t = cand[j]; cand[j] = cand[j-1]; cand[j-1] = t; j-- } }
    for (i = 1; i <= nc; i++) { X = cand[i]; okr = 1
      for (k = 1; k <= nm && okr; k++) { m = M[k]; if (!((m, X) in K) || !own[m, X]) continue
        out = 0; for (z = 1; z <= nfx; z++) { Z = FX[z]; if (Z != X && ((m, Z) in K) && E[m, Z] && !(Z in inR)) out = 1 }
        if (!out) okr = 0 }
      if (okr) inR[X] = 1 }
    for (x = 1; x <= nfx; x++) { X = FX[x]
      if (X in opq) { print X, "OVERLAY-OPAQUE", 0, "-", "-" > VF; continue }
      if (nsb[X]) { print X, "OVERLAY-NOT-SOURCED", 0, "-", "-" > VF; continue }
      if (ffb[X]) { print X, "FORK-FAIL", 0, "-", "-" > VF; continue }
      if (!bok[X]) { print X, "BROKEN", 0, "-", "-" > VF; continue }
      co = ""
      for (k = 1; k <= nm; k++) { m = M[k]; if (!((m, X) in K)) continue; s = ""
        for (z = 1; z <= nfx; z++) { Z = FX[z]; if (Z != X && ((m, Z) in K)) s = s (s == "" ? "" : "+") Z (((m, Z) in rb) ? "(RB)" : "") }
        co = co (co == "" ? "" : ";") m ":" (s == "" ? "-" : s) }
      if (X in nv) v = "NO-VERDICT"; else if (X in uq) v = "UNIQUE"; else if (X in inR) v = "COVERED-provisional"; else if (nk[X] > 0) v = "COVER-RETAINED-provisional"; else v = "NOKILL-provisional"
      print X, v, nk[X] + 0, (wit[X] == "" ? "-" : wit[X]), (co == "" ? "-" : co) > VF }
    for (k = 1; k <= nm; k++) { m = M[k]; s = ""
      for (x = 1; x <= nfx; x++) { f = FX[x]; if ((m, f) in K) s = s (s == "" ? "" : "+") f }
      print m, mf[m], (s == "" ? "SURVIVED" : "KILLED"), (s == "" ? "-" : s) > MF }
  }' "$run/sites.tsv" "$run/runs.tsv" "$run/lines.tsv" "$run/statics.tsv" "$run/noverdict.txt" "$run/opaque.tsv"
}

# km_static <worktree> <subject> <fixture list>: `<fixture>\t<file>` for each fixture whose run.sh, seed.sh, lib.sh
# or world.sh reads the subject AS DATA on a non-comment line: one of grep sed awk cmp shasum diff cat on the line,
# together with the subject's last two path components, or a variable assigned a value carrying them, or a
# variable naming the subject's parent directory followed by /<basename>. A bare basename is not enough: lib.sh
# names many files.
km_static() {
  local wt="$1" s="$2" fx f
  while IFS= read -r fx; do
    for f in run.sh seed.sh lib.sh world.sh; do
      [ -f "$wt/core/fixtures/$fx/$f" ] || continue
      if /usr/bin/awk -v s="$s" '
        BEGIN { n = split(s, p, "/"); base = p[n]; par = (n > 1) ? p[n-1] : ""; tail = (par != "") ? par "/" base : base
                tool = "(^|[^A-Za-z0-9_-])(grep|sed|awk|cmp|shasum|diff|cat)([^A-Za-z0-9_-]|$)" }
        { L[NR] = $0 }
        END {
          for (i = 1; i <= NR; i++) { l = L[i]; if (l ~ /^[ \t]*#/) continue
            if (match(l, /[A-Za-z_][A-Za-z0-9_]*=/)) { v = substr(l, RSTART, RLENGTH - 1); val = substr(l, RSTART + RLENGTH)
              if (index(val, tail) > 0) V1[v] = 1
              else if (par != "") { t = val; gsub(/["]/, "", t); sub(/[ \t;].*$/, "", t); if (t == par || substr(t, length(t) - length(par)) == "/" par) V2[v] = 1 } } }
          for (i = 1; i <= NR; i++) { l = L[i]; if (l ~ /^[ \t]*#/ || l !~ tool) continue
            if (index(l, tail) > 0) found = 1
            for (v in V1) if (index(l, "$" v) > 0 || index(l, "${" v "}") > 0) found = 1
            for (v in V2) if (index(l, "$" v "/" base) > 0 || index(l, "${" v "}/" base) > 0) found = 1 }
          exit found ? 0 : 1 }' "$wt/core/fixtures/$fx/$f"; then printf '%s\t%s\n' "$fx" "$f"; break; fi
    done
  done < "$3"
}

# km_matrix <fixture list file> <sites.tsv> [<pairs file>]: base, mutants, adaptive nulls and re-runs, final score.
# A pairs file (`<fixture>\t<mutant>` rows) restricts the mutant runs to those pairs; only the self-probe passes one.
km_matrix() {
  local fl="$1" st="$2" pairs="${3:-}" fx mut func ln op sha status var pos t n rp rb1 rb2
  cp "$st" "$KM_RUN/sites.tsv" || return 1
  [ "$fl" = "$KM_RUN/fixtures" ] || cp "$fl" "$KM_RUN/fixtures" || return 1
  t="$KM_RUN/tasks"; mkdir -p "$t"
  km_static "$KM_RUN/wt/w1" "$KM_SUBJ" "$fl" > "$KM_RUN/statics.tsv"
  : > "$t/base"; while IFS= read -r fx; do printf 'base\t%s\t-\t1\t-\nbase\t%s\t-\t2\t-\n' "$fx" "$fx" >> "$t/base"; done < "$fl"
  km_phase "$t/base"
  # THE SMOKE TWIN: the fixture the gross mutant turned red must be green unmutated, or the smoke proved nothing.
  if [ -n "${KM_SMOKE_RED:-}" ]; then
    /usr/bin/awk -F'\t' -v f="$KM_SMOKE_RED" '$2 == "base" && $3 == f && $6 == 0 && $7 == 0 { n++ } END { exit n == 2 ? 0 : 1 }' "$KM_RUN/runs.tsv" \
      || { km_say "smoke: $KM_SMOKE_RED went red under the gross mutant but its base runs are not both green, so the smoke proved nothing"
           km_base_red | tee "$KM_RUN/report.txt" >&2; return 3; }
  fi
  # TRANSPARENCY: one PLAIN run per fixture (the original lib/mutant.sh, no overlay). A fixture whose plain run
  # matches neither overlaid base run (rc, then output) is OVERLAY-OPAQUE: refused for scoring.
  : > "$t/plain"; while IFS= read -r fx; do printf 'plain\t%s\t-\t-\t-\n' "$fx" >> "$t/plain"; done < "$fl"
  km_phase "$t/plain"
  km_opaque_compute "$fl"
  # mutants run against fixtures whose two base runs were green, and against OVERLAY-OPAQUE fixtures whose plain
  # run was green -- those run PLAIN (km_worker) and count as fixture-level co-killers with no credit of their own
  : > "$t/mutant"
  while IFS= read -r fx; do
    if km_is_opaque "$fx"; then
      /usr/bin/awk -F'\t' -v f="$fx" '$2 == "plain" && $3 == f { g = ($6 == 0 && $7 == 0) } END { exit g ? 0 : 1 }' "$KM_RUN/runs.tsv" || continue
    else
      /usr/bin/awk -F'\t' -v f="$fx" '$2 == "base" && $3 == f && $6 == 0 && $7 == 0 { n++ } END { exit n == 2 ? 0 : 1 }' "$KM_RUN/runs.tsv" || continue
    fi
    while IFS="$KM_TAB" read -r mut func ln op sha status var pos; do
      [ "$status" = LIVE ] || continue
      if [ -n "$pairs" ]; then /usr/bin/grep -qxF "$fx$KM_TAB$mut" "$pairs" || continue; fi
      printf 'mutant\t%s\t%s\t-\t%s\n' "$fx" "$mut" "$var" >> "$t/mutant"
    done < "$KM_RUN/sites.tsv"
  done < "$fl"
  km_phase "$t/mutant"
  km_score "$KM_RUN" A "$KM_RUN/score.A" || return 1
  : > "$t/null"
  while IFS="$KM_TAB" read -r n fx func; do
    IFS="$KM_TAB" read -r ln pos <<EOF2
$(/usr/bin/awk -F'\t' -v f="$func" '$6 == "LIVE" && $2 == f { print $3 "\t" $8; exit }' "$KM_RUN/sites.tsv")
EOF2
    var="$KM_RUN/variants/null.$func"
    [ -f "$var" ] || km_apply "$KM_ORIG" "$ln" null "$pos" > "$var"
    if km_valid "$KM_ORIG" "$var"; then printf 'null\t%s\t%s\t-\t%s\n' "$fx" "$func" "$var" >> "$t/null"
    else printf 'NULL-STILLBORN\t%s\t%s\n' "$fx" "$func" >> "$KM_RUN/null-stillborn.tsv"; fi
  done < "$KM_RUN/score.A/needs.tsv"
  km_phase "$t/null"
  km_score "$KM_RUN" B "$KM_RUN/score.B" || return 1
  : > "$t/rerun"
  while IFS="$KM_TAB" read -r n fx mut; do
    var="$(/usr/bin/awk -F'\t' -v m="$mut" '$1 == m { print $7; exit }' "$KM_RUN/sites.tsv")"
    printf 'rerun\t%s\t%s\t-\t%s\n' "$fx" "$mut" "$var" >> "$t/rerun"
  done < "$KM_RUN/score.B/needs.tsv"
  km_phase "$t/rerun"
  km_score "$KM_RUN" C "$KM_RUN/score" || return 1
}

km_count() { /usr/bin/awk -F'\t' -v c="$2" '$2 == c { n++ } END { print n + 0 }' "$1"; }

# ============================================================================================
# SELF-PROBE
# ============================================================================================
km_probe_build() { # <toy dir> <state dir>
  local T="$1" S="$2" f
  mkdir -p "$T/core/scripts" "$T/core/fixtures/lib" "$T/core/toy" "$(dirname "$T/$KM_HOOK")" || return 1
  cp -p "$KM_ROOT/core/scripts/hermetic-run.sh" "$T/core/scripts/" || return 1
  [ -f "$KM_ROOT/core/scripts/core-paths.sh" ] && cp -p "$KM_ROOT/core/scripts/core-paths.sh" "$T/core/scripts/"
  cp -p "$KM_ROOT/$KM_HOOK" "$T/$KM_HOOK" || return 1
  cp -p "$KM_ROOT/core/fixtures/lib/mutant.sh" "$T/core/fixtures/lib/" || return 1
  cat > "$T/core/toy/subj.sh" <<'SUBJ'
# toy subject for the kill-matrix self-probe
k_a() {
  echo A
}
k_b() {
  echo B
}
k_d() {
  echo 3
}
k_e() {
  [ "$(k_d)" = 3 ] && echo E
}
k_f() {
  echo F
}
k_g() {
  echo G
}
k_h() {
  echo H
}
k_i() {
  echo I
}
k_j() {
  echo J
}
k_k() {
  echo K
}
k_m() {
  echo M
}
k_n() {
  echo N
}
k_o() {
  echo O
}
k_p() {
  echo P
}
k_q() {
  echo Q
}
k_r() {
  echo R
}
k_s() {
  echo S
}
k_t() {
  echo T
}
k_u() {
  echo U
}
k_v() {
  echo V
}
k_w() {
  echo W
}
k_y() {
  echo Y
}
SUBJ
  km_probe_fx() { # <name> <extra decl line or -> ; body on stdin
    mkdir -p "$T/core/fixtures/$1" || return 1
    { printf 'core/toy/subj.sh\n'; [ "$2" = - ] || printf '%s\n' "$2"; } > "$T/core/fixtures/$1/inputs.decl"
    { printf '#!/usr/bin/env bash\n'
      printf 'fails=0\n'
      printf "ok()  { printf '  ok    %%s\\\\n' \"\$1\"; }\n"
      printf "bad() { printf '  FAIL  %%s\\\\n' \"\$1\"; fails=\$((fails+1)); }\n"
      printf '. "$PWD/core/toy/subj.sh" || exit 2\n'
      cat
      printf '[ "$fails" -eq 0 ] || exit 1\nexit 0\n'; } > "$T/core/fixtures/$1/run.sh"
  }
  km_probe_fx fx-x - <<'B'
if [ "$(k_a)" = A ]; then ok x-a; else bad x-a; fi
if [ "$(k_b)" = B ]; then ok x-b; else bad x-b; fi
B
  km_probe_fx fx-y - <<'B'
if [ "$(k_a)" = A ]; then ok y-a; else bad y-a; fi
B
  km_probe_fx fx-z - <<'B'
ok "z-count $(k_d) rows"
if [ "$(k_e)" = E ]; then ok z-e; else bad z-e; fi
B
  km_probe_fx fx-t - <<'B'
if [ "$(k_f)" = F ]; then ok t-one; else bad t-one; exit 1; fi
ok t-two
ok t-three
B
  km_probe_fx fx-n core/fixtures/lib/mutant.sh <<'B'
. "$PWD/core/fixtures/lib/mutant.sh" || exit 2
B_G=0
if [ "$(k_g)" = G ]; then ok n-g; B_G=1; else bad n-g; fi
mutant_killed "$B_G" MG "battery kills MG"
B
  km_probe_fx fx-r - <<'B'
[ "$(k_h)" = H ] || exit 1
ok r-h
B
  km_probe_fx fx-w - <<'B'
if [ "$(k_h)" = H ]; then ok w-h; else bad w-h; fi
B
  km_probe_fx fx-g - <<'B'
[ "$(k_i)" = I ] && ok g-i
:
B
  # the unstable label prints FIRST, so an unstable label left in the base order would take the credit
  km_probe_fx fx-u - <<B
if [ "\$(k_p)" != P ]; then :; elif [ -f "$S/u.flag" ]; then ok u-flap; ok u-flap; else : > "$S/u.flag"; ok u-flap; fi
if [ "\$(k_p)" = P ]; then ok u-p; else bad u-p; fi
B
  km_probe_fx fx-p - <<'B'
if [ "$(k_k)" = K ]; then ok p-k; else bad p-k; fi
B
  km_probe_fx fx-q - <<'B'
if [ "$(k_k)" = K ]; then ok q-k; else bad q-k; fi
B
  # fx-s reads the subject as DATA (static scan); fx-bs is byte-sensitive (red on the null); fx-c2 is behavioural
  km_probe_fx fx-s - <<'B'
if grep -q 'echo M' core/toy/subj.sh; then ok s-m; else bad s-m; fi
B
  printf 'grep\n' > "$T/core/fixtures/fx-s/tools.decl"
  km_probe_fx fx-bs - <<'B'
found=0
while IFS= read -r l; do [ "$l" = "  echo M" ] && found=1; done < core/toy/subj.sh
if [ "$found" = 1 ] && [ "$(k_m)" = M ]; then ok bs-m; else bad bs-m; fi
B
  km_probe_fx fx-c2 - <<'B'
if [ "$(k_m)" = M ]; then ok c2-m; else bad c2-m; fi
B
  # fx-fl is red the first time it sees the mutant and green after: its re-run must make the kill FLAKY
  km_probe_fx fx-fl - <<B
if [ "\$(k_n)" = N ]; then ok fl-n; elif [ -f "$S/fl.flag" ]; then ok fl-n; else : > "$S/fl.flag"; bad fl-n; fi
B
  km_probe_fx fx-b - <<'B'
if [ "$(k_o)" = O ]; then ok b-o; else bad "FIXTURE BROKEN: k_o drifted"; fi
B
  km_probe_fx fx-b2 - <<'B'
[ "$(k_o)" = O ] || exit 2
ok b2-o
B
  km_probe_fx fx-c - <<'B'
if [ "$(k_o)" = O ]; then ok c-o; else bad c-o; fi
B
  km_probe_fx fx-i - <<'B'
if [ "$(k_q)" = Q ]; then ok i-a; ok i-b; else fails=1; fi
ok i-c
B
  km_probe_fx fx-nb core/fixtures/lib/mutant.sh <<'B'
. "$PWD/core/fixtures/lib/mutant.sh" || exit 2
B_R=0
if [ "$(k_r)" = R ]; then ok nb-r; B_R=1; fi
mutant_killed "$B_R" MR "battery kills MR"
B
  # fx-hang never ends under M17, so the watchdog must kill it; fx-c3 kills M17 behaviourally and must stay
  # UNIQUE, because a timeout is never a co-killer (C15).
  km_probe_fx fx-hang - <<'B'
if [ "$(k_s)" = S ]; then ok h-s; else while :; do :; done; fi
B
  km_probe_fx fx-c3 - <<'B'
if [ "$(k_s)" = S ]; then ok c3-s; else bad c3-s; fi
B
  # fx-ov runs a CHILD that sources lib/mutant.sh and compares the child's stdout+stderr EXACTLY (C23): green
  # only while the overlay is byte-transparent.
  km_probe_fx fx-ov core/fixtures/lib/mutant.sh <<'B'
out="$(bash "$PWD/core/fixtures/fx-ov/child.sh" 2>&1)"
if [ "$out" = "  ok    child kill" ]; then ok ov-exact; else bad ov-exact; fi
B
  printf 'bash\n' > "$T/core/fixtures/fx-ov/tools.decl"
  { printf '#!/usr/bin/env bash\n'
    printf "ok()  { printf '  ok    %%s\\\\n' \"\$1\"; }\n"
    printf "bad() { printf '  FAIL  %%s\\\\n' \"\$1\"; }\n"
    printf '. "$PWD/core/fixtures/lib/mutant.sh" || exit 2\n'
    printf 'mutant_killed 1 MX "child kill"\n'; } > "$T/core/fixtures/fx-ov/child.sh"
  # fx-td refuses a TMPDIR longer than 60 characters (C24), as procsub-staged-refusal-boot-c refuses a long one
  km_probe_fx fx-td - <<'B'
if [ "${#TMPDIR}" -le 60 ]; then ok td-len; else bad "td-len ${#TMPDIR}"; fi
B
  # fx-nc has a NON-CANONICAL bad() (no leading blanks), as 21 of the real definitions do: its need_base line must
  # still be tagged from the side file, so the red run is RED-UNATTRIBUTED, never RED-BROKEN (C26)
  km_probe_fx fx-nc core/fixtures/lib/mutant.sh <<'B'
bad() { printf 'FAIL  %s\n' "$1"; fails=$((fails+1)); }
. "$PWD/core/fixtures/lib/mutant.sh" || exit 2
B_T=0
if [ "$(k_t)" = T ]; then ok nc-t; B_T=1; else bad nc-t; fi
mutant_killed "$B_T" MT "nc battery"
B
  # fx-e1 exits 1 and fx-e2 exits 2 BEFORE sourcing lib/mutant.sh under M19: a KILL and a RED-BROKEN (C27)
  km_probe_fx fx-e1 core/fixtures/lib/mutant.sh <<'B'
if [ "$(k_u)" = U ]; then ok e1-u; else bad e1-u; exit 1; fi
. "$PWD/core/fixtures/lib/mutant.sh" || exit 2
mutant_killed 1 MU "e1 battery"
B
  km_probe_fx fx-e2 core/fixtures/lib/mutant.sh <<'B'
[ "$(k_u)" = U ] || exit 2
. "$PWD/core/fixtures/lib/mutant.sh" || exit 2
ok e2-u
B
  # fx-op is OVERLAY-OPAQUE by construction (its label reads the overlay); its PLAIN mutant run under M20 is red,
  # so it is a co-killer of fx-c4, which therefore is not UNIQUE (C28)
  km_probe_fx fx-op core/fixtures/lib/mutant.sh <<'B'
if grep -q km_side core/fixtures/lib/mutant.sh; then ok op-overlaid; else ok op-plain; fi
if [ "$(k_v)" = V ]; then ok op-v; else bad op-v; fi
B
  printf 'grep\n' > "$T/core/fixtures/fx-op/tools.decl"
  km_probe_fx fx-c4 - <<'B'
if [ "$(k_v)" = V ]; then ok c4-v; else bad c4-v; fi
B
  # fx-ff prints a fork-failure signature under M21: FORK-FAIL, re-run once, never a kill (C29)
  km_probe_fx fx-ff - <<'B'
if [ "$(k_w)" = W ]; then ok ff-w; else echo "bash: fork: Resource temporarily unavailable"; bad ff-w; fi
B
  # fx-th is a TREE-HASHER: red on ANY byte change of the subject (so it would be red on a null too) and OPAQUE
  # (its label reads the overlay). With fx-c5, which holds the only behavioural kill of M22, it must block fx-c5's
  # UNIQUE and must never supply fx-c5's COVERED (C31). Builtins only: `$(< file)` reads without cat.
  km_probe_fx fx-th core/fixtures/lib/mutant.sh <<'B'
case "$(< core/fixtures/lib/mutant.sh)" in *km_side*) ok th-overlaid ;; *) ok th-plain ;; esac
if [ "$(< core/toy/subj.sh)" = "$(< core/fixtures/fx-th/subj.copy)" ]; then ok th-tree; else bad th-tree; fi
B
  cp "$T/core/toy/subj.sh" "$T/core/fixtures/fx-th/subj.copy" || return 1
  km_probe_fx fx-c5 - <<'B'
if [ "$(k_y)" = Y ]; then ok c5-y; else bad c5-y; fi
B
  ( cd "$T" && git init -q . && git add -A && git -c user.name=km -c user.email=km@localhost -c commit.gpgsign=false commit -q --no-verify -m toy ) > /dev/null 2>&1
}

# km_probe_cases <rundir> <scoredir>: one `PASS|FAIL <case>` line per scorer-dependent case.
km_probe_cases() {
  local R="$1" D="$2" k="$2/kills.tsv" v="$2/verdicts.tsv" m="$2/mutants.tsv" u="$2/unstable.tsv" x="$2/flags.tsv"
  vd() { /usr/bin/awk -F'\t' -v f="$1" '$1 == f { print $2 }' "$v"; }
  wt() { /usr/bin/awk -F'\t' -v f="$1" '$1 == f { print $4 }' "$v"; }
  row() { /usr/bin/awk -F'\t' -v a="$1" -v b="$2" -v c="$3" -v d="$4" '$1 == a && $2 == b && $3 == c && $4 == d { n++ } END { print n + 0 }' "$k"; }
  kd() { /usr/bin/awk -F'\t' -v a="$1" -v b="$2" '$1 == a && $2 == b && $5 != "-" { print $5; exit }' "$k"; }
  ms() { /usr/bin/awk -F'\t' -v a="$1" '$1 == a { print $3 }' "$m"; }
  flg() { /usr/bin/awk -F'\t' -v a="$1" -v b="$2" -v c="$3" '$1 == a && $2 == b && (c == "" || $3 == c) { n++ } END { print n + 0 }' "$x"; }
  res() { if [ "$2" = 1 ]; then printf 'PASS %s\n' "$1"; else printf 'FAIL %s\n' "$1"; fi; }
  notvc() { [ "$(vd "$1")" != UNIQUE ] && [ "$(vd "$1")" != COVERED-provisional ]; }
  local c
  c=0; [ "$(vd fx-y)" != UNIQUE ] && [ "$(vd fx-x)" = UNIQUE ] && case ",$(wt fx-x)," in *,M1,*) ;; *) c=1 ;; esac; res "C1 M1 killed by fx-x and fx-y makes neither UNIQUE" "$c"
  c=0; [ "$(vd fx-x)" = UNIQUE ] && [ "$(wt fx-x)" = M2 ] && c=1; res "C2 M2 killed by fx-x only makes fx-x UNIQUE" "$c"
  c=0; [ "$(vd fx-p)" != UNIQUE ] && [ "$(vd fx-q)" != UNIQUE ] && ! { [ "$(vd fx-p)" = COVERED-provisional ] && [ "$(vd fx-q)" = COVERED-provisional ]; } \
    && { [ "$(vd fx-p)" = COVERED-provisional ] || [ "$(vd fx-q)" = COVERED-provisional ]; } && c=1; res "C3 mutual-cover pair fx-p/fx-q never both in R" "$c"
  c=0; [ "$(row M4 fx-z 'z-count # rows' RELABEL)" = 1 ] && [ "$(row M4 fx-z z-e KILL)" = 1 ] && [ "$(row M4 fx-z 'z-count # rows' KILL)" = 0 ] && c=1; res "C4 relabel gives RELABEL, the kill goes to z-e" "$c"
  c=0; [ "$(row M5 fx-t t-one KILL)" = 1 ] && [ "$(row M5 fx-t t-two TRUNCATED)" = 1 ] && [ "$(row M5 fx-t t-three TRUNCATED)" = 1 ] && c=1; res "C5 exit-after-first-FAIL gives TRUNCATED" "$c"
  c=0; /usr/bin/awk -F'\t' '$1 == "M0" && $6 == "STILLBORN" { f = 1 } END { exit f ? 0 : 1 }' "$R/sites.tsv" && ! km_valid "$R/orig.subject" "$R/variants/M0" \
    && [ "$(/usr/bin/awk -F'\t' '$4 == "M0" { n++ } END { print n + 0 }' "$R/runs.tsv")" = 0 ] && c=1; res "C6 a syntax-breaking mutant is STILLBORN and never run" "$c"
  local m6
  m6="$R/runs/$(/usr/bin/awk -F'\t' '$2 == "mutant" && $3 == "fx-n" && $4 == "M6" { print $1; exit }' "$R/runs.tsv")"
  c=0; [ "$(row M6 fx-n n-g KILL)" = 1 ] && [ "$(row M6 fx-n - RED-BROKEN)" = 0 ] \
    && [ "$(/usr/bin/awk -F'\t' '$2 == "fx-n" && ($3 ~ /battery kills/ || $3 ~ /MUTANT MG/) { n++ } END { print n + 0 }' "$k")" = 0 ] \
    && /usr/bin/grep -qxF "SOURCED${KM_TAB}$KM_TOKEN" "$m6.side" && /usr/bin/grep -qxF "NB${KM_TAB}MG" "$m6.side" \
    && /usr/bin/grep -q '^  FAIL  FIXTURE BROKEN: MUTANT MG not scored' "$m6.log" && c=1
  res "C7 a need_base line, recorded in the side file, is excluded and the run is not BROKEN" "$c"
  c=0; [ "$(row M7 fx-r - RED-UNATTRIBUTED)" = 1 ] && [ "$(vd fx-w)" != UNIQUE ] && c=1; res "C8 red with no FAIL is RED-UNATTRIBUTED and blocks fx-w UNIQUE" "$c"
  c=0; [ "$(/usr/bin/awk -F'\t' '$2 == "fx-g" { n++ } END { print n + 0 }' "$k")" = 0 ] && [ "$(vd fx-g)" = NOKILL-provisional ] && c=1; res "C9 a green run with a missing label is no kill" "$c"
  c=0; /usr/bin/awk -F'\t' '$1 == "fx-u" && $2 == "u-flap" { f = 1 } END { exit f ? 0 : 1 }' "$u" && c=1; res "C10 an unstable label gives UNSTABLE" "$c"
  c=0; [ "$(ms M9)" = SURVIVED ] && [ "$(ms M1)" = KILLED ] && c=1; res "C11 a near-miss gives SURVIVED, beside a KILLED control" "$c"
  c=0; [ "$(vd fx-c2)" = COVER-RETAINED-provisional ] && notvc fx-bs && [ "$(flg BYTE-SENSITIVE fx-bs k_m)" = 1 ] && [ "$(kd M11 fx-bs)" = static-text ] && c=1
  res "C16 a null-red co-killer BLOCKS the behavioural killer UNIQUE but never supplies its COVERED (fx-c2 $(vd fx-c2))" "$c"
  c=0; [ "$(flg STATIC-READ fx-s '')" = 1 ] && [ "$(flg STATIC-READ fx-c2 '')" = 0 ] && [ "$(kd M11 fx-s)" = static-text ] && [ "$(kd M11 fx-c2)" = behavioural ] && notvc fx-s && c=1
  res "C17 a fixture reading the subject as data is classed static-text and makes nothing COVERED" "$c"
  c=0; [ "$(flg FLAKY M11 fx-c2)" = 0 ] && [ "$(flg FLAKY M12 fx-fl)" = 1 ] && [ "$(ms M12)" = SURVIVED ] && [ "$(vd fx-fl)" != UNIQUE ] \
    && [ "$(/usr/bin/awk -F'\t' '$2 == "rerun" && $3 == "fx-fl" && $4 == "M12" { n++ } END { print n + 0 }' "$R/runs.tsv")" = 1 ] && c=1
  res "C18 a lone kill is re-run, and one that does not reproduce is FLAKY and scores nothing" "$c"
  c=0; [ "$(row M13 fx-b - RED-BROKEN)" = 1 ] && [ "$(row M13 fx-b2 - RED-BROKEN)" = 1 ] && [ "$(row M13 fx-c c-o KILL)" = 1 ] && [ "$(vd fx-c)" != UNIQUE ] \
    && [ "$(ms M13)" = KILLED ] && [ "$(vd fx-b)" = NOKILL-provisional ] && [ "$(vd fx-b2)" = NOKILL-provisional ] && c=1
  res "C19 a BROKEN mutant run (rc 2 or an untagged FIXTURE BROKEN) is RED-BROKEN: it blocks fx-c UNIQUE and earns its own fixture nothing" "$c"
  c=0; [ "$(row M14 fx-u u-p KILL)" = 1 ] && [ "$(/usr/bin/awk -F'\t' '$2 == "fx-u" && $3 == "u-flap" { n++ } END { print n + 0 }' "$k")" = 0 ] && c=1
  res "C20 an unstable label whose count drops in a red run is never attributed" "$c"
  c=0; [ "$(row M15 fx-i i-a UNATTRIBUTED)" = 1 ] && [ "$(row M15 fx-i i-b UNATTRIBUTED)" = 1 ] && [ "$(row M15 fx-i - RED-UNATTRIBUTED)" = 1 ] && c=1
  res "C21 an interior lost label is UNATTRIBUTED, not TRUNCATED" "$c"
  c=0; [ "$(row M16 fx-nb - RED-UNATTRIBUTED)" = 1 ] && [ "$(row M16 fx-nb nb-r KILL)" = 0 ] && c=1
  res "C22 a tagged battery FAIL is never counted as a FAIL line" "$c"
  local hid hrc hpg halive
  hid="$(/usr/bin/awk -F'\t' '$2 == "mutant" && $3 == "fx-hang" && $4 == "M17" { print $1; exit }' "$R/runs.tsv")"
  hrc="$(/usr/bin/awk -F'\t' -v r="$hid" '$1 == r { print $6 "/" $7 }' "$R/runs.tsv")"
  hpg="$(cut -f2 "$R/runs/$hid.pgid" 2>/dev/null)"
  halive="$(ps -A -o pgid= | /usr/bin/awk -v g="${hpg:-none}" '$1 == g { c++ } END { print c + 0 }')"
  c=0; [ -n "$hid" ] && [ "$hrc" = 137/1 ] && [ -s "$R/runs/$hid.log.wd" ] && [ "$halive" = 0 ] && [ "$(row M17 fx-hang - TIMEOUT)" = 1 ] \
    && [ "$(flg TIMEOUT M17 fx-hang)" = 1 ] && [ "$(vd fx-c3)" = UNIQUE ] && [ "$(wt fx-c3)" = M17 ] && notvc fx-hang && c=1
  res "C15 the wall timeout kills the run by its pgid (rc/timeout $hrc, $halive members left), reads TIMEOUT, and is never a co-killer" "$c"
  local r26 p26
  r26="$(/usr/bin/awk -F'\t' '$2 == "mutant" && $3 == "fx-nc" && $4 == "M18" { print $1; exit }' "$R/runs.tsv")"
  p26="$(KM_RUN="$R" km_parse "$r26" fx-nc mutant)"
  c=0; [ -n "$r26" ] && [ "$(row M18 fx-nc - RED-UNATTRIBUTED)" = 1 ] && [ "$(row M18 fx-nc - RED-BROKEN)" = 0 ] \
    && printf '%s\n' "$p26" | /usr/bin/grep -q "${KM_TAB}TAG${KM_TAB}other${KM_TAB}" && ! printf '%s\n' "$p26" | /usr/bin/grep -q "${KM_TAB}BRK${KM_TAB}" && c=1
  res "C26 a need_base line printed by a NON-CANONICAL bad() is tagged from the side file, so the run is never RED-BROKEN" "$c"
  c=0; [ "$(row M19 fx-e1 'e#-u' KILL)" = 1 ] && [ "$(row M19 fx-e2 - RED-BROKEN)" = 1 ] && c=1
  res "C27 a mutant run that exits 1 or 2 BEFORE sourcing lib/mutant.sh scores KILL and RED-BROKEN, never a refusal" "$c"
  c=0; [ "$(vd fx-op)" = OVERLAY-OPAQUE ] && [ "$(row M20 fx-op - PLAIN-RED)" = 1 ] && [ "$(vd fx-c4)" != UNIQUE ] && [ "$(ms M20)" = KILLED ] && c=1
  res "C28 an OVERLAY-OPAQUE fixture runs its mutants PLAIN and its red one is a co-killer (fx-op $(vd fx-op), fx-c4 $(vd fx-c4))" "$c"
  c=0; [ "$(row M21 fx-ff - FORK-FAIL)" = 1 ] && [ "$(ms M21)" = SURVIVED ] && [ "$(vd fx-ff)" != UNIQUE ] \
    && [ "$(/usr/bin/awk -F'\t' '$2 == "mutant" && $3 == "fx-ff" && $4 == "M21" { n++ } END { print n + 0 }' "$R/runs.tsv")" = 2 ] && c=1
  res "C29 a run carrying a fork-failure signature is FORK-FAIL, re-run once, and never a kill" "$c"
  c=0; [ "$(vd fx-th)" = OVERLAY-OPAQUE ] && [ "$(row M22 fx-th - PLAIN-RED)" = 1 ] && [ "$(row M22 fx-c5 c#-y KILL)" = 1 ] \
    && [ "$(vd fx-c5)" != UNIQUE ] && [ "$(vd fx-c5)" != COVERED-provisional ] && c=1
  res "C31 a tree-hashing OPAQUE co-killer blocks UNIQUE but never supplies COVERED (fx-c5 $(vd fx-c5))" "$c"
}

# THE PATCH TABLE: deliberately broken scorers, applied by literal replacement to a copy of km_score and
# km_probe_cases and re-scored over the SAME recorded probe runs. Each must apply, and each must FAIL at least
# the named case (or any case). `name @@ required case @@ old text @@ new text`; <EMPTY> is the empty string.
km_probe_patches() {
  cat <<'PATCHES'
unique-ignores-cokillers @@ C1 @@ if (others(m, X) == 0) { uq[X] = 1 @@ if (1) { uq[X] = 1
no-full-mask @@ C4 @@ okf[R, k] = $4 @@ okf[R, k] = $3
truncation-never @@ C5 @@ else if (j >= sfx) cls = "TRUNCATED"; else cls = "UNATTRIBUTED" @@ else cls = "UNATTRIBUTED"
validity-skips-bash-n @@ C6 @@ bash -n "$2" 2>/dev/null @@ :
tags-as-broken @@ C7 @@ else if ($2 == "BRK") nbrk[R]++ @@ else if ($2 == "BRK" || $2 == "TAG") nbrk[R]++
green-kills @@ C9 @@ if (rrc[R] == 0) return 0 @@ if (0) return 0
unstable-never-detected @@ C10 @@ for (L in c1) if (c1[L] != c2[L] + 0) @@ for (L in c1) if (0)
survived-always @@ C11 @@ (s == "" ? "SURVIVED" : "KILLED") @@ "SURVIVED"
picker-allows-same-function @@ C12 @@ case " $got " in *" $func "*) continue ;; esac @@ :
scanner-reads-heredoc-bodies @@ C13 @@ if (hd != "") { @@ if (0) {
mask-keeps-digits @@ C14 @@ gsub(/[0-9]+/, "#", s);  @@ <EMPTY>
timeout-as-kill @@ C15 @@ print "TIMEOUT", m, fx > XF } return -1 } @@ print "TIMEOUT", m, fx > XF } return 1 }
byte-sensitive-ignored @@ C16 @@ ((fx SUBSEP mf[m]) in bs) || (fx in st) @@ (fx in st)
static-read-ignored @@ C17 @@ ((fx SUBSEP mf[m]) in bs) || (fx in st) @@ ((fx SUBSEP mf[m]) in bs)
flaky-kept @@ C18 @@ delete K[m, f]; delete rb[m, f]; fl[m, f] = 1;  @@ fl[m, f] = 1;
isbrk-ignores-nbrk @@ C19 @@  || nbrk[R] > 0) } @@ ) }
red-broken-dropped @@ C19 @@ "RED-BROKEN", kind(fx, m) > KF; return 2 } @@ "RED-BROKEN", kind(fx, m) > KF; return -1 }
red-broken-own @@ C19 @@ own[m, f] = !((m, f) in rb) && @@ own[m, f] =
unstable-attributed @@ C20 @@ if ((f SUBSEP L) in un) continue;  @@ <EMPTY>
all-losses-truncated @@ C21 @@ else if (j >= sfx) cls = "TRUNCATED"; else cls = "UNATTRIBUTED" @@ else cls = "TRUNCATED"
tag-as-fail @@ C22 @@ else if ($2 == "FAIL") nfail[R]++ @@ else if ($2 == "FAIL" || $2 == "TAG") nfail[R]++
side-mk-ignored @@ C14 @@ if (mk[l2] > 0) { @@ if (0) {
overlay-prints-to-stdout @@ C23 @@ printf "km_side SOURCED '%s'\n" "$3" @@ printf "km_side SOURCED '%s'; echo KM-OVERLAY-SOURCED\n" "$3"
tmpdir-under-out @@ C24 @@ KM_SHORT="$(mktemp -d /tmp/km.XXXXXX)" @@ KM_SHORT="$(mktemp -d "$run/km.XXXXXX")"
overlay-never-marks @@ C25 @@ printf "km_side SOURCED '%s'\n" "$3" @@ :
nb-prefix-bound @@ C26 @@ index($0, "FIXTURE BROKEN: MUTANT " n " ") > 0 @@ index($0, "  FAIL  FIXTURE BROKEN: MUTANT " n " ") == 1
refused-before-scoring @@ C27 @@ if (forkfail(R)) { if (emit) @@ if (refused(R)) return -1; if (forkfail(R)) { if (emit)
opaque-never-kills @@ C28 @@ print m, fx, "-", "PLAIN-RED", "-" > KF; return 2 } @@ print m, fx, "-", "PLAIN-RED", "-" > KF; return 0 }
forkfail-as-kill @@ C29 @@ print "FORK-FAIL", m, fx > XF } return -1 } @@ print "FORK-FAIL", m, fx > XF } return 1 }
rescore-no-opaque @@ C30 @@ [ "$pass" = 2 ] || km_opaque_compute "$rs/fixtures" @@ :
plain-red-supplies-covered @@ C31 @@ E[m, f] = (kind(f, m) == "behavioural") && !(f in opq) @@ E[m, f] = (kind(f, m) == "behavioural")
PATCHES
}

# km_probe_scantoy <file>: the scanner probe file. Kept out of km_probe_pure_cases because its body holds
# column-0 braces, which would end the patch loop's extraction of that function early.
km_probe_scantoy() {
  cat > "$1" <<'SCANTOY'
# scanner probe
s_awk() {
  awk '
    { x = 1 }    # PROT
    $1 == "a" && $2 == "b" { exit 0 }   # PROT
  ' "$1"
}
s_here() {
  cat <<EOF
  some text && more || stuff   PROT
  return 0 PROT
EOF
  echo after
}
s_hs() {
  grep -q x <<< "abc" && echo one
  read -r v <<<word || return 1
}
s_ar() {
  n=$((1 << 3)) && echo "$n"
  [ "$n" -gt 2 ] || return 0
}
s_one() { [ -n "$1" ] && return 0; }
s_last() {
  if [ -z "$1" ]; then
    echo empty
  fi
}
SCANTOY
}

# km_probe_pure_cases <probe dir> <work dir>: the harness cases that need no fixture run -- the site picker
# (C12), the scanner (C13) and the label parser (C14). Patchable like the scorer: the patch loop re-runs it
# with patched copies of km_select, km_scan, km_apply, km_valid and km_parse.
km_probe_pure_cases() {
  local P="$1" W="$2" c op line sel
  mkdir -p "$W/sel" || return 1
  km_probe_scantoy "$W/scan-toy.sh"
  # C12: the picker draws 4 LIVE sites in 4 distinct functions of a file where every eligible function but
  # one carries several candidate sites, so a picker that allowed two in one function could not reach 4.
  if sel="$(km_select "$W/scan-toy.sh" 1 "$W/sel")" \
     && [ "$(/usr/bin/awk -F'\t' '$6 == "LIVE" { f[$2] = 1; n++ } END { for (k in f) d++; print n "/" d }' "$W/sel/sites.tsv")" = 4/4 ]; then
    printf 'PASS C12 the selector draws 4 sites in 4 distinct functions (%s functions, %s eligible)\n' $sel
  else printf 'FAIL C12 the selector draws 4 sites in 4 distinct functions\n'; fi
  # C13: the scanner never sites a line inside a quoted awk body or a heredoc (lines marked PROT), is not
  # derailed by a here-string or an arithmetic shift, and every operator yields a valid variant.
  km_scan "$W/scan-toy.sh" > "$W/scan-toy.tsv"
  c=1
  [ "$(/usr/bin/awk -F'\t' '$1 == "F" { n++ } END { print n + 0 }' "$W/scan-toy.tsv")" = 6 ] || c=0
  /usr/bin/awk -F'\t' '$1 == "C" && $2 == "s_last" { f = 1 } END { exit f ? 0 : 1 }' "$W/scan-toy.tsv" || c=0
  /usr/bin/awk -F'\t' 'NR == FNR { if ($0 ~ /PROT/) p[FNR] = 1; next } $1 == "C" && ($3 in p) { bad = 1 } END { exit bad ? 1 : 0 }' "$W/scan-toy.sh" "$W/scan-toy.tsv" || c=0
  for op in negtest andor retexit colon; do
    line="$(/usr/bin/awk -F'\t' -v o="$op" '$1 == "C" && $4 == o { print $3 "\t" $5; exit }' "$W/scan-toy.tsv")"
    [ -n "$line" ] || { c=0; continue; }
    km_apply "$W/scan-toy.sh" "${line%%"$KM_TAB"*}" "$op" "${line#*"$KM_TAB"}" > "$W/scan-toy.$op" && km_valid "$W/scan-toy.sh" "$W/scan-toy.$op" || c=0
  done
  if [ "$c" = 1 ]; then printf 'PASS C13 the scanner skips quoted awk bodies and heredocs, survives <<< and $((<<)), and every operator yields a valid variant\n'
  else printf 'FAIL C13 the scanner skips quoted awk bodies and heredocs, survives <<< and $((<<)), and every operator yields a valid variant\n'; fi
  # C14: km_parse masks the scratch root, mktemp-shaped paths, bracketed lists and digits, takes its tags from
  # the side file only (an MK label and an NB need_base line), and reads an untagged FIXTURE BROKEN as BRK.
  km_parse synthetic - mutant > "$W/parse.out"
  printf 'synthetic\tok\tcopied <ROOT><P> [a, b] 42 rows\tcopied <ROOT><P> [] # rows\nsynthetic\tok\tscratch <P> ok\tscratch <P> ok\nsynthetic\tFAIL\tFIXTURE BROKEN: x\tFIXTURE BROKEN: x\nsynthetic\tBRK\t-\t-\nsynthetic\tTAG\tok\ty\nsynthetic\tTAG\tFAIL\tFIXTURE BROKEN: MUTANT MZ not scored -- seed\n' > "$W/parse.want"
  if cmp -s "$W/parse.out" "$W/parse.want"; then printf 'PASS C14 the label masks, side-file tags and BRK detection read as specified\n'
  else printf 'FAIL C14 the label masks, side-file tags and BRK detection read as specified (see %s)\n' "$W/parse.out"; fi
}

# km_probe_live_cases <toy repo> <dir>: the cases that need their own runs because the thing under test is the
# overlay or the run environment -- a mini matrix (fx-n, fx-ov, fx-td; no mutants) through km_setup, km_overlay
# and km_matrix in a subshell, so the patch loop can re-run it with patched copies of those.
km_probe_live_cases() {
  ( D="$2"
    km_setup "$1" HEAD "$D" 1 core/toy/subj.sh > /dev/null 2>&1 \
      || { printf 'FAIL C23 setup failed\nFAIL C24 setup failed\nFAIL C25 setup failed\n'; exit 0; }
    KM_TIMEOUT=20
    printf 'fx-n\nfx-ov\nfx-td\n' > "$D/fixtures"; : > "$D/none"
    km_matrix "$D/fixtures" "$D/none" "$D/none" > /dev/null 2>&1
    lv() { /usr/bin/awk -F'\t' -v f="$1" '$1 == f { print $2 }' "$D/score/verdicts.tsv"; }
    lb() { /usr/bin/awk -F'\t' -v f="$1" '$2 == "base" && $3 == f && $5 == 1 { print $1; exit }' "$D/runs.tsv"; }
    lrc() { /usr/bin/awk -F'\t' -v r="$1" '$1 == r { print $6 }' "$D/runs.tsv"; }
    v="$(lv fx-ov)"; r="$(lb fx-ov)"
    if [ "$v" != OVERLAY-OPAQUE ] && [ "$v" != BROKEN ] && [ -n "$v" ] && [ "$(lrc "$r")" = 0 ] \
       && /usr/bin/grep -qxF "SOURCED${KM_TAB}$KM_TOKEN" "$D/runs/$r.side" && /usr/bin/grep -qxF "MK${KM_TAB}child kill" "$D/runs/$r.side"; then
      printf 'PASS C23 the overlay is byte-transparent: a child sourcing lib/mutant.sh prints exactly what it would without it (fx-ov %s)\n' "$v"
    else printf 'FAIL C23 the overlay is byte-transparent (fx-ov %s)\n' "${v:-no verdict}"; fi
    v="$(lv fx-td)"
    if [ "$v" != BROKEN ] && [ "$v" != OVERLAY-OPAQUE ] && [ -n "$v" ] && /usr/bin/grep -Eqx '(/private)?/tmp/km\.[A-Za-z0-9]{6}' "$D/short.path"; then
      printf 'PASS C24 every run TMPDIR sits under one short /tmp/km.XXXXXX root (fx-td %s)\n' "$v"
    else printf 'FAIL C24 every run TMPDIR sits under one short /tmp/km.XXXXXX root (fx-td %s, root %s)\n' "${v:-no verdict}" "$(cat "$D/short.path" 2>/dev/null)"; fi
    v="$(lv fx-n)"; r="$(lb fx-n)"
    if [ "$v" = NOKILL-provisional ] && /usr/bin/grep -qxF "SOURCED${KM_TAB}$KM_TOKEN" "$D/runs/$r.side"; then
      printf 'PASS C25 a fixture sourcing lib/mutant.sh is scored only when its side file carries the sourced marker (fx-n %s)\n' "$v"
    else printf 'FAIL C25 a fixture sourcing lib/mutant.sh is scored only when its side file carries the sourced marker (fx-n %s)\n' "${v:-no verdict}"; fi
    km_short_cleanup > /dev/null )
}

# km_probe_rescore_case <probe dir>: C30 -- --rescore of the probe's own run dir, from its stored logs and side
# files alone, reproduces the live verdict and kill tables byte for byte and calls itself final.
km_probe_rescore_case() {
  local o="$1/rescore.out" d
  ( km_rescore "$1/run" ) > "$o" 2>&1
  d="$(/usr/bin/sed -n 's/^rescore dir: //p' "$o" | head -1)"
  if [ -n "$d" ] && cmp -s "$d/score/verdicts.tsv" "$1/run/score/verdicts.tsv" && cmp -s "$d/score/kills.tsv" "$1/run/score/kills.tsv" \
     && /usr/bin/grep -q 'every adaptive run this re-score asks for is in the stored run' "$o"; then
    printf 'PASS C30 --rescore from the stored logs and side files reproduces the verdict and kill tables and is final\n'
  else printf 'FAIL C30 --rescore from the stored logs and side files reproduces the verdict and kill tables and is final (see %s)\n' "$o"; fi
}

km_self_probe() {
  local P T S jobs line c fails tsave
  P="$(mktemp -d "$KM_OUT/probe.XXXXXX")" || return 1
  T="$P/toy"; S="$P/state"; mkdir -p "$T" "$S" || return 1
  km_probe_build "$T" "$S" || { km_say "self-probe: toy build failed"; return 1; }
  [ -d "$T/.git" ] || { km_say "self-probe: toy repo not created"; return 1; }
  jobs="$KM_JOBS"; [ "$jobs" -le 3 ] || jobs=3
  km_setup "$T" HEAD "$P/run" "$jobs" core/toy/subj.sh || { km_say "self-probe: setup failed"; return 1; }
  # explicit probe sites: line numbers are those of the toy subject above
  # M0 breaks the syntax (STILLBORN); M4 relabels; every other probe mutant changes one echo.
  local mut func ln txt var st
  while read -r mut func ln; do
    case "$mut" in M0) txt="  if" ;; M4) txt="  echo 4" ;; *) txt="  echo Z" ;; esac
    var="$P/run/variants/$mut"
    km_apply "$KM_ORIG" "$ln" set 1 "$txt" > "$var" || return 1
    if km_valid "$KM_ORIG" "$var"; then st=LIVE; else st=STILLBORN; fi
    printf '%s\t%s\t%s\tset\t%s\t%s\t%s\t1\n' "$mut" "$func" "$ln" "$(km_sha "$var")" "$st" "$var"
  done > "$P/sites.real.tsv" <<'SITES'
M0 k_b 6
M1 k_a 3
M2 k_b 6
M4 k_d 9
M5 k_f 15
M6 k_g 18
M7 k_h 21
M8 k_i 24
M9 k_j 27
M10 k_k 30
M11 k_m 33
M12 k_n 36
M13 k_o 39
M14 k_p 42
M15 k_q 45
M16 k_r 48
M17 k_s 51
M18 k_t 54
M19 k_u 57
M20 k_v 60
M21 k_w 63
M22 k_y 66
SITES
  [ "$(/usr/bin/awk -F'\t' '$6 == "LIVE" { n++ } END { print n + 0 }' "$P/sites.real.tsv")" = 21 ] \
    || { km_say "self-probe: the 21 live probe variants did not build"; return 1; }
  /usr/bin/awk '{ print }' <<'FXL' > "$P/fixtures"
fx-b
fx-b2
fx-bs
fx-c
fx-c2
fx-c3
fx-c4
fx-c5
fx-e1
fx-e2
fx-ff
fx-fl
fx-nc
fx-op
fx-g
fx-hang
fx-i
fx-n
fx-nb
fx-p
fx-q
fx-r
fx-s
fx-t
fx-th
fx-u
fx-w
fx-x
fx-y
fx-z
FXL
  # Each mutant runs against the fixtures that reach its function (and fx-x/fx-g beside the near-miss M9);
  # every other pair is green by construction, so the cross product would only spend runs.
  /usr/bin/awk '{ for (i = 2; i <= NF; i++) print $i "\t" $1 }' <<'PAIRS' > "$P/pairs"
M1 fx-x fx-y
M2 fx-x
M4 fx-z
M5 fx-t
M6 fx-n
M7 fx-r fx-w
M8 fx-g
M9 fx-x fx-g
M10 fx-p fx-q
M11 fx-s fx-bs fx-c2
M12 fx-fl
M13 fx-b fx-b2 fx-c
M14 fx-u
M15 fx-i
M16 fx-nb
M17 fx-hang fx-c3
M18 fx-nc
M19 fx-e1 fx-e2
M20 fx-op fx-c4
M21 fx-ff
M22 fx-th fx-c5
PAIRS
  # fx-hang loops forever under M17, so the probe runs with a short wall timeout (every other toy run takes
  # about a second); the watchdog must kill it and the scorer must read it TIMEOUT (C15).
  tsave="$KM_TIMEOUT"; KM_TIMEOUT=20
  km_matrix "$P/fixtures" "$P/sites.real.tsv" "$P/pairs" || { KM_TIMEOUT="$tsave"; km_say "self-probe: matrix failed"; return 1; }
  KM_TIMEOUT="$tsave"
  { printf '  ok    copied %s/tmp/x.123/f [a, b] 42 rows\n' "$P/run"
    printf '  ok    scratch /var/folders/zz/T/hermetic-run.AbC/sb ok\n'
    printf '  FAIL  FIXTURE BROKEN: x\n'
    printf '  ok    y\n'
    printf '  FAIL  FIXTURE BROKEN: MUTANT MZ not scored -- seed\n'; } > "$P/run/runs/synthetic.log"
  printf 'MK\ty\nNB\tMZ\n' > "$P/run/runs/synthetic.side"
  { km_probe_cases "$P/run" "$P/run/score"; km_probe_pure_cases "$P" "$P/pure"; km_probe_live_cases "$T" "$P/live"; km_probe_rescore_case "$P"; } > "$P/cases"
  # every probe run but the deliberate hang owned its process group, and no other watchdog fired
  local hid
  hid="$(/usr/bin/awk -F'\t' '$2 == "mutant" && $3 == "fx-hang" && $4 == "M17" { print $1; exit }' "$P/run/runs.tsv")"
  c="$(cat "$P/run/runs/"*.pgid | /usr/bin/awk -F'\t' '$2 != $1 && $2 != "exited" { n++ } END { print n + 0 }')"
  ls "$P/run/runs/"*.wd 2>/dev/null | /usr/bin/grep -vF "/$hid.log.wd" > "$P/wd.other"
  [ "$c" = 0 ] && [ ! -s "$P/wd.other" ] || printf 'FAIL C0 every probe run owned its process group and no unexpected watchdog fired (%s did not)\n' "$c" >> "$P/cases"
  printf 'self-probe (%s):\n' "$P" >&2
  /usr/bin/sed 's/^/  /' "$P/cases" >&2
  fails="$(/usr/bin/grep -c '^FAIL' "$P/cases")" || fails=0
  c="$(/usr/bin/grep -c '^PASS' "$P/cases")" || c=0
  [ "$fails" = 0 ] && [ "$c" = 31 ] || { km_say "self-probe: $fails case(s) failed, $c of 31 passed"; return 1; }
  # DISCRIMINATION: every patch must apply and fail its named case; together they must fail every case. A patch
  # named for C23-C25 is a LIVE patch (overlay, setup): it re-runs the live mini matrix with the patched copies.
  km_probe_patches > "$P/patches"
  local fns="km_scan km_apply km_valid km_select km_parse km_score km_overlay km_setup km_probe_cases km_probe_pure_cases km_probe_live_cases km_rescore km_probe_rescore_case" f
  : > "$P/score.src"
  for f in $fns; do /usr/bin/sed -n "/^$f() {/,/^}/p" "$KM_SELF" >> "$P/score.src"; done
  bash -n "$P/score.src" && ( . "$P/score.src" && for f in $fns; do declare -F "$f" > /dev/null || exit 1; done ) \
    || { km_say "self-probe: the patchable functions did not extract whole"; return 1; }
  local k=0 name req pf bad=0
  : > "$P/failed.union"
  printf 'self-probe patch table (patch -> cases it fails):\n' >&2
  while IFS= read -r line; do
    k=$((k + 1))
    name="${line%% @@ *}"; req="${line#* @@ }"; req="${req%% @@ *}"
    /usr/bin/awk -v k="$k" 'NR == FNR { if (FNR == k) { n = split($0, a, " @@ "); old = a[3]; nw = a[4]; if (nw == "<EMPTY>") nw = "" } next }
      !done && (i = index($0, old)) > 0 { $0 = substr($0, 1, i - 1) nw substr($0, i + length(old)); done = 1 }
      { print } END { exit done ? 0 : 3 }' "$P/patches" "$P/score.src" > "$P/score.patch.$k" \
      || { printf '  %-30s DID NOT APPLY\n' "$name" >&2; bad=1; continue; }
    case "$req" in
      C23|C24|C25) ( . "$P/score.patch.$k" && km_probe_live_cases "$T" "$P/live.patch.$k" ) > "$P/cases.patch.$k" 2>&1 ;;
      C30) ( . "$P/score.patch.$k" && km_probe_rescore_case "$P" ) > "$P/cases.patch.$k" 2>&1 ;;
      *) ( . "$P/score.patch.$k" && km_score "$P/run" C "$P/run/score.patch.$k" && km_probe_cases "$P/run" "$P/run/score.patch.$k"
           km_probe_pure_cases "$P" "$P/pure.patch.$k" ) > "$P/cases.patch.$k" 2>&1 ;;
    esac
    pf="$(/usr/bin/awk '$1 == "FAIL" { printf "%s%s", s, $2; s = " " }' "$P/cases.patch.$k")"
    printf '  %-30s -> %s\n' "$name" "${pf:-NOTHING}" >&2
    /usr/bin/awk '$1 == "FAIL" && ($2 == "C23" || $2 == "C24" || $2 == "C25") { sub(/^FAIL /, "     "); print }' "$P/cases.patch.$k" >&2
    for c in $pf; do printf '%s\n' "$c" >> "$P/failed.union"; done
    case " $pf " in *" $req "*) ;; *) bad=1 ;; esac
  done < "$P/patches"
  [ "$k" -gt 0 ] && [ "$bad" = 0 ] || { km_say "self-probe: a broken variant did not apply or did not fail its named case, so that case is not shown able to fail"; return 1; }
  /usr/bin/awk '{ print $2 }' "$P/cases" | LC_ALL=C sort -u > "$P/cases.all"
  LC_ALL=C sort -u "$P/failed.union" > "$P/failed.u"
  if ! cmp -s "$P/cases.all" "$P/failed.u"; then
    km_say "self-probe: case(s) no broken variant fails: $(/usr/bin/grep -vxF -f "$P/failed.u" "$P/cases.all" | tr '\n' ' ')"; return 1
  fi
  km_short_cleanup >&2
  printf 'self-probe: 31/31 cases PASS; %s broken variants each fail their named case, and every case is failed by at least one; runs: base %s plain %s mutant %s null %s rerun %s\n' \
    "$k" "$(km_count "$P/run/runs.tsv" base)" "$(km_count "$P/run/runs.tsv" plain)" "$(km_count "$P/run/runs.tsv" mutant)" \
    "$(km_count "$P/run/runs.tsv" null)" "$(km_count "$P/run/runs.tsv" rerun)" >&2
  return 0
}

# km_report_core <run dir> <score dir> [<excluded count>]: the verdict part of report.txt, shared with --rescore.
km_report_core() {
  local R="$1" S="$2" nx="${3:-0}" nub ku kr
  printf 'runs by class: base %s, plain %s, mutant %s, null %s, rerun %s, smoke %s, stillborn %s (never run)\n' \
    "$(km_count "$R/runs.tsv" base)" "$(km_count "$R/runs.tsv" plain)" "$(km_count "$R/runs.tsv" mutant)" "$(km_count "$R/runs.tsv" null)" \
    "$(km_count "$R/runs.tsv" rerun)" "$(km_count "$R/runs.tsv" smoke)" "$(/usr/bin/awk -F'\t' '$6 == "STILLBORN" { n++ } END { print n + 0 }' "$R/sites.tsv")"
  printf 'fork-fail runs: %s (each re-run once; a re-run that fails to fork again stays FORK-FAIL)\n' \
    "$(/usr/bin/awk -F'\t' '$2 == "FORKFAIL" && !($1 in s) { s[$1] = 1; n++ } END { print n + 0 }' "$R/lines.tsv")"
  printf '*** OVERLAY-OPAQUE: %s fixture(s) refused for scoring (plain run reads differently from both overlaid base runs); they run their mutants PLAIN as co-killers only: %s ***\n' \
    "$(wc -l < "$R/opaque.tsv" | tr -d ' ')" "$(cut -f1 "$R/opaque.tsv" | tr '\n' ' ')"
  printf '*** OVERLAY-NOT-SOURCED: %s fixture(s) refused (sources lib/mutant.sh, base side file carries no marker): %s ***\n' \
    "$(/usr/bin/awk -F'\t' '$2 == "OVERLAY-NOT-SOURCED" { n++ } END { print n + 0 }' "$S/verdicts.tsv")" \
    "$(/usr/bin/awk -F'\t' '$2 == "OVERLAY-NOT-SOURCED" { printf "%s ", $1 }' "$S/verdicts.tsv")"
  nub="$(/usr/bin/awk -F'\t' 'FILENAME ~ /verdicts/ && ($2 == "OVERLAY-OPAQUE" || $2 == "OVERLAY-NOT-SOURCED" || $2 == "BROKEN" || $2 == "FORK-FAIL") { s[$1] = 1 }
    FILENAME ~ /flags/ && ($1 == "TIMEOUT" || $1 == "FORK-FAIL") { s[$3] = 1 } END { for (k in s) n++; print n + 0 }' "$S/verdicts.tsv" "$S/flags.tsv")"
  if [ "$((nub + nx))" -gt 0 ]; then
    printf '*** UPPER BOUND: %s fixture(s) did not score fully (%s excluded; the rest OVERLAY-OPAQUE, OVERLAY-NOT-SOURCED, BROKEN or FORK-FAIL, or with a TIMEOUT or FORK-FAIL mutant run): every UNIQUE is an upper bound against the run set ***\n' "$((nub + nx))" "$nx"
  fi
  ( KM_RUN="$R"; km_base_red )
  /usr/bin/awk -F'\t' '{ c[$2]++ } END { printf "verdicts:"; for (v in c) printf " %s %d", v, c[v]; printf "\n" }' "$S/verdicts.tsv"
  printf 'mutants: SURVIVED %s of %s; FLAKY kills %s; RED-BROKEN runs %s; PLAIN-RED runs %s; TIMEOUT runs %s and FORK-FAIL runs %s (never kills); BYTE-SENSITIVE pairs %s; STATIC-READ fixtures %s; UNSTABLE labels %s\n' \
    "$(/usr/bin/awk -F'\t' '$3 == "SURVIVED" { n++ } END { print n + 0 }' "$S/mutants.tsv")" "$(wc -l < "$S/mutants.tsv" | tr -d ' ')" \
    "$(/usr/bin/awk -F'\t' '$1 == "FLAKY" { n++ } END { print n + 0 }' "$S/flags.tsv")" \
    "$(/usr/bin/awk -F'\t' '$4 == "RED-BROKEN" { n++ } END { print n + 0 }' "$S/kills.tsv")" \
    "$(/usr/bin/awk -F'\t' '$4 == "PLAIN-RED" { n++ } END { print n + 0 }' "$S/kills.tsv")" \
    "$(/usr/bin/awk -F'\t' '$1 == "TIMEOUT" { n++ } END { print n + 0 }' "$S/flags.tsv")" \
    "$(/usr/bin/awk -F'\t' '$1 == "FORK-FAIL" { n++ } END { print n + 0 }' "$S/flags.tsv")" \
    "$(/usr/bin/awk -F'\t' '$1 == "BYTE-SENSITIVE" { n++ } END { print n + 0 }' "$S/flags.tsv")" \
    "$(/usr/bin/awk -F'\t' '$1 == "STATIC-READ" { n++ } END { print n + 0 }' "$S/flags.tsv")" "$(wc -l < "$S/unstable.tsv" | tr -d ' ')"
  ku="$(/usr/bin/awk -F'\t' '$2 == "UNIQUE" { n++ } END { print n + 0 }' "$S/verdicts.tsv")"
  kr="$(wc -l < "$R/runs.tsv" | tr -d ' ')"
  if [ "$ku" -gt 0 ]; then printf 'runs per conclusive verdict: %s runs / %s UNIQUE = %s\n' "$kr" "$ku" "$((kr / ku))"
  else printf 'runs per conclusive verdict: %s runs / 0 UNIQUE = no conclusive verdict\n' "$kr"; fi
  printf 'ranking (fixture, mutants killed, verdict, unique witnesses, co-killers per mutant; (RB) = a RED-BROKEN or PLAIN-RED co-killer):\n'
  LC_ALL=C sort -t "$KM_TAB" -k3,3nr -k1,1 "$S/verdicts.tsv" | /usr/bin/awk -F'\t' '{ printf "  %-44s %s %-28s %s %s\n", $1, $3, $2, $4, $5 }'
  printf 'mutant rows:\n'; /usr/bin/awk -F'\t' '{ printf "  %s %s %s %s\n", $1, $2, $3, $4 }' "$S/mutants.tsv"
}

# km_rescore <run dir>: re-run the scorer from a finished run's STORED inputs -- every log re-parsed with its side
# file, OVERLAY-OPAQUE recomputed, stages A, B and C -- into <run dir>/rescore.<pid>, and print the verdict report.
# No fixture runs. When the stored runs do not cover the adaptive runs the new score asks for, it says so and the
# result is NOT final.
km_rescore() {
  local src rs rid cls fx mut rep rc to need
  src="$(cd "$1" 2>/dev/null && pwd -P)" || km_die "--rescore: $1 is not a directory"
  for f in runs.tsv sites.tsv token statics.tsv noverdict.txt fixtures mutant.orig; do
    [ -f "$src/$f" ] || km_die "--rescore: $src carries no $f, so it is not a kill-matrix run dir"
  done
  [ -d "$src/wt/w1/core/fixtures" ] || km_die "--rescore: the scratch worktree $src/wt/w1 is gone; the sourcer test reads it"
  rs="$(mktemp -d "$src/rescore.XXXXXX")" && mkdir -p "$rs/cmp" || km_die "--rescore: cannot create a rescore dir under $src"
  printf 'rescore dir: %s\n' "$rs"
  for f in runs.tsv sites.tsv token statics.tsv noverdict.txt fixtures; do cp "$src/$f" "$rs/$f" || km_die "--rescore: copy $f"; done
  ln -s "$src/runs" "$rs/runs" && ln -s "$src/wt" "$rs/wt" || km_die "--rescore: cannot link the stored runs"
  KM_RUN="$rs"; KM_TOKEN="$(cat "$rs/token")"
  # two passes: OVERLAY-OPAQUE is computed from the first parse, and decides how the second parses a run
  : > "$rs/opaque.tsv"
  for pass in 1 2; do
    : > "$rs/lines.tsv"
    while IFS="$KM_TAB" read -r rid cls fx mut rep rc to; do km_parse "$rid" "$fx" "$cls" >> "$rs/lines.tsv"; done < "$rs/runs.tsv"
    [ "$pass" = 2 ] || km_opaque_compute "$rs/fixtures"
  done
  km_score "$rs" A "$rs/score.A" && km_score "$rs" B "$rs/score.B" && km_score "$rs" C "$rs/score" || km_die "--rescore: the scorer failed"
  /usr/bin/awk -F'\t' 'NR == FNR { if ($2 == "null") have["null", $3, $4] = 1; next }
    $1 == "null" && !(("null", $2, $3) in have) { print "null\t" $2 "\t" $3 }' "$rs/runs.tsv" "$rs/score.A/needs.tsv" > "$rs/needs.missing"
  cat "$rs/score.B/needs.tsv" >> "$rs/needs.missing"
  need="$(wc -l < "$rs/needs.missing" | tr -d ' ')"
  {
    printf 'kill-matrix --rescore of %s (no fixture was run)\n' "$src"
    if [ "$need" -gt 0 ]; then
      printf '*** NOT FINAL: this re-score asks for %s adaptive run(s) the stored run does not hold, so its verdicts are provisional on them: ***\n' "$need"
      /usr/bin/sed 's/^/  /' "$rs/needs.missing"
    else
      printf 'every adaptive run this re-score asks for is in the stored run\n'
    fi
    km_report_core "$rs" "$rs/score" 0
    printf 'files: %s/{lines.tsv,opaque.tsv,score/}\n' "$rs"
  } | tee "$rs/report.txt"
}

# ============================================================================================
# MAIN
# ============================================================================================
if [ -n "$KM_RESCORE" ]; then km_rescore "$KM_RESCORE"; exit 0; fi
km_self_probe || km_die "self-probe failed; nothing was run against the real tree"
[ "$KM_PROBE_ONLY" = 0 ] || exit 0

KM_SHA_FULL="$(git -C "$KM_ROOT" rev-parse --verify -q "${KM_SHA}^{commit}")" || km_die "--sha $KM_SHA is not a commit"
git -C "$KM_ROOT" cat-file -e "${KM_SHA_FULL}:${KM_SUBJECT}" 2>/dev/null || km_die "subject $KM_SUBJECT is not tracked at $KM_SHA_FULL"
RUN="$KM_OUT/run"
km_setup "$KM_ROOT" "$KM_SHA_FULL" "$RUN" "$KM_JOBS" "$KM_SUBJECT" || km_die "setup failed"

# population, from the scratch worktree at the pinned sha
km_population "$RUN/wt/w1" "$KM_SUBJECT" "$KM_EXCLUDE" > "$RUN/population.tsv"
cut -f1 "$RUN/population.tsv" > "$RUN/fixtures"
KM_NPOP="$(wc -l < "$RUN/fixtures" | tr -d ' ')"
KM_NREQ="$(/usr/bin/awk -F'\t' '$2 == "required-only" { n++ } END { print n + 0 }' "$RUN/population.tsv")"
KM_CTRL_PATH="core/__kill_matrix_never_existed__/never.sh"
[ ! -e "$RUN/wt/w1/$KM_CTRL_PATH" ] || km_die "the never-existed control path exists"
KM_NCTRL="$(km_population "$RUN/wt/w1" "$KM_CTRL_PATH" "$KM_EXCLUDE" | wc -l | tr -d ' ')"
[ "$KM_NPOP" -gt 0 ] || km_die "no fixture declares $KM_SUBJECT (control $KM_CTRL_PATH: $KM_NCTRL)"
KM_NEXCL=0; for km_f in $KM_EXCLUDE; do KM_NEXCL=$((KM_NEXCL + 1)); done
KM_NNV=0
for km_f in $KM_NOVERDICT; do
  /usr/bin/grep -qxF "$km_f" "$RUN/fixtures" || km_die "--no-verdict $km_f is not in the run population"
  printf '%s\n' "$km_f" >> "$RUN/noverdict.txt"; KM_NNV=$((KM_NNV + 1))
done

# sites
mkdir -p "$RUN/select"
KM_FNS="$(km_select "$KM_ORIG" "$KM_SEED" "$RUN/select")" || km_die "fewer than 4 functions of $KM_SUBJECT carry a live mutation site"
for km_v in $(/usr/bin/awk -F'\t' '{ print $7 }' "$RUN/select/sites.tsv"); do cp "$km_v" "$RUN/variants/" || km_die "variant copy"; done
/usr/bin/awk -F'\t' -v d="$RUN/variants" 'BEGIN { OFS = "\t" } { n = split($7, p, "/"); $7 = d "/" p[n]; print }' "$RUN/select/sites.tsv" > "$RUN/sites.sel.tsv"

# smoke: gross mutant of the most-called function; a covering fixture must go red, and the overlay marker
# must be printed by a run that sources lib/mutant.sh.
KM_GF="$(/usr/bin/awk -F'\t' '$1 == "S" { s[$2] = $3 } $1 == "F" { c[$2] = $4; o[++n] = $2 }
  END { b = ""; for (i = 1; i <= n; i++) { f = o[i]; if (!(f in s)) continue; if (b == "" || c[f] > c[b]) b = f } if (b != "") print b "\t" s[b] "\t" c[b] }' "$RUN/select/scan.tsv")"
[ -n "$KM_GF" ] || km_die "smoke: no function of the subject has a statement line to replace"
IFS="$KM_TAB" read -r KM_GFN KM_GLN KM_GCALLS <<EOF3
$KM_GF
EOF3
km_apply "$KM_ORIG" "$KM_GLN" gross 1 > "$RUN/variants/gross" && km_valid "$KM_ORIG" "$RUN/variants/gross" || km_die "smoke: the gross mutant is not valid"
: > "$RUN/smoke.order"
while IFS= read -r km_f; do /usr/bin/grep -qF 'lib/mutant.sh' "$RUN/wt/w1/core/fixtures/$km_f/run.sh" 2>/dev/null && printf '%s\n' "$km_f"; done < "$RUN/fixtures" | head -1 >> "$RUN/smoke.order"
if [ -s "$RUN/smoke.order" ]; then /usr/bin/grep -vxF -f "$RUN/smoke.order" "$RUN/fixtures" >> "$RUN/smoke.order" || :
else cp "$RUN/fixtures" "$RUN/smoke.order"; fi
KM_SMOKE_RED=""; KM_SMOKE_MARK=0; KM_SMOKE_N=0; KM_SMOKE_MARKFX="$(head -1 "$RUN/smoke.order")"
KM_SMOKE_MAX="$KM_NPOP"
while IFS= read -r km_f; do
  [ "$KM_SMOKE_N" -lt "$KM_SMOKE_MAX" ] || break
  printf 'smoke\t%s\tgross\t-\t%s\n' "$km_f" "$RUN/variants/gross" > "$RUN/smoke.task.$KM_SMOKE_N"
  KM_NJ_SAVE="$KM_NJ"; KM_NJ=1
  km_phase "$RUN/smoke.task.$KM_SMOKE_N"
  KM_NJ="$KM_NJ_SAVE"
  KM_SMOKE_N=$((KM_SMOKE_N + 1))
  km_rid="$(tail -1 "$RUN/runs.tsv" | cut -f1)"; km_rc="$(tail -1 "$RUN/runs.tsv" | cut -f6)"
  /usr/bin/grep -qxF "SOURCED${KM_TAB}$KM_TOKEN" "$RUN/runs/$km_rid.side" && KM_SMOKE_MARK=1
  if [ "$km_rc" = 1 ]; then KM_SMOKE_RED="$km_f"; fi
  [ -n "$KM_SMOKE_RED" ] && { [ "$KM_SMOKE_MARK" = 1 ] || ! /usr/bin/grep -qF 'lib/mutant.sh' "$RUN/wt/w1/core/fixtures/$KM_SMOKE_MARKFX/run.sh"; } && break
done < "$RUN/smoke.order"
[ -n "$KM_SMOKE_RED" ] || km_die "smoke: the gross mutant ($KM_GFN line $KM_GLN -> exit 99) turned no covering fixture red in $KM_SMOKE_N run(s)"
if /usr/bin/grep -qF 'lib/mutant.sh' "$RUN/wt/w1/core/fixtures/$KM_SMOKE_MARKFX/run.sh" 2>/dev/null; then
  [ "$KM_SMOKE_MARK" = 1 ] || km_die "smoke: $KM_SMOKE_MARKFX sources lib/mutant.sh but never printed the overlay marker, so the overlay is not the copy sourced"
  KM_MARK_NOTE="marker seen from $KM_SMOKE_MARKFX"
else
  KM_MARK_NOTE="no covering fixture sources lib/mutant.sh, so the overlay cannot matter and no marker is owed"
fi

km_matrix "$RUN/fixtures" "$RUN/sites.sel.tsv" || km_die "matrix failed"

# ============================================================================================
# REPORT
# ============================================================================================
S="$RUN/score"
{
  printf 'kill-matrix: subject %s at %s, seed %s, jobs %s\n' "$KM_SUBJECT" "$KM_SHA_FULL" "$KM_SEED" "$KM_JOBS"
  printf 'population: %s fixture(s) declare the subject or a directory prefix of it (%s only through a REQUIRED ! line); control %s: %s; excluded: %s\n' \
    "$KM_NPOP" "$KM_NREQ" "$KM_CTRL_PATH" "$KM_NCTRL" "${KM_EXCLUDE:-none}"
  [ "$KM_NEXCL" = 0 ] || printf '*** %s fixtures excluded: UNIQUE is an upper bound against the run set (an excluded fixture never ran, so it is no co-killer) ***\n' "$KM_NEXCL"
  [ "$KM_NNV" = 0 ] || printf 'no-verdict: %s fixture(s) ran and count as co-killers but get no verdict: %s\n' "$KM_NNV" "$KM_NOVERDICT"
  set -- $KM_FNS
  printf 'sites: 4 of %s functions (%s carry a candidate site); STILLBORN draws: %s\n' "$1" "$2" "$(/usr/bin/awk -F'\t' '$6 == "STILLBORN" { n++ } END { print n + 0 }' "$RUN/sites.tsv")"
  /usr/bin/awk -F'\t' '{ printf "  %-4s %-10s %s line %s op %s sha256 %s\n", $1, $6, $2, $3, $4, $5 }' "$RUN/sites.tsv"
  printf 'smoke: gross mutant %s line %s (%s call sites) -> exit 99; red: %s; %s; %s run(s)\n' "$KM_GFN" "$KM_GLN" "$KM_GCALLS" "$KM_SMOKE_RED" "$KM_MARK_NOTE" "$KM_SMOKE_N"
  km_report_core "$RUN" "$S" "$KM_NEXCL"
  printf 'provisional verdicts are on 4 sampled sites of %s functions; that ceiling is a property of the design, not of fixture quality\n' "$1"
  printf 'files: %s/{runs,lines}.tsv, %s/sites.tsv, %s/{kills,verdicts,mutants,flags,unstable}.tsv, logs in %s/runs\n' "$RUN" "$RUN" "$S" "$RUN"
  printf 'scratch worktrees left in place under %s/wt (remove with git worktree remove after reading)\n' "$RUN"
  printf 'operator tool: runs on no gate or hook\n'
  km_short_cleanup
} | tee "$RUN/report.txt"
exit 0
