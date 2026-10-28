#!/usr/bin/env bash
# validate-fixture-hygiene.sh -- static hygiene of the fixture corpus: no false SKIP on a condition true in normal use,
# no `sh` start the invocation counter cannot see, and a mutant battery declares its mutant x arm matrix.
#
# usage:  validate-fixture-hygiene.sh            check the tree (exit 0 clean, 1 FAIL, 2 self-probe red or broken)
#         validate-fixture-hygiene.sh --derive   print the derived H5 allowlist rows, `<fixture>\t<reason>`
#
# Standalone pre-suite step in .githooks/pre-push (the validate-mutant-kills.sh precedent), deliberately NOT an arm of
# validate-enforcement-map.sh, which the suite pole invokes. Distribution-only: repo-root scripts/ is never installed.
#
# THE CORPUS: `git ls-files -- 'core/fixtures/**/*.sh'` under the resolved root, COUNTED. Zero listed is a FAIL, and
# every listed file must be opened by the scan (an `F` row per file, compared with the list) -- an awk `getline`-free
# scan, so a file the shell listed and awk never opened is a count mismatch, not a clean file.
#
# THE MASKER. Every arm reads a MASKED copy of each line: the bytes inside single quotes, `$'...'`, double quotes
# (except a `$( )` inside them, which stays code), comments, and heredoc bodies are replaced by X, with the quote state
# carried across lines and reset per file. A file that ends with the masker inside a string or a heredoc is reported
# BROKEN (exit 2), never scanned silently half-masked. So `sh` or `exit 0` inside an awk program, a printf seed or a
# heredoc is data, and an arm sees only code.
#
# THE ARMS. Each runs a self-probe FIRST, under mktemp, in both directions; the probe's verdict per arm is printed.
#
# H1  linked-worktree false skip. A `-d <expr>` test inside `[`, `[[` or `test` (negated by `!` inside or before the
#     bracket, or not) whose operand ends in `/.git` (or is `.git`), and whose ABSENT branch reaches `exit 0` (or a
#     bare `exit`): in an `if`/`elif` condition, the then-body for a negated test and the else-body otherwise, through
#     the matching `fi`; in a statement, the `||` branch (`&&` when negated), a `{ }` or `( )` group through its close.
#     In a linked worktree `.git` is a FILE, so such a fixture skips green in normal use.
#     FP SET. Raw grammar, non-comment `-d …/.git` lines: 46 over the 450 tracked core/fixtures/**/*.sh (the
#     contract's 47 included readset-skip:3240, `-d "$dst/.git/modules/lib/sub"`, which does not end in `.git` and is
#     outside the population by construction). Narrowed by KEYING ON THE BRANCH, not the test: 45 of the 46 fail
#     with exit 2 / FIXTURE BROKEN / rc=1 / bad, or have no absent branch at all (`[ -d x/.git ] && git … prune`).
#     Final hits: 1, self-update-join-gate/run.sh:49 -- an OFFENDER (its SKIP fires in every linked worktree), fixed
#     on this branch. Measured false positives in the final set: 0.
# H2  missing-tool skip. A `command -v <t>` in command position (outside quotes) where <t> is a line of the SAME
#     fixture directory's tools.decl (a leading `?` stripped: hermetic-run.sh refuses an unresolved unkeyed tool too),
#     whose failing branch reaches `exit 0` by the H1 branch rules. hermetic-run never reaches these skips (it refuses
#     an undeclared-and-absent tool first); they mislead a DIRECT run, which is why they are fixed (exit 2, FIXTURE
#     BROKEN) rather than allowed.
#     FP SET. Raw: 215 non-comment `command -v` lines; 6 with `exit 0` on the same line, and 7 more with `exit 0`
#     within three lines. Narrowed by (a) masking -- foreground-budget-deny:543 (inside a sed expression),
#     postcompact-rulebook-recovery:1147 (a string), reconcile-emit-report:4547, hermetic-runner:731 and the two
#     wait-beat-liveness printf seeds are data; (b) the tool join -- only a tools.decl tool counts; (c) the branch --
#     apply-drift-after-write:172 skips through `ok "SKIP …"` with no exit and is not an offender. Final hits: 6,
#     all OFFENDERS: agent-definition-render:57, check-25-steering-conduct:35, architecture-index-cell-escaping:55
#     (fixed on this branch), layer-adjudication-tier:82, escalation-delivery:33, transient-ignore-block:62.
#     consumer-machinery-home, extension-check-adoption, derivation-capture and file-mtime carry no such site
#     (derivation-capture:34 exits 2).
# H3  a script started under `sh`: `sh`, `/bin/sh` or `/usr/bin/sh` in command position (line start, after `;`,
#     `&`, `|`, `(`, a backtick, `{`, `!`, or `then`/`do`/`else`/`exec`/`time`/`nohup`/`xargs`), outside quotes,
#     followed by an argument -- `-c`, a flag or an operand, never `==`, `!=`, `=`, `)` or a redirection. `/bin/sh`
#     reads no BASH_ENV, so the invocation counter cannot see the start.
#     FP SET. Raw: 15 lines carrying `sh <word>` in a command-ish position. Narrowed by masking (the awk
#     `sh == ""` / `sh != ""` programs in backlog-rotate-fence-guard, check-24, ledger-reverify, ledger-rotate,
#     shadowed-local-validators; the `(sh false)` messages in backlog-ledger; ledger-reverify:5997's printf) and by
#     the next-word rule. Final hits: 5, all OFFENDERS: readset-skip:1331 (`exec sh -c`), readset-skip:1827 and
#     :2177 and readset-stage1-verdict:900 (`sh -c 'exit 0' &`), self-update-gate:3401 (`sh scripts/…`).
#     STATED LIMITS: a variable-spelled interpreter (prepush-ssh-keepalive:46) and a written `#!/bin/sh` stub
#     executed directly are not seen.
# H4  DROPPED, with its numbers. The contract's form -- a bare `sed … IN > OUT` statement whose OUT is later compared
#     with IN by `cmp -s` in the same file -- matched 857 raw sed-into-file lines, 400 bare statements, and 200 of
#     them joined to a `cmp -s` on the same IN/OUT pair, across 78 fixtures (the contract adversary's naive form had
#     matched 2 of 535). Whether one of the 200 is an offender depends on what the mutant's kill asserts downstream,
#     which no line grammar sees, so the false-positive set is not enumerable and the arm is not shipped.
# H5  the mutant matrix. Population is the UNION, mapped through shard stubs to their IMPL by the ONE resolver,
#     `validate-fixture-invocations.sh --impl-of` (`[exec ]bash "$IMPL" --group`):
#       S1   a function whose name contains `mut` (any case) is defined in the fixture's files;
#       S2   a fixture file carries `cmp -s` in code and the word `mutant` (any case) anywhere;
#       MKA  a row of scripts/mutant-kills-allowlist.txt, which validate-mutant-kills.sh's M1/M2 hold equal to its
#            --derive set on every green push (read as data, so the probe can seed it);
#       MKC  any tracked fixture .sh, not only run.sh, calling `mutant_killed` in code (core/fixtures/lib excluded).
#     A FLOOR OF UNKNOWN DEPTH: being a mutant is semantic, not lexical; a battery that matches none of the four is
#     not seen. A member with no block FAILs unless it is a row of scripts/fixture-matrix-allowlist.txt.
#     THE BLOCK lives in the fixture's run.sh (the IMPL's, for a shard family; a block in a stub FAILs), as comment
#     lines, one of:
#       # MUTANT-MATRIX <m> decides=<arm>[,<arm>…] twins=<arm>[,<arm>…]
#       # MUTANT-MATRIX <m> decides=<arm>[,<arm>…] twins=- why=<clause>
#       # MUTANT-MATRIX-FULL <m> worlds=<w>[,<w>…] why=<clause>
#       # MUTANT-MATRIX-CONTROL <name> why=<clause>
#       # MUTANT-MATRIX-DYNAMIC <label> why=<clause>
#       # MUTANT-MATRIX-REMEASURE bash core/fixtures/<this fixture>/run.sh --matrix      (exactly one)
#     Arm tokens (decides, twins) match ^[A-Za-z0-9_-]+(\.[A-Za-z0-9_-]+)?$ -- at most one dot, `:` and `=` refused;
#     mutant names, labels and worlds match ^[A-Za-z0-9_.-]+$. decides and twins non-empty, no duplicates, no twin
#     inside its decides. `twins=-` only with a non-blank why=; `-` mixed into a list refused; why= on a row with real
#     twins refused; any other field (`log=`) refused. Each name carries exactly one MATRIX / FULL / CONTROL line. At
#     least one MATRIX or FULL line. H5 does NOT check that the REMEASURE mode is implemented: no static test
#     separates a real `--matrix` handler from an echo or a usage string; the integrator's run is the proof.
#     THE JOIN: every literal name passed to `mutant_killed` (its 2nd argument) or as the 1st argument of a mutation
#     helper the fixture defines (S1) carries a MATRIX/FULL/CONTROL line; a mutant_killed name on a CONTROL line
#     FAILs; a non-literal mutant_killed name FAILs unless the block carries a MUTANT-MATRIX-DYNAMIC line (a
#     declaration, never the proof: the runtime join is validate-fixture-invocations.sh's J5).
#     FP SET. The union over the b245-p1 tree is 214 fixtures after shard stubs map to their IMPL (rule 7's estimate
#     was 210; the gap is this branch's two new batteries plus the census counting every fixture .sh, not run.sh
#     only): S1 158, S2 212, MKA 124, MKC 4 at base. `_kill`/`kill_by` are NOT S1 tokens (they match process
#     reapers). The block and unblocked-member counts are PRINTED by every run (the `H5 N block(s), M unblocked
#     member(s)` line) and are not fixed in this comment; the unblocked members are the derived allowlist. Being a
#     member is a floor claim, not a defect claim, so the allowlist IS
#     the false-positive set, enumerated by --derive.
# THE ALLOWLIST scripts/fixture-matrix-allowlist.txt, rows `<fixture>\t<reason>`, DOWN-ONLY:
#     a member without a block and without a row FAILs; a row whose fixture is not such a member (it gained a block,
#     left the floor, or is gone) is STALE and FAILs; a duplicate row, and a row with no reason, FAIL; and a row whose
#     fixture is not a row of the list at origin/main FAILs (keyed on field 1, so rewording a reason is not an added
#     row). Two states have no base and SKIP with the reason printed: origin/main does not resolve, and origin/main
#     carries no list (the release that first ships it).
#
# ON THE BRANCH THAT SHIPS THIS, H2 AND H3 ARE RED BY DESIGN: their offenders sit in fixtures other units are
# rewriting, and H1-H3 carry NO allowlist (H1's one offender is fixed on that branch). The owner fixes them on the
# integrated tip, where this list is also re-derived.
#
# COST: a constant number of forks -- one git ls-files, one resolver call, one awk scan (two passes over the corpus),
# one judge awk, sorts -- the same again for the probe tree, and the M4 probe repos.
set -uo pipefail

