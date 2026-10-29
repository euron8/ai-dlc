#!/usr/bin/env bash
# BL-845 receipt (the mechanical half of Check 11: smoke_arms, run by --smoke and by handoff mode). Usage:
#   bash receipt-bl845.sh <path to validate-handoff-evidence.sh> [<worlds dir> [<cells>]]
# With <cells> (space-separated cell names), only those cells and the `clean` control run: a mutant run
# names the one cell that decides it. Without it every cell runs.
# With <worlds dir>, the worlds are seeded into it ONCE (it then carries `.seeded`) and every later call
# reuses them: a mutant changes the validator, never a world, and the validator only reads them through
# git. run.sh holds that to byte-identity with a snapshot. Without it, a scratch dir is seeded and removed.
# One repository per cell, each a <base> commit and a <frozen> commit, driven with
# `--smoke stories/s.md <base> <frozen>` unless the cell says handoff. A cell reads
# "<rc>:<sorted REFUSED kinds>:<flags>", flags O = a `SMOKE OK` line, N = `SMOKE NO-SURFACE (declared none`,
# U = `SKIP SMOKE-SURFACE (undeclared`, E = `SKIP SMOKE-SURFACE (empty`, V = `UNEVALUABLE SMOKE-SURFACE (`,
# R = a `REFUSED smoke-surface-unevaluable` line saying git rejected a pathspec (the matches-nothing line
# does not carry it, so each of the two unevaluable guards has its own observable). The surface (docs/smoke-surface.txt)
# is `web/src/**` unless the cell says otherwise; "UI diff" is a change to web/src/app.js, "test diff" a change
# to the top-level web/src/a.test.js only (tracked in every world).
#   clean    UI diff; `- \`web/tests/a.spec.js\` (modified)`, changed in range          -> 0::O
#   m1       clean plus `web/tests/e2e/x.spec.js`, never tracked                       -> 1:smoke-listed-absent:O
#   rm       clean plus `web/tests/old.spec.js` removed (tracked at base, deleted)     -> 0::O
#   api      clean plus `/api/v1/x/report.json` (starts with /: not a path)            -> 0::O
#   kv       clean plus `BASE_URL=http://h/x/index.html` (= and ://: not a path)       -> 0::O
#            (both end in a dotted segment, so the extension rule cannot acquit them in place of the
#            rejection under test: each rejection has a subject no other guard reaches)
#   glob     clean plus `web/tests/*.spec.js` (*: not a path)                          -> 0::O
#   line     clean plus `web/tests/a.spec.js:352` (line suffix stripped, resolves)      -> 0::O
#   node     clean plus `tests/test_x.py::TestA::test_x` (node suffix stripped)         -> 0::O
#   dir      clean plus `web/tests` and `web/` (trees, no `.` in the last segment)      -> 0::O
#   trail    clean plus `test-results/` (absent, ends in /)                            -> 0::O
#   e2e      clean plus `tests/e2e` (absent, no extension)                             -> 0::O
#   dotdir   clean plus `web/tests/e2e.d` (a TREE whose last segment carries a `.`)    -> 0::O
#   s320     UI diff; the LITERAL s320 4.2 dispatched body; scripts/test-aws-smoke.sh
#            tracked at base and not in range                                          -> 1:smoke-not-updated:
#   nm       empty body; the diff touches server/x.py only (no surface path)           -> 0::O
#   absent   no surface file at base; UI diff; empty body                              -> 0::U  (and no SMOKE OK)
#   none     surface `# comment` + `none`; UI diff; empty body                         -> 0::N
#   cnone    surface `None` (capitalised); UI diff; empty body: none is case-folded     -> 0::N
#            (uncased, `None` is no lone none: it matches nothing at base or frozen and refuses
#            smoke-surface-unevaluable, which is the sm-none-case mutant's kill)
#   magic    surface `:(bogus)x` + `web/src/**`; UI diff; empty body: git exits 128 on the
#            surface pathspecs, which REFUSES (exit 1), never an empty "no change"     -> 1:smoke-surface-unevaluable:R
#   magicm1  the magic surface plus the m1 absent token: both refusals, exit 1        -> 1:smoke-listed-absent,smoke-surface-unevaluable:R
#   nonedot  surface `none.`; UI diff; empty body: not the none keyword, and as a
#            pathspec it matches nothing at base or frozen: refused                  -> 1:smoke-surface-unevaluable:
#   btnone   surface `` `none` `` (backticked); the same                               -> 1:smoke-surface-unevaluable:
#   typo     surface `web/scr/**` (matches nothing at base or frozen); the same      -> 1:smoke-surface-unevaluable:
#   nmglob   surface `web/src/*.js` (matches at base); server diff; empty body: the
#            near-miss, a matching surface the range does not touch                    -> 0::O
#   exclglob surface `web/src/**` + `:(exclude,glob)web/src/**/*.test.*`; test diff     -> 0::O
#   exclnog  the same with `:(exclude)web/src/**/*.test.*` (no glob magic: `**/` needs a
#            directory, so the top-level test stays on the surface)                    -> 1:smoke-not-updated:
#   broken   the m1 token; UI diff; the frozen web/src tree object deleted, so the range
#            diff fails AFTER m1 refused: the refusal outranks the exit 2               -> 1:smoke-listed-absent:V
#   brk0     the broken world with an empty body: nothing refused, so the failed range
#            diff exits 2 (`|| exit 2 # smoke mode` is this cell's alone)               -> 2::V
#   green    surface `web/app/**`, a directory absent at base that the story creates
#            (web/app/new.js) plus the clean listed test: the matches-nothing guard
#            lists <frozen> too, so a greenfield surface is not refused                 -> 0::O
#   corrupt  surface `web/src/**`; server diff; empty body; the BASE web/src tree object
#            deleted, so the range diff passes and the surface listing at base fails on
#            an object, not on a pathspec: UNEVALUABLE, never a rejected-pathspec refusal -> 2::V
#   empty    surface of comments and blanks only; UI diff; empty body                  -> 0::E
#   edited   surface `web/src/**` at base, `none` at frozen; UI diff; empty body       -> 1:smoke-not-updated,smoke-surface-edited:
#   sub      the edited world driven with `-C <world>/web` (a subdirectory): the smoke
#            diffs run from the top level, so the same two refusals                    -> 1:smoke-not-updated,smoke-surface-edited:
#   excl     surface `web/src/**` + `:(exclude)web/src/utils/configSchema.js`; the diff
#            touches only that generated file; empty body                              -> 0::O
#   exclbang the same with the short `:!web/src/utils/configSchema.js`                  -> 0::O
#   exclctl  the same diff and body, surface `web/src/**` alone (the near-miss)         -> 1:smoke-not-updated:
#   grammar  `## Smoke Test Updates (dev)` with CRLF line ends, an absent token inside a
#            fence and another under the next `## ` heading (neither read)             -> 0::O
#   hand     handoff mode on the s320 world: the same smoke-not-updated line          -> smoke-not-updated present
#   handmag  handoff mode on the magic world: exit 1 with smoke-surface-unevaluable (never the exit 2 a
#            caller reads as "nothing checked")
#   handbrk  handoff mode on the broken world: exit 1 with smoke-listed-absent, never 2
# 0 = every cell answered as above. 1 = a cell did not (one `FAIL <cell>` line each). 9 = the receipt could not run.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
[ "$#" -ge 1 ] && [ "$#" -le 3 ] && [ -f "$1" ] \
  || { echo "REFUSED: usage: bash receipt-bl845.sh <path to validate-handoff-evidence.sh> [<worlds dir> [<cells>]]" >&2; exit 9; }
