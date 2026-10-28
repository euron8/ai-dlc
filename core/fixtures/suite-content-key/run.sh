#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
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
# THE MUTANT MATRIX. A CELL is one arm's predicate. PER PUSH a mutant is scored on its DECIDING cell, which
# must fail on it, and its named TWIN, a different cell it could plausibly co-trip but must leave GREEN.
# `run.sh --matrix` scores each mutant against every cell that READS the mutated file and prints one MATRIX
# line per mutant: M-plus mutates the READSET_KEYROWS span, so its cells are the four arms driving that span
# (k1, k2, k5, k6.hook); M-docs mutates the outer key script, so its cells are the arms driving it after the
# `+` fixture is built (k3.plans, k3.backlog, k4, k6.key, k7, and a well-formed-key sanity cell). Arms 0-9
# run against the unmutated key script and the unmutated span, so neither mutant reaches them. The matrix is
# re-measured whenever an arm or a mutant is added or changed, by the REMEASURE command below, run from the
# repo root.
# MUTANT-MATRIX M-plus decides=k1 twins=k2
# MUTANT-MATRIX M-docs decides=k3.plans twins=k3.backlog
# Both mutants reach mutant_killed through one helper, as a variable:
# MUTANT-MATRIX-DYNAMIC mx_score why=passes each mutant name of the two M- batteries as a variable and each name keeps its own row
# MUTANT-MATRIX-REMEASURE bash core/fixtures/suite-content-key/run.sh --matrix
#
# Usage: run.sh [--matrix]
set -uo pipefail

MODE=plain
case "${1:-}" in
  "") ;;
  --matrix) MODE=matrix ;;
  *) echo "suite-content-key: usage: run.sh [--matrix]" >&2; exit 2 ;;
esac

HERE="$(cd "$(dirname "$0")" && pwd)"
DIST="$(cd "$HERE/../../.." && pwd)"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }
broken() { printf '  FAIL  %s\n' "$1" >&2; echo "suite-content-key: FIXTURE BROKEN" >&2; exit 2; }

MUT_LIB="$HERE/../lib/mutant.sh"
[ -f "$MUT_LIB" ] || broken "lib/mutant.sh not found beside $HERE"
. "$MUT_LIB"
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"

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

KEY="$T/scripts/suite-content-key.sh"
key() { bash "$KEY" 2>/dev/null; }

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
# directory and a contents hash has nothing to hash. Verified by mutation --
# dropping directories from the listing turns exactly this assertion red.
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
# Two mutants, each a copy, each cmp-guarded, each killed by its own arm only:
#   M-plus  the parse strips `+` and emits no key row -- silent, it reads exactly like k2. k1 kills it.
#   M-docs  the outer key hashes all of docs/ (docs dropped from EXCLUDE). k3's plans control kills it.
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
if [ "$k1" = "$BSHA" ]; then ok "k1 a +docs/backlog.md declaration yields a docs/backlog.md key row carrying its sha256"; B_k1=1
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
if [ "$k3p" = "$KP" ]; then ok "k3 an EDIT of docs/plans/p.md does NOT move it (only the declared file is keyed, not its top)"; B_k3plans=1
else bad "k3 an edit of docs/plans/p.md moved the outer key -- the + opt-in widened to the whole excluded top"; fi

printf '!scripts/suite-content-key.sh\n+docs/backlog.md\n+docs/absent.md\n' > "$T/core/fixtures/gamma/inputs.decl"
if bash "$KEY" > /dev/null 2>&1; then bad "k4 a + naming an absent file still produced a key -- a skip would be authorised over a file nobody hashed"
else ok "k4 a + naming an absent file refuses the key (the caller runs the suite)"; fi
printf '!scripts/suite-content-key.sh\n+!docs/backlog.md\n' > "$T/core/fixtures/gamma/inputs.decl"
if bash "$KEY" > /dev/null 2>&1; then bad "k6 a line carrying + and ! together still produced an outer key"
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

# M-plus: the parse line that records a `+` path is deleted, so the marker is stripped and no P row
# is emitted. Anchored on that line alone, which the span carries exactly once.
mp_n="$(grep -cF 'if (x && $0 != "") print $0 > pl' "$WORK/span.sh")" || mp_n=0
[ "$mp_n" -eq 1 ] || broken "M-plus anchor found $mp_n time(s) in the span, want 1"
grep -vF 'if (x && $0 != "") print $0 > pl' "$WORK/span.sh" > "$WORK/span.mplus.sh"
cmp -s "$WORK/span.sh" "$WORK/span.mplus.sh" && broken "M-plus DID NOT APPLY"

