#!/usr/bin/env bash
# fixture-hygiene -- drive the REAL scripts/validate-fixture-hygiene.sh against seeded probe projects.
#
# THE SUBJECT is the shipping validator, copied byte-identical (cmp -s) with its sibling shard-stub resolver
# scripts/validate-fixture-invocations.sh into each probe project, which carries VERSION so the validator's root walk
# resolves to the PROBE, never to this repository; arm R asserts the corpus count it printed is the probe's. Nothing
# here re-implements a validator rule: every verdict is read off the validator's own output. This fixture never runs
# check mode on the real tree.
#
# THE WORLDS, each built once as a git repository (index only; the validator lists tracked files):
#   dirty  one offender per arm: H1 a `-d …/.git` skip, H2 a declared-tool skip, H3 a `sh -c` start and a written
#          `#!/bin/sh` stub run by path, H12 a run.sh defining a mutation helper, E1 a receipt-x.sh that nothing reads,
#          H6 an unguarded `. "$HERE/../lib/mutant.sh"`, H9 a top-level `sleep 5` carrying a `# bl868-allow:` marker in
#          a world with no H9 allowlist file (it fires, and so does its marker as W-ALLOW-STALE).
#   clean  the near-miss of each, carrying the property a regression would key on: a `-d …/.git` that exits 2, a
#          declared tool that exits 2, `sh` inside an awk program, the same chmod'ed stub run as `bash P` (which
#          ignores the shebang), a run.sh that only MENTIONS a retired battery helper in a comment and a string, the
#          same receipt-x.sh run by its run.sh, the same lib source carrying `|| { … exit 2; }`, and the sleep as the
#          poll quantum of an unbounded `until` wait.
# THE ARMS, each one read of a validator run:
#   D1 D2 D3 D6 D12 DE1 DW  the dirty run (rc 1) names exactly its arm's seeded line under `FAIL H<n>:` / `FAIL E1:`
#       (DW reads `FAIL H9:`; D12 reads `FAIL H12:` and its reasons `def mkmut:2, mkmut:2`)
#   D8  IS receipt-bl929.sh, D9 IS receipt-bl930.sh: each seeds its OWN world and drives the validator (BL-929: a
#       scrubbed fixture and a scrubbed-IMPL stub read SCRUBBED, an unscrubbed unlisted one FAILs H8, a listed one
#       passes; BL-930: the GIT_-only hook driver I10 acquitted, and a listed hook driver, FAIL H8). The dirty and clean
#       worlds' fa and fb carry no scrub and are rows of the world's own H8 list, so H8 is quiet there.
#   C   the clean run is rc 0 with the OK line, which counts 1 receipt and 0 inert (the positive control: a run that
#       scanned nothing cannot print it)
#   R   the clean run's OK line names the probe's corpus count (3 files), so the root walk resolved to the probe
#
# Usage: run.sh     Exit: 0 pass, 1 FAIL, 2 FIXTURE BROKEN.
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "fixture-hygiene: FIXTURE BROKEN: core/fixtures/lib/preamble.sh is absent" >&2; exit 2; }
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT=""; d="$HERE"
while [ -n "$d" ] && [ "$d" != / ]; do
  [ -f "$d/scripts/validate-fixture-hygiene.sh" ] && [ -f "$d/scripts/validate-fixture-invocations.sh" ] && { ROOT="$d"; break; }
  d="$(dirname "$d")"
done
[ -n "$ROOT" ] || { echo "FIXTURE ERROR: no scripts/validate-fixture-hygiene.sh walking up from $HERE" >&2; exit 2; }

WORK="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd -P)"
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$HERE/../lib/report.sh" || { echo "FIXTURE ERROR: lib/report.sh not found" >&2; exit 2; }
VREL=scripts/validate-fixture-hygiene.sh
IREL=scripts/validate-fixture-invocations.sh
g() { env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE -u GIT_OBJECT_DIRECTORY git -c core.hooksPath=/dev/null "$@"; }

