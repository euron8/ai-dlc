#!/usr/bin/env bash
# consumer-read.sh — the ONE door every reconcile detector reads a consumer path through.
#
# NOT MARKED region-exempt, deliberately. I105 (validate-enforcement-map.sh) counts a file as
# INVOKED by the driver when emit-report.sh names `"$SELF/<file>"`, and emit-report.sh sources this
# file under exactly that spelling: its own render reads the consumer through these functions. So
# the driver does run it, in its own process, on every render, and a marker saying otherwise would
# be the stale half of I105's BOTH finding. It emits no rows of its own; the rows its reads feed
# are each detector's.
#
# Sourced (never executed) by emit-report.sh and by every script it runs, transitively. Each
# function takes the CONSUMER ROOT and a ROOT-RELATIVE path, and does exactly what the raw
# test, read, hash, walk or `git -C` it replaces did -- plus, when `CR_LOG` names a file, it
# appends the access to that file. emit-report.sh's recorded PASS is keyed on that log: the key
# re-takes every logged entry and misses on any difference, so a path a detector resolved on its
# own can no longer sit outside the key. Before this, the key was a hand-listed set of read roots,
# and every detector that resolved a path outside it (a `hooks:` value with `..`, an unquoted glob,
# a lexically collapsed receipt label, a case variant of an excluded prefix, a bare `scripts/`)
# recorded a PASS that a fresh render contradicted.
#
#   cr_test  <root> <op> <rel>        `[ <op> <root>/<rel> ]`; op is one of -e -f -d -x -s -r -w -L -h
#   cr_read  <root> <rel>             the file's bytes on stdout (cat's status)
#   cr_hash  <root> <rel>             `git hash-object --no-filters` of the file
#   cr_walk  <root> <rel> [find-args] `find <rel> [find-args]` run FROM <root>, so every name it
#                                     prints is root-relative (`<rel>/...`); -print0 passes through
#   cr_git   <root> <git-args...>     `git -C <root> <git-args...>`
#   cr_run   <root> <cmd...>          <cmd> with its working directory at <root>, for a program that
#                                     resolves consumer-relative paths against its cwd
#   cr_run_reads <root> <list> <cmd...> <cmd> with HOOKREG_READS_OUT=<list>, then the read list the
#                                     program RECORDED is logged entry by entry (see the function)
#   cr_retake <root> <log>            re-takes every entry of a log, printing it as it reads NOW
#
# THE PATH IS REFUSED, NEVER NORMALISED. A <rel> with a `..` component or a leading `/` returns 2
# and names itself on stderr, from every function, logging or not (cr_walk also refuses a leading
# `-`, which find would read as a predicate). `a/../b` is not
# rewritten to `b`: a lexical collapse is a second path resolver, and it disagrees with the OS
# exactly where it matters (a symlinked `a`, or no `a` at all). Each call site maps 2 to the way it
# already reports an unresolvable input; 2 is never "absent". `./` prefixes, `/./` and doubled or
# trailing slashes are spelled out of the LOG only; the OS resolves them identically.
#
# THE LOG RECORDS THE REQUESTED SPELLING, AND THE VALUE IS WHAT THE OS RESOLVES FOR IT. A case
# variant (`.claude/WORKTREES` on a case-insensitive volume) is its own entry, re-taken through the
# OS, so it keys exactly the bytes the detector read. No key field EXCLUDES a prefix any more, so
# there is no excluded spelling for a variant to slip past.
#
# LOG LINE: `<kind> TAB <rel> TAB <value>`. Kinds: t (a test), r (a read or hash), w (a walk), g (a
# git command; its value is the git-state fields emit-report.sh keys), x (a program run at the
# root; its reads are invisible here, see cr_run), ! (a call this log cannot represent: a root other
# than CR_ROOT, or a name carrying a tab or newline -- the record is refused on it). Values, from
# cr__val, identical at access time and at every re-take:
#   L <comp>        a component of <rel>, the last included, is a symlink (R2 refuses the record)
#   -               absent
#   d               a directory          o   neither a file nor a directory (FIFO, socket, device)
#   f<x><r> <blob>  a regular file: exec bit, read bit, then its raw blob id (`?` when unreadable)
#   w<rc> <sha>     a walk: find's status and a hash over its whole typed listing; `L <sha>` when a
#                   walked entry is a symlink
# Logging, and every hash it costs, happens only when CR_LOG is set. CR_ROOT is the consumer root
# as `pwd -P` spells it; a call naming any other root logs `!`.
#
# GLOBBING IS OFF. Every closure script sets `-f` in its preamble and this file never turns it on.
# Every internal helper starts with `cr_` and every function's closing brace sits in column 0.

