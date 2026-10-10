#!/usr/bin/env bash
# hermetic-run.sh — run one fixture inside a sandbox that holds ONLY its declared inputs.
#
# Usage: hermetic-run.sh [--root <project root>] [--fixture-dir <dir>] [--key-only] <fixture name>
# Exit:  0 = the fixture passed and every REQUIRED input was consumed
#        1 = the fixture failed, or a REQUIRED input was never named in its log
#        2 = the declaration cannot be honoured (a declared path or tool is absent, no declaration)
#
# THE DECLARATION. `<fixture dir>/inputs.decl` lists project-root-relative paths, one per line.
# A trailing `/` names a directory, copied whole. A leading `!` marks a REQUIRED input: after the
# run, the fixture's own output must carry the line `HERMETIC-CONSUMED <path>` for it (the path as
# declared, or prefixed by the sandbox root), or the run FAILS even though the fixture reported PASS.
# `#` lines and blank lines are ignored; a declaration with NO path is exit 2, because a fixture
# that declares nothing and passes has passed against an empty tree. `<fixture dir>/tools.decl`
# lists tool NAMES, one per line, resolved against git's exec-path and then the fixed tool dirs the
# pre-push hook keys tools in (`readset_tools` order); a name that resolves nowhere is exit 2, never a
# silent omission. A line `?name` names a tool that must be REACHABLE and is NOT keyed: `name` must be
# in the hook's READSET_UNKEYED_TOOLS (any other `?` line is exit 2), it is resolved with `command -v`
# on the INVOKER's PATH, and so which copy runs depends on the invoker while the key does not.
#
# DISTRIBUTION COORDINATES. `inputs.decl` paths are spelled as in the distribution (`core/scripts/x.sh`).
# Layout: DISTRIBUTION iff `<root>/core/scripts` is a directory, else CONSUMER. In a consumer every
# declared path under `core/` is mapped by `core-paths.sh --map` (beside this script) BEFORE anything
# else reads it; the hook runs the same rule. Errors name both spellings. A mapped path absent on a
# consumer is `declared file absent`, exit 2, which is intended.
#
# WHY REQUIRED EXISTS, AND WHY IT IS A SENTINEL. A fixture that tolerates either of two layouts
# PASSES with one of them dropped: measured, 48 assertions down to 32, verdict PASS, when one hook
# was removed from its declaration. The sandbox cannot see that -- the fixture's own verdict is
# PASS -- so the declaration says which inputs the verdict must have consumed, and this runner
# checks it. A SUBSTRING match on the log was the first spelling and it was vacuous: a one-letter
# directory name is in every log, `a.sh` is inside `a.sh.bak`, and a fixture that prints
# `skipping core/git-hooks/pre-push: not found` and PASSES names the very path it did not consume.
# The sentinel line is printed by the fixture at the point it USES the input, so the only way to
# satisfy it is to reach that point.
#
# THE KEY. `--key-only` prints the hermetic key rows for this fixture, in the SAME grammar the
# pre-push hook writes to `$GITDIR/ai-dlc-fixture-keys/<fixture>.key`: `<path>\t<sha256>` for a
# declared file, `<dir>/\t#listing:<sha256>` for a declared directory's entry list (so a file added
# to a copied directory reruns the fixture, because it would be copied in), every file under the
# fixture's own directory, and `<tool path>\t<sha256>` for each declared tool. The POPULATION is
# the hook's own: this script sources the READSET_UNIVERSE span out of the pre-push hook beside it
# (the same span derive-fixture-readsets.sh sources) and takes its paths from readset_manifest, so
# the content key's excluded tops, git-ignored paths and deleted-but-tracked names are treated
# exactly as the hook treats them. The rows are composed by ONE implementation: the hook's
# READSET_KEYROWS span (readset_decl_parse, readset_decl_keys), sourced here and called by the hook
# over its whole declared set, so there is no second composer to drift. A declared path absent from
# the manifest (an excluded top, a git-ignored file) has no row on either side. A hook with no
# KEYROWS span (version skew mid-pull) is `--key-only` exit 2; a sandbox run still runs the fixture,
# with the verdict store OFF. A run with no hook to source is exit 2, key-only or not: the tool
# dirs and the unkeyed-tool vocabulary come from the hook's READSET_TOOLS span, so there is no copy of
# them here to drift.
#
# THE SANDBOX. A fresh `mktemp -d`, `env -i`, PATH pinned to the fixed tool dirs plus a symlink farm
# of the declared tools (keyed and unkeyed), `AI_DLC_PROJECT_ROOT` set to the sandbox root, and the fixture invoked as
# `bash core/fixtures/<f>/run.sh` from the sandbox ROOT -- the pre-push pool's own invocation, never
# a `cd` into the fixture directory (CLAUDE.md measures that as five fabricated failures).
# The sandbox is removed on exit unless `AI_DLC_HERMETIC_KEEP=1`. A declared DIRECTORY is copied by
# its git population (tracked plus untracked-unignored, the key's own), never whole; the fixture's OWN
# directory is the one stated exception, copied whole with links refused, and the reason is at the copy.
#
# A SEEDED REPOSITORY. `<fixture dir>/git.decl` (optional) makes the sandbox root a git repository:
# `seed` commits the copied tree, `pin <sha>` imports one commit and its tree from the project's own
# object store (exit 2 when absent), `pin? <sha>` imports it when present and otherwise leaves the
# fixture's own absent-pin branch to decide. The grammar and the reason it is a pack are at the build.
#
# A FIXTURE WITHOUT A DECLARATION IS NOT THIS RUNNER'S: exit 2. The hook dispatches to this runner
# only when `inputs.decl` exists, so a missing declaration here is a caller defect, not a skip.
set -u

