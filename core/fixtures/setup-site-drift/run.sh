#!/usr/bin/env bash
# setup-site-drift — §7v criterion 5 as a program: a core file carrying a declared setup site
# must equal `theirs` everywhere OUTSIDE that file's declared spans.
#
# THE DEFECT THIS EXISTS TO CATCH, measured on the reference consumer during the 0.297.0 ->
# 0.300.0 hop and not synthesised here: `deploy-validate.md` kept OURS at a line outside both of
# its declared spans, and the line it kept prescribed the OLD artifact-path grammar the same
# release had replaced. **The failure direction is upstream content NOT ARRIVING** — the pull
# reports success and the consumer is quietly behind. It surfaced only because a different check
# (`HARD-CORE-BEHIND`) flagged it, which is the safety net working rather than the mechanism.
#
# AND THE RULE ALREADY EXISTED. §7v criterion 5 states it exactly, was untangle-only, and had
# already reported PASS on an instance of it. Prose executed by the agent that performed the
# transform is not a check; that is what these arms replace.
#
# EVERY ARM ASSERTS A LINE, NOT A COUNT. The verdict rows name `<file>:<line>`, and the arms read
# those rows — a check reporting "1 drift" while pointing at the wrong line is a check that sends
# the operator to the wrong file.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }

SSD="$(pick "$HERE/../../skills/ai-dlc-update/reconcile/setup-site-drift.sh" \
            "$HERE/../../../.claude/skills/ai-dlc-update/reconcile/setup-site-drift.sh" \
            "$HERE/../../core/skills/ai-dlc-update/reconcile/setup-site-drift.sh")"
[ -n "$SSD" ] || { echo "FIXTURE ERROR: cannot locate setup-site-drift.sh" >&2; exit 2; }
RECONCILE="$(cd "$(dirname "$SSD")" && pwd)"

fails=0; asserts=0
ok()  { asserts=$((asserts+1)); printf '  ok    %s\n' "$1"; }
bad() { asserts=$((asserts+1)); fails=$((fails+1)); printf '  FAIL  %s\n' "$1"; }

echo "setup-site-drift:"

# =============================================================================
# A SELF-CONTAINED DIST + CONSUMER. The script reads its own reconcile/ directory
# for the declaration and map_consumer(), and reads `theirs` out of a git repo —
# so the fixture builds both rather than pointing at the live tree, which would
# make every assertion here depend on the reference consumer's current state.
# =============================================================================
W="$(mktemp -d "${TMPDIR:-/tmp}/ssd-fx-XXXXXX")"
trap 'rm -rf "$W"' EXIT
DIST="$W/dist"; CONS="$W/consumer"
mkdir -p "$DIST/core/team-roles" "$DIST/core/skills/ai-dlc/steps"
mkdir -p "$CONS/.claude/team-roles" "$CONS/.claude/skills/ai-dlc/steps"

# THEIRS. `deploy-validate.md` carries the two real single-line sites, including the `^(.+)$`
# one that needs an `after_line` anchor, plus a `{token}` HTML comment ABOVE the real site —
# the decoy that a greedy locator picked instead, and got wrong.
cat > "$DIST/core/skills/ai-dlc/steps/deploy-validate.md" <<'EOF'
# Deploy and validate

<!-- {deploy_command} is filled in by ai-dlc-setup -->

Audit: carry-over accounting MUST appear in
`_bmad-output/implementation-artifacts/s<N>/*.md` files
committed during the sprint.

### 2. Deploy

Run the project's deployment command:
```
{deploy_command}
```

### 3. Smoke Tests

Run live smoke tests and **capture output**:
```bash
{smoke_test_command} 2>&1 | tee test-results/smoke-test-output.txt
```
EOF
cat > "$DIST/core/team-roles/dev.md" <<'EOF'
# dev

## Ownership
{ownership_paths}

## Responsibilities
Write the code.
EOF
# The declaration names five sites across four files, and a file THEIRS does not have at all is
# a hard error rather than a skip — a pull cannot have overwritten a file from a version that
# does not contain it. So every declared file exists here; the CONSUMER is the side allowed to
# be missing one, which the ABSENT row covers.
cp "$DIST/core/team-roles/dev.md" "$DIST/core/team-roles/qa.md"
cat > "$DIST/core/skills/ai-dlc/steps/implementation.md" <<'EOF'
# implementation

### 5. Begin Implementation

- Dev teammates — mandatory evidence: run live smoke tests
  ({smoke_test_command}) and log output in the story file.
  Unit tests alone are not sufficient.
EOF

( cd "$DIST" && git -c init.defaultBranch=main init -q . \
  && git config user.email f@example.com && git config user.name Fixture \
  && git config commit.gpgsign false && git add -A && git commit -q -m theirs ) || {
  echo "FIXTURE ERROR: could not build the dist repo" >&2; exit 2; }
THEIRS="$(cd "$DIST" && git rev-parse HEAD)"

