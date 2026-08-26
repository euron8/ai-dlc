#!/usr/bin/env bash
# ci-gates-resolution — assert validate-ci-gates.sh's generalized enforcement match:
# the EXAMINED-NOTHING-78 code, the comment-aware forward match (no longer fail-open), and the
# optional two-legged alias table. Every general mechanism carries a MUTATION control:
# a FAIL/PASS is evidence for a mechanism only if removing that mechanism flips it.
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

# ==================== A. EXAMINED NOTHING = exit 78 ==========================
rc="$(run_ci "$VALIDATOR" "$WORK/does-not-exist")"
[ "$rc" = "78" ] && ok "A no surface -> exit 78 (EXAMINED NOTHING, not 0/1/2)" \
  || bad "A no surface -> exit $rc, expected 78"
# MUTATION: revert the exit-78 code to the old exit 2 and require the code to flip. This
# mutation is keyed on `exit 78`, NOT on the verdict token, so renaming the token leaves it
# working and RENUMBERING the code silently returns UNCHANGED -- which the guard below reports.
m="$(mutate 'exit 78' 'exit 2')"
if [ "$m" != "CHANGED" ]; then bad "A MUTATION matched nothing (exit 78 renumbered)"; else
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
#
# BOTH EMITTERS ARE GUARDED, SEPARATELY, AND THAT IS THE WHOLE REASON THE MUTANTS BELOW ARE
# A PAIR. The two identity blocks are byte-identical text, so a mutation keyed on the shared
# line edits both, moves two cells and scores a kill it did not earn. Each mutant is
# anchored on the VERDICT LINE ABOVE its block — `0 gates declared, 0 dormant"` for the
# early exit, `${unique_count} gates declared` for the main one — and each is required to
# leave the OTHER emitter intact, which is what proves the mutation was site-specific.
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
# claim of provenance that is false, which is worse than none. THIS ARM IS ABSENCE-SHAPED
# AND THEREFORE CARRIES ITS OWN MUTANT (H-A below); on its own it would pass against a
# subject that emits nothing, so it is paired with H1/H3, which demand those emitters print.
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

# THE UNMUTATED CONTROL, with a positive conjunct. A lone copy in a temp dir that could not
# run would emit nothing, and "no output" would otherwise score as a kill for both mutants
# below. `ident_holds` is presence-shaped, so this control cannot pass against `exit 0`.
IDENT_CTL="$WORK/ident-control.sh"
cp "$VALIDATOR" "$IDENT_CTL"
IDENT_CTL_OK=0
if ident_holds "$IDENT_CTL" "$IDENT_BODY_ZERO" '0 gates declared' \
   && ident_holds "$IDENT_CTL" "$IDENT_BODY_GATES" '2 gates declared' \
   && ident_holds "$IDENT_CTL" "$IDENT_BODY_ZERO" '0 dormant (no ' 'no-such-retro'; then
  ok "H CONTROL — an unmutated copy reproduces all three identity blocks, so a mutant's silence below means mutation, not breakage"
  IDENT_CTL_OK=1
else
  bad "H CONTROL FAILED ($IDENT_WHY) — every mutant verdict below is uninterpretable"
fi

# ident_mutant <label> <verdict-anchor> -> sets IDENT_MUT, returns 0 on success.
# Deletes ONLY the identity lines that FOLLOW the given verdict line, so the two
# byte-identical blocks are separable.
#
# IT SETS A GLOBAL RATHER THAN PRINTING, DELIBERATELY. Called as `M="$(ident_mutant ...)"`
# it runs in a SUBSHELL, so every `bad` it reports increments a `fails` that is discarded —
# a builder that failed would return an empty path, the caller's `[ -n "$M" ]` would skip
# the whole battery, and four unrun cells would read exactly like four that passed.
# Measured here: the first version did that, and the fixture reported PASS with mutants Z
# and M never built.
IDENT_MUT=""
ident_mutant() {
  local lab="$1"
  local anchor="$2"
  local out="$WORK/ident-mutant-$lab.sh"
  IDENT_MUT=""
  if [ "$(grep -cF "$anchor" "$VALIDATOR")" != "1" ]; then
    bad "H MUTATION $lab: the anchor '$anchor' is not unique in the validator, so the mutation could land on the other emitter and score a kill it did not earn"
    return 1
  fi
  awk -v A="$anchor" '
    index($0, A)                                                    { print; hit=1; next }
    hit && (index($0,"retro dir:") || index($0,"enforcement surface:")) { next }
                                                                    { hit=0; print }
  ' "$VALIDATOR" > "$out"
  if cmp -s "$VALIDATOR" "$out"; then
    bad "H MUTATION $lab: the mutant is byte-identical to the original — the mutation matched nothing and a green run below would prove only that"
    return 1
  fi
  if ! bash -n "$out" 2>/dev/null; then
    bad "H MUTATION $lab: the mutant is not a valid shell script, so its silence would score as a kill"
    return 1
  fi
  IDENT_MUT="$out"
  return 0
}