# HR_SANDBOX_BEGIN
# EVERYTHING BETWEEN THESE MARKERS DECIDES WHAT A FIXTURE RUNS WITH (arguments, declaration, population, key rows, copy, env -i
# invocation, sentinels) and is what the verdict store digests as `#runner`. Store read/write, logging and the summary line
# are OUTSIDE it, so an edit to those does not invalidate a recorded pass.
HR_ROOT_OPT=""
HR_FXDIR=""
HR_KEY_ONLY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --root) HR_ROOT_OPT="$2"; shift 2 ;;
    --fixture-dir) HR_FXDIR="$2"; shift 2 ;;
    --key-only) HR_KEY_ONLY=1; shift ;;
    --) shift; break ;;
    -*) printf 'hermetic-run: unknown option %s\n' "$1" >&2; exit 2 ;;
    *) break ;;
  esac
done

# `--root` is the override's command-line spelling; it feeds the same variable the chain reads.
[ -n "$HR_ROOT_OPT" ] && AI_DLC_PROJECT_ROOT="$HR_ROOT_OPT"
# --- AI_DLC_ROOT ---------------------------------------------------------------
# The project root. The chain below is the canonical one I75 binds across every root-consulting script
# (override -> walk up from this script -> CLAUDE_PROJECT_DIR -> walk up from cwd -> exit 2), and
# it is inline because locating a shared lib is the same unsolved problem. Never a hop count: the
# script lives at core/scripts/ here and scripts/ai-dlc/ installed.
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
HR_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HR_ROOT="${AI_DLC_PROJECT_ROOT:-}"
[ -n "$HR_ROOT" ] || HR_ROOT="$(ai_dlc_resolve_root "$HR_SCRIPT_DIR" || true)"
[ -n "$HR_ROOT" ] || HR_ROOT="${CLAUDE_PROJECT_DIR:-}"
[ -n "$HR_ROOT" ] || HR_ROOT="$(ai_dlc_resolve_root "$(pwd)" || true)"
[ -n "$HR_ROOT" ] || {
  echo "ERROR: hermetic-run: cannot resolve the project root from ${HR_SCRIPT_DIR} (no .git or" >&2
  echo "  .claude/ marker in any parent). Pass --root or set AI_DLC_PROJECT_ROOT." >&2
  exit 2
}
# --- end AI_DLC_ROOT -----------------------------------------------------------
HR_ROOT="$(cd "$HR_ROOT" && pwd -P)" || exit 2
# The usage refusal names the resolved root, so a run with no fixture argument still answers
# differently under a wrong root -- core/fixtures/validator-path-resolution drives every
# root-consulting script with no fixture-specific argv and requires that sensitivity.
[ $# -eq 1 ] || { printf 'hermetic-run: usage: hermetic-run.sh [--root R] [--fixture-dir D] [--key-only] <fixture>  (project root: %s)\n' "$HR_ROOT" >&2; exit 2; }
HR_FX="$1"
case "$HR_FX" in ''|*/*|.*) printf 'hermetic-run: fixture name must be a bare directory name, got %s\n' "$HR_FX" >&2; exit 2 ;; esac

# The fixture root is whichever layout the project carries: core/fixtures/ in the distribution,
# tests/fixtures/ on a consumer. The sandbox reproduces the SAME relative path, so a fixture's own
# `$0` walk lands on the sandbox root in either layout.
HR_FXROOT=""
for c in core/fixtures tests/fixtures; do
  [ -d "$HR_ROOT/$c" ] && { HR_FXROOT="$c"; break; }
done
[ -n "$HR_FXROOT" ] || { printf 'hermetic-run: neither core/fixtures/ nor tests/fixtures/ under %s\n' "$HR_ROOT" >&2; exit 2; }
[ -n "$HR_FXDIR" ] || HR_FXDIR="$HR_ROOT/$HR_FXROOT/$HR_FX"
[ -f "$HR_FXDIR/run.sh" ] || { printf 'hermetic-run: no run.sh in %s\n' "$HR_FXDIR" >&2; exit 2; }
[ -f "$HR_FXDIR/inputs.decl" ] || { printf 'hermetic-run: %s carries no inputs.decl -- this runner is for declared fixtures only\n' "$HR_FX" >&2; exit 2; }

# THE HOOK, AND ITS TOOLS SPAN. The fixed tool dirs, git's exec-path derivation and the unkeyed-tool
# vocabulary are owned by the pre-push hook's READSET_TOOLS span and sourced from it here, the way the
# universe span is, so there is one list. A run with no hook is exit 2: a tool outside the span has no
# stable key, and without it this runner would be guessing which directories count.
HR_WORK="$(mktemp -d "${TMPDIR:-/tmp}/hermetic-run.XXXXXX")" || exit 2
# PHYSICAL, SQUEEZED. macOS hands out TMPDIR with a TRAILING SLASH, so the mktemp above spells
# `.../T//hermetic-run.X`, and lines below export HOME and TMPDIR under it INTO the sandbox: the
# sandboxed fixture then sees an EMBEDDED `//` in every scratch path it mints, where a plain run sees
# none. Measured: a fixture comparing an absolute scratch citation against a pwd-derived path killed
# four predicates in the sandbox and one in the plain run. `pwd -P` collapses the `//` and the /var
# symlink in one step, the way HR_SB is already taken.
HR_WORK="$(cd "$HR_WORK" && pwd -P)" || exit 2
trap '[ "${AI_DLC_HERMETIC_KEEP:-0}" = 1 ] || rm -rf "$HR_WORK"' EXIT
HR_HOOK=""
for c in .githooks/pre-push core/git-hooks/pre-push; do [ -f "$HR_ROOT/$c" ] && { HR_HOOK="$HR_ROOT/$c"; break; }; done
[ -n "$HR_HOOK" ] || { printf 'hermetic-run: needs a pre-push hook under %s to take the tool dirs and the universe from\n' "$HR_ROOT" >&2; exit 2; }
sed -n '/^# READSET_TOOLS_BEGIN$/,/^# READSET_TOOLS_END$/p' "$HR_HOOK" > "$HR_WORK/tools.sh"
grep -q '^READSET_TOOL_DIRS=' "$HR_WORK/tools.sh" && grep -q '^READSET_UNKEYED_TOOLS=' "$HR_WORK/tools.sh" && grep -q '^readset_git_exec_path() ' "$HR_WORK/tools.sh" \
  || { printf 'hermetic-run: %s carries no READSET_TOOLS span with READSET_TOOL_DIRS, READSET_UNKEYED_TOOLS and readset_git_exec_path\n' "$HR_HOOK" >&2; exit 2; }
. "$HR_WORK/tools.sh" || exit 2
HR_TOOL_DIRS="$READSET_TOOL_DIRS"
# A bare name resolves against git's REAL exec-path first and then the fixed dirs, exactly as
# readset_tools does. The sandbox's own `git` is still the first one on its PATH (the system shim),
# which forwards to the binary keyed here; the key names the binary that runs behind it.
HR_XP="$READSET_TOOL_XP"
[ -n "$HR_XP" ] || HR_XP="$(readset_git_exec_path)"
HR_XPD="$HR_XP:$HR_TOOL_DIRS"

# LAYOUT: one rule, shared with the hook. DISTRIBUTION iff <root>/core/scripts is a directory.
HR_LAYOUT=consumer
[ -d "$HR_ROOT/core/scripts" ] && HR_LAYOUT=distribution

# THE DECLARATION AND THE KEY ROWS ARE THE HOOK'S READSET_KEYROWS SPAN, sourced here at top level (the READSET_TOOLS
# pattern): readset_decl_parse normalises and refuses the declaration and resolves tools.decl, readset_decl_keys
# composes the key rows. The hook runs the same two functions over its whole declared set, so the two cannot key
# one fixture two ways. VERSION SKEW (a consumer mid-pull running this runner against an OLDER hook that carries no
# span) is not a refusal for a SANDBOX run: the fixture still runs, through hr_parse_skew below, and the verdict
# store is OFF for it, because there is no composer to key the entry with. `--key-only` has nothing to print
# without the span and exits 2.
HR_KR=0
sed -n '/^# READSET_KEYROWS_BEGIN$/,/^# READSET_KEYROWS_END$/p' "$HR_HOOK" > "$HR_WORK/keyrows.sh"
if grep -q '^readset_decl_parse() ' "$HR_WORK/keyrows.sh" && grep -q '^readset_decl_keys() ' "$HR_WORK/keyrows.sh" && grep -q '^readset_decl_tool_hashes() ' "$HR_WORK/keyrows.sh"; then
  . "$HR_WORK/keyrows.sh" || exit 2
  HR_KR=1
fi
if [ "$HR_KR" = 0 ]; then
  [ "$HR_KEY_ONLY" = 1 ] && { printf 'hermetic-run: %s carries no READSET_KEYROWS span with readset_decl_parse, readset_decl_tool_hashes and readset_decl_keys, so there are no key rows to print\n' "$HR_HOOK" >&2; exit 2; }
  printf 'hermetic-run: %s: verdict store OFF: %s carries no READSET_KEYROWS span (an older hook), so this run is not recorded\n' "$HR_FX" "$HR_HOOK"
fi
# THE SKEW PARSE: reachable ONLY when the hook carries no READSET_KEYROWS span, and never on a key-only run, so it
# writes no key row and no store entry. It emits the span's parse-row grammar with the span's normalisation, so the
# sandbox below reads one shape either way.
hr_parse_skew() { # <fx> <fixture dir> <dist|cons> <mapper> <tool search path> <scratch prefix>
  local fx="$1" fd="$2" w="$6" t p
  printf '%s\tN\n' "$fx"
  awk -v fx="$fx" '{ sub(/\r$/, ""); if ($0 == "" || $0 ~ /^#/) next
      r = 0; if (substr($0, 1, 1) == "!") { r = 1; $0 = substr($0, 2) }
      if ($0 ~ /^\// || $0 ~ /(^|\/)\.\.(\/|$)/) { print fx "\tX\tabs\t" $0; next }
      k = "F"; if ($0 ~ /\/$/) { k = "D"; sub(/\/+$/, "") }
      if ($0 != "") print fx "\t" k "\t" $0 "\t" r }' "$fd/inputs.decl" > "$w.n"
  if [ "$3" = cons ] && awk -F'\t' '$2 != "X" && ($3 == "core" || index($3, "core/") == 1) { f = 1 } END { exit f ? 0 : 1 }' "$w.n"; then
    [ -f "$4" ] || { printf '%s\tX\tnomap\t%s\n' "$fx" "$4"; return 0; }
    awk -F'\t' '$2 != "X" { print $3 (($2 == "D") ? "/" : "") }' "$w.n" | bash "$4" --map > "$w.m" 2> "$w.e" \
      || { printf '%s\tX\tmaprefuse\t%s\n' "$fx" "$(sed -n 1p "$w.e" | tr '\t' ' ')"; return 0; }
    awk -F'\t' 'NR == FNR { m[FNR] = $0; next } $2 == "X" { print; next } { n++; p = m[n]; sub(/\/+$/, "", p); print $1 "\t" $2 "\t" p "\t" $4 "\t" $3 }' "$w.m" "$w.n"
  else
    awk -F'\t' '$2 == "X" { print; next } { print $1 "\t" $2 "\t" $3 "\t" $4 "\t" $3 }' "$w.n"
  fi
  [ -f "$fd/tools.decl" ] || return 0
  while IFS= read -r t || [ -n "$t" ]; do
    case "$t" in ''|'#'*) continue ;; '?'*) printf '%s\tU\t%s\n' "$fx" "${t#?}"; continue ;; */*) printf '%s\tX\ttpath\t%s\n' "$fx" "$t"; continue ;; esac
    p="$( IFS=:; for d in $5; do [ -x "$d/$t" ] && { printf '%s' "$d/$t"; break; }; done )"
    if [ -n "$p" ]; then printf '%s\tT\t%s\n' "$fx" "$p"; else printf '%s\tX\ttnone\t%s\n' "$fx" "$t"; fi
  done < "$fd/tools.decl"
}

