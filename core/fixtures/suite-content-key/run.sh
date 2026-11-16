#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
# suite-content-key — the fixture-suite skip is a check that did not run, and this
# is what stops it reading like one that passed.
#
# `.githooks/pre-push` skips all 84 fixtures when `scripts/suite-content-key.sh`
# reports the same key as the last fully green run. That is only sound while the
# key MOVES for every change the suite could see. This fixture asserts the moving,
# in both directions, against a throwaway copy of the distribution tree:
#
#   it MUST move on   a file's contents, a NEW EMPTY DIRECTORY, an exec-bit flip,
#                     a symlink's target, a new tracked path under an EXCLUDED
#                     tree, and a change to the fixture set
#   it MUST NOT move  on the contents of an excluded path, or across two runs
#                     over an untouched tree
#
# The empty-directory case is the one worth naming: several invariants fire on a
# directory that has no rows in it at all, so a contents hash alone cannot see the
# input that would make them speak.
#
# DIST-ONLY. Both subjects -- the key script and the distribution's own pre-push
# hook -- are dev-repo files that install.sh never ships, so there is nothing for a
# consumer tree to run this against.
#
# EVERY MUTATION IS GUARDED BY `cmp -s` OR A DIRECTORY DIFF, and every assertion
# states a POSITIVE outcome. A key script that crashed would print nothing and
# compare empty-to-empty, so the first assertion is a sanity arm that must produce
# a well-formed key before any comparison below is believed.
#
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
DIST="$(cd "$HERE/../../.." && pwd)"

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }
. "$HERE/../lib/mutant.sh" || { echo "FIXTURE BROKEN: cannot source lib/mutant.sh" >&2; exit 2; }
broken() { printf '  FAIL  %s\n' "$1" >&2; echo "suite-content-key: FIXTURE BROKEN" >&2; exit 2; }

echo "suite-content-key:"

[ -f "$DIST/scripts/suite-content-key.sh" ] || broken "no scripts/suite-content-key.sh at $DIST"
echo "HERMETIC-CONSUMED scripts/suite-content-key.sh"

# A real git repository, because the key reads `git ls-files` and `git check-ignore`
# and would degrade to a different -- still stable -- value without one. A fixture
# that keyed a non-repository would be testing a code path no push ever takes.
WORK="$(mktemp -d "${TMPDIR:-/tmp}/suite-content-key.XXXXXX")" || broken "mktemp failed"
trap 'rm -rf "$WORK"' EXIT
T="$WORK/tree"
mkdir -p "$T"
cp -R "$DIST/scripts"   "$T/scripts"
cp -R "$DIST/.githooks" "$T/.githooks"
cp -R "$DIST/templates" "$T/templates"
mkdir -p "$T/core/fixtures/alpha" "$T/core/fixtures/beta" "$T/core/fixtures/gamma" "$T/docs/plans"
printf 'body\n' > "$T/core/fixtures/alpha/run.sh"
printf 'body\n' > "$T/core/fixtures/beta/run.sh"
printf 'a doc\n'  > "$T/docs/note.md"
# gamma opts ONE excluded file into the keys with `+` (arms 10-14); docs/plans/p.md is its near-miss.
printf 'body\n' > "$T/core/fixtures/gamma/run.sh"
printf '!scripts/suite-content-key.sh\n+docs/backlog.md\n' > "$T/core/fixtures/gamma/inputs.decl"
printf '## BL-001\n' > "$T/docs/backlog.md"
printf '# a plan\n'  > "$T/docs/plans/p.md"
printf '0.0.1\n'  > "$T/VERSION"
printf '# log\n'  > "$T/CHANGELOG.md"
printf '.DS_Store\nnode_modules/\n' > "$T/.gitignore"

git -C "$T" init -q                       || broken "git init failed"
git -C "$T" config user.email f@x
git -C "$T" config user.name  f
git -C "$T" add -A                        || broken "git add failed"
git -C "$T" commit -q -m base             || broken "git commit failed"

# IN PROCESS (BL-878). The copy's key script is SOURCED once (its guard returns after defining sck_main; its root is the
# copy, from its own BASH_SOURCE) and every key is one sck_main call in a `( )` subshell, so the subject's `exit`, `cd`
# and `set` stay there. Mode and content edits of the copy are read from disk at each call, never from the sourced text.
# Each sck_main call is one fx_inproc pass (the inproc: row). The only separate-program starts of the subject are the four cli
# cells of cells.decl, each compared byte for byte with the in-process call (cli_eqv below).
KEY="$T/scripts/suite-content-key.sh"
. "$KEY" || broken "sourcing the copy's key script failed"
declare -F sck_main > /dev/null || broken "sourcing the copy's key script defined no sck_main"
key() { ( fx_inproc "$KEY"; sck_main 2>/dev/null ); }

# --- 0. SANITY: a well-formed key at all --------------------------------------
K0="$(key)"
case "$K0" in
  ????????????????????????????????????????????????????????????????)
    ok "the seeded tree yields a well-formed sha256 key (every comparison below means something)" ;;
  *)
    broken "the key script produced '$K0' on a pristine seed; every 'the key moved' assertion below would be a false pass" ;;
esac

# --- 1. DETERMINISM: an untouched tree keys the same twice ---------------------
# Without this the skip never fires and the whole change is 0.3s of dead weight.
if [ "$(key)" = "$K0" ]; then
  ok "two runs over an untouched tree agree (a key that drifted from itself could never authorise a skip)"
else
  bad "the key is not deterministic over an unchanged tree — every push would miss and the suite would always run"
fi

