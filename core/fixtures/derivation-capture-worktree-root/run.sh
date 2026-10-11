#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# derivation-capture-worktree-root/run.sh — a ```derived block written in a LINKED WORKTREE of the
# project is judged against that worktree's files, not the main tree's.
#
# THE DEFECT. ai-dlc-derivation-capture.sh handed the validator AI_DLC_PROJECT_ROOT=$PROJECT_DIR,
# and the validator runs every fence command from that root. A dev seat edits its story file in a
# linked worktree, so the hook evaluated the worktree's fences against the MAIN tree: measured on
# the reference consumer, one `grep -c` read 6 from the main tree and 8 from the worktree, and the
# write was refused for an output that was right. One file, two verdicts, chosen by cwd.
#
# THE DISCRIMINATING SEED. `data.txt` carries one `alpha` line in the main tree and three in the
# worktree, so `grep -c alpha data.txt` recorded as 3 reproduces ONLY in the worktree. A seed where
# both trees agree would pass under the defect and prove nothing; arm C0 asserts they disagree.
#
# WHY THE ANTI-STUB ARM. Every "the hook exits 0" arm passes against a hook replaced by `exit 0`.
# A2 writes a file whose two touched pairs are the tree-dependent one and a pair stale in BOTH
# trees, and requires exit 2 naming ONLY the second. A stub fails it (no exit 2); the defect fails
# it (names both). The mutant arms then revert the fix inside a copy of the hook and require a kill.
#
# WHY THE NESTED-REPO ARM. A file in a nested repository (or a submodule) under the project is
# NOT another checkout of the project, and its fences keep the project root. The fix accepts the
# file's toplevel only when its git common dir is the project's; M2 deletes that check and must be
# killed by A4.
set -uo pipefail

# The pre-push gate exports every AI_DLC_* tunable a consumer set into this process. Scrub them so
# the hook and the validator run on their own defaults (I10).
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
[ -n "$ROOT" ] || { echo "FIXTURE ERROR: cannot resolve a root from $HERE" >&2; exit 2; }
# Both layouts, each resolved on its own (never by walking from one core file to another, I33).
if [ -f "$ROOT/core/hooks/ai-dlc-derivation-capture.sh" ]; then
  SRC_HOOK="$ROOT/core/hooks/ai-dlc-derivation-capture.sh"
  echo "HERMETIC-CONSUMED core/hooks/ai-dlc-derivation-capture.sh"
elif [ -f "$ROOT/.claude/hooks/ai-dlc-derivation-capture.sh" ]; then
  SRC_HOOK="$ROOT/.claude/hooks/ai-dlc-derivation-capture.sh"
  echo "HERMETIC-CONSUMED .claude/hooks/ai-dlc-derivation-capture.sh"
else
  echo "FIXTURE ERROR: ai-dlc-derivation-capture.sh not found in either layout" >&2; exit 2
fi
if [ -f "$ROOT/core/scripts/validate-artifact-derivations.sh" ]; then
  SRC_VALIDATOR="$ROOT/core/scripts/validate-artifact-derivations.sh"
  echo "HERMETIC-CONSUMED core/scripts/validate-artifact-derivations.sh"
elif [ -f "$ROOT/scripts/ai-dlc/validate-artifact-derivations.sh" ]; then
  SRC_VALIDATOR="$ROOT/scripts/ai-dlc/validate-artifact-derivations.sh"
  echo "HERMETIC-CONSUMED scripts/ai-dlc/validate-artifact-derivations.sh"
else
  echo "FIXTURE ERROR: validate-artifact-derivations.sh not found in either layout" >&2; exit 2
fi
command -v jq  >/dev/null 2>&1 || { echo "FIXTURE ERROR: jq is required to build payloads" >&2; exit 2; }
command -v git >/dev/null 2>&1 || { echo "FIXTURE ERROR: git is required to build the worktrees" >&2; exit 2; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/derivcap-wt.XXXXXX")" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# Physical: git reports physical toplevels, and the hook compares them.
WORK="$(cd "$WORK" && pwd -P)"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails + 1)); }
broken() { echo "FIXTURE BROKEN: $1" >&2; exit 2; }