# ---- matrix plumbing. The header rows are the only source of a mutant's deciding cell and twin. ----
# MXL is the rule-9 ledger: a deciding or twin cell appends "dec", a matrix-only cell appends "mx".
MXL="$WORK/mx.ledger"; : > "$MXL"
mx_row() { # <mutant> <decides|twins> -> that field of the mutant's single header row
  awk -v n="$1" -v f="$2" '
    $1 == "#" && $2 == "MUTANT-MATRIX" && $3 == n {
      c++; for (i = 4; i <= NF; i++) if (index($i, f "=") == 1) v = substr($i, length(f) + 2)
    }
    END { if (c == 1) print v }' "$HERE/run.sh"
}
mx_count() { local n; n="$(grep -c "^$1 " "$MXL")" || n=0; printf '%s' "$n"; }
mx_cell() { # <mutant> <cell> <role dec|mx> -> RED|GREEN, ledgered; a predicate that crashes is BROKEN, never GREEN
  local m="$1" c="$2" r="$3" e="$WORK/cell.err" rc
  printf '%s %s %s\n' "$r" "$m" "$c" >> "$MXL"
  "cell_$m" "$c" 2>"$e"; rc=$?
  case "$(cat "$e")" in
    *"unbound variable"*|*"command not found"*|*"syntax error"*)
      if [ "$MODE" = matrix ]; then echo "MATRIX BROKEN $m"; exit 2; fi
      broken "cell $c of $m crashed, which reads as GREEN" ;;
  esac
  case "$rc" in 0) MX_COLOR=RED ;; 1) MX_COLOR=GREEN ;; *) broken "cell $c of $m is not a cell of that mutant" ;; esac
}
# mx_score <mutant> <base-pass flag> <message> -- the deciding cell and the twin per push, every cell under --matrix.
mx_score() {
  local m="$1" fl="$2" msg="$3" dec tw d t a g=0 tot=0 u=""
  dec="$(mx_row "$m" decides)"; tw="$(mx_row "$m" twins)"
  [ -n "$dec" ] && [ -n "$tw" ] || broken "MUTANT $m has no single MUTANT-MATRIX row naming its deciding cell and twin"
  mx_cell "$m" "$dec" dec; d="$MX_COLOR"
  if [ "$d" = RED ]; then mutant_killed "$fl" "$m" "$msg"; else bad "MUTANT $m SURVIVED: its deciding cell $dec held on the mutated copy"; fi
  mx_cell "$m" "$tw" dec; t="$MX_COLOR"
  if [ "$t" = RED ]; then bad "MUTANT $m is entangled: its twin $tw also failed"; fi
  if [ "$MODE" = matrix ]; then # mx-all-cells
    for a in $(cells_of "$m"); do
      if [ "$a" = "$dec" ] || [ "$a" = "$tw" ]; then continue; fi
      tot=$((tot + 1)); mx_cell "$m" "$a" mx; if [ "$MX_COLOR" = GREEN ]; then g=$((g + 1)); fi
    done
    if [ "$d" = GREEN ]; then u=" UNEXPECTED=$dec:GREEN"; fi
    if [ "$t" = RED ]; then u="$u UNEXPECTED=$tw:RED"; fi
    printf 'MATRIX %s decides=%s:%s twins=%s:%s others=%d/%d%s\n' "$m" "$dec" "$d" "$tw" "$t" "$g" "$tot" "$u"
  fi
}
cells_of() { case "$1" in M-plus) echo "k1 k2 k5 k6hook" ;; M-docs) echo "k3plans k3backlog k4 k6key k7 sane" ;; esac; }

# M-plus cells, each read off the mutated span: RED when that arm's own predicate would FAIL (rc 0), GREEN when it holds (rc 1).
cell_M-plus() {
  local v n
  case "$1" in
    k1) v="$(krows "$WORK/span.mplus.sh" '+docs/backlog.md' | awk -F'\t' '$2 == "docs/backlog.md" { print $3 }')"
        MP_CTL="$(awk -F'\t' '$2 == "F" && $3 == "docs/backlog.md"' "$WORK/k.parse" | grep -c .)" || MP_CTL=0
        [ "$v" != "$BSHA" ] ;;
    k2) n="$(krows "$WORK/span.mplus.sh" 'docs/backlog.md' | awk -F'\t' '$2 == "docs/backlog.md"' | grep -c .)" || n=0
        [ "$n" -ne 0 ] ;;
    k5) krows "$WORK/span.mplus.sh" '+docs/' > /dev/null
        n="$(awk -F'\t' '$2 == "X" && $3 == "plusdir"' "$WORK/k.parse" | grep -c .)" || n=0
        [ "$n" -ne 1 ] ;;
    k6hook) krows "$WORK/span.mplus.sh" '!+docs/backlog.md' > /dev/null
        n="$(awk -F'\t' '$2 == "X" && $3 == "plusbang"' "$WORK/k.parse" | grep -c .)" || n=0
        [ "$n" -ne 1 ] ;;
    *) return 2 ;;
  esac
}
MP_CTL=0
mx_score M-plus "${B_k1:-0}" "M-plus scored by k1: a parse that drops + silently keys nothing, with the F row still parsed (it ran)"
# k1 ran first in mx_score, so MP_CTL is the F-row count of the mutated parse. A copy that never ran has no F row.
[ "$MP_CTL" -eq 1 ] || bad "M-plus control: the mutated parse produced $MP_CTL F row(s) for docs/backlog.md, want 1 -- the copy may not have run"

