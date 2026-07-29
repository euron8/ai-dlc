#!/usr/bin/env bash
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
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
DIST="$(cd "$HERE/../../.." && pwd)"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }
broken() { printf '  FAIL  %s\n' "$1" >&2; echo "suite-content-key: FIXTURE BROKEN" >&2; exit 2; }

echo "suite-content-key:"

[ -f "$DIST/scripts/suite-content-key.sh" ] || broken "no scripts/suite-content-key.sh at $DIST"

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
mkdir -p "$T/core/fixtures/alpha" "$T/core/fixtures/beta" "$T/docs"
printf 'body\n' > "$T/core/fixtures/alpha/run.sh"
printf 'body\n' > "$T/core/fixtures/beta/run.sh"
printf 'a doc\n'  > "$T/docs/note.md"
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

echo
if [ "$fails" -ne 0 ]; then
  echo "suite-content-key: $fails assertion(s) FAILED" >&2
  exit 1
fi
echo "suite-content-key: all assertions passed"
