# Shared worlds for story-evidence-scaffold (and, formerly, its mutation battery). SOURCED, never run: it defines functions and tables and prints nothing.
#
# WHY THIS FILE EXISTS. The shipped fixture asserts the validator against a control vector and in place;
# the battery (dist-only) asserts that each mutated COPY of the validator moves exactly its own cases.
# Both drive the same seeded git worlds through the same verdict function, so a second copy of the
# world builder would be two opinions about one input. Single-sourcing it here means a change to a world
# moves both sides together. It ships with the shipped fixture (install.sh copies the whole directory),
# and the battery reads it as a sibling inside core/fixtures/, never by walking up into a core subtree.
#
# The sourcing script defines WORK (a scratch dir), ok, bad and DIR before calling anything here, and
# must not already own any of these names.
SE_WDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

locate() { # <core-relative path under core/> -> the first layout that has it
  local rel="$1" cand
  for cand in "$SE_WDIR/../../$rel" "$SE_WDIR/../../../.claude/$rel"; do
    [ -f "$cand" ] && { printf '%s\n' "$cand"; return 0; }
  done
  return 1
}
HE=""
for cand in "$SE_WDIR/../../scripts/validate-handoff-evidence.sh" "$SE_WDIR/../../../scripts/ai-dlc/validate-handoff-evidence.sh"; do
  [ -f "$cand" ] && { HE="$cand"; break; }
done
# The bookkeeping arms call sprint-status.sh beside the validator, which loads its schema. Both
# are subjects: a mutant tree without them reads every status arm as a SKIP.
SCHEMA="$(locate schemas/sprint-status.json)" || SCHEMA=""
SSH=""
[ -n "$HE" ] && [ -f "$(dirname "$HE")/sprint-status.sh" ] && SSH="$(dirname "$HE")/sprint-status.sh"

