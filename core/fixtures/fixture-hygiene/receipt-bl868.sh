#!/usr/bin/env bash
# core/fixtures/fixture-hygiene/receipt-bl868.sh -- the BL-868 backlog receipt: no fixture verdict or invocation
# count may depend on load.
#
# Exit 0: the tree carries none of the three classes below. Exit 1: at least one offender row was printed, one per
# line, `<class>\t<path>:<line>\t<text>`, or a stale allowlist row `W-ALLOW-STALE\t<path>\t<id>\t<why>`. Exit 9: could
# not measure (no root, git failed, an empty corpus, the ledger or a referencing file unreadable, a self-probe red, a
# malformed or duplicate allowlist row in this file, the hygiene validator broken or its H3 self-probe absent). Nothing else exits 1:
# every internal failure is routed to 9, so R7 of scripts/validate-backlog-receipts.sh never reads a broken receipt
# as STILL-LIVE.
#
# WHY IT LIVES IN fixture-hygiene. It reads three things: scripts/validate-fixture-hygiene.sh (class H3), the tracked
# core/fixtures/**/*.sh corpus (class W), and every tracked core/fixtures/*/invocations.decl (class PM). The first is
# the subject fixture-hygiene already owns, and the second is that validator's own corpus. Like it, the fixture is
# .dist-only, so a consumer never receives a receipt calling a distribution-only script.
#
# CLASS H3 -- an `sh` start the invocation counter cannot see (item 7). DELEGATED, never restated: this runs
#   scripts/validate-fixture-hygiene.sh and reports the rows of its `FAIL H3:` block, nothing from H1, H2, H5 or M4.
#   It requires the validator's `self-probe H3: ok` line, so a validator whose H3 probe stopped running is a 9.
#   STATED LIMIT, a property of whichever H3 the tree carries: at the commit this receipt shipped on, H3 refuses only
#   `sh`, `/bin/sh` or `/usr/bin/sh` in command position (and `| sh`). A written `#!/bin/sh` stub that is executed
#   directly, by `exec`, or by a PATH lookup is NOT seen until H3's stub join lands; when it does, this receipt sees
#   it with no edit here.
#
# CLASS W -- a BOUNDED real-time wait (item 8): elapsed time or an iteration bound can decide a verdict. An UNBOUNDED
#   condition wait (`until cond; do sleep 0.1; done`, `while ! [ -e f ]; do sleep 0.05; done`) is allowed and reads 0.
#   Corpus: `git ls-files -- 'core/fixtures/**/*.sh'`, counted (zero is a 9), minus INERT receipts (see the
#   false-positive paragraph below): a `receipt*.sh` that no live verify line and no runner names.
#   Each line is masked: single- and double-quoted bytes become X, with the quote state carried across lines, and a
#   comment is dropped. So sed mutant text, a JSON transcript seed and a message are data. Two kinds of string are
#   EXECUTED and are scanned as code: the body of a `-c '...'` (bash -c, sh -c) and a printf string that writes a stub
#   (`printf '#!...\n...'`, split on `\n`). A heredoc body is scanned as code, line by line with its own quote state,
#   when the heredoc WRITES A FILE (`cat > f <<'EOF'`, `tee f`) or feeds a shell, because the fixtures write their
#   executed stubs that way; a heredoc read into a variable (`read -r -d '' X <<'E'`, this file's own seeds and awk)
#   or fed to another program is data.
#   The rows:
#     W-SLEEP  `sleep N` (or /bin/sleep, /usr/bin/sleep; N a literal above zero or a `$` value) OUTSIDE every loop: a
#              fixed pause, a race delay or a hang target. `sleep "$@"` / `sleep "$*"` (a pass-through shim) is not.
#     W-CLOCK  `$SECONDS`, `${SECONDS}` or `SECONDS` inside `(( ))` on a line that COMPARES (-lt -le -gt -ge, or
#              `<`/`>` in the arithmetic); or `date +%s` on a line that compares or opens a while/until loop. A start
#              record (`s=$SECONDS`), a bare `SECONDS|` in a variable-name list, and `$(( $(date +%s) - 30 ))`
#              assigned as a seeded timestamp compare nothing.
#     W-BOUND  a while/until loop that both increments a counter (`v=$((v + 1))`, `((v++))`, `((v+=1))`) and compares
#              it (`$v -lt|-le|-gt|-ge|-eq`), in its header OR its body -- a header cap and an in-body watchdog
#              (`[ "$idle" -ge 50 ] && break`) alike -- when a sleep runs directly inside it; and a `for` over a
#              COUNTED list (`$(seq ...)`, `{1..N}`, literal numbers) with a sleep directly inside it. A `for` over a
#              data list (`for s in $SCEN`) is iteration, not a bound. One row, at the loop header.
#     W-TIMEOUT `timeout N` (a literal or `$` value) in code, and `read -t` outside every loop, or inside one when its
#              status or variable can decide anything: conditioned (if/while/until/elif, `!`, && or ||, `$( )`), its
#              `$?` read on the next line, or its variable read anywhere in the file.
#   A sleep INSIDE a loop is that loop's poll quantum and is judged only through the loop header (W-BOUND, W-CLOCK); so
#   is an unchecked `read -t` whose variable nothing reads (a pause on a held fifo). A counter (`let v++` counts too)
#   reset to an integer at the START of the loop body (`ul=0; ...`) is a per-pass count, never an iteration bound.
#   STATED LIMITS: a sleep paced inside an unbounded while-loop body (`while read l; do x; sleep 1; done`) is not
#   seen; nor a counter compared only through arithmetic (`(( n > 50 ))`, `"$((n % 10))" -eq 0`); nor a bound held
#   in a helper function the loop calls; nor a stub written by a printf whose string does not start with `#!`, by `echo`, or assembled in a
#   variable; nor a wait in a file outside core/fixtures (core/fixtures/lib is in); nor a timeout reached through a
#   variable command name (`TO=timeout; $TO 30 cmd`), `gtimeout`, or an alarm in another language (`perl -e 'alarm 5'`),
#   none of which the corpus uses today. `find -newer` and `-nt` are NOT
#   rows: they compare mtimes and wait for nothing, and the elapsed wait that once ordered those mtimes is a sleep,
#   which W-SLEEP sees (the D4 grammar lists them as SITES to read; this receipt narrows them out on that ground).
#   FALSE-POSITIVE SET, how it reached its value: measured on b248-b248-loadfree at 2a9dd73b4. The narrowing is
#   recorded beside W_ALLOW below, one row per site with its reason, each keyed on a `# bl868-allow: <id>` marker;
#   a row bound to no line or to several is a W-ALLOW-STALE row, so the list cannot go stale silently. The per-pass
#   reset and the unchecked-`read -t` pause narrowings came from consumer-suite-pool at 5991e017c (:1055, :1210).
#   INERT RECEIPTS are not scanned: a `receipt*.sh` that no `verify:` line of docs/backlog.md names and that no
#   non-comment line of a tracked core/fixtures/*/run.sh, seed.sh, lib.sh or .githooks/* file names (as
#   `<fixture>/<file>`, or by bare name from its own directory). No gate runs one. This replaced a test on the BL
#   heading, which missed `wait-stale-deliverable/receipt.sh` because that name carries no id.
#
# CLASS PM -- a `±` row in a tracked invocations.decl (items 1-3, 6). The existing check, unchanged in meaning.
#
# SELF-PROBE, BEFORE THE CORPUS, under mktemp, both directions: a seeded repository carries one offender per W row,
#   the unbounded near-misses (until/while condition waits, `sleep "$@"`, a seeded timestamp, a SECONDS name list,
#   sed mutant text, a JSON seed, a comment), a live and an archived receipt, and a `±` decl row against an exact one.
#   The rows the scan returns must equal the seeded set exactly.
set -uo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || exit 9
ROOT="$HERE"
# walk up for the SUBJECT, never count hops (and never key on a content-key-excluded path, I55)
while [ "$ROOT" != "/" ] && [ ! -f "$ROOT/scripts/validate-fixture-hygiene.sh" ]; do ROOT="$(dirname "$ROOT")"; done
[ -f "$ROOT/scripts/validate-fixture-hygiene.sh" ] || { echo "receipt-bl868: REFUSED -- no scripts/validate-fixture-hygiene.sh above $HERE" >&2; exit 9; }
WORK="$(mktemp -d "${TMPDIR:-/tmp}/bl868.XXXXXX")" || exit 9
trap 'rm -rf "$WORK"' EXIT