case $- in *f*) ;; *) set -f ;; esac

# cr__guard <rel> -- 0 when <rel> may name a consumer path, 2 (named on stderr) when it may not.
cr__guard() {
  case "/$1/" in
    */../*) ;;
    *) case "$1" in /*) ;; *) return 0 ;; esac ;;
  esac
  printf 'consumer-read: refused the consumer path %s: it must be relative to the consumer root, with no ".." component and no leading "/"\n' "'$1'" >&2
  # A refused path was asked for, so the render depended on something the log cannot re-take: the
  # entry makes emit-report.sh refuse to record.
  [ -z "${CR_LOG:-}" ] || printf '!\tguard\t-\n' >> "$CR_LOG"
  return 2
}

# cr__canon <rel> -- the log spelling: no leading `./`, no `/./`, no doubled or trailing `/`; `.` for
# the root itself.
cr__canon() {
  local r="$1"
  while :; do
    case "$r" in
      ./*) r="${r#./}" ;;
      *//*) r="${r//\/\//\/}" ;;
      */./*) r="${r//\/.\//\/}" ;;
      */.) r="${r%/.}" ;;
      ?*/) r="${r%/}" ;;
      *) break ;;
    esac
  done
  [ -n "$r" ] || r=.
  printf '%s' "$r"
}

# cr__links <root> <rel> -- prints the first component of <rel> that is a symlink, walking from the
# root; 1 when there is none.
cr__links() {
  local p="$1" rest="$2" c
  [ "$rest" != . ] || return 1
  while [ -n "$rest" ]; do
    c="${rest%%/*}"
    case "$rest" in */*) rest="${rest#*/}" ;; *) rest="" ;; esac
    p="$p/$c"
    if [ -L "$p" ]; then printf '%s' "${p#"$1"/}"; return 0; fi
    [ -e "$p" ] || return 1
  done
  return 1
}

# cr__val <kind> <root> <rel> -- the entry's value as the OS answers it now (see the header).
cr__val() {
  local p="$2/$3" l h t rc
  if l="$(cr__links "$2" "$3")"; then printf 'L %s' "$l"; return 0; fi
  case "$1" in
    t|r)
      if [ -d "$p" ]; then printf 'd'
      elif [ -f "$p" ]; then
        h="f"; if [ -x "$p" ]; then h="${h}x"; else h="${h}-"; fi
        if [ -r "$p" ]; then
          t="$(git hash-object --no-filters -- "$p" 2>/dev/null)" || t="?"
          printf '%sr %s' "$h" "$t"
        else printf '%s- ?' "$h"; fi
      elif [ -e "$p" ]; then printf 'o'
      else printf -- '-'; fi ;;
    w)
      if [ ! -e "$p" ]; then printf -- '-'; return 0; fi
      [ -d "$p" ] || { printf 'nd'; return 0; }
      h="$(cd "$2" 2>/dev/null && {
             set -o pipefail
             rc=0
             for t in d f l; do
               printf '%s\0' "$t"
               find "$3" -type "$t" -print0 2>/dev/null | LC_ALL=C sort -z || rc=1
             done
             printf 'o\0'
             find "$3" ! -type d ! -type f ! -type l -print0 2>/dev/null | LC_ALL=C sort -z || rc=1
             printf 'rc %s\0' "$rc"
           } | git hash-object --stdin)" || h="?"
      l="$(cd "$2" 2>/dev/null && find "$3" -type l -print 2>/dev/null | sed -n 1p)"
      if [ -n "$l" ]; then printf 'L %s' "$h"; else printf 'w %s' "$h"; fi ;;
    g) printf 'git-state' ;;
    x) printf 'foreign' ;;
    *) printf '?' ;;
  esac
}