# --- the worlds -------------------------------------------------------------------------------------------------
put() { mkdir -p "$(dirname "$1")" && cat > "$1"; }
mk_world() { # <dir> <dirty|clean>
  local w="$1"
  mkdir -p "$w/scripts" && : > "$w/VERSION" && cp -p "$ROOT/$VREL" "$ROOT/$IREL" "$w/scripts/" || return 1
  cmp -s "$ROOT/$VREL" "$w/$VREL" && cmp -s "$ROOT/$IREL" "$w/$IREL" || return 1
  printf 'jq\n' > "$w/tools.tmp"
  if [ "$2" = dirty ]; then
    put "$w/core/fixtures/fa/run.sh" <<'EOF'
#!/usr/bin/env bash
if [ ! -d "$R/.git" ]; then
  echo "SKIP no history"
  exit 0
fi
command -v jq >/dev/null 2>&1 || { echo "SKIP no jq"; exit 0; }
sh -c 'exit 0' & p=$!
printf '#!/bin/sh\nexit 0\n' > "$W/stub" && chmod +x "$W/stub"
"$W/stub"
. "$HERE/../lib/mutant.sh"
EOF
    # fa:11, the H9 offender: a marked sleep in a world with NO scripts/bl868-wait-allowlist.txt, so it must FIRE
    # and its marker read W-ALLOW-STALE (an absent list acquits nothing). Appended by printf, so this file's own line
    # does not END in the marker and the real tree's H9 reads no marker here.
    printf '%s\n' 'sleep 5 # bl868-allow: fa-wait' >> "$w/core/fixtures/fa/run.sh"
    put "$w/core/fixtures/fb/run.sh" <<'EOF'
#!/usr/bin/env bash
mkmut() { :; }
EOF
    cp "$w/tools.tmp" "$w/core/fixtures/fa/tools.decl"
    printf '#!/usr/bin/env bash\nexit 0\n' > "$w/core/fixtures/fb/receipt-x.sh"
  else
    put "$w/core/fixtures/fa/run.sh" <<'EOF'
#!/usr/bin/env bash
if [ ! -d "$R/.git" ]; then
  echo "FIXTURE BROKEN: no history; exit 0 would lie"
  exit 2
fi
command -v jq >/dev/null 2>&1 || { echo "FIXTURE BROKEN: no jq"; exit 2; }
awk '{ if (sh != "") print sh }' f
printf '#!/bin/sh\nexit 0\n' > "$W/stub" && chmod +x "$W/stub"
bash "$W/stub"
. "$HERE/../lib/mutant.sh" || { echo "FIXTURE BROKEN: cannot source lib/mutant.sh" >&2; exit 2; }
until [ -s "$W/stub" ]; do sleep 0.1; done
EOF
    put "$w/core/fixtures/fb/run.sh" <<'EOF'
#!/usr/bin/env bash
# mutant_killed and mkmut were retired with the batteries; this fixture only drives its subject
echo "no mkmut() { :; } here"
bash "$HERE/receipt-x.sh"
EOF
    cp "$w/tools.tmp" "$w/core/fixtures/fa/tools.decl"
    printf '#!/usr/bin/env bash\nexit 0\n' > "$w/core/fixtures/fb/receipt-x.sh"
  fi
  rm -f "$w/tools.tmp"
  # fa and fb carry no AI_DLC_* scrub; in both worlds they are rows of the world's own H8 list, so H8 stays quiet
  printf '# probe\nfa\tworld seed\nfb\tworld seed\n' > "$w/scripts/env-scrub-allowlist.txt"
  env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE -u GIT_OBJECT_DIRECTORY git -c core.hooksPath=/dev/null init -q "$w" && g -C "$w" add -A core >/dev/null 2>&1
}
mk_world "$WORK/w-dirty" dirty && mk_world "$WORK/w-clean" clean \
  || { echo "FIXTURE BROKEN: could not build the probe worlds byte-identical" >&2; exit 2; }