read -r -d '' W_AWK <<'AWK'
BEGIN { SQ = sprintf("%c", 39) }
function pop() { STK = substr(STK, 1, length(STK) - 1) }
function mask(s,   out, i, n, c, top) {
  # STK, carried across lines: c code, p a $( ) inside double quotes (code, with a paren depth DP), s single, a $'...',
  # d double. Quoted bytes become X, except a parameter reference inside double quotes, which stays code so a quoted
  # loop counter (`"$i" -lt 50`) is still read. A comment is dropped. Executed strings are recorded in EX[].
  out = ""; n = length(s); i = 1
  while (i <= n) {
    c = substr(s, i, 1); top = substr(STK, length(STK), 1)
    if (top == "s") { if (c == SQ) { pop(); out = out c; if (CAP) { EX[++NEX] = CBUF; CAP = 0 } } else { out = out "X"; if (CAP) CBUF = CBUF c } i++; continue }
    if (top == "a") { if (c == "\\") { out = out "XX"; i += 2; continue } if (c == SQ) { pop(); out = out c } else out = out "X"; i++; continue }
    if (top == "d") {
      if (c == "\\") { out = out "XX"; i += 2; continue }
      if (c == "\"") { pop(); out = out c; i++; continue }
      if (c == "$" && substr(s, i + 1, 1) == "(") { STK = STK "p"; DP[length(STK)] = 0; out = out "$("; i += 2; continue }
      if (c == "$" && match(substr(s, i), /^\$\{?[A-Za-z_][A-Za-z0-9_]*\}?/)) { out = out substr(s, i, RLENGTH); i += RLENGTH; continue }
      out = out "X"; i++; continue
    }
    # code: c or p
    if (c == "\\") { out = out substr(s, i, 2); i += 2; continue }
    if (c == "#" && (i == 1 || substr(s, i - 1, 1) ~ /[[:space:];&|(]/)) break
    if (c == SQ) {
      if (i > 1 && substr(s, i - 1, 1) == "$") { STK = STK "a"; out = out c; i++; continue }
      STK = STK "s"; out = out c
      # an executed string: the body of `-c '...'`, or a printf that writes a stub
      if (out ~ /(^|[[:space:]])-c[[:space:]]+'$/ || (out ~ /printf[[:space:]]+'$/ && substr(s, i + 1, 2) == "#!")) { CAP = 1; CBUF = "" }
      i++; continue
    }
    if (c == "\"") { STK = STK "d"; out = out c; i++; continue }
    if (top == "p") {
      if (c == "(") DP[length(STK)]++
      else if (c == ")") { if (DP[length(STK)] == 0) { pop(); out = out c; i++; continue } DP[length(STK)]-- }
    }
    out = out c; i++
  }
  if (substr(STK, length(STK), 1) == "s" && CAP) CBUF = CBUF "\n"
  return out
}
function incs(m,   r, o, a, b) {  # " v " for each `v=$((v + 1))` / `v=$(($v+1))` / `((v++))` / `((v+=1))`
  o = " "; r = m
  while (match(r, /[A-Za-z_][A-Za-z0-9_]*=\$\(\([[:space:]]*\$?[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\+[[:space:]]*1[[:space:]]*\)\)/)) {
    a = substr(r, RSTART, RLENGTH); b = a; sub(/=.*$/, "", a); sub(/^[^(]*\(\([[:space:]]*\$?/, "", b); sub(/[^A-Za-z0-9_].*$/, "", b)
    if (a == b) o = o a " "
    r = substr(r, RSTART + RLENGTH)
  }
  r = m
  while (match(r, /(\(\(|(^|[;&|[:space:]])let[[:space:]]+"?)[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*(\+\+|\+=[[:space:]]*1)/)) {
    a = substr(r, RSTART, RLENGTH); sub(/^(\(\(|[;&|[:space:]]*let[[:space:]]+"?)[[:space:]]*/, "", a); sub(/[^A-Za-z0-9_].*$/, "", a); o = o a " "
    r = substr(r, RSTART + RLENGTH)
  }
  return o
}
function cmps(m,   r, o, a) {  # " v " for each `$v -lt|-le|-gt|-ge|-eq X` (the counter on the left, quoted or not)
  o = " "; r = m
  while (match(r, /\$\{?[A-Za-z_][A-Za-z0-9_]*\}?"?[[:space:]]+-(lt|le|gt|ge|eq)[[:space:]]/)) {
    a = substr(r, RSTART, RLENGTH); sub(/^\$\{?/, "", a); sub(/[^A-Za-z0-9_].*$/, "", a); o = o a " "
    r = substr(r, RSTART + RLENGTH)
  }
  return o
}
function both(i, c, z,   n, a, k) { n = split(i, a, " "); for (k = 1; k <= n; k++) if (index(c, " " a[k] " ") && !index(z, " " a[k] " ")) return 1; return 0 }
function resets(s,   o, a) {  # " v " for each `v=<integer>` LEADING the loop body: a per-pass count, not an iteration bound
  o = " "
  while (match(s, /^[[:space:];]*[A-Za-z_][A-Za-z0-9_]*=[0-9]+([[:space:]]*;|[[:space:]]+|$)/)) {
    a = substr(s, RSTART, RLENGTH); sub(/^[[:space:];]*/, "", a); sub(/=.*$/, "", a); o = o a " "; s = substr(s, RSTART + RLENGTH)
  }
  return o
}
function used(m,   r, a) {  # record every `$v` / `${v` read on this masked line
  r = m
  while (match(r, /\$\{?[A-Za-z_][A-Za-z0-9_]*/)) { a = substr(r, RSTART, RLENGTH); sub(/^\$\{?/, "", a); USED[a] = 1; r = substr(r, RSTART + RLENGTH) }
}
function flush(   k) {  # an unchecked `read -t` whose variable the file never reads is a pause; one it reads is a row
  for (k = 1; k <= NPR; k++) if (PRV[k] in USED) print "W-TIMEOUT\t" PRF[k] ":" PRL[k] "\t" PRT[k]
  NPR = 0; split("", USED)
}
function row(cls, ln, txt) { print cls "\t" REL ":" ln "\t" substr(txt, 1, 160) }
function scan(m, ln, orig,   r, t, a, v, nm, k) {
  # left-to-right over loop keywords, done, and sleep; plus the per-line clock/timeout rules
  # an elapsed-time read is a row where it is COMPARED (`s=$SECONDS` alone only records a start)
  if (m ~ /\$SECONDS|\$\{SECONDS|\(\([^)]*SECONDS/ && m ~ /(-lt|-le|-gt|-ge)[[:space:]]|\(\([^)]*SECONDS[^)]*[<>]/) row("W-CLOCK", ln, orig)
  else if (m ~ /date[[:space:]]+(-u[[:space:]]+)?\+%s/ && m ~ /(-lt|-le|-gt|-ge)[[:space:]]|(^|[;&|[:space:]])(while|until)[[:space:]]/) row("W-CLOCK", ln, orig)
  if (m ~ /(^|[;&|({!`[:space:]])timeout[[:space:]]+(-[a-zA-Z]+[[:space:]]+)*"?(\$|[0-9])/) row("W-TIMEOUT", ln, orig)
  used(m)
  if (PQ) { if (m ~ /\$\?/) row("W-TIMEOUT", PQL, PQT); PQ = 0 }
  if (SP > 0 && RSP[SP]) { Z[SP] = resets(m); RSP[SP] = 0 }
  # the counters this line INCREMENTS and the names it COMPARES; a loop is bounded when one name is both, anywhere in
  # its header or body (a header cap `[ "$n" -lt 300 ]`, or an in-body watchdog `[ "$idle" -ge 50 ] && break`)
  linc = incs(m); lcmp = cmps(m)
  for (k = 1; k <= SP; k++) { INC[k] = INC[k] linc; CMP[k] = CMP[k] lcmp }
  r = m
  while (match(r, /(^|[;&|({!`[:space:]])(while|until|for|done|read|(\/usr)?(\/bin\/)?sleep)([[:space:]]|;|$)/)) {
    t = substr(r, RSTART, RLENGTH); gsub(/^[;&|({!`[:space:]]+|[[:space:];]+$/, "", t)
    pre = substr(m, 1, length(m) - length(r) + RSTART); rest = substr(r, RSTART + RLENGTH)
    if (t == "read") {
      # a `read -t` is a timeout row when its status or its variable can decide anything: it is conditioned (if,
      # while, until, elif, `!`, && or ||, or inside `$( )`), its `$?` is read on the next line, or its variable is
      # read anywhere in the file. Otherwise, INSIDE a loop, it is that loop's pause, judged like a sleep through the
      # loop header (W-BOUND, W-CLOCK); outside every loop it stays a row.
      if (rest ~ /^(-[a-zA-Z]+[[:space:]]+[0-9]*[[:space:]]*)*-[a-zA-Z]*t/) {
        v = rest; sub(/[;&|)].*$/, "", v); gsub(/-[a-zA-Z]+[[:space:]]+[0-9$][^[:space:]]*|-[a-zA-Z]+|<[^[:space:]]*/, "", v)
        n_ = split(v, vv, /[[:space:]]+/); rv = "REPLY"; for (k = n_; k >= 1; k--) if (vv[k] ~ /^[A-Za-z_][A-Za-z0-9_]*$/) { rv = vv[k]; break }
        if (SP == 0 || pre ~ /(^|[;&|({`[:space:]])(if|while|until|elif)[[:space:]]+$/ || pre ~ /(!|&&|\|\||\$\(|`)[[:space:]]*$/ || rest ~ /^[^;]*(&&|\|\|)/) row("W-TIMEOUT", ln, orig)
        else { LS[SP] = 1; PQ = 1; PQL = ln; PQT = orig; NPR++; PRV[NPR] = rv; PRF[NPR] = REL; PRL[NPR] = ln; PRT[NPR] = substr(orig, 1, 160) }
      }
    } else if (t == "while" || t == "until" || t == "for") {
      # a `for` is a bound only over a COUNTED list: `$(seq ...)`, `{1..N}`, or literal numbers
      SP++; LH[SP] = ln; LT[SP] = orig; LS[SP] = 0; INC[SP] = linc; CMP[SP] = lcmp; Z[SP] = " "; RSP[SP] = 1
      # the body's leading `v=<integer>` resets, read after `do` on this line or from the body's first line
      if (match(rest, /(^|[;[:space:]])do([[:space:]]+|$)/)) { bd = substr(rest, RSTART + RLENGTH); if (bd ~ /[^[:space:]]/) { Z[SP] = resets(bd); RSP[SP] = 0 } }
      LF[SP] = (t == "for" && rest ~ /^[A-Za-z_][A-Za-z0-9_]*[[:space:]]+in[[:space:]]+(\$\(seq[[:space:]]|\{[0-9]+\.\.|[0-9]+([[:space:]]+[0-9]+)*[[:space:]]*(;|$|[[:space:]]do))/)
    } else if (t == "done") {
      if (SP > 0) {
        if (LS[SP] && (LF[SP] || both(INC[SP], CMP[SP], Z[SP]))) row("W-BOUND", LH[SP], LT[SP])
        SP--
      }
    } else {
      # a sleep: its argument
      if (match(rest, /^[[:space:]]*"?(\$\{?[A-Za-z0-9_@*][A-Za-z0-9_:-]*\}?|[0-9]*\.?[0-9]+)/)) {
        a = substr(rest, RSTART, RLENGTH); gsub(/[[:space:]"]/, "", a)
        if (a ~ /^\$\{?[@*]/) { }
        else if (a ~ /^[0-9.]+$/ && a + 0 == 0) { }
        else if (SP > 0) LS[SP] = 1
        else row("W-SLEEP", ln, orig)
      }
    }
    r = rest
  }
}
function code(s, ln, orig,   m, k, j, nl, L) {
  NEX = 0; m = mask(s); LASTM = m; scan(m, ln, orig)
  for (k = 1; k <= NEX; k++) {
    # an executed string: scanned with its own quote state and loop stack
    sQ = STK; sSP = SP; STK = "c"; SP = 0
    gsub(/\\n/, "\n", EX[k]); nl = split(EX[k], L, "\n")
    for (j = 1; j <= nl; j++) scan(mask(L[j]), ln, orig)
    STK = sQ; SP = sSP
  }
}
END { flush() }
FNR == 1 {
  flush(); PQ = 0
  REL = substr(FILENAME, length(ROOTP) + 1); STK = "c"; split("", DP); SP = 0; HD = ""; CAP = 0
  SKIP = (REL in INERT)
  print "F\t" REL
}
# an allowlist anchor: a TRAILING comment `# bl868-allow: <id>` closing the line
match($0, /#[[:space:]]*bl868-allow:[[:space:]]*[A-Za-z0-9_.-]+[[:space:]]*$/) {
  mk = substr($0, RSTART); sub(/^#[[:space:]]*bl868-allow:[[:space:]]*/, "", mk); sub(/[[:space:]]+$/, "", mk)
  print "M\t" REL "\t" FNR "\t" mk
}
SKIP { next }
HD != "" {
  t = $0; if (HDT) sub(/^\t+/, "", t)
  if (t == HD) { HD = ""; STK = OQ; SP = OSP; next }
  if (HDX) code($0, FNR, $0)
  next
}
{
  code($0, FNR, $0)
  # a heredoc opened in CODE (read off the masked line, so `<<` inside a string is data); its word from the raw line
  if (match(LASTM, /<<-?[[:space:]]*['"]?[A-Za-z_\\][A-Za-z0-9_]*/) && substr(LASTM, RSTART, 3) != "<<<" && substr(LASTM, RSTART - 1, 1) != "<") {
    h = substr($0, RSTART); match(h, /^<<-?[[:space:]]*['"]?\\?[A-Za-z_][A-Za-z0-9_]*['"]?/); h = substr(h, 1, RLENGTH); sub(/\\/, "", h); HDT = (h ~ /^<<-/); sub(/^<<-?[[:space:]]*['"]?/, "", h); sub(/['"]$/, "", h); HD = h
    # the body has its own quote state and loop stack, stacked above the enclosing code's
    OQ = STK; OSP = SP; STK = "c"; SP = 0
    # the body is EXECUTED only when the heredoc writes a file (`cat > f`, `tee f`) or feeds a shell; a heredoc
    # read into a variable (`read -r -d '' X <<'E'`) or fed to any other program is data
    HDX = (LASTM ~ /(^|[;&|({[:space:]])(cat|tee)[[:space:]][^|]*>|(^|[;&|({[:space:]])tee[[:space:]]|(^|[;&|({[:space:]])(bash|sh)([[:space:]]+-s)?[[:space:]]*(<<|$)/)
  }
}
AWK

# inert <root> <list> <out>: the INERT receipts, one repo-relative path per line. Only a file named `receipt*.sh` can
# be inert (a sourced helper never is). It is inert when BOTH hold: no `verify:` line of docs/backlog.md names it, and
# no non-comment line of a tracked core/fixtures/*/run.sh, seed.sh, lib.sh or .githooks/* names it. "Names it" is
# `<fixture-dir>/<basename>` anywhere on the line, or the bare basename from a file in the receipt's OWN directory
# (`bash "$HERE/receipt.sh"`), so one fixture's call never makes another fixture's same-named receipt live. Returns 1
# when the ledger or a referencing file cannot be read (awk reads an unopenable file as empty, so reads are counted).
inert() {
  local r="$1" n
  [ -f "$r/docs/backlog.md" ] || return 1
  git -C "$r" ls-files -- 'core/fixtures/*/run.sh' 'core/fixtures/*/seed.sh' 'core/fixtures/*/lib.sh' '.githooks/*' > "$3.refs" 2>/dev/null || return 1
  n="$(awk 'END { print NR }' "$3.refs")"
  awk -v R="$r" -v RL="$3.refs" -v NREF="$n" '
    function named(l, s,   i, t) {  # s in l, with no name character before it (so `dir/receipt.sh` is not `r/receipt.sh`)
      t = l
      while ((i = index(t, s)) > 0) { if (i == 1 || substr(t, i - 1, 1) !~ /[A-Za-z0-9_.-]/) return 1; t = substr(t, i + 1) }
      return 0 }
    { b = $0; sub(/^.*\//, "", b); if (b !~ /^receipt[^\/]*\.sh$/) next
      d = $0; sub(/\/[^\/]*$/, "", d); C[$0] = 1; BASE[$0] = b; DIR[$0] = d; t = d; sub(/^.*\//, "", t); SUF[$0] = t "/" b }
    END {
      if ((getline l < (R "/docs/backlog.md")) < 0) exit 3
      do { if (l ~ /^verify:/) for (c in C) if (named(l, SUF[c])) LIVE[c] = 1 } while ((getline l < (R "/docs/backlog.md")) > 0)
      got = 0
      while ((getline f < RL) > 0) {
        fd = f; sub(/\/[^\/]*$/, "", fd); p = R "/" f
        if ((getline l < p) < 0) exit 3
        got++
        do { if (!index(l, "receipt") || l ~ /^[[:space:]]*#/) continue
             for (c in C) { if (named(l, SUF[c])) { LIVE[c] = 1; continue }
               if (fd == DIR[c] && named(l, BASE[c])) LIVE[c] = 1 }
        } while ((getline l < p) > 0)
        close(p)
      }
      if (got != NREF) exit 3
      for (c in C) if (!(c in LIVE)) print c
    }' "$2" > "$3" || return 1
  return 0
}

# scan_w <root> <out>: class W rows into <out>; returns 9 on a broken corpus
scan_w() {
  local r="$1" o="$2" n s
  git -C "$r" ls-files -- 'core/fixtures/**/*.sh' > "$o.list" 2>/dev/null || { echo "receipt-bl868: REFUSED -- git ls-files failed under $r" >&2; return 9; }
  n="$(awk 'END { print NR }' "$o.list")"
  [ "$n" -gt 0 ] || { echo "receipt-bl868: REFUSED -- core/fixtures/**/*.sh lists 0 tracked files under $r" >&2; return 9; }
  inert "$r" "$o.list" "$o.inert" || { echo "receipt-bl868: REFUSED -- docs/backlog.md or a referencing run/seed/lib/hook file could not be read under $r" >&2; return 9; }
  awk -v R="$r" '{ print R "/" $0 }' "$o.list" > "$o.abs"
  set -f; IFS='
'
  # shellcheck disable=SC2046
  set -- $(cat "$o.abs"); unset IFS; set +f
  awk -v ROOTP="$r/" -v HF="$o.inert" 'BEGIN { if ((getline l < HF) < 0) exit 3; do if (l != "") INERT[l] = 1; while ((getline l < HF) > 0) }
    '"$W_AWK" "$@" > "$o.raw" || { echo "receipt-bl868: REFUSED -- the wait scan failed" >&2; return 9; }
  s="$(grep -c '^F	' "$o.raw")" || s=0
  [ "$s" -eq "$n" ] || { echo "receipt-bl868: REFUSED -- listed $n files, scanned $s" >&2; return 9; }
  grep '^W-' "$o.raw" | LC_ALL=C sort -u > "$o.rows" || :
  grep '^M	' "$o.raw" > "$o.marks" || :
  return 0
}

# allow_join <allow> <rows> <marks> <keep> <notes>: the W rows NOT suppressed go to <keep>; a W-ALLOW-STALE row per
# allowlist row whose id is on no marked line or on more than one goes to stdout; a NOTE per marked line the scan
# did not flag goes to <notes>. A row suppresses every W row on the ONE line carrying its id in its path, and
# nothing when the id is on zero or several lines, so a copied marker never absorbs a second site. A marker whose
# id has no row suppresses nothing. Exit 2 on a malformed or duplicate row (the receipt's own text is wrong).
allow_join() {
  awk -F'\t' -v KEEP="$4" -v NOTES="$5" '
    FILENAME == ARGV[1] { if ($0 ~ /^#/ || $0 == "") next
      if (NF != 3 || $1 == "" || $2 == "" || $3 == "" || $2 !~ /^[A-Za-z0-9_.-]+$/) { print "receipt-bl868: malformed allowlist row: " $0 > "/dev/stderr"; bad = 1; next }
      if ($2 in AP) { print "receipt-bl868: duplicate allowlist id " $2 > "/dev/stderr"; bad = 1; next }
      AP[$2] = $1; ids[++n] = $2; next }
    FILENAME == ARGV[3] { if (AP[$4] == $2) { C[$4]++; L[$4] = $2 ":" $3 } next }
    { R[++nr] = $0; p = $2; key[nr] = p }
    END {
      if (bad) exit 2
      for (k = 1; k <= n; k++) { id = ids[k]
        if (C[id] + 0 == 1) { SUP[L[id]] = id; continue }
        print "W-ALLOW-STALE\t" AP[id] "\t" id "\t" (C[id] + 0 == 0 ? "no line carries # bl868-allow: " id : "the marker is on " C[id] " lines, want exactly 1") }
      for (j = 1; j <= nr; j++) if (key[j] in SUP) HIT[key[j]] = 1; else print R[j] > KEEP
      for (s in SUP) if (!(s in HIT)) print "receipt-bl868: NOTE -- " s " carries # bl868-allow: " SUP[s] " and the scan flags nothing there (the wait was fixed; drop the row and the marker)" > NOTES
      close(KEEP); close(NOTES) }' "$1" "$2" "$3" || return 2
  [ -f "$4" ] || : > "$4"; [ -f "$5" ] || : > "$5"
  return 0
}

# scan_pm <root> <out>
scan_pm() {
  local r="$1" o="$2" n
  n="$(git -C "$r" ls-files -- 'core/fixtures/*/invocations.decl' 2>/dev/null | awk 'END { print NR }')" || return 9
  [ "${n:-0}" -gt 0 ] || { echo "receipt-bl868: REFUSED -- no tracked invocations.decl under $r" >&2; return 9; }
  git -C "$r" grep -nF '±' -- 'core/fixtures/*/invocations.decl' > "$o.pmraw" 2>/dev/null
  case $? in 0|1) ;; *) echo "receipt-bl868: REFUSED -- git grep failed under $r" >&2; return 9 ;; esac
  awk -F: '{ l = $0; sub(/^[^:]*:[0-9]+:/, "", l); print "PM\t" $1 ":" $2 "\t" l }' "$o.pmraw" > "$o.pm"
  return 0
}

# ---- the allowlist: path, a marker id, and the reason. The allowlisted line ends in a trailing comment
# `# bl868-allow: <id>`, and the row drops every W row on THAT line. Keyed on the marker, never on the line's text,
# so an edit that keeps the marker keeps the suppression, and an unmarked identical line is still a row. Each id is
# unique here and must sit on exactly one line of its path; an id on no line or on several is a W-ALLOW-STALE row
# (exit 1, a finding to fix, never a 9 -- R8/R10 read a row count, not a broken receipt). A marked line the scan no
# longer flags is a NOTE on stderr. A marker with no row here suppresses nothing.
# FP SET (2a9dd73b4): the scan returned 53 rows; 6 are below, each a line where no elapsed time can decide a verdict.
# Every other row is an open site. Narrowings already applied in the grammar, each measured on the same tree: masking
# (jq/JSON transcript seeds in foreground-budget-deny and check-25, sed mutant text in readset-skip and advisor-gate-deny,
# the SECONDS variable-name lists in five shims: 0 rows), a sleep inside a loop counted only through its header (the
# poll quanta of unbounded condition waits: 0 rows), heredoc start read off the masked line (a `<<` inside a quoted
# sed program had swallowed 2000 lines of gate-remediation-deny), and a `for` counted only over a numeric list.
read -r -d '' W_ALLOW <<'ALLOW'
core/fixtures/readset-skip/run.sh	rs-trace-floor	a floor, not a bound: the trace must start in a later second; load only lengthens it and decides nothing
core/fixtures/readset-skip/run.sh	rs-lstart-floor	a floor, not a bound: each judge must start in a later lstart second than the lock pid
core/fixtures/consumer-suite-pool/run.sh	csp-barrier-cap	the observe barrier's cap: CSP_BARRIER_N is set only in the -P1 world and the m3 mutant, where one fixture is in flight whatever the timing, so the cap's expiry records 1 either way; unset, the wait is unbounded
core/fixtures/wait-beat-liveness/run.sh	wbl-clock-shim-probe	the clock shim probe: this sleep is the injected clock, which reaches no real sleep
core/fixtures/wait-beat-liveness/run.sh	wbl-clock-shim-control	the clock shim control: one real 1s sleep whose outcome is which binary it reached
core/fixtures/wait-beat-liveness/run.sh	wbl-clock-ip-probe	the in-process clock probe: sleep is the clock function, no real sleep
core/fixtures/wait-beat-liveness/run.sh	wbl-clock-ip-control	the in-process clock control: which binary the sleep reached
ALLOW

# ---- self-probe ----------------------------------------------------------------------------------------------------
P="$WORK/probe"; mkdir -p "$P/core/fixtures/p" "$P/core/fixtures/q" "$P/docs" || exit 9
printf '%s\n' '#!/usr/bin/env bash' \
  '( sleep 2; act ) &' \
  'while [ ! -e "$f" ] && [ $((SECONDS - s)) -lt 60 ]; do sleep 0.1; done' \
  'i=0; while [ "$i" -lt 50 ]; do probe && break; sleep 0.2; i=$((i + 1)); done' \
  'for k in 1 2 3; do' '  probe && break' '  /bin/sleep 1' 'done' \
  'timeout 30 cmd' \
  'read -r -t 5 l < "$fifo"' \
  'until [ -s "$f" ]; do sleep 0.1; done' \
  'while ! [ -e "$f" ]; do sleep 0.05; done' \
  'n=0; while [ "$(grep -c . "$p")" -lt 3 ]; do sleep 0.01; n=$((n + 1)); done' \
  'exec /bin/sleep "$@"' \
  'since=$(( $(date +%s) - 30 ))' \
  'case "$v" in IFS|SECONDS|RANDOM) continue ;; esac' \
  "sed 's/^      sleep 0\\.2\$/      sleep 600/' a > b" \
  "printf '{\"command\":\"until x; do sleep 15; done\"}' > t.jsonl" \
  '# sleep 30 is a comment' \
  'sleep 0' \
  "bash -c 'sleep 300 & wait'" \
  "printf '#!/bin/bash\\nexec sleep 600\\n' > \"\$w/stub\"" \
  'cat > "$w/stub2" <<'"'"'EOF'"'" \
  'sleep 5' \
  'EOF' \
  'sleep 0.3' \
  's=$SECONDS' \
  'for s in $SCEN; do run "$s"; sleep 0.1; done' \
  'read -r -d '"''"' DATA <<'"'"'EOD'"'" \
  'sleep 4' \
  'EOD' \
  'cat > "$w/fx/run.sh" <<FX' \
  'sleep $3' \
  'FX' \
  'idle=0; while [ ! -s "$s" ]; do sleep 0.1; idle=$((idle + 1)); [ "$idle" -ge 50 ] && break; done' \
  'n=0; while [ ! -s "$s" ]; do sleep 0.1; n=$((n + 1)); [ "$((n % 10))" -eq 0 ] || continue; done' \
  'while :; do' '  ul=0; set_=1' '  while read -r p; do ul=$((ul + 1)); done < "$f"' '  [ "$ul" -eq 0 ] && break' '  sleep 0.1' 'done' \
  'n=0; while :; do n=$((n + 1)); [ "$n" -lt 30 ] || break; sleep 0.1; done' \
  'while :; do' '  [ -e "$f" ] && break' '  read -t 1 -u 8 _px' 'done' \
  'while :; do if read -t 5 l1 < "$q"; then break; fi; done' \
  'while :; do read -t 5 l2 < "$q" || bad x; sleep 0.1; [ -s "$f" ] && break; done' \
  'while :; do read -t 2 l3 < "$q"; [ "$l3" = go ] && break; done' \
  'while :; do read -t 3 l4 < "$q"' '  [ $? -eq 0 ] && break; done' \
  'k=0; until [ "$k" -ge 40 ]; do sleep 0.1; let k++; done' > "$P/core/fixtures/p/run.sh"
# receipts, only a `receipt*.sh` can be INERT: q/receipt-bl901 is named by a live verify line (REPORTED, the
# control); q/receipt-bl902 is named by nothing and carries the same wait (SKIPPED); r/receipt.sh is named by nothing,
# while s/run.sh calls ITS OWN receipt.sh by bare name (r SKIPPED, so one fixture's call never makes another's
# same-named receipt live; s REPORTED); q/receipt-bl903 is named only in a comment, in prose and in a verify line of
# the ARCHIVE (SKIPPED); q/receipt-lib.sh is sourced from s/lib.sh (REPORTED).
mkdir -p "$P/core/fixtures/r" "$P/core/fixtures/s" "$P/core/fixtures/m" || exit 9
printf '%s\n' '#!/usr/bin/env bash' 'sleep 7' > "$P/core/fixtures/q/receipt-bl901.sh"
printf '%s\n' '#!/usr/bin/env bash' 'sleep 8' > "$P/core/fixtures/q/receipt-bl902.sh"
printf '%s\n' '#!/usr/bin/env bash' 'sleep 9' > "$P/core/fixtures/q/receipt-bl903.sh"
printf '%s\n' '#!/usr/bin/env bash' 'sleep 6' > "$P/core/fixtures/q/receipt-lib.sh"
printf '%s\n' '#!/usr/bin/env bash' 'sleep 5' > "$P/core/fixtures/r/receipt.sh"
printf '%s\n' '#!/usr/bin/env bash' 'sleep 4' > "$P/core/fixtures/s/receipt.sh"
printf '%s\n' '#!/usr/bin/env bash' 'HERE=x' 'bash "$HERE/receipt.sh"' '# bash core/fixtures/q/receipt-bl903.sh' > "$P/core/fixtures/s/run.sh"
printf '%s\n' '. "$HERE/../q/receipt-lib.sh"' > "$P/core/fixtures/s/lib.sh"
printf '%s\n' '3±1 core/scripts/x.sh why=poll provisional' > "$P/core/fixtures/p/invocations.decl"
printf '%s\n' '4 core/scripts/x.sh' > "$P/core/fixtures/q/invocations.decl"
printf '%s\n' '# ledger' '' '## BL-901 — live' '' 'verify: sh bash core/fixtures/q/receipt-bl901.sh' '' \
  '## BL-903 — live' '' 'prose: bash core/fixtures/q/receipt-bl903.sh' '' > "$P/docs/backlog.md"
printf '%s\n' '# archive' '' '## BL-902 — archived' '' 'verify: sh bash core/fixtures/q/receipt-bl903.sh' '' > "$P/docs/backlog.archive.md"
# the allowlist's markers, one live and several stale rows in ONE join: m:2 marked and suppressed (the live row); m:3
# the identical line UNmarked, still a row; m:4 a marker with no allowlist row, still a row and nothing more; m:5 a
# marked line the scan does not flag (a NOTE); m:6 and m:7 one id on two lines (W-ALLOW-STALE, neither suppressed);
# m:8 marked with an id whose row names ANOTHER path (W-ALLOW-STALE, not suppressed); pm-gone is on no line.
printf '%s\n' '#!/usr/bin/env bash' 'sleep 3  # bl868-allow: pm-one' 'sleep 3' 'sleep 4 # bl868-allow: pm-norow' \
  'true # bl868-allow: pm-fixed' 'sleep 5 # bl868-allow: pm-two' 'sleep 5 # bl868-allow: pm-two' \
  'sleep 6 # bl868-allow: pm-elsewhere' > "$P/core/fixtures/m/run.sh"
printf '%s\n' 'core/fixtures/m/run.sh	pm-one	probe' 'core/fixtures/m/run.sh	pm-fixed	probe' \
  'core/fixtures/m/run.sh	pm-two	probe' 'core/fixtures/m/run.sh	pm-gone	probe' 'core/fixtures/p/run.sh	pm-elsewhere	probe' > "$WORK/p.allow"
{ git init -q "$P" && git -C "$P" add -A && git -C "$P" -c user.name=p -c user.email=p@p commit -q -m probe; } >/dev/null 2>&1 \
  || { echo "receipt-bl868: REFUSED -- could not build the probe repository" >&2; exit 9; }
scan_w "$P" "$WORK/p" || exit 9
scan_pm "$P" "$WORK/p" || exit 9
cut -f1,2 "$WORK/p.rows" "$WORK/p.pm" | LC_ALL=C sort > "$WORK/p.got"
printf '%s\n' 'W-SLEEP	core/fixtures/p/run.sh:2' 'W-CLOCK	core/fixtures/p/run.sh:3' 'W-BOUND	core/fixtures/p/run.sh:4' \
  'W-BOUND	core/fixtures/p/run.sh:5' 'W-TIMEOUT	core/fixtures/p/run.sh:9' 'W-TIMEOUT	core/fixtures/p/run.sh:10' \
  'W-SLEEP	core/fixtures/p/run.sh:21' 'W-SLEEP	core/fixtures/p/run.sh:22' 'W-SLEEP	core/fixtures/p/run.sh:24' \
  'W-SLEEP	core/fixtures/p/run.sh:26' 'W-SLEEP	core/fixtures/p/run.sh:33' 'W-BOUND	core/fixtures/p/run.sh:35' \
  'W-BOUND	core/fixtures/p/run.sh:43' 'W-TIMEOUT	core/fixtures/p/run.sh:48' 'W-TIMEOUT	core/fixtures/p/run.sh:49' \
  'W-TIMEOUT	core/fixtures/p/run.sh:50' 'W-TIMEOUT	core/fixtures/p/run.sh:51' 'W-BOUND	core/fixtures/p/run.sh:53' \
  'W-SLEEP	core/fixtures/q/receipt-bl901.sh:2' 'W-SLEEP	core/fixtures/q/receipt-lib.sh:2' 'W-SLEEP	core/fixtures/s/receipt.sh:2' \
  'W-SLEEP	core/fixtures/m/run.sh:2' 'W-SLEEP	core/fixtures/m/run.sh:3' 'W-SLEEP	core/fixtures/m/run.sh:4' \
  'W-SLEEP	core/fixtures/m/run.sh:6' 'W-SLEEP	core/fixtures/m/run.sh:7' 'W-SLEEP	core/fixtures/m/run.sh:8' \
  'PM	core/fixtures/p/invocations.decl:1' | LC_ALL=C sort > "$WORK/p.want"
if ! cmp -s "$WORK/p.got" "$WORK/p.want"; then
  echo "receipt-bl868: REFUSED -- the self-probe's rows differ from the seeded set:" >&2
  diff "$WORK/p.want" "$WORK/p.got" | sed -n 's/^</    want-only/p; s/^>/    got-only /p' >&2
  exit 9
fi
# the allowlist join over the same probe: the marker, not the line text, suppresses; every stale shape is a row
allow_join "$WORK/p.allow" "$WORK/p.rows" "$WORK/p.marks" "$WORK/p.keep" "$WORK/p.notes" > "$WORK/p.stale" \
  || { echo "receipt-bl868: REFUSED -- the self-probe's allowlist join failed" >&2; exit 9; }
grep -v '	core/fixtures/m/run.sh:2$' "$WORK/p.want" | grep -v '^PM' > "$WORK/p.kwant"
cut -f1,2 "$WORK/p.keep" | LC_ALL=C sort > "$WORK/p.kgot"
sa="$(cut -f1,3 "$WORK/p.stale" | LC_ALL=C sort | tr '\t\n' ' |')"
sw='W-ALLOW-STALE pm-elsewhere|W-ALLOW-STALE pm-gone|W-ALLOW-STALE pm-two|'
nn="$(grep -c 'core/fixtures/m/run.sh:5 carries # bl868-allow: pm-fixed' "$WORK/p.notes")" || nn=0
na="$(awk 'END { print NR }' "$WORK/p.notes")"
if ! cmp -s "$WORK/p.kgot" "$WORK/p.kwant" || [ "$sa" != "$sw" ] || [ "$nn" != 1 ] || [ "$na" != 1 ]; then
  echo "receipt-bl868: REFUSED -- the self-probe's allowlist join is wrong: stale [$sa] want [$sw], notes $na (pm-fixed $nn) want 1 (1):" >&2
  diff "$WORK/p.kwant" "$WORK/p.kgot" | sed -n 's/^</    want-only/p; s/^>/    got-only /p' >&2
  exit 9
fi
# a malformed or duplicate row is the receipt's own text gone wrong: a refusal, never a finding
printf '%s\n' 'core/fixtures/m/run.sh	pm-one	a' 'core/fixtures/m/run.sh	pm-one	b' > "$WORK/p.dup"
if allow_join "$WORK/p.dup" "$WORK/p.rows" "$WORK/p.marks" "$WORK/p.k2" "$WORK/p.n2" > /dev/null 2>&1; then
  echo "receipt-bl868: REFUSED -- the self-probe's duplicate allowlist id was accepted" >&2; exit 9
fi
echo "receipt-bl868: self-probe ok ($(awk 'END { print NR }' "$WORK/p.want") seeded rows exact; the unbounded waits, the pauses, the per-pass counts, the data and the inert receipts stayed quiet; the allowlist suppressed only its marked line, and 3 stale rows and 1 NOTE printed)" >&2

# ---- the corpus ----------------------------------------------------------------------------------------------------
scan_w "$ROOT" "$WORK/c" || exit 9
scan_pm "$ROOT" "$WORK/c" || exit 9
# the allowlist, joined on its markers: a stale row is a FINDING (exit 1), never a refusal
printf '%s\n' "$W_ALLOW" > "$WORK/allow"
allow_join "$WORK/allow" "$WORK/c.rows" "$WORK/c.marks" "$WORK/c.keep" "$WORK/c.notes" > "$WORK/c.stale" \
  || { echo "receipt-bl868: REFUSED -- the allowlist join failed" >&2; exit 9; }
cat "$WORK/c.notes" >&2

# ---- class H3, delegated -------------------------------------------------------------------------------------------
HYG="$ROOT/scripts/validate-fixture-hygiene.sh"
[ -f "$HYG" ] || { echo "receipt-bl868: REFUSED -- $HYG is absent" >&2; exit 9; }
bash "$HYG" > "$WORK/hyg.out" 2>&1; hrc=$?
case "$hrc" in 0|1) ;; *) echo "receipt-bl868: REFUSED -- validate-fixture-hygiene.sh exited $hrc" >&2; sed -n '1,20p' "$WORK/hyg.out" >&2; exit 9 ;; esac
hp="$(grep -c '^self-probe H3: ok' "$WORK/hyg.out")" || hp=0
[ "$hp" -eq 1 ] || { echo "receipt-bl868: REFUSED -- validate-fixture-hygiene.sh printed no 'self-probe H3: ok' line, so its H3 arm is unproven" >&2; exit 9; }
awk '/^FAIL H3:/ { on = 1; next } on && /^    / { l = $0; sub(/^    /, "", l); p = l; sub(/: .*$/, "", p); t = l; sub(/^[^ ]*: /, "", t); print "H3\t" p "\t" t; next } { on = 0 }' \
  "$WORK/hyg.out" > "$WORK/c.h3" || exit 9

cat "$WORK/c.h3" "$WORK/c.keep" "$WORK/c.stale" "$WORK/c.pm" > "$WORK/c.all"
n3="$(awk 'END { print NR }' "$WORK/c.h3")"; nw="$(awk 'END { print NR }' "$WORK/c.keep")"; np="$(awk 'END { print NR }' "$WORK/c.pm")"
ns="$(awk 'END { print NR }' "$WORK/c.stale")"; nf="$(awk 'END { print NR }' "$WORK/c.list")"
if [ -s "$WORK/c.all" ]; then
  cat "$WORK/c.all"
  echo "receipt-bl868: OPEN -- $n3 H3 row(s), $nw bounded-wait row(s), $ns stale allowlist row(s), $np provisional decl row(s) over $nf fixture .sh" >&2
  exit 1
fi
echo "receipt-bl868: CLEAN -- no H3 row, no bounded wait over $nf fixture .sh, no provisional decl row" >&2
exit 0
