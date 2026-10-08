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
# exactly as the hook treats them. The hook derives the identical rows from the declaration in
# `readset_keys`; the self-probe fixture asserts the two agree byte-for-byte, because two
# implementations of one key drift. A run with no hook to source is exit 2, key-only or not: the tool
# dirs and the unkeyed-tool vocabulary come from the hook's READSET_TOOLS span, so there is no copy of
# them here to drift.
#
# THE SANDBOX. A fresh `mktemp -d`, `env -i`, PATH pinned to the fixed tool dirs plus a symlink farm
# of the declared tools (keyed and unkeyed), `AI_DLC_PROJECT_ROOT` set to the sandbox root, and the fixture invoked as
# `bash core/fixtures/<f>/run.sh` from the sandbox ROOT -- the pre-push pool's own invocation, never
# a `cd` into the fixture directory (CLAUDE.md measures that as five fabricated failures).
# The sandbox is removed on exit unless `AI_DLC_HERMETIC_KEEP=1`.
#
# A FIXTURE WITHOUT A DECLARATION IS NOT THIS RUNNER'S: exit 2. The hook dispatches to this runner
# only when `inputs.decl` exists, so a missing declaration here is a caller defect, not a skip.
set -u

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

# Parse the declaration. Pass 1 reads `[!]path[/]` lines into <req><TAB><path as declared>; pass 2 maps
# them (consumer layout, any path under core/) and fills the files, dirs and required lists.
: > "$HR_WORK/files"; : > "$HR_WORK/dirs"; : > "$HR_WORK/required"; : > "$HR_WORK/tools"; : > "$HR_WORK/unkeyed"; : > "$HR_WORK/dl"
hr_bad=0; hr_needmap=0
while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in ''|'#'*) continue ;; esac
  req=0; p="$line"
  case "$p" in '!'*) req=1; p="${p#!}" ;; esac
  case "$p" in /*|*/../*|../*|*/..|..) printf 'hermetic-run: %s: declaration path must be root-relative with no .. : %s\n' "$HR_FX" "$line" >&2; hr_bad=1; continue ;; esac
  printf '%s\t%s\n' "$req" "$p" >> "$HR_WORK/dl"
  case "$p" in core|core/|core/*) hr_needmap=1 ;; esac
done < "$HR_FXDIR/inputs.decl"
if [ "$HR_LAYOUT" = consumer ] && [ "$hr_needmap" = 1 ]; then
  [ -f "$HR_SCRIPT_DIR/core-paths.sh" ] || { printf 'hermetic-run: %s: mapper absent -- %s/core-paths.sh is needed to map a core/ declaration onto a consumer layout\n' "$HR_FX" "$HR_SCRIPT_DIR" >&2; exit 2; }
  cut -f2 "$HR_WORK/dl" | bash "$HR_SCRIPT_DIR/core-paths.sh" --map > "$HR_WORK/mp" 2> "$HR_WORK/mp.err" \
    || { printf 'hermetic-run: %s: a declared core/ path has no consumer location: %s\n' "$HR_FX" "$(cat "$HR_WORK/mp.err")" >&2; exit 2; }
  [ "$(grep -c . "$HR_WORK/mp")" = "$(grep -c . "$HR_WORK/dl")" ] || { printf 'hermetic-run: %s: the mapper returned a different number of paths than were declared\n' "$HR_FX" >&2; exit 2; }
  paste "$HR_WORK/dl" "$HR_WORK/mp" > "$HR_WORK/dm"
else
  awk -F'\t' '{ print $0 "\t" $2 }' "$HR_WORK/dl" > "$HR_WORK/dm"
fi
while IFS="$(printf '\t')" read -r req dp p; do
  [ -n "$dp" ] || continue
  # lbl is the path as the error names it: the mapped spelling, and the declared one when they differ.
  lbl="$p"; [ "$p" = "$dp" ] || lbl="$p (declared as $dp)"
  if [ "${p%/}" != "$p" ]; then
    p="${p%/}"
    [ -d "$HR_ROOT/$p" ] || { printf 'hermetic-run: %s: declared directory absent: %s\n' "$HR_FX" "$lbl" >&2; hr_bad=1; continue; }
    printf '%s\n' "$p" >> "$HR_WORK/dirs"
    [ "$req" = 1 ] && printf '%s/\t%s\n' "$p" "$dp" >> "$HR_WORK/required"
  else
    [ -f "$HR_ROOT/$p" ] || { printf 'hermetic-run: %s: declared file absent: %s\n' "$HR_FX" "$lbl" >&2; hr_bad=1; continue; }
    printf '%s\n' "$p" >> "$HR_WORK/files"
    [ "$req" = 1 ] && printf '%s\t%s\n' "$p" "$dp" >> "$HR_WORK/required"
  fi
done < "$HR_WORK/dm"
if [ -f "$HR_FXDIR/tools.decl" ]; then
  while IFS= read -r t || [ -n "$t" ]; do
    case "$t" in ''|'#'*) continue ;; esac
    case "$t" in
      '?'*)
        un="${t#?}"
        case "$un" in ''|*[!A-Za-z0-9_.+-]*) printf 'hermetic-run: %s: tools.decl line is not an unkeyed tool name: %s\n' "$HR_FX" "$t" >&2; hr_bad=1; continue ;; esac
        case " $READSET_UNKEYED_TOOLS " in *" $un "*) ;; *) printf 'hermetic-run: %s: tools.decl line %s names a tool outside READSET_UNKEYED_TOOLS (%s)\n' "$HR_FX" "$t" "$READSET_UNKEYED_TOOLS" >&2; hr_bad=1; continue ;; esac
        printf '%s\n' "$un" >> "$HR_WORK/unkeyed"
        continue ;;
    esac
    case "$t" in */*) printf 'hermetic-run: %s: tools.decl names a path, wants a bare name: %s\n' "$HR_FX" "$t" >&2; hr_bad=1; continue ;; esac
    found=""
    ( IFS=:; for d in $HR_XPD; do [ -x "$d/$t" ] && { printf '%s\n' "$d/$t"; break; }; done ) > "$HR_WORK/t1"
    found="$(cat "$HR_WORK/t1")"
    [ -n "$found" ] || { printf 'hermetic-run: %s: declared tool %s resolves in none of %s\n' "$HR_FX" "$t" "$HR_XPD" >&2; hr_bad=1; continue; }
    printf '%s\n' "$found" >> "$HR_WORK/tools"
  done < "$HR_FXDIR/tools.decl"