# --- validate-handoff-evidence.sh, driven ---------------------------------------
# Seeded git worlds. CLEAN carries every near-miss: a gitignored full-suite capture cited
# without RED words (not refused by (b)), a `test-results/local/**` subtree, a `/api/x/{id}`
# route and a `test-results/red-*.txt` glob whose every match is committed (not refused by
# (c)), a `sha=<sha> cmd=<cmd>` capture header (accepted by (a)), a modified
# `tools/requirements.txt` cited by path with no command line (not a capture), a capture
# whose `head:` is the base sha (a WARN, exit 0), a bare `test_new` test row and an
# off-vocabulary `manual` row (not refused by (d)/(e)). The nocmd offender carries `cmd=`
# mid-line, which is not a command header. The glob offender cites `seed{1,2}.txt` with only
# seed1 committed.
# Each offender world is CLEAN plus one commit carrying exactly one defect.
gitw() { local d="$1"; shift; GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 \
  git -C "$d" -c user.name=fx -c user.email=fx@example.invalid -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@"; }
STORY=stories/story-1.md
IMPLY_DIR=_bmad-output/implementation-artifacts
PLANY_DIR=_bmad-output/planning-artifacts
ymlw() { # <yaml path> <status> -> one sprint, one story row naming $STORY
  printf 'sprint: 1\nstatus: in_progress\nstories:\n  story-1:\n    status: %s\n    file: %s\n' "$2" "$STORY" > "$1"
}
story_awk() { # <world> <awk program> -> rewrite the story in place; 1 when it changed nothing
  awk "$2" "$1/$STORY" > "$1/.s" || return 1
  if cmp -s "$1/.s" "$1/$STORY"; then rm -f "$1/.s"; return 1; fi
  mv "$1/.s" "$1/$STORY"
}
build_world() { # <dir> <variant>
  local w="$1" v="$2" b
  mkdir -p "$w/tests" "$w/test-results" "$w/stories" "$w/tools" || return 2
  gitw "$w" init -q || return 2
  printf 'test-results/\n' > "$w/.gitignore"
  printf 'class TestA:\n    def test_new(self):\n        assert True\n' > "$w/tests/test_x.py"
  printf 'pytest\n' > "$w/tools/requirements.txt"
  # The base commit's story already carries a status, so a range cell whose frozen sha IS the
  # base reads a story the status arms can decide, and the cell stays about its range warning.
  printf -- '---\nstatus: review\n---\n# Story 1\n' > "$w/$STORY"
  gitw "$w" add -A && gitw "$w" commit -qm base || return 2
  b="$(gitw "$w" rev-parse HEAD)"
  printf 'class TestA:\n    def test_new(self):\n        assert 1 == 1\n' > "$w/tests/test_x.py"
  printf 'pytest\npytest-xdist\n' > "$w/tools/requirements.txt"
  printf '$ pytest -q\n# cwd: /w  head: %s\n1 passed\n' "$b" > "$w/test-results/full.txt"
  printf 'mutation-red replay\n  head:       %s\n  mutated:    RED (exit 1)\nPROVEN: x\n' "$b" > "$w/test-results/red-guard.txt"
  printf '1 passed\n' > "$w/test-results/full-suite.txt"
  printf 'sha=%s cmd=pytest -q -n auto cwd=/w\n1 passed\n' "$b" > "$w/test-results/p4.txt"
  # The bookkeeping half: the story at `review` in its frontmatter, and its row agreeing in BOTH
  # canonical views, so that a mutant reading the planning view moves only `planlag`.
  if [ "$v" != noyaml ]; then
    mkdir -p "$w/$IMPLY_DIR" "$w/$PLANY_DIR" || return 2
    ymlw "$w/$IMPLY_DIR/sprint-status.yaml" review; ymlw "$w/$PLANY_DIR/sprint-status.yaml" review
  fi
  printf -- '---\nstatus: review\n---\n' > "$w/$STORY"
  cat >> "$w/$STORY" <<'EOS'
# Story 1

## Dev Agent Record

Full-collection run: `test-results/full.txt` (1 passed).
Mutation self-check: PROVEN, capture `test-results/red-guard.txt`.
Parallel run: `test-results/p4.txt`.
A local re-run sits in `test-results/full-suite.txt` (gitignored, not committed).
A scratch re-run sits in `test-results/local/rerun.txt` (gitignored).
Dependencies pinned in `tools/requirements.txt`.
Every capture lives under `test-results/local/**`; the route under test is `/api/x/{id}`.
All committed captures: `test-results/red-*.txt`.

## Production Integrity Tests

None: no production path changed.

## Smoke Test Updates

None.

## Rename Verification

not a rename

## Strategy Test IDs

| Strategy id | Case | Kind | Resolves to |
|---|---|---|---|
| TS-1-01 | a | test | `tests/test_x.py::TestA::test_new` |
| TS-1-01 | b | test | test_new |
| TS-1-02 | - | manual | operator reads the dashboard |
EOS
  gitw "$w" add -A && gitw "$w" add -f test-results/full.txt test-results/red-guard.txt test-results/p4.txt \
    && gitw "$w" commit -qm work || return 2
  case "$v" in
    clean) ;;
    nocmd) printf '1 passed (xdist cmd=auto)\n' > "$w/test-results/nocmd.txt"
           printf 'Smoke run: `test-results/nocmd.txt`.\n' >> "$w/$STORY"
           gitw "$w" add -f test-results/nocmd.txt ;;
    redun) printf 'mutation-red replay\n' > "$w/test-results/red-extra.txt"
           printf 'Mutation-RED capture: `test-results/red-extra.txt`.\n' >> "$w/$STORY" ;;
    glob)  printf '$ pytest --seed 1\nhead: %s\n1 passed\n' "$b" > "$w/test-results/seed1.txt"
           gitw "$w" add -f test-results/seed1.txt || return 2
           printf 'Seeded runs: `test-results/seed{1,2}.txt`.\n' >> "$w/$STORY" ;;
    headeq) w0="$(gitw "$w" rev-parse HEAD)"
           printf '$ pytest -q\nhead: %s\n1 passed\n' "$w0" > "$w/test-results/full.txt"
           printf 'mutation-red replay\n  head:       %s\n  mutated:    RED (exit 1)\nPROVEN: x\n' "$w0" > "$w/test-results/red-guard.txt"
           gitw "$w" add -f test-results/full.txt test-results/red-guard.txt || return 2 ;;
    empty) printf '| TS-1-03 | - | test |  |\n' >> "$w/$STORY" ;;
    second) printf '| TS-1-05 | c | test | `tests/test_x.py::TestA::test_new`, `tests/test_x.py::TestA::test_gone` |\n' >> "$w/$STORY" ;;
    short) printf '| TS-1-04 | - | test |\n' >> "$w/$STORY" ;;
    shortnores)
           sed 's/^| Strategy id | Case | Kind | Resolves to |$/| Strategy id | Case | Kind | Node |/' "$w/$STORY" > "$w/.s" && mv "$w/.s" "$w/$STORY"
           printf '| TS-1-04 | - | test |\n' >> "$w/$STORY" ;;
    rename|rebind)
           printf 'class TestA:\n    def test_renamed(self):\n        assert 1 == 1\n' > "$w/tests/test_x.py"
           [ "$v" = rebind ] && sed 's/TestA::test_new`/TestA::test_renamed`/' "$w/$STORY" > "$w/.s" && mv "$w/.s" "$w/$STORY" ;;
    movefile) gitw "$w" mv tests/test_x.py tests/test_y.py || return 2 ;;
    noyaml|dirtyyaml) ;;
    notreview) story_awk "$w" '{ sub(/^status: review$/, "status: in-progress"); print }' || return 2
           ymlw "$w/$IMPLY_DIR/sprint-status.yaml" in-progress; ymlw "$w/$PLANY_DIR/sprint-status.yaml" in-progress ;;
    yamlmis) ymlw "$w/$IMPLY_DIR/sprint-status.yaml" ready-for-dev; ymlw "$w/$PLANY_DIR/sprint-status.yaml" ready-for-dev ;;
    planlag) ymlw "$w/$PLANY_DIR/sprint-status.yaml" ready ;;
    demoted) story_awk "$w" '{ sub(/^## Smoke Test Updates$/, "### Smoke Test Updates"); print }' || return 2 ;;
    level1)  story_awk "$w" '{ sub(/^## Smoke Test Updates$/, "# Smoke Test Updates"); print }' || return 2 ;;
    trail)   story_awk "$w" '/^## Rename Verification$/ { print "## Rename Verification (dev)"; print ""; print "### Rename Verification"; next } {print}' || return 2 ;;
    fence)   story_awk "$w" '/^## Production Integrity Tests$/ { print "```"; print "### Production Integrity Tests"; print "```"; next } {print}' || return 2 ;;
    stratrail) story_awk "$w" '{ sub(/^## Strategy Test IDs$/, "## Strategy Test IDs (rev 2)"); print }' || return 2
           printf '| TS-1-03 | - | test |  |\n' >> "$w/$STORY" ;;
    crlfstrat) printf '| TS-1-03 | - | test |  |\n' >> "$w/$STORY"
           story_awk "$w" '{ print $0 "\r" }' || return 2 ;;
    crlfdemoted) story_awk "$w" '{ sub(/^## Smoke Test Updates$/, "### Smoke Test Updates"); print $0 "\r" }' || return 2 ;;
    latin1yaml) story_awk "$w" '{ sub(/^status: review$/, "status: in-progress"); print }' || return 2
           ymlw "$w/$IMPLY_DIR/sprint-status.yaml" in-progress; ymlw "$w/$PLANY_DIR/sprint-status.yaml" in-progress
           printf '# caf\351 note\n' >> "$w/$IMPLY_DIR/sprint-status.yaml" ;;
    latin1story) printf '\nNotes: caf\351 au lait.\n' >> "$w/$STORY" ;;
    dirtystory) story_awk "$w" '{ sub(/^status: review$/, "status: in-progress"); print }' || return 2
           ymlw "$w/$IMPLY_DIR/sprint-status.yaml" in-progress; ymlw "$w/$PLANY_DIR/sprint-status.yaml" in-progress ;;
    dirtyhead) story_awk "$w" '{ sub(/^## Smoke Test Updates$/, "### Smoke Test Updates"); print }' || return 2 ;;
    nostatus) story_awk "$w" '{ sub(/^status: review$/, "title: story 1"); print }' || return 2 ;;
    mixfence) story_awk "$w" '/^## Smoke Test Updates$/ { print "~~~"; print "```"; print "~~~"; print ""; print "### Smoke Test Updates"; next } {print}' || return 2 ;;
    untracked) gitw "$w" rm -q --cached "$STORY" || return 2
           mkdir -p "$w/.git/info" && printf '%s\n' "$STORY" >> "$w/.git/info/exclude" || return 2 ;;
    latin1strat) printf '| TS-1-06 | - | manual | caf\351 au lait |\n| TS-1-03 | - | test |  |\n' >> "$w/$STORY" ;;
    # (j) worlds. The script's own header is `$ <argv>` then `mutation-red replay` then `head:`.
    rpfirst) printf '$ pytest -k "a or b"\nhead: %s\n$ scripts/ai-dlc/validate-mutation-red.sh x.py 1 y pytest\nmutation-red replay\n  head:       %s\n  mutated:    RED (exit 1)\n' "$b" "$b" > "$w/test-results/rp-red-first.txt"
           gitw "$w" add -f test-results/rp-red-first.txt || return 2
           printf 'Mutation-RED capture: `test-results/rp-red-first.txt`.\n' >> "$w/$STORY" ;;
    rps319) printf '$ scripts/ai-dlc/validate-mutation-red.sh x.py 1 y pytest -k "a or b"\nhead: %s\nmutation-red replay\n  head:       %s\n  mutated:    RED (exit 1)\n' "$b" "$b" > "$w/test-results/rp-red-s319.txt"
           gitw "$w" add -f test-results/rp-red-s319.txt || return 2
           printf 'Mutation-RED capture: `test-results/rp-red-s319.txt`.\n' >> "$w/$STORY" ;;
    rpok)  printf 'mutation-red replay\n  head:       %s\n  mutated:    RED (exit 1)\n$ pytest -q\n' "$b" > "$w/test-results/rp-red-line1.txt"
           printf '$ scripts/ai-dlc/validate-mutation-red.sh x.py 1 y pytest\nmutation-red replay\n  head:       %s\n  mutated:    RED (exit 1)\n' "$b" > "$w/test-results/rp-red-script.txt"
           gitw "$w" add -f test-results/rp-red-line1.txt test-results/rp-red-script.txt || return 2
           printf 'Mutation-RED captures: `test-results/rp-red-line1.txt`, `test-results/rp-red-script.txt`.\n' >> "$w/$STORY" ;;
    rphead) w0="$(gitw "$w" rev-parse HEAD)"
           printf 'head: %s\n$ scripts/ai-dlc/validate-mutation-red.sh x.py 1 y pytest\nmutation-red replay\n  head:       %s\n  mutated:    RED (exit 1)\n' "$w0" "$b" > "$w/test-results/rp-red-head.txt"
           printf 'head: %s\nmutation-red replay\n  mutated:    RED (exit 1)\n' "$b" > "$w/test-results/rp-red-fallback.txt"
           gitw "$w" add -f test-results/rp-red-head.txt test-results/rp-red-fallback.txt || return 2
           printf 'Mutation-RED captures: `test-results/rp-red-head.txt`, `test-results/rp-red-fallback.txt`.\n' >> "$w/$STORY" ;;
    *) return 2 ;;
  esac
  gitw "$w" add -A && gitw "$w" commit -qm "$v" --allow-empty || return 2
  printf '%s\n' "$b" > "$w/.B"; gitw "$w" rev-parse HEAD > "$w/.T"
  [ "$v" = latin1strat ] && [ -n "$UTF8_LOCALE" ] && printf '%s\n' "$UTF8_LOCALE" > "$w/.LC"
  # After the commit: the working tree disagrees, the frozen sha agrees. Read at <frozen>, quiet.
  [ "$v" = dirtyyaml ] && ymlw "$w/$IMPLY_DIR/sprint-status.yaml" done
  # After the commit: the working tree is FIXED and the frozen sha is not. Read at <frozen>, refused.
  if [ "$v" = dirtystory ]; then
    story_awk "$w" '{ sub(/^status: in-progress$/, "status: review"); print }' || return 2
    ymlw "$w/$IMPLY_DIR/sprint-status.yaml" review; ymlw "$w/$PLANY_DIR/sprint-status.yaml" review
  fi
  if [ "$v" = dirtyhead ]; then
    story_awk "$w" '{ sub(/^### Smoke Test Updates$/, "## Smoke Test Updates"); print }' || return 2
  fi
  if [ "$v" = untracked ]; then
    gitw "$w" cat-file -e "HEAD:$STORY" 2>/dev/null && return 2
    [ -f "$w/$STORY" ] || return 2
  fi
  return 0
}
# verdict <script> <world> <mode> -> "<rc>:<sorted refusal kinds>[:W][:E]"
# :W is the head-tree WARN on full.txt; :E is any stderr line other than the script's own
# verdict line (an `awk: newline in string` abort is how the multi-line `-v` defect showed).
verdict() {
  local s="$1" w="$2" m="$3" o rc k e="$WORK/.stderr" lc=""
  # A world carrying `.LC` is driven under that locale: with no locale set (`env -i`, or an
  # inherited C locale) BSD awk never aborts, so a world about the abort must force one itself.
  [ -f "$w/.LC" ] && lc="$(cat "$w/.LC")"
  if [ "$m" = s ]; then o="$(env ${lc:+LC_ALL="$lc"} bash "$s" -C "$w" --strategy "$(cat "$w/.T")" "$STORY" 2>"$e")"; rc=$?
  else o="$(bash "$s" -C "$w" "$STORY" "$(cat "$w/.B")" "$(cat "$w/.T")" 2>"$e")"; rc=$?; fi
  k="$(awk '/^REFUSED /{print $2}' <<<"$o" | sort | tr '\n' ',')"
  case "$o" in *"WARN head-tree test-results/full.txt"*) k="$k:W" ;; esac
  case "$o" in *"SKIP STATUS ("*) k="$k:S" ;; esac
  grep -qv '^validate-handoff-evidence: ' "$e" && k="$k:E"
  printf '%s:%s' "$rc" "$k"
}
# Cases 10-13 are appended so the 1-9 indices every mutant below names stay put, and 14-23 after
# them for the same reason.
# headeq: the captures' head: is the commit that frozen only adds them to, with FOUR captures
# cited, so the head-tree arm must be quiet and stderr empty. second: the first `.py::` token
# of a cell resolves and the second does not. short: a three-cell row under a header that has
# `Resolves to`; shortnores: the same row under a header that does not (not refused).
# The bookkeeping cases, each CLEAN plus one property. Offenders: notreview (story and both rows
# in-progress, so only (g) can fire), yamlmis (story review, rows ready-for-dev), demoted
# (`### Smoke Test Updates` only), level1 (`# Smoke Test Updates` only). Near-misses: noyaml (no
# sprint-status yaml: exit 0 with a SKIP STATUS line, the :S marker), dirtyyaml (the yaml edited
# to `done` in the working tree AFTER the commit; the frozen sha agrees), planlag (the planning
# view at `ready`, the implementation view agreeing), trail (`## Rename Verification (dev)` beside
# a `### Rename Verification`, so the heading is present at level 2 only under the trailing-text
# grammar), fence (`### Production Integrity Tests` only inside a code fence, absent outside), and
# stratrail: strategy mode under `## Strategy Test IDs (rev 2)` with an empty cell, refused only
# when the shared grammar reads a heading with trailing text as the table's heading.
# Cases 24-31, appended for the same reason. crlfstrat: the clean story with CRLF line ends and an
# empty cell, so strategy mode reads the table only if the heading grammar strips the CR.
# crlfdemoted: CRLF with `### Smoke Test Updates`. latin1yaml: a story and rows at in-progress and
# one non-UTF-8 byte in a yaml comment, so status-not-review must not ride on the row half.
# latin1story: a non-UTF-8 byte in the story body, quiet, no SKIP (a Traceback is a SKIP).
# dirtystory and dirtyhead: the defect committed, the working tree fixed after the commit, so only
# a reader of the disk passes them. nostatus: a committed story with no status (status-missing).
# untracked: the story is not tracked at <frozen> and sits on disk (story-untracked).
# mixfence (32): `~~~`, a "```" inside it, `~~~` closing it, then `### Smoke Test Updates`
# OUTSIDE every fence. A toggle on any marker reads the closing `~~~` as an opening and hides it.
# Mode `k` is handoff mode over the bookkeeping worlds. It is its own mode for cost only: an
# evidence-arm mutant runs the evidence worlds, and the bookkeeping worlds report their WANT.
# latin1strat (33): strategy mode over a row carrying one non-UTF-8 byte ABOVE an empty cell, driven
# under a UTF-8 locale (the world's `.LC`), so BSD awk without LC_ALL=C aborts at that row and the
# empty cell below it is never read.
# Cases 34-37, the replay-preamble arm (j), appended for the same reason. rpfirst: a hand `$ ` and
# `head:`, then the script's own `$ ` right above `mutation-red replay` -- refused, and the only world
# separating "the FIRST `$ ` is right above the replay" from "SOME `$ ` is". rps319: graph s319's
# shape, a hand `$ ` then `head:` then the replay (refused). rpok: the replay at line 1 with a `$ `
# BELOW it, and the script's `$ ` right above the replay (both accepted). rphead: the head-read arm;
# its two captures are read by name in run.sh, not through this vector.
CASES='clean:h clean:s nocmd:h redun:h glob:h empty:s rename:s rebind:s movefile:s headeq:h second:s short:s shortnores:s noyaml:k dirtyyaml:k notreview:k yamlmis:k planlag:k demoted:k level1:k trail:k fence:k stratrail:s crlfstrat:s crlfdemoted:k latin1yaml:k latin1story:k dirtystory:k dirtyhead:k nostatus:k untracked:k mixfence:k latin1strat:s rpfirst:h rps319:h rpok:h rphead:h'
WANT='0::W 0: 1:no-command,:W 1:red-untracked,:W 1:glob-cited,:W 1:empty-cell, 1:node-missing, 0: 1:node-missing, 0: 1:node-missing, 1:short-row, 0: 0::W:S 0::W 1:status-not-review,:W 1:status-yaml-mismatch,:W 0::W 1:heading-demoted,:W 1:heading-demoted,:W 0::W 0::W 1:empty-cell, 1:empty-cell, 1:heading-demoted,:W 1:status-not-review,:W 0::W 1:status-not-review,:W 1:heading-demoted,:W 1:status-missing,:W 1:story-untracked,:W 1:heading-demoted,:W 1:empty-cell, 1:replay-preamble,:W 1:replay-preamble,:W 0::W 0::W'
# The UTF-8 locale latin1strat is driven under: the first one in which THIS awk aborts on a
# non-UTF-8 byte. Empty where none does (gawk, mawk, or no UTF-8 locale installed): the abort the
# world is about cannot happen on this host, and its mutant below says so instead of scoring.
UTF8_LOCALE=""
LATIN1_PROBE="$(printf 'caf\351')"
for l in en_US.UTF-8 C.UTF-8; do
  # A regex match, because that is what aborts: a bare record count reads the byte fine.
  if ! LC_ALL="$l" awk '{gsub(/a/, "")} END{print 1}' <<<"$LATIN1_PROBE" >/dev/null 2>&1; then UTF8_LOCALE="$l"; break; fi