# cr__log <kind> <root> <rel> [value] -- appends one entry when CR_LOG is set. The value is taken
# here unless the caller already has it (cr_read hashes the bytes it staged).
cr__log() {
  [ -n "${CR_LOG:-}" ] || return 0
  local rel v
  if [ -z "${CR_ROOT:-}" ]; then printf '!\troot\tno CR_ROOT\n' >> "$CR_LOG"; return 0; fi
  if [ "$2" != "${CR__ROOT_OK:-}" ]; then
    if [ "$(cd "$2" 2>/dev/null && pwd -P)" = "$CR_ROOT" ]; then CR__ROOT_OK="$2"
    else printf '!\troot\t-\n' >> "$CR_LOG"; return 0; fi
  fi
  rel="$(cr__canon "$3")"
  case "$rel" in
    *"$(printf '\t')"*|*"
"*) printf '!\tname\t-\n' >> "$CR_LOG"; return 0 ;;
  esac
  if [ "$#" -ge 4 ]; then v="$4"; else v="$(cr__val "$1" "$2" "$rel")"; fi
  printf '%s\t%s\t%s\n' "$1" "$rel" "$v" >> "$CR_LOG"
}

# ROOT FIRST, like every other function here: `cr_test <op> <root>` would put `test -d "$ROOT"` in
# the source text, which reads as a raw rooted test to the closure's own read-site scanner.
# cr_path <root> <rel> -- the consumer path "<root>/<rel>" on stdout, for a reader that must take it as
# an OPERAND (a `diff` a caller's shim shadows, a program that resolves it itself). The path is
# guarded and the read is logged as a test entry (presence, kind, bits, blob), exactly as cr_test
# logs it. It forks nothing and writes nothing: a staged copy or a link in its place was a new write
# or a new tool ahead of the reader. 1 when the file is absent, 2 when refused.
cr_path() {
  cr__guard "$2" || return 2
  cr__log t "$1" "$2"
  [ -f "$1/$2" ] || return 1
  printf '%s/%s\n' "$1" "$2"
}

cr_test() {
  cr__guard "$3" || return 2
  case "$2" in -e|-f|-d|-x|-s|-r|-w|-L|-h) ;; *) printf 'consumer-read: cr_test does not take %s\n' "'$2'" >&2; return 2 ;; esac
  cr__log t "$1" "$3"
  [ "$2" "$1/$3" ]
}

cr_read() {
  cr__guard "$2" || return 2
  if [ -z "${CR_LOG:-}" ]; then cat -- "$1/$2"; return; fi
  local s rc l h v
  s="$(mktemp "${TMPDIR:-/tmp}/consumer-read.XXXXXX")" || { cr__log r "$1" "$2"; cat -- "$1/$2"; return; }
  cat -- "$1/$2" > "$s"; rc=$?
  # The VALUE of a read is the bytes it DELIVERED: staged once, hashed, then emitted from the stage.
  if l="$(cr__links "$1" "$(cr__canon "$2")")"; then v="L $l"
  elif [ -d "$1/$2" ]; then v=d
  elif [ -f "$1/$2" ]; then
    if [ -x "$1/$2" ]; then h="fx"; else h="f-"; fi
    if [ "$rc" -eq 0 ]; then v="${h}r $(git hash-object --no-filters -- "$s" 2>/dev/null || echo '?')"; else v="${h}- ?"; fi
  elif [ -e "$1/$2" ]; then v=o
  else v=-; fi
  cr__log r "$1" "$2" "$v"
  cat -- "$s"
  rm -f -- "$s"
  return "$rc"
}