fi
if [ ! -s "$HR_WORK/files" ] && [ ! -s "$HR_WORK/dirs" ]; then
  printf 'hermetic-run: %s: inputs.decl is empty -- refusing to run the fixture against an empty tree\n' "$HR_FX" >&2
  hr_bad=1
fi
[ "$hr_bad" = 0 ] || exit 2

# THE KEY ROWS, derived from the declaration against the live tree, in the hook's grammar. The
# population is what git can see (tracked plus untracked-unignored), which is the hook's universe
# minus the content key's excluded tops; a declaration naming a path under an excluded top is keyed
# by the hook as absent and by this print as hashed, and that is the one place the two can differ.
# Rows: every declared file; every file under a declared directory; the declared directory and
# every directory under it as `<dir>/\t#listing:<sha>` where the listing is the directory's
# immediate entry names IMPLIED BY THE FILE LIST (C-sorted, one per line -- the hook's
# readset_listings grammar, never readdir); every file under the fixture's own directory; and each
# declared tool by absolute path.
hr_key_rows() {
  local hook="$HR_HOOK" span
  span="$HR_WORK/universe.sh"
  sed -n '/^# READSET_UNIVERSE_BEGIN$/,/^# READSET_UNIVERSE_END$/p' "$hook" > "$span"
  grep -q '^readset_manifest() ' "$span" || { printf 'hermetic-run: %s carries no READSET_UNIVERSE span with readset_manifest\n' "$hook" >&2; return 2; }
  (
    cd "$HR_ROOT" || exit 2
    READSET_MAP=/dev/null READSET_LOCAL=/dev/null
    . "$span" || exit 2
    mkdir -p "$HR_WORK/m" && readset_manifest "$HR_WORK/m"
    [ -s "$HR_WORK/m/.now" ] || { printf 'hermetic-run: could not hash the working tree under %s\n' "$HR_ROOT" >&2; exit 2; }
    cut -f1 "$HR_WORK/m/.now" > "$HR_WORK/kall"
    { while IFS= read -r p; do [ -n "$p" ] && grep -xF -- "$p" "$HR_WORK/kall"; done < "$HR_WORK/files"
      while IFS= read -r d; do [ -n "$d" ] && grep -- "^$(printf '%s' "$d" | sed 's/[][\.*^$]/\\&/g')/" "$HR_WORK/kall"; done < "$HR_WORK/dirs"
      grep -- "^$(printf '%s' "$HR_FXROOT/$HR_FX" | sed 's/[][\.*^$]/\\&/g')/" "$HR_WORK/kall"
      :; } | LC_ALL=C sort -u > "$HR_WORK/kfiles"
    # File rows are the manifest's own hashes, never recomputed.
    [ -s "$HR_WORK/kfiles" ] && awk -F'\t' -v kf="$HR_WORK/kfiles" 'BEGIN { while ((getline l < kf) > 0) w[l] = 1 } ($1 in w)' "$HR_WORK/m/.now"
    # Listings implied by the whole universe list, for the declared directories and their subdirectories.
    awk '{ p = $0; while ((i = match(p, /\/[^\/]*$/)) > 0) { d = substr(p, 1, i - 1); print d "\t" substr(p, i + 1); p = d } }' "$HR_WORK/kall" \
      | LC_ALL=C sort -u > "$HR_WORK/kent"
    : > "$HR_WORK/kdirs"
    while IFS= read -r d; do
      [ -n "$d" ] || continue
      awk -F'\t' -v d="$d" '$1 == d || index($1, d "/") == 1 { print $1 }' "$HR_WORK/kent" >> "$HR_WORK/kdirs"
    done < "$HR_WORK/dirs"
    LC_ALL=C sort -u "$HR_WORK/kdirs" > "$HR_WORK/kdirs.u"
    while IFS= read -r d; do
      awk -F'\t' -v d="$d" '$1 == d { print $2 }' "$HR_WORK/kent" | shasum -a 256 | awk -v d="$d" '{ print d "/\t#listing:" $1 }'
    done < "$HR_WORK/kdirs.u"
    [ -s "$HR_WORK/tools" ] && tr '\n' '\000' < "$HR_WORK/tools" | xargs -0 shasum -a 256 -- 2>/dev/null \
      | awk '{ p = $0; sub(/^[0-9a-f]+  /, "", p); print p "\t" $1 }'
    :
  ) | LC_ALL=C sort -u
}
if [ "$HR_KEY_ONLY" = 1 ]; then hr_key_rows; exit $?; fi