HE="$1"; CELLS="${3:-}"
want() { [ -z "$CELLS" ] || case " clean $CELLS " in *" $1 "*) return 0 ;; esac; return 1; }
[ -f "$(dirname "$HE")/record-only-diff.sh" ] || { echo "REFUSED: no record-only-diff.sh beside $HE" >&2; exit 9; }
if [ -n "${2:-}" ]; then
  R="$2"; mkdir -p "$R" || exit 9
else
  R="$(mktemp -d "${TMPDIR:-/tmp}/receipt-bl845.XXXXXX")" || exit 9
  trap 'rm -rf "$R"' EXIT
fi
W=""
g() { GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -C "$W" -c user.name=r -c user.email=r@example.invalid \
  -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@"; }
S320='None. `scripts/test-aws-smoke.sh` asserts no HODL surface (`grep -c -i '"'"'hodl'"'"' scripts/test-aws-smoke.sh` returns 0; the control `grep -c -i '"'"'rebalancer'"'"' scripts/test-aws-smoke.sh` returns 70).'
# seed <cell> <surface at base | -> <surface at frozen | => <ui|srv|gen> <section body>; the body's lines are
# written under `## Smoke Test Updates`, followed by a `## Rename Verification` section.
seed() {
  local c="$1" sb="$2" sf="$3" kind="$4" body="$5"
  W="$R/$c"; mkdir -p "$W/web/src/utils" "$W/web/tests/e2e.d" "$W/scripts" "$W/server" "$W/docs" "$W/stories" "$W/tests" || return 1
  g init -q || return 1
  printf 'a\n' > "$W/web/src/app.js"; printf 'x\n' > "$W/server/x.py"; printf 's1\n' > "$W/web/src/utils/configSchema.js"
  printf 'smoke\n' > "$W/scripts/test-aws-smoke.sh"; printf 'a1\n' > "$W/web/tests/a.spec.js"
  printf 'old\n' > "$W/web/tests/old.spec.js"; printf 'h\n' > "$W/web/tests/e2e.d/helper.js"
  printf 'class TestA:\n    def test_x(self):\n        pass\n' > "$W/tests/test_x.py"; printf 't1\n' > "$W/web/src/a.test.js"
  [ "$sb" = - ] || printf '%s\n' "$sb" > "$W/docs/smoke-surface.txt"
  printf '# Story\n\n## Smoke Test Updates\n\n## Rename Verification\n\nnot a rename\n' > "$W/stories/s.md"
  g add -A && g commit -qm base || return 1
  g rev-parse HEAD > "$W/.B"
  case "$kind" in
    ui) printf 'b\n' > "$W/web/src/app.js" ;;
    gen) printf 's2\n' > "$W/web/src/utils/configSchema.js" ;;
    tst) printf 't2\n' > "$W/web/src/a.test.js" ;;
    newdir) mkdir -p "$W/web/app" && printf 'n\n' > "$W/web/app/new.js" ;;
    *) printf 'y\n' > "$W/server/x.py" ;;
  esac
  [ "$sf" = = ] || printf '%s\n' "$sf" > "$W/docs/smoke-surface.txt"
  printf '# Story\n\n## Smoke Test Updates\n\n%s\n\n## Rename Verification\n\nnot a rename\n' "$body" > "$W/stories/s.md"
}
fin() { g add -A && g commit -qm frozen && g rev-parse HEAD > "$W/.T"; }
SURF='# graph UI tree
web/src/**'
CLEAN='- `web/tests/a.spec.js` (modified)'
spec() { printf 'a2\n' > "$W/web/tests/a.spec.js"; }
if [ ! -f "$R/.seeded" ]; then
  ok=1
  for c in clean m1 api kv glob line node dir trail e2e dotdir; do
    case "$c" in
      clean) x='' ;; m1) x='- `web/tests/e2e/x.spec.js` (added)' ;; api) x='- `/api/v1/x/report.json` returns the new field' ;;
      kv) x='- run with `BASE_URL=http://h/x/index.html`' ;; glob) x='- `web/tests/*.spec.js`' ;; line) x='- `web/tests/a.spec.js:352`' ;;
      node) x='- `tests/test_x.py::TestA::test_x`' ;; dir) x='- everything under `web/tests` and `web/`' ;;
      trail) x='- captures in `test-results/`' ;; e2e) x='- the suite in `tests/e2e`' ;; dotdir) x='- helpers in `web/tests/e2e.d`' ;;
    esac
    seed "$c" "$SURF" = ui "$CLEAN${x:+
$x}" && spec && fin || ok=0
  done
  seed rm "$SURF" = ui "$CLEAN
- \`web/tests/old.spec.js\` removed (superseded)" && spec && g rm -q web/tests/old.spec.js && fin || ok=0
  seed s320 "$SURF" = ui "$S320" && fin || ok=0
  seed nm "$SURF" = srv '' && fin || ok=0
  seed absent - = ui '' && fin || ok=0
  seed none '# no UI here
none' = ui '' && fin || ok=0
  seed empty '# write globs here

# nothing yet' = ui '' && fin || ok=0
  seed edited "$SURF" none ui '' && fin || ok=0
  seed cnone 'None' = ui '' && fin || ok=0
  seed magic ':(bogus)x
web/src/**' = ui '' && fin || ok=0
  seed magicm1 ':(bogus)x
web/src/**' = ui '- `web/tests/e2e/x.spec.js` (added)' && fin || ok=0
  seed nonedot 'none.' = ui '' && fin || ok=0
  seed btnone '`none`' = ui '' && fin || ok=0
  seed typo 'web/scr/**' = ui '' && fin || ok=0
  seed nmglob 'web/src/*.js' = srv '' && fin || ok=0
  seed exclglob "$SURF
:(exclude,glob)web/src/**/*.test.*" = tst '' && fin || ok=0
  seed exclnog "$SURF