# Parse the declaration into $HR_WORK/parse (the span's rows), then word each refusal row the runner's way and
# fill the files, dirs, required, tools and unkeyed lists the sandbox reads. Absent-on-disk is the span's test
# (`-f` / `-d` under the root), so the parse runs FROM the root.
: > "$HR_WORK/files"; : > "$HR_WORK/dirs"; : > "$HR_WORK/required"; : > "$HR_WORK/tools"; : > "$HR_WORK/unkeyed"
hr_lay=cons; [ "$HR_LAYOUT" = distribution ] && hr_lay=dist
( cd "$HR_ROOT" || exit 2
  if [ "$HR_KR" = 1 ]; then readset_decl_parse "$HR_FX" "$HR_FXDIR" "$hr_lay" "$HR_SCRIPT_DIR/core-paths.sh" "$HR_XPD" "$HR_WORK/dp"
  else hr_parse_skew "$HR_FX" "$HR_FXDIR" "$hr_lay" "$HR_SCRIPT_DIR/core-paths.sh" "$HR_XPD" "$HR_WORK/dp"; fi ) > "$HR_WORK/parse" || exit 2
hr_bad=0
hr_tab="$(printf '\t')"
while IFS="$hr_tab" read -r f k a b c; do
  # lbl is the path as an error names it: the mapped spelling, and the declared one when they differ.
  lbl="$a"; [ -z "$b" ] || [ "$a" = "$b" ] || lbl="$a (declared as $b)"
  case "$k" in
    F) printf '%s\n' "$a" >> "$HR_WORK/files"; [ "$b" = 1 ] && printf '%s\t%s\n' "$a" "$c" >> "$HR_WORK/required" ;;
    D) printf '%s\n' "$a" >> "$HR_WORK/dirs"; [ "$b" = 1 ] && printf '%s/\t%s/\n' "$a" "$c" >> "$HR_WORK/required" ;;
    T) printf '%s\n' "$a" >> "$HR_WORK/tools" ;;
    U) printf '%s\n' "$a" >> "$HR_WORK/unkeyed" ;;
    X) hr_bad=1
       case "$a" in
         abs) printf 'hermetic-run: %s: declaration path must be root-relative with no .. : %s\n' "$HR_FX" "$b" >&2 ;;
         nomap) printf 'hermetic-run: %s: mapper absent -- %s/core-paths.sh is needed to map a core/ declaration onto a consumer layout\n' "$HR_FX" "$HR_SCRIPT_DIR" >&2 ;;
         maprefuse) printf 'hermetic-run: %s: a declared core/ path has no consumer location: %s\n' "$HR_FX" "$b" >&2 ;;
         mapcount) printf 'hermetic-run: %s: the mapper returned a different number of paths than were declared\n' "$HR_FX" >&2 ;;
         absd) lbl="$b/"; [ "$b" = "$c" ] || lbl="$b/ (declared as $c/)"; printf 'hermetic-run: %s: declared directory absent: %s\n' "$HR_FX" "$lbl" >&2 ;;
         absf) lbl="$b"; [ "$b" = "$c" ] || lbl="$b (declared as $c)"; printf 'hermetic-run: %s: declared file absent: %s\n' "$HR_FX" "$lbl" >&2 ;;
         qbad) printf 'hermetic-run: %s: tools.decl line is not an unkeyed tool name: %s\n' "$HR_FX" "$b" >&2 ;;
         qout) printf 'hermetic-run: %s: tools.decl line %s names a tool outside READSET_UNKEYED_TOOLS (%s)\n' "$HR_FX" "$b" "$READSET_UNKEYED_TOOLS" >&2 ;;
         tpath) printf 'hermetic-run: %s: tools.decl names a path, wants a bare name: %s\n' "$HR_FX" "$b" >&2 ;;
         tnone) printf 'hermetic-run: %s: declared tool %s resolves in none of %s\n' "$HR_FX" "$b" "$HR_XPD" >&2 ;;
         dup) printf 'hermetic-run: %s: two declared tools share the basename %s -- the sandbox farm holds one\n' "$HR_FX" "$b" >&2 ;;
         *) printf 'hermetic-run: %s: the declaration was refused (%s %s)\n' "$HR_FX" "$a" "$b" >&2 ;;
       esac ;;
  esac