g() { # g <dir> <git args...> -- hermetic identity, no hooks, no signing
  local d="$1"; shift
  git -C "$d" -c user.name=fixture -c user.email=fixture@example.invalid \
    -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@"
}

# build_main <dir>: a consumer-layout project repo with the hook and validator installed.
build_main() {
  local m="$1"
  mkdir -p "$m/.claude/hooks" "$m/scripts/ai-dlc" "$m/notes" || return 1
  cp "$SRC_HOOK" "$m/.claude/hooks/ai-dlc-derivation-capture.sh" || return 1
  cp "$SRC_VALIDATOR" "$m/scripts/ai-dlc/validate-artifact-derivations.sh" || return 1
  printf 'alpha\nbeta\n' > "$m/data.txt"
  printf 'one\n' > "$m/fixed.txt"
  printf '0.0.0\n' > "$m/VERSION"
  # Tracked, so notes/ exists in every worktree checked out from this commit.
  printf 'notes\n' > "$m/notes/README"
  g "$m" init -q 2>/dev/null || return 1
  [ -d "$m/.git" ] || return 1
  g "$m" add -A && g "$m" commit -qm base || return 1
}
# add_wt <main> <wt path>: a linked worktree whose data.txt carries THREE alpha lines.
add_wt() {
  local m="$1" w="$2"
  g "$m" worktree add -q -b "story-$(basename "$w")" "$w" 2>/dev/null || return 1
  [ -f "$w/.git" ] && [ -d "$w/notes" ] || return 1
  printf 'alpha\nalpha\nalpha\nbeta\n' > "$w/data.txt"
  g "$w" add -A && g "$w" commit -qm story || return 1
}

MAIN="$WORK/a/main"; WT_OUT="$WORK/a/wt-out"
build_main "$MAIN" || broken "could not build the main repository at $MAIN"
add_wt "$MAIN" "$WT_OUT" || broken "could not add the outside worktree at $WT_OUT"
MAIN_B="$WORK/b/main"; WT_IN="$MAIN_B/.claude/worktrees/story"
build_main "$MAIN_B" || broken "could not build the second main repository at $MAIN_B"
mkdir -p "$MAIN_B/.claude/worktrees" || broken "mkdir .claude/worktrees"
add_wt "$MAIN_B" "$WT_IN" || broken "could not add the inside worktree at $WT_IN"

# The artifacts, as an author writes them. ONE: the tree-dependent pair alone. TWO: that pair and
# a pair stale in both trees (`fixed.txt` reads `one` everywhere; `two` is recorded).
art_one() { printf '# Story\n\nThree alpha lines in this tree.\n\n```derived\n$ grep -c alpha data.txt\n%s\n```\n' "$1" > "$2"; }
art_two() {
  printf '# Story\n\nThree alpha lines in this tree.\n\n```derived\n$ grep -c alpha data.txt\n3\n```\n\nThe fixed file says two.\n\n```derived\n$ cat fixed.txt\ntwo\n```\n' > "$1"
}
write_json() { jq -nc --arg f "$1" --arg c "$(cat "$1")" '{tool_name:"Write",tool_input:{file_path:$f,content:$c}}'; }

HOOK="$MAIN/.claude/hooks/ai-dlc-derivation-capture.sh"
HOOK_B="$MAIN_B/.claude/hooks/ai-dlc-derivation-capture.sh"
OUT="$WORK/stdout"; ERR="$WORK/stderr"
# fire <hook> <project dir> <file> -> RC, streams in $OUT/$ERR
fire() {
  [ -f "$3" ] || broken "the artifact $3 was not written; the arm driving it would read a silent hook as a pass"
  write_json "$3" | CLAUDE_PROJECT_DIR="$2" bash "$1" >"$OUT" 2>"$ERR"
  RC=$?
}
silent_pass() { [ "$RC" = 0 ] && [ ! -s "$OUT" ] && [ ! -s "$ERR" ]; }
refused() { [ "$RC" = 2 ] && grep -qF 'AI/DLC derivation capture' "$ERR"; }