cr_hash() {
  cr__guard "$2" || return 2
  cr__log r "$1" "$2"
  git hash-object --no-filters -- "$1/$2"
}

# cr__strip <prefix> <nul:0|1> -- each name on stdin with <prefix> removed, in pure bash: no tool
# beyond the shell, so a hermetic tool farm that declares `find` needs nothing else for a walk.
cr__strip() {
  local p="$1" l
  if [ "$2" = 1 ]; then
    while IFS= read -r -d '' l; do printf '%s\0' "${l#"$p"}"; done
  else
    while IFS= read -r l; do printf '%s\n' "${l#"$p"}"; done
  fi
}

# FIND IS HANDED THE ABSOLUTE PATH, `<root>/<rel>`, the argv every detector passed it before this
# file existed, and the root prefix is stripped from each name afterwards, so the names stay
# root-relative. Run from inside the root with a relative operand, find's argv no longer carried
# the consumer path, and a probe keyed on it (a stubbed find that must fail one layer walk) never
# fired. A `-path` predicate therefore matches the ABSOLUTE spelling (`<root>/<rel>/...`). find's
# own status is the walk's status: the strip cannot mask a failed walk.
cr_walk() {
  local root="$1" rel="$2" a nul=0
  cr__guard "$rel" || return 2
  # find reads a leading `-` as a predicate, not a path.
  case "$rel" in -*) printf 'consumer-read: cr_walk cannot walk %s: a leading "-" is a find predicate\n' "'$rel'" >&2; return 2 ;; esac
  shift 2
  for a in "$@"; do [ "$a" != -print0 ] || nul=1; done
  cr__log w "$root" "$rel"
  # NO bash PROCESS OF THIS SHELL'S LINEAGE MAY EXIT THROUGH bash HERE. After a failed write, bash
  # still holds the unflushed bytes in its stdout buffer; a `( … )` subshell or a builtin pipeline
  # stage is a fork that flushes them when it exits, so the leaked fragment landed in the walk's
  # output and a caller iterated junk entries (measured: layer-drift's extensions loop under XFSZ,
  # three junk entries; the old `find | sort` leaked none). So the pipeline runs in THIS shell, its
  # status is read from PIPESTATUS, and every stage EXECs a program, which discards the inherited
  # buffer: awk strips a line walk (the prefix through ENVIRON, which keeps a backslash `-v` would
  # eat), and an exec'd "$BASH" strips a NUL walk, which BSD awk cannot split.
  local _cr_st
  if [ "$nul" = 1 ]; then
    find "$root/$rel" "$@" | CR__P="$root/" "$BASH" -c 'p="$CR__P"; while IFS= read -r -d "" l; do printf "%s\0" "${l#"$p"}"; done'
  else
    find "$root/$rel" "$@" | CR__P="$root/" awk 'BEGIN { p = ENVIRON["CR__P"]; n = length(p) } { if (substr($0, 1, n) == p) $0 = substr($0, n + 1); print }'
  fi
  _cr_st="${PIPESTATUS[0]}:${PIPESTATUS[1]}"
  [ "${_cr_st%%:*}" -eq 0 ] || return "${_cr_st%%:*}"
  return "${_cr_st##*:}"
}

# cr_list <root> <rel> -- the immediate non-dot subdirectories of <rel> (a link to a directory
# included), one root-relative name per line, in the order the shell's `<dir>/*/` glob expands:
# exactly the set and order such a glob gave, with no `find` or `sort` forked. Logged as a walk of
# <rel>. 1 when <rel> is not a directory. The glob runs in a subshell, so the caller's -f stands.
cr_list() {
  local root="$1" rel="$2"
  cr__guard "$rel" || return 2
  cr__log w "$root" "$rel"
  [ -d "$root/$rel" ] || return 1
  (
    set +f
    for e in "$root/$rel"/*/; do
      [ -d "$e" ] || continue
      e="${e%/}"
      printf '%s\n' "$rel/${e##*/}"
    done
    set -f
  )
}