done < "$HR_WORK/parse"
if [ ! -s "$HR_WORK/files" ] && [ ! -s "$HR_WORK/dirs" ]; then
  printf 'hermetic-run: %s: inputs.decl is empty -- refusing to run the fixture against an empty tree\n' "$HR_FX" >&2
  hr_bad=1
fi
[ "$hr_bad" = 0 ] || exit 2

# A GIT WORK TREE IS REQUIRED, key-only or not. The copy population and the key population are both
# git's view of the tree (below), so a root git cannot list has neither: a key-only run there hashed
# nothing, and a sandbox run fell back to copying whatever was on disk. The root must BE the work
# tree's top, not merely sit inside one, or an enclosing repository would answer for a tree it does
# not describe. Every caller (both pre-push hooks, the hermetic-runner probes, readset-skip's I66 arm)
# runs on a git tree.
hr_top="$(cd "$HR_ROOT" && git rev-parse --show-toplevel 2>/dev/null)" || hr_top=""
[ -n "$hr_top" ] && hr_top="$(cd "$hr_top" && pwd -P)"
[ "$hr_top" = "$HR_ROOT" ] || { printf 'hermetic-run: %s: hermetic-run needs a git work tree to derive the copy population, and %s is not the top of one\n' "$HR_FX" "$HR_ROOT" >&2; exit 2; }