if [ "$IDENT_CTL_OK" = "1" ]; then
  # MUTANT H-Z: the zero-gate identity block alone is removed.
  if ident_mutant z ', 0 gates declared, 0 dormant"'; then
    MZ="$IDENT_MUT"
    if ident_holds "$MZ" "$IDENT_BODY_ZERO" '0 gates declared'; then
      bad "H MUTANT Z SURVIVED — the zero-gate exit still satisfies H1 with its identity block deleted, so H1 is not testing that emitter"
    else
      ok "H MUTANT Z killed — deleting the zero-gate identity block alone makes two different trees indistinguishable ($IDENT_WHY)"
    fi
    if ident_holds "$MZ" "$IDENT_BODY_GATES" '2 gates declared'; then
      ok "H MUTANT Z leaves the MAIN verdict intact — the mutation is site-specific, not a sed that edited both byte-identical blocks"
    else
      bad "H MUTANT Z ALSO broke the main verdict ($IDENT_WHY) — the mutation hit both emitters and H1/H2 are entangled"
    fi
  fi

  # MUTANT H-M: the main verdict's identity block alone is removed.
  if ident_mutant m '${unique_count} gates declared'; then
    MM="$IDENT_MUT"
    if ident_holds "$MM" "$IDENT_BODY_GATES" '2 gates declared'; then
      bad "H MUTANT M SURVIVED — the main verdict still satisfies H2 with its identity block deleted, so H2 is not testing that emitter"
    else
      ok "H MUTANT M killed — deleting the main identity block alone makes two different trees indistinguishable ($IDENT_WHY)"
    fi
    if ident_holds "$MM" "$IDENT_BODY_ZERO" '0 gates declared'; then
      ok "H MUTANT M leaves the ZERO-GATE exit intact — the mutation is site-specific"
    else
      bad "H MUTANT M ALSO broke the zero-gate exit ($IDENT_WHY) — the mutation hit both emitters and H1/H2 are entangled"
    fi
  fi

  # MUTANT H-A: the ABSENT-RETRO exit's identity line alone is removed. Its anchor is the
  # ONLY thing that separates it from the :145 block — `0 dormant (no ` where the other
  # closes the quote after `dormant` — so this is the third leg of the same
  # anchor-on-what-separates-them argument, and the two cross-checks below are what prove
  # the deletion did not reach either sibling.
  if ident_mutant a '0 dormant (no '; then
    MA="$IDENT_MUT"
    if ident_holds "$MA" "$IDENT_BODY_ZERO" '0 dormant (no ' 'no-such-retro'; then
      bad "H MUTANT A SURVIVED — the absent-retro exit still satisfies H3 with its surface line deleted, so H3 is not testing that emitter"
    else
      ok "H MUTANT A killed — deleting the absent-retro exit's surface line alone makes two different surfaces indistinguishable ($IDENT_WHY)"
    fi
    if ident_holds "$MA" "$IDENT_BODY_ZERO" '0 gates declared' \
       && ident_holds "$MA" "$IDENT_BODY_GATES" '2 gates declared'; then
      ok "H MUTANT A leaves the OTHER TWO emitters intact — the mutation is site-specific across all three"
    else
      bad "H MUTANT A ALSO broke another emitter ($IDENT_WHY) — the three identity blocks are not separably anchored"
    fi
  fi

  # MUTANT H-T: the alias-table line alone is removed. H4b MUST go red and the two scanned
  # roots must stay named — the suppression channel is asserted by an arm that neither of
  # the root arms covers.
  MT="$WORK/ident-mutant-t.sh"
  if [ "$(grep -cF 'alias table:' "$VALIDATOR")" != "1" ]; then
    bad "H MUTANT T: 'alias table:' is not unique in the validator, so the deletion could land elsewhere"
  else
    awk 'index($0,"alias table:") { next } { print }' "$VALIDATOR" > "$MT"
    if cmp -s "$VALIDATOR" "$MT"; then
      bad "H MUTANT T: the deletion matched nothing — H4b would prove only that"
    elif ! bash -n "$MT" 2>/dev/null; then
      bad "H MUTANT T is not a valid shell script, so its silence would score as a kill"
    else
      IDENT_ALIAS='aliases.txt'
      MT_A="$(ident_corpus "$IDENT_BODY_GATES")"
      MT_RC="$(ident_run "$MT" "$MT_A" 'docs/retro' "$WORK/ident-mt.txt")"
      IDENT_ALIAS=""
      if [ "$MT_RC" = "0" ] && grep -qF "$MT_A/aliases.txt" "$WORK/ident-mt.txt"; then
        bad "H MUTANT T SURVIVED — the alias table is still named with its line deleted, so H4b is keyed on a path emitted somewhere else"
      else
        ok "H MUTANT T killed — deleting the alias-table line alone leaves the suppression channel unidentified (rc=$MT_RC)"
      fi
      if ident_holds "$MT" "$IDENT_BODY_GATES" '2 gates declared'; then
        ok "H MUTANT T leaves the two scanned roots named — H4b owns the alias table and H2 owns the roots"
      else
        bad "H MUTANT T ALSO broke the root identity ($IDENT_WHY) — H2 and H4b are entangled"
      fi
    fi
  fi

  # MUTANT H-E: the alias table is echoed at BOTH early exits, from the environment variable
  # rather than the resolved one — the exact wrong fix H6 exists to forbid, and the reason
  # H6 is worth having as an absence-shaped arm. The mutant reads `AI_DLC_CI_ALIAS_TABLE`
  # because `ALIAS_TABLE_FILE` is not assigned until :175; echoing the resolved variable
  # there would print empty and the mutation would be a silent no-op.
  ME="$WORK/ident-mutant-e.sh"
  awk '
    index($0,"0 dormant (no ")            { print; print "  echo \"  alias table:          ${AI_DLC_CI_ALIAS_TABLE:-(none set)}\""; next }
    index($0,", 0 gates declared, 0 dormant\"") { print; print "  echo \"  alias table:          ${AI_DLC_CI_ALIAS_TABLE:-(none set)}\""; next }
                                          { print }
  ' "$VALIDATOR" > "$ME"
  if cmp -s "$VALIDATOR" "$ME"; then
    bad "H MUTANT E: the injection matched nothing — H6 is unproved"
  elif ! bash -n "$ME" 2>/dev/null; then
    bad "H MUTANT E is not a valid shell script, so its silence would score as a kill"
  else
    IDENT_ALIAS='aliases.txt'
    ME_A="$(ident_corpus "$IDENT_BODY_ZERO")"
    ME_RC1="$(ident_run "$ME" "$ME_A" 'docs/retro' "$WORK/ident-me-zero.txt")"
    ME_RC2="$(ident_run "$ME" "$ME_A" 'no-such-retro' "$WORK/ident-me-absent.txt")"
    IDENT_ALIAS=""
    if grep -qF "$ME_A/aliases.txt" "$WORK/ident-me-zero.txt" \
       && grep -qF "$ME_A/aliases.txt" "$WORK/ident-me-absent.txt"; then
      ok "H MUTANT E killed — with the alias table echoed at both early exits (rc=$ME_RC1/$ME_RC2) H6 fires, so H6 is a real constraint and not a vacuous absence"
    else
      bad "H MUTANT E SURVIVED — the early exits still do not name the alias table after it was injected there, so H6 could never fire"
    fi
  fi

  # MUTANT H-N: identity replaced by a NONCE. This is the fix that DISCRIMINATES WITHOUT
  # NAMING — two runs differ, and neither says which tree was read. An arm keyed only on
  # "the outputs differ" passes against it, which is why the arm demands the path.
  # The nonce is `$$-$RANDOM`, evaluated by the MUTANT at run time, so two runs of it
  # differ from each other exactly as two runs of the real validator do — and neither
  # carries a path. A nonce fixed at mutation time would fail this arm on the cmp, which
  # tests nothing.
  MN="$WORK/ident-mutant-n.sh"
  awk '
    index($0,"retro dir:")           { print "echo \"  retro dir:            nonce-$$-$RANDOM\""; next }
    index($0,"enforcement surface:") { print "echo \"  enforcement surface:  nonce-$$-$RANDOM\""; next }
                                     { print }
  ' "$VALIDATOR" > "$MN"
  if cmp -s "$VALIDATOR" "$MN"; then
    bad "H MUTANT N: the nonce substitution matched nothing — the arm's nonce-resistance is unproved"
  elif ! bash -n "$MN" 2>/dev/null; then
    bad "H MUTANT N is not a valid shell script, so its silence would score as a kill"
  else
    if ident_holds "$MN" "$IDENT_BODY_ZERO" '0 gates declared'; then
      bad "H MUTANT N SURVIVED — a per-site constant that names no corpus satisfies H1, so H1 is a differ-check rather than a naming check"
    else
      ok "H MUTANT N killed — a per-run nonce varies the output exactly as the real roots do and still fails the arm, so H1 demands the corpus be NAMED and not merely varied ($IDENT_WHY)"
    fi
  fi
fi

echo
[ "$fails" -eq 0 ] && { echo "ci-gates-resolution: PASS"; exit 0; }
echo "ci-gates-resolution: $fails assertion(s) violated." >&2
exit 1