:(exclude)web/src/**/*.test.*" = tst '' && fin || ok=0
  # broken: m1 refuses first, then the range diff fails on the resolved refs (a deleted loose tree object).
  seed broken "$SURF" = ui '- `web/tests/e2e/x.spec.js` (added)' && fin \
    && o="$(g rev-parse "$(cat "$W/.T"):web/src")" && rm -f "$W/.git/objects/${o:0:2}/${o:2}" || ok=0
  # brk0: the broken world with nothing refused; corrupt: an unchanged BASE tree deleted, so only the listing fails.
  seed brk0 "$SURF" = ui '' && fin \
    && o="$(g rev-parse "$(cat "$W/.T"):web/src")" && rm -f "$W/.git/objects/${o:0:2}/${o:2}" || ok=0
  seed green 'web/app/**' = newdir "$CLEAN" && spec && fin || ok=0
  seed corrupt "$SURF" = srv '' && fin \
    && o="$(g rev-parse "$(cat "$W/.B"):web/src")" && rm -f "$W/.git/objects/${o:0:2}/${o:2}" || ok=0
  seed excl "$SURF
:(exclude)web/src/utils/configSchema.js" = gen '' && fin || ok=0
  seed exclbang "$SURF
:!web/src/utils/configSchema.js" = gen '' && fin || ok=0
  seed exclctl "$SURF" = gen '' && fin || ok=0
  seed grammar "$SURF" = ui '' && spec || ok=0
  [ "$ok" -eq 1 ] && printf '# Story\r\n\r\n## Smoke Test Updates (dev)\r\n\r\n- `web/tests/a.spec.js` (modified)\r\n```\r\n`web/tests/infence.spec.js`\r\n```\r\n\r\n## Rename Verification\r\n\r\n`web/tests/notread.spec.js`\r\n' > "$W/stories/s.md" && fin || ok=0
  [ "$ok" -eq 1 ] || { echo "REFUSED: a cell world could not be seeded" >&2; exit 9; }
  : > "$R/.seeded"