# --- CLI CELLS: one separate-program start per distinct outcome, equal to the in-process answer ----------------
# cli_eqv <id> <expected rc> <args...>: one `FXCELL=<id> bash "$KEY"` start and one sck_main call over the same untouched
# tree must agree on stdout, stderr and exit status byte for byte, and the exit status must be the one stated.
EQ="$WORK/eq"; mkdir -p "$EQ"
cli_eqv() {
  local id="$1" want="$2"; shift 2
  ( fx_inproc "$KEY"; sck_main "$@" ) > "$EQ/$id.ip.out" 2> "$EQ/$id.ip.err"; echo "$?" > "$EQ/$id.ip.rc"
  FXCELL="$id" bash "$KEY" "$@" > "$EQ/$id.cl.out" 2> "$EQ/$id.cl.err"; echo "$?" > "$EQ/$id.cl.rc"
  if [ "$(cat "$EQ/$id.cl.rc")" = "$want" ] && cmp -s "$EQ/$id.ip.out" "$EQ/$id.cl.out" && cmp -s "$EQ/$id.ip.err" "$EQ/$id.cl.err" \
     && cmp -s "$EQ/$id.ip.rc" "$EQ/$id.cl.rc"; then ok "EQUIV $id: the in-process call and the program agree on stdout, stderr and exit $want"
  else bad "EQUIV $id: in-process rc $(cat "$EQ/$id.ip.rc") vs program rc $(cat "$EQ/$id.cl.rc") (want $want), or their output differs"; fi
}
cli_eqv cli-key 0
case "$(cat "$EQ/cli-key.cl.out")" in
  ????????????????????????????????????????????????????????????????) ok "cli-key prints one well-formed sha256 key" ;;
  *) bad "cli-key printed '$(cat "$EQ/cli-key.cl.out")', not one sha256 key" ;;
esac
[ ! -s "$EQ/cli-key.cl.err" ] && ok "cli-key writes nothing to stderr" || bad "cli-key wrote to stderr"
cli_eqv cli-summary 0 --summary
grep -q '^included tops: ' "$EQ/cli-summary.cl.out" && grep -q '^paths hashed:  [1-9]' "$EQ/cli-summary.cl.out" \
  && ok "cli-summary prints the included tops and a non-zero hashed count" || bad "cli-summary printed no included-tops line or a zero hashed count"
cli_eqv cli-explain 0 --explain
grep -qx '### tools' "$EQ/cli-explain.cl.out" && grep -qx '### contents' "$EQ/cli-explain.cl.out" \
  && ok "cli-explain prints the contents and tools components" || bad "cli-explain printed no contents or tools component"
cli_eqv cli-usage 1 --no-such-option
grep -q '^suite-content-key: usage: ' "$EQ/cli-usage.cl.err" && [ ! -s "$EQ/cli-usage.cl.out" ] \
  && ok "cli-usage refuses an unknown option with the usage line on stderr and nothing on stdout" || bad "cli-usage did not print the usage line on stderr only"

# --- helper: mutate, key, restore, report -------------------------------------
# Asserts the POSITIVE outcome in each direction and requires the mutation to have
# landed, so a sed or a touch that matched nothing cannot pass as a change.
moved() { # $1 = label
  local k; k="$(key)"
  if [ "$k" != "$K0" ]; then ok "$1"; else bad "the key did NOT move: $1"; fi
}
unmoved() { # $1 = label
  local k; k="$(key)"
  if [ "$k" = "$K0" ]; then ok "$1"; else bad "the key moved when it should not have: $1"; fi
}

# --- 2. CONTENTS of an included file ------------------------------------------
cp "$T/core/fixtures/alpha/run.sh" "$WORK/alpha.orig"
printf 'one more line\n' >> "$T/core/fixtures/alpha/run.sh"
cmp -s "$WORK/alpha.orig" "$T/core/fixtures/alpha/run.sh" && broken "the contents mutation changed no bytes"
moved "an edit inside core/fixtures/ moves the key"
cp "$WORK/alpha.orig" "$T/core/fixtures/alpha/run.sh"

# --- 3. A NEW EMPTY DIRECTORY -------------------------------------------------
# DELIBERATELY NOT UNDER core/fixtures/. The key names the fixture directory set as
# its own component, so an empty directory there would be caught twice and this
# assertion could not attribute the catch to the listing. Under scripts/ the
# listing is the ONLY component that can see it: git cannot track an empty
# directory and a contents hash has nothing to hash.
mkdir "$T/scripts/probe-empty" || broken "could not create the empty-directory probe"
[ -d "$T/scripts/probe-empty" ] || broken "the empty-directory probe was not created"
moved "a NEW EMPTY DIRECTORY outside core/fixtures/ moves the key (only the listing component can see one)"
rmdir "$T/scripts/probe-empty"

# --- 4. THE EXECUTABLE BIT, with no content change ----------------------------
# v0.70.1 shipped a guard installed inert because a copy carried the bytes and not
# the mode. A mode-only change is a behavioural change.
chmod 644 "$T/scripts/suite-content-key.sh"
chmod 755 "$T/core/fixtures/alpha/run.sh"
moved "an exec-bit flip with identical bytes moves the key"
chmod 755 "$T/scripts/suite-content-key.sh"
chmod 644 "$T/core/fixtures/alpha/run.sh"

# --- 5. A SYMLINK'S TARGET, with the listing unchanged ------------------------
ln -s alpha/run.sh "$T/core/fixtures/link" || broken "could not create the symlink probe"
K_LINK="$(key)"
[ "$K_LINK" != "$K0" ] || broken "creating the symlink probe did not move the key, so the retarget below proves nothing"
rm -f "$T/core/fixtures/link"
ln -s beta/run.sh "$T/core/fixtures/link" || broken "could not retarget the symlink probe"
if [ "$(key)" != "$K_LINK" ]; then
  ok "RETARGETING a symlink moves the key with the listing byte-identical (only the target changed)"
