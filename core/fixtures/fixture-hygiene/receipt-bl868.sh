#!/usr/bin/env bash
# core/fixtures/fixture-hygiene/receipt-bl868.sh -- the BL-868 backlog receipt: no fixture verdict or invocation
# count may depend on load.
#
# Exit 0: the tree carries none of the three classes below. Exit 1: at least one offender row was printed, one per
# line, `<class>\t<path>:<line>\t<text>`. Exit 9: could not measure (no root, git failed, an empty corpus, a ledger
# file missing, a self-probe red, the hygiene validator broken or its H3 self-probe absent). Nothing else exits 1:
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
#   Corpus: `git ls-files -- 'core/fixtures/**/*.sh'`, counted (zero is a 9), minus ARCHIVED receipts: a
#   `receipt-bl<N>[-x].sh` whose `## BL-<N>` heading is absent from docs/backlog.md and present in
#   docs/backlog.archive.md is inert (no gate runs it). A receipt in neither file stays scanned.
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
#     W-TIMEOUT `timeout N` (a literal or `$` value) in code, and `read -t`.
#   A sleep INSIDE a loop is that loop's poll quantum and is judged only through the loop header (W-BOUND, W-CLOCK).
#   STATED LIMITS: a sleep paced inside an unbounded while-loop body (`while read l; do x; sleep 1; done`) is not
#   seen; nor a counter compared only through arithmetic (`(( n > 50 ))`, `"$((n % 10))" -eq 0`); nor a bound held
#   in a helper function the loop calls; nor a stub written by a printf whose string does not start with `#!`, by `echo`, or assembled in a
#   variable; nor a wait in a file outside core/fixtures (core/fixtures/lib is in). `find -newer` and `-nt` are NOT
#   rows: they compare mtimes and wait for nothing, and the elapsed wait that once ordered those mtimes is a sleep,
#   which W-SLEEP sees (the D4 grammar lists them as SITES to read; this receipt narrows them out on that ground).
#   FALSE-POSITIVE SET, how it reached its value: measured on b248-b248-loadfree at 2a9dd73b4. The narrowing is
#   recorded beside W_ALLOW below, one row per site with its reason; every row must match a live line or the run is
#   a 9, so the list cannot go stale silently.
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
  while (match(r, /\(\([[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*(\+\+|\+=[[:space:]]*1)/)) {
    a = substr(r, RSTART, RLENGTH); sub(/^\(\([[:space:]]*/, "", a); sub(/[^A-Za-z0-9_].*$/, "", a); o = o a " "
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
function both(i, c,   n, a, k) { n = split(i, a, " "); for (k = 1; k <= n; k++) if (index(c, " " a[k] " ")) return 1; return 0 }
function row(cls, ln, txt) { print cls "\t" REL ":" ln "\t" substr(txt, 1, 160) }
function scan(m, ln, orig,   r, t, a, v, nm, k) {
  # left-to-right over loop keywords, done, and sleep; plus the per-line clock/timeout rules
  # an elapsed-time read is a row where it is COMPARED (`s=$SECONDS` alone only records a start)
  if (m ~ /\$SECONDS|\$\{SECONDS|\(\([^)]*SECONDS/ && m ~ /(-lt|-le|-gt|-ge)[[:space:]]|\(\([^)]*SECONDS[^)]*[<>]/) row("W-CLOCK", ln, orig)
  else if (m ~ /date[[:space:]]+(-u[[:space:]]+)?\+%s/ && m ~ /(-lt|-le|-gt|-ge)[[:space:]]|(^|[;&|[:space:]])(while|until)[[:space:]]/) row("W-CLOCK", ln, orig)
  if (m ~ /(^|[;&|({!`[:space:]])timeout[[:space:]]+(-[a-zA-Z]+[[:space:]]+)*"?(\$|[0-9])/) row("W-TIMEOUT", ln, orig)
  if (m ~ /(^|[;&|({!`[:space:]])read[[:space:]]+(-[a-zA-Z]+[[:space:]]+)*-[a-zA-Z]*t/) row("W-TIMEOUT", ln, orig)
  # the counters this line INCREMENTS and the names it COMPARES; a loop is bounded when one name is both, anywhere in
  # its header or body (a header cap `[ "$n" -lt 300 ]`, or an in-body watchdog `[ "$idle" -ge 50 ] && break`)
  linc = incs(m); lcmp = cmps(m)
  for (k = 1; k <= SP; k++) { INC[k] = INC[k] linc; CMP[k] = CMP[k] lcmp }
  r = m
  while (match(r, /(^|[;&|({!`[:space:]])(while|until|for|done|(\/usr)?(\/bin\/)?sleep)([[:space:]]|;|$)/)) {
    t = substr(r, RSTART, RLENGTH); gsub(/^[;&|({!`[:space:]]+|[[:space:];]+$/, "", t)
    rest = substr(r, RSTART + RLENGTH)
    if (t == "while" || t == "until" || t == "for") {
      # a `for` is a bound only over a COUNTED list: `$(seq ...)`, `{1..N}`, or literal numbers
      SP++; LH[SP] = ln; LT[SP] = orig; LS[SP] = 0; INC[SP] = linc; CMP[SP] = lcmp
      LF[SP] = (t == "for" && rest ~ /^[A-Za-z_][A-Za-z0-9_]*[[:space:]]+in[[:space:]]+(\$\(seq[[:space:]]|\{[0-9]+\.\.|[0-9]+([[:space:]]+[0-9]+)*[[:space:]]*(;|$|[[:space:]]do))/)
    } else if (t == "done") {
      if (SP > 0) {
        if (LS[SP] && (LF[SP] || both(INC[SP], CMP[SP]))) row("W-BOUND", LH[SP], LT[SP])
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
FNR == 1 {
  REL = substr(FILENAME, length(ROOTP) + 1); STK = "c"; split("", DP); SP = 0; HD = ""; CAP = 0
  b = REL; sub(/^.*\//, "", b); SKIP = 0
  if (b ~ /^receipt-bl[0-9]+/) { id = b; sub(/^receipt-bl/, "", id); sub(/[^0-9].*$/, "", id); if (!(id in LIVE) && (id in ARCH)) SKIP = 1 }
  print "F\t" REL
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

# heading sets: `L <id>` for docs/backlog.md, `A <id>` for docs/backlog.archive.md
heads() { # <root>
  [ -f "$1/docs/backlog.md" ] && [ -f "$1/docs/backlog.archive.md" ] || return 1
  awk 'FNR == 1 { f = (FILENAME ~ /archive/) ? "A" : "L" } /^## BL-[0-9]+([^0-9]|$)/ { id = $2; sub(/^BL-/, "", id); sub(/[^0-9].*$/, "", id); print f " " id }' \
    "$1/docs/backlog.md" "$1/docs/backlog.archive.md"
}

# scan_w <root> <out>: class W rows into <out>; returns 9 on a broken corpus
scan_w() {
  local r="$1" o="$2" n s
  git -C "$r" ls-files -- 'core/fixtures/**/*.sh' > "$o.list" 2>/dev/null || { echo "receipt-bl868: REFUSED -- git ls-files failed under $r" >&2; return 9; }
  n="$(awk 'END { print NR }' "$o.list")"
  [ "$n" -gt 0 ] || { echo "receipt-bl868: REFUSED -- core/fixtures/**/*.sh lists 0 tracked files under $r" >&2; return 9; }
  heads "$r" > "$o.heads" || { echo "receipt-bl868: REFUSED -- docs/backlog.md or docs/backlog.archive.md is missing under $r" >&2; return 9; }
  awk -v R="$r" '{ print R "/" $0 }' "$o.list" > "$o.abs"
  set -f; IFS='
'
  # shellcheck disable=SC2046
  set -- $(cat "$o.abs"); unset IFS; set +f
  awk -v ROOTP="$r/" -v HF="$o.heads" 'BEGIN { while ((getline l < HF) > 0) { split(l, p, " "); if (p[1] == "L") LIVE[p[2]] = 1; else ARCH[p[2]] = 1 } }
    '"$W_AWK" "$@" > "$o.raw" || { echo "receipt-bl868: REFUSED -- the wait scan failed" >&2; return 9; }
  s="$(grep -c '^F	' "$o.raw")" || s=0
  [ "$s" -eq "$n" ] || { echo "receipt-bl868: REFUSED -- listed $n files, scanned $s" >&2; return 9; }
  grep '^W-' "$o.raw" | LC_ALL=C sort -u > "$o.rows" || :
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

# ---- the allowlist: path, a fixed substring of the line, and the reason. Every row must match a live W row.
# FP SET (2a9dd73b4): the scan returned 53 rows; 6 are below, each a line where no elapsed time can decide a verdict.
# Every other row is an open site. Narrowings already applied in the grammar, each measured on the same tree: masking
# (jq/JSON transcript seeds in foreground-budget-deny and check-25, sed mutant text in readset-skip and advisor-gate-deny,
# the SECONDS variable-name lists in five shims: 0 rows), a sleep inside a loop counted only through its header (the
# poll quanta of unbounded condition waits: 0 rows), heredoc start read off the masked line (a `<<` inside a quoted
# sed program had swallowed 2000 lines of gate-remediation-deny), and a `for` counted only over a numeric list.
read -r -d '' W_ALLOW <<'ALLOW'
core/fixtures/readset-skip/run.sh	sleep 1.1	a floor, not a bound: the trace must start in a later second; load only lengthens it and decides nothing
core/fixtures/readset-skip/run.sh	LOCK_T0 )) -lt 2 ]; do	a floor, not a bound: each judge must start in a later lstart second than the lock pid
core/fixtures/wait-beat-liveness/run.sh	bash -c 'a=$(date +%s); sleep 60; b=$(date +%s)	the clock shim probe: this sleep is the injected clock, which reaches no real sleep
core/fixtures/wait-beat-liveness/run.sh	bash -c 'sleep 1; date +%s'	the clock shim control: one real 1s sleep whose outcome is which binary it reached
core/fixtures/wait-beat-liveness/run.sh	wbl_clock_fns; a=$(date +%s); sleep 60	the in-process clock probe: sleep is the clock function, no real sleep
core/fixtures/wait-beat-liveness/run.sh	wbl_clock_fns; sleep 1; date +%s	the in-process clock control: which binary the sleep reached
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
  'n=0; while [ ! -s "$s" ]; do sleep 0.1; n=$((n + 1)); [ "$((n % 10))" -eq 0 ] || continue; done' > "$P/core/fixtures/p/run.sh"
printf '%s\n' '#!/usr/bin/env bash' 'sleep 7' > "$P/core/fixtures/q/receipt-bl901.sh"
printf '%s\n' '#!/usr/bin/env bash' 'sleep 8' > "$P/core/fixtures/q/receipt-bl902.sh"
printf '%s\n' '#!/usr/bin/env bash' 'sleep 9' > "$P/core/fixtures/q/receipt-bl903.sh"
printf '%s\n' '3±1 core/scripts/x.sh why=poll provisional' > "$P/core/fixtures/p/invocations.decl"
printf '%s\n' '4 core/scripts/x.sh' > "$P/core/fixtures/q/invocations.decl"
printf '%s\n' '# ledger' '' '## BL-901 — live' '' > "$P/docs/backlog.md"
printf '%s\n' '# archive' '' '## BL-901 — old' '' '## BL-902 — archived' '' > "$P/docs/backlog.archive.md"
{ git init -q "$P" && git -C "$P" add -A && git -C "$P" -c user.name=p -c user.email=p@p commit -q -m probe; } >/dev/null 2>&1 \
  || { echo "receipt-bl868: REFUSED -- could not build the probe repository" >&2; exit 9; }
scan_w "$P" "$WORK/p" || exit 9
scan_pm "$P" "$WORK/p" || exit 9
cut -f1,2 "$WORK/p.rows" "$WORK/p.pm" | LC_ALL=C sort > "$WORK/p.got"
printf '%s\n' 'W-SLEEP	core/fixtures/p/run.sh:2' 'W-CLOCK	core/fixtures/p/run.sh:3' 'W-BOUND	core/fixtures/p/run.sh:4' \
  'W-BOUND	core/fixtures/p/run.sh:5' 'W-TIMEOUT	core/fixtures/p/run.sh:9' 'W-TIMEOUT	core/fixtures/p/run.sh:10' \
  'W-SLEEP	core/fixtures/p/run.sh:21' 'W-SLEEP	core/fixtures/p/run.sh:22' 'W-SLEEP	core/fixtures/p/run.sh:24' \
  'W-SLEEP	core/fixtures/p/run.sh:26' 'W-SLEEP	core/fixtures/p/run.sh:33' 'W-BOUND	core/fixtures/p/run.sh:35' \
  'W-SLEEP	core/fixtures/q/receipt-bl901.sh:2' 'W-SLEEP	core/fixtures/q/receipt-bl903.sh:2' \
  'PM	core/fixtures/p/invocations.decl:1' | LC_ALL=C sort > "$WORK/p.want"
if ! cmp -s "$WORK/p.got" "$WORK/p.want"; then
  echo "receipt-bl868: REFUSED -- the self-probe's rows differ from the seeded set:" >&2
  diff "$WORK/p.want" "$WORK/p.got" | sed -n 's/^</    want-only/p; s/^>/    got-only /p' >&2
  exit 9
fi
echo "receipt-bl868: self-probe ok ($(awk 'END { print NR }' "$WORK/p.want") seeded rows exact; the unbounded waits, the data and the archived receipt stayed quiet)" >&2

# ---- the corpus ----------------------------------------------------------------------------------------------------
scan_w "$ROOT" "$WORK/c" || exit 9
scan_pm "$ROOT" "$WORK/c" || exit 9
# the allowlist: drop matching W rows; a row matching nothing is stale
: > "$WORK/c.kept"; cp "$WORK/c.rows" "$WORK/c.keep"
if [ -n "$W_ALLOW" ]; then
  printf '%s\n' "$W_ALLOW" > "$WORK/allow"
  awk -F'\t' 'NR == FNR { if ($0 ~ /^#/ || $0 == "") next
      if (NF != 3 || $1 == "" || $2 == "" || $3 == "") { print "STALE\t" $0 "\tmalformed: want <path><TAB><substring><TAB><reason>"; next }
      AP[++n] = $1; AS[n] = $2; next }
    { p = $2; sub(/:[0-9]+$/, "", p); hit = 0
      for (k = 1; k <= n; k++) if (p == AP[k] && index($3, AS[k])) { U[k]++; hit = 1 }
      if (!hit) print > KEEP }
    END { for (k = 1; k <= n; k++) if (U[k] + 0 != 1) print "STALE\t" AP[k] "\t" AS[k] "\tmatched " (U[k] + 0) " rows, want exactly 1" }' KEEP="$WORK/c.keep2" "$WORK/allow" "$WORK/c.rows" > "$WORK/c.stale" \
    || { echo "receipt-bl868: REFUSED -- the allowlist join failed" >&2; exit 9; }
  [ -f "$WORK/c.keep2" ] && mv "$WORK/c.keep2" "$WORK/c.keep" || : > "$WORK/c.keep"
  if [ -s "$WORK/c.stale" ]; then
    echo "receipt-bl868: REFUSED -- allowlist row(s) must each match exactly one live row (a second match would absorb a new site):" >&2; cat "$WORK/c.stale" >&2; exit 9
  fi
fi

# ---- class H3, delegated -------------------------------------------------------------------------------------------
HYG="$ROOT/scripts/validate-fixture-hygiene.sh"
[ -f "$HYG" ] || { echo "receipt-bl868: REFUSED -- $HYG is absent" >&2; exit 9; }
bash "$HYG" > "$WORK/hyg.out" 2>&1; hrc=$?
case "$hrc" in 0|1) ;; *) echo "receipt-bl868: REFUSED -- validate-fixture-hygiene.sh exited $hrc" >&2; sed -n '1,20p' "$WORK/hyg.out" >&2; exit 9 ;; esac
hp="$(grep -c '^self-probe H3: ok' "$WORK/hyg.out")" || hp=0
[ "$hp" -eq 1 ] || { echo "receipt-bl868: REFUSED -- validate-fixture-hygiene.sh printed no 'self-probe H3: ok' line, so its H3 arm is unproven" >&2; exit 9; }
awk '/^FAIL H3:/ { on = 1; next } on && /^    / { l = $0; sub(/^    /, "", l); p = l; sub(/: .*$/, "", p); t = l; sub(/^[^ ]*: /, "", t); print "H3\t" p "\t" t; next } { on = 0 }' \
  "$WORK/hyg.out" > "$WORK/c.h3" || exit 9

cat "$WORK/c.h3" "$WORK/c.keep" "$WORK/c.pm" > "$WORK/c.all"
n3="$(awk 'END { print NR }' "$WORK/c.h3")"; nw="$(awk 'END { print NR }' "$WORK/c.keep")"; np="$(awk 'END { print NR }' "$WORK/c.pm")"
nf="$(awk 'END { print NR }' "$WORK/c.list")"
if [ -s "$WORK/c.all" ]; then
  cat "$WORK/c.all"
  echo "receipt-bl868: OPEN -- $n3 H3 row(s), $nw bounded-wait row(s), $np provisional decl row(s) over $nf fixture .sh" >&2
  exit 1
fi
echo "receipt-bl868: CLEAN -- no H3 row, no bounded wait over $nf fixture .sh, no provisional decl row" >&2
exit 0
