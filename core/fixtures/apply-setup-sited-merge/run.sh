#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# Hermetic against ambient AI_DLC_* tunables (enforcement-map I10).
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
# apply-setup-sited-merge -- apply.sh resolves a setup-sited BOTH-CHANGED->CLASSIFY file whose only
# consumer delta is its declared setup values, and hands back every other shape exactly as before.
#
# Usage: run.sh
# Exit:  0 = every assertion holds (or the subject predates the feature: SKIP), 1 = regressed,
#        2 = fixture broken.
#
# THE DEFECT. A file reconcile/setup-sites.md declares carries values ai-dlc-setup filled in, so it
# never byte-matches base and every upstream change to it buckets BOTH-CHANGED->CLASSIFY. apply.sh
# handed each one back as `WORKLIST semantic-merge`, a manual 3-way merge whose whole content was
# "take theirs, keep the values" -- on the reproduced pull, `git merge-file` produced bytes identical
# to the consumer's hand merge for both such files.
#
# THE FIX RESOLVES ONLY WHEN FOUR QUESTIONS, EACH ASKED OF A PROGRAM, ALL SAY YES: (a) against BASE
# this one file differs only inside its spans (setup-site-drift.sh --file), (b) merge-file exits 0,
# (c) the unwritten merge equals theirs outside its spans (--file --ours), (d) theirs added no live
# `{token}` outside an HTML comment. An already-merged file resolves with no content write, accepted
# when re-merging theirs changes nothing, or -- for a re-merge that is ambiguous, a block added beside
# an identical one -- when it equals theirs outside its spans and every span's text is identical at
# base and theirs. Anything else is today's row, byte for byte, with the file untouched.
#
# HOW EACH ARM IS JUDGED. The clean target is compared against an expected file built HERE from
# theirs' bytes with the two site lines replaced by the seeded values -- never against
# setup-site-drift.sh, which is the subject's own oracle. A fallback is judged by the file's bytes,
# inode and mode before and after, AND by the row: literally `WORKLIST<TAB>semantic-merge<TAB><rel>`,
# and byte-identical to the row a REFERENCE copy of the same apply.sh prints for the same world --
# the reference is the shipped program with the merge call replaced by `false`, so it is exactly
# today's arm. Each world is built fresh per drive and records its refs in `.B`/`.T` beside it.
#
# LAYOUTS. reconcile/ is located relative to this file with pick(), never by walking up for a root:
# a walk-up resolves an enclosing real repo when this fixture is extracted under one.
#   distribution / receipt extraction: <root>/core/fixtures/<this> -> <root>/core/skills/...
#   consumer:                          <root>/tests/fixtures/<this> -> <root>/.claude/skills/...
#
# A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECT. A consumer can receive this file one pull before the
# apply.sh it tests, so an absent subject prints SKIP and exits 0 -- never an ok. The probe is keyed
# on the EMISSION site, the `say RESOLVED setup-site-merge` line; a tree that defines
# setup_site_merge() without that line is a respelled subject this grammar cannot see, which FAILS.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
APPLY="$(pick "$HERE/../../skills/ai-dlc-update/reconcile/apply.sh" \
              "$HERE/../../../.claude/skills/ai-dlc-update/reconcile/apply.sh")"
[ -n "$APPLY" ] || { echo "apply-setup-sited-merge: FIXTURE BROKEN -- reconcile/apply.sh not found beside this fixture in either layout" >&2; exit 2; }
REC="$(cd "$(dirname "$APPLY")" && pwd)"
echo "apply-setup-sited-merge: driving $REC/apply.sh"

# --- D10: the subject probe, at the emission site -----------------------------------------------
if ! grep -qF 'say RESOLVED setup-site-merge' "$REC/apply.sh"; then
  if grep -q '^setup_site_merge()' "$REC/apply.sh"; then
    echo "  FAIL  apply.sh defines setup_site_merge() but no line emits \`say RESOLVED setup-site-merge\` -- the row was respelled and this probe can no longer see its subject"
    echo; echo "apply-setup-sited-merge: FAIL (1)"; exit 1
  fi
  echo "SKIP: subject predates setup-site-merge"
  exit 0
fi
for f in setup-site-drift.sh preclassify.sh setup-sites.md retired-tokens.sh unregistered-drift.sh; do
  [ -f "$REC/$f" ] || { echo "apply-setup-sited-merge: FIXTURE BROKEN -- $REC/$f is missing beside apply.sh" >&2; exit 2; }
done

WORK="$(mktemp -d "${TMPDIR:-/tmp}/apply-setup-sited-merge.XXXXXX")" || { echo "apply-setup-sited-merge: FIXTURE BROKEN -- mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/out" || exit 2

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }
broken() { echo "apply-setup-sited-merge: FIXTURE BROKEN -- $1" >&2; exit 2; }

DV=skills/ai-dlc/steps/deploy-validate.md
IM=skills/ai-dlc/steps/implementation.md
QA=team-roles/qa.md
TAB="$(printf '\t')"

# --- the world ---------------------------------------------------------------------------------
# All four declared files exist at base and at theirs in every world except d8add, whose subject
# is a file absent at base. The consumer copies of the files a world does not exercise are at base,
# so only the files a world names are in the pull's range.
seed_base() { # <dist>
  local d="$1"
  mkdir -p "$d/core/skills/ai-dlc/steps" "$d/core/team-roles" "$d/core/scripts" || return 1
  cat > "$d/core/$DV" <<'EOF'
# Deploy and validate

<!-- {deploy_command}: the project's deploy command, filled in by ai-dlc-setup -->

Audit line A.
Write the log to $ROOT/.old-channel.tmp when asked.

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

### 4. Wrap up

Final line.
EOF
  cat > "$d/core/$IM" <<'EOF'
# implementation

### 5. Begin Implementation

- Dev teammates — mandatory evidence: run live smoke tests
  ({smoke_test_command}) and log output in the story file.
  Unit tests alone are not sufficient.

Closing paragraph.
EOF
  cat > "$d/core/team-roles/dev.md" <<'EOF'
# dev

## Ownership
<!-- {ownership_paths}: filled in by ai-dlc-setup -->
{ownership_paths}

## Responsibilities
Write the code.
EOF
  cp "$d/core/team-roles/dev.md" "$d/core/$QA"
  # A real distribution ships core validators and the manifest claims them; with none, apply.sh's
  # manifest expansion is empty and every manifest carries extra rows.
  printf '#!/usr/bin/env bash\necho v\n' > "$d/core/scripts/validate-synthetic.sh"
}
# edit <file> <exact-line> <replacement-line> -- fails when the line is not there exactly once, so a
# seed that matched nothing cannot build a world that silently is not the one named.
edit() {
  local n; n="$(grep -cxF -- "$2" "$1")" || n=0
  [ "$n" = 1 ] || { echo "edit: '$2' found $n time(s) in $1" >&2; return 1; }
  awk -v o="$2" -v r="$3" '$0 == o { print r; next } { print }' "$1" > "$1.e" && mv "$1.e" "$1"
}
fill_dv() { # <file> [deploy|smoke|both]
  case "${2:-both}" in
    deploy) edit "$1" '{deploy_command}' 'scripts/ecs-deploy.sh prod' ;;
    smoke)  edit "$1" '{smoke_test_command} 2>&1 | tee test-results/smoke-test-output.txt' 'scripts/smoke.sh 2>&1 | tee test-results/smoke-test-output.txt' ;;
    both)   fill_dv "$1" deploy && fill_dv "$1" smoke ;;
  esac
}
fill_im() { edit "$1" '  ({smoke_test_command}) and log output in the story file.' '  (scripts/smoke.sh) and log output in the story file.'; }