else
  bad "a symlink was pointed at a different file and the key did not notice — the listing alone cannot see this"
fi
rm -f "$T/core/fixtures/link"

# --- 6. THE FIXTURE SET -------------------------------------------------------
mkdir -p "$T/core/fixtures/delta"
printf 'body\n' > "$T/core/fixtures/delta/run.sh"
moved "adding a fixture directory moves the key (the row's stated condition: a hit is refused when the fixture SET changed)"
rm -rf "$T/core/fixtures/delta"

# --- 7. THE EXCLUDED SET: contents do NOT move it ------------------------------
# This is the entire point of the exclusion set and the reason the skip ever fires.
for f in CHANGELOG.md VERSION docs/note.md; do
  cp "$T/$f" "$WORK/ex.orig"
  printf 'edited\n' >> "$T/$f"
  cmp -s "$WORK/ex.orig" "$T/$f" && broken "the excluded-path mutation on $f changed no bytes"
  unmoved "editing $f does not move the key (this is what makes a release push skip the suite)"
  cp "$WORK/ex.orig" "$T/$f"
done

# --- 8. ...but the excluded set's LISTING does ---------------------------------
# A docs/ file being ADDED or REMOVED changes what `ledger-status-vocabulary`
# copies out of `git ls-files`, so it is an input even though its contents are not.
printf 'new doc\n' > "$T/docs/second.md"
git -C "$T" add docs/second.md >/dev/null 2>&1 || broken "could not stage the new excluded-tree file"
moved "ADDING a tracked file under an excluded tree moves the key (its contents are excluded; its existence is not)"
git -C "$T" rm -q --cached docs/second.md >/dev/null 2>&1
rm -f "$T/docs/second.md"

# --- 9. Back to the start -----------------------------------------------------
# The restores above are load-bearing: if any of them missed, the assertions after
# it were comparing against a tree that had already drifted.
if [ "$(key)" = "$K0" ]; then
  ok "the tree is byte-identical to where it started (every restore above landed)"
else
  bad "the tree did not return to its initial key — one of the restores above missed, and the assertions after it compared against a drifted tree"
fi

# --- 10-14. THE `+` OPT-IN: a declared file under an excluded top, keyed at BOTH layers ----
# docs/ is excluded, so a push changing only docs/backlog.md used to match the outer key and run no
# fixture, and the hook's per-fixture key had no row for it either. A leading `+` on an inputs.decl
# line keys that one file in both. Every arm below drives the SHIPPED code: the outer key is this
# copy's suite-content-key.sh, the inner one is the READSET_KEYROWS span cut out of this copy's
# .githooks/pre-push and sourced, the way hermetic-run.sh sources it.
#   k1  `+docs/backlog.md` yields a docs/backlog.md key row carrying the file's sha256
#   k2  the same line with no `+` yields none -- the behaviour before the opt-in, and the control
#   k3  the outer key moves on an EDIT of docs/backlog.md and NOT on an EDIT of docs/plans/p.md
#       (an edit, never an add: adding a file moves the key through its listing component)
#   k4  a `+` naming a file that is not there refuses the outer key (fails closed, never skips)
#   k5  `+` on a directory is refused by the parse
#   k6  `+` and `!` on one line is refused, by the parse and by the outer key
#   k7  no inputs.decl at all: the unmatched glob still yields a well-formed key
span() { # span <hook> <out> -- the READSET_KEYROWS span, or broken
  sed -n '/^# READSET_KEYROWS_BEGIN$/,/^# READSET_KEYROWS_END$/p' "$1" > "$2"
  grep -q '^readset_decl_parse() ' "$2" || broken "no READSET_KEYROWS span with readset_decl_parse in $1"
}
krows() { # krows <span file> <decl body> -> the composed key rows of a fixture declaring <decl body>, run from $T
  local s="$1" fd="$WORK/kfx/kx"
  rm -rf "$WORK/kfx"; mkdir -p "$fd"; printf '%s\n' "$2" > "$fd/inputs.decl"
  ( cd "$T" && . "$s" && : > "$WORK/k.now" && : > "$WORK/k.ls" && : > "$WORK/k.th" \
      && readset_decl_parse kx "$fd" dist "" "/usr/bin:/bin" "$WORK/k.w" > "$WORK/k.parse" \
      && readset_decl_keys "$WORK/k.now" "$WORK/k.ls" "$WORK/k.parse" "$WORK/k.th" "$WORK/kfx/" )
}
span "$T/.githooks/pre-push" "$WORK/span.sh"
BSHA="$(shasum -a 256 "$T/docs/backlog.md" | cut -d' ' -f1)"
[ "${#BSHA}" -eq 64 ] || broken "could not hash the seeded docs/backlog.md"

k1="$(krows "$WORK/span.sh" '+docs/backlog.md' | awk -F'\t' '$2 == "docs/backlog.md" { print $3 }')"
if [ "$k1" = "$BSHA" ]; then ok "k1 a +docs/backlog.md declaration yields a docs/backlog.md key row carrying its sha256"
else bad "k1 a +docs/backlog.md declaration yielded the row value '$k1', want '$BSHA' -- the file under an excluded top is still unkeyed"; fi

k2="$(krows "$WORK/span.sh" 'docs/backlog.md' | awk -F'\t' '$2 == "docs/backlog.md"' | grep -c .)" || k2=0
if [ "$k2" -eq 0 ]; then ok "k2 the same line WITHOUT + yields no docs/backlog.md row (an excluded top stays unkeyed unless opted in)"
else bad "k2 a plain docs/backlog.md declaration yielded $k2 row(s) -- the opt-in is not an opt-in"; fi