# THE SANDBOX: copy declared files and directories at their own relative paths, the fixture's own
# directory (or the override), and nothing else.
# `pwd -P`, because macOS hands out TMPDIR under /var which is a symlink to /private/var, and a
# fixture comparing AI_DLC_PROJECT_ROOT against its own `pwd` must see one spelling.
mkdir -p "$HR_WORK/sb" "$HR_WORK/home" "$HR_WORK/tmp" || exit 2
HR_SB="$(cd "$HR_WORK/sb" && pwd -P)" || exit 2
# DIRECTORIES FIRST, FILES SECOND, AND THE DIRECTORY COPY REFUSES AN EXISTING TARGET. A declared
# file under a declared directory had made the file's parent exist before `cp -Rp dir target` ran,
# and BSD cp then copies INTO an existing target, nesting `d/d/` inside the sandbox -- measured by
# the tip adversary. Copying directories first means a target never pre-exists; a declared
# directory that is a sub-tree of another declared directory is already present after the outer
# copy and is skipped rather than nested.
# A SYMLINK IS A READ OUTSIDE THE DECLARATION. `cp -Rp` keeps a link as a link, so a declared
# directory holding `lnk -> /etc/hosts` lets the sandboxed fixture read a file nobody declared --
# measured by the tip adversary. Refused, not dereferenced: a dereferenced copy would silently key
# the fixture on the link and not on its target. The fixture's own directory is held to the same rule.
hr_no_symlinks() { # <root-relative path, file or dir>: exit 2 naming the first symlink under it
  local l
  l="$(cd "$HR_ROOT" && /usr/bin/find "$1" -type l -print 2>/dev/null | head -1)"
  [ -z "$l" ] || { printf 'hermetic-run: %s: %s is a symlink -- a link reaches outside the declaration, so it cannot be copied into the sandbox\n' "$HR_FX" "$l" >&2; exit 2; }
}
while IFS= read -r d; do
  [ -n "$d" ] || continue
  hr_no_symlinks "$d"
  [ -e "$HR_SB/$d" ] && continue
  mkdir -p "$HR_SB/$(dirname "$d")" && cp -Rp "$HR_ROOT/$d" "$HR_SB/$d" || exit 2
done < "$HR_WORK/dirs"
while IFS= read -r p; do
  [ -n "$p" ] || continue
  hr_no_symlinks "$p"
  [ -f "$HR_SB/$p" ] && continue
  mkdir -p "$HR_SB/$(dirname "$p")" && cp -p "$HR_ROOT/$p" "$HR_SB/$p" || exit 2
done < "$HR_WORK/files"
hr_no_symlinks "$HR_FXROOT/$HR_FX"
mkdir -p "$HR_SB/$HR_FXROOT" && cp -Rp "$HR_FXDIR" "$HR_SB/$HR_FXROOT/$HR_FX" || exit 2
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

printf 'hermetic-run: %s: rc=%s sandbox_files=%s required_missing=%s\n' \
  "$HR_FX" "$hr_rc" "$(/usr/bin/find "$HR_SB" -type f | wc -l | tr -d ' ')" "$hr_missing"
[ "$hr_rc" -eq 0 ] && [ "$hr_missing" -eq 0 ] && exit 0
[ "$hr_rc" -eq 2 ] && exit 2
exit 1