MODE=check
case "${1:-}" in
  "") ;;
  --derive) MODE=derive ;;
  *) echo "usage: validate-fixture-hygiene.sh [--derive]" >&2; exit 2 ;;
esac

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$HERE"
while [ "$ROOT" != "/" ] && [ ! -f "$ROOT/VERSION" ]; do ROOT="$(dirname "$ROOT")"; done
if [ ! -f "$ROOT/VERSION" ]; then
  echo "validate-fixture-hygiene: FAIL -- could not resolve repo root (no VERSION marker above $0)" >&2; exit 2
fi
RESOLVER="$HERE/validate-fixture-invocations.sh"
[ -f "$RESOLVER" ] || { echo "validate-fixture-hygiene: FAIL -- the shard-stub resolver $RESOLVER is absent" >&2; exit 2; }
ALLOW_REL="scripts/fixture-matrix-allowlist.txt"
MKA_REL="scripts/mutant-kills-allowlist.txt"

WORK="$(mktemp -d)" || { echo "validate-fixture-hygiene: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

# --- the scan ------------------------------------------------------------------------------------------------------
read -r -d '' SCAN_AWK <<'AWK'
BEGIN { XS = "XXXXXXXXXXXXXXXX"; SQ = sprintf("%c", 39); EXITRE = "(^|[^A-Za-z0-9_$.-])exit([[:space:]]+0)?[[:space:]]*($|[;})&|\n])" }
function relof(p) { return substr(p, 1, length(ROOTP)) == ROOTP ? substr(p, length(ROOTP) + 1) : p }
function fxof(r,   a, n) { n = split(r, a, "/"); return (n >= 4 && a[1] == "core" && a[2] == "fixtures") ? a[3] : "" }
function pop() { STK = substr(STK, 1, length(STK) - 1) }
function maskcode(s,   out, i, n, c, top, r, re) {
  # Fast path: in code, a line with no quote, backtick, comment or escape character is its own mask.
  if (STK == "c" && s !~ /["`#\\]/ && index(s, SQ) == 0) return s
  out = ""; n = length(s)
  if (XS == "") XS = "XXXXXXXXXXXXXXXX"
  while (length(XS) < n) XS = XS XS
  for (i = 1; i <= n; i++) {
    top = substr(STK, length(STK), 1)
    # Copy (code) or mask (string) the run up to the next character this state treats specially, in one step.
    r = substr(s, i)
    if (top == "s") re = SQ; else if (top == "a") re = "[\\\\" SQ "]"; else if (top == "d") re = "[\\\\\"$]"; else re = "[\\\\#\"`()" SQ "]"
    if (!match(r, re)) { out = out ((top == "s" || top == "a" || top == "d") ? substr(XS, 1, length(r)) : r); break }
    if (RSTART > 1) { out = out ((top == "s" || top == "a" || top == "d") ? substr(XS, 1, RSTART - 1) : substr(r, 1, RSTART - 1)); i += RSTART - 1 }
    c = substr(s, i, 1)
    if (top == "s") { if (c == SQ) { pop(); out = out c } else out = out "X"; continue }
    if (top == "a") {
      if (c == "\\") { out = out "X"; if (i < n) { out = out "X"; i++ } continue }
      if (c == SQ) { pop(); out = out c } else out = out "X"; continue
    }
    if (top == "d") {
      if (c == "\\") { out = out "X"; if (i < n) { out = out "X"; i++ } continue }
      if (c == "\"") { pop(); out = out c; continue }
      if (c == "$" && substr(s, i + 1, 1) == "(") { STK = STK "p"; DP[length(STK)] = 0; out = out "$("; i++; continue }
      out = out "X"; continue
    }
    if (c == "\\") { out = out c; if (i < n) { out = out substr(s, i + 1, 1); i++ } continue }
    if (c == "#" && (i == 1 || substr(s, i - 1, 1) ~ /[[:space:];&|]/)) { out = out substr(XS, 1, n - i + 1); break }
    if (c == SQ) { STK = STK (i > 1 && substr(s, i - 1, 1) == "$" ? "a" : "s"); out = out c; continue }
    if (c == "\"") { STK = STK "d"; out = out c; continue }
    if (top == "p") {
      if (c == "(") DP[length(STK)]++
      else if (c == ")") { if (DP[length(STK)] == 0) { pop(); out = out c; continue } DP[length(STK)]-- }
    }
    if (c == "`") { if (top == "b") pop(); else STK = STK "b"; out = out c; continue }
    out = out c
  }
  return out
}
function maskl(s,   m, t, p, n, dash, q, c, w, e) {
  INHD = 0
  if (HDN > 0) {
    INHD = 1; t = s; if (HDD[HDI]) sub(/^\t+/, "", t)
    if (t == HDW[HDI]) { HDI++; if (HDI > HDN) { HDN = 0; HDI = 0 } }
    while (length(XS) < length(s)) XS = XS XS
    return substr(XS, 1, length(s))
  }
  m = maskcode(s); n = length(m)
  if (index(m, "<<") == 0) return m
  for (p = 1; p < n; p++) {
    e = index(substr(m, p), "<<"); if (!e) break
    p += e - 1
    if (substr(m, p + 2, 1) == "<") { p += 2; continue }
    dash = (substr(m, p + 2, 1) == "-"); q = p + 2 + dash
    while (substr(s, q, 1) ~ /[[:space:]]/) q++
    c = substr(s, q, 1); w = ""
    if (c == SQ || c == "\"") { e = index(substr(s, q + 1), c); if (e) w = substr(s, q + 1, e - 1) }
    else { if (c == "\\") q++; if (match(substr(s, q), /^[A-Za-z_][A-Za-z0-9_]*/)) w = substr(s, q, RLENGTH) }
    if (w != "") { HDN++; HDW[HDN] = w; HDD[HDN] = dash; HDI = 1 }
    p = q
  }
  return m
}
function wordat(str, p,   w, c, q) {
  w = ""
  while (p <= length(str)) {
    c = substr(str, p, 1)
    if (c ~ /[[:space:];&|<>()]/) break
    if (c == "\"" || c == SQ) {
      q = index(substr(str, p + 1), c)
      if (!q) { w = w substr(str, p); p = length(str) + 1; break }
      w = w substr(str, p, q + 1); p += q + 1; continue
    }
    if (c == "\\") { w = w substr(str, p, 2); p += 2; continue }
    w = w c; p++
  }
  WEND = p; return w
}
function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
function ifctx(pre,   r, lastif, lastthen) {
  r = pre; lastif = 0; lastthen = 0
  while (match(r, /(^|[;&|[:space:]])(el)?if[[:space:]]/)) { lastif += RSTART + RLENGTH - 1; r = substr(r, RSTART + RLENGTH) }
  r = pre
  while (match(r, /(^|[;&|[:space:]])then([;&|[:space:]]|$)/)) { lastthen += RSTART + RLENGTH - 1; r = substr(r, RSTART + RLENGTH) }
  return lastif > 0 && lastif > lastthen
}
function grab(rest, j, open,   cl, d, k, c, body) {
  cl = (open == "{") ? "}" : ")"; d = 0; k = 0; body = ""
  while (1) {
    k++
    if (k > length(rest)) { if (j >= NL || j - GI > 400) return body; j++; rest = rest "\n" M[j]; k--; continue }
    c = substr(rest, k, 1)
    if (c == open) d++
    else if (c == cl) { d--; if (d == 0) return body }
    body = body c
  }
}
function branch_stmt(i, q, neg,   s, j, op, k, pre, rest, c, body) {
  s = substr(M[i], q); j = i; GI = i
  while (s ~ /(\\|\|\||&&)[[:space:]]*$/ && j < NL) { j++; s = s "\n" M[j] }
  op = neg ? "&&" : "||"
  k = index(s, op); if (!k) return 0
  pre = substr(s, 1, k - 1); if (pre ~ /;/) return 0
  rest = substr(s, k + 2); sub(/^[[:space:]\\]+/, "", rest)
  c = substr(rest, 1, 1)
  if (c == "{" || c == "(") body = grab(rest, j, c)
  else { body = rest; sub(/(;|&&|\|\||\||\n).*/, "", body) }
  return body ~ EXITRE
}
function branch_if(i, p, neg,   s, j, pos, depth, phase, bstart, kw, ks, ke, r, tb, eb) {
  s = substr(M[i], p); j = i; pos = 1; depth = 0; phase = "cond"; tb = ""; eb = ""
  while (1) {
    r = substr(s, pos)
    if (!match(r, /(^|[;&|[:space:](])(if|then|elif|else|fi)([;&|[:space:])]|$)/)) {
      if (j >= NL || j - i > 400) break
      j++; s = s "\n" M[j]; continue
    }
    ks = pos + RSTART - 1; kw = substr(r, RSTART, RLENGTH)
    if (kw ~ /^[;&|[:space:](]/) { ks++; kw = substr(kw, 2) }
    sub(/[;&|[:space:])]$/, "", kw); ke = ks + length(kw)
    if (kw == "if") depth++
    else if (kw == "fi") {
      if (depth == 0) { if (phase == "then") tb = substr(s, bstart, ks - bstart); else if (phase == "else") eb = substr(s, bstart, ks - bstart); break }
      depth--
    } else if (depth == 0) {
      if (kw == "then" && phase == "cond") { phase = "then"; bstart = ke }
      else if ((kw == "else" || kw == "elif") && phase == "then") { tb = substr(s, bstart, ks - bstart); phase = "else"; bstart = ke }
    }
    pos = ke
  }
  return (neg ? tb : eb) ~ EXITRE
}
function fails_to_exit0(i, st, qe, neg, pre0) {
  return ifctx(pre0) ? branch_if(i, st, neg) : branch_stmt(i, qe, neg)
}
function loadtools(fx,   f, l) {
  split("", TOOLS); if (fx == "") return
  f = ROOTP "core/fixtures/" fx "/tools.decl"
  while ((getline l < f) > 0) { sub(/\r$/, "", l); if (l ~ /^[[:space:]]*(#|$)/) continue; l = trim(l); sub(/^\?/, "", l); TOOLS[l] = 1 }
  close(f)
}
function literal(w) { if (w ~ /[$`]/) return ""; gsub(/["\047]/, "", w); return (w ~ /^[A-Za-z0-9_.-]+$/ && w !~ /^-/) ? w : "" }
function analyze(   i, s, off, st, q, w, ww, pre, pre0, neg, e, qe, nw, ts, a, h, k, re, w2) {
  for (i = 1; i <= NL; i++) {
    s = M[i]
    # H1
    off = 0
    while (match(substr(s, off + 1), /(^|[[:space:]])-d[[:space:]]+/)) {
      st = off + RSTART; if (substr(s, st, 1) != "-") st++
      off = st + 1
      q = st + 2; while (substr(O[i], q, 1) ~ /[[:space:]]/) q++
      w = wordat(O[i], q); ww = w; gsub(/["\047]/, "", ww)
      if (ww !~ /(^|\/)\.git$/) continue
      pre0 = substr(s, 1, st - 1); pre = pre0; neg = 0
      sub(/[[:space:]]+$/, "", pre)
      if (pre ~ /!$/) { neg = 1; pre = substr(pre, 1, length(pre) - 1); sub(/[[:space:]]+$/, "", pre) }
      if (pre !~ /(^|[^A-Za-z0-9_])(\[|\[\[|test)$/) continue
      sub(/(\[\[|\[|test)$/, "", pre); sub(/[[:space:]]+$/, "", pre)
      if (pre ~ /(^|[^!=])!$/) neg = !neg
      T1++
      e = index(substr(s, WEND), "]"); qe = e ? WEND + e : WEND
      while (substr(s, qe, 1) == "]") qe++
      if (fails_to_exit0(i, st, qe, neg, pre0)) print "H1\t" REL ":" i "\t" trim(O[i])
    }
    # H2
    off = 0
    while (match(substr(s, off + 1), /(^|[[:space:];&|(!{])command[[:space:]]+-v[[:space:]]+/)) {
      st = off + RSTART; if (substr(s, st, 7) != "command") st++
      q = off + RSTART + RLENGTH; off = q - 1
      w = wordat(O[i], q); gsub(/["\047]/, "", w)
      if (!(w in TOOLS)) continue
      T2++
      pre0 = substr(s, 1, st - 1); pre = pre0; sub(/[[:space:]]+$/, "", pre); neg = (pre ~ /(^|[^!=])!$/)
      if (fails_to_exit0(i, st, WEND, neg, pre0)) print "H2\t" REL ":" i "\t" trim(O[i])
    }
    # H3
    off = 0
    while (match(substr(s, off + 1), /(^|[^A-Za-z0-9_.\/-])(\/usr\/bin\/|\/bin\/)?sh[[:space:]]+/)) {
      st = off + RSTART; ts = substr(s, st, 1); if (ts != "/" && ts != "s") st++
      q = off + RSTART + RLENGTH; off = q - 1
      pre = substr(s, 1, st - 1); sub(/[[:space:]]+$/, "", pre)
      if (!(pre == "" || pre ~ /[;&|(`{!]$/ || pre ~ /(^|[^A-Za-z0-9_])(then|do|else|exec|time|nohup|xargs)$/)) continue
      nw = substr(s, q)
      if (nw == "" || nw ~ /^(==|!=|=|\)|;|&|\||>|<)/) continue
      print "H3\t" REL ":" i "\t" trim(O[i])
    }
    if (FX == "" || FX == "lib") continue
    # H5 facts
    if (s ~ /(^|[^A-Za-z0-9_])cmp[[:space:]]+-s([[:space:]]|$)/) CMP[FX] = 1
    if (O[i] ~ /[Mm][Uu][Tt][Aa][Nn][Tt]/) MUTW[FX] = 1
    if (match(s, /(^|[[:space:];&|(])mutant_killed[[:space:]]+/)) {
      MKC[FX] = 1
      q = RSTART + RLENGTH; w = wordat(O[i], q); q = WEND; while (substr(O[i], q, 1) ~ /[[:space:]]/) q++
      w2 = wordat(O[i], q); k = literal(w2)
      print "K\t" FX "\t" REL ":" i "\t" (k == "" ? "$" : k)
    }
    if (HN[FX] > 0 && match(s, "(^|[[:space:];&|(!])(" HRE[FX] ")[[:space:]]+")) {
      re = substr(s, RSTART, RLENGTH); sub(/^[[:space:];&|(!]/, "", re); sub(/[[:space:]]+$/, "", re)
      if ((FX, re) in HSEEN) { k = literal(wordat(O[i], RSTART + RLENGTH)); if (k != "") print "N\t" FX "\t" REL ":" i "\t" k }
    }
    if (ISRUN && !HDL[i] && O[i] ~ /^[[:space:]]*#[[:space:]]*MUTANT-MATRIX/) print "B\t" FX "\t" i "\t" O[i]
  }
  if (STK != "c" || HDN > 0) print "Q\t" REL "\t" (HDN > 0 ? "inside a heredoc body" : "inside a quoted string (" STK ")")
}
pass == 1 {
  if (FNR == 1) FX = fxof(relof(FILENAME))
  if (FX != "" && FX != "lib" && match($0, /^[[:space:]]*(function[[:space:]]+)?[A-Za-z0-9_]*[mM][uU][tT][A-Za-z0-9_]*[[:space:]]*\(\)/)) {
    nm = $0; sub(/^[[:space:]]*(function[[:space:]]+)?/, "", nm); sub(/[[:space:]]*\(\).*/, "", nm)
    if (!((FX, nm) in HSEEN)) { HSEEN[FX, nm] = 1; HN[FX]++; HRE[FX] = (HN[FX] == 1 ? "" : HRE[FX] "|") nm }
    if (!(FX in S1)) S1[FX] = nm
  }
  next
}
pass == 2 && FNR == 1 {
  if (CUR != "") analyze()
  CUR = FILENAME; NL = 0; STK = "c"; HDN = 0; HDI = 0; split("", DP)
  REL = relof(FILENAME); FX = fxof(REL); ISRUN = (REL == "core/fixtures/" FX "/run.sh"); loadtools(FX)
  print "F\t" REL
}
pass == 2 { NL++; O[NL] = $0; M[NL] = maskl($0); HDL[NL] = INHD }
END {
  if (CUR != "") analyze()
  for (f in S1) print "P\t" f "\tS1 " S1[f] "()"
  for (f in CMP) if (f in MUTW) print "P\t" f "\tS2 cmp -s + mutant"
  for (f in MKC) print "P\t" f "\tMKC mutant_killed caller"
  print "T\tH1\t" (T1 + 0); print "T\tH2\t" (T2 + 0)
}
AWK

# --- the judge -----------------------------------------------------------------------------------------------------
read -r -d '' JUDGE_AWK <<'AWK'
function map(fx) { if (fx in IMPL) { if (IMPL[fx] == "!") { print "STUB\t" fx "\tshard stub whose IMPL= line does not resolve"; return fx } return IMPL[fx] } return fx }
function addtag(f, t) { MEM[f] = 1; if (index("," TAG[f] ",", "," t ",") == 0) TAG[f] = TAG[f] (TAG[f] == "" ? "" : ",") t }
function toks(list, re, what, where,   a, n, k, seen) {
  if (list == "") { print "ROW\t" where "\t" what " is empty"; return 0 }
  n = split(list, a, ","); split("", seen)
  for (k = 1; k <= n; k++) {
    if (a[k] !~ re) { print "ROW\t" where "\t" what " token \"" a[k] "\" is malformed"; return 0 }
    if (a[k] in seen) { print "ROW\t" where "\t" what " token \"" a[k] "\" is duplicated"; return 0 }
    seen[a[k]] = 1
  }
  return n
}
function clause(raw, k) { k = index(raw, " why="); if (!k) return ""; raw = substr(raw, k + 5); gsub(/[[:space:]]/, "", raw); return raw }
function claim(f, name, form, where) {
  if ((f, name) in FORM) { print "ROW\t" where "\tname " name " already carries a " FORM[f, name] " line; each name carries exactly one of MUTANT-MATRIX, -FULL, -CONTROL"; return }
  FORM[f, name] = form
}
FILENAME == ARGV[1] { IMPL[$1] = $2; next }
FILENAME == ARGV[2] { if ($0 !~ /^[[:space:]]*(#|$)/) { x = $1; gsub(/[[:space:]]/, "", x); MKA[x] = 1 } next }
FILENAME == ARGV[3] {
  if ($1 == "H1" || $1 == "H2" || $1 == "H3") { print; next }
  if ($1 == "P") { addtag(map($2), $3); next }
  if ($1 == "B") { if ($2 in IMPL) { print "ROW\t" $2 ":" $3 "\ta MUTANT-MATRIX block line in a shard stub; the block lives in its IMPL"; next }
                   NB[$2]++; BL[$2, NB[$2]] = $3; BR[$2, NB[$2]] = $4; next }
  if ($1 == "K") { f = map($2); NK[f]++; KL[f, NK[f]] = $3; KN[f, NK[f]] = $4; next }
  if ($1 == "N") { f = map($2); NN[f]++; NL_[f, NN[f]] = $3; NNm[f, NN[f]] = $4; next }
  next
}
FILENAME == ARGV[4] {
  if ($0 ~ /^[[:space:]]*(#|$)/) next
  x = $1; gsub(/[[:space:]]/, "", x); r = (NF >= 2) ? $2 : ""; gsub(/[[:space:]]/, "", r)
  if (x in LISTED) print "DUP\t" x
  LISTED[x] = 1
  if (r == "") print "NOREASON\t" x
  next
}
END {
  for (x in MKA) addtag(map(x), "MKA mutant-kills allowlist row")
  TOK = "^[A-Za-z0-9_-]+(\\.[A-Za-z0-9_-]+)?$"; NAMERE = "^[A-Za-z0-9_.-]+$"
  for (f in NB) {
    nrem = 0; nmut = 0; dyn = 0
    for (k = 1; k <= NB[f]; k++) {
      raw = BR[f, k]; where = f ":" BL[f, k]; n = split(raw, a, /[[:space:]]+/)
      if (a[1] == "") { for (m = 1; m < n; m++) a[m] = a[m + 1]; n-- }
      if (a[1] != "#") { print "ROW\t" where "\tmalformed: write `# MUTANT-MATRIX...`, the `#` and the form separated by one blank"; continue }
      form = a[2]
      if (form == "MUTANT-MATRIX-REMEASURE") {
        nrem++; cmd = raw; sub(/^[[:space:]]*#[[:space:]]*MUTANT-MATRIX-REMEASURE[[:space:]]+/, "", cmd); sub(/[[:space:]]+$/, "", cmd)
        if (cmd != "bash core/fixtures/" f "/run.sh --matrix") print "ROW\t" where "\tREMEASURE must read exactly `bash core/fixtures/" f "/run.sh --matrix` (got `" cmd "`)"
        continue
      }
      if (form != "MUTANT-MATRIX" && form != "MUTANT-MATRIX-FULL" && form != "MUTANT-MATRIX-CONTROL" && form != "MUTANT-MATRIX-DYNAMIC") { print "ROW\t" where "\tunknown form " form; continue }
      if (n < 3 || a[3] !~ NAMERE) { print "ROW\t" where "\tmissing or malformed name"; continue }
      if (form == "MUTANT-MATRIX") {
        if (n < 5 || a[4] !~ /^decides=/ || a[5] !~ /^twins=/) { print "ROW\t" where "\twant `# MUTANT-MATRIX <m> decides=<arms> twins=<arms>`"; continue }
        dec = substr(a[4], 9); tw = substr(a[5], 7)
        if (!toks(dec, TOK, "decides", where)) continue
        if (tw == "-") {
          if (n < 6 || a[6] !~ /^why=/ || clause(raw) == "") { print "ROW\t" where "\ttwins=- needs a non-empty why=<clause>"; continue }
        } else {
          if (("," tw ",") ~ /,-,/) { print "ROW\t" where "\ttwins=- cannot be mixed into a list"; continue }
          if (!toks(tw, TOK, "twins", where)) continue
          if (n >= 6) { print "ROW\t" where "\t" (a[6] ~ /^why=/ ? "why= is refused on a row with real twins" : "unknown field " a[6]); continue }
          split(dec, d, ","); split(tw, t, ","); bad = ""
          for (u in t) for (v in d) if (t[u] == d[v]) bad = t[u]
          if (bad != "") { print "ROW\t" where "\ttwin " bad " is inside its decides"; continue }
        }
        nmut++; claim(f, a[3], form, where)
      } else if (form == "MUTANT-MATRIX-FULL") {
        if (n < 5 || a[4] !~ /^worlds=/ || a[5] !~ /^why=/ || clause(raw) == "") { print "ROW\t" where "\twant `# MUTANT-MATRIX-FULL <m> worlds=<w,...> why=<clause>`"; continue }
        if (!toks(substr(a[4], 8), NAMERE, "worlds", where)) continue
        nmut++; claim(f, a[3], form, where)
      } else {
        if (n < 4 || a[4] !~ /^why=/ || clause(raw) == "") { print "ROW\t" where "\twant `# " form " <name> why=<clause>`"; continue }
        if (form == "MUTANT-MATRIX-DYNAMIC") { if ((f, "dyn:" a[3]) in FORM) print "ROW\t" where "\tDYNAMIC label " a[3] " is duplicated"; FORM[f, "dyn:" a[3]] = "DYNAMIC"; dyn = 1 }
        else claim(f, a[3], form, where)
      }
    }
    if (nrem != 1) print "ROW\t" f ":0\tthe block carries " nrem " MUTANT-MATRIX-REMEASURE lines; exactly one is required"
    if (nmut == 0) print "ROW\t" f ":0\tthe block declares no MUTANT-MATRIX or MUTANT-MATRIX-FULL row"
    for (k = 1; k <= NK[f]; k++) {
      nm = KN[f, k]
      if (nm == "$") { if (!dyn) print "JOIN\t" KL[f, k] "\ta non-literal mutant_killed name, and the block declares no MUTANT-MATRIX-DYNAMIC line" }
      else if (!((f, nm) in FORM)) print "JOIN\t" KL[f, k] "\tmutant_killed name " nm " carries no MUTANT-MATRIX or MUTANT-MATRIX-FULL line"
      else if (FORM[f, nm] == "MUTANT-MATRIX-CONTROL") print "JOIN\t" KL[f, k] "\tmutant_killed name " nm " carries a MUTANT-MATRIX-CONTROL line; a control never routes through mutant_killed"
    }
    for (k = 1; k <= NN[f]; k++) if (!((f, NNm[f, k]) in FORM)) print "JOIN\t" NL_[f, k] "\tmutation helper name " NNm[f, k] " carries no MUTANT-MATRIX, -FULL or -CONTROL line"
  }
  for (f in MEM) if (!(f in NB)) { DER[f] = 1; print "DERIVE\t" f "\tno MUTANT-MATRIX block; floor: " TAG[f]; if (!(f in LISTED)) print "FLOOR\t" f "\t" TAG[f] }
  for (x in LISTED) if (!(x in DER)) print "STALE\t" x
}
AWK

# run_all <root> <out-prefix>: list, resolve, scan, judge. Writes <out>.scan and <out>.verdict; returns 2 on a broken
# corpus with the reason on stdout.
run_all() {
  local r="$1" o="$2" listed scanned
  ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY
    git -C "$r" ls-files -- 'core/fixtures/**/*.sh' ) > "$o.list" 2>/dev/null \
    || { echo "BROKEN: git ls-files failed under $r"; return 2; }
  listed="$(awk 'END { print NR }' "$o.list")"
  [ "$listed" -gt 0 ] || { echo "BROKEN: core/fixtures/**/*.sh listed 0 tracked files under $r; an empty corpus has no offenders by construction"; return 2; }
  awk -v R="$r" '{ print R "/" $0 }' "$o.list" > "$o.abs"
  # shellcheck disable=SC2046
  set -f; IFS='
'
  set -- $(cat "$o.abs"); unset IFS; set +f
  bash "$RESOLVER" --impl-of "$@" | awk -F'\t' '{ n = split($1, a, "/"); print a[n - 1] "\t" $2 }' > "$o.stubs" \
    || { echo "BROKEN: the shard-stub resolver failed"; return 2; }
  awk -v ROOTP="$r/" "$SCAN_AWK" pass=1 "$@" pass=2 "$@" > "$o.scan" || { echo "BROKEN: the scan awk failed"; return 2; }
  scanned="$(grep -c '^F	' "$o.scan")" || scanned=0
  [ "$scanned" -eq "$listed" ] || { echo "BROKEN: listed $listed files, scanned $scanned"; return 2; }
  if grep -q '^Q	' "$o.scan"; then
    echo "BROKEN: the masker lost its quote state -- these files end inside a string or heredoc, so their arms are unattributable:"
    awk -F'\t' '$1 == "Q" { print "    " $2 ": " $3 }' "$o.scan"; return 2
  fi
  [ -f "$r/$MKA_REL" ] && cp "$r/$MKA_REL" "$o.mka" || : > "$o.mka"
  [ -f "$r/$ALLOW_REL" ] && cp "$r/$ALLOW_REL" "$o.allow" || : > "$o.allow"
  awk -F'\t' "$JUDGE_AWK" "$o.stubs" "$o.mka" "$o.scan" "$o.allow" | LC_ALL=C sort -u > "$o.verdict"
  return 0
}

# m4 <repo> <current list> <scratch>: the down-only arm, keyed on field 1.
m4() {
  local repo="$1" cur="$2" base="$3" sha added
  sha="$(git -C "$repo" rev-parse -q --verify 'origin/main^{commit}' 2>/dev/null)" || sha=""
  if [ -z "$sha" ]; then echo "SKIP M4: origin/main does not resolve here, so there is no base allowlist to compare against"; return 0; fi
  if ! git -C "$repo" cat-file -e "${sha}:${ALLOW_REL}" 2>/dev/null; then
    echo "SKIP M4: origin/main carries no $ALLOW_REL -- this is the release that first ships it"; return 0; fi
  git -C "$repo" show "${sha}:${ALLOW_REL}" > "$base" 2>/dev/null || { echo "FAIL M4: origin/main carries $ALLOW_REL but it could not be read"; return 1; }
  added="$(awk -F'\t' '/^[[:space:]]*(#|$)/ { next } { x = $1; gsub(/[[:space:]]/, "", x) }
    FNR == NR { b[x] = 1; next } !(x in b) && !(x in seen) { seen[x] = 1; print x }' "$base" "$cur" | LC_ALL=C sort)"
  if [ -n "$added" ]; then
    echo "FAIL M4: allowlist row(s) whose fixture is not on $ALLOW_REL at origin/main -- the list is DOWN-ONLY:"
    printf '%s\n' "$added" | sed 's/^/    /'
    echo "  Remedy: do not list the fixture; give it its MUTANT-MATRIX block (fixture-mutants.md) and delete the row."
    return 1
  fi
  echo "OK M4: no allowlist row added against origin/main"; return 0
}

# --- self-probe, before the corpus ---------------------------------------------------------------------------------
pgit() { env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE -u GIT_OBJECT_DIRECTORY \
  git -c user.name=probe -c user.email=probe@invalid -c commit.gpgsign=false -c core.hooksPath=/dev/null \
  -c init.defaultBranch=main "$@"; }
P="$WORK/probe"
seed() { mkdir -p "$(dirname "$P/$1")" && cat > "$P/$1"; }
mkdir -p "$P/scripts" && : > "$P/VERSION"
seed core/fixtures/s1/run.sh <<'EOF'
#!/usr/bin/env bash
D_ROOT=x; GATE=y
if [ ! -f "$GATE" ] || [ ! -d "$D_ROOT/.git" ]; then
  echo "SKIP"
  exit 0
fi
[ -d "$D_ROOT/.git" ] || { echo skip; exit 0; }
EOF
seed core/fixtures/s1n/run.sh <<'EOF'
#!/usr/bin/env bash
# [ -d "$R/.git" ] || exit 0
[ -d "$R/.git" ] || { echo "FIXTURE BROKEN: no repo, exit 0 would lie"; exit 2; }
if [ ! -d "$v/.git" ]; then
  note 'victim has no .git; exit 0'
  rc=1
fi
[ -d "$R/.git" ] && git -C "$R" worktree prune
[ -d "$R/.git" ] || bad "no repo"
exit 0
[ -d "$R/.git/modules/x" ] || exit 0
if [ -d "$R/.git" ]; then
  exit 0
fi
EOF
seed core/fixtures/s2/tools.decl <<'EOF'
# tools
jq
?node
EOF
seed core/fixtures/s2/run.sh <<'EOF'
#!/usr/bin/env bash
command -v jq >/dev/null 2>&1 || { echo "SKIP no jq"; exit 0; }
if ! command -v node >/dev/null 2>&1; then
  echo "skip"
  exit 0
fi
EOF
seed core/fixtures/s2n/tools.decl <<'EOF'
jq
EOF
seed core/fixtures/s2n/run.sh <<'EOF'
#!/usr/bin/env bash
command -v perl >/dev/null 2>&1 || { echo "SKIP no perl"; exit 0; }
MG='command -v jq >/dev/null 2>&1 || exit 0'
command -v jq >/dev/null 2>&1 || { echo "FIXTURE BROKEN: jq"; exit 2; }
if ! command -v jq >/dev/null 2>&1; then
  ok "SKIP arms: jq absent"
elif true; then
  exit 0
fi
EOF
seed core/fixtures/s3/run.sh <<'EOF'
#!/usr/bin/env bash
( cd "$X" && sh scripts/a.sh )
P="$(exec sh -c 'printf %s "$PPID"')"
sh -c 'exit 0' & p=$!
/bin/sh "$X/b.sh"
EOF
seed core/fixtures/s3n/run.sh <<'EOF'
#!/usr/bin/env bash
awk '{ if (sh != "") print sh }' f
x=1; [ "$sh" = 1 ] && bash scripts/a.sh
zsh -c 'true'
cat <<'END' > receipt.md
verify: sh scripts/x.sh
END
echo "run sh scripts/a.sh"
k=$(( sh == 1 ))
EOF
seed core/fixtures/m5a/run.sh <<'EOF'
mkmut() { :; }
EOF
seed core/fixtures/m5b/run.sh <<'EOF'
mut_copy() { :; }
EOF
seed core/fixtures/m5c/run.sh <<'EOF'
#!/usr/bin/env bash
# MUTANT-MATRIX MA decides=R1.cellA twins=R2
# MUTANT-MATRIX MB decides=R1,R3 twins=- why=it deletes the subject check
# MUTANT-MATRIX-FULL MC worlds=w1,w2.x why=no single world decides
# MUTANT-MATRIX-CONTROL KC why=proves which layer carries the kill
# MUTANT-MATRIX-DYNAMIC loop why=names come from the list below
# MUTANT-MATRIX-REMEASURE bash core/fixtures/m5c/run.sh --matrix
mkmut() { :; }
mkmut MA x
mkmut KC x
mutant_killed 1 MB "m"
for m in MC; do mutant_killed 1 "$m" "m"; done
EOF
seed core/fixtures/m5d/run.sh <<'EOF'
# MUTANT-MATRIX D1 decides=R1:cellA twins=R2
# MUTANT-MATRIX D2 decides=R1=x twins=R2
# MUTANT-MATRIX D3 decides=a.b.c twins=R2
# MUTANT-MATRIX D4 decides=.x twins=R2
# MUTANT-MATRIX D5 decides=R1 twins=-
# MUTANT-MATRIX D6 decides=R1 twins=- why=
# MUTANT-MATRIX D7 decides=R1 twins=-,R2
# MUTANT-MATRIX D8 decides=R1 twins=R2 why=x
# MUTANT-MATRIX D9 decides=R1 twins=R2 log=/tmp/x
# MUTANT-MATRIX D10 decides=R1 twins=R1
# MUTANT-MATRIX D11 decides=R1,R1 twins=R2
# MUTANT-MATRIX D12 decides=R1 twins=R2
# MUTANT-MATRIX-CONTROL D12 why=x
# MUTANT-MATRIX-REMEASURE bash core/scripts/hermetic-run.sh m5d
# MUTANT-MATRIX-BOGUS D13 x
# MUTANT-MATRIX-CONTROL KX why=x
mutant_killed 1 NOROW "m"
mutant_killed 1 "$m" "m"
mutant_killed 1 KX "m"
EOF
seed core/fixtures/m5e/run.sh <<'EOF'
# MUTANT-MATRIX E1 decides=R1 twins=R2
# MUTANT-MATRIX-REMEASURE bash core/fixtures/m5e/run.sh --matrix
mkmut() { :; }
EOF
seed core/fixtures/m5f/run.sh <<'EOF'
mut() { :; }
EOF
seed core/fixtures/m5f-b/run.sh <<'EOF'
#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
IMPL="$HERE/../m5f/run.sh"
cmp -s "$a" "$b" || echo "mutant differs"
bash "$IMPL" --group b > "$HERE/out"
EOF
seed core/fixtures/m5g/run.sh <<'EOF'
. "$HERE/world.sh"
EOF
seed core/fixtures/m5g/world.sh <<'EOF'
mutant_killed "$B" w "m"
EOF
seed core/fixtures/m5h/run.sh <<'EOF'
echo h
EOF
seed core/fixtures/m5i/run.sh <<'EOF'
cmp -s "$a" "$b" && bad "the mutant did not apply"
EOF
seed core/fixtures/m5j/run.sh <<'EOF'
# MUTANT-MATRIX-CONTROL CJ why=x
# MUTANT-MATRIX-DYNAMIC L why=x
# MUTANT-MATRIX-DYNAMIC L why=y
# MUTANT-MATRIX-FULL FJ worlds= why=x
# MUTANT-MATRIX-FULL FK worlds=w1
# MUTANT-MATRIX-CONTROL CK why=
mkmut() { :; }
mkmut NOROWJ x
mkmut CJ x
EOF
seed core/fixtures/m5k/run.sh <<'EOF'
# MUTANT-MATRIX K1 decides=R1 twins=R2
# MUTANT-MATRIX-REMEASURE bash core/fixtures/m5k/run.sh --matrix
# MUTANT-MATRIX-REMEASURE bash core/fixtures/m5k/run.sh --matrix
EOF
seed core/fixtures/m5f-c/run.sh <<'EOF'
#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
IMPL="$HERE/../m5f/run.sh"
# MUTANT-MATRIX X decides=R1 twins=R2
exec bash "$IMPL" --group c
EOF
seed core/fixtures/m5l/run.sh <<'EOF'
#!/usr/bin/env bash
IMPL="$X/run.sh"
cmp -s "$a" "$b" || echo "mutant differs"
exec bash "$IMPL" --group b
EOF
seed core/fixtures/m5n/run.sh <<'EOF'
# the copy differs; a comment only
cmp -s "$a" "$b" && bad "the copy did not apply"
reap_kill() { :; }
EOF
printf '%s\n' '# probe' m5h > "$P/$MKA_REL"
printf '# probe allowlist\nm5b\tS1\nm5f\tS1\nm5e\tS1\ngone\tS1\nm5b\tdup\nm5x\n' > "$P/$ALLOW_REL"
{ pgit init -q "$P" && pgit -C "$P" add -A && pgit -C "$P" commit -q -m probe; } >/dev/null 2>&1 \
  || { echo "validate-fixture-hygiene: REFUSED -- could not build the probe repository under $WORK" >&2; exit 2; }

SP_RED=0
sp_line() { printf 'self-probe %s: %s\n' "$1" "$2" >&2; }
pout="$(run_all "$P" "$WORK/p")"; prc=$?
if [ "$prc" -ne 0 ]; then
  sp_line CORPUS "FAIL -- $pout"; SP_RED=1
  : > "$WORK/p.verdict"; : > "$WORK/p.scan"
else
  sp_line CORPUS "ok (listed and scanned $(awk 'END { print NR }' "$WORK/p.list") probe files)"
fi
cut -f1,2 "$WORK/p.verdict" | grep -v '^DERIVE' > "$WORK/p.got"
want_rows() { case "$1" in
  H1) printf 'H1\tcore/fixtures/s1/run.sh:%s\n' 3 7 ;;
  H2) printf 'H2\tcore/fixtures/s2/run.sh:%s\n' 2 3 ;;
  H3) printf 'H3\tcore/fixtures/s3/run.sh:%s\n' 2 3 4 5 ;;
  H5) printf 'FLOOR\t%s\n' m5a m5g m5h m5i m5l
      printf 'ROW\tm5d:%s\n' 1 2 3 4 5 6 7 8 9 10 11 13 14 15
      printf 'ROW\tm5j:%s\n' 0 0 3 4 5 6
      printf 'ROW\tm5k:0\nROW\tm5f-c:4\nSTUB\tm5l\n'
      printf "JOIN\tcore/fixtures/m5d/run.sh:%s\n" 17 18 19
      printf "JOIN\tcore/fixtures/m5j/run.sh:8\n"
      printf 'STALE\t%s\n' gone m5e m5x
      printf 'DUP\tm5b\nNOREASON\tm5x\n' ;;
  esac; }
for arm in H1 H2 H3 H5; do
  case "$arm" in H5) pat='^(FLOOR|ROW|JOIN|STALE|DUP|NOREASON|STUB)	' ;; *) pat="^$arm	" ;; esac
  grep -E "$pat" "$WORK/p.got" | LC_ALL=C sort > "$WORK/got.$arm" || :
  want_rows "$arm" | LC_ALL=C sort > "$WORK/want.$arm"
  if cmp -s "$WORK/got.$arm" "$WORK/want.$arm"; then sp_line "$arm" "ok ($(awk 'END { print NR }' "$WORK/want.$arm") seeded offender row(s) exact; the near-misses stayed quiet)"
  else
    SP_RED=1; sp_line "$arm" "FAIL -- verdict rows differ from the seeded set:"
    diff "$WORK/want.$arm" "$WORK/got.$arm" | sed -n 's/^</    want-only/p; s/^>/    got-only /p' >&2
  fi
done
der="$(awk -F'\t' '$1 == "DERIVE" { print $2 }' "$WORK/p.verdict" | LC_ALL=C sort | tr '\n' ' ')"
if [ "$der" = "m5a m5b m5f m5g m5h m5i m5l " ]; then sp_line DERIVE "ok (derived rows m5a m5b m5f m5g m5h m5i m5l; the stubs m5f-b and m5f-c mapped to their IMPL)"
else SP_RED=1; sp_line DERIVE "FAIL -- derived '$der', want 'm5a m5b m5f m5g m5h m5i m5l '"; fi

m4_case() {  # <label> <repo> <want-rc> <want-first-line> <rows...>
  local lab="$1" repo="$2" wrc="$3" want="$4" got rc
  shift 4; printf '# probe list\n' > "$WORK/m4-cur.txt"; printf '%s\n' "$@" >> "$WORK/m4-cur.txt"
  got="$(unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY; m4 "$repo" "$WORK/m4-cur.txt" "$WORK/m4-base.txt")"; rc=$?
  [ "$rc" = "$wrc" ] && [ "$(printf '%s\n' "$got" | head -1)" = "$want" ] && return 0
  sp_line M4 "FAIL -- case $lab got rc $rc, want $wrc: $(printf '%s' "$got" | head -2 | tr '\n' ' ')"; SP_RED=1; return 1
}
R="$WORK/m4-base"; RN="$WORK/m4-nofile"; RX="$WORK/m4-noorigin"
mkdir -p "$R/scripts" "$RN" "$RX"
{ pgit init -q "$R" && printf '# base\na\tr1\nb\tr2\n' > "$R/$ALLOW_REL" && pgit -C "$R" add "$ALLOW_REL" \
  && pgit -C "$R" commit -q -m base && pgit -C "$R" update-ref refs/remotes/origin/main HEAD \
  && pgit init -q "$RN" && printf 'x\n' > "$RN/other" && pgit -C "$RN" add other && pgit -C "$RN" commit -q -m n \
  && pgit -C "$RN" update-ref refs/remotes/origin/main HEAD && pgit init -q "$RX"; } >/dev/null 2>&1 \
  || { echo "validate-fixture-hygiene: REFUSED -- could not build the M4 probe repos" >&2; exit 2; }
M4F="FAIL M4: allowlist row(s) whose fixture is not on $ALLOW_REL at origin/main -- the list is DOWN-ONLY:"
m4ok=0
m4_case added "$R" 1 "$M4F" "$(printf 'a\tr1')" "$(printf 'b\tr2')" "$(printf 'c\tr3')" || m4ok=1
m4_case swap "$R" 1 "$M4F" "$(printf 'a\tr1')" "$(printf 'c\tr3')" || m4ok=1
m4_case shrink "$R" 0 "OK M4: no allowlist row added against origin/main" "$(printf 'a\tr1')" || m4ok=1
m4_case reworded "$R" 0 "OK M4: no allowlist row added against origin/main" "$(printf 'a\tother words')" "$(printf 'b\tr2')" || m4ok=1
m4_case nofile "$RN" 0 "SKIP M4: origin/main carries no $ALLOW_REL -- this is the release that first ships it" "$(printf 'c\tr')" || m4ok=1
m4_case noorigin "$RX" 0 "SKIP M4: origin/main does not resolve here, so there is no base allowlist to compare against" "$(printf 'c\tr')" || m4ok=1
[ "$m4ok" = 0 ] && sp_line M4 "ok (added and swapped rows refused; shrink and a reworded reason pass; both no-base states SKIP)"

# --- the corpus ----------------------------------------------------------------------------------------------------
out="$(run_all "$ROOT" "$WORK/c")"; crc=$?
if [ "$crc" -ne 0 ]; then echo "validate-fixture-hygiene: REFUSED -- $out" >&2; exit 2; fi
t1="$(awk -F'\t' '$1 == "T" && $2 == "H1" { print $3 }' "$WORK/c.scan")"; t2="$(awk -F'\t' '$1 == "T" && $2 == "H2" { print $3 }' "$WORK/c.scan")"
nmem="$(grep -c '^DERIVE	' "$WORK/c.verdict")" || nmem=0
nblk="$(awk -F'\t' '$1 == "B" { print $2 }' "$WORK/c.scan" | LC_ALL=C sort -u | awk 'END { print NR }')"
if [ "${t1:-0}" -lt 1 ] || [ "${t2:-0}" -lt 1 ] || [ $((nmem + nblk)) -lt 1 ]; then
  echo "validate-fixture-hygiene: REFUSED -- a grammar stopped matching on the corpus (H1 candidates ${t1:-0}, H2 candidates ${t2:-0}, H5 members $((nmem + nblk))); this is not a clean tree." >&2
  exit 2
fi

if [ "$MODE" = derive ]; then
  [ "$SP_RED" = 0 ] || { echo "validate-fixture-hygiene: REFUSED -- the self-probe is red, so the derived set is unattributable" >&2; exit 2; }
  awk -F'\t' '$1 == "DERIVE" { print $2 "\t" $3 }' "$WORK/c.verdict"
  exit 0
fi

rc=0
echo "validate-fixture-hygiene: $(awk 'END { print NR }' "$WORK/c.list") fixture .sh scanned; judged $t1 H1 \`-d …/.git\` test(s) and $t2 H2 declared-tool \`command -v\` site(s); H5 $nblk block(s), $nmem unblocked member(s)"
for arm in H1 H2 H3; do
  if grep -q "^$arm	" "$WORK/c.verdict"; then
    rc=1; echo "FAIL $arm:"
    awk -F'\t' -v A="$arm" '$1 == A { print "    " $2 ": " substr($3, 1, 160) }' "$WORK/c.verdict"
    case "$arm" in
      H1) echo "  A \`-d …/.git\` whose absent branch exits 0 SKIPs green in every linked worktree, where .git is a file. Use \`git -C <root> rev-parse --git-dir\`, or exit 2 FIXTURE BROKEN." ;;
      H2) echo "  A declared tool (tools.decl) whose absence exits 0 is a green skip on a direct run. Exit 2, FIXTURE BROKEN." ;;
      H3) echo "  /bin/sh reads no BASH_ENV, so the invocation counter cannot see this start. Start it with bash." ;;
    esac
  fi
done
if grep -qE '^(FLOOR|ROW|JOIN|STALE|DUP|NOREASON|STUB)	' "$WORK/c.verdict"; then
  rc=1; echo "FAIL H5:"
  awk -F'\t' '$1 ~ /^(FLOOR|ROW|JOIN|STALE|DUP|NOREASON|STUB)$/ { print "    " $1 " " $2 (NF >= 3 ? ": " $3 : "") }' "$WORK/c.verdict"
  echo "  FLOOR: a mutant battery with no MUTANT-MATRIX block (fixture-mutants.md 'One run per distinct state'). STALE/DUP/NOREASON: fix $ALLOW_REL. ROW/JOIN: fix the block."
fi
m4_out="$(m4 "$ROOT" "$ROOT/$ALLOW_REL" "$WORK/m4-root-base.txt")" || rc=1
echo "$m4_out"
if [ "$SP_RED" != 0 ]; then
  echo "validate-fixture-hygiene: REFUSED -- the self-probe is red (above), so the verdict over the tree is unattributable." >&2
  exit 2
fi
nlist="$(awk 'END { print NR }' "$WORK/c.list")"
if [ "$rc" = 0 ]; then
  echo "OK: validate-fixture-hygiene -- self-probe fired both ways; $nlist fixture .sh scanned; H1 $t1 / H2 $t2 candidate test(s), no offender; H5 $nblk block(s), $nmem allowlisted member(s), no stale or added row."
fi
exit "$rc"