# THE POPULATION, ONE FUNCTION FOR THE KEY AND THE SANDBOX, built from the hook's own READSET_UNIVERSE
# span. It writes $HR_WORK/p/.paths: tracked plus untracked-unignored, minus git-ignored, minus the
# content key's excluded tops -- the readset_manifest `.paths` stage, BEFORE that function's `[ -f ]`
# filter, so a tracked link to a directory, a dangling link and a gitlink are still in it. The SANDBOX
# copies from this list and refuses from it.
# `key` mode additionally runs readset_manifest itself into $HR_WORK/m, whose `.now` (the `-f` entries
# hashed; `-f` follows a link) is the only thing the KEY reads, and requires its `.paths` to equal ours
# byte for byte. The sandbox does not hash: hashing the whole tree on every sandboxed run is the cost
# the key-only path alone pays. The equality check is what makes the two compositions one population.
# Exit 2 when the span cannot be read or the two `.paths` disagree.
hr_population() { # <copy|key>
  local span="$HR_WORK/universe.sh"
  sed -n '/^# READSET_UNIVERSE_BEGIN$/,/^# READSET_UNIVERSE_END$/p' "$HR_HOOK" > "$span"
  grep -q '^readset_manifest() ' "$span" || { printf 'hermetic-run: %s carries no READSET_UNIVERSE span with readset_manifest\n' "$HR_HOOK" >&2; return 2; }
  (
    cd "$HR_ROOT" || exit 2
    READSET_MAP=/dev/null READSET_LOCAL=/dev/null
    . "$span" || exit 2
    o="$HR_WORK/p"; mkdir -p "$o" || exit 2
    { git -c core.quotePath=false ls-files 2>/dev/null
      git -c core.quotePath=false ls-files --others --exclude-standard 2>/dev/null
      readset_rows "$o" paths
    } | readset_universe_paths | sort -u > "$o/.paths.all"
    readset_drop_ignored "$o/.paths.all" "$o/.paths" || { printf 'hermetic-run: git check-ignore failed under %s, so the copy population is unknown\n' "$HR_ROOT" >&2; exit 2; }
    [ "$1" = key ] || exit 0
    mkdir -p "$HR_WORK/m" && readset_manifest "$HR_WORK/m"
    cut -f1 "$HR_WORK/m/.now" > "$HR_WORK/m/.is" && readset_listings "$HR_WORK/m/.is" "$HR_WORK/m/.ls.now" || exit 2
    cmp -s "$o/.paths" "$HR_WORK/m/.paths" || { printf 'hermetic-run: the copy population and readset_manifest disagree under %s -- the key and the sandbox would describe different trees\n' "$HR_ROOT" >&2; exit 2; }
  )
}
if [ "$HR_KEY_ONLY" = 1 ]; then hr_population key || exit 2; else hr_population copy || exit 2; fi
[ -s "$HR_WORK/p/.paths" ] || { printf 'hermetic-run: %s: git lists nothing under %s, so there is no copy population\n' "$HR_FX" "$HR_ROOT" >&2; exit 2; }

# THE KEY ROWS are the span's readset_decl_keys over this run's own `.now` and the listings `hr_population key`
# derived from it, fed the parse rows above: the hook calls the same function over its whole declared set, so the
# rows cannot differ by implementation. Tool hashes are taken by the span's readset_decl_tool_hashes.
# THE ROWS GO TO A FILE AND THE SUBSHELL'S EXIT IS RETURNED. Piped straight into `sort -u` (no pipefail), its
# `exit 2` on an unhashable tree was discarded and `--key-only` printed nothing at exit 0.
hr_rows() {
  local hr_kr
  [ "$HR_KR" = 1 ] || return 2
  (
    [ -s "$HR_WORK/m/.now" ] || { printf 'hermetic-run: could not hash the working tree under %s\n' "$HR_ROOT" >&2; exit 2; }
    : > "$HR_WORK/th"
    readset_decl_tool_hashes "$HR_WORK/parse" "$HR_WORK/th"
    readset_decl_keys "$HR_WORK/m/.now" "$HR_WORK/m/.ls.now" "$HR_WORK/parse" "$HR_WORK/th" "$HR_FXROOT/" | cut -f2-
  ) > "$HR_WORK/krows"; hr_kr=$?
  [ "$hr_kr" = 0 ] || return "$hr_kr"
  LC_ALL=C sort -u "$HR_WORK/krows"
}
if [ "$HR_KEY_ONLY" = 1 ]; then hr_rows; exit $?; fi