theirs_edit() { # <variant> <dist>
  local d="$2"
  case "$1" in
    clean|d6a|d8del) edit "$d/core/$DV" 'Audit line A.' 'Audit line A, revised upstream.' ;;
    b1|b1b)  edit "$d/core/$DV" "Run the project's deployment command:" "Run the project's deploy command:" ;;
    b2)      edit "$d/core/$DV" 'Audit line A.' 'Audit line A, revised upstream.' ;;
    b2twin)  edit "$d/core/$DV" 'Audit line A.' 'Audit line A, revised upstream.' \
             && edit "$d/core/$DV" "<!-- {deploy_command}: the project's deploy command, filled in by ai-dlc-setup -->" "<!-- {deploy_command}: the deploy command, as ai-dlc-setup filled it in -->" ;;
    d2)      printf '\nRe-run the deploy if the smoke fails:\n\n    {deploy_command} --retry\n' >> "$d/core/$DV" ;;
    conflict) edit "$d/core/$DV" '{smoke_test_command} 2>&1 | tee test-results/smoke-test-output.txt' '{smoke_test_command} 2>&1 | tee test-results/smoke.txt' ;;
    d6b)     edit "$d/core/$DV" 'Audit line A.' 'Audit line A, revised upstream.' \
             && edit "$d/core/$IM" 'Closing paragraph.' 'Closing paragraph, revised upstream.' ;;
    d8add)   cp "$d/core/team-roles/dev.md" "$d/core/$QA" ;;
    d7)      edit "$d/core/$DV" 'Write the log to $ROOT/.old-channel.tmp when asked.' 'Write the log to $LOGDIR/run.log when asked.' ;;
    # Theirs changes a span INSIDE while the locator still matches: the already-merged shortcut's
    # outside-span check alone reads these as merged and would resolve without merging theirs.
    spanD)   edit "$d/core/$DV" '{deploy_command}' '{deploy_command} --wait' ;;
    spanQ)   edit "$d/core/$QA" '<!-- {ownership_paths}: filled in by ai-dlc-setup -->' '<!-- {ownership_paths}: list every directory QA owns -->' ;;
    # (d)'s pass direction: a shell expansion, a multi-line comment, a comment-only reword.
    dol)     printf '\nExport ${LOGDIR} before the deploy.\n' >> "$d/core/$DV" ;;
    ml)      printf '\n<!-- note for maintainers:\n     run {deploy_command} twice on a cold start -->\n' >> "$d/core/$DV" ;;
    com)     edit "$d/core/$DV" "<!-- {deploy_command}: the project's deploy command, filled in by ai-dlc-setup -->" "<!-- {deploy_command}: the deploy command, filled in by ai-dlc-setup -->" ;;
    # Theirs adds a line INSIDE qa.md's ## Ownership block, a blank line away from the value, so
    # merge-file is clean and the merge must carry it: a shortcut that trusts merge-file's exit
    # without comparing its output reads ours as merged and drops theirs' line.
    spanFar) awk '$0=="## Responsibilities" && !d {print "QA also owns the e2e harness."; print ""; d=1} {print}' "$d/core/$QA" > "$d/x" \
             && mv "$d/x" "$d/core/$QA" ;;
    # Theirs adds a fenced block right after an existing fence. After run 1 merges it, re-merging
    # theirs into the merged file is ambiguous (two identical fence edges), so a run-2 shortcut that
    # demands a no-op merge falls through to (a) and hands back a file it already merged.
    fence)   edit "$d/core/$DV" 'Audit line A.' 'Audit line A, revised upstream.' \
             && awk 'BEGIN{n=0} {print} $0=="```" {n++; if (n==2) {print "```bash"; print "make check"; print "```"}}' "$d/core/$DV" > "$d/x" \
             && mv "$d/x" "$d/core/$DV" ;;
    # Theirs DELETES a line next to a filled single-line site. Merged-vs-theirs is then one `c` hunk
    # whose two sides differ in length, and a site line on its left side used to excuse the whole
    # hunk: the second acceptance resolved on the FIRST run with theirs' deletion never carried.
    delIM)   awk '$0 != "  Unit tests alone are not sufficient."' "$d/core/$IM" > "$d/x" && mv "$d/x" "$d/core/$IM" ;;
    delDV)   awk '{print} /^\{smoke_test_command\} 2>&1/ {getline; next}' "$d/core/$DV" > "$d/x" && mv "$d/x" "$d/core/$DV" ;;
    delDVb)  awk '$0 != "```bash"' "$d/core/$DV" > "$d/x" && mv "$d/x" "$d/core/$DV" ;;
    # (a)'s side of the same blindness: the CONSUMER adds a line right after a filled site.
    cadd)    edit "$d/core/$DV" 'Audit line A.' 'Audit line A, revised upstream.' ;;
    # Block-site control: the block's length changes on BOTH sides (theirs adds a line inside it,
    # the consumer's value is two lines for one token) and the merge is clean -- block spans stay free.
    blkLen)  awk '$0=="## Responsibilities" && !d {print "QA also owns the e2e harness."; print ""; d=1} {print}' "$d/core/$QA" > "$d/x" \
             && mv "$d/x" "$d/core/$QA" ;;
    # Theirs edits qa.md's title, outside every span; the consumer side carries the subject.
    qd|qdctl) edit "$d/core/$QA" '# dev' '# qa role' ;;
    *) return 1 ;;
  esac
  case "$1" in d6a) edit "$d/core/$IM" 'Closing paragraph.' 'Closing paragraph, revised upstream.' ;; esac
}
cons_edit() { # <variant> <consumer> -- consumer copies start at base
  local c="$2/.claude"
  case "$1" in
    clean|b1|conflict|d2|d7|d6a|spanD|dol|ml|com|fence|delDV|delDVb) fill_dv "$c/$DV" both ;;
    delIM)   fill_im "$c/$IM" ;;
    cadd)    fill_dv "$c/$DV" both && awk '{print} $0=="scripts/ecs-deploy.sh prod"{print "scripts/notify.sh"}' "$c/$DV" > "$c/x" && mv "$c/x" "$c/$DV" ;;
    blkLen)  awk '$0 == "{ownership_paths}" { print "src/**"; print "infra/**"; next } { print }' "$c/$QA" > "$c/x" && mv "$c/x" "$c/$QA" ;;
    # qd: the consumer rewords the block's comment (in span) and deletes from the blank line that
    # ends the block THROUGH `## Responsibilities` and its body. diff reports one `d` hunk whose FIRST
    # line is inside the block, so a test of that line alone excuses the deleted heading and body.
    # qdctl is the in-block half alone: the comment reword, no deletion. It must still resolve.
    qd)      edit "$c/$QA" '<!-- {ownership_paths}: filled in by ai-dlc-setup -->' '<!-- our paths -->' \
             && awk '$0 == "{ownership_paths}" { print; exit } { print }' "$c/$QA" > "$c/x" && mv "$c/x" "$c/$QA" ;;
    qdctl)   edit "$c/$QA" '<!-- {ownership_paths}: filled in by ai-dlc-setup -->' '<!-- our paths -->' ;;
    spanQ|spanFar) edit "$c/$QA" '{ownership_paths}' 'tests/e2e/' ;;
    b1b)     fill_dv "$c/$DV" smoke ;;
    b2)      fill_dv "$c/$DV" both \
             && edit "$c/$DV" "<!-- {deploy_command}: the project's deploy command, filled in by ai-dlc-setup -->" "<!-- {deploy_command}: our own wording of the deploy comment -->" ;;
    b2twin)  fill_dv "$c/$DV" both \
             && edit "$c/$DV" "<!-- {deploy_command}: the project's deploy command, filled in by ai-dlc-setup -->" "<!-- {deploy_command}: the deploy command, as ai-dlc-setup filled it in -->" ;;
    d6b)     fill_dv "$c/$DV" both && edit "$c/$DV" 'Final line.' 'Final line, kept by the consumer.' && fill_im "$c/$IM" ;;
    d8del)   rm -f "$c/$DV" ;;
    d8add)   awk '$0 == "{ownership_paths}" { print "src/**"; print "infra/**"; next } { print }' "$2/theirs-qa" > "$c/$QA" ;;
    *) return 1 ;;
  esac
  case "$1" in d6a) fill_im "$c/$IM" && edit "$c/$IM" '  Unit tests alone are not sufficient.' '  Unit tests alone are not sufficient (consumer note).' ;; esac
}

