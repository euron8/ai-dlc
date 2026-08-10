#!/usr/bin/env bash
# Exercise install.sh's `.claude/rules/` version floor and uninstall.sh's removal of it.
#
# `.claude/rules/` did not exist before Claude Code 2.0.64. On an older build the loader
# reads nothing there, so a rule file copied into it is INERT while the tree, and the
# consumer's own audit, report it as installed. That is a check that cannot fire reading
# exactly like one that passed -- exported to every consumer. install.sh therefore resolves
# `claude --version` and SKIPS the copy loudly below the floor.
#
#   above-floor   a shimmed `claude --version` of 9.9.9   -> rule INSTALLED
#   below-floor   a shimmed `claude --version` of 1.9.0   -> SKIPPED, directory ABSENT
#   absent        no `claude` on PATH at all              -> SKIPPED, directory ABSENT
#   uninstall     removes ai-dlc-*.md, KEEPS a consumer's own rule file
#
# WHY THE VERSION IS SHIMMED AND NOT READ. A fixture that asserted "installs on this
# machine" would pass for as long as the developer's Claude Code happened to be recent and
# would never once exercise the skip. The shim is what makes the floor's two branches both
# reachable on any machine, which is the only way the skip is a tested path rather than a
# comment.
#
# WHY THE UNINSTALL ARM CARRIES A CONSUMER-OWNED FILE. `.claude/rules/` is NOT ai-dlc-owned
# the way team-roles/ is -- Claude Code reads every `.md` there, so a consumer's own rules
# live alongside ours and a directory-level removal would delete them. The `ai-dlc-` prefix
# is the boundary, and this arm is what proves the prefix is actually honoured.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
# Resolve the distribution root by walking UP for a marker from this fixture's OWN
# location, never by counting `..` hops -- a fixed hop count is what I33/I33b forbid, and
# the first draft of this file used `$DIR/../..`, which lands in core/ and made every arm
# below exit 2 before running. The marker is install.sh itself, since that is the subject.
ROOT="$DIR"
while [ "$ROOT" != "/" ] && [ ! -f "$ROOT/scripts/install.sh" ]; do ROOT="$(dirname "$ROOT")"; done
INSTALL="$ROOT/scripts/install.sh"
UNINSTALL="$ROOT/scripts/uninstall.sh"
RULE="ai-dlc-resident-discipline.md"

for f in "$INSTALL" "$UNINSTALL"; do
  [ -f "$f" ] || { echo "run.sh: missing $f" >&2; exit 2; }
done
command -v jq >/dev/null 2>&1 || { echo "run.sh: jq required by install.sh" >&2; exit 2; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
rc=0
note() { printf '%s\n' "$*"; }

new_target() { local d; d="$(mktemp -d "$TMP/tgt.XXXXXX")"; mkdir -p "$d/_bmad"; ( cd "$d" && git init -q . ); printf '%s' "$d"; }
shim() { # shim <version-or-empty> -> prints a dir to prepend to PATH
  local d v="$1"; d="$(mktemp -d "$TMP/bin.XXXXXX")"
  if [ -n "$v" ]; then printf '#!/bin/sh\necho "%s (Claude Code)"\n' "$v" > "$d/claude"; chmod +x "$d/claude"; fi
  printf '%s' "$d"
}

# --- arm 1: above the floor -> installed --------------------------------------
t="$(new_target)"; b="$(shim 9.9.9)"
PATH="$b:$PATH" bash "$INSTALL" "$t" > "$TMP/above.log" 2>&1
if [ -f "$t/.claude/rules/$RULE" ]; then
  note "ok    above-floor -- rule installed"
else
  note "FAIL  above-floor -- rule NOT installed with a 9.9.9 shim on PATH"; rc=1
  grep -A3 'Installing rule files' "$TMP/above.log" | sed 's/^/      /'
fi
# The carrier only works UNCONDITIONALLY. A `paths:` line would make it load once per
# session and vanish at the first compaction -- the exact failure it exists to prevent.
if [ -f "$t/.claude/rules/$RULE" ] && head -1 "$t/.claude/rules/$RULE" | grep -q '^---$'; then
  note "FAIL  above-floor -- the shipped rule carries frontmatter; a \`paths:\` scope would"
  note "      make it load once per session and NOT survive compaction, which is the whole point"
  rc=1
fi

# --- arm 2: below the floor -> skipped, nothing written -----------------------
t="$(new_target)"; b="$(shim 1.9.0)"
PATH="$b:$PATH" bash "$INSTALL" "$t" > "$TMP/below.log" 2>&1
if [ -e "$t/.claude/rules" ]; then
  note "FAIL  below-floor -- .claude/rules/ was created on a 1.9.0 build; the loader there reads nothing, so the file is inert while the tree reports it installed"; rc=1
elif ! grep -q 'SKIPPED' "$TMP/below.log"; then
  note "FAIL  below-floor -- nothing was written but install.sh said nothing. A silent skip is indistinguishable from a successful install."; rc=1
else
  note "ok    below-floor -- skipped, directory absent, and the skip is announced"
fi

# --- arm 3: no claude on PATH -> skipped, nothing written ---------------------
t="$(new_target)"; b="$(shim '')"
PATH="$b:/usr/bin:/bin" bash "$INSTALL" "$t" > "$TMP/absent.log" 2>&1
if [ -e "$t/.claude/rules" ]; then
  note "FAIL  absent-claude -- .claude/rules/ was created with no resolvable version"; rc=1
elif ! grep -q 'SKIPPED' "$TMP/absent.log"; then
  note "FAIL  absent-claude -- skipped silently"; rc=1
else
  note "ok    absent-claude -- skipped, directory absent, and the skip is announced"
fi

# --- arm 4: uninstall removes ours, keeps theirs ------------------------------
t="$(new_target)"; b="$(shim 9.9.9)"
PATH="$b:$PATH" bash "$INSTALL" "$t" > "$TMP/u-install.log" 2>&1
printf '# a rule this consumer wrote\n' > "$t/.claude/rules/consumer-own.md"
if [ ! -f "$t/.claude/rules/$RULE" ]; then
  note "FIXTURE BROKEN: arm 4's install did not place the rule, so the removal below proves nothing."
  exit 1
fi
printf 'y\n' | bash "$UNINSTALL" "$t" > "$TMP/uninstall.log" 2>&1
if [ -f "$t/.claude/rules/$RULE" ]; then
  note "FAIL  uninstall -- the shipped rule survived. An unconditional rule keeps loading into EVERY session of a repo that no longer has AI/DLC installed."; rc=1
elif [ ! -f "$t/.claude/rules/consumer-own.md" ]; then
  note "FAIL  uninstall -- it deleted the consumer's OWN rule file. The \`ai-dlc-\` prefix is the boundary; .claude/rules/ is shared, not ai-dlc-owned."; rc=1
elif [ -f "$t/.claude/.ai-dlc-cc-version" ]; then
  note "FAIL  uninstall -- the version stamp was left behind"; rc=1
else
  note "ok    uninstall -- removed ai-dlc-*, kept the consumer's own rule, cleared the stamp"
fi

[ "$rc" -eq 0 ] && note "PASS  shipped-rule-version-floor -- floor honoured in both directions, uninstall scoped by prefix"
exit "$rc"
