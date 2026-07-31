#!/usr/bin/env bash
# seed.sh — three REAL consumer trees for the per-entry contract receipt (E17 / W6).
#
# Everything below is written to disk and committed. A seed that PRINTS a description of a
# fixture instead of writing one cannot fail, and v0.48.0 shipped three of those.
#
#   consumer/     every entry carries a receipt at the current contract_version
#   bad-consumer/ one entry per malformed receipt, plus the BEHIND entry that carries a
#                 band violation — the subject of the non-silencing assertion
#   no-contract/  consumer/ with layer-contract.yaml removed, for the refusal arm
#
# THE CONTRACT IS COPIED FROM THE SHIPPING FILE, never written here. Its contract_version is
# read back out of the copy, so every receipt below tracks the real contract as it bumps and
# this fixture cannot go stale against a version it hard-coded.
#
# Prints the sandbox root on stdout.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(mktemp -d "${TMPDIR:-/tmp}/layer-conforms-to.XXXXXX")"
CONS="$ROOT/consumer"
BAD="$ROOT/bad-consumer"
NOLC="$ROOT/no-contract"

# Rooted at this seed's OWN location with both layouts named, never derived from another
# resolved path: I33 fails the build on the second shape, and this fixture runs in both trees.
LC=""
for _c in "$HERE/../../skills/ai-dlc/layer-contract.yaml" \
          "$HERE/../../../core/skills/ai-dlc/layer-contract.yaml" \
          "$HERE/../../../.claude/skills/ai-dlc/layer-contract.yaml"; do
  [ -f "$_c" ] && { LC="$_c"; break; }
done
[ -n "$LC" ] || { echo "SEED ERROR: cannot locate layer-contract.yaml" >&2; exit 2; }
CV="$(awk '/^contract_version:/{print $2; exit}' "$LC")"
[ -n "$CV" ] || { echo "SEED ERROR: no contract_version in layer-contract.yaml" >&2; exit 2; }
ABOVE=$((CV + 1))

# A synthetic core catalog. Entries hook it, and its check numbers are what the band arm
# joins a consumer id against — `12.` below is a number core defines, which is exactly the
# case the total partition reports rather than excludes.
core_tree() { # core_tree <consumer-root>
  local c="$1" s="$1/.claude/skills/ai-dlc"
  mkdir -p "$s/extensions" "$s/overrides" "$s/steps"
  cp "$LC" "$s/layer-contract.yaml"
  cat > "$s/steps/gate-validation.md" <<'CORE'
---
name: gate-validation
description: synthetic core catalog for the layer-conforms-to fixture
---

# Synthetic gate-validation catalog

### 12. Core's own check.
<!-- CHECK_LOADED: 12 -->
Core defines 12. A consumer heading under the same integer is an allocation from core's
namespace, which the band arm reports rather than excludes.
CORE
}

entry() { # entry <consumer-root> <basename> <heading-number> <receipt-line-or-empty>
  local c="$1" n="$2" num="$3" rcpt="${4:-}"
  { printf -- '---\n'
    printf 'kind: check\nhooks: steps/gate-validation.md\nid: %s\npush_candidate: false\n' "$n"
    [ -n "$rcpt" ] && printf '%s\n' "$rcpt"
    printf -- '---\n\n'
    printf '### %s. [ext:%s] Consumer check.\n<!-- CHECK_LOADED: %s -->\nBody.\n' "$num" "$n" "$num"
  } > "$c/.claude/skills/ai-dlc/extensions/$n.md"
}

# --- consumer/ : every receipt current, every id in band -------------------------------
core_tree "$CONS"
entry "$CONS" current-a 901 "conforms_to: $CV"
entry "$CONS" current-b 902 "conforms_to: $CV"
# An OVERRIDE carries the receipt too. The clause's subject is `any`, and a pass that walked
# only extensions/ would report the same clean footer on a tree whose overrides declare none.
{ printf -- '---\n'
  printf 'shadows: steps/gate-validation.md#12. Core'"'"'s own check.\n'
  printf 'base_sha: 0123456789abcdef0123456789abcdef01234567\n'
  printf 'reason: fixture override, exercises the receipt on the override side\n'
  printf 'conforms_to: %s\n' "$CV"
  printf -- '---\n\n### 12. Core'"'"'s own check.\n\nShadowed body.\n'
} > "$CONS/.claude/skills/ai-dlc/overrides/gate-validation__12.md"

# --- bad-consumer/ : one entry per malformed receipt -----------------------------------
core_tree "$BAD"
entry "$BAD" no-receipt   903 ""
entry "$BAD" not-a-number 904 "conforms_to: eight"
entry "$BAD" above-cv     905 "conforms_to: $ABOVE"
# THE NON-SILENCING SUBJECT. A well-formed receipt at version 1, on an entry that allocates a
# heading number core already defines. LC-N5 was introduced at `since: 4`, so under the skip
# semantics the contract specified for eight versions this entry would escape the band ERROR
# entirely. It must not: the receipt reports scope, it does not subtract clauses.
entry "$BAD" behind-and-in-core-range 12 "conforms_to: 1"

# --- no-contract/ : the refusal arm ----------------------------------------------------
core_tree "$NOLC"
entry "$NOLC" current-a 901 "conforms_to: $CV"
rm -f "$NOLC/.claude/skills/ai-dlc/layer-contract.yaml"

# THE CONSUMERS ARE GIT REPOS, because a real one always is. E16 reads an entry's id history
# from the consumer's own git and REFUSES on a tree with no git — correctly, and loudly. A seed
# without git would make the clean-consumer assertion below run against a shape no consumer has,
# and that refusal would read as a regression rather than as the missing seed it is.
for _c in "$CONS" "$BAD" "$NOLC"; do
  git init -q "$_c"
  git -C "$_c" config user.email fixture@example.invalid
  git -C "$_c" config user.name 'layer-conforms-to fixture'
  git -C "$_c" config commit.gpgsign false
  git -C "$_c" add -A
  GIT_AUTHOR_DATE='2026-03-01T00:00:00+00:00' GIT_COMMITTER_DATE='2026-03-01T00:00:00+00:00' \
    git -C "$_c" -c user.email=fixture@example.invalid -c user.name=fixture \
      commit -q --no-verify -m 'seed: the consumer layer as authored'
done

printf '%s\n' "$ROOT"
