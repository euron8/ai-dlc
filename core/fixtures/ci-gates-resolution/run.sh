#!/usr/bin/env bash
# ci-gates-resolution — assert validate-ci-gates.sh's generalized enforcement match:
# the VACUOUS-78 code, the comment-aware forward match (no longer fail-open), and the
# optional two-legged alias table. Every general mechanism carries a MUTATION control:
# a FAIL/PASS is evidence for a mechanism only if removing that mechanism flips it.
#
# THE DEFECTS THIS EXISTS TO CATCH.
#
#  - The old forward arm was `grep -rqF "$gate" "$WORKFLOW_DIR"`: any substring anywhere,
#    COMMENTS INCLUDED, read as enforcement. A gate name left in a `#` banner after its
#    enforcing step was deleted stayed "enforced" forever — a check that cannot fail.
#  - "No enforcement surface" exited 2 (tool-failure), sharing an exit with a real error
#    and never distinguishable from a clean or a dormant scan. It is VACUOUS: exit 78.
#  - A gate enforced under a DIFFERENT name than it is declared needs an alias, but an
#    alias that only checks the gate name is a suppression list. A row resolves ONLY when
#    the enforcer is wired (leg i) AND the detection anchor is present exactly once in
#    non-comment code (leg ii) — the literal whose deletion kills enforcement.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"

# install.sh maps core/scripts/<x> -> scripts/ai-dlc/<x> at the project root.
if [ -n "$ROOT" ] && [ -f "$ROOT/core/scripts/validate-ci-gates.sh" ]; then
  VALIDATOR="$ROOT/core/scripts/validate-ci-gates.sh"
elif [ -n "$ROOT" ] && [ -f "$ROOT/scripts/ai-dlc/validate-ci-gates.sh" ]; then
  VALIDATOR="$ROOT/scripts/ai-dlc/validate-ci-gates.sh"
else
  echo "FIXTURE ERROR: validate-ci-gates.sh not found in either layout" >&2
  exit 2
fi

# Scrub ambient AI_DLC_* — this fixture sets the tunables it tests; a leaked
# AI_DLC_CI_SURFACE or AI_DLC_CI_ALIAS_TABLE would pin every run to one answer.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

WORK="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/docs/retro" "$WORK/surface"
printf 'Retro.\n\nAdded CI gate `build` this sprint. Also CI gate `deploy`.\n' \
  > "$WORK/docs/retro/s1.md"

# Every run resolves the same fixture root and retro dir; only the surface / alias
# table vary per assertion.
run_ci() { # run_ci <validator> <surface> [alias-table]
  local v="$1" surface="$2" alias="${3:-}"
  AI_DLC_PROJECT_ROOT="$WORK" AI_DLC_RETRO_DIR="$WORK/docs/retro" \
  AI_DLC_CI_SURFACE="$surface" AI_DLC_CI_ALIAS_TABLE="$alias" \
    bash "$v" >"$WORK/out.txt" 2>&1
  echo "$?"
}
mutate() { # mutate <find> <replace> -> writes $WORK/mutant.sh, prints CHANGED|UNCHANGED
  python3 - "$VALIDATOR" "$WORK/mutant.sh" "$1" "$2" <<'PY'
import sys
src, dst, find, repl = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
s = open(src, encoding="utf-8").read()
s2 = s.replace(find, repl)
open(dst, "w", encoding="utf-8").write(s2)
print("CHANGED" if s2 != s else "UNCHANGED")
PY
}

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1" >&2; fails=$((fails+1)); }
echo "ci-gates-resolution:"

# ============================ A. VACUOUS = exit 78 ============================
rc="$(run_ci "$VALIDATOR" "$WORK/does-not-exist")"
[ "$rc" = "78" ] && ok "A no surface -> exit 78 (VACUOUS, not 0/1/2)" \
  || bad "A no surface -> exit $rc, expected 78"
