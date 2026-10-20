#!/usr/bin/env bash
# validate-consumer-reads.sh -- every consumer-path read in the recorded-PASS cache's READ CLOSURE
# goes through reconcile/consumer-read.sh, and every closure script runs with globbing off.
#
# WHY. emit-report.sh's `--verify` cache (BL-685) accepts a recorded PASS when a key over the render's
# inputs is unchanged. Four adversary rounds kept reopening one class: a detector the render runs
# READS a consumer path the key never keyed (an escaping `hooks:` value, a `fixtures:` glob expanded
# against the caller's cwd, a `[ -f ]` on a scripts/ path outside every read root), so the input moves,
# the key does not, and the cached run answers PASS where a fresh render fails. Round 8 found five such
# reads. Fixing them one at a time is what the earlier rounds did. The structural fix routes every
# consumer read through ONE helper file, consumer-read.sh (cr_walk, cr_test, cr_read, cr_hash, cr_git),
# so the key can be computed over exactly what the helpers were asked for. This validator is what
# keeps a new raw read from appearing beside it.
#
# THE CLOSURE IS DERIVED, never hand-listed: emit-report.sh plus every reconcile script it names as
# `$SELF/<x>.sh` or `${SELF}/<x>.sh` on a non-comment line, transitively. A name that resolves to no
# file is skipped and counted. The closure must contain emit-report.sh and at least two files, and
# every file in it must be SCANNED (an awk that could not open a file reads as an empty one).
#
# CR1 (raw consumer read). Outside consumer-read.sh, any operand rooted at a consumer root variable is
#   a finding. Inside consumer-read.sh, a rooted operand is a finding only OUTSIDE a function whose
#   name starts with cr_.
#   ROOT SEEDS : CONSUMER CONS ROOT _er_root SKILL_DIR EXT_DIR OVR_DIR LAYERS EXT
#   DERIVATION : one level, scoped to the enclosing function (top level = file scope):
#                V=<rooted>   V="$(cd <rooted> ...)"   V="$(git -C <rooted> ...)"   for V in ... <rooted>
#   POSITIONAL : a function called with a seeded or derived variable as its k-th argument taints $k
#                inside that function (same file).
#   ROOTED     : "$V  "${V  $V  ${V  followed by } / " space ; ) ] or end of line.
#   CLASSES    : test   [ -X  [[ -X  test -X  ! -X  && -X  || -X  -a -X  -o -X  with a rooted operand
#                redir  < <rooted>                    (not <<, not <( )
#                gitC   git -C <rooted>
#                exec   bash|sh|source|. <rooted>    (runs consumer bytes)
#                cd     cd <rooted>                   (moves the cwd into the consumer)
#                cdsub  a multi-line `( cd <x>` subshell whose body, up to its closing paren, names a
#                       rooted consumer variable (flagged at the opening line)
#                cmd    cat grep file_hash find cmp ls head tail sed awk diff wc readlink stat shasum
#                       md5 cp xargs hash-object jq sort cut uniq tr od strings in command position,
#                       a rooted operand after it
#   A cr_* CALL IS NOT A HEAD: `cr_test "$CONSUMER" -f x` and `cr_git "$CONSUMER" ...` match no
#   class, because every head needs a word boundary before it and `_` is not one. That holds for
#   either argument order of cr_test; the shipped order is root first.
#
# HOW THE FALSE-POSITIVE SET REACHED ITS MEASURED SIZE (on the 44825dfc9 closure, 15 files). The
#   grammar started from the round-8 sweep scanner, which reported 105 closure rows there.
#   N1 (inherited from the sweep): a test operator must follow a test opener or connective, so
#      `rm -f`, `mkdir -p`, `cp -p`, `sed -n` do not read as `[ -f` / `[ -p`. The sweep measured
#      14 rows dropped tree-wide, 283 -> 269, every one an rm -f or mkdir -p.
#   N2 (new): a HEAD inside a quoted string is text, not a command. Excludes one row on the closure,
#      emit-report.sh:624, an `echo "... diff <(...) $CONSUMER/$cons"` hint line. A head inside a
#      $( ) nested in a double-quoted string is still a head.
#   N3 (new): in the cmd class, a rooted occurrence that is the value of an assignment operand
#      (`-v pfx="$CONSUMER/"`, `--x=$CONSUMER`) is not a path the command opens. Excludes one row,
#      retired-layer-token.sh:393, where the awk reads the files xargs hands it, and the walk
#      producing them is a row of its own (:386).
#   N4 (new): in the cmd class, the search for a rooted operand stops at the first UNQUOTED `;`, `&&`,
#      `||` or `|`, so a rooted path inside a later command's message string is not the head's
#      operand. Measured after widening the head list with jq sort cut uniq tr od strings: the widening
#      added 2 rows, both false (retired-layer-contract.sh:438 and retired-layer-passage.sh:191,
#      `sort <tmp> || refuse "... $LAYERS/$dir"`), 109 -> 111. N4 drops exactly those 2, 111 -> 109.
#      No jq row exists on this closure: layer-drift.sh never names $ADJ_REGISTER as a jq operand.
#   The cd class (new) ADDS rows: the canonicalizations `X="$(cd "$CONSUMER" && pwd)"` and the
#   predicate-differential.sh subshells that run a probe with the consumer as cwd. Each resolves a
#   consumer path through the filesystem, so each is a consumer read under this property.
#   Count on the 44825dfc9 closure: 105 (the sweep grammar) -> 103 after N2 and N3 -> 109 with the
#   six cd rows (emit-report.sh:1062, layer-drift.sh:257, ledger-reverify.sh:266, preclassify.sh:106,
#   predicate-differential.sh:228/229). The remaining false-positive set was measured EMPTY, row by
#   row: every one of the 109 resolves, tests, reads, hashes, walks or runs `git -C` on a consumer
#   path. All six round-8 sites are among them (relabel-extension-checks.sh:138/144,
#   layer-drift.sh:2390, emit-report.sh:1472 and 1519-1527, preclassify.sh:763, ledger-reverify.sh:1421).
#   The cdsub class (round 8, the successor of layer-adjudication-tier's retired Part 7 mutant) ADDS
#   no row: a multi-line `( cd <x>` opening -- a `( cd` line whose subshell does not close on the same
#   line -- occurs 0 times in the closure at 44825dfc9, at f36ede45d and at the merged round-8 tip
#   (comment lines excluded), so its false-positive set is empty by population, and CR1 reads 109,
#   109 and 0 rows there with or without it. Its narrowing is structural: the subshell must stay open
#   past its opening line (a one-line `( cd "$DIST" … )` is the cd class's), and the body must NAME a
#   seeded or derived consumer variable as a rooted operand; a body that only uses the new cwd, or
#   touches DIST alone, is quiet. Both directions are in the self-probe below.
#   CR2 on the same closure: 32 rows, 15 missing preambles (all 15 closure files) and 17 `set +f`
#   unpaired under the rule. One of them, retired-layer-token.sh:207, sits in a pipe-stage subshell
#   and restores nothing in the parent; it is flagged anyway, since the rule is scoped by function.
#
# CR2 (globbing off). Every closure script RUN AS A PROGRAM carries a top-level `set -f` (or `set -o noglob`, or a
#   `set -<flags>` cluster containing f) BEFORE its first function definition and its first top-level
#   `for` loop. A `set +f` (or `set +o noglob`) is a finding unless a `set -f` follows it in the same
#   block: later on the same line before any `return` or `exit`, or, when the line has neither, on a
#   later line of the same function (top level: a later top-level line). A save-and-restore spelling
#   (`[ "$_mf" = 1 ] || set +f`) is a finding too: under the preamble it is dead, and alive it leaves
#   the caller globbing.
#   A SOURCED LIBRARY owes no preamble: a closure file that closure files name only as
#   `. "$SELF/<x>.sh"` / `source "$SELF/<x>.sh"`, derived per run, never listed. It runs under its
#   caller's options, and a top-level `set -f` in it would leak into every sourcing caller, including
#   ones outside the closure (validate-enforcement-map.sh sources lib.sh and globs fixture and hook
#   directories after it). The pairing half and CR1 still bind it. A file both sourced and run as a
#   program owes the preamble. Measured on the 44825dfc9 closure: lib.sh is the one sourced library,
#   and the exemption moves CR2 from 32 rows to 31.
#
# WHAT THIS CANNOT SEE. A read by a command missing from the CLOSED cmd head list above (an `ed`,
#   `perl`, `python`, `while read ... done < file` is caught as a redir, but `-nt` / `-ot` / `-ef`
#   test operators are not). A read whose path never sits in a variable this grammar taints: a derivation
#   two levels deep (`a="$CONSUMER/x"; b="$a/y"`), a path built by `printf -v`, read from a file the
#   script wrote (`while read p; do [ -f "$p" ]` over a staged walk), or passed through `eval`. A
#   cross-file positional (a script invoked with the consumer as an argument is scanned through its
#   own seed names, not through the caller's). A command head inside a multi-line quoted string (the
#   scanner is line-based; ledger-reverify.sh builds the receipt program `cd "$CONSUMER" && ...` as
#   such a string, and the receipt then runs consumer-chosen commands no grammar can bound). A
#   relative read after a cwd change that is itself flagged. A `case` pattern's `)` inside a
#   multi-line `( cd` subshell, which the cdsub paren count reads as a close (it stops early, so it
#   can miss a later consumer line, never invent one). Any read in a script the closure does
#   not reach through a literal `$SELF/<x>.sh` spelling.
#
# EVERY ARM CARRIES A SELF-PROBE, run BEFORE the corpus on mktemp trees, in both directions: each
# probe line tagged `@OFF` in a trailing comment must be flagged and no other line may be.
#
# STANDALONE, NOT AN ARM OF validate-enforcement-map.sh: that validator sits on the suite pole, which
# the sharded mutation batteries multiply. Wired as its own step in .githooks/pre-push, beside
# validate-claude-rules.sh.
#
# usage:  validate-consumer-reads.sh [--quiet] [--dir <reconcile-dir>]
# exit 0 = both arms pass;  1 = at least one finding;  2 = usage/environment error
set -u

