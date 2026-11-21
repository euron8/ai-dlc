#!/usr/bin/env bash
# suite-content-key.sh — a content key over everything the distribution's fixture
# suite can read, so an unchanged tree does not pay ~50s of wall clock to re-derive
# the same 84 verdicts.
#
# WHAT THIS IS NOT. It is not a narrowing, a sampling, or a per-unit cache. Those
# buy time by not looking, and a check that cannot fire reads exactly like one that
# passed. This never changes what any fixture examines; it decides only whether the
# suite ALREADY ran over byte-identical inputs. The key is a SUPERSET of the inputs,
# so a false hit needs the key to collide, not merely to be incomplete.
#
# THE POLARITY IS THE WHOLE DESIGN. The included set is "everything the repository
# carries EXCEPT a short declared exclusion list" -- never a list of trees to
# include. An include-list is the check-that-cannot-fire shape: a tree nobody
# remembered to add is silently outside the key, and the suite then skips on a
# change it never hashed. With this polarity a new directory is covered the moment
# it appears, and the only way to lose coverage is to write a new line into
# EXCLUDE below -- which I55 makes a deliberate, reviewed act.
#
#   The handoff that scoped this row named four trees -- core/, scripts/,
#   .githooks/, templates/ -- as the set "declared in the seeds". Derived against
#   the tree instead: fixtures also reach $ROOT/.claude, and
#   `ledger-status-vocabulary` builds its subject tree from `git ls-files`, so it
#   copies EVERY TRACKED FILE, docs/ and CHANGELOG.md included. A four-tree
#   include-list would have skipped on changes inside a fixture's own input tree.
#
# WHY AN EXCLUSION SET EXISTS AT ALL. Without one the key covers CHANGELOG.md and
# VERSION, which every release edits, and the hit rate is zero. The exclusions are
# justified by measurement, not by argument -- see EXCLUDE.
#
# HISTORY RANGES ARE IN THE KEY. A fixture whose git.decl carries a `range` line reads git history, which the tree
# does not hold; the `### ranges` component folds each such line's read-set hash, so a moved range moves this key.
#
# OUTPUT. One line: the key. `--explain` prints the components it was built from
# and `--summary` the sets it used; the pre-push announce shows both on a hit,
# because a silent cached green is the defect class with a stopwatch attached.
#
# EXIT. 0 and a key on stdout, or non-zero with a reason on stderr. Every caller
# MUST treat a non-zero exit, or an empty key, as "run the suite" -- this script
# failing must never be the thing that skips it.