echo "derivation-capture-worktree-root:"

# --- C0: CONTROL — the seed discriminates under the REAL validator ------------------------------
# The same file, the validator run with each root: stale from the main tree, reproducing from the
# worktree. Without this every arm below could pass with trees that agree.
art_one 3 "$WT_OUT/notes/one.md"
C_MAIN="$( ( cd "$MAIN" && AI_DLC_PROJECT_ROOT="$MAIN" bash "$MAIN/scripts/ai-dlc/validate-artifact-derivations.sh" "$WT_OUT/notes/one.md" ) 2>&1 )"; C_MAIN_RC=$?
C_WT="$( ( cd "$WT_OUT" && AI_DLC_PROJECT_ROOT="$WT_OUT" bash "$MAIN/scripts/ai-dlc/validate-artifact-derivations.sh" "$WT_OUT/notes/one.md" ) 2>&1 )"; C_WT_RC=$?
if [ "$C_MAIN_RC" = 1 ] && [ "$C_WT_RC" = 0 ] && grep -q 'STALE' <<<"$C_MAIN" && grep -q '^OK: 1 derivation' <<<"$C_WT"; then
  ok "C0 control: the fence is stale from the main tree (rc 1) and reproduces from the worktree (rc 0)"
else
  bad "C0 control: expected rc 1/STALE from main and rc 0/OK from the worktree, got $C_MAIN_RC / $C_WT_RC — the seed does not discriminate, so every arm below is vacuous"
fi

# --- A1: a correct fence written in a worktree OUTSIDE the project dir is accepted --------------
fire "$HOOK" "$MAIN" "$WT_OUT/notes/one.md"
if silent_pass; then ok "A1 worktree outside the project dir: the worktree-correct fence is accepted (rc 0, silent)"
else bad "A1 worktree outside the project dir: expected rc 0 and no output, got rc $RC: $(head -3 "$ERR" | tr '\n' ' ')"; fi

# --- A1b: the twin — a fence wrong FOR THE WORKTREE (main's value) is refused there -------------
art_one 1 "$WT_OUT/notes/one-main.md"
fire "$HOOK" "$MAIN" "$WT_OUT/notes/one-main.md"
if refused && grep -qF 'one-main.md:6' "$ERR"; then ok "A1b worktree outside: the main tree's value is refused in the worktree, naming one-main.md:6"
else bad "A1b worktree outside: expected rc 2 naming one-main.md:6, got rc $RC: $(head -3 "$ERR" | tr '\n' ' ')"; fi

# --- A2: ANTI-STUB — one pair stale in both trees is named, the tree-dependent pair is not ------
art_two "$WT_OUT/notes/two.md"
LN_TREE="$(grep -n '^\$ grep -c alpha data.txt$' "$WT_OUT/notes/two.md" | cut -d: -f1)"
LN_BOTH="$(grep -n '^\$ cat fixed.txt$' "$WT_OUT/notes/two.md" | cut -d: -f1)"
[ -n "$LN_TREE" ] && [ -n "$LN_BOTH" ] || broken "could not locate the two pairs' lines in two.md"
fire "$HOOK" "$MAIN" "$WT_OUT/notes/two.md"
if refused && grep -qF "two.md:$LN_BOTH" "$ERR" && ! grep -qF "two.md:$LN_TREE" "$ERR"; then
  ok "A2 anti-stub: rc 2 names two.md:$LN_BOTH (stale in both trees) and not two.md:$LN_TREE (correct in the worktree)"
