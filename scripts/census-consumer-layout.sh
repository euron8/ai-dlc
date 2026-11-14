#!/bin/bash
# census-consumer-layout.sh -- the ONE-TIME consumer-layout census the push gate reuses (BL-1043).
#
#   bash scripts/census-consumer-layout.sh [--jobs N] [--pool <extracted FIXTURE_POOL span>]
#
# Run from the ROOT of a clean worktree detached at the exact sha to be pushed. It builds the consumer-layout
# tree the way the hook's suite step does (scripts/install.sh into a fresh scratch tree with `_bmad/` over the
# hook's fixed root commit, one commit), then drives the HOOK'S OWN cl_select, cl_publish and cl_write: the
# FIXTURE_POOL span is extracted from .githooks/pre-push at run time and sourced, so the keys, the selection and
# the records are the hook's and cannot drift from it. cl_select runs in `census` mode, the one mode that selects
# without an existing record; every selected unit runs as the pool runs `<fx>@consumer` (hermetic-run.sh --root
# <tree> for a declared fixture, its run.sh from the tree otherwise). EVERY PASS IS KEPT THE MOMENT IT HAPPENS, in
# the SHARED verdict store base (AI_DLC_VERDICT_STORE, default ~/.cache/ai-dlc/verdicts, never a counted-<vk>
# store): hermetic-run.sh writes a declared unit's store entry, and cl_publish its placement record under
# <base>/consumer-placement-keys/<repository root commit>. A unit that fails gets neither, so the next run runs it.
# `--pool` sources the span from that file instead; core/fixtures/prepush-pool-depth drives its mutated spans
# through it.
#
# WHY IT EXISTS: a push never runs every shipping fixture in the consumer layout. With no record at all the
# hook FAILs its consumer-layout step and names this script; after it, a push runs only the units whose
# installed inputs moved. Re-running it is safe, and so is stopping it: a unit already recorded at these inputs
# is not selected again, from this clone or any other.
#
# Output: the tree, the selection line cl_select prints, one `<fx>@consumer ok|FAIL` line per unit run, and a
# summary. Exit 0 when every selected unit passed, 1 on any red (each named), 2 on a refusal (wrong cwd, dirty
# tree, the span not extractable, the install failed, the keys could not be built).
set -u
jobs=4; pool=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --jobs) jobs="${2:-}"; shift 2 || { echo "census-consumer-layout: --jobs needs a value" >&2; exit 2; } ;;
    --pool) pool="${2:-}"; shift 2 || { echo "census-consumer-layout: --pool needs a file" >&2; exit 2; } ;;
    *) echo "usage: bash scripts/census-consumer-layout.sh [--jobs N] [--pool <span file>]" >&2; exit 2 ;;
  esac
done
case "$jobs" in ''|*[!0-9]*|0) echo "census-consumer-layout: --jobs must be a positive integer" >&2; exit 2 ;; esac
HOOK="$PWD/.githooks/pre-push"
[ -f "$HOOK" ] && [ -f "$PWD/scripts/install.sh" ] \
  || { echo "census-consumer-layout: run from the root of a worktree (no .githooks/pre-push or scripts/install.sh here)" >&2; exit 2; }
st="$(git status --porcelain)" || { echo "census-consumer-layout: git status failed" >&2; exit 2; }
[ -z "$st" ] || { echo "census-consumer-layout: worktree is dirty; run from a clean worktree detached at the pushed sha" >&2; exit 2; }
work="$(mktemp -d "${TMPDIR:-/tmp}/clcensus.XXXXXX")" || exit 2
tree="$(mktemp -d /tmp/cl.XXXXXX)" || exit 2
cleanup() { rm -rf -- "$work" "$tree"; }
trap cleanup EXIT; trap 'exit 130' INT; trap 'exit 143' TERM
if [ -n "$pool" ]; then cp "$pool" "$work/pool.sh" || { echo "census-consumer-layout: cannot read --pool $pool" >&2; exit 2; }
else sed -n '/^# FIXTURE_POOL_BEGIN$/,/^# FIXTURE_POOL_END$/p' "$HOOK" > "$work/pool.sh"; fi
grep -q '^cl_select() ' "$work/pool.sh" && grep -q '^cl_write() ' "$work/pool.sh" && grep -q '^cl_tree_init() ' "$work/pool.sh" \
  || { echo "census-consumer-layout: could not extract cl_select and cl_write from ${pool:-$HOOK}" >&2; exit 2; }
