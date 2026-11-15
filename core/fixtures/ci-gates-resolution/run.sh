#!/usr/bin/env bash
# ci-gates-resolution — assert validate-ci-gates.sh's generalized enforcement match:
# the EXAMINED-NOTHING-78 code, the comment-aware forward match (no longer fail-open), and the
# optional two-legged alias table.
#
# THE DEFECTS THIS EXISTS TO CATCH.
#
#  - The old forward arm was `grep -rqF "$gate" "$WORKFLOW_DIR"`: any substring anywhere,
#    COMMENTS INCLUDED, read as enforcement. A gate name left in a `#` banner after its
#    enforcing step was deleted stayed "enforced" forever — a check that cannot fail.
#  - "No enforcement surface" exited 2 (tool-failure), sharing an exit with a real error
#    and never distinguishable from a clean or a dormant scan. It reports the declared
#    empty-subject verdict token EXAMINED NOTHING at exit 78. The token is owned by
#    enforcement-map.yaml `empty_subject_verdict:` and bound by validate-enforcement-map.sh I93;
#    the exit CODE is this script's own contract and is deliberately not unified with it.
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

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1" >&2; fails=$((fails+1)); }
echo "ci-gates-resolution:"

# ==================== A. EXAMINED NOTHING = exit 78 ==========================
rc="$(run_ci "$VALIDATOR" "$WORK/does-not-exist")"
[ "$rc" = "78" ] && ok "A no surface -> exit 78 (EXAMINED NOTHING, not 0/1/2)" \
  || bad "A no surface -> exit $rc, expected 78"

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

# ============ H. CORPUS IDENTITY on BOTH exit-0 emitters =====================
# THE DEFECT. Two runs over DIFFERENT trees holding IDENTICAL bytes produced
# byte-identical output. `Scanned 1 retros, 0 gates declared, 0 dormant` names neither the
# retro tree that was read nor the surface that was searched, and BOTH roots are
# consumer-tunable (AI_DLC_RETRO_DIR, AI_DLC_CI_SURFACE) — so a run against the wrong tree
# read exactly like a run against the right one. The zero-gate exit is the measured worst
# case: a retro tree that exists and declares nothing exits 0 and reports two zeros.
#
# THE ARM IS KEYED ON DISCRIMINATION, NOT ON A SPELLING. Each emitter is driven twice over
# two mktemp roots seeded with identical bytes. The outputs must DIFFER **and** each must
# carry ITS OWN root path. Those two halves are not the same requirement: a nonce, a
# timestamp or a run counter satisfies "differ" while naming nothing, and it fails the
# second half. Nothing here greps a label, so re-wording `retro dir:` leaves the arm
# working; what it demands is the resolved path, which is a mktemp name and therefore
# unconstructible as a literal in the validator.
IDENT_WHY=""
ident_corpus() { # <retro-body> -> prints a fresh root under $WORK
  local d
  d="$(mktemp -d "$WORK/ident.XXXXXX")" || return 1
  mkdir -p "$d/docs/retro" "$d/surface" || return 1
  printf '%s' "$1" > "$d/docs/retro/s1.md"
  printf 'jobs:\n  build:\n    run: ./build.sh\n  deploy:\n    run: ./deploy.sh\n' \
    > "$d/surface/ci.yml"
  # A well-formed alias table lives in every corpus. It is only CONSULTED when IDENT_ALIAS
  # names it, so its presence changes no verdict in the arms that leave IDENT_ALIAS empty.
  printf 'build|build|surface/ci.yml|./build.sh\n' > "$d/aliases.txt"
  printf '%s\n' "$d"
}
# THE RETRO SUBPATH IS A PARAMETER BECAUSE THE THIRD EMITTER IS REACHED BY POINTING AT A
# TREE THAT IS NOT THERE. `AI_DLC_RETRO_DIR` is what selects between the three exit-0 paths:
# a subpath that does not exist takes :110, one that exists and declares nothing takes :145,
# and one that declares gates takes :254. Driving all three through ONE helper is what keeps
# the three arms honest about being three arms — each names the emitter it reached.
#
# THE ALIAS TABLE IS A SEPARATE PARAMETER AND IT IS NOT ASSERTED THE SAME WAY EVERYWHERE.
# `ALIAS_TABLE_FILE` is resolved at :175, BELOW the :110 and :145 exits, so those two runs
# never consult it. Naming it there would report a corpus the run did not read, which is a
# worse failure than not naming it — so the early exits are asserted to be SILENT about it
# and only the main verdict is asserted to name it.
#
# `IDENT_ALIAS` holds a SUBPATH, never an absolute one, so each of the two runs consults the
# table inside ITS OWN corpus. Pointing both runs at one shared table would make the alias
# path a constant, and a constant cannot discriminate — the arm would pass against a
# validator that echoed a hardcoded string.
IDENT_ALIAS=""
ident_run() { # <validator> <root> <retro-subpath> <outfile> -> echoes rc
  local al=""
  [ -n "$IDENT_ALIAS" ] && al="$2/$IDENT_ALIAS"
  AI_DLC_PROJECT_ROOT="$2" AI_DLC_RETRO_DIR="$2/$3" \
  AI_DLC_CI_SURFACE="$2/surface" AI_DLC_CI_ALIAS_TABLE="$al" \
    bash "$1" >"$4" 2>&1
  echo "$?"
}
# ident_holds <validator> <retro-body> <verdict-substring> [retro-subpath]
# Returns 0 when the emitter reached is the one named AND the two runs are distinguishable
# AND each names its own corpus. Sets IDENT_WHY on failure.
ident_holds() {
  local v="$1" body="$2" want="$3" sub="${4:-docs/retro}" a b ra rb
  IDENT_WHY=""
  a="$(ident_corpus "$body")" || { IDENT_WHY="could not build corpus A"; return 1; }
  b="$(ident_corpus "$body")" || { IDENT_WHY="could not build corpus B"; return 1; }
  ra="$(ident_run "$v" "$a" "$sub" "$WORK/ident-a.txt")"
  rb="$(ident_run "$v" "$b" "$sub" "$WORK/ident-b.txt")"
  if [ "$ra" != "0" ] || [ "$rb" != "0" ]; then
    IDENT_WHY="rc=$ra/$rb, expected 0/0 — the run never reached a success emitter"; return 1
  fi
  # Requirement 3: prove WHICH emitter was reached, in the same invocation as the verdict.
  if ! grep -qF "$want" "$WORK/ident-a.txt"; then
    IDENT_WHY="the output carries no '$want' — this arm did not reach the emitter it claims"
    return 1
  fi
  if cmp -s "$WORK/ident-a.txt" "$WORK/ident-b.txt"; then
    IDENT_WHY="two different trees holding identical bytes produced byte-identical output"
    return 1
  fi
  # PRESENCE-shaped, both roots, both runs: a subject replaced by `exit 0` fails here.
  if ! grep -qF "$a/$sub" "$WORK/ident-a.txt" \
     || ! grep -qF "$a/surface" "$WORK/ident-a.txt"; then
    IDENT_WHY="run A does not name the retro tree it read and the surface it searched"
    return 1
  fi
  if ! grep -qF "$b/$sub" "$WORK/ident-b.txt" \
     || ! grep -qF "$b/surface" "$WORK/ident-b.txt"; then
    IDENT_WHY="run B does not name the retro tree it read and the surface it searched"
    return 1
  fi
  if grep -qF "$b" "$WORK/ident-a.txt"; then
    IDENT_WHY="run A's output carries run B's root — the paths are not the ones it resolved"
    return 1
  fi
  return 0
}

