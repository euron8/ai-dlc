# apply-setup-sited-merge/lib.sh -- the resolution, worlds, drives and predicates of
# apply-setup-sited-merge, sourced by that fixture's run.sh (the behavioural arms, shipped) and by
# apply-setup-sited-merge-mutants/run.sh (the mutation battery, distribution-only). ONE copy, so the
# battery scores its mutants with the predicates the shipped arms run, never a second copy of them.
#
# The caller sources the preamble and scrubs AI_DLC_* itself (I10), sets NAME, sources this file,
# runs its own subject probe, and then calls lib_init, which owns WORK and the ONE EXIT trap that
# removes it. Nothing else here has a side effect at source time but resolving reconcile/.
#
# LAYOUTS. reconcile/ is located relative to THIS file with pick(), never by walking up for a root:
# a walk-up resolves an enclosing real repo when this fixture is extracted under one. BASH_SOURCE,
# not $0, because a sourced file's $0 is its caller's.
#   distribution / receipt extraction: <root>/core/fixtures/<this> -> <root>/core/skills/...
#   consumer:                          <root>/tests/fixtures/<this> -> <root>/.claude/skills/...

set -uo pipefail
[ -n "${NAME:-}" ] || { echo "FIXTURE ERROR: apply-setup-sited-merge/lib.sh sourced without NAME set" >&2; exit 2; }

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
APPLY="$(pick "$LIB_DIR/../../skills/ai-dlc-update/reconcile/apply.sh" \
              "$LIB_DIR/../../../.claude/skills/ai-dlc-update/reconcile/apply.sh")"
[ -n "$APPLY" ] || { echo "$NAME: FIXTURE BROKEN -- reconcile/apply.sh not found beside this fixture in either layout" >&2; exit 2; }
REC="$(cd "$(dirname "$APPLY")" && pwd)"
echo "$NAME: driving $REC/apply.sh"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }
broken() { echo "$NAME: FIXTURE BROKEN -- $1" >&2; exit 2; }

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

fin_note() { awk -F'\t' -v r=".claude/$2" '$1=="NOTE" && $2=="finish-unverified" && $3==r {print $4}' "$WORK/out/$1.out" 2>/dev/null; }

# lib_init -- after the caller's subject probe: the siblings apply.sh shells to, WORK, the trap.
lib_init() {
  local f
  for f in setup-site-drift.sh preclassify.sh setup-sites.md retired-tokens.sh unregistered-drift.sh; do
    [ -f "$REC/$f" ] || broken "$REC/$f is missing beside apply.sh"
  done
  WORK="$(mktemp -d "${TMPDIR:-/tmp}/$NAME.XXXXXX")" || broken "mktemp failed"
  trap 'rm -rf "$WORK"' EXIT
  # Canonical, so a path built under WORK compares equal to one a program derives with `pwd`:
  # macOS TMPDIR ends in a slash, and the `//` it leaves in WORK is in no pwd-derived path.
  WORK="$(cd "$WORK" && pwd -P)" || broken "cannot enter $WORK"
  mkdir -p "$WORK/out" || exit 2
  : > "$WORK/built.want" || exit 2
}

# --- the world builds: a bounded pool, and every world is proven built before anything reads it --
# build() fails by returning 1 inside a backgrounded subshell, where `broken` would end only that
# subshell. So each pooled build writes a `.built` sentinel beside its world on success, the parent
# records every dispatch in built.want, and breap() waits on the whole pool and then requires one
# sentinel per dispatch -- a world that failed, or was never reached, is named and the run BREAKS.
# The builds are independent: every file a build writes is under its own world directory, and $REC
# is only read.
BPOOL=8; bjobs=0; BUILT_N=0; BUILT_OK=0
build_mark() { # <world-dir> <variant>
  build "$1" "$2" > "$WORK/out/build.$(basename "$1").log" 2>&1 && : > "$1/.built"
}
bspawn() { # <world-dir> <variant>
  printf '%s\n' "$1" >> "$WORK/built.want"
  BUILT_N=$((BUILT_N+1))
  build_mark "$1" "$2" &
  bjobs=$((bjobs+1)); [ "$bjobs" -lt "$BPOOL" ] || { wait; bjobs=0; }
}
breap() { # -> BUILT_OK, or BREAK naming every world without a sentinel
  local w miss="" first=""
  wait; bjobs=0; BUILT_OK=0
  while IFS= read -r w; do
    if [ -f "$w/.built" ]; then BUILT_OK=$((BUILT_OK+1)); else miss="$miss $(basename "$w")"; [ -n "$first" ] || first="$w"; fi
  done < "$WORK/built.want"
  if [ -n "$first" ]; then sed 's/^/        /' "$WORK/out/build.$(basename "$first").log" 2>/dev/null | head -8 >&2; fi
  [ "$BUILT_N" -gt 0 ] && [ "$BUILT_OK" -eq "$BUILT_N" ] \
    || broken "$BUILT_OK of $BUILT_N dispatched worlds were built; not built:${miss:- none}"
}