# THE SANDBOX: copy declared files and directories at their own relative paths, the fixture's own
# directory (or the override), and nothing else.
# `pwd -P`, because macOS hands out TMPDIR under /var which is a symlink to /private/var, and a
# fixture comparing AI_DLC_PROJECT_ROOT against its own `pwd` must see one spelling.
mkdir -p "$HR_WORK/sb" "$HR_WORK/home" "$HR_WORK/tmp" || exit 2
HR_SB="$(cd "$HR_WORK/sb" && pwd -P)" || exit 2
# A DECLARED DIRECTORY IS COPIED BY ITS POPULATION, NEVER BY `cp -Rp`. The key covers only what git
# can see (tracked plus untracked-unignored, $HR_WORK/p/.paths); a whole-directory copy also carried
# every IGNORED file, none of them keyed. Measured on the reference consumer: `.claude/skills` held 221
# tracked and 1091 ignored files, all copied, and one ignored link (`swap-integration`, listed in its
# .gitignore) refused every fixture declaring `core/skills/`. Now the sandbox holds exactly the files
# the key names, by construction, and an ignored path is neither copied nor refused.
# A SYMLINK IN THE POPULATION IS A READ OUTSIDE THE DECLARATION: exit 2 naming it. Refused, not
# dereferenced -- a dereferenced copy would key the fixture on the link and not on its target. The
# test is `-L` over the PRE-`-f` list, so a link to a directory and a dangling link (no `.now` row,
# since `-f` follows links) are refused as well as a link to a file. A GITLINK (mode 160000) under a
# declared directory is refused too: its contents belong to another repository's key.
# Every declared directory exists in the sandbox even when its population is empty, and every copy is
# `cp -p` per parent directory, so modes (an executable non-.sh file) survive. A declared directory
# under another declared directory is simply re-listed; the copy refuses nothing that exists.
# DECLARED FILES keep the direct `cp -p` below and are NOT gated by the population: a dist sandbox
# declares VERSION and docs/backlog*.md, which sit under EXCLUDED tops and so are in no population.
: > "$HR_WORK/copy"
if [ -s "$HR_WORK/dirs" ]; then
  ( cd "$HR_ROOT" && git -c core.quotePath=false ls-files -s 2>/dev/null ) \
    | awk '$1 == "160000" { sub(/^[^\t]*\t/, ""); print }' > "$HR_WORK/gitlinks"
  # Every population entry under a declared directory, one awk over the list. A name git QUOTES is
  # listed with a leading `"`, so its prefix is matched after that quote too, or it would never reach
  # the refusal below.
  awk -F'\t' -v dl="$HR_WORK/dirs" 'BEGIN { while ((getline l < dl) > 0) if (l != "") d[++n] = l "/" }
    { for (i = 1; i <= n; i++) if (index($1, d[i]) == 1 || index($1, "\"" d[i]) == 1) { print $1; next } }' "$HR_WORK/p/.paths" > "$HR_WORK/under"
  awk -v dl="$HR_WORK/dirs" 'BEGIN { while ((getline l < dl) > 0) if (l != "") d[++n] = l "/" }
    { for (i = 1; i <= n; i++) if (index($0, d[i]) == 1) { print; next } }' "$HR_WORK/gitlinks" > "$HR_WORK/under.gl"
  if [ -s "$HR_WORK/under.gl" ]; then
    printf 'hermetic-run: %s: %s is a gitlink (submodule) under a declared directory -- its contents are another repository'"'"'s, so it cannot be copied into the sandbox\n' "$HR_FX" "$(head -1 "$HR_WORK/under.gl")" >&2; exit 2
  fi
  # A NAME GIT STILL QUOTES (tab, newline, `"`, `\`) cannot be tested or copied by its listed
  # spelling, so it would be dropped silently; refused here on its own terms rather than by relying
  # on readset_manifest's quoted-path guard, which governs only the key.
  if grep -q '^"' "$HR_WORK/under"; then
    printf 'hermetic-run: %s: %s is a name git quotes, so it cannot be copied into the sandbox by its listed spelling\n' "$HR_FX" "$(grep '^"' "$HR_WORK/under" | head -1)" >&2; exit 2
  fi
  while IFS= read -r e; do
    if [ -L "$HR_ROOT/$e" ]; then
      printf 'hermetic-run: %s: %s is a symlink -- a link reaches outside the declaration, so it cannot be copied into the sandbox\n' "$HR_FX" "$e" >&2; exit 2
    fi
    [ -f "$HR_ROOT/$e" ] && printf '%s\n' "$e" >> "$HR_WORK/copy"
  done < "$HR_WORK/under"
fi
while IFS= read -r d; do
  [ -n "$d" ] || continue
  mkdir -p "$HR_SB/$d" || exit 2