# M-docs: docs removed from EXCLUDE in a copy of the key script, driven through k3's two edits only.
sed '/^# EXCLUDE_BEGIN$/,/^# EXCLUDE_END$/{/^docs$/d;}' "$KEY" > "$WORK/key.mdocs.sh"
cmp -s "$KEY" "$WORK/key.mdocs.sh" && broken "M-docs DID NOT APPLY"
cp "$WORK/key.mdocs.sh" "$T/scripts/.key-mdocs.sh"
mkey() { bash "$T/scripts/.key-mdocs.sh" 2>/dev/null; }
mkedit() { # <file> -> the mutant key after appending one line, then the file restored
  cp "$T/$1" "$WORK/e.orig"; printf 'edited\n' >> "$T/$1"
  mkey; cp "$WORK/e.orig" "$T/$1"
}
MK="$(mkey)"
[ -n "$MK" ] || bad "M-docs control: the mutated key script produced no key on the pristine tree, so it may not have run"
GAMMA="$T/core/fixtures/gamma/inputs.decl"
cell_M-docs() { # RED = that arm's predicate would FAIL on the mutated key script
  local k
  case "$1" in
    k3plans)   k="$(mkedit docs/plans/p.md)"; [ -n "$MK" ] && [ "$k" != "$MK" ] ;;
    k3backlog) k="$(mkedit docs/backlog.md)"; [ -z "$k" ] || [ "$k" = "$MK" ] ;;
    k4)  printf '!scripts/suite-content-key.sh\n+docs/backlog.md\n+docs/absent.md\n' > "$GAMMA"
         if mkey > /dev/null; then k=0; else k=1; fi
         printf '!scripts/suite-content-key.sh\n+docs/backlog.md\n' > "$GAMMA"; [ "$k" -eq 0 ] ;;
    k6key) printf '!scripts/suite-content-key.sh\n+!docs/backlog.md\n' > "$GAMMA"
         if mkey > /dev/null; then k=0; else k=1; fi
         printf '!scripts/suite-content-key.sh\n+docs/backlog.md\n' > "$GAMMA"; [ "$k" -eq 0 ] ;;
    k7)  mv "$GAMMA" "$WORK/gamma.mdecl"; k="$(mkey)"; mv "$WORK/gamma.mdecl" "$GAMMA"
         case "$k" in ????????????????????????????????????????????????????????????????) return 1 ;; *) return 0 ;; esac ;;
    sane) case "$MK" in ????????????????????????????????????????????????????????????????) return 1 ;; *) return 0 ;; esac ;;
    *) return 2 ;;
  esac
}
mx_score M-docs "${B_k3plans:-0}" "M-docs scored by k3: a key hashing all of docs/ moves on the plans edit k3 requires to be still"
rm -f "$T/scripts/.key-mdocs.sh"
[ "$(key)" = "$KP" ] || broken "the tree did not return to its baseline key after the M-docs cells"

# RULE 9: a plain run executes NO matrix-only cell. Deciding and twin cells write the same ledger, so an
# empty matrix count cannot come from a ledger nothing writes.
mx_only="$(mx_count mx)"; mx_ctl="$(mx_count dec)"
if [ "$MODE" = plain ]; then
  if [ "$mx_ctl" -eq 0 ]; then bad "rule-9: the matrix ledger control is EMPTY, so a zero count of matrix-only cells means nothing"
  elif [ "$mx_only" -ne 0 ]; then bad "rule-9: a plain run executed $mx_only matrix-only cell(s) -- the --matrix measurement leaked into the per-push run"
  else ok "rule-9: a plain run executed no matrix-only cell, while $mx_ctl deciding or twin cell(s) wrote the same ledger"; fi
else
  echo "MATRIX-SUMMARY $mx_only matrix-only cell(s) ran"
fi

echo
if [ "$fails" -ne 0 ]; then
  echo "suite-content-key: $fails assertion(s) FAILED" >&2
  exit 1
fi
echo "suite-content-key: all assertions passed"