# --- one validator run per distinct state -------------------------------------------------------------------------
drive() { # <tag> <world dir>
  ( cd "$2" && unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE && bash "$2/$VREL" ) > "$WORK/c.$1.out" 2> "$WORK/c.$1.err"
  echo $? > "$WORK/c.$1.rc"
}
# d8drive / d9drive <tag>: arms D8 and D9 ARE receipt-bl929.sh and receipt-bl930.sh, each seeding its own world
# (BL-929: a scrubbed fixture, a scrubbed-IMPL stub, an unscrubbed unlisted and an allowlisted one; BL-930: the
# GIT_-only hook driver I10 acquitted and a listed hook driver) and driving the validator.
d8drive() {
  bash "$HERE/receipt-bl929.sh" > "$WORK/c.$1.out" 2> "$WORK/c.$1.err"
  echo $? > "$WORK/c.$1.rc"
}
d9drive() {
  bash "$HERE/receipt-bl930.sh" > "$WORK/c.$1.out" 2> "$WORK/c.$1.err"
  echo $? > "$WORK/c.$1.rc"
}
has()  { grep -qF -- "$2" "$WORK/c.$1.out" "$WORK/c.$1.err"; }
rcis() { [ "$(cat "$WORK/c.$1.rc" 2>/dev/null)" = "$2" ]; }
# section <tag> <arm>: the lines under `FAIL <arm>:` up to the next unindented line
section() { awk -v A="FAIL $2:" '$0 == A { on = 1; next } on && /^    / { print; next } on { exit }' "$WORK/c.$1.out"; }
verdict() { # <arm> <tag>
  local t="$2"
  case "$1" in
    D1) rcis "$t" 1 && [ "$(section "$t" H1)" = '    core/fixtures/fa/run.sh:2: if [ ! -d "$R/.git" ]; then' ] ;;
    D2) rcis "$t" 1 && [ "$(section "$t" H2)" = '    core/fixtures/fa/run.sh:6: command -v jq >/dev/null 2>&1 || { echo "SKIP no jq"; exit 0; }' ] ;;
    D3) rcis "$t" 1 && [ "$(section "$t" H3)" = "    core/fixtures/fa/run.sh:7: sh -c 'exit 0' & p=\$!
    core/fixtures/fa/run.sh:8: a #!/bin/sh stub \$W/stub written here is executed at :9: \"\$W/stub\"" ] ;;
    D12) rcis "$t" 1 && [ "$(section "$t" H12)" = '    core/fixtures/fb/run.sh: def mkmut:2, mkmut:2' ] ;;
    D6) rcis "$t" 1 && [ "$(section "$t" H6)" = '    core/fixtures/fa/run.sh:10: . "$HERE/../lib/mutant.sh"' ] ;;
    DE1) rcis "$t" 1 && [ "$(section "$t" E1)" = '    INERT core/fixtures/fb/receipt-x.sh' ] ;;
    # the marker is spelled through H9MK so no line of THIS file ends in a marker (the real tree's H9 reads raw lines)
    DW) rcis "$t" 1 && [ "$(section "$t" H9)" = "    W-SLEEP core/fixtures/fa/run.sh:11: sleep 5 $H9MK
    W-ALLOW-STALE core/fixtures/fa/run.sh fa-wait: line 11 carries $H9MK and no allowlist row names that id" ] ;;
    D8) rcis "$t" 0 && has "$t" 'receipt-bl929: PASS' ;;
    D9) rcis "$t" 0 && has "$t" 'receipt-bl930: PASS' ;;
    C)  rcis "$t" 0 && has "$t" 'OK: validate-fixture-hygiene -- ' && has "$t" 'E1 1 receipt(s), 0 inert' ;;
    R)  rcis "$t" 0 && has "$t" '-- 3 fixture .sh scanned;' ;;
    *) return 1 ;;
  esac
}
H9MK="# bl868-allow: fa-wait"

drive dirty "$WORK/w-dirty" & drive clean "$WORK/w-clean" & d8drive d8 & d9drive d9 &
wait
for a in D1 D2 D3 D6 D12 DE1 DW; do
  if verdict "$a" dirty; then ok "$a the dirty world names exactly its seeded line"; : > "$WORK/base.$a"
  else bad "$a fails on the validator (rc $(cat "$WORK/c.dirty.rc")): $(head -c 800 "$WORK/c.dirty.out" | tr '\n' ' ')"; fi
done
if verdict D8 d8 && grep -qxF 'receipt-bl929: PASS' "$WORK/c.d8.out"; then
  ok "D8 receipt-bl929.sh: a scrubbed fixture and a scrubbed-IMPL stub read SCRUBBED, an unscrubbed unlisted one FAILs H8, a listed one passes"; : > "$WORK/base.D8"
  grep -xF 'receipt-bl929: PASS' "$WORK/c.d8.out"   # the receipt's own line, re-emitted for BL-929's verify: line
else bad "D8 receipt-bl929.sh did not PASS (rc $(cat "$WORK/c.d8.rc")): $(head -c 800 "$WORK/c.d8.out" | tr '\n' ' ')"; fi
if verdict D9 d9 && grep -qxF 'receipt-bl930: PASS' "$WORK/c.d9.out"; then
  ok "D9 receipt-bl930.sh: the GIT_-only hook driver I10 acquitted, and a listed hook driver, FAIL H8; the AI_DLC_ near-miss reads SCRUBBED"
  grep -xF 'receipt-bl930: PASS' "$WORK/c.d9.out"   # the receipt's own line, re-emitted for BL-930's verify: line
else bad "D9 receipt-bl930.sh did not PASS (rc $(cat "$WORK/c.d9.rc")): $(head -c 800 "$WORK/c.d9.out" | tr '\n' ' ')"; fi
verdict C clean && ok "C the clean world (every near-miss) is rc 0 with the OK line" \
  || bad "C the clean world is not clean (rc $(cat "$WORK/c.clean.rc")): $(head -c 800 "$WORK/c.clean.out" | tr '\n' ' ')"
verdict R clean && ok "R the validator resolved the PROBE root (3 fixture .sh scanned, not this repository's corpus)" \
  || bad "R the clean run did not report the probe's 3-file corpus"
if [ -e "$WORK/base.D1" ] && verdict C clean; then
  echo "HERMETIC-CONSUMED $VREL"
  echo "HERMETIC-CONSUMED $IREL"
fi

report_end fixture-hygiene