sck_main() {
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" || exit 1
cd "$REPO_ROOT" || exit 1

# SCK_RW is the ranges scratch directory while one exists: a refusal removes it (no trap, so a caller that sources this keeps its own).
SCK_RW=""
die() { printf 'suite-content-key: %s\n' "$*" >&2; [ -z "$SCK_RW" ] || rm -rf "$SCK_RW"; exit 1; }

# ---------------------------------------------------------------------------
# THE EXCLUSION SET, and the evidence for each line.
#
# MEASURED 2026-07-29, and this is the only thing standing between the skip and a
# fidelity loss, so it is measured rather than reasoned. Method: a faithful `tar`
# copy of the repository including .git (control), and a second copy with the
# CONTENT of every path below overwritten -- not appended to, overwritten --
# guarded by `diff -rq` so a no-op mutation could not pass as one that landed
# (46 paths differed). Both trees ran the full 84-fixture suite at -P16 and were
# compared on verdicts and on every fixture's normalised stdout. Verdicts
# identical, 84/84 both sides; the three stdout differences are sandbox git shas
# and elapsed-second values, and a second run of the CONTROL against itself
# reproduces exactly those three, which is what makes them nondeterminism rather
# than an effect of the mutation.
#
# The control earned its place immediately, as it did in v0.194.0: an earlier
# round copied the tree WITHOUT .git and `ledger-status-vocabulary` went red,
# which reads exactly like a mutation kill and is not one. That is also how the
# tracked-path listing below got into the key.
#
# WHAT THIS DOES NOT PROVE. That no FUTURE check reads these paths. The mutation
# was taken against the suite as it stands. I55 is the durable half: it fails the
# build if a script the suite drives starts naming an excluded path at the real
# repository root.
#
# .git is excluded on a different footing and is not a measurement: it is the
# object store, it changes on every commit, and its one input to the suite --
# which paths are tracked -- is folded back in explicitly as the `tracked`
# component below.
#
# CLAUDE.md ADDED 2026-08-10, BY THE SAME METHOD, AND IT IS THE CASE THIS HEADER
# ALREADY DESCRIBES WITHOUT NAMING. The paragraph above records that the original
# four-tree scoping was corrected because `ledger-status-vocabulary` builds its
# subject tree from `git ls-files` and therefore copies EVERY TRACKED FILE. That is
# also the ONLY reason CLAUDE.md was inside the key: it is in exactly one fixture's
# trace-derived read-set, that fixture's read-set is 519 of 534 tracked paths, and
# nothing in its chain reads the file as INPUT -- `validate-enforcement-map.sh`
# reads CLAUDE.md at run time only as one root of the I108 and I121-I123 corpus walks
# (a FIFO there hangs it).
# (Control: `templates/CLAUDE.md.template`, a DIFFERENT file one basename away, is a
# genuine input to nine fixtures and stays in the key.)
#
# MEASURED, not argued, to the standard the paragraph above sets: two faithful tar
# copies of the repository including .git, the mutant's CLAUDE.md OVERWRITTEN --
# 222 lines replaced by 4, `cmp -s`-guarded so a no-op could not pass as a mutation,
# and `diff -rq` confirming exactly ONE path differs. Both trees ran the full
# 133-fixture suite at AI_DLC_FIXTURE_NO_SKIP=1. Verdicts identical, 133 ok / 0 FAIL
# on both sides.
#
# AND THE COVERAGE IS NOT LOST, WHICH IS THE ONLY THING THIS EXCLUSION COULD COST.
# `audit-rule-files.sh` reads CLAUDE.md on EVERY push as its own pre-push step,
# outside the fixture suite and unaffected by this key. What the exclusion removes is
# a whole-suite re-run -- minutes, on the reference tree -- triggered by editing a
# file. Four fixture verdicts DO read its content (BL-797); each keys it with
# `+CLAUDE.md` in its own inputs.decl, and I55 arm 5 refuses a bare declaration.
# layer-contract-conformance-b runs the same full control but has no CLAUDE.md in
# its hermetic sandbox; the parent's `+CLAUDE.md` re-runs that family.
# EXCLUDE_BEGIN
EXCLUDE="
.git
CHANGELOG.md
VERSION
docs
CLAUDE.md
"
# EXCLUDE_END

# GIT-IGNORED PATHS ARE NOT IN THE KEY, and that boundary is DERIVED -- it is the
# repository's own .gitignore, read by git, not a second list maintained here. It
# has to be excluded: `.claude/` and `_bmad-output/` are ignored precisely because
# hooks and fixtures WRITE INTO THEM while the suite runs (the .gitignore says so
# in its own comment), so a key that covered them would differ from itself across
# the very run it is keyed on, and no push would ever hit.
#
# Measured, not assumed: the 84/84 control tree above was built by `tar` with
# node_modules and .DS_Store excluded and went fully green without them, so
# neither is a suite input. `.claude/` carries two files here, a lock and
# settings.local.json, and the fixtures that name `$ROOT/.claude/...` are probing
# for a CONSUMER layout (`.claude/skills/ai-dlc-update/`) that this repository
# does not have; the `-f` test they guard on fails identically whether the
# directory is absent or holds those two files.

# The tools the suite shells out to. A hand-list, and the failure mode of a
# hand-list is stated rather than hidden: a tool upgraded in place that is NOT
# named here leaves a stale key valid. They are hashed AND version-probed because
# neither alone is sufficient -- /usr/bin/python3 on macOS is a stable shim over a
# toolchain that moves underneath it, and BSD `sed`/`awk` answer no --version.
TOOLS="bash sh grep sed awk python3 git jq xargs sort find shasum mktemp cmp diff"

# ---------------------------------------------------------------------------
# The included path set.
# ---------------------------------------------------------------------------

# Top-level entries, minus EXCLUDE. Git-ignored entries are dropped in the same
# pass that drops ignored paths deeper down, so this only has to prune the big
# ones early: without it `find` walks node_modules for nothing.
included_tops() {
  local e keep x
  for e in $(ls -A); do
    keep=1
    for x in $EXCLUDE; do [ "$e" = "$x" ] && keep=0; done
    [ "$keep" = 1 ] && printf '%s\n' "$e"
  done
}

# Every path under the included tops that git does not ignore.
#
# `git check-ignore --stdin --verbose --non-matching` answers for a whole list in
# ONE process. A path git ignores comes back with its source and pattern; a path
# it does not comes back with all three fields empty, i.e. a line starting `::`.
# Selecting on that prefix is the arm that keeps a path, so a git that failed to
# run keeps nothing -- and an empty set is caught by the zero guard below rather
# than hashing to a stable value over no files at all.
#
# NEVER READ THIS PIPELINE'S EXIT STATUS. `git check-ignore` exits 1 when NOTHING
# in its input was ignored, which is a perfectly ordinary tree -- and under
# `pipefail` that status became the pipeline's, so an earlier draft of this script
# read a clean small tree as a failed walk and refused to emit a key at all. The
# emptiness of the OUTPUT is the signal, and the caller's derived floor is what
# decides whether the walk was complete. This is the repo's standing "never read
# `$?` after a pipe" rule, met one layer out from where it usually bites.
included_paths() {
  local tops out
  tops="$(included_tops)"
  [ -n "$tops" ] || return 0
  # shellcheck disable=SC2086
  out="$(find $tops \( -type d -o -type f -o -type l \) -print 2>/dev/null \
         | git check-ignore --stdin --verbose --non-matching 2>/dev/null \
         | sed -n 's/^:://p' | sed 's/^\t//' \
         | LC_ALL=C sort)"
  printf '%s\n' "$out"
  return 0
}

# ---------------------------------------------------------------------------
# Components.
# ---------------------------------------------------------------------------

emit_components() {
  local paths n floor
  paths="$(included_paths)"
  n="$(printf '%s\n' "$paths" | grep -c . )"

  # THE ZERO GUARD, and its floor is DERIVED rather than a constant. A key over a
  # truncated walk is perfectly stable -- stable for the wrong reason -- and would
  # authorise a skip on a tree nobody hashed. The walk must therefore reach at
  # least every TRACKED file that is not under an excluded top: those are paths
  # git can independently prove exist, and the walk enumerates directories and
  # untracked files on top, so this is a floor and never an equality. A constant
  # here would be wrong in both directions -- it fails on a small tree that is
  # entirely correct, and it passes on a large one that lost half its walk.
  floor="$(git ls-files 2>/dev/null | while IFS= read -r f; do
             top="${f%%/*}"; skip=0
             for x in $EXCLUDE; do [ "$top" = "$x" ] && skip=1; done
             [ "$skip" = 0 ] && printf '%s\n' "$f"
           done | grep -c . )"
  if [ "${n:-0}" -lt "${floor:-0}" ]; then
    die "the included walk found ${n:-0} path(s) but git tracks ${floor:-0} file(s) outside the exclusion set. The walk is truncated, and a key over a truncated walk is stable for the wrong reason -- it would authorise a skip over files it never read. Fails closed."
  fi
  [ "${n:-0}" -gt 0 ] || die "the included walk found no paths at all. Fails closed rather than emitting a key that every tree would match."

  # 1. LISTING, not only contents. Several invariants fire on a directory that has
  #    NO rows in it at all, so a new EMPTY directory is an input and a contents
  #    hash alone cannot see one. Directories, files and symlinks all enumerated.
  printf '### listing\n'
  printf '%s\n' "$paths"

  # 2. THE EXECUTABLE BIT. v0.70.1 shipped a guard installed inert because a copy
  #    carried the bytes and not the mode. A mode change with no content change is
  #    a behavioural change and must move the key.
  printf '### exec\n'
  printf '%s\n' "$paths" | while IFS= read -r p; do
    [ -f "$p" ] && [ -x "$p" ] && printf '%s\n' "$p"
  done

  # 3. SYMLINK TARGETS. The listing sees the link; only this sees where it points.
  printf '### symlinks\n'
  printf '%s\n' "$paths" | while IFS= read -r p; do
    [ -L "$p" ] && printf '%s -> %s\n' "$p" "$(readlink "$p" 2>/dev/null)"
  done

  # 4. CONTENTS.
  printf '### contents\n'
  printf '%s\n' "$paths" | while IFS= read -r p; do
    [ -f "$p" ] && [ ! -L "$p" ] && printf '%s\0' "$p"
  done | xargs -0 shasum -a 256 2>/dev/null

  # 5. THE TRACKED PATH SET, and it is here because a fixture reads it.
  #    `ledger-status-vocabulary` builds its subject tree from `git ls-files`, so
  #    adding or removing a tracked path changes what that fixture examines even
  #    when the path itself is excluded above. This is the listing arm for the
  #    exclusion set: a new file under docs/ moves the key; editing one does not.
  printf '### tracked\n'
  git ls-files 2>/dev/null | LC_ALL=C sort

  # 6. THE FIXTURE SET, named explicitly even though core/ already covers it.
  #    The row's stated condition is that a hit is refused when the fixture SET
  #    changed; a component that is redundant today stays correct if core/fixtures
  #    is ever reorganised, and it costs one find.
  printf '### fixtures\n'
  find core/fixtures -mindepth 1 -maxdepth 1 -type d -print 2>/dev/null | LC_ALL=C sort

  # 7. THE `+`-DECLARED FILES, the one hole in EXCLUDE that a fixture opts INTO. A
  #    fixture whose verdict reads a file under an excluded top (this repo's own
  #    docs/backlog.md) declares it in its inputs.decl with a leading `+`, and the
  #    hook's READSET_KEYROWS span keys that fixture on the file. Without this
  #    component a push changing only such a file would match this key, skip the whole
  #    suite, and never reach the per-fixture key that names it.
  #    DERIVED FROM THE DECLARATIONS, never hand-listed: every `+` line of every
  #    core/fixtures/*/inputs.decl. A line carrying `+` and `!` together refuses the
  #    key, as the hook's parse refuses it (`plusbang`). Only
  #    the named files are hashed, never their top -- a plan edit under docs/ still
  #    matches. FAILS CLOSED: a `+` path that is absolute, carries `..`, names a
  #    directory, or is not a readable file refuses the key, so the caller runs the
  #    suite. A glob that matches no declaration contributes an empty section, which
  #    is the honest answer: no fixture opted in.
  #    A `+` file the fixture's section.decl narrows is hashed on that section alone, by readset_section and
  #    readset_section_of SOURCED from .githooks/pre-push's READSET_KEYROWS span (the per-fixture key's own pair), as
  #    `<sha256>  <path> <heading>`; a file any declarer keys whole is also hashed whole.
  printf '### keyed\n'
  local d kl kp kt p t tab kall us ka
  tab="$(printf '\t')"; kl=""; us="$(printf '\037')"; ka=""
  # ONE awk over every inputs.decl, each + line prefixed by its file and a US byte (one exec, not one per declarer).
  set -- core/fixtures/*/inputs.decl
  for d in "$@"; do [ -f "$d" ] && ka="${ka}${d}${us}"; done
  set --
  while [ -n "$ka" ]; do set -- "$@" "${ka%%"$us"*}"; ka="${ka#*"$us"}"; done
  kall=""
  if [ "$#" -gt 0 ]; then
    kall="$(awk -v us="$us" 'FNR == 1 { bad = 0 }
                 { sub(/\r$/, ""); x = 0; r = 0
                 while ((c = substr($0, 1, 1)) == "!" || c == "+") { if (c == "+") x = 1; else r = 1; $0 = substr($0, 2) }
                 if (x && r) { bad = 1; bf = FILENAME; exit }
                 if (x) print FILENAME us $0 }
               END { if (bad) { print "BAD" us bf; exit 3 } }' "$@")" || die "could not read an inputs.decl for its + declarations, or a line there carries + and ! together. Fails closed."
  fi
  for d in "$@"; do
    kp=""
    while IFS= read -r p; do
      case "$p" in "$d$us"*) kp="${kp}${p#"$d$us"}
" ;; esac
    done <<< "$kall"
    while [ "${kp%
}" != "$kp" ]; do kp="${kp%
}"; done
    [ -n "$kp" ] || continue
    if [ -f "${d%/inputs.decl}/section.decl" ]; then
      kt="$(sed -n '/^# READSET_KEYROWS_BEGIN$/,/^# READSET_KEYROWS_END$/p' .githooks/pre-push \
        | awk '/^readset_section(_of)?\(\) \{/ { on = 1 } on { print } on && /^}$/ { on = 0 }')"
      case "$kt" in *'readset_section() {'*'readset_section_of() {'*) ;; *) die "could not source readset_section and readset_section_of from .githooks/pre-push. Fails closed." ;; esac
      eval "$kt"
      while IFS= read -r p; do
        t="$(readset_section_of "${d%/inputs.decl}" "$p")"
        [ "$t" != '!' ] || die "${d%/inputs.decl}/section.decl names no # heading for '$p'. Fails closed."
        kl="${kl}${p}${t:+$tab}${t}
"
      done <<< "$kp"
    else
      kl="${kl}${kp}
"
    fi
  done
  kl="$(printf '%s' "$kl" | grep -v '^$' | LC_ALL=C sort -u)"
  if [ -n "$kl" ]; then
    while IFS="$tab" read -r p t; do
      case "$p" in
        /*|*/|..|../*|*/../*|*/..) die "a + declaration names '$p', which is not a root-relative file. Fails closed." ;;
      esac
      [ -f "$p" ] && [ -r "$p" ] || die "a + declaration names '$p', which is not a readable file here. Fails closed."
      if [ -n "$t" ]; then
        printf '%s  %s %s\n' "$(readset_section "$p" "$t" | shasum -a 256 | cut -d' ' -f1)" "$p" "$t"
      else
        shasum -a 256 -- "$p" 2>/dev/null || die "could not hash the + declared file '$p'. Fails closed."
      fi
    done <<< "$kl"
  fi

  # 8. THE HISTORY RANGES. Every `range` line of every core/fixtures/*/git.decl: fixture, `git-range:<n>` key and the
  #    row's HASH field, from readset_decl_ranges SOURCED from .githooks/pre-push's READSET_KEYROWS span (the per-fixture
  #    key's own function; no base or theirs sha, so this key moves exactly when that row does). Fails closed: an X row,
  #    or a span that cannot be found or loaded, refuses the key. The span is loaded only when a git.decl carries a range.
  printf '### ranges\n'
  local rg rf rrc rw rrows rfx
  set -- core/fixtures/*/git.decl
  rg=""
  for rf in "$@"; do [ -f "$rf" ] && rg="${rg}${rf}${us}"; done
  set --
  while [ -n "$rg" ]; do set -- "$@" "${rg%%"$us"*}"; rg="${rg#*"$us"}"; done
  rf=""
  if [ "$#" -gt 0 ]; then
    rf="$(grep -lE '^range( |$)' "$@" 2>/dev/null)"; rrc=$?
    [ "$rrc" -le 1 ] || die "could not scan the git.decl files for range lines. Fails closed."
  fi
  if [ -n "$rf" ]; then
    rw="$(mktemp -d "${TMPDIR:-/tmp}/sck-ranges.XXXXXX")" || die "could not make a scratch directory for the range rows. Fails closed."
    SCK_RW="$rw"
    sed -n '/^# READSET_KEYROWS_BEGIN$/,/^# READSET_KEYROWS_END$/p' .githooks/pre-push > "$rw/keyrows.sh" 2>/dev/null
    grep -q '^readset_decl_ranges() ' "$rw/keyrows.sh" || die "could not find readset_decl_ranges in .githooks/pre-push's READSET_KEYROWS span. Fails closed."
    . "$rw/keyrows.sh" || die "could not load the READSET_KEYROWS span of .githooks/pre-push. Fails closed."
    while IFS= read -r rf; do
      rfx="${rf%/git.decl}"; rfx="${rfx##*/}"
      rrows="$(readset_decl_ranges "$rfx" "${rf%/git.decl}" "$rw/w")" || die "readset_decl_ranges failed for $rfx. Fails closed."
      case "$rrows" in *"$tab"X"$tab"*) die "readset_decl_ranges refuses a range line of $rfx. Fails closed." ;; esac
      [ -n "$rrows" ] || die "readset_decl_ranges returned no row for $rfx, which carries a range line. Fails closed."
      printf '%s\n' "$rrows" | cut -f1,3,4
    done <<< "$rf"
    rm -rf "$rw"
    SCK_RW=""
  fi

  # 9. THE TOOLS. Identity, hash and version -- see TOOLS above for why all three.
  printf '### tools\n'
  # One shasum over every present tool (a shasum that did not answer for every path, or answered out of order,
  # falls back to one per tool); the first hash field and the first --version line are cut with builtins.
  local t p tp="" tl="" th="" tn=0 hi=0 hh v nl
  nl="