QUIET=0; DIR_OVERRIDE=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --quiet) QUIET=1; shift ;;
    --dir) DIR_OVERRIDE="${2:-}"; [ -n "$DIR_OVERRIDE" ] || { echo "usage: validate-consumer-reads.sh [--quiet] [--dir <reconcile-dir>]" >&2; exit 2; }; shift 2 ;;
    *) echo "usage: validate-consumer-reads.sh [--quiet] [--dir <reconcile-dir>]" >&2; exit 2 ;;
  esac
done

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
while [ "$ROOT" != "/" ] && [ ! -f "$ROOT/VERSION" ]; do ROOT="$(dirname "$ROOT")"; done
if [ ! -f "$ROOT/VERSION" ]; then
  echo "validate-consumer-reads: FAIL -- could not resolve repo root (no VERSION marker above $0)" >&2
  exit 2
fi
RDIR="${DIR_OVERRIDE:-$ROOT/core/skills/ai-dlc-update/reconcile}"
[ -f "$RDIR/emit-report.sh" ] || { echo "validate-consumer-reads: FAIL -- no emit-report.sh in $RDIR" >&2; exit 2; }

fail=0
say() { [ "$QUIET" = "1" ] || printf '%s\n' "$*"; }
err() { printf 'FAIL: %s\n' "$*" >&2; fail=1; }