done < "$HR_WORK/dirs"
# One `cp -p` per destination parent directory, not one per file.
if [ -s "$HR_WORK/copy" ]; then
  LC_ALL=C sort -u "$HR_WORK/copy" | awk '{ p = $0; i = match(p, /\/[^\/]*$/); print (i > 0 ? substr(p, 1, i - 1) : ".") "\t" p }' > "$HR_WORK/copy.bp"
  hr_par=""; set --
  while IFS="$(printf '\t')" read -r par f; do
    if [ "$par" != "$hr_par" ]; then
      [ $# -eq 0 ] || cp -p "$@" "$HR_SB/$hr_par/" || exit 2
      set --; hr_par="$par"; mkdir -p "$HR_SB/$par" || exit 2
    fi
    set -- "$@" "$HR_ROOT/$f"
  done < "$HR_WORK/copy.bp"
  [ $# -eq 0 ] || cp -p "$@" "$HR_SB/$hr_par/" || exit 2
fi
hr_no_symlinks() { # <root-relative path, file or dir>: exit 2 naming the first symlink under it
  local l
  l="$(cd "$HR_ROOT" && /usr/bin/find "$1" -type l -print 2>/dev/null | head -1)"
  [ -z "$l" ] || { printf 'hermetic-run: %s: %s is a symlink -- a link reaches outside the declaration, so it cannot be copied into the sandbox\n' "$HR_FX" "$l" >&2; exit 2; }
}
while IFS= read -r p; do
  [ -n "$p" ] || continue
  hr_no_symlinks "$p"
  [ -f "$HR_SB/$p" ] && continue
  mkdir -p "$HR_SB/$(dirname "$p")" && cp -p "$HR_ROOT/$p" "$HR_SB/$p" || exit 2
done < "$HR_WORK/files"
# THE FIXTURE'S OWN DIRECTORY IS THE STATED EXCEPTION: copied whole with `cp -Rp`, links refused by
# `hr_no_symlinks` over the disk. Two reasons. `--fixture-dir` names a directory OUTSIDE the work tree
# (the self-update path runs a fixture from a scratch copy), which git cannot list; and the key already
# covers this directory as git sees it, so an ignored file here is a file the fixture's own author put
# beside its run.sh. The population rule binds the DECLARED inputs, which is where a consumer's ignored
# tree lives.
mkdir -p "$HR_SB/$HR_FXROOT" || exit 2
hr_no_symlinks "$HR_FXROOT/$HR_FX"
[ "$HR_FXDIR" = "$HR_ROOT/$HR_FXROOT/$HR_FX" ] || hr_no_symlinks "$HR_FXDIR"
cp -Rp "$HR_FXDIR" "$HR_SB/$HR_FXROOT/$HR_FX" || exit 2
# A SEEDED REPOSITORY, WHEN THE FIXTURE DECLARES ONE IN `<fixture dir>/git.decl`. `seed` makes the
# sandbox root a git work tree holding one commit of everything copied in. `pin <40-hex sha>` imports
# that commit and its tree -- never its parents, so `log` past it fails loudly -- from the project's
# own object store; a pin the project lacks is exit 2. `pin? <sha>` is the same, except that a pin the
# project lacks (a consumer, a shallow clone) is not imported and the fixture's own absent-pin branch
# decides, so a shipping fixture can declare one. Any other line is exit 2.
# THE OBJECTS TRAVEL AS A PACK BUILT AT RUN TIME INTO THE SANDBOX'S OWN .git. Nothing is written under
# core/: pinned blobs committed under core/fixtures/ were a second corpus to arms I104, I113 and I65,
# which scan core/ by content, and that is what kept the procsub fixtures undeclared. No alternates
# file points at the project's store either -- that would be a read outside the declaration.
# NO KEY ROWS: a sha names immutable content, and git.decl is keyed as a file of the fixture's own dir.
# Every sandbox-side git call drops the GIT_* variables a hook exports, `--template=` keeps the
# invoker's init templates out, and the seed commit runs no hook and signs nothing.
if [ -f "$HR_FXDIR/git.decl" ]; then
  hr_seed=0; hr_pin_skipped=0; : > "$HR_WORK/pins"
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ''|'#'*) continue ;; esac
    case "$line" in
      seed) hr_seed=1 ;;
      'pin '*|'pin? '*)
        hr_ps="${line#* }"
        case "$hr_ps" in *[!0-9a-f]*|'') printf 'hermetic-run: %s: git.decl pin is not a lowercase hex sha: %s\n' "$HR_FX" "$line" >&2; exit 2 ;; esac
        [ "${#hr_ps}" -eq 40 ] || { printf 'hermetic-run: %s: git.decl pin must be a full 40-hex sha: %s\n' "$HR_FX" "$line" >&2; exit 2; }
        if git -C "$HR_ROOT" cat-file -e "${hr_ps}^{commit}" 2>/dev/null; then
          printf '%s\n' "$hr_ps" >> "$HR_WORK/pins"
        elif [ "${line%% *}" = pin ]; then
          printf 'hermetic-run: %s: declared pin %s is not a commit in %s\n' "$HR_FX" "$hr_ps" "$HR_ROOT" >&2; exit 2
        else
          printf 'hermetic-run: %s: optional pin %s is not in this project'"'"'s history -- not imported\n' "$HR_FX" "$hr_ps"
          hr_pin_skipped=1
        fi ;;
      *) printf 'hermetic-run: %s: git.decl line is neither seed, pin <sha> nor pin? <sha>: %s\n' "$HR_FX" "$line" >&2; exit 2 ;;
    esac
  done < "$HR_FXDIR/git.decl"
  hr_sbgit() { ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES
                 git -C "$HR_SB" -c core.hooksPath=/dev/null -c commit.gpgsign=false "$@" ); }
  hr_sbgit init -q --template= . || { printf 'hermetic-run: %s: git init in the sandbox failed\n' "$HR_FX" >&2; exit 2; }
  if [ -s "$HR_WORK/pins" ]; then
    git -C "$HR_ROOT" rev-list --objects --no-walk --stdin < "$HR_WORK/pins" > "$HR_WORK/pin.objs" \
      && git -C "$HR_ROOT" pack-objects -q "$HR_SB/.git/objects/pack/pack" < "$HR_WORK/pin.objs" > /dev/null \
      || { printf 'hermetic-run: %s: could not pack the declared pins out of %s\n' "$HR_FX" "$HR_ROOT" >&2; exit 2; }
    while IFS= read -r hr_ps; do
      hr_sbgit cat-file -e "${hr_ps}^{commit}" 2>/dev/null \
        || { printf 'hermetic-run: %s: pin %s did not arrive in the sandbox repository\n' "$HR_FX" "$hr_ps" >&2; exit 2; }
    done < "$HR_WORK/pins"
  fi
  if [ "$hr_seed" = 1 ]; then
    hr_sbgit add -A \
      && GIT_AUTHOR_DATE='1970-01-01T00:00:00Z' GIT_COMMITTER_DATE='1970-01-01T00:00:00Z' \
         hr_sbgit -c user.name=hermetic -c user.email=hermetic@localhost commit -q --no-verify -m seed \
      || { printf 'hermetic-run: %s: the seed commit failed\n' "$HR_FX" >&2; exit 2; }
  fi