# build <world-dir> <variant> -> a dist with base and theirs, a consumer at base plus the variant's
# edits, `.B`/`.T` beside them. Theirs commits deploy-validate.md at 100755 (D5): the mode an apply
# must carry is read from theirs' TREE, so the bit is set before `git add`.
build() {
  local w="$1" v="$2" d="$1/dist" c="$1/cons" B T p
  mkdir -p "$d" "$c/.claude/skills/ai-dlc/steps" "$c/.claude/team-roles" "$c/scripts/ai-dlc" || return 1
  git -C "$d" init -q 2>/dev/null || return 1
  seed_base "$d" || return 1
  [ "$v" = d8add ] && rm -f "$d/core/$QA"
  git -C "$d" add -A && git -C "$d" -c user.email=f@f -c user.name=fx -c commit.gpgsign=false commit -qm base || return 1
  B="$(git -C "$d" rev-parse HEAD)"
  theirs_edit "$v" "$d" || return 1
  chmod 755 "$d/core/$DV"
  git -C "$d" add -A && git -C "$d" -c user.email=f@f -c user.name=fx -c commit.gpgsign=false commit -qm theirs || return 1
  T="$(git -C "$d" rev-parse HEAD)"
  for p in "$DV" "$IM" team-roles/dev.md "$QA"; do
    git -C "$d" cat-file -e "${B}:core/${p}" 2>/dev/null || continue
    git -C "$d" show "${B}:core/${p}" > "$c/.claude/$p" || return 1
  done
  [ "$v" = d8add ] && { git -C "$d" show "${T}:core/${QA}" > "$c/theirs-qa" || return 1; }
  printf '#!/usr/bin/env bash\necho v\n' > "$c/scripts/ai-dlc/validate-synthetic.sh"
  printf 'version: 1.0.0\ncommit: %s\n' "$B" > "$c/.claude/.ai-dlc-version"
  cons_edit "$v" "$c" || return 1
  rm -f "$c/theirs-qa"
  printf '%s\n' "$B" > "$w/.B"; printf '%s\n' "$T" > "$w/.T"
  # The pre-run snapshot every fallback arm compares against: bytes, inode, exec bit.
  for p in "$DV" "$IM" "$QA"; do
    [ -f "$c/.claude/$p" ] || continue
    cp -p "$c/.claude/$p" "$w/pre.$(basename "$p")"
    ls -i "$c/.claude/$p" | awk '{print $1}' > "$w/ino.$(basename "$p")"
    if [ -x "$c/.claude/$p" ]; then echo x > "$w/mode.$(basename "$p")"; else echo - > "$w/mode.$(basename "$p")"; fi
  done
}
render_report() { # <world> <rec>
  local w="$1"
  mkdir -p "$w/cons/_bmad-output/ai-dlc-update" || return 1
  { printf '# reconcile report (fixture)\n\n'
    bash "$2/emit-report.sh" "$w/dist" "$(cat "$w/.B")" "$w/cons" "$(cat "$w/.T")" 2>/dev/null
  } > "$w/cons/_bmad-output/ai-dlc-update/reconcile-report.md"
}

# --- the drives: a bounded pool, because each apply run costs seconds --------------------------
POOL=8; njobs=0
launch() { # <label> <rec> <world> [cwd] [flag]
  local l="$1" r="$2" w="$3" cwd="${4:-}" fl="${5:-}"
  ( [ -n "$cwd" ] && cd "$cwd"
    bash "$r/apply.sh" $fl "$w/dist" "$(cat "$w/.B")" "$w/cons" "$(cat "$w/.T")" \
      > "$WORK/out/$l.out" 2> "$WORK/out/$l.err"
    echo $? > "$WORK/out/$l.rc" ) &
  njobs=$((njobs+1)); [ "$njobs" -lt "$POOL" ] || { wait; njobs=0; }
}
rows_for() { awk -F'\t' -v r="$2" '$3 == r' "$WORK/out/$1.out" 2>/dev/null; }
has_resolved() { awk -F'\t' -v r="$2" '$1=="RESOLVED" && $2=="setup-site-merge" && $3==r && NF==3 {f=1} END {exit !f}' "$WORK/out/$1.out" 2>/dev/null; }
# today's row, literally: WORKLIST, semantic-merge, the rel, and nothing else (D7's carries a 4th).
has_today() { awk -F'\t' -v r="$2" -v nf="${3:-3}" '$1=="WORKLIST" && $2=="semantic-merge" && $3==r && NF==nf {f=1} END {exit !f}' "$WORK/out/$1.out" 2>/dev/null; }
ran() { [ -s "$WORK/out/$1.out" ] && [ "$(cat "$WORK/out/$1.rc" 2>/dev/null)" = 0 ]; }
ino() { ls -i "$1" 2>/dev/null | awk '{print $1}'; }
xbit() { if [ -x "$1" ]; then echo x; else echo -; fi; }
# untouched <world> <rel> -> 0 when bytes, inode, exec bit AND mtime all match the pre-run snapshot.
# The mtime conjunct is what sees a write-then-restore: same bytes, same inode, same mode, later
# mtime. The snapshot is a `cp -p` copy, so it carries the original mtime; equality is "neither
# file is -newer than the other", which avoids BSD-only stat flags.
same_mtime() { [ -z "$(find "$1" -newer "$2" 2>/dev/null)" ] && [ -z "$(find "$2" -newer "$1" 2>/dev/null)" ]; }
untouched() {
  local w="$1" b; b="$(basename "$2")"
  cmp -s "$w/pre.$b" "$w/cons/.claude/$2" && [ "$(ino "$w/cons/.claude/$2")" = "$(cat "$w/ino.$b")" ] \
    && [ "$(xbit "$w/cons/.claude/$2")" = "$(cat "$w/mode.$b")" ] \
    && same_mtime "$w/pre.$b" "$w/cons/.claude/$2"
}
# The expected merge, built here and not by the subject's own checker: theirs with only the site
# lines carrying the seeded values.
expect_dv() { git -C "$1/dist" show "$(cat "$1/.T"):core/$DV" > "$1/want" && fill_dv "$1/want" both; }
expect_im() { git -C "$1/dist" show "$(cat "$1/.T"):core/$IM" > "$1/want" && fill_im "$1/want"; }