else
  bad "A2 anti-stub: expected rc 2 naming only two.md:$LN_BOTH, got rc $RC: $(grep -E 'two\.md:[0-9]' "$ERR" | tr '\n' ' ')"
fi

# --- A3: the same for a worktree INSIDE the project dir (.claude/worktrees/) --------------------
art_one 3 "$WT_IN/notes/one.md"
fire "$HOOK_B" "$MAIN_B" "$WT_IN/notes/one.md"
if silent_pass; then ok "A3 worktree inside the project dir: the worktree-correct fence is accepted (rc 0, silent)"
else bad "A3 worktree inside the project dir: expected rc 0 and no output, got rc $RC: $(head -3 "$ERR" | tr '\n' ' ')"; fi

# --- A4: a NESTED repository under the project keeps the project root --------------------------
# nested/data.txt carries two alpha lines; the project's carries one. Recorded 1: correct only from
# the project root, which is where a file in another repository must still be judged.
NEST="$MAIN/nested"
mkdir -p "$NEST/notes" && printf 'alpha\nalpha\n' > "$NEST/data.txt" || broken "mkdir nested"
g "$NEST" init -q 2>/dev/null && [ -d "$NEST/.git" ] && g "$NEST" add -A && g "$NEST" commit -qm nested \
  || broken "could not build the nested repository"
art_one 1 "$NEST/notes/n.md"
fire "$HOOK" "$MAIN" "$NEST/notes/n.md"
if silent_pass; then ok "A4 nested repository: the project root is kept, the project-correct fence is accepted"
else bad "A4 nested repository: expected rc 0 and no output, got rc $RC: $(head -3 "$ERR" | tr '\n' ' ')"; fi
art_one 2 "$NEST/notes/n2.md"
fire "$HOOK" "$MAIN" "$NEST/notes/n2.md"
if refused && grep -qF 'n2.md:6' "$ERR"; then ok "A4b nested repository: the nested repo's own value is refused, naming n2.md:6"
else bad "A4b nested repository: expected rc 2 naming n2.md:6, got rc $RC: $(head -3 "$ERR" | tr '\n' ' ')"; fi

# --- A5: a file OUTSIDE any repository falls back to the project dir without error --------------
NOREPO="$WORK/norepo"; mkdir -p "$NOREPO" || broken "mkdir norepo"
g "$NOREPO" rev-parse --show-toplevel >/dev/null 2>&1 && broken "$NOREPO is inside a git repository; A5 cannot express its case"
printf '# Loose\n\n```derived\n$ cat fixed.txt\none\n```\n' > "$NOREPO/loose.md"
fire "$HOOK" "$MAIN" "$NOREPO/loose.md"
if silent_pass; then ok "A5 file outside any repository: falls back to the project dir, fence reproduces (rc 0, silent)"
else bad "A5 file outside any repository: expected rc 0 and no output, got rc $RC: $(head -3 "$ERR" | tr '\n' ' ')"; fi
printf '# Loose\n\n```derived\n$ cat fixed.txt\ntwo\n```\n' > "$NOREPO/loose2.md"
fire "$HOOK" "$MAIN" "$NOREPO/loose2.md"
if refused && grep -qF 'loose2.md:4' "$ERR"; then ok "A5b file outside any repository: a stale fence is still refused, naming loose2.md:4"
else bad "A5b file outside any repository: expected rc 2 naming loose2.md:4, got rc $RC: $(head -3 "$ERR" | tr '\n' ' ')"; fi

# --- A6: a main-tree edit is judged against the main tree, as before ----------------------------
art_one 1 "$MAIN/notes/m.md"
fire "$HOOK" "$MAIN" "$MAIN/notes/m.md"
if silent_pass; then ok "A6 main tree: the main tree's value is accepted (rc 0, silent)"
else bad "A6 main tree: expected rc 0 and no output, got rc $RC: $(head -3 "$ERR" | tr '\n' ' ')"; fi