fi
# Seed controls, read on every call: the s320 world carries the literal body, its script is tracked and out
# of range; the trees the dir/dotdir cells name are trees at frozen and the trail/e2e/m1 paths are absent.
W="$R/s320"
grep -qF "$S320" "$W/stories/s.md" && g cat-file -e "$(cat "$W/.T"):scripts/test-aws-smoke.sh" \
  && [ -z "$(g diff --name-only "$(cat "$W/.B")" "$(cat "$W/.T")" -- scripts/test-aws-smoke.sh)" ] \
  || { echo "REFUSED: the s320 world does not carry its literal body or its script is in range" >&2; exit 9; }
W="$R/dotdir"; T="$(cat "$W/.T")"
{ [ "$(g cat-file -t "$T:web/tests/e2e.d")" = tree ] && [ "$(g cat-file -t "$T:web/tests")" = tree ] \
  && ! g cat-file -e "$T:test-results" 2>/dev/null && ! g cat-file -e "$T:tests/e2e" 2>/dev/null \
  && ! g cat-file -e "$T:web/tests/e2e/x.spec.js" 2>/dev/null; } \
  || { echo "REFUSED: the token worlds cannot express their cases (tree or absence wrong)" >&2; exit 9; }
# The cnone, magic and sub cells carry the property they test: the surface is exactly `None`, the magic
# surface carries a line git rejects, and the edited world has a tracked subdirectory to be driven from.
W="$R/cnone"; [ "$(g show "$(cat "$W/.B"):docs/smoke-surface.txt")" = None ] \
  || { echo "REFUSED: the cnone world's surface is not exactly None" >&2; exit 9; }