"
  set --
  for t in $TOOLS; do
    p="$(command -v "$t" 2>/dev/null)"
    [ -n "$p" ] || continue
    set -- "$@" "$p"; tn=$((tn + 1))
  done
  if [ "$tn" -gt 0 ]; then
    th="$(shasum -a 256 "$@" 2>/dev/null)"
    while IFS= read -r hh; do [ -z "$hh" ] || hi=$((hi + 1)); done <<< "$th"
    [ "$hi" = "$tn" ] || th=""
    hi=0
  fi
  [ -z "$th" ] || exec 3<<< "$th"
  for t in $TOOLS; do
    p="$(command -v "$t" 2>/dev/null)"
    if [ -z "$p" ]; then printf '%s ABSENT\n' "$t"; continue; fi
    hh=""
    if [ -n "$th" ]; then
      IFS= read -r hh <&3 || hh=""
      case "$hh" in *"  $p") hh="${hh%% *}" ;; *) hh="" ;; esac
    fi
    [ -n "$hh" ] || hh="$(shasum -a 256 "$p" 2>/dev/null | awk '{print $1}')"
    v="$("$t" --version 2>/dev/null)"
    printf '%s %s %s %s\n' "$t" "$p" "$hh" "${v%%"$nl"*}"
  done
  exec 3<&-
}