# --- A7: a project dir that is a SUBDIRECTORY of its repository ---------------------------------
# repo/app is the project; the fences are written relative to app/. app/data.txt carries one alpha
# in the main tree and three in the worktree, and the repo ROOT carries a data.txt with two, so a
# fence recorded 3 reproduces ONLY from <worktree>/app: from the worktree's toplevel it reads 2,
# and from the main tree's app/ it reads 1. Both wrong roots refuse it; only the right one accepts.
SUB_REPO="$WORK/c/repo"; SUB_PROJ="$SUB_REPO/app"; SUB_WT="$WORK/c/wt"
mkdir -p "$SUB_PROJ/.claude/hooks" "$SUB_PROJ/scripts/ai-dlc" "$SUB_PROJ/notes" || broken "mkdir subdir project"
cp "$SRC_HOOK" "$SUB_PROJ/.claude/hooks/ai-dlc-derivation-capture.sh" || broken "cp hook (subdir)"
cp "$SRC_VALIDATOR" "$SUB_PROJ/scripts/ai-dlc/validate-artifact-derivations.sh" || broken "cp validator (subdir)"
printf 'alpha\nbeta\n' > "$SUB_PROJ/data.txt"; printf 'notes\n' > "$SUB_PROJ/notes/README"
printf '0.0.0\n' > "$SUB_PROJ/VERSION"; printf 'alpha\nalpha\n' > "$SUB_REPO/data.txt"
g "$SUB_REPO" init -q 2>/dev/null && [ -d "$SUB_REPO/.git" ] && g "$SUB_REPO" add -A && g "$SUB_REPO" commit -qm base \
  || broken "could not build the subdirectory-project repository"
g "$SUB_REPO" worktree add -q -b story-sub "$SUB_WT" 2>/dev/null && [ -d "$SUB_WT/app/notes" ] \
  || broken "could not add the subdirectory-project worktree"
printf 'alpha\nalpha\nalpha\nbeta\n' > "$SUB_WT/app/data.txt"
HOOK_SUB="$SUB_PROJ/.claude/hooks/ai-dlc-derivation-capture.sh"
# Control: the three candidate roots answer three different counts, or A7 cannot discriminate.
SC="$(grep -c alpha "$SUB_WT/app/data.txt") $(grep -c alpha "$SUB_WT/data.txt") $(grep -c alpha "$SUB_PROJ/data.txt")"
[ "$SC" = "3 2 1" ] || broken "A7 seed: <wt>/app, <wt> and <main>/app read [$SC], expected [3 2 1]"
art_one 3 "$SUB_WT/app/notes/s.md"
fire "$HOOK_SUB" "$SUB_PROJ" "$SUB_WT/app/notes/s.md"
if silent_pass; then ok "A7 subdirectory project dir, worktree edit: judged from <worktree>/app, the worktree-correct fence is accepted (rc 0, silent)"
else bad "A7 subdirectory project dir, worktree edit: expected rc 0 and no output, got rc $RC: $(head -3 "$ERR" | tr '\n' ' ')"; fi
art_one 2 "$SUB_WT/app/notes/s-top.md"
fire "$HOOK_SUB" "$SUB_PROJ" "$SUB_WT/app/notes/s-top.md"
if refused && grep -qF 's-top.md:6' "$ERR"; then ok "A7b subdirectory project dir: the worktree TOPLEVEL's value is refused, naming s-top.md:6"
else bad "A7b subdirectory project dir: expected rc 2 naming s-top.md:6, got rc $RC: $(head -3 "$ERR" | tr '\n' ' ')"; fi
art_one 1 "$SUB_PROJ/notes/m.md"
fire "$HOOK_SUB" "$SUB_PROJ" "$SUB_PROJ/notes/m.md"
if silent_pass; then ok "A7c subdirectory project dir, main-tree edit: the project dir is kept, its value accepted (rc 0, silent)"
else bad "A7c subdirectory project dir, main-tree edit: expected rc 0 and no output, got rc $RC: $(head -3 "$ERR" | tr '\n' ' ')"; fi

