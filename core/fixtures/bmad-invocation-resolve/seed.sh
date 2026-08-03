#!/usr/bin/env bash
# Build a synthetic consumer: a .claude/skills tree holding one live self-contained
# skill, one dead shim, one deprecated shim, and a rulebook that invokes them.
# Prints the root on stdout. Caller owns cleanup.
set -eu
ROOT="$(mktemp -d "${TMPDIR:-/tmp}/bmad-invocation-resolve.XXXXXX")"
S="$ROOT/.claude/skills"
mkdir -p "$S" "$ROOT/rules/steps" "$ROOT/_bmad/live/agents"

# (1) live, self-contained -- no LOAD directive at all
mkdir -p "$S/bmad-live-one"
printf -- '---\nname: bmad-live-one\ndescription: a self-contained workflow\n---\n\n# Live\nSteps are in this file.\n' \
  > "$S/bmad-live-one/SKILL.md"

# (2) live loader -- LOAD target EXISTS
mkdir -p "$S/bmad-loader-ok"
printf -- '---\nname: bmad-loader-ok\ndescription: loader\n---\n\nLOAD the FULL {project-root}/_bmad/live/agents/real.md, READ its entire contents.\n' \
  > "$S/bmad-loader-ok/SKILL.md"
printf '# real agent\n' > "$ROOT/_bmad/live/agents/real.md"

# (3) DEAD SHIM -- directory exists, SKILL.md exists, LOAD target ABSENT
mkdir -p "$S/bmad-dead-shim"
printf -- '---\nname: bmad-dead-shim\ndescription: shim\n---\n\nLOAD the FULL agent file from {project-root}/_bmad/abandoned/agents/gone.md\n' \
  > "$S/bmad-dead-shim/SKILL.md"

# (4) deprecated but resolving -- must be REPORTED, not failed
mkdir -p "$S/bmad-deprecated-one"
printf -- '---\nname: bmad-deprecated-one\ndescription: DEPRECATED -- consolidated into bmad-live-one; removed in v7.\n---\n\n# Deprecated\n' \
  > "$S/bmad-deprecated-one/SKILL.md"

printf 'Invoke `/bmad-live-one` and `/bmad-loader-ok` at this step.\n' > "$ROOT/rules/steps/clean.md"

# (5) THE POISON. A fixture-path DECLARATION carrying a `/bmad-…` segment, in a file
# the scan reads. This is the real shape: the rulebook's own manifest names the
# fixture directory that tests this check, and for the life of the UNLOADABLE arm the
# enumerator counted it as an invocation of a skill nobody wrote. Both spellings the
# distribution actually carries are seeded -- the manifest bullet and the
# enforcement-map list form -- plus the line-start case, where there is no leading
# path character at all and only the TRAILING separator distinguishes it.
cat > "$ROOT/rules/core-manifest.md" <<'EOF'
# core manifest

```yaml
core_manifest:
  - fixtures/bmad-invocation-resolve/**
```
EOF
printf 'fixtures: [tests/fixtures/bmad-invocation-resolve]\n' > "$ROOT/rules/enforcement-map.yaml"
printf '/bmad-line-start-path/seed.sh is a path, not a call site.\n' >> "$ROOT/rules/steps/clean.md"

printf '%s\n' "$ROOT"
