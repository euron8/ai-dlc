#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
# presuite-present-key -- drive the PRESENT KEY, the record lookup and the shell wiring of the distribution hook's
# pre-suite step keys (BL-914), from .githooks/pre-push's own bytes, and assert what each tree shape does.
#
# THE SUBJECT. pk_step skips a pre-suite step on a recorded pass. A step that tests a path which does not exist
# reads nothing, so no read key can move when that path appears. The hook keys every record on the PRESENT KEY:
# the sha256 of the raw NUL-separated walk `/usr/bin/find . -path ./.git -prune -o -print0` taken by pk_present,
# one escaped `<path>\t<kind>\t<target>` line per path; a walk find could not finish turns the keys off. pk_init
# writes a START MARK just before that walk, and after every traced step a path newer than the mark makes the run
# unrecordable; pk_finish re-walks when the push recorded anything and deletes this push's records if the key moved.
# Records are named `<slug>.<present[:16]>.key`, carry a `#format k2` header and a non-# `@present` row, and a
# successful record prunes the step's k1 files and keeps the newest 4.
#
# WHAT IT DRIVES, ALL CUT FROM THE HOOK'S BYTES, NEVER A COPY OF THE LOGIC. Per variant (the hook, or a mutated copy
# of it) `mkvar` extracts: pk.py (the `pk_py` heredoc, run through its CLI `present`, `check`, `record`);
# present.sh (the `pk_present` shell function, so every key here comes from the hook's own find line and its
# exit/stderr test); and fns.sh (the whole span from `PK_ON=""` through the end of `pk_py`, every pk_* shell
# function). The W.* cells source fns.sh in a subshell inside a mktemp `git init` repo with its OWN .git, so
# pk_init resolves its key dir there and never touches a real common dir; pk_init's fallback reads the repo's own
# `.githooks/pre-push` copy for the READSET spans. The CLI cells' `u` directory is a minimal stub of the tables
# pk_init writes. No `log`, no `sandbox-exec`, no sleep, no clock-dependent assertion: A5's survivors are ordered
# by seeded `touch -t` mtimes in 2001, and W.samesec creates and removes its path in the same second as the mark.
#
# DIST-ONLY: the subject is `.githooks/pre-push`, which install.sh never ships; core/git-hooks/pre-push carries
# no pk_py.
#
# THE ARMS (cells). Every cell is presence-shaped: a key must be 64 hex, an accept must print its exact
# `N key(s)` line, a refusal its exact reason, a wiring push its exact PASS/skip/not-recorded lines, so a subject
# that dies or prints nothing is RED, never GREEN.
#   A1.create   a git-ignored `.claude/settings.json` (a .gitignore covers it) moves the present key
#   A1.dir      a file becoming an EMPTY directory moves it (empty, so no name is added)
#   A1.link     a symlink retargeted between two existing files moves it
#   A1.content  a content-only edit does NOT move it (both keys 64 hex, equal)
#   A2.holds    a record written by `record` passes `check` on the same tree
#   A2.moved    after a new path is created, `check` refuses with the present-set reason
#   A3.k1       a record with a `#format k1` header and the same body is refused (malformed record)
#   A3.hashrow  a record whose present key sits only in a `#` row is refused (malformed record)
#   A4          tree A's record copied to tree B's filename is refused in tree B (present-set reason)
#   A5          prune keeps exactly the newest 4 `s.<hash>.key`, deletes `s.key` and `s.key.absent`, and leaves
#               the prefix-sharing slug `s-x`'s files alone
#   A6.run      record and check succeed with PATH holding python3 alone (no `log`, no `sandbox-exec`), with a
#               same-cell control that PATH resolves neither
#   A6.grep     no non-comment line of the hook span from `PK_ON=""` to `PK_PY_END` invokes `log stream` or
#               `sandbox-exec`, against a control that the same scan counts the span's `/usr/bin/find` lines
#   A6.nearmiss a comment-only `log stream` line inserted into a hook copy still scans as 0
#   T1.unsearch a directory find cannot read (chmod 0300, restored by the EXIT trap) makes pk_present fail with
#               find's `Permission denied` in walk.err, against a same-cell control that a readable tree keys
#   T1.nlrename a rename inside a directory whose name holds a newline moves the key
#   T1.linknl   a symlink whose target holds NL and TAB does not collide with the tree its unescaped lines spell
#   W.skip      a push records two steps (`[ -f x ]`, `[ -f a ]`), and the next push skips both
#   W.settings  after a git-ignored `.claude/settings.json` is created, the next push runs both steps
#   W.collide   the same, with the old records copied to the new present key's filenames (a 16-hex prefix
#               collision, or a shared common dir): both steps run with the present-set reason
#   W.t2b       a path created after pk_init's walk and removed between two steps leaves no record, and the next
#               push runs the step that tested it (and it FAILs)
#   W.samesec   a path created and removed right after pk_init, in the same second as the mark, leaves no record
#   W.forged    a path created with its parent's mtime restored (`cp -p`, `touch -m -r`) is recorded, then pk_finish's
#               re-walk deletes the record; after it is removed the same way, the next push runs the step
#   W.multi     two steps are recorded, then a path is created with its parent's mtime restored and left present:
#               pk_finish deletes BOTH records (`deleted: 2`), and the forge itself moved no mtime (no not-recorded line)
#   W.rewalkfail a step runs `chmod 0300 sub` (moves no mtime), so pk_finish's re-walk fails: every record is deleted,
#               against a same-cell control that the step passed and was not refused by the mark check
#   T1.esc.bs   file `a\tb` (a literal backslash, then t) does not collide with file `a<TAB>b`
#   T1.esc.nl   a symlink to `x<NL>b` beside file `c` does not collide with a symlink to `x` beside file `b<NL>c`
#   T1.esc.tab  file `p<TAB>l<TAB>x` does not collide with a symlink `p` to `x<TAB>f<TAB>`
#   L1.leak     after a wiring push returns, no process of any name has its cwd under the scratch dir (one listing,
#               no wait); whatever is listed is reaped by pid
#   L1.name     the knock-out control: the old name-filtered listing misses m_bash's bash-named leak keyed on `log stream`,
#               and lists it keyed on the name it carries (`presuite-present-key/run`)
#   L1.control  a child forked while the main shell stands in the scratch dir is listed by its pid, and is no longer
#               listed once killed and waited for
#
# THE MUTANT MATRIX. Every mutant is an exact-once string replacement in a COPY of the hook (`hmut`, guarded by
# the anchor occurring exactly once, `cmp -s`, `bash -n` of the copy, and its pk.py still parsing). It is scored
# on its deciding cell(s) and its named twin(s) only; `run.sh --matrix` scores every mutant on every cell and
# prints one MATRIX line per cell. Re-measure whenever an arm or a mutant is added or changed, from the repo root,
# with the REMEASURE command below.
#   n1  the present key from names only: the esc()'d kind and target dropped from each line
#   n2  check skips the `@present` comparison
#   n3  check ignores the `#format` line, so k1 is accepted
#   n4  prune keeps every record
#   n5  present ignores symlink targets
#   n6  a hook copy with a non-comment `/usr/bin/log stream` line in pk_trace_init
#   n7  esc() is the identity, so a name or target holding NL or TAB spells another tree's lines
#   m_stderr  pk_present ignores find's exit status and stderr
#   m_nl      the walk is `-print` and pk.py splits it on newlines
#   m_own     pk_step passes the record's own `@present` row to check
#   m_univ    the present key is built from the universe listing `$PK_W/u/.is` (pk_present's walk replaced by
#             it, so pk_init and pk_finish agree), not from find
#   m_mmark   the moved check reverted to a per-step mark touched before each step's reset
#   m_rewalk  pk_finish's re-walk removed
#   X1  pk_finish deletes only the last record in `wrote`
#   X2  a failed re-walk is read as no change (ph2 falls back to the start key)
#   X3  esc() does not escape backslash
#   X7  esc() does not escape newline
#   X8  esc() does not escape TAB
#   m_leak    a real `/usr/bin/log stream` backgrounded in pk_trace_init
#   m_bash    a backgrounded subshell in pk_trace_init that never execs (it blocks in the `read` builtin on a fifo),
#             so its command reads as bash
# MUTANT-MATRIX n1 decides=A1.dir,A1.link twins=A1.create
# MUTANT-MATRIX n2 decides=A2.moved,A4 twins=A2.holds
# MUTANT-MATRIX n3 decides=A3.k1 twins=A3.hashrow
# MUTANT-MATRIX n4 decides=A5 twins=A2.holds
# MUTANT-MATRIX n5 decides=A1.link twins=A1.dir
# MUTANT-MATRIX n6 decides=A6.grep twins=A6.run
# MUTANT-MATRIX m_leak decides=L1.leak twins=W.skip
# MUTANT-MATRIX m_bash decides=L1.leak twins=W.skip
# MUTANT-MATRIX-CONTROL m_bash_named why=L1.leak under the name-filtered listing stays GREEN on m_bash keyed on `log stream` and goes RED keyed on the name its child carries, so the kill is the cwd listing's
# MUTANT-MATRIX n7 decides=T1.linknl twins=A1.link
# MUTANT-MATRIX m_stderr decides=T1.unsearch twins=A1.create
# MUTANT-MATRIX m_nl decides=T1.nlrename twins=A1.create
# MUTANT-MATRIX m_own decides=W.collide twins=W.settings
# MUTANT-MATRIX m_univ decides=W.settings twins=W.skip
# MUTANT-MATRIX m_mmark decides=W.t2b,W.samesec twins=W.skip
# MUTANT-MATRIX m_rewalk decides=W.forged twins=W.skip
# MUTANT-MATRIX X1 decides=W.multi twins=W.forged
# MUTANT-MATRIX X2 decides=W.rewalkfail twins=W.forged
# MUTANT-MATRIX X3 decides=T1.esc.bs twins=T1.esc.nl
# MUTANT-MATRIX X7 decides=T1.esc.nl twins=T1.esc.bs
# MUTANT-MATRIX X8 decides=T1.esc.tab twins=T1.esc.bs
# MUTANT-MATRIX-REMEASURE bash core/fixtures/presuite-present-key/run.sh --matrix
#
# Usage: run.sh [--matrix]
# Exit 0 = every arm and mutant hold, 1 = an arm regressed or a mutant survived, 2 = the fixture could not run.
set -u