# --- A8: an exported GIT_DIR does not redirect the checkout test ---------------------------------
# With GIT_DIR set and no GIT_WORK_TREE, git takes the CURRENT directory as the toplevel, so a
# main-tree edit in notes/ read as a different checkout sharing the common dir and its fences ran
# from notes/, where data.txt does not exist. The hook must answer as it does with a clean env.
fire_env() { # fire_env <hook> <project dir> <file> <VAR=value...>
  local h="$1" p="$2" f="$3"; shift 3
  [ -f "$f" ] || broken "the artifact $f was not written"
  write_json "$f" | env "$@" CLAUDE_PROJECT_DIR="$p" bash "$h" >"$OUT" 2>"$ERR"
  RC=$?
}
fire_env "$HOOK" "$MAIN" "$MAIN/notes/m.md" GIT_DIR="$MAIN/.git"
if silent_pass; then ok "A8 GIT_DIR=<main>/.git exported, main-tree subdirectory edit: judged from the project dir (rc 0, silent)"
else bad "A8 GIT_DIR exported, main-tree subdirectory edit: expected rc 0 and no output, got rc $RC: $(head -3 "$ERR" | tr '\n' ' ')"; fi
fire_env "$HOOK" "$MAIN" "$WT_OUT/notes/one.md" GIT_DIR="$MAIN/.git"
if silent_pass; then ok "A8b GIT_DIR=<main>/.git exported, worktree edit: still judged from the worktree (rc 0, silent)"
else bad "A8b GIT_DIR exported, worktree edit: expected rc 0 and no output, got rc $RC: $(head -3 "$ERR" | tr '\n' ' ')"; fi

# --- MUTANTS — copies of the hook, never the installed one --------------------------------------
# mkmut <name> <sed program>: a copy with the program applied; refuses a no-op (cmp -s) and a sed
# that died, so a mutation that matched nothing cannot score a kill.
mkmut() {
  local m="$WORK/mut-$1.sh"
  sed "$2" "$HOOK" > "$m" 2>/dev/null || { bad "mutant $1 DID NOT APPLY (sed failed)"; return 1; }
  if cmp -s "$HOOK" "$m"; then bad "mutant $1 DID NOT APPLY (no change)"; return 1; fi
  bash -n "$m" 2>/dev/null || { bad "mutant $1 does not parse"; return 1; }
  printf '%s' "$m"
}

# M1: the fix reverted — every use of the resolved root at the invocation back to PROJECT_DIR, the
# env var AND the cd (the env var is the layer the validator reads; the cd is reverted too so no
# layer is left standing). A1 and A2 must redden: A1 by a refusal, A2 by naming both pairs.
# Occurrences, not lines: the cd and the env var share one line.
n_before="$(grep -o '"\$DERIV_ROOT"' "$HOOK" | wc -l | tr -d ' ')"
if M1="$(mkmut revert 's/"\$DERIV_ROOT"/"$PROJECT_DIR"/g')"; then
  n_after="$(grep -o '"\$DERIV_ROOT"' "$M1" | wc -l | tr -d ' ')"
  [ "$n_before" -ge 2 ] && [ "$n_after" = 0 ] || bad "M1 revert: expected every \"\$DERIV_ROOT\" use replaced, before $n_before after $n_after"
  fire "$M1" "$MAIN" "$WT_OUT/notes/one.md"
  if refused && grep -qF 'one.md:6' "$ERR"; then ok "M1 revert-to-PROJECT_DIR killed by A1 (the worktree-correct fence is refused, naming one.md:6)"
  else bad "M1 revert-to-PROJECT_DIR SURVIVED A1: rc $RC"; fi
  fire "$M1" "$MAIN" "$WT_OUT/notes/two.md"
  if refused && grep -qF "two.md:$LN_TREE" "$ERR" && grep -qF "two.md:$LN_BOTH" "$ERR"; then
    ok "M1 revert-to-PROJECT_DIR killed by A2 (both pairs named)"
  else bad "M1 revert-to-PROJECT_DIR SURVIVED A2: rc $RC"; fi
  # The inside layout, driven through the second project's own hook path with the mutant's bytes.
  cp "$M1" "$WORK/mut-revert-b.sh"
  fire "$WORK/mut-revert-b.sh" "$MAIN_B" "$WT_IN/notes/one.md"
  if refused && grep -qF 'one.md:6' "$ERR"; then ok "M1 revert-to-PROJECT_DIR killed by A3 (the inside-worktree fence is refused)"
  else bad "M1 revert-to-PROJECT_DIR SURVIVED A3: rc $RC"; fi