T="$(mktemp -d "${TMPDIR:-/tmp}/validate-consumer-reads.XXXXXX")" || { echo "validate-consumer-reads: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$T"' EXIT

# closure <dir> -- the derived read closure, one basename per line, emit-report.sh first. Writes the
# count of names that resolved to no file into <dir-of-T>/closure.missing.
closure() {
  local d="$1" todo="emit-report.sh" seen=" " f g miss=0
  while [ -n "$todo" ]; do
    f="${todo%% *}"; case "$todo" in *" "*) todo="${todo#* }" ;; *) todo="" ;; esac
    case "$seen" in *" $f "*) continue ;; esac
    seen="$seen$f "
    if [ ! -f "$d/$f" ]; then miss=$((miss + 1)); continue; fi
    printf '%s\n' "$f"
    for g in $(grep -v '^[[:space:]]*#' "$d/$f" | grep -oE '\$\{?SELF\}?/[A-Za-z0-9_.-]+\.sh' | sed -E 's,.*/,,' | LC_ALL=C sort -u); do
      todo="$todo $g"
    done
    todo="${todo# }"
  done
  printf '%s\n' "$miss" > "$T/closure.missing"
}

# The scanner: one awk program over one file. Prints file<TAB>line<TAB>arm<TAB>class<TAB>var<TAB>excerpt.
# NOTE: no apostrophe may appear anywhere in this program, comments included (it is a single-quoted
# shell literal); a literal single quote is spelled \x27.
SCAN_AWK='
function rooted_re(v) { return "(^|[[:space:]=(<])\"?[$][{]?" v "([}/\"[:space:];)]|\\]|$)" }
function imm_re(v) { return "^[[:space:]]*\"?[$][{]?" v "([}/\"[:space:];)]|\\]|$)" }
function strip(s,   i, c, q, out) {
  q = ""; out = ""
  for (i = 1; i <= length(s); i++) {
    c = substr(s, i, 1)
    if (q == "" && c == "#" && (i == 1 || substr(s, i-1, 1) ~ /[[:space:]]/)) break
    if (c == "\\" && q != "\x27") { out = out c substr(s, i+1, 1); i++; continue }
    if (q == "" && (c == "\"" || c == "\x27")) q = c
    else if (q != "" && c == q) q = ""
    out = out c
  }
  return out
}
# inq(s, pos): 1 when position pos of s lies inside a quoted literal, not inside a $( ) nested in one.
function inq(s, pos,   i, c, sp, st) {
  sp = 0; st[0] = "T"
  for (i = 1; i < pos; i++) {
    c = substr(s, i, 1)
    if (st[sp] == "S") { if (c == "\x27") sp--; continue }
    if (c == "\\") { i++; continue }
    if (c == "$" && substr(s, i+1, 1) == "(") { st[++sp] = "C"; i++; continue }
    if (c == "(" && st[sp] != "D") { st[++sp] = "P"; continue }
    if (c == ")" && (st[sp] == "C" || st[sp] == "P")) { sp--; continue }
    if (c == "\"") { if (st[sp] == "D") sp--; else st[++sp] = "D"; continue }
    if (c == "\x27" && st[sp] != "D") { st[++sp] = "S"; continue }
  }
  return (st[sp] == "D" || st[sp] == "S")
}
# opens(s, start, d): the number of subshell/command-substitution parens still open after scanning s
# from position start, with d already open. Quote-aware like inq; a `case` pattern `)` is not told
# apart from a closing paren (a stated limit).
function opens(s, start, d,   i, c, sp, st, k, m) {
  sp = 0; st[0] = "T"; for (k = 1; k <= d; k++) st[++sp] = "P"
  for (i = start; i <= length(s); i++) {
    c = substr(s, i, 1)
    if (st[sp] == "S") { if (c == "\x27") sp--; continue }
    if (c == "\\") { i++; continue }
    if (c == "$" && substr(s, i+1, 1) == "(") { st[++sp] = "C"; i++; continue }
    if (c == "(" && st[sp] != "D") { st[++sp] = "P"; continue }
    if (c == ")" && (st[sp] == "C" || st[sp] == "P")) { sp--; continue }
    if (c == "\"") { if (st[sp] == "D") sp--; else st[++sp] = "D"; continue }
    if (c == "\x27" && st[sp] != "D") { st[++sp] = "S"; continue }
  }
  m = 0; for (k = 1; k <= sp; k++) if (st[k] == "P" || st[k] == "C") m++
  return m
}
# head(s, hre, v, mode): 1 when some unquoted match of hre is followed by a rooted v. mode "imm":
# immediately (after blanks); mode "any": anywhere later on the line, not as an assignment value.
function head(s, hre, v, mode,   rest, off, e, aft, p, q, qo) {
  rest = s; off = 0
  while (match(rest, hre)) {
    e = off + RSTART + RLENGTH - 1
    aft = substr(s, e + 1)
    if (!inq(s, e)) {
      if (mode == "imm" && aft ~ imm_re(v)) return 1
      if (mode == "any") {
        p = aft; q = aft; qo = e
        while (match(q, /(\|\||&&|;|\|)/)) {
          if (!inq(s, qo + RSTART)) { p = substr(aft, 1, qo + RSTART - 1 - e); break }
          qo = qo + RSTART + RLENGTH - 1; q = substr(q, RSTART + RLENGTH)
        }
        while (match(p, rooted_re(v))) {
          if (substr(p, RSTART, 1) != "=") return 1
          p = substr(p, RSTART + RLENGTH)
        }
      }
    }
    off = e; rest = substr(s, e + 1)
    if (RLENGTH == 0) break
  }
  return 0
}
{ raw[NR] = $0; L[NR] = ($0 ~ /^[[:space:]]*#/) ? "" : strip($0) }
END {
  n = NR
  for (i = 1; i <= n; i++) {
    s = L[i]
    if (match(s, /^[[:space:]]*(function[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\(\)/)) {
      hdr = substr(s, 1, RLENGTH); ind = hdr; sub(/[^[:space:]].*/, "", ind)
      nm = hdr; sub(/^[[:space:]]*(function[[:space:]]+)?/, "", nm); sub(/[[:space:]]*\(\).*/, "", nm)
      fdef[nm] = 1
      if (firstfn == "") firstfn = i
      if (s ~ /\}[[:space:]]*;?[[:space:]]*$/ && s ~ /\{/) { fn[i] = nm; continue }
      for (j = i; j <= n; j++) { fn[j] = nm; if (j > i && raw[j] ~ ("^" ind "}")) break }
      i = j
    }
  }
  if (firstfn == "") firstfn = n + 1
  # ---- CR2: set -f preamble and set +f pairing ----
  setm = "(^|[;&|{(!]|[[:space:]])set[[:space:]]+(-[A-Za-z]*f[A-Za-z]*([[:space:];]|$)|-o[[:space:]]+noglob)"
  setp = "(^|[;&|{(!]|[[:space:]])set[[:space:]]+(\\+[A-Za-z]*f[A-Za-z]*([[:space:];]|$)|\\+o[[:space:]]+noglob)"
  exitre = "(^|[;&|{(!]|[[:space:]])(return|exit)([[:space:];)}]|$)"
  pre = (lib == 1) ? -1 : 0; firstfor = n + 1
  for (i = 1; i <= n; i++) {
    if (i in fn) continue
    if (L[i] ~ /(^|[;&|[:space:]])for[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]+in([[:space:]]|$)/ && i < firstfor) firstfor = i
  }
  lim = (firstfn < firstfor) ? firstfn : firstfor
  if (pre == 0) for (i = 1; i < lim; i++) if (!(i in fn) && L[i] ~ setm) { pre = i; break }
  at = lim; if (at > n) at = n
  if (pre == 0) printf "%s\t%d\tCR2\tpreamble\t-\tno top-level set -f before the first function definition or top-level for loop (line %d)\n", fname, at, at
  for (i = 1; i <= n; i++) {
    s = L[i]; if (!match(s, setp)) continue
    aft = substr(s, RSTART + RLENGTH)
    ok = 0; bad = 0
    if (match(aft, setm)) { a1 = RSTART; if (match(aft, exitre) && RSTART < a1) bad = 1; else ok = 1 }
    else if (match(aft, exitre)) bad = 1
    if (!ok && !bad) {
      sc = (i in fn) ? fn[i] : ""
      for (j = i + 1; j <= n; j++) {
        if (((j in fn) ? fn[j] : "") != sc) { if (sc != "") break; else continue }
        if (L[j] ~ setm) { ok = 1; break }
      }
    }
    if (!ok) { ex = raw[i]; sub(/^[[:space:]]+/, "", ex); printf "%s\t%d\tCR2\tset+f\t-\t%s\n", fname, i, substr(ex, 1, 110) }
  }
  # ---- CR1: rooted consumer operands ----
  ns = split(seeds, S, " ")
  for (k = 1; k <= ns; k++) taint["", S[k]] = "seed"
  for (i = 1; i <= n; i++) {
    s = L[i]; if (s == "") continue
    sc = (i in fn) ? fn[i] : ""
    rest = s
    while (match(rest, /(^|[[:space:];&|(])(local[[:space:]]+|export[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*=/)) {
      a = substr(rest, RSTART, RLENGTH); rest = substr(rest, RSTART + RLENGTH)
      v = a; sub(/^[[:space:];&|(]/, "", v); sub(/^(local|export)[[:space:]]+/, "", v); sub(/=$/, "", v)
      rhs = rest; sub(/^"?\$\(cd[[:space:]]+/, " ", rhs); sub(/^"?\$\(git[[:space:]]+-C[[:space:]]+/, " ", rhs)
      for (k = 1; k <= ns; k++)
        if (match(("=" rhs), rooted_re(S[k])) && RSTART == 1) { if (!((sc, v) in taint)) taint[sc, v] = "derived<-" S[k]; break }
    }
    if (match(s, /(^|[[:space:];])for[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]+in[[:space:]]/)) {
      t = substr(s, RSTART, RLENGTH); sub(/^[[:space:];]*for[[:space:]]+/, "", t); sub(/[[:space:]].*/, "", t)
      lst = substr(s, RSTART + RLENGTH - 1)
      for (k = 1; k <= ns; k++) if (lst ~ rooted_re(S[k])) { taint[sc, t] = "loop<-" S[k]; break }
    }
  }
  for (i = 1; i <= n; i++) {
    s = L[i]; if (s == "" || index(s, "$") == 0) continue
    sc = (i in fn) ? fn[i] : ""
    for (nm in fdef) {
      if (!match(s, "(^|[;&|({!]|[[:space:]]|[$][(])" nm "[[:space:]]")) continue
      argstr = substr(s, RSTART + RLENGTH); sub(/[;|&)<>].*$/, "", argstr)
      na = split(argstr, A, /[[:space:]]+/); pos = 0
      for (q = 1; q <= na; q++) {
        if (A[q] == "") continue
        pos++
        av = A[q]; gsub(/"/, "", av)
        if (av !~ /^[$][{]?[A-Za-z_][A-Za-z0-9_]*[}]?(\/.*)?$/) continue
        vn = av; sub(/^[$][{]?/, "", vn); sub(/[}\/].*$/, "", vn)
        if (((sc, vn) in taint) || (("", vn) in taint)) taint[nm, pos ""] = "positional<-" vn
      }
    }
  }
  for (key in taint) { split(key, KK, SUBSEP); vars[KK[1]] = vars[KK[1]] " " KK[2] }
  B = "(^|[;&|(!{]|[[:space:]]|[$][(])"
  h_test = "(^|[;&|(!{]|[[:space:]])(\\[\\[?|test|!|&&|\\|\\||-a|-o)[[:space:]]+-[efdxsLhrwSpbcgkuGON][[:space:]]+"
  h_redir = "(^|[^<0-9&>])<[[:space:]]*"
  h_git = B "git[[:space:]]+-C[[:space:]]+"
  h_exec = B "(bash|sh|source|\\.)[[:space:]]+"
  h_cd = B "cd[[:space:]]+"
  h_cmd = B "(cat|grep|file_hash|find|cmp|ls|head|tail|sed|awk|diff|wc|readlink|stat|shasum|md5|cp|xargs|hash-object|jq|sort|cut|uniq|tr|od|strings)[[:space:]]"
  for (i = 1; i <= n; i++) {
    s = L[i]; if (s == "" || index(s, "$") == 0) continue
    sc = (i in fn) ? fn[i] : ""
    if (crfile && sc ~ /^cr_/) continue
    cand = vars[""] ((sc != "") ? vars[sc] : "")
    nv = split(cand, V, " "); hit = ""
    for (k = 1; k <= nv && hit == ""; k++) {
      v = V[k]; if (v == "") continue
      if (head(s, h_test, v, "imm")) hit = "test"
      else if (head(s, h_redir, v, "imm")) hit = "redir"
      else if (head(s, h_git, v, "imm")) hit = "gitC"
      else if (head(s, h_exec, v, "imm")) hit = "exec"
      else if (head(s, h_cd, v, "imm")) hit = "cd"
      else if (head(s, h_cmd, v, "any")) hit = "cmd"
      if (hit != "") break
    }
    # cdsub: a MULTI-LINE `( cd <x>` subshell whose body, on later lines up to the closing paren,
    # names a consumer root. The body resolves its relative paths against <x>, so a consumer path it
    # builds is read from wherever <x> is -- the shape a relative consumer root once took through
    # `git -C "$DIST"`. Flagged at the opening line. A subshell closed on its own line is not this
    # class (the cd class above already judges its operand).
    if (hit == "" && match(s, /(^|[;&|[:space:]])\([[:space:]]*cd[[:space:]]/) && !inq(s, RSTART + RLENGTH - 1)) {
      op = index(substr(s, RSTART), "(") + RSTART - 1
      d = opens(s, op + 1, 1)
      for (j = i + 1; d > 0 && j <= n && hit == ""; j++) {
        for (k = 1; k <= nv; k++) {
          v = V[k]; if (v == "") continue
          if (L[j] ~ rooted_re(v)) { hit = "cdsub"; break }
        }
        d = opens(L[j], 1, d)
      }
    }
    if (hit != "") {
      who = ((sc, v) in taint) ? taint[sc, v] : taint["", v]
      ex = raw[i]; sub(/^[[:space:]]+/, "", ex)
      printf "%s\t%d\tCR1\t%s\t%s(%s)\t%s\n", fname, i, hit, v, who, substr(ex, 1, 110)
    }
  }
  print "SCANNED" > "/dev/stderr"
}'
SEEDS="CONSUMER CONS ROOT _er_root SKILL_DIR EXT_DIR OVR_DIR LAYERS EXT"

# scan_dir <reconcile-dir> <out.tsv> -- the derived closure, every file scanned; consumer-read.sh is
# scanned whenever it exists in the directory (the rule binds it whether or not the closure names it).
# Returns 2 on a closure below the floor or a file that was not scanned.
scan_dir() {
  local d="$1" out="$2" f cr nfiles=0 nscan=0
  closure "$d" > "$T/closure.list"
  if [ -f "$d/consumer-read.sh" ] && ! grep -qxF consumer-read.sh "$T/closure.list"; then
    printf '%s\n' consumer-read.sh >> "$T/closure.list"
  fi
  : > "$out"; : > "$T/libs.list"
  # A SOURCED LIBRARY is derived, never listed: a closure file that some closure file names as
  # `. "$SELF/<x>.sh"` or `source "$SELF/<x>.sh"`, and that NO closure file names any other way (no
  # `bash "$SELF/<x>.sh"`). It runs under its caller's shell options, so the preamble half of CR2
  # does not bind it, and a top-level `set -f` in it would leak into every sourcing caller, closure or
  # not. The `set +f` pairing half still binds it, and CR1 binds it fully.
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    local src oth
    src="$(cd "$d" && grep -hvE '^[[:space:]]*#' $(cat "$T/closure.list") 2>/dev/null \
      | grep -cE "(^|[;&|{(!]|[[:space:]])(\\.|source)[[:space:]]+\"?[\$][{]?SELF[}]?/${f}\"?([[:space:];|&)]|\$)")" || src=0
    oth="$(cd "$d" && grep -hvE '^[[:space:]]*#' $(cat "$T/closure.list") 2>/dev/null \
      | grep -E "[\$][{]?SELF[}]?/${f}" \
      | grep -cvE "(^|[;&|{(!]|[[:space:]])(\\.|source)[[:space:]]+\"?[\$][{]?SELF[}]?/${f}\"?([[:space:];|&)]|\$)")" || oth=0
    [ "$src" -gt 0 ] && [ "$oth" -eq 0 ] && printf '%s\n' "$f" >> "$T/libs.list"
  done < "$T/closure.list"
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    nfiles=$((nfiles + 1))
    cr=0; [ "$f" = consumer-read.sh ] && cr=1
    lib=0; grep -qxF -- "$f" "$T/libs.list" && lib=1
    if LC_ALL=C awk -v seeds="$SEEDS" -v fname="$f" -v crfile="$cr" -v lib="$lib" "$SCAN_AWK" "$d/$f" >> "$out" 2> "$T/scan.err" \
       && grep -qx SCANNED "$T/scan.err"; then
      nscan=$((nscan + 1))
    fi
  done < "$T/closure.list"
  printf '%s %s\n' "$nfiles" "$nscan" > "$T/scan.counts"
  head -1 "$T/closure.list" | grep -qx emit-report.sh || return 2
  [ "$nfiles" -ge 2 ] && [ "$nfiles" -eq "$nscan" ] || return 2
  return 0
}

# ---------------------------------------------------------------------------
# SELF-PROBE (before the corpus). Probe tree A: CR1 shapes; tree B: CR2 shapes. In each, the lines
# tagged @OFF must be flagged by that arm and no other line may be.
# ---------------------------------------------------------------------------
PA="$T/probe-a"; PB="$T/probe-b"; mkdir -p "$PA" "$PB" || exit 2
cat > "$PA/emit-report.sh" <<'EOF'
#!/usr/bin/env bash
set -f
SELF="$(cd "$(dirname "$0")" && pwd)"
. "$SELF/consumer-read.sh"
CONSUMER="${3:?}"
SKILL_DIR="$CONSUMER/.claude/skills/ai-dlc"
core_file="$SKILL_DIR/x.md"
[ -f "$core_file" ] && echo hi # @OFF derived one level
[ -e "$CONSUMER/$t" ] && echo hi # @OFF
[[ -d "${CONSUMER}/x" ]] && echo hi # @OFF
test -x "$CONSUMER/x" && echo hi # @OFF
read -r a < "$CONSUMER/stamp" # @OFF
grep -q foo "$CONSUMER/x" # @OFF
jq -c . "$CONSUMER/reg.jsonl" # @OFF
git -C "$CONSUMER" status # @OFF
x="$(cat "$CONSUMER/f")" # @OFF a head inside a nested $( ) is a head
( cd "$CONSUMER" && ls ) # @OFF
top="$(cd "$CONSUMER" && pwd -P)" # @OFF
bash "$CONSUMER/scripts/x.sh" # @OFF
( cd "$tmpd" # @OFF a multi-line subshell whose body names a consumer root
  bash ./probe.sh "$CONSUMER"
)
( cd "$DIST" && git log -1 )
( cd "$DIST"
  git log -1 "$x"
)
rows() {
  if [ -e "$2/$t" ]; then echo p; fi # @OFF positional
}
rows "$f" "$CONSUMER"
bash "$SELF/newdet.sh" "$DIST" "$CONSUMER"
DIST="${1:?}"
dfile="$DIST/x.md"
[ -f "$dfile" ] && echo hi
[ -e "$DIST/$t" ] && echo hi
[ -f "$SELF/lib.sh" ] && echo hi
grep -q foo "$SELF/x"
jq -c . "$DIST/reg.jsonl"
sort "$tmpd/w" > "$tmpd/s" || echo "sorting the walk of $CONSUMER/x failed"
awk '$1 || $2 { print }' "$CONSUMER/a.txt" # @OFF a separator inside a quoted program is not one
git -C "$DIST" status
tmpd="$(mktemp -d)"; [ -f "$tmpd/x" ] && cat "$tmpd/x"
# [ -f "$CONSUMER/x" ] in a comment
echo hi # [ -e "$CONSUMER/x" ] trailing comment
rm -f "$CONSUMER/x"
mkdir -p "$CONSUMER/y"
rel="${p#"$CONSUMER"/}"
[ -f "$rel" ] && echo hi
echo "full: diff <(git show x) $CONSUMER/$cons"
xargs -0 awk -v pfx="$CONSUMER/" '{ print }' < "$tmpd/list"
cr_test "$CONSUMER" -f docs/x && echo hi
cr_test "$CONSUMER" -d "$rel" || [ -n "$x" ]
cr_git "$CONSUMER" status
h="$(cr_hash "$CONSUMER" docs/x)"
cr_walk "$CONSUMER" docs | sort > "$tmpd/w"
cr_run "$CONSUMER" bash "$tmpd/probe.sh" && echo ran
! cr_test "$CONSUMER" -e docs/x || cr_test "$CONSUMER" -L docs/x
other() {
  if [ -e "$2/$t" ]; then echo p; fi
}
other "$f" "$DIST"
EOF
cat > "$PA/consumer-read.sh" <<'EOF'
set -f
cr_read() {
  cat "$CONSUMER/$1"
}
cr_test() { [ "$2" "$1/$3" ]; }
cr__guard() {
  [ -e "$CONSUMER/$1" ] && cat "$CONSUMER/$1"
}
cr_run() { ( cd "$CONSUMER" && "$@" ); }
_cr_helper() {
  cat "$CONSUMER/$1" # @OFF outside a cr_ function
}
[ -f "$CONSUMER/x" ] && echo top # @OFF top level of the helper file
EOF
cat > "$PA/newdet.sh" <<'EOF'
set -f
CONSUMER="${2:?}"
[ -f "$CONSUMER/new" ] && echo hi # @OFF reached only through the derived closure
EOF
cat > "$PA/orphan.sh" <<'EOF'
set -f
CONSUMER="${2:?}"
[ -f "$CONSUMER/never" ] && echo hi
EOF
# Tree B: CR2. emit-report.sh invokes the three; orphan2.sh is not in the closure and lacks set -f.
cat > "$PB/emit-report.sh" <<'EOF'
#!/usr/bin/env bash
set -euf
SELF="$(cd "$(dirname "$0")" && pwd)"
bash "$SELF/a.sh"; bash "$SELF/b.sh"; bash "${SELF}/c.sh"
. "$SELF/l.sh" || exit 1
. "$SELF/d.sh"
bash "$SELF/d.sh" --run
EOF
cat > "$PB/l.sh" <<'EOF'
# a sourced library: no preamble owed, the pairing rule still binds
lf() { :; }
lg() {
  set +f # @OFF a sourced library is not exempt from the pairing rule
  echo x
}
EOF
cat > "$PB/d.sh" <<'EOF'
dd() { :; } # @OFF sourced AND run as a program, so the preamble binds
EOF
cat > "$PB/a.sh" <<'EOF'
#!/usr/bin/env bash
x=1
f() { :; } # @OFF no preamble set -f before this first function
set -f
EOF
cat > "$PB/b.sh" <<'EOF'
#!/usr/bin/env bash
set -o noglob
g() {
  set +f
  for p in $LIST; do :; done
  set -f
}
h() { set +f; ls *; set -f; }
k() { [ -n "$x" ] || { rc=$?; set +f; return "$rc"; }; set -f; } # @OFF set +f then return
EOF
cat > "$PB/c.sh" <<'EOF'
#!/usr/bin/env bash
set -f
m() {
  set +f # @OFF never set -f again in this function
  echo done
}
n() {
  set -f
}
EOF
cat > "$PB/orphan2.sh" <<'EOF'
for x in *; do :; done
EOF

probe() { # probe <dir> <arm> -- 0 when the arm flags exactly the @OFF lines of the closure files
  local d="$1" arm="$2" want got f
  scan_dir "$d" "$T/probe.tsv" || { err "[$arm] SELF-PROBE: the probe closure did not scan ($(cat "$T/scan.counts" 2>/dev/null))"; return 1; }
  want="$(while IFS= read -r f; do grep -n '@OFF' "$d/$f" | sed "s|^\\([0-9]*\\):.*|$f:\\1|"; done < "$T/closure.list" | LC_ALL=C sort)"
  got="$(awk -F'\t' -v a="$arm" '$3 == a { print $1 ":" $2 }' "$T/probe.tsv" | LC_ALL=C sort -u)"
  if [ -z "$want" ]; then err "[$arm] SELF-PROBE: no @OFF lines were found, so the probe asserts nothing"; return 1; fi
  if [ "$want" != "$got" ]; then
    err "[$arm] SELF-PROBE: flagged {$(printf '%s' "$got" | tr '\n' ' ')} but the offenders are {$(printf '%s' "$want" | tr '\n' ' ')}; a missing one cannot fire, an extra one is a near miss read as an offender"
    return 1
  fi
  say "  self-probe [$arm]: $(printf '%s\n' "$want" | grep -c .) offender(s) flagged, every near miss quiet, closure $(tr '\n' ' ' < "$T/closure.list")"
}
probe "$PA" CR1 || exit 1
probe "$PB" CR2 || exit 1
# The orphans must have stayed out of the closure: a glob-built closure would have flagged them.
scan_dir "$PA" "$T/probe.tsv"; grep -qxF orphan.sh "$T/closure.list" && { err "[closure] SELF-PROBE: orphan.sh, named by no \$SELF invocation, entered the closure"; exit 1; }

# ---------------------------------------------------------------------------
# THE CORPUS.
# ---------------------------------------------------------------------------
if ! scan_dir "$RDIR" "$T/corpus.tsv"; then
  err "the closure of $RDIR/emit-report.sh is below the floor or a file in it was not scanned (files scanned: $(cat "$T/scan.counts")); a corpus that did not scan reads exactly like a clean one"
  exit 1
fi
[ -n "${VCR_DUMP:-}" ] && cp "$T/corpus.tsv" "$VCR_DUMP"
n1="$(awk -F'\t' '$3 == "CR1"' "$T/corpus.tsv" | grep -c .)" || n1=0
n2="$(awk -F'\t' '$3 == "CR2"' "$T/corpus.tsv" | grep -c .)" || n2=0
if [ "$n1" -gt 0 ]; then
  while IFS="$(printf '\t')" read -r f l a c v e; do
    err "[CR1] reconcile/$f:$l ($c on $v) reads a consumer path outside consumer-read.sh's cr_* helpers, so the recorded-PASS key cannot know it was read: $e"
  done < <(awk -F'\t' '$3 == "CR1"' "$T/corpus.tsv")
fi
if [ "$n2" -gt 0 ]; then
  while IFS="$(printf '\t')" read -r f l a c v e; do
    err "[CR2] reconcile/$f:$l ($c): $e -- an unquoted expansion in this script would glob against the cwd, which no key field holds"
  done < <(awk -F'\t' '$3 == "CR2"' "$T/corpus.tsv")
fi
if [ "$fail" -eq 0 ]; then
  say "OK: validate-consumer-reads -- CR1 no raw consumer read, CR2 set -f preamble and paired set +f. Closure: $(grep -c . "$T/closure.list") file(s) from emit-report.sh, $(cat "$T/closure.missing") unresolved name(s)."
  exit 0
fi
printf 'validate-consumer-reads: %s CR1 and %s CR2 finding(s) over a %s-file closure\n' "$n1" "$n2" "$(grep -c . "$T/closure.list")" >&2
exit 1