# --- the reference: today's arm, from the same apply.sh -----------------------------------------
# mut_new <dir> copies the WHOLE reconcile directory (apply.sh evals map_consumer() out of
# preclassify.sh and shells to its sibling detectors, so a lone copy dies before printing a row).
# mut_sub <dir> <old> <new> replaces a literal substring on exactly ONE line of the copy's apply.sh;
# mut_del <dir> <anchor> <k> deletes the one line carrying <anchor> and the <k> lines after it.
# Both refuse unless exactly one line matched, so a respelled anchor reports DID NOT APPLY.
mut_new() { mkdir -p "$1" && cp "$REC"/* "$1"/ 2>/dev/null && [ -f "$1/apply.sh" ] && [ -f "$1/setup-site-drift.sh" ]; }
mut_sub() {
  local n; n="$(grep -cF -- "$2" "$1/apply.sh")" || n=0
  [ "$n" = 1 ] || return 1
  MS_OLD="$2" MS_NEW="$3" awk '{ i = index($0, ENVIRON["MS_OLD"]); if (i) $0 = substr($0, 1, i-1) ENVIRON["MS_NEW"] substr($0, i + length(ENVIRON["MS_OLD"])); print }' \
    "$1/apply.sh" > "$1/apply.sh.m" && mv "$1/apply.sh.m" "$1/apply.sh"
}
# mut_subn <dir> <old> <new> <n> -- the same, for an anchor that must be on exactly <n> lines; every
# one is replaced. For a property the subject states at more than one site.
mut_subn() {
  local n; n="$(grep -cF -- "$2" "$1/apply.sh")" || n=0
  [ "$n" = "$4" ] || return 1
  MS_OLD="$2" MS_NEW="$3" awk '{ i = index($0, ENVIRON["MS_OLD"]); if (i) $0 = substr($0, 1, i-1) ENVIRON["MS_NEW"] substr($0, i + length(ENVIRON["MS_OLD"])); print }' \
    "$1/apply.sh" > "$1/apply.sh.m" && mv "$1/apply.sh.m" "$1/apply.sh"
}
mut_del() {
  local n; n="$(grep -cF -- "$2" "$1/apply.sh")" || n=0
  [ "$n" = 1 ] || return 1
  MS_A="$2" awk -v k="$3" 'index($0, ENVIRON["MS_A"]) { skip = k + 1 } skip > 0 { skip--; next } { print }' \
    "$1/apply.sh" > "$1/apply.sh.m" && mv "$1/apply.sh.m" "$1/apply.sh"
}
mutated() { ! cmp -s "$REC/apply.sh" "$1/apply.sh"; }
# ssd_sub <dir> <old> <new> -- the same literal one-line replacement, in the copy's
# setup-site-drift.sh; ssd_mutated is its cmp guard. apply.sh shells to its sibling, so a mutation
# of the checker lives in the same directory copy as every other mutant.
ssd_sub() {
  local n; n="$(grep -cF -- "$2" "$1/setup-site-drift.sh")" || n=0
  [ "$n" = 1 ] || return 1
  MS_OLD="$2" MS_NEW="$3" awk '{ i = index($0, ENVIRON["MS_OLD"]); if (i) $0 = substr($0, 1, i-1) ENVIRON["MS_NEW"] substr($0, i + length(ENVIRON["MS_OLD"])); print }' \
    "$1/setup-site-drift.sh" > "$1/ssd.m" && mv "$1/ssd.m" "$1/setup-site-drift.sh"
}
ssd_mutated() { ! cmp -s "$REC/setup-site-drift.sh" "$1/setup-site-drift.sh"; }

CALL='&& setup_site_merge "$path" "$rel" "$cons"; then'
REF="$WORK/ref"
mut_new "$REF" && mut_sub "$REF" "$CALL" '&& false; then' && mutated "$REF" \
  || broken "the reference copy could not be built: the merge call \`$CALL\` is not on exactly one line of apply.sh"
CTL="$WORK/ctl"
mut_new "$CTL" || broken "the unmutated control copy could not be built"

# --- worlds ------------------------------------------------------------------------------------
FALLBACKS="b1 b1b b2 b2twin d2 conflict d8del d8add d7 spanD spanQ delIM delDV delDVb cadd qd"
RESOLVES="dol ml com"
for v in clean cwd mode fin fence spanFar blkLen qdctl d6a d6b $FALLBACKS $RESOLVES; do
  case "$v" in cwd|mode) vv=clean ;; fin) vv=d6a ;; *) vv="$v" ;; esac
  build "$WORK/tip-$v" "$vv" || broken "could not build world $v"
done
for v in clean d6a d6b $FALLBACKS; do build "$WORK/ref-$v" "$v" || broken "could not build reference world $v"; done
build "$WORK/ctl-clean" clean || broken "could not build the control world"
render_report "$WORK/tip-clean" "$REC" || broken "emit-report.sh did not render the clean world's report"
grep -q 'reconcile-mechanical' "$WORK/tip-clean/cons/_bmad-output/ai-dlc-update/reconcile-report.md" \
  || broken "the rendered report carries no reconcile-mechanical region"

# --- mutants: each a copy, each aimed at one arm -----------------------------------------------
read -r -d '' W2_FN <<'EOF'
w2_subst() { local c; c="$(consumer_path "$1")" || return 1; git -C "$DIST" show "${THEIRS}:core/$1" | sed -e 's|{deploy_command}|scripts/ecs-deploy.sh prod|g' -e 's|{smoke_test_command}|scripts/smoke.sh|g' > "$c.w2" && mv "$c.w2" "$c"; }
EOF
read -r -d '' W3_A <<'EOF'
awk -F'\t' -v r="$_r" '$1=="CORE-TEMPLATE-SUBSTITUTED" && $2==r {f=1} END {exit !f}' "$DT_DIR/ud.out" || return 1; printf 'SETUP-SITE-OK\t-\t\n' > "$DT_DIR/ssm.out"
EOF
A_LINE='detector_run ssm setup-site-drift.sh --file "$_p" "$DIST" "$CONSUMER" "$BASE" || return 1'
C_LINE='--ours "$_d/merged" "$DIST" "$CONSUMER" "$THEIRS" || return 1'
GATE='if [ "$rt_rc" -eq 0 ] && [ -z "$rt" ] \'
# The second acceptance's span-identity conjunct: every span's text equal at base and theirs.
SPANID='     && [ "$_stb" = "$_stt" ]; then'
# The already-merged shortcut's no-op-merge test. `if true` is the shortcut as it first shipped
# (outside-span OK alone); `if false` removes the shortcut.
SHORT='if git merge-file -p "$_cons" "$_d/b0" "$_d/t0" > "$_d/m0" 2>/dev/null && cmp -s "$_d/m0" "$_cons" \'
# The second acceptance's opening line. no-idempotence disables BOTH acceptances: with only the
# first gone, the second still accepts an already-merged file and the mutant reads as idempotent.
SHORT2='  if detector_run ssm setup-site-drift.sh --file "$_p" "$DIST" "$CONSUMER" "$THEIRS" && ssm_ok \'
# Theirs' exec bit is applied at both acceptances, so the mode mutant strips both.
SHORT_MODE='    sync_mode_from_theirs "$_r" "$_cons"'
# NO BUCKET TEST AND NO BUCKET MUTANT. The call site no longer tests the bucket: what refuses every
# CLASSIFY bucket other than BOTH-CHANGED is setup_site_merge itself, which reads BASE's and THEIRS'
# blobs first and needs a consumer file. So BOTH-ADDED (absent at base), UPSTREAM-DELETED+consumer-
# modified (absent at theirs) and UPSTREAM-MOD+consumer-deleted (no consumer file) all return 1
# there, and the ORPHANED-* rows name no sited path. D8b and D8 are the arms that hold that.
#
# NO "ABSENT LOCATOR READ AS EQUAL" MUTANT, because no world reaches it. The span texts are compared
# as strings and each must be non-empty: a site whose locator is absent at BASE gives an empty base
# text against a non-empty theirs text, unequal whatever the guard; and for both to be absent the
# locator must be absent at THEIRS, which already fails the `--file` OK conjunct before them.
# setup-site-drift.sh's c-hunk length test: a hunk touching a single-line site whose two sides differ
# in length is drift. laxC reverts it in the copy's checker; laxCa is the same mutation scored on the
# consumer-addition world, (a)'s side of the same blindness.
LAXC='        if [ $((l2 - l1)) -ne $((r2 - r1)) ]; then'
# Its a|d arm's range test: every deleted line of a `d` hunk must sit in a heading block. laxD
# reverts it to testing the hunk's first line alone.
LAXD='          for l in $(seq "$l1" "$l2"); do in_span "$l" || { _ad_ok=0; break; }; done'
MUTS="W1 W2 W3 W4 noD noIdem treeA mode ssdExit noD7 bareShort rcOnly spanId spanIdQ dDol dML dCom idemMode leak writeRestore finNote laxC laxCa laxD"
mk_mut() {
  local m="$WORK/m-$1"
  mut_new "$m" || return 1
  case "$1" in
    W1)     mut_sub "$m" "$CALL" '&& overwrite_from_theirs "$rel"; then' ;;
    W2)     mut_sub "$m" "$CALL" '&& w2_subst "$rel"; then' \
            && mut_sub "$m" 'setup_site_merge() { # <core-path>' "$W2_FN
setup_site_merge() { # <core-path>" ;;
    W3)     mut_sub "$m" "$A_LINE" "$W3_A" ;;
    W4)     mut_del "$m" "$C_LINE" 1 ;;
    noD)    mut_sub "$m" 'END { exit bad ? 1 : 0 }' 'END { exit 0 }' ;;
    noIdem) mut_sub "$m" "$SHORT" 'if false \' && mut_sub "$m" "$SHORT2" '  if false \' ;;
    bareShort) mut_sub "$m" "$SHORT" 'if true \' ;;
    rcOnly) mut_sub "$m" "$SHORT" 'if git merge-file -p "$_cons" "$_d/b0" "$_d/t0" > "$_d/m0" 2>/dev/null \' ;;
    dDol)   mut_sub "$m" '(^|[^$])[{][A-Za-z0-9_]+[}]' '[{][A-Za-z0-9_]+[}]' ;;
    dML)    mut_sub "$m" '      s = $0; out = ""' '      s = $0; out = ""; incom = 0' ;;
    dCom)   mut_sub "$m" 'i = index(s, "<!--")' 'i = 0' ;;
    idemMode) mut_subn "$m" "$SHORT_MODE" '    :' 2 ;;
    leak)   mut_sub "$m" '  # (b)' '  cp -p "$_cons" "$_cons.incoming.$$" # (b)' ;;
    writeRestore) mut_sub "$m" '  # (c)' '  cp -p "$_cons" "$_d/orig"; cat "$_d/merged" > "$_cons" # (c)' \
            && mut_sub "$m" "$C_LINE" '"$DIST" "$CONSUMER" "$THEIRS" || { cat "$_d/orig" > "$_cons"; return 1; }' ;;
    finNote) mut_sub "$m" 'if [ "$_fv_ss_rc" -eq 0 ] && awk' 'if true || awk' ;;
    laxC|laxCa) ssd_sub "$m" "$LAXC" '        if false; then' && ssd_mutated "$m"; return ;;
    laxD)   ssd_sub "$m" "$LAXD" '          in_span "$l1" || _ad_ok=0' && ssd_mutated "$m"; return ;;
    treeA)  mut_sub "$m" '--file "$_p" "$DIST" "$CONSUMER" "$BASE"' '"$DIST" "$CONSUMER" "$BASE"' ;;
    mode)   mut_del "$m" 'sync_mode_from_theirs "$_r" "$_tmp"' 0 ;;
    spanId|spanIdQ) mut_sub "$m" "$SPANID" '     ; then' ;;
    ssdExit) mut_sub "$m" "$C_LINE" '--ours "$_d/merged" "$DIST" "$CONSUMER" "$THEIRS" || :' ;;
    noD7)   mut_sub "$m" "$GATE" 'if [ "$rt_rc" -eq 0 ] \' ;;
  esac || return 1
  mutated "$m"
}
mut_world() { case "$1" in W1|W2|mode|noIdem|idemMode) echo clean ;; W3) echo b2twin ;; W4|writeRestore|leak) echo b1 ;; noD) echo d2 ;;
  treeA|finNote) echo d6a ;; ssdExit) echo b1b ;; noD7) echo d7 ;; bareShort) echo spanD ;; rcOnly|spanId) echo spanFar ;; spanIdQ) echo spanQ ;; laxC) echo delIM ;; laxCa) echo cadd ;; laxD) echo qd ;;
  dDol) echo dol ;; dML) echo ml ;; dCom) echo com ;; esac; }
MUT_OK=""
for m in $MUTS; do
  if mk_mut "$m"; then
    build "$WORK/mw-$m" "$(mut_world "$m")" || broken "could not build the world for mutant $m"
    MUT_OK="$MUT_OK $m"
  else
    bad "MUTANT $m DID NOT APPLY -- its anchor is not on exactly one line of apply.sh, so it proves nothing. Re-anchor it."
  fi
done

# --- phase 1 drives ----------------------------------------------------------------------------
launch tip-clean "$REC" "$WORK/tip-clean"
launch tip-cwd   "$REC" "$WORK/tip-cwd" /
launch ctl-clean "$CTL" "$WORK/ctl-clean"
for v in mode fin fence spanFar blkLen qdctl d6a d6b $FALLBACKS $RESOLVES; do launch "tip-$v" "$REC" "$WORK/tip-$v"; done
for v in clean d6a d6b $FALLBACKS; do launch "ref-$v" "$REF" "$WORK/ref-$v"; done
for m in $MUT_OK; do launch "m-$m" "$WORK/m-$m" "$WORK/mw-$m"; done
wait; njobs=0

# --- phase 1b: the exec bit taken away after the merge, then a re-run (the shortcut must restore
# it), and --finish over the d6a tree the ordinary run left with its stamp withheld ---------------
MODE_RES1="$(has_resolved tip-mode "$DV" && echo yes || echo no)"
FENCE_RES1="$(has_resolved tip-fence "$DV" && echo yes || echo no)"; FENCE_INO1="$(ino "$WORK/tip-fence/cons/.claude/$DV")"
cp "$WORK/tip-fence/cons/.claude/$DV" "$WORK/tip-fence/after1"
render_report "$WORK/tip-fence" "$REC" || broken "emit-report.sh did not render the fence world's run-2 report"
launch tip-fence2 "$REC" "$WORK/tip-fence"
chmod -x "$WORK/tip-mode/cons/.claude/$DV"
launch tip-mode2 "$REC" "$WORK/tip-mode"
case " $MUT_OK " in *" idemMode "*) chmod -x "$WORK/mw-idemMode/cons/.claude/$DV"; launch m-idemMode2 "$WORK/m-idemMode" "$WORK/mw-idemMode" ;; esac
launch tip-fin2 "$REC" "$WORK/tip-fin" "" --finish
case " $MUT_OK " in *" finNote "*) launch m-finNote2 "$WORK/m-finNote" "$WORK/mw-finNote" "" --finish ;; esac
wait; njobs=0

# --- phase 2: the second run over the same trees (D1) ------------------------------------------
# The report is re-rendered first: run 1 moved the stamp, and a region rendered before it is
# refused as STALE, which would test the union gate instead of the merge.
INO1="$(ino "$WORK/tip-clean/cons/.claude/$DV")"; cp "$WORK/tip-clean/cons/.claude/$DV" "$WORK/tip-clean/after1"
render_report "$WORK/tip-clean" "$REC" || broken "emit-report.sh did not re-render the clean world's report"
launch tip-clean2 "$REC" "$WORK/tip-clean"
case " $MUT_OK " in *" noIdem "*) launch m-noIdem2 "$WORK/m-noIdem" "$WORK/mw-noIdem" ;; esac
wait; njobs=0

for l in tip-clean tip-clean2 ref-clean ctl-clean; do
  ran "$l" || { sed 's/^/        /' "$WORK/out/$l.err" | head -8; broken "drive $l exited $(cat "$WORK/out/$l.rc" 2>/dev/null) or printed nothing"; }
done

# === S: the reference is today's arm and the control is the shipped program ====================
if has_today ref-clean "$DV" && ! has_resolved ref-clean "$DV"; then
  ok "S1 the reference copy (merge call replaced by false) hands the clean world back as today's semantic-merge row -- it is a real 'before'"
else
  bad "S1 the reference copy did not print today's row on the clean world, so every byte-identity comparison below compares against nothing"
fi
if has_resolved ctl-clean "$DV"; then
  ok "S2 an unmutated copy in a fresh directory resolves the clean world -- a mutant's fallback is its mutation, not the copy"
else
  bad "S2 the unmutated control copy did not resolve the clean world; every mutant verdict below is unreadable"
fi

# === C: the clean target ========================================================================
W="$WORK/tip-clean"; expect_dv "$W" || broken "could not build the expected clean file"
if has_resolved tip-clean "$DV"; then ok "C1 the clean target emits RESOLVED${TAB}setup-site-merge${TAB}$DV"
else bad "C1 the clean target did not resolve: $(cut -f1-3 "$WORK/out/tip-clean.out" | tr '\t\n' ' |')"; fi
if has_today tip-clean "$DV"; then bad "C1 and the same run ALSO printed today's semantic-merge row for it"; fi
if cmp -s "$W/want" "$W/after1"; then
  ok "C2 the written file is theirs byte-for-byte outside the two sites, and carries the consumer's values inside them"
else
  bad "C2 the written file is not theirs-with-the-consumer's-values:"; diff "$W/want" "$W/after1" | head -8 | sed 's/^/        /'
fi
if [ "$(xbit "$W/after1")" = x ] && [ "$(cat "$W/mode.deploy-validate.md")" = - ]; then
  ok "C3 the consumer's 0644 copy took theirs' 100755 (D5)"
else
  bad "C3 the mode did not follow theirs: consumer was $(cat "$W/mode.deploy-validate.md"), now $(xbit "$W/after1"), theirs 100755"
fi
if [ "$INO1" != "$(cat "$W/ino.deploy-validate.md")" ]; then ok "C4 the write replaced the inode (.incoming + mv), the positive control for D1's no-write"
else bad "C4 the clean write kept the inode -- either nothing was written or it was written in place"; fi

# === D1: idempotence ============================================================================
if has_resolved tip-clean2 "$DV" && [ "$(ino "$W/cons/.claude/$DV")" = "$INO1" ] && cmp -s "$W/after1" "$W/cons/.claude/$DV"; then
  ok "D1 a second run over the merged file resolves again, with the same inode and bytes -- already merged, no write"
else
  bad "D1 the second run: resolved=$(has_resolved tip-clean2 "$DV" && echo yes || echo NO) inode $(ino "$W/cons/.claude/$DV") vs $INO1, bytes $(cmp -s "$W/after1" "$W/cons/.claude/$DV" && echo same || echo CHANGED)"
fi

# === CWD ========================================================================================
if ran tip-cwd && has_resolved tip-cwd "$DV" && cmp -s "$W/want" "$WORK/tip-cwd/cons/.claude/$DV"; then
  ok "CWD the clean world driven from / reaches the same verdict and the same bytes"
else
  bad "CWD the clean world driven from / did not reproduce (rc $(cat "$WORK/out/tip-cwd.rc" 2>/dev/null))"
fi

# === fallbacks: today's row, byte-identical to the reference, file untouched ===================
# fallback <arm> <variant> <rel> <nf> <why>
fallback() {
  local a="$1" v="$2" r="$3" nf="$4" why="$5" w="$WORK/tip-$2"
  if ! ran "tip-$v" || ! ran "ref-$v"; then bad "$a ($v) a drive failed: tip rc $(cat "$WORK/out/tip-$v.rc"), ref rc $(cat "$WORK/out/ref-$v.rc")"; return; fi
  local t f; t="$(rows_for "tip-$v" "$r")"; f="$(rows_for "ref-$v" "$r")"
  if has_today "tip-$v" "$r" "$nf" && ! has_resolved "tip-$v" "$r" && [ -n "$t" ] && [ "$t" = "$f" ] && untouched "$w" "$r"; then
    ok "$a $why -- today's row, byte-identical to the reference's, and $r untouched (bytes, inode, mode)"
  else
    bad "$a $why -- tip rows [$(printf '%s' "$t" | tr '\t\n' ' |')] ref rows [$(printf '%s' "$f" | tr '\t\n' ' |')] untouched=$(untouched "$w" "$r" && echo yes || echo NO)"
  fi
}
fallback B1  b1       "$DV" 3 "theirs rewords the after_line anchor: (a) OK and merge-file 0, only (c) sees the lost anchor"
fallback B1b b1b      "$DV" 3 "theirs rewords the anchor of a site the consumer left unfilled: (c) exits 1 while still printing SETUP-SITE-OK"
fallback B2  b2       "$DV" 3 "the consumer edited the <!-- {deploy_command}: ... --> doc-comment line, outside every span"
fallback B2t b2twin   "$DV" 3 "consumer and theirs made the SAME doc-comment edit: unregistered-drift exempts the hunk and (c) is blind, only (a) refuses"
fallback D2  d2       "$DV" 3 "theirs adds a live {deploy_command} --retry line outside the site"
fallback MF  conflict "$DV" 3 "theirs edits a span line the consumer filled: merge-file exits 1"
fallback D7  d7       "$DV" 4 "a pending retired-token obligation keeps today's row with its re-point detail"
fallback D8b d8add    "$QA" 3 "a BOTH-ADDED->CLASSIFY sited file falls back because it has no blob at base to merge from"
fallback SpD spanD    "$DV" 3 "theirs changes the value line to {deploy_command} --wait, the locator still matching: the already-merged shortcut must not read it as merged"
fallback SpQ spanQ    "$QA" 3 "theirs rewords the doc comment INSIDE qa.md's ## Ownership block: the already-merged shortcut must not read it as merged"
fallback DlI delIM    "$IM" 3 "theirs deletes the line below the filled implementation-smoke-command site: a first run must not accept the file without theirs' deletion"
fallback DlD delDV    "$DV" 3 "theirs deletes the closing fence after the filled smoke line"
fallback DlB delDVb   "$DV" 3 "theirs deletes the opening fence before the filled smoke line"
fallback CAd cadd     "$DV" 3 "the consumer adds a line right after the filled deploy site: (a) must see it as outside every span"
fallback QD  qd       "$QA" 3 "the consumer deletes from inside qa.md's Ownership block through ## Responsibilities and its body: one d hunk whose first line is in span"

# === QDc: a deletion-shaped edit wholly inside the block still resolves =========================
w="$WORK/tip-qdctl"
git -C "$w/dist" show "$(cat "$w/.T"):core/$QA" > "$w/want" \
  && edit "$w/want" '<!-- {ownership_paths}: filled in by ai-dlc-setup -->' '<!-- our paths -->' \
  || broken "could not build the expected qa.md for qdctl"
if ran tip-qdctl && has_resolved tip-qdctl "$QA" && cmp -s "$w/want" "$w/cons/.claude/$QA"; then
  ok "QDc the same in-block comment reword without the deletion RESOLVES -- the range test does not hit edits inside the block"
else
  bad "QDc qdctl: resolved=$(has_resolved tip-qdctl "$QA" && echo yes || echo NO) bytes=$(cmp -s "$w/want" "$w/cons/.claude/$QA" && echo want || echo OTHER)"
fi

# === (d)'s pass direction: three theirs additions that are NOT a live setup token ===============
for v in $RESOLVES; do
  w="$WORK/tip-$v"; expect_dv "$w" || broken "could not build the expected file for $v"
  case "$v" in
    dol) why='theirs adds `Export ${LOGDIR}` -- a shell expansion, not a setup token' ;;
    ml)  why='theirs adds a multi-line <!-- ... {deploy_command} ... --> comment' ;;
    com) why='theirs rewords only the <!-- {deploy_command}: ... --> comment line' ;;
  esac
  if ran "tip-$v" && has_resolved "tip-$v" "$DV" && cmp -s "$w/want" "$w/cons/.claude/$DV"; then
    ok "D+$v $why: it RESOLVES, and the file is theirs-with-values"
  else
    bad "D+$v $why: resolved=$(has_resolved "tip-$v" "$DV" && echo yes || echo NO) bytes=$(cmp -s "$w/want" "$w/cons/.claude/$DV" && echo want || echo OTHER) -- (d) refuses an addition that carries no live token"
  fi
done

# === SpF: theirs' line inside a heading block, away from the value, is MERGED ==================
w="$WORK/tip-spanFar"
git -C "$w/dist" show "$(cat "$w/.T"):core/$QA" > "$w/want" && edit "$w/want" '{ownership_paths}' 'tests/e2e/' \
  || broken "could not build the expected qa.md for spanFar"
if ran tip-spanFar && has_resolved tip-spanFar "$QA" && cmp -s "$w/want" "$w/cons/.claude/$QA"; then
  ok "SpF theirs adds a line inside qa.md's ## Ownership block away from the value: it RESOLVES, carrying theirs' line and keeping the consumer's value"
else
  bad "SpF spanFar: resolved=$(has_resolved tip-spanFar "$QA" && echo yes || echo NO), theirs' line present $(grep -c 'QA also owns the e2e harness.' "$w/cons/.claude/$QA"), value kept $(grep -c 'tests/e2e/' "$w/cons/.claude/$QA"), bytes $(cmp -s "$w/want" "$w/cons/.claude/$QA" && echo want || echo OTHER)"
fi

# === BLK: a block span may change length on both sides and still resolve =======================
w="$WORK/tip-blkLen"
git -C "$w/dist" show "$(cat "$w/.T"):core/$QA" \
  | awk '$0 == "{ownership_paths}" { print "src/**"; print "infra/**"; next } { print }' > "$w/want" \
  || broken "could not build the expected qa.md for blkLen"
if ran tip-blkLen && has_resolved tip-blkLen "$QA" && cmp -s "$w/want" "$w/cons/.claude/$QA"; then
  ok "BLK qa.md's Ownership block changes length on both sides (theirs adds a line, the consumer's value is two lines): it still RESOLVES to theirs-with-values"
else
  bad "BLK blkLen: resolved=$(has_resolved tip-blkLen "$QA" && echo yes || echo NO) bytes=$(cmp -s "$w/want" "$w/cons/.claude/$QA" && echo want || echo OTHER) -- a length check meant for single-line sites is catching block spans"
fi

# === D1f: idempotence over a fence-adjacent insertion ==========================================
w="$WORK/tip-fence"; expect_dv "$w" || broken "could not build the expected fence file"
n_t="$(grep -c '^make check$' "$w/want")" || n_t=0
n_1="$(grep -c '^make check$' "$w/after1")" || n_1=0
n_2="$(grep -c '^make check$' "$w/cons/.claude/$DV")" || n_2=0
if [ "$FENCE_RES1" = yes ] && cmp -s "$w/want" "$w/after1" && [ "$n_t" = 1 ] \
   && ran tip-fence2 && has_resolved tip-fence2 "$DV" && cmp -s "$w/after1" "$w/cons/.claude/$DV" \
   && [ "$(ino "$w/cons/.claude/$DV")" = "$FENCE_INO1" ] && [ "$n_2" = 1 ]; then
  ok "D1f theirs adds a fenced block beside an existing fence: run 1 merges it, run 2 resolves with no write, and the block appears once"
else
  bad "D1f fence: run1 resolved=$FENCE_RES1 bytes=$(cmp -s "$w/want" "$w/after1" && echo want || echo OTHER); run2 resolved=$(has_resolved tip-fence2 "$DV" && echo yes || echo NO) bytes=$(cmp -s "$w/after1" "$w/cons/.claude/$DV" && echo same || echo CHANGED) inode $([ "$(ino "$w/cons/.claude/$DV")" = "$FENCE_INO1" ] && echo same || echo CHANGED); 'make check' count theirs=$n_t run1=$n_1 run2=$n_2"
fi

# === M2: the shortcut restores theirs' exec bit ================================================
if [ "$MODE_RES1" = yes ] && ran tip-mode2 && has_resolved tip-mode2 "$DV" && [ "$(xbit "$WORK/tip-mode/cons/.claude/$DV")" = x ]; then
  ok "M2 after chmod -x on the merged file, a re-run resolves through the shortcut AND restores theirs' 100755"
else
  bad "M2 re-run after chmod -x: run1 resolved=$MODE_RES1, run2 resolved=$(has_resolved tip-mode2 "$DV" && echo yes || echo NO), exec bit now $(xbit "$WORK/tip-mode/cons/.claude/$DV") (want x)"
fi

# === FIN: --finish over the d6a tree ===========================================================
fin_note() { awk -F'\t' -v r=".claude/$2" '$1=="NOTE" && $2=="finish-unverified" && $3==r {print $4}' "$WORK/out/$1.out" 2>/dev/null; }
if ran tip-fin && has_resolved tip-fin "$DV" && has_today tip-fin "$IM" && ran tip-fin2; then
  n_dv="$(fin_note tip-fin2 "$DV")"; n_im="$(fin_note tip-fin2 "$IM")"
  if [ -z "$n_dv" ] && [ -n "$n_im" ] && case "$n_im" in *"SETUP-SITE-DRIFT .claude/$IM"*) true ;; *) false ;; esac; then
    ok "FIN --finish: the merged deploy-validate.md is verified (no finish-unverified row), implementation.md keeps the NOTE carrying ssd's DRIFT rows"
  else
    bad "FIN --finish: DV note [${n_dv:-none}] (want none); IM note [${n_im:-NONE}] (want one naming SETUP-SITE-DRIFT .claude/$IM)"
  fi
else
  bad "FIN setup: the d6a ordinary run did not leave DV resolved and IM handed back, or --finish did not run (rc $(cat "$WORK/out/tip-fin2.rc" 2>/dev/null))"
fi

# === INC: no world is left holding a write temp ================================================
# Counted over EVERY world driven by the shipped program, so a write path that leaks its
# `.incoming.$$` in any shape is seen. The control is the number of worlds the find walked.
n_w=0; n_leak=0
for w in "$WORK"/tip-* "$WORK"/ref-* "$WORK"/ctl-*; do
  [ -d "$w/cons" ] || continue
  n_w=$((n_w+1))
  [ -z "$(find "$w/cons" -name '*.incoming.*' 2>/dev/null)" ] || n_leak=$((n_leak+1))
done
if [ "$n_w" -ge 20 ] && [ "$n_leak" -eq 0 ]; then
  ok "INC none of the $n_w driven worlds holds an *.incoming.* temp"
else
  bad "INC $n_leak of $n_w driven worlds hold an *.incoming.* temp (or too few worlds were walked to mean anything)"
fi
# D8: consumer-deleted
if ran tip-d8del && ran ref-d8del && [ ! -e "$WORK/tip-d8del/cons/.claude/$DV" ] && ! has_resolved tip-d8del "$DV" \
   && [ "$(rows_for tip-d8del "$DV")" = "$(rows_for ref-d8del "$DV")" ]; then
  ok "D8 a consumer-deleted sited path stays absent, and its rows are the reference's ($(rows_for tip-d8del "$DV" | cut -f1,2 | tr '\t\n' ' |'))"
else
  bad "D8 the consumer-deleted path: present=$([ -e "$WORK/tip-d8del/cons/.claude/$DV" ] && echo YES || echo no), rows tip [$(rows_for tip-d8del "$DV" | tr '\t\n' ' |')] ref [$(rows_for ref-d8del "$DV" | tr '\t\n' ' |')]"
fi

# === D6: per file, both directions =============================================================
d6() { # <arm> <variant> <target-rel> <other-rel> <expect-fn>
  local w="$WORK/tip-$2"
  "$5" "$w" || broken "could not build the expected file for $2"
  if ran "tip-$2" && has_resolved "tip-$2" "$3" && cmp -s "$w/want" "$w/cons/.claude/$3" \
     && has_today "tip-$2" "$4" && untouched "$w" "$4" \
     && [ "$(rows_for "tip-$2" "$4")" = "$(rows_for "ref-$2" "$4")" ]; then
    ok "$1 $3 resolves to theirs-with-values while $4, carrying an outside-span consumer edit, gets today's row untouched"
  else
    bad "$1 per-file: $3 resolved=$(has_resolved "tip-$2" "$3" && echo yes || echo NO) bytes=$(cmp -s "$w/want" "$w/cons/.claude/$3" && echo want || echo OTHER); $4 today=$(has_today "tip-$2" "$4" && echo yes || echo NO) untouched=$(untouched "$w" "$4" && echo yes || echo NO)"
  fi
}
d6 D6a d6a "$DV" "$IM" expect_dv
d6 D6b d6b "$IM" "$DV" expect_im

# === mutants ====================================================================================
# Every verdict is PRESENCE-shaped: a kill needs the mutant to have run (rc 0, rows printed) AND to
# have produced the wrong observable its arm reads.
mres() { # <mutant> -> the world dir
  printf '%s' "$WORK/mw-$1"
}
kill_if() { # <mutant> <arm> <claim> <test...>
  local m="$1" a="$2" c="$3"; shift 3
  if ! ran "m-$m"; then bad "MUTANT $m did not run (rc $(cat "$WORK/out/m-$m.rc" 2>/dev/null)) -- a dead copy cannot score a kill"; return; fi
  if "$@"; then ok "MUTANT $m killed by $a: $c"; else bad "MUTANT $m SURVIVED $a: $c"; fi
}
# Each kill names the WRONG SHAPE it reads, never only "not the right one": a copy that errored and
# fell back would also leave the file unequal to want, and must not score.
k_W1() { local w; w="$(mres W1)"; expect_dv "$w" && has_resolved m-W1 "$DV" && ! cmp -s "$w/want" "$w/cons/.claude/$DV" \
           && grep -qxF '{deploy_command}' "$w/cons/.claude/$DV"; }
k_W2() { local w; w="$(mres W2)"; expect_dv "$w" && has_resolved m-W2 "$DV" && ! cmp -s "$w/want" "$w/cons/.claude/$DV" \
           && grep -qF '<!-- scripts/ecs-deploy.sh prod:' "$w/cons/.claude/$DV"; }
k_mode()        { local w; w="$(mres mode)"; expect_dv "$w" && has_resolved m-mode "$DV" && cmp -s "$w/want" "$w/cons/.claude/$DV" && [ "$(xbit "$w/cons/.claude/$DV")" = - ]; }
k_resolved()    { has_resolved "m-$1" "$2"; }
k_treeA()       { ! has_resolved m-treeA "$DV" && has_today m-treeA "$DV"; }
k_noIdem()      { ran m-noIdem2 && has_resolved m-noIdem "$DV" && ! has_resolved m-noIdem2 "$DV" && has_today m-noIdem2 "$DV"; }
k_today()       { has_today "m-$1" "$DV" && ! has_resolved "m-$1" "$DV"; }
k_dropFar()     { has_resolved "m-$1" "$QA" && grep -qxF 'tests/e2e/' "$WORK/mw-$1/cons/.claude/$QA" \
                    && ! grep -qxF 'QA also owns the e2e harness.' "$WORK/mw-$1/cons/.claude/$QA"; }
k_idemMode()    { ran m-idemMode2 && has_resolved m-idemMode2 "$DV" && [ "$(xbit "$WORK/mw-idemMode/cons/.claude/$DV")" = - ]; }
# The leak is seeded on B1, a fallback past (b): on a resolving world the write reuses the same
# `.incoming.$$` name and its `mv` consumes the leaked copy, so only a fallback can show it.
k_leak()        { has_today m-leak "$DV" && [ -n "$(find "$WORK/mw-leak/cons" -name '*.incoming.*' 2>/dev/null)" ]; }
k_writeRestore() { local w="$WORK/mw-writeRestore"; has_today m-writeRestore "$DV" && cmp -s "$w/pre.deploy-validate.md" "$w/cons/.claude/$DV" \
                    && [ "$(ino "$w/cons/.claude/$DV")" = "$(cat "$w/ino.deploy-validate.md")" ] && ! untouched "$w" "$DV"; }
k_finNote()     { ran m-finNote2 && has_today m-finNote "$IM" && [ -z "$(fin_note m-finNote2 "$IM")" ]; }
for m in $MUT_OK; do
  case "$m" in
    W1)  kill_if W1 C2 "re-bucketing as overwrite_from_theirs lands theirs' {token} lines over the consumer's values" k_W1 ;;
    W2)  kill_if W2 C2 "substituting token text rewrites theirs' <!-- {deploy_command}: ... --> comment" k_W2 ;;
    W3)  kill_if W3 B2t "keying on CORE-TEMPLATE-SUBSTITUTED resolves a file whose consumer delta is outside its spans" k_resolved W3 "$DV" ;;
    W4)  kill_if W4 B1 "skipping (c) resolves over a lost after_line anchor" k_resolved W4 "$DV" ;;
    noD) kill_if noD D2 "without (d) theirs' new live {deploy_command} line lands unfilled and resolves" k_resolved noD "$DV" ;;
    noIdem) kill_if noIdem D1 "without the already-merged check the second run falls back on its own write" k_noIdem ;;
    treeA) kill_if treeA D6a "a tree-wide (a) hands back the clean target because ANOTHER file drifted" k_treeA ;;
    mode) kill_if mode C3 "without sync_mode_from_theirs the merged file keeps the consumer's 0644" k_mode ;;
    spanId) kill_if spanId SpF "the second acceptance without span identity resolves spanFar with no write, dropping theirs' line" k_dropFar spanId ;;
    spanIdQ) kill_if spanIdQ SpQ "the second acceptance without span identity resolves spanQ, leaving theirs' reworded block comment unmerged" k_resolved spanIdQ "$QA" ;;
    ssdExit) kill_if ssdExit B1b "reading a non-zero setup-site-drift.sh exit as a pass resolves over an unlocatable site" k_resolved ssdExit "$DV" ;;
    noD7) kill_if noD7 D7 "without the retired-token gate a pending re-point obligation is resolved away" k_resolved noD7 "$DV" ;;
    bareShort) kill_if bareShort SpD "the bare already-merged shortcut (outside-span OK alone) resolves theirs' --wait away unmerged" k_resolved bareShort "$DV" ;;
    rcOnly) kill_if rcOnly SpF "a shortcut trusting merge-file's exit without comparing its output resolves spanFar and drops theirs' line" k_dropFar rcOnly ;;
    dDol) kill_if dDol D+dol "(d) without the \$ exclusion hands back \${LOGDIR}" k_today dDol ;;
    dML)  kill_if dML D+ml "(d) resetting comment state per line reads a multi-line comment's token as live" k_today dML ;;
    dCom) kill_if dCom D+com "(d) treating comment text as live hands back a comment-only reword" k_today dCom ;;
    idemMode) kill_if idemMode M2 "a shortcut without sync_mode_from_theirs leaves the re-run file 0644" k_idemMode ;;
    leak) kill_if leak INC "a write path that leaves its .incoming temp behind" k_leak ;;
    writeRestore) kill_if writeRestore B1 "write-then-restore leaves the same bytes and inode but a newer mtime" k_writeRestore ;;
    laxC) kill_if laxC DlI "a c-hunk test reading left lines only resolves a file missing theirs' deletion beside the filled site" k_resolved laxC "$IM" ;;
    laxCa) kill_if laxCa CAd "the same lax test lets (a) pass a consumer line added beside the filled deploy site" k_resolved laxCa "$DV" ;;
    laxD) kill_if laxD QD "a d-hunk test reading its first line alone resolves a file whose consumer deleted ## Responsibilities" k_resolved laxD "$QA" ;;
    finNote) kill_if finNote FIN "--finish always dropping the NOTE loses implementation.md's unverified row" k_finNote ;;
  esac
done

echo
if [ "$fails" -eq 0 ]; then echo "apply-setup-sited-merge: PASS"; exit 0; fi
echo "apply-setup-sited-merge: FAIL ($fails)"
exit 1