# A CONSUMER THAT REINJECTED CORRECTLY: differs from theirs at the two site lines and the
# heading block, and nowhere else.
seed_good() {
  sed -e 's|^{deploy_command}$|scripts/ecs-deploy.sh <service>|' \
      -e 's|^{smoke_test_command} |scripts/test-aws-smoke.sh |' \
      "$DIST/core/skills/ai-dlc/steps/deploy-validate.md" \
      > "$CONS/.claude/skills/ai-dlc/steps/deploy-validate.md"
  sed 's|^{ownership_paths}$|src/**\ninfra/**|' "$DIST/core/team-roles/dev.md" \
      > "$CONS/.claude/team-roles/dev.md"
}
seed_good

run() { bash "$SSD" "$DIST" "$CONS" "$THEIRS" 2>&1; }

# =============================================================================
# 1. THE CLEAN CASE. Values filled in at every declared site, nothing else moved.
# =============================================================================
OUT="$(run)"; RC=$?
[ "$RC" -eq 0 ] && ok "a correctly-reinjected consumer exits 0" \
                || { bad "a correct consumer exited $RC"; printf '%s\n' "$OUT" | sed 's/^/        /'; }
grep -q 'SETUP-SITE-DRIFT' <<<"$OUT" && bad "a correct consumer was reported as drifted" \
                                     || ok "...and reports no drift"
# THE CONTROL ON THAT ZERO. A run that resolved no site, or compared no file, prints the same
# clean sheet.
grep -qE 'SETUP-SITE-SCANNED.*[1-9][0-9]* declared site' <<<"$OUT" \
  && ok "the scanned count is reported and non-zero — the control on the clean sheet above" \
  || bad "no non-zero scanned count: the clean sheet above could be a run that read nothing"
grep -q 'deploy-validate.md' <<<"$OUT" && ok "the sited file appears in the verdict rows" \
                                       || bad "the sited file is absent from the output entirely"

# =============================================================================
# 2. THE MEASURED DEFECT, REPRODUCED. One line outside every declared span kept
#    from OURS — the artifact-path line, exactly as the reference consumer had it.
# =============================================================================
seed_good
sed -i.bak 's|`_bmad-output/implementation-artifacts/s<N>/\*\.md` files|`_bmad-output/implementation-artifacts/sprint-<N>-*.md` files|' \
  "$CONS/.claude/skills/ai-dlc/steps/deploy-validate.md"
if cmp -s "$CONS/.claude/skills/ai-dlc/steps/deploy-validate.md.bak" \
          "$CONS/.claude/skills/ai-dlc/steps/deploy-validate.md"; then
  bad "FIXTURE ERROR: the defect seed matched nothing, so the arms below prove nothing"
else
  rm -f "$CONS/.claude/skills/ai-dlc/steps/deploy-validate.md.bak"
  OUT="$(run)"; RC=$?
  [ "$RC" -eq 1 ] && ok "a line retained from OURS outside every declared span exits 1" \
                  || bad "the reproduced defect exited $RC, expected 1"
  if grep -qE 'SETUP-SITE-DRIFT.*deploy-validate\.md:6' <<<"$OUT"; then
    ok "...and names the exact LINE, not just the file"
  else
    bad "the drift row does not name line 6"; printf '%s\n' "$OUT" | sed 's/^/        /'
  fi
  grep -q 's<N>/' <<<"$OUT" \
    && ok "...and quotes what THEIRS has there, so the operator can act without re-diffing" \
    || bad "the drift row does not show theirs' content"
fi

# =============================================================================
# 3. THE TWO DIRECTIONS THAT ARE NOT A CHANGED LINE. A setup value REPLACES a
#    line; an insertion or a deletion outside a heading block is drift whatever
#    it contains, and a `c`-only check sees neither.
# =============================================================================
seed_good
printf 'a line theirs does not have\n' >> "$CONS/.claude/skills/ai-dlc/steps/deploy-validate.md"
OUT="$(run)"; RC=$?
[ "$RC" -eq 1 ] && grep -q 'SETUP-SITE-DRIFT' <<<"$OUT" \
  && ok "a line ADDED outside every declared span is drift" \
  || bad "an added line outside every span was not reported"

seed_good
sed -i.bak '/^### 3. Smoke Tests$/d' "$CONS/.claude/skills/ai-dlc/steps/deploy-validate.md"
rm -f "$CONS/.claude/skills/ai-dlc/steps/deploy-validate.md.bak"
OUT="$(run)"; RC=$?
[ "$RC" -eq 1 ] && grep -q 'SETUP-SITE-DRIFT' <<<"$OUT" \
  && ok "a line REMOVED outside every declared span is drift" \
  || bad "a removed line outside every span was not reported"

# =============================================================================
# 4. THE HEADING BLOCK MAY CHANGE LENGTH, and must not be reported for it. The
#    consumer's ownership list is genuinely longer than theirs' single token.
# =============================================================================
seed_good
printf 'scripts/**\ndocs/**\n' >> "$W/extra"
awk '/^\{ownership_paths\}$/ { print "src/**"; print "infra/**"; print "scripts/**"; next } { print }' \
  "$DIST/core/team-roles/dev.md" > "$CONS/.claude/team-roles/dev.md"
