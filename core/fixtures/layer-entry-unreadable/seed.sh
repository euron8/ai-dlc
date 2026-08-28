#!/usr/bin/env bash
# seed.sh — REAL consumer trees for the read-failure / absent-key partition (PC-S307).
#
# Everything below is written to disk and committed. A seed that PRINTS a description of a
# fixture instead of writing one cannot fail.
#
#   consumer/       every entry readable and well-formed — the baseline the control asserts
#   unreadable/     consumer/ plus ONE chmod-000 extension. The subject.
#   keyless/        consumer/ plus the SAME file, same bytes, readable, with conforms_to
#                   removed. The discriminating twin: absent key, not absent read.
#   nolc-ovr/       contract_version made unreadable so the census loop is skipped, plus one
#                   chmod-000 OVERRIDE. Reaches the overrides guard, which the census
#                   pre-empts on every ordinary tree.
#   nolc-ext/       same, with ONE chmod-000 EXTENSION and no other extension at all.
#                   Reaches the live-layer guard, and makes the resolvability set the
#                   observable that guard is the only thing protecting.
#   permissive/     a kind: role entry whose extends/position/gate_types are each wrong in
#                   their own way, so every permissive read has a finding of its own to lose.
#   citation/       an extension whose shadows anchor ACQUITS a bare Check citation in its
#                   own body — the one guarded read whose failure ADDS a finding.
#
# THE LAST TWO CARRY NO chmod. Their sites sit behind every earlier guard, so a permanently
# unreadable file never reaches them; run.sh reaches them with a fault-injected fm() instead,
# and measures the pair it injects off the shipped fm() before trusting it.
#
# THE CHMOD IS THE LAST THING DONE, AFTER THE COMMIT. `git add` cannot read a 000 file, so
# seeding the mode first produces a repo with no entry in it and a fixture whose subject is
# absent rather than unreadable — which reads as a clean run.
#
# THE CONTRACT IS COPIED FROM THE SHIPPING FILE, never written here, so every receipt below
# tracks the real contract as it bumps.
#
# Prints the sandbox root on stdout.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(mktemp -d "${TMPDIR:-/tmp}/layer-entry-unreadable.XXXXXX")"

# Rooted at this seed's OWN location with both install layouts named, never derived from
# another resolved path: I33 fails the build on the second shape, and this fixture runs in
# both trees.
LC=""
for _c in "$HERE/../../skills/ai-dlc/layer-contract.yaml" \
          "$HERE/../../../core/skills/ai-dlc/layer-contract.yaml" \
          "$HERE/../../../.claude/skills/ai-dlc/layer-contract.yaml"; do
  [ -f "$_c" ] && { LC="$_c"; break; }
done
[ -n "$LC" ] || { echo "SEED ERROR: cannot locate layer-contract.yaml" >&2; exit 2; }
CV="$(awk '/^contract_version:/{print $2; exit}' "$LC")"
[ -n "$CV" ] || { echo "SEED ERROR: no contract_version in layer-contract.yaml" >&2; exit 2; }

core_tree() { # core_tree <consumer-root>
  local s="$1/.claude/skills/ai-dlc"
  mkdir -p "$s/extensions" "$s/overrides" "$s/steps"
  cp "$LC" "$s/layer-contract.yaml"
  cat > "$s/steps/gate-validation.md" <<'CORE'
---
name: gate-validation
description: synthetic core catalog for the layer-entry-unreadable fixture
---

# Synthetic gate-validation catalog

### 12. Core's own check.
<!-- CHECK_LOADED: 12 -->
Core defines 12.
CORE
}

# ext <consumer-root> <basename> <heading-number> <receipt-line-or-empty>
ext() {
  local c="$1" n="$2" num="$3" rcpt="${4:-}"
  { printf -- '---\n'
    printf 'kind: check\nhooks: steps/gate-validation.md\nid: %s\npush_candidate: false\n' "$n"
    [ -n "$rcpt" ] && printf '%s\n' "$rcpt"
    printf -- '---\n\n'
    printf '### %s. [ext:%s] Consumer check.\n<!-- CHECK_LOADED: %s -->\nBody.\n' "$num" "$n" "$num"
  } > "$c/.claude/skills/ai-dlc/extensions/$n.md"
}