MODE=plain
case "${1:-}" in
  "") ;;
  --matrix) MODE=matrix ;;
  *) echo "presuite-present-key: usage: run.sh [--matrix]" >&2; exit 2 ;;
esac
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT=""
for cand in "$HERE/../../.." "$HERE/../.."; do
  if [ -f "$cand/.githooks/pre-push" ]; then ROOT="$(cd "$cand" && pwd)"; break; fi
done
[ -n "$ROOT" ] || { echo "FIXTURE BROKEN: no .githooks/pre-push above $HERE"; exit 2; }
HOOK="$ROOT/.githooks/pre-push"
echo "HERMETIC-CONSUMED .githooks/pre-push"
PY3="$(command -v python3)" || { echo "FIXTURE BROKEN: python3 not found (declared in tools.decl)"; exit 2; }

rc=0
ok()  { printf 'ok    %s\n' "$*"; }
bad() { printf 'FAIL  %s\n' "$*"; rc=1; }
broken() { echo "FIXTURE BROKEN: $*"; exit 2; }
MUT_LIB="$HERE/../lib/mutant.sh"
[ -f "$MUT_LIB" ] || broken "lib/mutant.sh not found beside $HERE"
. "$MUT_LIB"
[ -f "$HERE/../lib/matrix.sh" ] || broken "lib/matrix.sh not found beside $HERE"
. "$HERE/../lib/matrix.sh"

T="$(mktemp -d)" && T="$(cd "$T" && pwd -P)" || broken "no scratch dir"
# The unsearchable dir is made searchable again before the tree is removed, or rm cannot list it.
# W.rewalkfail's step leaves "$T/rwf/sub" at 0300 until the cell restores it; the trap restores it too.
trap 'chmod 0700 "$T/w/u/locked" "$T/rwf/sub" 2>/dev/null; rm -rf "$T"' EXIT
# Leak guard. scoped_pids prints the pid of EVERY process whose cwd is this run's scratch dir $T or lies under it
# (one `lsof -a -d cwd` over all processes), whatever its name. Every hook copy runs in a repo under $T, and a forked
# child inherits its cwd at fork, so a process a push leaves behind is listed from the instant it exists -- before it
# execs, and whether or not it ever does; a peer's process is never under $T. No process of the fixture itself is
# listed: $T is minted here, the main shell never stands in it when the listing runs (L1.control's cd is undone
# before it lists), and every subshell that cd's under $T (pkey, push, W.forged) has exited before a listing runs.
# L1_NAME, set only by the m_bash control, restores the old name-filtered listing: only pids whose command ALSO
# matches that ERE.
scoped_pids() {
  if [ -n "${L1_NAME:-}" ]; then
    ps -axo pid=,command= 2>/dev/null | awk -v re="$L1_NAME" '$0 ~ re { print $1 }' > "$T/l1.named"
  fi
  lsof -a -d cwd -Fpn 2>/dev/null | awk -v t="$T" -v named="${L1_NAME:+$T/l1.named}" '
    BEGIN { if (named != "") while ((getline l < named) > 0) { sub(/^[[:space:]]+/, "", l); N[l] = 1 } }
    /^p/ { p = substr($0, 2); next }
    /^n/ { n = substr($0, 2); if ((n == t || index(n, t "/") == 1) && (named == "" || (p in N))) print p }'
  return 0
}
LEAKPIDS="$T/leakpids"; : > "$LEAKPIDS"; export LEAKPIDS
# m_bash's leaked child blocks reading this fifo, opened read-write so the open never blocks and no writer is needed.
LEAKFIFO="$T/leakfifo"; mkfifo "$LEAKFIFO" || broken "no fifo at $LEAKFIFO"; export LEAKFIFO