cr_git() {
  local root="$1"
  shift
  cr__log g "$root" .
  git -C "$root" "$@"
}

# cr_run <root> <cmd...> -- for a program that reads consumer paths ITSELF (a predicate validator, an
# `sh` receipt): its reads cannot be logged here, so the entry is `x`, and emit-report.sh keeps its
# whole-tree git fields (tracked and untracked bytes) for exactly these, and each caller pre-logs the
# paths it KNOWS the program reads. An IGNORED file such a program opens on its own is a stated limit
# of the key (emit-report.sh's header). A failed `cd` is a non-zero exit, never a run at the
# caller's cwd.
cr_run() {
  local root="$1"
  shift
  cr__log x "$root" .
  ( cd "$root" && "$@" )
}

# cr_run_reads <root> <list> <cmd...> -- for a program that RECORDS its own consumer reads (today
# validate-hook-registration.sh, the hook-registration section's validator at THEIRS). <cmd> runs with
# HOOKREG_READS_OUT=<list> in its environment and the caller's cwd unchanged; its stdout, stderr and
# exit are its own, and nothing this function does reaches either stream. Only when CR_LOG is set is
# the list then read: its first line must be the sentinel `hookreg-reads 1`, and each later line is
# `<kind> TAB <path relative to <root>>`, logged through the existing door as the path the program
# recorded -- `t` through cr_test, `r` through cr_hash, `w` through cr_walk. A list that is missing,
# lacks the sentinel, carries no entry after it, or holds a `!` (a subprocess, whose reads no list
# names) or any other kind logs `!`, so the record refuses: an older program that writes no list
# fails CLOSED, never records unkeyed. The variable has no AI_DLC_ prefix: fixtures scrub that prefix.
cr_run_reads() {
  local root="$1" rf="$2" rc k p first n=0 bad=0
  shift 2
  HOOKREG_READS_OUT="$rf" "$@"; rc=$?
  [ -n "${CR_LOG:-}" ] || return "$rc"
  if [ ! -f "$rf" ]; then printf '!\treads-list\t-\n' >> "$CR_LOG"; return "$rc"; fi
  {
    IFS= read -r first || first=""
    if [ "$first" = "hookreg-reads 1" ]; then
      # `|| [ -n "$k" ]`: a last entry with no trailing newline is still an entry, never dropped.
      while IFS="$(printf '\t')" read -r k p || [ -n "$k" ]; do
        n=$((n + 1))
        [ -n "$p" ] || { bad=1; continue; }
        case "$k" in
          t) cr_test "$root" -e "$p" >/dev/null 2>&1 ;;
          r) cr_hash "$root" "$p" >/dev/null 2>&1 ;;
          w) cr_walk "$root" "$p" >/dev/null 2>&1 ;;
          *) bad=1 ;;
        esac
      done
    else
      bad=1
    fi
  } < "$rf"
  [ "$bad" = 0 ] && [ "$n" -gt 0 ] || printf '!\treads-list\t-\n' >> "$CR_LOG"
  return "$rc"
}

# cr_retake <root> <log> -- every entry of <log> re-taken now, one line each, in the log's order and
# shape, with logging off. emit-report.sh compares the output with the recorded entries.
cr_retake() {
  local k r v
  while IFS="$(printf '\t')" read -r k r v; do
    case "$k" in
      t|r|w|g|x) printf '%s\t%s\t%s\n' "$k" "$r" "$(cr__val "$k" "$1" "$r")" ;;
      *) printf '%s\t%s\t%s\n' "$k" "$r" "unrepresentable" ;;
    esac
  done < "$2"
}
