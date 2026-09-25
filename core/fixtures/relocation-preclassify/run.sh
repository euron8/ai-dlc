#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# relocation-preclassify — preclassify.sh detects the pre-0.126.0 validators at the OLD
# path, distinguishes a locally edited copy from an identical one, and is silent on the
# consumer's own scripts.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the check regressed, 2 = fixture broken.
#
# THE DEFECT THIS EXISTS TO CATCH.
#
# v0.126.0 moved the core validators scripts/ -> scripts/ai-dlc/. On a consumer that has
# not migrated, every copy is still at scripts/X, and preclassify was blind to all of them:
#
#   - map_consumer() sends core/scripts/X to scripts/ai-dlc/X, which is EMPTY there, so the
#     changed-files pass read the upstream-modified validators as `consumer-deleted` and
#     filed each a CLASSIFY row — a semantic-merge task for a file nobody deleted and apply
#     moves mechanically. The UNCHANGED validators are not in the base..theirs diff at all,
#     so that pass never named them.
#   - unregistered-drift.sh excludes scripts/ by design.
#
# So a locally edited validator at the old path produced NO row a report could show, and a
# live dry-run asserted OURS==BASE for all 25 against a comparison that never ran — the
# unsafe direction, because apply then overwrites the local adaptation with nothing said.
#
# Assertion B is the one that matters: the edited copy must surface, distinctly, so the
# report can disclose that apply is about to discard it. The move itself is not in dispute
# (apply-legacy-script-path owns that); being SEEN is.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"

for cand in "$ROOT/core/skills/ai-dlc-update/reconcile" "$ROOT/.claude/skills/ai-dlc-update/reconcile"; do
  [ -f "$cand/preclassify.sh" ] && RECON="$cand" && break
done
[ -n "${RECON:-}" ] || { echo "FIXTURE ERROR: reconcile/preclassify.sh not found in either layout" >&2; exit 2; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/reloc-pc.XXXXXX")" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd)"
trap 'rm -rf "$WORK"' EXIT

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

# --- a synthetic distribution, two commits ------------------------------------
# Three validators upstream ships under core/scripts/. One is MODIFIED between base and
# theirs; the other two are UNCHANGED — they must still be detected, because the pass is
# level-triggered, not keyed on the base..theirs diff. A base..theirs pass would miss them.
DIST="$WORK/dist"
mkdir -p "$DIST/core/scripts" || exit 2
git -C "$DIST" init -q 2>/dev/null || { echo "FIXTURE ERROR: git init failed" >&2; exit 2; }
gitc() { git -C "$DIST" -c user.email=f@f -c user.name=fixture "$@"; }

printf '#!/usr/bin/env bash\necho A base\n'  > "$DIST/core/scripts/validate-alpha.sh"
printf '#!/usr/bin/env bash\necho B\n'       > "$DIST/core/scripts/validate-beta.sh"
printf '#!/usr/bin/env bash\necho C\n'       > "$DIST/core/scripts/validate-gamma.sh"
printf '1.0.0\n' > "$DIST/VERSION"
gitc add -A && gitc commit -q -m base
BASE="$(git -C "$DIST" rev-parse HEAD)"

# theirs: only alpha changes. beta/gamma are byte-identical to base.
printf '#!/usr/bin/env bash\necho A theirs\n' > "$DIST/core/scripts/validate-alpha.sh"
printf '2.0.0\n' > "$DIST/VERSION"
gitc add -A && gitc commit -q -m theirs
THEIRS="$(git -C "$DIST" rev-parse HEAD)"