# MUTATION: revert the VACUOUS code to the old exit 2 and require the code to flip.
m="$(mutate 'exit 78' 'exit 2')"
if [ "$m" != "CHANGED" ]; then bad "A MUTATION matched nothing (exit 78 renamed)"; else
  rc="$(run_ci "$WORK/mutant.sh" "$WORK/does-not-exist")"
  [ "$rc" = "2" ] && ok "A MUTATION — without the 78 code the surface-missing path is exit 2 again" \
    || bad "A MUTATION — expected exit 2 from the reverted code, got $rc"
fi

# ==================== B. comment-aware forward match =========================
# 'build' appears ONLY in a comment; 'deploy' runs for real.
printf '# runs the build gate nightly\njobs:\n  deploy:\n    run: ./deploy.sh\n' \
  > "$WORK/surface/ci.yml"
rc="$(run_ci "$VALIDATOR" "$WORK/surface")"
if [ "$rc" = "1" ] && grep -q "DORMANT: gate 'build'" "$WORK/out.txt"; then
  ok "B a gate named only in a comment is DORMANT (fail-open closed)"
else
  bad "B comment-only gate not dormant (rc=$rc) — the forward match is fail-open again"
fi
# MUTATION: neuter the comment strip (revert to the raw fail-open match).
m="$(mutate "sed -e 's/^[[:space:]]*#.*\$//'" 'cat')"
if [ "$m" != "CHANGED" ]; then bad "B MUTATION matched nothing (comment strip renamed)"; else
  rc="$(run_ci "$WORK/mutant.sh" "$WORK/surface")"
  if grep -q "DORMANT: gate 'build'" "$WORK/out.txt"; then
    bad "B MUTATION — 'build' still dormant without the comment strip; B proves nothing"
  else
    ok "B MUTATION — without the comment strip the comment-only 'build' reads enforced (fail-open)"
  fi
fi

# ========================= C. honest non-comment match ======================
printf 'jobs:\n  build:\n    run: ./build.sh\n  deploy:\n    run: ./deploy.sh\n' \
  > "$WORK/surface/ci.yml"
rc="$(run_ci "$VALIDATOR" "$WORK/surface")"
[ "$rc" = "0" ] && ok "C both gates enforced in non-comment code -> clean (exit 0)" \
  || bad "C honest enforcement flagged dormant (rc=$rc): $(tail -1 "$WORK/out.txt")"

# ===================== D/E/F. two-legged alias table ========================
# 'build' is enforced under a differently-named step ('ci_pipeline') via the anchor
# 'make compile-all'. The gate name itself never appears in the surface.
printf 'jobs:\n  ci_pipeline:\n    run: make compile-all\n  deploy:\n    run: ./deploy.sh\n' \
  > "$WORK/surface/ci.yml"
printf 'build|ci_pipeline|surface/ci.yml|make compile-all\n' > "$WORK/aliases.txt"

# D. both legs hold -> resolved.
rc="$(run_ci "$VALIDATOR" "$WORK/surface" "$WORK/aliases.txt")"
[ "$rc" = "0" ] && ok "D alias row (enforcer wired + anchor once) resolves the gate -> clean" \
  || bad "D a both-legged alias row did not resolve (rc=$rc): $(tail -1 "$WORK/out.txt")"

# E. leg (ii): the anchor appears TWICE -> not exactly once -> DORMANT.
printf 'jobs:\n  ci_pipeline:\n    run: make compile-all\n  redo:\n    run: make compile-all\n  deploy:\n    run: ./deploy.sh\n' \
  > "$WORK/surface/ci.yml"
rc="$(run_ci "$VALIDATOR" "$WORK/surface" "$WORK/aliases.txt")"
if [ "$rc" = "1" ] && grep -q "DORMANT: gate 'build'" "$WORK/out.txt"; then
  ok "E leg (ii) — anchor present twice is NOT exactly once -> gate stays DORMANT"
else
  bad "E an anchor present twice still resolved (rc=$rc) — leg (ii) exactly-once is dark"