W="$R/magic"; grep -qxF ':(bogus)x' <<<"$(g show "$(cat "$W/.B"):docs/smoke-surface.txt")" \
  && ! g diff --name-only "$(cat "$W/.B")" "$(cat "$W/.T")" -- ':(bogus)x' >/dev/null 2>&1 \
  || { echo "REFUSED: the magic world's surface carries no line git rejects" >&2; exit 9; }
W="$R/broken"; ! g diff --name-only "$(cat "$W/.B")" "$(cat "$W/.T")" >/dev/null 2>&1 \
  && g cat-file -e "$(cat "$W/.T"):stories/s.md" \
  || { echo "REFUSED: the broken world's range diff does not fail, or its story is unreadable" >&2; exit 9; }
W="$R/brk0"; ! g diff --name-only "$(cat "$W/.B")" "$(cat "$W/.T")" >/dev/null 2>&1 \
  && ! grep -q '`' <<<"$(g show "$(cat "$W/.T"):stories/s.md")" \
  || { echo "REFUSED: the brk0 world's range diff does not fail, or its story carries a token" >&2; exit 9; }
W="$R/green"; [ -z "$(g ls-tree -r --name-only "$(cat "$W/.B")" -- web/app)" ] \
  && [ -n "$(g ls-tree -r --name-only "$(cat "$W/.T")" -- web/app)" ] \
  || { echo "REFUSED: the green world's surface matches at base, or matches nothing at frozen" >&2; exit 9; }
W="$R/corrupt"; ET="$(g hash-object -t tree /dev/null)"
g diff --name-only "$(cat "$W/.B")" "$(cat "$W/.T")" >/dev/null 2>&1 \
  && ! g diff --name-only "$ET" "$(cat "$W/.B")" -- 'web/src/**' >/dev/null 2>&1 \
  && g diff --name-only "$ET" "$ET" -- 'web/src/**' >/dev/null 2>&1 \
  || { echo "REFUSED: the corrupt world's range diff fails, or its base listing does not fail on an object" >&2; exit 9; }
W="$R/nmglob"; [ -n "$(g ls-files --with-tree="$(cat "$W/.B")" -- 'web/src/*.js')" ] \
  || { echo "REFUSED: the nmglob near-miss surface matches nothing at base" >&2; exit 9; }
W="$R/edited"; [ "$(g cat-file -t "$(cat "$W/.T"):web")" = tree ] && [ -d "$W/web" ] \
  || { echo "REFUSED: the edited world has no web/ subdirectory for the sub cell" >&2; exit 9; }
