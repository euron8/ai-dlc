#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
# smoke-surface-ignored/run.sh -- BL-845's SMOKE-SURFACE-IGNORED arm of validate-handoff-evidence.sh (its header names
# it): a surface path that is no blob at <base> and that the `.gitignore` blobs committed at <base> ignore prints
# `WARN smoke-surface-ignored ...` right before the byte-identical `SKIP SMOKE-SURFACE (undeclared: ...)`, exit
# unchanged. Split out of story-evidence-scaffold (the suite pole) so the pool runs it beside that fixture.
#
# THE SUBJECT IS ASKED IN PROCESS: story-evidence-scaffold/he-inproc.sh's he_run sources the validator in a subshell
# (no bash start), from a copy of the whole scripts directory plus the sprint-status schema, so a mutant written
# beside record-only-diff.sh finds every sibling the real one does.
#
# WORLDS, each one git repository with a <base> and a <frozen> commit, a UI diff and an empty smoke section. Every
# frozen story carries `status: review`, both labels and a Dev Agent Record citing the untracked capture
# `evidence/cn-never.out`, so the handoff exit is the smoke arms' verdict alone, and handoff mode asks
# ignored_at_frozen BEFORE smoke_arms (the frozen-first order; --smoke asks <base> alone, base-first).
#   ig    root `*.txt`, the surface on disk and untracked                        -> WARN (.gitignore:1:*.txt)
#   nig   root `*.log` (a chain .gitignore that matches nothing)                 -> quiet
#   trk   root `*.txt`, the surface force-added at base                          -> no SKIP, no WARN, SMOKE OK
#   dB    base's docs/.gitignore ignores it, the range deletes that file          -> WARN (follows base)
#   dF    the range ADDS that docs/.gitignore                                     -> quiet (follows base)
#   nest  docs/.gitignore alone                                                  -> WARN, `!smoke-surface.txt` in docs/.gitignore
#   neg   root `*.txt` + `!docs/smoke-surface.txt` (check-ignore -v answers 0 on it, -q does not) -> quiet
#   dirx  root `docs/` + `!docs/smoke-surface.txt`                               -> WARN offering NO negation
#   ovr   consumer_smoke_surface_file: docs/ui-surface.txt, only that path ignored -> WARN and SKIP name the override
#   ovrn  the same declaration, only the default path ignored                    -> quiet
#   unr   ig's ignore set with its .gitignore BLOB deleted at base              -> one gitignore-unreadable WARN, no smoke-surface-ignored
#   dstar  root `docs/*` (the directory's contents, not the directory)           -> WARN offering `!docs/smoke-surface.txt` in .gitignore
#   dstarn root `docs/*` + `!docs/smoke-surface.txt` (dstar's remedy applied)    -> quiet: the offered negation re-includes the file
#   deep   consumer_smoke_surface_file: docs/sub/surf.txt, root `docs/` (two ancestors, the outer one excluded) -> WARN, NO negation
#   deepok the same declaration, root `*.txt` (no ancestor excluded)            -> WARN offering `!docs/sub/surf.txt` in .gitignore
# ROWS. Every world runs in --smoke and in handoff mode from its top level. ig also runs from its web/ subdirectory and
# from a linked worktree at <frozen> (no ignored file on disk), with no -C: the cwd-invariance rows. A row asserts the
# exit (0), the exact SKIP line, the exact WARN as the line right before it (or no smoke-surface-ignored line), no
# gitignore-unreadable line outside unr, no shell error text, and in handoff mode the exact capture-unresolved line
# before the smoke lines (ignored_at_frozen ran first).
# ARMS, each a firing world and a quiet near-miss (so each fails on a validator without the WARN):
#   ig-a ig+nig   ig-c trk+ig   ig-d dB+dF   ig-e nest+neg+dirx   ig-f ovr+ovrn   ig-u unr+ig
#   ig-g dstar+dstarn+deep+deepok (the excluded-ancestor walk: each ancestor asked alone, with no trailing slash)
#
# THE MUTATION BATTERY IS NOT HERE. It edits copies of core's own validator, so it is distribution-only and lives in
# smoke-surface-ignored-mutants (a `.dist-only` fixture), which SOURCES this file: everything above the arm loop
# (worlds, runworlds, rowfail, armfail, ARMS, the control tree) is defined, and the BASH_SOURCE guard below returns
# to it before this file runs its own arms. A consumer runs the arms; only the distribution scores the mutants.
#
# Exit: 0 every arm passed, 1 an arm failed, 2 the fixture could not run.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HEI="$DIR/../story-evidence-scaffold/he-inproc.sh"
[ -f "$HEI" ] || { echo "smoke-surface-ignored: FIXTURE BROKEN -- $HEI is absent" >&2; exit 2; }
# shellcheck source=/dev/null
. "$HEI" || { echo "smoke-surface-ignored: FIXTURE BROKEN -- cannot source $HEI" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/fixtures/story-evidence-scaffold/he-inproc.sh"
HE=""
for cand in "$DIR/../../scripts/validate-handoff-evidence.sh" "$DIR/../../../scripts/ai-dlc/validate-handoff-evidence.sh"; do
  [ -f "$cand" ] && { HE="$cand"; break; }
done
SCHEMA=""
for cand in "$DIR/../../schemas/sprint-status.json" "$DIR/../../../.claude/schemas/sprint-status.json"; do
  [ -f "$cand" ] && { SCHEMA="$cand"; break; }
done
{ [ -n "$HE" ] && [ -n "$SCHEMA" ] && [ -f "$(dirname "$HE")/record-only-diff.sh" ] && [ -f "$(dirname "$HE")/sprint-status.sh" ]; } \
  || { echo "smoke-surface-ignored: FIXTURE BROKEN -- validate-handoff-evidence.sh, its record-only-diff.sh / sprint-status.sh siblings or the sprint-status schema is absent in both layouts. An absent subject is not a passing one." >&2; exit 2; }
for p in scripts/validate-handoff-evidence.sh scripts/record-only-diff.sh scripts/sprint-status.sh; do echo "HERMETIC-CONSUMED core/$p"; done
WORK="$(mktemp -d "${TMPDIR:-/tmp}/smoke-surface-ignored.XXXXXX")" || exit 2
trap 'rm -rf "$WORK"' EXIT
rc=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1" >&2; rc=1; }
# The control tree: the whole scripts directory and the schema, laid out as the shipped one is.
T="$WORK/tree/core"
mkdir -p "$T/scripts" "$T/schemas" && cp -R "$(dirname "$HE")/." "$T/scripts/" && cp "$SCHEMA" "$T/schemas/sprint-status.json" \
  && [ -f "$T/scripts/record-only-diff.sh" ] || { echo "smoke-surface-ignored: FIXTURE BROKEN -- the control tree could not be built" >&2; exit 2; }
HECTL="$T/scripts/validate-handoff-evidence.sh"

# --- worlds -------------------------------------------------------------------------------------------------------
R="$WORK/worlds"; W=""
g() { GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -C "$W" -c user.name=r -c user.email=r@example.invalid \
  -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@"; }
SURF='# graph UI tree
web/src/**'
STORY_HEAD=$'---\nstatus: review\n---\n'
STORY_TAIL="$(printf '\nFull-collection run: `pytest -q` from the root, 1 passed.\nDependency setup: none, system pytest.\n\n## Dev Agent Record\n\nLocal run: `evidence/cn-never.out`.')"
LC_OVR="$(printf 'contract_version: 1\nconsumer_smoke_surface_file: docs/ui-surface.txt')"
LC_DEEP="$(printf 'contract_version: 1\nconsumer_smoke_surface_file: docs/sub/surf.txt')"
# seed <world> <surface on disk at base, or -> ; SEED_GI / SEED_DGI: a root / docs .gitignore committed at base;
# SEED_FORCE: the surface `git add -f`ed past them; SEED_LC: a layer contract; SEED_ALT: the override surface on disk.
seed() {
  W="$R/$1"; mkdir -p "$W/web/src" "$W/docs" "$W/stories" || return 1
  g init -q || return 1
  printf 'a\n' > "$W/web/src/app.js"
  [ "$2" = - ] || printf '%s\n' "$2" > "$W/docs/smoke-surface.txt"
  if [ -n "${SEED_GI:-}" ]; then printf '%s\n' "$SEED_GI" > "$W/.gitignore" || return 1; fi
  if [ -n "${SEED_DGI:-}" ]; then printf '%s\n' "$SEED_DGI" > "$W/docs/.gitignore" || return 1; fi
  if [ -n "${SEED_LC:-}" ]; then mkdir -p "$W/.claude/skills/ai-dlc" && printf '%s\n' "$SEED_LC" > "$W/.claude/skills/ai-dlc/layer-contract.yaml" || return 1; fi
  if [ -n "${SEED_ALT:-}" ]; then printf '%s\n' "$SEED_ALT" > "$W/docs/ui-surface.txt" || return 1; fi
  printf '# Story\n\n## Smoke Test Updates\n\n## Rename Verification\n\nnot a rename\n' > "$W/stories/s.md"
  g add -A && { [ -z "${SEED_FORCE:-}" ] || g add -f docs/smoke-surface.txt; } && g commit -qm base || return 1
  g rev-parse HEAD > "$W/.B"
  printf 'b\n' > "$W/web/src/app.js"
  printf '%s# Story\n\n## Smoke Test Updates\n\n%s\n\n## Rename Verification\n\nnot a rename\n%s' "$STORY_HEAD" "${SEED_BODY:-}" "$STORY_TAIL" > "$W/stories/s.md"
}
fin() { g add -A && g commit -qm frozen && g rev-parse HEAD > "$W/.T"; }
sok=1
SEED_GI='*.txt' seed ig "$SURF" && fin || sok=0
SEED_GI='*.log' seed nig - && fin || sok=0
mkdir -p "$R/trk/web/tests" && printf 'a1\n' > "$R/trk/web/tests/a.spec.js" || sok=0
SEED_GI='*.txt' SEED_FORCE=1 SEED_BODY='- `web/tests/a.spec.js` (modified)' seed trk "$SURF" && printf 'a2\n' > "$W/web/tests/a.spec.js" && fin || sok=0
SEED_GI='*.log' SEED_DGI='smoke-surface.txt' seed dB - && rm -f "$W/docs/.gitignore" && fin || sok=0
SEED_GI='*.log' seed dF - && printf 'smoke-surface.txt\n' > "$W/docs/.gitignore" && fin || sok=0
SEED_DGI='smoke-surface.txt' seed nest "$SURF" && fin || sok=0
SEED_GI="$(printf '*.txt\n!docs/smoke-surface.txt')" seed neg - && fin || sok=0
SEED_GI="$(printf 'docs/\n!docs/smoke-surface.txt')" seed dirx "$SURF" && fin || sok=0
SEED_LC="$LC_OVR" SEED_ALT="$SURF" SEED_GI='docs/ui-surface.txt' seed ovr - && fin || sok=0
SEED_LC="$LC_OVR" SEED_GI='docs/smoke-surface.txt' seed ovrn - && fin || sok=0
SEED_GI='*.txt' seed unr - && fin || sok=0
SEED_GI='docs/*' seed dstar "$SURF" && fin || sok=0
SEED_GI="$(printf 'docs/*\n!docs/smoke-surface.txt')" seed dstarn - && fin || sok=0
SEED_LC="$LC_DEEP" SEED_GI='docs/' seed deep - && fin || sok=0
SEED_LC="$LC_DEEP" SEED_GI='*.txt' seed deepok - && fin || sok=0
W="$R/ig"; [ "$sok" = 1 ] && g worktree add -q --detach "$R/ig.wt" "$(cat "$W/.T")" || sok=0
W="$R/unr"; [ "$sok" = 1 ] && o="$(g rev-parse "$(cat "$W/.B"):.gitignore")" && rm -f "$W/.git/objects/${o:0:2}/${o:2}" || sok=0
[ "$sok" = 1 ] || { echo "smoke-surface-ignored: FIXTURE BROKEN -- a world could not be seeded" >&2; exit 2; }
WORLDS="ig nig trk dB dF nest neg dirx ovr ovrn unr dstar dstarn deep deepok"
igsurf() { case "$1" in ovr|ovrn) echo docs/ui-surface.txt ;; deep|deepok) echo docs/sub/surf.txt ;; *) echo docs/smoke-surface.txt ;; esac; }
# Seed controls: the surface is no blob at <base> (tracked in trk); the ignored file is on disk in ig and not in its
# worktree; dB/dF really differ in their ignore sets; unr's .gitignore is named by the tree and unreadable.
for c in $WORLDS; do
  W="$R/$c"; B="$(cat "$W/.B")"; TT="$(cat "$W/.T")"; p="$(igsurf "$c")"
  if [ "$c" = trk ]; then g cat-file -e "$B:$p" || { echo "smoke-surface-ignored: FIXTURE BROKEN -- trk's surface is not tracked at base" >&2; exit 2; }
  else ! g cat-file -e "$B:$p" 2>/dev/null || { echo "smoke-surface-ignored: FIXTURE BROKEN -- $c's surface is a blob at base" >&2; exit 2; }; fi
  case "$c" in
    ig) { [ -f "$W/$p" ] && [ -f "$R/ig.wt/.git" ] && [ ! -e "$R/ig.wt/$p" ]; } || { echo "smoke-surface-ignored: FIXTURE BROKEN -- ig's ignored surface is not on disk, or is in its worktree" >&2; exit 2; } ;;
    dB) { g cat-file -e "$B:docs/.gitignore" && ! g cat-file -e "$TT:docs/.gitignore" 2>/dev/null; } || { echo "smoke-surface-ignored: FIXTURE BROKEN -- dB's docs/.gitignore is not base-only" >&2; exit 2; } ;;
    dF) { ! g cat-file -e "$B:docs/.gitignore" 2>/dev/null && g cat-file -e "$TT:docs/.gitignore"; } || { echo "smoke-surface-ignored: FIXTURE BROKEN -- dF's docs/.gitignore is not frozen-only" >&2; exit 2; } ;;
    unr) { g rev-parse -q --verify "$B:.gitignore" >/dev/null && ! g show "$B:.gitignore" >/dev/null 2>&1; } || { echo "smoke-surface-ignored: FIXTURE BROKEN -- unr's base .gitignore is not a named, unreadable blob" >&2; exit 2; } ;;
  esac
done

# --- rows -----------------------------------------------------------------------------------------------------------
armworlds() { case "$1" in ig-a) echo "ig nig" ;; ig-c) echo "trk ig" ;; ig-d) echo "dB dF" ;; ig-e) echo "nest neg dirx" ;; ig-f) echo "ovr ovrn" ;; ig-u) echo "unr ig" ;; ig-g) echo "dstar dstarn deep deepok" ;; esac; }
worldrows() { if [ "$1" = ig ]; then echo "top sub wt"; else echo top; fi; }
# runworlds <script> <arms...>: one run per (world, row, mode) the arms read, held in IGO_/IGR_ variables (no files).
runworlds() {
  local s="$1" a c l m d o rc done=" "; shift
  for a in "$@"; do
    for c in $(armworlds "$a"); do
      case "$done" in *" $c "*) continue ;; esac; done="$done$c "
      for l in $(worldrows "$c"); do
        case "$l" in top) d="$R/$c" ;; sub) d="$R/$c/web" ;; *) d="$R/$c.wt" ;; esac
        for m in s h; do
          if [ "$m" = s ]; then o="$(cd "$d" && he_run "$s" --smoke stories/s.md "$(cat "$R/$c/.B")" "$(cat "$R/$c/.T")" 2>&1)"; rc=$?
          else o="$(cd "$d" && he_run "$s" stories/s.md "$(cat "$R/$c/.B")" "$(cat "$R/$c/.T")" 2>&1)"; rc=$?; fi
          eval "IGO_${c}_${l}_$m=\$o; IGR_${c}_${l}_$m=\$rc"
        done
      done
    done
  done
}
# igwarn <world> -> the exact WARN a firing world prints (empty for a quiet one), in the shipped wording: `git add -f`
# always, and a negation relative to the matching .gitignore only when no directory above the surface is excluded.
igwarn() {
  local c="$1" p prov fix b12
  p="$(igsurf "$c")"; b12="$(cut -c1-12 "$R/$c/.B")"
  case "$c" in
    ig)      prov='.gitignore:1:*.txt';                  fix="\`git add -f $p\` or un-ignore it (\`!$p\` in .gitignore)" ;;
    dB|nest) prov='docs/.gitignore:1:smoke-surface.txt'; fix="\`git add -f $p\` or un-ignore it (\`!smoke-surface.txt\` in docs/.gitignore)" ;;
    dirx)    prov='.gitignore:1:docs/';                  fix="\`git add -f $p\` (a directory above it is excluded, so no negation can re-include it)" ;;
    ovr)     prov='.gitignore:1:docs/ui-surface.txt';    fix="\`git add -f $p\` or un-ignore it (\`!$p\` in .gitignore)" ;;
    dstar)   prov='.gitignore:1:docs/*';                 fix="\`git add -f $p\` or un-ignore it (\`!$p\` in .gitignore)" ;;
    deep)    prov='.gitignore:1:docs/';                  fix="\`git add -f $p\` (a directory above it is excluded, so no negation can re-include it)" ;;
    deepok)  prov='.gitignore:1:*.txt';                  fix="\`git add -f $p\` or un-ignore it (\`!$p\` in .gitignore)" ;;
    *) return 0 ;;
  esac
  printf "WARN smoke-surface-ignored stories/s.md: %s is not tracked at %s and the .gitignore committed there ignores it (%s); smoke-not-updated cannot run until it is committed: %s and commit it outside a story's range" "$p" "$b12" "$prov" "$fix"
}
# rowfail <world> <row> <mode> -> the row's defects on stdout (empty: the row passed)
rowfail() {
  local c="$1" l="$2" m="$3" o rc wl sk ns nw nc t12 b12 bad=""
  eval "o=\$IGO_${c}_${l}_$m; rc=\$IGR_${c}_${l}_$m"
  wl="$(igwarn "$c")"; t12="$(cut -c1-12 "$R/$c/.T")"; b12="$(cut -c1-12 "$R/$c/.B")"
  sk="SKIP SMOKE-SURFACE (undeclared: no $(igsurf "$c") at $b12)"
  [ "$rc" -eq 0 ] || bad="$bad exit $rc (want 0);"
  if [ "$c" = trk ]; then
    grep -q '^SKIP SMOKE-SURFACE' <<<"$o" && bad="$bad a SKIP SMOKE-SURFACE line for a tracked surface;"
    ns="$(grep -n '^SMOKE OK ' <<<"$o" | head -n 1 | cut -d: -f1)"
    [ -n "$ns" ] || bad="$bad no SMOKE OK;"
  else
    ns="$(grep -nxF -- "$sk" <<<"$o" | head -n 1 | cut -d: -f1)"
    [ -n "$ns" ] || bad="$bad no exact [$sk];"
  fi
  if [ -n "$wl" ]; then
    nw="$(grep -nxF -- "$wl" <<<"$o" | head -n 1 | cut -d: -f1)"
    if [ -z "$nw" ]; then bad="$bad no exact smoke-surface-ignored WARN;"
    elif [ -n "$ns" ] && [ "$nw" -ne $((ns - 1)) ]; then bad="$bad the WARN (line $nw) is not the line right before the SKIP (line $ns);"; fi
  else
    grep -q '^WARN smoke-surface-ignored' <<<"$o" && bad="$bad a smoke-surface-ignored WARN on a quiet world;"
  fi
  if [ "$c" = unr ]; then
    nw="$(grep -nxF -- "WARN gitignore-unreadable $b12: smoke-surface ignore set unknown" <<<"$o" | cut -d: -f1)"
    if [ -z "$nw" ] || [ "$nw" != "${nw%%[!0-9]*}" ]; then bad="$bad not exactly one gitignore-unreadable WARN for <base>;"
    elif [ -n "$ns" ] && [ "$nw" -ne $((ns - 1)) ]; then bad="$bad the unreadable WARN is not the line right before the SKIP;"; fi
  else
    grep -q '^WARN gitignore-unreadable' <<<"$o" && bad="$bad a gitignore-unreadable WARN;"
  fi
  grep -qE 'unbound variable|command not found|No such file or directory' <<<"$o" && bad="$bad shell error text;"
  if [ "$m" = h ]; then
    nc="$(grep -nxF "WARN capture-unresolved evidence/cn-never.out: not tracked at $t12" <<<"$o" | head -n 1 | cut -d: -f1)"
    if [ -z "$nc" ]; then bad="$bad no capture-unresolved line (ignored_at_frozen never ran first);"
    elif [ -n "$ns" ] && [ "$nc" -ge "$ns" ]; then bad="$bad the capture line is not before the smoke lines;"; fi
  fi
  printf '%s' "$bad"
}
# armfail <arm> -> one `<world>/<row>/<mode>: <defects>` line per failing row (empty: the arm passed)
armfail() {
  local a="$1" c l m f
  for c in $(armworlds "$a"); do for l in $(worldrows "$c"); do for m in s h; do
    f="$(rowfail "$c" "$l" "$m")"; [ -z "$f" ] || printf '%s/%s/%s:%s\n' "$c" "$l" "$m" "$f"
  done; done; done
}
ARMS="ig-a ig-c ig-d ig-e ig-f ig-u ig-g"

# Sourced by smoke-surface-ignored-mutants: hand it the worlds and the arm functions, and run nothing further here.
if [ "${BASH_SOURCE[0]}" != "$0" ]; then return 0; fi

echo "smoke-surface-ignored:"
runworlds "$HECTL" $ARMS
for a in $ARMS; do
  f="$(armfail "$a")"
  if [ -z "$f" ]; then ok "$a: the unmutated validator answers every row of $(armworlds "$a" | tr ' ' '+')"
  else bad "$a: the unmutated validator: $(tr '\n' ' ' <<<"$f")"; fi
done
if [ "$rc" = 0 ]; then echo "PASS smoke-surface-ignored"; else echo "FAIL smoke-surface-ignored"; fi
exit "$rc"
