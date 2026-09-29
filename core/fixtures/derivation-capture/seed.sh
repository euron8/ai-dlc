#!/usr/bin/env bash
# derivation-capture/seed.sh — build a consumer tree carrying an artifact whose
# ```derived blocks are HALF stale, so run.sh can drive the real hook and prove it
# blocks the pair an edit wrote and stays silent on the pair it did not.
#
# The tree copies the REAL validate-artifact-derivations.sh and the REAL hook. The
# hook delegates every verdict to that validator, so a fixture that stubbed either
# would be asserting against its own idea of the grammar rather than the shipped one.
#
# Four command/output pairs across three blocks, deliberately mixed:
#   block A   stale   (its own block, so a block-grain mask would also catch it)
#   block B   fresh   (its own block)
#   block C   fresh THEN stale in ONE block — the pair-grain discriminator. A mask
#             that worked at block grain and not pair grain passes every arm except
#             the two that use this block, which is why it is here.
#
# Prints the WORK dir on stdout. Idempotent: a fresh temp tree each call.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

# Both layouts: fixtures live at core/fixtures/<name>/ in the distribution and at
# tests/fixtures/<name>/ on a consumer, and the two sides put hooks and scripts in
# different places. Resolve each source independently — never by walking up from the
# other, which is the I33 defect.
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
[ -n "$ROOT" ] || { echo "FIXTURE ERROR: cannot resolve a root from $HERE" >&2; exit 2; }
if [ -f "$ROOT/core/hooks/ai-dlc-derivation-capture.sh" ]; then
  SRC_HOOK="$ROOT/core/hooks/ai-dlc-derivation-capture.sh"
  SRC_VALIDATOR="$ROOT/core/scripts/validate-artifact-derivations.sh"
elif [ -f "$ROOT/.claude/hooks/ai-dlc-derivation-capture.sh" ]; then
  SRC_HOOK="$ROOT/.claude/hooks/ai-dlc-derivation-capture.sh"
  SRC_VALIDATOR="$ROOT/scripts/ai-dlc/validate-artifact-derivations.sh"
else
  echo "FIXTURE ERROR: ai-dlc-derivation-capture.sh not found in either layout" >&2
  exit 2
fi
for f in "$SRC_HOOK" "$SRC_VALIDATOR"; do
  [ -r "$f" ] || { echo "FIXTURE ERROR: missing source $f" >&2; exit 2; }
done

WORK="$(mktemp -d "${TMPDIR:-/tmp}/derivation-capture.XXXXXX")" || exit 2
# macOS /tmp is a symlink; resolve so the hook's project-prefix strip lines up with
# the paths run.sh constructs.
WORK="$(cd "$WORK" && pwd)"

CONSUMER="$WORK/consumer"
mkdir -p "$CONSUMER/.claude/hooks" "$CONSUMER/scripts/ai-dlc" \
         "$CONSUMER/_bmad-output/planning-artifacts/s1"

# The root markers validate-artifact-derivations.sh walks up for.
printf '0.0.0\n' > "$CONSUMER/VERSION"

cp "$SRC_HOOK" "$CONSUMER/.claude/hooks/ai-dlc-derivation-capture.sh"
cp "$SRC_VALIDATOR" "$CONSUMER/scripts/ai-dlc/validate-artifact-derivations.sh"
chmod +x "$CONSUMER/.claude/hooks/ai-dlc-derivation-capture.sh" \
         "$CONSUMER/scripts/ai-dlc/validate-artifact-derivations.sh"

ART="$CONSUMER/_bmad-output/planning-artifacts/s1/stories-repair-p1.md"
cat > "$ART" <<'ARTIFACT'
# Story repair p1

## Finding 1 — the stale one

The token appears 99 times, which is why the propagation fans out.

```derived
$ grep -c stale VERSION
99
```

## Finding 2 — the fresh one

One line carries the version.

```derived
$ grep -c 0 VERSION
1
```

## Finding 3 — one block, two pairs

The version string and the absent token, derived together.

```derived
$ cat VERSION
0.0.0
$ grep -c neverpresent VERSION
7
```
ARTIFACT

# A second artifact with no fence at all: the cheap-reject path has to be shown to
# reject, not merely to pass for having found nothing to check.
cat > "$CONSUMER/_bmad-output/planning-artifacts/s1/prose-only.md" <<'PROSE'
# Prose only

No derivation anywhere in this file. 42 things, asserted and underived.
PROSE

# A third artifact whose ONLY fences are INDENTED -- both sit inside list items, as the
# reference consumer writes them. Block A (line 6) is stale, block B (line 13) is fresh. Kept
# in its own file so the arms that drive it are the only ones an indent-blind hook moves:
# the hook's two cheap rejects and its mask all matched the opener at column 0 until
# v0.500.0, and each of the three sites has a mutant in the sibling battery keyed on this
# file. PC-S308-VALIDATE-ARTIFACT-DERIVATIONS-INDENTED-FENCE-BLIND-SPOT.
IND_ART="$CONSUMER/_bmad-output/planning-artifacts/s1/indented-repair-p1.md"
cat > "$IND_ART" <<'INDENTED'
# Indented repair p1