# --- a pre-relocation consumer ------------------------------------------------
# All three validators loose in scripts/ (nothing in scripts/ai-dlc/ yet). alpha is
# locally EDITED; beta/gamma are pristine copies of base. Plus a consumer-authored script
# that shares the directory and must never be mentioned — scripts/ is shared, and a
# find-the-directory pass would indict it.
CONS="$WORK/consumer"
mkdir -p "$CONS/.claude" "$CONS/scripts" || exit 2
cp "$DIST/core/scripts/validate-beta.sh"  "$CONS/scripts/"
cp "$DIST/core/scripts/validate-gamma.sh" "$CONS/scripts/"
git -C "$DIST" show "$BASE:core/scripts/validate-alpha.sh" > "$CONS/scripts/validate-alpha.sh"
printf '# LOCAL EDIT made while the old layout permitted it\n' >> "$CONS/scripts/validate-alpha.sh"
printf '#!/usr/bin/env bash\necho mine\n' > "$CONS/scripts/audit-dormant-gates.sh"
printf 'version: 1.0.0\ncommit: %s\n' "$BASE" > "$CONS/.claude/.ai-dlc-version"

run_pc() { bash "$1/preclassify.sh" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>/dev/null; }

echo "relocation-preclassify"
PC="$(run_pc "$RECON")"

row_bucket() { # row_bucket <cons-rel> -> the bucket string, or empty
  printf '%s\n' "$PC" | awk -F'\t' -v c="$1" '$3==c {print $4}'
}

# --- A. the identical unchanged copies are RELOCATE-MOVE -----------------------
# gamma never changed between base and theirs and so is absent from the diff; only a
# level-triggered pass can see it. beta likewise.
for v in validate-beta.sh validate-gamma.sh; do
  b="$(row_bucket "scripts/$v")"
  case "$b" in
    RELOCATE-MOVE\ *|RELOCATE-MOVE) ok "$v (identical, unchanged-in-range) → RELOCATE-MOVE" ;;
    *) bad "$v should be RELOCATE-MOVE, got '${b:-<no row>}'" ;;
  esac
done

# --- B. THE EDITED COPY IS FLAGGED, DISTINCTLY --------------------------------
b="$(row_bucket "scripts/validate-alpha.sh")"
case "$b" in
  RELOCATE-MOVE+consumer-edited*) ok "validate-alpha.sh (locally edited) → RELOCATE-MOVE+consumer-edited — the disclosure the report was missing" ;;
  *) bad "the edited validator must be RELOCATE-MOVE+consumer-edited, got '${b:-<no row>}'" ;;
esac

# --- C. no spurious CLASSIFY row for any core/scripts path --------------------
# The false consumer-deleted verdict is exactly the semantic-merge noise this replaces.
n="$(printf '%s\n' "$PC" | awk -F'\t' '$2 ~ /^core\/scripts\// && $4 ~ /CLASSIFY/' | wc -l | tr -d ' ')"
[ "$n" = 0 ] && ok "no core/scripts/* path is filed as a CLASSIFY (semantic-merge) row" \
             || bad "$n core/scripts/* CLASSIFY row(s) survived — the spurious semantic-merge tasks"

# --- D. the consumer's OWN script is never mentioned --------------------------
# Derived from the upstream tree, not from find scripts/. audit-dormant-gates.sh is theirs.
if grep -q . <<<"$(printf '%s\n' "$PC" | awk -F'\t' '$3 ~ /audit-dormant-gates/')"; then
  bad "a consumer-authored script was reported — the pass globbed the shared dir instead of the upstream tree"
else
  ok "the consumer's own scripts/audit-dormant-gates.sh is not mentioned"
fi

# --- E. a MIGRATED copy is NOT a relocation row -------------------------------
# Once the file is at the canonical new path, it is a normal core file and the
# changed-files pass owns it. Move beta across and re-run: its RELOCATE row must vanish.
mkdir -p "$CONS/scripts/ai-dlc" || exit 2
git -C "$DIST" show "$THEIRS:core/scripts/validate-beta.sh" > "$CONS/scripts/ai-dlc/validate-beta.sh"
rm -f "$CONS/scripts/validate-beta.sh"
PC2="$(run_pc "$RECON")"
if grep -q . <<<"$(printf '%s\n' "$PC2" | awk -F'\t' '$2=="core/scripts/validate-beta.sh" && $4 ~ /RELOCATE/')"; then
  bad "a migrated validator still emits a RELOCATE row — the new-path guard is not firing"
