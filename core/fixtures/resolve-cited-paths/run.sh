#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/fixtures/lib/preamble.sh"
# resolve-cited-paths -- core/scripts/resolve-cited-paths.sh resolves every path a subject's files cite against the
# repository's tracked file list, so a seat brief can carry the real path in place of a guessed one.
#
# Usage: run.sh        Exit: 0 = every assertion holds, 1 = a regression, 2 = fixture broken.
#
# ONE WORLD, ONE ANSWER. A scratch repository tracks src/app/{execution,config}.py, lib/config.py and
# tests/test_x.py, and ignores .claude/, which holds an on-disk file. Two subject files cite one of each class: a
# path found as cited (with a `:<line>` and a `::<test>` suffix, a tracked directory, an ignored file on disk), a
# bare name and a two-component tail each matching ONE tracked file (SUFFIX), a basename matching two (AMBIGUOUS),
# a path matching nothing (ABSENT), and spans that are not paths (a range, a `<rev>:<path>`, a glob, a placeholder,
# a URL, a dotted identifier, a flag). The expected output is a literal. The discriminating ABSENT and AMBIGUOUS
# rows are not first, and a repeated citation across the two files must print once.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
SUBJ=""
for c in "$HERE/../../scripts/resolve-cited-paths.sh" "$HERE/../../../scripts/ai-dlc/resolve-cited-paths.sh"; do
  [ -f "$c" ] && { SUBJ="$c"; break; }
done
[ -n "$SUBJ" ] || { echo "FIXTURE ERROR: cannot locate resolve-cited-paths.sh in either layout" >&2; exit 2; }
SUBJ="$(cd "$(dirname "$SUBJ")" && pwd)/$(basename "$SUBJ")"
echo "HERMETIC-CONSUMED $SUBJ"
command -v git >/dev/null 2>&1 || { echo "FIXTURE BROKEN: git not on PATH" >&2; exit 2; }

WORK="$(mktemp -d)" || { echo "FIXTURE BROKEN: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd)"
trap 'rm -rf "$WORK"' EXIT

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/fixtures/lib/report.sh"
. "$HERE/../lib/world.sh" || { echo "FIXTURE BROKEN: cannot source lib/world.sh" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/fixtures/lib/world.sh"
# A literal-tail path, never `. "$VAR"`: in a fixture opted in by an inproc: row, P1 reads an opaque source as a drive.
. "$HERE/../lib/mutant.sh" || { echo "FIXTURE BROKEN: cannot source lib/mutant.sh" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"

# A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECT only in the sense that both arrive on one pull: the subject is new with
# this fixture, so there is no pre-wrap shape to SKIP. Both halves of the wrap are required.
grep -qxF 'rcp_main() {' "$SUBJ"; g1=$?
grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$SUBJ"; g2=$?
[ "$g1" -le 1 ] && [ "$g2" -le 1 ] || { echo "FIXTURE BROKEN: cannot read $SUBJ" >&2; exit 2; }
if [ "$g1$g2" != 00 ]; then
  bad "$SUBJ lacks the in-process wrap (rcp_main line: rc $g1, column-0 source guard: rc $g2)"
  report_end resolve-cited-paths
fi
fx_inproc "$SUBJ"
. "$SUBJ" || { echo "FIXTURE BROKEN: sourcing $SUBJ failed" >&2; exit 2; }
declare -F rcp_main >/dev/null || { echo "FIXTURE BROKEN: sourcing $SUBJ defined no rcp_main" >&2; exit 2; }
# Every in-process call is one fx_inproc pass (the inproc: row counts them).
rcp_ip() {
  fx_inproc "$SUBJ"
  rcp_main "$@"
}

# --- the world ------------------------------------------------------------------------------------------------------
R="$WORK/repo"
world_repo "$R" >/dev/null || { echo "FIXTURE BROKEN: world_repo failed" >&2; exit 2; }
mkdir -p "$R/src/app" "$R/lib" "$R/tests" "$R/.claude/ext/checks" "$R/plan"
printf 'x\n' > "$R/src/app/execution.py"
printf 'x\n' > "$R/src/app/config.py"
printf 'x\n' > "$R/lib/config.py"
printf 'x\n' > "$R/tests/test_x.py"
printf '.claude/\nplan/\n' > "$R/.gitignore"
world_commit "$R" "seed" || { echo "FIXTURE BROKEN: world_commit failed" >&2; exit 2; }
printf 'x\n' > "$R/.claude/ext/checks/domain.md"
[ -d "$R/.git" ] || { echo "FIXTURE BROKEN: $R is not a repository" >&2; exit 2; }
[ "$(cd "$R" && world_git ls-files | grep -c .)" = 5 ] || { echo "FIXTURE BROKEN: the world does not track exactly 5 files" >&2; exit 2; }

cat > "$R/plan/a.md" <<'EOF'
# Subject one
Read `src/app/execution.py:12` and `execution.py`, then `sys.path.insert` and `main..HEAD`.
The base is `abc123:src/x.py`; never `src/*.py`, `<dir>/x.py`, `https://example.com/a/b` or `--out/x`.
See `rebalancer/db.py`, `config.py`, `app/execution.py` and `src/app/`.
EOF
cat > "$R/plan/b.md" <<'EOF'
# Subject two
Also `tests/test_x.py::test_a`, `.claude/ext/checks/domain.md`, `execution.py` again, and `lib/config.py`.
EOF

EXPECT='cited-paths: 2 subject file(s), 9 cited, 5 found, 2 resolved by suffix, 1 ambiguous, 1 absent
SUFFIX execution.py src/app/execution.py
ABSENT rebalancer/db.py
AMBIGUOUS config.py 2
SUFFIX app/execution.py src/app/execution.py'

# --- in process: one call per distinct state ------------------------------------------------------------------------
OUT="$(cd "$R" && rcp_ip plan/a.md plan/b.md 2>"$WORK/pass.err")"; RC=$?
if [ "$RC" -eq 0 ] && [ "$OUT" = "$EXPECT" ] && [ ! -s "$WORK/pass.err" ]; then
  ok "the world resolves to the literal: found rows omitted, SUFFIX, AMBIGUOUS and ABSENT in first-citation order"
else bad "the world's answer differs: rc=$RC out=[$OUT] err=[$(cat "$WORK/pass.err")]"; fi

OUT="$(cd "$R" && rcp_ip plan/a.md plan/missing.md 2>&1)"; RC=$?
case "$OUT" in *"cannot read subject file: plan/missing.md"*) m=1 ;; *) m=0 ;; esac
if [ "$RC" -eq 2 ] && [ "$m" = 1 ]; then ok "an unreadable subject file is refused with exit 2, naming it"
else bad "unreadable subject: rc=$RC out=[$OUT]"; fi

mkdir -p "$WORK/notrepo"; cp "$R/plan/a.md" "$WORK/notrepo/a.md"
OUT="$(cd "$WORK/notrepo" && GIT_CEILING_DIRECTORIES="$WORK" rcp_ip a.md 2>&1)"; RC=$?
case "$OUT" in *"not inside a git work tree"*) m=1 ;; *) m=0 ;; esac
if [ "$RC" -eq 2 ] && [ "$m" = 1 ]; then ok "outside a git work tree it refuses with exit 2 rather than call every path ABSENT"
else bad "outside a work tree: rc=$RC out=[$OUT]"; fi