krows "$WORK/span.sh" '+docs/' > /dev/null
k5="$(awk -F'\t' '$2 == "X" && $3 == "plusdir"' "$WORK/k.parse" | grep -c .)" || k5=0
if [ "${k5:-0}" -eq 1 ]; then ok "k5 + on a directory is refused (plusdir), never keyed as a second manifest"
else bad "k5 + on a directory was not refused (plusdir rows: ${k5:-0})"; fi

KP="$(key)"
case "$KP" in ????????????????????????????????????????????????????????????????) : ;; *) broken "no key for the + arms' baseline" ;; esac
edit_key() { # edit_key <file> -> the key after appending one line, then the file restored
  cp "$T/$1" "$WORK/e.orig"; printf 'edited\n' >> "$T/$1"
  cmp -s "$WORK/e.orig" "$T/$1" && broken "the edit of $1 changed no bytes"
  key; cp "$WORK/e.orig" "$T/$1"
}
k3b="$(edit_key docs/backlog.md)"; k3p="$(edit_key docs/plans/p.md)"
if [ -n "$k3b" ] && [ "$k3b" != "$KP" ]; then ok "k3 an EDIT of the +declared docs/backlog.md moves the outer key"
else bad "k3 an edit of the +declared docs/backlog.md did NOT move the outer key ('$k3b') -- a backlog-only push still skips the suite"; fi
if [ "$k3p" = "$KP" ]; then ok "k3 an EDIT of docs/plans/p.md does NOT move it (only the declared file is keyed, not its top)"
else bad "k3 an edit of docs/plans/p.md moved the outer key -- the + opt-in widened to the whole excluded top"; fi

printf '!scripts/suite-content-key.sh\n+docs/backlog.md\n+docs/absent.md\n' > "$T/core/fixtures/gamma/inputs.decl"
if ( fx_inproc "$KEY"; sck_main ) > /dev/null 2>&1; then bad "k4 a + naming an absent file still produced a key -- a skip would be authorised over a file nobody hashed"
else ok "k4 a + naming an absent file refuses the key (the caller runs the suite)"; fi
printf '!scripts/suite-content-key.sh\n+!docs/backlog.md\n' > "$T/core/fixtures/gamma/inputs.decl"
if ( fx_inproc "$KEY"; sck_main ) > /dev/null 2>&1; then bad "k6 a line carrying + and ! together still produced an outer key"
else ok "k6 a line carrying + and ! together refuses the outer key (one marker per line)"; fi
krows "$WORK/span.sh" '!+docs/backlog.md' > /dev/null
k6="$(awk -F'\t' '$2 == "X" && $3 == "plusbang"' "$WORK/k.parse" | grep -c .)" || k6=0
if [ "$k6" -eq 1 ]; then ok "k6 the hook's parse refuses + and ! on one line (plusbang)"
else bad "k6 the hook's parse did not refuse + and ! on one line (plusbang rows: $k6)"; fi
# k7 THE UNMATCHED GLOB: with no inputs.decl anywhere, `core/fixtures/*/inputs.decl` matches nothing,
# and the key must still be well-formed (an empty keyed section), not refused and not the literal glob.
mv "$T/core/fixtures/gamma/inputs.decl" "$WORK/gamma.decl"
k7="$(key)"
case "$k7" in
  ????????????????????????????????????????????????????????????????) ok "k7 with no inputs.decl at all the glob matches nothing and the key is still well-formed" ;;
  *) bad "k7 with no inputs.decl at all the key script produced '$k7' -- an unmatched glob refused or broke the key" ;;
esac
[ "$k7" != "$KP" ] || bad "k7 removing the only + declaration did not move the key -- the keyed component is not in it"
mv "$WORK/gamma.decl" "$T/core/fixtures/gamma/inputs.decl"
printf '!scripts/suite-content-key.sh\n+docs/backlog.md\n' > "$T/core/fixtures/gamma/inputs.decl"
[ "$(key)" = "$KP" ] || broken "the gamma declaration was not restored"

# --- BL-1071. ANOTHER FIXTURE'S DECLARATION IS KEYED ONLY BY A FIXTURE THAT NAMES IT -----------------------------
# The READSET_KEYROWS span, sourced, over a world of two other fixtures (alpha, beta), each with run.sh, inputs.decl
# and invocations.decl, every file a `.now` row. Run from the world with the fixture root core/fixtures/, as the hook
# passes it; the declaring fixture gx sits beside the other two.
#   k8  a fixture declaring core/fixtures/ is keyed on alpha's run.sh and on NEITHER of alpha's declarations
#   k9  the same plus `core/fixtures/*/inputs.decl` is keyed on alpha's and beta's inputs.decl at their manifest values,
#       still on neither invocations.decl, and the parse refuses nothing
G="$WORK/g"
for _f in alpha beta; do
  mkdir -p "$G/core/fixtures/$_f"
  printf 'body %s\n' "$_f" > "$G/core/fixtures/$_f/run.sh"
  printf 'core/scripts/x-%s.sh\n' "$_f" > "$G/core/fixtures/$_f/inputs.decl"
  printf '1 *\n' > "$G/core/fixtures/$_f/invocations.decl"