# ovr <consumer-root> <basename> <receipt-line-or-empty>
ovr() {
  local c="$1" n="$2" rcpt="${3:-}"
  { printf -- '---\n'
    printf 'shadows: steps/gate-validation.md#12. Core'"'"'s own check.\n'
    printf 'base_sha: 0123456789abcdef0123456789abcdef01234567\n'
    printf 'reason: fixture override, gives the overrides pass a subject\n'
    [ -n "$rcpt" ] && printf '%s\n' "$rcpt"
    printf -- '---\n\n### 12. Core'"'"'s own check.\n\nShadowed body.\n'
  } > "$c/.claude/skills/ai-dlc/overrides/$n.md"
}

# --- consumer/ : the baseline ----------------------------------------------------------
CONS="$ROOT/consumer"
core_tree "$CONS"
ext "$CONS" current-a 901 "conforms_to: $CV"
ovr "$CONS" gate-validation__12 "conforms_to: $CV"

# --- unreadable/ and keyless/ : the discriminating PAIR ---------------------------------
# Same tree, same extra file, same BYTES in that file. The only difference between them is
# one chmod and one frontmatter line, so a validator that refuses everything and one that
# discriminates cannot produce the same pair of verdicts.
UNR="$ROOT/unreadable"
core_tree "$UNR"
ext "$UNR" current-a 901 "conforms_to: $CV"
ovr "$UNR" gate-validation__12 "conforms_to: $CV"
ext "$UNR" subject 902 "conforms_to: $CV"

KEY="$ROOT/keyless"
core_tree "$KEY"
ext "$KEY" current-a 901 "conforms_to: $CV"
ovr "$KEY" gate-validation__12 "conforms_to: $CV"
ext "$KEY" subject 902 ""

# --- nolc-ovr/ : the overrides guard's own subject --------------------------------------
# `contract_version` is made unreadable rather than the contract deleted. The validator
# ERRORs, sets LC_CV empty and CARRIES ON — which is the one reachable state where the
# census loop does not run and the later loops are the first thing to read an entry. A
# deleted contract would do the same, but it also silences the crosswalk declaration, and
# this fixture's subject is the entry read, not the contract read.
OVRT="$ROOT/nolc-ovr"
core_tree "$OVRT"
ext "$OVRT" current-a 901 "conforms_to: $CV"
ovr "$OVRT" gate-validation__12 "conforms_to: $CV"
ovr "$OVRT" subject-ovr "conforms_to: $CV"
sed 's/^contract_version:.*/contract_version: not-a-number/' \
  "$OVRT/.claude/skills/ai-dlc/layer-contract.yaml" > "$OVRT/.claude/skills/ai-dlc/lc.tmp"
mv "$OVRT/.claude/skills/ai-dlc/lc.tmp" "$OVRT/.claude/skills/ai-dlc/layer-contract.yaml"

# --- nolc-ext/ : the live-layer guard's own subject -------------------------------------
# EXACTLY ONE extension, and it is the unreadable one. That is deliberate: the resolvability
# set is then built from this file alone, so dropping it silently leaves the set EMPTY and
# E16 says so out loud. With a second readable extension present the drop is unobservable in
# this run's output, which is the point the live-layer guard exists to make.
EXTT="$ROOT/nolc-ext"
core_tree "$EXTT"
ovr "$EXTT" gate-validation__12 "conforms_to: $CV"
ext "$EXTT" subject-ext 902 "conforms_to: $CV"
sed 's/^contract_version:.*/contract_version: not-a-number/' \
  "$EXTT/.claude/skills/ai-dlc/layer-contract.yaml" > "$EXTT/.claude/skills/ai-dlc/lc.tmp"
mv "$EXTT/.claude/skills/ai-dlc/lc.tmp" "$EXTT/.claude/skills/ai-dlc/layer-contract.yaml"