fi

# M2: the common-dir check deleted — show-toplevel alone. A4 must redden (the nested repo's root
# is taken and the project-correct fence is refused); A1 must stay green (one property apart).
if M2="$(mkmut nocommon '/\[ -n "\$fc" \] && \[ "\$fc" = "\$pc" \] || exit 1/d')"; then
  fire "$M2" "$MAIN" "$NEST/notes/n.md"
  if refused && grep -qF 'n.md:6' "$ERR"; then ok "M2 no-common-dir-check killed by A4 (the nested repo's root is taken)"
  else bad "M2 no-common-dir-check SURVIVED A4: rc $RC"; fi
  fire "$M2" "$MAIN" "$WT_OUT/notes/one.md"
  if silent_pass; then ok "M2 control: the same mutant still accepts the worktree fence (A1 green), so it fails only A4"
  else bad "M2 control: the mutant also broke A1 (rc $RC) — the mutation is not confined to the common-dir check"; fi
fi

# M3: the worktree's TOPLEVEL returned instead of its copy of the project dir (the 0.773.0 shape).
# A7 must redden (the fence runs from <worktree>, reads 2); A1 must stay green (project dir is the
# toplevel there, so the two forms agree).
if M3="$(mkmut toplevel 's/^    printf .%s. "\${ft}\${pp#"\$pt"}"$/    printf "%s" "$ft"/')"; then
  fire "$M3" "$SUB_PROJ" "$SUB_WT/app/notes/s.md"
  if refused && grep -qF 's.md:6' "$ERR"; then ok "M3 toplevel-not-project-subdir killed by A7 (the fence runs from the worktree toplevel)"
  else bad "M3 toplevel-not-project-subdir SURVIVED A7: rc $RC"; fi
  fire "$M3" "$MAIN" "$WT_OUT/notes/one.md"
  if silent_pass; then ok "M3 control: the same mutant still accepts the A1 worktree fence, so it fails only A7"
  else bad "M3 control: the mutant also broke A1 (rc $RC)"; fi
fi

# M4: the repository environment left set inside deriv_file_root. A8 must redden; A6 (clean env)
# must stay green.
if M4="$(mkmut gitenv '/^    unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR$/d')"; then
  fire_env "$M4" "$MAIN" "$MAIN/notes/m.md" GIT_DIR="$MAIN/.git"
  if refused && grep -qF 'm.md:6' "$ERR"; then ok "M4 GIT_DIR-not-unset killed by A8 (the main-tree edit is judged from notes/)"
  else bad "M4 GIT_DIR-not-unset SURVIVED A8: rc $RC"; fi
  fire "$M4" "$MAIN" "$MAIN/notes/m.md"
  if silent_pass; then ok "M4 control: the same mutant still accepts the main-tree fence with a clean env (A6 green)"
  else bad "M4 control: the mutant also broke A6 (rc $RC)"; fi
fi

echo
if [ "$fails" -eq 0 ]; then echo "PASS: derivation-capture-worktree-root"; exit 0; fi
echo "FAIL: derivation-capture-worktree-root ($fails)"; exit 1