fi
# MUTATION: relax exactly-once to at-least-once; the twice case must then resolve.
m="$(mutate '"$a_anchor")" -eq 1 ] && return 0' '"$a_anchor")" -ge 1 ] && return 0')"
if [ "$m" != "CHANGED" ]; then bad "E MUTATION matched nothing (leg ii test renamed)"; else
  rc="$(run_ci "$WORK/mutant.sh" "$WORK/surface" "$WORK/aliases.txt")"
  [ "$rc" = "0" ] && ok "E MUTATION — relaxing exactly-once to >=1 resolves the twice case (leg ii fires)" \
    || bad "E MUTATION — twice case still dormant with >=1 (rc=$rc); E proves nothing"
fi

# F. leg (i): the enforcer is NOT wired (id absent from the surface) -> DORMANT,
# even though the anchor is present exactly once.
printf 'jobs:\n  other:\n    run: make compile-all\n  deploy:\n    run: ./deploy.sh\n' \
  > "$WORK/surface/ci.yml"
rc="$(run_ci "$VALIDATOR" "$WORK/surface" "$WORK/aliases.txt")"
if [ "$rc" = "1" ] && grep -q "DORMANT: gate 'build'" "$WORK/out.txt"; then
  ok "F leg (i) — enforcer id absent -> gate stays DORMANT despite the anchor"
else
  bad "F an unwired enforcer still resolved (rc=$rc) — leg (i) is dark"
fi
# MUTATION: force leg (i) to always pass; the unwired case must then resolve.
m="$(mutate '[ "$(code_hits "$resolved_file" "$a_enf")" -ge 1 ] || continue' ': # MUTANT: leg (i) disabled')"
if [ "$m" != "CHANGED" ]; then bad "F MUTATION matched nothing (leg i test renamed)"; else
  rc="$(run_ci "$WORK/mutant.sh" "$WORK/surface" "$WORK/aliases.txt")"
  [ "$rc" = "0" ] && ok "F MUTATION — disabling leg (i) resolves the unwired case (leg i fires)" \
    || bad "F MUTATION — unwired case still dormant with leg (i) off (rc=$rc); F proves nothing"
fi

# ===================== G. angle-bracket placeholder skip ====================
# A retro TEMPLATE / declaration-format example (`CI gate `<gate-name>``) is
# documentation, not a declared gate. It must be skipped, or it reads as a phantom
# dormant gate and exits 1 on template noise.
printf 'jobs:\n  build:\n    run: ./build.sh\n  deploy:\n    run: ./deploy.sh\n' \
  > "$WORK/surface/ci.yml"
printf 'Retro.\n\nAdded CI gate `build`. Also CI gate `deploy`. Format: CI gate `<gate-name>`.\n' \
  > "$WORK/docs/retro/s1.md"
rc="$(run_ci "$VALIDATOR" "$WORK/surface")"
if [ "$rc" = "0" ] && grep -q '2 gates declared' "$WORK/out.txt"; then
  ok "G a <placeholder> gate name is skipped (2 declared, not 3) -> clean"
else
  bad "G placeholder not skipped (rc=$rc): $(tail -1 "$WORK/out.txt")"
fi
# MUTATION: neuter the placeholder skip; the <gate-name> token must then count and go DORMANT.
m="$(mutate '*"<"*">"*) continue' '*"<"*">"*) :')"
if [ "$m" != "CHANGED" ]; then bad "G MUTATION matched nothing (placeholder skip renamed)"; else
  rc="$(run_ci "$WORK/mutant.sh" "$WORK/surface")"
  if [ "$rc" = "1" ] && grep -q "DORMANT: gate '<gate-name>'" "$WORK/out.txt"; then
    ok "G MUTATION — without the skip the <gate-name> placeholder counts and is DORMANT (skip is real)"
  else
    bad "G MUTATION — placeholder still skipped without the guard (rc=$rc); G proves nothing"
  fi
fi

echo
[ "$fails" -eq 0 ] && { echo "ci-gates-resolution: PASS"; exit 0; }
echo "ci-gates-resolution: $fails assertion(s) violated." >&2
exit 1