# --- permissive/ : the tree that REACHES the reads whose empty value is PERMISSIVE ------
# The four guards added in the second round sit behind `if [ -n "$x" ]` arms, so an empty
# read there does not manufacture a finding — it DELETES one. To see that at all the entry
# has to survive every earlier `continue` in the extensions loop, and two of them are easy
# to miss: an entry with no `hooks:` and an entry whose hooks target does not exist are both
# `continue`d BEFORE these reads. So this tree ships a real `steps/retro.md` to hook and a
# `push_candidate:` key, and each seeded key is wrong in its OWN way so that each read has a
# finding of its own to lose:
#
#   extends:    an anchor that is in no heading  -> E11
#   position:   declared on kind role, and not append/prepend -> E12 AND E13
#   gate_types: declared on a kind that is not check -> E14
PERM="$ROOT/permissive"
core_tree "$PERM"
cat > "$PERM/.claude/skills/ai-dlc/steps/retro.md" <<'RETRO'
---
name: retro
description: synthetic core retro step for the layer-entry-unreadable fixture
---

# Synthetic retro

### 7. Retro heading.
Body.
RETRO
{ printf -- '---\n'
  printf 'kind: role\nhooks: steps/retro.md\nid: role-entry\npush_candidate: false\n'
  printf 'conforms_to: %s\n' "$CV"
  printf 'extends: steps/retro.md#No Such Heading\n'
  printf 'position: sideways\n'
  printf 'gate_types: universal\n'
  printf -- '---\n\n'
  printf '## Consumer role.\n\nBody.\n'
} > "$PERM/.claude/skills/ai-dlc/extensions/role-entry.md"

# --- citation/ : the reference-resolution loop's `shadows` read ------------------------
# THE ONLY ONE OF THE EIGHT WHOSE CONSUMER IS AN ACQUITTAL, and that is why the key sits on
# an EXTENSION here and not on an override. The overrides pass reads `shadows:` off every
# override before this loop does, so on an override the earlier guard always fires first and
# this one can never be the site that speaks. An extension may declare the key too, and then
# this loop is its first reader.
#
# The shape the acquittal needs: core defines `12.`, the consumer defines the `912.` band
# counterpart, and the entry's body cites a bare `Check 12`. That citation is ambiguous
# between the two — except that the entry's own `shadows:` anchor already says which one it
# means, which is exactly what the acquittal reads.
CITE="$ROOT/citation"
core_tree "$CITE"
{ printf -- '---\n'
  printf 'kind: check\nhooks: steps/gate-validation.md\nid: cite-ext\npush_candidate: false\n'
  printf 'conforms_to: %s\n' "$CV"
  printf 'shadows: steps/gate-validation.md#12. Core'"'"'s own check.\n'
  printf -- '---\n\n'
  printf '### 912. [ext:cite-ext] Consumer check.\n<!-- CHECK_LOADED: 912 -->\n'
  printf 'This body cites Check 12 and means the one it shadows.\n'
} > "$CITE/.claude/skills/ai-dlc/extensions/cite-ext.md"

# THE CONSUMERS ARE GIT REPOS, because a real one always is. E16 reads an entry's id history
# from the consumer's own git and REFUSES on a tree with no git — correctly, and loudly.
for _c in "$CONS" "$UNR" "$KEY" "$OVRT" "$EXTT" "$PERM" "$CITE"; do
  git init -q "$_c"
  git -C "$_c" config user.email fixture@example.invalid
  git -C "$_c" config user.name 'layer-entry-unreadable fixture'
  git -C "$_c" config commit.gpgsign false
  git -C "$_c" add -A
  GIT_AUTHOR_DATE='2026-03-01T00:00:00+00:00' GIT_COMMITTER_DATE='2026-03-01T00:00:00+00:00' \
    git -C "$_c" -c user.email=fixture@example.invalid -c user.name=fixture \
      commit -q --no-verify -m 'seed: the consumer layer as authored'
done

# --- and NOW the chmod, after every git read has happened -------------------------------
chmod 000 "$UNR/.claude/skills/ai-dlc/extensions/subject.md"
chmod 000 "$OVRT/.claude/skills/ai-dlc/overrides/subject-ovr.md"
chmod 000 "$EXTT/.claude/skills/ai-dlc/extensions/subject-ext.md"

printf '%s\n' "$ROOT"