# ---- extraction: every piece from the hook's own bytes ----
parses() { # <pk.py>: the CLI with no arguments falls through to exit 2; a copy that does not parse exits 1
  "$PY3" -I "$1" > /dev/null 2>&1; [ $? -eq 2 ]
}
# mkvar <dir> <hook>: the variant dir -- hook, pk.py, present.sh, fns.sh; non-zero when any piece is missing
mkvar() {
  mkdir -p "$1" && cp "$2" "$1/hook" || return 1
  sed -n "/^pk_py() { cat <<'PK_PY_END'\$/,/^PK_PY_END\$/p" "$2" | sed '1d;$d' > "$1/pk.py"
  awk '/^pk_present\(\) \{/ { on = 1 } on { print } on && /^\}$/ { exit }' "$2" > "$1/present.sh"
  { sed -n '/^PK_ON=""; PK_TR=""/,/^PK_PY_END$/p' "$2"; printf '}\n'; } > "$1/fns.sh"
  [ -s "$1/pk.py" ] && grep -q '^def present(top):$' "$1/pk.py" && grep -q '^def prune(rec):$' "$1/pk.py" && parses "$1/pk.py" \
    && grep -q '^pk_present() {' "$1/present.sh" && grep -q '^pk_step() {' "$1/fns.sh" && grep -q '^pk_finish() {' "$1/fns.sh" \
    && bash -n "$1/fns.sh"
}
V0="$T/v0"
mkvar "$V0" "$HOOK" || broken "the pk_py heredoc, pk_present or the pk_* span could not be extracted from $HOOK"