# --- the cli cells (cells.decl): the subject run as a PROGRAM once per distinct CLI outcome --------------------------
EQ="$WORK/eq"; mkdir -p "$EQ"
eqv() { # <cell-id> <args...> -> $EQ/<id>.{ip,cl}.{out,err,rc}
  local id="$1"; shift
  ( cd "$R" && rcp_ip "$@" ) > "$EQ/$id.ip.out" 2> "$EQ/$id.ip.err"; echo "$?" > "$EQ/$id.ip.rc"
  ( cd "$R" && FXCELL="$id" bash "$SUBJ" "$@" ) > "$EQ/$id.cl.out" 2> "$EQ/$id.cl.err"; echo "$?" > "$EQ/$id.cl.rc"
  cmp -s "$EQ/$id.ip.out" "$EQ/$id.cl.out" && cmp -s "$EQ/$id.ip.err" "$EQ/$id.cl.err" && cmp -s "$EQ/$id.ip.rc" "$EQ/$id.cl.rc"
}
if eqv cli-pass plan/a.md plan/b.md && [ "$(cat "$EQ/cli-pass.cl.rc")" = 0 ] \
   && [ "$(cat "$EQ/cli-pass.cl.out")" = "$EXPECT" ]; then
  ok "cli-pass: the program prints the literal exactly as the in-process call does (stdout, stderr, exit 0)"
else bad "cli-pass: program rc=$(cat "$EQ/cli-pass.cl.rc") out=[$(cat "$EQ/cli-pass.cl.out")] in-process rc=$(cat "$EQ/cli-pass.ip.rc")"; fi
if eqv cli-usage && [ "$(cat "$EQ/cli-usage.cl.rc")" = 2 ] && [ ! -s "$EQ/cli-usage.cl.out" ] \
   && [ "$(cat "$EQ/cli-usage.cl.err")" = "usage: resolve-cited-paths.sh <subject-file> [<subject-file> ...]" ]; then
  ok "cli-usage: no argument is refused with the usage line and exit 2, as the in-process call does"
else bad "cli-usage: program rc=$(cat "$EQ/cli-usage.cl.rc") err=[$(cat "$EQ/cli-usage.cl.err")] in-process rc=$(cat "$EQ/cli-usage.ip.rc")"; fi

report_end resolve-cited-paths 5