run() { # <cell> [<subdirectory of the world to pass as -C>] -> "<rc>:<kinds>:<flags>"
  local w="$R/$1" o rc f=""
  o="$(bash "$HE" -C "$w${2:+/$2}" --smoke stories/s.md "$(cat "$w/.B")" "$(cat "$w/.T")" 2>/dev/null)"; rc=$?
  grep -q '^SMOKE OK ' <<<"$o" && f="${f}O"
  grep -q '^SMOKE NO-SURFACE (declared none' <<<"$o" && f="${f}N"
  grep -q '^SKIP SMOKE-SURFACE (undeclared' <<<"$o" && f="${f}U"
  grep -q '^SKIP SMOKE-SURFACE (empty' <<<"$o" && f="${f}E"
  grep -q '^UNEVALUABLE SMOKE-SURFACE (' <<<"$o" && f="${f}V"
  grep -q '^REFUSED smoke-surface-unevaluable .*: git rejected a pathspec' <<<"$o" && f="${f}R"
  printf '%s:%s:%s' "$rc" "$(awk '/^REFUSED /{print $2}' <<<"$o" | sort | tr '\n' ',' | sed 's/,$//')" "$f"
}
fails=0
cell() { # <cell> <want> [<world> <subdirectory>]
  local got; want "$1" || return 0
  if [ -n "${3:-}" ]; then got="$(run "$3" "$4")"; else got="$(run "$1")"; fi
  [ "$got" = "$2" ] || { echo "FAIL $1: want [$2] got [$got]"; fails=$((fails + 1)); }
}
cell clean    0::O
cell m1       1:smoke-listed-absent:O
cell rm       0::O
cell api      0::O
cell kv       0::O
cell glob     0::O
cell line     0::O
cell node     0::O
cell dir      0::O
cell trail    0::O
cell e2e      0::O
cell dotdir   0::O
cell s320     1:smoke-not-updated:
cell nm       0::O
cell absent   0::U
cell none     0::N
cell empty    0::E
cell edited   1:smoke-not-updated,smoke-surface-edited:
cell sub      1:smoke-not-updated,smoke-surface-edited: edited web
cell cnone    0::N
cell magic    1:smoke-surface-unevaluable:R
cell magicm1  1:smoke-listed-absent,smoke-surface-unevaluable:R
cell nonedot  1:smoke-surface-unevaluable:
cell btnone   1:smoke-surface-unevaluable:
cell typo     1:smoke-surface-unevaluable:
cell nmglob   0::O
cell exclglob 0::O
cell exclnog  1:smoke-not-updated:
cell broken   1:smoke-listed-absent:V
cell brk0     2::V
cell green    0::O
cell corrupt  2::V
cell excl     0::O
cell exclbang 0::O
cell exclctl  1:smoke-not-updated:
cell grammar  0::O
W="$R/s320"
if want hand; then
o="$(bash "$HE" -C "$W" stories/s.md "$(cat "$W/.B")" "$(cat "$W/.T")" 2>/dev/null)"
grep -q '^REFUSED smoke-not-updated stories/s.md: ' <<<"$o" \
  || { echo "FAIL hand: handoff mode did not print the smoke-not-updated refusal"; fails=$((fails + 1)); }
fi
hand_rc() { # <cell> <world> <REFUSED kind that must print> -> FAIL unless handoff mode exits 1 with it
  local w="$R/$2" o rc
  want "$1" || return 0
  o="$(bash "$HE" -C "$w" stories/s.md "$(cat "$w/.B")" "$(cat "$w/.T")" 2>/dev/null)"; rc=$?
  { [ "$rc" -eq 1 ] && grep -q "^REFUSED $3 stories/s.md: " <<<"$o"; } \
    || { echo "FAIL $1: handoff mode on the $2 world exited $rc, want 1 with REFUSED $3"; fails=$((fails + 1)); }
}
hand_rc handmag magic smoke-surface-unevaluable
hand_rc handbrk broken smoke-listed-absent
[ "$fails" -eq 0 ] || exit 1
exit 0