done
( cd "$G" && for _f in core/fixtures/*/*; do printf '%s\t%s\n' "$_f" "$(shasum -a 256 < "$_f" | cut -d' ' -f1)"; done ) > "$WORK/g.now"
[ "$(grep -c . "$WORK/g.now")" -eq 6 ] || broken "the BL-1071 world's manifest does not hold its six files"
grows() { # grows <decl body> -> the composed key rows, under the span copy GSPAN names, of a fixture declaring <decl body>, run from $G
  mkdir -p "$G/core/fixtures/gx"; printf '%s\n' "$1" > "$G/core/fixtures/gx/inputs.decl"
  ( cd "$G" && . "$GSPAN" && : > "$WORK/g.ls" && : > "$WORK/g.th" \
      && readset_decl_parse gx core/fixtures/gx dist "" "/usr/bin:/bin" "$WORK/g.w" > "$WORK/g.parse" \
      && readset_decl_keys "$WORK/g.now" "$WORK/g.ls" "$WORK/g.parse" "$WORK/g.th" core/fixtures/ )
}
gval() { awk -F'\t' -v p="$1" '$1 == p { print $2 }' "$WORK/g.now"; }
g_k8() { # under GSPAN: 0 when k8's predicate holds; G_K8 names what it saw
  local r; r="$(grows 'core/fixtures/')"
  G_K8="$(awk -F'\t' '$2 == "core/fixtures/alpha/run.sh" { r++ } $2 == "core/fixtures/alpha/inputs.decl" { i++ }
    $2 == "core/fixtures/alpha/invocations.decl" { v++ } END { print "run.sh:" r + 0 " inputs:" i + 0 " invocations:" v + 0 }' <<< "$r")"
  [ "$G_K8" = "run.sh:1 inputs:0 invocations:0" ]
}
g_k9() { # under GSPAN: 0 when k9's predicate holds; G_K9 names what it saw
  local r; r="$(grows 'core/fixtures/
core/fixtures/*/inputs.decl')"
  G_K9="$(GA="$(gval core/fixtures/alpha/inputs.decl)" GB="$(gval core/fixtures/beta/inputs.decl)" awk -F'\t' '
    $2 == "core/fixtures/alpha/inputs.decl" && $3 == ENVIRON["GA"] { a++ } $2 == "core/fixtures/beta/inputs.decl" && $3 == ENVIRON["GB"] { b++ }
    $2 ~ /\/invocations\.decl$/ { v++ } END { printf "alpha:%d beta:%d invocations:%d", a, b, v }' <<< "$r") refused:$(awk -F'\t' '$2 == "X" { n++ } END { print n + 0 }' "$WORK/g.parse")"
  [ "$G_K9" = "alpha:1 beta:1 invocations:0 refused:0" ]
}
GSPAN="$WORK/span.sh"
if g_k8; then ok "k8 a core/fixtures/ declarer is keyed on another fixture's run.sh and on neither of its declarations ($G_K8)"
else bad "k8 a core/fixtures/ declarer's rows for alpha read $G_K8, want run.sh:1 inputs:0 invocations:0"; fi
if g_k9; then ok "k9 a core/fixtures/*/inputs.decl declarer is keyed on every fixture's inputs.decl at its manifest value ($G_K9)"
else bad "k9 a core/fixtures/*/inputs.decl declarer read $G_K9, want alpha:1 beta:1 invocations:0 refused:0"; fi

# --- BL-954. THE FINAL BANNER NAMES THE ARM THAT DECIDED THE SKIP ---------------------------------
# Two arms skip the suite and each is its own decision with its own log line: the whole-suite content key
# (HIT) and the read-set skip inside run_fixtures (the key MISSED, then no fixture's inputs moved). The
# banner once said "unchanged content key" for both. Driven through the REAL code, never a retyped copy:
# the FIXTURE_POOL block is cut from the hook (run_fixtures and apply_readset_skip set READSET_NO_CHANGE
# themselves; nothing here sets it), then SUITE_STEP (fixture_suite_step and its cause assignments) and
# SUITE_BANNER (the final banner) are cut by the markers the hook carries, and all three are sourced in a
# world.
#   W1 the key MISSED (no record) and every read-set is unchanged  -> banner names the read-set arm, never
#      "unchanged content key", and the step and log say MISS / "content key changed"
#   W2 the key matches its record                                  -> banner names the content-key arm, log HIT
#   the two banners DIFFER, and each matches its own log line.
BW="$WORK/bl954"; mkdir -p "$BW/tpl/core/fixtures/alpha" "$BW/tpl/core/fixtures/beta" "$BW/tpl/src"
for _f in alpha beta; do printf 'exit 0\n' > "$BW/tpl/core/fixtures/$_f/run.sh"; done
printf 'alpha\tsrc/a.sh\nbeta\tsrc/b.sh\n' > "$BW/tpl/.ai-dlc-fixture-readsets.tsv"
printf 'v1\n' > "$BW/tpl/src/a.sh"; printf 'v1\n' > "$BW/tpl/src/b.sh"
cp -R "$DIST/scripts" "$BW/tpl/scripts"
( cd "$BW/tpl" && git init -q . && git add -A && git -c user.email=f@f -c user.name=f commit -qm seed ) >/dev/null 2>&1 \
  || broken "the BL-954 world seed failed"