# ---- worlds, built once ----
W="$T/w"; mkdir -p "$W/base/sub" "$W/base/.git"
printf 'alpha\n' > "$W/base/a.txt"; printf 'beta\n' > "$W/base/sub/b.txt"; printf 'n\n' > "$W/base/node"
printf '.claude/settings.json\n' > "$W/base/.gitignore"; printf 'x\n' > "$W/base/.git/HEAD"
ln -s a.txt "$W/base/lnk"
for w in create dir link content moved B; do cp -Rp "$W/base" "$W/$w"; done
mkdir "$W/create/.claude"; printf '{}\n' > "$W/create/.claude/settings.json"
rm "$W/dir/node"; mkdir "$W/dir/node"
ln -sfn sub/b.txt "$W/link/lnk"
printf 'ALPHA\n' > "$W/content/a.txt"
printf 'new\n' > "$W/moved/appeared"
printf 'b\n' > "$W/B/only-in-b"
NLD="$W/nl/a
b"
mkdir -p "$W/nl/a" "$NLD" "$W/sa" "$W/sb/q" "$W/u/locked"
printf 'x\n' > "$NLD/c"
ln -s "x
q	d	" "$W/sa/p"; ln -s x "$W/sb/p"
printf 'x\n' > "$W/u/locked/f"; printf 'x\n' > "$W/u/plain"; chmod 0300 "$W/u/locked"
# The escape collision pairs: under an esc() missing one replace, each pair spells the same lines.
mkdir -p "$W/bs1" "$W/bs2" "$W/nl1" "$W/nl2" "$W/tb1" "$W/tb2"
: > "$W/bs1/a\\tb"; : > "$W/bs2/a	b"
ln -s "x
b" "$W/nl1/a"; : > "$W/nl1/c"; ln -s x "$W/nl2/a"; : > "$W/nl2/b
c"
: > "$W/tb1/p	l	x"; ln -s "x	f	" "$W/tb2/p"
[ -f "$W/bs1/a\\tb" ] && [ -f "$W/bs2/a	b" ] && [ -L "$W/nl1/a" ] && [ -f "$W/nl2/b
c" ] && [ -f "$W/tb1/p	l	x" ] && [ "$(readlink "$W/tb2/p")" = "x	f	" ] || broken "an escape collision world did not build"
[ -L "$W/link/lnk" ] && [ "$(readlink "$W/link/lnk")" = sub/b.txt ] && [ "$(readlink "$W/base/lnk")" = a.txt ] \
  && [ -d "$W/dir/node" ] && ! cmp -s "$W/base/a.txt" "$W/content/a.txt" && [ -f "$NLD/c" ] && [ -L "$W/sa/p" ] \
  && [ ! -r "$W/u/locked" ] || broken "a world did not build"

# The stub tables Tree reads. .now carries the one read file, so check never touches the disk for it.
U="$T/u"; mkdir -p "$U"
printf 'a.txt\t%s\nsub/b.txt\t%s\n' 1111111111111111111111111111111111111111111111111111111111111111 2222222222222222222222222222222222222222222222222222222222222222 > "$U/.now"
: > "$U/.ls.now"; : > "$U/.tools"; : > "$U/.ftools"; : > "$U/.pathcmds"
RL="$T/readlist"; printf 'a.txt\n' > "$RL"
T2="$T/t2"; mkdir -p "$T2"
CMD=abababababababababababababababababababababababababababababababab
PRESENT_WHY="the set of paths present under the work tree changed"

# The wiring repo, built once: its own .git, a .gitignore covering .claude/settings.json, files a and x, and a copy
# of the hook at .githooks/pre-push, the path pk_init falls back to for the READSET spans.
R0="$T/repo0"; mkdir -p "$R0/.githooks"
( cd "$R0" && git init -q . && printf '.claude/settings.json\n' > .gitignore && printf 'a\n' > a && printf 'x\n' > x \
    && cp "$HOOK" .githooks/pre-push && git add -A && git -c user.name=f -c user.email=f@f commit -qm i ) > "$T/repo0.log" 2>&1 \
  && [ -f "$R0/.git/HEAD" ] || broken "the wiring repo did not build ($(head -1 "$T/repo0.log"))"
# W.rewalkfail's repo, built once at a literal path: the wiring repo plus a searchable subdirectory its step locks.
mkdir "$T/rwf" && cp -Rp "$R0/." "$T/rwf/" && mkdir "$T/rwf/sub" && printf 'f\n' > "$T/rwf/sub/f" \
  || broken "the re-walk repo did not build"

# pkey <V> <dir> -> the 64-hex present key from the variant's own pk_present; non-zero when it yields none
pkey() {
  local k
  k="$(cd "$2" && PK_W="$1" && PK_TOP="$(pwd -P)" && . "$1/present.sh" && pk_present 2>/dev/null)" || return 1
  case "$k" in *[!0-9a-f]*|"") return 1 ;; esac
  [ "${#k}" = 64 ] || return 1
  printf '%s' "$k"
}
# mkrec <pk.py> <keydir> <tree> <present> [PATH] -> the record path; non-zero unless record printed its exact line
mkrec() {
  local r="$2/s.${4:0:16}.key" o
  o="$(PATH="${5:-$PATH}" "$PY3" -I "$1" record "$r" "$U" "$3" "$CMD" "$4" "$RL" "$T2" true 2>&1)" || return 1
  [ "$o" = "2 key(s), 0 git" ] && [ -f "$r" ] || return 1
  printf '%s' "$r"
}
# chk <pk.py> <rec> <tree> <present> <want rc> <want output> [PATH] -> 0 when check answered exactly that
chk() {
  local o r
  o="$(PATH="${7:-$PATH}" "$PY3" -I "$1" check "$2" "$U" "$3" "$CMD" "$4" 2>&1)"; r=$?
  [ "$r" = "$5" ] && [ "$o" = "$6" ]
}
# span_hits <hook> <ERE> -> non-comment lines of the span from `PK_ON=""` to `PK_PY_END` matching the ERE
span_hits() {
  awk -v re="$2" '/^PK_ON=""; PK_TR=""/ { f = 1 } f && $0 !~ /^[[:space:]]*#/ && $0 ~ re { n++ } /^PK_PY_END$/ { f = 0 } END { print n + 0 }' "$1"
}
# push <V> <repo> <out> <actions>: one prefix -- pk_init, the actions (pk_step calls), pk_finish -- in a subshell
# that sources the variant's pk_* span inside the repo.
push() {
  ( cd "$2" && . "$1/fns.sh" && fail=0 && pk_init && eval "$4"; pk_finish; printf 'fail=%s\n' "${fail:-}" ) < /dev/null > "$3" 2>&1
}
nrec() { # <repo> -> the number of `.key` records in its key dir
  local f c=0
  for f in "$1/.git/ai-dlc-presuite-keys"/*.key; do [ -f "$f" ] && c=$((c + 1)); done
  printf '%s' "$c"
}
nline() { # <file> <exact line prefix> -> lines starting with it
  local n
  n="$(grep -c -F -- "$2" "$1")" || n=0
  printf '%s' "$n"
}
newrepo() { # -> a fresh copy of the wiring repo
  local d
  d="$(mktemp -d "$T/wr.XXXXXX")" && cp -Rp "$R0/." "$d/" && printf '%s' "$d"
}
STEPS='pk_step s1 [ -f x ]; pk_step s2 [ -f a ]'
SKIPLN='   skipped on a recorded pass: '
NOTREC='   ..    not recorded: the work tree changed since the present walk ('
RUNSLN="   ..    runs: $PRESENT_WHY"

# cell <V> <cell> -> 0 GREEN (the arm holds), 1 RED
cell() {
  local v="$1" p="$1/pk.py" k0 k1 kd r r2 n c f d o
  case "$2" in
    A1.create|A1.dir|A1.link)
      k0="$(pkey "$v" "$W/base")" && k1="$(pkey "$v" "$W/${2#A1.}")" && [ "$k0" != "$k1" ] ;;
    A1.content)
      k0="$(pkey "$v" "$W/base")" && k1="$(pkey "$v" "$W/content")" && [ "$k0" = "$k1" ] ;;
    A2.holds)
      kd="$(mktemp -d "$T/kd.XXXXXX")" && k0="$(pkey "$v" "$W/base")" && r="$(mkrec "$p" "$kd" "$W/base" "$k0")" \
        && chk "$p" "$r" "$W/base" "$k0" 0 "2 key(s)" ;;
    A2.moved)
      kd="$(mktemp -d "$T/kd.XXXXXX")" && k0="$(pkey "$v" "$W/base")" && k1="$(pkey "$v" "$W/moved")" && [ "$k0" != "$k1" ] \
        && r="$(mkrec "$p" "$kd" "$W/base" "$k0")" && chk "$p" "$r" "$W/moved" "$k1" 1 "$PRESENT_WHY" ;;
    A3.k1)
      kd="$(mktemp -d "$T/kd.XXXXXX")" && k0="$(pkey "$v" "$W/base")" && r="$(mkrec "$p" "$kd" "$W/base" "$k0")" \
        && sed '1s/^#format k2$/#format k1/' "$r" > "$kd/k1.key" && ! cmp -s "$r" "$kd/k1.key" \
        && chk "$p" "$kd/k1.key" "$W/base" "$k0" 1 "malformed record" ;;
    A3.hashrow)
      kd="$(mktemp -d "$T/kd.XXXXXX")" && k0="$(pkey "$v" "$W/base")" && r="$(mkrec "$p" "$kd" "$W/base" "$k0")" \
        && awk 'NR == 5 { sub(/^@present/, "# @present") } { print }' "$r" > "$kd/hash.key" && ! cmp -s "$r" "$kd/hash.key" \
        && grep -q "^# @present.$k0\$" "$kd/hash.key" && chk "$p" "$kd/hash.key" "$W/base" "$k0" 1 "malformed record" ;;
    A4)
      kd="$(mktemp -d "$T/kd.XXXXXX")" && k0="$(pkey "$v" "$W/base")" && k1="$(pkey "$v" "$W/B")" && [ "$k0" != "$k1" ] \
        && r="$(mkrec "$p" "$kd" "$W/base" "$k0")" && r2="$kd/s.${k1:0:16}.key" && cp "$r" "$r2" \
        && chk "$p" "$r2" "$W/B" "$k1" 1 "$PRESENT_WHY" ;;
    A5)
      kd="$(mktemp -d "$T/kd.XXXXXX")" || return 1
      for n in 1 2 3 4 5; do printf 'old\n' > "$kd/s.000000000000000$n.key"; touch -t "200${n}01010000" "$kd/s.000000000000000$n.key"; done
      printf 'k1\n' > "$kd/s.key"; printf 'k1\n' > "$kd/s.key.absent"
      printf 'other\n' > "$kd/s-x.0000000000000009.key"; printf 'other\n' > "$kd/s-x.key"
      k0="$(pkey "$v" "$W/base")" && r="$(mkrec "$p" "$kd" "$W/base" "$k0")" || return 1
      c=0; for f in "$kd"/* "$kd"/.[!.]*; do [ -e "$f" ] && c=$((c + 1)); done
      [ "$c" = 6 ] || return 1
      for f in "${r##*/}" s.0000000000000005.key s.0000000000000004.key s.0000000000000003.key s-x.0000000000000009.key s-x.key; do
        [ -f "$kd/$f" ] || return 1
      done ;;
    A6.run)
      [ -d "$T/pbin" ] || { mkdir "$T/pbin" && ln -s "$PY3" "$T/pbin/python3"; } || return 1
      ! PATH="$T/pbin" command -v log > /dev/null 2>&1 && ! PATH="$T/pbin" command -v sandbox-exec > /dev/null 2>&1 \
        && PATH="$T/pbin" command -v python3 > /dev/null 2>&1 || return 1
      kd="$(mktemp -d "$T/kd.XXXXXX")" && k0="$(pkey "$v" "$W/base")" && r="$(mkrec "$p" "$kd" "$W/base" "$k0" "$T/pbin")" \
        && chk "$p" "$r" "$W/base" "$k0" 0 "2 key(s)" "$T/pbin" ;;
    A6.grep)
      n="$(span_hits "$v/hook" 'log stream|sandbox-exec')"; c="$(span_hits "$v/hook" '/usr/bin/find')"
      [ "$n" = 0 ] && [ "$c" -gt 0 ] ;;
    T1.unsearch)
      : > "$v/walk.err"
      ! pkey "$v" "$W/u" > /dev/null && grep -q 'locked.*Permission denied' "$v/walk.err" && pkey "$v" "$W/base" > /dev/null ;;
    T1.nlrename)
      k0="$(pkey "$v" "$W/nl")" || return 1
      mv "$NLD/c" "$NLD/d" || return 1
      k1="$(pkey "$v" "$W/nl")"; r=$?
      mv "$NLD/d" "$NLD/c" || return 1
      [ "$r" = 0 ] && [ "$k0" != "$k1" ] ;;
    T1.linknl)
      k0="$(pkey "$v" "$W/sa")" && k1="$(pkey "$v" "$W/sb")" && [ "$k0" != "$k1" ] ;;
    W.skip)
      d="$(newrepo)" && push "$v" "$d" "$d.1" "$STEPS" && [ "$(nrec "$d")" = 2 ] && [ "$(nline "$d.1" "$SKIPLN")" = 0 ] \
        && push "$v" "$d" "$d.2" "$STEPS" && [ "$(nline "$d.2" "$SKIPLN")" = 2 ] \
        && grep -qxF '   ..    pre-suite keys: 2 of 2 step(s) skipped on a recorded pass: s1 s2' "$d.2" ;;
    W.settings)
      d="$(newrepo)" && push "$v" "$d" "$d.1" "$STEPS" && [ "$(nrec "$d")" = 2 ] \
        && mkdir "$d/.claude" && printf '{}\n' > "$d/.claude/settings.json" \
        && push "$v" "$d" "$d.2" "$STEPS" && [ "$(nline "$d.2" "$SKIPLN")" = 0 ] && [ "$(grep -cx '   PASS' "$d.2")" = 2 ] \
        && grep -qxF '   ..    pre-suite keys: 0 of 2 step(s) skipped on a recorded pass' "$d.2" ;;
    W.collide)
      d="$(newrepo)" && push "$v" "$d" "$d.1" "$STEPS" && [ "$(nrec "$d")" = 2 ] \
        && mkdir "$d/.claude" && printf '{}\n' > "$d/.claude/settings.json" \
        && push "$v" "$d" "$d.2" 'for r in .git/ai-dlc-presuite-keys/*.key; do b="${r##*/}"; cp "$r" ".git/ai-dlc-presuite-keys/${b%%.*}.${PK_PH:0:16}.key" 2>/dev/null; done; '"$STEPS" \
        && [ "$(nline "$d.2" "$SKIPLN")" = 0 ] && [ "$(grep -cxF "$RUNSLN" "$d.2")" = 2 ] ;;
    W.t2b)
      d="$(newrepo)" && push "$v" "$d" "$d.1" 'printf y > y; pk_step s1 [ -f y ]; rm y; pk_step s2 [ -f a ]' \
        && [ "$(nrec "$d")" = 0 ] && [ "$(nline "$d.1" "$NOTREC")" = 1 ] \
        && push "$v" "$d" "$d.2" 'pk_step s1 [ -f y ]' && [ "$(nline "$d.2" "$SKIPLN")" = 0 ] && grep -qx 'fail=1' "$d.2" ;;
    W.samesec)
      d="$(newrepo)" && push "$v" "$d" "$d.1" ': > z; rm z; pk_step s1 [ -f x ]' \
        && [ "$(nrec "$d")" = 0 ] && [ "$(nline "$d.1" "$NOTREC")" = 1 ] && grep -qx 'fail=0' "$d.1" ;;
    L1.leak)
      d="$(newrepo)" && push "$v" "$d" "$d.1" "$STEPS" || return 1
      # The push has returned: any process still standing under $T is a leak, read once, with no wait.
      scoped_pids > "$d.leak"
      n="$(grep -c . "$d.leak")" || n=0
      # Reap by recorded pid: what the listing found, and what the mutant recorded.
      for f in $(cat "$d.leak" "$LEAKPIDS"); do kill "$f" 2>/dev/null; done
      : > "$LEAKPIDS"
      [ "$n" = 0 ] ;;
    W.forged)
      d="$(newrepo)" && push "$v" "$d" "$d.1" 'cp -p a y && touch -m -r a . && pk_step s1 [ -f y ]' \
        && [ "$(nrec "$d")" = 0 ] && grep -q 'every record this push wrote is deleted: 1$' "$d.1" && grep -qx 'fail=0' "$d.1" \
        && ( cd "$d" && rm y && touch -m -r a . ) \
        && push "$v" "$d" "$d.2" 'pk_step s1 [ -f y ]' && [ "$(nline "$d.2" "$SKIPLN")" = 0 ] && grep -qx 'fail=1' "$d.2" ;;
    W.multi)
      d="$(newrepo)" && push "$v" "$d" "$d.1" "$STEPS"'; cp -p a y && touch -m -r a .' \
        && [ -f "$d/y" ] && [ "$(nrec "$d")" = 0 ] && grep -q 'every record this push wrote is deleted: 2$' "$d.1" \
        && [ "$(nline "$d.1" "$NOTREC")" = 0 ] && [ "$(grep -cx '   PASS' "$d.1")" = 2 ] && grep -qx 'fail=0' "$d.1" ;;
    W.rewalkfail)
      # The one repo at the literal "$T/rwf", so the EXIT trap restores its mode if the cell dies mid-way. A record a
      # mutant left behind is removed first, or the next variant's s1 would skip and never chmod.
      d="$T/rwf"; rm -f "$d/.git/ai-dlc-presuite-keys"/*.key
      push "$v" "$d" "$d.1" 'pk_step s1 chmod 0300 sub'
      [ ! -r "$d/sub" ]; c=$?
      chmod 0700 "$d/sub" || return 1
      [ "$c" = 0 ] && [ "$(nrec "$d")" = 0 ] \
        && grep -q ' at the start, (the re-walk failed) at the end) -- every record this push wrote is deleted: 1$' "$d.1" \
        && [ "$(nline "$d.1" "$NOTREC")" = 0 ] && grep -qx '   PASS' "$d.1" && grep -qx 'fail=0' "$d.1" ;;
    T1.esc.bs|T1.esc.nl|T1.esc.tab)
      case "$2" in T1.esc.bs) f=bs ;; T1.esc.nl) f=nl ;; *) f=tb ;; esac
      k0="$(pkey "$v" "$W/${f}1")" && k1="$(pkey "$v" "$W/${f}2")" && [ "$k0" != "$k1" ] ;;
    *) return 1 ;;
  esac
}

# ---- the unmutated run: every cell once, each flag set only in its passing branch ----
if cell "$V0" A1.create; then ok "A1.create a git-ignored .claude/settings.json moves the present key"; B_A1create=1; else bad "A1.create the present key did not move on a git-ignored file"; fi
if cell "$V0" A1.dir; then ok "A1.dir a file becoming an empty directory moves the present key"; B_A1dir=1; else bad "A1.dir the present key did not move on file->dir"; fi
if cell "$V0" A1.link; then ok "A1.link a symlink retarget moves the present key"; B_A1link=1; else bad "A1.link the present key did not move on a symlink retarget"; fi
if cell "$V0" A1.content; then ok "A1.content a content-only edit leaves the present key (64 hex) unmoved"; else bad "A1.content the present key moved on a content-only edit, or was not 64 hex"; fi
if cell "$V0" A2.holds; then ok "A2.holds a recorded pass is accepted on the same tree (2 key(s))"; B_A2holds=1; else bad "A2.holds the record did not hold on its own tree"; fi
if cell "$V0" A2.moved; then ok "A2.moved a new path refuses the record: $PRESENT_WHY"; B_A2moved=1; else bad "A2.moved the record was not refused with the present-set reason after a path appeared"; fi
if cell "$V0" A3.k1; then ok "A3.k1 a #format k1 record is refused as malformed"; B_A3k1=1; else bad "A3.k1 a k1 record was not refused as malformed"; fi
if cell "$V0" A3.hashrow; then ok "A3.hashrow a present key only in a # row is refused as malformed"; B_A3hashrow=1; else bad "A3.hashrow a #-row present key was not refused as malformed"; fi
if cell "$V0" A4; then ok "A4 tree A's record under tree B's filename is refused in tree B"; B_A4=1; else bad "A4 tree A's record was not refused in tree B"; fi
if cell "$V0" A5; then ok "A5 prune keeps the newest 4, drops s.key and s.key.absent, leaves s-x alone"; B_A5=1; else bad "A5 prune left the wrong set of files"; fi
if cell "$V0" A6.run; then ok "A6.run record and check pass with no log and no sandbox-exec on PATH"; B_A6run=1; else bad "A6.run record or check failed with PATH stripped of log and sandbox-exec"; fi
if cell "$V0" A6.grep; then ok "A6.grep the pk span invokes neither log stream nor sandbox-exec (control: its /usr/bin/find lines count)"; B_A6grep=1; else bad "A6.grep the pk span invokes log stream or sandbox-exec, or the scan control read 0"; fi
# The near-miss: a comment line naming the tool is not an invocation, so the scan must still read 0.
awk '{ print } /^pk_trace_init\(\) \{/ { print "  # /usr/bin/log stream is not used here" }' "$HOOK" > "$T/hook.near"
if ! cmp -s "$HOOK" "$T/hook.near" && [ "$(span_hits "$T/hook.near" 'log stream|sandbox-exec')" = 0 ] \
  && [ "$(span_hits "$T/hook.near" '/usr/bin/find')" -gt 0 ]; then ok "A6.nearmiss a comment-only log stream line scans as 0"; else bad "A6.nearmiss the comment insertion did not apply, or the scan counted a comment"; fi
if cell "$V0" T1.unsearch; then ok "T1.unsearch an unreadable directory turns the present key off (find's Permission denied in walk.err)"; B_T1unsearch=1; else bad "T1.unsearch a walk under an unreadable directory still produced a key, or the readable control did not"; fi
if cell "$V0" T1.nlrename; then ok "T1.nlrename a rename inside a newline-named directory moves the present key"; B_T1nlrename=1; else bad "T1.nlrename the present key did not move on a rename inside a newline-named directory"; fi
if cell "$V0" T1.linknl; then ok "T1.linknl a symlink target holding NL and TAB does not collide with the tree it would spell"; B_T1linknl=1; else bad "T1.linknl a NL/TAB symlink target collided with the forged tree"; fi
if cell "$V0" W.skip; then ok "W.skip pk_step records two steps and the next push skips both (2 of 2)"; B_Wskip=1; else bad "W.skip the wiring did not record, or the next push did not skip both steps"; fi
if cell "$V0" W.settings; then ok "W.settings a git-ignored .claude/settings.json makes the next push run both steps"; B_Wsettings=1; else bad "W.settings a push after a git-ignored file appeared skipped a step"; fi
if cell "$V0" W.collide; then ok "W.collide records under the new key's filenames are refused: both steps run with the present-set reason"; B_Wcollide=1; else bad "W.collide a record copied to the new key's filename was used"; fi
if cell "$V0" W.t2b; then ok "W.t2b a path created after the walk and removed between steps leaves no record, and the next push runs (FAIL)"; B_Wt2b=1; else bad "W.t2b a step that ran while a since-removed path existed was recorded, or the next push skipped"; fi
if cell "$V0" W.samesec; then ok "W.samesec a path created and removed in the mark's second leaves no record"; B_Wsamesec=1; else bad "W.samesec a same-second create-then-remove after the mark was recorded"; fi
if cell "$V0" L1.leak; then ok "L1.leak no process of any name started by a wiring push survives it under the scratch dir"; B_L1leak=1; else bad "L1.leak a wiring push left a process running under the scratch dir"; fi
if cell "$V0" W.forged; then ok "W.forged a path created with its parent's mtime restored: pk_finish deletes the record, the next push runs (FAIL)"; B_Wforged=1; else bad "W.forged a forged-mtime create kept its record, or the next push skipped"; fi
if cell "$V0" W.multi; then ok "W.multi a forged create after two recorded steps: pk_finish deletes both records (deleted: 2)"; B_Wmulti=1; else bad "W.multi a forged create after two recorded steps did not delete both records"; fi
if cell "$V0" W.rewalkfail; then ok "W.rewalkfail a step leaves sub unsearchable: the re-walk fails and every record is deleted"; B_Wrewalkfail=1; else bad "W.rewalkfail a failed re-walk kept a record, or the step did not pass unrefused"; fi
if cell "$V0" T1.esc.bs; then ok "T1.esc.bs file a\\tb (literal backslash) does not collide with file a<TAB>b"; B_T1escbs=1; else bad "T1.esc.bs the backslash pair collided"; fi
if cell "$V0" T1.esc.nl; then ok "T1.esc.nl symlink to x<NL>b plus c does not collide with symlink to x plus b<NL>c"; B_T1escnl=1; else bad "T1.esc.nl the newline pair collided"; fi
if cell "$V0" T1.esc.tab; then ok "T1.esc.tab file p<TAB>l<TAB>x does not collide with symlink p to x<TAB>f<TAB>"; B_T1esctab=1; else bad "T1.esc.tab the TAB pair collided"; fi

# ---- mutants ----
ALL_CELLS="L1.leak A1.create A1.dir A1.link A1.content A2.holds A2.moved A3.k1 A3.hashrow A4 A5 A6.run A6.grep T1.unsearch T1.nlrename T1.linknl T1.esc.bs T1.esc.nl T1.esc.tab W.skip W.settings W.collide W.t2b W.samesec W.forged W.multi W.rewalkfail"
SELF_FILE="$HERE/run.sh"
mx_row() { # <mutant> <decides|twins> -> that field of the mutant's single header row
  local n="$1" f="$2" l w c=0 v=""
  while IFS= read -r l; do
    case "$l" in
      "# MUTANT-MATRIX $n "*)
        c=$((c + 1))
        for w in ${l#"# MUTANT-MATRIX $n "}; do case "$w" in "$f="*) v="${w#"$f="}" ;; esac; done ;;
    esac
  done < "$SELF_FILE"
  [ "$c" -eq 1 ] && printf '%s' "$v"
}
# score <mutant> <V>: 0 when every deciding cell is RED and every twin GREEN. --matrix adds every other cell.
score() {
  local m="$1" v="$2" dec tw a res=0
  dec="$(mx_row "$m" decides)"; tw="$(mx_row "$m" twins)"
  [ -n "$dec" ] && [ -n "$tw" ] || { bad "FIXTURE BROKEN: no single MUTANT-MATRIX row for $m"; return 1; }
  for a in ${dec//,/ }; do
    if cell "$v" "$a"; then res=1; [ "$MODE" = matrix ] && matrix_row "$m" "$a" 0 GREEN no
    else [ "$MODE" = matrix ] && matrix_row "$m" "$a" 1 TRIPPED yes; fi
  done
  for a in ${tw//,/ }; do
    if cell "$v" "$a"; then [ "$MODE" = matrix ] && matrix_row "$m" "$a" 0 GREEN no
    else res=1; bad "$m: its twin $a also tripped -- the mutant is not confined to its own arm"
      [ "$MODE" = matrix ] && matrix_row "$m" "$a" 1 TRIPPED no; fi
  done
  if [ "$MODE" = matrix ]; then
    for a in $ALL_CELLS; do
      case ",$dec,$tw," in *",$a,"*) continue ;; esac
      if cell "$v" "$a"; then matrix_row "$m" "$a" 0 GREEN no; else matrix_row "$m" "$a" 1 TRIPPED no; fi
    done
  fi
  return "$res"
}
# hmut <name> <old> <new> [<old> <new>]...: $T/v.<name>, a variant built from a hook copy with each <old> replaced
# by <new>; non-zero (reported) when an anchor does not occur exactly once, the copy is unchanged, or the copy
# does not parse (bash -n of its pk_* span, its pk.py's CLI fall-through).
hmut() {
  local n="$1" o
  shift
  o="$("$PY3" -I -c '
import sys
s = open(sys.argv[1], encoding="utf-8", errors="surrogateescape").read()
a = sys.argv[3:]
for i in range(0, len(a), 2):
    if s.count(a[i]) != 1:
        print("anchor %d occurs %d times" % (i // 2 + 1, s.count(a[i]))); sys.exit(3)
    s = s.replace(a[i], a[i + 1])
open(sys.argv[2], "w", encoding="utf-8", errors="surrogateescape").write(s)
' "$HOOK" "$T/h.$n" "$@" 2>&1)" || { bad "$n DID NOT APPLY -- $o"; return 1; }
  if cmp -s "$HOOK" "$T/h.$n"; then bad "$n DID NOT APPLY -- the copy is unchanged"; return 1; fi
  mkvar "$T/v.$n" "$T/h.$n" || { bad "$n DID NOT APPLY -- the mutated hook no longer extracts or parses"; return 1; }
}
# mrun <name>: score the built variant; a survivor is reported here, a kill by the caller's literal mutant_killed
mrun() {
  local mr=0 lp
  score "$1" "$T/v.$1" || mr=1
  # Reap by recorded pid whatever a mutant's wiring push started (the twin cell pushes after L1.leak has reaped).
  for lp in $(cat "$LEAKPIDS"); do kill "$lp" 2>/dev/null; done
  : > "$LEAKPIDS"
  [ "$mr" = 0 ] || { bad "$1 SURVIVED"; return 1; }
}

hmut n1 'out.append(esc(rel) + b"\t" + k + b"\t" + esc(tgt) + b"\n")' 'out.append(esc(rel) + b"\n")' \
  && mrun n1 && mutant_killed "$(( ${B_A1dir:-0} && ${B_A1link:-0} ))" n1 "n1 names-only present key -- A1.dir and A1.link red, A1.create green"
hmut n2 'if lines[4] != "@present' 'if False and lines[4] != "@present' \
  && mrun n2 && mutant_killed "$(( ${B_A2moved:-0} && ${B_A4:-0} ))" n2 "n2 check skips @present -- A2.moved and A4 red, A2.holds green"
hmut n3 'if lines[:3] != ["#format k2", ' 'if lines[1:3] != [' \
  && mrun n3 && mutant_killed "${B_A3k1:-0}" n3 "n3 k1 accepted -- A3.k1 red, A3.hashrow green"
hmut n4 'mine[4:]' 'mine[len(mine):]' \
  && mrun n4 && mutant_killed "${B_A5:-0}" n4 "n4 prune keeps every record -- A5 red, A2.holds green"
hmut n5 'os.readlink(p)' 'b""' \
  && mrun n5 && mutant_killed "${B_A1link:-0}" n5 "n5 symlink targets ignored -- A1.link red, A1.dir green"
hmut n6 'pk_trace_init() { # the two controls, once per push; true when a traced run can be recorded' \
  'pk_trace_init() { # the two controls, once per push; true when a traced run can be recorded
  if false; then /usr/bin/log stream --style ndjson > /dev/null 2>&1; fi' \
  && mrun n6 && mutant_killed "${B_A6grep:-0}" n6 "n6 log stream in pk_trace_init -- A6.grep red, A6.run green"
hmut m_leak 'pk_trace_init() { # the two controls, once per push; true when a traced run can be recorded' \
  'pk_trace_init() { # the two controls, once per push; true when a traced run can be recorded
  /usr/bin/log stream --style ndjson > /dev/null 2>&1 & printf "%s\n" "$!" >> "$LEAKPIDS"' \
  && mrun m_leak && mutant_killed "${B_L1leak:-0}" m_leak "m_leak a real log stream started in pk_trace_init -- L1.leak red, W.skip green"
hmut n7 'return b.replace(b"\\", b"\\\\").replace(b"\t", b"\\t").replace(b"\n", b"\\n")' 'return b' \
  && mrun n7 && mutant_killed "${B_T1linknl:-0}" n7 "n7 esc() the identity -- T1.linknl red, A1.link green"
hmut m_stderr '  [ "$rc" = 0 ] || { [ -s "$PK_W/walk.err" ] || printf '"'"'find exited %s\n'"'"' "$rc" > "$PK_W/walk.err"; return 1; }
  [ -s "$PK_W/walk.err" ] && return 1
' '' \
  && mrun m_stderr && mutant_killed "${B_T1unsearch:-0}" m_stderr "m_stderr find's exit and stderr ignored -- T1.unsearch red, A1.create green"
hmut m_nl '-o -print0 > "$PK_W/walk"' '-o -print > "$PK_W/walk"' 'split(b"\0")' 'split(b"\n")' \
  && mrun m_nl && mutant_killed "${B_T1nlrename:-0}" m_nl "m_nl newline-separated walk -- T1.nlrename red, A1.create green"
hmut m_own '"$cmdsha" "$PK_PH" 2>&1)"; rc=$?' '"$cmdsha" "$(sed -n 5p "$rec" | cut -f2)" 2>&1)"; rc=$?' \
  && mrun m_own && mutant_killed "${B_Wcollide:-0}" m_own "m_own check against the record's own @present -- W.collide red, W.settings green"
hmut m_univ '/usr/bin/find . -path ./.git -prune -o -print0 > "$PK_W/walk"' 'sed "s|^|./|" "$PK_W/u/.is" | tr "\n" "\0" > "$PK_W/walk"' \
  && mrun m_univ && mutant_killed "${B_Wsettings:-0}" m_univ "m_univ present key from the universe listing -- W.settings red, W.skip green"
hmut m_mmark 'mkdir "$PK_W/t2.$slug" && pk_reset_all' 'mkdir "$PK_W/t2.$slug" && touch "$PK_W/mmark" && pk_reset_all' \
  '-newer "$PK_W/start"' '-newer "$PK_W/mmark"' \
  && mrun m_mmark && mutant_killed "$(( ${B_Wt2b:-0} && ${B_Wsamesec:-0} ))" m_mmark "m_mmark per-step mark -- W.t2b and W.samesec red, W.skip green"
hmut m_rewalk 'if [ "$PK_ON" = 1 ] && [ -s "$PK_W/wrote" ]; then' 'if false; then' \
  && mrun m_rewalk && mutant_killed "${B_Wforged:-0}" m_rewalk "m_rewalk pk_finish re-walk removed -- W.forged red, W.skip green"
hmut X1 'while IFS= read -r r; do rm -f -- "$r"; done < "$PK_W/wrote"' 'r="$(tail -1 "$PK_W/wrote")"; rm -f -- "$r"' \
  && mrun X1 && mutant_killed "${B_Wmulti:-0}" X1 "X1 pk_finish deletes only the last record -- W.multi red, W.forged green"
hmut X2 'ph2="$(pk_present)" || ph2=""' 'ph2="$(pk_present)" || ph2="$PK_PH"' \
  && mrun X2 && mutant_killed "${B_Wrewalkfail:-0}" X2 "X2 a failed re-walk read as no change -- W.rewalkfail red, W.forged green"
hmut X3 'return b.replace(b"\\", b"\\\\").replace(b"\t"' 'return b.replace(b"\t"' \
  && mrun X3 && mutant_killed "${B_T1escbs:-0}" X3 "X3 no backslash escape -- T1.esc.bs red, T1.esc.nl green"
hmut X7 '.replace(b"\t", b"\\t").replace(b"\n", b"\\n")' '.replace(b"\t", b"\\t")' \
  && mrun X7 && mutant_killed "${B_T1escnl:-0}" X7 "X7 no NL escape -- T1.esc.nl red, T1.esc.bs green"
hmut X8 '.replace(b"\t", b"\\t").replace(b"\n", b"\\n")' '.replace(b"\n", b"\\n")' \
  && mrun X8 && mutant_killed "${B_T1esctab:-0}" X8 "X8 no TAB escape -- T1.esc.tab red, T1.esc.bs green"

hmut m_bash 'pk_trace_init() { # the two controls, once per push; true when a traced run can be recorded' \
  'pk_trace_init() { # the two controls, once per push; true when a traced run can be recorded
  ( exec 3<> "$LEAKFIFO"; read -t 4711 -u 3 ) > /dev/null 2>&1 & printf "%s\n" "$!" >> "$LEAKPIDS"' \
  && mrun m_bash && mutant_killed "${B_L1leak:-0}" m_bash "m_bash a leaked child that never execs (a bash subshell) -- L1.leak red, W.skip green"
# The knock-out control: under the old name-filtered listing m_bash's child, which is named bash, must escape, so
# what kills m_bash is the cwd listing and not a name. Its child is reaped by recorded pid inside the cell.
if [ -d "$T/v.m_bash" ]; then
  if L1_NAME='log stream' cell "$T/v.m_bash" L1.leak; then ok "L1.name the name-filtered listing misses m_bash's bash-named leak (control: the cwd listing kills it)"
  else bad "L1.name the name-filtered listing caught m_bash's bash-named leak -- the control does not separate the two listings"; fi
  : > "$LEAKPIDS"
  # Its positive twin, one property apart: the same filtered branch, keyed on a name the never-exec child DOES carry
  # (a forked subshell keeps this script's argv), must list it, or the miss above may be a filter that lists nothing.
  if L1_NAME='presuite-present-key/run' cell "$T/v.m_bash" L1.leak; then bad "L1.name the name-filtered listing missed m_bash's leak under its own name -- the filtered branch lists nothing"
  else ok "L1.name the name-filtered listing lists m_bash's leak under the name it carries (presuite-present-key/run)"; fi
  : > "$LEAKPIDS"
fi

# The scoped listing must see a live process under $T (control), or L1.leak cannot fire. The sleep is a direct child
# forked while the main shell stands in $T, so it holds that cwd from fork, whatever its name, and `wait` reaps it.
L1PWD="$(pwd -P)" && cd "$T" || broken "cannot enter $T for L1.control"
sleep 4711 & SLP=$!
cd "$L1PWD" || broken "cannot return to $L1PWD after L1.control"
if scoped_pids | grep -qx "$SLP"; then ok "L1.control the scoped listing sees a live child forked under the scratch dir, by pid"; else bad "L1.control the scoped listing did not see a live child under the scratch dir -- L1.leak cannot fire"; fi
kill "$SLP" 2>/dev/null; wait "$SLP" 2>/dev/null
if scoped_pids | grep -qx "$SLP"; then bad "L1.control the reaped child is still listed"; fi

[ "$rc" -eq 0 ] && echo "PASS  presuite-present-key -- 30 arms, 20 mutants scored"
exit "$rc"