# The tree, as the hook's suite step builds it.
# shellcheck disable=SC1090
. "$work/pool.sh" > /dev/null 2>&1
unset PREPUSH_POOL_DEPTH; POOL_DEPTH_IN=0
# The hook's own cl_tree_init: its fixed root commit is the one consumer project id, so the store entries written
# here are the ones a push reads.
if ! { mkdir "$tree/_bmad" && cl_tree_init "$tree"; } > /dev/null 2>&1; then
  echo "census-consumer-layout: git init $tree failed" >&2; exit 2
fi
if ! bash scripts/install.sh "$tree" > "$work/install.log" 2>&1; then
  echo "census-consumer-layout: scripts/install.sh $tree failed:" >&2; tail -n 5 "$work/install.log" >&2; exit 2
fi
if ! { git -C "$tree" add -A && GIT_AUTHOR_NAME=ai-dlc GIT_AUTHOR_EMAIL=ai-dlc@invalid GIT_COMMITTER_NAME=ai-dlc \
    GIT_COMMITTER_EMAIL=ai-dlc@invalid GIT_AUTHOR_DATE=2000-01-01T00:00:00Z GIT_COMMITTER_DATE=2000-01-01T00:00:00Z \
    git -C "$tree" -c commit.gpgsign=false commit -q --no-verify -m 'consumer-layout tree'; } > /dev/null 2>&1; then
  echo "census-consumer-layout: the tree's commit failed" >&2; exit 2
fi
echo "tree: $tree"
out="$work/out"; mkdir -p "$out" || exit 2
cl_tree="$tree"
cl_select "$out" census
if [ -s "$out/.cl.refused" ]; then echo "census-consumer-layout: $(sed -n 1p "$out/.cl.refused")" >&2; exit 2; fi
# Each selected unit, as the pool runs `<fx>@consumer`: from the tree, with its own TMPDIR and a scratch store.
mkdir -p "$out/.log" || exit 2
cat > "$work/unit.sh" <<'UNIT'
#!/bin/bash
ct="$1"; out="$2"; cf="$3"; t="$(mktemp -d /tmp/cu.XXXXXX)" || exit 0
if [ -f "$ct/tests/fixtures/$cf/inputs.decl" ]; then set -- bash "$ct/scripts/ai-dlc/hermetic-run.sh" --root "$ct" "$cf"
else set -- bash "tests/fixtures/$cf/run.sh"; fi
cs=""; read -r cs < "$out/.cl.store"
if [ -n "$cs" ] && ( cd "$ct" && TMPDIR="$t" env -u FXCOUNT_RC -u FXCOUNT_DIR -u FXCOUNT_JUDGE -u AI_DLC_FX_CL_TREE -u PREPUSH_POOL_DEPTH \
     AI_DLC_VERDICT_STORE="$cs" "$@" ) < /dev/null > "$out/.log/$cf@consumer" 2>&1; then v=ok; else v=FAIL; fi
printf '%s' "$v" > "$out/$cf@consumer"
# A PASS IS KEPT THE MOMENT IT HAPPENS: the hook's own cl_publish, as cl_select wrote it, never batched for the end.
[ "$v" != ok ] || { . "$out/.cl.pub" && cl_publish "$out" "$cf"; }
printf '%s@consumer %s\n' "$cf" "$v"
rm -rf -- "$t"
UNIT
tr '\n' '\000' < "$out/.cl.sel" | xargs -0 -n 1 -P "$jobs" bash "$work/unit.sh" "$tree" "$out"
n_sel="$(grep -c . "$out/.cl.sel")" || n_sel=0
n_ok=0; n_fail=0; n_none=0; reds=""
while IFS= read -r b; do
  [ -n "$b" ] || continue
  case "$(cat "$out/$b@consumer" 2>/dev/null)" in
    ok) n_ok=$((n_ok + 1)) ;;
    FAIL) n_fail=$((n_fail + 1)); reds="$reds $b" ;;
    *) n_none=$((n_none + 1)); reds="$reds $b(no verdict)" ;;
  esac
done < "$out/.cl.sel"
cl_write "$out"
kd="$(cat "$out/.cl.keys")"; n_rec=0
for f in "$kd"/*.key; do [ -f "$f" ] && n_rec=$((n_rec + 1)); done
echo "census: $n_sel unit(s) run, $n_ok passed and recorded, $n_fail failed, $n_none gave no verdict; $n_rec record(s) now in $kd"
if [ -n "$reds" ]; then
  echo "census: no record for:$reds"
  for b in $reds; do b="${b%(no verdict)}"; echo "--- $b@consumer (last 8 lines)"; tail -n 8 "$out/.log/$b@consumer" 2>/dev/null; done
  exit 1
fi
exit 0