else
  ok "a migrated validator (now at scripts/ai-dlc/) emits no RELOCATE row"
fi

# --- F. THE MUTATION TEST — prove the pass is what surfaces the edit -----------
# Delete the ls-tree enumeration line so the relocation pass iterates nothing. The
# edited alpha must then have NO disclosure row at all: either it falls back to the old
# false-CLASSIFY, or it vanishes entirely. Anything but a surviving
# RELOCATE-MOVE+consumer-edited proves the pass is load-bearing.
MUT="$WORK/mutant"
cp -R "$RECON" "$MUT" || exit 2
# Neutralize the subject-set generator: an empty `done < <(true)` feeds the loop nothing.
# The enumerator line carries its own status check after `2>/dev/null`, so the match runs to the
# end of that line rather than stopping at the redirect.
perl -0pi -e 's{done < <\(git -C "\$DIST" ls-tree --name-only "\$THEIRS" core/scripts/ 2>/dev/null[^\n]*\)\n}{done < <(true)\n}' "$MUT/preclassify.sh" || exit 2
if grep -q 'ls-tree --name-only "$THEIRS" core/scripts/' "$MUT/preclassify.sh"; then
  echo "FIXTURE ERROR: mutation did not take — the ls-tree enumerator line was not rewritten" >&2
  exit 2
fi
# Restore beta to the pre-migration state so the mutant sees the same tree assertion B did.
git -C "$DIST" show "$BASE:core/scripts/validate-beta.sh" > "$CONS/scripts/validate-beta.sh"
rm -rf "$CONS/scripts/ai-dlc"
PCM="$(run_pc "$MUT")"
bm="$(printf '%s\n' "$PCM" | awk -F'\t' '$3=="scripts/validate-alpha.sh" {print $4}')"
case "$bm" in
  RELOCATE-MOVE+consumer-edited*)
    bad "MUTATION: the edit still surfaced with the enumerator gone — the row comes from somewhere else, assertion B proves nothing" ;;
  *)
    ok "MUTATION: with the enumerator removed the edit disclosure disappears (got '${bm:-<no row>}') — the pass is what produces it" ;;
esac

# --- G. A PRE-RELOCATION CONSUMER PULLING A core/scripts/* DELETION IS ZERO WORK, NOT A REFUSAL ---
# THE NEAR-MISS FOR THE EMPTY-RESULT GUARD. emit-report and apply refuse an EMPTY row set while
# base..theirs moves core/, because preclassify used to go silent under a git failure. This is the
# one legitimate pull that USED to print zero rows over such a range: its only core/ change deletes
# core/scripts/x.sh, and the consumer still holds scripts/x.sh at the old path. The relocation pass
# enumerates theirs, where x.sh is gone, and the changed-files pass skipped the pre-relocation path
# with a bare `continue` -- so emit-report refused five sections and apply stopped on a pull with
# nothing to do, and no re-run could clear it. preclassify now emits an inert PRE-RELOCATION-NOOP
# row there. apply's half of this world is apply-drift-refile arm h.
#
# Its OWN world: the range above changes a validator's content, so it cannot host a zero-row pull.
#
# G is one arm with two conjuncts: the row is printed, and the render carries no preclassify
# refusal. The mutant below restores the silent skip and must fail G and move nothing A-F read:
# A-F read only the main world's preclassify output, and over that world the mutant's output is
# asserted byte-identical to the subject's once the PRE-RELOCATION-NOOP rows are removed.
case "$RECON" in */core/skills/ai-dlc-update/reconcile) G_DIST=1 ;; *) G_DIST=0 ;; esac
G_RUN=1
if ! grep -qF 'PRE-RELOCATION-NOOP' "$RECON/preclassify.sh"; then
  if [ "$G_DIST" = 0 ]; then
    printf '  SKIP  G -- the installed preclassify.sh predates PRE-RELOCATION-NOOP; it lands with the pull that carries this fixture\n'
    G_RUN=0
  else
    printf '  --    (G: this preclassify.sh carries no PRE-RELOCATION-NOOP row; in the distribution the arm runs anyway and must go red)\n'
  fi