done

# A mutant TREE: the whole scripts directory and the schema, laid out so sprint-status.sh finds
# its schema script-relative and its root by its own walk. A lone validator copy finds no
# sibling and turns every status arm into a SKIP, which reads as a kill or a survival for the
# wrong reason. mk_tree <name> -> path of the validator in that tree, sibling asserted present.
mk_tree() {
  local t="$WORK/tree-$1"
  mkdir -p "$t/core/scripts" "$t/core/schemas" "$t/core/skills/ai-dlc" || return 1
  cp -R "$(dirname "$HE")/." "$t/core/scripts/" && cp "$SCHEMA" "$t/core/schemas/sprint-status.json" || return 1
  [ -f "$t/core/scripts/sprint-status.sh" ] && [ -f "$t/core/scripts/validate-handoff-evidence.sh" ] || return 1
  printf '%s\n' "$t/core/scripts/validate-handoff-evidence.sh"
}
vector() { # <script> [modes] -> space-separated verdicts in CASES order
  # With modes (letters from h, k, s), only the cases of those modes run and every other case is
  # reported as its WANT value, so it can never move: a mutant inside one mode's code path cannot
  # reach another mode's worlds. Measured solo on the unsharded fixture: a bookkeeping-mode verdict
  # costs about 0.4s, so a mutant run over the 17 bookkeeping worlds is about 6-7s, a handoff-mode
  # mutant about 3s and a strategy-mode mutant under a second; the 16 bookkeeping mutants were about
  # 112s of a 168s run, which is why the battery is dealt by mode.
  # Serial on purpose: running the cases concurrently lost reads from the sandbox read-set
  # tracer's stream (73 paths) and the map then OMITTED the fixture.
  local s="$1" only="${2:-}" c out="" i=0
  for c in $CASES; do
    i=$((i+1))
    if [ -n "$only" ] && case "$only" in *"${c#*:}"*) false ;; *) true ;; esac; then
      out="$out $(awk -v n="$i" '{print $n}' <<<"$WANT")"
    else
      out="$out $(verdict "$s" "$WORK/world-${c%%:*}" "${c#*:}")"
    fi
  done
  printf '%s' "${out# }"
}
# se_build_worlds <modes> -> seeds one world per distinct case name of those modes (letters from h, k, s)
# under $WORK/world-<name>. A shard builds ONLY its dealt modes' worlds. Returns 1 when any world failed.
se_build_worlds() {
  local want="$1" c v built=" " okw=0
  for c in $CASES; do
    case "$want" in *"${c#*:}"*) ;; *) continue ;; esac
    v="${c%%:*}"
    case "$built" in *" $v "*) continue ;; esac
    built="$built$v "
    build_world "$WORK/world-$v" "$v" || { okw=1; bad "FIXTURE BROKEN: could not seed git world '$v'"; }
  done
  return "$okw"
}
  # mkmut <name> <he|ss> <from-literal> <to-literal> -> path of the validator to drive, or
  # nothing when the mutation matched nothing. A validator mutant is written INTO the control
  # tree's scripts dir under its own name, so it finds the real sprint-status.sh beside it; a
  # sprint-status.sh mutant gets a tree of its own (mk_tree asserts the sibling is there).
mkmut() {
  local name="$1" tgt="$2" src m t
  if [ "$tgt" = ss ]; then
    t="$(mk_tree "$name")" || return 1
    src="$SSH"; m="$(dirname "$t")/sprint-status.sh"
  else
    src="$HE"; m="$(dirname "$HECTL")/he-mut-$name.sh"; t="$m"
  fi
  FROM="$3" TO="$4" awk 'BEGIN{f=ENVIRON["FROM"]; t=ENVIRON["TO"]} !done && (p=index($0,f)) {$0=substr($0,1,p-1) t substr($0,p+length(f)); done=1} {print}' "$src" > "$m.tmp"
  if cmp -s "$src" "$m.tmp"; then rm -f "$m.tmp"; return 1; fi
  mv "$m.tmp" "$m"
  printf '%s\n' "$t"
}