# A retro that EXISTS and declares nothing -> the early exit 0. The declaring body drives
# the main verdict. Both are seeded from the declaration grammar the real producer writes,
# never from anything read back out of the validator.
IDENT_BODY_ZERO='Retro for sprint 1.

Nothing was gated this sprint.
'
IDENT_BODY_GATES='Retro for sprint 1.

Added CI gate `build` this sprint. Also CI gate `deploy`.
'

if ident_holds "$VALIDATOR" "$IDENT_BODY_ZERO" '0 gates declared'; then
  ok "H1 zero-gate exit 0 names the retro tree and the enforcement surface it resolved, and two identical corpora are distinguishable"
else
  bad "H1 zero-gate exit 0 carries no corpus identity — $IDENT_WHY"
fi
if ident_holds "$VALIDATOR" "$IDENT_BODY_GATES" '2 gates declared'; then
  ok "H2 the main verdict names the retro tree and the enforcement surface it resolved, and two identical corpora are distinguishable"
else
  bad "H2 the main verdict carries no corpus identity — $IDENT_WHY"
fi
# H3. THE THIRD EXIT-0 EMITTER. `AI_DLC_RETRO_DIR` pointing at a tree that is not there
# exits 0 at :110 — a live consumer state, not a synthetic one, since a consumer with no
# docs/retro takes it on every run. It named the retro dir inline and nothing else, so two
# runs differing only in which enforcement surface they were pointed at were byte-identical.
# The verdict token is `0 dormant (no `, which the :145 emitter cannot produce: that one
# closes the quote straight after `dormant`. Asserting it is what proves this arm reached
# the third emitter rather than falling through to the second.
if ident_holds "$VALIDATOR" "$IDENT_BODY_ZERO" '0 dormant (no ' 'no-such-retro'; then
  ok "H3 the absent-retro-tree exit 0 names the tree it looked for AND the enforcement surface, and two identical corpora are distinguishable"