fi
# UNKEYED TOOLS (`?name`) are resolved HERE, after the --key-only exit above, so the key is byte-identical
# with and without the line. `command -v` on the invoker's PATH must answer an absolute executable path:
# a function, an alias or a bare word is not one.
: > "$HR_WORK/tools.unk"
while IFS= read -r un; do
  [ -n "$un" ] || continue
  ur="$(command -v "$un" 2>/dev/null)" || ur=""
  case "$ur" in /*) [ -x "$ur" ] || ur="" ;; *) ur="" ;; esac
  [ -n "$ur" ] || { printf 'hermetic-run: %s: declared tool name (unkeyed) is not on PATH: %s\n' "$HR_FX" "$un" >&2; exit 2; }
  printf '%s\n' "$ur" >> "$HR_WORK/tools.unk"
done < "$HR_WORK/unkeyed"
HR_BIN="$HR_WORK/bin"; mkdir -p "$HR_BIN"
for hr_tl in tools tools.unk; do
  while IFS= read -r t; do
    [ -n "$t" ] || continue
    if [ -e "$HR_BIN/${t##*/}" ] || [ -L "$HR_BIN/${t##*/}" ]; then
      # The same resolved path declared twice is one tool; two DIFFERENT paths sharing a basename are refused.
      [ "$(readlink "$HR_BIN/${t##*/}")" = "$t" ] && continue
      printf 'hermetic-run: %s: two declared tools share the basename %s -- the sandbox farm holds one\n' "$HR_FX" "${t##*/}" >&2; exit 2
    fi
    ln -s "$t" "$HR_BIN/${t##*/}"
  done < "$HR_WORK/$hr_tl"
done

HR_LOG="$HR_WORK/log"
( cd "$HR_SB" && env -i PATH="$HR_TOOL_DIRS:$HR_BIN" HOME="$HR_WORK/home" TMPDIR="$HR_WORK/tmp" \
    AI_DLC_PROJECT_ROOT="$HR_SB" PREPUSH_POOL_DEPTH="${PREPUSH_POOL_DEPTH:-}" \
    bash "$HR_FXROOT/$HR_FX/run.sh" ) > "$HR_LOG" 2>&1
hr_rc=$?
cat "$HR_LOG"

# REQUIRED inputs: each must have a `HERMETIC-CONSUMED <path>` line in the fixture's output, the
# path spelled as declared or prefixed by the sandbox root, whole-line, so neither a longer path
# nor a not-found message can satisfy it.
hr_missing=0
while IFS="$(printf '\t')" read -r r rdecl; do
  [ -n "$r" ] || continue
  rr="${r%/}"; rd="${rdecl%/}"
  rlbl="$r"; [ "$r" = "$rdecl" ] || rlbl="$r (declared as $rdecl)"
  if ! grep -qxF -e "HERMETIC-CONSUMED $rr" -e "HERMETIC-CONSUMED $rr/" -e "HERMETIC-CONSUMED $HR_SB/$rr" -e "HERMETIC-CONSUMED $HR_SB/$rr/" -e "HERMETIC-CONSUMED $rd" -e "HERMETIC-CONSUMED $rd/" "$HR_LOG"; then
    printf 'hermetic-run: %s: REQUIRED input %s was never consumed -- no HERMETIC-CONSUMED line names it, so the verdict did not depend on it\n' "$HR_FX" "$rlbl"
    hr_missing=1
  fi
done < "$HR_WORK/required"
# HR_SANDBOX_END

printf 'hermetic-run: %s: rc=%s sandbox_files=%s required_missing=%s\n' \
  "$HR_FX" "$hr_rc" "$(/usr/bin/find "$HR_SB" -type f | wc -l | tr -d ' ')" "$hr_missing"

# THE SHARED VERDICT STORE. This runner is its ONLY writer; the pre-push hooks only read it. A CLEAN PASS ONLY: rc 0 and no REQUIRED
# input missing. The entry is named for the sha256 of its body: the fixture name, this runner's sha, the sha of the
# hook spans this runner sources, and the --key-only rows of the same tree. Written atomically (temp + mv); two
# concurrent writers of one name write identical bytes. A failure to write drops the record and never changes
# this run's exit.
# The store path, the ident and the digest input are the hook's READSET_VS span, sourced here at top level (the
# READSET_TOOLS pattern), so the reader and this writer are one implementation. No span: the store is OFF.
sed -n '/^# READSET_VS_BEGIN$/,/^# READSET_VS_END$/p' "$HR_HOOK" > "$HR_WORK/vs.sh"
grep -q '^readset_vs_store() ' "$HR_WORK/vs.sh" && . "$HR_WORK/vs.sh" || : > "$HR_WORK/vs.sh"
# No READSET_KEYROWS span (version skew, above): no composer, so the store is OFF for this run.
[ "$HR_KR" = 1 ] || : > "$HR_WORK/vs.sh"
hr_store_put() {
  # A PASS WITH AN OPTIONAL PIN NOT IMPORTED IS NOT RECORDED. The key carries no trace of the pin, so a pass whose
  # pinned differential SKIPPED (a shallow clone) would be reused by a clone where that differential runs.
  [ "${hr_pin_skipped:-0}" = 0 ] || return 0
  local store ident dig
  [ -s "$HR_WORK/vs.sh" ] || return 0
  store="$(readset_vs_store "$HR_ROOT")"
  [ -n "$store" ] || { printf 'hermetic-run: %s: verdict store OFF: no store base, or the project root commit cannot be resolved\n' "$HR_FX"; return 0; }
  mkdir -p "$store" 2>/dev/null || return 0
  hr_population key || return 0
  hr_rows > "$HR_WORK/vs.rows" || return 0
  [ -s "$HR_WORK/vs.rows" ] || return 0
  ident="$(readset_vs_ident "$HR_HOOK" "${BASH_SOURCE[0]}")" || return 0
  readset_vs_input "$HR_FX" "$ident" "$HR_WORK/vs.rows" > "$HR_WORK/vs.d" || return 0
  dig="$(shasum -a 256 < "$HR_WORK/vs.d" | cut -d' ' -f1)"
  [ "${#dig}" -eq 64 ] || return 0
  { printf '#format k1\n#state ok\n'; cat "$HR_WORK/vs.d"; } > "$store/.tmp.$$.$HR_FX" 2>/dev/null \
    && mv "$store/.tmp.$$.$HR_FX" "$store/$dig" 2>/dev/null \
    && printf 'hermetic-run: %s: verdict recorded in the shared store\n' "$HR_FX" || rm -f "$store/.tmp.$$.$HR_FX" 2>/dev/null
  return 0
}
if [ "$hr_rc" -eq 0 ] && [ "$hr_missing" -eq 0 ]; then ( hr_store_put ) 2>/dev/null; exit 0; fi
[ "$hr_rc" -eq 2 ] && exit 2
exit 1