# ---------------------------------------------------------------------------

case "${1:-}" in
  --explain)
    emit_components; exit $? ;;
  --summary)
    # The tops are reported AFTER the ignore filter, not before it. Printing the
    # pre-filter list would name node_modules and .claude as covered when they are
    # not, and this text is what the pre-push announce shows an operator who is
    # deciding whether to trust a skip.
    _paths="$(included_paths)"
    printf 'included tops: %s\n' \
      "$(printf '%s\n' "$_paths" | awk -F/ 'NF{print $1}' | LC_ALL=C sort -u | tr '\n' ' ')"
    printf 'excluded:      %s\n' "$(printf '%s' "$EXCLUDE" | tr '\n' ' ' | sed 's/^ *//;s/ *$//')"
    printf 'ignored:       derived from .gitignore via git check-ignore\n'
    printf 'paths hashed:  %s\n' "$(printf '%s\n' "$_paths" | grep -c . )"
    printf 'tools:         %s\n' "$TOOLS"
    printf 'ranges:        each git.decl range line, keyed on its read-set hash (readset_decl_ranges)\n'
    exit 0 ;;
  "") : ;;
  *) die "usage: suite-content-key.sh [--explain|--summary]" ;;
esac

KEY="$(emit_components | shasum -a 256 | awk '{print $1}')" || die "key computation failed"
case "$KEY" in
  ????????????????????????????????????????????????????????????????) : ;;
  *) die "computed key is not a sha256 ('$KEY') -- refusing to emit a value a caller would compare against" ;;
esac
printf '%s\n' "$KEY"
}
[ "${BASH_SOURCE[0]}" = "$0" ] || return 0
sck_main "$@"