OUT="$(run)"; RC=$?
if grep -q 'dev.md.*SETUP-SITE-DRIFT' <<<"$OUT" || grep -qE 'SETUP-SITE-DRIFT.*dev\.md' <<<"$OUT"; then
  bad "a heading-block site whose body grew was reported as drift"
else
  ok "a heading-block body may change length without being reported"
fi

# =============================================================================
# 5. MUTANTS. Each removes ONE mechanism and must flip exactly its own arm.
#    Every mutant is a guarded COPY laid down beside the reconcile/ files it
#    reads — the declaration AND preclassify.sh, which owns map_consumer().
#    A lone copy dies at its first resolution and emits nothing, and "no output"
#    otherwise scores as a kill.
# =============================================================================
MUT="$W/mut"
lay() { mkdir -p "$1"; cp "$RECONCILE/setup-sites.md" "$RECONCILE/preclassify.sh" "$1/"; cp "$SSD" "$1/m.sh"; }

# $1 tag  $2 file to mutate: ssd|sites  $3 sed  $4 seeder  $5 test over $out/$rc  $6 claim
mutate() {
  local tag="$1" which="$2" prog="$3" seeder="$4" test_expr="$5" claim="$6"
  local d="$MUT/$tag" src dst out rc
  asserts=$((asserts+1))
  lay "$d"
  if [ "$which" = ssd ]; then src="$SSD"; dst="$d/m.sh"; else src="$RECONCILE/setup-sites.md"; dst="$d/setup-sites.md"; fi
  sed -E "$prog" "$src" > "$dst.new" && mv "$dst.new" "$dst"
  if cmp -s "$src" "$dst"; then
    fails=$((fails+1)); printf '  FAIL  MUTANT %-18s sed matched NOTHING — the mutant IS the original\n' "$tag"; return
  fi
  "$seeder"
  out="$(bash "$d/m.sh" "$DIST" "$CONS" "$THEIRS" 2>&1)"; rc=$?
  if eval "$test_expr"; then printf '  ok    MUTANT %-18s %s\n' "$tag" "$claim"
  else fails=$((fails+1)); printf '  FAIL  MUTANT %-18s did NOT flip: %s\n' "$tag" "$claim"; fi
}

seed_defect() {
  seed_good
  sed -i.bak 's|`_bmad-output/implementation-artifacts/s<N>/\*\.md` files|`_bmad-output/implementation-artifacts/sprint-<N>-*.md` files|' \
    "$CONS/.claude/skills/ai-dlc/steps/deploy-validate.md"
  rm -f "$CONS/.claude/skills/ai-dlc/steps/deploy-validate.md.bak"
}

# Check only the `c` hunks whose line is a site, i.e. stop reporting anything else. This is the
# shape §7v criterion 5 failed in for real: confirm the values look right and declare pass.
mutate 'values-only' ssd \
  's@^          grep -qxF "\$l" "\$TMP/allow" \&\& continue@          continue@' \
  seed_defect \
  '[ "$rc" -eq 0 ]' \
  'checking only that the values look right passes a tree that lost an upstream line'

# Drop the after_line narrowing. The `^(.+)$` site then resolves to seven candidates, and the
# script must say UNLOCATABLE rather than pick one.
mutate 'no-anchor-narrowing' sites \
  's@^    after_line: .*$@    anchor_note: removed@' \
  seed_good \
  '[ "$rc" -eq 1 ] && grep -q "SETUP-SITE-UNLOCATABLE" <<<"$out"' \
  'a site whose match cannot pin one line is reported UNLOCATABLE, never guessed at'

# Empty the declaration. Every span goes away, so a correctly-reinjected consumer would read as
# drifted everywhere — and a parser that silently returned nothing would do the same.
mutate 'no-sites-parsed' ssd \
  's@^  /\^sites:\$/ \{ f=1; next \}@  /^NEVER-MATCHES-THIS:$/ { f=1; next }@' \
  seed_good \
  '[ "$rc" -eq 2 ] && grep -q "parsed ZERO sites" <<<"$out"' \
  'a declaration that parses to nothing refuses to answer instead of reporting a clean tree'

# UNMUTATED CONTROL, from the same directory.
asserts=$((asserts+1))
lay "$MUT/control"
seed_defect
ctl_out="$(bash "$MUT/control/m.sh" "$DIST" "$CONS" "$THEIRS" 2>&1)"; ctl_rc=$?
if [ "$ctl_rc" -eq 1 ] && grep -q 'SETUP-SITE-DRIFT' <<<"$ctl_out"; then
  ok "CONTROL: an unmutated copy beside the same reconcile/ files still reports the defect"
else
  bad "CONTROL: an unmutated copy FAILED (rc=$ctl_rc) — the harness is what is broken, not the mutants"
fi

echo
if [ "$fails" -eq 0 ]; then echo "setup-site-drift: PASS ($asserts assertions)"; exit 0; fi
echo "setup-site-drift: $fails of $asserts assertion(s) FAILED" >&2
exit 1