else
  bad "H3 the absent-retro-tree exit 0 carries no corpus identity — $IDENT_WHY"
fi

# ---- H4/H5/H6. THE ALIAS TABLE, which is the SUPPRESSION channel -------------
# A row in the alias table RESOLVES an otherwise-dormant gate. It is the one input here
# whose CONTENTS decide the verdict rather than merely being scanned, and a green run that
# does not name it cannot be told from a green run against the wrong table.
IDENT_ALIAS='aliases.txt'
if ident_holds "$VALIDATOR" "$IDENT_BODY_GATES" '2 gates declared'; then
  ok "H4 the main verdict names the alias table it consulted — the suppression channel is identified, not just the two scanned roots"
else
  bad "H4 the main verdict carries no corpus identity with an alias table in play — $IDENT_WHY"
fi
# H4 as written would also pass if the alias path were echoed but never resolved, so the
# path is additionally required by name, on the run that consulted it.
IDENT_A1="$(ident_corpus "$IDENT_BODY_GATES")"
IDENT_RC1="$(ident_run "$VALIDATOR" "$IDENT_A1" 'docs/retro' "$WORK/ident-alias-set.txt")"
IDENT_ALIAS=""
IDENT_RC2="$(ident_run "$VALIDATOR" "$IDENT_A1" 'docs/retro' "$WORK/ident-alias-unset.txt")"
if [ "$IDENT_RC1" = "0" ] && grep -qF "$IDENT_A1/aliases.txt" "$WORK/ident-alias-set.txt"; then
  ok "H4b the alias table's resolved PATH appears in the verdict of the run that consulted it"
else
  bad "H4b the alias table path is not named (rc=$IDENT_RC1) — the row that resolved a gate came from a file the operator cannot identify"
fi
# H5. OMISSION MUST NOT SPELL THE SAME AS A PATH. Keyed on discrimination rather than on
# the `(none set)` wording, so re-wording the placeholder leaves it working — what it
# forbids is the two states rendering identically, which is what a bare `$VAR` would do.
if [ "$IDENT_RC2" = "0" ] && ! cmp -s "$WORK/ident-alias-set.txt" "$WORK/ident-alias-unset.txt"; then
  ok "H5 the same corpus WITH and WITHOUT an alias table produces different output — an omitted table is reported as omitted, not as blank"
else
  bad "H5 setting and unsetting the alias table produced identical output (rc=$IDENT_RC2) — omission and a supplied table share a spelling"
fi
# H6. THE TWO EARLY EXITS MUST STAY SILENT ABOUT IT. `ALIAS_TABLE_FILE` is resolved at :175,
# below both of them, so a name printed there would be a corpus the run never opened — a
# claim of provenance that is false, which is worse than none. THIS ARM IS ABSENCE-SHAPED, so it is paired with H1/H3,
IDENT_ALIAS='aliases.txt'
IDENT_A2="$(ident_corpus "$IDENT_BODY_ZERO")"
IDENT_RC3="$(ident_run "$VALIDATOR" "$IDENT_A2" 'docs/retro' "$WORK/ident-early-zero.txt")"
IDENT_RC4="$(ident_run "$VALIDATOR" "$IDENT_A2" 'no-such-retro' "$WORK/ident-early-absent.txt")"
IDENT_ALIAS=""
if [ "$IDENT_RC3" = "0" ] && [ "$IDENT_RC4" = "0" ] \
   && grep -qF '0 gates declared' "$WORK/ident-early-zero.txt" \
   && grep -qF '0 dormant (no ' "$WORK/ident-early-absent.txt" \
   && ! grep -qF "$IDENT_A2/aliases.txt" "$WORK/ident-early-zero.txt" \
   && ! grep -qF "$IDENT_A2/aliases.txt" "$WORK/ident-early-absent.txt"; then
  ok "H6 neither early exit names the alias table — both return above the line that resolves it, so naming it would report a corpus the run never opened"
else
  bad "H6 an early exit (rc=$IDENT_RC3/$IDENT_RC4) named an alias table it returned before resolving, or did not reach the emitter this arm claims — a false provenance claim is worse than none"
fi


echo
[ "$fails" -eq 0 ] && { echo "ci-gates-resolution: PASS"; exit 0; }
echo "ci-gates-resolution: $fails assertion(s) violated." >&2
exit 1