# The driver: <hook> <w1|w2> <world dir> <template> -> the step's output, ---BANNER--- and the banner, ---LOG--- and the key log.
cat > "$BW/drv.sh" <<'DRV'
set -uo pipefail
# IN PROCESS (BL-878). The hook's step starts the world's key script as `bash scripts/suite-content-key.sh [args]`, and this
# driver does too; both go through this function, which answers that one command by sourcing the world's copy and calling
# sck_main in a subshell (one fx_inproc pass each; run.sh exports fx_inproc) and passes every other `bash` through.
bash() {
  case "${1:-}" in
    scripts/suite-content-key.sh) shift
      ( fx_inproc "$PWD/scripts/suite-content-key.sh"; . "$PWD/scripts/suite-content-key.sh" && sck_main "$@" ) ;;
    *) command bash "$@" ;;
  esac
}
hook="$1"; w="$2"; t="$3"
cp -Rp "$4" "$t" || exit 3
cd "$t" || exit 3
sp="$t.spans"; mkdir -p "$sp"
export AI_DLC_READSET_LIVE_TRACE=0 AI_DLC_VERDICT_STORE="$t.vs"
sed -n '/^# FIXTURE_POOL_BEGIN$/,/^# FIXTURE_POOL_END$/p' "$hook" > "$sp/pool"
sed -n '/^# SUITE_STEP_BEGIN$/,/^# SUITE_STEP_END$/p' "$hook" > "$sp/step"
sed -n '/^# SUITE_BANNER_BEGIN$/,/^# SUITE_BANNER_END$/p' "$hook" > "$sp/banner"
[ -s "$sp/pool" ] && [ -s "$sp/step" ] && [ -s "$sp/banner" ] || { echo "DRIVER: a span is empty"; exit 3; }
fail=0; PENDING_N=0; SUITE_SKIPPED=0; SUITE_SKIP_CAUSE=""; pending_note=""
. "$sp/pool" 2>/dev/null
. "$sp/step"
if [ "$w" = w1 ] || [ "$w" = w1p ]; then
  # no key record; the verified record is the tree's own manifest, so every read-set is unchanged
  mkdir -p "$sp/m"; for d in core/fixtures/*/; do printf '%s\n' "$d"; done > "$sp/m/list"
  readset_manifest "$sp/m"
  mkdir -p "${VERIFIED_RECORD%/*}" "${KEYS_DIR%/*}" && cp "$sp/m/.now" "$VERIFIED_RECORD" && printf 'v2\n' > "$VERIFIED_FORMAT" || exit 3
  if [ "$w" = w1p ]; then
    # BL-998: the per-fixture records W1's seed published ($W1P_KEYS), each given line 4 `#pending <n>` where the
    # producer writes it -- alpha 3, beta 0 -- so the green write's snapshot has a count to name and one to omit
    cp -Rp "$W1P_KEYS" "$KEYS_DIR" || exit 3
    for kp in alpha=3 beta=0; do
      awk -v n="${kp#*=}" '{ print } FNR == 3 { print "#pending " n }' "$W1P_KEYS/${kp%=*}.key" > "$KEYS_DIR/${kp%=*}.key" || exit 3
    done
  fi
elif [ "$w" = w2p ]; then
  # BL-998: the record's line 2 snapshots alpha=3 (beta absent) while the key records say alpha 0 and beta 5
  mkdir -p "${KEY_RECORD%/*}" || exit 3
  printf '%s %s %s\n#pending alpha=3\n' "$(bash scripts/suite-content-key.sh)" 2 2026-01-01T00:00:00Z > "$KEY_RECORD"
  mkdir -p "$KEYS_DIR"
  printf '#format k1\n#state ok\n#tools canonical\n#pending 0\n' > "$KEYS_DIR/alpha.key"
  printf '#format k1\n#state ok\n#tools canonical\n#pending 5\n' > "$KEYS_DIR/beta.key"
else
  mkdir -p "${KEY_RECORD%/*}" || exit 3
  printf '%s %s %s\n' "$(bash scripts/suite-content-key.sh)" 2 2026-01-01T00:00:00Z > "$KEY_RECORD"
fi
fixture_suite_step; echo "STEP-RC $?"
echo "---REC---"; cat "$KEY_RECORD" 2>/dev/null
echo "---BANNER---"
( . "$sp/banner" ) 2>&1
echo "---LOG---"; cat "$KEY_LOG"
DRV
export -f fx_inproc
bl954_run() { # <hook> <world> <tag> -> output on stdout
  bash "$BW/drv.sh" "$1" "$2" "$BW/w.$3.$2" "$BW/tpl" 2>&1
}
bl954_banner() { sed -n '/^---BANNER---$/,/^---LOG---$/p' <<< "$1" | grep 'all gates green'; }
bl954_log() { sed -n '/^---LOG---$/,$p' <<< "$1"; }
bl954_okw1() { # the read-set world's output holds the read-set banner, the MISS log and the key-not-matched step line
  local b; b="$(bl954_banner "$1")"
  grep -qF 'no prior green run recorded' <<< "$1" || return 1
  grep -qF ' MISS ' <<< "$(bl954_log "$1")" || return 1
  grep -qF 'read-set keys:' <<< "$1" || return 1
  grep -qF 'FIXTURE SUITE SKIPPED -- the read-set skip' <<< "$b" && ! grep -qF 'unchanged content key' <<< "$b" && ! grep -qF 'cause not recorded' <<< "$b"
}
bl954_okw2() {
  local b; b="$(bl954_banner "$1")"
  grep -qF ' HIT ' <<< "$(bl954_log "$1")" || return 1
  grep -qF 'FIXTURE SUITE SKIPPED -- the whole-suite content key matched' <<< "$b" && ! grep -qF 'cause not recorded' <<< "$b"
}
BHOOK="$T/.githooks/pre-push"
grep -q '^# SUITE_BANNER_BEGIN$' "$BHOOK" || broken "BL-954: the hook carries no SUITE_BANNER span"
BR1="$(bl954_run "$BHOOK" w1 base)"; BR2="$(bl954_run "$BHOOK" w2 base)"
grep -q 'STEP-RC 0' <<< "$BR1" || broken "BL-954 W1 driver: the step did not return 0: $(printf '%s' "$BR1" | tail -5 | tr '\n' '|')"
grep -q 'STEP-RC 0' <<< "$BR2" || broken "BL-954 W2 driver: the step did not return 0: [$BR2]"
if bl954_okw1 "$BR1"; then ok "W1 key MISSED, every read-set unchanged: the banner names the read-set arm, not 'unchanged content key', and the log says MISS ($(bl954_banner "$BR1" | cut -c1-150))"
else bad "W1 the read-set world's banner/log is wrong: $(printf '%s' "$BR1" | tail -6 | tr '\n' '|')"; fi
if bl954_okw2 "$BR2"; then ok "W2 key matched its record: the banner names the content-key arm and the log says HIT ($(bl954_banner "$BR2" | cut -c1-150))"
else bad "W2 the content-key world's banner/log is wrong: $(printf '%s' "$BR2" | tail -6 | tr '\n' '|')"; fi
if [ -n "$(bl954_banner "$BR1")" ] && [ "$(bl954_banner "$BR1")" != "$(bl954_banner "$BR2")" ]; then ok "W1 and W2 banners differ, each matching its own log line (MISS and HIT)"
else bad "W1 and W2 banners are identical or empty: a banner that cannot tell the arms apart"; fi
# --- BL-998. A WHOLE-SUITE HIT NAMES THE PENDING FIXTURES IT SKIPPED, FROM THE RECORD'S OWN SNAPSHOT --------
# Every fixture is skipped on a HIT, so its PENDING counts come from line 2 of the key record, written at the green
# write beside the key. W2P's snapshot names alpha=3 and not beta while the per-fixture key records say alpha 0 and
# beta 5: the HIT prints the snapshot (alpha recorded with 3, beta unnamed), never the records. W2, the one-line record
# of a hook that predates the snapshot, prints no PENDING line at all (the twin). W1's green write snapshots its seeded
# records, which carry no count, as `<fx>=-` each (count unrecorded; a zero is omitted, n > 0 is named).
BL998_W2P='   PENDING: 1 skipped on a recorded pass that printed a PENDING row: alpha(recorded)=3'
BRP="$(bl954_run "$BHOOK" w2p base)"
grep -q 'STEP-RC 0' <<< "$BRP" || broken "BL-998 W2P driver: the step did not return 0: $(printf '%s' "$BRP" | tail -5 | tr '\n' '|')"
if bl954_okw2 "$BRP" && grep -qxF "$BL998_W2P" <<< "$BRP"; then ok "W2P a HIT prints the PENDING clause from the record's snapshot (alpha=3, beta unnamed), not from the key records (alpha 0, beta 5)"
else bad "W2P the HIT's PENDING line is wrong: $(grep 'PENDING' <<< "$BRP" | tr '\n' '|')"; fi
if ! grep -q '^   PENDING:' <<< "$BR2"; then ok "W2 a one-line record (no snapshot) prints no PENDING line on its HIT"
else bad "W2 a record without a snapshot printed a PENDING line: $(grep 'PENDING:' <<< "$BR2" | tr '\n' '|')"; fi
if [ "$(sed -n '/^---REC---$/,/^---BANNER---$/p' <<< "$BR1" | sed -n 3p)" = '#pending alpha=- beta=-' ]; then
  ok "W1 the green write's line 2 is the snapshot line, naming each seeded record count unrecorded (alpha=- beta=-): they carry no count"
else bad "W1 the green write's snapshot line is wrong: $(sed -n '/^---REC---$/,/^---BANNER---$/p' <<< "$BR1" | tr '\n' '|')"; fi
# W1P: W1's world again, its KEYS_DIR holding the records W1's seed just published, each given line 4 `#pending <n>`
# where readset_keys_write puts it (alpha 3, beta 0). Both still skip, and the green write's line 2 must read exactly
# `#pending alpha=3`: a count on line 4 is read, a zero is omitted. W1 above is the twin, its records carrying no count.
export W1P_KEYS="$BW/w.base.w1.vs/fixture-keys/$(git -C "$BW/w.base.w1" rev-list --max-parents=0 HEAD 2>/dev/null)"
[ -f "$W1P_KEYS/alpha.key" ] && [ -f "$W1P_KEYS/beta.key" ] || broken "BL-998 W1P: W1's seed published no alpha/beta record at $W1P_KEYS"
bl998_w1p_rec() { sed -n '/^---REC---$/,/^---BANNER---$/p' <<< "$1" | sed -n 3p; } # line 2 of the record
BR1P="$(bl954_run "$BHOOK" w1p base)"
grep -q 'STEP-RC 0' <<< "$BR1P" || broken "BL-998 W1P driver: the step did not return 0: $(printf '%s' "$BR1P" | tail -5 | tr '\n' '|')"
if grep -qF 'read-set keys: 0 of 2 fixture(s) run' <<< "$BR1P" && [ "$(bl998_w1p_rec "$BR1P")" = '#pending alpha=3' ]; then
  ok "W1P the green write snapshots line 4 of the key records: line 2 reads '#pending alpha=3' (beta's 0 omitted, both records skipped)"
else bad "W1P the green write's snapshot is wrong: $(sed -n '/^---REC---$/,/^---BANNER---$/p' <<< "$BR1P" | tr '\n' '|') $(grep 'read-set keys:' <<< "$BR1P")"; fi
# --- BL-998. STEP 3b: A STORE-SKIPPED COUNTED FIXTURE IS NOT PENDING ----------------------------------------------
# inproc_pending_step (distribution hook only, outside FIXTURE_POOL) vouches for a fixture this push did not run counted
# when its key record's rows digest to an entry of the counted store. A record now carries `#pending <n>` as line 4, so
# the rows are read through readset_key_rows; a `tail -n +4` would take the `#pending` line as a row, miss the entry,
# and report a counted pass PENDING. One world: `dc` declared, run once through the real runner into a counted store
# (the producer's own k2 entry, with its 2 PENDING rows), its key record composed from the runner's --key-only rows.
# The step is cut from the hook and run in-process against three records:
#   pend     the record with `#pending 2`   -> skipped on a counted pass, 0 PENDING
#   legacy   the record with no `#pending`  -> the same
#   nostore  the record against an empty counted store -> 1 PENDING, named (the step CAN report PENDING)
HRS="$DIST/core/scripts/hermetic-run.sh"
[ -f "$HRS" ] || broken "no core/scripts/hermetic-run.sh at $DIST"
echo "HERMETIC-CONSUMED core/scripts/hermetic-run.sh"
IPW="$BW/ip"
cp -Rp "$BW/tpl" "$IPW" && mkdir -p "$IPW/.githooks" "$IPW/core/scripts" "$IPW/core/fixtures/dc" "$IPW.vs/counted-x" "$IPW.vs0/counted-x" \
  && cp "$BHOOK" "$IPW/.githooks/pre-push" && cp "$HRS" "$IPW/core/scripts/hermetic-run.sh" || broken "BL-998 step-3b world seed failed"
printf '#!/usr/bin/env bash\necho "  PENDING  dc: the subject is absent"\necho "  PENDING  dc: a second part"\nexit 0\n' > "$IPW/core/fixtures/dc/run.sh"
printf 'src/a.sh\n' > "$IPW/core/fixtures/dc/inputs.decl"
IPH="$( cd "$IPW" && env -u FXCOUNT_DIR -u FXCOUNT_RC -u FXCOUNT_JUDGE AI_DLC_VERDICT_STORE="$IPW.vs/counted-x" bash core/scripts/hermetic-run.sh --root "$IPW" dc 2>&1)"
( cd "$IPW" && env -u FXCOUNT_DIR -u FXCOUNT_RC -u FXCOUNT_JUDGE -u AI_DLC_VERDICT_STORE bash core/scripts/hermetic-run.sh --root "$IPW" --key-only dc ) > "$IPW.rows" 2>/dev/null
_ipe="$(grep -lx '#fixture dc' "$IPW.vs/counted-x"/*/* 2>/dev/null)"
[ -s "$IPW.rows" ] && [ "$(sed -n 1,2p "$_ipe" 2>/dev/null | tr '\n' ,)" = '#format k1,#state ok,' ] && [ "$(tail -n 1 "$_ipe" 2>/dev/null)" = '#pending 2' ] \
  || broken "BL-998 step-3b world: the runner wrote no k1 entry ending '#pending 2' for dc, or --key-only printed no rows: $(printf '%s\n' "$IPH" | tail -6 | tr '\n' '|')"