- Finding A, in a list item, with its derivation fenced beneath it -- and stale.

  ```derived
  $ grep -c neverpresent VERSION
  7
  ```

- Finding B, the same shape, fresh.

  ```derived
  $ cat VERSION
  0.0.0
  ```

- Finding C, fresh, whose recorded output is itself a `$ ` line indented deeper than the fence.
  Under the shed rule that line is OUTPUT; a mask shedding all leading blanks reads it as a
  second command and the pair stops reproducing.

  ```derived
  $ printf '      $ x\n'
        $ x
  ```
INDENTED

# A fourth artifact: a wrapped SENTENCE whose continuation begins with the fence token
# (line 4), above one real, stale block (lines 6-9). The opener grammar used to accept any
# text after the word, so this line opened a phantom block that swallowed the real one --
# measured on two lines in the reference consumer. The info string is now exactly `derived`.
OPN_ART="$CONSUMER/_bmad-output/planning-artifacts/s1/prose-opener-p1.md"
cat > "$OPN_ART" <<'OPENER'
# Prose opener p1

A sentence that wraps so its continuation begins with the fence token, and the block
```derived would promise a machine check the command cannot keep -- so it stays unfenced.

```derived
$ grep -c neverpresent VERSION
7
```
OPENER

# A fifth artifact and the SECTION SPLIT of it -- the BL-372 section-sharded repair. The split is
# made by the REAL partition-document.sh when either layout carries it, so the manifest is the
# producer's bytes; a tree without it (a consumer that has not pulled it) gets the manifest the
# splitter's own header specifies, written here, and the run says which. The hook is the subject,
# not the splitter.
SPLIT_DOC="$CONSUMER/_bmad-output/planning-artifacts/s1/prd.md"
cat > "$SPLIT_DOC" <<'SPLITDOC'
# PRD

## Goals
The first goal of the product, stated in one line.
The second goal of the product, stated in one line.
The third goal of the product, stated in one line.

## Scope
The first scope item of the product, in one line.
The second scope item of the product, in one line.
The third scope item of the product, in one line.
The fourth scope item of the product, in one line.

## Risks
The first risk of the product, stated in one line.
The second risk of the product, stated in one line.
SPLITDOC
REPDIR="$CONSUMER/_bmad-output/planning-artifacts/s1/shards/prd-repair-p1"
SRC_PART=""
for _c in "$ROOT/core/scripts/partition-document.sh" "$ROOT/scripts/ai-dlc/partition-document.sh"; do
  [ -f "$_c" ] && { SRC_PART="$_c"; break; }
done
if [ -n "$SRC_PART" ]; then
  bash "$SRC_PART" --split "$SPLIT_DOC" "$REPDIR" >/dev/null 2>&1 \
    || { echo "FIXTURE ERROR: partition-document.sh --split refused the seeded document" >&2; exit 2; }
  SPLIT_BY="partition-document.sh"
else
  mkdir -p "$REPDIR/sections"
  sed -n '1,7p' "$SPLIT_DOC" > "$REPDIR/sections/1.md"
  sed -n '8,13p' "$SPLIT_DOC" > "$REPDIR/sections/2.md"
  sed -n '14,16p' "$SPLIT_DOC" > "$REPDIR/sections/3.md"
  { printf 'document\t%s/%s\n' "$(cd "$(dirname "$SPLIT_DOC")" && pwd -P)" "$(basename "$SPLIT_DOC")"
    printf 'sha256\t%s\n' "$(shasum -a 256 "$SPLIT_DOC" | cut -d' ' -f1)"
    printf 'part\t1\t1\t7\t## Goals\npart\t2\t8\t13\t## Scope\npart\t3\t14\t16\t## Risks\n'; } > "$REPDIR/sections/.manifest"
  SPLIT_BY="the seed (no partition-document.sh in either layout)"
fi

cat > "$WORK/env.sh" <<EOF
WORK="$WORK"
CONSUMER="$CONSUMER"
HOOK="$CONSUMER/.claude/hooks/ai-dlc-derivation-capture.sh"
VALIDATOR="$CONSUMER/scripts/ai-dlc/validate-artifact-derivations.sh"
ART="$ART"
PROSE_ART="$CONSUMER/_bmad-output/planning-artifacts/s1/prose-only.md"
IND_ART="$IND_ART"
OPN_ART="$OPN_ART"
SPLIT_DOC="$SPLIT_DOC"
REPDIR="$REPDIR"
SPLIT_BY="$SPLIT_BY"
EOF

printf '%s\n' "$WORK"