fi
if [ "$G_RUN" = 1 ]; then
  ZD="$WORK/zr-dist"; ZC="$WORK/zr-consumer"
  mkdir -p "$ZD/core/scripts" "$ZD/core/rules" "$ZC/scripts" "$ZC/.claude/rules" || exit 2
  zg() { git -C "$ZD" -c user.email=f@f -c user.name=fixture "$@" >/dev/null 2>&1; }
  printf '#!/usr/bin/env bash\necho x\n' > "$ZD/core/scripts/x.sh"
  printf 'rule\n' > "$ZD/core/rules/r.md"; printf '0.1.0\n' > "$ZD/VERSION"
  { zg init -q && zg add -A && zg commit -q -m base; } || { echo "FIXTURE ERROR: G base commit failed" >&2; exit 2; }
  ZB="$(git -C "$ZD" rev-parse HEAD)"
  printf '0.2.0\n' > "$ZD/VERSION"
  { zg rm -q core/scripts/x.sh && zg commit -qam theirs; } || { echo "FIXTURE ERROR: G theirs commit failed" >&2; exit 2; }
  ZT="$(git -C "$ZD" rev-parse HEAD)"
  cp "$ZD/core/rules/r.md" "$ZC/.claude/rules/r.md" 2>/dev/null || git -C "$ZD" show "${ZB}:core/rules/r.md" > "$ZC/.claude/rules/r.md"
  git -C "$ZD" show "${ZB}:core/scripts/x.sh" > "$ZC/scripts/x.sh"
  printf 'version: 0.1.0\ncommit: %s\n' "$ZB" > "$ZC/.claude/.ai-dlc-version"
  # The world must be the one described: exactly one core/ change, a deletion under core/scripts/,
  # and theirs shipping NO core/scripts/ file the relocation pass could emit a row for.
  _zr="$(git -C "$ZD" diff --no-renames --name-status "$ZB" "$ZT" -- core/)"
  _zt="$(git -C "$ZD" ls-tree --name-only "$ZT" core/scripts/)"
  if [ "$_zr" != "$(printf 'D\tcore/scripts/x.sh')" ] || [ -n "$_zt" ] || [ ! -f "$ZC/scripts/x.sh" ] || [ -e "$ZC/scripts/ai-dlc/x.sh" ]; then
    echo "FIXTURE ERROR: G world is not a lone core/scripts/ deletion pulled by a pre-relocation consumer (range: $(printf '%s' "$_zr" | tr '\t\n' ' '))" >&2
    exit 2
  fi
  # g_score <recon-dir> <tag> -> empty, or what failed
  g_score() {
    local _m="" _rows _rc _n
    _rows="$(bash "$1/preclassify.sh" "$ZD" "$ZB" "$ZT" "$ZC" 2>/dev/null)"; _rc=$?
    [ "$_rc" -eq 0 ] || _m="${_m}preclassify-rc=$_rc "
    printf '%s\n' "$_rows" | LC_ALL=C awk -F'\t' '$1=="D" && $2=="core/scripts/x.sh" && $4=="PRE-RELOCATION-NOOP" {f=1} END {exit !f}' \
      || _m="${_m}no-PRE-RELOCATION-NOOP-row "
    bash "$1/emit-report.sh" "$ZD" "$ZB" "$ZC" "$ZT" > "$WORK/g-$2.md" 2>/dev/null
    grep -qF 'BEGIN GENERATED: reconcile-mechanical' "$WORK/g-$2.md" || _m="${_m}no-region "
    _n="$(grep -cF 'DETECTOR-REFUSED  preclassify.sh' "$WORK/g-$2.md")" || _n=0
    [ "$_n" = 0 ] || _m="${_m}render-refusals=$_n "
    printf '%s' "$_m"
  }
  g="$(g_score "$RECON" tip)"
  if [ -z "$g" ]; then
    ok "G a pre-relocation consumer pulling a lone core/scripts/ deletion gets a PRE-RELOCATION-NOOP row, and the render carries 0 preclassify refusals"
  else
    bad "G the zero-work pre-relocation pull was not classified as zero work: $g"
  fi

  # THE MUTANT: the emitted row removed, restoring the silent `continue`.
  GM="$WORK/g-mutant"
  cp -R "$RECON" "$GM" || exit 2
  _ga="$(printf '        printf %s %s %s %s %s\n' "'%s\\t%s\\t%s\\t%s\\n'" '"$status"' '"$path"' '"$cons"' '"PRE-RELOCATION-NOOP"')"
  _gh="$(grep -cxF "$_ga" "$RECON/preclassify.sh")" || _gh=0
  _gc="$(grep -cxF 'ZZ-NO-SUCH-PRECLASSIFY-LINE-ZZ' "$RECON/preclassify.sh")" || _gc=0
  G_A="$_ga" awk '$0 == ENVIRON["G_A"] { next } { print }' "$RECON/preclassify.sh" > "$GM/preclassify.sh"
  if [ "$_gh" -ne 1 ] || [ "$_gc" -ne 0 ]; then
    bad "FIXTURE STALE [G mutant]: the row-emitter anchor matches $_gh lines of preclassify.sh (want 1; impossible-anchor control $_gc, want 0). Re-anchor on the same observable"
  elif cmp -s "$RECON/preclassify.sh" "$GM/preclassify.sh" || ! bash -n "$GM/preclassify.sh"; then
    bad "FIXTURE STALE [G mutant]: the mutation did not apply or does not parse"
  else
    gm="$(g_score "$GM" mutant)"
    # Subject and mutant over the SAME current main world. Not against `$PC`: E and F have moved
    # the consumer since `$PC` was taken, so that comparison would read the world's movement.
    # The main world ALSO carries a PRE-RELOCATION-NOOP row (alpha is modified in range and sits
    # at the old path), which the mutant rightly drops. A-F never read that row -- they key on the
    # old-path consumer column and on CLASSIFY -- so the mutant may differ by exactly those rows
    # and nothing else.
    _gs="$(run_pc "$RECON")"
    _gs_rest="$(printf '%s\n' "$_gs" | LC_ALL=C awk -F'\t' '$4 != "PRE-RELOCATION-NOOP"')"
    if [ -z "$_gs_rest" ]; then
      bad "FIXTURE BROKEN [G mutant]: the subject classified nothing else over the main world, so the comparison below compares empty to empty"
    elif [ "$(printf '%s\n' "$(run_pc "$GM")")" != "$_gs_rest" ]; then
      bad "MUTANT [G] moved main-world rows OTHER than PRE-RELOCATION-NOOP, so it reaches arms A-F -- entangled"
    elif ! grep -qF 'BEGIN GENERATED: reconcile-mechanical' "$WORK/g-mutant.md"; then
      bad "MUTANT HARNESS BROKEN [G]: the copy rendered no region, so its verdict is a copy that did not run"
    elif [ -z "$gm" ]; then
      bad "MUTANT SURVIVED [G]: with the row removed, G still passed -- it cannot see the silent skip"
    else
      ok "MUTANT (PRE-RELOCATION-NOOP row removed) fails G ($gm) and leaves every other main-world row, which A-F read, byte-identical"
    fi
  fi
fi

echo ""
if [ "$fails" -eq 0 ]; then
  echo "relocation-preclassify: PASS"
  exit 0
fi
echo "relocation-preclassify: FAIL ($fails assertion(s))"
exit 1