cat > "$BW/drvip.sh" <<'DRV'
set -uo pipefail
hook="$1"; t="$2"; v="$3"; sp="$4"
cd "$t" || exit 3
mkdir -p "$sp"
sed -n '/^# FIXTURE_POOL_BEGIN$/,/^# FIXTURE_POOL_END$/p' "$hook" > "$sp/pool"
sed -n '/^inproc_vs_hit() {/,/^}$/p; /^inproc_pending_step() {$/,/^}$/p' "$hook" > "$sp/ip"
[ -s "$sp/pool" ] && [ "$(grep -cE '^(inproc_vs_hit|inproc_pending_step)\(\) \{' "$sp/ip")" = 2 ] || { echo "DRIVER: a span is empty"; exit 3; }
fail=0; PENDING_N=0
. "$sp/pool" 2>/dev/null
. "$sp/ip"
AI_DLC_VERDICT_STORE="$t.vs/counted-x"; [ "$v" = nostore ] && AI_DLC_VERDICT_STORE="$t.vs0/counted-x"
export AI_DLC_VERDICT_STORE
FXCOUNT_DIR="$sp/fxc"; KEYS_DIR="$sp/keys"; mkdir -p "$FXCOUNT_DIR" "$KEYS_DIR"
{ printf '#format k1\n#state ok\n#tools canonical\n'; [ "$v" = legacy ] || printf '#pending 2\n'; cat "$t.rows"; } > "$KEYS_DIR/dc.key"
inproc_pending_step; echo "STEP-RC $?"
DRV
ip_run() { bash "$BW/drvip.sh" "$1" "$IPW" "$2" "$BW/ipsp.$3.$2" 2>&1; } # <hook> <variant> <tag>
IP_VS='   1 declared fixture(s): 0 counted this push, 1 skipped on a counted pass under this judge, 0 on scripts/fixture-inprocess-allowlist.txt, 0 PENDING'
IP_PN='   1 declared fixture(s): 0 counted this push, 0 skipped on a counted pass under this judge, 0 on scripts/fixture-inprocess-allowlist.txt, 1 PENDING'
ip_ok() { # ip_ok <output> <variant>: the variant's own predicate
  grep -q 'STEP-RC 0' <<< "$1" || return 2
  case "$2" in
    pend|legacy) grep -qxF "$IP_VS" <<< "$1" && ! grep -q '^   PENDING (no counted run' <<< "$1" ;;
    nostore) grep -qxF "$IP_PN" <<< "$1" && grep -qxF '   PENDING (no counted run under this judge): dc' <<< "$1" ;;
  esac
}
for _v in pend legacy nostore; do
  _o="$(ip_run "$BHOOK" "$_v" base)"
  if ip_ok "$_o" "$_v"; then ok "step 3b $_v: $(grep -E '^   1 declared|^   PENDING \(' <<< "$_o" | tr '\n' ' ')"
  else bad "step 3b $_v is wrong: $(printf '%s' "$_o" | tail -4 | tr '\n' '|')"; fi
done
echo
report_end suite-content-key
